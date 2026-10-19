# How the launch animation works today, and what exists for watching a launched app

Grounding for plan 017 (launch bounce). It merges four explorer reports (fire path, overlay, tuner, lifecycle). I checked the claims it relies on against the code. Paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/017-launch-wait-bounce/`. Requirement numbers (R1...R19) refer to `plans/017-launch-wait-bounce/plan.md`.

## Overview

A recognised tap reaches the one model, `Launcher` (`LauncherCore`). The model checks three guards, then does four things in one synchronous main-actor turn: it plays the haptic, calls `SystemActions.bringToFront`, calls `SystemActions.playLaunchAnimation` (only when the setting is on) and closes the launcher window. The real `SystemActions` is `WorkspaceActions` (`LauncherPlatform`). It hands the animation to `LaunchOverlay`. The overlay reads the pointer, the displays and Reduce motion at that moment, and has the pure `LaunchFlight` code stage about 0.34 s of Core Animation keyframes. It opens a new click-through panel just for this play and adds the keyframes. When the transaction completes, the panel closes. Nothing ever reports back to the model, and none of our code runs while the animation plays.

The launch bounce clashes with this design in four places. The model does not know whether the app is running. Nothing pushes launch-lifecycle events about other apps to the model. The model has no clock. The overlay's only contract is "fire and forget, never cancel". Today the code does not track the pointer, move an overlay window, end an animation early or know about a launched process. The bounce needs all of these. Two rules constrain how they can be added, and both are enforced: the source-scan test bans timers and display links, and `docs/architecture.md` says every input is a push and no code of ours runs per frame.

## Key concepts

| Concept | Where | What it is |
|---|---|---|
| `Launcher` | `LauncherKit/Sources/LauncherCore/Launcher.swift` | `@MainActor @Observable` model. Every decision is made here. `fire(_:)` (around l.233-244) is the only path from a gesture to an effect. |
| `SystemActions` (port) | `LauncherKit/Sources/LauncherCore/Ports.swift:56-81` | The effects macOS performs. Every member is synchronous: `bringToFront`, `registerLoginItem`, `prepareLaunchAnimations`, `playLaunchAnimation`, `runningApps`, `frontmostWindows`, `raiseWindows`. It has **no `on…` push member**. |
| `AppEntry` | `LauncherCore/Apps.swift:12-30` | `{bundleID, name, url}`. It has no pid and no `NSRunningApplication`. Everything that crosses `SystemActions` uses it as the identity. |
| `RunningApps` | `Apps.swift:31-50` | `{frontmost, apps}`, where `apps` is the **⌘-Tab list**, not a process list. `contains(_ location: URL)` matches by URL. |
| `WorkspaceActions` | `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` | The real `SystemActions`. It owns one `LaunchOverlay`, one `RunningAppsReader` and one `FrontmostAppWindows`. It also has the DEBUG-only `showAnimationTuner()`. |
| `LaunchOverlay` | `LauncherPlatform/LaunchOverlay.swift` | The AppKit/Core Animation shell. It holds the icon cache, creates the panels, installs the keyframes and cleans up on completion. |
| `LaunchFlights` / `LaunchFlight` / `LaunchStage` / `LaunchDisplay` | `LauncherPlatform/LaunchFlight.swift` | Pure, tested geometry and keyframe construction. It never touches `NSScreen` or the pointer: the shell passes those in as values. |
| `LaunchTuning` | `LauncherPlatform/LaunchTuning.swift` | One flat struct holding every flight number, plus three switcher-swipe knobs. Its memberwise defaults are the shipped animation. `LaunchTuning.current` is the single read point. |
| `AnimationTuner` / `TunerModel` / `TunerView` / `tunerOverride` | `LauncherPlatform/AnimationTuner.swift` (the whole file is `#if DEBUG`) | The SwiftUI tuner window, its presets in `UserDefaults`, and the `Mutex` that `LaunchTuning.current` reads in Debug builds. |
| `RecordingSystemActions` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:260-298` | The in-memory `SystemActions`. It records calls and answers scripted running apps and windows. (The overlay report calls it "InMemorySystem". The real name is `RecordingSystemActions`.) |
| `World` | `LauncherKit/Tests/LauncherCoreTests/World.swift` | A real `Launcher` wired to the in-memory adapters, a temp folder of fake bundles and a throwaway defaults suite. |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | A substring scan of all sources. It enforces banned tokens and keeps certain tokens confined to one file. |

## How it works

### 1. End to end, from fired gesture to cleanup

```mermaid
sequenceDiagram
    participant FT as Frame thread (DeviceSession)
    participant MT as MultitouchTrackpads
    participant L as Launcher.fire
    participant WA as WorkspaceActions
    participant LO as LaunchOverlay
    participant LF as LaunchFlight (pure)
    participant CA as Render server
    participant UI as MenuBarShell

    FT->>FT: GestureRecognizer: last tapping finger lifts (within 400 ms)
    FT->>MT: deliver(TrackpadEvent.gesture, reply=nil)
    MT->>MT: DispatchQueue.main.async, drop if stale generation
    MT->>L: onEvent(.gesture(GestureEvent)) via WindowSwipeConfirmation.deliver
    L->>L: guard activity.isActive, assignment, catalog.locate (reads Info.plist)
    L->>MT: playFeedback(.gesture) (actuator, synchronous)
    L->>WA: bringToFront(app) -> NSWorkspace.openApplication, completion dropped
    L->>WA: playLaunchAnimation(app) [if isLaunchAnimationOn]
    WA->>LO: play(for: app)
    LO->>LO: read NSEvent.mouseLocation, NSScreen.screens, Reduce motion
    LO->>LF: flights.next(draw:reduceMotion:), flight.staged(at:among:)
    LF-->>LO: LaunchStage(frame, scale, iconCentre, 3 CAKeyframeAnimations)
    LO->>CA: new NSPanel, orderFrontRegardless, CATransaction{layer + keyframes, completion}
    L->>L: window = .closed
    Note over L,UI: fire returns; later main-actor turn
    UI->>UI: Observations(isWindowOpen) -> hide()
    CA-->>LO: ~0.34 s later, completion: panel.close(), playingPanels.remove
```

**From the frame thread to the main actor.** `contactFrameCallback` (`LauncherPlatform/FrameStream.swift:96-101`) steps a `DeviceSession`'s `GestureRecognizer` under a `Mutex`. A tap fires when the last tapping finger lifts. `MultitouchTrackpads.run` builds a `deliver` closure (`MultitouchTrackpads.swift:95-105`) that hops to the main queue and drops events from a replaced session (by `generation`). It then calls `WindowSwipeConfirmation.deliver`, which passes a `.gesture` straight to `onEvent`. `Launcher.start()` installed that handler (`Launcher.swift:88-96`), and it calls `fire(_:)`. `GestureEvent` carries only `gesture` and `trackpad`: no timestamp and no pointer.

**The decision (`Launcher.fire`).** These steps run in this order (verified):

1. Guards, and every one of them fails silently: `activity.isActive`, then `settings.assignments[event.gesture]`, then `catalog.locate(assigned)`. The last one reads `Contents/Info.plist` from disk on the main actor. It returns an `AppEntry` whose `url` is the catalog's location, not a running process's location.
2. `hardware.playFeedback(.gesture, on:)`: the actuator is driven synchronously. **The haptic is issued before anything visual.** R1 asks that the bounce appear "no later than the haptic". Today that can only mean "in the same main-actor turn".
3. `system.bringToFront(app)`: the same call whether the app is running or not.
4. `if settings.isLaunchAnimationOn { system.playLaunchAnimation(for: app) }`. A comment explains the order: bring-to-front comes first, so the animation's cost lands on the icon and never delays the app. A test asserts this order.
5. `window = .closed`. `MenuBarShell` (`LauncherUI/MenuBarShell.swift:69-72`) hides the panel on a later turn through `Observations({ launcher.isWindowOpen })`.

`fire` never calls `runningApps()`. Today the model has no idea whether the target is running. Nothing about the gesture outlives `fire`: there is no "launches in flight" state. The only per-gesture state the model keeps is `swapSeries` and the shown switcher, and both belong to other features.

**Bring to front (`WorkspaceActions.bringToFront`, l.14-20).** It creates a `NSWorkspace.OpenConfiguration` with `activates = true`, then calls `openApplication(at:configuration:)`. It passes **no completion handler**, on purpose: the comment says "its only reactions would be a log line or a dialog". So the launched `NSRunningApplication` (and its pid) is never learned, and a launch error is never seen.

**Play (`LaunchOverlay.play(for:)`, l.34-69).** Everything happens synchronously inside the call:

- It reads the system now: `NSEvent.mouseLocation` (Cocoa global coordinates, y up, the same space as `NSScreen.frame`, so nothing is ever flipped), `NSScreen.screens` mapped to `[LaunchDisplay(frame:scale:)]`, and Reduce motion as `accessibilityDisplayShouldReduceMotion || LaunchTuning.current.forceReduceMotion`.
- `flights.next(draw: .random(in: -1...1), reduceMotion:)`. The shell draws the random number, and the pure code receives it as a parameter.
- `flight.staged(at: pointer, among: displays)` and `makePanel(frame:)`. If either returns nil, the call is a silent no-op.
- The panel goes into `playingPanels` (AppKit keeps closed panels in `NSApp.windows`, so the overlay tracks its own), then `orderFrontRegardless()`.
- One `CATransaction` with `setDisableActions(true)`. Its completion block runs `MainActor.assumeIsolated { panel.close(); self?.playingPanels.remove(panel) }`. It holds `panel` strongly and `self` weakly. Inside the transaction a new 60 pt `CALayer` gets its contents from `bitmap(for:scale:)`, its `contentsScale` from the stage, and a trilinear minification filter. For each of the three staged animations, the layer's model value is set to the last keyframe first, so nothing snaps back when the animation is removed. Then the animation is added.

**Cleanup.** The render server plays the keyframes. The completion block closes the panel. According to the overlay report, plan 004 measured the completion arriving 9-19 ms after the animation ends. That completion block is the only "time passes" mechanism in the app.

### 2. Before any gesture: the icon pass

`Launcher.resolveRows()` (`Launcher.swift:330-338`) runs from `start()`, `setAssignment` and `openWindow()`. It calls `system.prepareLaunchAnimations(for:)` with the present assigned apps, de-duplicated by URL. It does this even when the launch animation setting is off. `LaunchOverlay.prepare(for:)` renders every icon off the main actor (`@concurrent renderOffMain`, `DispatchQueue.concurrentPerform`). Each icon is drawn at `peakSide` (72 pt = 60 x 1.2 pop) times the highest backing scale, in Display P3. The results **replace** the whole `icons: [URL: CGImage]` dictionary. The cache key is the bundle URL only: there is no appearance or modification stamp. At play time, `bitmap(for:scale:)` returns the cached image if it is at least as wide as needed. Otherwise it renders **synchronously on the main actor** and caches the result. This happens when the app moved, when a sharper display was connected, or when the prepare `Task` has not finished yet. `docs/architecture.md` documents this as an exception.

The overlay does not use `LauncherUI`'s `AppIcons`: `LauncherPlatform` cannot import `LauncherUI` (`LauncherKit/Package.swift`). A bounce of the same app at 60 pt (R4) can use the same cache, because the 72 pt bitmap passes the `width >= pixels` check.

### 3. Staging: the pure geometry (`LaunchFlight.swift`)

- `LaunchFlights.next` returns `.fadeInPlace` under Reduce motion, and that flight does not count toward the "never three sway sides in a row" streak. Otherwise it picks a side from the sign of the draw, flips the side if the last two flights went the same way, and computes a sway magnitude between `minimumSway` and 1 times `maximumSway`. One `LaunchFlights` exists per overlay, and real plays and tuner previews share it.
- `pose(at u:)` describes a pop phase, where the icon swells in place with an ease-out, then a flight phase. In the flight phase, rise, drift, shrink, tilt and fade each follow power curves of `u`.
- The pose is sampled at 240 per second (`steps = max(10, duration*240)`). It becomes three parallel `CAKeyframeAnimation`s: `position`, `transform` (rotation with scale) and `opacity`. They share `keyTimes`, use `.linear` calculation, and have no timing functions and no group: the easing is baked into the dense samples.
- `staged(at:among:)` (l.116-129) picks the display with AppKit's `NSMouseInRect` rule, or the nearest display if none matches. It pixel-snaps the start point. It takes the union of each pose's rotated bounding square as `reach`. The panel frame is `reach ∩ display.frame`, so near an edge the icon is **clipped, not slid** sideways. The icon's centre starts **on the pointer tip**.

This code lives in `LauncherPlatform`, not `LauncherCore`, because it uses `CAKeyframeAnimation`, `NSValue` and `NSMouseInRect`, and `LauncherCore` may import only `Foundation` and `Observation` (enforced by `SourcePolicyTests`).

### 4. The panel

`LaunchOverlay.makePanel` (l.120-139) creates a borderless `.nonactivatingPanel` that is clear, has no shadow, has `ignoresMouseEvents = true` and level `.screenSaver`. Its behaviour includes `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, and it sets `hidesOnDeactivate = false` and `animationBehavior = .none`. The content is a plain, non-flipped, layer-backed `NSView`. **Every play gets its own panel, sized to that flight's reach and positioned once.** The panel never moves, is never reused and never comes from a pool. Overlapping plays are independent: each has its own panel, its own transaction and its own completion. `init()` creates and closes a 1x1 panel, because a process's first window costs about 27 ms.

`LauncherUI/OverlayPanel.swift` is a separate precedent for a long-lived overlay that is presented again and again. Its `dismiss` fades from `layer.presentation()?.opacity`, which continues from the in-flight value. A `generation` counter guards stale fade completions (l.95-115). This is the closest existing pattern for "end an animation partway through and continue from wherever it is".

### 5. Tuning: shipped vs live, the tuner and presets

- **Release:** `LaunchTuning.current` returns `shipped` (the memberwise defaults). The tuner, `Codable` and the `Mutex` do not exist in Release.
- **Debug:** `current` reads `tunerOverride.withLock { $0 }`, a module-level `Mutex(LaunchTuning.shipped)` in `AnimationTuner.swift:9`. `TrackpadLauncher/TrackpadLauncherApp.swift` calls `system.showAnimationTuner()` under `#if DEBUG` after `launcher.start()`. This is why the composition root keeps `system` as the concrete `WorkspaceActions` instead of the port type. The tuner opens on every Debug launch. It has no close button and no menu item to reopen it.
- `TunerModel.init` loads `"AnimationTuner.current"` from `UserDefaults.standard` and pushes it into `tunerOverride`. **A Debug build therefore plays the last tuner state, not the shipped one.** Plan 014 was bitten by this. On every knob change, `tuning.didSet` writes the override and stores the JSON.
- **"Preview at pointer"** calls the single closure `WorkspaceActions` injected: `{ [overlay] in overlay.play(for: finder) }`. It plays a hard-coded Finder `AppEntry` straight through the overlay and skips `Launcher` entirely, so the setting and the activity guard do not apply. Because the button was just clicked, the preview plays at the pointer, above the tuner (`.screenSaver` sits above `.floating`).
- **Per-preset play** uses `TunerModel.preview(_:play:)` (verified, around l.91-96): set the override to the preset, call `play()`, then **restore the live tuning straight away**. This works only because `play` reads every tuning value synchronously while it stages.
- **Presets:** three keys in `UserDefaults.standard`: `AnimationTuner.current`, `AnimationTuner.presets` and `AnimationTuner.selected`. `TuningPreset` nests `LaunchTuning`. `LaunchTuning`'s Debug-only `Codable` has a hand-written `init(from:)` that does `decodeIfPresent ?? shipped.<field>` for each key, while `encode` and `CodingKeys` are synthesised. A missing key falls back to shipped, which is what R19 asks for. The tuner report found that the real saved presets on this machine predate the `swipe*` keys and still load. That shows old presets are in use and depend on this fallback.
- **Layout:** `TunerView` is a grouped `Form` of sections. Each numeric control is built by `knob(_:_ keyPath: WritableKeyPath<LaunchTuning, Double>, range, step, unit, hint)`, which includes a revert-to-shipped button. Bool controls use `Toggle`. The "Switcher swipe" section, with its header and footer, is the template for a self-contained section. No section has its own button today: the only preview button is in the bottom bar.

### 6. What the code observes about other apps today

| Mechanism | Where | Push or pull | Reaches the model? |
|---|---|---|---|
| `runningApps()` -> `RunningAppsReader.read()` | `LauncherPlatform/RunningAppsReader.swift`, `LaunchServicesOrder.swift` | Pull, read now | Yes, but only for swipe and swap, not `fire` |
| `frontmostWindows()` -> `FrontmostAppWindows.read()` | `LauncherPlatform/FrontmostAppWindows.swift` | Pull, AX + `CGWindowList`, frontmost app only | Yes, for window swipes |
| `didLaunch` / `didTerminateApplicationNotification` | `LauncherUI/SwitcherPresenter.swift:44-67` | Push, main queue | No. It only warms the switcher's icon cache, and only while the swipe setting is on |
| `didActivateApplicationNotification` | `LauncherPlatform/ActivationTracker.swift` | Push | No. It exists only on the fallback path when the private LaunchServices order is missing |
| `didWakeNotification` | `MultitouchTrackpads.swift:48-52` | Push | As `.trackpadsChanged` |
| `NSRunningApplication.runningApplications(withBundleIdentifier:)` | `LauncherUI/AppIcons.swift:53` | Pull | No (icon borrowing) |

The code has nothing for `isFinishedLaunching`, `isTerminated` KVO, `willLaunch`, `AXObserver`, `kAXWindowCreated`, or a launched pid.

**The push-port shape to copy:** each of the four push ports has a `var on…: (@MainActor (…) -> Void)? { get set }` property that `Launcher.start()` sets once: `TrackpadHardware.onEvent`, `TrackpadPreferences.onChange`, `Permissions.onChange` and `AppScanner.onScan`. The adapters deliver to the main actor in one of these ways:

- NotificationCenter with `queue: .main` plus `MainActor.assumeIsolated`.
- `notify_register_dispatch` on `.main`.
- KVO followed by `Task { @MainActor in … }`.
- IOKit and FSEvents on `.main`.

Adapters remove their observers in an `isolated deinit`. `SystemActions` has no push member at all.

## Module ownership and seams

```
TrackpadLauncher/TrackpadLauncherApp.swift   composition root only (+ DEBUG showAnimationTuner call)
        │ builds
        ▼
LauncherCore  (Foundation + Observation only)
  Launcher (model, every decision) ── ports: TrackpadHardware, TrackpadPreferences,
  domain types, pure policy                    Permissions, AppScanner, SystemActions
        ▲ implements ports                      ▲ observes model via Observations
LauncherPlatform (AppKit, CA, IOKit, AX...)     LauncherUI (menu bar shell, SwiftUI, switchers)
  WorkspaceActions ─ LaunchOverlay ─ LaunchFlight (pure) ─ LaunchTuning
                   ─ RunningAppsReader ─ LaunchServicesOrder
                   ─ FrontmostAppWindows (only AX/CGWindowList file)
  AnimationTuner (#if DEBUG)
```

- **Pure policy vs shell.** The pure parts are `LaunchFlight`/`LaunchFlights` (geometry, randomness taken as input, keyframes), `FallbackOrder`, and `FrontmostAppWindows.sort`. The shell parts are `LaunchOverlay` (system reads, panels, cache, `.random`) and the adapters. Pure code is unit-tested. The shell is not.
- **`LauncherPlatform` cannot see `LauncherUI`, and the reverse is also true.** Both depend only on `LauncherCore`. As a result, two "pointer's display" rules exist: `LaunchFlight.display(for:)` and `LauncherUI/Displays.screen(under:)`.
- **Confined files** (`SourcePolicyTests.confined`, matched on the file's `lastPathComponent`):
  - `AXUIElement` and `CGWindowList` → `FrontmostAppWindows.swift`.
  - `tapCreate`, `CGEventTapCreate`, `tapEnable`, `tapIsEnabled`, `scrollWheel` → `ClickTap.swift`.
  - The private LaunchServices symbols → `LaunchServicesOrder.swift`.
  - `AXIsProcessTrusted`, `notify_register`, `ScreenCaptureAccess` → `SystemPermissions.swift`.
  - The ScreenCaptureKit symbols → `PreviewCapture.swift`.

## Contracts and invariants the code promises

1. **The launch animation is fire and forget.** The doc comment on `SystemActions.playLaunchAnimation` (`Ports.swift:65-68`) says it "returns at once", reads the pointer, displays and Reduce motion at the moment of the call, plays for about a third of a second and removes itself. It also says "Every call plays its own animation and never cancels, restarts or reuses one already playing", and that nothing it shows activates the app, becomes key or receives a click.
2. **No timers, no polling, no per-frame code** (`docs/architecture.md`, Concurrency section). "Every input is a push." "Animation is Core Animation keyframes … cleaned up from its completion callback. No code of ours runs per frame, and display links are banned along with timers." `SourcePolicyTests.banned` enforces this with plain case-sensitive substring matches on every line, **comments and `#if DEBUG` code included**: `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink`. A name like `bounceTimer`, or a comment saying "no Timer", fails the test. `ContinuousClock`, `perform(afterDelay:)`, a `.mouseMoved` NSEvent monitor and `CACurrentMediaTime` are not banned by token, but most of them break the written rule. None of them appears in the sources today. `repeatCount` and `repeatDuration` are not used anywhere either.
3. **Framework types never cross a port** (`docs/architecture.md`, Shape section). `NSRunningApplication`, `NSImage`, `CGEvent` and the like stay inside adapters. The core has no pid.
4. **Every port has exactly two adapters:** the real one in `LauncherPlatform` and an in-memory one in the tests. Anything that delivers asynchronously goes behind a port, so the model's tests stay synchronous. Ports and the public surface of the real adapters are `@MainActor`.
5. **Developer tools are `#if DEBUG` only.** There are five DEBUG boundaries:
   - `LaunchTuning.current`
   - `LaunchTuning: Codable`
   - all of `AnimationTuner.swift`
   - `WorkspaceActions.tuner` / `showAnimationTuner()`
   - the call in the composition root

   Release reads `shipped`.
6. **`LauncherCore` imports only `Foundation` and `Observation`.**
7. **Accessibility has a narrow stated use** (`docs/architecture.md`, Privacy section): click, scroll and Dock-swipe blocking, plus listing and raising the frontmost app's windows during a window swipe. A new AX use, such as watching a launching app's windows, would contradict that sentence as it is written.
8. **Every decision is made in `Launcher`.** `fire` is the only place a gesture becomes effects. Its doc comment says: "Every silent case decided here and only here".

## How tests drive this

- **Model tests** (`LauncherCoreTests`, Swift Testing, `@MainActor @Suite struct`, long descriptive `@Test` names). The pattern is: `let world = World(apps: ["Figma"])`, then `world.launcher.start()`, then `setAssignment(.app(world.app("Figma")), for: .two)`, then `world.tap(2)`. `InMemoryTrackpads.touch` runs synthetic `TouchScript` frames, 10 ms apart, through the **real** recognizer and delivers each event inline. There is no dispatch, so the whole fire path runs synchronously inside `world.tap`.
- **What a test can assert:**
  - On `RecordingSystemActions`: `broughtToFront`, `launchAnimations`, `preparedLaunchAnimations`.
  - On `InMemoryTrackpads`: `pulses`, `feedback`, `lightTicks`.
  - On the model: `isWindowOpen`.

  Settable `frontmost`/`running` answers `runningApps()`, through the World helpers `makeRunning`, `makeFrontmost` and `activate`. **Order** is asserted with a hook: `onPlayLaunchAnimation` runs inside the call, so the first test in `LauncherTests.swift` captures `broughtToFront` at that moment. Nothing records order across adapters, so "haptic before bring-to-front" is never asserted.
- **Simulating pushes:** each in-memory adapter keeps the same `on…` closure and calls it synchronously, for example `InMemoryPermissions.set(_:granted:push:)` or `InMemoryAppScanner.holdScans()`/`deliverHeldScan()` to model latency. A lifecycle push for the bounce would follow the same pattern: the fake gains methods such as "app X finished launching" that call the closure inline.
- **Time in tests:** the only time anywhere is `TouchScript`'s synthetic `FrameTime`. No test waits in real time, and nothing injects a clock or scheduler.
- **Platform pure tests** (`LauncherPlatformTests/LaunchFlightTests.swift`): `LaunchStage.keyframes()` decodes the produced `CAKeyframeAnimation` values back into `Keyframe` samples (time, screen position, side, rotation, opacity). Two fixture displays are used, `builtIn` (1512x982 @2x) and `external` (2560x1440 @1x, above it). Tests are parameterised over draws and the Reduce-motion flag, and they assert **requirement bounds, not formulas**: peak 66-78 pt within 0.1 s, rise 60-80 pt, invisible between 0.3 and 0.4 s, top-edge clipping, display choice. `LaunchTuning.current` equals `shipped` under `swift test`, because no test builds a `TunerModel`.
- **Gaps in coverage:** nothing tests `LaunchTuning`'s `Codable`, `TuningPreset` or `TunerModel`. `TunerModel` hard-codes `UserDefaults.standard` and writes the global `tunerOverride`, which makes it awkward to test. Decoding `LaunchTuning` from JSON can be tested directly in `LauncherPlatformTests`, since DEBUG is on there. Shell code such as `LaunchOverlay` has no unit tests.
- **Negative checks** ("never the launch animation") exist in the swipe, swap, window-switching and tap-gate suites. The bounce will need equivalents for R3.

## What the bounce needs that the code does not have

| Need (requirement) | Today | Constraint on adding it |
|---|---|---|
| **Is the target running?** (R1, R2, R14) | `fire` never asks. `runningApps()` is the ⌘-Tab list: it excludes menu bar (UIElement/accessory) apps unless one is frontmost, so a running menu bar app would read as "not running". The only "any process for this bundle" read is `NSRunningApplication.runningApplications(withBundleIdentifier:)` in `LauncherUI/AppIcons.swift` | It needs a `SystemActions` read (or a new port) that answers in domain terms. Identity choice: assigned-vs-running matching uses **bundle ID** (`Switcher.init` filters by `assignedBundleIDs`). Matching by URL between a catalog `AppEntry` and a running `AppEntry` is **not guaranteed**: running entries share one spelling (`AppEntry.location(ofBundleAtPath:)`, `URL(fileURLWithPath:isDirectory: true)`), but catalog URLs come from `contentsOfDirectory`, `lastKnownURL` or `registeredCopies`. The two reports disagreed on this. The code only promises that running-app entries compare equal to each other |
| **Launch result / pid / failure** (R11 "fails to launch") | `bringToFront` drops `openApplication`'s completion. `bringToFront` returns `Void` | The completion arrives off the main thread with `NSRunningApplication?`/`Error?`. Those types must not cross a port, so the adapter has to translate them into a domain event. Changing `bringToFront`'s contract also touches `RecordingSystemActions` |
| **Finished launching** (R10, R12) | Nothing | Possible push sources: `didLaunchApplicationNotification` (documented as not posted for LSUIElement apps) or KVO on `NSRunningApplication.isFinishedLaunching`. Both are unverified in this repo. The existing `didLaunch` observer lives in `LauncherUI`, is tied to the swipe setting, and is not a port |
| **Quit before window** (R11) | Only `didTerminate` in `SwitcherPresenter`, which serves the icon cache | Same as above: KVO on `isTerminated` or the notification, translated into a domain event |
| **First window shows, within 50 ms, splash counts** (R9) | `FrontmostAppWindows` reads only the **frontmost** app, by pull. Its pid-parameterised helpers (`windowList(_:of:)`, `onScreenNumbers(of:)`) are `private` and keep only `kCGWindowLayer == 0` | The only push for window creation is an `AXObserver` (`kAXWindowCreatedNotification`). That needs Accessibility, an app whose AX server already answers, and the process-wide 0.2 s messaging timeout. `AXUIElement` and `CGWindowList` are **confined to `FrontmostAppWindows.swift`**, so either the code goes there or the confinement table changes. A `CGWindowList` pull would need polling, which is banned. Without Accessibility there is no push at all, so a fallback ending is required |
| **A clock: 2 s after finished launching, 10 s cap** (R10, R12), **3 s preview** (R18) | The model has no time. The only time source is Core Animation durations and completion blocks | Timer, `asyncAfter`, `Task.sleep` and display links are banned by token. The model's tests must stay synchronous, so a deadline has to reach the model as a **push from an adapter** (faked inline in tests), not as a clock inside the model. The house style is to let a Core Animation animation's duration be the clock (`repeatDuration`, or a finite animation plus a transaction completion). Completions arrive about 10-20 ms late. Whether a CA completion used as a deadline is acceptable is a design decision, and no precedent exists |
| **Follow the pointer every frame** (R7) | Nothing tracks the pointer. Pointer reads are one-shot `NSEvent.mouseLocation` calls (overlay, both switcher presenters). The only NSEvent monitor is `MenuBarShell`'s mouse-down monitor while the window shows. `ClickTap`'s CGEvent taps do not mask `mouseMoved` and are gated to thumb touches | This would be the first code of ours that runs per pointer event, which conflicts with "no code of ours runs per frame". A `.mouseMoved` global monitor is not banned by token, but global monitors miss events delivered to our own windows (the launcher window, the tuner), so a local monitor would be needed too. Display links are banned. Moving a `.screenSaver`, `.stationary` panel with `setFrameOrigin` on every event has never been tried here, and neither has moving a layer inside a panel the size of the display or one panel per display. R7's "follow onto another display" and the multi-display panel shape are open |
| **End a running animation partway and play a different one from the current spot** (R9, R11) | The port says "never cancels". Each play builds a new panel sized to its own reach, and `staged(at:)` starts from a pointer. Nothing returns a handle | It needs a new port method or contract, e.g. start a bounce, then end it with float-away or fade. `staged(at:)` already takes a start point, so float-away could stage from the bounce's presentation position (`layer.presentation()`, as `OverlayPanel.dismiss` does). The float-away's reach may not fit the bounce's panel, so either the bounce panel grows or a new panel is made |
| **Per-app bounces in flight** (R13, R14) | No model state outlives `fire` | The model needs state keyed by app identity, so that a repeated gesture keeps the one bounce, bounces sit in a row, and each one ends on its own app's events. It must be testable through `World` |
| **Edge behaviour** (R6) | Clipping only: `reach ∩ display.frame`, no sideways move. The icon is centred **on** the pointer | Rest 8 pt above the tip (R5), slide sideways at left and right, clip at the top. This is new pure geometry and fits the `LaunchFlight` pure/shell split and its test style |
| **Reduce motion pulse** (R15) | Reduce motion maps to `.fadeInPlace` for the flight only | A new pulse mode, read by the adapter as today |
| **Tuner: bounce section, preview, presets** (R17-R19) | One preview closure, `AnimationTuner(preview:)`. Every knob is a flat `Double` on `LaunchTuning`. `preview(_:play:)` swaps the override back straight away | It needs a second preview closure or a richer interface from `WorkspaceActions`. A bounce lasts seconds, so it must **snapshot its tuning at start**, otherwise per-preset previews would see the restored live tuning. Each new field needs a `value(.x, s.x)` line in `init(from:)`; the compiler does not catch a missing line, and the saved value silently reverts to shipped. A nested struct (`\.bounce.height`) works with `knob`'s keypath and revert logic. The 3-second preview end cannot use a timer |

## Where things live

| Path | Why you would open it |
|---|---|
| `LauncherKit/Sources/LauncherCore/Launcher.swift` | `start()` (installs the handlers), `fire(_:)`, `resolveRows()`, `setLaunchAnimation(on:)` |
| `LauncherKit/Sources/LauncherCore/Ports.swift` | `SystemActions` and its contracts; the shape of the push ports |
| `LauncherKit/Sources/LauncherCore/Apps.swift` | `AppEntry`, `RunningApps`, `AppCatalog.locate` |
| `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` | Real `SystemActions`; `bringToFront`; the tuner hookup |
| `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift` | Panels, icon cache, `play` |
| `LauncherKit/Sources/LauncherPlatform/LaunchFlight.swift` | Pure staging and keyframes |
| `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift` | Knobs, `shipped`/`current`, tolerant decoder |
| `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift` | DEBUG tuner, presets, `tunerOverride` |
| `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift`, `LaunchServicesOrder.swift`, `RunningApp.swift` | Running-app reads and the URL spelling |
| `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift` | The only AX/`CGWindowList` file |
| `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`, `OverlayPanel.swift` | `didLaunch`/`didTerminate` observer precedent; fade-from-presentation precedent |
| `TrackpadLauncher/TrackpadLauncherApp.swift` | Composition root |
| `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`, `World.swift`, `LauncherTests.swift` | Fakes, harness, fire-path tests |
| `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` | How pure animation code is tested |
| `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Bans and confinement |
| `docs/architecture.md` | Stated rules (Shape, Concurrency, Privacy sections) |

## Gotchas

- **Substring bans include comments.** Writing "Timer", "DisplayLink" or "AXUIElement" in a comment in the wrong file fails `swift test`. Name things to avoid them, for example "deadline" or "cap".
- **The haptic comes before the visuals today.** If the bounce is built in a later turn, for instance after an async running check, it would arrive after the haptic and break R1.
- **`runningApps()` is not a process list.** Using it to decide whether to bounce would wrongly bounce a running menu bar app (R2/R14). Whether an app still launching from the Dock already appears in `_LSCopyApplicationArrayInFrontToBackOrder` is unknown.
- **`catalog.locate` reads Info.plist on the main actor at every fire**, before the haptic. Any new read added to `fire` adds to that same synchronous cost.
- **Debug plays the last tuner state, not shipped.** New bounce knobs start at shipped for everyone, because old saved blobs lack those keys. Tuner state is shared across all worktrees' Debug builds through the same bundle-ID defaults domain.
- **A wrong-typed key in a saved preset drops the whole preset list**, and the next save overwrites it. Do not change an existing field's type. Renaming a field silently drops saved values.
- **The tuner preview skips `Launcher`.** That is convenient for a bounce preview: Finder is always running, so a real gesture would never bounce it. It also means the preview does not exercise the model's running check.
- **`WorkspaceActions` is held concretely** only so the DEBUG tuner can reach `overlay` outside the port. A bounce preview would reach the overlay the same way.
- **`playingPanels` exists because AppKit keeps closed panels in `NSApp.windows`.** Any long-lived bounce panel needs the same lifetime bookkeeping.
- **Stale docs:** `docs/architecture.md` and plan 004 describe the overlay bitmap as 46 pt and rendered on the main thread. The code renders at 72 pt (`peakSide`) off the main actor.
- **`window = .closed` happens in `fire` regardless of the animation.** R16's "the launcher window closes on the gesture as today" holds as long as the bounce path keeps that statement.

## Open questions the explorers left

1. When `openApplication`'s completion fires relative to `isFinishedLaunching` and `didLaunchApplicationNotification`, and what error it reports while a Gatekeeper "are you sure" prompt is pending or after it is declined (R11).
2. Whether `didLaunchApplicationNotification` and `didTerminateApplicationNotification` fire for LSUIElement menu bar apps on current macOS. Apple's docs say they do not, and KVO on `NSRunningApplication` is the documented route. The repo never exercises this.
3. Whether a still-launching app appears in the private LaunchServices front-to-back array (R2, "launching from the Dock counts as running").
4. How early an `AXObserver` can be registered on a just-launched pid, and whether `kAXWindowCreatedNotification` fires reliably for splash windows (which may be at non-zero window levels) and for windows on another Space.
5. Whether moving an overlay panel on every `.mouseMoved` event is smooth enough to count as "no visible lag", and whether a global monitor needs any permission or keeps working while a full-screen app is in front. The repo has no probe for either.
6. Whether a Core Animation completion used as a deadline (2 s, 10 s, the 3 s preview) is acceptable under the "no timers" rule. This is a design call. The code shows only that CA completions are the one existing time mechanism.
7. Whether URL equality between a catalog-located `AppEntry` and a running app's `AppEntry` holds for every app (trailing slash, firmlinks, Safari under Cryptexes). Bundle ID is the safer precedent.
