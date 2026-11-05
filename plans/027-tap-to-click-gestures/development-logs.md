# Development logs: Gestures work with Tap to click and Look up on

## Specify
- Probe (`.temp/probes/tap-click-order.swift`, `episodes.py`) on the built-in trackpad, thumb in the anchor corner, Tap to click on: a 1-finger tap's left click arrives at the finger's lift, just after the lift frame; a 2-finger tap's right click arrives 275–285 ms after lift (Smart zoom on); 3/4/5-finger taps, a lone thumb tap in the corner and the swap make no click. Look up (3-finger tap) arrives as a type-29 gesture event with field 110 = 24; Smart zoom (2-finger double tap) as type 29 with field 110 = 22; both fire with the thumb anchored. Listen-only taps need Input Monitoring; the probe uses an active tap that passes every event.
- prd-reviewer: R5 (Smart zoom blocked) and R6 (gestures work without the permission when both settings are off) conflicted → R5 needs the permission; without it the zoom happens as today and Smart zoom never turns gestures off.
- prd-reviewer: R1's "no system setting makes gestures inactive" contradicted R6 → qualified with "with the Accessibility permission".
- prd-reviewer: the 0.5 s window was ambiguous against "a tap with no thumb clicks" → stated as a plain time window; the lost deliberate tap is a scenario and a non-goal.
- prd-reviewer: swipes and the swap were not checked against stray taps → R2 covers any tap of fingers that landed under the anchored thumb; scenarios for a short swipe lifting as a tap and for the swap.
- prd-reviewer: missing scenarios → added revoking the permission, Look up with Tap to click off, Smart zoom without the permission, a Magic Trackpad, Smart zoom off, taps 0.3 s apart, a tap-and-hold drag in the window, a quick tap right after a gesture.
- prd-reviewer: "today's click blocking rules" and "the Accessibility hint" undefined → spelled out in R3 and R9.
- prd-reviewer: R7 held four MUSTs and paraphrased the notice → split into R7–R11 with the exact notice text, and a live-update requirement.
- prd-reviewer: R6's "inactive" scope → covers all five gestures, the swipe, the window swipe and the swap.
- prd-reviewer: non-goals → added three-finger drag and Force Click; moved the tap-drag behaviour into R2.
- Rejected: updating the product overview's privacy note now. Docs change with the implementation.
- Rejected: dropping the uniform 0.5 s window for Look up and Smart zoom. One rule for all three is simpler.

## Plan
- plan-reviewer (critical): a lift window opened on every non-thumb lift inside a thumb touch would block a physical double click, or a click after a scroll, under a thumb rested past 3 s, breaking R3 and the "physical press rules unchanged" non-goal → the window opens only for a contact macOS could read as a tap: down for less than a tap action hold limit (measured in S1, `GestureRules.tapActionHoldLimit`) and with no press seen while it was down; T13 pins both conditions (a 1 s scroll, then a click that passes; two firm presses 300 ms apart, all passed); the domain model's *Lift window*, *Tap action* and *Swap series* say so.
- plan-reviewer: the tap-action rule's level branch and its pass branch had no row → T22 (Look up and Smart zoom offered before the lift under a thumb rested 4 s: dropped) and T34 (a thumb alone: passed).
- plan-reviewer: three existing tests would go red unnamed → `WindowSwitcherOnScreenTests.whileGesturesAreInactive…` builds its world without the permission, `DeviceSessionAnswerTests.theTapIsWokenOnly…` advances an injected clock, `TapGateRecoveryTests.tapToClickTurnsTheTapOff` becomes "with access, a Tap to click change keeps the tap and restarts it closed".
- plan-reviewer: the fake could not let time pass without frames, and two trackpads' script timelines made "latest frame time" undefined → the fake owns a monotonic `Uptime` clock with `advanceClock(by:)`; T35 proves the real "next event closes the gate" path.
- plan-reviewer: T15 never checked the press past the window's end → drags at L+300 and L+700, the release at L+1000.
- plan-reviewer: R7's and R9's button clauses were visible only in the view → `Launcher.inactiveNotice` (message plus optional `.openAccessibilitySettings` button) is a core value; T30 and T31 assert it.
- plan-reviewer: S1's ordering check was thin for the one assumption the long-rest case rests on → fifty taps per trackpad kind, the probe's callback does the app's pre-step work before taking the time, a 1 ms margin, and S3's hardware check counts twenty long-rest taps on a control.
- plan-reviewer: S2 could not ship alone, and a failed Look up finding would falsify its Look up half → S2 is blocked by S1 and the four slices land together (Further Notes).
- plan-reviewer (minor): T17's exact 500 ms boundary on `Double` frame times → 490/510; T8 and T21 timings corrected to 40 ms; "holds today" claims corrected to "after S2"; cost claims corrected (one clock read per frame while a window end is pending; the port stays on until the next frame or event, and a mouse's own events close it); T33 asserts `liftWindowIsOpen(at:)` rather than the stored end; T5 runs 1 to 5 fingers; T36 adds the window-swipe twin of T12; T31 pins the Accessibility hint beside the no-trackpad notice; S1 records other system gestures' type and field-110 numbers; `blockTapClicks` is computed as `blockClicks && Tap to click on`; the source-scan test confines `systemUptime`; the tap-refused edge is an accepted non-state.
- plan-reviewer: the swap-series window was speculative → gone with the hold limit; the swap scenario is checked on hardware in S1 and S4 and has no row.
- Open for the human: the no-trackpad notice loses the *Open Trackpad Settings…* button it shared with the deleted notice (R7's "ever" against R11's "as it is today"). The plan removes it; say if it should stay.

## Implement
- S1, hardware probe (built-in MacBook trackpad, macOS 27.2; no Magic Trackpad at hand; logs `.temp/probes/s1-drop.log`, readers `episodes.py`, `touches.py`):
  - **Drop suppresses both.** Drop mode on (type 29, field 110 = 24 or 22 returned nil): 56 Look up events and 11 Smart zoom events dropped; the user saw neither the Look up panel nor a zoom. With the drop off (earlier run) both appeared.
  - **Look up is a pair, not one event.** Every 3-finger tap that looks up sends two type-29 hid-24 phase-5 events within 0.3 ms, at the lift; same f169, the first carries f123 = 1 and f165 = 1, the second does not. Both carry f115 = f117 = f164 = 70 (likely the hot key's id). Each must be judged on its own; both fall in the same instant, so the rule drops both. Smart zoom is one hid-22 phase-0 event at the second tap's lift.
  - **Click after the lift frame.** Thumb rested 5 s, ~75 one-finger taps: every LEFT DOWN arrived after the receipt of the finger's first break frame (state 5, the frame the app reads as the lift): smallest gap 1.7 ms, largest 12.6 ms, typical 4–10 ms. The probe's callback did not do the app's pre-step work, so the app's real margin is smaller than 1.7 ms. Passes the 1 ms bar, narrowly.
  - **A robust discriminator exists.** Physical presses are preceded ~6 ms by a type-29 field-110 = 32 (force) phase-1 event; tap-to-click presses have no force event at all (pressure 1.00 and subtype 3 are identical for both). Recorded as the fallback for the ordering race.
  - **Hold limit.** Under the thumb, one-finger touches held 40–169 ms clicked; touches held ≤ 24 ms and every touch held 297–763 ms (10 of them) did not. Three-finger taps held 40–120 ms looked up; longer three-finger holds were not tried. `GestureRules.tapActionHoldLimit` = 400 ms (above the shortest hold seen not to act, 297 ms, with margin).
  - **The swap can click.** Two fingers resting, thumb taps in the corner: thumb landings at x ≈ 0.00–0.05 made no click, landings at x ≈ 0.07–0.08 made a LEFT DOWN 3–11 ms after the thumb's lift. No Look up from swaps. The swap fires on that lift frame, so the series' click blocking covers it when the swap setting is on; a row must pin that a click right after the swap's thumb lift is withheld.
  - **Other gestures.** Launchpad pinch and Show Desktop spread: type 30 hid 23 (Dock); two-finger swipe from the right edge: type 29 hid 6 (scroll); one two-finger gesture produced hid 8 and hid 4. No other hid-24 event was seen, so the parser stays on hid 24 alone.
  - Not done: Dragging (setting off), Magic Trackpad, Smart zoom double-taps with the thumb resting (an earlier run showed hid 22 arrives with the thumb anchored).
- S1 deviations folded into the slices: the Look up pair is judged event by event (S4's rows offer it twice); `tapActionHoldLimit` = 400 ms (S3); a swap's own thumb-tap click is pinned as withheld by the series (S3, T37).
- Kept the lift-frame design over the force-event discriminator for the long-rest case. The discriminator ("a press with no type-29 hid-32 force event ~6 ms before it is a tap's click") rests on facts S1 did not check and no agent can: whether the force event still comes with *Force Click and haptic feedback* off, on a Magic Trackpad, and never for a mouse's click. If any of these is wrong, it blocks physical presses every time under a thumb rested past 3 s, which breaks R3 and the "physical click blocking unchanged" non-goal for those users. The race it would close has not been seen: every one of ~75 clicks came after its lift frame, 1.7 ms at the closest, while the app's pre-step work takes microseconds. The press rule's comment records the assumption. S3's hardware check (twenty taps after a 5 s rest toggle a checkbox zero times) is the guard. If a click ever leaks there, the discriminator is the next step, once the facts above are checked on hardware.
- S2–S4 built as planned. Departures:
  - `DockSwipeFields` became `GestureEventFields`, since it now holds the tap actions' numbers too.
  - T14's click is offered at L+440, not L+410: `lift()` moves the cursor on for 40 ms. It is still inside the window.
  - Two of the nine named `TapGateTests` rows (`aPressStaysWithheldThroughTheThumbsLiftUntilTheButtonIsUp`, `aDockSwipeWarningThatSlippedThroughIsDroppedFromItsBeganOnceTheFingersAreDown`) needed no edit. Their fingers pressed or rested past the hold limit, so no lift window opens there.
  - T30 and T31 are two long rows in `ActivityTests`.
- Verification skill: none in the repo, so that step was skipped.
- implementation-reviewer findings fixed:
  - The frame thread read the injected clock while holding the session state's lock (two locks at once). The clock is now read outside the lock.
  - `TrackpadTapState.take` is named for what it returns.
  - The stale "trackpad settings notice" wording in `SettingsNotice`'s doc is gone.
  - `SettingsNotice` takes one optional button value instead of a title plus a dummy closure.
  - architecture.md now says the lift window opens when "fingers lift under the thumb" (it said "after a gesture").
  - Test tidy-ups: the compound `#expect` in T33 is split, and the T32 phase and field numbers are named. T5's grant half is now the five-app world and asserts inactivity first. T16 checks the gated port on every frame.
- Rejected review findings:
  - One enum in place of `blockClicks` + `blockTapClicks`: rejected, the plan's design.
  - Deriving `showsAccessibilityHint` from the cause: rejected, the plan's design.
  - Dropping the test-only `DeviceSession.liftWindowIsOpen(at:)`: rejected, T33's seam.
  - Negated `#expect` and plain `@Suite`: rejected, the repo's style.
- Accepted risk, not changed: a press withheld while a contact is down marks that contact as pressed, so its lift opens no window. Example: a late right click from a 2-finger tap arriving under the next touch's fingers. This needs macOS to send the delayed right click while a new touch is down. But it delays the right click precisely to watch for a second tap. A leak would also need that touch to lift after the earlier window ends yet within the hold limit. Recorded so the S3 hardware check can watch for it.
- Pending manual checks (need a human, not done):
  - S2's Debug-build notice check.
  - S3's checkbox counts (20 taps after a 5 s rest toggle nothing; two physical clicks after a 4 s rest toggle twice).
  - S4's Look up / Smart zoom checks and the final walkthrough of R1–R6, the swap scenario included.
  - A Magic Trackpad, and Dragging on.
