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
