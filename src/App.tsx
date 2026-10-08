/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { AppProvider, useApp } from './context/AppContext';
import { SplashScreen } from './components/SplashScreen';
import { DeviceFrame } from './components/DeviceFrame';
import { TipstersTab } from './components/TipstersTab';
import { MikekaTab } from './components/MikekaTab';
import { SingleSlipsTab } from './components/SingleSlipsTab';
import { ProfileTab } from './components/ProfileTab';

// Modals
import { LoginModal } from './components/LoginModal';
import { PayPackageModal } from './components/PayPackageModal';
import { BuySingleSlipModal } from './components/BuySingleSlipModal';
import { WinPopupModal } from './components/WinPopupModal';
import { WarningPopupModal } from './components/WarningPopupModal';
import { FlutterSourceModal } from './components/FlutterSourceModal';
import { GenerateApkModal } from './components/GenerateApkModal';

// Icons
import {
  Users,
  Ticket,
  Target,
  User as UserIcon,
  Smartphone,
  Maximize2,
  FileCode,
  Trophy,
  AlertTriangle,
  Globe,
  CheckCircle2,
  AlertCircle,
  Zap,
} from 'lucide-react';

const MainAppContent: React.FC = () => {
  const {
    snack,
    sessionInvalidReason,
    isSessionBanned,
    showWinPopupManually,
    showWarningPopupManually,
    logout,
  } = useApp();

  const [bootstrapping, setBootstrapping] = useState(true);
  const [activeTab, setActiveTab] = useState<number>(0);
  const [isFramed, setIsFramed] = useState<boolean>(true);
  const [isFlutterSourceOpen, setIsFlutterSourceOpen] = useState<boolean>(false);
  const [isGenerateApkOpen, setIsGenerateApkOpen] = useState<boolean>(false);

  // Splash screen bootstrap (mimics Flutter 800ms bootstrap)
  useEffect(() => {
    const timer = setTimeout(() => {
      setBootstrapping(false);
    }, 1000);
    return () => clearTimeout(timer);
  }, []);

  if (bootstrapping) {
    return <SplashScreen />;
  }

  return (
    <div className="relative min-h-screen bg-[#000010] text-[#E8EAF0] flex flex-col">
      {/* Top Developer Bar (Interactive Tools for Flutter App & Simulation) */}
      <header className="z-30 bg-[#0A0A1A]/90 backdrop-blur border-b border-white/10 px-3 py-2 flex flex-wrap items-center justify-between gap-2 text-xs">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-[#00FFC8] animate-ping" />
          <div className="flex items-center gap-1.5 font-black text-[#00FFC8] tracking-wider uppercase text-xs">
            <Globe className="w-3.5 h-3.5" />
            <span>MIKEKA APP (FLUTTER ENGINE)</span>
          </div>
          <span className="hidden sm:inline-block px-2 py-0.5 rounded-full bg-white/5 border border-white/10 text-[10px] text-white/70">
            API: Live (mikekaapp.co.tz)
          </span>
        </div>

        <div className="flex items-center gap-1.5 sm:gap-2">
          {/* Generate APK Button */}
          <button
            onClick={() => setIsGenerateApkOpen(true)}
            className="px-2.5 py-1 rounded-lg bg-gradient-to-r from-[#00FFC8] to-[#00B4FF] hover:brightness-110 text-black font-black text-[11px] flex items-center gap-1 transition-all shadow-[0_0_15px_rgba(0,255,200,0.3)] active:scale-95"
            title="Tengeneza APK / Sakinisha App kwenye Simu"
          >
            <Zap className="w-3.5 h-3.5 fill-black" />
            <span>GENERATE APK</span>
          </button>

          {/* View Flutter Source Code Button */}
          <button
            onClick={() => setIsFlutterSourceOpen(true)}
            className="px-2.5 py-1 rounded-lg bg-[#00FFC8]/15 hover:bg-[#00FFC8]/25 text-[#00FFC8] border border-[#00FFC8]/40 font-bold text-[11px] flex items-center gap-1 transition-all"
            title="View Flutter single-file main.dart code & pubspec.yaml"
          >
            <FileCode className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Flutter Code</span>
          </button>

          {/* Test Win Popup Button */}
          <button
            onClick={() => showWinPopupManually()}
            className="px-2 py-1 rounded-lg bg-[#FFD700]/15 hover:bg-[#FFD700]/25 text-[#FFD700] border border-[#FFD700]/30 font-bold text-[11px] flex items-center gap-1 transition-all"
            title="Jaribu onyesho la ushindi (Win Popup)"
          >
            <Trophy className="w-3.5 h-3.5" />
            <span className="hidden md:inline">Test Win</span>
          </button>

          {/* Test Warning Button */}
          <button
            onClick={() => showWarningPopupManually()}
            className="px-2 py-1 rounded-lg bg-[#FF6B00]/15 hover:bg-[#FF6B00]/25 text-[#FF6B00] border border-[#FF6B00]/30 font-bold text-[11px] flex items-center gap-1 transition-all"
            title="Jaribu tahadhari (Warning Dialog)"
          >
            <AlertTriangle className="w-3.5 h-3.5" />
            <span className="hidden md:inline">Test Alert</span>
          </button>

          {/* Toggle Phone Frame vs Full Responsive */}
          <button
            onClick={() => setIsFramed(!isFramed)}
            className="px-2 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-white/80 border border-white/10 font-bold text-[11px] flex items-center gap-1 transition-all"
            title={isFramed ? 'Badili kuwa Full Screen' : 'Badili kuwa Mobile Frame'}
          >
            {isFramed ? (
              <>
                <Maximize2 className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Full Screen</span>
              </>
            ) : (
              <>
                <Smartphone className="w-3.5 h-3.5 text-[#00FFC8]" />
                <span className="hidden sm:inline">Phone Frame</span>
              </>
            )}
          </button>
        </div>
      </header>

      {/* Main Container with Mobile Frame */}
      <main className="flex-1 flex flex-col justify-center">
        <DeviceFrame isFramed={isFramed}>
          <div className="relative min-h-full flex flex-col justify-between">
            {/* Screen Content based on Active Tab */}
            <div className="flex-1">
              {activeTab === 0 && <TipstersTab />}
              {activeTab === 1 && <MikekaTab />}
              {activeTab === 2 && <SingleSlipsTab />}
              {activeTab === 3 && <ProfileTab />}
            </div>

            {/* Bottom Navigation Bar (Faithful replica of Flutter BottomNavigationBar) */}
            <nav className="sticky bottom-0 z-30 w-full bg-[#0A0A19]/95 backdrop-blur border-t border-white/10 px-2 pt-2 pb-2.5 flex items-center justify-around select-none">
              <button
                onClick={() => setActiveTab(0)}
                className="flex-1 flex flex-col items-center justify-center gap-0.5 py-1 transition-transform active:scale-95"
              >
                <Users
                  className={`w-5 h-5 transition-colors ${
                    activeTab === 0 ? 'text-[#00FFC8]' : 'text-[#8899AA]'
                  }`}
                  strokeWidth={activeTab === 0 ? 2.5 : 2}
                />
                <span
                  className={`text-[10px] font-semibold transition-colors ${
                    activeTab === 0 ? 'text-[#00FFC8] font-bold' : 'text-[#8899AA]'
                  }`}
                >
                  Tipsters
                </span>
              </button>

              <button
                onClick={() => setActiveTab(1)}
                className="flex-1 flex flex-col items-center justify-center gap-0.5 py-1 transition-transform active:scale-95"
              >
                <Ticket
                  className={`w-5 h-5 transition-colors ${
                    activeTab === 1 ? 'text-[#00FFC8]' : 'text-[#8899AA]'
                  }`}
                  strokeWidth={activeTab === 1 ? 2.5 : 2}
                />
                <span
                  className={`text-[10px] font-semibold transition-colors ${
                    activeTab === 1 ? 'text-[#00FFC8] font-bold' : 'text-[#8899AA]'
                  }`}
                >
                  Mikeka
                </span>
              </button>

              <button
                onClick={() => setActiveTab(2)}
                className="flex-1 flex flex-col items-center justify-center gap-0.5 py-1 transition-transform active:scale-95"
              >
                <Target
                  className={`w-5 h-5 transition-colors ${
                    activeTab === 2 ? 'text-[#00FFC8]' : 'text-[#8899AA]'
                  }`}
                  strokeWidth={activeTab === 2 ? 2.5 : 2}
                />
                <span
                  className={`text-[10px] font-semibold transition-colors ${
                    activeTab === 2 ? 'text-[#00FFC8] font-bold' : 'text-[#8899AA]'
                  }`}
                >
                  Single
                </span>
              </button>

              <button
                onClick={() => setActiveTab(3)}
                className="flex-1 flex flex-col items-center justify-center gap-0.5 py-1 transition-transform active:scale-95"
              >
                <UserIcon
                  className={`w-5 h-5 transition-colors ${
                    activeTab === 3 ? 'text-[#00FFC8]' : 'text-[#8899AA]'
                  }`}
                  strokeWidth={activeTab === 3 ? 2.5 : 2}
                />
                <span
                  className={`text-[10px] font-semibold transition-colors ${
                    activeTab === 3 ? 'text-[#00FFC8] font-bold' : 'text-[#8899AA]'
                  }`}
                >
                  Profile
                </span>
              </button>
            </nav>
          </div>
        </DeviceFrame>
      </main>

      {/* Floating SnackBar Toast (Flutter SnackBarBehavior.floating replica) */}
      {snack && (
        <div className="fixed bottom-16 sm:bottom-6 left-1/2 -translate-x-1/2 z-50 px-4 py-2.5 rounded-xl bg-[#1A1A2E] border border-white/20 text-white text-xs font-bold shadow-2xl flex items-center gap-2 animate-slide-up max-w-sm w-full mx-4">
          {snack.isError ? (
            <AlertCircle className="w-4 h-4 text-[#FF0055] shrink-0" />
          ) : (
            <CheckCircle2 className="w-4 h-4 text-[#00C853] shrink-0" />
          )}
          <span className="flex-1 leading-snug">{snack.message}</span>
        </div>
      )}

      {/* Session Invalid Modal (Banned or Kicked) */}
      {sessionInvalidReason && (
        <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-[#111122] border-2 border-[#FF0055] p-5 shadow-2xl text-center">
            <h3
              className={`text-sm font-black uppercase tracking-wider ${
                isSessionBanned ? 'text-[#FF0055]' : 'text-[#FF6B00]'
              }`}
            >
              {isSessionBanned ? 'AKAUNTI IMEFUNGWA' : 'UMESAJILIWA NJE'}
            </h3>
            <p className="mt-2 text-xs text-white/80 leading-relaxed">
              {sessionInvalidReason}
            </p>
            <button
              onClick={() => {
                logout();
                window.location.reload();
              }}
              className="mt-4 w-full py-2.5 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider"
            >
              SAWA
            </button>
          </div>
        </div>
      )}

      {/* Modals & Dialogs */}
      <LoginModal />
      <PayPackageModal />
      <BuySingleSlipModal />
      <WinPopupModal />
      <WarningPopupModal />
      {isFlutterSourceOpen && (
        <FlutterSourceModal onClose={() => setIsFlutterSourceOpen(false)} />
      )}
      {isGenerateApkOpen && (
        <GenerateApkModal onClose={() => setIsGenerateApkOpen(false)} />
      )}
    </div>
  );
};

export default function App() {
  return (
    <AppProvider>
      <MainAppContent />
    </AppProvider>
  );
}
