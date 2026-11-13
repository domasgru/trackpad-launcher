# Development logs: Hold thumb setting

## Specify
- The thumbless tap definition was ambiguous: a thumb plus fingers could count as a thumbless tap, and the second finger of a multi-finger tap could fail the "empty trackpad" rule → R4 now defines the tap. The first finger lands on an empty trackpad. A contact in the anchor corner is always a thumb, so that touch follows the thumb rules only. Scenarios cover thumb plus fingers, a tap in the corner, a quick swap and a double tap.
- When the gesture fires and how sequential taps count were undefined → it fires when the last finger lifts, and a landing after the trackpad empties starts a new tap.
- Tapping the switch in the settings window while off was not covered → the "Turning it back on by tap" scenario accepts that the gesture also fires.
- The order of the gesture and macOS's click was unspecified → R8 states that which app receives the click is not specified.
- No scenarios for accidental touches → a new non-goal says any touch that meets the definition fires.
- R4 and R5 each bundled several behaviours, and R5 used an internal term and an unexplained "3 seconds" → R4 became R4–R6 and R5 became R7–R8. "Blocking window" and "3 seconds" were dropped, and scroll and system swipe scenarios were added.
- R10 (now R13) was an implementation constraint → kept, because the user asked for it. It is judged by reviewing the code, and its scenario is now observable.
- Downgrade wording constrained an old version → reworded as a storage constraint on this version, with a scenario.
- Smaller fixes: the press wording, a force-quit scenario, "Every tap gesture" in the problem statement, and non-goals for a per-trackpad setting and an in-app caption. The perf-run non-goal was dropped.
- Declined: replacing domain-model terms (anchor corner, edge contact band) with the overview's wording. `docs/domain-model.md` is the glossary.

## Plan
- Rows that played a second fresh script in one world would never run: `World.play` drops frames not newer than the last it delivered, so `swipe` after a slide failed and several "nothing fires" steps passed with no frame delivered → "a tap of N" is now a `World` helper that delivers straight to the fake, as `World.tap` does; the rows say where a script continues and where a world is fresh (T9, T10, T13 to T18, T20, T21).
- A press that macOS makes itself could end a tap: the tap's own Tap to click click races the press sample of the lift frame, with a margin plan 027 called narrow, and a thumbless tap would run that race on every tap → a press ends a candidate only while one of its fingers is down; the frame its last finger is gone judges only the time, and what it carries (a press, a landing) belongs to what comes next. T9(c) and T15(d) pin it. The real-trackpad pass gains "50 taps, every one fires".
- Dragging makes the second tap of a double tap carry macOS's own button-down → kept as a known limit of R4's "Double tap", named as such in Further Notes and reported.
- R4's "Thumb and fingers land together" was read narrower than written, and the note missed the fingers-first order, which swaps → the note now lists all three orders and is marked as an open question for the human reviewer. The requirement's wording is not changed here: that belongs to the requirements step.
- The clean-start condition "the frame before had no contact" was exercised by no row → T19 gains two touches: an anchored thumb lifting, or rolling out, on the frame a finger lands.
- Smart zoom was unproved for R7's "any tap action" → T16(e).
- T20(a) and (d) could not fail, since `switcherWorld` assigns no gesture → an app on gesture 2 in T20's worlds.
- T17 only repeats what T3 and T21 show, because the fake delivers at once → kept as a pin of the order the model sees, labelled so; the real order is a step of the real-trackpad pass.
- R13's checks had gaps: `git diff main` also lists what main gained, the grep skipped the app target and several observer tokens, and a new source file for `RecognizerOptions` would have forced an edit of the source-scan test's lists → the checks use `git diff --merge-base main` with an allowlist of six files and a wider grep, and `RecognizerOptions` is declared beside the recognizer.
- The recognizer helpers in `Fixtures.swift` were to gain an argument nothing used → dropped; T19 builds its recognizers through the test-side convenience.
- Docs: *Hold thumb setting* did not say that an older version which saves drops the choice → one sentence added. S2's doc-comment list named the gesture type's comment, which never mentions the thumb, and missed the settings view's → corrected.
- Planner found that R4's "Thumb and fingers land together" conflicted with today's thumb rules (R9): fingers landing on the same frame as the thumb fire nothing → the scenario now has the thumb land first, and a new scenario pins that a same-frame landing fires nothing, as today.

## Implement
- S1 (`fb755fe`): `RecognizerOptions` carries the slide kinds and the swap flag from the model's run record through the port and both adapters into each recognizer, as planned. One `make test` run had a `LauncherPlatformTests` failure that did not recur in the next two runs: likely a flaky test unrelated to this change.
- S2 (`445ca6d`): the Hold thumb setting, its intent, the `thumblessTaps` option and the candidate inside the rest, as planned. A six-finger tap fires nothing, so it starts no new candidate on its lift frame (the plan's "after a tap that fired" read literally).
- No verification skill exists in the repo, so none was run.
- Plan text: Further Notes still called R4's "Thumb and fingers land together" an open question, and T12 pointed at it, although the requirements were resolved → the note now records the resolution, and T12 cites both R4 scenarios.
- Review: T20(d) could not fail (its world assigned no app to gesture 2), and T20(b)/(c)'s fresh worlds lacked the assignment → every T20 world assigns the gesture, and (a) also checks nothing fires before the lift.
- Review: T19 lacked "a window swipe answered no" and ran its touches in one loop → added, and T19 is parameterised over the touches.
- Review: T16(d) lacked the firm-pressed tap after a thumbless tap (R7 "Press right after") → added, `pressVerdicts == [.pass, .pass]`.
- Review: "nothing fires" was checked through `broughtToFront` alone → one helper checks `broughtToFront`, `pulses`, `launchAnimations` and `bounces`; the repeated click-passes and rows-present checks are helpers too.
- Review: T9(b) ran one press timing, T14 did not check the pulse kind, and T24 checked one of five bundle identifiers → all three now match their plan rows.
- Review: T14, T15(a) and T16(e) used other timings than the plan → brought to the plan's 280 ms, 0–100/200–300 ms and 80 ms gap.
- Review: `#expect(!…)` and a vague `enum Case` in the new suites → `== false` and a descriptive name.
- Human, on a real trackpad: thumbless taps were far too generous (400 ms window), so still taps to click (104–232 ms) fired. Recorded deliberate thumbless taps ran 16–64 ms → R4 now has a 70 ms thumbless tap window; thumb-held taps keep 400 ms. Committed as "Shorten the thumbless tap window to 70 ms".
