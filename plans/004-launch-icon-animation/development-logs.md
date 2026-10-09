# Development logs: Launch animation

## Specify
- No scenario for "does not delay bringing the app to front" → added "No delay to the target app" scenario to R13.
- Space-switch behaviour unspecified → R12 requires the icon to stay visible while macOS switches Spaces; new scenario.
- Pointer near the top edge uncovered → added scenario to R6: icon rises over the menu bar, cut off at the display edge.
- Same gesture twice not exercised → added "Same gesture twice" scenario to R14.
- Pointer over the launcher window only a non-goal → turned into an R4 scenario; non-goal removed.
- Motion requirement bundled five behaviours with no magnitudes → split into R6 rise (30–60 pt, accelerating), R7 shrink (≤ half size), R8 fade (before shrinking away), R9 sway (≤ a third of the rise, random), R10 tilt (≤ 5°), each excepting Reduce motion.
- Retina sharpness had no scenario → folded into R3's scenario.
- "About 500 ms" untestable → R11 says fully invisible between 400 and 600 ms.
- Trigger tied to haptic feedback → R1 triggers on the gesture firing; appears no later than the feedback.
- Wording fixes: R2 explains Tap to click makes gestures inactive; R5 scenario drops "first frame"; "Paths differ" uses ten launches.
- Solution now mentions Reduce motion and that the icon is the confirmation; non-goals add "icon until the app's window appears" and "finger-count indicator".

## Plan
- R1's "no later than the haptic feedback" knowingly broken by a first-ever icon render (45–120 ms) at the gesture; T1 claimed timing it cannot see → added `SystemActions.prepareLaunchAnimations(for:)`. `Launcher` passes the present assigned apps from `start()` and whenever it re-resolves rows; the overlay renders and caches their bitmaps. New World row T4 proves the icon is prepared before any gesture. T1's source no longer claims timing. The plan states its reading of R1.
- R14 proved by test rows and a manual check at once (T2/T3 cited R14 scenarios) → T2/T3 now cite R1 only; R14 is a manual check alone.
- Display choice sat in the untested overlay, and the stage took one display, so "external display above" could not be passed → `staged(at:among:)` chooses the display by AppKit's mouse rule (checked while planning: top edge in, bottom edge out), with a nearest-display fallback. Rows T18–T20 cover the top edge, the second display and the shared edge, all labelled R6.
- R4 (c) could be left pending forever → made required, listing four ways to get a real second display.
- Copying poses into Core Animation (the lean's sign, conversion to window coordinates) was checked only by eye → the flight now builds the exact `CAKeyframeAnimation`s the overlay adds, and the T9–T21 rows read their values, keyTimes and duration. The non-flipped layer tree is stated as a decision.
- R13 "no delay" rested on reading code and "no perceptible difference" → T1 captures through an `onPlayLaunchAnimation` hook that `broughtToFront` already holds the app when the animation is requested. The hardware A/B uses 240 fps film, with medians within 4 frames.
- Test rows cited manual-only requirements as sources, and R12 (c) repeated R6 → sources rephrased; R12 (c) cut down to "passes over the menu bar"; the design-mechanism checks are marked as not proofs of R5–R10 or R15.
- R8's thresholds were invented in a source column → moved into a "Readings of the requirements" list (R1, R8, R9, R11) for the requirement owner to confirm at plan review. The product requirements themselves are unchanged.
- A draw of exactly 0 had no side → 0 counts as right; 0 added to D.
- T19 restated `stage`'s algorithm ("whole reach, unclipped") → now T21: the frame lies inside the display, and every rotated keyframe square lies inside the frame.
- Sway's streak rule was promised in the domain model but untested → T14 asserts no three end drifts in a row on one side, for constant draws of 0.6, −0.6 and 0.
- "Reduce motion read fresh on every call" was unchecked → the fidelity check toggles Reduce motion while the app runs.
- The R13 click-through steps collided with plan 002's click blocking → the steps lift all fingers before pressing, and a recording confirms the icon covered the button.
- Four public LauncherCore types plus two custom geometry values existed only for the overlay → the flight moved into LauncherPlatform as internal types using CG and Core Animation types directly, tested through `@testable import`. The precedent is the trackpad adapter's own `feedbackActuation`.
- The warm-up might not warm what the probe timed → states `defer: false` and names the timed step (creating the window-server window). The icon's first-use cost is paid by the first prepare.
