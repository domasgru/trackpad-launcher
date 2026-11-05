#!/bin/bash
# Reproduces the update hand-over against a real app bundle: an old copy is resident, a new copy starts as a new
# instance (as ApplicationsUpdater.openNewVersion does), and the old copy ends while the new one starts.
#
# usage: repro.sh <path to app built with its own bundle identifier> <rounds> <ending>
#   ending = after-open   the old copy gets SIGTERM right after `open` returns, as Lifecycle.replaced() ends it
#   ending = stopped      nothing ends the old copy but the new copy's own stop()
#
# Build the app under its own identifier: a copy force-terminates every copy of its identifier family, so a build
# with the real identifier would kill the installed app.
set -u
app="$1"; rounds="$2"; ending="$3"
binary="$app/Contents/MacOS/Trackpad Launcher"
alive=0; dead=0

clear_copies() {
    pkill -9 -f "$binary" 2>/dev/null
    sleep 0.5
}

clear_copies
for round in $(seq 1 "$rounds"); do
    open -g -n "$app"
    sleep 1.5
    old=$(pgrep -f "$binary" | head -1)
    open -g -n "$app"
    [ "$ending" = after-open ] && kill -TERM "$old" 2>/dev/null
    sleep 1.5
    survivors=$(pgrep -f "$binary" | grep -v -x "$old" | wc -l | tr -d ' ')
    if [ "$survivors" -ge 1 ]; then alive=$((alive + 1)); result=alive; else dead=$((dead + 1)); result=DEAD; fi
    echo "round $round: new copy $result"
    clear_copies
done
echo "ending=$ending rounds=$rounds new-copy-alive=$alive new-copy-dead=$dead"
