// ============================================================
// MIKEKA APP - FLUTTER MOBILE APPLICATION
// Single-file complete app using REST API at https://mikekaapp.co.tz/
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================
// MAIN ENTRY POINT
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const MikekaApp());
}

// ============================================================
// APP CONFIGURATION
// ============================================================
class AppConfig {
  static const String API_BASE = 'https://mikekaapp.co.tz/api.php';
  static const String APP_NAME = 'MIKEKA APP';
  static const String VERSION = '1.0.0';
  static const String WASHINDI_URL = 'https://mikekaapp.co.tz/users.php';
  static const String SUPPORT_EMAIL = 'admin@mikekaapp.com';

  static late FlutterSecureStorage secureStorage;
  static late SharedPreferences prefs;
  static late DeviceInfoPlugin deviceInfo;
  static late FlutterLocalNotificationsPlugin notifications;

  static String? deviceId;
  static String? deviceModel;

  static Future<void> initialize() async {
    secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    prefs = await SharedPreferences.getInstance();
    deviceInfo = DeviceInfoPlugin();
    notifications = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await notifications.initialize(initSettings);

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
        deviceModel = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor;
        deviceModel = info.name;
      }
    } catch (_) {}
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
// API CLIENT
// ============================================================
class ApiClient {
  static const String _tokenKey = 'mikeka_session_token';
  static String? _cachedToken;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await AppConfig.secureStorage.read(key: _tokenKey);
    return _cachedToken;
  }

  static Future<void> setToken(String? token) async {
    _cachedToken = token;
    if (token == null) {
      await AppConfig.secureStorage.delete(key: _tokenKey);
    } else {
      await AppConfig.secureStorage.write(key: _tokenKey, value: token);
    }
  }

  static Map<String, String> _headers(String? token) {
    final h = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['X-Session-Token'] = token;
    }
    if (AppConfig.deviceId != null) {
      h['X-Device-Hash'] = AppConfig.deviceId!;
    }
    return h;
  }

  static Future<ApiResponse> post(
    String action, {
    Map<String, dynamic>? data,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final body = <String, String>{'action': action};
      data?.forEach((k, v) {
        if (v != null) body[k] = v.toString();
      });

      final res = await http
          .post(
            Uri.parse(AppConfig.API_BASE),
            headers: _headers(token),
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      return _parse(res);
    } catch (e) {
      return ApiResponse(success: false, error: 'Hitilafu ya mtandao. Angalia internet.');
    }
  }

  static Future<ApiResponse> get(
    String action, {
    Map<String, dynamic>? data,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final params = <String, String>{'action': action};
      data?.forEach((k, v) {
        if (v != null) params[k] = v.toString();
      });
      final uri = Uri.parse(AppConfig.API_BASE).replace(queryParameters: params);

      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 25));

      return _parse(res);
    } catch (e) {
      return ApiResponse(success: false, error: 'Hitilafu ya mtandao. Angalia internet.');
    }
  }

  static ApiResponse _parse(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse.fromJson(data, res.statusCode);
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Server response si sahihi.',
        statusCode: res.statusCode,
      );
    }
  }
}

class ApiResponse {
  final bool success;
  final String? error;
  final int statusCode;
  final Map<String, dynamic> data;

  ApiResponse({
    required this.success,
    this.error,
    this.statusCode = 200,
    this.data = const {},
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, int code) {
    return ApiResponse(
      success: json['success'] == true,
      error: json['error']?.toString(),
      statusCode: code,
      data: json,
    );
  }

  dynamic operator [](String key) => data[key];
  bool get isBanned => data['banned'] == true || data['session_status'] == 'banned';
  bool get isKicked => data['session_status'] == 'kicked';
  bool get isLoginRequired => data['login_required'] == true;
}

// ============================================================
// APP STATE (GLOBAL)
// ============================================================
class AppState extends ChangeNotifier {
  static final AppState I = AppState._();
  AppState._();

  bool loggedIn = false;
  bool isTipster = false;
  bool isSubscribed = false;
  Map<String, dynamic>? user;
  Map<String, dynamic>? subscription;
  List<dynamic> payments = [];
  List<dynamic> todaysSlips = [];
  List<dynamic> allSlips = [];
  List<dynamic> bettingCompanies = [];
  List<dynamic> tipsters = [];
  List<dynamic> followedTipsters = [];
  List<dynamic> singleSlips = [];
  List<dynamic> purchasedSingleSlips = [];
  List<String> dismissedPopups = [];
  String? displayPhone;

  Map<String, dynamic>? activeWarning;

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

  void applyUserData(Map<String, dynamic> d) {
    user = Map<String, dynamic>.from(d['user'] ?? {});
    displayPhone = d['display_phone'];
    subscription = d['subscription'] != null ? Map<String, dynamic>.from(d['subscription']) : null;
    payments = d['payments'] ?? [];
    todaysSlips = d['todays_slips'] ?? [];
    allSlips = d['all_slips'] ?? [];
    bettingCompanies = d['betting_companies'] ?? [];
    tipsters = d['tipsters'] ?? [];
    followedTipsters = d['followed_tipsters'] ?? [];
    purchasedSingleSlips = d['purchased_single_slips'] ?? [];
    isTipster = d['is_tipster'] == true;
    isSubscribed = d['is_subscribed'] == true;
    dismissedPopups = _parseDismissed(user?['dismissed_popups']);
    loggedIn = true;
    notifyListeners();
  }

  List<String> _parseDismissed(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      final parsed = jsonDecode(raw.toString());
      if (parsed is List) return parsed.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  bool isPopupDismissed(String type) => dismissedPopups.contains(type);
}

// ============================================================
// ROOT APP WIDGET
// ============================================================
class MikekaApp extends StatefulWidget {
  const MikekaApp({super.key});
  @override
  State<MikekaApp> createState() => _MikekaAppState();
}

class _MikekaAppState extends State<MikekaApp> {
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navKey,
      home: const SplashScreen(),
    );
  }
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
    await Future.delayed(const Duration(milliseconds: 800));
    final token = await ApiClient.getToken();
    if (token != null && token.isNotEmpty) {
      final res = await ApiClient.post('get_user_data');
      if (res.success) {
        AppState.I.applyUserData(res.data);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
          return;
        }
      } else {
        await ApiClient.setToken(null);
      }
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
              CircularProgressIndicator(color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN (Bottom Navigation)
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  Timer? _sessionTimer;
  Timer? _winTimer;

  final List<Widget> _screens = const [
    TipstersTab(),
    MikekaTab(),
    SingleSlipsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    if (AppState.I.loggedIn) {
      _startSessionHealthCheck();
      _startWinCheck();
      _checkImmediateWarning();
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _winTimer?.cancel();
    super.dispose();
  }

  void _startSessionHealthCheck() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final res = await ApiClient.post('check_session');
      if (!res.success && (res.isBanned || res.isKicked)) {
        _handleSessionInvalid(res);
      }
    });
  }

  void _startWinCheck() {
    _winTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || !AppState.I.loggedIn) return;
      if (AppState.I.isPopupDismissed('win_popup')) return;
      final res = await ApiClient.post('check_new_win');
      if (res.success && res['show_popup'] == true && res['betslip'] != null) {
        _showWinPopup(Map<String, dynamic>.from(res['betslip']));
      }
    });
  }

  Future<void> _checkImmediateWarning() async {
    if (AppState.I.isPopupDismissed('warning_popup')) return;
    final res = await ApiClient.post('check_immediate_warning');
    if (res.success && res['show_warning'] == true) {
      _showWarningPopup(
        res['message']?.toString() ?? 'Kuna jambo linahitaji uangalie.',
        res['severity']?.toString() ?? 'medium',
      );
    }
  }

  void _handleSessionInvalid(ApiResponse res) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          res.isBanned ? 'AKAUNTI IMEFUNGWA' : 'UMESAJILIWA NJE',
          style: TextStyle(
            color: res.isBanned ? AppColors.red : AppColors.warn,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          res['ban_reason']?.toString() ??
              (res.isKicked
                  ? 'Umeingiwa kwenye kifaa kingine. Tafadhali ingia tena.'
                  : res.error ?? 'Session imekwisha.'),
          style: const TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiClient.setToken(null);
              AppState.I.setLoggedOut();
              if (mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('SAWA', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showWinPopup(Map<String, dynamic> slip) {
    if (!mounted) return;
    showDialog(
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
              _winRow('Kampuni', slip['company_name']?.toString() ?? '--'),
              _winRow('Tarehe', slip['created_date']?.toString() ?? '--'),
              const SizedBox(height: 16),
              const Text(
                'Hongera sana! Endelea kufuatilia mikeka yetu ya uhakika! 💪🔥',
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
                  onPressed: () async {
                    final dismiss = await _askDismiss();
                    if (dismiss) {
                      await ApiClient.post('dismiss_popup', data: {'popup_type': 'win_popup'});
                      AppState.I.dismissedPopups.add('win_popup');
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('ASANTE SANA!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _askDismiss() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Onyesho la ushindi', style: TextStyle(color: AppColors.text)),
            content: const Text(
              'Usionyeshe tena ujumbe huu wa ushindi?',
              style: TextStyle(color: AppColors.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('HAPANA', style: TextStyle(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('NDIYO', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ) ??
        false;
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

  void _showWarningPopup(String message, String severity) {
    if (!mounted) return;
    final isHigh = severity == 'high' || severity == 'critical';
    showDialog(
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
                    final dismiss = await _askDismiss();
                    if (dismiss) {
                      await ApiClient.post('dismiss_popup', data: {'popup_type': 'warning_popup'});
                      AppState.I.dismissedPopups.add('warning_popup');
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('NIMEKUELEWA'),
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
      {'icon': Icons.confirmation_num_outlined, 'active': Icons.confirmation_num, 'label': 'Mikeka'},
      {'icon': Icons.track_changes_outlined, 'active': Icons.track_changes, 'label': 'Single'},
      {'icon': Icons.person_outline, 'active': Icons.person, 'label': 'Profile'},
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
                if (i == 0) _refresh();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? items[i]['active'] as IconData : items[i]['icon'] as IconData,
                    color: active ? AppColors.accent : AppColors.muted,
                    size: 22,
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

  Future<void> _refresh() async {
    if (!AppState.I.loggedIn) return;
    final res = await ApiClient.post('get_user_data');
    if (res.success) {
      AppState.I.applyUserData(res.data);
    }
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

class _TipstersTabState extends State<TipstersTab> {
  List<dynamic> tipsters = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final res = await ApiClient.get('get_tipsters');
    if (res.success) {
      tipsters = res['tipsters'] ?? [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleFollow(int tipsterId, bool current) async {
    if (!AppState.I.loggedIn) {
      _showLoginPrompt(context);
      return;
    }
    final res = await ApiClient.post(current ? 'unfollow_tipster' : 'follow_tipster',
        data: {'tipster_id': tipsterId});
    if (res.success) {
      _showSnack(context, res['message']?.toString() ?? 'Umefanikiwa!');
      _load();
    } else {
      _showSnack(context, res.error ?? 'Hitilafu', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TIPSTERS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: tipsters.isEmpty
                  ? _emptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: tipsters.length,
                      itemBuilder: (_, i) => _tipsterCard(Map<String, dynamic>.from(tipsters[i])),
                    ),
            ),
    );
  }

  Widget _emptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.people_outline, size: 60, color: AppColors.muted),
        SizedBox(height: 12),
        Center(
          child: Text('HAKUNA TIPSTERS BADO',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _tipsterCard(Map<String, dynamic> t) {
    final name = (t['tipster_name'] ?? t['name'] ?? 'Tipster').toString();
    final verified = t['tipster_verified'] == true || t['tipster_verified'] == 1;
    final isFollowing = t['is_following'] == true;
    final rating = double.tryParse(t['tipster_rating']?.toString() ?? '5') ?? 5.0;
    final winRate = double.tryParse(t['tipster_success_rate']?.toString() ?? '75') ?? 75;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TipsterDetailScreen(tipsterId: t['id'])),
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.gold],
                    ),
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: ClipOval(
                    child: (t['tipster_avatar']?.toString().startsWith('http') ?? false)
                        ? Image.network(
                            t['tipster_avatar'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initials(name),
                          )
                        : _initials(name),
                  ),
                ),
                if (verified)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DA1F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 13),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(color: AppColors.gold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip('${t['tips_count'] ?? 0}', 'tips'),
                _statChip('${winRate.toStringAsFixed(0)}%', 'win'),
              ],
            ),
            const SizedBox(height: 4),
            Text('${t['followers_count'] ?? 0} followers',
                style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            const SizedBox(height: 8),
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
                onPressed: () => _toggleFollow(t['id'], isFollowing),
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
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name) {
    return Container(
      color: AppColors.accent.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'T',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 24,
          fontWeight: FontWeight.w900,
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

class _TipsterDetailScreenState extends State<TipsterDetailScreen> {
  Map<String, dynamic>? tipster;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final res = await ApiClient.post('get_tipster_with_slips',
        data: {'tipster_id': widget.tipsterId});
    if (res.success && res['tipster'] != null) {
      tipster = Map<String, dynamic>.from(res['tipster']);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleFollow() async {
    if (!AppState.I.loggedIn) {
      _showLoginPrompt(context);
      return;
    }
    final isFollowing = tipster?['is_following'] == true;
    final res = await ApiClient.post(isFollowing ? 'unfollow_tipster' : 'follow_tipster',
        data: {'tipster_id': widget.tipsterId});
    if (res.success) {
      _showSnack(context, res['message']?.toString() ?? 'Ok');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text((tipster?['tipster_name'] ?? 'Tipster').toString())),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : tipster == null
              ? const Center(child: Text('Tipster haipatikani', style: TextStyle(color: AppColors.muted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _followButton(),
                      const SizedBox(height: 16),
                      ..._slips(),
                      ..._singleSlips(),
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    final t = tipster!;
    final name = (t['tipster_name'] ?? t['name'] ?? 'Tipster').toString();
    final verified = t['tipster_verified'] == true || t['tipster_verified'] == 1;
    final rating = double.tryParse(t['tipster_rating']?.toString() ?? '5') ?? 5.0;
    final winRate = double.tryParse(t['tipster_success_rate']?.toString() ?? '75') ?? 75;
    final badge = t['tipster_badge']?.toString();

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
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.gold]),
                  border: Border.all(color: AppColors.bg, width: 3),
                ),
                child: ClipOval(
                  child: (t['tipster_avatar']?.toString().startsWith('http') ?? false)
                      ? Image.network(
                          t['tipster_avatar'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'T',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
              if (verified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DA1F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (badge != null && badge.isNotEmpty) ...[
            const SizedBox(height: 4),
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
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statBox('${t['followers_count'] ?? 0}', 'Wafuasi'),
              _statBox('${t['tips_count'] ?? 0}', 'Tips'),
              _statBox('${winRate.toStringAsFixed(0)}%', 'Mafanikio'),
            ],
          ),
          if (t['tipster_bio']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t['tipster_bio'].toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      ],
    );
  }

  Widget _followButton() {
    final isFollowing = tipster?['is_following'] == true;
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

  List<Widget> _slips() {
    final slips = tipster?['slips'];
    if (slips is List && slips.isNotEmpty) {
      final isSubscribed = AppState.I.isSubscribed;
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('MIKEKA MIPYA',
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ),
        ...slips.map((s) => BetslipCard(slip: Map<String, dynamic>.from(s), isBlurred: !isSubscribed)),
      ];
    }

    final sys = tipster?['system_betslip'];
    if (sys != null) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('MKEKA WA SYSTEM',
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ),
        BetslipCard(slip: Map<String, dynamic>.from(sys), isBlurred: !AppState.I.isSubscribed),
      ];
    }

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Tipster huyu hajatoa mikeka bado. Follow kupata notification.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ];
  }

  List<Widget> _singleSlips() {
    final single = tipster?['single_slips'];
    if (single is! List || single.isEmpty) return [];
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('MIKEKA YA SINGLE',
              style: TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ),
      ...single.map((s) => SingleSlipCard(slip: Map<String, dynamic>.from(s))),
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

class _MikekaTabState extends State<MikekaTab> {
  Map<String, dynamic>? previewSlip;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    if (AppState.I.loggedIn) {
      final res = await ApiClient.post('get_user_data');
      if (res.success) AppState.I.applyUserData(res.data);
    } else {
      // Guest
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _buyPackage(String type) async {
    if (!AppState.I.loggedIn) {
      _showLoginPrompt(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PayPackageScreen(packageType: type)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIKEKA YA LEO'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: _content(),
            ),
    );
  }

  Widget _content() {
    if (!AppState.I.loggedIn) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _guestBanner(),
          const SizedBox(height: 20),
          _packagesGrid(),
        ],
      );
    }

    if (!AppState.I.isSubscribed) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _lockedCard(),
          const SizedBox(height: 20),
          _packagesGrid(),
        ],
      );
    }

    if (AppState.I.todaysSlips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _emptySlipsCard(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: AppState.I.todaysSlips
          .map((s) => BetslipCard(slip: Map<String, dynamic>.from(s), isBlurred: false))
          .toList(),
    );
  }

  Widget _guestBanner() {
    return InkWell(
      onTap: () => _showLoginPrompt(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold.withOpacity(0.12), AppColors.gold.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.gold, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karibu Mikeka App!',
                      style: TextStyle(
                          color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Ingia au jisajili ili kuweza kununua mikeka na kufuata tipsters',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
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
              style: TextStyle(
                  color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Lipia kifurushi chochote ili kuona mkeka wa leo wenye odds za uhakika!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPackagesSheet(context, _buyPackage),
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
              style: TextStyle(
                  color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
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
        const Text('CHAGUA KIFURUSHI',
            style: TextStyle(
                color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 12),
        _packageCard('NORMAL', '3,000', 'Siku 1 (Masaa 24)', AppColors.accent2, 'normal'),
        const SizedBox(height: 10),
        _packageCard('TANZANITE', '5,000', 'Siku 3 (Masaa 72)', AppColors.tanzanite, 'tanzanite'),
        const SizedBox(height: 10),
        _packageCard('VIP', '10,000', 'Siku 7 (Wiki 1)', AppColors.gold, 'vip'),
        const SizedBox(height: 10),
        _packageCard('VVIP', '30,000', 'Siku 30 (Mwezi 1)', AppColors.red, 'vvip'),
      ],
    );
  }

  Widget _packageCard(String name, String price, String duration, Color color, String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bg2, color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(duration,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('TSh $price/=',
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
              ),
              onPressed: () => _buyPackage(type),
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text('LIPIA TSh $price/= — $name'),
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

class _SingleSlipsTabState extends State<SingleSlipsTab> {
  List<dynamic> slips = [];
  List<dynamic> purchased = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final res = await ApiClient.get('get_single_slips');
    if (res.success) {
      slips = res['slips'] ?? [];
    }
    if (AppState.I.loggedIn) {
      final my = await ApiClient.post('get_my_single_slips');
      if (my.success) purchased = my['slips'] ?? [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _buy(Map<String, dynamic> slip) async {
    if (!AppState.I.loggedIn) {
      _showLoginPrompt(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuySingleSlipScreen(slip: slip)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SINGLE SLIPS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (slips.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.track_changes, color: AppColors.muted, size: 48),
                          SizedBox(height: 12),
                          Text('HAKUNA MIKEKA YA SINGLE',
                              style: TextStyle(
                                  color: AppColors.muted, fontWeight: FontWeight.w900)),
                          SizedBox(height: 8),
                          Text(
                            'Wataalam wetu hawajatoa mikeka ya single bado. Endelea kufuatilia!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Text('MIKEKA YA SINGLE — NUNUA MMOJA MMOJA',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    ...slips.map((s) {
                      final m = Map<String, dynamic>.from(s);
                      return SingleSlipCard(
                        slip: m,
                        onBuy: () => _buy(m),
                      );
                    }),
                  ],
                  if (AppState.I.loggedIn && purchased.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('MIKEKA YANGU YA SINGLE',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    ...purchased.map((s) => SingleSlipCard(
                          slip: Map<String, dynamic>.from(s),
                          purchased: true,
                        )),
                  ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 80, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text('Karibu Mikeka App',
                style: TextStyle(
                    color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
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
          ],
        ),
      ),
    );
  }

  Widget _loggedInBody() {
    final u = AppState.I.user ?? {};
    final sub = AppState.I.subscription;
    return ListView(
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
                AppState.I.displayPhone ?? u['phone_number']?.toString() ?? '',
                style: const TextStyle(
                    color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(u['name']?.toString() ?? 'Customer',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              if (AppState.I.isTipster) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('⭐ TIPSTER',
                      style: TextStyle(
                          color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _subscriptionCard(sub),
        const SizedBox(height: 16),
        _actionTile(Icons.phone, 'Badilisha Namba', () => _changePhone(context)),
        _actionTile(Icons.history, 'Historia ya Malipo', () => _showPayments(context)),
        _actionTile(Icons.emoji_events, 'Washindi', () => _openWashindi(context)),
        _actionTile(Icons.logout, 'Toka', () => _logout(context), color: AppColors.red),
      ],
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
                style: TextStyle(
                    color: AppColors.warn, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showPackagesSheet(context, (p) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PayPackageScreen(packageType: p)),
                  );
                }),
                child: const Text('LIPIA SASA'),
              ),
            ),
          ],
        ),
      );
    }

    final endDate = sub['end_date']?.toString();
    final packageType = sub['package_type']?.toString() ?? 'normal';
    final end = endDate != null ? DateTime.tryParse(endDate) : null;
    String remaining = '--';
    if (end != null) {
      final diff = end.difference(DateTime.now());
      if (diff.inSeconds <= 0) {
        remaining = 'IMEISHA';
      } else if (diff.inDays >= 1) {
        remaining = '${diff.inDays}siku ${diff.inHours % 24}h ${diff.inMinutes % 60}m';
      } else if (diff.inHours >= 1) {
        remaining = '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        remaining = '${diff.inMinutes} dakika';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.crown, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text('KIFURUSHI: ${packageType.toUpperCase()}',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Inabaki: $remaining',
              style: const TextStyle(color: AppColors.accent, fontSize: 13)),
          if (end != null)
            Text(
              'Inaisha: ${end.day}/${end.month}/${end.year} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
            style: TextStyle(
                color: color ?? AppColors.text, fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
      ),
    );
  }

  Future<void> _changePhone(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Badilisha Namba', style: TextStyle(color: AppColors.accent)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: '0762xxxxxx au 255762xxxxxx'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('BADILISHA', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiClient.post('update_phone', data: {'phone': ctrl.text.trim()});
    if (context.mounted) {
      _showSnack(context, res.success ? (res['message'] ?? 'Imebadilishwa') : (res.error ?? 'Hitilafu'),
          isError: !res.success);
      if (res.success) {
        final u = await ApiClient.post('get_user_data');
        if (u.success) AppState.I.applyUserData(u.data);
      }
    }
  }

  Future<void> _showPayments(BuildContext context) async {
    final res = await ApiClient.post('get_user_data');
    if (!res.success) return;
    final payments = res['payments'] as List? ?? [];
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('HISTORIA YA MALIPO',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Hakuna malipo bado', style: TextStyle(color: AppColors.muted)),
              )
            else
              ...payments.map((p) {
                final m = Map<String, dynamic>.from(p);
                return ListTile(
                  leading: Icon(
                    m['payment_status'] == 'completed' ? Icons.check_circle : Icons.access_time,
                    color: m['payment_status'] == 'completed' ? AppColors.success : AppColors.warn,
                  ),
                  title: Text('TSh ${m['amount']}',
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text('${m['package_type']} • ${m['created_at']}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  trailing: Text((m['payment_status'] ?? '').toString().toUpperCase(),
                      style: TextStyle(
                          color: m['payment_status'] == 'completed' ? AppColors.success : AppColors.warn,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _openWashindi(BuildContext context) async {
    final uri = Uri.parse(AppConfig.WASHINDI_URL);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Toka?', style: TextStyle(color: AppColors.text)),
        content: const Text('Una uhakika unataka kutoka?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('HAPANA', style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('NDIYO', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await ApiClient.post('logout');
    await ApiClient.setToken(null);
    AppState.I.setLoggedOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (r) => false,
      );
    }
  }
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

  String _maskCode(String? code) {
    if (code == null) return '***';
    if (!isBlurred) return code;
    if (code.length <= 3) return '$code***';
    return '${code.substring(0, 3)}***';
  }

  @override
  Widget build(BuildContext context) {
    final bookingCode = slip['booking_code']?.toString() ?? '';
    final maskedCode = _maskCode(bookingCode);
    final odds = slip['odds']?.toString();
    final companyName = slip['company_name']?.toString();
    final companyLogo = slip['logo_url']?.toString();
    final matchDetails = slip['match_details']?.toString() ?? '';
    final packageType = slip['package_type']?.toString();
    final resultStatus = slip['result_status']?.toString() ?? 'pending';
    final validity = slip['validity_time']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                if (companyLogo != null && companyLogo.isNotEmpty)
                  Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.network(
                      companyLogo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (companyName != null && companyName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                ],
                if (packageType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Text(packageType.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
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
                    border: Border.all(color: AppColors.accent.withOpacity(0.3), style: BorderStyle.solid),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    maskedCode,
                    style: TextStyle(
                      color: isBlurred ? AppColors.gold : AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                if (isBlurred)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: AppColors.accent, size: 28),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isBlurred && matchDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(matchDetails,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ),
          // Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (odds != null && odds.isNotEmpty)
                  _badge(Icons.show_chart, 'ODDS: $odds', AppColors.gold),
                if (resultStatus == 'won')
                  _badge(Icons.check_circle, 'WON', AppColors.success)
                else if (resultStatus == 'lost')
                  _badge(Icons.cancel, 'LOST', AppColors.red)
                else
                  _badge(Icons.access_time, 'PENDING', AppColors.warn),
                if (isSystemGenerated || slip['slip_type'] == 'system')
                  _badge(Icons.smart_toy, 'SYSTEM', AppColors.accent2),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                if (validity != null && validity.isNotEmpty) ...[
                  const Icon(Icons.hourglass_bottom, color: AppColors.muted, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Expires: $validity',
                        style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                  ),
                ],
                if (!isBlurred)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.copy, size: 14, color: AppColors.accent),
                    label: const Text('Copy',
                        style: TextStyle(color: AppColors.accent, fontSize: 11)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: bookingCode));
                      _showSnack(context, 'Booking code imenakiliwa!');
                    },
                  ),
              ],
            ),
          ),
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
          Text(label,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
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
    final price = int.tryParse(slip['price']?.toString() ?? '3000') ?? 3000;
    final bookingCode = slip['booking_code']?.toString() ?? '';
    final maskedCode = purchased ? bookingCode : '${bookingCode.length > 3 ? bookingCode.substring(0, 3) : bookingCode}***';
    final tipsterName = slip['tipster_name']?.toString();
    final tipsterAvatar = slip['tipster_avatar']?.toString();
    final companyName = slip['company_name']?.toString();
    final companyLogo = slip['logo_url']?.toString();
    final matchDetails = slip['match_details']?.toString() ?? '';
    final odds = slip['odds']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: purchased ? AppColors.success.withOpacity(0.3) : AppColors.gold.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (companyLogo != null && companyLogo.isNotEmpty) ...[
                Image.network(companyLogo,
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const SizedBox(width: 6),
              ],
              if (companyName != null)
                Expanded(
                  child: Text(companyName,
                      style: const TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              if (purchased)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('UMELIPIA',
                      style: TextStyle(
                          color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: Text('${price.toString()}/=',
                      style: const TextStyle(
                          color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          if (tipsterName != null && tipsterName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.gold.withOpacity(0.2),
                  backgroundImage: (tipsterAvatar?.startsWith('http') ?? false)
                      ? NetworkImage(tipsterAvatar!)
                      : null,
                  child: (tipsterAvatar?.startsWith('http') ?? false)
                      ? null
                      : Text(tipsterName[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.gold, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mkeka wa Tipster',
                          style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(tipsterName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ),
              ],
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
                      color: purchased ? AppColors.success.withOpacity(0.3) : AppColors.gold.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  maskedCode,
                  style: TextStyle(
                    color: purchased ? AppColors.accent : AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              if (!purchased)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, color: AppColors.gold, size: 24),
                    ),
                  ),
                ),
            ],
          ),
          if (matchDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              purchased
                  ? matchDetails
                  : (matchDetails.length > 30
                      ? '${matchDetails.substring(0, 30)}... [LIPIA KUONA ZAIDI]'
                      : matchDetails),
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ],
          if (odds != null && odds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.show_chart, color: AppColors.gold, size: 14),
                const SizedBox(width: 4),
                Text('ODDS: $odds',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
          if (!purchased && onBuy != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.shopping_cart, size: 16),
                label: Text('LIPIA ${price.toString()}/='),
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
// PAY PACKAGE SCREEN
// ============================================================
class PayPackageScreen extends StatefulWidget {
  final String packageType;
  const PayPackageScreen({super.key, required this.packageType});

  @override
  State<PayPackageScreen> createState() => _PayPackageScreenState();
}

class _PayPackageScreenState extends State<PayPackageScreen> {
  static const Map<String, Map<String, dynamic>> _packages = {
    'normal': {'name': 'NORMAL', 'price': 3000, 'duration': 'Siku 1 (Masaa 24)'},
    'tanzanite': {'name': 'TANZANITE', 'price': 5000, 'duration': 'Siku 3 (Masaa 72)'},
    'vip': {'name': 'VIP', 'price': 10000, 'duration': 'Siku 7 (Wiki 1)'},
    'vvip': {'name': 'VVIP', 'price': 30000, 'duration': 'Siku 30 (Mwezi 1)'},
  };

  final phoneCtrl = TextEditingController();
  String? selectedNetwork;
  bool loading = false;
  Timer? _poll;
  int _pollCount = 0;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    phoneCtrl.text = AppState.I.displayPhone ?? AppState.I.user?['phone_number']?.toString() ?? '';
  }

  @override
  void dispose() {
    _poll?.cancel();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = phoneCtrl.text.trim();
    if (phone.length < 9) {
      _showSnack(context, 'Ingiza namba sahihi', isError: true);
      return;
    }
    setState(() => loading = true);

    final res = await ApiClient.post('create_order', data: {
      'buyer_phone': phone,
      'package_type': widget.packageType,
    });

    setState(() => loading = false);

    if (res.success && res['order_id'] != null) {
      _orderId = res['order_id'].toString();
      _showUssdDialog();
      _startPolling();
    } else {
      _showSnack(context, res.error ?? 'Malipo yameshindikana', isError: true);
    }
  }

  void _showUssdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Angalia Simu Yako',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_iphone, size: 60, color: AppColors.accent),
              const SizedBox(height: 12),
              const Text(
                'Ujumbe wa malipo umetumwa kwenye simu yako. Tafadhali ingiza namba yako ya siri kuthibitisha.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(phoneCtrl.text, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _poll?.cancel();
              },
              child: const Text('FUNGA', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollCount = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      _pollCount++;
      if (_orderId == null) return;
      final res = await ApiClient.post('check_status', data: {'order_id': _orderId});
      if (res.success && res['is_payment_successful'] == true) {
        t.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        _showCongrats();
        await _refreshUser();
      } else if (_pollCount >= 30) {
        t.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        _showSnack(context, 'Malipo hayajakamilika. Jaribu tena.', isError: true);
      }
    });
  }

  Future<void> _refreshUser() async {
    final res = await ApiClient.post('get_user_data');
    if (res.success) AppState.I.applyUserData(res.data);
  }

  void _showCongrats() {
    final pkg = _packages[widget.packageType]!;
    showDialog(
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
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text('Malipo yako yamekamilika kwa ufanisi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              Text(pkg['name'].toString(),
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(pkg['duration'].toString(),
                  style: const TextStyle(color: AppColors.accent, fontSize: 12)),
              const SizedBox(height: 8),
              Text('TSh ${pkg['price']}/=',
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
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
    final pkg = _packages[widget.packageType]!;
    final color = widget.packageType == 'vip'
        ? AppColors.gold
        : widget.packageType == 'vvip'
            ? AppColors.red
            : widget.packageType == 'tanzanite'
                ? AppColors.tanzanite
                : AppColors.accent2;

    return Scaffold(
      appBar: AppBar(title: Text('LIPIA ${pkg['name']}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.card, color.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(pkg['name'].toString(),
                      style: TextStyle(
                          color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text(pkg['duration'].toString(),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('TSh ${pkg['price']}/=',
                      style: TextStyle(
                          color: color, fontSize: 32, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Namba ya Simu ya Kulipa',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.text, fontSize: 16, letterSpacing: 1),
              decoration: const InputDecoration(
                hintText: '0762xxxxxx au 255762xxxxxx',
                prefixIcon: Icon(Icons.phone, color: AppColors.accent),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            ),
            const SizedBox(height: 18),
            const Text('Chagua Mtandao (Si lazima)',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _networkBtn('VODACOM', 'vodacom'),
                const SizedBox(width: 8),
                _networkBtn('YAS', 'yas'),
                const SizedBox(width: 8),
                _networkBtn('AIRTEL', 'airtel'),
                const SizedBox(width: 8),
                _networkBtn('HALOTEL', 'halotel'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : _pay,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text('LIPIA TSh ${pkg['price']}/=', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkBtn(String label, String code) {
    final selected = selectedNetwork == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedNetwork = selected ? null : code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.12) : AppColors.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: selected ? AppColors.accent : AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
              if (selected) const Icon(Icons.check_circle, color: AppColors.accent, size: 14),
            ],
          ),
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

class _BuySingleSlipScreenState extends State<BuySingleSlipScreen> {
  final phoneCtrl = TextEditingController();
  String? selectedNetwork;
  bool loading = false;
  Timer? _poll;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    phoneCtrl.text = AppState.I.displayPhone ?? AppState.I.user?['phone_number']?.toString() ?? '';
  }

  @override
  void dispose() {
    _poll?.cancel();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = phoneCtrl.text.trim();
    if (phone.length < 9) {
      _showSnack(context, 'Ingiza namba sahihi', isError: true);
      return;
    }
    setState(() => loading = true);
    final res = await ApiClient.post('create_single_slip_order', data: {
      'buyer_phone': phone,
      'betslip_id': widget.slip['id'],
    });
    setState(() => loading = false);

    if (res.success && res['order_id'] != null) {
      _showUssd();
      _startPolling(res['order_id'].toString());
    } else {
      _showSnack(context, res.error ?? 'Malipo yameshindikana', isError: true);
    }
  }

  void _showUssd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Angalia Simu Yako',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_iphone, size: 60, color: AppColors.gold),
              const SizedBox(height: 12),
              const Text(
                'Ujumbe wa malipo umetumwa kwenye simu yako. Ingiza namba yako ya siri kuthibitisha.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _poll?.cancel();
              },
              child: const Text('FUNGA', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  void _startPolling(String orderId) {
    _pollCount = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      _pollCount++;
      final res = await ApiClient.post('check_status', data: {'order_id': orderId});
      if (res.success && res['is_payment_successful'] == true) {
        t.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        _showSuccess();
      } else if (_pollCount >= 30) {
        t.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        _showSnack(context, 'Malipo hayajakamilika. Jaribu tena.', isError: true);
      }
    });
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('HONGERA! 🎯',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
        content: const Text(
          'Umefanikiwa kununua mkeka single! Booking code yako ipo tayari kwenye "Mikeka Yangu".',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('SAWA', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slip;
    final price = int.tryParse(slip['price']?.toString() ?? '3000') ?? 3000;
    final companyName = slip['company_name']?.toString();
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
                  if (companyName != null)
                    Text(companyName,
                        style: const TextStyle(
                            color: AppColors.accent, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('BEI YA MKEKA',
                      style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('TSh $price/=',
                      style: const TextStyle(
                          color: AppColors.gold, fontSize: 28, fontWeight: FontWeight.w900)),
                  if (matchDetails.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(matchDetails,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Namba ya Simu ya Kulipa',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.text, fontSize: 16, letterSpacing: 1),
              decoration: const InputDecoration(
                hintText: '0762xxxxxx au 255762xxxxxx',
                prefixIcon: Icon(Icons.phone, color: AppColors.accent),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            ),
            const SizedBox(height: 18),
            const Text('Chagua Mtandao (Si lazima)',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _net('VODACOM', 'vodacom'),
                const SizedBox(width: 8),
                _net('YAS', 'yas'),
                const SizedBox(width: 8),
                _net('AIRTEL', 'airtel'),
                const SizedBox(width: 8),
                _net('HALOTEL', 'halotel'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _pay,
                icon: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.shopping_cart),
                label: Text('LIPIA TSh $price/='),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _net(String label, String code) {
    final selected = selectedNetwork == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedNetwork = selected ? null : code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withOpacity(0.12) : AppColors.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: selected ? AppColors.gold : AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
              if (selected) const Icon(Icons.check_circle, color: AppColors.gold, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SHARED HELPERS
// ============================================================
void _showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error : Icons.check_circle,
              color: isError ? AppColors.red : AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppColors.red.withOpacity(0.9) : AppColors.card2,
      duration: Duration(seconds: isError ? 4 : 3),
    ),
  );
}

Future<void> _showLoginPrompt(BuildContext context) async {
  final phoneCtrl = TextEditingController();
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('INGIA / JISAJILI',
                  style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: Completer.sync().isCompleted ? MainAxisSize.max : MainAxisSize.min,
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
              style: const TextStyle(color: AppColors.text, fontSize: 16, letterSpacing: 1),
              decoration: const InputDecoration(
                hintText: '0762xxxxxx au 255762xxxxxx',
                prefixIcon: Icon(Icons.phone, color: AppColors.accent),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12)
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Unaweza kuingiza namba kuanzia 0 (076...) au 255 (255762...)',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    final phone = phoneCtrl.text.trim();
                    if (phone.length < 9) {
                      _showSnack(ctx, 'Ingiza namba sahihi', isError: true);
                      return;
                    }
                    setS(() => loading = true);
                    final res = await ApiClient.post('login',
                        data: {'phone': phone}, requiresAuth: false);

                    if (res.success) {
                      if (res['action'] == 'need_confirmation') {
                        setS(() => loading = false);
                        final confirmed = await _showConfirmDialog(ctx, phone);
                        if (confirmed) {
                          final cres = await ApiClient.post('confirm_phone',
                              data: {'phone': phone}, requiresAuth: false);
                          if (cres.success && cres['session_token'] != null) {
                            await ApiClient.setToken(cres['session_token'].toString());
                            final ud = await ApiClient.post('get_user_data');
                            if (ud.success) AppState.I.applyUserData(ud.data);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          }
                        }
                      } else if (res['session_token'] != null) {
                        await ApiClient.setToken(res['session_token'].toString());
                        final ud = await ApiClient.post('get_user_data');
                        if (ud.success) AppState.I.applyUserData(ud.data);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      }
                    } else if (res.isBanned) {
                      setS(() => loading = false);
                      _showSnack(ctx, res['ban_reason']?.toString() ?? 'Akaunti imefungwa',
                          isError: true);
                    } else {
                      setS(() => loading = false);
                      _showSnack(ctx, res.error ?? 'Hitilafu', isError: true);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('ENDELEA'),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}

Future<bool> _showConfirmDialog(BuildContext context, String phone) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('RUDIA TENA NAMBA YAKO',
          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(phone,
              style: const TextStyle(
                  color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('Ingiza namba tena kuhakiki',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
            decoration: const InputDecoration(hintText: 'Weka namba tena'),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12)
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('GHAIRI', style: TextStyle(color: AppColors.muted))),
        ElevatedButton(
            onPressed: () {
              final raw = ctrl.text.replaceAll(RegExp(r'\D'), '');
              final formatted = raw.startsWith('0') && raw.length == 10
                  ? '255${raw.substring(1)}'
                  : raw.length == 9
                      ? '255$raw'
                      : raw;
              final origRaw = phone.replaceAll(RegExp(r'\D'), '');
              final origFormatted = origRaw.startsWith('0') && origRaw.length == 10
                  ? '255${origRaw.substring(1)}'
                  : origRaw.length == 9
                      ? '255$origRaw'
                      : origRaw;
              if (formatted == origFormatted) {
                Navigator.pop(ctx, true);
              } else {
                _showSnack(ctx, 'Namba hazilingani', isError: true);
              }
            },
            child: const Text('THIBITISHA', style: TextStyle(color: Colors.black))),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> _showPackagesSheet(BuildContext context, Function(String) onSelect) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('CHAGUA KIFURUSHI',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 20),
            _pkgTile('NORMAL', 'Siku 1 (Masaa 24)', '3,000', AppColors.accent2, 'normal'),
            const SizedBox(height: 10),
            _pkgTile('TANZANITE', 'Siku 3 (Masaa 72)', '5,000', AppColors.tanzanite, 'tanzanite'),
            const SizedBox(height: 10),
            _pkgTile('VIP', 'Siku 7 (Wiki 1)', '10,000', AppColors.gold, 'vip'),
            const SizedBox(height: 10),
            _pkgTile('VVIP', 'Siku 30 (Mwezi 1)', '30,000', AppColors.red, 'vvip'),
          ],
        ),
      ),
    ),
  );
  if (selected != null) onSelect(selected);
}

Widget _pkgTile(String name, String duration, String price, Color color, String type) {
  return Builder(
    builder: (context) => InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.bg2, color.withOpacity(0.08)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(
                name == 'VVIP'
                    ? Icons.workspace_premium
                    : name == 'VIP'
                        ? Icons.star
                        : name == 'TANZANITE'
                            ? Icons.diamond
                            : Icons.calendar_today,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: color, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(duration,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
            Text('TSh $price',
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    ),
  );
}
