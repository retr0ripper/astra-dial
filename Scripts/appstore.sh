#!/usr/bin/env bash
# Builds the Mac App Store package: build/appstore/AstraDial-<version>.pkg, ready to upload
# with Transporter (or `xcrun altool --upload-app`).
#
#   PROVISIONING_PROFILE=~/Downloads/Astra_Dial_Mac_App_Store.provisionprofile Scripts/appstore.sh
#
# Needs, in the login keychain, an "Apple Distribution" certificate (signs the app) and a
# "3rd Party Mac Developer Installer" / "Mac Installer Distribution" certificate (signs the
# package), and a Mac App Store provisioning profile for com.astradial.AstraDial.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
APP="build/Astra Dial.app"
OUT="build/appstore"
PKG="$OUT/AstraDial-$VERSION.pkg"

[[ -n "${PROVISIONING_PROFILE:-}" && -f "$PROVISIONING_PROFILE" ]] || {
  echo "error: set PROVISIONING_PROFILE to the Mac App Store provisioning profile" >&2; exit 1; }
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v | sed -n 's/.*"\(\(3rd Party Mac Developer Installer\|Mac Installer Distribution\): [^"]*\)".*/\1/p' | head -1)}"
[[ -n "$INSTALLER_IDENTITY" ]] || { echo "error: no Mac Installer Distribution certificate in the keychain" >&2; exit 1; }

APPSTORE=1 PROVISIONING_PROFILE="$PROVISIONING_PROFILE" Scripts/bundle.sh --universal

# App Review rejects private API use; the App Store build must not link IOAVService (DDC/CI).
if nm -u "$APP/Contents/MacOS/AstraDial" | grep -q IOAVService; then
  echo "error: the App Store build links IOAVService, a private API" >&2; exit 1
fi
codesign --verify --strict "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q com.apple.security.app-sandbox || {
  echo "error: the app isn't sandboxed" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

cat <<SUMMARY

Astra Dial $VERSION for the Mac App Store
  App        $APP ($(lipo -archs "$APP/Contents/MacOS/AstraDial"))
  Signed     $(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
  Package    $PKG (signed: $INSTALLER_IDENTITY)

Upload it with Transporter, or:
  xcrun altool --upload-app --type macos --file "$PKG" --username <apple id> --password <app-specific password>
SUMMARY
