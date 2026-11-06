#!/bin/bash
# Does the suite fail when the whole test process tree is slow? Background policy throttles its CPU and I/O, which is how
# the failing run looked: even the pure UI tests took five times as long.
# Usage: throttled.sh <runs> <label> [extra swift test arguments...]
set -u
runs=$1
label=$2
shift 2
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
logs=/tmp/launcherkit-repeat/$label
mkdir -p "$logs"
failed=0
for run in $(seq 1 "$runs"); do
    log=$logs/$run.log
    taskpolicy -b swift test --package-path LauncherKit --skip-build "$@" > "$log" 2>&1
    code=$?
    if [ "$code" -ne 0 ]; then failed=$((failed + 1)); fi
    echo "$label run $run: exit $code"
    grep -E 'Test theEarlierLaunchDateComesFirst\(\) passed|Test run with' "$log" | sed 's/^/    /'
    grep -E 'recorded an issue|Timed out|pid [0-9]+: gone' "$log" | sed 's/^/    /'
done
echo "$label: $failed of $runs runs failed"
