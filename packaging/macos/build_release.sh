#!/usr/bin/env bash
# Tempo — macOS release: build, sign, package as a DMG, notarise, staple.
#
# Everything that needs an identity comes from the environment, so nothing
# secret lives in the repository:
#
#   export TEMPO_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export TEMPO_NOTARY_PROFILE="tempo-notary"   # see below
#   ./packaging/macos/build_release.sh
#
# The notary profile is stored once, in the keychain:
#
#   xcrun notarytool store-credentials tempo-notary \
#     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
#
# Signing and notarising are optional: without TEMPO_SIGN_IDENTITY the script
# still produces a DMG, which is fine for your own machine but will be refused
# by Gatekeeper on anyone else's.

set -euo pipefail

cd "$(dirname "$0")/../.."

APP_NAME="Tempo"
VERSION="$(grep '^version:' pubspec.yaml | head -1 | sed 's/version: *//' | cut -d'+' -f1)"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
OUT_DIR="packaging/macos/output"
DMG_PATH="$OUT_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Building $APP_NAME $VERSION"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "Build produced no app at $APP_PATH" >&2
  exit 1
fi

if [ -n "${TEMPO_SIGN_IDENTITY:-}" ]; then
  echo "==> Signing with $TEMPO_SIGN_IDENTITY"
  # Deep signing with the hardened runtime, which notarisation requires.
  codesign --force --deep --options runtime --timestamp \
    --entitlements macos/Runner/Release.entitlements \
    --sign "$TEMPO_SIGN_IDENTITY" "$APP_PATH"
  codesign --verify --strict --verbose=2 "$APP_PATH"
else
  echo "==> TEMPO_SIGN_IDENTITY not set — skipping signing"
fi

echo "==> Packaging $DMG_PATH"
mkdir -p "$OUT_DIR"
rm -f "$DMG_PATH"
STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"

if [ -n "${TEMPO_SIGN_IDENTITY:-}" ] && [ -n "${TEMPO_NOTARY_PROFILE:-}" ]; then
  echo "==> Signing the disk image"
  codesign --force --sign "$TEMPO_SIGN_IDENTITY" "$DMG_PATH"

  echo "==> Notarising (this waits for Apple)"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$TEMPO_NOTARY_PROFILE" --wait

  echo "==> Stapling"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
else
  echo "==> Notary credentials not set — skipping notarisation"
fi

echo "==> Done: $DMG_PATH"
