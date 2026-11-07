#!/bin/sh
# A failed check, nothing listening on the feed's port, then a check remembered and fired from
# willScheduleUpdateCheckAfterDelay. Does the second cycle run, and is the 24-hour timer re-armed?
spike=/tmp/039-sparkle/spike
run=$spike/run
home=/Users/dominykasgrubys
install=$spike/install
id=com.domasgru.sparklespike

pkill -x SpikeHost 2>/dev/null
chmod 755 "$install" 2>/dev/null
rm -rf "$install" "$home/Library/Caches/$id"
defaults delete $id 2>/dev/null
mkdir -p "$install"
rm -f "$run/host.log"
printf %s pendingcheck > "$run/mode"
/usr/bin/ditto "$spike/build/v1/SpikeHost.app" "$install/SpikeHost.app"
/usr/bin/open -g -j "$install/SpikeHost.app"
sleep 5
cut -c1-180 "$run/host.log"
pkill -x SpikeHost 2>/dev/null
exit 0
