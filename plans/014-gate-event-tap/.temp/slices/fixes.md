# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/014-gate-event-tap` (branch `feature/014-gate-event-tap`). Package in `LauncherKit/`. Do not commit; the orchestrator commits. Gate: `Scripts/test.sh` from the worktree root, green before you finish. Do not edit any existing `@Test` body other than the ones named below.

## F1. The fake's "scroll under way, unseen" flag goes stale

- Where: `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`, `scrollUnderWayUnseen` (declared ~line 24, updated ~lines 155-156 only on unsent events, read ~line 203 in the context).
- Rule broken: the plan's design, "The fake builds its context from what it actually withheld", and `TapContext.scrollMayBeUnderWay`'s doc: "Whether a scroll gesture may be under way that the gated port was never sent." Today the flag is cleared only by an *unsent* `ended`/`cancelled`, so a gesture whose `mayBegin` went unsent and whose `ended` was later *decided* (the gate had opened) leaves the flag true; a later thumb-first opening then resumes the scroll filter to `.unseen` and a bare `began` reads `.passStill` where it should read `.drop`.
- Fix decided: the flag means "the system's current fingers-scroll gesture has events the tap was not sent and has not since seen it end". Update it on every offered `.scroll(.fingers(phase))`, sent or not:
  - not sent: `.mayBegin/.began/.changed` → true; `.ended/.cancelled` → false (as today);
  - decided (the tap saw it): → false (the filter now holds the gesture's memory itself; an `ended`/`cancelled` ends it either way).
  Keep it not reset by `run` (it describes the system's event stream, not the tap). Update its doc comment to say exactly this.
- Add one World row (new `@Test` in `LauncherKit/Tests/LauncherCoreTests/TapGateTests.swift`) that pins it: two fingers rest with no thumb, `.scroll(.fingers(.mayBegin))` offered (`.notSent`); a thumb lands under them (gate opens); `.scroll(.fingers(.ended))` offered (decided); everything lifts (gate closes); then a fresh thumb lands alone, waits, two fingers land beside it, and `scroll(.fingers(.began)) == .drop`. Check the row fails before the fix (stilled) and passes after. Adjust the hand's timings to the suite's idioms (frames at or before the last delivered time are skipped by `play`).

## F2. `ClickTap.wake()` still acts after `remove()`

- Where: `LauncherKit/Sources/LauncherPlatform/ClickTap.swift`, `wake()` (~lines 77-81) and `remove()` (~lines 84-97).
- Rule broken: the plan's `wake()` contract, "Never waits; a no-op after removal." After `remove()` it still signals the invalidated source and wakes the stopped loop.
- Fix decided: `wake()` returns at once when the ports are gone: `guard ports.withLock({ $0 != nil }) else { return }` before reading the source (taking each lock one at a time, never nested). Do NOT make `remove()` write `runLoop` (its one writer is the tap thread). Keep the doc comment true.

## F3. Repeated context construction in `ClickTap`

- Where: `ClickTap.swift` ~lines 101, 113, 137: `TapContext.estimated(from: mergedBlocking())` written three times.
- Rule broken: Duplicated Code (the review's baseline smells); the estimate is the real tap's one view of the trackpads and should be stated once.
- Fix decided: one `private func context() -> TapContext` with a doc comment ("Tap thread: the trackpads as the real tap can see them, read before any of the tap's locks"), used by `handle`, `follow` and `recover`. Each call site still reads it before taking the filters' lock.

## F4. A notice-mask check that cannot fail

- Where: `LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift` ~lines 18-22, `theDisabledNoticesAreInNeitherMask`: `raw >= 64 || …` is always true for 0xFFFFFFFE / 0xFFFFFFFF.
- Rule broken: the tdd skill's tests rule that a test must be able to fail; plan T20 "the two disabled notices (0xFFFFFFFE, 0xFFFFFFFF) are in neither mask".
- Fix decided: assert instead that neither `CGEventType.tapDisabledByTimeout` nor `.tapDisabledByUserInput` is in `TapEvent.pressTypes` or `TapEvent.gatedTypes` (the lists the masks are built from), and that neither parses: `TapEvent(type, event) == nil` for a synthetic event of each type (as the file's other rows build them). Rename the test if its name no longer fits.

## F5. Misnamed resume test

- Where: `LauncherKit/Tests/LauncherCoreTests/FilterResumeTests.swift` ~line 45, `resumingWithNothingUnderWayForgetsAPassedCoast`, which checks that a *dropped* coast is kept (T15(f)).
- Rule broken: tests' names say what they prove (tdd skill, tests.md).
- Fix decided: rename to e.g. `resumingKeepsADroppedCoastThroughItsMomentum`; body unchanged.
