# How the platform side works: adapters, click blocking, permissions, source policy

Explorer angle: `LauncherPlatform` adapters, the click tap and its filters, the Accessibility permission, running apps and bring to front, cursor travel, the source-scan policy, build config, and how platform adapters are tested. All paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/012-window-switcher-gesture/` unless absolute. `LK/` = `LauncherKit/`.

---

## Components Found

| Component | File | What it does |
|---|---|---|
| `ClickTap` (final class, `Sendable`) | `LK/Sources/LauncherPlatform/ClickTap.swift:12-89` | The app's single active CGEvent session tap; owns a `ClickFilter`, a `ScrollFilter` and per-type `DockSwipeFilter`s behind `Mutex`es, runs on its own `"ClickTap"` thread. |
| `TapEvent` (enum) | `ClickTap.swift:103-134` | Parses a `CGEvent` into `.pointer(PointerEvent)`, `.scroll(ScrollEvent)` or `.dockSwipe(DockSwipePhase)`; also owns `tapTypes` / `tapMask`. |
| `DockSwipeFields` (enum) | `ClickTap.swift:137-148` | Undocumented event numbers: gesture type 29, Dock control type 30, field 110 = IOHIDEventType, 23 = kIOHIDEventTypeDockSwipe, field 132 = phase. |
| `PointerVerdict.apply`, `ScrollVerdict.apply`, `DockSwipeVerdict.apply` | `ClickTap.swift:213-251` | Turn a pure verdict into an event-tap return value (`nil` = drop, rewrite to `.mouseMoved`, or zero every scroll delta in place). |
| `ClickFilter` | `LK/Sources/LauncherCore/ClickFilter.swift:35-82` | Pure state machine: press/release/drag/pressure → pass/drop/passAsMove; exposes `holding` (`.nothing/.withheld/.passed`). |
| `PointerEvent`, `PressID`, `PointerVerdict` | `ClickFilter.swift:4-30` | Domain vocabulary of what the tap sees, free of CG types. |
| `ScrollFilter`, `ScrollEvent`, `ScrollVerdict` | `LK/Sources/LauncherCore/ScrollFilter.swift` | Pure scroll suppression: a scroll gesture is passed, dropped or "stilled" (deltas zeroed); momentum inherits. |
| `DockSwipeFilter`, `DockSwipePhase`, `DockSwipeVerdict` | `LK/Sources/LauncherCore/DockSwipeFilter.swift` | Pure system-swipe blocking, decided once on the opening phase and kept whole. |
| `DeviceSession` | `LK/Sources/LauncherPlatform/FrameStream.swift:8-56` | One running trackpad: its `GestureRecognizer`, pointer curves, the two blocking flags the tap reads, and the event delivery closure. |
| `sessions` (global `Mutex<[UInt: DeviceSession]>`) | `FrameStream.swift:61` | The only state shared between `run` (main), frame threads and the tap thread. |
| `contactFrameCallback`, `anyMouseButtonDown`, `anyTrackpadBlocksClicks`, `anyTrackpadBlocksDockSwipes` | `FrameStream.swift:63-85` | Frame-thread entry; button-state query; merged blocking flags read by the tap. |
| `MultitouchTrackpads` (`TrackpadHardware`) | `LK/Sources/LauncherPlatform/MultitouchTrackpads.swift` | Real hardware adapter: device discovery (IOKit), `run` (installs/removes the tap, starts sessions), haptics. |
| `Recognition` | `LK/Sources/LauncherCore/GestureRecognizer.swift:4-34` | Per-frame recognizer output: optional event plus `blocksClicks` and `blocksDockSwipes`. |
| `TouchFrame.Press` | `LK/Sources/LauncherCore/Touch.swift:61-83` | `.click` (reached apps) or `.blocked` (withheld), derived from the tap's `holding` and the button state. |
| `SystemAccessibilityPermission` (`AccessibilityPermission`) | `LK/Sources/LauncherPlatform/SystemAccessibilityPermission.swift` | AX trust read, the prompt, and the push from tccd's Darwin notification. |
| `AccessibilityPermission` port | `LK/Sources/LauncherCore/Ports.swift:65-73` | `onChange`, `isGranted()`, `prompt()`. |
| `SettingsPane`, `LauncherActions.openSettings` | `LK/Sources/LauncherUI/LauncherActions.swift:5-16, 27-28` | The System Settings URLs; opened by `NSWorkspace.shared.open` in `MenuBarShell.makeActions` (`MenuBarShell.swift`, `openSettings:` closure). |
| `WorkspaceActions` (`SystemActions`) | `LK/Sources/LauncherPlatform/WorkspaceActions.swift` | Bring to front via `NSWorkspace.openApplication`, running apps via `RunningAppsReader`, login item, launch overlay. |
| `RunningAppsReader` | `LK/Sources/LauncherPlatform/RunningAppsReader.swift` | Reads frontmost app (`NSWorkspace.frontmostApplication`) and the ⌘-Tab apps (LaunchServices order or fallback). |
| `RunningApp` | `LK/Sources/LauncherPlatform/RunningApp.swift` | The one place an `AppEntry` is built from an `NSRunningApplication` / LaunchServices dictionary. |
| `LaunchServicesOrder` | `LK/Sources/LauncherPlatform/LaunchServicesOrder.swift` | Two private LaunchServices functions resolved by `dlsym(RTLD_DEFAULT)`. |
| `FallbackOrder` | `LK/Sources/LauncherPlatform/FallbackOrder.swift` | Pure fallback ordering by recency then launch date. |
| `ActivationTracker` | `LK/Sources/LauncherPlatform/ActivationTracker.swift` | Observes `didActivateApplicationNotification` only on the fallback path. |
| `CursorTravel` | `LK/Sources/LauncherPlatform/CursorTravel.swift` | Reads `HIDAccelCurves` (IORegistry) and the tracking speed (`CFPreferencesCopyAppValue`) and builds a `SwipeTravel`. |
| `PointerCurve`, `SwipeTravel` | `LK/Sources/LauncherCore/PointerCurve.swift` | Pure reproduction of `IOHIDPointerAccelerator`; `SwipeTravel.travel(dxMM:dyMM:interval:)`. |
| `LaunchTuning` | `LK/Sources/LauncherPlatform/LaunchTuning.swift` | Shipped numbers incl. `swipeFollowsCursor`, `swipePointsPerIcon`, `swipeTrackingSpeed` (Debug tuner overrides). |
| `SystemTrackpadPreferences` (`TrackpadPreferences`) | `LK/Sources/LauncherPlatform/SystemTrackpadPreferences.swift` | KVO on two cfprefs domains for the conflicting settings only. |
| `Settings`, `SettingsStore` | `LK/Sources/LauncherCore/Settings.swift` | Codable settings record, one binary-plist blob under key `"settings"` in `UserDefaults`. |
| `SourcePolicyTests` | `LK/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Banned tokens, confined tokens, LauncherCore import allow-list. |
| In-memory adapters | `LK/Tests/LauncherCoreTests/InMemoryAdapters.swift` | `InMemoryTrackpads` (real recognizer + real `ClickFilter`/`ScrollFilter`), `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `InMemoryAccessibilityPermission`, `InMemoryAppScanner`. |

---

## Flow

### A. Arming and disarming the click tap (model → hardware)

1. `Launcher.reconcile(restart:)` (`LK/Sources/LauncherCore/Launcher.swift:172-189`) reads `hardware.connected()`, `preferences.current()`, `access.isGranted()` and computes a `Run` (`Launcher.swift:158-164`: `trackpads`, `handMode`, `blockClicks`, `swipes`, `swaps`). `blockClicks = active && granted` (line 182). If the `Run` equals `lastRun` and `restart` is false it returns (line 184), so a TCC/preferences broadcast that changes nothing leaves a swipe in progress alone. Otherwise it sets `switcher = nil` (line 187) and calls `hardware.run(...)` (line 188).
   - Triggers of `reconcile`: `start()` (line 80), `preferences.onChange` (78), `access.onChange` (79), `.trackpadsChanged` with `restart: true` (73), `setHandMode`/`setSwipe`/`setSwap` (117, 132, 140).
   - **The only state the model pushes to the tap is the `blockClicks: Bool` argument of `TrackpadHardware.run`** (port at `Ports.swift:35`). The model never talks to the tap per frame; the swipe/blocking state reaches the tap from the recognizer on the frame thread (B below).
2. `MultitouchTrackpads.run` (`MultitouchTrackpads.swift:66-113`): bumps `runs`; empties `sessions` (69); removes the old tap (`clickTap?.remove()`, 71-72); stops every device; then `if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }` (85); builds one `DeviceSession` per device with a fresh `GestureRecognizer(handMode:surface:swipes:swaps:travel: .linear)` (90), `pointerCurves: CursorTravel.curves(of: framework.getService(ref))` (91), and the same `clickTap` (92). `deliver` hops to `DispatchQueue.main.async` and drops events whose `generation != runs` (93-101).
3. `ClickTap.install()` (`ClickTap.swift:25-46`): `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: TapEvent.tapMask, callback: clickTapCallback, userInfo: passUnretained(tap))`. Returns `nil` when the system refuses (no Accessibility). Then starts a `Thread` named `"ClickTap"`, QoS `.userInteractive`, which adds the mach port's run-loop source in `.commonModes`, stores its `CFRunLoop`, and calls `CFRunLoopRun()`. The thread closure captures `tap` strongly ("That thread retains the ClickTap", lines 9-11).
4. `ClickTap.remove()` (`ClickTap.swift:52-61`, main, idempotent): `CGEvent.tapEnable(false)`, `CFMachPortInvalidate`, nil the port, `CFRunLoopStop` the tap thread's loop. Comment: "Never relies on macOS to stop delivery after a revoke." So a revoke → TCC notification → `reconcile` → `blockClicks` false → `run` → `remove()`.
5. Tap mask (`ClickTap.swift:115-120`): left/right/other down/up, the three drag types, type 34 (pressure), `.scrollWheel`, types 29 and 30. No keyboard and no plain mouse-move types. `TapEventTests.maskCoversPressesTheirReleasesDragsPressureScrollAndGesturesOnly` pins the bit set `[1,2,3,4,6,7,22,25,26,27,29,30,34]` (`LK/Tests/LauncherPlatformTests/TapEventTests.swift:8-11`).

### B. Per-frame blocking state (recognizer → tap), and "held open for the whole of a swipe"

1. `contactFrameCallback` (`FrameStream.swift:63-68`, MultitouchSupport's thread) looks up the session by device pointer, samples `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())`, parses the frame and calls `session.receive`.
2. `DeviceSession.receive` (`FrameStream.swift:33-46`): steps the recognizer under its Mutex; if `recognition.swipe == .began` it sets `$0.travel = CursorTravel.travel(curves: pointerCurves)` (38) — the travel is chosen per swipe, at its start. Then writes `blocking = recognition.blocksClicks` and `blockingDockSwipes = recognition.blocksDockSwipes` (41-42), and delivers any event.
3. `GestureRecognizer.step` computes the flags at `GestureRecognizer.swift:170-188`:
   - `state == .swiping` → `blocksClicks = true`, `blocksDockSwipes = true` (172-174). **This is the whole "blocking window held open for the whole of a swipe": there is no timer; the flag is simply true on every frame while the state is `.swiping`.**
   - swap series (`.rest(rest)` with `rest.isSeries`) → both true (175-177).
   - otherwise: `blocksDockSwipes` = a thumb anchored and any other contact down (180); `blocksClicks` = thumb's landing time known and `frame.time - landedAt < GestureRules.clickBlockingWindow` and another contact down (181-186).
   - A vertical slide today goes through `beginOrSpoil` (`GestureRecognizer.swift:243-249`): `guard let pair, move.isSideways else { return (.spoiled(anchor), nil) }`; `isSideways` is `abs(dxMM) > abs(dyMM)` (line 335). A spoiled state falls into the "otherwise" branch, so a vertical slide today only blocks clicks for the 3 s window.
4. Tap thread reads the merged flags at event time: `anyTrackpadBlocksClicks()` / `anyTrackpadBlocksDockSwipes()` (`FrameStream.swift:77-85`) copy the session values out of the `sessions` lock first, so no two locks are held at once.

### C. Tap callback

`clickTapCallback` → `ClickTap.handle(_:_:)` (`ClickTap.swift:64-88`, tap thread):
1. On `.tapDisabledByTimeout` / `.tapDisabledByUserInput`: `filter.forgetHeldPresses()`, `scrollFilter.forgetGesture()`, `dockSwipeFilters = [:]`, re-enable the port, pass the event (65-72).
2. Parse with `TapEvent(type, event)`; unparsed → pass (73).
3. `let blocking = anyTrackpadBlocksClicks()` read once before any filter lock (75).
4. `.pointer` → `ClickFilter.decide(_, trackpadBlocking:)` → `PointerVerdict.apply` (78). A press is dropped iff blocking at the press; its release follows the press's verdict regardless of the flag; drags of a withheld press become `.mouseMoved` (`passAsMove`); pressure events follow `holding` (`ClickFilter.swift:41-58`).
5. `.scroll` → `ScrollFilter.decide` → `ScrollVerdict.apply` (80). Rules (`ScrollFilter.swift:30-62`): wheel always passes; unphased drops iff blocking; finger phases: a gesture first seen while blocking on `mayBegin`/`began` is dropped, first seen mid-way while blocking is stilled; a passing gesture that meets blocking mid-way becomes stilled ("never relaxes inside a gesture"); momentum inherits the gesture's treatment; unknown coasting passes. `.passStill` zeroes `DeltaAxis1-3`, `FixedPtDeltaAxis1-3`, `PointDeltaAxis1-3` in place (`ClickTap.swift:233-249`). Nothing is ever posted.
6. `.dockSwipe` → reads its own flag `anyTrackpadBlocksDockSwipes()` (83) → per-event-type `DockSwipeFilter` keyed by `type.rawValue` (84-86), because a Dock swipe may arrive as both type 29 and 30. Judged once on `mayBegin`/`began`, kept until `ended`/`cancelled`; first seen mid-way passes (`DockSwipeFilter.swift:16-27`). Parsing: field 110 must equal 23; phase field 132: 128 mayBegin, 1 began, 4 ended, 8 cancelled, else changed (`ClickTap.swift:153-162`).

### D. "A click that reaches apps" reported back to cancel a swipe

There is **no port and no event from the tap to the model for this**. The path is a shared-memory read on the frame thread:
1. `ClickTap.holding` (`ClickTap.swift:49`) is `filter.withLock { $0.holding }`, read by the frame thread via `DeviceSession.holding` (`FrameStream.swift:49`).
2. `TouchFrame.Press(holding:buttonDown:)` (`Touch.swift:72-82`): `.withheld` → `.blocked`; `.nothing` → nil; `.passed` or `nil` (no tap) → `.click` only while a button is down (`CGEventSource.buttonState(.combinedSessionState, ...)`, `FrameStream.swift:71-73`).
3. The recognizer cancels on `frame.press == .click`: in `.swiping` it sets `state = after` and `event = .swipe(.cancelled)` (`GestureRecognizer.swift:140-142`); `.armed`/`.tapping`/`.resting` spoil on `.click` (90, 96, 112).
4. `.swipe(.cancelled)` travels as `TrackpadEvent.swipe(SwipeEvent)` over `TrackpadHardware.onEvent` (`Ports.swift:3-18, 27`) to `Launcher.swipe(_:)` `.cancelled` → `switcher = nil` (`Launcher.swift:232-233`).
   - Without Accessibility there is no tap, `holding` is nil, and any physical press with a button down reads `.click`, so a click always cancels a swipe without the permission.

### E. Accessibility permission

`SystemAccessibilityPermission` (`SystemAccessibilityPermission.swift`):
- `init(trusted: = { AXIsProcessTrusted() })` (14): reads `lastKnown` and calls `notify_register_dispatch("com.apple.tcc.access.changed", &token, .main)` (10, 17-19). The handler calls `refresh()`, which re-reads `trusted()` and calls `onChange` only if the value changed (35-40). Comment (5-7): the broadcast arrives ~30 ms after a TCC change and "names no app and no service", so trust is re-read on every broadcast.
- `isGranted()` reads fresh and updates `lastKnown` (24-27). Never prompts.
- `prompt()` calls `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)` (31-33); the key is spelled as a string because the imported `kAXTrustedCheckOptionPrompt` global `var` is rejected by strict concurrency.
- `isolated deinit { notify_cancel(token) }` (22).
- The prompt is shown only on first launch: `Launcher.start()` → `if prompting { access.prompt() }` before the first `store.save` (`Launcher.swift:81-89`), and the window is `.heldOpen` under the prompt (30-35, 88); a grant closes the held window (177).
- "Open System Settings" is UI-side, not the permission port: `SettingsPane.accessibility.url` = `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, `.trackpad` = `x-apple.systempreferences:com.apple.preference.trackpad` (`LauncherActions.swift:9-15`). `MenuBarShell.makeActions` → `openSettings: { pane in launcher.closeWindow(); NSWorkspace.shared.open(pane.url) }`. The view shows the Accessibility hint (`Copy.accessibilityHint`, `LK/Sources/LauncherCore/Copy.swift:12-13`) with button "Grant access…" while `!launcher.isAccessibilityGranted` (`LK/Sources/LauncherUI/LauncherView.swift`, around lines 30-34). Pressing the hint's button never prompts; it only opens the pane.
- Test `LK/Tests/LauncherPlatformTests/SystemAccessibilityPermissionTests.swift`: injects `trusted` as a `Mutex<Bool>`, posts the real Darwin notification with `notify_post(SystemAccessibilityPermission.changeNotification)` (accessible via `@testable`), and awaits `onChange` through an `AsyncStream` with a `Task.sleep` bound (1 s for "noise", 5 s for grant/revoke). Asserts: broadcast without trust change is silent; grant and revoke each arrive. It never touches real TCC.

### F. Running apps, frontmost app, bring to front

- `WorkspaceActions.bringToFront(_ app: AppEntry)` (`WorkspaceActions.swift:15-19`): `NSWorkspace.OpenConfiguration()` with `activates = true`, `NSWorkspace.shared.openApplication(at: app.url, configuration:)`; completion ignored. **Not** `NSRunningApplication.activate`. "One call reproduces a Dock click: launches, unhides, restores, reopens and activates." It is keyed by URL only; no pid, no window.
- `WorkspaceActions.runningApps()` → `RunningAppsReader.read()` (`WorkspaceActions.swift:21`, `RunningAppsReader.swift:19-21`) → `RunningApps(frontmost: frontmost(), apps: order?.apps() ?? fallbackApps())`.
  - `frontmost()` (38-43): `NSWorkspace.shared.frontmostApplication`, nil when it is this process; `RunningApp.entry(for:)`.
  - `LaunchServicesOrder.apps()` (`LaunchServicesOrder.swift:36-51`): `_LSCopyApplicationArrayInFrontToBackOrder(0xFFFF_FFFE)` then `_LSCopyApplicationInformation(-2, serial, keys)` per app with keys `pid, ApplicationType, LSBundlePath, CFBundleIdentifier, LSDisplayName`; keeps `ApplicationType == "Foreground"`, `pid != own`. **The pid is read but discarded**; `RunningApp.entry(bundleIdentifier:name:path:)` builds an `AppEntry`.
  - `fallbackApps()` (`RunningAppsReader.swift:23-34`): `NSWorkspace.shared.runningApplications` where `activationPolicy == .regular` and not own pid, ordered by `FallbackOrder.pids(running:recency:)`, recency from `ActivationTracker` (only created when `order == nil`, line 15).
- `RunningApp` (`RunningApp.swift`) is the only place an `NSRunningApplication` becomes a domain type: `AppEntry(bundleID:name:url:)`, URL via `AppEntry.location(ofBundleAtPath:)` (`LK/Sources/LauncherCore/Apps.swift:27-29`). `AppEntry` (`Apps.swift:12-30`) has `bundleID`, `name`, `url` and no pid. `RunningApps` (`Apps.swift:33-50`) has `frontmost: AppEntry?` and `apps: [AppEntry]`.
- `SystemActions` port (`Ports.swift:49-63`): `bringToFront`, `registerLoginItem`, `prepareLaunchAnimations`, `playLaunchAnimation`, `runningApps`.

### G. Tracking speed and pointer curves

- Curves: `CursorTravel.curves(of: io_service_t)` (`CursorTravel.swift:21-34`) reads `HIDAccelCurves` via `IORegistryEntrySearchCFProperty(..., kIORegistryIterateRecursively)`, 16.16 fixed point → `PointerCurve.Point`; falls back to `PointerCurve.builtInCurves`. Read once per session at `run` (`MultitouchTrackpads.swift:91`).
- Tracking speed: `CursorTravel.trackingSpeed()` (14-17) = `CFPreferencesCopyAppValue("com.apple.trackpad.scaling", kCFPreferencesAnyApplication)`, default `PointerCurve.defaultTrackingSpeed = 0.6875` (`PointerCurve.swift:33`). **It is not pushed by cfprefs KVO.** The comment (11-13): "Nothing pushes a change to this key (key-value observing splits its dotted name), so it is read at the start of each swipe instead: a read on a user event, not a poll."
- `CursorTravel.travel(curves:)` (37-43): `LaunchTuning.current`; `swipeFollowsCursor` false → `.linear`; speed = tuner override if `>= 0` else `trackingSpeed()`; `PointerCurve(curves, trackingSpeed:)` → `.cursor(curve, pointsPerIcon: tuning.swipePointsPerIcon)` (shipped 100, `PointerCurve.swift:140`).
- Called from `DeviceSession.receive` only when `recognition.swipe == .began` (`FrameStream.swift:38`), assigned to the recognizer's `var travel` (`GestureRecognizer.swift:52`); "Travel is 0 on the frame a swipe begins, so the next frame is the first to use it."
- `SwipeTravel.travel(dxMM:dyMM:interval:)` (`PointerCurve.swift:142-150`): `.linear` returns `dxMM`; `.cursor` returns `curve.cursorPoints(...) / pointsPerIcon * GestureRules.switcherStepMM`. `PointerCurve.cursorPoints` (`PointerCurve.swift:93-100`) uses `hypot(dx, dy)` for velocity but returns `dx * multiplier / velocity` — "Cursor points the pointer moves along x". **Both travel modes are x-only today.**
- `SystemTrackpadPreferences` (`SystemTrackpadPreferences.swift`) is the cfprefs-KVO adapter, but only for `ConflictingSetting.allCases` keys in `com.apple.AppleMultitouchTrackpad` and `com.apple.driver.AppleBluetoothMultitouch.trackpad`; `observeValue` hops to main and calls `onChange` (45-50). It does not observe the tracking speed.

### H. Settings persistence (for the window swipe setting)

`Settings` (`Settings.swift:7-33`): `handMode`, `assignments`, `isLaunchAnimationOn`, `isSwipeOn`, `isSwapOn`; custom `init(from:)` decodes each with `decodeIfPresent ?? default` ("a key missing from the record decodes as that field's default"). `SettingsStore` (36-57) saves one binary plist under key `"settings"` in the injected `UserDefaults` (`.standard` in `TrackpadLauncherApp.swift:19`). `setSwipe(on:)`/`setSwap(on:)` save and `reconcile()` (`Launcher.swift:128-141`); `swipes`/`swaps` flow through `Run` into `TrackpadHardware.run` and into each `GestureRecognizer` init.

---

## Source policy (`LK/Tests/LauncherCoreTests/SourcePolicyTests.swift`) in full

- **Scanned roots** (83-88): `LauncherKit/Sources` and `<repo>/TrackpadLauncher` (filtered by existence). Tests are not scanned, which is why tests may use `Task.sleep`, `.write(to:` etc. `scanVisitsEveryLibraryTarget` (128-134) asserts files under `/Sources/LauncherCore/`, `/Sources/LauncherPlatform/`, `/Sources/LauncherUI/` and `/TrackpadLauncher/` were visited.
- **Scan rule** (`scan`, 179-186): every `.swift` file, plain substring `line.contains(token)` per line, **comments included**, case-sensitive. Confined scans skip files whose `lastPathComponent == onlyIn` (file name only, not path).
- **Banned** (13-54), token → rule:
  - log: `print(`, `debugPrint(`, `dump(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os`
  - network: `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`
  - own files: `FileHandle(forWriting`, `.write(to:`, `createFile(atPath`
  - timer/polling: `Timer`, `asyncAfter`, `Task.sleep` (polling), `makeTimerSource`, `displayLink`, `DisplayLink`
  - "R9 only Accessibility": `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `IOHIDRequestAccess`, `IOHIDCheckAccess`, `CGRequestPostEventAccess`, `CGPreflightPostEventAccess`
  - "R9 no keyboard": `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged`
  - `ScrollWheel` ("scrolling is read only by the click tap")
  - "R9 never synthesise": `.post(tap:`, `CGEventPost`, `postToPid`
  - `nonisolated(unsafe)` ("one writer per field")
- **Confined** (64-76), token → only file:
  - `AXIsProcessTrusted` → `SystemAccessibilityPermission.swift` (also matches `AXIsProcessTrustedWithOptions` by substring)
  - `notify_register` → `SystemAccessibilityPermission.swift` ("R7 the trust push")
  - `tapCreate` → `ClickTap.swift`
  - `CGEventTapCreate` → `ClickTap.swift`
  - `scrollWheel` → `ClickTap.swift`
  - `_LSCopyApplicationArrayInFrontToBackOrder` → `LaunchServicesOrder.swift`
  - `_LSCopyApplicationInformation` → `LaunchServicesOrder.swift`
- **Registering a new adapter**: there is no registration mechanism other than adding `Confined(token:onlyIn:rule:)` / `Entry(token:rule:)` rows to these arrays. `Confined.onlyIn` is a single `String` file name, so one token can be confined to exactly one file.
- **Self-tests of the scanner**: `confinedScanFindsAUseOutsideItsFile` (102-113) and `scannerFindsAPlantedHit` (115-126) plant files in a temp dir removed by `defer`; `importScannerFindsAPlantedImport` (144-154).
- **Core import allow-list**: `coreImportsOnlyFoundationAndObservation` (136-142); `disallowedImports` (157-169) matches lines whose words before `import` are only attributes/`public`/`internal`, and checks the first dotted component of the module.
- The architecture's "no files written other than settings in UserDefaults" is enforced only by the three "own files" tokens.

### Where window-swipe APIs meet the policy (facts, no design)

- `AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue`, `kAXWindowsAttribute`, `kAXRaiseAction`/`AXUIElementPerformAction`, `kAXMinimizedAttribute`, `kAXFocusedWindowAttribute`, `kAXMainAttribute`: **none is banned or confined today**. A new adapter file using them passes the scan as long as it does not contain the substring `AXIsProcessTrusted` (confined to `SystemAccessibilityPermission.swift`). `docs/architecture.md` ("Privacy and permissions") says "The Accessibility APIs, the event tap and the scroll-event API are each confined to one adapter file by the source-scan test", but the table only confines `AXIsProcessTrusted`, not the `AXUIElement*` family.
- `CGPreflightScreenCaptureAccess`, `CGRequestScreenCaptureAccess`, `CGWindowListCopyWindowInfo`, `ScreenCaptureKit`/`SCShareableContent`/`SCScreenshotManager`: **not banned or confined today**. They are not substrings of any banned token (e.g. `CGPreflightListenEventAccess` ≠ `CGPreflightScreenCaptureAccess`).
- The banned rule label "R9 only Accessibility" and `docs/architecture.md` ("The app asks for one permission, Accessibility ... It never asks for Input Monitoring or any other permission") are the prose/table that a Screen Recording permission contradicts; the doc's product-overview privacy note is called out for change in `plan.md` "Documentation".
- `notify_register` is confined to `SystemAccessibilityPermission.swift`. A second permission adapter in another file that registers the same `com.apple.tcc.access.changed` broadcast would fail `onlyItsAdapterUses`. The broadcast "names no app and no service" (adapter comment), so the same notification is the existing push channel for any TCC change; whether it also fires for Screen Recording grants was not verified here.
- `CGWindowListCreateImage` is marked `SCREEN_CAPTURE_OBSOLETE(10.5,14.0,15.0)` = `availability(macos, deprecated=14.0, obsoleted=15.0, message="Please use ScreenCaptureKit instead.")` in the installed SDK (`MacOSX.sdk` 26.5, `CoreGraphics.framework/Headers/CGWindow.h:271-274`, macro at 223-224). With the macOS 26 deployment target it is unavailable; `CGWindowListCopyWindowInfo` is plain `API_AVAILABLE(macos(10.5))` (CGWindow.h:170-172). `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess` are at CGWindow.h:295/298. `ScreenCaptureKit.framework` is present in the SDK.
- The banned `Timer`, `asyncAfter`, `Task.sleep` tokens also bind any wait/retry logic around asynchronous capture; `.write(to:` binds any image encoding to disk (R17).
- Substring hazards for new code: `print(` catches any identifier ending in `print(` (e.g. `fingerprint(`); `dump(`; `Timer` catches any identifier containing `Timer`; `keyDown`/`KeyDown` catch e.g. names containing them; `ScrollWheel`/`scrollWheel` catch any mention, comments included.
- `LauncherCore` may import only Foundation and Observation (test at 136-142), so no AX, CG, AppKit or ScreenCaptureKit type can appear in core domain types. No `CGRect`/`CGFloat`/`CGImage` appears in `LauncherCore` today (grep found none).

---

## Build configuration

- `LK/Package.swift`: tools 6.2, `.macOS(.v26)`, Swift 6 language mode. Targets: `LauncherCore` (no deps), `LauncherPlatform` (→ Core), `LauncherUI` (→ Core only, `.defaultIsolation(MainActor.self)`), test targets `LauncherCoreTests` (→ Core) and `LauncherPlatformTests` (→ Platform, Core). **`LauncherUI` does not depend on `LauncherPlatform`**; only the app target sees both. No `linkerSettings`/`linkedFramework` anywhere: system frameworks are linked by SwiftPM autolinking from `import`s. Imports in `LauncherPlatform` today: AppKit, ApplicationServices (1: SystemAccessibilityPermission), CoreGraphics (2), CoreServices (2), Dispatch, Foundation, IOKit (3), notify (1), Observation, QuartzCore, ServiceManagement, SwiftUI, Synchronization.
- `project.yml`: one `application` target `TrackpadLauncher`, sources `TrackpadLauncher/` (excludes `Info.plist`) and `assets/*.svg` as resources; depends on the three package products. Info.plist is generated from `info.properties`: `CFBundleName`/`CFBundleDisplayName` "Trackpad Launcher", `CFBundleShortVersionString` "1.0", `CFBundleVersion` "1", `LSUIElement: true`, `LSMinimumSystemVersion` "26.0". `PRODUCT_BUNDLE_IDENTIFIER: com.domasgru.TrackpadLauncherApp`, `GENERATE_INFOPLIST_FILE: NO`. `TrackpadLauncher/Info.plist` and `TrackpadLauncher.xcodeproj/` are gitignored (`.gitignore`).
- **No usage-description strings** (`NS*UsageDescription`) exist in Info.plist properties today. **No entitlements file** exists (`find` found no `*.entitlements`; no `CODE_SIGN_ENTITLEMENTS` setting). **Not sandboxed** (no sandbox entitlement; `LaunchServicesOrder.swift:5` says "the app is not sandboxed").
- `Config/Base.xcconfig`: `MACOSX_DEPLOYMENT_TARGET = 26.0`, `ARCHS = $(ARCHS_STANDARD)`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_STYLE = Manual`. `Debug.xcconfig`: "Apple Development", team `CQK27876UL`. `Release.xcconfig`: "Developer ID Application", `OTHER_CODE_SIGN_FLAGS = --timestamp`.
- `Scripts/release.sh`: archive, export developer-id, verify hardened runtime flag `0x10000(runtime)`, notarize, staple, `spctl --assess`. `Scripts/test.sh`: `swift test` in `LauncherKit`.
- Composition root `TrackpadLauncher/TrackpadLauncherApp.swift`: builds `Launcher(hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), access: SystemAccessibilityPermission(), system: WorkspaceActions(), catalog: .system, scanner: SystemAppScanner(catalog:), store: SettingsStore(defaults: .standard))`, then `MenuBarShell`, `launcher.start()`.

---

## How platform adapters are tested

`LK/Tests/LauncherPlatformTests/` (1049 lines total):

| Test file | Hits the real platform? |
|---|---|
| `RunningAppsReaderTests.swift` | Yes: real `LaunchServicesOrder` (private symbols) and `NSWorkspace.runningApplications`/`frontmostApplication`, compared against each other. Guarded with `.enabled(if: orderResolves ...)` and `.enabled(if: dockAppCount >= 3 ...)`. Fallback activation is simulated by **posting** `didActivateApplicationNotification` on the workspace notification center with a real `NSRunningApplication` — nothing is actually activated. `FallbackOrder` is tested as a pure function. |
| `TapEventTests.swift` | Builds synthetic `CGEvent(source: nil)` / `CGEvent(scrollWheelEvent2Source:...)` and runs the parsers and `apply` functions. **No tap is installed**; no permission needed. |
| `SystemTrackpadPreferencesTests.swift` | Yes: real cfprefs KVO, with domains written by a child `/usr/bin/defaults` process. Since d612c10 the domains are absolute paths inside a temp folder `tl-prefs-<UUID>` removed in `deinit` (lines 12-19). |
| `SystemAccessibilityPermissionTests.swift` | Real `notify_post`/`notify_register_dispatch`, injected `trusted` closure; never reads or changes real TCC. |
| `SystemAppScannerTests.swift` | Real FSEvents and off-main scans over a temp tree `tl-scanner-<UUID>` removed in `deinit`; uses a semaphore `Gate`. |
| `SpotlightLastUsedTests.swift` | Real Spotlight read compared with `/usr/bin/mdls`. |
| `AppCatalogSystemTests.swift` | Real `AppCatalog.system` on `/System/Applications/FindMy.app`. |
| `LaunchFlightTests.swift` | Core Animation keyframes read back (no display). |
| `HapticActuationTests.swift`, `TrackpadClassificationTests.swift`, `TouchFrameParsingTests.swift` | Pure helpers (`actuation(for:)`, `trackpadKind(product:isBuiltIn:)`, frame parsing). |

Nothing in `LauncherPlatformTests` installs the click tap, prompts for a permission, activates an app, or reads the real AX trust; `MultitouchTrackpads` and `WorkspaceActions.bringToFront` have no direct test.

Machine-cleanliness rule (commit `d612c10`, "Stop tests leaking preference files and temp folders"): named cfprefs domains leave an empty plist in `~/Library/Preferences` even after `removePersistentDomain` / `defaults delete`, so both `World`'s suite (`LK/Tests/LauncherCoreTests/World.swift`, `suiteName = root.appending(path: "Preferences").path`) and the `SystemTrackpadPreferencesTests` domains are named by absolute paths inside a temp folder removed in `deinit`. Hooks that read a `World` must capture it `[unowned world]`, or the retain cycle keeps `deinit` from running (`AccessibilityTests.swift`, `PersistenceTests.swift` diffs).

Representative platform test (`LK/Tests/LauncherPlatformTests/SystemTrackpadPreferencesTests.swift:50-65`):

```swift
@Test(arguments: TrackpadKind.allCases)
func tapToClickWriteAndDeleteArePushedAndReadable(kind: TrackpadKind) async {
    let domain = Domain(kind)
    domain.write("Unrelated", int: 1)
    let adapter = SystemTrackpadPreferences(domains: [kind: domain.name])
    #expect(adapter.current()[kind]?[.tapToClick] == nil)

    let wrote = await changeArrives(on: adapter) { domain.write("Clicking", int: 1) }
    #expect(wrote, "onChange arrives within 5 s of the write")
    #expect(adapter.current()[kind]?[.tapToClick] == 1)
    #expect(adapter.current()[kind]?[.lookUpTapWithThreeFingers] == nil)

    let deleted = await changeArrives(on: adapter) { domain.delete() }
    #expect(deleted, "onChange arrives within 5 s of the delete")
    #expect(adapter.current()[kind]?[.tapToClick] == nil)
}
```

`changeArrives` (34-48) is the shared shape for push adapters: set `onChange` to yield into an `AsyncStream`, start a bounded `Task.sleep` that yields `false`, run the action, await the first value. "The push is awaited, never polled."

In-memory side (`LK/Tests/LauncherCoreTests/InMemoryAdapters.swift`): `InMemoryTrackpads` runs the **real** `GestureRecognizer`, `ClickFilter` and `ScrollFilter`; its `run` arms a fake tap iff `blockClicks && !trackpads.isEmpty` (line 53-54); `touch(_:on:)` delivers press edges through the filter using the previous frame's merged `blocking` flags, then re-samples `TouchFrame.Press(holding:buttonDown:)` exactly like the frame callback (79-93); `scroll(_:)` returns the `ScrollVerdict` or nil without a tap (113-115). It records `blocking` from `blocksClicks` only (it has no Dock swipe filter). `RecordingSystemActions` records `broughtToFront` and returns `RunningApps(frontmost:apps:)` from settable fields. `InMemoryAccessibilityPermission` counts `prompts` and exposes `set(granted:)`.

---

## Files Read

- `docs/architecture.md`, `docs/domain-model.md`, `plans/012-window-switcher-gesture/plan.md`
- `LauncherKit/Sources/LauncherPlatform/ClickTap.swift`
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift`
- `LauncherKit/Sources/LauncherPlatform/SystemAccessibilityPermission.swift`
- `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift`
- `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift`
- `LauncherKit/Sources/LauncherPlatform/RunningApp.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift`
- `LauncherKit/Sources/LauncherPlatform/FallbackOrder.swift`
- `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift`
- `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift`
- `LauncherKit/Sources/LauncherPlatform/SystemTrackpadPreferences.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift` (lines 1-80)
- `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift` (grep only)
- `LauncherKit/Sources/LauncherPlatform/MultitouchSupport.swift` (grep only)
- `LauncherKit/Sources/LauncherCore/ClickFilter.swift`, `ScrollFilter.swift`, `DockSwipeFilter.swift`
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (lines 1-200, 242-250, 334-339)
- `LauncherKit/Sources/LauncherCore/Touch.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (lines 20-260)
- `LauncherKit/Sources/LauncherCore/Settings.swift`
- `LauncherKit/Sources/LauncherCore/Apps.swift` (AppEntry, RunningApps)
- `LauncherKit/Sources/LauncherCore/PointerCurve.swift` (lines 33, 85-150)
- `LauncherKit/Sources/LauncherCore/Copy.swift` (accessibilityHint)
- `LauncherKit/Sources/LauncherUI/LauncherActions.swift`, `MenuBarShell.swift` (makeActions), `LauncherView.swift` (lines 15-45), `SwitcherPanel.swift`/`LauncherPanel.swift` (grep only)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 1-120 plus outline)
- `LauncherKit/Tests/LauncherPlatformTests/SystemAccessibilityPermissionTests.swift`, `RunningAppsReaderTests.swift`, `TapEventTests.swift`, `SystemTrackpadPreferencesTests.swift`, `HapticActuationTests.swift`, `AppCatalogSystemTests.swift`, `TrackpadClassificationTests.swift`, heads of `SystemAppScannerTests.swift`, `SpotlightLastUsedTests.swift`, `LaunchFlightTests.swift`
- `LauncherKit/Package.swift`, `project.yml`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `.gitignore`, `Scripts/release.sh`, `Scripts/test.sh`, `TrackpadLauncher/TrackpadLauncherApp.swift`
- `git show d612c10`
- SDK header `MacOSX.sdk/System/Library/Frameworks/CoreGraphics.framework/Headers/CGWindow.h` (grep)

---

## Boundaries

- **Model → hardware**: `TrackpadHardware.run(_:handMode:blockClicks:swipes:swaps:)` (`Ports.swift:35`) is the only way the model affects the tap and the recognizers. Per-recognizer behaviour flags (`swipes`, `swaps`) are init parameters of `GestureRecognizer`, so a change means a new `run`, which ends any swipe in progress (`Launcher.swift:186-188`).
- **Hardware → model**: `TrackpadHardware.onEvent` with `TrackpadEvent` `.gesture/.swipe/.swap/.trackpadsChanged` (`Ports.swift:3-18`), on main, generation-checked. `Recognition.Event` → `TrackpadEvent` mapping is the single `TrackpadEvent.init(_:on:)` used by both adapters.
- **Recognizer ↔ tap** (no port, frame/tap threads): `Recognition.blocksClicks` / `.blocksDockSwipes` → `DeviceSession` Mutexes → `anyTrackpadBlocks*()` on the tap thread; `ClickFilter.holding` → `TouchFrame.Press` on the frame thread.
- **Permission → model**: `AccessibilityPermission.onChange` (no data) → `reconcile()`; `isGranted()` drives `Launcher.isAccessibilityGranted` (UI hint) and `blockClicks`. The model never passes the permission to the recognizer: "Whether a press is really blocked also needs the click filter armed ... which the recognizer never knows" (`GestureRecognizer.swift:14-16`).
- **Model → system effects**: `SystemActions.bringToFront(AppEntry)` and `runningApps()`; domain types only (`AppEntry` has no pid, no window).
- **UI → System Settings**: `LauncherActions.openSettings(SettingsPane)`, URL-based, in `LauncherUI`, outside any port.
- **Settings**: `SettingsStore` (concrete, not a port — "can be pointed at a throwaway `UserDefaults` suite", architecture.md).
- **Architecture rules a window adapter has to meet** (`docs/architecture.md`): every port has exactly two adapters (real in `LauncherPlatform`, in-memory in tests); framework types (`CFTypeRef`, `NSRunningApplication`, `NSImage`, ...) never cross a port; concrete types that deliver asynchronously sit behind a port so the model's tests stay synchronous; no timers/polling; `LauncherUI` cannot see `LauncherPlatform`.

---

## Non-Obvious Things

1. **No "click reached apps" message exists.** The tap does not notify anyone; the frame thread reads `ClickFilter.holding` plus the global button state on each frame and the recognizer cancels on `.click`. A passed press counts as `.click` only while a button is still down.
2. **"Held open for the whole of a swipe" has no timer**: `blocksClicks`/`blocksDockSwipes` are true on every frame where the recognizer's state is `.swiping` (or a swap series). A window swipe that is not `.swiping` (or an equivalent state) would fall back to the 3 s rule and to the anchored-thumb Dock-swipe rule (`GestureRecognizer.swift:170-187`).
3. **A vertical slide today is a spoil, not a non-event**: `beginOrSpoil` returns `.spoiled(anchor)` when `!move.isSideways` (`GestureRecognizer.swift:246`).
4. **The tracking speed is not pushed**: despite "cfprefs KVO" elsewhere, `com.apple.trackpad.scaling` is read with `CFPreferencesCopyAppValue` when each swipe begins, because KVO splits dotted key names (`CursorTravel.swift:11-13`). `SystemTrackpadPreferences` observes only the conflicting-setting keys.
5. **Travel is horizontal-only**: `SwipeTravel.linear` returns `dxMM` and `PointerCurve.cursorPoints` returns x cursor points (velocity uses `hypot`). The travel is reset per swipe only on `recognition.swipe == .began` in `DeviceSession.receive` (`FrameStream.swift:38`).
6. **Bring to front is `NSWorkspace.openApplication(at: url, activates: true)`**, keyed by bundle URL, not `NSRunningApplication.activate`; it reproduces a Dock click (may reopen windows). It cannot target a window.
7. **The pid is available but dropped**: `LaunchServicesOrder` asks for `"pid"` and uses it only to exclude this process; `RunningApp.entry(for:)` ignores `processIdentifier`. `AppEntry`/`RunningApps` carry no pid, which `AXUIElementCreateApplication(pid_t)` needs.
8. **The Accessibility prompt is only ever shown on first launch** (`Launcher.start`). The hint button opens System Settings by URL; it never calls `prompt()`. R8's "first press asks, later presses open Settings" has no precedent in the code.
9. **`DockSwipeFilter.forgetSwipe()` is unused**: on a tap disable `ClickTap.handle` replaces the whole dictionary instead (`ClickTap.swift:69`).
10. **The tap thread retains the `ClickTap`** via the `Thread` closure capture; `userInfo` is passed unretained. The tap is replaced (not toggled) on every `run`: `remove()` then a fresh `install()`.
11. **The source scan matches comments too**, as substrings: a doc comment naming a banned API fails the build.
12. **The architecture text over-states the confinement**: only `AXIsProcessTrusted` is confined, not the AX element API family.
13. **`Confined.onlyIn` is one file name**, matched by `lastPathComponent`: two files with the same name in different targets would both be exempt; a token cannot be allowed in two files.
14. **`InMemoryTrackpads` mirrors only click blocking and scroll suppression**, not Dock swipe blocking (it records `blocksClicks` only, line 87).
15. The Debug-only `AnimationTuner` writes tuning JSON into `UserDefaults.standard` (`AnimationTuner.swift:79, 141`), the only other `UserDefaults` writer besides `SettingsStore`.

---

## Open Questions

- Whether `com.apple.tcc.access.changed` is broadcast for Screen Recording (kTCCServiceScreenCapture) grants/revokes as it is for Accessibility: not verified. The adapter comment says only that it "names no app and no service".
- Whether a Screen Recording grant takes effect in-process without relaunch on macOS 26 (R7 says "after any relaunch macOS requires"): not checked in code; nothing in the repo deals with it.
- Whether an Info.plist usage string is required for Screen Recording or `CGRequestScreenCaptureAccess` on macOS 26: none exists today; I did not verify the TCC requirement.
- Whether `AXUIElement` calls against another app would need anything beyond the existing Accessibility trust under the hardened runtime with no entitlements (the app is not sandboxed and has no entitlements file): not verified.
- I did not read `SwitcherPanel.swift`, `SwitcherPresenter.swift`, `AppIcons.swift` or `LaunchOverlay.swift` in full (UI/overlay are outside this angle); only grepped that `SwitcherPanel` is a `.nonactivatingPanel` with `ignoresMouseEvents = true` and `canBecomeKey == false`.
- I did not run `swift test`; facts about test behaviour come from reading the sources.
