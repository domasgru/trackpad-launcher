#!/bin/bash
# Builds the measurement tools and a Release app for performance runs (see docs/performance.md).
# The app is signed with the local Apple Development identity: same optimisation and hardened runtime as the
# notarized release, and Accessibility stays granted across rebuilds. Output: build/perf/.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/perf"
mkdir -p "$OUT/tools"

clang -O2 -framework CoreFoundation -o "$OUT/tools/sampler" "$ROOT/Scripts/perf/sampler.c"
clang -O2 -framework CoreFoundation -o "$OUT/tools/mtidle" "$ROOT/Scripts/perf/mtidle.c"

(cd "$ROOT" && xcodegen generate >/dev/null)
xcodebuild -project "$ROOT/TrackpadLauncher.xcodeproj" -scheme TrackpadLauncher -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$OUT/dd" CODE_SIGN_IDENTITY="Apple Development" \
  build > "$OUT/build.log" 2>&1 || { tail -20 "$OUT/build.log"; exit 1; }
echo "App: $OUT/dd/Build/Products/Release/TrackpadLauncher.app"
echo "Tools: $OUT/tools"
