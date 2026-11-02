#!/bin/sh
# Post-fan-out checks for the synthesis, using a copy of /Applications/Shottr.app (notarised, stapled).
# (1) AppleArchive extracts from memory; the unpacked copy still verifies.
# (2) The selection hook's .cancel aborts the extraction part-way (what is left on disk is reported).
# Everything temporary is deleted.
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(mktemp -d /tmp/tl-checks.XXXXXX)
mkdir -p "$DIR/src" "$DIR/out" "$DIR/out2"
ditto /Applications/Shottr.app "$DIR/src/Shottr.app"
aa archive -d "$DIR/src" -subdir Shottr.app -exclude-field uid,gid,xat,acl,flg -o "$DIR/Shottr.aar"
swiftc -O -o "$DIR/aar-from-memory" "$HERE/aar-from-memory.swift" 2>&1 | grep -v warning
echo "== (1) extract from memory"
"$DIR/aar-from-memory" "$DIR/Shottr.aar" "$DIR/out"
codesign --verify --strict --deep "$DIR/out/Shottr.app" && echo "unpacked from memory: codesign --verify --strict --deep ok"
xcrun stapler validate "$DIR/out/Shottr.app" 2>&1 | tail -1
echo "xattrs on bundle root (archived with -exclude-field xat): [$(xattr "$DIR/out/Shottr.app" | tr '\n' ' ')]"
swift "$HERE/../grounding/probes/codesign-requirement.swift" "$DIR/out/Shottr.app" | head -3
echo "== (2) the hook refuses Contents/Info.plist with .cancel"
"$DIR/aar-from-memory" "$DIR/Shottr.aar" "$DIR/out2" "Contents/Info.plist"
echo "items written before the stop: $(find "$DIR/out2" | wc -l | tr -d ' ')"
rm -rf "$DIR"
echo cleaned up
