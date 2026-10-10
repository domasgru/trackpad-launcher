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

This plan amends earlier plans. Plan 001: R3 and R4 (four gesture rows) become five rows plus the switcher section (R2, R16 here); R11's scenario "Drag is not a tap" is replaced by R3 and R12 to R14 here; the non-goal "Gestures beyond the four" no longer holds. Plan 002: R1's "more than four distinct fingers" becomes "more than five" (R1 here); R4's blocking window is extended for the whole of a swipe, and its "clicks work again once the thumb lifts" does not apply during a swipe (R13 here); R6's scrolling sentence and its "Scrolling still works" scenario are replaced by R12 to R14 here; R11's hint copy is replaced by R15 here. `docs/product-overview.md` changes in three places: the four gestures become five tap gestures plus the swipe; the haptic rule gains one exception, a swipe released on the frontmost app is silent; the sound effect stays deferred. `docs/domain-model.md` gains the terms above, and its *Gesture*, *Tap*, *Launcher window*, *Click blocking* and *Blocking window* entries follow this plan.

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
- **GIVEN** the 3-finger gesture is assigned to Notion and Safari is frontmost
- **WHEN** the user anchors the thumb and taps with three fingers, and one of the first two fingers skids 4 mm sideways before the third lands
- **THEN** the switcher appears and disappears, no app comes to the front and no haptic plays (a finger that drags more than 3 mm already ended the tap under plan 001's drag rule, so no tap that fired before is lost)

#### Scenario: Two-finger tap that drifts
- **GIVEN** the 2-finger gesture is assigned to Figma and Safari is frontmost
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

- **Flick or momentum in the switcher.** The selection follows finger travel only; a fast swipe moves no further than a slow one of the same length.
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
