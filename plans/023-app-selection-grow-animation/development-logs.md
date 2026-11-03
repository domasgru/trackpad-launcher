# Development logs: Pick animation and a per-animation tuner

## Specify

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
