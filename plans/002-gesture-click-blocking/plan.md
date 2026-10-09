# Plan: Click blocking and forgiving taps

## Problem statement

Tap to click must be off for gestures to work. So a firm tap during a gesture becomes a real press. A firm 1-finger tap clicks whatever is under the pointer. A firm 2-finger tap opens a context menu. The press also cancels the gesture, so the user gets the unwanted click and no app.

3-finger and 4-finger gestures sometimes do nothing. A tap counts only if the first finger landing and the last finger lifting fall within 300 ms. Fingers of a natural 3 or 4-finger tap land unevenly and often miss that window. A finger that lifts before the last one lands also drops out of the count. A 4-finger tap can then fire the 3-finger gesture.

## Solution

Trackpad Launcher asks for the Accessibility permission on first launch. With it, clicks are blocked for the first 3 seconds after the thumb lands in the anchor corner. A firm tap in that window opens the app instead of clicking. Without it, gestures work as before, and the launcher window shows a hint with a button to grant access.

Blocking has a time window so a thumb resting in the corner never disables clicking for long. 3 seconds is long enough for a few taps in a row and short enough to recover from.

Taps get more forgiving. The time limit grows from 300 ms to 400 ms. Every finger that touches during the tap counts, even if it lifted before another landed. The app still opens the moment the fingers lift.

This plan changes the plan in `plans/001-trackpad-launcher-app/plan.md`. Its R11 finger count, tap duration and press rule are replaced by R1, R2 and R8 here; R3 restates R11's fire-on-lift rule to rule out any wait. Its R20 "No permissions" is replaced by R9 here. The reason in its non-goal "Working with Tap to click on" no longer holds, because the app now asks for one permission.

## Requirements

### R1. Every finger that touches counts
A tap begins when a non-thumb finger lands while no other non-thumb finger is down, and ends when the last non-thumb finger lifts. The finger count of a tap MUST be the number of distinct non-thumb fingers that touched during the tap, whether or not they were down at the same moment. A finger that lifts and lands again within the same tap MUST count once. A tap with more than four distinct fingers MUST NOT fire a gesture.

#### Scenario: Early finger lifts before the last lands
- **GIVEN** the 4-finger gesture is assigned to Spotify and the 3-finger gesture to Notion
- **WHEN** the user anchors the thumb and taps with four fingers, and the first finger lifts before the fourth lands, all within 400 ms
- **THEN** Spotify comes to the front and Notion does not

#### Scenario: Five fingers in a rolling tap
- **GIVEN** all four gestures are assigned
- **WHEN** the user anchors the thumb and five fingers touch one after another within 400 ms, never more than four at once
- **THEN** nothing happens

#### Scenario: Two quick 1-finger taps
- **GIVEN** the 1-finger gesture is assigned to Arc and the 2-finger gesture to Figma
- **WHEN** the user anchors the thumb, taps with one finger, lifts, and taps again with one finger 200 ms later
- **THEN** Arc comes to the front twice and Figma never does

#### Scenario: Bouncing finger counts once
- **GIVEN** all four gestures are assigned and the 4-finger gesture is assigned to Spotify
- **WHEN** the user anchors the thumb and taps with four fingers, and one finger briefly lifts and lands again within the tap
- **THEN** Spotify comes to the front

### R2. A tap may last up to 400 ms
A tap that meets the other gesture rules MUST fire when its first finger landing and last finger lifting are no more than 400 ms apart. A tap longer than 400 ms MUST NOT fire, and no new tap begins until every non-thumb finger has lifted.

#### Scenario: Uneven 3-finger tap
- **GIVEN** the 3-finger gesture is assigned to Notion
- **WHEN** the user anchors the thumb, three fingers land over 150 ms, and the last lifts 350 ms after the first landed
- **THEN** Notion comes to the front exactly once

#### Scenario: Too slow
- **GIVEN** the 2-finger gesture is assigned to Figma
- **WHEN** the user anchors the thumb and holds two fingers down for 500 ms before lifting
- **THEN** nothing happens

### R3. Gestures fire the moment the fingers lift
A gesture MUST fire on the lift of its last finger, with no added wait for further fingers.

#### Scenario: No delay after lift
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb and taps with one finger
- **THEN** the haptic pulse plays as the finger lifts and Arc comes to the front with no added wait

### R4. Clicks are blocked for 3 seconds after the thumb anchors
While Trackpad Launcher has the Accessibility permission and gestures are active, trackpad clicks MUST be blocked for the first 3 seconds after a thumb becomes anchored, while that thumb stays anchored and while at least one other finger is on the trackpad. Clicks are left-clicks, right-clicks and Force Clicks. A press made while the anchored thumb is the only touch MUST pass, so pressing with the thumb or a lone finger in the corner still clicks. Once the thumb lifts or leaves the anchor corner, clicks MUST work again at once. After the 3 seconds, clicks MUST work again even with the thumb still anchored.

#### Scenario: Firm 1-finger tap does not click
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user anchors the thumb and firmly taps with one finger within 3 seconds
- **THEN** the button is not clicked

#### Scenario: Firm 2-finger tap does not open a context menu
- **GIVEN** access is granted and the pointer is over a file in Finder
- **WHEN** the user anchors the thumb and firmly taps with two fingers within 3 seconds
- **THEN** no context menu opens

#### Scenario: Force Click does not Look up
- **GIVEN** access is granted and the pointer is over a word
- **WHEN** the user anchors the thumb and force-presses with one finger within 3 seconds
- **THEN** no Look up appears

#### Scenario: Clicks return after 3 seconds
- **GIVEN** access is granted
- **WHEN** the user rests the thumb in the anchor corner for 4 seconds, then presses the trackpad with one finger over a button
- **THEN** the button is clicked

#### Scenario: Clicks return when the thumb lifts
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb, lifts it after 1 second, then clicks a button
- **THEN** the button is clicked

#### Scenario: Thumb slides out
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb, slides it out of the anchor corner, then presses with one finger over a button
- **THEN** the button is clicked

#### Scenario: Lone finger in the corner still clicks
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** only one finger is on the trackpad, resting in the anchor corner, and the user presses
- **THEN** the button is clicked

#### Scenario: Ordinary click
- **GIVEN** access is granted and nothing touches the anchor corner
- **WHEN** the user presses with one finger over a button
- **THEN** the button is clicked

#### Scenario: No blocking while gestures are inactive
- **GIVEN** access is granted and *Tap to click* is on
- **WHEN** the user rests the thumb in the anchor corner and clicks a button
- **THEN** the button is clicked

### R5. A press is blocked or passed as a whole
The press-down and the release of one press MUST both be blocked or both be passed.

#### Scenario: Thumb lands during a drag
- **GIVEN** access is granted and the user is dragging a window with a press held
- **WHEN** the thumb lands in the anchor corner during the drag
- **THEN** the drag continues and ends normally on release

#### Scenario: Press across the 3-second mark
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user anchors the thumb, presses with one finger 2.9 seconds later and releases at 3.1 seconds
- **THEN** the whole press is blocked and nothing is clicked

### R6. Pointer, scrolling and mouse are never blocked
Pointer movement, scrolling and clicks from a mouse MUST NOT be blocked.

#### Scenario: Pointer still moves
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb and slides one finger across the trackpad
- **THEN** the pointer moves as usual

#### Scenario: Scrolling still works
- **GIVEN** access is granted and the pointer is over a long page
- **WHEN** the user anchors the thumb and scrolls with two fingers
- **THEN** the page scrolls

#### Scenario: Mouse clicks still work
- **GIVEN** access is granted and a mouse is connected
- **WHEN** the user rests the thumb in the anchor corner and clicks a button with the mouse in the other hand
- **THEN** the button is clicked

### R7. Blocking follows the permission live
Click blocking MUST start within 5 seconds of access being granted and stop within 5 seconds of it being revoked, with no relaunch.

#### Scenario: Granting starts blocking
- **GIVEN** access is not granted
- **WHEN** the user turns Trackpad Launcher on under Accessibility, then 5 seconds later anchors the thumb and firmly taps with one finger over a button
- **THEN** the button is not clicked, without relaunching the app

#### Scenario: Revoking stops blocking
- **GIVEN** access is granted
- **WHEN** the user turns Trackpad Launcher off under Accessibility, then 5 seconds later anchors the thumb and firmly taps with one finger over a button
- **THEN** the button is clicked, without relaunching the app

### R8. A blocked press counts as a tap
While clicks are blocked (R4), a press during a tap MUST NOT cancel it, and the tap MUST fire its gesture under the usual rules. When clicks are not blocked, a press MUST cancel the tap, as today.

#### Scenario: Firm tap opens the app
- **GIVEN** access is granted and the 2-finger gesture is assigned to Figma
- **WHEN** the user anchors the thumb and firmly taps with two fingers within 3 seconds, pressing the trackpad down
- **THEN** Figma comes to the front, nothing is right-clicked, and the gesture's haptic plays as for a light tap

#### Scenario: Press and hold does nothing
- **GIVEN** access is granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb, presses with one finger, holds for 1 second and releases
- **THEN** nothing is clicked and Arc does not come to the front

#### Scenario: Without access, a press stays a click
- **GIVEN** access is not granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb and presses the trackpad down with one finger over a button
- **THEN** the button is clicked and Arc does not come to the front

#### Scenario: After 3 seconds, a press stays a click
- **GIVEN** access is granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user rests the thumb for 4 seconds, then presses the trackpad down with one finger over a button
- **THEN** the button is clicked and Arc does not come to the front

### R9. Accessibility is the only permission, and it is optional
Trackpad Launcher MUST NOT ask for any permission other than Accessibility. Every feature except click blocking MUST work without it. With access granted, the app MUST use it only to block clicks as described here. It MUST NOT read, record or change keyboard input or any other event.

#### Scenario: Declined
- **GIVEN** the user declined Accessibility
- **WHEN** they assign an app and perform its gesture
- **THEN** the app comes to the front, and clicks are not blocked

#### Scenario: No other prompts
- **WHEN** a user installs the app, dismisses the Accessibility prompt, assigns an app and performs its gesture
- **THEN** no other permission prompt appears and the gesture works

### R10. First launch asks for Accessibility
On first launch Trackpad Launcher MUST show the system's Accessibility prompt once, unless access is already granted. Once the prompt is dismissed, the launcher window MUST be open, showing the Accessibility hint if access was not granted. Later launches MUST NOT show the prompt.

#### Scenario: First launch
- **WHEN** the user opens the app for the first time and dismisses the Accessibility prompt without granting access
- **THEN** the launcher window is open and shows the Accessibility hint

#### Scenario: Second launch
- **GIVEN** the user dismissed the prompt on first launch
- **WHEN** the app starts at login
- **THEN** no prompt appears

### R11. Accessibility hint in the launcher window
While access is not granted, the launcher window MUST show a hint below the gesture hint or the trackpad settings notice. The hint reads "Clicks aren't blocked during gestures. Allow Accessibility access to block them." and has a "Grant access…" button. The button MUST open System Settings > Privacy & Security > Accessibility. The hint MUST disappear within 5 seconds of access being granted and come back within 5 seconds of it being revoked, with no relaunch. The menu bar icon MUST NOT change because of the permission.

#### Scenario: Hint while not granted
- **GIVEN** access is not granted and gestures are active
- **WHEN** the user opens the launcher window
- **THEN** the hint and the "Grant access…" button are shown, and the menu bar icon shows gestures as active

#### Scenario: Button opens the right pane
- **WHEN** the user clicks "Grant access…"
- **THEN** System Settings opens on Privacy & Security > Accessibility

#### Scenario: Granting removes the hint live
- **GIVEN** the window shows the hint
- **WHEN** the user turns Trackpad Launcher on under Accessibility and opens the window again 5 seconds later
- **THEN** the hint is gone, without relaunching the app

#### Scenario: Revoking brings the hint back
- **GIVEN** access is granted
- **WHEN** the user turns Trackpad Launcher off under Accessibility and opens the window 5 seconds later
- **THEN** the hint is shown, without relaunching the app

#### Scenario: Hidden when granted
- **GIVEN** access is granted
- **WHEN** the user opens the launcher window
- **THEN** no Accessibility hint is shown

## Non-goals

- **Blocking the pointer or scrolling.** Freezing the pointer whenever the thumb rests in the corner would feel broken, and taps barely move it.
- **Detecting a gesture before its click.** A press arrives before the fingers lift, so the app cannot know in time that it is a tap. Blocking keys off the anchored thumb instead.
- **A grace period after the last finger lifts.** The user wants apps to open instantly. A late finger that lands after all others lifted starts a new tap.
- **Tuning other gesture rules.** The anchor corner size and the drag threshold stay as they are.
- **Recording real taps to fit the timing.** The user chose to try 400 ms first.
- **A setting to turn click blocking off.** Declining or revoking Accessibility already turns it off.
- **Feedback when a click is blocked.** Blocked clicks are silent. The gesture's own haptic is the feedback.
- **Changing the 3-second window.** It is fixed, like the other gesture rules.
- **Prompting installs that already launched an earlier build.** The prompt appears only on first launch. Such installs see only the hint.
