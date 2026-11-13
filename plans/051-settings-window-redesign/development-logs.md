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
