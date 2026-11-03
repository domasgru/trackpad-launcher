# How the swipe switcher works today: the state pipeline (model side)

All paths below are relative to `LauncherKit/Sources/` unless they start with `LauncherKit/Tests/`, `docs/` or `plans/`.

Headline answers first, then the details.

- **There is no switcher UI port.** `Ports.swift` has no switcher protocol (its protocols are TrackpadHardware, TrackpadPreferences, SystemActions, Permissions, AppScanner, RunningCopies, LoginItem and Installer: `LauncherCore/Ports.swift:26-186`). The model shows the switcher through **observable state**. `Launcher` is `@MainActor @Observable` (`LauncherCore/Launcher.swift:9-10`). Its computed `switcher: Switcher?` (`Launcher.swift:13-15`) is derived from the private stored `shown: ShownSwitcher?` (`Launcher.swift:54-56`). The UI (`LauncherUI/SwitcherPresenter.swift:25-28`) watches it with Swift 6.2's `Observations({ launcher.switcher })`. "Show / move / hide" are therefore three changes of one value:
  - **show:** nil becomes non-nil.
  - **move:** non-nil becomes a different non-nil.
  - **hide:** the value becomes nil.
- **There is no in-memory UI adapter.** Tests read `world.launcher.switcher` (and `.windowSwitcher`) directly after feeding frames (`LauncherKit/Tests/LauncherCoreTests/World.swift:317-333`, `SwitcherOnScreenTests.swift`). The in-memory adapter that exists is for the **hardware** port: `InMemoryTrackpads` (`LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:6-243`).
- **How often the value changes:** once per trackpad frame whose summed travel changed, not only when the selection changes. Every `.moved` event rewrites `shown` (`Launcher.swift:301-305`).
- **What continuous data reaches the UI:**
  - `selection.position`: fractional, clamped to `[0, count-1]`.
  - `selection.stretch`: the rubber band, in items, signed.
  - `selection.travelMM`: public read; the travel clamped to the quarter-step band.
  - `selection.selected`: the integer index.

  **Velocity, timestamps, frame intervals and raw (unclamped) finger travel do not reach the model or the UI.** The recognizer uses the frame interval only inside the pointer-acceleration curve, and then drops it.

---

## Components found

| Name | File | What it is | Isolation |
|---|---|---|---|
| `GestureRecognizer` | `LauncherCore/GestureRecognizer.swift:73` | A pure state machine for one trackpad. It turns `TouchFrame`s into a `Recognition`, which can carry `.swipe(SwipePhase)` / `.windowSwipe(SwipePhase)`. | `struct … Sendable`. Not actor-isolated. On hardware it is stepped on the MultitouchSupport frame thread inside a `Mutex`. |
| `GestureRecognizer.Swipe` (private) | `GestureRecognizer.swift:380-392` | Per-slide state: `kind`, `began`, `isConfirmed`, `fingers: [TouchID: SurfacePoint]` (positions on the last frame), `lastTime: FrameTime`, `travelMM` (unclamped running sum), `thumb`. | Sendable struct |
| `Recognition` / `Recognition.Event` | `GestureRecognizer.swift:4-39` | What one frame produced. `beginsSlide` (`:31`) tells the frame thread to install cursor travel. | Sendable |
| `SlideKind` | `LauncherCore/Gesture.swift:26-31` | `.swipe` (sideways; app switcher; positive to the right in both hand modes) or `.windowSwipe` (up or down; positive downwards). | Hashable, Sendable |
| `SwipePhase` | `Gesture.swift:34-45` | `.began` (travel 0; the 3 mm before it do not count), `.moved(travelMM:)` (absolute travel since `began`, in step-mm, **sent only when it changed**), `.ended` (both fingers lifted), `.cancelled` (a third finger, or a click that reached apps). | Equatable, Sendable |
| `SwipeEvent` | `Gesture.swift:48-56` | A `phase` plus a `trackpad`. | Sendable |
| `TrackpadEvent` | `LauncherCore/Ports.swift:3-20` | The port enum: `.gesture`, `.swipe(SwipeEvent)`, `.windowSwipe(SwipeEvent)`, `.swap`, `.trackpadsChanged`. Its `init(_:on:)` is the single mapping from a recognizer event. | Sendable |
| `TrackpadHardware` | `Ports.swift:26-46` | The hardware port. `onEvent: (@MainActor (TrackpadEvent) -> Void)?` is called on the main actor, in frame order. | `@MainActor` protocol |
| `SwipeTravel` | `LauncherCore/PointerCurve.swift:135-157` | `.linear` (1 step-mm per finger mm) or `.cursor(PointerCurve, pointsPerStep:)`. `travel(along:dxMM:dyMM:interval:)` converts one frame's finger movement into step-mm. | Equatable, Sendable enum |
| `PointerCurve` | `PointerCurve.swift:7-132` | Reproduces macOS trackpad pointer acceleration (IOHIDParametricAcceleration). `cursorMove(dxMM:dyMM:interval:)` returns cursor points. | Equatable, Sendable struct |
| `CursorTravel` | `LauncherPlatform/CursorTravel.swift:7-44` | Reads the device's `HIDAccelCurves` (IOKit) and the user's tracking speed (`com.apple.trackpad.scaling`), then builds a `SwipeTravel` per slide. | Static, nonisolated. Called on the frame thread. |
| `LaunchTuning` (swipe fields) | `LauncherPlatform/LaunchTuning.swift:39-44, 49-56` | `swipeFollowsCursor = true`, `swipePointsPerStep = 100`, `swipeTrackingSpeed = -1` (−1 means use the system value). In Debug builds a tuner can override them. | Sendable struct |
| `DeviceSession` | `LauncherPlatform/FrameStream.swift:23-89` | One running device. Holds the recognizer in a `Mutex`, steps it per frame, installs cursor travel on `beginsSlide`, and calls `deliver`. | `final class … Sendable` |
| `MultitouchTrackpads` | `LauncherPlatform/MultitouchTrackpads.swift:10` | The real `TrackpadHardware`. `deliver` hops each event with `DispatchQueue.main.async` + `MainActor.assumeIsolated`. | `@MainActor` |
| `WindowSwipeConfirmation` | `LauncherCore/WindowSwipeConfirmation.swift:6-33` | Every event passes through `deliver(_:to:)`. Only window-swipe starts get a reply. | `@MainActor` |
| `Launcher` | `LauncherCore/Launcher.swift:9-389` | The model. `swipe(_:)` (`:291-320`) is the only place a swipe becomes state and effects. | `@MainActor @Observable final class` |
| `Launcher.ShownSwitcher` | `Launcher.swift:54` | Private `enum { case apps(Switcher), windows(WindowSwitcher) }`. At most one switcher of either kind at a time. | Equatable |
| `Switcher` | `LauncherCore/Switcher.swift:6-33` | One swipe's switcher: a fixed `row: [AppEntry]` (≤10), private `startsOnFrontmost`, `selection: SwitcherSelection` (`public package(set)`), `trackpad`. Also `selectedApp` and `selectsFrontmost`. | `struct: Equatable, Sendable` |
| `SwitcherSelection` | `LauncherCore/SwitcherSelection.swift:6-57` | Position along a fixed list. Stores `count`, `travelMM` (clamped to a ±quarter-step band past the ends) and a private `reportedMM`. Provides `follow(_:)`, `selected`, `position` and `stretch`. **Shared with the window switcher.** | `struct: Equatable, Sendable` |
| `SwitcherRowLayout` | `LauncherCore/SwitcherRowLayout.swift:7-50` | Pure geometry for the app row: the scale factor, icon side and gap, `pitch`, highlight side, `panelSize`, `centreX(at:)`, `centreY`. **Built by the UI, not by the model.** | `struct: Equatable, Sendable` |
| `GestureRules` | `LauncherCore/GestureRules.swift:4-35` | Fixed numbers: `switcherMaxApps = 10`, `switcherStepMM = 12`, `switcherMaxStretch = 0.2`, `switcherMaxOvershoot = 0.25`, `windowSwitcherMaxRows = 10`. | `package enum` |
| `WindowSwitcher` | `LauncherCore/WindowSwitcher.swift:37-~165` | The window swipe's equivalent of `Switcher`. Also holds a `SwitcherSelection` (`:73`, `:87`). | Equatable, Sendable |
| `SwitcherPresenter` | `LauncherUI/SwitcherPresenter.swift:11-141` | The UI consumer. Observes `launcher.switcher`, reads Reduce Motion, builds `SwitcherRowLayout`, drives `SwitcherPanel`. | Implicitly `@MainActor` (LauncherUI has `.defaultIsolation(MainActor.self)`: `LauncherKit/Package.swift:15-19`). Has an `isolated deinit`. |
| `SwitcherPanel` | `LauncherUI/SwitcherPanel.swift:7-95` | `OverlayPanel` subclass: icon `CALayer`s, a glass highlight (`NSGlassEffectView`), `show(position:selected:animatesSize:)`, `springHighlight(from:)`. | Implicit MainActor |
| `OverlayPanel` | `LauncherUI/OverlayPanel.swift:17-126` | Base window shared by both switchers: borderless and non-activating. Content is `NSGlassEffectView(.regular)` under a rounded-rectangle clip. `present` shows at once; `dismiss` fades over 150 ms, or orders out at once under Reduce Motion. | Implicit MainActor |
| `InMemoryTrackpads` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:6-243` | Test hardware adapter: a real recognizer, scripted frames, synchronous main-actor delivery, `pulses` recorded. Always `travel: .linear` (`:62`). | `@MainActor` |

---

## Flow

### 1. Frame arrives (MultitouchSupport thread)

`contactFrameCallback` (`LauncherPlatform/FrameStream.swift:96-101`):

- Looks up the `DeviceSession` by device pointer in the global `sessions` Mutex (`:94`).
- Builds `TouchFrame(parsing:count:timestamp:press:)`. The frame carries `time: FrameTime`, which is monotonic seconds on the driver clock (`LauncherCore/Touch.swift:34-58`).
- Calls `session.receive(frame)`.

### 2. Recognize (frame thread)

`DeviceSession.receive` (`FrameStream.swift:54-80`):

- Under the recognizer `Mutex`, it applies any pending window-swipe answer and then calls `recognizer.step(frame)`.
- If `recognition.beginsSlide`, it sets `recognizer.travel = CursorTravel.travel(curves: pointerCurves)` (`:63`). So acceleration is chosen per slide, at its start. Travel is 0 on the begin frame, so the next frame is the first to use the curve (comment `:61-62`).
- If there is an event, it calls `deliver(TrackpadEvent(event, on: trackpad), reply)` (`:71-79`).

### 3. Inside `step`, for a swipe

**Begin.** `beginOrSpoil` (`GestureRecognizer.swift:300-309`) decides the slide direction once, using strict `|dx| > |dy|` (`:401`). This happens on the first frame where the farthest-moved finger of the pair passes 3 mm (`dragThresholdMM`). It creates `Swipe(kind:began:isConfirmed: kind == .swipe, fingers:lastTime:thumb:)` and emits `.slide(kind, .began)`.

**Moves.** In the `.swiping` case (`:159-203`), for each frame:

- **Lift and cancel checks first:**
  - A click, or more than two fingers, emits `.cancelled` (`:174-176`).
  - When both fingers are lifted, it emits `.ended` (`:177-180`).
- **Otherwise, per-frame movement:**
  - Per-finger delta comes only from fingers present on both frames (`:184-186`).
  - `interval = (frame.time - swipe.lastTime)` in seconds (`:187`).
  - The deltas are averaged across fingers, then converted to mm via `surface.widthMM` / `heightMM` (`:191-194`).
- **Travel:** `travel = swipe.travelMM + self.travel.travel(along: kind, dxMM:, dyMM:, interval:)` (`:195-196`).
- **Emit only on change:** `if travel != swipe.travelMM { swipe.travelMM = travel; event = .moved(travelMM: travel) }` (`:197-200`). No `.moved` event is sent when the fingers rest.
- Finger positions are not mirrored for hand mode, so `dx > 0` is rightwards in both modes (`Gesture.swift:27`).

### 4. Finger mm become step-mm: `SwipeTravel.travel` (`PointerCurve.swift:148-156`)

- `.linear`: returns `dxMM` for a swipe (`dyMM` for a window swipe). This is the default in a new recognizer (`MultitouchTrackpads.swift:92`), in tests (`InMemoryAdapters.swift:62`), and when the tuner turns `swipeFollowsCursor` off.
- `.cursor(curve, pointsPerStep)`: returns `curve.cursorMove(dxMM:, dyMM:, interval:).x / pointsPerStep * 12`. With the shipped `pointsPerStep = 100` (`PointerCurve.swift:141-144`; `LaunchTuning.swift:42`), **100 cursor points = 12 step-mm = one icon**.

### 5. Pointer acceleration: `PointerCurve.cursorMove` (`PointerCurve.swift:94-102`)

- **Counts:** `dx = dxMM / 25.4 * 400` and `dy` likewise (400 counts per inch).
- **Velocity:** `rateMultiplier = (1/120) / max(interval, 1/120)` (a nominal report rate of 120 Hz). Then `velocity = max(floor(hypot(dx, dy)) * rateMultiplier, 1/65536)`. The perpendicular component feeds the speed even though only `.x` is used for a swipe.
- **Output:** `scale = multiplier(velocity) / velocity`, and the method returns `(dx * scale, dy * scale)`.
- **`multiplier`** (`:105-117`) reproduces `IOHIDParametricAcceleration::multiplier`:
  - a polynomial below `tangent0`;
  - a linear tangent segment up to `tangent1`;
  - a square-root segment above that;
  - times `cursorScale = 96/67`.
- **Curve source:** `init?(_:trackingSpeed:)` (`:50-89`) picks or interpolates between the driver's curves by tracking speed.
  - The curves come from the device's `HIDAccelCurves`, falling back to the built-in MacBook curves (`CursorTravel.swift:21-34`, `PointerCurve.swift:121-131`).
  - The tracking speed is read fresh at each slide start from the CFPreferences key `com.apple.trackpad.scaling`, defaulting to 0.6875 (`CursorTravel.swift:14-17`), unless the tuner overrides it (`CursorTravel.swift:37-43`).
- **Velocity stays internal.** It is computed per frame inside this function and then discarded. It never appears in `SwipePhase`, `Switcher` or `SwitcherSelection`.

### 6. Hop to the main actor (`MultitouchTrackpads.swift:95-103`)

- `DispatchQueue.main.async { MainActor.assumeIsolated { guard self.runs == generation; self.confirmation.deliver(event, to: self.onEvent) … } }`.
- This is **one main-queue block per recognized event**, so at most one per trackpad frame. The queue is FIFO from one frame thread, so frame order is kept.
- Events from a replaced session (an older `runs` generation) are dropped.
- `WindowSwipeConfirmation.deliver` (`WindowSwipeConfirmation.swift:16-26`) passes non-window-start events straight to the handler.

### 7. Model dispatch

`Launcher.start` wires `hardware.onEvent`: `.swipe(let event)` goes to `swipe(event)` (`Launcher.swift:99-107`).

### 8. `Launcher.swipe(_:)` (`Launcher.swift:291-320`)

**`.began`** (`:293-300`):

- Ignored unless `shown == nil` (one switcher at a time; a second trackpad's swipe is ignored) and `activity.isActive`.
- Reads `system.runningApps()`, then builds `Switcher(frontmost:running:leavingOut: settings.assignedBundleIDs, trackpad:)`.
- That init returns nil when there is nothing but the frontmost app (`Switcher.swift:20-27`). In that case `shown` stays nil, no switcher shows, and the swipe still runs its course in the recognizer.
- The row is the frontmost app first, then the ⌘-Tab running apps (minus the frontmost app's URL and minus any assigned bundle IDs), capped at 10 by prefix.
- The selection starts with `SwitcherSelection(count:)`: `travelMM = 0`, so `position 0`, `selected 0`.

**`.moved(let travel)`** (`:301-305`):

- Guarded on an `.apps` switcher from the same trackpad.
- `let crossed = open.selection.follow(travel)`, then `shown = .apps(open)`, which notifies observers. Then `crossed` × `hardware.playFeedback(.lightTick, …)`.
- **This runs and writes `shown` for every `.moved` event, whether or not `selected` changed.**

**`.ended`** (`:306-316`):

- Sets `shown = nil` (hide) **first**, synchronously.
- If `selectsFrontmost`, it returns silently.
- Otherwise it re-reads running apps. If the selected app is still running, it plays the `.gesture` haptic and calls `system.bringToFront(selectedApp)`.
- All of this happens in the same main-actor turn, before any UI observer runs.

**`.cancelled`** (`:317-318`): sets `shown = nil` with no effects.

**Other hide paths:** `reconcile()` sets `shown = nil` whenever it re-runs the trackpads (`Launcher.swift:240-242`). That covers settings toggles, hand mode, permission or preference changes that alter the run, hot-plug and wake.

### 9. `SwitcherSelection.follow(_ reportedMM:)` (`SwitcherSelection.swift:23-35`)

The code:

```swift
let moved = reportedMM - self.reportedMM        // per-event delta from the absolute travel
self.reportedMM = reportedMM
var next = travelMM + moved
if travelMM < 0 && moved > 0 { next = moved }               // turning back from past the left end
if travelMM > last && moved < 0 { next = last + moved }     // turning back from past the right end
travelMM = min(max(next, -band), last + band)                // band = 0.25 * 12 = 3 step-mm
return abs(selected - before)
```

- **"Travel past the end is forgotten"** means two things in code:
  - (a) Clamping keeps at most 3 step-mm past either end, so any extra finger travel is dropped.
  - (b) On the first frame that moves back toward the list, travel restarts at the end (0 or `last`) plus that frame's movement. The stored overshoot is thrown away.

  So the selection changes after the usual 6 step-mm from the turn, however far the fingers went past the end. Tests confirm this: `SwitcherTests.swift:37-74`; `SwitcherOnScreenTests.swift:449-469` ("next app seven millimetres after the turn": 1 mm already inside the half-step + 6).
- The model keeps the recognizer's absolute travel (`reportedMM`, private) and its own clamped travel (`travelMM`) separately. **Only the clamped one is public.** The recognizer's unclamped running sum is never exposed beyond the `.moved` payload.

### 10. Derived values the UI reads (`SwitcherSelection.swift:39-56`)

- **`selected`:** `clamp(round_halfAwayFromZero(travelMM / 12), 0, count-1)`. It changes at ±6 step-mm, then every 12.
- **`position`:** `clamp(travelMM / 12, 0, count-1)`. This is **continuous and fractional**: the highlight sits between icons in proportion to travel (test `SwitcherTests.swift:128-134`).
- **`stretch`:** signed rubber band in items, `sign(e) × 0.2 × (1 − 1/(1 + |e|/0.2))` with `e = unclamped − clamped position`. It is 0 inside the list.
  - Because overshoot is clamped to 0.25 items, **the largest `stretch` ever produced is 0.2 × (1 − 1/2.25) ≈ 0.111 items**, about 11.1 pt at the full 100 pt pitch.
  - `switcherMaxStretch = 0.2` is an asymptote that is never reached. Tests only assert `< 0.2` (`SwitcherTests.swift:136-148`).
  - The mapping is a saturating curve, roughly linear for small `e`. Plan R10 asks for "at most 20 pt, most reached within 3 mm", which is a different number from today's.

### 11. UI receives it: `SwitcherPresenter.render` (`SwitcherPresenter.swift:116-129`)

**The loop.** It runs as `for await shown in Observations({ launcher.switcher }) { self?.render(shown) }` inside a `Task` (`:25-28`). The Task inherits MainActor through the module's default isolation.

**nil.** `panel.dismiss()`: a 150 ms opacity fade, or an immediate `orderOut` under Reduce Motion (`OverlayPanel.swift:94-117`).

**Non-nil:**

- Reads Reduce Motion fresh on every render with `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (`:121`). **The model never reads Reduce Motion.** No switcher type in LauncherCore knows about it.
- `if !panel.isPresented || switcher.row != laidOutRow { open(switcher.row) }` (`:122`).
- `open` (`:131-140`):
  - Picks the display under the pointer: `Displays.screen(under: NSEvent.mouseLocation)` (`LauncherUI/Displays.swift:5-9`).
  - **Computes the scale factor:** `SwitcherRowLayout(iconCount:, displayWidth: screen.frame.width)`. It uses the full frame, not `visibleFrame`.
  - Calls `panel.layoutRow(...)`, which centres the panel on the screen's midX/midY (`SwitcherPanel.swift:36-38`).
  - Resets `lastStretch = 0` and calls `panel.present(appear: nil)`, so the panel appears at once with no grow-in.
- `panel.show(position: selection.position, selected: selection.selected, animatesSize: !reduceMotion)` (`:124`). In `SwitcherPanel.show` (`SwitcherPanel.swift:65-79`):
  - The highlight x is set to `layout.centreX(at: position) - highlightSide/2` with implicit actions **disabled**, so it jumps to each trackpad-frame value.
  - Each icon's transform is set to 1.12× for `selected` and 1 for the others, inside a 0.12 s implicit animation, which is disabled under Reduce Motion.
- **Stretch:** `if selection.stretch != lastStretch, selection.stretch != 0, !reduceMotion { panel.springHighlight(from: stretch * layout.pitch) }`, then `lastStretch = stretch` (`:125-128`).
  - `springHighlight` (`SwitcherPanel.swift:83-94`) adds an **additive** `CASpringAnimation` on `position.x` from `offset` to 0 (mass 1, stiffness 420, damping 22), keyed `"stretch"` so each new one replaces the last.
  - So the rubber band is shown as a series of re-kicked springs that decay back to the end icon. It is not a held offset.

### 12. Scale factor for narrow displays (`SwitcherRowLayout.swift:19-31`)

- The formula: `scale = min(1, (displayWidth − 2×22) / fullSpan)`, where `fullSpan = (n−1) × (80+20) + 92`.
  - For 10 icons, `fullSpan = 992`, so the row shrinks on displays narrower than 1036 pt.
- A non-positive width means scale 1.
- These values all multiply by `scale`: `iconSide`, `iconGap`, `pitch = iconSide + iconGap`, `highlightSide`, and `panelSize`. The 22 pt `padding` stays fixed.
- Where it runs: computed in LauncherCore and instantiated **only in the UI**, by `SwitcherPresenter.open` (`SwitcherPresenter.swift:133`). The model never knows the scale.
- Consequence: **travel per icon is still 100 cursor points (12 step-mm) whatever the scale.** On a shrunk row the highlight moves `pitch` (< 100 pt) per icon, so it no longer tracks the cursor 1:1. `docs/domain-model.md:51` states this: "whatever the icons' size on screen".

### 13. Lift and cancel hide the switcher

Both go through `shown = nil`, which makes `launcher.switcher == nil` and leads to `render(nil)` → `panel.dismiss()`.

- **The app switch happens first.** `bringToFront` runs synchronously in `Launcher.swipe(.ended)`, in the same turn as `shown = nil`. The fade starts only when the async `Observations` loop next yields. So the app switch never waits for the UI, which is already what R12 needs.
- `OverlayPanel.dismiss` uses a generation counter so that a `present` arriving during the fade cancels the pending `orderOut` (`OverlayPanel.swift:94-117`).

---

## Frequency and payload across the model→UI boundary

**Frame thread → main:**
- One `TrackpadEvent` per recognized frame.
- For an ongoing swipe, that is one `.moved(travelMM: Double)` per trackpad frame in which the averaged finger x movement produced non-zero travel.
- No event when travel is unchanged (fingers resting, or a pure-vertical frame in `.linear` mode).
- The payload is a single absolute `Double` (step-mm since begin, unclamped) plus the `TrackpadID`. No timestamp, no velocity, no delta.

**Model → UI:**
- `shown` is reassigned on every `.moved` event (`Launcher.swift:304`). The new `Switcher` value always differs from the old one:
  - `travelMM` changes;
  - even when clamped at the band, the private `reportedMM` (part of the synthesized `Equatable`) changes.
- So observation fires per event, whether or not `selected` changed.
- `Observations` is transactional or asynchronous: if several main-queue blocks run before the observing Task resumes, the UI sees only the latest value. Intermediate frames can coalesce. **I did not verify how often this happens in practice.**

**What the UI gets:** a `Switcher` value. The useful fields:

| Field | Type | Notes |
|---|---|---|
| `row` | `[AppEntry]` | |
| `selection.count` | Int | |
| `selection.travelMM` | Double | Clamped to −3…last+3 |
| `selection.selected` | Int | |
| `selection.position` | Double | Continuous, clamped |
| `selection.stretch` | Double | Signed, ≤ ~0.111 items |
| `selectedApp` | AppEntry | |
| `selectsFrontmost` | Bool | |
| `trackpad` | TrackpadID | |

**Not available to the UI:**
- velocity or finger speed;
- frame timestamps or intervals;
- the selection's direction of motion (only derivable by diffing successive `position`/`travelMM` in the presenter);
- unclamped overshoot beyond 3 step-mm;
- how many icons a single event crossed. The model computes `crossed` (`follow`'s return value) only for haptic ticks and does not store it.

At rest no events flow, so the presenter does no work. The only animation left running is a decaying `"stretch"` spring or the 0.12 s icon-scale transition, both on the render server.

---

## Window switcher: what it shares

The plan's non-goal is that the window switcher keeps its look. It shares:

- **The recognizer machinery.** It uses the same `Swipe` state and the same `SwipeTravel` (100 cursor points per row along y: `PointerCurve.swift:141-155`; "for a window switcher's rows the match is not literal"). Its `.windowSwipe` events go through the same hop, plus the confirmation reply.
- **`SwitcherSelection`, identical.** It is a field of `WindowSwitcher` (`WindowSwitcher.swift:73, 87`), driven by `Launcher.windowSwipe(.moved)` through the same `follow` call (`Launcher.swift:338-344`). That handler also raises the selected visible window when `crossed > 0`.
- **`GestureRules` constants** (step 12, overshoot 0.25, max stretch 0.2). Any change to `SwitcherSelection` or these constants changes the window switcher's behaviour too.
- **The same presenter pattern.** `WindowSwitcherPresenter.render` (`LauncherUI/WindowSwitcherPresenter.swift:38-54`) has the same `Observations` loop and the same `lastStretch`/additive-spring logic, on `position.y`, through `WindowSwitcherPanel.springHighlight(fromY:)` (`WindowSwitcherPanel.swift:106-120`, using the look's spring numbers).
- **`OverlayPanel` as base class**, for both `SwitcherPanel` and `WindowSwitcherPanel`. It provides the rounded-rect `NSGlassEffectView(.regular)` content and the 150 ms fade.
- **`Displays.screen(under:)`.**

The window switcher does **not** share `Switcher`, `SwitcherRowLayout` (it has its own `WindowColumnLayout`), or `SwitcherPanel`.

---

## Files read

- `LauncherKit/Sources/LauncherCore/Switcher.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift`
- `LauncherKit/Sources/LauncherCore/GestureRules.swift`
- `LauncherKit/Sources/LauncherCore/Gesture.swift`
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (lines 1-210, 290-415)
- `LauncherKit/Sources/LauncherCore/PointerCurve.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Launcher.swift`
- `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift`
- `LauncherKit/Sources/LauncherCore/WindowSwitcher.swift` (lines 1-80 plus a grep)
- `LauncherKit/Sources/LauncherCore/Touch.swift` (lines 30-60)
- `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift`
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (lines 1-130)
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift` (lines 36-60)
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift` (lines 90-130)
- `LauncherKit/Sources/LauncherUI/Displays.swift` (`screen(under:)`)
- `LauncherKit/Package.swift`
- `Config/Base.xcconfig`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 1-125, 236-243)
- `LauncherKit/Tests/LauncherCoreTests/SwitcherTests.swift` (lines 30-148)
- `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift` (lines 1-60, 140-190, 445-470)
- `LauncherKit/Tests/LauncherCoreTests/SwipeTravelAndExitTests.swift` (lines 1-40)
- `LauncherKit/Tests/LauncherCoreTests/World.swift` (swipe, play and frame-by-frame helpers)
- `docs/architecture.md` (lines 18-21)
- `docs/domain-model.md` (switcher, window switcher, haptics sections)
- `docs/performance.md` (grep)
- `plans/024-fluid-app-switcher/plan.md`
- `plans/024-fluid-app-switcher/development-logs.md`

---

## Boundaries

- **Input to the pipeline:** MultitouchSupport contact frames (`contactFrameCallback`), IOKit `HIDAccelCurves`, CFPreferences `com.apple.trackpad.scaling`, and in Debug the `LaunchTuning` overrides.
- **Recognizer → model:** `TrackpadHardware.onEvent(TrackpadEvent)` on MainActor. The swipe payload is `SwipePhase` plus `TrackpadID`.
- **Model → OS effects:**
  - `TrackpadHardware.playFeedback(.lightTick | .gesture)`: one light tick per icon crossed, and the gesture haptic on a lift that switches;
  - `SystemActions.runningApps()` at begin and at lift;
  - `SystemActions.bringToFront(_:)` at lift.
- **Model → UI:** the observable `Launcher.switcher: Switcher?` and nothing else. The UI holds no model state except its own `laidOutRow`, `layout` and `lastStretch` caches (`SwitcherPresenter.swift:18-20`).
- **UI-only inputs:**
  - Reduce Motion (`NSWorkspace.accessibilityDisplayShouldReduceMotion`), read per render;
  - pointer location and display (`NSEvent.mouseLocation`, `NSScreen`);
  - backing scale;
  - icons from `AppIcons`.
- **Module layering:** LauncherUI depends only on LauncherCore (`Package.swift:15-19`), so it cannot see `LaunchTuning` or the Debug tuner in LauncherPlatform. The tuner's "Simulate Reduce motion" (`forceReduceMotion`) does not affect the switcher.

---

## Non-obvious things

1. **No "move" message exists, and the highlight already follows the fingers continuously.** The UI is not told only about selection changes. `position` is fractional, and the highlight's x is set (actions disabled) on every observed value. The "snap" is only the icon scale (0.12 s animation) and the haptic.
2. **"12 mm per icon" is in step-mm, not finger mm, on real hardware.** With `swipeFollowsCursor` on (shipped), step-mm = cursor points × 12/100. The plan's "6 mm changes the selection" (R5, R6, R13) is 6 step-mm = 50 cursor points, which is accelerated and speed-dependent. Physical mm match step-mm only under `.linear`, which every test uses (`InMemoryAdapters.swift:62`, `MultitouchTrackpads.swift:92` before the first `beginsSlide`). Test assertions in "mm" are therefore literal finger mm, but on hardware they are not.
3. **Finger speed already exists, but only inside `PointerCurve.cursorMove`,** as `velocity` in counts per nominal 120 Hz report. To drive a speed-scaled wave, speed would have to be:
   - recomputed in the UI from successive `travelMM`/`position` values and its own clock (the UI has no frame timestamps);
   - or added to `SwipePhase.moved` and `SwitcherSelection`, which are shared with the window switcher.

   The architecture also states "display links are banned" and "No code of ours runs per display frame" (`docs/architecture.md:21`). Code may run per input event while a switcher shows.
4. **The rubber band's actual maximum is about 0.111 items (about 11 pt), not 0.2.** The 0.2 constant (`switcherMaxStretch`) is the asymptote of the saturating curve; the overshoot clamp (0.25 items = 3 step-mm) stops the input first. The plan's R10 asks for up to 20 pt, "most within 3 mm".
5. **The stretch is shown as a decaying spring, not a held offset.** Each frame whose `stretch` changed (and is non-zero) restarts an additive spring from `stretch × pitch` toward 0.
   - If the fingers stop past the end, no more events arrive and the highlight springs back to the end icon while the fingers are still past it.
   - When the fingers turn back, `stretch` becomes 0 at once (travel restarts inside the list), no new spring is added, and the running spring finishes.
   - `lastStretch` de-duplicates identical values. Pushing further against the clamp leaves `stretch` unchanged, so no new kick.
6. **`shown` is rewritten on every move, even at the clamp.** The private `reportedMM` is part of `SwitcherSelection`'s synthesized `Equatable`, so the `Switcher` value always changes and the observer fires per event.
7. **The scale factor is a UI-side computation using a Core type.**
   - The model's row has no scale, and the pitch the presenter uses for the stretch spring is the scaled pitch.
   - `displayWidth` is the screen's full `frame.width`, not `visibleFrame`.
   - The panel is centred on the display's middle, not under the pointer; the pointer only chooses the display.
   - Travel per icon does not change with scale.
8. **Hide happens before the app switch is visible.** `shown = nil` and `bringToFront` happen in one main-actor turn. The fade starts later, when `Observations` yields. Reduce Motion skips the fade (`OverlayPanel.swift:98`).
9. **`.began` can produce no switcher** (nothing to switch to, gestures inactive, or another trackpad already showing one). Later `.moved` and `.ended` events are then ignored by the guards on `shown`, but the recognizer still blocks clicks until lift.
10. **Selection writes are `package(set)`.** `follow` and `SwitcherSelection.init` are `package`, so technically visible to LauncherUI (same package). The docs say only `Launcher` (and tests) write them.
11. **Reduce Motion is read in three UI places only:** the presenter's render (icon-scale animation and stretch spring), and `OverlayPanel.present`/`dismiss`. It is not read in LauncherCore.
12. **`OverlayPanel` imposes a rounded-rectangle glass container** (`OverlayPanel.swift:40-44`: `NSGlassEffectView(.regular)` plus `roundedClip`) on both switchers. A shape with "no rectangular panel" (R1) cannot simply subclass it unchanged without also changing the window switcher's base.

---

## Open questions

- **Trackpad frame rate.** I did not find a measured rate in code or docs. `PointerCurve.reportRate = 120` is the HID pointer report-rate constant used for acceleration, not a measurement of MultitouchSupport's frame cadence.
- **`Observations` coalescing.** I did not determine how much `Observations` coalesces back-to-back `.moved` events under load: how often the presenter skips intermediate values, and how far its resumption lags the main-queue block that wrote `shown`.
- **Swift 6.2 `@Observable` equality skip.** I did not verify whether the macro skips notification for equal `Equatable` values. Here it does not matter, because every `.moved` produces a different `Switcher` (see Non-obvious 6).
- **Lifecycle details I did not trace:**
  - how `SettingsShell` creates and holds `SwitcherPresenter` beyond `SettingsShell.swift:15, 28`;
  - `AppIcons.icon(forSwitcher:)`;
  - `GlassClip.roundedClip`.

  These are UI-side, outside this angle.
