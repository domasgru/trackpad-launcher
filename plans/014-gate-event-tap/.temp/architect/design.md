
## Design

### Problem

The one active session tap is enabled for the whole armed run, so every scroll, drag, pressure and system gesture event in the session makes a synchronous round trip through the app: 84% of its CPU while fingers touch (P9 in the grounding index). A disabled tap costs what no tap costs, the window server applies the event mask on its side, and `tapEnable` takes about 0.1 ms from any thread with its effect in place when it returns (probes P1-P4), so the mechanism is settled. The shape is set by what must not change. With a live click filter, a press the filter never saw reads as no press on the frame thread and cannot cancel a tap gesture (C7), so presses and releases must keep reaching the filter whenever a gesture or swap could complete. A blocking verdict can appear on a frame with no warning frame before it (C5). The filters' memory outlives the verdict: a withheld press until its release, a dropped or stilled scroll through its momentum (about a second after the lift, P10), a dropped Dock swipe until it ends (R3). A reopened gate has missed events, and the fingers-resting-then-thumb-then-move scroll must still be stilled, never dropped (C11), while a `mayBegin` after reopening is still a fresh start. Every `tapEnable(false)` we issue echoes a `tapDisabledByUserInput` into the callback, which today re-enables unconditionally (P6). Two kinds of thread change the gate's inputs (frame threads the verdicts, the tap thread the filters' memory) under one writer per field, a frame thread that never waits, and no timers (C14). `TrackpadHardware.run`, the model, `tapCreate`'s confinement to the tap's file and every existing behavioural test stay as they are.

### Usage (caller's view)

The model, the `TrackpadHardware` port and `MultitouchTrackpads.run` do not change: `run` still installs one `ClickTap` and removes it before the next. The new surface is one pure value in `LauncherCore`, `TapFilters`: the three filters plus the gate that decides whether the *gated port* receives events, driven by one ordered `Blocking` level per trackpad frame.

```swift
// README: the click tap's mind, one per installed tap, mutated only on the tap's thread. Fresh means closed.
var filters = TapFilters()
filters.follow(.estimated(from: .none))                     // nil: nobody wants the gated port
filters.follow(.estimated(from: .possible))                 // .open: a thumb landed alone in the corner
filters.decide(.scroll(.fingers(.mayBegin)), in: .estimated(from: .clicks))
                                                            // TapDecision(verdict: .scroll(.drop), gate: nil)
filters.follow(.estimated(from: .none))                     // nil: the dropped scroll still holds the gate open
filters.decide(.scroll(.momentum(.ended)), in: .estimated(from: .none)).gate   // .close: nothing left in flight
```

Call site 1, the frame thread in `DeviceSession.receive`: one write with a compare per frame, and a wake-up of the tap thread only when this trackpad's `wantsTap` flips. It never touches a port:

```swift
let recognition = recognizer.withLock { /* answer, step, travel: as today */ }
let flipped = blocking.withLock { was in defer { was = recognition.blocking }; return was.wantsTap != recognition.blocking.wantsTap }
if flipped { clickTap?.wake() }
```

Call site 2, the tap thread in `ClickTap`, the only code that switches the gated port:

```swift
fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { recover(); return .passUnretained(event) }
    guard let parsed = TapEvent(type, event) else { return .passUnretained(event) }   // a non-Dock gesture event: no lock
    let context = TapContext.estimated(from: mergedBlocking())                        // read before the filters' lock
    let decision = filters.withLock { $0.decide(parsed, in: context) }
    apply(decision.gate)                                                              // before the verdict returns to the window server
    return decision.verdict.apply(to: event)
}
/// The wake-up source's perform, and the thread's first act before its loop runs.
private func follow() { apply(filters.withLock { $0.follow(TapContext.estimated(from: mergedBlocking())) }) }
```

Call site 3, the behavioural fake and a World test. `scroll(_:)` and `pressVerdicts` keep their meaning, so every existing test runs unchanged; `offer(_:)` and `isGatedPortOn` are the new handles:

```swift
// R1: two fingers scroll a page for 40 s, away from the corner. The gated port never opens; the app is sent nothing.
let world = World.switcherWorld(accessGranted: true)
let scrolling = TouchScript(.macBook14).land(fingers: 2).slide(byMM: (0, 400), over: .seconds(40))
#expect(world.playFrameByFrame(scrolling) { world.hardware.isGatedPortOn }.allSatisfy { !$0 })
#expect(world.hardware.offer(.scroll(.fingers(.changed))) == .notSent)
#expect(world.hardware.scroll(.fingers(.changed)) == .pass)                  // the apps' view, as today

// R3: a flick dropped under the thumb keeps reaching the tap after the thumb lifts, until its momentum ends.
let flick = World.switcherWorld(accessGranted: true)
flick.play(TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2).slide(byMM: (0, -20)).lift().liftThumb())
#expect(flick.hardware.offer(.scroll(.momentum(.changed))) == .decided(.scroll(.drop)))
#expect(flick.hardware.offer(.scroll(.momentum(.ended))) == .decided(.scroll(.drop)))
#expect(!flick.hardware.isGatedPortOn)

// C11: fingers rest, a thumb lands under them, the fingers move. Apps saw the mayBegin, so the rest is stilled.
let rest = World.switcherWorld(accessGranted: true)
var script = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
rest.play(script)
#expect(rest.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)
script = script.thumb(atMM: (10, 10)).wait(.milliseconds(50)).slide(byMM: (10, 0))
rest.play(script)
#expect(rest.hardware.scroll(.fingers(.began)) == .passStill)
```

### Shape

**Data first.** Three pieces of state, each with one writer, merged where they are read (per `separate-before-serializing-shared-state`).

1. *`Blocking`, one level per trackpad per frame*, in `Recognition`, replacing the two Bools. Ordered `none < possible < dockSwipes < clicks`, so `blocksClicks ⇒ blocksDockSwipes ⇒ wantsTap` is a construction, not a comment (per `type-system-discipline`). `.possible` is the new information, R1's "a thumb anchored, a swipe or window swipe in progress": a thumb alone in `.armed` or `.spoiled`, a thumb under a rest with no other contact, or a slide awaiting its confirmation after its thumb left. In every thumb-first flow it is up at least one frame before a verdict can appear; on the no-warning entries (thumb and finger on one frame, a thumb under resting fingers, a resting thumb on a fresh recognizer's first frame) the level is already `.dockSwipes` or `.clicks` on that frame. Written by its device's frame thread into one `Mutex<Blocking>`; read by the tap thread and merged with `max` per event and per wake, which replaces `anyTrackpadBlocksClicks()` and `anyTrackpadBlocksDockSwipes()` and ends the case where one tap event saw clicks from frame N and Dock swipes from frame N-1. The existing accessors stay as derived properties, so every recognizer test compiles unchanged; `Recognition` is constructed only in `step`.
2. *`TapFilters`, one per installed tap*: `ClickFilter`, `ScrollFilter`, one `DockSwipeFilter` per stream (29, 30) and `gateIsOpen`, what it last asked the gated port to be. Behind the `ClickTap`'s one `Mutex`, which replaces today's three. The tap thread writes it; frame threads read it only through `holding`, as today.
3. *The ports, `(presses, gated)`*, written by main at install and remove; the tap thread switches `gated` and re-enables after a system disable, under the ports lock, as today's re-enable does.

**Two ports, one thread.** The *press port* masks 1, 2, 3, 4, 25, 26 and is enabled for as long as the tap exists: the mask keeps it asleep during pointing and scrolling (P2), a click wakes it as today, and the frame-side press rule reads exactly today's `holding` with every press verdict today's, by construction (per `encode-lessons-in-structure`). The *gated port* masks 6, 7, 27, 34, 22, 29, 30, R1's set exactly. Both sources sit on the existing `userInteractive` thread with one callback and one `userInfo`; a third source, a version-0 run-loop source whose perform is `follow()`, is the wake-up frame threads signal (it coalesces and allocates nothing on the frame thread). The three press races keep today's path: a press before its finger's landing frame is decided on the thumb frame's `.possible` (`blocksClicks` false), passes, reads `.click` and spoils the tap; a press right after a grant is decided on the finger frame's `.clicks` and dropped, its drags and pressure flowing because the gate opened on the thumb's frame; thumb and finger on one frame decide presses as today.

**The gate.** Wanted iff `blocking.wantsTap || click.isWithholding || scroll.isSuppressing || any dock.isDropping`. Every entry point settles against that predicate: an open first resumes the filters (below); a close happens only when nothing is altered in flight, so R3 holds by the predicate itself. `decide` settles before deciding (a press or a straggler arriving before a pending wake opens the gate first, with the reopen rules) and again after (a release, a momentum end or a swipe end may close it), returning the net change, which the shell applies before the verdict returns to the window server. Only the tap thread switches the gated port, and it decides each event against the level it read for that event and settles on the same thread straight after; a frame thread lowering its level either precedes that read (the event passes and nothing is in flight) or follows it (the drop is committed and holds the gate open). No interleaving closes the gate on an in-flight drop and no lock is shared across threads for it. The frame thread's cost per frame is one lock and a compare; a transition costs it a signal and a wake-up, and the tap thread a merge and one `tapEnable` (70-130 µs, one 2.6 ms outlier, P3), with one echo for each close. `docs/architecture.md:18` and plan 002's "nothing on the frame thread enables or disables the tap" hold as written, and the latter becomes a source-policy row confining `tapEnable` to the tap's file.

**Notices (P6, R4).** `recover()` treats a disabled notice as a prompt to reconcile, not a command, and counts nothing: it reads `tapIsEnabled` on both ports (20-47 µs each, on a notice only) and hands both to `portsWereDisabled`. The press port reading off is the system's doing: held presses are forgotten and the port re-enabled, as today. The gated port reading off while `gateIsOpen` is true is the system's doing: the scroll and Dock filters forget (the stage goes to nil, today's reset) and the gate settles, reopening only if a trackpad wants it now. Otherwise the notice is the echo of our own close (the port reads off after it, or on if we reopened before the echo arrived): nothing is forgotten, nothing switched beyond what the level asks. A lost or coalesced echo cannot strand the state, because each notice re-reads the truth (per `make-operations-idempotent`). Forgetting is per port: a timeout on the gated port never releases a withheld press's mouse-up that the press port never missed.

**Reopening (Q-E).** The gate closes only on non-load-bearing memory (scroll nil, `.unseen`, `.coasting(.passed)` or `.touching(.passed)`; Dock nil or `.pass`), so the open overwrites exactly the stale state of C10(b) and C10(d) and never touches a gesture in flight. The scroll filter's `resume(scrollMayBeUnderWay:)` sets the stage to `.unseen` when a scroll may be under way, else nil. From `.unseen`, a `mayBegin` is a fresh start (dropped under the flag, as every thumb-first test pins), `began` and the mid phases are first seen mid-way (stilled under the flag: apps already got the `mayBegin`, P10), momentum passes and its end clears to nil. The real tap cannot see what it was not sent, so `TapContext.estimated(from:)` takes "fingers are down beside the thumb", `blocking >= .dockSwipes`, as "a scroll may be under way": the no-warning entries exactly. A `.possible` opening (a thumb alone) resumes to nil. So fingers resting, then the thumb, then a move is stilled (C11, today's hardware outcome); on the same-frame landing either the open beats the system's `mayBegin` (dropped) or the `mayBegin` beats it (stilled), today's two outcomes. The fake builds its context from what it actually withheld, so a script that never offered a `mayBegin` (`SwapTests:324`) still drops. The Dock filter's `resume()` keeps a `.drop` and forgets a `.pass`; a `began` first seen after an open drops under the flag, the block-biased behaviour of the 29/30 fix, pending D2.

**Lifecycle (R4).** `run` replaces both ports and the `TapFilters`, as today. `install` creates both ports, disables the gated one at once on main (main is the ports' writer at install and remove), starts the thread, which adds the three sources, publishes its loop, runs `follow()` (opening the gate if a frame already wants it) and then its loop: a fresh value is closed and converges from there, and nothing queues before the thread runs. A thumb already down alone on the first frame gives `.possible` (an open with warning); a thumb with a finger gives `.dockSwipes` or `.clicks`: scrolling passes or stills as today, the Dock drops from nil. Revoke, hot-plug, wake and setting changes all go through `run`; after a revoke no tap exists; sleep latches the level and may leave the gated port on, which is free while no events flow, until the wake's `run`. `follow` twice returns nil the second time; `remove` twice is a no-op; a wake or an echo after `remove` finds no ports; a stale session after `run` only wakes its own removed tap.

**Testing seams (R2, Q-G).** Unit: `TapFilters` with scripted `(TapContext, TapEvent)` sequences and the changes they return; `Blocking` pinned per recognizer state, including `.possible` on the thumb frame before every first verdict in thumb-first scripts; the `.unseen` rows; `TapContext.estimated(from:)`. Behavioural: the fake wraps a real `TapFilters` and models the window server's side: press-port events are always delivered while armed; gated-port events are delivered only while `isGatedPortOn`; `offer(_:) -> Delivery` tells `.notSent` from `.decided(.pass)`; `scroll(_:)` keeps its apps'-view meaning (not sent counts as `.pass`); `pressVerdicts` is unchanged; `withLateWakes { }` holds the wakes and the notices so a test can show events passing in the open latency; `systemDisablesThePorts()` turns both off and queues their notice; each close queues its echo. Nothing waits on a clock: the 3 s window runs on scripted `FrameTime`. Platform: `TapEventTests` pins the press mask `[1, 2, 3, 4, 25, 26]` and the gated mask `[6, 7, 22, 27, 29, 30, 34]`, disjoint, union today's 13 bits, every type parsing, `ridesGatedPort` agreeing with the mask each type sits in, 29 and 30 mapping to their streams; `DeviceSessionAnswerTests` reads the level per frame. Manual: the Release-build CPU per frame (proc_pid_rusage) against 0.088 ms over 40 s of pointing and scrolling; hardware checks for C11 stilling, a dropped flick's momentum, a thumb-plus-two-finger Dock swipe blocked, D2, and the debugger-pause recovery with the gate open and closed.

**Docs (R5).** Replace the last sentence of `docs/architecture.md`'s Concurrency section (line 20) with: "The one extra thread is the click tap's run loop, which exists only while click blocking is armed and serves two event taps. One, over presses and their releases, is on for as long as it exists, and only a click wakes it. The other, over drags, pressure, scrolling and the system's gesture events, is turned on by that thread only while some trackpad has a thumb in the anchor corner or a swipe, window swipe or swap series on, or while a press, a scroll gesture with its momentum or a Dock swipe is still withheld or altered, and turned off once none is, so ordinary pointing, dragging and scrolling never reach the app. A trackpad's frame thread only wakes that thread when what it needs flips." In line 25 "the event tap" becomes "the event taps". `SourcePolicyTests`: the "R9 the one event tap" label becomes "the click tap's event taps, one file", and `tapEnable` joins the tokens confined to `ClickTap.swift`. `docs/domain-model.md` describes behaviour that does not change.

**Depth.** The model, the port and `run` learn nothing. `DeviceSession` publishes one value instead of two flags. `ClickTap` shrinks to parsing `CGEvent`s, reading the merged level, calling one of three entry points, rewriting the event and switching one port; it no longer knows which filter takes which event, what each reads, what to forget, or when the gated port may come back on. `TapFilters` exposes three mutations, one per trigger (event, wake, notice), and two reads; behind them sit the routing, the gate predicate, the reopen rules and the echo-versus-system logic, and the fake wraps the same value, so none of those rules exists twice.

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` · `Recognition` / `GestureRecognizer` | `Blocking` replaces the two Bools (derived accessors kept); `step` computes one level |
| `LauncherCore` · tap vocabulary | `TapEvent` moves here, CG-free (a Dock swipe carries its stream); `TapVerdict`, `GateChange`, `TapDecision`, `TapContext` |
| `LauncherCore` · `TapFilters` | new: the three filters plus the gate |
| `LauncherCore` · `ClickFilter`, `ScrollFilter`, `DockSwipeFilter` | in-flight queries; `.unseen` and `resume` on the scroll filter, `resume` on the Dock filter |
| `LauncherPlatform` · `ClickTap` | two ports, one thread, the wake-up source; `wake()`, `follow()`, `recover()`, `apply(_:)`; parsing and rewrites as today |
| `LauncherPlatform` · frame stream (`DeviceSession`) | `Mutex<Blocking>`, a wake on a `wantsTap` flip; `mergedBlocking()` |
| Tests · `InMemoryTrackpads` | the real `TapFilters`, gated delivery, `offer`, late wakes, a system disable |

#### Type sketch

```swift
// MARK: LauncherCore, beside Recognition

/// How far one trackpad's blocking reaches after a frame. Ordered: each level includes those below it, so
/// `blocksClicks ⇒ blocksDockSwipes ⇒ wantsTap` holds by construction.
public enum Blocking: Int, Comparable, Sendable {
    /// No thumb in the corner, no slide, no swap series: nothing on this trackpad can block before its next frame.
    case none
    /// A thumb anchored alone, or a slide awaiting its confirmation: nothing is blocked, but a verdict can appear on
    /// the next frame with none between, so the gated port must already be receiving events.
    case possible
    /// A thumb with another contact down, its 3 s over or its landing unknown: the system's swipes are blocked.
    case dockSwipes
    /// Inside the blocking window, a confirmed swipe or window swipe, or a swap series: everything is blocked.
    case clicks

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    public var wantsTap: Bool { self >= .possible }
    public var blocksDockSwipes: Bool { self >= .dockSwipes }
    public var blocksClicks: Bool { self == .clicks }
}

public struct Recognition: Equatable, Sendable {
    public let event: Event?
    public let blocking: Blocking
    public var blocksClicks: Bool { blocking.blocksClicks }
    public var blocksDockSwipes: Bool { blocking.blocksDockSwipes }
    public init(event: Event?, blocking: Blocking) { fatalError("not implemented") }
}

extension GestureRecognizer {
    // Tail of `step`, replacing today's two flags (same truth table, plus `.possible`):
    // TODO: confirmed swipe or series                     -> .clicks
    //       thumb = state.thumb, another contact down     -> landing known && < 3 s ? .clicks : .dockSwipes
    //       thumb alone                                   -> .possible
    //       .swiping, unconfirmed, thumb gone             -> .possible
    //       otherwise (idle, a rest with no thumb)        -> .none
}

// MARK: LauncherCore, the click tap's vocabulary

/// The two gesture event types a Dock swipe may arrive as; each has its own filter.
public enum DockSwipeStream: Hashable, Sendable { case gesture, dockControl }   // types 29, 30

public enum TapEvent: Equatable, Sendable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    case dockSwipe(DockSwipePhase, DockSwipeStream)
    /// Presses and releases ride the press port; drags, pressure, scrolls and Dock swipes ride the gated port.
    /// `TapEventTests` pins both masks to this.
    public var ridesGatedPort: Bool { fatalError("not implemented") }
}

public enum TapVerdict: Equatable, Sendable { case pointer(PointerVerdict), scroll(ScrollVerdict), dockSwipe(DockSwipeVerdict) }

/// What to do to the gated port now.
public enum GateChange: Equatable, Sendable { case open, close }

public struct TapDecision: Equatable, Sendable {
    public let verdict: TapVerdict
    /// nil: leave the gated port as it is. Applied before the verdict returns to the window server.
    public let gate: GateChange?
}

/// The trackpads as the tap's thread reads them when it acts.
public struct TapContext: Equatable, Sendable {
    /// The highest level of any running trackpad.
    public let blocking: Blocking
    /// Whether a scroll gesture may be under way that the gated port was never sent. Read only when the gate opens.
    public let scrollMayBeUnderWay: Bool
    public init(blocking: Blocking, scrollMayBeUnderWay: Bool) { fatalError("not implemented") }
    /// The real tap's view: it cannot see what it was not sent, so it takes fingers down beside a thumb (the openings
    /// with no warning frame) as "a scroll may be under way". The in-memory adapter knows what it withheld instead.
    public static func estimated(from blocking: Blocking) -> TapContext {
        TapContext(blocking: blocking, scrollMayBeUnderWay: blocking >= .dockSwipes)
    }
}

// MARK: LauncherCore, TapFilters

/// The click tap's filters and the gate over its busy event types, as one pure value. Clock-free, device-free.
/// Invariant: after every call, `gateIsOpen` == some trackpad wants the tap, or a press is withheld, or a scroll is
/// dropped or stilled (through its momentum), or a Dock swipe is dropped. It closes only when nothing is altered in
/// flight (R3). The one exception is a system disable not yet noticed. A fresh value is closed.
public struct TapFilters: Sendable {
    public init() { fatalError("not implemented") }

    /// Frame threads, through the click tap's lock: the summary `TouchFrame.Press(holding:buttonDown:)` reads.
    public var holding: ClickFilter.Holding { click.holding }
    /// What this value last asked the gated port to be.
    public private(set) var gateIsOpen = false

    /// One event either port was handed, decided on the level read when it arrived.
    public mutating func decide(_ event: TapEvent, in context: TapContext) -> TapDecision {
        // TODO: let was = gateIsOpen
        //       settle(context)                 // a press or a straggler arriving before a pending wake opens it first
        //       verdict = route: pointer -> click (blocksClicks); scroll -> scroll (blocksClicks);
        //                        dockSwipe(phase, stream) -> dock[stream] (blocksDockSwipes)
        //       settle(context)                 // a release, a momentum end or a swipe end may close it
        //       return TapDecision(verdict, gate: gateIsOpen == was ? nil : (gateIsOpen ? .open : .close))
        fatalError("not implemented")
    }

    /// A trackpad's `wantsTap` flipped (the tap's thread was woken), or the thread's first turn. Idempotent: a second
    /// call returns nil.
    public mutating func follow(_ context: TapContext) -> GateChange? { fatalError("not implemented") }

    /// A `tapDisabledBy…` notice: the system's, or the echo of our own close. The ports' states as read now. The
    /// caller re-enables the press port whenever it read off.
    public mutating func portsWereDisabled(pressPortIsOn: Bool, gatedPortIsOn: Bool, in context: TapContext) -> GateChange? {
        // TODO: if !pressPortIsOn { click.forgetHeldPresses() }                        // its releases may have passed
        //       let gatedBySystem = gateIsOpen && !gatedPortIsOn
        //       if gatedBySystem { scroll.forgetGesture(); dock = [:] }                 // today's reset: nil, not .unseen
        //       gateIsOpen = gatedPortIsOn                                              // the port's truth
        //       settle(gatedBySystem ? TapContext(blocking: context.blocking, scrollMayBeUnderWay: false) : context)
        //       return gateIsOpen == gatedPortIsOn ? nil : (gateIsOpen ? .open : .close)
        fatalError("not implemented")
    }

    private mutating func settle(_ context: TapContext) {
        // TODO: wanted = context.blocking.wantsTap || click.isWithholding || scroll.isSuppressing || dock.values.contains(\.isDropping)
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
    // decide, from .unseen: .fingers(phase): !blocking -> passed; phase == .mayBegin -> dropped (a fresh start);
    //                       otherwise -> stilled (apps saw it open). .momentum: pass; momentum(.ended) -> stage = nil.
    /// A dropped or stilled gesture, touching or coasting: further events will be dropped or stilled.
    package var isSuppressing: Bool { fatalError("not implemented") }
    /// The gated port is receiving events again after a stretch with none. A suppressed gesture is kept (the gate
    /// never closes on one; total anyway). Otherwise the stage becomes `.unseen` if a gesture may be under way, else nil.
    public mutating func resume(scrollMayBeUnderWay: Bool) { fatalError("not implemented") }
    // forgetGesture() is unchanged: nil. It serves the system's disable only (R4: today's recovery).
}

extension DockSwipeFilter {
    package var isDropping: Bool { fatalError("not implemented") }
    /// Keeps a dropped swipe; forgets a passing one (a missed `ended` must not pass the next swipe under the flag).
    /// TODO(D2): if real Dock swipes send `mayBegin`, take the scroll's hint so a `began` after a no-warning open passes.
    public mutating func resume() { fatalError("not implemented") }
}

// MARK: LauncherPlatform, ClickTap (internal)

/// The app's event taps: two active session taps on one `userInteractive` thread. The press port listens for the
/// tap's whole life; the gated port only while `TapFilters` says so. Threads: installed and removed on main. The
/// callback, `follow()` and `recover()` run on the tap thread, the only caller of `tapEnable` on the gated port.
/// Frame threads only read `holding` and call `wake()`.
final class ClickTap: Sendable {
    /// Writer: the tap thread. Reader: frame threads (`holding`).
    private let filters = Mutex(TapFilters())
    /// Writer: main (install, remove). The tap thread switches `gated` and re-enables `presses`, under this lock.
    private let ports = Mutex<Unchecked<(presses: CFMachPort, gated: CFMachPort)>?>(nil)
    /// Writer: the tap thread, once, before its first turn. Readers: main (remove), frame threads (`wake`).
    private let runLoop = Mutex<Unchecked<CFRunLoop>?>(nil)
    /// A version-0 run-loop source whose perform is `follow()`. Created with the tap, added to the loop by the tap
    /// thread, signalled by frame threads. Signals coalesce; one before the loop runs is honoured by the first `follow()`.
    private let wakeUp: Unchecked<CFRunLoopSource>

    /// Main. Two `tapCreate` calls (press mask, gated mask) or nil; if only one succeeded, it is invalidated and nil is
    /// returned. The gated port is disabled at once. One thread: add the three sources, publish the loop, `follow()`,
    /// then `CFRunLoopRun`.
    @MainActor static func install() -> ClickTap? { fatalError("not implemented") }
    /// Frame thread.
    var holding: ClickFilter.Holding { filters.withLock { $0.holding } }
    /// Frame thread, when its trackpad's `wantsTap` flipped: `CFRunLoopSourceSignal(wakeUp)` then `CFRunLoopWakeUp`
    /// on the published loop, if any. Never waits; a no-op after removal.
    func wake() { fatalError("not implemented") }
    /// Main. Idempotent. Disables and invalidates both ports, invalidates the source, stops the loop.
    @MainActor func remove() { fatalError("not implemented") }
    /// Tap thread, also the wake-up source's perform.
    private func follow() { fatalError("not implemented") }
    /// Tap thread, on a disabled notice: read both ports' `tapIsEnabled`, call `portsWereDisabled`, re-enable the
    /// press port if it read off, apply the change. Nothing when the ports are gone.
    private func recover() { fatalError("not implemented") }
    /// Tap thread, after the filters' lock is released: `tapEnable(gated, change == .open)` under the ports lock.
    private func apply(_ change: GateChange?) { fatalError("not implemented") }
}

extension TapEvent {
    static let pressTypes: [CGEventType] = [/* 1, 2, 3, 4, 25, 26 */]
    static let gatedTypes: [CGEventType] = [/* 6, 7, 27, 34, 22, 29, 30 */]
    static var pressMask: CGEventMask { fatalError("not implemented") }
    static var gatedMask: CGEventMask { fatalError("not implemented") }
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }   // 29 -> .gesture, 30 -> .dockControl
}

// MARK: LauncherPlatform, frame stream

// DeviceSession: `private let blocking = Mutex(Blocking.none)`. Writer: its frame thread. Reader: the tap thread.
//   `var blocking: Blocking`; `var blocksClicks: Bool { blocking.blocksClicks }` kept for the DeviceSession tests.
/// Tap thread: the highest level of any running trackpad. Copies the sessions out first: never two locks at once.
func mergedBlocking() -> Blocking { fatalError("not implemented") }

// MARK: Tests, InMemoryTrackpads (additions)

extension InMemoryTrackpads {
    enum Delivery: Equatable { case noTap, notSent, decided(TapVerdict) }
    // private var tap: TapFilters?; private(set) var isGatedPortOn; private var isPressPortOn
    // private var levels: [TrackpadID: Blocking]
    // private var scrollUnderWayUnseen: Bool   // set by an unsent mayBegin/began/changed, cleared by an unsent ended/cancelled
    // run: fresh TapFilters (closed), press port on, then one tap-thread turn: follow(TapContext(blocking: max, scrollMayBeUnderWay: truth)).
    // touch: after each step, a flipped wantsTap queues a turn. Each .close queues its echo turn (portsWereDisabled).
    //        Turns run at once unless inside `withLateWakes`. The press edge is decided on the previous frame's level, as today.
    /// An event as the window server would hand it: `.notSent` while its port is off.
    func offer(_ event: TapEvent) -> Delivery { fatalError("not implemented") }
    /// Wakes and notices queue while `body` runs, then run in order: the open latency, made visible.
    func withLateWakes(_ body: () -> Void) { fatalError("not implemented") }
    /// A timeout: both ports off, their notice queued.
    func systemDisablesThePorts() { fatalError("not implemented") }
    // scroll(_:) -> ScrollVerdict?: noTap -> nil, notSent -> .pass, decided(.scroll(v)) -> v. Unchanged meaning.
}
```

### Synthesis decision

Both candidates converged on the backbone: two active session taps on the one tap thread (a press port always on, a gated port over R1's seven types), one ordered level per frame replacing the two Bools, the tap thread as the sole caller of `tapEnable` woken by frame threads, a pure gate in core, an `.unseen` scroll stage at reopening, the Dock filter kept at nil semantics pending D2, a fake that tells "never delivered" from "passed", the same R5 sentence. That consensus ships as is.

**Base: candidate 1** (the Opus runner), on interface depth: its `TapFilters` keeps the routing, the gate predicate, the reopen rules and the echo-versus-system logic in one pure value the fake wraps unchanged, so no rule exists twice; it keeps the press rule and the recorded races by construction and `SwapTests:324` (fingers rest, thumb tap, slide, a bare `began` expected `.drop`) by letting the fake know what it withheld; it reconciles notices by reading both ports' state, which converges whatever number of echoes arrived; it keeps the timeout path at today's nil. The architect scored 17 to 11 and the cross-judge (a different model) 16 to 9, both for candidate 1 on the same grounds; the judge further found that candidate 2's `.unseen` at every opening would flip seven existing `.drop` assertions (`ScrollSuppressionTests:12, 30, 85`, `WindowSwipeBlockingTests:113`, `SwitcherAssignedAppsTests:120`, `SwipeSettingTests:51`, `SwapTests:324`), that its echo ledger can leave the gated port off while a drop is in flight after one lost echo, and that its usage cited `thumbTap(lift:)`, which does not exist.

**Grafted from candidate 2:** the names (`Blocking` with `.none / .possible / .dockSwipes / .clicks`, `Recognition.blocking`, `wantsTap`, `isSuppressing`, the domain's words); the wake-up as a coalescing version-0 run-loop source signalled only when a trackpad's `wantsTap` flips (candidate 1 woke on every level change through `CFRunLoopPerformBlock`, a block per change); forgetting per port on a system disable (the judge's graft: a gated-port timeout never releases a withheld press's mouse-up); the source-policy row confining `tapEnable` to the tap's file; and, one step beyond its apply-before-the-loop, disabling the gated port on main at install so a fresh value is closed and nothing queues before the thread runs.

**Rejected:** candidate 2's `GateLedger` (a counter for a fact the port can be asked); its `.unseen` at every reopening and for the timeout path (R2, R4); its separate four-Bool `TapGate` and the settle rule written again in the fake (shallow, and one policy in two places); candidate 1's `TapContext.init(need:)` that hid the estimate in an initializer (now the named `estimated(from:)`).

**Added from the post-fan-out checks** (`.temp/architect/checks/`): two ports deliver in posting order at trackpad rates (500 Hz and 125 Hz, strictly alternating) and lose cross-port order only once a backlog builds, so the two-port hazard is confined to a stalled tap thread; `tapIsEnabled` costs 20-47 µs per call; the lingering coast after a dropped scroll that ends without momentum is recorded as an open question.

### Tradeoffs accepted

- We accept a second event tap (a port and a source on the same thread, a reworded policy label) in exchange for presses and releases never being gated, so press verdicts and the frame-side press rule are today's by construction.
- We accept a wake of the tap thread on each flip of a trackpad's `wantsTap` and an open that lands about 0.1-0.3 ms after the frame, in exchange for one owner of the gated port, no lock shared across threads for the gate, and plan 002's rule intact as a build rule.
- We accept that on the no-warning entries events in the first fraction of a millisecond pass unseen; scrolling then resolves to today's two race outcomes (dropped or stilled), and the Dock rests on D2.
- We accept that a dropped or stilled scroll that ends without momentum, which is most swipe lifts, keeps the gated port on until the next scroll gesture's first event, so pointing after such a swipe costs today's amount until the user next scrolls. "Never relaxes" stays exactly as it is and no clock enters the filters; R1's predicate is the filter's own memory, so this is inside the requirement.
- We accept that the fake knows what it withheld while the real tap estimates it from the level, in exchange for every existing test passing unchanged while C11 is stilled on hardware; the estimate is one unit-tested line. Fingers resting on a second trackpad or a Magic Mouse while a thumb lands alone elsewhere can still lose a `mayBegin` (dropped where today stilled), and a scroll begun before a `run` is now stilled where today it resumed headless.
- We accept that cross-port order is lost if the tap thread stalls long enough for a backlog to build, when a withheld press's first drags may be decided before its down and pass as plain drags; the same stall today ends in a timeout disable that under-blocks far more.
- We accept two `tapIsEnabled` round trips per notice, in exchange for no echo counter and convergence whatever arrived.
- We accept a larger diff than a point fix (`TapEvent` moves to core, three Mutexes become one, four small core types), in exchange for the whole policy living once, in the module the suite drives.

### Alternatives considered

- **One tap, gated wide (presses inside it, open whenever a thumb may act).** Smaller surface, strict FIFO by construction. A press that passes unseen while the gate is closed reads as nothing: a mouse button held as the thumb lands alone, then a finger tap, fires the gesture beside a delivered click, and a thumb's own press racing its landing frame does the same. Closing that needs the tap to seed a `.passed` entry from the button state at every opening, a press the filter never saw: a third source of truth about a press beside the filter and the button state. Lost on R2 and on exposing a timing hazard to the recognizer to save one port.
- **One mutex over levels, filters and applied state, with whoever changes an input calling `tapEnable` under it (Q-D (i)).** The open lands a few tens of µs sooner. Frame threads make WindowServer calls (bending plan 002's rule and the one-writer rule), contend on the tap's lock every frame, and absorb the 2.6 ms outlier. Lost: sole ownership closes the same race with less shared state.
- **A gate on the blocking flags alone, without `.possible`.** Every open would be a no-warning open, so the common thumb-first flows would race the system's `mayBegin` and the Dock's opening against the enable, turning drops into stills and letting desktop switches through. Lost on R2.
- **Echo counting.** Breaks if echoes coalesce or a system user-input disable lands in the count. Reading `tapIsEnabled` converges whatever arrived.
- **Hopping transitions to main.** Main can lag a frame or more (plan 012:1267). Lost on latency.
- **Reinstalling the tap per transition.** `tapCreate` on main and filter resets. Lost on cost and memory loss.
- **A time bound on the lingering coast from event timestamps.** The gated port's non-Dock gesture events carry timestamps the filter could compare with the `ended`'s to conclude no momentum is coming; it adds a time rule to clock-free filters and needs timestamps in every scroll script. Deferred to the open question.

### Open questions and risks

1. Do real Dock swipes send `mayBegin` (field 132 == 128) before `began` (D2)? If they do, should `DockSwipeFilter.resume` take the scroll's hint and pass a `began` after a no-warning open, accepting a desktop switch in that race, or keep dropping it and leave the Dock a lone `mayBegin`?
2. Is the lingering coast acceptable (the gated port on from a swipe's lift until the next scroll gesture, at today's cost for pointing in between), or should a follow-up close it from the next gated event's timestamp once more than, say, 100 ms have passed since a dropped gesture's `ended` with no momentum begun (momentum starts about 7 ms after `ended`, P10)?
3. Is one hardware pass with Instruments points of interest enough to bound the open latency end to end (frame delivery, step, wake, `tapEnable`) before merge, since the probes bound only the last step?
4. Is the fake's exact knowledge of what it withheld an acceptable reading of R2, given that the real tap's estimate is exercised only by a unit test and a hardware check?
5. Should the stall ordering hazard be made observable (a debug counter of gated-port events decided while the press filter holds nothing for their button), or is the timeout parity argument enough?

### Next implementation step

Add `Blocking` and `Recognition.blocking` with the derived accessors and the `.possible` row, and pin its truth table in the recognizer suites, since every other piece reads from it.
