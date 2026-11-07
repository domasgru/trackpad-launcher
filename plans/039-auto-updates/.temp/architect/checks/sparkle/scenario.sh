#!/bin/sh
# Runs one scenario from a clean state: installs version 1, starts it, watches for a
# fixed time, then prints the host log, the relauncher log, the frontmost-app transitions,
# what lies at the install path and what still runs.
#   scenario.sh <mode> <seconds> [start command: open | opengj]
mode=$1
seconds=$2
start=${3:-open}
spike=/tmp/039-sparkle/spike
run=$spike/run
home=/Users/dominykasgrubys
install=$spike/install
id=com.domasgru.sparklespike

pkill -x SpikeHost 2>/dev/null
launchctl remove $id-sparkle-updater 2>/dev/null
launchctl remove $id-sparkle-progress 2>/dev/null
launchctl remove $id.relaunch 2>/dev/null
chmod 755 "$install" 2>/dev/null
rm -rf "$install" "$home/Library/Caches/$id" "$home/Library/HTTPStorages/$id" "$home/Library/HTTPStorages/$id.binarycookies" "$home/Library/Preferences/$id.plist"
defaults delete $id 2>/dev/null
mkdir -p "$install" "$run"
rm -f "$run/host.log" "$run/relauncher.log" "$run/requests.log"
printf %s "$mode" > "$run/mode"
/usr/bin/ditto "$spike/build/v1/SpikeHost.app" "$install/SpikeHost.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$install/SpikeHost.app"

/usr/bin/python3 -I -B "$spike/server.py" "$spike/feed" "$run/requests.log" 8765 &
server=$!
sleep 0.5

( end=$(( $(date +%s) + seconds + 1 )); last=""
  while [ "$(date +%s)" -lt "$end" ]; do
    now=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | tr -d '"' | sed 's/LSDisplayName=//')
    if [ "$now" != "$last" ]; then echo "$(date +%H:%M:%S) front: $now" >> "$run/front.log"; last=$now; fi
    sleep 0.1
  done ) &
watcher=$!
rm -f "$run/front.log"

case $start in
  open) /usr/bin/open "$install/SpikeHost.app" ;;
  opengj) /usr/bin/open -g -j "$install/SpikeHost.app" ;;
esac
sleep "$seconds"

echo "=== host.log"; cat "$run/host.log" 2>/dev/null
echo "=== relauncher.log"; cat "$run/relauncher.log" 2>/dev/null
echo "=== front.log"; cat "$run/front.log" 2>/dev/null
echo "=== installed version"; /usr/bin/plutil -extract CFBundleVersion raw -o - "$install/SpikeHost.app/Contents/Info.plist"; echo
echo "=== running"; pgrep -fl 'SpikeHost|Sparkle.framework|sparklespike' | grep -v scenario | cut -c1-150
echo "=== launchd jobs"; launchctl list | grep sparklespike
echo "=== cache"; find "$home/Library/Caches/$id" -maxdepth 4 2>/dev/null | sed "s|$home|~|" | head -12
echo "=== requests"; cat "$run/requests.log" 2>/dev/null; echo "=== sparkle log"; log show --last "$((seconds + 5))s" --style compact --predicate 'subsystem == "org.sparkle-project.Sparkle"' 2>/dev/null | grep -v '^Timestamp' | cut -c1-200 | tail -14

kill $server 2>/dev/null
wait $watcher 2>/dev/null
pkill -x SpikeHost 2>/dev/null
chmod 755 "$install" 2>/dev/null
exit 0
