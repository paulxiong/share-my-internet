#!/usr/bin/env bash
# release_macos.sh — Share My Internet macOS release pipeline
#
# Builds a universal (arm64 + x86_64) release binary, assembles the .app,
# signs it with the Developer ID Application identity (hardened runtime),
# packages a DMG, signs the DMG, notarizes it, and staples the ticket.
#
# This app needs unsandboxed shell access to run the `tailscale` CLI, so it
# cannot go through the Mac App Store — Developer ID + notarization is the
# only (and correct) distribution path. No App Store Connect registration
# is needed; just the existing certificate + account credentials.
#
# Usage:
#   bash scripts/release_macos.sh              # build, sign, DMG, notarize, staple
#   bash scripts/release_macos.sh --no-notarize # build, sign, DMG only (skip notarization)
#
# Credentials — reused directly from the tiktok_clone project (same Apple ID
# and Team ID), no need to duplicate secrets into a second file:
#   ~/github/tiktok_clone/scripts/release.env.local
#     APPLE_ID, TEAM_ID, APP_PASSWORD, (optional) KEYCHAIN_PASSWORD
#
# Requirements:
#   - "Developer ID Application" certificate in the login Keychain
#   - Swift toolchain (swift build) with Xcode installed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Share My Internet"
BUNDLE_ID="comboostcode.sharemyinternet"
BUILD_DIR="$REPO_ROOT/.build/apple/Products/Release"
STAGING_APP="$REPO_ROOT/.release/$APP_NAME.app"
DMG="$REPO_ROOT/.release/$APP_NAME.dmg"

NOTARIZE=true
for arg in "$@"; do
  case "$arg" in
    --no-notarize) NOTARIZE=false ;;
    *) echo "✗  Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# ── Credentials (reused from tiktok_clone — same Apple ID / Team) ────────────
TIKTOK_SCRIPTS="$HOME/github/tiktok_clone/scripts"
RELEASE_ENV="$TIKTOK_SCRIPTS/release.env.local"
if [ -f "$RELEASE_ENV" ]; then
  source "$RELEASE_ENV"
else
  echo "⚠  $RELEASE_ENV not found — notarization will be skipped."
  NOTARIZE=false
fi

if $NOTARIZE; then
  for VAR in APPLE_ID TEAM_ID APP_PASSWORD; do
    if [ -z "${!VAR:-}" ]; then
      echo "⚠  $VAR not set in $RELEASE_ENV — notarization will be skipped."
      NOTARIZE=false
    fi
  done
fi

echo "════════════════════════════════════════"
echo "▶  [1/6] Build universal binary"
echo "════════════════════════════════════════"
cd "$REPO_ROOT"
swift build -c release --arch arm64 --arch x86_64

echo
echo "════════════════════════════════════════"
echo "▶  [2/6] Assemble .app bundle"
echo "════════════════════════════════════════"
rm -rf "$REPO_ROOT/.release"
mkdir -p "$STAGING_APP/Contents/MacOS" "$STAGING_APP/Contents/Resources"
cp "$BUILD_DIR/ShareMyInternetBeta" "$STAGING_APP/Contents/MacOS/$APP_NAME"
cp "$REPO_ROOT/Resources/core.sh" "$REPO_ROOT/Resources/watchdog.sh" "$STAGING_APP/Contents/Resources/"

cat > "$STAGING_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF
echo "✓  Assembled: $STAGING_APP"

echo
echo "════════════════════════════════════════"
echo "▶  [3/6] Sign .app (Developer ID, hardened runtime)"
echo "════════════════════════════════════════"
source "$TIKTOK_SCRIPTS/_keychain_helpers.sh"
_ensure_keychain_ready

SIGN_CERT="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep 'Developer ID Application' | head -1 | awk '{print $2}')"
if [ -z "$SIGN_CERT" ]; then
  echo "✗  Developer ID Application cert not found in keychain." >&2
  exit 1
fi

codesign --force --options runtime --timestamp --sign "$SIGN_CERT" "$STAGING_APP"
echo "✓  Signed with hardened runtime"

echo
echo "════════════════════════════════════════"
echo "▶  [4/6] Create DMG"
echo "════════════════════════════════════════"
for i in "" " 1" " 2" " 3"; do
  hdiutil detach "/Volumes/$APP_NAME${i}" 2>/dev/null || true
done
rm -f "$DMG"

DMG_TMP="${DMG%.dmg}_tmp.dmg"
MOUNT_POINT="$(mktemp -d)"
APP_SIZE_MB=$(du -sm "$STAGING_APP" | cut -f1)
IMAGE_SIZE_MB=$(( APP_SIZE_MB + 30 ))

rm -f "$DMG_TMP"
hdiutil create -size "${IMAGE_SIZE_MB}m" -volname "$APP_NAME" -fs HFS+ -layout SPUD "$DMG_TMP"
hdiutil attach "$DMG_TMP" -mountpoint "$MOUNT_POINT"
ditto "$STAGING_APP" "$MOUNT_POINT/$APP_NAME.app"
ln -s /Applications "$MOUNT_POINT/Applications"
hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force
rm -rf "$MOUNT_POINT"
hdiutil convert "$DMG_TMP" -format UDZO -o "$DMG"
rm -f "$DMG_TMP"
echo "✓  DMG: $DMG  ( $(du -sh "$DMG" | cut -f1) )"

echo
echo "════════════════════════════════════════"
echo "▶  [5/6] Sign DMG"
echo "════════════════════════════════════════"
codesign --sign "$SIGN_CERT" --timestamp "$DMG"
echo "✓  DMG signed"

echo
echo "════════════════════════════════════════"
echo "▶  [6/6] Notarize + staple"
echo "════════════════════════════════════════"
if $NOTARIZE; then
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id  "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG"
  echo "✓  Notarization complete and stapled"
else
  echo "ℹ  Skipped (no credentials or --no-notarize given)."
fi

echo
echo "Done: $DMG"
echo
echo "Verification:"
echo "  spctl -a -vvv \"$STAGING_APP\""
echo "  codesign -vvv --deep \"$STAGING_APP\""
