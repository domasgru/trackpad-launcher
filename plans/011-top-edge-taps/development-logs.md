# Development logs: Taps near the top edge count

## Specify
- No scenario had a palm resting while a finger taps, the case the guard exists for → R1 gained that scenario for both hand modes.
- R5 named five finger rules but exercised two → R5 gained swipe and click-blocking scenarios, plus a sentence on what click and Dock swipe blocking are.
- A finger that lands outside the band and slides into it was not covered → R5 now states it stays a finger, with a two-finger tap scenario whose edge finger slides past the 40% line.
- A left-hand scenario put the anchor corner on the left edge → "below the anchor corner" removed.
- "Bottom 60%" and "more than 40% down" disagreed at the line → the Solution now uses the 40% line and says why it is a share of the height.
- R1's "outside the anchor corner" could never apply to the new band → dropped; the restated edge-contact behaviour left R1 for Non-goals.
- Imprecise positions and durations → bottom-edge ends, the spot next to the anchor corner, top-edge widths and "within the tap window" made explicit; the 40% boundary scenario split in two; the swap scenario needs two running apps.
- R3 lacked a case near the anchor corner → left edge 30% down, just below the corner, added.
- Non-goals gained the anchor corner staying as it is and a second hand on the pad.

## Plan
- The bug was never reproduced end to end; the 3 mm diagnosis was inferred from the code, and the hardware check ran only after the fix → S1's first step records the user's top-edge taps on today's build with plan 007's recorder and replays them through today's recognizer (nothing fires; every tap lands within 3 mm of the top, or the plan stops), and its last step replays the same recording after the change (once per tap). design.md's Further Notes say why.
- T1 duplicated the suite's existing band test, and the R6 check's "only the three rows move" forbade merging them → T1 is that test extended with a hand-mode argument and T1's rows; the design's "Existing tests" and the R6 check say so.
- The three freed rows were said to "move into T2" but were not in T2's list and would near-duplicate its rows → they are deleted, superseded by T2's rows at (1, 53.76), (62.4, 1) and (30, 1).
- T3's stated failure mode was wrong (a palm counted as a finger would fire `.two` at 400 ms, within the window, not nothing) → reworded; the guard works either way.
- The design claimed `distanceMM` has other callers (it has none) and "no public signature changes" (removing the nearest-edge helper is one) → both corrected: the removal is the plan's one public change; `distanceMM` was dead before this plan and stays out of its scope.
- The recorded palm's distance below the 40% line was overstated (19 mm, from the two bursts plan 007's test copied) → the recording's 20 palm landings, 42.1–61.6 mm from the top (55–80% down), the highest 11.4 mm below the line, in design.md and testing.md.
- The R6 check said every other contact lands 10 mm or more from the top, left and right edges, missing the corner-thumb guard at (1, 1) and (123.8, 1); the design named the wrong swap suite → the corner exception named (inside the anchor corner, never in the band) and `SwapTests.swift` named.
- The design put the new constant "beside `cornerHeight`" and the slice "beside `edgeBandMM`" → both say `GestureRules` beside `edgeBandMM`, documented like `cornerHeight`.
- The "band moves with the hand mode" claim named no proof → cites `LauncherTests.handModeDefaultsToRightAndSwitchingMovesTheCorner`.
- The hardware step "slide one finger fast around the anchor corner: nothing fires" could not fail without the palm → the heel of the hand resting beside the pad added.
- The R5 click-blocking timing slip was noted only in Further Notes, which the implementer never reads → T7's source-of-truth cell names it: R5's scenario "A finger resting at the top edge counts for click blocking" says the thumb anchored "more than 3 s ago" yet expects the click blocked, which the glossary's *Click blocking* makes impossible for any finger; "less than 3 s ago" was the intent, plan.md was corrected to it, and T7 proves both sides of the 3 s line.
- Rejected: moving to the `World` seam for the swipe and swap rows; the recognizer is the only module that changes and the model's side is unchanged and already proven there (testing.md's Strategy).
- The human ruled this a requirement change, not a bug, and is sure their top-edge taps land within 3 mm → the reproduction and this plan's recording are dropped; the plan 007 palm replay stays as the hardware check.

## Implement

- S1 committed as 59ded9d; gate green (376 tests), plan 007 replay harness prints nothing for rec1.txt.
- Verification skill: none in this repo, so no Branch-mode pass.
- Review (`.temp/review/report.md`, fixed point `origin/main` because local `main` is stale): no hard violations; 15 judgement calls or minor findings.
- Fixes, F1 (c5d0c06): `HandMode` owns the hand-side arithmetic for `AnchorCorner` and `EdgeContacts`; `edgeBandMM` read once; glossary wording in the `EdgeContacts` and suite doc comments; T7 per-frame messages with the millisecond, built with `frames([Track])`; `phasesMatch` failures show the actual phases; one `thumbX` helper; the "more than 3 s" question recorded as resolved in design.md, testing.md and this log; S1 boxes ticked. Mutation check: main's rule fails T2, T4–T8; per-frame re-judging fails T8.
- Left: the remaining multi-assertion findings (Standards #5, tdd #2 second and third bullets); each test asserts one behaviour as its testing.md row states it.
