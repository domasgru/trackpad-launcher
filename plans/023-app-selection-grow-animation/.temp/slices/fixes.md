# Fixes after review: pick animation and the per-animation tuner

Repo root (worktree): `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/023-app-selection-grow-animation`. Package: `LauncherKit/` (paths below are under it unless stated). Run tests with `Scripts/test.sh`. Do not commit; the orchestrator commits. The full gate was green before these fixes (574 + 153 + 15 tests, Debug app builds); keep it green, and keep `swift build -c release` building.

Fix each finding below as decided. Nothing else.

## F1. The picker tests' expected keyframes restate the implementation

- **Where:** `Tests/LauncherUITests/PickerBench.swift:124-129` (`expectPlaysPickAnimation`).
- **Rule broken:** the tdd skill's `tests.md`: "Expected value restates the implementation" is a red flag; the expected value must come from an independent source of truth, here R6: "The icon appears at 40% of its side … grows to 110% of its side in 0.2 seconds … settles back to 100% by 0.35 seconds after the pick." The plan's T7 names the landmarks: "(0.4 first, 1.1 at 0.2 s, 1.0 last)".
- **Fix:** keep the equality with `PickAnimation.shipped.keyframes(perSecond: 240)` (T7 asks that the layer plays exactly those samples, which is a real check that the view maps them faithfully), and add literal assertions on what the layer plays, independent of that function: 85 values and 85 key times; key times start at 0 and end at 1; the first scale is 0.4; the scale at the key time whose time (key time × 0.35) is within 1e-9 of 0.2 s is 1.1 and is the largest; the last scale is 1.0; every value is a uniform scale (m11 == m22, m33 == 1). Compare floats within a small tolerance (1e-9) where needed.

## F2. Leaving the Bounce tab may leave the bounce preview running

- **Where:** `Sources/LauncherPlatform/AnimationTuner.swift:238-240` (the `onChange(of: model.tab)` handler) with the toggle's handlers at `:361-363`.
- **Rule broken:** plan D7: "Leaving the Bounce tab ends a running bounce preview and turns *Preview bounce* off, so the switch never shows on with nothing bouncing." Today the tab handler only sets `isPreviewingBounce = false`; stopping relies on the toggle's `onChange`/`onDisappear`, and the toggle is leaving the hierarchy at the same moment, so depending on SwiftUI's ordering, nothing calls `previewBounce(false)`.
- **Fix:** in the tab handler, when the old tab is `.bounce` and `isPreviewingBounce` is true, call `previewBounce(false)` directly and then set `isPreviewingBounce = false`. Make sure the stop is not harmful if it also runs from the toggle's `onDisappear` (check `bounces.stopPreview` in `WorkspaceActions.swift` / the bounce overlay: if a second stop is not a no-op, guard so it is called once, e.g. drop the toggle's `onDisappear` stop only if the window-close path is still covered some other way; keep stopping on window close).

## F3. T8's Other… runs can pass without a completion ever being handed over

- **Where:** `Tests/LauncherUITests/AppPickerTests.swift`, `anOtherPickTheModelIgnoresChangesNothing` and the cancelled-Other… test.
- **Rule broken:** plan T8: "When "Other…" is picked from the menu. Then `chooseOther` was called once and handed a completion …" Calling `bench.otherCompletion?(nil)` is a no-op when nothing was captured, so the test cannot fail.
- **Fix:** in every T8 run assert `chooseOther` was called once and the completion was captured (non-nil) before using it; call it unwrapped (`try #require`).

## F4. T13's starting condition is not checked

- **Where:** `Tests/LauncherUITests/AppPickerTests.swift`, `aQuickSecondPickReplacesTheIconAndPlaysFromTheStart`.
- **Rule broken:** plan T13: "Given Mail just picked, its animation on the layer."
- **Fix:** after picking Mail and before picking Music, assert the layer shows Mail's icon and carries the pick animation.

## F5. The pick-tuning tuple is spelled out at seven sites

- **Where:** `Sources/LauncherUI/SettingsShell.swift` (lines ~10, 31, 45, 47, 204, 213) and `Sources/LauncherPlatform/WorkspaceActions.swift:100`.
- **Rule broken:** baseline smell "Data Clump / Primitive Obsession": the same `(animation: PickAnimation, simulateReduceMotion: Bool)` shape repeated.
- **Fix:** in `SettingsShell.swift`, declare one `public typealias PickTuning = (animation: PickAnimation, simulateReduceMotion: Bool)` (nested in `SettingsShell` or at file scope, public so the composition root can use it) and use it at every site in that file, including the pure `pickAnimation(reduceMotion:tuned:)` signature. `WorkspaceActions` in `LauncherPlatform` cannot see `LauncherUI`, so leave its tuple as is; the composition root bridges. Also rename the `tuned` parameter/closure only if a clearer name falls out naturally; do not rename the public functions the plan names (`pickAnimation(reduceMotion:tuned:)`, `pickTuning`, `previewPickAnimation()`, `canPreviewPickAnimation`).

## F6. `showCurrentOnly` asks for the icon twice

- **Where:** `Sources/LauncherUI/AppPicker.swift:92` and `:144` (`closedItem` for `.present`), both calling `icon(entry.url)` in one `showCurrentOnly` pass.
- **Rule broken:** baseline smell "Duplicated Code"; and `icon` is `AppIcons.iconDrawingIfMissing`, which may draw on the main actor (architecture.md, Concurrency: it "draws a missing icon on the main actor, but only for the closed button showing a row app outside the list that was just picked through Other…"), so it should run once per show.
- **Fix:** resolve the icon once in `showCurrentOnly` for `.present` and pass it to both the closed item's clear-image sizing and `pickerView.showIcon`.

## F7. The tuner's footer preview buttons repeat the per-tab switch of `playButton`

- **Where:** `Sources/LauncherPlatform/AnimationTuner.swift:223-233` and `:312-323`.
- **Rule broken:** baseline smell "Duplicated Code / Repeated Switches".
- **Fix:** one private helper that, for a tuning (or nil for the current one), returns the play action and whether it is available on the shown tab (nil on Bounce and Swipe), used by both the footer button and `playButton`. Keep the labels and help texts as they are (footer: *Preview at pointer* / *Preview in settings*; preset rows: the play icon). Only do this if it stays simpler than the current code; if not, leave it and say so.

## Not fixed (for the record, no action)

- Release builds carry `pickAnimation(reduceMotion:tuned:)`'s `tuned` parameter: the plan's D5 makes this the one pure rule T15 tests; Release passes nil.
- Implementation-detail assertions on `action(forKey:)`, `masksToBounds`, `pickKey`: they are the plan's R7 review and D2/D3 checks at the seam the plan names.
- Multi-case tests in `AppResolutionTests` / `rendersNeverAnimateTheIcon`: each is one plan scenario (T3, T12) walked step by step.
- `TuningHook` middle man, the wiring across files, `canPreviewPickAnimation`'s placement: the plan's D5/D6 design.

## Done when

F1–F6 are fixed (F7 fixed or reported as left), `Scripts/test.sh` is green with no new warnings, and `swift build -c release` (from `LauncherKit/`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) builds. Report each fix and any departure.
