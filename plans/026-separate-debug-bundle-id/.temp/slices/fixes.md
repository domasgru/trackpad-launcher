# Fixes after review

Repo root (git worktree; stay in it, absolute paths):
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/026-separate-debug-bundle-id`

Do not commit; the orchestrator commits. Touch only the two files below. Do not edit any other test.

Skills: `macos-dev-workflow:swift-testing-pro`.

## F1. Loops and near-duplicate tests where a parameterized test fits

File: `LauncherKit/Tests/LauncherPlatformTests/RunningCopiesFamilyTests.swift`, the whole suite (lines ~13–32).

Rule (swift-testing-pro core rules): prefer parameterized tests (`@Test(arguments:)`) over a `for` loop inside a test, so each input reports on its own.

Fix:
- `eitherBuildListsEveryRunningCopyOfTheFamily`: replace the `for identifier in ["com.apple.finder.debug", "com.apple.finder"]` loop with `@Test(.enabled(if: finderRuns, "Finder is not running"), arguments: ["com.apple.finder.debug", "com.apple.finder"])` taking `identifier: String`. Keep both expectations (set equality with Finder's pids read independently via `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")`, and the count check against duplicates); drop the `"as \(identifier)"` messages.
- Merge `theReleaseIdentifierNamesBothBuilds` and `theDebugIdentifierNamesTheSameTwoBuilds` into one parameterized test over `["com.domasgru.TrackpadLauncherApp", "com.domasgru.TrackpadLauncherApp.debug"]`, expecting `SystemRunningCopies.family(of:)` to equal the set of those two literals for each argument (the family never depends on which build asks). Keep the expected set as literals, not derived from the arguments.
- Keep `@MainActor @Suite` (house style).

## F2. Identifier guard's grep treats the identifier as a regex

File: `Scripts/release.sh`, in `archive_and_check`, the line `grep -qx "Identifier=$BUNDLE_ID" <<<"$after" ||` (~line 212).

Rule (plan): "fails when its code-signing `Identifier` is not exactly `com.domasgru.TrackpadLauncherApp`: a whole-line match". Unescaped `.` matches any character, so the match is not exact.

Fix: use `grep -qxF "Identifier=$BUNDLE_ID"`. Nothing else in the script changes.

## Verify

- `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/026-separate-debug-bundle-id/Scripts/test.sh` green.
- From the repo root: `Scripts/release.sh --archive-only build/dev/Build/Products/Debug/TrackpadLauncher.app` still exits non-zero naming the identifier, and `Scripts/release.sh --archive-only build/perf/dd/Build/Products/Release/TrackpadLauncher.app` still passes (both products already exist under `build/`; do not rebuild or launch the app).

Report: files changed, test counts, both guard outcomes.
