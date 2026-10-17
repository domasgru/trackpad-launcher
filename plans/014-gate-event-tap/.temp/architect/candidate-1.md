# Candidate 1: two taps, one owner, a need per trackpad

## Design

### Problem

Every scroll, drag, pressure and system gesture event in the session makes a synchronous round trip through the app, because the one active tap is enabled for the whole armed run. That round trip is 84% of the app's CPU while fingers touch (P9). `tapEnable` is the cure. A disabled tap costs what no tap costs, the window server applies the mask on its side, and the call takes about 0.1 ms from any thread with its effect in place on return (P1-P3). What makes the shape hard is everything that must stay the same:

- **The press rule.** With a live filter, a press the filter never saw reads as no press and cannot cancel a tap gesture (C7).
- **No warning before blocking.** A blocking verdict can appear on a frame with nothing before it: thumb and finger on one frame, or a thumb under resting fingers (C5).
- **Filter memory outlives the flag.** It has to stay in force after the flag drops: a withheld press until its release, a dropped scroll through its momentum, a dropped Dock swipe until it ends (C6-C9, R3).
- **A reopened gate has missed events.** The resting-fingers scroll must still be stilled, and a later `mayBegin` must still count as a fresh start (C10-C11).
- **Our own disable echoes back.** Every `tapEnable(false)` comes back as a `tapDisabledByUserInput`, and today's handler re-enables on it (P6).
- **Two kinds of thread change the inputs.** The frame threads change what blocks, and the tap thread changes the filters' memory (Q-D).

Constraints to honour:

- `TrackpadHardware.run` and the model stay as they are.
- One writer per shared field (`docs/architecture.md:18`).
- Nothing on the frame thread enables or disables a tap (plan 002:437).
- No timers.
- `tapCreate` stays inside the click tap's file.
- Every existing behavioural test must pass unchanged (R2). Note that `SwapTests:324` asserts `.drop` for a bare `began` after a thumb lands under resting fingers.

### Usage (caller's view)

The model, `TrackpadHardware` and `MultitouchTrackpads.run` do not change. The new surface is a pure value in `LauncherCore`, `TapFilters`: the click, scroll and Dock swipe filters plus the gate that decides whether the *gated tap* receives events. Each recognizer frame also reports a `TapNeed`. Three kinds of caller use them.

```swift
// README: the click tap's mind, one per installed tap, mutated only on the tap's thread.
var filters = TapFilters()                                  // the gated tap starts on, as tapCreate leaves it
filters.follow(TapContext(need: .none))                     // == .close: nobody needs it
filters.follow(TapContext(need: .watch))                    // == .open: a thumb landed alone in the corner
filters.decide(.scroll(.fingers(.mayBegin)), in: TapContext(need: .clicks))
                                                            // == TapDecision(verdict: .scroll(.drop), gate: nil)
filters.follow(TapContext(need: .none))                     // == nil: the dropped scroll still holds the gate open
filters.decide(.scroll(.momentum(.ended)), in: TapContext(need: .none)).gate   // == .close: nothing left in flight
```

Call site 1 is the frame thread, in `DeviceSession.receive`. Per frame it does one lock and one compare, and on a change it wakes the tap's thread. It never calls `tapEnable`:

```swift
let recognition = recognizer.withLock { /* answer, step, travel: as today */ }
let was = need.withLock { stored in defer { stored = recognition.tapNeed }; return stored }
if was != recognition.tapNeed { clickTap?.needChanged() }
```

Call site 2 is the tap thread, in `ClickTap`. It is the only code that switches the gated tap on and off:

```swift
fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { recover(); return .passUnretained(event) }
    guard let parsed = TapEvent(type, event) else { return .passUnretained(event) }
    let context = TapContext(need: anyTrackpadNeed())          // read before the filters' lock
    let decision = filters.withLock { $0.decide(parsed, in: context) }
    switchGatedTap(decision.gate)                              // before the verdict returns to the window server
    return decision.verdict.apply(to: event)
}
/// Run on the tap's run loop by `needChanged()`.
private func follow() { switchGatedTap(filters.withLock { $0.follow(TapContext(need: anyTrackpadNeed())) }) }
```

Call site 3 is the behavioural fake (`InMemoryTrackpads`) and a World test:

```swift
// Fingers scroll a page for 40 s, away from the corner: the window server never sends the gated types.
let seen = world.playFrameByFrame(scrolling) { world.hardware.isGatedTapOn }
#expect(seen.allSatisfy { !$0 })
#expect(world.hardware.offer(.scroll(.fingers(.changed))) == .notSent)
// A flick dropped under the thumb keeps reaching the tap after the thumb lifts, until its momentum ends.
#expect(world.hardware.offer(.scroll(.momentum(.changed))) == .decided(.scroll(.drop)))
#expect(world.hardware.scroll(.fingers(.began)) == .pass)        // the existing apps'-view API, unchanged
```

### Shape

**Data first.** There are three pieces of state, each with one writer, and they are merged where they are read (per separate-before-serializing-shared-state).

1. **`TapNeed`, one per trackpad.** An ordered enum, `none < watch < dockSwipes < clicks`, which replaces `Recognition`'s two Bools. `blocksClicks` is `== .clicks`, `blocksDockSwipes` is `>= .dockSwipes`, and `needsTap` is `>= .watch`. The ordering makes `blocksClicks ⇒ blocksDockSwipes ⇒ needsTap` a fact of construction rather than a comment (per type-system-discipline). `.watch` is the new information, R1's "a thumb anchored, a swipe or window swipe in progress". It is true for a thumb alone in `.armed` or `.spoiled`, and for any slide not yet confirmed. In every thumb-first flow it is up at least one frame before any blocking verdict can appear. It is written by that device's frame thread, in its session's `Mutex<TapNeed>`. The tap thread reads it and merges with `max` on every event and every wake, which replaces `anyTrackpadBlocksClicks`/`…DockSwipes`. The merged read is a single value, so a tap event can no longer see clicks from frame N and Dock swipes from frame N-1.
2. **`TapFilters`, one per installed tap.** It holds `ClickFilter`, `ScrollFilter`, one `DockSwipeFilter` per stream (29, 30) and `gateIsOpen`, which records what it last asked the gated port to be. It sits behind the `ClickTap`'s one `Mutex`, which replaces today's three. The tap thread writes it. Frame threads read it, only through `holding`, as today.
3. **The ports, a pair `(presses, gated)`.** Main writes them (install, remove). The tap thread switches `gated` and re-enables after a system disable, under the ports lock, as today's re-enable does.

**Two taps, one thread.**

- **The press tap.** Its mask is `1, 2, 3, 4, 25, 26`. It is enabled for as long as the click tap exists. Its mask keeps it asleep during pointing and scrolling (P2), and a click wakes it as today.
- **The gated tap.** Its mask is `6, 7, 27, 34, 22, 29, 30`, R1's set exactly.

Both sources sit on the existing `userInteractive` thread, with one callback and one `userInfo`. Why not one tap gated wide enough? Presses are never gated, so the frame-side press rule reads exactly today's `holding` and every press verdict is today's, by construction (per encode-lessons-in-structure). The alternatives section shows the cases where a single gated tap drifts.

The three press races keep today's code path:

- **A press before its finger's landing frame.** It is decided on the merged need left by the thumb's frame (`.watch`, so `blocksClicks` is false). It passes, reads `.click`, and spoils the tap: `[.pass, .pass]`.
- **A press right after a grant.** The fresh press tap is on from install, and the press is decided on the finger frame's `.clicks`: `[.drop, .drop]`. Its drags and pressure flow because the gated tap is either still on from creation or opened on the thumb's frame. `decide` also opens it before deciding any event that arrives while the need already wants it.
- **Thumb and finger on one frame.** Presses behave as today. For scrolling, see "Reopening".

**The gate.** It is wanted when `need.needsTap || click withholds a press || scroll is dropping or stilling (touching or coasting) || a Dock filter is dropping`. Every entry point settles the gate against that predicate:

- An **open** first resumes the filters (below).
- A **close** happens only when nothing is altered in flight, so R3 holds by the predicate itself.

`decide` settles before it decides, for a press or a straggler that arrives while a wake is still pending, and again after. It returns the net change, and the shell applies it before the verdict returns to the window server.

Why this closes Q-D's race structurally: only the tap thread switches the gated port, and it decides each event against the need it read for that event and settles on the same thread straight after. A frame thread lowering its need either precedes that read (the event passes and nothing is in flight) or follows it (the drop is committed and then holds the gate open). No interleaving closes the gate on an in-flight drop, and no lock is shared across threads for it.

The frame thread's per-frame work is one lock plus a compare. A transition costs:

- the frame thread `CFRunLoopPerformBlock` plus `CFRunLoopWakeUp` (a few µs);
- the tap thread a wake, one merge and one `tapEnable` (70-130 µs, outlier 2.6 ms, P3/P4);
- for a close, one echo later.

That comes to about five per gesture. The open lands roughly 0.1-0.2 ms after the frame. `docs/architecture.md:18` and plan 002:437 hold as written: frame threads publish, and only the tap's thread and main touch a port. The one new channel is a wake from the frame thread to the tap thread, which carries no data.

**Notices (P6, R4).** The handler treats a disabled notice as a prompt to reconcile, not a command, and it counts nothing. It reads `tapIsEnabled` on both ports:

- **The system disabled a tap** iff the press port reads off, or `gateIsOpen` is true and the gated port reads off. Then, as today, every filter forgets its memory and the press tap is re-enabled. `gateIsOpen` takes the port's actual state, and the gate settles: the gated tap comes back on only if a trackpad needs it now, since after forgetting nothing is in flight.
- **Otherwise it is our own echo.** The port reads off after our close, or on if we reopened before the echo arrived. Nothing is forgotten and nothing is switched beyond what the need asks.

Re-enabling the gated tap is allowed only through the gate's wish. A coalesced or lost echo cannot strand the state, because each notice re-reads the truth (per make-operations-idempotent).

**Reopening (Q-E).** The gate closes only on non-load-bearing memory: scroll `nil`, `.unseen`, `.coasting(.passed)` or `.touching(.passed)`; Dock `nil` or `.pass`. So the open overwrites exactly the stale state of C10(b) and C10(d), and never touches a gesture in flight.

- **Scroll.** The open takes `TapContext.scrollMayBeUnderWay`. If false, the stage becomes `nil` and the filter behaves as a fresh one. If true, the stage becomes a new `.unseen`, where `mayBegin` is a fresh start (dropped under the flag), `began` is judged as first seen mid-way (stilled under the flag), and momentum passes. The real tap cannot see what it was not sent, so `TapContext(need:)` estimates "may be under way" as `need >= .dockSwipes`: fingers are down beside the thumb, which is exactly the no-warning entries. A `.watch` opening means only a thumb is down on that pad.
  - Fingers resting, then the thumb, then a move (C11) is stilled, as today.
  - On the same-frame landing, either the open beats the system's `mayBegin` (dropped, as when today's frame wins), or the `mayBegin` beats it (stilled, as when today's `mayBegin` wins).
  - The fake builds `TapContext(need:scrollMayBeUnderWay:)` from what it actually withheld, so `SwapTests:324` (no `mayBegin` ever offered) still drops.
- **Dock.** Stale `.pass` resets to `nil` and `.drop` is kept. The next opening phase under the flag drops, and anything else passes. That keeps the block-biased behaviour of the 29/30 fix. D2 is settled by a hardware check: log field 132 for real three- and four-finger swipes and see whether 128 precedes 1. If it does, the thumb-under-rest case leaves the Dock a `mayBegin` with nothing after it, and `DockSwipeFilter.resume` should take the scroll's hint so that a `began` passes. The seam is already in place.

**Lifecycle (R4).** `run` replaces both taps and `TapFilters`, as today.

- **Install.** Both taps are created enabled, and `gateIsOpen` starts `true` to match. The tap thread publishes its run loop, runs its first `follow` (which closes the gated tap unless a frame already needs it), then calls `CFRunLoopRun`. Until that first turn the gated tap sees everything with fresh filters, like today's tap, so no gap needs resuming.
- **First frames.**
  - A thumb already down alone gives `.watch`, so the tap opens with warning.
  - A thumb already down with a finger gives `.dockSwipes`. Scrolling passes because `blocksClicks` is false, and the Dock is dropped from `nil`, as today's fresh filter does.
- **Revoke, hot-plug, wake, settings.** These go through `run`. After a revoke no tap exists. Sleep latches the need and may leave the gated tap on, which is free while no events flow, until `run`.
- **Idempotence.**
  - `follow` twice: the second returns nil.
  - `remove` twice: no-op.
  - A wake or an echo after `remove`: no-op, because the ports are nil.
  - `tapsWereDisabled` with the ports already as wished: nil.
  - A stale session after `run` only wakes its own dead tap.

**Testing seams (R2, Q-G).**

- **Unit.** `TapFilters` is the unit seam: scripted `(TapContext, TapEvent)` sequences and the changes they return. `TapNeed` is pinned per recognizer state, including `.watch` on the thumb frame before every first verdict in thumb-first scripts.
- **Behavioural.** The fake wraps a real `TapFilters` and models the window server's side:
  - events the press tap carries are always delivered while it is on;
  - events the gated tap carries are delivered only while `isGatedTapOn`;
  - `offer(_:) -> Delivery` tells `.notSent` from `.decided(.pass)`;
  - `scroll(_:)` keeps its apps'-view meaning (not sent counts as `.pass`), so every existing test passes unchanged;
  - `withLateWakes { }` holds the frame-to-tap wakes and the notices, so a test can show events passing in the open latency;
  - `systemDisablesTheTaps()` turns both taps off and queues their notice;
  - each close queues its echo.

  Nothing in the design waits on a clock. The recognizer's 3 s window runs on scripted `FrameTime`.
- **Platform.** `TapEventTests` pins the press mask `[1, 2, 3, 4, 25, 26]` and the gated mask `[6, 7, 22, 27, 29, 30, 34]`: disjoint, their union equal to today's 13 bits, every type parses, `ridesGatedTap` agrees with the mask it sits in, and 29/30 map to their streams. `DeviceSession` tests read the need per frame.
- **Manual.**
  - The Release-build per-frame CPU (proc_pid_rusage) against 0.088 ms over 40 s of pointing and scrolling.
  - The two-tap ordering probe (open question 1).
  - Hardware checks for C11 stilling, momentum of a dropped flick, a thumb-plus-two-finger Dock swipe blocked, D2, and debugger-pause recovery with the gate open and with it closed.

**Docs (R5).** Replace the last sentence of `docs/architecture.md:20` with:

> The one extra thread is the click tap's run loop, which exists only while click blocking is armed. It serves two taps. One over presses and releases is on for as long as it exists, and only a click wakes it. One over drags, pressure, scrolling and the system's gesture events is turned on by that thread only while some trackpad has a thumb in the anchor corner or a swipe, window swipe or swap series on, or while a press, a scroll with its momentum or a Dock swipe is still withheld or altered. It is turned off once none is, so ordinary pointing, dragging and scrolling never reach the app. A trackpad's frame thread only wakes that thread when what it needs changes.

Also:

- In `:25`, make "the event tap" plural.
- Change `SourcePolicyTests`' "R9 the one event tap" to "R9 the click tap's event taps, one file".
- Update the header comment in `ClickTap`.
- `docs/domain-model.md` describes behaviour that does not change.

**Depth.**

- The model, the port and `run` learn nothing.
- `DeviceSession` publishes one value and no longer writes two flags.
- `ClickTap` shrinks to parsing CGEvents, reading the need, calling one of three entry points, rewriting the event and toggling a port. It no longer knows which filter takes which event, which flag each reads, what to forget, or when the gated tap may come back on.
- `TapFilters` exposes three mutations, one per trigger (event, wake, notice), and two reads. Behind them sit the routing, the gate predicate, the reopen rules and the echo-versus-system logic.

### Module map and type sketch

| Module | Change |
|---|---|
| `LauncherCore` · `Recognition` / `GestureRecognizer` | `TapNeed` replaces the two Bools (derived accessors kept); `step` computes one level |
| `LauncherCore` · tap vocabulary | `TapEvent` moves here, CG-free (Dock swipes carry their stream); `TapVerdict`, `GateChange`, `TapDecision`, `TapContext` |
| `LauncherCore` · `TapFilters` | new: the three filters plus the gate |
| `LauncherCore` · `ScrollFilter`, `DockSwipeFilter`, `ClickFilter` | `.unseen` and `resume`, `resume`, plus in-flight queries (`package`) |
| `LauncherPlatform` · `ClickTap` | two ports, one thread; `needChanged()`, `follow()`, `recover()`; parsing and rewrites as today |
| `LauncherPlatform` · frame stream (`DeviceSession`) | `Mutex<TapNeed>`, a wake on change; `anyTrackpadNeed()` |
| Tests · `InMemoryTrackpads` | the real `TapFilters`, gated delivery, `offer`, late wakes, system disable |

```swift
// MARK: LauncherCore, beside Recognition

/// What one trackpad needs from the click tap after a frame. Ordered: each level includes those below it, so
/// `blocksClicks ⇒ blocksDockSwipes ⇒ needsTap` holds by construction.
public enum TapNeed: Int, Comparable, Sendable {
    /// No thumb in the corner, no slide, no swap series: nothing on this trackpad can block before its next frame.
    case none
    /// A thumb anchored alone, or a slide awaiting confirmation: nothing is blocked, but a verdict can appear on the
    /// next frame with none between, so the tap must already be seeing events.
    case watch
    /// A thumb with another contact down, its 3 s over or its landing unknown: the system's swipes are blocked.
    case dockSwipes
    /// Inside the blocking window, a confirmed swipe or window swipe, or a swap series: everything is blocked.
    case clicks

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    public var needsTap: Bool { self >= .watch }
    public var blocksDockSwipes: Bool { self >= .dockSwipes }
    public var blocksClicks: Bool { self == .clicks }
}

public struct Recognition: Equatable, Sendable {
    public let event: Event?
    public let tapNeed: TapNeed
    public var blocksClicks: Bool { tapNeed.blocksClicks }
    public var blocksDockSwipes: Bool { tapNeed.blocksDockSwipes }
    public init(event: Event?, tapNeed: TapNeed) { fatalError("not implemented") }
}

extension GestureRecognizer {
    // Tail of `step`, replacing today's two flags (same truth table, plus `.watch`):
    // TODO: confirmed swipe or series            -> .clicks
    //       thumb = state.thumb, another down     -> landing known && < 3 s ? .clicks : .dockSwipes
    //       thumb alone                           -> .watch
    //       .swiping (unconfirmed, thumb gone)    -> .watch
    //       otherwise                             -> .none
}

// MARK: LauncherCore, the click tap's vocabulary

/// The two gesture event types a Dock swipe may arrive as; each has its own filter.
public enum DockSwipeStream: Hashable, Sendable { case gesture, dockControl }   // types 29, 30

public enum TapEvent: Equatable, Sendable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    case dockSwipe(DockSwipePhase, DockSwipeStream)
    /// Presses and releases ride the press tap; everything else rides the gated tap. `TapEventTests` pins both masks to this.
    public var ridesGatedTap: Bool { fatalError("not implemented") }
}

public enum TapVerdict: Equatable, Sendable { case pointer(PointerVerdict), scroll(ScrollVerdict), dockSwipe(DockSwipeVerdict) }

/// What to do to the gated tap now.
public enum GateChange: Equatable, Sendable { case open, close }

public struct TapDecision: Equatable, Sendable {
    public let verdict: TapVerdict
    /// nil: leave the gated tap as it is. Applied before the verdict returns to the window server.
    public let gate: GateChange?
}

/// The trackpads as the tap's thread reads them when it acts.
public struct TapContext: Equatable, Sendable {
    /// The highest need of any running trackpad.
    public let need: TapNeed
    /// Whether a scroll gesture may be under way that the gated tap was never sent. Read only when the gate opens.
    public let scrollMayBeUnderWay: Bool
    /// The real tap's view: it cannot see what it was not sent, so it assumes a scroll may be under way whenever
    /// fingers are down beside a thumb (the openings with no warning frame).
    public init(need: TapNeed) { self.init(need: need, scrollMayBeUnderWay: need >= .dockSwipes) }
    /// For an adapter that knows what it withheld (the in-memory one).
    public init(need: TapNeed, scrollMayBeUnderWay: Bool) { fatalError("not implemented") }
}

// MARK: LauncherCore, TapFilters

/// The click tap's filters and the gate over its busy event types, as one pure value. Clock-free, device-free.
/// Invariant: after every call, `gateIsOpen` == some trackpad needs the tap, or a press is withheld, or a scroll is
/// dropped or stilled (through its momentum), or a Dock swipe is dropped. It turns off only when nothing is altered in
/// flight (R3). The exceptions are a fresh value (on, as `tapCreate` leaves the port) and a system disable not yet
/// noticed.
public struct TapFilters: Sendable {
    public init() { fatalError("not implemented") }

    /// Frame threads, through the click tap's lock: the press summary `TouchFrame.Press(holding:buttonDown:)` reads.
    public var holding: ClickFilter.Holding { click.holding }
    /// What this value last asked the gated tap to be.
    public private(set) var gateIsOpen = true

    /// One event either tap was handed, decided on the need read when it arrived.
    public mutating func decide(_ event: TapEvent, in context: TapContext) -> TapDecision {
        // TODO: let was = gateIsOpen
        //       settle(context)                 // a press or straggler arriving before a pending wake opens it first
        //       verdict = route: pointer -> click (blocksClicks); scroll -> scroll (blocksClicks);
        //                        dockSwipe(phase, stream) -> dock[stream] (blocksDockSwipes)
        //       settle(context)                 // a release, a momentum end or a swipe end may close it
        //       return TapDecision(verdict, gate: gateIsOpen == was ? nil : (gateIsOpen ? .open : .close))
        fatalError("not implemented")
    }

    /// A trackpad's need changed (the tap's thread was woken). Idempotent: a second call returns nil.
    public mutating func follow(_ context: TapContext) -> GateChange? { fatalError("not implemented") }

    /// A `tapDisabledBy…` notice: the system's, or the echo of our own close. The ports' states as read now.
    /// The caller re-enables the press tap whenever it reads off.
    public mutating func tapsWereDisabled(pressTapIsOn: Bool, gatedTapIsOn: Bool, in context: TapContext) -> GateChange? {
        // TODO: let systemDisabled = !pressTapIsOn || (gateIsOpen && !gatedTapIsOn)
        //       if systemDisabled { click.forgetHeldPresses(); scroll.forgetGesture(); dock = [:] }   // as today
        //       gateIsOpen = gatedTapIsOn                      // the port's truth
        //       settle(systemDisabled ? context with scrollMayBeUnderWay: false : context)   // R4: today's reset
        //       return the change relative to gatedTapIsOn
        fatalError("not implemented")
    }

    private mutating func settle(_ context: TapContext) {
        // TODO: wanted = context.need.needsTap || click.isWithholding || scroll.isAltering || dock.values.contains(\.isDropping)
        //       if wanted && !gateIsOpen { scroll.resume(scrollMayBeUnderWay: context.scrollMayBeUnderWay)
        //                                  dock.keys.forEach { dock[$0]!.resume() }; gateIsOpen = true }
        //       else if !wanted && gateIsOpen { gateIsOpen = false }
    }

    private var click = ClickFilter()
    private var scroll = ScrollFilter()
    private var dock: [DockSwipeStream: DockSwipeFilter] = [:]
}

// MARK: LauncherCore, filter additions

extension ClickFilter { package var isWithholding: Bool { holding == .withheld } }

extension ScrollFilter {
    // private enum Stage { case touching(Treatment), coasting(Treatment), unseen }
    // decide: from .unseen, fingers phases use the from-nil rule with only .mayBegin as an opening; momentum passes.
    /// A dropped or stilled gesture, touching or coasting: further events will be altered.
    package var isAltering: Bool { fatalError("not implemented") }
    /// The tap is handed events again after a stretch with none. An altered gesture is kept (the gate never closes on
    /// one; total anyway). Otherwise the stage becomes `.unseen` if a gesture may be under way, else nil.
    public mutating func resume(scrollMayBeUnderWay: Bool) { fatalError("not implemented") }
}

extension DockSwipeFilter {
    package var isDropping: Bool { fatalError("not implemented") }
    /// Keeps a dropped swipe; forgets a passing one (a missed `ended` must not pass the next swipe under the flag).
    /// TODO(D2): if Dock swipes send `mayBegin`, take the scroll's hint so a `began` after a no-warning open passes.
    public mutating func resume() { fatalError("not implemented") }
}

// MARK: LauncherPlatform, ClickTap (internal)

final class ClickTap: Sendable {
    /// Writer: the tap thread. Reader: frame threads (`holding`).
    private let filters = Mutex(TapFilters())
    /// Writer: main (install, remove). The tap thread switches `gated`, and re-enables either after a system disable.
    private let ports = Mutex<Unchecked<(presses: CFMachPort, gated: CFMachPort)>?>(nil)
    /// Writer: the tap thread, once, before its first turn. Readers: main (remove), frame threads (`needChanged`).
    private let runLoop = Mutex<Unchecked<CFRunLoop>?>(nil)

    /// Main. Both taps (press mask, gated mask) or nil. One thread: add both sources, publish the run loop, `follow()`,
    /// then `CFRunLoopRun`. Without Accessibility both creations fail; if only one did, the other is invalidated.
    @MainActor static func install() -> ClickTap? { fatalError("not implemented") }
    /// Frame thread.
    var holding: ClickFilter.Holding { filters.withLock { $0.holding } }
    /// Frame thread, on a change of its trackpad's need: `CFRunLoopPerformBlock(loop, commonModes) { follow() }` and
    /// `CFRunLoopWakeUp`. No-op before the loop is published (the first `follow()` reads the need) or after removal.
    func needChanged() { fatalError("not implemented") }
    /// Main. Idempotent. Disables and invalidates both ports, stops the loop.
    @MainActor func remove() { fatalError("not implemented") }
    /// Tap thread: read both ports' `tapIsEnabled`, call `tapsWereDisabled`, re-enable the press port if it read off,
    /// apply the change. Nothing when the ports are gone.
    private func recover() { fatalError("not implemented") }
    /// Tap thread, after the filters' lock is released: `tapEnable(gated, change == .open)` under the ports lock.
    private func switchGatedTap(_ change: GateChange?) { fatalError("not implemented") }
}

extension TapEvent {
    static let pressTypes: [CGEventType] = [/* 1, 2, 3, 4, 25, 26 */]
    static let gatedTypes: [CGEventType] = [/* 6, 7, 27, 34, 22, 29, 30 */]
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }   // 29 -> .gesture, 30 -> .dockControl
}

// MARK: LauncherPlatform, frame stream

// DeviceSession: `private let need = Mutex(TapNeed.none)`. Writer: its frame thread. Reader: the tap thread.
//   `var tapNeed: TapNeed`; `var blocksClicks: Bool { tapNeed.blocksClicks }` kept for DeviceSession tests.
/// Tap thread: the highest need of any running trackpad. Copies the sessions out first: never two locks at once.
func anyTrackpadNeed() -> TapNeed { fatalError("not implemented") }

// MARK: Tests, InMemoryTrackpads (additions)

extension InMemoryTrackpads {
    enum Delivery: Equatable { case noTap, notSent, decided(TapVerdict) }
    // private var tap: TapFilters?; private(set) var isGatedTapOn; private var isPressTapOn
    // private var needs: [TrackpadID: TapNeed]
    // private var scrollUnderWayUnseen: Bool   // set by an unsent mayBegin/began/changed, cleared by an unsent end, consumed by the next open
    // run: fresh TapFilters, both taps on, then one tap-thread turn (`follow`), which closes the gated tap.
    // touch: after each step, a changed need triggers a turn: follow(TapContext(need: max, scrollMayBeUnderWay: truth)).
    // Each `.close` queues its echo turn (tapsWereDisabled); turns run at once unless inside `withLateWakes`.
    /// An event as the window server would hand it: `.notSent` while its tap is off.
    func offer(_ event: TapEvent) -> Delivery { fatalError("not implemented") }
    /// Wakes and notices queue while `body` runs, then run in order: the open latency, made visible.
    func withLateWakes(_ body: () -> Void) { fatalError("not implemented") }
    /// A timeout: both taps off, their notice queued.
    func systemDisablesTheTaps() { fatalError("not implemented") }
    // scroll(_:) -> ScrollVerdict?: noTap -> nil, notSent -> .pass, decided(.scroll(v)) -> v. Unchanged meaning.
}
```

### Synthesis decision

### Tradeoffs accepted

- We accept a second event tap (a port and a source on the same thread, a reworded policy label) in exchange for presses and releases never being gated, so press verdicts and the frame-side press rule are today's by construction.
- We accept a frame-to-tap-thread wake on each change of need (a few µs, about five per gesture) and an open that lands about 0.1-0.2 ms after the frame, in exchange for one owner of the gated tap, no shared lock across threads, and plan 002's rule intact.
- We accept that on the no-warning entries (thumb and finger on one frame, a thumb under resting fingers, a resting thumb on a fresh recognizer's first frame) events in the first fraction of a millisecond pass unseen. Scrolling resolves to today's two race outcomes. The Dock rests on D2.
- We accept that the gate stays open after a dropped or stilled scroll that ended without momentum, or a dropped Dock swipe whose end never came, until the next scroll gesture or Dock swipe. That keeps "never relaxes" exactly as it is, at today's cost for that stretch.
- We accept that the in-memory fake knows what it withheld while the real tap estimates it from the need, in exchange for every existing test passing unchanged while C11 is stilled on hardware.
- We accept the estimate is per opening trackpad. Fingers resting on a second trackpad or a Magic Mouse while a thumb lands alone elsewhere can still lose a `mayBegin`, and so can a scroll begun before a `run`, which is now stilled where today it was dropped headless.
- We accept the gated tap being on from creation until the tap thread's first turn, as today's tap is, in exchange for every switch having one owner.

### Alternatives considered

- **One tap, gated wide (presses inside it, open whenever a thumb may act).** The surface is smaller, but a press that passes unseen while the gate is closed reads as nothing. Two cases follow. A mouse button held as the thumb lands alone, then a finger tap, fires the gesture beside a delivered click. A thumb's own press racing its landing frame does the same. `pressVerdicts` would also stop recording presses. Lost on R2, to save one port.
- **One mutex over needs, filters and applied state, with whoever changes an input calling `tapEnable` under it (Q-D (i)).** The open lands a few tens of µs sooner. In exchange, frame threads make WindowServer calls (bending 002:437 and the one-writer rule), contend on the tap's lock every frame, and absorb the 2.6 ms outlier. Lost: sole ownership closes the same race with less shared state.
- **A gate on the blocking flags alone (no `.watch`).** Every open would have no warning, so the common thumb-first flows would race the system's `mayBegin` and the Dock's opening against the enable, turning drops into stills and letting desktop switches through. Lost on R2.
- **Echo counting.** It breaks if echoes coalesce, or a system user-input disable lands in the count. Reading `tapIsEnabled` converges whatever arrived.
- **Hopping transitions to main.** Main can lag a frame or more (012:1267). Lost on latency.
- **Reinstalling the tap per transition.** That means `tapCreate` on main and filter resets. Lost on cost and memory loss.

### Open questions and risks

1. Does the window server hand our two taps events strictly in posting order (a press before its drags)? I expect yes, because tap processing is serial per event, but it is unprobed. A probe with two taps on one run-loop thread posting down, 20 drags, then up settles it. If the order is not guaranteed, should we fall back to one gated tap and accept the drift described under Alternatives?
2. Do real Dock swipes send `mayBegin` (field 132 == 128) before `began` (D2)? If they do, should `DockSwipeFilter.resume` take the scroll's hint and pass a `began` after a no-warning open, accepting a desktop switch in that race?
3. Is the fake's exact knowledge of what it withheld an acceptable reading of R2? The alternative is that the fake runs the real estimate and `SwapTests:324`'s `slid` assertion moves from `.drop` to `.passStill`, which is what the shipped build does on real hardware.
4. After a system timeout, should recovery keep today's `nil` (chosen, for R4 parity) or use `.unseen`, which never leaves apps a `mayBegin` without its end?
5. Should a coasting dropped scroll with no momentum be bounded, for example by event timestamps, so the gate cannot stay open until the next scroll? That would add a time rule to clock-free filters.
6. How much does `tapIsEnabled` cost inside the notice handler, and can it be trusted there? Probe it alongside question 1.

### Next implementation step

Run the two-tap ordering probe in `probes/tap-gating`, then add `TapNeed` to `Recognition` with a unit suite that pins `.watch` on the thumb frame before every first blocking verdict.
