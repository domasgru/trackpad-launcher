# Implementation review: 011 top-edge taps

Branch: `feature/011-top-edge-taps`. Fixed point: `origin/main` (af72489). The local `main` ref is stale (1cf9c4b, eleven merged PRs behind); `origin/main` is the branch merge-base and yields exactly the two commits below, so it was used as the fixed point.

Diff: `git diff origin/main...HEAD` (10 files, +421/-29).
Commits (`git log origin/main..HEAD --oneline`):
- 59ded9d S1: The guarded band follows the hand mode
- 542369c Plan 011: top-edge taps

Plan: `plans/011-top-edge-taps/plan.md`. Skills ledger: `plans/011-top-edge-taps/.temp/review/skills.md` (swift-testing-pro, tdd). No verification-skill commit on this branch.

Sub-reports in this directory: `standards.md`, `standards-swift-testing-pro.md`, `standards-tdd.md`, `plan.md`. Each section below is the sub-report verbatim, with its headings nested one level.

## Standards


Sources: docs/architecture.md, docs/domain-model.md, tdd/tests.md, tdd/mocking.md, smell baseline.

**Hard violations: none.** LauncherCore still imports Foundation only. No new ports or mocks. The policy stays in value types. The domain-model.md "Edge contact" and "Hand mode" entries match `isInBand`: bottom < 3 mm, or hand-side < 3 mm with `p.y > 0.40`.

### Judgement calls

#### LauncherCore/Surface.swift
1. **Possible Repeated Switches / Duplicated Code.** The same `HandMode` conditional on `p.x` now appears in two structs, once in each direction:
   `handMode == .right ? p.x : 1 - p.x` (AnchorCorner.fromEdge)
   `(handMode == .right ? 1 - p.x : p.x) * surface.widthMM` (EdgeContacts.isInBand)
   Fix: give `HandMode` one place to own these (for example `anchorSideFraction(_:)` and `handSideFraction(_:)`), and have both structs call it.
2. **Domain vocabulary (domain-model.md: "Use these words ... everywhere: docs, plans, code").** The `EdgeContacts` doc comment says "the guarded band", and the glossary has no such term. The glossary says "edge contact", "hand-side edge" and, informally, "the band". This is minor: either add the term to the glossary or say "the band".

#### LauncherCoreTests/EdgeContactRecognizerTests.swift
3. **Possible Duplicated Code.** The thumb position for each hand mode is worked out three times, and one copy hard-codes the MacBook 14 width:
   `let thumbX = handMode == .right ? 10.0 : surface.widthMM - 10` (x2)
   `let thumbX = handMode == .right ? 10.0 : 114.8`
   Fix: one helper, for example `thumbX(for:surface:)`.
4. **Possible Duplicated Code.** `aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad` builds its frames by hand with `h.contact`/`h.frame`, which repeats what `frames([Track])` already does: `var touches = [h.contact(9, ms == 0 ? .landing : .down, atMM: 10, 10)]`
5. **tests.md "One logical assertion per test".**
   - `aFingerSlidingIntoTheHandSideBandStaysAFingerInATap` asserts `twos == [170]` and also `fired(all) == [.two]`, and the second check mostly repeats the first.
   - `aFingerAtTheTopEdgeTakesPartInASwipe` makes three expectations: the swipe timings, the phases, and that no tap fires.
   These are borderline, and the suite already uses this pattern.
6. **Stale suite doc comment (unchanged line, but the behaviour it describes has changed).** It says `/// A contact landing at the trackpad's edge is a resting hand, not a finger...`, but the top edge, the opposite edge and the upper hand-side edge are now fingers. That contradicts domain-model.md "Edge contact".

Findings: 6 (0 hard, 6 judgement calls). Worst: #1, the hand-side conditional repeated across AnchorCorner and EdgeContacts.

## Standards: macos-dev-workflow:swift-testing-pro


Range: `origin/main...HEAD` (af72489..59ded9d), file `LauncherKit/Tests/LauncherCoreTests/EdgeContactRecognizerTests.swift`, changed lines only.
Sources: `SKILL.md`, `references/core-rules.md`, `references/writing-better-tests.md`. The smell baseline is left out on purpose because the repo-standards review covers it.

Findings: 2 (both judgement calls, no hard violations).

### EdgeContactRecognizerTests.swift

#### 1. Lines 163-165: the per-frame row gives no millisecond in its failure message (medium, judgement call)
Rule: swift-testing-pro, `references/writing-better-tests.md`, "Structuring tests": "Add user-facing messages to `#expect` and `#require` when they provide value." The slice (S1.md) applies this rule as "a per-frame row reports the frame's millisecond in its failure message as the suite's existing per-frame tests do", which means the `for`-loop shape at lines 236-240.

```swift
let recognized = recognitions(all)
#expect(recognized.map(\.blocksClicks) == [false, true, true, true, false, false, false])
#expect(recognized.map(\.blocksDockSwipes) == [false, true, true, true, true, true, false])
```
If this fails, the output is two 7-element Bool arrays, and the reader has to work out by hand which entry of `times` (0, 100, 1000, 2990, ...) went wrong. Suggested fix, following the suite's per-frame shape:
```swift
let clicks = [false, true, true, true, false, false, false]
let dock   = [false, true, true, true, true, true, false]
for (i, recognition) in recognitions(all).enumerated() {
    #expect(recognition.blocksClicks == clicks[i], "at \(times[i]) ms")
    #expect(recognition.blocksDockSwipes == dock[i], "at \(times[i]) ms")
}
```
The unchanged test at lines 289-290 compares whole arrays the same way, so the suite's precedent is mixed. That is why this is a judgement call and not a hard breach.

#### 2. Line 142: an opaque Bool helper inside `#expect` (low, judgement call)
Rule: swift-testing-pro, `references/writing-better-tests.md`, "Writing good verification methods". When expectations are wrapped in a helper, the helper should expect and pass `sourceLocation`, so the failure shows real values.

```swift
#expect(phasesMatch(events.phases, [.began, .moved(travelMM: 4), ...]))
```
If this fails, the report says only `phasesMatch(...) -> false`, with no actual phases. The helper already exists (`Fixtures.swift:77`) and lines 277 and 309 call it the same way, so this new call follows suite convention. The cheapest fix inside this diff is a message: `#expect(phasesMatch(...), "\(events.phases)")`. Turning `phasesMatch` into a `verifyPhases(..., sourceLocation:)` helper would touch `Fixtures.swift`, which this slice must not edit (R6).

### Checked and clean
- No `!` inside `#expect`/`#require` (core-rules).
- Every parameterised test passes one tuple-array collection, so there is no Cartesian product (core-rules).
- The `@Suite struct` stays as the repo's convention, the tests have no `test` prefix, and nothing depends on test order (core-rules).
- Tests with several `#expect` lines (134-144, 168-177) still test one behaviour each (writing-better-tests).

## Standards: dev-workflow:tdd


Range: `origin/main...HEAD` (af72489..59ded9d), limited to GestureRecognizer.swift, GestureRules.swift, Surface.swift, EdgeContactRecognizerTests.swift.
Standards source: `dev-workflow:tdd` (SKILL.md, tests.md). I skipped the smell baseline because the repo-standards review covers it.

### Hard violations

None.

- **Seams:** every new row runs through `GestureRecognizer.step` at the recognizer seam that testing.md's Strategy agreed. Nothing tests `EdgeContacts` (package) or `isInBand` (private) directly. This meets SKILL.md "Test only at pre-agreed seams".
- **No mocks:** nothing is faked, and the tests read only the public `Recognition` fields (tests.md "Good Tests: Uses public API only").
- **Expected values are literals:** the `[.one]`/`[.two]` verdicts, the `[110 ... 160]` swipe frames, the travel values 4/8/12/16 and the blocking arrays are all literals taken from testing.md. None is recomputed the way `isInBand` computes it, so none is tautological (SKILL.md "Anti-patterns: Tautological"). The `thumbX = ... surface.widthMM - 10` line places the fixture. It is not an expected value.
- **Minimal code:** the source change is only what T2 needs: a new band predicate, one constant, and the removal of `distanceToNearestEdgeMM`, which the plan required. Nothing speculative is added (SKILL.md "Red before green ... Don't anticipate future tests").

### Judgement calls

1. **T4–T8 were never seen red** (SKILL.md, "Rules of the loop: Red before green"). The implementation notes say "T3 to T8 passed on T2's code with no further change". So the band change came before the rows `aFingerAtTheTopEdgeCountsInATwoFingerTap`, `aFingerAtTheTopEdgeTakesPartInASwipe`, `aFingerRestingAtTheTopEdgeCountsForASwap`, the `(62.4, 1.0)` row of `aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad`, and `aFingerSlidingIntoTheHandSideBandStaysAFingerInATap`. testing.md says each of these fails on today's code, but none was ever seen failing. S1.md permits this ("may pass on T2's code"), but the skill's rule is that a test is seen failing first. T8 is the one most at risk: it guards against a filter that re-judges a contact by position on every frame, and T2's code never had that filter, so the guard has never been proven to catch it. Everything sits in one commit (59ded9d), so the history cannot confirm the order either. Fix: revert the `isInBand` change locally and confirm each row fails for the reason testing.md gives.

2. **More than one assertion per test** (tests.md, "Good Tests: One logical assertion per test"):
   - `aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad` checks `blocksClicks` and `blocksDockSwipes` in two `#expect`s.
   - `aFingerAtTheTopEdgeTakesPartInASwipe` has three: `events.at`, `phasesMatch(...)` and `fired(all) == []`.
   - `aFingerSlidingIntoTheHandSideBandStaysAFingerInATap` has two: `twos == [170]` and `fired(all) == [.two]`.

   Each can be read as one behaviour ("blocks like a middle finger", "takes part in a swipe") and each follows its testing.md row exactly, so this is a minor point. Splitting the two blocking flags would give clearer failure messages.

Findings: 2 (0 hard, 2 judgement calls). Worst: #1, the rows T4–T8 were never seen red.

## Plan


Requirements R1–R6 look implemented. `isInBand` matches design.md: strict `< 3 mm` from the bottom edge, or from the hand-side edge (`1 - x` in right-hand mode, `x` in left-hand mode) with `p.y > 0.40`. The corner carve-out is gone, the recognizer passes `handMode`, and `GestureRecognizer.init` keeps its parameters. T1–T8 each have a test at the recognizer seam, with rows and expected values that match the table. Five findings follow, all minor.

### (a) Missing or partial
None.

### (b) Scope creep
None.

### (c) Implemented but wrong
1. `edgeBandMM` is read twice. S1 says: "The 40% constant lives in `GestureRules` beside `edgeBandMM`, each with exactly one read, in `EdgeContacts`". Design.md says the same: "Each constant has exactly one read, in `EdgeContacts`." Surface.swift:90 and :91 both read `GestureRules.edgeBandMM`, once for the bottom distance and once for the hand-side distance. The behaviour is correct, but this acceptance item is not met as written.

### (d) Test scenarios
2. T7 (`aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad`) compares whole arrays and has no message saying which millisecond failed. S1's skills line asks: "a per-frame row reports the frame's millisecond in its failure message as the suite's existing per-frame tests do". `aFingerSlidingIntoTheBandStaysAFingerForBlocking` is the suite's model for this. The expected values are correct.

### (e) Verified without a test
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

### Plan-document consistency
5. The open question is stale. plan.md:128 now reads "a thumb anchored less than 3 s ago", so the slip is fixed. Three plan documents still describe the old wording:
   - design.md Further Notes: "says the thumb anchored 'more than 3 s ago' … It is not edited here"
   - testing.md T7: "The scenario's GIVEN, 'a thumb anchored more than 3 s ago', cannot block a click"
   - development-logs.md line 25

   T7 still agrees with the corrected scenario.
