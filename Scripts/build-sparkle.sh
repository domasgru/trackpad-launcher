#!/bin/bash
# Builds Sparkle from its pinned tag's source, without its user interface, legacy parts or downloader service,
# and vendors the result in LauncherKit/Vendor/Sparkle: Sparkle.xcframework, bin/sign_update,
# bin/generate_keys and manifest.json. A person runs this when the pin changes; the output is committed.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

TAG="2.10.1"
REPO_URL="https://github.com/sparkle-project/Sparkle"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/LauncherKit/Vendor/Sparkle"

FLAGS=(
  "SPARKLE_BUILD_UI_BITS=0"
  "SPARKLE_BUILD_LEGACY_SUUPDATER=0"
  "SPARKLE_BUILD_LEGACY_DSA_SUPPORT=0"
  "SPARKLE_BUILD_LEGACY_DELTA_SUPPORT=0"
  "SPARKLE_EMBED_DOWNLOADER_XPC_SERVICE=0"
  "SPARKLE_EMBED_INSTALLER_LAUNCHER_XPC_SERVICE=1"
)

fail() { echo "build-sparkle: $*" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

CLONE="$SCRATCH/Sparkle"
git clone --quiet --depth 1 --branch "$TAG" "$REPO_URL" "$CLONE" || fail "cannot clone $REPO_URL at $TAG."
COMMIT="$(git -C "$CLONE" rev-parse HEAD)"

# Sparkle's own note: with legacy DSA support off, its Swift flag for it goes too.
SWIFT_FLAGS="-DGENERATE_APPCAST_BUILD_LEGACY_DSA_SUPPORT -DSPARKLE_BUILD_PACKAGE_SUPPORT"

cd "$CLONE"
xcodebuild build \
  -project Sparkle.xcodeproj -scheme Sparkle -configuration Release \
  -derivedDataPath "$SCRATCH/framework" -quiet \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- \
  OTHER_SWIFT_FLAGS_COMMON="$SWIFT_FLAGS" \
  "${FLAGS[@]}" || fail "the Sparkle framework did not build."

FRAMEWORK="$SCRATCH/framework/Build/Products/Release/Sparkle.framework"
[ -d "$FRAMEWORK" ] || fail "the build left no Sparkle.framework."

LINKED="$(otool -L "$FRAMEWORK/Versions/B/Sparkle")"
for library in WebKit AppKit; do
  if grep -q "$library" <<<"$LINKED"; then
    fail "Sparkle.framework links $library; its user interface is meant to be off."
  fi
done

xcodebuild -create-xcframework -framework "$FRAMEWORK" -output "$SCRATCH/Sparkle.xcframework" >/dev/null \
  || fail "cannot pack the xcframework."

xcodebuild build \
  -project Sparkle.xcodeproj -configuration Release \
  -derivedDataPath "$SCRATCH/tools" -quiet \
  -scheme sign_update || fail "sign_update did not build."
xcodebuild build \
  -project Sparkle.xcodeproj -configuration Release \
  -derivedDataPath "$SCRATCH/tools" -quiet \
  -scheme generate_keys || fail "generate_keys did not build."

TOOLS="$SCRATCH/tools/Build/Products/Release"
[ -x "$TOOLS/sign_update" ] && [ -x "$TOOLS/generate_keys" ] || fail "the signing tools were not built."

XCODE="$(xcodebuild -version | tr '\n' ' ' | sed 's/ *$//')"

rm -rf "$VENDOR"
mkdir -p "$VENDOR/bin"
ditto "$SCRATCH/Sparkle.xcframework" "$VENDOR/Sparkle.xcframework"
cp "$TOOLS/sign_update" "$TOOLS/generate_keys" "$VENDOR/bin/"

python3 -I - "$VENDOR/manifest.json" "$TAG" "$COMMIT" "$XCODE" "${FLAGS[@]}" <<'PY'
import json, sys
path, tag, commit, xcode, *flags = sys.argv[1:]
with open(path, "w") as out:
    json.dump({"tag": tag, "commit": commit, "flags": flags, "xcode": xcode}, out, indent=2)
    out.write("\n")
PY

echo "Vendored Sparkle $TAG ($COMMIT) in $VENDOR"
