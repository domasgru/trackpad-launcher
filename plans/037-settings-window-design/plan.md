# Plan: Settings window design update

Design: [Figma, Utility Panel](https://www.figma.com/design/EB5ptBWZnAot7J3vx3cYLw/TapLauncher?node-id=2193-21747). The frame is the visual target for everything these requirements change.

## Problem statement

The settings window lists the permission hints below the form, far from what they affect. The Accessibility hint matters most, because gestures work less reliably without it, yet it is the last thing the user reads. The screen recording hint concerns one setting, *Switch windows*, but sits apart from that setting's switch. Both buttons have long titles that repeat the hint above them.

## Solution

The Accessibility hint moves to the top of the window as a card that stands out: a light border, a slowly turning gear and a filled blue button. The frame shows the gear at rest; the turning draws the eye to the hint. The screen recording hint moves into the *Switch windows* row, right under its switch, with a yellow warning triangle. Both buttons read *Open Settings…*. The rest of the window stays as it is.

## Requirements

*Switch windows* is the window swipe's switch. *Toggle recent* is the swap's.

The window resizes to fit its content whenever a hint, the notice or the update card appears or disappears, as it does today.

### R1. The Accessibility hint sits above the form

While the Accessibility permission is missing, the Accessibility hint MUST show above the form, 20 pt from it. While a newer version is known, the update card MUST stay first, with the hint below it, 20 pt apart.

#### Scenario: Permission missing, no update

- **GIVEN** the Accessibility permission is missing and no newer version is known
- **WHEN** the user opens the settings window
- **THEN** the hint is the first thing in the window and the gesture rows follow it

#### Scenario: Release check finds an update

- **GIVEN** the window is open with the hint first
- **WHEN** the release check finds a newer version
- **THEN** the update card appears above the hint, the hint and the gesture rows move down and the window grows to fit

#### Scenario: Permission granted while the window is open

- **GIVEN** the settings window shows the hint
- **WHEN** the user grants the Accessibility permission
- **THEN** the hint disappears, the gesture rows move up and the window shrinks to fit

#### Scenario: Permission already granted

- **GIVEN** the Accessibility permission is granted
- **WHEN** the user opens the settings window
- **THEN** no hint shows and the gesture rows come first (or the update card, once known)

### R2. The Accessibility hint has its own card design

The hint MUST be a rounded group with a light border, its message limited to 216 pt wide, and a filled blue button under it, titled as R5 says. The button MUST open the Accessibility page of System Settings, with no macOS prompt first.

#### Scenario: Pressing the button

- **GIVEN** the hint shows
- **WHEN** the user presses *Open Settings…*
- **THEN** System Settings opens on the Accessibility page and the settings window stays open

### R3. A gear turns in the Accessibility hint's corner

The hint MUST show the Figma gear in its top-right corner, 91 pt in diameter, partly outside the card and clipped by its edges. The gear MUST turn clockwise around its own centre at a constant speed of one full turn every 30 seconds. It MUST turn for as long as the card is shown. With the system's Reduce motion setting on, it MUST stay still. It MUST follow Reduce motion live. The gear MUST NOT take clicks or block the button.

#### Scenario: Card shown

- **GIVEN** the Accessibility permission is missing
- **WHEN** the settings window opens
- **THEN** the gear turns smoothly and never jumps, including where a turn ends and the next begins

#### Scenario: Reduce motion on

- **GIVEN** the Accessibility permission is missing and Reduce motion is on
- **WHEN** the settings window opens
- **THEN** the gear shows at rest and does not turn

#### Scenario: Reduce motion turned on while the card shows

- **GIVEN** the card shows and the gear turns
- **WHEN** the user turns Reduce motion on, then off again
- **THEN** the gear stops at rest, and turning the setting off starts it turning again

#### Scenario: Card gone

- **GIVEN** the settings window shows the card
- **WHEN** the user grants the Accessibility permission
- **THEN** the card and its gear disappear, and nothing keeps animating

#### Scenario: Idle with the window closed

- **GIVEN** the Accessibility permission is missing
- **WHEN** the user closes the settings window
- **THEN** the app stays at no idle wakeups, as it does today

### R4. The screen recording hint sits inside the *Switch windows* row

While the screen recording hint applies, it MUST show directly under the *Switch windows* switch, in the same row of the group, its left edge lined up with the row's title. It MUST start with a yellow warning triangle, and its button MUST sit under the message in the ordinary grey style. The hint MUST show while Screen Recording is missing and the *Switch windows* switch is on, and disappear once the permission is granted. The first press of its button, ever, MUST show macOS's own prompt; the fact that it asked survives relaunches. Every later press MUST open the Screen Recording page of System Settings.

#### Scenario: Permission missing, setting on

- **GIVEN** Screen Recording is missing and the *Switch windows* switch is on
- **WHEN** the user opens the settings window
- **THEN** the triangle, the message and *Open Settings…* show under the switch, above *Toggle recent*

#### Scenario: Turning the setting on

- **GIVEN** Screen Recording is missing and the switch is off
- **WHEN** the user turns it on
- **THEN** the hint appears in the row and the window grows to fit

#### Scenario: Turning the setting off

- **GIVEN** the hint shows
- **WHEN** the user turns the *Switch windows* switch off
- **THEN** the hint disappears, the row returns to its usual height and the window shrinks to fit

#### Scenario: First press asks, later presses open System Settings

- **GIVEN** the hint shows and the app has never asked for the permission
- **WHEN** the user presses *Open Settings…*, then presses it again while the permission is still missing
- **THEN** the first press shows macOS's own prompt, and the second opens the Screen Recording page of System Settings

### R5. Both permission buttons read *Open Settings…*

Both buttons MUST read *Open Settings…*. The screen recording button keeps this title whether the press asks macOS or opens System Settings. The messages MUST stay word for word: "Allow Accessibility access to make trackpad gestures work reliably." and "Allow Screen Recording access to show previews in the window switcher."

#### Scenario: Both hints show

- **GIVEN** both permissions are missing and the *Switch windows* switch is on
- **WHEN** the user opens the settings window
- **THEN** each hint's button reads *Open Settings…*, and each message still names its own permission

## Non-goals

- The update card. Its design does not change.
- The *Hide background apps* switch. The Figma frame leaves it out, but it stays below *Thumb corner*.
- The no trackpad notice. The design has no place for it, so it stays below the form, above *Quit Trackpad Launcher* and *Close*, in its current style.
- A dark appearance. The window stays light, as it does today, until a dark theme is designed.
- The title bar, the gesture rows, the switches and the bottom buttons, apart from the hint R4 adds to the *Switch windows* row. The window already matches the frame there, and they keep the system's own controls.
- Pausing the gear while the window is behind another app, minimised or hidden. The card counts as shown, so the app does nothing to stop the gear; keeping one rule is worth more than the small cost.
- A speed setting for the gear. Thirty seconds is a value that we will tune by eye.

## Implementation Decisions

### The column

- The settings column keeps its one-column shape (326 pt wide, parts 20 pt apart, 16 pt in from the edges) and reorders its parts: the update card, while a newer version is known; the Accessibility hint card, while the permission is missing; the form; the no trackpad notice, while gestures are inactive; then *Quit Trackpad Launcher* and *Close*. The 20 pt between parts is the column's existing spacing, so R1's two gaps come for free.
- The notice block below the form holds only the no trackpad notice. Its "has notices" guard and the 10 pt notice spacing go; the notice view loses its optional button (no notice has one any more) and the button-description value type that only served it goes with it. The doc comments on the column and the notice view stop naming the tap-bound settings notice and the two permission hints.
- The update card does not change, and the shared rounded group view keeps its rendering; it only exposes its metrics (corner radius 12, 10 pt side inset, the quaternary fill) as named constants so the Accessibility card draws the same shape without going through it.
- The window height keeps following the shell's existing fit observation, which already reads the Accessibility hint, the screen recording hint, the inactive notice and the update card; nothing new feeds it. This is the first time content inside the Form changes height live, so the probe checked it (`.temp/layout.swift live`): the hosting view's fitting size is stale in the same turn as the model change, for the card outside the Form as much as for the hint inside it, but it is current by the turn in which an `Observations` loop like the shell's reads it (394.5 → 461.5 → 558.5 → 491.5 pt as the hint and the card flip). The existing refit needs no change.

### The Accessibility hint card

- A view of its own: the message (the existing 11 pt notice text style, at most 216 pt wide, leading-aligned), 8 pt, then the button, 8 pt in from the top and bottom and 10 pt from the sides, on the group's fill and radius, clipped to that rounded rectangle, with a 1 pt `#dedede` border drawn inside the edge. Its height is the frame's 76 pt.
- The gear is a background of the card's content, aligned to the top-trailing corner and offset 19 pt right and 23 pt up (the frame's x 222, y -23 in the 294 pt group), so the card's clip cuts it at the top and right edges. It draws over the fill and under the message and button, and takes no hit tests on either side of the AppKit bridge. The offscreen probe (`.temp/layout.swift`, `.temp/layout-both.png`) shows SwiftUI's clip applies to the bridged AppKit view on macOS 26 for a still gear captured offscreen; the by-hand check on the real window confirms it for the turning one. The fallback, should the clip ever fail on screen, is the probe's `mask` mode: the gear view as large as the card, masking its own layer to the card's rounded rectangle, with the gear placed inside it; it renders identically in the probe and would change T2's expected bounds.
- The button uses the existing tinted button style with a new *filled* face: a white 13 pt medium label on the solid tint, 24 pt tall, 16 pt horizontal padding, radius 6; pressed, the fill goes a touch darker. The style's metrics stay in one place for both faces. The tint is the system's accent colour: blue unless the user chose another accent, which is what the switches beside it already follow, and what the frame's "accent blue" names. R2 says "blue"; this reading is flagged for the user, and a fixed blue is a one-constant change.
- Pressing it calls the actions' `openSettings(.accessibility)` as today: System Settings opens on the Accessibility page and nothing prompts.

### The gear

- One SVG asset, exported from the Figma gear node and committed under the repository's assets folder, reaches the bundle through the project's existing resource rule for SVGs and loads through the existing bundle-image loader. No Figma URL ships. The export's root `width` and `height` are normalised to `91` if Figma writes them otherwise, since the image's size is read from them.
- A small AppKit view behind a SwiftUI representable, modelled on the app picker's icon view: a flipped, layer-backed view 91 × 91 pt, hit-testing nothing, holding one sublayer with the gear as its contents, bounds 91 × 91, position (45.5, 45.5), anchor at its centre, implicit actions off, its contents scale following the window's backing scale.
- The turn is one Core Animation animation on that sublayer: `transform.rotation.z` from 0 to 2π, linear, repeating forever, with the period as one named constant (30 s) that the user will tune by eye. In a flipped view the layer's geometry is flipped (the probe confirmed `isGeometryFlipped == true`), so a positive angle should be clockwise on screen; the direction is confirmed by eye, not by a test. The model transform stays identity, so the gear rests in the frame's pose whenever the animation is absent, and a turn's end meets the next turn's start at the same angle, so nothing jumps. The render server plays it: the probe (`.temp/gear-cost.swift`) measured the Core Animation gear indistinguishable from a still window (2–41 ms of process CPU over 5 s against 8–20 ms still, run to run), against 255 ms process and 225 ms main-thread CPU for a SwiftUI `repeatForever` rotation of the same gear, which advances in the process every frame and is therefore out.
- The view owns its lifetime rule: on entering a window it adds the animation unless Reduce motion is on, and starts observing the workspace's accessibility display options notification (a selector observer on the workspace's notification centre, so delivery is synchronous on the posting thread); on that notification it re-reads Reduce motion and adds or removes the animation; on leaving a window it removes the animation and stops observing. Reduce motion is read through an injected reader (the workspace's `accessibilityDisplayShouldReduceMotion` in the app) so a test can flip it. Nothing else turns the gear: the card going (the permission granted) removes the view from its window, which is what stops the gear. The window closing leaves the animation on the render server: the probe's `ca-hide` mode ordered the window out for 2 s and back in, and the animation stayed on the layer and kept advancing at 2π/30 rad/s throughout (presentation angle 0.21 → 0.66 → 1.10 rad), at no process cost while hidden; so the gear is still turning when the window opens again, with nothing to restart.

### The screen recording hint in its row

- The switcher section takes the actions as well as the launcher, like the gesture rows do. Its *Switch windows* row becomes one Form row holding a vertical stack: the existing setting row (illustration, title, switch) and, while the launcher's screen recording hint is non-nil, the hint 4 pt below it, inset by the illustration's width plus the gap between the illustration and the title, so the hint's leading edge is the title's. That gap is today the stack's default, measured at 8 pt (`.temp/gap.swift`: the title sits 53 pt from the row's leading edge); it becomes an explicit named 8 pt shared by the setting row and the hint's inset, so no row moves. The frame has the gap at 10 pt (the title and the hint at 55); the 2 pt difference is flagged for the user, and closing it is that one constant. The probe shows a Form row laid out this way keeps the switch level with the title and adds no separator inside the row; the row grows from 46 pt to the frame's 110 pt while the hint shows.
- The hint view takes the launcher and the actions, as the gesture row view does, and its button routes on the launcher's hint: `.ask` calls the launcher's `askForScreenRecording()`, `.openSettings` calls the actions' `openSettings(.screenRecording)`. The model keeps the first-ever-ask rule and its persistence; nothing there changes.
- The hint's message is one Text: the `exclamationmark.triangle.fill` symbol in `#ffcc00`, a space, then the message, in the notice text style, at most 219 pt wide, wrapping as a paragraph with the symbol inline; 8 pt below it, the button in the ordinary bordered style with radius 6.

### Copy

- One constant, *Open Settings…*, replaces the two button titles; both hints use it. The two messages stay as they are.

### Docs

- The domain model's settings window, Accessibility hint and screen recording hint entries describe the new placement, the card, the gear and the one button title (done with this plan).
- The architecture's animation rule records the gear as the one animation that never completes: a repeating rotation the render server plays while its card is in the window, the window closed included, removed with the card (done with this plan).

## Testing Decisions

### Strategy

Three seams, none rendering SwiftUI:

- The copy values, in the core copy tests: R5's literals are read straight off the constants.
- The gear's AppKit view, driven directly from a test as the app picker tests drive the picker button, plus a window, which no test in the repository makes today: the bench touches `NSApplication.shared`, makes a borderless window that is never ordered in, and sets the view as its content view, which is what moves it into a window. The test makes the view with an injected Reduce motion reader and reads the gear layer's animation (key path, values, duration, repeat count, timing) and the layers' stillness, and flips Reduce motion by changing the reader and posting the workspace notification to the workspace's own notification centre, which the view's selector observer receives synchronously, so nothing settles. The suite is serialized because it posts to a shared centre. This observes the animation's parameters and the view's lifetime rule; it misses the picture on screen, the direction as seen, and the real workspace wiring.
- The gear asset read from the repository's assets folder, as the corner illustration tests read theirs, through `NSImage` because the image loader there reads bitmaps only: observes that the file exists, is 91 × 91 pt and draws its gear centred; misses whether the bundle carries it (the project's SVG rule, unchanged, does that).

Faked: the Reduce motion reader (a closure) and the workspace notification (posted by the test). Everything else is real. The picture itself, the placement, the window's resize, the gear as seen and the two System Settings presses are proved by hand, because they are what a test at these seams cannot see: R1, R2 and R4 under Verified without a test; the by-eye checks that complete R3 beside T2–T6 as S1's acceptance criteria, with their steps under Further Notes.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R5 | Copy | Given the copy constants, when read, then the one button title is "Open Settings…" and the two messages are "Allow Accessibility access to make trackpad gestures work reliably." and "Allow Screen Recording access to show previews in the window switcher." | R5's literals |
| T2 | R3 | Gear view | Given a gear view whose Reduce motion reader says off, when it enters a window, then its gear layer carries exactly one animation: `transform.rotation.z` from 0 to 2π, duration 30, repeating forever, linear; the layer's model transform is identity, its anchor is its centre, its bounds 91 × 91 and its position (45.5, 45.5); the view's own layer carries none; the view hit-tests nothing | R3 (30 s per turn at constant speed, one full turn, 91 pt, around its own centre, no clicks) |
| T3 | R3 | Gear view | Given the reader says on, when the view enters a window, then no layer carries an animation and the gear layer's transform is identity | R3's Reduce motion scenario |
| T4 | R3 | Gear view | Given the view is in a window and turning, when the reader flips to on and the workspace's accessibility display options notification is posted, then the animation is gone and the transform is identity; when the reader flips to off and the notification is posted again, then the T2 animation is back | R3's live scenario |
| T5 | R3 | Gear view | Given the view is in a window and turning, when it leaves the window, then no layer carries an animation; when it enters a window again, then the T2 animation is back | R3's card-gone scenario |
| T6 | R3 | Asset file | Given the repository's assets folder, when the gear SVG is loaded as an `NSImage` and drawn into a bitmap, then it exists, its size is 91 × 91 pt, and the centroid of its drawn pixels' alpha lies within 0.5 pt of the image's centre | R3's diameter and "around its own centre"; the Figma node's size |

### Verified without a test

- R1 (placement and order, the window fitting). On a Debug build, whose bundle identifier keeps its permissions and settings apart from the release's: reset its grants (`tccutil reset Accessibility com.domasgru.TrackpadLauncherApp.debug`, `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp.debug`), run it, open the window: the card is first and the gesture rows follow. Grant Accessibility in System Settings while the window is open: the card goes, the rows move up, the window shrinks. Close the window with ⌘W and open the app again: no card, the rows come first. Revoke the grant: the card is back. Compare a screenshot of the window with the Figma frame's screenshot (fetched from the Figma MCP into the plan's `.temp`): same order, 20 pt gaps, same card. The hint's following of the grant is already proved by the existing activity tests, which stay green. The "Release check finds an update" scenario needs a copy that checks, which only a Developer ID copy in /Applications is: build one from this branch with a version below the latest release (`xcodegen generate`, then `xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build/card CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" DEVELOPMENT_TEAM=<the team in Scripts/release.sh> MARKETING_VERSION=0.0.1 build`), quit the installed copy, copy the product over `/Applications/Trackpad Launcher.app` with `ditto`, reset its grant (`tccutil reset Accessibility com.domasgru.TrackpadLauncherApp`, which clears the installed release's grant), open it: the window opens with the hint card first, then, when the check answers, the update card appears above it reading "App version <latest> is available", the hint 20 pt below it, the gesture rows below that, and the window grows. Then press *Update now*, which installs the latest release over the test copy, and grant Accessibility again. A test cannot see the window.
- R2 (the card's look and its button): the same screenshot comparison for the border, the 216 pt message and the filled button; pressing *Open Settings…* opens System Settings on the Accessibility page with no prompt, and the settings window stays open. The press is the unchanged `openSettings(.accessibility)` action.
- R4 (the hint in the row, the resize, the two presses). On the Debug build, with Screen Recording reset as above and the Debug build's saved settings deleted first (`defaults delete com.domasgru.TrackpadLauncherApp.debug settings`, which also clears the remembered ask; this makes the next opening a first run, whose Accessibility prompt is dismissed), open the window and turn *Switch windows* on: the triangle, the message and *Open Settings…* appear under the switch, above *Toggle recent*, lined up with the title, and the window grows; compare with the Figma frame; turn it off: the row returns to 46 pt and the window shrinks; turn it on again. Press the button once: macOS's own prompt, dismissed without granting; press again: System Settings on the Screen Recording page. Grant Screen Recording there: the hint goes and the window shrinks. The ask-once rule, its survival across relaunches and the hint's disappearance on the grant are already proved by the existing window preview tests, which stay green; the routing from the hint's two cases to the ask and to the System Settings page is what the two presses prove.
- The whole: `swift test` green, including the source policy scan (no timer, no display link in the new code) and the corner illustration tests; the app builds through `xcodegen` and `xcodebuild` and the bundle holds `gear.svg`.

## Further Notes

- Figma: file `EB5ptBWZnAot7J3vx3cYLw`, frame node `2193:21747`, gear node `2193:21759`. The gear's SVG comes from the design context's asset URL and is downloaded once into the assets folder; the URL is temporary and must not appear in code.
- Two design readings for the user: R2's "blue" is implemented as the system accent colour (blue by default), as the switches are; and the illustration-to-title gap stays at today's 8 pt (the frame has 10), so the hint lines up with the title at 53 pt rather than the frame's 55. Each is one constant if the user wants the other reading.
- R3 mixes what a test can prove (the animation's parameters and lifetime, T2–T6) with what only eyes and a sampler can (direction, smoothness, the clip, idle); the testing rule allows one proof per requirement, so the by-eye checks are S1's acceptance criteria rather than a second proof of record. Splitting R3 into a visual requirement and a rule requirement would make the record exact; that is offered to the user, not done, since the requirements are confirmed.
- By-eye checks for R3, run in S1 on the Debug build with the card showing: the gear turns clockwise and smoothly, and does not jump where a turn ends and the next begins (watch past 30 s); it is cut by the card's top and right edges, with its left and bottom whole; turn Reduce motion on in System Settings → Accessibility → Display while the window shows: it stops in the frame's pose; turn it off: it turns again; close the window with ⌘W and open the app again: still turning; minimise and restore: still turning. The idle check follows docs/performance.md, never a Debug build: `Scripts/perf/build.sh`, open the perf build (its release identifier means `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp` clears the installed release's grant too, to be granted again afterwards), open the window so the card shows and the gear turns, close it with ⌘W, then `build/perf/tools/sampler <pid> 1000 60 closed`: 0 idle wakeups over the minute, matching the baseline's "Hands off" row.
- The probes under `.temp` are kept with the plan, as plan 036's were. `gear-cost.swift` (`swift gear-cost.swift still | ca | swiftui | ca-hide`) measured the CPU of each gear over 5 s, and the `ca-hide` mode the animation across `orderOut` and `orderFront`. `layout.swift` (compile with `swiftc`; the interpreter's JIT lacks an availability symbol) renders the proposed column offscreen in a state (`both | none | card | hint`) with the gear clipped by SwiftUI (`clip`) or by its own layer (`mask`); `layout-both.png` and `layout-none.png` are its output; its `live` state flips the hint and the card after the window shows and reads the fitting size in the same turn and from an `Observations` loop. `gap.swift` prints today's title offset.
- The probe's hint text used a looser line spacing than the frame's 14 pt line height; the implementation uses the notice text style (11 pt, 1 pt line spacing) for both messages and checks the card's 76 pt and the row's 110 pt against the frame.
- The shell's fit observation also reads the swipe setting, which no longer changes the height; it is harmless and left alone.

## Slices

### S1: The Accessibility hint card with its turning gear

**What to build:** With the Accessibility permission missing, the settings window opens with the hint as a bordered card above the form, its gear turning once every 30 s (still under Reduce motion, live), its filled *Open Settings…* button opening the Accessibility page; the card goes, and the window shrinks, when the permission is granted. Both permission buttons' copy becomes the one *Open Settings…* constant.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R5 (the copy and the Accessibility button).

**Test scenarios:** T1, T2, T3, T4, T5, T6.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:swift-testing-pro`, `figma:figma-design-to-code`.

- [ ] The gear SVG is exported from the Figma node into the assets folder, with `width` and `height` of 91, and ships in the bundle; T6 is green.
- [ ] The gear view passes T2–T5; the source policy scan stays green.
- [ ] The card sits above the form, 20 pt from it, below the update card when one shows; the no trackpad notice stays below the form; the column's doc comment describes the new column.
- [ ] T1 is green; the Accessibility button reads *Open Settings…* and opens the Accessibility page with no prompt.
- [ ] Manual check for R1 and R2 as under Verified without a test, the Developer ID copy's update-card step included, with the Debug build's screenshot compared to the Figma frame (the card alone; both hints showing needs S2).
- [ ] The by-eye checks for R3 under Further Notes, the idle sampler run on the perf build included, each with its stated result.

### S2: The screen recording hint inside the Switch windows row

**What to build:** With Screen Recording missing and *Switch windows* on, the hint shows under that switch inside its row, with the yellow triangle and the grey *Open Settings…* button; the row and the window grow and shrink with it; the first press ever asks macOS, later presses open the Screen Recording page. The notice block below the form holds only the no trackpad notice.

**Blocked by:** S1 (the shared button title constant and the notice block's shrinking).

**Requirements:** R4, R5 (the screen recording button).

**Test scenarios:** None.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:swift-testing-pro`, `figma:figma-design-to-code`.

- [ ] The existing window preview tests and the whole suite stay green.
- [ ] The switcher section reaches the actions; the hint sits in the *Switch windows* row at the title's leading edge, 4 pt under the switch row, and the row is 110 pt while it shows.
- [ ] The notices block holds only the no trackpad notice; the notice view has no button, and its doc comment and the column's name no hint.
- [ ] Manual check for R4 as under Verified without a test, including the settings reset, the two presses and the grant, with the Debug build's screenshot compared to the Figma frame in the both-hints state and the no-hints state, both buttons reading *Open Settings…*.
