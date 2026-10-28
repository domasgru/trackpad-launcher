#!/bin/bash
# Builds the release disk image: archive, export with the developer-id method,
# notarize and staple the app, lay out a disk image, sign, notarize and staple it.
# Output: build/release/TrackpadLauncher.dmg
#
# Needs a "Developer ID Application" identity in the keychain, a notarytool
# keychain profile (xcrun notarytool store-credentials) named by NOTARY_PROFILE,
# and xcodegen on the PATH. The Finder layout step needs the Automation
# permission for Finder (asked once). Signing of the app is left to xcodebuild,
# which signs nested code first and the main executable last; --deep is never used.
#
#   Scripts/release.sh                     full release
#   Scripts/release.sh --image-only <app>  lay out an UNSIGNED image around an
#                                          existing app, to check the layout
#                                          without a certificate
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-CQK27876UL}"
APP_NAME="TrackpadLauncher"
VOLUME_NAME="Trackpad Launcher"
OUT="${RELEASE_OUT:-$ROOT/build/release}"
BACKGROUND="$ROOT/Scripts/release/dmg-background.png"
DMG="$OUT/$APP_NAME.dmg"
STAGE="$OUT/dmg-stage"
RW_DMG="$OUT/$APP_NAME-rw.dmg"

# Window content size in points; matches the background picture.
WINDOW_WIDTH=600
WINDOW_HEIGHT=400
WINDOW_LEFT=200
WINDOW_TOP=120

fail() { echo "release.sh: $*" >&2; exit 1; }

MOUNT_POINT=""
cleanup() {
  if [ -n "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
    MOUNT_POINT=""
  fi
  rm -f "$RW_DMG"
  rm -rf "$STAGE"
}
trap cleanup EXIT

# Stages the app, an Applications link and the background, then writes an
# unsigned compressed image to $DMG.
build_image() {
  local app="$1"
  [ -d "$app" ] || fail "no app at $app"
  [ -f "$BACKGROUND" ] || fail "missing $BACKGROUND; run Scripts/release/make-dmg-background.swift"
  [ ! -e "/Volumes/$VOLUME_NAME" ] ||
    fail "a volume named '$VOLUME_NAME' is already mounted; eject it and retry."

  rm -rf "$STAGE" "$RW_DMG" "$DMG"
  mkdir -p "$STAGE/.background"
  ditto "$app" "$STAGE/$APP_NAME.app"
  ln -s /Applications "$STAGE/Applications"
  cp "$BACKGROUND" "$STAGE/.background/dmg-background.png"

  local size_mb
  size_mb=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
  hdiutil create -srcfolder "$STAGE" -volname "$VOLUME_NAME" -fs HFS+ \
    -format UDRW -size "${size_mb}m" -ov "$RW_DMG" >/dev/null

  MOUNT_POINT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen |
    awk -F'\t' '/\/Volumes\//{print $NF}')"
  [ -n "$MOUNT_POINT" ] || fail "could not find the mount point of $RW_DMG"
  local disk_name
  disk_name="$(basename "$MOUNT_POINT")"

  # Finder learns about a fresh mount a moment after hdiutil returns.
  local tries=0
  until osascript -e "tell application \"Finder\" to exists disk \"$disk_name\"" 2>/dev/null | grep -q true; do
    tries=$((tries + 1))
    [ "$tries" -lt 20 ] || fail "Finder does not see the mounted volume '$disk_name' (or Automation permission for Finder is missing)."
    sleep 1
  done

  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$disk_name"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WINDOW_LEFT, $WINDOW_TOP, $((WINDOW_LEFT + WINDOW_WIDTH)), $((WINDOW_TOP + WINDOW_HEIGHT))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:dmg-background.png"
    set position of item "$APP_NAME.app" of container window to {150, 190}
    set position of item "Applications" of container window to {450, 190}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT
  sync

  hdiutil detach "$MOUNT_POINT" >/dev/null ||
    { sleep 3; hdiutil detach "$MOUNT_POINT" -force >/dev/null; }
  MOUNT_POINT=""

  hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
  rm -f "$RW_DMG"
}

if [ "${1:-}" = "--image-only" ]; then
  [ -n "${2:-}" ] || fail "usage: release.sh --image-only <path to TrackpadLauncher.app>"
  mkdir -p "$OUT"
  build_image "$2"
  echo "Unsigned test image: $DMG"
  exit 0
fi

security find-identity -v -p codesigning | grep -q "Developer ID Application" ||
  fail "no 'Developer ID Application' signing identity in the keychain; install the certificate and retry."

[ -n "${NOTARY_PROFILE:-}" ] ||
  fail "NOTARY_PROFILE is not set; create a profile with 'xcrun notarytool store-credentials <name>' and export its name."

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
  fail "notarytool cannot use keychain profile '$NOTARY_PROFILE'; check the profile name and credentials."

command -v xcodegen >/dev/null ||
  fail "xcodegen is not on the PATH; install it (brew install xcodegen) and retry."

rm -rf "$OUT"
mkdir -p "$OUT"

(cd "$ROOT" && xcodegen generate)

xcodebuild archive \
  -project "$ROOT/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$OUT/$APP_NAME.xcarchive" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID"

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$OUT/$APP_NAME.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export"

APP="$OUT/export/$APP_NAME.app"
[ -d "$APP" ] || fail "export did not produce $APP"

codesign --verify --strict --verbose=2 "$APP"
SIGNATURE="$(codesign -dv --verbose=2 "$APP" 2>&1)"
grep -q "Authority=Developer ID Application" <<<"$SIGNATURE" ||
  fail "exported app is not signed by a Developer ID Application identity."
grep -q "flags=0x10000(runtime)" <<<"$SIGNATURE" ||
  fail "exported app lacks the hardened runtime flag."

# The app is stapled before it goes into the image so a copy dragged out opens offline.
ZIP="$OUT/$APP_NAME-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"

build_image "$APP"

codesign --timestamp -s "Developer ID Application" "$DMG"
codesign --verify --verbose=2 "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type open --context context:primary-signature -vv "$DMG"
spctl --assess --type execute -vv "$APP"

echo "Release artifact: $DMG"
