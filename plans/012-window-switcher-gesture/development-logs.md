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
