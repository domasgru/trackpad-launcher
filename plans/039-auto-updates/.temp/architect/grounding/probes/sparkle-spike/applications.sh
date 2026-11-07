#!/bin/sh
# The self-quit path once more, from /Applications, with the archive's download going through
# a local 302 to a second path, the way github.com redirects to release-assets.
# Removes only /Applications/SpikeHost.app, which this script created.
seconds=${1:-12}
spike=/tmp/039-sparkle/spike
run=$spike/run
home=/Users/dominykasgrubys
app=/Applications/SpikeHost.app
id=com.domasgru.sparklespike
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pkill -x SpikeHost 2>/dev/null
launchctl remove $id-sparkle-updater 2>/dev/null
launchctl remove $id-sparkle-progress 2>/dev/null
rm -rf "$app" "$home/Library/Caches/$id" "$home/Library/HTTPStorages/$id" "$home/Library/HTTPStorages/$id.binarycookies"
defaults delete $id 2>/dev/null
rm -f "$run/host.log" "$run/relauncher.log" "$run/requests.log"
printf %s selfquit > "$run/mode"
/usr/bin/ditto "$spike/build/v1/SpikeHost.app" "$app"
"$lsregister" -f "$app"

/usr/bin/python3 -I -B "$spike/server-redirect.py" "$spike/feed" "$run/requests.log" 8765 &
server=$!
sleep 0.5
/usr/bin/open -g -j "$app"
sleep "$seconds"

echo "=== host.log"; cat "$run/host.log"
echo "=== relauncher.log"; cat "$run/relauncher.log"
echo "=== installed"; /usr/bin/plutil -extract CFBundleVersion raw -o - "$app/Contents/Info.plist"; echo
ls -ld "$app"
echo "=== running"; pgrep -fl 'SpikeHost|Sparkle.framework' | grep -v applications.sh | cut -c1-120
echo "=== requests"; cat "$run/requests.log"
echo "=== sparkle log"; log show --last "$((seconds + 5))s" --style compact --predicate 'subsystem == "org.sparkle-project.Sparkle" or process == "tccd" and eventMessage contains "SpikeHost"' 2>/dev/null | grep -v '^Timestamp' | cut -c1-180 | tail -10

kill $server 2>/dev/null
pkill -x SpikeHost 2>/dev/null
sleep 0.3
"$lsregister" -u "$app"
rm -rf "$app"
ls -d "$app" 2>&1 | tail -1
exit 0
