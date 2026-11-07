#!/bin/sh
# Plan 038 left this to the automatic-updates plan: a silent new copy never opens a window, so it
# stays a UI element without one. The old copy here was a regular app with a window, then an
# accessory with that window closed, which is R8's normal state. Watch the new copy for two minutes
# and read what loginwindow said about it.
probe=$(cd "$(dirname "$0")" && pwd)
sh "$probe/build.sh" > /dev/null 2>&1
sh "$probe/scenario.sh" windowquit 130 opengj
echo "=== loginwindow on SpikeHost"
log show --last 3m --style compact --predicate 'process == "loginwindow" and eventMessage contains "SpikeHost"' 2>/dev/null | grep -v '^Timestamp' | cut -c1-200 | tail -20
