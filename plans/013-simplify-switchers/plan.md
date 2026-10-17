# Plan: Simpler switchers

## Problem statement

The switcher shows the selected app's name under the icons. The icons already say which app is selected, so the name adds clutter. It also makes the panel taller below the icons than above them, so the panel looks unbalanced.

The window switcher changes width from one window swipe to the next. Its width follows the longest title, from about 340 pt up to about 480 pt. A panel that grows and shrinks feels unsteady, and a wide one covers more of the screen than it needs to.

## Solution

The switcher shows icons only. The space around the highlight is the same on all four sides.

The window switcher is always 360 pt wide. Each row shows the window's title exactly as the app gives it. A title that does not fit is cut short at the end.

## Requirements

### R1. The switcher shows no app name
The switcher MUST show only the icons and the highlight. It MUST NOT show the name of the selected app or of any other app.

#### Scenario: Moving the selection
- **GIVEN** a swipe showing Safari, Mail and Notes, with Safari selected
- **WHEN** the fingers slide right until Mail is selected
- **THEN** no app name appears anywhere on the switcher

### R2. The switcher's selected icon stays larger
The selected icon MUST be drawn larger than the others, unchanged from today, and it MUST stay inside the highlight.

#### Scenario: Selection on the frontmost app
- **WHEN** a swipe begins
- **THEN** the frontmost app's icon, at the left end, is drawn larger than the other icons and sits wholly inside the highlight

### R3. The switcher's padding is equal on all sides
The icon row MUST sit 22 pt from the panel's top, bottom, left and right edges at full size, measured to the highlight's edge, so the highlight on the first icon is 22 pt from the left edge and on the last icon 22 pt from the right edge. At full size the panel MUST be 22 pt + the highlight's height + 22 pt tall.

#### Scenario: Highlight on the first icon
- **GIVEN** a switcher showing at full size, with the first icon selected
- **THEN** the highlight sits 22 pt from the panel's top, bottom and left edges

#### Scenario: Highlight on the last icon
- **GIVEN** a switcher showing at full size
- **WHEN** the selection reaches the last icon
- **THEN** the highlight sits 22 pt from the panel's right edge

#### Scenario: Single app
- **GIVEN** a switcher showing exactly one icon at full size
- **THEN** the highlight sits 22 pt from all four edges

#### Scenario: Shrunk row on a narrow display
- **GIVEN** a display too narrow for the row at full size, so icons and gaps shrink by one factor
- **THEN** the gaps above, below, left and right of the highlight are still equal to one another

### R4. The window switcher is always 360 pt wide
The window switcher panel MUST be 360 pt wide at full size, whatever the length of its titles. When the column shrinks to fit the display, the width MUST shrink by the same factor as the rows.

#### Scenario: Short titles
- **GIVEN** a frontmost app whose two windows are titled "A" and "B"
- **WHEN** a window swipe begins
- **THEN** the window switcher is 360 pt wide

#### Scenario: Long titles
- **GIVEN** a frontmost app with a window whose title is far wider than the row
- **WHEN** a window swipe begins
- **THEN** the window switcher is 360 pt wide

#### Scenario: Column shrunk on a short display
- **GIVEN** a display too short for the column at full size, so the rows shrink by one factor
- **THEN** the panel is 360 pt times that factor wide
- **AND** titles are cut short against that narrower width

### R5. Titles that do not fit are cut short at the end
A title wider than the space left beside the preview MUST show on one line, cut short at the end with an ellipsis. It MUST NOT wrap, overlap the preview or reach past the panel's padding.

#### Scenario: Long title is cut short
- **GIVEN** a window titled "A very long document title that goes on and on and on.txt"
- **WHEN** it shows in the window switcher
- **THEN** its row shows the start of the title on one line, ending in "…", inside the panel

#### Scenario: Minimised window with a long title
- **GIVEN** a minimised window with a long title
- **THEN** its title is cut short on one line and the "Minimised" badge still shows below it

#### Scenario: No Screen Recording permission
- **GIVEN** Trackpad Launcher lacks the Screen Recording permission, so rows show the app icon instead of a preview
- **WHEN** a window with a long title shows
- **THEN** the panel is still 360 pt wide and the title is cut short at the end beside the icon

## Non-goals

- Changing window titles. Rows keep showing each window's title exactly as the app gives it, as today, and an untitled window still reads as the app's name followed by " — Window N". Apps title windows differently, so reformatting them as "project — file" was dropped to keep it simple.
- Showing app names on hover or in any other way in the switcher. The icons are enough.
- Changing icon size, the highlight's size, its motion, the haptics, or where either panel appears.
- Changing the window switcher's previews, row height, badge or highlight.
- Changing the window switcher's padding. Only the app switcher's padding is balanced.

## Implementation Decisions

- **Two existing pure layout values change; nothing else decides a size.** `SwitcherRowLayout` and `WindowColumnLayout` in `LauncherCore` already hold the switchers' geometry as tested values, and each panel positions its rows and highlight through that value alone. This plan finishes that shape for the sizes that place things: every size that places the panel, the rows, the highlight, the icons and the title column, including the switcher's height and the window switcher's width, comes from its layout. The panels in `LauncherUI` keep their look (corner radii, glass styles, durations) and the window row's own small text and badge insets, which the non-goals keep as they are. No port, no model type and no event changes. `Switcher.selectedApp` stays: the model's lift and the behavioural tests identify the selection by it; only the shell stops reading its name.

- **The switcher's padding is measured to the highlight, 22 pt, constant at every scale.** `SwitcherRowLayout.padding` becomes 22 and means the gap between the panel's edge and the highlight's edge on all four sides. Today's 28 was measured to the icon's edge; the two agree at full size, because the 92 pt highlight overhangs the 80 pt icon by 6 pt on each side, so the panel's full-size footprint and the icons' centres are unchanged (5 icons: 536 pt wide, first centre at 68, 100 pt pitch). The padding does not shrink with the row, as the horizontal padding does not today: the four gaps stay equal to one another at every scale, and a shrunk row fills the display exactly.

- **The fitting rule and the width follow the highlights' span.** The span a row needs is from the first highlight's left edge to the last highlight's right edge: `max(iconCount − 1, 0)` × full pitch + full highlight side, at full size, so it is positive for any count. The scale is `min(1, (displayWidth − 2 × padding) / span)`, and 1 when the display width is not positive, as today; the panel is `2 × padding + span × scale` wide and `2 × padding + highlightSide` tall. The threshold at which a row starts to shrink is unchanged (a full 10-icon row fits a 1036 pt display at full size and shrinks on a narrower one), since the full-size width is identical to today's.

- **`SwitcherRowLayout`'s interface after the change:** `init(iconCount:displayWidth:)`, `scale`, `iconSide`, `iconGap`, `pitch`, `highlightSide`, `panelSize` (width and height, replacing `panelWidth`; `rowWidth` goes too, nothing outside the layout reads it), `centreX(at:)` (signature unchanged; now padding + highlightSide / 2 + position × pitch, which agrees with today's padding + iconSide / 2 at full size only), new `centreY` (the row's vertical centre, half the panel's height), and the statics `fullIconSide`, `fullIconGap`, `fullHighlightSide`, `padding` and new `selectedIconScale` (1.12, moved from the panel so every size that must agree with another, the icon, the highlight and the enlarged icon, is one tested value). The panel sets the highlight's origin to `centreX − highlightSide / 2` and `centreY − highlightSide / 2`, and each icon layer's position to `(centreX(at: index), centreY)`.

- **`SwitcherPanel` loses the name and its vertical constants.** The name label, `topPadding`, `bottomPadding`, `nameHeight` and `nameGap` go. The panel's frame is `layout.panelSize` centred on the display, as today's width is; `show` loses its `name` parameter and `SwitcherPresenter.render` stops passing one. `SwitcherPanel.selectedScale` goes with them: the selected-icon transform reads `SwitcherRowLayout.selectedIconScale`, so the value T6 proves is the value drawn. The panel's corner radius (34) and the highlight's (24), the transform's 0.12 s animation and the spring are untouched: the look and motion are non-goals.

- **The window switcher declares its width and derives the title column.** `WindowColumnLayout.fullPanelWidth = 360` is declared; the title column at full size is derived from it and the unchanged row constants: 360 − 2 × 8 (panel padding) − 2 × 6 (row inset) − 120 (preview slot) − 12 (title gap) = 200. `minTitleWidth`, `maxTitleWidth` and the `widestTitle` init parameter go: `init(rowCount:displayHeight:)`. `panelSize.width` is `360 × scale` and `titleWidth` is `200 × scale`; `titleLeading`, the slot, the row height, the padding, the fonts and the preview sizes are unchanged. The title column therefore ends exactly at the row's inset (138 + 200 = 338 = 344 − 6), clear of the preview slot and inside the padding, at every scale.

- **Text is no longer measured.** `WindowSwitcherPanel.widestTitle(_:)` is removed and the presenter builds the layout from the row count and the display's visible height alone. The row's title label keeps its one line and tail truncation, which AppKit applies against the now bounded `titleWidth`; the badge keeps its place below the title at `titleLeading`.

- **Every test row added or changed, in one place.** `SwitcherRowLayoutTests`: the full-size 5-icon row is extended with the height and the first and last highlights' gaps (T1, T2); a single-icon row is added (T3); the 14-, 15- and 30-icon rows, which test rows the product never builds (`GestureRules.switcherMaxApps` is 10), are replaced by 10-icon rows on a 1024 pt display (T4) and at the 1036/1035 pt threshold (T5); a selected-icon row is added (T6); the not-positive-display row stays as it is. `WindowColumnLayoutTests`: the widest-title row is replaced by the 360 pt row (T7); the shrink row is extended with the width and the title column (T8); a title-column row is added (T9); the preview, pixel and ten-rows rows only drop the `widestTitle` argument. No test outside these two files changes.

- **Documents.** `docs/domain-model.md`: the *Switcher* entry loses the name and gains the 22 pt padding; the *Window switcher* entry gains the fixed 360 pt width, the ellipsis and that the width shrinks with the rows. `docs/architecture.md` and `docs/product-overview.md` are unchanged: neither names the switchers' sizes or the name.

## Testing Decisions

### Strategy

Two seams, both existing, both pure values in `LauncherCore` tested directly: `SwitcherRowLayout` through `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift` and `WindowColumnLayout` through `LauncherKit/Tests/LauncherCoreTests/WindowColumnLayoutTests.swift`. Each observes the numbers its panel draws from: the panel's size, the highlight's and the icons' centres, the title column's leading edge and width, the scale. The new rows extend, replace or sit beside the rows already there (`aRowThatFitsKeepsTheFullSize…`, `thirtyIconsShrink…`, `aColumnThatWouldNotFitShrinks…`, `theColumnIsAsWideAsTheWidestTitle…`); the Implementation Decisions' last-but-one bullet lists every row added and changed.

What the seams miss is the drawing: that the panels apply the layout's numbers, the label's ellipsis, the glass. `LauncherUI` has no test target (`LauncherKit/Package.swift` declares `LauncherCoreTests` and `LauncherPlatformTests` only, as plans 008 and 012 left it), so the plan makes the panels pure readers of the layouts, which is where every placing size now lives, and covers the drawing once by hand with the sequence in Further Notes. The one line and the ellipsis of a cut title are AppKit's work against the label's frame, observable only on screen, so R5 is verified without a test; the frame it is cut against is the title column T9 proves. The model seam (`World`, `SwitcherOnScreenTests`, `WindowSwitcherOnScreenTests`) sees no geometry and nothing on its path changes; the existing suite staying green proves that.

Faked: nothing. The layouts are pure values whose only inputs are a count and the display's size.

Before and after: no new row compiles today. T1–T6 need `panelSize`, `centreY` or `selectedIconScale`, and T7–T9 the init without a title. Given today's values, T4's gaps would read 22.07 (28 − 6 × 968 ÷ 980), not 22, and a title-driven width would read 340 for short titles and 480 for long ones where T7 expects 360. T1's width and centres, T2, T5's threshold, T6 and T9's full-size values would hold today: they are the guards that the footprint, the threshold, the enlarged icon and the title column's place survive the change.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R3 | `SwitcherRowLayout` | 5 icons on a 1512 pt display. Then `scale == 1`, `panelSize.width == 536`, `panelSize.height == 136`, the first highlight's left edge `centreX(at: 0) − highlightSide / 2 == 22`, its top gap `centreY − highlightSide / 2 == 22` and its bottom gap `panelSize.height − (centreY + highlightSide / 2) == 22`; `centreX(at: 0) == 68`, `centreX(at: 1) == 168` and `pitch == 100` as today. The existing full-size row extended. | R3 "Highlight on the first icon": 22 pt from the top, bottom and left edges; R3 "22 pt + the highlight's height + 22 pt tall" with the highlight 92 pt (Non-goals: the highlight's size unchanged): 136; the width 22 + 4 × 100 + 92 + 22 = 536, today's footprint (Non-goals: icon size unchanged) |
| T2 | R3 | `SwitcherRowLayout` | The same 5-icon row. Then the last highlight's right gap `panelSize.width − (centreX(at: 4) + highlightSide / 2) == 22`. | R3 "Highlight on the last icon": 22 pt from the right edge |
| T3 | R3 | `SwitcherRowLayout` | 1 icon on a 1512 pt display. Then `panelSize.width == 136`, `panelSize.height == 136`, and the left, right, top and bottom gaps of T1 and T2 are each 22. | R3 "Single app": 22 pt from all four edges; 22 + 92 + 22 both ways |
| T4 | R3 | `SwitcherRowLayout` | 10 icons, the most a row holds, on a 1024 pt display (a 13-inch MacBook at its largest-text scaling), too narrow for the row at full size. Then `scale` is 980 ÷ 992 within 0.0001, `panelSize.width == 1024` within 0.01, and the four gaps of T1 and T2 are equal to one another and each 22 within 0.01 (today's rule would read 22.07). Replaces today's 15- and 30-icon rows, whose expected 28 was measured to the icon's edge. | R3 "Shrunk row on a narrow display": the gaps "still equal to one another"; the worked example: the display less two 22 pt paddings, 980, over the full-size span from the first highlight's left edge to the last's right edge, 9 × 100 + 92 = 992 |
| T5 | R3 | `SwitcherRowLayout` | 10 icons on a 1036 pt display keep `scale == 1` and `panelSize.width == 1036`; on a 1035 pt display `scale < 1` and `panelSize.width == 1035` within 0.01. Replaces today's 14-icon row. | The worked example: 10 icons span 9 × 100 + 92 = 992, plus two 22 pt paddings is 1036, so 1036 fits and 1035 shrinks until 44 + 992 × scale = 1035; the same threshold as today's rule (10 × 80 + 9 × 20 + 2 × 28 = 1036) |
| T6 | R2 | `SwitcherRowLayout` | `fullIconSide × selectedIconScale` (80 × 1.12 = 89.6) is more than `fullIconSide` and at most `fullHighlightSide` (92). | R2: "drawn larger than the others" and "stay inside the highlight"; 1.12, 80 and 92 are today's values (R2 "unchanged from today"; Non-goals: icon and highlight size unchanged) |
| T7 | R4 | `WindowColumnLayout` | 2 rows on a 900 pt display, and 10 rows on a 900 pt display, both fitting at full size. Then `panelSize.width == 360` for both. The init has no title input and the panel's frame comes from `panelSize` alone, so no title, short or long, can move it. Replaces today's widest-title row. | R4 "Short titles" and "Long titles": "the window switcher is 360 pt wide" |
| T8 | R4 | `WindowColumnLayout` | 10 rows on a 777 pt display, one point too short for the column at full size. Then `scale < 1`, `panelSize.width` is 359.5225 and `titleWidth` is 199.7347, each within 0.001. The existing shrink row extended. | R4 "Column shrunk on a short display": "360 pt times that factor wide" and "titles are cut short against that narrower width"; the factor is the worked example (777 − 2 × 12) ÷ 754 = 753 ÷ 754 from the existing row's 778 pt full-size column, so 360 × 753 ÷ 754 and 200 × 753 ÷ 754; the title column 360 − 2 × 8 − 2 × 6 − 120 − 12 = 200 (Non-goals: the window switcher's padding, previews and row height unchanged) |
| T9 | R4 | `WindowColumnLayout` | 3 rows on a 900 pt display at full size: `titleLeading == 138` and `titleLeading + titleWidth == 338`; on T8's 777 pt display, 137.8170 and 337.5517 within 0.001. The title column starts clear of the preview slot and ends at the row's inset at every scale, so no title can push the panel past its 360 pt; the layout has one `titleWidth` for every row, minimised or visible, and one slot width whether the slot shows a picture or the app icon. | R4 "whatever the length of its titles": the slot is 120 pt at a 6 pt inset with a 12 pt gap, so the title starts at 138; the row is 360 − 2 × 8 = 344 wide and the title ends at its 6 pt inset, 338; scaled by T8's 753 ÷ 754 |

### Verified without a test

- **R1, the switcher shows no app name.** The build proves no caller passes a name once `SwitcherPanel.show` loses its `name` parameter; `grep -n "NSTextField\|labelWithString\|\.name" LauncherKit/Sources/LauncherUI/SwitcherPanel.swift LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift` returns nothing (today it returns five lines); and the manual sequence in Further Notes, step 1: with Safari, Mail and Notes running, none of them assigned to a gesture, and Safari in front, slide right until Mail is selected, and no text appears on the panel. A test is not the right proof: what is drawn is observable only on screen, `LauncherUI` has no test target, and the name was never a model decision (`Switcher.selectedApp` stays for the lift), so no seam below the screen can tell whether a name is drawn.

- **R5, titles that do not fit are cut short at the end.** `grep -n "byTruncatingTail\|maximumNumberOfLines = 1" LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift` returns both lines, in the row view's init, so AppKit cuts the title at its end with an ellipsis and keeps it to one line; the frame it is cut against is the title column T9 proves, clear of the preview and inside the padding at every scale; and the manual sequence in Further Notes, steps 3 to 5: a title far wider than the row shows on one line ending in "…" beside the preview, a minimised window's cut title keeps the "Minimised" badge below it, and without Screen Recording the title is cut the same way beside the app icon in a panel still 360 pt wide. A test is not the right proof: the ellipsis and the single line are drawn by AppKit against the label's frame and are observable only on screen; the layout can prove the frame (T9) but not the text drawn in it.

## Further Notes

- The switcher's full-size width and the icons' horizontal positions do not move; the panel loses the 24 pt below the row where the name sat (160 pt tall today, 136 after). Because the panel stays centred on the display, the row, which today sits 12 pt above the panel's centre, is now at its centre, so it lands about 12 pt lower on screen than today. Where the panel appears is unchanged, which is what the non-goal keeps.
- On a display too narrow for the row, the shrunk icons come out a hair larger than today, since the span now counts the highlight's 12 pt overhang once instead of the 28 pt paddings twice: 10 icons on 1024 pt are 79.03 pt instead of 79.02. The full-size icon stays 80 pt, as the non-goals ask.
- The highlight's corner radius (24) and the panel's (34) are not concentric with a 22 pt padding (that would need 12). Changing the highlight's look is a non-goal; left as is.
- `SwitcherOnScreenTests` and `WindowSwitcherOnScreenTests` read `selectedApp.name` and `rows.map(\.title)` to identify apps and windows at the model seam; they are untouched by this plan.
- Manual sequence, once at the end of S1, on a built app with Accessibility granted, the swipe and window swipe settings on, Safari, Mail and Notes running with no gesture assigned to any of them (an assigned app is left out of the row), and Safari in front:
  1. Thumb in the corner, two fingers slide right until Mail is selected: the panel shows icons and the highlight only, no text; the panel looks as tall above the row as below it (R1, R3).
  2. Without lifting, slide back to Safari: the Safari icon is drawn larger than the others and sits wholly inside the highlight (R2).
  3. Open two Safari windows titled "A" and "B" (any two short titles) and window-swipe: the window switcher is 360 pt wide, measured on a screenshot at the display's backing scale (720 px on a 2× display). Then open a Safari window with a title far wider than the row and window-swipe again: the panel is the same 360 pt wide and the long title shows on one line ending in "…", clear of the preview (R4, R5).
  4. Minimise the long-titled window and window-swipe: its row shows the cut title with the "Minimised" badge below it (R5).
  5. With Screen Recording denied (System Settings › Privacy & Security › Screen & System Audio Recording), window-swipe on the long-titled window: the panel is still 360 pt wide and the title is cut short beside the Safari icon (R5).

## Slices

### S1: Both switchers simplified

**What to build:** The switcher shows icons and the highlight only, 22 pt of padding on every side; the window switcher is 360 pt wide whatever its titles, each title on one line cut short with an ellipsis. Every size that places either panel, its rows, highlight, icons and title column comes from its layout value, and the layouts' tests prove the new geometry.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9.

- [ ] `SwitcherRowLayout` measures its 22 pt padding to the highlight, exposes `panelSize`, `centreY` and `selectedIconScale`, and T1–T6 are green.
- [ ] `SwitcherPanel` has no name label and no vertical constants of its own; its frame, the highlight's and the icons' positions come from the layout; `show` takes no name and `SwitcherPresenter` passes none (R1's build and grep checks pass).
- [ ] `SwitcherPanel.selectedScale` is gone and the selected-icon transform reads `SwitcherRowLayout.selectedIconScale`: `grep -rn "selectedScale" LauncherKit/Sources` returns nothing.
- [ ] `WindowColumnLayout` declares `fullPanelWidth = 360`, derives the 200 pt title column, takes no title measurement, and T7–T9 are green.
- [ ] `WindowSwitcherPanel.widestTitle(_:)` is gone and the presenter builds the layout from the row count and display height alone; R5's grep finds the row view's tail truncation and one-line limit.
- [ ] `docs/domain-model.md`'s *Switcher* and *Window switcher* entries match what ships.
- [ ] `Scripts/test.sh` is green: the whole suite, with the two layout suites' rows added and changed as this plan's Implementation Decisions list them and no test outside those two files edited.
- [ ] The manual sequence in Further Notes runs clean on a built app: step 1 for R1, steps 3 to 5 for R5, the rest as a demo.
