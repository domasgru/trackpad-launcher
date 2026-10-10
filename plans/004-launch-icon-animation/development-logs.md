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

## Implement
- S1 deviations from the plan:
  - T4's step order: the plan's "relaunch, then `start()` → [Arc]" could pass on the recorder's leftover value, since `World.relaunch()` keeps the same recorder → the row checks that creating the launcher prepares nothing before `start()` prepares.
  - `start()` rebuilds and prepares rows on every call, not only the first. The rows it produces are unchanged.
  - The icon bitmap is drawn at exactly 46 pt at the highest backing scale, in Display P3, instead of using the 128 px representation the probe got. The first, nearly still frames then map one to one onto the display.
  - An icon rendered at gesture time (the app moved since the last prepare) stays cached until the next prepare.
  - Extra rows: `missingTargetIsSilent` also checks that no animation plays. A new flight row checks that Reduce-motion flights do not count toward a sway streak.
- Review fixes:
  - Icons prepared while only a 1x display was connected stayed 46 px and were stretched on a 2x display (R3, "no blur") → the overlay re-renders a cached icon narrower than `46 × stage.scale` px. `prepare` and `play` share one render-and-cache path.
  - `play` could return after making a panel without closing it → `makePanel` returns the panel together with its host layer, so the only failure comes before any window exists.
  - T4 checked six behaviours in one test, against the "one logical assertion per test" rule → split into six tests. Gesture order now differs from assignment order, so the ordering check means something. The missing-app test keeps another app present, so an empty result cannot pass by accident.
  - Code wording drifted from the glossary's *Sway* ("lean") → `maximumTilt` and "tilt". The R10 test keeps the scenario's "leans".
  - `LaunchFlight` held `moves: Bool` plus `sway`, which allowed a non-moving flight with a sway → a `Motion` enum (`fadeInPlace`, `sway`). `Side` gained `opposite` and `sign`, replacing two switches.
  - `LaunchOverlay.live` → `playingPanels`.
  - T20 picked the built-in display only because it came first in the list → T20 also stages at (700, 982) among `[external, builtIn]`. The T14 and Reduce-motion streak rows now stage among both displays, per the plan's convention.
- Not changed: `WorkspaceActions` forwarding to the overlay, and the streak rule living in LauncherPlatform. Both are plan decisions ("no new port"; motion is rendering).

## Tuning
- The user polished the animation by feel in a Debug-only tuner window and picked their "Preset 2" → it is the shipped animation: 60 pt, 0.34 s, a 20 % pop over 75 ms, rise 70 pt, and new rise, shrink, fade and sway curves. New R16 (the puff). R3, R6, R7, R11 and R15 bounds follow the new numbers; R5 now rules out only growing in from a smaller size.
- Every animation number moved into `LaunchTuning`, whose defaults are the shipped animation. The tuner (`AnimationTuner`, `#if DEBUG`) stays in the codebase for future polishing; Release builds contain none of it.
- The icon bitmap is rendered at the pop's peak size, and keyframes are sampled at 240 per second so the short pop stays smooth.

## Merge with main
- Main (PR #2) made icon drawing an off-main-actor rule → `LaunchOverlay.prepare` renders on all cores away from the main actor and swaps the set in when done. `play` draws on the spot only when no ready icon is sharp enough.
- `openWindow` keeps both main's background scan and this branch's row resolution, so it also prepares the icons.
