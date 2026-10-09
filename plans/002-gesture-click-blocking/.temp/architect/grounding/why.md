# Why: the press rule, button sampling, the permission and timer bans, and the peak count

Produced by the `why` skill (two investigators, one synthesizer) on 2026-10-09 against branch `feature/001-trackpad-launcher-app` at 7c7f7c2, as the precursor to replacing these rules in plan 002.

> Status note from the architect: the synthesizer read the probe directories before the probes had produced results. Both have since run; see `index.md` Q1 and Q2. In short: an active mouse-button tap returns nil without Accessibility; the Darwin notification `com.apple.tcc.access.changed` is delivered 30 ms after a TCC change on the main queue (so Risk 1 below now has a push mechanism, and Avoid 6 stands); whether a dropped press still reads as down in `CGEventSource.buttonState` (Risk 2) remains open, because the probe process is not a trusted client. The body below is the synthesizer's text, unchanged.

---

### The Question

Why does the recognizer treat a physical press as spoiling the tap and detect that press by sampling `CGEventSource.buttonState` on every frame rather than through an event tap; why are permission APIs and timers/polling banned by `SourcePolicyTests` and `docs/architecture.md`; and why is the finger count the peak number simultaneously down, with a 300 ms limit? The answer is wanted as a precursor to plan 002, which reverses or relaxes all three.

### The Code in Question

All paths below are under `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/001-trackpad-launcher-app/`.

- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift:31-52`: `armed` → `spoiled` when `frame.buttonDown` on the landing frame (line 34); `tapping` → `spoiled` on `buttonDown`, on `frame.time - start > maxTapDuration`, or on drag (38-43); `fired = Gesture(fingerCount: peak)` (45); `peak = max(peak, fingers.count)` (52). Logic from 4552ceb (S1); 1d10f52 only extracted `Self.tapping(...)` on lines 34 and 47.
- `LauncherKit/Sources/LauncherCore/GestureRules.swift:12` `maxTapDuration = .milliseconds(300)`; `LauncherKit/Sources/LauncherCore/Touch.swift:46` `buttonDown`; `LauncherKit/Sources/LauncherPlatform/FrameStream.swift:37-40` `anyMouseButtonDown()` (def630e, S5).
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:30-39` (timer/polling/permission tokens) and `docs/architecture.md:19,22` (ccd4654, never changed since).
- Branch `feature/001-trackpad-launcher-app`, 11 linear commits, all by domasgru with Claude as co-author; `main` holds only fe0e0d7 (the product overview). PR #1 is open with no reviews or comments.

### What We Found

**Why a press spoils the tap**

- **[Direct]** The press-spoils rule is a product requirement written during the Specify phase to close a gap, not a defensive guard. Source: `plans/001-trackpad-launcher-app/plan.md:167-168` (R11: "The following MUST NOT fire a gesture: a physical click (trackpad pressed down), with any number of fingers"), scenario "Click is not a tap" at `:208-211` ("the button is clicked as normal and Arc does not come to the front"), and `plans/001-trackpad-launcher-app/development-logs.md:4` ("Physical click with the thumb anchored was unspecified → R11 lists it as not a gesture"). The two spoil transitions in the code are the two the plan's T10 names (`plan.md:1441`: "`armed` → `spoiled` on the landing frame, `tapping` → `spoiled` mid-tap"), tested by `physicalClickIsNotATapAndTheNextTapStillFires` (`GestureRecognizerTests.swift:144`).
- **[Supported]** The reason a click is "not a tap" is that the design leaves clicks to the system and takes only taps. Evidence: non-goal `plan.md:446` ("The app requires [Tap to click] off instead of fighting the system's own clicks; this keeps the app free of permissions"); `plan.md:17` ("Gestures need *Tap to click* off"); `docs/domain-model.md:44-45` (a conflicting setting is one "that binds an action to a tap rather than a click, so it cannot coexist with gestures"). No sentence says "a press spoils the tap because X"; these three converge on a tap/click split where the system owns presses.

**Why button state is sampled per frame instead of using an event tap**

- **[Direct]** Sampling was chosen because an event tap was ruled out by the no-permissions constraint. Source: `plan.md:457` ("A click must be told from a tap without an event tap, so button state is sampled (Q2). ... Hard constraints: no permissions, no network, no logging, no timers or polling (R20–R22)"); `candidate-1.md:13` (same premise); `FrameStream.swift:37` ("A state query on the session's event source: no event tap, no permission"); `plan.md:1139` ("a state query, no tap, no TCC").
- **[Direct]** The grounding established that `buttonState` is permission-free and that the multitouch frame carries no button information. Source: `plans/001-trackpad-launcher-app/.temp/architect/grounding/index.md:29-32`: probed that `CGEventSource.buttonState(.combinedSessionState, button: .left)` "returns from a plain process with no prompt and no TCC entry"; sourced from `CGEventSource.h` that "it is a state query, not an event tap; no TCC category covers it"; conclusion "sampling ... detects the click without monitors, main-thread hops or permissions. Frames come every ~8–11 ms and a physical click's down state lasts longer than that"; "MTTouch carries no button state ... `zTotal` is pressure, not click". Note the same entry records that `true` was never observed ("the user was idle"); a real press was not probed.
- **[Direct]** Sampling on *every* frame (not only during a tap) was a deliberate tradeoff for recognizer purity. Source: `plan.md:1373` ("We accept sampling button state on every frame while touching, in exchange for a recognizer that is a pure function of its input"); `candidate-1.md:848` ("The alternative was sampling only when a tap is being counted, which would leak recognizer state into the adapter"). This resolves the scope shift from grounding Q2's "while a tap is in progress".
- **[Direct]** The sample is taken on the frame thread because per-frame main-actor hops were rejected on cost. Source: `plan.md:1383` ("Hop every frame to the main actor ... wakes the main thread ~100 times a second ... button state would still be sampled on the frame thread. Rejected on cost"); decision 1 at `plan.md:548` ("Only fired gestures hop to the main actor; the main thread wakes for gestures, not frames").

**Why permission APIs are banned**

- **[Direct]** R20 forbids any prompt, and the plan's problem statement gives the motive. Source: `plan.md:402` ("MUST work without asking the user for any system permission (no Accessibility, Input Monitoring or other prompt)"); `plan.md:9` ("A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled"); `plan.md:230` (R12: "If some part of this cannot be done without a permission prompt, R20 wins and that part is dropped").
- **[Direct]** That motivating paragraph was added during the Specify review, and the user's original brief does not mention permissions. Source: `development-logs.md:18` ("Problem statement did not motivate privacy, permissions, idle cost → paragraph added"); `docs/product-overview.md:7-8` (fe0e0d7) asks for "the least possible resources" and "0 network calls, no logging" and says nothing about prompts or Accessibility. The no-permission rule's provenance is the plan's specification step, not a user-stated requirement.
- **[Direct]** The ban list is the structural enforcement of R20–R22, labelled per requirement in the plan but not in the committed test. Source: decision 9 `plan.md:556` ("Rules are enforced by structure ... `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit"); `candidate-1.md:136` ("per encode-lessons-in-structure"); grounding Q11 `index.md:101` (a source scan is "the strongest mechanism available without swiftlint"). The plan's sketch labels entries `"R20"`, `"R22 timer"`, `"R22 polling"` (`plan.md:1325-1327`); the committed `SourcePolicyTests.swift:30-39` carries only `"timer"`, `"polling"`, `"permission"`. `architecture.md:23` and `SourcePolicyTests.swift:4-5` say to extend the list rather than write prose.

**Why timers and polling are banned**

- **[Direct]** Zero idle CPU is a requirement, and push-only input is the mechanism. Source: R22 `plan.md:420` ("0% CPU in Activity Monitor, with at most one momentary blip per minute"); grounding Q11 `index.md:100` ("every input the app waits on is push-based ... No timer is needed anywhere, so idle CPU is 0.0%"); `docs/architecture.md:19` ("No timers, no polling, no background loops: every input is a push ... This is what keeps idle CPU at zero"); `product-overview.md:7`.
- **[Direct]** "Time is data" was chosen over an injected clock and a timeout timer, against the task brief. Source: `plan.md:548` ("frames carry their own timestamps ... so no clock object or timer exists anywhere"); alternative `plan.md:1389` ("every lift is observed as a frame, so the frame timestamp is a sufficient clock, and a timer would be the app's only timer (R22)"); `plan.md:1356` (both candidates "independently rejected an injected clock and any timer"); `candidate-2.md:114,929,943`. The brief had asked for the opposite: `task.md:21` ("with the clock injected"), `rubric.md:8`, `index.md:135` ("The clock: injected"). The only timer the plan ever contemplated is a bounded device-readiness retry (`plan.md:1397`).
- **[Direct]** The synchronous test suite depends on this. Source: `plan.md:1420` ("The clock needs no fake: no clock object exists"); `plan.md:1551` (ticked: "no `Task.sleep`, no polling, no `confirmation` with a timeout anywhere in LauncherCoreTests"); `plan.md:1422` (the existing "within 5 seconds" bounds "are push paths with no timer").

**Why the finger count is the peak simultaneous count, and why 300 ms**

- **[Direct]** "Peak simultaneous" is R11's definition, written to resolve staggered lifts; the alternative it rejected was "count at the last lift", not "distinct fingers". Source: `plan.md:167` ("N is the largest number of non-thumb fingers simultaneously down during the tap"); `development-logs.md:5` ("Finger count for staggered taps ... unspecified → R11 defines N as the peak non-thumb finger count"); T12 `plan.md:1443` ("not the number down when the last lifts"); scenario `plan.md:213-216` (fingers "a few milliseconds apart" → exactly once). Both candidates sketched the same `peak = max(peak, ...)` (`candidate-2.md:310-314`). A grep for `distinct|simultaneous` across plan 001, its logs, both candidates, `design.md` and the glossary hits only R11 and T12: distinct-finger counting was never discussed.
- **[Direct]** 300 ms has no recorded derivation and was never tuned. Source: non-goal `plan.md:445` ("Fixed values, chosen to feel natural on common trackpads"); open question `plan.md:1399` ("Feel constants. 300 ms tap ... Should these be tuned once ... before they are frozen?"); S5 checklist `plan.md:1593` unticked ("any `GestureRules` tuning are written back into the design"); `candidate-2.md:279,954` proposed 0.35 s and called it a guess; the final plan took candidate-1's 300 with no reason recorded for 300 over 350. Plan 002 says 400 is likewise a first try: `plans/002-gesture-click-blocking/plan.md:237` ("The user chose to try 400 ms first").

**What plan 002 revokes, and what it leaves standing**

- **[Direct]** 002 enumerates its replacements: R11's finger count, duration and press rule; R20; and non-goal 446. Source: `plans/002-gesture-click-blocking/plan.md:17`. R21, R22, the push-only rule and the "time is data" decision are not on that list, and the 002 plan and log contain no occurrence of `R22`, `idle`, `timer`, `polling`, `clock` or `CPU` (grep, exit 1).
- **[Direct]** 002 keeps "a press cancels the tap" whenever clicks are not blocked. Source: `002/plan.md:158` (R8: "When clicks are not blocked, a press MUST cancel the tap, as today").

### What We Can Reasonably Infer

- **[Inferred]** The three mechanisms you are changing were chosen as a package to satisfy R20 and R22 together, so loosening one tends to press on the other. Reasoning: sampling exists because a tap was forbidden (R20, `plan.md:457`); it sits on the frame thread because the main-actor hop was rejected on cost (R22, `plan.md:1383`); and the result is a recognizer with no clock (R22, `plan.md:548`). Nothing states this coupling in one place; it emerges from the citations above.
- **[Inferred]** The zero-idle and no-timer rules remain in force for 002 unless the plan says otherwise. Reasoning: 002 explicitly lists what it replaces (`002/plan.md:17`) and R22 is absent; a plan that revokes R20 by name and is silent on R22 is most plausibly leaving R22 standing. This is an inference from an omission, not a statement.
- **[Inferred]** The glossary's "fingers that touched during the tap" wording (`docs/domain-model.md:18`, ccd4654) appears to be the drafter's intuitive definition, while R11 and the code encoded the narrower "simultaneously down" rule. Reasoning: both texts landed in the same commit, no text reconciles them, and 002 R1 now adopts the glossary's meaning. Whether the gap was noticed in 001 is not recorded.
- **[Inferred]** The S1 implementation dropped a field the plan sketched that 002's 3-second window would need: `Anchor.since: FrameTime` (`plan.md:727,752`), set but never read in the pseudocode and absent from `GestureRecognizer.swift:67-69`. Reasoning: it was removed as dead; it is not evidence that 002 was anticipated.
- **[Inferred]** Sampling evidently does catch real presses on hardware. Reasoning: 001 never observed `buttonState == true` (`index.md:29`) and the S5 hardware checklist is unticked, but 002's problem statement reports from use that "The press also cancels the gesture" (`002/plan.md:5`). That is a user observation, not a measurement.

### Competing Hypotheses

Only the 300 ms value admits more than one story; everything else has a single documented origin.

- **Hypothesis:** 300 ms is candidate-1's number, adopted by base selection rather than by argument.
  - **Evidence for:** candidate-1 was chosen as the base (`plan.md:1358`); candidate-2's 0.35 s is explicitly a guess (`candidate-2.md:954`); no sentence anywhere compares the two.
  - **Evidence against or missing:** candidate-1's own derivation of 300 is not in the parts of the record either investigator or I read; "chosen to feel natural" (`plan.md:445`) is the only stated basis.
- **Hypothesis:** 300 ms was meant as a conventional tap/hold boundary and expected to be tuned on hardware before release.
  - **Evidence for:** open question `plan.md:1399` asks exactly that; S5 reserved a write-back step (`plan.md:1593`).
  - **Evidence against or missing:** the step was never done, so no tuning data exists; 002 declines to record real taps (`002/plan.md:237`).

### What We Don't Know

- **Why peak over distinct.** No plan, log, candidate or doc considers distinct-finger counting; the only recorded contrast is peak versus "count at the last lift". The glossary contradicts R11 and nothing explains the mismatch.
- **Why 300 ms.** No derivation beyond "feel"; no hardware tuning recorded. The same is true of 400 ms in 002.
- **Whether a mouse press should spoil a trackpad tap.** R11 says "trackpad pressed down" (`plan.md:168`), but the sampler reads `.combinedSessionState` (`FrameStream.swift:39`), whose documented meaning is the session-wide combined state of all sources, so a mouse press reads as `buttonDown` today. No test or text covers an external mouse in 001; 002 R6 (`002/plan.md:126-127`) now says mouse clicks are never blocked and R8 says an unblocked press cancels.
- **How 002 will meet R7's "within 5 seconds" without a timer.** `002/plan.md` has no Design or Testing section. The in-progress probe `plans/002-gesture-click-blocking/.temp/architect/grounding/probes/ax-notify-probe/output.txt` recorded 0 hits, but its trigger failed (`tccutil` exit 64, "No such bundle identifier"), so the TCC row was never changed and the result says nothing about whether a push signal exists.
- **What an active tap does to `buttonState`.** `ax-tap-probe/main.swift:1-2` was written to check "whether a press DROPPED by an active session tap still shows in `CGEventSource.buttonState`"; `output.txt` shows it could not run (`AXIsProcessTrusted: false`; the active tap returned nil; a listen-only tap was created but `tapIsEnabled: false`). This directly decides whether today's `buttonDown` spoil path can coexist with R8.
- **Latency between a press and the frame that samples it.** Asserted as "a physical click's down state lasts longer than" a frame interval (`index.md:31`); never measured.
- **Whether the CGEvent timestamp and `FrameTime` ("monotonic seconds on the multitouch driver's clock", `Touch.swift:28`) are comparable.** Not addressed anywhere; relevant if the 3-second window is measured across the two sources.
- **Why `IOHIDManager` is a "permission" token.** Only inferable from R20 naming Input Monitoring; no sentence ties the token to a requirement.
- **Who to ask.** Every commit is by domasgru (you) with Claude as co-author; the rationale not written down lives in those planning sessions. PR #1 has no reviews or comments, `main` is at fe0e0d7, and there are no fix-for, revert or incident commits.

### Sources Consulted

- **Source control history**: all 11 commits on `feature/001-trackpad-launcher-app` (fe0e0d7..7c7f7c2) with full bodies (every body is subject plus trailer only); `git blame` on `GestureRecognizer.swift:31-52` and `docs/domain-model.md:17-18`; per-file logs for `docs/architecture.md`, `SourcePolicyTests.swift`, `GestureRules.swift`; `git diff` of 7c7f7c2 under `docs/`; investigator A's pickaxe on `buttonState|tapCreate|addGlobalMonitor|pressedMouseButtons|AXIsProcessTrusted|Input Monitoring|maxTapDuration|peak`; `gh pr view 1`; code comments in `GestureRecognizer.swift`, `GestureRules.swift`, `Touch.swift`, `FrameStream.swift`, `MultitouchSupport.swift:1-14`, `MultitouchTrackpads.swift:1-8`, `SystemTrackpadPreferences.swift:1-8`, `MenuBarShell.swift:70-84`; tests `SourcePolicyTests.swift`, `GestureRecognizerTests.swift:97-154`, `TouchScript.swift:7,62-91`, `InMemoryAdapters.swift:1-6`; `docs/architecture.md`, `docs/domain-model.md`, `docs/product-overview.md`.
- **Plans**: `plans/001-trackpad-launcher-app/plan.md` (problem, solution, R11, R12, R20–R22, non-goals, Design problem, decisions 1 and 9, `GestureRules` sketch, recognizer pseudocode, adapter sketch, ban list, test handles, synthesis, tradeoffs, alternatives, open questions, testing strategy, T10/T12/T15, S2 and S5 checklists); `development-logs.md` (all 60 lines); `.temp/architect/{task.md:18-24, rubric.md:8, candidate-1.md, candidate-2.md, grounding/index.md}`; `plans/002-gesture-click-blocking/plan.md` (all 241 lines), `development-logs.md` (all), `.temp/architect/grounding/probes/{ax-notify-probe,ax-tap-probe}/{main.swift,output.txt}`. Greps: `distinct|simultaneous` (plan 001, logs, candidates, design, glossary); `accessibility|input monitoring|TCC` (plan 001, docs); `r22|idle|timer|polling|clock|cpu` (plan 002 and log); `mouse|external|combinedSession` (plan 001). `research/` was not read.

### Constraint Set for Designing Plan 002

Derived from the findings above; each item cites the evidence it rests on. These are constraints and open checks, not a design.

**Preserve** (still in force after 002, by the record)

1. Zero idle CPU, push-only inputs, no timers, no polling. R22 (`001/plan.md:420`), `architecture.md:19`, grounding Q11. Not revoked by `002/plan.md:17`. If the 3-second window (R4) or the 5-second permission bound (R7) needs a timer, 002 must say so explicitly and amend the `timer`/`polling` entries; the only timer the record ever tolerated is the bounded device-readiness retry (`001/plan.md:1397`).
2. The recognizer as a pure function of frames, with time as data and synchronous tests. Decision 1 (`001/plan.md:548`), tradeoff `:1373`, testing strategy `:1420`, S2 checklist `:1551`. The precedent for feeding external state into recognition is `TouchFrame.buttonDown` as the test handle (`:1339`); a "press is blocked" fact should be able to enter the same way.
3. Recognition on the frame thread, only fired gestures hop to main, one writer per shared field, never-contended `Mutex`. `architecture.md:18`, `001/plan.md:548,1371,1383`, `SourcePolicyTests.swift:40`.
4. Accessibility only, used only to block clicks, no keyboard or other events, no Input Monitoring. 002 R9 (`002/plan.md:181`); `001/plan.md:605` ("No key-event monitors"). The `IOHIDManager`, `CGRequestListenEventAccess` and `CGPreflightListenEventAccess` bans still serve R9.
5. Fire on the last lift, no grace period. 002 R3 (`:58`), non-goal `:235`; 001 R11 "when the fingers lift".
6. A press cancels the tap whenever clicks are not blocked. 002 R8 last sentence (`:158`). The `buttonDown` spoil path and T10 stay, but gated.
7. Rules enforced by the scan test, not by prose. Decision 9 (`001/plan.md:556`), `architecture.md:23`, `SourcePolicyTests.swift:4-5`.
8. Mouse clicks, pointer and scrolling never blocked. 002 R6 (`:126-127`), non-goal `:233`.

**Change** (what the record says must move together)

1. R20 → R9: remove `AXIsProcessTrusted`, `tapCreate`, `CGEventTapCreate` from `banned`; rewrite `architecture.md:22`, which on HEAD contradicts `domain-model.md:57` (7c7f7c2 updated only the glossary); and revise or annotate `001/plan.md:9` ("asks for Accessibility ... gets uninstalled") and R12's "R20 wins" (`:230`), which 002 did not touch.
2. Peak → distinct: R11's "simultaneously down" becomes 002 R1 (`:22`); the glossary (`domain-model.md:18`) already says "touched during the tap" and can stand. T12 (`fingerCountIsThePeakNotTheCountAtTheLastLift`) cannot tell peak from distinct (all three fingers overlap at 100–120 ms), so the new rule needs the 002 R1 scenarios: lift-before-last-lands, five fingers never more than four at once, and a bouncing finger counted once.
3. 300 → 400 ms: `GestureRules.maxTapDuration`, T15's 290/310 rows (`:1446`), and the boundary-row technique (`:1422`). Both numbers are untuned "feel" constants (`:445,1399,1593`; `002/plan.md:237`).
4. Non-goal `001/plan.md:446`'s rationale ("keeps the app free of permissions") is voided by `002/plan.md:17`; the Tap-to-click-off requirement itself (R14) stays.
5. The sampler's role. Today `buttonDown` is both "a press happened" and "spoil". Under R4/R8 the recognizer must distinguish a blocked press (counts as a tap) from a passed press (cancels), which `CGEventSource.buttonState` may or may not be able to express (see Risk 2).
6. Restore the requirement labels on `banned` entries. The plan's sketch carried `R20`/`R22` (`001/plan.md:1325-1327`); the committed test dropped them, so the file no longer says which requirement each token serves. Changing the list is the moment to put that back.

**Avoid** (rejected or forbidden in the record; do not reintroduce by accident)

1. Hopping every frame to the main actor (`001/plan.md:1383`; `candidate-2.md:941`).
2. Threading or the hop inside `LauncherCore` (`001/plan.md:1384`); tests must stay synchronous (`:1551`).
3. An injected `Clock` or a tap-timeout timer (`:1389,1356`; `candidate-2.md:943`) unless R22 is explicitly relaxed.
4. Leaking recognizer state into the adapter (`candidate-1.md:848`).
5. `nonisolated(unsafe)` (`SourcePolicyTests.swift:40`).
6. Polling `AXIsProcessTrusted` for R7: it violates Preserve 1 and the existing `polling` ban, and the push-signal probe has not yet failed, it simply never ran (`ax-notify-probe/output.txt`, exit 64).
7. Key-event monitors or reading keyboard input (`002/plan.md:181`; `001/plan.md:605`).

**Risk** (thin or contradictory evidence; verify before committing to a shape)

1. **No push signal for permission changes has been found.** The only probe recorded 0 hits because `tccutil` rejected the bundle ID; it must be re-run with a LaunchServices-registered ID before concluding anything. Until then R7's 5-second bound has no permission-free, timer-free mechanism in the record.
2. **Does a press dropped by an active tap still show in `buttonState`?** `ax-tap-probe/main.swift:1-2` asks exactly this; it could not run. If yes, a blocked press would still set `buttonDown` and spoil the tap, contradicting R8, and the recognizer needs a different press signal. If no, the current spoil path is silently correct for blocked presses and only passed presses cancel. Either way the answer decides the recognizer's input.
3. **Cross-thread state.** R4 blocks only while the thumb is anchored, another finger is down, and under 3 s have passed since anchoring; that state lives on the frame thread (`architecture.md:18`), while a tap callback runs on its host run loop (`ax-tap-probe` logs the thread). The one-writer `Mutex` is the recorded shape for sharing; a callback that blocks on it risks `tapDisabledByTimeout` (the probe counts these at `main.swift:24`). No evidence either way.
4. **Two clocks.** The 3-second window starts at a frame-time event (`Anchor.since` existed in the plan sketch, `001/plan.md:727,752`, and was dropped in S1); a tap callback sees `event.timestamp`. Nothing in the record says whether these are comparable with `FrameTime` (`Touch.swift:28`).
5. **Mouse versus trackpad.** R11 says "trackpad pressed down" but the sampler is device-agnostic (`.combinedSessionState`), and 002 R6 and R8 need a per-device answer. Whether a tap callback can tell a trackpad press from a mouse press is not established anywhere.
6. **Idle cost of a tap.** R22 measures idle "while no finger is touching any trackpad"; a session-wide mouse tap wakes the process on mouse-button events from any device, anchored or not. The record does not address whether that is a "blip" or how the tap's enabled state would follow the frame thread.
7. **Nothing was tuned on hardware.** S5's checklist is unticked; 300 ms, 3 mm and now 400 ms rest on feel. Expect another timing iteration; 002 has already declined to record real taps (`:237`).
8. **Docs drift at HEAD.** `architecture.md:22` and the `permission` ban entries are already inconsistent with `domain-model.md:56-57` after 7c7f7c2; whichever slice lands the tap must change all three together or the build gate and the docs will say opposite things.

### Confidence Summary

The three "why"s are well-documented at the Direct tier: the press-spoils rule is R11 plus a Specify-phase gap closure; sampling exists because an event tap was forbidden by R20 and was placed on the frame thread for R22; the bans are the structural enforcement of R20–R22, with the no-permission motive authored in the plan rather than the user's brief; and "peak simultaneous" was written to handle staggered lifts without ever considering distinct-finger counting. The 300 ms value has no recorded basis beyond "feel", and the two questions that most affect 002's design, whether a TCC change can be observed by push and whether a dropped press still appears in `buttonState`, are open because both probes exist but neither has produced a result.
