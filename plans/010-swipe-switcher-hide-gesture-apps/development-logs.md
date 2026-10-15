# Development logs: Switcher hides apps that have a gesture

## Specify
- No scenario checked that lifting after a hidden app opens the right one → added "Lifting after a hidden app opens the right one" to R1.
- No frontmost app with every running app assigned was uncovered → R4 widened to "no app without a gesture left to switch to"; scenario added under R5.
- R6's "changed during a swipe" clause was untestable and speculative → removed.
- "Row refills to 10" GIVEN was underspecified → states the other 11 have no gesture and names the 10th–12th apps.
- Product overview and domain model would describe the switcher wrongly → Solution states both are updated.
- Trash scenario leaked internal state and allowed two readings → reworded to observable steps; R1 states an assignment still hides its app when it can't be found on disk.
- "Bundle identifier" in R1 → reworded to "app that a gesture is assigned to".
- Scenarios compared against "before this change" → rewritten to concrete outcomes.
- R7 bundled four areas in one "exactly as before" → R7 is now the swap requirement only; the no-new-control scenario moved to new R8.
- Inconsistent "starts a swipe" / "slides two fingers" → "starts a swipe" defined once in Solution and used throughout.
- Rejected: dropping R4's click/scroll blocking clause. The domain model's Swipe entry already documents that behaviour.

## Plan
- The design claimed no model-level switcher test changes, but the mid-swipe reconcile test assigns the running Mail to the 1-finger gesture and expects a 12 mm slide to select Mail → "Existing tests" names that test and prescribes assigning an app that is not running, with the slice's green criterion pointing at it.
- T7's second `scroll(.fingers(.began))` would still drop: the shared `ScrollFilter` stays on its dropped treatment until the fingers' scroll ends → T7 checks `.fingers(.ended) == .drop` before `.fingers(.began) == .pass`, as `ScrollSuppressionTests` does.
- No row distinguished hiding by bundle identifier from hiding by the assignment's stored location → T2 runs a second copy of Arc from Downloads and expects both copies left out.
- The slice's TDD line asked for a red on rows that pass on today's code (T3, T10) or on T1's code → the Strategy and the slice say which rows are regression rows and which may pass without a red.
- The *Frontmost app* entry still said the row with no frontmost app is "the running apps alone", contradicting R5 → "the running apps without a gesture alone", and the design's Documentation lists the edit.

## Implement
- S1 (b19a265): all ten rows green in one pass; no red observed at the time → F1's red check: with `Switcher` ignoring `leavingOut` every leaving-out test goes red, and with missing apps skipped only the Trash test goes red.
- No verification skill in the repo; that step was skipped.
- Review fixes in F1 (6ef03d7):
  - the no-frontmost test bundled two scenarios → split in two;
  - T8(b) checked "no switcher" only after the lift → now checked mid-swipe;
  - T5, T7 and T8(b) checked "nothing" only in part → now check the full set, including launch animations;
  - `switcher?.` chains and a force-unwrap → `try #require`;
  - `Launcher` reached into the assignments map → computed `Settings.assignedBundleIDs`, with no stored field added;
  - the private `started(...)` helper duplicated `World.switcherWorld` → `switcherWorld` takes parameters.
- Rejected: the call-count assertion (repo convention on a boundary fake), the bare `@Suite` (repo convention), and dropping the no-assignment test that overlaps `SwitcherTests` (kept as a check through `Launcher`).
- Left for the human: R8's manual check of the launcher window and S1's hardware checks.
