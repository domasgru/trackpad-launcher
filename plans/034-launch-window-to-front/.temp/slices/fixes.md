# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/034-launch-window-to-front`. Do not commit. Do not edit `plans/` or `docs/`. Do not open the app, build the bundle or run any real-app step: the orchestrator does those. The gate is `make -C /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/034-launch-window-to-front test` (timeout 600000), green at the end. Bash commands use literal arguments only: no shell variables, `$(…)`, loops or heredocs.

`SourcePolicyTests` matches substrings of whole lines, comments included: `.activate()` with its leading dot may appear in no comment outside `AnimationTuner.swift`, and `ignoringOtherApps` in none outside `AppActivation.swift`.

## 1. The move dialog is shown but the app stays inactive

`LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift:37`. Rule: R2, "A copy opened by hand outside /Applications MUST show its move dialog in front of other windows, with the app active."

Measured on a cold opening with Calculator in front, 3 trials each: activating before `runModal` leaves `active=false key=none`, 0 of 3, because the system drops an activation while the app has no window on screen. Performing it in the modal panel run-loop mode gives `active=true key=_NSAlertPanel`, 3 of 3, with AppKit's own placement of the alert.

Fix: replace line 37 with the block below, and leave the rest of `run` alone.

```swift
        // The system drops an activation while the app has no window on screen, so it runs inside the modal session,
        // once the alert shows. Ordering the alert front here instead would stop AppKit centring it.
        RunLoop.main.perform(inModes: [.modalPanel]) {
            MainActor.assumeIsolated { AppActivation.activateOverOtherApps() }
        }
```

The type's doc comment changes to: `/// Renders `lifecycle.moveDialog` as an alert run modally, activating the app once it shows (an accessory app activates without a Dock icon), and sends the answer back.`, wrapped as the file wraps.

If this does not compile cleanly under Swift 6 with no new warning, stop and report it rather than reach for another mechanism.

## 2. `AppActivation`'s doc comment is false for the dialog and uses words outside the glossary

`LauncherKit/Sources/LauncherUI/AppActivation.swift:3-16`. Rules: docs/domain-model.md:3, "Use these words, with these meanings, everywhere: docs, plans, code, UI." The word is "active app", and an opening is "opened by hand", not "cold launch". R4: the place "states why plain `NSApp.activate()` is not enough". The clause "the window or the move dialog would stay under the app in front" is false: the dialog was measured above Calculator, without focus.

Fix: the doc comment becomes exactly this, rewrapped to the file's width if needed.

```swift
/// The one place the app becomes the active app, whichever app is active.
///
/// The app is `LSUIElement`, so opening it by hand while its process is not running starts it
/// without making it active. Since macOS 14 `activate()` is cooperative: the system grants it only
/// when the active app yielded, and on such an opening nothing yielded, so the settings window stays
/// under the active app and the move dialog floats above it without the keyboard focus.
///
/// `activate(ignoringOtherApps: true)` is marked for a future deprecation but is the one call that
/// works: 3 of 3 in each mode of plan 034's harness that starts the process, where `activate()`, a
/// deferred `activate()` and `NSRunningApplication.current.activate(options:)` (whose
/// `.activateIgnoringOtherApps` option the SDK says has had no effect since macOS 14) each failed
/// 3 of 3.
///
/// Call it with a window on screen: the system drops it while the app has none.
///
/// A reopen arrives already active, where the call changes nothing.
```

## 3. "Cold launch" and "the app in front" in the test's rule strings

`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:140,143`. Rule: docs/domain-model.md:3, quoted above.

Fix, the two `rule:` strings only:
- `ignoringOtherApps`: `"the override of the active app has one home, with its reason"`
- `.activate()`: `"the plain call is refused when an opening by hand starts the process; it lives only in the Debug tuner, whose click-time call is user intent"`

Report in two lines: done or blocked, and the test count.
