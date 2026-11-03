# S4 follow-up: a flow is not cut short by the finger follow

## Goal

S4's work is in the working tree, uncommitted, and green. It has one design flaw, which it hid by changing a test's stimulus. Fix the flaw, and restore the test to its planned form.

The flaw: after a selection change, the very next move event inside the row retargets both swell edges over `followTime` (1/60 s). Fingers almost always keep moving after they cross the half-step, so in a real slide the 108 to 180 ms flow collapses into a 17 ms jump. That breaks R6's look: "When the selection changes, the swell MUST flow from the old icon to the new one and wrap it … reach the new icon within 200 ms of the change, ending with a small wobble."

## Requirements

- **R6.** Quoted above. Its *one step right* scenario: with the first app selected, the fingers slide right past 6 mm. The liquid flows to the second icon, swells around it, and the first icon is left in a bead.
- **R5 and R15 still hold.** Between changes, the leading edge follows the fingers; the liquid responds without visible lag.

## Design

All in `LauncherKit/Sources/LauncherCore/Liquid.swift`.

- **The flow's arrival is a deadline.** Each edge's flow leg has a due time: the change's time + `leadShare × T` for the leading edge, and + T for the trailing edge, with T = min(`flowTime`, 0.2). `Liquid` keeps both due times as state.
- **A later call before that deadline does not shorten it.** When a call with an unchanged selection retargets an edge inside the row, the approach for that edge is max(`followTime`, due − time). So the edge still arrives at the flow's due time, now at the follow target (rest + lean). Once the deadline has passed, the approach is `followTime` as now.
- **The arrival velocity** stays the clamped estimate S4 uses.
- **A new selection change** sets new due times from its own time, as now. Retargets always start from each curve's current position and velocity.
- **The end pull and the spring-back are unchanged.** A pull happens only with `selected` at an end, after any flow onto that end. Apply the same max to the outer edge's approach if a pull call comes before the flow's due time.
- **The 200 ms reach still holds.** Every due time is at most 0.2 s after its change.
- **`shape(at:)` and the sampled tracks stay the same closed forms.**

## Rules that apply

- `docs/architecture.md`, Shape: "`LauncherCore` … imports Foundation and Observation only".
- Requirement bounds are `Liquid`'s private constants: "flow at most 0.2 s, settle at most 1 s, end pull at most 0.2 pitch."

## Skills

- `dev-workflow:tdd`: restore the row first and watch it fail against the current code, then fix.
- `macos-dev-workflow:swift-testing-pro`.

## Tests

In `Tests/LauncherCoreTests/LiquidFlowTests.swift`, `oneStepFlowsToTheNextIconWobblesAndLeavesTheFirstInABead` is T8. S4 changed its hand to `begin()` then one `move(toMM: 12, atMS: 50)`. Restore the planned hand: travel ramps from 0 to 12.0 mm in ten 10 ms events, reaching exactly 6.0 mm at the fifth, then rests 2 s.

| ID | Requirements | Seam | Given / When / Then |
|----|--------------|------|---------------------|
| T8 | R6, R4 | Liquid via World, injected travel | **Given** five apps. **When** travel ramps from 0 to 12.0 mm in ten 10 ms events, reaching exactly 6.0 mm at the fifth, then rests 2 s. **Then** the call at 6.0 mm returns `swell(at: 1)`, icon 1 with 0 < duration ≤ 0.2 s, and swell tracks. No played edge moves more than 0.5 pt across that instant, so the offsets were computed against the new rest. 100 ms later the right edge is strictly between the right edges of `swell(at: 0)` and `swell(at: 1)`: it flows, it does not jump. From 200 ms after the change, both edges are within `wobble` (4 pt) of `swell(at: 1)`'s, and the right edge crosses its rest at least twice (a wobble). From 1 s after the last event the played swell is exactly `swell(at: 1)` and does not overlap bead 0. |

How to read T8:

- **"No played edge moves more than 0.5 pt across that instant":** compare the played history with and without the change call, at the change's instant. That is how T9's row already reads its jump check, because a real edge legitimately moves about 1 pt per ms mid-flow.
- **"100 ms later":** the leading edge's due time is 0.6 × 0.18 = 108 ms after the change. At 100 ms it is still short of its target.
- **"From 1 s after the last event"** is 1 s after the travel's last moving event (at 100 ms), not after the change.

Every other row, T1 to T28, must stay green. If one fails because of this fix, its expectation probably assumed the cut-short flow. Report it with the reason, rather than loosening it silently.

## Starting point

S4 is in the working tree, uncommitted:

- `EdgeCurve` has a hold-then-return second leg and a value bound;
- `Liquid.follow` has the lean, the end pull and the turn back;
- `LiquidStretchTests.swift` holds T23 to T28;
- the one changed stimulus is in `LiquidFlowTests.swift`.

S4 also made two choices: T28 skips events that change the selection, and each edge's arrival velocity is its own target's velocity.

## Done when

- [ ] T8 is back to its planned hand and green. T1 to T28 and the whole suite are green: `Scripts/test.sh` from the worktree root.
- [ ] The app builds: `xcodegen generate` in the worktree root, then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
- [ ] Report whether the `LauncherUITests` real-window rows ran (look for their names in the `swift test` output).
- [ ] Do not commit. Report the files changed.
