# MIKEKA APP — API v1 (for the Dart / Flutter app)

`api.php` uses the same database, packages, prices and SonicPesa payments as the web app.
It lives on the **main domain**: upload it to `public_html` of `mikekaapp.co.tz`
(same cPanel account and database as the web app on `odds-mikeka.mikekaapp.co.tz`).

**Base URL**

```
https://mikekaapp.co.tz/api.php
```

Both styles work: `.../api.php/tipsters` or `.../api.php?route=tipsters`.
`GET /docs` returns the live list of all endpoints.

---

## 1. Requests and responses

- Send bodies as JSON (`Content-Type: application/json`) or form-data.
- Every response has the same shape:

```json
{ "success": true,  "data": { ... }, "meta": { "server_time": 1793004243, "server_datetime": "2026-10-26T11:44:03+03:00", "api_version": "1.0.0" } }
{ "success": false, "error": { "code": "login_required", "message": "Tafadhali ingia ..." }, "meta": { ... } }
```

- `error.message` is already in Swahili — show it to the user as it is.
- Use `meta.server_time` (unix seconds) for countdowns instead of the phone clock.

### Error codes

| code | HTTP | What the app should do |
|---|---|---|
| `validation` | 422 | Show the message |
| `login_required`, `unauthorized`, `token_expired` | 401 | Delete the token, open the login screen |
| `session_kicked` | 401 | Account was opened on another phone. Delete token, show message, open login |
| `account_banned` | 403 | Show ban screen (`error.reason` has the admin's reason) |
| `account_suspended` | 403 | Show the message; admin deactivated the account |
| `ip_banned` | 403 | Show the message |
| `forbidden` | 403 | Show the message |
| `not_found` | 404 | Show the message |
| `conflict` | 409 | e.g. single slip already bought |
| `rate_limited` | 429 | Wait 60 s (`Retry-After` header) |
| `payment_error` | 502 | Payment gateway problem, let the user retry |
| `server_error` | 500 | Show the message, retry later |

---

## 2. Login (no password, same as web)

1. `POST /auth/login` `{ "phone": "0712345678", "device_id": "<uuid>", "device_name": "Tecno Spark", "platform": "android", "app_version": "1.0.0" }`
   - Number exists → `data.action = "login"` + `data.token`.
   - New number → `data.action = "need_confirmation"` (no token yet). Ask the user to type the number again.
2. `POST /auth/confirm` `{ "phone": "...", "phone_confirm": "...", "device_id": "..." }` → creates the account (HTTP 201, `action = "register"`) and returns `data.token`.

Save `data.token` in secure storage and send it on every request:

```
Authorization: Bearer <token>
```

If your hosting strips the `Authorization` header, use `X-Auth-Token: <token>` instead.

**device_id**: create a UUID once on first launch and keep it. The same `device_id` is how the server knows it is the same phone.
**One phone per account**: logging in on a new phone logs the old phone out (old phone gets `session_kicked`). To make it ban the account like the web app does, set `API_ONE_DEVICE_MODE = 'ban'` at the top of `api.php`.
Tokens last 365 days. `POST /auth/logout` ends the session. `GET /auth/check` tells you if the token is still valid.

---

## 3. Endpoints

🔒 = token required. Others work for guests too (with a token they return personal data such as `is_following`, `is_purchased`, unlocked codes).

### App setup
| Method | Path | Description |
|---|---|---|
| GET | `/config` | Packages (prices, durations, features text), networks, companies, links, PIN-safety / 18+ / disclaimer text, privacy policy, terms |
| GET | `/packages` | Packages only |
| GET | `/home` | Home screen in one call: hero slides, tipsters, today's slips (if subscribed), locked preview (if not), single slips, companies |
| GET | `/docs` | All endpoints |

### Auth & profile
| Method | Path | Description |
|---|---|---|
| POST | `/auth/login` | `phone, device_id, device_name?, platform?, app_version?` |
| POST | `/auth/confirm` | `phone, phone_confirm, device_id` |
| POST 🔒 | `/auth/logout` | |
| GET 🔒 | `/auth/check` | |
| GET 🔒 | `/me` | User, subscription, payments, today's slips, history, favourites, bought singles |
| POST 🔒 | `/me/phone` | Change phone `{phone}` |
| GET 🔒 | `/me/payments` | `?limit=20` |
| GET 🔒 | `/me/subscription` | Active package or null |
| POST 🔒 | `/me/push-token` | Save FCM token `{push_token, platform}` |

### Payments (SonicPesa)
| Method | Path | Description |
|---|---|---|
| POST 🔒 | `/orders/package` | `{package_type: normal\|tanzanite\|vip\|vvip, phone?, network?}` → `order_id` |
| POST 🔒 | `/orders/single` | `{betslip_id, phone?}` → `order_id` |
| GET 🔒 | `/orders/status?order_id=...` | `status: pending \| completed \| failed`. When completed it also returns the new `subscription` (or the unlocked `betslip` for a single) |

Payment flow in the app:
1. Call `/orders/package` (or `/orders/single`). The user gets a payment message on their phone.
2. Show "Thibitisha malipo kwenye simu yako" with a 60 s timer. **Never ask for the PIN inside the app** (show `config.notices.pin_safety`).
3. Poll `/orders/status` every 2 s, max 30 times. Stop on `completed` (show congrats) or `failed` (show error).

Prices always come from the server. If the user pays again before the package ends, the new time is added on top of the remaining time.

### Slips
| Method | Path | Description |
|---|---|---|
| GET 🔒 | `/slips/today` | Today's slips for the user's package level |
| GET 🔒 | `/slips/history` | `?limit=20` |
| GET | `/slips/preview` | Locked preview of today's slip |
| GET | `/slips/{id}` | One slip |

### Single slips (buy one by one)
| Method | Path | Description |
|---|---|---|
| GET | `/singles` | All single slips for sale (`is_purchased` per user) |
| GET 🔒 | `/singles/mine` | Singles I bought |
| GET 🔒 | `/singles/{id}/purchased` | `{is_purchased}` |

### Tipsters
| Method | Path | Description |
|---|---|---|
| GET | `/tipsters` | All tipsters |
| GET 🔒 | `/tipsters/followed` | Favourites |
| GET | `/tipsters/{id}` | Profile + slips + single slips + achievements + `system_betslip` when the tipster has no slips |
| GET | `/tipsters/{id}/tips` | Tips (or system slip) |
| GET 🔒 | `/tipsters/{id}/last10` | Last 10 slips |
| GET | `/tipsters/{id}/singles` | Single slips of the tipster |
| GET | `/tipsters/{id}/system-slip` | System slip |
| POST 🔒 | `/tipsters/{id}/follow` | |
| POST/DELETE 🔒 | `/tipsters/{id}/unfollow` | |

### Betting companies
| Method | Path | Description |
|---|---|---|
| GET | `/companies` | |
| GET | `/companies/{id}/slips` | Slips from one company |
| GET | `/companies/search?q=` | Search by match text / booking code / company |

### Popups
| Method | Path | Description |
|---|---|---|
| GET 🔒 | `/popups/win` | Won slip today (once per day). Call on app start |
| GET 🔒 | `/popups/new-win` | Slip marked WON in the last 5 min. Poll every ~10 s while the app is open |
| GET 🔒 | `/popups/warnings` | Account warning (3+ failed payments in 24 h or admin warning) |
| POST 🔒 | `/popups/dismiss` | "Usionyeshe tena" `{popup_type: win_popup\|warning_popup}` |
| POST 🔒 | `/popups/reset` | Show popups again `{popup_type?}` |
| POST 🔒 | `/warnings/{id}/read` | Mark warning as read (`warning_id` from `/popups/warnings`) |

### Tipster tools (only users with `is_tipster = 1`)
| Method | Path | Description |
|---|---|---|
| GET 🔒 | `/tipster/slips` | My slips |
| POST 🔒 | `/tipster/slips` | Create `{booking_code, match_details, odds, company_id, price, package_type, is_single_slip, image_url?, validity_time?}` |
| POST/PUT 🔒 | `/tipster/slips/{id}` | Edit (results / counters stay admin-only) |
| POST/DELETE 🔒 | `/tipster/slips/{id}/delete` | Delete |

The tipster needs a completed subscription on their account (admin can add one) so their slips appear in the lists.

---

## 4. Objects

**Slip**

```json
{
  "id": 10, "booking_code": "SYS***", "is_locked": true,
  "match_details": "Arsenal vs Chelsea, Simba vs Ya…", "odds": "55.2",
  "image_url": null, "slip_type": "system", "package_type": "normal",
  "is_single_slip": false, "price": 3000,
  "result_status": "pending", "result_icon": null,
  "created_date": "2026-10-26", "is_today": true,
  "validity_time": "2026-10-27 11:12:25", "validity_ts": 1793088745, "seconds_left": 84500, "is_expired": false,
  "company": { "id": 1, "name": "BETPAWA", "code": "BETPAWA", "logo_url": "https://..." },
  "tipster": { "id": 1, "name": "Tipster X", "avatar": null, "rating": 5.0, "verified": false },
  "is_purchased": false
}
```

- `is_locked: true` → the server already masked the code (`ABC***`) and cut `match_details`. Show the blur + "LIPIA SASA" button. The full code is never sent to users who haven't paid.
- `is_purchased` only exists on single slips.
- `result_status`: `pending | won | lost`.
- Show the countdown from `validity_ts` and `meta.server_time`.
- Always show slip text as plain text (`Text(...)`), never as HTML.

**Tipster**: `id, name, bio, avatar, rating, success_rate, total_tips, won_tips, tips_count, active_tips_count, single_slips_count, followers_count, verified, badge, is_following`. Only show a verified tick when `verified` is `true`.

**Subscription**: `id, package_type, package_amount, label, badge, payment_status, start_date, end_date, end_ts, seconds_left`.

---

## 5. Dart example

```dart
// pubspec: http, flutter_secure_storage, uuid
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String code, message;
  final int status;
  ApiException(this.code, this.message, this.status);
  bool get mustLogin => ['login_required', 'unauthorized', 'token_expired', 'session_kicked'].contains(code);
  @override
  String toString() => message;
}

class MikekaApi {
  static const base = 'https://mikekaapp.co.tz/api.php';
  String? token;
  final String deviceId;
  MikekaApi(this.deviceId, {this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Device-Id': deviceId,
        if (token != null) 'Authorization': 'Bearer $token',
        if (token != null) 'X-Auth-Token': token!,
      };

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? q]) async =>
      _handle(await http.get(Uri.parse('$base/$path').replace(queryParameters: q), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async =>
      _handle(await http.post(Uri.parse('$base/$path'), headers: _headers, body: jsonEncode(body ?? {})));

  Map<String, dynamic> _handle(http.Response r) {
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['success'] == true) return (j['data'] as Map).cast<String, dynamic>();
    final e = (j['error'] as Map).cast<String, dynamic>();
    throw ApiException(e['code'] ?? 'error', e['message'] ?? 'Hitilafu', r.statusCode);
  }

  // Login: returns null when the number is new and must be confirmed
  Future<Map<String, dynamic>?> login(String phone) async {
    final d = await post('auth/login', {'phone': phone, 'device_id': deviceId, 'platform': 'android'});
    if (d['action'] == 'need_confirmation') return null;
    token = d['token'];
    return d;
  }

  Future<Map<String, dynamic>> confirm(String phone, String again) async {
    final d = await post('auth/confirm', {'phone': phone, 'phone_confirm': again, 'device_id': deviceId, 'platform': 'android'});
    token = d['token'];
    return d;
  }

  // Package payment with polling
  Future<String> payPackage(String type, String phone) async {
    final o = await post('orders/package', {'package_type': type, 'phone': phone});
    final orderId = o['order_id'] as String;
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final s = await get('orders/status', {'order_id': orderId});
      if (s['status'] == 'completed') return 'completed';
      if (s['status'] == 'failed') return 'failed';
    }
    return 'timeout';
  }
}
```

---

## 6. Server notes

- `api.php` is at `https://mikekaapp.co.tz/api.php` (constant `API_PUBLIC_URL`). The web app address is `WEB_APP_URL` (`https://odds-mikeka.mikekaapp.co.tz/`); `config.links` uses it for `users.php`. Change both at the top of `api.php` if you move things.
- The web app (`mikeka_app_v13_2.php`) must have been opened at least once so its tables exist. `api.php` adds three tables of its own: `api_tokens`, `api_push_tokens`, `api_rate_limits`.
- Payments made from the app use `https://mikekaapp.co.tz/api.php?webhook=sonicpesa` as callback. Every webhook is re-checked with SonicPesa before anything is unlocked.
- Secrets: put `.mikeka_secrets.php` in your cPanel home folder (`/home/<cpanel-user>/`, outside `public_html`). `api.php` finds it there, so the main domain and the subdomain share one file. Env vars `MIKEKA_DB_PASS`, `MIKEKA_SP_KEY` also work.
- Logs: `api_err.log`, `api_fatal.log` next to `api.php`.
- If Apache strips the `Authorization` header, add this to `.htaccess`:

```
RewriteEngine On
RewriteCond %{HTTP:Authorization} .
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
```
