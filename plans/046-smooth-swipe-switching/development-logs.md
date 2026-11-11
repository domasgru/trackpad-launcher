# Development logs: Smooth switcher travel

## Specify

## Plan
- S1's acceptance criterion allowed only added settles, rest frames and port deliveries, but a correct S1 also shifts frame counts, frame indices and event times in the hand-built tests and replaces Rule C's jump slides → the criterion lists those as the only other edits, and keeps "no expected travel, selection, tick, haptic or window order changes".
- T13 added a `.began` assertion the two reach tests do not have today, which S1's "nothing but rests" could not hold → dropped; the reach tests assert what they assert today.
- T1's pinned step (11.9, located by the prototype) was a golden value → worked by hand from the fixture's four frames (14.48 mm in all, 3.62 mm a frame, 57 counts, 99.0 points, 11.88) and cited that way.
- The stored count of swipe fingers on the last frame decided nothing: with at most two swipe fingers, "fewer than on the frame before" is always "only one down" → dropped from the slide state and the snippet, and the *Travel* entry says "while only one of the two swipe fingers is down".
- The plan's choice that a finger's first movement counts was pinned only for the first frame after the begin → T18 added for a finger that has just rejoined and is alone on its first movement.
- Further Notes understated what the "none is 0 mm" reading changes → all four affected hands listed with their totals.
- `settle()` was said to hold the window at 4; three rest frames only hold it at 4 or fewer → reworded, naming the rows that pin it exactly.
- "What is faked: nothing" ignored the in-memory adapters `World` runs over → "nothing new".
- T2 and T3 had no "Today" line for S2's red-before-green criterion → added. S2 and S3 listed scenarios as turning green that only stay green → the slices now say which turn green, which are re-derived and which are guards.
- T4 named no tolerance → 1e-9.
- The `RecordedSwipes` helper mirrors the adapter's parse rule without saying so, and named no slide kinds → it names `TouchFrame(parsing:count:timestamp:press:)` and replays with both kinds and swaps on.
- The glossary's "never leaps" read as absolute, though a fast flick still moves about an icon a frame → *Switcher* and *Travel* say the uneven report is evened out, without the absolute.
- The plan reported that R2, as worded, could swallow a lone finger's sustained movement: a discard left the reference where it was, so a finger that started abruptly was discarded on every frame (the prototype's hand stayed at 2 of 14) → R2 amended on the coordinator's decision: no finger is discarded two frames in a row, and the frame after a discard is counted and becomes the reference. Carried into the pseudocode (a one-frame mark per finger), the decisions, R2's new scenario, T19 (the hand ends at 11.6), S3 and the *Travel* entry.
- The plan reported that R2 was silent on a finger with no counted movement yet → R2 now states that its first movement is counted; the decision left the "decided here" list, and T10 and T18 cite R2.
- The plan reported that R2's first condition was redundant → R2 reads "while only one swipe finger is down".
- Re-check asked for with the amendment: both recordings replayed through the amended prototype → no number moved. T1's step is 11.88; T5's travel is 84.196, 84.254, 84.331, 84.386; R2 discards exactly swipe 4's frames at 1.136 s and 1.152 s; T6's sequence is unchanged; the same 26 existing tests fail and no other.
- The first amendment's cost, measured: a snap away and back on adjacent frames left the travel displaced by the back snap (the hand ends at −5.6 where the fingers moved +1.4) → not accepted. R2 amended again on the coordinator's decision: a discarded snap is remembered as a vector for 4 frames, a movement that undoes it (the two summing to at most half the snap's length) is discarded too, and the memory also goes when the finger lifts or two fingers are down again. Carried into R2's text and two new scenarios, the pseudocode, the decisions (the undo is judged first; an undo marks the next frame as counted like a snap does; a new snap replaces a remembered one), six constants, T20 (adjacent away and back ends at 1.4; a back of −4 is an undo, one of −3 is not), T21 (a turn on the fifth frame after the discard is counted, one on the fourth is the undo; both end at 6.8), S3 and the *Travel* entry. The "accepted" text is gone from R2 and Further Notes.
- Re-check after the second amendment, replays and snap hands only: swipe 2 has no discard and a step of 11.8816 at 0.512 s; swipe 4 discards 1.136 s as a snap and 1.152 s as its undo, travel 84.1963, 84.2538, 84.3312, 84.3855, no leap in either; T6 ends at 1.6 and T19 at 11.6, both unchanged; T20 and T21 read as their rows say.
- R3's lift rule questioned by the plan's own note (a flick lifted mid-movement can land one item short) → kept as written; T12 stays.

## Implement
