# Plan: Gate the event tap so ordinary trackpad use costs almost nothing

## Problem statement

A performance audit of the Release build (`-O`, whole-module optimisation, hardened runtime, origin/main `9557bc2`, MacBook Pro on macOS 26.6) found that the app is free while idle but costs 2.2–2.7% of one CPU core for the whole time any finger touches the trackpad, even with no launcher gesture: plain pointer moves and scrolling.

| Measured (proc_pid_rusage, per trackpad frame while touching) | CPU per frame | Share of one core |
|---|---|---|
| Shipped build, ordinary pointer + scroll | 0.39 ms | 2.34% |
| Same build with the click tap never installed | 0.058 ms | 0.27% |
| A bare MultitouchSupport client with a no-op callback | 0.020 ms | – |
| Idle, nothing touching (shipped) | 0.77 ms per 60 s, 0 idle wakeups | 0.001% |

Root cause, from Instruments Time Profiler over 30 s of ordinary pointer + scroll use: 84% of the app's CPU is on the `ClickTap` thread inside SkyLight's event-tap machinery (decoding each event sent to the tap and re-posting it: `eventTapMessageHandler` → `processEventTapData` → `SLEventCreateFromDataAndSource`, `CGSEncodeEventRecord`, `_CGSPostFilteredEventTapData`, `mach_msg`). `ClickTap.handle` itself is about 1%, `GestureRecognizer.step` about 2.4%.

The tap (`LauncherPlatform/ClickTap.swift`) is an active session tap at the head of the session, installed for as long as gestures are active and Accessibility is granted. Since plan 002 it has grown from presses, drags and pressure to also scroll (plan 006) and the system's gesture and Dock control events, types 29 and 30 (plan 006's Dock swipe fix). Scroll and gesture events flow at frame rate whenever fingers are on the trackpad, so every one of them makes a synchronous round trip through this process before any app sees it. Besides the CPU, that puts the app in the latency path of every scroll, drag and system swipe on the Mac, all the time.

Yet blocking can only ever be needed in a few recognizer states (`GestureRecognizer.step`'s `blocksClicks` / `blocksDockSwipes`): a thumb anchored in the corner, a swipe or window swipe in progress, or a swap series. The corner is a small zone in the top corner on the thumb side that ordinary pointing and scrolling almost never touches. Outside those states, and once nothing a filter has withheld is still in flight, the tap does work that can change nothing.

Plan 002 deliberately chose not to enable or disable the tap from the frame thread (plan 002, around lines 437 and 1319). That was decided when the tap saw only presses, drags and pressure, which are rare and cheap; it never weighed today's event volume. `docs/architecture.md` still says the tap "sleeps until an event arrives", which is no longer true while fingers are on the trackpad.

## Requirements

### R1. Ordinary trackpad use does not route high-volume events through the app
While no trackpad's recognizer is in a state that may need blocking (no thumb anchored, no swipe or window swipe in progress, no swap series) and no filter has a press, scroll gesture (including its momentum) or Dock swipe still withheld or altered in flight, the app MUST NOT be sent scroll, drag, pressure or system gesture/Dock control events (types 6, 7, 27, 34, 22, 29, 30). Its CPU during ordinary pointer and scroll use MUST be within 0.03 ms per frame of the measured no-tap build (0.058 ms per frame), measured with the same method on a Release build.

#### Scenario: Scrolling a web page with two fingers
- GIVEN gestures are active, Accessibility is granted, and click blocking is armed
- WHEN the user moves the pointer and scrolls a web page for 40 s without ever touching the anchor corner
- THEN the app receives none of those scroll or gesture events, and its CPU per trackpad frame is at most 0.088 ms

### R2. What is blocked and what passes does not change
Every press, drag, pressure event, scroll event and Dock swipe that the shipped build blocks, stills or rewrites MUST still be blocked, stilled or rewritten the same way, and everything it passes MUST still pass, including the races the existing plans accepted (a thumb and a finger landing on the same frame, a thumb landing under resting fingers). Every existing behavioural test MUST keep passing, and the behavioural suite MUST also hold with the tap's gating modelled.

### R3. Nothing reaches apps half-blocked
The gating MUST NOT deliver to apps the start of a press, scroll gesture or Dock swipe and then withhold its end, nor withhold its start and then deliver the rest. Once the shipped build would withhold part of one, the rest MUST stay withheld until it ends, as plan 006's "never relaxes" rule requires, even if the recognizer has returned to a state that needs no blocking.

### R4. Tap timeouts and permission changes behave as today
A tap disabled by the system (timeout or user input) MUST recover as it does today, without turning on a tap the gating wants off. Revoking Accessibility, a hot-plug, wake, a hand-mode or setting change MUST leave no tap enabled or event withheld that the shipped build would not have.

### R5. Architecture notes match the code
`docs/architecture.md` MUST describe when the tap receives events after this change, replacing the claim that it sleeps until an event arrives.

## Non-goals

- Fewer redraws in `SwitcherPanel.show` during app switcher swipes: it saves a few milliseconds per swipe and would likely change the icon-grow animation that plan 013 keeps unchanged.
- Freeing the menu window's SwiftUI content when it closes (about 15 MB): plan 003 keeps pickers instant on every open, and the saving is uncertain.
- Per-frame allocations in the recognizer and the frame parser: about 2–5% of the remaining cost, not worth the churn.
- Startup cost (about 1 s of CPU in the first second after launch), paid once per login.

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
if flipped { tap?.wake() }   // the session's `TapLink`: the real `ClickTap`, or a stub that counts wakes
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

// R3: a swipe's scroll, dropped under the thumb, keeps reaching the tap after everything lifts, until its momentum ends.
let flick = World.switcherWorld(accessGranted: true)
let swipe = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2).slide(byMM: (10, 0))
flick.play(swipe)
#expect(flick.hardware.offer(.scroll(.fingers(.began))) == .decided(.scroll(.drop)))
flick.play(swipe.lift().liftThumb())
#expect(flick.hardware.isGatedPortOn)                                        // the dropped gesture holds it open
#expect(flick.hardware.offer(.scroll(.fingers(.ended))) == .decided(.scroll(.drop)))
#expect(flick.hardware.offer(.scroll(.momentum(.began))) == .decided(.scroll(.drop)))
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

**Notices (P6, R4).** `recover()` treats a disabled notice as a prompt to reconcile, not a command, and counts nothing: it reads `tapIsEnabled` on both ports (20-47 µs each, on a notice only) and hands both to `portsWereDisabled`. The press port reading off is the system's doing: held presses are forgotten and the port re-enabled, as today. The gated port reading off while `gateIsOpen` is true is the system's doing: the scroll and Dock filters forget (the stage goes to nil, today's reset) and the gate settles, reopening only if a trackpad wants it now. Otherwise the notice is the echo of our own close (the port reads off after it, or on if we reopened before the echo arrived): nothing is forgotten, nothing switched beyond what the level asks. A lost or coalesced echo cannot strand the state, because each notice re-reads the truth (per `make-operations-idempotent`). Forgetting is per port, a refinement of today's forget-all that two ports make the honest reading of R4's "as today": each port forgets only what it could have missed, so a timeout on the gated port never releases a withheld press's mouse-up that the press port never missed.

**Reopening (Q-E).** The gate closes only on non-load-bearing memory (scroll nil, `.unseen`, `.coasting(.passed)` or `.touching(.passed)`; Dock nil or `.pass`), so the open overwrites exactly the stale state of C10(b) and C10(d) and never touches a gesture in flight. The scroll filter's `resume(scrollMayBeUnderWay:)` sets the stage to `.unseen` when a scroll may be under way, else nil. From `.unseen`, a `mayBegin` is a fresh start (dropped under the flag, as every thumb-first test pins), `began` and the mid phases are first seen mid-way (stilled under the flag: apps already got the `mayBegin`, P10), momentum passes and its end clears to nil. The real tap cannot see what it was not sent, so `TapContext.estimated(from:)` takes "fingers are down beside the thumb", `blocking >= .dockSwipes`, as "a scroll may be under way": the no-warning entries exactly. A `.possible` opening (a thumb alone) resumes to nil. So fingers resting, then the thumb, then a move is stilled (C11, today's hardware outcome); on the same-frame landing either the open beats the system's `mayBegin` (dropped) or the `mayBegin` beats it (stilled), today's two outcomes. The fake builds its context from what it actually withheld, so a script that never offered a `mayBegin` (`SwapTests:324`) still drops. The Dock filter's `resume()` keeps a `.drop` and forgets a `.pass`; a `began` first seen after an open drops under the flag, the block-biased behaviour of the 29/30 fix, pending D2.

**Lifecycle (R4).** `run` replaces both ports and the `TapFilters`, as today. `install` creates both ports, disables the gated one at once on main (main is the ports' writer at install and remove), starts the thread, which adds the three sources, publishes its loop, runs `follow()` (opening the gate if a frame already wants it) and then its loop: a fresh value is closed and converges from there, and nothing queues before the thread runs. A thumb already down alone on the first frame gives `.possible` (an open with warning); a thumb with a finger gives `.dockSwipes` or `.clicks`: scrolling passes or stills as today, the Dock drops from nil. Revoke, hot-plug, wake and setting changes all go through `run`; after a revoke no tap exists; sleep latches the level and may leave the gated port on, which is free while no events flow, until the wake's `run`. `follow` twice returns nil the second time; `remove` twice is a no-op; a wake or an echo after `remove` finds no ports; a stale session after `run` only wakes its own removed tap.

**Testing seams (R2, Q-G).** Unit: `TapFilters` with scripted `(TapContext, TapEvent)` sequences and the changes they return; `Blocking` pinned per recognizer state, including `.possible` on the thumb frame before every first verdict in thumb-first scripts; the `.unseen` rows; `TapContext.estimated(from:)`. Behavioural: the fake wraps a real `TapFilters` and models the window server's side: press-port events are always delivered while armed; gated-port events are delivered only while `isGatedPortOn`; `offer(_:) -> Delivery` tells `.notSent` from `.decided(.pass)`; `scroll(_:)` keeps its apps'-view meaning (not sent counts as `.pass`); `pressVerdicts` is unchanged; `withLateWakes { }` holds the wakes and the notices so a test can show events passing in the open latency; `systemDisables(_:)` turns one or both ports off and queues their notice; each close queues its echo; `usesEstimatedContext` makes the fake build its context as the real tap does, for the rows that pin the divergence between the two. Nothing waits on a clock: the 3 s window runs on scripted `FrameTime`. Platform: `TapEventTests` pins the press mask `[1, 2, 3, 4, 25, 26]` and the gated mask `[6, 7, 22, 27, 29, 30, 34]`, disjoint, union today's 13 bits, every type parsing, `ridesGatedPort` agreeing with the mask each type sits in, 29 and 30 mapping to their streams; the `DeviceSession` tests read the level per frame and, through a stub `TapLink`, count one wake per `wantsTap` flip and none otherwise. Manual: the Release-build CPU per frame (proc_pid_rusage) against 0.088 ms over 40 s of pointing and scrolling; hardware checks for C11 stilling, a dropped flick's momentum, a thumb-plus-two-finger Dock swipe blocked, D2, and the debugger-pause recovery with the gate open and closed.

**Docs (R5).** Replace the last sentence of `docs/architecture.md`'s Concurrency section (line 20) with: "The one extra thread is the click tap's run loop, which exists only while click blocking is armed and serves two event taps. One, over presses and their releases, is on for as long as it exists, and only a click wakes it. The other, over drags, pressure, scrolling and the system's gesture events, is turned on by that thread only while some trackpad has a thumb in the anchor corner or a swipe, window swipe or swap series on, or while a press, a scroll gesture with its momentum or a Dock swipe is still withheld or altered, and turned off once none is, so ordinary pointing, dragging and scrolling never reach the app. A trackpad's frame thread only wakes that thread when what it needs flips." In line 25 "the event tap" becomes "the event taps". `SourcePolicyTests`: the "R9 the one event tap" label becomes "the click tap's event taps, one file", and `tapEnable` joins the tokens confined to `ClickTap.swift`. `docs/domain-model.md` describes behaviour that does not change.

**Depth.** The model, the port and `run` learn nothing. `DeviceSession` publishes one value instead of two flags and reaches the tap through `TapLink`, two members (`holding`, `wake()`) that `ClickTap` satisfies and a test stub counts. `ClickTap` shrinks to parsing `CGEvent`s, reading the merged level, calling one of three entry points, rewriting the event and switching one port; it no longer knows which filter takes which event, what each reads, what to forget, or when the gated port may come back on. `TapFilters` exposes three mutations, one per trigger (event, wake, notice), and two reads; behind them sit the routing, the gate predicate, the reopen rules and the echo-versus-system logic, and the fake wraps the same value, so none of those rules exists twice.

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` · `Recognition` / `GestureRecognizer` | `Blocking` replaces the two Bools (derived accessors kept); `step` computes one level |
| `LauncherCore` · tap vocabulary | `TapEvent` moves here, CG-free (a Dock swipe carries its stream); `TapVerdict`, `GateChange`, `TapDecision`, `TapContext` |
| `LauncherCore` · `TapFilters` | new: the three filters plus the gate |
| `LauncherCore` · `ClickFilter`, `ScrollFilter`, `DockSwipeFilter` | in-flight queries; `.unseen` and `resume` on the scroll filter, `resume` on the Dock filter |
| `LauncherPlatform` · `ClickTap` | two ports, one thread, the wake-up source; `wake()`, `follow()`, `recover()`, `apply(_:)`; parsing and rewrites as today |
| `LauncherPlatform` · frame stream (`DeviceSession`) | `Mutex<Blocking>`, a wake on a `wantsTap` flip through `TapLink` (two members, satisfied by `ClickTap` and by a test stub); `mergedBlocking()` |
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

/// What a session needs from the click tap: the press summary and a wake-up. `ClickTap` satisfies it; the
/// `DeviceSession` tests pass a stub that counts wakes per frame (one per `wantsTap` flip, none otherwise).
protocol TapLink: Sendable {
    var holding: ClickFilter.Holding { get }
    func wake()
}
extension ClickTap: TapLink {}

// DeviceSession: `init(trackpad:recognizer:pointerCurves:tap: (any TapLink)?, deliver:)`;
//   `private let blocking = Mutex(Blocking.none)`. Writer: its frame thread. Reader: the tap thread.
//   `var blocking: Blocking`; `var blocksClicks: Bool { blocking.blocksClicks }` kept for the DeviceSession tests.
//   `receive`: one write with a compare; `tap?.wake()` only when this trackpad's `wantsTap` flipped.
/// Tap thread: the highest level of any running trackpad. Copies the sessions out first: never two locks at once.
func mergedBlocking() -> Blocking { fatalError("not implemented") }

// MARK: Tests, InMemoryTrackpads (additions)

extension InMemoryTrackpads {
    enum Delivery: Equatable { case noTap, notSent, decided(TapVerdict) }
    // private var tap: TapFilters?; private(set) var isGatedPortOn; private var isPressPortOn
    // private var levels: [TrackpadID: Blocking]
    // private var scrollUnderWayUnseen: Bool   // set by an unsent mayBegin/began/changed, cleared by an unsent ended/cancelled
    // run: fresh TapFilters (closed), press port on, then one tap-thread turn: follow(context()), where context() is
    //      TapContext(blocking: max, scrollMayBeUnderWay: truth), or TapContext.estimated(from: max) under `usesEstimatedContext`.
    // touch: after each step, a flipped wantsTap queues a turn. Each .close queues its echo turn (portsWereDisabled).
    //        Turns run at once unless inside `withLateWakes`. The press edge is decided on the previous frame's level, as today.
    /// An event as the window server would hand it: `.notSent` while its port is off.
    func offer(_ event: TapEvent) -> Delivery { fatalError("not implemented") }
    /// Wakes and notices queue while `body` runs, then run in order: the open latency, made visible.
    func withLateWakes(_ body: () -> Void) { fatalError("not implemented") }
    enum Port: Hashable { case presses, gated }
    /// The system's disable of one or both ports: each goes off and its notice is queued.
    func systemDisables(_ ports: Set<Port> = [.presses, .gated]) { fatalError("not implemented") }
    /// false (the default): the context is exact, built from what the fake withheld. true: built as the real tap builds
    /// it, `TapContext.estimated(from:)`, so one row can show the divergence (a bare `began` under a thumb that landed
    /// on resting fingers reads `.passStill`, as on hardware) without touching the existing tests.
    var usesEstimatedContext = false
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
- We accept forgetting per port on a system disable, where today's one tap forgets all three filters, in exchange for a gated-port timeout never releasing a withheld press's mouse-up that the press port saw; R4's "as today" is read per disabled port, and the human may prefer to say so in R4's wording.
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

## Testing Decisions

### Strategy

Four seams, three of them existing, in the order the rows prefer them.

- **World** (`LauncherKit/Tests/LauncherCoreTests/World.swift` over `InMemoryTrackpads` in `InMemoryAdapters.swift`): the real `Launcher`, recognizer, three filters and, new, the real `TapFilters`, driven by scripted frames on the `FrameTime` clock (10 ms frames; `wait(.seconds(4))` crosses the 3 s window). It observes what the user and the window server would: `isGatedPortOn` after any frame or event; `offer(_:) -> Delivery`, whose `.noTap`, `.notSent` and `.decided(verdict)` are the one handle that tells "never delivered" from "passed"; `scroll(_:)` and `pressVerdicts` with today's meaning (`.notSent` reads `.pass`, `.noTap` nil; `offer` never appends to `pressVerdicts`, the frames' presses do); `isBlockingClicks`, `runCount`, pulses, what fired. The fake models the window server's side as the design states it: press-port events are delivered while a tap exists; gated-port events only while `isGatedPortOn`; each `wantsTap` flip queues a tap-thread turn (`follow`), each close queues its echo notice (`portsWereDisabled` with the ports as they then read); `systemDisables(_:)` turns one or both ports off and queues their notice; `withLateWakes { }` holds every queued turn until the block ends, which is what makes the open latency and a late echo visible. Its `TapContext` is exact by default (what it withheld); `usesEstimatedContext` builds it as the real tap does, for the rows that pin the divergence between the two (T24). Rows resemble `ScrollSuppressionTests.swift`, `ClickBlockingTests.swift`, `WindowSwipeBlockingTests.swift` and the per-frame probes of `WindowSwitcherOnScreenTests.swift`. It misses the real ports, the thread, the run-loop source, real notices, the open latency (D5) and cross-port order under a stall.
- **Pure values in `LauncherCore`**: `TapFilters` (new seam, the one the design names; the fake wraps the same value, so a rule proven here is the rule World runs), `ScrollFilter` and `DockSwipeFilter` (`ScrollFilterTests.swift`, `DockSwipeFilterTests.swift`), `TapContext`. Scripted `(TapContext, TapEvent)` sequences and the `TapDecision` or `GateChange?` each returns, plus `gateIsOpen` and `holding`. This is the only seam where the interleavings the fake's synchronous turns cannot produce are forced one call at a time: a level lowered before or after an event's read, a straggler after a close (P5), a notice for one port only, an echo arriving after a reopen.
- **The recognizer over scripted frames** (`ClickBlockingRecognizerTests.swift`, `DockSwipeBlockingRecognizerTests.swift`, `SwapRecognizerTests.swift`, `WindowSwipeRecognizerTests.swift`, the drivers in `Fixtures.swift`): the `Blocking` level per frame and the warning frame before every verdict.
- **`LauncherPlatformTests` and the source scan**: `TapEventTests.swift` for the two masks and the parse tables over synthetic `CGEvent`s; `DeviceSessionAnswerTests.swift` for the level a session publishes per frame and, through a stub `TapLink` that counts wakes, the one wake per `wantsTap` flip and none otherwise; `SourcePolicyTests.swift` for the confinements.

Faked: the window server's two ports and their notices, the tap thread (the fake's turns, run in order), the clock. Real: everything in `LauncherCore` and the model. Not reachable by a test, each under Verified without a test: `ClickTap.install`, `handle`, `follow`, `recover`, `apply`, `remove` and the wake-up source (they need Accessibility trust and real devices); the Release-build CPU per frame; the real open latency; the real tap's estimate on the device (T17 pins the function, T24 its outcomes through the fake, M2 (3) the hardware).

Before and after: no new row compiles today (`Blocking`, `TapFilters`, `offer`, `isGatedPortOn` do not exist). Today's press-race rows (`aPressReachingTheTapBeforeTheLandingFrameIsAClickThatCancelsTheTap`, `aTapRightAfterAccessIsGrantedBlocksItsPressWithNoFrameBeforeTheThumb`, `aThumbLandingDuringADragLeavesTheDragAlone`) and every `scroll(_:)` assertion in the suite hold today and must hold after: they are R2's guard, and `SwapTests:324` is the one whose `.drop` rests on the fake knowing what it withheld (T5 pins the contrast). One existing platform row changes its assertion, not a behavioural one: `TapEventTests.maskCoversPressesTheirReleasesDragsPressureScrollAndGesturesOnly` becomes T20's two masks whose union is today's 13 bits, and `parsesADockSwipeOnEitherGestureTypeWithItsPhase` gains the stream.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | World, frame by frame | Given `World.switcherWorld(accessGranted: true)`. When two fingers land at (62, 45) and slide 400 mm down over 40 s (`TouchScript(.macBook14).land(fingers: 2).slide(byMM: (0, 400), over: .seconds(40))`, 4000 frames), observing `isGatedPortOn` after every frame; then one event of each gated kind is offered: `.scroll(.fingers(.changed))`, `.pointer(.drag(button: 0))`, `.pointer(.pressure)`, `.dockSwipe(.changed, .gesture)`, `.dockSwipe(.changed, .dockControl)`; then a press-port event, `.pointer(.release(PressID(button: 2, number: 7)))`. Then every one of the 4000 observations is false; each gated offer is `.notSent`; the release is `.decided(.pointer(.pass))`; `scroll(.fingers(.changed)) == .pass` (the apps' view, as today); `isBlockingClicks` is true. | R1's set (6, 7, 27, 34, 22, 29, 30) and its scenario's 40 s with no corner touch; R1 "MUST NOT be sent"; P2 (a tap masked to presses is not woken by scrolling but delivers a press); the `Delivery` cases. |
| T2 | R1 | World, frame by frame | Given the same world. When one finger lands away from the corner, presses from the frame after landing (`.firm`) and drags 30 mm while pressed, then lifts. Then `isGatedPortOn` is false after every frame; mid-drag `offer(.pointer(.drag(button: 0))) == .notSent` and `offer(.pointer(.pressure)) == .notSent`; `pressVerdicts == [.pass, .pass]`; nothing fires. | R1 (drags and pressure of a passed press are never routed); C6 (drags of a passed press change no state); plan 002:1134. |
| T3 | R1, R2 | World, frame by frame and `withLateWakes` | Given the same world. When a thumb lands alone at (10, 10) and rests 200 ms, frame by frame. Then `isGatedPortOn` is true from the thumb's frame on, while `scroll(.unphased) == .pass` and `offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.pass))` (open, blocking nothing); after the thumb lifts, `isGatedPortOn` is false. In a second world the thumb lands (its wake runs), then inside `withLateWakes { }` two fingers land beside it and `.scroll(.fingers(.mayBegin))` is offered: `.decided(.scroll(.drop))`, because the port opened on the thumb's frame, with the fingers' own wake still pending; after the block `isGatedPortOn` is still true. | The design's `.possible` ("up at least one frame before a verdict can appear"); C5; `ClickBlockingRecognizerTests.aThumbAloneOrNoThumbNeverBlocks` and `DockSwipeBlockingRecognizerTests` (a thumb alone blocks nothing); `ScrollSuppressionTests.aSwipeFromAFreshThumbDropsScrolling…` (`mayBegin` dropped). A gate on the flags alone leaves the second world's offer `.notSent`. |
| T4 | R2 | World, `withLateWakes` (hand frames) | Given the same world. When the thumb and a finger land on one frame (`h.frame(atMS: 0, [thumb .landing, finger .landing])`), inside `withLateWakes { }`, and `.scroll(.fingers(.mayBegin))` is offered inside the block; then the block ends and `.scroll(.fingers(.began))` is asked. Then inside the block `isGatedPortOn` is false and the offer is `.notSent`; after it `isGatedPortOn` is true and `scroll(.fingers(.began)) == .passStill`. In a second world with no late wakes the same frame gives `offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop))` and `scroll(.fingers(.began)) == .drop`. | The design's two outcomes of the no-warning entry ("either the open beats the system's `mayBegin` (dropped) or the `mayBegin` beats it (stilled)"); C10(a), C11; plan 006:1374 (a `mayBegin` before the flag is stilled, never dropped); `GestureRecognizer.swift:92-94` (`.spoiled` on that frame). |
| T5 | R2, R3 | World | (a) Given two fingers resting 150 ms with no thumb. When `.scroll(.fingers(.mayBegin))` is offered, then the thumb lands under them, waits 50 ms and the fingers slide 10 mm. Then the offer is `.notSent`, and `scroll(.fingers(.began)) == .passStill`, `scroll(.fingers(.changed)) == .passStill`. (b) The same hand as `SwapTests.fromTheFirstSwapUntilTheFingersLiftClicksAndScrollsAreBlocked` (rest 150 ms, thumb tap, slide 10 mm) with a `.scroll(.fingers(.mayBegin))` offered while the fingers rest: `scroll(.fingers(.began)) == .passStill`; and that existing test, which offers no `mayBegin`, still reads `.drop`. | C11 and plan 006:1331 (a thumb under scrolling fingers stills the rest); the design's reopen rule (`.unseen` iff a scroll may be under way; the fake knows what it withheld); checks README "SwapTests:324". A reset to nil at the open reads `.drop` in (a). |
| T6 | R3 | World, frame by frame | (a) Given a fresh thumb and two fingers sliding 10 mm right (a swipe). When `.scroll(.fingers(.began))` is offered, then the fingers and the thumb lift frame by frame, then `.fingers(.ended)`, `.momentum(.began)`, `.momentum(.changed)`, `.momentum(.ended)` are offered in turn, then `.fingers(.mayBegin)`. Then the first offer is `.decided(.scroll(.drop))`; `isGatedPortOn` is true after every lift frame and after each of the first three later offers, which are all `.decided(.scroll(.drop))`; `.momentum(.ended)` is `.decided(.scroll(.drop))` and `isGatedPortOn` is false after it; the final `mayBegin` is `.notSent`. (b) Given the thumb rested 4 s, two fingers slide 2 mm (`scroll(.fingers(.began)) == .pass`) then 10 mm more (the switcher shows, `scroll(.fingers(.changed)) == .passStill`), then everything lifts frame by frame. Then `isGatedPortOn` is true on every lift frame; `.fingers(.ended)`, `.momentum(.began)` and `.momentum(.ended)` are each `.decided(.scroll(.passStill))`; after the last, `isGatedPortOn` is false. | R3 "the rest MUST stay withheld until it ends"; plan 006:649 (never relaxes, momentum inherits); P10 (momentum arrives about a second after the lift, after `blocksClicks` fell); the existing drop and still sequences in `ScrollSuppressionTests`. Without `scroll.isSuppressing` in the predicate the port closes on the lift frame and the momentum reads `.notSent`. |
| T7 | R3 | World, frame by frame (hand frames) | Given `thumb` at (10, 10) landing at 0 ms, a finger landing at 100 ms, the button down from 110 ms, the thumb lifting at 200 ms with the finger still down and pressed, the button up at 300 ms, the finger up at 350 ms. When played frame by frame, observing `isGatedPortOn`, with `.pointer(.drag(button: 0))` and `.pointer(.pressure)` offered between the 250 ms and 300 ms frames, and `.pointer(.drag(button: 0))` offered again after the 300 ms frame. Then `isGatedPortOn` is true after every frame from 100 ms through 250 ms (the thumb's lift included); the drag reads `.decided(.pointer(.passAsMove))` and the pressure `.decided(.pointer(.drop))`; after the release `pressVerdicts == [.drop, .drop]`, `isGatedPortOn` is false, and the last drag reads `.notSent`. | R3 "the start of a press … and then withhold its end"; plan 002 R5 (a press blocked whole), 002:1134 (its drags and pressure); C6; `ClickBlockingTests.aPressAcrossTheThreeSecondMarkIsBlockedWholeAndStillCountsAsTheTap`. Without `click.isWithholding` the port closes at 200 ms. |
| T8 | R3 | World | (a) Given the thumb and two fingers down. When `.dockSwipe(.began, .gesture)` and `.dockSwipe(.began, .dockControl)` are offered, then everything lifts, then `.dockSwipe(.changed, .gesture)`, `.dockSwipe(.ended, .gesture)`, `.dockSwipe(.ended, .dockControl)` are offered in turn. Then both opening offers are `.decided(.dockSwipe(.drop))`; `isGatedPortOn` is true after the lift and after the two `.gesture` offers (both `.decided(.dockSwipe(.drop))`); it is false only after the `.dockControl` `ended`, itself `.decided(.dockSwipe(.drop))`. (b) Given a thumb alone. When `.dockSwipe(.began, .gesture)` is offered (`.decided(.dockSwipe(.pass))`) and the thumb lifts. Then `isGatedPortOn` is false. | R3 for Dock swipes; plan 006-log:45 and `DockSwipeFilter.swift:11-12` (judged once, kept whole, one filter per stream); C9 (`.pass` memory is not load-bearing). |
| T9 | R1, R2 | World | Given the thumb rested 4 s alone, then two fingers land. When `scroll(.fingers(.mayBegin))` and `scroll(.fingers(.began))` are asked (both `.pass`: past the window), then the fingers and the thumb lift, then a fresh thumb lands with two fingers beside it and `.scroll(.fingers(.mayBegin))` is offered. Then after the lifts `isGatedPortOn` is false (a passing gesture whose `ended` was never seen holds nothing open), and the final offer is `.decided(.scroll(.drop))`, not `.passStill`. | R1's predicate (nothing altered in flight); C8 ("`.touching(.passed)` differs from nil in exactly one case"); C10(b) and the design's "the open overwrites exactly the stale state"; `ScrollSuppressionTests.scrollingReturnsAfterThreeSecondsAndWhenTheThumbLifts`. Without `resume` the offer reads `.passStill`. |
| T10 | R1 | World | Given a fresh thumb and two fingers sliding 10 mm (a swipe) with `.scroll(.fingers(.began))` and `.scroll(.fingers(.ended))` offered dropped and no momentum. When everything lifts and, later, two fingers land away from the corner and `.scroll(.fingers(.mayBegin))` is offered. Then `isGatedPortOn` is true after the lifts (the coast lingers), the offer is `.decided(.scroll(.pass))`, and `isGatedPortOn` is false right after it. | The design's accepted tradeoff ("keeps the gated port on until the next scroll gesture's first event"); C8 (`.coasting(.dropped)` lingers until the next fingers event); R1's predicate read as the filter's own memory. |
| T11 | R2 | World (hand frames) | (a) Given the button down on a frame with no touches (0 ms, a passed press). When the thumb lands at 50 ms and a finger lands at 100 ms, both with the button still down, the finger lifts at 200 ms and the button is released at 300 ms. Then nothing fires, `pressVerdicts == [.pass, .pass]`. (b) The same with the thumb lifting at 150 ms (a close and its echo) and landing again at 200 ms before the finger lands at 250 ms: the same. | Plan 002:376 ("No ordering of events can produce 'a click and a gesture'"), 002:367 and `Touch.swift:72-82` (a passed press reads `.click` while down); `GestureRecognizer.swift:101` (a `.click` spoils); P6 and the design's Notices rule (the echo of our own close forgets nothing). A handler that forgets on every notice, or a gated press port, lets the tap fire in (b). |
| T12 | R4 | World | (a) Given the thumb and two fingers down and `scroll(.fingers(.began)) == .drop`. When `systemDisables()` (both ports). Then `isGatedPortOn` is true again and `scroll(.fingers(.changed)) == .passStill`. (b) Given Arc on the 1-finger gesture, the thumb down, one finger landed 20 ms ago and the button down (withheld). When `systemDisables()`, then the button and the finger lift. Then `pressVerdicts == [.drop, .pass]` and Arc comes to the front. (c) Given no touches. When `systemDisables()` inside `withLateWakes { }` with `.pointer(.release(PressID(button: 2, number: 7)))` offered inside and again after the block. Then inside: `.notSent`; after: `.decided(.pointer(.pass))`, `isGatedPortOn` false, `offer(.scroll(.fingers(.changed))) == .notSent`. (d) Given the thumb down, a finger landed 20 ms ago, the button down (withheld) and `scroll(.fingers(.began)) == .drop`. When `systemDisables([.gated])`. Then `isGatedPortOn` is true again, `offer(.pointer(.drag(button: 0))) == .decided(.pointer(.passAsMove))` (the press is still withheld), `scroll(.fingers(.changed)) == .passStill` (the scroll was forgotten); after the lift `pressVerdicts == [.drop, .drop]`. (e) The same given. When `systemDisables([.presses])`. Then `scroll(.fingers(.changed)) == .drop` (the scroll is kept), `offer(.pointer(.drag(button: 0))) == .decided(.pointer(.pass))` (the press was forgotten); after the lift `pressVerdicts == [.drop, .pass]`. | R4 "recover as it does today, without turning on a tap the gating wants off"; C12 (today forgets and re-enables); `ScrollFilterTests.forgettingTheGestureTreatsTheRestAsFirstSeenMidWay` (`.passStill` under the flag after a forget); plan 002:1130 (a press passed unseen while disabled reads as nothing, so the tap fires); `ClickFilterTests.forgettingHeldPressesLetsALostReleasePassAndClearsHolding`; the design's Notices paragraph and Tradeoffs accepted (forgetting per disabled port). Today's unconditional re-enable turns (c)'s `isGatedPortOn` true; today's forget-all gives (d) `[.drop, .pass]`. |
| T13 | R4 | Core: `TapFilters.portsWereDisabled` | Given a value opened by `follow(.estimated(from: .clicks))` holding a withheld press (`decide(.pointer(.press(p)), in: .clicks)` → `.drop`) and a dropped scroll (`decide(.scroll(.fingers(.began)), …)` → `.drop`). When (a) `portsWereDisabled(pressPortIsOn: false, gatedPortIsOn: true, in: .estimated(from: .none))`; (b) `(true, false, .none)`; (c) with `.unseen` memory instead (a value opened by `follow(.estimated(from: .dockSwipes))`): `(true, true, .clicks)`; (d) a closed value: `(true, false, .none)`; (e) an open value with nothing in flight: `(true, false, .none)`; (f) the value of (a) and (b) with both ports off and context `.clicks`. Then (a) returns nil, `holding == .nothing`, the next `.scroll(.fingers(.changed))` under `.none` is `.drop`, `gateIsOpen` true; (b) returns `.open`, `holding == .withheld`, the next `.scroll(.fingers(.changed))` under `.none` is `.pass`; (c) returns nil and the next `.scroll(.fingers(.began))` under `.clicks` is `.passStill`; (d) returns nil, `gateIsOpen` false; (e) returns nil, `gateIsOpen` false; (f) returns `.open`, `holding == .nothing`, and the next `.scroll(.fingers(.began))` under `.clicks` is `.drop` (a reset to nil, not `.unseen`). | The design's Notices paragraph (forgetting per port; a notice is a prompt to reconcile; "today's reset: nil, not `.unseen`"); C12; P6 (one echo per close); the judge's graft (a gated-port timeout never releases a withheld press's mouse-up). |
| T14 | R1, R3 | Core: `TapFilters` | (a) `follow(.estimated(from: .clicks))` → `.open`; `decide(.scroll(.fingers(.began)), in: .estimated(from: .clicks))` → `(.scroll(.drop), nil)`; `follow(.estimated(from: .none))` → nil with `gateIsOpen` true; `decide(.scroll(.fingers(.ended)), .none)` → `(.scroll(.drop), nil)`; `decide(.scroll(.momentum(.began)), .none)` → `(.scroll(.drop), nil)`; `decide(.scroll(.momentum(.ended)), .none)` → `(.scroll(.drop), .close)`. (b) `follow(.clicks)` → `.open`; `follow(.none)` → `.close`; `decide(.scroll(.fingers(.began)), .none)` → `(.scroll(.pass), nil)`, `gateIsOpen` false. (c) fresh: `decide(.pointer(.press(p)), .clicks)` → `(.pointer(.drop), .open)`; `decide(.pointer(.release(p)), .none)` → `(.pointer(.drop), .close)`. (d) fresh: `decide(.scroll(.fingers(.changed)), .clicks)` → `(.scroll(.passStill), .open)`. (e) `follow(.possible)` → `.open`, again → nil. (f) a fresh value: `gateIsOpen` false, `holding == .nothing`. | The design's gate paragraph (the level is read per event; a lowering before the read passes and nothing is in flight, after it the drop holds the gate; a press or straggler before a pending wake opens first; `follow` idempotent); R3; P5 (a straggler is still decided); `ScrollFilterTests` (a mid phase under the flag is `.passStill`). |
| T15 | R2 | Core: `ScrollFilter` | From a fresh filter after `resume(scrollMayBeUnderWay: true)`: (a) `mayBegin`/true → `.drop`; (b) `began`/true → `.passStill`, then `changed`/false → `.passStill`; (c) `changed`/false → `.pass`; (d) `momentum(.changed)`/true → `.pass`, `momentum(.ended)`/true → `.pass`, then `began`/true → `.drop`. (e) From `.touching(.passed)` (`began`/false), `resume(scrollMayBeUnderWay: false)` then `began`/true → `.drop`; (f) from `.coasting(.dropped)` (`began`/true, `ended`/false), `resume(scrollMayBeUnderWay: false)` then `momentum(.began)`/false → `.drop`. (g) `isSuppressing` is true after `began`/true and after the `ended` that follows it, and after `changed`/true from `.touching(.passed)`; false for a fresh filter, after `resume(true)`, after `began`/false, and after `momentum(.ended)`. | The design's `.unseen` rules (a fresh start is dropped, a gesture first seen mid-way is stilled, momentum passes and its end clears); C8 and C10; plan 006:649 (never relaxes). |
| T16 | R2 | Core: `DockSwipeFilter` | (a) After `began`/false (`.pass`), `resume()`, then `began`/true → `.drop`. (b) After `began`/true (`.drop`), `resume()`, then `changed`/false → `.drop`. (c) `isDropping` is true only between a dropped opening and its `ended` or `cancelled`. | The design's "keeps a `.drop` and forgets a `.pass`"; C9 and C10(d) (a stale `.pass` would pass the next under-flag swipe); `DockSwipeFilterTests.aSwipeOpeningWhileBlockingIsDroppedWholeEvenIfBlockingEnds`. |
| T17 | R1 | Core: `TapContext` | `estimated(from:)` for each level: `.none` → `(.none, false)`, `.possible` → `(.possible, false)`, `.dockSwipes` → `(.dockSwipes, true)`, `.clicks` → `(.clicks, true)`. | The design's `estimated(from:)` ("fingers down beside a thumb … as a scroll may be under way"); C11 (the only reachable no-warning scroll). |
| T18 | R1, R2 | Recognizer, every frame | (a) The level per state, each over hand frames or a script: no touches → `.none`; a thumb alone → `.possible`; a thumb and an edge contact in the bottom band only → `.possible`; a thumb with a finger landing 1000 ms after it → `.clicks`; at 2990 ms `.clicks`, at 3010 ms `.dockSwipes` (the existing `expiryIsSeenOnAFrameWhereNothingButTheClockMoved` hand); a thumb already `.down` on the first frame with a finger landing → `.dockSwipes`; two fingers resting with no thumb → `.none`; the thumb landing under them → `.clicks`; a series with one rest finger and no thumb → `.clicks`; a confirmed swipe after the thumb lifted → `.clicks`; an unconfirmed window swipe whose thumb lifted, `answering: nil` → `.possible`; the same declined with the thumb gone → `.none`, declined with the thumb rested 4 s → `.dockSwipes`; a thumb rolled out of the corner → `.none`; the `[]` frame → `.none`. On every frame `blocksClicks == (blocking == .clicks)` and `blocksDockSwipes == (blocking >= .dockSwipes)`. (b) Over the thumb-first scripts `thumb.tap(fingers: n)` for n in 1…5, `thumb.land(2).slide((10, 0))`, `thumb.land(2, atMM: (62, 30)).slide((0, 10))`, `thumb.tap(1, click: .firm)` and `thumb.wait(4 s).land(2)`: on the frame before the first frame at or above `.dockSwipes`, `wantsTap` is true. (c) The only entries with no warning frame: the thumb and a finger on one frame (`.clicks` on the first frame), a thumb landing under resting fingers (`.none` then `.clicks`), a resting thumb on a fresh recognizer's first frame with a finger (`.dockSwipes` on the first frame). | C4 and `GestureRecognizer.swift:182-200` (today's truth table, kept); the design's `step` tail and `Blocking` doc comments; C5's list of no-warning entries; `GestureRules.clickBlockingWindow` 3 s, strictly less; `DockSwipeBlockingRecognizerTests.aThumbAlreadyRestingWhenRecognitionStartedBlocksToo`; `SwapRecognizerTests.theSeriesBlocksClicksAndDockSwipesWhileAnyRestFingerIsDown…`. |
| T19 | R1 | Platform: `DeviceSession` | Given `DeviceSessionAnswerTests.frames()` (the thumb rested 4 s, two slides down, each 3.5 then 12 mm, in 10 ms frames, two thumb-only frames after each). When the first start is answered true before the next frame, in a second run false, in a third never. Then `session.blocking` per frame reads `.possible` on the thumb-only frames (the first frame and after each lift), `.dockSwipes` on every finger frame up to and including the start frame, `.clicks` from the frame after a confirmed start to the frame before the lift, and never `.clicks` when declined or unanswered; `blocksClicks` equals `blocking == .clicks` on every frame, so the existing rows keep passing unchanged. | Plan 012's answer rule (`aStartConfirmedAtOnceBlocksClicksFromTheNextFrameUntilTheLift`); the design's `Blocking` for an unconfirmed slide and a thumb alone; `FrameStream.swift:58-59` replaced by one write. |
| T20 | R1, R2 | Platform: `TapEventTests` | `TapEvent.pressMask` is bits `[1, 2, 3, 4, 25, 26]` and `gatedMask` bits `[6, 7, 22, 27, 29, 30, 34]`; they are disjoint and their union is today's 13 bits; one synthetic event of every type in `pressTypes` and `gatedTypes` parses; for each, `ridesGatedPort` is true iff its type is in `gatedTypes`; a Dock swipe on type 29 parses to `.dockSwipe(phase, .gesture)` and on 30 to `.dockSwipe(phase, .dockControl)`, each phase as today; the two disabled notices (0xFFFFFFFE, 0xFFFFFFFF) are in neither mask; the pointer, scroll and rewrite tables are unchanged. | R1's gated set; C7 and the design's press port (1, 2, 3, 4, 25, 26); C1 (today's 13 types, `TapEventTests.swift:8-11`); `DockSwipeFields`. |
| T21 | R4 | Source scan | `tapEnable` appears only in `ClickTap.swift`; `tapCreate`, `CGEventTapCreate` and `scrollWheel` still only there; the rows' labels read "the click tap's event taps, one file". | Plan 002:437 and 002:1319 ("nothing on the frame thread enables or disables the tap"), now a build rule; C16. |
| T22 | R4 | World | (a) Given the thumb and two fingers down with `scroll(.fingers(.began)) == .drop`. When Accessibility is revoked (`permissions.set(.accessibility, granted: false)`). Then `isBlockingClicks` false, `isGatedPortOn` false, `offer(.scroll(.fingers(.changed))) == .noTap`, `scroll(.fingers(.changed)) == nil`. When it is granted again and the next frame (the same contacts, `.down`) is played: `isGatedPortOn` true, `offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.drop))`, `scroll(.fingers(.began)) == .pass`. (b) The same hand; when `hardware.wake()`. Then `runCount` rose by one, `isGatedPortOn` false, `offer(.scroll(.momentum(.began))) == .notSent` and `scroll(.fingers(.changed)) == .pass`. (c) When `hardware.sleep()` with the thumb and a finger down. Then `isGatedPortOn` stays true and frames played are dropped; after `wake()` it is false. (d) `attach(.magicTrackpad)` and later `detach` mid-gesture: false after each. (e) `setSwipe(on: false)` mid-swipe and `setHandMode(.left)`: false after each. (f) Tap to click turned on: `offer(.scroll(.fingers(.changed))) == .noTap`. | R4's list (revoke, hot-plug, wake, hand-mode or setting change); C13 (`run` replaces the tap and abandons everything in flight: "a harmless stray mouse-up", plan 006:641 "resumes headless"); the design's Lifecycle (sleep latches the level; a fresh value is closed and converges; a resting thumb's landing is unknown, so `blocksClicks` is false and `blocksDockSwipes` true: `DockSwipeBlockingRecognizerTests.aThumbAlreadyRestingWhenRecognitionStartedBlocksToo`); `ClickBlockingTests.blockingFollowsTheGrantAndTheRevokeWithoutRelaunching`. |
| T23 | R1, R2 | World, two trackpads | Given `World(attached: [.macBook14, .magicTrackpad], accessGranted: true)`, started. When a thumb lands alone on the Magic Trackpad, then two fingers land on the MacBook, then a thumb lands under the MacBook's fingers, then the MacBook's thumb lifts. Then after the Magic thumb `isGatedPortOn` is true and `scroll(.unphased) == .pass`; after the MacBook fingers (`.none` there) still true and `.pass`; after the MacBook thumb `scroll(.unphased) == .drop` and `scroll(.fingers(.began)) == .drop`; after it lifts `scroll(.unphased) == .pass` and `isGatedPortOn` true (the Magic thumb still wants it). | The design's merge by `max` across trackpads; C3 (today's OR per flag) and the ended N/N-1 split; `docs/domain-model.md` *Click blocking* (a mouse's scroll is suppressed while any trackpad blocks); `WindowSwitcherOnScreenTests` two-trackpad rows. |
| T24 | R2 | World, `usesEstimatedContext` | Given `World.switcherWorld(accessGranted: true)` with `hardware.usesEstimatedContext = true`, and beside it the same world with the default. When (a) two fingers rest 150 ms, the thumb lands under them, waits 50 ms and the fingers slide 10 mm, with no `mayBegin` offered; (b) the `SwapTests.fromTheFirstSwapUntilTheFingersLiftClicksAndScrollsAreBlocked` hand (rest 150 ms, thumb tap, slide 10 mm), no `mayBegin` offered; (c) a fresh thumb, then two fingers beside it, `.scroll(.fingers(.mayBegin))` offered after the fingers land; (d) the thumb and a finger on one frame (hand frames), no late wakes, with `.scroll(.fingers(.mayBegin))` offered in one world and nothing offered in another. Then under the estimate (a) and (b) read `scroll(.fingers(.began)) == .passStill` where the default world reads `.drop`; (c) reads `.decided(.scroll(.drop))` in both (the `.possible` opening resumed to nil and the `.clicks` step reopens nothing); (d) with the `mayBegin` offered reads `.decided(.scroll(.drop))` and then `scroll(.fingers(.began)) == .drop`, and with nothing offered `scroll(.fingers(.began)) == .passStill` under the estimate and `.drop` by default. The existing `SwapTests` row keeps its `.drop` untouched. | The design's `estimated(from:)` and its Tradeoffs accepted ("the fake knows what it withheld while the real tap estimates it"); C11 and plan 006:1331 (stilled on hardware, since the system sends the `mayBegin` on landing, P10); checks README "SwapTests:324"; the design's two outcomes for the same-frame landing. |
| T25 | R1 | Platform: `DeviceSession` with a stub `TapLink` | Given a session whose `tap` is a stub `TapLink` that records every `wake()` and answers a fixed `holding`. When `DeviceSessionAnswerTests.frames()` plus one trailing `[]` frame are played with the start answered true, recording the wake count after each frame. Then exactly one wake on the first frame (`.none` to `.possible`), none on any frame where the level moved among `.possible`, `.dockSwipes` and `.clicks` (the finger landing, the start, the confirmation, the lift), and one on the `[]` frame (`.possible` to `.none`): two in all; `session.holding` reads the stub's value, and nil for a session with `tap: nil`. | The design's call site 1 ("a wake-up of the tap thread only when this trackpad's `wantsTap` flips") and `TapLink`'s doc comment ("one per `wantsTap` flip, none otherwise"); `Blocking.wantsTap` (`>= .possible`); `Touch.swift:47` (the `[]` frame after the last lift). A wake on every level change gives more than two; a wake on none gives zero. |

### Verified without a test

Every hardware check runs on the MacBook Pro of the audit, a Debug build from Xcode unless it says Release, right hand, the three switches on, Accessibility granted. Each names the part of a requirement no seam can observe; the rest of that requirement is in its rows.

- **R1, the CPU budget (M1, Release).** Build Release (`-O`, whole-module optimisation, hardened runtime), launch, let the first scan settle, make no gesture. Measure as the audit did: `proc_pid_rusage` user plus system time before and after 40 s of pointer moves and two-finger scrolling in Safari, divided by the trackpad frames delivered in that window. Expect at most 0.088 ms per frame on each of three runs. Then one thumb-first swipe and one ordinary scroll gesture (the lingering coast ends at that gesture's first event), and the same 40 s again: the same bound. Then Instruments Time Profiler over 30 s of pointer moves and scrolling: no samples on the `ClickTap` thread. A test is not the right proof: the cost is SkyLight's, in the Release binary, on real devices.
- **R1 and R2, what the real gated port passes and withholds (M2).** Safari over a long page, Mission Control on three-finger swipe. (1) Thumb in the corner, two fingers slide: the page does not move and no desktop switches, ten of ten tries, including five where the fingers land within a frame of the thumb. (2) Flick two fingers under the thumb and lift everything at once: the page does not coast (R3, the momentum). (3) Two fingers rest first, the thumb lands, the fingers move: the page stays still and the overlay scrollers flash (C11, stilled). (4) Thumb and finger, click and hold, drag and Force Click: nothing is clicked, no drag reaches the page, no Force Click preview (the press port and the drags of a withheld press). (5) With the thumb rested 4 s, two fingers scroll: the page scrolls. (6) No thumb: scrolling, dragging, pinching and a three-finger desktop swipe all work. (7) A Magic Mouse scroll under a MacBook thumb and finger is suppressed. (8) D2: with Activity Monitor's CPU graph visible, a thumb-plus-two-finger slide does not switch desktops; note whether the Dock ever shows a half-started switch. A test is not the right proof: the real taps need trust and devices.
- **R4, the system's disable and our echo (M3).** (1) Gate open: thumb and two fingers down, pause in the debugger while scrolling under them for 5 s, resume: scrolling and clicking work; the next thumb-first swipe blocks again. (2) Gate closed: no thumb, pause while scrolling, resume: the same, and Time Profiler shows no `ClickTap` samples while scrolling afterwards (the system's disable did not leave the gated port on). (3) Twenty thumb landings and lifts, 1 s apart, then (1) again: no stuck state after twenty echoes. (4) Revoke Accessibility mid-swipe: scrolling resumes at once; grant it again: the next swipe blocks. (5) Sleep with the thumb and a finger down, wake: gestures and scrolling work. (6) Toggle hand mode and the swipe setting mid-gesture: the same. A test is not the right proof: the notices come from the window server.
- **The tap thread's rules (M4, code review).** `ClickTap.wake()` signals the source and wakes the published loop and never waits; `mergedBlocking()` copies the sessions out before reading any level; `install` disables the gated port on main before the thread starts, and the thread adds the three sources, publishes its loop and runs `follow()` before `CFRunLoopRun`; `handle` reads the merged level before taking the filters' lock and calls `apply` after releasing it, before returning the verdict; `recover` reads both ports' `tapIsEnabled` on a notice only and re-enables the press port when it read off; no two of the tap's locks are held at once; `remove` is idempotent and a wake or echo after it finds no ports. `grep -rn "tapEnable\|tapIsEnabled" LauncherKit/Sources` hits `ClickTap.swift` only. Why not a test: what is left is the real ports, the thread and the run-loop source, which need trust and devices; the frame thread's half is T25.
- **The open latency (M5).** Signposts are banned with the rest of logging, so the latency from a thumb's landing to the open cannot be timed in the app; P3 and P4 bound the last step at about 0.1 ms, and M2 (1) is the end-to-end evidence: a Dock swipe or scroll that beat the open would switch the desktop or move the page.
- **R2, the existing suite unchanged (M6).** `Scripts/test.sh` is green. `git diff --stat origin/main -- LauncherKit/Tests/LauncherCoreTests` lists only `InMemoryAdapters.swift`, `SourcePolicyTests.swift` (the relabelled rows and the `tapEnable` row) and new files; no existing `@Test` body under `LauncherCoreTests` changes, since the recognizer rows read the derived accessors and the World rows read `scroll(_:)`, `pressVerdicts` and `isBlockingClicks` with today's meaning. Under `LauncherPlatformTests`, only `TapEventTests.swift` (T20) and the two `DeviceSession` suites change (T19, T25, and the init's `tap:` label in `DeviceSessionTravelTests.swift`).
- **R5, the architecture notes (M7).** `grep -n "sleeps until an event arrives" docs/architecture.md` returns nothing; line 20 ends with the design's sentence verbatim ("The one extra thread is the click tap's run loop, which exists only while click blocking is armed and serves two event taps. …"); line 25 reads "the event taps"; `git diff --quiet origin/main -- docs/domain-model.md` succeeds.
- **The build (M8).** `swift build` and `swift test` in `LauncherKit`; `xcodegen` then `xcodebuild` builds the bundle; the policy scan passes with `TapEvent` in `LauncherCore` importing Foundation only.

## Slices

### S1: One ordered blocking level per frame

**What to build:** Nothing the user can see changes. Each frame yields one `Blocking` level (`.none`, `.possible`, `.dockSwipes`, `.clicks`) in `Recognition.blocking`, with `blocksClicks` and `blocksDockSwipes` derived from it, so `blocksClicks ⇒ blocksDockSwipes ⇒ wantsTap` holds by construction and every existing recognizer row compiles and passes unchanged. `step`'s tail computes the level with today's truth table plus `.possible` for a thumb alone and an unconfirmed slide whose thumb has gone. `DeviceSession` publishes one `Mutex<Blocking>` per frame (keeping `blocksClicks` for its tests), `mergedBlocking()` replaces the two per-flag merges, and today's `ClickTap.handle` reads the merged level once per event and derives both flags from it, which already ends the case where one event saw clicks from frame N and Dock swipes from frame N-1.

**Blocked by:** None (can start immediately).

**Requirements:** R1 (the level the gate reads), R2 (every verdict as today).

**Test scenarios:** T18, T19.

- [ ] T18 and T19 green.
- [ ] `Recognition(event:blocksClicks:blocksDockSwipes:)` is gone, `Recognition` is constructed only in `step`, and `anyTrackpadBlocksClicks()` and `anyTrackpadBlocksDockSwipes()` have no callers.
- [ ] `Scripts/test.sh` green with no existing test edited.

### S2: The click tap's mind as one pure value

**What to build:** Nothing the user can see changes. `TapEvent` moves into `LauncherCore` with `DockSwipeStream`, `ridesGatedPort`, and the platform extension holding `pressTypes`, `gatedTypes`, `pressMask`, `gatedMask` and the `CGEvent` parser (29 to `.gesture`, 30 to `.dockControl`); today's tap creates its one tap over the union of the two masks and keys its Dock filters by stream. The filters gain their in-flight queries (`ClickFilter.isWithholding`, `ScrollFilter.isSuppressing`, `DockSwipeFilter.isDropping`), the scroll filter its `.unseen` stage and `resume(scrollMayBeUnderWay:)`, the Dock filter its `resume()`. `TapFilters` arrives with `decide(_:in:)`, `follow(_:)`, `portsWereDisabled(pressPortIsOn:gatedPortIsOn:in:)`, `holding` and `gateIsOpen`, behind which sit the routing, the gate predicate, the reopen rules and the echo-versus-system logic; beside it `TapVerdict`, `GateChange`, `TapDecision` and `TapContext` with `estimated(from:)`.

**Blocked by:** S1.

**Requirements:** R1, R3 and R4 as the pure rules the suite and the real tap both run; R2 (the reopen rules reproduce today's outcomes).

**Test scenarios:** T13, T14, T15, T16, T17, T20.

- [ ] T13 to T17 and T20 green.
- [ ] The policy scan passes with `TapEvent` in `LauncherCore` (Foundation only).
- [ ] `Scripts/test.sh` green; the only existing test edited is `TapEventTests.swift` (T20 replaces its mask row and adds the stream).

### S3: The behavioural suite sees the gate

**What to build:** Nothing the user can see changes. `InMemoryTrackpads` wraps a real `TapFilters` and models the window server's side: one level per trackpad, press-port events always delivered while a tap exists, gated-port events only while `isGatedPortOn`, a tap-thread turn queued on each `wantsTap` flip and an echo on each close, `systemDisables(_:)` for one or both ports, `withLateWakes { }` and `offer(_:) -> Delivery`, with its context built from what it withheld unless `usesEstimatedContext` asks for the real tap's estimate. `scroll(_:)`, `pressVerdicts` and `isBlockingClicks` keep their meaning, so every World row passes unchanged, and the new rows show the gate closed during ordinary use, open on the thumb's frame, held through everything in flight, reconciled on a notice per port, reset by every `run`, and the one divergence between the fake's knowledge and the real tap's estimate.

**Blocked by:** S2.

**Requirements:** R1, R2, R3, R4, each as modelled in the suite.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T22, T23, T24.

- [ ] T1 to T12, T22, T23 and T24 green.
- [ ] M6: the whole suite green with no existing `@Test` body under `LauncherCoreTests` changed; `SwapTests:324` still reads `.drop`.

### S4: Two ports on the tap thread, gated for real

**What to build:** Ordinary pointing, dragging and scrolling no longer reach the app. `ClickTap` creates two active session taps on its one `userInteractive` thread, the press port enabled for its whole life and the gated port disabled at install and switched only by that thread: the wake-up source whose perform is `follow()`, `handle` deciding each event against the merged level and applying the gate before the verdict returns, `recover()` reading both ports' `tapIsEnabled` on a notice and handing them to `portsWereDisabled`, `apply(_:)` under the ports lock, `wake()` for frame threads, `remove()` idempotent over both ports and the source. `DeviceSession` reaches the tap through `TapLink` (`holding` and `wake()`, satisfied by `ClickTap` and by the tests' counting stub; `init` takes `tap: (any TapLink)?`) and wakes it on a `wantsTap` flip and never otherwise. `tapEnable` joins the tokens confined to the tap's file and the policy labels are reworded. `docs/architecture.md`'s Concurrency section says when the taps receive events and line 25 speaks of the event taps. The Release-build measurement and the hardware checks close the plan.

**Blocked by:** S3.

**Requirements:** R1 (the cost and the delivery, for real), R2 and R3 (on hardware), R4 (the real notices and lifecycle), R5.

**Test scenarios:** T21, T25.

- [ ] T21 and T25 green and `Scripts/test.sh` green; `DeviceSessionTravelTests` and the T19 rows pass with `tap: nil`.
- [ ] M4 passes code review.
- [ ] M1: at most 0.088 ms per frame on three Release runs, before and after a swipe, and no `ClickTap` samples while scrolling.
- [ ] M2 (1) to (8), M3 (1) to (6) and M5 by hand; D2's observation and the open-latency note recorded in the development log.
- [ ] M7: the architecture notes carry the design's sentence and the old claim is gone; M8: the build.
