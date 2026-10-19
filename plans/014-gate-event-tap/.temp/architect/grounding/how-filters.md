# Grounding: the three filters (ClickFilter, ScrollFilter, DockSwipeFilter)

Angle: the filters' interfaces, in-flight state, decision points, idle conditions, rewrites, how the blocking flags reach them, and what each does with an event whose start it never saw. All paths are relative to `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/014-gate-event-tap/`.

## Components Found

| Name | File:line | What it is |
|---|---|---|
| `PressID` | `LauncherKit/Sources/LauncherCore/ClickFilter.swift:4-13` | One press: `button: Int` (0 left, 1 right, 2+ other) and `number: Int64` (the `kCGMouseEventNumber` the down and its up share). |
| `PointerEvent` | `ClickFilter.swift:16-23` | `.press(PressID)`, `.release(PressID)`, `.drag(button: Int)`, `.pressure`. "Everything the click tap is ever told about, parsed." |
| `PointerVerdict` | `ClickFilter.swift:25-30` | `.pass`, `.drop`, `.passAsMove`. |
| `ClickFilter` | `ClickFilter.swift:35-82` | Pure press-blocking state machine; one per tap; no clock, no device. |
| `ClickFilter.Holding` | `ClickFilter.swift:37` | `.nothing`, `.withheld`, `.passed`: the summary the frame thread reads. |
| `ClickFilter.Held` (private) | `ClickFilter.swift:76-79` | `.withheld(PressID)` / `.passed(PressID)`. |
| `ScrollEvent` | `LauncherKit/Sources/LauncherCore/ScrollFilter.swift:4-16` | `.wheel`, `.fingers(Phase)`, `.momentum(Momentum)`, `.unphased`; `Phase` = mayBegin/began/changed/ended/cancelled; `Momentum` = began/changed/ended. |
| `ScrollVerdict` | `ScrollFilter.swift:18-23` | `.pass`, `.drop`, `.passStill` (every delta zeroed). |
| `ScrollFilter` | `ScrollFilter.swift:27-82` | Pure per-scroll-gesture suppression state machine. |
| `ScrollFilter.Treatment` / `Stage` (private) | `ScrollFilter.swift:67-79` | `Treatment` = passed/dropped/stilled (maps to pass/drop/passStill); `Stage` = `.touching(Treatment)` / `.coasting(Treatment)`; the state is `stage: Stage?`. |
| `DockSwipePhase` | `LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift:5` | mayBegin/began/changed/ended/cancelled. |
| `DockSwipeVerdict` | `DockSwipeFilter.swift:7` | `.pass`, `.drop` (no rewrite case). |
| `DockSwipeFilter` | `DockSwipeFilter.swift:13-34` | Pure Dock swipe blocking: judged once on the opening event, kept whole. State `current: DockSwipeVerdict?`. |
| `TouchFrame.Press` / `init?(holding:buttonDown:)` | `LauncherKit/Sources/LauncherCore/Touch.swift:61-83` | How the click filter's `holding` turns into what a frame says about a press. |
| `Recognition.blocksClicks` / `.blocksDockSwipes` | `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift:18,23`, computed `182-200` | The recognizer's per-trackpad halves of the two flags. |
| `ClickTap` | `LauncherKit/Sources/LauncherPlatform/ClickTap.swift:12-89` | Owns the three filters behind `Mutex`es, parses events, applies verdicts. |
| `TapEvent` and the parse extensions | `ClickTap.swift:103-211` | The one parse from `CGEvent` to the domain types above. |
| `PointerVerdict.apply`, `DockSwipeVerdict.apply`, `ScrollVerdict.apply` | `ClickTap.swift:213-251` | Turn verdicts into return values / in-place rewrites. |
| `DeviceSession.blocking`, `.blockingDockSwipes`, `.holding` | `LauncherKit/Sources/LauncherPlatform/FrameStream.swift:20-22,58-59,72-78` | Per-device `Mutex<Bool>` flags (frame thread writes, tap thread reads). |
| `anyTrackpadBlocksClicks()` / `anyTrackpadBlocksDockSwipes()` | `FrameStream.swift:100-108` | Merged OR across all sessions, read by the tap per event. |
| `InMemoryTrackpads` (fake tap) | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:5-127` | Test fake: real `ClickFilter` + `ScrollFilter`, no `DockSwipeFilter`. |

## Exact interfaces

### ClickFilter (`ClickFilter.swift`)
- `public init()` (line 39)
- `public mutating func decide(_ event: PointerEvent, trackpadBlocking: Bool) -> PointerVerdict` (line 41)
- `public var holding: Holding { get }` (line 62)
- `public mutating func forgetHeldPresses()` (line 74): `held = [:]`
- private state: `held: [Int: Held]` (line 81), keyed by button number.

`decide` per case (lines 42-57):
- `.press(p)`: `held[p.button] = trackpadBlocking ? .withheld(p) : .passed(p)`; returns `.drop` if blocking else `.pass`. A new press of a button overwrites any stale entry for that button. **The only case that reads the flag.**
- `.release(p)`: returns `.drop` iff `held[p.button] == .withheld(p)` (same button AND same number); in all cases clears `held[p.button]` (`defer`). Flag ignored. A release whose number differs from the held press passes and still clears the button.
- `.drag(button)`: `.passAsMove` iff `held[button]` is `.withheld(_)` (any number), else `.pass`. Flag ignored. Does not mutate state.
- `.pressure`: `.drop` iff `holding == .withheld` (any button withheld), else `.pass`. Flag ignored. Does not mutate state. Not tied to a button.

`holding` (lines 62-71): `.withheld` if any entry is withheld (wins), else `.passed` if any entry exists, else `.nothing`.

### ScrollFilter (`ScrollFilter.swift`)
- `public init()` (line 28)
- `public mutating func decide(_ event: ScrollEvent, trackpadBlocking: Bool) -> ScrollVerdict` (line 30)
- `public mutating func forgetGesture()` (line 65): `stage = nil`
- private state: `stage: Stage?` (line 81). No public accessor.

`decide` per case (lines 31-61):
- `.wheel`: always `.pass`, no state touched.
- `.unphased`: `trackpadBlocking ? .drop : .pass`, stateless.
- `.fingers(phase)`:
  - if `stage == .touching(current)`: treatment = `current == .passed && trackpadBlocking ? .stilled : current` (the "never relaxes" rule: passed can escalate to stilled; dropped and stilled never change; nothing ever goes back to passed inside a gesture).
  - if `stage` is `.coasting(_)` or `nil` (a new gesture, or one first seen mid-way): flag false → `.passed`; flag true → `.dropped` if phase is `mayBegin` or `began`, else `.stilled` ("A gesture first seen mid-way was already seen by apps: only stilling keeps it whole", line 43).
  - new stage: `ended`/`cancelled` → `.coasting(treatment)`, else `.touching(treatment)` (line 50).
- `.momentum(m)`: inherits the treatment of `.coasting(t)` or `.touching(t)`; with `stage == nil` returns `.pass` and leaves `stage` nil ("unknown coasting is never interrupted"). Never reads the flag ("never escalates"). `momentum == .ended` sets `stage = nil` (line 59).

### DockSwipeFilter (`DockSwipeFilter.swift`)
- `public init()` (line 14)
- `public mutating func decide(_ phase: DockSwipePhase, trackpadBlocking: Bool) -> DockSwipeVerdict` (line 16)
- `public mutating func forgetSwipe()` (line 30): `current = nil`
- private state: `current: DockSwipeVerdict?` (line 33). No public accessor.

`decide` (lines 17-26): if `current != nil` → keep `current`; else if phase is `mayBegin`/`began` → `trackpadBlocking ? .drop : .pass`; else (`changed`/`ended`/`cancelled` first seen) → `.pass`. Then `current = (phase == ended || cancelled) ? nil : verdict`. So a mid-way first sight records `current = .pass` for the rest of that swipe.

`forgetSwipe()` is unused by `ClickTap`: on tap-disabled it replaces the whole dictionary (`dockSwipeFilters.withLock { $0 = [:] }`, ClickTap.swift:69). `forgetSwipe` is exercised only by `DockSwipeFilterTests`.

## What crosses from the platform event into each filter

All parsing is in `ClickTap.swift`; no `CGEvent` type crosses into LauncherCore.

- `TapEvent.init?(_ type:, _ event:)` (ClickTap.swift:122-133): `.scrollWheel` → `.scroll(ScrollEvent(event))` (never nil); types 29/30 → `.dockSwipe(phase)` only if `DockSwipePhase(event)` is non-nil, else nil (passes untouched); otherwise `PointerEvent(type, event)`, else nil.
- `PointerEvent.init?` (165-185): reads `.mouseEventNumber` and `.mouseEventButtonNumber`. Button = 0 for left types, 1 for right types, `mouseEventButtonNumber` for other types. Down types → `.press(PressID)`, up types → `.release(PressID)`, dragged types → `.drag(button:)` (number not used), raw type 34 → `.pressure`. Nothing about the device (trackpad vs mouse) is read.
- `ScrollEvent.init` (192-210): `scrollWheelEventIsContinuous == 0` → `.wheel` regardless of phases. Else reads `scrollWheelEventScrollPhase` and `scrollWheelEventMomentumPhase`: scroll phase 128/1/2/4/8 → `.fingers(mayBegin/began/changed/ended/cancelled)` (scroll phase wins over momentum); (0,1)/(0,2)/(0,3) → `.momentum(began/changed/ended)`; anything else → `.unphased`. Deltas are not read.
- `DockSwipePhase.init?` (153-162): nil unless field 110 (`DockSwipeFields.hidType`) == 23 (`kIOHIDEventTypeDockSwipe`); phase field 132: 128 mayBegin, 1 began, 4 ended, 8 cancelled, **anything else (including 2 and 0) → `.changed`**, which never starts a drop.
- The event *type* (29 or 30) also crosses, but only as the dictionary key for which `DockSwipeFilter` instance decides (ClickTap.swift:85), never into the filter.

## How the blocking flags reach the filters

A plain `Bool` argument, `trackpadBlocking:`, passed per event; no callback, no shared state inside LauncherCore.

1. Frame thread: `contactFrameCallback` (FrameStream.swift:86-91) → `DeviceSession.receive(_:)` (46-69) → `GestureRecognizer.step(frame)` → `blocking.withLock { $0 = recognition.blocksClicks }` and `blockingDockSwipes.withLock { $0 = recognition.blocksDockSwipes }` (58-59). Each is a `Mutex<Bool>` per `DeviceSession` (20, 22), one writer (that device's frame callback).
2. Tap thread: `ClickTap.handle(_:_:)` (ClickTap.swift:64-88) calls `anyTrackpadBlocksClicks()` once per parsed event, before any filter lock (line 75: "Read once, before either filter lock, so no two locks are held at once"). That function (FrameStream.swift:100-102) copies the session values out of the global `sessions: Mutex<[UInt: DeviceSession]>` (line 84) and ORs each session's `blocksClicks` (each a further `Mutex` read).
3. Pointer and scroll events: `filter.withLock { $0.decide(pointer, trackpadBlocking: blocking) }` (78) and `scrollFilter.withLock { $0.decide(scroll, trackpadBlocking: blocking) }` (80). Both use the same merged `blocksClicks` flag.
4. Dock swipes: a second read, `anyTrackpadBlocksDockSwipes()` (line 83; FrameStream.swift:106-108), merged the same way from `blockingDockSwipes`. The `blocksClicks` read at line 75 is also done for Dock swipe events and is unused for them.
5. Reverse direction (filter → frame thread): `ClickTap.holding` (ClickTap.swift:49) locks `filter` and returns `ClickFilter.holding`; `DeviceSession.holding` (FrameStream.swift:72) returns `clickTap?.holding` (nil without a tap); `contactFrameCallback` builds `TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())` (88) for every frame *before* stepping. So the frame thread takes the ClickFilter's lock every frame. Scroll and Dock swipe filter state is never read off the tap thread.

What produces the flags (GestureRecognizer.swift:182-199), for reference: confirmed swiping or a swap series → both true; otherwise with an anchored thumb (`state.thumb`), `blocksDockSwipes` = any other contact down (no time limit), `blocksClicks` = thumb's real landing time known and < 3 s ago (`GestureRules.clickBlockingWindow`, GestureRules.swift:23) and another contact down. So `blocksDockSwipes` is a superset of `blocksClicks` in the thumb branch, and stays true indefinitely while thumb + another contact rest.

## In-flight state and when each filter is "idle"

### ClickFilter
- In flight: `held[button]` for each button pressed and not yet released. A withheld press "owns": its release (same button and number → dropped), drags of the same button (→ `.passAsMove`), and every pressure event while any press is withheld (→ dropped, regardless of which button). A passed press's drags/pressure/release all pass; its entry matters only for `holding == .passed` (frame sampling, see below).
- Decides: once, on `.press`, from the flag at that instant. Everything after follows the stored entry, ignoring the flag ("blocked or passed whole", line 48).
- Ends: on any release of that button (even a mismatched number), a new press of the same button (overwrite), or `forgetHeldPresses()`.
- Idle query exists: `holding`. For blocking purposes "nothing will be altered" is `holding != .withheld`; "nothing in flight at all" is `holding == .nothing`.
- Mouse click vs trackpad press: the filter makes **no device distinction**. A mouse click arriving while any trackpad's `blocksClicks` is true is withheld exactly like a trackpad press. The only distinction in the code is `TouchFrame.Press.click` ("macOS delivered this press to apps as a click (any pointing device)") vs `.blocked` ("the click filter is withholding this press"), Touch.swift:62-65.

### ScrollFilter
- In flight: `stage`. `.touching(t)` = a fingers gesture in progress with treatment t; `.coasting(t)` = its fingers ended/cancelled, momentum may follow and inherits t; `nil` = nothing known.
- Decides: on the first fingers event of a gesture (stage nil or coasting), from the flag and whether the phase opens. While touching, each fingers event can escalate `.passed` → `.stilled` if the flag is up; never the other way. Momentum never reads the flag.
- Ends: `momentum(.ended)` → nil. `fingers(.ended/.cancelled)` only moves to coasting. The next fingers event of a later gesture ignores the coasting treatment and decides afresh. `forgetGesture()` → nil.
- Idle query: **none** (`stage` is private, no accessor).
- State that would answer it, by behavioural equivalence to `nil` (worked out from `decide`):
  - `nil` and `.coasting(.passed)` are behaviourally identical for every future event (fingers: same branch; momentum: both `.pass`; momentum ended: both end at nil).
  - `.touching(.passed)` differs from `nil` in exactly one case: an opening phase (`mayBegin`/`began`) arriving with the flag up gives `.stilled` from `.touching(.passed)` but `.dropped` from `nil`. All other events give the same verdict.
  - `.touching(.dropped|.stilled)` and `.coasting(.dropped|.stilled)` are pending alterations: further fingers or momentum events of the gesture are dropped or stilled.
  - So "nothing withheld or altered in flight" = `stage ∈ {nil, .coasting(.passed), .touching(.passed)}`, but `.touching(.passed)` also carries memory that matters if an opening phase arrives under the flag.
- Surprise: `.coasting(.dropped|.stilled)` has no end unless momentum arrives and ends, or the next fingers event arrives. A slow lift with no momentum leaves the filter in `.coasting(.dropped)` indefinitely (harmless today, but an "is idle" predicate built on it would stay false until the next scroll gesture).

### DockSwipeFilter (one per event type, 29 and 30)
- In flight: `current`. `.drop` = a swipe whose opening event was dropped; `.pass` = a swipe passing (judged open with the flag down, or first seen mid-way); nil = between swipes.
- Decides: only when `current == nil` and the phase is `mayBegin` or `began`, from `blocksDockSwipes` at that instant. Otherwise the verdict is `current` (or `.pass` if first seen mid-way).
- Ends: `ended`/`cancelled` → nil; `forgetSwipe()` or replacing the dictionary.
- Idle query: **none** (`current` private). Pending alteration iff `current == .drop`. `current == .pass` differs from nil in one case: an opening phase under the flag (nil → `.drop`, `.pass` → `.pass`).
- Two independent filters: `dockSwipeFilters: Mutex<[UInt32: DockSwipeFilter]>` keyed by `type.rawValue` (ClickTap.swift:18, 85) "since a Dock swipe may arrive as both". Each reads the flag at its own event, so if the flag flips between a swipe's type-29 opening and its type-30 opening, the two copies can get different verdicts. That is today's behaviour, not a gating artefact.

## What "rewritten" means

- `PointerVerdict.passAsMove` (ClickTap.swift:219-221): `event.type = .mouseMoved`, the same event passed on. Why: "the pointer keeps moving, and no app sees a drag whose press it never got" (ClickFilter.swift:28). Dropping would freeze the cursor during a withheld press.
- `ScrollVerdict.passStill` (ClickTap.swift:237-248): zeroes in place `scrollWheelEventDeltaAxis1-3` (integer) and `FixedPtDeltaAxis1-3`, `PointDeltaAxis1-3` (double), keeps type, phases and `isContinuous`, passes the same event. Nothing is posted. Why: a gesture apps already saw the start of (passed, then blocking arrived; or first seen mid-way) must still get its whole began…ended bracket and momentum, but nothing moves or coasts. Plan 006 rejected dropping these because "a gesture stilled after its `began` passed ... would leave the app without an `ended`" (plans/006-five-finger-tap-and-corner-swipe/.temp/architect/candidate-2.md:848). Its accepted risk: an app reading scroll data outside the nine delta fields would still move (plan 006 design.md:887).
- `DockSwipeVerdict` has no rewrite: drop or pass. A Dock swipe already under way is never dropped, because that "could leave the Dock stranded between two desktops" (DockSwipeFilter.swift:11-12).
- `ClickFilter` drops press, release and pressure; only drags are rewritten.

## Flow (per event on the tap thread)

1. `clickTapCallback` (ClickTap.swift:97-100) → `ClickTap.handle(type, event)` (64).
2. If `type` is `.tapDisabledByTimeout` / `.tapDisabledByUserInput` (65-72): `forgetHeldPresses()`, `forgetGesture()`, `dockSwipeFilters = [:]`, then `CGEvent.tapEnable(…, true)` unconditionally, pass the event.
3. `TapEvent(type, event)`; nil → pass untouched (73). This covers non-Dock-swipe gesture events (pinch, rotate, app swipes) and unknown types.
4. `blocking = anyTrackpadBlocksClicks()` (75).
5. Dispatch to one filter under its own `Mutex` (77-87); Dock swipes read `anyTrackpadBlocksDockSwipes()` first.
6. `verdict.apply(to: event)` → `nil` (drop), the same event, or the event rewritten in place.

Lifecycle of filter state: the filters are stored properties of a `ClickTap` (14-18), created fresh by `ClickTap.install()` (25-46), which `MultitouchTrackpads.run` calls on every run iff `blockClicks && !devices.isEmpty` (MultitouchTrackpads.swift:87), after `sessions = [:]` and `clickTap?.remove()` (69-73). So every `run` (launch, hot-plug, wake, hand mode, settings, Accessibility change, via `Launcher.reconcile`, Launcher.swift:210-231) discards every in-flight press, scroll and Dock swipe. The run comment accepts "A withheld press's release may now reach apps: a harmless stray mouse-up" (MultitouchTrackpads.swift:71). Plan 006 likewise accepted a scroll resuming "headless" after a run (plans/006-…/plan.md:641).

## Behaviour that depends on having seen the start

The question for gating: if the filter never saw some events (because the tap was not sent them), what happens? An unseen event reaches apps untouched, and the filter's state is whatever it was before. Two things must hold for "identical to today": (a) today's filter would have passed every unseen event unaltered, and (b) the filter's state after missing them gives the same verdicts on later events as today's state would.

### ClickFilter
- Release, drag and pressure never mutate state and never read the flag (except that press and release update/clear `held`). With no entry for the button, release → pass, drag → pass, pressure → pass (unless another button is withheld). So a press first seen mid-way (down unseen) passes whole, identical to today's *passed* press.
- Drags and pressure don't mutate state, so missing them leaves (b) intact. For (a): a missed drag differs from today only when `held[button]` is withheld (today `.passAsMove`, unseen: a raw drag reaches apps for a press they never got); a missed pressure event differs only while `holding == .withheld` (today dropped). So drags (6, 7, 27) and pressure (34) may go unseen exactly when `holding != .withheld`.
- Presses and releases cannot simply go unseen while a tap exists, for a reason outside the filter: `TouchFrame.Press.init?(holding:buttonDown:)` (Touch.swift:72-82) returns **nil for `.nothing` even if the button is down** ("a press the filter has not seen yet is nothing"); only `holding == nil` (no tap) falls back to the button state. If a live `ClickTap` missed a real click, the frame would read no press, and the recognizer's `frame.press == .click` spoil checks (GestureRecognizer.swift:101, 107, 123, 151) would not fire. Also a missed press under the flag would deliver a press today's build withholds. The plan's R1 list (6, 7, 27, 34, 22, 29, 30) leaves the press/release types (1, 2, 3, 4, 25, 26) out, consistent with this.
- A withheld press is decided on the tap thread. If drags/pressure were gated by something the frame thread computes from recognizer state, the 3 s window can end mid-press (`blocksClicks` goes false while the press is still held, by design: the press stays withheld until its release). The gate must therefore also stay open while `holding == .withheld`, which is the tap thread's own knowledge.

### ScrollFilter
Compare "filter saw the gesture from its start" (today) with "filter's stage was nil when the event arrived" (start unseen, or reset):
- Gesture still under way, flag up when first seen: `changed`/`ended`/`cancelled` → `.stilled` (stage nil branch). Today, a gesture that began with the flag down is `.touching(.passed)` and escalates to `.stilled` on the same event. **Same.**
- Same, flag down: `.passed` in both. **Same.**
- Momentum first seen (stage nil): `.pass`, whatever the flag. Today a passed gesture's momentum is `.pass` too. **Same.** (Pinned by `ScrollSuppressionTests.coastingFromBeforeIsNotInterruptedWhenTheThumbLands`, ScrollSuppressionTests.swift:98-108.)
- **Divergence: an opening phase whose predecessor was missed.** If `mayBegin` passed unseen and `began` arrives with the flag up: today `.touching(.passed)` + flag → `.stilled` (apps get mayBegin, then a zeroed bracket); unseen-start → `.dropped` (apps got `mayBegin` and then nothing). That is a half-blocked gesture (start delivered, rest withheld). Plan 006 already names the underlying race: "If the system's scroll recognizer emits `mayBegin` before our frame sets the flag, a gesture we would have dropped is stilled instead" (plans/006-…/.temp/architect/design.md:888). Today that race ends in stilling because the filter saw the `mayBegin`; a gated tap that was not yet receiving 22 would turn it into a drop after a delivered `mayBegin`.
- **Divergence: stale state from missed ends.** If the filter saw part of a passed gesture but missed its `ended`, stage stays `.touching(.passed)`. A later gesture's `mayBegin`/`began` under the flag would then be stilled instead of dropped (today it would have seen `ended` → `.coasting(.passed)` ≡ nil → dropped). So missing events while stage is non-nil needs a `forgetGesture()` (or equivalent) before trusting the stage again, and that reset brings back the mayBegin/began divergence above.
- Missed events while stage is `.touching/.coasting(.dropped|.stilled)` are what R3 forbids: today they would be dropped or stilled. The never-relax rule depends on the filter seeing every fingers and momentum event until the gesture ends (`momentum(.ended)`, or the next gesture's first fingers event), even after the flag has gone down: the lift frame clears the flag before the last `changed`/`ended` arrive (plans/006-…/plan.md:649).
- `.unphased` is stateless and `.pass` with the flag down; `.wheel` always passes. Neither needs the tap when nothing is blocking. Note that type 22 also carries mouse wheels and Magic Mouse scrolling (`.fingers`, "a trackpad or a Magic Mouse, which the system reports alike", ScrollFilter.swift:7), so Magic Mouse scrolling is suppressed while a trackpad blocks.

### DockSwipeFilter
- First seen mid-way (`changed`/`ended`/`cancelled`, or unknown phase) → `.pass`, `current = .pass` for the rest. Today, a swipe that opened with the flag down passes whole. **Same.** A swipe that opened with the flag up (today dropped whole) can only be missed at its start if the tap was not receiving 29/30 while `blocksDockSwipes` was true.
- **Divergence: missed `mayBegin`, seen `began`.** Today: `mayBegin` with the flag down → `current = .pass` → `began` with the flag up still passes. Unseen `mayBegin`: `current == nil` → `began` with the flag up → `.drop`, and the rest dropped. The Dock got `mayBegin` and nothing else: half-blocked. I could not determine whether real Dock swipes always send a separate `mayBegin` (128) event before `began`.
- **Divergence: stale `.pass`** (missed `ended`): a later swipe's opening under the flag would pass instead of drop. Needs a reset, as for scrolls.
- Gate must stay open on types 29 and 30 while either per-type filter has `current == .drop`.

## Boundaries

- Inputs: parsed `PointerEvent` / `ScrollEvent` / `DockSwipePhase` plus a `Bool` flag per event; the event type 29/30 only as a dictionary key.
- Outputs: a verdict per event; `ClickFilter.holding` to the frame thread (via `ClickTap.holding` → `DeviceSession.holding` → `TouchFrame.Press`).
- Reset hooks: `forgetHeldPresses()`, `forgetGesture()`, `forgetSwipe()` (the last unused in production). Called only on `tapDisabledByTimeout/ByUserInput` (ClickTap.swift:65-71). Whole-tap replacement on every `run`.
- Policy constraints near the boundary: `SourcePolicyTests` confines `tapCreate`/`CGEventTapCreate` and `scrollWheel` to `ClickTap.swift` under rule "R9 the one event tap" (SourcePolicyTests.swift:79-81). `TapEventTests.maskCoversPressesTheirReleasesDragsPressureScrollAndGesturesOnly` pins the mask to bits `[1,2,3,4,6,7,22,25,26,27,29,30,34]` (TapEventTests.swift:8-11), and `everyMaskedTypeParses` checks every `tapTypes` entry parses (13-17). A tap's mask is fixed when it is created (`CGEvent.tapCreate(... eventsOfInterest: TapEvent.tapMask ...)`, ClickTap.swift:28-31), so the filters cannot learn about gating from the mask itself.

## How the tests model the filters and the tap

- Unit suites over the pure filters, feeding `(event, flag)` sequences:
  - `ClickFilterTests` in `LauncherKit/Tests/LauncherCoreTests/ClickBlockingRecognizerTests.swift:117-206`: whole press per flag at press time, all buttons; new press ends a stale one; mismatched release passes and clears; drags `.passAsMove` only for the withheld button; pressure dropped only while something is withheld; forget lets a lost release pass; withheld wins over passed in `holding`.
  - `PressSamplingTests` (same file, 208-226): the `TouchFrame.Press(holding:buttonDown:)` table, including `(.nothing, true) → nil`.
  - `ScrollFilterTests` (`ScrollFilterTests.swift`): wheel/unphased; judged on the opening event and kept whole; passed→stilled through momentum's end; first seen mid-way under the flag → `.passStill` (line 34); momentum follows its gesture, unknown momentum passes; forget treats the rest as first seen mid-way.
  - `DockSwipeFilterTests` (`DockSwipeFilterTests.swift`): dropped whole, passed whole, judged afresh after an end, first-seen-mid-way passes, forget.
  - `TapEventTests` (`LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift`): parse tables for every type and phase value, mask bits, and the `apply(to:)` rewrites (passStill zeroes nine delta fields in place and keeps type and phase; passAsMove sets `.mouseMoved`).
- Behavioural fake, `InMemoryTrackpads` (InMemoryAdapters.swift):
  - `run` (47-59) arms a fresh `ClickFilter` iff `blockClicks && !trackpads.isEmpty`, and a fresh `ScrollFilter` iff a click filter exists ("one tap decides both"); resets `blocking`, `buttonWasDown`, `pressInProgress`.
  - `touch(_:on:)` (84-101): per frame, `deliverPressEdge` first (a press edge "reaches the tap between frames, so it is decided on the flags the previous frame left, merged across trackpads", line 81), then re-samples the frame's press through `TouchFrame.Press(holding: clickFilter?.holding, buttonDown:)`, steps the real recognizer and stores `blocking[id] = recognition.blocksClicks` (93).
  - `deliverPressEdge` (103-117): only button 0, numbers counting up, a press on a down edge and the release on the up edge; verdicts appended to `pressVerdicts`.
  - `scroll(_:)` (121-123): `scrollFilter?.decide(event, trackpadBlocking: blocking.values.contains(true))`; nil when no tap is armed.
  - Not modelled: drags, pressure, `blocksDockSwipes`, `DockSwipeFilter`, tap-disabled events, multiple buttons, and any notion of the tap being sent some types and not others. `sleep()` makes frames be dropped but leaves `blocking` at its last value (as on hardware, where `DeviceSession.blocking` keeps its last write until the next `run`).
  - Scroll events in behavioural tests are injected between `world.play(...)` calls (`World.play` delivers only frames newer than the last delivered, World.swift:173-178), so each reads the flags of the last frame played. Examples: `ScrollSuppressionTests.swift`, `WindowSwipeBlockingTests.swift:7-36`, `SwapTests.swift:319-324`, probes in `WindowSwipeNeedsTwoWindowsTests.swift:112` and `WindowSwitcherOnScreenTests.swift:289-295`.

## Non-Obvious Things

1. Only the opening event reads the flag for presses and Dock swipes; for scrolls, every fingers event reads it (to escalate passed→stilled), momentum never does. Drags, pressure and releases never read it.
2. Pressure is not per button: one withheld press of any button drops every pressure event.
3. A release with a different `number` than the held press passes but still clears that button's entry.
4. With a tap live, a press the filter has not seen reads as *no press* on frames (`.nothing` → nil), not as a click. Gating presses would change recognition (taps would not spoil under real clicks), not just blocking.
5. `nil` and `.coasting(.passed)` are equivalent ScrollFilter states; `.touching(.passed)` is not equivalent to nil (opening phase under the flag: stilled vs dropped). Likewise DockSwipe `.pass` vs nil (opening under the flag: pass vs drop). This is the crux for a gate that turns on part-way: the only divergences from "saw it from the start" are an opening phase (`began`) whose own `mayBegin` went unseen, and stale state from missed ends.
6. The mid-way rules were written for the tap-disabled recovery (`forgetGesture`, `forgetSwipe`, "under-blocking") and for the `mayBegin` race, and they happen to make a mid-way start behave like a gesture that began unblocked. They do not make a missed `mayBegin` harmless.
7. `.coasting(.dropped|.stilled)` can persist with no momentum ever arriving; it ends only at `momentum(.ended)`, the next fingers event, a forget, or a `run`.
8. A scroll gesture's momentum stage can be overwritten by the next gesture's first fingers event; if the old gesture's `momentum(.ended)` then arrives, it ends the *new* gesture's stage (sets it to nil). I could not determine whether macOS ever orders events that way.
9. Per-type Dock swipe filters can disagree for one physical swipe if the flag flips between the type-29 and type-30 copies of its opening.
10. `ClickTap.handle` reads `anyTrackpadBlocksClicks()` for Dock swipe events too and doesn't use the result (ClickTap.swift:75 vs 83).
11. The tap-disabled handler re-enables the tap unconditionally (ClickTap.swift:70). That matters for the plan's R4 ("without turning on a tap the gating wants off").
12. `docs/architecture.md:20` says the tap thread "sleeps until an event arrives (a press, its drags and pressure, a scroll event, or a system gesture event)": that is the claim R5 replaces.
13. The question's framing groups "the start of a press" with scrolls and Dock swipes. In the code a press's start (the mouse-down) is not among the plan's high-volume types and is always seen, so for clicks the only gating risk is drags/pressure during a withheld press. For scrolls and Dock swipes the start itself is in the gated set, which is where the `mayBegin` divergence lives.

## Files Read

- `LauncherKit/Sources/LauncherCore/ClickFilter.swift`
- `LauncherKit/Sources/LauncherCore/ScrollFilter.swift`
- `LauncherKit/Sources/LauncherCore/DockSwipeFilter.swift`
- `LauncherKit/Sources/LauncherCore/Touch.swift`
- `LauncherKit/Sources/LauncherCore/Trackpad.swift`
- `LauncherKit/Sources/LauncherCore/GestureRules.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (lines 1-260)
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (lines 190-235)
- `LauncherKit/Sources/LauncherPlatform/ClickTap.swift`
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (lines 1-140)
- `LauncherKit/Tests/LauncherCoreTests/ScrollFilterTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/DockSwipeFilterTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/ClickBlockingRecognizerTests.swift` (lines 110-226)
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 1-140)
- `LauncherKit/Tests/LauncherCoreTests/ScrollSuppressionTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/WindowSwipeBlockingTests.swift` (lines 1-60)
- `LauncherKit/Tests/LauncherCoreTests/World.swift` (play / playFrameByFrame, lines 170-290)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (lines 60-100)
- `LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift`
- `plans/014-gate-event-tap/plan.md`
- grep hits in `plans/006-five-finger-tap-and-corner-swipe/plan.md`, `.temp/architect/design.md`, `.temp/architect/candidate-2.md`, `development-logs.md`
- grep hits in `docs/architecture.md`

## Open Questions

- Whether macOS always sends a scroll `mayBegin` (128) before `began`, and whether Dock swipes (field 132) always send `mayBegin` before `began`. That decides how often the missed-`mayBegin` divergence would happen under a gate.
- Whether macOS sends `momentum(.ended)` for a coasting gesture interrupted by a new touch before or after the new gesture's `mayBegin` (Non-Obvious 8).
- Whether a tap disabled by our own `CGEvent.tapEnable(false)` ever delivers a `tapDisabledByUserInput` callback; if it did, the handler would forget all filters and re-enable (ClickTap.swift:65-71). Not traceable from this code.
- How the type-29 and type-30 copies of one Dock swipe are ordered relative to each other: not determinable from the code.
