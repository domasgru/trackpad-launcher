# Grounding: the model, the wiring, and the tests (angle: model-and-tests)

All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/014-gate-event-tap`.

## Part 1. The model and the wiring

### Components Found

- **`TrackpadHardware`** (`LauncherKit/Sources/LauncherCore/Ports.swift:26-46`). This is the only port click blocking sits behind. No separate "click tap" port exists. It has four members:
  - `var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }` (line 32)
  - `func connected() -> [Trackpad]` (line 34)
  - `func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, slides: Set<SlideKind>, swaps: Bool)` (line 40). Doc (lines 35-39): "Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent. The tap needs Accessibility. If the system refuses it, nothing is filtered…"
  - `func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)` (line 42)
  - `func confirmWindowSwipe(on trackpad: TrackpadID)` (line 45)
  - The port has no arm/disarm methods and no query such as "is the tap installed" or "is the tap enabled". Arming is the `blockClicks: Bool` argument of `run`, and nothing more.
- **`TrackpadEvent`** (`Ports.swift:3-20`) has the cases `.gesture`, `.swipe`, `.windowSwipe`, `.swap` and `.trackpadsChanged` ("Attached, detached, or the Mac woke"). Both adapters build it from a recognizer event with `TrackpadEvent.init(_ event: Recognition.Event, on:)`.
- **`TrackpadPreferences`** (`Ports.swift:49-54`) has `onChange` and `current() -> [TrackpadKind: TrackpadPreferenceValues]`.
- **`Permissions`** (`Ports.swift:89-97`) has `onChange`, `isGranted(_:)` (always a fresh read) and `ask(_:)`. `Permission` (lines 84-86) is `.accessibility` or `.screenRecording`.
- **`Launcher`** (`LauncherKit/Sources/LauncherCore/Launcher.swift:8-348`) is the `@MainActor @Observable` model. Everything about arming lives in the private `struct Run` (197-203), `lastRun` (205) and `reconcile(restart:)` (211-231).
- **`GestureActivity`**, `ConflictingSetting` and `ConflictingSettings` (`LauncherKit/Sources/LauncherCore/Activity.swift`). `GestureActivity.init(connected:values:)` (62-71) returns `.inactive(.noTrackpad)` when nothing is connected. It returns `.inactive(.settings(...))` when a table key conflicts on any connected kind: Tap to click is `Clicking == 1`, and Look up is `TrackpadThreeFingerTapGesture == 2` (lines 12-25). Otherwise it returns `.active`.
- **`Settings`** (`LauncherKit/Sources/LauncherCore/Settings.swift:7-33`) holds `handMode` (default `.right`), `isSwipeOn`, `isSwapOn` and `isWindowSwipeOn` (all default true). `slides` (27-32) is derived: `.swipe` if `isSwipeOn`, plus `.windowSwipe` if `isWindowSwipeOn`.
- **`GestureRules`** (`LauncherKit/Sources/LauncherCore/GestureRules.swift`) is `package`, and the model never passes it anywhere. The recognizer reads its constants directly. The one constant relevant to blocking is `clickBlockingWindow = .seconds(3)` (line 23, "Strictly less blocks").
- **Composition root**: `TrackpadLauncher/TrackpadLauncherApp.swift:8-26`. It builds `Launcher(hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(), system: WorkspaceActions(), catalog: .system, scanner: SystemAppScanner(...), store: SettingsStore(defaults: .standard))`, creates `MenuBarShell`, and calls `launcher.start()`. Nothing else in the app target touches the tap.
- **`MultitouchTrackpads`** (`LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift`) is the real `TrackpadHardware`, and it owns `private var clickTap: ClickTap?` (line 17).
- **`DeviceSession`** and the global `sessions` (`LauncherKit/Sources/LauncherPlatform/FrameStream.swift`) are the frame-thread half. They hold the per-trackpad `blocking` and `blockingDockSwipes` mutexes that the tap thread reads.
- **`SystemPermissions`** (`LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift`) is the TCC Darwin notification `com.apple.tcc.access.changed` via `notify_register_dispatch` on `.main` (line 22). `refresh()` (51-56) calls `onChange` only if the granted set really changed.
- **`SystemTrackpadPreferences`** (`LauncherKit/Sources/LauncherPlatform/SystemTrackpadPreferences.swift`) uses KVO on the two cfprefs domains for each `ConflictingSetting.preferenceKey` (19-23). `observeValue` hops to main with `Task { @MainActor … onChange?() }` (45-50). It fires for any write to those keys, even one that changes nothing.

### The arming predicate (exact)

From `Launcher.reconcile(restart:)`, `Launcher.swift:211-231`:

```swift
connected = hardware.connected()
preferenceValues = preferences.current()
let granted = permissions.isGranted(.accessibility)
...
isScreenRecordingGranted = permissions.isGranted(.screenRecording)
let active = activity.isActive          // GestureActivity(connected kinds, preference values)
let run = Run(
    trackpads: active ? connected : [], handMode: settings.handMode, blockClicks: active && granted,
    slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe]), swaps: settings.isSwapOn)
guard restart || run != lastRun else { return }
lastRun = run
shown = nil
hardware.run(run.trackpads, handMode: run.handMode, blockClicks: run.blockClicks, slides: run.slides, swaps: run.swaps)
```

- "Click blocking is armed" means `blockClicks == active && granted`, where `active` means at least one trackpad is connected and no conflicting setting is on for any connected kind.
- `active` implies `connected` is non-empty. So from the model's side, `blockClicks == true` always comes with a non-empty `trackpads`. The real adapter still checks `!devices.isEmpty` again after its own `listTrackpads()` (`MultitouchTrackpads.swift:87`).
- Accessibility also gates `slides`: without access, `.windowSwipe` is removed.
- The arming flag depends on no per-gesture state. It never changes during a gesture. The only way to change it is a new `run`.

### Every input that re-evaluates it, and what happens

There is one convergent path, `reconcile(restart:)`. Every call site is listed below.

| Input | Where | Call | Re-runs? |
|---|---|---|---|
| Launch | `start()` `Launcher.swift:101` | `reconcile()` | First call, so `lastRun == nil` and it always runs |
| IOKit hot-plug (first-match and terminated on `AppleMultitouchDevice`) | `MultitouchTrackpads.init` 31-47 → `onEvent?(.trackpadsChanged)` → `Launcher.start` closure line 94 | `reconcile(restart: true)` | Always |
| Wake (`NSWorkspace.didWakeNotification`) | `MultitouchTrackpads.init` 48-52 → `.trackpadsChanged` | `reconcile(restart: true)` | Always, because devices stop delivering frames across sleep |
| cfprefs KVO (Tap to click, Look up) | `start()` line 99 `preferences.onChange = { reconcile() }` | `reconcile()` | Only if `Run` changed |
| TCC Darwin notification (Accessibility or Screen Recording) | `start()` line 100 `permissions.onChange = { reconcile() }` | `reconcile()` | Only if `Run` changed. A Screen Recording change alone never re-runs (comment line 218) |
| Hand mode | `setHandMode(_:)` 134-139 | `reconcile()` | Yes, because `Run.handMode` differs |
| Swipe setting | `setSwipe(on:)` 149-154 | `reconcile()` | Yes, because `slides` differs |
| Window swipe setting | `setWindowSwipe(on:)` 158-163 | `reconcile()` | Only if Accessibility is granted. Without it, `.windowSwipe` is already stripped, so `Run` is unchanged and nothing runs |
| Swap setting | `setSwap(on:)` 166-171 | `reconcile()` | Yes, because `swaps` differs |
| Launch animation, assignment, window open or close, screen recording ask | none | none | Never re-evaluated |

When a reconcile does run:
1. `shown = nil` (line 229). This ends any switcher or window switcher. The comment says "Running replaces every recognizer, which ends any swipe or window swipe in progress".
2. `hardware.run(...)` performs a new `run` session, with fresh recognizers built with the hand mode, slides and swaps. In the real adapter the tap is also always re-installed: it is removed and then created again if `blockClicks`. There is no "keep the tap, swap the recognizers" path, and no "change only the arming" path. Any change to hand mode or a setting therefore throws away all `ClickFilter`, `ScrollFilter` and `DockSwipeFilter` state along with the old `ClickTap`.

### How the blocking policy reaches the recognizer

- The model never hands `GestureRules` or `Settings` objects across the port. It hands only `handMode`, `slides` and `swaps` through `run`. The adapter builds `GestureRecognizer(handMode:surface:slides:swaps:travel:)` per trackpad: real at `MultitouchTrackpads.swift:92` with `travel: .linear`, which `DeviceSession.receive` later replaces with `CursorTravel.travel(...)` on `beginsSlide`; in memory at `InMemoryAdapters.swift:51`. The recognizer is never mutated by the model on a setting change. It is replaced.
- The recognizer has no idea whether blocking is armed (`GestureRecognizer.swift:15-23` doc on `Recognition.blocksClicks`/`blocksDockSwipes`: "Whether a press is really blocked also needs the click filter armed (access granted, gestures active), which the recognizer never knows."). It computes `blocksClicks`/`blocksDockSwipes` every frame regardless (`GestureRecognizer.swift:182-200`).
- `blockClicks` itself does not reach the recognizer. It decides only whether a `ClickTap` exists.

### Real adapter `run` flow (`MultitouchTrackpads.swift:68-116`)

1. `runs += 1`, which bumps the generation. If there is no `framework`, it returns early, so no tap is ever installed.
2. `sessions.withLock { $0 = [:] }`. Frames in flight for old devices now find nothing.
3. `clickTap?.remove(); clickTap = nil` (73-74). The comment at line 72 reads "A withheld press's release may now reach apps: a harmless stray mouse-up."
4. It unregisters the old devices' callbacks, stops them, and closes their actuators.
5. `devices = listTrackpads().filter { wanted.contains(...) }`. Then `if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }` (line 87). This can be `nil` when the system refuses (no Accessibility). The model is never told.
6. For each device it creates a `DeviceSession(trackpad:, recognizer:, pointerCurves:, clickTap: clickTap, deliver:)`. Each session holds a reference to the same `ClickTap`. It then inserts the session into `sessions`, registers `contactFrameCallback`, and starts the device.

### Frame thread → tap thread (wiring, for context)

- `contactFrameCallback` (`FrameStream.swift:86-91`) samples `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())` before stepping. `session.holding` is `clickTap?.holding`, which reads `ClickFilter.holding` under the tap's mutex. So state flows tap → frame thread as well: the frame reads the click filter's withheld/passed summary.
- `DeviceSession.receive` (46-69) steps the recognizer and then writes `blocking.withLock { $0 = recognition.blocksClicks }` and `blockingDockSwipes.withLock { $0 = recognition.blocksDockSwipes }` (58-59). Two separate mutexes, no combined atomicity.
- On the tap thread, `ClickTap.handle` (`ClickTap.swift:64-88`) calls `anyTrackpadBlocksClicks()` once per event (`FrameStream.swift:100-102`: copies `sessions` values, ORs `blocksClicks`). For Dock swipes it also calls `anyTrackpadBlocksDockSwipes()` (106-108). These are OR-merged across trackpads at read time.
- `TouchFrame.Press.init?(holding:buttonDown:)` (`LauncherKit/Sources/LauncherCore/Touch.swift`, the `Press` enum) is "the one precedence rule, used by both hardware adapters". `.withheld` → `.blocked`. `.nothing` → nil. `.passed`/nil → `.click` iff the button is down.

## Part 2. The tests

### Seams at a glance

| Test file | Seam driven | Real code under test |
|---|---|---|
| `ClickBlockingTests.swift` | Model via `World` + `InMemoryTrackpads.touch(frames)` with press-carrying frames | `Launcher` + real `GestureRecognizer` + real `ClickFilter` (inside the fake) |
| `ScrollSuppressionTests.swift` | Model via `World.play` then `hardware.scroll(ScrollEvent)` | `Launcher` + recognizer + real `ScrollFilter` (inside the fake) |
| `WindowSwipeBlockingTests.swift` (incl. `WindowSwipeSettingTests`) | Model via `World.windowWorld`, `play`, `playFrameByFrame`, `scroll(...)`, `pressVerdicts` | same + `WindowSwipeConfirmation` |
| `AccessibilityTests.swift` | Model via `World` + `InMemoryPermissions.set` | only `isAccessibilityGranted`, the window hold, prompt order. **Does not assert blocking at all** |
| `ClickBlockingRecognizerTests.swift` | `GestureRecognizer.step` with `HandFrames`/`TouchScript` (`blocksClicks`); also `ClickFilterTests` (filter directly) and `PressSamplingTests` (`TouchFrame.Press.init`) | recognizer, `ClickFilter`, `TouchFrame.Press` |
| `DockSwipeBlockingRecognizerTests.swift` | `GestureRecognizer.step` → `blocksDockSwipes` | recognizer |
| `SwapRecognizerTests.swift` (blocking parts, lines 29-42, 44-62, 73-81, 83-107) | `GestureRecognizer.step` → both flags | recognizer |
| `ScrollFilterTests.swift` | `ScrollFilter.decide` with `(ScrollEvent, Bool)` pairs | `ScrollFilter` |
| `DockSwipeFilterTests.swift` | `DockSwipeFilter.decide` with `(DockSwipePhase, Bool)` pairs | `DockSwipeFilter` |
| `SourcePolicyTests.swift` | Text scan of `LauncherKit/Sources` + `TrackpadLauncher/` | none (static) |
| `LauncherPlatformTests/TapEventTests.swift` | `@testable import LauncherPlatform`: `TapEvent`, `TapEvent.tapMask`/`tapTypes`, the `PointerEvent`/`ScrollEvent`/`DockSwipePhase` `CGEvent` parsers, the verdict `apply(to:)` extensions, with synthetic `CGEvent(source: nil)` | parsing and rewrite only. **Never `ClickTap.install`, `handle`, `remove`, or the timeout path** |

Other suites that assert blocking through the World: `SwapTests.swift:58-77, 309-335`; `SwitcherOnScreenTests.swift:299-360`; `SwipeSettingTests.swift:42-63`; `SwitcherAssignedAppsTests.swift:110-130`; `WindowSwipeNeedsTwoWindowsTests.swift:84-125` (scroll probe per frame); `WindowSwitcherOnScreenTests.swift:270-297` (scroll probe per frame, two trackpads). Platform-level `DeviceSessionAnswerTests.swift:62-128` drives a real `DeviceSession` with `clickTap: nil` and reads `session.blocksClicks` per frame, which is the one test of the frame-thread flag write.

### `InMemoryTrackpads` (the fake tap), `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:5-127`

Doc: "Real recognizer, real click filter, scripted frames, synchronous main-actor delivery."

State:
- `private(set) var running: [TrackpadID: GestureRecognizer]` (8). The fake owns and steps real recognizers.
- `private var clickFilter: ClickFilter?` (13) and `var isBlockingClicks: Bool { clickFilter != nil }` (14). This is "the fake click tap: armed iff the last `run` asked for it with trackpads".
- `private var scrollFilter: ScrollFilter?` (16). It is "armed and disarmed with `clickFilter`: one tap decides both".
- `private(set) var pressVerdicts: [PointerVerdict]` (18). This is "what the fake tap did with each scripted press and release, in order". It is cumulative for the test's whole lifetime and not reset by `run`.
- `private var blocking: [TrackpadID: Bool]` (20) holds each running trackpad's latest `blocksClicks`. There is no `blocksDockSwipes` and no `DockSwipeFilter` in the fake.
- `buttonWasDown`, `pressInProgress`, `nextPressNumber` (21-23) synthesize press IDs (always button 0).
- `private(set) var runCount` (45) counts `run` calls, and `windowSwipeAnswers: [Bool]` (26).

`run(...)` (47-59) replaces all recognizers and clears `deaf`, `blocking`, `buttonWasDown` and `pressInProgress`. It then sets `clickFilter = blockClicks && !trackpads.isEmpty ? ClickFilter() : nil` and `scrollFilter = clickFilter == nil ? nil : ScrollFilter()`. It records only the *arming* (filter present or absent). It never records arm and disarm as separate calls, and the history of the `blockClicks` argument is not kept. `runCount` is the only history.

`touch(_ frames:, on:)` (84-101). Per frame, in this order:
1. A guard drops the frame (and the rest of the batch) if that trackpad isn't running or is `deaf` (after `sleep()`).
2. `deliverPressEdge(buttonDown: frame.press != nil)` (103-117). If the press-down state changed since the previous frame and a filter is armed, it feeds `.press(PressID(button: 0, number: n))` or `.release(pressInProgress)` to `clickFilter.decide(_, trackpadBlocking: blocking.values.contains(true))` and appends the verdict to `pressVerdicts`. The doc (80-83) says: "a press edge reaches the tap between frames, so it is decided on the flags the previous frame left, merged across trackpads; then the frame's press is re-sampled through the filter's `holding`, as the frame callback does."
3. It re-samples the press as `TouchFrame.Press(holding: clickFilter?.holding, buttonDown:)`, the same rule as the real callback.
4. It steps the recognizer and sets `blocking[id] = recognition.blocksClicks`.
5. It delivers the event through `WindowSwipeConfirmation.deliver` synchronously. A window-swipe answer is applied with `running[id]?.answerWindowSwipe(...)` before the next frame.

`scroll(_ event: ScrollEvent) -> ScrollVerdict?` (121-123) returns `scrollFilter?.decide(event, trackpadBlocking: blocking.values.contains(true))`. The result is nil when no tap is armed, meaning the event reaches apps untouched.

The hot-plug, wake and permission hooks: `attach`/`detach` (65-73) mutate `attached` and fire `.trackpadsChanged`. `sleep()` (76) marks running trackpads deaf. `wake()` (78) fires `.trackpadsChanged`. `inject(_:)` (126) delivers an event as if recognized just before a flip. `InMemoryPermissions.set(_:granted:push:)` (`InMemoryAdapters.swift:289-293`) pushes `onChange` synchronously only on a real change, or silently with `push: false`. Only a Screen Recording test uses the silent form (`WindowPreviewTests.swift:49`). `InMemoryTrackpadPreferences.set` (138-141) and `touch()` (136, a no-op notification).

### How a test asserts each verdict

- **"This press was blocked"**: `#expect(world.hardware.pressVerdicts == [.drop, .drop])`, one entry for the press and one for its release. For example `ClickBlockingTests.swift:29,37,62,71`. A passed press is `[.pass, .pass]`. No filter armed is `pressVerdicts.isEmpty` plus `!isBlockingClicks` (`ClickBlockingTests.swift:54-55`, `SwapTests.swift:69-76`, `SwitcherOnScreenTests.swift:311-312`). Gesture-side effects are asserted alongside, through `world.system.broughtToFront` and `world.hardware.feedback`.
- **"This scroll was suppressed"**: after `world.play(script)`, the test calls `#expect(world.hardware.scroll(.fingers(.began)) == .drop)` (or `.passStill`, `.pass`, or `nil` for unarmed). Several calls in a row simulate one scroll gesture's phases arriving after the frames so far (`ScrollSuppressionTests.swift:47-62, 80-96, 98-108`).
- **"Flag probe"**: `world.hardware.scroll(.unphased)` returns `.drop` iff the merged `blocksClicks` is true, since `ScrollFilter` judges `.unphased` alone on the flag with no state (`ScrollFilter.swift:34-35`). Tests use it with `playFrameByFrame(observing:)` to read the merged flag after every frame (`WindowSwipeNeedsTwoWindowsTests.swift:109-113`, `WindowSwitcherOnScreenTests.swift:286-295`).
- **"This Dock swipe passed"**: there is no World-level assertion. Dock swipe blocking is tested only as recognizer flags (`DockSwipeBlockingRecognizerTests`, `SwapRecognizerTests`, `ClickBlockingRecognizerTests.swift:26`, `EdgeContactRecognizerTests.swift:176,250,301`, `WindowSwipeRecognizerTests.swift:323-324`, `WindowSwipeAnswerTests.swift:126,170`) and as the pure filter (`DockSwipeFilterTests`). Nothing composes `blocksDockSwipes` with `DockSwipeFilter` through the model.
- **Drag and pressure**: these exist only in `ClickFilterTests` (`ClickBlockingRecognizerTests.swift:152-180`) as direct `decide(.drag/.pressure, ...)` calls. The fake never feeds drags or pressure.

### Fixtures

- **`TouchScript`** (`LauncherKit/Tests/LauncherCoreTests/TouchScript.swift`) is a value-type builder on one millisecond timeline. Frames are 10 ms apart and start at `FrameTime(seconds: 1.0)`; contacts are positioned in millimetres. Builders: `thumb(atMM:)` (lands thumb id 100, +50 ms), `tap(fingers:atMM:stagger:hold:dragMM:click:)`, `thumbTap(...)`, `land(fingers:atMM:)`, `slide(byMM:over:)`, `lift(_:)` (.all/.first/.last; ends a `press()`), `press()` (held until next lift), `rollThumb(toMM:)`, `liftThumb()` and `wait(_:)`. `ClickTiming` (`.none/.onLanding/.firm/.midway`, line 10) places the physical press in the timeline. `.onLanding` is documented as "the accepted race". The `frames` getter (210-224) emits `TouchFrame(time:touches:press:)` where `press` is `.click` for any ms inside a press range. **The only "tap event" a script can carry is the physical button state, embedded in each frame.** There is no scroll, drag, pressure or Dock event in a script.
- **`HandFrames`** (`Fixtures.swift:113-127`) is a hand-built `contact(id, phase, atMM:)` plus `frame(atMS:, touches, press:)` "for the interleavings `TouchScript` cannot sequence". It can set `press: .blocked` directly for recognizer-only tests.
- **Recognizer helpers** (`Fixtures.swift:20-86`): `fired`, `phases`, `windowPhases`, `swaps` and `perFrame` (per frame: swipe, windowSwipe, `blocksClicks`). There is also `GestureRecognizer.step(_:answering:)` (91-97), which answers a window-swipe start before the next frame as the adapters do. Defaults are `.right` hand, `.macBook14` (124.8 x 76.8 mm), `slides: [.swipe, .windowSwipe]`, `swaps: true`.
- **`World`** (`LauncherKit/Tests/LauncherCoreTests/World.swift:36-190`) is the real `Launcher` over `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `InMemoryPermissions` and `InMemoryAppScanner`, with a temp-dir catalog and settings suite. `init(apps:attached:accessGranted:screenRecording:)`. `tap(_:on:thumbAtMM:)` (167) feeds frames directly. `play(_:on:)` (173-178) delivers only frames newer than the last delivered on that trackpad, so one hand can be played in pieces with model intents or `scroll(...)` calls in between. `playFrameByFrame(_:on:observing:)` (281-290) delivers one frame at a time and runs a closure after each. Factories: `switcherWorld(...)` (209-218), `windowWorld(...)` (241-254, access granted by default), `swap(...)`, `windowSwipe(...)` and `swipe(...)`.

### Interleaving and the frame-thread / tap-thread race

- No fixture interleaves trackpad frames and tap events by timestamp. Interleaving is procedural. The test calls `play`/`playFrameByFrame` and then `scroll(...)`, so every scroll event is decided on the flag left by the last frame delivered. Press and release edges are the one exception: they are derived inside `touch()` from the frames' `press` field and decided on the previous frame's flags.
- The modelled race is deterministic and one-sided. A press edge always reaches the tap after frame N-1's flag write and before frame N's step. This is how `.onLanding` (press on the finger's landing frame passes, then cancels the tap as a click: `ClickBlockingTests.swift:108-113`) and "a thumb and a finger landing on the same frame" are represented. The fake cannot represent a tap event that arrives before the frame-thread flag write of an earlier frame, or a frame callback racing a tap callback mid-frame. Concurrency, mutex ordering and two-lock non-atomicity are not modelled.
- The window-swipe answer is synchronous in the fake: answered before the next frame. `DeviceSessionAnswerTests` (platform) covers late answers against a real `DeviceSession`.

### What `TapEventTests` covers of `ClickTap.swift`

`LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift`:
- `maskCoversPressesTheirReleasesDragsPressureScrollAndGesturesOnly` (8-11) asserts `TapEvent.tapMask` is exactly bits `[1, 2, 3, 4, 6, 7, 22, 25, 26, 27, 29, 30, 34]`.
- `everyMaskedTypeParses` (13-17) makes each type in `TapEvent.tapTypes` parse to non-nil, using a synthetic event with field 110 = 23 so 29/30 read as Dock swipes.
- It covers the press, release and drag parse with button numbers (28-41), pressure (43-46), and the ignoring of `.mouseMoved`/`.keyDown` (48-51). On gestures, it covers Dock swipe phase parsing on both 29 and 30 (61-69, phase 0 → `.changed`) and the ignoring of the non-Dock gesture HID types 0, 8, 5 and 6 (71-75).
- On scrolling, it covers line-unit → `.wheel`, the pixel-unit phase and momentum tables (83-117), and `passStill` zeroing all nine delta fields in place while keeping type, phase and continuous (125-140).
- On verdicts, it covers `pass`/`drop` for scroll, `passAsMove` → `.mouseMoved`, and `DockSwipeVerdict.apply`.
- Not covered: `ClickTap.install()`, `handle(_:_:)` (it is `fileprivate`), the `tapDisabledByTimeout`/`tapDisabledByUserInput` recovery path (`ClickTap.swift:65-71`), `remove()`, the thread and run loop, or `anyTrackpadBlocksClicks`/`anyTrackpadBlocksDockSwipes`. Nothing in the test suite references `ClickTap`, `sessions` with a tap, or `tapEnable`.

### What `SourcePolicyTests` constrains (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`)

The scan covers `LauncherKit/Sources` and `TrackpadLauncher/` (`scannedRoots`, 97-102). Matching is plain substring per line, comments included.
- **Confined to `ClickTap.swift`** (79-81): `tapCreate`, `CGEventTapCreate`, and **`scrollWheel`** ("scrolling is read only by the one event tap"). Any other file containing the substring `scrollWheel` (for example `.scrollWheel`, `scrollWheelEventIsContinuous`) fails. `tapEnable`, `CFMachPort` and `CGEventMask` are **not** confined, so they may appear elsewhere.
- **Banned everywhere** (relevant subset):
  - `"ScrollWheel"` (capital S) is banned in every file, ClickTap.swift included (line 49). `kCGEventScrollWheel` style names are therefore out, and so is any comment containing that word.
  - `.post(tap:`, `CGEventPost` and `postToPid` are banned (R9 never synthesise). Re-posting a withheld event is impossible.
  - `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`/`DisplayLink` and `Task.sleep` (30-35). No time-based gating or delayed re-arm is allowed, and the substring `Timer` is banned even in comments or identifiers.
  - `nonisolated(unsafe)` ("one writer per field").
  - `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `IOHIDRequestAccess`/`IOHIDCheckAccess` and `CGRequest`/`CGPreflightPostEventAccess`. No Input Monitoring.
  - `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged` (no keyboard).
  - All logging: `print(`, `os_log`, `Logger(`, `NSLog(`, `import os`.
- `coreImportsOnlyFoundationAndObservation` (152-156): LauncherCore may import only `Foundation` and `Observation`. Any gate logic placed in LauncherCore cannot import CoreGraphics or Synchronization.

### What a test can drive for real today, and what has no seam

Real and drivable:
- The arming decision: `Launcher.reconcile` → `run(blockClicks:)`, observed as `InMemoryTrackpads.isBlockingClicks`, `running`, and `runCount`.
- The recognizer flags (`blocksClicks` per frame via the fake and directly; `blocksDockSwipes` directly only).
- `ClickFilter` and `ScrollFilter` composed with the model and the merged flag, inside the fake.
- `DockSwipeFilter` alone.
- `TouchFrame.Press` sampling.
- `DeviceSession.blocksClicks` (platform, `clickTap: nil`).
- CGEvent parsing and rewriting.

No seam:
- Nothing observes "the tap is enabled right now" or "the tap is installed". The fake's `isBlockingClicks` means "a filter is armed", and the real `ClickTap` has no query. The port has no method for it.
- Nothing models tap-disabled-by-timeout or user input, or `forgetHeldPresses`/`forgetGesture`/`forgetSwipe` reached via the tap (these are tested only as direct filter calls: `ClickBlockingRecognizerTests.swift:182-194`, `ScrollFilterTests.swift:47-57`, `DockSwipeFilterTests.swift:31-36`).
- Nothing models the system refusing the tap (`ClickTap.install()` returning nil while the model believes it armed blocking).
- Nothing tests Dock swipe blocking end to end through the model, and nothing feeds drags or pressure through the fake.
- No time-ordered mixed script of frames plus scroll, Dock and pointer events exists.
- No multi-button presses exist in the fake (always button 0).

## Boundaries

- The model is the input side. Arming happens only through `TrackpadHardware.run(_:handMode:blockClicks:slides:swaps:)`, on the main actor.
- The adapter is the output side: `ClickTap` lifetime equals the span between two `run`s. The frame thread writes `DeviceSession.blocking` and `blockingDockSwipes`. The tap thread reads the merged OR via `sessions`. The frame thread reads `ClickTap.holding` back.
- Recognized events reach the model through `onEvent` on main, and the window-swipe answer goes back to the frame thread via the reply. Blocking flags never pass through the main actor or the model.
- The behavioural fake reimplements the adapter's tap half (filters and merged flag) but not the platform threads.

## Non-Obvious Things

1. **There is no separate arming API.** Every arm and disarm is a full `run`: devices stopped and restarted, recognizers replaced, `ClickTap` removed and re-created with fresh filters, and `shown = nil`. Hand mode and each setting change therefore also re-install the tap and wipe filter state, including a withheld press (its release then passes as a "harmless stray mouse-up", `MultitouchTrackpads.swift:72`) and a dropped or stilled scroll gesture in flight. A gate design must keep or explicitly accept this "a run resets everything" behaviour to stay R2/R4-identical.
2. **The `Run` equality guard** (`Launcher.swift:197-231`) means no-op preference and TCC notifications don't touch the tap (tested: `SwitcherOnScreenTests.swift:228-232` `preferences.touch()`; `WindowPreviewTests.swift:27-33` Screen Recording grant; `SwitcherAssignedAppsTests.swift:114-119`). Wake and hot-plug bypass the guard with `restart: true`.
3. **The window swipe toggle without Accessibility is a no-op for `run`**, because `.windowSwipe` is stripped from `slides` when not granted.
4. **`isAccessibilityGranted` is not part of `activity`.** `AccessibilityTests` asserts that a grant or revoke never changes `activity`, and it asserts nothing about blocking. The blocking-on-grant and revoke assertions live in `ClickBlockingTests.swift:66-72, 131-146`.
5. **`pressVerdicts` is cumulative across runs.** In `blockingFollowsTheGrantAndTheRevokeWithoutRelaunching` (`ClickBlockingTests.swift:131-146`), the final `== [.drop, .drop]` after the revoke means "no new verdicts were recorded", because there is no filter, not "dropped again".
6. **The fake's press model diverges across a `run`.** `run` resets `buttonWasDown = false` and `pressInProgress = nil`. A physical press held across a run (scripted `press` still true on frames after it) would be fed as a **new** press edge to the new filter, and its eventual release would be recorded against that new press. In reality no new mouse-down arrives, and the new tap sees only a release with no held press, which passes. I found no test exercising this, but a gating model that adds runs mid-press would hit it.
7. **The fake models only `blocksClicks`.** `InMemoryTrackpads` doesn't store `blocksDockSwipes`, and has no `DockSwipeFilter`, no drag or pressure events, and no tap-disable events. "The behavioural suite must also hold with the tap's gating modelled" therefore currently means the gating can be observed only through `pressVerdicts`, `scroll(...)` (incl. the `.unphased` flag probe) and `isBlockingClicks`.
8. **Scroll uses the click flag, not a scroll-specific one.** Both real (`ClickTap.swift:79-80`) and fake (`InMemoryAdapters.swift:122`) pass the merged `blocksClicks` to `ScrollFilter`. Dock swipes alone use `blocksDockSwipes`, which can stay true long after `blocksClicks` expires: thumb anchored plus another finger, no time limit (`SwapRecognizerTests.swift:29-42`, `ClickBlockingRecognizerTests.swift:12-29`).
9. **`blocksClicks` expiry is seen only on a frame** (`ClickBlockingRecognizerTests.swift:40-48`). The flag left by the last frame persists until the next frame. After the last lift the `[]` frame clears it, and after that the pad sends no frames. Any gating decision made off the frame thread inherits this.
10. **Filter state that outlives the flag (relevant to R3)**:
    - `ClickFilter` keeps `.withheld` until the release, and drags and pressure follow it.
    - `ScrollFilter` keeps `.touching(t)` or `.coasting(t)`. `.coasting` persists after `.ended` until `momentum(.ended)` or the next fingers event, so a dropped gesture's momentum stays dropped even with the flag false (`ScrollSuppressionTests.swift:80-96`).
    - `DockSwipeFilter` keeps `current` until `.ended`/`.cancelled`.
    - Filters are fed only events they receive, so a gated-off tap that misses an `.ended` would leave state stale. The existing recovery for "events passed unseen" is the forget-on-timeout path, which under-blocks.
11. **The real adapter reads `ClickTap.holding` into every frame's `Press`.** If a gate stops delivering pressure, drags or presses to the tap, that changes only the tap side. Presses (types 1-4, 25, 26) are not in the plan's high-volume list and would keep the `holding` input intact.
12. **`ClickTap.install()` can return nil silently.** The model and the fake both assume that arming means filtering. The fake has no "refused" mode.
13. **The architecture doc claim** "sleeps until an event arrives" is in `docs/architecture.md:20`, the line R5 targets. The source-scan test is described at `docs/architecture.md:25` as confining "the event tap and the scroll-event API" to one file.
14. **Possible framing gap.** The question speaks of "how the model arms and disarms click blocking across … hand-mode and settings changes" as if there were separate arm and disarm actions. Hand mode and settings never change `blockClicks`. They only force a re-run, which happens to re-install the tap. Only Accessibility, connected trackpads and conflicting preferences change the arming predicate.

## Open Questions

- I did not read `GestureRecognizer.swift` in full (only 1-60 and 150-210) or `EdgeContactRecognizerTests`/`WindowSwipeAnswerTests` in full. Other explorers cover the recognizer's states.
- I could not confirm whether macOS stops delivering to an existing tap after an Accessibility revoke that arrives without a TCC broadcast. No test models a silent Accessibility revoke (`push: false` is used only for Screen Recording).
- I did not verify whether any test plays a scripted press that is still held across a `run`, which is divergence 6 above. A grep showed no obvious case, but I did not check every World test.

## Files Read

- `LauncherKit/Sources/LauncherCore/Launcher.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Activity.swift`
- `LauncherKit/Sources/LauncherCore/Settings.swift` (1-40)
- `LauncherKit/Sources/LauncherCore/GestureRules.swift`
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (1-60, 150-210)
- `LauncherKit/Sources/LauncherCore/Touch.swift` (45-95)
- `LauncherKit/Sources/LauncherCore/ClickFilter.swift` (1-80)
- `LauncherKit/Sources/LauncherCore/ScrollFilter.swift`
- `LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift`
- `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift`
- `LauncherKit/Sources/LauncherPlatform/ClickTap.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift`
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`
- `LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift`
- `LauncherKit/Sources/LauncherPlatform/SystemTrackpadPreferences.swift`
- `LauncherKit/Package.swift`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `LauncherKit/Tests/LauncherCoreTests/World.swift`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`
- `LauncherKit/Tests/LauncherCoreTests/TouchScript.swift`
- `LauncherKit/Tests/LauncherCoreTests/Fixtures.swift`
- `LauncherKit/Tests/LauncherCoreTests/ClickBlockingTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/ClickBlockingRecognizerTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/ScrollSuppressionTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/ScrollFilterTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/DockSwipeFilterTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/DockSwipeBlockingRecognizerTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/WindowSwipeBlockingTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwapRecognizerTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/AccessibilityTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift`
- Partial: `SwapTests.swift` (50-80, 240-336), `SwitcherOnScreenTests.swift` (220-235, 295-362), `SwipeSettingTests.swift` (35-76), `SwitcherAssignedAppsTests.swift` (105-135), `LauncherTests.swift` (195-232), `ActivityTests.swift` (1-70), `WindowSwipeNeedsTwoWindowsTests.swift` (75-130, 175-195), `WindowSwitcherOnScreenTests.swift` (270-312), `WindowPreviewTests.swift` (15-40), `WindowSwipeAnswerTests.swift` (115-130), `LauncherPlatformTests/DeviceSessionAnswerTests.swift` (55-128)
- `docs/architecture.md` (grep for "tap": lines 18, 20, 25)
- `plans/014-gate-event-tap/plan.md` (1-49, for context)
