# Development logs: Automatic updates switch and Check for updates

## Specify
- R6 (now R7) forbade downloads that R7 (now R8) lets carry on → widened the off-state exception to a download already under way and to the alert's *Update*.
- *Update* didn't say whether it re-reads the list → R14: it reads once more and installs the newest newer version.
- No single rule for window openings during a download → new R16 "One download at a time".
- Overview's privacy statement would go stale → Solution names the overview and domain-model entries that change; Problem statement now says "if it can write to its own bundle".
- "Exactly as today" was untrue → "as today, apart from the row's button and the animated dots".
- Alert modality unspecified → R26: alerts are app-modal; added a Hide background apps scenario.
- R1 bundled position and look → split into R1 and R2; R2 points to `design/auto-updates.json` and covers dark appearance.
- Undefined terms, contradictory scenario → Terms extended; mixed-trackpads scenario split into two consistent setups.
- R17 and R20 bundled behaviours → split into R19/R20 and R23/R24/R25; added a stable VoiceOver label.
- "Animation stops while window closed" not observable → removed.
- R19 (now R22) alert text false for some copies → "This copy of Trackpad App can't update itself."; switch only saves its value there.
- R16 (now R18) failure text blames the connection → declined: the user agreed this text.
- Download failing with the window closed was unspecified → silent, no alert later (R19).
- No not-genuine scenario → added to R19.
- R7 (now R8) edges → added the dropped-window-check and failed-*Update now* scenarios, plus rules for in-flight manual and login checks.
- R4/R5/R8 scenario gaps → added survival-through-update, login-update and off-then-on scenarios.
- Manual check vs card unclear → R12: a manual check never adds the card.
- *Checking…* had no upper bound → 30-second limit, then the failed-check alert (R11).
- Dots requirement had no anchor → Problem statement says static dots look stuck.
- Missing non-goal → alerts or cards for results while the window is closed.

## Plan
- Grounding probe: `runModal` called from a main-queue block or a main-actor `Task`, as the move dialog does, blocks every main-queue job, gestures included → the update alerts' sessions start in a run-loop callout. The move dialog's own latent freeze is put to the human as an open question.
- Red-flag screen: candidate 2's offer handshake (an `.offered` event, `accept()`/`decline()`, and a reply held in the adapter) was the widest point on either port → replaced by candidate 1's synchronous `shouldDownload` question.
- Cross-judge: recommended candidate 2 as the base, 23 to 20, the same as my own scoring → candidate 2 is the base, with grafts from candidate 1.
- Cross-judge: candidate 2 armed the deadline from a `didSet`, outside `enter(_:)` → the deadline arms and cancels from `enter(_:)`'s diff.
- Cross-judge: *Update* over a running login download started nothing, so the hand-over could skip the window and a failure went silent → the user's download adopts the login download (R14, R19).
- Cross-judge: a click during the window's own check showed both the card and the alert, against R12's letter → the click takes that check's answer, and no card shows.
- Cross-judge: `Version` clashed with `CardContract.Version`, and the row's paddings were a TODO → `AppVersion`, and candidate 1's row arithmetic.
- Cross-judge: AppKit gives Escape to no *Not now*, and the alert bench would hang on a regression → an explicit Escape on *Not now*, and a test-only timer that aborts a held session and fails the test.
- Cross-judge: candidate 1's `withAnimation` ban was not asked for → not grafted.
- Verification checks C1-C4: `abortModal()` from a main-actor job and `terminate` during a modal both work. A two-button alert refuses a quit Apple event, so the update alert would cancel a logout → the presenter ends its session on `NSWorkspace.willPowerOffNotification`, hand check M10 was added, and *Quit Trackpad App* says the Dock's *Quit* waits for the alert.
- Test planner: the queued-download branches in the two login phases could not be reached → removed.
- Test planner: the switch's key had two rules that contradicted each other → the key's presence is the fact: present means off.
- Test planner: R3 had no handle to test the version read → `ThisCopy.version(of:)`.
- Test planner: the hand checks for the dots, the update alert, the logout and the card's refit needed a published release → the Debug-only `-PreviewUpdates <state>`, whose alert runs through the shipped session path.
- Test planner: the design's harness lacked four handles: a `Published` state after every fake delivery, `isAutomaticUpdatesOn`, `answersInside`, and preconditions on the fakes → added to the test seam.
- Test planner: the docs list missed *Quit Trackpad App* under the two-button alert, and *Hand-over* for the alert's *Update* → both added and written.
- Test planner: adoption and *Update now* during *Checking…* strain R10's, R11's and R12's wording, and R2's dark scenario cannot be observed → recorded as tradeoffs and open questions for the human, and R2's dark appearance becomes a hand check with the light pin removed locally. The requirements were not edited.
- Test planner, second pass: the `alert` preview had no path through the presenter → it is scheduled once from the presenter's init, through the same session code.
- Dropout: none. Both runners produced a candidate.

## Implement
- Review: six test rows checked less than their row says (T27 the button, T63 a `.found` ending an update cycle, T6(b) any event, T50 the process end and the new copy's watches, T64 only the final state, T65 the tap on one ending only) → each asserts its whole Then; the in-memory engine refuses `.found` while an update cycle runs, and T63 ends its declined cycle `.failed`, as the real engine does.
- Review: `UpdateAlertBench` left a defaults suite behind and force-unwrapped it → `try #require`, and the suite is removed at the end.
- Review: `Progress` shadowed Foundation's `Progress` → renamed `ProgressLabel`, the domain's term.
- Review: the `CheckDeadline` port sat in `Updater.swift` → moved to `Ports.swift` with the other ports.
- Review: the progress label's font was built in two places → one `ProgressDots.font(for:)`.
- Review: `UpdatesPreview` read and compared raw strings three times → one Debug-only `PreviewState`.
- Review: update-row test helpers were copied across three suites → shared in `LifecycleWorld.swift`.
- Human asked to fix the architect's move-dialog findings in this branch → reproduced end-to-end (Developer ID build in /tmp, `--at-login`, opened by hand): the session ran inside a Swift task job, and an `osascript` quit ended the dialog as *Move* and ran the move → addendum R27/R28, slice S6 (`294c5a8`).
- E2E check of S6: R27 holds (session under `__CFRunLoopDoBlocks`); the quit no longer moves but is refused (-128), as C4 found for the update alerts → R28 aligned with the update alerts (logout/restart/shutdown end it via power-off; other quits wait for an answer), domain model sentence corrected. A real logout stays a hand check.
