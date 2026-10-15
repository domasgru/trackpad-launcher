# Standards review: macos-dev-workflow:swift-testing-pro (+ smell baseline)

Range: origin/main...HEAD, the 5 ledger files. No hard violations: no XCTest, no `!`-negated `#expect`, suites are structs with no-arg init, the parameterized test uses arrays of labelled tuples (not a Cartesian product), and there's no shared mutable state between tests.

## SwitcherAssignedAppsTests.swift

1. **Judgement: the test checks two behaviours.** swift-testing-pro, `references/writing-better-tests.md`, "Structuring tests": "prefer to test only one behavior in each unit test". Lines 133-152, `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGesture...`, builds two separate worlds (`some`, `every`). The second half (every running app has a gesture and nothing is frontmost, so there's no switcher) is a different behaviour. Fix: split it into its own `@Test`. Lines 41-58 (`everyGesturesAssignmentCounts...AndAnotherCopy...`) also join two claims in one name, but they share one setup, so that one is milder.
2. **Judgement: an optional precondition is checked with `#expect`.** `writing-better-tests.md`, "Expect vs require": "use `#require` for preconditions". Lines 31-32, 67, 91-92, 139-140 chain through `world.launcher.switcher?.…`. When the switcher is nil, each line fails on its own instead of stopping at one clear cause. Fix: `let switcher = try #require(world.launcher.switcher)`, then check its fields. This is the existing style in SwitcherOnScreenTests, so it's low priority.
3. **Judgement: `@Suite` with no name or traits** (line 5). `references/core-rules.md`: `@Suite` is "unnecessary" without a name or traits. All 40 test files in the repo use `@Suite struct`, so keep it for consistency. This is noted only for completeness.

## SwitcherTests.swift

4. **Judgement, in a touched line (pre-existing): force-unwrap in the `switcher(...)` helper** (`leavingOut: [], trackpad: Trackpad.macBook14.id)!`). `writing-better-tests.md`, "Expect vs require": "`#require` also unwraps optionals, which is cleaner than force-unwrapping". Fix: make the helper `throws` and use `try #require(Switcher(...))`.

## Smell baseline (all judgement calls)

5. **Possible Duplicated Code.** In SwitcherAssignedAppsTests.swift:17-23, `started(apps:running:frontmost:accessGranted:)` repeats the body of `World.switcherWorld` (World.swift:202-208) with the values made into parameters. Lines 43-44 then repeat the same setup by hand. Fix: add the parameterised builder to `World` and have `switcherWorld` call it.
6. **Possible Message Chain / Feature Envy.** In Launcher.swift:213, `leavingOut: Set(settings.assignments.values.map(\.bundleID))` walks into the settings' data to work out a domain fact ("the bundles that have a gesture"). Fix: give it a name on settings, e.g. `settings.assignedBundleIDs`.
7. **Possible Mysterious Name.** In SwitcherAssignedAppsTests.swift:134/146, the locals `some` and `every` don't say which world they stand for. Fix: names like `oneAssigned` / `allAssigned`. Finding 1's split removes this.

Switcher.swift and SwitcherOnScreenTests.swift: no findings.
