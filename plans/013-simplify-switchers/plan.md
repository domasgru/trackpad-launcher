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
