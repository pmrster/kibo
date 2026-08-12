#!/usr/bin/env bash
set -euo pipefail

# Builds dist/WhoForgotToChangeLang.app and a DMG beside it.
#
#   Packaging/package.sh [version]
#
# With no signing credentials the app is ad-hoc signed and NOT notarized — installable, but macOS
# will ask the user to right-click → Open the first time. For a public build, set both:
#
#   SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" \
#   NOTARY_PROFILE=<notarytool keychain profile> \
#   REQUIRE_NOTARIZATION=1 Packaging/package.sh 0.1.0

APP_NAME="WhoForgotToChangeLang"
DISPLAY="WhoForgotToChangeLang"
VERSION="${1:-0.1.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR=".build/release"
DIST="dist"
APP="$DIST/$DISPLAY.app"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
REQUIRE_NOTARIZATION="${REQUIRE_NOTARIZATION:-0}"
ENTITLEMENTS="Packaging/$APP_NAME.entitlements"

cd "$REPO_ROOT"

if [ "$REQUIRE_NOTARIZATION" = "1" ] && { [ -z "$SIGN_IDENTITY" ] || [ -z "$NOTARY_PROFILE" ]; }; then
  echo "ERROR: REQUIRE_NOTARIZATION=1 needs SIGN_IDENTITY and NOTARY_PROFILE." >&2
  exit 1
fi

echo "==> Running tests"
swift test

echo "==> Building release binary"
swift build -c release --product "$APP_NAME"

echo "==> Assembling app bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed "s/0\.1\.0/$VERSION/" Packaging/Info.plist > "$APP/Contents/Info.plist"

# The app icon is optional; without it macOS shows the generic application icon.
if [ -f Packaging/AppIcon.icns ]; then
  cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "    (no Packaging/AppIcon.icns — the bundle will use the generic icon)"
fi

# Note there is no SwiftPM resource bundle to copy. The package declares no resources: the only
# data file is Fixtures/conversion-cases.json, which is read by the test suite from the repo and
# never ships inside the app.

# ---- Optional: code signing + notarization (Gatekeeper trust) -------------------------------
if [ -n "$SIGN_IDENTITY" ]; then
  echo "==> Code-signing app (hardened runtime): $SIGN_IDENTITY"
  ENT_ARGS=()
  [ -f "$ENTITLEMENTS" ] && ENT_ARGS=(--entitlements "$ENTITLEMENTS")
  codesign --force --options runtime --timestamp \
    "${ENT_ARGS[@]}" --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  # Re-sign ad-hoc AFTER assembling the bundle. The linker ad-hoc-signs the bare binary, but
  # adding Info.plist invalidates that signature — which makes macOS report a quarantined
  # download as "damaged" (the scary message). A VALID ad-hoc signature downgrades that to the
  # ordinary "unidentified developer", which the user clears with right-click → Open. It is
  # still NOT notarized; only a Developer ID plus notarization removes the prompt entirely.
  echo "==> Ad-hoc signing app (no SIGN_IDENTITY → not notarized; users right-click → Open once)"
  codesign --force --sign - "$APP"
  codesign --verify --strict "$APP" && echo "    ad-hoc signature valid" \
    || echo "WARN: ad-hoc signature did not verify"
fi

echo "==> Creating DMG"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
rm -f "$DMG"
STAGE="$DIST/.dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$DISPLAY" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# Notarize BEFORE hashing, because stapling rewrites the DMG and would invalidate the checksum.
if [ -n "$SIGN_IDENTITY" ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "==> Signing DMG"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  echo "==> Notarizing DMG (waits for Apple)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling ticket"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
else
  echo "WARN: notarization skipped (set SIGN_IDENTITY + NOTARY_PROFILE). DMG not notarized."
fi

echo "==> SHA-256"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

# Versionless copy, so a GitHub Release can serve a constant asset name and a
# .../releases/latest/download/ link never goes stale across versions.
STABLE="$DIST/$APP_NAME.dmg"
cp "$DMG" "$STABLE"

echo "Done: $DMG (and $STABLE)"
