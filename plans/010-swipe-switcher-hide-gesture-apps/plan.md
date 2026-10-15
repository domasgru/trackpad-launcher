# Plan: Switcher hides apps that have a gesture

## Problem statement

The user reaches their most used apps with the five tap gestures. The switcher still lists those apps among the running apps. They take slots the user never needs there, push other apps further right, and add travel to every swipe. Apps without a gesture can even fall off the 10-icon row.

## Solution

The user starts a swipe when they hold the thumb in the anchor corner and slide two fingers sideways. The switcher leaves out every running app that a gesture is assigned to. The app in front stays at the left end as before, so lifting there still changes nothing. The freed slots go to the next most recently used running apps without a gesture, so the row still holds up to 10 icons. Nothing else changes: the swap, the gestures and the launcher window behave as today. There is no switch for this; it is always on. The switcher's description in the product overview and in the domain model's Switcher entry changes to say the row leaves out apps that have a gesture.

## Requirements

### R1. The switcher leaves out apps that have a gesture
When a swipe begins, the switcher's row MUST leave out every running app that any of the five gestures is assigned to, except the frontmost app. An assignment still hides its app when the app can no longer be found on disk.

#### Scenario: Assigned app is left out
- **GIVEN** Safari, Mail, Notes and Music are running, Notes is in front, Mail was used just before it, and the 2-finger gesture is assigned to Mail
- **WHEN** the user starts a swipe
- **THEN** the row shows Notes, then Safari and Music in their ⌘-Tab order, and Mail does not appear

#### Scenario: Lifting after a hidden app opens the right one
- **GIVEN** Safari, Mail, Notes and Music are running, Notes is in front, Mail was used just before it, and the 2-finger gesture is assigned to Mail
- **WHEN** the user slides to the second icon and lifts
- **THEN** Safari comes to the front with the gesture haptic, and Mail stays where it was

#### Scenario: Every gesture's assignment counts
- **GIVEN** five running apps are each assigned to a different gesture, from the 1-finger gesture to the 5-finger gesture, and three other running apps have no gesture
- **WHEN** the user starts a swipe from one of the three
- **THEN** the row shows only those three apps

#### Scenario: Unassigned gestures hide nothing
- **GIVEN** every gesture is unassigned
- **WHEN** the user starts a swipe
- **THEN** the row shows the frontmost app, then the other running apps from most to least recently used, up to 10 icons

#### Scenario: An app moved to the Trash stays hidden
- **GIVEN** Notes is assigned to the 3-finger gesture and is running, and the user moves Notes to the Trash without quitting it
- **WHEN** the user starts a swipe
- **THEN** Notes does not appear in the row

### R2. The frontmost app keeps its place
The frontmost app MUST stay at the left end of the row, with the selection starting on it, even when a gesture is assigned to it.

#### Scenario: Frontmost app has a gesture
- **GIVEN** Safari is in front and assigned to the 1-finger gesture
- **WHEN** the user starts a swipe
- **THEN** Safari sits at the left end with the selection on it
- **AND** lifting on Safari does nothing and is silent

#### Scenario: Two assigned apps, one in front
- **GIVEN** Safari is in front and assigned to the 1-finger gesture, and Mail is running and assigned to the 2-finger gesture
- **WHEN** the user starts a swipe
- **THEN** Safari is at the left end and Mail is not in the row

### R3. Freed slots go to the next apps without a gesture
After the frontmost app, the row MUST hold the most recently used running apps that have no gesture, in ⌘-Tab order, up to 9 of them, so it has 10 icons whenever enough such apps are running.

#### Scenario: Row refills to 10
- **GIVEN** 14 running apps besides the frontmost app, three of the 9 most recent assigned to gestures, and the other 11 have no gesture
- **WHEN** the user starts a swipe
- **THEN** the row shows 10 icons: the frontmost app and the 9 most recent apps without a gesture, including the 10th, 11th and 12th most recently used

#### Scenario: Fewer apps than slots
- **GIVEN** 6 running apps besides the frontmost app, 2 of them assigned to gestures
- **WHEN** the user starts a swipe
- **THEN** the row shows 5 icons: the frontmost app and the 4 apps without a gesture

### R4. Nothing left to switch to
When no running app without a gesture is left to switch to, besides the frontmost app if there is one, the swipe MUST behave as it does today with nothing to switch to: no switcher shows, and the swipe still blocks clicks and scrolling until the fingers lift.

#### Scenario: Only assigned apps are running besides the front one
- **GIVEN** Notes is in front, and the only other running apps are Safari and Mail, both assigned to gestures
- **WHEN** the user starts a swipe
- **THEN** no switcher appears, clicks and scrolling stay blocked until the fingers lift, and lifting is silent

### R5. No frontmost app
When there is no frontmost app, as while Trackpad Launcher itself is active, the row MUST be the running apps without a gesture alone, up to 10, with the selection on the most recently used one.

#### Scenario: Trackpad Launcher is active
- **GIVEN** Trackpad Launcher is active, Safari is the most recently used running app and assigned to the 1-finger gesture, and Notes is the next most recent with no gesture
- **WHEN** the user starts a swipe
- **THEN** Safari is not in the row, and the selection starts on Notes

#### Scenario: Trackpad Launcher is active and every running app has a gesture
- **GIVEN** Trackpad Launcher is active and every other running app is assigned to a gesture
- **WHEN** the user starts a swipe
- **THEN** no switcher appears and lifting is silent

### R6. Assignments are read when the swipe begins
The row MUST use the assignments in place when the swipe begins.

#### Scenario: Assignment added between swipes
- **GIVEN** Mail is running with no gesture and appears in the switcher
- **WHEN** the user assigns Mail to the 4-finger gesture and starts a new swipe
- **THEN** Mail is not in the row

#### Scenario: Assignment cleared between swipes
- **GIVEN** Mail is running and assigned to the 4-finger gesture
- **WHEN** the user sets the 4-finger gesture to None and starts a new swipe
- **THEN** Mail appears in the row in its ⌘-Tab place

### R7. The swap still reaches apps that have a gesture
A swap MUST still target the most recently used running app other than the frontmost app, whether or not a gesture is assigned to it.

#### Scenario: Swap still reaches an assigned app
- **GIVEN** Notes is in front, Mail was used just before it, and Mail is assigned to the 2-finger gesture
- **WHEN** the user rests two fingers and taps the thumb in the anchor corner
- **THEN** Mail comes to the front

### R8. No new control
The launcher window MUST gain no control for this behaviour.

#### Scenario: No new switch
- **WHEN** the user opens the launcher window
- **THEN** the switcher section shows the swipe switch and the swap switch and no other control

## Non-goals

- **Hiding apps from the swap.** The swap is a quick toggle back to the last app, which is often one opened by a gesture. The user asked to change the switcher only.
- **A switch to turn this off.** The user wants it always on for now. A switch can follow if needed.
- **Showing the hidden apps elsewhere in the switcher.** They are left out, not shown in another section.
- **Hiding apps for any reason other than an assignment.** Only gesture assignments decide what the switcher leaves out.

## Plan files

- `design.md`: the implementation decisions (identity by bundle identifier, the Switcher's new argument, the model reading the set at the swipe's beginning, what stays untouched, the documents) and further notes.
- `testing.md`: the strategy (one seam, `Launcher` through `World`), the test scenarios T1–T10, and R8 verified without a test.
- `slices/S1.md`: the one slice, delivering every requirement.
- `development-logs.md`: what each review round found and what changed.
