#!/usr/bin/env bash
# Build Loki and wrap the binary in a proper Loki.app bundle.
#
# A bundle (with Info.plist + bundle identifier) gives Loki a stable TCC
# identity so macOS remembers the Automation / Accessibility permissions you
# grant, and LSUIElement keeps it out of the Dock.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Loki"
BUNDLE_ID="com.github.loki-prank"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Loki steuert Browser und Systemfunktionen für reversible Streiche.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Optional: damit du dem sprechenden Companion mündlich antworten kannst. Audio wird on-device verarbeitet.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Optional: erkennt deine gesprochenen Antworten lokal (on-device), damit der Companion reagieren kann.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so the bundle launches locally without a Developer ID.
echo "==> Ad-hoc signing"
codesign --force --deep --sign - "${APP_DIR}" || \
  echo "!! codesign fehlgeschlagen — App läuft evtl. nur via Rechtsklick > Öffnen"

echo "==> Fertig: ${APP_DIR}"
