#!/bin/sh
# Probe: which release-asset formats keep a notarised, stapled Developer ID app whole through
# pack -> download -> unpack, so that R8's checks pass on the unpacked copy?
#   (1) zip made with `ditto -c -k --keepParent` (what release.sh already makes for notarytool),
#       unpacked with `ditto -x -k` (a child process);
#   (2) Apple Archive made with `aa archive`, unpacked in-process with the AppleArchive framework.
# Subject: a copy of /Applications/Shottr.app (Developer ID, notarised, stapled, 6.6 MB).
# Checks on each unpacked copy: the codesign-requirement.swift requirements (team, identifier, notarized),
# `codesign --verify --strict --deep`, `stapler validate`, and the extended attributes on the bundle root.
# Everything happens in a temp folder that is deleted afterwards.
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(mktemp -d /tmp/tl-probe-archive.XXXXXX)
mkdir -p "$DIR/src" "$DIR/zip-out" "$DIR/aar-out"
ditto /Applications/Shottr.app "$DIR/src/Shottr.app"

echo "== (1) zip via ditto"
ditto -c -k --keepParent "$DIR/src/Shottr.app" "$DIR/Shottr.zip"
ls -l "$DIR/Shottr.zip" | awk '{print "zip bytes:", $5}'
ditto -x -k "$DIR/Shottr.zip" "$DIR/zip-out"
codesign --verify --strict --deep "$DIR/zip-out/Shottr.app" && echo "codesign --verify --strict --deep: ok"
xcrun stapler validate "$DIR/zip-out/Shottr.app" 2>&1 | tail -1
echo "xattrs on bundle root: $(xattr "$DIR/zip-out/Shottr.app" | tr '\n' ' ')"

echo "== (2) Apple Archive via aa + AppleArchive framework"
aa archive -d "$DIR/src" -subdir Shottr.app -o "$DIR/Shottr.aar"
ls -l "$DIR/Shottr.aar" | awk '{print "aar bytes:", $5}'
swiftc -O -o "$DIR/extract-aar" "$HERE/extract-aar.swift" 2>&1 | grep -v warning
"$DIR/extract-aar" "$DIR/Shottr.aar" "$DIR/aar-out"
codesign --verify --strict --deep "$DIR/aar-out/Shottr.app" && echo "codesign --verify --strict --deep: ok"
xcrun stapler validate "$DIR/aar-out/Shottr.app" 2>&1 | tail -1
echo "xattrs on bundle root: $(xattr "$DIR/aar-out/Shottr.app" | tr '\n' ' ')"

echo "== requirement checks on both unpacked copies"
swift "$HERE/../codesign-requirement.swift" "$DIR/zip-out/Shottr.app" "$DIR/aar-out/Shottr.app"
rm -rf "$DIR"
echo "cleaned up"
