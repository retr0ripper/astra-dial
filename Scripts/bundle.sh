#!/usr/bin/env bash
# Builds AstraDial and wraps it in build/Astra Dial.app (menu bar only).
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
VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
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
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

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
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>Astra Dial is not affiliated with Cosmic Byte.</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Developer ID builds need a secure timestamp for notarization; local builds skip the network call.
TIMESTAMP=(--timestamp=none)
[[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]] && TIMESTAMP=(--timestamp)
codesign --force --options runtime "${TIMESTAMP[@]}" --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP (signed: $SIGN_IDENTITY)"
