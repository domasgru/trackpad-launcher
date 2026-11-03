#!/bin/sh
# Probe: can a stock macOS tool, run the way PrivilegedInstall runs its script (/bin/sh -c script sh args...),
# replace a bundle directory with Foundation's atomic replaceItemAt, so that an administrator install could be
# one atomic step instead of two `mv`s?
# Tool tried: /usr/bin/osascript -l JavaScript (JXA) with the ObjC bridge, paths passed as arguments (argv),
# never interpolated into the script text.
# Run unprivileged in a temp folder (the same call as root is what the admin path would make). Cleans up.
DIR=$(mktemp -d /tmp/tl-probe-jxa.XXXXXX)
mkdir -p "$DIR/apps/Probe.app/Contents" "$DIR/stage/Probe.app/Contents"
echo old > "$DIR/apps/Probe.app/Contents/marker"
echo new > "$DIR/stage/Probe.app/Contents/marker"
INODE_STAGED=$(stat -f %i "$DIR/stage/Probe.app")

SCRIPT='ObjC.import("Foundation");
function run(argv) {
  const fm = $.NSFileManager.defaultManager;
  const error = Ref();
  const ok = fm.replaceItemAtURLWithItemAtURLBackupItemNameOptionsResultingItemURLError(
    $.NSURL.fileURLWithPath(argv[0]), $.NSURL.fileURLWithPath(argv[1]), $(), 0, $(), error);
  if (!ok) { return "failed: " + (error[0] ? error[0].localizedDescription.js : "unknown"); }
  return "replaced";
}'

/bin/sh -c '/usr/bin/osascript -l JavaScript -e "$1" "$2" "$3"' sh "$SCRIPT" "$DIR/apps/Probe.app" "$DIR/stage/Probe.app"
echo "exit status: $?"
echo "marker now: $(cat "$DIR/apps/Probe.app/Contents/marker")"
echo "destination inode == staged inode: $( [ "$(stat -f %i "$DIR/apps/Probe.app")" = "$INODE_STAGED" ] && echo yes || echo no )"
echo "staged path still exists: $( [ -e "$DIR/stage/Probe.app" ] && echo yes || echo no )"
echo "== a path with quotes, spaces and \$(touch pwned) is passed through intact"
mkdir -p "$DIR/odd \"name\" \$(touch pwned)/Probe.app/Contents"
echo new2 > "$DIR/stage2" ; mkdir -p "$DIR/stage2dir/Probe.app/Contents"; echo new2 > "$DIR/stage2dir/Probe.app/Contents/marker"
/bin/sh -c '/usr/bin/osascript -l JavaScript -e "$1" "$2" "$3"' sh "$SCRIPT" "$DIR/odd \"name\" \$(touch pwned)/Probe.app" "$DIR/stage2dir/Probe.app"
echo "marker now: $(cat "$DIR/odd \"name\" \$(touch pwned)/Probe.app/Contents/marker")"
echo "pwned file created: $( [ -e pwned ] || [ -e "$DIR/pwned" ] && echo yes || echo no )"
echo "== missing destination"
/bin/sh -c '/usr/bin/osascript -l JavaScript -e "$1" "$2" "$3"' sh "$SCRIPT" "$DIR/nowhere/Probe.app" "$DIR/stage2dir/Probe.app"
rm -rf "$DIR"
echo cleaned up
