#!/bin/bash
# The final check: the whole suite through the repo's own script, normally and throttled.
# Usage: final.sh <normal runs> <throttled runs> <label>
set -u
normal=$1
throttled=$2
label=$3
logs=/tmp/launcherkit-repeat/$label
mkdir -p "$logs"
failed=0
check() {
    if [ "$2" -ne 0 ]; then failed=$((failed + 1)); fi
    echo "$1: exit $2"
    grep -E 'recorded an issue|Timed out|pid [0-9]+: gone' "$3" | cut -c1-200 | sed 's/^/    /'
}
for run in $(seq 1 "$normal"); do
    bash Scripts/test.sh > "$logs/normal-$run.log" 2>&1
    check "normal $run" $? "$logs/normal-$run.log"
done
for run in $(seq 1 "$throttled"); do
    taskpolicy -b bash Scripts/test.sh > "$logs/throttled-$run.log" 2>&1
    check "throttled $run" $? "$logs/throttled-$run.log"
done
echo "$label: $failed of $((normal + throttled)) runs failed"
