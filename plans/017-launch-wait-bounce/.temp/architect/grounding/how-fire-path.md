# Grounding: the gesture fire path in the model (angle: model decision, ports, composition, tests)

All paths relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/017-launch-wait-bounce/`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `Launcher` (`@MainActor @Observable public final class`) | `LauncherKit/Sources/LauncherCore/Launcher.swift:8-348` | The one model; `fire(_:)` (lines 233-244) is the only path that pulses/launches/plays the launch animation/closes the window from a gesture. |
| `TrackpadHardware` (port) | `LauncherKit/Sources/LauncherCore/Ports.swift:26-46` | Multitouch hardware: `var onEvent: (@MainActor (TrackpadEvent) -> Void)?`, `func connected() -> [Trackpad]`, `func run(_:handMode:blockClicks:slides:swaps:)`, `func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)`, `func confirmWindowSwipe(on:)`. Real: `MultitouchTrackpads`. Fake: `InMemoryTrackpads`. |
| `SystemActions` (port) | `LauncherKit/Sources/LauncherCore/Ports.swift:56-81` | Effects macOS performs: `bringToFront(_ app: AppEntry)`, `registerLoginItem()`, `prepareLaunchAnimations(for apps: [AppEntry])`, `playLaunchAnimation(for app: AppEntry)`, `runningApps() -> RunningApps`, `frontmostWindows() -> FrontmostWindows`, `raiseWindows(_ frontToBack: [WindowID])`. Real: `WorkspaceActions`. Fake: `RecordingSystemActions`. All methods are synchronous, return-at-once; no callback/`on…` property exists on this port. |
| `TrackpadPreferences` (port) | `Ports.swift:49-54` | `onChange`, `current()`. Real: `SystemTrackpadPreferences`. Fake: `InMemoryTrackpadPreferences`. Feeds `activity` (the fire guard). |
| `Permissions` (port) | `Ports.swift:89-97` | `onChange`, `isGranted(_:)`, `ask(_:)`. Real: `SystemPermissions`. Fake: `InMemoryPermissions`. Not used by `fire`. |
| `AppScanner` (port) | `Ports.swift:100-106` | `onScan`, `scan()`. Real: `SystemAppScanner`. Fake: `InMemoryAppScanner`. Not used by `fire`. |
| `AppCatalog` (struct, NOT a port; "local-substitutable") | `LauncherKit/Sources/LauncherCore/Apps.swift:155-234` | Apps on disk; `locate(_ app: AssignedApp) -> AppEntry?` (lines 221-228) is the "missing" check in `fire`. Tests point it at a temp dir. |
| `SettingsStore` (struct, not a port) | `LauncherKit/Sources/LauncherCore/Settings.swift:52-73` | Plist record in `UserDefaults`; tests use a throwaway suite. |
| `Settings` | `Settings.swift:7-49` | `assignments: [Gesture: AssignedApp]`, `isLaunchAnimationOn = true` (line 12), etc. |
| `GestureEvent` | `LauncherKit/Sources/LauncherCore/Gesture.swift:14-22` | `gesture: Gesture`, `trackpad: TrackpadID`. No timestamp, no pointer. |
| `TrackpadEvent` | `Ports.swift:3-20` | `.gesture(GestureEvent)`, `.swipe`, `.windowSwipe`, `.swap`, `.trackpadsChanged`; `init(_ event: Recognition.Event, on:)` maps `.fired(g)` -> `.gesture(GestureEvent(...))`. |
| `Haptic` | `Ports.swift:23` | `enum Haptic { case gesture, lightTick }`. |
| `RunningApps` | `Apps.swift:33-50` | `frontmost: AppEntry?`, `apps: [AppEntry]` (⌘-Tab apps), `contains(_ location: URL) -> Bool` (compares `url`). |
| `AppEntry` / `AssignedApp` | `Apps.swift:12-30`, `53-66` | `AppEntry(bundleID, name, url)`; `AssignedApp(bundleID, name, lastKnownURL)`. |
| `GestureActivity` | `LauncherKit/Sources/LauncherCore/Activity.swift:55-72` | `.active` / `.inactive(cause)`; `isActive` is the first guard in `fire`. |
| `WindowSwipeConfirmation` | `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift:6-33` | Shared by both hardware adapters: every event reaches `onEvent` through `deliver(_:to:)`; for non-window-swipe-start events it just calls the handler and returns nil. |
| `WorkspaceActions` (real `SystemActions`) | `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:5-56` | Owns a `LaunchOverlay`, a `RunningAppsReader`, a `FrontmostAppWindows`. |
| `LaunchOverlay` | `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift:10-140` | Plays one launch animation per call in its own click-through panel; reads pointer, displays, Reduce motion itself. |
| `RunningAppsReader` | `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift:5-44` | Backs `runningApps()`: private LaunchServices ⌘-Tab order, or fallback over `NSWorkspace.runningApplications`. |
| `LaunchServicesOrder` | `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift:8-52` | `_LSCopyApplicationArrayInFrontToBackOrder` + `_LSCopyApplicationInformation`; keeps only `ApplicationType == "Foreground"`. |
| `ActivationTracker` | `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift` | Fallback-only `didActivateApplicationNotification` observer. |
| `RunningApp.entry(for:)` | `LauncherKit/Sources/LauncherPlatform/RunningApp.swift:5-20` | The one place an `NSRunningApplication` becomes an `AppEntry`; url via `AppEntry.location(ofBundleAtPath:)`. |
| `MultitouchTrackpads` (real `TrackpadHardware`) | `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:10-169` | Runs sessions, hops recognised events to main, owns actuators for haptics. |
| `DeviceSession` + `contactFrameCallback` | `LauncherKit/Sources/LauncherPlatform/FrameStream.swift:23-101` | Frame-thread side: steps the recognizer, calls `deliver` with the `TrackpadEvent`. |
| `InMemoryTrackpads`, `RecordingSystemActions`, `FakeWindows`, `InMemoryPermissions`, `InMemoryTrackpadPreferences`, `InMemoryAppScanner` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` | The in-memory adapters. |
| `World` | `LauncherKit/Tests/LauncherCoreTests/World.swift:36-302` | Real `Launcher` over the in-memory adapters + temp dir of fake bundles + throwaway defaults suite. |
| `TouchScript` | `LauncherKit/Tests/LauncherCoreTests/TouchScript.swift` | Synthetic frames 10 ms apart, `FrameTime(seconds: 1.0 + ms/1000)` (line ~220). |
| `MenuBarShell` | `LauncherKit/Sources/LauncherUI/MenuBarShell.swift:69-72` | Observes `launcher.isWindowOpen` via `Observations` and hides the panel. |
| Composition root | `TrackpadLauncher/TrackpadLauncherApp.swift:6-27` | Builds everything. |

## Flow (exact order)

### A. Frame thread -> main actor (real adapter)
1. `contactFrameCallback` (`FrameStream.swift:96-101`) on MultitouchSupport's thread finds the `DeviceSession` in the `sessions` Mutex, builds a `TouchFrame` (`TouchFrameParsing.swift:54`, `FrameTime(seconds: timestamp)`), calls `session.receive(frame)`.
2. `DeviceSession.receive` (`FrameStream.swift:54-80`) steps the `GestureRecognizer` under its Mutex; a tap fires when the last tapping finger lifts (`GestureRecognizer.swift:136-137`: `event = Gesture(fingerCount: tap.touched.count).map(Recognition.Event.fired)`), within `GestureRules.maxTapDuration` 400 ms. `reply` is nil for anything but a window swipe start. Calls `deliver(TrackpadEvent(event, on: trackpad), reply)`.
3. `deliver` closure built in `MultitouchTrackpads.run` (`MultitouchTrackpads.swift:95-105`): `DispatchQueue.main.async { MainActor.assumeIsolated { guard let self, self.runs == generation else { return }; let answer = self.confirmation.deliver(event, to: self.onEvent); ... } }`. Events from a replaced session (stale `generation`) are dropped. FIFO main queue keeps frame order.
4. `WindowSwipeConfirmation.deliver` (`WindowSwipeConfirmation.swift:16-26`): for `.gesture` just calls `handler?(event)`, returns nil.
5. `Launcher.start()` installed `hardware.onEvent` (`Launcher.swift:88-96`): `case .gesture(let fired): fire(fired)`.

### B. The model's decision: `Launcher.fire(_ event: GestureEvent)` (`Launcher.swift:233-244`), verbatim order
```swift
private func fire(_ event: GestureEvent) {
    guard activity.isActive,
          let assigned = settings.assignments[event.gesture],
          let app = catalog.locate(assigned)
    else { return }
    hardware.playFeedback(.gesture, on: event.trackpad)
    system.bringToFront(app)
    // After bring to front, so whatever the animation costs lands on the icon, never on the app.
    if settings.isLaunchAnimationOn { system.playLaunchAnimation(for: app) }
    window = .closed
}
```
1. Guard 1: `activity.isActive` - derived each call from `connected` + `preferenceValues` (`Launcher.swift:30-32`, `Activity.swift:62-71`); covers an event recognised just before activity flipped (tested via `InMemoryTrackpads.inject`).
2. Guard 2: assignment lookup `settings.assignments[event.gesture]` (unassigned -> silent).
3. Guard 3: missing check `catalog.locate(assigned)` (`Apps.swift:221-228`): `lastKnownURL` if outside Trash and Info.plist still has the bundle ID, else first of `registeredCopies(bundleID)` passing the same test. This does synchronous disk I/O (reads `Contents/Info.plist`) on the main actor at fire time. Returns a fresh `AppEntry` whose `url` is the catalog URL (not a running-app URL).
4. Haptic: `hardware.playFeedback(.gesture, on: event.trackpad)` - real: `MultitouchTrackpads.playFeedback` (`MultitouchTrackpads.swift:119-122`) synchronously calls `framework.actuatorActuate(actuator, 6, 0, 0, 0)` (`.gesture` = 6, `.lightTick` = 3, lines 127-132); no-op if the trackpad has no open actuator. Fake: appends `Pulse` to `pulses` (`InMemoryAdapters.swift:81`).
5. Bring to front: `system.bringToFront(app)`.
6. Launch animation: only `if settings.isLaunchAnimationOn`, `system.playLaunchAnimation(for: app)`.
7. `window = .closed` (closes even a `.heldOpen` first-launch window; `dismissWindow()` would not). The shell reacts asynchronously: `MenuBarShell` loops `for await open in Observations({ launcher.isWindowOpen }) { if open { show() } else { hide() } }` (`MenuBarShell.swift:69-72`), i.e. on a later main-actor turn.

So the order is: haptic -> bringToFront -> launch animation -> window closed. The haptic precedes the overlay. The spec's R1 ("bounce MUST appear no later than the haptic feedback") would be satisfied by "same synchronous turn" only; strictly the haptic call is issued first today.

The model never reads `runningApps()` in `fire`. It has no notion of whether the target is running.

### C. Real `bringToFront` (`WorkspaceActions.swift:14-20`)
```swift
/// One call reproduces a Dock click: launches, unhides, restores, reopens and activates.
/// The completion is ignored: its only reactions would be a log line or a dialog.
public func bringToFront(_ app: AppEntry) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
}
```
- Same call for running and non-running apps (no branching).
- No completion handler is passed (the ObjC nullable completion imports with a default nil); not the async/throwing overload (no `try await`). So the resulting `NSRunningApplication?` and any `Error` are discarded. Failure to launch is invisible to the model today.
- No other launch-lifecycle observation in `LauncherPlatform`.

### D. Real `playLaunchAnimation` (`WorkspaceActions.swift:37-39` -> `LaunchOverlay.play(for:)`, `LaunchOverlay.swift:34-69`)
- Pointer: `NSEvent.mouseLocation` read inside the overlay at call time (line 35). The model never has the pointer; no port carries it. (Elsewhere, `SwitcherPresenter.swift:130` and `WindowSwitcherPresenter.swift:60` also read `NSEvent.mouseLocation` in `LauncherUI`, only to pick a screen.)
- Displays: `NSScreen.screens` -> `[LaunchDisplay(frame:scale:)]` (line 36).
- Reduce motion: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || LaunchTuning.current.forceReduceMotion` (lines 37-38), read at call time inside the adapter; passed to `flights.next(draw:reduceMotion:)` which returns `.fadeInPlace` motion under Reduce motion (`LaunchFlight.swift:37-38`). The model never sees Reduce motion.
- Launch-animation setting: reaches the decision only as the model-side `if settings.isLaunchAnimationOn` in `fire` (setter `setLaunchAnimation(on:)`, `Launcher.swift:142-146`, saves at once, applies to the next gesture). The adapter knows nothing of the setting.
- Plays CA keyframes in a fresh `NSPanel` (`.screenSaver` level, `ignoresMouseEvents`, `.nonactivatingPanel`); panel closed in `CATransaction` completion block. Fire-and-forget: nothing returns to the model.
- Icons are pre-rendered by `prepareLaunchAnimations(for:)` (called from `Launcher.resolveRows()`, `Launcher.swift:330-338`, for every present assigned app, deduped by url) -> `LaunchOverlay.prepare(for:)` renders off main (`@concurrent renderOffMain`), cached in `icons: [URL: CGImage]` keyed by the catalog url.

### E. Composition root (`TrackpadLauncher/TrackpadLauncherApp.swift:8-26`)
```swift
let catalog = AppCatalog.system
let system = WorkspaceActions()
let launcher = Launcher(
    hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
    system: system, catalog: catalog, scanner: SystemAppScanner(catalog: catalog), store: SettingsStore(defaults: .standard))
let shell = MenuBarShell(launcher: launcher)
launcher.start()
#if DEBUG
system.showAnimationTuner()
#endif
withExtendedLifetime(shell) { application.run() }
```
`system` is kept as the concrete `WorkspaceActions` so the DEBUG tuner (`showAnimationTuner()`, `WorkspaceActions.swift:41-55`, previews Finder's icon via `overlay.play`) can be reached outside the port.

## How the model knows whether an app is running today

- Only through `SystemActions.runningApps() -> RunningApps` (`Ports.swift:69-70`), "read now, from their one source of truth". Used by `swipe(.began)`, `swipe(.ended)` (`running.contains(target.url)` at `Launcher.swift:268-270`: "An app that quit meanwhile is never relaunched"), and `swap` (`SwapSeries.next(in:)`). NOT used by `fire`.
- Real read: `RunningAppsReader.read()` (`RunningAppsReader.swift:19-21`) = `frontmost` from `NSWorkspace.shared.frontmostApplication` (excluding own pid) + `apps` from `LaunchServicesOrder.apps()` (only `ApplicationType == "Foreground"`, i.e. Dock apps) or, if the private symbols are missing, `NSWorkspace.shared.runningApplications` filtered to `activationPolicy == .regular`.
- Consequence for R1 ("not running means macOS reports no process for the app"): `RunningApps` deliberately excludes menu bar (UIElement/accessory) apps ("never a menu bar app", `docs/domain-model.md:33`) unless one is frontmost. A running menu bar app would read as "not running" through this port. It is the ⌘-Tab list, not a process list. Unknown (not verified here) whether an app that is mid-launch from the Dock already appears in LaunchServices' front-to-back array.
- `RunningApps.contains(_:)` compares by URL. The catalog's `locate` URL comes from `FileManager.contentsOfDirectory`/`lastKnownURL`/`registeredCopies` paths; running-app URLs are spelled `URL(fileURLWithPath: path, isDirectory: true)` (`Apps.swift:27-29`). Precedent for identity matching between assigned and running apps is by bundle ID: `Switcher.init` filters `!leavingOut.contains($0.bundleID)` (`Switcher.swift:21`) with `settings.assignedBundleIDs`. URL equality between a catalog-located `AppEntry` and a running one is not guaranteed (trailing slash / firmlink / symlink spellings) - unverified, flagged.
- Other lifecycle observation that exists in the codebase (outside the model, in `LauncherUI`): `SwitcherPresenter.startIconPasses` (`LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift:43-66`) observes `NSWorkspace.didLaunchApplicationNotification` and `didTerminateApplicationNotification` on `.main`, only while the swipe setting is on, only to draw/evict switcher icons (`launched`/`terminated`, lines 78-88). `ActivationTracker` observes `didActivateApplicationNotification` (fallback ordering only). `AppIcons.icon(forSwitcher:)` calls `NSRunningApplication.runningApplications(withBundleIdentifier:)` (`AppIcons.swift:53`). None of these reach the model.
- Windows: `SystemActions.frontmostWindows()` reads only the FRONTMOST app's windows via AX + `CGWindowList` (`FrontmostAppWindows.swift`, confined there by the source-scan test: `AXUIElement` and `CGWindowList` tokens may appear only in that file, `SourcePolicyTests.swift:74-106`). It is a synchronous read, not a push; nothing observes window creation (`kAXWindowCreated`/`AXObserver` appear nowhere).
- There is no port, today, that pushes app launched / finished launching / terminated / first window shown / open failed to the model. `SystemActions` has no `on…` callback at all; every other push port (`TrackpadHardware.onEvent`, `TrackpadPreferences.onChange`, `Permissions.onChange`, `AppScanner.onScan`) has the `var on…: (@MainActor (...) -> Void)? { get set }` shape, set in `Launcher.start()`.

## Time in the model

- The model has no clock, no deadline, no `Date`, no `Duration`, no scheduler, no injected clock. `grep` over `Sources` for `Clock|Duration|asyncAfter|Task.sleep|Timer|DisplayLink|DispatchTime|Date()` finds in `LauncherCore` only `GestureRules` durations and `FrameTime` (`Touch.swift:33-44`, "Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads.").
- All timing in recognition is derived from frame timestamps: `maxTapDuration = 400 ms`, `clickBlockingWindow = 3 s` (`GestureRules.swift:19,23`); these live in the recognizer on the frame thread, not in the model. `GestureEvent` carries no time.
- Architecture: "No timers, no polling, no background loops: every input is a push" (`docs/architecture.md:20`); "No code of ours runs per frame, and display links are banned along with timers" (`docs/architecture.md:21`). Enforced by `SourcePolicyTests.banned` (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:13-62`), plain substring scan over `Sources/` and `TrackpadLauncher/`: `"Timer"` (case-sensitive substring - any identifier containing `Timer` fails), `"asyncAfter"`, `"Task.sleep"`, `"makeTimerSource"`, `"displayLink"`, `"DisplayLink"`. `clock.sleep(for:)` or `ContinuousClock` are not literally banned but violate the stated rule. The doc line 21 says completion callbacks clean up animations; a 2 s / 10 s deadline has no existing mechanism. (CA animation durations/completion blocks are the only "time" the code runs on.)
- `LauncherCore` may import only `Foundation` and `Observation` (`SourcePolicyTests.swift:156-161`).

## How the model's tests are written

- Swift Testing, `@MainActor @Suite struct ...Tests`, `@Test func longDescriptiveName()`. Run via `Scripts/test.sh` (`swift test`).
- Fire-path tests: `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift` (lines 10-114: `twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow`, `withTheLaunchAnimationOffAGesturePulsesBringsToFrontAndClosesTheWindowWithoutAnIcon`, `theSwitchAppliesToTheNextGestureWithoutARestart`, `iconsAreStillPreparedWhileTheLaunchAnimationIsOff`, `repeatedTapsWhileTheThumbStaysAnchoredFireEachTime`, `unassignedGestureIsSilentAndLeavesTheWindowOpen`, `missingTargetIsSilent`, prepare tests 116-185); `FiveFingerTests.swift`; `ActivityTests.swift` (inactive -> silent); `AppResolutionTests.swift`; `PersistenceTests.swift` (`turningTheLaunchAnimationOffSurvivesARelaunchAndGesturesShowNoIcon`, line 169); negative "never the launch animation" checks in `SwitcherOnScreenTests.swift`, `SwapTests.swift`, `SwapSettingTests.swift`, `WindowSwitchingTests.swift`, `WindowSwitcherOnScreenTests.swift`, `TapGateTests.swift`.
- Setup: `let world = World(apps: ["Figma"]); world.launcher.start(); world.launcher.setAssignment(.app(world.app("Figma")), for: .two); world.tap(2)`. `World.tap` (`World.swift:167-169`) builds `TouchScript(...).thumb(atMM:).tap(fingers:)` frames and calls `hardware.touch(frames, on:)`.
- `InMemoryTrackpads.touch` (`InMemoryAdapters.swift:104-123`) steps the REAL `GestureRecognizer` synchronously and delivers each event through a real `WindowSwipeConfirmation.deliver(_, to: onEvent)` inline: no dispatch, no main-queue hop. That is how "async deliveries are kept synchronous" (architecture: "Concrete types ... are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous", `docs/architecture.md:14`). Same pattern: `InMemoryAppScanner.scan()` calls `onScan` inline (with `holdScans()`/`deliverHeldScan()` to model latency); `InMemoryPermissions.set(_:granted:push:)` calls `onChange` inline; `InMemoryTrackpadPreferences.set` calls `onChange` inline; `inject(_:)` delivers a raw `TrackpadEvent`.
- Recording: `RecordingSystemActions` (`InMemoryAdapters.swift:260-298`) appends to `broughtToFront: [AppEntry]`, `launchAnimations: [AppEntry]`, replaces `preparedLaunchAnimations`; `runningApps()` answers settable `frontmost`/`running` (World helpers `makeRunning`, `makeFrontmost`, `activate`). Hooks `onPlayLaunchAnimation` / `onRegisterLoginItem` run inside the call so a test can snapshot other effects at that moment - this is how ordering is asserted: the first LauncherTests test captures `system.broughtToFront` inside `onPlayLaunchAnimation` to prove bring-to-front precedes the animation. `InMemoryTrackpads.pulses: [Pulse]` (+ `feedback`, `lightTicks` views). There is no shared cross-adapter event log, so haptic-before-bringToFront ordering is not asserted anywhere.
- No clock/scheduler injection anywhere in tests; the only time is `TouchScript`'s synthetic `FrameTime` (frames 10 ms apart starting at 1.0 s; `.wait(_ d: Duration)` advances the script cursor). Tests never wait in real time.

## Boundaries

- In: `TrackpadEvent.gesture(GestureEvent)` via `TrackpadHardware.onEvent` (main actor, frame order). Settings via `Launcher.setLaunchAnimation(on:)` etc. from `LauncherUI`.
- Out: `TrackpadHardware.playFeedback`, `SystemActions.bringToFront`, `SystemActions.playLaunchAnimation`, observable `isWindowOpen` (and `rows`, `isLaunchAnimationOn`) read by `LauncherUI` through `Observations`.
- Framework types (`NSRunningApplication`, `NSImage`, `CGEvent`...) must not cross a port (`docs/architecture.md:13`); every port has exactly two adapters (real in `LauncherPlatform`, in-memory in tests) (`docs/architecture.md:14`). Ports and real adapters' public surface are `@MainActor` (`docs/architecture.md:17`).

## Non-Obvious Things

1. `fire` never asks whether the app is running; the same `openApplication` call serves launch and activate (the glossary's "Bring to front", `docs/domain-model.md:77-78`).
2. `bringToFront` drops the completion handler on purpose (comment: "its only reactions would be a log line or a dialog"); there is no failure path back. A launch failure (R11) is currently unobservable.
3. Pointer, displays and Reduce motion are adapter-side reads at the instant of `playLaunchAnimation`; the port's doc (`Ports.swift:65-68`) promises "Reads the pointer, the displays and Reduce motion at the moment of the call ... Every call plays its own animation and never cancels, restarts or reuses one already playing." A bounce that must be ended/converted later breaks the "fire-and-forget, never cancels" contract of this method - it needs a new method or port contract.
4. `runningApps()` is the ⌘-Tab list, not a process list: menu bar apps are absent (unless frontmost). A "not running" check via `runningApps().contains(...)` would misclassify a running menu bar app as not running (R10's menu bar scenario starts with the app not running, so OK there, but R2/R14 with a running menu bar app would wrongly bounce).
5. `catalog.locate` reads Info.plist from disk at every fire, on the main actor, before the haptic.
6. Ordering is tested only for bringToFront-before-animation (via the `onPlayLaunchAnimation` hook). Haptic-first is code order only.
7. `window = .closed` is the last statement; `MenuBarShell` hides on a later turn via the `Observations` async sequence.
8. `WorkspaceActions` is held concretely by the composition root only for the DEBUG tuner; the tuner previews by calling `overlay.play` directly, bypassing the port.
9. `LaunchOverlay` keys its icon cache by `AppEntry.url` from the catalog; `prepareLaunchAnimations` covers only present assigned apps, deduped by url, re-sent whenever rows are resolved (start, setAssignment, openWindow).
10. Source-scan bans the substring `Timer` case-sensitively: any new type named e.g. `LaunchTimer` would fail the build.
11. The model holds no per-app transient state across gestures today except `swapSeries` (`SwapSeries`) and `shown` switcher; nothing analogous for "launches in flight".

## Open Questions

- Whether LaunchServices' `_LSCopyApplicationArrayInFrontToBackOrder` lists an app that is still mid-launch (R1/R2 "launching from the Dock counts as running"). Not determinable from code.
- Whether URL equality between a catalog-located `AppEntry.url` and a running app's `AppEntry.location(ofBundleAtPath:)` holds for all apps (e.g. Safari under `/System/Cryptexes/...` vs `/Applications/Safari.app`, trailing-slash spellings). Not verified; bundle-ID matching is the existing precedent for assigned-vs-running identity.
- How a 2 s grace / 10 s cap could be expressed without timers: the codebase has no precedent; the only "time" sources are frame timestamps (recognizer, frame thread) and Core Animation durations with completion blocks. Whether a CA completion block as a deadline is considered acceptable is a design question, not answered by code.
- I did not trace `LaunchFlight` staging internals beyond the `reduceMotion` branch (other explorers' slice).
