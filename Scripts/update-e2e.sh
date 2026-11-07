#!/bin/bash
# Puts two real, patched builds of Trackpad Launcher through a real Sparkle update against a local server, and writes
# build/update-e2e/report.md. The in-memory tests prove the app's decisions; this proves Sparkle's behaviour on the
# wire and on screen, which fakes hid in two earlier update plans.
#
#   Scripts/update-e2e.sh               every row; needs a person with a Developer ID, a notary profile and sudo
#   Scripts/update-e2e.sh T30 T31       only those rows; most stop for a person (T35 and T36 also want a standard account
#                                       named in E2E_STANDARD_USER, logged in at the screen; T41 is done by hand)
#   Scripts/update-e2e.sh --check       no credentials: builds ad-hoc signed, renders the feed through
#                                       release.sh --feed-only, starts the server and the sampler, and writes the
#                                       report with every row SKIPPED
#   Scripts/update-e2e.sh --build-only  builds, signs and notarises every copy the rows use, into the cache, and stops:
#                                       no copy is installed or opened and no person is needed, so a later run starts
#                                       at its first row
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
T28|row_T28|a login start downloads and installs at once; v2 runs silently, gestures work, and v2 makes no request
T29|row_T29|opening the window during a login update checks nothing and shows no card; v2 then opens with its window
T30|row_T30|each opening of the window probes once; the card shows; Update now downloads and opens v2 with its window
T31|row_T31|every request carries no cookie, validator, query or identifying header, on both versions
T32|row_T32|the highest newer release that runs on this Mac is the one downloaded, never an older or pre-release one
T33|row_T33|no request while the window is closed; a failed feed is tried twice and not hammered
T34|row_T34|a failed install or a killed process leaves a working copy and no job; a reset download returns the card
T35|row_T35|an update that is not the publisher's installs nothing and starts no installer
T36|row_T36|on a standard account a login start asks nothing; Update now asks for a password only after the download
T37|row_T37|Quit during an update ends the app at once; after a probe no updater and no WebKit remain
T41|row_T41|by hand: logout, restart and shutdown proceed at once during a login download
TABLE
}

row_ids() { rows_table | cut -d'|' -f1; }

# ---------------------------------------------------------------------------------------------------------------
# Arguments and mode

CHECK=0
BUILD_ONLY=0
SELECTED=""
for argument in "$@"; do
  case "$argument" in
    --check) CHECK=1 ;;
    --build-only) BUILD_ONLY=1 ;;
    -h | --help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    T[0-9]*)
      row_ids | grep -qx "$argument" || die "no row $argument; rows: $(row_ids | tr '\n' ' ')"
      SELECTED="$SELECTED $argument" ;;
    *) die "usage: update-e2e.sh [--check | --build-only] [row...]" ;;
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
  local paths="TrackpadLauncher LauncherKit/Sources LauncherKit/Package.swift LauncherKit/Vendor Config project.yml assets"
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
  if [ -n "$STD_USER" ] && sudo -n true 2>/dev/null; then
    for pattern in "${PROCESS_PATTERNS[@]}"; do sudo -n pkill -9 -f "$pattern" 2>/dev/null; done
  fi
  sleep 0.5
  for pattern in "${PROCESS_PATTERNS[@]}"; do pkill -9 -f "$pattern" 2>/dev/null; done
  return 0
}

stop_app() {
  pkill -f "$APP_NAME/Contents/MacOS" 2>/dev/null
  [ "$STD_ACTIVE" = 1 ] && sudo -n pkill -f "$APP_NAME/Contents/MacOS" 2>/dev/null
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
  [ "$STD_ACTIVE" = 1 ] && sudo -n pkill -f "$STD_DIR/sampler" 2>/dev/null
  rm -f "$SAMPLER_PIDFILE"
}

set_control() { printf '%s\n' "$*" > "$CONTROL"; }

# Everything a row's run can leave behind, then an empty request log and a server that behaves.
reset_world() {
  stop_sampler
  watch_sparkle_stop
  kill_app_processes
  remove_launch_jobs
  remove_copies
  defaults delete "$E2E_ID" 2>/dev/null
  local library="$HOME/Library"
  rm -rf "$library/Caches/$E2E_ID" "$library/HTTPStorages/$E2E_ID" "$library/HTTPStorages/$E2E_ID.binarycookies" \
    "$library/Preferences/$E2E_ID.plist" "$library/Application Support/$E2E_ID" "$library/WebKit/$E2E_ID" \
    "$library/Saved Application State/$E2E_ID.savedState" "$library/Logs/$E2E_ID"
  reset_std
  [ -d "$SERVE" ] && { : > "$LOG"; set_control ""; }
  return 0
}

stop_server() {
  [ -f "$SERVER_PIDFILE" ] || return 0
  kill "$(cat "$SERVER_PIDFILE")" 2>/dev/null
  rm -f "$SERVER_PIDFILE"
}

# Sparkle's own processes for the e2e copy: its framework's helpers, Autoupdate and the copy of it under the cache.
SPARKLE_PROCESSES="$APP_NAME/Contents/Frameworks/Sparkle.framework|Autoupdate.*$E2E_ID|$E2E_ID.*Autoupdate|$E2E_ID.*org.sparkle-project"
SPARKLE_SEEN_FILE="$SCRATCH/sparkle-seen.txt"
WATCH_PIDFILE="$SCRATCH/watch.pid"
SUDO_PIDFILE="$SCRATCH/sudo.pid"

count_sparkle_processes() { pgrep -f "$SPARKLE_PROCESSES" 2>/dev/null | wc -l | tr -d ' '; }

# watch_sparkle_start: records every 100 ms in which a Sparkle process of the copy exists, so a row can say none ever did.
watch_sparkle_start() {
  watch_sparkle_stop
  : > "$SPARKLE_SEEN_FILE"
  ( while :; do pgrep -f "$SPARKLE_PROCESSES" >/dev/null 2>&1 && echo seen >> "$SPARKLE_SEEN_FILE"; sleep 0.1; done ) &
  echo $! > "$WATCH_PIDFILE"
  disown
}

watch_sparkle_stop() {
  [ -f "$WATCH_PIDFILE" ] || return 0
  kill "$(cat "$WATCH_PIDFILE")" 2>/dev/null
  rm -f "$WATCH_PIDFILE"
}

sparkle_seen() { wc -l < "$SPARKLE_SEEN_FILE" | tr -d ' '; }

# The download Sparkle keeps until it installs; a refused update must leave none of it.
persistent_files() { find "$(user_home)/Library/Caches/$E2E_ID/org.sparkle-project.Sparkle/PersistentDownloads" -type f 2>/dev/null | wc -l | tr -d ' '; }

# --- the standard account: rows T35 and T36 run the copy as E2E_STANDARD_USER, whose session is on the screen.
STD_USER="${E2E_STANDARD_USER:-}"
STD_ACTIVE=0
STD_DIR=/tmp/update-e2e-std

std_home() { dscl . -read "/Users/$STD_USER" NFSHomeDirectory 2>/dev/null | awk '{ print $2 }'; }

# std_unready: prints why the standard-account rows cannot run; nothing when they can.
std_unready() {
  [ -n "$STD_USER" ] || { echo "E2E_STANDARD_USER names no account"; return; }
  id "$STD_USER" >/dev/null 2>&1 || { echo "there is no account $STD_USER"; return; }
  if dseditgroup -o checkmember -m "$STD_USER" admin >/dev/null 2>&1; then echo "$STD_USER is an administrator"; return; fi
  [ "$(stat -f %Su /dev/console)" = "$STD_USER" ] || { echo "$STD_USER is not the account at the screen (switch to it with fast user switching)"; return; }
  sudo -n true 2>/dev/null || echo "sudo has no cached credentials (run sudo -v first)"
}

as_std() { sudo -n launchctl asuser "$(id -u "$STD_USER")" sudo -n -u "$STD_USER" "$@"; }

# as_user <command...>: as the account the row runs the copy for.
as_user() { if [ "$STD_ACTIVE" = 1 ]; then as_std "$@"; else "$@"; fi; }

user_home() { if [ "$STD_ACTIVE" = 1 ]; then std_home; else echo "$HOME"; fi; }

console_left() { [ "$(stat -f %Su /dev/console)" != "$STD_USER" ]; }

# keep_sudo: the rows that need root run for long, so the credentials are refreshed until the script ends.
keep_sudo() {
  sudo -v || return 1
  [ -f "$SUDO_PIDFILE" ] && return 0
  ( while :; do sudo -n true 2>/dev/null; sleep 40; done ) &
  echo $! > "$SUDO_PIDFILE"
  disown
}

stop_keep_sudo() {
  [ -f "$SUDO_PIDFILE" ] || return 0
  kill "$(cat "$SUDO_PIDFILE")" 2>/dev/null
  rm -f "$SUDO_PIDFILE"
}

# Everything the copy left in the standard account's home and session.
reset_std() {
  [ -n "$STD_USER" ] || return 0
  local home library
  home="$(std_home)"
  [ -d "$home" ] || return 0
  sudo -n true 2>/dev/null || return 0
  sudo -n pkill -f "$STD_DIR/sampler" 2>/dev/null
  sudo -n pkill -f "$APP_NAME/Contents/" 2>/dev/null
  sudo -n -u "$STD_USER" defaults delete "$E2E_ID" 2>/dev/null
  as_std launchctl list 2>/dev/null | awk -v id="$E2E_ID" 'index($3, id) { print $3 }' |
    while read -r label; do as_std launchctl remove "$label" 2>/dev/null; done
  library="$home/Library"
  sudo -n rm -rf "$library/Caches/$E2E_ID" "$library/HTTPStorages/$E2E_ID" "$library/HTTPStorages/$E2E_ID.binarycookies" \
    "$library/Preferences/$E2E_ID.plist" "$library/Application Support/$E2E_ID" "$library/WebKit/$E2E_ID" \
    "$library/Saved Application State/$E2E_ID.savedState" "$library/Logs/$E2E_ID" "$STD_DIR" 2>/dev/null
  return 0
}

leftovers() {
  local found=""
  if [ -n "$STD_USER" ] && sudo -n true 2>/dev/null && [ -d "$(std_home)" ]; then
    sudo -n -u "$STD_USER" defaults read "$E2E_ID" >/dev/null 2>&1 && found="$found standard-account-defaults-domain"
    [ -d "$(std_home)/Library/Caches/$E2E_ID" ] && found="$found standard-account-cache"
  fi
  if sudo -n true 2>/dev/null && sudo -n sfltool dumpbtm 2>/dev/null | grep -q "$E2E_ID"; then found="$found login-item"; fi
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
  watch_sparkle_stop
  stop_server
  reset_world
  stop_keep_sudo
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

# launch_login <app>: the copy started the way a login starts it. launch_hand <app>: opened by hand, with its window; on a
# running copy it is the window's opening again.
launch_login() { as_user /usr/bin/open -g "$1" --args --at-login; }
launch_hand() { as_user /usr/bin/open "$1"; }

# pid_since <ms>: the first app process the sampler saw from then; fails if none.
pid_since() {
  wait_for 20 analyze new-pid "$SAMPLES" --since "$1" || return 1
  analyze new-pid "$SAMPLES" --since "$1" | awk '{ print $2 }'
}

# start_sampler <label> [app path]...: SAMPLES names the file the rows read afterwards.
start_sampler() {
  local label="$1" arguments=() path
  shift
  SAMPLES="$SCRATCH/samples-$label.jsonl"
  for path in "$@"; do arguments+=(--app "$path"); done
  if [ "$STD_ACTIVE" = 1 ]; then
    # The sampler must run in the standard account's session to see its screen, from a place that account can read.
    mkdir -p "$STD_DIR" && chmod 777 "$STD_DIR" && cp "$SAMPLER" "$STD_DIR/sampler" && chmod 755 "$STD_DIR/sampler"
    SAMPLES="$STD_DIR/samples-$label.jsonl"
    as_std env "SAMPLER_BUNDLE_ID=$E2E_ID" "$STD_DIR/sampler" "$SAMPLES" "${arguments[@]}" >/dev/null 2>&1 &
  else
    SAMPLER_BUNDLE_ID="$E2E_ID" "$SAMPLER" "$SAMPLES" "${arguments[@]}" >/dev/null 2>&1 &
  fi
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

first_process() { app_processes | head -1; }

# process_runs <pid> <app path> <arguments>: the process runs that copy's executable with exactly those arguments.
process_runs() { ps -o args= -p "$1" | grep -q -- "^$2/Contents/MacOS/.* $3\$"; }

# after_exit <description> <old pid>: once the old pid has ended, finds the copy that follows it. Sets GONE_AT, NEW_AT and
# NEW_PID from the sampler.
after_exit() {
  local description="$1" old="$2"
  wait_for 60 analyze gone-at "$SAMPLES" --pid "$old" || row_fail "$description: the sampler never saw the old process end"
  GONE_AT="$(analyze gone-at "$SAMPLES" --pid "$old")"
  wait_for 20 analyze new-pid "$SAMPLES" --exclude "$old" --since "$GONE_AT" || row_fail "$description: no copy started after the old one ended"
  read -r NEW_AT NEW_PID <<<"$(analyze new-pid "$SAMPLES" --exclude "$old" --since "$GONE_AT")"
}

# wait_until <ms>
wait_until() { while [ "$(now_ms)" -lt "$1" ]; do sleep 1; done; }

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

# In the standard account's session the instructions arrive as dialogs there, because the person sits at that screen.
std_dialog() { as_std osascript -e "display dialog \"${1//\"/\'}\" buttons {$2} default button $3 with title \"Trackpad Launcher E2E\"" 2>/dev/null; }

# ask_person <instruction>: what nothing can synthesise. The time after the Return is the row's clock.
ask_person() {
  if [ "$STD_ACTIVE" = 1 ]; then
    printf '\n>>> %s\n' "$1" > /dev/tty
    std_dialog "$1" '"Ready"' 1 >/dev/null
    return 0
  fi
  printf '\n>>> %s\n    Press Return here when ready: ' "$1" > /dev/tty
  read -r _ < /dev/tty
}

# tell_person <instruction>: for a moment the script finds for itself, so nothing waits on a Return.
tell_person() {
  printf '\n>>> %s\n' "$1" > /dev/tty
  if [ "$STD_ACTIVE" = 1 ]; then
    as_std osascript -e "display notification \"${1//\"/\'}\" with title \"Trackpad Launcher E2E\"" >/dev/null 2>&1 &
  fi
}

# ask_yes_no <question>: prints yes, no or skip.
ask_yes_no() {
  local answer
  if [ "$STD_ACTIVE" = 1 ]; then
    printf '\n>>> %s\n' "$1" > /dev/tty
    answer="$(std_dialog "$1" '"No","Yes"' 2 | sed -n 's/.*button returned:\(.*\)/\1/p')"
    case "$answer" in Yes) echo yes ;; *) echo no ;; esac
    return 0
  fi
  printf '\n>>> %s [y/n/s] ' "$1" > /dev/tty
  read -r answer < /dev/tty
  case "$answer" in y | Y | yes) echo yes ;; s | S) echo skip ;; *) echo no ;; esac
}

# The gesture rows time a person's 1-finger gesture through the app's real settings window: this app is assigned to it,
# so its reaching the front is the only outside sign that gestures run.
GESTURE_APP_ID=com.apple.calculator
GESTURE_APP_NAME=Calculator

quit_gesture_app() { as_user osascript -e "tell application \"$GESTURE_APP_NAME\" to quit" >/dev/null 2>&1; return 0; }

# assign_gesture <app path>: the running copy's settings window opens, the person assigns the app and closes it again.
assign_gesture() {
  quit_gesture_app
  as_user /usr/bin/open -g "$1"
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

# confirm <description> <question>: what only a person's eyes settle.
confirm() {
  case "$(ask_yes_no "$2")" in
    yes) ROW_NOTES+=("$1: confirmed by the person") ;;
    skip) ROW_FAILS+=("$1: not answered") ;;
    *) ROW_FAILS+=("$1: the person answered no") ;;
  esac
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
        grep -E "^ +status: Accepted" >/dev/null || { log "notarisation of $name was not accepted; see $build_log"; return 1; }
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

row_T28() {
  local app="/Applications/$APP_NAME" launched old download
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T28-assign "$app"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"
  stop_app
  stop_sampler
  : > "$LOG"
  ask_person "Rest two fingers on the trackpad and leave them there. With the other hand press Return here: the login start begins."
  start_sampler T28 "$app"
  launched="$(now_ms)"
  launch_login "$app"
  tell_person "Keep your fingers resting. When TAP NOW appears, tap the gesture once a second until this row ends."
  old="$(pid_since "$launched")" || row_fail "the login start never ran"
  wait_count 30 feed "$launched" 1 || row_fail "no feed request came with no input"
  wait_count 30 payload "$launched" 1 || row_fail "no asset request came with no input"
  download="$(analyze first-at "$LOG" --kind payload --since "$launched")"
  after_exit "login install" "$old"
  tell_person "TAP NOW: the gesture, once a second."
  within "v2 started after the asset request" $((NEW_AT - download)) 0 10000
  check "the new process runs from /Applications with --after-update only" process_runs "$NEW_PID" "$app" "--after-update"
  check "the bundle is v2" test "$(bundle_version "$app")" = 2000
  check_gesture "gesture after the hand-over" "$GONE_AT"
  check "no window from any process, UIElement, neither the app nor a Sparkle helper frontmost" \
    analyze quiet "$SAMPLES" --since "$launched" --forbid-owner SecurityAgent --max-app-windows 0 --no-new-windows \
    --allow-owner "$GESTURE_APP_NAME"
  wait_until $((NEW_AT + 180000))
  expect_count "requests from v2 for 180 s" -eq 0 count_in any "$NEW_AT"
  expect_count "helper jobs listed at 180 s" -eq 0 count_helper_jobs
  check "the pid of v2 is unchanged at 180 s" kill -0 "$NEW_PID"
}

row_T29() {
  local app="/Applications/$APP_NAME" launched old opened
  use_feed v2 || row_fail "cannot render the feed"
  set_control "payload=hold"
  install_copy v1 "$app"
  start_sampler T29 "$app"
  launched="$(now_ms)"
  launch_login "$app"
  wait_count 60 payload "$launched" 1 || row_fail "no download began"
  old="$(pid_since "$launched")" || row_fail "the login start never ran"
  opened="$(now_ms)"
  launch_hand "$app"
  wait_for 15 analyze window-open "$SAMPLES" || row_fail "the window did not open"
  sleep 15
  expect_count "feed requests after the window opened" -eq 0 count_in feed "$opened"
  confirm "no card in the window during the login update" "Does the settings window show NO update card?"
  check "the old copy is still running" kill -0 "$old"
  set_control "payload=release"
  after_exit "login update with the window open" "$old"
  check "v2 runs with --after-update --with-window" process_runs "$NEW_PID" "$app" "--after-update --with-window"
  wait_for 15 analyze window-open "$SAMPLES" || ROW_FAILS+=("v2 opened without its settings window")
  expect_count "app processes" -eq 1 count_app_processes
  check "the bundle is v2" test "$(bundle_version "$app")" = 2000
  sleep 30
  expect_count "feed requests at v2's start" -eq 0 count_in feed "$NEW_AT"
}

row_T30() {
  local app="/Applications/$APP_NAME" started opened pressed old
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T30 "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_for 30 analyze window-open "$SAMPLES" || row_fail "the copy opened by hand showed no window"
  wait_count 30 feed "$started" 1 || row_fail "the start made no probe"
  ask_person "Close the settings window with its red button."
  wait_for 15 window_closed || row_fail "the window did not close"
  sleep 3
  opened="$(now_ms)"
  launch_hand "$app"
  wait_for 15 analyze window-open "$SAMPLES" || row_fail "the window did not open"
  wait_count 15 feed "$opened" 1
  sleep 5
  expect_count "feed requests from the opening" -eq 1 count_in feed "$opened"
  expect_count "asset requests from the opening" -eq 0 count_in download "$opened"
  confirm "the card is the window's first group, above the gesture rows, reading Update available" \
    "Is there a card reading 'Update available' with an 'Update now' button above the gesture rows?"
  confirm "the arrow drifts about 4 pt every 3 s; tray, text and button stay still" \
    "Watch the card for ten seconds. Does only the arrow drift, about 4 pt every 3 s, with the tray, text and button still?"
  ask_person "Close the settings window with its red button."
  wait_for 15 window_closed || row_fail "the window did not close"
  sleep 3
  opened="$(now_ms)"
  launch_hand "$app"
  wait_for 15 analyze window-open "$SAMPLES" || row_fail "the window did not reopen"
  wait_count 15 feed "$opened" 1
  sleep 3
  expect_count "feed requests from the second opening" -eq 1 count_in feed "$opened"
  set_control "payload=hold"
  pressed="$(now_ms)"
  tell_person "Press 'Update now' in the settings window."
  wait_count 120 payload "$pressed" 1 || row_fail "Update now brought no asset request"
  confirm "the button is greyed and reads Updating…" "Does the card's button read 'Updating…' and look greyed out?"
  expect_count "feed requests between Update now and the asset GET" -eq 1 count_in feed "$pressed"
  check "the feed request came before the asset GET" test "$(analyze first-at "$LOG" --kind feed --since "$pressed")" -le \
    "$(analyze first-at "$LOG" --kind payload --since "$pressed")"
  old="$(first_process)"
  set_control "payload=release"
  after_exit "Update now" "$old"
  check "v2 runs with --after-update --with-window" process_runs "$NEW_PID" "$app" "--after-update --with-window"
  wait_for 15 analyze window-open "$SAMPLES" || ROW_FAILS+=("v2 opened without its settings window")
  confirm "v2's window shows no card" "Does the new window show NO update card?"
  expect_count "app processes" -eq 1 count_app_processes
  sleep 30
  expect_count "requests at v2's start" -eq 0 count_in any "$NEW_AT"
}

row_T31() {
  local app="/Applications/$APP_NAME" first second end old
  use_feed v2 || row_fail "cannot render the feed"
  defaults write "$E2E_ID" AppleLanguages -array de
  install_copy v1 "$app"
  start_sampler T31 "$app"
  first="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$first" 1 || row_fail "no probe"
  tell_person "Press 'Update now' in the settings window."
  wait_count 120 payload "$first" 1 || row_fail "Update now brought no asset request"
  old="$(first_process)"
  wait_gone "$old" 60 || row_fail "v1 did not hand over"
  wait_for 20 analyze new-pid "$SAMPLES" --exclude "$old" --since "$first" || row_fail "v2 never started"
  sleep 5
  stop_app
  second="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$second" 1 || row_fail "v2 made no probe"
  sleep 3
  stop_app
  end="$(now_ms)"
  expect_count "feed requests" -ge 2 count_in feed "$first"
  expect_count "downloads reached the redirect" -ge 1 count_in payload "$first"
  check "no query, cookie or validator; fixed User-Agent, Accept-Language, Accept-Encoding" \
    analyze privacy "$LOG" --since "$first" --until "$end"
  check "header sets of both versions" analyze same-headers "$LOG" "$first" "$second" "$second" "$end"
}

# One scenario of T32: v1 runs against a feed, started the way <mode> says (login, or card for the person pressing
# Update now, or probe for a window opening only); the paths asked for are the evidence.
t32_case() {
  local description="$1" feed="$2" mode="$3" wanted="$4" refused="$5" since
  reset_world
  stage_assets
  cp "$feed" "$SERVE/feed.xml"
  install_copy v1 "/Applications/$APP_NAME"
  start_sampler "T32-$mode"  "/Applications/$APP_NAME"
  since="$(now_ms)"
  if [ "$mode" = login ]; then launch_login "/Applications/$APP_NAME"; else launch_hand "/Applications/$APP_NAME"; fi
  wait_count 45 feed "$since" 1
  if [ "$mode" = card ]; then
    tell_person "Press 'Update now' in the settings window."
  fi
  [ -z "$wanted" ] || wait_count 120 release "$since" 1 "$wanted"
  sleep 12
  expect_count "$description: feed requests" -ge 1 count_in feed "$since"
  if [ -n "$wanted" ]; then expect_count "$description: asked for $wanted" -ge 1 count_in release "$since" "" "$wanted"; fi
  if [ -n "$refused" ]; then
    expect_count "$description: asked for $refused" -eq 0 count_in release "$since" "" "$refused"
  else
    expect_count "$description: asset requests" -eq 0 count_in download "$since"
    confirm "$description: no card" "Does the settings window show NO update card?"
  fi
  stop_app
}

row_T32() {
  local folder="$SCRATCH/t32" mid higher
  ensure_build mid 1.1.0 1100 release || row_fail "cannot build the 1.1.0 copy"
  mkdir -p "$folder"
  mid="$(version_of mid)"
  higher="$(version_of v2)"
  use_feed mid v2 || row_fail "cannot render the feed"
  cp "$SERVE/feed.xml" "$folder/both.xml"
  t32_case "1.1.0 and 2.0.0 offered, from the card" "$folder/both.xml" card "/v$higher/" "/v$mid/"
  t32_case "1.1.0 and 2.0.0 offered, at login" "$folder/both.xml" login "/v$higher/" "/v$mid/"

  $PY "$HELPERS/feed.py" set-minimum "$folder/both.xml" "$higher" 99.0 > "$folder/needs99.xml"
  t32_case "2.0.0 needing macOS 99.0, at login" "$folder/needs99.xml" login "/v$mid/" "/v$higher/"

  use_feed v1 || row_fail "cannot render the feed"
  edit_feed derive "$(version_of v1)" 0.9.0 900 || row_fail "cannot derive a lower release"
  edit_feed derive "$(version_of v1)" 1.5.0 1500 || row_fail "cannot derive a higher release"
  edit_feed set-channel 1.5.0 beta || row_fail "cannot make the higher release a pre-release"
  cp "$SERVE/feed.xml" "$folder/not-newer.xml"
  t32_case "the running build, a lower one and a pre-release above it" "$folder/not-newer.xml" probe "" ""
}

row_T33() {
  local app="/Applications/$APP_NAME" started first mark
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T33 "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$started" 1 || row_fail "the start made no probe"
  ask_person "Close the settings window with its red button, then leave the trackpad and the Mac alone for ten minutes."
  wait_for 15 window_closed || row_fail "the window did not close"
  mark="$(now_ms)"
  sleep 600
  expect_count "requests in 10 minutes with the window closed" -eq 0 count_in any "$mark"

  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_control "feed=503once"
  started="$(now_ms)"
  launch_login "$app"
  wait_count 30 feed "$started" 1 || row_fail "the login start made no feed request"
  first="$(analyze first-at "$LOG" --kind feed --since "$started")"
  sleep 8
  expect_count "feed requests after one 503" -eq 2 count_in feed "$started"
  expect_count "feed requests within 5 s of the first" -eq 2 count_in feed "$started" $((first + 5000))
  stop_app

  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_control "feed=503"
  started="$(now_ms)"
  launch_login "$app"
  sleep 60
  expect_count "feed requests in 60 s against a feed that always fails" -eq 2 count_in feed "$started"
}

# Where a failed install leaves the person: <mode> is login or card.
t34_failed_install() {
  local mode="$1" folder="/Applications/$FOLDER_NAME" app="/Applications/$FOLDER_NAME/$APP_NAME" started old suffix
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_control "payload=hold"
  start_sampler "T34-$mode" "$app"
  started="$(now_ms)"
  if [ "$mode" = login ]; then
    launch_login "$app"
    suffix="--after-update"
  else
    launch_hand "$app"
    wait_count 30 feed "$started" 1 || row_fail "$mode: no probe"
    tell_person "Press 'Update now' in the settings window."
    suffix="--after-update --with-window"
  fi
  wait_count 120 payload "$started" 1 || row_fail "$mode: no download began"
  old="$(pid_since "$started")" || row_fail "$mode: the app never ran"
  chmod a-w "$folder"
  set_control "payload=release"
  after_exit "$mode failed install" "$old"
  within "$mode: the old copy was opened after the exit" $((NEW_AT - GONE_AT)) 5000 7000
  check "$mode: the opened copy is the one in the folder, with $suffix" process_runs "$NEW_PID" "$app" "$suffix"
  check "$mode: the old copy is whole and verifies" /usr/bin/codesign --verify --strict "$app"
  check "$mode: the bundle is v1" test "$(bundle_version "$app")" = 1000
  check "$mode: no password window appeared" analyze absent "$SAMPLES" --owner SecurityAgent
  if [ "$mode" = login ]; then
    check "login: nothing shown" analyze quiet "$SAMPLES" --since "$started" --forbid-owner SecurityAgent --max-app-windows 0
  else
    wait_for 15 analyze window-open "$SAMPLES" || ROW_FAILS+=("card: v1 did not reopen with its window")
  fi
  sleep 40
  expect_count "$mode: requests for 40 s after the reopen" -eq 0 count_in any "$NEW_AT"
  chmod u+w "$folder"
  stop_app
  launch_hand "$app"
  wait_for 15 analyze window-open "$SAMPLES"
  confirm "$mode: the next opening shows the card" "Does the settings window show the update card ('Update available')?"
}

t34_reset() {
  local app="/Applications/$APP_NAME" started pid
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  set_control "payload=hold"
  start_sampler T34-reset "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$started" 1 || row_fail "reset: no probe"
  tell_person "Press 'Update now' in the settings window."
  wait_count 120 payload "$started" 1 || row_fail "reset: no download began"
  pid="$(first_process)"
  set_control "payload=reset"
  sleep 6
  set_control ""
  check "reset: v1 keeps running" kill -0 "$pid"
  check "reset: the bundle is v1" test "$(bundle_version "$app")" = 1000
  confirm "reset: the card reads Update available" "Does the card read 'Update available' again, with its button ready?"
}

# t34_verify <description> <armed: yes|no>: what must hold once the kill's effects have settled.
t34_verify() {
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
  launch_login "$app"
  sleep 8
  expect_count "$description: a relaunch runs with" -eq 1 count_app_processes
  stop_app
}

t34_app_round() {
  local round="$1" app="/Applications/$APP_NAME" delay armed=no
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler "T34-app-$round" "$app"
  launch_login "$app"
  delay="$((RANDOM % 4)).$((RANDOM % 10))"
  sleep "$delay"
  job_listed .hand-over && armed=yes
  pkill -9 -f "$APP_NAME/Contents/MacOS"
  job_listed .hand-over && armed=yes
  t34_verify "app killed at $delay s" "$armed"
}

# Autoupdate's command line names the bundle identifier, as its path does.
kill_autoupdate() {
  local end=$((SECONDS + 20))
  while [ "$SECONDS" -lt "$end" ]; do
    pkill -9 -f "Autoupdate.*$E2E_ID|$E2E_ID.*Autoupdate" && return 0
    sleep 0.02
  done
  return 1
}

t34_installer_round() {
  local round="$1" app="/Applications/$APP_NAME"
  reset_world
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler "T34-installer-$round" "$app"
  launch_login "$app"
  kill_autoupdate || ROW_FAILS+=("installer round $round: no Autoupdate appeared to kill")
  t34_verify "Autoupdate killed, round $round" yes
}

row_T34() {
  local round
  t34_failed_install card
  t34_failed_install login
  t34_reset
  for round in $(seq 1 20); do t34_app_round "$round"; done
  for round in $(seq 1 10); do t34_installer_round "$round"; done
}

# One case of T35: <label> <description> <yes|no: the person presses Update now> <build> [feed.py command and arguments].
# A card case lets the person press Update now; a login case starts the copy at login and waits.
t35_case() {
  local label="$1" description="$2" kind="$3" build="$4" app="/Applications/$APP_NAME" started pid
  shift 4
  reset_world
  use_feed "$build" || row_fail "$description: cannot render the feed"
  if [ $# -gt 0 ]; then edit_feed "$@" || row_fail "$description: cannot edit the feed"; fi
  install_copy v1 "$app"
  start_sampler "T35-$label-$kind" "$app"
  watch_sparkle_start
  started="$(now_ms)"
  if [ "$kind" = card ]; then
    launch_hand "$app"
    wait_count 45 feed "$started" 1 || { ROW_FAILS+=("$description: no probe"); return; }
    tell_person "Press 'Update now' in the settings window."
  else
    launch_login "$app"
    wait_count 45 feed "$started" 1 || { ROW_FAILS+=("$description: no feed request"); return; }
  fi
  if [ "$label" = dmg ] || [ "$label" = host ]; then
    sleep 20
  else
    wait_count 120 payload "$started" 1 || { ROW_FAILS+=("$description ($kind): the archive was never asked for"); return; }
    sleep 25
  fi
  pid="$(first_process)"
  check "$description ($kind): v1 never replaced" analyze whole "$SAMPLES" --app "$app" --versions 1000
  check "$description ($kind): v1 still runs" test -n "$pid"
  expect_count "$description ($kind): Sparkle helper processes now" -eq 0 count_sparkle_processes
  expect_count "$description ($kind): files left in the persistent download" -eq 0 persistent_files
  expect_count "$description ($kind): helper jobs listed" -eq 0 count_helper_jobs
  check "$description ($kind): no password window" analyze absent "$SAMPLES" --owner SecurityAgent
  if [ "$kind" = card ]; then
    confirm "$description (card): the card reads Update available again" "Does the card read 'Update available' again?"
  else
    check "$description (login): nothing shown" analyze quiet "$SAMPLES" --since "$started" --forbid-owner SecurityAgent --max-app-windows 0
  fi
  if [ "$label" = plain ] || [ "$label" = appledev ] || [ "$label" = otherid ]; then
    expect_count "$description ($kind): Sparkle helper processes ever seen" -eq 0 sparkle_seen
  fi
  watch_sparkle_stop
}

row_T35() {
  local version why
  ensure_build v2dev 2.0.0 2000 appledev || row_fail "cannot build v2 signed with Apple Development"
  ensure_build v2plain 2.0.0 2000 unnotarised || row_fail "cannot build v2 signed but not notarised"
  ensure_build v2other 2.0.0 2000 release "$E2E_ID.other" || row_fail "cannot build v2 with another bundle identifier"
  version="$(version_of v2)"
  local kind
  for kind in card login; do
    t35_case tampered "a tampered EdDSA signature" "$kind" v2 tamper-signature "$version"
    t35_case appledev "v2 signed by Apple Development" "$kind" v2dev
    t35_case plain "v2 signed by the Developer ID, not notarised" "$kind" v2plain
    t35_case otherid "v2 with another bundle identifier" "$kind" v2other
  done
  t35_case dmg "an enclosure of a .dmg" login v2 replace "$version" .aar .dmg
  expect_count "no asset request for the .dmg" -eq 0 count_in download 0
  t35_case host "an enclosure on another host" login v2 replace "$version" "http://127.0.0.1:$PORT" "http://localhost:$PORT"
  expect_count "no asset request for the other host" -eq 0 count_in download 0

  why="$(std_unready)"
  if [ -n "$why" ]; then
    ROW_FAILS+=("the standard-account case did not run: $why")
    return
  fi
  keep_sudo
  STD_ACTIVE=1
  t35_case std "a tampered EdDSA signature on a standard account" card v2 tamper-signature "$version"
}

# The standard-account row's way to the administrator prompt: v1 in place, the download held, Update now pressed by the
# person, the download released. Returns once the prompt is up.
t36_to_prompt() {
  local label="$1" app="/Applications/$APP_NAME" started
  stop_app
  stop_sampler
  remove_path "$app"
  install_copy v1 "$app"
  : > "$LOG"
  set_control "payload=hold"
  start_sampler "$label" "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$started" 1 || return 1
  tell_person "Press 'Update now' in the settings window."
  wait_count 120 payload "$started" 1 || return 1
  sleep 3
  check "$label: no administrator prompt while the download is held" analyze absent "$SAMPLES" --owner SecurityAgent
  set_control "payload=release"
  wait_for 60 prompt_up
}

prompt_up() { analyze shown "$SAMPLES" --owner SecurityAgent; }
prompt_gone() { ! prompt_up; }

row_T36() {
  local why app="/Applications/$APP_NAME" started pressed gone old left
  why="$(std_unready)"
  [ -z "$why" ] || row_fail "a standard account is needed: $why"
  keep_sudo || row_fail "sudo is not available"
  STD_ACTIVE=1
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T36-assign "$app"
  assign_gesture "$app" || row_fail "the gesture could not be assigned, or the window did not close"

  stop_app
  stop_sampler
  : > "$LOG"
  start_sampler T36-login "$app"
  started="$(now_ms)"
  launch_login "$app"
  sleep 60
  expect_count "standard login start: requests in 60 s" -eq 0 count_in any "$started"
  check "standard login start: no administrator prompt" analyze absent "$SAMPLES" --owner SecurityAgent
  stop_app

  t36_to_prompt T36-quit || row_fail "quit run: the administrator prompt never came after the download"
  old="$(first_process)"
  tell_person "While the prompt is up, tap the gesture once a second without stopping."
  pressed="$(now_ms)"
  check_gesture "gesture while the prompt is up, a person's tap interval included" "$pressed" 2000
  ask_person "Press Return here after the next line: then at once press 'Quit Trackpad Launcher' in the settings window."
  pressed="$(now_ms)"
  wait_for 30 no_app_running || row_fail "the app did not end after Quit while the prompt was up"
  gone="$(now_ms)"
  ROW_NOTES+=("Quit during the prompt: the app ended $((gone - pressed)) ms after the Return, a person's reaction included")
  sleep 3
  check "the prompt went with the app" prompt_gone
  check "the bundle stays v1" test "$(bundle_version "$app")" = 1000

  t36_to_prompt T36-cancel || row_fail "cancel run: the administrator prompt never came after the download"
  old="$(first_process)"
  tell_person "Cancel the administrator prompt."
  wait_for 90 prompt_gone || ROW_FAILS+=("the prompt did not go away")
  sleep 5
  check "v1 still runs after cancelling" kill -0 "$old"
  check "the bundle is whole v1" analyze whole "$SAMPLES" --app "$app" --versions 1000
  confirm "cancelling returns the card to Update available, no error" "Does the card read 'Update available' with no error shown?"
  set_control ""
  pressed="$(now_ms)"
  tell_person "Press 'Update now' again and type the administrator password."
  wait_for 180 analyze first-version "$SAMPLES" --app "$app" --version 2000 --since "$pressed" ||
    row_fail "the password did not install v2"
  after_exit "the installed update" "$old"
  check "v2 runs with --after-update --with-window" process_runs "$NEW_PID" "$app" "--after-update --with-window"
  wait_for 15 analyze window-open "$SAMPLES" || ROW_FAILS+=("v2 opened without its settings window")

  t36_to_prompt T36-logout || row_fail "logout run: the administrator prompt never came after the download"
  tell_person "With the prompt up, log out of $STD_USER (Apple menu, Log Out…). Log back in afterwards if you like."
  wait_for 300 console_left || row_fail "the account was never logged out"
  left="$(now_ms)"
  wait_for 60 no_app_running || row_fail "the app was still running 60 s after the logout"
  gone="$(now_ms)"
  if [ $((gone - left)) -le 5000 ]; then
    ROW_NOTES+=("logout during the prompt: the app ended $((gone - left)) ms after the console changed hands")
  else
    ROW_FAILS+=("logout during the prompt: the app ended $((gone - left)) ms after the console changed hands, wanted at most 5000")
  fi
}

# inspect_app <pid>: heap and vmmap need the task port, which a hardened app gives only to root.
inspect_app() {
  local pid="$1" heap_out vmmap_out
  heap_out="$(sudo -n heap "$pid" 2>&1)"
  vmmap_out="$(sudo -n vmmap "$pid" 2>&1)"
  grep -q "Process" <<<"$heap_out" || { echo "heap printed nothing usable: $(head -c 120 <<<"$heap_out")"; return 1; }
  grep -q "Process" <<<"$vmmap_out" || { echo "vmmap printed nothing usable: $(head -c 120 <<<"$vmmap_out")"; return 1; }
  if grep -q "SPUUpdater" <<<"$heap_out"; then echo "heap shows SPUUpdater"; return 1; fi
  if grep -qi "WebKit" <<<"$vmmap_out"; then echo "vmmap shows WebKit"; return 1; fi
  echo "heap: no SPUUpdater; vmmap: no WebKit"
}

row_T37() {
  local app="/Applications/$APP_NAME" started pressed gone pid
  keep_sudo || row_fail "sudo is not available"
  use_feed v2 || row_fail "cannot render the feed"
  set_control "payload=hold"
  install_copy v1 "$app"
  start_sampler T37 "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$started" 1 || row_fail "no probe"
  tell_person "Press 'Update now' in the settings window."
  wait_count 120 payload "$started" 1 || row_fail "Update now brought no asset request"
  confirm "the button reads Updating…" "Does the card's button read 'Updating…'?"
  ask_person "Press Return here, then at once press 'Quit Trackpad Launcher' in the settings window."
  pressed="$(now_ms)"
  wait_for 30 no_app_running || row_fail "the app did not end"
  gone="$(now_ms)"
  ROW_NOTES+=("the app ended $((gone - pressed)) ms after the Return, a person's reaction included")
  check "the bundle stays v1" test "$(bundle_version "$app")" = 1000
  sleep 120
  check "nothing ran for 120 s" analyze pids "$SAMPLES" --since $((gone + 2000)) --max-concurrent 0
  expect_count "launchd jobs now" -eq 0 count_jobs
  expect_count "Sparkle helper processes now" -eq 0 count_sparkle_processes

  reset_world
  use_feed v1 || row_fail "cannot render the feed"
  install_copy v1 "$app"
  start_sampler T37-probe "$app"
  started="$(now_ms)"
  launch_hand "$app"
  wait_count 30 feed "$started" 1 || row_fail "no probe"
  sleep 15
  pid="$(first_process)"
  expect_count "Sparkle helper processes after a probe that found nothing" -eq 0 count_sparkle_processes
  check "the app holds no updater and no WebKit" inspect_app "$pid"
}

# By hand: a restart or a shutdown ends this script with the Mac, so those cases are done from these steps and answered
# in a later run; a case not answered fails the row.
row_T41() {
  local event state
  use_feed v2 || row_fail "cannot render the feed"
  install_copy v1 "/Applications/$APP_NAME"
  set_control "payload=hold"
  tell_person "Armed: v2 is offered, the asset is held mid-body, v1 sits in /Applications. For each case:
  1. open -g '/Applications/$APP_NAME' --args --at-login   (and, for the window-open cases, also: open '/Applications/$APP_NAME')
  2. Wait until $LOG shows the asset request, then do the event: log out, restart, or shut down.
  3. A restart or a shutdown ends this script and its server. After logging in, run Scripts/update-e2e.sh T41 again and
     answer the case you did; answer s to the others.
  4. For the next login start, open -g '/Applications/$APP_NAME' --args --at-login with the server running and the hold removed."
  for event in "log out" "restart" "shut down"; do
    for state in "window closed" "window open"; do
      confirm "$event with the download held, $state: it proceeded at once with no dialog, and the next login start checked again and installed" \
        "Case: $event, $state. Did it proceed at once with no dialog, and did the next login start check again and install v2? (y, n, or s if not done)"
    done
  done
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

  if [ "$BUILD_ONLY" = 1 ]; then
    # The builds the rows make for themselves, so that no row waits on a notarisation.
    ensure_build mid 1.1.0 1100 "$kind" || die "cannot build the 1.1.0 copy."
    ensure_build v2dev 2.0.0 2000 appledev || die "cannot build v2 signed with Apple Development."
    ensure_build v2plain 2.0.0 2000 unnotarised || die "cannot build v2 signed but not notarised."
    ensure_build v2other 2.0.0 2000 "$kind" "$E2E_ID.other" || die "cannot build v2 with another bundle identifier."
    log "built every copy into $CACHE"
    exit 0
  fi

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
