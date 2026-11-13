# Development logs: Settings window redesign

## Specify
- R1 and R4 disagreed on the 1-finger row's height → R1 now lists its rows by name and leaves out the 1-finger row.
- The Solution and R4 named the picture differently → both say "MacBook keyboard and trackpad".
- The no-thumb rationale implied fingers never move → R7 says the fingers move to their top-left places when the setting turns off, and that this is intended.
- "Corner drawn" was not defined → defined once from the domain model, with a scenario for mixed trackpads.
- The hand and label positions only worked with the hint card showing → given as offsets from the gesture group's top-leading corner, with label heights.
- The Switch windows row with its hint and the two-trackpad block had no measure → both keep today's layout inside the row, with a scenario each.
- "Text-only row" was undefined and over-constrained → R1 names the rows and centres their content.
- The 1-finger row with a second app had no defined layout → the picture stays pinned to the top, the hands keep their offsets, and scenarios cover both.
- Clipping was open → R4 says the group clips the picture and the picture never draws into the 2-finger row.
- "Light only" sat in the Solution without a requirement → moved to Non-goals (the window is already pinned to light).
- No scenario opened the window with Hold thumb off → added.
- R3 left the button gap, the update card alone and the no trackpad notice untested → scenarios added.
- The click-through scenario observed nothing → it now opens the 1-finger and 2-finger pickers.
- R6 (the old guide) restated R5 → folded into R5.
- "As today" mirroring could be built two ways → R6 states the visible result: the same card, with only the marks mirrored.
- The Problem statement said "both" for three problems → it now lists all three.
- Readers would expect the hands to mirror for other corners, and mockup details could conflict with the requirements → a Non-goal and a precedence rule added.
- Declined: putting Hold thumb into the product overview. The domain model's *Hold thumb setting* entry already defines which gestures fire without the thumb.
- Declined: moving the design's coordinates out of the requirements. They are the user's stated design and are observable.

## Plan
- R3's manual steps all showed a card, so the window with no card was never measured, and an empty block could have added a gap unseen → a step measures the gesture group 16 pt below the content's top with no card showing.
- T8 found the thumb with the script's own rule, the mark nearest the top-left corner, so it could not catch the script removing the wrong mark → T8 takes the thumb's place from the committed art: 7.6 pt from the card's left and top edges, with the change confined to 6 pt around it.
- The script's rim could be as narrow as 1.25 pt, where the card's rounded corners leave pixels a mark threshold would catch, nearer the corner than the thumb → the rim is at least 1.5 pt.
- The pictures were to be reduced when the app loads them, with a new test seam and T12, only because the exports are 9 to 19 pixels per point; T12 also checked the width it passed in → S1 resizes the seven large files to 4 pixels per point instead. The runtime reduction, its seam and T12 are gone, and S2 no longer claims R5's hand sizes. Listed for the user, since it changes files they exported.
- The width note said a long picker name would sit under the *Tap* label in a one-line row; the label is lower than that picker → corrected: only the minus button of a two-line first row with a long second app sits under it. S3's check 9 clicks that button through the label.
- The plan turned down a test seam for the window's measures on development cost → by hand stays the default, as in earlier settings window plans, but the seam is set out as a decision for the user: what it would prove (R1 to R3), what it would not (R4's and R5's drawing), and what it needs.
- The 10 pt between the form's groups is macOS's own and was measured only on macOS 27.2 → listed for the user, with what a different value on macOS 26 would require.
- S2's by-eye check of the first gesture's picture belongs to R6 and R7, which S2 did not list → S2 lists them for that part, and Strategy names S2 among the slices with by-eye checks.
- The one-proof-per-requirement note copied plan 037 without its offer to split the mixed requirement → the offer to split R5 into its rule and its drawing is listed for the user.
- R3's notice step said a MacBook can never show the notice, though the model treats a closed lid as the trackpad disconnecting → the step tries the closed lid first, then a Mac with no trackpad, then reading the diff.
- S2's criterion for the handwritten guide's removal named code identifiers → it states the result, and the command sits under Further Notes.

## Implement
- The user added R8 (a tall window scrolls) after planning → folded in as S4 after S3, so it does not collide with S2's work in the settings view: a pure height cap rule with its test T12, the settings view hosted in a scroll view, the cap applied on every fit and on a display change, and a by-hand check for R8. The domain model's *Settings window* entry states the cap.
- The user found the Hold and Tap labels slightly blurry → the dots are the user's `hold.svg` and `tap.svg` at their own size, the text is 11 pt medium, the fill and shadows sit on the background shape only, and the cards' block is rounded up to a whole point so the labels' anchor stays pixel-aligned.
- The labels used a solid grey, not the design's light Ultra Thick material (R5) → they use the material.
- A legacy scroller (scroll bars always shown, or a mouse) would take its width from the 358 pt content of a capped window (R8) → the document keeps its own width, and a capped window widens by the legacy scroller's width; the window refits when the preferred scroller style changes.
- New tests negated Booleans with `!` inside `#expect` (swift-testing-pro core rules) → they compare with `false`.
- The corner illustration script called no-thumb pictures "thumbless", a glossary word for a gesture → renamed to "no thumb"; its output is unchanged.
- The 70 pt first row, the 48 pt one-line row, the 358 pt column and the update card lookup were each written in more than one place → each is one named constant or one lookup.
- An unused `"svg"` default on the width-sized picture helper → removed.
- The architecture's push list did not name the settings window's display, screen parameter and scroller style changes → it does.
