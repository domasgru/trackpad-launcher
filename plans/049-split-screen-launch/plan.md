# Plan: Split gesture: two apps side by side

## Problem statement

A gesture brings one app to front. Users who work in two apps at once, such as an editor and a browser, must bring each app to front separately. Then they arrange the two windows by hand, through the green button's menu or by dragging. Each time, that takes several steps.

## Solution

A gesture can hold a second app. In the gesture's row, a plus button next to the app picker opens the same app menu. The app picked there becomes the gesture's second app. The row then shows both apps, one under the other, with a minus button that removes the second app. When the gesture fires, both apps come to front. The first app's front window fills the left half of the display, and the second app's fills the right half.

## Design reference

The Figma file is not reachable by every reader, so this section records it in full. Screenshots: `plans/049-split-screen-launch/design/one-app-row-with-plus.png` and `plans/049-split-screen-launch/design/two-app-row-with-minus.png`.

Both mockups show a gesture row: 326 pt wide, 10 pt horizontal padding, a 0.5 pt bottom divider in `rgba(0,0,0,0.05)`. The gesture illustration (45 × 28 pt) sits at the leading edge, vertically centred. Everything else sits at the trailing edge.

**Row with one app** (Figma node `2231:13433`, row 48 pt tall, 16 pt vertical padding). The trailing group is one line, 16 pt tall, with 12 pt between items:

1. The app picker as it is today: the app icon (16 pt) and, 6 pt after it, the app name (SF Pro Medium 13 pt, 16 pt line, `rgba(0,0,0,0.85)`); then the chevrons (`chevron.up.chevron.down`, SF Pro Bold 10 pt) in a 16 pt round badge filled `rgba(0,0,0,0.08)`.
2. The plus button: SF Symbol `plus.circle.fill`, 16 × 16 pt, grey like the badge.

**Row with two apps** (Figma node `2231:13407`, row 78 pt tall, 15 pt vertical padding). The trailing group is a column of two lines, right-aligned, 16 pt apart; each line is 16 pt tall with 12 pt between items:

1. Line 1: the first app's picker (icon, name, chevron badge), as above. No plus button.
2. Line 2: the minus button, SF Symbol `minus.circle.fill`, 16 × 16 pt, grey; then the second app's picker (icon, name, chevron badge).

The two pickers' trailing edges line up. The illustration stays vertically centred in the taller row. The two-app mockup shows Notes on both lines as filler; real use never holds one app twice.

Colours follow the existing picker's system colours, in light and in dark appearance. Each picker is at most 128 pt wide, and a long name is cut short at the end, as today. The plus button's tooltip and accessibility label is "Add a second app"; the minus button's is "Remove the second app".

## Glossary

These terms join `docs/domain-model.md`:

- **First app**: the app an assignment has always held, chosen in the gesture row's first picker.
- **Second app**: an optional extra app in an assignment, chosen through the plus button. Only an assignment with a first app can hold one.
- **Split gesture**: a gesture whose assignment holds a first app and a second app.
- **Front window (of an app)**: the window the app shows in front of its other windows. When that is a sheet or a panel, it is the window the sheet or panel belongs to. A minimised window is restored first.
- **Split to front**: what a split gesture does: bring both apps to front and place their front windows side by side on the display under the pointer.

## Requirements

### R1. The plus button shows only for a gesture with exactly one app
A gesture row MUST show the plus button to the right of its picker when the gesture has a first app and no second app. It MUST NOT show it when the gesture is unassigned or already has a second app. A row whose first app is missing MUST still show the plus button.

#### Scenario: Plus button on a one-app gesture
- **GIVEN** the 2-finger gesture is assigned to Music, with no second app
- **WHEN** the user opens the settings window
- **THEN** the 2-finger row shows Music's picker and, to its right, the plus button

#### Scenario: No plus button on an unassigned gesture
- **GIVEN** the 3-finger gesture is unassigned
- **WHEN** the user opens the settings window
- **THEN** the 3-finger row shows its picker with no plus button

#### Scenario: Plus button with a missing first app
- **GIVEN** the 2-finger gesture is assigned to Music, with no second app, and Music was moved to the Trash
- **WHEN** the user opens the settings window
- **THEN** the 2-finger row shows Music's name greyed and, to its right, the plus button

### R2. The plus button opens the app menu for the second app
Pressing the plus button MUST open the same menu the picker shows, with the first app disabled (R5): the recent apps, the other installed apps, *Other…* and *None*. Picking an app there MUST make it the gesture's second app. Picking *None* there MUST change nothing, exactly like closing the menu. Picking an app through the plus button MUST play the pick animation on the new second picker's icon.

#### Scenario: Adding a second app
- **GIVEN** the 2-finger gesture is assigned to Notes, with no second app
- **WHEN** the user presses the plus button and picks Safari
- **THEN** the row shows Notes on its first line and, on a second line, the minus button and Safari's picker
- **AND** the plus button is gone

#### Scenario: Adding a second app through Other…
- **GIVEN** the 2-finger gesture is assigned to Notes, with no second app
- **WHEN** the user presses the plus button, picks *Other…* and chooses an app in ~/Downloads
- **THEN** that app becomes the second app

#### Scenario: Cancelling the menu
- **WHEN** the user presses the plus button and closes the menu without picking
- **THEN** the gesture still has no second app and the row is unchanged

### R3. A row with a second app shows both apps
A gesture row with a second app MUST show two lines at its trailing edge, laid out as the design reference describes: the first app's picker on top, and under it the minus button followed by the second app's picker. The settings window MUST resize to fit the taller row.

#### Scenario: Two-app row layout
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user opens the settings window
- **THEN** the 1-finger row is 78 pt tall, where a one-app row is 48 pt
- **AND** it shows Notes's picker on line 1, and the minus button then Safari's picker on line 2, both right-aligned, the two pickers' trailing edges lined up
- **AND** the settings window is taller by the difference, 30 pt

### R4. The second picker changes the second app
The second app's picker MUST list what the first picker lists, *None* included. Picking an app there MUST replace the second app. Picking *None* there MUST change nothing, exactly like closing the menu. Picking an app MUST play the pick animation on the second picker's icon.

#### Scenario: Replacing the second app
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user picks Mail in the second picker
- **THEN** the gesture holds Notes and Mail, and the second picker's icon plays the pick animation

#### Scenario: None in the second picker is a no-op
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user picks *None* in the second picker
- **THEN** the gesture still holds Notes and Safari, and nothing animates

### R5. The first app cannot be picked as the second app
In the second app's menu, opened from the plus button or the second picker, the first app MUST be shown disabled. Picking the first app through *Other…* as the second app MUST change nothing.

#### Scenario: First app disabled in the second menu
- **GIVEN** the 1-finger gesture is assigned to Notes
- **WHEN** the user presses the plus button
- **THEN** Notes shows disabled in the menu and cannot be picked

#### Scenario: First app chosen through Other…
- **GIVEN** the 1-finger gesture is assigned to Notes, with no second app
- **WHEN** the user presses the plus button, picks *Other…* and chooses Notes
- **THEN** the gesture still holds Notes only, and the row is unchanged

### R6. The minus button removes the second app
Pressing the minus button MUST remove the second app. The row MUST return to one line with the plus button, and the window MUST resize to fit.

#### Scenario: Removing the second app
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user presses the minus button
- **THEN** the gesture holds Notes only, and the row shows Notes's picker and the plus button

### R7. None on the first picker clears both apps
Picking *None* on the first picker of a split gesture MUST make the gesture unassigned, clearing both apps.

#### Scenario: Unassigning a split gesture
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user picks *None* in the first picker
- **THEN** the gesture is unassigned, and the row shows *None* with no plus button and no second line

### R8. Changing the first app keeps the second app
Picking another app on the first picker MUST keep the second app. Picking the second app as the first app MUST make it the first app and remove the second app, so the gesture never holds the same app twice.

#### Scenario: Replacing the first app
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user picks Mail in the first picker
- **THEN** the gesture holds Mail and Safari

#### Scenario: Picking the second app as the first
- **GIVEN** the 1-finger gesture holds Notes and Safari
- **WHEN** the user picks Safari in the first picker
- **THEN** the gesture holds Safari only, and the row shows the plus button

### R9. A second app is saved
A second app MUST be saved at once and survive a quit, a force-quit, a Mac restart and an update. Upgrading from a version without second apps MUST keep every gesture's app and add no second app.

#### Scenario: Second app survives a restart
- **GIVEN** the user set the 1-finger gesture to Notes and Safari
- **WHEN** the Mac restarts and Trackpad Launcher starts at login
- **THEN** the 1-finger gesture still holds Notes and Safari

#### Scenario: Second app survives a force-quit
- **GIVEN** the user set the 1-finger gesture to Notes and Safari
- **WHEN** Trackpad Launcher is force-quit and opened again
- **THEN** the 1-finger gesture still holds Notes and Safari

#### Scenario: Upgrade keeps existing assignments
- **GIVEN** a Mac with saved settings from version 1.0.19, the 1-finger gesture assigned to Notes
- **WHEN** the new version starts
- **THEN** the 1-finger gesture holds Notes and no second app

### R10. A split gesture brings both apps to front
When a split gesture fires and both apps are present, each app MUST be brought to front as a one-app gesture would bring it: launched if not running, otherwise unhidden, restored or given a new window as needed. The app on the half the pointer is over MUST be the active app after the gesture (the first app when no window is placed); call it the focused app. The other app MUST NOT keep the focus: one still launching does not take it when it finishes launching, and one that takes it by itself within a second of the gesture gives it back. A focused app that is launching becomes active when it finishes launching, as a one-app launch does. While the hide background apps setting is on, the other app MUST NOT be made active at all. (Changed during Finish, on the human's request: the focus follows the pointer's side.) One gesture haptic MUST play.

#### Scenario: Both apps running
- **GIVEN** the 1-finger gesture holds Notes and Safari, both running behind other apps
- **WHEN** the 1-finger gesture fires
- **THEN** Notes and Safari both come to front, Notes is the active app, and one gesture haptic plays

#### Scenario: One app hidden, one not running
- **GIVEN** the 1-finger gesture holds Notes (hidden) and Safari (not running)
- **WHEN** the 1-finger gesture fires
- **THEN** Notes shows again, Safari launches, and Notes is the active app

#### Scenario: First app running, second app launching
- **GIVEN** the 1-finger gesture holds Notes (running) and Safari (not running)
- **WHEN** the 1-finger gesture fires
- **THEN** Notes is the active app
- **AND** Notes stays the active app after Safari's window shows

#### Scenario: First app launching, second app running
- **GIVEN** the 1-finger gesture holds Notes (not running) and Safari (running)
- **WHEN** the 1-finger gesture fires
- **THEN** Safari comes to front
- **AND** Notes becomes the active app when it finishes launching

### R11. A split gesture places the windows side by side
With the Accessibility permission, a split gesture MUST place the first app's front window in the left half and the second app's front window in the right half of the usable area of the display under the pointer. The usable area excludes the menu bar and the Dock. The halves MUST meet exactly in the middle, with no gap. When the usable width is an odd number of points, the left half MUST take the extra point. Each fire MUST place both windows again, even when the user moved them since.

#### Scenario: Placing two running apps
- **GIVEN** the 1-finger gesture holds Notes and Safari, both running with one window each, the pointer on a display with the Dock at the bottom
- **WHEN** the 1-finger gesture fires
- **THEN** Notes's window fills the left half of the area between the menu bar and the Dock, and Safari's fills the right half

#### Scenario: Firing again after a manual move
- **GIVEN** the user fired the split gesture and then dragged Safari's window elsewhere
- **WHEN** the gesture fires again
- **THEN** Safari's window returns to the right half

#### Scenario: Display under the pointer
- **GIVEN** two displays, with Notes's window on display A and the pointer on display B
- **WHEN** the split gesture fires
- **THEN** both windows are placed on display B

### R12. No other window covers a placed window
Once a split gesture's windows are placed, no other window of either app MUST cover either placed window. Both placed windows are fully visible.

#### Scenario: A back window over the other half
- **GIVEN** the 1-finger gesture holds Notes and Safari, and Notes has two windows, the back one lying over the right half
- **WHEN** the gesture fires
- **THEN** Notes's front window fills the left half and Safari's fills the right half
- **AND** both placed windows are fully visible

### R13. A window that appears later is placed when it shows
When an app of a split gesture has no window yet (it is launching, or it has to open one), its first window MUST be placed in its half when it shows within 10 s of the gesture, while its launch watch runs. The half is on the display chosen when the gesture fired. A window that shows after that MUST NOT be moved. The other app's window MUST be placed at once and not wait. A later gesture of any kind firing MUST cancel the pending placements of earlier split gestures.

#### Scenario: Second app not running
- **GIVEN** the 1-finger gesture holds Notes (running) and Safari (not running)
- **WHEN** the gesture fires
- **THEN** Notes's window is placed in the left half at once
- **AND** when Safari's first window shows, it is placed in the right half

#### Scenario: A window that shows too late
- **GIVEN** the 1-finger gesture holds Notes (running) and Safari (not running)
- **WHEN** the gesture fires and Safari's first window shows 12 s later
- **THEN** Safari's window is not moved

#### Scenario: A running app with no window
- **GIVEN** the 1-finger gesture holds Notes and Safari, both running, and Safari has no window
- **WHEN** the gesture fires
- **THEN** Safari opens a window, and that window is placed in the right half

#### Scenario: Another gesture cancels the placement
- **GIVEN** the 1-finger gesture holds Notes (running) and Safari (not running)
- **WHEN** the gesture fires, and another gesture fires before Safari's first window shows
- **THEN** Safari's window is not moved when it shows

### R14. A window that cannot take its half's size gets the closest size
A window that cannot take its half's size MUST get the size closest to the half's that it allows. The first app's window is anchored at its half's top-left corner, and the second app's at its half's top-right corner. So an oversize window stays on the display and overlaps the other half.

#### Scenario: A fixed-size window
- **GIVEN** the 1-finger gesture holds Calculator, whose window has a fixed size, and Safari
- **WHEN** the gesture fires
- **THEN** Calculator's window sits at the left half's top-left corner at its own size, and Safari's fills the right half

#### Scenario: An oversize second-app window
- **GIVEN** the 1-finger gesture holds Notes and an app whose window cannot be narrower than 900 pt, on a display whose usable area is 1400 pt wide
- **WHEN** the gesture fires
- **THEN** Notes's window fills the left half
- **AND** the second app's window is 900 pt wide, its top-right corner at the right half's top-right corner, overlapping the left half by 200 pt

### R15. A full-screen window leaves full screen first
A window in full screen MUST leave full screen first, then be placed.

#### Scenario: A full-screen window
- **GIVEN** Safari's front window is in full screen
- **WHEN** a split gesture holding Notes and Safari fires
- **THEN** Safari's window leaves full screen and fills the right half

### R16. No error for a window that cannot be placed
Trackpad Launcher MUST NOT show any error for a window that cannot be placed.

#### Scenario: A window that refuses to move
- **GIVEN** the 1-finger gesture holds Notes and an app whose window refuses to move
- **WHEN** the gesture fires
- **THEN** Notes's window fills the left half, the other window stays where it was, and no alert or message shows

### R17. Without Accessibility, both apps come to front unplaced
Without the Accessibility permission, a split gesture MUST bring both apps to front, with the first app active, and MUST NOT move or resize any window. It MUST NOT show any new message; the existing Accessibility hint covers it.

#### Scenario: Permission missing
- **GIVEN** Trackpad Launcher lacks the Accessibility permission
- **WHEN** a split gesture holding Notes and Safari fires
- **THEN** Notes and Safari come to front, Notes active, and their windows keep their places and sizes

#### Scenario: The Accessibility hint covers it
- **GIVEN** the 1-finger gesture holds Notes and Safari, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** the Accessibility hint shows with its existing message, "Allow Accessibility access to make trackpad gestures work reliably."

### R18. A missing app falls back to a one-app gesture
When one app of a split gesture is missing, the gesture MUST bring the present app to front exactly as a one-app gesture would, moving no window. When both are missing, the gesture MUST do what a gesture with a missing app does today. A missing second app MUST show in its picker as a missing first app does today: its name, greyed.

#### Scenario: Second app deleted
- **GIVEN** the 1-finger gesture holds Notes and Safari, and Safari was moved to the Trash
- **WHEN** the gesture fires
- **THEN** Notes comes to front as a one-app gesture brings it, and no window moves

#### Scenario: First app deleted
- **GIVEN** the 1-finger gesture holds Notes and Safari, and Notes was moved to the Trash
- **WHEN** the gesture fires
- **THEN** Safari comes to front as a one-app gesture brings it, and no window moves

#### Scenario: Both apps deleted
- **GIVEN** the 1-finger gesture holds Notes and Safari, and both were moved to the Trash
- **WHEN** the gesture fires
- **THEN** the gesture does what a gesture with a missing app does today

#### Scenario: Missing second app in its picker
- **GIVEN** the 1-finger gesture holds Notes and Safari, and Safari was moved to the Trash
- **WHEN** the user opens the settings window
- **THEN** the second picker shows Safari's name, greyed, as a missing first app shows

### R19. Each app plays its own launch effect
With the launch animation setting on, each app of a split gesture MUST play the effect it would play alone. A running app plays the launch animation, and an app that is not running bounces. Two bounces from one split gesture MUST sit side by side, the first app's on the left.

#### Scenario: Both apps launching
- **GIVEN** neither Notes nor Safari is running
- **WHEN** the split gesture fires
- **THEN** two bounces show side by side, Notes's on the left
- **AND** when each app's window shows, its icon floats away swaying toward its own side

#### Scenario: One app running, one launching
- **GIVEN** the launch animation setting is on, Notes is running and Safari is not
- **WHEN** the split gesture holding Notes and Safari fires
- **THEN** Notes's icon floats away swaying left, and Safari bounces

### R20. Each app's launch animation sways toward its half
The first app's launch animation MUST sway to the left and the second app's to the right, never at random. This includes the launch animation that ends a bounce.

#### Scenario: Both apps running
- **GIVEN** the launch animation setting is on, and Notes and Safari are both running
- **WHEN** the split gesture holding Notes and Safari fires
- **THEN** Notes's icon floats up swaying left, and Safari's floats up swaying right

### R21. Hide background apps keeps both apps
With the hide background apps setting on, a split gesture MUST hide every app except its two apps. As for a one-app launch, an app that is launching hides the others once its window shows, and never hides the other app of the gesture.

#### Scenario: Hiding with a split gesture
- **GIVEN** the hide background apps setting is on, and Mail, Notes and Safari are running
- **WHEN** the split gesture holding Notes and Safari fires
- **THEN** Mail is hidden, and Notes and Safari stay on screen side by side

#### Scenario: Hiding while the second app launches
- **GIVEN** the hide background apps setting is on, Mail and Notes are running, and Safari is not
- **WHEN** the split gesture holding Notes and Safari fires
- **THEN** Mail hides once Safari's window shows, and Notes is never hidden

### R22. Split gesture apps stay in the switcher
The apps of a split gesture MUST NOT be left out of the switcher's row on that account. A split gesture's app is not one tap away on its own: its gesture brings two apps, so the switcher stays the way to reach it alone. An app that is also a one-app gesture's app stays left out, as today. The row keeps its usual most-recently-used order.

#### Scenario: Split apps in the switcher
- **GIVEN** the 1-finger gesture holds Notes and Safari, and no other gesture holds either
- **WHEN** the user swipes with Notes and Safari running
- **THEN** both Notes and Safari appear in the switcher's row

#### Scenario: App also on a one-app gesture
- **GIVEN** the 1-finger gesture holds Notes and Safari, and the 2-finger gesture holds Safari alone
- **WHEN** the user swipes
- **THEN** Safari is left out of the row, and Notes is in it

## Product overview changes

These wordings replace the matching parts of `docs/product-overview.md`:

- **Gestures**: each gesture launches or focuses its app, or, when it holds a second app, brings both apps to front side by side: the first in the left half and the second in the right half of the display under the pointer.
- **Switcher**: it leaves out apps that a gesture holds alone. Apps held only in a split gesture stay in the row.
- **Hide background apps**: "one app is on screen at a time" becomes "one app, or a split gesture's two apps, on screen at a time".
- **Accessibility**: the permission is also used to place a split gesture's windows: to move them, resize them and take them out of full screen.

## Non-goals

- **macOS full-screen Split View.** macOS offers no public way to start it, so it would be fragile. The windows are tiled on the current desktop instead.
- **The same app twice, as two windows.** This would need a second window from apps that may not open one. R5 prevents it.
- **More than two apps, or layouts other than left and right halves.** The design shows two apps side by side only.
- **Choosing which app is on which side apart from the order of picking.** The first app is always on the left.
- **Window gaps or margins.** macOS's own tiling margins setting is not followed; the halves meet exactly.
- **A message when windows cannot be placed.** Placement is best effort (R14 to R17).
- **The swipe, the window swipe and the swap.** They reach one app or window at a time, unchanged, except which apps the switcher leaves out (R22).
- **Windows on another desktop (Space), and Stage Manager.** Each app is brought to front as macOS does today, which may switch desktops. Windows are placed where macOS shows them, and are not gathered onto one desktop.
- **Restoring a window's earlier size and position after a split.**

## Design

### Problem

Today a gesture holds one app everywhere: one `AssignedApp` in the saved record, one `RowApp` per row, one `BundleID` behind every launch record, watch, bounce and hide. Accessibility only reads and raises windows. A split gesture needs a second app in each of those places, plus the codebase's first Accessibility writes. The shape must honour these constraints (F-numbers are the grounding's facts, in `.temp/architect/grounding/index.md`):

- **The record.** 1.0.19 fails the whole record when an `assignments` value changes shape. It reads a new key and drops it at its next save (F2).
- **Activation order.** The app opened last ends active, and its front window is lifted alone (F17, F18). Only a launch opened without activation stays out of the focus (F20).
- **Launches.** An app opens before any watch, clock, layer or animation work. The adapter never pairs two port calls behind the model's back (plan 017).
- **Windows and time.** Only the window list says a window is on screen (F24). No timer may wait for one (F26). Accessibility calls block their thread (F32).
- **The port.** Setting window attributes is banned, the element API is confined to two files (F30), and no geometry crosses a port (F31).
- **The settings row.** The picker is an AppKit pop-up whose pick animation plays only on its own confirmed pick (F10). The window refits only on `Fit` changes (F11).

### Usage (caller's view)

```swift
// The row (GestureRowView): three intents. The second picker has no way to say None.
AppPicker(current: row.app, unavailable: nil, …,
    choose: { launcher.setAssignment($0, for: row.gesture) },              // R8: keeps the second app unless it is $0
    chooseNone: { launcher.setAssignment(nil, for: row.gesture) })         // R7: both apps go
if let slot = row.second {                                                  // nil while unassigned (R1)
    SecondAppPicker(slot: slot, unavailable: row.firstBundleID, …,          // .add: plus; .app: minus + picker
        choose: { launcher.setSecondApp($0, for: row.gesture) },            // R2, R4, R5; answers what plays
        remove: { launcher.removeSecondApp(for: row.gesture) })             // R6
}

// The model firing Notes (running) + Safari (not running), Accessibility granted.
hardware.playFeedback(.gesture, on: event.trackpad)                         // once (R10)
system.bringToFront(SplitArrival(
    first: SplitApp(notes, .running(animates: true, followed: true)),
    second: SplitApp(safari, .launching(watch: .bouncing))), cap: WatchedLaunch.cap)
system.placeFrontWindow(of: notes.bundleID, in: ScreenHalf(side: .left, display: display))
// … later, pushed by Safari's watch, inside progress(.windowShown, of: safari):
system.endLaunch(of: safari.bundleID, with: .launchAnimation)              // the bounce kept its side: it sways right
system.placeFrontWindow(of: safari.bundleID, in: ScreenHalf(side: .right, display: display))
system.hideOtherApps(keeping: KeptApps(front: notes.bundleID, beside: safari.bundleID))   // with the setting on

// A model scenario at the World seam (R13, "Another gesture cancels the placement").
world.tap(1)
#expect(world.system.windowPlacements == [.init(B("Notes"), ScreenHalf(side: .left, display: D1))])
world.tap(2)                                                                // Mail, a one-app gesture
world.report(.finishedLaunching, for: "Safari"); world.report(.windowShown, for: "Safari")
#expect(world.system.windowPlacements.count == 1)                          // Safari's window is not moved

// The write sequence at the platform's internal seam (R14, the 900 pt window of F36).
let calls = ScriptedPlacing(window: .init(frame: CGRect(x: 260, y: 390, width: 900, height: 332), minWidth: 900))
let outcome = FrontWindowPlacer.place(pid, in: halves, side: .right, previous: nil, budget: budget, calls: calls,
                                      isLatest: { true })
#expect(calls.writes == [.position(756, 33), .size(756, 949), .position(612, 33)])
#expect(outcome == .placed(CGRect(x: 612, y: 33, width: 900, height: 949)))   // the next pass leaves it there
```

### Shape

**Data first.**
- **`Assignment`.** It holds a required first app and an optional second app. Its one initializer drops a second app that has the first app's bundle identifier, so neither R5 nor R8 can be broken by any caller, and a gesture's `Assignment?` cannot hold a second app without a first. This follows type-system-discipline.
- **The wire.** `Settings.assignments` keeps its key and becomes `[Gesture: Assignment]`. An `Assignment` encodes as the first app's three keys at the entry's top level, exactly as every version wrote them, plus a `secondApp` key holding the same three keys. So 1.0.19 reads every first app (F2 B), an old record loads with no second apps (R9), and a second app without a first cannot exist on disk.
- **A row** is a sum type, `GestureRow.Apps`, with three cases: `.unassigned`, `.one`, `.two`. The plus button and the second line therefore have one source and cannot contradict each other. The view reads three derived facts:
  - `app`, the first picker's `RowApp`, which is unchanged;
  - `second`, a `SecondSlot?` that is nil, `.add` or `.app`;
  - `firstBundleID`, the app the second menu shows disabled.
- **The pending placement.** It is one optional, `Launcher.placing: SplitPlacing?`, holding the first app, the second app and the display chosen at fire. Each gesture that is not silent clears it before deciding, so at most one split gesture's windows can still be waiting (R13). This follows model-the-domain.
- **Watch records.** A running app that a split gesture follows until its window shows gets a `WatchedLaunch` record of kind `.followed`. So there is one record type, one `progress` path and one watch per bundle.

**Load-bearing decisions.**

1. **One port call brings a split to front.** `bringToFront(_: SplitArrival, cap:)` performs every effect of the arrival, in order:
   1. Open the second app, then the first (F17, F18, R12). The first app always activates. The second activates only when it is `.running`; a launching second app opens without activation (F20, R10).
   2. Start each new watch's clock.
   3. Start the bounces, first app first (R19).
   4. Play the launch animations.

   The two apps sway toward their sides, and a bounce keeps its side for its ending (R20). The order is a pure `SplitSteps` value that the adapter runs and a platform test pins. The one-app path (`bringToFront`, `bringToFrontWatching`, `playLaunchAnimation`) is untouched. This follows encode-lessons-in-structure: the order cannot be broken by the model.
2. **Two placing moments.**
   - **At the gesture,** for each app with a process: a hidden app is shown already in its half (F38), and a visible window moves at once (R13: "placed at once").
   - **When the watch first sees a window of that app on screen.** This is the one trigger for launching, windowless, hidden-until-now and minimised apps (R13).

   A split gesture with Accessibility follows its running apps with the existing launch watch (F25), its 2 s grace starting at once. Placing is idempotent: a window already in its half is left alone, and a later placing for the same process wins. This follows make-operations-idempotent. Every placement is gated on `placing`, which only the latest gesture's split holds, and on a live watch record, which only lives within the watch's limits. That gives R13's two cut-offs.
3. **Geometry never crosses the port.** The model sends `ScreenHalf(side:display:)`. The adapter resolves the display, converts its `visibleFrame` to Accessibility coordinates (F40), trims it inward to whole points and halves it, the odd point going left (R11). This happens in a pure `SplitHalves`, per boundary-discipline.
4. **Accessibility writes live in one file, off the main actor.** `FrontWindowPlacer.swift` runs one GCD work item per placing.
   - **Queues.** One process's work items run one at a time, on a serial queue that targets the placer's concurrent queue; different apps run in parallel. Before every call into the app, a work item checks that its ticket is still the latest for that process. So a newer placing always runs alone, with no older write after it.
   - **Budget.** The sequence is held to 0.5 s from dispatch with `ReadBudget`; each call gets what is left as its messaging timeout.
   - **Silence.** No element leaves the work item, and nothing hops back, so no error can show (R16).
   - **The sequence, in order:**
     1. choose the window: the main window, else the first standard window that is not minimised;
     2. leave full screen (R15, F37);
     3. set the position, then the size (F34);
     4. read the size back;
     5. re-anchor the right half at its top-right corner (R14, F36).
   - **Refusals.** A refused size carries on (F33). A refused position, or a refused exit from full screen, ends the sequence, so the window stays where it was (R16).
   - **Already there.** A window already in its half is left alone. So is a window still at the frame this process's last placing into the same half left it at, such as an anchored oversize or fixed-size window. This keeps the watch's second pass from moving it (R14).
   - **Without Accessibility** the model reads no display and places nothing (R17).
5. **Hiding keeps both apps.** `hideOtherApps(keeping: KeptApps)` replaces `hideOtherApps(than:)`. `BackgroundHider` keeps its one goal (`front`, the first app) and its arrival rule. Every pass skips `beside`. A pass that finds `beside` frontmost hides nothing and carries on to the next pass.
   - When both apps run, the hide is sent at fire.
   - Otherwise it is sent when a split app's window shows, if the first app is frontmost and its own launch is not still waiting for a window. A pending first app hides when its own window shows, so the active app always has a window on screen when the others hide (plan 032 root cause 1, R21, O8).
6. **Settings row.** `AppPicker` gains three changes:
   - `choose` takes a non-optional choice;
   - an optional `chooseNone`, inert when absent, so None on the second picker cannot change anything (R2, R4);
   - an `unavailable` bundle identifier, whose menu item is disabled (F9, R5).

   `SecondAppPicker` is one AppKit view holding the plus button, the minus button and a `PickerButton`, driven by an `AppPicker.Coordinator`. The plus button pops up a menu with the same items. An accepted pick switches the view to minus and picker at once, and plays the pick animation on that picker (R2). `AnyLayout` switches between an `HStackLayout` (one line) and a trailing `VStackLayout` (two lines). This keeps the identity of the second slot's view, so its animation survives the move to line 2.
7. **Row heights (O1).** The shipped one-app row stays at 46 pt, a deliberate change in #39. A two-app row is 30 pt taller, 76 pt: the difference R3 states. `Fit` gains `twoAppRows` (R3, R6).
8. **Switcher (R22).** `Settings.oneAppBundleIDs` replaces `assignedBundleIDs`. It holds the first apps of gestures without a second app.

**Depth.** `SystemActions` gains three members (`bringToFront(_:cap:)` for a split, `pointerDisplay`, `placeFrontWindow`), and one member changes its parameter (`hideOtherApps(keeping:)`). Behind them sit:
- the activation order and the no-activation launch;
- the watches, bounces and sides;
- the coordinate conversion and the halving;
- the write sequence, anchoring, full screen, the budget, threads and tickets;
- the two-app hide.

The model keeps only what it decides: which app goes where, what is watched, when to place, and what hides.

#### LauncherCore: assignment, rows

```swift
/// What a gesture holds: a first app and, for a split gesture, a second app that is never the first app.
public struct Assignment: Codable, Equatable, Sendable {
    public let first: AssignedApp                    // AssignedApp unchanged: the frozen replicas stay valid
    public let second: AssignedApp?

    /// The only initializer, decoding included: a second app with the first app's bundle identifier is dropped.
    public init(first: AssignedApp, second: AssignedApp? = nil) {
        self.first = first
        self.second = second?.bundleID == first.bundleID ? nil : second
    }

    /// R8: a new first app keeps the second app, unless it is that app, which then is the only app.
    public func settingFirst(_ app: AssignedApp) -> Assignment { Assignment(first: app, second: second) }
    /// R2, R4, R5: nil when `app` is the first app, so nothing changes.
    public func settingSecond(_ app: AssignedApp) -> Assignment? {
        app.bundleID == first.bundleID ? nil : Assignment(first: first, second: app)
    }
    /// R6.
    public var removingSecond: Assignment { Assignment(first: first) }

    /// R18. What a fire brings to front, from which apps are on disk now: both → split; one → that app alone, as a
    /// one-app gesture; none → nothing (silent, as a missing app today). One Info.plist read per app.
    func target(locate: (AssignedApp) -> AppEntry?) -> GestureTarget { fatalError("not implemented") }

    /// Wire: the first app's `bundleID`, `name`, `lastKnownURL` at the entry's top level, as every version wrote them,
    /// plus `secondApp`, permanently that name, holding the same three keys. 1.0.19 ignores `secondApp`.
    public init(from decoder: any Decoder) throws {
        // let first = try AssignedApp(from: decoder)
        // let second = try decoder.container(keyedBy: Key.self).decodeIfPresent(AssignedApp.self, forKey: .secondApp)
        // self.init(first: first, second: second)
        fatalError("not implemented")
    }
    public func encode(to encoder: any Encoder) throws {
        // try first.encode(to: encoder); then encodeIfPresent(second, forKey: .secondApp) into the same dictionary
        fatalError("not implemented")
    }
}

enum GestureTarget: Equatable, Sendable {
    case nothing
    case one(AppEntry)
    case split(first: AppEntry, second: AppEntry)
}

// Settings
/// Absent = unassigned. The key and each entry's first-app keys are permanent (see Assignment's wire form).
public var assignments: [Gesture: Assignment] = [:]
/// R22. The apps some gesture holds alone, missing ones included: one tap away, so the switcher leaves them out.
/// Replaces `assignedBundleIDs`. Derived, never stored.
public var oneAppBundleIDs: Set<BundleID> {
    Set(assignments.values.filter { $0.second == nil }.map(\.first.bundleID))
}

public struct GestureRow: Identifiable, Equatable, Sendable {
    public let gesture: Gesture
    public let apps: Apps
    public var id: Gesture { gesture }

    public enum Apps: Equatable, Sendable {
        case unassigned                            // "Choose app…", no plus button (R1)
        case one(Held)                             // one line: the picker, then the plus button, missing included (R1)
        case two(first: Held, second: Held)        // line 1: the picker; line 2: minus, then the second picker (R3)
    }
    /// An app a gesture holds: on disk, or missing and shown by its saved name, greyed (R18).
    public enum Held: Equatable, Sendable { case present(AppEntry), missing(name: String, bundleID: BundleID) }

    /// The first picker's app; `RowApp` is unchanged.
    public var app: RowApp { fatalError("not implemented") }
    /// nil while unassigned; `.add` for one app; `.app` for the second app.
    public var second: SecondSlot? { fatalError("not implemented") }
    /// The first app, present or missing: shown disabled in the second app's menu (R5).
    public var firstBundleID: BundleID? { fatalError("not implemented") }
    public var lineCount: Int { if case .two = apps { 2 } else { 1 } }
}
public enum SecondSlot: Equatable, Sendable { case add, app(GestureRow.Held) }

public enum AppItemState: Equatable, Sendable { case plain, current, unavailable }   // .unavailable: shown disabled
extension InstalledApps {
    /// As today; `unavailable`'s item, when listed, is `.unavailable`.
    public func pickerMenu(checking app: RowApp, unavailable: BundleID? = nil) -> [PickerItem] { fatalError("not implemented") }
}

// Copy gains `addSecondApp` = "Add a second app" and `removeSecondApp` = "Remove the second app".

extension Launcher {
    /// First picker. nil = None: the gesture is unassigned, second app included (R7). An app becomes the first app
    /// through `settingFirst` (R8). Saves at once (R9). Answers the app the first picker now shows present.
    @discardableResult public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) -> AppEntry? {
        fatalError("not implemented")
    }
    /// Plus button and second picker. Answers the app the second picker now shows present, which plays the pick
    /// animation. nil, nothing saved: no first app, the first app itself, also through Other… (R5), or not an app.
    @discardableResult public func setSecondApp(_ choice: AppChoice, for gesture: Gesture) -> AppEntry? {
        fatalError("not implemented")
    }
    /// Minus button (R6). A no-op without a second app.
    public func removeSecondApp(for gesture: Gesture) { fatalError("not implemented") }
    // Each saves the whole record with one store.save and calls resolveRows(), which also prepares the launch
    // animations of present second apps, de-duplicated by URL.
}
```

#### LauncherCore: split values, the port, the model

```swift
/// The side an app of a split gesture takes: the first app left, the second right. Halves, sway and bounce order
/// all derive from it.
public enum SplitSide: Equatable, Sendable { case left, right }
/// A display, by the window server's number, as `WindowID` wraps a window's. No frame crosses the port.
public struct DisplayID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
/// "The left half of that display's usable area"; the adapter works out the rectangle when it places.
public struct ScreenHalf: Equatable, Sendable {
    public let side: SplitSide
    public let display: DisplayID
    public init(side: SplitSide, display: DisplayID) { self.side = side; self.display = display }
}

/// One app of a split gesture, as the model decided to bring it to front.
public struct SplitApp: Equatable, Sendable {
    public let app: AppEntry
    public let entrance: Entrance
    public init(_ app: AppEntry, _ entrance: Entrance) { self.app = app; self.entrance = entrance }
    public enum Entrance: Equatable, Sendable {
        /// Has a process. `followed`: a new watch reports its next window on screen (no bounce).
        case running(animates: Bool, followed: Bool)
        /// No process. `watch` nil: launched and not watched.
        case launching(watch: Watch?)
        /// Its launch is already watched: opened only; its one watch, bounce and side carry on.
        case alreadyLaunching
    }
    public enum Watch: Equatable, Sendable { case unseen, bouncing }
}
public struct SplitArrival: Equatable, Sendable {
    public let first: SplitApp
    public let second: SplitApp
    public init(first: SplitApp, second: SplitApp) { self.first = first; self.second = second }
}

/// The apps a hide keeps. `front` must be active and shown before anything hides; `beside`, a split gesture's other
/// app, is kept but never waited for. Never the same app twice.
public struct KeptApps: Hashable, Sendable {
    public let front: BundleID
    public let beside: BundleID?
    public init(front: BundleID, beside: BundleID? = nil) { fatalError("not implemented") }  // drops beside == front

    /// R21, pure. Whether `app`'s first window showing hides the others now: `front` must be frontmost, and when
    /// `app` is `beside`, `front`'s own launch must not still be waiting for its window (that window hides instead).
    func hides(onWindowOf app: BundleID, frontmost: BundleID?, frontStillWaits: Bool) -> Bool { fatalError("not implemented") }
}

@MainActor public protocol SystemActions: AnyObject {
    // Unchanged: bringToFront(_: AppEntry), bringToFrontWatching, limitLaunch, endLaunch, playLaunchAnimation,
    // prepareLaunchAnimations, hasProcess, onLaunchProgress, runningApps and the window reads.

    /// A split gesture's bring to front, in one call so the order is the adapter's to keep: opens `second`, then
    /// `first`, before anything else, each exactly as `bringToFront` opens an app, except that `second` is activated
    /// only when `.running`. So the first app ends active with its front window on top, the second app's front window
    /// lies above every other window of both, and a second app that finishes launching never takes the focus. Then
    /// each watch asked for (`cap`; reports through `onLaunchProgress`; one watch per app), then the bounces, the
    /// first app's first, then the launch animations; each app sways toward its side, a bounce's ending included.
    func bringToFront(_ split: SplitArrival, cap: Duration)
    /// The display under the pointer now; nil with none. Reads only.
    func pointerDisplay() -> DisplayID?
    /// Puts the app's front window in that half, if the app runs and has one, and returns at once: the work runs away
    /// from the main actor and answers nothing, ever. A full-screen window leaves full screen first; a window that
    /// cannot take the half's size keeps the closest it allows, at the half's top-left corner (`.left`) or top-right
    /// corner (`.right`). A window already there is left alone; a later call for the same app wins. Needs
    /// Accessibility: the caller checks it.
    func placeFrontWindow(of app: BundleID, in half: ScreenHalf)
    /// Was `hideOtherApps(than:)`: every Dock app outside `kept` hides once `kept.front` is active and shown, as before.
    func hideOtherApps(keeping kept: KeptApps)
}
```

```swift
struct WatchedLaunch: Equatable, Sendable {
    var stage: Stage                   // Stage, its table, cap and grace: unchanged
    let kind: Kind
    /// What hides when its first window shows, as the latest gesture for this app left it; nil: nothing.
    var hidesOnWindow: KeptApps?       // was hidesOthersOnWindow: Bool
    enum Kind: Equatable, Sendable {
        /// The app had no process: its window, or its limits, end a launch (bounce or unseen).
        case launched
        /// A running app a split gesture follows only until its window shows, to place it. Exists only while
        /// `placing` names it; never hides.
        case followed
    }
}

/// The latest split gesture's windows that may still be placed. At most one: every gesture that is not silent
/// clears it before deciding (R13).
struct SplitPlacing: Equatable, Sendable {
    let first: BundleID, second: BundleID, display: DisplayID
    func half(of app: BundleID) -> ScreenHalf? { fatalError("not implemented") }   // first → .left, second → .right
}

// Launcher
@ObservationIgnored private var placing: SplitPlacing?

private func fire(_ event: GestureEvent) {
    // guard activity.isActive, let assignment = settings.assignments[event.gesture] else { return }
    // let target = assignment.target(locate: catalog.locate); guard target != .nothing else { return }   // silent
    // hardware.playFeedback(.gesture, on: event.trackpad)                // one haptic (R10)
    // stopPlacing()   // R13: placing = nil; each .followed record: launches[id] = nil, endLaunch(id, .quietFade)
    // switch target { case .one(let app): bringOneToFront(app)             // today's body, hides KeptApps(front:)
    //                 case .split(let first, let second): splitToFront(first, second) }
    fatalError("not implemented")
}

private func splitToFront(_ first: AppEntry, _ second: AppEntry) {
    // let display = isAccessibilityGranted ? system.pointerDisplay() : nil   // R17: no read, nothing placed
    // let kept = settings.isHideBackgroundAppsOn ? KeptApps(front: first.bundleID, beside: second.bundleID) : nil
    // For each (app, side):
    //   launches[id] exists (.launched) → hidesOnWindow = kept; .alreadyLaunching
    //   !system.hasProcess(id)          → watched = animates || kept != nil || display != nil
    //                                     watched: launches[id] = WatchedLaunch(.startingUp, .launched, kept)
    //                                     .launching(watch: watched ? (animates ? .bouncing : .unseen) : nil)
    //   has a process                   → display != nil: launches[id] = WatchedLaunch(.startingUp, .followed, nil)
    //                                     .running(animates: animates, followed: display != nil)
    // placing = display.map { SplitPlacing(first: first.bundleID, second: second.bundleID, display: $0) }
    // system.bringToFront(SplitArrival(first:, second:), cap: WatchedLaunch.cap)    // records exist before the call
    // for each .running app: placing?.half(of: id).map { system.placeFrontWindow(of: id, in: $0) }
    // if let kept, neither app has a .launched record: system.hideOtherApps(keeping: kept)   // both run (R21)
    fatalError("not implemented")
}

private func progress(_ progress: LaunchProgress, of app: BundleID) {
    // guard let launch = launches[app] else { return }                    // table unchanged for both kinds
    // on .end(ending): launches[app] = nil; system.endLaunch(of: app, with: ending)
    //   guard progress == .windowShown
    //   placing?.half(of: app).map { system.placeFrontWindow(of: app, in: $0) }   // R13: live record, latest split
    //   if let kept = launch.hidesOnWindow,
    //      kept.hides(onWindowOf: app, frontmost: system.runningApps().frontmost?.bundleID,
    //                 frontStillWaits: launches[kept.front]?.hidesOnWindow != nil) {
    //       system.hideOtherApps(keeping: kept) }                            // R21
    fatalError("not implemented")
}
// swipe(.began) passes settings.oneAppBundleIDs; every other hide passes KeptApps(front: id).
```

#### LauncherPlatform

```swift
// WorkspaceActions
public func bringToFront(_ split: SplitArrival, cap: Duration) {
    // Runs SplitSteps(split): a LaunchWatch is made before its open (no clock yet) so the open can hand it the pid;
    // the adapter's one-watch-per-app guard holds; .bounce → bounces.start(app, toward:), which keeps the side for
    // its ending; .launchAnimation → overlay.play(for:toward:).
    fatalError("not implemented")
}
public func pointerDisplay() -> DisplayID? { fatalError("not implemented") }   // LaunchDisplay.containing(…)?.id
public func placeFrontWindow(of app: BundleID, in half: ScreenHalf) { placer.place(app, in: half) }
public func hideOtherApps(keeping kept: KeptApps) { hider.hideOthers(keeping: kept) }

/// A split gesture's bring to front as ordered steps. Pure, so a test pins the order without opening anything.
struct SplitSteps: Equatable {
    enum Step: Equatable {
        case open(AppEntry, activates: Bool, watched: Bool)
        case startWatch(BundleID)
        case bounce(AppEntry, toward: SplitSide)
        case launchAnimation(AppEntry, toward: SplitSide)
    }
    let steps: [Step]
    init(_ split: SplitArrival) {
        // open second (activates: entrance is .running; watched: .running(followed: true) or .launching(watch: non-nil))
        // open first (activates: true; watched likewise)
        // startWatch for each watched open, first app's first
        // bounce for each .launching(watch: .bouncing), first app's first   (R19: start order is row order)
        // launchAnimation for each .running(animates: true), first app's first
        fatalError("not implemented")
    }
}

/// FrontWindowPlacer.swift: the one file that sets a window's attributes.
@MainActor final class FrontWindowPlacer {
    static let budget = Duration.milliseconds(500)
    /// Per process, behind one `Mutex`: the latest ticket, written on the main actor; and the half and frame its last
    /// completed placing left, written by that process's work items, which run one at a time.
    private let tickets: PlacingTickets

    /// The real placer: `AXPlacingCalls`, the screens from `NSScreen`, the running copy from `NSRunningApplication`.
    convenience init() { fatalError("not implemented") }
    /// Tests inject the calls, the screens (the primary display's frame and each display's `visibleFrame` by number)
    /// and the process lookup, and hear each work item end through `finished`, on the work item's thread. The real
    /// placer passes nothing: no outcome ever leaves the file (R16).
    init<Calls: PlacingCalls>(calls: Calls, screens: @escaping @MainActor () -> PlacingScreens,
                              process: @escaping @MainActor (BundleID) -> pid_t?,
                              finished: @escaping @Sendable (BundleID, Outcome) -> Void = { _, _ in }) {
        fatalError("not implemented")
    }

    /// Main actor: the display by number (gone → nothing), `SplitHalves`, the app's running copy from `process`
    /// (none → nothing; this process's own pid → nothing, decided here, not by the lookup), a new ticket; then one work
    /// item on that process's serial queue, which targets the placer's concurrent GCD queue, never the cooperative
    /// pool. Returns at once, answering whether it dispatched a work item; the port ignores the answer.
    @discardableResult func place(_ app: BundleID, in half: ScreenHalf) -> Bool { fatalError("not implemented") }

    /// One window's whole placing, on the calling thread. Each call into the app gets what is left of `budget` as its
    /// messaging timeout; `cannotComplete`, or no time left, ends it with no further call. `previous`: the frame this
    /// process's last completed placing into the same half left.
    nonisolated static func place<Calls: PlacingCalls>(
        _ pid: pid_t, in halves: SplitHalves, side: SplitSide, previous: CGRect?, budget: ReadBudget, calls: Calls,
        isLatest: () -> Bool
    ) -> Outcome {
        // Before every call into the app: isLatest() else .superseded
        // 1. window = mainWindow(of: app), else the first of windows(of: app) whose state is standard and not
        //    minimised; none → .noWindow (a minimised or windowless app's window is placed when the watch sees it)
        // 2. state(of: window); not full screen and its frame == halves[side], or == previous → .alreadyThere
        // 3. full screen → setFullScreen(false), then on at once (R15, F37); refused → .refused
        // 4. setPosition(halves[side].origin)                         // position before size (F34); refused → .refused
        // 5. setSize(halves[side].size)                               // refused (−25200, F33): carry on (R14)
        // 6. taken = size(of: window); side == .right, taken.width != half.width
        //       → setPosition((half.maxX − taken.width, half.minY))  // top-right anchored (F36)
        // 7. with time left, one more state(of: window): the frame macOS left (it may adjust an origin, F35)
        // → .placed(that frame; with no time left for step 7, the last position written with `taken`)
        fatalError("not implemented")
    }
    /// For tests and the remembered frame; it never leaves the file's callers (R16).
    enum Outcome: Equatable { case placed(CGRect), alreadyThere, noWindow, refused, unanswered, superseded }
}
/// What the placer reads of the displays: the primary display's frame and each display's `visibleFrame`, AppKit global.
struct PlacingScreens: Equatable { let primary: CGRect; let visible: [DisplayID: CGRect] }

/// The two halves of a display's usable area in the Accessibility API's coordinates: global points, origin at the
/// primary display's top-left, y down (F40). Pure; these rectangles never leave the placer.
struct SplitHalves: Equatable {
    let left: CGRect, right: CGRect
    /// `visible`: the display's `visibleFrame`; `primary`: `NSScreen.screens[0].frame`; both AppKit global, y up.
    init(visible: CGRect, primary: CGRect) {
        // usable = (visible.minX, primary.maxY − visible.maxY, visible.width, visible.height), trimmed inward to
        // whole points; left.width = ceil(usable.width / 2) (R11: the odd point goes left); right.minX == left.maxX
        fatalError("not implemented")
    }
    subscript(side: SplitSide) -> CGRect { fatalError("not implemented") }
}

/// The placer's calls into one app: an internal seam with two adapters, as `WindowCalls` has. Real: `AXPlacingCalls`;
/// test: a scripted double with its own clock, per-call cost, refusals and a minimum size.
protocol PlacingCalls: Sendable {
    associatedtype Element
    func now() -> Uptime
    func setTimeout(_ seconds: Float, on element: Element)
    func appElement(_ pid: pid_t) -> Element
    /// nil: the app names no main window.
    func mainWindow(of app: Element) -> Result<Element?, WindowCallError>
    func windows(of app: Element) -> Result<[Element], WindowCallError>
    func state(of window: Element) -> Result<WindowState, WindowCallError>
    func size(of window: Element) -> Result<CGSize, WindowCallError>
    func setFullScreen(_ on: Bool, of window: Element) -> WindowCallError?
    func setPosition(_ origin: CGPoint, of window: Element) -> WindowCallError?
    func setSize(_ size: CGSize, of window: Element) -> WindowCallError?
}
/// One multiple-attribute read: frame, full screen, subrole and minimised.
struct WindowState: Equatable, Sendable { let frame: CGRect; let isFullScreen: Bool; let isStandard: Bool; let isMinimised: Bool }

// LaunchDisplay gains `id: DisplayID` (from the screen's NSScreenNumber); ScreenRead.now fills it.
// LaunchWatch.finished: the window list first; a listed window is .windowShown with no Accessibility call, so
//   following a running app that shows a window costs one window-list read on the main actor. `look` is unchanged.
// LaunchFlights.next(draw:reduceMotion:toward:): with `toward`, that side, its size from |draw| as ever; a directed
//   flight neither reads nor feeds the streak, as a Reduce motion flight does not.
// LaunchOverlay.play(for:toward:) and play(for:from:among:size:toward:); BounceOverlay.start(_:toward:) keeps the side
//   in its bounce, and its ending's flight takes it.
// BackgroundHider.hideOthers(keeping: KeptApps): goal = kept.front, arrival unchanged; Apps.hideOthers skips every
//   kept bundle; a pass with kept.beside frontmost hides nothing and carries on; any other app frontmost ends the run.
```

#### LauncherUI

```swift
// AppPicker: `choose: (AppChoice) -> AppEntry?`, `chooseNone: (() -> Void)?`, `unavailable: BundleID?`.
// Coordinator.pick: an item with no app is None → guard let chooseNone else { return } (inert: R2, R4); then, as
// today, current = .unassigned, stop the animation, show at once. build(_:): isEnabled = state != .unavailable
// (it sticks: autoenablesItems is already false, F9).

/// The second slot of a gesture row: the plus button, or the minus button and the second app's picker. One NSView
/// holding three controls, driven by an `AppPicker.Coordinator` for the picker and its menu.
/// - plus: pops up a menu built by the coordinator's own builder at the plus button, nothing checked, the first app
///   disabled.
/// - an accepted pick, from the plus button's menu or the picker's: the view shows the minus button and the picker at
///   once, and the coordinator plays the pick animation on that picker's icon (R2, R4). Renders never play it.
/// - minus: `remove()`; the plus button shows at once.
/// The buttons are `plus.circle.fill` and `minus.circle.fill`, 16 × 16 pt, grey like the picker's badge, with
/// `Copy.addSecondApp` and `Copy.removeSecondApp` as tooltip and accessibility label.
struct SecondAppPicker: NSViewRepresentable {
    // slot, unavailable, installedApps, cachedIcon, icon, choose, chooseOther, remove, pickAnimation
    /// How the plus button's menu opens: `menu.popUp(positioning: nil, at:, in: plusButton)` in the app. A bench
    /// replaces it, since a real pop-up runs a modal tracking loop, and picks from the menu it is handed.
    var popUp: @MainActor (NSMenu, NSView) -> Void = { menu, button in fatalError("not implemented") }
}

// GestureRowView.body
HStack(spacing: 0) {
    GestureIllustration(…)                                // centred in the taller row by the stack
    Spacer(minLength: 12)
    let layout = row.lineCount == 2
        ? AnyLayout(VStackLayout(alignment: .trailing, spacing: Self.lineSpacing))   // line centres 32 pt apart
        : AnyLayout(HStackLayout(spacing: Self.itemSpacing))                        // 12 pt after the chevrons
    layout { AppPicker(…); if let slot = row.second { SecondAppPicker(slot: slot, …) } }
}
.formRowContent(lines: row.lineCount)                     // 26 or 56 pt: a 46 or 76 pt row
// SettingsShell.Fit gains `twoAppRows: Int` (R3, R6); iconTargets and canPreviewPickAnimation read second apps too.
// Spacings are measured against the design reference's PNGs on macOS 26, as the thumb corner rows' were.
```

#### Requirement trace

| R | Carried by |
|---|---|
| R1 | `GestureRow.Apps` → `second`: `.one` (missing included) gives `.add`; `.unassigned` gives nil |
| R2 | `SecondAppPicker`'s plus menu; `setSecondApp`; no `chooseNone`; the coordinator plays on its picker |
| R3 | `.two` → `VStackLayout`, `formRowContent(lines: 2)`, `Fit.twoAppRows` |
| R4 | `SecondAppPicker` in `.app`; `setSecondApp`; no `chooseNone` |
| R5 | `AppItemState.unavailable` from `firstBundleID`; `Assignment.settingSecond` → nil |
| R6 | `removeSecondApp`; `Fit.twoAppRows` |
| R7 | `setAssignment(nil, …)` removes the whole `Assignment` |
| R8 | `Assignment.settingFirst` through `init(first:second:)` |
| R9 | `Assignment`'s wire form in the one record, one `store.save`; the frozen `Build1018Settings` replica, whose record coding 1.0.19 shipped unchanged (`cd9bf28`) |
| R10 | one `playFeedback`; `SplitSteps`: open order, the second app's activation only when running |
| R11 | `pointerDisplay` at fire, `ScreenHalf`, `placeFrontWindow` at every fire, `SplitHalves` |
| R12 | the open order (F18); the placer targets each app's main window, the window the activation lifts |
| R13 | `SplitPlacing`, `stopPlacing`, `.followed` records, `progress`; the watch's grace and cap |
| R14 | `FrontWindowPlacer.place` steps 4 to 6 |
| R15 | step 3 |
| R16 | `placeFrontWindow` answers nothing; `Outcome` stays in the platform |
| R17 | no `pointerDisplay` read without the grant: no placing, no followed app, no new message |
| R18 | `Assignment.target` → `GestureTarget`; `Held.missing` in the second picker |
| R19 | each app decided on its own `hasProcess`; `SplitSteps` starts the bounces first app first |
| R20 | `SplitSteps`' `toward:`; `LaunchFlights.next(toward:)`; the bounce keeps its side |
| R21 | `KeptApps`; the hide at fire when both run; `KeptApps.hides(onWindowOf:…)`; the hider skips `beside` |
| R22 | `Settings.oneAppBundleIDs` |

#### Seams

| Seam | Handles | Covers |
|---|---|---|
| The model, through `World` and `RecordingSystemActions` | `world.tap`; pushed or withheld `world.report`; a scripted `pointerDisplay` answer (nil for none); the grant through `permissions.set`. The fake records `splits`, `windowPlacements` and `kept: [KeptApps]`, keeps `hidesOthers` as `kept.map(\.front)`, and has hooks for order. | R1, R5 to R13, R17 to R22 |
| Core values | `Assignment` (transitions, wire bytes, the 1.0.19 replica both ways); `pickerMenu`; `KeptApps.hides`; `GestureRow.Apps` | R1, R5, R8, R9, R18, R21 |
| `SecondPickerBench`, as `PickerBench` | the real `NSMenu` items and buttons, stub closures | R2, R4, R5, R6 |
| Platform, pure and scripted | `SplitSteps`; `SplitHalves` with two-display frames; `FrontWindowPlacer.place` over scripted `PlacingCalls` (its own clock, a held call, a refusal, a minimum size, a stale ticket, a remembered frame); a `FrontWindowPlacer` built with its test initializer (the main actor returns at once; one process's placings run in order); `LaunchFlights`; `BackgroundHider` over injected `Apps` | R10, R11, R12, R13, R14 to R16, R19 to R21 |
| By hand | Notes, Safari, Calculator and an Electron app; real full-screen exits; focus with real launches; a second display; row heights, the two buttons, the plus menu and the refit; plan 032's hide stress run with two kept apps | R3, R10, R12, R15, O2, O5 |

#### Source scan and docs

- **`SourcePolicyTests`.**
  - `banned` loses `AXUIElementSetAttributeValue`; `kAXPressAction` stays.
  - `confined` gains `AXUIElementSetAttributeValue`, only in `FrontWindowPlacer.swift`, with the rule "only a split gesture moves, resizes or takes a window out of full screen".
  - `AXUIElement` becomes only in `AppWindowReader.swift`, `LaunchWatch.swift` and `FrontWindowPlacer.swift`, with the rule "the Accessibility element API has three users". `CGWindowList` is unchanged.
- **`docs/architecture.md`.**
  - Privacy, the "used only to" list: gains placing a split gesture's front windows (move, resize, leave full screen). "To notice the first window of an app a gesture is launching" also covers a running app a split gesture follows.
  - Privacy, "everything works except": gains placing.
  - Privacy, the confinement sentence: the element API goes to three files, the window list stays with two, and setting attributes goes to one.
  - Concurrency: gains one sentence on placing (off the main actor, one GCD work item per app, held to 0.5 s, no element leaves it, nothing hops back). The push list's "only while a launch is watched" gains "or a split gesture waits to place a window".
- **`docs/domain-model.md`.**
  - New entries: *First app*, *Second app*, *Split gesture*, *Split to front*.
  - *Front window* already exists for the window swipe, so it is widened to cover an app's front window rather than duplicated.
  - Changed entries: *Assignment*, *Target app*, *Bring to front*, *Switcher*, *Gesture row*, *App picker*, *Pick animation*, *Settings window*, *Launch animation*, *Launch bounce*, *Launch watch*, *Sway*, *Hide background apps setting*.

### Synthesis decision

**Base: candidate 2** (Fable). The cross-judge recommended candidate 1, 26 to 24. My own scores, criterion by criterion, were 23 for candidate 1 and 24 for candidate 2:

| Criterion | Candidate 1 | Candidate 2 |
|---|---|---|
| Coverage | 5 | 4 |
| Invariants | 4 | 5 |
| Depth and seams | 3 | 4 |
| Grounding and architecture | 3 | 4 |
| Testability | 5 | 4 |
| Economy | 3 | 3 |

We differ on three criteria:
- **Depth and seams.** Candidate 1 puts Accessibility's coordinate system into core (`ScreenRect`, "origin at the primary display's top-left, y down"). That is the leakage the rubric names.
- **Grounding.** Candidate 1's hide can run while the active first app is still launching and shows no window. That is plan 032's root cause 1. The judge did not weigh this.
- **Economy.** Candidate 1 rewrites the proven one-app port path and its fake. It also makes the plus a pop-up face, whose bezel and chevrons fight the design.

The judge's own grafts from candidate 2 were the persistence shape, a single `SplitPlacing`, keeping geometry off the port, the hardened placer, the non-optional `setSecondApp` and the doc catches. Together those are most of candidate 2's skeleton. So I kept that skeleton and took the judge's two reasons for candidate 1 as grafts.

**Grafted from candidate 1:**
- the pure ordered-steps value (`SplitSteps`), so the open order of R10, R12 and R19 is tested, not only checked by hand;
- the launch animations carried inside the split call, and the bounce keeping its side from its start. Together these remove candidate 2's widening of `playLaunchAnimation` and `endLaunch` with a `swaying:` parameter;
- one watch-record type with a kind (`.followed`), so there is one `progress` path, instead of candidate 2's `followed` set and parallel handler;
- the usable area trimmed inward to whole points;
- the 0.5 s budget;
- `Held.missing` carrying the bundle identifier, so the second menu disables a missing first app too.

**Fixed while synthesizing** (defects the judge found in candidate 2, and one I found):
- Silent gestures no longer clear `placing` or end watches, which keeps `fire`'s silent contract.
- The two-app hide waits only for the first app's own pending window. Candidate 2 waited for either partner, so a second app's run-out could suppress every hide (an R21 gap).

**Rejected from candidate 1:**
- the core `ScreenRect` and frames across the port (leakage);
- replacing the one-app `bringToFrontWatching` and `playLaunchAnimation` with `GestureArrival` (blast radius on proven code);
- the plus face as an `AppPicker` with a custom `Layout` (it does not match the design, and `AnyLayout` keeps view identity with less code);
- `PickAnswer` (a non-optional choice makes None on the second picker unrepresentable);
- two wire maps with a decode filter (the nested key cannot hold an orphan).

**Rejected from candidate 2:**
- `stopPlacing()` before the silent guard;
- the symmetric partner wait in `WatchedLaunch.kept`;
- the `swaying:` widenings;
- the parallel `followed(_:of:)` handler;
- the 1 s budget.

**Convergence.** Both candidates independently chose:
- 46 and 76 pt rows;
- the open order second-then-first, with no activation for a launching second app;
- following running apps with the existing watch;
- a pure placing sequence over an internal Accessibility seam;
- one GCD work item per placement;
- the switcher's one-app rule.

I read that agreement as a strong signal.

### Tradeoffs accepted

- We accept placing a running app's window twice (at the gesture, and when its watch sees it) in exchange for one late trigger that covers launching, windowless, hidden and minimised apps, and no visible jump for a hidden app. The second pass is two reads when nothing moved.
- We accept a short watch on each running app per split fire (KVO, a clock and one window-list read) in exchange for no window read before the opens and no extra port read.
- We accept that a downgrade to 1.0.19 drops second apps at its next save in exchange for one atomic record that cannot hold a second app alone (R9 asks only for upgrades).
- We accept a split-only bring-to-front call beside the one-app calls in exchange for leaving the proven one-app path untouched. Both calls share the adapter's one watch and bounce machinery.
- We accept that with the first app still launching, the hide waits for its window, and is skipped if that launch runs out, as a one-app launch's would be. In exchange, nothing ever hides while the active app shows nothing (plan 032, root cause 1).
- We accept three edges of "one watch per app": a bounce already playing keeps its side and its place in the row; a second app still launching from an earlier one-app gesture was opened with activation and may take the focus when it finishes; and a splash screen ends a watch, so a launching app's window after the splash is not placed.
- We accept rows of 46 and 76 pt, not the plan's 48 and 78, in exchange for keeping #39's shipped rows while meeting R3's 30 pt difference.
- We accept directed flights staying out of the random streak, so a split right after two random left sways can show a third left sway.

### Alternatives considered

- **One port call for every gesture** (candidate 1's `GestureArrival`). It has the deepest port and a single opening routine. But it rewrites the proven one-app path and its fake for no requirement. Lost on blast radius; its pure order test was grafted instead.
- **Pending placements held by the adapter.** It gives the smallest surface. But R13's rules become adapter state no model test sees, and the model must still send a cancel. It hides decisions, not mechanics. Lost.
- **Frames across the port, with the halving in core.** The halving becomes a model function, but the port then carries Accessibility's coordinate system, and the model stores rectangles that go stale. Lost to `DisplayID` plus `SplitSide`.
- **Placing only when a watch reports a window.** One trigger, but a hidden app unhides at its old frame and then jumps, and a visible window waits for the open's answer. Lost on quality, since F38 shows a hidden app's window takes a frame.
- **Second apps under their own defaults key** (plan 048's shape). They would survive a downgrade. But the two keys can disagree, saves stop being atomic, and a stale second app re-attaches to a first app that the old build changed. Lost unless O4 is answered the other way.

### Open questions and risks

- **O1.** Should the rows be 46 and 76 pt, keeping #39's shipped rows, or should every row move to the plan's 48 and 78 pt?
- **O2.** Does a real app's own full-screen exit (Safari, an Electron app) keep a frame set at once? F37 covers an AppKit window only. The watch's second pass helps only when the window was off screen at the gesture.
- **O4.** Is losing second apps on a downgrade acceptable?
- **O5.** Does the coordinate rule hold with a display to the left of or above the primary one? It is tested with fabricated frames, not probed.
- **O6 and O7.** A running app with no window gets the watch's 2 s from the gesture to open one. Is that enough, and does every app answer the reopen with a window?
- **O9.** Only gestures that bring an app to front cancel a pending placement: an unassigned or missing gesture, a swipe, a window swipe and a swap do not. Is that right?
- **Window order (R12).** F18 shows the order only for visible running apps. Does a launching second app's window, opening while the first app is active, land above the first app's back windows? And does a launching first app that restores several windows, or a hidden one that unhides several, order them all below the second app's front window? No probe settled either; M3 checks both by hand.
- **Hung apps.** A followed running app that is hung and shows no window still costs up to two 0.2 s Accessibility calls on the main actor when its watch registers (plan 017's accepted O8, now also for running apps).
- **Hides with two kept apps.** Does the hider's 0-in-90 result hold with two kept apps? Plan 032's stress run needs repeating by hand.
- **Plan 001.** Should plan 049 record that it reverses plan 001's R12 ("MUST NOT resize, zoom or full-screen any window") and its "window layouts" non-goal for split gestures?

### Decisions on the open questions

Taken by the orchestrating session under `/do`, which runs to Finish without human review; the human sees them at the merge question.

- **O1:** 46 and 76 pt. #39 deliberately shipped 46 pt rows, and R3's checkable part is the 30 pt growth and the aligned trailing edges.
- **O4:** acceptable. A downgrade is rare and keeps every first app; the single-key shape keeps saves atomic.
- **O9:** yes. Only a gesture that brings an app to front cancels a pending placement; silent gestures stay silent.
- **Plan 001:** yes. Plan 049 reverses plan 001's R12 and its "window layouts" non-goal for split gestures only; one-app gestures still never resize, zoom or full-screen a window.
- **O2, O5, O6, O7 and the risks:** settled by the manual checks; a failing one is reported under Open at Finish rather than blocking the slices.

### Next implementation step

Start slice S1 with its prefactor, `AppPicker`'s non-optional `choose`, `chooseNone` and `unavailable`, which changes nothing. Then write `Assignment` with its wire form and switch `Settings.assignments` to it. The persistence rows must prove R9 in both directions against the frozen `Build1018Settings` (1.0.19's coding) before the row's intents and views are built.

## Testing Decisions

### Strategy

The requirements are proven at the design's own seams, highest first. One seam cannot carry them all: the model never sees the order the adapter opens apps in, a window's frame, the hider's passes, a flight's side or an AppKit control.

- **The model, at `World`** (`LauncherKit/Tests/LauncherCoreTests/World.swift`). It runs the real `Launcher`, `SettingsStore` on a throwaway suite, `AppCatalog` over temp-dir bundles, and the real recognizer under `world.tap(n)`, over `RecordingSystemActions`. A row observes:
  - `launcher.rows` (`apps`, `app`, `second`, `firstBundleID`, `lineCount`) and each intent's answer;
  - the record as a new process reads it (`relaunch()`, `freshStore().load()`, `settingsRecordBytes()`);
  - the switcher's row, `hardware.feedback`, and every port call in order, through hooks.

  Time passes only by pushed reports. A withheld `world.report` is a window that has not shown. A pushed `.ranOut` is the watch's cap or grace passing on the watch's own clock. A pushed `.finishedLaunching` stands in for the push a running app's watch makes at once (KVO `.initial`, F25). The seam misses everything behind the port. Rows resemble `LaunchBounceFiringTests.swift`, `HideBackgroundAppsTests.swift`, `SwitcherAssignedAppsTests.swift`, `AppResolutionTests.swift` and `PersistenceTests.swift` (`savedSettings`, and `Build1018Settings`, which is also 1.0.19's record coding).
- **The picker in AppKit, at `PickerBench` and a new `SecondPickerBench`** (`LauncherKit/Tests/LauncherUITests/`). They drive the real `PickerButton`, `NSMenu` items and `AppPicker.Coordinator` with stub closures, and send picks through the real items, as `AppPickerTests.swift` does. A row observes item titles, states and `isEnabled`, which closure ran, which control shows, labels, and the icon layer's animation. The bench misses SwiftUI: the two-line layout, `AnyLayout` keeping the view's identity, the heights and the window's refit.
- **Platform rules, pure and scripted** (`LauncherKit/Tests/LauncherPlatformTests/`, `@testable`):
  - `SplitSteps`, as `LaunchReportGate` is pinned;
  - `SplitHalves` and `LaunchDisplay.containing`, over `LaunchFlightTests`' display fixtures;
  - the static `FrontWindowPlacer.place(_:in:side:previous:budget:calls:isLatest:)` over a scripted `PlacingCalls` with its own clock, as `AppWindowReadTests.swift` drives `AppWindowReader.read` over `ScriptedCalls`;
  - a `FrontWindowPlacer` built with `init(calls:screens:process:finished:)` over the same double, each work item awaited through `finished`, and a placing that dispatches nothing told apart by `place(_:in:)` answering false: the tickets, each process's serial queue, the remembered frame, and the display and process lookups;
  - `LaunchFlights.next(…toward:)`, as `LaunchFlightTests.swift`;
  - `BackgroundHider` over a staged `Apps`, as `BackgroundHiderTests.swift`.

  These miss the real adapters behind them: `AXPlacingCalls`, `NSScreen`, `NSRunningApplication`, `NSWorkspace` and the overlays' drawing.
- **By hand**, the M checks under Verified without a test: real apps, real focus, real windows, two displays, the row's look, a real force-quit and real old builds. F44 keeps real cross-app effects out of the suite.

Faked: every `SystemActions` effect (`RecordingSystemActions`), the TCC grant (`InMemoryPermissions`), trackpad frames and haptics (`InMemoryTrackpads`), one app's Accessibility calls (`ScriptedPlacing`), and the workspace's apps for the hider (the stage). Everything we own is real.

Clocks and interleavings:
- The model owns no clock (above). The placer's 0.5 s budget runs on `ScriptedPlacing`'s clock, each call costing what the row scripts. The hider's passes run on the real `LaunchClock` with waits the row injects, as `BackgroundHiderTests` already do, asserting only what has or has not happened after generous gaps. The watch's real cap and grace stay proven by `LaunchWatchClockTests`.
- Forced interleavings: a report withheld across a later gesture (T12, T13); a newer placing issued inside a call (T33); the second app's window before and after the first app's (T18); a second placing of a placed window (T31, T38).
- Held calls: the instance rows hold one app's scripted call until the row releases it. So the main actor's return, another app's placing, and a newer placing of the same app all run while that call blocks (T37). M2 step 7 repeats it with a really stopped app.
- No row kills the process at random: each intent is one synchronous `set` of the one record, so there is no moment between two writes. "Saved at once" is proven by a fresh store read with nothing run after the intent (T3, T4); a real `kill -9` is M5.

Test-side handles this plan adds:
- `RecordingSystemActions`:
  - `splits: [Split]` (`arrival`, `cap`) and `onBringToFrontSplit`. The split call shows both apps again (`hiddenApps`) and appends to `launches`, first app first, a watch for each entrance that starts one: `.running(followed: true)` and `.launching(watch: .unseen)` not bouncing, `.launching(watch: .bouncing)` bouncing. So `limitLaunch`, `endLaunch` and `bounces` work for split apps as they do for one-app launches.
  - `pointerDisplayAnswer: DisplayID?` (default `World.D1`) and `pointerDisplayReads`.
  - `windowPlacements: [WindowPlacement]` (`app`, `half`) and `onPlaceFrontWindow`.
  - `kept: [KeptApps]`, with `hidesOthers` derived as `kept.map(\.front)` and `hiddenApps` sparing `front` and `beside`.
- `World`: `D1` and `D2` (`DisplayID(rawValue: 1)` and `2`), and `split(_:_:on:)`, which sets the first app, then the second, through the two intents.
- `SecondPickerBench`: drives `SecondAppPicker` through `makeView(coordinator:)` and `update`, with stub `choose`, `chooseOther` and `remove` that record their calls. It exposes the plus button, the minus button and the picker's `PickerButton`. It replaces `popUp`, so pressing the plus button hands the bench the menu and the button, and the bench reads and picks from that menu.
- `ScriptedPlacing: PlacingCalls`: an app element per process, each with a main window or none and a list of windows. Each window has a frame, standard or not, minimised or not, full screen or not, and a minimum, maximum or fixed size. Each call has a cost in milliseconds, an error, or a hold the row releases. The double records, per process: the attempted `writes` (`.fullScreen`, `.position`, `.size`) and which window each touched, the window's `frames` after each write, the `timeouts` set, and the `intoApp` calls. It has a hook per call, and it applies macOS's probed rules:
  - a fixed size refuses a size write with −25200 (F33);
  - a size below the minimum takes the minimum (F36), and one above the maximum takes the maximum;
  - a position is taken as given.
- For the instance rows: a `PlacingScreens` with `primary (0, 0, 1512, 982)` and `D1`'s `visible (0, 0, 1512, 949)` (and `D2`'s `(1512, 0, 1920, 1055)` where a row says), and a process lookup answering a pid per bundle identifier.

Existing rows that change, mechanically:
- S1: rows that build `Settings.assignments` wrap `AssignedApp` in `Assignment(first:)` (`CornerChoiceTests`, `LauncherTests`, `PersistenceTests`). `PickerBench` passes `chooseNone`.
- S2: the fake's `hideOtherApps(than:)` becomes `hideOtherApps(keeping:)`. `BackgroundHiderTests` call `hideOthers(keeping: KeptApps(front:))`, and the stage's `hideOthers` takes the kept bundles.
- S3: the `SourcePolicyTests` entries the design lists.

### Test scenarios

`B(x)` is `World.bundleID(x)`. `L(D)` and `R(D)` are `ScreenHalf(side: .left, display: D)` and `.right`. "Placements" are `system.windowPlacements` as (app, half) pairs. "The watches" are the fake's `launches`. `.two(X, Y)` and `.one(X)` abbreviate `GestureRow.Apps` with present apps. A world is started unless said.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R3, R5, R18 | World | Given Music, Notes and Safari; Music alone on `.two`, `split("Notes", "Safari", on: .one)`, `.three` unassigned. Then row `.one`: `apps == .two(Notes, Safari)`, `app == .present(Notes)`, `second == .app(.present(Safari))`, `firstBundleID == B("Notes")`, `lineCount == 2`. Row `.two`: `second == .add`, `firstBundleID == B("Music")`, `lineCount == 1`. Row `.three`: `app == .unassigned`, `second == nil`, `firstBundleID == nil`, `lineCount == 1`. When Music and Safari are moved to the Trash and the window is opened by hand: row `.two` has `apps == .one(.missing(name: "Music", bundleID: B("Music")))`, `app == .missing(name: "Music")`, `second == .add`, `firstBundleID == B("Music")`; row `.one` has `second == .app(.missing(name: "Safari", bundleID: B("Safari")))`. | R1 scenarios 1-3; R3 (two lines); R18 scenario 4; R5 (the first app, present or missing, is the one the second menu disables) |
| T2 | R1, R2, R5, R19 | World | Given Notes, Safari, Mail and Music; Tool, a copy of Notes (same bundle identifier) and an empty folder `Folder` in `downloads`. Notes alone on `.one`, Mail alone on `.two`, Safari alone on `.four`, Music alone on `.five`, then Music trashed and the window opened by hand. When, in turn: (a) `setSecondApp(.app(Safari), for: .one)`; (b) `setSecondApp(.appBundle(at: downloads/Tool.app), for: .two)`; (c) `setSecondApp(.app(Notes), for: .one)`; (d) `setSecondApp(.appBundle(at: downloads/Notes.app), for: .one)`; (e) `setSecondApp(.appBundle(at: downloads/Folder), for: .one)`; (f) `setSecondApp(.app(Safari), for: .three)`; (g) `setSecondApp(.app(Safari), for: .five)`. Then (a) answers Safari's entry, `.one` is `.two(Notes, Safari)`, and the latest `preparedLaunchAnimations` holds Safari once. (b) answers Tool's entry and `.two` is `.two(Mail, Tool)`. (c), (d), (e) and (f) answer nil, and leave `settingsRecordBytes()` byte-identical and every row as it was. (g) answers Safari's entry, and `.five` is `.two(first: .missing(name: "Music", bundleID: B("Music")), second: .present(Safari))`. | R2 scenarios 1-2; R5 scenario 2 ("through Other…"); R1 (no second app without a first; a missing first app's plus works, scenario 3); the design's `setSecondApp` nil cases; R19 (a second app's animation is prepared, de-duplicated by URL, as first apps' are) |
| T3 | R4, R6, R7, R8, R9 | World | Given Notes, Safari and Mail. When, on `.one`, in turn: `setAssignment(.app(Notes))`; `setSecondApp(.app(Safari))`; `setSecondApp(.app(Mail))`; `setAssignment(.app(Safari))`; `setAssignment(.app(Mail))`; `setSecondApp(.app(Notes))`; `removeSecondApp`; `removeSecondApp`; `setSecondApp(.app(Safari))`; `setAssignment(nil)`. Then `.one`'s `apps` reads, step by step: `.one(Notes)`; `.two(Notes, Safari)`; `.two(Notes, Mail)`, answering Mail; `.two(Safari, Mail)`; `.one(Mail)` with `second == .add`, answering Mail; `.two(Mail, Notes)`; `.one(Mail)` with `second == .add`; the same, with the record's bytes unchanged; `.two(Mail, Safari)`; `.unassigned` with `second == nil`. After every step, no row holds one bundle identifier on both lines, and `freshStore().load()?.assignments[.one]` holds exactly what the row shows, nil after the last. After the last step, `relaunch()` then `start()` shows `.one` unassigned. | R4 scenario 1; R8 scenarios 1-2 and "the gesture never holds the same app twice"; R6 scenario; R7 scenario; R9 "saved at once" |
| T4 | R8, R9 | World | Given Notes and Safari; `split("Notes", "Safari", on: .one)` and nothing else run. (a) `relaunch()` then `start()`, a login start after a force-quit or a restart: `.one` is `.two(Notes, Safari)`, and still so after `openedByHand()`. (b) The raw record: `assignments["1"]` has exactly the keys `bundleID`, `name`, `lastKnownURL` and `secondApp`, with `bundleID.rawValue == B("Notes")` and `name == "Notes"`; `secondApp` has exactly `bundleID`, `name` and `lastKnownURL`, with `bundleID.rawValue == B("Safari")`. After `removeSecondApp(for: .one)`, `assignments["1"]` has exactly `bundleID`, `name` and `lastKnownURL`. (c) A seeded record whose entry `"1"` holds Notes's three keys plus a `secondApp` holding Notes's three keys loads, relaunched, as `.one(Notes)` with `second == .add`. | R9 scenarios 1-2; the design's wire form ("the first app's three keys at the entry's top level … plus a `secondApp` key holding the same three keys"); the released shape in `PersistenceTests.savedSettings`; R8 "never holds the same app twice" |
| T5 | R9 | World | (a) Given the frozen released record `PersistenceTests.savedSettings` (Arc on 1, Figma on 2, Spotify on 5, thumb top right), bundles registered as `settingsSavedInTheCurrentFormatStillLoad` does; relaunched and started. Then rows `.one`, `.two` and `.five` are `.one(…)` with `second == .add`, and `.three` and `.four` are unassigned. A 1-finger tap with the thumb top right brings Arc alone to front: `broughtToFront` names Arc, and `splits` is empty. (b) Given a record `Build1018Settings` (1.0.19's coding) encoded with Notes on `.three` and the hide setting on: the new version shows `.three` as `.one(Notes)`, with the hide setting on. (c) Given the new version's record with Notes and Safari on `.one`, Mail alone on `.two` and the hide setting on. Then `Build1018Settings` decodes it without throwing: `assignments[.one]?.bundleID == B("Notes")`, `.two` holds Mail, and the hide setting is on. After `previousVersionSaves` turns the swipe off, the new version shows `.one(Notes)` with no second app, Mail on `.two`, the hide setting on and the swipe off. | R9 scenario 3 ("keep every gesture's app and add no second app"); the frozen fixture; F2 (`probes/record.out`: an extra key inside an entry decodes and is dropped at the next save, while another shape fails the whole record); the design's tradeoff ("a downgrade to 1.0.19 drops second apps at its next save") |
| T6 | R10 | World | Given Mail, Notes and Safari running, Mail frontmost; the animation on, the hide off, no Accessibility; Notes and Safari on `.one`; a split hook copying `hardware.feedback`. When `tap(1)`. Then `splits` holds one split with `cap == .seconds(10)` and the arrival `first: SplitApp(Notes, .running(animates: true, followed: false))`, `second: SplitApp(Safari, .running(animates: true, followed: false))`. `hardware.feedback == [Trackpad.macBook14.id]`, and the hook saw that one pulse already. `broughtToFront`, `launchAnimations` and the watches are empty. | R10 scenario 1 ("both come to front … one gesture haptic"); `aGestureForAnAppWithNoProcessBouncesInsteadOfFloatingAndPulsesFirst` (the pulse first); R13's 10 s; R17 (no grant, nothing followed) |
| T7 | R10, R19 | World | Given Notes and Safari on `.one`, no Accessibility, the animation on and the hide off unless said. When `tap(1)` with: (a) Notes running, Safari not; (b) Notes not running, Safari running; (c) neither running; (d) the animation off, Notes running, Safari not; (e) the animation off and the hide on, neither running; (f) Safari alone on `.two`, not running, `tap(2)` first, then `tap(1)` with Notes running; (g) Safari only `startProcess`ed, as a menu bar app or one still launching from the Dock. Then the arrival is: (a) Notes `.running(animates: true, followed: false)`, Safari `.launching(watch: .bouncing)`, and `bounces` is Safari's alone; (b) Notes `.launching(watch: .bouncing)`, Safari `.running(animates: true, followed: false)`, `bounces` Notes's alone; (c) both `.launching(watch: .bouncing)`, `bounces` Notes's then Safari's; (d) Notes `.running(animates: false, followed: false)`, Safari `.launching(watch: nil)`, no watch; (e) both `.launching(watch: .unseen)`, two watches and no bounce; (f) Safari `.alreadyLaunching`, and the watches hold Safari's one watch, unchanged; (g) Safari `.running(animates: true, followed: false)`. | R10 scenarios 2-4; R19 scenarios 1-2; domain *Launch bounce* ("Not running means macOS reports no process"); domain *Launch watch* (both settings off, nothing is watched; animation off with the hide on, unseen); domain *Launch bounce* ("keeps that one bounce"); `aGestureForAnAppWithAProcessFloatsWhateverKindOfProcessItIs` |
| T8 | R11 | World | Given Notes and Safari running, both on `.one`, Accessibility granted, `pointerDisplayAnswer == D1`, a placement hook copying `splits.count`. (a) `tap(1)`: placements are `[(B("Notes"), L(D1)), (B("Safari"), R(D1))]`, each recorded with `splits.count == 1`, and `pointerDisplayReads == 1`. (b) `tap(1)` again; the user moved Safari's window in between, which the model cannot see. Then there are four placements, the last two equal to the first two. (c) `pointerDisplayAnswer = D2`, `tap(1)`: the new pair is on `D2`. (d) `pointerDisplayAnswer = nil`, `tap(1)`: one more split is recorded, and no placement. | R11 scenarios 1-3 and "Each fire MUST place both windows again"; plan 017's contract (the app opens before anything else) |
| T9 | R13 | World | Given Notes running, Safari not, both on `.one`, Accessibility granted, `D1`, the animation on. When `tap(1)`: placements are `[(Notes, L(D1))]` before any report. When Safari reports `.finishedLaunching`: still one. When `pointerDisplayAnswer = D2` and Safari reports `.windowShown`: placements are `[(Notes, L(D1)), (Safari, R(D1))]`, `pointerDisplayReads == 1`, and Safari's launch ended with `.launchAnimation`. | R13 scenario 1 ("placed in the left half at once"; "when Safari's first window shows, it is placed in the right half"); R13 "The half is on the display chosen when the gesture fired" |
| T10 | R13 | World | Given T9's world. (a) `tap(1)`; Safari reports `.ranOut` (the cap passed on the watch's clock), then `.windowShown`: placements are Notes's alone. (b) In a fresh world, `tap(1)`; Safari reports `.finishedLaunching`: Safari's watch has `limits == [.seconds(2)]`; then `.ranOut`, then `.windowShown`: placements are Notes's alone. (c) The split's `cap == .seconds(10)`. | R13 scenario 2 ("shows 12 s later … not moved") and its 10 s; domain *Launch watch* (2 seconds after the app finished starting up, 10 seconds after the gesture) |
| T11 | R13, R19 | World | Given Notes and Safari running, Safari with no window, both on `.one`, Accessibility granted, `D1`, the hide on. When `tap(1)`. Then both arrive `.running(animates: true, followed: true)`, the watches hold one non-bouncing watch for each with cap 10 s, and placements are `[(Notes, L(D1)), (Safari, R(D1))]`; Safari's finds no window, which is the adapter's business. When Safari reports `.finishedLaunching`: its watch has `limits == [.seconds(2)]`. When Safari reports `.windowShown`: placements gain `(Safari, R(D1))`, `launchAnimations` stays empty, `splits` stays one, and `kept` holds only the hide sent at the tap. In a fresh world where Safari reports `.ranOut` before `.windowShown`, Safari is not placed a second time. | R13 scenario 3 ("that window is placed in the right half"); the design's `.followed` kind ("never hides"); R19 (each app plays its effect once) |
| T12 | R13 | World | Given Notes running and Safari not, both on `.one`; Mail running, alone on `.two`; Calendar and Music running, split on `.three`; Maps alone on `.five`, trashed; Accessibility granted, `D1`. (a) `tap(1)`, `tap(2)`; Safari reports `.finishedLaunching` and `.windowShown`. Then Safari is not placed, Notes's follow ended at the second tap with `.quietFade`, and Safari's bounce still ended with `.launchAnimation`. (b) `tap(1)`, `tap(3)`; Safari's window shows. Then Safari is not placed, while Calendar and Music were placed at the third tap. (c) `tap(1)`; `pointerDisplayAnswer = D2`; `tap(1)`; Safari's window shows. Then Safari is placed once, on `R(D2)`. (d) The design's reading, O9: `tap(1)`, then an unassigned `tap(4)`, `tap(5)` (missing app) and a swipe lift on Mail; Safari's window shows. Then Safari is placed on `R(D1)`. Row (d) flips if O9 is answered "every tap cancels". | R13 scenario 4 and "A later gesture of any kind firing MUST cancel the pending placements"; R13 "the display chosen when the gesture fired"; O9 and `fire`'s silent contract |
| T13 | R13, R19 | World | Given Notes and Safari running with windows, both on `.one`, Safari also alone on `.two`, Accessibility granted, the animation on. When `tap(1)`, then `tap(2)`. Then the second tap ends Safari's follow with `.quietFade` and takes today's one-app path: `broughtToFront == [Safari]` and `launchAnimations == [Safari]`. When Safari then reports `.windowShown`, Safari is not placed again. | domain *Launch animation* ("every gesture for a running app plays its own"); R13 (a later gesture cancels); the one-app rows of `LaunchBounceFiringTests` |
| T14 | R17 | World | Given Notes running, Safari not, both on `.one`, Accessibility not granted, the animation on. When `tap(1)`, then Safari reports `.finishedLaunching` and `.windowShown`. Then `pointerDisplayReads == 0` and placements are empty after every step. The arrival is Notes `.running(animates: true, followed: false)` and Safari `.launching(watch: .bouncing)`. `launcher.showsAccessibilityHint` is true. `Copy.accessibilityHint == "Allow Accessibility access to make trackpad gestures work reliably."`. `inactiveNotice` and `screenRecordingHint` are what they were before the tap. | R17 scenarios 1-2 |
| T15 | R18 | World | Given Mail, Notes and Safari running, Mail frontmost; Accessibility granted, `D1`, the hide and the animation on; Notes and Safari on `.one`. Each case has a twin world, set up the same way, whose `.one` holds the present app alone. Cases: (a) Safari trashed; (b) Notes trashed; (c) both trashed, the twin's Notes trashed too; (d) Safari trashed and Notes not running. When `tap(1)` in both worlds. Then, compared by bundle identifier, both worlds recorded the same `broughtToFront`, `launchAnimations`, watches, `kept` and `hardware.feedback`. The split world recorded no split, no placement and `pointerDisplayReads == 0`. In (c) both recorded nothing at all, feedback included. | R18 scenarios 1-3 ("exactly as a one-app gesture would, moving no window"; "what a gesture with a missing app does today"); the twin one-app world is the oracle |
| T16 | R21 | World | Given Mail, Notes and Safari running, Mail frontmost, the hide on, no Accessibility; Notes and Safari on `.one`; a hide hook copying `splits.count`. When `tap(1)`. Then `kept == [KeptApps(front: B("Notes"), beside: B("Safari"))]`, recorded with `splits.count == 1`; `hidesOthers == [B("Notes")]`; `hiddenApps == [B("Mail")]`. | R21 scenario 1 |
| T17 | R21 | World | Given Mail and Notes running, Safari not, Mail frontmost, the hide on; Notes and Safari on `.one`. (a) `tap(1)`: `kept` is empty. `makeFrontmost("Notes")`; Safari reports `.finishedLaunching`, then `.windowShown`: `kept == [KeptApps(front: B("Notes"), beside: B("Safari"))]` and `hiddenApps == [B("Mail")]`. After every step, `hiddenApps` holds neither Notes nor Safari. (b) As (a), but Mail is frontmost when Safari's window shows: nothing hides. (c) `tap(1)`; the hide turned off; `tap(1)` again; Notes frontmost; Safari's window shows: nothing hides. | R21 scenario 2 ("Mail hides once Safari's window shows, and Notes is never hidden"); domain *Hide background apps setting* ("only if the app is the frontmost app at that moment"; "a repeated gesture for a launching app takes the switch's value then") |
| T18 | R21 | World | Given Mail running and frontmost, the hide on, no Accessibility; Notes and Safari on `.one`. (a) Notes not running, Safari running: `tap(1)` hides nothing; Notes frontmost; Notes's window shows: one hide, keeping Notes and Safari. (b) Neither running: `tap(1)`; Notes frontmost; Safari's window shows first: nothing hides; then Notes's window shows: one hide, keeping both. (c) Neither running: Notes's window shows first: one hide; then Safari's: a second hide, keeping both. (d) Neither running: Safari's window shows, then Notes reports `.finishedLaunching` and `.ranOut`: nothing ever hides. In every case, `hiddenApps` never holds Notes or Safari. | R21 ("an app that is launching hides the others once its window shows, and never hides the other app of the gesture"); plan 032 root cause 1 (nothing hides while the active app shows nothing), which the design keeps; domain *Hide background apps setting* ("shows no window within the watch's limits … hides nothing") |
| T19 | R22 | World | Given `switcherWorld(apps: ["Safari", "Mail", "Notes", "Music"], frontmost: "Music")`, all running in that order. (a) Notes and Safari on `.one`: a swipe's row is `["Music", "Safari", "Mail", "Notes"]`. (b) Safari also alone on `.two`: the row is `["Music", "Mail", "Notes"]`. | R22 scenarios 1-2; the running order is the row's most-recently-used order (`anAssignedAppIsLeftOutAndTheLiftOpensTheNextOneInTheRow`) |
| T20 | R1, R2, R5 | SecondPickerBench | Given slot `.add`, unavailable `B("Notes")`, over `PickerBench.names`. The plus button shows, 16 × 16 pt, with tooltip and accessibility label "Add a second app"; the minus button and the picker are hidden. When the plus button is pressed, the bench's `popUp` is handed one menu and the plus button. That menu's titles equal those of a `PickerBench(showing: nil)` over the same apps. No item is on; Notes's item has `isEnabled == false` and every other is enabled; `autoenablesItems == false`. When "Safari" is picked from it: `chosen == [Safari]`. At once the minus button and the picker show and the plus hides; the picker shows "Safari" and plays the shipped pick animation on its icon (`expectPlaysPickAnimation`). A following render of `.app(.present(Safari))` leaves that same animation running. | R1 scenario 1; R2 scenario 1 ("the minus button and Safari's picker"; "the plus button is gone"); R5 scenario 1; design reference (16 × 16 pt; "Add a second app"); the first picker's menu is the oracle; F10 (renders never play) |
| T21 | R2, R4 | SecondPickerBench | (a) Slot `.add`: "None" picked from the plus menu. (b) Slot `.app(.present(Safari))`: "None" picked from the picker's menu. Then, in both, no closure ran, the view shows what it showed, and no layer animates. | R2 "Picking *None* there MUST change nothing, exactly like closing the menu"; R4 scenario 2 |
| T22 | R2, R5 | SecondPickerBench | Given slot `.add`. When "Other…" is picked from the plus menu: `otherCalls == 1`, and nothing changes. (a) The completion gets Tool's entry: the picker shows Tool and plays the pick animation, and the plus hides. (b) The completion gets nil, as the model answers for the first app chosen through Other…: the plus still shows, and nothing animates. | R2 scenario 2; R5 scenario 2 |
| T23 | R4, R5 | SecondPickerBench | Given slot `.app(.present(Safari))`, unavailable `B("Notes")`. The picker's menu has the first picker's titles, None included, with Safari on and Notes disabled. When "Mail" is picked: `chosen == [Mail]`, and the picker shows Mail and plays the pick animation on its icon. | R4 scenario 1 and "MUST list what the first picker lists, *None* included"; R5 scenario 1 (the second picker too) |
| T24 | R1, R6 | SecondPickerBench | Given slot `.app(.present(Safari))`. The minus button shows, 16 × 16 pt, left of the picker, with tooltip and accessibility label "Remove the second app"; the plus hides. When the minus button is pressed: `removed == 1`, and at once the plus shows while the minus and the picker hide. A render of `.add` then animates nothing. `Copy.addSecondApp == "Add a second app"` and `Copy.removeSecondApp == "Remove the second app"`. | R6 scenario; design reference (line 2 is the minus button, then the picker; 16 × 16 pt; the two labels) |
| T25 | R2, R4, R18 | SecondPickerBench | Renders, with animations cleared between them: `.add`; `.app(.present(Safari))`; `.app(.missing(name: "Safari", bundleID: B("Safari")))`; `.app(.present(Safari))`; `.app(.present(App))`, where App's name is 40 characters. Then no render animates any layer. The missing render shows "Safari" in `tertiaryLabelColor`, with tooltip "Safari not found" and no icon, exactly as `PickerBench` renders `.missing(name: "Safari")`. The long name's picker is at most `AppPicker.maxWidth` wide, and its title ends with "…". | R18 scenario 4 ("as a missing first app shows"); design reference ("at most 128 pt wide … cut short at the end, as today"); F10; the first picker's missing render is the oracle |
| T26 | R4, R7 | PickerBench | (a) Showing Notes, with `chooseNone`: "None" picked runs `chooseNone` once and `choose` never; "Choose app…" shows at once with the icon hidden; nothing animates. (b) With no `chooseNone`: "None" picked runs nothing, and Notes still shows. (c) With `unavailable: B("Mail")`: Mail's item is disabled and Notes's is on. | R7 scenario; `pickingNoneShowsChooseAppAtOnceWithoutAnimation`; R4's inert *None*, which the second picker gets from (b) |
| T27 | R10, R12, R19, R20 | SplitSteps (pure) | With N = Notes first and S = Safari second; the second and third arguments of `open` are `activates` and `watched`, and every other step's side is its `toward`. (1) Both `.running(animates: true, followed: true)` → `[open(S, true, true), open(N, true, true), startWatch(N), startWatch(S), launchAnimation(N, .left), launchAnimation(S, .right)]`. (2) N `.running(animates: true, followed: false)`, S `.launching(watch: .bouncing)` → `[open(S, false, true), open(N, true, false), startWatch(S), bounce(S, .right), launchAnimation(N, .left)]`. (3) N `.launching(watch: .bouncing)`, S `.running(animates: true, followed: false)` → `[open(S, true, false), open(N, true, true), startWatch(N), bounce(N, .left), launchAnimation(S, .right)]`. (4) Both `.launching(watch: .bouncing)` → `[open(S, false, true), open(N, true, true), startWatch(N), startWatch(S), bounce(N, .left), bounce(S, .right)]`. (5) Both `.launching(watch: .unseen)` → (4)'s opens and `startWatch` steps only. (6) N `.running(animates: false, followed: false)`, S `.launching(watch: nil)` → `[open(S, false, false), open(N, true, false)]`. (7) N `.running(animates: true, followed: false)`, S `.alreadyLaunching` → `[open(S, false, false), open(N, true, false), launchAnimation(N, .left)]`. In every case both opens come before any other step, and Notes's comes last. | F17 (the last-opened app ends active); F18 (open the second, then the first: the first's front window on top, the second's above every other window of both); F20 (`activates = false` keeps a launching app out of the focus); plan 017 (an app opens before any watch, clock, layer or animation); R19 with F28 (bounces sit in start order, newest on the right, so Notes's is on the left); R20 |
| T28 | R11 | SplitHalves, LaunchDisplay (pure) | `primary` is `(0, 0, 1512, 982)` unless said. (a) `visible (0, 0, 1512, 949)` → left `(0, 33, 756, 949)`, right `(756, 33, 756, 949)`. (b) The Dock at the bottom, `visible (0, 70, 1512, 879)` → `(0, 33, 756, 879)` and `(756, 33, 756, 879)`. (c) Odd width: `primary (0, 0, 1511, 982)`, `visible (0, 0, 1511, 949)` → `(0, 33, 756, 949)` and `(756, 33, 755, 949)`. (d) Fractional: `visible (0, 69.5, 1512, 879.5)` → `(0, 33, 756, 879)` and `(756, 33, 756, 879)`. (e) A display to the right, `visible (1512, 0, 1920, 1055)` → `(1512, −73, 960, 1055)` and `(2472, −73, 960, 1055)`. (f) A display above, `visible (−524, 982, 2560, 1415)` → `(−524, −1415, 1280, 1415)` and `(756, −1415, 1280, 1415)`. In every case `right.minX == left.maxX`, the widths sum to the usable width, and the left width minus the right width is 0 or 1. (g) `LaunchDisplay.containing`, with `.builtIn` numbered 1 and `.external` numbered 2, answers 2 at (1000, 2410) and 1 at (700, 982). | `probes/screens.out` and `axplace2.out` ("halves L=(0.0, 33.0, 756.0, 949.0) R=(756.0, 33.0, 756.0, 949.0)"); F40's rule, worked by hand for (b) to (f), which O5 checks by hand (M4); R11 ("excludes the menu bar and the Dock"; "meet exactly in the middle, with no gap"; "the left half MUST take the extra point"); the design's "trimmed inward to whole points"; `LaunchFlightTests`' display fixtures and shared-edge rule |
| T29 | R11, R14 | FrontWindowPlacer.place over ScriptedPlacing | T28 (a)'s halves, `previous: nil`, `isLatest` always true, each call 1 ms, the window the app's main window. Each case gives its writes, then its outcome, which carries the window's final frame. (a) Left, a resizable window at `(200, 450, 500, 332)` → `[position(0, 33), size(756, 949)]`, `.placed((0, 33, 756, 949))`. (b) Right, a resizable window at `(260, 390, 800, 332)` → `[position(756, 33), size(756, 949)]`, `.placed((756, 33, 756, 949))`. (c) Right, minimum width 900, at `(260, 390, 900, 332)` → `[position(756, 33), size(756, 949), position(612, 33)]`, `.placed((612, 33, 900, 949))`. (d) Right, minimum width 900, with the halves of `visible (0, 0, 1400, 949)` and `primary (0, 0, 1400, 982)` → `[position(700, 33), size(700, 949), position(500, 33)]`, `.placed((500, 33, 900, 949))`: 900 pt wide, over the left half by 200 pt. (e) Left, a fixed 230 × 362 window at `(320, 300)` → `[position(0, 33), size(756, 949)]` with the size refused, `.placed((0, 33, 230, 362))`. (f) Right, the same fixed window → `[position(756, 33), size(756, 949), position(1282, 33)]`, `.placed((1282, 33, 230, 362))`. (g) Right, maximum width 500 → `[position(756, 33), size(756, 949), position(1012, 33)]`, `.placed((1012, 33, 500, 949))`. In every case the double's final frame equals the outcome's. | `probes/axplace.out` steps 1b and 6 (a fixed window refuses size with −25200 and takes position); `axplace2.out` A (x = 612); R14 scenarios 1-2 (Calculator at the top-left at its own size; 900 pt on a 1400 pt area, 200 pt over); R14 "the size closest to the half's that it allows" and "the second app's at its half's top-right corner" |
| T30 | R15, R16 | FrontWindowPlacer.place over ScriptedPlacing | (a) Right, a window in full screen at `(0, 0, 1512, 982)` → writes `[fullScreen(false), position(756, 33), size(756, 949)]`, `.placed((756, 33, 756, 949))`. (b) Left, a window in full screen whose frame is exactly `(0, 33, 756, 949)`, and also with `previous` equal to that frame → writes start with `fullScreen(false)`; never `.alreadyThere`. (c) Right, a full-screen window that refuses the exit → writes `[fullScreen(false)]` and no other call, `.refused`, its frame unchanged. | R15 ("MUST leave full screen first, then be placed"); `probes/axplace.out` 7a and `axplace2.out` C (full screen off, then placed at once; the frame held 3 s); the design's "a refused exit from full screen ends the sequence, so the window stays where it was" (R16) |
| T31 | R11, R14 | FrontWindowPlacer.place over ScriptedPlacing | (a) Left, a window at `(0, 33, 756, 949)` → no write, `.alreadyThere`. (b) Right, at `(756, 33, 756, 949)` → no write, `.alreadyThere`. (c) Left, a window the user moved to `(100, 200, 756, 949)` → `[position(0, 33), size(756, 949)]`. (d) Right, T29 (c)'s window at `(612, 33, 900, 949)` with `previous: (612, 33, 900, 949)` → no write, `.alreadyThere`. Likewise T29 (g)'s at `(1012, 33, 500, 949)` and T29 (e)'s at `(0, 33, 230, 362)`, each with its own frame as `previous`. (e) T29 (c)'s window dragged to `(100, 200, 900, 949)`, with the same `previous` → T29 (c)'s writes again. | R11 scenario 2 ("Each fire MUST place both windows again, even when the user moved them since"); the design's "Already there" (the half's frame, or the frame the last placing into the same half left); the frames of T29 |
| T32 | R16 | FrontWindowPlacer.place over ScriptedPlacing | T29 (c)'s window (the main window) and halves; a `ReadBudget` of 0.5 s from the double's clock at 0. (a) Every call into the app costs 100 ms: timeouts `[0.5, 0.4, 0.3, 0.2, 0.1]` for `mainWindow`, `state`, `setPosition`, `setSize` and `size`; no sixth call; writes `[position(756, 33), size(756, 949)]`; `.unanswered`. (b) Every call costs 99 ms: six calls, the last with a timeout of 0.005 s, and the writes end with `position(612, 33)`; no seventh call, since no time is left for the read-back, and the outcome is `.placed((612, 33, 900, 949))`, the frame asked for. (b′) Every call costs 1 ms and the double moves the window's origin by one point after the last write, as macOS may (F35): a seventh call, `state`, and the outcome carries the frame read back. (c) `mainWindow` costs 600 ms → `.unanswered`, `intoApp == ["mainWindow"]`. (d) `state` answers `cannotComplete` → `.unanswered`, `intoApp == ["mainWindow", "state"]`, no write. (e) `setPosition` answers `cannotComplete` → no further call, `.unanswered`. (f) `setPosition` is refused with another error → no further call, `.refused`, the window's frame unchanged. (g) `mainWindow` answers nil and `windows` answers none → `.noWindow`, no other call. Every case returns its outcome, and none throws. | the design's 0.5 s budget, "`cannotComplete`, or no time left, ends it with no further call" and "A refused position … ends the sequence, so the window stays where it was"; R16 scenario ("the other window stays where it was"; "MUST NOT show any error"); `ReadBudgetTests` (no timeout at the deadline itself); `AppWindowReadTests`' scripted-clock rows |
| T33 | R13, R16 | FrontWindowPlacer.place over ScriptedPlacing | T29 (b)'s window; `isLatest` reads a flag that the double's hooks flip, standing for a newer placing of the same process issued mid-sequence. (a) Flipped inside `setPosition` → `setPosition` is the last call into the app, writes `[position(756, 33)]`, `.superseded`. (b) False from the start → no call into the app at all, `.superseded`. (c) Flipped inside `mainWindow` → `intoApp == ["mainWindow"]`, `.superseded`. (d) T30 (a)'s window, flipped inside `setFullScreen` → writes `[fullScreen(false)]`, `.superseded`. | the design's "Before every call into the app, a work item checks that its ticket is still the latest for that process"; R13 (a later gesture cancels pending placements) |
| T34 | R20 | LaunchFlights (pure) | For each draw in `LaunchFlightTests.draws`: `next(draw:reduceMotion: false, toward: .left)`, staged at the built-in display's middle, ends left of its start, and `toward: .right` right of it. Each drifts as far as an undirected flight drawn at the same magnitude. Streaks: random −0.6, random −0.6, then `toward: .left` at −0.6 → left, not flipped; random −0.6, `toward: .left`, random −0.6 → the third is left, since the directed flight fed no streak. With Reduce motion and a side, the icon fades in place. | R20 ("MUST sway to the left … never at random"); `LaunchFlightTests`' undirected flights are the oracle for size; the design's "a directed flight neither reads nor feeds the streak" and its tradeoff |
| T35 | R21 | BackgroundHider over a staged Apps | A stage with Notes and Safari, and injected waits. (a) `hideOthers(keeping: KeptApps(front: Notes, beside: Safari))`, with Notes frontmost and shown: on the next turn one hide runs, handed both Notes and Safari as kept. (b) Waits of 300 ms and 300 ms: after the first pass Safari becomes frontmost; 450 ms later there is still one hide; Notes becomes frontmost again; 300 ms later there is a second hide. With Mail frontmost instead, no later hide (`aUserWhoMovedOnKeepsWhatTheySee`). (c) Safari frontmost and shown at the call: nothing hides until Notes activates and shows, then one hide. (d) `KeptApps(front: Notes, beside: Notes)`: the hide keeps Notes alone. | the design's decision 5 ("keeps its one goal (`front`) and its arrival rule … A pass that finds `beside` frontmost hides nothing and carries on"); `KeptApps` ("Never the same app twice"); R21 scenario 1; `BackgroundHiderTests`' staging |
| T36 | R12 | FrontWindowPlacer.place over ScriptedPlacing | T28 (a)'s halves, side `.right`, resizable windows. (a) Windows W1 and W2, both standard, with W2 the main window → every write touches W2. (b) No main window; windows W1 (not standard), W2 (standard, minimised) and W3 (standard) → every write touches W3. (c) No main window; one window, standard and minimised → `.noWindow`, no write. (d) `mainWindow` answers `cannotComplete` → `.unanswered`, `intoApp == ["mainWindow"]`. | the design's step 1 ("the main window, else the first standard window that is not minimised"); F38 (a minimised window is not the main window); F39 (an app never active answers its frontmost window as main); glossary *Front window* |
| T37 | R13, R16 | FrontWindowPlacer, test initializer, over ScriptedPlacing | Given the instance screens (with `D2`) and a process lookup answering Safari 101 and Notes 102; resizable windows; Safari's first `mainWindow` call held. (a) `place(Safari, in: R(D1))` returns on the main actor while the call is still held. (b) While it is held, `place(Notes, in: L(D1))` completes: Notes's window ends at `(0, 33, 756, 949)`. (c) While it is held, `place(Safari, in: L(D1))`; then the hold is released. The older work item makes no call after its held one returns, every call of the newer one comes after that return, and Safari's window ends at `(0, 33, 756, 949)`. (d) `place(Notes, in: L(DisplayID(rawValue: 3)))`, a display the screens do not list → `place` answers false, and no call into any app. (e) The lookup answers nil for Mail, and the test process's own pid for Calendar; placing either → `place` answers false, and no call into any app. (f) `place(Notes, in: L(D2))` → Notes's window ends at `(1512, −73, 960, 1055)`. | the design's decision 4 ("One process's work items run one at a time … Before every call into the app, a work item checks that its ticket is still the latest … a newer placing always runs alone, with no older write after it"; "Returns at once"); `place(_:in:)`'s "gone → nothing" and "none, or this process → nothing"; R13 ("The other app's window MUST be placed at once and not wait"); T28 (a) and (e) for the frames |
| T38 | R11, R14 | FrontWindowPlacer, test initializer, over ScriptedPlacing | T37's instance, with Safari's window at `(260, 390, 900, 332)`, minimum width 900. When `place(Safari, in: R(D1))` runs twice, each awaited. Then the first makes T29 (c)'s writes, and the second makes no write. When the script moves the window to `(100, 200, 900, 949)` and Safari is placed into `R(D1)` again: T29 (c)'s writes again. When `place(Safari, in: L(D1))`: writes `[position(0, 33), size(756, 949)]`, and the window ends at `(0, 33, 900, 949)`. | the design's "Already there" (the frame this process's last placing into the same half left) and `previous`'s "into the same half"; R11 scenario 2; T29 (c)'s writes |

### Verified without a test

- **R3, R6: the refit and the row's lines.** A read shows `SettingsShell.Fit` holding `twoAppRows`, counted from `launcher.rows` with `lineCount == 2` inside its `Observations` closure. It also shows `GestureRowView` choosing its `AnyLayout` and its `formRowContent(lines:)` from `row.lineCount`. M1 checks the heights, the identity of the second slot's view and the refit.
- **R9: `Build1018Settings` is 1.0.19's record coding, and `AssignedApp` is unchanged.** The "Version 1.0.19" commit is `cd9bf28`; this clone has no `v1.0.19` tag. `git diff v1.0.18 cd9bf28 -- LauncherKit/Sources/LauncherCore/Settings.swift` only adds `SettingsStore`'s External trackpad corner members and `SavedCorner`, and changes no stored field and no decode line. `git diff v1.0.18 cd9bf28 -- LauncherKit/Sources/LauncherCore/Apps.swift LauncherKit/Sources/LauncherCore/Gesture.swift` prints nothing, which was so on 2026-11-13. `git diff main -- LauncherKit/Sources/LauncherCore/Apps.swift` leaves `AssignedApp` untouched. The `PersistenceTests` rows on `savedSettings`, `Build106Settings` and `Build1018Settings` stay green.
- **R10: the runner.** A read of `WorkspaceActions.bringToFront(_:cap:)` shows that it runs `SplitSteps(split).steps` in order and does nothing else, and that `.open(app, activates:, watched:)` sets `OpenConfiguration.activates` from the step. `SourcePolicyTests` stays green with `.activate()` and `ignoringOtherApps` confined as today. M3 checks the real focus.
- **R20: a bounce's side.** A read shows `BounceOverlay` keeping `toward` from `start(_:toward:)` in its bouncing record and passing it to `LaunchOverlay.play(…toward:)` on a `.launchAnimation` ending. It also shows `LaunchOverlay` passing it to `LaunchFlights.next(…toward:)`. M3 step 2 checks it.
- **R11, R14, R15, R16: confinement and silence.** `SourcePolicyTests` stays green with the design's edits: `AXUIElementSetAttributeValue` leaves `banned` and is confined to `FrontWindowPlacer.swift`; `AXUIElement` is confined to `AppWindowReader.swift`, `LaunchWatch.swift` and `FrontWindowPlacer.swift`; `kAXPressAction` stays banned. `grep -rln "alreadyThere\|superseded" LauncherKit/Sources` lists only `FrontWindowPlacer.swift`, so the placer's `Outcome` stays inside that file. `placeFrontWindow(of:in:)` returns nothing and takes no closure.
- **R17: no new message.** `git diff main -- LauncherKit/Sources/LauncherCore/Copy.swift` adds exactly `addSecondApp` and `removeSecondApp`. `CopyTests.theAccessibilityHintAsksForAccessAndBothHintsShareOneButtonTitle` stays green, unedited.
- **R13: the watch reads the window list first.** A read of `LaunchWatch.finished` shows `listedWindows(of:)` read before any Accessibility call, and `.windowShown` reported with no Accessibility call when a window is listed. `LaunchWatchLookTests` and `LaunchWatchClockTests` stay green.
- **M1: R1, R2, R3, R5, R6, R7, R18, the settings window, by hand.** On the Debug build (`make run`):
  1. Set the 2-finger gesture to Music and leave the 3-finger one unassigned. Expected: the 2-finger row shows Music's picker, then a grey `plus.circle.fill`, 16 × 16 pt, 12 pt after the chevron badge, whose tooltip reads "Add a second app"; the 3-finger row has no plus. The row matches `design/one-app-row-with-plus.png`.
  2. Set the 1-finger gesture to Notes. In Accessibility Inspector, note the settings window's `AXSize` height. Press the 1-finger row's plus. Expected: a menu opens at the plus, with the recent apps, the other installed apps, *Other…* and *None*; Notes is greyed and does not respond to a click; nothing is checked.
  3. Pick Safari. Expected: the row becomes two lines, Notes's picker on line 1 and, on line 2, the minus button then Safari's picker, right-aligned, the pickers' trailing edges lined up. Safari's icon jumps in from below on line 2. The illustration stays vertically centred. The row is 30 pt taller than a one-app row: 76 pt against 46 pt, or 78 against 48 if O1 is answered the other way. The window's height grew by exactly 30 pt. The row matches `design/two-app-row-with-minus.png`.
  4. In Safari's picker, pick *None*. Expected: nothing changes and nothing animates. Pick Mail. Expected: Mail replaces Safari, and its icon jumps in.
  5. Press the minus button. Expected: one line with the plus again, and the window's height is back to step 2's.
  6. Add Safari again, then pick *None* in the first picker. Expected: *Choose app…*, no plus, one line.
  7. Add Safari again, close the window, move Safari to the Trash and reopen the window. Expected: Safari's name greyed on line 2, with the tooltip "Safari not found". Put Safari back.
  8. Remove Safari. Press the plus, choose *Other…* and pick Notes in /System/Applications. Expected: nothing changes. Press the plus, choose *Other…* and pick an app in ~/Downloads. Expected: it becomes the second app, with the pick animation.
  9. Turn on Reduce motion and pick a second app from the plus. Expected: the icon appears at once.
- **M2: R10, R11, R12, R14, R15, R16, placing real windows, by hand.** One display, the Dock shown at the bottom, Accessibility granted, the 1-finger gesture holding Notes and Safari:
  1. Notes and Safari running behind Mail, one window each, anywhere; fire. Expected: one haptic; Notes is active (its name in the menu bar); Notes's window fills the left half of the area between the menu bar and the Dock, and Safari's the right half; a zoomed screenshot of the seam shows no gap and no overlap.
  2. Drag Safari's window elsewhere; fire. Expected: it is back in the right half.
  3. Open a second Notes window, drag it over the right half, then click Notes's first window; fire. Expected: both placed windows are fully visible.
  4. With Calculator as the first app; fire. Expected: Calculator's window sits at the left half's top-left corner at its own size, and Safari's fills the right half.
  5. With an app whose window cannot be narrower than 756 pt as the second app (check by dragging its edge first); fire. Expected: its window's right edge is on the display's right edge, over the left half.
  6. Put Safari's window in full screen; fire. Expected: it leaves full screen, fills the right half, and is still there 3 s later. Repeat with VS Code in full screen as the second app, and record whether it holds (O2).
  7. `kill -STOP` Safari's process; fire, then fire the 2-finger gesture at once. Expected: Notes's window is placed, Safari's stays where it was, no alert shows, and the 2-finger gesture answers at once. Then `kill -CONT` it.
  8. Minimise Safari's window; fire. Expected: it is restored and placed in the right half.
  9. Give Notes a second window, then hide Notes with ⌘H; fire. Expected: Notes shows already in the left half, with no visible jump, and neither Notes window covers Safari's placed window.
- **M3: R10, R12, R13, R19, R20, R21, launches, effects and hides, by hand.** Accessibility granted, the animation on, the 1-finger gesture holding Notes and Safari, Mail on the 2-finger gesture:
  1. Quit Safari, with Notes running and two Notes windows, the back one over the right half; fire. Expected: Notes is active at once and its icon floats away swaying left; Safari bounces; when Safari's window shows it fills the right half above Notes's back window, and Notes stays active (a typed character lands in Notes).
  2. Quit both; fire. Expected: two bounces side by side, Notes's on the left; each ends floating away toward its own side; Notes becomes active when it finishes launching; each window lands in its half, and both are fully visible, also when Notes restores several windows.
  3. Quit Notes, with Safari running; fire. Expected: Safari comes to front and fills the right half at once; Notes becomes active when it finishes launching, and fills the left half.
  4. Both running; fire five times. Expected: Notes's icon sways left and Safari's right every time.
  5. Close every Safari window, leaving Safari running; fire. Expected: Safari opens a window, which fills the right half.
  6. Quit Safari; fire, then fire the 2-finger gesture before Safari's window shows. Expected: Safari's window, when it shows, is not moved.
  7. Turn the hide setting on, with Mail, Notes and Safari running; fire. Expected: Mail hides, and Notes and Safari stay side by side. Quit Safari; fire. Expected: Mail hides once Safari's window shows, and Notes never hides.
- **M4: R11, two displays, by hand (O5).**
  1. Notes's window on display A, the pointer on display B; fire. Expected: both windows fill B's halves, below B's menu bar.
  2. In *System Settings → Displays → Arrange*, put B left of A, then above A, and repeat step 1 each time. Expected: the same.
  3. Quit Safari; fire with the pointer on A, then move the pointer to B before Safari's window shows. Expected: Safari's window fills A's right half.
- **M5: R9, durability and real versions, by hand.**
  1. On the Debug build, set the 1-finger gesture to Notes and Safari; at once `kill -9` the process; `make run`. Expected: the row shows Notes and Safari.
  2. With a Release build in /Applications and starting at login on, restart the Mac. Expected: after login, the 1-finger gesture brings both apps.
  3. Install v1.0.18 from its release disk image into /Applications, set the 1-finger gesture to Notes, and quit; install this branch's Release build over it and open it. Expected: the 1-finger row shows Notes with the plus, and every setting is kept.
  4. With Notes and Safari on the 1-finger gesture in this build, install the old build over it and open it. Expected: every setting is kept, and the 1-finger gesture holds Notes. Turn *Switch recent* off there and quit; install this build again. Expected: the 1-finger gesture holds Notes alone, and *Switch recent* is off.
- **M6: R17, without Accessibility, by hand.** Run `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp.debug`, then relaunch the Debug build without granting. With Notes and Safari running, fire the split gesture. Expected: both come to front, Notes is active, and no window moves or resizes. The settings window shows the Accessibility hint with "Allow Accessibility access to make trackpad gestures work reliably." and no other message.
- **M7: R21, plan 032's hide stress run with two kept apps, by hand.** With the hide setting on and Mail, Notes, Safari and Calendar running: 30 times, click Calendar's window, then fire the split gesture. Expected after each: Notes is active, Notes and Safari are on screen, and Mail and Calendar are hidden; no run ends with a third app in front.

## Slices

There are four slices, each landing green on the quick gate. S1 lets a gesture hold a second app, end to end in the settings window and the record; firing still brings the first app alone. S2 makes a split gesture bring both apps to front, with their effects and hides. S3 places the running apps' windows at the gesture. S4 places windows that show later, and cancels pending placements.

### S1: A gesture can hold a second app

**What to build:** in the settings window, a one-app row shows the plus button. Its menu makes a second app, which shows on a second line with the minus button and its own picker. The minus button removes it. *None* on the first picker clears both apps, and changing the first app keeps the second. No gesture ever holds one app twice. A second app is saved at once in the one record, and survives a relaunch and an upgrade. The switcher leaves out only apps a gesture holds alone. Until S2, firing a gesture that holds two apps brings its first app alone, through `Assignment.first`. The pieces:
- `Assignment` with its wire form, `Settings.assignments: [Gesture: Assignment]`, and `Settings.oneAppBundleIDs` replacing `assignedBundleIDs`;
- `GestureRow.Apps`, `Held`, `SecondSlot`, and the derived `app`, `second`, `firstBundleID` and `lineCount`;
- `AppItemState.unavailable` and `pickerMenu(checking:unavailable:)`;
- `setAssignment`, `setSecondApp` and `removeSecondApp`, and `resolveRows` preparing second apps' launch animations;
- `Copy.addSecondApp` and `Copy.removeSecondApp`;
- `AppPicker`'s non-optional `choose`, `chooseNone` and `unavailable`, done first as a prefactor that changes nothing;
- `SecondAppPicker`; `GestureRowView`'s `AnyLayout` and `formRowContent(lines:)`; `SettingsShell.Fit.twoAppRows`; `iconTargets` and `canPreviewPickAnimation` reading second apps;
- the test-side `World.split(_:_:on:)` and `SecondPickerBench`, and the persistence rows against `Build1018Settings`, which is 1.0.19's record coding.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, R22. R18's picker part: a missing second app shows greyed. R19's part: a second app's launch animation is prepared.

**Test scenarios:** T1, T2, T3, T4, T5, T19, T20, T21, T22, T23, T24, T25, T26.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-data`, `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-macos`

- [ ] The quick gate is green. Existing rows change only as Strategy lists for S1, and `AppPickerTests`, `PersistenceTests`, `AppResolutionTests` and `SwitcherAssignedAppsTests` assert what they asserted before.
- [ ] The checks "R3, R6: the refit and the row's lines" and "R9: `Build1018Settings` is 1.0.19's record coding, and `AssignedApp` is unchanged" pass.
- [ ] M1 passes by hand, and so do M5 steps 1, 3 and 4.
- [ ] The `docs/domain-model.md` entries *First app*, *Second app*, *Assignment*, *Gesture row*, *App picker*, *Pick animation*, *Settings window* and *Switcher* match what this slice built. Where the build departs from an entry, the entry is corrected. `docs/product-overview.md` takes the plan's *Switcher* wording.

### S2: A split gesture brings both apps to front

**What to build:** firing a gesture that holds two present apps brings both to front with one haptic, the first app active. A second app still launching never takes the focus. Each app plays the effect it would play alone, swaying toward its side, and two bounces sit side by side, the first app's on the left. With the hide setting on, every app but the two hides, and a launching app hides the others only once the first app has its window. When one app is missing, the present one is brought to front exactly as a one-app gesture brings it. No window moves yet. The pieces:
- the prefactor first, changing nothing: `hideOtherApps(than:)` becomes `hideOtherApps(keeping: KeptApps(front:))` in the port, both adapters and `BackgroundHider`, with `hidesOthers` derived in the fake;
- `Assignment.target(locate:)` and `GestureTarget`; `SplitSide`, `SplitApp`, `SplitArrival`; `KeptApps` with `hides(onWindowOf:frontmost:frontStillWaits:)`;
- `SystemActions.bringToFront(_:cap:)` on both adapters, `SplitSteps` and its runner;
- `WatchedLaunch.hidesOnWindow`; `fire`, `splitToFront` with no display (`followed` is false), and `progress`'s hide;
- `LaunchFlights.next(…toward:)`, `LaunchOverlay.play(for:toward:)`, and `BounceOverlay.start(_:toward:)` keeping the side for its ending;
- `BackgroundHider.hideOthers(keeping:)` and its pass rule for `beside`.

**Blocked by:** S1.

**Requirements:** R10, R18's fallback, R19, R20, R21. R12's part: the open order.

**Test scenarios:** T6, T7, T15, T16, T17, T18, T27, T34, T35.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:swift-concurrency`

- [ ] The prefactor lands with the quick gate green and `HideBackgroundAppsTests` unedited.
- [ ] The quick gate is green, with `LaunchBounceFiringTests`, `HideBackgroundAppsTests`, `WatchedLaunchTests`, `LaunchFlightTests` and `BackgroundHiderTests` asserting what they asserted before.
- [ ] The checks "R10: the runner" and "R20: a bounce's side" pass.
- [ ] By hand, without placement yet: M3 steps 1 to 4 and 7, and M7, for focus, effects and hides.
- [ ] The `docs/domain-model.md` entries *Split gesture*, *Split to front* (its bring to front), *Bring to front*, *Target app*, *Launch animation*, *Launch bounce*, *Sway* and *Hide background apps setting* match what this slice built. Where the build departs from an entry, the entry is corrected. `docs/product-overview.md` takes the plan's *Hide background apps* wording.

### S3: A split gesture places its running apps' windows side by side

**What to build:** with the Accessibility permission, firing a split gesture places the front window of each app that runs: the first app's in the left half and the second's in the right half of the usable area of the display under the pointer, again at every fire. A full-screen window leaves full screen first. A window that cannot take its half's size keeps the closest size it allows, anchored at its half's outer top corner. Nothing shows an error. Without the permission, no display is read and nothing moves. The pieces:
- `DisplayID` (with a public initializer, as `WindowID` has), `ScreenHalf` and `SplitPlacing`;
- `Launcher.placing`, set at a split's fire and cleared by every gesture that is not silent, and the placement of each running app at fire;
- `pointerDisplay()` and `placeFrontWindow(of:in:)` on both adapters, and `LaunchDisplay.id`;
- `FrontWindowPlacer`: its tickets, its serial queue per process targeting its concurrent queue, the remembered frame per process and half, its test initializer `init(calls:screens:process:finished:)` with `PlacingScreens`, `place(_:in:)` answering whether it dispatched, and the static `place(_:in:side:previous:budget:calls:isLatest:)` with its `Outcome`;
- `SplitHalves`, `PlacingCalls` (with `mainWindow(of:)` and `windows(of:)`), `WindowState` and `AXPlacingCalls`;
- `SourcePolicyTests`' entries;
- the test-side `ScriptedPlacing`.

**Blocked by:** S2.

**Requirements:** R11, R14, R15, R16, R17. R12's part: the placer targets each app's front window. R13's part: a later placing of the same app stops an earlier one before its next write.

**Test scenarios:** T8, T14, T28, T29, T30, T31, T32, T33, T36, T37, T38.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:axiom-apple-docs`

- [ ] The quick gate is green, with `AppWindowReadTests`, `ReadBudgetTests` and `LaunchFlightTests` asserting what they asserted before.
- [ ] The checks "R11, R14, R15, R16: confinement and silence" and "R17: no new message" pass.
- [ ] M2 passes by hand, except steps 8 and 9, which need S4. M4 steps 1 and 2 and M6 pass too.
- [ ] `docs/architecture.md`'s placing matches what this slice built: Privacy's "used only to" list, its "everything works except" and its confinement sentence, and the Concurrency sentence on placing. So do `docs/domain-model.md`'s *Front window* and the placement in *Split to front*. Where the build departs, the doc is corrected. `docs/product-overview.md` takes the plan's *Gestures* and *Accessibility* wordings.

### S4: A window that shows later is placed, until a later gesture

**What to build:** when an app of a split gesture has no window on screen at the gesture (launching, windowless, hidden until then, or minimised), its first window is placed in its half when the launch watch first sees it, within the watch's limits, on the display chosen when the gesture fired. Running apps are followed by the launch watch for this. A later gesture that is not silent cancels the pending placements of earlier split gestures. The pieces:
- `WatchedLaunch.Kind` (`.launched`, `.followed`) and `.running(followed: true)` when a display was read;
- `stopPlacing()` ending every `.followed` record with `.quietFade`;
- the placement in `progress` on `.windowShown`;
- `LaunchWatch.finished` reading the window list first.

**Blocked by:** S3.

**Requirements:** R13.

**Test scenarios:** T9, T10, T11, T12, T13.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:swift-concurrency`

- [ ] The quick gate is green, with `LaunchBounceFiringTests`, `HideBackgroundAppsTests`, `LaunchWatchLookTests` and `LaunchWatchClockTests` asserting what they asserted before.
- [ ] The check "R13: the watch reads the window list first" passes.
- [ ] By hand: M3 steps 1, 2, 3, 5 and 6, M2 steps 8 and 9, and M4 step 3.
- [ ] `docs/domain-model.md`'s *Launch watch* matches what this slice built. So does `docs/architecture.md`, in two places: noticing the first window covers a running app a split gesture follows, and the push list includes "or a split gesture waits to place a window". Where the build departs, the doc is corrected.
