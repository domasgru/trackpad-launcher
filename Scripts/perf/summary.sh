#!/bin/bash
# Per-frame cost of each sampler TSV (see docs/performance.md): CPU over the seconds in which the trackpads
# delivered frames, divided by those frames, and that CPU as a share of one core.
# Usage: Scripts/perf/summary.sh <tsv>...
for f in "$@"; do
  awk -F'\t' -v name="$(basename "$f" .tsv)" '
    NR > 1 && $1 !~ /#/ {
      if ($3 > 0) { frames += $3; touchCpu += $5; touchSecs++ } else { idleCpu += $5; idleSecs++ }
    }
    END {
      printf "%-28s touching %3d s, %6d frames, %8.1f ms CPU = %.4f ms/frame, %5.2f%% of a core | not touching %3d s, %.1f ms CPU\n",
        name, touchSecs, frames, touchCpu, (frames ? touchCpu / frames : 0), (touchSecs ? touchCpu / touchSecs / 10 : 0),
        idleSecs, idleCpu
    }' "$f"
done
