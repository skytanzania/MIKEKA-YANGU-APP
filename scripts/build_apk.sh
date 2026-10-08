#!/usr/bin/env bash
# ============================================================
# MIKEKA APP — LOCAL & CI APK BUILD SCRIPT
# ============================================================
set -e

echo "🚀 Anzisha mchakato wa kutengeneza APK ya Mikeka App..."

# Hakiki Flutter SDK
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter haipatikani kwenye mfumo wako. Sakinisha Flutter kutoka https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "📦 Inapakua packages za Flutter..."
flutter pub get

echo "🔨 Inajenga APK ya Release (Android)..."
flutter build apk --release

echo ""
echo "✅ HONGERA! APK imetengenezwa kwa mafanikio!"
echo "📁 Mahali ilipohifadhiwa:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📲 Unaweza kutuma faili hili kwenye simu yako ya Android na kulisakinisha moja kwa moja!"
