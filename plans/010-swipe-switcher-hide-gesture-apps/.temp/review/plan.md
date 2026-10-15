# Plan review: 010 switcher hides apps that have a gesture

Range: `origin/main...HEAD` (implementation in b19a265). R1–R8 all look implemented: `Switcher.init?` filters `others` by `leavingOut.contains($0.bundleID)` and the frontmost app is never filtered. `Launcher` builds the set from `settings.assignments` on `.began` and does not store it. The docs match design.md's "Documentation" section.

## (a) Missing or partial requirements
None.

## (b) Scope creep
None. The diff touches only `Launcher.swift`, `Switcher.swift`, the tests and the two docs.

## (c) Implemented but wrong
None found.

## (d) Test scenario gaps (all minor)
1. **T8(b) does not check the begin state.** Plan: "Begin: `switcher` nil; lift: nothing." The test calls `every.swipe(3.5)`, which lifts, and only then checks `switcher == nil`. That check passes after any lift, so "no switcher appears" is never observed. The `broughtToFront.isEmpty` and `pulses.isEmpty` checks would still catch a regression (Safari would be selected and brought to front). Fix: use `swipe(3.5, lift: false)`, check nil, then lift.
2. **"Nothing" is checked only in part in T5, T7 and T8(b).** testing.md: "'nothing' means nothing brought to front, no pulse, no launch animation and no switcher." None of the three tests checks `system.launchAnimations`, and T5 does not check `switcher` nil after the lift.
3. All expected values follow the table's sources of truth (scenario text), not the implementation. T1–T10 each have a test at the World seam in `SwitcherAssignedAppsTests.swift`. The edited reconcile test follows design.md "Existing tests" ("install one, assign it, expect the final tap to bring that app to the front"). Every existing `Switcher(...)` construction passes `leavingOut: []`.

## (e) Verified without a test
- **R8** ("the diff touches nothing under `LauncherUI`, `Settings` gains no field, and `SwitcherSection` keeps exactly its two toggles"): confirmed by reading.
  - The diff stat lists no file under `LauncherUI` and no `Settings.swift`.
  - `SwitcherSection.swift` has exactly two `Toggle(` and no other control.
- **R8 manual step and the S1 hardware checks**: unverified. They need hardware and stay with the human.
- **S1** ("the model's swipe path is its only production caller ... without storing it"): confirmed. `Switcher(` has one production call site, `Launcher.swift:211`, and the set is passed inline.
