# Standards review: dev-workflow:tdd (tests.md) + smell baseline

Range: origin/main...HEAD, the 5 files in the ledger. No hard violations. Tests go through `Launcher` with fakes only at the system boundary (system, hardware, registry), which fits tests.md "Integration-style" and mocking.md. Expected values are independent literals (the parameterized `row:` indexes, the fixed 9 rather than `switcherMaxApps`), so nothing is tautological.

## SwitcherAssignedAppsTests.swift

1. **Judgement: tdd, tests.md, Good Tests "One logical assertion per test".** `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst` builds two separate worlds (`some`, then `every`). The second scenario ("every running app has a gesture -> no switcher") is its own behaviour, so it should be its own test. Other names joined with "And" bundle two behaviours too: `everyGesturesAssignmentCountsAndAnotherCopyOfTheBundleIsLeftOutToo`, `onlyAssignedAppsBesideTheFrontOneShowNoSwitcherAndStayBlockedUntilTheFingersLift`. Each could be split along its "And".
2. **Judgement: tests.md, same rule.** `anAssignedAppIsLeftOutAndTheLiftOpensTheNextOneInTheRow` and `theFrontmostAppStaysAtTheLeftEnd...` check lift, haptic, trackpad id, `isWindowOpen`, scroll and press verdicts. That repeats lift and blocking behaviour already covered in SwitcherOnScreenTests, and it makes these tests break for reasons unrelated to leaving apps out.
3. **Judgement: possible overlap.** `withNoAssignmentTheRowIsStillTheFrontmostAppAndTheNineMostRecent` overlaps `SwitcherTests.theRowHoldsTheFrontmostAppAndTheNineMostRecentOthers`. It is still worth keeping as a check through `Launcher` that an empty `assignments` doesn't filter anything.

## Process gap (SKILL.md)

The implementer wrote the tests and the code in one pass, with no red run. That breaks SKILL.md "Rules of the loop: Red before green" and is the "Horizontal slicing" anti-pattern. It matters here because 10 behaviours were written at once and none was seen failing. A test could pass whether or not the filter works: the trash case passes only if `settings.assignments` keeps the bundle ID of a missing app. The new tests do not show whether they would fail without the change.

## Baseline smells (all judgement calls)

- **Duplicated Code**: `started(apps:running:frontmost:accessGranted:)` repeats the body of `World.switcherWorld` (World.swift:202) with parameters added. Generalizing `switcherWorld` would let both use one helper. `names(_:)` is also defined again, with a different signature, in SwitcherOnScreenTests.swift:10.
- **Mysterious Name**: the locals `some` / `every` in the no-frontmost test don't say what each world holds.
- **Feature Envy / Message Chains** (Launcher.swift:213): `leavingOut: Set(settings.assignments.values.map(\.bundleID))`. Launcher reaches into the settings' assignment map to work out a concept that settings could expose itself (e.g. `settings.assignedBundleIDs`).

## SwitcherTests.swift / SwitcherOnScreenTests.swift / Switcher.swift

Mechanical `leavingOut: []` threading, plus moving the reconcile test from Mail to Figma so it keeps the behaviour it was written to test. No findings.
