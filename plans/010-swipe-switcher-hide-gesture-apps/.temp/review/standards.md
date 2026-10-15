# Standards review: origin/main...HEAD (plan 010, S1)

Sources: docs/architecture.md, docs/domain-model.md, docs/product-overview.md, tdd/tests.md, tdd/mocking.md, plus the smell baseline.

No hard violations of architecture.md. The filter is a pure step inside the `Switcher` value type, and `LauncherCore` still imports only Foundation. No framework types cross a port. The tests run through `World` and its in-memory adapters, which fake only the system boundary (mocking.md). The changes to domain-model.md and product-overview.md match the code, and they use the glossary's words (assigned, missing, frontmost app, swap).

## Findings

### 1. SwitcherAssignedAppsTests.swift: two scenarios in one test (judgement call, tests.md)
tests.md, "Good Tests": "One logical assertion per test". `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst` builds two worlds, `some` and `every`. The second checks something the name does not mention:
```
let every = started(apps: ["Safari", "Mail"], frontmost: nil)
assign(every, ["Safari", "Mail"], to: [.one, .two])
every.swipe(3.5)
#expect(every.launcher.switcher == nil)
```
Fix: move it into its own test, e.g. `withNoFrontmostAppAndEveryRunningAppAssignedNoSwitcherShows`. `everyGesturesAssignmentCountsAndAnotherCopyOfTheBundleIsLeftOutToo` also names two behaviours, but it has a single assertion, so it is borderline.

### 2. Launcher.swift:213: possible Feature Envy, or a missing domain query (judgement call)
```
leavingOut: Set(settings.assignments.values.map(\.bundleID)), trackpad: event.trackpad)
```
The model reaches into `Settings`' raw dictionary to work out "the assigned bundle identifiers", a domain concept that the glossary now names in the Assignment entry. Fix: add a property on `Settings`, e.g. `assignedBundleIDs`, so the rule has one home and the call site reads in domain terms.

### 3. SwitcherAssignedAppsTests.swift `started(...)`: possible Duplicated Code (judgement call)
```
let world = World(apps: apps, accessGranted: accessGranted)
world.launcher.start()
world.makeRunning(running ?? apps)
world.makeFrontmost(frontmost)
```
This repeats the shape of `World.switcherWorld(accessGranted:)` in World.swift:202-208, with the apps, the running list and the frontmost app as parameters. Fix: give `switcherWorld` those parameters, keep its current values as defaults, and drop the private copy.

### 4. SwitcherAssignedAppsTests.swift `onlyAssignedAppsBesideTheFrontOne...`: call-count assertion (judgement call, tests.md red flags)
```
#expect(world.hardware.runCount == runs)
```
tests.md lists "Asserting on call counts" as a red flag. Two mitigating facts: `hardware` is a boundary fake, and SwitcherOnScreenTests.swift:228/348 already use the same idiom. So this follows the repo's convention and is low priority.

## Not flagged
- The name `leavingOut:` is fine: the glossary's Switcher and Assignment entries use "left out", and `Switcher` rightly stays unaware of gestures.
- In SwitcherOnScreenTests, switching the reconcile test's assignment from Mail to Figma keeps its intent now that Mail would be left out of the row.
