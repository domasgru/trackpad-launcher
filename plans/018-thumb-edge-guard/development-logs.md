# Development logs: The thumb arms only when it lands fully inside the anchor corner

## Specify
- No scenario for a vertical slide under a graze → added a window swipe / scroll scenario to R1.
- No scenarios for mixed contacts (a graze down with a real thumb, or the thumb lifting while a graze stays) → added three scenarios to R3: arming, swapping, and no arming left behind after the thumb lifts.
- "No gesture fires" scenarios passed vacuously → every such scenario now names the hand mode and an assigned gesture.
- R3 bundled several outcomes in internal terms → rewritten as observable outcomes (finger count, clicks, scrolling, system swipes); arming and swapping left to R1 and R2.
- R7, R8 scenarios and "as before" phrasing were untestable → made concrete; R5 states its release rule.
- Anchor corner size and tap window undefined → added to Terms.
- Silent rejection of a thumb tap in the strip, and the corner not growing, were implicit → added as Non-goals.
- Rejected: dropping "thumb touch" and "Dock swipe blocking" as undefined. Both are glossary terms in docs/domain-model.md, which the reviewer did not read.
- Human: existing behaviour's source of truth is the tests, so requirements must not restate it → removed R9 (edges outside the corner), R7's left-edge scenario, and R5's restated release rule; R6 now states only the new strip boundary.

## Plan
- Review: the plan said T1 and T14 land at the deleted `aThumbAtTheVeryCornerStillAnchors` row's two points, but T14 had no (123.8, 1) → T14 gains that third argument; the deleted row is credited to plan 007 (kept by plan 011), not plan 011.
- Review: three "today" explanations were wrong though their values were right (T5's tap never completes within the script rather than timing out; T8's tap ends with nothing because `lift()` takes the graze-anchor up with the fingers rather than being spoiled; T3's `.ended` frame reads `.possible`, so `.clicks` runs to the frame before it) → reworded.
- Review: T13's floating-point claim was stated for the direct path only, while `HandMode.fractionFromThumbSideEdge` computes `1 - (1 - x)`, which gives 3.000000000000003 for the exact-3 mm point → the source now states both paths come out `>= 3` and that the row knowingly departs from plans 007's and 011's 0.5 mm-either-side convention because R6 names the boundary.
- Review: T2 cited `handModeDefaultsToRightAndSwitchingMovesTheCorner` as its twin, which taps left-handed and never reads the haptic → T2 cites `twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow`; T15's twin rows are 0.5 mm either side of the band, not 1 mm.
- Review: the Strategy claimed bottom-band edge-contact rows in five test files that have none → the clause is replaced by the argument that the model never sees an edge contact, with `TapGateTests.fortySecondsOfOrdinaryScrollingNeverOpensTheGate` and the `trackpadBlocking: false` filter rows as the proof that `.none` passes everything.
- Review: the Strategy named `perFrame`, which returns only `blocksClicks`, for rows that read the `Blocking` level and events → it names `EdgeContactRecognizerTests`' own `recognitions(_:)`.
- Review: T15 checked the top strip on the Magic Trackpad but a thumb-side strip scaled as a share of the width (3.85 mm) would have passed → T15 gains a Magic Trackpad thumb at (3.5, 10) expecting `[.two]`.
- Review: R5's "stays anchored" holds within one recognition run only; a restart judges a drifted thumb resting in the strip as an edge contact → a Further Note says so, with the palm-on-restart twin.
- Review: the acceptance criterion "no other existing test changes" would have forbidden fixing the `EdgeContactRecognizerTests` suite doc comment, which becomes false → "no other existing test body changes", and the suite doc comment is listed among the comments to update.
- Review: the docs criterion (`grep -c` at least 4) could not fail because the docs landed with the plan → it checks that the diff against origin/main touches exactly the five named entries.
- Review: the rejected `admits` alternative was said to "start a thumb touch", which a lone strip finger (`.none`) cannot → reworded to count toward a tap under an anchored thumb, open click blocking beside it, extend a thumb touch and stop a later thumb from arming.
- Review: `.none` proves only what the app controls, and macOS may count a resting graze among the contacts of its own swipes → the Strategy says so, and the optional hardware check now covers a click, a two-finger scroll and a three-finger desktop swipe under a resting graze, with the outcome to be recorded in Further Notes.

## Implement
