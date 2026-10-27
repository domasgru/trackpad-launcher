#!/bin/bash
# Builds check.swift into /tmp, signs it ad hoc, and checks Developer ID apps on this Mac, the installed and the
# Xcode-run Trackpad Launcher (Apple Development), and itself (ad hoc). Removes /tmp/tl021sig afterwards.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
rm -rf /tmp/tl021sig; mkdir -p /tmp/tl021sig
xcrun swiftc -O "$HERE/check.swift" -o /tmp/tl021sig/check || exit 1
codesign --force -s - /tmp/tl021sig/check
DD=$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/TrackpadLauncher-*/Build/Products/Debug/TrackpadLauncher.app 2>/dev/null | head -1)
/tmp/tl021sig/check /Applications/Ghostty.app "/Applications/Visual Studio Code.app" /Applications/TrackpadLauncher.app "$DD" /tmp/tl021sig/check
rm -rf /tmp/tl021sig
