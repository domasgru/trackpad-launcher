#!/bin/bash
# Regenerates the committed fixtures of a genuine release under
# LauncherKit/Tests/LauncherPlatformTests/UpdateFixtures/:
#   DeveloperID/TrackpadLauncher.app      signed with the project's Developer ID, notarised and stapled
#   AppleDevelopment/TrackpadLauncher.app the same app signed with the Apple Development identity (what Debug and perf
#                                         builds carry)
#   TrackpadLauncher-fixture.aar          the Developer ID app archived exactly as the release archives it
#   fixture.json                          version, minimum macOS, team, identifier and the file manifest
#
# Notarisation submits to Apple with your credentials: set NOTARY_PROFILE to a notarytool keychain profile
# (xcrun notarytool store-credentials). Nothing runs without it.
set -euo pipefail

: "${NOTARY_PROFILE:?set NOTARY_PROFILE to a notarytool keychain profile name}"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
TEAM=CQK27876UL
IDENTIFIER=com.domasgru.TrackpadLauncherUpdateFixture
VERSION=1.0.0
MINIMUM_MACOS=26.0
DEVELOPER_ID_IDENTITY="Developer ID Application"
DEVELOPMENT_IDENTITY="Apple Development"

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/LauncherKit/Tests/LauncherPlatformTests/UpdateFixtures"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

make_app() {
  local app="$1/TrackpadLauncher.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat > "$work/main.c" <<'EOF'
int main(void) { return 0; }
EOF
  cc -arch arm64 -arch x86_64 -mmacosx-version-min="$MINIMUM_MACOS" -o "$app/Contents/MacOS/TrackpadLauncher" "$work/main.c"
  cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$IDENTIFIER</string>
  <key>CFBundleName</key><string>TrackpadLauncher</string>
  <key>CFBundleExecutable</key><string>TrackpadLauncher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>$MINIMUM_MACOS</string>
</dict>
</plist>
EOF
  printf 'a sealed resource\n' > "$app/Contents/Resources/fixture.txt"
  echo "$app"
}

rm -rf "$out/DeveloperID" "$out/AppleDevelopment" "$out/TrackpadLauncher-fixture.aar" "$out/fixture.json"
mkdir -p "$out/DeveloperID" "$out/AppleDevelopment"

developer_id_app="$(make_app "$out/DeveloperID")"
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$developer_id_app"
ditto -c -k --keepParent "$developer_id_app" "$work/notarise.zip"
xcrun notarytool submit "$work/notarise.zip" --wait --keychain-profile "$NOTARY_PROFILE"
xcrun stapler staple "$developer_id_app"

development_app="$(make_app "$out/AppleDevelopment")"
codesign --force --sign "$DEVELOPMENT_IDENTITY" "$development_app"

mkdir -p "$work/archive"
cp -R "$developer_id_app" "$work/archive/"
aa archive -d "$work/archive" -subdir TrackpadLauncher.app -exclude-field uid,gid,xat,acl,flg -o "$out/TrackpadLauncher-fixture.aar"

python3 -I - "$developer_id_app" "$out/fixture.json" "$VERSION" "$MINIMUM_MACOS" "$TEAM" "$IDENTIFIER" <<'EOF'
import hashlib, json, os, sys

app, destination, version, minimum, team, identifier = sys.argv[1:]
manifest = {}
for folder, directories, files in os.walk(app):
    for name in directories + files:
        path = os.path.join(folder, name)
        relative = os.path.relpath(path, app)
        if os.path.islink(path):
            manifest[relative] = "link:" + os.readlink(path)
        elif os.path.isdir(path):
            manifest[relative] = "dir"
        else:
            with open(path, "rb") as handle:
                manifest[relative] = hashlib.sha256(handle.read()).hexdigest()
record = {"version": version, "minimumMacOS": minimum, "team": team, "identifier": identifier, "manifest": manifest}
with open(destination, "w") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
EOF

codesign --verify --strict --verbose=2 "$developer_id_app"
spctl --assess --type execute --verbose=2 "$developer_id_app"
echo "Fixtures written to $out"
