# Development logs: Pick animation and a per-animation tuner

## Specify
- R4 contradicted the tuner's preview animating unpicked pickers → R4 names the tuner previews as the one exception.
- R11's scenario left out the shared controls → R11 lists what shows on every tab; "Release builds have no tuner" dropped.
- No scenario for a first assignment from "Choose app…" or a cancelled *Other…* → both added to R1.
- *Simulate Reduce motion* had no pick behaviour → R9 says it turns picks and Pick previews off, with a scenario.
- Easing source was ambiguous → R6 says the curve is fixed and the Launch tab does not affect it; the settle slows into 100%.
- R7 claimed the overshoot reaches the name, which the numbers may not allow → R7 now only requires the whole icon uncut.
- Hand-mode toggle named without a scenario → scenario added to R4.
- Pick preview with no installed app's icon, and the "not found" case, were unspecified → R14 disables the button then and skips "not found" and "Choose app…"; the Pick button reads *Preview in settings*.
- No default tab on first open → R12 opens on Launch.
- Preset play button on the Pick tab was undefined → R16 makes it play on the pickers, hidden on Bounce and Swipe.
- R12 did not trace to the problem → problem statement mentions the tuner forgetting its place.
- Haptic or sound on pick a likely assumption → added as a non-goal.
- Not applied: the scenario-restatement and multi-clause suggestions; each requirement stays testable as written.

## Plan
- Review: R1–R5, R8 and R9 rested on a World row that could not fail if the picker ignored the model's answer, never played or played on every render, with the visible behaviour left to a "by feel" checkbox → a `LauncherUITests` target is added. The representable's make and update become two internal functions taking the coordinator, which the tests call as SwiftUI does; picks go through the real menu (the coordinator builds it, the test fires the item's action at its target); the icon layer's keyframes are read back as `LaunchFlightTests` reads a stage's. Rows T7–T15 prove R1–R5, R8, R9 and R6's layer facts; T3 stays as the model's answer. A planning probe (`.temp/picker-seam-probe.swift`) confirmed this works with no window and no running application, and that `performActionForItem` does not, so the rows name the action.
- Review: the Core type exposed only `scale(at:)`, leaving the step count, key-time scaling and last key untested in the UI → `PickAnimation.keyframes(perSecond:)` in Core returns the key times and scales; T1 and T2 assert on it and the view only maps scales to transforms.
- Review: T1 passed for a linear settle, so "slowing smoothly into 100%" had no failing check → T1 asserts the last step's drop before 0.35 s is under a quarter of the settle's largest drop (the smoothstep gives about a twentieth).
- Review: R6's "centred on its slot" and "fully opaque" had no check → T7 asserts the layer's anchor (0.5, 0.5), opacity 1 and that the pick key is the only animation on it.
- Review: `Codable` on the Core type contradicted S2's "pick decoding inside `#if DEBUG`" and put tuner-only code in shipping Core → `PickAnimation` is `Equatable` and `Sendable` only; the tuner declares the JSON conformance retroactively in its Debug-only block beside the bounce's.
- Review: a preset's preview swapped in the preset's own *Simulate Reduce motion*, so with the switch on a preset play could animate against R9 → previews keep the current switch value (it belongs to no tab); S2's feel check covers a preset's play with the switch on.
- Review: Reduce motion was read both in the picker (D3) and in the shell's supplier (D5) → the picker reads no system setting; the rule is one pure function on the shell, `pickAnimation(reduceMotion:tuned:)`, which T15 proves; the shell passes the system flag.
- Review: `setAssignment` returned the parsed entry even when the catalog could not locate it (an app in the Trash through Other…), so the picker would animate a row showing "not found" → it returns the row's app only when present, nil otherwise; T3 adds the Trash step.
- Review: R4's manual step waited for a "not found" that never comes with the window open, since rows resolve only on start, a pick or an opening by hand → R4 is now T12 (renders never animate); the Trash step is gone.
- Review: S1 asked for a hand check of two menu picks within 0.2 s, impossible without the tuner → R8 is T13; the slowed-down visual stays as S2's feel check.
- Review: R12's step named no defaults key → the tab is `AnimationTuner.tab`; the step runs `defaults delete com.domasgru.TrackpadLauncherApp AnimationTuner.tab` and quits through *Quit Trackpad Launcher*.
- Review: leaving the Bounce tab would stop the bounce preview but leave *Preview bounce* showing on → D7 says leaving Bounce ends the preview and turns the switch off; R11's check covers it.
- Review: T2's "nothing else" named no assertion, T2 proved R13 from a slice that did not list it, and an exact "at 0.2 s" comparison would fail on `i / 84 × 0.35` → T2 names the landmarks that stay for each knob, S1 lists R13 in part (the knobs), and times compare within 1e-9.
- Review: a layer centred on the 17 × 16 slot would sit 0.5 pt right of today's icon, and the clipping fallback was unnamed → the layer takes the slot's leading 16 pt square (the probe measured the slot at 3 pt in); Further Notes name the `clipsToBounds` default and the fix if an ancestor clips.
- Review: the tuner window's rename had no requirement → kept, as following the docs' name for the tool, "Animation tuner".
- Rejected: none of the fifteen findings; all were applied in some form.

## Implement
- No `AGENTS.md` in the repo → full gate taken as a clean `Scripts/test.sh` plus `xcodegen generate` and a Debug `xcodebuild` of the app, as in plans 012 and 021. No `.claude/skills/verify-*` → verification-skill step skipped. The local `main` is stale, so the review used `origin/main` (`c9125b6`) as its fixed point.
- S1: a pick whose supplier gives nil (Reduce motion) or a pick of None also removes a running pick animation, so the swap is at once. `PickAnimation.scale(at:)` snaps times within 1e-9 of the peak and the end, so the sampled peak is exactly 1.1 and the last sample exactly 1.0.
- S2: the `PickAnimation` JSON conformance is a plain extension, not `@retroactive` (the compiler rejects it within one package); still inside the tuner's `#if DEBUG` block.
- Full gate after S2: green (15 + 153 + 574 tests, Debug app builds), only the existing `quinaryLabel` deprecation warning.
- Review: the picker bench compared the layer's keyframes only with `PickAnimation.keyframes`, restating the implementation → it also asserts R6's literals (85 samples, 0.4 first, 1.1 largest at 0.2 s, 1.0 last, uniform scales).
- Review: leaving the Bounce tab only cleared the flag, so the bounce preview could keep running depending on SwiftUI's ordering → the tab handler stops the preview itself; a second stop is a no-op.
- Review: T8's Other… runs could pass with no completion captured, and T13 never checked Mail's animation before the second pick → both asserted.
- Review: the pick-tuning tuple was spelled out at every site in the shell → `SettingsShell.PickTuning`; `showCurrentOnly` asked for the icon twice → once.
- Review, not fixed: the tuner's footer and preset play buttons' two per-tab switches (a shared helper would still switch at both sites); `tuned:` shipping in Release (D5's one pure rule, T15's seam); layer-detail assertions (the plan's R7, D2 and D3 checks); multi-step T3 and T12 tests (one scenario each); `TuningHook` and the wiring across files (D5, D6).
- Full gate after fixes: green (15 + 153 + 574 tests, Debug app builds, `swift build -c release` builds), no warnings from the branch.
- Not run (manual, needs a person at a running Debug app): R7's uncut overshoot on screen, R11, R12, R14, the by-feel checks of S1 and S2, and R9 under System Settings' Reduce motion.
- Human review in the running app: no hover, dead chevrons, heavy chevron and name, menu opened at its top, button briefly past the window after a pick, picked icon at full size before the animation → the picker is the system's pop-up in System Settings' style (private semantic context, chosen by the human), drawing its own display item, menu built with the row's app selected; see the plan's "Follow-up: the native pop-up".
