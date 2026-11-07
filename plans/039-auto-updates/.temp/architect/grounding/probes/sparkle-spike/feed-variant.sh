#!/bin/sh
# Replaces the spike's feed with a variant. build.sh restores the plain one.
#   feed-variant.sh renamed   the archive holds the bundle as TrackpadLauncher.app, with the host's identifier
#   feed-variant.sh github    the enclosure is a real release asset, through github.com's real redirect
set -eu
spike=/tmp/039-sparkle/spike
bin=/tmp/039-sparkle/spm/extracted/bin

write_feed() {
  url=$1
  signature=$2
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
<enclosure url="$url" $signature type="application/octet-stream"/>
</item>
</channel></rss>
XML
}

case $1 in
  renamed)
    rm -rf "$spike/build/renamed"
    mkdir -p "$spike/build/renamed"
    /usr/bin/ditto "$spike/build/v2/SpikeHost.app" "$spike/build/renamed/TrackpadLauncher.app"
    aa archive -d "$spike/build/renamed" -o "$spike/feed/Renamed-2.aar" -exclude-field uid,gid,xat,acl,flg
    write_feed "http://127.0.0.1:8765/Renamed-2.aar" "$("$bin/sign_update" --ed-key-file "$spike/ed.key" "$spike/feed/Renamed-2.aar")"
    ;;
  github)
    url=https://github.com/domasgru/trackpad-launcher/releases/download/v1.0.15/TrackpadLauncher-1.0.15-macOS-26.0.aar
    curl -sSL -m 120 -o "$spike/github.aar" "$url"
    write_feed "$url" "$("$bin/sign_update" --ed-key-file "$spike/ed.key" "$spike/github.aar")"
    ;;
esac
grep enclosure "$spike/feed/appcast.xml" | cut -c1-110
