// ============================================================
// MIKEKA APP - FLUTTER MOBILE APPLICATION
// Single-file app for the MIKEKA APP REST API v1:
//   https://mikekaapp.co.tz/api.php   (docs: https://mikekaapp.co.tz/api.php?route=docs)
//
// - Login with phone number -> Bearer token (stored in secure storage)
// - One phone per account: logging in on another phone logs this one out
// - Prices, packages, networks, links and notices come from GET config
// - Booking codes are masked by the SERVER for users who have not paid
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Navigator used for app-wide dialogs (session kicked / banned)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ============================================================
// MAIN ENTRY POINT
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConfig.initialize();
  } catch (e) {
    // Never die on the launch screen: fall back to plain prefs and keep going.
    debugPrint('AppConfig.initialize failed: $e');
    await AppConfig.ensureFallback();
  }
  ApiClient.onAuthError = handleAuthError;
  runApp(const MikekaApp());
}

// ============================================================
// APP CONFIGURATION
// ============================================================
class AppConfig {
  static const String API_BASE = 'https://mikekaapp.co.tz/api.php';
  static const String APP_NAME = 'MIKEKA APP';
  static const String VERSION = '1.5.0';
  static const String DEFAULT_WASHINDI_URL = 'https://odds-mikeka.mikekaapp.co.tz/users.php';
  static const String SUPPORT_EMAIL = 'admin@mikekaapp.co.tz';

  static late FlutterSecureStorage secureStorage;
  static late SharedPreferences prefs;
  static late DeviceInfoPlugin deviceInfo;
  static late FlutterLocalNotificationsPlugin notifications;

  /// Random id created once per install. The API uses it to know "same phone".
  static String? deviceId;
  static String? deviceModel;
  static String platform = 'android';

  static Future<void> initialize() async {
    secureStorage = const FlutterSecureStorage(
      // resetOnError: if the stored data can't be decrypted (e.g. after a
      // reinstall), wipe it instead of crashing on startup.
      aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    prefs = await SharedPreferences.getInstance();
    deviceInfo = DeviceInfoPlugin();
    if (!kIsWeb) notifications = FlutterLocalNotificationsPlugin();

    if (!kIsWeb) {
      // Local notifications have no browser implementation.
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings();
        const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
        await notifications.initialize(initSettings);
      } catch (_) {}
    }

    try {
      if (kIsWeb) {
        platform = 'web';
        final info = await deviceInfo.webBrowserInfo;
        deviceModel = 'Web ${info.browserName.name}';
      } else if (Platform.isAndroid) {
        platform = 'android';
        final info = await deviceInfo.androidInfo;
        deviceModel = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        platform = 'ios';
        final info = await deviceInfo.iosInfo;
        deviceModel = info.name;
      }
    } catch (_) {}

    deviceId = await _loadDeviceId();
  }

  /// Minimal setup used only if [initialize] threw, so every `late` field is set.
  static Future<void> ensureFallback() async {
    secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    );
    prefs = await SharedPreferences.getInstance();
    deviceInfo = DeviceInfoPlugin();
    if (!kIsWeb) notifications = FlutterLocalNotificationsPlugin();
    if (deviceId == null) {
      const key = 'mikeka_device_id';
      var id = prefs.getString(key);
      if (id == null || id.isEmpty) {
        final rnd = Random.secure();
        final hex = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        id = 'app-$platform-$hex';
        await prefs.setString(key, id);
      }
      deviceId = id;
    }
  }

  static Future<String> _loadDeviceId() async {
    const key = 'mikeka_device_id';
    String? id;
    try {
      id = await secureStorage.read(key: key);
    } catch (_) {}
    id ??= prefs.getString(key);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      final hex = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      id = 'app-$platform-$hex';
      try {
        await secureStorage.write(key: key, value: id);
      } catch (_) {}
      await prefs.setString(key, id);
    }
    return id;
  }
}

// ============================================================
// SERVER CLOCK (countdowns use server time, not the phone clock)
// ============================================================
class AppClock {
  static int _offsetSeconds = 0;

  static void sync(int serverUnix) {
    if (serverUnix <= 0) return;
    _offsetSeconds = serverUnix - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static int nowUnix() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + _offsetSeconds;

  /// Server timezone is Africa/Dar_es_Salaam (UTC+3, no daylight saving).
  static String serverDateTimeString(int unix) {
    final t = DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true).add(const Duration(hours: 3));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return 'IMEISHA';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    if (d > 0) return '${d}siku ${two(h)}:${two(m)}:${two(s)}';
    return '${two(h)}:${two(m)}:${two(s)}';
  }
}

// ============================================================
// THEME / COLORS
// ============================================================
class AppColors {
  static const Color bg = Color(0xFF000010);
  static const Color bg2 = Color(0xFF0A0A1A);
  static const Color card = Color(0xFF111122);
  static const Color card2 = Color(0xFF1A1A2E);
  static const Color accent = Color(0xFF00FFC8);
  static const Color accent2 = Color(0xFF00B4FF);
  static const Color gold = Color(0xFFFFD700);
  static const Color red = Color(0xFFFF0055);
  static const Color warn = Color(0xFFFF6B00);
  static const Color success = Color(0xFF00C853);
  static const Color tanzanite = Color(0xFF7B5CFF);
  static const Color muted = Color(0xFF8899AA);
  static const Color text = Color(0xFFE8EAF0);
  static const Color border = Color(0x14FFFFFF);
  static const Color verified = Color(0xFF1DA1F2);
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.accent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.card,
      error: AppColors.red,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.accent,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: AppColors.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.card2,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ============================================================
// JSON HELPERS (the API may send numbers as text and vice versa)
// ============================================================
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().toLowerCase() ?? '';
  return s == 'true' || s == '1' || s == 'yes';
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, dynamic>? _mapOrNull(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _list(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<String> _stringList(dynamic v) {
  if (v is! List) return <String>[];
  return v.map((e) => e.toString()).toList();
}

Color _hexColor(dynamic v, Color fallback) {
  final s = v?.toString().replaceAll('#', '') ?? '';
  if (s.length != 6) return fallback;
  final n = int.tryParse(s, radix: 16);
  return n == null ? fallback : Color(0xFF000000 | n);
}

String _formatMoney(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// "0712345678" / "255712345678" / "712345678" -> "255712345678"
String _normalizePhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10 && d.startsWith('0')) return '255${d.substring(1)}';
  if (d.length == 12 && d.startsWith('255')) return d;
  if (d.length == 9) return '255$d';
  return d;
}

bool _validPhone(String raw) {
  final p = _normalizePhone(raw);
  return p.length == 12 && p.startsWith('255');
}

// Slip field helpers (API v1 slip object)
String? _slipCompanyName(Map<String, dynamic> s) => _str(_map(s['company'])['name']) ?? _str(s['company_name']);
String? _slipCompanyLogo(Map<String, dynamic> s) => _str(_map(s['company'])['logo_url']) ?? _str(s['logo_url']);
Map<String, dynamic> _slipTipster(Map<String, dynamic> s) => _map(s['tipster']);
bool _slipLocked(Map<String, dynamic> s) => _asBool(s['is_locked']);

// ============================================================
// API CLIENT (REST v1 — Bearer token)
// ============================================================
typedef AuthErrorHandler = void Function(ApiResponse res);

class ApiClient {
  static const String _tokenKey = 'mikeka_api_token_v1';
  static const Duration _timeout = Duration(seconds: 25);
  static String? _cachedToken;
  static bool _tokenLoaded = false;

  /// Called when the server says the session is over (kicked / banned / expired).
  static AuthErrorHandler? onAuthError;

  static Future<String?> getToken() async {
    if (_tokenLoaded) return _cachedToken;
    try {
      _cachedToken = await AppConfig.secureStorage.read(key: _tokenKey);
    } catch (_) {
      _cachedToken = AppConfig.prefs.getString(_tokenKey);
    }
    _tokenLoaded = true;
    return _cachedToken;
  }

  static Future<void> setToken(String? token) async {
    _cachedToken = token;
    _tokenLoaded = true;
    try {
      if (token == null) {
        await AppConfig.secureStorage.delete(key: _tokenKey);
      } else {
        await AppConfig.secureStorage.write(key: _tokenKey, value: token);
      }
    } catch (_) {
      if (token == null) {
        await AppConfig.prefs.remove(_tokenKey);
      } else {
        await AppConfig.prefs.setString(_tokenKey, token);
      }
    }
  }

  static Future<bool> hasToken() async => (await getToken())?.isNotEmpty == true;

  static Future<Map<String, String>> _headers() async {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': AppConfig.deviceId ?? '',
      'X-App-Version': AppConfig.VERSION,
    };
    // Some shared-hosting firewalls block the default "Dart/x.y" agent.
    // (Browsers send their own User-Agent and refuse to change it.)
    if (!kIsWeb) h['User-Agent'] = 'Mozilla/5.0 (Linux; Android) MikekaApp/${AppConfig.VERSION}';
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
      h['X-Auth-Token'] = token; // used when the host strips Authorization
    }
    return h;
  }

  // ---- Web version only ----------------------------------------------
  // A browser follows redirects by itself and turns a redirected POST into a
  // GET, so the server answers "Method hairuhusiwi". We find the address
  // api.php really answers on once, then always call that address directly.
  static Uri? _webBase;
  static Future<void>? _webBaseCheck;

  static Uri get _base {
    if (_webBase != null) return _webBase!;
    if (kIsWeb) {
      // Served from mikekaapp.co.tz (e.g. /app/): call the API on the same
      // origin, so no CORS and no www / non-www redirect.
      final page = Uri.base;
      if (page.host == 'mikekaapp.co.tz' || page.host.endsWith('.mikekaapp.co.tz')) {
        return Uri(scheme: page.scheme, host: page.host, port: page.hasPort ? page.port : null, path: '/api.php');
      }
    }
    return Uri.parse(AppConfig.API_BASE);
  }

  static Future<void> _resolveWebBase() async {
    final client = http.Client();
    try {
      final start = _uri('config');
      final r = await client.send(http.Request('GET', start)).timeout(_timeout);
      if (r case http.BaseResponseWithUrl(:final url)) {
        if (url.host != start.host || url.path != start.path || url.scheme != start.scheme) {
          _webBase = Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null, path: url.path);
          debugPrint('API base redirected to $_webBase');
        }
      }
      await r.stream.drain<void>();
    } catch (_) {
      // Keep the default address; the real request will report any problem.
    } finally {
      client.close();
    }
  }

  /// Uses ?route= so it works even when the host disables PATH_INFO.
  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final route = path.startsWith('/') ? path.substring(1) : path;
    final q = <String, String>{'route': route};
    query?.forEach((k, v) {
      if (v != null) q[k] = v.toString();
    });
    return _base.replace(queryParameters: q);
  }

  static Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  static Future<ApiResponse> post(String path, {Map<String, dynamic>? data}) =>
      _send('POST', path, body: data);

  static Future<ApiResponse> delete(String path) => _send('DELETE', path);

  static Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    if (kIsWeb) {
      final check = _webBaseCheck ??= _resolveWebBase();
      // Only POST/DELETE break on redirects; GETs start straight away.
      if (method != 'GET') await check;
    }
    final hadToken = await hasToken();
    late http.Response res;
    try {
      final uri = _uri(path, query);
      final headers = await _headers();
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(_timeout);
      } else if (method == 'DELETE') {
        res = await http.delete(uri, headers: headers).timeout(_timeout);
      } else {
        final clean = <String, dynamic>{};
        body?.forEach((k, v) {
          if (v != null) clean[k] = v;
        });
        final payload = jsonEncode(clean);
        res = await http.post(uri, headers: headers, body: payload).timeout(_timeout);
        // package:http does not follow redirects for POST. If the host
        // redirects (http→https, non-www→www, …) re-send the same POST to the
        // new address instead of reading the redirect page as the answer.
        var target = uri;
        for (var hop = 0; hop < 3 && const [301, 302, 303, 307, 308].contains(res.statusCode); hop++) {
          final loc = res.headers['location'];
          if (loc == null || loc.isEmpty) break;
          target = target.resolve(loc);
          res = await http.post(target, headers: headers, body: payload).timeout(_timeout);
        }
      }
    } on TimeoutException {
      return ApiResponse.network('Mtandao unachelewa. Jaribu tena.');
    } catch (_) {
      return ApiResponse.network('Hitilafu ya mtandao. Angalia internet.');
    }

    final r = ApiResponse.fromHttp(res);
    if (!r.success && hadToken && (r.isBanned || r.isKicked || r.isLoginRequired)) {
      onAuthError?.call(r);
    }
    return r;
  }
}

class ApiResponse {
  final bool success;
  final int statusCode;
  final Map<String, dynamic> data;
  final String? errorCode;
  final String? error;
  final Map<String, dynamic> errorInfo;

  ApiResponse({
    required this.success,
    this.statusCode = 200,
    this.data = const {},
    this.errorCode,
    this.error,
    this.errorInfo = const {},
  });

  factory ApiResponse.network(String message) =>
      ApiResponse(success: false, statusCode: 0, errorCode: 'network', error: message);

  factory ApiResponse.fromHttp(http.Response res) {
    final json = _decodeLenient(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (json == null) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      debugPrint('API bad response HTTP ${res.statusCode}: '
          '${body.length > 300 ? body.substring(0, 300) : body}');
      return ApiResponse(
        success: false,
        statusCode: res.statusCode,
        errorCode: 'bad_response',
        // The HTTP code tells us where to look (403 = firewall, 500 = PHP error,
        // 301/302 = redirect, 200 = PHP printed something that isn't JSON).
        error: 'Jibu la seva si sahihi (HTTP ${res.statusCode}). Jaribu tena.',
      );
    }

    final meta = json['meta'];
    if (meta is Map && meta['server_time'] != null) {
      AppClock.sync(_asInt(meta['server_time']));
    }

    if (json['success'] == true) {
      final d = json['data'];
      return ApiResponse(
        success: true,
        statusCode: res.statusCode,
        data: d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{'value': d},
      );
    }

    final e = json['error'] is Map
        ? Map<String, dynamic>.from(json['error'] as Map)
        : <String, dynamic>{'code': 'error', 'message': json['error']?.toString()};
    return ApiResponse(
      success: false,
      statusCode: res.statusCode,
      errorCode: e['code']?.toString(),
      error: e['message']?.toString() ?? 'Hitilafu. Jaribu tena.',
      errorInfo: e,
    );
  }

  /// Parses the API JSON even when PHP printed a BOM, a warning or a notice
  /// around it (common on shared hosting after a PHP upgrade).
  static Map<String, dynamic>? _decodeLenient(String body) {
    Map<String, dynamic>? tryObj(String s) {
      try {
        final d = jsonDecode(s);
        return d is Map ? Map<String, dynamic>.from(d) : null;
      } catch (_) {
        return null;
      }
    }

    var s = body.trim();
    if (s.startsWith('﻿')) s = s.substring(1).trim();
    final direct = tryObj(s);
    if (direct != null) return direct;

    // Look for the API envelope {"success": ...} inside the extra output.
    final end = s.lastIndexOf('}');
    if (end < 0) return null;
    var start = s.indexOf('{"success"');
    if (start < 0) start = s.indexOf('{');
    while (start >= 0 && start < end) {
      final obj = tryObj(s.substring(start, end + 1));
      if (obj != null && obj.containsKey('success')) return obj;
      start = s.indexOf('{', start + 1);
    }
    return null;
  }

  dynamic operator [](String key) => data[key];

  bool get isNetworkError => errorCode == 'network';
  bool get isBanned => const ['account_banned', 'account_suspended', 'ip_banned'].contains(errorCode);
  bool get isKicked => errorCode == 'session_kicked';
  bool get isLoginRequired => const ['login_required', 'unauthorized', 'token_expired'].contains(errorCode);
  String? get banReason => _str(errorInfo['reason']);
}

// ============================================================
// PACKAGES (from GET config, with built-in fallback)
// ============================================================
class PackageInfo {
  final String type;
  final String name;
  final String title;
  final String label;
  final String badge;
  final String note;
  final String highlight;
  final int price;
  final int level;
  final Color color;
  final List<String> features;

  const PackageInfo({
    required this.type,
    required this.name,
    required this.title,
    required this.label,
    required this.badge,
    required this.note,
    required this.highlight,
    required this.price,
    required this.level,
    required this.color,
    required this.features,
  });

  IconData get icon {
    switch (type) {
      case 'vvip':
        return Icons.workspace_premium;
      case 'vip':
        return Icons.star;
      case 'tanzanite':
        return Icons.diamond;
      default:
        return Icons.calendar_today;
    }
  }

  factory PackageInfo.fromJson(Map<String, dynamic> j) {
    final type = j['type']?.toString() ?? 'normal';
    final fb = PackageInfo.fallback(type);
    return PackageInfo(
      type: type,
      name: _str(j['name']) ?? fb.name,
      title: _str(j['title']) ?? fb.title,
      label: _str(j['label']) ?? fb.label,
      badge: _str(j['badge']) ?? fb.badge,
      note: _str(j['note']) ?? fb.note,
      highlight: _str(j['highlight']) ?? fb.highlight,
      price: j['price'] != null ? _asInt(j['price']) : fb.price,
      level: j['level'] != null ? _asInt(j['level']) : fb.level,
      color: _hexColor(j['color'], fb.color),
      features: j['features'] is List ? _stringList(j['features']) : fb.features,
    );
  }

  static PackageInfo fallback(String type) =>
      defaults.firstWhere((p) => p.type == type, orElse: () => defaults.first);

  static const List<PackageInfo> defaults = [
    PackageInfo(
      type: 'normal', name: 'NORMAL', title: 'KIFURUSHI NORMAL', label: 'Siku 1 (Masaa 24)', badge: 'SIKU 1',
      note: 'Inaisha siku 1 (masaa 24) baada ya malipo',
      highlight: 'Matumizi siku 1 (masaa 24) kamili — lipia leo, tumia siku nzima!',
      price: 3000, level: 1, color: AppColors.accent2,
      features: ['mikeka mingi ndani ya siku 1', 'Odds 50–100', 'Booking code ya kila kampuni', 'Mikeka iliyochambuliwa na mafundi', 'Mikeka 10 kutoka kampuni na tipsters wote'],
    ),
    PackageInfo(
      type: 'tanzanite', name: 'TANZANITE', title: 'KIFURUSHI TANZANITE', label: 'Siku 3 (Masaa 72)', badge: 'SIKU 3',
      note: 'Inaisha siku 3 (masaa 72) baada ya malipo',
      highlight: 'Matumizi ya app siku 3 (masaa 72) mikeka ya ligi ya tanzania!',
      price: 5000, level: 2, color: AppColors.tanzanite,
      features: ['Mkeka wa TANZANITE maalum kwa ligi ya tanzania kwa siku 3', 'Odds 50–100 zilizochambuliwa na mafundi', 'Mikeka iliyochambuliwa na magwiji wetu', 'Booking code mpya kila siku', 'mikeka hatari ya ligi ya tanzania'],
    ),
    PackageInfo(
      type: 'vip', name: 'VIP', title: 'KIFURUSHI VIP', label: 'Siku 7 (Wiki 1)', badge: 'SIKU 7',
      note: 'Inaisha siku 7 (wiki 1) baada ya malipo',
      highlight: 'Matumizi ya app siku 7 (wiki 1) kamili — thamani bora kwa wiki!',
      price: 10000, level: 3, color: AppColors.gold,
      features: ['Mkeka wa VIP kwa siku 7', 'Odds 50–100 (VIP)', 'Msaada wa moja kwa moja', 'Mikeka ya moto kutoka kwa mafundi wetu', 'Odds ZA MOTO 🔥 (VIP)', 'Mikeka 70 mfululizo kila siku mikeka 10'],
    ),
    PackageInfo(
      type: 'vvip', name: 'VVIP', title: 'KIFURUSHI VVIP', label: 'Siku 30 (Mwezi 1)', badge: 'SIKU 30',
      note: 'Inaisha siku 30 (mwezi 1) baada ya malipo',
      highlight: 'Matumizi ya app siku 30 (mwezi 1) kamili — thamani kubwa kwa mwezi!',
      price: 30000, level: 4, color: AppColors.red,
      features: ['Mikeka ya VVIP ya hali ya juu', 'Odds VVIP ZA MOTO 🔥 za AI', 'Huduma ya dharura', 'Msaada wa haraka kutoka admin', 'Mikeka 300 mfululizo kila siku mikeka 10', 'Ushauri wa ziada wa kipekee'],
    ),
  ];
}

class NetworkInfo {
  final String name;
  final String code;
  final String initial;
  final Color color;
  final String? logoUrl; // from GET config (networks[].logo_url), optional
  const NetworkInfo(this.name, this.code, this.initial, this.color, [this.logoUrl]);

  /// Mobile-money name shown on the card for each network code.
  String get wallet {
    switch (code.toLowerCase()) {
      case 'vodacom':
      case 'mpesa':
      case 'm-pesa':
        return 'M-PESA';
      case 'yas':
      case 'tigo':
      case 'mixx':
        return 'MIXX BY YAS';
      case 'airtel':
        return 'AIRTEL MONEY';
      case 'halotel':
      case 'halopesa':
        return 'HALOPESA';
      default:
        return name.toUpperCase();
    }
  }

  /// Bundled logo file: assets/networks/<code>.png (see assets/networks/README.md).
  String get assetPath => 'assets/networks/${code.toLowerCase()}.png';

  static const List<NetworkInfo> defaults = [
    NetworkInfo('M-PESA', 'vodacom', 'M', Color(0xFFE60000)),
    NetworkInfo('MIXX BY YAS', 'yas', 'Y', Color(0xFF0033A1)),
    NetworkInfo('AIRTEL MONEY', 'airtel', 'A', Color(0xFFE40000)),
    NetworkInfo('HALOPESA', 'halotel', 'H', Color(0xFFF26522)),
  ];
}

/// Network logo: server logo → bundled PNG → coloured badge with the wallet name.
class NetworkLogo extends StatelessWidget {
  final NetworkInfo net;
  final double height;
  const NetworkLogo({super.key, required this.net, this.height = 34});

  Widget _badge() => Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: net.color, borderRadius: BorderRadius.circular(8)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(net.wallet,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, height: 1.05)),
        ),
      );

  Widget _asset() => Image.asset(net.assetPath,
      height: height, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _badge());

  @override
  Widget build(BuildContext context) {
    final url = _absUrl(net.logoUrl);
    final logo = url != null
        ? _netImage(url, height: height, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _asset())
        : _asset();
    return Container(
      height: height + 8,
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Center(child: logo),
    );
  }
}

// ============================================================
// APP STATE (GLOBAL)
// ============================================================
class AppState extends ChangeNotifier {
  static final AppState I = AppState._();
  AppState._();

  static const String _configCacheKey = 'mikeka_config_cache_v1';

  // --- account ---
  bool loggedIn = false;
  bool isTipster = false;
  bool isSubscribed = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? subscription;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> todaysSlips = [];
  List<Map<String, dynamic>> allSlips = [];
  List<Map<String, dynamic>> followedTipsters = [];
  List<Map<String, dynamic>> purchasedSingleSlips = [];
  List<String> dismissedPopups = [];
  String? displayPhone;

  // --- app config (GET config) ---
  List<PackageInfo> packages = List<PackageInfo>.from(PackageInfo.defaults);
  List<NetworkInfo> networks = List<NetworkInfo>.from(NetworkInfo.defaults);
  List<Map<String, dynamic>> companies = [];
  List<HeroSlide> heroSlides = [];
  String washindiUrl = AppConfig.DEFAULT_WASHINDI_URL;
  String supportEmail = AppConfig.SUPPORT_EMAIL;
  String pinSafetyNotice =
      'MIKEKA APP haitakuuliza PIN yako ya M-Pesa, Mixx by Yas, Airtel Money au HaloPesa kwenye app. PIN unaiweka kwenye simu yako tu, kwenye ujumbe wa malipo (USSD) wa mtandao wako.';
  String responsibleNotice =
      '18+ Cheza kwa uwajibikaji. Kubeti kuna hatari ya kupoteza pesa — hakuna mkeka wenye uhakika wa kushinda 100%.';
  String disclaimer =
      'MIKEKA APP ni huduma ya uchambuzi wa mikeka, Tanzania. Hatuhusiani na wala hatuwakilishi kampuni yoyote ya kubeti wala mtandao wowote wa simu.';
  List<String> privacyPolicy = [];
  List<String> terms = [];
  int pollIntervalSeconds = 2;
  int maxPolls = 30;

  PackageInfo packageByType(String type) =>
      packages.firstWhere((p) => p.type == type, orElse: () => PackageInfo.fallback(type));

  // ------------------------------------------------------------
  /// Uses the saved config straight away; the fresh copy from the server
  /// is applied when it arrives (start-up never waits for it when cached).
  Future<void> loadConfig() async {
    final cached = AppConfig.prefs.getString(_configCacheKey);
    var hadCache = false;
    if (cached != null) {
      try {
        _applyConfig(Map<String, dynamic>.from(jsonDecode(cached) as Map));
        hadCache = true;
      } catch (_) {}
    }
    final fresh = _fetchConfig();
    if (!hadCache) await fresh;
  }

  Future<void> _fetchConfig() async {
    final res = await ApiClient.get('config');
    if (res.success) {
      _applyConfig(res.data);
      await AppConfig.prefs.setString(_configCacheKey, jsonEncode(res.data));
      notifyListeners();
    }
  }

  void _applyConfig(Map<String, dynamic> c) {
    final pk = _list(c['packages']);
    if (pk.isNotEmpty) packages = pk.map(PackageInfo.fromJson).toList();
    final nw = _list(c['networks']);
    if (nw.isNotEmpty) {
      networks = nw
          .map((n) => NetworkInfo(
                n['name']?.toString() ?? '',
                n['code']?.toString() ?? '',
                n['initial']?.toString() ?? '?',
                _hexColor(n['color'], AppColors.accent2),
                _str(n['logo_url']) ?? _str(n['logo']) ?? _str(n['icon']),
              ))
          .toList();
    }
    companies = _list(c['companies']);
    final slides = HeroSlide.parse(c);
    if (slides.isNotEmpty) heroSlides = slides;
    final links = _map(c['links']);
    washindiUrl = _str(links['washindi_page']) ?? washindiUrl;
    supportEmail = _str(c['support_email']) ?? supportEmail;
    final notices = _map(c['notices']);
    pinSafetyNotice = _str(notices['pin_safety']) ?? pinSafetyNotice;
    responsibleNotice = _str(notices['responsible_gambling']) ?? responsibleNotice;
    disclaimer = _str(notices['disclaimer']) ?? disclaimer;
    privacyPolicy = _stringList(c['privacy_policy']);
    terms = _stringList(c['terms']);
    final poll = _map(c['payment_poll']);
    if (poll.isNotEmpty) {
      pollIntervalSeconds = max(1, _asInt(poll['interval_seconds']));
      maxPolls = max(5, _asInt(poll['max_polls']));
    }
  }

  // ------------------------------------------------------------
  /// Reloads everything about the logged-in user (GET me).
  Future<ApiResponse> refresh() async {
    final res = await ApiClient.get('me');
    if (res.success) applyMe(res.data);
    return res;
  }

  void applyMe(Map<String, dynamic> d) {
    user = _map(d['user']);
    displayPhone = _str(user?['display_phone']) ?? _str(user?['phone_number']);
    subscription = _mapOrNull(d['subscription']);
    payments = _list(d['payments']);
    todaysSlips = _list(d['todays_slips']);
    allSlips = _list(d['all_slips']);
    followedTipsters = _list(d['followed_tipsters']);
    purchasedSingleSlips = _list(d['purchased_single_slips']);
    isTipster = _asBool(d['is_tipster']);
    isSubscribed = _asBool(d['is_subscribed']);
    loggedIn = true;
    if (isSubscribed) mikekaCount = todaysSlips.length;
    notifyListeners();
  }

  void setLoggedOut() {
    loggedIn = false;
    isTipster = false;
    isSubscribed = false;
    user = null;
    subscription = null;
    payments = [];
    todaysSlips = [];
    allSlips = [];
    followedTipsters = [];
    purchasedSingleSlips = [];
    dismissedPopups = [];
    displayPhone = null;
    notifyListeners();
  }

  bool isPopupDismissed(String type) => dismissedPopups.contains(type);

  // ------------------------------------------------------------
  // Badges on the bottom menu: how many slips are available right now.
  int mikekaCount = 0;
  int singlesCount = 0;
  Future<void>? _countsJob;

  /// Today's slips available (for subscribers: the slips they can open;
  /// for others: how many are waiting behind the paywall).
  void setMikekaCount(int n) {
    if (n == mikekaCount) return;
    mikekaCount = n;
    notifyListeners();
  }

  /// Single slips the user can still buy (not bought yet, not expired).
  void setSinglesFromList(List<Map<String, dynamic>> slips) {
    final now = AppClock.nowUnix();
    final n = slips.where((x) {
      if (_asBool(x['is_purchased'])) return false;
      final until = _asInt(x['validity_ts']);
      return until == 0 || until > now;
    }).length;
    if (n == singlesCount) return;
    singlesCount = n;
    notifyListeners();
  }

  Future<void> refreshCounts() => _countsJob ??= _loadCounts().whenComplete(() => _countsJob = null);

  Future<void> _loadCounts() async {
    final results = await Future.wait([ApiClient.get('singles'), ApiClient.get('home')]);
    final singles = results[0];
    final home = results[1];
    if (singles.success) setSinglesFromList(_list(singles['slips']));
    if (isSubscribed) {
      setMikekaCount(todaysSlips.length);
    } else if (home.success) {
      final d = home.data;
      var n = 0;
      for (final k in ['todays_count', 'today_count', 'todays_slips_count', 'slips_today_count', 'total_today']) {
        if (d[k] != null) {
          n = _asInt(d[k]);
          break;
        }
      }
      final preview = _map(d['preview']);
      if (n == 0) n = _asInt(preview['total'] ?? preview['count']);
      if (n == 0) n = _list(d['todays_slips']).length;
      if (n == 0 && (d['preview'] is Map || d['locked_preview'] is Map || d['preview_slip'] is Map)) n = 1;
      setMikekaCount(n);
    }
  }
}

// ============================================================
// SESSION ENDED (kicked / banned / expired) — app-wide
// ============================================================
bool _authDialogOpen = false;

void handleAuthError(ApiResponse res) async {
  if (_authDialogOpen) return;
  _authDialogOpen = true;
  await ApiClient.setToken(null);
  AppState.I.setLoggedOut();

  final ctx = appNavigatorKey.currentContext;
  if (ctx == null) {
    _authDialogOpen = false;
    return;
  }

  final banned = res.isBanned;
  final kicked = res.isKicked;
  final title = banned
      ? (res.errorCode == 'account_suspended' ? 'AKAUNTI IMESITISHWA' : 'AKAUNTI IMEFUNGWA')
      : kicked
          ? 'UMETOLEWA KWENYE AKAUNTI'
          : 'INGIA TENA';
  final reason = res.banReason;
  final message = [
    res.error ?? 'Tafadhali ingia tena.',
    if (reason != null && reason.isNotEmpty) '\nSababu: $reason',
    if (banned) '\nKwa msaada: ${AppState.I.supportEmail}',
  ].join();

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (dCtx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            Icon(banned ? Icons.block : Icons.logout, color: banned ? AppColors.red : AppColors.warn),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: banned ? AppColors.red : AppColors.warn,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppColors.text, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('SAWA', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    ),
  );

  _authDialogOpen = false;
  appNavigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (r) => false,
  );
}

// ============================================================
// ROOT APP WIDGET
// ============================================================
class MikekaApp extends StatelessWidget {
  const MikekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: appNavigatorKey,
      // Web: open the home screen at once (it shows skeletons while data
      // loads). Phones keep the short splash.
      home: kIsWeb ? const _WebStart() : const SplashScreen(),
    );
  }
}

/// Web start: no logo screen. Config and login load in the background and
/// the tabs reload themselves when the login state arrives.
class _WebStart extends StatefulWidget {
  const _WebStart();
  @override
  State<_WebStart> createState() => _WebStartState();
}

class _WebStartState extends State<_WebStart> {
  @override
  void initState() {
    super.initState();
    () async {
      await AppState.I.loadConfig();
      if (await ApiClient.hasToken()) await AppState.I.refresh();
    }();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AppState.I.loadConfig();
    if (await ApiClient.hasToken()) {
      // Errors like kicked/banned are handled by handleAuthError.
      await AppState.I.refresh();
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF001A1A), AppColors.bg],
            radius: 1.2,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino, size: 90, color: AppColors.accent),
              SizedBox(height: 20),
              Text(
                'MIKEKA APP',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mikeka ya Leo Tanzania',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              SizedBox(height: 40),
              Shimmer(
                child: Column(children: [
                  _SplashBar(width: 160),
                  SizedBox(height: 8),
                  _SplashBar(width: 100),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBar extends StatelessWidget {
  final double width;
  const _SplashBar({required this.width});
  @override
  Widget build(BuildContext context) => _bone(width: width, height: 8, radius: 4);
}

// ============================================================
// HOME SCREEN (Bottom Navigation)
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _sessionTimer;
  Timer? _winTimer;
  Timer? _countsTimer;
  bool _wasLoggedIn = false;
  bool _popupOpen = false;

  final List<Widget> _screens = const [
    TipstersTab(),
    MikekaTab(),
    SingleSlipsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppState.I.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStateChanged());
    AppState.I.refreshCounts();
    _countsTimer = Timer.periodic(const Duration(minutes: 2), (_) => AppState.I.refreshCounts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppState.I.removeListener(_onStateChanged);
    _stopTimers();
    _countsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppState.I.refreshCounts();
    if (state == AppLifecycleState.resumed && AppState.I.loggedIn) {
      AppState.I.refresh();
      _checkNewWin();
    }
  }

  void _onStateChanged() {
    final loggedIn = AppState.I.loggedIn;
    if (loggedIn != _wasLoggedIn) AppState.I.refreshCounts();
    if (loggedIn && !_wasLoggedIn) {
      _wasLoggedIn = true;
      _startTimers();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkPopupsOnOpen());
    } else if (!loggedIn && _wasLoggedIn) {
      _wasLoggedIn = false;
      _stopTimers();
    }
  }

  void _startTimers() {
    _stopTimers();
    // Kicked / banned / expired come back as errors -> handleAuthError()
    _sessionTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (AppState.I.loggedIn) ApiClient.get('auth/check');
    });
    _winTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkNewWin());
  }

  void _stopTimers() {
    _sessionTimer?.cancel();
    _winTimer?.cancel();
    _sessionTimer = null;
    _winTimer = null;
  }

  Future<void> _checkPopupsOnOpen() async {
    if (!mounted || !AppState.I.loggedIn) return;
    final win = await ApiClient.get('popups/win');
    if (win.success && _asBool(win['show_popup']) && win['betslip'] != null) {
      await _showWinPopup(_map(win['betslip']));
    }
    if (!mounted || !AppState.I.loggedIn) return;
    final warn = await ApiClient.get('popups/warnings');
    if (warn.success && _asBool(warn['show_warning'])) {
      await _showWarningPopup(
        warn['message']?.toString() ?? 'Kuna jambo linahitaji uangalie.',
        warn['severity']?.toString() ?? 'medium',
        _asInt(warn['warning_id']),
      );
    }
  }

  Future<void> _checkNewWin() async {
    if (!mounted || !AppState.I.loggedIn || _popupOpen) return;
    final res = await ApiClient.get('popups/new-win');
    if (res.success && _asBool(res['show_popup']) && res['betslip'] != null) {
      await _showWinPopup(_map(res['betslip']));
      AppState.I.refresh();
    }
  }

  Future<void> _showWinPopup(Map<String, dynamic> slip) async {
    if (!mounted || _popupOpen) return;
    _popupOpen = true;
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A1A00), Color(0xFF1A3A00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.success, width: 3),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              const Text(
                'UMESHINDA!',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'MKEKA WAKO UMESHINDAAA! 🎯',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _winRow('Booking Code', slip['booking_code']?.toString() ?? '---'),
              _winRow('Odds', slip['odds']?.toString() ?? '--'),
              _winRow('Kampuni', _slipCompanyName(slip) ?? '--'),
              _winRow('Tarehe', slip['created_date']?.toString() ?? '--'),
              const SizedBox(height: 16),
              const Text(
                'Hongera sana! Endelea kufuatilia mikeka yetu kwa ushindi zaidi! 💪🔥',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ASANTE SANA!'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ApiClient.post('popups/dismiss', data: {'popup_type': 'win_popup'});
                  AppState.I.dismissedPopups.add('win_popup');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Usionyeshe tena ujumbe huu',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
    _popupOpen = false;
  }

  Widget _winRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarningPopup(String message, String severity, int warningId) async {
    if (!mounted || _popupOpen) return;
    _popupOpen = true;
    final isHigh = severity == 'high' || severity == 'critical';
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1A00), Color(0xFF1A0A00)],
            ),
            border: Border.all(color: isHigh ? AppColors.red : AppColors.warn, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHigh ? Icons.error : Icons.warning_amber_rounded,
                color: isHigh ? AppColors.red : AppColors.warn,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                isHigh ? 'TAHADHARI KUBWA!' : 'TAHADHARI YA AKAUNTI',
                style: TextStyle(
                  color: isHigh ? AppColors.red : AppColors.warn,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHigh ? AppColors.red : AppColors.warn,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (warningId > 0) await ApiClient.post('warnings/$warningId/read');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('NIMEKUELEWA'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ApiClient.post('popups/dismiss', data: {'popup_type': 'warning_popup'});
                  AppState.I.dismissedPopups.add('warning_popup');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Usionyeshe tena ujumbe huu',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
    _popupOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.I,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.people_alt_outlined, 'active': Icons.people_alt, 'label': 'Tipsters'},
      {
        'icon': Icons.confirmation_num_outlined,
        'active': Icons.confirmation_num,
        'label': 'Mikeka',
        'badge': AppState.I.mikekaCount,
        'badgeColor': AppColors.red,
      },
      {
        'icon': Icons.track_changes_outlined,
        'active': Icons.track_changes,
        'label': 'Single',
        'badge': AppState.I.singlesCount,
        'badgeColor': AppColors.gold,
      },
      {'icon': Icons.person_outline, 'active': Icons.person, 'label': AppState.I.loggedIn ? 'Profile' : 'Ingia'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF00A0A19),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == _index;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _index = i);
                if (AppState.I.loggedIn && (i == 1 || i == 3)) AppState.I.refresh();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        active ? items[i]['active'] as IconData : items[i]['icon'] as IconData,
                        color: active ? AppColors.accent : AppColors.muted,
                        size: 22,
                      ),
                      if ((items[i]['badge'] as int? ?? 0) > 0)
                        Positioned(
                          right: -10,
                          top: -6,
                          child: _navBadge(items[i]['badge'] as int, items[i]['badgeColor'] as Color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i]['label'] as String,
                    style: TextStyle(
                      color: active ? AppColors.accent : AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Small red/gold number on a bottom-menu icon.
Widget _navBadge(int n, Color color) {
  return Container(
    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF0A0A19), width: 1.5),
    ),
    child: Text(n > 99 ? '99+' : '$n',
        style: TextStyle(
          color: color == AppColors.gold ? Colors.black : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1.1,
        )),
  );
}

// ============================================================
// SHARED: reload a tab when the user logs in / out
// ============================================================
mixin ReloadOnLogin<T extends StatefulWidget> on State<T> {
  bool _lastLoggedIn = AppState.I.loggedIn;

  Future<void> reload();

  void _authListener() {
    if (AppState.I.loggedIn != _lastLoggedIn) {
      _lastLoggedIn = AppState.I.loggedIn;
      if (mounted) reload();
    }
  }

  @override
  void initState() {
    super.initState();
    AppState.I.addListener(_authListener);
  }

  @override
  void dispose() {
    AppState.I.removeListener(_authListener);
    super.dispose();
  }
}

Widget _errorState(String message, VoidCallback onRetry) {
  return ListView(
    children: [
      const SizedBox(height: 100),
      const Icon(Icons.wifi_off, size: 56, color: AppColors.muted),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(message,
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: AppColors.accent),
          label: const Text('JARIBU TENA', style: TextStyle(color: AppColors.accent)),
        ),
      ),
    ],
  );
}

Widget _sectionTitle(String text, {Color color = AppColors.gold, Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

Widget _countBadge(int n, {Color color = AppColors.red, Color textColor = Colors.white}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text('$n', style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w900)),
  );
}

Widget _avatar(String? url, String name, double size, {Color textColor = AppColors.accent}) {
  final initial = Text(
    name.isNotEmpty ? name[0].toUpperCase() : 'T',
    style: TextStyle(color: textColor, fontSize: size * 0.38, fontWeight: FontWeight.w900),
  );
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(colors: [AppColors.accent, AppColors.gold]),
      border: Border.all(color: AppColors.bg, width: 2),
    ),
    child: ClipOval(
      child: (url != null && url.startsWith('http'))
          ? _netImage(
              url,
              fit: BoxFit.cover,
              loadingBuilder: _imageSkeleton,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.card2,
                alignment: Alignment.center,
                child: initial,
              ),
            )
          : Container(color: AppColors.card2, alignment: Alignment.center, child: initial),
    ),
  );
}

Widget _verifiedTick(double size) {
  return Container(
    padding: EdgeInsets.all(size * 0.2),
    decoration: BoxDecoration(
      color: AppColors.verified,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.card, width: 2),
    ),
    child: Icon(Icons.check, size: size, color: Colors.white),
  );
}

// ============================================================
// SKELETON LOADING (shimmer placeholders used across the app)
// ============================================================
/// Sweeps a light band across every [_bone] inside [child].
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: const [AppColors.card2, Color(0xFF2A2A44), AppColors.card2],
          stops: const [0.1, 0.3, 0.4],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          transform: _SlideGradient(_c.value * 3 - 1.5),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double percent;
  const _SlideGradient(this.percent);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// One grey placeholder block.
Widget _bone({double? width, double height = 12, double radius = 8, bool circle = false}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.card2,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

Widget _skeletonFrame({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

Widget _skeletonTipsterCard() {
  return _skeletonFrame(
    child: Column(
      children: [
        _bone(width: 64, height: 64, circle: true),
        const SizedBox(height: 10),
        _bone(width: 90, height: 12),
        const SizedBox(height: 6),
        _bone(width: 50, height: 10),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _bone(width: 44, height: 14, radius: 10),
          _bone(width: 44, height: 14, radius: 10),
        ]),
        const SizedBox(height: 8),
        _bone(width: 70, height: 9),
        const Spacer(),
        _bone(width: double.infinity, height: 32, radius: 12),
      ],
    ),
  );
}

Widget _skeletonSlipCard() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _skeletonFrame(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _bone(width: 32, height: 32, circle: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bone(width: 120, height: 12),
                const SizedBox(height: 6),
                _bone(width: 70, height: 9),
              ]),
            ),
            _bone(width: 56, height: 20, radius: 10),
          ]),
          const SizedBox(height: 14),
          _bone(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          _bone(width: 200, height: 12),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _bone(height: 40, radius: 12)),
            const SizedBox(width: 10),
            _bone(width: 90, height: 40, radius: 12),
          ]),
        ],
      ),
    ),
  );
}

Widget _skeletonListTile() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Row(children: [
      _bone(width: 28, height: 28, circle: true),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _bone(width: 110, height: 12),
          const SizedBox(height: 6),
          _bone(width: 160, height: 9),
        ]),
      ),
      _bone(width: 60, height: 10),
    ]),
  );
}

/// Home (Tipsters tab) while loading: slider, filter chips, tipster grid.
Widget skeletonHome() {
  return Shimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        _bone(width: double.infinity, height: 250, radius: 18),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3; i++)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _bone(width: i == 0 ? 18 : 7, height: 7)),
        ]),
        const SizedBox(height: 16),
        _bone(width: 110, height: 14),
        const SizedBox(height: 14),
        Row(children: [_bone(width: 86, height: 32, radius: 16), const SizedBox(width: 8), _bone(width: 120, height: 32, radius: 16)]),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: List.generate(4, (_) => _skeletonTipsterCard()),
        ),
      ],
    ),
  );
}

/// Lists of slips (Mikeka, Single, tipster's own slips).
Widget skeletonSlipList({int count = 4, bool withHeader = true}) {
  return Shimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        if (withHeader) ...[
          _bone(width: double.infinity, height: 80, radius: 16),
          const SizedBox(height: 16),
          _bone(width: 140, height: 14),
          const SizedBox(height: 14),
        ],
        for (var i = 0; i < count; i++) _skeletonSlipCard(),
      ],
    ),
  );
}

/// Tipster profile page.
Widget skeletonProfile() {
  return Shimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: _bone(width: 96, height: 96, circle: true)),
        const SizedBox(height: 14),
        Center(child: _bone(width: 150, height: 16)),
        const SizedBox(height: 8),
        Center(child: _bone(width: 90, height: 11)),
        const SizedBox(height: 18),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _bone(height: 58, radius: 14)),
          ],
        ]),
        const SizedBox(height: 16),
        _bone(width: double.infinity, height: 44, radius: 12),
        const SizedBox(height: 20),
        _bone(width: 130, height: 14),
        const SizedBox(height: 14),
        _skeletonSlipCard(),
        _skeletonSlipCard(),
      ],
    ),
  );
}

/// Plain rows (payments history etc.).
Widget skeletonRows({int count = 6}) {
  return Shimmer(
    child: Column(children: List.generate(count, (_) => _skeletonListTile())),
  );
}

/// Image.network loadingBuilder that shows a shimmer block until the image arrives.
Widget _imageSkeleton(BuildContext context, Widget child, ImageChunkEvent? progress) {
  if (progress == null) return child;
  return Shimmer(child: _bone(width: double.infinity, height: double.infinity, radius: 0));
}

// ============================================================
// HERO SLIDER (sliding images at the top of the home tab)
// ============================================================
class HeroSlide {
  final String? image;
  final String title;
  final String? subtitle;
  final String? link; // https://… opens in the in-app browser; app://packages opens packages
  final List<Color> colors;

  const HeroSlide({this.image, required this.title, this.subtitle, this.link, required this.colors});

  static String? _absolute(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return Uri.parse(AppConfig.API_BASE).resolve(url).toString();
  }

  static const _palettes = [
    [Color(0xFF003B36), Color(0xFF000010)],
    [Color(0xFF2A1060), Color(0xFF000010)],
    [Color(0xFF4A3300), Color(0xFF000010)],
    [Color(0xFF00284A), Color(0xFF000010)],
  ];

  /// Accepts the slide list from GET config or GET home under any of the
  /// usual key names, so it keeps working if the API names change.
  static List<HeroSlide> parse(Map<String, dynamic> data) {
    dynamic raw;
    for (final k in ['hero_slides', 'slides', 'hero', 'banners', 'sliders', 'slider']) {
      if (data[k] is List) {
        raw = data[k];
        break;
      }
      if (data[k] is Map && _map(data[k])['items'] is List) {
        raw = _map(data[k])['items'];
        break;
      }
    }
    final out = <HeroSlide>[];
    for (final s in _list(raw)) {
      if (s.containsKey('is_active') && !_asBool(s['is_active'])) continue;
      final image = _absolute(_str(s['image_url']) ?? _str(s['image']) ?? _str(s['img']) ?? _str(s['banner']) ?? _str(s['photo']));
      final title = _str(s['title']) ?? _str(s['heading']) ?? _str(s['name']) ?? '';
      if (image == null && title.isEmpty) continue;
      out.add(HeroSlide(
        image: image,
        title: title,
        subtitle: _str(s['subtitle']) ?? _str(s['description']) ?? _str(s['text']) ?? _str(s['caption']),
        link: _str(s['link_url']) ?? _str(s['link']) ?? _str(s['target_url']) ?? _str(s['url']) ?? _str(s['action_url']),
        colors: _palettes[out.length % _palettes.length],
      ));
    }
    return out;
  }

  /// Shown when the server has no slides yet, so the slider is never empty.
  static List<HeroSlide> defaults() {
    final prices = AppState.I.packages.map((p) => p.price).where((p) => p > 0).toList()..sort();
    final from = prices.isEmpty ? '' : ' kuanzia TSh ${_formatMoney(prices.first)}';
    return [
      HeroSlide(
        title: 'MIKEKA YA LEO 🔥',
        subtitle: 'Mikeka mipya kila siku kutoka kwa tipsters bora Tanzania',
        link: 'app://packages',
        colors: _palettes[0],
      ),
      HeroSlide(
        title: 'VIFURUSHI VYA VIP 💎',
        subtitle: 'Fungua booking codes zote$from',
        link: 'app://packages',
        colors: _palettes[1],
      ),
      HeroSlide(
        title: 'WASHINDI WA LEO 🏆',
        subtitle: 'Angalia mikeka iliyoshinda leo',
        link: AppState.I.washindiUrl,
        colors: _palettes[2],
      ),
    ];
  }
}

class HeroSlider extends StatefulWidget {
  final List<HeroSlide> slides;
  final double height;
  const HeroSlider({super.key, required this.slides, this.height = 250});
  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  PageController _pc = PageController(viewportFraction: 0.94);
  double _fraction = 0.94;

  /// Slide width follows the screen: full width minus a small margin on
  /// phones, capped on tablets / computers so slides don't get too wide.
  void _fitTo(double screenWidth) {
    if (screenWidth <= 0) return;
    final slideWidth = (screenWidth - 24).clamp(280.0, 640.0);
    final f = (slideWidth + 8) / screenWidth;
    final fraction = f > 1 ? 1.0 : f;
    if ((fraction - _fraction).abs() < 0.01) return;
    final old = _pc;
    _fraction = fraction;
    _pc = PageController(viewportFraction: fraction, initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void didUpdateWidget(covariant HeroSlider old) {
    super.didUpdateWidget(old);
    if (_page >= widget.slides.length) _page = 0;
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_page + 1) % widget.slides.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _tap(HeroSlide s) async {
    final link = s.link;
    if (link == null || link.isEmpty) return;
    if (link == 'app://packages') {
      await startPackagePurchase(context);
    } else {
      await _openUrl(context, link, title: s.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    _fitTo(MediaQuery.sizeOf(context).width);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            // Pause auto-sliding while the user swipes, restart after.
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
              if (n is ScrollEndNotification) _startAuto();
              return false;
            },
            child: PageView.builder(
              controller: _pc,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _slide(slides[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _slide(HeroSlide s) {
    final gradientBg = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: s.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    );
    return GestureDetector(
      onTap: () => _tap(s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            gradientBg,
            if (s.image != null)
              _netImage(
                s.image!,
                fit: BoxFit.cover,
                loadingBuilder: _imageSkeleton,
                errorBuilder: (_, __, ___) => gradientBg,
              )
            else
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.casino, size: 150, color: Colors.white.withOpacity(0.06)),
              ),
            if (s.title.isNotEmpty || s.subtitle != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC000010)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.title.isNotEmpty)
                    Text(s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  if (s.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(s.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  if (s.link != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                      child: const Text('FUNGUA',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// IN-APP BROWSER (web links open inside MIKEKA APP)
// ============================================================
class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String? title;
  const InAppBrowserScreen({super.key, required this.url, this.title});
  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _firstLoadDone = false;
  String? _pageTitle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = null);
        },
        onPageFinished: (_) async {
          final t = await _web.getTitle();
          if (!mounted) return;
          setState(() {
            _firstLoadDone = true;
            _progress = 100;
            // Some pages have no <title> and WebView returns the URL instead.
            final clean = t?.trim() ?? '';
            if (clean.isNotEmpty && !clean.contains('://') && !RegExp(r'^[\w.-]+\.[a-z]{2,}(/.*)?$').hasMatch(clean)) {
              _pageTitle = clean;
            }
          });
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == false || !mounted) return;
          setState(() {
            _firstLoadDone = true;
            _error = 'Imeshindikana kufungua ukurasa. Angalia internet.';
          });
        },
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          if (u == null) return NavigationDecision.prevent;
          if (const ['http', 'https', 'about', 'data', 'blob', 'javascript'].contains(u.scheme)) {
            return NavigationDecision.navigate;
          }
          // tel:, mailto:, whatsapp:, intent:… need the phone's own app.
          _launchOutside(u);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _launchOutside(Uri u) async {
    try {
      if (u.scheme == 'intent') {
        final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(u.toString())?.group(1);
        if (fallback != null) {
          await _web.loadRequest(Uri.parse(Uri.decodeComponent(fallback)));
          return;
        }
      }
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _showSnack(context, 'Imeshindikana kufungua link.', isError: true);
    }
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          // The web address is never shown, only the page name.
          title: Text(
            (widget.title ?? _pageTitle ?? AppConfig.APP_NAME).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _web.reload())],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _firstLoadDone && _progress < 100
                ? LinearProgressIndicator(
                    value: _progress / 100, minHeight: 2, color: AppColors.accent, backgroundColor: Colors.transparent)
                : const SizedBox(height: 2),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _web),
            if (!_firstLoadDone) Positioned.fill(child: Container(color: AppColors.bg, child: _pageSkeleton())),
            if (_error != null)
              Positioned.fill(
                child: Container(color: AppColors.bg, child: _errorState(_error!, () => _web.reload())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageSkeleton() {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _bone(width: double.infinity, height: 150, radius: 14),
          const SizedBox(height: 18),
          _bone(width: 200, height: 16),
          const SizedBox(height: 12),
          for (var i = 0; i < 4; i++) ...[
            _bone(width: double.infinity, height: 11),
            const SizedBox(height: 8),
          ],
          _bone(width: 160, height: 11),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) _skeletonListTile(),
        ],
      ),
    );
  }
}

// ============================================================
// TIPSTERS TAB
// ============================================================
class TipstersTab extends StatefulWidget {
  const TipstersTab({super.key});
  @override
  State<TipstersTab> createState() => _TipstersTabState();
}

class _TipstersTabState extends State<TipstersTab> with ReloadOnLogin<TipstersTab> {
  List<Map<String, dynamic>> tipsters = [];
  bool loading = true;
  bool onlyFollowed = false;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    setState(() {
      // Skeleton only on the first load; pull-to-refresh keeps the content.
      loading = tipsters.isEmpty;
      error = null;
    });
    final results = await Future.wait([ApiClient.get('tipsters'), ApiClient.get('home')]);
    if (!mounted) return;
    final res = results[0];
    final home = results[1];
    setState(() {
      if (home.success) {
        final fromHome = HeroSlide.parse(home.data);
        if (fromHome.isNotEmpty) AppState.I.heroSlides = fromHome;
      }
      if (res.success) {
        tipsters = _list(res['tipsters']);
      } else if (home.success && _list(home['tipsters']).isNotEmpty) {
        tipsters = _list(home['tipsters']);
      } else {
        error = res.error;
      }
      loading = false;
    });
  }

  List<HeroSlide> get _slides =>
      AppState.I.heroSlides.isNotEmpty ? AppState.I.heroSlides : HeroSlide.defaults();

  Future<void> _toggleFollow(Map<String, dynamic> t) async {
    if (!AppState.I.loggedIn) {
      await _showLoginPrompt(context);
      return;
    }
    final id = _asInt(t['id']);
    final following = _asBool(t['is_following']);
    final res = await ApiClient.post('tipsters/$id/${following ? 'unfollow' : 'follow'}');
    if (!mounted) return;
    if (res.success) {
      setState(() {
        t['is_following'] = _asBool(res['is_following']);
        t['followers_count'] = _asInt(res['followers_count']);
      });
      _showSnack(context, res['message']?.toString() ?? 'Umefanikiwa!');
      AppState.I.refresh();
    } else {
      _showSnack(context, res.error ?? 'Hitilafu', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followedCount = tipsters.where((t) => _asBool(t['is_following'])).length;
    final visible = onlyFollowed ? tipsters.where((t) => _asBool(t['is_following'])).toList() : tipsters;

    return Scaffold(
      // No title bar: the slider is the first thing on the screen.
      // Pull down to refresh.
      body: SafeArea(
        bottom: false,
        child: loading
          ? skeletonHome()
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: reload,
              child: error != null && tipsters.isEmpty
                  ? _errorState(error!, reload)
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: HeroSlider(slides: _slides),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                            child: _sectionTitle('🔥 TIPSTERS', color: AppColors.accent),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: Text('Wote (${tipsters.length})'),
                                  selected: !onlyFollowed,
                                  onSelected: (_) => setState(() => onlyFollowed = false),
                                  selectedColor: AppColors.accent.withOpacity(0.2),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  avatar: const Icon(Icons.favorite, size: 14, color: AppColors.red),
                                  label: Text('Favourites ($followedCount)'),
                                  selected: onlyFollowed,
                                  onSelected: (_) async {
                                    if (!AppState.I.loggedIn) {
                                      await _showLoginPrompt(context);
                                      return;
                                    }
                                    setState(() => onlyFollowed = true);
                                  },
                                  selectedColor: AppColors.red.withOpacity(0.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (visible.isEmpty)
                          SliverToBoxAdapter(child: _emptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _tipsterCard(visible[i]),
                                childCount: visible.length,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 50, bottom: 50),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 60, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(onlyFollowed ? 'HUJAFUATA TIPSTER YEYOTE' : 'HAKUNA TIPSTERS BADO',
              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tipsterCard(Map<String, dynamic> t) {
    final name = (_str(t['name']) ?? 'Tipster');
    final verified = _asBool(t['verified']);
    final isFollowing = _asBool(t['is_following']);
    final rating = _asDouble(t['rating'], 5);
    final winRate = _asDouble(t['success_rate'], 75);
    final badge = _str(t['badge']);
    final followers = _asInt(t['followers_count']);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TipsterDetailScreen(tipsterId: _asInt(t['id']))),
        );
        if (mounted) reload();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.card, AppColors.card2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                _avatar(_str(t['avatar']), name, 64),
                if (verified) Positioned(right: 0, bottom: 0, child: _verifiedTick(10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w900),
            ),
            if (badge != null)
              Text('🏅 $badge',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 13),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip('${_asInt(t['tips_count'])}', 'tips'),
                _statChip('${winRate.toStringAsFixed(0)}%', 'win'),
              ],
            ),
            const SizedBox(height: 4),
            Text('$followers ${followers == 1 ? 'follower' : 'followers'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? AppColors.success.withOpacity(0.15) : AppColors.accent,
                  foregroundColor: isFollowing ? AppColors.success : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
                icon: Icon(isFollowing ? Icons.check : Icons.add, size: 14),
                label: Text(
                  isFollowing ? 'following' : 'follow',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _toggleFollow(t),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            TextSpan(text: label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TIPSTER DETAIL SCREEN
// ============================================================
class TipsterDetailScreen extends StatefulWidget {
  final int tipsterId;
  const TipsterDetailScreen({super.key, required this.tipsterId});
  @override
  State<TipsterDetailScreen> createState() => _TipsterDetailScreenState();
}

class _TipsterDetailScreenState extends State<TipsterDetailScreen> with ReloadOnLogin<TipsterDetailScreen> {
  Map<String, dynamic>? tipster;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    final res = await ApiClient.get('tipsters/${widget.tipsterId}');
    if (!mounted) return;
    setState(() {
      if (res.success && res['tipster'] != null) {
        tipster = _map(res['tipster']);
      } else {
        error = res.error ?? 'Tipster hapatikani.';
      }
      loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    if (!AppState.I.loggedIn) {
      await _showLoginPrompt(context);
      return;
    }
    final isFollowing = _asBool(tipster?['is_following']);
    final res = await ApiClient.post('tipsters/${widget.tipsterId}/${isFollowing ? 'unfollow' : 'follow'}');
    if (!mounted) return;
    if (res.success) {
      setState(() {
        tipster?['is_following'] = _asBool(res['is_following']);
        tipster?['followers_count'] = _asInt(res['followers_count']);
      });
      _showSnack(context, res['message']?.toString() ?? 'Ok');
      AppState.I.refresh();
    } else {
      _showSnack(context, res.error ?? 'Hitilafu', isError: true);
    }
  }

  Future<void> _buySingle(Map<String, dynamic> slip) async {
    final bought = await startSingleSlipPurchase(context, slip);
    if (bought && mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text((_str(tipster?['name']) ?? 'Tipster').toUpperCase())),
      body: loading
          ? skeletonProfile()
          : tipster == null
              ? _errorState(error ?? 'Tipster hapatikani', reload)
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _followButton(),
                      ..._achievements(),
                      ..._slips(),
                      ..._singleSlips(),
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    final t = tipster!;
    final name = _str(t['name']) ?? 'Tipster';
    final verified = _asBool(t['verified']);
    final rating = _asDouble(t['rating'], 5);
    final winRate = _asDouble(t['success_rate'], 75);
    final badge = _str(t['badge']);
    final bio = _str(t['bio']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.card, AppColors.card2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              _avatar(_str(t['avatar']), name, 88),
              if (verified) Positioned(right: 0, bottom: 0, child: _verifiedTick(14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
          if (verified)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('Tipster amethibitishwa',
                  style: TextStyle(color: AppColors.verified, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: Text('🏅 $badge',
                  style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: AppColors.gold, size: 18),
              const SizedBox(width: 4),
              Text('${rating.toStringAsFixed(1)} / 5.0',
                  style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statBox('${_asInt(t['followers_count'])}', 'Wafuasi'),
              _statBox('${_asInt(t['tips_count'])}', 'Tips'),
              _statBox('${winRate.toStringAsFixed(0)}%', 'Mafanikio'),
            ],
          ),
          if (bio != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      ],
    );
  }

  Widget _followButton() {
    final isFollowing = _asBool(tipster?['is_following']);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? AppColors.success.withOpacity(0.15) : AppColors.accent,
          foregroundColor: isFollowing ? AppColors.success : Colors.black,
        ),
        icon: Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
        label: Text(isFollowing ? 'following' : 'follow Tipster'),
        onPressed: _toggleFollow,
      ),
    );
  }

  List<Widget> _achievements() {
    final list = _list(tipster?['achievements']);
    if (list.isEmpty) return [];
    return [
      _sectionTitle('🏆 MAFANIKIO'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list
            .take(8)
            .map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                  ),
                  child: Text('${a['icon'] ?? '🏅'} ${a['name'] ?? ''}',
                      style: const TextStyle(color: AppColors.gold, fontSize: 10)),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _slips() {
    final slips = _list(tipster?['slips']);
    if (slips.isNotEmpty) {
      return [
        _sectionTitle('MIKEKA MIPYA', trailing: _countBadge(slips.length, color: AppColors.gold, textColor: Colors.black)),
        ...slips.map((s) => BetslipCard(slip: s)),
      ];
    }

    final sys = _mapOrNull(tipster?['system_betslip']);
    if (sys != null) {
      return [
        _sectionTitle('🤖 MKEKA WAKO UPO TAYARI'),
        BetslipCard(slip: sys, isSystemGenerated: true),
      ];
    }

    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
        child: const Text(
          'Tipster huyu hajatoa mikeka bado. Follow kupata taarifa mkeka ukiwa tayari.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ];
  }

  List<Widget> _singleSlips() {
    final single = _list(tipster?['single_slips']);
    if (single.isEmpty) return [];
    return [
      _sectionTitle('🎯 MIKEKA YA SINGLE', trailing: _countBadge(single.length, color: AppColors.gold, textColor: Colors.black)),
      ...single.map((s) => SingleSlipCard(slip: s, onBuy: () => _buySingle(s))),
    ];
  }
}

// ============================================================
// MIKEKA TAB
// ============================================================
class MikekaTab extends StatefulWidget {
  const MikekaTab({super.key});
  @override
  State<MikekaTab> createState() => _MikekaTabState();
}

class _MikekaTabState extends State<MikekaTab> with ReloadOnLogin<MikekaTab> {
  Map<String, dynamic>? previewSlip;
  bool loading = true;
  bool showHistory = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    setState(() => loading = true);
    if (AppState.I.loggedIn) {
      await AppState.I.refresh();
    }
    if (!AppState.I.isSubscribed) {
      final res = await ApiClient.get('slips/preview');
      previewSlip = res.success ? _mapOrNull(res['slip']) : null;
      final n = _asInt(res['total'] ?? res['count'] ?? res['todays_count']);
      if (n > 0) {
        AppState.I.setMikekaCount(n);
      } else if (previewSlip != null && AppState.I.mikekaCount == 0) {
        AppState.I.setMikekaCount(1);
      }
    } else {
      previewSlip = null;
      AppState.I.setMikekaCount(AppState.I.todaysSlips.length);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.I,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('MIKEKA YA LEO'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: reload)],
        ),
        body: loading
            ? skeletonSlipList()
            : RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.card,
                onRefresh: reload,
                child: _content(),
              ),
      ),
    );
  }

  Widget _content() {
    final s = AppState.I;
    if (!s.loggedIn || !s.isSubscribed) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!s.loggedIn) _guestBanner(),
          if (!s.loggedIn) const SizedBox(height: 16),
          _sectionTitle('🔒 MKEKA WA LEO UPO TAYARI — LIPIA UCHUKUE MKEKA WAKO'),
          if (previewSlip != null) BetslipCard(slip: previewSlip!, isBlurred: true) else _lockedCard(),
          const SizedBox(height: 12),
          _packagesGrid(),
        ],
      );
    }

    final sub = s.subscription;
    final pkg = s.packageByType(sub?['package_type']?.toString() ?? 'normal');
    final history = s.allSlips.where((x) => !_asBool(x['is_today'])).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sub != null) _activePackageBanner(sub, pkg),
        const SizedBox(height: 8),
        _sectionTitle('🔥 MIKEKA YA LEO — ${pkg.name}',
            trailing: _countBadge(s.todaysSlips.length)),
        if (s.todaysSlips.isEmpty)
          _emptySlipsCard()
        else
          ...s.todaysSlips.asMap().entries.map((e) => Column(
                children: [
                  if (e.key > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('───── MKEKA ${e.key + 1} ─────',
                          style: const TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1)),
                    ),
                  BetslipCard(slip: e.value),
                ],
              )),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => showHistory = !showHistory),
            child: _sectionTitle(
              '📅 MIKEKA ILIYOPITA (${history.length})',
              color: AppColors.accent2,
              trailing: Icon(showHistory ? Icons.expand_less : Icons.expand_more, color: AppColors.accent2),
            ),
          ),
          if (showHistory) ...history.map((x) => BetslipCard(slip: x)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => startPackagePurchase(context),
            icon: const Icon(Icons.bolt),
            label: const Text('LIPIA TENA — ONGEZA MUDA'),
          ),
        ),
      ],
    );
  }

  Widget _activePackageBanner(Map<String, dynamic> sub, PackageInfo pkg) {
    final end = _asInt(sub['end_ts']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warn.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warn.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(pkg.icon, color: pkg.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pkg.name} INAISHA (${sub['label'] ?? pkg.label})',
                    style: const TextStyle(color: AppColors.warn, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('INATUMIKA', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (end > 0)
            CountdownText(
              endUnix: end,
              style: const TextStyle(color: AppColors.warn, fontSize: 16, fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }

  Widget _guestBanner() {
    return InkWell(
      onTap: () => _showLoginPrompt(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.12), AppColors.gold.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.gold, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karibu Mikeka App!',
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Ingia au jisajili ili kuweza kununua mikeka na kufuata tipsters',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _lockedCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.card, AppColors.card2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.accent, size: 56),
          const SizedBox(height: 12),
          const Text('FUNGUA MKEKA',
              style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Lipia kifurushi chochote ili kuona mkeka wa leo!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => startPackagePurchase(context),
              icon: const Icon(Icons.bolt),
              label: const Text('LIPIA SASA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySlipsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.card, AppColors.card2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.access_time, color: AppColors.muted, size: 56),
          SizedBox(height: 12),
          Text('MKEKA HAUJAPAKIWA',
              style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(
            'Hongera! Tumepokea malipo yako. Wataalam wanasuka mikeka kwa ajili yako. Mkeka wa leo bado haujapakiwa. Tafadhali subiri ndani ya dakika chache kisha rudi tena.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _packagesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('CHAGUA KIFURUSHI'),
        ...AppState.I.packages.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PackageCard(
                package: p,
                onBuy: () => startPackagePurchase(context, packageType: p.type),
              ),
            )),
      ],
    );
  }
}

// ============================================================
// PACKAGE CARD (reusable)
// ============================================================
class PackageCard extends StatelessWidget {
  final PackageInfo package;
  final VoidCallback onBuy;
  const PackageCard({super.key, required this.package, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final p = package;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.bg2, p.color.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: TextStyle(color: p.color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.icon, color: p.color, size: 12),
                    const SizedBox(width: 4),
                    Text(p.badge, style: TextStyle(color: p.color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('TSh ${_formatMoney(p.price)}/=',
              style: const TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(p.note, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(p.highlight, style: TextStyle(color: p.color, fontSize: 11)),
          ),
          const SizedBox(height: 8),
          ...p.features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, color: AppColors.success, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: p.color, foregroundColor: Colors.black),
              onPressed: onBuy,
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text('LIPIA TSh ${_formatMoney(p.price)}/= — ${p.badge}'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SINGLE SLIPS TAB
// ============================================================
class SingleSlipsTab extends StatefulWidget {
  const SingleSlipsTab({super.key});
  @override
  State<SingleSlipsTab> createState() => _SingleSlipsTabState();
}

class _SingleSlipsTabState extends State<SingleSlipsTab> with ReloadOnLogin<SingleSlipsTab> {
  List<Map<String, dynamic>> slips = [];
  List<Map<String, dynamic>> purchased = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    final res = await ApiClient.get('singles');
    List<Map<String, dynamic>> mine = [];
    if (AppState.I.loggedIn) {
      final my = await ApiClient.get('singles/mine');
      if (my.success) mine = _list(my['slips']);
    }
    if (!mounted) return;
    setState(() {
      if (res.success) {
        slips = _list(res['slips']);
        AppState.I.setSinglesFromList(slips);
      } else {
        error = res.error;
      }
      purchased = mine;
      loading = false;
    });
  }

  Future<void> _buy(Map<String, dynamic> slip) async {
    final bought = await startSingleSlipPurchase(context, slip);
    if (bought && mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final forSale = slips.where((s) => !_asBool(s['is_purchased'])).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SINGLE SLIPS'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: reload)],
      ),
      body: loading
          ? skeletonSlipList(withHeader: false)
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: reload,
              child: error != null && slips.isEmpty
                  ? _errorState(error!, reload)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Slips the user already paid for come first.
                        if (AppState.I.loggedIn && purchased.isNotEmpty) ...[
                          _sectionTitle('✅ MIKEKA YANGU YA SINGLE (ULIYOLIPIA)',
                              color: AppColors.success,
                              trailing: _countBadge(purchased.length, color: AppColors.success, textColor: Colors.black)),
                          ...purchased.map((s) => SingleSlipCard(slip: s, purchased: true)),
                          const SizedBox(height: 12),
                        ],
                        _sectionTitle('🎯 MIKEKA YA SINGLE — NUNUA MMOJA MMOJA',
                            trailing: _countBadge(forSale.length, color: AppColors.gold, textColor: Colors.black)),
                        if (forSale.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                            child: const Column(
                              children: [
                                Icon(Icons.track_changes, color: AppColors.muted, size: 48),
                                SizedBox(height: 12),
                                Text('HAKUNA MIKEKA YA SINGLE',
                                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w900)),
                                SizedBox(height: 8),
                                Text(
                                  'Wataalam wetu hawajatoa mikeka ya single bado. Endelea kufuatilia!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          ...forSale.map((s) => SingleSlipCard(slip: s, onBuy: () => _buy(s))),
                      ],
                    ),
            ),
    );
  }
}

// ============================================================
// PROFILE TAB
// ============================================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.I,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PROFILE'),
            actions: [
              if (AppState.I.loggedIn)
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.red),
                  onPressed: () => _logout(context),
                ),
            ],
          ),
          body: AppState.I.loggedIn ? _loggedInBody() : _guestBody(),
        );
      },
    );
  }

  Widget _guestBody() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.person_outline, size: 80, color: AppColors.muted),
        const SizedBox(height: 16),
        const Center(
          child: Text('Karibu Mikeka App',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingia au jisajili ili kuweza kununua mikeka, kufuata tipsters, na kupata huduma zote.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLoginPrompt(context),
            icon: const Icon(Icons.login),
            label: const Text('INGIA / JISAJILI'),
          ),
        ),
        const SizedBox(height: 24),
        ..._infoTiles(context),
        _footer(),
      ],
    );
  }

  Widget _loggedInBody() {
    final s = AppState.I;
    final u = s.user ?? {};
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await s.refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withOpacity(0.1), AppColors.accent2.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person, size: 48, color: AppColors.accent),
                const SizedBox(height: 8),
                Text(
                  s.displayPhone ?? u['phone_number']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(u['name']?.toString() ?? 'Customer',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (s.isTipster) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⭐ TIPSTER',
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _subscriptionCard(s.subscription),
          const SizedBox(height: 16),
          if (s.isTipster)
            _actionTile(Icons.edit_note, 'Mikeka Yangu (Tipster)', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TipsterSlipsScreen()));
            }, color: AppColors.gold),
          _actionTile(Icons.phone, 'Badilisha Namba', () => _changePhone(context)),
          _actionTile(Icons.history, 'Historia ya Malipo', () => _showPayments(context)),
          _actionTile(Icons.emoji_events, 'Washindi', () => _openUrl(context, AppState.I.washindiUrl, title: 'WASHINDI')),
          ..._infoTiles(context),
          _actionTile(Icons.logout, 'Toka', () => _logout(context), color: AppColors.red),
          _footer(),
        ],
      ),
    );
  }

  List<Widget> _infoTiles(BuildContext context) {
    final s = AppState.I;
    return [
      _actionTile(Icons.privacy_tip_outlined, 'Sera ya Faragha', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PolicyScreen(title: 'SERA YA FARAGHA', paragraphs: s.privacyPolicy)));
      }),
      _actionTile(Icons.description_outlined, 'Vigezo na Masharti', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PolicyScreen(title: 'VIGEZO NA MASHARTI', paragraphs: s.terms)));
      }),
      _actionTile(Icons.mail_outline, 'Msaada: ${s.supportEmail}', () => _openUrl(context, 'mailto:${s.supportEmail}')),
    ];
  }

  Widget _footer() {
    final s = AppState.I;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          _noticeBox(s.responsibleNotice, icon: Icons.info_outline, color: AppColors.red),
          const SizedBox(height: 8),
          _noticeBox(s.pinSafetyNotice, icon: Icons.shield_outlined, color: AppColors.success),
          const SizedBox(height: 8),
          Text(s.disclaimer,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 10, height: 1.5)),
          const SizedBox(height: 8),
          Text('${AppConfig.APP_NAME} v${AppConfig.VERSION}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _subscriptionCard(Map<String, dynamic>? sub) {
    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 40),
            const SizedBox(height: 8),
            const Text('HAKUNA KIFURUSHI',
                style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => startPackagePurchase(context),
                child: const Text('LIPIA KUPATA MKEKA'),
              ),
            ),
          ],
        ),
      );
    }

    final pkg = AppState.I.packageByType(sub['package_type']?.toString() ?? 'normal');
    final endTs = _asInt(sub['end_ts']);
    final endDate = sub['end_date']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pkg.color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(pkg.icon, color: pkg.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('KIFURUSHI: ${pkg.name}',
                    style: TextStyle(color: pkg.color, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ACTIVE',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Muda: ${sub['label'] ?? pkg.label}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          if (endTs > 0)
            CountdownText(
              endUnix: endTs,
              prefix: 'Inabaki: ',
              style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          if (endDate.isNotEmpty)
            Text('Inaisha: $endDate', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
              onPressed: () => startPackagePurchase(context),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('LIPIA TENA — ONGEZA MUDA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        leading: Icon(icon, color: color ?? AppColors.accent),
        title: Text(label,
            style: TextStyle(color: color ?? AppColors.text, fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
      ),
    );
  }

  Future<void> _changePhone(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Badilisha Namba', style: TextStyle(color: AppColors.accent)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.text),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          decoration: const InputDecoration(hintText: '0762xxxxxx au 255762xxxxxx'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('BADILISHA', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (ok != true) return;
    if (!_validPhone(ctrl.text)) {
      if (context.mounted) _showSnack(context, 'Namba si sahihi.', isError: true);
      return;
    }
    final res = await ApiClient.post('me/phone', data: {'phone': ctrl.text.trim()});
    if (!context.mounted) return;
    _showSnack(context, res.success ? (res['message']?.toString() ?? 'Imebadilishwa') : (res.error ?? 'Hitilafu'),
        isError: !res.success);
    if (res.success) await AppState.I.refresh();
  }

  Future<void> _showPayments(BuildContext context) async {
    // Open the sheet straight away and show skeleton rows while loading.
    final request = ApiClient.get('me/payments', query: {'limit': 20});
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => FutureBuilder<ApiResponse>(
          future: request,
          builder: (_, snap) {
            final res = snap.data;
            final payments = res != null && res.success ? _list(res['payments']) : <Map<String, dynamic>>[];
            return _paymentsList(scroll, snap.connectionState != ConnectionState.done, res, payments);
          },
        ),
      ),
    );
  }

  Widget _paymentsList(
      ScrollController scroll, bool waiting, ApiResponse? res, List<Map<String, dynamic>> payments) {
    return ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            const Center(
              child: Text('HISTORIA YA MALIPO',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            if (waiting)
              skeletonRows()
            else if (res == null || !res.success)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                    child: Text(res?.error ?? 'Hitilafu. Jaribu tena.',
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.red))),
              )
            else if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Hakuna malipo bado', style: TextStyle(color: AppColors.muted))),
              )
            else
              ...payments.map((m) {
                final status = m['payment_status']?.toString() ?? 'pending';
                final color = status == 'completed'
                    ? AppColors.success
                    : status == 'failed'
                        ? AppColors.red
                        : AppColors.warn;
                return ListTile(
                  leading: Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'failed'
                            ? Icons.cancel
                            : Icons.access_time,
                    color: color,
                  ),
                  title: Text('TSh ${_formatMoney(_asInt(m['amount']))}',
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text('${(m['package_type'] ?? '').toString().toUpperCase()} • ${m['created_at'] ?? ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  trailing: Text(status.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
                );
              }),
          ],
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Toka?', style: TextStyle(color: AppColors.text)),
        content: const Text('Una uhakika unataka kutoka?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('HAPANA', style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('NDIYO', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await ApiClient.post('auth/logout');
    await ApiClient.setToken(null);
    AppState.I.setLoggedOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    }
  }
}

// ============================================================
// POLICY SCREEN (privacy / terms from GET config)
// ============================================================
class PolicyScreen extends StatelessWidget {
  final String title;
  final List<String> paragraphs;
  const PolicyScreen({super.key, required this.title, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    final items = paragraphs.isEmpty ? ['Taarifa hizi hazijapakiwa. Hakikisha una internet kisha jaribu tena.'] : paragraphs;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...items.map((p) {
            final idx = p.indexOf(':');
            final hasLabel = idx > 0 && idx < 30;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                  children: hasLabel
                      ? [
                          TextSpan(
                              text: p.substring(0, idx + 1),
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                          TextSpan(text: p.substring(idx + 1)),
                        ]
                      : [TextSpan(text: p)],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Mawasiliano: ${AppState.I.supportEmail}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ============================================================
// COUNTDOWN TEXT (uses server clock)
// ============================================================
class CountdownText extends StatefulWidget {
  final int endUnix;
  final String prefix;
  final String expiredText;
  final TextStyle? style;
  final TextStyle? expiredStyle;

  const CountdownText({
    super.key,
    required this.endUnix,
    this.prefix = '',
    this.expiredText = 'IMEISHA',
    this.style,
    this.expiredStyle,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endUnix - AppClock.nowUnix();
    if (left <= 0) {
      return Text(widget.expiredText,
          style: widget.expiredStyle ??
              (widget.style ?? const TextStyle()).copyWith(color: AppColors.red));
    }
    return Text('${widget.prefix}${AppClock.formatDuration(left)}', style: widget.style);
  }
}

Widget _noticeBox(String text, {IconData icon = Icons.info_outline, Color color = AppColors.accent2}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5))),
      ],
    ),
  );
}

Widget _badge(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

Widget _resultBadge(String status) {
  switch (status) {
    case 'won':
      return _badge(Icons.check_circle, 'WON', AppColors.success);
    case 'lost':
      return _badge(Icons.cancel, 'LOST', AppColors.red);
    default:
      return _badge(Icons.access_time, 'PENDING', AppColors.warn);
  }
}

Color _packageColor(String? type) =>
    type == null ? AppColors.gold : AppState.I.packageByType(type).color;

void _copyCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  _showSnack(context, 'Booking code imenakiliwa!');
}

// ============================================================
// BETSLIP CARD (reusable)
// ============================================================
class BetslipCard extends StatelessWidget {
  final Map<String, dynamic> slip;
  final bool isBlurred;
  final bool isSystemGenerated;

  const BetslipCard({
    super.key,
    required this.slip,
    this.isBlurred = false,
    this.isSystemGenerated = false,
  });

  @override
  Widget build(BuildContext context) {
    final locked = isBlurred || _slipLocked(slip);
    final bookingCode = slip['booking_code']?.toString() ?? '';
    final shownCode = locked && !bookingCode.endsWith('***')
        ? '${bookingCode.length > 3 ? bookingCode.substring(0, 3) : bookingCode}***'
        : bookingCode;
    final odds = _str(slip['odds']);
    final companyName = _slipCompanyName(slip);
    final companyLogo = _slipCompanyLogo(slip);
    final matchDetails = slip['match_details']?.toString() ?? '';
    final packageType = _str(slip['package_type']);
    final resultStatus = slip['result_status']?.toString() ?? 'pending';
    final validityTs = _asInt(slip['validity_ts']);
    final tipster = _slipTipster(slip);
    final tipsterName = _str(tipster['name']);
    final system = isSystemGenerated || _asBool(slip['is_system_generated']) || slip['slip_type'] == 'system';
    final imageUrl = _slipImageUrl(slip);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: locked ? AppColors.gold.withOpacity(0.25) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: company + package
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                if (companyLogo != null)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _netImage(
                      companyLogo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Expanded(
                  child: Text(companyName ?? 'MKEKA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                if (packageType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _packageColor(packageType).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _packageColor(packageType).withOpacity(0.3)),
                    ),
                    child: Text(packageType.toUpperCase(),
                        style: TextStyle(color: _packageColor(packageType), fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
          if (tipsterName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 13, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(tipsterName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  if (_asBool(tipster['verified'])) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 13, color: AppColors.verified),
                  ],
                ],
              ),
            ),
          // Code box
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shownCode.isEmpty ? '***' : shownCode,
                    style: TextStyle(
                      color: locked ? AppColors.gold : AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: const Icon(Icons.lock, color: AppColors.gold, size: 20),
                  ),
              ],
            ),
          ),
          if (matchDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: matchDetails),
                  if (locked)
                    const TextSpan(
                      text: '  [LIPIA KUONA ZAIDI]',
                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
                    ),
                ]),
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          if (imageUrl != null || locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: SlipImage(
                url: imageUrl,
                locked: locked,
                onUnlock: () => startPackagePurchase(context),
              ),
            ),
          // Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(Icons.show_chart, 'ODDS: ${odds ?? 'N/A'}', AppColors.gold),
                _resultBadge(resultStatus),
                if (system) _badge(Icons.smart_toy, 'SYSTEM', AppColors.accent2),
                if (_asBool(slip['is_today'])) _badge(Icons.today, 'LEO', AppColors.warn),
                if (_str(slip['created_date']) != null)
                  _badge(Icons.calendar_today, slip['created_date'].toString(), AppColors.muted),
              ],
            ),
          ),
          // Footer: validity + copy / pay
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                if (validityTs > 0) ...[
                  const Icon(Icons.hourglass_bottom, color: AppColors.muted, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: CountdownText(
                      endUnix: validityTs,
                      prefix: 'VALID: ',
                      expiredText: '⛔ MUDA UMEISHA',
                      style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (!locked && bookingCode.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.copy, size: 14, color: AppColors.accent),
                    label: const Text('Copy', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                    onPressed: () => _copyCode(context, bookingCode),
                  ),
                if (locked)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => startPackagePurchase(context),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('LIPIA SASA', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SLIP IMAGE (blurred + locked for unpaid users, clear for paid)
// ============================================================
/// Image.network that also works on the web version when the image host
/// sends no CORS headers (falls back to a plain <img> element).
Widget _netImage(
  String url, {
  double? width,
  double? height,
  BoxFit? fit,
  AlignmentGeometry alignment = Alignment.center,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  );
}

String? _absUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final u = url.trim();
  if (u.startsWith('http')) return u;
  return Uri.parse(AppConfig.API_BASE).resolve(u).toString();
}

String? _slipImageUrl(Map<String, dynamic> s) => _absUrl(_str(s['image_url']) ??
    _str(s['slip_image']) ??
    _str(s['image']) ??
    _str(s['screenshot']) ??
    _str(s['blurred_image_url']));

class SlipImage extends StatelessWidget {
  final String? url;
  final bool locked;
  final VoidCallback? onUnlock;
  final double height;
  const SlipImage({super.key, required this.url, required this.locked, this.onUnlock, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final img = url == null || (locked && kIsWeb)
        ? _fakeSlip()
        : _netImage(
            url!,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            loadingBuilder: (c, child, p) =>
                p == null ? child : SizedBox(height: height, child: _imageSkeleton(c, child, p)),
            errorBuilder: (_, __, ___) => locked ? _fakeSlip() : const SizedBox.shrink(),
          );

    if (!locked) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _SlipImageViewer(url: url!)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            img,
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.zoom_in, size: 18, color: Colors.white),
              ),
            ),
          ]),
        ),
      );
    }

    return GestureDetector(
      onTap: onUnlock,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.decal),
                child: img,
              ),
              Container(color: const Color(0x99000010)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withOpacity(0.15),
                        border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                      ),
                      child: const Icon(Icons.visibility, color: AppColors.gold, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text('TAZAMA MKEKA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Lipia kifurushi kuona mkeka kamili',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    if (onUnlock != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.visibility, size: 14, color: Colors.black),
                          SizedBox(width: 5),
                          Text('TAZAMA',
                              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drawn stand-in for a betslip, used under the blur when there is no image.
  Widget _fakeSlip() {
    Widget line(double w, Color c) => Container(
          width: w,
          height: 9,
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        );
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFF2F4F7),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 22, color: const Color(0xFF0B8A3E)),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++)
            Row(children: [
              Expanded(child: line(double.infinity, const Color(0xFF9AA3AF))),
              const SizedBox(width: 20),
              line(34, const Color(0xFF0B8A3E)),
            ]),
          const Spacer(),
          Row(children: [line(80, const Color(0xFF6B7280)), const Spacer(), line(50, const Color(0xFFE11D48))]),
        ],
      ),
    );
  }
}

class _SlipImageViewer extends StatelessWidget {
  final String url;
  const _SlipImageViewer({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('PICHA YA MKEKA')),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: _netImage(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, p) => p == null ? child : Shimmer(child: _bone(width: 260, height: 420)),
            errorBuilder: (_, __, ___) =>
                const Text('Picha haikupatikana', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SINGLE SLIP CARD
// ============================================================
class SingleSlipCard extends StatelessWidget {
  final Map<String, dynamic> slip;
  final bool purchased;
  final VoidCallback? onBuy;

  const SingleSlipCard({
    super.key,
    required this.slip,
    this.purchased = false,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = purchased || _asBool(slip['is_purchased']) || (slip.containsKey('is_locked') && !_slipLocked(slip));
    final price = _asInt(slip['price']) > 0 ? _asInt(slip['price']) : 3000;
    final bookingCode = slip['booking_code']?.toString() ?? '';
    final shownCode = !unlocked && !bookingCode.endsWith('***')
        ? '${bookingCode.length > 3 ? bookingCode.substring(0, 3) : bookingCode}***'
        : bookingCode;
    final tipster = _slipTipster(slip);
    final tipsterName = _str(tipster['name']);
    final tipsterAvatar = _str(tipster['avatar']);
    final companyName = _slipCompanyName(slip);
    final companyLogo = _slipCompanyLogo(slip);
    final matchDetails = slip['match_details']?.toString() ?? '';
    final odds = _str(slip['odds']);
    final validityTs = _asInt(slip['validity_ts']);
    final imageUrl = _slipImageUrl(slip);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? AppColors.success.withOpacity(0.3) : AppColors.gold.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (companyLogo != null) ...[
                _netImage(companyLogo,
                    width: 22, height: 22, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(companyName ?? 'MKEKA SINGLE',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('UMELIPIA',
                      style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: Text('${_formatMoney(price)}/=',
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          if (tipsterName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.1), AppColors.gold.withOpacity(0.03)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  _avatar(tipsterAvatar, tipsterName, 36, textColor: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mkeka wa Tipster',
                            style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
                        Text(tipsterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        if (tipster['rating'] != null)
                          Text('⭐ ${_asDouble(tipster['rating'], 5).toStringAsFixed(1)}',
                              style: const TextStyle(color: AppColors.gold, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (_asBool(tipster['verified'])) const Icon(Icons.verified, color: AppColors.verified, size: 20),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: unlocked ? AppColors.success.withOpacity(0.3) : AppColors.gold.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  shownCode.isEmpty ? '***' : shownCode,
                  style: TextStyle(
                    color: unlocked ? AppColors.accent : AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              if (!unlocked)
                const Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Icon(Icons.lock, color: AppColors.gold, size: 20),
                ),
            ],
          ),
          if (matchDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: matchDetails),
                if (!unlocked)
                  const TextSpan(
                      text: '  [LIPIA KUONA ZAIDI]',
                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
              ]),
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ],
          if (imageUrl != null || !unlocked) ...[
            const SizedBox(height: 10),
            SlipImage(url: imageUrl, locked: !unlocked, onUnlock: onBuy),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(Icons.show_chart, 'ODDS: ${odds ?? 'N/A'}', AppColors.gold),
              _badge(Icons.track_changes, 'SINGLE', AppColors.tanzanite),
              _resultBadge(slip['result_status']?.toString() ?? 'pending'),
              if (validityTs > 0)
                CountdownText(
                  endUnix: validityTs,
                  prefix: '⏳ ',
                  expiredText: '⛔ MUDA UMEISHA',
                  style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (unlocked && bookingCode.isNotEmpty && !bookingCode.endsWith('***')) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPY BOOKING CODE'),
                onPressed: () => _copyCode(context, bookingCode),
              ),
            ),
          ],
          if (!unlocked && onBuy != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                icon: const Icon(Icons.shopping_cart, size: 16),
                label: Text('LIPIA ${_formatMoney(price)}/='),
                onPressed: onBuy,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// PURCHASE ENTRY POINTS (login first if needed)
// ============================================================
/// Guests can pay straight away: the account is created / opened in the
/// background from the phone number they pay with (see PaymentFlow).
Future<void> startPackagePurchase(BuildContext context, {String? packageType}) async {
  final chosen = packageType ?? await _pickPackage(context);
  if (chosen == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PayPackageScreen(packageType: chosen)),
  );
}

Future<bool> startSingleSlipPurchase(BuildContext context, Map<String, dynamic> slip) async {
  final bought = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => BuySingleSlipScreen(slip: slip)),
  );
  return bought == true;
}

// ============================================================
// NETWORK SELECTOR (optional — names only, no copied logos)
// ============================================================
class NetworkSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  final Color color;
  const NetworkSelector({super.key, required this.selected, required this.onChanged, this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    final nets = AppState.I.networks;
    // 2 per row on narrow phones, 4 per row on wider screens.
    return LayoutBuilder(builder: (context, box) {
      final perRow = box.maxWidth < 340 ? 2 : 4;
      const gap = 8.0;
      final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final n in nets)
            SizedBox(
              width: w,
              child: GestureDetector(
                onTap: () => onChanged(selected == n.code ? null : n.code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected == n.code ? color.withOpacity(0.12) : AppColors.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected == n.code ? color : AppColors.border,
                      width: selected == n.code ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NetworkLogo(net: n),
                          if (selected == n.code)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.check, size: 12, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(n.wallet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: selected == n.code ? color : AppColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// ============================================================
// PAYMENT FLOW (shared by package + single slip)
// ============================================================
mixin PaymentFlow<T extends StatefulWidget> on State<T> {
  final phoneCtrl = TextEditingController();
  String? selectedNetwork;
  bool loading = false;
  bool _cancelled = false;
  BuildContext? _ussdCtx;

  @override
  void initState() {
    super.initState();
    final p = AppState.I.displayPhone ?? AppState.I.user?['phone_number']?.toString() ?? '';
    phoneCtrl.text = p;
  }

  @override
  void dispose() {
    _cancelled = true;
    phoneCtrl.dispose();
    super.dispose();
  }

  void showUssdDialog(Color color) {
    _cancelled = false;
    final ends = AppClock.nowUnix() + AppState.I.maxPolls * AppState.I.pollIntervalSeconds;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _ussdCtx = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.card,
            title: Text('Angalia Simu Yako', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_iphone, size: 56, color: color),
                  const SizedBox(height: 12),
                  const Text(
                    'Ujumbe wa malipo umetumwa kwenye simu yako na mtandao wako. Thibitisha malipo kwenye simu yako.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Text(phoneCtrl.text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                  const SizedBox(height: 8),
                  CountdownText(
                    endUnix: ends,
                    prefix: 'Inasubiri uthibitisho... ',
                    expiredText: 'Muda umeisha',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _cancelled = true;
                  _ussdCtx = null;
                  Navigator.of(ctx).pop();
                },
                child: const Text('FUNGA', style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        );
      },
    );
  }

  void closeUssdDialog() {
    final c = _ussdCtx;
    _ussdCtx = null;
    if (c != null && c.mounted) Navigator.of(c).pop();
  }

  /// Polls GET orders/status until completed / failed / timeout.
  /// Returns the final data when completed, null otherwise.
  Future<Map<String, dynamic>?> pollOrder(String orderId) async {
    final s = AppState.I;
    for (var i = 0; i < s.maxPolls; i++) {
      await Future.delayed(Duration(seconds: s.pollIntervalSeconds));
      if (!mounted || _cancelled) return null;
      final r = await ApiClient.get('orders/status', query: {'order_id': orderId});
      if (!mounted || _cancelled) return null;
      if (r.success) {
        final status = r['status']?.toString();
        if (status == 'completed') {
          closeUssdDialog();
          return r.data;
        }
        if (status == 'failed') {
          closeUssdDialog();
          _showSnack(context, 'Malipo yameshindikana au yameghairiwa. Jaribu tena.', isError: true);
          return null;
        }
      } else if (r.errorCode == 'not_found' || r.isLoginRequired || r.isBanned || r.isKicked) {
        closeUssdDialog();
        if (r.errorCode == 'not_found') _showSnack(context, r.error ?? 'Order haipatikani.', isError: true);
        return null;
      }
    }
    if (mounted && !_cancelled) {
      closeUssdDialog();
      _showSnack(context, 'Malipo hayajakamilika. Kama umeshalipa, subiri kidogo kisha bofya refresh.', isError: true);
    }
    return null;
  }

  /// Guest → opens the account for [phone], creating it if it is new
  /// (no extra screens). Returns an error message, or null when logged in.
  Future<String?> ensureAccount(String phone) async {
    if (AppState.I.loggedIn) return null;
    var res = await ApiClient.post('auth/login', data: _authPayload(phone));
    if (res.success && res['action'] == 'need_confirmation') {
      final digits = _normalizePhone(phone);
      res = await ApiClient.post('auth/confirm', data: {
        ..._authPayload(phone),
        'phone_confirm': phone,
        // Customer username for the new account (server may ignore it).
        'name': 'Mteja ${digits.substring(digits.length - 4)}',
        'username': 'mteja$digits',
        'source': 'auto_payment',
      });
    }
    if (!res.success) {
      final reason = res.banReason;
      return [res.error ?? 'Imeshindikana kufungua akaunti.', if (reason != null) 'Sababu: $reason'].join('\n');
    }
    final token = _str(res['token']);
    if (token == null) return 'Imeshindikana kufungua akaunti. Jaribu tena.';
    await ApiClient.setToken(token);
    final me = await AppState.I.refresh();
    if (!me.success) return me.error ?? 'Imeshindikana kupakua taarifa zako.';
    return null;
  }

  Widget phoneAndNetworkFields(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Namba ya Simu ya Kulipa', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.text, fontSize: 16, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: '0762xxxxxx au 255762xxxxxx',
            prefixIcon: Icon(Icons.phone, color: color),
            helperText: 'M-Pesa, Mixx by Yas, Airtel Money au HaloPesa',
            helperStyle: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
        ),
        const SizedBox(height: 18),
        const Text('Chagua Mtandao (Si lazima)', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        NetworkSelector(
          selected: selectedNetwork,
          color: color,
          onChanged: (v) => setState(() => selectedNetwork = v),
        ),
      ],
    );
  }
}

// ============================================================
// PAY PACKAGE SCREEN
// ============================================================
class PayPackageScreen extends StatefulWidget {
  final String packageType;
  const PayPackageScreen({super.key, required this.packageType});

  @override
  State<PayPackageScreen> createState() => _PayPackageScreenState();
}

class _PayPackageScreenState extends State<PayPackageScreen> with PaymentFlow<PayPackageScreen> {
  PackageInfo get pkg => AppState.I.packageByType(widget.packageType);

  Future<void> _pay() async {
    if (!_validPhone(phoneCtrl.text)) {
      _showSnack(context, 'Ingiza namba sahihi', isError: true);
      return;
    }
    setState(() => loading = true);
    final authError = await ensureAccount(phoneCtrl.text.trim());
    if (!mounted) return;
    if (authError != null) {
      setState(() => loading = false);
      _showSnack(context, authError, isError: true);
      return;
    }
    final res = await ApiClient.post('orders/package', data: {
      'package_type': widget.packageType,
      'phone': phoneCtrl.text.trim(),
      'network': selectedNetwork,
    });
    if (!mounted) return;
    setState(() => loading = false);

    final orderId = _str(res['order_id']);
    if (!res.success || orderId == null) {
      _showSnack(context, res.error ?? 'Malipo yameshindikana', isError: true);
      return;
    }
    showUssdDialog(pkg.color);
    final done = await pollOrder(orderId);
    if (done == null || !mounted) return;
    await AppState.I.refresh();
    if (!mounted) return;
    await _showCongrats(_map(done['subscription']));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showCongrats(Map<String, dynamic> sub) async {
    final p = pkg;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0A1A00), Color(0xFF1A3A00)]),
            border: Border.all(color: AppColors.success, width: 3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: AppColors.success),
              const SizedBox(height: 12),
              const Text('HONGERA SANA!',
                  style: TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text('Malipo yako yamekamilika kwa ufanisi. Karibu kwenye familia ya Mikeka App!',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              Text(p.title, style: TextStyle(color: p.color, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(p.label, style: const TextStyle(color: AppColors.accent, fontSize: 12)),
              if (_str(sub['end_date']) != null) ...[
                const SizedBox(height: 10),
                const Text('KIFURUSHI KITAISHA:', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                Text(sub['end_date'].toString(),
                    style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 8),
              Text('TSh ${_formatMoney(p.price)}/=',
                  style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('SAWA, NIMEKUELEWA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pkg;
    final sub = AppState.I.subscription;
    return Scaffold(
      appBar: AppBar(title: Text('LIPIA ${p.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.card, p.color.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(p.icon, color: p.color, size: 36),
                  const SizedBox(height: 6),
                  Text(p.title,
                      style: TextStyle(color: p.color, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text(p.label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('TSh ${_formatMoney(p.price)}/=',
                      style: TextStyle(color: p.color, fontSize: 32, fontWeight: FontWeight.w900)),
                  if (sub != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Una kifurushi kinachotumika — muda huu utaongezwa juu ya muda uliobaki.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.accent2, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            phoneAndNetworkFields(p.color),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: p.color, foregroundColor: Colors.black),
                onPressed: loading ? null : _pay,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text('LIPIA TSh ${_formatMoney(p.price)}/=', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BUY SINGLE SLIP SCREEN
// ============================================================
class BuySingleSlipScreen extends StatefulWidget {
  final Map<String, dynamic> slip;
  const BuySingleSlipScreen({super.key, required this.slip});

  @override
  State<BuySingleSlipScreen> createState() => _BuySingleSlipScreenState();
}

class _BuySingleSlipScreenState extends State<BuySingleSlipScreen> with PaymentFlow<BuySingleSlipScreen> {
  int get price => _asInt(widget.slip['price']) > 0 ? _asInt(widget.slip['price']) : 3000;

  Future<void> _pay() async {
    if (!_validPhone(phoneCtrl.text)) {
      _showSnack(context, 'Ingiza namba sahihi', isError: true);
      return;
    }
    setState(() => loading = true);
    final authError = await ensureAccount(phoneCtrl.text.trim());
    if (!mounted) return;
    if (authError != null) {
      setState(() => loading = false);
      _showSnack(context, authError, isError: true);
      return;
    }
    final res = await ApiClient.post('orders/single', data: {
      'betslip_id': _asInt(widget.slip['id']),
      'phone': phoneCtrl.text.trim(),
      'network': selectedNetwork,
    });
    if (!mounted) return;
    setState(() => loading = false);

    final orderId = _str(res['order_id']);
    if (!res.success || orderId == null) {
      _showSnack(context, res.error ?? 'Malipo yameshindikana', isError: true);
      if (res.errorCode == 'conflict' && mounted) Navigator.pop(context, true);
      return;
    }
    showUssdDialog(AppColors.gold);
    final done = await pollOrder(orderId);
    if (done == null || !mounted) return;
    AppState.I.refresh();
    await _showSuccess(_map(done['betslip']));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showSuccess(Map<String, dynamic> slip) async {
    final code = _str(slip['booking_code']);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('HONGERA! 🎯', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Umefanikiwa kununua mkeka single! Booking code yako ipo tayari.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            if (code != null && !code.endsWith('***')) ...[
              const SizedBox(height: 14),
              const Text('BOOKING CODE YAKO:', style: TextStyle(color: AppColors.muted, fontSize: 10)),
              const SizedBox(height: 4),
              SelectableText(code,
                  style: const TextStyle(
                      color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
              TextButton.icon(
                onPressed: () => _copyCode(ctx, code),
                icon: const Icon(Icons.copy, size: 16, color: AppColors.accent),
                label: const Text('Copy', style: TextStyle(color: AppColors.accent)),
              ),
            ],
            const SizedBox(height: 8),
            Text('TSh ${_formatMoney(price)}/=',
                style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('SAWA, ASANTE!', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slip;
    final companyName = _slipCompanyName(slip);
    final tipsterName = _str(_slipTipster(slip)['name']);
    final matchDetails = slip['match_details']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('LIPIA MKEKA SINGLE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  if (tipsterName != null)
                    Text('Mkeka wa $tipsterName',
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                  if (companyName != null)
                    Text(companyName, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('BEI YA MKEKA', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('TSh ${_formatMoney(price)}/=',
                      style: const TextStyle(color: AppColors.gold, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Unalipia mkeka huu pekee — sio kifurushi',
                      style: TextStyle(color: AppColors.accent2, fontSize: 11)),
                  if (matchDetails.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(matchDetails,
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            phoneAndNetworkFields(AppColors.gold),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                onPressed: loading ? null : _pay,
                icon: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.shopping_cart),
                label: Text('LIPIA TSh ${_formatMoney(price)}/='),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TIPSTER TOOLS — my slips (only for users with is_tipster = 1)
// ============================================================
class TipsterSlipsScreen extends StatefulWidget {
  const TipsterSlipsScreen({super.key});
  @override
  State<TipsterSlipsScreen> createState() => _TipsterSlipsScreenState();
}

class _TipsterSlipsScreenState extends State<TipsterSlipsScreen> {
  List<Map<String, dynamic>> slips = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final res = await ApiClient.get('tipster/slips');
    if (!mounted) return;
    setState(() {
      if (res.success) {
        slips = _list(res['slips']);
      } else {
        error = res.error;
      }
      loading = false;
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> s) async {
    final id = _asInt(s['id']);
    final active = s['is_active'] == null ? true : _asBool(s['is_active']);
    final res = await ApiClient.post('tipster/slips/$id', data: {'is_active': active ? 0 : 1});
    if (!mounted) return;
    _showSnack(context, res.success ? (active ? 'Mkeka umefichwa.' : 'Mkeka umeonyeshwa.') : (res.error ?? 'Hitilafu'),
        isError: !res.success);
    if (res.success) _load();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Futa mkeka?', style: TextStyle(color: AppColors.text)),
        content: Text('Booking code: ${s['booking_code'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('HAPANA', style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('FUTA', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiClient.post('tipster/slips/${_asInt(s['id'])}/delete');
    if (!mounted) return;
    _showSnack(context, res.success ? 'Mkeka umefutwa.' : (res.error ?? 'Hitilafu'), isError: !res.success);
    if (res.success) _load();
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TipsterSlipFormScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIKEKA YANGU (TIPSTER)'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('MKEKA MPYA', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: loading
          ? skeletonSlipList(withHeader: false)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: error != null
                  ? _errorState(error!, _load)
                  : slips.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.note_add_outlined, color: AppColors.muted, size: 56),
                            SizedBox(height: 12),
                            Center(
                              child: Text('Bado hujaweka mkeka. Bofya "MKEKA MPYA".',
                                  style: TextStyle(color: AppColors.muted)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                          itemCount: slips.length,
                          itemBuilder: (_, i) => _tile(slips[i]),
                        ),
            ),
    );
  }

  Widget _tile(Map<String, dynamic> s) {
    final single = _asBool(s['is_single_slip']);
    final active = s['is_active'] == null ? true : _asBool(s['is_active']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.border : AppColors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s['booking_code']?.toString() ?? '',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18, color: AppColors.accent),
                onPressed: () => _copyCode(context, s['booking_code']?.toString() ?? ''),
              ),
            ],
          ),
          if (_str(s['match_details']) != null)
            Text(s['match_details'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge(Icons.show_chart, 'ODDS: ${_str(s['odds']) ?? 'N/A'}', AppColors.gold),
              _resultBadge(s['result_status']?.toString() ?? 'pending'),
              if (single) _badge(Icons.track_changes, 'SINGLE ${_formatMoney(_asInt(s['price']))}/=', AppColors.tanzanite),
              _badge(Icons.workspace_premium, (s['package_type'] ?? 'normal').toString().toUpperCase(), AppColors.accent2),
              if (_slipCompanyName(s) != null) _badge(Icons.business, _slipCompanyName(s)!, AppColors.accent),
              if (!active) _badge(Icons.visibility_off, 'IMEFICHWA', AppColors.red),
              _badge(Icons.calendar_today, s['created_date']?.toString() ?? '', AppColors.muted),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _toggleActive(s),
                icon: Icon(active ? Icons.visibility_off : Icons.visibility, size: 16, color: AppColors.warn),
                label: Text(active ? 'Ficha' : 'Onyesha', style: const TextStyle(color: AppColors.warn)),
              ),
              TextButton.icon(
                onPressed: () => _delete(s),
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                label: const Text('Futa', style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TipsterSlipFormScreen extends StatefulWidget {
  const TipsterSlipFormScreen({super.key});
  @override
  State<TipsterSlipFormScreen> createState() => _TipsterSlipFormScreenState();
}

class _TipsterSlipFormScreenState extends State<TipsterSlipFormScreen> {
  final codeCtrl = TextEditingController();
  final detailsCtrl = TextEditingController();
  final oddsCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '3000');
  final imageCtrl = TextEditingController();
  int? companyId;
  String packageType = 'normal';
  bool isSingle = false;
  int validHours = 24;
  bool saving = false;

  @override
  void dispose() {
    codeCtrl.dispose();
    detailsCtrl.dispose();
    oddsCtrl.dispose();
    priceCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = codeCtrl.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_\-]{1,20}$').hasMatch(code)) {
      _showSnack(context, 'Booking code si sahihi (herufi na namba tu, max 20).', isError: true);
      return;
    }
    final image = imageCtrl.text.trim();
    if (image.isNotEmpty && !image.startsWith('http')) {
      _showSnack(context, 'Link ya picha lazima ianze na https://', isError: true);
      return;
    }
    setState(() => saving = true);
    final res = await ApiClient.post('tipster/slips', data: {
      'booking_code': code,
      'match_details': detailsCtrl.text.trim(),
      'odds': oddsCtrl.text.trim(),
      'company_id': companyId,
      'package_type': packageType,
      'is_single_slip': isSingle ? 1 : 0,
      'price': isSingle ? (int.tryParse(priceCtrl.text.trim()) ?? 3000) : 3000,
      'image_url': image.isEmpty ? null : image,
      'validity_time': AppClock.serverDateTimeString(AppClock.nowUnix() + validHours * 3600),
    });
    if (!mounted) return;
    setState(() => saving = false);
    if (res.success) {
      _showSnack(context, res['message']?.toString() ?? 'Mkeka umehifadhiwa.');
      Navigator.pop(context, true);
    } else {
      _showSnack(context, res.error ?? 'Hitilafu', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = AppState.I.companies;
    return Scaffold(
      appBar: AppBar(title: const Text('MKEKA MPYA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: AppColors.text, letterSpacing: 2, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'Booking code *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: detailsCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(labelText: 'Mechi / maelezo (mfano: Simba vs Yanga, Over 2.5)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: oddsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(labelText: 'Odds (mfano: 55.20)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: companyId,
            dropdownColor: AppColors.card2,
            decoration: const InputDecoration(labelText: 'Kampuni ya kubeti'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— Chagua —')),
              ...companies.map((c) => DropdownMenuItem<int?>(
                    value: _asInt(c['id']),
                    child: Text(c['name']?.toString() ?? ''),
                  )),
            ],
            onChanged: (v) => setState(() => companyId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: packageType,
            dropdownColor: AppColors.card2,
            decoration: const InputDecoration(labelText: 'Kifurushi kinachoona mkeka huu'),
            items: AppState.I.packages
                .map((p) => DropdownMenuItem<String>(value: p.type, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() => packageType = v ?? 'normal'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: validHours,
            dropdownColor: AppColors.card2,
            decoration: const InputDecoration(labelText: 'Mkeka unadumu (muda)'),
            items: const [6, 12, 24, 48, 72]
                .map((h) => DropdownMenuItem<int>(value: h, child: Text('Masaa $h')))
                .toList(),
            onChanged: (v) => setState(() => validHours = v ?? 24),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: isSingle,
            activeColor: AppColors.gold,
            contentPadding: EdgeInsets.zero,
            title: const Text('Mkeka wa SINGLE (wateja wanunue mmoja mmoja)',
                style: TextStyle(color: AppColors.text, fontSize: 13)),
            onChanged: (v) => setState(() => isSingle = v),
          ),
          if (isSingle)
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(labelText: 'Bei ya mkeka single (TSh)'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: imageCtrl,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(labelText: 'Link ya picha ya mkeka (si lazima, https://...)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save),
              label: const Text('HIFADHI MKEKA'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED HELPERS
// ============================================================
void _showSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error : Icons.check_circle, color: isError ? Colors.white : AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppColors.red.withOpacity(0.92) : AppColors.card2,
      duration: Duration(seconds: isError ? 4 : 3),
    ),
  );
}

/// Web links open inside the app; mailto:/tel:/whatsapp: go to the phone's app.
Future<void> _openUrl(BuildContext context, String url, {String? title}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  if (kIsWeb) {
    // Web version: a browser tab is the in-app browser.
    try {
      await launchUrl(uri, webOnlyWindowName: uri.scheme.startsWith('http') ? '_blank' : '_self');
    } catch (_) {
      if (context.mounted) _showSnack(context, 'Imeshindikana kufungua link.', isError: true);
    }
    return;
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: uri.toString(), title: title)),
    );
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _showSnack(context, 'Imeshindikana kufungua link.', isError: true);
  } catch (_) {
    if (context.mounted) _showSnack(context, 'Imeshindikana kufungua link.', isError: true);
  }
}

Map<String, dynamic> _authPayload(String phone) => {
      'phone': phone,
      'device_id': AppConfig.deviceId,
      'device_name': AppConfig.deviceModel,
      'platform': AppConfig.platform,
      'app_version': AppConfig.VERSION,
    };

/// Login / register dialog. Returns true when the user is logged in.
Future<bool> _showLoginPrompt(BuildContext context) async {
  final phoneCtrl = TextEditingController();
  bool loading = false;
  String? errorMsg;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> submit() async {
          final phone = phoneCtrl.text.trim();
          if (!_validPhone(phone)) {
            setS(() => errorMsg = 'Nambari si sahihi. Tumia 0XXXXXXXXX au 255XXXXXXXXX.');
            return;
          }
          setS(() {
            loading = true;
            errorMsg = null;
          });

          ApiResponse res = await ApiClient.post('auth/login', data: _authPayload(phone));
          if (res.success && res['action'] == 'need_confirmation') {
            setS(() => loading = false);
            if (!ctx.mounted) return;
            final again = await _showConfirmDialog(ctx, phone);
            if (again == null) return;
            setS(() => loading = true);
            res = await ApiClient.post('auth/confirm', data: {..._authPayload(phone), 'phone_confirm': again});
          }

          if (!res.success) {
            final reason = res.banReason;
            setS(() {
              loading = false;
              errorMsg = [res.error ?? 'Hitilafu. Jaribu tena.', if (reason != null) 'Sababu: $reason'].join('\n');
            });
            return;
          }

          final token = _str(res['token']);
          if (token == null) {
            setS(() {
              loading = false;
              errorMsg = 'Imeshindikana kuingia. Jaribu tena.';
            });
            return;
          }
          await ApiClient.setToken(token);
          final me = await AppState.I.refresh();
          if (!me.success) {
            setS(() {
              loading = false;
              errorMsg = me.error ?? 'Imeshindikana kupakua taarifa zako.';
            });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx, true);
        }

        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('INGIA / JISAJILI',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingiza namba yako ya simu ili kuendelea na kununua mikeka, kufuata tipsters, na kupata huduma zote.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  enabled: !loading,
                  onSubmitted: (_) => loading ? null : submit(),
                  style: const TextStyle(color: AppColors.text, fontSize: 16, letterSpacing: 1),
                  decoration: const InputDecoration(
                    hintText: '0762xxxxxx au 255762xxxxxx',
                    prefixIcon: Icon(Icons.phone, color: AppColors.accent),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                ),
                const SizedBox(height: 6),
                const Text('Unaweza kuingiza namba kuanzia 0 (076...) au 255 (255762...)',
                    style: TextStyle(color: AppColors.muted, fontSize: 10)),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.4)),
                    ),
                    child: Text(errorMsg!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 10),
                const Text('Kwa kuendelea unakubali Vigezo na Masharti. Huduma ni kwa watu wenye miaka 18+.',
                    style: TextStyle(color: AppColors.muted, fontSize: 10)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: loading ? null : submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('ENDELEA'),
            ),
          ],
        );
      },
    ),
  );

  // controller not disposed here: the dialog may still be animating out
  final ok = result ?? false;
  if (ok && context.mounted) _showSnack(context, 'Karibu! Umeingia kwenye akaunti yako.');
  return ok;
}

/// New number: user types it again. Returns the typed number when it matches, otherwise null.
Future<String?> _showConfirmDialog(BuildContext context, String phone) async {
  final ctrl = TextEditingController();
  String? err;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('RUDIA TENA NAMBA YAKO', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Namba hii ni mpya. Akaunti mpya itaundwa:', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(phone, style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('Ingiza namba tena kuhakiki', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: const TextStyle(color: AppColors.text, fontSize: 16),
              decoration: InputDecoration(hintText: 'Weka namba tena', errorText: err),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted))),
          ElevatedButton(
            onPressed: () {
              if (_normalizePhone(ctrl.text) == _normalizePhone(phone)) {
                Navigator.pop(ctx, ctrl.text.trim());
              } else {
                setS(() => err = 'Namba hazilingani');
              }
            },
            child: const Text('THIBITISHA', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    ),
  );
  return result;
}

/// Bottom sheet with all packages (from GET config). Returns the chosen type.
Future<String?> _pickPackage(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    isScrollControlled: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('CHAGUA KIFURUSHI CHA KULIPIA',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('Ukilipia tena kabla muda haujaisha, muda mpya unaongezwa juu ya uliobaki.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ),
          const SizedBox(height: 16),
          ...AppState.I.packages.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PackageCard(package: p, onBuy: () => Navigator.pop(sheetCtx, p.type)),
              )),
        ],
      ),
    ),
  );
}
