# Development logs: 5-finger gesture and the swipe switcher

## Specify
- A rolling 3-finger tap whose first two fingers skid 3 mm could start and cancel a swipe → scenario added: the switcher flashes, nothing opens; such a tap was already lost under plan 001's drag rule.
- Thumb and fingers lifting together was both "open" (R8) and "cancel" (R9) → a thumb lifting no more than 50 ms before the fingers counts as ended; whole-hand lift opens; the deliberate cancel keeps the fingers down.
- A switcher row wider than the screen was undefined → the panel spans the screen minus 40 pt margins and the row slides to keep the selected icon visible; icons stay 80 pt; 20-app scenario.
- A press during a swipe begun after the 3-second window clicked through → click blocking is extended for the whole of a swipe, like scrolling (R13); scenario added.
- A 2-finger tap drifting past 3 mm now flashes the switcher → accepted and named in a scenario.
- Full-screen apps and a second display unnamed → scenarios added.
- Momentum that began before the thumb anchored was unstated → momentum after an unsuppressed scroll is never interrupted (R14).
- R3's text allowed fingers landing before the thumb → "the thumb anchored before either finger landed" added to the conditions.
- Overview edits were implied, not listed → the amendments paragraph names them: five taps plus the swipe, the silent no-op lift as the one haptic exception, sound still deferred; glossary entries named.
- R6 read as two selection rules (step every 12 mm vs nearest icon) → rewritten: icons are 12 mm apart, the nearest wins, so the selection changes 6 mm in and every 12 mm after; travel is the midpoint of the two fingers from where the swipe began.
- "More than five distinct fingers" dropped "non-thumb" → fixed in text and scenario.
- Reduce motion ambiguous about the larger selected icon → still drawn larger, no size animation.
- Old R12 bundled eight behaviours → split into R12 (scroll under the click rule), R13 (whole of a swipe), R14 (momentum); later requirements renumbered to R15–R24.
- "A few millimetres" and "noticeably lighter" untestable → bounded to the first 3 mm of travel; the two haptics named *light tick* and *gesture haptic*.
- Vertical suppression inside the window had no rationale → one sentence in the Solution: one rule for clicks and scrolling.
- Missing non-goals → vertical swipes, quitting or hiding from the switcher, a cap on list length, window previews.
- Implementation language in the scroll requirement (per-event wording, Magic Mouse explanation) → removed; the reason stays in the non-goal.
- Rejected: dropping the context-menu Remove in favour of the hover button alone. The user chose both in the interview.
- User review: the thumb only starts a swipe → thumb lift, thumb leaving the corner and thumb re-landing no longer cancel; the 50 ms whole-hand tie-break removed; only a new finger outside the corner or an unblocked click cancels; blocking during a swipe holds whether or not the thumb stays (R8, R9, R13).
- User review: no handling of a switcher row wider than the screen → the sliding-row rule and its scenario removed from R10; recorded as a non-goal.

## Plan

## Implement
