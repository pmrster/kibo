#!/usr/bin/env bash
set -euo pipefail

# Builds dist/Kibo.app and a DMG beside it.
#
#   Packaging/package.sh [version]
#
# With no signing credentials the app is ad-hoc signed and NOT notarized — installable, but macOS
# will ask the user to right-click → Open the first time. For a public build, set both:
#
#   SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" \
#   NOTARY_PROFILE=<notarytool keychain profile> \
#   REQUIRE_NOTARIZATION=1 Packaging/package.sh 0.1.0

APP_NAME="Kibo"
DISPLAY="Kibo"
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

# Version is injected, never edited into Packaging/Info.plist by hand — the plist's own value is
# a placeholder. PlistBuddy sets the key by name; an earlier `sed "s/0\.1\.0/$VERSION/"` matched a
# hardcoded literal, so bumping the plist would have silently stopped the substitution.
# CFBundleVersion is the commit count: monotonic, needs no bookkeeping, and distinct per build.
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
echo "    version $VERSION (build $BUILD_NUMBER)"

# The app icon is built from icon.png rather than committed as a binary .icns — one source of
# truth for the artwork, and nothing to regenerate by hand when the mascot changes. Info.plist
# declares CFBundleIconFile, so without this every DMG shipped a blank generic icon.
ICON_SRC="icon.png"
if [ -f "$ICON_SRC" ]; then
  echo "==> Building AppIcon.icns from $ICON_SRC"
  ICONSET="$DIST/.AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$ICON_SRC" \
      --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
else
  echo "WARN: $ICON_SRC missing — the bundle will use the generic icon."
fi

# Note there is no SwiftPM resource bundle to copy. The package declares no resources: the only
# data file is Fixtures/conversion-cases.json, which is read by the test suite from the repo and
# never ships inside the app.

# ---- Code signing + notarization (Gatekeeper trust) -----------------------------------------
# The entitlements are applied on BOTH paths. They are what puts the app in the App Sandbox with
# no network entitlement, so signing without them would ship an unsandboxed build — which is what
# happened while this file referenced an entitlements file that did not exist.
if [ ! -f "$ENTITLEMENTS" ]; then
  echo "ERROR: $ENTITLEMENTS is missing. It is what sandboxes the app; refusing to ship without it." >&2
  exit 1
fi

if [ -n "$SIGN_IDENTITY" ]; then
  echo "==> Code-signing app (hardened runtime + sandbox): $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  # Re-sign ad-hoc AFTER assembling the bundle. The linker ad-hoc-signs the bare binary, but
  # adding Info.plist invalidates that signature — which makes macOS report a quarantined
  # download as "damaged" (the scary message). A VALID ad-hoc signature downgrades that to the
  # ordinary "unidentified developer", which the user clears with right-click → Open. It is
  # still NOT notarized; only a Developer ID plus notarization removes the prompt entirely.
  echo "==> Ad-hoc signing app (no SIGN_IDENTITY → not notarized; users right-click → Open once)"
  codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP"
  codesign --verify --strict "$APP" && echo "    ad-hoc signature valid" \
    || echo "WARN: ad-hoc signature did not verify"
fi

# Prove the sandbox actually made it into the signature, rather than trusting that it did.
if codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert xml1 -o - - \
   | grep -q "com.apple.security.app-sandbox"; then
  echo "    sandbox entitlement present"
else
  echo "ERROR: the signed app is NOT sandboxed." >&2
  exit 1
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
