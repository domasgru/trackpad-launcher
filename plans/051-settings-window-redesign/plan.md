# Plan: Settings window redesign

The design is beside this plan: `Utility Panel.png` (the mockup) and `Utility Panel.json` (its Figma structure). Where the mockup and these requirements differ, the requirements win. Other details of the mockup that differ from today's window are not part of this change, for example the window title "Trackpad App".

## Problem statement

The settings window has three problems:

- **Layout.** The window does not match the new design. Its rows are 46 pt tall and its parts sit 20 pt apart. The design's rows are 48 pt tall, with tighter spacing.
- **First gesture.** A small handwritten guide with arrows is all that explains the first gesture. A first-time user still has to work out what "hold" and "tap" mean on a trackpad.
- **Pictures.** The gesture pictures have been redrawn in the design. The window still shows the old ones. The pictures also always show the thumb. With *Hold thumb* off, a tap with no thumb fires a gesture, so a picture with a thumb in the corner shows a gesture the user no longer has to make.

## Solution

The settings window follows the new design:

- Every one-line row is 48 pt tall, and the window's parts sit closer together.
- The first gesture row shows a large picture of a MacBook keyboard and trackpad.
- When the thumb is held in the top-left corner, two hands over that picture show where to hold and where to tap, with a *Hold* label and a *Tap* label.
- Every picture uses the new drawing, in a version for each thumb corner.
- While *Hold thumb* is off, the five gesture pictures show no thumb.

## Requirements

"The corner drawn" is the domain model's term: the External trackpad corner while the Mac has mixed trackpads and an external trackpad is connected, otherwise the MacBook trackpad corner.

### R1. One-line rows are 48 pt tall

These rows of the settings form MUST each be 48 pt tall, with their content centred vertically:

- the 2- to 5-finger gesture rows that hold one app or none
- the *Animate app launch*, *Hold thumb*, *Switch recent*, *Toggle recent* and *Hide background apps* switch rows
- the *Switch windows* row while the screen recording hint is hidden
- the single *Thumb corner* row

The *Switch windows* row with the screen recording hint keeps today's layout inside the row. So does the two-trackpad *Thumb corner* block (title plus two indented lines). Each of them is taller than 48 pt.

#### Scenario: Switch rows
- **WHEN** the user opens the settings window
- **THEN** the *Animate app launch*, *Hold thumb*, *Switch recent*, *Switch windows*, *Toggle recent* and *Hide background apps* rows are each 48 pt tall, and each title is centred vertically

#### Scenario: Gesture rows 2 to 5
- **GIVEN** the 2-finger gesture holds one app and the 4-finger gesture holds none
- **WHEN** the user opens the settings window
- **THEN** the 2-finger and the 4-finger rows are each 48 pt tall

#### Scenario: One thumb corner row
- **GIVEN** the Mac has never had mixed trackpads
- **WHEN** the user opens the settings window
- **THEN** the *Thumb corner* row is 48 pt tall

#### Scenario: The screen recording hint still grows its row
- **GIVEN** the window swipe is on and Screen Recording is not allowed, so the screen recording hint shows
- **WHEN** the user opens the settings window
- **THEN** the *Switch windows* row holds the hint and its button and is taller than 48 pt

#### Scenario: Two thumb corner lines
- **GIVEN** the Mac has mixed trackpads
- **WHEN** the user opens the settings window
- **THEN** the thumb corner group shows "Thumb corner:" with the indented *MacBook trackpad* and *External trackpad* lines, laid out as today

### R2. Two-line gesture rows are 86 pt tall

A gesture row that holds a second app MUST be 86 pt tall. Its two lines take 56 pt, with 15 pt above and 15 pt below. This applies to the first gesture row too.

#### Scenario: A split gesture
- **GIVEN** the 3-finger gesture holds Notes and a second app, Mail
- **WHEN** the user opens the settings window
- **THEN** the 3-finger row is 86 pt tall
- **AND WHEN** the user removes the second app
- **THEN** the row returns to 48 pt, and the window shrinks to fit

### R3. The window's parts sit at the design's spacing

The column's parts MUST be spaced as follows:

| Between | Gap |
| --- | --- |
| The update card and the Accessibility hint card, while both show | 10 pt |
| The last of those cards and the gesture group | 16 pt |
| The form's groups | 10 pt |
| The last group or the no trackpad notice, and the *Quit Trackpad Launcher* and *Close* buttons | 20 pt |

The window's 16 pt inset from its edges does not change.

#### Scenario: Accessibility hint above the gestures
- **GIVEN** the Accessibility permission is missing and no update has been found
- **WHEN** the user opens the settings window
- **THEN** the gesture group starts 16 pt below the Accessibility hint card

#### Scenario: Update card alone
- **GIVEN** an update has been found and the Accessibility permission is granted
- **WHEN** the user opens the settings window
- **THEN** the gesture group starts 16 pt below the update card

#### Scenario: Both cards
- **GIVEN** an update has been found and the Accessibility permission is missing
- **WHEN** the user opens the settings window
- **THEN** the Accessibility hint card starts 10 pt below the update card, and the gesture group starts 16 pt below the hint card

#### Scenario: Groups of the form and the buttons
- **WHEN** the user opens the settings window
- **THEN** the gesture group, the switcher group and the thumb corner group are each 10 pt apart, and the buttons start 20 pt below the thumb corner group

#### Scenario: No trackpad notice
- **GIVEN** no trackpad is connected
- **WHEN** the user opens the settings window
- **THEN** the buttons start 20 pt below the no trackpad notice

### R4. The first gesture row shows the large keyboard and trackpad picture

The 1-finger row MUST be 70 pt tall with one app or none. With a second app it MUST be 86 pt tall. It MUST show the large picture of a MacBook keyboard and trackpad, 137 pt wide at the picture's own aspect ratio.

The picture's position MUST be fixed to the group's leading edge and the row's top edge: its top-left corner sits 1 pt above the row's top and 12 pt left of the group's leading edge. The picture keeps that place when the row grows to 86 pt, and the space below it stays empty. The group's rounded corner MUST clip the picture. The picture MUST NOT draw into the 2-finger row.

The app picker or pickers MUST stay at the trailing edge, centred vertically in the row.

#### Scenario: One app
- **GIVEN** the 1-finger gesture holds Notes
- **WHEN** the user opens the settings window
- **THEN** the 1-finger row is 70 pt tall, and the picture fills its leading part, clipped by the group's top-left corner
- **AND** Notes's picker sits at the trailing edge

#### Scenario: No app
- **GIVEN** the 1-finger gesture holds no app
- **WHEN** the user opens the settings window
- **THEN** the row looks the same, with *Choose app…* in place of the app

#### Scenario: Second app
- **GIVEN** the 1-finger gesture holds Notes
- **WHEN** the user adds Mail as its second app
- **THEN** the row grows to 86 pt, and the picture stays at the row's top
- **AND WHEN** the user removes Mail
- **THEN** the row returns to 70 pt

### R5. Hands and labels show how to make the first gesture

While *Hold thumb* is on and the corner drawn is *Top left*, the first gesture row MUST show two hands and two labels over the picture. In every other state it MUST show neither.

Each element sits at a fixed offset from the gesture group's top-leading corner, which is also the first row's top-leading corner. These are the mockup's positions, measured from the top-left of the window content, minus the group's own position there of (16, 108):

| Element | Size | Offset from the group's top-leading corner |
| --- | --- | --- |
| Left hand | 52.48 pt wide | (−11.5, 10.5) |
| Right hand | 60 pt wide | (55, 24) |
| *Hold* label, with a filled dot | 18 pt tall, as wide as its content | (−11, 49) |
| *Tap* label, with a ringed dot | 18 pt tall, as wide as its content | (92, 55) |

The hands MUST draw at 90% opacity. The labels MUST draw over the hands, as small light tooltips with a soft shadow, as in the mockup. The hands and labels MAY reach past the row and the group's edges, and nothing MUST clip them. They MUST take no clicks.

The handwritten *Hold* / *Tap* guide with arrows MUST NOT show in any state.

#### Scenario: Default settings
- **GIVEN** *Hold thumb* is on and the corner drawn is *Top left*
- **WHEN** the user opens the settings window
- **THEN** the left hand rests on the trackpad's top-left corner with the *Hold* label below it, and the right hand taps the trackpad's centre with the *Tap* label below it
- **AND** no handwritten guide shows

#### Scenario: Another corner
- **GIVEN** *Hold thumb* is on and the corner drawn is *Top left*
- **WHEN** the user picks *Bottom left* as the thumb corner
- **THEN** the hands and labels disappear at once, and the picture shows the thumb in the bottom-left corner

#### Scenario: Mixed trackpads with the external one connected
- **GIVEN** the Mac has mixed trackpads, *MacBook trackpad* is *Top left*, *External trackpad* is *Bottom left*, and an external trackpad is connected
- **WHEN** the user opens the settings window
- **THEN** no hands or labels show
- **AND WHEN** the external trackpad disconnects
- **THEN** the hands and labels appear

#### Scenario: Hold thumb off
- **GIVEN** the corner drawn is *Top left*
- **WHEN** the user turns *Hold thumb* off
- **THEN** the hands and labels disappear at once, and the picture shows no thumb
- **AND WHEN** the user turns it back on
- **THEN** the hands and labels return

#### Scenario: No cards above the gestures
- **GIVEN** the Accessibility permission is granted and no update has been found
- **WHEN** the user opens the settings window
- **THEN** the hands and labels sit at the same offsets from the gesture group as they do when the hint card shows

#### Scenario: Second app
- **GIVEN** the hands and labels show
- **WHEN** the 1-finger gesture gains a second app
- **THEN** the hands and labels keep their offsets from the group's top

#### Scenario: Controls under the hands still work
- **GIVEN** the hands and labels show
- **WHEN** the user clicks the 1-finger and the 2-finger pickers
- **THEN** each picker's menu opens

### R6. Every corner's picture uses the new drawing

Each gesture, swipe, window swipe and thumb tap picture MUST come in four versions, one for each thumb corner. Each version MUST show the new drawing.

For the 2- to 5-finger, swipe, window swipe and thumb tap pictures, each version MUST show the top-left version's card unchanged, with its light and shading as drawn. The marks are moved to the corner:

| Corner | Marks |
| --- | --- |
| Top right | mirrored left to right |
| Bottom left | mirrored top to bottom |
| Bottom right | mirrored both ways |

The 1-finger gesture's four versions are the ones drawn in the design. Every picture except the first gesture's stays 45 × 28 pt. It shows at least two pixels per point, so it stays as sharp as today on a Retina display.

#### Scenario: Top right corner
- **GIVEN** *Hold thumb* is on and the corner drawn is *Top right*
- **WHEN** the user opens the settings window
- **THEN** every gesture, swipe, window swipe and thumb tap picture shows its thumb in the top-right corner, in the new drawing, on a card lit as in the top-left version

### R7. With *Hold thumb* off, gesture pictures show no thumb

While *Hold thumb* is off, each of the five gesture rows MUST show its gesture's picture without a thumb: the top-left version's tapping fingers, in the same place on the same card. This picture is the same for every thumb corner. So at a corner other than *Top left*, turning *Hold thumb* off moves the fingers to their top-left places. This is intended.

The swipe, window swipe and thumb tap pictures MUST keep showing the thumb in the corner drawn, because those actions still need it.

#### Scenario: Opening with Hold thumb off
- **GIVEN** *Hold thumb* is off and the corner drawn is *Top left*
- **WHEN** the user opens the settings window
- **THEN** the five gesture pictures show the fingers without a thumb, and no hands or labels show

#### Scenario: Turning Hold thumb off
- **GIVEN** the corner drawn is *Top right*
- **WHEN** the user turns *Hold thumb* off
- **THEN** the five gesture pictures change at once to the fingers without a thumb
- **AND** the *Switch recent*, *Switch windows* and *Toggle recent* pictures still show the thumb in the top-right corner

#### Scenario: Turning Hold thumb back on
- **GIVEN** *Hold thumb* is off and the corner drawn is *Bottom right*
- **WHEN** the user turns *Hold thumb* on
- **THEN** the five gesture pictures show the thumb in the bottom-right corner again

#### Scenario: Corner change while Hold thumb is off
- **GIVEN** *Hold thumb* is off
- **WHEN** the user changes the thumb corner
- **THEN** the gesture pictures stay the same, and the *Switch recent*, *Switch windows* and *Toggle recent* pictures move their thumb to the new corner

## Non-goals

- **The *Filter launch apps* switch** under *Switch recent* in the mockup. It is new behaviour: today the switcher always leaves out the apps a gesture holds alone. It gets a feature of its own later.
- **A dark appearance.** The app is light only today, and stays so. The hands, labels and pictures have one look.
- **Hands and labels for the other three corners.** The design draws them only for *Top left*.
- **No-thumb pictures for the swipe, window swipe and thumb tap.** Those actions need the thumb whatever the setting.
- **A no-thumb picture for each corner.** Without the thumb, the corner has nothing to show.
- **Changes to copy, controls or behaviour** beyond the above. The pickers, switches, hints, cards and buttons keep their wording and what they do.
