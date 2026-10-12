# Plan: 5-finger gesture and the swipe switcher

## Problem statement

Trackpad Launcher reaches four apps: one per tap gesture. Most people switch between more apps than that every day. The fifth and later apps still need ⌘-Tab or the Dock, so the trackpad covers only part of the day's switching.

Adding a fifth tap gesture helps, but taps cannot grow much further: a hand has five fingers. The remaining apps need a gesture that scales with the number of apps, not with the number of fingers.

## Solution

Two additions.

A **5-finger gesture**. It works exactly like the 1-finger to 4-finger gestures: thumb anchored, tap with five fingers, the assigned app comes to the front. The launcher window gets a fifth gesture row.

A **swipe**. With the thumb anchored, the user slides two fingers left or right. The **switcher** appears on screen: one row of 80 pt app icons from the **switcher list**, the apps the user chose for swiping. The selection starts on the **frontmost app**, the app that is active when the swipe begins, so the user can also stay where they are. A glass highlight follows the fingers across the icons. The icon under it grows a little, its name shows below, and a light haptic tick marks each change. The thumb only starts the swipe: once the switcher is up it may stay in the corner or lift, and nothing changes. Lifting the fingers brings the selected app to the front and the switcher disappears. The list, its order, and its contents are set in the launcher window: add, reorder, remove.

Scrolling gets suppressed. Today a two-finger swipe with the thumb anchored scrolls the page under the pointer. So, with the Accessibility permission, trackpad scrolling is suppressed under the same rule as click blocking (plan 002 R4), and for the whole of a swipe once the switcher is up. Vertical scrolling is suppressed inside that window too: one rule for clicks and scrolling, so the user learns a single 3-second window. Once a swipe begins, clicks and scrolling stay blocked until it ends, however long after the thumb anchored.

Terms, for the glossary: *5-finger gesture*; *swipe* (two fingers sliding left or right, started under an anchored thumb); *switcher* (the on-screen row shown during a swipe); *switcher list* (the user-ordered apps the switcher shows); *frontmost app* (the active app at the moment a swipe begins; never Trackpad Launcher, which never activates).

This plan amends earlier plans. Plan 001: R3 and R4 (four gesture rows) become five rows plus the switcher section (R2, R16 here); R11's bullet "fingers that drag or scroll while the thumb is anchored" now scopes to taps (a swipe is not a tap and fires no gesture) and its scenario "Drag is not a tap" is replaced by R3 and R12 to R14 here; the non-goal "Gestures beyond the four" no longer holds. Plan 002: R1's "more than four distinct fingers" becomes "more than five" (R1 here); R4's blocking window is extended for the whole of a swipe, and its "clicks work again once the thumb lifts" does not apply during a swipe (R13 here); R6's scrolling sentence and its "Scrolling still works" scenario are replaced by R12 to R14 here; R9's "MUST NOT read, record or change … scrolling" is amended by R12 to R14 here (scroll events are read, and those of a suppressed scroll are changed, under the one Accessibility permission); R11's hint copy is replaced by R15 here. `docs/product-overview.md` changes in three places: the four gestures become five tap gestures plus the swipe; the haptic rule gains one exception, a swipe released on the frontmost app is silent; the sound effect stays deferred. `docs/domain-model.md` gains the terms above, and its *Gesture*, *Tap*, *Launcher window*, *Click blocking* and *Blocking window* entries follow this plan.

## Requirements

### R1. A five-finger tap fires the 5-finger gesture
A tap with exactly five distinct non-thumb fingers MUST fire the 5-finger gesture under the same rules as the other gestures (plan 002 R1 to R3: every finger that touches counts, 400 ms, fires on lift). A tap with more than five distinct non-thumb fingers MUST NOT fire a gesture.

#### Scenario: Five-finger tap opens the app
- **GIVEN** the 5-finger gesture is assigned to Slack and gestures are active
- **WHEN** the user anchors the thumb and taps with five fingers of the other hand
- **THEN** Slack comes to the front once, with the gesture haptic and the launch animation

#### Scenario: Rolling five-finger tap
- **GIVEN** the 5-finger gesture is assigned to Slack and the 4-finger gesture to Spotify
- **WHEN** the user anchors the thumb and five fingers land one after another within 400 ms, the first lifting before the last lands
- **THEN** Slack comes to the front and Spotify does not

#### Scenario: Six fingers
- **GIVEN** all five gestures are assigned
- **WHEN** the user anchors the thumb and six distinct non-thumb fingers touch during one tap
- **THEN** nothing happens

### R2. The launcher window has a fifth gesture row
The launcher window MUST show a fifth gesture row below the 4-finger row, with a five-finger illustration in the style of the existing ones and an app picker that behaves like the other rows (plan 001 R5 to R7: install list, Other…, None, placeholder, not found). The illustration MUST mirror in left-hand mode like the others.

#### Scenario: Fresh install shows five rows
- **WHEN** the user opens the window after installing for the first time
- **THEN** five gesture rows show, 1 to 5 fingers top to bottom, each with "Choose app…"

#### Scenario: Assign the fifth row
- **WHEN** the user picks Slack in the fifth row's picker
- **THEN** the row shows Slack's icon and name, and a five-finger tap brings Slack to the front

#### Scenario: Left hand mirrors the fifth illustration
- **WHEN** the user selects Left hand
- **THEN** the fifth row's illustration shows the thumb mark top-right

### R3. A swipe begins on sideways movement of two fingers
A swipe MUST begin when all of these hold: a thumb is anchored and it anchored before either finger landed; exactly two non-thumb fingers are down; no other non-thumb finger has touched since the last moment no non-thumb finger was down; and one of the two fingers has moved more than 3 mm from where it landed, with that movement more sideways than up or down. There MUST be no time limit between the fingers landing and the movement. When the first movement past 3 mm is more up or down than sideways, no swipe begins and nothing further happens until every non-thumb finger has lifted. Two fingers that lift without moving past 3 mm remain a 2-finger tap.

#### Scenario: Sideways movement opens the switcher
- **GIVEN** the switcher list holds Mail, Slack and Notes, and gestures are active
- **WHEN** the user anchors the thumb, puts two fingers down and slides them 5 mm to the right
- **THEN** the switcher appears

#### Scenario: Fingers rest, then swipe
- **GIVEN** the switcher list is not empty
- **WHEN** the user anchors the thumb, rests two fingers for 2 seconds, then slides them sideways
- **THEN** the switcher appears

#### Scenario: Up or down is not a swipe
- **GIVEN** the switcher list is not empty
- **WHEN** the user anchors the thumb and slides two fingers 10 mm downwards, then 20 mm to the right without lifting
- **THEN** no switcher appears and nothing opens

#### Scenario: One finger is not a swipe
- **WHEN** the user anchors the thumb and slides one finger sideways
- **THEN** no switcher appears and the pointer moves as usual

#### Scenario: Three fingers are not a swipe
- **WHEN** the user anchors the thumb and slides three fingers sideways
- **THEN** no switcher appears and nothing opens

#### Scenario: Two-finger tap still fires
- **GIVEN** the 2-finger gesture is assigned to Figma
- **WHEN** the user anchors the thumb and taps with two fingers, moving less than 3 mm
- **THEN** Figma comes to the front and no switcher appears

#### Scenario: Fingers before thumb
- **WHEN** the user puts two fingers down, then anchors the thumb, then slides the fingers sideways
- **THEN** no switcher appears

#### Scenario: Rolling three-finger tap with drift
- **GIVEN** the 3-finger gesture is assigned to Notion, the switcher list is not empty and Safari is frontmost
- **WHEN** the user anchors the thumb and taps with three fingers, and one of the first two fingers skids 4 mm sideways before the third lands
- **THEN** the switcher appears and disappears, no app comes to the front and no haptic plays (a finger that drags more than 3 mm already ended the tap under plan 001's drag rule, so no tap that fired before is lost)

#### Scenario: Two-finger tap that drifts
- **GIVEN** the 2-finger gesture is assigned to Figma, the switcher list is not empty and Safari is frontmost
- **WHEN** the user anchors the thumb and taps with two fingers that skid 4 mm sideways before lifting
- **THEN** the switcher appears briefly and disappears, no haptic plays, and neither Figma nor any other app comes to the front

### R4. The switcher shows the switcher list with the frontmost app
The switcher MUST show the switcher list's apps in list order, left to right, leaving out apps that are missing (no copy outside the Trash). When the frontmost app is not among them, it MUST be shown as an extra icon at the left end. The row is fixed for the swipe from the moment it begins.

#### Scenario: Frontmost app is in the list
- **GIVEN** the switcher list is Mail, Slack, Notes and Slack is frontmost
- **WHEN** the user starts a swipe
- **THEN** the switcher shows Mail, Slack, Notes, left to right

#### Scenario: Frontmost app is not in the list
- **GIVEN** the switcher list is Mail, Slack, Notes and Safari is frontmost
- **WHEN** the user starts a swipe
- **THEN** the switcher shows Safari, Mail, Slack, Notes, left to right

#### Scenario: Missing app is left out
- **GIVEN** the switcher list is Mail, Figma, Notes and Figma is in the Trash
- **WHEN** the user starts a swipe
- **THEN** the switcher shows Mail and Notes, and Figma is not in the row

### R5. The selection starts on the frontmost app
When the switcher appears, the frontmost app's icon MUST be the selected one, wherever it sits in the row.

#### Scenario: Selection starts in the middle
- **GIVEN** the switcher list is Mail, Slack, Notes and Slack is frontmost
- **WHEN** the user starts a swipe
- **THEN** Slack is selected, with Mail to its left and Notes to its right

#### Scenario: Selection starts at the left end
- **GIVEN** the switcher list is Mail, Slack, Notes and Safari is frontmost
- **WHEN** the user starts a swipe
- **THEN** Safari, at the left end, is selected

### R6. The highlight follows the fingers and snaps every 12 mm
During a swipe the icons are 12 mm of travel apart. Travel is the sideways movement of the midpoint of the two fingers, measured from where the swipe began. The highlight MUST move continuously with the fingers: between two icons it sits between them in proportion to the travel. The selected app MUST be the icon the highlight is nearest to, so the selection changes when the highlight crosses the midpoint between two icons: 6 mm after the swipe began, then every 12 mm. Reversing direction MUST move the selection back under the same rule. The selection MUST NOT move past the first or last icon; travel beyond an end moves the highlight only slightly past it, and it springs back to the end icon. Travel is measured in trackpad millimetres, the same on every trackpad, and the direction is the same in both hand modes: right moves the selection right.

#### Scenario: Two steps right
- **GIVEN** the switcher shows Safari, Mail, Slack, Notes with Safari selected
- **WHEN** the user slides the fingers 24 mm further to the right
- **THEN** Slack is selected

#### Scenario: Half a step shows progress without changing the selection
- **GIVEN** Safari is selected and Mail is next to its right
- **WHEN** the user slides 5 mm to the right and holds
- **THEN** the highlight sits visibly between Safari and Mail, nearer Safari, and Safari is still selected

#### Scenario: Past the midpoint snaps
- **GIVEN** Safari is selected and Mail is next to its right
- **WHEN** the user slides 7 mm to the right and holds
- **THEN** Mail is selected and the highlight sits on Mail

#### Scenario: Back and forth
- **GIVEN** Safari is selected
- **WHEN** the user slides 24 mm right, then 12 mm left
- **THEN** Mail is selected

#### Scenario: No wrap at the end
- **GIVEN** the switcher shows Safari, Mail, Slack, Notes with Notes selected
- **WHEN** the user slides 30 mm further to the right and holds
- **THEN** Notes stays selected and the highlight rests on Notes, having moved only slightly past it

#### Scenario: Same direction in left-hand mode
- **GIVEN** Left hand is selected and Safari is selected at the left end of the row
- **WHEN** the user slides the fingers 12 mm to the right
- **THEN** the selection moves one icon to the right

### R7. A light haptic tick marks each selection change
Each time the selected icon changes during a swipe, the trackpad MUST give the *light tick*: a haptic pulse lighter than the *gesture haptic* that plays when an app opens. No tick plays while the selection stays put.

#### Scenario: Ticks per icon
- **GIVEN** the switcher shows four icons with the first selected
- **WHEN** the user slides 36 mm to the right in one movement
- **THEN** three light ticks play, one per icon crossed

#### Scenario: No tick without a change
- **WHEN** the user slides 5 mm to the right and holds
- **THEN** no tick plays

### R8. Lifting opens the selected app
A swipe ends when the first of the two fingers lifts, whether or not the thumb is still anchored. Then the selected app MUST come to the front (plan 001 R12), the gesture haptic MUST play, and the switcher MUST disappear. No launch animation plays. The launcher window, if open, closes. When the selected app is the frontmost app, nothing happens except that the switcher disappears: no haptic, no bring to front. After a swipe ends, nothing further happens until every non-thumb finger has lifted.

#### Scenario: Lift opens the app
- **GIVEN** Slack is selected in the switcher and Safari is frontmost
- **WHEN** the user lifts the fingers
- **THEN** Slack comes to the front, the gesture haptic plays, no launch animation plays, and the switcher is gone

#### Scenario: One finger lifts first
- **GIVEN** Slack is selected
- **WHEN** one of the two fingers lifts and the other stays down and keeps moving
- **THEN** Slack comes to the front at the first lift and the remaining finger changes nothing

#### Scenario: Whole hand lifts together
- **GIVEN** Slack is selected
- **WHEN** the user lifts the thumb and the two fingers together
- **THEN** Slack comes to the front

#### Scenario: Thumb lifts, swipe goes on
- **GIVEN** Mail is selected and Slack is two icons to its right
- **WHEN** the user lifts the thumb, keeps sliding the two fingers 24 mm to the right, then lifts them
- **THEN** the switcher stays up the whole time, follows the fingers, and Slack comes to the front

#### Scenario: Staying on the frontmost app
- **GIVEN** Safari is frontmost and selected
- **WHEN** the user lifts the fingers
- **THEN** the switcher disappears, no haptic plays and no app changes

#### Scenario: Launcher window closes
- **GIVEN** the launcher window is open and Slack is selected
- **WHEN** the user lifts the fingers
- **THEN** Slack comes to the front and the window closes

### R9. A third finger or a click cancels the swipe
A swipe MUST be cancelled, with the switcher disappearing and nothing opening, when another finger lands outside the anchor corner, or when a click reaches apps (an unblocked press). The thumb plays no part once the swipe has begun: it may lift, leave the corner, or land in the corner again, and the swipe goes on. A blocked press (plan 002 R8) MUST NOT affect the swipe. After a cancel, nothing further happens until every non-thumb finger has lifted.

#### Scenario: Thumb slides out, swipe goes on
- **GIVEN** Slack is selected
- **WHEN** the thumb slides out of the anchor corner and the user lifts the two fingers
- **THEN** Slack comes to the front

#### Scenario: Thumb lands again
- **GIVEN** Slack is selected and the thumb has lifted
- **WHEN** the thumb lands in the anchor corner again and the user lifts the two fingers
- **THEN** Slack comes to the front

#### Scenario: Third finger lands
- **GIVEN** Slack is selected
- **WHEN** a third finger lands, then all fingers lift
- **THEN** the switcher disappears and nothing opens

#### Scenario: Unblocked click cancels
- **GIVEN** access is not granted and Slack is selected
- **WHEN** the user presses the trackpad down with the swiping fingers over a button
- **THEN** the button is clicked, the switcher disappears and Slack does not come to the front

#### Scenario: Blocked press is ignored
- **GIVEN** access is granted and Slack is selected
- **WHEN** the user presses the trackpad down with the swiping fingers, keeps sliding, and lifts
- **THEN** nothing is clicked and the app selected at the lift comes to the front

### R10. The switcher's look and placement
The switcher MUST be a Liquid Glass panel centred on the screen the pointer is on, holding one row of 80 pt app icons with 20 pt between neighbours, a glass selection highlight slightly larger than an icon that slides under the icons, the selected icon drawn slightly larger than the others, and the selected app's name below the row. It MUST appear as the swipe begins with no perceptible delay, MUST be gone within 200 ms of the swipe ending or cancelling, MUST never take focus or activate Trackpad Launcher, and MUST look correct in light and dark appearance. With Reduce motion on, the highlight MUST still follow the fingers and the selected icon is still drawn larger, but nothing springs, fades or animates its size.

#### Scenario: Appearance
- **GIVEN** the switcher list holds six apps
- **WHEN** the user starts a swipe
- **THEN** a glass panel centred on the pointer's screen shows six 80 pt icons in one row, the selected one highlighted and slightly larger, with its name below

#### Scenario: Focus stays put
- **GIVEN** the user is typing in a text field in Notes
- **WHEN** they start a swipe and lift the fingers with Notes still selected
- **THEN** the text field still has focus and Notes is still active

#### Scenario: Second display
- **GIVEN** two displays and the pointer on the external one
- **WHEN** the user starts a swipe
- **THEN** the switcher appears centred on the external display

#### Scenario: Swipe from a full-screen app
- **GIVEN** Safari is full screen and frontmost
- **WHEN** the user swipes to Slack and lifts
- **THEN** the switcher appeared over full-screen Safari and Slack comes to the front

#### Scenario: Reduce motion
- **GIVEN** Reduce motion is on
- **WHEN** the user swipes across three icons
- **THEN** the highlight moves with the fingers, the selection changes and the selected icon is larger, with no spring, fade or size animation

### R11. No switcher when there is nothing to switch to
When the switcher list holds no present app, or the only icon the row would hold is the frontmost app, a sideways two-finger movement MUST do nothing: no switcher, no haptic, nothing opens. While gestures are inactive (plan 001 R14), the swipe MUST do nothing, like the taps.

#### Scenario: Empty list
- **GIVEN** the switcher list is empty
- **WHEN** the user anchors the thumb and slides two fingers sideways
- **THEN** nothing happens

#### Scenario: Only the frontmost app
- **GIVEN** the switcher list holds only Safari and Safari is frontmost
- **WHEN** the user anchors the thumb and slides two fingers sideways
- **THEN** nothing happens

#### Scenario: Gestures inactive
- **GIVEN** *Tap to click* is on and the switcher list holds three apps
- **WHEN** the user anchors the thumb and slides two fingers sideways
- **THEN** nothing happens

### R12. Trackpad scrolling is suppressed under the click-blocking rule
While Trackpad Launcher has the Accessibility permission and gestures are active, trackpad scrolling MUST be suppressed under exactly the conditions that block clicks (plan 002 R4: within 3 seconds of the thumb anchoring, while it stays anchored and another finger is on the trackpad). Scrolling MUST work again at once when that condition no longer holds. Scrolling from a mouse wheel MUST NOT be suppressed. Magic Mouse scrolling is suppressed under the same conditions as trackpad scrolling. Pointer movement is never blocked. Without the Accessibility permission, nothing is suppressed and the swipe still works.

#### Scenario: Vertical movement inside the window does not scroll
- **GIVEN** access is granted and the pointer is over a long page
- **WHEN** the user anchors the thumb and, within 3 seconds, slides two fingers up and down
- **THEN** the page does not scroll and no switcher appears

#### Scenario: Scrolling returns after 3 seconds
- **GIVEN** access is granted and the pointer is over a long page
- **WHEN** the user rests the thumb in the anchor corner for 4 seconds, then scrolls up with two fingers
- **THEN** the page scrolls

#### Scenario: Thumb lifted, scrolling is normal
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb, lifts it, then scrolls with two fingers
- **THEN** the page scrolls as usual

#### Scenario: Mouse wheel is never suppressed
- **GIVEN** access is granted and a mouse with a scroll wheel is connected
- **WHEN** the user anchors the thumb, rests a finger on the trackpad and turns the wheel
- **THEN** the page scrolls

#### Scenario: Without access, the page scrolls under the switcher
- **GIVEN** access is not granted and the pointer is over a wide page
- **WHEN** the user anchors the thumb and swipes two fingers sideways
- **THEN** the switcher appears and works, and the page scrolls sideways under it

### R13. Clicks and scrolling stay blocked for the whole of a swipe
While Trackpad Launcher has the Accessibility permission and gestures are active, clicks MUST be blocked and trackpad scrolling MUST be suppressed from the moment a swipe begins until it ends or is cancelled, however long after the thumb anchored and whether or not the thumb is still anchored. This extends the 3-second window of plan 002 R4 for the duration of a swipe and sets aside its "clicks work again once the thumb lifts" for that time. Once the swipe ends or is cancelled, the plan 002 R4 rule alone applies again.

#### Scenario: Swipe does not scroll
- **GIVEN** access is granted and the pointer is over a wide page in Safari
- **WHEN** the user anchors the thumb and swipes two fingers sideways, choosing an app
- **THEN** the page does not scroll, before, during or after the switcher

#### Scenario: Late swipe still gets a clean switcher
- **GIVEN** access is granted and the pointer is over a wide page
- **WHEN** the user rests the thumb for 4 seconds, then swipes two fingers sideways across three icons
- **THEN** the switcher appears and works, the page moves no more than the first 3 mm of finger travel scrolls it, and not at all once the switcher is up

#### Scenario: Press during a late swipe is blocked
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user rests the thumb for 4 seconds, swipes to Slack, presses the trackpad down with the swiping fingers, and lifts
- **THEN** nothing is clicked and Slack comes to the front

#### Scenario: Thumb lifted mid-swipe, press still blocked
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user starts a swipe, lifts the thumb, presses the trackpad down with the swiping fingers over the button, and lifts
- **THEN** nothing is clicked and the selected app comes to the front

### R14. Nothing coasts after a suppressed scroll
The momentum that follows a suppressed scroll MUST be suppressed too, so nothing coasts after the fingers lift. The momentum that follows a scroll that was not suppressed MUST NOT be interrupted.

#### Scenario: No coasting
- **GIVEN** access is granted and the pointer is over a long page
- **WHEN** the user anchors the thumb and, within 3 seconds, flicks two fingers upwards and lifts
- **THEN** the page does not move, and does not coast after the lift

#### Scenario: Coasting from before is not interrupted
- **GIVEN** access is granted and a page is coasting after a two-finger flick
- **WHEN** the thumb lands in the anchor corner while the page coasts
- **THEN** the page coasts to a stop as usual

### R15. The Accessibility hint names scrolling
The Accessibility hint of plan 002 R11 MUST read "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them." Everything else about the hint stays as in plan 002 R11.

#### Scenario: Hint copy
- **GIVEN** access is not granted
- **WHEN** the user opens the launcher window
- **THEN** the hint reads "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them." with the "Grant access…" button

### R16. The launcher window has a switcher section
Below the five gesture rows, the launcher window MUST show a switcher section: a swipe illustration in the style of the gesture illustrations (thumb mark, two finger marks and a double-headed sideways arrow), mirrored in left-hand mode, with the title "Swipe to switch apps"; under it the switcher list rows; under them an "Add app…" button. The hand-mode toggle sits below this section, above the divider. The section MUST look correct in light and dark appearance and keep the window's Liquid Glass look.

#### Scenario: Layout
- **GIVEN** the switcher list holds Mail, Slack and Notes
- **WHEN** the user opens the launcher window
- **THEN** below the fifth gesture row come the swipe illustration and title, then the rows Mail, Slack, Notes, then "Add app…", then the hand-mode toggle, then the divider and the hint

#### Scenario: Left hand mirrors the swipe illustration
- **WHEN** the user selects Left hand
- **THEN** the swipe illustration shows the thumb mark top-right

### R17. Switcher list rows show the apps in switcher order
Each row MUST show the app's icon and name. Top-to-bottom order in the window MUST be left-to-right order in the switcher. A missing app's row MUST show the name greyed with "not found", like a gesture row, and recover by itself when a copy exists again.

#### Scenario: Order matches
- **GIVEN** the window lists Mail, Slack, Notes top to bottom
- **WHEN** the user starts a swipe
- **THEN** the switcher shows Mail, Slack, Notes left to right

#### Scenario: Missing app in the list
- **GIVEN** Figma is in the switcher list
- **WHEN** the user moves Figma to the Trash and opens the window
- **THEN** Figma's row shows "Figma" greyed with "not found"
- **WHEN** the user puts Figma back and reopens the window
- **THEN** Figma's row shows normally

### R18. Add app… appends an app to the list
"Add app…" MUST open a menu like an app picker's: the recently launched apps, the other installed apps, then *Other…*, with no *None*. Apps already in the switcher list MUST appear checked and disabled. Choosing an app MUST append it to the end of the list. *Other…* MUST open the file chooser that accepts only applications and append the chosen app; an app already in the list MUST NOT be added twice. An app MAY be both on a tap gesture and in the switcher list.

#### Scenario: Add from the menu
- **GIVEN** the switcher list is Mail, Slack
- **WHEN** the user clicks "Add app…" and chooses Notes
- **THEN** the list reads Mail, Slack, Notes

#### Scenario: Listed apps are checked and disabled
- **GIVEN** the switcher list is Mail, Slack
- **WHEN** the user opens the "Add app…" menu
- **THEN** Mail and Slack show a checkmark and cannot be chosen, and Notes can

#### Scenario: Other… from elsewhere
- **WHEN** the user chooses *Other…* and selects an app bundle in ~/Downloads
- **THEN** that app is appended with its icon and name

#### Scenario: Other… picks a listed app
- **GIVEN** Slack is in the list
- **WHEN** the user chooses *Other…* and selects Slack
- **THEN** the list is unchanged

#### Scenario: Same app on a tap and in the list
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user adds Arc to the switcher list
- **THEN** Arc is added, without a warning

### R19. Rows can be removed
Hovering a row MUST reveal a remove button at its trailing edge, and the row's context menu MUST offer *Remove*. Either MUST remove the app from the list at once, with the rows below moving up.

#### Scenario: Remove on hover
- **GIVEN** the list is Mail, Slack, Notes
- **WHEN** the user hovers Slack and clicks its remove button
- **THEN** the list reads Mail, Notes

#### Scenario: Remove from the context menu
- **GIVEN** the list is Mail, Slack, Notes
- **WHEN** the user right-clicks Notes and chooses *Remove*
- **THEN** the list reads Mail, Slack

### R20. Rows can be reordered by dragging
Dragging a row to a new position MUST reorder the list, and the next swipe MUST use the new order.

#### Scenario: Drag to reorder
- **GIVEN** the list is Mail, Slack, Notes
- **WHEN** the user drags Notes above Mail
- **THEN** the list reads Notes, Mail, Slack, and the next switcher shows Notes, Mail, Slack left to right

### R21. Empty list shows only the Add button
With no apps in the switcher list, the section MUST show the illustration, the title and the "Add app…" button, and nothing else.

#### Scenario: Fresh install
- **WHEN** the user opens the window after installing for the first time
- **THEN** the switcher section shows the illustration, "Swipe to switch apps" and "Add app…", with no rows

### R22. The window stays on screen as the list grows
The launcher window MUST grow with the switcher list. When the window would not fit the screen's visible area, the switcher list MUST scroll inside the window instead, and everything else in the window MUST stay reachable.

#### Scenario: Long list on a small screen
- **GIVEN** the switcher list holds 30 apps on a 13" built-in display
- **WHEN** the user opens the window
- **THEN** the window fits the screen, the list scrolls, and the hand-mode toggle, the hint and Quit are reachable

### R23. The new settings persist
The 5-finger assignment, the switcher list and its order MUST persist across quitting, relaunching and rebooting.

#### Scenario: Survives relaunch
- **GIVEN** the user assigned Slack to the 5-finger gesture and ordered the switcher list Notes, Mail
- **WHEN** they quit and relaunch Trackpad Launcher
- **THEN** the fifth row shows Slack and the list reads Notes, Mail

### R24. The hint mentions five fingers and the swipe
While gestures are active, the hint MUST read "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps", with the same marks as today and "top-right" in left-hand mode.

#### Scenario: Hint copy per hand
- **GIVEN** gestures are active and Right hand is selected
- **WHEN** the user opens the window
- **THEN** the hint reads as above with "top-left"
- **WHEN** the user selects Left hand
- **THEN** the hint reads "top-right" and is otherwise unchanged

## Non-goals

- **Momentum in the switcher.** The selection follows the fingers only and stops when they stop. (Amended after review, at the user's request: switcher travel now follows the cursor, with macOS's pointer acceleration at the user's tracking speed and 100 cursor points per icon, so R6's fixed 12 mm per icon no longer holds and a fast swipe travels farther than a slow one. R8 and R9 are amended too: a swipe ends when both fingers have lifted, a finger that briefly loses contact rejoins, and only a third finger landing while both are down cancels.)
- **Wrapping from the last icon to the first.** The ends are hard stops with a small rubber band, so a long swipe always parks on the end icon.
- **Vertical swipes.** Up and down with two fingers is scrolling; the switcher is a sideways gesture only.
- **Quitting or hiding apps from the switcher.** ⌘-Tab offers Q and H; the switcher only brings an app to the front.
- **A cap on the switcher list length.** Any number of apps; the window scrolls when they do not fit.
- **A switcher row wider than the screen.** Lists that long are not expected. The row is laid out as if it fits; nothing slides, shrinks or wraps.
- **Keyboard control of the switcher.** It never takes focus, so there is no Escape, arrow keys or Return; lifting on the frontmost app is the way out.
- **Showing the switcher before any movement.** Two fingers resting with the thumb anchored may still become a 2-finger tap, which must stay instant and silent.
- **Tunable step distance, icon size or thresholds.** 12 mm, 80 pt and 3 mm are fixed, like the other gesture rules.
- **Recency ordering of the switcher.** The user chose a hand-ordered list for stable positions; ⌘-Tab already covers recency.
- **Keeping tap-assigned apps out of the switcher list.** The list usually holds the other apps, but nothing enforces it.
- **A launch animation for apps opened from the switcher.** The icon is already large on screen; the user chose a plain disappearance.
- **Suppressing anything besides scrolling.** Pointer movement stays live. The hardware check found only scrolling reacts to thumb plus two fingers.
- **Telling Magic Mouse scrolling from trackpad scrolling.** The system reports them alike; wheel mice are passed because they can be told apart.
- **A grace period after a swipe ends.** Lift opens at once, as taps do.
- **Running or hidden indicators, or window previews, in the switcher.** Just icons and the selected name.
- **Sound effect on gestures.** Still deferred from plan 001.
- **A 6-finger gesture, or swipes with other finger counts.** Five is the hand; the swipe is the way past it.

## Design

### Problem

Plan 006 adds a fifth tap gesture, a two-finger swipe that drives an on-screen switcher, a switcher list edited in the launcher window, and scroll suppression in the existing event tap. The fifth tap is one enum case: `Gesture(fingerCount:)` returning nil is the only thing that silences five fingers today (F13). The swipe is the first gesture that lasts, that outlives the thumb, and that produces a stream instead of one event. It breaks three assumptions the recognizer was built on: every non-idle state carries the anchor and dies with it (F9 iii); a two-finger rest ends at 400 ms (F9 i); a movement past 3 mm spoils the tap (F9 ii). It must keep the one per-trackpad flag true for its whole length, however long and whether or not the thumb stays (F9 iv, F21), stream about 100 Hz of travel to the main actor without a reordering hazard (F6, F7), and use no timer and no second clock (F8, F27). Scroll suppression rides on that same flag, read when each event arrives, and needs one piece of memory per scroll gesture because momentum arrives after the fingers have lifted (F18). It also has to pass a source gate that bans the very API it uses: the token moves from banned to confined, never weakened (F17). The frontmost app is a main-actor fact read through `NSWorkspace` (F1, F2); the list's 80 pt icons take up to 220 ms to draw cold (F4) and must be ready before the swipe; a record saved by today's build must still decode (F22, F23); the window must grow with the list and cap at the visible frame (F28, F36). Constraints carried over: one `@MainActor @Observable` `Launcher` owns every decision and the shell renders its state (F24); every port has exactly two adapters and framework types never cross one (F25); recognition stays on the frame thread and the in-memory hardware delivers synchronously (F7); every field has one writer; `LauncherCore` imports Foundation and Observation only.

### Usage (caller's view)

**README excerpt.** The recognizer still owns everything that happens on the frame thread. Per frame it returns `Recognition { event, blocksClicks }`: `event` is a fired tap (one to five fingers) or a swipe phase, `began`, `moved(travelMM:)`, `ended` or `cancelled`; travel is the sideways movement of the two fingers' midpoint since the swipe began, in trackpad millimetres, positive to the right in both hand modes. `blocksClicks` is true for the whole of a swipe. The hardware adapter delivers events to the main actor in frame order and never from a session a later `run` replaced. `Launcher` turns a swipe into one observable value, `switcher: Switcher?`: the row fixed at begin, the home index where the frontmost app sits, and the travel; the selection, the highlight's position and its rubber band are pure functions of that value. Each icon crossed plays a light tick; at the end the model brings the selected app to the front unless the selection is still the frontmost app. The shell draws the switcher from `switcher` and nothing else. Scroll suppression happens in the same tap, on the same flag, with a pure `ScrollFilter` beside `ClickFilter`. The switcher list is a `SwitcherList` value inside `Settings`, edited through three intents. Tests drive all of it synchronously through `World`.

```swift
// TrackpadLauncher app target: the composition root does not change. MenuBarShell owns the switcher's presenter;
// WorkspaceActions answers the one new question (the frontmost app).
let launcher = Launcher(
    hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(),
    access: SystemAccessibilityPermission(), system: WorkspaceActions(), catalog: catalog,
    scanner: SystemAppScanner(catalog: catalog), store: SettingsStore(defaults: .standard))
let shell = MenuBarShell(launcher: launcher)
launcher.start()
```

```swift
// LauncherCoreTests, the high seam. R4, R5, R6, R7 while the fingers are down; R8 at the lift. Synchronous throughout.
@MainActor @Test func liftingOpensTheSelectionWithTheGestureHapticAndNoLaunchAnimation() {
    let world = World(apps: ["Safari", "Mail", "Slack", "Notes"])
    world.launcher.start()
    for name in ["Mail", "Slack", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
    world.makeFrontmost("Safari")

    var hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2)
        .slide(byMM: (3.5, 0))                       // past 3 mm, sideways: the swipe begins, travel 0
        .slide(byMM: (24, 0))                        // two icons right
    world.play(hand)
    #expect(world.launcher.switcher?.row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"])
    #expect(world.launcher.switcher?.selectedApp.name == "Slack")
    #expect(world.hardware.lightTicks.count == 2)

    hand = hand.lift()
    world.play(hand)                                 // delivers only the frames not delivered yet
    #expect(world.system.broughtToFront == [world.app("Slack")])
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])   // the gesture haptic, once
    #expect(world.system.launchAnimations.isEmpty)
    #expect(world.launcher.switcher == nil)
}

// R8 "Staying on the frontmost app": silent, and the window stays as it was.
@MainActor @Test func liftingOnTheFrontmostAppDoesNothingButCloseTheSwitcher() {
    let world = World.switcherWorld()                // Safari frontmost; Mail, Slack, Notes listed; started
    world.launcher.openWindow()
    world.swipe(3.5, 4)                              // 4 mm: nearer Safari than Mail
    #expect(world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty)
    #expect(world.launcher.isWindowOpen)
}

// R12, R13, R14 at the high seam: the fake tap decides scroll events on the flags the frames left.
@MainActor @Test func aLateSwipeLetsItsFirstMillimetresScrollThenStillsTheRestAndTheMomentum() {
    let world = World.switcherWorld(accessGranted: true)
    var hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(4)).land(fingers: 2).slide(byMM: (2, 0))
    world.play(hand)
    #expect(world.hardware.scroll(.fingers(.began)) == .pass)        // window over, no swipe yet: the page may move
    hand = hand.slide(byMM: (10, 0))
    world.play(hand)
    #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)  // switcher up: nothing moves, the app's bracket stays whole
    hand = hand.press().slide(byMM: (12, 0)).lift()                  // R13: a press during a late swipe is blocked
    world.play(hand)
    #expect(world.hardware.pressVerdicts == [.drop, .drop])
    #expect(world.hardware.scroll(.momentum(.began)) == .passStill)   // R14: nothing coasts
    #expect(world.system.broughtToFront.count == 1)
}

// R23: a record saved by today's build still loads, and the new fields round-trip.
@MainActor @Test func aRecordWithoutASwitcherListLoadsWithAnEmptyOne() {
    let world = World(apps: ["Arc"])
    UserDefaults(suiteName: world.suiteName)!.set(Fixtures.recordSavedByPlan002(two: world.app("Arc")), forKey: "settings")
    let relaunched = world.relaunch()
    #expect(relaunched.app(for: .two) == .present(world.app("Arc")) && relaunched.switcherRows.isEmpty)
}
```

```swift
// The recognizer's own seam: R8, R9 and R13 frame by frame. The thumb lifts, then lands again, mid-swipe.
@Test func theThumbPlaysNoPartOnceASwipeHasBegunAndBlockingHoldsThroughout() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2)
        .slide(byMM: (5, 0)).liftThumb().slide(byMM: (24, 0)).thumb(atMM: (12, 10)).lift().frames
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let steps = frames.map { recognizer.step($0) }
    let phases = steps.compactMap(\.swipe)
    #expect(phases.first == .began && phases.last == .ended && !phases.contains(.cancelled))
    #expect(steps.drop { $0.swipe != .began }.prefix { $0.swipe != .ended }.allSatisfy(\.blocksClicks))
}

// Pure policy: R6's nearest-icon rule, the hard stops and the rubber band's bound. No adapter involved.
@Test(arguments: [(travel: 5.0, selected: 0), (6, 1), (7, 1), (24, 2), (-30, 0), (60, 3)])
func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
    var switcher = Switcher(listed: [mail, slack, notes], frontmost: safari, trackpad: Trackpad.macBook14.id)!
    switcher.travelMM = travel
    #expect(switcher.selected == selected)
    #expect(abs(switcher.stretch) < 0.2)             // switcherMaxStretch: never a fifth of an icon past an end
}

// The scroll filter's own seam: R12–R14 as a table.
@Test func aScrollIsSuppressedFromItsFirstBlockedEventThroughItsMomentum() {
    var filter = ScrollFilter()
    #expect(filter.decide(.fingers(.mayBegin), trackpadBlocking: true) == .drop)   // apps never see this gesture
    #expect(filter.decide(.fingers(.changed), trackpadBlocking: false) == .drop)   // the window closed meanwhile: still whole
    #expect(filter.decide(.fingers(.ended), trackpadBlocking: false) == .drop)
    #expect(filter.decide(.momentum(.began), trackpadBlocking: false) == .drop)    // nothing coasts
    #expect(filter.decide(.fingers(.began), trackpadBlocking: false) == .pass)     // the next scroll works at once
    #expect(filter.decide(.fingers(.ended), trackpadBlocking: false) == .pass)
    #expect(filter.decide(.momentum(.changed), trackpadBlocking: true) == .pass)   // coasting from before is not interrupted
    #expect(filter.decide(.wheel, trackpadBlocking: true) == .pass)                // a wheel mouse, never
}
```

```swift
// LauncherUI: the presenter renders the model's value and holds nothing the model holds.
for await shown in Observations({ launcher.switcher }) { self?.render(shown) }

// LauncherUI.LauncherView: the section sits between the gesture rows and the hand toggle; each edit is one intent.
ForEach(launcher.rows) { row in GestureRowView(row: row, launcher: launcher, actions: actions) }
SwitcherSection(launcher: launcher, actions: actions)      // illustration + title, rows, Add app…
HandModeToggle(launcher: launcher).padding(.top, 16)

AppMenuButton(
    .pullDown(title: "Add app…"),
    menu: { launcher.installedApps.addMenu(listing: Set(launcher.switcherRows.map(\.id))) },
    cachedIcon: actions.cachedIcon, icon: actions.icon,
    choose: { $0.map { launcher.addToSwitcher($0) } },
    chooseOther: { actions.chooseOtherApp { launcher.addToSwitcher(.appBundle(at: $0)) } })
```

### Shape

**Data first.**

- *What a frame meant.* `Recognition { event: Event?; blocksClicks: Bool }`, where `Recognition.Event` is `.fired(Gesture)` or `.swipe(SwipePhase)`. A frame yields at most one event, because a tap fires on the frame its last finger is gone and a swipe begins on a frame a finger is still down; one optional sum instead of two optionals whose valid combinations a comment would have to explain (per `type-system-discipline`). `fired` and `swipe` are derived accessors, so every existing `fired(_:)` test reads as before. `blocksClicks` keeps its name: scroll suppression is defined in terms of click blocking (the glossary's *Click blocking*), and the flag is still that one decision.
- *What crosses the hardware port.* `TrackpadEvent` gains `.swipe(SwipeEvent)`, where `SwipeEvent` is a `SwipePhase` plus the `TrackpadID`. The payload is plain values: travel is a `Double` in millimetres, absolute since begin (a coalesced or late `moved` is harmless), no `CGPoint` and no frame time. One core initialiser, `TrackpadEvent(_ event: Recognition.Event, on: TrackpadID)`, is the only mapping and both adapters use it. *Ordering guarantee:* events reach `onEvent` on the main actor in the order each trackpad's frames produced them, and never from a session that a later `run` replaced.
- *What the recognizer remembers.* `State` gains `.resting(Anchor, Pair)`, two fingers still down past 400 ms, no longer a tap but still able to become a swipe, and `.swiping(Swipe)`, where `Swipe` carries the `Pair`, the midpoint where it began, the last travel it reported, and `thumb: Anchor?`. The four tap states keep a required `Anchor`; the thumb is optional only in a swipe, because a swipe outlives it. `Pair` is built as exactly two `Finger`s (id plus landing origin): constructed, not checked, so "exactly two" cannot drift.
- *What the model shows.* `Launcher.switcher: Switcher?` is non-nil exactly while a switcher is on screen. `Switcher` holds the `row`, the `home` index of the frontmost app, `travelMM` and the trackpad. Its row always has at least two icons and always holds the frontmost app at `home`; its failable initialiser is the only constructor, so a switcher that R11 forbids cannot exist. `selected`, `position` (where the highlight rests, in icons) and `stretch` (the bounded rubber band) are derived, never stored. `switcherRows: [SwitcherRow]` is the window's list: each row is the stored `AssignedApp` plus `present: AppEntry?`, nil meaning missing by the rule gesture rows already use (F3).
- *What persists.* `Settings.switcherList: SwitcherList`, a value whose only mutations are `append` (ignores a bundle ID already listed), `remove`, and `move(_:to:)` (clamps the index). It is encoded as a plain array and drops duplicates when decoded. `Settings` gets a hand-written `init(from:)` that reads the new key with `decodeIfPresent` (F22).
- *What the tap sees.* `TapEvent` is `.pointer(PointerEvent)` or `.scroll(ScrollEvent)`: the one parse of a `CGEvent`, inside `ClickTap`. `ScrollEvent` has four cases: `.wheel` (`isContinuous == 0`), `.fingers(Phase)`, `.momentum(Momentum)`, `.unphased`. `ScrollVerdict` is `.pass`, `.drop` or `.passStill` (deltas zeroed in place). `ClickFilter`, `PointerEvent` and `PointerVerdict` do not change.
- *What the window needs.* `PickerItem.app(AppEntry, state: AppItemState)` with `AppItemState` `plain | current | listed` (checked; checked and disabled) replaces the bare `checked:` flag, so checked and disabled are one dimension of one item. `InstalledApps.addMenu(listing:)` is the Add app… menu. `Copy.gestureHint(for:)` and `Copy.accessibilityHint` are the two strings R15 and R24 pin, kept in core so they are tested as values; the view swaps the `●` and `◉` characters for its images. `AppChoice` loses `.unassigned`: `setAssignment(_ choice: AppChoice?, for:)` reads nil as None, matching `assignments`' own "absent = unassigned", and `addToSwitcher(_ choice: AppChoice)` has no case to ignore.
- *Haptics.* `Haptic` is `.gesture` or `.lightTick`; `playFeedback(_:on:)` takes one.

**Load-bearing decisions.**

1. *One recognizer owns the finger session; the swipe is two more states of it (O1; F9, F10, F11).* A tap, a resting pair and a swipe are three readings of the same non-thumb fingers since the last moment none was down. They must agree on `touched`, on the landing origins and on the flag, so a second state machine beside this one would be two owners of one decision (per `model-the-domain`). The rules:
   - *Begin.* The drag check in `.tapping` becomes the swipe's entry. When the farthest-moved finger passes 3 mm, the tap becomes `.swiping` if swipes are on, the tap is a `Pair` (exactly two touched, both down, none joining on this frame) and that finger's displacement is more sideways than vertical (`|dx| > |dy|` in mm); otherwise it is spoiled as today. The drag check runs before the 400 ms check, so a slow pair that moves on the frame it crosses 400 ms still begins (R3 "no time limit").
   - *No time limit (R3).* The 400 ms rule no longer spoils a `Pair`; it moves it to `.resting`. `.resting` never fires a tap, which keeps plan 002 R2 (`twoFingersHeldFiveHundredMillisecondsFireNothing`). It spoils on a delivered click, on either finger lifting, or on any other non-thumb contact landing; it becomes `.swiping` on a sideways first move past 3 mm and is spoiled by a vertical one.
   - *Thumb before fingers (R3).* Holds by construction: a tap only starts from `.armed`; fingers already down when the thumb lands put the recognizer in `.spoiled`, which never begins a swipe.
   - *During a swipe the thumb plays no part (R8, R9).* The top-of-step anchor check covers only the anchored states. `.swiping` keeps its own `thumb: Anchor?`: it becomes nil when it lifts (a reused id counts) or leaves `holds`; while it is nil, a contact landing in `admits` becomes the thumb with `landedAt = frame.time`; a contact already down is never adopted (F10's `.idle` rule). The thumb is handled before the exits, so a thumb landing on the exit frame is the anchor afterwards.
   - *Exits, all named, in this order:* a `.click` press → `cancelled`; either pair finger lifting → `ended` (the first lift wins; R8); a contact landing outside `admits` that is not the thumb → `cancelled` (R9). A `.blocked` press changes nothing. Every exit goes to `thumb.map(.spoiled) ?? .idle`: with a thumb, `.spoiled` recovers only when the thumb is alone; without one, `.idle` never adopts a resting contact and a thumb landing beside resting fingers goes to `.spoiled`. Both are "nothing further until every non-thumb finger has lifted". `run` ends any swipe because it replaces the recognizer; `reconcile()` clears `switcher` for the same reason.
   - *Blocking after the swipe.* Plan 002 R4 alone decides, from the current thumb's `landedAt`: a thumb that re-landed mid-swipe opens its own fresh 3-second window; the original thumb keeps its original one.
2. *The flag stays the only channel (F21; `why.md` Change).* `blocksClicks` is `true` in `.swiping`, whatever the anchor or the clock says, and follows the unchanged R4 expression in every other state. The tap reads it for presses and now for scrolls. Nothing new crosses between threads (per "single source of truth per invariant").
3. *Swipes are recognised only while the switcher list is not empty (R11).* `TrackpadHardware.run` gains `swipes: Bool` and `reconcile()` passes `!settings.switcherList.isEmpty`. With swipes off the recognizer behaves exactly as today plus five fingers: a pair's drag spoils, a resting pair spoils at 400 ms. Without this gate, every user with an empty list (every upgrading user) would find an anchored thumb plus a sideways two-finger scroll suppressed for its whole length, past the 3 s window, while R11 says such a movement "MUST do nothing". The list's emptiness flips only through the three edit intents, which reconcile only on a flip. What the frame thread cannot know, the model ends: when a `began` yields no switcher (the list holds only missing apps or only the frontmost app, or no frontmost app can be read), `swipe(.began)` calls `reconcile()`, the one operation that replaces recognizers. The fresh recognizer sees the thumb and the resting fingers already down on its first frame and goes to `.spoiled` with no window (their landing time is unknown), so clicks and the next scroll work again at once and the remaining fingers do nothing until they lift: R11's "do nothing" holds with no main-to-frame channel, and the block lasts only from the begin frame until main handles the event. A scroll in progress at that moment is not stilled to its end: `run` replaces the tap and its filters, so the gesture's next event reaches a fresh `ScrollFilter` with the flag down and passes, resumed after a brief stop (inside the 3 s window it resumes without the `began` the dropped gesture never showed apps, the headless gesture the disabled-tap recovery already accepts). The empty list keeps the gate rather than this fallback because the fallback restarts the devices and the tap, which every upgrading user would otherwise meet on every anchored sideways scroll.
4. *Travel crosses the port and the selection is decided on main (O2; F11).* The recognizer knows millimetres and nothing about rows. The row depends on the frontmost app and on the catalog, main-actor facts, so the selection belongs to the pure `Switcher` in core: `selected = clamp(home + round(travel / 12 mm))`, rounding half away from zero, so it changes at ±6 mm and then every 12 mm, reversibly; `position = clamp(home + travel / 12 mm)`; `stretch` is the signed excess past an end passed through a saturating function bounded below 0.2 icons. Right is +x on `SurfacePoint` in both hand modes, so R6's direction rule needs no code. The model plays `|selected after − selected before|` light ticks per `moved` (R7 "one per icon crossed", even when one frame crosses two).
5. *Delivery is the main queue, gated by run generation (O3; F6, F7).* `MultitouchTrackpads` hops with `DispatchQueue.main.async { MainActor.assumeIsolated { … } }`, the path libdispatch documents as FIFO and the one `SystemAppScanner` already uses, so events arrive in frame order without resting on the observed but undocumented order of unstructured tasks. Each session's deliver closure captures the `run` generation that made it; on main, an event whose generation is stale is dropped. This closes the existing "a session fetched just before `run` can still deliver" gap for taps too, and for a `began` it is not a nicety: a stale `began` arriving after `reconcile()` cleared `switcher` would open a switcher that no recognizer can ever end. The in-memory adapter keeps calling `onEvent` inline (F7) and does not model the gate.
6. *The frontmost app is read once, at begin, through `SystemActions` (O6; F1, F2, F3).* `frontmostApp() -> URL?` returns the active app's bundle location, or nil when there is none or when it is Trackpad Launcher itself. The model parses it with `catalog.entry(at:)`, the one rule that builds an `AppEntry` from disk, as Other… already does; identity is the bundle ID. Nil or self means no switcher, and the swipe is ended through `reconcile()` as in decision 3: a `Switcher` has no meaning without a home, and starting anywhere else would make a lift without moving open an app. F1 shows a frontmost app always exists in practice; F2 shows self is possible only while the Other… chooser is up. It is a query on the workspace port beside `bringToFront`, its natural pair; a one-method port would be a hypothetical seam.
7. *The row is built fresh at begin, cheaply.* `settings.switcherList.apps.compactMap(catalog.locate)` on the main actor, as `fire` locates fresh at fire time (F3). `AppCatalog.locate` changes to consult `registeredCopies` only when `lastKnownURL` misses (today it runs the LaunchServices query for every app before looking): the common case becomes one Info.plist read per listed app, tens of microseconds warm, and `fire` gets the same saving. Same semantics, since the two lookups were already ordered.
8. *The switcher is model state rendered by `LauncherUI`, with AppKit and Core Animation (O5; F24, F26, F27, F32).* The model owns which apps are shown, which one is selected, when the switcher shows, and every effect; a test reads `launcher.switcher` with no fake. `SwitcherPresenter`, owned by `MenuBarShell`, iterates `Observations({ launcher.switcher })`, which coalesces to the latest value per main-actor turn, a natural back-pressure at ~100 Hz. Its `SwitcherPanel` uses the launch overlay's configuration (F26: borderless, `.nonactivatingPanel`, `ignoresMouseEvents`, `.screenSaver` level, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `animationBehavior = .none`, never key) around an `NSGlassEffectView` in a rounded clip as `LauncherPanel` does, holding a layer-backed host for the 80 pt icon layers, a glass highlight view 92 pt square, and a name label. It is created once at shell init (F32's 27 ms). *On open:* size the panel from the icon count (deterministic: `count × 80 + (count − 1) × 20` plus padding), centre it on the display under `NSEvent.mouseLocation` by the `NSMouseInRect` rule `LaunchFlight` uses (nearest display otherwise), `orderFrontRegardless`. *Per update, with actions disabled:* highlight x = `position × 100 pt`, so it follows the fingers one to one; the selected icon layer at 1.12× with the name below. *When `stretch` changes and is not zero:* add an additive `CASpringAnimation` on the highlight layer's `position.x`, keyed so each one replaces the last, from `stretch × 100 pt` to 0. While the push extends, the highlight tracks the saturated overshoot; when the fingers stop, the last spring settles it on the end icon: "moved only slightly past, and springs back" with no code of ours per display frame. *On close:* opacity to 0 over 150 ms, `orderOut` from the completion unless a new switcher opened meanwhile. *Reduce motion:* no spring (the highlight rests on the end icon), no scale animation, no fade.
9. *Icons are ready before the swipe (F4, F5).* `AppIcons` gains a `side` parameter; the presenter holds an 80 pt instance. It re-renders the list's present apps off the main actor whenever `switcherRows` changes and when `NSApp.effectiveAppearance` changes (KVO, a push; macOS 26 icons have dark variants). A frontmost app outside the list is looked up through `NSRunningApplication.icon`, 0.1 ms in both probe runs. A cache miss for a listed app falls back to drawing on the spot, as `LaunchOverlay.bitmap(for:)` does.
10. *Haptics take a kind (O8; F14).* `.gesture` maps to actuation 6 (unchanged) and `.lightTick` to 3, the "weak" one the existing comment names; tuned by feel. The model plays the gesture haptic only when an app is brought to front.
11. *Scrolls are suppressed per scroll gesture, in the one tap, by a filter of their own (O4; F8, F15–F20).* `ClickTap` adds `.scrollWheel` (22) to its mask and keeps a `Mutex<ScrollFilter>` beside its `Mutex<ClickFilter>`; both read the same `anyTrackpadBlocksClicks()` before taking their own lock, one at a time. The press filter does not change: one policy per filter. *The memory is the treatment of the scroll gesture in progress, momentum included:* a gesture first seen at an opening event (`mayBegin` or `began`) while blocking is `dropped`, so apps never see any of it; a gesture that was passing and meets blocking mid-way becomes `stilled`, its remaining events passed with every delta zeroed (axes 1–3 in lines, fixed point and points), so the app's began-to-ended bracket closes and nothing moves; a `passed` gesture's momentum is never touched (R14 "coasting from before"); the treatment never relaxes inside a gesture, the scroll analogue of plan 002 R5's whole press. This is what survives the race the single flag cannot order: a `changed` or `ended` arriving after the lift frame has cleared the flag is still part of a gesture already decided, so nothing leaks after a swipe (R13 "before, during or after"). *Exemptions and resets:* `.wheel` always passes (R12); `.unphased` is decided per event on the flag; momentum with no known gesture passes; on `tapDisabledBy…` the filter forgets the gesture in progress, as `forgetHeldPresses()` does. Without access there is no tap, so nothing is suppressed (F20). Zeroing is an in-place rewrite like `passAsMove`; nothing is posted.
12. *The gate moves the token; it does not weaken it (F17).* `scrollWheel` leaves `banned` and becomes `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift")`; `ScrollWheel` stays banned with its rule relabelled, which passes the case-sensitive overlap check. Every scroll field name lives in that one file; core comments say "scroll event".
13. *Persistence is tolerant by construction (F22, F23).* A missing `switcherList` key decodes as empty; `handMode` and `assignments` decode as today; the first-launch rule (no record means first launch) and "undecodable loads as defaults" are unchanged; an old record's `assignments` decode into the five-case `Gesture`.
14. *The window reuses the picker machinery (O7, O9; F28–F31, F36).* *The Add menu* is a pure shape: `addMenu(listing:)` returns the recent apps, a divider, the others, a divider, then Other…, with no None; a listed app is `.app(entry, state: .listed)`. `AppPicker` becomes `AppMenuButton` in two forms over one coordinator: `.popUp(current:)` shows the row's app and builds `pickerMenu(checking:)`, `.pullDown(title:)` shows the title and builds the `menu` closure's items in `menuNeedsUpdate` from values in memory with `cachedIcon`; `.listed` items are checked and disabled. *Other…:* `LauncherActions.chooseOtherApp` takes its completion, `(URL) -> Void`, so one chooser serves rows and the list. *Reorder:* a `DragGesture` on each row; rows have a fixed pitch, the dragged row follows the pointer, the drop index is `start + round(dy / pitch)` and the model clamps it. This needs no drag session or pasteboard, so it does not depend on drag-and-drop inside a non-activating panel (O9 unprobed) and the rows stay inside a `ScrollView` that sizes to its content. *Remove:* an `.onHover` trailing button and `.contextMenu { Remove }`. *The height cap (R22):* the list is a `ScrollView` with `.layoutPriority(-1)`; the root keeps `fixedSize` horizontally only; `fitToContent` caps the panel's height at the visible frame minus 16 pt, and SwiftUI's own layout takes the whole deficit out of the list alone (F36, probed). *Refits:* `MenuBarShell` also refits when `switcherRows.count` changes.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init(handMode:surface:swipes:)`, `step` → `Recognition` (2 stored fields) | Taps of 1–5 fingers; the swipe's entry (pair, sideways, 3 mm, no time limit); vertical inertness; thumb independence and re-anchoring; three named exits; travel in mm; the swipe-wide block |
| `Switcher` | failable `init`, `travelMM`; `row`, `home`, `selected`, `selectedApp`, `selectsFrontmost`, `position`, `stretch` | R4's row rule, R5's start, R6's nearest icon, 12 mm, hard stops and the bounded rubber band, R11's "nothing to switch to" |
| `SwitcherList` | `apps`, `isEmpty`, `append`, `remove`, `move`, `Codable` | No duplicates ever, clamped moves, array coding with dedupe on decode |
| `ScrollFilter` | `init`, `decide`, `forgetGesture` | Per-gesture treatment (dropped, stilled, passed), momentum inheritance, the wheel exemption, unknown coasting, the never-relax rule |
| `TrackpadHardware` | `run` gains `swipes`; `playFeedback` gains a kind | Plus: the FIFO hop, the stale-session gate, scroll parsing, zeroing, the actuation table |
| `SystemActions` | gains `frontmostApp()` | `NSWorkspace`, `NSRunningApplication`, excluding itself |
| `Launcher` | gains `switcher`, `switcherRows`, 3 intents | Plus: row building at begin, R11, ticks, end effects, closing the switcher on reconcile, reconciling when the list's emptiness flips |
| `InstalledApps` | gains `addMenu(listing:)` | The second menu shape with its disabled state |

The public surface grows by: one sum type on `step`'s result; one case on `TrackpadEvent` and one initialiser; one argument on `run`; one argument on `playFeedback`; one query on `SystemActions`; two observed properties and three intents on `Launcher`; one method on `InstalledApps`; the `Copy` values. A frame reaches a highlight on screen through `GestureRecognizer`, `MultitouchTrackpads`, `Launcher`/`Switcher`, `SwitcherPresenter`: three modules. `switcher` has one writer.

**Concurrency** (one writer per field).

- *Frame thread:* the recognizer as today. Each session's `blocking` flag is written before `deliver`, so the swipe-wide block is in effect before main knows a swipe began. ~100 Hz while a swipe moves: input-driven work, not a per-display-frame loop (F27).
- *Tap thread:* the `ClickFilter` and `ScrollFilter` mutexes, each written only there, taken one at a time after the flag read; scroll events add ~100–250 Hz of wake-ups while anyone scrolls with the tap armed (F19, accepted).
- *Main:* `Launcher.switcher` is written only by `swipe(_:)` and by `reconcile()`. `MultitouchTrackpads.runs` is written only by `run`. Every field the presenter's layers touch is main-only; the 80 pt `AppIcons` merges off-main renders on main as the 16 pt one does.

#### Module map

```
LauncherCore     (Foundation, Observation)   Gesture (+ five) · Recognition (+ Event, SwipePhase) · SwipeEvent ·
                                              GestureRecognizer (+ resting, swiping, Pair, Swipe, swipes flag) ·
                                              GestureRules (+ switcherStepMM, switcherMaxStretch) ·
                                              Switcher · SwitcherList · SwitcherRow · Settings (+ switcherList, tolerant init) ·
                                              AppChoice (no .unassigned) · PickerItem (state: AppItemState) · InstalledApps.addMenu ·
                                              AppCatalog.locate (lazy registered copies) · Copy ·
                                              ScrollEvent · ScrollVerdict · ScrollFilter · ClickFilter (unchanged) ·
                                              ports: TrackpadEvent (+ swipe, init), Haptic, TrackpadHardware (run + swipes,
                                              playFeedback(kind)), SystemActions (+ frontmostApp) · Launcher (+ switcher,
                                              switcherRows, list intents, swipe handling, reconcile cancel)
LauncherPlatform                              MultitouchTrackpads (main-queue hop, run generation, actuation per Haptic) ·
                                              DeviceSession (delivers TrackpadEvent) · ClickTap (TapEvent, scroll in the mask,
                                              ScrollFilter, ScrollEvent parsing, ScrollVerdict.apply zeroing) · WorkspaceActions (+ frontmostApp)
LauncherUI                                    SwitcherPresenter + SwitcherPanel (AppKit/CA, glass) · AppIcons (side) · SwitcherSection ·
                                              SwitcherListRow · AppMenuButton (popUp + pullDown) · LauncherView (5 rows, section,
                                              Copy) · LauncherPanel.fitToContent (height cap) · MenuBarShell (presenter, refit on
                                              list count, appearance KVO) · LauncherActions.chooseOtherApp(then:)
TrackpadLauncher app target                   unchanged · assets/gesture-5.svg, assets/swipe.svg (drawn during implementation, O10)
Tests                                         LauncherCoreTests: recognizer, Switcher, SwitcherList, ScrollFilter, addMenu, Copy,
                                              World seam, SourcePolicyTests; InMemoryTrackpads (swipe delivery, pulses, scroll),
                                              RecordingSystemActions (frontmost), TouchScript (land, slide, lift, press, thumb
                                              re-land), World (play, swipe, makeFrontmost, switcherWorld), Fixtures
                                              (recordSavedByPlan002) · LauncherPlatformTests: TapEvent parse, mask, zeroing
```

#### LauncherCore: recognition

```swift
/// One of the five tap gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1, two, three, four, five
    /// nil outside 1...5: a six-finger tap is not a gesture (R1).
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
}

/// A swipe's progress as the frame thread reports it.
public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved sideways past 3 mm. Travel is 0 here.
    case began
    /// Sideways movement of the two fingers' midpoint since `began`, in trackpad millimetres, positive to the right in
    /// both hand modes. Absolute, not a delta. Sent only when it changed.
    case moved(travelMM: Double)
    /// The first of the two fingers lifted: open the selection (R8).
    case ended
    /// A finger landed outside the anchor corner, or a press reached apps: open nothing (R9).
    case cancelled
}

/// A swipe phase on a specific trackpad (its haptics play there; its switcher belongs to it).
public struct SwipeEvent: Equatable, Sendable {
    public let phase: SwipePhase
    public let trackpad: TrackpadID
}

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// What one frame produced, if anything. A frame never both fires a tap and moves a swipe.
    public enum Event: Equatable, Sendable {
        case fired(Gesture)
        case swipe(SwipePhase)
    }
    public let event: Event?
    /// This trackpad's half of click blocking, which also suppresses trackpad scrolling (R12): true for the whole of
    /// a swipe (R13); otherwise a thumb this recognizer saw land less than 3 s ago is still anchored and another
    /// contact is down. Whether anything is really blocked also needs the filters armed.
    public let blocksClicks: Bool

    public var fired: Gesture? { if case .fired(let gesture)? = event { gesture } else { nil } }
    public var swipe: SwipePhase? { if case .swipe(let phase)? = event { phase } else { nil } }
}

package enum GestureRules {
    // … unchanged …
    /// Icons are this far apart in finger travel; the selection is the nearest icon (R6).
    static let switcherStepMM = 12.0
    /// The most the highlight's rubber band shows past an end, in icons (R6 "only slightly past it").
    static let switcherMaxStretch = 0.2
}

public struct GestureRecognizer: Sendable {
    /// `swipes`: false while the switcher list is empty; a pair's drag then spoils like any drag (R11).
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Bool = true) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // Per-frame sets exactly as today: isFirstFrame, before, down, reused, lifted, landed; defer previouslyDown.
        //
        // 1. Anchor check as today, but only for the anchored states (state.anchor is nil for .idle and .swiping):
        //      anchor lifted (reused counts) or outside holds → .idle
        //
        // 2. switch state
        //    .idle, .armed, .spoiled: unchanged.
        //
        //    .tapping(anchor, var tap):
        //      drop lifted ids from tap.down; joining = landed minus the anchor
        //      pair = swipes ? Pair(tap, joining: joining) : nil
        //      if frame.press == .click                                   → .spoiled(anchor)
        //      else if let move = Self.drag(of: tap.fingers, in: down)    // the farthest finger, if past 3 mm
        //          pair != nil && move.isSideways                         → begin(pair, anchor)
        //          otherwise                                              → .spoiled(anchor)
        //      else if frame.time - tap.start > maxTapDuration            → pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)
        //      else if tap.down.isEmpty                                   → event = Gesture(fingerCount: tap.touched.count).map(.fired);
        //                                                                   re-arm or start the next Tap, as today
        //      else join `joining`, as today
        //
        //    .resting(anchor, pair):                                      // fires nothing, ever
        //      if frame.press == .click, a pair finger lifted, or any non-anchor contact landed → .spoiled(anchor)
        //      else if let move = Self.drag(of: pair.fingers, in: down)   → move.isSideways ? begin(pair, anchor) : .spoiled(anchor)
        //
        //    .swiping(var swipe):                                         // the thumb plays no part
        //      if let thumb = swipe.thumb, lifted.contains(thumb.id) || !(down[thumb.id].map { corner.holds($0.position) } ?? false)
        //          swipe.thumb = nil
        //      if swipe.thumb == nil, let thumb = landed.first(where: { corner.admits($0.position) })
        //          swipe.thumb = Anchor(id: thumb.id, landedAt: frame.time)   // R9 "Thumb lands again"; already-down contacts never
        //      after = swipe.thumb.map(State.spoiled) ?? .idle            // "nothing further until every non-thumb finger has lifted"
        //      if frame.press == .click                                   → state = after; event = .swipe(.cancelled)   (.blocked: nothing)
        //      else if swipe.pair.contains(any of lifted)                 → state = after; event = .swipe(.ended)       (the first lift wins)
        //      else if landed.contains { $0.id != swipe.thumb?.id && !corner.admits($0.position) }
        //                                                                 → state = after; event = .swipe(.cancelled)   (a finger outside the corner)
        //      else travel = (swipe.pair.midX(in: down) − swipe.startMidX) × surface.widthMM
        //           if travel != swipe.travelMM { swipe.travelMM = travel; event = .swipe(.moved(travelMM: travel)) }
        //           state = .swiping(swipe)
        //
        //    begin(pair, anchor): state = .swiping(Swipe(pair: pair, startMidX: pair.midX(in: down), thumb: anchor)); event = .swipe(.began)
        //
        // 3. blocksClicks = state is .swiping ? true : today's expression over state.anchor (unchanged)
        fatalError("not implemented")
    }

    private struct Finger: Sendable {
        let id: TouchID
        let origin: SurfacePoint
    }

    /// Exactly two fingers: the only shape a swipe has.
    private struct Pair: Sendable {
        let first: Finger
        let second: Finger
        /// The tap as a pair: exactly two fingers touched since the last moment none was down, both still down,
        /// and none joins on this frame.
        init?(_ tap: Tap, joining: [Touch]) { fatalError("not implemented") }
        var fingers: [Finger] { [first, second] }
        func contains(_ id: TouchID) -> Bool { first.id == id || second.id == id }
        /// Normalised x of the midpoint of the two fingers' current positions.
        func midX(in down: [TouchID: Touch]) -> Double { fatalError("not implemented") }
    }

    private struct Swipe: Sendable {
        let pair: Pair
        let startMidX: Double
        var travelMM: Double = 0
        /// The thumb as it is now. Only what happens after the swipe reads it.
        var thumb: Anchor?
    }

    /// A finger's displacement in millimetres from its landing point.
    private struct Move: Sendable {
        let dxMM: Double
        let dyMM: Double
        /// More sideways than up or down (R3).
        var isSideways: Bool { abs(dxMM) > abs(dyMM) }
    }

    /// The farthest-moved finger's displacement, when it is more than `dragThresholdMM`. Deterministic: the maximum.
    private static func drag(of fingers: [Finger], in down: [TouchID: Touch], on surface: SurfaceSize) -> Move? {
        fatalError("not implemented")
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        /// Two fingers still down past the tap limit: no longer a tap, still able to become a swipe (R3: no time limit).
        case resting(Anchor, Pair)
        case spoiled(Anchor)
        case swiping(Swipe)

        /// The anchor the top-of-step check maintains. A swipe keeps its own optional thumb instead.
        var anchor: Anchor? { fatalError("not implemented") }
    }
    // Anchor, Tap (+ `var fingers: [Finger]`), corner, surface, state, previouslyDown as today; `private let swipes: Bool`.
}
```

#### LauncherCore: the switcher, the list, settings, menus, copy

```swift
/// The switcher during one swipe. The row is fixed when the swipe begins; everything else follows the travel.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app first when the list lacks it, then the list's present apps in list order.
    /// Always at least two icons.
    public let row: [AppEntry]
    /// The frontmost app's index: the selection at travel 0 (R5).
    public let home: Int
    /// Sideways midpoint travel since the swipe began, in trackpad millimetres (R6). Written only by `Launcher` (and tests).
    public package(set) var travelMM: Double = 0
    public let trackpad: TrackpadID

    /// nil when the row would hold nothing besides the frontmost app (R11). `listed`: the list's present apps, in order.
    package init?(listed: [AppEntry], frontmost: AppEntry, trackpad: TrackpadID) {
        // row = listed holds frontmost.bundleID ? listed : [frontmost] + listed
        // home = index of frontmost.bundleID in row; guard row.count >= 2
        fatalError("not implemented")
    }

    /// The nearest icon, never past an end: home + round(travel / 12 mm), half away from zero, clamped. Changes at
    /// ±6 mm, then every 12 mm, in either direction.
    public var selected: Int { fatalError("not implemented") }
    public var selectedApp: AppEntry { row[selected] }
    /// Lifting here is a silent no-op (R8).
    public var selectsFrontmost: Bool { selected == home }
    /// Where the highlight rests, in icons: home + travel / 12 mm, clamped to the row. Between two icons it sits
    /// between them in proportion (R6).
    public var position: Double { fatalError("not implemented") }
    /// The rubber band past an end, in icons, signed, bounded below `switcherMaxStretch`:
    /// sign(excess) × max × (1 − 1 / (1 + |excess| / max)), where excess = unclamped position − position. 0 inside the row.
    public var stretch: Double { fatalError("not implemented") }
}

/// The user-ordered apps the switcher shows. No bundle ID appears twice.
public struct SwitcherList: Codable, Equatable, Sendable {
    public private(set) var apps: [AssignedApp] = []
    public var isEmpty: Bool { apps.isEmpty }
    public init() {}
    /// Appends at the end; an app already listed (same bundle ID) leaves the list unchanged (R18).
    package mutating func append(_ app: AssignedApp) { fatalError("not implemented") }
    package mutating func remove(_ id: BundleID) { fatalError("not implemented") }
    /// Moves the app to `index`, clamped into the list; an app not listed leaves it unchanged (R20).
    package mutating func move(_ id: BundleID, to index: Int) { fatalError("not implemented") }
    /// A plain array; a duplicate bundle ID keeps its first copy.
    public init(from decoder: any Decoder) throws { fatalError("not implemented") }
    public func encode(to encoder: any Encoder) throws { fatalError("not implemented") }
}

/// A switcher list row as the launcher window shows it.
public struct SwitcherRow: Identifiable, Equatable, Sendable {
    public let assigned: AssignedApp
    /// nil: missing, shown greyed as "<assigned.name>  not found"; recovers when a copy exists again (R17).
    public let present: AppEntry?
    public var id: BundleID { assigned.bundleID }
}

public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    public var assignments: [Gesture: AssignedApp] = [:]
    public var switcherList = SwitcherList()
    public init() {}
    /// Keys from the first release decode as before; a key added later decodes as absent → default, so a record
    /// saved by an older build keeps its assignments (F22). Encoding stays synthesized.
    public init(from decoder: any Decoder) throws {
        // handMode = decode; assignments = decode; switcherList = decodeIfPresent ?? SwitcherList()
        fatalError("not implemented")
    }
}

/// An app the user chose: from a menu, or any bundle on disk through Other…. None is `nil` at `setAssignment`.
public enum AppChoice: Sendable {
    case app(AppEntry)
    /// Parsed by `AppCatalog.entry(at:)`, ignored if not an app with a bundle ID.
    case appBundle(at: URL)
}

/// One line of an app menu.
public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, state: AppItemState)
    case divider
    /// Other…
    case other
    /// None.
    case unassigned
}

public enum AppItemState: Equatable, Sendable {
    case plain
    /// Checked: the picker's current app.
    case current
    /// Checked and disabled: already in the switcher list (R18).
    case listed
}

extension InstalledApps {
    /// An app picker's menu, as before; the row's present app is `.current`.
    public func pickerMenu(checking app: RowApp) -> [PickerItem] { fatalError("not implemented") }
    /// The switcher's Add app… menu: recent, divider, others, divider, Other…; no None. Listed apps are `.listed`.
    public func addMenu(listing listed: Set<BundleID>) -> [PickerItem] { fatalError("not implemented") }
}

extension AppCatalog {
    /// As today, but `registeredCopies` is consulted only when `lastKnownURL` misses: one Info.plist read in the common case.
    public func locate(_ app: AssignedApp) -> AppEntry? { fatalError("not implemented") }
}

/// The strings the window quotes verbatim, kept in core so they are tested as values (R15, R24).
public enum Copy {
    /// "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or
    /// swipe left or right with 2 fingers to switch apps"; "top-right" in left-hand mode. `●` and `◉` are the two
    /// marks the view draws as its template images.
    public static func gestureHint(for handMode: HandMode) -> String { fatalError("not implemented") }
    public static let accessibilityHint =
        "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them."
}
```

#### LauncherCore: scroll suppression

```swift
/// A scroll event as suppression needs it. Parsed in the tap; no event-system type crosses.
public enum ScrollEvent: Equatable, Sendable {
    /// Line-based, no phases: a scroll wheel. Never suppressed (R12).
    case wheel
    /// Fingers on a surface: a trackpad or a Magic Mouse, which the system reports alike.
    case fingers(Phase)
    /// Coasting after the fingers lifted.
    case momentum(Momentum)
    /// Continuous without phases: decided alone, on the flag.
    case unphased

    public enum Phase: Equatable, Sendable { case mayBegin, began, changed, ended, cancelled }
    public enum Momentum: Equatable, Sendable { case began, changed, ended }
}

public enum ScrollVerdict: Equatable, Sendable {
    case pass
    case drop
    /// Delivered with every delta zeroed: the app's gesture ends cleanly and nothing moves.
    case passStill
}

/// Scroll suppression for one event stream, as a pure state machine. Like `ClickFilter`, it knows no clock and no
/// device; `trackpadBlocking` is the same merged flag, read when the event arrives. One per tap, fed in order.
public struct ScrollFilter: Sendable {
    public init() {}

    public mutating func decide(_ event: ScrollEvent, trackpadBlocking: Bool) -> ScrollVerdict {
        // .wheel → .pass;  .unphased → blocking ? .drop : .pass
        // .fingers(phase):
        //   stage .touching(t)          → t' = (t == .passed && blocking) ? .stilled : t      (never relaxes)
        //   stage nil or .coasting      → a new gesture: t' = !blocking ? .passed
        //                                                : phase opens (mayBegin, began) ? .dropped : .stilled
        //                                 (a gesture first seen mid-way was already seen by apps: only stilling keeps it whole)
        //   stage = phase closes (ended, cancelled) ? .coasting(t') : .touching(t')
        //   return t'.verdict
        // .momentum(m):
        //   stage .coasting(t) or .touching(t) → t.verdict, and stage = nil after .ended   (momentum inherits; never escalates: R14)
        //   stage nil                          → .pass                                      (unknown coasting is never interrupted)
        fatalError("not implemented")
    }

    /// The system disabled the tap; events may have passed unseen. Forget the gesture in progress (under-blocking).
    public mutating func forgetGesture() { stage = nil }

    private enum Treatment: Sendable { case passed, dropped, stilled }   // .verdict: .pass, .drop, .passStill
    private enum Stage: Sendable { case touching(Treatment), coasting(Treatment) }
    private var stage: Stage?
}
```

#### LauncherCore: ports and the model

```swift
public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case swipe(SwipeEvent)
    /// Attached, detached, or the Mac woke.
    case trackpadsChanged
    /// The one mapping from what a recognizer said to what the port carries. Both hardware adapters use it.
    public init(_ event: Recognition.Event, on trackpad: TrackpadID) { fatalError("not implemented") }
}

/// The two haptics: the gesture haptic when an app comes to the front, and the lighter tick per selection change.
public enum Haptic: Sendable { case gesture, lightTick }

@MainActor public protocol TrackpadHardware: AnyObject {
    /// On the main actor, in the order each trackpad's frames produced them. Never for a session a later `run` replaced.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    func connected() -> [Trackpad]
    /// As today, plus `swipes`: whether each fresh recognizer recognises swipes. Ends any swipe in progress.
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, swipes: Bool)
    /// One pulse of that kind on that trackpad. No-op if it is gone.
    func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)
}

/// The workspace: effects the core decides and macOS performs, and the one fact the core reads back from it.
@MainActor public protocol SystemActions: AnyObject {
    // bringToFront, registerLoginItem, prepareLaunchAnimations, playLaunchAnimation: unchanged
    /// The active app's bundle location, read now. nil when there is none, it has no bundle, or it is Trackpad
    /// Launcher itself (which never activates except around the Other… chooser, F2).
    func frontmostApp() -> URL?
}

@MainActor @Observable public final class Launcher {
    public private(set) var rows: [GestureRow] = []                 // five, by Gesture.allCases
    /// The switcher list as the window shows it, in switcher order. Resolved with `rows`.
    public private(set) var switcherRows: [SwitcherRow] = []
    /// Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`.
    public private(set) var switcher: Switcher?
    // … everything else as today …

    /// App picker. nil = None.
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) { fatalError("not implemented") }
    /// Add app… and its Other…: appends; an app already listed is left where it is (R18).
    public func addToSwitcher(_ choice: AppChoice) { fatalError("not implemented") }
    public func removeFromSwitcher(_ app: BundleID) { fatalError("not implemented") }
    /// Drag to reorder: `index` is where the row lands, clamped into the list (R20).
    public func moveInSwitcher(_ app: BundleID, to index: Int) { fatalError("not implemented") }

    // init: rows = makeRows(); switcherRows = makeSwitcherRows() — no effects, as today, so a relaunched model reads both.
    // start(): onEvent gains `case .swipe(let event): swipe(event)`.

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        // .began:     guard switcher == nil, activity.isActive
        //             frontmost = system.frontmostApp().flatMap(catalog.entry(at:))                      — nil or self: no home (O6)
        //             listed = settings.switcherList.apps.compactMap(catalog.locate)                    — missing apps left out (R4)
        //             switcher = frontmost.flatMap { Switcher(listed: listed, frontmost: $0, trackpad: event.trackpad) }   — nil: R11
        //             if switcher == nil { reconcile() }   — nothing to show: end the swipe from main, so nothing stays blocked (R11);
        //                                                    the same re-entry as `.trackpadsChanged` → reconcile() inside onEvent today
        // .moved(t):  guard var open = switcher, open.trackpad == event.trackpad
        //             before = open.selected; open.travelMM = t; switcher = open
        //             |open.selected − before| × hardware.playFeedback(.lightTick, on: event.trackpad)   (R7)
        // .ended:     guard let open = switcher, open.trackpad == event.trackpad; switcher = nil
        //             guard !open.selectsFrontmost                                                        (R8: silent)
        //             hardware.playFeedback(.gesture, on:); system.bringToFront(open.selectedApp); window = .closed
        //             — no launch animation
        // .cancelled: if switcher?.trackpad == event.trackpad { switcher = nil }                        (R9)
        fatalError("not implemented")
    }

    // reconcile(): switcher = nil; … hardware.run(active ? connected : [], handMode:, blockClicks: active && granted,
    //                                             swipes: !settings.switcherList.isEmpty)
    // fire(_:): playFeedback(.gesture, on:) — otherwise unchanged
    // resolveRows(): also switcherRows = settings.switcherList.apps.map { SwitcherRow(assigned: $0, present: catalog.locate($0)) };
    //                prepareLaunchAnimations still for the rows' present apps only (a swipe plays no animation)
    // list intents: edit settings.switcherList, save, resolveRows(), and reconcile() only when isEmpty flipped
}
```

#### LauncherPlatform

```swift
// MultitouchTrackpads
private var runs = 0                                   // main only; run bumps it first
// in run, per session:
let generation = runs
deliver: { [weak self] event in
    DispatchQueue.main.async {                          // documented FIFO from this frame thread
        MainActor.assumeIsolated {
            guard let self, self.runs == generation else { return }   // a later run replaced this session
            self.onEvent?(event)
        }
    }
}
public func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID) { fatalError("not implemented") }
/// Chosen by feel: 3 weak, 4 medium, 6 strong (F14). The tick starts at 3; the feel check may move it to 4.
static func actuation(for haptic: Haptic) -> Int32 { fatalError("not implemented") }   // .gesture → 6, .lightTick → 3

// DeviceSession: `deliver: @Sendable (TrackpadEvent) -> Void`; receive writes `blocking` first, then
//   `if let event = recognition.event { deliver(TrackpadEvent(event, on: trackpad)) }`

// ClickTap.swift (the only file that may say scrollWheel)
/// Everything the tap is told about, parsed. `PointerEvent` keeps its vocabulary: a press and what belongs to it.
enum TapEvent: Equatable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    /// Buttons, drags, pressure (34) and scroll (22). A test parses one synthetic event of every listed type.
    static let tapTypes: [CGEventType] = [/* today's ten */ .scrollWheel]
    static var tapMask: CGEventMask { fatalError("not implemented") }
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }
}
extension ScrollEvent {
    /// isContinuous 0 → .wheel; scrollPhase ≠ 0 → .fingers; momentumPhase ≠ 0 → .momentum; else .unphased (F18).
    init(_ event: CGEvent) { fatalError("not implemented") }
}
extension ScrollVerdict {
    /// `.passStill` zeroes DeltaAxis1–3, FixedPtDeltaAxis1–3 and PointDeltaAxis1–3 in place and passes the event.
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? { fatalError("not implemented") }
}
// handle: tapDisabled → forgetHeldPresses() and forgetGesture(), re-enable; else parse TapEvent (nil → pass);
//   blocking = anyTrackpadBlocksClicks(); then the matching filter under its own lock, and that verdict's apply.

// WorkspaceActions
public func frontmostApp() -> URL? {
    // NSWorkspace.shared.frontmostApplication, unless its pid is ours; its bundleURL
    fatalError("not implemented")
}
```

#### LauncherUI

```swift
/// Renders `launcher.switcher` and holds nothing the model holds. Owned by MenuBarShell.
final class SwitcherPresenter {
    init(launcher: Launcher) {
        // panel = SwitcherPanel() — created now, so a swipe never pays the first window's cost (F32)
        // icons = AppIcons(side: 80)
        // Observations({ launcher.switcher }) → render(_:)
        // Observations({ launcher.switcherRows }) and NSApp effectiveAppearance KVO → icons.renderOffMainActor(present apps)
        fatalError("not implemented")
    }

    /// nil → hide: opacity to 0 over 150 ms, orderOut from the completion unless shown again (Reduce motion: at once).
    /// Newly non-nil → lay out the row's icon layers (80 pt, 20 pt apart), size from the icon count, centre on the
    /// pointer's display (NSMouseInRect rule, nearest otherwise), orderFrontRegardless.
    /// Always, with actions disabled → highlight x = position × 100 pt; selected icon 1.12× with its name below;
    /// stretch changed and ≠ 0 → additive CASpringAnimation on the highlight's position.x from stretch × 100 pt to 0,
    /// keyed so it replaces the last (none under Reduce motion).
    private func render(_ switcher: Switcher?) { fatalError("not implemented") }
}

/// The launch overlay's configuration (F26) around an NSGlassEffectView in a rounded clip (as LauncherPanel), holding
/// 80 pt icon layers 20 pt apart, a glass highlight view 92 pt square, and the name label. Never key, never
/// activating, click-through.
final class SwitcherPanel: NSPanel { override var canBecomeKey: Bool { false } }

// AppIcons(side: CGFloat = 16): today's cache, parameterised; the presenter holds an 80 pt one. Its lookup for the
//   switcher: cached → the running app's icon (the frontmost, F4) → drawn on the spot.
// SwitcherSection: illustration "swipe" mirrored in left hand, "Swipe to switch apps", the rows in a ScrollView with
//   layoutPriority(-1), AppMenuButton(.pullDown(title: "Add app…")) (R16, R21).
// SwitcherListRow: 16 pt icon + name, or greyed "<name>  not found" with the dashed-app symbol; .onHover → trailing
//   remove button; .contextMenu { Remove }; DragGesture → the row follows the pointer, on end
//   moveInSwitcher(id, to: start + round(dy / pitch)) (R17, R19, R20).
// AppMenuButton: the picker's NSPopUpButton in two forms over one coordinator. `.popUp(current: RowApp)` shows the
//   row's app and builds pickerMenu(checking:); `.pullDown(title:)` shows the title and builds the `menu` closure's
//   items. `.app(_, state:)`: .current selected, .listed checked and disabled. choose: (AppChoice?) -> Void, nil = None.
// LauncherActions.chooseOtherApp: (@escaping (URL) -> Void) -> Void — close, activate, NSOpenPanel, completion, reopen.
// LauncherView: rows (five), SwitcherSection, HandModeToggle, Divider, hint from Copy.gestureHint(for:), notices
//   (Copy.accessibilityHint), Quit; root fixedSize(horizontal: true, vertical: false) (R22, F36).
// LauncherPanel.fitToContent: height = min(fittingSize.height, visible.height − 16); y from the top edge (R22).
// MenuBarShell: owns SwitcherPresenter; refit also on switcherRows.count; iconTargets include the list's present apps.
```

#### Tests: fixtures and the gate

```swift
extension TouchScript {
    /// Lands `n` fingers 8 mm apart from `p`; they stay down until `lift`.
    func land(fingers n: Int = 2, atMM p: (x: Double, y: Double) = (62, 45)) -> TouchScript { fatalError("not implemented") }
    /// Moves every non-thumb finger that is down by `d` over `over` (100 ms by default).
    func slide(byMM d: (x: Double, y: Double), over: Duration = .milliseconds(100)) -> TouchScript { fatalError("not implemented") }
    /// Lifts the down fingers: all of them, or only the first landed. Ends a press in progress.
    func lift(_ which: Lift = .all) -> TouchScript { fatalError("not implemented") }   // enum Lift { case all, first }
    /// A press held from now until the next lift.
    func press() -> TouchScript { fatalError("not implemented") }
    // thumb(atMM:) after liftThumb() lands the thumb again (a new contact, same id, .landing); liftThumb lifts the
    // thumb that is down now. `wait` with fingers down is a hold.
}

extension World {
    /// What the next swipe reads as frontmost; nil models "none" or Trackpad Launcher itself.
    func makeFrontmost(_ name: String?) { fatalError("not implemented") }
    /// Delivers the frames of `script` newer than any delivered on that trackpad, so scroll events can interleave.
    func play(_ script: TouchScript, on trackpad: Trackpad = .macBook14) { fatalError("not implemented") }
    /// A World with Safari, Mail, Slack and Notes installed, Mail, Slack and Notes listed in that order, Safari frontmost, started.
    static func switcherWorld(accessGranted: Bool = false) -> World { fatalError("not implemented") }
    /// Thumb at (10, 10), two fingers down, each slide in turn (mm, positive right), then the fingers lift unless `lift` is
    /// false. Returns its script so a row can continue it with `play`.
    @discardableResult
    func swipe(_ slidesMM: Double..., lift: Bool = true, on trackpad: Trackpad = .macBook14) -> TouchScript { fatalError("not implemented") }
}

// InMemoryTrackpads: run(_:handMode:blockClicks:swipes:) builds recognizers with `swipes`, arms ClickFilter and
//   ScrollFilter together; touch delivers the frame's event through TrackpadEvent(_:on:) inline; playFeedback records
//   `pulses: [Pulse { haptic, trackpad }]`, with `feedback` (gesture pulses, so today's assertions keep reading) and
//   `lightTicks` derived; `scroll(_ event: ScrollEvent) -> ScrollVerdict?` decides on the merged flags the last frames
//   left (nil when no tap is armed) and records `scrollVerdicts`; inject(_ event: TrackpadEvent) delivers regardless of
//   `running` (the real adapter's generation gate has no in-process seam).
// RecordingSystemActions: `var frontmost: URL?`; frontmostApp() returns it.
// Fixtures.recordSavedByPlan002(handMode: HandMode = .right, two: AppEntry? = nil) -> Data: a binary plist of today's
//   `Settings` shape (handMode + assignments 1...4), written through a test-local struct, as today's build saves it.

// SourcePolicyTests
//   banned:   − Entry(token: "scrollWheel", rule: "R6 never scrolling")
//             ~ Entry(token: "ScrollWheel", rule: "006 R12 scroll events only by their Swift names, in the tap")
//   confined: + Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", rule: "006 R12 scroll suppression in the one tap")
//   The kept-token pin and the overlap check are unchanged; they pass as is.
// PointerEventTests → TapEventTests: mask bits [1,2,3,4,6,7,22,25,26,27,34]; everyMaskedTypeParses over TapEvent;
//   `.scrollWheel` leaves ignoresEverythingElse; synthetic scroll events (CGEvent(scrollWheelEvent2Source:…) plus
//   setIntegerValueField for phase, momentum, isContinuous: F18) parse to .wheel / .fingers / .momentum / .unphased;
//   passStill reads back nine zero deltas and the same type and phases.
```

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Gesture.five`; `init?(fingerCount:)` nil above 5 | Recognizer: five → `.five`, rolling five → `.five`, six → nothing (amends `fiveFingerTapFiresNothing`, `fiveFingersInARollingTapFireNothing`). World: Slack, not Spotify; haptic and animation |
| R2 | `Gesture.allCases` rows; `gesture-5.svg` | World: five rows, all `.unassigned` (amends `PersistenceTests` counts); fifth assignment fronts on a five-finger tap. Illustration and mirroring: manual |
| R3 | `.tapping` drag check → `.swiping`; `.resting`; `Pair`; `Move.isSideways`; `swipes` | Recognizer: 5 mm sideways → `.began`; 2 s rest then sideways → `.began`; 10 mm down then 20 mm right → no phase; one or three fingers → none; fingers before thumb → none; two-finger tap under 3 mm → `.two`; drifting three-finger tap → `.began` then `.cancelled`; drifting two-finger tap → `.began` then `.ended`. World: no haptic, nothing fronted |
| R4 | `Switcher.init?` row rule; `catalog.locate` at begin | Switcher (pure): frontmost in or out of the list. World: Figma trashed → left out |
| R5 | `Switcher.home` | Switcher (pure); World: `selectedApp` at begin |
| R6 | `selected`, `position`, `stretch`; travel is +x on `SurfacePoint` | Switcher (pure): 5, 6, 7, 24, 24 then −12, +30 at the end, stretch bound. Recognizer: travel values on `.macBook14` and `.magicTrackpad`, left hand → same sign. Spring and look: manual |
| R7 | ticks per `|Δselected|`; `Haptic.lightTick` | World: 36 mm → 3 `lightTicks`; 5 mm → 0. Feel against the gesture haptic: manual |
| R8 | `.ended` at the first pair lift; `Launcher.swipe(.ended)` | Recognizer: one finger lifts → `.ended`, later frames silent until all lift. World: Slack fronted, `feedback` once, no animation, window closed; frontmost selected → nothing, window stays; thumb lifted → still fronted |
| R9 | Exits `.click`, foreign landing; `.blocked` ignored; optional thumb | Recognizer: thumb slides out, re-lands → `.ended`; third finger → `.cancelled`; `.click` → `.cancelled`; `.blocked` → continues. World: no access + press → nothing fronted; access + press → `[.drop, .drop]`, fronted |
| R10 | `SwitcherPresenter`, `SwitcherPanel` (F26 configuration), `AppIcons(side: 80)` | World: `switcher` non-nil while up, nil at end or cancel. Glass, sizes, display, full screen, focus, dark mode, Reduce motion, ≤ 200 ms, no perceptible delay: manual |
| R11 | `Switcher.init?` nil; `run(swipes:)`; `reconcile()` on a null row; `activity` guard; frontmost nil → none | World: empty list → no `.began` and no blocking after 4 s; only frontmost, only missing, or no frontmost → `switcher == nil` and a press after the begin passes (the recognizers were replaced); Tap to click on → nothing |
| R12 | `ScrollFilter` on the R4 flag; `.wheel`; no tap without access | ScrollFilter table. World `scroll`: within 3 s → `.drop`; after 4 s → `.pass`; thumb lifted → `.pass`; wheel → `.pass`; no access → nil and the switcher works. Real pages and a real wheel: manual |
| R13 | `blocksClicks` true in `.swiping` | Recognizer: true from `.began` to `.ended`, thumb or no thumb, after 4 s. World: late swipe press → `[.drop, .drop]`; late swipe scroll → `.pass` then `.passStill` |
| R14 | Treatment inherited by momentum, never escalated | ScrollFilter table; World: flick in the window → momentum `.drop`; coasting then thumb lands → `.pass` |
| R15 | `Copy.accessibilityHint` | Core: the exact string. Rendered: manual |
| R16 | `SwitcherSection`, `swipe.svg`, order in `LauncherView` | Manual (layout, mirroring, light and dark) |
| R17 | `switcherRows` resolved with `rows`; `present == nil` = missing | World: order matches the switcher row; trash → `present == nil`; restore and `openWindow` → present |
| R18 | `addToSwitcher`; `SwitcherList.append`; `addMenu(listing:)`; `.listed` | Pure menu projection: `✓ Mail (listed)`, no `None`. World: append Notes; Other… from Downloads; Other… a listed app → unchanged; an app on a tap and in the list → added |
| R19 | `removeFromSwitcher` | World: list after removal. Hover and context menu: manual |
| R20 | `moveInSwitcher`; `SwitcherList.move` | World: Notes to 0 → Notes, Mail, Slack; the next switcher uses it. Dragging in the panel: manual |
| R21 | `ForEach` over an empty `switcherRows` | World: fresh install → `switcherRows.isEmpty`. Look: manual |
| R22 | List `ScrollView` + `fitToContent` height cap; refit on count | Manual (30 apps on a 13" display); F36 probed the mechanism |
| R23 | `Settings.switcherList`, tolerant `init(from:)`, `SwitcherList` coding | World: relaunch keeps five-finger Slack and Notes, Mail; `Fixtures.recordSavedByPlan002` loads with its assignments and an empty list |
| R24 | `Copy.gestureHint(for:)` | Core: the exact string per hand mode. Rendered: manual |

**Test handles.**

| Thing | Handle |
|---|---|
| The clock behind 400 ms, 3 s and "no time limit" | `TouchFrame.time`; `TouchScript.wait` |
| The swipe event stream | `Recognition.event` per frame (`steps.compactMap(\.swipe)`); `InMemoryTrackpads.touch` delivers it inline |
| A swipe by script | `TouchScript.land`, `slide`, `lift(.first)`, `press`, `liftThumb`, and `thumb` again; `World.play` for increments; `HandFrames` for anything else |
| The frontmost app | `RecordingSystemActions.frontmost`, `World.makeFrontmost(_:)`, nil for none or self |
| The switcher's visible state | `launcher.switcher` (row, home, selected, position, stretch) |
| The haptic kind and order | `InMemoryTrackpads.pulses`; `feedback` and `lightTicks` derived |
| Scroll events | `InMemoryTrackpads.scroll(_:)` on the frames' flags; `ScrollFilter` directly; synthetic `CGEvent`s in LauncherPlatformTests |
| What suppression does to an event | `ScrollVerdict.apply(to:)`: `.drop` → nil; `.passStill` → all nine delta fields read 0 and the phases are unchanged |
| A reconcile mid-swipe | `preferences.set` between two `play` calls → `switcher == nil`, the remaining fingers do nothing until they lift |
| The old settings record | `Fixtures.recordSavedByPlan002` as a binary plist into the suite |
| Presses during a swipe | `TouchScript.press()` → `pressVerdicts` |

**Existing tests this plan amends** (only the ones `how.md` names): `fiveFingerTapFiresNothing` and `fiveFingersInARollingTapFireNothing` now expect `.five`, with a six-finger row replacing the "nothing" case; `thumbThenNFingerTapFiresThatGestureOnce` and `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps` run over 1...5; the `PersistenceTests` row counts go to 5 and `assignmentsAndHandModeSurviveARelaunch` assigns and expects five names (it compares `rows.map(\.app)` against the names it zipped with `Gesture.allCases`); `PointerEventTests` covers mask bit 22, no longer lists `.scrollWheel` under `ignoresEverythingElse`, and `everyMaskedTypeParses` parses `TapEvent`; the `RecentAppsTests.menu` projection reads `.app(_, state:)`; `.unassigned` call sites in `setAssignment` become `nil`. A two-finger sideways drag is now a swipe, but it fires no tap, so `draggingFingersIsNotATapAndTheNextTapStillFires` still reads `[.two]`. `twoFingersHeldFiveHundredMillisecondsFireNothing`, `liftingTheThumbEndsBlockingAtOnce` and `aThumbSlidingOutOfTheCornerStopsBlocking` pass unchanged.

**Docs.**

- `docs/domain-model.md`: *Gesture* (five tap gestures); *Tap* (a two-finger tap that slides sideways past 3 mm becomes a swipe); *Launcher window* (five rows, the switcher section, the toggle, the hint, Quit); *Feedback* (the *gesture haptic* and the *light tick*; the silent lift on the frontmost app); *Click blocking* (trackpad and Magic Mouse scrolling suppressed under the same rule and for the whole of a swipe; the momentum of a suppressed scroll too; pointer movement and wheel mice never; a mouse click during a swipe is blocked for the swipe's length); *Blocking window* (held open for the whole of a swipe); *Accessibility hint* (names scrolling); new entries *5-finger gesture*, *Swipe*, *Switcher*, *Switcher list*, *Frontmost app*, *Light tick*.
- `docs/architecture.md`, three cross-cutting sentences: Concurrency, "only completed gestures hop to the main actor" becomes "only recognised events hop: a fired tap, and a swipe's begin, moves and end, in frame order on the main queue, never from a replaced session"; the main-actor icon-drawing exceptions gain the switcher's frontmost icon (drawn at swipe begin from the running app's loaded representations) and its draw-on-cache-miss fallback; Privacy, Accessibility is used "only to block trackpad clicks and suppress trackpad scrolling during gestures", with the scroll-event API confined to the tap's file like the tap itself. The tap's thread now wakes for scroll events while armed.
- `docs/product-overview.md`, the three changes the Solution names: five tap gestures plus the swipe; the haptic rule's one exception (a swipe released on the frontmost app is silent); the sound effect stays deferred.
- Plan text, done in this plan's Solution: the amendments paragraph names plan 002 R9 (scroll events are now read, and those of a suppressed scroll changed) and plan 001 R11's "drag or scroll" bullet (scoped to taps). The glossary, the architecture sentences and the product overview edits are in the working tree with this design and are committed with the slice that makes them true.

**Deliberately not done.** No timer, deadline or display link. No main-to-frame channel: the recognizer is never told the row. No device attribution of scrolls beyond `isContinuous`. No posting, and no synthesising of momentum or `ended` events: zeroing happens in place. No switcher row wider than the screen. No grace period at the lift. No launch animation on a swipe. No `NSRunningApplication` crosses a port. No pasteboard drag for reordering. No cap on the list. No change to `ClickFilter`, `PointerEvent` or `PointerVerdict`.

### Synthesis decision

**Base: candidate 1** (the Opus runner). Both candidates converged on the backbone: the swipe as two more states of the one recognizer with an optional thumb only in `.swiping`, begun exactly where the drag rule spoiled, with `blocksClicks` true throughout and the exits named; travel in millimetres across the port and the selection decided on main; the main-queue hop; the switcher as model state; a tolerant `Settings` decoder; the `scrollWheel` token confined to `ClickTap.swift`. That convergence is shipped as is. They diverged on the invariant-bearing edges, and candidate 1 was right on each: the `swipes` gate (without it every upgrading user with an empty list loses sideways scrolling for the whole of an anchored slide, against R11 and R12); the run-generation gate (a stale `began` after `reconcile()` would otherwise leave a switcher nobody can close); the per-gesture, never-relaxing scroll treatment (candidate 2's per-event rule leaks a `changed` that races the lift frame, against R13's "after"); a `Pair` constructed as exactly two with "none joining on this frame" and a deterministic farthest-finger mover (candidate 2 iterated a dictionary and missed a third finger landing on the begin frame); the `Switcher` whose only constructor encodes R4, R5 and R11, with ticks per icon crossed; the frontmost app parsed through the one existing catalog rule; AppKit and Core Animation rendering per the architecture's animation rule; an R22 mechanism with no feedback loop (F36 probed it after fan-out: `fittingSize` reports the full height and a capped frame is absorbed by the `ScrollView` alone, so candidate 2's `WindowLimits` observable written from `refit()` is unnecessary and its `List` cannot size the window); a reorder that does not depend on O9.

**Cross-judge:** recommended candidate 1 as the base, 16 to 9 on the rubric (C1 3/2, C2 2/1, C3 3/1, C4 3/2, C5 2/1, C6 3/2); my own scoring was 15 to 12 with the same ordering on every criterion. It found no misdescription of the existing code in either candidate and no red flag in candidate 1 beyond the acknowledged panel-configuration copy. Agreement confirms the pick.

**Grafted from candidate 2:** `Copy.gestureHint(for:)` and `Copy.accessibilityHint` as core values (candidate 1 left both strings in the view, the one rubric defect the judge and I both found); `TrackpadEvent.init(_:on:)` as the single mapping both adapters use; `InMemoryTrackpads.pulses` as one ordered record with `feedback` and `lightTicks` derived; `PickerItem.app(_, state: AppItemState)` instead of a sibling `.listed` case, so checked and disabled are one dimension of one item; `AppMenuButton` in two forms over one coordinator instead of a shared populate function plus a second button; `Recognition.Event` as a nested type with the existing `.fired` vocabulary; the plan-002 record fixture by name; its open questions and handles that candidate 1 lacked (glass in a `.screenSaver`, non-key, click-through panel and glass on glass; Magic Mouse unobserved; a reconcile mid-swipe).

**Changed in the base during synthesis:** the rubber band's high-water mark and `switcherPushStepMM` are dropped: `stretch` is a pure saturating function of the raw excess, and the presenter re-adds a keyed additive spring on each change, which gives the same feel (tracks while pushing, settles when the push stops) with no stored state; the claim that `inject` after a reconcile is ignored is dropped (the gate lives only in the real adapter, as the judge noted); `AppCatalog.locate` consults registered copies lazily (the judge measured a LaunchServices query per listed app at swipe begin); `ClickFilter`'s doc comment no longer claims to be everything the tap is told; the docs section gains the architecture's icon-drawing exceptions, the product overview, the glossary's mouse-click sentence and the plan-text gaps.

**Rejected from candidate 2, with reasons:** scroll suppression folded into `ClickFilter` with a per-event rule (the lift race; and `passAsMove` would be meaningless for scrolls, `passAsStill` for presses); `frontmostApp() -> AppEntry?` built in the adapter from `localizedName` (a second `AppEntry` parse rule beside `catalog.entry(at:)`); `SwitcherIcons` (a second copy of `AppIcons`' cache policy; a `side` parameter suffices); `SwitcherRow.make` returning a tuple plus `SwitcherGeometry` statics forwarded by `Switcher` (two public surfaces for one rule); a nil frontmost shown with the selection on the leftmost icon (its own pseudocode then made the lift there silent, and a one-app list with no frontmost would show a switcher that can open nothing); `List` with `onMove` and the `WindowLimits` cap (O9 unprobed; F36); renaming `blocksClicks` to `blocking` (churn across tests; the glossary still defines scroll suppression in terms of click blocking); `PickerTarget` (a completion closure needs no enum); `IndexSet` intents (only `List` needed them); SwiftUI content for the switcher (its springs and scale animations are not Core Animation keyframes, the architecture's rule). **Rejected from the judge's suggestions:** gating swipes on "at least one present app" rather than a non-empty list: the gate would then flip in `resolveRows`, which runs on every window open, and a reconcile there would reset recognizers mid-gesture. **Changed after the test planner's report:** its finding that R11's "MUST do nothing" contradicted the accepted over-blocking for a list of only missing apps or only the frontmost app is closed in the design, since a `began` that yields no switcher now ends the swipe through `reconcile()` (decision 3) and nothing stays blocked; its finding that the run-generation gate has no seam is answered with the manual hot-plug check rather than a ticket type whose only logic is an integer comparison (the in-memory adapter already drops a replaced session's frames at `touch`); its R12 "at once" finding stays the first open question, for the requirement owner.

### Tradeoffs accepted

- We accept that a scroll gesture suppressed at any point stays suppressed until its fingers lift and its momentum ends, even if the 3 s window closes mid-gesture. In exchange, no app ever sees a broken began-to-ended bracket, nothing leaks when a `changed` races the lift frame, and momentum follows its gesture with no clock. We read R12's "work again at once" as "the next scroll works at once", the scroll analogue of plan 002 R5's whole press.
- We accept two suppression mechanics, dropping (gesture never seen) and zeroed pass-through (gesture already seen), in exchange for apps seeing either nothing of a suppressed gesture (no overlay-scroller flash) or a complete, motionless one (no stuck elastic state). The probe verified zeroing only on a locally built event.
- We accept that a thumb landing in the corner while two fingers are already scrolling stills the rest of that scroll, because R12 says "exactly the conditions that block clicks" and a thumb landing with fingers down opens a window.
- We accept one main-queue hop per changed frame while a swipe moves (~100 Hz), plus a layer update per main turn, in exchange for the selection, ticks and effects staying pure and in the model. The work is input-driven and stops when the fingers stop.
- We accept swipes switched off while the switcher list is empty (one more `run` argument, and a reconcile when emptiness flips), in exchange for users who never fill the list keeping today's scrolling past the 3 s window.
- We accept that a swipe with nothing to show (a list of only missing apps or only the frontmost app, or no frontmost app) ends through `reconcile()`, which restarts the devices and the tap, in exchange for R11's "do nothing" holding with no main-to-frame channel. A scroll in progress at that moment stops for the time main takes to handle the `began` and resumes through the replaced tap's fresh filter; inside the 3 s window it resumes without the `began` apps never saw, the headless gesture the disabled-tap recovery already accepts. For the rest of that hand the resting thumb has no window, so a press within 3 s of its real landing passes: R11 wins over plan 002 R4 there.
- We accept that mouse clicks during a swipe are blocked for the swipe's length, not 3 s, by the same indistinguishability plan 002 accepted.
- We accept one scroll memory for every pointing device: interleaved streams from a Magic Mouse and a trackpad share one filter, since the system reports them alike (non-goal).
- We accept that the switcher panel repeats the launch overlay's ten-line panel configuration in `LauncherUI`, because `LauncherUI` does not depend on `LauncherPlatform`. The recipe is cited, not shared.
- We accept that rendering the switcher in AppKit and Core Animation is more imperative than SwiftUI, in exchange for springs and fades played by the render server with no code of ours per display frame, as in the launch overlay.
- We accept `catalog.locate` for every listed app on the main actor at swipe begin (one Info.plist read each after the lazy-lookup change), in exchange for a row that is correct at the moment it is shown rather than at the last window open.
- We accept that the frontmost app's icon may be drawn at begin (0.1 ms observed through `NSRunningApplication.icon`, 25 ms once for another running app, F4) rather than prepared, since it cannot be known earlier.
- We accept that `AppChoice` loses `.unassigned` (five call sites change) in exchange for intents that are total over their input.
- We accept a light tick per icon crossed even when one frame crosses two (they merge on the actuator), in exchange for counts that match R7.
- We accept that the tap wakes for every scroll event in the session while armed (F19), in exchange for one tap and no second permission.

### Alternatives considered

- **A separate `SwipeRecognizer` beside `GestureRecognizer` on the frame thread.** Exposes nothing new to callers, but each recognizer would need the other's facts (which fingers belong to the tap, whether 400 ms ends a pair, which owns the flag): two writers of `blocking` or a merge, and a protocol between two state machines. Rejected: two owners of one finger session, the reason plan 002 rejected a second owner of the blocking decision.
- **The recognizer told the row length and emitting the selection (O2).** Exposes a main-to-frame channel mid-gesture, because the row depends on the frontmost app and the catalog; the 12 mm rule could only be tested through frames. Hides hops on moves that do not change the selection, which the highlight needs anyway (R6). Rejected.
- **The switcher as an effect behind `SystemActions` (`show`, `update`, `hide`) played by `LauncherPlatform` (O5).** Three methods mirroring model state, callers coordinating several calls per swipe, state split between the model and the adapter, tests reading a recording fake instead of the model. Hides nothing the model-state shape does not. Rejected as shallow; the overlay precedent is for stateless effects.
- **SwiftUI for the switcher's content.** Declarative, with `glassEffect` and environment Reduce motion, and less code. But its springs and scale animations are not Core Animation keyframes, the architecture's animation rule, and the overlay precedent is Core Animation. Kept for the window, not used for the switcher.
- **Delivery by `Task { @MainActor }` (observed order), or a coalescing mailbox, or self-describing events (O3).** The first rests on undocumented ordering (F6); the second needs a field written by two threads; the third cannot make an `ended` that overtakes its `began` harmless without a remembered set of swipe IDs. The documented FIFO queue plus a generation gate is the simplest correct choice.
- **Suppress by dropping only (O4).** Simplest, but when suppression starts mid-gesture (a late swipe, or a thumb landing mid-scroll) apps keep an open scroll gesture with no `ended`. **Suppress by zeroing only.** Brackets always close, but a gesture blocked from its first event shows apps an empty gesture (overlay scrollers flash), and per-event decisions relax at the lift and leak. The per-gesture treatment combines the two failure-free halves.
- **Scroll suppression inside `ClickFilter` as more `PointerEvent` cases.** One lock and one `decide`, but two unrelated policies in one filter: `passAsMove` means nothing for a scroll, `passAsStill` nothing for a press, and every scroll change touches the click filter. A sibling filter with its own vocabulary keeps the click filter untouched.
- **Recognise swipes regardless of the list.** Simpler `run`, but it suppresses scrolling for every user who never uses the switcher (R11 "do nothing"). **Gate on "at least one present app".** More precise, but the value changes in `resolveRows`, which runs on every window open; reconciling there resets recognizers mid-gesture.
- **`frontmostApp()` returning an `AppEntry` built in the adapter.** Parses at the boundary, but with a second name rule (`localizedName`) beside `catalog.entry(at:)`; two entries for one app could differ. The URL plus the one catalog parse keeps one rule.
- **`List` with `.onMove`, or `.draggable` and `.dropDestination`, for reordering (O9).** Both depend on unprobed drag behaviour in a non-activating key panel; `List` brings its own chrome into the glass card and does not size to its content under `fittingSize` (F36). A `DragGesture` over fixed-pitch rows needs neither.
- **A SwiftUI `ViewThatFits` or an observable height cap for R22 (O7).** `ViewThatFits` picks by fitting the proposal, which `fittingSize` makes unbounded; an observable cap written in `refit` races SwiftUI's asynchronous update and reads a stale `fittingSize`. Capping the panel frame and letting one flexible child absorb the deficit uses SwiftUI's layout as designed (F36).

### Open questions and risks

- Is "a scroll suppressed at any point stays suppressed until its fingers lift" acceptable for R12's "scrolling MUST work again at once"? The alternative, resuming mid-gesture, shows apps `changed` events without a `began` for a dropped gesture, and leaks deltas at the lift of a late swipe. How far the drop-at-open rule reaches past the 3 s window also depends on whether `mayBegin` arrives when fingers land or ~17 ms before `began` (F18 sequences 3 and 4 do not settle it).
- R12 read literally stills an in-progress two-finger scroll when a thumb lands in the corner. Should a thumb that lands while two fingers are already scrolling open no scroll suppression (as R14 already protects momentum)?
- Is gating swipes on a non-empty switcher list, and ending a swipe that shows nothing through `reconcile()`, the intended reading of R11? The residuals: a horizontal scroll in progress when such a swipe begins stops for the time main takes to reconcile and resumes, headless (no `began`) when it was inside the 3 s window; and for the rest of that hand clicks pass even inside the thumb's original 3 s, since the replaced recognizer gives a resting thumb no window.
- When the frontmost app cannot be read (or is Trackpad Launcher itself, only while Other… is open), the swipe shows nothing. Is that right, or should the switcher open with the selection on the first icon?
- R6 measures travel from where the swipe began, so with fingers moving together the first selection change comes about 9 mm after the fingers landed (3 mm to begin, then 6 mm). Should travel instead count from the landing midpoint?
- Does actuation 3 feel right as the light tick next to 6? The meaning of `actuatorActuate`'s other arguments is unknown (`how.md`).
- Does `NSGlassEffectView` render inside a `.screenSaver`-level, non-key, click-through panel, and does a glass highlight read well over a glass panel in light and dark? Manual R10 check; the fallback is a translucent material capsule.
- Does the saturating rubber band with a re-added spring per change feel right, and does the 1.12× selected icon read as "slightly larger" at 80 pt? Feel checks on hardware.
- What should happen when two fingers lift in the same frame that a third lands? This design ends the swipe (opening the selection); a delivered click wins over both (cancel).
- A swipe on a second trackpad while the first one's switcher is up is ignored on screen but still blocks on its own pad. Acceptable?
- A reconcile mid-swipe (hot-plug, wake, preference or trust change) cancels the switcher silently and the remaining fingers do nothing until they lift. Fine?
- Downgrade: an older build reading a record with a `5` key or a `switcherList` key fails to decode and loads defaults. Worth a release note?
- *Risk:* zeroed deltas were verified only as a field round trip on a local event (F18). An app that computes scrolling from data outside the nine delta fields would still move; the fallback is mapping `stilled` to `.drop`, a one-line change.
- *Risk:* the `mayBegin`-before-the-flag race. If the system's scroll recognizer emits `mayBegin` before our frame sets the flag, a gesture we would have dropped is stilled instead: overlay scrollers flash, and nothing moves.
- *Risk:* a swipe's block has no cap. Its exits are a lift, a foreign landing, a delivered click, or a `run`. A swipe could stick only if the pad never sent the empty frame after the last lift, the same assumption tap firing already relies on (plan 002's open question); with a swipe-wide block that failure would now be visible as a switcher that stays. Worth checking on hardware before the first slice ships.
- *Risk:* F4's fast frontmost icon rests on two observations; a cold `NSRunningApplication.icon` for a rarely used app may cost ~25 ms on the first swipe from it. The time from `began` to the panel on screen with N icon layers laid out is unprobed; the panel is warmed, the layout is not.
- *Risk:* Magic Mouse scrolling was never observed (F18); it is assumed `isContinuous == 1` and suppressed like a trackpad's, as the plan accepts. The wheel-mouse exemption rests on a synthetic event.
- *Risk:* a touch during momentum. If the system keeps emitting a dropped gesture's momentum events after a new gesture's `mayBegin` (F18 did not observe this interleaving), `ScrollFilter` would treat them as the new gesture's and they could move the page. A probe row (touch during a coast) belongs in the S4 hardware checks before the filter's rule is trusted on that case.
- *Risk:* F35's unmerged `feature/005` branch adds a switch to the launcher window, and its merge will meet this layout.
- *Risk:* `scrollWheel` must not appear in any shipped file but `ClickTap.swift`, comments included; the implementation must spell the field names only there and say "scroll" elsewhere.

### Next implementation step

Add the `TouchScript` swipe primitives (`land`, `slide`, `lift(.first)`, `press`, thumb re-landing). Then grow `GestureRecognizer` test-first with `Gesture.five`, `.resting`, `.swiping` and `Recognition.event`, against R1, R3, R8, R9 and R13 at the recognizer seam.

## Testing Decisions

### Strategy

Six seams, highest first. Five exist today and only widen; the one new seam, `ScrollFilter`, is a pure value the design names beside `ClickFilter`. `Switcher`, `SwitcherList`, `InstalledApps.addMenu` and `Copy` are pure values read through `World` or on their own. Everything we own runs for real: the recognizer, both filters, `Launcher`, `Settings` through `SettingsStore` over a throwaway suite, `AppCatalog` over the World's temp tree, `CGEvent` parsing and rewriting.

1. **`Launcher` through `World` (LauncherCoreTests), the high seam.** `World` is unchanged in shape; its adapters grow as the design's "Tests: fixtures and the gate" says. `InMemoryTrackpads.run(_:handMode:blockClicks:swipes:)` builds each recognizer with `swipes` and, when asked with trackpads, arms a real `ClickFilter` and a real `ScrollFilter` together; `touch` steps the real recognizer per frame and delivers every `Recognition.Event` inline through `TrackpadEvent(_:on:)`, taps and swipe phases alike; `playFeedback(_:on:)` appends to `pulses`, from which `feedback` (gesture pulses, so today's assertions keep reading) and `lightTicks` derive; `scroll(_:)` decides one `ScrollEvent` on the merged flags the last frames left, records it in `scrollVerdicts` and returns nil when no tap is armed; `inject(_:)` takes any `TrackpadEvent`. `RecordingSystemActions.frontmost` answers `frontmostApp()`. `World.play(_:on:)` delivers only the frames newer than any delivered on that trackpad, so scroll events, intents and reconciles interleave with one hand in progress; `World.swipe` returns its script (`@discardableResult`) so a row can continue it with `play`; `switcherWorld` is the shared fixture. It observes `launcher.switcher` (`row`, `home`, `selected`, `selectedApp`, `selectsFrontmost`, `position`, `stretch`), `switcherRows`, `rows`, `isWindowOpen`, `activity`, `system.broughtToFront`, `system.launchAnimations`, `hardware.pulses`, `pressVerdicts`, `scrollVerdicts`, `running`, `scanner.scanRequests` and the suite. It misses the panel and the presenter, the window and its menus, real scrolling, the real tap and its thread, the real frontmost read, the run-generation gate and haptic feel: all under Verified without a test. Rows resemble `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift`, `ClickBlockingTests.swift`, `AppResolutionTests.swift`, `RecentAppsTests.swift` and `PersistenceTests.swift`.
2. **`GestureRecognizer.step` → `Recognition`** (`GestureRecognizerTests.swift`, `ClickBlockingRecognizerTests.swift`) over `TouchScript`, which gains `land`, `slide`, `lift(.first)`, `press` and thumb re-landing, and `HandFrames` for the interleavings a builder cannot sequence. Helpers over a fresh recognizer: `fired(_:)` and `blocking(_:)` as today, plus `phases(_:)` (`compactMap(\.swipe)`) and per-frame maps of `swipe` and `blocksClicks` where the frame matters. `TouchFrame.time` is the only clock. It misses arming, the merge across trackpads and which trackpad (seam 1 and manual).
3. **Pure values**: `Switcher` (row, home, selection, position, stretch), `SwitcherList` (append, remove, move, coding), `Settings` coding, `InstalledApps.addMenu(listing:)` and `pickerMenu(checking:)` through a string projection like `RecentAppsTests.menu`, `Copy`, and `AppCatalog.locate` with a counting `registeredCopies` closure.
4. **`ScrollFilter.decide` / `forgetGesture`**, fed events in order with `trackpadBlocking` chosen per event, exactly as `ClickFilterTests` feeds `ClickFilter`. It misses `CGEvent` (seam 5).
5. **LauncherPlatformTests, real adapters that need no hardware and no permission:** `TapEvent.tapMask`, `TapEvent.init(_:_:)` and `ScrollEvent.init(_:)` over synthetic `CGEvent`s (`PointerEventTests.swift` becomes `TapEventTests.swift`, same fixture style), `ScrollVerdict.apply(to:)`, and `MultitouchTrackpads.actuation(for:)`. It misses creating the tap, the tap thread and the generation gate.
6. **`SourcePolicyTests`**: the moved `scrollWheel` token and the unchanged self-checks.

Faked at the seam: frames (scripts), the frontmost app (`RecordingSystemActions.frontmost`; the real one is `NSWorkspace`), the event tap (the fake's few lines of edge glue around the real `ClickFilter` and `ScrollFilter`), haptics (recorded by kind), the main-actor hop (inline). Real: everything else. The clock needs no fake: no clock object exists and no row waits. Randomness: none in the design.

Techniques, applied. *Own the clock:* every bound is a frame timestamp; T7 straddles 400 ms with the move on the 410 ms frame, T18 and T25 contrast a fresh and a 4 s-old thumb, T7 rests 2 s to prove "no time limit", T66 proves momentum follows its gesture with no clock. *Withhold and inject:* the fake tap withholds a scripted press and rows read both what the recognizer saw (`.blocked`) and what apps would have got (`pressVerdicts`) (T24, T53, T54); `inject` delivers a `began` the frame thread recognised before activity flipped (T57) and a second trackpad's phases (T61). *Hold the blocking call:* not applicable; the design bounds no call. *Force the interleaving:* a third finger on the begin frame (T9), the thumb re-landing on the exit frame (T22), the pair lifting on the frame a third lands and a click on the frame the pair lifts (T23), a `changed` and a momentum event arriving after the lift frame cleared the flag (T71, T73), a reconcile mid-swipe (T62) and one from inside the begin event's own handling with the hand still down (T40, T56), list edits under a resting hand (T58), another trackpad's events while a switcher is up (T61). *Kill at random:* no new "however it ends" guarantee; every intent saves before it resolves, as today, and the first-launch sequence is unchanged (plan 002 T38, T42). *Boundary values:* 2.9/3.1 mm; (3.0, 2.9) against (2.9, 3.0) mm; the move at 410 ms; 5.9/6.0/6.1 and 17.9/18.0 mm; 0.2 icons; 4 s; five against six fingers; 36 and 30 mm at an end. *Whole history:* `phases` and `blocksClicks` per frame, `pulses` and `pressVerdicts` in order, `switcher` read before, during and after, `broughtToFront` as a list.

**Readings of the requirements**, written here for the owner to confirm at plan review: R6 "6 mm after the swipe began": at exactly 6.0 mm the selection has changed (half away from zero), at 5.9 it has not. R12 "scrolling MUST work again at once": the *next* scroll gesture passes at once; a gesture suppressed at any point stays suppressed to its momentum's end (the design's first open question; T65 pins this reading). R3 "Rolling three-finger tap with drift" and "Two-finger tap that drifts": their GIVENs name a non-empty switcher list, which design decision 3 needs (no swipe is recognised with an empty one); T35 and T36 list Mail, Slack, Notes. R11 "MUST do nothing" for a list of only missing apps or only the frontmost app, or no readable frontmost app: the block the begin frame raised lasts until main handles the `began` and the reconcile rebuilds the recognizers, after which the resting thumb has no window, so a press within 3 s of its real landing passes; T40 and T56 read "do nothing" as that press passing and the next scroll passing (in the synchronous fake the reconcile lands before the next frame, so no later frame is blocked). R8 "The launcher window, if open, closes": only when an app is brought to front; the silent lift on the frontmost app leaves it as it was (T51). R13 "no more than the first 3 mm": the scroll events between the fingers landing and the begin frame pass; everything from the begin frame on is stilled (T70).

**Existing tests amended** (the design's list): `fiveFingerTapFiresNothing` and `fiveFingersInARollingTapFireNothing` become T1 and T2 (`.five`, with six fingers as the "nothing" case); `thumbThenNFingerTapFiresThatGestureOnce` runs over 1...5; `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps` runs over 1...5 with five apps (T3); `PersistenceTests` `count: 4` becomes 5 and `assignmentsAndHandModeSurviveARelaunch` zips five names, since `Gesture.allCases` now has five (T5, T32); `RecentAppsTests.menu` reads `.app(_, state:)` (T27); `setAssignment(.unassigned, …)` becomes `setAssignment(nil, …)` in `LauncherTests.unassigningAnAppStopsPreparingIt` and `AppResolutionTests.unassigningClearsTheRowForeverAndSilencesTheGesture`; `PointerEventTests` becomes `TapEventTests` with bit 22 in the mask and `.scrollWheel` out of `ignoresEverythingElse` (T76). `draggingFingersIsNotATapAndTheNextTapStillFires`, `twoFingersHeldFiveHundredMillisecondsFireNothing`, `liftingTheThumbEndsBlockingAtOnce`, `aThumbSlidingOutOfTheCornerStopsBlocking` and `aReconcileUnderARestingThumbDoesNotRestartTheWindow` pass unchanged and stay as the no-swipe baseline.

### Test scenarios

Conventions. Right hand and `SurfaceSize.macBook14` unless stated; the thumb lands at (10, 10) mm; `land(fingers: n)` puts fingers at (62, 45), (70, 45), … 8 mm apart; `slide(byMM: (x, y))` moves every down finger over 100 ms (10 frames, 10 ms apart) unless `over:` says otherwise; `wait` with fingers down is a hold; `lift()` lifts every down finger, `lift(.first)` only the first landed. "Thumb" alone is `TouchScript(.macBook14).thumb(atMM: (10, 10))`. The **begin script** is `thumb.land(fingers: 2).slide(byMM: (3.5, 0))`: the swipe begins on the ninth frame of the slide (a finger at 3.15 mm), so the slide's last 0.35 mm is the first `moved`, and a further slide of d mm leaves travel d + 0.35; rows read such travel as "about d" and compare `travelMM` within 1e-9. "phases" is `phases(frames)`, "fired" is `fired(frames)`, "blocking" is `blocking(frames)`. `HandFrames` rows list contacts per frame in ms with the thumb as contact 9 at (10, 10) and fingers 1, 2, 3 at (62, 45), (70, 45), (86, 45). Switcher pure rows use four `AppEntry`s `safari`, `mail`, `slack`, `notes` with distinct bundle IDs and `Trackpad.macBook14.id`. ScrollFilter rows feed one filter in sequence, `f(e, T)` meaning `decide(e, trackpadBlocking: true)`, `.fingers(.began)` written `.began` and so on, momentum written `.m(.began)`. Every `World` row calls `start()` before acting; `switcherWorld` has Safari, Mail, Slack and Notes installed, Mail, Slack, Notes listed in that order, Safari frontmost, not granted unless `accessGranted: true`; "nothing" means `broughtToFront`, `pulses` and `launchAnimations` gained no entry. A `World` row that plays a second hand on the same trackpad uses `hardware.touch` (a fresh script restarts at 1.0 s, which `play` would skip). The menu projection renders `.app(e, state: .plain)` as the name, `.current` as "✓ name", `.listed` as "✓ name (listed)", `.divider` as "—", `.other` as "Other…", `.unassigned` as "None".

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | recognizer | Parametrised fingers ∈ 1…6: `thumb.tap(fingers: fingers)` → fired == [Gesture(fingerCount: fingers)!] for 1…5 and [] for 6; a trailing `tap(fingers: 1)` after the six fires `.one` | R1 "exactly five distinct non-thumb fingers MUST fire the 5-finger gesture", scenario "Six fingers" (nothing happens); plan 002 R1 (the same rules as the other gestures); the trailing tap proves the six-finger tap left the recognizer armed, as today's silent five did |
| T2 | R1 | recognizer | `thumb.tap(fingers: 5, stagger: 40 ms, hold: 100 ms)`: five distinct fingers over 260 ms, at most three down at once → fired == [.five]; the same with `fingers: 6` → [] | R1 scenario "Rolling five-finger tap" (Slack, not the 4-finger app); "more than five distinct non-thumb fingers MUST NOT fire" |
| T3 | R1 | World | Slack on `.five`, Spotify on `.four`; T2's five-finger script → `broughtToFront == [Slack]`, `feedback == [macBook14.id]`, `launchAnimations == [Slack]`. Separately, granted, five apps on the five gestures, parametrised N ∈ 1…5: firm tap N → `broughtToFront == [the Nth app]`, `pressVerdicts == [.drop, .drop]`, `feedback == [macBook14.id]` (amends `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps`) | R1 scenarios "Five-finger tap opens the app" (once, with the gesture haptic and the launch animation) and "Rolling five-finger tap" (Slack comes to the front and Spotify does not); plan 002 R8 "Firm tap opens the app" for the fifth gesture |
| T4 | R1 | World | All five gestures assigned; `thumb.tap(fingers: 6)` → nothing | R1 scenario "Six fingers" |
| T5 | R2 | World | `World()` → `rows.map(\.gesture) == Gesture.allCases` (five, `.one` … `.five`) and `rows.map(\.app)` all `.unassigned`; `relaunch()` over a garbage record → the same five (amends `PersistenceTests` counts). `World(apps: ["Slack"])`: `setAssignment(.app(Slack), for: .five)` → `app(for: .five) == .present(Slack)`; `tap(5)` → `broughtToFront == [Slack]` | R2 scenarios "Fresh install shows five rows" (1 to 5 top to bottom, each unassigned) and "Assign the fifth row" (the row shows Slack and a five-finger tap brings it to the front); the illustration and its mirroring are manual |
| T6 | R3 | recognizer | Parametrised dx ∈ {2.9, 3.1}: `thumb.land(fingers: 2).slide(byMM: (dx, 0)).lift()` → for 2.9: phases == [] and fired == [.two]; for 3.1: phases.first == .began and fired == [] | R3 "moved more than 3 mm" and "Two fingers that lift without moving past 3 mm remain a 2-finger tap", scenario "Two-finger tap still fires"; `GestureRules.dragThresholdMM` is strictly greater, rows 0.1 mm either side |
| T7 | R3 | recognizer | (a) `thumb.land(fingers: 2).wait(2 s).slide(byMM: (5, 0)).lift()` → phases.first == .began, fired == []. (b) HandFrames: thumb at 0; fingers 1, 2 land at 100; both still at 300 and 500; at 510 finger 1 at (65.5, 45); at 520 the same → per-frame `swipe` == [nil, nil, nil, nil, .began, nil]. (c) `twoFingersHeldFiveHundredMillisecondsFireNothing` passes unchanged | R3 scenario "Fingers rest, then swipe" and "There MUST be no time limit"; design decision 1 "the drag check runs before the 400 ms check, so a slow pair that moves on the frame it crosses 400 ms still begins" (the begin is on the 510 frame, not the one after); plan 002 R2 (a rest that lifts without moving fires nothing) |
| T8 | R3 | recognizer | (a) `thumb.land(fingers: 2).slide(byMM: (0, 10)).slide(byMM: (20, 0)).lift().tap(fingers: 2)` → phases == [], fired == [.two] (the trailing tap only). (b) Parametrised d ∈ {(3.0, 2.9), (2.9, 3.0)}: `thumb.land(fingers: 2).slide(byMM: d).lift()` → phases.first == .began for the first, phases == [] for the second | R3 "with that movement more sideways than up or down" and "When the first movement past 3 mm is more up or down than sideways, no swipe begins and nothing further happens until every non-thumb finger has lifted", scenario "Up or down is not a swipe"; the trailing tap proves recovery; the boundary rows straddle abs(dx) > abs(dy) by 0.1 mm at the frame the drag passes 3 mm |
| T9 | R3 | recognizer | (a) `thumb.land(fingers: 1).slide(byMM: (20, 0)).lift()` → phases == []. (b) `thumb.land(fingers: 3).slide(byMM: (20, 0)).lift()` → phases == []. (c) HandFrames: thumb at 0; fingers 1, 2 land at 100; at 120 finger 1 at (66, 45) and finger 3 `.landing` at (86, 45); at 200 thumb only; finger 4 lands at 300 and lifts at 330 → phases == [], fired == [.one] | R3 scenarios "One finger is not a swipe" and "Three fingers are not a swipe"; R3 "exactly two non-thumb fingers are down; no other non-thumb finger has touched"; design `Pair.init?` "none joins on this frame" (the synthesis names the third finger landing on the begin frame as the case candidate 2 missed); the trailing tap proves recovery |
| T10 | R3 | recognizer | HandFrames: fingers 1, 2 `.landing` at 0; thumb `.landing` at 50 with both down; at 100 fingers at (82, 45) and (90, 45); thumb only at 150; finger 3 lands at 200 and lifts at 230 → phases == [], fired == [.one] | R3 "a thumb is anchored and it anchored before either finger landed", scenario "Fingers before thumb"; design decision 1 "fingers already down when the thumb lands put the recognizer in `.spoiled`, which never begins a swipe"; `fingersDownBeforeTheThumbNeverFire` is the tap precedent |
| T11 | R3 | recognizer | Parametrised over four scripts after `thumb.land(fingers: 2).wait(1 s)`: (a) `.land(fingers: 1, atMM: (86, 45)).slide(byMM: (20, 0)).lift()`; (b) `.slide(byMM: (0, 10)).slide(byMM: (20, 0)).lift()`; (c) HandFrames equivalent with `press: .click` on the frame at 1 s, then both fingers at +20 mm, then lifted; (d) `.lift(.first).slide(byMM: (20, 0)).lift()`; each followed by `tap(fingers: 1)` → phases == [], fired == [.one] | Design decision 1 "`.resting` … spoils on a delivered click, on either finger lifting, or on any other non-thumb contact landing; it becomes `.swiping` on a sideways first move past 3 mm and is spoiled by a vertical one"; R3 "no other non-thumb finger has touched since the last moment no non-thumb finger was down"; plan 002 R2 "no new tap begins until every non-thumb finger has lifted" (the trailing tap) |
| T12 | R3 | recognizer | HandFrames: thumb at 0; fingers 1, 2 land at 100; at 120 finger 1 at (66, 45); at 140 finger 3 `.landing` at (86, 45) with 1, 2 down; at 200 thumb only; at 300 nothing → phases == [.began, .cancelled], fired == [] | R3 scenario "Rolling three-finger tap with drift" (the switcher appears and disappears, no app comes to the front); R9 "another finger lands outside the anchor corner" cancels |
| T13 | R3, R8 | recognizer | `thumb.land(fingers: 2).slide(byMM: (4, 0)).lift()` → phases.first == .began, phases.last == .ended, no `.cancelled`, every `.moved` travel < 1 mm, fired == [] | R3 scenario "Two-finger tap that drifts" (the switcher appears briefly and disappears, no tap fires); R8 "A swipe ends when the first of the two fingers lifts" |
| T14 | R6 | recognizer | Begin script then `slide(byMM: (12, 0))`, parametrised over surface ∈ {`.macBook14`, `.magicTrackpad`} and hand ∈ {right with the thumb at (10, 10), left with the thumb at (114.8, 10) on macBook14 and (150, 10) on magicTrackpad} → the last `.moved` travel is about +12 (12.35 within 1e-9) in every case; with `slide(byMM: (−12, 0))` instead, about −12 | R6 "Travel is measured in trackpad millimetres, the same on every trackpad, and the direction is the same in both hand modes: right moves the selection right", scenario "Same direction in left-hand mode"; `SurfacePoint` x 0 is the left edge in both hand modes (F11) |
| T15 | R6 | recognizer | HandFrames: thumb at 0; fingers 1, 2 land at 100; finger 2 stays at (70, 45) while finger 1 is at (66, 45) at 110, (70, 45) at 120, (74, 45) at 130, (78, 45) at 140, (82, 45) at 150, (86, 45) at 160 → phases == [.began, .moved(2), .moved(4), .moved(6), .moved(8), .moved(10)] (within 1e-9); nothing moves on a frame where neither finger moved | R6 "Travel is the sideways movement of the midpoint of the two fingers, measured from where the swipe began": one finger 24 mm, the other still, from a begin at 4 mm, is a midpoint travel of (24 − 4) ÷ 2 = 10; `SwipePhase.moved` "Sent only when it changed" |
| T16 | R8 | recognizer | (a) Begin script, `.slide(byMM: (24, 0)).lift(.first).slide(byMM: (24, 0)).lift()` → phases.last == .ended, exactly one `.ended`, no phase after it, fired == []. (b) HandFrames mirror where the second-landed finger lifts first and the first keeps moving → the same | R8 "A swipe ends when the first of the two fingers lifts", scenario "One finger lifts first" (Slack comes to the front at the first lift and the remaining finger changes nothing); design "the first lift wins" for either finger |
| T17 | R8 | recognizer | HandFrames: thumb at 0; fingers 1, 2 land at 50; at 60 finger 1 at (66, 45); at 150 fingers at (90, 45) and (94, 45); at 200 nothing → phases == [.began, .moved(24), .ended] (within 1e-9), blocking at 200 == false | R8 scenario "Whole hand lifts together" (Slack comes to the front); design decision 1: the thumb is handled before the exits, so its lift on the same frame does not cancel |
| T18 | R8, R13 | recognizer | Parametrised rest ∈ {0, 4 s}: `thumb.wait(rest).land(fingers: 2)` + begin, `.slide(byMM: (12, 0)).lift(.first).slide(byMM: (30, 0)).land(fingers: 1, atMM: (86, 45)).lift().tap(fingers: 1)` → one `.ended` and no phase after it, fired == [.one] (the trailing tap only); blocking on the first frame after the `.ended` frame == (rest == 0) | R8 "After a swipe ends, nothing further happens until every non-thumb finger has lifted"; R13 "Once the swipe ends or is cancelled, the plan 002 R4 rule alone applies again": a fresh thumb still inside its 3 s window blocks, a 4 s-old one does not |
| T19 | R8, R9, R13 | recognizer | (a) The design's row: `thumb.land(fingers: 2).slide(byMM: (5, 0)).liftThumb().slide(byMM: (24, 0)).thumb(atMM: (12, 10)).lift().tap(fingers: 1)` → phases.first == .began, phases.last before the tap == .ended, no `.cancelled`; `blocksClicks` true on every frame from the `.began` frame through the frame before `.ended`; fired == [.one]; blocking true on the tap's frames with the finger down. (b) The same without `.thumb(atMM: (12, 10))` → `.ended` still, fired == [] | R8 scenario "Thumb lifts, swipe goes on" and R9 scenarios "Thumb lands again" (Slack comes to the front) and "The thumb plays no part once the swipe has begun"; R13 "whether or not the thumb is still anchored"; design decision 1 "a thumb landing in `admits` becomes the thumb with `landedAt = frame.time`" (so the trailing tap fires and its press window is open) and "Every exit goes to `thumb.map(.spoiled) ?? .idle`" (no thumb: the trailing tap has no anchor) |
| T20 | R9 | recognizer | `thumb.land(fingers: 2).slide(byMM: (5, 0)).rollThumb(toMM: (40, 10)).slide(byMM: (24, 0)).lift()` → phases.first == .began, phases.last == .ended, no `.cancelled`; then `.rollThumb(toMM: (10, 10)).tap(fingers: 1)` → fired == []; then `.liftThumb().thumb(atMM: (10, 10)).tap(fingers: 1)` → fired == [.one] | R9 scenario "Thumb slides out, swipe goes on" (Slack comes to the front); design decision 1 "a contact already down is never adopted (F10's `.idle` rule)" after the swipe, and a thumb landing anew arms as today |
| T21 | R9 | recognizer | Begin script, `.slide(byMM: (24, 0)).land(fingers: 1, atMM: (86, 45)).slide(byMM: (12, 0)).lift().tap(fingers: 1)` → phases contain exactly one `.cancelled`, nothing after it, fired == [.one] | R9 scenario "Third finger lands" (the switcher disappears and nothing opens) and "After a cancel, nothing further happens until every non-thumb finger has lifted"; the trailing tap proves recovery under the still-anchored thumb |
| T22 | R9 (design decision 1) | recognizer | HandFrames: thumb at 0; fingers 1, 2 land at 50; at 60 finger 1 at (66, 45); at 100 fingers only (thumb lifted); at 150 finger 2 only and thumb 9 `.landing` at (10, 10); at 200 thumb and finger 2; at 250 thumb only; finger 3 lands at 300 and lifts at 330 → per-frame `swipe` == [nil, nil, .began, nil, .ended, nil, nil, nil, nil], blocking at 200 == true, fired == [.one] | Design decision 1 "The thumb is handled before the exits, so a thumb landing on the exit frame is the anchor afterwards" and "a thumb that re-landed mid-swipe opens its own fresh 3-second window"; R9 "Thumb lands again"; plan 002 R4 (a thumb becoming anchored opens a window) |
| T23 | R9 (design decision 1) | recognizer | HandFrames after thumb at 0, fingers 1, 2 at 50, finger 1 at (66, 45) at 60: (a) at 100 thumb and finger 3 `.landing` at (86, 45), fingers 1, 2 gone → `.ended`; (b) at 100 thumb only with `press: .click` → `.cancelled` | Design decision 1 "Exits, all named, in this order: a `.click` press → cancelled; either pair finger lifting → ended; a contact landing outside `admits` that is not the thumb → cancelled" and its open question "two fingers lift in the same frame that a third lands"; pinned so the order is a decision, not an accident |
| T24 | R9 | recognizer | Parametrised press ∈ {.blocked, .click}, HandFrames: thumb at 0; fingers 1, 2 land at 50; at 60 finger 1 at (66, 45); at 70 the same with `press`; at 80 fingers at (74, 45), (78, 45) with `press`; at 100 thumb only → per-frame `swipe` == [nil, nil, .began, nil, .moved(8), .ended] for `.blocked` and [nil, nil, .began, .cancelled, nil, nil] for `.click` | R9 "when a click reaches apps (an unblocked press)" cancels and "A blocked press (plan 002 R8) MUST NOT affect the swipe", scenarios "Unblocked click cancels" and "Blocked press is ignored"; plan 002 R8 (the filter's verdict is the single truth about a press) |
| T25 | R13 | recognizer | Parametrised over (a) `thumb.wait(4 s).land(fingers: 2)` + begin + `.slide(byMM: (24, 0)).lift()`, (b) T19 (a)'s script up to `.lift()`, (c) T20's script up to `.lift()` → `blocksClicks` is true on every frame from the `.began` frame through the frame before the `.ended` frame, and false on the `.ended` frame and every frame after | R13 "clicks MUST be blocked and trackpad scrolling MUST be suppressed from the moment a swipe begins until it ends or is cancelled, however long after the thumb anchored and whether or not the thumb is still anchored" and "Once the swipe ends … the plan 002 R4 rule alone applies" (a 4 s-old, lifted or slid-out thumb blocks nothing); design decision 2 |
| T26 | R17 | World | `World(apps: ["Safari", "Mail", "Slack", "Notes", "Figma"])`; `addToSwitcher` Mail, Slack, Notes → `switcherRows.map(\.assigned.name) == ["Mail", "Slack", "Notes"]` with every `present` non-nil; `addToSwitcher(.app(Figma))`, `registry[Figma] = [trash("Figma")]`, `openWindow()` → the last row has `assigned.name == "Figma"` and `present == nil`; `install("Figma")`, registry → the new copy, `openWindow()` → `present == app("Figma")` | R17 "Each row MUST show the app's icon and name" (the row's `present` entry carries both), scenario "Missing app in the list" (greyed "not found", then shows normally); the missing rule is the one gesture rows use (`reinstalledAppRecoversWithoutRepicking`) |
| T27 | R18 | pure menu | `World(apps: ["Mail", "Slack", "Notes"])`, `recordLaunch("Notes")`, started: `installedApps.addMenu(listing: [Mail, Slack])` projects to ["Notes", "—", "Finder", "✓ Mail (listed)", "✓ Slack (listed)", "—", "Other…"]; `World(apps: ["Mail", "Slack"])` with no launch data: `addMenu(listing: [])` → ["Finder", "Mail", "Slack", "—", "Other…"] and `pickerMenu(checking: .present(Slack))` → ["Finder", "Mail", "✓ Slack", "—", "Other…", "None"] | R18 "a menu like an app picker's: the recently launched apps, the other installed apps, then Other…, with no None. Apps already in the switcher list MUST appear checked and disabled", scenario "Listed apps are checked and disabled" (Mail and Slack checked and unchoosable, Notes choosable); the picker's own shape is unchanged (`everyPickerSharesOneRecentSectionAndChecksItsOwnApp`); Finder order from `AppCatalogTests` |
| T28 | R18 | World | `World(apps: ["Mail", "Slack", "Notes", "Arc"])`, Mail and Slack listed: `addToSwitcher(.app(Notes))` → names == ["Mail", "Slack", "Notes"]; `addToSwitcher(.app(Slack))` → unchanged; `install("Sketch", in: downloads)` and `addToSwitcher(.appBundle(at: downloads/Sketch.app))` → the last row's `present == app("Sketch", in: downloads)` and `assigned.name == "Sketch"`; `addToSwitcher(.appBundle(at: downloads/Notes.txt))` → unchanged; `addToSwitcher(.appBundle(at: app("Slack").url))` → unchanged; Arc on `.one` then `addToSwitcher(.app(Arc))` → Arc appended and `app(for: .one) == .present(Arc)`; `store.load()?.switcherList.apps.map(\.name)` equals the rows' names throughout | R18 scenarios "Add from the menu" (Mail, Slack, Notes), "Other… from elsewhere" (appended with its icon and name), "Other… picks a listed app" (unchanged), "Same app on a tap and in the list" (added, without a warning); `AppChoice.appBundle` "ignored if not an app with a bundle ID" (`otherAcceptsAnAppBundleAndIgnoresAnythingElse`) |
| T29 | R18, R20, R23 | pure value | `SwitcherList`: `append(A)`, `append(B)`, `append(A')` (A's bundle ID at another URL) → `apps == [A, B]`; `remove(C)` → unchanged; `remove(A)` → [B]; on [A, B, C]: `move(C, to: 0)` → [C, A, B], `move(A, to: 2)` → [B, C, A], `move(B, to: 1)` → unchanged, `move(A, to: 99)` → A last, `move(C, to: −1)` → C first, `move(D, to: 0)` → unchanged. Coding: a `Settings` with `.five → Slack` and list [A, B] round-trips through `PropertyListEncoder`/`PropertyListDecoder` equal; a test-local record whose `switcherList` is the plain array [A, B, A] decodes to [A, B]; the encoded `Settings` decodes into a test-local struct whose `switcherList` is `[AssignedApp]` | R18 "an app already in the list MUST NOT be added twice" (identity is the bundle ID, glossary *Assignment*); R20 "Dragging a row to a new position MUST reorder the list" with the design's "clamps the index"; R23 round trip; design "encoded as a plain array and drops duplicates when decoded"; probe F22 ("NEW round trip: five=Arc switcherList=[…]") |
| T30 | R19, R21 | World | `World()` → `switcherRows.isEmpty`; `relaunch().switcherRows.isEmpty`. `World(apps: ["Mail", "Slack", "Notes"])` with all three listed: `removeFromSwitcher(Slack)` → ["Mail", "Notes"]; `removeFromSwitcher(Notes)` → ["Mail"]; `removeFromSwitcher(Notes)` again → unchanged; `removeFromSwitcher(Mail)` → `switcherRows.isEmpty`; `store.load()?.switcherList.isEmpty == true` | R19 scenarios "Remove on hover" (Mail, Notes) and "Remove from the context menu" (the rows below move up); R21 scenario "Fresh install" (no rows); the hover button and the context menu themselves are manual |
| T31 | R20 | World | `World(apps: ["Mail", "Slack", "Notes"])` with Mail, Slack, Notes listed: `moveInSwitcher(Notes, to: 0)` → ["Notes", "Mail", "Slack"]; `moveInSwitcher(Mail, to: 99)` → ["Notes", "Slack", "Mail"]; `relaunch().switcherRows.map(\.assigned.name) == ["Notes", "Slack", "Mail"]` | R20 scenario "Drag to reorder" (Notes, Mail, Slack); R23 "the switcher list and its order MUST persist"; the next switcher's order is T59 |
| T32 | R23 | World | `World(apps: ["Safari", "Slack", "Notes", "Mail"])`: five apps on the five gestures (Slack on `.five`), `setHandMode(.left)`, `addToSwitcher` Mail then Notes, `moveInSwitcher(Notes, to: 0)`; `relaunch()` → `rows.map(\.app)` == the five `.present` entries, `handMode == .left`, `switcherRows.map(\.assigned.name) == ["Notes", "Mail"]` (amends `assignmentsAndHandModeSurviveARelaunch` to five names) | R23 scenario "Survives relaunch" (the fifth row shows Slack and the list reads Notes, Mail); plan 001's relaunch pattern over the throwaway suite |
| T33 | R23 | World | Parametrised handMode ∈ {.right, .left}: `World(apps: ["Arc"])`; `UserDefaults(suiteName:)` gets `Fixtures.recordSavedByPlan002(handMode:, two: Arc)` under "settings"; `relaunch()` → `app(for: .two) == .present(Arc)`, `handMode == handMode`, `switcherRows.isEmpty`, `rows.count == 5`; `start()` → `loginItemRegistrations == 0`, `!isWindowOpen`. `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch` passes with five rows | Probe F22 ("TOLERANT decodes: handMode=right two=Arc switcherList=0"; synthesized decoding throws `keyNotFound`); design decision 13; plan 002's "no record means first launch" unchanged (F23) |
| T34 | design decision 7 | AppCatalog | A catalog over the World's `applications` whose `registeredCopies` closure counts its calls through a `Mutex`: `locate(AssignedApp(app("Figma")))` → the entry, calls == 0; after `trash("Figma")` with the registry holding a live copy in `userApplications`, `locate` → that copy, calls == 1; with the registry holding only the trashed copy → nil, calls == 1 | Design decision 7 "`registeredCopies` is consulted only when `lastKnownURL` misses"; the semantics are those `trashedCopiesNeverCountWhenARealCopyExists` and `aDifferentBundleAtTheOldLocationIsNotTheAssignedApp` already pin |
| T35 | R3, R10 | World | switcherWorld, Notion installed and on `.three`; T12's frames via `hardware.touch` in two halves: through the 120 frame → `switcher != nil` with `row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"]`; the rest → `switcher == nil`, nothing | R3 scenario "Rolling three-finger tap with drift" (the switcher appears and disappears, no app comes to the front, no haptic plays); R10 (the switcher is up exactly while the swipe is) |
| T36 | R3, R8, R10 | World | switcherWorld, Figma installed and on `.two`; `thumb.land(fingers: 2).slide(byMM: (4, 0))` through `play` → `switcher != nil` and `selectsFrontmost`; then `.lift()` → `switcher == nil`, nothing, `isWindowOpen` unchanged | R3 scenario "Two-finger tap that drifts" (briefly appears, no haptic, neither Figma nor any other app); R8 "When the selected app is the frontmost app, nothing happens except that the switcher disappears" |
| T37 | R4, R5 | Switcher pure | `Switcher(listed: [mail, slack, notes], frontmost: slack)` → `row == [mail, slack, notes]`, `home == 1`, `selected == 1`, `selectedApp == slack`, `selectsFrontmost`. `(listed: [mail, slack, notes], frontmost: safari)` → `row == [safari, mail, slack, notes]`, `home == 0`. `(listed: [mail, slack, notes], frontmost: slack at another URL)` → `row == [mail, slack, notes]`, `home == 1`. `(listed: [mail], frontmost: safari)` → non-nil with two icons. `(listed: [], frontmost: safari)` and `(listed: [safari], frontmost: safari)` → nil | R4 scenarios "Frontmost app is in the list" and "Frontmost app is not in the list" (Safari at the left end); R5 scenarios "Selection starts in the middle" and "at the left end"; identity is the bundle ID (glossary); R11 "no present app, or the only icon the row would hold is the frontmost app" |
| T38 | R4, R5, R17 | World | switcherWorld with `makeFrontmost("Slack")`: `swipe(3.5, lift: false)` → `switcher?.row.map(\.name) == ["Mail", "Slack", "Notes"]` == `switcherRows.map(\.assigned.name)`, `selectedApp.name == "Slack"`. switcherWorld (Safari) → ["Safari", "Mail", "Slack", "Notes"], Safari selected. `install("Sketch", in: downloads)`, `system.frontmost = downloads/Sketch.app` → the row starts with "Sketch" | R4 and R5 scenarios as T37, through the whole app; R17 scenario "Order matches" (top to bottom in the window is left to right in the switcher); design decision 6: the frontmost app is parsed by `catalog.entry(at:)` from any location (F1) |
| T39 | R4 | World | `World(apps: ["Safari", "Mail", "Figma", "Notes"])`, Mail, Figma, Notes listed, Safari frontmost; `registry[Figma] = [trash("Figma")]` with no `openWindow()`; `swipe(3.5, lift: false)` → `row.map(\.name) == ["Safari", "Mail", "Notes"]` | R4 scenario "Missing app is left out" (Figma is not in the row); design decision 7 "The row is built fresh at begin" (a row read from the last window open would still hold Figma) |
| T40 | R11 (design decision 6) | World | Parametrised frontmost ∈ {nil, downloads/Notes.txt}: switcherWorld(accessGranted: true), `makeFrontmost(nil)` or `system.frontmost = downloads/Notes.txt`; play `thumb.land(fingers: 2).slide(byMM: (3.5, 0))` → `switcher == nil`, `scroll(.fingers(.began)) == .pass`; continue `.press().slide(byMM: (12, 0)).lift()` → `pressVerdicts == [.pass, .pass]`, `switcher` nil throughout, nothing; then `makeFrontmost("Safari")` and continue `.land(fingers: 2).slide(byMM: (3.5, 0))` (the thumb never lifted) → `switcher?.row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"]` | Design decision 6 "Nil or self means no switcher, and the swipe is ended through `reconcile()` as in decision 3: a `Switcher` has no meaning without a home, and starting anywhere else would make a lift without moving open an app"; decision 3 "The fresh recognizer sees the thumb and the resting fingers already down on its first frame and goes to `.spoiled` with no window … so clicks and the next scroll work again at once and the remaining fingers do nothing until they lift" (without the reconcile the recognizer stays `.swiping` and the press and the scroll read `.drop`); `aReconcileUnderARestingThumbDoesNotRestartTheWindow` (a press under a thumb whose landing time is unknown passes, and that thumb arms the next gesture); F2 (self only while Other… is open); the design's open question records this as a decision to confirm |
| T41 | R6 | Switcher pure | `Switcher(listed: [mail, slack, notes], frontmost: safari)` (home 0), parametrised travel → selected: 5.9 → 0, 6.0 → 1, 6.1 → 1, 17.9 → 1, 18.0 → 2, 24 → 2, 30 → 3, 36 → 3, 60 → 3, −30 → 0. `Switcher(listed: [mail, slack, notes], frontmost: slack)` (home 1): −5.9 → 1, −6.0 → 0, −6.1 → 0, 6.0 → 2, 18.0 → 2 | R6 "the selection changes when the highlight crosses the midpoint between two icons: 6 mm after the swipe began, then every 12 mm. Reversing direction MUST move the selection back under the same rule. The selection MUST NOT move past the first or last icon", scenarios "Two steps right" (24 → Slack), "Half a step" (5 → Safari), "Past the midpoint" (7 → Mail), "No wrap at the end"; the 6.0 reading above |
| T42 | R6 | Switcher pure | Home 0, four icons: travel 5 → `position == 5/12` (within 1e-9), `stretch == 0`; 36 → `position == 3`, `stretch == 0`; 48 → `position == 3`, 0 < `stretch` < 0.2; 60 → `stretch` greater than at 48 and < 0.2; 1000 → `stretch` < 0.2; −12 → `position == 0`, −0.2 < `stretch` < 0; 0 → `stretch == 0` | R6 "between two icons it sits between them in proportion to the travel" (5 of 12 mm), "travel beyond an end moves the highlight only slightly past it" (`GestureRules.switcherMaxStretch` 0.2 of an icon, never reached), "springs back" is the presenter's and manual |
| T43 | R6, R7 | World | switcherWorld: `swipe(3.5, 24, lift: false)` → `selectedApp.name == "Slack"`, `lightTicks.count == 2`, no `.gesture` pulse; continue `.slide(byMM: (−12, 0))` → "Mail", `lightTicks.count == 3` | R6 scenarios "Two steps right" (Slack) and "Back and forth" (Mail); R7 "Each time the selected icon changes … the light tick" (two crossings right, one back) |
| T44 | R6, R7 | World | switcherWorld: `swipe(3.5, 5, lift: false)` → Safari selected, `selectsFrontmost`, 0 < `position` < 0.5, `lightTicks.isEmpty`. A fresh switcherWorld: `swipe(3.5, 7, lift: false)` → "Mail", `position` > 0.5, `lightTicks.count == 1` | R6 scenarios "Half a step shows progress without changing the selection" (nearer Safari, still selected) and "Past the midpoint snaps" (Mail); R7 scenario "No tick without a change" |
| T45 | R6, R7 | World | switcherWorld: `swipe(3.5, 36, lift: false)` → "Notes"; continue `.slide(byMM: (30, 0))` → still "Notes", `position == 3`, 0 < `stretch` < 0.2, `lightTicks.count == 3`; `.lift()` → `broughtToFront == [Notes]` | R6 scenario "No wrap at the end" (Notes stays selected, the highlight rests on Notes having moved only slightly past it); non-goal "Wrapping from the last icon to the first"; R7 "No tick plays while the selection stays put" |
| T46 | R7 | World | switcherWorld: `swipe(3.5, 36, lift: false)` → `lightTicks == [macBook14.id, macBook14.id, macBook14.id]`. A fresh switcherWorld: begin script then `.slide(byMM: (36, 0), over: .milliseconds(10))` (one frame) → `lightTicks.count == 3` | R7 scenario "Ticks per icon" (three light ticks for 36 mm, one per icon crossed); design decision 4 "The model plays abs(selected after − selected before) light ticks per `moved` (R7 'one per icon crossed', even when one frame crosses two)" |
| T47 | R8, R10 | World | switcherWorld, `openWindow()`; the design's row: begin + `.slide(byMM: (24, 0))` → row ["Safari", "Mail", "Slack", "Notes"], "Slack", `lightTicks.count == 2`, `switcher != nil`; `.lift()` → `broughtToFront == [Slack]`, `pulses` == [two `.lightTick` then one `.gesture`, all on macBook14], `feedback == [macBook14.id]`, `launchAnimations.isEmpty`, `switcher == nil`, `!isWindowOpen` | R8 scenarios "Lift opens the app" (Slack, the gesture haptic, no launch animation, the switcher gone) and "Launcher window closes"; R10 "gone … of the swipe ending"; non-goal "A launch animation for apps opened from the switcher"; plan 001 R12 (bring to front) |
| T48 | R8 | World | switcherWorld: `swipe(3.5, 24, lift: false)`; continue `.lift(.first).slide(byMM: (24, 0)).lift()` → `broughtToFront == [Slack]`, `lightTicks.count == 2`, `feedback.count == 1`, `switcher == nil` from the first lift on | R8 scenario "One finger lifts first" (Slack comes to the front at the first lift and the remaining finger changes nothing) |
| T49 | R8 | World | switcherWorld; T17's frames via `hardware.touch` → `broughtToFront == [Slack]`, `feedback == [macBook14.id]`, `switcher == nil` | R8 scenario "Whole hand lifts together" (Slack comes to the front) |
| T50 | R8, R9 | World | switcherWorld: `swipe(3.5, 12, lift: false)` → "Mail"; continue `.liftThumb()` and play → `switcher != nil`, still "Mail"; `.slide(byMM: (24, 0))` → "Notes"; `.lift()` → `broughtToFront == [Notes]` | R8 scenario "Thumb lifts, swipe goes on" (the switcher stays up the whole time, follows the fingers, and the app two icons right comes to the front); R9 "The thumb plays no part once the swipe has begun" |
| T51 | R8 | World | switcherWorld, `openWindow()`: `swipe(3.5, 4)` → `switcher == nil`, nothing, `isWindowOpen`; `scanRequests == 2` (the open only) | R8 scenario "Staying on the frontmost app" (the switcher disappears, no haptic plays and no app changes); the R8 reading above (the window stays) |
| T52 | R9, R10 | World | switcherWorld: `swipe(3.5, 24, lift: false)`; continue `.land(fingers: 1, atMM: (86, 45))` → `switcher == nil`; `.lift()` → nothing; `pulses` holds only the two ticks | R9 scenario "Third finger lands" (the switcher disappears and nothing opens); R10 "gone … of the swipe … cancelling" |
| T53 | R9 | World | switcherWorld (not granted): `swipe(3.5, 24, lift: false)` → "Slack"; continue `.press().slide(byMM: (12, 0)).lift()`: after the press frame `switcher == nil`; at the end `broughtToFront.isEmpty`, no `.gesture` pulse, `pressVerdicts.isEmpty`, `!hardware.isBlockingClicks` | R9 scenario "Unblocked click cancels" (the switcher disappears and Slack does not come to the front; that the button is clicked is manual); plan 002 R8 "Without access, a press stays a click" |
| T54 | R9, R13 | World | switcherWorld(accessGranted: true): `swipe(3.5, 12, lift: false)` → "Mail"; continue `.press().slide(byMM: (12, 0)).lift()` → `switcher` stayed non-nil through the press, `pressVerdicts == [.drop, .drop]`, `broughtToFront == [Slack]` | R9 scenario "Blocked press is ignored" (nothing is clicked and the app selected at the lift comes to the front); R13 (the press inside the 3 s window is blocked as before) |
| T55 | R11 | World | `World(apps: ["Safari", "Mail"], accessGranted: true)`, `makeFrontmost("Safari")`, list empty: `thumb.wait(4 s).land(fingers: 2).slide(byMM: (20, 0)).press().lift()` → `switcher` nil throughout, nothing, `pressVerdicts == [.pass, .pass]`. Then `addToSwitcher(.app(Mail))` and the same frames via `hardware.touch` → `switcher` was non-nil, `pressVerdicts` gained `[.drop, .drop]`, `broughtToFront == [Mail]` | R11 scenario "Empty list" ("nothing happens": no switcher and, with the gate, no swipe-wide block past the window); design decision 3 "`run` gains `swipes` … Without this gate, every user with an empty list would find an anchored thumb plus a sideways two-finger scroll suppressed for its whole length"; the second half proves the gate turns on with the first app |
| T56 | R11 (design decision 3) | World | Parametrised rest ∈ {0, 4 s} × list ∈ {(a) [Safari], (b) [Figma] with `registry[Figma] = [trash("Figma")]`}: `World(apps: ["Safari", "Mail", "Figma"], accessGranted: true)`, `makeFrontmost("Safari")`; play `thumb.wait(rest).land(fingers: 2).slide(byMM: (3.5, 0))` → `switcher == nil`, `scroll(.fingers(.began)) == .pass`; continue `.press().slide(byMM: (12, 0)).lift()` → `pressVerdicts == [.pass, .pass]`, `switcher` nil throughout, nothing, `scanRequests == 1`; then `addToSwitcher(.app(Mail))` (no emptiness flip) and continue `.land(fingers: 2).slide(byMM: (3.5, 0))` (the thumb never lifted) → `switcher?.row.map(\.name) == ["Safari", "Mail"]` | R11 scenarios "Only the frontmost app" and "When the switcher list holds no present app" ("nothing happens": no switcher, no haptic, nothing opens, and the press right after is a click); design decision 3 "when a `began` yields no switcher … `swipe(.began)` calls `reconcile()` … the fresh recognizer … goes to `.spoiled` with no window … so clicks and the next scroll work again at once and the remaining fingers do nothing until they lift" and "the block lasts only from the begin frame until main handles the event" (without the reconcile the recognizer stays `.swiping`: `[.drop, .drop]` and `.drop`, at rest 0 and at 4 s alike); `Switcher.init?` nil (T37); `aReconcileUnderARestingThumbDoesNotRestartTheWindow` (the thumb that stays arms the next gesture with no window); `onlyStartAndOpeningTheWindowRequestAScan` (a reconcile requests no scan) |
| T57 | R11 | World | switcherWorld: `preferences.set(.tapToClick, rawValue: 1, for: .builtIn)` → `running.isEmpty`; `swipe(3.5, 12)` → nothing, `switcher == nil`; `inject(.swipe(SwipeEvent(phase: .began, trackpad: macBook14.id)))` → `switcher == nil` | R11 scenario "Gestures inactive" (nothing happens); design `swipe(.began)` "guard … activity.isActive"; `gestureInFlightWhenActivityFlipsIsDropped` is the tap precedent for the in-flight event |
| T58 | R11 (design decision 3) | World | (a) `World(apps: ["Safari", "Mail", "Slack"], accessGranted: true)`, Mail listed: play `thumb.land(fingers: 1)`; `addToSwitcher(.app(Slack))`; continue `.press().lift()` → `pressVerdicts == [.drop, .drop]`. (b) The same with the list empty before `addToSwitcher(.app(Mail))` → `pressVerdicts == [.pass, .pass]`. Both: `scanRequests == 1` | Design decision 3 "The list's emptiness flips only through the three edit intents, which reconcile only on a flip" (an edit that does not flip leaves the recognizer and its window intact; one that flips rebuilds it, and plan 002's "A reconcile cannot restart the window" makes that visible as a passed press); `onlyStartAndOpeningTheWindowRequestAScan` |
| T59 | R20, R23 | World | switcherWorld with `makeFrontmost("Slack")`: `moveInSwitcher(Notes, to: 0)`; `swipe(3.5, lift: false)` → `row.map(\.name) == ["Notes", "Mail", "Slack"]`, "Slack" selected. Then T32's world: `relaunch()`, `start()`, `makeFrontmost("Safari")`, `swipe(3.5, lift: false)` → `row.map(\.name) == ["Safari", "Notes", "Mail"]` | R20 scenario "Drag to reorder" ("the next switcher shows Notes, Mail, Slack left to right"); R23 (the stored list drives the swipe after a relaunch, so the `swipes` gate is on from `start()`) |
| T60 | R24 | Copy | `Copy.gestureHint(for: .right) == "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps"`; `.left` is the same string with "top-right"; `HandMode.cornerName` unchanged | R24 (the literal, "top-right" in left-hand mode); plan 001's `cornerNamesMatchTheHint` |
| T61 | design decision 4 (per-trackpad guard) | World | `World(apps: ["Safari", "Mail", "Slack", "Notes"], attached: [.macBook14, .magicTrackpad])`, Mail, Slack, Notes listed, Safari frontmost: `swipe(3.5, 12, lift: false)` on macBook14 → "Mail", `lightTicks.count == 1`; `inject(.swipe(SwipeEvent(phase: .moved(travelMM: 24), trackpad: magicTrackpad.id)))` → still "Mail", `lightTicks.count == 1`; inject `.ended` on magicTrackpad → `switcher != nil`, `broughtToFront.isEmpty`; inject `.cancelled` and `.began` on magicTrackpad → `switcher?.trackpad == macBook14.id`; continue `.lift()` → `broughtToFront == [Mail]`, `feedback == [macBook14.id]` | Design `swipe(_:)` "guard … open.trackpad == event.trackpad" and "guard switcher == nil" on `.began`; open question "A swipe on a second trackpad while the first one's switcher is up is ignored on screen"; plan 001 (feedback plays on the trackpad that fired) |
| T62 | R8, R9 (reconcile mid-swipe) | World | switcherWorld, Mail on `.one`: `swipe(3.5, 12, lift: false)` → "Mail"; `preferences.set(.tapToClick, rawValue: 0, for: .builtIn)` → `switcher == nil`; continue `.slide(byMM: (24, 0)).lift()` → nothing new (`lightTicks.count == 1`, `broughtToFront.isEmpty`); `.tap(fingers: 1)` → `broughtToFront == [Mail]` | Design decision 1 "`run` ends any swipe because it replaces the recognizer; `reconcile()` clears `switcher` for the same reason"; the test handle "A reconcile mid-swipe"; "the remaining fingers do nothing until they lift", after which the resting thumb arms as `aReconcileUnderARestingThumbDoesNotRestartTheWindow` shows |
| T63 | R7, R8 | MultitouchTrackpads.actuation | `actuation(for: .gesture) == 6`, `actuation(for: .lightTick) == 3`, and the two differ | F14 (`feedbackActuation = 6` today, "Chosen by feel: 3 weak, 4 medium, 6 strong"); R7 "a haptic pulse lighter than the gesture haptic"; design decision 10 (the feel check may move the tick to 4, which keeps this row's third clause) |
| T64 | R12 | ScrollFilter | `f(.wheel, T) == .pass`; `f(.unphased, T) == .drop`, `f(.unphased, F) == .pass`; then `f(.mayBegin, T) == .drop`, `f(.began, F) == .drop`, `f(.changed, F) == .drop`, `f(.ended, F) == .drop`, `f(.m(.began), F) == .drop`, `f(.m(.changed), F) == .drop`, `f(.m(.ended), F) == .drop`, `f(.began, F) == .pass`, `f(.ended, F) == .pass`; on a fresh filter `f(.began, T) == .drop` | R12 "Scrolling from a mouse wheel MUST NOT be suppressed" (`.wheel` is `isContinuous == 0`, F18), "suppressed under exactly the conditions that block clicks" (the flag), scenario "Scrolling returns after 3 seconds" (the next gesture passes at once); R14 "The momentum that follows a suppressed scroll MUST be suppressed too"; design decision 11 "a gesture first seen at an opening event while blocking is dropped, so apps never see any of it" |
| T65 | R12, R13 | ScrollFilter | `f(.began, F) == .pass`, `f(.changed, T) == .passStill`, `f(.changed, F) == .passStill`, `f(.ended, F) == .passStill`, `f(.m(.began), F) == .passStill`, `f(.m(.ended), F) == .passStill`, `f(.began, F) == .pass`. On a fresh filter `f(.changed, T) == .passStill` (first seen mid-way), then `f(.ended, F) == .passStill` | R13 "the page does not scroll, before, during or after the switcher" and scenario "Late swipe still gets a clean switcher" (nothing moves once the switcher is up, the app's bracket stays whole); design decision 11 "a gesture that was passing and meets blocking mid-way becomes stilled … the treatment never relaxes inside a gesture"; the R12 "at once" reading above |
| T66 | R14 | ScrollFilter | `f(.began, F) == .pass`, `f(.ended, F) == .pass`, `f(.m(.began), T) == .pass`, `f(.m(.changed), T) == .pass`, `f(.m(.ended), T) == .pass`; then `f(.m(.changed), T) == .pass` (no gesture known); then `f(.mayBegin, T) == .drop`, `f(.cancelled, F) == .drop`, `f(.began, F) == .pass` | R14 "The momentum that follows a scroll that was not suppressed MUST NOT be interrupted", scenario "Coasting from before is not interrupted"; design decision 11 "momentum inherits; never escalates", "momentum with no known gesture passes"; F18 (`mayBegin → cancelled` with no `began` is a gesture that closes) |
| T67 | R12 | ScrollFilter | `f(.began, T) == .drop`; `forgetGesture()`; `f(.changed, F) == .pass`. On another filter `f(.began, T) == .drop`; `forgetGesture()`; `f(.changed, T) == .passStill` | Design decision 11 "on `tapDisabledBy…` the filter forgets the gesture in progress, as `forgetHeldPresses()` does" (under-blocking is the safe direction, plan 002); a gesture seen mid-way is stilled, not dropped |
| T68 | R12 | World | switcherWorld(accessGranted: true), one world per case: (a) `thumb.land(fingers: 2).slide(byMM: (0, 10))` → `scroll(.fingers(.began)) == .drop`, `switcher == nil`; (b) `thumb.wait(4 s).land(fingers: 2)` → `scroll(.fingers(.began)) == .pass`; (c) `thumb.liftThumb().land(fingers: 2)` → `.pass`; (d) `thumb.land(fingers: 1)` → `scroll(.wheel) == .pass` and `scroll(.fingers(.began)) == .drop` | R12 scenarios "Vertical movement inside the window does not scroll" (and no switcher appears), "Scrolling returns after 3 seconds", "Thumb lifted, scrolling is normal", "Mouse wheel is never suppressed" (the wheel passes while a finger-scroll on the same flags would not) |
| T69 | R12 | World | switcherWorld (not granted): `thumb.land(fingers: 2)` → `scroll(.fingers(.began)) == nil`; continue `.slide(byMM: (3.5, 0)).slide(byMM: (12, 0))` → `switcher != nil`, `scroll(.fingers(.changed)) == nil`; `.lift()` → `broughtToFront == [Mail]`, `pressVerdicts.isEmpty` | R12 "Without the Accessibility permission, nothing is suppressed and the swipe still works", scenario "Without access, the page scrolls under the switcher"; F20 (no tap without access) |
| T70 | R13, R14 | World | switcherWorld(accessGranted: true); the design's row: `thumb.wait(4 s).land(fingers: 2).slide(byMM: (2, 0))` → `scroll(.fingers(.began)) == .pass`; `.slide(byMM: (10, 0))` → `switcher != nil`, `scroll(.fingers(.changed)) == .passStill`; `.press().slide(byMM: (12, 0)).lift()` → `pressVerdicts == [.drop, .drop]`, `scroll(.fingers(.ended)) == .passStill`, `scroll(.momentum(.began)) == .passStill`, `broughtToFront == [Slack]` | R13 scenarios "Late swipe still gets a clean switcher" (the page moves no more than the first 3 mm of finger travel scrolls it, and not at all once the switcher is up) and "Press during a late swipe is blocked" (nothing is clicked and Slack comes to the front); R14 "No coasting" after a stilled gesture; the R13 reading above |
| T71 | R13 | World | switcherWorld(accessGranted: true): `thumb.land(fingers: 2)` → `scroll(.fingers(.mayBegin)) == .drop`; `.slide(byMM: (3.5, 0)).slide(byMM: (12, 0))` → `scroll(.fingers(.changed)) == .drop`; `.lift()` → `scroll(.fingers(.ended)) == .drop`, `scroll(.momentum(.began)) == .drop`, `broughtToFront == [Mail]`; then `scroll(.fingers(.began)) == .pass` | R13 scenario "Swipe does not scroll" (before, during or after the switcher); design decision 11 "a `changed` or `ended` arriving after the lift frame has cleared the flag is still part of a gesture already decided, so nothing leaks after a swipe" (the flag is false after the lift; the `.drop` comes from the gesture's memory) |
| T72 | R13 | World | switcherWorld(accessGranted: true): `swipe(3.5, 5, lift: false)`; continue `.liftThumb().press().slide(byMM: (12, 0)).lift()` → `pressVerdicts == [.drop, .drop]`, `broughtToFront == [Mail]` | R13 scenario "Thumb lifted mid-swipe, press still blocked" (nothing is clicked and the selected app comes to the front); R13 sets aside plan 002 R4's "clicks work again once the thumb lifts" for the swipe |
| T73 | R14 | World | switcherWorld(accessGranted: true): `thumb.land(fingers: 2).slide(byMM: (0, −20))` → `scroll(.fingers(.began)) == .drop`, `scroll(.fingers(.changed)) == .drop`; `.lift()` → `scroll(.fingers(.ended)) == .drop`, `scroll(.momentum(.began)) == .drop`, `scroll(.momentum(.changed)) == .drop`, `scroll(.momentum(.ended)) == .drop`; `.liftThumb()` → `scroll(.fingers(.began)) == .pass` | R14 scenario "No coasting" (the page does not move, and does not coast after the lift); F18 (momentum begins ~7 ms after `ended`, when the fingers are gone and the flag is false) |
| T74 | R14 | World | switcherWorld(accessGranted: true), nothing touching: `scroll(.fingers(.began)) == .pass`, `scroll(.fingers(.ended)) == .pass`, `scroll(.momentum(.began)) == .pass`; play `thumb.land(fingers: 1)` → `scroll(.momentum(.changed)) == .pass`, `scroll(.momentum(.ended)) == .pass`; then `scroll(.fingers(.began)) == .drop` | R14 scenario "Coasting from before is not interrupted" (the page coasts to a stop as usual while the thumb lands); the closing `.drop` proves the flag was on while the momentum passed |
| T75 | R15 | Copy | `Copy.accessibilityHint == "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them."` | R15 (the literal); plan 002 R11 for everything else about the hint |
| T76 | R12 | TapEvent.tapMask / init | `TapEvent.tapMask` has exactly the bits {1, 2, 3, 4, 6, 7, 22, 25, 26, 27, 34}; every type in `TapEvent.tapTypes` parses to non-nil; `.mouseMoved` and `.keyDown` parse to nil; every pointer row of plan 002 T45 parses to `.pointer(…)` unchanged | `CGEventTypes.h` (`scrollWheel` = 22, F18) and plan 002 T44's bits; R12 "Pointer movement is never blocked" (no bit 5); plan 002 R9 (no keyboard); the design's closed-vocabulary rule "A test parses one synthetic event of every listed type" |
| T77 | R12, R14 | ScrollEvent.init | `CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0)` → `.wheel`, and still `.wheel` with scroll phase 1 set; with `units: .pixel`: scroll phase 128 → `.fingers(.mayBegin)`, 1 → `.began`, 2 → `.changed`, 4 → `.ended`, 8 → `.cancelled`; phase 0 with momentum phase 1 → `.momentum(.began)`, 2 → `.changed`, 3 → `.ended`; phase 0 and momentum 0 → `.unphased` | F18 (`isContinuous` 0 for a line-unit event, 1 for pixel units; `CGScrollPhase` began 1, changed 2, ended 4, cancelled 8, mayBegin 128; `CGMomentumScrollPhase` begin 1, continuous 2, end 3; momentum events carry `phase = 0`); R12 "Scrolling from a mouse wheel MUST NOT be suppressed" |
| T78 | R12, R13 | ScrollVerdict.apply | A pixel-unit event with `wheel1: −7, wheel2: 3, wheel3: 2`, scroll phase 2 set: `.passStill.apply(to:)` returns the same object (`===`), after which all nine delta fields (`DeltaAxis1–3`, `FixedPtDeltaAxis1–3`, `PointDeltaAxis1–3`) read 0, `type == .scrollWheel`, the scroll phase still reads 2 and `isContinuous` 1; before the call at least `DeltaAxis1`, `PointDeltaAxis1` and `FixedPtDeltaAxis1` were non-zero. `.pass` returns the same object with every delta unchanged; `.drop` returns nil | F18 ("zeroing `DeltaAxis1`, `PointDeltaAxis1` and `FixedPtDeltaAxis1` reads back 0/0/0.0"; "after set: scrollPhase=1" round-trips); design "Zeroing is an in-place rewrite like `passAsMove`; nothing is posted" (R9 of plan 002: never synthesise); R13 (the app's began-to-ended bracket closes with nothing moving) |
| T79 | R12 | SourcePolicyTests | `banned` holds `ScrollWheel` and not `scrollWheel`; `confined` holds `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", …)`; the parametrised scans find no `scrollWheel` outside `ClickTap.swift` and no `ScrollWheel` anywhere under the package's Sources and the app target; `confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans`, `confinedScanFindsAUseOutsideItsFile` and `coreImportsOnlyFoundationAndObservation` pass as they are | Design decision 12 "`scrollWheel` leaves `banned` and becomes `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift")`; `ScrollWheel` stays banned"; F17 (the case-sensitive overlap check; the kept-token pin does not name `scrollWheel`); plan 002's `tapCreate` precedent; the architecture's "add to its list rather than adding prose" |

### Verified without a test

Build and tool checks run from the worktree through `Scripts/test.sh` and `swift build`, with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Manual sequences run on this 14" MacBook Pro against a Debug build with Accessibility granted to that build unless the check says otherwise; "fresh install" means the settings suite removed. "Recording" means a QuickTime screen recording at 60 fps stepped frame by frame; "slow-motion film" means an iPhone at 240 fps filming the trackpad and the screen together, as plan 004 did. Safari and Finder are the pages; Mail, Slack and Notes are the listed apps unless a check names others.

- **R2 (illustration).** `ls assets/` lists `gesture-5.svg` beside `gesture-1.svg` … `gesture-4.svg`, 48×31, the thumb dot at (8, 8) and five ringed finger marks in the style of `gesture-4.svg`; it ships through `project.yml`'s `assets` resource phase with no edit to the project. Manual: open the window after a fresh install → five rows, 1 to 5 fingers top to bottom, each "Choose app…"; pick Slack in the fifth row → the row shows Slack's icon and name; a five-finger tap brings Slack to the front; select Left hand → the fifth illustration shows the thumb mark top-right. Why not a test: pixels and a resource lookup under `Bundle.main`.
- **R6, R7, R8 (feel on hardware).** With Mail, Slack, Notes listed and Safari frontmost: a slow 24 mm swipe moves the selection twice, each change with a tick clearly lighter than the gesture haptic that plays at the lift; a 5 mm hold shows the highlight between Safari and Mail; pushing 30 mm past Notes shows the highlight nudged slightly past it and springing back onto Notes when the fingers stop; the selected icon reads as slightly larger (1.12×); a swipe released on Safari is silent and nothing changes. If actuation 3 is too faint next to 6, move the tick to 4 and write it into design decision 10 (T63 keeps passing).
- **R9 "Unblocked click cancels" (hardware, access off).** Pointer over a Finder toolbar button, swipe to Slack, press the trackpad with the swiping fingers → the button is clicked, the switcher disappears, Slack does not come to the front. Why not a test: whether the click reached the button is another process's behaviour (plan 002's R8 precedent).
- **R10 (the panel).** Each scenario as written: (a) six apps listed, start a swipe → a glass panel centred on the pointer's screen with six 80 pt icons in one row, 20 pt apart, the selected one highlighted by a glass square and slightly larger, its name below; record it and step frames: the panel is on screen on the first frame after the fingers pass 3 mm with no visible delay, and after the lift it is fully gone within 12 frames (200 ms). (b) Focus: typing in a Notes text field, start a swipe and lift with Notes still selected → the caret is still in the field and `lsappinfo front` reports Notes; after ten swipes to other apps and back, Trackpad Launcher never shows as the active app. (c) Second display attached, pointer on it → the switcher appears centred on that display. (d) Safari full screen → the switcher appears over it and Slack comes to the front. (e) Light and dark appearance → the glass, the highlight and the name read correctly in both; the icons are the dark variants in dark mode after an appearance change without a relaunch (the presenter's KVO re-render). (f) Reduce motion on → the highlight follows the fingers, the selection changes, the selected icon is larger, no spring at the ends, no fade, no size animation. Also: the pointer stays live during a swipe, and a click lands through the panel after the swipe (ignoresMouseEvents). Why not a test: window-server output. Record whether `NSGlassEffectView` renders inside a `.screenSaver`-level, non-key, click-through panel and whether the glass highlight reads over glass (the design's open question); the fallback is a translucent material capsule.
- **R11 (hardware, the null row).** Access granted. (a) At S3: list only Safari, Safari frontmost, pointer over a Finder toolbar button: anchor the thumb, slide two fingers sideways → no switcher; press the trackpad with those fingers at once → the button clicks (the block ended with the reconcile); lift the fingers, keep the thumb, land two fingers and slide again → still nothing and the press still clicks; bring Slack to the front and repeat the swipe → the switcher shows Safari, Slack, and lifting opens Safari. (b) Once S4 has landed, pointer over a wide page in Safari, the same list: rest the thumb 4 s, slide two fingers sideways and keep sliding → no switcher; the page stops for the time main takes to handle the `began` and then follows the fingers again (the reconcile reinstalls the tap, so the scroll's next event reaches a fresh `ScrollFilter` with the flag down: decision 3 and the Tradeoffs bullet); record how long the stop lasts on the recording. If the page instead stays still until the fingers lift, the filter's memory survived the restart and the two sentences are wrong about the mechanism, not the other way round; either way, the next two-finger scroll after lifting scrolls at once. (c) After S4, within 3 s: anchor and slide two fingers sideways with the same list → no switcher; the gesture was dropped from its first event, so once the slide passes 3 mm and main has reconciled the page should move under a headless scroll (apps saw no `began`), the outcome the disabled-tap recovery already accepts; record whether Safari takes it cleanly or shows a stuck elastic edge or an overlay scroller that never appears. Why not a test: the real tap's restart and what an app does with a gesture whose first events were dropped.
- **R12 (hardware).** Pointer over a long page in Safari, access granted: thumb anchored and two fingers sliding up and down within 3 s → the page does not scroll and no switcher appears; thumb resting 4 s then a two-finger scroll → the page scrolls; thumb anchored then lifted, then a scroll → scrolls; pointer slides move the pointer throughout. Access off (`tccutil reset Accessibility <bundle id>`): the page scrolls sideways under a working switcher. With a wheel mouse connected (if one is available; F18 observed none): thumb anchored with a finger resting, turn the wheel → the page scrolls. With a Magic Mouse (if available; unobserved by the grounding): thumb anchored with a finger resting, scroll on the mouse → suppressed like the trackpad; record the outcome against the "Telling Magic Mouse scrolling from trackpad scrolling" non-goal.
- **R13, R14 (hardware).** Pointer over a wide page: anchor and swipe to Slack within 3 s → the page never moves and no overlay scroller flashes; rest 4 s, then swipe across three icons → the page moves at most a few points before the switcher appears and not at all after, and nothing coasts after the lift (the stilled bracket); rest 4 s, swipe to Slack, press with the swiping fingers over a button, lift → nothing clicked, Slack in front; start a swipe, lift the thumb, press over a button, lift → nothing clicked. Flick upward within 3 s and lift → the page neither moves nor coasts. Flick to start a long coast, then land the thumb in the corner → the page coasts to a stop. Touch during a coast (the design's last scroll risk): anchor the thumb, flick two fingers upward within 3 s, lift the fingers and the thumb together, and at once rest two fingers on the trackpad again → the page neither moves nor coasts; if it coasts, the dropped flick's momentum events arrived after the new gesture's `mayBegin` and the filter took them as the new, passing gesture's: record the phase sequence (the scroll-tap probe prints it) and give the filter a momentum memory per gesture before trusting R14 on that case. Why not a test: real scroll events, momentum and what an app does with zeroed deltas (the design's risk: an app that scrolls from data outside the nine delta fields would still move; if one does, map `stilled` to `.drop`).
- **R15, R24 (rendered copy).** `grep -rF "aren't blocked during gestures" LauncherKit/Sources/LauncherUI` and `grep -rF "tap with 1, 2, 3" LauncherKit/Sources/LauncherUI` find nothing (the literals live only in `Copy`), and `grep -rn "Copy.gestureHint\|Copy.accessibilityHint" LauncherKit/Sources/LauncherUI` hits `LauncherView.swift`. Manual: with gestures active and Right hand the hint reads R24's copy with "top-left" and the two marks drawn as images; Left hand → "top-right"; with access off the Accessibility hint reads R15's copy with "Grant access…".
- **R16, R21 (the section).** `ls assets/` lists `swipe.svg` (thumb mark, two finger marks, a double-headed sideways arrow, 48×31). Manual: with Mail, Slack, Notes listed, open the window → below the fifth gesture row: the swipe illustration and "Swipe to switch apps", the rows Mail, Slack, Notes with their icons and names, "Add app…", the hand-mode toggle, the divider, the hint; Left hand → the swipe illustration shows the thumb mark top-right; light and dark → the section keeps the window's glass look. Fresh install → the illustration, the title and "Add app…" only. A trashed listed app's row shows its name greyed with "not found" and the dashed-app symbol; after restoring it, reopening the window shows it normally.
- **R18 (menus).** "Add app…" opens a pull-down of the recent apps, a divider, the others, a divider, "Other…", no "None"; Mail and Slack carry a checkmark and are disabled, Notes is choosable and appends; "Other…" closes the window, activates the app, shows the file chooser accepting only applications; choosing an app in ~/Downloads appends it with its icon and name and reopens the window; choosing Slack leaves the list unchanged; a row picker's own menu still ends in "Other…" and "None" and still works. Why not a test: `NSMenu`, `NSPopUpButton` and `NSOpenPanel`.
- **R19 (remove).** Hovering Slack's row reveals a remove button at its trailing edge; clicking it leaves Mail, Notes with Notes moved up; right-clicking Notes shows a context menu with "Remove" that removes it. Why not a test: hover and context menus are AppKit events.
- **R20 (drag to reorder).** Drag Notes above Mail with the pointer: the dragged row follows the pointer, the list reads Notes, Mail, Slack on release, and the next swipe shows Notes, Mail, Slack. Do this with the app inactive (the panel is non-activating), the case design question O9 left unprobed: if the `DragGesture` does not deliver inside the key, non-activating panel, record it against decision 14 before S2 ships.
- **R22 (the height cap).** With 30 apps in the list (add them through "Other…" from /System/Applications): the window fits the visible area with its top edge under the status item; the list scrolls inside the window; the hand-mode toggle, the hint and Quit are visible and clickable; removing apps shrinks the window again (the refit on `switcherRows.count`). `grep -n "fixedSize(horizontal: true, vertical: false)" LauncherKit/Sources/LauncherUI/LauncherView.swift` hits the root, and `LauncherPanel.fitToContent` reads `min(fittingSize.height, visible.height − 16)`. Why not a test: `NSHostingView.fittingSize` and the screen; the mechanism is F36's probe.
- **R23 (reboot).** Assign Slack to the fifth gesture, order the list Notes, Mail, reboot → the fifth row shows Slack and the list reads Notes, Mail. T32 covers quit and relaunch.
- **Design mechanisms with no row.** *The run-generation gate (decision 5):* with a Magic Trackpad paired, start a swipe on the built-in trackpad and unplug the Magic Trackpad mid-swipe (a reconcile) → the switcher disappears and does not come back; the fingers still down do nothing; the next swipe works. Also by reading: `MultitouchTrackpads.run` bumps `runs` before building sessions, each `deliver` closure captures its generation, and the hop is `DispatchQueue.main.async` (documented FIFO), not `Task`. *The stuck-swipe risk:* twenty swipes released in different ways (fingers only, whole hand, thumb first, one finger first) never leave the switcher on screen or clicks blocked afterwards (a press over a button clicks within a second of the lift). *Scroll wake-ups and idle:* Activity Monitor shows the same thread count as plan 002 (the one tap thread) and 0.0 % CPU after ten minutes idle with access granted. *Recovery from a disabled tap:* pause the process in the debugger for several seconds while scrolling, resume → the next anchored swipe still stills the page and a firm tap is still blocked (the callback saw `tapDisabledByTimeout`, forgot its presses and its gesture, and re-enabled). *Icons ready before the swipe:* after a quit and relaunch, the first swipe's icons appear together with the panel on the slow-motion film; a listed app never shown at 80 pt before appears the same way; a frontmost app outside the list (a utility from /System/Applications/Utilities) appears on the first swipe from it, with the one-off cold draw noted if the film shows it. *The confined token:* T79 is the test; `grep -rn scrollWheel LauncherKit/Sources TrackpadLauncher` hits `ClickTap.swift` only. *Build:* `swift build` in Swift 6 mode with strict concurrency, the `xcodebuild` bundle, `LauncherCore` importing Foundation and Observation only (existing test), and `docs/architecture.md`, `docs/domain-model.md` and `docs/product-overview.md` reading as the design's Docs paragraph says.

## Slices

S1 is the design's named first step and the only slice that touches the recognizer's rules; it ships to hardware on its own as the five-finger gesture, with the swipe recognised but switched off. S2 lands the switcher list end to end in the window and the settings, so a person can fill the list before anything reads it, and takes the two prefactors (`AppChoice` without `.unassigned`, lazy `locate`) first. S3 turns the list and the recognised swipe into the switcher on screen. S4 adds scroll suppression in the one tap. Each slice fits a fresh context; S1 and S2 could land in either order but S2's persistence row counts five gestures.

### S1: Five fingers, and the swipe recognised on the frame thread

**What to build:** From the user's side: a five-finger tap opens its app under the same rules as the other four, the launcher window shows a fifth row with its illustration, and nothing else changes on hardware. Underneath: `Gesture.five`, with the rows, pickers and persistence keys following by construction; `Recognition.Event`, `SwipePhase`, `SwipeEvent` and the derived `fired`/`swipe` accessors; the recognizer's `.resting` and `.swiping` states, `Pair`, `Move`, the farthest-finger drag, the thumb as an optional contact of the swipe, the three named exits and `blocksClicks` true throughout a swipe, behind `init(handMode:surface:swipes:)`; `GestureRules.switcherStepMM` and `switcherMaxStretch`; `TrackpadEvent.swipe` and `TrackpadEvent(_:on:)`; `TrackpadHardware.run(_:handMode:blockClicks:swipes:)` with `reconcile()` passing `swipes: false` until S3; `DeviceSession` delivering any recognised event and `MultitouchTrackpads` hopping on the main queue gated by run generation; `Launcher.start` receiving `.swipe` and doing nothing with it yet; `InMemoryTrackpads.run(swipes:)` and `touch` delivering swipe phases inline; the `TouchScript` primitives (`land`, `slide`, `lift(_:)`, `press`, thumb re-landing) and `World.play`; `assets/gesture-5.svg`. Existing tests amended as the Strategy lists for R1, R2 and the mask-free parts.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R8 and R9 (the recognizer's half: the exits and the thumb's independence), R13 (the recognizer's half: the flag through a swipe).

**Test scenarios:** T1–T25.

- [ ] Every row is green through `Scripts/test.sh`; the no-swipe baseline tests named in the Strategy pass unchanged.
- [ ] `GestureRecognizer`'s public surface is `init(handMode:surface:swipes:)` and `step` → `Recognition`; the 3 mm, 400 ms, 3 s, 12 mm and 0.2 numbers live only in `GestureRules`.
- [ ] `MultitouchTrackpads` delivers through `DispatchQueue.main.async` with the generation guard; `grep -rn "Task {" LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` finds no per-event task.
- [ ] The R2 illustration check under Verified without a test is ticked; on hardware a five-finger tap opens its app, a thumb-anchored two-finger slide still scrolls past 3 s (swipes off), and the stuck-swipe risk is noted as not yet observable.

### S2: The switcher list in the settings and the window

**What to build:** From the user's side: the launcher window gains the switcher section below the five rows (illustration, "Swipe to switch apps", the list's rows, "Add app…"), apps can be added from a menu or through Other…, removed by hover or context menu, reordered by dragging, the window grows and caps at the screen with the list scrolling, and the list and the fifth assignment survive relaunch and reboot; old settings records still load. Underneath, prefactors first: `AppChoice` loses `.unassigned` and `setAssignment(_:for:)` takes an optional (five call sites); `AppCatalog.locate` consults registered copies lazily. Then `SwitcherList`, `Settings.switcherList` with the hand-written tolerant `init(from:)`, `SwitcherRow` and `Launcher.switcherRows` resolved with `rows`, the three intents (`addToSwitcher`, `removeFromSwitcher`, `moveInSwitcher`) saving and resolving; `PickerItem.app(_, state:)` with `AppItemState` and `InstalledApps.addMenu(listing:)`; `AppMenuButton` in its `.popUp` and `.pullDown` forms over one coordinator, `LauncherActions.chooseOtherApp(then:)`, `SwitcherSection`, `SwitcherListRow` with the hover remove button, the context menu and the `DragGesture` reorder, `LauncherView`'s root `fixedSize` horizontal-only, `LauncherPanel.fitToContent`'s height cap and `MenuBarShell`'s refit on the list's count; `assets/swipe.svg`; `Fixtures.recordSavedByPlan002`.

**Blocked by:** S1 (the fifth gesture that R23's row assigns; the five-row counts).

**Requirements:** R16, R17 (the rows), R18, R19, R20 (the list order; the next swipe is S3), R21, R22, R23.

**Test scenarios:** T26–T34.

- [ ] Every row is green; `grep -rn "\.unassigned" LauncherKit/Sources` hits only `RowApp` and `PickerItem`.
- [ ] `Launcher`'s intents are the only writers of `settings.switcherList`; `reconcile()` still passes `swipes: false`, so hardware behaves as after S1.
- [ ] The R16, R18, R19, R20, R21, R22 and R23 (reboot) checks under Verified without a test are ticked; the O9 drag outcome is recorded in the plan.
- [ ] A record saved by the build before this slice loads with its assignments and an empty list (T33), checked once by hand against a real pre-slice suite.

### S3: The switcher on screen

**What to build:** From the user's side: with the thumb anchored, sliding two fingers sideways shows the switcher, the highlight follows the fingers with a light tick per icon, lifting brings the selected app to the front with the gesture haptic and closes the window, a third finger or an unblocked click cancels, the thumb may lift or re-land, and nothing shows when there is nothing to switch to or gestures are inactive; the hint names five fingers and the swipe. Underneath: `Switcher` (the row rule, home, nearest icon, position, bounded stretch); `SystemActions.frontmostApp()` with `WorkspaceActions` reading `NSWorkspace` and excluding itself, and `RecordingSystemActions.frontmost`; `Haptic` with `playFeedback(_:on:)`, `MultitouchTrackpads.actuation(for:)` and `InMemoryTrackpads.pulses`; `Launcher.switcher`, `swipe(_:)` as the one place a swipe becomes effects, `reconcile()` clearing the switcher and passing `swipes: !settings.switcherList.isEmpty`, the list intents reconciling only when emptiness flips, and `swipe(.began)` reconciling when it yields no switcher (a list of only missing apps or only the frontmost app, or no readable frontmost app), so the fresh recognizer spoils under the resting hand and nothing stays blocked; `Copy.gestureHint(for:)` and `LauncherView` reading it; `SwitcherPresenter` and `SwitcherPanel` (the launch overlay's panel configuration around glass, 80 pt icon layers 20 pt apart, the 92 pt glass highlight, the name, the keyed additive spring on stretch, the 150 ms fade, Reduce motion), `AppIcons(side:)` with the presenter's 80 pt instance re-rendered on list and appearance changes and the running app's icon for the frontmost; `MenuBarShell` owning the presenter; `World.makeFrontmost`, `World.swipe`, `World.switcherWorld`; the glossary and architecture sentences already in the working tree that describe the swipe and the switcher.

**Blocked by:** S1 (the recognised swipe), S2 (the list).

**Requirements:** R3 (the drift scenarios through the app), R4, R5, R6, R7, R8, R9, R10, R11, R17 (order matches), R20 (the next swipe), R23 (the swipe after relaunch), R24.

**Test scenarios:** T35–T63.

- [ ] Every row is green and synchronous; `launcher.switcher` has one writer besides `reconcile()`; no `Timer`, `asyncAfter`, `Task.sleep` or display link appears in shipped sources.
- [ ] `SwitcherPanel` is never key, never activating and click-through (its configuration matches F26 line for line, with `canBecomeKey` false); the presenter holds nothing the model holds.
- [ ] The R6–R8 feel check, the R9 click check, every R10 check, the R11 null-row check (a), the R24 rendered copy, and the design-mechanism checks for the generation gate, the stuck-swipe risk and icons-before-the-swipe under Verified without a test are ticked; the actuation chosen for the tick and the glass-on-glass outcome are written into the design.
- [ ] The architecture's Concurrency sentence and the glossary's *Gesture*, *Tap*, *Swipe*, *Switcher*, *Switcher list*, *Frontmost app*, *Launcher window*, *Feedback* and *Light tick* entries are committed with this slice.

### S4: Scroll suppression in the one tap

**What to build:** From the user's side: with access granted, trackpad scrolling is suppressed under the click-blocking rule and for the whole of a swipe, its momentum with it, a wheel mouse is never suppressed, scrolling that was already coasting is left alone, and the Accessibility hint says so. Underneath: `ScrollEvent`, `ScrollVerdict` and the pure `ScrollFilter` in core; `TapEvent` as the one parse of a `CGEvent` with `.scrollWheel` in the mask, `ScrollEvent(_:)`, `ScrollVerdict.apply(to:)` zeroing the nine delta fields in place; `ClickTap` keeping a `Mutex<ScrollFilter>` beside the click filter, reading the flag once before either lock, and forgetting both on a disabled tap; `SourcePolicyTests` moving `scrollWheel` to `confined` under `ClickTap.swift`; `InMemoryTrackpads` arming a `ScrollFilter` with the click filter and `scroll(_:)`; `Copy.accessibilityHint` and `LauncherView` reading it; `PointerEventTests` becoming `TapEventTests`; the glossary's scrolling sentences, the architecture's Privacy sentence and the product overview edits already in the working tree.

**Blocked by:** S3 (the swipe the late-swipe rows ride on; `switcherWorld`).

**Requirements:** R12, R13 (the tap's half), R14, R15.

**Test scenarios:** T64–T79.

- [ ] Every row is green; T79's confinement has its only real hits in `ClickTap.swift`; `ClickFilter`, `PointerEvent` and `PointerVerdict` are unchanged (`git diff` on `ClickFilter.swift` is empty).
- [ ] `ClickTap.handle` reads `anyTrackpadBlocksClicks()` once and never holds both filter locks at once.
- [ ] The R12, R13, R14 and R15 checks, the touch-during-a-coast probe with its phase sequence recorded against the design's risk, the R11 null-row scroll checks (b) and (c) with their outcome recorded against the Tradeoffs bullet, and the scroll wake-up, idle and disabled-tap recovery checks under Verified without a test are ticked with access granted; a wheel mouse and a Magic Mouse are tried if available and the outcome recorded; if an app still scrolls under `.passStill`, `stilled` is mapped to `.drop` and the design updated.
- [ ] The remaining doc sentences the design's Docs paragraph names, already in the working tree (the glossary's *Click blocking*, *Blocking window* and *Accessibility hint* scrolling sentences, the architecture's Privacy sentence, the product overview's haptic exception), are committed with this slice; the plan-text amendments (plan 002 R9, plan 001 R11's bullet) are already in the Solution.
