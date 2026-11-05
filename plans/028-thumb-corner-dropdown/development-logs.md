# Development logs: Four thumb corners

## Specify
- Window swipe direction from a bottom corner had no scenario → added a bottom-left window swipe scenario to R3.
- Top-corner side palm band had no regression scenario → added the opposite-edge scenario to R5.
- 2 mm release margin was not stated for bottom corners → added it to R2 with a "rolls too far" scenario; moved the "just outside" case to 25 mm, clear of the margin.
- Thumb tap at the bottom edge inside the corner was not covered → added a swap scenario to R4; R4 now says what an edge contact does.
- R5 leaned on "as today" → stated the band explicitly.
- R7 did not say today's guide behaviour → stated it and added *Top right* and *Top left* scenarios.
- R8 bundled three requirements → split into R8 (migration), R9 (first-run default), R10 (relaunch); the upgrade scenario now checks anchoring before any window opens.
- Solution did not trace R4, R5, R7 → added a sentence for each; added a Documentation section for the overview and glossary.
- Non-goal wording: tooling name dropped, side-band and downgrade reasons sharpened.
- Rejected: keeping the window-swipe arrows unflipped in bottom illustrations; the user chose a plain top-to-bottom flip.
- Found while checking the downgrade non-goal: an older version drops every setting when one value does not decode → added R11, a downgrade keeps the other settings and loads a bottom corner as the top corner on its side.

## Plan
- Planning found R1's last clause ("a thumb already anchored keeps working until it lifts") contradicts the domain model, where every settings change restarts recognition and a thumb already down is judged on the first frame → the clause now says the thumb is judged afresh and anchors only if it rests in the new corner; T1 proves it.
- T1's last step could never fail (`World.play` drops frames older than the last delivered, so a fresh script delivered nothing), its third step put thumb and finger on the fresh recognizer's first frame (spoiled, not judged against the corner), and the clause's positive half had no check → the steps continue one script with a 20 ms wait before the next tap, and a second world proves a contact already resting in the new corner anchors on the change.
- T23's centroid check would pass a whole-image flip (which also flips the card's lighting) and a slightly stale asset → it now compares the card outside the union of the mark masks (unchanged within 1 per channel) and the mark mask itself (the original's mirrored), with the script's own mark definition; the `-inverse` files are checked the same way.
- S2's manual downgrade check ran on the Debug build, whose settings macOS keeps apart from the release's, so 1.0.6 would have read untouched settings; and "the bottom corner is back" only held if nothing was changed in 1.0.6 → the check runs on a Release-configuration build in /Applications, and the re-upgrade clause is dropped (a non-goal).
- T25 called `savedSettings` "the 1.0.6 record" though it predates two keys → relabelled; T29 gains a record with all seven 1.0.6 keys.
- T28 left the swap switch at its default, so a dropped `isSwapOn` key would pass → `setSwap(on: false)` added and asserted.
- T26 used `World()`, which installs no Arc, so the tap could never bring Arc to front → `World(apps: ["Arc"])`; T22's (123.8, 53.76) row duplicated an existing row → dropped.
- T16 needed `blocksDockSwipes`, which `perFrame` does not report, and T9/T10's tuples carried only a thumb x → the edge-contact suite's per-frame helper takes `corner:` and the travel tests' tuples carry a thumb point; both named in the test-helper decision.
- The first decision said `ThumbCorner` exposes "only two" geometry queries while the band is keyed by the row → a row query is named, three in all.
- R6 and S3 said "the filled thumb dot", but in *Toggle recent* the thumb is the ringed mark → "the thumb's mark".
- The requirements' Documentation list named three domain-model entries and the decision seven → aligned; S2's docs criterion, already met by the planning-time edit, is reworded as a re-check against the code as built.
- The pop-up decision said the segmented control "and its group go; in their place, in the same group" → the control goes, its group stays holding one row.
- R4's "nor a swap" had no bottom-corner row → T30: an edge contact beside one resting finger makes no swap, beside two is not a third finger.
- S3's `cmp` of regenerated `-inverse` files could fail on byte-different encodings of identical pixels → compare decoded pixels.
- Between S2 and S3 a bottom corner shows top-corner pictures → the plan says S2 and S3 ship together; the Strategy says the view wiring is proved only by the manual criteria.

## Implement
- Review: new test lines negated Booleans inside `#expect` and packed four switch checks into one → `== false` comparisons and one expectation per switch.
- Review: the T23 bitmap reader force-unwrapped inside a throwing helper → `try #require`.
- Review: side and top/bottom were re-derived in two four-way switches in `Settings` and in `ThumbCorner`'s queries → `ThumbCorner.isLeft`, `isBottom` and `init(isLeft:isBottom:)` carry them once; "row edge" (no glossary term) renamed to "top or bottom edge".
- Review: T19 lacked the plan's `(.bottomRight, 123.8, 23.04)` row and T25 did not assert the rows and switches after the login start → both added; the illustration test lists corners through `allCases`.
- T23's mark-mask tolerance is 2%, not the plan's 1%: `window-swipe-bottom-inverse` differs in 15 of 1278 mark pixels (1.17%), all antialiased edges of its small marks; a stale or whole-image-flipped asset differs by far more. Kept, with a comment at the expectation.
- Kept against review: `ThumbCornerRow`'s explicit regular control size and accessibility label, both named by the plan.
- Full gate (`make test`) green after the fixes: 677 tests in 67 suites.
