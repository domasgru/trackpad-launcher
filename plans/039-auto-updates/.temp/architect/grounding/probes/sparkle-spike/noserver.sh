#!/bin/sh
# What a failed check looks like to the delegate: nothing listens on the feed's port.
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
printf %s hold > "$run/mode"
/usr/bin/ditto "$spike/build/v1/SpikeHost.app" "$install/SpikeHost.app"
/usr/bin/open -g -j "$install/SpikeHost.app"
sleep 4
cut -c1-200 "$run/host.log"
pkill -x SpikeHost 2>/dev/null
exit 0
