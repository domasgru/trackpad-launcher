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
