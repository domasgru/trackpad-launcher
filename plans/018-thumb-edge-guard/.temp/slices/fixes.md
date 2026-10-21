# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/018-thumb-edge-guard` (branch `feature/018-thumb-edge-guard`). Work only there. Do not commit. Paths below are under `LauncherKit/`. No behaviour changes; no other files.

## F1. T9 tests at the wrong seam

`Tests/LauncherCoreTests/EdgeContactRecognizerTests.swift:405-414`, `aContactInTheCornerStripAloneDoesNotKeepBlockingAfterTheThumbLifts`.

Rule (plan, T9): "Given a thumb anchored at (8, 8) and a contact landing at (10, 1) 50 ms later and staying. When 50 ms after that the thumb lifts, and 50 ms later one finger taps in the middle (`thumb(atMM: (8, 8)).land(fingers: 1, atMM: (10, 1)).wait(.milliseconds(50)).liftThumb().tap(fingers: 1)`). Then `fired == []`, and every frame from the thumb's lift on reads `blocking == .none`. Today: … the frames after the lift read `.possible` with the contact alone and `.dockSwipes` while the finger is down (the contact keeps the thumb touch alive)."

Problem: the test slices the frames after the lift and calls `recognitions(Array(afterLift))`, which builds a fresh `GestureRecognizer`, so the thumb touch from before the lift is gone and the row never checks that a strip contact does not keep the thumb touch alive.

Fix: run `recognitions(frames)` over the whole script, find the index of the first frame (after the thumb was down) in which the thumb's touch ID is absent, and assert that every recognition from that index on reads `blocking == .none` (and that there is at least one such frame). Keep `fired(frames) == []`. Confirm the fixed test fails if `|| anchorCorner.isInStrip(p)` (soon `isInCornerStrip`) is temporarily removed from `EdgeContacts.isInBand`, then restore it.

## F2. Test hard-codes TouchScript's thumb ID

Same test, lines 409-410: `$0.id.rawValue == 100`. Rule (tdd tests.md): tests "survive internal refactors". `TouchScript` already has `private static let thumbID: Int32 = 100` (`Tests/LauncherCoreTests/TouchScript.swift:47`).

Fix: make that constant non-private (`static let thumbID: Int32 = 100`, with a one-line doc comment: the touch ID every thumb in a script lands with) and use `TouchScript.thumbID` in the rewritten T9. Do not touch `BlockingLevelRecognizerTests`.

## F3. Glossary wording in production code

Rule (`docs/domain-model.md`): "Use these words, with these meanings, everywhere: docs, plans, code, UI". The glossary terms are *corner strip*, *thumb-side edge*, and edge contact "where a thumb sits partly off the pad"; the 3 mm zones are *bands*.

In `Sources/LauncherCore/Surface.swift`:
- Rename `AnchorCorner.isInStrip(_:)` to `isInCornerStrip(_:)`, and its call in `EdgeContacts.isInBand` (line ~104).
- Rename the private `fromEdge(_:)` to `fractionFromThumbSideEdge(_:)` (all its uses in `admits`, `holds`, the strip query), and change its doc comment "Distance from the anchor-side edge as a fraction of the width." to say thumb-side edge.
- In the `EdgeContacts` doc comment (line ~70), replace "a half-off thumb" with "a thumb that sits partly off the pad" (or reword so the term is used once and not duplicated in the same sentence).

In `Sources/LauncherCore/GestureRules.swift`:
- `cornerWidth`'s doc (line 5): "measured from the anchor-side edge" → "measured from the thumb-side edge".
- `edgeBandMM`'s doc (lines 11-12): replace "guarded edge(s)" wording with band wording, e.g. "A contact landing in one of the three bands is an edge contact …: closer than this to the bottom edge, to the hand-side edge below the `edgeBandTop` line, or, in the anchor corner's corner strip, to the top edge or the thumb-side edge. Strictly less is inside the band." Keep "Strictly less is inside the band."

## Not fixed (decided)

Data clump of `handMode`/`surface`, a shared band-distance helper, and the three assertions in the R2 row: judgement calls, left as is.

## Done when

`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/018-thumb-edge-guard/Scripts/test.sh` is green. Report briefly: what changed, and whether F1's test went red with the strip check removed.
