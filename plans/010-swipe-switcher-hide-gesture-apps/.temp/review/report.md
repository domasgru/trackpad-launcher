# Implementation review: 010 switcher hides apps that have a gesture

- Branch: `feature/010-swipe-switcher-hide-gesture-apps`
- Fixed point: `origin/main` (858c61d). The worktree's local `main` ref is stale at 1cf9c4b, ten merged PRs behind; `origin/main` is the branch's merge-base, so the review used it instead of the stale local ref.
- Diff: `git diff origin/main...HEAD` (12 files: `Launcher.swift`, `Switcher.swift`, three test files, two docs, five plan files)
- Commits: `983a08e` Plan 010; `b19a265` S1: the switcher leaves out the apps that have a gesture
- Plan: `plans/010-swipe-switcher-hide-gesture-apps/plan.md`
- Skills ledger: `.temp/review/skills.md` (swift-testing-pro, tdd)
- No verification-skill step ran on this branch.

The two axes are kept separate on purpose; findings are not merged or reranked across sections.

## Standards


Sources: docs/architecture.md, docs/domain-model.md, docs/product-overview.md, tdd/tests.md, tdd/mocking.md, plus the smell baseline.

No hard violations of architecture.md. The filter is a pure step inside the `Switcher` value type, and `LauncherCore` still imports only Foundation. No framework types cross a port. The tests run through `World` and its in-memory adapters, which fake only the system boundary (mocking.md). The changes to domain-model.md and product-overview.md match the code, and they use the glossary's words (assigned, missing, frontmost app, swap).

### Findings

#### 1. SwitcherAssignedAppsTests.swift: two scenarios in one test (judgement call, tests.md)
tests.md, "Good Tests": "One logical assertion per test". `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst` builds two worlds, `some` and `every`. The second checks something the name does not mention:
```
let every = started(apps: ["Safari", "Mail"], frontmost: nil)
assign(every, ["Safari", "Mail"], to: [.one, .two])
every.swipe(3.5)
#expect(every.launcher.switcher == nil)
```
Fix: move it into its own test, e.g. `withNoFrontmostAppAndEveryRunningAppAssignedNoSwitcherShows`. `everyGesturesAssignmentCountsAndAnotherCopyOfTheBundleIsLeftOutToo` also names two behaviours, but it has a single assertion, so it is borderline.

#### 2. Launcher.swift:213: possible Feature Envy, or a missing domain query (judgement call)
```
leavingOut: Set(settings.assignments.values.map(\.bundleID)), trackpad: event.trackpad)
```
The model reaches into `Settings`' raw dictionary to work out "the assigned bundle identifiers", a domain concept that the glossary now names in the Assignment entry. Fix: add a property on `Settings`, e.g. `assignedBundleIDs`, so the rule has one home and the call site reads in domain terms.

#### 3. SwitcherAssignedAppsTests.swift `started(...)`: possible Duplicated Code (judgement call)
```
let world = World(apps: apps, accessGranted: accessGranted)
world.launcher.start()
world.makeRunning(running ?? apps)
world.makeFrontmost(frontmost)
```
This repeats the shape of `World.switcherWorld(accessGranted:)` in World.swift:202-208, with the apps, the running list and the frontmost app as parameters. Fix: give `switcherWorld` those parameters, keep its current values as defaults, and drop the private copy.

#### 4. SwitcherAssignedAppsTests.swift `onlyAssignedAppsBesideTheFrontOne...`: call-count assertion (judgement call, tests.md red flags)
```
#expect(world.hardware.runCount == runs)
```
tests.md lists "Asserting on call counts" as a red flag. Two mitigating facts: `hardware` is a boundary fake, and SwitcherOnScreenTests.swift:228/348 already use the same idiom. So this follows the repo's convention and is low priority.

### Not flagged
- The name `leavingOut:` is fine: the glossary's Switcher and Assignment entries use "left out", and `Switcher` rightly stays unaware of gestures.
- In SwitcherOnScreenTests, switching the reconcile test's assignment from Mail to Figma keeps its intent now that Mail would be left out of the row.

## Standards: macos-dev-workflow:swift-testing-pro


Range: origin/main...HEAD, the 5 ledger files. No hard violations: no XCTest, no `!`-negated `#expect`, suites are structs with no-arg init, the parameterized test uses arrays of labelled tuples (not a Cartesian product), and there's no shared mutable state between tests.

### SwitcherAssignedAppsTests.swift

1. **Judgement: the test checks two behaviours.** swift-testing-pro, `references/writing-better-tests.md`, "Structuring tests": "prefer to test only one behavior in each unit test". Lines 133-152, `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGesture...`, builds two separate worlds (`some`, `every`). The second half (every running app has a gesture and nothing is frontmost, so there's no switcher) is a different behaviour. Fix: split it into its own `@Test`. Lines 41-58 (`everyGesturesAssignmentCounts...AndAnotherCopy...`) also join two claims in one name, but they share one setup, so that one is milder.
2. **Judgement: an optional precondition is checked with `#expect`.** `writing-better-tests.md`, "Expect vs require": "use `#require` for preconditions". Lines 31-32, 67, 91-92, 139-140 chain through `world.launcher.switcher?.…`. When the switcher is nil, each line fails on its own instead of stopping at one clear cause. Fix: `let switcher = try #require(world.launcher.switcher)`, then check its fields. This is the existing style in SwitcherOnScreenTests, so it's low priority.
3. **Judgement: `@Suite` with no name or traits** (line 5). `references/core-rules.md`: `@Suite` is "unnecessary" without a name or traits. All 40 test files in the repo use `@Suite struct`, so keep it for consistency. This is noted only for completeness.

### SwitcherTests.swift

4. **Judgement, in a touched line (pre-existing): force-unwrap in the `switcher(...)` helper** (`leavingOut: [], trackpad: Trackpad.macBook14.id)!`). `writing-better-tests.md`, "Expect vs require": "`#require` also unwraps optionals, which is cleaner than force-unwrapping". Fix: make the helper `throws` and use `try #require(Switcher(...))`.

### Smell baseline (all judgement calls)

5. **Possible Duplicated Code.** In SwitcherAssignedAppsTests.swift:17-23, `started(apps:running:frontmost:accessGranted:)` repeats the body of `World.switcherWorld` (World.swift:202-208) with the values made into parameters. Lines 43-44 then repeat the same setup by hand. Fix: add the parameterised builder to `World` and have `switcherWorld` call it.
6. **Possible Message Chain / Feature Envy.** In Launcher.swift:213, `leavingOut: Set(settings.assignments.values.map(\.bundleID))` walks into the settings' data to work out a domain fact ("the bundles that have a gesture"). Fix: give it a name on settings, e.g. `settings.assignedBundleIDs`.
7. **Possible Mysterious Name.** In SwitcherAssignedAppsTests.swift:134/146, the locals `some` and `every` don't say which world they stand for. Fix: names like `oneAssigned` / `allAssigned`. Finding 1's split removes this.

Switcher.swift and SwitcherOnScreenTests.swift: no findings.

## Standards: dev-workflow:tdd


Range: origin/main...HEAD, the 5 files in the ledger. No hard violations. Tests go through `Launcher` with fakes only at the system boundary (system, hardware, registry), which fits tests.md "Integration-style" and mocking.md. Expected values are independent literals (the parameterized `row:` indexes, the fixed 9 rather than `switcherMaxApps`), so nothing is tautological.

### SwitcherAssignedAppsTests.swift

1. **Judgement: tdd, tests.md, Good Tests "One logical assertion per test".** `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst` builds two separate worlds (`some`, then `every`). The second scenario ("every running app has a gesture -> no switcher") is its own behaviour, so it should be its own test. Other names joined with "And" bundle two behaviours too: `everyGesturesAssignmentCountsAndAnotherCopyOfTheBundleIsLeftOutToo`, `onlyAssignedAppsBesideTheFrontOneShowNoSwitcherAndStayBlockedUntilTheFingersLift`. Each could be split along its "And".
2. **Judgement: tests.md, same rule.** `anAssignedAppIsLeftOutAndTheLiftOpensTheNextOneInTheRow` and `theFrontmostAppStaysAtTheLeftEnd...` check lift, haptic, trackpad id, `isWindowOpen`, scroll and press verdicts. That repeats lift and blocking behaviour already covered in SwitcherOnScreenTests, and it makes these tests break for reasons unrelated to leaving apps out.
3. **Judgement: possible overlap.** `withNoAssignmentTheRowIsStillTheFrontmostAppAndTheNineMostRecent` overlaps `SwitcherTests.theRowHoldsTheFrontmostAppAndTheNineMostRecentOthers`. It is still worth keeping as a check through `Launcher` that an empty `assignments` doesn't filter anything.

### Process gap (SKILL.md)

The implementer wrote the tests and the code in one pass, with no red run. That breaks SKILL.md "Rules of the loop: Red before green" and is the "Horizontal slicing" anti-pattern. It matters here because 10 behaviours were written at once and none was seen failing. A test could pass whether or not the filter works: the trash case passes only if `settings.assignments` keeps the bundle ID of a missing app. The new tests do not show whether they would fail without the change.

### Baseline smells (all judgement calls)

- **Duplicated Code**: `started(apps:running:frontmost:accessGranted:)` repeats the body of `World.switcherWorld` (World.swift:202) with parameters added. Generalizing `switcherWorld` would let both use one helper. `names(_:)` is also defined again, with a different signature, in SwitcherOnScreenTests.swift:10.
- **Mysterious Name**: the locals `some` / `every` in the no-frontmost test don't say what each world holds.
- **Feature Envy / Message Chains** (Launcher.swift:213): `leavingOut: Set(settings.assignments.values.map(\.bundleID))`. Launcher reaches into the settings' assignment map to work out a concept that settings could expose itself (e.g. `settings.assignedBundleIDs`).

### SwitcherTests.swift / SwitcherOnScreenTests.swift / Switcher.swift

Mechanical `leavingOut: []` threading, plus moving the reconcile test from Mail to Figma so it keeps the behaviour it was written to test. No findings.

## Plan


Range: `origin/main...HEAD` (implementation in b19a265). R1–R8 all look implemented: `Switcher.init?` filters `others` by `leavingOut.contains($0.bundleID)` and the frontmost app is never filtered. `Launcher` builds the set from `settings.assignments` on `.began` and does not store it. The docs match design.md's "Documentation" section.

### (a) Missing or partial requirements
None.

### (b) Scope creep
None. The diff touches only `Launcher.swift`, `Switcher.swift`, the tests and the two docs.

### (c) Implemented but wrong
None found.

### (d) Test scenario gaps (all minor)
1. **T8(b) does not check the begin state.** Plan: "Begin: `switcher` nil; lift: nothing." The test calls `every.swipe(3.5)`, which lifts, and only then checks `switcher == nil`. That check passes after any lift, so "no switcher appears" is never observed. The `broughtToFront.isEmpty` and `pulses.isEmpty` checks would still catch a regression (Safari would be selected and brought to front). Fix: use `swipe(3.5, lift: false)`, check nil, then lift.
2. **"Nothing" is checked only in part in T5, T7 and T8(b).** testing.md: "'nothing' means nothing brought to front, no pulse, no launch animation and no switcher." None of the three tests checks `system.launchAnimations`, and T5 does not check `switcher` nil after the lift.
3. All expected values follow the table's sources of truth (scenario text), not the implementation. T1–T10 each have a test at the World seam in `SwitcherAssignedAppsTests.swift`. The edited reconcile test follows design.md "Existing tests" ("install one, assign it, expect the final tap to bring that app to the front"). Every existing `Switcher(...)` construction passes `leavingOut: []`.

### (e) Verified without a test
- **R8** ("the diff touches nothing under `LauncherUI`, `Settings` gains no field, and `SwitcherSection` keeps exactly its two toggles"): confirmed by reading.
  - The diff stat lists no file under `LauncherUI` and no `Settings.swift`.
  - `SwitcherSection.swift` has exactly two `Toggle(` and no other control.
- **R8 manual step and the S1 hardware checks**: unverified. They need hardware and stay with the human.
- **S1** ("the model's swipe path is its only production caller ... without storing it"): confirmed. `Switcher(` has one production call site, `Launcher.swift:211`, and the set is passed inline.
