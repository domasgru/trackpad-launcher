# Frame thread and blocking state: how the verdict is produced and published

Angle: frame-thread-and-state. Base: the worktree at `feature/014-gate-event-tap` (HEAD 9557bc2). All paths are relative to
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/014-gate-event-tap/`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `Recognition` | `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift:4-38` | Per-frame output of one trackpad's recognizer: optional `event`, plus `blocksClicks` and `blocksDockSwipes`. |
| `Recognition.Event` | same, `:6-12` | `.fired(Gesture)`, `.swipe(SwipePhase)`, `.windowSwipe(SwipePhase)`, `.swap(startsSeries: Bool)`. A frame carries at most one. |
| `GestureRecognizer` | same, `:50-457` | Pure value-type state machine for ONE trackpad; `step(_:)` per frame, `answerWindowSwipe(began:isWindowSwipe:)` between frames. |
| `GestureRecognizer.State` (private) | same, `:418-446` | `idle`, `armed(Anchor)`, `tapping(Anchor, Tap)`, `resting(Anchor, Pair)`, `spoiled(Anchor)`, `rest(Rest)`, `swiping(Swipe)`; `anchor` and `thumb` computed views. |
| `ContactBook` (private) | same, `:299-316` | Every contact down after the edge filter: origin, `firstSeen`, `isRealLanding`. `landingTime(of:)` is nil for an unknown landing time. |
| `EdgeContacts` | `LauncherKit/Sources/LauncherCore/Surface.swift:61-93` | Strips palm contacts (bottom band, lower hand-side band) from every frame before the recognizer sees them. |
| `AnchorCorner` | `Surface.swift:32-56` | `admits` (a landing becomes the thumb), `holds` (an anchored thumb stays, zone + 2 mm margin). |
| `GestureRules` | `LauncherKit/Sources/LauncherCore/GestureRules.swift` | Constants: `clickBlockingWindow = 3 s` (strictly less blocks), `maxTapDuration = 400 ms`, `dragThresholdMM = 3`, corner 20% x 25%, `anchorReleaseMarginMM = 2`, edge band 3 mm / top line 0.40. |
| `DeviceSession` | `LauncherKit/Sources/LauncherPlatform/FrameStream.swift:14-79` | One running trackpad: its recognizer (in a Mutex), its two published blocking flags, the window-swipe answer slot, the `deliver` hop. Replaced by every `run`. |
| `sessions` (global) | `FrameStream.swift:84` | `Mutex<[UInt: DeviceSession]>`, key = device ref bit pattern. The registry the frame callback and the tap thread look sessions up in. |
| `contactFrameCallback` (global) | `FrameStream.swift:86-91` | The C callback MultitouchSupport calls per frame; looks the session up, samples the press, parses, calls `session.receive`. |
| `anyTrackpadBlocksClicks()` / `anyTrackpadBlocksDockSwipes()` | `FrameStream.swift:100-108` | Tap-thread readers: copy `sessions.values` out of the lock, then OR each session's flag. |
| `anyMouseButtonDown()` | `FrameStream.swift:94-96` | `CGEventSource.buttonState(.combinedSessionState, …)` for left/right/center; called on every frame. |
| `WindowSwipeAnswer` | `FrameStream.swift:6-9` | `{ began: FrameTime, isWindowSwipe: Bool }`, the main-actor-to-frame-thread message. |
| `MultitouchTrackpads` | `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:10-169` | `@MainActor` real `TrackpadHardware`: IOKit hot-plug + wake notifications, `run`, haptics, `confirmWindowSwipe`. Owns the `ClickTap`. |
| `MultitouchSupport` | `LauncherKit/Sources/LauncherPlatform/MultitouchSupport.swift` | `dlopen`ed private framework symbols; `ContactFrameCallback` C signature. |
| `TouchFrame(parsing:count:timestamp:press:)` | `LauncherKit/Sources/LauncherPlatform/TouchFrameParsing.swift:37-56` | MTTouch[] (96-byte `MTTouchMirror`) → `TouchFrame`; keeps only driver states 3 (`.landing`) and 4 (`.down`), flips y to top-left. |
| `TouchFrame`, `TouchFrame.Press` | `LauncherKit/Sources/LauncherCore/Touch.swift:48-84` | Snapshot of one instant; `Press(holding:buttonDown:)` is the precedence rule combining the click filter's `holding` with the button state. |
| `WindowSwipeConfirmation` | `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift` | `@MainActor` helper both adapters use: delivers an event to `onEvent` and, for `.windowSwipe(.began)`, returns whether `confirm(on:)` was called during it. |
| `TrackpadHardware` port, `TrackpadEvent` | `LauncherKit/Sources/LauncherCore/Ports.swift:3-46` | The port the model sees; `TrackpadEvent.init(_:on:)` maps `Recognition.Event` to the port event. |
| `ClickTap` | `LauncherKit/Sources/LauncherPlatform/ClickTap.swift:12-89` | The event tap (reader of the flags; also source of `holding` the frame thread reads). Covered in depth by another explorer. |
| `CursorTravel` | `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift` | Read on the frame thread when a slide begins (CFPreferences + `LaunchTuning.current`); affects travel only, never blocking. |
| `Launcher.reconcile(restart:)` | `LauncherKit/Sources/LauncherCore/Launcher.swift:211-231` | The only caller of `hardware.run`. |
| `InMemoryTrackpads` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:5-123` | Test adapter: real recognizer, real `ClickFilter` / `ScrollFilter`, scripted frames, synchronous delivery. |

## Flow

### 1. Frame production (MultitouchSupport thread)

1. `MultitouchTrackpads.run` (main) registers `contactFrameCallback` for every wanted device and calls `MTDeviceStart`
   (`MultitouchTrackpads.swift:111-114`). The session is put into `sessions` BEFORE the callback is registered (`:111`
   then `:112`), so the first frame always finds it.
2. MultitouchSupport calls `contactFrameCallback(device, touches, count, timestamp, frame)` on a framework-owned
   background thread (`MultitouchSupport.swift:9-12`; plan 001 grounding index.md:19 "delivered on a background thread
   owned by the framework"). `FrameStream.swift:86-91`:
   - `sessions.withLock { $0[UInt(bitPattern: device)] }`; nil → frame dropped (`return 0`).
   - `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())`. `session.holding` is
     `clickTap?.holding` (`FrameStream.swift:72`), which takes the `ClickTap.filter` Mutex and reads
     `ClickFilter.holding` (`ClickTap.swift:49`). nil when this run installed no tap.
   - `TouchFrame(parsing:…)` (`TouchFrameParsing.swift:40-55`): drops every driver state other than 3/4 (hovering,
     breaking, lingering contacts disappear), `FrameTime(seconds: timestamp)` is the only clock.
   - `session.receive(frame)`.
3. `DeviceSession.receive` (`FrameStream.swift:46-69`), all on the frame thread:
   1. `let latestAnswer = answer.withLock { $0 }` (the window-swipe answer slot, never cleared).
   2. Inside `recognizer.withLock`: if there is an answer, `answerWindowSwipe(began:isWindowSwipe:)` first; then
      `step(frame)`; if `recognition.beginsSlide`, `$0.travel = CursorTravel.travel(curves: pointerCurves)`.
   3. `blocking.withLock { $0 = recognition.blocksClicks }` (`:58`).
   4. `blockingDockSwipes.withLock { $0 = recognition.blocksDockSwipes }` (`:59`).
   5. If `recognition.event` is non-nil: builds a `reply` closure only for `.windowSwipe(.began)` (writes
      `WindowSwipeAnswer(began: frame.time, …)` into `answer`), then `deliver(TrackpadEvent(event, on: trackpad), reply)`.

   Both flags are written UNCONDITIONALLY on every frame, in two separate Mutexes (not one atomic pair). There is no
   change detection and no hook of any kind on a false→true or true→false transition today.

### 2. `GestureRecognizer.step` (pure; frame thread in production, test thread in tests)

Signature: `public mutating func step(_ frame: TouchFrame) -> Recognition` (`GestureRecognizer.swift:65`).
`Recognition.init(event: Event?, blocksClicks: Bool, blocksDockSwipes: Bool)` (`:33`). Those two Bools are the only
blocking fields; `beginsSlide` (`:29`) is a derived flag the session uses for travel, not for blocking.

Order inside `step`:
1. `edgeContacts.fingers(in: frame)` (`:66`): palm contacts are removed for good while they stay down. Everything
   below (including "another finger down" for blocking) uses only the remaining contacts.
2. Bookkeeping (`:67-82`): `isFirstFrame = previouslyDown == nil`; `lifted` includes an id that reappears with
   `.landing` (driver reuse); `landed` = `.landing` or not down on the previous frame. New book entries get
   `isRealLanding: !isFirstFrame || touch.phase == .landing` (`:81`): a contact already `.down` on a fresh recognizer's
   first frame has an unknown landing time.
3. Anchor maintenance (`:84-87`): for `armed/tapping/resting/spoiled`, if the anchor lifted or left `corner.holds`,
   state becomes `restOrIdle` of the other contacts that did not land this frame.
4. The state switch (`:90-181`) — transitions summarised:
   - `idle`: a landing that `corner.admits` becomes the thumb: `.armed` if it is alone, `.spoiled` if anything else is
     down (`:92-94`). Other landings → `.rest`.
   - `armed`: a finger lands → `.tapping` (or `.spoiled` if `press == .click`).
   - `tapping`: click → spoiled; a drag → `beginOrSpoil` (a two-finger pair dragging along an enabled kind begins a
     swipe/window swipe, else spoiled); > 400 ms → `.resting(pair)` or spoiled; all lifted → `.fired`.
   - `resting`: click, a pair finger lifting, or any non-thumb landing → spoiled; drag → `beginOrSpoil`.
   - `spoiled`: back to `.armed` once only the anchor is down.
   - `rest`: the private `step(_ rest:…)` (`:222-265`): thumb landing under resting fingers becomes `RestThumb`
     (`canSwap` iff `swaps && !isStopped && fingers.count == 2`); its lift within 400 ms, unchanged, undragged, fires
     `.swap(startsSeries: !isSeries)` and sets `isSeries = true`; a thumb rolling out of the corner becomes a finger
     (`rolled`); when `rest.fingers` empties → `.armed(thumb)` or `.idle`.
   - `swiping`: thumb tracking (`:138-144`), `cancelled` on a click or > 2 swipe fingers, `ended` when both lifted,
     else `moved(travelMM:)` when travel changed. The state after ending is `.spoiled(thumb)` or `restOrIdle`.
   - `beginOrSpoil` (`:274-283`): `Swipe(kind, began: time, isConfirmed: kind == .swipe, …)`. A `.swipe` is confirmed
     at once; a `.windowSwipe` starts unconfirmed.
5. Blocking verdict (`:182-200`), computed from the NEW state after the switch, the current `down` set (edge contacts
   excluded), the book and `frame.time`:
   - `.swiping(swipe)` with `swipe.isConfirmed` → both true.
   - `.rest(rest)` with `rest.isSeries` → both true.
   - otherwise `thumb = state.thumb` (`:439-445`: the anchor for armed/tapping/resting/spoiled; `rest.thumb?.id` in a
     rest; `swipe.thumb?.id` in an UNCONFIRMED swipe; nil in a confirmed swipe or idle):
     - `blocksDockSwipes = thumb != nil && down has some id != thumb` (no time limit).
     - `blocksClicks = thumb != nil && book.landingTime(of: thumb) != nil && frame.time - landedAt < 3 s && down has
       some id != thumb`.

Conditions, mapped to the question's cases:

| Case | blocksClicks | blocksDockSwipes | Where |
|---|---|---|---|
| Thumb anchored alone (armed, nothing else down) | false | false | `:192-198`, other contact required |
| Thumb anchored, another finger down, thumb landed < 3 s ago (this recognizer saw it land) | true | true | `:192-198` |
| Same, ≥ 3 s after the thumb landed | false | true | expiry observed only on a frame (ClickBlockingRecognizerTests `expiryIsSeenOnAFrameWhereNothingButTheClockMoved`) |
| Thumb and a finger land on the same frame | true (spoiled anchor, landed now) | true | `:94`, then `:192-198`, on that very frame |
| Confirmed swipe (`.swipe`), whole duration incl. after the thumb lifts | true | true | `:184-186`; DockSwipeBlockingRecognizerTests `aSwipeBlocksToItsEndAfterTheThumbLifts` |
| Unconfirmed window swipe | thumb rules only (via `swipe.thumb`) | thumb rules only | `:442`; begin frame: `!blocksClicks` unless within 3 s, `blocksDockSwipes` true (WindowSwipeRecognizerTests:323) |
| Confirmed window swipe | true from the frame AFTER the answer is taken until both fingers lift | true | `answerWindowSwipe` sets `isConfirmed`, flags recomputed on the next `step` |
| Thumb under resting fingers (rest with `rest.thumb`) | thumb rules, from the landing frame | thumb rules | `:441`; SwapRecognizerTests `beforeTheFirstSwap…` |
| Swap series (`rest.isSeries`) | true while any rest finger is down, no time limit, no thumb needed | true | `:187-189`; SwapRecognizerTests `theSeriesBlocks…` (one finger left still blocks) |
| Thumb already resting on a fresh recognizer's first frame (after `run`) | false (landing time unknown) until it lifts and lands again | true with another finger | `:81`, `:313-315`; ClickBlockingRecognizerTests `aThumbAlreadyRestingOnTheFirstFrameOpensNoWindow`, DockSwipeBlockingRecognizerTests `aThumbAlreadyRestingWhenRecognitionStartedBlocksToo` |
| Edge (palm) contact as the "other finger" | does not count | does not count | `:66`; EdgeContactRecognizerTests `anEdgeContactIsNotAnotherContactDownForBlocking` |
| Thumb rolled out of the corner | stops at once (anchor dropped / becomes a rest finger) | stops | `:84-87`, `:241-246` |
| No thumb, fingers only | false | false | DockSwipeBlockingRecognizerTests `fingersWithNoThumbInTheCornerNeverBlock` |

Purity: the verdict is a deterministic function of (recognizer config: corner, surface, slides, swaps) + (private
state: `state`, `book`, `previouslyDown`, `edgeContacts`) + the frame (touches, `press`, `time`). No wall clock, no
global reads. The one other mutator is `answerWindowSwipe`, applied between frames by the session (`FrameStream.swift:49-51`).
`travel` is mutated by the session on `beginsSlide` but only affects `.moved` travel, never blocking.

Invariant (derived from the code, not documented): `blocksClicks ⇒ blocksDockSwipes`. Both special branches set both
true; in the thumb branch `blocksClicks` requires the same "thumb + another contact" as `blocksDockSwipes` plus the
3 s check. So `blocksDockSwipes` is the superset "may block" flag a recognizer publishes.

### 3. Leaving the frame thread: the verdict

- Written to: `DeviceSession.blocking: Mutex<Bool>` and `DeviceSession.blockingDockSwipes: Mutex<Bool>`
  (`FrameStream.swift:20-22`), both initialised `false` ("resets its blocking flag by construction", `:11`).
- Single writer: that device's frame callback (`receive`, `:58-59`), every frame.
- Readers: the click tap thread, per tap event, through `anyTrackpadBlocksClicks()` (`ClickTap.swift:75`, read once per
  parsed event before any filter lock) and `anyTrackpadBlocksDockSwipes()` (`ClickTap.swift:83`, only for Dock swipe
  events). Each reader copies `Array(sessions.withLock { $0.values })` (an array allocation per event) and ORs the
  per-session flags: any trackpad blocking → block. Merging happens at the read; nothing on the frame thread knows
  about other trackpads.
- Tests read `session.blocksClicks` directly (DeviceSessionAnswerTests:88).
- Note `anyTrackpadBlocksClicks()` is read for every parsed event, including drags, pressure and releases, where
  `ClickFilter.decide` ignores the flag (only `.press` reads it), and for Dock swipe events, where it is unused.

### 4. Leaving the frame thread: events

- Mechanism: the `deliver` closure built in `run` (`MultitouchTrackpads.swift:95-105`):
  `DispatchQueue.main.async { MainActor.assumeIsolated { guard let self, self.runs == generation else { return }; let
  answer = self.confirmation.deliver(event, to: self.onEvent); if let reply, let answer { reply(answer) } } }`.
- Hops: every non-nil `Recognition.event`: `.gesture` (fired tap), `.swap`, `.swipe(began/moved/ended/cancelled)`,
  `.windowSwipe(began/moved/ended/cancelled)`. One `async` block per event. Blocking flags never hop.
- Ordering: the main queue is FIFO; comment at `:96` claims "FIFO from one frame thread" so a trackpad's events keep
  frame order.
- Session identity: `generation = runs` captured at `run` time (`:84`); `runs` is bumped at the very start of each
  `run` (`:69`, even before the `framework` guard). The check runs at dequeue time on main, so an event enqueued by a
  replaced session is dropped, together with its reply (comment `:96-97`: "a stale swipe start could never be ended").
  `[weak self]` also drops events after the adapter is gone.

### 5. The window-swipe answer hop (main → frame thread): the existing precedent

1. Frame N reports `.windowSwipe(.began)`; `receive` builds `reply = { answer.withLock { $0 = WindowSwipeAnswer(began:
   frame.time, isWindowSwipe:) } }` (`FrameStream.swift:62-66`), capturing the session strongly.
2. Main: `WindowSwipeConfirmation.deliver` sets `startBeingHandled = (trackpad, false)`, calls `onEvent`; the model's
   `windowSwipe(.began)` (`Launcher.swift:282-294`) reads the frontmost windows and calls
   `hardware.confirmWindowSwipe(on:)` → `confirmation.confirm(on:)` marks it confirmed. `deliver` returns the Bool;
   the adapter calls `reply(answer)` (`MultitouchTrackpads.swift:101-102`).
3. Frame thread, on the next frame AFTER the reply landed: `receive` reads `answer` and calls
   `answerWindowSwipe(began:isWindowSwipe:)` before `step` (`FrameStream.swift:47-51`). The recognizer ignores an
   answer for another start, after the slide ended, or a second answer (`GestureRecognizer.swift:211-219`). The slot
   is never cleared; the same answer is re-offered every frame and ignored.
4. The frame thread never waits; frames processed before the reply lands see the slide unconfirmed (thumb rules only).
   A confirmation raises blocking only on the next frame's `step`, since flags are only published in `receive`.

Pattern: a `Mutex` slot on the `DeviceSession`, writer main (through a closure the frame thread created), reader the
frame thread at the top of the next `receive`. Nothing pushes into the frame thread; it pulls on its next frame.

### 6. Session lifecycle: `MultitouchTrackpads.run` (main)

`public func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, slides: Set<SlideKind>, swaps: Bool)`
(`MultitouchTrackpads.swift:68-116`), in order:
1. `runs += 1`; `guard let framework else { return }` (no MultitouchSupport → nothing runs, no tap).
2. `sessions.withLock { $0 = [:] }` — before any device is touched, so an in-flight frame finds nothing.
3. `clickTap?.remove(); clickTap = nil` (comment: a withheld press's release may now reach apps).
4. For each started device: `MTUnregisterContactFrameCallback`, `MTDeviceStop`; close actuators.
5. `devices = listTrackpads()` filtered to `trackpads`; `if blockClicks && !devices.isEmpty { clickTap =
   ClickTap.install() }` (nil when the system refuses: no Accessibility). The new tap is live BEFORE any new session
   exists, so it reads all flags false until frames flow.
6. Per device: new `DeviceSession` with a fresh `GestureRecognizer(…, travel: .linear)`, pointer curves, the new
   `clickTap`, a `deliver` capturing `generation`; actuator open; insert into `sessions`; register callback; start.

Recognizers: exactly one per running trackpad (one `DeviceSession` per device). A `run` resets EVERYTHING recognizer
side: `state = .idle`, empty book, `previouslyDown = nil` (so a resting thumb's landing time is unknown, and every
contact down on the first frame counts as landed), fresh `EdgeContacts`, fresh flags (false), fresh `answer` slot, and
a fresh `ClickTap` with fresh `ClickFilter`, `ScrollFilter`, `dockSwipeFilters`. The model sets `shown = nil` just
before (`Launcher.swift:229`).

Who calls `run`: only `Launcher.reconcile(restart:)` (`Launcher.swift:211-231`). `Run` = `(trackpads: active ?
connected : [], handMode, blockClicks: active && granted, slides: granted ? settings.slides : slides − windowSwipe,
swaps)`; skipped when equal to `lastRun` unless `restart`.
- Hot-plug: IOKit `kIOFirstMatchNotification` / `kIOTerminatedNotification` on the main queue → `.trackpadsChanged`
  (`MultitouchTrackpads.swift:31-47`) → `reconcile(restart: true)` (`Launcher.swift:94`): always re-runs.
- Wake: `NSWorkspace.didWakeNotification` → `.trackpadsChanged` → restart (`:48-52`). Devices stop delivering frames
  across sleep.
- Hand mode: `setHandMode` → `reconcile()` → re-runs (handMode is in `Run`).
- Settings: `setSwipe`, `setWindowSwipe`, `setSwap` → `reconcile()`; re-runs only if `Run` changed (e.g. window swipe
  toggled without Accessibility changes nothing). Launch animation and assignments never re-run.
- Accessibility / Screen Recording: `permissions.onChange` → `reconcile()`; Accessibility changes `blockClicks` and
  `slides` → re-run; Screen Recording alone never re-runs.
- Trackpad preferences (conflicting system gestures): `preferences.onChange` → `reconcile()`; `activity.isActive`
  changes `trackpads` and `blockClicks`.

## Shared mutable state (every piece crossing threads)

| State | Type / file:line | Writer | Readers |
|---|---|---|---|
| `sessions` | `Mutex<[UInt: DeviceSession]>`, `FrameStream.swift:84` | main (`run`: empty, then insert per device) | frame callback (per frame lookup), tap thread (`anyTrackpadBlocks*`, per event) |
| `DeviceSession.recognizer` | `Mutex<GestureRecognizer>`, `:16` | that device's frame thread only (uncontended; "the compiler's proof", `:12-13`) | same |
| `DeviceSession.blocking` | `Mutex<Bool>`, `:20` | that device's frame thread, every frame | tap thread (per parsed tap event); tests |
| `DeviceSession.blockingDockSwipes` | `Mutex<Bool>`, `:22` | that device's frame thread, every frame | tap thread (Dock swipe events only) |
| `DeviceSession.answer` | `Mutex<WindowSwipeAnswer?>`, `:28` | main, via the reply closure | that device's frame thread, top of every `receive` |
| `ClickTap.filter` | `Mutex<ClickFilter>`, `ClickTap.swift:14` | tap thread | tap thread; frame threads via `holding` (every frame) |
| `ClickTap.scrollFilter`, `dockSwipeFilters` | `ClickTap.swift:16-18` | tap thread | tap thread |
| `ClickTap.port` | `Mutex<Unchecked<CFMachPort>?>`, `:20` | main (install/remove) | tap thread (re-enable on disabled-by-timeout/user-input; run loop source creation) |
| `ClickTap.runLoop` | `Mutex<Unchecked<CFRunLoop>?>`, `:22` | tap thread (on start) | main (`remove` stops it) |
| `LaunchTuning.tunerOverride` (DEBUG only) | `LaunchTuning.swift:50` | main (tuner) | frame thread via `CursorTravel.travel` on slide begin |
| MultitouchTrackpads `runs`, `clickTap`, `startedDevices`, `actuators`, `confirmation` | `MultitouchTrackpads.swift:13-23` | main only | main only (the `deliver` block reads `runs` on main) |

Also read per frame on the frame thread without app-owned state: `CGEventSource.buttonState` (3 calls) and, on a
slide begin, `CFPreferencesCopyAppValue("com.apple.trackpad.scaling")`.

## Files Read

- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift`
- `LauncherKit/Sources/LauncherCore/Touch.swift`
- `LauncherKit/Sources/LauncherCore/Surface.swift`
- `LauncherKit/Sources/LauncherCore/GestureRules.swift`
- `LauncherKit/Sources/LauncherCore/ClickFilter.swift`
- `LauncherKit/Sources/LauncherCore/ScrollFilter.swift`
- `LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift`
- `LauncherKit/Sources/LauncherCore/Launcher.swift`
- `LauncherKit/Sources/LauncherCore/Settings.swift` (grep: `slides`)
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift`
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchSupport.swift`
- `LauncherKit/Sources/LauncherPlatform/TouchFrameParsing.swift`
- `LauncherKit/Sources/LauncherPlatform/ClickTap.swift`
- `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift` (lines 40-60)
- `LauncherKit/Package.swift`, `Config/Base.xcconfig` (grep), `TrackpadLauncher/TrackpadLauncherApp.swift` (grep)
- `docs/architecture.md`
- `plans/014-gate-event-tap/plan.md`
- `plans/002-gesture-click-blocking/plan.md` (lines ~247, 376-401, 425-437, 1115-1162, 1310-1319)
- `plans/001-trackpad-launcher-app/.temp/architect/grounding/index.md` and `probes/README.md` (grep: thread)
- Tests: `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`, `ClickBlockingRecognizerTests.swift`,
  `DockSwipeBlockingRecognizerTests.swift`, `SwapRecognizerTests.swift` (1-115), `WindowSwipeAnswerTests.swift`
  (1-60, 110-180), `EdgeContactRecognizerTests.swift` (index + 150-180), `SourcePolicyTests.swift` (20-108),
  `LauncherKit/Tests/LauncherPlatformTests/DeviceSessionAnswerTests.swift`, `DeviceSessionTravelTests.swift` (1-60)

## Boundaries

- In: MultitouchSupport C callback (device ref, MTTouch[], count, timestamp); `CGEventSource.buttonState`; the
  `ClickTap.filter`'s `holding`; the main actor's window-swipe answer through `DeviceSession.answer`; `run` from
  `Launcher.reconcile`.
- Out: per-session `blocking` / `blockingDockSwipes` flags (pulled by the tap thread per event); `TrackpadEvent`s on
  the main queue to `onEvent` (pushed). Nothing else leaves the frame thread.
- The port (`TrackpadHardware`, `Ports.swift:26-46`) exposes no blocking state to the model; the model only arms
  blocking via `run(…, blockClicks:)`. The model never sees flags; the tap never sees the model.

## Test modelling of the frame thread (summary for this angle)

- `InMemoryTrackpads.touch(_:on:)` (`InMemoryAdapters.swift:84-103`): per frame, (a) a scripted press edge is decided
  by the real `ClickFilter` on the flags the PREVIOUS frame left, merged with `blocking.values.contains(true)`; (b) the
  frame's press is re-sampled with `TouchFrame.Press(holding: clickFilter?.holding, buttonDown:)`; (c) the real
  recognizer steps; (d) `blocking[id] = recognition.blocksClicks`; (e) events delivered synchronously through
  `WindowSwipeConfirmation`; (f) the answer applied immediately after the frame via `answerWindowSwipe` (the real
  adapter applies it before the next frame — equivalent for the recognizer, but the fake never models a late reply).
- `scroll(_:)` (`:113-115`) decides a scroll event on the same merged `blocksClicks` flags; nil when unarmed.
- NOT modelled in the fake: `blocksDockSwipes` and `DockSwipeFilter` (only pure `DockSwipeFilterTests` and recognizer
  tests cover them), drags and pressure through the filter, the tap's disabled-by-timeout path, cross-thread timing
  (events between frames other than press edges / scripted scrolls), the generation drop (it runs synchronously; `inject`
  simulates "an event recognised just before activity flipped").
- `run` in the fake (`:47-59`) resets recognizers, `blocking`, button state and arms `clickFilter` + `scrollFilter` iff
  `blockClicks && !trackpads.isEmpty`; `sleep()` makes trackpads deaf until the next `run` (wake).
- `DeviceSessionAnswerTests` / `DeviceSessionTravelTests` drive the real `DeviceSession.receive` with a recording
  `deliver`, calling replies synchronously, and read `session.blocksClicks` after each frame.

## docs/architecture.md "Concurrency" claims, verified

1. "LauncherCore and LauncherPlatform are nonisolated by default; the model, the ports and the public surface of every
   real adapter are @MainActor. LauncherUI and the app target use main-actor default isolation." — TRUE
   (`Package.swift`: only LauncherUI has `.defaultIsolation(MainActor.self)`; `Config/Base.xcconfig:6`
   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; `Launcher`, `TrackpadHardware`, `MultitouchTrackpads` are
   `@MainActor`).
2. "Multitouch frames are recognised on the framework's own thread; only recognised events hop to the main actor: a
   fired tap, a swap, and the begin, moves and end of a swipe or of a slide up or down that may be a window swipe, in
   frame order on the main queue and never from a session a later run replaced." — TRUE (`deliver` /
   `DispatchQueue.main.async` / `runs == generation`). Slightly incomplete: `.cancelled` also hops (it says "end").
   Also note blocking flags do not hop; they are pulled by the tap thread.
3. "One thing hops back: the model's answer … the adapter replies once that call returns, and the frame thread hands
   the reply to that trackpad's recognizer before its next frame. The recognizer ignores an answer to any other start.
   Until the answer arrives the slide blocks only by the thumb rules, and the frame thread never waits for it." —
   TRUE. Nuance: "before its next frame" means "at the start of the first frame processed after the reply lands"; if
   main is slow, several frames can pass unconfirmed.
4. "State shared with that thread lives behind a Mutex with one writer." — TRUE for every app-owned field
   (`sessions`, flags, answer, filter, port, runLoop; the recognizer Mutex has one writer by construction).
   `nonisolated(unsafe)` is banned by `SourcePolicyTests.swift:53`.
5. "No timers, no polling, no background loops … This is what keeps idle CPU at zero. The one extra thread is the
   click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives (a press,
   its drags and pressure, a scroll event, or a system gesture event)." — Literally true (it sleeps between events) but
   STALE in spirit, as plan 014 says: scroll (22) and gesture/Dock control events (29/30) arrive at frame rate whenever
   fingers are on the pad, so the thread is effectively busy during all ordinary use. Also: "exists only while click
   blocking is armed" — the thread exists whenever `ClickTap.install()` succeeded, i.e. `blockClicks && devices
   non-empty && Accessibility`; it is torn down and recreated on every `run` (hot-plug, wake, hand-mode and setting
   changes), not only on arm/disarm.
6. The other Concurrency bullets (off-main work, Core Animation, DEBUG tools) are outside this angle; not checked.

## Non-Obvious Things

- Flags are rewritten every frame with no change detection, as two separate lock acquisitions; a tap event can see
  `blocksClicks` from frame N and `blocksDockSwipes` from frame N-1. Harmless today because each tap path reads one flag
  for its decision (the click/scroll paths read only `blocksClicks`; the Dock path reads only `blocksDockSwipes`).
- There is NO hook today that runs when a verdict changes. Any gating driven from the frame thread would be new
  (plan 002, lines 437 and 1319, deliberately forbade enabling/disabling the tap from the frame thread, and its
  checklist greps `tapEnable` to `ClickTap.swift` only; the source-policy test confines `tapCreate`,
  `CGEventTapCreate` and `scrollWheel` to `ClickTap.swift` but not `tapEnable`).
- Verdict false→true can happen on a single frame with no precursor frame in which any flag is true: thumb + finger
  landing together (`.spoiled` with both flags true), a finger landing next to an armed thumb, a thumb landing under
  resting fingers. "Thumb anchored alone" yields false/false and is invisible outside the recognizer: `State.thumb` is
  private and `Recognition` exposes no "thumb anchored" or "may block soon" bit. A gate that wants to open BEFORE the
  first blocking frame would need a new output.
- Blocking does not imply a thumb in the corner or two contacts: a confirmed swipe keeps blocking after the thumb lifts,
  with a single swipe finger; a swap series keeps blocking with one rest finger and no thumb at all
  (SwapRecognizerTests `oneUp`). "Thumb in the corner" is not a sufficient proxy for the verdict.
- `blocksClicks ⇒ blocksDockSwipes` holds in every branch, so `blocksDockSwipes` is the per-trackpad superset.
- True→false transitions can be clock-only (the 3 s expiry), observed on the next frame. Frames keep coming while any
  contact is down (~100 Hz per plan 002); the driver sends an empty frame after the last lift (Touch.swift:47 "`[]` is
  the frame after the last lift"), which makes both flags false. If frames stop with contacts down (sleep), the last
  flags stay latched in the old session until `run` replaces it (wake → restart → `sessions` emptied, new flags false).
- A confirmation raises blocking only on the following frame (flags are only published in `receive`), and the answer is
  pulled, never pushed.
- `run` installs the new tap before any new session is registered, so a tap briefly reads "nobody blocks". It removes
  the old tap after emptying `sessions`. A held press's release may leak to apps across a `run` (accepted, comment `:72`).
- After any `run`, a thumb already resting has an unknown landing time: Dock swipes block immediately with another
  finger; clicks never block until it lifts and lands again.
- `holding` crosses from the tap thread to the frame thread every frame; it is how a dropped press reads `.blocked`
  instead of `.click`. If the tap stopped seeing presses this would change recognition, not only blocking. (Presses
  1-4, 25, 26 are not in the gated list in plan 014; drags and pressure are, and the filter's `holding` does not depend
  on drags or pressure.)
- Ordering comment "The main queue is FIFO from one frame thread" vs plan 002's "Frame thread (per device)" and
  `ClickTap.filter`'s "Reader: frame threads": the code does not settle whether MultitouchSupport uses one callback
  thread for all devices or one per device.
- `anyTrackpadBlocks*` allocate an array per tap event and are called even when the filter will ignore the result.
- In-memory fake models only `blocksClicks`; `blocksDockSwipes` merging and `DockSwipeFilter` are not modelled at the
  high seam.

## Open Questions

- Callback thread identity: one MultitouchSupport thread for all devices or one per device? Never probed (plan 001
  grounding README: "callback thread … not probed"; mt-probe recorded `threads=[]`). Matters for any per-trackpad
  combination done on the frame thread (a merged "any trackpad may block" computed on frame threads would need its own
  synchronisation if there are several).
- Whether `MTUnregisterContactFrameCallback` / `MTDeviceStop` wait for an in-flight callback. The code does not rely
  on it (empties `sessions` first), but an in-flight `receive` on a replaced session can still write the old session's
  flags and enqueue a (dropped) event; a frame-thread gating hook on a replaced session could act after `run`.
- Whether the driver always sends the trailing empty frame after the last lift in every case (e.g. palm-only lifts,
  lifts during sleep). The comment in `Touch.swift` asserts it; I found no probe.
- I did not trace `ClickTap` disabled-by-timeout recovery or filter in-flight state in depth (another explorer's angle).
