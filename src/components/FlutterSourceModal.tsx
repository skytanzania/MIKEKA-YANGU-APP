import React, { useState } from 'react';
import { X, Copy, Check, Download, FileCode, PackageCheck, Terminal } from 'lucide-react';
import { useApp } from '../context/AppContext';

interface Props {
  onClose: () => void;
}

export const FlutterSourceModal: React.FC<Props> = ({ onClose }) => {
  const { showSnack } = useApp();
  const [activeTab, setActiveTab] = useState<'dart' | 'pubspec' | 'setup'>('dart');
  const [copied, setCopied] = useState(false);

  // Exact Dart source code from the user
  const dartCode = `// ============================================================
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const MikekaApp());
}

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
        deviceModel = '\${info.manufacturer} \${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor;
        deviceModel = info.name;
      }
    } catch (_) {}
  }
}

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

// ... See /lib/main.dart in this repository for the full 1,000+ line code ...`;

  const pubspecCode = `name: mikeka_app
description: "Mikeka App - Mobile sports betting tips app for Tanzania"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_secure_storage: ^9.2.2
  http: ^1.2.2
  shared_preferences: ^2.3.2
  url_launcher: ^6.3.0
  device_info_plus: ^10.1.2
  flutter_local_notifications: ^17.2.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true`;

  const handleCopy = () => {
    const text = activeTab === 'dart' ? dartCode : pubspecCode;
    navigator.clipboard.writeText(text);
    setCopied(true);
    showSnack('Imenakiliwa!');
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadDart = async () => {
    try {
      const response = await fetch('/lib/main.dart');
      const text = await response.text();
      const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'main.dart';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showSnack('main.dart imepakuliwa!');
    } catch (_) {
      showSnack('Pakua kupitia filesystem: /lib/main.dart');
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
      <div className="w-full max-w-2xl rounded-2xl bg-[#111122] border border-white/15 p-5 shadow-2xl flex flex-col max-h-[85vh] animate-scale-up">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-white/10">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-[#00FFC8]/15 text-[#00FFC8]">
              <FileCode className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-sm font-black text-white uppercase tracking-wider">
                Flutter Single-File App
              </h3>
              <span className="text-[10px] text-[#00FFC8] font-mono">
                lib/main.dart & pubspec.yaml
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleDownloadDart}
              className="px-3 py-1.5 rounded-lg bg-[#00FFC8] hover:bg-[#00e6b4] text-black font-black text-xs flex items-center gap-1.5 shadow"
              title="Download main.dart"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Pakua main.dart</span>
            </button>
            <button
              onClick={handleCopy}
              className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-[#00FFC8] border border-white/10"
              title="Copy"
            >
              {copied ? <Check className="w-4 h-4 text-[#00C853]" /> : <Copy className="w-4 h-4" />}
            </button>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-[#8899AA] hover:text-white hover:bg-white/5"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex items-center gap-2 pt-3 pb-2 border-b border-white/5">
          <button
            onClick={() => setActiveTab('dart')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeTab === 'dart'
                ? 'bg-[#00FFC8]/15 text-[#00FFC8] border border-[#00FFC8]/40'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <FileCode className="w-3.5 h-3.5" />
            <span>lib/main.dart</span>
          </button>

          <button
            onClick={() => setActiveTab('pubspec')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeTab === 'pubspec'
                ? 'bg-[#00FFC8]/15 text-[#00FFC8] border border-[#00FFC8]/40'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <PackageCheck className="w-3.5 h-3.5" />
            <span>pubspec.yaml</span>
          </button>

          <button
            onClick={() => setActiveTab('setup')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeTab === 'setup'
                ? 'bg-[#00FFC8]/15 text-[#00FFC8] border border-[#00FFC8]/40'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <Terminal className="w-3.5 h-3.5" />
            <span>Maelekezo (Setup)</span>
          </button>
        </div>

        {/* Code Content */}
        <div className="flex-1 overflow-y-auto mt-3 rounded-xl bg-[#0A0A1A] border border-white/5 p-3.5 font-mono text-xs text-white/80 leading-relaxed">
          {activeTab === 'dart' && (
            <pre className="whitespace-pre-wrap select-all text-[#00FFC8]/90 font-mono text-[11px]">
              {dartCode}
            </pre>
          )}

          {activeTab === 'pubspec' && (
            <pre className="whitespace-pre-wrap select-all text-[#FFD700]/90 font-mono text-[11px]">
              {pubspecCode}
            </pre>
          )}

          {activeTab === 'setup' && (
            <div className="space-y-3 font-sans text-xs text-white/80">
              <h4 className="font-bold text-[#00FFC8] text-sm">
                Jinsi ya kutumia faili hii kwenye Flutter:
              </h4>
              <ol className="list-decimal pl-5 space-y-2">
                <li>
                  Tengeneza mradi mpya wa Flutter kwa amri:{' '}
                  <code className="text-[#00FFC8] bg-black/50 px-1 py-0.5 rounded font-mono">
                    flutter create mikeka_app
                  </code>
                </li>
                <li>
                  Weka faili la <code className="text-[#00FFC8] font-mono">pubspec.yaml</code> lililopo kwenye mradi huu.
                </li>
                <li>
                  Weka faili la <code className="text-[#00FFC8] font-mono">lib/main.dart</code> lililotolewa kwenye folda la <code className="text-[#00FFC8] font-mono">lib/</code>.
                </li>
                <li>
                  Pakua package zote kwa kuendesha:{' '}
                  <code className="text-[#00FFC8] bg-black/50 px-1 py-0.5 rounded font-mono">
                    flutter pub get
                  </code>
                </li>
                <li>
                  Anzisha application kwa Android au iOS au Web:{' '}
                  <code className="text-[#00FFC8] bg-black/50 px-1 py-0.5 rounded font-mono">
                    flutter run
                  </code>
                </li>
              </ol>
              <div className="mt-4 p-3 rounded-lg bg-[#00FFC8]/10 border border-[#00FFC8]/25 text-[#00FFC8]">
                ✓ Faili hili ni kamilifu 100% (Single file complete architecture) likiwa na:
                REST API client, theme, local notifications, secure storage, session health check, win celebrations, USSD payments polling, na UI zote 4 za tabs!
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
