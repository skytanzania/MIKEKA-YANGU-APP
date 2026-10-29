# MIKEKA APP — FLUTTER MOBILE APPLICATION

Programu kamili ya simu ya Mikeka ya Leo Tanzania (Single-File Complete Flutter App).
Huu mradi umejengwa kwa kutumia faili kamili la Dart (`lib/main.dart`) linalounganishwa na **MIKEKA APP REST API v1**:
`https://mikekaapp.co.tz/api.php` — orodha ya endpoints: `https://mikekaapp.co.tz/api.php?route=docs`.

Maelezo kamili ya API (endpoints, majibu, error codes, mfano wa Dart): [`docs/API.md`](docs/API.md).

---

## 📱 Miundombinu ya Flutter (Flutter Architecture)

- **Faili la Dart**: `/lib/main.dart` (ina mistari 1,000+ ya msimbo kamili bila kuhitaji faili zingine).
- **Faili la Configuration**: `/pubspec.yaml` (ina dependencies zote zinazohitajika: `http`, `flutter_secure_storage`, `shared_preferences`, `url_launcher`, `device_info_plus`, `flutter_local_notifications`).
- **Web Simulation & Preview**: Programu ya React/Vite inayoiga na kuendesha UI, API calls, na tabia za Flutter kwa 100%.

---

## 🚀 Jinsi ya Kuendesha kwenye Flutter (Run with Flutter)

Ili kujenga na kuendesha APK ya Android au toleo la iOS/Web kwa kutumia Flutter CLI:

```bash
# 1. Hakikisha una Flutter SDK iliyowekwa
flutter --version

# 2. Pakua package zote
flutter pub get

# 3. Endesha kwenye kifaa kilichounganishwa (au Emulator)
flutter run

# 4. Kujenga APK ya Android:
flutter build apk --release
```

### 📦 APK kupitia GitHub Actions

- Kila `push` kwenye `main` inajenga APK moja kwa moja (`.github/workflows/build-apk.yml`).
- Pakua APK: **Actions** → chagua run iliyofanikiwa → **Artifacts** → `mikeka-app-release-apk`.
- Faili la Play Store (AAB iliyosainiwa): **Artifacts** → `mikeka-app-playstore-aab` → pakia `app-release.aab` kwenye Google Play Console.
- AAB inasainiwa kwa "upload key" iliyohifadhiwa kwenye **Settings → Secrets and variables → Actions**:
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
  Kama secrets hazipo, APK bado inajengwa lakini AAB inarukwa.
- ⚠️ Usiweke keystore (`.jks`) wala `android/key.properties` kwenye repo hii — ni ya umma (public).
- 📲 **"App not installed" kwenye simu?** Android inakubali update tu kama APK mpya imesainiwa kwa key ileile ya APK iliyopo kwenye simu.
  Bila secrets, kila build inasainiwa kwa debug key mpya ya bahati nasibu → simu inakataa. Suluhisho:
  1. Weka secrets 4 za `ANDROID_*` hapo juu (key moja ya kudumu kwa builds zote).
  2. Kwenye simu, **ondoa (uninstall) MIKEKA APP ya zamani mara moja**, kisha sakinisha APK mpya. Builds zinazofuata zitajisasisha bila kuondoa.
  - Ukurasa wa kila run (Summary) unaonyesha kama APK imesainiwa kwa key ya kudumu au debug key.
- Version code inaongezeka yenyewe kila build (`github.run_number`); badilisha version name kwenye `pubspec.yaml`.
- Flutter imefungwa kwenye toleo **3.38.10** (Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20). Folda ya `android/` imetengenezwa kwa toleo hilo — usiifute wala kuitengeneza upya kwa `flutter create`.
- Ukitaka kupandisha Flutter, pandisha pia plugins (`flutter_local_notifications`, `device_info_plus`) na matoleo ya Gradle kwenye `android/settings.gradle.kts` kwa pamoja.

### 🌐 Web App (bure)

Toleo la web linajengwa kutoka `lib/main.dart` ileile (`.github/workflows/web.yml`) kila `push` kwenye `main`:

- **GitHub Pages (bure):** https://skytanzania.github.io/MIKEKA-YANGU-APP/
  (mara ya kwanza: **Settings → Pages → Source: GitHub Actions**).
- **cPanel (mikekaapp.co.tz/app/):** Actions → run → Artifacts → `mikeka-web-cpanel` → fungua zip ndani ya `public_html/app/`.
  Hapa hakuna haja ya CORS kwa sababu web app na `api.php` ziko kwenye domain moja.
- Ukitumia GitHub Pages, `api.php` lazima iruhusu CORS kwa `https://skytanzania.github.io`.
- Watumiaji wanaweza "Add to Home Screen" (PWA) kwenye Android, iPhone na kompyuta.

---

## ✨ Vipengele Muhimu Vilivyojumuishwa (Features Included)

1. **Tipsters Tab**:
   - Orodha ya Tipsters maarufu Tanzania (Fundi majamvi, Master Mikeka Tz, KIBOKO YA MUHINDI, MZEE WA TRENI, GWIJI WA MIKEKA, n.k.)
   - Alama za uhakiki (Blue verified check)
   - Ukadiriaji wa nyota (Star rating)
   - Asilimia ya ushindi (Win rate %) na idadi ya tips
   - Kufuata / Kutofuata (Follow / Following toggle)
   - Ukurasa maalum wa taarifa za Tipster (`TipsterDetailScreen`)

2. **Mikeka ya Leo Tab**:
   - Orodha ya mikeka ya VIP na ya siku
   - Booking code zilizofichwa kwa wasio na kifurushi (`***`) na wazi kwa waliolipia
   - Nakili booking code (1-click copy)
   - Odds na takwimu za mechi
   - Vifurushi:
     - **NORMAL**: TSh 3,000/= (Siku 1 / Masaa 24)
     - **TANZANITE**: TSh 5,000/= (Siku 3 / Masaa 72)
     - **VIP**: TSh 10,000/= (Siku 7 / Wiki 1)
     - **VVIP**: TSh 30,000/= (Siku 30 / Mwezi 1)

3. **Single Slips Tab**:
   - Mikeka ya kununua mmoja mmoja kwa bei nafuu
   - Malipo ya moja kwa moja kwa kila mkeka
   - Orodha ya "Mikeka Yangu ya Single" iliyonunuliwa

4. **Profile Tab**:
   - Taarifa za akaunti na namba ya simu
   - Kaunta ya muda uliobaki wa kifurushi
   - Kubadilisha namba ya simu
   - Historia ya malipo yote (Completed / Pending)
   - Kiungo cha ukurasa wa washindi (`users.php`)
   - Kutoka kwenye akaunti (Logout)

5. **Malipo na USSD**:
   - Usaidizi wa mitandao yote: Vodacom, YAS, Airtel, Halotel
   - Uthibitishaji wa USSD push ("Angalia Simu Yako")
   - Polling ya hadhi ya malipo kila sekunde 2
   - Dirisha maalum la pongezi ya ushindi na malipo (Victory celebration)

6. **Tahadhari & Ushindi**:
   - Popup ya ushindi wa leo app inapofunguliwa (`popups/win`) na ukaguzi wa ushindi mpya kila sekunde 20 (`popups/new-win`)
   - Onyesho la kombe la dhahabu 🏆 ("UMESHINDA!") + "Usionyeshe tena" (`popups/dismiss`)
   - Tahadhari za akaunti (malipo yaliyoshindikana mara nyingi, ujumbe wa admin) (`popups/warnings`)
   - Session inakaguliwa kila sekunde 60 (`auth/check`): ukiingia kwenye simu nyingine, ukifungiwa au ukisitishwa na admin, app inakutoa na kuonyesha sababu

7. **Tipster Tools** (kwa akaunti zenye `is_tipster = 1`):
   - Profile → "Mikeka Yangu (Tipster)": kuona, kuweka, kuficha na kufuta mikeka yako (pamoja na mikeka ya SINGLE yenye bei)

8. **Usalama & Uwazi**:
   - App haiulizi PIN ya mobile money kamwe — PIN inawekwa kwenye ujumbe wa USSD wa mtandao tu
   - Booking code zinafichwa na **server** (`ABC***`) kwa wasiolipia — code kamili haitumwi kwenye simu yao
   - Sera ya Faragha, Vigezo na Masharti, onyo la 18+ na msaada (`admin@mikekaapp.co.tz`) vinatoka kwenye `GET config`

---

## 🔌 Jinsi App Inavyotumia API v1

| Kazi kwenye app | Endpoint |
|---|---|
| Kuanza app (bei, vifurushi, mitandao, links, sera) | `GET config` |
| Kuingia / kujisajili | `POST auth/login` → (namba mpya) `POST auth/confirm` → `token` |
| Taarifa zote za mtumiaji | `GET me` |
| Tipsters / profile ya tipster | `GET tipsters`, `GET tipsters/{id}` |
| Kufuata / kuacha kufuata | `POST tipsters/{id}/follow`, `POST tipsters/{id}/unfollow` |
| Mkeka wa leo (preview kwa wasiolipia) | `GET slips/preview` |
| Mikeka ya single | `GET singles`, `GET singles/mine` |
| Kulipia kifurushi / mkeka single | `POST orders/package`, `POST orders/single`, kisha `GET orders/status` kila sekunde 2 |
| Kubadilisha namba / historia ya malipo | `POST me/phone`, `GET me/payments` |
| Popups | `GET popups/win`, `GET popups/new-win`, `GET popups/warnings`, `POST popups/dismiss`, `POST warnings/{id}/read` |
| Tipster tools | `GET/POST tipster/slips`, `POST tipster/slips/{id}`, `POST tipster/slips/{id}/delete` |
| Kutoka | `POST auth/logout` |

- Token inahifadhiwa kwenye `flutter_secure_storage` na kutumwa kama `Authorization: Bearer <token>` (pia `X-Auth-Token`).
- Kila simu inapata `device_id` yake ya kudumu (inatengenezwa mara moja). Akaunti moja = simu moja: ukiingia kwenye simu nyingine, ya zamani inatolewa (`session_kicked`).
- Muda wa vifurushi na mikeka unahesabiwa kwa saa ya **server** (`meta.server_time`), sio saa ya simu.
- Kubadilisha anwani ya API: `AppConfig.API_BASE` juu ya `lib/main.dart`.
