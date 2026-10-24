#!/usr/bin/env bash
# Builds AstraDial and wraps it in build/Astra Dial.app (menu bar only).
#
#   Scripts/bundle.sh            release build for this Mac's architecture
#   Scripts/bundle.sh --universal  arm64 + x86_64
#   SANDBOX=1 Scripts/bundle.sh    "Astra Dial Sandbox": App Sandbox on, its own bundle ID, to test
#                                  what works under Mac App Store rules
#   APPSTORE=1 Scripts/bundle.sh   the Mac App Store variant: built with -DAPP_STORE (no
#                                  Brightness, no update check), sandboxed. With
#                                  PROVISIONING_PROFILE=path it embeds the profile and signs with
#                                  Apple Distribution, ready for Scripts/appstore.sh to package;
#                                  without, it signs like a dev build so it can be run locally.
#
# Signing: uses a Developer ID Application identity if the keychain has one, else
# "Astra Dial Local Signing" if Scripts/create-signing-cert.sh has created it. macOS ties
# Input Monitoring and Accessibility to the signing identity, so signing dev builds like
# releases keeps permissions when switching between `make run` and an installed copy.
# Without either, falls back to ad-hoc, which makes macOS ask again after every rebuild.
# Override with SIGN_IDENTITY="…". SIGN_TIMESTAMP=1 adds the secure timestamp notarization
# needs (release.sh sets it); dev builds skip that network call.
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="Astra Dial"
BUNDLE_ID="${BUNDLE_ID:-com.astradial.AstraDial}"
ENTITLEMENTS=()
SWIFT_FLAGS=()
PROFILE="${PROVISIONING_PROFILE:-}"
if [[ "${SANDBOX:-}" == 1 ]]; then
  # A separate app, so its permissions and settings don't touch the regular build's.
  APP_NAME="Astra Dial Sandbox"
  BUNDLE_ID="$BUNDLE_ID.sandbox"
  ENTITLEMENTS=(--entitlements packaging/sandbox.entitlements)
elif [[ "${APPSTORE:-}" == 1 ]]; then
  # Its own scratch path, so switching variants doesn't rebuild everything.
  SWIFT_FLAGS=(-Xswiftc -DAPP_STORE --scratch-path .build/appstore)
  mkdir -p build
  cp packaging/appstore.entitlements build/appstore.entitlements
  if [[ -n "$PROFILE" ]]; then
    # A provisioning profile needs the app and team identifiers it was made for.
    TEAM_ID="$(security cms -D -i "$PROFILE" | plutil -extract TeamIdentifier.0 raw -)"
    plutil -insert com.apple.application-identifier -string "$TEAM_ID.$BUNDLE_ID" build/appstore.entitlements
    plutil -insert com.apple.developer.team-identifier -string "$TEAM_ID" build/appstore.entitlements
    if [[ -z "${SIGN_IDENTITY:-}" ]]; then
      SIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Distribution: [^"]*\)".*/\1/p' | head -1)"
      [[ -n "$SIGN_IDENTITY" ]] || { echo "error: no Apple Distribution certificate in the keychain" >&2; exit 1; }
    fi
  fi
  ENTITLEMENTS=(--entitlements build/appstore.entitlements)
fi
VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
LOCAL_IDENTITY="Astra Dial Local Signing"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  DEVELOPER_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
  if [[ -n "$DEVELOPER_ID" ]]; then
    SIGN_IDENTITY="$DEVELOPER_ID"
  elif security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
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

BUILD_FLAGS=(-c release --product AstraDial "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" "${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"}")
swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AstraDial" "$APP/Contents/MacOS/AstraDial"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
[[ -n "$PROFILE" ]] && cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

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
  <key>NSHumanReadableCopyright</key><string>Copyright © $(date +%Y) Astra Dial</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST

# Notarization needs a secure timestamp; dev builds skip the network call.
TIMESTAMP=(--timestamp=none)
[[ "${SIGN_TIMESTAMP:-}" == 1 ]] && TIMESTAMP=(--timestamp)
codesign --force --options runtime "${TIMESTAMP[@]}" "${ENTITLEMENTS[@]+"${ENTITLEMENTS[@]}"}" --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP (signed: $SIGN_IDENTITY)"
