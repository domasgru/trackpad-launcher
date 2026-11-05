# Fixes after review of S1

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/035-post-update-crash`, branch `feature/035-post-update-crash`. Paths are relative to it. The branch's gate is `make test`.

Do not touch `LauncherKit/Sources/`: the adapter is final, and `build/repro` was built from it. Do not commit, push, or open a PR.

## Constraints

- Never launch or stop anything with bundle identifier `com.domasgru.TrackpadLauncherApp` or its `.debug` twin. The orchestrator re-runs `repro.sh`; you do not need to launch the app at all.
- Write each Bash command with literal arguments (no shell variables, `$(...)` or loops), and create and edit files with Write and Edit; the worktree guard rejects anything else.

## F1. A second `exited` could go uncounted

`LauncherKit/Tests/LauncherPlatformTests/SystemRunningCopiesStopTests.swift:62-63`. Rule, from the plan: "`exited` itself records how many times it ran and whether it ran on the main thread; the helper wakes the test once and would hide a second call."

`exits.count` is read straight after the wake, so a second call that comes later is never counted. Fix: move the two `#expect`s on `exits` to after the `isGone` loop, so the count is read after the process-gone wait.

## F2. One test holds two behaviours, and its name says how

`SystemRunningCopiesStopTests.swift:29,72-74`. Rule, `swift-testing-pro` `references/writing-better-tests.md`: "generally preferred to test only one behavior in each unit test"; `dev-workflow:tdd` `tests.md`: red flag "Test name describes HOW not WHAT".

Fix: T2's first case stays in the same function, since it has to reuse T1's processes (only the fixture's own pids may reach `stop`). The empty-list case needs no process, so it becomes its own `@Test` that calls `stop([])` inside an `autoreleasepool` on an adapter built on a fresh `BundleFixture.identifier`-based unique identifier, and expects one synchronous `exited`. Rename the long test so its name says the behaviour, for example `stoppedCopiesExitAndTheNewCopySurvives`.

## F3. `pgrep -f` can match the shell's forked child

`BundleFixture.swift:83-84`, with its effect at `SystemRunningCopiesStopTests.swift:48-49`. Rule, `writing-better-tests.md`, FIRST: "Repeatable".

Between `fork` and `exec` of `sleep`, the child still carries the shell's argv, so `pgrep -f` can return a third pid and fail `pids.count == 2`. Fix: add `-P 1` to the `pgrep` arguments; the shell's parent is launchd and its forked child's parent is the shell. Say so in the doc comment in a few words.

## F4. `pids(runningExecutableOf:)` replays `run`

`BundleFixture.swift:82-90` against `run` at the end of the file. Fix: its body becomes `(try? run("/usr/bin/pgrep", [...])) ?? ""` split into pids, since `pgrep` exits non-zero on no match and that reads as no pids. `run` itself stays unchanged.

## F5. `pids(…release) + pids(…debug)` appears twice

`SystemRunningCopiesStopTests.swift:37,48`. Fix: one local closure in the test, used in both places.

## F6. Speculative parameters on `makeRunnableBundle`

`BundleFixture.swift:59-60`. Fix: remove `@discardableResult` (both callers use the result) and the `named:` parameter (always `"Fixture.app"`); the signature becomes `makeRunnableBundle(in:identifier:)`.

## F7. `repro.sh` passes vacuously with no old copy

`plans/035-post-update-crash/repro.sh:34`. Rule, R1's scenario: "GIVEN a copy of the app is running". An empty `$old` makes `kill -0 ""` fail, so `old_gone=yes`. Fix: `old_gone=yes` only when `$old` is non-empty and `kill -0` fails; a round with no old copy counts as DEAD. Keep the summary line's shape, and edit with Edit, keeping mode 755.

## Done when

- `Scripts/test.sh --filter SystemRunningCopiesStopTests` is green and `make test` is green, with no other existing test edited.
- `lsappinfo list | grep -c "TrackpadLauncherFixture"` prints `0` after the run.
- Report the literal last line of `make test`.
