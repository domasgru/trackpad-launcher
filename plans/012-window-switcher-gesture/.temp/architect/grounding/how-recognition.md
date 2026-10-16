# Grounding: recognition on the multitouch thread

Angle: how `GestureRecognizer` recognises and runs the swipe, what it emits, how frames get to it and events leave it, and how it is tested. Every path below is under `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/012-window-switcher-gesture/`. `LC` = `LauncherKit/Sources/LauncherCore`, `LP` = `LauncherKit/Sources/LauncherPlatform`, `T` = `LauncherKit/Tests/LauncherCoreTests`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `Recognition` | `LC/GestureRecognizer.swift:4-34` | What one frame produced: an optional `Event` plus two blocking flags, `blocksClicks` and `blocksDockSwipes`. |
| `Recognition.Event` | `LC/GestureRecognizer.swift:6-11` | Three cases: `.fired(Gesture)`, `.swipe(SwipePhase)`, `.swap(startsSeries: Bool)`. Convenience accessors `fired`, `swipe`, `swapStartsSeries` (lines 24-27). |
| `GestureRecognizer` | `LC/GestureRecognizer.swift:39-413` | A pure `Sendable` struct state machine for ONE trackpad. `step(_ TouchFrame) -> Recognition` (line 54). Owned by one frame thread or one test. |
| `GestureRecognizer.State` | `LC/GestureRecognizer.swift:379-402` | `idle`, `armed(Anchor)`, `tapping(Anchor, Tap)`, `resting(Anchor, Pair)`, `spoiled(Anchor)`, `rest(Rest)`, `swiping(Swipe)`. `anchor` (391-396) is nil for idle, rest and swiping; `thumb` (399-401) is the rest's thumb or the anchor. |
| `Anchor` | `:251-253` | Just a `TouchID`: the anchored thumb. |
| `Contact` / `ContactBook` | `:256-282` | Per contact down (after the edge filter): landing `origin`, `firstSeen` time, `isRealLanding`. `landingTime(of:)` returns nil for a contact already resting on the first frame. The only source of landing points and times. |
| `Pair` | `:285-299` | Exactly two fingers. `init?(tap, joining:)` succeeds only when nobody joins this frame, `tap.touched.count == 2` and `tap.fingers.count == 2`. `fingers` is `[first, second]` sorted by raw id. |
| `Tap` | `:353-377` | `start` time, `down` set, `touched` set (superset). `fingers` = `down` sorted by raw id. |
| `Rest` / `RestThumb` | `:302-318` | Fingers-first state (the swap's home): fingers, optional thumb with `canSwap`, `rolled` (thumbs that slid out), `isStopped`, `isSeries`. |
| `Swipe` | `:320-327` | `fingers: [TouchID: SurfacePoint]` (positions on the LAST frame, at most two), `lastTime`, `travelMM` (accumulated, in "step millimetres"), optional `thumb`. |
| `Move` | `:330-336` | One finger's displacement in mm from its landing point; `isSideways` is `abs(dxMM) > abs(dyMM)` (strict). |
| `drag(of:in:book:on:)` | `:339-351` | The farthest-moved finger (by `hypot`) among `fingers`, returned only if it is farther than `GestureRules.dragThresholdMM` (strictly). |
| `beginOrSpoil` | `:243-249` | Pair + sideways move -> `.swiping` + `.swipe(.began)`; anything else -> `.spoiled(anchor)` and no event. |
| `restOrIdle(of:)` | `:238-240` | `.idle` if no ids, else `.rest(Rest(fingers:))`. |
| `GestureRules` | `LC/GestureRules.swift:4-33` | Every fixed number: corner 20% x 25% (6,8), release margin 2 mm (10), edge band 3 mm (13) below 40% height (17), tap window 400 ms (19), `dragThresholdMM = 3.0` (21), click window 3 s (23), `switcherMaxApps = 10` (25), `switcherStepMM = 12.0` (27), stretch 0.2 (29), overshoot 0.25 (32). `package` enum. |
| `SwipePhase` | `LC/Gesture.swift:25-35` | `.began`, `.moved(travelMM: Double)`, `.ended`, `.cancelled`. |
| `SwipeEvent`, `GestureEvent`, `SwapEvent` | `LC/Gesture.swift:14-58` | The recognizer's events tagged with a `TrackpadID`. |
| `TrackpadEvent` | `LC/Ports.swift:3-18` | Port enum `.gesture/.swipe/.swap/.trackpadsChanged`; `init(_ Recognition.Event, on:)` is "the one mapping" used by both hardware adapters. |
| `TrackpadHardware` | `LC/Ports.swift:24-38` | Port: `onEvent`, `connected()`, `run(_:handMode:blockClicks:swipes:swaps:)`, `playFeedback`. Contract: events on main, in frame order, never from a replaced session (25-27). |
| `Touch`, `TouchID`, `TouchFrame`, `FrameTime`, `TouchFrame.Press` | `LC/Touch.swift` | Domain frame types. `Touch.phase` `.landing/.down`; `isLanding(after:)` (28-30) treats a new id as landed. `TouchFrame` is a complete snapshot (46-58). `Press` `.click` (delivered to apps, cancels) / `.blocked` (withheld). `Press.init?(holding:buttonDown:)` (72-82) is the precedence rule. |
| `SurfacePoint`, `SurfaceSize` | `LC/Surface.swift:5-29` | Normalised position, x 0 = left, 1 = right; **y 0 = TOP, 1 = bottom**. Size in mm. |
| `AnchorCorner` | `LC/Surface.swift:32-56` | `admits` (landing inside 20% x 25%), `holds` (zone grown by 2 mm). Hand mode picks the side via `fractionFromThumbSideEdge`. |
| `EdgeContacts` | `LC/Surface.swift:61-93` | Filters edge contacts out of each frame before the state machine sees them; judged at landing, kept while down. |
| `HandMode` | `LC/HandMode.swift` | `.right/.left`; `fractionFromHandSideEdge(x:)`, `fractionFromThumbSideEdge(x:)`. Only corner and edge band depend on it. |
| `Trackpad`, `TrackpadID`, `TrackpadKind` | `LC/Trackpad.swift` | Device id (MT device id), kind, `surface`. |
| `Gesture` | `LC/Gesture.swift:4-11` | `.one ... .five`; `init?(fingerCount:)` nil outside 1...5. |
| `PointerCurve` | `LC/PointerCurve.swift:7-130` | Reproduces macOS's IOHID trackpad pointer acceleration. `cursorPoints(dxMM:dyMM:interval:)` (93-100) returns **x-axis** cursor points for one report. |
| `SwipeTravel` | `LC/PointerCurve.swift:133-151` | `.linear` (returns `dxMM`) or `.cursor(PointerCurve, pointsPerIcon:)` (cursor points / pointsPerIcon x 12). `shippedPointsPerIcon = 100` (140). `travel(dxMM:dyMM:interval:)` is internal (142). |
| `CursorTravel` | `LP/CursorTravel.swift:7-44` | Reads `com.apple.trackpad.scaling` via `CFPreferencesCopyAppValue` (14-17), the device's `HIDAccelCurves` from IORegistry (21-34, fallback `builtInCurves`), and builds the `SwipeTravel` for a swipe starting now (37-43). |
| `LaunchTuning` swipe fields | `LP/LaunchTuning.swift:39-44, 47-52` | `swipeFollowsCursor = true`, `swipePointsPerIcon = 100`, `swipeTrackingSpeed = -1` (use System Settings). `current` is `shipped` in Release, the DEBUG tuner's `tunerOverride` Mutex (`LP/AnimationTuner.swift:9`) in Debug. |
| `DeviceSession` | `LP/FrameStream.swift:8-56` | One running trackpad: `Mutex<GestureRecognizer>`, its `pointerCurves`, two `Mutex<Bool>` blocking flags, the `ClickTap?`, and `deliver`. |
| `sessions` | `LP/FrameStream.swift:61` | Global `Mutex<[UInt: DeviceSession]>` keyed by device ref bit pattern. |
| `contactFrameCallback` | `LP/FrameStream.swift:63-68` | The C callback MultitouchSupport calls on its thread. |
| `anyTrackpadBlocksClicks()` / `anyTrackpadBlocksDockSwipes()` | `LP/FrameStream.swift:77-85` | Merge flags across sessions for the click tap's thread. |
| `MultitouchTrackpads` | `LP/MultitouchTrackpads.swift:10-164` | The real `TrackpadHardware`: IOKit hot-plug, wake, `run`, actuators. |
| `MultitouchSupport` | `LP/MultitouchSupport.swift:7-71` | `dlopen` + `dlsym` of the private framework; any missing symbol fails the whole load. |
| `MTTouchMirror`, `TouchFrame.init(parsing:...)` | `LP/TouchFrameParsing.swift` | The 96-byte `MTTouch` layout; keeps only states 3 (makeTouch -> `.landing`) and 4 (touching -> `.down`); flips y (`1 - normalizedY`, line 51). |

## Flow

### A. Frames arrive and events leave (platform)

1. **`MultitouchTrackpads.run(...)`** (`LP/MultitouchTrackpads.swift:66-113`), main actor. Increments `runs` (67) **before** the `framework` guard. Empties `sessions` first (69), removes the click tap (71-72), unregisters and stops every started device (73-77), closes actuators. Then, for each wanted device, builds a `DeviceSession` with a **fresh** `GestureRecognizer(handMode:surface:swipes:swaps:travel: .linear)` (90), the device's curves `CursorTravel.curves(of: framework.getService(ref))` (91), the shared `clickTap`, and a `deliver` closure that captures `generation = runs` (82). It inserts the session into `sessions` (108), then registers the callback and starts the device (109-110).
2. **`contactFrameCallback`** (`LP/FrameStream.swift:63-68`), framework thread. Looks the session up under the `sessions` lock (64) (a frame for a torn-down device finds nothing and returns). Samples the press as `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())` (65): `holding` is the click filter's summary, `anyMouseButtonDown` is `CGEventSource.buttonState` (71-73). Parses `MTTouch[]` into a `TouchFrame` (`LP/TouchFrameParsing.swift:40-55`) and calls `session.receive`.
3. **`DeviceSession.receive`** (`LP/FrameStream.swift:33-46`). Under the recognizer's Mutex: `step(frame)`; **if `recognition.swipe == .began`, replaces `recognizer.travel` with `CursorTravel.travel(curves: pointerCurves)`** (38). Comment (36-37): each swipe uses the tracking speed set when it starts; travel is 0 on the begin frame, so the next frame is the first to use it. Then writes `blocking` and `blockingDockSwipes` Mutexes (41-42), and if there is an event, `deliver(TrackpadEvent(event, on: trackpad))` (43-45).
4. **`deliver`** (`LP/MultitouchTrackpads.swift:93-102`): `DispatchQueue.main.async { MainActor.assumeIsolated { guard let self, self.runs == generation else { return }; self.onEvent?(event) } }`. FIFO from one frame thread keeps frame order; a stale session's events are dropped ("a stale swipe start could never be ended", 95).
5. **`Launcher.start`** installs `onEvent` (`LC/Launcher.swift:68-75`): `.swipe(let event) -> swipe(event)` (71). `Launcher.swipe(_:)` (`LC/Launcher.swift:205-236`) handles `.began` (reads running apps, builds `Switcher`), `.moved(let travel)` (`Switcher.follow(travel)`, one light tick per selection change), `.ended` (bring to front unless frontmost / quit), `.cancelled` (drop switcher).
6. **Click tap thread** (`LP/ClickTap.swift:63-87`) reads `anyTrackpadBlocksClicks()` once per event (75) and feeds it to `ClickFilter` (pointer) or `ScrollFilter` (scroll); reads `anyTrackpadBlocksDockSwipes()` for Dock swipes (83).

Mutex discipline (as written in code comments):
- `DeviceSession.recognizer`: stepped only by that device's frame callbacks; "the Mutex is the compiler's proof of that and is never contended" (`LP/FrameStream.swift:6-7`).
- `blocking` / `blockingDockSwipes`: writer = frame callback, reader = click tap thread (13-16).
- `sessions`: written by `run` (main), read by the callback and the click tap (58-61).
- `anyTrackpadBlocks*` copy the sessions out of the lock first "so no lock is held while another is taken" (76, 78, 84). `ClickTap.handle` reads `blocking` "once, before either filter lock, so no two locks are held at once" (`LP/ClickTap.swift:74`).
- `CursorTravel.travel` (called inside the recognizer lock at line 38) reads `LaunchTuning.current`, which in DEBUG takes the `tunerOverride` Mutex, and `CFPreferencesCopyAppValue` — on the frame thread, once per swipe begin.

Session replacement rule: `Launcher.reconcile` (`LC/Launcher.swift:174-189`) calls `hardware.run` only when the `Run` value (trackpads, handMode, blockClicks, swipes, swaps; 158-164) changed or `restart` is set, and sets `switcher = nil` first (187) because "Running replaces every recognizer, which ends any swipe in progress". `setSwipe(on:)` (127-) goes through reconcile. A window-swipe setting would need a field here and a parameter on `run` (`LC/Ports.swift:35`, `LP/MultitouchTrackpads.swift:66`, the in-memory `run` at `T/InMemoryAdapters.swift:44`) to reach the recognizer `init`.

### B. One `step` (`LC/GestureRecognizer.swift:54-189`)

Preamble, every frame:
1. `edgeContacts.fingers(in: frame)` (55): edge contacts removed from `touches` before anything else. So they never land, lift, join, cancel, or count as "another finger" for blocking.
2. `isFirstFrame = previouslyDown == nil` (56); `before` = ids down last frame.
3. `down` = this frame's contacts by id (58). `reused` = ids that reappear with `.landing` (driver reused the id; 59). `lifted = before - down ∪ reused` (60). `landed` = contacts with `isLanding(after: before)` (61).
4. Book update: `departed = book.contacts(of: lifted)` captured before removal (64, used by the swap); lifted removed (65); landed added with `origin = touch.position`, `firstSeen = frame.time`, `isRealLanding = !isFirstFrame || touch.phase == .landing` (66-71).
5. **Anchor check** (73-76): if the state has an `anchor` (armed, tapping, resting, spoiled) and that anchor lifted or is outside `corner.holds`, state becomes `restOrIdle(of: down ids not landed this frame)`. Swiping and rest are exempt (their `anchor` is nil).

Then the switch (78-169):

- **`.idle`** (80-86): a landed contact admitted by the corner becomes the anchor: `.armed` if it is the only contact down, `.spoiled` otherwise (any other contact down). Other landings -> `.rest(Rest(fingers: landed))` (fingers-first).
- **`.armed(anchor)`** (87-91): any non-anchor landing starts `.tapping(anchor, Tap(start: frame.time, landing:))`, unless the frame carries `press == .click` -> `.spoiled`.
- **`.tapping(anchor, tap)`** (92-110), in this order:
  1. lifted ids leave `tap.down` (93);
  2. `joining` = non-anchor landings (94);
  3. `pair = swipes ? Pair(tap, joining:) : nil` (95) — **the swipe setting gates the pair here**;
  4. `press == .click` -> `.spoiled` (96-97);
  5. else if `drag(of: tap.fingers ...)` is past 3 mm -> `beginOrSpoil(pair, move, anchor, down, time)` (98-99);
  6. else if the tap is older than 400 ms -> `.resting(anchor, pair)` if a pair exists, else `.spoiled` (100-101);
  7. else if all tap fingers lifted -> `.fired(Gesture(fingerCount: tap.touched.count))` and back to `.armed`, or a new `.tapping` if someone landed this same frame (102-104);
  8. else joining fingers `tap.land(id)` (105-109).
- **`.resting(anchor, pair)`** (111-118): a click, either pair finger lifting, or any non-anchor landing -> `.spoiled`. Else a drag past 3 mm -> `beginOrSpoil` (same function, same sideways rule).
- **`.spoiled(anchor)`** (119-122): stays until every contact down is the anchor, then `.armed`. Nothing fires, nothing begins. (The anchor check at 73-76 can still move it to `.rest` / `.idle` if the thumb lifts or leaves.)
- **`.rest(rest)`** (123-124): the fingers-first state machine (`step(_ rest:...)`, 192-235), the swap. Not reachable for a swipe start.
- **`.swiping(swipe)`** (125-168), in order:
  1. Thumb bookkeeping (126-133): if the remembered thumb lifted or left `corner.holds`, forget it; if no thumb is remembered, a contact landing inside `corner.admits` becomes the remembered thumb. Comment: "The thumb plays no part in a swipe: it is only remembered for what happens after it."
  2. `after = swipe.thumb.map(State.spoiled) ?? restOrIdle(of: down.keys)` (135): the state after an end or cancel. With a thumb: spoiled (waits for every other contact to lift, then armed). Without: a rest of everything still down, or idle.
  3. Lifted ids leave `swipe.fingers` (138). `joining` = landings that are not the remembered thumb and not `corner.admits` (139) — a finger landing in the anchor corner never joins nor cancels.
  4. **Cancel** (140-142): `press == .click` or `swipe.fingers.count + joining.count > 2` -> `after`, `.swipe(.cancelled)`. So a third finger only cancels while both swipe fingers are still down; with one finger down a new landing is a rejoin.
  5. **End** (143-146): `swipe.fingers.isEmpty` -> `after`, `.swipe(.ended)`. Both fingers must have lifted. A finger landing on that frame "starts nothing" (it ends up in `after`: spoiled or a rest).
  6. **Move** (147-167): `moves` = for each swipe finger still down, `(x_now - x_last, y_now - y_last)` in normalised units (150-152) — only fingers present on both frames, "so a finger dropping out or rejoining never makes the highlight jump" (148-149). `interval` = seconds since `swipe.lastTime` (153). Then positions are updated, joining fingers are added at their landing position (154-155) (rejoin), `lastTime` set (156). If there were moves: `dxMM` = mean dx x `surface.widthMM`, `dyMM` = mean dy x `surface.heightMM` (158-160); `travel = swipe.travelMM + self.travel.travel(dxMM:dyMM:interval:)` (161); only if it changed, store it and emit `.swipe(.moved(travelMM: travel))` (162-165).

Blocking flags (170-187):
- `.swiping` -> both true (172-174).
- `.rest` with `isSeries` -> both true (175-177).
- otherwise, with `thumb = state.thumb`: `blocksDockSwipes` = a thumb and any other contact down (180); `blocksClicks` = additionally the thumb's real landing time is less than 3 s ago (181-186). A thumb resting on the first frame (`isRealLanding == false`) never opens the click window.

### C. How a swipe begins (`beginOrSpoil`, `:243-249`)

- Requires `pair != nil` (so `swipes == true`, exactly two fingers touched since the last moment none was down, both still down, nobody joining this frame) **and** `move.isSideways`.
- The move tested is the single farthest-moved finger (by Euclidean mm from its own landing point), only when that distance exceeds 3 mm (`drag`, 339-351). `isSideways` compares that finger's |dx| vs |dy| at that frame (strict `>`; a tie is not sideways). Test: `(dx: 3.0, dy: 2.9)` begins, `(2.9, 3.0)` does not (`T/SwipeRecognizerTests.swift:44-48`).
- `Swipe.fingers` is initialised from the pair's **current** positions (247), `lastTime = time`, `thumb = anchor`, `travelMM = 0`. Event `.swipe(.began)`.
- Any failure (no pair, not sideways) returns `.spoiled(anchor)` with no event.

### D. What "spoiled" means for a pair that drags more up/down than sideways (today)

Confirmed by code and tests:
- `tapping` or `resting` + vertical first drag past 3 mm -> `beginOrSpoil` -> `.spoiled(anchor)` (`:246`).
- In `.spoiled` nothing fires and no swipe can begin; later sideways movement is ignored (`T/SwipeRecognizerTests.swift:38-42` `movingUpOrDownFirstIsNeverASwipeAndTheNextTapStillFires`: `slide(0,10)` then `slide(20,0)` -> no phases; the next tap fires `.two`). The direction decision is therefore already "once" for the swipe: vertical-first is permanent until every non-thumb contact lifts, then `.armed`.
- Blocking while spoiled follows the thumb rules (`:179-186`): clicks and scrolling are blocked only while the thumb (a real landing) is younger than 3 s and another contact is down; Dock swipes are blocked for as long as the thumb is anchored and another contact is down, no time limit. `T/ScrollSuppressionTests.swift:8-13`: vertical slide inside the window -> `scroll(.fingers(.began)) == .drop`, `switcher == nil`. After 3 s scrolling passes (`:15-23`).
- If the thumb lifts or leaves the corner while spoiled, the anchor check (73-76) turns the state into `.rest` of the remaining contacts (so a later thumb landing under them is fingers-first: swap rules).
- With `swipes == false` the pair is nil (95), so a sideways drag spoils exactly the same way, and a pair past 400 ms goes straight to `.spoiled` instead of `.resting` (101). `T/SwipeRecognizerTests.swift:132-142` and `T/ClickBlockingRecognizerTests.swift:12-29`.

### E. Travel accumulation (`travelMM`)

- Units: "step millimetres" — 12 per icon (`GestureRules.switcherStepMM`). `Switcher.selected` = `round(travelMM / 12)` half away from zero, clamped (`LC/Switcher.swift:32-35`); `follow(_:)` turns the absolute reported travel into per-frame deltas, clamps overshoot to 0.25 icon and implements the turn-back rule (43-53).
- `.linear` (`LC/PointerCurve.swift:145`): travel += mean `dxMM`. Used by every test and by the real recognizer until a swipe begins (`LP/MultitouchTrackpads.swift:90`).
- `.cursor(curve, pointsPerIcon)` (146-148): `curve.cursorPoints(dxMM:dyMM:interval:) / pointsPerIcon * 12`. With `pointsPerIcon = 100` (`SwipeTravel.shippedPointsPerIcon`, 140; `LaunchTuning.swipePointsPerIcon`), 100 cursor points = one icon = 12 step mm. This is the "100 points per icon" rule.
- `PointerCurve.cursorPoints` (93-100): converts mm to counts (400 counts/inch), computes a velocity from `hypot(dx, dy)` scaled by report-rate (120 Hz) vs `interval`, and returns **`dx * multiplier(velocity) / velocity`** — the x component of the accelerated vector. `dy` only affects speed (acceleration), never direction. The curve is chosen/interpolated by tracking speed in `init?(_:trackingSpeed:)` (50-89).
- Tracking speed and curves: `CursorTravel.travel(curves:)` (`LP/CursorTravel.swift:37-43`): `.linear` if tuning disables cursor travel or no curves; else `.cursor(PointerCurve(curves, trackingSpeed: speed), pointsPerIcon: tuning.swipePointsPerIcon)`; `speed` = tuner value if >= 0 else `trackingSpeed()` read fresh from `com.apple.trackpad.scaling` (default 0.6875). It is read at each swipe begin because nothing pushes changes to that key (11-13).
- Sign and axis: positive = finger moved right (x grows), in both hand modes (x is never mirrored for hand mode). `SurfacePoint.y` grows downward (`LC/Surface.swift:3`; flip in `LP/TouchFrameParsing.swift:51`), so a positive `dyMM` is a slide toward the user ("down").
- Travel is measured **from where the swipe began, not from where the fingers landed**: `Swipe.fingers` starts at the begin-frame positions and the begin frame emits `.began` with travel 0. `T/SwipeTravelAndExitTests.swift:20-28`: begin with `slide(3.5, 0)` (began fires at ~3.15 mm), then `slide(12, 0)` reports `12.35`, `slide(-12, 0)` reports `-11.65`. `:30-41`: one finger moving 4 mm per frame, the other still -> `.began` then `.moved(2), (4), (6)...` (midpoint, pre-begin 4 mm not counted). Plan 006 recorded this as an open question (`plans/006-five-finger-tap-and-corner-swipe/plan.md:1365`).
- With one finger down (the other lifted), `moves.count == 1` so travel follows that finger alone, not half of it (`T/SwipeTravelAndExitTests.swift:51-61`: 66 -> 80 gives `.moved(14)`).

### F. Ending, rejoin, cancel, thumb, edge contacts, hand modes

- **End**: both swipe fingers lifted (`:143-146`). The whole hand lifting in one frame ends it, the thumb lift that frame does not cancel (`T/SwipeTravelAndExitTests.swift:87-97`).
- **Rejoin**: a finger lifts (`swipe.fingers` drops to 1), a new contact lands outside the corner while the other is down: `1 + 1 > 2` is false, so it joins at its landing point with no jump (`T/SwipeTravelAndExitTests.swift:63-75`).
- **Third finger cancel**: landing outside the corner while both are down (`T/SwipeRecognizerTests.swift:109-120`, `T/SwipeTravelAndExitTests.swift:77-85, 148-154`). Two fingers lifting while a third lands on the same frame is an **end**, not a cancel (`:175-185`), because the lifted ids leave first.
- **Click cancel**: `press == .click` on any swiping frame; `.blocked` (withheld) leaves it alone (`T/SwipeTravelAndExitTests.swift:187-204`).
- **Thumb after the begin**: may lift, roll out, land again; the swipe goes on and blocks throughout (`T/SwipeTravelAndExitTests.swift:110-146, 206-218`). After the end: a remembered thumb -> spoiled -> armed once the hand is up; a thumb that rolled out and back is a rest finger and arms nothing until it lands anew (`:135-146`). A thumb landing on the exit frame is the anchor afterwards (`:156-173`).
- **After end/cancel**, blocking is the thumb rules again (`:99-108`, `:211-218`).
- **Edge contacts**: removed at line 55 by `EdgeContacts.fingers(in:)` (`LC/Surface.swift:73-85`), judged at landing (inside the band if < 3 mm from the bottom edge, or < 3 mm from the hand-side edge and > 40% down). So they cannot start, join, rejoin or cancel a swipe (`T/EdgeContactRecognizerTests.swift:274-283, 304-315`), and a finger at the top edge does take part (`:137-147`).
- **Hand modes**: only `AnchorCorner` and `EdgeContacts` read `HandMode`. Swipe travel is not mirrored (`T/SwipeTravelAndExitTests.swift:14-28` runs both modes on both surfaces).

### G. The tap-with-drift case

- A 2-finger tap whose fingers drift less than or equal to 3 mm never triggers `drag` (`:350` strict `>`), so `tap.down.isEmpty` fires `.two` at the lift (`:102-103`). `T/GestureRecognizerTests.swift:127-131` (`dragMM: 2.5` fires, `3.5` does not). The drag check only sees fingers still down (`tap.fingers` = `down`), so a lift frame never counts as a drag.
- A 2-finger tap drifting more than 3 mm sideways **becomes a swipe** (`.began` ... `.ended`) and fires no tap (`T/SwipeRecognizerTests.swift:122-130`); the model then sees a swipe whose travel is under 1 mm and lifts on the frontmost app (silent).
- More than 3 mm vertically: spoiled, no tap, no swipe.
- R1's "drifts 2 mm down" needs no recognizer change: it is below the threshold. Note `TouchScript.tap(dragMM:)` only drags along x (`T/TouchScript.swift:87-89`); a vertical drift is scriptable as `thumb.land(fingers: 2).slide(byMM: (0, 2)).lift()` (lift at +110 ms, inside 400 ms).

## Recognition.Event and SwipePhase payloads (exact)

```swift
// LC/GestureRecognizer.swift:6-11
public enum Event: Equatable, Sendable {
    case fired(Gesture)
    case swipe(SwipePhase)
    case swap(startsSeries: Bool)
}
// LC/Gesture.swift:25-35
public enum SwipePhase: Equatable, Sendable {
    case began
    case moved(travelMM: Double)
    case ended
    case cancelled
}
```

- `.moved(travelMM:)`: absolute (not a delta) accumulated travel since `.began`, signed, positive right, x axis only, in step millimetres (12 per icon), sent only when it changed. `.began` carries no payload; travel is 0 on that frame. No direction or axis is carried anywhere.
- `Recognition` is also returned on frames with no event, with the two flags.
- `TrackpadEvent.init(_:on:)` (`LC/Ports.swift:11-17`) is an exhaustive switch over `Recognition.Event`, so a new case or payload must be mapped there; `Launcher.start`'s `onEvent` switch (`LC/Launcher.swift:69-74`) is exhaustive over `TrackpadEvent`.

## Testing shape

- **Units**: `TouchScript` (`T/TouchScript.swift`) takes positions in **millimetres from the top-left** (`SurfaceSize.point(mm:_:)`, `T/Fixtures.swift:10-12`, converting to normalised), y grows downward. Time: frames every **10 ms**, `FrameTime.seconds = 1.0 + ms/1000` (`T/TouchScript.swift:220`). `.landing` on a contact's first frame. The thumb is id 100 (47), fingers 1, 2, ... in order. Fingers from `land`/`tap` are placed 8 mm apart in x (`:85`, `:139`). `slide(byMM:over:)` moves every non-thumb finger that is down, by `(x, y)`, linearly over `over` (default 100 ms) (`:146-154`). `lift()` lifts one frame after the cursor (`:158-175`). `thumb(atMM:)` advances the cursor 50 ms (`:60-67`). `press()` holds `.click` until the next lift.
- `HandFrames` (`T/Fixtures.swift:82-96`) hand-builds frames for interleavings the script cannot express: `h.contact(id, phase, atMM: x, y)`, `h.frame(atMS:, touches, press:)`.
- **Drivers**: `fired(_:)`, `phases(_:)`, `swaps(_:)`, `perFrame(_:)` (`T/Fixtures.swift:21-67`) each build a fresh `GestureRecognizer(..., travel: .linear)` and step every frame, returning gestures, swipe phases, swap flags, or `(swipe, blocksClicks)` per frame. `phasesMatch` compares `.moved` within 1e-9 (69-79). `EdgeContactRecognizerTests` has its own `Track` builder and `recognitions` helper (`T/EdgeContactRecognizerTests.swift:10-61`).
- **Model-level**: `World` (`T/World.swift`) drives the real `Launcher` over `InMemoryTrackpads` (`T/InMemoryAdapters.swift:5-119`). `world.play(script)` delivers only frames newer than any already delivered on that trackpad (`T/World.swift:167-172`), so a hand can be played in pieces. `World.swipe(_ slidesMM: Double...)` slides **x only** (`:235-241`). `InMemoryTrackpads.touch` (`T/InMemoryAdapters.swift:77-91`) steps the recognizer, stores `blocksClicks`, maps events through `TrackpadEvent(event, on:)` synchronously, and runs presses and scrolls through real `ClickFilter`/`ScrollFilter` on those flags. The in-memory `run` always builds recognizers with `travel: .linear` (`:48`); the cursor curve is only covered by `T/PointerCurveTests.swift` (unit tests of `PointerCurve` and `SwipeTravel`, all with `dyMM: 0` except `SwipeTravel.linear.travel(dxMM: 3, dyMM: 9, ...) == 3`, line 51).
- Representative test (`T/SwipeRecognizerTests.swift:38-48`):

```swift
@Test func movingUpOrDownFirstIsNeverASwipeAndTheNextTapStillFires() {
    let frames = thumb.land(fingers: 2).slide(byMM: (0, 10)).slide(byMM: (20, 0)).lift().tap(fingers: 2).frames
    #expect(phases(frames).isEmpty)
    #expect(fired(frames) == [.two])
}

@Test(arguments: [(dx: 3.0, dy: 2.9, begins: true), (dx: 2.9, dy: 3.0, begins: false)])
func theMoveMustBeMoreSidewaysThanVerticalWhereItPassesThreeMillimetres(dx: Double, dy: Double, begins: Bool) {
    let frames = thumb.land(fingers: 2).slide(byMM: (dx, dy)).lift().frames
    #expect(phases(frames).first == (begins ? .began : nil))
}
```
  where `thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))`.
- The first of these is a test that a window swipe would have to change (with the window swipe on, `slide(0, 10)` would begin a window swipe); `T/SwipeRecognizerTests.swift:82-91` (`aRestingPairThatIsDisturbedOrMovesVerticallyNeverSwipes`, second argument) and `T/ScrollSuppressionTests.swift:8-13` (vertical slide shows no switcher) likewise encode today's vertical-spoils rule.

## Boundaries

- **In**: `TouchFrame` per device frame (touches with id, phase, normalised top-left position; time; sampled press). Constructor inputs: `handMode`, `surface`, `swipes`, `swaps`, `travel`. Only `travel` is mutable after construction (`public var`, `:52`), set by `DeviceSession` at a swipe's begin.
- **Out**: `Recognition` per frame: `event?` (to the main actor via `TrackpadEvent`) and `blocksClicks` / `blocksDockSwipes` (to the click tap thread via per-session Mutexes merged across trackpads).
- **Configuration path**: `Settings.isSwipeOn` / `isSwapOn` -> `Launcher.reconcile` `Run` -> `TrackpadHardware.run(swipes:swaps:)` -> `GestureRecognizer.init`. A changed setting replaces every recognizer (ending any swipe).
- **Platform reads on the frame thread**: `CursorTravel.travel(curves:)` at begin (CFPreferences + `LaunchTuning.current`); `anyMouseButtonDown()`; `ClickTap.holding`.
- Blocking decisions downstream (`ClickFilter`, `ScrollFilter`, `DockSwipeFilter`) know nothing about swipes; they see one merged Bool each, read when an event arrives (`LC/ScrollFilter.swift:25-30`).

## Where the window swipe's requirements touch the recognizer (places only, no design)

- **Direction decision**: `beginOrSpoil` `LC/GestureRecognizer.swift:243-249` (`guard let pair, move.isSideways else { return (.spoiled(anchor), nil) }`) is the single place a slide's direction is decided, reached from `.tapping` (`:98-99`) and `.resting` (`:116-117`). `Move.isSideways` `:335` is strict, so an exact diagonal tie is not sideways today (it spoils).
- **Setting gate**: `let pair = swipes ? Pair(tap, joining:) : nil` (`:95`) and `pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)` (`:101`) tie the pair, and the `.resting` state, to the swipe setting; R16's "swipe off, window swipe on" scenario passes through these lines. Constructor `:43-50` and stored flags `:406-407`.
- **State**: `State.swiping(Swipe)` `:388` and the `.swiping` case `:125-168` (thumb memory, cancel, end, rejoin, movement) are what R15 asks to "match"; `State.anchor` `:391-396` exempts `.swiping` from the top-of-step anchor check.
- **Vertical travel**: movement accumulation `:157-165` computes both `dxMM` and `dyMM` but `SwipeTravel.travel` (`LC/PointerCurve.swift:142-150`) returns only the x component: `.linear` returns `dxMM`; `.cursor` uses `PointerCurve.cursorPoints` (`:93-100`), which returns `dx * multiplier / velocity`. A y component would need a counterpart there. `Swipe.travelMM` `:325` is a single scalar.
- **Blocking**: `if case .swiping = state` `:172` is what holds `blocksClicks` and `blocksDockSwipes` true for the whole swipe.
- **Event**: `Recognition.Event` `:6-11` (`.swipe(SwipePhase)` carries no direction), the accessor `Recognition.swipe` `:25`, `SwipePhase` / `SwipeEvent` `LC/Gesture.swift:25-46`, `TrackpadEvent` `LC/Ports.swift:3-17`, `Launcher.start` switch `LC/Launcher.swift:69-74`.
- **Per-begin travel hook**: `LP/FrameStream.swift:38` triggers only on `recognition.swipe == .began`; a window swipe's begin would not get the cursor curve unless this condition covers it.
- **Settings plumbing**: `TrackpadHardware.run` (`LC/Ports.swift:35`), `MultitouchTrackpads.run` (`LP/MultitouchTrackpads.swift:66, 90`), `InMemoryTrackpads.run` (`T/InMemoryAdapters.swift:44-49`), `Launcher.Run` (`LC/Launcher.swift:158-164, 181-183`), every `GestureRecognizer(...)` call in the tests (`T/Fixtures.swift:28,40,51,62`, `T/ClickBlockingRecognizerTests.swift:8,13`, `T/EdgeContactRecognizerTests.swift:41`, `T/SwapRecognizerTests.swift:32`, `T/DockSwipeBlockingRecognizerTests.swift`, `T/GestureRecognizerTests.swift`).
- **Test fixtures**: `World.swipe` x only (`T/World.swift:235-241`); `TouchScript.tap(dragMM:)` and `thumbTap(dragMM:)` x only (`T/TouchScript.swift:87-89, 117-119`); `phases`/`perFrame` return `SwipePhase` only (`T/Fixtures.swift:33-67`).

## Non-Obvious Things

1. **Stale doc comments on `SwipePhase`** (`LC/Gesture.swift:26-34`): `.ended` says "The first of the two fingers lifted" but the code ends only when **both** have lifted (`:143-146`); `.moved` says "in trackpad millimetres" but with `.cursor` travel (the shipped default) it is step millimetres from the cursor curve (12 per 100 cursor points); `.cancelled` says "A finger landed outside the anchor corner" but only a third finger while both are down cancels. `Switcher.travelMM`'s doc (`LC/Switcher.swift:13`) also says "trackpad millimetres". Test name `theFirstFingerToLiftEndsTheSwipe...` (`T/SwipeTravelAndExitTests.swift:43`) is likewise historical; its assertions hold with the both-fingers rule.
2. **R9's premise does not match today's code.** R9 says "The selection MUST be measured from where the fingers landed, so the 3 mm that start the window swipe count towards the first row, as in the app switcher." The app switcher's travel is measured from the **begin** position: `.began` carries 0 and `Swipe.fingers` is initialised from the begin-frame positions (`:247`); tests assert it (`T/SwipeTravelAndExitTests.swift:26-27, 39`; `T/EdgeContactRecognizerTests.swift:144`). The landing points do exist in `ContactBook` (`origin`).
3. **The swipe already ignores vertical movement for direction**: once begun, pure vertical drift produces no `.moved` at all (linear: `dxMM` = 0; cursor: `dx * ...` = 0, and the event is sent only when travel changed). `dy` still raises velocity in cursor mode, so a diagonal slide accelerates x travel more than a pure sideways one of the same dx. R2's "vertical drift during a swipe" already holds today; "decided once" is structurally true for the swipe because spoiled is terminal until the hand lifts.
4. **The drag check uses the farthest single finger, from its own landing point**, and the direction test uses that same finger's dx/dy, not the midpoint. Midpoint (mean of fingers present on both frames) is used only for travel after the begin.
5. **`travel` is replaced on the frame thread inside the recognizer's lock** right after the begin frame (`LP/FrameStream.swift:38`), and never reset to `.linear` afterwards; the next begin overwrites it. Tests never exercise `.cursor` through the recognizer (all `.linear`).
6. **`runs` is incremented before the `framework` guard** (`LP/MultitouchTrackpads.swift:67-68`), so even a failed load invalidates older deliveries.
7. **The thumb is not part of the swipe's finger accounting**: a contact landing in the anchor corner during a swipe never joins or cancels (`:139`), and becomes the remembered thumb if none is remembered (`:131-133`). A finger landing inside the corner as a "third finger" therefore does not cancel.
8. **Spoiled after the thumb leaves becomes a rest**: if the anchor lifts while a vertical pair is spoiled, the anchor check (`:73-76`) turns the remaining fingers into `.rest`, so a new thumb landing under them follows the swap rules.
9. **On the frame that ends a swipe, a landing finger starts nothing**; with a remembered thumb the state is `.spoiled`, so even that new finger must lift before anything can fire.
10. **`blocksClicks` during a swipe is unconditional on the clock**; outside a swipe it depends on `isRealLanding`, so a thumb already resting when recognition (re)started never opens the 3 s window but does block Dock swipes (`T/DockSwipeBlockingRecognizerTests.swift:24`).
11. `GestureRules` is `package`, `SwipeTravel.travel` is internal, `GestureRecognizer`'s nested types are private: tests can only observe `Recognition`.

## Files Read

- `docs/architecture.md`, `docs/domain-model.md`
- `plans/012-window-switcher-gesture/plan.md` (R1-R17 skimmed; R1, R2, R9, R15, R16 read), `plans/012-window-switcher-gesture/development-logs.md`
- `plans/009-app-switch-gesture/plan.md` (decisions 1-5, via grep), `plans/006-five-finger-tap-and-corner-swipe/plan.md` (lines 59, 135, 1365, 1427 via grep)
- `LC/GestureRecognizer.swift`, `LC/GestureRules.swift`, `LC/Touch.swift`, `LC/Surface.swift`, `LC/Gesture.swift`, `LC/Trackpad.swift`, `LC/HandMode.swift`, `LC/PointerCurve.swift`, `LC/Ports.swift`, `LC/Switcher.swift`, `LC/ScrollFilter.swift`, `LC/Launcher.swift` (lines 55-80, 150-240)
- `LP/FrameStream.swift`, `LP/MultitouchTrackpads.swift`, `LP/MultitouchSupport.swift`, `LP/TouchFrameParsing.swift`, `LP/CursorTravel.swift`, `LP/LaunchTuning.swift` (1-60, grep), `LP/ClickTap.swift` (60-110), `LP/AnimationTuner.swift` (grep)
- `T/TouchScript.swift`, `T/Fixtures.swift`, `T/World.swift`, `T/InMemoryAdapters.swift` (1-120), `T/SwipeRecognizerTests.swift`, `T/SwipeTravelAndExitTests.swift`, `T/GestureRecognizerTests.swift` (1-50, 118-160, test list), `T/EdgeContactRecognizerTests.swift` (1-66, 130-150, 270-316), `T/SwapRecognizerTests.swift` (1-45), `T/PointerCurveTests.swift`, `T/ScrollSuppressionTests.swift` (1-80), `T/ClickBlockingRecognizerTests.swift` (1-30), `T/DockSwipeBlockingRecognizerTests.swift` (38-53)

## Open Questions

- Whether `PointerCurve.cursorPoints`'s IOHID reproduction is valid for the y axis by symmetry (it computes velocity from `hypot(dx, dy)` and scales one component; the y component would be `dy * multiplier / velocity`). Nothing in the code or tests covers y; I did not verify against IOHIDFamily source.
- I did not read `SwitcherOnScreenTests.swift`, `SwipeSettingTests.swift`, `ClickBlockingTests.swift`, the remainder of `ScrollSuppressionTests.swift`, or `LC/ClickFilter.swift` / `LC/DockSwipeFilter.swift` in full; other explorers cover blocking and the model.
- Whether macOS's own scroll recognition starts before 3 mm on a vertical pair (so a late window swipe would be "stilled" mid-scroll, as `T/ScrollSuppressionTests.swift:46-61` shows for a late sideways swipe) is a platform behaviour I could not observe here.
