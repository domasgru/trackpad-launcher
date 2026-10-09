#!/bin/zsh
# Builds a throwaway TLProbeTarget.app in a temp dir, runs the driver against it, removes everything.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d /tmp/tlprobe.XXXXXX)"
APP="$TMP/TLProbeTarget.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TLProbeTarget</string>
<key>CFBundleIdentifier</key><string>com.trackpadlauncher.probe.target</string>
<key>CFBundleName</key><string>TLProbeTarget</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF
swiftc -O -o "$APP/Contents/MacOS/TLProbeTarget" "$HERE/target.swift"
swiftc -O -o "$TMP/driver" "$HERE/driver.swift"
LOG="$TMP/target.log"
# The target inherits TLPROBE_LOG via LaunchServices? No: LS launches with its own env. Use a fixed path instead.
export TLPROBE_LOG="/tmp/tlprobe-target.log"; rm -f "$TLPROBE_LOG"
# Write the fixed path into the target by env file: simplest is to rely on the default path in target.swift.
"$TMP/driver" "$APP" "$TLPROBE_LOG"
# Cleanup: unregister from LaunchServices and remove the bundle.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" >/dev/null 2>&1 || true
rm -rf "$TMP" "$TLPROBE_LOG"
echo "cleanup done: $(ls "$TMP" 2>&1 | head -1)"
