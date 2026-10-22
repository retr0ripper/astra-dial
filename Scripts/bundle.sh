#!/usr/bin/env bash
# Builds AstraDial and wraps it in build/Astra Dial.app (menu bar only, ad-hoc signed).
#
#   Scripts/bundle.sh            release build for this Mac's architecture
#   Scripts/bundle.sh --universal  arm64 + x86_64
#
# Signing: uses "Astra Dial Local Signing" if Scripts/create-signing-cert.sh has created it,
# so macOS keeps Input Monitoring and Accessibility across rebuilds. Otherwise falls back to
# ad-hoc, which makes macOS ask again after every rebuild. Override with
#   SIGN_IDENTITY="Developer ID Application: …" Scripts/bundle.sh
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="Astra Dial"
BUNDLE_ID="${BUNDLE_ID:-com.astradial.AstraDial}"
VERSION="${VERSION:-0.1.0}"
LOCAL_IDENTITY="Astra Dial Local Signing"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  if security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
    SIGN_IDENTITY="$LOCAL_IDENTITY"
  else
    SIGN_IDENTITY="-"
    echo "warning: ad-hoc signing; macOS will re-ask for permissions after each rebuild." >&2
    echo "         Run Scripts/create-signing-cert.sh once to fix that." >&2
  fi
fi

ARCH_FLAGS=()
if [[ "${1:-}" == "--universal" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release --product AstraDial "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}"
BIN_DIR="$(swift build -c release --product AstraDial "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" --show-bin-path)"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AstraDial" "$APP/Contents/MacOS/AstraDial"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>AstraDial</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --options runtime --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP (signed: $SIGN_IDENTITY)"
