# Plan: Hold thumb setting

## Problem statement

Every tap gesture needs the thumb held in the anchor corner. Some users find the thumb a hassle. They want a plain tap with one to five fingers to launch the app they assigned. Today they have no way to drop the thumb.

## Solution

A new *Hold thumb* switch sits at the end of the settings window's first group, below *Animate app launch*. It is on by default, and nothing changes while it is on. While it is off, a tap with one to five fingers on an otherwise empty trackpad fires that finger count's gesture, with no thumb. Taps under a held thumb keep working as today. The swipe, the window swipe and the swap still need the thumb. The setting only drops the thumb for launching.

A thumbless tap leaves macOS alone. It blocks nothing, so a tap macOS turns into a click, right-click or Look up does that too. Users who mind can turn off Tap to click, or leave that finger count without an app.

## Requirements

### R1. The Hold thumb switch sits at the end of the first group
The settings window MUST show a *Hold thumb* switch as the last row of the group that holds the five gesture rows, directly below the *Animate app launch* switch.

#### Scenario: Switch placement
- **WHEN** the user opens the settings window
- **THEN** the first group shows the five gesture rows, then *Animate app launch*, then *Hold thumb*, and nothing after it in that group

### R2. Hold thumb is on by default
On a fresh install the Hold thumb setting MUST be on.

#### Scenario: Fresh install
- **GIVEN** Trackpad Launcher has never run on this Mac
- **WHEN** the user opens the settings window
- **THEN** the *Hold thumb* switch is on

### R3. While on, gestures need the held thumb as today
While the Hold thumb setting is on, a tap without a thumb anchored in the anchor corner MUST fire no gesture.

#### Scenario: Plain tap with the setting on
- **GIVEN** Hold thumb is on and the 2-finger gesture has an app
- **WHEN** the user taps two fingers on an empty trackpad, with no thumb in the corner
- **THEN** no gesture fires, and macOS handles the tap as it would without Trackpad Launcher

### R4. A thumbless tap is a short, clean tap on an otherwise empty trackpad
Trackpad Launcher MUST recognise as a thumbless tap only a touch that meets all of these:
- One to five fingers touch one trackpad.
- The first finger lands while no other contact is on that trackpad (edge contacts aside).
- No contact lands inside the anchor corner during the tap. A contact in the anchor corner is a thumb, never a tap finger, and any touch with one follows today's thumb rules only.
- Every finger lifts within the tap window (400 ms from the first landing) without dragging more than 3 mm.
- The trackpad is not physically pressed to a click during the touch. A touch with such a press is not a tap.

The finger count is the number of fingers that touched during the tap. The gesture fires when the last finger lifts. A finger landing after the trackpad is empty again starts a new tap.

#### Scenario: Too slow
- **GIVEN** Hold thumb is off and the 1-finger gesture has an app
- **WHEN** a finger lands and lifts 410 ms later without moving
- **THEN** no gesture fires

#### Scenario: A drag is no tap
- **GIVEN** Hold thumb is off and the 1-finger gesture has an app
- **WHEN** a finger lands, moves 3.5 mm and lifts within 400 ms
- **THEN** no gesture fires

#### Scenario: A finger already resting
- **GIVEN** Hold thumb is off, the 1-finger gesture has an app, and one finger rests on the trackpad moving the pointer
- **WHEN** a second finger taps while the first stays down
- **THEN** no gesture fires

#### Scenario: A press cancels the tap
- **GIVEN** Hold thumb is off and the 1-finger gesture has an app
- **WHEN** the user presses the trackpad down to a click with one finger and lifts within 400 ms
- **THEN** the click reaches the app under the pointer and no gesture fires

#### Scenario: Edge contacts do not count
- **GIVEN** Hold thumb is off, a palm rests in the edge contact band, and the 2-finger gesture has an app
- **WHEN** the user taps two fingers elsewhere on the trackpad
- **THEN** the 2-finger gesture fires

#### Scenario: Six fingers
- **GIVEN** Hold thumb is off
- **WHEN** the user taps six fingers on an empty trackpad
- **THEN** no gesture fires

#### Scenario: Thumb and fingers land together
- **GIVEN** Hold thumb is off and the 2- and 3-finger gestures have apps
- **WHEN** the thumb lands in the anchor corner, two fingers land after it and lift within 400 ms, and then the thumb lifts
- **THEN** the 2-finger gesture fires once, as a thumb-held tap, and the 3-finger gesture does not

#### Scenario: Thumb and fingers land on the same frame
- **GIVEN** Hold thumb is off and the 2- and 3-finger gestures have apps
- **WHEN** the thumb and two fingers land in the same instant and all lift within 400 ms
- **THEN** no gesture fires, as today under the thumb rules

#### Scenario: One finger taps in the corner
- **GIVEN** Hold thumb is off and the 1-finger gesture has an app
- **WHEN** a single finger taps inside the anchor corner on an empty trackpad
- **THEN** no gesture fires

#### Scenario: Quick swap
- **GIVEN** Hold thumb is off, the swap setting is on, and the 2-finger gesture has an app
- **WHEN** two fingers land, then the thumb taps the anchor corner, and all lift within 400 ms
- **THEN** the swap happens and no tap gesture fires

#### Scenario: Double tap
- **GIVEN** Hold thumb is off and the 1- and 2-finger gestures have apps
- **WHEN** one finger taps twice on an empty trackpad, both taps within 400 ms
- **THEN** the 1-finger gesture fires twice, and the 2-finger gesture never fires

### R5. While off, a thumbless tap fires its gesture
While the Hold thumb setting is off, a thumbless tap MUST fire the gesture for its finger count.

#### Scenario: One to five fingers
- **GIVEN** Hold thumb is off and each of the 1- to 5-finger gestures has an app
- **WHEN** the user taps N fingers (N from 1 to 5) on an empty trackpad
- **THEN** the N-finger gesture's app comes to the front with the gesture haptic

#### Scenario: Unassigned finger count
- **GIVEN** Hold thumb is off and the 3-finger gesture has no app
- **WHEN** the user taps three fingers on an empty trackpad
- **THEN** nothing opens and no gesture haptic plays

### R6. A thumbless tap launches like a thumb-held tap
A thumbless tap MUST bring the same app to the front as the same tap under an anchored thumb, with the same gesture haptic, launch animation and hide background apps behaviour. It differs only in blocking nothing (see R7).

#### Scenario: Hide background apps
- **GIVEN** Hold thumb is off, Hide background apps is on, and the 1-finger gesture has an app
- **WHEN** the user taps one finger on an empty trackpad
- **THEN** the gesture's app comes to the front and the other apps hide, as for a thumb-held tap

### R7. A thumbless tap blocks nothing
A thumbless tap MUST NOT block any press, tap action, scroll or system swipe, during or after it. Blocking a thumb-held tap still causes, such as its lift window, is unchanged (see R9).

#### Scenario: Press right after a thumbless tap
- **GIVEN** Hold thumb is off and a thumbless tap has just fired
- **WHEN** the user presses the trackpad right after
- **THEN** the press reaches apps

#### Scenario: Scroll right after a thumbless tap
- **GIVEN** Hold thumb is off and a thumbless tap has just fired
- **WHEN** the user scrolls with two fingers right after
- **THEN** the page scrolls

#### Scenario: Three-finger swipe right after
- **GIVEN** Hold thumb is off, the system's three-finger swipe between desktops is on, and a thumbless tap has just fired
- **WHEN** the user swipes three fingers sideways right after
- **THEN** macOS moves to the next desktop

### R8. macOS still makes its tap action
Whatever macOS makes for a thumbless tap, such as a click, right-click or Look up, MUST still happen alongside the gesture. Which app receives that click, the one under the pointer before or after the gesture's app comes forward, is not specified.

#### Scenario: Tap to click on
- **GIVEN** Hold thumb is off, Tap to click is on, and the 1-finger gesture has an app
- **WHEN** the user taps one finger on an empty trackpad
- **THEN** the gesture's app comes to the front, and macOS also clicks, wherever macOS sends it

#### Scenario: Look up on
- **GIVEN** Hold thumb is off, Look up: Tap with three fingers is on, and the 3-finger gesture has an app
- **WHEN** the user taps three fingers on an empty trackpad
- **THEN** the gesture's app comes to the front, and macOS also shows Look up, wherever macOS sends it

#### Scenario: Turning it back on by tap
- **GIVEN** Hold thumb is off, Tap to click is on, and the 1-finger gesture has an app
- **WHEN** the user taps the *Hold thumb* switch with one finger in the settings window
- **THEN** the switch turns on, and the 1-finger gesture's app also comes to the front

### R9. Taps under a held thumb are unchanged while off
While the Hold thumb setting is off, a tap under an anchored thumb MUST behave with the same gesture, click blocking, tap action blocking and Dock swipe blocking as while the setting is on.

#### Scenario: Thumb-held tap with the setting off
- **GIVEN** Hold thumb is off, Tap to click is on, and the 2-finger gesture has an app
- **WHEN** the user anchors the thumb in the corner and taps two fingers
- **THEN** the 2-finger gesture fires once, and the right-click is blocked

### R10. The swipe, the window swipe and the swap still need the thumb
The Hold thumb setting MUST NOT change the swipe, the window swipe or the swap: each still starts only as it does today, with the thumb.

#### Scenario: Two fingers slide without a thumb
- **GIVEN** Hold thumb is off and the swipe setting is on
- **WHEN** the user slides two fingers sideways with no thumb in the corner
- **THEN** no switcher shows, and the slide scrolls as usual

#### Scenario: Swipe with the thumb while off
- **GIVEN** Hold thumb is off and the swipe setting is on
- **WHEN** the user anchors the thumb and slides two fingers sideways
- **THEN** the switcher shows as it does today

### R11. A change applies to the next tap and is saved at once
Flipping the Hold thumb switch MUST take effect from the next tap, with no relaunch. The setting MUST be saved at once, so it survives a quit, a force-quit or a Mac restart.

#### Scenario: Turning it off
- **GIVEN** Hold thumb is on and the 1-finger gesture has an app
- **WHEN** the user turns the switch off and then taps one finger on an empty trackpad
- **THEN** the 1-finger gesture fires

#### Scenario: Survives a restart
- **GIVEN** the user turned Hold thumb off
- **WHEN** the Mac restarts and Trackpad Launcher starts at login
- **THEN** Hold thumb is still off, and a thumbless tap fires its gesture

#### Scenario: Survives a force-quit
- **GIVEN** Hold thumb is on
- **WHEN** the user flips the switch off, force-quits Trackpad Launcher at once and reopens it
- **THEN** the switch shows off

### R12. Upgrading leaves Hold thumb on
Upgrading from a version without the Hold thumb setting MUST leave it on and change no other setting. The setting MUST be stored so that an older version without it, installed over this one, still starts with every other setting intact.

#### Scenario: Upgrade
- **GIVEN** a user on a version without the setting, with the launch animation off and an app on every gesture
- **WHEN** they upgrade
- **THEN** Hold thumb is on, the launch animation is still off, and every gesture keeps its app

#### Scenario: Downgrade
- **GIVEN** Hold thumb is off and every gesture has an app
- **WHEN** the user installs an older version without the setting
- **THEN** every gesture keeps its app, and that version needs the thumb as usual

### R13. The setting adds no ongoing cost
Introducing the Hold thumb setting MUST NOT add a new input listener, event tap or timer, in either state. This is judged by reviewing the implementation.

#### Scenario: Off, during ordinary use
- **GIVEN** Hold thumb is off
- **WHEN** the user moves the pointer and scrolls without tapping
- **THEN** pointer movement and scrolling behave exactly as with the setting on, and no new permission is requested

## Non-goals

- **Blocking the tap action of a thumbless tap.** The user decides: they turn off Tap to click, or leave that finger count without an app. Blocking it would turn off tap-to-click across the Mac for any assigned 1-finger gesture.
- **Changing the gesture illustrations and the *Hold* / *Tap* guide while the setting is off.** The pictures keep showing the thumb for now. A follow-up change will update them.
- **Thumbless swipe, window swipe or swap.** Without the thumb they collide with scrolling and macOS's own gestures. The setting is only for launching.
- **Filtering accidental touches.** Any touch that meets the thumbless tap definition fires, such as a tap to stop momentum scrolling, a brief pointer nudge under 3 mm, or the first tap of tap-and-drag. Users who mind keep Hold thumb on.
- **A per-trackpad setting.** One setting covers every trackpad; the MacBook and external trackpads do not get their own.
- **Explaining the Tap to click overlap in the app.** The switch has no caption about it.

## Implementation Decisions

- **One new field in the settings record, on by default.** The record gains a Boolean for Hold thumb, `isHoldThumbOn`, default true, under a key that is the field's name permanently, read by the record's decoding rule. An absent key reads as on, so every record written so far loads with Hold thumb on and nothing else changed (R2, R12). A build that does not know the key ignores it, so a downgrade keeps every other setting (R12). It sits in the record like its sibling switches, not in a key beside it: nothing about it has to outlive a downgrade. A version without the setting that saves the record drops the choice, so this version installed again starts with Hold thumb on.

- **The model: one read, one intent.** `Launcher` exposes whether Hold thumb is on, and one intent to set it. The intent does nothing when the value is unchanged. Otherwise it sets the field, saves the record at once and reconciles, exactly as the swap setting's intent does. The reconcile sees a changed run, so every trackpad gets a fresh recognizer: the next tap obeys the switch with no relaunch (R11). `fire` is not touched.

- **Prefactor: one value carries what a run's recognizers recognise.** Today the slide kinds and the swap flag travel as two separate parameters from the model's record of the last run, through the hardware port's `run`, into each recognizer's initializer, and both adapters repeat them. A third flag would put two Booleans side by side in the one place no test reaches, the real adapter's `run`, where transposing them compiles. So, before the feature: a small `Hashable`, `Sendable` value in core, `RecognizerOptions`, holds the slide kinds and whether swaps are recognised. It is declared beside the recognizer, in the source file that already holds `Recognition` and `Blocking`, which the source-scan test already lists as frame-path code, so that test's lists do not change. The model's run record holds it, `TrackpadHardware.run` takes it in place of the two parameters, and `GestureRecognizer`'s initializer takes it whole: corner, surface, options, travel. Neither adapter reads a field of it; each hands the value it was given to every recognizer it builds. Nothing a user can see changes. From then on a new recognition option is a field on that value, the model's derivation of it, and the recognizer; the port and both adapters stay as they are.

- **Thumbless taps are one more option.** `RecognizerOptions` gains `thumblessTaps`. The model sets it to the opposite of Hold thumb, whatever the Accessibility permission: a thumbless tap needs none. The value's initializer has no default arguments, so the model spells every option.

- **The recognizer: a rest that began on an empty trackpad may be a thumbless tap.** The recognizer already has the state a thumbless tap lives in: the rest, contacts that landed with no thumb anchored. With the option on, a rest that begins cleanly also carries a tap candidate, kept with the same bookkeeping the thumb-held tap uses: its first landing time, the fingers down now, and every finger that touched. A rest begins cleanly when all of these hold on its first frame:
  - the frame before had no contact (edge contacts are removed before the recognizer's states see a frame, so they never count);
  - every contact on the frame landed on it, at a known time. A contact already resting on the first frame after recognition restarted has no landing time;
  - no contact landed inside the anchor corner. The existing rule already makes that contact a thumb and the touch no rest;
  - the frame carries no press.

  On each later frame, fingers that lifted leave the candidate first. Then one of two cases applies.

  While at least one of its fingers is still down, the first of these rules that applies wins:
  1. a contact lands inside the anchor corner, or the frame carries a press, delivered or withheld: the candidate ends;
  2. one of its fingers is more than 3 mm from its landing point: it ends;
  3. more than 400 ms have passed since its first landing: it ends;
  4. otherwise fingers landing on the frame join it.

  On the frame its last finger is gone, the tap is over and only the time is judged. Past 400 ms the candidate ends silently. Otherwise it fires the gesture for the number of fingers that touched, nothing for six or more. Whatever else that frame carries belongs to what comes next, not to the tap: a press first seen there, and a contact landing there. After a tap that fired, fingers landing on that frame, a finger the driver reports as landing anew under its old ID included, start a new candidate when the frame carries no press and none of them landed in the anchor corner, as fingers start a new tap after a thumb-held one.

  The two limits are the thumb-held tap's own constants, not copies. A candidate that ended never comes back for that rest: the rest carries on exactly as today, so a thumb landing under it may still swap. A rest that begins any other way (the thumb lifted or rolled away, a slide ended or was declined) never carries a candidate. With the option off no candidate is ever made, so the recognizer does what it does today.

- **A press ends a candidate only while one of its fingers is down.** Under the thumb a press the click filter withholds is part of the tap. A thumbless tap has no such case: R4 excludes every physical press, so a frame with any press, delivered or withheld, ends the candidate. But R4 excludes a press *during the touch*, and a press first seen on the frame the last finger is gone cannot be a press of those fingers. That frame is where the tap's own Tap to click click would show if it ever beat the lift frame: plan 027 measured that click 2 to 13 ms after the lift frame and called the margin narrow. Under the thumb a lost race rarely matters, because the click is withheld there. A thumbless tap would run the race on every tap, and losing it would drop the gesture in exactly R8's "Tap to click on" case, so the thumbless tap does not run it. The thumb-held tap's own rule, a delivered press on any frame through the lift frame, is left as it is (R9). The press is the sample every frame already carries; nothing new reads the button.

- **A thumbless tap fires the event a thumb-held tap fires.** The recognizer reports the existing fired-gesture event, the port carries the existing gesture event, and the model's `fire` runs. The model cannot tell the two taps apart, so the app, the gesture haptic, the launch animation, the launch bounce and the hide are the same by construction (R6), and an unassigned or missing count is silent by `fire`'s existing guard (R5).

- **Blocking is not edited.** The blocking level, the thumb touch and the lift window are computed as today. A thumbless tap is a rest with no thumb, outside any thumb touch, so its frames report no blocking and open no lift window (R7). The click tap's gated port therefore stays off, the press port passes the click, and whatever macOS makes for the tap goes through (R8). Taps under the thumb, the swipe, the window swipe and the swap run through states this change does not edit (R9, R10).

- **The switch.** The settings form's first section gains one row after *Animate app launch*: a switch titled *Hold thumb*, in the form's own switch style and row height like its sibling, reading the model's value and sending the model's intent (R1). The row always shows, so the window's height rule is untouched.

- **Nothing new listens, wakes or asks (R13).** The frame callback already runs the recognizer on every frame of every touch on every running trackpad, whatever the settings: it must, to see a thumb land. A thumbless tap is recognised inside that step from the frame it is already handed. No callback, event tap, monitor, observer, timer, thread, lock or clock read is added, in either state of the switch. With Hold thumb on, the added work is one Boolean test when a rest begins. With it off, it is a few set operations per frame for at most the first 400 ms of a touch that began on an empty trackpad, and one hop to the main actor per recognised thumbless tap, through the delivery every fired tap already uses; a tap whose finger count has no app ends at `fire`'s first guard. A thumbless tap's frames report no blocking, so ordinary pointing, scrolling and dragging still never reach the app. No permission is involved.

- **Alternatives rejected.**
  - *A tap tracker beside the state machine.* It would follow the same contacts as the rest, in parallel, and two records of one touch can disagree.
  - *A new state before the rest.* A thumb landing under the fingers inside the tap window must still be able to swap (R4, quick swap), so that state would have to be a rest as well.
  - *A third parameter beside the slide kinds and the swap flag.* See the prefactor.
  - *A fired event that says the tap was thumbless.* Nothing downstream differs (R6).
  - *Telling recognizers which finger counts have an app, to spare the hop for an unassigned count.* Every assignment change would then rebuild the recognizers, to save one main-queue block per tap.

## Testing Decisions

### Strategy

The requirements are proven at the highest existing seam, `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`): the real `Launcher` and the real `SettingsStore` on a throwaway `UserDefaults` suite, over `InMemoryTrackpads`, whose `run` builds a real `GestureRecognizer` for each trackpad and a real `TapFilters` behind a model of the window server's two ports. A row flips the setting through the model's intent, plays scripted frames (`TouchScript`, or `HandFrames` for interleavings a script cannot sequence), and observes:
- what fired: `system.broughtToFront`, `hardware.pulses` and `feedback`, `system.launchAnimations`, `bounces` and `hidesOthers`;
- what was blocked: `hardware.isGatedPortOn`, `pressVerdicts`, and what `offer(_:)` and `scroll(_:)` answer for a click, a tap action, a scroll and a Dock swipe;
- `launcher.switcher` and `windowSwitcher`;
- the setting as the model reads it and as a new process would: `launcher.isHoldThumbOn`, `freshStore().load()`, `settingsRecordBytes()` and `relaunch()`.

One row, T19, runs at the existing seam below it, the recognizer's own interface (frames in, `Recognition` out, through the helpers in `Fixtures.swift`). Only there is every frame's whole `Recognition` visible, which "unchanged under the thumb" is a statement about. No new seam is added.

The new rows resemble: `SwapSettingTests.swift` (a setting flipped through its intent, then touches); `LiftWindowTests.swift` and `TapActionBlockingTests.swift` (what the fake tap does with the click or Look up that follows a tap); `PersistenceTests.swift` (records, the frozen released fixture and the frozen `Build1018Settings`); `GestureRecognizerTests.swift` (the same tap rules under the thumb, and its `HandFrames` interleavings); `SwapRecognizerTests.swift` (rows at the recognizer seam).

Faked, as today: the trackpad hardware port (scripted frames, frame times and the process clock are the fake's own), the system actions, the permissions and the trackpad preferences. `UserDefaults` is real, on a suite under the World's temp folder. Everything we own runs for real.

Test-side handles: the fake's `run` takes the options value. One test-side convenience builds a recognizer from spelled-out options, so the existing recognizer suites keep their bodies; it gains a thumbless-taps argument that is off unless asked, which T19 uses. `World` gains a helper for a tap with no thumb, described under Test scenarios.

Hold thumb is on by default, so every existing suite keeps running with the setting on and keeps pinning today's behaviour.

The seam misses the views, which no test hosts (R1), and the absence of listeners, which is a property of the source and not of a run (R13). It also misses the real adapter's `run` and macOS itself: see Further Notes.

### Test scenarios

Terms used in the rows:
- *Thumbless world*: `World(apps: ["Arc", "Figma", "Notion", "Spotify", "Slack"])`, started, the five apps on gestures 1 to 5 in that order, then Hold thumb turned off through the intent. "With access" adds the Accessibility permission, with Tap to click on for the built-in trackpad.
- *A tap of N*, optionally at a point or on another trackpad: a new `World` helper that delivers `TouchScript(surface).tap(fingers: N)`, with no thumb, straight to the fake, as `World.tap` does for a tap under the thumb. The fingers are 8 mm apart from (62, 45) unless a point is given, and down for 120 ms. Taps made this way can follow one another in one world.
- *Continues*: `World.play` drops every frame that is not newer than the last one it delivered on that trackpad, so a second fresh script played through it never arrives. A row uses `play`, `swipe`, `windowSwipe` or `swap` only for the first touch of a world or to continue one script. Each lettered case, and each value of a case that runs over several values, runs in a fresh world unless it says it continues.
- *Fires X*: X is the one new entry in `broughtToFront`, with one gesture pulse on the trackpad tapped. *Nothing fires*: `broughtToFront`, `pulses`, `launchAnimations` and `bounces` are unchanged.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2 | World | Given a fresh `World` that never saved settings. When it starts and is opened by hand. Then `launcher.isHoldThumbOn` is true. | R2 |
| T2 | R3 | World | Given the five apps on gestures 1 to 5, with access, Hold thumb left on. When a tap of N is played, for N in 1...5. Then nothing fires, the gated port is off, and the click offered right after (press and release) passes. | R3's scenario: no gesture fires, and macOS handles the tap as without Trackpad Launcher |
| T3 | R5, R6 | World | Given a thumbless world with the five apps running. When a tap of N is played, for N in 1...5. Then `broughtToFront == [the app on gesture N]`, `feedback == [macBook14.id]` and `launchAnimations == [that app]`. | R5 scenario "One to five fingers"; R6 (the launch animation, which domain-model *Launch animation* gives a running target app) |
| T4 | R6 | World | Given two identical thumbless worlds, for each of these cases: Arc running; Arc with no process; Hide background apps on with Arc running; the launch animation off. When one world gets a tap of 1 and the other the same tap under a thumb at (10, 10). Then `broughtToFront`, `pulses`, `launchAnimations`, `bounces` and `hidesOthers` are equal between the two. In the hide case `hidesOthers == [Arc's bundle identifier]` in both. | R6: "the same app … as the same tap under an anchored thumb, with the same gesture haptic, launch animation and hide background apps behaviour"; R6's scenario |
| T5 | R5 | World | Given a thumbless world with gesture 3 set to None. When a tap of 3 is played. Then nothing fires. | R5 scenario "Unassigned finger count" |
| T6 | R4 | World | Given a thumbless world. (a) A one-finger tap held 390 ms fires Arc; held 410 ms, nothing fires. (b) Three fingers landing 75 ms apart, each down 200 ms (the last lifts 350 ms after the first landed), fire Notion; each down 300 ms (450 ms), nothing fires. | R4 "Every finger lifts within the tap window (400 ms from the first landing)"; scenario "Too slow" (410 ms) |
| T7 | R4 | World | Given a thumbless world. (a) A one-finger tap that drags 2.5 mm fires Arc; one that drags 3.5 mm fires nothing. (b) `HandFrames`: two fingers land together, one moves 3.5 mm while the other stays, both lift at 120 ms: nothing fires. | R4 "without dragging more than 3 mm"; scenario "A drag is no tap" (3.5 mm) |
| T8 | R4 | World | Given a thumbless world. (a) One finger lands and slides 10 mm over 300 ms and stays; a second finger lands, lifts 120 ms later; the first lifts. (b) One finger rests still for 500 ms; a second taps; the first lifts. Then in both nothing fires. | R4 scenario "A finger already resting" |
| T9 | R4, R8 | World | (a) Given a thumbless world with access. When one script holds a one-finger tap that carries a press, for each `TouchScript.ClickTiming` of `.onLanding`, `.firm` and `.midway`, and then a plain one-finger tap. Then the pressed tap fires nothing, `pressVerdicts == [.pass, .pass]`, and the plain tap fires Arc. (b) The same pressed tap in a thumbless world without the Accessibility permission fires nothing. (c) Given a thumbless world, with access and without. `HandFrames`: a finger lands at 0 ms, is down at 50 ms, and the frame at 100 ms has no contact and carries a press. Then Arc fires. | R4 scenario "A press cancels the tap": the click reaches the app and no gesture fires. For (c): R4 excludes a press "during the touch", and R8 scenario "Tap to click on": the gesture's app comes to the front although macOS clicks for the same tap, a click plan 027 measured arriving just after the lift frame |
| T10 | R4 | World | (a) Given a thumbless world. One script: a contact lands at (60, 75.5), 1.3 mm from the bottom edge of the 76.8 mm pad, and stays down; 600 ms later two fingers tap, then one finger taps. Then `broughtToFront == [Figma, Arc]`. (b) A lone contact that lands at (60, 75.5) and lifts 120 ms later fires nothing. | R4 scenario "Edge contacts do not count"; domain-model *Edge contact* (closer than 3 mm to the bottom edge; neither starts nor joins a tap) |
| T11 | R4 | World | Given a thumbless world. (a) Three fingers landing 10 ms apart and lifting 10 ms apart fire Notion once, and neither Arc nor Figma. (b) Four fingers landing 40 ms apart, each down 100 ms, so earlier ones lift while later ones land, fire Spotify once. (c) A tap of 6 fires nothing. | R4 "The finger count is the number of fingers that touched during the tap", "One to five fingers", scenario "Six fingers"; `GestureRecognizerTests.fourFingersLandingOneByOneWhileEarlierOnesLiftFireFour` for the same shape under the thumb |
| T12 | R4, R9 | World | Given a thumbless world, by `HandFrames`. (a) A contact lands at (10, 10) at 0 ms, two fingers land at 10 ms, the fingers lift at 120 ms, the thumb at 130 ms: Figma fires once and Notion never. (b) The thumb and two fingers land on one frame and all lift on one frame: Notion never fires, and nothing else does. (c) Two fingers land at 0 ms, a contact lands at (10, 10) at 10 ms, and all lift on one frame at 120 ms: Notion never fires, and nothing else does, with the swap setting on and with it off. | R4 scenarios "Thumb and fingers land together" (thumb first: the 2-finger gesture once, as a thumb-held tap; the 3-finger gesture never) and "Thumb and fingers land on the same frame" (no gesture fires); R4 "any touch with one follows today's thumb rules only", which `GestureRecognizerTests.thumbAndFingerLandingInTheSameFrameNeverFire`, `thumbLiftingInTheSameFrameAsTheLastFingerFiresNothing` and `fingersDownBeforeTheThumbNeverFire` pin |
| T13 | R4 | World | (a) Given a thumbless world. A tap of 1 at (10, 10): nothing fires. (b) Given a thumbless world with the thumb corner set to Bottom left. A tap of 1 at (10, 66.8): nothing fires. Then a tap of 1 at (10, 10): Arc fires. (c) Given a thumbless world with `[.macBook14, .magicTrackpad]` attached. A tap of 1 at (10, 105) on the Magic Trackpad: nothing fires. Then a tap of 1 at (10, 10) there: Arc fires, with the pulse on the Magic Trackpad. | R4 scenario "One finger taps in the corner"; domain-model *Anchor corner* (20% by 25% from the thumb corner) and *Thumb corner* (the External trackpad corner is Bottom left once the Mac has mixed trackpads; each rule follows the trackpad the touch is on) |
| T14 | R4, R10 | World | (a) Given `World.switcherWorld()` (Safari, Mail, Slack and Notes running, Safari frontmost), Notes on gesture 2, Hold thumb off. When two fingers land, the thumb taps the corner 50 ms later for 120 ms, and the fingers lift 280 ms after they landed. Then `broughtToFront == [Mail]` with one gesture pulse and no launch animation: the swap, and never Notes. (b) In a fresh such world with the swap setting off, the same touch fires nothing. | R4 scenario "Quick swap"; `SwapSettingTests` (a swap from Safari brings Mail forward; with the swap off a thumb under resting fingers does nothing) |
| T15 | R4 | World | Given a thumbless world. (a) One script: one finger down 0 to 100 ms and again 200 to 300 ms: `broughtToFront == [Arc, Arc]`, two pulses. (b) `HandFrames`: one contact down from 0 ms, reported as landing again under the same ID at 60 ms with no empty frame between, gone at 120 ms: `[Arc, Arc]`. (c) `HandFrames`: finger 1 lifts and finger 2 lands on the same frame, and finger 2 lifts 100 ms later: `[Arc, Arc]`. (d) `HandFrames`: a finger is down 0 to 100 ms, and on the frame it is gone a contact lands at (10, 10) and lifts 100 ms later: `[Arc]`. Figma never fires. | R4 scenario "Double tap"; R4 "The gesture fires when the last finger lifts. A finger landing after the trackpad is empty again starts a new tap"; `GestureRecognizerTests.reusedTouchIDLandingAgainStartsASecondTap` for the same frames under the thumb |
| T16 | R7, R8 | World | Given a thumbless world with access and Look up: Tap with three fingers on. (a) A tap of 1 played frame by frame: the gated port is off after every frame; Arc fires; the click offered right after (press and release) passes. (b) A tap of 2, the clock advanced 280 ms, then a right click offered: it passes; Figma fired. (c) A tap of 3, then the Look up pair: `[.notSent, .notSent]`; Notion fired. (d) A tap of 1, then `scroll(.fingers(.began)) == .pass` and `offer(.dockSwipe(.began, .gesture)) == .notSent`; then a one-finger firm-pressed tap delivered straight to the fake gives `pressVerdicts == [.pass, .pass]`. (e) One script: two fingers tap, and 80 ms later tap again: `broughtToFront == [Figma, Figma]` and `offer(.tapAction(.smartZoom)) == .notSent`. | R7's three scenarios and "any … tap action", which domain-model *Tap action* lists as the click, the right click, Look up and Smart zoom; R8 scenarios "Tap to click on" and "Look up on"; `TapActionBlockingTests.aThreeFingerTapWithNoThumbStillLooksUp` and `aDoubleTapOfTwoWithNoThumbStillZooms` (`.notSent` is an event the tap is never handed, so it reaches apps untouched) |
| T17 | R8, R11 | World | Given a thumbless world. When a tap of 1 is made, and then the Hold thumb intent is sent with on, as the click macOS made for that tap lands on the switch. Then `isHoldThumbOn` is true and `broughtToFront == [Arc]`. A further tap of 1 leaves it `[Arc]`. This pins the order the model sees. The fake delivers at once, so the order on a real Mac is not visible here: see Further Notes. | R8 scenario "Turning it back on by tap" |
| T18 | R9 | World | Given a thumbless world with access. When a thumb rests at (10, 10) and two fingers tap. Then Figma fires once, and the right click offered 180 ms later is dropped, press and release. A fresh world that differs only in Hold thumb being on gives the same. | R9's scenario; `LiftWindowTests.aRightClickAfterATwoFingerTapOrAShortTouchIsBlockedToo` |
| T19 | R9, R10 | Recognizer | Given two fresh recognizers that differ only in thumbless taps, on and off. When each is stepped through the same touch, for each touch of this list, in which a contact lands in the anchor corner before the trackpad next empties: a thumb, then a tap of N for N in 1...6; a firm-pressed tap under the thumb; a tap dragged 3.5 mm; a tap held 410 ms; a swipe (two fingers slide 3.5 mm, then 12 mm, and lift); a window swipe answered yes, and one answered no; two fingers resting, then two thumb taps, then a third finger; two fingers resting, a thumb held 500 ms, the fingers lifting, then a tap of 2; the thumb and a finger landing on one frame; the thumb lifting on the frame of the last finger; a thumb rolling out of the corner under a finger; an anchored thumb lifting on the frame a finger lands, that finger lifting 100 ms later; an anchored thumb rolling out of the corner on the frame a finger lands, both lifting 100 ms later. Then the two return equal `Recognition` values on every frame. The swap rows run with swaps on and with swaps off. | R9: "the same gesture, click blocking, tap action blocking and Dock swipe blocking as while the setting is on"; R10: "each still starts only as it does today"; for the last two touches also R4 "The first finger lands while no other contact is on that trackpad" |
| T20 | R10 | World | (a) Given `World.switcherWorld(accessGranted: true)` with Notes on gesture 2 and Hold thumb off. Two fingers land with no thumb and slide sideways 3.5 mm, then 12 mm: `switcher == nil`, `scroll(.fingers(.began)) == .pass`, and nothing fires; the script continues with the lift, and still nothing fires. (b) In a fresh such world, `swipe(3.5, 12, lift: false)` under the thumb: `switcher != nil`; the script continues with the lift, which brings Mail forward with pulses `[.lightTick, .gesture]`. (c) Given `World.windowWorld(visible: ["Docs", "Mail", "News"])` with Mail on gesture 2 and Hold thumb off. Two fingers slide down 3.5 mm, then 12 mm, with no thumb: `windowSwitcher == nil` and nothing fires. In a fresh such world, the same slide under the thumb: `windowSwitcher != nil`. (d) Given (a)'s world, fresh. Two fingers rest 500 ms with no thumb and lift: nothing fires. | R10's two scenarios; `SwapSettingTests.withTheSwapOffAThumbFirstSwipeStillShowsTheSwitcher` (3.5 mm then 12 mm selects Mail; a tick, then the gesture pulse) |
| T21 | R11 | World | Given the five apps on gestures 1 to 5, Hold thumb on. (a) A tap of 1: nothing fires. The intent turns it off; a tap of 1 fires Arc. The intent turns it on; a tap of 1 leaves `broughtToFront == [Arc]`. All on one `Launcher`. (b) One script, played in two pieces: a finger lands and stays 50 ms; the intent turns Hold thumb off while it is down; the script continues, the finger staying 30 ms more and lifting. Nothing fires. A tap of 1 after it fires Arc. | R11 "take effect from the next tap, with no relaunch"; scenario "Turning it off" |
| T22 | R11 | World | Given a thumbless world. Then, right after the intent returned, `freshStore().load()?.isHoldThumbOn == false`. When `relaunch()` and `start()` only, as a login start. Then `isHoldThumbOn` is false and a tap of 1 fires Arc; after `openedByHand()` it is still false. | R11 scenarios "Survives a force-quit" (a new process reads the choice at once) and "Survives a restart" |
| T23 | R12 | World | (a) Given the frozen released record `PersistenceTests.savedSettings` seeded, with its three apps registered. When relaunched and started. Then `isHoldThumbOn` is true, the launch animation is off, and the rows are Arc, Figma, unassigned, unassigned, Spotify. (b) Given a record written by the frozen `PersistenceTests.Build1018Settings` with the launch animation off and an app on every gesture. When relaunched and started. Then `isHoldThumbOn` is true, the launch animation is off, all five rows show their apps, a tap of 1 fires nothing, and the same tap under the thumb fires Arc. | R12 scenario "Upgrade"; the fixture's own doc (launch animation off, apps on gestures 1, 2 and 5) |
| T24 | R12 | World | Given the five apps on gestures 1 to 5, the launch animation turned off, then Hold thumb turned off. Then the saved record holds `isHoldThumbOn` as false under exactly that key. `Build1018Settings`, the previous version's frozen decoder, decodes the same bytes, with all five assignments by bundle identifier and the launch animation off. When `previousVersionSaves` writes the record back unchanged and this version relaunches. Then all five rows show their apps and `isHoldThumbOn` is true. | R12 scenario "Downgrade"; the record's decoding rule in `Settings` (a key a build does not know is ignored; a missing key reads as the default) |
| T25 | R11, R12 | World | (a) A record that holds only `isHoldThumbOn` as false loads equal to `Settings()` with that one field off. (b) `PersistenceTests.everySettingsFieldSurvivesTheStore` sets the field to false with the others and loads back an equal value. | The record's decoding rule; R12 "change no other setting"; R11 "saved" |

### Verified without a test

- **R1, the switch's place.** No test hosts the settings form, and a SwiftUI grouped form shows its row order to no unit test without a new seam for hosting views. The sibling switches' places are verified the same way. The checks:
  - a read of the settings view's first form section: its rows are, in order, the gesture rows, the *Animate app launch* switch and the *Hold thumb* switch, and nothing follows in that section; the new switch reads `launcher.isHoldThumbOn` and sends the Hold thumb intent;
  - **M1**, by hand: `make run`. The settings window opens. Its first group of rows shows the five gesture rows, then *Animate app launch*, then *Hold thumb*, and nothing below it in that group. The *Quit Trackpad Launcher* and *Close* buttons are fully inside the window.
- **R13, no ongoing cost.** R13 says it is judged by reviewing the implementation: the absence of a listener, a tap or a timer is a property of the source, and no run can show it. The checks:
  - `git diff --merge-base main --stat -- LauncherKit/Sources TrackpadLauncher` lists these six files and no other: `GestureRecognizer.swift`, `Launcher.swift`, `Ports.swift` and `Settings.swift` in `LauncherCore`, `MultitouchTrackpads.swift` in `LauncherPlatform`, and `SettingsView.swift` in `LauncherUI`. Any other file is a finding to explain in the development log. (`--merge-base` compares the working tree with the commit the branch left main at, so it shows uncommitted work and nothing main gained since.)
  - the diff of `MultitouchTrackpads.swift` only replaces the slide kinds and the swap flag by the options value, in `run`'s signature and in the recognizer it builds;
  - `git diff --merge-base main -- LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` prints nothing and the suite is green. It bans timers, polling and display links in every shipped file, and confines the event taps and the event monitors to the one file each already has;
  - `git diff --merge-base main -- LauncherKit/Sources TrackpadLauncher | grep -nE "^\+.*(Mutex|DispatchQueue|Task \{|Task\.|addObserver|observe\(|publisher\(for|notifications\(named|onReceive|Uptime|\.now|ask\()"` prints nothing: no new shared state, hop, task, observer, clock read or permission ask;
  - a read of the recognizer's diff: the candidate is made only with the option on, lives inside the rest, and the lines that compute the blocking level, the thumb touch and the lift window are unchanged.

## Further Notes

- **R4's "Thumb and fingers land together", read at the frame (resolved).** Today's thumb rules decide every order of a thumb and two fingers that land and lift within 400 ms: the thumb landing a frame or more before the fingers and lifting after them fires the 2-finger gesture (T12a); the thumb and the fingers landing on one frame, or all lifting on one frame, fire nothing (T12b, T12c); the fingers landing first and the thumb lifting first is a swap while the swap setting is on, and otherwise nothing (T14). In every order the 3-finger gesture never fires. The requirements now say so: the scenario has the thumb land first, and "Thumb and fingers land on the same frame" says no gesture fires.
- **Things only a real trackpad shows.** None is a requirement's proof; they are worth one pass with the Debug build before a release, with Hold thumb off and an app on the 1-finger gesture.
  - *Every tap fires.* With Tap to click on, tap one finger 50 times: the app comes forward every time. The plan removes the one race that could drop a tap, the tap's own click showing on its lift frame, by design; this is the check that nothing else drops one.
  - *The tap's own click.* With Tap to click on, macOS clicks 2 to 13 ms after the lift frame (measured for plan 027), where the pointer is. If the pointer is over another app's window, that click can activate that app after the gesture's app was asked forward. R8 leaves the click's receiver open, and blocking the click is a non-goal, so no design here settles which app ends in front.
  - *Turning it back on by tap.* With Tap to click on, open the settings window and tap the *Hold thumb* switch with one finger: the switch turns on and the 1-finger gesture's app comes forward. Then tap one finger anywhere: nothing comes forward.
  - *Dragging, a known limit of R4's "Double tap".* With macOS's Dragging setting on, a second tap soon after a first carries macOS's own button-down while its finger is down (plan 027's log). A frame cannot tell that from a physical press, so the second tap of a double tap fires nothing there. R4's scenario holds with Dragging off, which is macOS's default.
  - *Palms.* The trackpad adapter keeps every contact the driver reports as touching, whatever its size. A palm that brushes the pad outside the edge contact band for under 400 ms, as when typing, meets the thumbless tap definition. The non-goal "Filtering accidental touches" accepts this.
- **The order behind "Turning it back on by tap".** The gesture fires on the lift frame and macOS's click follows it, so the gesture's event is queued for the main actor before the click can flip the switch. If the click's handling ever ran first, the reconcile would replace the session and the gesture's event would be dropped: the switch still turns on. T17 pins the order the model sees; the fake delivers at once, so the real order shows only in the pass above.
- **The real adapter's `run`.** No test reaches it. After the prefactor it hands one value to each recognizer and reads none of its fields, so there is no option it can drop or transpose; the quick gate compiles it, and R13's second check reads its diff.
- **The illustrations and the guide** keep showing the thumb while Hold thumb is off: a non-goal, left for a follow-up.
- **Docs.** `docs/domain-model.md` gains *Thumbless tap* and *Hold thumb setting*, and its *Gesture*, *Tap*, *Thumb touch*, *Tap action*, *Tap-bound setting*, *Click blocking* and *Settings window* entries are updated. `docs/architecture.md` is unchanged: no decision it holds changes.

## Slices

Two slices. S1 is the prefactor: it changes nothing a user can see, and the existing suite proves it. S2 is the whole feature, one path through the record, the model, the recognizer, the window and the tests. The recognizer's part of S2 is one small block whose rules are judged together, so splitting S2 further would separate rules from their tests.

### S1: One value carries a run's recognizer options

**What to build:** nothing a user can see changes. `RecognizerOptions` holds the slide kinds and whether swaps are recognised. The model's run record holds it, `TrackpadHardware.run` takes it in place of the two parameters, and `GestureRecognizer`'s initializer takes it whole. Both adapters hand it on unread: the real one and `InMemoryTrackpads`. The doc comments of the port's `run` and of the recognizer's initializer describe the options once, on the value. In the tests, one convenience builds a recognizer from spelled-out options, so the recognizer suites keep their bodies.

**Blocked by:** None (can start immediately).

**Requirements:** None on its own. It makes S2's recognizer option one field, and it removes the one place where two recognizer flags could be transposed unseen.

**Test scenarios:** None.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`

- [ ] The quick gate is green. No test body changes beyond how a recognizer is built or how the fake's `run` is spelled. The suites this can break are every one that builds a recognizer or runs the fake: `GestureRecognizerTests`, `SwapRecognizerTests`, `SwipeRecognizerTests`, `WindowSwipeRecognizerTests`, `WindowSwipeAnswerTests`, `EdgeContactRecognizerTests`, `BlockingLevelRecognizerTests`, `ClickBlockingRecognizerTests`, `DockSwipeBlockingRecognizerTests`, `AveragedTravelTests`, `SnapTravelTests`, `RecordedSwipeTravelTests`, the two `DeviceSession` suites in `LauncherPlatformTests`, and every `World` suite.
- [ ] `grep -nE "slides:|swaps:" LauncherKit/Sources/LauncherCore/Ports.swift LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` finds nothing: neither the port nor the real adapter names an option.
- [ ] `RecognizerOptions` is `Hashable` and `Sendable`, and its initializer has no default arguments.

### S2: The Hold thumb switch, and thumbless taps while it is off

**What to build:** the settings window's first group ends with a *Hold thumb* switch, on by default. While it is on, everything is as today. While it is off, a short, clean tap of one to five fingers on an otherwise empty trackpad fires that finger count's gesture exactly as a tap under the thumb does, and blocks nothing; taps under the thumb, the swipe, the window swipe and the swap are unchanged. A flip applies to the next tap, is saved at once, and survives a relaunch, an upgrade and a downgrade. The pieces:
- the record's `isHoldThumbOn` field and its decoding;
- the model's read and intent, and the option's derivation in the reconcile;
- `RecognizerOptions.thumblessTaps`, and the tap candidate in the recognizer's rest, as Implementation Decisions gives its clean start, its four rules while a finger is down and its lift frame;
- the switch in the settings form's first section;
- the doc comments this makes stale: the recognizer's and the fired event's, which say a tap needs the thumb, and the settings view's, which lists the first section's rows;
- the test-side handles named under Strategy.

**Blocked by:** S1.

**Requirements:** R1 to R13.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22, T23, T24, T25.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-data`, `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:swift-concurrency`

- [ ] T1 to T25 are green, each written before the code that turns it green.
- [ ] The quick gate is green, and no existing test changes except `PersistenceTests.everySettingsFieldSurvivesTheStore` (T25). The existing rows this can break are the ones that tap or rest with no thumb while Hold thumb is on, and the swap rows, which share the rest: `TapActionBlockingTests.aThreeFingerTapWithNoThumbStillLooksUp` and `aDoubleTapOfTwoWithNoThumbStillZooms`, `GestureRecognizerTests.onlyTheTapMadeWhileTheThumbIsAnchoredFires`, `SwapRecognizerTests`, `SwapTests`, `SwapSettingTests` and `EdgeContactRecognizerTests`.
- [ ] R1: the read under "R1, the switch's place" passes, and M1 passes by hand.
- [ ] R13: the five checks under "R13, no ongoing cost" pass.
- [ ] The entries of `docs/domain-model.md` the plan updated match what was built: *Thumbless tap*, *Hold thumb setting*, *Gesture*, *Tap*, *Thumb touch*, *Tap action*, *Tap-bound setting*, *Click blocking* and *Settings window*. Where the build departs from an entry, the entry is corrected.
