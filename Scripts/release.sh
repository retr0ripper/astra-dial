#!/usr/bin/env bash
# Builds a release: universal Astra Dial.app, a DMG, and a Homebrew cask, in build/release/.
#
#   Scripts/release.sh
#
# Signing follows bundle.sh. For a build other Macs open without warnings, sign with a
# Developer ID and notarize:
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=astra-dial \
#   GITHUB_REPO=owner/astra-dial \
#   Scripts/release.sh
# Create the notary profile once with:
#   xcrun notarytool store-credentials astra-dial --apple-id you@example.com --team-id TEAMID
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
GITHUB_REPO="${GITHUB_REPO:-retr0ripper/astra-dial}"
OUT="build/release"
APP="build/Astra Dial.app"
DMG="$OUT/AstraDial-$VERSION.dmg"

# Prefer a Developer ID identity for releases when one is installed; bundle.sh otherwise
# falls back to the local certificate.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  DEVELOPER_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
  [[ -n "$DEVELOPER_ID" ]] && export SIGN_IDENTITY="$DEVELOPER_ID"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "warning: the working tree has uncommitted changes; the build won't match a commit." >&2
fi

VERSION="$VERSION" SIGN_IDENTITY="${SIGN_IDENTITY:-}" Scripts/bundle.sh --universal
ARCHS="$(lipo -archs "$APP/Contents/MacOS/AstraDial")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "error: expected a universal binary, got: $ARCHS" >&2; exit 1; }
codesign --verify --deep --strict "$APP"
SIGNED_WITH="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
SIGNED_WITH="${SIGNED_WITH:-ad-hoc}"

rm -rf "$OUT"
mkdir -p "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -quiet -volname "Astra Dial $VERSION" -srcfolder "$OUT/dmg" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$OUT/dmg"

NOTARIZED=no
if [[ "$SIGNED_WITH" == "Developer ID Application:"* ]]; then
  codesign --force --timestamp --sign "$SIGNED_WITH" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    NOTARIZED=yes
  else
    echo "note: NOTARY_PROFILE not set; skipping notarization." >&2
  fi
fi

SHA256="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
sed -e "s|@VERSION@|$VERSION|g" -e "s|@SHA256@|$SHA256|g" -e "s|@GITHUB_REPO@|$GITHUB_REPO|g" \
  packaging/astra-dial.rb.template > "$OUT/astra-dial.rb"

cat <<SUMMARY

Astra Dial $VERSION
  App        $APP ($ARCHS)
  Signed     $SIGNED_WITH
  Notarized  $NOTARIZED
  DMG        $DMG
  SHA-256    $SHA256
  Cask       $OUT/astra-dial.rb (download URL: github.com/$GITHUB_REPO/releases)
SUMMARY

if [[ "$NOTARIZED" == no ]]; then
  cat <<'NOTE'

This DMG isn't notarized, so on other Macs Gatekeeper blocks the app on first open.
They can open it with right-click → Open, or run:
  xattr -dr com.apple.quarantine "/Applications/Astra Dial.app"
NOTE
fi
