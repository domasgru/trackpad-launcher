# Plan review: 011 top-edge taps (origin/main...HEAD)

Requirements R1–R6 look implemented. `isInBand` matches design.md: strict `< 3 mm` from the bottom edge, or from the hand-side edge (`1 - x` in right-hand mode, `x` in left-hand mode) with `p.y > 0.40`. The corner carve-out is gone, the recognizer passes `handMode`, and `GestureRecognizer.init` keeps its parameters. T1–T8 each have a test at the recognizer seam, with rows and expected values that match the table. Five findings follow, all minor.

## (a) Missing or partial
None.

## (b) Scope creep
None.

## (c) Implemented but wrong
1. `edgeBandMM` is read twice. S1 says: "The 40% constant lives in `GestureRules` beside `edgeBandMM`, each with exactly one read, in `EdgeContacts`". Design.md says the same: "Each constant has exactly one read, in `EdgeContacts`." Surface.swift:90 and :91 both read `GestureRules.edgeBandMM`, once for the bottom distance and once for the hand-side distance. The behaviour is correct, but this acceptance item is not met as written.

## (d) Test scenarios
2. T7 (`aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad`) compares whole arrays and has no message saying which millisecond failed. S1's skills line asks: "a per-frame row reports the frame's millisecond in its failure message as the suite's existing per-frame tests do". `aFingerSlidingIntoTheBandStaysAFingerForBlocking` is the suite's model for this. The expected values are correct.

## (e) Verified without a test
3. Checked and holding:
   - `grep -rn distanceToNearestEdgeMM LauncherKit` returns nothing.
   - `git diff origin/main...HEAD -- LauncherKit/Tests` touches only `EdgeContactRecognizerTests.swift`.
   - In that file the changes are the band test (now T1, with its three freed rows removed), the boundary test rename, and the new T2–T8. No other `@Test` changed.
   - `docs/domain-model.md` is committed as the plan prescribes.
   - `edgeBandTop` has exactly one read.
4. Unverified, because it cannot be checked with read-only access:
   - "the full suite is green" (R6). I did not run `Scripts/test.sh`.
   - The plan 007 replay "still prints nothing for … rec1.txt". The only evidence is the implementation note; the rebuilt harness is in /tmp and was not committed.
   - The checkboxes in S1.md are still unticked.

## Plan-document consistency
5. The open question is stale. plan.md:128 now reads "a thumb anchored less than 3 s ago", so the slip is fixed. Three plan documents still describe the old wording:
   - design.md Further Notes: "says the thumb anchored 'more than 3 s ago' … It is not edited here"
   - testing.md T7: "The scenario's GIVEN, 'a thumb anchored more than 3 s ago', cannot block a click"
   - development-logs.md line 25

   T7 still agrees with the corrected scenario.
