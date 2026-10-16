# Grounding: the model, its ports and the in-memory test adapters (LauncherCore)

Angle: `Launcher` (the `@MainActor @Observable` model), the value types and pure policy around the swipe, the ports, persistence, and how the model is tested. Paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/012-window-switcher-gesture/`. `LK/` = `LauncherKit/`.

---

## Components Found

| Name | File | What it is |
|---|---|---|
| `Launcher` | `LK/Sources/LauncherCore/Launcher.swift:8-267` | The one `@MainActor @Observable` model; owns every decision, turns `TrackpadEvent`s into effects through ports. |
| `Switcher` | `LK/Sources/LauncherCore/Switcher.swift:6-71` | Value type: the app row fixed at swipe begin, plus travel → selection / highlight position / rubber-band stretch. |
| `SwitcherRowLayout` | `LK/Sources/LauncherCore/SwitcherRowLayout.swift:6-38` | Pure geometry for a horizontal row of icons on a display of a given width (80 pt icons, 20 pt gaps, one shrink factor). Used only by the presenter. |
| `SwapSeries` | `LK/Sources/LauncherCore/SwapSeries.swift:4-25` | Internal struct: picks a swap's target and remembers the last swap (from/to) to handle in-flight activation. |
| `GestureActivity`, `ConflictingSetting(s)`, `InactiveCause` | `LK/Sources/LauncherCore/Activity.swift` | Pure derivation of active/inactive from connected trackpad kinds + raw preference values. |
| `Settings`, `SettingsStore` | `LK/Sources/LauncherCore/Settings.swift` | The persisted record (Codable, tolerant decoding) and its one-key `UserDefaults` store. |
| `Copy` | `LK/Sources/LauncherCore/Copy.swift` | Verbatim window strings (gesture hint, Accessibility hint, inactive notice) kept in core so they are tested as values. |
| `HandMode` | `LK/Sources/LauncherCore/HandMode.swift` | `.right`/`.left`, corner name for copy, hand-side-edge fractions. |
| `AppEntry`, `RunningApps`, `BundleID`, `AssignedApp`, `AppCatalog`, `InstalledApps`, `RowApp`, `GestureRow` | `LK/Sources/LauncherCore/Apps.swift` | App domain types; `RunningApps` is what `SystemActions.runningApps()` returns. |
| `Gesture`, `GestureEvent`, `SwipePhase`, `SwipeEvent`, `SwapEvent` | `LK/Sources/LauncherCore/Gesture.swift` | Event payload types crossing the hardware port. |
| `GestureRules` | `LK/Sources/LauncherCore/GestureRules.swift` | `package enum` of every fixed number (corner size, 3 mm drag, 400 ms tap, 3 s window, `switcherMaxApps = 10`, `switcherStepMM = 12`, `switcherMaxStretch = 0.2`, `switcherMaxOvershoot = 0.25`). |
| `SwipeTravel`, `PointerCurve` | `LK/Sources/LauncherCore/PointerCurve.swift` | How finger movement becomes switcher travel ("step millimetres", 12 per icon); `.cursor` reproduces macOS pointer acceleration. |
| `TrackpadEvent`, `Haptic`, ports `TrackpadHardware`, `TrackpadPreferences`, `SystemActions`, `AccessibilityPermission`, `AppScanner` | `LK/Sources/LauncherCore/Ports.swift` | Every port protocol plus the event enum the hardware port carries. |
| `GestureRecognizer`, `Recognition` | `LK/Sources/LauncherCore/GestureRecognizer.swift` | Pure per-trackpad state machine (frames in, `Recognition` out). Not my angle, but the model's input. |
| `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `InMemoryAccessibilityPermission`, `InMemoryAppScanner` | `LK/Tests/LauncherCoreTests/InMemoryAdapters.swift` | The test adapters, one per port. |
| `World` | `LK/Tests/LauncherCoreTests/World.swift:36-242` | Test fixture: real `Launcher` over in-memory adapters, a temp dir of fake bundles and a throwaway `UserDefaults` suite. |
| `TouchScript`, `HandFrames`, `Fixtures` | `LK/Tests/LauncherCoreTests/TouchScript.swift`, `Fixtures.swift` | Frame-building DSL (mm, 10 ms frames) and hand-built frames; old settings records. |
| `SourcePolicyTests` | `LK/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Source scan: banned APIs, permission APIs confined to one file, core imports only Foundation/Observation. |

---

## Launcher: stored state (Launcher.swift)

Observable (public read, private write unless noted):
- `rows: [GestureRow]` (l.10) — derived from settings + catalog by `makeRows()` (l.259-266), refreshed by `resolveRows()`.
- `switcher: Switcher?` (l.12) — "Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`." This is the only swipe state the UI sees.
- `installedApps: InstalledApps` (l.14) — replaced by scans.
- `isAccessibilityGranted: Bool` (l.28) — drives the Accessibility hint; "Deliberately not part of `activity`, so the icon never reads it." Written only in `reconcile()` (l.178).
- Private observable: `window: Window` (`.closed/.open/.heldOpen`, l.33-35), `settings: Settings` (l.36), `connected: [Trackpad]` (l.37), `preferenceValues` (l.38).
- Computed public: `isWindowOpen` (l.15), `handMode`, `isLaunchAnimationOn`, `isSwipeOn`, `isSwapOn` (l.16-19, all read through `settings`), `gestureHint` (l.21, `Copy.gestureHint(for:swipe:)`), `activity` (l.23-25, `GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)` — derived, never stored).
- `@ObservationIgnored`: `isFirstLaunch` (l.39), the five ports + `catalog` + `store` (l.40-46), `lastRun: Run?` (l.166), `swapSeries = SwapSeries()` (l.167).

`Run` (l.158-164): `Equatable` struct of `trackpads`, `handMode`, `blockClicks`, `swipes`, `swaps` — "what the trackpads were last run with".

## Launcher: methods (who calls them)

Called by the composition root / shell:
- `init(hardware:preferences:access:system:catalog:scanner:store:)` (l.48-64): reads `catalog.installedApps()` synchronously, `store.load()`; `isFirstLaunch = stored == nil`; `settings = stored ?? Settings()`; `rows = makeRows()`. Composition root: `TrackpadLauncher/TrackpadLauncherApp.swift:12-19` passes `MultitouchTrackpads()`, `SystemTrackpadPreferences()`, `SystemAccessibilityPermission()`, `WorkspaceActions()`, `AppCatalog.system`, `SystemAppScanner(catalog:)`, `SettingsStore(defaults: .standard)`; then `MenuBarShell(launcher:)` is created before `launcher.start()` (l.20-21).
- `start()` (l.67-91): installs `hardware.onEvent` switch (l.68-75: `.gesture → fire`, `.swipe → swipe`, `.swap → swap`, `.trackpadsChanged → reconcile(restart: true)`), `scanner.onScan`, `scanner.scan()`, `preferences.onChange → reconcile()`, `access.onChange → reconcile()`, then `reconcile()`. On first launch: `system.registerLoginItem()`, `access.prompt()` if not granted, `store.save(settings)` (after both effects, so a crash repeats them), window `.heldOpen` if prompting else `.open`. Then `resolveRows()`.
- UI intents: `setAssignment(_:for:)` (l.94-103, saves, `resolveRows()`), `setHandMode(_:)` (l.113-118, saves, `reconcile()`), `setLaunchAnimation(on:)` (l.121-125, saves, no reconcile), `setSwipe(on:)` (l.128-133, saves, `reconcile()`), `setSwap(on:)` (l.136-141, saves, `reconcile()`), `openWindow()` (l.144-148: opens, `resolveRows()`, `scanner.scan()`), `closeWindow()` (l.151), `dismissWindow()` (l.154, no-op while `.heldOpen`).

Private (driven by port callbacks):
- `reconcile(restart:)` (l.172-189): re-reads `hardware.connected()`, `preferences.current()`, `access.isGranted()`; a grant while `.heldOpen` closes the window (l.177); computes `active = activity.isActive`; builds `Run(trackpads: active ? connected : [], handMode:, blockClicks: active && granted, swipes: settings.isSwipeOn, swaps: settings.isSwapOn)`; returns early if `!restart && run == lastRun` (l.184) — so preference/trust notifications that change nothing leave a swipe alone; otherwise `switcher = nil` (l.187, "Running replaces every recognizer, which ends any swipe in progress") and `hardware.run(...)` (l.188).
- `fire(_:)` (l.192-202): the tap gestures. Guards active + assigned + `catalog.locate`; `playFeedback(.gesture)`, `bringToFront`, launch animation if on, `window = .closed`.
- `swipe(_:)` (l.205-235): see Flow.
- `swap(_:)` (l.238-245): see Flow.
- `resolveRows()` (l.249-257), `makeRows()` (l.259-266).

---

## Flow

### Swipe, end to end (real app)
1. Frame thread: `DeviceSession.receive` (`LK/Sources/LauncherPlatform/FrameStream.swift:33-46`) steps the recognizer; on `.began` it swaps the recognizer's `travel` to `CursorTravel.travel(curves:)` (l.38; travel is 0 on the begin frame so the next frame is first to use it). Events are delivered via a closure that hops `DispatchQueue.main.async` and drops events from replaced sessions by `runs == generation` (`MultitouchTrackpads.swift` `run`, the `deliver:` closure).
2. `TrackpadEvent.init(_:on:)` (`Ports.swift:11-17`) maps `Recognition.Event.swipe(phase)` → `.swipe(SwipeEvent(phase:trackpad:))`. "The one mapping … Both hardware adapters use it."
3. `Launcher.start`'s `onEvent` closure → `swipe(event)` (Launcher.swift:71).
4. `Launcher.swipe(_:)` (l.205-235):
   - `.began` (l.207-213): `guard switcher == nil, activity.isActive else { return }` — a second trackpad's begin while one switcher is up is ignored; an inactive state ignores even an injected begin. Reads `system.runningApps()` once (frontmost + ⌘-Tab apps). Reads `settings.assignedBundleIDs` (Settings.swift:19, derived from all five assignments, missing ones included). Builds `Switcher(frontmost: running.frontmost, running: running.apps, leavingOut: settings.assignedBundleIDs, trackpad: event.trackpad)`. The init is failable: `nil` when no app besides the frontmost would show, so `switcher` stays nil and nothing shows ("With nothing to show the swipe still runs its course: the fingers stay blocked until they lift" — blocking is the recognizer's job, not the model's).
   - `.moved(let travel)` (l.214-219): `guard var open = switcher, open.trackpad == event.trackpad`; `before = open.selected`; `open.follow(travel)`; `switcher = open` (one observable write per frame); then `for _ in 0..<abs(open.selected - before) { hardware.playFeedback(.lightTick, on: event.trackpad) }` — one light tick per icon crossed, several in one frame if the frame jumps.
   - `.ended` (l.220-231): `guard let open = switcher, open.trackpad == event.trackpad`; `switcher = nil` first; `guard !open.selectsFrontmost` (silent, window untouched); re-reads `system.runningApps()` (l.226) and `guard running.contains(target.url)` (an app that quit is never relaunched, silent); then `hardware.playFeedback(.gesture, on:)`, `system.bringToFront(open.selectedApp)`, `window = .closed`. Never the launch animation. Note `.ended` does not re-check `activity`.
   - `.cancelled` (l.232-233): `if switcher?.trackpad == event.trackpad { switcher = nil }` — no haptic, no effect.
5. The shell renders: `SwitcherPresenter` (`LK/Sources/LauncherUI/SwitcherPresenter.swift:28-31`) observes `launcher.switcher` with `Observations` and calls `render(_:)` (l.117-131): nil → fade out; new or changed row → `open(row)` (lays out with `SwitcherRowLayout` on the screen under `NSEvent.mouseLocation`); then `panel.show(position:selected:name:animatesSize:)` and a spring when `stretch` changes. The presenter "holds nothing the model holds".

### Switcher policy (Switcher.swift)
- Row fixed at begin (init, l.22-28): `others = running.filter { $0.url != frontmost?.url && !leavingOut.contains($0.bundleID) }`; nil if `others` empty; `row = prefix(switcherMaxApps)` of `[frontmost] + others`; `startsOnFrontmost = frontmost != nil`. Identity of the frontmost copy is the URL (two copies = two icons); leaving out is by bundle ID; frontmost is never left out. `row` is `let` — later reads of running apps never change it (launch mid-swipe not added; quit stays).
- `travelMM` (`package(set)`, l.14) is in step-mm; `reportedMM` (l.16) is the last absolute travel given to `follow`.
- `selected` (l.32-35): `round(travelMM / 12, .toNearestOrAwayFromZero)` clamped to `0...row.count-1` — nearest icon, so it changes at ±6 mm then every 12 mm.
- `follow(_ reportedMM:)` (l.43-53): `moved = reported - lastReported`; `next = travelMM + moved`; if past the left end (`travelMM < 0`) and moving right, `next = moved` (overshoot forgotten); if past the right end (`travelMM > last`) and moving left, `next = last + moved`; then clamp to `[-band, last + band]` where `band = 0.25 × 12 = 3 mm`. This is "hard stops, small rubber band, no dead zone; travel past the end is forgotten on the turn".
- `selectsFrontmost` (l.56): `startsOnFrontmost && selected == 0` — the silent-lift condition.
- `position` (l.60): `travelMM/12` clamped (highlight between icons proportionally). `stretch` (l.64-68): signed `max × (1 − 1/(1 + |excess|/max))` with `max = 0.2`, 0 inside the row.

### Travel units (PointerCurve.swift:132-150, GestureRules.swift:27)
- `SwipeTravel.linear`: travel = `dxMM` (tests use this). `.cursor(curve, pointsPerIcon:)`: `curve.cursorPoints(dxMM:dyMM:interval:) / pointsPerIcon × 12`; `shippedPointsPerIcon = 100` (l.140). So the model only ever sees step-mm where 12 = one icon = 100 cursor points.
- `PointerCurve.cursorPoints` (PointerCurve.swift ~l.92-99) uses `hypot(dx, dy)` for velocity but returns only the x component: `dx * multiplier(velocity) / velocity`.
- `CursorTravel.travel(curves:)` (`LK/Sources/LauncherPlatform/CursorTravel.swift:37-43`) reads `LaunchTuning.current` (`swipeFollowsCursor`, `swipePointsPerIcon`, `swipeTrackingSpeed`, `LaunchTuning.swift:39-44`) and the tracking speed `com.apple.trackpad.scaling` fresh at each swipe start (l.14-17; "a read on a user event, not a poll").
- Recognizer: `Swipe.travelMM` starts at 0 at `.began` (`GestureRecognizer.swift:248-253`, `beginOrSpoil`), and each frame adds `travel.travel(dxMM:dyMM:interval:)` of the fingers' mean movement (l.151-166). `.moved` is sent only when travel changed. `.ended` when `swipe.fingers.isEmpty` (both lifted, l.~143); `.cancelled` on `frame.press == .click` or a third joining finger (l.139-141).

### Swap (Launcher.swift:238-245, SwapSeries.swift)
- `if event.startsSeries { swapSeries = SwapSeries() }` happens before the `activity.isActive` guard (so memory is replaced even while inactive).
- `swapSeries.next(in: system.runningApps())`: if the last swap is in flight (`running.frontmost?.url == last.from && running.contains(last.to.url)`), `last.to` stands in for frontmost; target = first of `running.apps` whose URL ≠ frontmost (assigned apps are NOT left out). Records `last`. nil → silent.
- Effect: `playFeedback(.gesture)`, `bringToFront(target)`, `window = .closed`. Never the launch animation, never touches `switcher`.

### Hints in the launcher window
- Gesture hint: `Launcher.gestureHint` (l.21) → `Copy.gestureHint(for:swipe:)` (Copy.swift:6-10): appends ", or swipe left or right with 2 fingers to switch apps" only while the swipe is on. `●`/`◉` are drawn as images by `HintText` (`LauncherView.swift:139-158`).
- Trackpad settings notice: `LauncherView.swift:22-29` switches on `launcher.activity`; `.inactive(cause)` → `SettingsNotice(message: Copy.inactiveNotice(for: cause), button: "Trackpad settings…", open: actions.openSettings(.trackpad))`.
- Accessibility hint: `LauncherView.swift:30-34`, shown when `!launcher.isAccessibilityGranted`, `Copy.accessibilityHint` (Copy.swift:12-13), button "Grant access…" → `actions.openSettings(.accessibility)`.
- `SettingsPane` (`LK/Sources/LauncherUI/LauncherActions.swift:5-16`): `.trackpad` and `.accessibility` URLs (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`). `openSettings` (`MenuBarShell.swift:147-150`) closes the window then `NSWorkspace.shared.open(pane.url)`.
- `MenuBarShell` re-fits the panel when `(launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn)` changes (`MenuBarShell.swift:48-53`) — the tuple of everything that changes the window's height.

### Settings toggles
- `SwitcherSection` (`LK/Sources/LauncherUI/SwitcherSection.swift:6-41`): two rows, each `Toggle` bound `get: { launcher.isSwipeOn } set: { launcher.setSwipe(on:) }` and likewise `isSwapOn`/`setSwap(on:)`. Toggles do NOT go through `LauncherActions` — `LauncherActions` (`LauncherActions.swift:19-30`) holds only AppKit-only suppliers: `cachedIcon`, `icon`, `chooseOtherApp`, `openSettings`, `quit`.
- `LaunchAnimationSwitch`, `HandModeToggle` in `LauncherView.swift:106-137` use the same Binding-to-intent shape.

---

## Ports (Ports.swift) — all `@MainActor`, all `AnyObject`

| Port | Methods (sync unless noted) | Domain types crossing | Real adapter | Test adapter |
|---|---|---|---|---|
| `TrackpadHardware` (l.24-38) | `var onEvent: (@MainActor (TrackpadEvent) -> Void)?` (push, main actor, frame order, never from a replaced session); `connected() -> [Trackpad]`; `run(_ trackpads:, handMode:, blockClicks:, swipes:, swaps:)` (idempotent; replaces every recognizer, ends a swipe in progress; installs click tap iff `blockClicks` and trackpads non-empty); `playFeedback(_ Haptic, on: TrackpadID)` | `TrackpadEvent` (`.gesture/.swipe/.swap/.trackpadsChanged`), `Trackpad`, `HandMode`, `Haptic` (`.gesture`, `.lightTick`, l.21) | `MultitouchTrackpads` — `LK/Sources/LauncherPlatform/MultitouchTrackpads.swift:10` (with `FrameStream.swift`, `ClickTap.swift`, `CursorTravel.swift`) | `InMemoryTrackpads` (InMemoryAdapters.swift:5-119) |
| `TrackpadPreferences` (l.41-46) | `var onChange` (push); `current() -> [TrackpadKind: TrackpadPreferenceValues]` | `TrackpadKind`, `[ConflictingSetting: Int]` | `SystemTrackpadPreferences` — `LK/Sources/LauncherPlatform/SystemTrackpadPreferences.swift:6` (cfprefs KVO on the two system trackpad domains, l.19-23, 45-50) | `InMemoryTrackpadPreferences` (l.121-134) |
| `SystemActions` (l.49-63) | `bringToFront(AppEntry)`; `registerLoginItem()`; `prepareLaunchAnimations(for: [AppEntry])`; `playLaunchAnimation(for: AppEntry)` (returns at once); `runningApps() -> RunningApps` (read now, sync) | `AppEntry`, `RunningApps` | `WorkspaceActions` — `LK/Sources/LauncherPlatform/WorkspaceActions.swift:5` (`bringToFront` = `NSWorkspace.openApplication(at:configuration:)` with `activates = true`, l.15-19; `runningApps()` = `RunningAppsReader.read()`, `RunningAppsReader.swift:19-21`) | `RecordingSystemActions` (l.136-167) |
| `AccessibilityPermission` (l.66-73) | `var onChange` (push, "Carries no data; re-read with `isGranted()`"); `isGranted() -> Bool` (fresh, never prompts); `prompt()` (returns at once) | `Bool` | `SystemAccessibilityPermission` — `LK/Sources/LauncherPlatform/SystemAccessibilityPermission.swift:8` (`AXIsProcessTrusted`, Darwin notification `com.apple.tcc.access.changed`, l.10, 17-19; onChange only when value changed, l.35-40) | `InMemoryAccessibilityPermission` (l.169-191) |
| `AppScanner` (l.76-82) | `var onScan: (@MainActor (InstalledApps) -> Void)?` (async push); `scan()` (returns at once; coalesces) | `InstalledApps` | `SystemAppScanner` — `LK/Sources/LauncherPlatform/SystemAppScanner.swift:7` (FSEvents + off-main `Task`) | `InMemoryAppScanner` (l.194-229; synchronous delivery, `holdScans()`/`deliverHeldScan()` to model asynchrony) |

Not behind a port (architecture rule, `docs/architecture.md` "Shape", last bullet): `AppCatalog` (`Apps.swift:155-234`, "Local-substitutable: tests point it at a temp directory of fake bundles and inject what LaunchServices and Spotlight know" via closures `registeredCopies`, `lastOpened`, `displayName`) and `SettingsStore` (`Settings.swift:35-57`, "Local-substitutable: tests use a throwaway `UserDefaults` suite"). `AppScanner` is the example of "delivers asynchronously → behind a port so the model's tests stay synchronous".

Every port has exactly two adapters as stated: the five protocols above, five real classes in `LauncherPlatform`, five in `InMemoryAdapters.swift`.

---

## Persistence

- One record, binary plist, under key `"settings"` (`Settings.swift:38, 51-56`) in `UserDefaults.standard` (composition root `TrackpadLauncherApp.swift:19`).
- Fields (`Settings.swift:8-16`): `handMode = .right`, `assignments: [Gesture: AssignedApp] = [:]`, `isLaunchAnimationOn = true`, `isSwipeOn = true`, `isSwapOn = true`. Comments: "The key is this field's name, permanently."
- Decoding rule (l.5-6, 23-32): custom `init(from:)` using `decodeIfPresent(...) ?? default` for every field: a missing key = default (this is how an upgrade leaves a new switch on), unknown keys ignored, an undecodable value fails the whole record. `load()` (l.46-49): `nil` = nothing ever saved (= first launch); undecodable data loads as `Settings()`, not first launch.
- Saved at once: every setter in `Launcher` calls `store.save(settings)` synchronously (l.101, 116, 124, 131, 139). `UserDefaults.set` persists through cfprefsd, so a quit/force-quit keeps it.
- The model does NOT observe its own settings (no KVO on `"settings"`). The in-memory `settings` property is the truth; only the model's setters write it. cfprefs KVO exists only for the *system* trackpad domains (`SystemTrackpadPreferences`). The tracking-speed preference is read, not observed (`CursorTravel.swift:11-17`).
- How a setting takes effect: `setSwipe`/`setSwap` call `reconcile()`, which builds a new `Run` with the flag → `hardware.run(..., swipes:, swaps:)` → fresh `GestureRecognizer(handMode:surface:swipes:swaps:travel:)` per trackpad (`MultitouchTrackpads.swift` `run`, `InMemoryAdapters.swift:44-56`). The recognizer, not the model, decides "no swipe while off" (`GestureRecognizer.swift` `.tapping`: `let pair = swipes ? Pair(...) : nil`). `setLaunchAnimation` does not reconcile; it is read at `fire` time.
- Persistence tests (`LK/Tests/LauncherCoreTests/PersistenceTests.swift`): `firstLaunchShowsFreshDefaults…` (l.21-33, asserts `isSwipeOn`, `isSwapOn` true); `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch` (l.46-60); `settingsSavedInTheCurrentFormatStillLoad` with the frozen XML `savedSettings` (l.77-98, 250-311; "Never regenerate: this is the format released builds write. It predates the swap key, so it also proves an upgrade keeps the swap on"); `upgradingFromARecordWithoutTheLaunchAnimationSetting…` (l.121-135); `turningTheSwipeOffSurvivesARelaunchAndAnOlderRecordLoadsWithTheSwipeOn` using `Fixtures.recordSavedByPlan002` (l.182-198, `Fixtures.swift:98-111`); `aRecordHoldingOnlyTheSwapKeyLoadsWithTheSwapOffAndEveryOtherDefault` (l.212-228); `everySettingsFieldSurvivesTheStore` (l.230-243, sets every field non-default and round-trips). `World.seedSettingsRecord(_:)` (World.swift:106-108) plants raw data at key `"settings"`; `World.relaunch()` (l.176-183) builds a second `Launcher` on a fresh `UserDefaults` instance of the same suite.

---

## How the model is tested

### `World` (LK/Tests/LauncherCoreTests/World.swift)
- Creates `root = tmp/tl-world-<UUID>` with `Applications`, `SystemApplications`, `UserApplications`, `CoreServices`, `Downloads` (l.60-70) and a `UserDefaults` suite whose name is an absolute path under `root` (`suiteName = root/Preferences`, l.43-45, 67) so cfprefs keeps the plist in `root`; `deinit` removes `root` (l.101-103). Hooks reading the World must capture it `unowned` (doc l.34-35).
- Wires: `InMemoryTrackpads(attached:)` (default `[.macBook14]`), `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `InMemoryAccessibilityPermission(granted:)` (default false), `Registry` (stands in for LaunchServices `registeredCopies`), `LaunchRecord` (Spotlight `lastOpened`), a real `AppCatalog` over the temp roots + `CoreServices/Finder.app` extra, `InMemoryAppScanner(catalog:)`, `SettingsStore`, and the real `Launcher` (l.71-89). Installs fake `Finder` plus `apps` as `.app` dirs holding only `Info.plist` with `CFBundleIdentifier = com.test.<name>` (l.120-128). `displayName` is the file name (l.113).
- Note: `World.init` does NOT call `launcher.start()`; tests or `switcherWorld` do.
- Drivers: `tap(_:on:thumbAtMM:)` (l.161-163); `play(_ script:on:)` (l.167-172) delivers only frames newer than any already delivered on that trackpad, so one hand can be played in pieces with assertions/intents in between; `swap(taps:lift:on:)` (l.224-230); `swipe(_ slidesMM: Double..., lift:on:)` (l.235-241) = thumb at (10,10) mm, `land(fingers: 2)` at (62,45), each slide horizontal `(slide, 0)`, then lift. `makeFrontmost(_:)`, `makeRunning(_:)` (l.188-199) set what the next `runningApps()` returns; `activate(_:)` (l.215-219) models an activation landing. `switcherWorld(apps:running:frontmost:accessGranted:)` (l.203-212): default Safari, Mail, Slack, Notes all running, Safari frontmost, started.

### In-memory adapters (InMemoryAdapters.swift)
- `InMemoryTrackpads` runs the **real** `GestureRecognizer` (with `travel: .linear`) and the **real** `ClickFilter` / `ScrollFilter` (l.44-56). `touch(_:on:)` (l.79-93) simulates the press edge between frames against the previous frame's blocking flags (merged across trackpads), re-samples the frame press through the filter's `holding`, steps the recognizer and calls `onEvent?(TrackpadEvent(event, on: id))` synchronously. Records `pulses: [Pulse(haptic, trackpad)]` with views `feedback` (gesture haptics) and `lightTicks` (l.11, 25-33), `pressVerdicts`, `runCount`, `running` (recognizers by id), `isBlockingClicks`. `scroll(_:)` (l.113-115) asks the fake tap for a scroll verdict. `attach`/`detach`/`sleep`/`wake` simulate hot-plug and sleep; `inject(_:)` (l.118) delivers an arbitrary `TrackpadEvent` regardless of `running` (models a late event).
- `RecordingSystemActions` (l.136-167): records `broughtToFront`, `launchAnimations`, `preparedLaunchAnimations`, `loginItemRegistrations`; `frontmost`/`running` vars answer `runningApps()`; hooks `onRegisterLoginItem`, `onPlayLaunchAnimation`.
- `InMemoryAccessibilityPermission` (l.169-191): `set(granted:)` pushes `onChange` only on a real change (mirrors the real adapter); counts `prompts`; `onPrompt` hook.
- `InMemoryAppScanner` (l.194-229): runs the real `catalog.installedApps()` synchronously; `holdScans()` defers.

### What "on screen" means in `SwitcherOnScreenTests`
There is no presenter, panel or AppKit in the loop: `LauncherUI` has no test target (`LK/Package.swift`: test targets are `LauncherCoreTests` and `LauncherPlatformTests` only). "On screen" means `world.launcher.switcher` is non-nil, its `row`, `selected`, `selectedApp`, `position`, `stretch`, `selectsFrontmost` — i.e. the model value the presenter would render. Effects are asserted on the fakes: `system.broughtToFront`, `hardware.pulses`/`lightTicks`/`feedback`, `system.launchAnimations`, `launcher.isWindowOpen`, `hardware.pressVerdicts`, `hardware.scroll(...)`, `hardware.runCount`.

### Representative end-to-end swipe test (SwitcherOnScreenTests.swift:189-210)
```swift
@Test func liftingOpensTheSelectionWithTheGestureHapticNoLaunchAnimationAndClosesTheWindow() {
    let world = World.switcherWorld()
    world.launcher.openWindow()
    let hand = world.swipe(3.5, 24, lift: false)
    #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])
    #expect(world.launcher.switcher?.selectedApp.name == "Slack")
    #expect(world.hardware.lightTicks.count == 2)
    #expect(world.launcher.switcher != nil)

    world.play(hand.lift())

    #expect(world.system.broughtToFront == [world.app("Slack")])
    #expect(
        world.hardware.pulses == [
            .init(haptic: .lightTick, trackpad: trackpad.id), .init(haptic: .lightTick, trackpad: trackpad.id),
            .init(haptic: .gesture, trackpad: trackpad.id),
        ])
    #expect(world.hardware.feedback == [trackpad.id])
    #expect(world.system.launchAnimations.isEmpty)
    #expect(world.launcher.switcher == nil)
    #expect(!world.launcher.isWindowOpen)
}
```
Path: `TouchScript` frames (10 ms apart, mm on a 124.8 × 76.8 mm surface) → `World.play` → `InMemoryTrackpads.touch` → real `GestureRecognizer.step` (linear travel) → `TrackpadEvent(.swipe(...))` → `Launcher.swipe` → `RecordingSystemActions` / pulses. `swipe(3.5, 24)`: the 3.5 mm slide crosses the 3 mm threshold at ~3.15 mm (`.began`, travel 0), leaving ~0.35 mm + 24 mm ≈ 24.35 travel → `selected` 2 (Slack).

### Other suites (what each pins)
- `SwitcherTests.swift` (pure `Switcher` value): row = frontmost + 9 most recent (l.26-30); band past left end kept to a quarter icon and forgiven on the turn (l.32-47: `follow(-30)` → `travelMM == -3`; `follow(-35)` from -40 → 5; `follow(-34)` → 6 → selected 1); same past the right end (l.57-69); selection = nearest, clamped (l.105-111 table); proportional position, stretch < 0.2 (l.123-142); nil when nothing but frontmost (l.98-103). Tests set `switcher.travelMM` directly via `package(set)`.
- `SwitcherOnScreenTests.swift`: drift tap shows switcher briefly then opens nothing (l.18-54); row & selection start (l.58-102); fresh read each swipe (l.104-114); ticks per icon including 3 in one frame (l.118-185); lift effects (l.189-210); both fingers must lift, last keeps steering (l.212-223); preference notification changing nothing leaves the swipe and `runCount` alone (l.225-236); thumb lift mid-swipe changes nothing (l.254-269); lift on frontmost leaves window open (l.271-281); third finger cancel (l.285-297); unblocked click cancels (l.299-313); blocked press ignored (l.315-337); nothing to show still blocks presses and does not restart trackpads (l.341-360); no frontmost app (l.364-392); inactive ignores injected `.began` (l.394-405); left hand (l.435-445); rubber band left end, 7 mm after the turn (l.447-465); quit mid-swipe not relaunched, silent (l.469-483); launch mid-swipe never joins (l.485-503); lift on start app after another came forward is silent (l.505-517); second trackpad ignored (l.521-548); reconcile mid-swipe (wake) removes switcher, remaining fingers do nothing (l.550-567).
- `SwitcherAssignedAppsTests.swift`: leaving out by bundle ID, all five gestures, missing/trashed still left out, frontmost kept, assignments counted from the next swipe, swap still reaches assigned apps.
- `SwapTests.swift`: swap effects (haptic, bring to front, window closes, no animation, l.15-35); left-hand corner (l.37-46); held/dragged thumb (l.48-56); firm press dropped (l.58-77); menu bar app / no frontmost (l.79-94); in-flight alternation (l.96-134, 259-270); nothing to swap silent (l.136-152); one/three fingers, edge contact (l.154-168); series rejoin / third finger stops (l.284-313); blocking for the whole series (l.315-335).
- `SwipeSettingTests.swift`: off → no switcher and hint changes at once (l.12-29); back on (l.31-41); off → slide scrolls only after the blocking window (l.43-64, asserts `pressVerdicts == [.drop, .drop, .pass, .pass]` and scroll verdicts); off keeps 2-finger tap (l.66-75).
- `SwapSettingTests.swift`: off → thumb is only anchored (l.14-26); swap off keeps swipe (l.28-38); applies without relaunch (l.40-50); swipe off keeps swap (l.52-60).
- `AccessibilityTests.swift`: hint follows grant live, never changes `activity` (l.5-18); first-launch prompt + held window (l.20-36); granted skips prompt (l.38-51); grant ends hold (l.53-61); fired gesture closes held window (l.63-73); prompt before first save (l.75-84).
- `LauncherTests.swift`: tap gestures (animation after bring to front, l.10-29), animation switch, prepare logic, hand mode, hot-plug, wake.
- `SourcePolicyTests.swift`: banned tokens (l.13-54: logging, network, file writes incl. `.write(to:`, `Timer`, `asyncAfter`, `Task.sleep`, display links, listen/post-event access APIs, keyboard tokens, `ScrollWheel`, event posting, `nonisolated(unsafe)`); confined tokens (l.64-76: `AXIsProcessTrusted` and `notify_register` only in `SystemAccessibilityPermission.swift`; `tapCreate`/`CGEventTapCreate`/`scrollWheel` only in `ClickTap.swift`; the two private LS functions only in `LaunchServicesOrder.swift`); core imports only Foundation/Observation (l.136-142).

---

## Boundaries

- In (to the model): `TrackpadEvent` via `TrackpadHardware.onEvent` (`.gesture`, `.swipe(SwipeEvent)`, `.swap(SwapEvent)`, `.trackpadsChanged`); `TrackpadPreferences.onChange`; `AccessibilityPermission.onChange`; `AppScanner.onScan`; UI intents (`setSwipe(on:)`, `setSwap(on:)`, `setAssignment`, `setHandMode`, `setLaunchAnimation`, `openWindow`, `closeWindow`, `dismissWindow`).
- Reads at swipe time: `system.runningApps()` at `.began` and again at `.ended`; `settings.assignedBundleIDs` at `.began`; `activity` at `.began`.
- Out: `hardware.run(...)`, `hardware.playFeedback(.lightTick|.gesture, on:)`, `system.bringToFront(AppEntry)`, `system.playLaunchAnimation` (gestures only), `system.prepareLaunchAnimations`, `access.prompt()`, `system.registerLoginItem()`, `store.save(settings)`; observable state `switcher`, `rows`, `activity`, `isAccessibilityGranted`, `isSwipeOn`, `isSwapOn`, `gestureHint`, `isWindowOpen` read by `MenuBarShell`, `LauncherView`, `SwitcherSection`, `SwitcherPresenter`.
- The recognizer (pure, `LauncherCore`) owns blocking (`Recognition.blocksClicks`, `blocksDockSwipes`) for the whole of `.swiping` regardless of whether the model built a switcher; the model never touches blocking except via `blockClicks:` in `run`.

## Where the window swipe's requirements touch the model (places only, no design)

- Event payload: `SwipePhase`/`SwipeEvent` (`Gesture.swift:25-46`) carry no direction; `Recognition.Event` (`GestureRecognizer.swift:5-11`) and the one mapping `TrackpadEvent.init(_:on:)` (`Ports.swift:11-17`) and the `onEvent` switch (`Launcher.swift:68-75`) are where a window-swipe event would enter. `SwipePhase.moved(travelMM:)` doc says "Sideways movement … positive to the right" (`Gesture.swift:28-30`).
- Travel: `SwipeTravel.travel(dxMM:dyMM:interval:)` (`PointerCurve.swift:142-150`) and `PointerCurve.cursorPoints` return the x component only; the recognizer adds it to `Swipe.travelMM` (`GestureRecognizer.swift:161`). Vertical travel has no path today.
- Start direction: `Move.isSideways` (`GestureRecognizer.swift:~333`) and `beginOrSpoil` (l.248-253: `guard let pair, move.isSideways else { return (.spoiled(anchor), nil) }`) — a vertical first drag spoils today.
- Settings: `Settings` (`Settings.swift:7-33`) would need a field with `decodeIfPresent ?? true` and the custom `init(from:)` line; `Launcher` a computed `is…On` + setter calling `store.save` and `reconcile()`; `Run` (`Launcher.swift:158-164`) a flag; `TrackpadHardware.run(...)` signature (`Ports.swift:35`) a parameter, which changes both `MultitouchTrackpads.run` and `InMemoryTrackpads.run`, and `GestureRecognizer.init(handMode:surface:swipes:swaps:travel:)` (`GestureRecognizer.swift:42`) plus test helpers `fired/phases/swaps/perFrame` (`Fixtures.swift:21-67`) that construct recognizers. Persistence tests to extend: `everySettingsFieldSurvivesTheStore`, `firstLaunchShowsFreshDefaults…`, the upgrade tests (the frozen `savedSettings` predates the new key, so it would prove "upgrade leaves it on" as it does for the swap). UI: a third row in `SwitcherSection.swift` below the swap row.
- Model state: today only `switcher: Switcher?` (l.12) and the comment "Written only by `swipe(_:)` and `reconcile()`"; `reconcile()` nils it on every re-run (l.187). A window switcher would be a separate observable value or a sum type here; `SwitcherPresenter` observes `launcher.switcher` only (`SwitcherPresenter.swift:30`).
- `Switcher` cannot represent R13: its init returns nil when there is only the frontmost item (`Switcher.swift:24`); the window switcher must always show (one row, no windows, no frontmost app, no Accessibility). `selectsFrontmost` (l.56) is the analogue of "lift on the front window is silent". The `follow`/`selected`/`position`/`stretch` math is generic over `row.count` and `GestureRules.switcherStepMM`; the element type is `[AppEntry]`.
- Live effects while sliding: today `.moved` only ticks (`Launcher.swift:214-219`); R10 needs an effect per selection change (raise a window), which no port offers. `SystemActions` (`Ports.swift:49-63`) has only app-level `bringToFront(AppEntry)` (real: `NSWorkspace.openApplication`, `WorkspaceActions.swift:15-19`) and `runningApps()`.
- Reading windows: nothing reads an app's windows today. `SystemActions.runningApps()` is the sync-read precedent (read at begin and at end, `Launcher.swift:210, 226`). A window list read, raise-a-window, restore-a-minimised-window, and final reordering at lift (R11) would need port methods; by the architecture rule they get a real adapter in `LauncherPlatform` and an in-memory one in `InMemoryAdapters.swift`, and `RecordingSystemActions`-style recording for assertions.
- Lift (R11/R12): today's `.ended` re-reads running apps and decides silence by "selected is frontmost" or "app quit" (`Launcher.swift:224-228`). R12's rule ("haptic iff the window in front after the lift differs from the front window at the start, or a minimised window was restored") and R11's closed-window case would need a post-lift read of the front window.
- Cancel (R15): today's `.cancelled` only nils the switcher (l.232-233); with live raising there is no "undo", which matches R15 ("keep the window in front as it is at that moment").
- Previews (R6/R17): asynchronous delivery ("Previews MAY fill in afterwards") — per the architecture rule, async-delivering things sit behind a port so the model's tests stay synchronous (precedent: `AppScanner.onScan` and `InMemoryAppScanner.holdScans()/deliverHeldScan()`). Whether previews are model state at all or a presenter concern is open; the switcher's app icons today are entirely presenter-side (`SwitcherPresenter`'s `AppIcons`), not in the model.
- Screen Recording permission (R7/R8): the precedent is `AccessibilityPermission` (`Ports.swift:66-73`: `onChange`, `isGranted()`, `prompt()`) with `isAccessibilityGranted` read in `reconcile()` (`Launcher.swift:175-178`) and the hint in `LauncherView.swift:30-34`. R8's "first press asks, later presses open System Settings" needs a remembered "asked" bit or an OS answer; there is no such state today. `SettingsPane` (`LauncherActions.swift:5-16`) has only `.trackpad` and `.accessibility`. The real Accessibility adapter's Darwin notification `com.apple.tcc.access.changed` "names no app and no service" (`SystemAccessibilityPermission.swift:5-7`), and `notify_register` is confined to that file by `SourcePolicyTests` (l.66). The window's re-fit tuple (`MenuBarShell.swift:50`) lists what changes its height; a new hint would belong there.
- R14 (no Accessibility): the model already has `isAccessibilityGranted` (l.28), refreshed in `reconcile()`.
- Policy/privacy: `docs/architecture.md` states the app asks for one permission (Accessibility) used only to block clicks/scrolls/Dock swipes, and "The Accessibility APIs … are each confined to one adapter file by the source-scan test". `SourcePolicyTests.confined` today confines only `AXIsProcessTrusted` among AX APIs. Window raising via AX and any screen-capture API would be new entries/rule changes there.
- Hint copy: `Copy.gestureHint(for:swipe:)` (`Copy.swift:6-10`) takes only the swipe flag.
- Haptics: `Haptic` (`Ports.swift:21`) already has `.gesture` and `.lightTick`; nothing new is needed by R12.
- Constants: `GestureRules` (`GestureRules.swift:24-32`) holds `switcherMaxApps = 10` and the step/stretch/overshoot numbers that R3 (cut at 10) and R9 (same rubber band) reuse. `SwitcherRowLayout` is horizontal-only (`displayWidth`); R5's vertical column has no geometry type.
- Tests: `World.swipe(_:)` slides only horizontally (`World.swift:235-241`); `TouchScript.slide(byMM:)` already accepts `(x, y)` (`TouchScript.swift:146`).

---

## Non-Obvious Things

1. **The 3 mm that start a swipe are NOT counted toward the selection today.** `beginOrSpoil` starts `Swipe.travelMM = 0` at the begin frame with the fingers' current positions (`GestureRecognizer.swift:248-253, 325`), and `SwipeTravelAndExitTests.travelIsTheMidpointsMovementSinceTheBegin…` (l.~31-40) pins `.began, .moved(2), .moved(4) …` — the first 4 mm finger move that begins the swipe contributes 0. `world.swipe(3.5, 12)` yields ≈12.35 travel. R9 of the plan says "measured from where the fingers landed, so the 3 mm that start the window swipe count towards the first row, as in the app switcher" — that does not match the app switcher's current code.
2. `Gesture.swift:31-32` documents `.ended` as "The first of the two fingers lifted", but the recognizer sends `.ended` only when both have lifted (`swipe.fingers.isEmpty`), and the domain model and tests (`theSwitcherStaysUntilBothFingersLift…`) agree with the code. Stale doc comment.
3. A nil `switcher` does not mean "no swipe": with nothing to show the recognizer is still `.swiping` and blocks presses/scrolls; the model just ignores `.moved/.ended` (guards on `switcher`). `aSwipeWithNothingToShowStaysBlocked…` (SwitcherOnScreenTests l.341-360).
4. `reconcile()` only nils the switcher when the `Run` changed (or on `restart`); a preference/trust notification that changes nothing leaves the swipe alone (`Launcher.swift:184`; test l.225-236). But toggling any setting that reconciles (`setSwipe`, `setSwap`, `setHandMode`) ends a swipe in progress.
5. Only `.began` checks `activity.isActive`; `.moved/.ended/.cancelled` rely on the switcher being nil after an inactive reconcile.
6. Tests always run `travel: .linear` (1 step-mm per finger mm); the cursor-acceleration path only exists in the real adapter (`FrameStream.swift:38`). Model tests therefore speak in "12 mm per icon".
7. `cursorPoints` returns only the x component of accelerated motion (velocity uses `hypot(dx, dy)`), so vertical finger motion slows nothing but contributes nothing.
8. `Switcher.travelMM` is `package(set)` so tests can set it directly; `Switcher.init?` is `package` — not public; the UI cannot build one.
9. `SwapSeries` is reset on `startsSeries` before the activity guard (`Launcher.swift:239-240`).
10. Swap does not leave out assigned apps; the switcher does. Swap never touches `switcher`.
11. The model never observes its own settings in `UserDefaults`; there is no cfprefs KVO on `"settings"`. KVO is only on the two system trackpad domains. The user's "cfprefs KVO?" guess applies to trackpad preferences, not to the app's settings.
12. `LauncherActions` is not where toggles go; toggles bind directly to `Launcher` setters in SwiftUI (`SwitcherSection.swift:18-23, 32-37`). `LauncherActions` is AppKit-only suppliers (icons, Other… chooser, opening System Settings, quit).
13. `World.init` does not start the launcher; `switcherWorld` does. `World.play` skips frames already delivered by time, so scripts are built cumulatively (`hand.lift()` replays only the tail).
14. `InMemoryTrackpads` uses the real recognizer, click filter and scroll filter; only the device, actuator and event tap are faked. So "model tests" are really recognizer + filter + model integration tests.
15. The first-launch `store.save` happens after `registerLoginItem()` and `prompt()` on purpose (crash-repeat); tests pin this order (`loginItemIsRegisteredBeforeTheFirstSave`, `promptComesBeforeTheFirstSave`).
16. `SourcePolicyTests` bans the token `.write(to:` and `Timer` anywhere in shipped sources, and `nonisolated(unsafe)`; any preview caching or delay logic must avoid these tokens.

## Open Questions

- I did not read `SwitcherPanel.swift`, `AppIcons.swift`, `ClickTap.swift`, `ClickFilter.swift`, `ScrollFilter.swift` or the rest of `GestureRecognizer.swift` in full (other explorers' angles); blocking semantics above are taken from `Recognition` docs and the tests.
- I did not verify whether `CGRequestScreenCaptureAccess` / ScreenCaptureKit TCC changes post `com.apple.tcc.access.changed`; the adapter comment only says the notification names no service.
- Whether the plan's R9 "3 mm count towards the first row, as in the app switcher" intends a change to the app switcher too, or is a mistaken description of it, is not something the code can answer.
