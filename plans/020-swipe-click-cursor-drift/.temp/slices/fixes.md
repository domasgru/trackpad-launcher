# Fixes after review

Repo root (worktree): `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/020-swipe-click-cursor-drift`. Package `LauncherKit/`. Gate: `Scripts/test.sh` (must be green when you finish). Do not commit. Do not edit `docs/` or `plans/` (other than nothing). The slice already built: `Blocking.pressDrags` / `blocksPressDrags` in `LauncherCore/GestureRecognizer.swift`, `ClickFilter.decide(_:trackpadBlocking:trackpadBlocksDrags:)` in `LauncherCore/ClickFilter.swift`, wiring in `LauncherCore/TapFilters.swift`, tests in `Tests/LauncherCoreTests/PressedSwipeTests.swift`, `BlockingLevelRecognizerTests.swift`, `ClickBlockingRecognizerTests.swift`, `TapContextTests.swift`, `Tests/LauncherPlatformTests/DeviceSessionAnswerTests.swift`.

## F1. Tautological per-frame checks in the `levels` helper

File: `LauncherKit/Tests/LauncherCoreTests/BlockingLevelRecognizerTests.swift`, the `levels(_:answering:)` helper.
Rule (tdd `tests.md`): "Tautological tests: Expected value restates the implementation, so the test passes by construction."
The checks `recognition.blocksClicks == (recognition.blocking >= .clicks)`, `blocksDockSwipes == (blocking >= .dockSwipes)` and `blocking.blocksPressDrags == (blocking == .pressDrags)` restate the one-line definitions.
Fix: remove the definitional equalities that the slice added or changed (keep any that existed on `main` before this branch only if removing them would change an unrelated row's meaning; check with `git diff main -- <file>`; if the `blocksClicks`/`blocksDockSwipes` checks were already on main, leave them as they were on main and remove only the new `blocksPressDrags == (blocking == .pressDrags)` one). Keep the implication-chain checks (`blocksPressDrags` only with `blocksClicks`, `blocksClicks` only with `blocksDockSwipes`, `blocksDockSwipes` only with `wantsTap`). Leave `DeviceSessionAnswerTests` as is (there the check compares the session's stored flag with its stored level, not a definition).

## F2. T9's confirmed window-swipe row bypasses the `levels` helper

File: same, test `aConfirmedWindowSwipeReadsDragsFromTheFrameAfterItsConfirmationUntilItEnds`.
Rule (plan T9 (a)): "The `levels` helper checks on every frame of every row … and that the chain holds."
The row calls `recognizer.step` directly, so its `.pressDrags` frames are never chain-checked.
Fix: route it through `levels(_:answering: true)` (extend the helper's return value if the row needs the events per frame, e.g. return the recognitions rather than only the levels, or add a sibling helper that runs the same per-frame checks). Also extract the repeated hand `thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).lift().liftThumb().frames`, used by this row and the `[nil, false]` row, into one private helper/property in that suite.

## F3. Parameter and test names drop "Press"

Files: `ClickFilter.swift`, `TapFilters.swift`, `ClickBlockingRecognizerTests.swift`, `BlockingLevelRecognizerTests.swift`.
Rule (code-smell baseline, Mysterious Name; tdd `tests.md`: "Test name describes HOW not WHAT"): the parameter `trackpadBlocksDrags` carries `blocksPressDrags` but reads as if all drags were blocked; test names `aConfirmedSwipeReadsDragsFromItsFirstFrame...`, `aConfirmedWindowSwipeReadsDrags...` and `aWindowSwipeNobodyConfirmedNeverReadsDrags` say "reads drags" for "reaches the level that drops a press's drags".
Fix: rename the parameter to `trackpadBlocksPressDrags` everywhere (signature, body, doc comments, call sites, tests). Rename those tests so they say what is blocked, e.g. `aConfirmedSwipeDropsPressDragsFromItsFirstFrameAndAfterTheThumbLifted`, `aConfirmedWindowSwipeDropsPressDragsFromTheFrameAfterItsConfirmationUntilItEnds`, `aWindowSwipeNobodyConfirmedNeverDropsPressDrags` (pick the actual names; keep them in the suite's style). Keep the phrase "withheld press's drags" in exactly the seven comments it is in now: `grep -n "withheld press's drag" LauncherKit/Sources/LauncherCore/GestureRecognizer.swift LauncherKit/Sources/LauncherCore/ClickFilter.swift` must still give exactly seven hits.

## F4. T5's last frame lifts the thumb too

File: `LauncherKit/Tests/LauncherCoreTests/PressedSwipeTests.swift`, the T5 row (hand frames, 0 to 150 ms).
Rule (plan T5): "150 ms the thumb alone, not pressed."
The test plays `h.frame(atMS: 150)`, an empty frame, so the thumb lifts with the release.
Fix: the 150 ms frame holds the thumb alone at (10, 10), not pressed. Assertions unchanged (`pressVerdicts == [.drop, .drop]`, `broughtToFront == [Mail]`, etc.).

## F5. Duplicated window-swipe hand in `PressedSwipeTests`

File: `PressedSwipeTests.swift`, `aPressedWindowSwipeDropsTheHeldPressDrags` and `aPressedSlideWithNoWindowSwipeStillMovesThePointer`.
Rule (code-smell baseline, Duplicated Code).
Both build `TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30)).wait(.milliseconds(20)).press().slide(byMM: (0, 3.5)).slide(byMM: (0, 12))`.
Fix: one private helper in the suite for that pressed downward hand, used by both rows.

## Not fixed (for your information, do not change)

- `ClickFilter.decide` taking two Bools rather than `Blocking`: the plan chose this deliberately (each filter takes only the Bools it needs and knows nothing of the ordering; `TapFilters` derives them).
- Several assertions per World test; `Recognition` not forwarding `blocksPressDrags`.

## Done when

All five fixes made, the seven-comment grep gives exactly seven hits, `git diff main -- LauncherKit/Sources/LauncherCore/TapEvent.swift LauncherKit/Sources/LauncherPlatform/ClickTap.swift` is empty, and `Scripts/test.sh` is green. Report files changed and the gate result.
