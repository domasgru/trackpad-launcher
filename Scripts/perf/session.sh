#!/bin/bash
# Guided measurement session (see docs/performance.md): each phase is announced aloud, then the app is sampled once
# a second while the person does what was asked. One TSV per phase, its last line the phase total.
# Usage: Scripts/perf/session.sh <app-pid> <outdir>
# Needs Scripts/perf/build.sh first. Quit every other copy of the app before running.
set -euo pipefail
PID=$1
OUT=$2
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/build/perf/tools/sampler"
mkdir -p "$OUT"

phase() { # name seconds cue
  say -r 210 "$3"
  sleep 1
  "$S" "$PID" 1000 "$2" "$1" > "$OUT/$1.tsv"
  say -r 230 "stop"
  sleep 3
}

say -r 210 "Measurement starting in five seconds."
sleep 5
phase 01_idle_hands_off 60 "Phase one. Take your hands off the trackpad and keyboard for one minute."
phase 02_pointer_scroll 40 "Phase two. Move the pointer and scroll web pages. No launcher gestures. Forty seconds."
phase 03_taps 40 "Phase three. Launcher taps. Thumb in the corner, then tap with one to four fingers. About ten taps."
phase 04_app_swipe 30 "Phase four. App switcher. Thumb in the corner, two fingers sideways, lift. About six times."
phase 05_window_swipe 30 "Phase five. Window switcher, in an app with several windows. About six times."
phase 06_swap 20 "Phase six. Swap. Rest two fingers, then tap your thumb in the corner a few times."
phase 07_menu_window 25 "Phase seven. Open the menu bar window and one app picker, scroll its list, then close it."
phase 08_idle_after 60 "Phase eight. Hands off the trackpad again for one minute."
say -r 210 "Measurement complete."
grep -h "#TOTAL" "$OUT"/*.tsv
