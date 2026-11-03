#!/bin/sh
# Probe: the RUNNING app replaces its own bundle in place (FileManager.replaceItemAt) and then calls
# NSWorkspace.openApplication(at: <its own bundle path>).
#   Case A: default configuration.
#   Case B: createsNewApplicationInstance = true.
# Does that start a NEW process from the new bundle (version 2), or reach the running process (version 1)
# as a reopen?
# Everything lives in a temp folder; the probe apps are killed, unregistered from LaunchServices and deleted.
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(mktemp -d /tmp/tl-probe-selfrelaunch.XXXXXX)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
LOG="$DIR/log.txt"
APP="$DIR/apps/Self Probe.app"
STAGED="$DIR/stage/Self Probe.app"
BID=com.example.tl-self-relaunch-probe

swiftc -O -o "$DIR/SelfSwapApp" "$HERE/SelfSwapApp.swift" 2>&1 | grep -v warning

make_bundle() { # $1 bundle path, $2 version, $3 extra plist xml
  mkdir -p "$1/Contents/MacOS"
  cp "$DIR/SelfSwapApp" "$1/Contents/MacOS/SelfProbe"
  cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BID</string>
<key>CFBundleExecutable</key><string>SelfProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$2</string>
<key>CFBundleVersion</key><string>$2</string>
<key>LSUIElement</key><true/>
<key>ProbeLog</key><string>$LOG</string>
$3
</dict></plist>
PLIST
  codesign -s - "$1" 2>/dev/null
}

run_case() { # $1 label, $2 ProbeNewInstance plist bool (<true/> or <false/>)
  pkill -f "Self Probe.app/Contents/MacOS/SelfProbe" 2>/dev/null
  sleep 1
  rm -rf "$DIR/apps" "$DIR/stage"; : > "$LOG"
  make_bundle "$STAGED" 2 ""
  make_bundle "$APP" 1 "<key>ProbeSelfSwapFrom</key><string>$STAGED</string><key>ProbeNewInstance</key>$2"
  open "$APP"
  sleep 5
  echo "== $1: log"
  cat "$LOG"
  echo "== $1: probe processes running"
  pgrep -fl "SelfProbe" | sed 's/^/  /'
}

run_case "A (default configuration)" "<false/>"
run_case "B (createsNewApplicationInstance = true)" "<true/>"

pkill -f "Self Probe.app/Contents/MacOS/SelfProbe" 2>/dev/null
sleep 1
"$LSREGISTER" -u "$APP" 2>/dev/null
rm -rf "$DIR"
echo "cleaned up"
