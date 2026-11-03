#!/bin/sh
# Runs codesign-requirement.swift against a notarised Developer ID app (Ghostty) and an ad-hoc signed
# throwaway bundle built in a temp directory, which is removed afterwards.
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d /tmp/tl-probe-cs.XXXXXX)
mkdir -p "$TMP/Adhoc.app/Contents/MacOS"
printf 'int main(void){return 0;}\n' > "$TMP/main.c"
clang -o "$TMP/Adhoc.app/Contents/MacOS/Adhoc" "$TMP/main.c"
cat > "$TMP/Adhoc.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>example.adhoc</string>
<key>CFBundleExecutable</key><string>Adhoc</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST
codesign -s - "$TMP/Adhoc.app" 2>&1
echo "== stapler validate Ghostty (is a ticket stapled?)"
xcrun stapler validate /Applications/Ghostty.app 2>&1 | tail -1
swift "$HERE/codesign-requirement.swift" /Applications/Ghostty.app "$TMP/Adhoc.app"
rm -rf "$TMP"
