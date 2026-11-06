# Fixes after review

Work only in the worktree `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/038-post-update-force-quit`. Do not commit, build the app bundle, or touch anything but the file named below. The orchestrator commits and runs the gate.

## 1. T3 accepts any error

- **File:** `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`, around line 257, in `manifestScanFailsWithoutAManifest`.
- **Current:** `#expect(throws: (any Error).self) { try Self.scanManifest(in: dir, for: "NSSupportsSuddenTermination") }`
- **Rule:** `swift-testing-pro`, `references/writing-better-tests.md`: "always name the specific error rather than using a broad `Error.self`".
- **Why:** the test promises that a missing manifest fails the scan, but any read failure would pass it.
- **Fix:** expect `CocoaError.self`, capture the error `#expect(throws:)` returns, and expect its `code` to be `.fileReadNoSuchFile`. Confirm the code against what `String(contentsOf:encoding:)` actually throws for a missing file by running the test.

## Done when

`Scripts/test.sh --filter SourcePolicyTests` is green. Report the summary line.
