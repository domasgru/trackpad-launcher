# Standards review: dev-workflow:tdd

Range: `origin/main...HEAD` (af72489..59ded9d), limited to GestureRecognizer.swift, GestureRules.swift, Surface.swift, EdgeContactRecognizerTests.swift.
Standards source: `dev-workflow:tdd` (SKILL.md, tests.md). I skipped the smell baseline because the repo-standards review covers it.

## Hard violations

None.

- **Seams:** every new row runs through `GestureRecognizer.step` at the recognizer seam that testing.md's Strategy agreed. Nothing tests `EdgeContacts` (package) or `isInBand` (private) directly. This meets SKILL.md "Test only at pre-agreed seams".
- **No mocks:** nothing is faked, and the tests read only the public `Recognition` fields (tests.md "Good Tests: Uses public API only").
- **Expected values are literals:** the `[.one]`/`[.two]` verdicts, the `[110 ... 160]` swipe frames, the travel values 4/8/12/16 and the blocking arrays are all literals taken from testing.md. None is recomputed the way `isInBand` computes it, so none is tautological (SKILL.md "Anti-patterns: Tautological"). The `thumbX = ... surface.widthMM - 10` line places the fixture. It is not an expected value.
- **Minimal code:** the source change is only what T2 needs: a new band predicate, one constant, and the removal of `distanceToNearestEdgeMM`, which the plan required. Nothing speculative is added (SKILL.md "Red before green ... Don't anticipate future tests").

## Judgement calls

1. **T4–T8 were never seen red** (SKILL.md, "Rules of the loop: Red before green"). The implementation notes say "T3 to T8 passed on T2's code with no further change". So the band change came before the rows `aFingerAtTheTopEdgeCountsInATwoFingerTap`, `aFingerAtTheTopEdgeTakesPartInASwipe`, `aFingerRestingAtTheTopEdgeCountsForASwap`, the `(62.4, 1.0)` row of `aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad`, and `aFingerSlidingIntoTheHandSideBandStaysAFingerInATap`. testing.md says each of these fails on today's code, but none was ever seen failing. S1.md permits this ("may pass on T2's code"), but the skill's rule is that a test is seen failing first. T8 is the one most at risk: it guards against a filter that re-judges a contact by position on every frame, and T2's code never had that filter, so the guard has never been proven to catch it. Everything sits in one commit (59ded9d), so the history cannot confirm the order either. Fix: revert the `isInBand` change locally and confirm each row fails for the reason testing.md gives.

2. **More than one assertion per test** (tests.md, "Good Tests: One logical assertion per test"):
   - `aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad` checks `blocksClicks` and `blocksDockSwipes` in two `#expect`s.
   - `aFingerAtTheTopEdgeTakesPartInASwipe` has three: `events.at`, `phasesMatch(...)` and `fired(all) == []`.
   - `aFingerSlidingIntoTheHandSideBandStaysAFingerInATap` has two: `twos == [170]` and `fired(all) == [.two]`.

   Each can be read as one behaviour ("blocks like a middle finger", "takes part in a swipe") and each follows its testing.md row exactly, so this is a minor point. Splitting the two blocking flags would give clearer failure messages.

Findings: 2 (0 hard, 2 judgement calls). Worst: #1, the rows T4–T8 were never seen red.
