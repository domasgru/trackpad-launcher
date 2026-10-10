# Development logs: Smaller launch icon and launch animation setting

## Specify
- Persistence could be satisfied by saving only on clean quit → R8 requires saving on change, with a force-quit / restart scenario.
- R2 bundled seven clauses and referred to "as they are" → split into flight geometry (explicit 44–52 pt puff, 40–53 pt rise at the icon's centre, ≤24 pt end) and timing (300–400 ms); sway and tilt moved to the non-goal on unchanged character.
- "Nothing on screen" contradicted the app coming to front → off now means no launch icon or other visual at the pointer.
- Untested clauses → added scenarios for the switch showing off, the launcher window closing and a not-running app with the animation off; upgrade must not change other saved settings.
- Unreachable "animation already playing finishes" clause → removed.
- Sharpness named only Retina → now Retina and non-Retina.
- Not applied: updating the product overview's "hand mode toggle missing in design" note; the shipped window has the toggle.

## Plan
- The flight's transform keyframes are relative (side ÷ icon side), so the keyframe helper's hard-coded start side would report 40 at t = 0 with the icon still at 60; T1, T2, T4 and the Reduce-motion row could not fail on the main change → the helper reads the stage's `iconSide` (the layer's bounds the overlay sets), T1 asserts that `iconSide` is 40, and the decision records why the transform alone cannot carry the size.
- R1 was proved by a manual check and, in disguise, by T1 and T5 sourcing their 40 from it; T5 proved nothing about R2 → T1 is motion-only and takes its 40 from R2's own arithmetic (44–52 is 110–130 % of 40); the Reduce-motion rows are retargeted existing rows under plan 004's R5 and R15; the "geometry beneath" sentence is gone. Splitting R1 into size and sharpness in the PRD would let the size be test-proven; left for the user to decide.
- "A record missing any field decodes with its default" was a slice criterion nothing checked, and "any record any version wrote decodes" overstated (a bad value still fails the record) → new World row T10 (an empty record loads as the defaults, not a first launch); the rule is narrowed and goes in `Settings`' doc comment.
- "Prepare while off" leaned on R7 but nothing checked it; T13 passes even if preparing depended on the setting → recorded as a performance decision (no cold render on the first gesture after turning on) and pinned by World row T14.
- The "saved at once" row repeated the relaunch row's mechanism and claimed more than it proved about the preferences daemon → dropped; T15's source states what the relaunch proves and what rests on `UserDefaults`' contract.
- The R1 manual check expected "80 px square", which cannot be measured (artwork fills about 80 % of its canvas; the first 60 fps frame may be 16 ms into the puff) → measures the artwork's rounded square, uses Reduce motion for an un-puffed start frame, gives ranges at 2× and 1×, and corrects the low-resolution display steps.
- Naming and comments: the field and plist key are named `isLaunchAnimationOn`; T3's test is renamed from "60And80" to "40And53" and its "faster and faster" clause cites plan 004's R6; the launcher view's doc comment gains the switch; the port's "about 500 ms" comment becomes a third of a second.
- The R4 manual check repeated R6 and R7's gesture steps → trimmed to the switch's placement, label, state and accessibility.
