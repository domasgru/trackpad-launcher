# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/039-auto-updates`. The full gate is green at `a2da883`; these are review findings. Do exactly these, nothing else. No production Swift changes. Do not commit: the orchestrator commits.

Worktree guard: literal Bash arguments, no shell variables, `$(…)` or loops; create and edit files with Write and Edit; absolute paths.

## 1. `docs/architecture.md:19`, the main-actor exception understates what runs on main

Rule broken: "Work that would delay a click ... runs off the main actor ... The update's signature check is one exception: it runs on the main actor, 18 to 31 ms once per release, so that no unchecked update is ever held."

`SparkleEngine.swift:62,108,135` and `LaunchdJob.swift:16` also run on main: the lookup of the extracted bundle, and a refused update's veto (a job removal that waits, and a bundle's removal), inside the same delegate call. That is the plan's design (the veto was proven inside the delegate call), and arming the hand-over runs in the turn that ends the process. So the document is what is wrong.

Fix: reword that sentence so the exception covers the check with the bundle lookup before it, and, for a refused update only, the veto after it; all of it inside Sparkle's delegate call, once per release. Keep "18 to 31 ms" attached to the signature check alone. Same voice as the file.

## 2. `docs/architecture.md:20`, "bounded wait"

Rule broken: "the hand-over job's bounded wait, which runs after this process has ended."

`LaunchdJob.swift:56` first waits for the old pid with no limit, on purpose: a late end must still install and still come back, and the process ends in the same turn the job is armed. Only the wait for the swap is bounded.

Fix: reword to say the job waits for the old process to end, then for at most 6 s for the install, all of it after this process has decided to end. Leave the script alone.

## 3. `Scripts/release.sh:42` and `:380`, wrong claim about a rerun

Plan: "A version already in the feed is replaced, so --feed-only can run twice." The header says "A feed that already lists the version publishes nothing", and the message at `:380` says "The feed already lists $EXPECTED_VERSION; nothing to publish." `write_feed` renders a fresh `pubDate`, so a later rerun replaces the item and pushes. The `cmp` branch is right only for a byte-identical render, the same second, where `git commit` would otherwise fail with nothing to commit.

Fix: keep the `cmp` branch. Header: a rerun replaces the version's item; a feed that comes out byte-identical publishes nothing. Message at `:380`: "The feed is unchanged; nothing to publish." Keep `publish_feed`'s behaviour. Make `feedOnlyRunTwice…` in `LauncherKit/Tests/ReleaseTests/ReleaseTests.swift` still pass.

## 4. T18, `LauncherKit/Tests/LauncherCoreTests/HandOverTests.swift:125-136`, the test recomputes the table

Plan's source of truth for T18 is the design's `Route` table. The test's `switch` and ternaries restate the rule, so they would drift with it (tdd `tests.md`).

Fix: a literal table of rows: every `Opening` (`.atLogin`, `.byHand`, `.afterUpdate`) × `Placement` × `olderCopyRuns`, 18 rows, each with its expected `Route` written out, parameterised. Values:

- `.atLogin`: `olderCopyRuns` true → `.end`, false → `.runSilently`, any placement.
- `.byHand`: `.elsewhere` → `.askToMove`; `.installed`, `.development` → `.runWithWindow`.
- `.afterUpdate`: `.installed` → `.runSilently`; `.elsewhere` → `.askToMove`; `.development` → `.runWithWindow`.

## 5. `LauncherKit/Tests/LauncherPlatformTests/LaunchdJobTests.swift:107`, an assertion that cannot fail

`#expect(afterKill < rewritten)` compares two clock reads taken in order. Delete it and the `afterKill` constant if nothing else reads it.

## 6. T36, `LauncherKit/Tests/LauncherPlatformTests/DeviceSessionContactTests.swift:105-108`

Plan: "the injected clock is read as often as in a session with no contact code." The test compares sensing off with sensing on, and both carry the contact code, so a clock read added to `receive` would pass.

Fix: assert a literal read count for the row's frames, derived from what `receive` does for those frames with no contact code. Prove the test bites: temporarily add a clock read at the contact lines in `FrameStream.swift`, see it fail, and take the change out again. Say in your report that you did.

## 7. T1, `LauncherKit/Tests/LauncherCoreTests/UpdaterStartTests.swift:31-46`

Plan: "its whole history holds no engine call, no connection watch and no clock wait." Gated-out rows assert only engine values.

Fix: add `#expect(process.connection.watches == 0)` and `#expect(process.idleClock.waits.isEmpty)` to the gated-out branch. Use the handle names as they are in `InMemoryAdapters.swift`.

## 8. T28, `LauncherKit/Tests/LauncherCoreTests/UpdateRetryTests.swift:119-128`

Plan: "A download lost mid-way, which arrives as `.requestFailed`, watches like a failed check." The test pushes `.held(.genuine)` first, so it tests a held update being lost, not a download.

Fix: rename the existing test for what it proves (a held update lost to a failed request). Add the real row: no `.held` at all, `.cycleEnded(.requestFailed)`, then `isWatching`, and `set(true)` gives one more check.

## Done when

`Scripts/test.sh` is green; use a long Bash timeout (up to 600000 ms) or `run_in_background`.
