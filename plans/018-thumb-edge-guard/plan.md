# Plan: The thumb arms only when it lands fully inside the anchor corner

## Problem statement

The thumb often grazes the edge of the trackpad by accident. In right-hand mode it rests against the top or left edge, right in the anchor corner. Today any contact that lands in the anchor corner becomes the anchored thumb, even one that sits barely on the pad. The user then taps or slides with the other fingers, meaning an ordinary click, scroll or system swipe, and fires a gesture, a swipe or a swap instead. Clicks, scrolling and the system's swipes get blocked as well.

## Solution

The anchor corner gets a 3 mm dead strip along the two pad edges it touches: the top edge and the thumb-side edge. A contact that lands in that strip is an edge contact, a resting graze and not a thumb. It is ignored for as long as it stays down, just like a palm resting on the bottom edge. To arm a gesture, the user puts the thumb fully inside the corner, at least 3 mm from both edges. A thumb that is already anchored may still drift towards the edge without losing its anchoring.

## Requirements

Terms used below:
- The *anchor corner* covers the top 25% of the pad's height and 20% of its width, measured from the thumb-side edge: top-left in right-hand mode, top-right in left-hand mode.
- The *thumb-side edge* is the pad edge the anchor corner touches at its side: the left edge in right-hand mode, the right edge in left-hand mode.
- The *corner strip* is the part of the anchor corner closer than 3 mm to the top edge or to the thumb-side edge.
- The *tap window* is 400 ms. A thumb tap lifts within it.

### R1. A contact landing in the corner strip never anchors
A contact whose landing point is in the corner strip MUST NOT become the anchored thumb, so no tap, swipe or window swipe can follow it.

#### Scenario: Thumb grazing the top edge, then a two-finger tap
- **GIVEN** right-hand mode, a 1-finger gesture and a 2-finger gesture both assigned
- **WHEN** a contact lands 1 mm below the top edge, 10 mm from the left edge, and stays down, and two fingers tap in the middle of the pad
- **THEN** no gesture fires and no haptic plays

#### Scenario: Thumb grazing the left edge, then a sideways slide
- **GIVEN** right-hand mode with the swipe setting on
- **WHEN** a contact lands 2 mm from the left edge, 10 mm below the top edge, and stays down, and two fingers slide sideways in the middle of the pad
- **THEN** no switcher shows, and the app does not block the scroll; it reaches the app under the pointer

#### Scenario: Thumb grazing the top edge, then a vertical slide
- **GIVEN** right-hand mode, the window swipe setting on, and the frontmost app has two or more windows
- **WHEN** a contact lands 1 mm below the top edge inside the anchor corner and stays down, and two fingers slide up in the middle of the pad
- **THEN** no window switcher shows, and the scroll reaches the app under the pointer

### R2. A contact landing in the corner strip never swaps
A contact whose landing point is in the corner strip MUST NOT be a thumb tap, so it MUST NOT fire a swap.

#### Scenario: Edge tap under two resting fingers
- **GIVEN** right-hand mode, the swap setting on, and two fingers resting in the middle of the pad
- **WHEN** a contact lands 1 mm below the top edge inside the anchor corner and lifts within the tap window
- **THEN** no swap happens and no haptic plays

### R3. A corner-strip contact is ignored for as long as it stays down
While a contact that landed in the corner strip stays down, it MUST NOT add to a tap's finger count. It MUST NOT make the app block other fingers' clicks, scrolling or the system's trackpad swipes. It is not part of a thumb touch.

#### Scenario: A graze does not count as a finger under a real thumb
- **GIVEN** right-hand mode, a thumb anchored fully inside the anchor corner, with the 1-finger and 2-finger gestures assigned
- **WHEN** a second contact lands in the corner strip and stays down, and one finger taps in the middle of the pad
- **THEN** the 1-finger gesture fires

#### Scenario: A graze does not block clicks
- **GIVEN** right-hand mode
- **WHEN** a contact lands in the corner strip and stays down, and another finger clicks in the middle of the pad
- **THEN** the click reaches the app under the pointer

#### Scenario: A graze does not block the system's swipes
- **GIVEN** right-hand mode, and the system's three-finger swipe between desktops is on
- **WHEN** a contact lands in the corner strip and stays down, and three fingers swipe sideways in the middle of the pad
- **THEN** macOS switches desktops as usual

#### Scenario: A graze does not stop a real thumb from arming
- **GIVEN** right-hand mode with a 2-finger gesture assigned
- **WHEN** a contact lands in the corner strip and stays down, then a thumb lands 8 mm from both the top and the left edge, and two fingers tap in the middle of the pad
- **THEN** the 2-finger gesture fires

#### Scenario: A graze does not stop a real thumb tap from swapping
- **GIVEN** right-hand mode and the swap setting on
- **WHEN** a contact rests in the corner strip, two fingers rest in the middle of the pad, and a thumb lands 8 mm from both the top and the left edge and lifts within the tap window
- **THEN** the swap fires

#### Scenario: A graze does not keep the launcher armed after the thumb lifts
- **GIVEN** right-hand mode, a thumb anchored 8 mm from both the top and the left edge, and a 1-finger gesture assigned
- **WHEN** a contact lands in the corner strip and stays down, the thumb lifts, and one finger taps in the middle of the pad
- **THEN** no gesture fires

### R4. Only the landing point decides
A contact MUST be judged by where it lands. A contact that landed in the corner strip MUST stay an edge contact when it moves out of the strip. A finger that lifts and lands again MUST be judged by its new landing point.

#### Scenario: Graze rolls inward
- **GIVEN** right-hand mode with a 2-finger gesture assigned
- **WHEN** a contact lands 1 mm from the left edge inside the anchor corner, slides 10 mm inward without lifting, and two fingers tap in the middle of the pad
- **THEN** no gesture fires

#### Scenario: Thumb is lifted and put down properly
- **GIVEN** right-hand mode with a 2-finger gesture assigned
- **WHEN** a contact lands in the corner strip and lifts, then a thumb lands 8 mm from both the top and the left edge, and two fingers tap in the middle of the pad
- **THEN** the 2-finger gesture fires

### R5. An anchored thumb that drifts into the corner strip stays anchored
A thumb that anchored by landing outside the corner strip MUST stay anchored when it moves into the corner strip.

#### Scenario: Thumb settles against the edge mid-gesture
- **GIVEN** right-hand mode, a thumb anchored 6 mm from both the top and the left edge, and a 3-finger gesture assigned
- **WHEN** the thumb rolls to 1 mm from the top edge without lifting, and three fingers tap in the middle of the pad
- **THEN** the 3-finger gesture fires

### R6. The strip ends exactly 3 mm from the edge
The corner strip MUST cover only contacts landing closer than 3 mm to the top edge or the thumb-side edge. A contact landing exactly 3 mm from both is outside it.

#### Scenario: Thumb exactly 3 mm from both edges
- **GIVEN** right-hand mode with a 1-finger gesture assigned
- **WHEN** a thumb lands exactly 3 mm from the top edge and 3 mm from the left edge, and one finger taps in the middle of the pad
- **THEN** the 1-finger gesture fires

#### Scenario: Thumb just inside the strip
- **GIVEN** right-hand mode with a 1-finger gesture assigned
- **WHEN** a thumb lands 2.9 mm from the top edge and 10 mm from the left edge, and one finger taps in the middle of the pad
- **THEN** no gesture fires

### R7. Left-hand mode mirrors the strip
In left-hand mode the corner strip MUST run along the top edge and the right edge of the top-right anchor corner.

#### Scenario: Left-hand graze on the right edge
- **GIVEN** left-hand mode with a 2-finger gesture assigned
- **WHEN** a contact lands 1 mm from the right edge, 10 mm below the top edge, and stays down, and two fingers tap in the middle of the pad
- **THEN** no gesture fires

### R8. The strip is 3 mm on every trackpad
The corner strip MUST be 3 mm wide on every trackpad size. This is a physical distance, like the 3 mm band along the bottom edge where a resting palm is ignored.

#### Scenario: Built-in and Magic Trackpad
- **GIVEN** right-hand mode with a 2-finger gesture assigned
- **WHEN** on each of a built-in trackpad and a Magic Trackpad, a contact lands 2 mm below the top edge inside the anchor corner and stays down, and two fingers tap in the middle of the pad
- **THEN** no gesture fires on either

## Non-goals

- **A setting for the strip's width.** The anchor corner is a fixed zone, not tunable by the user. One fixed number keeps the rule predictable.
- **Judging a contact by its size or pressure.** Contact size varies with the person and with pressure. The landing point alone catches a thumb that sits partly off the pad, because its centre lands next to the edge. We revisit size only if grazes still arm after this ships.
- **A settle time before the thumb arms.** An accidental resting thumb is still and long-lived, so a settle time would not catch it. It would also slow quick thumb taps and fast gestures.
- **Promoting a graze that rolls inward to a thumb.** A graze often slides. Promoting it would bring back accidental arming.
- **Dead strips along the full top edge or thumb-side edge.** Fingers near those edges outside the corner are deliberate taps and slides.
- **Feedback when a thumb lands in the corner strip.** A deliberate thumb tap placed within 3 mm of the edge now does nothing, silently, as any graze does; the user puts the thumb further in.
- **Enlarging the anchor corner to make up for the strip.** The corner keeps its size, so its usable area shrinks by the strip.

## Implementation Decisions

- **The corner strip is a third edge band in the edge-contact filter, `EdgeContacts`.** That filter already judges every contact by its landing point alone, removes the ones it calls edge contacts from the frame before the recognizer sees them, keeps each one out for as long as it stays down, and judges a contact that lifts and lands again afresh (ID reuse included). Making the strip one more band buys every requirement but R5 from that mechanism: a strip contact is never in the recognizer's frame, so the anchor corner cannot admit it (R1) and it cannot be a thumb tap (R2); it is not a finger for a tap's count, for either kind of blocking or for the thumb touch, which read the filtered frame (R3); it stays an edge contact while it moves and is re-judged when it lands again (R4); and the band is placed by the hand mode and measured in millimetres from the surface size like the two palm bands (R7, R8). The alternative, putting the strip into `AnchorCorner.admits` so a strip landing is a finger rather than a thumb, was rejected: a finger in the corner would count toward a tap under an anchored thumb, open click blocking beside it, extend a thumb touch and stop a later thumb from arming, exactly what R3 forbids.

- **`GestureRecognizer` does not change.** Its state machine, its blocking levels, the thumb touch, `AnchorCorner.admits` and `AnchorCorner.holds` are untouched, and so are its interface, `EdgeContacts`' interface (built from a hand mode and a surface size; one call per frame returning the frame without its edge contacts) and `Recognition`. The real multitouch adapter, `DeviceSession`, the in-memory trackpads and the model learn nothing. R5 follows from this: an anchor is held by `holds`, which knows no strip, and the filter judges landings only, so a thumb that landed outside the strip and drifts into it stays anchored.

- **The strip's geometry lives in `AnchorCorner`.** The strip is the part of the anchor corner closer than 3 mm to the top edge or to the thumb-side edge, so it is bounded by the corner, and only `AnchorCorner` defines the corner. `AnchorCorner` gains one query: whether a landing point is in the corner strip, true when `admits` would admit the point (the corner's two fractions, strict) and its distance in millimetres to the top edge or to the thumb-side edge is strictly less than the band width. `EdgeContacts` builds an `AnchorCorner` from the same hand mode and surface and asks it beside its two palm bands. `admits` keeps its meaning: it is the one definition of the corner, grown by `holds` for the release margin, and on the frames the recognizer sees no landing is in the strip. The rejected alternative, `EdgeContacts` deriving the corner bounds itself from the rules, would make two definitions of the corner.

- **One band width for every edge.** The strip is 3 mm like the palm bands, a physical distance (R8), so `GestureRules.edgeBandMM` is reused, not duplicated, and its comment names the corner strip as the third place the band applies. An edge contact is "a contact landing closer than 3 mm to a guarded edge"; the guarded edges are what differ (the whole bottom edge; the hand-side edge below the 40% line; the top edge and the thumb-side edge inside the anchor corner). No new rule constant, no setting (a non-goal).

- **Left-hand mode mirrors through the hand mode's thumb-side edge**, which the corner already uses; the top edge is the same in both modes (R7).

- **The one existing test that contradicts the requirements goes.** `EdgeContactRecognizerTests.aThumbAtTheVeryCornerStillAnchors` (a thumb at 1 mm from both edges arms, in both hand modes) pins the decision of plan 007, kept by plan 011, to exempt the anchor corner from the band, which this plan reverses. It is deleted; T1 lands at its right-hand point and T14 at its left-hand point, with the new outcome. Every other test in the suite lands its thumb at least 10 mm from the top edge and at least 10 mm from the thumb-side edge (the farthest-in landings, 24 mm and 26 mm from the left edge, are at the corner's far side, not near its edges), so nothing else moves, and the rest of the suite staying green is the proof that the palm bands, the corner, the release margin, swaps, slides and blocking are as they were.

- **Docs and doc comments.** `docs/domain-model.md`: *Anchor corner* introduces the *corner strip* and the corner's size; *Edge contact* lists the strip as the third place an edge contact lands and narrows its "anywhere else near an edge is a finger" sentence; *Anchored thumb* and *Thumb tap* require a landing outside the strip, and *Anchored thumb* says a drift into the strip keeps the anchoring; *Hand mode* defines the *thumb-side edge*. `docs/architecture.md` is unchanged: the strip is a feature-level rule. The doc comments of `EdgeContacts`, `AnchorCorner` and `GestureRules.edgeBandMM` describe the strip.

## Testing Decisions

### Strategy

One seam carries every requirement, and one row repeats the reported case at the highest seam the suite has. Both exist.

- **The recognizer over scripted frames** (`LauncherKit/Tests/LauncherCoreTests/EdgeContactRecognizerTests.swift`, where every new row lives, with `TouchScript.swift`, the `fired` and `swaps` helpers of `Fixtures.swift`, and the suite's own `recognitions(_:)`, which returns every frame's full `Recognition`, events and `Blocking` level, from a right-hand MacBook recognizer that answers window swipe starts true, which is what T3, T4, T6 and T9 read). It steps the real `GestureRecognizer`, whose only input is a frame and whose only output is a `Recognition`, and observes per frame what fired, which slide phase was reported, whether a swap fired, and the blocking level. In millimetres, so every requirement's scenario is reproduced as written. It misses the adapter's parsing of the hardware frame (`TouchFrameParsingTests`, unchanged) and what the model and the filters make of a `Recognition`, which does not change: a frame with no event pulses no haptic, shows no switcher and brings nothing to front, and a frame reading `.none` lets the tap pass clicks, scrolls and the system's swipes (the model never sees an edge contact, only the recognition, and a frame with no event gives it nothing to act on; `TapGateTests.fortySecondsOfOrdinaryScrollingNeverOpensTheGate` and the `trackpadBlocking: false` rows of `DockSwipeFilterTests` and `ScrollFilterTests` prove that `.none` passes everything). So in the rows below "no haptic plays", "no switcher shows" and "no swap" read as no event, and "the click reaches the app", "the scroll reaches the app" and "macOS switches desktops as usual" read as `blocking == .none` on every frame, the level at which nothing on the trackpad can block and the gated port is off. `.none` proves the app's half; what macOS makes of the contacts it counts itself is the optional hardware check's question (Further Notes).
- **World through `InMemoryTrackpads`** (`LauncherTests.twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow` for what a 2-finger tap does, `LauncherTests.handModeDefaultsToRightAndSwitchingMovesTheCorner` for `world.tap(_:thumbAtMM:)`, `World.swift`): the real `Launcher`, recognizer and in-memory hardware; observes what was brought to front and which trackpads pulsed the gesture haptic. One row, T2, proves R1 as the user meets it, gesture assigned and haptic included. It misses nothing the recognizer rows do not also miss, and adds the model's reading of the recognition.

Faked: the hardware (the World's in-memory trackpads, which run the real recognizer), the system actions and permissions (the World's recording fakes) and the clock (scripted `FrameTime`), exactly as every existing row fakes them. Nothing new is faked; everything in `LauncherCore` runs for real.

Before and after: T1, T2, T3, T4, T5, T6, T7, T8, T10, T14, and the "no gesture" cases of T13 and T15 fail on today's code with the "today" value each row states, so each is a failing test first; T9 fails today on its blocking levels (its "nothing fires" clause already holds, as the row says). T11, T12 and the "fires" cases of T13 and T15 pass today and guard the shape of the change: a strip that stuck to a lifted contact's ID (T11), entered `holds` or was re-judged per frame (T12), or scaled with the pad (T15) would turn them red. Every expected value is a requirement literal, a glossary sentence, a fixture size or an existing twin row's value, never a restatement of the band's arithmetic.

### Test scenarios

Positions are millimetres from the top-left corner on the 14" MacBook Pro surface (124.8 × 76.8 mm; anchor corner 24.96 × 19.2 mm) unless a row names the Magic Trackpad (160 × 115 mm; corner 32 × 28.75 mm). "The middle of the pad" is `TouchScript`'s default (62, 45), fingers 8 mm apart. Right-hand mode and both slide kinds and swaps on unless a row says otherwise.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | Recognizer | Given a contact landing at (10, 1) [1 mm below the top edge], at (2, 10) [2 mm from the left edge], or at (1, 1) [the very corner], staying down. When two fingers tap in the middle of the pad (`thumb(atMM: p).tap(fingers: 2)`). Then nothing fires: `fired == []`. Today: `[.two]` for all three. | R1's first two scenarios' landing points and its rule ("MUST NOT become the anchored thumb, so no tap … can follow it"); (1, 1) is the deleted `aThumbAtTheVeryCornerStillAnchors` row's point, now inside the strip by the requirements' definition ("closer than 3 mm to the top edge or to the thumb-side edge"). |
| T2 | R1 | World | Given a started World with two apps installed, one assigned to the 1-finger gesture and the other to the 2-finger gesture. When `world.tap(2, thumbAtMM: (10, 1))`. Then `world.system.broughtToFront == []` and `world.hardware.feedback == []`. Today: the 2-finger app is brought to front and its trackpad pulses one gesture haptic. | R1's first scenario's THEN ("no gesture fires and no haptic plays"); `LauncherTests.twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow` is the twin that reads the app brought to front and `feedback == [macBook14]` for `world.tap(2)` at (10, 10). |
| T3 | R1 | Recognizer, every frame | Given a contact landing at (2, 10) and two fingers landing in the middle and sliding 20 mm to the right, then lifting (`thumb(atMM: (2, 10)).land(fingers: 2).slide(byMM: (20, 0)).lift()`); and, as a second argument, a contact landing at (10, 1) and two fingers sliding 20 mm up (`thumb(atMM: (10, 1)).land(fingers: 2).slide(byMM: (0, -20)).lift()`), each stepped with window swipe starts answered true. Then on every frame `swipe == nil`, `windowSwipe == nil`, `fired == nil` and `blocking == .none`. Today: the first reports a swipe's `.began`, `.moved`s and `.ended` and reads `.clicks` from the fingers' landing to the frame before its `.ended`; the second a window swipe's, confirmed, likewise. | R1's second and third scenarios ("no switcher shows, and the app does not block the scroll"; "no window switcher shows, and the scroll reaches the app"); the domain model's *Click blocking* ("Under the same rule, trackpad … scrolling is suppressed") makes `.none` the reading of an unblocked scroll; `Blocking.none`'s contract ("nothing on this trackpad can block before its next frame"). |
| T4 | R2 | Recognizer, every frame | Given two fingers resting in the middle for 150 ms. When a contact lands at (10, 1) and lifts 120 ms later, then the fingers lift (`land(fingers: 2).wait(.milliseconds(150)).thumbTap(atMM: (10, 1)).lift()`). Then `swaps == []`, `fired == []` and every frame reads `.none`. Today: `[true]`, and `.clicks` from the thumb's landing until the fingers lift (the swap series). | R2's scenario ("no swap happens and no haptic plays"); the script is `World.swap()`'s hand, which `SwapRecognizerTests.theFingersMayRestForAnyTimeBeforeTheThumbLands` reads as `[true]` with the thumb at (10, 10); *Swap* fires only on a thumb tap, and *Thumb tap* now requires a landing outside the strip. |
| T5 | R3 | Recognizer | Given a thumb anchored at (10, 10). When a contact lands at (10, 1) and stays, and 50 ms later one finger taps in the middle (`thumb(atMM: (10, 10)).land(fingers: 1, atMM: (10, 1)).wait(.milliseconds(50)).tap(fingers: 1)`). Then `fired == [.one]`. Today: `[]` (the contact is a tap finger that never lifts, so the tap never completes within the script). | R3's first scenario ("the 1-finger gesture fires"); *Tap* ("the finger count … not counting the anchored thumb or any edge contact"); `aPalmRestingAtTheHandSideEdgeDoesNotAddToATap` is the hand-side twin reading `[.one]`. |
| T6 | R3 | Recognizer, every frame | Given a contact landing at (10, 1) and staying. When (a) one finger taps in the middle with a firm press from the frame after its landing to its lift, then 100 ms pass (`thumb(atMM: (10, 1)).tap(fingers: 1, click: .firm).wait(.milliseconds(100))`); (b) three fingers land at (50, 45), (58, 45) and (66, 45) and slide 40 mm to the right over 300 ms, then lift (`thumb(atMM: (10, 1)).land(fingers: 3, atMM: (50, 45)).slide(byMM: (40, 0), over: .milliseconds(300)).lift()`). Then every frame of both reads `blocking == .none` and reports no event. Today: (a) reads `.possible` with the contact alone and `.clicks` while the finger is down; (b) `.clicks` while the three fingers are down. | R3 ("MUST NOT make the app block other fingers' clicks, scrolling or the system's trackpad swipes"; "It is not part of a thumb touch") and its second and third scenarios; *Dock swipe blocking* ("Outside a thumb touch nothing is blocked, so three fingers that land and swipe with no thumb in the corner reach the system as usual"); `DockSwipeBlockingRecognizerTests.fingersWithNoThumbInTheCornerNeverBlock` is the no-graze twin reading false. |
| T7 | R3 | Recognizer | Given a contact landing at (10, 1) and staying. When 50 ms later a thumb lands at (8, 8) and two fingers tap in the middle (`land(fingers: 1, atMM: (10, 1)).wait(.milliseconds(50)).thumb(atMM: (8, 8)).tap(fingers: 2)`). Then `fired == [.two]`. Today: `[]` (the contact is the anchor; the thumb at (8, 8) is a tap finger that never lifts). | R3's fourth scenario ("the 2-finger gesture fires"); `anEdgeContactAlreadyDownWhenTheThumbLandsDoesNotStopItArming` is the hand-side twin reading `[.one]`. |
| T8 | R3 | Recognizer | Given a contact resting at (10, 1), then two fingers resting in the middle for 150 ms. When a thumb lands at (8, 8) and lifts 120 ms later, then the fingers lift (`land(fingers: 1, atMM: (10, 1)).wait(.milliseconds(50)).land(fingers: 2).wait(.milliseconds(150)).thumbTap(atMM: (8, 8)).lift()`). Then `swaps == [true]`. Today: `[]` (the contact is the anchor, the thumb joins the fingers' tap, and the final `lift()` takes the contact up with the fingers, so the tap ends with nothing). | R3's fifth scenario ("the swap fires"); *Swap* ("while exactly two fingers rest outside the anchor corner (edge contacts aside)"); `SwapTests.oneOrThreeRestingFingersSwapNothingButAnEdgeContactDoesNotCount` is the hand-side twin at the World seam. |
| T9 | R3 | Recognizer, every frame | Given a thumb anchored at (8, 8) and a contact landing at (10, 1) 50 ms later and staying. When 50 ms after that the thumb lifts, and 50 ms later one finger taps in the middle (`thumb(atMM: (8, 8)).land(fingers: 1, atMM: (10, 1)).wait(.milliseconds(50)).liftThumb().tap(fingers: 1)`). Then `fired == []`, and every frame from the thumb's lift on reads `blocking == .none`. Today: `fired == []` too, but the frames after the lift read `.possible` with the contact alone and `.dockSwipes` while the finger is down (the contact keeps the thumb touch alive). | R3's sixth scenario ("no gesture fires") and its rule ("It is not part of a thumb touch"); *Thumb touch* ("until the first frame with no contact on the trackpad, edge contacts aside"). |
| T10 | R4 | Recognizer | Given a contact landing at (1, 10). When it slides 10 mm inward to (11, 10) without lifting and two fingers tap in the middle (`thumb(atMM: (1, 10)).rollThumb(toMM: (11, 10)).tap(fingers: 2)`). Then `fired == []`. Today: `[.two]`. | R4's first scenario ("no gesture fires"); the non-goal "Promoting a graze that rolls inward to a thumb"; `anEdgeContactRollingInwardStaysAnEdgeContact` is the hand-side twin. |
| T11 | R4 | Recognizer | Given a contact landing at (10, 1) that lifts 120 ms later. When 100 ms after that a thumb lands at (8, 8) and two fingers tap in the middle (`thumbTap(atMM: (10, 1)).thumb(atMM: (8, 8)).tap(fingers: 2)`; `TouchScript` gives both landings the same touch ID, with an absent frame between). Then `fired == [.two]`. Holds today; guards against a strip that sticks to a contact's ID after it lifts. | R4's second scenario ("the 2-finger gesture fires") and its rule ("A finger that lifts and lands again MUST be judged by its new landing point"); `anIDReusedAtTheFingerSpotAfterAnEdgeContactLiftedIsAFinger` is the hand-side twin. |
| T12 | R5 | Recognizer | Given a thumb anchored at (6, 6). When it rolls to (6, 1) over 50 ms without lifting and three fingers tap in the middle (`thumb(atMM: (6, 6)).rollThumb(toMM: (6, 1)).tap(fingers: 3)`). Then `fired == [.three]`. Holds today; guards against the strip entering `holds` or the band being re-judged on a later frame. | R5's scenario ("the 3-finger gesture fires"); *Anchored thumb* as updated ("may drift into the corner strip without losing its anchoring"); `GestureRecognizerTests.thumbMayRollTwoMillimetresPastTheCornerEdge` pins that an anchor is held by `holds`. |
| T13 | R6 | Recognizer | Given a thumb landing at (3, 3) [exactly 3 mm from both edges], at (10, 2.9) [just inside the strip at the top] or at (2.9, 10) [just inside at the side]. When one finger taps in the middle (`thumb(atMM: p).tap(fingers: 1)`). Then `fired == [.one]` for (3, 3) and `[]` for the other two. Today: `[.one]` for all three. | R6 ("closer than 3 mm"; "A contact landing exactly 3 mm from both is outside it") and its two scenarios; `GestureRules.edgeBandMM`'s "Strictly less is inside the band"; the exact value lands on the outside on both arithmetic paths: the top-edge distance comes out as 3.0 exactly (`(3 / 76.8) * 76.8 == 3.0` in IEEE doubles) and the thumb-side distance, which `HandMode.fractionFromThumbSideEdge` computes as `1 - (1 - x)`, as 3.000000000000003, both `>= 3`, so the strict `<` reads them as outside. The row departs from plans 007's and 011's convention of 0.5 mm either side of the band because R6 names the boundary itself. |
| T14 | R7 | Recognizer, left-hand mode | Given left-hand mode and a contact landing at (123.8, 10) [1 mm from the right edge, 10 mm below the top], at (114.8, 1) [10 mm from the right edge, 1 mm below the top] or at (123.8, 1) [the very corner, the deleted row's left-hand point], staying down. When two fingers tap in the middle (`thumb(atMM: p).tap(fingers: 2)` with `handMode: .left`). Then `fired == []`. Today: `[.two]` for all three. | R7's scenario and rule ("along the top edge and the right edge of the top-right anchor corner"); *Hand mode* as updated (the thumb-side edge is the right edge in left-hand mode); `GestureRecognizerTests.leftHandAnchorsInTheTopRightCorner` reads `[.one]` for (114.8, 10). |
| T15 | R8 | Recognizer, both surfaces | Given a contact landing 2 mm below the top edge, 10 mm from the left edge, on the MacBook and on the Magic Trackpad (`TouchScript(surface).thumb(atMM: (10, 2))`), and, as third and fourth arguments, a thumb at (10, 4) and one at (3.5, 10) on the Magic Trackpad. When two fingers tap in the middle (`.tap(fingers: 2)`). Then `fired == []` for both 2 mm landings and `[.two]` for the 4 mm and the 3.5 mm ones. Today: `[.two]` for all four. A strip that were a share of the height (3 mm of 76.8 mm is 3.9%, which is 4.49 mm of 115 mm) would swallow the 4 mm landing, and one that were a share of the width (3 mm of 124.8 mm is 2.4%, which is 3.85 mm of 160 mm) the 3.5 mm one. | R8 ("3 mm wide on every trackpad size. This is a physical distance, like the 3 mm band along the bottom edge") and its scenario; the fixture sizes in `Fixtures.swift`; `theBandIsThreeMillimetresOnTheGuardedEdgesOfEverySize` is the palm-band twin with its 0.5 mm either side of the band on both surfaces. |

### Verified without a test

None.

## Further Notes

- **The corner's usable area shrinks**, as the non-goals accept: on the MacBook from 24.96 × 19.2 mm to 21.96 × 16.2 mm of landing area, on the Magic Trackpad from 32 × 28.75 mm to 29 × 25.75 mm. The corner's size and the release margin are unchanged, so a thumb that landed inside may still roll 2 mm past the corner's far sides, and, by R5, into the strip.
- **A thumb that lands in the strip during a swipe, a window swipe or a swap series is an edge contact too.** Today such a landing becomes the slide's thumb for what follows (a spoiled anchor once the slide ends, then an armed one); with the strip it does not, and the slide ends into a rest or idle of the fingers down as the filter shows them. This is R1 applied in every state, which the filter gives for free; the slide itself is unaffected, since the thumb only starts it (*Swipe*). No row pins it: the swipe rows in `SwipeTravelAndExitTests` and `WindowSwipeRecognizerTests` land their re-landing thumbs at (10, 10) and (12, 10) and stay green.
- **The 3 mm figure rests on the specify step's observation** that a thumb pressed against the pad's physical edge reports its centroid next to that edge. The real adapter maps the framework's normalised position onto `SurfacePoint` and the surface size from the device, unchanged here. If grazes still arm after this ships, the centroid lands farther in than 3 mm, and the non-goals say size and pressure are the next thing to look at, not a wider strip.
- **R5 covers one recognition run.** Recognition restarting mid-touch (after a trackpad change, wake or a settings change) judges every contact down on its first frame by where it is then, as the filter always has: an anchored thumb that had drifted into the strip is an edge contact from that frame and loses its anchoring, just as a palm already in a band is an edge contact on a restart (`anEdgeContactAlreadyDownWhenTheThumbLandsDoesNotStopItArming`'s `.down` case). The *Thumb touch* entry already treats a restart as a fresh judgement.
- **Optional hardware check**, not a gate, and the one place the app's reading meets macOS's own: `.none` proves the app blocks nothing, but macOS counts contacts itself (*Dock swipe blocking*), and whether it counts a thumb resting partly off the pad is not known. On a MacBook in right-hand mode: rest the thumb against the top edge inside the corner and two-finger tap (nothing fires, no haptic); with the thumb still resting, click with another finger (the click lands) and slide two fingers sideways (the page scrolls and no desktop switches); with the system's three-finger desktop swipe on, swipe three fingers under the resting thumb (the desktop switches); then lift the thumb, land it a thumb's width in and two-finger tap (the 2-finger gesture fires). Record the outcome here. The recognizer rows reproduce the app's half of each in millimetres.

## Slices

### S1: The thumb arms only when it lands fully inside the anchor corner

**What to build:** A contact that lands in the anchor corner within 3 mm of the top edge or the thumb-side edge is an edge contact: it never anchors, never swaps, counts for nothing while it stays down and stays ignored if it rolls inward, in both hand modes and on every trackpad size; a thumb that landed farther in anchors as today and keeps its anchoring if it drifts to the edge. The glossary says so.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15.

- [ ] `AnchorCorner` answers whether a landing point is in the corner strip; `EdgeContacts` treats the strip as a band beside the two palm bands, through its unchanged interface; `GestureRecognizer`, the adapters and the model are untouched (`git diff --stat origin/main -- LauncherKit/Sources` lists only the surface types' file and the rules' file).
- [ ] The band width is the one existing rule constant, with its comment naming the corner strip; no new constant, no setting.
- [ ] T1 to T15 are green in `EdgeContactRecognizerTests` (T2 in `LauncherTests`), each written red first where the Strategy says it fails today; `aThumbAtTheVeryCornerStillAnchors` is deleted and no other existing test body changes.
- [ ] `Scripts/test.sh` is green: the whole suite, which is the proof that the palm bands, the corner, the release margin, swaps, slides and blocking are as they were.
- [ ] `docs/domain-model.md` reads as this plan has it, landed with the plan: `git diff origin/main -- docs/domain-model.md` touches exactly the five entries the Docs decision names (*Anchor corner*, *Anchored thumb*, *Thumb tap*, *Edge contact*, *Hand mode*) and nothing else; `docs/architecture.md` is unchanged.
- [ ] The doc comments of `EdgeContacts`, `AnchorCorner` and the band width constant describe the strip, and the `EdgeContactRecognizerTests` suite's doc comment no longer says that anywhere else on the pad, the edges included, a contact is a finger.
