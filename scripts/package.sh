#!/usr/bin/env bash
#
#  File:      package.sh
#  Created:   2026-06-09
#  Updated:   2026-06-14
#  Developer: Kennt Kim / Calida Lab
#  Overview:  Builds release SiliconScope.app, Developer ID–signs it (hardened runtime),
#             notarizes + staples it, then ships a notarized DMG with an /Applications
#             drop link.
#  Notes:     SPM emits no .app, so Contents/{MacOS,Resources} + Info.plist are assembled
#             by hand; the SPM resource bundle is copied alongside a top-level
#             AppIcon.icns. Requires a stored notarytool keychain profile. The profile
#             name (NOTARY_PROFILE) is a pre-existing local keychain credential kept
#             as "WhisPlayInfo-notary" so notarization works without re-auth.
#             Usage: scripts/package.sh [version]
#
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP="SiliconScope"
BUNDLE_ID="ai.calidalab.SiliconScope"
IDENTITY="Developer ID Application: YONG SOO KIM (8677QL77VJ)"
NOTARY_PROFILE="WhisPlayInfo-notary"   # pre-existing local keychain profile (kept to avoid re-auth)
DIST="dist"
APPDIR="$DIST/$APP.app"

echo "▸ Building release binary…"
xcrun swift build -c release --product "$APP"
BIN=".build/release/$APP"
RES_BUNDLE=".build/release/SiliconScope_${APP}.bundle"
ICON="Sources/$APP/Resources/AppIcon.icns"

echo "▸ Assembling $APP.app…"
rm -rf "$DIST"; mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
cp "$BIN" "$APPDIR/Contents/MacOS/$APP"
cp "$ICON" "$APPDIR/Contents/Resources/AppIcon.icns"
[ -d "$RES_BUNDLE" ] && cp -R "$RES_BUNDLE" "$APPDIR/Contents/Resources/"

cat > "$APPDIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

echo "▸ Signing (Developer ID, hardened runtime)…"
# The SPM resource bundle is a flat resource folder (no Info.plist / no code), so it
# is sealed by the app signature — do NOT sign it separately.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APPDIR"
codesign --verify --strict --verbose=2 "$APPDIR"

echo "▸ Notarizing app…"
ZIP="$DIST/$APP-notarize.zip"
ditto -c -k --keepParent "$APPDIR" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APPDIR"
rm -f "$ZIP"

echo "▸ Building DMG…"
STAGE="$DIST/.stage"; mkdir -p "$STAGE"
cp -R "$APPDIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP-$VERSION.dmg"
hdiutil create -volname "$APP $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "▸ Notarizing DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo ""
echo "▸ Gatekeeper check:"
spctl -a -vvv "$APPDIR" 2>&1 || true
echo ""
echo "✓ $APPDIR  (signed, notarized, stapled)"
echo "✓ $DMG"
ls -lh "$DMG"
