# Development logs: A palm brushing the trackpad edge is not a finger

## Specify
- No review round recorded: the requirements were written from the end-to-end reproduction (the recording and its replay through the real recognizer).

## Plan
- No row proved that an edge contact sliding inward stays an edge contact (every edge contact stayed inside the band, so a filter that re-judges a contact on leaving the band passed everything) → T12: a palm lands at 1 mm, rolls 2.5 mm inward to 3.5 mm, lifts; the next tap fires once, not twice.
- T4 and T10 claimed to prove the swipe's "begin", "join" and "move" clauses but could not fail without the fix (T4's palm moved vertically, so the pair spoiled either way; T10's palm landed with both swipe fingers down, so it only ever cancelled) → T4's palm now lands on the bottom edge and slides sideways, which begins a swipe before the fix; T13 added: after one swipe finger lifts, a palm lands at the bottom edge and slides 8 mm while the other finger moves, and the swipe must end on that finger's lift with travel from it alone. T10 now claims "cancel" only.
- A driver ID reused straight from a palm to a finger (no absent frame) was untested, so a filter that only ever adds IDs passed → T9(c) added; decision 2 says explicitly that an inward re-landing clears the ID.
- Every edge row sat at 1 mm, so a band measured as a surface fraction, or a y scaled by the width, passed → T7 parametrised over surface and edge: MacBook bottom edge and Magic Trackpad right edge at 2.5 / 3.5 mm.
- T1 described the recording's second fire as 200 ms after the first; in the recording the burst 208 ms later fired nothing (the thumb had slid past the hold margin) and the second fire came 5 s later after the thumb re-landed → T1 reworded as two bursts under one anchored thumb, with the compression noted. Problem statement's "at least 60 mm" corrected to "more than 57 mm" (nearest real finger at x = 67.2 mm).
- T5 did not say the palm stays down through the tap (if it lifted first the unchanged recognizer would fire too) → stated; the `.down` variant noted as needing `HandFrames`.
- Guard rows (T6, T7's "fires" rows, T8) were not labelled, so the implementer would expect them to fail first → each says it passes before and after and what it catches; the slice's acceptance criterion says which rows were seen red.
- Nothing pinned `admits` over `holds` as the corner carve-out → T2 gained the (26, 1) point: outside admission, inside the 2 mm hold margin, must fire nothing.
- T10 said the travel values were "exactly" 4 and 8, but travel is normalised coordinates times the width → `phasesMatch`, as the existing travel tests use.
- The R3 check said "grep for the number", which cannot work since `dragThresholdMM` is also 3.0 → grep for `edgeBandMM` (exactly two lines) and `git diff main -- docs/architecture.md` empty.
- Decision 4 left the `Recognition` doc comments ("another contact is down") as an optional rewording, though they become wrong → mandatory. Decision 2 now states `EdgeContacts` keeps `touches` in order, since `step` picks the thumb as the first admitted landing.
- The rows read `fired`, both blocking flags and swipe phases per frame but the existing `perFrame` returns only two of those → the new suite's one private helper returns the full `Recognition` per frame.

## Implement
