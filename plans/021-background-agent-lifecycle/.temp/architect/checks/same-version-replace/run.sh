#!/bin/bash
# Post-fan-out check for plan 021 R3: grounding F6 showed that replacing a running bundle at the same path with a build
# of a DIFFERENT CFBundleVersion, then opening that path, starts a new process. Does the same happen when the
# replacement has the SAME CFBundleVersion (today every build is "1")?
#   R1: replace with an identical copy (same version, same executable).
#   R2: replace with a different executable carrying the same version.
# Reuses the grounding probe app. Cleans up like the grounding probe.
set -u
PROBE=/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/plans/021-background-agent-lifecycle/.temp/architect/grounding/probes/lifecycle-probe
ROOT=/tmp/tl021probe
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

rm -rf "$ROOT"; mkdir -p "$ROOT/build" "$ROOT/flags" "$ROOT/A" "$ROOT/same" "$ROOT/other"
: > "$ROOT/log.txt"
xcrun swiftc -O "$PROBE/ProbeApp.swift" -o "$ROOT/build/TLProbe" || exit 1
# A second executable that differs only by an extra symbol, so its bytes and code hash differ.
sed 's/Throwaway LSUIElement app/Throwaway LSUIElement app (variant b)/; s/^let root = /let variantMarker = "b"\nlet root = /' "$PROBE/ProbeApp.swift" > "$ROOT/build/ProbeAppB.swift"
xcrun swiftc -O "$ROOT/build/ProbeAppB.swift" -o "$ROOT/build/TLProbeB" || exit 1
cmp -s "$ROOT/build/TLProbe" "$ROOT/build/TLProbeB" && echo "WARNING: variant executable is identical"

bundle() { # dir executable
  local app="$1/TLProbe.app"; mkdir -p "$app/Contents/MacOS"
  cp "$2" "$app/Contents/MacOS/TLProbe"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.domasgru.tl021probe</string>
<key>CFBundleExecutable</key><string>TLProbe</string>
<key>CFBundleName</key><string>TLProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
  codesign --force -s - "$app" >/dev/null 2>&1
}
bundle "$ROOT/A" "$ROOT/build/TLProbe"
bundle "$ROOT/same" "$ROOT/build/TLProbe"
bundle "$ROOT/other" "$ROOT/build/TLProbeB"
procs() { echo "  processes: $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | tr '\n' ' ')"; }
stopall() { touch "$ROOT/flags/allow-quit"; osascript -e 'tell application id "com.domasgru.tl021probe" to quit' >/dev/null 2>&1; sleep 1.5; pkill -f 'TLProbe.app/Contents/MacOS/TLProbe'; sleep 0.5; rm -f "$ROOT/flags/allow-quit"; }

echo "== R1 same version, identical copy: run A, replace A with an identical copy, open A"
open "$ROOT/A/TLProbe.app"; sleep 2; procs
rm -rf "$ROOT/A/TLProbe.app"; cp -R "$ROOT/same/TLProbe.app" "$ROOT/A/"; sleep 1
open "$ROOT/A/TLProbe.app"; sleep 2.5; procs
stopall; procs

echo "== R2 same version, different executable: run A, replace A with the variant, open A"
rm -rf "$ROOT/A/TLProbe.app"; bundle "$ROOT/A" "$ROOT/build/TLProbe"
open "$ROOT/A/TLProbe.app"; sleep 2; procs
rm -rf "$ROOT/A/TLProbe.app"; cp -R "$ROOT/other/TLProbe.app" "$ROOT/A/"; sleep 1
open "$ROOT/A/TLProbe.app"; sleep 2.5; procs
stopall; procs

echo; echo "== Probe log"; cat "$ROOT/log.txt"
"$LSREG" -u "$ROOT/A/TLProbe.app" 2>/dev/null; "$LSREG" -u "$ROOT/same/TLProbe.app" 2>/dev/null; "$LSREG" -u "$ROOT/other/TLProbe.app" 2>/dev/null
rm -rf "$ROOT"
echo; echo "cleanup: probe processes left = $(pgrep -f 'TLProbe.app/Contents/MacOS/TLProbe' | wc -l | tr -d ' ')"
