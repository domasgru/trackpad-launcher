# Standards review: origin/main...HEAD (feature/011-top-edge-taps)

Sources: docs/architecture.md, docs/domain-model.md, tdd/tests.md, tdd/mocking.md, smell baseline.

**Hard violations: none.** LauncherCore still imports Foundation only. No new ports or mocks. The policy stays in value types. The domain-model.md "Edge contact" and "Hand mode" entries match `isInBand`: bottom < 3 mm, or hand-side < 3 mm with `p.y > 0.40`.

## Judgement calls

### LauncherCore/Surface.swift
1. **Possible Repeated Switches / Duplicated Code.** The same `HandMode` conditional on `p.x` now appears in two structs, once in each direction:
   `handMode == .right ? p.x : 1 - p.x` (AnchorCorner.fromEdge)
   `(handMode == .right ? 1 - p.x : p.x) * surface.widthMM` (EdgeContacts.isInBand)
   Fix: give `HandMode` one place to own these (for example `anchorSideFraction(_:)` and `handSideFraction(_:)`), and have both structs call it.
2. **Domain vocabulary (domain-model.md: "Use these words ... everywhere: docs, plans, code").** The `EdgeContacts` doc comment says "the guarded band", and the glossary has no such term. The glossary says "edge contact", "hand-side edge" and, informally, "the band". This is minor: either add the term to the glossary or say "the band".

### LauncherCoreTests/EdgeContactRecognizerTests.swift
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
