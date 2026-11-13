#!/bin/bash
# Releases main: checks every credential and that main is clean and current, runs the tests, optionally raises the
# version, refuses a version that is not above every earlier release, archives, exports with the developer-id
# method, notarizes and staples the app, archives it as the update asset, lays out a disk image, signs, notarizes
# and staples it, and publishes a GitHub release carrying both, then adds its item to the update feed.
# Output: build/release/TrackpadApp.dmg
#         build/release/TrackpadLauncher-<version>-macOS-<minimum>.aar
#         the release v<version> on GitHub, published and marked latest: copies from before automatic updates
#         offer it on their old card the next time their settings window opens. gh uploads the assets before it publishes, so no copy sees a half-made one.
#         the feed item in appcast.xml, committed to main: newer copies learn of the release from it, at a login start or when their settings window opens.
#
# The feed, appcast.xml at the repository's root, is served by raw.githubusercontent.com and is the update list of
# every copy with automatic updates. Only this script writes it: it signs the .aar with the update key (the keychain's, which must
# be the one project.yml ships as SUPublicEDKey; its private half cannot rotate, so back it up with
# generate_keys -x), adds an item and keeps the older ones. The order is: publish the release, then the feed, so the
# feed never names an asset that does not exist. Sparkle compares CFBundleVersion, so the build number must be above
# every earlier one's; the script refuses a release whose build number is not above the feed's and the last tag's.
# The card-contract tool runs on the .aar and fails the release should an older copy's update card refuse it.
#
# Needs gh authenticated for the repository, the main branch checked out, clean and equal to origin's,
# a "Developer ID Application" identity in the keychain, a notarytool keychain profile
# (xcrun notarytool store-credentials) named by NOTARY_PROFILE (default: trackpad-launcher),
# and xcodegen on the PATH. The Finder layout step needs the Automation
# permission for Finder (asked once). Signing of the app is left to xcodebuild,
# which signs nested code first and the main executable last; --deep is never used.
#
#   Scripts/release.sh patch|minor|major   raise the version (1.2.3 → 1.2.4 | 1.3.0 | 2.0.0) and the build number by
#                                          one, commit that, release it, and push the commit just before publishing.
#                                          Should anything fail before the push, the version commit is undone, so
#                                          the same command tries the same version again
#   Scripts/release.sh                     release the version already in Config/Version.xcconfig
#   Scripts/release.sh --image-only <app>  lay out an UNSIGNED image around an
#                                          existing app, to check the layout
#                                          without a certificate
#   Scripts/release.sh --archive-only <app> write the .aar for an existing app and self-check it the way an
#                                          older version will, without notarisation or GitHub. Here the
#                                          stapler and Team ID checks are only reported; in the full
#                                          release they are fatal. The bundle identifier check is fatal
#                                          in both
#   Scripts/release.sh --feed-only <version> write and publish the feed item of an already published release: the way
#                                          to finish a release whose feed push was rejected (the local feed commit
#                                          is then undone). A rerun replaces the version's item; a feed that comes out byte-identical publishes nothing
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-CQK27876UL}"
PROJECT_NAME="TrackpadApp"
# The bundle as users get it: Finder, the Dock and Spotlight show its file name, not CFBundleDisplayName.
BUNDLE_NAME="Trackpad App.app"
# The update archive's asset prefix and the one bundle name inside it: a contract with every shipped version, which
# refuses any other entry and installs the bundle over its own copy, whatever that copy is named.
ARCHIVE_PREFIX="TrackpadLauncher"
ARCHIVED_BUNDLE_NAME="TrackpadLauncher.app"
BUNDLE_ID="com.domasgru.TrackpadLauncherApp"
VOLUME_NAME="Trackpad App"
OUT="${RELEASE_OUT:-$ROOT/build/release}"
BACKGROUND="$ROOT/Scripts/release/dmg-background.png"
DMG="$OUT/$PROJECT_NAME.dmg"
REPOSITORY="domasgru/trackpad-app"
# Where every feed item's download lies: the repository's path before its rename, which GitHub redirects to
# $REPOSITORY. A contract with every shipped version, whose Info.plist key TLUpdateDownloads admits only addresses
# under it; keep it equal to TLUpdateDownloads in project.yml.
DOWNLOADS="https://github.com/domasgru/trackpad-launcher/releases/download"
VERSION_FILE="$ROOT/Config/Version.xcconfig"
FEED="$ROOT/appcast.xml"
SPARKLE_BIN="$ROOT/LauncherKit/Vendor/Sparkle/bin"
NOTARY_PROFILE="${NOTARY_PROFILE:-trackpad-launcher}"
# True from the version commit until it is pushed: should the script stop in between, the commit is undone.
UNPUSHED_BUMP=false
# Dotted whole numbers of one to nine digits each: exactly what the app's Version parses.
NUMERIC='^[0-9]{1,9}(\.[0-9]{1,9})*$'
EXPECTED_VERSION=""
AAR=""
STAGE="$OUT/dmg-stage"
RW_DMG="$OUT/$PROJECT_NAME-rw.dmg"

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
  if $UNPUSHED_BUMP; then
    UNPUSHED_BUMP=false
    git -C "$ROOT" reset --quiet --keep HEAD~1 &&
      echo "release.sh: nothing was published; the version commit was undone, so the same command retries it." >&2
  fi
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

# A setting's value in Config/Version.xcconfig.
read_setting() {
  sed -n "s/^$1 *= *//p" "$VERSION_FILE" | tr -d '[:space:]'
}

# Refuses to start, before anything changes, unless every credential works and the checkout is main, clean and equal
# to origin's main: the release targets this commit, and a version commit goes on top of it.
preflight_checkout() {
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; run 'gh auth login' and retry."
  # Captured first, here and below: grep -q leaves at its match, and the writer dying of SIGPIPE fails pipefail.
  grep -q "Developer ID Application" <<<"$(security find-identity -v -p codesigning)" ||
    fail "no 'Developer ID Application' signing identity in the keychain; install the certificate and retry."
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
    fail "notarytool cannot use keychain profile '$NOTARY_PROFILE'; create it with 'xcrun notarytool store-credentials $NOTARY_PROFILE' or set NOTARY_PROFILE."
  command -v xcodegen >/dev/null ||
    fail "xcodegen is not on the PATH; install it (brew install xcodegen) and retry."
  [ -x "$SPARKLE_BIN/sign_update" ] && [ -x "$SPARKLE_BIN/generate_keys" ] ||
    fail "Sparkle's tools are missing from LauncherKit/Vendor/Sparkle/bin."
  [ "$("$SPARKLE_BIN/generate_keys" -p)" = "$(sed -n 's/^ *SUPublicEDKey: *//p' "$ROOT/project.yml")" ] ||
    fail "the keychain's update key is not the one project.yml ships; import the backup with generate_keys -f."
  xmllint --noout "$FEED" || fail "appcast.xml is not well-formed."

  git -C "$ROOT" fetch --quiet --tags origin || fail "cannot fetch origin."
  [ "$(git -C "$ROOT" branch --show-current)" = main ] || fail "check out main first; releases are made from main."
  [ -z "$(git -C "$ROOT" status --porcelain)" ] || fail "the worktree is not clean; commit or stash everything and retry."
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$ROOT" rev-parse origin/main)" ] ||
    fail "main differs from origin's main; pull or push first, so the release is exactly what is on GitHub."
}

# Raises the version in Config/Version.xcconfig by `patch`, `minor` or `major`, and the build number by one, and
# commits it on main without pushing.
bump_version() {
  local part="$1" current build next major minor patch
  current="$(read_setting MARKETING_VERSION)"
  build="$(read_setting CURRENT_PROJECT_VERSION)"
  [[ "$current" =~ ^[0-9]{1,9}(\.[0-9]{1,9}){0,2}$ ]] ||
    fail "MARKETING_VERSION '$current' is not one to three dotted whole numbers; raise it by hand and run release.sh alone."
  [[ "$build" =~ ^[0-9]{1,9}$ ]] || fail "CURRENT_PROJECT_VERSION '$build' is not a whole number."
  IFS=. read -r major minor patch <<<"$current"
  major=$((10#$major)) minor=$((10#${minor:-0})) patch=$((10#${patch:-0}))
  case "$part" in
    major) next="$((major + 1)).0.0" ;;
    minor) next="$major.$((minor + 1)).0" ;;
    patch) next="$major.$minor.$((patch + 1))" ;;
  esac
  sed -i '' -e "s/^MARKETING_VERSION *=.*/MARKETING_VERSION = $next/" \
    -e "s/^CURRENT_PROJECT_VERSION *=.*/CURRENT_PROJECT_VERSION = $((build + 1))/" "$VERSION_FILE"
  git -C "$ROOT" commit --quiet -m "Version $next" -- "$VERSION_FILE"
  UNPUSHED_BUMP=true
  echo "Version $current → $next, build $build → $((build + 1)), committed on main (pushed just before publishing)."
}

# Refuses a build number that Sparkle would never offer: it must be above the feed's highest and the previous tag's.
# The tag is checked as well, so an empty feed cannot bypass the check.
preflight_build_number() {
  local build highest tag tagged=""
  build="$(read_setting CURRENT_PROJECT_VERSION)"
  [[ "$build" =~ ^[0-9]{1,9}$ ]] || fail "CURRENT_PROJECT_VERSION '$build' is not a whole number."
  highest="$(sed -n 's:.*<sparkle\:version>\([0-9]*\)</sparkle\:version>.*:\1:p' "$FEED" | sort -n | tail -1)"
  [ "$build" -gt "${highest:-0}" ] || fail "build $build is not above the feed's $highest; Sparkle would never offer it."
  tag="$(git -C "$ROOT" tag --list 'v*' | sort -V | tail -1)"
  if [ -n "$tag" ]; then
    tagged="$(git -C "$ROOT" show "$tag:Config/Version.xcconfig" | sed -n 's/^CURRENT_PROJECT_VERSION *= *//p')"
    [ "$build" -gt "${tagged:-0}" ] || fail "build $build is not above $tag's $tagged."
  fi
}

# Refuses to go on unless the version in Config/Version.xcconfig is above every earlier tag and release,
# drafts included, and the build number is above every earlier one. Sets EXPECTED_VERSION.
preflight_version() {
  EXPECTED_VERSION="$(read_setting MARKETING_VERSION)"
  [[ "$EXPECTED_VERSION" =~ $NUMERIC ]] ||
    fail "MARKETING_VERSION '$EXPECTED_VERSION' in Config/Version.xcconfig is not dotted whole numbers."
  [ -z "$(git -C "$ROOT" tag --list "v$EXPECTED_VERSION")" ] || fail "tag v$EXPECTED_VERSION already exists."

  local releases tags clash
  releases="$(gh release list --repo "$REPOSITORY" --limit 1000 --json tagName --jq '.[].tagName')" ||
    fail "cannot list the releases of $REPOSITORY."
  tags="$(git -C "$ROOT" tag --list 'v*')"
  clash="$(printf '%s\n%s\n' "$tags" "$releases" | first_not_below "$EXPECTED_VERSION")"
  [ -z "$clash" ] ||
    fail "version $EXPECTED_VERSION is not above every earlier release ($clash exists); run 'release.sh patch' or raise Config/Version.xcconfig."
  preflight_build_number
}

# Archives the app as the update asset, unpacks it as an older version will and checks the result. Sets AAR.
# With mode "lenient" the stapler and Team ID checks are reported instead of fatal; the bundle identifier check is
# fatal in both modes.
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

  AAR="$OUT/$ARCHIVE_PREFIX-$version-macOS-$minimum.aar"
  local source unpacked copy
  source="$(mktemp -d)"
  unpacked="$(mktemp -d)"
  ditto "$app" "$source/$ARCHIVED_BUNDLE_NAME"
  mkdir -p "$OUT"
  rm -f "$AAR"
  aa archive -d "$source" -subdir "$ARCHIVED_BUNDLE_NAME" -exclude-field uid,gid,xat,acl,flg -o "$AAR"
  aa extract -d "$unpacked" -i "$AAR"
  copy="$unpacked/$ARCHIVED_BUNDLE_NAME"
  [ -d "$copy" ] || fail "the archive does not unpack to $ARCHIVED_BUNDLE_NAME."

  codesign --verify --strict --deep --verbose=2 "$copy" || fail "the unpacked app fails codesign verification."
  local before after
  before="$(codesign -dv --verbose=2 "$app" 2>&1 | grep -E '^(Identifier|TeamIdentifier)=' | sort)"
  after="$(codesign -dv --verbose=2 "$copy" 2>&1 | grep -E '^(Identifier|TeamIdentifier)=' | sort)"
  [ "$before" = "$after" ] || fail "identifier or team changed by the archive: '$before' vs '$after'."

  # Under another identifier a release would be a different app to macOS (fresh grants, settings and login item), and
  # no installed copy would accept it as an update, since the update's genuineness check pins the signer's identifier.
  grep -qxF "Identifier=$BUNDLE_ID" <<<"$after" ||
    fail "the app is not signed with the identifier $BUNDLE_ID (found: $(grep '^Identifier=' <<<"$after" | tr '\n' ' '))."

  local stapled=true signed=true
  xcrun stapler validate "$copy" >/dev/null 2>&1 || stapled=false
  grep -qx "TeamIdentifier=$TEAM_ID" <<<"$after" || signed=false
  if [ "$mode" = lenient ]; then
    $stapled || echo "note: no valid stapled ticket (not fatal in --archive-only)."
    $signed || echo "note: not signed by team $TEAM_ID (not fatal in --archive-only)."
  else
    $stapled || fail "the unpacked app has no valid stapled ticket."
    $signed || fail "the unpacked app is not signed by team $TEAM_ID."
    # Sparkle's atomic swap needs its installer and the update on one team.
    grep -qx "TeamIdentifier=$TEAM_ID" <<<"$(codesign -dv "$copy/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1)" ||
      fail "Sparkle's installer is not signed by team $TEAM_ID."
    grep -qx "TeamIdentifier=$TEAM_ID" <<<"$(codesign -dv "$copy/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" 2>&1)" ||
      fail "Sparkle's installer launcher service is not signed by team $TEAM_ID."
  fi
  # The kernel stamps com.apple.provenance on files this process creates; it cannot be excluded, anything else can.
  [ -z "$(xattr -lr "$copy" | grep -v ': com.apple.provenance: ')" ] || fail "the unpacked app carries extended attributes."
  rm -rf "$source" "$unpacked"
  echo "Archive self-check passed: $AAR"
}

# Ejects every disk image mounted as $VOLUME_NAME (or as "$VOLUME_NAME 1", "$VOLUME_NAME 2"…, the names macOS gives a
# second volume of the same name), typically an earlier release opened from Downloads or a leftover of a stopped run.
# The layout step addresses its disk by name in Finder, so another disk of the same name could take its layout.
# Only disk images are ejected; a volume of that name that is not one, or an image in use, stops the release.
eject_same_named_images() {
  local mount_point
  while IFS= read -r mount_point; do
    [ -n "$mount_point" ] || continue
    echo "Ejecting the disk image mounted at $mount_point"
    hdiutil detach "$mount_point" >/dev/null 2>&1 ||
      { sleep 2; hdiutil detach "$mount_point" >/dev/null 2>&1; } ||
      fail "cannot eject the disk image at '$mount_point'; something on it is in use (a running Trackpad App?). Quit it and retry."
  done < <(hdiutil info | awk -F'\t' -v name="/Volumes/$VOLUME_NAME" \
    '$NF == name || index($NF, name " ") == 1 && substr($NF, length(name) + 2) ~ /^[0-9]+$/ { print $NF }')
  [ ! -e "/Volumes/$VOLUME_NAME" ] ||
    fail "a volume named '$VOLUME_NAME' is mounted and is not a disk image; eject it and retry."
}

# Stages the app, an Applications link and the background, then writes an
# unsigned compressed image to $DMG.
build_image() {
  local app="$1"
  [ -d "$app" ] || fail "no app at $app"
  [ -f "$BACKGROUND" ] || fail "missing $BACKGROUND; run Scripts/release/make-dmg-background.swift"
  eject_same_named_images

  rm -rf "$STAGE" "$RW_DMG" "$DMG"
  mkdir -p "$STAGE/.background"
  ditto "$app" "$STAGE/$BUNDLE_NAME"
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
  until grep -q true <<<"$(osascript -e "tell application \"Finder\" to exists disk \"$disk_name\"" 2>/dev/null)"; do
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
    set position of item "$BUNDLE_NAME" of container window to {150, 190}
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

# Signs $AAR with the update key and renders the feed with its item for $EXPECTED_VERSION into $OUT/appcast.xml,
# read from the sealed bundle $APP. The tree is untouched, so a failure here leaves it clean.
write_feed() {
  local attributes signature item plist="$APP/Contents/Info.plist" name
  name="$(basename "$AAR")"
  attributes="$("$SPARKLE_BIN/sign_update" "$AAR")" || fail "cannot sign the update with the update key."
  signature="$(sed -n 's/.*edSignature="\([^"]*\)".*/\1/p' <<<"$attributes")"
  "$SPARKLE_BIN/sign_update" --verify "$AAR" "$signature" || fail "the update's signature does not verify."
  item="<item><title>$EXPECTED_VERSION</title>"
  item+="<pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>"
  item+="<sparkle:version>$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")</sparkle:version>"
  item+="<sparkle:shortVersionString>$EXPECTED_VERSION</sparkle:shortVersionString>"
  item+="<sparkle:minimumSystemVersion>$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")</sparkle:minimumSystemVersion>"
  item+="<enclosure url=\"$DOWNLOADS/v$EXPECTED_VERSION/$name\" $attributes type=\"application/octet-stream\"/></item>"
  # A version already in the feed is replaced, so --feed-only can run twice.
  awk -v item="$item" -v version="<title>$EXPECTED_VERSION</title>" \
    'index($0, version) { next } /<\/channel>/ { print item } { print }' "$FEED" > "$OUT/appcast.xml"
  xmllint --noout "$OUT/appcast.xml" || fail "the feed is not well-formed."
}

# Commits and pushes the rendered feed. A rejected push is undone locally, so main still equals origin's and
# --feed-only can run again.
publish_feed() {
  if cmp -s "$OUT/appcast.xml" "$FEED"; then
    echo "The feed is unchanged; nothing to publish."
    return
  fi
  local retry="v$EXPECTED_VERSION is published but the feed is not; run release.sh --feed-only $EXPECTED_VERSION."
  cp "$OUT/appcast.xml" "$FEED"
  git -C "$ROOT" add "$FEED" && git -C "$ROOT" commit --quiet -m "Feed $EXPECTED_VERSION" -- "$FEED" ||
    { git -C "$ROOT" checkout --quiet HEAD -- "$FEED"; fail "cannot commit the feed. $retry"; }
  git -C "$ROOT" push --quiet origin HEAD:main ||
    { git -C "$ROOT" reset --quiet --keep HEAD~1; fail "cannot push the feed. $retry"; }
  echo "Published the feed with $EXPECTED_VERSION."
}

if [ "${1:-}" = "--image-only" ]; then
  [ -n "${2:-}" ] || fail "usage: release.sh --image-only <path to Trackpad App.app>"
  mkdir -p "$OUT"
  build_image "$2"
  echo "Unsigned test image: $DMG"
  exit 0
fi

if [ "${1:-}" = "--archive-only" ]; then
  [ -n "${2:-}" ] || fail "usage: release.sh --archive-only <path to Trackpad App.app>"
  archive_and_check "$2" lenient
  swift run --package-path "$ROOT/LauncherKit" card-contract \
    "$AAR" --team "$TEAM_ID" --identifier "$BUNDLE_ID" ||
    echo "note: an older copy's card would refuse this archive (not fatal in --archive-only: the app is not notarised)."
  exit 0
fi

if [ "${1:-}" = "--feed-only" ]; then
  version="${2:-}"
  [[ "$version" =~ $NUMERIC ]] || fail "usage: release.sh --feed-only <published version>"
  preflight_checkout
  EXPECTED_VERSION="$version"
  mkdir -p "$OUT"
  rm -f "$OUT/$ARCHIVE_PREFIX-$version-macOS-"*.aar
  gh release download "v$version" --pattern '*.aar' --dir "$OUT" --repo "$REPOSITORY" ||
    fail "cannot download the archive of v$version; is it published?"
  archives=("$OUT/$ARCHIVE_PREFIX-$version-macOS-"*.aar)
  { [ "${#archives[@]}" -eq 1 ] && [ -f "${archives[0]}" ]; } || fail "v$version has no single $ARCHIVE_PREFIX-$version-macOS-*.aar."
  AAR="${archives[0]}"
  unpacked="$(mktemp -d)"
  aa extract -d "$unpacked" -i "$AAR"
  APP="$unpacked/$ARCHIVED_BUNDLE_NAME"
  [ -d "$APP" ] || fail "the archive does not unpack to $ARCHIVED_BUNDLE_NAME."
  write_feed
  publish_feed
  rm -rf "$unpacked"
  exit 0
fi

case "${1:-}" in
  "" | patch | minor | major) ;;
  *) fail "usage: release.sh [patch|minor|major]   (or --image-only <app>, --archive-only <app>, --feed-only <version>)" ;;
esac

preflight_checkout
"$ROOT/Scripts/test.sh" || fail "the tests fail; nothing was changed or published."
[ -z "${1:-}" ] || bump_version "$1"
# A failed publish can leave a draft nothing sees, and it would block this retry.
[ "$(gh release view "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --json isDraft --jq .isDraft 2>/dev/null)" != true ] ||
  gh release delete "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --yes
preflight_version

rm -rf "$OUT"
mkdir -p "$OUT"

(cd "$ROOT" && xcodegen generate)

xcodebuild archive \
  -project "$ROOT/$PROJECT_NAME.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$OUT/$PROJECT_NAME.xcarchive" \
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
  -archivePath "$OUT/$PROJECT_NAME.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export"

APP="$OUT/export/$BUNDLE_NAME"
[ -d "$APP" ] || fail "export did not produce $APP"

codesign --verify --strict --verbose=2 "$APP"
SIGNATURE="$(codesign -dv --verbose=2 "$APP" 2>&1)"
grep -q "Authority=Developer ID Application" <<<"$SIGNATURE" ||
  fail "exported app is not signed by a Developer ID Application identity."
grep -q "flags=0x10000(runtime)" <<<"$SIGNATURE" ||
  fail "exported app lacks the hardened runtime flag."

# The app is stapled before it goes into the image so a copy dragged out opens offline.
ZIP="$OUT/$PROJECT_NAME-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"

archive_and_check "$APP" strict
# After archive_and_check strict: the stapled archive, against every shipped card's own rules (R16).
swift run --package-path "$ROOT/LauncherKit" card-contract \
  "$AAR" --team "$TEAM_ID" --identifier "$BUNDLE_ID" || fail "an older copy's card would refuse this release."

build_image "$APP"

codesign --timestamp -s "Developer ID Application" "$DMG"
codesign --verify --verbose=2 "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type open --context context:primary-signature -vv "$DMG"
spctl --assess --type execute -vv "$APP"

MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
write_feed
if $UNPUSHED_BUMP; then
  git -C "$ROOT" push --quiet origin HEAD:main ||
    fail "cannot push the version commit to origin's main (did main move?); nothing was published."
  UNPUSHED_BUMP=false
fi
gh release create "v$EXPECTED_VERSION" "$DMG" "$AAR" --repo "$REPOSITORY" --latest \
  --target "$(git -C "$ROOT" rev-parse HEAD)" \
  --title "Trackpad App $EXPECTED_VERSION" --notes "Requires macOS $MIN_MACOS or later." ||
  fail "publishing v$EXPECTED_VERSION failed; main already holds its version, so run release.sh with no argument to retry."
publish_feed
echo "Release artifacts: $DMG $AAR"
echo "Published v$EXPECTED_VERSION."
