# Development logs: Launch animation slant

## Specify
- Geometry admitted two builds (rotated path vs added sideways offset) → R1 and the glossary fix the rise's height and timing and add rise × tan(slant) sideways.
- Max sway 0 left the slant undefined → R2 ties the slant to the drawn sway share, not to Max sway, with a "Slant without sway" scenario.
- No round-trip for a new save → added R9.
- Angle scenarios were not observable by eye → Requirements now say they are judged on the recorded keyframes.
- R2 pinned only the ends → stated direct proportion and added a mid-point scenario (0.55 → 2.2°).
- "As before this change" phrasing → R3 lists the shipped numbers; scenarios name concrete observables.
- R4 read as a runtime clamp and only tested the end → reworded as a constraint on shipped numbers; noted the ratio only grows, so the end is the worst moment.
- Separate side-rule requirement restated R1 → folded into R1 as the "Third launch in a row" scenario.
- Reduce motion and bounce ending under-covered → added the Simulate Reduce motion scenario; R6 covers every ending that plays a launch animation, pop or not.
- Slider range untested → added a range-and-steps scenario.
- Added the problem statement's link from "rotation" to "slant", the third-of-rise rule's origin, and the non-goal "independent slant draw".
- Rejected: renaming the plan folder (the worktree and branch carry the name); lowering the 30° slider ceiling (the tuner is for exploring past the shipped limit).

## Plan
- T2 could not tell the share scaling the angle from the share scaling its tangent (2.206° and 0.401° both pass at shipped) → T9 gains Max slant 20° with draw 0.5 → 11° ± 0.02°, where the tangent version gives 11.32°.
- T1's sign-only check passed on today's code (the veer alone already puts the first rising keyframe 4e-6 pt to the side) → T1 requires at least 0.38° from straight up, and R1 is attributed to T2 too.
- R1's "the rise's height and timing stay the same" had no direct test; a rotated path only failed T6 by coincidence → T9 compares every keyframe's time and rise between Max slant 20° and 0 for the same draw.
- D2 let the icon tilt with Max sway 0, which the confirmed non-goal on the tilt rules out, and nothing pinned it → the tilt keeps today's guard (no lean when Max sway is 0), D2's edge-case bullet and the Further Notes entry are gone, and T3 asserts rotation 0 with Max sway 0.
- Strategy claimed T9 proves R7 whole and that the tests draw with the override at shipped, contradicting D1 → reworded: T9 proves what Max slant does to a flight; the slider and the overlay's read of the current tuning are checked by hand with exact steps in S1; the tests pass a tuning value and never read `LaunchTuning.current`.
- Further Notes called `swift build -c release` the check for R3 → R3 rests on T5, T2 and the unchanged `#else` branch; the Release build only shows no Debug code leaks.
- T12's fixture had every kept key at shipped, so a key wrongly falling back would pass → the fixture is the everything-away-from-shipped tuning (already Max sway 0.5) encoded before `maximumSlant` exists; it must decode to that tuning with Max slant 4.
- "Drift" meant the veer in D2 and all sideways movement in T6/T9 → D2 defines veer, slant and drift; Sway curve's comment is to say veer.
- Slips: 83 keyframes, not 82; S1 names Max slant's comment for the inequality too; T7 simulates Reduce motion with Max slant 20° rather than the shipped 4°.
- The *Launch bounce* entry read as if the slant made the ending swell on → reworded so the size clause carries "swells on" and the slant is its own clause.
