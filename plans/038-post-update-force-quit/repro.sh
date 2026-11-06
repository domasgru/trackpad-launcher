#!/bin/bash
# Reproduces the update hand-over end to end: an old copy opens the real app as a new instance, exactly as
# ApplicationsUpdater.openNewVersion does, and ends, exactly as Lifecycle.replaced does. Then it watches the new copy
# for longer than the 3 seconds loginwindow waits, and reads loginwindow's own verdict from the system log.
#
# usage: repro.sh <new version's bundle> <rounds> [parent's Info.plist]
#   REPRO_WAIT overrides the seconds a round watches the new copy, 11 by default.
#   The new version must be built under its own bundle identifier: a copy force-terminates every copy of its identifier
#   family, so the real identifier would kill the installed app.
#   The old copy gets the new version's Info.plist unless another is given: pass a released version's to reproduce an
#   update from that version.
#
# A round counts as alive only when, once the watch ends, the new copy still runs and is type="Foreground"
# (its settings window opened: the resident was built) and loginwindow never scheduled it for termination.
set -u
new="$1"; rounds="$2"; here="$(cd "$(dirname "$0")" && pwd)"
parent_plist="${3:-$new/Contents/Info.plist}"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
binary="$new/Contents/MacOS/Trackpad Launcher"
work="$(mktemp -d /tmp/tl-handover.XXXXXX)"
old="$work/Old Copy.app"
mkdir -p "$old/Contents/MacOS"
cp "$parent_plist" "$old/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable old-copy" "$old/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$new/Contents/Info.plist")" "$old/Contents/Info.plist"
xcrun swiftc -O "$here/old-copy.swift" -o "$old/Contents/MacOS/old-copy" || exit 2
codesign -f -s - "$old" 2>/dev/null
echo "new version sudden termination: $(/usr/libexec/PlistBuddy -c 'Print :NSSupportsSuddenTermination' "$new/Contents/Info.plist" 2>&1 | tail -1)"
echo "old copy sudden termination:    $(/usr/libexec/PlistBuddy -c 'Print :NSSupportsSuddenTermination' "$old/Contents/Info.plist" 2>&1 | tail -1)"

clear_copies() {
    pkill -9 -f "$binary" 2>/dev/null
    pkill -9 -f "$old/Contents/MacOS/old-copy" 2>/dev/null
    sleep 0.5
}

alive=0; dead=0
clear_copies
for round in $(seq 1 "$rounds"); do
    start=$(date "+%Y-%m-%d %H:%M:%S")
    open -n "$old" --args "$new"
    sleep "${REPRO_WAIT:-11}"
    pid=$(pgrep -f "$binary" | head -1)
    foreground=no
    if [ -n "$pid" ] && lsappinfo info -pid "$pid" 2>/dev/null | grep -q 'type="Foreground"'; then foreground=yes; fi
    scheduled=$(/usr/bin/log show --start "$start" --style compact --info --debug \
        --predicate 'process == "loginwindow" AND category == "quitsupport" AND composedMessage CONTAINS "terminateAppIf"' 2>/dev/null \
        | grep -c "terminating all subordinate")
    if [ -n "$pid" ] && [ "$foreground" = yes ] && [ "$scheduled" = 0 ]; then alive=$((alive + 1)); result=alive; else dead=$((dead + 1)); result=DEAD; fi
    echo "round $round: new copy $result (pid: ${pid:-none}, foreground: $foreground, loginwindow scheduled its termination: $scheduled)"
    clear_copies
done
rm -rf "$work"
echo "rounds=$rounds new-copy-alive=$alive new-copy-dead=$dead"
