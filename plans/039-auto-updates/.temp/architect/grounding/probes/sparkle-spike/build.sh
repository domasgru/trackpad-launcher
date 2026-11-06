#!/bin/sh
# Builds spike bundles version 1 and 2 with Sparkle 2.10.1 embedded, signs them inside-out
# with the Apple Development identity (hardened runtime, one team across host and helpers),
# packs version 2 as an Apple Archive and signs that with a throwaway EdDSA key.
set -eu
probe=$(cd "$(dirname "$0")" && pwd)
spike=/tmp/039-sparkle/spike
fw=/tmp/039-sparkle/spm/extracted/Sparkle.xcframework/macos-arm64_x86_64
bin=/tmp/039-sparkle/spm/extracted/bin
identity="Apple Development"

rm -rf "$spike/build" "$spike/feed"
mkdir -p "$spike/build" "$spike/feed" "$spike/run"; cp "$probe/server.py" "$spike/server.py"

[ -f "$spike/ed.key" ] || swift "$probe/keygen.swift" "$spike"
public=$(cat "$spike/ed.pub")

swiftc -swift-version 5 -O -parse-as-library -F "$fw" -framework Sparkle -framework AppKit -framework ServiceManagement \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "$probe/SpikeHost.swift" -o "$spike/build/SpikeHost"

bundle() {
  version=$1
  app="$spike/build/v$version/SpikeHost.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
  cp "$spike/build/SpikeHost" "$app/Contents/MacOS/SpikeHost"
  /usr/bin/ditto "$fw/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
  rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.domasgru.sparklespike</string>
<key>CFBundleName</key><string>SpikeHost</string>
<key>CFBundleExecutable</key><string>SpikeHost</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleShortVersionString</key><string>$version.0</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
<key>SUFeedURL</key><string>http://127.0.0.1:8765/appcast.xml</string>
<key>SUPublicEDKey</key><string>$public</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAutomaticallyUpdate</key><true/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
</dict></plist>
PLIST
  f="$app/Contents/Frameworks/Sparkle.framework"
  codesign -f -s "$identity" -o runtime --timestamp=none "$f/Versions/B/Autoupdate"
  codesign -f -s "$identity" -o runtime --timestamp=none "$f/Versions/B/Updater.app"
  codesign -f -s "$identity" -o runtime --timestamp=none "$f"
  codesign -f -s "$identity" -o runtime --timestamp=none "$app"
  codesign --verify --strict --deep "$app"
}

bundle 1
bundle 2

aa archive -d "$spike/build/v2" -o "$spike/feed/SpikeHost-2.aar" -exclude-field xat
signature=$("$bin/sign_update" --ed-key-file "$spike/ed.key" "$spike/feed/SpikeHost-2.aar")
cat > "$spike/feed/appcast.xml" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
<channel><title>Spike</title>
<item>
<title>2.0</title>
<sparkle:version>2</sparkle:version>
<sparkle:shortVersionString>2.0</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
<pubDate>Fri, 06 Nov 2026 12:00:00 +0000</pubDate>
<enclosure url="http://127.0.0.1:8765/SpikeHost-2.aar" $signature type="application/octet-stream"/>
</item>
</channel></rss>
XML
ls -la "$spike/feed"
aa list -i "$spike/feed/SpikeHost-2.aar" | head -5
cat "$spike/feed/appcast.xml" | grep enclosure
