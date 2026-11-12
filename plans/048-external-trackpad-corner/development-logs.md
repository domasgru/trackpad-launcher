# Development logs: A thumb corner per trackpad kind

## Specify
- Swipe direction listed as corner-dependent, against the overview → R4 says directions are the same from every corner.
- Upgrade with both trackpads in use had no scenario → R6 scenario states the Magic Trackpad moves to bottom-left with no notice; notice added as a non-goal.
- Hold/Tap guide hidden for a new user with a Magic Trackpad → R7 scenario makes it explicit.
- R6 contradicted R3 for Macs without mixed trackpads → R6 qualified.
- R7 title said "in use" but meant "connected" → retitled; "last touched" added as a non-goal.
- Edge-contact scenario was untestable → replaced by swap, swipe and cross-trackpad scenarios in R4.
- Trigger list in R1 read as exhaustive (clamshell) → made an example; record scoped to the user's settings and the events it survives.
- Missing scenarios: MacBook-only upgrade (R3), live apply, force-quit and mirror change (R5), corner change in view (R7), illustrations on first connect (R2).
- R5's held thumb was ambiguous → judged afresh at once, as today.
- R2 listed the corners as "today's order" → listed explicitly; resize moved into the requirement.
- "connected" defined once in Terms; GIVENs reworded to "does not have mixed trackpads".
- R8 simplified to keep the existing setting's meaning as the MacBook corner.
- Declined: seeding the external corner from the current corner on upgrade (user chose Bottom left for all); adding the overview update to the PRD (documentation is the implement step's job).

## Plan
- Grounding, probe 02: v1.0.18 re-saves the `settings` record with its own keys only, so any fact stored inside the record fails R8's re-upgrade → the External corner lives under its own defaults key beside the record, which also keeps detection from writing the first-run sentinel.
- Grounding, probe 03: a `UserDefaults` set survives a SIGKILL right after it → R1 and R5 durability rests on one synchronous set, with no extra flush.
- Arena: both runners converged on the same whole shape (the `ThumbCorners` sum type, the new fact beside an untouched record, detection in `reconcile()`, resolved corners at the port, the full re-run kept, `Fit` gaining the row fact) → shipped the consensus shape; no dropouts.
- Red-flag screen, candidate 1: its `MixedTrackpads` held an External corner "in effect only once" a flag was set, a pair needing a comment to explain → kept candidate 2's one key, whose presence is the mixed-trackpads record.
- Cross-judge: candidate 2 recommended as base, 29 to 27, agreeing with the architect's scoring → base. Its public store methods and rule internals widened the surface → made internal. Its case against two keys argued from write atomicity, which did not describe candidate 1 → the recorded reason is the invariant.
- Cross-judge, candidate 1: its `[Trackpad: ThumbCorner]` port made `Run` order-insensitive, an unrequested change, and its adapter sketch indexed that map by ID → not grafted; kept `[TrackpadRun]`.
- Grafted from candidate 1: one read of the drawn corner passed down from `SettingsView.body`; the `connectMagicMouse()` handle; the R7 "corner not in view" assertion with `runCount`; R5's restart of the other trackpad put to the human as a question.
- Verification: the sketch showed only the real adapter's `run` → added the in-memory adapter's mirror. Six existing tests rest a top-left thumb on a Magic Trackpad beside the MacBook (`checks/01`) → recorded as a tradeoff R6 forces.
- Test planner: no test could observe the real adapter's join of listed devices to their corners, and no Magic Trackpad is at hand → the join became the pure `devicesToRun(_:_:)`, tested in LauncherPlatformTests (T30, S1).
- Test planner: the wake path could not be told apart from a hot-plug → added `InMemoryTrackpads.attachWhileAsleep(_:)`.
- Test planner: the design said seven illustrations where R7 lists eight → corrected.
- Test planner: `ThumbCorners` gets no rows of its own, because its rules are reached through `Launcher`'s two reads → the Next implementation step now matches S1.
- Test planner: T19 and T21 (c) assert the designed answers to two open questions → noted under Open questions.
- Docs: `docs/domain-model.md` updated before implementation (Thumb corner, Mixed trackpads (new), Trackpad, Anchor corner, Edge contact, First run, Settings window, Hide background apps setting) → the doc items in S2 and S3 became checks that the entries match what was built.
- Open questions resolved by the orchestrating session on safe defaults (/do runs without human review until Finish): restarting the other trackpad on a corner change is accepted, as today for every settings change; a login start writing the External corner key once is accepted; the key beside the settings record counts as "the user's settings"; an unreadable value counts as mixed with Bottom left. The Figma node 2231-13555 was captured as `plans/048-external-trackpad-corner/.temp/figma-thumb-corner.png` for M1 and the layout: "Thumb corner:" title, two indented rows "MacBook trackpad" / "External trackpad" each with a trailing corner pop-up, a divider, then "Hide background apps" switch.

## Implement
- Verification skill: none in the repo (`.claude/skills/verify-*` absent) → step skipped.
- Coordinator, mid-run: the Figma node was read into `design-spec.md`, and the human asked for it to be followed closely → the two-row group was rebuilt as one form cell (16 pt line spacing, rows indented 20 pt, system pop-up kept), overriding the plan's "match by eye" TODO.
- Review, standards: new verification helpers (`World.previousVersionSaves`, `convergesAfterAKillAnywhereIn`) reported failures at the helper → they take `sourceLocation:`.
- Review, standards: `world.login()!` in the new mixed-trackpads suite → `try #require`.
- Review, standards: `SettingsView`'s header comment still described one thumb corner row and 46 pt for every row → updated for the mixed-trackpads cell.
- Review, standards: `CornerPicker(fixedHeight:)` and bare layout literals → renamed `isFormRow`; spacing, indent and padding named on `ThumbCornerRows`, the indent applied once.
- Review, plan: the cell's 16 pt vertical padding added to the form's own cell padding → measured offscreen against the Hide background apps cell; 4 pt matches the design's edge-to-text distance.
- Review, plan: T11's control ran in a fresh world → it now runs under case (b)'s resting thumb.
- Review, standards: `opposite(of:)`, the fired count and the external-key reader duplicated across two suites → moved to `Fixtures.swift` and `World`.
- Human, after screenshots: gaps between the two pop-ups and from the second pop-up to the cell's edge measured 13 pt → 15 pt each (pop-up spacing 18, bottom padding 6), re-measured at 30 px at 2x on the running window.
