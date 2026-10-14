# Development logs: Thumb tap to swap apps

## Specify
- Fingers landing a few ms before the thumb could turn an intended tap into a swap → R6 requires both fingers down at least 100 ms before the thumb, with a scenario.
- A held thumb under resting fingers was unspecified → R6: it does not swap and becomes an anchored thumb once the fingers lift.
- Landing order across a thumb lift and re-land was ambiguous → R6 judges each thumb contact on its own.
- No Accessibility permission was unspecified → R9: the swap still works, nothing is blocked.
- R2 and R3 defined the target two ways → R2 is the single rule; R3 derives alternation, forbids stale order on rapid taps, and covers an app quitting or activating between taps.
- Rejected thumb taps were not asserted silent → R5 rule plus "no haptic" in every no-op scenario; Solution generalises the overview's haptic exception.
- Three phrasings for series end; drift vs. rejoin conflict; "briefly" unbounded → unified "until no finger rests outside the anchor corner"; a finger rejoins only while the other is down, its drift reference resets where it lands.
- Thumb press, one finger left resting, swipe-on/swap-off mirror, force-quit persistence → scenarios added.
- R10 bundled six behaviours → split into R10–R12.
- R12 (now R14) and tap window vague → inactive conditions and 400 ms named; R4 gains the ⌘-Tab qualifier; R1 references R6 instead of repeating it; R9 phrased as parity with the swipe.
- Scenario "Trackpad Launcher is active" was self-contradictory → corrected to bring Finder to front.
- Non-goals gained window swapping within one app and a thumb tap while the switcher shows.
- Rejected: renaming "launcher window" to the overview's "menubar window" (the glossary owns the term); removing doc paths from the Solution (prior plans use them); folding R15 into R2.

## Plan
- A delivered click cancelled a thumb tap, as it cancels a tap gesture, against R1's unqualified rule and R9's "the swap still works without the permission" → a press of either kind is part of a thumb tap (decision 2, glossary *Thumb tap*); T19 gains the no-permission press.
- The drift reference moving to each swap's position (R7) had no row that fails without it → T16 (b): 2 mm, swap, 2 mm more (4 mm from landing), swap.
- "A swipe that ends or is cancelled with contacts still down forms a rest" read literally would have turned the swipe's remembered thumb into a rest finger and broken four exit tests → the exit goes to spoiled with its remembered thumb as today; a rest forms only with no remembered thumb; the four tests listed as unchanged.
- A fingers-first thumb that leaves the corner without lifting was unspecified; the literal rules could arm an anchor outside the corner → it becomes a rest finger at once and nothing blocks from that frame (decision 1); T29 added.
- `World.play` drops frames older than any delivered, so chained independent hands in one World would pass vacuously → every lettered clause runs in its own World unless it continues the same hand; the Strategy says so and the rows are lettered.
- T23 had the thumb tap and then stay down → the thumb lands again and stays before the fingers lift; S3's hardware step reworded the same way.
- T14's re-landing 100 ms after the handover could not tell real landing times from a rest dated at the handover → re-land at 250 ms, 50 ms after the handover.
- S2 covered the recognizer state, the port, the model, the setting, the window, the fakes, the documents and 22 rows → split: S2 the swap always on, S3 the switch, S4 the series; S3 and S4 independent.
- R3 rows T6 and T8 sat in S2 without R3 listed there → S2 lists R3 (taps after the activation landed).
- An app that quits during its own activation would have been treated as in flight, giving a dead tap → the correction applies only while that app is still running; the genuine-reactivation blind spot recorded in Further Notes.
- The model's swap-setting guard was unreachable (a `swaps: false` recognizer never emits, the port drops replaced sessions) → dropped, as the swipe has none; the activity guard stays, reached by T27's injection.
- `SwapEvent`'s shape and the helpers' `swaps` default were left to guess → `SwapEvent(startsSeries:trackpad:)`; `swaps: Bool = true` on the `Fixtures.swift` helpers; direct constructions pass `true`.
- R1's "any length of time" had no first-swap row → T21 gains a 5 s rest.
- R2's hardware step lacked the windowless app; the Strategy credited plan 008's adapter tests with bring to front's semantics → Preview with every window closed added; the credit moved to the hardware steps.
- `isSwapOn`'s key name was pinned by nothing (round trips use the same code both ways) → T24 (e) loads a literal with the key; the old fixture's comment says it doubles as the upgrade proof.
- The one-per-rest stop latch is stricter than R7 in one contrived hand → recorded in Further Notes, not changed.
- "From the walk-through prototype" pointed at nothing; the intro said the lagging read comes from LaunchServices (the frontmost app is the workspace's) → both reworded.
- T28 and T23's recognizer half repeated the held-thumb-becomes-anchor proof T13 gives → their `.one` tails dropped.

## Implement
- A thumb that rolled out of the corner joined the rest and latched its stop (drift from its corner landing, or a third finger during a series), so its next landing under the same two fingers could not swap, against R6 → a rolled-out thumb is a rest finger that counts for neither the drift stop nor the third-finger stop; recognizer row added for both before and during a series.
- `RestThumb.isTap` meant "can still swap", not the glossary's thumb tap → renamed `canSwap`; `Recognition.swap` renamed `swapStartsSeries`.
- T1 asserted nothing only on the landing frame, not through 50 ms of hold → plays the hold too.
- T23's recognizer half checked that some frame blocked → checks both flags on every thumb-down frame.
- `docs/domain-model.md` said the model keeps nothing beyond the series in progress, while decision 7 replaces the memory only when the next series starts → the doc follows decision 7.
- Not changed: the `swipes`/`swaps` flag pair (decision 6 folds them at a third option); `setSwap` and the switch row mirroring their neighbours; multi-clause tests, which follow the plan's lettered rows.

## Change after hardware use
- The 100 ms minimum rest before the thumb tap made quick swaps fail on the trackpad; the user asked to drop it and revisit only if accidental swaps appear → R6 now needs only the fingers to land in an earlier frame than the thumb; `minRestBeforeThumbTap` removed; T11 and T21 rewritten (a thumb 10 ms or 20 ms after the fingers swaps; the same frame does not).
- Swaps failed during or after a scroll; the user asked that finger movement never matter, and to add restrictions only if problems appear → R7 rewritten (moving fingers still swap); the drift stop and per-swap reference reset removed from the recognizer; T15 and T16 rewritten; series blocking (R9) unchanged.
- The user asked for an illustration on the thumb tap row like the swipe row's → `assets/thumb-tap.svg` added (resting fingers solid, tapping thumb ringed, ⇄ mark) and shown mirrored in left-hand mode; the non-goal removed.
