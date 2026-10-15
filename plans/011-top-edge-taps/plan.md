# Plan: Taps near the top edge count

## Problem statement

A tap that lands close to the top edge of the trackpad does nothing. Today a contact that lands within 3 mm of any edge, outside the anchor corner, is an edge contact. The app takes it for a palm and ignores it. The guard exists for the palm resting beside the pad. That palm reaches only the bottom edge and the lower part of the edge on the hand's side. On the top edge, and on the upper part of the side edges, the guard swallows only real fingers. A user who taps high on the pad, near the top edge, sees the gesture fail.

## Solution

Only the bottom edge and the lower part of the hand-side edge stay guarded. In right-hand mode the hand-side edge is the right edge. In left-hand mode it is the left edge. The guarded part of that edge is the part more than 40% of the trackpad's height down from the top. The boundary is a share of the height, not millimetres, because the palm sits at the same share of the pad on every size, and the anchor corner is sized the same way. A contact landing anywhere else near an edge is a finger, like any other finger.

## Requirements

### R1. The guarded band covers only where a palm rests
A contact MUST be an edge contact only when it lands either closer than 3 mm to the bottom edge, or closer than 3 mm to the hand-side edge and more than 40% of the trackpad's height down from the top. In right-hand mode the hand-side edge is the right edge; in left-hand mode it is the left edge.

#### Scenario: Palm at the lower right edge is still ignored
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** a contact lands 1 mm from the right edge, 70% of the way down, and lifts after 120 ms, within the tap window
- **AND** one finger then taps the middle of the pad
- **THEN** the 1-finger gesture fires once, for the middle tap only

#### Scenario: Palm at the lower left edge is still ignored in left-hand mode
- **GIVEN** left-hand mode and an anchored thumb
- **WHEN** a contact lands 1 mm from the left edge, 70% of the way down, and lifts after 120 ms, within the tap window
- **THEN** no gesture fires

#### Scenario: A resting palm at the right edge does not add to a tap
- **GIVEN** right-hand mode, an anchored thumb, and a contact resting 1 mm from the right edge, 70% of the way down
- **WHEN** one finger taps the middle of the pad
- **THEN** the 1-finger gesture fires, not the 2-finger one

#### Scenario: A resting palm at the left edge does not add to a tap in left-hand mode
- **GIVEN** left-hand mode, an anchored thumb, and a contact resting 1 mm from the left edge, 70% of the way down
- **WHEN** one finger taps the middle of the pad
- **THEN** the 1-finger gesture fires, not the 2-finger one

#### Scenario: Palm at the bottom edge is still ignored along its whole length
- **GIVEN** an anchored thumb, in right-hand mode and in left-hand mode
- **WHEN** a contact lands 1 mm from the bottom edge and 1 mm from the left edge, at the middle of the bottom edge, or 1 mm from the bottom edge and 1 mm from the right edge, and lifts after 120 ms, within the tap window
- **THEN** no gesture fires

#### Scenario: 45% down on the hand-side edge is still guarded
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** a contact lands 1 mm from the right edge, 45% of the way down, and lifts after 120 ms, within the tap window
- **THEN** no gesture fires

#### Scenario: 35% down on the hand-side edge is a finger
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** a contact lands 1 mm from the right edge, 35% of the way down, and lifts after 120 ms, within the tap window
- **THEN** the 1-finger gesture fires

### R2. A contact near the top edge is a finger
A contact that lands near the top edge, outside the anchor corner, MUST count as a finger, in both hand modes.

#### Scenario: One finger taps at the top edge (the reported case)
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the top edge, at the middle of its width
- **THEN** the 1-finger gesture fires

#### Scenario: Top edge in left-hand mode
- **GIVEN** left-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the top edge, at the middle of its width
- **THEN** the 1-finger gesture fires

#### Scenario: Top edge just outside the anchor corner
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the top edge, 5 mm right of the anchor corner's right side
- **THEN** the 1-finger gesture fires

#### Scenario: Top-right corner in right-hand mode
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the top edge and 1 mm from the right edge
- **THEN** the 1-finger gesture fires

### R3. A contact near the edge opposite the hand side is a finger
A contact that lands near the edge opposite the hand side MUST count as a finger, unless it is closer than 3 mm to the bottom edge. In right-hand mode that is the left edge; in left-hand mode it is the right edge.

#### Scenario: Left edge in right-hand mode
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the left edge, 70% of the way down
- **THEN** the 1-finger gesture fires

#### Scenario: Left edge just below the anchor corner in right-hand mode
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the left edge, 30% of the way down, just below the anchor corner
- **THEN** the 1-finger gesture fires

#### Scenario: Right edge in left-hand mode
- **GIVEN** left-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the right edge, 70% of the way down
- **THEN** the 1-finger gesture fires

### R4. A contact near the upper part of the hand-side edge is a finger
A contact that lands near the hand-side edge, 40% or less of the trackpad's height down from the top, MUST count as a finger.

#### Scenario: Upper right edge in right-hand mode
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the right edge, 20% of the way down
- **THEN** the 1-finger gesture fires

#### Scenario: Upper left edge in left-hand mode
- **GIVEN** left-hand mode and an anchored thumb
- **WHEN** one finger taps 1 mm from the left edge, 30% of the way down
- **THEN** the 1-finger gesture fires

### R5. A freed contact follows every finger rule
A contact that R2, R3 or R4 makes a finger MUST behave like any other finger: it counts toward a tap's finger count, takes part in swipes and swaps, and counts for click blocking and Dock swipe blocking. A contact that lands as a finger MUST stay a finger if it later slides into a guarded band.

Click blocking and Dock swipe blocking are the existing rules that keep a click or the system's trackpad swipe from reaching apps while gesture fingers are down. A freed finger counts there exactly as a finger in the middle of the pad does.

#### Scenario: Two fingers tap, one at the top edge
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** two fingers tap together, one in the middle of the pad and one 1 mm from the top edge, at the middle of its width
- **THEN** the 2-finger gesture fires

#### Scenario: A finger at the top edge takes part in a swipe
- **GIVEN** right-hand mode, the swipe setting on, and an anchored thumb
- **WHEN** two fingers land, one in the middle of the pad and one 1 mm from the top edge, at the middle of its width
- **AND** both slide sideways 20 mm
- **THEN** the switcher shows

#### Scenario: A finger resting at the top edge counts for a swap
- **GIVEN** right-hand mode, the swap setting on, at least two running apps, and two fingers resting: one in the middle of the pad and one 1 mm from the top edge, at the middle of its width
- **WHEN** the thumb taps the anchor corner
- **THEN** the swap fires

#### Scenario: A finger resting at the top edge counts for click blocking
- **GIVEN** right-hand mode, a thumb anchored less than 3 s ago, and one finger resting 1 mm from the top edge, at the middle of its width
- **WHEN** the user clicks
- **THEN** the click is blocked, as it is for a finger resting in the middle of the pad

#### Scenario: A finger that slides into the guarded band stays a finger
- **GIVEN** right-hand mode and an anchored thumb
- **WHEN** two fingers tap together, one in the middle of the pad and one landing 1 mm from the right edge, 38% of the way down
- **AND** the edge finger slides 2 mm down along the edge, past the 40% line, before both lift within the tap window
- **THEN** the 2-finger gesture fires

### R6. Contacts away from the edges behave as today
Taps, swipes, swaps, click blocking and Dock swipe blocking for contacts landing 3 mm or more from every edge MUST behave as they do today.

#### Scenario: A tap in the middle of the pad
- **GIVEN** an anchored thumb, in either hand mode
- **WHEN** one finger taps the middle of the pad
- **THEN** the 1-finger gesture fires, as today

## Non-goals

- **Changing the 3 mm band width.** The problem is where the band applies, not how wide it is.
- **A setting for the guarded edges.** The guard follows the hand mode, like the anchor corner, and is not user-tunable.
- **Rejecting a palm by its shape.** Plan 007 left this out; nothing here changes that reasoning.
- **Changing what an edge contact does.** Only where it can land changes; once a contact is an edge contact, it is ignored as today.
- **Changing the anchor corner.** Its size and position stay as they are.
- **A second hand, or the other hand's palm, resting on the pad.** The guard covers the palm of the hand the hand mode names; plan 007's recording shows no other.

## Plan files

- `design.md`: the implementation decisions (the band follows the hand mode, the anchor-corner carve-out goes, the two rule numbers, `EdgeContacts`' unchanged interface with new inputs, the recognizer passing its hand mode, the nearest-edge helper removed, the existing tests that move, the documents) and further notes.
- `testing.md`: the strategy (one seam, the recognizer over scripted frames), the test scenarios T1–T8, and R6 verified without a test.
- `slices/S1.md`: the one slice, delivering every requirement.
- `development-logs.md`: what each review round found and what changed.
