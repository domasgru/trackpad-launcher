# Development logs: Simpler switchers

## Specify
- R5 (titles verbatim) traced to no problem, since titles are already shown verbatim → removed; kept as a Non-goal.
- R3's "same gap on all sides" failed literally for middle icons → reworded as the icon row's 22 pt padding, measured to the highlight; panel height stated as 22 + highlight + 22; added a single-app scenario.
- R4's shrink clause had no scenario → added "Column shrunk on a short display"; dropped the redundant "Same width on every window swipe".
- No scenario without Screen Recording → added one to the titles-cut-short requirement.
- R1's scenario also tested R2 → R1 now only checks that no name shows; R2 says "unchanged from today".
- Readers might assume the window switcher's padding changes too → added a Non-goal.

## Plan
- R5's one line and ellipsis had no listed proof; T9 only placed the title column → R5 moved to Verified without a test (grep for the row view's tail truncation and one-line limit, manual steps 3–5 with exact results); T9 re-tagged to R4 as the proof that the title column stays inside the fixed width at every scale.
- The slice never required the panel to read the moved `selectedIconScale`, so T6 could test a constant the drawing ignores → the decision and a slice criterion say `SwitcherPanel.selectedScale` goes and the transform reads the layout's value; `grep -rn "selectedScale" LauncherKit/Sources` must return nothing.
- The manual sequence lacked its preconditions (an app with a gesture is left out of the row) and a measurable width → added "no gesture assigned to Safari, Mail or Notes; swipe and window swipe settings on", and "720 px on a 2× display".
- T8 and T9 read `layout.scale` from the code under test, and T9's identity restated the derivation → both now expect the worked-example literals from 753 ÷ 754: 359.5225, 199.7347, 137.8170, 337.5517.
- The 14-, 15- and 30-icon rows test rows the product never builds (the row caps at 10), and the 15-icon row could not tell the new rule from the old within the suite's 0.01 → replaced by 10 icons on 1024 pt (gaps 22, today 22.07) and the 1036/1035 pt threshold.
- T6's scaled clause could never fail on its own → dropped.
- The interface description said `centreX(at:)` was unchanged (its formula changes; only the full-size value agrees), omitted that `rowWidth` goes, and dropped today's guard for an empty row → corrected; the span uses `max(iconCount − 1, 0)`.
- Further Notes claimed the icons stay put on screen; with the panel centred and 24 pt shorter, the row lands about 12 pt lower → reworded; also noted that shrunk icons come out a hair larger (79.03 vs 79.02 pt on 1024 pt).
- The domain model's new *Switcher* wording, "22 pt from the panel's top, bottom, left and right edges", was false for a middle icon, the slip the Specify round had already fixed in R3 → reworded to R3's: 22 pt above and below, 22 pt from the left edge on the first icon and from the right on the last.
- The record of test changes and the "pass today" claims did not match the table (T3, T6, T9 and T8's extension were missing; no new row compiles today) → one bullet lists every added and changed row; Before and after now says which values "would hold today".
- The architecture citation for the missing `LauncherUI` test target was not a real quote → cites `LauncherKit/Package.swift` and plans 008 and 012.
- The first decision read as a mandate to move the window row's badge and text insets into the layout → narrowed to the sizes that place the panel, the rows, the highlight, the icons and the title column.
