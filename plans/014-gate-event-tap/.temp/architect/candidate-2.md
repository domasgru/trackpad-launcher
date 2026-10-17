## Design

### Problem

The one session tap costs the app 0.39 ms per trackpad frame whenever fingers touch the pad, 84% of it in SkyLight's transport for scroll and gesture events (22, 29, 30) and drags and pressure (6, 7, 27, 34) that the filters can change only in a few recognizer states. A disabled tap costs what no tap costs and `tapEnable` takes effect before it returns from any thread (P1, P3, P4), so the mechanism is settled; the shape is not, because of four constraints the grounding surfaced. (1) The frame-side press rule (C7, `Touch.swift:72-82`): while a filter is live, a press the filter never saw reads as nothing, so a tap gesture or a swap could fire beside a click. Presses and releases must therefore reach the filter whenever one could complete, which is before any frame shows a thumb. (2) No warning frame precedes a blocking verdict (C5): the thumb-and-finger same-frame landing, a thumb under resting fingers, a confirmed window swipe and the first swap all raise `blocksClicks` on the frame they happen. (3) The filters' "never relaxes" memory outlives the verdict: a withheld press through its release, a dropped or stilled scroll through its momentum (about a second after the lift, P10), a dropped Dock swipe through its end (R3). (4) Two actors change the gate's inputs: frame threads change what each trackpad wants, the tap thread changes the filters' memory; the record requires one writer per shared field, a frame thread that never waits, and no timers (C14). Every `tapEnable(false)` we issue also echoes a `tapDisabledByUserInput` into the callback that today re-enables unconditionally (P6, C12).

### Usage (caller's view)

The model and `MultitouchTrackpads.run` learn nothing new. `run` still installs one `ClickTap` and removes it; the tap now owns two ports on its one thread and gates the second by itself.

```swift
// MultitouchTrackpads.run (main), unchanged in shape: one tap per run, removed before the next.
if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }   // nil: the system refused (no Accessibility)
clickTap?.remove()

// DeviceSession.receive (frame thread): one write per frame, a compare, and a wake-up on a transition only.
let recognition = recognizer.withLock { $0.step(frame) }
let wishChanged = blocking.withLock { let was = $0.wantsTap; $0 = recognition.blocking; return was != recognition.wantsTap }
if wishChanged { clickTap?.wake() }   // never enables or disables anything itself; never waits

// ClickTap.handle (tap thread), both ports: decide as today, then settle the gate on this thread.
defer { applyGate() }
let merged = mergedBlocking()   // max over the running trackpads' `Recognition.blocking`
case .scroll(let scroll): return scrollFilter.withLock { $0.decide(scroll, trackpadBlocking: merged.blocksClicks) }.apply(to: event)
```

A test reads the pure gate and the fake's gate the same way:

```swift
// Pure, LauncherCore: the one predicate, with its four reasons spelled out.
let gate = TapGate(trackpadWantsTap: recognition.wantsTap, pressWithheld: filter.holding == .withheld,
                   scrollSuppressed: scrollFilter.isSuppressing, dockSwipeDropped: dock.isDropping)
#expect(gate.isOpen)

// Behavioural, through the fake (World): ordinary scrolling never reaches the tap, R1's scenario.
world.play(TouchScript(.macBook14).land(fingers: 2).slide(byMM: (0, 40)))
#expect(world.hardware.scroll(.fingers(.changed)) == .pass)   // apps get it untouched
#expect(!world.hardware.isTapListening)                        // the gated port was never enabled
#expect(world.hardware.unseenByTap == [.scroll(.fingers(.changed))])

// Behavioural: fingers rest, a thumb lands under them, the fingers move. Stilled, never dropped (C11, R3).
let fingers = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
world.play(fingers)
#expect(world.hardware.scroll(.fingers(.mayBegin)) == .pass)   // unseen: the gate is closed
world.play(fingers.thumbTap(lift: false))                        // the thumb lands under the rest: the gate opens
#expect(world.hardware.scroll(.fingers(.began)) == .passStill)  // apps already saw its mayBegin
#expect(world.hardware.scroll(.momentum(.began)) == .passStill)

// Behavioural: a withheld press keeps the gate open for its drags and pressure after the window shuts.
world.hardware.touch(script().wait(.milliseconds(2850)).tap(fingers: 1, hold: .milliseconds(400), click: .firm).frames, on: id)
#expect(world.hardware.drag() == .passAsMove)
#expect(world.hardware.isTapListening)
```

### Shape

**Data first.** Three values carry the design.

*`Recognition.blocking: Blocking`*, one ordered level per frame per trackpad, replacing the two independent bools. The levels nest, so `blocksClicks ⇒ blocksDockSwipes ⇒ wantsTap` is a construction, not a comment (per `type-system-discipline`, `encode-lessons-in-structure`). The new bottom level, `.possible`, is the thing C5 said nobody outside the recognizer could see: a thumb anchored alone, under a rest or under an unconfirmed slide, or an unconfirmed slide whose thumb has gone. It is true on the frame before any verdict can appear, and on the same frame in the no-warning cases, which is exactly when the gated port must already be or become enabled. The existing accessors stay as derived properties, so every recognizer test keeps compiling, and the frame thread writes one `Mutex<Blocking>` instead of two bools from possibly different frames (C3).

*Filter memory queries.* Each filter already holds its in-flight state; each gains one `Bool` that says whether that state is load-bearing: `ClickFilter.holding == .withheld` (exists), `ScrollFilter.isSuppressing` (stage holds `.dropped` or `.stilled`), `DockSwipeFilter.isDropping` (`current == .drop`). A `passed`/`pass` memory is not load-bearing (C8, C9) and is what the gate may close over.

*`TapGate`*, a pure value in `LauncherCore`: the merged `wantsTap` plus the three filter queries, `isOpen` their OR. It is the single source of truth for "must the high-volume types reach the process" and has two adapters, the real tap and the fake (the deletion test: without it the OR and its reasons live twice).

**Two ports, one thread, one owner of `tapEnable`.** The tap keeps its thread and its filters and creates two ports instead of one: a *press port* over 1, 2, 3, 4, 25, 26, enabled for the port's whole life, and a *gated port* over 6, 7, 27, 34, 22, 29, 30, enabled iff `TapGate.isOpen`. The press port answers C7 by construction: a press or release never passes unseen while a tap exists, so `holding` keeps today's meaning in every state and every recorded race keeps its outcome (the press before the landing frame still passes and reads `.click`; the press right after a grant is decided on the thumb's frame flags, `.drop`; the thumb-and-finger same-frame press is decided on whatever flag the step left, as today). The window server applies the mask on its side, so the press port is never woken by ordinary use (P2). Two `tapCreate` calls in `ClickTap.swift` already pass the source policy; the rule label changes.

The tap thread is the only caller of `tapEnable` on the gated port (Q-D shape ii). It settles the gate at two moments, both on its own thread: after every event it decides (the filters' memory just changed) and when a frame thread wakes it (a trackpad's wish changed) through a version-0 run-loop source on the tap's loop. A signalled source coalesces and never blocks the signaller, so the frame thread does per frame one lock write with a compare and, on a transition, two CF calls; it never waits and never touches a port. The verdict-drops-while-a-drop-commits race cannot interleave: deciding an event and evaluating the gate are sequential on one thread, and every input change by the other actor is followed by a wake-up that re-reads the latest inputs, so the applied state converges on the last write (per `separate-before-serializing-shared-state`: per-session `Blocking` written by its frame thread, filter memory written by the tap thread, the applied state written by the tap thread, merged at the read). Plan 002's "nothing on the frame thread enables or disables the tap" and `architecture.md:18` stay true to the letter; the design adds a policy row confining `tapEnable` to `ClickTap.swift` so the rule is a test, not a checklist line.

**The echo and the system's disables.** A `GateLedger` on the tap thread holds what is applied to the gated port and how many of our own disables still owe an echo. Each `tapEnable(false)` we issue increments the debt; a `tapDisabledByUserInput` with debt outstanding is our echo (decrement, pass it, nothing else: nothing was missed, the port is already off). A `tapDisabledByTimeout`, or a user-input disable with no debt, is the system's: that port's filters forget what they alone could have missed (the press port its held presses, the gated port its scroll and Dock memory), the ledger records the port as disabled, and the gate is re-applied, which enables the gated port only if it is wanted (R4). The press port is re-enabled unconditionally, as today. The gated port starts enabled (that is what `tapCreate` gives) and the tap thread's first act before `CFRunLoopRun` is to apply the gate, which closes it: convergent startup, no main-thread writer of the ledger (per `make-operations-idempotent`).

**The filters at a reopening.** The gate closes only when nothing load-bearing is in flight, so what remains at a reopening is `passed`/`pass` memory or nothing, and events have passed unseen since. `ScrollFilter.forgetGesture()` now moves the stage to a new `.unseen` marker instead of nil: from it a `mayBegin` is a fresh start (dropped under the flag, as T71 pins), any other fingers phase under the flag is stilled because apps already saw the gesture open (C11), momentum passes and its end clears to nil. The same method serves a system disable, which is the same situation (the T67 rows are unchanged; the one that differs, a `began` under the flag after a forget, becomes stilled, which is the half-blocked case R3 forbids today). The tap calls it on the closed-to-open transition only, never mid-gesture, and it is a no-op on a suppressing stage. `DockSwipeFilter.forgetSwipe()` (nil) is called at the same moment: a stale `.pass` from an `ended` that passed unseen would otherwise let the next under-flag swipe through (C10d); keeping nil semantics for a `began` first seen after reopen drops it, the safe direction for the symptom the 29/30 fix addressed. Whether a Dock swipe sends a `mayBegin` the Dock acts on (D2) is the hardware check that decides whether the Dock filter also wants an `.unseen` marker. `ClickFilter` needs no reopen hook: the press port never closes.

**Interface depth.** The model, the port protocol and `run` are untouched. `ClickTap`'s surface grows by one internal method (`wake()`); behind it the tap hides two ports, the gate, the ledger, the wake-up source, the reopen hooks and both recovery paths. `LauncherCore` grows by `Blocking`, `wantsTap`, two filter queries and `TapGate`, each a fact the fake must share with the real tap. Nothing of CoreGraphics crosses a port.

```swift
// MARK: LauncherCore / GestureRecognizer

/// How far one trackpad's blocking reaches on this frame. The levels nest, each including the ones below it: that is how
/// `blocksClicks ⇒ blocksDockSwipes ⇒ wantsTap` holds by construction rather than by three flags kept in step.
public enum Blocking: Int, Comparable, Sendable {
    /// No thumb anchored, no slide, no series. Nothing on this trackpad can block before a frame that shows a thumb.
    case none
    /// A thumb is anchored (alone, under a rest or under an unconfirmed slide), or an unconfirmed slide is on after its
    /// thumb left: blocking can begin on any coming frame with no warning frame before it. The tap must be listening.
    case possible
    /// A thumb is anchored and another finger is down past the 3 s window: the system's Dock swipes are blocked.
    case dockSwipes
    /// Another finger down inside the window, or a confirmed swipe, a window swipe or a swap series: clicks, scrolling
    /// and Dock swipes.
    case clicks

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Recognition: Equatable, Sendable {
    public let event: Event?
    public let blocking: Blocking
    /// Derived, never stored: the three facts cannot disagree.
    public var blocksClicks: Bool { blocking == .clicks }
    public var blocksDockSwipes: Bool { blocking >= .dockSwipes }
    /// The gated port must be listening: some verdict may appear on a coming frame, or has.
    public var wantsTap: Bool { blocking >= .possible }
    public init(event: Event?, blocking: Blocking)
}

extension GestureRecognizer {
    // In `step`, replacing the two-flag tail at :182-200. Pure: the state after this frame, the contacts down, the
    // book and `frame.time`; no clock.
    // TODO (pseudocode):
    //   if confirmed swipe || series            -> .clicks
    //   else if let thumb = state.thumb:
    //       if no other contact down            -> .possible
    //       else if landing known && < 3 s      -> .clicks
    //       else                                -> .dockSwipes
    //   else if case .swiping = state           -> .possible      // unconfirmed slide, thumb gone: the answer may confirm it
    //   else                                    -> .none          // idle, or a rest with no thumb
    // Same truth table as today for the two existing flags; `.possible` is the only new row.
}

// MARK: LauncherCore / filters

extension ScrollFilter {
    /// A dropped or stilled gesture, touching or coasting, still has events to drop or still: momentum included.
    /// `passed` memory is not load-bearing and is what the gate may close over.
    public var isSuppressing: Bool { get }   // not implemented

    /// Events have passed unseen: the tap was disabled by the system, or the gate was closed and has reopened. The
    /// gesture in progress, if any, is over or was already seen by apps. From here a `mayBegin` is a fresh start,
    /// any other fingers phase under the flag is stilled (never dropped: apps saw it open), and momentum passes until
    /// its end. No-op while suppressing: a reopening never happens mid-gesture, and a forget mid-gesture must not
    /// relax it. Idempotent.
    public mutating func forgetGesture()   // stage = .unseen  (was nil)

    // private enum Stage { case touching(Treatment), coasting(Treatment), unseen }
    // decide(.fingers(phase)) from .unseen:
    //   !blocking                  -> .passed
    //   phase == .mayBegin         -> .dropped          // fresh start, as from nil
    //   otherwise                  -> .stilled          // began/changed/ended/cancelled: apps already saw it open
    // decide(.momentum) from .unseen: .pass; momentum(.ended) -> stage = nil   (as from nil)
}

extension DockSwipeFilter {
    /// The swipe in progress is being dropped: its remaining phases must still reach the filter.
    public var isDropping: Bool { get }   // current == .drop
    // forgetSwipe() unchanged (nil): now called at every reopening and on a system disable of the gated port.
}

// MARK: LauncherCore / TapGate

/// Whether the high-volume event types (drags, pressure, scrolling, the system's gesture events) must reach the tap:
/// some trackpad may block on a coming frame, or a filter still has something withheld or altered in flight. The one
/// predicate both the real tap and the test fake apply. Pure, clock-free.
public struct TapGate: Equatable, Sendable {
    /// Some running trackpad's `Recognition.wantsTap`, merged by OR (the `max` of their `Blocking`).
    public var trackpadWantsTap: Bool
    /// `ClickFilter.holding == .withheld`: the press's drags and pressure are rewritten until its release.
    public var pressWithheld: Bool
    /// `ScrollFilter.isSuppressing`: through the gesture's momentum.
    public var scrollSuppressed: Bool
    /// Any `DockSwipeFilter.isDropping`, on either event type.
    public var dockSwipeDropped: Bool

    public init(trackpadWantsTap: Bool, pressWithheld: Bool, scrollSuppressed: Bool, dockSwipeDropped: Bool)
    public var isOpen: Bool { trackpadWantsTap || pressWithheld || scrollSuppressed || dockSwipeDropped }
}

// MARK: LauncherPlatform / FrameStream

final class DeviceSession: Sendable {
    /// Writer: this device's frame callback, once per frame. Reader: the tap thread, which merges across sessions.
    private let blocking = Mutex(Blocking.none)

    /// Frame thread. Steps the recognizer, publishes this frame's `Blocking` in one write, and wakes the tap thread
    /// only when this trackpad's `wantsTap` changed. Never enables or disables a port; never waits.
    func receive(_ frame: TouchFrame) {
        // ... step as today ...
        // let wishChanged = blocking.withLock { let was = $0.wantsTap; $0 = recognition.blocking; return was != recognition.wantsTap }
        // if wishChanged { clickTap?.wake() }     // a replaced session wakes its own, removed tap: a no-op (Gotcha 9)
        // ... deliver as today ...
        fatalError("not implemented")
    }

    /// Tap thread.
    var blocking: Blocking { get }
}

/// The running trackpads' blocking, merged at the read on the tap thread: the `max` level, which is the OR of each flag
/// (`anyBlocksClicks == (max == .clicks)`, `anyBlocksDockSwipes == (max >= .dockSwipes)`, `anyWantsTap == (max >= .possible)`).
/// Copies the sessions out first, so no two locks are held at once. Replaces `anyTrackpadBlocksClicks()` and
/// `anyTrackpadBlocksDockSwipes()`: one read per event serves the verdict and the gate.
func mergedBlocking() -> Blocking   // not implemented

// MARK: LauncherPlatform / ClickTap

/// The app's event taps: two active session taps on one `userInteractive` thread. The press port, over mouse buttons and
/// their releases, listens for the whole life of the tap, so no press or release ever passes the click filter unseen
/// (the frame-side press rule depends on it) and the window server never wakes it for anything else. The gated port,
/// over drags, pressure, scrolling and the system's gesture events, is enabled by the tap thread only while `TapGate`
/// is open and disabled otherwise, so ordinary pointing and scrolling never enter the process.
/// Threads: installed and removed on main. Both callbacks run on the tap thread, which is the only caller of
/// `tapEnable` on the gated port. Frame threads only read `holding` and call `wake()`.
final class ClickTap: Sendable {
    private let filter = Mutex(ClickFilter())
    private let scrollFilter = Mutex(ScrollFilter())
    private let dockSwipeFilters = Mutex<[UInt32: DockSwipeFilter]>([:])
    /// Writer: main (install, remove). The tap thread enables and disables the gated port through it.
    private let ports = Mutex<Ports?>(nil)
    /// Set by the tap thread; main stops it on remove; frame threads wake it.
    private let runLoop = Mutex<Unchecked<CFRunLoop>?>(nil)
    /// The gate's wake-up: a version-0 source whose perform is `applyGate`. Created with the tap, added to the loop by
    /// the tap thread, signalled by frame threads. Signals coalesce; a signal before the loop runs is honoured.
    private let wakeUp: Unchecked<CFRunLoopSource>
    /// Writer and reader: the tap thread, after it started. Initial values describe what `tapCreate` left.
    private let ledger = Mutex(GateLedger())

    private struct Ports { let presses: Unchecked<CFMachPort>; let gated: Unchecked<CFMachPort> }
    enum PortRole { case presses, gated }

    /// nil when the system refuses either tap (no Accessibility); a half success is removed and reads as refusal.
    /// The gated port is created enabled and closed by the tap thread's first `applyGate()` before its loop runs.
    @MainActor static func install() -> ClickTap?   // not implemented: two tapCreate calls (pressMask, gatedMask), one thread, both sources + wakeUp in .commonModes

    /// Frame thread.
    var holding: ClickFilter.Holding { get }

    /// Frame thread. A trackpad's `wantsTap` changed: have the tap thread re-apply the gate. Coalesces, never waits,
    /// a no-op once removed. The only frame-to-tap channel besides `holding`.
    func wake()   // CFRunLoopSourceSignal(wakeUp); runLoop.withLock { $0.map { CFRunLoopWakeUp($0) } }

    /// Main. Idempotent. Disables and invalidates both ports, then stops the loop. Never relies on macOS.
    @MainActor func remove()

    /// Tap thread, both ports. Decides the event as today, then settles the gate on this thread.
    fileprivate func handle(_ role: PortRole, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // if type is a disabled notification:
        //     switch (role, ledger.withLock { $0.disabledNotice(type) }):
        //     case (.presses, _):          filter.forgetHeldPresses(); tapEnable(presses, true)          // as today
        //     case (.gated, .ownEcho):     nothing: the port is already off and nothing was missed
        //     case (.gated, .bySystem):    scrollFilter.forgetGesture(); dockSwipeFilters = [:]; applyGate()   // enables iff wanted
        //     return .passUnretained(event)
        // defer { applyGate() }                       // the filters' memory may have changed
        // guard let parsed = TapEvent(type, event) else { return .passUnretained(event) }   // non-Dock gesture events: before any lock
        // let merged = mergedBlocking()               // one read serves the verdict and the gate
        // switch parsed { ... decide with merged.blocksClicks / merged.blocksDockSwipes, apply(to:) as today ... }
        fatalError("not implemented")
    }

    /// Tap thread only, also the wake-up source's perform. Reads every input fresh, compares with what is applied, and
    /// calls `tapEnable` on the gated port only on a difference. Idempotent: run twice, the second does nothing. On a
    /// closed-to-open transition the scroll and Dock filters are told events passed unseen, before the enable.
    private func applyGate() {
        // let gate = TapGate(trackpadWantsTap: mergedBlocking().wantsTap,
        //                    pressWithheld: filter.withLock { $0.holding == .withheld },
        //                    scrollSuppressed: scrollFilter.withLock { $0.isSuppressing },
        //                    dockSwipeDropped: dockSwipeFilters.withLock { $0.values.contains(where: \.isDropping) })
        // guard let change = ledger.withLock({ $0.wish(open: gate.isOpen) }), let gated = ports.withLock({ $0?.gated }) else { return }
        // switch change {
        // case .enable:  scrollFilter.forgetGesture(); dockSwipeFilters.withLock { for key in $0.keys { $0[key]!.forgetSwipe() } }
        //                CGEvent.tapEnable(tap: gated, enable: true)
        // case .disable: CGEvent.tapEnable(tap: gated, enable: false)     // owes one echo, counted in wish(open:)
        // }
        fatalError("not implemented")
    }
}

/// What the tap thread knows about the gated port: whether it is enabled and how many of our own disables still owe
/// the echo the system sends for each (P6). Pure, so the echo-versus-timeout rule has a unit test without a port.
struct GateLedger: Equatable {
    /// `tapCreate` leaves the port enabled; the first `applyGate` converges.
    var isGatedPortEnabled = true
    var owedEchoes = 0

    enum Change { case enable, disable }
    /// The call to make, if the wish differs from what is applied. A disable adds one owed echo.
    mutating func wish(open: Bool) -> Change?   // not implemented

    enum Disabled { case ownEcho, bySystem }
    /// `tapDisabledByTimeout` is always the system's. `tapDisabledByUserInput` is our echo while one is owed (debt
    /// decremented, nothing else changes); otherwise the system's. A system disable records the port as disabled.
    mutating func disabledNotice(_ type: CGEventType) -> Disabled   // not implemented
}

extension TapEvent {
    /// The press port's vocabulary: mouse buttons and their releases. Never woken by ordinary use (the mask is applied
    /// in the window server).
    static let pressTypes: [CGEventType]   // 1, 2, 3, 4, 25, 26
    /// The gated port's vocabulary: everything that flows at frame rate while fingers touch or a button is held.
    static let gatedTypes: [CGEventType]   // 6, 7, 27, 34, 22, 29, 30
    static var pressMask: CGEventMask { get }
    static var gatedMask: CGEventMask { get }
    // `tapTypes`/`tapMask` become the union, kept so `everyMaskedTypeParses` still pins that nothing unparsed is masked.
}

// Two C callbacks, one per role, both with `userInfo` = the ClickTap, each forwarding to `handle(role, type, event)`.
private let pressTapCallback: CGEventTapCallBack
private let gatedTapCallback: CGEventTapCallBack
// The wake-up source's perform: `Unmanaged<ClickTap>.fromOpaque(info).takeUnretainedValue().applyGate()`.

// MARK: Tests / InMemoryTrackpads (the behavioural seam)

@MainActor final class InMemoryTrackpads: TrackpadHardware {
    /// The fake tap, armed iff the last `run` asked with trackpads (as today). Presses and releases always reach the
    /// click filter while armed, as the real press port never closes. Drags, pressure, scrolls and Dock swipes reach
    /// their filters only while the modelled gate is open; otherwise they reach apps untouched and are recorded in
    /// `unseenByTap`, so a test tells "never delivered" from "passed".
    private var clickFilter: ClickFilter?
    private var scrollFilter: ScrollFilter?
    private var dockSwipeFilter: DockSwipeFilter?      // one stream in the fake; the real tap keys two by event type
    /// Each running trackpad's latest `Recognition.blocking`.
    private var blocking: [TrackpadID: Blocking] = [:]
    /// The gate as the frames and events so far left it. The one-sided model: an event between frames sees the gate
    /// the previous frame settled, exactly as it sees the flags.
    private(set) var isTapListening = false
    enum GatedEvent: Equatable { case drag(button: Int), pressure, scroll(ScrollEvent), dockSwipe(DockSwipePhase) }
    private(set) var unseenByTap: [GatedEvent] = []
    /// Closed-to-open transitions so far: a test pins that ordinary use makes none.
    private(set) var gateOpenings = 0

    func scroll(_ event: ScrollEvent) -> ScrollVerdict?          // nil: no tap. .pass when closed (recorded unseen), else the filter's verdict
    func dockSwipe(_ phase: DockSwipePhase) -> DockSwipeVerdict? // same convention
    func drag(button: Int = 0) -> PointerVerdict?                // same convention
    func pressure() -> PointerVerdict?                           // same convention

    /// After every frame step and every delivered event: `TapGate(...)` over the fake's inputs; on closed-to-open,
    /// `scrollFilter.forgetGesture()` and `dockSwipeFilter.forgetSwipe()`, as the real `applyGate` does.
    private func settleGate()   // not implemented
}
```

**Validation and trust.** `CGEvent` fields are parsed into `TapEvent` at the port, as today; the ledger consumes a `CGEventType` only to classify the two notification kinds. Inside, `Blocking`, the filter queries and `TapGate` are plain values with no checks (per `boundary-discipline`). The frame thread per frame: one lock write with a compare. A transition: two CF calls on the frame thread; on the tap thread N session reads, three filter reads, one `tapEnable` of about 0.1 ms (P3), then one echo callback per disable. Per event while open: today's work plus the gate's reads. Lifecycle: `run` replaces the tap as today (both ports removed before the next install, Preserve 8); a fresh tap starts closed and opens on the first frame that shows a thumb, which covers the first-frame cases (a thumb already down publishes `.possible` or `.dockSwipes` on the first step; the press right after a grant lands on the thumb's frame). Revoke, hot-plug, wake, hand-mode and setting changes all go through `run`; sleep latches the last `Blocking` as it latches the flags today, which keeps the gated port on at the shipped cost until the wake's `run`, never off while something is in flight.

**What the suite pins.** Pure: `Blocking`'s truth table per recognizer state including `.possible` on a thumb alone, on an unconfirmed slide after its thumb lifts, and `.none` on the `[]` frame (the invariant is by construction; one test pins the order); `TapGate.isOpen` rows; `ScrollFilter.isSuppressing` and the `.unseen` rows (`mayBegin` under the flag → `.drop`, `began` under the flag → `.passStill`, momentum → `.pass` then `began` under the flag → `.drop`); `DockSwipeFilter.isDropping`; `GateLedger` (own echo versus timeout, the debt, the initial converge). Platform: `TapEventTests` pins both masks, their disjointness, their union equal to today's 13 bits, and that every listed type parses; `DeviceSessionAnswerTests` reads `session.blocking`. Behavioural, through the fake: every existing test unchanged (an undelivered high-volume event reads `.pass`, which is the value those tests already see, and `pressVerdicts` is untouched); new rows for R1 (no opening, every scroll `.pass`, all unseen), R3 (open through a withheld press's drags and release, a dropped scroll's momentum, a dropped Dock swipe's end), C11 (stilled, not dropped), the fresh `mayBegin` after a reopen (dropped), and the lifecycle paths through `Launcher.reconcile`. Manual: the Release CPU per frame against 0.088 ms by the audit's method; real scroll, momentum and Dock swipe delivery with the gate; the debugger-pause recovery on each port; ten toggles giving ten echoes and no re-enable in the real app; D2.

**Docs (R5).** Replace the clause in `docs/architecture.md` Concurrency, "The one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives (a press, its drags and pressure, a scroll event, or a system gesture event)", with: "The one extra thread is the click tap's run loop, which exists only while click blocking is armed and holds two event taps. One, over presses and their releases, listens for the tap's whole life and is woken by nothing else. The other, over drags, pressure, scrolling and the system's gesture events, is enabled by the tap thread only while some trackpad's recognizer may block (a thumb anchored, a slide or a swap series on) or a filter still holds a press, a scroll gesture or a Dock swipe it is withholding or altering, and disabled otherwise, so ordinary pointing and scrolling never enter the process. A frame thread whose trackpad changes its mind wakes the tap thread's run loop; no frame thread enables or disables a tap." Line 18's one-writer rule and "never waits" stay as they are. The Privacy paragraph's "the event tap ... confined to one file" becomes "the event taps". `SourcePolicyTests`: relabel "R9 the one event tap" to "the event taps live in one file" and add `tapEnable` confined to `ClickTap.swift`. `docs/domain-model.md` is unchanged: no verdict changes.

### Synthesis decision

### Tradeoffs accepted

- We accept a second `tapCreate` and CFMachPort in exchange for presses and releases never passing the filter unseen, which keeps the frame-side press rule and every recorded race exactly as shipped with no new state on the frame path.
- We accept about a quarter of a millisecond between a trackpad's wish changing and the gated port being enabled (a wake-up plus `tapEnable`), rather than the frame thread calling `tapEnable` itself, in exchange for one owner of the port's enabled state, a frame thread that never makes a WindowServer call, and no bend of plan 002's rule. Events in that window pass unseen and the `.unseen` rule turns the consequence into "stilled instead of dropped", the symptom plan 006 already accepted for the `mayBegin` race.
- We accept that a dropped or stilled scroll that ends without momentum keeps the gated port on until the next scroll gesture's first event (the filter's coasting memory cannot know no momentum is coming without a clock), so pointer use after a slow-ending swipe costs the shipped amount until the user next scrolls. R1's predicate is the filter's own memory, so this is inside the requirement.
- We accept that a dropped Dock swipe whose `mayBegin` passed unseen is dropped from its `began` (the Dock got a `mayBegin` and nothing else) rather than passed, pending D2.
- We accept an echo debt counter rather than ignoring `tapDisabledByUserInput` outright, so a genuine user-input disable still forgets and recovers; a missing or extra echo degrades to one unneeded forget, never to a tap stuck on or off.
- We accept the per-event `Array` in `mergedBlocking()` (unchanged from today) rather than a lock-free merge; it runs only while the gate is open and is outside the plan's non-goals.

### Alternatives considered

- **One tap, gated by `.possible` (a thumb anchored) with presses in the gated mask.** Saves the second port. Loses: a press that begins between a thumb's physical landing and its frame step and is held into a finger landing passes unseen, reads as nothing, and lets a tap gesture fire beside a click (C7); closing that needs the tap to seed a `passed` entry from the button state at every reopening, a press the filter never saw, or the frame path to read a gated-off tap as "no filter", a third meaning for `holding`. Exposes a timing hazard to the recognizer to hide one `tapCreate`.
- **The frame thread applies `tapEnable` under one mutex holding wants, filter memory and the applied state (Q-D i).** About 0.1 ms faster to open. Loses: three writers of the port's enabled state, a WindowServer call on the frame thread under a lock the tap thread takes per event (P3 saw a 2.5 ms outlier), and it breaks `architecture.md:18` and plan 002's rule rather than confining them.
- **Toggle from the main actor on recognised events** (plan 002 candidate-2's rejected refinement). A main hop can lag past a frame (012:1267) and the no-warning cases have no event to hop on.
- **Reinstall the tap per transition** instead of `tapEnable`. A thread per install and `tapCreate` from a non-main thread; P3 makes it pointless.
- **Reset the scroll filter to nil at reopening** instead of `.unseen`. Drops a `began` whose `mayBegin` apps already got (C11), half-blocking it, which R3 forbids. **Treat `began` as mid-way everywhere** instead: a device that sends no `mayBegin` would never have a gesture dropped, and T64's `began`-under-the-flag row is pinned `.drop`.

### Open questions and risks

- Does a real Dock swipe send a `mayBegin` (field 132 == 128) before `began`, and does the Dock react to a lone `mayBegin` (D2)? If yes, should the Dock filter take the same `.unseen` marker (pass a `began` first seen after reopening) rather than drop it?
- Is the lingering coast after a slow-ending swipe worth a frame-side rule ("a landing after the lift with no momentum begun ends the coast"), given its bounce race (a re-landing within the ~7 ms before momentum begins would let that momentum pass)? Or is "until the next scroll" acceptable?
- Does each `tapEnable(false)` echo exactly once when two taps share the process (P6 probed one)? The ledger tolerates a miscount, but the manual ten-toggle check should be run on the real app.
- Should `tapEnable` be confined to `ClickTap.swift` by the policy test, making plan 002's checklist line a failing build? The design assumes yes.
- `Recognition.init` changes to `init(event:blocking:)`; only `step` constructs it, but is the two-flag init worth keeping for a transition?
- The open latency (frame delivery, step, wake-up, `tapEnable`) is bounded by P3 and P4 but not measured end to end; is one hardware pass with the Instruments points-of-interest enough before merge?

### Next implementation step

Add `Blocking` and `Recognition.blocking` with the derived accessors and the `.possible` row, and pin its truth table in the recognizer suites, since every other piece reads from it.
