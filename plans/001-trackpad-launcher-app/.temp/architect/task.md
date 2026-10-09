# Design task: Trackpad Launcher (plan 001)

## Artifact

One candidate design package for the whole Trackpad Launcher app, shaped per the Design package template in the shared reference (`design-reference.md`): Problem, Usage (caller's view), Shape (data structures, module map, type sketch with `not implemented` bodies and pseudocode, in Swift), Tradeoffs accepted, Alternatives considered, Open questions and risks, Next implementation step. Leave Synthesis decision empty. Write it to your output path and nothing else.

This is greenfield: there is no code, no `docs/architecture.md`, and no surrounding system. The requirements are R1–R23 in `plan.md`. The vocabulary is `docs/domain-model.md` (gesture, anchor corner, anchored thumb, tap, hand mode, assignment, target app, bring to front, launcher window, gesture row, app picker, gestures active/inactive, trackpad settings notice, feedback) and the codebase-design skill (module, interface, implementation, seam, adapter, depth). Use those words.

## What the human asked for

The human invoked the architect with no instructions beyond the plan. The plan's requirements and non-goals are the whole contract.

## What the design must address

Everything below is grounded in `grounding/index.md` (read it and the sources it cites in full where a decision rests on them). The index is frozen: design to it.

1. **The whole module map.** Menu bar presence and icon state (R1, R2); the launcher window and its rows, picker, hand toggle, hint/notice, Quit (R3–R6, R9, R10, R15, R19); gesture recognition (R11); device management across hot-plug and sleep/wake (R16); gestures active/inactive from trackpad settings and connected trackpads, updated live (R2, R14, R15); bring to front (R12); haptic feedback per trackpad (R13); assignment identity, resolution and the not-found state (R7); persistence, first launch and login item (R8, R17, R18); no permissions, no network, no logging, zero idle cost (R20–R22); platform, build and distribution (R23). Trace each `R<N>` to the module and seam that carries it.

2. **Data structures first.** Name the domain types: hand mode, the four gestures, assignment (unassigned / assigned / missing is a derived view, decide how), gesture activity with its causes (which settings, which trackpad kind, no trackpad), the recognizer's state, the gesture event, the connected trackpad set. Encode invariants in types. Keep framework and wire types (MTTouch, CFTypeRef, UserDefaults keys, NSRunningApplication) behind adapters.

3. **The recognizer as a pure core.** Frames in (per device: touches with id, state, normalized position, millimetre position, timestamp; plus the sampled mouse-button state), gesture events out, with the clock injected. Every R11 scenario must be expressible as a frame sequence through one seam, including click-during-tap, staggered landing/lifting, thumb lifting early, drag versus tap, five fingers, and the anchor-corner geometry at 1 cm and 4 cm on a 124.8 mm wide surface. State where the fixed constants live (corner fractions, drag threshold, tap duration).

4. **Platform adapters, each behind a small interface with a real adapter and an in-memory adapter** (per "one adapter means a hypothetical seam, two means a real one", name the test adapter): the multitouch source (device list with built-in flag and device id, start/stop, frames, the actuator), the trackpad preferences (read + change notification via KVO on the two suite domains), the IOKit/wake device notifications, the launcher (LaunchServices `openApplication`), persistence, the login item. Say which thread each real adapter delivers on and where the hop to the main actor happens.

5. **Gestures active/inactive as a table-driven derivation.** The conflicting-settings list (Tap to click, Look up: tap with three fingers; Smart zoom conditional per R14) and their notice text live in one place so adding Smart zoom is a data change. The derivation takes the connected trackpad kinds and the preference values and returns the status plus the notice contents, and runs on every change (push, no polling). The window reads the same status the recognizer gates on: one source of truth.

6. **Device-set reconciliation as one idempotent operation** run at launch, on IOKit add/remove and on wake, instead of three paths.

7. **Bring to front** via `NSWorkspace.openApplication(at:configuration:)` with `activates`, as probed; the fire path from recognizer event to activation and haptic, with the silent cases of R13 (unassigned, missing, inactive) decided in one place.

8. **The menu bar shell.** The grounding shows `MenuBarExtra` cannot open or close its window programmatically, which R18 and R3 need; use `NSStatusItem` + an `NSPanel` hosting SwiftUI with Liquid Glass (`NSGlassEffectView` or `.glassEffect`). Decide close-on-click-outside, Escape, icon-click toggle, and gesture-closes-window mechanisms. The inactive icon is drawn (symbol + diagonal stroke) since SF Symbols has no slashed variant of the hand symbols.

9. **Assignment identity and resolution.** Bundle identifier as identity; last-known URL as fast path; LaunchServices lookup filtered of Trash copies; recovery without re-picking; the picker list from the three folders plus Finder, refreshed each time the picker opens, with Other… and None.

10. **Concurrency.** Swift 6 strict concurrency on the Xcode 26 toolchain (Swift 6.3). State what is `@MainActor`, what runs on the frame thread, what is `Sendable`, and that no two actors write the same state.

11. **No logging, no network, zero idle** as mechanisms, not prose: name the test that scans sources for logging calls; note there is no timer anywhere.

12. **Build and test layout.** The machine has Xcode 26.6 (SDK 26.5, `actool`, `xcodebuild`, `notarytool`), `xcodegen`, and `swift test` running Swift Testing. Choose the layout (for example a local SwiftPM package for the testable core plus an xcodegen-generated app target, or another shape) and say why; the slices will be cut against it. Deployment target macOS 26, universal binary, `LSUIElement`, `LSMinimumSystemVersion`, Developer ID + notarization (note the machine currently has no Developer ID certificate).

13. **Test handles.** For everything a test cannot wait for or provoke, name the handle: the clock behind the tap timeout, the frame source, the button-state sampler, the preference store, the device notifications, the launcher, the actuator.

Judge interface depth explicitly: what each public surface hides, what stays exposed, why it is no larger than needed. Keep the shell thin and the policy in pure functions. Keep the prose to about one page outside the type sketch.
