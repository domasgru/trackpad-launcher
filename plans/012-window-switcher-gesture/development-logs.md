# Development logs: Swipe up or down to switch windows

## Specify
- prd-reviewer: two-finger tap regression unscenarioed → R1 scenario "A tap that drifts stays a tap".
- prd-reviewer: full-screen front window undefined → R3/R4 show it as the single row; lift changes nothing.
- prd-reviewer: all-minimised app undefined → R11 selection starts on the first row; lifting restores with the gesture haptic; R10 notes sliding back changes nothing.
- prd-reviewer: thumb lift mid-swipe undefined → R15 says it changes nothing; rejoin and click-cancel scenarios added.
- prd-reviewer: R11/R12 contradiction on a closed window → R12 has one observable haptic rule; R11 rewritten to match.
- prd-reviewer: "gestures are active" vs Accessibility → R1 points to the glossary term; R14 notes scrolling is not blocked without Accessibility.
- prd-reviewer: preview timing ambiguous → R6 shows the switcher at once, previews fill in, icon until ready.
- prd-reviewer: R8 button state invisible → first press asks, later presses open System Settings; scenarios added.
- prd-reviewer: R7 relaunch → "after any relaunch macOS requires".
- prd-reviewer: missing scenarios (upgrade, shrink-to-fit, static preview, focus on lift) → added to R16, R5, R6, R11; R10 gives focus while sliding.
- prd-reviewer: vague sizes → 60 pt tall, at most 120 pt wide.
- prd-reviewer: R9 start distance, R3 minimised order, R13 no-frontmost icon, R14 title, R17 observability, docs paths, terminology, Problem statement and Non-goals → each applied as suggested.

## Plan
- Arena resumed after the first architect run (Fable) stopped on a quota error → its grounding, task, rubric and candidate-2 (Fable) reused; the missing runner, the cross-judge and the test planner ran on Opus, as the human asked.
- Arena dropout that was not one: the first run's Opus runner wrote candidate-1 after its architect stopped, and this run's Opus runner then overwrote that path → judged candidate-1 restored verbatim, the late package kept and scored as candidate-3; the judge running on the same model as candidates 1 and 3 was checked by my own criterion-by-criterion pass.
- Red-flag screen, candidate-1: R11's closed and minimised rules lived in the adapter's `stack` contract and again in its fake → the lift became a pure `lift(now:)` over a second read in the model (from candidate-3); the fake only emulates `AXRaise`.
- Red-flag screen, candidate-2: `WorkspaceActions` pass-throughs and previews relayed through the model as state no decision reads → previews stay a shell asset (candidates 1 and 3); the two window methods still sit on `SystemActions` (Preserve 7), delegated to one platform type.
- Red-flag screen, candidate-3: the all-minimised case as an optional front window and per-row flags → candidate-1's `.front` / `.minimisedOnly` variants and `Row` enum.
- Cross-judge, first verdict (candidate-1 12, candidate-2 11): keep previews in the shell per plan 008's icon decision → adopted, reversing my first draft's graft of candidate-2's capture port.
- Cross-judge: the AX messaging timeout was set on the app element only → set once on the system-wide element, process-wide per `AXUIElement.h`.
- Cross-judge: candidate-2 lacked R3's full-screen rule and its World test contradicted its own lift → neither carried.
- Cross-judge: a lift with no window in front was undecided → silent.
- Cross-judge: read the Screen Recording grant fresh at each begin → rejected: the preflight costs about 4 ms on the calling thread (check-1); the model gates on the grant the TCC push leaves, and the judge agreed.
- Cross-judge, second verdict after scoring candidate-3 (13): base candidate-3 → candidate-1 kept as base for its types and its `.windowSwipe` event (78 bare `.began` uses untouched); candidate-3's lift, `SystemActions` placement, adapter seams, preview geometry and encoder bans grafted.
- Candidates 2 and 3 changed the gesture hint and candidate-3 closed the window on the ask → dropped; no requirement asks.
- Verify: the source scan reads comments, so a core doc comment naming a confined API would fail it → stated in the design.
- Verify: the usage chained two `World.windowSwipe` calls, whose second hand `World.play` would drop as older frames → the second window swipe continues the first script.
- Verify: `WindowStack.raises` checked against R10–R13 with an `AXRaise`-like stack (check-2) → all pass; a window opened mid-swipe ends just behind the selected one, recorded as open question 4.
- Verify: `docs/architecture.md` still placed ScreenCaptureKit in `LauncherPlatform` after the previews decision → moved to `LauncherUI`.
- test-planner: a platform test of `FrontmostAppWindows` over the test process's own windows could never run (the read skips this process, and raises would reorder the developer's windows) → dropped from the design's seams; real AX behaviour stays with M10, M11 and M18.
- test-planner: the AX messaging timeout has no test handle → rejected: faking the AX calls would test our model of the API, not the API; `FakeWindows.answers` is the high seam's handle and M18 checks the real timeout; open question 13 for the human.
- test-planner: the preview-capture race has no test handle → rejected: accepted tradeoff, no `LauncherUI` test target by precedent; M16 and M17 check it.
- test-planner: R15's "Click reaching apps cancels" cannot happen on hardware (raises need Accessibility, which blocks every press) → requirement left as written, open question 12; the cancel rule is tested through T10, T35 and T56.
- test-planner: `WindowStack.raises` did not say its order is relative → doc comment states it, and where a window opened mid-swipe lands (T52).
- test-planner: `WindowColumnLayout` did not define "fits" → the panel plus `margin` above and below within the visible height (T13).
- test-planner: T47(c), T49(b) and T52(b) rest on unanswered readings of R11 and R13 → open question 4 states the "front-window lift restores the order" reading and names the rows that flip.
- test-planner, second pass: no new findings; T49's source now cites open question 4.

## Implement
- No `AGENTS.md` in the repo → quick gate taken as `Scripts/test.sh`; full gate as a clean `Scripts/test.sh` plus `xcodegen generate` and a Debug `xcodebuild` of the app. No `.claude/skills/verify-*` → verification-skill step skipped.
- S1 committed (f4590b1). Departure: `beginOrSpoil` held a temporary `kind == .swipe` stop-gap until S2 added the event; removed in S2.
- S2 committed (a09ddfa). Departures: T4's exact tie uses a 128 × 64 mm test surface (the MacBook's fraction round-trip never ties exactly); `FakeWindows.set` takes `untitled:` since ids are keyed by name; the vertical `ScrollSuppressionTests` rows now turn the window swipe off to keep pinning today's behaviour.
- S3 committed (ffa025d). A hung app mid-swipe can cost a second 0.2 s timeout at the lift's read → kept: the plan's Tradeoffs accept a stall "at the raise that meets it and again at the lift's read".
- S4 committed (ae4354e). `@preconcurrency import ScreenCaptureKit` needed for Swift 6; no Info.plist key needed for capture.
- Full gate after S4: green (473 tests, app builds).
- implementation-reviewer (against origin/main; local `main` is stale): no requirement missing or wrong, every T row has a test.
- Fixed: off-main warm-up and preview capture moved into `@concurrent` functions (architecture.md Concurrency, "explicitly concurrent functions"); the window-number fallback now also covers a window whose private lookup fails (plan adapter step 4); panel row count from `GestureRules.windowSwitcherMaxRows` (made `package`); unused `present(animated:)` and `OverlayAppear.fade` removed; T53's name says what, not how; T19 asserts no read before the crossing frame directly.
- Declined: count assertions on `reads`/`raised` (the plan's named test handles); `Swipe*` naming and the two event cases (plan decisions, alternatives rejected); small duplication and naming smells (`.moved`/`.cancelled` branches, stretch spring, `look:` parameter, size tuples, `emptied()`, `dismissFade`).
- Full gate after fixes: green (473 tests, app builds).

## Specify (change 1: window swipe only with two or more windows)
- Human: no window swipe and no switcher when the frontmost app has fewer than two windows, no frontmost app, or no Accessibility → Solution, R1, R3, R13, R14 rewritten; the slide behaves as with the setting off.
- prd-reviewer: Design still builds message rows → left to the planner.
- prd-reviewer: R4 one-row scenarios, unstated window counts in scenarios, blocking-window timing in no-swipe scenarios → scenarios given window counts and "thumb landed just now".
- prd-reviewer: lone minimised window → rule kept; Non-goal and R13 scenario added.
- prd-reviewer: untestable speed rule → 50 ms bound; the count is the switcher's row count.
- prd-reviewer: R2 two-kinds wording, R1 Accessibility wording, R13 MUST NOT, R3 full-screen wording, R6 dead condition, docs clauses → applied.
- prd-reviewer: missing scenarios (vertical-then-sideways stays no swipe, Accessibility granted later) → added to R13, R14.

## Plan (change 1: window swipe only with two or more windows)
- Decision point: the recognizer decides on the frame thread, only the main actor reads windows → a window swipe's start became a question the model answers before the next frame, the unconfirmed slide blocking by the thumb rules so a declined slide is exactly the setting-off slide. Rejected: a frame-thread window read, a pushed window count, a read when the pair lands, starting blocked then releasing (the scroll filter never relaxes). Without Accessibility the recognizers run without the window swipe. `docs/architecture.md` Concurrency gains the answer hop; `docs/domain-model.md` follows R1, R3, R6, R13, R14.
- Built work kept: S1 to S4 left as history; S5 (the answer protocol, no visible change) and S6 (the product change) added; superseded rows retired rather than rewritten.
- plan-reviewer W1: the main-actor reply bookkeeping written twice (real and in-memory adapters), checked only by review → one `WindowSwipeConfirmation` in `LauncherCore` both adapters use, T73 for its edges; M21 shrinks to wiring.
- plan-reviewer W2: M20 timed only part of R1's 50 ms with a sampling profiler → end-to-end 240 fps video from the fingertip crossing a 3 mm mark to the panel; T19 claimed only for the model.
- plan-reviewer: T35's new case (a) proves S5's one visible change but sat in S6 → moved to S5; the old no-Accessibility click case is deleted in S6.
- plan-reviewer: T22, T28, T29, T30 reused for new scenarios while S2 claims them green → retired; their change-1 content is T69 to T72.
- plan-reviewer: S5 said the system's swipes unblock on the start frame, but the anchored thumb keeps them blocked → S5 reworded.
- plan-reviewer: requirements proved by both a test and a manual check → every manual entry now names the clause no test can reach; "All requirements" narrowed to "no requirement on its own".
- plan-reviewer: M13 could fail where open question 8's Mission Control applies → compared against the same slide with the switch off. M14 had no thumb timing → a within-3 s run and a rested-thumb run.
- plan-reviewer: a late decline after the thumb rolled out was underspecified → "a rest of every contact down, as `restOrIdle` gives"; T67 gains the rolled-thumb hand and the `[.windowSwipe]` against `[]` pairing.
- plan-reviewer: the differential row's no-Accessibility pair compared identical recognizers; "(h1)'s probes drop" was false while only the thumb is down; the full-screen world was missing → pair dropped (T72 covers it), wording fixed, world added, swipe-off pairing added (T70).
- plan-reviewer: R13's "a haptic MUST NOT play" against the swap a declined slide's fingers allow → read as the slide's own haptic, recorded in the trace and as open question 17.
- plan-reviewer: `confirmWindowSwipe(on:)` sketched in a protocol extension, which would not dispatch to the adapter → written inside the protocol body.
- plan-reviewer: requirement tags (S5 missing R2 and R13, T68 missing R13), stale docs (architecture's "a window swipe reads", the *Tap* entry without Accessibility, the renamed `SystemPermissionsTests`, the "same hop" bullet) → fixed.

## Implement (change 1: window swipe only with two or more windows)
- S5 committed (fc2e216). Departure: `FrameTime` made `Equatable` so an answer can name its start; `.trackpadsChanged` events still reach `onEvent` directly (no reply).
- S6 committed (a88b1c3), with `docs/product-overview.md` updated. Departures: `FrontmostWindows.app` removed (its one user was the deleted Accessibility row); T70 compares apps brought to front by name (each world has its own temp folder); T72's slide after the grant re-anchors the thumb (the re-run recognizer never saw the old thumb land).
- Open questions 14–17 kept at the plan's defaults, as instructed. No `.claude/skills/verify-*` → verification-skill step skipped.
- Full gate after S6: green (480 tests, app builds).
- implementation-reviewer (fixed point 8c3f56f): no requirement missing or wrong.
- Fixed: T40(b) now shows the second trackpad's slide blocked until its lift (thumb rested 4 s, MacBook hand lifted, unphased probe drops then passes); T68 and T73 split into one test per case; `asking` → `startBeingHandled`, `answered` → `latestAnswer`; T67's thumb rolls 20 mm as planned; an unused binding from S1 in `SwapRecognizerTests` removed (build warning).
- Declined: moving `WindowSwipeConfirmation` out of `LauncherCore`, a `WindowSwipeAnswer` parameter, a non-optional `deliver` result (all plan decisions); the one-line answer sites, per-driver `answering:`, the two `isConfirmed` checks and the forwarding `confirmWindowSwipe(on:)` (small or port-required).
- Full gate after fixes: green (486 tests, no warnings, app builds).
