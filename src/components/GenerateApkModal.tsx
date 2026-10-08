import React, { useState } from 'react';
import {
  X,
  Smartphone,
  Download,
  Copy,
  Check,
  Terminal,
  Github,
  Zap,
  CheckCircle2,
  Share2,
  FileCode,
  Sparkles,
} from 'lucide-react';
import { usePWAInstall } from '../hooks/usePWAInstall';
import { useApp } from '../context/AppContext';

interface Props {
  onClose: () => void;
}

export const GenerateApkModal: React.FC<Props> = ({ onClose }) => {
  const { isInstallable, isInstalled, isIOS, install } = usePWAInstall();
  const { showSnack } = useApp();
  const [activeTab, setActiveTab] = useState<'direct' | 'github' | 'cli'>('direct');
  const [copiedCmd, setCopiedCmd] = useState(false);

  const cliCommands = `# 1. Hakiki Flutter SDK
flutter --version

# 2. Pakua packages zote
flutter pub get

# 3. Tengeneza APK ya Release (Universal APK inayofanya kazi kwenye simu zote)
flutter build apk --release

# APK itapatikana kwenye:
# build/app/outputs/flutter-apk/app-release.apk`;

  const handleCopyCmd = () => {
    navigator.clipboard.writeText(cliCommands);
    setCopiedCmd(true);
    showSnack('Amri za CLI zimenakiliwa!');
    setTimeout(() => setCopiedCmd(false), 2000);
  };

  const handleDownloadMainDart = async () => {
    try {
      const res = await fetch('/lib/main.dart');
      const text = await res.text();
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
      showSnack('Pakua kupitia faili: /lib/main.dart');
    }
  };

  const handleDownloadBuildScript = () => {
    const script = `#!/usr/bin/env bash
flutter pub get
flutter build apk --release
echo "APK iko tayari: build/app/outputs/flutter-apk/app-release.apk"`;
    const blob = new Blob([script], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'build_apk.sh';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showSnack('build_apk.sh imepakuliwa!');
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-3 sm:p-4 overflow-y-auto">
      <div className="w-full max-w-xl rounded-3xl bg-[#111122] border-2 border-[#00FFC8]/30 p-5 sm:p-6 shadow-[0_0_50px_rgba(0,255,200,0.15)] flex flex-col my-auto animate-scale-up">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-[#00FFC8] to-[#00B4FF] flex items-center justify-center text-black shadow-lg">
              <Smartphone className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-black text-white uppercase tracking-wider">
                  GENERATE ANDROID APK
                </h3>
                <span className="px-2 py-0.5 rounded-full text-[9px] font-black uppercase bg-[#00FFC8]/15 text-[#00FFC8] border border-[#00FFC8]/30">
                  Ready
                </span>
              </div>
              <p className="text-xs text-[#8899AA]">
                Mikeka App — Chaguo 3 za kusakinisha au kutengeneza APK
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-xl text-[#8899AA] hover:text-white hover:bg-white/5 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="grid grid-cols-3 gap-1.5 p-1 rounded-xl bg-[#0A0A1A] border border-white/5 mt-4">
          <button
            onClick={() => setActiveTab('direct')}
            className={`py-2 px-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5 ${
              activeTab === 'direct'
                ? 'bg-[#00FFC8] text-black shadow-md font-black'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <Zap className="w-3.5 h-3.5" />
            <span>Sakinisha Simuni</span>
          </button>

          <button
            onClick={() => setActiveTab('github')}
            className={`py-2 px-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5 ${
              activeTab === 'github'
                ? 'bg-[#00FFC8] text-black shadow-md font-black'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <Github className="w-3.5 h-3.5" />
            <span>Cloud Build (Auto)</span>
          </button>

          <button
            onClick={() => setActiveTab('cli')}
            className={`py-2 px-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5 ${
              activeTab === 'cli'
                ? 'bg-[#00FFC8] text-black shadow-md font-black'
                : 'text-[#8899AA] hover:text-white'
            }`}
          >
            <Terminal className="w-3.5 h-3.5" />
            <span>Local Flutter CLI</span>
          </button>
        </div>

        {/* Tab 1: Direct Phone Install (WebAPK / Standalone App) */}
        {activeTab === 'direct' && (
          <div className="mt-4 space-y-3">
            <div className="p-4 rounded-2xl bg-gradient-to-br from-[#00FFC8]/10 to-[#00B4FF]/10 border border-[#00FFC8]/25">
              <div className="flex items-center gap-2 text-[#00FFC8] font-black text-xs uppercase tracking-wider mb-1">
                <Sparkles className="w-4 h-4" />
                <span>Njia Rahisi Zaidi (Bila Kompyuta)</span>
              </div>
              <h4 className="text-sm font-black text-white">
                Sakinisha Moja kwa Moja kwenye Simu Yako
              </h4>
              <p className="mt-1 text-xs text-white/70 leading-relaxed">
                App itasakinishwa kama App halisi ya Android ikiwa na icon ya Mikeka App kwenye Menu ya simu,
                skrini nzima bila viunga vya browser, na inafunguka moja kwa moja!
              </p>

              <div className="mt-4">
                {isInstalled ? (
                  <div className="p-3 rounded-xl bg-[#00C853]/15 border border-[#00C853]/35 text-[#00C853] text-xs font-bold flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>App hii imesakinishwa tayari kwenye kifaa hiki!</span>
                  </div>
                ) : isInstallable ? (
                  <button
                    onClick={async () => {
                      const success = await install();
                      if (success) showSnack('App inasakinishwa kwenye simu yako!');
                    }}
                    className="w-full py-3 px-4 rounded-xl bg-[#00FFC8] hover:bg-[#00e6b4] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg active:scale-95 transition-all"
                  >
                    <Download className="w-4 h-4" />
                    <span>SAKINISHA SASA KWENYE SIMU</span>
                  </button>
                ) : isIOS ? (
                  <div className="p-3 rounded-xl bg-[#111122] border border-white/10 text-xs text-white/80 space-y-1.5">
                    <div className="flex items-center gap-1.5 text-[#00FFC8] font-bold">
                      <Share2 className="w-4 h-4" />
                      <span>Kwenye iPhone / iPad:</span>
                    </div>
                    <p className="text-[11px] text-[#8899AA]">
                      1. Gonga kitufe cha <strong>Share</strong> (Kushiriki) chini ya Safari.<br />
                      2. Tembeza chini kisha gonga <strong>Add to Home Screen</strong>.
                    </p>
                  </div>
                ) : (
                  <button
                    onClick={async () => {
                      showSnack('Fungua kwenye Chrome kwenye simu yako ya Android kisha gonga Sakinisha!');
                    }}
                    className="w-full py-3 px-4 rounded-xl bg-[#00FFC8] hover:bg-[#00e6b4] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg active:scale-95 transition-all"
                  >
                    <Smartphone className="w-4 h-4" />
                    <span>FUNGUA KWENYE SIMU KUSAKINISHA</span>
                  </button>
                )}
              </div>
            </div>

            <div className="p-3 rounded-xl bg-[#0A0A1A] border border-white/5 text-[11px] text-[#8899AA] space-y-1">
              <span className="font-bold text-white block">Sifa Kuu:</span>
              <p>✓ Inatumia icons rasmi za 192x192 & 512x512</p>
              <p>✓ Inafanya kazi ikiwa na data na nje ya mtandao (Offline Cache)</p>
              <p>✓ Inapokea updates kiotomatiki bila kupakua upya</p>
            </div>
          </div>
        )}

        {/* Tab 2: GitHub Actions Free APK Builder */}
        {activeTab === 'github' && (
          <div className="mt-4 space-y-3">
            <div className="p-4 rounded-2xl bg-[#0A0A1A] border border-white/10 space-y-2">
              <div className="flex items-center gap-2 text-[#00B4FF] font-black text-xs uppercase">
                <Github className="w-4 h-4" />
                <span>GitHub Actions (Bure & Moja kwa Moja)</span>
              </div>
              <h4 className="text-sm font-black text-white">
                Kujenga app-release.apk kiotomatiki mtandaoni
              </h4>
              <p className="text-xs text-white/70 leading-relaxed">
                Mradi huu tayari una faili la{' '}
                <code className="text-[#00FFC8] font-mono">.github/workflows/build-apk.yml</code>.
                Ukiweka msimbo huu kwenye GitHub:
              </p>

              <ol className="list-decimal pl-5 space-y-1.5 text-xs text-[#8899AA]">
                <li>Weka repository yako kwenye GitHub (Public au Private).</li>
                <li>Nenda kwenye tab ya <strong>Actions</strong>.</li>
                <li>Chagua <strong>Build Mikeka Flutter APK</strong> kisha gonga <strong>Run workflow</strong>.</li>
                <li>Ndani ya dakika 2, utapata faili la <strong className="text-[#00FFC8]">app-release.apk</strong> lililo tayari kupakuliwa!</li>
              </ol>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={handleDownloadMainDart}
                className="flex-1 py-2.5 px-3 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-bold text-white flex items-center justify-center gap-1.5 transition-all"
              >
                <FileCode className="w-3.5 h-3.5 text-[#00FFC8]" />
                <span>Pakua main.dart</span>
              </button>
              <button
                onClick={() => {
                  const yml = `name: Build Mikeka Flutter APK

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    name: Build Android APK
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Set up Java JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'

      - name: Set up Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Generate Compatible Android Gradle Scaffold
        run: flutter create . --platforms android --org com.mikekaapp.tz

      - name: Get Flutter Packages
        run: flutter pub get

      - name: Build Release APK
        run: flutter build apk --release --no-tree-shake-icons

      - name: Upload Release APK Artifact
        uses: actions/upload-artifact@v4
        with:
          name: mikeka-app-release-apk
          path: build/app/outputs/flutter-apk/*.apk
          retention-days: 30`;
                  navigator.clipboard.writeText(yml);
                  showSnack('Faili la build-apk.yml limenakiliwa!');
                }}
                className="flex-1 py-2.5 px-3 rounded-xl bg-[#00FFC8]/15 hover:bg-[#00FFC8]/25 border border-[#00FFC8]/40 text-xs font-black text-[#00FFC8] flex items-center justify-center gap-1.5 transition-all"
              >
                <Copy className="w-3.5 h-3.5" />
                <span>Nakili build-apk.yml</span>
              </button>
            </div>
          </div>
        )}

        {/* Tab 3: Local CLI Command */}
        {activeTab === 'cli' && (
          <div className="mt-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-white uppercase tracking-wider">
                Amri za Flutter CLI kwenye Terminal Yako
              </span>
              <button
                onClick={handleCopyCmd}
                className="px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-[11px] font-bold text-[#00FFC8] flex items-center gap-1"
              >
                {copiedCmd ? <Check className="w-3 h-3 text-[#00C853]" /> : <Copy className="w-3 h-3" />}
                <span>{copiedCmd ? 'Imenakiliwa!' : 'Copy Commands'}</span>
              </button>
            </div>

            <div className="p-3.5 rounded-xl bg-[#0A0A1A] border border-white/5 font-mono text-[11px] text-[#00FFC8] leading-relaxed overflow-x-auto select-all">
              <pre>{cliCommands}</pre>
            </div>

            <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5 text-[11px] text-[#8899AA]">
              💡 Folda zote za <code className="text-[#00FFC8] font-mono">android/</code> (ikiwa na <code className="text-white font-mono">build.gradle</code> na <code className="text-white font-mono">AndroidManifest.xml</code> yenye ruhusa za mtandao) zimeundwa tayari kwenye mradi huu.
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
