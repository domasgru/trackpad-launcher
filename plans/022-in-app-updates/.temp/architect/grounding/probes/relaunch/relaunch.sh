#!/bin/sh
# Probe: after a running app's bundle is replaced in place (FileManager.replaceItemAt, as BundleInstall.swap
# does), what does NSWorkspace.openApplication(at: <same path>) do?
#   Case A: default configuration (as ApplicationsInstaller.openInstalledCopy does today).
#   Case B: createsNewApplicationInstance = true.
# For each case: does a NEW process start from the new bundle (version 2), or does the old process (version 1)
# just receive a reopen event?
# Everything lives in a temp folder; the probe apps are killed, unregistered from LaunchServices and deleted.
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(mktemp -d /tmp/tl-probe-relaunch.XXXXXX)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
LOG="$DIR/log.txt"
APP="$DIR/apps/Relaunch Probe.app"
BID=com.example.tl-relaunch-probe

swiftc -O -o "$DIR/ProbeApp" "$HERE/ProbeApp.swift" 2>&1 | grep -v warning
swiftc -O -o "$DIR/tool" "$HERE/open-and-swap.swift" 2>&1 | grep -v warning

make_bundle() { # $1 bundle path, $2 version
  mkdir -p "$1/Contents/MacOS"
  cp "$DIR/ProbeApp" "$1/Contents/MacOS/RelaunchProbe"
  cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BID</string>
<key>CFBundleExecutable</key><string>RelaunchProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$2</string>
<key>CFBundleVersion</key><string>$2</string>
<key>LSUIElement</key><true/>
<key>ProbeLog</key><string>$LOG</string>
</dict></plist>
PLIST
  codesign -s - "$1" 2>/dev/null
}

run_case() { # $1 label, $2 createsNewApplicationInstance 0|1
  pkill -f "Relaunch Probe.app/Contents/MacOS/RelaunchProbe" 2>/dev/null
  rm -rf "$DIR/apps" "$DIR/stage"; : > "$LOG"
  make_bundle "$APP" 1
  make_bundle "$DIR/stage/Relaunch Probe.app" 2
  "$DIR/tool" open "$APP" 0
  sleep 2
  "$DIR/tool" swap "$APP" "$DIR/stage/Relaunch Probe.app"
  echo "after swap, Info.plist version on disk: $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
  "$DIR/tool" open "$APP" "$2"
  sleep 3
  echo "== $1: log"
  cat "$LOG"
  echo "== $1: probe processes running"
  pgrep -fl "RelaunchProbe" | sed 's/^/  /'
}

run_case "A (default configuration)" 0
run_case "B (createsNewApplicationInstance = true)" 1

pkill -f "Relaunch Probe.app/Contents/MacOS/RelaunchProbe" 2>/dev/null
sleep 1
"$LSREGISTER" -u "$APP" 2>/dev/null
rm -rf "$DIR"
echo "cleaned up $DIR"
