#!/bin/bash
# The full gate: every test, then the app target, which the tests do not build. It never opens the app, and builds
# apart from `make run`'s build/dev, so a development copy that is running stays as it is.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/.."

Scripts/test.sh
xcodegen generate --quiet
xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug \
    -derivedDataPath build/gate -quiet

echo "gate: all green"
