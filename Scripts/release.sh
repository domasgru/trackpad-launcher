#!/bin/bash
# Builds a release: refuses a version that is not above every earlier release, archives, exports with the
# developer-id method, notarizes and staples the app, archives it as the update asset, lays out a disk image,
# signs, notarizes and staples it, and creates a DRAFT GitHub release carrying both.
# Output: build/release/TrackpadLauncher.dmg
#         build/release/TrackpadLauncher-<version>-macOS-<minimum>.aar
#         a draft release v<version> on GitHub; publishing is a separate, deliberate step:
#         gh release edit v<version> --draft=false --latest
#
# Needs gh authenticated for the repository, a clean worktree whose HEAD is on origin,
# a "Developer ID Application" identity in the keychain, a notarytool
# keychain profile (xcrun notarytool store-credentials) named by NOTARY_PROFILE,
# and xcodegen on the PATH. The Finder layout step needs the Automation
# permission for Finder (asked once). Signing of the app is left to xcodebuild,
# which signs nested code first and the main executable last; --deep is never used.
#
#   Scripts/release.sh                     full release
#   Scripts/release.sh --image-only <app>  lay out an UNSIGNED image around an
#                                          existing app, to check the layout
#                                          without a certificate
#   Scripts/release.sh --archive-only <app> write the .aar for an existing app and self-check it the way an
#                                          older version will, without notarisation or GitHub. Here the
#                                          stapler and Team ID checks are only reported; in the full
#                                          release they are fatal
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-CQK27876UL}"
APP_NAME="TrackpadLauncher"
VOLUME_NAME="Trackpad Launcher"
OUT="${RELEASE_OUT:-$ROOT/build/release}"
BACKGROUND="$ROOT/Scripts/release/dmg-background.png"
DMG="$OUT/$APP_NAME.dmg"
REPOSITORY="domasgru/trackpad-launcher"
# Dotted whole numbers of one to nine digits each: exactly what the app's Version parses.
NUMERIC='^[0-9]{1,9}(\.[0-9]{1,9})*$'
EXPECTED_VERSION=""
AAR=""
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

# Drops trailing ".0" parts, as the app's Version does when it compares: 1.1.0 is 1.1.
normalise_version() {
  local version="$1"
  while [[ "$version" == *.0 ]]; do version="${version%.0}"; done
  echo "$version"
}

# Prints -1, 0 or 1 as version $1 is below, equal to or above version $2, part by part as numbers.
compare_versions() {
  local -a first second
  IFS=. read -ra first <<<"$(normalise_version "$1")"
  IFS=. read -ra second <<<"$(normalise_version "$2")"
  local count=${#first[@]} index left right
  [ "${#second[@]}" -le "$count" ] || count=${#second[@]}
  for ((index = 0; index < count; index++)); do
    left=$((10#${first[index]:-0}))
    right=$((10#${second[index]:-0}))
    if [ "$left" -lt "$right" ]; then echo -1; return; fi
    if [ "$left" -gt "$right" ]; then echo 1; return; fi
  done
  echo 0
}

# Reads tag names, one per line, and prints the first whose version is not below version $1; prints nothing when $1 is
# above all of them. A name that is not "v" and dotted whole numbers is not a version the app reads: it is skipped.
first_not_below() {
  local version="$1" name earlier
  while IFS= read -r name; do
    earlier="${name#v}"
    [[ "$earlier" =~ $NUMERIC ]] || continue
    if [ "$(compare_versions "$version" "$earlier")" -le 0 ]; then
      echo "$name"
      return
    fi
  done
}

# Refuses to start unless the version in Config/Version.xcconfig is above every earlier tag and release,
# drafts included. Sets EXPECTED_VERSION.
preflight() {
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; run 'gh auth login' and retry."
  git -C "$ROOT" fetch --quiet --tags origin || fail "cannot fetch origin."
  [ -z "$(git -C "$ROOT" status --porcelain)" ] || fail "the worktree is not clean; commit or stash everything and retry."
  [ -n "$(git -C "$ROOT" branch --remotes --contains HEAD)" ] ||
    fail "HEAD is not on origin; push it first, the release targets this commit."

  EXPECTED_VERSION="$(sed -n 's/^MARKETING_VERSION *= *//p' "$ROOT/Config/Version.xcconfig" | tr -d '[:space:]')"
  [[ "$EXPECTED_VERSION" =~ $NUMERIC ]] ||
    fail "MARKETING_VERSION '$EXPECTED_VERSION' in Config/Version.xcconfig is not dotted whole numbers."
  [ -z "$(git -C "$ROOT" tag --list "v$EXPECTED_VERSION")" ] || fail "tag v$EXPECTED_VERSION already exists."

  local releases tags clash
  releases="$(gh release list --repo "$REPOSITORY" --limit 1000 --json tagName --jq '.[].tagName')" ||
    fail "cannot list the releases of $REPOSITORY."
  tags="$(git -C "$ROOT" tag --list 'v*')"
  clash="$(printf '%s\n%s\n' "$tags" "$releases" | first_not_below "$EXPECTED_VERSION")"
  [ -z "$clash" ] ||
    fail "version $EXPECTED_VERSION is not above every earlier release ($clash exists); raise Config/Version.xcconfig."
}

# Archives the app as the update asset, unpacks it as an older version will and checks the result. Sets AAR.
# With mode "lenient" the stapler and Team ID checks are reported instead of fatal.
archive_and_check() {
  local app="$1" mode="$2"
  [ -d "$app" ] || fail "no app at $app"
  local plist="$app/Contents/Info.plist" version minimum
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
  minimum="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
  [[ "$version" =~ $NUMERIC ]] || fail "app version '$version' is not dotted whole numbers."
  [[ "$minimum" =~ $NUMERIC ]] || fail "app minimum macOS '$minimum' is not dotted whole numbers."
  [ -z "$EXPECTED_VERSION" ] || [ "$version" = "$EXPECTED_VERSION" ] ||
    fail "app version $version differs from Config/Version.xcconfig's $EXPECTED_VERSION."

  AAR="$OUT/$APP_NAME-$version-macOS-$minimum.aar"
  local source unpacked copy
  source="$(mktemp -d)"
  unpacked="$(mktemp -d)"
  ditto "$app" "$source/$APP_NAME.app"
  mkdir -p "$OUT"
  rm -f "$AAR"
  aa archive -d "$source" -subdir "$APP_NAME.app" -exclude-field uid,gid,xat,acl,flg -o "$AAR"
  aa extract -d "$unpacked" -i "$AAR"
  copy="$unpacked/$APP_NAME.app"
  [ -d "$copy" ] || fail "the archive does not unpack to $APP_NAME.app."

  codesign --verify --strict --deep --verbose=2 "$copy" || fail "the unpacked app fails codesign verification."
  local before after
  before="$(codesign -dv --verbose=2 "$app" 2>&1 | grep -E '^(Identifier|TeamIdentifier)=' | sort)"
  after="$(codesign -dv --verbose=2 "$copy" 2>&1 | grep -E '^(Identifier|TeamIdentifier)=' | sort)"
  [ "$before" = "$after" ] || fail "identifier or team changed by the archive: '$before' vs '$after'."

  local stapled=true signed=true
  xcrun stapler validate "$copy" >/dev/null 2>&1 || stapled=false
  grep -qx "TeamIdentifier=$TEAM_ID" <<<"$after" || signed=false
  if [ "$mode" = lenient ]; then
    $stapled || echo "note: no valid stapled ticket (not fatal in --archive-only)."
    $signed || echo "note: not signed by team $TEAM_ID (not fatal in --archive-only)."
  else
    $stapled || fail "the unpacked app has no valid stapled ticket."
    $signed || fail "the unpacked app is not signed by team $TEAM_ID."
  fi
  # The kernel stamps com.apple.provenance on files this process creates; it cannot be excluded, anything else can.
  [ -z "$(xattr -lr "$copy" | grep -v ': com.apple.provenance: ')" ] || fail "the unpacked app carries extended attributes."
  rm -rf "$source" "$unpacked"
  echo "Archive self-check passed: $AAR"
}

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

if [ "${1:-}" = "--archive-only" ]; then
  [ -n "${2:-}" ] || fail "usage: release.sh --archive-only <path to TrackpadLauncher.app>"
  archive_and_check "$2" lenient
  exit 0
fi

preflight

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

archive_and_check "$APP" strict

build_image "$APP"

codesign --timestamp -s "Developer ID Application" "$DMG"
codesign --verify --verbose=2 "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type open --context context:primary-signature -vv "$DMG"
spctl --assess --type execute -vv "$APP"

MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
gh release create "v$EXPECTED_VERSION" "$DMG" "$AAR" --repo "$REPOSITORY" --draft \
  --target "$(git -C "$ROOT" rev-parse HEAD)" \
  --title "Trackpad Launcher $EXPECTED_VERSION" --notes "Requires macOS $MIN_MACOS or later."
echo "Release artifacts: $DMG $AAR"
echo "Draft v$EXPECTED_VERSION created. Publish with: gh release edit v$EXPECTED_VERSION --draft=false --latest"
