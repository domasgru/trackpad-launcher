# Fixes after review

The branch `feature/012-window-switcher-gesture` implements the window swipe (plan 012) in four committed slices. The full gate is green: `Scripts/test.sh` gives 473 tests passing, and the app bundle builds. The implementation reviewer raised the findings below, and the orchestrator decided to fix each one. Make each fix, keep the suite green and add no new warnings. Do not commit, and do not edit `plans/` or `docs/`. All paths are under `LauncherKit/`.

## F1. Off-main work goes through an explicitly concurrent function

- **Where:** `Sources/LauncherPlatform/FrontmostAppWindows.swift`, in `init()` at about lines 38–40. The window-list warm-up uses `DispatchQueue.global(qos: .utility).async { _ = CGWindowListCopyWindowInfo(...) }`.
- **Rule:** `docs/architecture.md` Concurrency says: "Work that would delay a click (folder scans, Spotlight reads, icon drawing) runs off the main actor in explicitly concurrent functions". The repo's form for this is `@concurrent private static func … async`, as in:
  - `SystemAppScanner.read`
  - `LaunchOverlay.renderOffMain`
  - `AppIcons.renderChangedOffMain`
- **Fix:**
  1. Replace the dispatch with a `@concurrent private static func warmWindowList() async` that makes the call.
  2. Start it from `init` with `Task { await Self.warmWindowList() }`.
  3. Keep the doc comment accurate.
  4. Remember the source scan bans `asyncAfter`, `Timer` and `Task.sleep`.

## F2. Preview capture runs in an explicitly concurrent function

- **Where:** `Sources/LauncherUI/PreviewCapture.swift`, at about lines 19–40. `pictures(of:fitting:)` starts an unstructured `Task {}` whose body does the listing and the concurrent captures inline.
- **Rule:** the same rule as F1, "explicitly concurrent functions, including inside `LauncherUI`".
- **Fix:**
  1. Move the body (the `SCShareableContent` listing, then the task group of captures yielding into the continuation) into a `@concurrent private static func capture(_ wanted: Set<UInt32>, width: Int, height: Int, into continuation: AsyncStream<(WindowID, CGImage)>.Continuation) async`. Use any equivalent signature that compiles cleanly under Swift 6.
  2. Have the `Task` only call that function.
  3. Keep the behaviour the same: cancelling on termination stops the captures, and `finish()` runs at the end.

## F3. The window-number fallback also covers a window whose private lookup fails

- **Where:** `Sources/LauncherPlatform/FrontmostAppWindows.swift`, in `read()` at about lines 71–77. The fallback `Self.number(of:among:)` runs only when `getWindow == nil`. If the private symbol exists but fails for one window, that window gets no number and silently drops out of the list.
- **Rule:** the plan's adapter design, step 4, says: "Number: _AXUIElementGetWindow, else Self.number(of:among:) against the pid's window-list entries."
- **Fix:**
  1. After the per-window loop, if any raw window has `number == nil`, read `Self.listedWindows(of: pid)` once.
  2. Fill each nil number with `Self.number(of:among:)`.
  3. Keep the single window-list read: do no read when every number came from the private call.

## F4. The panel's row count uses the rule constant

- **Where:** `Sources/LauncherUI/WindowSwitcherPanel.swift`, at about line 31, which reads `rowViews = (0..<10).map { … }`.
- **Rule:** the plan puts the cut in `GestureRules.windowSwitcherMaxRows`. A magic number duplicated in the shell drifts from the rule.
- **Fix:** use `(0..<GestureRules.windowSwitcherMaxRows)`.

## F5. Remove the unused overlay present path

- **Where:** `Sources/LauncherUI/OverlayPanel.swift`, at about lines 12 and 51–55.
  - `present(animated:)` has one caller, `SwitcherPresenter.swift:139`, which passes `false`.
  - `OverlayAppear.fade` is used only by that unused branch.
- **Rule:** this is speculative generality in the review's code-smell baseline. The window switcher already uses `present(appear:)`.
- **Fix:**
  1. Delete `present(animated:)` and `OverlayAppear.fade`.
  2. `SwitcherPresenter` calls `panel.present(appear: nil)`.
  3. Update the doc comments on `OverlayPanel` so they describe only `present(appear:)`.

## F6. A test name says what, not how

- **Where:** `Tests/LauncherCoreTests/WindowSwitchingTests.swift:185`, `theLiftReadsTheWindowsAgainSoItDoesNotDependOnTheRaisesWhileSliding` (T53).
- **Rule:** `tests.md` flags a "test name [that] describes HOW not WHAT".
- **Fix:** rename it to what the user sees, for example `liftingOrdersTheWindowsEvenWhenRaisesWhileSlidingWereIgnored`. Keep its assertions; the `reads == 2` row is part of the plan's T53.

## F7. T19 checks "nothing read before the crossing frame" directly

- **Where:** `Tests/LauncherCoreTests/WindowSwitcherOnScreenTests.swift`, the T19 test near line 18, which uses `playFrameByFrame`.
- **Rule:** the plan's T19 says: "before the crossing frame `windowSwitcher` is nil and nothing was read". The reviewer found the read check is only indirect.
- **Fix:**
  1. Assert `world.system.windows.reads == 0` on every frame before the begin frame. The cleanest way is to have the frame-by-frame history also record `reads`, or to use the observer variant of the frame-by-frame player that S3 added.
  2. Assert `reads == 1` on the begin frame.

## Not fixed (decided, for the record; do not change)

- **Count assertions on `reads` and `raised`.** The plan's tests name these handles as what a test observes; for example, "nothing is read" on message lifts is a design rule. They stay.
- **`SwipePhase`, `SwipeEvent`, `SwipeTravel` and `.swiping` naming, and the two event cases instead of one `.slide` case.** These are deliberate plan decisions: the alternatives were considered and rejected.
- **The similar `.moved` and `.cancelled` branches, the stretch-spring block in both presenters, `WindowSwitcherLook`'s `look:` parameter, the hint switch in `Copy` and `LauncherView`, the size tuples, `emptied()`, `isUnanswering`, and the missing `dismissFade`.** Each is a plan shape or a small judgement call; leave them as they are.

## Done when

- F1–F7 are made.
- `Scripts/test.sh` is green, and there are no new compiler warnings.
- The app still builds: run `xcodegen generate` in the repo root, then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
