# Why: the window swipe, the window switcher and the frontmost app's window read

### The Question

Why do the window swipe, the window switcher and the frontmost-app window read look the way they do? The question covers five things: (1) the read is synchronous, on the main actor, bounded at 0.2 s, applies only to the frontmost app, and is confined to its own file; (2) there is no window swipe below 2 windows, and the answer hops back to the frame thread; (3) the list order, the cap of 10, and how lift reorders; (4) the model keeps no window state, and the list and row are fixed at begin; (5) icons are pre-drawn, running apps are read at begin, layout types live in Core, and the selected icon grows. This is groundwork for plan 042: asynchronous stack counts for up to 10 apps, a per-app window order kept in the model, and a window swipe even with 0 or 1 windows.

### The Code in Question

- `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift`: the `@MainActor` reader and raiser. It holds `messagingTimeout = 0.2`, `listed` and `isUnanswering`.
- `LauncherKit/Sources/LauncherCore/Ports.swift` ~126-138 (`frontmostWindows()`, `raiseWindows(_:)`). `Launcher.swift` ~370-405 (window swipe start, confirmation, lift, hide-others). `WindowSwitcher.swift`, `WindowLift.swift`, `WindowSwipeConfirmation.swift`, `WindowColumnLayout.swift`, `Switcher.swift`, `SwitcherRowLayout.swift`.
- Most of the shape comes from plan 012 (PR #15, squash 18acef7). That includes a mid-PR "change 1" that reversed the human's original brief. Earlier precedents come from plans 006, 008 and 009. Plans 013, 017, 021, 023, 025 and 032 refined it.

---

### What We Found

#### Q1. Synchronous main-actor read, 0.2 s timeout, no raises after a timeout, confinement, only the frontmost app

- **[Direct]** The synchronous main-actor read was an explicit trade, made for a synchronous model and synchronous tests. Source: `plans/012-window-switcher-gesture/plan.md` Tradeoffs accepted (:1431-1435), verified: "We accept AX calls synchronously on the main actor (about a millisecond to read, about 2 ms per raise), bounded by a 0.2 s process-wide messaging timeout with no further raises to an app after its first timeout, in exchange for a synchronous model and model tests with no held reads. An app that hangs mid-swipe can stall the main actor for up to 0.2 s at the raise that meets it and again at the lift's read…"
- **[Direct]** An async read and a background-queue raise were both considered and rejected. Source: 012 plan.md Alternatives considered (:1506-1508), verified: "**Raises on a serial background queue, or an async window read.** The main actor would never wait on another app, but the model would gain a loading state and a lift that can arrive before the read lands. For a read of about a millisecond, bounded timeouts instead." The candidate designs give the same reasons in more detail. Candidate-3 (:932): an async port "exposes a loading state to the model and the shell … for a 1 to 2 ms read it moves complexity onto callers instead of hiding it". Candidate-1 (:831-833): "the lift's haptic needs the outcome, so the model would have to wait or decide late, and it adds ordering and cancellation states."
- **[Direct]** Reading on the frame thread was also rejected. Source: 012 plan.md (:1509-1513), verified. The frame thread "would make AX calls into another app, waiting up to the 0.2 s timeout with every trackpad's recognition stalled". The rejection lists two more costs: raise handles shared across threads, and the frame thread breaking its promise never to wait.
- **[Direct]** The rule that only ids from the latest read are raisable exists so that nothing on another Space is raised. Sources: `Ports.swift` `raiseWindows` doc ("an id the latest read did not list is skipped, so nothing on another Space is ever raised"), `FrontmostAppWindows.swift` `listed` doc, and 012 grounding F24 ("raising a window on another Space switches Spaces. Never raise an unlisted window"). Commit ffa025d introduced it.
- **[Direct]** The process-wide timeout came out of a review finding. Source: 012 `development-logs.md` Plan :24: "the AX messaging timeout was set on the app element only → set once on the system-wide element, process-wide per `AXUIElement.h`." Plan 017 later gave `LaunchWatch` its own per-element 0.2 s timeout "so the bound does not depend on `FrontmostAppWindows` having set the process default first" (`plans/017-launch-wait-bounce/plan.md` :442).
- **[Direct]** The value 0.2 s was never settled. Candidates 2 and 3 proposed 0.1 s and candidate 1 proposed 0.2 s. The final plan kept 0.2 s and recorded open question 5 (012 plan.md :1546-1548, verified): "Is 0.2 s the right AX messaging timeout? Apps whose accessibility tree wakes on the first query (Chromium, O5) may read as having no windows on the first slide down…"
- **[Direct]** The timeout has no automated test, by decision. Source: 012 dev log Plan :35: "faking the AX calls would test our model of the API, not the API". Manual check M18 covers it instead.
- **[Direct]** The confinement applies the repo's one-API-one-adapter policy. It is now two files, not one. Sources: in 012 plan.md :1317-1325, `AXUIElement` and `CGWindowList` were confined to `FrontmostAppWindows.swift` ("the window read has one reader", a09ddfa). Plan 017 / PR #21 (a068ed5) widened this. The current `SourcePolicyTests.swift:172-173` (verified) reads `onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers"`. **The question's premise ("one file") is out of date.**
- **[Direct]** The only commit that mentions "concurrent off-main work" for this file (92914eb) does not move the read off the main actor. It only turns the ~50 ms window-list warm-up from GCD into `@concurrent` (why-git item 5). No plan or commit ever made `frontmostWindows` async (`git log --all -G 'frontmostWindows\(\) async|…windowCount'` found nothing).
- **[Direct]** Only the frontmost app is read because other apps' windows were a non-goal, and raising depends on the app being frontmost. Sources: 012 plan.md Non-goals (:371, verified): "**Windows of other apps.** The window swipe stays within the frontmost app; the swipe reaches other apps." Also :377 (hidden apps) and :370 (other Spaces: "Reaching them makes macOS switch Spaces"). Plan 021 decision 8 (:497, verified): "while Trackpad Launcher is active a slide up or down is no window swipe, because raising windows needs their app frontmost (F29)."
- **[Direct]** The Accessibility permission's stated uses name only the frontmost app's windows. Source: `docs/architecture.md:25` (verified): Accessibility is used "to list the frontmost app's windows when two fingers start sliding up or down under the thumb, to raise and restore them during a window swipe, and to notice the first window of an app a gesture is launching…"

#### Q2. Window swipe only with 2+ windows; the answer hop

- **[Direct]** The human's original brief asked for the opposite: a switcher even with one window. Source: 012 `.temp/architect/task.md` :58-62 (verified): "If app does not have multiple windows, the windows switcher still should be shown so you are sure that the feature is working, but it should just not switch apps and indicate only once screen." Slices S1-S4 built this as a "No open windows" or "Allow Accessibility to switch windows" message row.
- **[Direct]** The human then reversed it inside the same PR ("change 1"). The record says what changed, not why. Sources: 012 dev log "Specify (change 1)" :56 (verified): "Human: no window swipe and no switcher when the frontmost app has fewer than two windows, no frontmost app, or no Accessibility … the slide behaves as with the setting off." The owner's comment on PR #15 (verified) repeats the rule. Commit a88b1c3 removed `Copy.noOpenWindows`, `Row.message`, `.noWindows`, `.accessibilityNeeded` and the single-row full-screen case. The PR #15 body still says "One window or none still shows the switcher" and was never edited.
- **[Direct]** The rationale phrases that do appear: "only when there is something to switch to" (012 plan.md Solution :11; `docs/domain-model.md:93`) and, for a lone minimised window, "One window is nothing to switch between; the Dock restores it" (012 Non-goals :380, verified).
- **[Direct]** Scrolling is what the window swipe costs, and change 1 keeps scrolling for apps with fewer than two windows. Source: 012 plan.md Tradeoffs :1462-1464 (verified): "two fingers sliding up or down under an anchored thumb over an app with two or more windows no longer scroll after the blocking window … Over an app with fewer, they scroll as before (R13)." The grounding's Risk 1 called vertical-scroll suppression something that "Needs a product decision, not a default."
- **[Direct]** The answer hops back to the frame thread because the 2+ verdict needs the window read, which only the main actor does, while the frame thread decides blocking frame by frame. Sources: `docs/architecture.md:18` (verified): "One thing hops back: the model's answer to a window swipe's start … which only the main actor can tell because it reads the frontmost app's windows". 012 plan.md Design Problem (:395-399) and the load-bearing decision (:605-625). Dev log :65.
- **[Direct]** Each piece of the hop's shape answers a rejected alternative (012 plan.md :1509-1528, verified):
  - A pushed window count was rejected: no push exists for full-screen or Space moves, Chromium/Electron observers are unreliable, and the count could disagree with the rows.
  - Reading when the finger pair lands was rejected: the pair may rest for seconds, and every tap would pay a read.
  - Starting blocked and releasing on a decline was rejected: "the scroll filter never relaxes a scroll it has stilled".
  - Returning the answer from `onEvent` lost "narrowly".
  - The unconfirmed slide blocks only by the thumb rules "so a declined slide is exactly the setting-off slide" (dev log :65).
- **[Direct]** `WindowSwipeConfirmation` lives in `LauncherCore` so that both adapters share one copy of the reply bookkeeping. Source: 012 dev log :67, plan-reviewer W1: "the main-actor reply bookkeeping written twice (real and in-memory adapters), checked only by review → one `WindowSwipeConfirmation` in `LauncherCore` both adapters use". Moving it out was explicitly declined (dev log :87).
- **[Direct]** The rows and the verdict come from one read so that "the count that decides is the count the user sees (R1)". Source: 012 plan.md Tradeoffs :1474-1476 (verified).
- **[Direct]** The hop was an intentional, narrow exception to an earlier rule. The 012 grounding's Preserve 3 said "No main-to-frame channel", and "Deliberately not done" (:690, verified) narrows it to "No main-to-frame channel beyond the one answer per window swipe start."

#### Q3. Order, cap of 10, lift reorder

- **[Direct]** The order is a requirement. Source: 012 R3 (:65): "MUST list the visible windows front to back, the front window first, then the minimised windows in the order the app lists them, and cut the list at 10." Visible windows are ordered by the window list (CG on-screen order) because "AX order follows z-order, but no source documents it; CG on-screen order (F11) is the documented one" (grounding F8, O7). Minimised windows have no z-order, so they follow the app's AX order. They are recognised by `kAXMinimized` because they report `AXDialog` (F9).
- **[Direct]** The lift reorder implements a "toggle between the last two windows" scenario. Source: 012 R11 and its scenario (:214-219, verified): from "Docs","Mail","News", sliding to "News" and lifting makes the next swipe read "News","Docs","Mail". The toggle works without model memory because the next read gets the order back from the window server. 012 plan.md :1309-1313: "a second window swipe sees the first one's order (R11's toggle scenario)".
- **[Direct]** The lift is a pure plan computed from a second read, so it never depends on what the raises during the slide did. Source: 012 plan.md Design :648-655 ("per make-operations-idempotent; Risk 4"). Rejected alternatives: a full re-stack on every lift (up to 11 raises; candidate-3 :937), and `stack(order)` inside the adapter ("Lost on locality", :1494-1496). Commit 50c9c9f later fixed a window minimised mid-swipe being restored (dev log :89).
- **[Direct]** Plan 032's hide-others is tied to the lift's haptic flag. Source: `plans/032-hide-background-apps/plan.md` :316. Verified in code: `Launcher.swift:403` calls `if lift.playsHaptic { hideOtherApps(…) }`.

#### Q4. No window state across swipes; fixed at begin

- **[Direct]** "No window state in the model between window swipes" is listed under "Deliberately not done". Source: 012 plan.md :690-693 (verified).
- **[Direct]** That rule descends from plan 008's pull-don't-store rule for running apps. Sources: 008 decision 1 (:262): "The read is a pull at the moment it is needed (a swipe's begin and end), never stored: the order changes with every activation and LaunchServices is its one source of truth." 012 grounding Preserve 5 / Avoid 9 carried it over: "storing window state in the model between swipes (008 decision 1)".
- **[Direct]** The rule that the list is fixed at begin is a requirement. Its rationale was never written down. Sources: 012 R3; `WindowSwitcher.swift` doc; 008 R5 / 006 R4 for the app row. The 012 grounding (`why.md` :124-127) already marked both candidate reasons ("stability under the fingers"; "a consequence of 'the model keeps none of it'") as Speculative.
- **[Supported]** The model is not stateless on principle. Plans have held state when a requirement forced it. Evidence: plan 009's `SwapSeries` remembers the last swap of a series (009 decision 7); plan 008's fallback `ActivationTracker` keeps a recency list (008 dev log); plans 017/032 keep a `WatchedLaunch`. On the other side, plan 021 rejected an activation memory as "an extra observer and state" (:1049, :1058).

#### Q5. Icons pre-drawn, running apps at begin, layout types in Core, selected-icon grow

- **[Direct]** Icons are drawn ahead of time because a cold draw is too slow for a gesture. Source: 008 Implementation Decisions preamble (:260): "a cold row of 14 would stall 350 ms if drawn at the swipe". Decision 9 (:286) and 006 :491 add that 80 pt icons take "up to 220 ms to draw cold". `docs/architecture.md:19`: "Work that would delay a click … runs off the main actor in explicitly concurrent functions."
- **[Direct]** Running apps are read from LaunchServices at begin and again at lift, because the order changes with every activation and LaunchServices is its one source of truth (008 decision 1 :262; decision 4 :276). The read is cheap: 1.4 ms warm, under 4 ms cold (008 :260, :348).
- **[Direct]** The layout types live in `LauncherCore` for three reasons: the icons/rows and the highlight are placed through one tested value so they "cannot drift apart" (008 decision 10 :288; 012 :951-954); `LauncherUI` had no test target (013 Strategy); and both modules read them (023 D1 :244).
- **[Direct]** The switcher's enlarged selected icon (1.12×, 0.12 s transform) comes from plan 006 R10 ("the selected icon drawn slightly larger"). Plan 013 R2 kept it unchanged. **Plan 023 is not about the switcher.** It is the settings-window app picker's "pick animation" ("Nothing marks the moment, so the pick feels flat", 023 :5), built from one Core Animation keyframe on a layer it owns, with the model transform left at identity so "nothing to clean up" (D3). The question attributes it to the wrong feature.

---

### What We Can Reasonably Infer

- **[Inferred]** The main reason plan 012 gave against an async read ("for a read of about a millisecond") likely does not carry over to plan 042's multi-app read. Reasoning: 012 judged that an async port "hides nothing" because one read costs ~1 ms. Ten apps, each bounded at 0.2 s, could block the main actor for up to ~2 s in the worst case. That moves the cost/benefit balance 012 used. The other two reasons 012 gave (a loading state in the model and shell, and a lift that can arrive before the read lands) still appear to apply, and plan 042 would need to answer them.
- **[Inferred]** A human-written 0.2 s per-app deadline outside the AX call would be a new kind of mechanism. Reasoning: 012 Testing Strategy :1604 (verified) says "The design adds no timer or poll; its one deadline, the AX messaging timeout, lives inside the system call". The messaging timeout bounds *each call*, not each app. A read of one app is several calls, so "0.2 s per app" is not what the current timeout already gives.
- **[Inferred]** No Accessibility call in the codebase has ever run off the main actor. Reasoning: `FrontmostAppWindows` and `LaunchWatch` are both `@MainActor` (verified, `LaunchWatch.swift:16`), and the only off-main work is the window-list warm-up. Nothing in the record shows whether `AXUIElement` calls are safe from a background executor. That would be new ground.
- **[Inferred]** Change 1 may have been motivated by keeping scrolling under the thumb for apps with fewer than two windows, or by the 0/1-window message rows feeling noisy once the feature was proven. Reasoning: the tradeoff text at :1462-1464 explicitly keeps scroll for "an app with fewer". The original brief wanted the 1-window switcher "so you are sure that the feature is working", which is a verification motive. Neither reason is stated as the human's. See Competing Hypotheses.
- **[Inferred]** A model-held per-app window order would be the first window state in these switchers. It would also be the first switcher order not re-read from a system source of truth. Reasoning: 008 decision 1 and 012 "Deliberately not done" both rely on the system being the source of truth. The R11 toggle currently gets the order back from the z-order.
- **[Inferred]** The comment at `Launcher.swift:17`, "it always shows", is a leftover from before change 1 (a09ddfa). Plan 042 would make it literally true again.

### Competing Hypotheses

Why did the human reverse the 0/1-window switcher (change 1)? This matters most for 042, which reverses it back.

- **Hypothesis A: keep scrolling under the anchored thumb for apps with nothing to switch to.**
  - Evidence for: 012 Tradeoffs :1462-1464 contrasts "two or more windows no longer scroll" with "Over an app with fewer, they scroll as before". The grounding's Risk 1 flagged vertical-scroll suppression as needing a product decision.
  - Evidence against or missing: the human's dev-log entry (:56) gives no reason. The tradeoff text could be a consequence the planner wrote down after the decision rather than the cause.
- **Hypothesis B: a switcher with nothing to switch to was noise once the feature was known to work.**
  - Evidence for: the original brief justified the 1-window switcher only "so you are sure that the feature is working". The domain model calls the swipe something that exists "only when there is something to switch to".
  - Evidence against or missing: nothing records the human saying this.
- **Hypothesis C: one read, one count, no message rows.** On this reading, change 1 simplified the switcher: message rows, the Accessibility-needed row, and the full-screen single row were all removed.
  - Evidence for: a88b1c3 removed all of these together.
  - Evidence against or missing: the 2+ rule *added* the confirmation hop. That cost more complexity than it saved, so simplicity was probably not the driver.

### What We Don't Know

- **The human's reason for change 1.** Searched: 012 dev log (full), plan.md Solution/R13/Tradeoffs, slice S6, PR #15 body and comments (no reviews), and commit b3af55c ("Plan: window swipe only for apps with two or more windows", no body). Only the rule is recorded. Only the author (domasgru) can answer this. It is the single most important question for 042, which goes back toward the original brief.
- **Why 0.2 s rather than 0.1 s.** Open question 5 was never answered. Dev log: "Open questions 14–17 kept at the plan's defaults".
- **Why the cap is 10** (both the window cap and the app cap). Searched plans for `switcherMaxApps|at most 10|cut at 10|ten rows|windowSwitcherMaxRows`, and searched git for 8de1e32's message. Only "the frontmost app and the 9 most recently used others" was found.
- **Why the list and row are fixed at begin.** No rationale is recorded anywhere. The 012 grounding already labelled both hypotheses Speculative.
- **Whether AX calls are safe or fast off the main actor or concurrently across apps.** No probe exists. 012 probe-2 timed AX on one app. O5 notes that what Chromium/Java apps return on a first query was never probed. Nothing measures a multi-app read; the `docs/performance.md:51` figure is for the single-app read.
- **How AX behaves for windows of non-frontmost or hidden apps, or windows on other Spaces.** F10 says a window left on another Space "disappeared from `kAXWindowsAttribute`". Nobody probed whether a background app's window count is accurate. That matters for "off-Space windows keep their place".
- **Why the window swipe became off by default** (4428446). The commit gives no reason.
- **Leads not followed by either investigator:** `plans/012-window-switcher-gesture/.temp/architect/grounding/probes/probe-2-ax-windows.*` and `probe-5-spaces.*`; `plans/017-launch-wait-bounce/.temp/architect/grounding/` (F16-F19, AX observers and window counts for a non-frontmost app being launched); `plans/021-…/grounding/how-activation.md` §F (F29); and commit 8acaea8 ("Gestures stay on without Accessibility"), which has no plan.

### Sources Consulted

- **Source control history:** full main `git log`. `--follow` on FrontmostAppWindows/SwitcherRowLayout/WindowColumnLayout/Switcher. The pre-squash branches `origin/feature/012-window-switcher-gesture` (12 commits), 008, 025, and `backup/025-full-blocking`. `git show` on ~22 commits (18acef7, c5f9ffd, a09ddfa, ffa025d, 92914eb, b3af55c, 8c3f56f, fc2e216, a88b1c3, 50c9c9f, 7bcb68d, 9557bc2, a068ed5, b67a5ca, 6405d49, 97abf50, 8de1e32, 4428446 and others). PRs #11, #15, #16, #17, #19, #33, #41. Pickaxe on the key doc sentences, plus `--grep` for deadlock / main actor / off-main / concurren / timeout / hang. Tests: SourcePolicyTests, WindowSwipeNeedsTwoWindowsTests, WindowSwitchingTests, WindowSwipeAnswerTests, DeviceSessionAnswerTests, FrontmostAppWindowsTests. Docs: architecture, domain-model, product-overview, performance.
- **Plans:** 012 (plan.md in full, dev log, `.temp/architect/` task, grounding why/index, candidates 1-3, synthesis, slices). 008 and 013 (plan and dev log). 023 (plan and dev log). 025. 015. Parts of 006, 009, 021 and 032. Greps across all plans for window swipe / frontmostWindows / messaging timeout / WindowSwipeConfirmation / WindowColumnLayout / AXUIElement / cap-10 / selected-icon scale.
- **Spot-checked by the synthesizer:**
  - 012 plan.md :368-381, :688-694, :1429-1436, :1460-1476, :1504-1530, :1546-1548, :1604, :214-219
  - 012 dev log :54-67; 012 task.md :56-63
  - 008 plan.md :260-262, :286; 021 plan.md :497
  - `SourcePolicyTests.swift:172-173`; `Ports.swift:127-138`; `FrontmostAppWindows.swift:10-23`
  - `Launcher.swift:17, 375, 399-403`; `LaunchWatch.swift:16-17, 100`; `docs/architecture.md:18-19, 25`
  - PR #15 owner comment

  All matched what the investigators reported.

### Confidence Summary

> The core rationale is well-supported by direct plan evidence: a synchronous main-actor read was a deliberate trade, an async read was considered and rejected, only the frontmost app is read because other apps were a non-goal and raising needs the app frontmost, the answer hop exists because only the main actor can read windows, the list order and lift reorder are explicit requirements, and the model keeps no window state by deliberate choice. What is not recorded: the human's reason for removing the 0/1-window switcher (change 1), the choice of 0.2 s, the cap of 10, and the "fixed at begin" rule. Nothing in the record says whether concurrent or off-main AX reads of background apps are safe or accurate.

---

## Constraint set for plan 042

### Preserve

1. **Nothing on another Space is ever raised.** Only ids from the latest read of that app may be raised (`Ports.swift` `raiseWindows`; grounding F24). A model-held order that keeps off-Space windows "in their place" must never pass them to `raiseWindows`. 012 also excludes them from the list because "Reaching them makes macOS switch Spaces" (Non-goal :370).
2. **Raising stays a frontmost-app operation.** `kAXRaiseAction` "relies on the app already being frontmost" (021 F29, decision 8). Stack counts for other apps are display only.
3. **A declined slide is exactly the setting-off slide**, along with the unconfirmed-slide blocking that plans 014/016 build on. This applies wherever a slide is still declined, such as no Accessibility (R14) or the setting off.
4. **The lift is computed from a second read at lift time.** It does not depend on what the raises during the slide did (Design :648-655, Risk 4). The shortest-prefix `WindowStack.raises` rule and the fix from 50c9c9f (a window minimised mid-swipe stays minimised) also stay.
5. **A lift that changes nothing is silent and has no side effects.** The "no other windows" card's lift must have `playsHaptic == false` so that 032's `hideOtherApps` does not fire (`Launcher.swift:403`).
6. **The frame thread never waits and never makes AX calls** (012 :1509-1513). The main actor is never blocked by the switcher (architecture.md:19, "Work that would delay a click … runs off the main actor").
7. **One API, one owning adapter.** Any new AX/CGWindowList reader must be in the `Confined` table (`SourcePolicyTests.swift:172-173`). Preferably it stays inside `FrontmostAppWindows.swift` or `LaunchWatch.swift` rather than a third file.
8. **Self-exclusion.** Trackpad Launcher's own process is never read (7bcb68d; 025).
9. **Geometry stays a pure, tested value in `LauncherCore`** that both the icons/rows and the highlight are placed through (008 decision 10; 013). Stack offsets belong there too.
10. **Icons are ready before any swipe** (008 decision 9). Stack visuals must not add a cold draw on the swipe path.

### Change (knowingly reversing recorded decisions)

1. **"No window state in the model between window swipes"** (012 :690). A per-app window order is the first model-held order in these switchers and departs from 008 decision 1's "LaunchServices/the system is its one source of truth". Update the domain model and architecture docs, and record the trade explicitly.
2. **The 2+ rule (change 1), which the human chose but never explained.** Going back toward the original brief (task.md :58-62) gives up scrolling under the anchored thumb over 0/1-window apps while the setting is on (Tradeoffs :1462-1464). Confirm with the author that this is intended. Tests that encode the 2+ rule will need rewriting: `WindowSwipeNeedsTwoWindowsTests` (both tests), `aWindowThatOpensMidSlide…`, and parts of `WindowSwipeAnswerTests`. So will scenarios in 015, 021 ("no window swipe while Trackpad Launcher is active"), 025 ("no window switcher … over the settings window") and 028.
3. **"Async window read" was rejected in 012 (:1506-1508).** Plan 042 has to address both stated reasons: (a) a loading state in model and shell, and (b) a lift/end arriving before the read lands. It should also say why the "~1 ms" premise no longer holds for up to 10 apps.
4. **The Accessibility use statement** (`docs/architecture.md:25`, "to list the frontmost app's windows") must widen to cover reading other running apps' windows, together with any user-facing permission text.
5. **The answer hop's meaning.** If every slide up/down becomes a window swipe (subject to Accessibility), the verdict may no longer depend on a window count. Decide whether the hop and the unconfirmed state stay, and for which cases: no Accessibility, no frontmost app, full-screen front window, self frontmost.

### Avoid

1. **AX calls on the frame thread**, and AX handles shared across threads (012 :1509-1513).
2. **Blocking the main actor for a multi-app read.** Ten sequential 0.2 s timeouts could stall it for about 2 s.
3. **Letting a background count gate whether the swipe is a window swipe or what the lift does.** That would bring back the "lift before the read lands" race 012 rejected.
4. **Pushed window counts from AX observers.** 012 rejected them as unreliable for full-screen/Space changes and Chromium/Electron (:1514-1518).
5. **Re-ordering the list or row mid-swipe** (012 grounding Avoid 9). Stack counts that arrive late should not move rows.
6. **Treating the 0.2 s AX messaging timeout as a per-app deadline.** It bounds each call. A per-app deadline is a new timer the design needs to own and test (012 Testing :1604, "adds no timer or poll").
7. **Changing the process-wide messaging timeout** without checking `LaunchWatch`, which sets its own per element (017 :442).
8. **Relying on `Launcher.swift:17` "it always shows" as evidence of current intent.** It is a pre-change-1 leftover.

### Risk

1. **AX thread safety and concurrency are unknown.** No AX call in the codebase runs off the main actor. Concurrent per-app reads need a probe first.
2. **Accuracy of background apps' window counts is unprobed.** Hidden apps, other-Space windows (F10: they disappear from `kAXWindowsAttribute`), and apps whose AX tree wakes on the first query (O5, Chromium/Java) may show a wrong count, or 0 on the first swipe.
3. **The model order can drift from reality.** Windows the user reorders by clicking or ⌘-`, windows that move Space, and windows that go full screen will not match a remembered order. "Selection starts on the front window's row" may then not be row 0. The lift rule (selected, then front, then the rest) and the silent front-window lift (R11) need restating against the remembered order.
4. **Window identity across reads.** `WindowID` comes from private `_AXUIElementGetWindow`, with a frame-and-title fallback. A per-app order held for the life of the app depends on ids staying stable, and the fallback path may not keep them stable.
5. **Scroll regression.** Making 0/1-window slides into window swipes removes scrolling under the thumb for those apps. The reason the human chose change 1 is unknown, so the author should confirm this.
6. **Memory and lifetime** of per-app order state: it must be cleared on quit, and it must not grow without limit.
7. **Plans that depend on the old behaviour:**
   - 014/016 depend on the unconfirmed-slide blocking.
   - 032 depends on the lift haptic.
   - 021 and 025 depend on "no window swipe over Trackpad Launcher".
   - 015 and 028 depend on scenario preambles.
   - The tests listed in the source-control findings will need changes.
