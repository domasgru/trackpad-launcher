#!/bin/bash
# Archive, export with the developer-id method, notarize and staple.
# Needs a "Developer ID Application" identity in the keychain and a notarytool
# keychain profile (xcrun notarytool store-credentials), named by NOTARY_PROFILE.
# Signing is left to xcodebuild, which signs nested code first and the main
# executable last; --deep is never used.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-CQK27876UL}"
APP_NAME="TrackpadLauncher"
OUT="${RELEASE_OUT:-$ROOT/build/release}"

fail() { echo "release.sh: $*" >&2; exit 1; }

security find-identity -v -p codesigning | grep -q "Developer ID Application" ||
  fail "no 'Developer ID Application' signing identity in the keychain; install the certificate and retry."

[ -n "${NOTARY_PROFILE:-}" ] ||
  fail "NOTARY_PROFILE is not set; create a profile with 'xcrun notarytool store-credentials <name>' and export its name."

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
  fail "notarytool cannot use keychain profile '$NOTARY_PROFILE'; check the profile name and credentials."

rm -rf "$OUT"
mkdir -p "$OUT"

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

ZIP="$OUT/$APP_NAME-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$OUT/$APP_NAME.zip"
echo "Release artifact: $OUT/$APP_NAME.zip"
