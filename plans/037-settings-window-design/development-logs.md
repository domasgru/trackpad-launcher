# Development logs: Settings window design update

## Specify
- The release check answers after the window opens, so the "update known at open" scenario never happens → R1's scenario now has the update card arriving above a hint already showing.
- Nothing required the window to grow, and turning *Switch windows* on had no scenario → added a window-resize rule under Requirements and a "Turning the setting on" scenario to R4.
- "Constant speed, starting at" could mean a ramp → R3 now states a constant speed of one turn every 30 seconds; tuning stays a non-goal remark.
- R4 deferred to "as today", and R5 did not quote the messages → R4 states the rule (the first press ever asks, and that survives relaunches); R5 quotes both messages word for word.
- Reduce motion changing while the card shows was unspecified → R3 follows it live, with a scenario.
- R2 and R5 both set the Accessibility button's title, and R2 left a macOS prompt open → R2 points to R5 and says no prompt comes first.
- Smaller gaps → added the 20 pt card-to-hint spacing, the gear's 91 pt as a diameter, a "Permission already granted" scenario, a switch-name mapping, the non-goal exception for the R4 row, "as it does today" on the light appearance, what counts as "shown" for the gear, and a note that the frame shows the gear at rest.
- Not applied: a Screen Recording live-grant scenario (behaviour unchanged and covered by R4's rule), overview additions on Accessibility (outside this change), a scenario for pixel values (the frame is the stated target), naming the resize as instant or animated (unchanged), and asset location (planning's concern).

## Plan
- R3, R4 and R5 each had a test scenario and a Verified-without-a-test entry → R5 is T1 alone; R4 is manual alone (T7, a two-case switch through closures made for the test, was dropped and the hint view takes the launcher and actions like the gesture row view); R3 is T2–T6, with its by-eye checks moved to S1's acceptance criteria and their steps under Further Notes; the split of R3 into a visual and a rule requirement is offered to the user rather than made.
- R1's "Release check finds an update" scenario had no executable proof, since a Debug build has no updater → exact steps for a Developer ID copy with a lowered version in /Applications, restored by its own *Update now*.
- A live height change inside the Form had no evidence → the layout probe gained a `live` state: the fitting size is stale in the same turn but current by the `Observations` turn the shell reads it in; recorded under The column.
- The window-closed behaviour of the gear was asserted → the gear probe gained a `ca-hide` mode: the animation survives `orderOut`/`orderFront` and keeps advancing; a close-and-reopen and a minimise-and-restore check were added to the by-eye list.
- The idle check named a Debug build, which docs/performance.md forbids → it now runs the perf build and the sampler, with the shared-identifier grant reset called out.
- The first-press check depended on the saved ask surviving a `tccutil` reset → `defaults delete` of the Debug build's settings first, with the first-run prompt it causes; a reopen step for "Permission already granted" and the grant step for the hint's disappearance were added.
- R2 says blue while the decision followed the system accent → the accent stays, the domain model says so, and the reading is flagged for the user.
- The gear's direction was credited to T2 on an inference, and position was unasserted → T2 asserts position (45.5, 45.5); clockwise is a by-eye check.
- A hub off-centre in the SVG would pass T2 and T6 → T6 checks the drawn gear's alpha centroid against the centre, loads through `NSImage`, and the export's root size is normalised.
- The clip evidence covered a still gear offscreen → the `mask` mode is named as the fallback.
- An unbounded repeating animation was unrecorded in the architecture → one sentence under its animation rule.
- Scope: the filled button's disabled look dropped; the illustration-to-title gap measured at 8 pt and kept (the frame's 10 flagged), so no row moves; three wording fixes (the group view's constants, the probe numbers as "indistinguishable from still", the notice view's doc comment moved to S2).
- Not applied: reading Reduce motion from SwiftUI's environment instead of the workspace (the codebase reads the workspace in four places, the AppKit view is testable without rendering, and the environment's liveness in a closed hosting window is unverified); the bench detail that no test makes a window is now stated in the strategy.

## Implement
