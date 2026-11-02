#!/bin/sh
# Runs AfterSwapApp: v1 swaps v2 into its own place and keeps running without opening it. Cleans up after itself.
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(mktemp -d /tmp/tl-check-afterswap.XXXXXX)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
LOG="$DIR/log.txt"; : > "$LOG"
APP="$DIR/apps/After Swap.app"
STAGED="$DIR/stage/After Swap.app"
swiftc -O -o "$DIR/AfterSwapApp" "$HERE/AfterSwapApp.swift" 2>&1 | grep -v warning

make_bundle() { # $1 path, $2 version, $3 extra plist xml
  mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources"
  cp "$DIR/AfterSwapApp" "$1/Contents/MacOS/AfterSwap"
  echo "$2" > "$1/Contents/Resources/marker.txt"
  cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.example.tl-after-swap-check</string>
<key>CFBundleExecutable</key><string>AfterSwap</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$2</string>
<key>LSUIElement</key><true/>
<key>ProbeLog</key><string>$LOG</string>
$3
</dict></plist>
PLIST
}
make_bundle "$STAGED" v2 ""
make_bundle "$APP" v1 "<key>ProbeSelfSwapFrom</key><string>$STAGED</string>"
echo v1-only > "$APP/Contents/Resources/only-in-v1.txt"
codesign -s - "$STAGED" 2>/dev/null; codesign -s - "$APP" 2>/dev/null
open "$APP"
sleep 6
cat "$LOG"
echo "running now: $(pgrep -f 'After Swap.app/Contents/MacOS/AfterSwap' | wc -l | tr -d ' ') process(es)"
pkill -f "After Swap.app/Contents/MacOS/AfterSwap" 2>/dev/null
sleep 1
"$LSREGISTER" -u "$APP" 2>/dev/null
rm -rf "$DIR"
echo cleaned up
