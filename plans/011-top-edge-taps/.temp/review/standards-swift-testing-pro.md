# Standards review: macos-dev-workflow:swift-testing-pro

Range: `origin/main...HEAD` (af72489..59ded9d), file `LauncherKit/Tests/LauncherCoreTests/EdgeContactRecognizerTests.swift`, changed lines only.
Sources: `SKILL.md`, `references/core-rules.md`, `references/writing-better-tests.md`. The smell baseline is left out on purpose because the repo-standards review covers it.

Findings: 2 (both judgement calls, no hard violations).

## EdgeContactRecognizerTests.swift

### 1. Lines 163-165: the per-frame row gives no millisecond in its failure message (medium, judgement call)
Rule: swift-testing-pro, `references/writing-better-tests.md`, "Structuring tests": "Add user-facing messages to `#expect` and `#require` when they provide value." The slice (S1.md) applies this rule as "a per-frame row reports the frame's millisecond in its failure message as the suite's existing per-frame tests do", which means the `for`-loop shape at lines 236-240.

```swift
let recognized = recognitions(all)
#expect(recognized.map(\.blocksClicks) == [false, true, true, true, false, false, false])
#expect(recognized.map(\.blocksDockSwipes) == [false, true, true, true, true, true, false])
```
If this fails, the output is two 7-element Bool arrays, and the reader has to work out by hand which entry of `times` (0, 100, 1000, 2990, ...) went wrong. Suggested fix, following the suite's per-frame shape:
```swift
let clicks = [false, true, true, true, false, false, false]
let dock   = [false, true, true, true, true, true, false]
for (i, recognition) in recognitions(all).enumerated() {
    #expect(recognition.blocksClicks == clicks[i], "at \(times[i]) ms")
    #expect(recognition.blocksDockSwipes == dock[i], "at \(times[i]) ms")
}
```
The unchanged test at lines 289-290 compares whole arrays the same way, so the suite's precedent is mixed. That is why this is a judgement call and not a hard breach.

### 2. Line 142: an opaque Bool helper inside `#expect` (low, judgement call)
Rule: swift-testing-pro, `references/writing-better-tests.md`, "Writing good verification methods". When expectations are wrapped in a helper, the helper should expect and pass `sourceLocation`, so the failure shows real values.

```swift
#expect(phasesMatch(events.phases, [.began, .moved(travelMM: 4), ...]))
```
If this fails, the report says only `phasesMatch(...) -> false`, with no actual phases. The helper already exists (`Fixtures.swift:77`) and lines 277 and 309 call it the same way, so this new call follows suite convention. The cheapest fix inside this diff is a message: `#expect(phasesMatch(...), "\(events.phases)")`. Turning `phasesMatch` into a `verifyPhases(..., sourceLocation:)` helper would touch `Fixtures.swift`, which this slice must not edit (R6).

## Checked and clean
- No `!` inside `#expect`/`#require` (core-rules).
- Every parameterised test passes one tuple-array collection, so there is no Cartesian product (core-rules).
- The `@Suite struct` stays as the repo's convention, the tests have no `test` prefix, and nothing depends on test order (core-rules).
- Tests with several `#expect` lines (134-144, 168-177) still test one behaviour each (writing-better-tests).
