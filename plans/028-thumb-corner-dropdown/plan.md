# Plan: Four thumb corners

## Problem statement

The thumb can anchor only in a top corner. The settings window offers *Left thumb* (top-left) and *Right thumb* (top-right) in a segmented control. A user who rests their thumb at the bottom of the trackpad cannot use the gestures.

## Solution

The settings window offers a *Thumb corner* pop-up with four choices: *Top left*, *Top right*, *Bottom left* and *Bottom right*. Each choice moves the anchor corner to that corner of the trackpad. Every gesture works there as it does in the top corners. The illustrations show the thumb in the chosen corner. With a bottom corner, the palm band is the bottom edge outside the corner, and the side edges are not part of it. Top corners keep today's palm band. The *Hold* / *Tap* guide shows only for *Top left*, as it does today only for *Left thumb* (top left).

The anchor corner keeps its size in every corner: 20% of the width from its side edge and 25% of the height from its top or bottom edge, with the same 2 mm release margin.

## Requirements

### R1. The thumb corner is chosen from a pop-up
The settings window MUST show a *Thumb corner* row in place of the *Left thumb* / *Right thumb* segmented control. Its pop-up offers *Top left*, *Top right*, *Bottom left* and *Bottom right*, in that order, and shows the current choice.

#### Scenario: Picking a bottom corner
- **GIVEN** the thumb corner is *Top left*
- **WHEN** the user opens the *Thumb corner* pop-up and picks *Bottom right*
- **THEN** the pop-up shows *Bottom right*
- **AND** the anchor corner is the bottom-right corner for every thumb that lands after the change; a thumb already down when the choice changes is judged afresh, as after any settings change: it anchors only if it rests in the new corner, and otherwise is a plain contact until it lifts

#### Scenario: The current choice shows when the window opens
- **GIVEN** the user picked *Bottom left* earlier
- **WHEN** they open the settings window
- **THEN** the pop-up shows *Bottom left*

### R2. A bottom corner anchors the thumb at the bottom
With *Bottom left* or *Bottom right* chosen, the anchor corner MUST be the zone 20% of the width from that side edge and 25% of the height from the bottom edge. A contact anywhere else MUST NOT anchor. An anchored thumb MUST stay anchored until it moves more than 2 mm outside the zone.

#### Scenario: Thumb inside the bottom-left corner
- **GIVEN** the thumb corner is *Bottom left*
- **WHEN** a thumb rests 10 mm from the left edge and 10 mm from the bottom edge, and one finger taps elsewhere
- **THEN** the 1-finger gesture fires

#### Scenario: Thumb just outside the bottom corner's height
- **GIVEN** the thumb corner is *Bottom right*, on a trackpad 80 mm tall
- **WHEN** a thumb rests 10 mm from the right edge and 25 mm from the bottom edge, and one finger taps elsewhere
- **THEN** no gesture fires

#### Scenario: A top corner no longer anchors
- **GIVEN** the thumb corner is *Bottom left*
- **WHEN** a thumb rests in the top-left corner and one finger taps elsewhere
- **THEN** no gesture fires

#### Scenario: The anchored thumb rolls slightly out of the bottom corner
- **GIVEN** the thumb corner is *Bottom left* and a thumb is anchored
- **WHEN** the thumb rolls 1 mm above the corner's top boundary and one finger taps elsewhere
- **THEN** the 1-finger gesture fires

#### Scenario: The anchored thumb rolls too far out of the bottom corner
- **GIVEN** the thumb corner is *Bottom left* and a thumb is anchored
- **WHEN** the thumb rolls 3 mm above the corner's top boundary and one finger taps elsewhere
- **THEN** no gesture fires

### R3. Every gesture works the same from a bottom corner
The tap gestures, the swipe, the window swipe, the swap (a thumb tap under two resting fingers), click blocking, scroll suppression, Dock swipe blocking and the haptic feedback MUST behave in a bottom corner exactly as they do in a top corner. Slide directions MUST stay the same: sliding right reaches older apps, and up and down drive the window swipe as today.

#### Scenario: Swipe from the bottom-right corner
- **GIVEN** the thumb corner is *Bottom right* and the swipe setting is on
- **WHEN** a thumb rests in the bottom-right corner and two fingers slide right
- **THEN** the switcher appears and the selection moves to older apps, as it does from a top corner

#### Scenario: Swap from the bottom-left corner
- **GIVEN** the thumb corner is *Bottom left*, the swap setting is on, and two fingers rest outside the corner
- **WHEN** the thumb taps in the bottom-left corner
- **THEN** the app used before the frontmost one comes to the front

#### Scenario: Window swipe from the bottom-left corner
- **GIVEN** the thumb corner is *Bottom left*, the window swipe setting is on, and the frontmost app has two or more windows
- **WHEN** a thumb rests in the bottom-left corner and two fingers slide down
- **THEN** the window switcher appears and the selection moves the same way it does for a slide down from a top corner

### R4. Bottom corners have their own palm band
With a bottom corner chosen, an edge contact MUST be a contact landing closer than 3 mm to the bottom edge, outside the anchor corner. The side edges MUST NOT be part of the band, and a contact landing inside the anchor corner MUST NOT be an edge contact. An edge contact is ignored for as long as it stays down: it neither starts nor joins a tap, a swipe or a swap.

#### Scenario: Thumb hugging the bottom edge in the corner
- **GIVEN** the thumb corner is *Bottom left*
- **WHEN** a thumb lands 1 mm from the bottom edge and 10 mm from the left edge, and one finger taps elsewhere
- **THEN** the 1-finger gesture fires

#### Scenario: Palm on the bottom edge outside the corner
- **GIVEN** the thumb corner is *Bottom left* and a thumb is anchored
- **WHEN** a contact lands 1 mm from the bottom edge in the middle of the pad and lifts quickly
- **THEN** no gesture fires

#### Scenario: Contact near a side edge low on the pad
- **GIVEN** the thumb corner is *Bottom left* and a thumb is anchored
- **WHEN** one finger taps 1 mm from the right edge, 70% of the height down from the top
- **THEN** the 1-finger gesture fires

#### Scenario: Swap with the thumb hugging the bottom edge in the corner
- **GIVEN** the thumb corner is *Bottom left*, the swap setting is on, and two fingers rest outside the corner
- **WHEN** the thumb taps 1 mm from the bottom edge and 10 mm from the left edge
- **THEN** the swap happens

### R5. Top corners keep today's palm band
With a top corner chosen, a contact landing closer than 3 mm to the bottom edge anywhere along it, or closer than 3 mm to the edge opposite the thumb and more than 40% of the height down from the top, MUST be an edge contact.

#### Scenario: Palm in the bottom-left of the pad with a top-left thumb
- **GIVEN** the thumb corner is *Top left* and a thumb is anchored
- **WHEN** a contact lands 1 mm from the bottom edge, 10 mm from the left edge, and lifts quickly
- **THEN** no gesture fires

#### Scenario: Palm on the opposite edge low on the pad with a top-left thumb
- **GIVEN** the thumb corner is *Top left* and a thumb is anchored
- **WHEN** a contact lands 1 mm from the right edge, 70% of the height down, and lifts quickly
- **THEN** no gesture fires

### R6. Illustrations draw the thumb in the chosen corner
Every illustration in the settings window MUST show the thumb in the chosen corner: the five gesture rows, *Switch recent*, *Switch windows* and *Toggle recent*. Bottom-corner illustrations are the top-corner ones with their marks flipped top to bottom, on the same paper card with the same lighting.

#### Scenario: Bottom-right illustrations
- **GIVEN** the thumb corner is *Bottom right*
- **WHEN** the user looks at the settings window
- **THEN** every illustration shows the thumb's mark in the bottom-right of its card

#### Scenario: Switching corners redraws the illustrations
- **GIVEN** the settings window is open with *Top left*
- **WHEN** the user picks *Bottom left*
- **THEN** every illustration shows the thumb's mark bottom-left at once

### R7. The guide shows only for the top-left corner
The *Hold* / *Tap* guide over the first illustration MUST show only while the thumb corner is *Top left*. Today it shows only for *Left thumb*, the top-left corner; *Top right* and the bottom corners show none.

#### Scenario: Guide hidden for a bottom corner
- **GIVEN** the thumb corner is *Bottom left*
- **WHEN** the user opens the settings window
- **THEN** no guide shows over the 1-finger gesture's illustration

#### Scenario: Guide hidden for the top-right corner
- **GIVEN** the thumb corner is *Top right*
- **WHEN** the user opens the settings window
- **THEN** no guide shows

#### Scenario: Guide shown for the top-left corner
- **GIVEN** the thumb corner is *Top left*
- **WHEN** the user opens the settings window
- **THEN** the guide shows over the 1-finger gesture's illustration

### R8. Saved choices migrate
An existing saved *Left thumb* MUST load as *Top left*, and *Right thumb* as *Top right*.

#### Scenario: Upgrading with the right thumb chosen
- **GIVEN** a user who saved *Right thumb* in an earlier version
- **WHEN** they upgrade and Trackpad Launcher starts at login
- **THEN** the thumb anchors top-right with no window opened
- **WHEN** the user opens the settings window
- **THEN** the pop-up shows *Top right*

### R9. A first run defaults to the top-left corner
A first run MUST default to *Top left*.

#### Scenario: First run
- **GIVEN** no saved settings
- **WHEN** Trackpad Launcher starts
- **THEN** the thumb anchors top-left and the pop-up shows *Top left*

### R10. The choice survives a relaunch
The chosen thumb corner MUST survive a relaunch.

#### Scenario: A bottom corner survives a relaunch
- **GIVEN** the user picked *Bottom right*
- **WHEN** Trackpad Launcher quits and starts again
- **THEN** the thumb anchors bottom-right and the pop-up shows *Bottom right*

### R11. A downgrade keeps the other settings
After a downgrade to a version without bottom corners, every other setting MUST survive: app assignments and every switch. A saved bottom corner MUST load there as the top corner on the same side.

#### Scenario: Downgrading with a bottom corner chosen
- **GIVEN** the user picked *Bottom right* and assigned apps to gestures
- **WHEN** they install an older version without bottom corners
- **THEN** their app assignments and switches are unchanged
- **AND** the older version anchors the thumb top-right

## Non-goals

- **New illustration artwork for bottom corners.** Flipping the existing marks gives the right picture without design work.
- **Moving anything on screen with the corner.** The switcher stays centred on the display, and the window switcher stays top-left.
- **A resizable or tunable corner.** The anchor corner stays a fixed zone, as today.
- **Keeping a bottom corner after a downgrade.** An older version knows only the top corners.
- **A side-edge palm band for bottom corners.** With the thumb in a bottom corner, the heel of the hand rests below the trackpad, not along a side edge.

## Documentation

The product overview's sentence on the two hand modes (top left in right hand mode, top right in left hand mode) is rewritten for the four thumb corners. So are the glossary's *Hand mode* (renamed *Thumb corner*), *Anchor corner* and *Edge contact* entries, and the four entries that mention hand modes in passing: *Settings window*, *Switcher*, *Window switcher* and *Pick animation*.

## Implementation Decisions

- **One domain type, `ThumbCorner`, replaces `HandMode` everywhere.** A public core enum with four cases in the pop-up's order, `topLeft`, `topRight`, `bottomLeft`, `bottomRight`, `CaseIterable` in that order, `Hashable` and `Sendable`, and deliberately not `Codable`: the saved shape is the settings record's concern alone (next decision), so nothing can persist the corner by accident under a value an older build would refuse. Its geometry queries are package-internal and are the three the recognizer needs: whether the corner is a bottom one (the palm band's key), how far a normalised x lies from the corner's side edge, as a fraction of the width, and how far a normalised y lies from the corner's top or bottom edge, as a fraction of the height. `HandMode` is deleted as a public type; the model exposes `thumbCorner` and `setThumbCorner(_:)` in place of `handMode` and `setHandMode(_:)`, the recognizer and the trackpad port take `corner:` in place of `handMode:`, and the reconcile's `Run` compares the corner. A corner change re-runs the trackpads with fresh recognizers exactly as a hand-mode change does today, ending any swipe in progress; a thumb already down is judged on the fresh recognizer's first frame, as after any settings change (the domain model's *Thumb touch* and *Blocking window*), which is what R1's last clause now says.

- **The saved record keeps the old key and adds one the old build ignores.** The settings record's decoding rule is unchanged: a missing key decodes as the default, an unknown key is ignored, a value that does not decode fails the whole record. A four-value enum under the existing `handMode` key would break that for a downgrade: 1.0.6 fails the whole record on a raw value it does not know and loads every assignment as unassigned. So the corner is stored as two fields, both private to the record, with `thumbCorner` a computed property over them: the side under the key `handMode` with the values `right` and `left` exactly as every version has written them (the hand, so `right` is the thumb on the left side), and `isThumbAtBottom`, a `Bool` under a new key, absent in every record written so far and read as `false`. This gives R8, R9, R10 and R11 by the existing rule with no migration code: an old record has only the side, so *Left thumb* loads as *Top left* and *Right thumb* as *Top right*; no record is the defaults, *Top left*; a downgraded build reads the side, ignores the new key and anchors in the top corner on that side, every other setting intact. The record's synthesized encoding is kept; its custom decoder reads the new key with `decodeIfPresent` like every other field.

- **The anchor corner is the same zone measured from the chosen corner's two edges.** `admits` is "less than 20% of the width from the corner's side edge and less than 25% of the height from the corner's top or bottom edge"; `holds` is the same zone grown by the 2 mm release margin on both sides. `cornerHeight`'s description changes from "measured from the top edge" to "from the corner's top or bottom edge"; no number changes. Slide travel is already independent of the corner (positive to the right and positive downwards by construction), so R3's directions hold with no change; the tests prove it for the bottom corners.

- **The palm band is one rule keyed by the corner's row.** For a top corner, today's band: closer than 3 mm to the bottom edge anywhere along it, or closer than 3 mm to the side edge opposite the thumb and more than 40% of the height down. For a bottom corner: closer than 3 mm to the bottom edge and at least 20% of the width from the corner's side edge, so the strip stops where the anchor corner begins; no side edge is in the band. A landing inside the anchor corner is never an edge contact, so a thumb hugging the bottom edge in its corner anchors. The band is decided at landing, as today; the edge-contact bookkeeping (which contacts are palms while down) is untouched. `edgeBandTop`'s description says it applies to top corners.

- **The settings window's thumb picker becomes a row with a pop-up.** The segmented control goes; its group stays and holds one row: the title *Thumb corner* at the leading edge and, at the trailing edge, the system's pop-up button (SwiftUI's menu-style picker, which is AppKit's pop-up button on macOS) at the regular size with its own label hidden, listing the four corners in `ThumbCorner.allCases` order and showing the current one. The row's title and the four item titles (*Top left*, *Top right*, *Bottom left*, *Bottom right*) live in `Copy`, so they are tested as values. The pop-up's accessibility label is *Thumb corner*. The guide over the first illustration shows exactly when the corner is `topLeft`; the view's guide rule becomes a one-line rule on the corner inside the UI module so it is tested as a value, beside the illustration-name rule below.

- **Bottom-corner illustrations are derived files, named by corner, drawn by the existing script generalised.** Four resource names per illustration: the Figma original (top-left), the existing `-inverse` copy (top-right), and two new copies, `-bottom` (bottom-left: the original's marks mirrored top to bottom) and `-bottom-inverse` (bottom-right: mirrored both ways), 16 new PNGs beside the 16 that exist, at the same pixel size and DPI. The script that draws the left-hand copies is generalised to draw all three derived copies of each original by the same method (mirror the marks' coverage onto the infilled card, so the card and its lighting are untouched) with the mirror applied in x, in y or both, its "a mark falls off the card" check applied in every direction, and renamed to say so. Its outputs are committed as today's `-inverse` files are, and regenerated only when a Figma original changes. The illustration view maps the corner to the suffix with one rule in the UI module; a missing resource still draws nothing rather than failing.

- **Test helpers follow the rename, with two small additions.** The recognizer fixtures (`fired`, `phases`, `windowPhases`, `swaps`, `perFrame`) and the edge-contact suite's private per-frame helper, which today hard-codes the right hand, take `corner:` defaulting to `topLeft`; the two travel-direction tests' parameter tuples carry a thumb point in place of a thumb x; the World's `swipe` and `swap` gain `thumbAtMM:` as `tap` and `windowSwipe` already have, so bottom-corner rows read like their top-corner twins; the persistence fixtures and the lifecycle world take the corner (or, where they build a raw record, the wire string) in place of the hand mode. Every existing test that names a hand mode is updated mechanically: `.right` is `topLeft`, `.left` is `topRight`; no existing assertion changes.

- **Documentation.** The product overview's sentence on the two hand modes and the domain model's *Hand mode* (now *Thumb corner*), *Anchor corner*, *Edge contact*, *Settings window*, *Switcher*, *Window switcher* and *Pick animation* entries are rewritten for four corners; the code comments that say "in both hand modes" say "whatever the thumb corner".

## Testing Decisions

### Strategy

Four seams, all existing, from the one most rows use down.

- **The recognizer over scripted frames**, through the fixtures `fired`, `phases`, `windowPhases`, `swaps` and `perFrame` with `TouchScript` and `HandFrames` (`LauncherKit/Tests/LauncherCoreTests/GestureRecognizerTests.swift`, `EdgeContactRecognizerTests.swift`, `SwipeTravelAndExitTests.swift`, `WindowSwipeRecognizerTests.swift`): the real `GestureRecognizer`, `AnchorCorner` and `EdgeContacts` over frames given in millimetres. It observes what fired, every slide phase and the per-frame blocking level; it misses the model's effects. R2, R4 and R5 live here, and R3's directions and blocking.
- **The World over `InMemoryTrackpads`** (`LauncherTests.swift`, `SwapTests.swift`, `SwitcherOnScreenTests.swift`, `WindowSwitcherOnScreenTests.swift`, `ClickBlockingTests.swift`, `ScrollSuppressionTests.swift`, `PersistenceTests.swift`, with `World.swift`): the real `Launcher`, recognizer, `TapFilters` and `SettingsStore` over a throwaway `UserDefaults` suite. It observes brought-to-front, pulses, press and scroll verdicts, the switchers, `thumbCorner`, the window, and the saved record's bytes; it misses the views. R1, R3's effects, R8, R9, R10 and R11 live here.
- **Values** (`CopyTests.swift`, `PersistenceTests.swift`): the pop-up's titles and order, and the two-key wire shape read back with `PropertyListSerialization` and with a replica of 1.0.6's decoder kept in the test as a fixture.
- **The UI module's rules and the shipped PNGs** (`LauncherKit/Tests/LauncherUITests/PickAnimationRuleTests.swift` is the model): the corner-to-suffix rule and the guide rule as values, and the files under `assets/`, read from disk by a path from `#filePath` as the source-scan test finds the package.

Faked, exactly as every World row fakes them today: the trackpads, the preferences, the permissions and the system actions, in memory; the settings in a throwaway suite. Nothing new is faked: the illustrations are the real files, and the 1.0.6 decoder replica is a fixture, not a fake.

What no test observes is the view wiring: that the pop-up's binding reads and writes `thumbCorner`, that the illustrations and the guide read the corner through their rules, and that a change redraws them at once. T3, T23 and T24 prove the rules; the wiring is a few lines of SwiftUI checked by the slices' manual criteria.

Every new row states what the code reads before it, so each is a failing test first, except T22, T26 and T9's and T10's top-corner rows, which are today's tests re-expressed and pin the "unchanged" clauses. The rest of the suite staying green after the rename proves every "exactly as in a top corner" clause for the top corners.

### Test scenarios

Unless a row says otherwise: the surface is `.macBook14` (124.8 × 76.8 mm; the corner is 24.96 mm wide and 19.2 mm tall, so a bottom corner starts 57.6 mm from the top); points are millimetres from the top-left as `TouchScript` takes them; "the bottom-left thumb" is at (10, 66.8) and "the bottom-right thumb" at (114.8, 66.8), each 10 mm from its two edges; a tap lands at (62, 45) unless placed; a World is `World(apps: ["Arc"])`, started, with Arc on the 1-finger gesture. "Before" says what today's code does.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | World | Given the default world: `thumbCorner == .topLeft`. When `s1 = thumb(atMM: (10, 10)).tap(fingers: 1)` is played: `broughtToFront == [Arc]`. When, the thumb still down, `setThumbCorner(.bottomRight)`: `thumbCorner == .bottomRight` and `runCount` rose by one. When `s2 = s1.wait(.milliseconds(20)).tap(fingers: 1)` is played on (so the fresh recognizer's first frame holds the top-left thumb alone, then one more tap): still `[Arc]`. When `s3 = s2.liftThumb().thumb(atMM: (114.8, 66.8)).tap(fingers: 1)` is played on: `[Arc, Arc]`, `feedback.count == 2`. When `s3.liftThumb().thumb(atMM: (10, 10)).tap(fingers: 1)` is played on: still `[Arc, Arc]`. And, in a fresh default world: when `r1 = thumb(atMM: (114.8, 66.8))` is played (a plain contact resting in the bottom-right under *Top left*), then `setThumbCorner(.bottomRight)`, then `r1.wait(.milliseconds(20)).tap(fingers: 1)` is played on: `broughtToFront == [Arc]`, the contact having anchored on the fresh recognizer's first frame. Before: `setThumbCorner` does not exist. | R1's first scenario, both halves of its last clause; `LauncherTests.handModeDefaultsToRightAndSwitchingMovesTheCorner`, its two-corner twin; the domain model's *Thumb touch* ("Recognition restarting mid-touch … starts a thumb touch only if a thumb is in the corner on its first frame") and *Blocking window* (a thumb already resting opens no window but anchors). |
| T2 | R1 | World | Given a started `World()` where `setThumbCorner(.bottomLeft)` was called. When `relaunch()`, `start()`, `openedByHand()`. Then `thumbCorner == .bottomLeft` and `isWindowOpen`. Before: no such setting. | R1's second scenario ("the pop-up shows *Bottom left*"). |
| T3 | R1 | Values | `ThumbCorner.allCases == [.topLeft, .topRight, .bottomLeft, .bottomRight]`; `allCases.map(Copy.thumbCornerTitle) == ["Top left", "Top right", "Bottom left", "Bottom right"]`; `Copy.thumbCornerRow == "Thumb corner"`. Before: none of the three exists. | R1's text: the row's name, the four choices "in that order". |
| T4 | R2 | Recognizer | Given `corner: .bottomLeft`. When the bottom-left thumb lands and one finger taps. Then `fired == [.one]`. Before: nothing fires (the corner is top-left). | R2's first scenario (10 mm from the left edge and from the bottom edge). |
| T5 | R2 | Recognizer | Given `corner: .bottomRight` on `SurfaceSize(widthMM: 120, heightMM: 80)`. When a thumb lands at (110, 55) (10 mm from the right edge, 25 mm from the bottom) and one finger taps: `fired == []`. When a thumb lands at (110, 70) (10 mm from the bottom) and one finger taps: `[.one]`. Before: `[]` for both. | R2's second scenario (an 80 mm pad: the corner is 20 mm tall, so 25 mm out is outside and 10 mm in is inside). |
| T6 | R2 | Recognizer | Parameterised over every corner × every thumb spot in {(10, 10), (114.8, 10), (10, 66.8), (114.8, 66.8)}: a thumb at the spot and one finger tapping fire `[.one]` exactly when the spot's corner is the chosen corner, `[]` otherwise (16 rows). Before: the bottom cases do not compile. | R2's third scenario and "a contact anywhere else MUST NOT anchor"; `GestureRecognizerTests.leftHandAnchorsInTheTopRightCorner`, the two-corner version. |
| T7 | R2 | Recognizer | Given `corner: .bottomLeft`: a thumb at (24, 66.8) fires, at (26, 66.8) not; at (10, 58.8) (18 mm from the bottom) fires, at (10, 56.8) (20 mm) not. Given `.bottomRight` on `.magicTrackpad` (160 × 115): (150, 105) fires, (150, 85) (30 mm from the bottom; the corner is 28.75 mm tall) not. Before: none fire. | R2's "20% of the width from that side edge and 25% of the height from the bottom edge"; the literals mirror `GestureRecognizerTests.cornerIsTwentyPercentByTwentyFivePercentOfTheSurface` (24/26, 18/20) about the bottom edge. |
| T8 | R2 | Recognizer | Given `.bottomLeft` and the bottom-left thumb anchored. When it rolls to (10, 56.6) (1 mm above the corner's top boundary at 57.6) and one finger taps: `[.one]`. When instead it rolls to (10, 54.6) (3 mm above): `[]`. Sideways: rolls to (26, 66.8) (1 mm past the width): `[.one]`; to (28, 66.8) (3 mm): `[]`. Before: nothing fires. | R2's fourth and fifth scenarios; the 2 mm release margin. |
| T9 | R3 | Recognizer | `SwipeTravelAndExitTests.travelIsInTrackpadMillimetresAndPositiveToTheRight…` gains four rows: `.bottomLeft` and `.bottomRight` on `.macBook14` (thumbs at (10, 66.8), (114.8, 66.8)) and on `.magicTrackpad` (thumbs at (10, 105), (150, 105)): after the 3.5 mm begin, a 12 mm slide right ends at `.moved(travelMM: 12.35)` and a 12 mm slide left at `.moved(travelMM: -11.65)`, as the existing four rows do. Before: no phases at all from a bottom thumb. | R3's "sliding right reaches older apps … directions MUST stay the same"; the existing rows' literals. |
| T10 | R3 | Recognizer | `WindowSwipeRecognizerTests.travelIsInTrackpadMillimetresAndPositiveDownwards…` gains the same four bottom-corner rows with the test's existing expectations for a slide down and a slide up, and no swipe phases. Before: no window-swipe phases from a bottom thumb. | R3's "up and down drive the window swipe as today"; the existing rows' literals. |
| T11 | R3 | World | Given `World.switcherWorld()` with `setThumbCorner(.bottomRight)`. When `swipe(3.5, 12, thumbAtMM: (114.8, 66.8))`. Then `broughtToFront == [Mail]`, `feedback == [macBook14]`, `switcher == nil`. When, in a fresh such world, the same slide with the thumb at (114.8, 10). Then nothing happened. Before: nothing happens from (114.8, 66.8). | R3's first scenario; `SwitcherOnScreenTests.leftHandedTheSameSlideRightReachesTheSameNextApp` (Mail is the next older app). |
| T12 | R3 | World | Given `World.switcherWorld()` with `.bottomLeft`. When `swap(thumbAtMM: (10, 66.8))`. Then `broughtToFront == [Mail]`, `pulses.count == 1`. When, in a fresh switcher world left at `.topLeft`, `swap(thumbAtMM: (10, 66.8))`. Then nothing happened. Before: nothing happens. | R3's second scenario; `SwapTests.leftHandSwapsFromTheTopRightCornerOnly`. |
| T13 | R3 | World | Given `World.windowWorld(visible: ["Docs", "Mail"])` with `.bottomLeft`. When `windowSwipe(3.5, 12, lift: false, thumbAtMM: (10, 66.8))`. Then the titles are `["Docs", "Mail"]`, the selected row is 1, `lightTicks.count == 1`, `windows.raised == [[Mail]]`. Before: no window switcher. | R3's third scenario; `WindowSwitcherOnScreenTests.leftHandedTheSameSlideDownReachesTheNextWindow` and `WindowSwitchingTests` (`raised == [[Mail]]`). |
| T14 | R3 | World | Given `World.switcherWorld(accessGranted: true)` with `.bottomRight` and `hand = thumb(atMM: (114.8, 66.8)).land(fingers: 2)`. When `hand` is played: `scroll(.fingers(.mayBegin)) == .drop`. When `hand.slide(byMM: (3.5, 0)).slide(byMM: (12, 0))`: `scroll(.fingers(.changed)) == .drop`. When `.lift()` is added: `scroll(.fingers(.ended)) == .drop`, `scroll(.momentum(.began)) == .drop`, `broughtToFront == [Mail]`, then `scroll(.fingers(.began)) == .pass`. Before: every offer reads `.pass` and nothing is brought to front. | R3's "scroll suppression"; `ScrollSuppressionTests.aSwipeFromAFreshThumbDropsScrollingBeforeDuringAndAfterTheSwitcher`, verbatim with the thumb moved. |
| T15 | R3 | World | Given `World(apps: ["Arc"], accessGranted: true)` with `.bottomLeft`, Arc on 1. When `thumb(atMM: (10, 66.8)).tap(fingers: 1, click: .firm)`. Then `broughtToFront == [Arc]`, `pressVerdicts == [.drop, .drop]`, `feedback == [macBook14]`. Before: `[.pass, .pass]` and nothing opens. | R3's "click blocking … and the haptic feedback"; `ClickBlockingTests.aFirmTapOpensItsAppAndTheWholePressNeverReachesApps`. |
| T16 | R3 | Recognizer | Given `.bottomLeft` through the edge-contact suite's per-frame helper (the one that reports both blocking flags), the bottom-left thumb from 0 ms and a finger at (62, 45) from 100 ms to 4100 ms, sampled at 0, 100, 1000, 2990, 3010, 4000 and 4100 ms. Then `blocksClicks` reads `[false, true, true, true, false, false, false]` and `blocksDockSwipes` `[false, true, true, true, true, true, false]`. Before: all false. | R3's "click blocking … Dock swipe blocking"; `EdgeContactRecognizerTests.aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad`, the same sample times and verdicts. |
| T17 | R4 | Recognizer | Given `.bottomLeft`. When a thumb lands at (10, 75.8) (1 mm from the bottom, 10 mm from the left) and one finger taps: `[.one]`. Given `.bottomRight`: a thumb at (114.8, 75.8): `[.one]`. Before: `[]` (the landing is an edge contact). | R4's first scenario. |
| T18 | R4 | Recognizer | Given `.bottomLeft` with the bottom-left thumb anchored, parameterised over x in {25.0, 62.4, 123.8}: a one-finger tap at (x, 75.8) fires nothing, and a following tap at (62, 45) fires, so `fired == [.one]`. The same for `.bottomRight` with the bottom-right thumb and x in {1.0, 62.4, 99.8}. Before: `[]` throughout, since no bottom thumb anchors. 25.0 and 99.8 sit 0.04 mm past the corner's width, so these rows pin the corner-wide exclusion. | R4's second scenario ("1 mm from the bottom edge in the middle of the pad"); R4's "outside the anchor corner"; the existing `aTapLandingInTheBottomEdge…` rows' shape. |
| T19 | R4 | Recognizer | Given `.bottomLeft` with the bottom-left thumb anchored: a one-finger tap at (123.8, 53.76) (1 mm from the right edge, 70% down) fires `[.one]`; at (1.0, 53.76) (1 mm from the left edge, 70% down, above the corner) `[.one]`; at (123.8, 23.04) `[.one]`. The same three for `.bottomRight` with the bottom-right thumb. Before: `[]` throughout, since no bottom thumb anchors. | R4's third scenario; "The side edges MUST NOT be part of the band". |
| T20 | R4 | World | Given `World.switcherWorld()` with `.bottomLeft`. When `swap(thumbAtMM: (10, 75.8))`. Then `broughtToFront == [Mail]`. Before: nothing happens. | R4's fourth scenario. |
| T21 | R4 | Recognizer | Given `.bottomLeft` with the bottom-left thumb anchored. When a finger at (62, 45) and a contact at (62.4, 75.8) land together and lift together: `fired == [.one]`, not `.two`. When a finger at (62, 45) and a contact at (70, 75.8) land together and both slide 20 mm right: no swipe phases and nothing fires. Before: `[]` and no phases (nothing anchors). | R4's "it neither starts nor joins a tap, a swipe or a swap"; the inverse of `EdgeContactRecognizerTests.aFingerAtTheTopEdgeCountsInATwoFingerTap`; `aFingerAndAnEdgeContactSlidingUpTogetherAreNoWindowSwipe`'s shape. |
| T22 | R5 | Recognizer | `EdgeContactRecognizerTests`' parameterised rows re-expressed with corners (`.right` → `.topLeft`, `.left` → `.topRight`) plus one row: with `.topLeft` and the thumb at (10, 10), a tap at (10, 75.8) fires nothing and the next tap at (62, 45) fires, `[.one]`. R5's second scenario is the existing row (123.8, 53.76). Holds today. | R5's two scenarios; the existing rows' literals (1.0/123.8 at 53.76; 75.8 along the bottom; 3 mm on every size). |
| T23 | R6 | UI module + files | For each of the eight illustration names and each corner: the suffix rule gives `name`, `name-inverse`, `name-bottom`, `name-bottom-inverse` for `topLeft`, `topRight`, `bottomLeft`, `bottomRight`; the file `assets/<result>.png` exists and has the original's pixel size. With the original and the derived file decoded the way the script decodes them, and the mark mask being the pixels of luminance below 180 inside a 5 px rim, grown by 2 px (the script's own definition): every pixel outside the union of the original's mask and that mask mirrored (in x for a right corner, in y for a bottom corner, both for bottom-right) equals the original's within 1 per channel, so the card and its lighting are untouched; and the derived file's mask equals the original's mask mirrored, differing in fewer than 1% of the mask's pixels (threshold pixels at the marks' edges). The `-inverse` files are checked the same way. Before: the `-bottom` rule and files do not exist. | R6's "the top-corner ones with their marks flipped top to bottom, on the same paper card with the same lighting"; R6's scenario ("the thumb's mark in the bottom-right of its card"); the originals as fixtures and the script's mark definition (180, 5 px, 2 px). |
| T24 | R7 | UI module | The guide rule reads true for `.topLeft` and false for `.topRight`, `.bottomLeft` and `.bottomRight`. Before: the rule is on `HandMode`. | R7's three scenarios. |
| T25 | R8 | World | Given the record a released build wrote, `PersistenceTests.savedSettings` (`handMode` = `left`, Arc on 1, Figma on 2, Spotify on 5, animation off, swipe off; it predates the swap and window-swipe keys), seeded with its apps registered. When `relaunch()` and `start()` (a login start). Then `!isWindowOpen`, `thumbCorner == .topRight`, the rows and switches as the existing test asserts; a tap with the thumb at (114.8, 10) brings Arc to front and one at (10, 10) brings nothing more. When `openedByHand()`. Then `isWindowOpen` and `thumbCorner == .topRight`. And a `recordSavedByPlan002` built with the wire string `right` loads as `.topLeft`. Before: `.left`/`.right` under the old type. | R8's scenario ("the thumb anchors top-right with no window opened … the pop-up shows *Top right*"); the fixture is a record a released build wrote; T29 covers the record with all of 1.0.6's keys. |
| T26 | R9 | World | Given `World(apps: ["Arc"])` with no record. When `start()` and `openedByHand()`. Then `thumbCorner == .topLeft`, and with Arc assigned a tap with the thumb at (10, 10) brings Arc to front. (`PersistenceTests.firstRunShowsFreshDefaults…` and `anEmptyRecordDecodesAsDefaults…` assert `.topLeft`.) Holds today under the old name. | R9's scenario. |
| T27 | R10 | World | Given the default world with `setThumbCorner(.bottomRight)`. When `relaunch()` and `start()`. Then `thumbCorner == .bottomRight`; a tap with the thumb at (114.8, 66.8) brings Arc, at (114.8, 10) nothing more; after `openedByHand()` still `.bottomRight`. And `everySettingsFieldSurvivesTheStore` with `thumbCorner = .bottomRight`, plus each of the four corners saved and loaded back equal. Before: no such setting. | R10's scenario. |
| T28 | R11 | World + values | Given `World(apps: ["Arc", "Figma"])`, started, Arc on 1, Figma on 2, `setLaunchAnimation(on: false)`, `setSwipe(on: false)`, `setSwap(on: false)`, `setWindowSwipe(on: true)`, `setThumbCorner(.bottomRight)`. Then the saved bytes read through `PropertyListSerialization` hold `handMode` = `"left"`, `isThumbAtBottom` = `true`, `isLaunchAnimationOn` = `false`, `isSwipeOn` = `false`, `isSwapOn` = `false`, `isWindowSwipeOn` = `true`, and assignments `"1"` and `"2"` with Arc's and Figma's bundle IDs; and decoded with a replica of 1.0.6's `Settings` decoder kept in the test (`handMode` as a `right`/`left` enum via `decodeIfPresent`, the six other keys as 1.0.6 reads them, unknown keys ignored) they give `handMode == .left`, both assignments and the four switches as set. With `.bottomLeft` instead, `handMode` = `"right"`. Before: no bottom corner can be saved. | R11's scenario; the current `Settings.init(from:)`, which is the 1.0.6 decoder, reproduced as the fixture. |
| T29 | R8, R10 | Values | A record holding only `isThumbAtBottom` = `true` loads as `thumbCorner == .bottomLeft` with every other field default; only `handMode` = `left` loads as `.topRight`; both as `.bottomRight`; neither as `.topLeft`; a record holding all seven of 1.0.6's keys (encoded through T28's replica made `Codable`) with `handMode` = `left` and no `isThumbAtBottom` loads as `.topRight` with the other six as written; `isThumbAtBottom` holding a string fails the whole record, which loads as `Settings()`. Before: the key is unknown and ignored. | The record's decoding rule (missing = default, unknown = ignored, undecodable = the whole record fails); `PersistenceTests.aRecordHoldingOnlyTheSwapKeyLoads…`'s shape; R8's "an existing saved *Right thumb* MUST load as *Top left*". |
| T30 | R4 | Recognizer | Given `.bottomLeft`, a finger resting at (62, 45) and a contact resting at (62, 75.8) from 0 ms (the second is an edge contact). When the bottom-left thumb taps at 150 ms for 120 ms. Then `swaps == []`: one finger rests, not two. Given instead fingers resting at (62, 45) and (70, 45) and a contact at (62.4, 75.8), the same thumb tap: `swaps == [true]`: the edge contact is not a third finger. Before: `[]` for both (no bottom thumb anchors); without the band the first would read `[true]`. | R4's "it neither starts nor joins … a swap"; the domain model's *Swap* ("exactly two fingers rest outside the anchor corner (edge contacts aside)"); `EdgeContactRecognizerTests.aFingerRestingAtTheTopEdgeCountsForASwap`'s shape. |

### Verified without a test

None.

## Further Notes

- **R1's last clause was amended during planning.** It read "a thumb already anchored keeps working until it lifts", which no settings change does today: every change re-runs the trackpads with fresh recognizers, and the domain model's *Thumb touch* and *Blocking window* entries define what a thumb already down then is. Keeping a thumb anchored across a corner change would need a second writer to the recognizer the frame thread owns, for a moment no user is in (the pointer is on the pop-up). The clause now says the thumb is judged afresh; T1 proves it.
- **Why two stored fields rather than a four-value `handMode`.** The downgrade (R11) is the whole reason: 1.0.6 fails the entire record on a `handMode` value it does not know and loads with every assignment gone. The two keys cost nothing at runtime and no migration code, and the computed `thumbCorner` keeps the rest of the model ignorant of the shape.
- **Why re-run rather than retarget.** A corner change ends a swipe in progress exactly as the swipe, window swipe, swap and hand-mode changes do today; the reconcile is the one convergent operation and gains no second path.
- **The pop-up.** SwiftUI's menu-style picker is AppKit's pop-up button, so the row looks like System Settings' own; the app picker keeps its hover-bezel style, which belongs to a control whose content is an icon and a name. If the two sit uneasily in the same window, the corner pop-up can take the app picker's bezel rule in a later change; nothing in the model depends on it.
- **Assets.** The 16 new PNGs are committed outputs of the script, as the 8 `-inverse` files are; the script runs by hand when a Figma original changes. T23 compares each derived file with its original both outside the marks (the card, which must be untouched) and in the marks' mask (which must be the mirror), so a missing, stale, hand-copied or whole-image-flipped asset cannot ship silently.
- **S2 and S3 ship together.** After S2 alone a bottom corner shows the top-corner pictures, which breaks R6; S2 is a reviewable step, not a release.
- **Out of scope, unchanged.** The switcher's and window switcher's placement, the corner's size, the blocking rules and the lift window.

## Slices

### S1: `HandMode` becomes `ThumbCorner`, two corners, nothing else changes

**What to build:** A prefactor with no behaviour change. The domain type is renamed and reshaped to the corner it names, `topLeft` and `topRight` only; the settings record stores the side as today under the `handMode` key and exposes `thumbCorner` as a computed property; the model, the recognizer, the port, both adapters, the views, the test fixtures (`corner:` with a `topLeft` default; the World's `swipe` and `swap` gain `thumbAtMM:`) and every existing test follow the rename. The Debug build behaves exactly as before, the segmented control included.

**Blocked by:** None (can start immediately).

**Requirements:** None delivered; makes R1 to R11 a small change.

**Test scenarios:** None new; the whole suite stays green.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-data`.

- [ ] `swift test` is green with every existing assertion unchanged in meaning (`.right` → `.topLeft`, `.left` → `.topRight`).
- [ ] A grep for `HandMode` finds only the settings record's private wire type and its decoder.
- [ ] The saved record a Debug build writes after this slice is what it wrote before for the same settings (`handMode` = `right`/`left`, no new key): `PersistenceTests.settingsSavedInTheCurrentFormatStillLoad` and `everySettingsFieldSurvivesTheStore` stay green.

### S2: Four thumb corners, chosen from the pop-up, with gestures and the palm band in the bottom corners

**What to build:** The user opens the settings window, sees the *Thumb corner* row with its pop-up showing the current corner, picks *Bottom left* or *Bottom right*, and from the next thumb every gesture, swipe, window swipe and swap works from that corner with the same click, scroll and Dock swipe blocking and haptics; the bottom edge outside the corner is the palm band and the side edges are not; the guide shows only for *Top left*; the choice survives a relaunch, an old record loads as its top corner, and a downgrade keeps every other setting. The illustrations still show the top-corner pictures in this slice (S3 adds the bottom ones). The product overview and the code comments are rewritten.

**Blocked by:** S1.

**Requirements:** R1, R2, R3, R4, R5, R7, R8, R9, R10, R11.

**Test scenarios:** T3, T6, T4, T5, T7, T8, T17, T18, T19, T21, T30, T22, T9, T10, T16, T1, T2, T11, T12, T13, T14, T15, T20, T24, T26, T25, T29, T27, T28.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-data`, `macos-dev-workflow:swift-testing-pro`.

- [ ] `swift test` is green, every T row above included.
- [ ] Manual, on the Debug build: the group that held the segmented control shows one row, *Thumb corner*, with a pop-up listing *Top left*, *Top right*, *Bottom left*, *Bottom right* in that order and showing the current one; picking each redraws nothing else and the guide shows only for *Top left*.
- [ ] Manual, on the built-in trackpad with *Bottom left*: the five gestures fire from the bottom-left corner, a thumb hugging the bottom edge in the corner anchors, a palm on the bottom edge in the middle of the pad is ignored, a finger 1 mm from the right edge low on the pad taps, a swipe right reaches older apps, a slide down switches windows, a thumb tap under two resting fingers swaps; with Accessibility on, a firm tap under the thumb opens its app without a click. The same with *Bottom right*. Then *Top left* again: a palm in the bottom-left of the pad is ignored.
- [ ] Manual, on the Debug build: quit and reopen with a bottom corner chosen: the pop-up shows it and the thumb anchors there.
- [ ] Manual downgrade, on a Release-configuration build of this branch (the perf build, which keeps the release's bundle identifier and so shares the release's settings; a Debug build keeps its own and would prove nothing) installed in /Applications: pick *Bottom right*, assign apps, flip a switch; install release 1.0.6 over it and open it: its segmented control shows *Right thumb*, every app assignment and switch is as it was. Change nothing in 1.0.6 (keeping the bottom corner across a downgrade is a non-goal).
- [ ] The product overview's hand-mode sentence is rewritten for four corners; the domain model's entries, rewritten during planning, are re-read against the code as built and corrected where they differ; no code comment says "hand mode".

### S3: The illustrations draw the thumb in the chosen corner

**What to build:** With a bottom corner chosen, every illustration in the settings window, the five gesture rows, *Switch recent*, *Switch windows* and *Toggle recent*, shows the thumb dot in that corner of its card, flipped top to bottom from the top-corner picture on the same card with the same lighting, and switching corners redraws them at once. The script that draws the derived copies is generalised and renamed, the 16 new PNGs are committed, and the view maps the corner to its file.

**Blocked by:** S2.

**Requirements:** R6.

**Test scenarios:** T23.

**Skills:** `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:swift-testing-pro`.

- [ ] Running the renamed script from the repository root rewrites all 24 derived files from the 8 originals and reports each; the 8 `-inverse` files it writes decode to the same pixels as the committed ones (T23's reader, or `git diff --stat` showing them unchanged if the encoder is byte-stable), so the generalisation changed nothing for the top-right corner.
- [ ] `swift test` is green, T23 included.
- [ ] Manual, on the Debug build: with each of the four corners chosen, all eight illustrations show the thumb's mark in that corner of the card (the ringed mark in *Toggle recent*, the filled one elsewhere), the card's shading unchanged, at 45 × 28 pt; picking another corner redraws every illustration at once; the guide still sits on the thumb for *Top left*.
