# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/029-launch-icon-rotation` (branch `feature/029-launch-icon-rotation`). Paths below are relative to `LauncherKit/`. Do not commit; leave the work in the tree. The full gate was green before these fixes; keep it green.

Context: the launch animation now slants toward its sway's side. The flight draw `LaunchFlights.next(draw:reduceMotion:tuning:)` keeps a `LaunchTuning` snapshot; the moving motion carries a side and a `share` (the sway's drawn size share, Min sway…1). Pose after the pop: `x = sign(side) × rise × (tan(share × Max slant) + share × Max sway × u^swayCurve)`, tilt `= −sign(side) × (Max sway > 0 ? share : 0) × Max tilt × u^tiltCurve`.

## F1. Negation inside `#expect` — `Tests/LauncherPlatformTests/LaunchFlightTests.swift:135`

Rule (skill `macos-dev-workflow:swift-testing-pro`, core rules): never negate with `!` inside `#expect`/`#require`.

`#expect(!rising.isEmpty)` in `withNoSwayTheIconRisesAlongAStraightSlantedLineAndDoesNotTilt`. Fix: `try #require(rising.isEmpty == false, "never rises")`, since the loop after it depends on it. Check the rest of the diff's new tests for any other `!` inside `#expect`/`#require` and fix them the same way.

## F2. Helper `#require` without a source location — `Tests/LauncherPlatformTests/LaunchFlightTests.swift:84`

Rule (swift-testing-pro, writing good verification methods): a helper that calls `#require`/`#expect` takes `sourceLocation: SourceLocation = #_sourceLocation` and passes it on, so a failure points at the calling test (as the neighbouring `stage(...)` helper does).

Fix: give `firstRising(of:)` a `sourceLocation: SourceLocation = #_sourceLocation` parameter and pass it to its `#require`.

## F3. `lean` collides with the glossary — `Sources/LauncherPlatform/LaunchFlight.swift:144`

Rule (`docs/domain-model.md` vocabulary; the *Sway* entry now reads "A launch animation's lean to one side, left or right, with a slight tilt toward that side…"): "lean" names the whole sideways movement, not the tilt's scale.

`let lean = tuning.maximumSway > 0 ? share : 0` is the tilt's scale. Fix: rename the local to `tiltShare` (and its use in the rotation), with a short comment that with no sway there is no tilt, as before the slant. Keep `share` as is (the plan's term for the sway's size share; its doc comment on `Motion.moving` already defines it). Behaviour unchanged.

## F4. T6 is a second test instead of the extended third-of-rise test — `Tests/LauncherPlatformTests/LaunchFlightTests.swift:175` and `:352`

Plan T6: "Given the shipped tuning, draws 1 and −1. Then over the rising keyframes the ratio |drift| ÷ rise never decreases, and at every keyframe, the end included, |drift| ≤ rise ÷ 3. (The existing third-of-rise test, extended with the monotonic ratio.)"

Now `theDriftShareOfTheRiseOnlyGrowsAndNeverPassesAThird` (only the last ratio against 1/3) duplicates part of the existing `iconVeersToTheDrawnSideByNoMoreThanAThirdOfItsRise` (per-keyframe 1/3, over all seven draws). Fix: move the monotonic-ratio check (over the rising keyframes, `next >= previous - 1e-12`) into `iconVeersToTheDrawnSideByNoMoreThanAThirdOfItsRise`, which already runs every draw including 1 and −1, and delete `theDriftShareOfTheRiseOnlyGrowsAndNeverPassesAThird`. Rename the extended test if its name no longer says what it checks (e.g. `iconDriftsToTheDrawnSideByAGrowingShareOfItsRiseThatNeverPassesAThird`). Use `#require` (not `!`) for a non-empty rising set.

## Not fixed (decided)

- `LaunchOverlay.pixels(at:)` reading `LaunchTuning.current.peakSide`: it also serves `prepare(for:)` and `bitmap(for:scale:)`, which the bounce shares; it sizes the cached bitmap, not the flight. Leave it.
- The third-of-rise inequality in both doc comments: the plan (D3) asks for it in both.
- T5 shipped-numbers test and the explicit `maximumSway == 0.5` in T12: both are plan scenarios; keep.

## Done when

F1–F4 done; from `LauncherKit/`: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` green and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release` builds.
