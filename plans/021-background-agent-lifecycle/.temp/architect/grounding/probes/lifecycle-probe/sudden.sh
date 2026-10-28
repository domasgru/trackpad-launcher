#!/bin/bash
# Plan 021 follow-up probe: with NSSupportsSuddenTermination = YES, does a quit Apple event (osascript, as the
# Dock's Quit sends) or NSRunningApplication.terminate() (as a peer copy sends) still reach
# applicationShouldTerminate, so the app can cancel it? Cleans up like run.sh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=/tmp/tl021probe
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

rm -rf "$ROOT"; mkdir -p "$ROOT/build" "$ROOT/flags" "$ROOT/S"
: > "$ROOT/log.txt"
xcrun swiftc -O "$HERE/ProbeApp.swift" -o "$ROOT/build/TLProbe" || exit 1
xcrun swiftc -O "$HERE/terminator.swift" -o "$ROOT/build/terminator" || exit 1
APP="$ROOT/S/TLProbe.app"; mkdir -p "$APP/Contents/MacOS"; cp "$ROOT/build/TLProbe" "$APP/Contents/MacOS/TLProbe"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.domasgru.tl021probe</string>
<key>CFBundleExecutable</key><string>TLProbe</string>
<key>CFBundleName</key><string>TLProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSUIElement</key><true/>
<key>NSSupportsSuddenTermination</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP" >/dev/null 2>&1
procs() { echo "  processes: $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | tr '\n' ' ')"; }

echo "== S1 launch with NSSupportsSuddenTermination"; open "$APP"; sleep 2; procs
echo "== S2 osascript quit"; osascript -e 'tell application id "com.domasgru.tl021probe" to quit' 2>&1 | sed 's/^/  osascript: /'; sleep 1; procs
echo "== S3 NSRunningApplication.terminate()"; "$ROOT/build/terminator" | sed 's/^/  /'; procs
echo "== Cleanup"; touch "$ROOT/flags/allow-quit"; osascript -e 'tell application id "com.domasgru.tl021probe" to quit' >/dev/null 2>&1; sleep 1.5
pkill -f 'TLProbe.app/Contents/MacOS/TLProbe'; sleep 0.5; procs
echo; echo "== Probe log"; cat "$ROOT/log.txt"
"$LSREG" -u "$APP" 2>/dev/null; rm -rf "$ROOT"
echo; echo "cleanup: probe processes left = $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | wc -l | tr -d ' ')"
