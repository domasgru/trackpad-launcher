#!/bin/sh
# Leaves the Mac as the spike found it. Keeps /tmp/039-sparkle/src, site and spm for the arena.
home=/Users/dominykasgrubys
id=com.domasgru.sparklespike
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pkill -x SpikeHost 2>/dev/null
launchctl remove $id-sparkle-updater 2>/dev/null
launchctl remove $id-sparkle-progress 2>/dev/null
launchctl remove $id.relaunch 2>/dev/null
chmod 755 /tmp/039-sparkle/spike/install 2>/dev/null
"$lsregister" -u /tmp/039-sparkle/spike/install/SpikeHost.app 2>/dev/null
rm -rf /tmp/039-sparkle/spike/install /tmp/039-sparkle/spike/build /tmp/039-sparkle/spike/feed
rm -rf "$home/Library/Caches/$id" "$home/Library/HTTPStorages/$id" "$home/Library/HTTPStorages/$id.binarycookies"
defaults delete $id 2>/dev/null
rm -f "$home/Library/Preferences/$id.plist"
ls -d /Applications/SpikeHost.app "$home/Library/Caches/$id" "$home/Library/HTTPStorages/$id" 2>&1 | grep -v 'No such'
pgrep -fl 'SpikeHost|sparklespike' | grep -v cleanup.sh
launchctl list | grep sparklespike
echo clean
