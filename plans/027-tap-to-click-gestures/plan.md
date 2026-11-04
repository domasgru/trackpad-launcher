# Plan: Gestures work with Tap to click and Look up on

## Problem statement

Gestures only work while *Tap to click* and *Look up: Tap with three fingers* are off for every connected trackpad. Many people use Tap to click every day. To use Trackpad Launcher they must give it up, and the settings window tells them to. People who refuse lose all five gestures, the swipe, the window swipe and the swap.

The rule dates from the first version, which had no permissions and so could not stop the system acting on a tap. Trackpad Launcher now holds the Accessibility permission and already blocks clicks and the system's Dock swipes under the thumb. Simply dropping the rule is not enough, though. A probe on a MacBook trackpad with Tap to click on showed what macOS does when the thumb rests in the anchor corner and other fingers tap:

- A 1-finger tap makes a left click as the finger lifts, just after the moment Trackpad Launcher sees the lift. Today blocking ends at that moment, so the click reaches apps.
- A 2-finger tap makes a right click 275–285 ms after the fingers lift. With Smart zoom on, macOS waits to rule out a double tap first.
- With Look up set to *Tap with three fingers*, a 3-finger tap shows Look up as the fingers lift, thumb or no thumb.
- With Smart zoom on, a double tap with 2 fingers zooms, thumb or no thumb. This happens today too, whatever Tap to click is set to.
- A tap after the thumb has rested more than 3 seconds clicks too. Today's blocking window has passed by then.
- A thumb tap alone in the corner, and the swap's thumb tap, make no click.

So each gesture would also click, right-click, show Look up or zoom wherever the pointer is.

## Solution

Tap to click and Look up no longer turn gestures off. A tap with other fingers under an anchored thumb is the gesture alone. macOS's click for it, its right click, its Look up and its Smart zoom never reach apps, even when they arrive up to 0.5 seconds after the fingers lift or after the thumb has rested a long time. Everywhere else Tap to click, Look up and Smart zoom work as usual. The settings window no longer asks the user to turn trackpad settings off. Blocking needs the Accessibility permission, so while Tap to click or Look up is on and the permission is missing, gestures stay off and the settings window says why. Without the permission, Smart zoom works as it does today.

## Requirements

### R1. Tap to click and Look up no longer turn gestures off
Gestures MUST be active while *Tap to click* or *Look up: Tap with three fingers* is on for any connected trackpad, as long as Trackpad Launcher has the Accessibility permission and a trackpad is connected. This holds for the built-in trackpad and for a Magic Trackpad alike. With the Accessibility permission, no system trackpad setting makes gestures inactive.

#### Scenario: Tap to click on, a gesture opens its app
- **GIVEN** Tap to click is on for the built-in trackpad, Trackpad Launcher has the Accessibility permission, and Mail is assigned to the 1-finger gesture
- **WHEN** the thumb rests in the anchor corner and one finger taps the middle of the pad
- **THEN** Mail comes to the front with the gesture haptic

#### Scenario: Both settings on, on a Magic Trackpad only
- **GIVEN** Tap to click and Look up: Tap with three fingers are on for a connected Magic Trackpad and off for the built-in one, with the Accessibility permission
- **WHEN** the user makes the 3-finger gesture on either trackpad
- **THEN** the gesture fires

#### Scenario: Swipe, window swipe and swap work with Tap to click on
- **GIVEN** Tap to click is on, with the Accessibility permission, and the swipe, window swipe and swap settings are on
- **WHEN** the user makes a swipe, then a window swipe, then a swap
- **THEN** each behaves exactly as it does with Tap to click off

#### Scenario: Turning Tap to click on while running
- **GIVEN** gestures are active, Tap to click is off, and Trackpad Launcher has the Accessibility permission
- **WHEN** the user turns Tap to click on in System Settings
- **THEN** gestures stay active, with no relaunch, and the next gesture fires

### R2. A tap under an anchored thumb never clicks
While Tap to click is on, a click that macOS makes for a tap of other fingers that landed while the thumb was anchored MUST NOT reach apps. This holds for every finger count, whether a left or a right click, whether or not the gesture has an app assigned, and however long the thumb has rested. It also holds for fingers that start a swipe or window swipe but lift as a tap. A click that arrives up to 0.5 seconds after those fingers lift MUST be blocked too, whether or not the thumb is still down.

This is a plain time window. Any click within it is blocked, including a deliberate tap elsewhere made within 0.5 seconds after the gesture. That cost is accepted. A press that starts in the window, such as a tap-and-hold drag with the Dragging setting on, is blocked whole, from press to release, so nothing is dragged and no button stays down.

#### Scenario: 1-finger tap opens its app and clicks nothing (the reported case)
- **GIVEN** Tap to click is on, Mail is assigned to the 1-finger gesture, and the pointer is over a button in another app
- **WHEN** the thumb rests in the anchor corner and one finger taps
- **THEN** Mail comes to the front and the button is not pressed

#### Scenario: 2-finger tap makes no right click
- **GIVEN** Tap to click is on and Smart zoom is on, so macOS sends the right click about 280 ms after the fingers lift
- **WHEN** the thumb rests in the anchor corner and two fingers tap
- **THEN** the 2-finger gesture fires and no context menu opens

#### Scenario: 2-finger tap with Smart zoom off
- **GIVEN** Tap to click is on and Smart zoom is off, so macOS sends the right click as the fingers lift
- **WHEN** the thumb rests in the anchor corner and two fingers tap
- **THEN** the 2-finger gesture fires and no context menu opens

#### Scenario: On a Magic Trackpad
- **GIVEN** Tap to click is on for a connected Magic Trackpad
- **WHEN** the thumb rests in the anchor corner of the Magic Trackpad and two fingers tap
- **THEN** the 2-finger gesture fires and no context menu opens

#### Scenario: Thumb lifts right after the tap
- **GIVEN** Tap to click is on
- **WHEN** the thumb rests in the anchor corner, two fingers tap, and the thumb lifts immediately after the fingers, before the right click arrives
- **THEN** the right click that macOS sends about 280 ms after the fingers lifted does not reach apps

#### Scenario: Unassigned gesture clicks nothing
- **GIVEN** Tap to click is on and no app is assigned to the 1-finger gesture
- **WHEN** the thumb rests in the anchor corner and one finger taps
- **THEN** nothing opens and no click reaches apps

#### Scenario: After a long thumb rest
- **GIVEN** Tap to click is on and Mail is assigned to the 1-finger gesture
- **WHEN** the thumb has rested in the anchor corner for 5 seconds and one finger taps
- **THEN** Mail comes to the front and no click reaches apps

#### Scenario: Several gestures in a row
- **GIVEN** Tap to click is on
- **WHEN** the thumb rests in the anchor corner and one finger taps three times, 0.3 seconds apart, so macOS would read them as a double click
- **THEN** the 1-finger gesture fires three times and no click or double click reaches apps

#### Scenario: A short swipe that lifts as a tap
- **GIVEN** Tap to click is on and the swipe setting is on
- **WHEN** the thumb rests in the anchor corner, two fingers land, slide just past 3 mm, and lift quickly
- **THEN** the swipe runs as usual and no context menu opens afterwards

#### Scenario: Swap makes no click or Look up
- **GIVEN** Tap to click is on, Look up is set to Tap with three fingers, and the swap setting is on
- **WHEN** two fingers rest on the pad, the thumb taps the anchor corner, and the fingers lift
- **THEN** the swap happens, no context menu opens, and no Look up panel appears

#### Scenario: A quick tap right after a gesture is lost
- **GIVEN** Tap to click is on
- **WHEN** the thumb rests in the anchor corner, one finger taps, the thumb lifts, and 0.3 seconds after the gesture's finger lifted one finger taps a button
- **THEN** the gesture fires and the button is not pressed, because the 0.5-second window swallows the tap by design

#### Scenario: Tap-and-hold drag started right after a gesture
- **GIVEN** Tap to click and Dragging are on
- **WHEN** the thumb rests in the anchor corner, one finger taps, then within 0.5 seconds touches again and moves
- **THEN** nothing is dragged and no button stays pressed

### R3. Tap to click works as usual everywhere else
Outside R2, a tap MUST click as macOS makes it. That covers a tap with no thumb anchored, and a click that arrives more than 0.5 seconds after a tap under the thumb once the thumb has lifted. A physical press (pressing the pad down until it clicks) is unchanged. Under an anchored thumb with another finger down, it is blocked during the first 3 seconds after the thumb landed, and reaches apps after that. During a swipe, window swipe or swap series, it is blocked throughout.

#### Scenario: Plain tap clicks
- **GIVEN** Tap to click is on and no thumb rests in the anchor corner
- **WHEN** one finger taps a button
- **THEN** the button is pressed

#### Scenario: Two-finger tap without the thumb right-clicks
- **GIVEN** Tap to click is on and no thumb rests in the anchor corner
- **WHEN** two fingers tap
- **THEN** the context menu opens

#### Scenario: Tap after a gesture, once the thumb has gone
- **GIVEN** Tap to click is on
- **WHEN** the thumb rests in the anchor corner, one finger taps, the thumb lifts, and one second later one finger taps a button
- **THEN** the gesture fires for the first tap and the button is pressed by the second

#### Scenario: Physical press after the thumb's first 3 seconds
- **GIVEN** Tap to click is on and the thumb has rested in the anchor corner for 4 seconds
- **WHEN** a finger presses the pad down until it clicks, and releases
- **THEN** the click reaches apps, as it does today with Tap to click off

### R4. A tap under an anchored thumb never shows Look up
The Look up that macOS shows for a 3-finger tap MUST NOT appear when that tap is under an anchored thumb, or when it arrives up to 0.5 seconds after the tap's fingers lift. A 3-finger tap with no thumb anchored MUST still show Look up. This holds whatever Tap to click is set to.

#### Scenario: 3-finger gesture shows no Look up
- **GIVEN** Look up is set to Tap with three fingers and the pointer is over a word
- **WHEN** the thumb rests in the anchor corner and three fingers tap
- **THEN** the 3-finger gesture fires and no Look up panel appears

#### Scenario: Look up blocked with Tap to click off
- **GIVEN** Tap to click is off, Look up is set to Tap with three fingers, and the pointer is over a word
- **WHEN** the thumb rests in the anchor corner and three fingers tap
- **THEN** the 3-finger gesture fires and no Look up panel appears

#### Scenario: Look up without the thumb
- **GIVEN** Look up is set to Tap with three fingers and the pointer is over a word
- **WHEN** three fingers tap with no thumb in the anchor corner
- **THEN** the Look up panel appears for the word

### R5. A tap under an anchored thumb never triggers Smart zoom
The Smart zoom that macOS performs for a double tap with two fingers MUST NOT happen when the double tap is under an anchored thumb, or when it arrives up to 0.5 seconds after the second tap's fingers lift. This holds whatever Tap to click is set to. A double tap with two fingers and no thumb anchored MUST still zoom. Blocking needs the Accessibility permission. Without it, the zoom happens as it does today, and Smart zoom never turns gestures off.

#### Scenario: Two 2-finger gestures in quick succession
- **GIVEN** Smart zoom is on and the pointer is over a web page
- **WHEN** the thumb rests in the anchor corner and two fingers tap twice within half a second
- **THEN** the 2-finger gesture fires twice and the page does not zoom

#### Scenario: Smart zoom with Tap to click off
- **GIVEN** Smart zoom is on, Tap to click is off, and the pointer is over a web page
- **WHEN** the thumb rests in the anchor corner and two fingers tap twice within half a second
- **THEN** the page does not zoom

#### Scenario: Smart zoom without the thumb
- **GIVEN** Smart zoom is on and the pointer is over a web page
- **WHEN** two fingers double-tap with no thumb in the anchor corner
- **THEN** the page zooms

#### Scenario: Smart zoom without the permission
- **GIVEN** Smart zoom is on, Tap to click and Look up: Tap with three fingers are off, Trackpad Launcher lacks the Accessibility permission, and the pointer is over a web page
- **WHEN** the thumb rests in the anchor corner and two fingers tap twice within half a second
- **THEN** the 2-finger gesture fires twice and the page zooms, as it does today

### R6. Without the Accessibility permission, Tap to click and Look up turn gestures off
While Tap to click or Look up: Tap with three fingers is on for any connected trackpad and Trackpad Launcher lacks the Accessibility permission, gestures MUST be inactive. Inactive covers all five gestures, the swipe, the window swipe and the swap: nothing is recognised and nothing fires. With both settings off, gestures without the permission MUST work as they do today. Granting the permission MUST make gestures active within 5 seconds, with no relaunch. Revoking it MUST make them inactive within 5 seconds.

#### Scenario: Tap to click on, no permission
- **GIVEN** Tap to click is on and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the thumb rests in the anchor corner and one finger taps
- **THEN** nothing opens and no haptic plays, and the tap clicks as macOS makes it

#### Scenario: Granting the permission
- **GIVEN** Tap to click is on, Trackpad Launcher lacks the Accessibility permission, and gestures are inactive
- **WHEN** the user grants the permission in System Settings
- **THEN** within 5 seconds the next gesture fires and makes no click

#### Scenario: Revoking the permission
- **GIVEN** Tap to click is on, Trackpad Launcher has the Accessibility permission, and gestures are active
- **WHEN** the user revokes the permission in System Settings
- **THEN** within 5 seconds a tap under the thumb opens nothing and clicks as macOS makes it

#### Scenario: Both settings off, no permission
- **GIVEN** Tap to click and Look up: Tap with three fingers are off, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user makes a gesture
- **THEN** it fires, as it does today

### R7. The settings window never asks to turn trackpad settings off
The settings window MUST NOT show the trackpad-settings notice ("Gestures are off while these trackpad settings are on: …") nor its *Open Trackpad Settings…* button, ever.

#### Scenario: Tap to click on, permission granted
- **GIVEN** Tap to click is on and Trackpad Launcher has the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** it shows no trackpad-settings notice, and the gesture hint shows as usual

### R8. The settings window says when gestures need Accessibility access
While gestures are inactive because R6 applies, the settings window MUST show one of these notices in place of the gesture hint, exactly as written:
- "Gestures are off while Tap to click is on, until Trackpad Launcher has Accessibility access."
- "Gestures are off while Look up: Tap with three fingers is on, until Trackpad Launcher has Accessibility access."
- "Gestures are off while Tap to click and Look up: Tap with three fingers are on, until Trackpad Launcher has Accessibility access."

The notice names only the settings that are on for any connected trackpad. It does not name the trackpad.

#### Scenario: Tap to click on, no permission
- **GIVEN** Tap to click is on, Look up is set to Force Click, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** it shows "Gestures are off while Tap to click is on, until Trackpad Launcher has Accessibility access."

#### Scenario: Both settings on, no permission
- **GIVEN** Tap to click and Look up: Tap with three fingers are on, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** it shows "Gestures are off while Tap to click and Look up: Tap with three fingers are on, until Trackpad Launcher has Accessibility access."

### R9. The notice opens Accessibility settings in place of the Accessibility hint
The Accessibility hint is the settings-window message "Allow Accessibility access to make trackpad gestures work reliably." with its *Open Accessibility Settings…* button, shown while the permission is missing. The notice from R8 MUST carry the *Open Accessibility Settings…* button, which opens the Accessibility pane of System Settings. While the notice shows, the Accessibility hint does not. With Tap to click and Look up: Tap with three fingers off and no permission, the Accessibility hint MUST show as it does today.

#### Scenario: The notice's button
- **GIVEN** Tap to click is on and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window and clicks *Open Accessibility Settings…* in the notice
- **THEN** the Accessibility pane of System Settings opens, and the window shows no Accessibility hint

#### Scenario: Both settings off, no permission
- **GIVEN** Tap to click and Look up: Tap with three fingers are off, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** it shows the Accessibility hint as it does today, and no notice from R8

### R10. The notice updates while the settings window is open
The notice from R8 MUST appear and disappear while the settings window is open, with no need to reopen the window.

#### Scenario: Granting the permission with the window open
- **GIVEN** the settings window is open and shows the notice from R8
- **WHEN** the user grants the Accessibility permission in System Settings
- **THEN** within 5 seconds the notice is gone and the gesture hint shows

### R11. "No trackpad connected" takes priority
The notice "No trackpad connected. Connect a trackpad to use gestures." MUST stay as it is today and take priority over every other notice.

#### Scenario: No trackpad
- **GIVEN** no trackpad is connected, Tap to click is on, and Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the settings window
- **THEN** it shows "No trackpad connected. Connect a trackpad to use gestures."

## Non-goals

- **Blocking taps outside a gesture.** Apart from the 0.5-second window after a gesture, a tap with no thumb anchored clicks, shows Look up or zooms as macOS decides. The user wants those.
- **Changing physical click blocking.** A real press keeps today's rules, including the 3-second window, so the user can rest the thumb and then click on purpose.
- **Blocking a click within 0.5 seconds after a gesture while Tap to click is off.** With Tap to click off, no click comes from a tap, so today's rules stay as they are.
- **Keeping a deliberate click right after a gesture.** While Tap to click is on, a click within 0.5 seconds after a gesture's fingers lift is lost. This is accepted because such a click is rarely intended.
- **Other tap-bound system actions** such as *Dragging* (tap and hold to drag) or a tap in the corner for a secondary click. The probe found no action besides clicks, Look up and Smart zoom that a gesture tap triggers.
- **Three-finger drag and Force Click under the anchored thumb.** Three-finger drag and Force Click under the anchored thumb keep today's behaviour.
- **Changing system trackpad settings.** Trackpad Launcher only reads them and never turns a setting off or on.

## Implementation Decisions

- **The two settings are renamed to what they now are: *tap-bound settings*, which need Accessibility rather than silence gestures.** `ConflictingSetting` becomes `TapBoundSetting` and `ConflictingSettings` becomes `TapBoundSettings` (the same non-empty, table-ordered value); the table itself (Tap to click = `Clicking` 1, Look up = `TrackpadThreeFingerTapGesture` 2) and the preferences adapter's reads are unchanged. `GestureActivity` is built from three inputs: the connected kinds, the preference values and the Accessibility grant. No trackpad gives `.inactive(.noTrackpad)`; otherwise a tap-bound setting on for a connected kind while the grant is missing gives `.inactive(.settingsNeedAccessibility(TapBoundSettings))`; otherwise `.active`. One pure helper answers "which tap-bound settings are on for a connected trackpad", in table order, and feeds both the activity and the run. `Launcher.activity` now reads the stored grant; the comment that kept the grant out of activity ("so the icon never reads it") describes a menu bar icon that no longer exists and goes. The reconcile's `Run` gains `blockTapClicks`, computed as `blockClicks` and Tap to click on for any connected trackpad, so it never holds without `blockClicks` and a Tap to click change while nothing runs changes no `Run`; `blockClicks` stays `active && granted`. A Tap to click change therefore re-runs the trackpads like a hand-mode or swipe change, ending a slide in progress, which is what every other run change does today.

- **`TrackpadHardware.run` gains one input, `blockTapClicks`.** Its contract: presses that arrive while a lift window is open are blocked; only meaningful together with `blockClicks`. Both adapters hand it to the `TapFilters` they build, where it is fixed for that tap's life (`TapFilters(blocksTapClicks:)`); nothing per event carries it.

- **The lift window is decided by the recognizer and timed by the tap.** `Recognition` gains `opensLiftWindow`: true on a frame where a thumb touch was on before the frame and a contact other than the thumb lifted that macOS could read as a tap: it had been down for less than the tap action hold limit (`GestureRules.tapActionHoldLimit`: the longest hold for which macOS still makes a tap action, set from S1's measurement with a margin; a contact already resting when recognition started has an unknown landing and never qualifies), and no press, delivered or withheld, was seen on any frame while it was down (a finger that physically clicked is no tap to macOS, so its lift makes no tap action). "The thumb" is the one the state knows: the anchor, the thumb under a rest, or a slide's thumb. So the window opens on a tap's fingers lifting (each lift reopens it; the last lift sets its end), on a swipe's or a window swipe's fingers lifting quickly (R2's short swipe), and on a short-lived finger that loses contact mid-slide; it does not open on a thumb lifting alone (the probe found a lone thumb tap makes no click), on fingers that rested or scrolled past the hold limit (a swap series' fingers, a two-finger scroll under a rested thumb), on a finger that physically pressed (a double click under a rested thumb keeps both clicks), nor on any lift outside a thumb touch. The recognizer stays clock-free: `GestureRules.liftWindow` is 0.5 s, "strictly less is inside" like the 3 s `clickBlockingWindow`; the hold limit is a frame-time comparison of the kind the recognizer already makes, and nothing in core turns the window into a frame-time deadline.

- **The window is measured on one new clock, read at receipt: `Uptime`.** A core value type distinct from `FrameTime`: monotonic seconds of the process's own clock (what `ProcessInfo.systemUptime` reads), with `+ Duration` and ordering. The frame time is the multitouch driver's clock and the tap sees events timestamped by the window server; the probe's 275–285 ms were measured on receipt times, so receipt times are what the design rests on, and a distinct type makes comparing the two clocks a compile error. Core defines the value and its arithmetic and never reads the clock; `LauncherPlatform` reads `now` in one small extension. The `DeviceSession` takes its clock as a dependency (a closure the real adapter fills with that read), so a platform test can move time without sleeping; the click tap reads the same clock once per event it decides.

- **What a trackpad's frames have told the tap is one core value, used by both adapters.** The session's shared state, today a bare `Blocking` level, becomes a small struct holding the level and the end (`Uptime?`) of the lift window last opened on that trackpad, with three operations: take one `Recognition` at `now` (replace the level; when the recognition opens a window, stamp `now` plus 0.5 s); whether the window is open at `now`; and `wantsTap(at:)`, the level's `wantsTap` or an open window. The frame thread compares `wantsTap` between frames to wake the tap thread, as it compares `wantsTap` today, so the wake also fires on the first frame after a window ended: that frame is what lets the gate close. The clock is read once per frame while a window end is pending (the end is cleared once it has passed, so an ordinary touch reads no clock) and once per event the tap decides. A pure merge over every running trackpad's value at `now` gives the tap its context: the highest level and whether any window is open. `TapContext` gains `liftWindowIsOpen`; `estimated(from:)` gains the same flag and keeps deriving its scroll estimate from the level alone (a window never opens a closed gate: the lifting contact was down, so the port was already on).

- **The tap's rules live in `TapFilters`, as today.** Presses: blocked when the level blocks clicks, or when the tap blocks tap clicks and a lift window is open. `ClickFilter` is untouched, so a press that starts in the window is withheld whole: its drags become moves and its release is dropped, which is R2's tap-and-hold drag. Scrolls and Dock swipes: unchanged; the window never suppresses scrolling. Tap actions, new: `TapEvent.tapAction(TapAction)` with `TapAction` being `lookUp` or `smartZoom`, dropped when the level blocks Dock swipes (a thumb touch with two or more contacts, which is "under an anchored thumb" however long it rested, and also catches the event when it beats the lift frame to the tap) or a lift window is open; passed otherwise. Each is one event, so the rule is stateless and its verdict a plain pass or drop. The gate: `settle`'s predicate gains "a lift window is open", so the gated port stays on through the window after the pad empties, which is where a Look up arriving as the thumb lifts with the fingers would otherwise race the close. The port closes lazily, on the next frame (the frame thread wakes on the flip) or the next event the tap is sent, whichever comes first; a port left on while nothing touches the pad is sent nothing, so the cost is bounded by the first event of the next touch.

- **Parsing in the click tap.** Type 29 with field 110 equal to 24 is Look up (the IOHID symbolic hot key event) and equal to 22 is Smart zoom (the IOHID zoom toggle event); both join the Dock swipe in the same table of undocumented numbers, ride the gated port (type 29 is already in its mask) and parse into `TapEvent.tapAction`. Every other gesture event still parses as nothing and passes untouched before any lock is taken. A dropped tap action returns nothing to the window server; a passed one returns the event as it came. If the first slice finds a sub-field that tells Look up from other symbolic hot keys, the parser reads it and drops only Look up; otherwise every hid-24 event is Look up to us, which is scoped by the rule to a thumb touch and its lift window.

- **The settings window.** `Copy.inactiveNotice(for:)` gives the three R8 sentences for `.settingsNeedAccessibility` (one setting: "… while Tap to click is on, until …"; two: "… while Tap to click and Look up: Tap with three fingers are on, until …", names in table order joined by "and") and the unchanged no-trackpad sentence. The trackpad-settings button and the Trackpad pane are deleted. The notice view takes an optional button: the no-trackpad notice is a message alone (R7's "ever" removes the button it shared with the deleted notice; its text is unchanged), the R8 notice carries *Open Accessibility Settings…*, opening the Accessibility pane exactly as the Accessibility hint's button does. The model, not the view, decides the notice: `Launcher.inactiveNotice` is a derived value, nil while gestures are active, otherwise a small core value holding the message (from `Copy.inactiveNotice(for:)`) and an optional button, `.openAccessibilitySettings` for the tap-bound settings notice and none for the no-trackpad notice; the view renders the message and, when the button is there, *Open Accessibility Settings…* over the existing open-pane action. `Launcher.showsAccessibilityHint` is derived too: the grant is missing and `inactiveNotice` carries no button; the view's hint and the shell's refit read it in place of the bare grant. The window already observes `activity` and the grant, so R10 needs no new push: the TCC broadcast and the cfprefs KVO reach `reconcile` as today.

- **Hardware first.** Three assumptions behind R2, R4 and R5 have not been seen on real hardware and the first slice verifies them with the probe in `.temp/probes/` before any tap-side code is written: that returning nothing for a type-29 hid-24 or hid-22 event in a session tap suppresses the Look up panel and the zoom; that each is one event, not a phased pair; and that a tap's click reaches the tap after its lift frame has reached us, which the long-rest scenario depends on, because during the fingers' touch after 3 s the level is `.dockSwipes` and a physical press must pass there (R3). The findings go to the development log; a failed assumption sends the plan back before the tap-side slices (fallbacks in Further Notes).

- **Existing tests that assert the old rules are updated; nothing else is edited.** `ActivityTests`: the three rows that deactivate on Tap to click become no-permission worlds and gain granted twins (T1, T26); `noticeNamesExactlyTheOffendingSettingsInTableOrder` names `TapBoundSetting` in a no-permission world; `noTrackpadWinsOverSettingsAndTracksHotPlug` becomes T31. `ClickBlockingTests.blockingIsArmedOnlyWhileGesturesAreActiveAndAccessIsGranted`: Tap to click on with access keeps blocking armed and the devices running; without access it disarms and stops them. `TapGateRecoveryTests.tapToClickTurnsTheTapOff` becomes "with access, a Tap to click change keeps the tap and restarts it closed" (a `Run` change replaces the tap, and the gate reads off right after). `WindowSwitcherOnScreenTests.whileGesturesAreInactiveAWindowSwipeShowsNothingEvenIfOneWasInFlight` builds its world without the permission, since Tap to click alone no longer makes gestures inactive (the `SwitcherOnScreenTests` and `SwapTests` rows that turn Tap to click on already build theirs without it and stay as they are). `DeviceSessionAnswerTests.theTapIsWokenOnlyWhenTheTrackpadStartsOrStopsWantingIt` gives its session a test clock and advances it past the window before the final empty frame whose wake it asserts. `CopyTests`: T29 replaces the inactive-notice row and the trackpad-settings-button row. `AccessibilityTests.accessHintFollowsTheGrantLiveAndNeverChangesActivity` keeps its body and is renamed to say "while no tap-bound setting is on". `TapFiltersTests` and `TapContextTests` build contexts with the new flag (false). Nine `TapGateTests` rows assert the gate closed within 0.5 s of a non-thumb lift inside a thumb touch and now play 0.5 s of empty frames before that assertion, their other assertions untouched: `aSwipesScrollStaysDroppedThroughTheLiftsAndTheMomentumAndTheGateClosesAfterTheLast`, `aStilledScrollStaysStilledThroughTheLiftsAndItsMomentum`, `aPressStaysWithheldThroughTheThumbsLiftUntilTheButtonIsUp` (a frame at 900 ms reads the close that 350 ms read before), `aDockSwipeDroppedAtItsStartStaysDroppedUntilItsOwnStreamEnds`, `aPassingScrollWhoseEndWasNeverSeenHoldsNothingOpenAndDoesNotStillTheNextHand`, `aScrollWhoseStartWentUnsentAndWhoseEndWasDecidedDoesNotLeaveALaterThumbFirstHandUnseen`, `aDroppedSwipeWithNoMomentumLeavesTheGateOpenUntilTheNextScrollEventPasses`, `aDockSwipeOpeningAfterTheThumbRolledOutIsDroppedWholeAndHoldsTheGateToItsEnd`, `aDockSwipeWarningThatSlippedThroughIsDroppedFromItsBeganOnceTheFingersAreDown`. No `@Test` body outside the rows named here and in the scenario table is edited; the rest of the suite staying green is the proof of every "as today" clause.

## Testing Decisions

### Strategy

Four seams, all existing, from the one most rows use down.

- **World through `InMemoryTrackpads`** (`LauncherKit/Tests/LauncherCoreTests/ClickBlockingTests.swift`, `TapGateTests.swift`, `ActivityTests.swift`, `AccessibilityTests.swift`, with `World.swift`, `TouchScript.swift` and `InMemoryAdapters.swift`): the real `Launcher`, recognizer, trackpad state value, merge, `TapFilters` and `ClickFilter` over scripted frames and the fake's two ports. It observes `activity`, `showsAccessibilityHint`, `hardware.running`, `isBlockingClicks`, `isGatedPortOn`, `offer(_:) -> Delivery` (which tells "never delivered" from "passed" from "dropped"), `pressVerdicts`, `system.broughtToFront` and `hardware.feedback`. Every R1 to R6 and R8 to R11 row runs here. It misses the real ports and clock, the window server's own timing, and whether a dropped event really suppresses the panel, the zoom and the click: that is the first slice's hardware check and the last slice's walkthrough.
- **`Copy` as values** (`CopyTests.swift`): the exact notice sentences.
- **The click tap's parser over synthetic `CGEvent`s** (`LauncherKit/Tests/LauncherPlatformTests/TapEventTests.swift`): the undocumented numbers to `TapEvent`, and the verdicts' effect on an event. The only place the hid-24/22 mapping can be proved.
- **`DeviceSession` over hand frames** (`LauncherPlatformTests/DeviceSessionAnswerTests.swift`): the real session's stamp on an injected clock and its wake-ups. The only place the real adapter's clock use can be proved without the tap.

Faked, exactly as every World row fakes them today: the window server's ports and notices (the fake's turns), the trackpad preferences and the permissions (in memory). The one addition is the tap's clock: the fake owns an `Uptime` clock that never goes backwards, follows the latest frame time it is handed on any trackpad, and can be advanced by a row without frames (`advanceClock(by:)`); so a scripted `wait` of empty frames after a lift is time passing with the pad empty (the "next frame" path), an advance without frames is time passing with nothing arriving (the real "next event" path, T35), and a tap's click or a Look up "arriving n ms after the lift" is `offer(_:)` after playing the script to that time. The fake takes a press from `offer(.pointer(.press(_)))` as the window server would hand it (a tap's click is never seen by a frame, so it does not ride the frames' `press` field); `pressVerdicts` keeps recording only the frames' presses. The fake gains `.tapAction` in what it can be offered and decides it with the real `TapFilters`. Everything in `LauncherCore` runs for real.

Before and after: every new row states what the code reads before it ("after S2" for the S3 and S4 rows, since before S2 a Tap-to-click world runs nothing and every offer reads `.noTap`), so each is a failing test first, except T13, T16, T20, T24, T25, T28 and T34, which pass as soon as their world runs and pin the "as usual", "without the thumb", "without the permission" and "passed, not dropped" clauses against a rule that would over-reach. The rest of the suite staying green proves every "unchanged" clause: physical press rules (`ClickBlockingTests`, `ClickBlockingRecognizerTests`), scroll suppression (`ScrollSuppressionTests`, `ScrollFilterTests`), Dock swipes (`DockSwipeFilterTests`, `DockSwipeBlockingRecognizerTests`), swaps, swipes and window swipes (`SwapTests`, `SwitcherOnScreenTests`, `WindowSwitchingTests`), and the gate's other paths (`TapFiltersTests`, `TapGateRecoveryTests`).

### Test scenarios

Unless a row says otherwise: `World(apps: ["Arc", "Figma", "Notes"], accessGranted: true)`, started, Arc on the 1-finger gesture, Figma on the 2-finger, Notes on the 3-finger, Tap to click on for the built-in trackpad, the built-in trackpad only. `thumb` is `TouchScript(.macBook14).thumb(atMM: (10, 10))`. Times are counted from the fingers' lift frame, `L`. A "click offered at L+n" is `offer(.pointer(.press(PressID(button: b, number: k))))` followed by `offer(.pointer(.release(…)))` after playing the script up to L+n (10 ms frames, so n is a multiple of 10); "dropped" is both reading `.decided(.pointer(.drop))`, "passed" both `.decided(.pointer(.pass))`. Scripted times come from `TouchScript`'s builder: `thumb()` lands at the cursor and moves it 50 ms; `tap(fingers:)` lands at the cursor, lifts 120 ms later and leaves the cursor 100 ms after the lift; `land`/`wait`/`lift` as documented there.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | World | Given the default world. Then `activity == .active`, `hardware.running` holds the built-in trackpad, `isBlockingClicks`. When `thumb.tap(1)` is played. Then `broughtToFront == [Arc]` and `feedback == [macBook14]`. Today: `.inactive(.settings([.tapToClick]))`, nothing runs, nothing fires (`ActivityTests.tapToClickOnBuiltInDeactivatesAndStopsTheDevices`). | R1's first scenario ("Mail comes to the front with the gesture haptic"); the domain model's *Feedback*. |
| T2 | R1 | World | Given `attached: [.macBook14, .magicTrackpad]`, both tap-bound settings on for `.external` and off for `.builtIn`, with the permission. Then `activity == .active`. When the 3-finger gesture is played on the Magic Trackpad, then on the built-in. Then `broughtToFront == [Notes, Notes]` and `feedback == [magicTrackpad, macBook14]`. Today inactive (`ActivityTests.settingOnlyOnTheConnectedExternalTrackpadDeactivates`). | R1's second scenario ("the gesture fires" on either trackpad). |
| T3 | R1 | World | Given `World.switcherWorld(accessGranted: true)` with Tap to click on: `world.swipe(3.5, 12)` brings Mail to front with one gesture pulse and the switcher is gone after the lift; a fresh such world: `world.swap()` brings Mail to front with one gesture pulse; `World.windowWorld(visible: ["Docs", "Mail"])` with Tap to click on: `windowSwipe(3.5, 12, lift: false)` reads `windows.raised == [[Mail]]`. Today: nothing happens in any of the three (inactive). | R1's third scenario ("exactly as it does with Tap to click off"): the literals are the Tap-to-click-off rows' own, `SwitcherOnScreenTests`/`SwitcherTests` (one 12 mm step selects Mail, the next most recent after Safari), `SwapTests.theThumbLiftingSwapsToThePreviousAppWithTheHapticAndNoAnimationAndLeavesTheWindowOpen` (`broughtToFront == [Mail]`), `WindowSwitchingTests.eachWindowTheSelectionReachesComesToTheFrontAndSlidingBackBringsTheFrontWindowBack` (`raised == [[Mail]]`). |
| T4 | R1 | World | Given the default world with Tap to click off and `runCount` noted. When Tap to click is set on for the built-in. Then `activity == .active`, `hardware.running` still holds the trackpad, `runCount` rose by one, `isBlockingClicks`; `thumb.tap(1)` then brings Arc to front, and a left click offered at L+100 is dropped. Today: inactive, nothing runs. | R1's fourth scenario ("gestures stay active, with no relaunch, and the next gesture fires"); the run re-runs on a `Run` change (the first implementation decision); the click's verdict is R2's. |
| T5 | R2, R6 | World | Given a world with Arc, Figma, Notion, Spotify and Slack on gestures 1 to 5 (as `ClickBlockingTests.aFirmTapOpensItsAppAndTheWholePressNeverReachesApps`), Tap to click on, the permission. When, for each finger count 1 to 5, `thumb.tap(n)` is played and a left click is offered at L+100. Then the gesture's app is brought to front, `feedback == [macBook14]`, the click is dropped. And given the five-app world started without the permission (inactive), then granted: the same for n = 1. After S2: passed (the level after the lift is `.possible`). | R2's first scenario ("Mail comes to the front and the button is not pressed") and its "every finger count"; the probe (the click arrives at the lift, just after the lift frame); R6's "Granting the permission" scenario ("the next gesture fires and makes no click"). |
| T6 | R2 | World | Given the default world. (a) `thumb.tap(2)` played to L+280, a right click (button 1) offered: dropped, `broughtToFront == [Figma]`. (b) `thumb.land(fingers: 2).wait(.milliseconds(120)).lift()`, a right click offered at L+50: dropped, Figma. After S2: passed. | R2's second and third scenarios; the probe's 275–285 ms (Smart zoom on) and "at the lift" (Smart zoom off); `ClickFilter` is per button, so the right click is the same rule as the left. |
| T7 | R2 | World | Given `attached: [.macBook14, .magicTrackpad]`, Tap to click on for `.external` only. When `TouchScript(.magicTrackpad).thumb(atMM: (10, 10)).tap(2)` is played on the Magic Trackpad to L+280 and a right click is offered. Then dropped, `broughtToFront == [Figma]`, `feedback == [magicTrackpad]`. After S2: passed. | R2's fourth scenario; `blockTapClicks` is true when Tap to click is on for any connected trackpad (second decision). |
| T8 | R2 | World | Given the default world. When `thumb.land(fingers: 2).wait(.milliseconds(120)).lift().liftThumb()` is played (the thumb lifts 40 ms after the fingers, the pad is empty) and, at L+280, a right click is offered. Then dropped, `broughtToFront == [Figma]`, and `isGatedPortOn` is still true at that moment. After S2: passed and the port is off. | R2's fifth scenario ("the right click that macOS sends about 280 ms after the fingers lifted does not reach apps"); the lift window holds "whether or not the thumb is still down". |
| T9 | R2 | World | Given `World(apps: [], accessGranted: true)` with Tap to click on: nothing assigned. When `thumb.tap(1)` is played and a left click offered at L+100. Then dropped, `broughtToFront` empty, `pulses` empty. After S2: passed. | R2's sixth scenario ("nothing opens and no click reaches apps"). |
| T10 | R2 | World | Given the default world. When `thumb.wait(.seconds(5)).tap(1)` is played and a left click offered at L+100. Then dropped and `broughtToFront == [Arc]`. After S2: passed (the 3 s window is over). | R2's seventh scenario ("thumb has rested … for 5 seconds … no click reaches apps"); the lift window is independent of the 3 s blocking window. |
| T11 | R2 | World | Given the default world. When `thumb.tap(1).wait(.milliseconds(80)).tap(1).wait(.milliseconds(80)).tap(1)` is played in three pieces (lifts 300 ms apart) and after each piece a left click is offered. Then all three are dropped, `broughtToFront == [Arc, Arc, Arc]`, `feedback.count == 3`. After S2: all three passed. | R2's eighth scenario ("fires three times and no click or double click reaches apps"); `LauncherTests.repeatedTapsWhileTheThumbStaysAnchoredFireEachTime` for the firing. |
| T12 | R2 | World | Given `World.switcherWorld(accessGranted: true)` with Tap to click on. When `thumb.land(fingers: 2).slide(byMM: (3.5, 0), over: .milliseconds(20)).lift()` is played frame by frame observing `launcher.switcher != nil`, then played to L+280 and a right click is offered. Then the observation contains `true` (the swipe ran), the switcher is nil after the lift, `broughtToFront` is empty (a lift on the frontmost app is silent), the click is dropped. After S2: passed. | R2's ninth scenario ("the swipe runs as usual and no context menu opens afterwards"); the domain model's *Swipe* (a slide past 3 mm is a swipe) and *Switcher* (lifting on the frontmost app does nothing, silent). |
| T13 | R3 | World | Given the default world. (a) `thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (0, 30), over: .seconds(1)).lift()` (a two-finger scroll under a rested thumb, the fingers down 1 s; the window swipe setting is off, so the slide is spoiled, not a window swipe) and a left click offered at L+100: passed. (b) `thumb.wait(.seconds(4)).tap(1, click: .firm).wait(.milliseconds(80)).tap(1, click: .firm)` (two physical clicks 300 ms apart under a rested thumb): `pressVerdicts == [.pass, .pass, .pass, .pass]`, nothing fires. Both pass after S2 and would fail under a window that opened on every lift: (a) through the hold limit, (b) through the press seen while the finger was down. | R3's "a physical press … reaches apps after that" and the non-goal "Changing physical click blocking"; the third decision's two conditions; macOS makes no tap action for a finger that scrolled for a second or that pressed (`ClickBlockingTests.aPressReachingTheTapBeforeTheLandingFrameIsAClickThatCancelsTheTap` pins the press-cancels-tap rule). |
| T14 | R2 | World | Given the default world. When `thumb.tap(1).liftThumb()` is played (Arc fires; the pad empties at L+100), then at L+300 a no-thumb one-finger tap of 100 ms (`.land(fingers: 1)` at L+300, `.lift()` at L+400), and a left click is offered at L+410. Then dropped, `broughtToFront == [Arc]`. After S2: passed. | R2's eleventh scenario ("the 0.5-second window swallows the tap by design"); the non-goal "Keeping a deliberate click right after a gesture". |
| T15 | R2 | World | Given the default world. When `thumb.wait(.seconds(4)).tap(1)` is played (Arc fires, L at 4170 ms), then `.land(fingers: 1)` at L+100 and a left press offered there, then `.slide(byMM: (20, 0), over: .milliseconds(800))` with `offer(.pointer(.drag(button: 0)))` at L+300 and again at L+700, then `.lift()` and a left release offered at L+1000. Then the press is dropped, both drags read `.decided(.pointer(.passAsMove))`, the release is dropped although the window ended at L+500, `broughtToFront == [Arc]`. After S2: the press passes (the level is `.dockSwipes` after 4 s) and the drags pass as drags. | R2's twelfth scenario ("nothing is dragged and no button stays pressed"); R2's text ("a press that starts in the window … is blocked whole, from press to release"); `ClickFilterTests.dragsBecomeMovesOnlyDuringAWithheldPressOfTheSameButton`. |
| T16 | R3 | World | Given the default world. When `TouchScript(.macBook14).tap(1)` (no thumb) is played and a left click offered at L+100; then, in a fresh world, `tap(2)` and a right click offered at L+50. Then both passed, nothing fires, `isGatedPortOn` is false throughout. Holds after S2 (today a Tap-to-click world runs no tap and reads `.noTap`). | R3's first and second scenarios ("the button is pressed", "the context menu opens"); the non-goal "Blocking taps outside a gesture". |
| T17 | R2, R3 | World | Given the default world. When `thumb.tap(1).liftThumb()` is played and a left click is offered at L+490, in another world at L+510, in another at L+1000. Then L+490 is dropped; L+510 and L+1000 are passed; Arc fired once in each. After S2: all passed. | R3's third scenario ("one second later … the button is pressed"); R2's "up to 0.5 seconds"; the half-open window ("strictly less is inside", third decision, the `clickBlockingWindow` convention); the rows sit 10 ms off the exact boundary, as the 3 s rows do (2990/3010), where `Double` frame times would decide. |
| T18 | R3 | World | Given the default world. (a) `thumb.wait(.seconds(4)).tap(1, click: .firm)`: `pressVerdicts == [.pass, .pass]`, `broughtToFront` empty. (b) `thumb.tap(1, click: .firm)`: `pressVerdicts == [.drop, .drop]`, `broughtToFront == [Arc]`. Both hold today with Tap to click off (`ClickBlockingTests.afterFourSecondsAPressIsAClickAndOpensNothing`, `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps`); today with Tap to click on nothing runs. | R3's fourth scenario ("the click reaches apps, as it does today with Tap to click off") and its "blocked during the first 3 seconds"; the non-goal "Changing physical click blocking". |
| T19 | R4 | World | Given the default world with Look up set to Tap with three fingers (raw 2) and Tap to click on, and the same with Tap to click off. When `thumb.tap(3)` is played and `offer(.tapAction(.lookUp))` is made right after (the thumb still down). Then `.decided(.tapAction(.drop))` in both, `broughtToFront == [Notes]`. Today: the tap does not read the event; it passes. | R4's first and second scenarios ("no Look up panel appears", "whatever Tap to click is set to"); the probe (Look up is type 29, field 110 = 24, at the lift). |
| T20 | R4 | World | Given the default world with Look up on. When `TouchScript(.macBook14).tap(3)` (no thumb) is played and `.tapAction(.lookUp)` offered. Then `.notSent` (the gated port is off; the event reaches apps untouched) and nothing fires. Holds after S2. | R4's third scenario ("the Look up panel appears for the word"). |
| T21 | R4 | World | Given the default world with Look up on. When `thumb.land(fingers: 3).wait(.milliseconds(120)).lift().liftThumb()` is played (the pad empties 40 ms after the lift) and `.tapAction(.lookUp)` is offered at L+100. Then `.decided(.tapAction(.drop))` and `isGatedPortOn`. When the script is played on to L+600 (empty frames) and the offer repeated. Then `.notSent` and `!isGatedPortOn`. After S2: the port is off at L+100. | R4's text ("or when it arrives up to 0.5 seconds after the tap's fingers lift"); the gate decision (the window holds the port; the next frame after the window closes it). |
| T22 | R4, R5 | World | Given the default world with Look up on. When `thumb.wait(.seconds(4)).land(fingers: 3)` is played and `.tapAction(.lookUp)` is offered before any lift (the thumb rested past 3 s and three fingers down: level `.dockSwipes`, no window yet). Then `.decided(.tapAction(.drop))`. The same with `.land(fingers: 2)` and `.tapAction(.smartZoom)`. After S2: passes unread. | R4's and R5's "under an anchored thumb", however long it rested; the sixth decision's level branch, which is what catches an event that beats the lift frame to the tap. |
| T23 | R5 | World | Given the default world, Tap to click on, and the same with Tap to click off. When `thumb.tap(2).wait(.milliseconds(80)).tap(2)` is played (the second lift 300 ms after the first) and `.tapAction(.smartZoom)` is offered right after. Then `.decided(.tapAction(.drop))` in both, `broughtToFront == [Figma, Figma]`. After S2: passes unread. | R5's first and second scenarios ("the 2-finger gesture fires twice and the page does not zoom"); the probe (Smart zoom is type 29, field 110 = 22, at the second tap's lift). |
| T24 | R5 | World | Given the default world. When `TouchScript(.macBook14).tap(2).wait(.milliseconds(80)).tap(2)` (no thumb) is played and `.tapAction(.smartZoom)` offered. Then `.notSent`, nothing fires. Holds after S2. | R5's third scenario ("the page zooms"). |
| T25 | R5 | World | Given `World(apps: ["Figma"])` without the permission, both tap-bound settings off, Figma on 2. When `thumb.tap(2).wait(.milliseconds(80)).tap(2)` is played and `.tapAction(.smartZoom)` offered. Then `broughtToFront == [Figma, Figma]`, `feedback.count == 2`, the offer reads `.noTap`. Holds today. | R5's fourth scenario ("the 2-finger gesture fires twice and the page zooms, as it does today"); R5's "Blocking needs the Accessibility permission". |
| T26 | R6 | World | Given `World(apps: ["Arc"])` without the permission, Arc on 1, and in turn Tap to click on; Look up on; both on (for the built-in). Then `activity == .inactive(.settingsNeedAccessibility(TapBoundSettings([.tapToClick])!))`, `…([.lookUpTapWithThreeFingers])`, `…([.tapToClick, .lookUpTapWithThreeFingers])` respectively, `hardware.running` empty, `!isBlockingClicks`. When `thumb.tap(1)` is played and a left click offered. Then `broughtToFront` empty, `pulses` empty, the offer reads `.noTap`. Today: the same inactivity, under the old cause name (`ActivityTests.tapToClickOnBuiltInDeactivatesAndStopsTheDevices`). | R6's first scenario ("nothing opens and no haptic plays, and the tap clicks as macOS makes it"); R6's "any connected trackpad" and R8's table order. |
| T27 | R6 | World | Given T26's Tap-to-click world. When the permission is granted (pushed). Then `activity == .active`, `hardware.running` holds the trackpad, `isBlockingClicks`; `thumb.tap(1)` brings Arc to front; a left click offered at L+100 is dropped. When the permission is revoked (pushed). Then `activity` is T26's cause again, nothing runs; `thumb.tap(1)` fires nothing and a left click offered reads `.noTap`. Today: the grant changes nothing (still inactive). | R6's second and third scenarios ("within 5 seconds the next gesture fires and makes no click"; "a tap under the thumb opens nothing and clicks as macOS makes it"); the push is synchronous in the fake and about 30 ms in `SystemPermissions`, inside the 5 s. |
| T28 | R6 | World | `ClickBlockingTests.withoutAccessAGestureStillWorksButNothingIsBlocked`, unchanged: no permission, both settings off, `thumb.tap(1)` brings Arc to front, a firm press passes, `!isBlockingClicks`. Holds today. | R6's fourth scenario ("it fires, as it does today"). |
| T29 | R7, R8 | Copy | `Copy.inactiveNotice(for: .settingsNeedAccessibility(TapBoundSettings([.tapToClick])!))` is "Gestures are off while Tap to click is on, until Trackpad Launcher has Accessibility access."; for `[.lookUpTapWithThreeFingers]` "Gestures are off while Look up: Tap with three fingers is on, until Trackpad Launcher has Accessibility access."; for both "Gestures are off while Tap to click and Look up: Tap with three fingers are on, until Trackpad Launcher has Accessibility access."; for `.noTrackpad` "No trackpad connected. Connect a trackpad to use gestures."; none of the four begins with "Gestures are off while these trackpad settings are on". `Copy.accessibilityButton` is still "Open Accessibility Settings…". Today: the old sentence. | R8's three sentences and R11's, verbatim; R7's quoted notice text; R9's button name. |
| T30 | R7, R8, R9, R10 | World | Given `World()` without the permission, Tap to click on and Look up set to Force Click (raw 0) for the built-in, `openedByHand()`. Then `activity == .inactive(.settingsNeedAccessibility(TapBoundSettings([.tapToClick])!))`, `inactiveNotice` holds the message "Gestures are off while Tap to click is on, until Trackpad Launcher has Accessibility access." with the button `.openAccessibilitySettings`, and `showsAccessibilityHint == false`. When the permission is granted (pushed). Then `activity == .active`, `inactiveNotice == nil`, `showsAccessibilityHint == false`, `isWindowOpen`. When revoked. Then the notice is back and the hint still false. When both settings are on. Then the cause is `[.tapToClick, .lookUpTapWithThreeFingers]` and the notice's message is the two-setting sentence with the same button. When both are off (raw 0 and raw 0), still without the permission. Then `activity == .active`, `inactiveNotice == nil` and `showsAccessibilityHint == true`; granted, `false`. Today: neither value exists and the hint shows beside the old notice. | R8's two scenarios (which settings are named); R9 ("MUST carry the *Open Accessibility Settings…* button"; "while the notice shows, the Accessibility hint does not"; "with Tap to click and Look up … off and no permission, the Accessibility hint MUST show as it does today"); R7 (the only button a notice can carry opens Accessibility); R10 ("appear and disappear while the settings window is open"); `AccessibilityTests.aGrantLeavesTheWindowOpen`. |
| T31 | R7, R11 | World | Given `World(attached: [])` without the permission and Tap to click on for the built-in, started. Then `activity == .inactive(.noTrackpad)`, `inactiveNotice` holds the message "No trackpad connected. Connect a trackpad to use gestures." and no button, and `showsAccessibilityHint == true`. When the built-in is attached. Then `.inactive(.settingsNeedAccessibility(TapBoundSettings([.tapToClick])!))`. When detached. Then `.inactive(.noTrackpad)` again. When attached and the permission granted. Then `.active`. Today's `noTrackpadWinsOverSettingsAndTracksHotPlug`, with the notice value and the permission edge added. | R11's scenario and "takes priority over every other notice"; R7 (no button opens the Trackpad pane; this notice has none); `GestureActivity`'s "no trackpad wins" order, unchanged; the Accessibility hint beside the no-trackpad notice is today's behaviour, kept. |
| T32 | R4, R5 | Parser (platform) | A type-29 event with field 110 = 24 parses as `.tapAction(.lookUp)`, = 22 as `.tapAction(.smartZoom)`, both `ridesGatedPort`; field 110 = 23 still parses as a Dock swipe with its phase; 0, 5, 6 and 8 still parse as nil; the press and gated masks are unchanged (`everyListedTypeParsesAndRidesItsPort` and `theMasksSplitPressesFromDragsPressureScrollsAndGestures` stay green); the tap-action drop verdict applied to such an event returns nil and the pass verdict returns the same event. Today: 24 and 22 parse as nil. | The probe (Look up = type 29, field 110 = 24; Smart zoom = type 29, field 110 = 22); `TapEventTests.ignoresEveryOtherGestureSoPinchRotateAndAppSwipesPass` for the untouched numbers. |
| T33 | R2 | `DeviceSession` (platform) | Given a session over a stub tap counting wakes and a clock the test sets (`Uptime` 10.0 s). When it receives: the thumb landing at 0 ms; a finger landing at 100 ms; the thumb alone at 200 ms (the finger lifted); nothing at 300 ms with the clock at 10.1 s; nothing at 400 ms with the clock at 10.6 s. Then `liftWindowIsOpen(at:)` is false after the first two frames at any time; after the third and the fourth it is true at 10.49 s and false at 10.5 s; the wakes are 1 (the thumb's frame) through the fourth frame; the fifth frame adds one wake and `blocking == .none`. Today: the session knows no window and wakes on the fourth frame. | The fifth decision (`now + 0.5 s` stamped on the lift frame, strictly less inside; the wake fires on the flip of `wantsTap`, window included); `DeviceSessionAnswerTests.theTapIsWokenOnlyWhenTheTrackpadStartsOrStopsWantingIt` for today's wakes. |
| T34 | R4, R5 | World | Given the default world with Look up on. When `thumb.wait(.milliseconds(200))` is played (a thumb alone: the gated port is on, level `.possible`, no window) and `.tapAction(.lookUp)` then `.tapAction(.smartZoom)` are offered. Then both read `.decided(.tapAction(.pass))`. Holds once the parser lands: the rule's pass branch, which a rule that dropped every tap action the port is sent would fail. | R4's and R5's "MUST still" clauses read with the gate on: a tap action the port is sent passes unless the level or the window says otherwise (sixth decision); `TapGateTests.theGateOpensOnTheThumbsFrameAndHoldsForTheFingersWakeStillPending` (a thumb alone passes a Dock swipe's opening the same way). |
| T35 | R4 | World | Given the default world with Look up on. When `thumb.tap(3).liftThumb()` is played (Notes fires; the pad is empty 100 ms after the lift with the window open), the fake's clock is advanced by 600 ms with no frames, and `.scroll(.fingers(.mayBegin))` is offered. Then it reads `.decided(.scroll(.pass))` and `!isGatedPortOn` right after (the first event after the window closed the gate), and `.tapAction(.lookUp)` offered next reads `.notSent`. After S2: the gate closed on the empty frame. | The sixth decision's lazy close by the next event; the architecture's gated-port sentence ("noticed on the next frame or the next event"); `TapGateTests.aDroppedSwipeWithNoMomentumLeavesTheGateOpenUntilTheNextScrollEventPasses` (a scroll event closing the gate). |
| T36 | R2 | World | Given `World.windowWorld(visible: ["Docs", "Mail"])` with Tap to click on. When `thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5), over: .milliseconds(20)).lift()` is played (a window swipe that begins and ends at once: `windowSwipeAnswers == [true]`, `windowSwitcher == nil` after the lift), then to L+280, and a right click is offered. Then dropped. After S2: passed. | R2's "fingers that start a swipe or window swipe but lift as a tap"; `WindowSwipeNeedsTwoWindowsTests` for the answer; T12 is its swipe twin. |

### Verified without a test

None. Every requirement has a scenario row above. The hardware facts the rows rest on (a dropped event suppresses the panel, the zoom and the click; one event each; the lift frame precedes the click) are not requirements but assumptions, and are checked on real hardware as the first slice's acceptance criteria and again in the last slice's walkthrough.

## Further Notes

- **Why the clock is read at receipt and not taken from the frames.** A frame's `FrameTime` is the multitouch driver's clock and a `CGEvent`'s timestamp the window server's; whether they are the same clock in the same units on every Mac is not known, and the probe did not measure it (it logged receipt times). Receipt times on the process's own clock are the same clock on both threads by construction, and cost one `clock_gettime` per event the tap decides and per frame while a window end is pending. The stamp lands about a millisecond after the real lift, which only lengthens the window by that much.
- **The lift frame must beat the click to the tap for the long-rest case.** With the thumb rested more than 3 s and a finger down, the level is `.dockSwipes`, where a physical press passes (R3). A tap's click arriving in that state, before the lift frame has been stepped, would pass too. The probe says the click arrives at the lift, just after the lift frame, and both paths start from the same digitizer report, ours being shorter (driver → MultitouchSupport → our callback versus driver → window server → tap → our thread). The first slice measures the gap over twenty taps. If it ever inverts, the fallback is to tell a tap's click from a press by a field of the event (the probe already logs `mouseEventPressure` and `mouseEventSubtype`) and block only tap clicks from the fingers' landing; that is a different design and is not written here.
- **If dropping the type-29 event does not suppress Look up or Smart zoom,** the first slice finds the event that does: the probe logs every type but moves, drags, scrolls, pressure and keys, so the panel's trigger is in its log if a session tap sees it at all. If no tap sees it, R4 and R5 cannot be met this way and the plan is revised; R1 to R3 and R6 to R11 stand on their own.
- **The hold limit is the one number the probe has not measured.** macOS's longest tap hold is not documented; S1 measures it (the longest one-finger hold under the thumb that still clicks, and the longest three-finger hold that still shows Look up) and `GestureRules.tapActionHoldLimit` takes the larger, rounded up to the next 100 ms plus 100 ms. Too small leaks a click (R2); too large loses a deliberate click after a long hold under the thumb (the accepted kind of loss). The recognizer's own 400 ms tap limit is not reused on purpose: it says what fires, not what macOS clicks.
- **The swap scenario is proved on hardware, not by a row.** The probe found no click for a swap, and a swap series' fingers have rested past the hold limit by the time they lift, so the rule opens no window for them: there is nothing for a row to drop. S1 records the swap's events with Look up on, and S4's walkthrough checks the scenario. Should S1 ever see a click or a Look up for a swap, the hold limit is raised to cover it.
- **Accepted cost: the gated port stays on after a gesture until the first frame or event after its window.** While nothing touches the pad it is sent nothing but a mouse's own events (a wheel, a drag), the first of which closes it; otherwise the first frame of the next touch closes it. `docs/performance.md`'s numbers for ordinary pointing and scrolling stand: a touch with no thumb never opens the port, and a touch within half a second of a gesture pays one event's worth.
- **A trusted process whose tap the system refuses** (`AXIsProcessTrusted` true, the tap's creation nil) runs gestures with nothing blocked, as today; with Tap to click on its gestures would click. macOS does not produce that state for a session tap with the permission, and no feedback path from the adapter to the model is added for it.
- **The four slices land together.** After S2 alone a gesture under Tap to click clicks and a three-finger gesture under Look up shows the panel, which is the problem statement; nothing is merged or released between S2 and S4, and S2 waits for S1 so that a failed assumption revises the plan before any of it lands.
- **The old notice's button goes from the no-trackpad notice too.** R7 says the *Open Trackpad Settings…* button never shows; R11 says the no-trackpad notice stays as it is. They meet at the button, which the two notices shared; the plan keeps the text and removes the button, since R7 says "ever" and the Trackpad pane has nothing to offer with no trackpad connected. This is the human's call and the final report asks for it; if the button is wanted, R11 should say so and T31 gains it.
- **"The gesture hint" in R7 and R8 names nothing in today's window.** `Copy.gestureHint` was removed in an earlier plan; today the window ends with the notice groups. The plan reads "in place of the gesture hint" as "in the window's notice group" and "the gesture hint shows as usual" as "the window shows no notice".
- **Why a run flag and not blocking every click in the window.** With Tap to click off, no click comes from a tap, and blocking a deliberate press within 0.5 s of a gesture would be a regression for those users (the third non-goal). The flag is global rather than per trackpad: the tap cannot tell which trackpad a click came from, and a Magic Trackpad with Tap to click on beside a built-in one without it loses only a deliberate click within 0.5 s of a gesture on the built-in.
- **Field 110 = 24 is the symbolic hot key event type, which Look up shares with other system shortcuts bound to gestures.** Dropping it only under a thumb touch with two or more contacts, or in the lift window, keeps the blast radius to taps under the thumb, where the Dock swipe rule already blocks the system's own gestures. If the first slice finds a sub-field naming the hot key, the parser narrows to Look up.
- **A Tap to click change re-runs the trackpads**, replacing recognizers and the tap, as every other `Run` change does. A swipe in progress at that moment ends, as it does when the swipe setting flips; the user is in System Settings when that happens.
- **Docs.** `docs/domain-model.md`: *Conflicting setting* becomes *Tap-bound setting*; *Gestures active / inactive* carries the permission; *Trackpad settings notice* becomes *No trackpad notice* and *Tap-bound settings notice*; *Accessibility hint*, *Settings window*, *Click blocking*, *Blocking window*, *Tap* and *Swap series* point to the new entries; *Tap action* and *Lift window* are new. `docs/architecture.md`: the gated port's "when it is on" sentence, the "time passes only" paragraph (the lift window's stamp and its lazy close) and the Privacy paragraph (what Accessibility is used for, what works without it). `docs/product-overview.md` and the README do not mention the settings and are unchanged.

## Slices

### S1: The three hardware assumptions, verified with the probe

**What to build:** No shipped code. The existing probe in `plans/027-tap-to-click-gestures/.temp/probes/` gains a drop mode that returns nothing for type-29 events whose field 110 is 22 or 24, logging each with its phase field, and is run on a real trackpad to settle what R2, R4 and R5 rest on: that the drop suppresses the Look up panel and the zoom, that each is one event, and that a tap's click arrives after its lift frame. The findings are written to the development log so the tap-side slices can proceed, or the plan can be revised before them.

**Blocked by:** None (can start immediately).

**Requirements:** None delivered; informs R2, R4 and R5.

**Test scenarios:** None.

**Skills:** None.

- [x] The probe has a drop mode (an argument) that returns nil for type-29 events with field 110 equal to 22 or 24 and logs each with its phase field (132) and every integer field that differs between a Look up and another hid-24 event; everything else passes as today. Its frame callback does the app's own pre-step work before taking the receipt time (the three `CGEventSource.buttonState` reads of `anyMouseButtonDown()`, parsing the touches into the app's frame type, and a step of a `GestureRecognizer`), so the measured gap is the app's, not a lighter one. It stays under `.temp/probes/`, outside the source-scan test's roots.
- [x] Look up set to Tap with three fingers, the pointer over a word, drop mode on: ten three-finger taps with the thumb anchored and ten without, and the Look up panel never appears; drop mode off, it appears each time. The log, with how many hid-24 events each tap produced and their phases, is kept under `.temp/probes/` and summarised in `development-logs.md` under Implement.
- [x] Smart zoom on, the pointer over a web page, drop mode on: ten two-finger double taps with the thumb anchored and ten without, and the page never zooms; drop mode off, it zooms each time. Logged and summarised the same way, with the hid-22 event count and phases per double tap.
- [x] Drop mode off: a Launchpad pinch, a Show Desktop spread, a Notification Center edge swipe and a three-finger drag, each a few times, and the type and field-110 numbers each produces are recorded, so hid 24's breadth is known and any sub-field that names Look up is found.
- [x] Tap to click on, the thumb rested more than 3 s: fifty one-finger taps on the built-in trackpad and fifty on a Magic Trackpad where one is at hand; for every one the lift frame's receipt precedes the LEFT DOWN's receipt by at least 1 ms, and the smallest and largest gaps are recorded. The same for twenty two-finger taps with Smart zoom off (RIGHT DOWN at the lift) and ten with it on (RIGHT DOWN later).
- [x] The hold limit: one-finger taps under the thumb held longer and longer (100 ms steps, three at each length) until macOS stops clicking, and three-finger taps likewise until Look up stops appearing; the longest hold that still acts is recorded for each, and the value `GestureRules.tapActionHoldLimit` is to take (the larger, rounded up to the next 100 ms, plus 100 ms) is written down.
- [x] Look up on: ten swaps (two fingers rest, the thumb taps, the fingers lift); whether any hid-24 event or any click arrives is recorded.
- [x] Dragging on: a one-finger tap under the thumb, then a touch-and-move within 0.5 s; the events (a LEFT DOWN at the second touch, drags, the LEFT UP at the lift) are recorded.
- [x] The findings are in `development-logs.md`. If the drop does not suppress Look up or Smart zoom, if either arrives as several events, if any click precedes its lift frame by less than the margin, or if a swap ever clicks or looks up, nothing further starts until the plan has been revised (Further Notes name the fallbacks).

Done: findings in `development-logs.md` under Implement. Deviations: Look up arrives as a pair of hid-24 events (each judged on its own); the swap can click (covered by the series, needs a row); the hold limit is 400 ms; no Magic Trackpad or Dragging run.

### S2: Tap-bound settings need Accessibility, not silence

**What to build:** With the Accessibility permission, Tap to click and Look up: Tap with three fingers no longer turn gestures off: gestures, swipes, window swipes and swaps run, and turning a setting on or off while running keeps them running. Without the permission they still turn gestures off, and the settings window says so with the exact R8 sentence and an *Open Accessibility Settings…* button, hiding the Accessibility hint while it does; the old trackpad-settings notice and its button are gone; "No trackpad connected" keeps its text and its priority. The window follows a grant or a revoke while open.

**Blocked by:** S1 (its findings may revise the plan before anything lands; the four slices land together).

**Requirements:** R1; R6 in part (activity, what runs, the notice; the click after a grant is T27 in S3); R7; R8; R9; R10; R11.

**Test scenarios:** T1, T2, T3, T4 (without its last clause, the dropped click, which S3 adds), T26, T28, T29, T30, T31.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-swiftui`.

- [x] `TapBoundSetting` and `TapBoundSettings` replace the conflicting-setting names everywhere (sources, tests, comments); `grep -rn "Conflicting" LauncherKit docs` returns nothing.
- [x] `GestureActivity` takes the grant; `.settingsNeedAccessibility` replaces `.settings`; the pure "which tap-bound settings are on for a connected trackpad" helper exists and the reconcile uses it for both activity and `Run.blockTapClicks` (the flag is carried through `TrackpadHardware.run` to both adapters and stored on the `TapFilters` they build, read by nothing yet).
- [x] `Copy.inactiveNotice(for:)` produces the three R8 sentences and the no-trackpad sentence; `Copy.trackpadSettingsButton` and the Trackpad `SettingsPane` are deleted; `grep -rn "Open Trackpad Settings\|trackpadSettingsButton\|preference.trackpad" LauncherKit TrackpadLauncher` returns nothing.
- [x] `Launcher.inactiveNotice` and `Launcher.showsAccessibilityHint` exist; the settings view renders the notice from the model (its message, and the *Open Accessibility Settings…* button only when the value carries one) and the hint from `showsAccessibilityHint`; the shell's refit reads both; the no-trackpad notice shows no button; the tap-bound settings notice's button opens the Accessibility pane through the existing open-pane action.
- [ ] Manual, on the Debug build: with Tap to click on and the Debug build's Accessibility off, the window shows the R8 sentence with its button and no Accessibility hint; the button opens System Settings at Accessibility; granting there makes the notice disappear within 5 s with the window open; with both settings off and no permission, the Accessibility hint shows as before.
- [x] The existing rows named in the last implementation decision are updated as described (`ActivityTests`, `ClickBlockingTests.blockingIsArmedOnlyWhileGesturesAreActiveAndAccessIsGranted`, `TapGateRecoveryTests.tapToClickTurnsTheTapOff`, `WindowSwitcherOnScreenTests.whileGesturesAreInactiveAWindowSwipeShowsNothingEvenIfOneWasInFlight`, `CopyTests`, `AccessibilityTests`); `swift test` is green.

### S3: A tap under the anchored thumb never clicks

**What to build:** With Tap to click on and the permission, every gesture, swipe, window swipe and swap leaves no click behind: the click macOS makes at the lift, the right click it makes up to 0.3 s later, a click after a thumb rested for seconds, three quick gestures in a row, and a tap-and-hold drag begun within half a second are all swallowed, whether or not the thumb is still down; a tap with no thumb, a tap a second after the thumb has gone, and a physical press after the thumb's first 3 s click as they do today.

**Blocked by:** S1 (the lift frame precedes the click), S2 (gestures run with Tap to click on).

**Requirements:** R2; R3; R6's remaining part (the click after a grant).

**Test scenarios:** T4's last clause, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T27, T33, T36.

**Skills:** `macos-dev-workflow:swift-concurrency`, `macos-dev-workflow:swift-testing-pro`.

- [x] `Recognition.opensLiftWindow`, `GestureRules.liftWindow` (0.5 s) and `GestureRules.tapActionHoldLimit` (S1's value) exist; the recognizer sets the flag exactly as the third decision says: a non-thumb contact lifting inside a thumb touch, down for less than the hold limit, with no press seen while it was down; never the thumb alone; never outside a thumb touch.
- [x] `Uptime` exists in core with no clock read; the platform reads `now` in one place, and the source-scan test confines `systemUptime` to that file; the `DeviceSession` takes its clock as a dependency; the trackpad state value (level plus lift window end, `follow`, `liftWindowIsOpen(at:)`, `wantsTap(at:)`) and the merge exist in core and both adapters use them; `TapContext` and `estimated(from:)` carry `liftWindowIsOpen`.
- [x] `TapFilters` blocks presses in an open window when it blocks tap clicks and holds the gate open while a window is open; `ClickFilter`, `ScrollFilter` and `DockSwipeFilter` are untouched.
- [x] The fake owns a monotonic `Uptime` clock that follows the frames and has `advanceClock(by:)`; `offer(.pointer(.press(_)))` is decided at that clock; the nine `TapGateTests` rows named in the last implementation decision wait past the window before asserting the close, their other assertions untouched; `DeviceSessionAnswerTests.theTapIsWokenOnlyWhenTheTrackpadStartsOrStopsWantingIt` advances its injected clock; `TapFiltersTests` and `TapContextTests` build contexts with the flag.
- [x] Comments updated: `Blocking`'s and `Recognition`'s docs name the lift window; `TapFilters`'s invariant names it; `TrackpadHardware.run`'s doc names `blockTapClicks`.
- [ ] `swift test` is green; the Debug build on hardware, Tap to click on, the pointer over a control that shows each click (a checkbox): a one-finger tap under the thumb opens its app and the control is not toggled; a two-finger tap opens its app and no context menu appears; twenty one-finger taps after the thumb has rested 5 s toggle the control zero times; two physical clicks 300 ms apart under a thumb rested 4 s toggle it twice; a tap with no thumb toggles it once.

### S4: A tap under the anchored thumb never looks up or zooms

**What to build:** With the permission, a three-finger gesture never shows the Look up panel and two quick two-finger gestures never Smart-zoom the page, whatever Tap to click is set to and whether the thumb is still down; a three-finger tap and a two-finger double tap with no thumb still do, and so does Smart zoom without the permission.

**Blocked by:** S1 (the event and its drop verified), S3 (the lift window and the gate).

**Requirements:** R4; R5.

**Test scenarios:** T19, T20, T21, T22, T23, T24, T25, T32, T34, T35.

**Skills:** `macos-dev-workflow:swift-testing-pro`.

- [x] `TapEvent.tapAction(TapAction)` with `lookUp` and `smartZoom` exists, rides the gated port, and is decided in `TapFilters` as the sixth decision says; the fake can be offered it.
- [x] The click tap parses type 29 with field 110 = 24 as Look up and = 22 as Smart zoom (narrowed by any sub-field S1 found), beside the Dock swipe's numbers; a dropped tap action returns nil to the window server.
- [ ] `swift test` is green; the Debug build on hardware, with Look up set to Tap with three fingers and Smart zoom on: a three-finger gesture over a word opens its app and no Look up panel appears, with Tap to click on and off; a three-finger tap with no thumb shows Look up; two two-finger gestures within half a second over a web page open their app twice and the page does not zoom; a two-finger double tap with no thumb zooms; with the Debug build's Accessibility revoked and both tap-bound settings off, the double tap under the thumb fires the gesture twice and zooms.
- [ ] Final walkthrough of every scenario in R1 to R6 on the Debug build, built-in trackpad, with a Magic Trackpad where one is at hand, R2's swap scenario included (it has no row: the swap happens, no context menu opens, no Look up panel appears); anything that differs from its scenario is logged in `development-logs.md` under Implement before the slice is closed.
