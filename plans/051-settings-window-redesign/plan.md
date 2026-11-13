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

While the corner drawn is *Top left*, the first gesture row MUST show the right hand and the *Tap* label over the picture. While *Hold thumb* is also on, it MUST show the left hand and the *Hold* label too. While *Hold thumb* is off, it MUST NOT show the left hand or the *Hold* label. At any other corner it MUST show no hand and no label. (Changed at the user's request after implementation: *Hold thumb* off used to hide both hands.)

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
- **THEN** the left hand and the *Hold* label disappear at once, the right hand and the *Tap* label stay, and the picture shows no thumb
- **AND WHEN** the user turns it back on
- **THEN** the left hand and the *Hold* label return

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

### R8. A tall window scrolls

The settings window MUST be at most 90% as tall as the visible area of the display it is on: the display minus the menu bar and the Dock. When its content is taller, the window MUST stay at that height, and the content MUST scroll vertically inside it, with the system's own scroller. When the content fits, the window MUST stay as tall as its content, and nothing scrolls. The limit MUST hold every time the window resizes to fit: when a card, a hint or the notice appears or disappears, when a gesture row gains or loses its second line, when the thumb corner row becomes two, and when the window moves to another display. The hands and labels from R5 scroll with the first gesture row.

#### Scenario: Short display
- **GIVEN** a display whose visible area is 800 pt tall, and window content 1,000 pt tall
- **WHEN** the user opens the settings window
- **THEN** the window is 720 pt tall, and scrolling reaches the *Quit Trackpad Launcher* and *Close* buttons at the bottom

#### Scenario: Content fits
- **GIVEN** a display whose visible area is 1,200 pt tall
- **WHEN** the user opens the settings window
- **THEN** the window is as tall as its content and shows no scroller

#### Scenario: Content grows past the limit
- **GIVEN** the window is just under 90% of the visible area
- **WHEN** the update card appears
- **THEN** the window grows to 90% of the visible area and no further, and its content scrolls

## Non-goals

- **The *Filter launch apps* switch** under *Switch recent* in the mockup. It is new behaviour: today the switcher always leaves out the apps a gesture holds alone. It gets a feature of its own later.
- **A dark appearance.** The app is light only today, and stays so. The hands, labels and pictures have one look.
- **Hands and labels for the other three corners.** The design draws them only for *Top left*.
- **No-thumb pictures for the swipe, window swipe and thumb tap.** Those actions need the thumb whatever the setting.
- **A no-thumb picture for each corner.** Without the thumb, the corner has nothing to show.
- **Changes to copy, controls or behaviour** beyond the above. The pickers, switches, hints, cards and buttons keep their wording and what they do.

## Implementation Decisions

### What the pictures draw

- **The launcher model decides, through two new reads beside the corner drawn.**
  - `gestureThumbCorner`: the corner the five gesture pictures draw the thumb in. It is the corner drawn while Hold thumb is on, and no corner while it is off.
  - `showsHandGuide`: true exactly while `gestureThumbCorner` is *Top left*.

  Both are worked out on each read from the saved settings and the connected trackpads, as the corner drawn is. Nothing new is stored, saved or reconciled. So both follow the Hold thumb switch, a corner pick, and a trackpad connecting or disconnecting, at once (R5, R7).
- **The swipe, window swipe and thumb tap pictures keep reading the corner drawn**, whatever Hold thumb is (R7).
- **One rule in the UI names a picture's file.** It takes the picture's base name and the thumb to draw: a corner, or none. *Top left* gives the base name. The other corners keep today's suffixes: `-inverse` for top right, `-bottom` for bottom left, `-bottom-inverse` for bottom right. No thumb gives `-no-thumb`. It replaces today's corner-to-suffix rule. The gesture rows pass the model's `gestureThumbCorner`. The switcher rows pass the corner drawn, so they can never ask for a no-thumb file (R6, R7).
- The rule that showed the handwritten guide for *Top left* is removed. The model's `showsHandGuide` takes its place.

### The picture files

- **Three kinds of file are drawn by hand, and the script never writes them:**
  - the top-left version of the seven small pictures: gestures 2 to 5, swipe, window swipe, thumb tap
  - the first gesture's five versions: four corners and no thumb
  - the two hands
- **The corner illustration script derives the rest:** the three other corners of each small picture, and the no-thumb version of gestures 2 to 5. That is 25 files. The script no longer lists the first gesture.
- **The script measures in points.** Its rim width and its mark edge are pixel counts tuned for 2× art. They become points, multiplied by the file's pixels per point, which the script reads from the file's resolution (4 for the new art).
- **Its values are set again for the new drawing.** Measured on the committed top-left files:
  - the card's shaded rim is 5 px wide (1.25 pt)
  - the marks come within 10 px (2.5 pt) of the card's top and bottom edges
  - the card's face is never darker than 213 of 255
  - the inside of a ring is about 170 to 200

  So the rim is at least 1.5 pt and less than 2.5 pt, and the mark threshold lies between a ring's inside and the card's face. At 1.25 pt the card's rounded corners leave pixels as dark as 203 inside the rim, which a threshold in that band would take for marks nearer the corner than the thumb. From 1.5 pt on none is left.
- **A mark is carried as a darkening of the card**, as today. The share of the card's light that a mark pixel takes is moved to its mirrored place on the filled-in card. The new marks are dark grey with a translucent ring, not pure black. The same rule carries them.
- **The thumb is the mark nearest the top-left corner:** the connected part of the mark mask closest to that corner. In all seven small pictures it is a part of its own, apart from the fingers (checked on the committed files). The no-thumb version is the top-left file with that part replaced by the filled-in card. Every other pixel stays the original's.
- **The card fill runs until it settles**, not for a fixed number of passes. At 4× a mark covers four times the pixels, and the fixed count was tuned for 2×.
- **The derived files are committed** at the originals' pixel size and resolution. Running the script on a clean tree changes no file.
- The handwritten guide's SVG is deleted from the assets, so the bundle no longer carries it (R5).

### The large pictures' size

- **A picture can be sized by its width alone**, at the file's own aspect ratio: 137 pt for the first gesture's picture (R4), 52.48 pt and 60 pt for the hands (R5). The small pictures keep their fixed 45 × 28 pt.
- **The large files are stored at 4 pixels per point of the width they show at**, as the small pictures are: 548 px wide for the first gesture's five files, 210 px and 240 px for the hands, at 288 dpi.
  - The committed exports are 1270, 978 and 1118 px wide: 9 to 19 pixels per point.
  - Kept so, they would hold about 11 MB of decoded pixels for as long as the app runs. The settings view is built once and kept, and the image loader never drops what it loaded. They would also add 3.8 MB to the bundle.
  - At 4 pixels per point they take under 1 MB decoded and about 0.6 MB in the bundle. The product overview asks for the least resources possible.
- **S1 resizes the seven committed exports once**, with the system's `sips`, and commits the result (the command is under Further Notes). No code reduces a picture at run time, and the script still never writes these files. This changes files the user exported: see Further Notes.

### The column's spacing (R3)

- The column's one 20 pt spacing becomes the design's gaps:
  - The update card and the Accessibility hint card form one block, 10 pt apart.
  - That block sits 16 pt above the form.
  - The no trackpad notice sits 10 pt below the form. R3 does not name this gap (see Further Notes).
  - The buttons carry a 20 pt gap above them, whatever is above: the form or the notice. No condition picks it.
- A block that shows nothing takes no room and adds no gap. With no card, the gesture group starts at the window's 16 pt inset.
- The 10 pt between the form's groups is the grouped form's own spacing. No public API sets it on macOS. The probe measured it at 10 pt (see Further Notes). The form stays one form.
- The form stays under its neighbours in drawing order, as today, so the margins it lays over them never take their clicks.
- The 16 pt inset does not change. The window widens from 326 pt to the mockup's 358 pt, so the groups are 326 pt wide, as in the mockup (the user's decision). The update card's and the Accessibility hint card's pictures, clipped at the card's trailing side, get a second look at the new width.

### Row heights (R1, R2, R4)

- **A row states its full height, and one helper takes off the form's own padding.** The grouped form pads every row by 10 pt above and below. Today that number lives in comments, and each row sets a content height (26 or 56 pt) that adds up to the row. It becomes one named, measured constant beside the form's margins. A row then asks for 48, 70 or 86 pt.
- One-line rows ask for 48 pt: gesture rows 2 to 5 with one app or none, the six switch rows (the *Switch windows* row while its hint is hidden), and the single *Thumb corner* row.
- Two-line gesture rows ask for 86 pt. The two lines keep today's layout: 56 pt, their centres 32 pt apart. So 15 pt stands above and below them.
- The first gesture row asks for 70 pt with one line and 86 pt with two.
- The *Switch windows* row with the screen recording hint keeps its stack: the switch line, now 48 pt, then the hint. The two-trackpad *Thumb corner* block keeps its own paddings.
- The form draws its 1 pt separator between rows, outside the rows' heights, as today.
- The shell's refit already follows the number of two-line rows, the hints, the card and the notice. Nothing new feeds it.

### The first gesture's art (R4, R5)

- **One view draws everything the first gesture shows at its leading side:** the large picture, the hands and the labels. It is an overlay on the form, not content of the first row. Its origin is the gesture group's top-leading corner: the form's top edge, at the column's inset. So every position in R4 and R5 is written as the requirement gives it, as an offset from that corner. None depends on the form's row padding.
- **Why an overlay.** The grouped form clips a row's content to its group (probe, Further Notes). The hands and labels reach past the group, so they cannot be row content. An overlay also stays where it is when the first row grows from 70 to 86 pt.
- **The picture** sits at (−12, −1), 137 pt wide. It shows the file the picture rule names for the first gesture and the model's `gestureThumbCorner`. It is clipped to a shape of our own: the group's width, the first row's 70 pt, and the group's 12 pt radius at the top-leading corner. So the group's corner and edges cut it, and it can never draw into the 2-finger row.
- **The hand guide** shows its tapping hand and *Tap* label while the model's `showsTapHand` is true, and its holding hand and *Hold* label while `showsHoldHand` is true (only ever with the first). It is not clipped.
  - The left hand sits at (−11.5, 10.5), 52.48 pt wide. The right hand sits at (55, 24), 60 pt wide. Both draw at 90% opacity.
  - The *Hold* label sits at (−11, 49) and the *Tap* label at (92, 55), over the hands.
- **A label** is 18 pt tall and as wide as its content: a dot, 4 pt, then the word. Its padding is 6 pt left and right, 3 pt above and 2 pt below.
  - *Hold* has a filled black dot, 7.17 pt across. *Tap* has a ringed dot, 10.67 pt across.
  - The fill is the design's light Ultra Thick material.
  - It has two shadows, from the JSON: black at 20% with blur 8, 2 pt down; black at 40% with blur 2.
  - The JSON does not carry the corner radius or the text's size and weight. They are matched by eye to the mockup.
- The whole overlay takes no clicks, so the pickers under it work (probe, Further Notes).
- The hand guide appears and disappears with no animation.
- The first row itself holds only its pickers, at the trailing edge, centred vertically. It keeps the accessibility label "1-finger gesture". The hand guide carries, for VoiceOver, the sentence the handwritten guide carried.
- **The handwritten guide is removed:** its view, its rule, its test and its SVG.
- Gesture rows 2 to 5 keep their 45 × 28 pt picture at the leading edge, centred vertically.

### A tall window scrolls (R8)

- **The cap is one pure rule in the UI**, beside the window: given the content's fitting height, the window's title bar height and the visible height of the display, it returns the content height to set: the fitting height, or 90% of the visible height less the title bar, whichever is smaller. R8 measures the whole window, title bar included, against the visible area (`NSScreen.visibleFrame`, which leaves out the menu bar and the Dock).
- **The window hosts the settings view in an `NSScrollView`**: the hosting view is its document view, pinned to the top, with the system's vertical scroller, shown only when the content is taller than the window (`autohidesScrollers`), and no horizontal scroller. The document view keeps the content's own size, so the column's 358 pt width and every measure of R1 to R4 stand. The window's content size is the column's width and the capped height.
- **The hands and labels scroll with the first row** with no code of their own: the first gesture's overlay is part of the settings view, which is the scroll view's document.
- **Every fit applies the cap**, on the display the window will be on. The shell's one fit already runs on each change of what decides the height (the cards, the hints, the notice, a second line, the two thumb corner rows). On opening it measures against the display under the pointer, where the window is centred. It also runs when the window moves to another display (`windowDidChangeScreen`) and when the displays' arrangement or the Dock changes the visible area (`NSApplication.didChangeScreenParametersNotification`): both are pushes, so the no-polling rule holds.
- A fit keeps the window's top edge where it is, as today. When the content shrinks back under the cap the scroller goes and the window is as tall as its content.

### Docs

- `docs/domain-model.md` is updated with this plan: the settings window's spacing and row heights, the gesture row, the hold thumb setting's effect on the pictures, and two new entries, *Illustration* and *Hand guide*.
- `docs/domain-model.md`'s *Settings window* entry also says the window is at most 90% as tall as its display's visible area and scrolls beyond it (R8).
- `docs/architecture.md` does not change. No core decision moves.
- The doc comments that state 46 pt rows, the 20 pt spacing, @2x pictures and the handwritten guide are brought up to date with the code they describe.

## Testing Decisions

### Strategy

Two existing seams prove what a test can prove, and one pure rule is added for R8.

- **`World`** (`LauncherKit/Tests/LauncherCoreTests/World.swift`): the real `Launcher` and the real settings store, over the in-memory trackpads.
  - A test flips Hold thumb, picks corners, attaches and detaches trackpads, and relaunches. Then it reads `gestureThumbCorner` and `showsHandGuide` beside `drawnThumbCorner`.
  - It observes the decisions: what the gesture pictures draw, and whether the hand guide shows.
  - It misses what the window draws with them.
  - The new tests resemble `LauncherKit/Tests/LauncherCoreTests/CornerChoiceTests.swift` and `HoldThumbSettingTests.swift`.
- **The picture files the rule names** (`LauncherKit/Tests/LauncherUITests/ThumbCornerRuleTests.swift`, the suite `CornerIllustrationFileTests`).
  - A test asks the picture rule for a file name, reads that file from the repository's assets folder, and compares pixels.
  - It observes that every state the model can report has a file, and that the file shows what the requirement says.
  - It misses whether the bundle carries the file, which the project's unchanged resource rule does, and how the window draws it.
  - The mark mask in these tests is the tests' own, apart from the script's. Its measures become points, as the script's do.
  - The existing corner-suffix test goes: the file tests call the rule for every name. The guide-rule test goes with the rule.

- **The height cap rule** (R8): the pure function that caps the window's content height, called with numbers. It observes the cap and when it applies. It misses the scroll view, the scroller and which display the shell measures against, which R8's by-hand check covers. Its tests sit in `LauncherKit/Tests/LauncherUITests/`.

Nothing is faked beyond the `World`'s existing in-memory adapters. The asset files are read for real.

R1 to R4 are not proved by a test. They are measures of the real window: our constants added to the grouped form's own, unexposed metrics, laid out by SwiftUI. No test in this repository renders SwiftUI, and earlier settings window plans measured the window by hand. So R1 to R4 are measured by hand on the running window. A seam that could measure part of it exists in principle: the settings view hosted over a real model. Adding it is a decision for the user, set out under Further Notes.

R5, R6 and R7 each join a rule a test can prove with a look only eyes can judge. The rule allows one proof per requirement. Their test scenarios are the proof of record. The by-eye checks are acceptance criteria of S1, S2 and S3. Their steps are under Further Notes for S1 and S3, and in the criterion itself for S2.

### Test scenarios

"T1's world" is a `World` with the built-in trackpad, started and opened by hand, with default settings: Hold thumb on, thumb corner *Top left*. "The mixed world" is a `World` with the built-in trackpad and a Magic Trackpad attached, started and opened by hand: MacBook trackpad *Top left*, External trackpad *Bottom left*.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R6 | World | Given T1's world. When `setThumbCorner` picks each of the four corners in turn. Then after each pick `gestureThumbCorner` and `drawnThumbCorner` both equal that corner. | R6 "Top right corner", for every corner |
| T2 | R7 | World | Given T1's world at each of the four corners, one case per corner. When `setHoldThumb(on: false)`. Then `gestureThumbCorner` is nil on the next read, and `drawnThumbCorner` is still the corner. When `setHoldThumb(on: true)`. Then `gestureThumbCorner` is the corner again. | R7 "Turning Hold thumb off" and "Turning Hold thumb back on" |
| T3 | R7 | World | (a) Given T1's world with Hold thumb off. When the corner changes from *Top left* to *Bottom right*. Then `gestureThumbCorner` stays nil and `drawnThumbCorner` is *Bottom right*. (b) Given the mixed world with Hold thumb off. When the Magic Trackpad detaches, then attaches again. Then `gestureThumbCorner` stays nil throughout, while `drawnThumbCorner` reads *Bottom left*, then *Top left*, then *Bottom left*. | R7 "Corner change while Hold thumb is off"; the corner drawn's definition |
| T4 | R7 | World | Given T1's world with Hold thumb turned off, which saves. When the process relaunches, starts and is opened by hand. Then `gestureThumbCorner` is nil. | R7 "Opening with Hold thumb off" |
| T5 | R6 | Picture files | For each of the seven small pictures and each of *Top right*, *Bottom left* and *Bottom right* (21 cases). Given the top-left file and the file the rule names for that corner. Then: (a) both have one pixel size; (b) outside the marks, meaning the top-left file's marks and their mirrored places, every pixel equals the top-left file's within 1 level per channel; (c) the file's mark mask is the top-left file's mask mirrored left to right for *Top right*, top to bottom for *Bottom left*, and both ways for *Bottom right*, with under 2% of the mark pixels differing. | R6's table; the committed top-left file as the fixture |
| T6 | R6 | Picture files | For each of the seven small pictures' top-left file. Then its pixel size is 45k × 28k for one whole number k of at least 2. | R6: 45 × 28 pt, at least two pixels per point |
| T7 | R6, R7 | Picture files | Given the five files the rule names for the first gesture: four corners and no thumb. Then: (a) all five have one pixel size; (b) each corner's file differs from the no-thumb file, in any channel by more than 1, in one patch no wider or taller than a tenth of the picture's width; (c) at the patch's centre the corner's file is dark and the no-thumb file is light; (d) the *Top left* and *Bottom left* patches share a centre x, left of the *Top right* and *Bottom right* patches' x; (e) the *Top left* and *Top right* patches share a centre y, above the *Bottom left* and *Bottom right* patches' y. | R6: four versions, one for each corner. R7: the no-thumb picture is the top-left version without its thumb. The patch bound: the thumb dot is a sixteenth of the picture's width |
| T8 | R7 | Picture files | For each of gestures 2 to 5. Given the top-left file and the file the rule names for no thumb. Then: (a) both have one pixel size; (b) the two differ, in any channel by more than 1, only within 6 pt of the thumb's centre, which lies 7.6 pt from the card's left edge and 7.6 pt from its top edge; (c) the differing pixels include that centre and span at least 6 pt across and 6 pt down; (d) within those 6 pt, no pixel of the no-thumb file is darker than 205 of 255. | R7: the same fingers, in the same place, on the same card, without a thumb. The thumb's place, read from the committed art and not from the script's rule: in all four top-left files its dot is centred 30.5 px from the left and top edges of the 180 px width and is 31 px across, and the nearest finger mark is 38 px from that centre. The card's face is never darker than 213, and no mark is lighter than 200 |
| T9 | R5 | World | Given T1's world. Then `showsHandGuide` is true. When each of the other three corners is picked in turn. Then it is false after each pick. When *Top left* is picked again. Then it is true. | R5 "Default settings" and "Another corner" |
| T10 | R5 | World | Given the mixed world. Then `showsHandGuide` is false. When the Magic Trackpad detaches. Then it is true. When the Magic Trackpad attaches again. Then it is false. | R5 "Mixed trackpads with the external one connected" |
| T11 | R5 | World | (a) Given T1's world. When Hold thumb turns off. Then `showsHandGuide` is false on the next read. When it turns on. Then true. (b) For each of the other three corners, with Hold thumb on and with it off. Then false. (c) Given T1's world with Hold thumb turned off, which saves. When the process relaunches, starts and is opened by hand. Then false. | R5 "Hold thumb off"; R5's rule "in every other state it MUST show neither"; R7 "Opening with Hold thumb off" |
| T12 | R8 | Height cap rule | The rule called with a title bar of 28 pt. (a) Visible height 800, fitting height 1,000 − 28: returns 692, so the window is 720 pt tall. (b) Visible height 1,200, fitting height 900: returns 900. (c) Visible height 1,000, fitting height 860 (just under the cap of 872), then 960: returns 860, then 872. (d) Fitting height exactly at the cap: returns it. | R8 "Short display", "Content fits", "Content grows past the limit" |

### Verified without a test

R1 to R4 are checked by hand on a Debug build, in one sitting at the end of S2; R8 at the end of S4. A test is not the right proof for the reason under Strategy: the measures exist only in the real window.

The method, shared by all four:

- Build and open with `make run`. The Debug build keeps its own settings and permissions, under `com.domasgru.TrackpadLauncherApp.debug`.
- Capture the settings window on a Retina display, where one point is two pixels: ⇧⌘4, Space, then ⌥-click the window.
- Measure in the capture. A row runs from the group's edge or the separator above it to the separator below it or the group's edge. The 1 pt separator is not counted. Every measure must be within half a point of its expected value.
- Then lay the capture beside `Utility Panel.png`. The mockup's groups are 32 pt wider (see Further Notes). Heights, gaps and offsets from a group's leading edge must match within 1 pt, except where the requirements differ from the mockup.

**R1. One-line rows are 48 pt tall.**

1. Open the window with Accessibility allowed and *Switch windows* off. Expected: the *Animate app launch*, *Hold thumb*, *Switch recent*, *Switch windows*, *Toggle recent* and *Hide background apps* rows are each 48 pt tall. Each title and each switch is centred between its row's edges within 1 pt.
2. Give the 2-finger gesture one app and the 4-finger gesture none. Expected: both rows are 48 pt tall, and so are the 3-finger and 5-finger rows with one app.
3. Quit the app. Run `defaults delete com.domasgru.TrackpadLauncherApp.debug externalThumbCorner`, which reports a missing key on a Mac that never had mixed trackpads. With no Magic Trackpad connected, run `make run`. Expected: one *Thumb corner* row, 48 pt tall.
4. Run `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp.debug`, then turn *Switch windows* on. Expected: the row holds the hint and its button under the switch line and is taller than 48 pt. Against a capture of the same state from a build of `main`: the hint and the button sit where they sat, measured from the switch line, and the row is 2 pt taller.
5. Quit the app. Run `defaults write com.domasgru.TrackpadLauncherApp.debug externalThumbCorner -string bottomLeft`, then `make run`. Expected: "Thumb corner:" with the indented *MacBook trackpad* and *External trackpad* lines. Against a capture of the same state from a build of `main`: the block is the same height, and its lines sit where they sat.

**R2. Two-line gesture rows are 86 pt tall.**

1. Give the 3-finger gesture Notes, then Mail as its second app. Expected: the row is 86 pt tall. The two app icons' centres are 32 pt apart, the first 27 pt below the row's top and the second 27 pt above its bottom. That is 15 pt, then two 24 pt lines 8 pt apart, then 15 pt.
2. Remove the second app. Expected: the row is 48 pt tall again, and the window is 38 pt shorter, with no empty band at its bottom.

**R3. The window's parts sit at the design's spacing.**

1. Open the window with Accessibility allowed and no update card. Expected: the gesture group's top edge is 16 pt below the content's top. No card shows, and no gap stands where the cards would be.
2. Run `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp.debug`, then `make run`. Expected: the gesture group's top edge is 16 pt below the Accessibility hint card's bottom edge.
3. Allow Accessibility in System Settings. Quit the app. Run `open "build/dev/Build/Products/Debug/Trackpad Launcher.app" --args -PreviewUpdateCard YES`. Expected: the gesture group's top edge is 16 pt below the update card's bottom edge.
4. Reset Accessibility again, quit, and open with the same argument. Expected: the hint card's top edge is 10 pt below the update card's bottom edge, and the gesture group's top edge is 16 pt below the hint card's bottom edge.
5. In each of these four states. Expected: the gesture group, the switcher group and the thumb corner group are 10 pt apart. The buttons' top edge is 20 pt below the thumb corner group's bottom edge. The first part starts 16 pt below the content's top, the buttons end 16 pt above its bottom, and every part is 16 pt from its sides.
6. The no trackpad notice, which shows only with no trackpad connected. Try these routes in order, and note which one was taken:
   - Close the MacBook's lid with an external display and a mouse connected and no Magic Trackpad. The model counts a closed lid as the built-in trackpad disconnecting, but whether macOS then stops listing the trackpad is not known.
   - Use a Mac with no trackpad connected.
   - Expected on either route: the notice shows, and the buttons' top edge is 20 pt below its bottom edge.
   - If neither route shows the notice, read the diff instead. Expected: one 20 pt gap stands above the buttons, with no condition on what is above them, so the gap measured in step 5 is the gap under the notice.

**R4. The first gesture row shows the large keyboard and trackpad picture.**

1. Give the 1-finger gesture Notes, with Hold thumb on and the thumb corner *Top left*. Expected:
   - The row is 70 pt tall. Notes's picker is at the trailing edge, its icon's centre 35 pt below the row's top.
   - Measured from the gesture group's top-leading corner, the thumb dot's centre is at (36.3, 31.6) and the ringed dot's centre at (56.4, 41.3), each within 1 pt. These come from the drawing: in the 1270 px export the thumb dot's centre lies 448 px from the left edge and 302 px from the top, and the ringed dot's 634 px and 392 px. Drawn 137 pt wide, less the (12, 1) offset, that gives the two points.
   - The group's rounded top-left corner, its top edge and its leading edge cut the picture. No part of the picture shows outside the group or in the 2-finger row.
2. Set the 1-finger gesture to *None*. Expected: the same, with *Choose app…* at the trailing edge.
3. Give it Notes, then Mail as its second app. Expected: the row is 86 pt tall. The two dots have not moved. Below the picture only the group's fill shows, down to the separator. The pickers' two lines are centred in the row.
4. Remove Mail. Expected: the row is 70 pt tall again.
5. Lay the first row beside the mockup's. Expected: the keyboard, the trackpad and the two dots sit where the mockup has them, within 1 pt, measured from the group's top-leading corner.

**R8. A tall window scrolls.** On a display short enough for the content to pass the cap, or with the cap's 90% lowered temporarily in a local build (and put back):

1. Open the window. Expected: the window's frame is 90% of the display's visible height, within 1 pt. The system's vertical scroller shows. Scrolling to the end shows the *Quit Trackpad Launcher* and *Close* buttons with the 16 pt inset below them.
2. Scroll part way down. Expected: the hands and labels stay at their offsets over the first row's picture (R5) as it moves, and nothing draws over the title bar.
3. Make the content shorter than the cap (remove a second app, or close a card), and taller again. Expected: the window shrinks to its content with no scroller, then grows back to the cap and no further, its top edge still.
4. With a second display of another height, drag the window onto it. Expected: the cap follows the new display.
5. At full height on a tall display, with the cap restored. Expected: no scroller, and the window is as tall as its content, as in R1 to R4's checks.

## Further Notes

**Decisions for the user to confirm.** The requirements leave each of these open. The plan picks one reading and says what the other would change.

- **The window's width (decided by the user).** The window is 358 pt wide, as in the mockup, with groups 326 pt wide. Every control is then clear of the hands and labels, as the mockup shows.
- **The large files are resized.** The first gesture's five files and the two hands were exported at 9 to 19 pixels per point. S1 resizes them to 4 pixels per point, in place. The exports stay in git history, and Figma stays their source. The user can instead export them again at 548, 210 and 240 px wide: the result is the same. If the user wants the large files kept as they are, the other reading is to reduce each picture when the app loads it, which adds code and a test seam and leaves 3.8 MB in the bundle.
- **A test seam for the window's measures.** The plan measures R1 to R4 by hand, as plans 037, 048, 049 and 050 measured this window. A higher seam is possible: the settings view hosted over a real `Launcher`. The user decides whether this change should add it.
  - What it would prove: R1, R2 and R3. The probe shows the hosting view's fitting size is right in the same turn, and the pickers and switches are AppKit views whose frames give each row's centre.
  - What it would not prove: where R4's picture and R5's hands and labels are drawn. They are SwiftUI drawing with no view of their own, so a test could see them only by rendering pixels and searching them. The by-hand sitting stays for them either way.
  - What it needs: the `World` and its in-memory adapters, which live in the core test target, moved to a support target that both test targets use. That touches most of the core test files.
  - What it brings with it: the quick gate, and the release that runs it, would then depend on the grouped form's own metrics on the Mac that runs them. A macOS update that moves those metrics turns the gate red until they are measured again. That is also the moment the window has drifted from the design.
  - If the user wants it, it becomes a slice before S2, and R1 to R3 move from Verified without a test to test scenarios.
- **The gap between the last group and the no trackpad notice.** R3 names the gap under the notice, not the one above it. The plan uses 10 pt, as between groups: the notice is a rounded group like the others. Today it is 20 pt.
- **The 10 pt between the form's groups is macOS's.** The grouped form sets it, and no public API changes it. The probe measured 10 pt on macOS 27.2. The app also runs on macOS 26, where it was not measured. If it differs there, each group would have to become a form of its own to carry our gap.
- **Row heights and separators.** The mockup counts each 1 pt separator inside its row. The form draws separators between rows, as today, so a group of n rows is n − 1 pt taller than the mockup's. Each row is the height R1, R2 and R4 give.
- **The *Hide background apps* row.** It is 52 pt in the mockup. R1 says 48 pt. The plan follows R1.
- **R5 could be two requirements.** R5 holds a rule (when the hands and labels show) and a drawing (where and how). The tests prove the rule. Only eyes judge the drawing. Splitting R5 would give each part its own proof of record. The plan does not split it, since the requirements are confirmed.

**One proof per requirement.** R5, R6 and R7 mix what a test can prove with what only eyes can judge. Their test scenarios are the proof of record. The by-eye checks below, and the one in S2's criteria, are acceptance criteria, not a second proof of record. Plan 037 handled its gear the same way.

**By-eye checks for S1** (R6, R7), on a Debug build opened with `make run`:

1. Open each of the 25 derived files at 800%. Expected: the card's light and rim are the top-left file's. The marks are crisp. No ghost shows where a mark was. In a no-thumb file, a clean card shows where the thumb was.
2. Open the seven resized files at 400%. Expected: smooth edges, no jagged steps, and nothing cut off at a file's edge.
3. Pick each thumb corner in turn. Expected: the 2- to 5-finger pictures and the *Switch recent*, *Switch windows* and *Toggle recent* pictures show the thumb in that corner, as sharp as on a build of `main`.
4. At *Top right*, turn *Hold thumb* off. Expected: the 2- to 5-finger pictures change at once to the fingers without a thumb, in their top-left places. The three switcher pictures keep the thumb top right.
5. With *Hold thumb* off, pick another corner. Expected: the gesture pictures stay the same. The three switcher pictures move the thumb.
6. Turn *Hold thumb* on. Expected: the gesture pictures show the thumb in the corner again.

In S1 the 1-finger row keeps today's layout, so its new picture shows squeezed into 45 × 28 pt under the handwritten guide. It does so on this branch already. S2 gives the row its design.

**By-eye checks for S3** (R5), on a Debug build opened with `make run`, with Hold thumb on and the thumb corner *Top left*:

1. Capture the window. Expected, measured from the gesture group's top-leading corner, within 1 pt: the left hand's box starts at (−11.5, 10.5) and is 52.5 pt wide; the right hand's starts at (55, 24) and is 60 pt wide; the *Hold* label starts at (−11, 49) and the *Tap* label at (92, 55); each label is 18 pt tall.
2. Lay it beside the mockup. Expected: the left hand rests on the trackpad's top-left corner with *Hold* below it, and the right hand taps the trackpad's centre with *Tap* below it. The keyboard shows faintly through the hands. The labels cover the hands. Each label looks like the mockup's: a small light tooltip with a soft shadow, a filled dot for *Hold* and a ringed dot for *Tap*. The hands' edges are smooth.
3. Look at the group's leading edge and the first row's separator. Expected: neither cuts a hand or a label. No handwritten guide shows.
4. Pick *Bottom left*. Expected: the hands and labels go at once, and the picture shows the thumb bottom left. Pick *Top left*. Expected: they return.
5. Turn *Hold thumb* off. Expected: they go at once, and the picture shows no thumb. Turn it on. Expected: they return.
6. Add a second app to the 1-finger gesture. Expected: the hands and labels have not moved.
7. Compare a capture with the Accessibility hint card showing and one without it. Expected: the same offsets from the gesture group.
8. Click the 1-finger picker, then the 2-finger picker. Expected: each menu opens.
9. Give the 1-finger gesture a second app with a long name, so the second line's minus button sits under the *Tap* label. Click the second picker. Expected: its menu opens. Click the minus button through the label. Expected: the second app is removed.
10. With a Magic Trackpad connected, *MacBook trackpad* *Top left* and *External trackpad* *Bottom left*. Expected: no hands or labels. Switch the Magic Trackpad off. Expected: they appear.

**Commands the slices use.**

- S1's resize, run once on each file, in place: `sips --resampleWidth 548 -s dpiWidth 288 -s dpiHeight 288 <file>` for the first gesture's five files, with 210 for the left hand and 240 for the right. A trial into the `.temp` folder gave 548 × 272, 210 × 208 and 240 × 186 px, 0.63 MB in all, with smooth edges. After it, each first-gesture corner file still differs from the no-thumb file in one patch of about 38 px, as T7 expects.
- S2's check that no code of the handwritten guide remains: `git grep -n -e showsGuide -e "struct Guide" -e '"guide"' -- LauncherKit` prints nothing, and the assets folder holds no `guide.svg`.

**What the probes measured.** Two throwaway probes sit in this plan's `.temp` folder, which git ignores: `form-probe.swift` and `overlay-probe.swift`. Each is built with `swiftc`, renders a grouped form offscreen in the light appearance, and reads the result off the pixels. On macOS 27.2:

- The form's margins are 20 pt on every side, and a row's padding is 10 pt on every side. Both are what the code assumes today.
- Rows of 28, 50 and 66 pt content come out 48, 70 and 86 pt tall, with a 1 pt separator between rows.
- Two sections sit 10 pt apart. This is the system's value. `listSectionSpacing` and `listSectionMargins` are unavailable on macOS.
- A section's corner radius is 12 pt, the value the group style already holds.
- The form clips a row's content to its section's rounded shape. A picture offset past the section's leading and top edges is cut there.
- An overlay on the form reaches past the group's edge uncut, draws over a pop-up button in a row, and with hit testing off lets a click through: a hit test at the covered button's centre returns the button.

The app's deployment target is macOS 26. These values were not measured there. The by-hand checks run on the developer's Mac.

**The branch starts red.** The commit that brought the new art replaced the seven top-left files with 4× versions and the first gesture's files with the large picture. The derived copies beside them are still the old 2× ones. So `CornerIllustrationFileTests` fails today, with 26 issues. S1 turns it green.

## Slices

### S1: Every picture in the new drawing, and no thumb while Hold thumb is off

**What to build:** Every small picture shows the new drawing, with its thumb in the thumb corner the user picked. When the user turns *Hold thumb* off, the 2- to 5-finger pictures change at once to the fingers without a thumb, while the *Switch recent*, *Switch windows* and *Toggle recent* pictures keep theirs. Turning it on brings the thumb back. The corner illustration script produces every derived file from the hand-drawn ones, the large hand-drawn files are stored at their display size, and the quick gate, red on this branch today, is green again.

**Blocked by:** None (can start immediately).

**Requirements:** R6, R7.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-swiftui`.

- [ ] The script derives three corner copies of each of the seven small pictures and a no-thumb copy of gestures 2 to 5, at 180 × 112 px, and writes no first-gesture file. Run on a clean tree, it changes no tracked file.
- [ ] The first gesture's five files are 548 px wide and the hands 210 and 240 px wide, at 288 dpi: 4 pixels per point of 137, 52.48 and 60 pt.
- [ ] T5, T6, T7 and T8 are green. The stale-size failures of the corner illustration file tests are gone.
- [ ] T1, T2, T3 and T4 are green.
- [ ] The gesture rows show the picture for the model's gesture thumb. The switcher rows show the picture for the corner drawn.
- [ ] The by-eye checks for S1 under Further Notes, all six, each with its stated result.
- [ ] `make test` is green. The tests this slice can break: the corner illustration and thumb corner rule tests it rewrites; the gear and update picture asset tests, which share the assets path; the Hold thumb, corner choice and mixed trackpads suites, which read the same model; the source-scan test.

### S2: The window at the design's measures, with the large first picture

**What to build:** The settings window opens at the design's measures: 358 pt wide, with 326 pt groups. Every one-line row is 48 pt tall and a row with a second app is 86 pt. The update card, the Accessibility hint card, the groups and the buttons sit at the design's gaps. The 1-finger row is 70 pt tall and shows the large keyboard and trackpad picture, fixed to the group's top-leading corner and cut by it, with its thumb in the corner drawn, or without one while *Hold thumb* is off. The handwritten guide is gone.

**Blocked by:** S1 (the picture rule, the model's gesture thumb, the resized files, and a green gate).

**Requirements:** R1, R2, R3 and R4; R5 in the part that removes the handwritten guide; R6 and R7 in the part that shows the first gesture's picture in its row.

**Test scenarios:** None.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-macos`.

- [ ] The manual check for R1 as under Verified without a test, all five steps, each with its expected result.
- [ ] The window's content is 358 pt wide and every group 326 pt wide; the update card's and Accessibility hint card's pictures still sit clipped at the card's trailing side, as in the mockup.
- [ ] The manual check for R2, both steps.
- [ ] The manual check for R3, all six steps. Step 6 says which route was taken.
- [ ] The manual check for R4, all five steps.
- [ ] By eye, for the first gesture's picture in its row: at *Top right*, *Bottom left* and *Bottom right* the thumb dot's centre is at (76.5, 31.6), (36.3, 51.0) and (76.5, 51.0) from the group's top-leading corner, within 1 pt; with *Hold thumb* off no thumb dot shows; the picture's edges are smooth on the Retina display.
- [ ] No view, rule, test or asset of the handwritten guide remains (the check is under Further Notes).
- [ ] `make test` is green. No test measures the window, so the tests this slice can break are the corner illustration tests, through the picture rule and the assets folder, and the source-scan test.

### S3: Hands and labels show how to make the first gesture

**What to build:** While *Hold thumb* is on and the thumb is drawn top left, two hands and the *Hold* and *Tap* labels sit over the first gesture's picture, where the design puts them. They go at once when the user picks another corner, turns *Hold thumb* off, or connects an external trackpad with another corner, and return when the state returns. They never take a click.

**Blocked by:** S2 (the first gesture's overlay and its large picture).

**Requirements:** R5.

**Test scenarios:** T9, T10, T11.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:swift-testing-pro`.

- [ ] T9, T10 and T11 are green.
- [ ] The hands and labels show exactly while the model says the hand guide shows. Nothing else in the view decides it.
- [ ] The by-eye checks for S3 under Further Notes, all ten, each with its stated result.
- [ ] `make test` is green. The tests this slice can break: the Hold thumb, corner choice and mixed trackpads suites, which read the same model, and the source-scan test.

### S4: A tall window scrolls

**What to build:** The settings window is never taller than 90% of its display's visible area. Content taller than that scrolls inside the window with the system's scroller, and the hands and labels scroll with the first row. Content that fits keeps the window at its content's height with no scroller. The cap holds on every fit and when the window moves to another display.

**Blocked by:** S3 (the hands and labels that must scroll with the first row).

**Requirements:** R8.

**Test scenarios:** T12.

**Skills:** `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:swift-testing-pro`.

- [ ] T12 is green.
- [ ] The by-hand check for R8 under Verified without a test, all five steps, each with its stated result.
- [ ] R1 to R4's measures are unchanged when the content fits.
- [ ] `make test` is green, and `make gate` ends with "gate: all green".
