#!/bin/bash
# Puts two real, patched builds of Trackpad Launcher through a real Sparkle update against a local server, and writes
# build/update-e2e/report.md. The in-memory tests prove the app's decisions; this proves Sparkle's behaviour on the
# wire and on screen, which fakes hid in two earlier update plans.
#
#   Scripts/update-e2e.sh               every row; needs a person with a Developer ID, a notary profile and sudo
#   Scripts/update-e2e.sh T58 T59       only those rows; T60, T62, T63, T64, T65, T68 and T72 stop for a person
#   Scripts/update-e2e.sh --check       no credentials: builds ad-hoc signed, renders the feed through
#                                       release.sh --feed-only, starts the server and the sampler, and writes the
#                                       report with every row SKIPPED
#
# Without a "Developer ID Application" identity or the notarytool profile (NOTARY_PROFILE, default trackpad-launcher)
# the script behaves as --check and says why. The gate in the app reads the process's real signature, so only
# Developer ID signed, notarised builds can run the rows; an Apple Development build passes nothing there.
#
# Two builds come from a patched copy of the tree (the real project.yml is never edited): bundle identifier
# com.domasgru.TrackpadLauncherApp.e2e, feed and download prefix on 127.0.0.1, a throwaway update key, local networking
# allowed. v1 is 1.0.0 build 1000, v2 is 2.0.0 build 2000. They are cached by commit, because notarising takes
# minutes. Scratch work, the cache and the report live under build/update-e2e/.
#
# Rows are the functions named in rows_table below. A row ends in PASS or FAIL with one line of evidence, or SKIPPED
# with the reason; a failing row does not stop the others. Each starts from a clean state. Copies install as
# "Trackpad Launcher E2E.app". Cleanup runs on exit and on Ctrl-C, and leaves no copy, launchd job, defaults domain,
# cache or server process.
set -o pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPERS="$ROOT/Scripts/update-e2e"
SCRATCH="$ROOT/build/update-e2e"
TEAM_ID="${TEAM_ID:-CQK27876UL}"
NOTARY_PROFILE="${NOTARY_PROFILE:-trackpad-launcher}"
PORT="${E2E_PORT:-18765}"
BASE_ID="com.domasgru.TrackpadLauncherApp"
E2E_ID="$BASE_ID.e2e"
BUNDLE_NAME="Trackpad Launcher.app"
APP_NAME="Trackpad Launcher E2E.app"
FOLDER_NAME="Trackpad Launcher E2E Folder"
REPOSITORY_URL="https://github.com/domasgru/trackpad-launcher/releases/download"
FEED_URL="http://127.0.0.1:$PORT/domasgru/trackpad-launcher/main/appcast.xml"
DOWNLOADS_BASE="http://127.0.0.1:$PORT/domasgru/trackpad-launcher/releases/download"
SPARKLE_BIN="$ROOT/LauncherKit/Vendor/Sparkle/bin"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
PY="python3 -I -B"

TREE="$SCRATCH/tree"
SERVE="$SCRATCH/serve"
LOG="$SERVE/requests.log"
CONTROL="$SERVE/control"
RESULTS="$SCRATCH/results.tsv"
ROW_RESULT="$SCRATCH/row.result"
SAMPLER="$SCRATCH/sampler"
SAMPLER_PIDFILE="$SCRATCH/sampler.pid"
SERVER_PIDFILE="$SCRATCH/server.pid"
FRAME_NOTES="$SCRATCH/frame.txt"
REPORT="$SCRATCH/report.md"
REPORT_WRITTEN=0
SAMPLES=""
TAB=$'\t'

log() { echo "[update-e2e] $*" >&2; }
die() { log "$*"; exit 1; }

# One row per line: id|function|what it proves.
rows_table() {
  cat <<'TABLE'
T56|row_T56|card-contract accepts the real stapled archives, nested Sparkle code included
T57|row_T57|a build started by hand, its window closed, updates with nothing shown and no input
T58|row_T58|the updater's requests carry no cookie, validator, query or identifying header, on both versions
T59|row_T59|the highest newer release that runs on this Mac is the one downloaded
T60|row_T60|a copy that cannot update itself makes no request and asks for no password
T61|row_T61|--after-update leaves the 24 hour timer as the only source of a check
T62|row_T62|Quit Trackpad Launcher ends the app at once and the held update installs without a restart
T63|row_T63|an idle minute hands over silently: v2 runs with --after-update, gestures work, nothing asks or shows
T64|row_T64|a finger, then a palm, resting 90 s each keep the held update waiting; it installs a minute after the lift
T65|row_T65|a download reset half way shows nothing and the next check completes it
T66|row_T66|a feed that fails once is retried once, 20 of 20 times, and a feed that always fails is not hammered
T67|row_T67|an update that is not the publisher's, or not from the publisher's host, installs nothing and shows nothing
T68|row_T68|a failed install reopens the old copy intact, gestures work, and no hand-over loop starts
T69|row_T69|kill -9 of the app or of Autoupdate at random moments never leaves a half copy or a stuck job
T70|row_T70|an update that would need a password installs nothing and never shows a password window
T71|row_T71|a removed installer job ends the cycle with no hand-over and a later check downloads again
T72|row_T72|a build with an empty update key makes no request and shows nothing
TABLE
}

row_ids() { rows_table | cut -d'|' -f1; }

# ---------------------------------------------------------------------------------------------------------------
# Arguments and mode

CHECK=0
SELECTED=""
for argument in "$@"; do
  case "$argument" in
    --check) CHECK=1 ;;
    -h | --help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    T[0-9]*)
      row_ids | grep -qx "$argument" || die "no row $argument; rows: $(row_ids | tr '\n' ' ')"
      SELECTED="$SELECTED $argument" ;;
    *) die "usage: update-e2e.sh [--check] [row...]" ;;
  esac
done

MODE=full
SKIP_REASON=""
if [ "$CHECK" = 1 ]; then
  MODE=check
  SKIP_REASON="--check: builds are ad-hoc signed and no credential is used"
elif ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  MODE=check
  SKIP_REASON="no Developer ID Application identity in the keychain"
elif ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  MODE=check
  SKIP_REASON="notarytool cannot use the keychain profile '$NOTARY_PROFILE'"
fi

commit_key() {
  local paths="TrackpadLauncher LauncherKit/Sources LauncherKit/Package.swift LauncherKit/Package.resolved Config project.yml assets"
  local head tag=""
  head="$(git -C "$ROOT" rev-parse --short=12 HEAD)"
  # shellcheck disable=SC2086
  if [ -n "$(git -C "$ROOT" status --porcelain -- $paths)" ]; then
    # shellcheck disable=SC2086
    tag="-dirty-$(git -C "$ROOT" diff HEAD -- $paths | shasum | cut -c1-8)"
  fi
  echo "$head$tag"
}

mkdir -p "$SCRATCH"
COMMIT="$(commit_key)"
CACHE="$SCRATCH/cache/$COMMIT-$MODE-$PORT"

# ---------------------------------------------------------------------------------------------------------------
# State: what a run touches, and putting it all back

PROCESS_PATTERNS=("$APP_NAME/Contents/" "$E2E_ID")

app_processes() { pgrep -f "$APP_NAME/Contents/MacOS" 2>/dev/null; }

kill_app_processes() {
  local pattern
  for pattern in "${PROCESS_PATTERNS[@]}"; do pkill -f "$pattern" 2>/dev/null; done
  sleep 0.5
  for pattern in "${PROCESS_PATTERNS[@]}"; do pkill -9 -f "$pattern" 2>/dev/null; done
  return 0
}

stop_app() {
  pkill -f "$APP_NAME/Contents/MacOS" 2>/dev/null
  wait_for 10 no_app_running
}

count_app_processes() { app_processes | wc -l | tr -d ' '; }

count_jobs() { launchctl list 2>/dev/null | grep -c "$E2E_ID"; }

no_app_running() { [ -z "$(app_processes)" ]; }

remove_launch_jobs() {
  launchctl list 2>/dev/null | awk -v id="$E2E_ID" 'index($3, id) { print $3 }' |
    while read -r label; do launchctl remove "$label" 2>/dev/null; done
  return 0
}

remove_path() {
  [ -e "$1" ] || return 0
  "$LSREGISTER" -u "$1" 2>/dev/null
  chmod -R u+w "$1" 2>/dev/null
  rm -rf "$1" 2>/dev/null
  [ ! -e "$1" ] || sudo -n rm -rf "$1" 2>/dev/null
  [ ! -e "$1" ] || log "could not remove $1; remove it by hand (sudo rm -rf)."
}

remove_copies() {
  remove_path "/Applications/$APP_NAME"
  remove_path "/Applications/$FOLDER_NAME"
  remove_path "$HOME/Applications/$APP_NAME"
}

stop_sampler() {
  [ -f "$SAMPLER_PIDFILE" ] || return 0
  kill "$(cat "$SAMPLER_PIDFILE")" 2>/dev/null
  rm -f "$SAMPLER_PIDFILE"
}

set_control() { printf '%s\n' "$*" > "$CONTROL"; }

# Everything a row's run can leave behind, then an empty request log and a server that behaves.
reset_world() {
  stop_sampler
  kill_app_processes
  remove_launch_jobs
  remove_copies
  defaults delete "$E2E_ID" 2>/dev/null
  local library="$HOME/Library"
  rm -rf "$library/Caches/$E2E_ID" "$library/HTTPStorages/$E2E_ID" "$library/HTTPStorages/$E2E_ID.binarycookies" \
    "$library/Preferences/$E2E_ID.plist" "$library/Application Support/$E2E_ID" "$library/WebKit/$E2E_ID" \
    "$library/Saved Application State/$E2E_ID.savedState" "$library/Logs/$E2E_ID"
  [ -d "$SERVE" ] && { : > "$LOG"; set_control ""; }
  return 0
}

stop_server() {
  [ -f "$SERVER_PIDFILE" ] || return 0
  kill "$(cat "$SERVER_PIDFILE")" 2>/dev/null
  rm -f "$SERVER_PIDFILE"
}

leftovers() {
  local found=""
  [ -e "/Applications/$APP_NAME" ] && found="$found /Applications/$APP_NAME"
  [ -e "/Applications/$FOLDER_NAME" ] && found="$found /Applications/$FOLDER_NAME"
  [ -e "$HOME/Applications/$APP_NAME" ] && found="$found ~/Applications/$APP_NAME"
  [ -n "$(launchctl list 2>/dev/null | awk -v id="$E2E_ID" 'index($3, id)')" ] && found="$found launchd-job"
  defaults read "$E2E_ID" >/dev/null 2>&1 && found="$found defaults-domain"
  [ -d "$HOME/Library/Caches/$E2E_ID" ] && found="$found cache"
  app_processes >/dev/null && found="$found process"
  echo "$found"
}

STATUS=0
cleanup() {
  STATUS=$?
  trap - EXIT INT TERM
  stop_sampler
  stop_server
  reset_world
  rm -rf "$SCRATCH/feedwork" "$TREE" "$TREE-emptykey" "$ROW_RESULT"
  rmdir "$HOME/Applications" 2>/dev/null
  local left
  left="$(leftovers)"
  if [ -n "$left" ]; then log "cleanup left:$left"; else log "cleanup: nothing left behind"; fi
  [ "$REPORT_WRITTEN" = 1 ] || { [ -d "$SCRATCH" ] && write_report; }
  exit "$STATUS"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---------------------------------------------------------------------------------------------------------------
# Helpers for rows

now_ms() { $PY -c 'import time; print(int(time.time() * 1000))'; }

analyze() { $PY "$HELPERS/analyze.py" "$@"; }

# wait_for <seconds> <command...>: polls until the command succeeds.
wait_for() {
  local limit="$1" end
  shift
  end=$((SECONDS + limit))
  while [ "$SECONDS" -lt "$end" ]; do
    "$@" >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  return 1
}

# count_in <kind> <since ms> [until ms] [path text]: requests of a kind in the server log.
count_in() {
  analyze count "$LOG" --kind "$1" --since "$2" ${3:+--until "$3"} ${4:+--contains "$4"}
}

# wait_count <seconds> <kind> <since> <minimum> [path text]
wait_count() {
  wait_for "$1" count_at_least "$2" "$3" "$4" "${5:-}"
}

count_at_least() {
  [ "$(count_in "$1" "$2" "" "$4")" -ge "$3" ]
}

window_closed() { ! analyze window-open "$SAMPLES" >/dev/null; }

version_of() { /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CACHE/$1/$BUNDLE_NAME/Contents/Info.plist"; }

aar_of() { ls "$CACHE/$1/"*.aar 2>/dev/null | head -1; }

install_copy() {
  local name="$1" destination="$2"
  mkdir -p "$(dirname "$destination")"
  /usr/bin/ditto "$CACHE/$name/$BUNDLE_NAME" "$destination" && "$LSREGISTER" -f "$destination"
}

# Sets the last check time to <seconds> ago: the engine decides on a request at start from this.
set_last_check() {
  defaults write "$E2E_ID" SULastCheckTime -date "$(date -u -v-"$1"S '+%Y-%m-%d %H:%M:%S +0000')"
}

launch_hidden() {
  local app="$1"
  shift
  /usr/bin/open -g -j "$app" --args "$@"
}

# start_sampler <label> [app path]...: SAMPLES names the file the rows read afterwards.
start_sampler() {
  local label="$1" arguments=() path
  shift
  SAMPLES="$SCRATCH/samples-$label.jsonl"
  for path in "$@"; do arguments+=(--app "$path"); done
  SAMPLER_BUNDLE_ID="$E2E_ID" "$SAMPLER" "$SAMPLES" "${arguments[@]}" >/dev/null 2>&1 &
  echo $! > "$SAMPLER_PIDFILE"
  disown
  sleep 0.5
}

# stage_assets [build name]...: the archives the server hands out. Builds of one version share an archive's file name, so
# a row with two of them names the one it serves; with no name every archive is served.
stage_assets() {
  rm -rf "$SERVE/assets"
  mkdir -p "$SERVE/assets"
  if [ $# -eq 0 ]; then
    cp "$CACHE"/*/*.aar "$SERVE/assets/" 2>/dev/null
  else
    local name
    for name in "$@"; do cp "$(aar_of "$name")" "$SERVE/assets/" 2>/dev/null; done
  fi
  return 0
}

# use_feed <build name>...: serves the feed release.sh --feed-only renders with those builds' items.
use_feed() {
  stage_assets "$@"
  render_feed "$SERVE/feed.xml" "$@" || return 1
}

# edit_feed <feed.py command> <version> [arguments]: edits the feed being served.
edit_feed() {
  local command="$1"
  shift
  $PY "$HELPERS/feed.py" "$command" "$SERVE/feed.xml" "$@" > "$SERVE/feed.edit" || return 1
  mv "$SERVE/feed.edit" "$SERVE/feed.xml"
}

# The hand-over job and Sparkle's two installer jobs, which no row may leave listed.
HELPER_JOBS="$E2E_ID(\\.hand-over|-sparkle-)"
count_helper_jobs() { launchctl list 2>/dev/null | awk '{ print $3 }' | grep -cE "^$HELPER_JOBS"; }
# job_listed <label suffix>: .hand-over, -sparkle-updater or -sparkle-progress.
job_listed() { launchctl list 2>/dev/null | awk -v label="$E2E_ID$1" '$3 == label { found = 1 } END { exit !found }'; }

# wait_job <seconds> <label suffix>: polls fast, because the instant the job appears is a measurement.
wait_job() {
  local end=$((SECONDS + $1))
  while [ "$SECONDS" -lt "$end" ]; do
    job_listed "$2" && return 0
    sleep 0.1
  done
  return 1
}

# wait_gone <pid> <seconds>
wait_gone() {
  local end=$((SECONDS + $2))
  while [ "$SECONDS" -lt "$end" ]; do
    kill -0 "$1" 2>/dev/null || return 0
    sleep 0.05
  done
  return 1
}

bundle_version() { /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$1/Contents/Info.plist"; }

# ask_person <instruction>: what nothing can synthesise. The time after the Return is the row's clock.
ask_person() {
  printf '\n>>> %s\n    Press Return here when ready: ' "$1" > /dev/tty
  read -r _ < /dev/tty
}

# tell_person <instruction>: for a moment the script finds for itself, so nothing waits on a Return.
tell_person() { printf '\n>>> %s\n' "$1" > /dev/tty; }

# The gesture rows time a person's 1-finger gesture through the app's real settings window: this app is assigned to it,
# so its reaching the front is the only outside sign that gestures run.
GESTURE_APP_ID=com.apple.calculator
GESTURE_APP_NAME=Calculator

quit_gesture_app() { osascript -e "tell application \"$GESTURE_APP_NAME\" to quit" >/dev/null 2>&1; return 0; }

# assign_gesture <app path>: the running copy's settings window opens, the person assigns the app and closes it again.
assign_gesture() {
  quit_gesture_app
  /usr/bin/open -g "$1"
  wait_for 15 analyze window-open "$SAMPLES" || return 1
  ask_person "In the settings window of Trackpad Launcher E2E, assign $GESTURE_APP_NAME to the 1-finger tap gesture, close the window with its red button, and stay off the trackpad."
  wait_for 15 window_closed
}

# check_gesture <description> <since ms> [limit ms]: the person has been told to tap; the time the app first came to the
# front after <since> is measured from the sampler, so it includes their reaction.
check_gesture() {
  local reached limit="${3:-10000}"
  wait_for $((limit / 1000 + 2)) analyze first-front "$SAMPLES" --id "$GESTURE_APP_ID" --since "$2"
  reached="$(analyze first-front "$SAMPLES" --id "$GESTURE_APP_ID" --since "$2")"
  if [ -n "$reached" ] && [ $((reached - $2)) -lt "$limit" ]; then
    ROW_NOTES+=("$1: $GESTURE_APP_NAME reached the front $((reached - $2)) ms after the mark")
  else
    ROW_FAILS+=("$1: $GESTURE_APP_NAME did not reach the front within $((limit / 1000)) s of the mark")
  fi
  quit_gesture_app
}

# within <description> <value ms> <least> <most>
within() {
  if [ -n "$2" ] && [ "$2" -ge "$3" ] && [ "$2" -le "$4" ]; then
    ROW_NOTES+=("$1: $2 ms")
  else
    ROW_FAILS+=("$1: ${2:-nothing} ms, wanted $3 to $4")
  fi
}

# --- verdicts. A row is a function run in a subshell: it calls check, expect_count, row_fail or row_skip, and the
# frame calls row_done afterwards.

ROW_FAILS=()
ROW_NOTES=()

oneline() { tr '\n\t' '  ' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c1-260; }

# check <description> <command...>: the command's output is the evidence.
check() {
  local description="$1" output status
  shift
  output="$("$@" 2>&1)"
  status=$?
  output="$(printf '%s' "$output" | oneline)"
  if [ "$status" -eq 0 ]; then ROW_NOTES+=("$description: ${output:-ok}"); else ROW_FAILS+=("$description: ${output:-failed}"); fi
}

# expect_count <description> <-eq|-ge> <number> <command...>: the command prints a count.
expect_count() {
  local description="$1" operator="$2" wanted="$3" count
  shift 3
  count="$("$@" 2>/dev/null)"
  count="${count:-0}"
  if test "$count" "$operator" "$wanted"; then
    ROW_NOTES+=("$description: $count")
  else
    ROW_FAILS+=("$description: $count, wanted $operator $wanted")
  fi
}

write_row_result() { printf '%s\t%s\n' "$1" "$2" > "$ROW_RESULT"; }

join_lines() {
  local joined="" item
  for item in "$@"; do joined="${joined:+$joined; }$item"; done
  echo "$joined"
}

row_done() {
  if [ "${#ROW_FAILS[@]}" -gt 0 ]; then
    write_row_result FAIL "$(join_lines "${ROW_FAILS[@]}")"
  else
    write_row_result PASS "$(join_lines "${ROW_NOTES[@]}")"
  fi
}

row_fail() {
  ROW_FAILS+=("$1")
  row_done
  exit 0
}

row_skip() {
  write_row_result SKIPPED "$1"
  exit 0
}

record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULTS"
  log "$1 $2: $3"
}

run_row() {
  local id="$1" function="$2" title="$3" status evidence
  if [ "$MODE" = check ]; then
    record "$id" SKIPPED "$SKIP_REASON"
    return
  fi
  log "$id: $title"
  reset_world
  rm -f "$ROW_RESULT"
  ( ROW_FAILS=(); ROW_NOTES=(); "$function"; row_done ) </dev/null
  if [ -f "$ROW_RESULT" ]; then
    IFS=$'\t' read -r status evidence < "$ROW_RESULT"
  else
    status=FAIL
    evidence="the row stopped without a verdict"
  fi
  record "$id" "$status" "$evidence"
}

# ---------------------------------------------------------------------------------------------------------------
# The update key, the helpers, the patched tree and the two builds

ensure_key() {
  mkdir -p "$SCRATCH/key"
  [ -f "$SCRATCH/key/ed.pub" ] && [ -f "$SCRATCH/key/ed.key" ] && return 0
  swift "$HELPERS/keygen.swift" "$SCRATCH/key" || die "cannot make the throwaway update key."
}

ensure_sampler() {
  if [ ! -x "$SAMPLER" ] || [ "$HELPERS/sampler.swift" -nt "$SAMPLER" ]; then
    swiftc -O -swift-version 5 "$HELPERS/sampler.swift" -o "$SAMPLER" || die "cannot compile the sampler."
  fi
}

ensure_sparkle_tools() {
  [ -x "$SPARKLE_BIN/sign_update" ] || die "Sparkle's tools are missing from LauncherKit/Vendor/Sparkle/bin."
}

# A copy of the tree with project.yml patched; the real one is never edited.
prepare_tree() {
  local variant="${1:-}" tree="$TREE${1:+-$1}"
  [ -f "$tree/.ready" ] && return 0
  rm -rf "$tree"
  mkdir -p "$tree"
  rsync -a --exclude /.git --exclude /build --exclude /plans --exclude /.claude --exclude /DerivedData \
    --exclude /LauncherKit/.build --exclude /LauncherKit/.swiftpm --exclude /TrackpadLauncher.xcodeproj \
    "$ROOT/" "$tree/" || return 1
  local key patched="$tree/project.yml.patched"
  key="$(cat "$SCRATCH/key/ed.pub")"
  [ "$variant" = emptykey ] && key='""'
  awk -v feed="$FEED_URL" -v downloads="$DOWNLOADS_BASE/" -v key="$key" '
    /PRODUCT_BUNDLE_IDENTIFIER: com.domasgru.TrackpadLauncherApp$/ { sub(/TrackpadLauncherApp$/, "TrackpadLauncherApp.e2e") }
    /SUFeedURL:/ { sub(/SUFeedURL:.*/, "SUFeedURL: " feed) }
    /SUPublicEDKey:/ { sub(/SUPublicEDKey:.*/, "SUPublicEDKey: " key) }
    /TLUpdateDownloads:/ {
      sub(/TLUpdateDownloads:.*/, "TLUpdateDownloads: " downloads)
      print
      print "        NSAppTransportSecurity:"
      print "          NSAllowsLocalNetworking: true"
      next
    }
    { print }' "$tree/project.yml" > "$patched" || return 1
  mv "$patched" "$tree/project.yml"
  local expectation
  for expectation in "PRODUCT_BUNDLE_IDENTIFIER: $E2E_ID" "SUFeedURL: $FEED_URL" "SUPublicEDKey: $key" \
    "TLUpdateDownloads: $DOWNLOADS_BASE/" "NSAllowsLocalNetworking: true"; do
    grep -qF -- "$expectation" "$tree/project.yml" || { log "the patched project.yml lacks: $expectation"; return 1; }
  done
  (cd "$tree" && xcodegen generate) >"$SCRATCH/logs-xcodegen.txt" 2>&1 || { tail -20 "$SCRATCH/logs-xcodegen.txt" >&2; return 1; }
  touch "$tree/.ready"
}

# ensure_build <name> <version> <build number> <kind> [bundle identifier] [tree variant]: leaves the app and its update
# archive in $CACHE/<name>. Kinds: release (Developer ID, notarised), unnotarised (Developer ID only), appledev. The
# identifier defaults to the e2e one, and the variant emptykey ships an empty update key. Under --check every kind is
# ad-hoc signed, with no export and no notarising.
ensure_build() {
  local name="$1" version="$2" number="$3" kind="$4" identifier="${5:-$E2E_ID}" variant="${6:-}"
  [ -f "$CACHE/$name/.done" ] && return 0
  log "building $name ($version, build $number, $kind${5:+, $identifier}${variant:+, $variant})"
  prepare_tree "$variant" || return 1
  local tree="$TREE${variant:+-$variant}"
  local work="$SCRATCH/work/$name" build_log="$SCRATCH/logs/$name.log" app signing
  rm -rf "$work"
  mkdir -p "$work" "$SCRATCH/logs"
  local identifier_setting=()
  [ "$identifier" = "$E2E_ID" ] || identifier_setting=("PRODUCT_BUNDLE_IDENTIFIER=$identifier")
  if [ "$MODE" = check ]; then
    signing=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=-" DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS=)
  elif [ "$kind" = appledev ]; then
    signing=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Apple Development" DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS=)
  else
    signing=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID")
  fi

  xcodebuild archive \
    -project "$tree/TrackpadLauncher.xcodeproj" \
    -scheme TrackpadLauncher \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$work/TrackpadLauncher.xcarchive" \
    -derivedDataPath "$SCRATCH/derived" \
    "${signing[@]}" \
    "${identifier_setting[@]}" \
    MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$number" >"$build_log" 2>&1 ||
    { tail -30 "$build_log" >&2; return 1; }

  if [ "$MODE" = full ] && [ "$kind" != appledev ]; then
    cat > "$work/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive \
      -archivePath "$work/TrackpadLauncher.xcarchive" \
      -exportOptionsPlist "$work/ExportOptions.plist" \
      -exportPath "$work/export" >>"$build_log" 2>&1 || { tail -30 "$build_log" >&2; return 1; }
    app="$work/export/$BUNDLE_NAME"
    [ -d "$app" ] || { log "export did not produce $app"; return 1; }
    codesign --verify --strict --verbose=2 "$app" || return 1
    local signature
    signature="$(codesign -dv --verbose=2 "$app" 2>&1)"
    grep -q "Authority=Developer ID Application" <<<"$signature" || { log "$name is not Developer ID signed"; return 1; }
    grep -q "flags=0x10000(runtime)" <<<"$signature" || { log "$name lacks the hardened runtime"; return 1; }
    if [ "$kind" = release ]; then
      ditto -c -k --keepParent "$app" "$work/notarize.zip"
      xcrun notarytool submit "$work/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee -a "$build_log" |
        grep -q "status: Accepted" || { log "notarisation of $name was not accepted; see $build_log"; return 1; }
      xcrun stapler staple "$app" >>"$build_log" 2>&1 && xcrun stapler validate "$app" >>"$build_log" 2>&1 ||
        { log "cannot staple $name"; return 1; }
    fi
  else
    app="$work/TrackpadLauncher.xcarchive/Products/Applications/$BUNDLE_NAME"
    [ -d "$app" ] || { log "archive holds no $app"; return 1; }
  fi

  local plist="$app/Contents/Info.plist" minimum
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = "$identifier" ] || { log "$name has the wrong identifier"; return 1; }
  minimum="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
  mkdir -p "$CACHE/$name"
  rm -rf "$CACHE/$name/$BUNDLE_NAME"
  ditto "$app" "$CACHE/$name/$BUNDLE_NAME" || return 1
  make_archive "$name" "$version" "$minimum" || return 1
  touch "$CACHE/$name/.done"
  rm -rf "$work"
}

# The update archive, made with the release's own flags and inner name.
make_archive() {
  local name="$1" version="$2" minimum="$3" source archive
  source="$(mktemp -d)"
  archive="$CACHE/$name/TrackpadLauncher-$version-macOS-$minimum.aar"
  ditto "$CACHE/$name/$BUNDLE_NAME" "$source/TrackpadLauncher.app" || return 1
  rm -f "$archive"
  aa archive -d "$source" -subdir TrackpadLauncher.app -exclude-field uid,gid,xat,acl,flg -o "$archive" || return 1
  rm -rf "$source"
}

# ---------------------------------------------------------------------------------------------------------------
# The feed: whatever release.sh --feed-only renders, in a throwaway clone with a local bare origin and stubs for
# everything outside (the same arrangement ReleaseHarness.swift makes), then pointed at the local server.

write_stub() { printf '#!/bin/bash\n%s\n' "$2" > "$1/$3"; chmod +x "$1/$3"; }

# render_feed <destination> <build name>...
render_feed() {
  local destination="$1" key work="$SCRATCH/feedwork" name version
  shift
  key="$(printf '%s+' "$@")"
  mkdir -p "$CACHE/feeds"
  if [ -f "$CACHE/feeds/$key.xml" ]; then cp "$CACHE/feeds/$key.xml" "$destination"; return 0; fi

  rm -rf "$work"
  mkdir -p "$work/origin.git" "$work/clone" "$work/state/stubs" "$work/state/releases" "$work/home" "$work/tmp" "$work/out"
  local stubs="$work/state/stubs" clone="$work/clone" bin
  bin="$clone/LauncherKit/Vendor/Sparkle/bin"
  write_stub "$stubs" '
case "$1 $2" in
  "auth status") exit 0 ;;
  "release download")
    tag="$3"; shift 3; dir=""
    while [ $# -gt 0 ]; do [ "$1" = "--dir" ] && dir="$2"; shift; done
    cp "$STUB_STATE/releases/$tag/"*.aar "$dir/" ;;
  *) exit 1 ;;
esac' gh
  write_stub "$stubs" 'exit 0' xcrun
  write_stub "$stubs" 'exit 0' swift
  write_stub "$stubs" 'exit 0' xcodegen
  write_stub "$stubs" "echo '  1) 0123456789ABCDEF \"Developer ID Application: Harness ($TEAM_ID)\"'" security
  mkdir -p "$bin"
  write_stub "$bin" "exec \"$SPARKLE_BIN/sign_update\" --ed-key-file \"$SCRATCH/key/ed.key\" \"\$@\"" sign_update
  write_stub "$bin" "[ \"\$1\" = \"-p\" ] && cat \"$SCRATCH/key/ed.pub\"" generate_keys

  local file
  for file in Scripts/release.sh Scripts/test.sh Scripts/release/dmg-background.png Config/Version.xcconfig appcast.xml .gitignore; do
    mkdir -p "$clone/$(dirname "$file")"
    cp "$ROOT/$file" "$clone/$file"
  done
  # Only the key matters to release.sh: it checks that the keychain's key is the one project.yml ships.
  awk -v key="$(cat "$SCRATCH/key/ed.pub")" '/SUPublicEDKey:/ { sub(/SUPublicEDKey:.*/, "SUPublicEDKey: " key) } { print }' \
    "$ROOT/project.yml" > "$clone/project.yml"

  local environment=(env -i "PATH=$stubs:/usr/bin:/bin:/usr/sbin:/sbin" "HOME=$work/home" "TMPDIR=$work/tmp/"
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 "STUB_STATE=$work/state" "RELEASE_OUT=$work/out")
  {
    "${environment[@]}" git init --quiet --bare --initial-branch=main "$work/origin.git" &&
      "${environment[@]}" git -C "$clone" init --quiet --initial-branch=main &&
      "${environment[@]}" git -C "$clone" config user.name "Update E2E" &&
      "${environment[@]}" git -C "$clone" config user.email "e2e@example.invalid" &&
      "${environment[@]}" git -C "$clone" config commit.gpgsign false &&
      "${environment[@]}" git -C "$clone" add -A &&
      "${environment[@]}" git -C "$clone" commit --quiet -m Initial &&
      "${environment[@]}" git -C "$clone" remote add origin "$work/origin.git" &&
      "${environment[@]}" git -C "$clone" push --quiet origin main &&
      "${environment[@]}" git -C "$clone" fetch --quiet origin &&
      "${environment[@]}" git -C "$clone" branch --set-upstream-to=origin/main main
  } >"$work/git.log" 2>&1 || { cat "$work/git.log" >&2; return 1; }

  for name in "$@"; do
    version="$(version_of "$name")"
    mkdir -p "$work/state/releases/v$version"
    cp "$(aar_of "$name")" "$work/state/releases/v$version/"
    "${environment[@]}" /bin/bash "$clone/Scripts/release.sh" --feed-only "$version" </dev/null >>"$work/release.log" 2>&1 ||
      { tail -20 "$work/release.log" >&2; return 1; }
  done
  sed "s|$REPOSITORY_URL|$DOWNLOADS_BASE|g" "$clone/appcast.xml" > "$destination" || return 1
  xmllint --noout "$destination" || return 1
  [ "$(grep -c '<item>' "$destination")" -eq "$#" ] || { log "the feed does not hold $# items"; return 1; }
  cp "$destination" "$CACHE/feeds/$key.xml"
}

# ---------------------------------------------------------------------------------------------------------------
# The server and the frame's own proof

start_server() {
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then die "port $PORT is in use; set E2E_PORT, and rebuild."; fi
  mkdir -p "$SERVE/assets"
  : > "$LOG"
  : > "$CONTROL"
  [ -f "$SERVE/feed.xml" ] || : > "$SERVE/feed.xml"
  $PY "$HELPERS/server.py" "$SERVE" "$LOG" "$CONTROL" "$PORT" >"$SCRATCH/server.out" 2>&1 &
  echo $! > "$SERVER_PIDFILE"
  disown
  wait_for 10 /usr/bin/curl -s -o /dev/null "http://127.0.0.1:$PORT/" || die "the local server did not start; see $SCRATCH/server.out"
}

frame_note() { echo "$*" >> "$FRAME_NOTES"; log "$*"; }

# Proves the feed, the server's paths, redirect and request log, and the sampler, with /usr/bin/curl.
frame_check() {
  : > "$FRAME_NOTES"
  use_feed v2 || die "cannot render the feed."
  grep -q "$DOWNLOADS_BASE/v$(version_of v2)/" "$SERVE/feed.xml" && ! grep -q github.com "$SERVE/feed.xml" ||
    die "the rendered feed does not point at the local server."
  frame_note "feed: release.sh --feed-only rendered $(grep -c '<item>' "$SERVE/feed.xml") item(s), pointed at 127.0.0.1:$PORT"

  : > "$LOG"
  local headers="$SCRATCH/curl.headers" name path
  name="$(basename "$(aar_of v2)")"
  path="/domasgru/trackpad-launcher/releases/download/v$(version_of v2)/$name"
  /usr/bin/curl -s -D "$headers" -o "$SCRATCH/curl.feed" "http://127.0.0.1:$PORT/domasgru/trackpad-launcher/main/appcast.xml" || die "the feed is not served."
  grep -qi '^content-type: text/plain; charset=utf-8' "$headers" && grep -qi '^etag:' "$headers" &&
    grep -qi '^cache-control: max-age=300' "$headers" || die "the feed's headers differ from raw.githubusercontent.com's."
  cmp -s "$SCRATCH/curl.feed" "$SERVE/feed.xml" || die "the served feed differs from the rendered one."
  /usr/bin/curl -s -D "$headers" -o /dev/null "http://127.0.0.1:$PORT$path" || die "the release path is not served."
  head -1 "$headers" | grep -q ' 302' && grep -qi '^location: /assets/' "$headers" && grep -qi '^set-cookie: probe=' "$headers" ||
    die "the release path does not answer 302 with a cookie."
  /usr/bin/curl -s -L -o "$SCRATCH/curl.aar" "http://127.0.0.1:$PORT$path" || die "the redirect cannot be followed."
  cmp -s "$SCRATCH/curl.aar" "$(aar_of v2)" || die "the downloaded archive differs from v2's."
  set_control "payload=503"
  [ "$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT$path" -L)" = 503 ] || die "the control file does not switch the server."
  set_control ""
  local requests
  requests="$(analyze count "$LOG" --kind any --since 0)"
  [ "$requests" -eq 6 ] || die "the request log holds $requests records, not 6."
  grep -q '^User-Agent: curl' "$LOG" || die "the request log lacks the request headers."
  frame_note "server: feed with ETag and max-age, 302 with a cookie to a second path, control switch, $requests logged requests"

  SAMPLES="$SCRATCH/samples-check.jsonl"
  SAMPLER_BUNDLE_ID="$E2E_ID" "$SAMPLER" "$SAMPLES" --app "/Applications/$APP_NAME" --duration 1 >/dev/null 2>&1
  analyze samples-ok "$SAMPLES" --min 5 >/dev/null || die "the sampler's file is unusable."
  frame_note "sampler: $(analyze samples-ok "$SAMPLES" --min 5) in one second"
  : > "$LOG"
}

# ---------------------------------------------------------------------------------------------------------------
# The rows

row_T56() {
  local name
  for name in v1 v2; do
    check "$name archive" swift run --package-path "$ROOT/LauncherKit" card-contract \
      "$(aar_of "$name")" --team "$TEAM_ID" --identifier "$E2E_ID"
  done
}

row_T57() {
  local app="/Applications/$APP_NAME" launched closed
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler T57 "$app"
  launched="$(now_ms)"
  /usr/bin/open -g "$app"
  wait_for 30 analyze window-open "$SAMPLES" || row_fail "the copy opened by hand showed no window"
  osascript -e "tell application id \"$E2E_ID\" to quit" >/dev/null 2>&1
  wait_for 10 window_closed || row_fail "the quit event did not close the window"
  closed="$(now_ms)"
  wait_count 90 feed "$launched" 1
  wait_count 90 payload "$launched" 1
  sleep 5
  expect_count "feed requests with no input" -ge 1 count_in feed "$launched"
  expect_count "archive GETs with no input" -ge 1 count_in download "$launched" "" "/v2.0.0/"
  check "app kept running" test -n "$(app_processes)"
  check "no window beyond the one closed, UIElement, never frontmost" \
    analyze quiet "$SAMPLES" --since "$closed" --forbid-owner SecurityAgent --max-app-windows 1
}

# One launch of a copy with an overdue check, the feed seen, the app stopped.
t58_check() {
  local name="$1" since
  remove_path "/Applications/$APP_NAME"
  install_copy "$name" "/Applications/$APP_NAME"
  set_last_check $((30 * 3600))
  since="$(now_ms)"
  launch_hidden "/Applications/$APP_NAME"
  wait_count 45 feed "$since" 1
  sleep 4
  stop_app
}

row_T58() {
  local first second end
  use_feed v2 || row_fail "cannot render the feed"
  set_control "payload=503"
  defaults write "$E2E_ID" AppleLanguages -array de
  first="$(now_ms)"
  t58_check v1
  t58_check v1
  second="$(now_ms)"
  t58_check v2
  end="$(now_ms)"
  expect_count "feed requests" -ge 3 count_in feed "$first"
  expect_count "downloads reached the redirect" -ge 1 count_in payload "$first"
  check "no query, cookie or validator; fixed User-Agent, Accept-Language, Accept-Encoding" \
    analyze privacy "$LOG" --since "$first" --until "$end"
  check "header sets of both versions" analyze same-headers "$LOG" "$first" "$second" "$second" "$end"
}

# One scenario of T59: v1 runs against a feed; the paths asked for are the evidence.
t59_case() {
  local description="$1" feed="$2" wanted="$3" refused="$4" since
  reset_world
  stage_assets
  cp "$feed" "$SERVE/feed.xml"
  install_copy v1 "/Applications/$APP_NAME"
  set_last_check $((30 * 3600))
  since="$(now_ms)"
  launch_hidden "/Applications/$APP_NAME"
  wait_count 45 feed "$since" 1
  [ -z "$wanted" ] || wait_count 45 release "$since" 1 "$wanted"
  sleep 12
  expect_count "$description: feed requests" -ge 1 count_in feed "$since"
  if [ -n "$wanted" ]; then expect_count "$description: asked for $wanted" -ge 1 count_in release "$since" "" "$wanted"; fi
  if [ -n "$refused" ]; then
    expect_count "$description: asked for $refused" -eq 0 count_in release "$since" "" "$refused"
  else
    expect_count "$description: asset requests" -eq 0 count_in download "$since"
  fi
}

row_T59() {
  local folder="$SCRATCH/t59" mid higher
  ensure_build mid 1.1.0 1100 release || row_fail "cannot build the 1.1.0 copy"
  mkdir -p "$folder"
  mid="$(version_of mid)"
  higher="$(version_of v2)"
  use_feed mid v2 || row_fail "cannot render the feed"
  cp "$SERVE/feed.xml" "$folder/both.xml"
  t59_case "1.1.0 and 2.0.0 offered" "$folder/both.xml" "/v$higher/" "/v$mid/"

  $PY "$HELPERS/feed.py" set-minimum "$folder/both.xml" "$higher" 99.0 > "$folder/needs99.xml"
  t59_case "2.0.0 needing macOS 99.0" "$folder/needs99.xml" "/v$mid/" "/v$higher/"

  use_feed v1 || row_fail "cannot render the feed"
  $PY "$HELPERS/feed.py" derive "$SERVE/feed.xml" "$(version_of v1)" 0.9.0 900 > "$folder/not-newer.xml"
  t59_case "only the running build and a lower one" "$folder/not-newer.xml" "" ""
}

# One scenario of T60: the copy placed by the given function runs for 30 seconds against an overdue check.
t60_case() {
  local description="$1" place="$2" since
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  "$place"
  set_last_check $((30 * 3600))
  start_sampler "T60-$3" "/Applications/$APP_NAME" "$HOME/Applications/$APP_NAME"
  since="$(now_ms)"
  launch_hidden "$4"
  sleep 30
  expect_count "$description: requests in 30 s" -eq 0 count_in any "$since"
  check "$description: no password window" analyze absent "$SAMPLES" --owner SecurityAgent
}

place_apple_development() {
  ensure_build appledev 1.0.0 1000 appledev || row_fail "cannot build the Apple Development copy"
  install_copy appledev "/Applications/$APP_NAME"
}
place_in_user_applications() { install_copy v1 "$HOME/Applications/$APP_NAME"; }
place_root_wheel() {
  install_copy v1 "/Applications/$APP_NAME"
  sudo chown -R root:wheel "/Applications/$APP_NAME" && sudo chmod -R u=rwX,go=rX "/Applications/$APP_NAME"
}
place_root_admin() {
  install_copy v1 "/Applications/$APP_NAME"
  sudo chown -R root:admin "/Applications/$APP_NAME" && sudo chmod -R u=rwX,g=rwX,o=rX "/Applications/$APP_NAME"
}
place_foreign_group() {
  install_copy v1 "/Applications/$APP_NAME"
  sudo chown -R "$(id -un):daemon" "/Applications/$APP_NAME" && sudo chmod -R u=rwX,go=rX "/Applications/$APP_NAME"
}

row_T60() {
  local pressed
  sudo -v || row_skip "sudo is not available"
  ensure_build appledev 1.0.0 1000 appledev >/dev/null 2>&1 || log "no Apple Development build; its case will fail"
  t60_case "Apple Development copy in /Applications" place_apple_development appledev "/Applications/$APP_NAME"
  t60_case "root:wheel 755" place_root_wheel rootwheel "/Applications/$APP_NAME"
  t60_case "root:admin group-writable" place_root_admin rootadmin "/Applications/$APP_NAME"
  t60_case "a group not this user's" place_foreign_group foreign "/Applications/$APP_NAME"

  t60_case "Developer ID copy in ~/Applications, dialog up" place_in_user_applications dialog "$HOME/Applications/$APP_NAME"
  ask_person "Press 'Move to Applications' in the dialog of Trackpad Launcher E2E, then come back here."
  pressed="$(now_ms)"
  wait_count 40 feed "$pressed" 1
  sleep 5
  expect_count "after Move to Applications: feed requests" -eq 1 count_in feed "$pressed"
}

row_T61() {
  local app="/Applications/$APP_NAME" started
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T61 "$app"
  started="$(now_ms)"
  set_last_check 86380
  launch_hidden "$app" --after-update
  sleep 19
  expect_count "requests in the first 19 s at 86,380 s since the last check" -eq 0 count_in any "$started" $((started + 19000))
  wait_count 20 feed "$started" 1
  expect_count "feed requests by 36 s" -ge 1 count_in feed "$started" $((started + 36000))
  check "no restart" analyze pids "$SAMPLES" --since "$started" --max-distinct 1

  stop_app
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T61b "$app"
  started="$(now_ms)"
  set_last_check $((30 * 3600))
  launch_hidden "$app" --after-update
  wait_count 15 feed "$started" 1
  expect_count "feed requests at 30 h, at once" -ge 1 count_in feed "$started" $((started + 15000))
}

# One run of T62: the person presses Quit; <stalled> holds the download half way.
t62_run() {
  local description="$1" stalled="$2" app="/Applications/$APP_NAME" started pressed gone installed
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  [ "$stalled" = yes ] && set_control "payload=hold"
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler "T62-$stalled" "$app"
  started="$(now_ms)"
  launch_hidden "$app"
  wait_count 60 payload "$started" 1 || { ROW_FAILS+=("$description: no download began"); return; }
  sleep 15
  /usr/bin/open -g "$app"
  wait_for 15 analyze window-open "$SAMPLES" || { ROW_FAILS+=("$description: the settings window did not open"); return; }
  ask_person "Press Return here, then at once press 'Quit Trackpad Launcher' in the settings window."
  pressed="$(now_ms)"
  wait_for 30 no_app_running || { ROW_FAILS+=("$description: the app did not end"); return; }
  gone="$(now_ms)"
  ROW_NOTES+=("$description: the app ended $((gone - pressed)) ms after the Return, a person's reaction included")
  if [ "$stalled" = yes ]; then
    sleep 10
    check "$description: the bundle stays v1" test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" = 1000
  else
    installed="$(analyze first-version "$SAMPLES" --app "$app" --version 2000 --since "$pressed")"
    if [ -n "$installed" ] && [ $((installed - gone)) -le 5000 ]; then
      ROW_NOTES+=("$description: the bundle read v2 $((installed - gone)) ms after the process ended")
    else
      ROW_FAILS+=("$description: the bundle did not read v2 within 5 s of the process ending")
    fi
  fi
  sleep 120
  check "$description: nothing ran for 120 s" analyze pids "$SAMPLES" --since $((gone + 2000)) --max-concurrent 0
  expect_count "$description: processes of the copy now" -eq 0 count_app_processes
  expect_count "$description: launchd jobs now" -eq 0 count_jobs
}

row_T62() {
  t62_run "an update waiting" no
  t62_run "a stalled download" yes
}

# ---------------------------------------------------------------------------------------------------------------
# The hand-over rows

# start_held <label> <app path> [launch argument]...: v1 is installed at that path and launched with an overdue check.
# Returns once the update is held (Sparkle's installer job is listed); HELD_AT is that instant.
start_held() {
  local label="$1" app="$2" started
  shift 2
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler "$label" "$app"
  started="$(now_ms)"
  launch_hidden "$app" "$@"
  wait_count 60 payload "$started" 1 || row_fail "no download began"
  wait_job 150 -sparkle-updater || row_fail "the update was never held"
  HELD_AT="$(now_ms)"
}

first_process() { app_processes | head -1; }

# process_runs <pid> <app path>: the process runs that copy's executable with --after-update.
process_runs() { ps -o args= -p "$1" | grep -q -- "^$2/Contents/MacOS/.* --after-update\$"; }

# after_exit <description> <old pid>: once the old pid has ended, finds the copy that follows it. Sets GONE_AT, NEW_AT and
# NEW_PID from the sampler.
after_exit() {
  local description="$1" old="$2"
  wait_for 5 analyze gone-at "$SAMPLES" --pid "$old" || row_fail "$description: the sampler never saw the old process end"
  GONE_AT="$(analyze gone-at "$SAMPLES" --pid "$old")"
  wait_for 20 analyze new-pid "$SAMPLES" --exclude "$old" --since "$GONE_AT" || row_fail "$description: no copy started after the old one ended"
  read -r NEW_AT NEW_PID <<<"$(analyze new-pid "$SAMPLES" --exclude "$old" --since "$GONE_AT")"
}

# wait_until <ms>
wait_until() { while [ "$(now_ms)" -lt "$1" ]; do sleep 1; done; }

row_T63() {
  local app="/Applications/$APP_NAME" old closed mark until
  start_held T63 "$app"
  old="$(first_process)"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"
  closed="$(analyze closed-at "$SAMPLES")" || row_fail "the settings window did not close"
  mark=$((HELD_AT > closed ? HELD_AT : closed))
  tell_person "Stay off the trackpad. When TAP NOW appears, tap the gesture once a second until this row ends."
  wait_gone "$old" 100 || row_fail "the old copy was still running 100 s after the window closed"
  tell_person "TAP NOW: the gesture, once a second."
  after_exit "v2 start" "$old"
  within "the old process ended after the later of the hold and the window closing" $((GONE_AT - mark)) 60000 63000
  within "v2 started after the old process ended" $((NEW_AT - GONE_AT)) 0 1000
  check "the new process runs from /Applications with --after-update" process_runs "$NEW_PID" "$app"
  check "the bundle is v2" test "$(bundle_version "$app")" = 2000
  check_gesture "gesture after the hand-over" "$GONE_AT"
  check "no window from any other process, UIElement, neither the app nor a Sparkle helper frontmost" \
    analyze quiet "$SAMPLES" --since "$closed" --forbid-owner SecurityAgent --no-new-windows --allow-owner "$GESTURE_APP_NAME"
  until=$((NEW_AT + 180000))
  wait_until "$until"
  expect_count "feed requests from v2 for 180 s" -eq 0 count_in feed "$NEW_AT" "$until"
  expect_count "helper jobs listed at 180 s" -eq 0 count_helper_jobs
  check "the pid of v2 is unchanged at 180 s" kill -0 "$NEW_PID"
  check "one app process over the 180 s" analyze pids "$SAMPLES" --since "$NEW_AT" --max-distinct 1
  ask_person "Open Trackpad Launcher E2E with Spotlight (Command-Space, its name, Return), then press Return here."
  wait_for 10 analyze window-open "$SAMPLES"
  check "Spotlight opened the settings window" analyze window-open "$SAMPLES"
}

row_T64() {
  local app="/Applications/$APP_NAME" old lifted gone
  ask_person "Rest one finger on the trackpad and leave it there. With the other hand press Return here: the run starts."
  start_held T64 "$app"
  old="$(first_process)"
  sleep 90
  check "a finger resting past 90 s kept the old copy alive" kill -0 "$old"
  ask_person "Lay a palm on the trackpad, lift the finger, and press Return here. Keep the palm down."
  sleep 90
  check "a palm resting 90 s kept the old copy alive" kill -0 "$old"
  ask_person "Lift the palm and press Return here the moment it is off."
  lifted="$(now_ms)"
  wait_gone "$old" 100 || row_fail "the old copy did not end within 100 s of the lift"
  wait_for 5 analyze gone-at "$SAMPLES" --pid "$old"
  gone="$(analyze gone-at "$SAMPLES" --pid "$old")"
  within "the old process ended after the lift, the Return pressed up to 3 s late" $((gone - lifted)) 57000 63000
}

row_T65() {
  local app="/Applications/$APP_NAME" started asked pid closed
  use_feed v2 || row_fail "cannot render the feed"
  set_control "payload=hold"
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler T65 "$app"
  started="$(now_ms)"
  launch_hidden "$app"
  wait_count 60 payload "$started" 1 || row_fail "no download began"
  pid="$(first_process)"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"
  closed="$(analyze closed-at "$SAMPLES")" || row_fail "the settings window did not close"
  asked="$(now_ms)"
  ask_person "Tap the gesture once, then press Return here."
  check_gesture "gesture during the stalled download, a person's reaction included" "$asked" 60000
  set_control "payload=reset"
  sleep 5
  set_control ""
  check "v1 keeps running after the reset" kill -0 "$pid"
  check "the bundle is still v1" test "$(bundle_version "$app")" = 1000
  check "nothing showed" analyze quiet "$SAMPLES" --since "$closed" --forbid-owner SecurityAgent --no-new-windows \
    --allow-owner "$GESTURE_APP_NAME"
  if ! wait_count 20 payload "$started" 2; then
    stop_app
    set_last_check $((30 * 3600))
    launch_hidden "$app"
    wait_count 60 payload "$started" 2 || row_fail "no second GET followed the reset"
  fi
  wait_job 120 -sparkle-updater || ROW_FAILS+=("the second GET did not complete the download")
  expect_count "archive GETs" -ge 2 count_in payload "$started"
}

row_T66() {
  local app="/Applications/$APP_NAME" round started first total inside good=0
  use_feed v2 || row_fail "cannot render the feed"
  for round in $(seq 1 20); do
    reset_world
    install_copy v1 "$app"
    set_control "feed=503once"
    set_last_check $((30 * 3600))
    started="$(now_ms)"
    launch_hidden "$app"
    if wait_count 30 feed "$started" 1; then
      first="$(analyze first-at "$LOG" --kind feed --since "$started")"
      sleep 3
      total="$(count_in feed "$started")"
      inside="$(count_in feed "$started" $((first + 2000)))"
      if [ "$total" = 2 ] && [ "$inside" = 2 ]; then
        good=$((good + 1))
      else
        ROW_NOTES+=("round $round: $total feed requests, $inside within 2 s")
      fi
    else
      ROW_NOTES+=("round $round: no feed request")
    fi
    stop_app
  done
  expect_count "rounds of 20 with exactly 2 feed requests within 2 s" -eq 20 echo "$good"

  reset_world
  install_copy v1 "$app"
  set_control "feed=503"
  set_last_check $((30 * 3600))
  started="$(now_ms)"
  launch_hidden "$app"
  sleep 60
  expect_count "feed requests in 60 s against a feed that always fails" -eq 2 count_in feed "$started"
}

# t67_case <label> <description> <yes|no: the archive is asked for> <build> [feed.py command and arguments]...
t67_case() {
  local label="$1" description="$2" wanted="$3" build="$4" app="/Applications/$APP_NAME" started later
  shift 4
  reset_world
  use_feed "$build" || row_fail "$description: cannot render the feed"
  if [ $# -gt 0 ]; then edit_feed "$@" || row_fail "$description: cannot edit the feed"; fi
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler "T67-$label" "$app"
  started="$(now_ms)"
  launch_hidden "$app"
  wait_count 45 feed "$started" 1 || { ROW_FAILS+=("$description: no feed request"); return; }
  if [ "$wanted" = yes ]; then
    wait_count 60 payload "$started" 1 || { ROW_FAILS+=("$description: the archive was never asked for"); return; }
    sleep 80
  else
    sleep 20
    expect_count "$description: asset requests" -eq 0 count_in download "$started"
  fi
  check "$description: v1 never replaced" analyze whole "$SAMPLES" --app "$app" --versions 1000
  expect_count "$description: processes" -eq 1 count_app_processes
  check "$description: one pid throughout" analyze pids "$SAMPLES" --since "$started" --max-distinct 1
  expect_count "$description: helper jobs listed" -eq 0 count_helper_jobs
  check "$description: nothing shown" analyze quiet "$SAMPLES" --since "$started" --forbid-owner SecurityAgent --max-app-windows 0
  if [ "$wanted" = yes ]; then
    stop_app
    set_last_check $((30 * 3600))
    later="$(now_ms)"
    launch_hidden "$app"
    wait_count 60 payload "$later" 1
    expect_count "$description: a later check asked for the archive again" -ge 1 count_in payload "$later"
  fi
}

row_T67() {
  local version
  ensure_build v2dev 2.0.0 2000 appledev || row_fail "cannot build v2 signed with Apple Development"
  ensure_build v2plain 2.0.0 2000 unnotarised || row_fail "cannot build v2 signed but not notarised"
  ensure_build v2other 2.0.0 2000 release "$E2E_ID.other" || row_fail "cannot build v2 with another bundle identifier"
  version="$(version_of v2)"
  t67_case tampered "a tampered EdDSA signature" yes v2 tamper-signature "$version"
  t67_case appledev "v2 signed by Apple Development" yes v2dev
  t67_case plain "v2 signed by the Developer ID, not notarised" yes v2plain
  t67_case otherid "v2 with another bundle identifier" yes v2other
  t67_case dmg "an enclosure of a .dmg" no v2 replace "$version" .aar .dmg
  t67_case host "an enclosure on another host" no v2 replace "$version" "http://127.0.0.1:$PORT" "http://localhost:$PORT"
}

row_T68() {
  local folder="/Applications/$FOLDER_NAME" app="/Applications/$FOLDER_NAME/$APP_NAME" old started
  start_held T68 "$app"
  old="$(first_process)"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"
  chmod a-w "$folder"
  tell_person "Stay off the trackpad. When TAP NOW appears, tap the gesture once a second until this row ends."
  wait_gone "$old" 150 || row_fail "the old copy did not end within 150 s"
  tell_person "TAP NOW: the gesture, once a second."
  after_exit "the failed install" "$old"
  within "the old copy was opened after the exit" $((NEW_AT - GONE_AT)) 5000 7000
  check "the opened copy is the one in the folder, with --after-update" process_runs "$NEW_PID" "$app"
  check "the old copy is whole and verifies" /usr/bin/codesign --verify --strict "$app"
  check "the bundle is v1" test "$(bundle_version "$app")" = 1000
  check_gesture "gesture after the failed install" "$GONE_AT"
  wait_until $((NEW_AT + 120000))
  expect_count "feed requests for 120 s after the reopen" -eq 0 count_in feed "$NEW_AT" $((NEW_AT + 120000))
  chmod u+w "$folder"
  stop_app
  set_last_check $((30 * 3600))
  started="$(now_ms)"
  launch_hidden "$app"
  wait_for 300 analyze first-version "$SAMPLES" --app "$app" --version 2000 --since "$started"
  check "with the parent writable the next start installed v2" analyze first-version "$SAMPLES" --app "$app" --version 2000 --since "$started"
}

# t69_verify <description> <armed: yes|no>: what must hold once the kill's effects have settled.
t69_verify() {
  local description="$1" armed="$2" app="/Applications/$APP_NAME"
  sleep 25
  check "$description: every read was a whole v1 or v2" analyze whole "$SAMPLES" --app "$app" --versions 1000,2000
  check "$description: the copy verifies" /usr/bin/codesign --verify --strict "$app"
  if [ "$armed" = yes ]; then
    expect_count "$description: processes after the kill, hand-over armed" -le 1 count_app_processes
  else
    expect_count "$description: processes after the kill, hand-over not armed" -eq 0 count_app_processes
  fi
  expect_count "$description: helper jobs left" -eq 0 count_helper_jobs
  stop_app
  launch_hidden "$app"
  sleep 8
  expect_count "$description: a relaunch runs with" -eq 1 count_app_processes
  stop_app
}

t69_app_round() {
  local round="$1" app="/Applications/$APP_NAME" delay armed=no
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_last_check $((30 * 3600))
  start_sampler "T69-app-$round" "$app"
  launch_hidden "$app"
  delay=$((RANDOM % 75 + 1))
  sleep "$delay"
  job_listed .hand-over && armed=yes
  pkill -9 -f "$APP_NAME/Contents/MacOS"
  job_listed .hand-over && armed=yes
  t69_verify "app killed at $delay s" "$armed"
}

# Autoupdate's command line names the bundle identifier, as its path does.
kill_autoupdate() {
  local end=$((SECONDS + 2))
  while [ "$SECONDS" -lt "$end" ]; do
    pkill -9 -f "Autoupdate.*$E2E_ID|$E2E_ID.*Autoupdate" && return 0
    sleep 0.02
  done
  return 1
}

t69_installer_round() {
  local round="$1" app="/Applications/$APP_NAME" old
  reset_world
  start_held "T69-installer-$round" "$app"
  old="$(first_process)"
  wait_gone "$old" 150 || { ROW_FAILS+=("installer round $round: the old copy never ended"); return; }
  kill_autoupdate || ROW_FAILS+=("installer round $round: no Autoupdate to kill in the 2 s after the exit")
  t69_verify "Autoupdate killed, round $round" yes
}

row_T69() {
  local round
  for round in $(seq 1 20); do t69_app_round "$round"; done
  for round in $(seq 1 10); do t69_installer_round "$round"; done
}

row_T70() {
  local folder="/Applications/$FOLDER_NAME" app="/Applications/$FOLDER_NAME/$APP_NAME" started
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T70 "$app"
  set_last_check 86380
  started="$(now_ms)"
  launch_hidden "$app" --after-update
  sleep 5
  chmod a-w "$folder"
  wait_count 60 feed "$started" 1 || row_fail "the stamp never fired a check"
  sleep 150
  check "no password window appeared" analyze absent "$SAMPLES" --owner SecurityAgent
  check "the update did not install" analyze whole "$SAMPLES" --app "$app" --versions 1000
  check "nothing shown" analyze quiet "$SAMPLES" --since "$started" --forbid-owner SecurityAgent --max-app-windows 0
  expect_count "helper jobs listed at the end" -eq 0 count_helper_jobs
}

row_T71() {
  local app="/Applications/$APP_NAME" old later
  start_held T71 "$app"
  old="$(first_process)"
  launchctl remove "$E2E_ID-sparkle-updater"
  sleep 90
  check "no hand-over job at the mark" test "$(job_listed .hand-over && echo listed)" != listed
  check "v1 still runs with the same pid" kill -0 "$old"
  check "the bundle never changed" analyze whole "$SAMPLES" --app "$app" --versions 1000
  stop_app
  remove_launch_jobs
  set_last_check $((30 * 3600))
  later="$(now_ms)"
  launch_hidden "$app"
  wait_count 60 payload "$later" 1
  expect_count "a later check downloaded again" -ge 1 count_in payload "$later"
}

row_T72() {
  local app="/Applications/$APP_NAME" started asked
  ensure_build nokey 1.0.0 1000 release "$E2E_ID" emptykey || row_fail "cannot build the copy with an empty update key"
  use_feed v2 || row_fail "cannot render the feed"
  install_copy nokey "$app"
  set_last_check $((30 * 3600))
  start_sampler T72 "$app"
  started="$(now_ms)"
  launch_hidden "$app"
  sleep 30
  expect_count "requests in 30 s" -eq 0 count_in any "$started"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"
  asked="$(now_ms)"
  ask_person "Tap the gesture once, then press Return here."
  check_gesture "gesture with an empty key, a person's reaction included" "$asked" 60000
  expect_count "requests at the end" -eq 0 count_in any "$started"
  check "nothing shown beyond the settings window" analyze quiet "$SAMPLES" --since "$started" --forbid-owner SecurityAgent --max-app-windows 1
}

# ---------------------------------------------------------------------------------------------------------------
# The report

write_report() {
  REPORT_WRITTEN=1
  local id function title status evidence
  {
    echo "# Update end-to-end report"
    echo
    echo "- Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "- Commit: $COMMIT"
    echo "- macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "- Xcode: $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
    echo "- Mode: $MODE${SKIP_REASON:+ ($SKIP_REASON)}"
    if [ -s "$FRAME_NOTES" ]; then
      echo
      echo "## Frame"
      echo
      sed 's/^/- /' "$FRAME_NOTES"
    fi
    echo
    echo "## Rows"
    echo
    echo "| Row | What it proves | Result | Evidence |"
    echo "|-----|----------------|--------|----------|"
    while IFS='|' read -r id function title; do
      status="NOT RUN"
      evidence="not selected"
      if [ -f "$RESULTS" ] && grep -q "^$id$TAB" "$RESULTS"; then
        IFS=$'\t' read -r _ status evidence <<<"$(grep "^$id$TAB" "$RESULTS" | tail -1)"
      fi
      echo "| $id | $title | $status | ${evidence//|/\\|} |"
    done < <(rows_table)
  } > "$REPORT"
  log "report: $REPORT"
}

# ---------------------------------------------------------------------------------------------------------------

main() {
  rm -f "$RESULTS" "$ROW_RESULT"
  rm -rf "$SERVE/assets"
  log "mode: $MODE${SKIP_REASON:+ ($SKIP_REASON)}; commit $COMMIT; port $PORT"
  ensure_key
  ensure_sparkle_tools
  ensure_sampler

  # An old run's processes would answer on the port, and an old copy would shadow this run's.
  reset_world
  local kind=release
  ensure_build v1 1.0.0 1000 "$kind" || die "cannot build v1."
  ensure_build v2 2.0.0 2000 "$kind" || die "cannot build v2."

  start_server
  frame_check

  local id function title
  while IFS='|' read -r id function title; do
    if [ -n "$SELECTED" ] && ! grep -qw "$id" <<<"$SELECTED"; then continue; fi
    run_row "$id" "$function" "$title"
  done < <(rows_table)

  write_report
  local failures
  failures="$(grep -c "${TAB}FAIL$TAB" "$RESULTS" 2>/dev/null)"
  [ "${failures:-0}" -eq 0 ] || exit 1
  exit 0
}

main
