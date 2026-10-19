# Grounding: the click tap's lifecycle (angle: tap-lifecycle)

Repo root: /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/014-gate-event-tap (all paths below relative to it). Code as of `9557bc2`.

## Components Found

| Name | File:line | What it is |
|---|---|---|
| `ClickTap` (`final class ClickTap: Sendable`) | LauncherKit/Sources/LauncherPlatform/ClickTap.swift:12-89 | The app's one event tap: owns the CFMachPort, its run-loop thread, and the three filters behind Mutexes. Internal (not public) to LauncherPlatform. |
| `ClickTap.install() -> ClickTap?` (`@MainActor static`) | ClickTap.swift:25-46 | Creates the tap and its thread; returns nil when `CGEvent.tapCreate` fails (no Accessibility). |
| `ClickTap.remove()` (`@MainActor`) | ClickTap.swift:52-61 | Idempotent teardown: disable, invalidate port, stop run loop. |
| `ClickTap.holding: ClickFilter.Holding` | ClickTap.swift:49 | Frame-thread read of the click filter's summary. |
| `ClickTap.handle(_:_:) -> Unmanaged<CGEvent>?` (fileprivate) | ClickTap.swift:64-88 | The per-event callback body, tap thread. |
| `clickTapCallback: CGEventTapCallBack` (private global) | ClickTap.swift:97-100 | C callback; recovers the ClickTap from `userInfo` with `takeUnretainedValue()`. |
| `Unchecked<Value>: @unchecked Sendable` | ClickTap.swift:92-95 | Wrapper making CFMachPort / CFRunLoop storable in a Mutex. |
| `TapEvent` enum (`.pointer`, `.scroll`, `.dockSwipe`) | ClickTap.swift:103-134 | Parsed vocabulary; `tapTypes` list builds `tapMask`. |
| `DockSwipeFields` enum | ClickTap.swift:137-148 | Undocumented numbers: types 29/30, field 110 (HID type), value 23 (Dock swipe), field 132 (phase). |
| `DockSwipePhase.init?(CGEvent)`, `PointerEvent.init?(CGEventType, CGEvent)`, `ScrollEvent.init(CGEvent)` | ClickTap.swift:150-211 | CGEvent -> LauncherCore domain-type parsers (platform-side extensions on core types). |
| `PointerVerdict.apply(to:)`, `DockSwipeVerdict.apply(to:)`, `ScrollVerdict.apply(to:)` | ClickTap.swift:213-251 | Verdict -> callback return (nil / same event / mutated event). |
| `ClickFilter` | LauncherKit/Sources/LauncherCore/ClickFilter.swift:35-82 | Pure press state machine; `held: [Int: Held]` keyed by button. |
| `ScrollFilter` | LauncherKit/Sources/LauncherCore/ScrollFilter.swift:27-82 | Pure scroll-gesture state machine; `stage: Stage?`. |
| `DockSwipeFilter` | LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift:13-34 | Pure Dock-swipe state machine; `current: DockSwipeVerdict?`. |
| `DeviceSession` | LauncherKit/Sources/LauncherPlatform/FrameStream.swift:14-79 | One running trackpad: recognizer + the two blocking flags (Mutex<Bool>) the tap reads + a strong ref to the ClickTap. |
| `sessions` (global `Mutex<[UInt: DeviceSession]>`) | FrameStream.swift:84 | Registry keyed by device ref bit pattern; shared main / frame thread / tap thread. |
| `contactFrameCallback` | FrameStream.swift:86-91 | MultitouchSupport frame callback (frame thread): samples press via `session.holding` + `anyMouseButtonDown()`, then `session.receive`. |
| `anyTrackpadBlocksClicks()`, `anyTrackpadBlocksDockSwipes()` | FrameStream.swift:100-108 | Tap-thread reads: copy `sessions.values` out under the lock, then OR each session's flag. |
| `anyMouseButtonDown()` | FrameStream.swift:94-96 | `CGEventSource.buttonState(.combinedSessionState, ...)` for left/right/center. |
| `MultitouchTrackpads` (`@MainActor public final class`, `TrackpadHardware`) | LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:10-169 | The adapter: `run(...)` removes and re-installs the tap; holds `private var clickTap: ClickTap?` (line 17). |
| `TrackpadHardware.run(_:handMode:blockClicks:slides:swaps:)` | LauncherKit/Sources/LauncherCore/Ports.swift:26-46 (run at :40, doc :35-39) | The port the tap sits behind. There is no tap-specific port; the tap is a side effect of `run`. |
| `Launcher.reconcile(restart:)` + `Run` struct | LauncherKit/Sources/LauncherCore/Launcher.swift:197-231 | Sole caller of `hardware.run`; computes `blockClicks: active && granted`. |
| `TouchFrame.Press.init?(holding:buttonDown:)` | LauncherKit/Sources/LauncherCore/Touch.swift:61-83 | Precedence rule turning the filter's `holding` + button state into what the recognizer sees. |
| `Recognition.blocksClicks` / `.blocksDockSwipes` | LauncherKit/Sources/LauncherCore/GestureRecognizer.swift:4-38, produced at :182-200 | Per-frame flags written into DeviceSession. |
| `InMemoryTrackpads` | LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:5-127 | Test fake: real recognizer, real ClickFilter + ScrollFilter, armed iff `blockClicks && !trackpads.isEmpty`. |
| `TapEventTests` | LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift | Mask bits, parse-every-masked-type, parsers, verdict application on real CGEvents. |
| `SourcePolicyTests.confined` | LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:79-81 | `tapCreate`, `CGEventTapCreate`, `scrollWheel` tokens may appear only in ClickTap.swift. |
| Composition root | TrackpadLauncher/TrackpadLauncherApp.swift:12-21 | `Launcher(hardware: MultitouchTrackpads(), permissions: SystemPermissions(), ...)`, then `launcher.start()`. |

## The tap's creation (ClickTap.swift:25-46)

```swift
CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
    eventsOfInterest: TapEvent.tapMask, callback: clickTapCallback,
    userInfo: Unmanaged.passUnretained(tap).toOpaque())
```

- Location `.cgSessionEventTap` (login-session level, so every pointing device and app in the session), placement `.headInsertEventTap` (ahead of other session taps), options `.defaultTap` (an active, filtering tap: can drop/modify; that is what makes every event a synchronous round trip through this process, unlike `.listenOnly`).
- `userInfo` is unretained; lifetime is guaranteed by the thread's closure capturing `[tap]` (see below) and by every `DeviceSession.clickTap` strong ref.
- Failure (`nil` mach port) -> `install` returns nil. The doc comment (line 24) says this means no Accessibility. `MultitouchTrackpads.clickTap` stays nil; `DeviceSession.holding` becomes nil (FrameStream.swift:72), and `TouchFrame.Press` falls back to button state alone.

### The exact mask (ClickTap.swift:115-120; asserted in TapEventTests.swift:8-11 as bits `[1, 2, 3, 4, 6, 7, 22, 25, 26, 27, 29, 30, 34]`)

| Raw | CGEventType | Parsed as | Purpose | Volume |
|---|---|---|---|---|
| 1 | leftMouseDown | `.pointer(.press(PressID(button: 0, number)))` | withhold a press inside the window | rare |
| 2 | leftMouseUp | `.pointer(.release(...button 0))` | withhold the release of a withheld press | rare |
| 3 | rightMouseDown | `.press(button 1)` | same | rare |
| 4 | rightMouseUp | `.release(button 1)` | same | rare |
| 6 | leftMouseDragged | `.pointer(.drag(button: 0))` | rewrite to `.mouseMoved` while that button's press is withheld | high while a button is held |
| 7 | rightMouseDragged | `.drag(button: 1)` | same | high while held |
| 22 | scrollWheel | `.scroll(ScrollEvent)` | drop / still trackpad and Magic Mouse scrolling | frame-rate while two fingers move, plus momentum |
| 25 | otherMouseDown | `.press(button: mouseEventButtonNumber)` | as left/right | rare |
| 26 | otherMouseUp | `.release(button: mouseEventButtonNumber)` | as left/right | rare |
| 27 | otherMouseDragged | `.drag(button: mouseEventButtonNumber)` | as left/right | high while held |
| 29 | (no public case) NSEventTypeGesture, `DockSwipeFields.gestureType` | `.dockSwipe(phase)` only if field 110 == 23, else nil (passes) | block the system's desktop / Mission Control / App Expose swipes | frame-rate whenever fingers touch (every gesture event: pinch, rotate, app swipes...) |
| 30 | (no public case) Dock control, `DockSwipeFields.dockControlType` | same parse as 29 | a Dock swipe may arrive as either | during system gestures |
| 34 | (no public case) NSEventTypePressure | `.pointer(.pressure)` | drop Force Click stages of a withheld press (stops Look up) | high during a press |

Not in the mask: `mouseMoved` (5), keyboard, tablet types. `tapDisabledByTimeout` (raw 0xFFFFFFFE) and `tapDisabledByUserInput` (0xFFFFFFFF) are not mask bits; the system always delivers them to the callback.

The mask is a single static value fixed at creation. Nothing in the code changes it; CoreGraphics offers no API to change an existing tap's mask (only enable/disable the whole tap via `CGEvent.tapEnable`).

### The thread (ClickTap.swift:34-44)

- `Thread { [tap] in ... }`, `name = "ClickTap"`, `qualityOfService = .userInteractive`, started immediately.
- Inside the thread: `CFRunLoopGetCurrent()`; reads the port under `port` lock and creates `CFMachPortCreateRunLoopSource(nil, port, 0)`; `CFRunLoopAddSource(loop, source, .commonModes)`; stores the loop into `runLoop` Mutex; `CFRunLoopRun()`.
- If `remove()` already ran (port nil), no source is added and `CFRunLoopRun()` returns at once (comment line 39).
- The thread's closure retains the ClickTap until `CFRunLoopRun` returns.
- Rationale (plan 002 plan.md:378, :1145): not the main run loop, because every click in the session waits on the callback and main may be stuck in a WindowServer call -> stall until timeout.

## The callback (`handle`, ClickTap.swift:64-88) - tap thread

1. `clickTapCallback` (97-100): if `userInfo` nil, pass. Else `handle(type, event)`.
2. Disabled types (65-72): see next section.
3. `TapEvent(type, event)` (122-133). Order: `scrollWheel` first -> `.scroll`; then raw 29/30 -> `DockSwipePhase(event)` or nil; then `PointerEvent(type, event)`; else nil. A nil parse returns `.passUnretained(event)` BEFORE any flag is read (so non-Dock gesture events on 29 are cheap in-process; their cost is SkyLight's round trip).
4. `let blocking = anyTrackpadBlocksClicks()` (75) - read for every parsed event, including drags, pressure, releases and Dock swipes even though those cases ignore it. Comment: "Read once, before either filter lock, so no two locks are held at once."
5. Dispatch:
   - `.pointer` -> `filter.withLock { $0.decide(pointer, trackpadBlocking: blocking) }.apply(to: event)`.
   - `.scroll` -> `scrollFilter.withLock { $0.decide(scroll, trackpadBlocking: blocking) }.apply(to: event)`.
   - `.dockSwipe(phase)` -> reads a second flag `anyTrackpadBlocksDockSwipes()` (83), then `dockSwipeFilters.withLock { $0[type.rawValue, default: DockSwipeFilter()].decide(phase, trackpadBlocking: blockingDockSwipes) }.apply(to: event)`. One filter per raw type (29 and 30 separately), created lazily.

### Field reads (parsers)

- PointerEvent (165-185): `mouseEventNumber` (press/release pairing id), `mouseEventButtonNumber` (only used for `other*` types; left=0, right=1 come from the type). Raw 34 -> `.pressure` (no fields read).
- ScrollEvent (187-211): `scrollWheelEventIsContinuous == 0` -> `.wheel` (line-unit, never suppressed). Else `scrollWheelEventScrollPhase` (128 mayBegin, 1 began, 2 changed, 4 ended, 8 cancelled) takes precedence; with phase 0, `scrollWheelEventMomentumPhase` (1 began, 2 changed, 3 ended); (0,0) or unknown -> `.unphased`.
- DockSwipePhase (150-163): field 110 must equal 23 (kIOHIDEventTypeDockSwipe) else nil; field 132: 128 mayBegin, 1 began, 4 ended, 8 cancelled, anything else (incl. 2, 0) -> `.changed`.

### Return values

- `nil` = withheld: `PointerVerdict.drop`, `ScrollVerdict.drop`, `DockSwipeVerdict.drop`.
- Same event mutated and returned: `PointerVerdict.passAsMove` sets `event.type = .mouseMoved` (220); `ScrollVerdict.passStill` zeroes `scrollWheelEventDeltaAxis1/2/3` (integer) and `FixedPtDeltaAxis1/2/3`, `PointDeltaAxis1/2/3` (double) in place (237-248). Phases and continuity untouched (TapEventTests.swift:125-140).
- `.passUnretained(event)` unchanged: every `.pass`, every unparsed event, and the disabled notifications.
- Nothing is ever posted or synthesised.

### What crosses into core

Only `PointerEvent`, `ScrollEvent`, `DockSwipePhase` (LauncherCore enums, no CoreGraphics) plus a Bool flag. The filters are pure and clock-free.

## tapDisabledByTimeout / tapDisabledByUserInput (ClickTap.swift:65-72) - tap thread

```swift
filter.withLock { $0.forgetHeldPresses() }          // held = [:]
scrollFilter.withLock { $0.forgetGesture() }        // stage = nil
dockSwipeFilters.withLock { $0 = [:] }              // drops both per-type filters (forgetSwipe() is not called)
port.withLock { $0.map { CGEvent.tapEnable(tap: $0.value, enable: true) } }
return .passUnretained(event)
```

- Re-enables unconditionally if `port` is non-nil. After `remove()` the port is nil, so a late disabled notification cannot revive a removed tap. But there is no notion of "the tap is intentionally disabled" - any gating design that disables the same tap with `tapEnable(false)` would be re-enabled here on the next timeout notification (R4 of plan 014 calls this out). (Note: macOS sends these only when the system disabled the tap, not when the app did.)
- Forgetting is deliberately under-blocking: a release, scroll end or Dock swipe end may have passed unseen while disabled.

## install / remove / teardown and the shared state

### Mutexes on ClickTap (ClickTap.swift:13-22)

| Field | Type | Writer | Reader |
|---|---|---|---|
| `filter` | `Mutex(ClickFilter())` | tap thread (`decide`, `forgetHeldPresses`) | frame threads via `holding` (49), through `DeviceSession.holding` (FrameStream.swift:72) in `contactFrameCallback` (:88) |
| `scrollFilter` | `Mutex(ScrollFilter())` | tap thread | tap thread |
| `dockSwipeFilters` | `Mutex<[UInt32: DockSwipeFilter]>` | tap thread | tap thread |
| `port` | `Mutex<Unchecked<CFMachPort>?>` | main (install line 33, remove line 58) | tap thread (thread start line 36; re-enable line 70) |
| `runLoop` | `Mutex<Unchecked<CFRunLoop>?>` | tap thread (line 38) | main (`remove`, line 60) |

### Mutexes outside ClickTap that the tap reads

| Field | File:line | Writer | Reader |
|---|---|---|---|
| `sessions` global | FrameStream.swift:84 | main (`MultitouchTrackpads.run`: emptied at :71, filled at :111) | frame callback (lookup, :87), tap thread (`anyTrackpadBlocks*`, :100-108) |
| `DeviceSession.blocking` | FrameStream.swift:20 | frame thread (`receive`, :58) every frame, = `recognition.blocksClicks` | tap thread (`blocksClicks`, :75) |
| `DeviceSession.blockingDockSwipes` | FrameStream.swift:22 | frame thread (:59) every frame | tap thread (:78) |

Lock discipline: no two locks are held at once anywhere on the tap path (`anyTrackpadBlocks*` copies `sessions.values` into an Array before reading each session's flag; the flag is read before taking a filter lock). The frame thread takes sessions -> (released) -> filter (via holding) -> (released) -> recognizer -> blocking -> blockingDockSwipes, sequentially.

### remove() (ClickTap.swift:52-61) - main

Under the `port` lock: `CGEvent.tapEnable(tap: port, enable: false)`, `CFMachPortInvalidate(port)`, set nil. Then `CFRunLoopStop` on the stored loop if any. Comment: "Idempotent. Never relies on macOS to stop delivery after a revoke." `CFRunLoopRun` returns, the thread ends, and releases its retain on the tap. There is no `deinit` on ClickTap. Old `DeviceSession`s also retain the old tap, but `run` drops them from `sessions` first.

Small race worth knowing: if `remove()` runs after the thread created/added its source but before it stored `runLoop`, `CFRunLoopStop` is skipped; the invalidated port's source is removed from the loop, so `CFRunLoopRun` with no sources returns anyway. Not explicitly commented beyond line 39.

### Does anything enable/disable the tap from the frame thread today?

No. `grep tapEnable` hits only ClickTap.swift:55 (main, disable in remove) and :70 (tap thread, re-enable after system disable). Plan 002 made this an explicit acceptance check (plan 002 plan.md, "No enabling or disabling of the tap from the frame thread", and S4's checklist "grep -rn tapEnable LauncherKit/Sources hits ClickTap.swift only (nothing on the frame thread enables or disables the tap)").

## Who drives it

### Adapter: MultitouchTrackpads.run (MultitouchTrackpads.swift:66-116) - main

Signature: `public func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, slides: Set<SlideKind>, swaps: Bool)`.

Order:
1. `runs += 1`; `guard let framework` (no MultitouchSupport -> nothing, and the tap is NOT removed in that case - but then it was never installed).
2. `sessions.withLock { $0 = [:] }` - in-flight frames find nothing; tap's `anyTrackpadBlocks*` now returns false.
3. `clickTap?.remove(); clickTap = nil` (73-74). Comment: "A withheld press's release may now reach apps: a harmless stray mouse-up."
4. Unregister callbacks / stop every started device; close actuators.
5. `devices = listTrackpads().filter { wanted.contains(...) }`.
6. `if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }` (87) - the tap is installed BEFORE the new sessions are registered, so its first events see an empty `sessions` (flags false -> pass).
7. Per device: new `DeviceSession(..., clickTap: clickTap, ...)` with a fresh `GestureRecognizer` (flags start false), register into `sessions`, register frame callback, start device.

Doc (66-67): "A click tap exists afterwards iff `blockClicks`, the system allows it and a trackpad is running." Every `run` creates a brand-new ClickTap with fresh filters even when `blockClicks` did not change (hand mode, swipe/window-swipe/swap settings, hot-plug, wake all recreate it).

### Port contract (Ports.swift:35-40)

"Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent. The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before..."

### Model: Launcher.reconcile(restart:) (Launcher.swift:211-231) - main

```swift
let granted = permissions.isGranted(.accessibility)
let active = activity.isActive
let run = Run(
    trackpads: active ? connected : [], handMode: settings.handMode, blockClicks: active && granted,
    slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe]), swaps: settings.isSwapOn)
guard restart || run != lastRun else { return }
lastRun = run
shown = nil
hardware.run(...)
```

Arming predicate, end to end: tap exists iff `activity.isActive` (>= 1 trackpad connected AND no `ConflictingSetting` - Tap to click `Clicking == 1` or Look up three-finger tap `TrackpadThreeFingerTapGesture == 2` - on any connected kind; Activity.swift:59-71) AND `permissions.isGranted(.accessibility)` (AXIsProcessTrusted) AND at least one of the requested trackpads is actually listed by MultitouchSupport AND `CGEvent.tapCreate` succeeds. Note `active` false -> `trackpads: []` so devices stop too; `granted` false -> devices run, no tap.

One flag arms all three blockings (click, scroll, Dock swipe): there is no separate setting for scroll or Dock swipe blocking; the swipe / window swipe / swap settings only change `slides` / `swaps`, which re-runs (and recreates the tap) but never disarms it.

Triggers of `reconcile` (Launcher.swift):
- `start()` (101) at launch.
- `.trackpadsChanged` -> `reconcile(restart: true)` (94): IOKit first-match/terminated for `AppleMultitouchDevice` (MultitouchTrackpads.swift:31-47) and `NSWorkspace.didWakeNotification` (:48-52). `restart: true` forces a run (and so a new tap) even if `Run` is equal.
- `preferences.onChange` (99): cfprefs change in either trackpad domain.
- `permissions.onChange` (100): SystemPermissions re-reads AX and screen-capture on tccd's `com.apple.tcc.access.changed` Darwin notification and calls onChange only when either grant changed (SystemPermissions.swift:22-24, 51-56). A Screen Recording-only change calls reconcile but `Run` is unchanged (Screen Recording is not in `Run`), so no re-run.
- `setHandMode`, `setSwipe`, `setWindowSwipe`, `setSwap` (134-171). `setLaunchAnimation`, `setAssignment` do not reconcile.

Revoke path: AX revoke -> TCC push -> reconcile -> `blockClicks` false -> `run` -> `remove()` (not relying on macOS to stop delivery).

### Composition root

TrackpadLauncher/TrackpadLauncherApp.swift:12-21: `MultitouchTrackpads()` and `SystemPermissions()` injected into `Launcher`; `launcher.start()` before `application.run()`. Nothing in the app target touches the tap directly.

## How the recognizer's flags reach the tap

- Produced: `GestureRecognizer.step` (GestureRecognizer.swift:182-200). Confirmed swipe/window swipe, or a swap series rest -> both true. Otherwise `blocksDockSwipes` = a thumb anchored and another contact down (no time limit); `blocksClicks` = same but only while the thumb landed < `GestureRules.clickBlockingWindow` (3 s, GestureRules.swift:23) ago.
- Written: `DeviceSession.receive` (FrameStream.swift:46-69), on the device's frame thread, every frame: `blocking = recognition.blocksClicks`, `blockingDockSwipes = recognition.blocksDockSwipes` (58-59). Unconditional per-frame lock+write.
- Read: tap thread, per event, `anyTrackpadBlocksClicks()` / `anyTrackpadBlocksDockSwipes()` merge across sessions at read time.
- Back-channel the other way: `contactFrameCallback` builds `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())` (FrameStream.swift:88). `holding` reads `ClickTap.filter` (frame thread reads tap-thread-owned state).

## Behavioural tests' model of the tap (InMemoryAdapters.swift:5-127)

- `run` (47-59): fresh recognizers, `blocking = [:]`, `clickFilter = blockClicks && !trackpads.isEmpty ? ClickFilter() : nil`, `scrollFilter = clickFilter == nil ? nil : ScrollFilter()`. `isBlockingClicks` = `clickFilter != nil`. Mirrors "fresh tap per run" and the arming predicate (minus tapCreate failure).
- `touch(_:on:)` (84-101): for each scripted frame, `deliverPressEdge(buttonDown: frame.press != nil)` decides a press or release on the flags the PREVIOUS frame left (`blocking.values.contains(true)`), modelling that a press edge reaches the tap between frames; then re-samples `TouchFrame.Press(holding: clickFilter?.holding, buttonDown:)`, steps the recognizer, stores `blocking[id] = recognition.blocksClicks`.
- Presses are always button 0 with incrementing `PressID.number`; verdicts recorded in `pressVerdicts`.
- `scroll(_:) -> ScrollVerdict?` (121-123): decides on current merged flags; nil when unarmed (= reaches apps untouched).
- NOT modelled in the fake: drags, pressure, the `DockSwipeFilter` and `blocksDockSwipes` (no Dock swipe API at all), tapDisabled recovery, tapCreate failure, cross-thread timing beyond "previous frame's flags". Dock swipe behaviour is tested only as pure `DockSwipeFilterTests` plus recognizer-level `DockSwipeBlockingRecognizerTests`; `forgetHeldPresses`/`forgetGesture`/`forgetSwipe` only as pure filter tests (ClickBlockingRecognizerTests.swift:185-192, ScrollFilterTests.swift:50-55, DockSwipeFilterTests.swift:34).
- Arming tests: ClickBlockingTests.swift:115-146 (`blockingIsArmedOnlyWhileGesturesAreActiveAndAccessIsGranted`, `blockingFollowsTheGrantAndTheRevokeWithoutRelaunching`), :148 (reconcile under a resting thumb).
- Platform tests: TapEventTests.swift (mask bits, every masked type parses, parsers, verdict application). DeviceSession tests construct sessions with `clickTap: nil` (DeviceSessionAnswerTests.swift:24, DeviceSessionTravelTests.swift:22). Nothing exercises a real `ClickTap.install()` in tests.

## Performance characteristics documented

- docs/architecture.md:20: "The one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives (a press, its drags and pressure, a scroll event, or a system gesture event)." Plan 014 points out this is no longer true while fingers touch.
- ClickTap.swift:74 lock comment; FrameStream.swift:98-108 "Copies the sessions out first, so no lock is held while another is taken" (allocates an Array per parsed event).
- plans/014-gate-event-tap/plan.md: 84% of CPU in SkyLight event-tap machinery on the ClickTap thread; `handle` itself about 1%.
- plan 002 plan.md:1258 hardware check: thread count +1 on grant, -1 on revoke; 0.0% idle CPU with the tap.

## Files Read

- LauncherKit/Sources/LauncherPlatform/ClickTap.swift
- LauncherKit/Sources/LauncherPlatform/FrameStream.swift
- LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift
- LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift
- LauncherKit/Sources/LauncherCore/Ports.swift (lines 1-80)
- LauncherKit/Sources/LauncherCore/Launcher.swift (lines 1-330)
- LauncherKit/Sources/LauncherCore/ClickFilter.swift
- LauncherKit/Sources/LauncherCore/ScrollFilter.swift
- LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift
- LauncherKit/Sources/LauncherCore/Activity.swift
- LauncherKit/Sources/LauncherCore/Touch.swift (lines 45-95)
- LauncherKit/Sources/LauncherCore/GestureRecognizer.swift (lines 1-45, 170-205)
- TrackpadLauncher/TrackpadLauncherApp.swift
- LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift
- LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift
- LauncherKit/Tests/LauncherCoreTests/ClickBlockingTests.swift (lines 110-165)
- LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift (lines 60-100)
- docs/architecture.md (grep hits, lines 18-25)
- plans/014-gate-event-tap/plan.md (first 80 lines)
- plans/002-gesture-click-blocking/plan.md (lines 378, 425-450, 1145, 1184, 1258, 1305-1330)

## Boundaries

- In: CGEvents from the WindowServer session (all devices, not just trackpads: a mouse wheel, Magic Mouse scroll, external mouse clicks all hit the tap); per-session Bool flags written by frame threads; `install`/`remove` from main via `MultitouchTrackpads.run`.
- Out: the callback's return (drop / rewrite / pass) to the WindowServer; `ClickFilter.holding` to frame threads (feeds `TouchFrame.Press`, which decides whether a press cancels a tap or counts as part of it).
- Core types crossing: `PointerEvent`, `ScrollEvent`, `DockSwipePhase`, verdict enums, `ClickFilter.Holding`. LauncherCore never sees CoreGraphics.
- Source policy: `tapCreate`, `CGEventTapCreate`, `scrollWheel` confined to ClickTap.swift (SourcePolicyTests.swift:79-81) - a second tap in another file, or naming `scrollWheel` elsewhere, fails the test.

## Non-Obvious Things

1. The tap is recreated on every `run`, not only on arm/disarm: hand mode, any of the swipe / window swipe / swap settings, every hot-plug and every wake build a new ClickTap with fresh filters. Filter state never survives a run; anything withheld in flight at that moment is abandoned (stray mouse-up accepted).
2. `blockClicks` arms scroll suppression and Dock swipe blocking too; the name is historical (plan 002 had only presses/drags/pressure; scroll and types 29/30 were added in plan 006).
3. The new tap is installed before the new sessions are registered, so the window between `install` and registration sees all flags false.
4. `ClickFilter` is stateful in a way that matters even when nothing blocks: every passed press is recorded as `.passed` until its release, and `holding` (.passed) makes the frame see `.click` while the button is down. If the tap is live but `holding` reads `.nothing` because the press never reached the filter, `TouchFrame.Press.init` returns nil even with the button down (Touch.swift:76-77) - a press would stop cancelling taps. Presses/releases (1-4, 25, 26) therefore must keep reaching the filter; plan 014 only targets 6/7/27/34/22/29/30, which is consistent.
5. Drags and pressure ignore the recognizer flag entirely: they depend only on whether a press is withheld (`held[button] == .withheld` / `holding == .withheld`). So "a recognizer may need to block" is not sufficient for gating drags/pressure: a press withheld while blocking stays withheld until its release, after the flag has gone false, and its drags must still become moves and its pressure must still drop.
6. `ScrollFilter` and `DockSwipeFilter` carry a verdict through a gesture regardless of the flag ("never relaxes", momentum inherits). A dropped/stilled scroll gesture continues to be dropped/stilled through its end and momentum after the recognizer stops blocking; a dropped Dock swipe stays dropped until ended/cancelled. Gating these off mid-gesture would also strand stale state: e.g. if scroll is gated off after a `.fingers(.began)` passed, `stage` stays `.touching(.passed)`; when re-enabled, the next gesture's `.began` under blocking would be `.stilled` (from the touching branch) instead of `.dropped` (the nil/coasting branch). Same pattern for DockSwipeFilter's `current`. The tapDisabled path handles the analogous situation by forgetting (`forgetGesture`, clearing dockSwipeFilters), which is explicitly under-blocking.
7. The tapDisabled handler re-enables unconditionally while `port` is non-nil; it has no knowledge of an intentional disable. It also resets the Dock swipe filters by replacing the dictionary, not via `DockSwipeFilter.forgetSwipe()` (which is only called in tests).
8. `anyTrackpadBlocksClicks()` is evaluated (lock + Array copy of sessions) for every parsed event, including drags/pressure/releases and Dock swipes whose decision ignores it. Unparsed events (most type-29 gesture traffic, non-Dock) return before any lock.
9. The mask cannot be changed after `tapCreate`; gating by type therefore means either a second tap (the source policy confines taps to ClickTap.swift, a file not a count) or `tapEnable` toggling of a tap for the high-volume types - and `tapEnable` from the frame thread would break plan 002's explicit "nothing on the frame thread enables or disables the tap" invariant.
10. Frame threads read the tap's `filter` Mutex every frame (`holding`), so frame callbacks and the tap callback contend on that one lock today (briefly).
11. `install` failing is the only Accessibility check at the adapter level; the model's `granted` is read separately (AXIsProcessTrusted), so a grant that the tap still refuses yields `isBlockingClicks`-equivalent false in reality but `blockClicks: true` in the model's `Run`.
12. The question's framing "the click tap ... who drives it" - there is no tap-specific port or adapter method; the tap is entirely a side effect of `TrackpadHardware.run(blockClicks:)`. And "GestureRecognizer.step's blocksClicks / blocksDockSwipes" reach the tap not by a message but by per-session Mutex<Bool> polled at event time.

## Open Questions

- Whether MultitouchSupport delivers each device's frames on one shared thread or one thread per device was not verified (code comments say "the framework's own thread" / "this device's frame callbacks"; DeviceSession comments assume one writer per device).
- Whether macOS ever sends `tapDisabledByUserInput` for this kind of tap in practice was not determined from code.
- The exact semantics of `CFRunLoopRun` after the source's port is invalidated mid-start (race in point "small race") is inferred from CF behaviour, not tested in the repo.
- Whether type 30 events actually carry field 110 == 23 and phase field 132 on current macOS is only asserted in synthetic tests; hardware verification lives in plan 006 notes, which I did not read.
