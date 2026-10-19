# Development logs: Launch bounce

## Specify
- R2 (running apps float up) contradicted R13 (a repeat gesture during a bounce plays nothing) once the app had started up → R2 now defers to the same-app rule (R14), with a scenario.
- "Not running" was undefined for an app already launching from the Dock → R1 defines it as no process when the gesture fires; such an app gets the launch animation, with a scenario.
- The problem statement claimed nothing shows during a cold launch, but the Dock bounces → reworded; "Suppressing the Dock's own bounce" added to non-goals.
- R7/R8 forbade trailing and squash that the tuner offers → scoped to the shipped tuning.
- R5 "centred on the tip" clashed with the edge and row rules → R5 covers a single icon, except as R6 and R13 say.
- R6 below-pointer mode was ambiguous → rests 8 pt below the arrow and jumps downward; scenario for crossing onto the menu bar mid-bounce; the rule covers the whole row.
- "Finished starting up" was not observable → R10's scenario uses the Dock's bounce stopping as the proxy.
- The overall cap was implicit → new R12: 10 s from the gesture; a late window plays nothing.
- R13's gap closing could be instant or animated → slides over about 0.2 s.
- R14's "bring to front as usual" was unclear for a launching app → asks macOS to open it again, nothing visible changes.
- R4 stated the size twice → "the launch animation's icon size, 60 pt as shipped".
- R1 never asserted the app launches → added; R14 asserts the window shows.
- Missing scenarios → crash during startup, and the first-launch "are you sure" dialog (accepted to run to the cap).
- The tuner requirement bundled five → split into R17 (knobs), R18 (preview), R19 (presets); the tuner's purpose stated.
- Rejected: "gestures inactive" is undefined (it is in the glossary); dropping the squash and trailing knobs (the user asked for them); dropping the 2 s grace after start-up (the user confirmed it); fading the icon when the setting turns off mid-bounce (the setting applies to the next gesture, as the glossary says).
- User review: the icon always stays above the pointer → R6 drops the below-the-pointer mode; at the top edge the icon is cut off by the edge instead.

## Plan
- Red-flag screen: candidate 2 had the model call `bringToFront` (now returning launched/activated) and then `showLaunchBounce`, which the adapter had to pair behind its back (callers coordinating two calls for one operation) → base on candidate 1's `hasProcess` query plus one command per visual; `bringToFrontBouncing` opens the app first by construction.
- Red-flag screen: candidate 2's two `after(_:for:)` overloads, and the lifecycle's retries riding the overlay's clock, were pass-throughs that leaked the clock into two modules → not grafted.
- Cross-judge picked candidate 1, 28 to 24, agreeing with the criterion-by-criterion scoring → candidate 1 is the base.
- Cross-judge: candidate 1's `LaunchStage` collided with `LaunchStage` in `LaunchFlight.swift` → the model's value is `LaunchBounce` with a nested `Step` (candidate 2's naming).
- Cross-judge: the fake re-implemented "the earliest limit wins" → it records every limit as a list.
- Cross-judge: the window-list look at finishing was called reliable → reworded as racy (F15, F19).
- Cross-judge: the display-sized row panel's memory was unmeasured, and candidate 2 claimed about 24 MB → measured (`checks/p6-panel-memory.md`) at about 0.8 MB in our process; kept the display-sized panel.
- Cross-judge grafts taken from candidate 2:
  - icons re-scale when the row crosses displays;
  - `addGlobalMonitorForEvents` is confined too;
  - the design states that plan 004's non-goals are reversed, and names the Dock-launch window and the hand-off swell.
- Cross-judge proposed grafting candidate 2's AX retry ticks → rejected. P1 shows registration was possible before the finishing push in all seven runs; grounding F16 understated this. A retry would bend the polling rule for a case no probe produced, so it is kept as open question O7.
- Verify: a deadline in a row cut off entirely by the top edge was untested → check P5 (`checks/p5-offscreen-clock.md`): a committed animation completes when its panel is off-screen, empty, moved off or ordered out, 15–57 ms late.
- Verify: the design claimed `FrontmostAppWindows` relies on `apiDisabled` → corrected; it treats any failed call as "no windows".
- Verify: the architecture doc's icon-drawing exception did not cover the bounce → added to the doc changes.
- Verify: candidate 1 read the process list before the pulse → moved after it, so `fire`'s effect order is exactly today's.
- Verify: the window list was read only after a failed registration → it is read on every look (`look(_:axWindows:listedWindows:)`).
- Test planner, pass 1:
  - `Deadline` was private (T25) → internal.
  - The no-display fallback could not be produced (T44) → `ScreenRead` injected through `WorkspaceActions(screen:)`.
  - The 0.2 s AX timeout was another class's side effect (T47) → `LaunchWatch` sets it on its own element.
  - The window-list count was inline (T48) → `LaunchWatch.listedWindows(of:)`.
  - The push contract was not enforced → a per-bounce `LaunchReportGate`, and the observer is dropped once it has reported (T39, T51, T52).
- Test planner, pass 1: R9 is not met without Accessibility (O1) or under AX lag (O7) → both open questions say so, and S3 waits on the human's answer. R12 slips (deadlines up to about 0.1 s late, longer across display sleep) → added to tradeoffs and as an open question.
- Test planner, pass 1: the fake must record a repeated start and offer an `onBringToFrontBouncing` hook (T1, T11) → added.
- Test planner, pass 1, rejected: a test-only time scale on the row's host layer. Scaled caps and limits with bounded waits already serve, and the slow suite can be skipped. The manual-only items (R18's preview, the mid-jump hand-off, R4, R7, R16) stay manual.
- Test planner, pass 2: the hand-off flight read the displays itself, not the bounce's `ScreenRead` → `play(for:from:among:)` takes the bounce's displays.
- Finalize: the slices asked implementers to write doc changes that planning had already made → those slice items now check the code against the updated `docs/domain-model.md` and `docs/architecture.md`.
- No runner dropped out.
- Human review of the design: D2 signed off; D1 accepted for later features; O1/O7 accepted with R9 amended, no AX retry; R12 reads "about 10 seconds"; D3/O4 accepted pending manual checks.

## Implement
- S1–S5 implemented, one commit each. S2 was built in two dispatches (S2a pure parts, S2b wiring) and committed as one; a crash killed the S2b implementer mid-run, and a second one finished it from the working tree. No verification skill in the repo, so that step was skipped. The local `main` ref is stale, so the review used origin/main `eb90f96` as its fixed point.
- The human saw "can't open … damaged or incomplete" alerts from a test opening a probe bundle with no executable → tests open with `promptsUserIfNeeded = false`; `WorkspaceActions(screen:promptsUser:)` is the test seam, the app keeps macOS's default.
- S2b's three red platform rows were test-side: a racy off-main lookup in `ProbeBundles.listed`, a slow start too short under load (now `blockInWillFinish`), and a row panel expected at 132 pt wide instead of the display's frame.
- After S4 the gate was red: probes leaked past their tests and showed up in `RunningAppsReaderTests`' read → separate commit: cleanup deletes the bundles first, kills every process under the probe directory and awaits each exit; every real-launch suite and the running-apps readers sit in one serialized parent suite `RealAppTests`. Three green runs.
- S4: the test process runs no application loop, so `LaunchBounceFollowTests` runs `NSApplication.run()` briefly, stopped by its own timer and a wake event.
- Review: BounceOverlay duplicated the icon-layer setup, the rest-to-panel conversion and the row layout, and spelled its stage tuple twice → private helpers and a `RowStage` struct.
- Review: the Bounce decoder copied LaunchTuning's fallback helper → one Debug `KeyedDecodingContainer.decode(_:or:)`.
- Review: mysterious names → `Visual.none` is `.bringToFrontOnly`, `flights` is `launchOverlay`, `flow` is `settle`.
- Review: icons kept their old `contentsScale` when start or end moved the row to another display → `stage(on:)` is the one re-frame and re-scales every icon.
- Review: `LaunchWatch` passed itself unretained to the AX observer with no cleanup if freed unstopped → `isolated deinit { stop() }`.
- Review: T23 bypassed the `slide` knob → `BounceRow.slide(from:to:tuning:)` reads it, and the test sets it. T8 used a made-up app and checked too little → an assigned, never-tapped app and every history. T2's string kinds → an exhaustive enum. T26 checked 4 of 15 flight keys → all. T29 allowed 5 s → the plan's 0.5 s. Test helpers re-implemented `ScreenRead.now` and `LaunchDisplay.containing` → use them.
- Review findings not taken: the Debug tuner panel's `acceptsMouseMovedEvents` (the plan's design, so the preview follows over the tuner); the one-bounce and report-once rules held in several layers (deliberate defence in depth); `LaunchWatch`'s window-list filter vs `FrontmostAppWindows`' (different filters); `ScreenRead` split into pointer and displays in two signatures (the plan's); `theCapIsTenSeconds` (pins a spec number).
- Gate after fixes: `Scripts/test.sh` green, 659 tests in 79 suites, no probe left running.
- Human, after implementation: the real-app tests (throwaway probe apps) took the suite from 6.4 s to 92 s → removed with the probe target; the pure look and deadline tests moved to LaunchWatchLookTests.swift; the suite runs 629 tests in about 6.6 s.
- Human: the tuner's 3 s preview button → a toggle that bounces without end and restarts on every tuning change; R18 reworded.
- Human: a second waiting animation to compare in the tuner → `Bounce.style` (jump or inflate) with inflate knobs (start size, inflate time and curve, keep growing, growing time); Debug tuner only, no tests, shipped style stays jump.
- Human: inflate paused between reaching the icon size and growing on, with no knob for it → one seamless curve whose speed falls as (1 + t/τ)^−easing, τ solved so it passes the icon size at the inflate time; "Easing" knob shapes it.
