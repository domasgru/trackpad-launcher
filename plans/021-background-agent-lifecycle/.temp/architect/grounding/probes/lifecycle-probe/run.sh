#!/bin/bash
# Plan 021 lifecycle probe. Builds a throwaway LSUIElement app (com.domasgru.tl021probe) under /tmp/tl021probe,
# runs the experiments below, prints the probe's own log, and cleans up: processes quit, LaunchServices
# registrations removed, /tmp/tl021probe deleted, Calculator quit only if this script launched it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=/tmp/tl021probe
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

rm -rf "$ROOT"; mkdir -p "$ROOT/build" "$ROOT/flags" "$ROOT/A" "$ROOT/B" "$ROOT/v2"
: > "$ROOT/log.txt"
CALC_WAS_RUNNING=0; pgrep -x Calculator >/dev/null && CALC_WAS_RUNNING=1

xcrun swiftc -O "$HERE/ProbeApp.swift" -o "$ROOT/build/TLProbe" || exit 1
xcrun swiftc -O "$HERE/terminator.swift" -o "$ROOT/build/terminator" || exit 1

bundle() { # dir version
  local app="$1/TLProbe.app"; mkdir -p "$app/Contents/MacOS"
  cp "$ROOT/build/TLProbe" "$app/Contents/MacOS/TLProbe"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.domasgru.tl021probe</string>
<key>CFBundleExecutable</key><string>TLProbe</string>
<key>CFBundleName</key><string>TLProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$2</string>
<key>CFBundleVersion</key><string>$2</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
  codesign --force -s - "$app" >/dev/null 2>&1
}
bundle "$ROOT/A" 1
bundle "$ROOT/v2" 2

procs() { echo "  processes: $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | tr '\n' ' ')"; }
apptype() { for p in $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe'); do echo "  pid $p $(lsappinfo info -only ApplicationType "$(lsappinfo find pid=$p)" 2>/dev/null)"; done; }
step() { echo; echo "== $1"; }

step "E1 open A (not running): launch event, policy, LaunchServices type"
open "$ROOT/A/TLProbe.app"; sleep 2; procs; apptype

step "E2 open A again while it runs (same path): reopen? second process? window, activation, type after .regular"
open "$ROOT/A/TLProbe.app"; sleep 2; procs; apptype

step "E3 close the window through a reopen with the close flag: type after .accessory"
touch "$ROOT/flags/close"; open "$ROOT/A/TLProbe.app"; sleep 2; rm "$ROOT/flags/close"; procs; apptype

step "E4 copy the same build to B and open B while A runs (same build, other place)"
cp -R "$ROOT/A/TLProbe.app" "$ROOT/B/"; open "$ROOT/B/TLProbe.app"; sleep 2; procs

step "E5 quit Apple event from osascript (stands in for the Dock's Quit) to every copy: cancelled?"
osascript -e 'tell application id "com.domasgru.tl021probe" to quit' 2>&1 | sed 's/^/  osascript: /'; sleep 1; procs

step "E6 NSRunningApplication.terminate() from another process (as a newer copy would): sender, reason, outcome"
"$ROOT/build/terminator" | sed 's/^/  /'; procs

step "E7 bring another app (Calculator) to front while the probe is active with its window key"
pkill -f "$ROOT/B/TLProbe.app/Contents/MacOS/TLProbe"; sleep 1
touch "$ROOT/flags/bring"; open "$ROOT/A/TLProbe.app"; sleep 4; rm "$ROOT/flags/bring"; procs

step "E8 replace A in place with build v2 while v1 runs (rm + copy, like Finder's Replace), then open A"
touch "$ROOT/flags/close"; open "$ROOT/A/TLProbe.app"; sleep 1.5; rm "$ROOT/flags/close"
rm -rf "$ROOT/A/TLProbe.app"; cp -R "$ROOT/v2/TLProbe.app" "$ROOT/A/"; sleep 1
open "$ROOT/A/TLProbe.app"; sleep 2.5; procs; apptype

step "Cleanup"
touch "$ROOT/flags/allow-quit"
osascript -e 'tell application id "com.domasgru.tl021probe" to quit' >/dev/null 2>&1; sleep 1.5
pkill -f 'TLProbe.app/Contents/MacOS/TLProbe'; sleep 0.5; procs
[ "$CALC_WAS_RUNNING" = 0 ] && osascript -e 'tell application id "com.apple.calculator" to quit' >/dev/null 2>&1

echo; echo "== Probe log (/tmp/tl021probe/log.txt)"; cat "$ROOT/log.txt"

"$LSREG" -u "$ROOT/A/TLProbe.app" 2>/dev/null; "$LSREG" -u "$ROOT/B/TLProbe.app" 2>/dev/null; "$LSREG" -u "$ROOT/v2/TLProbe.app" 2>/dev/null
rm -rf "$ROOT"
echo; echo "cleanup: probe processes left = $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | wc -l | tr -d ' '), Calculator running = $(pgrep -x Calculator >/dev/null && echo yes || echo no) (was $CALC_WAS_RUNNING)"
