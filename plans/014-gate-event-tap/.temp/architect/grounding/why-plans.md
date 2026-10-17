# Why (Plans source): the click tap's lifetime, its thread, the filters' in-flight state, and the accepted races

## Source

Plans only: `plans/<NNN>/plan.md`, `development-logs.md`, the committed `.temp/` architect notes (task, rubric, grounding, candidates) of plans 001, 002, 006, 012, and `design.md`/`testing.md`/`slices/` of plans 010 and 011. No git history, no `research/`, no code read for intent. Plan 014's own `.temp/` (other investigators' work in progress) was not read, except `plans/014-gate-event-tap/plan.md` for the question's context.

All paths below are relative to `plans/`. "002:437" means `002-gesture-click-blocking/plan.md` line 437; "002-log:23" means that plan's `development-logs.md` line 23; "002/.temp/candidate-2.md:667" means `002-gesture-click-blocking/.temp/architect/candidate-2.md` line 667.

## What I Searched

- Read in full: 002 plan.md (1–1320) and 002-log; 006-log; 009 plan.md requirements R1–R15, Implementation Decisions, Further Notes, and 009-log; 012-log; 002/.temp task.md, rubric.md, and the tail of grounding/why.md.
- Read by section: 001 plan.md (Problem, R20–R22, Design Problem, decisions 1–3, Concurrency, Tradeoffs, Alternatives); 006 plan.md (Solution, R9, R12–R14, Non-goals, Design Problem, Usage, Shape and decisions 1–14, Concurrency, recognition, scroll suppression and platform sketches, test fixtures, Requirement trace, Docs, Deliberately not done, Synthesis, Tradeoffs, Alternatives, Open questions and risks, Testing Strategy, test rows T10–T25, T40, T53–T58, T62, T64–T79, Verified without a test, S4); 008 plan.md R8, R12, decisions 4–6, T14, T19, T21; 012 plan.md Problem, Usage, change 1 decision, Deliberately not done, R13–R15, platform answer-slot sketch, degraded cases, docs, change 1 tradeoffs; 007 plan.md R1, R2, decisions 3–4; 010 design.md and 010-log; 011 plan.md R5, design.md, testing.md; 013 plan.md and 013-log (skim).
- 002/.temp: candidate-1.md and candidate-2.md (Deliberately not done, Concurrency, Tradeoffs, Alternatives, ClickTap sketch), grounding/index.md, checks/, the ax-tap-probe source header and output.
- 006/.temp: grounding/index.md (F8, F18–F21, risks), grounding/why.md, both candidates (grep).
- 012/.temp: grounding/why.md, how-platform.md, how-recognition.md (grep only, for leads).
- Greps across all plan files (each run over `00[1-9]-*/` and `01[0-3]-*/` plan.md, development-logs.md, design.md, testing.md, slices/):
  - `tapEnable|tap.*enable|enable.*tap|disable.*tap|tapDisabled|frame thread`
  - `tapEnable|enable the tap|disable the tap|enabling or disabling|enable/disable|tap.*enabled|tapIsEnabled|gat(e|ing) the tap|latency|round trip|wake-ups|wakeups|wakes for`
  - `never relax|relax|ScrollFilter|DockSwipe|type 22|type 29|type 30|tapMask|tapTypes|ClickTap|event tap|race`
  - `dock|blocksDockSwipes|gesture event|type 29|type 30` (in 006 plan.md)
  - `blocksClicks|blocksDockSwipes|ClickTap|event tap|ScrollFilter|DockSwipe|ClickFilter|tapEnable|blocking` (per plan, counted, then shown)
  - `same frame|landing race|one-frame race|accepted race|the race|races`
  - `resting fingers|under resting|already (down|scrolling|resting)|beside resting|lands? (beside|under|while)`
  - `answer|main-to-frame|frame thread|back to the frame|pending|awaiting` (012 plan.md)
  - `sleeps until an event arrives` (all of `plans/`)

## Direct Evidence Found

### A. Why the tap lives for the whole time blocking is armed, and plan 002's "not from the frame thread" rule

A1. The rule itself, with no reason stated beside it.
- **What it says**: 002:437, *Deliberately not done*: "Nothing in the mask beyond buttons, drags and pressure: no keyboard, scroll or plain movement. No posting or synthesising of events. No enabling or disabling of the tap from the frame thread."
- 002:1319, S4 checklist: "`grep -rn tapEnable LauncherKit/Sources` hits `ClickTap.swift` only (nothing on the frame thread enables or disables the tap)."
- **Relevance**: these are the two lines plan 014 cites. Neither line gives a reason. The final plan.md does not state the reason anywhere I found (see Gaps).

A2. The stated reason, which appears only in the non-base candidate (002/.temp/candidate-2.md).
- 002/.temp/candidate-2.md:146, *Deliberately not done*: "No enable/disable of the tap from the frame thread as the window opens and closes."
- 002/.temp/candidate-2.md:654, *Tradeoffs accepted*: "We accept that the tap, while installed, wakes the click thread for every mouse-button event session-wide, including a mouse's, in exchange for never enabling or disabling the tap from the frame thread; blocking applies only when a trackpad's window is open, and a user clicking is not idle under R22."
- 002/.temp/candidate-2.md:667, *Alternatives considered*: "**Hop the window decision to main and enable/disable the tap as it opens and closes.** Zero wakeups for mouse clicks while idle, but a main-actor hop per window transition, and a disabled tap misses the passed presses the filter must know about. Rejected on cost and correctness; a possible later refinement if the idle blips ever matter."
- **Relevance**: this is the only place in the plans that gives the reasons. There are two of them: cost (a main-actor hop per window transition) and correctness (a disabled tap misses the passed presses the filter must know about). It also calls gating "a possible later refinement if the idle blips ever matter". The cost weighed was mouse-button events only, because the mask then held no scroll or gesture types.
- **Standing**: candidate-1 was chosen as the base (002:1121). Candidate-1's *Deliberately not done* (002/.temp/candidate-1.md:177) does not contain the sentence. The final 002:437 does, but the Synthesis decision's list of grafts (002:1123) and 002-log do not record taking it over, or its reasons.

A3. One convergent `run` owns the tap's lifecycle: the tap belongs to the hardware port, and every reset is structural.
- 002:377, decision 3: "*Click blocking is part of the hardware port, not a port of its own.* The tap's only input is the per-trackpad `blocksClicks` flags, and its only output the frame path reads is `holding`. Both are frame-path state. `TrackpadHardware.run` gains one argument, `blockClicks: Bool`. `run` already means "forget everything, start exactly this", and that now includes "remove the tap; install a fresh one if asked and allowed". Every reset is structural: the per-trackpad flags live in each `DeviceSession`, which `run` replaces; the filter lives in the `ClickTap`, which `run` replaces. If the system refuses the tap, nothing is filtered, presses are sampled as today, and taps behave exactly as without access (per `make-operations-idempotent`)."
- 002:1132, Tradeoff: "We accept tearing down and recreating the tap on every reconcile, including trust changes. A press withheld at that moment sends apps a stray release, which they ignore. In exchange, there is one convergent `run` and no second lifecycle path for the tap."
- 002:379, decision 5: "`reconcile()` arms blocking with `blockClicks: activity.isActive && isAccessibilityGranted`: R4 "No blocking while gestures are inactive" and R9 "Declined" in one expression. Revoke tears the tap down through the same path, without relying on macOS to stop delivery."
- 002:665–669 (port doc): "Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent."
- 002:794: "Postcondition: frames flow from exactly `trackpads`; a tap exists iff asked, allowed and trackpads exist."
- 002:851 (ClickTap doc): "It exists from the `run` that armed click blocking until the next `run`."
- 002:881–885: "/// Main. Idempotent. Never relies on macOS to stop delivery after a revoke." with `CGEvent.tapEnable(tap: p, enable: false); CFMachPortInvalidate(p)` in `remove()`.
- **Relevance**: these explain why the tap's life is tied to arming (activity plus permission) through `run`. The stated benefit is "no second lifecycle path for the tap".

A4. Single writer per field, including the tap's port.
- 002:401, Concurrency: "*Writers:* `sessions` by main (`run`); each `blocking` flag by its device's frame callback; the filter by the tap thread; the tap's port by main (install and remove), with the tap thread only re-enabling through it. No two threads write the same field."
- 002:857: `private let port = Mutex<CFMachPort?>(nil)  // writer: main (install, remove); the tap thread only re-enables`
- **Relevance**: as designed, the frame thread never touches the tap's port. The plan does not itself link this rule to 437 (see Indirect I1).

A5. What the brief and grounding asked about lifecycle and idle cost.
- 002/.temp/task.md:22: "**Lifecycle.** When the tap is created and torn down relative to trust and to gesture activity; what happens on revoke (tear down yourself; do not rely on macOS stopping delivery), on grant without relaunch, on `run([])`, on wake. Idempotent under repeated reconciles." The brief names trust and gesture activity as the lifecycle inputs, not recognizer state.
- 002/.temp/task.md:17: "...that drops trackpad button presses while *blocking is in effect* and passes everything else."
- 002/.temp/rubric.md:15, criterion C3 title: "Correct under concurrency and time, with zero idle cost".
- 002/.temp/grounding/why.md:135, risk 6: "**Idle cost of a tap.** R22 measures idle "while no finger is touching any trackpad"; a session-wide mouse tap wakes the process on mouse-button events from any device, anchored or not. The record does not address whether that is a "blip" or how the tap's enabled state would follow the frame thread."
- **Relevance**: the grounding raised the question of the tap's enabled state following the frame thread. Candidate-2 answered it (A2), and the final plan kept only the conclusion (A1).

A6. Cost models plan 002 accepted. Each counts only the callback's own work.
- 002:1133: "We accept one extra thread while click blocking is armed, in exchange for click latency that never depends on the app's main thread and no WindowServer stall risk. It sleeps in the kernel between events and costs no idle CPU."
- 002:1134: "We accept a mask that includes drags and pressure. While blocking is armed, the tap wakes for every drag and pressure change in the session (a dictionary lookup each). In exchange, a blocked press is withheld whole: apps never see a drag or a Force Click stage of a press they never got."
- 002:1115, docs change: "the one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives". This is the sentence plan 014 R5 targets.
- 002:1258, *Design mechanisms with no row*: "Idle CPU with the tap installed: plan 001's R22 check repeated with access granted (0.0% after ten minutes idle)."
- **Relevance**: "idle" here is plan 001 R22's no-touch idle (001:419–420: "While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU"). No plan states a cost bound for while-touching use.

### B. Why the tap runs on its own thread

B1. 002:378, decision 4: "*The tap runs on its own thread's run loop.* Every click in the login session waits for the tap's callback. On the main run loop that wait would include the app's UI work (the picker's enumeration, LaunchServices lookups, SwiftUI layout) and risk a stall with main blocked in a WindowServer call while the WindowServer waits on our tap, until the tap is disabled by timeout. A dedicated `userInteractive` thread holds only the tap's run loop source, sleeps in the kernel between events and ends when `run` removes the tap. The thread retains its `ClickTap`, so no callback can outlive the object behind its `userInfo` pointer. On `tapDisabledByTimeout` or `tapDisabledByUserInput` the callback forgets every held press (their releases may have passed while the tap was disabled) and re-enables the tap."

B2. 002:1145, Alternatives: "**The tap on the main run loop.** This removes the thread and the cross-thread CF handles, but every click in the session would wait on the app's UI thread, with a stall risk while main waits on the WindowServer. Rejected for robustness."

B3. 002/.temp/candidate-2.md:111: "The WindowServer disables a slow tap and clicks then pass silently; the main thread does this app's only slow work (the picker's enumeration, SwiftUI layout). The callback touches only `Mutex`-guarded state and never hops to main." And candidate-2.md:666: "...a disabled tap passes clicks silently; the failure is exactly the feature's promise. Rejected for robustness."

B4. 002/.temp/grounding/index.md:18, sourced from `CGEvent.h`: "If a tap becomes unresponsive or a user requests taps be disabled, an appropriate `kCGEventTapDisabled...` event is passed to the registered CGEventTapCallBack function. An event tap may be re-enabled by calling this function". Its conclusion: "the callback must handle the two out-of-band types and re-enable; a slow callback (the WindowServer's timeout is undocumented) gets the tap disabled and events pass through."

B5. 002:852–854 (ClickTap doc): "Threads: installed and removed on main. Its callback runs on the tap's own `userInteractive` thread, whose run loop holds only this tap's source and ends when the tap is removed. That thread retains the ClickTap, so no callback outlives the object behind its `userInfo`."

B6. 002:1162, open question: "Does `CFRunLoopRun` on the tap thread return after `remove()`? The design both invalidates the port and stops the loop. Manual: the thread count drops after a revoke."

- **Relevance**: the thread exists for latency isolation and to avoid a WindowServer deadlock or timeout. Its premise is that the thread sleeps between events (B1, A6).

### C. The defensive re-enable on `tapDisabledByTimeout` / `tapDisabledByUserInput`

C1. 002:378 (B1 above) and 002:892–896 (sketch): "if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { filter.withLock { $0.forgetHeldPresses() } // releases may have passed while disabled; port.withLock { $0.map { CGEvent.tapEnable(tap: $0, enable: true) } } ..."

C2. 002:649–650 (ClickFilter sketch): "/// The system disabled the tap, and releases may have passed meanwhile. Forget every held press."

C3. 002-log:26 (cross-judge): "candidate-2 never cleared a passed press whose release the tap missed while disabled, cancelling every later tap until the next reconcile → candidate-1's forget-on-disable kept and extended to passed presses".

C4. 002:1130, Tradeoff: "We accept that a press the tap passed unseen while disabled by the system (a microsecond window) reads as nothing to the recognizer, so a tap could fire beside such a click. In exchange, no frame can ever read a press as a click before the tap has passed it, which would cost the user both the click and the gesture."

C5. 006:649, decision 11: "on `tapDisabledBy…` the filter forgets the gesture in progress, as `forgetHeldPresses()` does." 006:1026–1027: "/// The system disabled the tap; events may have passed unseen. Forget the gesture in progress (under-blocking)." 006:1479, T67's source cell: "(under-blocking is the safe direction, plan 002)".

C6. 006-log:45, Dock swipe fix (types 29 and 30). Per the code descriptions in 012/.temp/grounding/how-platform.md:70 (not plan text), the disabled path also clears the Dock swipe filters. The 006 dev log does not say so.

C7. Hardware checks of recovery. 002:1258: "Recovery from a disabled tap: pause the process in the debugger for several seconds while clicking, resume, then a firm tap inside a window is still blocked (the callback saw `tapDisabledByTimeout`, forgot its presses and re-enabled)." 006:1511: "*Recovery from a disabled tap:* pause the process in the debugger for several seconds while scrolling, resume → the next anchored swipe still stills the page and a firm tap is still blocked (the callback saw `tapDisabledByTimeout`, forgot its presses and its gesture, and re-enabled)."

- **Relevance (incident angle)**: no plan records an incident or outage behind the re-enable. It comes from the SDK header (B4) and was designed in from the start (task.md:17: "handle `tapDisabledByTimeout` / `tapDisabledByUserInput` by re-enabling"). The memory-forgetting half was hardened at cross-judge (C3). The plan's own phrase for the disabled window is "a microsecond window" (C4).

### D. Why a press is blocked or passed whole (ClickFilter)

D1. Requirement, 002:113–114, R5: "The press-down and the release of one press MUST both be blocked or both be passed." Scenarios 002:116–124: "Thumb lands during a drag" ("the drag continues and ends normally on release") and "Press across the 3-second mark" ("the whole press is blocked and nothing is clicked").

D2. Origin, 002-log:6 (Specify): "Press straddling the window or a drag in progress was undefined → new requirement: a press is blocked or passed as a whole."

D3. 002:376, decision 2: "*The filter's own decision is the single truth about a press.* `ClickFilter.decide` drops a press-down exactly when some running trackpad's latest `blocksClicks` is true at that event, then drops the release with the same `PressID`, turns that press's drags into plain moves so the pointer keeps moving (R6), and drops pressure events while any press is withheld. Every other event passes unchanged. The frame thread never works out "was this press blocked" for itself: it reads `holding` from the filter when it samples the press... No ordering of events can produce "a click and a gesture" or "neither": a press the tap passed reads `.click` only after the tap passed it, and a press the tap dropped reads `.blocked` whatever the button state table says. A press that beats its finger's landing frame passes as a click, frames read `.click`, and the tap cancels; that is today's behaviour, recorded as the accepted race (per "single source of truth per invariant")."

D4. 002:367, Shape: "...with a live filter, `.withheld` reads `.blocked` whatever the session's button state says, `.passed` reads `.click` while the button is still down, and `.nothing` reads nil even if the button state is down (the tap has not decided that press yet, or passed it unseen); with no filter (no tap, no permission), the button state alone says `.click`."

D5. 002-log:23 (cross-judge): "candidate-1 read a frame's press from "withheld" plus the session's button state, so a frame could read a press as a click before the tap dropped it, costing the user both the click and the gesture → the frame's press is derived from `ClickFilter.holding` (`.withheld` / `.passed` / `.nothing`), with the button still down required for `.click` so a release the tap missed heals on the next frame."

D6. 002:1143, Alternative rejected: "**A "blocking in effect" input to the recognizer.** ... R5's whole-press rule would live twice, in the filter and in the recognizer, and the two would have to agree at the window's edges and in the landing race. When they disagree, the user gets the click and the gesture. Rejected: two modules owning one decision."

D7. 002:1134 (A6): drags and pressure are in the mask so that "apps never see a drag or a Force Click stage of a press they never got."

D8. 002:788 (run sketch): "clickTap?.remove(); clickTap = nil  // a withheld press's release may now reach apps: a harmless stray up".

D9. Test rows. 002:1224, T31: "a finger ... lands at 0 with press `.click` (a drag in progress); at 50 the thumb lands in the corner with the press held ... → `pressVerdicts == [.pass, .pass]`" (source: "a release decided on the current flag would be dropped"). 002:1223, T30 (press at 2.91 s, release at 3.11 s → `[.drop, .drop]`). 002:1210–1215, T17–T22 (filter tables, including T21 `forgetHeldPresses()`).

D10. 002:1058 (fake's timing model): "a press edge reaches the tap BETWEEN frames, so it is decided on the flags left by the previous frame, merged across trackpads".

### E. Why a scroll, once suppressed, never relaxes (ScrollFilter)

E1. Requirements. 006:287, R12: trackpad scrolling "MUST be suppressed under exactly the conditions that block clicks ... Scrolling MUST work again at once when that condition no longer holds. Scrolling from a mouse wheel MUST NOT be suppressed." 006:315, R13: "...clicks MUST be blocked and trackpad scrolling MUST be suppressed from the moment a swipe begins until it ends or is cancelled". 006:338, R14: "The momentum that follows a suppressed scroll MUST be suppressed too, so nothing coasts after the fingers lift. The momentum that follows a scroll that was not suppressed MUST NOT be interrupted."

E2. 006:649, decision 11: "*The memory is the treatment of the scroll gesture in progress, momentum included:* a gesture first seen at an opening event (`mayBegin` or `began`) while blocking is `dropped`, so apps never see any of it; a gesture that was passing and meets blocking mid-way becomes `stilled`, its remaining events passed with every delta zeroed ..., so the app's began-to-ended bracket closes and nothing moves; a `passed` gesture's momentum is never touched (R14 "coasting from before"); the treatment never relaxes inside a gesture, the scroll analogue of plan 002 R5's whole press. This is what survives the race the single flag cannot order: a `changed` or `ended` arriving after the lift frame has cleared the flag is still part of a gesture already decided, so nothing leaks after a swipe (R13 "before, during or after")."

E3. 006:1329, Tradeoff: "We accept that a scroll gesture suppressed at any point stays suppressed until its fingers lift and its momentum ends, even if the 3 s window closes mid-gesture. In exchange, no app ever sees a broken began-to-ended bracket, nothing leaks when a `changed` races the lift frame, and momentum follows its gesture with no clock. We read R12's "work again at once" as "the next scroll works at once", the scroll analogue of plan 002 R5's whole press."

E4. 006:1352, Alternatives: "**Suppress by dropping only (O4).** Simplest, but when suppression starts mid-gesture (a late swipe, or a thumb landing mid-scroll) apps keep an open scroll gesture with no `ended`. **Suppress by zeroing only.** Brackets always close, but a gesture blocked from its first event shows apps an empty gesture (overlay scrollers flash), and per-event decisions relax at the lift and leak. The per-gesture treatment combines the two failure-free halves."

E5. 006:1325 (Synthesis, rejected from candidate 2): "scroll suppression folded into `ClickFilter` with a per-event rule (the lift race; and `passAsMove` would be meaningless for scrolls, `passAsStill` for presses)". 006-log:28: "a per-event scroll rule that leaks a `changed` racing the lift frame (R13)".

E6. 006:1014–1022 (ScrollFilter pseudocode): "stage .touching(t) → t' = (t == .passed && blocking) ? .stilled : t (never relaxes)"; "stage nil or .coasting → a new gesture: t' = !blocking ? .passed : phase opens (mayBegin, began) ? .dropped : .stilled (a gesture first seen mid-way was already seen by apps: only stilling keeps it whole)"; ".momentum(m): ... (momentum inherits; never escalates: R14)"; "stage nil → .pass (unknown coasting is never interrupted)".

E7. Why memory is needed at all. 006/.temp/grounding/index.md:40 (F18, probed): "...a flick is `began → changed… → ended (zero deltas)`, then ~7 ms later `momentum begin → continuous… → end`...; fingers resting then scrolling give `mayBegin` ~17 ms before `began`; resting then lifting without scrolling gives `mayBegin → cancelled` with no `began`... Conclusions: ... momentum suppression (R14) needs one bit of memory per gesture because momentum events arrive after the fingers lifted (when `blocksClicks` is already false)".

E8. Open question, 006:1361: "Is "a scroll suppressed at any point stays suppressed until its fingers lift" acceptable for R12's "scrolling MUST work again at once"? The alternative, resuming mid-gesture, shows apps `changed` events without a `began` for a dropped gesture, and leaks deltas at the lift of a late swipe. How far the drop-at-open rule reaches past the 3 s window also depends on whether `mayBegin` arrives when fingers land or ~17 ms before `began`".

E9. Risks. 006:1374: "*Risk:* the `mayBegin`-before-the-flag race. If the system's scroll recognizer emits `mayBegin` before our frame sets the flag, a gesture we would have dropped is stilled instead: overlay scrollers flash, and nothing moves." 006:1378: "*Risk:* a touch during momentum. If the system keeps emitting a dropped gesture's momentum events after a new gesture's `mayBegin` ... `ScrollFilter` would treat them as the new gesture's and they could move the page."

E10. Tests pinning the rule: 006:1476 T64, 1477 T65 ("`f(.changed, F) == .passStill`... the treatment never relaxes inside a gesture"), 1478 T66, 1479 T67, 1483 T71 ("the flag is false after the lift; the `.drop` comes from the gesture's memory"), 1485 T73, 1486 T74.

E11. Later plans treat the rule as a constraint they cannot undo.
- 012-log:65 (Plan, change 1): "Rejected: a frame-thread window read, a pushed window count, a read when the pair lands, starting blocked then releasing (the scroll filter never relaxes)."
- 012:1465–1466, Tradeoff: "We accept a window swipe's blocking starting on the frame after its start, about 10 ms later, in exchange for a declined slide being exactly the setting-off slide: on the start frame the slide blocks only by the thumb rules, which is what a declined slide must have blocked, because a scroll the filter has once stilled stays stilled until the fingers lift."
- 010-log:18: "T7's second `scroll(.fingers(.began))` would still drop: the shared `ScrollFilter` stays on its dropped treatment until the fingers' scroll ends".
- **Relevance**: 012 explicitly rejected over-blocking first and releasing later, because the filter's memory cannot be relaxed.

### F. Why a Dock swipe is decided once, when it begins (DockSwipeFilter, types 29 and 30)

F1. 006-log:45 (Implement, after merge): "User report after merge review: swiping in the switcher sometimes also moved to another desktop. Not reproduced (intermittent); diagnosed from the code and settings. This Mac has the three-finger horizontal swipe set to switch desktops, and macOS can count a thumb that landed recently or shifts as a finger, so thumb plus two sliding fingers reads as that three-finger swipe. The tap never saw it: its mask held only clicks, pressure and scroll, and the Dock's swipe travels as a separate gesture event. Fix: the tap also takes event types 29 (gesture) and 30 (Dock control) and drops only Dock swipes (HID type 23, field 110; phase in field 132), via a pure `DockSwipeFilter` that judges each Dock swipe once on its opening event and keeps it whole, since dropping one mid-way could strand the Dock between desktops. Its flag, `Recognition.blocksDockSwipes`, has no time limit: a thumb anchored with another contact down, or a swipe on. The field numbers are undocumented and taken from reverse-engineered Dock swipe tools; a hardware check must confirm the tap sees and drops real Dock swipes."
- **Relevance**: this is the only plan record of the 29/30 addition. It is a defensive fix driven by a user report (an incident in the loose sense). 006 plan.md was not amended: a grep for `dock|blocksDockSwipes|gesture event|type 29|type 30` in 006 plan.md finds only an unrelated "Dock" at line 5.

F2. The Dock swipe flag has no time limit. 011/testing.md:27 (T7) expects, with a thumb and a resting finger, `blocksClicks == [false, true, true, true, false, false, false]` and `blocksDockSwipes == [false, true, true, true, true, true, false]` over frames at 100, 1000, 2990, 3010, 4000 ms (the Dock flag stays true past 3 s). 008:223, R12: "...the 3-second blocking window, and Dock swipe blocking while a thumb is anchored and another finger is down." 008 T21: "`blocksDockSwipes` is true on every frame with a finger down through the fifth second; `blocksClicks` is true on those frames before 3 s and false after."

### G. Accepted races

G1. A press that beats its finger's landing frame (the landing race).
- 002:1129, Tradeoff: "We accept that a press reaching the tap before its finger's landing frame is delivered as a click, and that click cancels the tap. In exchange, a press is never both a click and a gesture, and there is no grace delay (a non-goal)."
- 002:376 (D3): "...recorded as the accepted race".
- 002:1226, T33: "`thumb.tap(fingers: 1, click: .onLanding)` (the press reaches the tap before the landing frame). → nothing, `pressVerdicts == [.pass, .pass]`".
- 002:426: "`.onLanding` (beats the landing frame: the race)".
- 002/.temp/grounding/index.md:27: "**Race to note:** the frame showing the pressing finger's landing travels through MultitouchSupport to the frame thread; the click travels through the HID system to the WindowServer and the tap. Their relative latency was not probed. A firm, very fast tap could reach the tap before "another finger is on the trackpad" is true on the frame side, and then pass as a click. The plan's non-goals rule out any delay, so this is an accepted risk to record."
- 002:1164, open question: "The latency race between the landing frame and the click event is accepted under the "no grace delay" non-goal; is a firm tap fast enough to hit it in practice?"
- 002:234, non-goal: "**Detecting a gesture before its click.** A press arrives before the fingers lift, so the app cannot know in time that it is a tap. Blocking keys off the anchored thumb instead."

G2. Thumb and finger on the same frame.
- 001:1436, T5: "Thumb and one finger land in the same frame; the finger lifts; then a clean 1-finger tap. → fired == [.one]". 001:729 (sketch): "fingers already down when the thumb lands (or landing in the same frame) never fire: wait for a clean slate".
- 009:296, decision 2: "...a thumb landing in the same frame as the fingers goes down the thumb-first path from idle". 009-log:47: "(a thumb 10 ms or 20 ms after the fingers swaps; the same frame does not)".
- 009:382, Further Notes: "With the permission the press is withheld anyway (each thumb landing opens a blocking window). The one visible consequence is the accepted one-frame race: a press reaching the tap before the thumb's landing frame passes to apps and the swap fires too."
- Note: I found no plan sentence that uses the words "a thumb and a finger landing on the same frame" as an accepted *blocking* race. That phrase is plan 014 R2's (014:33). The nearest texts are G1 (the landing race) and the rows above.

G3. A thumb landing under fingers that are already down or moving.
- 006:1331, Tradeoff: "We accept that a thumb landing in the corner while two fingers are already scrolling stills the rest of that scroll, because R12 says "exactly the conditions that block clicks" and a thumb landing with fingers down opens a window." 006:1362, open question: "R12 read literally stills an in-progress two-finger scroll when a thumb lands in the corner. Should a thumb that lands while two fingers are already scrolling open no scroll suppression (as R14 already protects momentum)?"
- 006:1486, T74 (coasting from before is not interrupted when the thumb lands; "the closing `.drop` proves the flag was on while the momentum passed").
- 002 R5 scenario "Thumb lands during a drag" (002:116–119) and T31 (002:1224), quoted under D.
- 009:302, decision 5 (fingers-first thumb): "Before the first swap, the fingers-first thumb (tapping or held) is the anchor for today's rules: Dock swipes are blocked while another contact is down, clicks while that holds and the thumb landed less than 3 s ago (R9, "unchanged") ... With no thumb nothing is blocked."
- 001-log:29: "candidate-2 ignored fingers already down when the thumb landed, so two resting fingers plus one tap would fire the 1-finger gesture ... → candidate-1's voiding kept, encoded as the `spoiled` state." 006:636: "fingers already down when the thumb lands put the recognizer in `.spoiled`, which never begins a swipe."

G4. A disabled tap passes events unseen. 002:1130 (C4), "a microsecond window". 006:641 and 006:1334 say the same headless outcome is accepted for a tap replaced by `run`: "inside the 3 s window it resumes without the `began` apps never saw, the headless gesture the disabled-tap recovery already accepts."

G5. Other accepted timing gaps.
- 002:1161, open question: "Does the frame stream always end with a frame that has no down contacts after the last lift? That frame is what clears `blocksClicks`. If the stream ever stopped with the thumb and a finger down, the flag would stay up until the next touch or `run`."
- 006:1375: "*Risk:* a swipe's block has no cap. Its exits are a lift, a foreign landing, a delivered click, or a `run`. A swipe could stick only if the pad never sent the empty frame after the last lift..."
- 012:1267 (degraded case, "Main actor busy past the next frame"): "The start waits, unconfirmed: its phases are reported, and it blocks only by the thumb rules, until the answer reaches the frame thread on a later frame."

### H. Precedents for crossing threads (frame thread to main, main to frame thread)

H1. 001:1383, Alternative rejected: "**Hop every frame to the main actor and recognize there.** No frame-thread `Mutex`, but it wakes the main thread ~100 times a second whenever a finger is on the trackpad, for no gain in depth; button state would still be sampled on the frame thread. Rejected on cost." 001:548: "Only fired gestures hop to the main actor; the main thread wakes for gestures, not frames".

H2. 001:1385, Alternative rejected: "**Devices always running, gated only at the fire path.** Simpler device lifecycle, but CPU is spent on frames that can never fire while *Tap to click* is on, and "nothing is recognised" would hold only in effect. Reconcile already runs on every input, so stopping the devices costs nothing extra." (A precedent for not spending CPU on input that can change nothing.)

H3. 006:640, decision 2: "*The flag stays the only channel* ... The tap reads it for presses and now for scrolls. Nothing new crosses between threads". 006:1313: "No main-to-frame channel: the recognizer is never told the row."

H4. Plan 012's main-to-frame answer, the one exception.
- 012:605–623, decision: "*A window swipe's start is a question the model answers before the next frame* (change 1; per separate-before-serializing-shared-state). ... The real adapter's `DeviceSession` delivers each start with a reply that writes `(began, isWindowSwipe)` into a slot only the main actor writes; its frame callback hands the slot to the recognizer before stepping each frame. The answer normally lands between the start frame and the next ...; if the main actor is busy the slide waits, unconfirmed, on the frames that keep arriving. No timer, no poll."
- 012:1141: "// Change 1: the answer to a window swipe start, the one thing that hops from the main actor to a frame thread."
- 012:1154–1157: "// Writer: the main actor, through a reply. Reader: this device's frame callback, which reads it before taking the recognizer's lock ... Never cleared: the recognizer ignores an answer it has already taken or that names another start."
- 012:690: "**Deliberately not done.** No main-to-frame channel beyond the one answer per window swipe start."
- 012:1471–1472, Tradeoff: "We accept one main-to-frame answer per window swipe start, through a slot only the main actor writes and a reply only the adapter calls, in exchange for every window read staying on the main actor and the frame thread never waiting on another app."
- 012:1334: "`docs/architecture.md` Concurrency gains the one answer that hops back to a frame thread".
- 012/.temp/architect/grounding/why.md:168 (Preserve 3): "**No main-to-frame channel.** ... Never restart devices from a gesture."

H5. 008:276, decision 4: "...This replaces plan 006's mechanism of ending a null-row swipe by re-running the trackpads, which is what R8 asks for and removes a device restart from a user gesture." 008:342: "Plan 006 ended a swipe with nothing to show by re-running the trackpads from the main actor so nothing stayed blocked... R8 here says the swipe still happens and stays blocked, so that mechanism and its test go".

### I. What resetting the tap's memory mid-gesture costs (from the plans' own mechanisms)

I-a. 006:641, decision 3 (later superseded by 008): "A scroll in progress at that moment is not stilled to its end: `run` replaces the tap and its filters, so the gesture's next event reaches a fresh `ScrollFilter` with the flag down and passes, resumed after a brief stop (inside the 3 s window it resumes without the `began` the dropped gesture never showed apps, the headless gesture the disabled-tap recovery already accepts)."
I-b. 006-log:35 (test planner, 2nd pass): "`run` removes and reinstalls the tap ..., so the gesture's next event meets a fresh `ScrollFilter` with the flag down and passes → the three sentences ... now describe the brief stop and the resumption, headless".
I-c. 006:1505 (R11 hardware check (c)): "record whether Safari takes it cleanly or shows a stuck elastic edge or an overlay scroller that never appears."
- **Relevance**: the plans record what happens when filter memory is lost while a gesture is in flight: the scroll resumes headless. 006 accepted it only for rare events (reconcile, disabled tap), and 008 removed one source of it.

## Indirect / Circumstantial Evidence

I1. "Not from the frame thread" and the single-writer rule.
- **What**: 002:401 names main as the tap port's only writer ("with the tap thread only re-enabling through it"), and 002:437 forbids the frame thread enabling or disabling the tap.
- **Inference chain**: enabling or disabling from the frame thread would make the frame thread a third writer of the port's enabled state, beside main and the tap thread's re-enable. That conflicts with "No two threads write the same field" (002:401) and with the rubric's "one writer behind a `Mutex`" (002/.temp/rubric.md:17).
- **Alternative reading**: the plan never links the two. The only explicit reasons are candidate-2's cost and correctness (A2), which concern a main-actor hop and missed passed presses, not writer counts.

I2. Why "missed passed presses" matters, in the plans' own terms.
- **What**: D4 (`.nothing` reads nil "even if the button state is down (the tap has not decided that press yet, or passed it unseen)"), C4 (a press passed unseen while disabled "reads as nothing to the recognizer, so a tap could fire beside such a click"), and A2 ("a disabled tap misses the passed presses the filter must know about").
- **Inference chain**: plan 002 accepted the "tap fires beside a delivered click" outcome only for "a microsecond window" (system disable). A tap that is disabled on purpose, for long stretches, widens that window. Any press delivered while the tap is off reads nil on the frame path while a `ClickTap` exists. A press with no `ClickTap` reads from button state (002:367, `holding: nil` → button state decides).
- **Alternative reading**: whether a tap gesture can be in progress while the gate is off depends on plan 014's gate predicate. If the gate is always open whenever a thumb is anchored (014:25), a recognizer tap (which needs an anchored thumb) may never overlap a gated-off period. The plans do not settle this; it is a design question for 014.

I3. The cost accepted when scroll was added was the callback's work, never the event-tap transport.
- **What**: 006:672 ("scroll events add ~100–250 Hz of wake-ups while anyone scrolls with the tap armed (F19, accepted)"), 006:1343 ("We accept that the tap wakes for every scroll event in the session while armed (F19), in exchange for one tap and no second permission."), 006/.temp/grounding/index.md:41 (F19: "the cost model for adding scroll events to the mask is already accepted for drags; scroll events add ~100–250 Hz while scrolling, each a few lock reads"), 006/.temp/grounding/why.md:145 ("Not idle (001 R22 is about no-touch idle), but worth recording as a tradeoff.").
- **Inference chain**: plan 006 did weigh scroll volume, but costed each event as "a few lock reads", the same model as 002's "a dictionary lookup each" (002:1134). Plan 014's profile (014:14) puts 84% of CPU in SkyLight's per-event decode and re-post, a cost no plan modelled.
- **Alternative reading**: none needed. The citations are explicit; only the comparison with 014's measurement is mine.

I4. The hardware checks that would have measured scroll wake-ups were not run when 006 shipped.
- **What**: 006-log:37: "every hardware and on-screen check under Verified without a test is still unticked (no hardware available to the implementers)". This list includes 006:1511 "*Scroll wake-ups and idle:* Activity Monitor shows the same thread count as plan 002 (the one tap thread) and 0.0 % CPU after ten minutes idle with access granted." That check measures no-touch idle only.
- **Suggests**: the while-touching cost was never measured by any plan before 014.

I5. 002's "no second lifecycle path" tradeoff was later partly undone, for another reason.
- **What**: 006-log:48: "Every reconcile cleared the switcher and restarted recognition, and preference and trust notifications fire for writes that change nothing here: a reconcile now runs the trackpads only when what it would run them with changed, or when a wake, hot-plug or empty switcher forces it." 008:276 (H5) removes the null-row restart.
- **Suggests**: later plans moved away from restarting `run` (and therefore the tap and its filters) during user gestures. 002:1132's "tearing down and recreating the tap on every reconcile" is no longer the shape described in the logs.
- **Alternative reading**: this concerns `run`'s frequency, not tap gating. It does not touch 002:437.

I6. The swipe-wide and series-wide blocking states.
- **What**: 006:640 (`blocksClicks` true in `.swiping`), 009:302 (both flags true "on every frame the rest is non-empty" during a series), 012:315 (R15, window swipe), 008:161 / 010/design.md:21 (a swipe with nothing to show "runs its course with the fingers blocked until they lift").
- **Suggests**: these are the recognizer states plan 014 R1 lists as "may need blocking". The plans define the flags' exits (lift, foreign landing, delivered click, `run`) but say nothing about a tap gate.

I7. The edge filter and blocking flags.
- **What**: 007:21: an edge contact "counts as neither "another contact down" for click and Dock swipe blocking nor a second contact that stops a thumb from arming"; 007:72: the flags' doc comments reworded to "another finger is down". 011:107–109: freed top-edge fingers count for click and Dock swipe blocking "exactly as a finger in the middle of the pad does".
- **Suggests**: what counts as a contact for blocking is decided in the recognizer after edge filtering. Any gate predicate derived from recognizer state inherits this.

## Contradictions

C-1. Plan 014 says plan 002's rule "never weighed today's event volume" (014:20). That is accurate for 002, which costed only drags and pressure (002:1134) and, in candidate-2, mouse-button events (002/.temp/candidate-2.md:654). Plan 006 did weigh and accept scroll volume (006:672, 006:1343, F19), but costed it as callback work ("a few lock reads") and did not revisit 002:437. No plan weighs the volume of types 29 and 30. They appear only in 006-log:45, which says nothing about frequency or cost.

C-2. Docs and claims about the thread sleeping. 002:1115 and 002:1133 say the tap thread "sleeps until an event arrives" and "costs no idle CPU". 006:1309 adds "The tap's thread now wakes for scroll events while armed." Plan 014 (014:20, R5) says `docs/architecture.md` still says it "sleeps until an event arrives". Both claims can be true, since the thread sleeps between events. What changed is how often events arrive while touching. I did not read docs/ (outside my source).

C-3. Plan 006 contradicts itself on what thumb plus two fingers triggers. 006:480, non-goal: "**Suppressing anything besides scrolling.** Pointer movement stays live. The hardware check found only scrolling reacts to thumb plus two fingers." 006-log:45: "macOS can count a thumb that landed recently or shifts as a finger, so thumb plus two sliding fingers reads as that three-finger swipe" (the Dock swipe fix). The log entry, which came later, won. 012/.temp/architect/grounding/why.md:35 also records this.

C-4. Plan 006 versus plan 008 on a swipe with nothing to show. 006:641 (decision 3) ends it with `reconcile()`, which restarts the devices and the tap. 008:276 (decision 4) and 008:161 (R8) keep it blocked until the fingers lift and remove the restart ("removes a device restart from a user gesture").

C-5. 002:1132 accepts re-creating the tap "on every reconcile, including trust changes". 006-log:48 says a reconcile now re-runs the trackpads only when the run inputs change. This is a later change in shape, recorded only in the dev log.

C-6. Where the "not from the frame thread" reasons live. The final plan (002:437, 002:1319) states the rule without reasons. The reasons (A2) are in a non-base candidate whose other choices the synthesis rejected or did not record grafting (002:1121–1125). The plan neither endorses nor contradicts candidate-2's reasons; it is silent on them.

C-7. Plan 002 R9's limit on what the tap may read. 002:181: "It MUST NOT read, record or change keyboard input, scrolling, pointer movement or any other event: the only events it reads are presses and what belongs to a press". 006:21 amends it: "R9's "MUST NOT read, record or change … scrolling" is amended by R12 to R14 here (scroll events are read, and those of a suppressed scroll are changed, under the one Accessibility permission)". Types 29 and 30 were added later (006-log:45) with no recorded amendment of R9 in any plan.md.

## Gaps

- I searched plans for an explicit reason next to 002:437 / 002:1319. The final 002 plan.md gives none; only 002/.temp/candidate-2.md:146, 654, 667 do. Neither the 002 Synthesis decision (002:1117–1125) nor 002-log records adopting the sentence or its reasons.
- Grepped all plans for `tapEnable|enable the tap|disable the tap|enabling or disabling|enable/disable|tap.*enabled|tapIsEnabled|gat(e|ing) the tap`. After plan 002 (and its .temp), no plan (003–013) considers enabling or disabling the tap by recognizer state. Plan 006 never discusses it, even when it added scroll.
- No plan discusses the WindowServer/SkyLight per-event cost of an active session tap, or the latency the tap adds to other apps' scroll, drag or gesture delivery. The nearest texts are 002:378 ("Every click in the login session waits for the tap's callback") and 002:1145.
- No plan estimates the volume or cost of event types 29 and 30. They are recorded only in 006-log:45, with the note that the field numbers are undocumented and a hardware check must confirm that real Dock swipes are seen.
- No plan states a CPU bound for while-touching use. R22 (001:419–420) covers only "While no finger is touching any trackpad".
- No incident or outage is recorded behind the `tapDisabledByTimeout`/`tapDisabledByUserInput` re-enable. It is designed from the SDK header (002/.temp/grounding/index.md:18) and the task brief (002/.temp/task.md:17).
- No plan addresses what a tap-disabled or tap-off period means for `DockSwipeFilter`'s memory. 006-log:45 states only "judges each Dock swipe once on its opening event and keeps it whole".
- Plans 003, 005 and 013 have no blocking content: grep counts were 0 for `blocksClicks|blocksDockSwipes|ClickTap|event tap|ScrollFilter|DockSwipe|ClickFilter|tapEnable|blocking`. Plan 004 mentions click blocking only in a manual test step (004:468, 004-log:29).
- No plan text says "a thumb and a finger landing on the same frame" as an accepted blocking race in those words. The nearest are G1 and G2.
- 006's S4 hardware checks were left unticked (006-log:37), so the plans contain no measurement of scroll wake-up cost, the touch-during-coast probe (006:1378) or the `mayBegin` timing (006:1361, 1374).

## Additional Leads

- Source control: find the commits that landed `ClickTap.swift` in plan 002 S4, the scroll addition (006-log:37 names S4 as `9d2f330`), and the Dock swipe fix (006-log:45; 012/.temp grounding/why.md:101 names `9044785` in connection with it). Check whether any PR review discussed gating or `tapEnable`.
- Source control: the commit behind 006-log:48 ("a reconcile now runs the trackpads only when what it would run them with changed") is the current form of 002:1132's lifecycle. Its diff shows whether the tap is still recreated on trust changes.
- Source control and code: confirm whether `DeviceSession.holding` still returns `clickTap?.holding` (002:820). If so, while a `ClickTap` exists a press the filter never saw reads nil on the frame path (D4). That bears on I2 if the tap is installed but disabled.
- Docs (other investigator): `docs/architecture.md` Concurrency and Privacy paragraphs. 002:1115, 006:1309 and 012:1334 each name sentences there that the plans changed.
- 002/.temp/grounding/probes/ax-tap-probe and 006/.temp/grounding/probes/scroll-tap-probe hold the only recorded tap probes: an untrusted run in 002, and in 006 "An active `.defaultTap` session tap over `scrollWheel` was created from the AX-trusted process ...; 0 disabled notices" (006 F18). A gating design may want a probe of `CGEvent.tapEnable` on/off latency and of events seen just after re-enabling. No plan has one.
