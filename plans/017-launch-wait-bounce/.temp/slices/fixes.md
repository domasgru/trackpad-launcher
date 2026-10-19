# Review fixes: plan 017, launch bounce

The branch is complete (S1–S5 committed, full gate green at 659 tests). The review found the items below; each is to be fixed as decided. Behaviour must not change except where an item says so. Paths are under `LauncherKit/`.

## Rules quoted

- Smell baseline, *Duplicated code*: "the same logic in two or more places; change one and the others drift."
- Smell baseline, *Data clumps*: "the same group of values passed or stored together in several places wants its own type."
- Smell baseline, *Mysterious name*: "a name that does not say what the thing is or does."
- TDD `tests.md`: a test must exercise behaviour through the seam it names, so broken wiring turns it red; expected values come from the requirement, not from the code.
- Plan 017, Design: "When the pointer crosses to another display, the panel is re-framed once. Each icon's `contentsScale` is updated to that display's scale."
- Plan 017, T8: "When `.windowShown` arrives for Xcode again, or for an assigned app that never bounced (a launch from the Dock), Then every history is unchanged."
- Plan 017, T23: "`slide` 0.4 makes the slide last 0.4 s" (each knob set away from its shipped value moves what it names).
- Plan 017, T26: "each flight knob equals the fixture's value and `bounce == LaunchTuning.Bounce()`."
- Plan 017, T29: "true as soon as macOS lists the process (within 0.5 s), while `isFinishedLaunching` is still false."

## Fixes

1. **BounceOverlay internal duplication** — `Sources/LauncherPlatform/BounceOverlay.swift`: icon-layer setup at ~67–74 and ~266–275; `CGPoint(x: rest.x - origin.x, y: rest.y - origin.y)` at ~66, ~203, ~248; the `BounceRow(count:…, side:…, tuning:…)` construction at ~136–138 and ~187–189. Rule: *Duplicated code*. Fix: one private helper each (make the icon layer; convert a global rest to panel coordinates; lay out the row for a read).

2. **Stage tuple** — `BounceOverlay.swift:17` and `:227` spell out `(panel: NSPanel, host: CALayer, display: LaunchDisplay)`. Rule: *Data clumps*. Fix: a small private struct (e.g. `RowStage`) used in both places.

3. **Bounce decoder duplicates LaunchTuning's fallback** — `Sources/LauncherPlatform/LaunchTuning.swift:91–112` copies the generic `value(_:_:)` helper at ~64. Rule: *Duplicated code*. Fix: one shared Debug-only helper (e.g. an extension on `KeyedDecodingContainer`: `decode(_:or:)`), used by both decoders. Keep one line per field.

4. **Names** — Rule: *Mysterious name*.
   - `Launcher.swift`: `Visual.none` reads like `Optional.none` (`return .none` at 242, 244; `case .none` at 264). Rename to `.bringToFrontOnly` (or `.nothingShown`), with the comment kept.
   - `BounceOverlay.swift`: the stored `flights: LaunchOverlay` (and `init(flights:screen:)`) holds the launch overlay, not flights. Rename to `launchOverlay` (update the call in `WorkspaceActions`). Rename `flow(_:to:on:from:slides:)` to say what it does (e.g. `reflow` or `settle`).
   - Leave `LaunchWatch.Look.blind`: it is the plan's vocabulary.

5. **contentsScale on re-frames from start/end** — `BounceOverlay.swift` ~54 and ~139: when `start` or `end` moves the row panel to another display, the remaining icons keep their old `contentsScale` (only `moved()` updates it, ~206). Rule: plan Design quoted above. Fix: one place that re-frames the panel also updates every icon's `contentsScale` and bitmap, used by `start`, `end` and `moved`.

6. **LaunchWatch observer outliving the watch** — `Sources/LauncherPlatform/LaunchWatch.swift` ~87 passes `self` unretained as the AX observer's refcon, with no cleanup if a watch is freed without `stop()`. Fix: ensure the observer's run-loop source is removed when the watch goes (e.g. an `isolated deinit` that calls the same teardown as `stop()`, if the toolchain allows; otherwise retain-cycle-free equivalent). `stop()` stays idempotent.

7. **T23 bypasses the `slide` knob** — `Tests/LauncherPlatformTests/BounceStagingTests.swift:259` passes `over: 0.4` straight to `BounceRow.slide`, so broken wiring of `tuning.bounce.slide` would pass. Rule: TDD seam rule; plan T23. Fix: make the pure unit read the knob, e.g. `BounceRow.slide(from:to:tuning:)` taking `LaunchTuning.Bounce` and using `tuning.slide`; update `BounceOverlay` to call it; the test sets `slide = 0.4` on a tuning and expects a 0.4 s slide (and T18 uses the shipped tuning for 0.2 s).

8. **T8 uses a made-up app and checks too little** — `Tests/LauncherCoreTests/LaunchBounceFiringTests.swift:134` reports for `"Slack-never-bounced"`. Fix: use an app that is assigned to a gesture in the World and never bounced (e.g. assigned and running, or assigned and never tapped), and assert every history is unchanged: `bounces` (including `limits`), `bounceEndings`, `launchAnimations`, `broughtToFront`.

9. **T2's string kinds** — `LaunchBounceFiringTests.swift:36` takes `kind: String` with a `default:` that sets up `"menuBar"` and `"launchingFromTheDock"` identically. Fix: a small enum of the four ways (`commandTab`, `frontmostOnly`, `menuBar`, `launchingFromTheDock`), switched exhaustively with no `default`. The last two may share a setup (both are `startProcess` per plan), written as one `case .menuBar, .launchingFromTheDock:` with a comment.

10. **T26 checks 4 of 15 flight keys** — `Tests/LauncherPlatformTests/TunerCodingTests.swift:21–26`. Fix: assert every flight knob in the fixture equals the fixture's value (all 15 keys, for each preset in the fixture), plus `bounce == LaunchTuning.Bounce()`.

11. **T29's listing bound** — the plan's bound is "within 0.5 s"; the test allows 5 s (`BounceBench.swift:145` area / `LaunchBounceAdapterTests`). Keep `blockInWillFinish` (it is what keeps the probe unfinished reliably), but assert `hasProcess` becomes true within 0.5 s of the open. If it genuinely cannot be met under the full gate, report the measured times instead of widening.

12. **Test helpers re-implement product rules** — `Tests/LauncherPlatformTests/BounceBench.swift:71–74` copies `ScreenRead.now`'s screen mapping; ~91–93 rebuilds `LaunchDisplay.containing` without its nearest fallback. Fix: use `ScreenRead.now()` / `LaunchDisplay.containing(_:among:)` (`@testable import` reaches them).

## Not taken (no action)

- Tuner panel `acceptsMouseMovedEvents` (Debug-only): the plan's design calls for it so the preview follows the pointer over the tuner, and nothing reads the events outside a bounce's monitors.
- The "one bounce per app" and "report once" rules held in more than one layer: deliberate defence in depth in the plan (model record, adapter guard, gate).
- `LaunchWatch`'s window-list filter vs `FrontmostAppWindows`': different filters (below status level vs layer 0).
- `ScreenRead` passed as pointer and displays separately, and `LaunchOverlay` sharing `bitmap`/`makePanel`: the plan's signatures.
- `theCapIsTenSeconds`: it pins a spec number.

## Done when

All twelve fixes are in, `Scripts/test.sh` is green, and no probe process is left after the run (`pgrep -f com.trackpadlauncher.test.probe` finds nothing).
