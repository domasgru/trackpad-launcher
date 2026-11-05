# Plan: Launch animation slant

## Problem statement

The launch animation's icon rises straight up from the pointer. It veers to one side only late in its flight. Every launch therefore starts in the same direction, and the flight looks stiff and mechanical. The animation tuner has no control for the direction the icon leaves in, so the developer cannot try a slanted flight. The request asked to "rotate the direction the icon goes". This plan calls that the slant, distinct from the icon's own tilt, which stays.

## Solution

The icon leaves the pointer along a slightly slanted line, leaning to the side its sway veers to. The slant's angle follows the sway's random size: a larger veer slants more, up to 4° in the shipped animation. The sway's late veer adds on top, unchanged, and the total sideways movement still stays within a third of the rise. This third-of-rise limit is an existing rule of the sway that keeps the icon's flight close to the pointer. The Debug animation tuner gets a *Max slant* slider in the Launch tab's Sway section, which the tab's reset restores.

Glossary: *slant* is the angle between the launch animation's path and straight up, toward its sway's side. It is part of the sway (see *Sway* in `docs/domain-model.md`). The rise's height and timing are unchanged. The slant adds sideways movement equal to the height risen × tan(slant angle), so the path from the start of the rise is a straight line at that angle, before the sway's late veer adds on top.

## Requirements

Scenarios that name angles or ratios are judged on the animation's recorded path, its keyframes, not by eye.

### R1. The launch animation slants toward its sway's side
Once its pop ends, the launch animation's icon MUST move along a line slanted from straight up toward the side its sway veers to, from the first moment it moves. The rise's height and timing stay the same. The slant adds sideways movement equal to the height risen × tan(slant angle), so the path from the start of the rise is a straight line at that angle, before the sway's late veer adds on top. The side is random, and a side never comes up three times in a row.

#### Scenario: Slants right with a rightward sway
- **GIVEN** a launch animation whose sway veers right
- **WHEN** the icon starts to rise after its pop
- **THEN** its first rising moments already move it right of the pointer, not straight up

#### Scenario: Slants left with a leftward sway
- **GIVEN** a launch animation whose sway veers left
- **WHEN** the icon starts to rise after its pop
- **THEN** its first rising moments already move it left of the pointer

#### Scenario: The pop stays in place
- **WHEN** the icon swells in its pop
- **THEN** it stays centred on the pointer

#### Scenario: Third launch in a row
- **GIVEN** two launches in a row that both veered and slanted right
- **WHEN** a third launch plays
- **THEN** it veers and slants left

### R2. The slant's size follows the sway's size
The slant's share of Max slant MUST equal the sway's size share for that launch, the share between Min sway and 1 the launch drew, in direct proportion. The slant does not depend on Max sway.

#### Scenario: Largest sway slants the most
- **GIVEN** the shipped animation
- **WHEN** a launch draws the largest sway
- **THEN** its path slants by 4° from straight up

#### Scenario: Mid-point sway slants by the mid-point share
- **GIVEN** the shipped animation
- **WHEN** a launch draws a sway share of 0.55, halfway between Min sway and 1
- **THEN** its path slants by 2.2° from straight up, toward its sway's side

#### Scenario: Smallest sway still slants a little
- **GIVEN** the shipped animation, with the shipped Min sway of 0.1
- **WHEN** a launch draws the smallest sway
- **THEN** its path slants by 0.4° from straight up, toward its sway's side

#### Scenario: Slant without sway
- **GIVEN** the tuner with Max sway at 0 and Max slant at 4°
- **WHEN** a launch plays
- **THEN** it still slants toward a side picked by the same side rule, with no late veer

### R3. The shipped numbers
The shipped launch animation MUST use Max slant 4°, Max sway 0.26, Min sway 0.1 and Sway curve 1.8.

#### Scenario: Release build
- **WHEN** a release build plays a launch animation
- **THEN** the icon moves sideways from its first rising moment
- **AND** its sway uses Max sway 0.26, Min sway 0.1 and Sway curve 1.8

### R4. Total sideways movement stays within a third of the rise
The shipped Max slant and sway numbers MUST be chosen so that the icon's sideways distance from the start of its path never exceeds a third of its rise at any moment. The ratio only grows over the flight, so the end is the worst moment.

#### Scenario: Largest sway at the end
- **GIVEN** the shipped animation and a launch with the largest sway
- **WHEN** the flight reaches its end
- **THEN** the icon is at most a third of its rise to the side of the pointer

### R5. Reduce motion has no slant
With the system's Reduce motion setting on, or the tuner's *Simulate Reduce motion* on, the launch animation MUST fade out in place with no slant.

#### Scenario: Reduce motion on
- **GIVEN** Reduce motion is on
- **WHEN** a gesture plays the launch animation
- **THEN** the icon fades out in place without moving

#### Scenario: Simulate Reduce motion on
- **GIVEN** the tuner's Simulate Reduce motion is on
- **WHEN** a gesture plays the launch animation
- **THEN** the icon fades out in place without moving

### R6. A bounce's ending slants too
Every bounce ending that plays a launch animation MUST slant like any other launch animation. Endings that fade out in place have no launch animation. The slant starts from the icon's first rising moment, whether or not that animation pops, from the spot the icon is at.

#### Scenario: Bounce ends with a window
- **GIVEN** a launch bounce playing for a starting app
- **WHEN** the app's first window shows
- **THEN** the ending launch animation rises along a slanted line toward its sway's side

### R7. The tuner has a Max slant slider
The Debug animation tuner's Launch tab MUST show a *Max slant* slider in its Sway section, from 0° to 30° in steps of 0.5°, that changes the maximum slant of the next launch animation.

#### Scenario: Slider range and steps
- **GIVEN** the tuner open on the Launch tab
- **WHEN** the developer drags the Max slant slider
- **THEN** it stops at 0° and 30° and moves in 0.5° steps

#### Scenario: Set the slant to zero
- **GIVEN** the tuner open with Max slant at 0°
- **WHEN** a gesture plays the launch animation
- **THEN** the icon rises straight up and veers only from its sway

#### Scenario: Large slant
- **GIVEN** the tuner open with Max slant at 20°
- **WHEN** a gesture plays a launch animation with the largest sway
- **THEN** its path slants by 20° toward its sway's side

### R8. The Launch tab's reset restores the slant
The tuner's reset for the Launch tab MUST set Max slant back to its shipped 4°, and the other tabs' resets MUST leave it alone.

#### Scenario: Reset Launch
- **GIVEN** the tuner with Max slant at 12°
- **WHEN** the developer resets the Launch tab
- **THEN** Max slant reads 4°

#### Scenario: Reset Bounce
- **GIVEN** the tuner with Max slant at 12°
- **WHEN** the developer resets the Bounce tab
- **THEN** Max slant still reads 12°

### R9. A saved Max slant loads back
A tuning saved with Max slant at a value MUST load with Max slant at that value.

#### Scenario: Save and load 12°
- **GIVEN** a tuning saved with Max slant at 12°
- **WHEN** the tuner loads it
- **THEN** Max slant reads 12°

### R10. Older tuner saves load the shipped slant
A tuning the tuner saved before this change MUST load with the shipped Max slant and every saved value kept.

#### Scenario: Load an older save
- **GIVEN** a tuner save from before Max slant existed, with Max sway 0.5
- **WHEN** the tuner loads it
- **THEN** Max slant reads 4° and Max sway reads 0.5

## Non-goals

- **A slant curve slider.** The slant is a straight line from the start. A curve would blur it into the sway, which already has its own curve.
- **Changing the icon's tilt.** The icon's own rotation stays as it is. The slant changes only the direction of travel.
- **Holding tuner values to the third-of-rise limit.** The tuner can already go past it with Max sway. The limit binds only the shipped numbers, so the developer can explore freely.
- **A user-facing setting.** The slant ships at a fixed value. Only Debug builds' tuner changes it.
- **The launch bounce's own motion.** The bounce's inflate and jump stay unchanged. Only its ending launch animation slants.
- **An independent slant draw.** The slant takes its side and size from the sway, so the two read as one movement.

## Implementation Decisions

### D1. A flight is a value of its tuning
- The flight draw, `LaunchFlights.next`, takes the tuning the flight plays with, beside the draw and the Reduce motion flag, and the flight keeps that snapshot: every number its poses need comes from the snapshot, never from a global read at pose time. The launch overlay passes the current tuning at play time, so behaviour is unchanged (a tuner change applies to the next launch, as today); tests pass the shipped tuning or a copy with knobs changed, so a tuned flight is proved through the same interface the overlay uses and no test touches the tuner's process-wide override, which parallel tests could never share safely.
- The flight's static knob accessors go (icon side, duration, step count, the sway bounds, the tilt, the peak side); the overlay's icon-pixel size reads the peak side, icon side × (1 + pop size), from the tuning itself, as a computed property on the tuning.
- Simulate Reduce motion folds into the draw: a flight fades in place when the system's Reduce motion is on or the tuning's `forceReduceMotion` is on. The overlay passes the system setting alone, and the tuner's switch is proved at the flight seam. The bounce overlay keeps combining the two for its own bounce; nothing there changes.

### D2. The sway carries its side and its size share
- The flight's moving motion holds a *side* (left or right) and a *share*, the sway's size share drawn for the launch: Min sway + (1 − Min sway) × |draw|, in Min sway…1. It replaces today's one signed sway value, from which the tilt back-computed its lean by dividing by Max sway.
- Words: the *veer* is the sway's late sideways part, the *slant* the straight line, and the *drift* is all sideways movement, veer and slant together. The veer, the slant and the tilt each read the share, all signed by the side. The pose at rise share `u` (from the prototype; it encodes R1 and R2 exactly):

  ```
  rise = Rise × u^riseCurve
  x    = sign(side) × (rise × tan(share × Max slant) + share × Max sway × rise × u^swayCurve)
  y    = rise
  lean = Max sway > 0 ? share : 0
  tilt = −sign(side) × lean × Max tilt × u^tiltCurve      (counter-clockwise positive)
  ```

  So the path from the start of the rise is a straight line at share × Max slant until the veer adds on top (R1), the slant's share of Max slant is the sway's share, in angle, not in tangent (R2), the slant ignores Max sway (R2), and the rise's height and timing are untouched (R1). At the shipped numbers the veer is what it is today.
- The tilt is unchanged in every case, as the non-goal asks: its lean is the share when Max sway is above 0 and 0 otherwise, which is exactly today's sway ÷ Max sway with its guard against a zero Max sway. So with Max sway at 0 the icon slants but does not tilt, as it does not tilt today. T3 pins it.
- The pop is untouched: the pose during the pop has no offset, so the icon stays centred on the pointer (R1), and the slant starts with the rise, whether or not there is a pop (R6).

### D3. One new tuning knob: Max slant
- `LaunchTuning` gains `maximumSlant`, in degrees, shipped at 4: the slant of the largest sway; a launch's slant is its share × Max slant. Max sway 0.26, Min sway 0.1 and Sway curve 1.8 stay as shipped (R3).
- It is a Launch-tab knob: the Launch reset restores it and the other tabs' resets leave it (R8); the Debug JSON decoder reads it missing-or-shipped like every other key, so an older save loads it at 4° (R10); encoding stays synthesized, so a save carries it (R9).
- The third-of-rise limit becomes an inequality on the shipped numbers, written in both knobs' doc comments, Max sway's and Max slant's: tan(Max slant) + Max sway ≤ 1/3 at the largest sway. Shipped: tan 4° + 0.26 = 0.3299. T6 fails if either shipped number breaks it. Sway curve's comment calls the sway's part the veer, not the drift (D2's words).

### D4. The tuner's slider
- The Launch tab's Sway section gains a *Max slant* knob, 0…30 in steps of 0.5, unit °, last in the section after Sway curve, with a hint that the rise leans toward the sway's side and that a launch's slant follows its sway's share. Like every knob it is a slider plus a field, with the per-knob reset arrow showing the shipped 4 (R7).

### D5. The bounce's ending needs nothing new
- A bounce's ending already plays through the launch overlay's `play(for:from:among:size:)`, which draws from the same `LaunchFlights`, so the ending's flight slants from the spot the icon is at, at the icon's size, from its first rising moment (R6). Nothing changes in the bounce overlay; the flight seam proves a sized flight from an off-pointer start, with and without a pop.

### D6. Tests
- The flight suite gains two keyframe readings: the *first rising keyframe*, the first whose screen y is above the start's, and a keyframe's *angle from straight up*, atan2(|dx|, dy) of its displacement from the start, in degrees. Its `stage` helper takes a tuning, shipped by default.
- The tuner coding suite's everything-away-from-shipped fixture (which already has Max sway 0.5) gains Max slant 12°, the Launch reset expectation gains the slant, and a new verbatim fixture holds that everything-away-from-shipped tuning as the JSON the tuner saves today: encoded with `JSONEncoder` before `maximumSlant` exists and pasted as a literal, so it has every current key and no `maximumSlant`, and every kept value is away from shipped, so a key wrongly falling back to shipped is caught.

### D7. Documentation
- `docs/domain-model.md`: *Sway* names the slant, the 4° ceiling, and that the slant, the veer and the tilt grow together with the sway's size; *Launch animation* says the icon rises along a slightly slanted line; *Launch bounce* says the ending slants from where the icon is. `docs/architecture.md` is unchanged: no core decision moves.

## Testing Decisions

### Strategy

Two seams, both existing.

- **The flight**, through `LaunchFlights.next(draw:reduceMotion:tuning:)` → `LaunchFlight.sized(_:)` → `staged(at:among:)` → the stage's keyframe animations, decoded by the existing `keyframes()` helper in `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift`. It observes the icon's position, side, rotation and opacity at every keyframe Core Animation will play, which is what the requirements say angles are judged on. It misses the panel, the layer tree and the render server's playback, and the random draw, which the test supplies. Nothing is faked: the flight is a pure value, randomness is its `draw` parameter, the tuning is a value passed in (D1), and the connected displays are the suite's two fixtures. The new tests resemble the existing rows of that file.
- **The tuning**, through `LaunchTuning`'s JSON coding and `resettingToShipped(_:)` in `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`. It observes the decoded values and the reset result; it misses the tuner's window, its defaults store and its sliders.

What no seam sees: the slider's range, step and section in the tuner's SwiftUI form (R7's first scenario), and the overlay passing the current tuning to the draw (D1). T9 proves what Max slant does to a flight; the slider itself and the overlay's read are checked by hand in the slice's acceptance criterion, with exact steps. Release builds read the shipped tuning through the existing `#if DEBUG` on `LaunchTuning.current`; T1–T9 pass `LaunchTuning.shipped` or a changed copy, and no test reads `LaunchTuning.current`.

### Test scenarios

Angles are read from keyframes as D6 describes. "First rising keyframe" is the first keyframe above the start. The 0.02° tolerance covers the sway's late veer at the first rising step, which is below 0.01° at shipped sampling because the sway's curve starts flat (prototype: 4.007°, 2.204°, 0.401°, 20.006°).

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R3 | flight | Given the shipped tuning and each of the suite's seven draws (−1, −0.5, −0.01, 0, 0.01, 0.5, 1). Then every keyframe up to and including the pop's peak sits at the pointer; the first rising keyframe is right of the pointer for draws ≥ 0 and left for draws < 0, at least 0.38° from straight up (today's veer alone puts it below 0.01°); every keyframe from it to the end stays on that side. | R1's three first scenarios; the suite's draw rule, zero veers right, as the existing side tests use; 0.38° is R2's smallest slant, 0.4°, less the tolerance. |
| T2 | R1, R2, R3 | flight | Given the shipped tuning. When the draw is 1 (the largest sway) Then the first rising keyframe's angle from straight up is 4° ± 0.02°. Draw 0.5 (the share halfway between Min sway 0.1 and 1, 0.55): 2.2° ± 0.02°. Draw 0 (the smallest sway, share 0.1): 0.4° ± 0.02°. Each toward the draw's side. | R2's literals 4°, 2.2°, 0.4°; "halfway between Min sway and 1" is the draw 0.5. |
| T3 | R2 | flight | Given a tuning with Max sway 0 and Max slant 4° (else shipped), draws 1 and −1. Then every rising keyframe's angle is 4° within 1e-6°, toward the draw's side: a straight line, no late veer; and every keyframe's rotation is 0, as today with Max sway 0. Given three draws of 0.6 on one `LaunchFlights`: right, right, left. The angle equals T2's shipped 4°, so the slant does not depend on Max sway. | R2 "Slant without sway" and "does not depend on Max sway"; the side rule in R1; the non-goal "the icon's own rotation stays as it is", today's flight not tilting with Max sway 0. |
| T4 | R1 | flight | Given a fresh `LaunchFlights`, the shipped tuning and draws 0.6, 0.6, 0.6. Then the first two flights' first rising keyframes and ends lie right of their start and the third's lie left. | R1 "Third launch in a row". |
| T5 | R3 | `LaunchTuning.shipped` | Then Max slant is 4, Max sway 0.26, Min sway 0.1, Sway curve 1.8. | R3's literals. |
| T6 | R4 | flight | Given the shipped tuning, draws 1 and −1. Then over the rising keyframes the ratio \|drift\| ÷ rise never decreases, and at every keyframe, the end included, \|drift\| ≤ rise ÷ 3. (The existing third-of-rise test, extended with the monotonic ratio.) | R4's "a third" and "only grows". |
| T7 | R5 | flight | Given Reduce motion on with the shipped tuning; and Reduce motion off with a tuning whose Simulate Reduce motion is on and Max slant 20°. For every draw. Then every keyframe is at the pointer, side 60, rotation 0, and opacity falls to 0. | R5's two scenarios; "fades out in place". |
| T8 | R6 | flight | Given the shipped tuning, draw 1, a flight `sized(1.4)` staged from (900, 500), an inflated bounce icon's spot (84 pt = 1.4 × 60). Then the start keyframe has side 84; every keyframe to the peak sits at (900, 500); the first rising keyframe leaves (900, 500) at 4° ± 0.02° to the right. Given the same with Pop size 0: the keyframe right after the start already moves at 4° ± 0.02°. | R6; the domain model's 84 pt inflated icon; R2's 4°. |
| T9 | R7, R2, R1 | flight | Given a tuning with Max slant 0 (else shipped), draw 1. Then the first rising keyframe is straight up within 0.02°, and the end drift is to the right with drift ÷ rise = 0.26 ± 1e-9: the sway alone. Given Max slant 20°, draws 1 and −1. Then the first rising keyframe is at 20° ± 0.02° toward the draw's side; with draw 0.5 (share 0.55) it is at 11° ± 0.02°, so the share scales the angle, not its tangent (which would give 11.32°). And for the same draw, every keyframe of the Max slant 20° flight has the same time and the same rise as the Max slant 0 flight's, within 1e-9: the slant adds sideways movement and changes neither the rise's height nor its timing (a rotated path would end 65.8 pt up instead of 70). | R7 "Set the slant to zero" and "Large slant"; R2 "in direct proportion" (0.55 × 20° = 11°); R1 "the rise's height and timing stay the same"; Max sway's documented meaning, sideways per point of rise at the end for the largest sway. |
| T10 | R8 | `LaunchTuning.resettingToShipped` | Given every knob away from shipped, Max slant at 12°. When Launch is reset Then Max slant is 4 and the fifteen flight knobs are shipped, everything else kept. When Bounce is reset Then Max slant is still 12 and only the bounce is shipped; Pick and Swipe likewise keep 12. | R8's 12° and 4°. |
| T11 | R9 | `LaunchTuning` coding | Given a preset with Max slant 12°, encoded and decoded. Then Max slant is 12 and the preset equals the original. | R9. |
| T12 | R10 | `LaunchTuning` decoding | Given the verbatim JSON the tuner saves today for the everything-away-from-shipped tuning: every current key, no `maximumSlant`, Max sway 0.5 (D6). Then it decodes to that tuning with Max slant 4: Max sway 0.5 and every other saved value as saved, each of them away from shipped, so a key wrongly falling back to shipped fails. | R10's 4° and 0.5; the fixture, encoded before the change. |

### Verified without a test

None.

## Further Notes

- **Measuring the slant from keyframes.** The slant is the angle of the straight line before the veer adds on top. The keyframes show the sum, so the tests read the angle at the first rising keyframe, where the veer's contribution is below 0.01° at shipped sampling (82 steps, 83 keyframes, over 0.34 s; the first rising keyframe is 0.033 pt up), and separately prove the pure line with Max sway 0 (T3). The 0.02° tolerance is for that first step only; T3 uses 1e-6°.
- **Why the shipped end ratio is 0.3299.** tan 4° + 0.26 = 0.3299 < 1/3, so the shipped numbers sit just inside the sway's limit; any later raise of Max slant or Max sway must keep tan(Max slant) + Max sway ≤ 1/3, or T6 fails.
- **Release builds.** `LaunchTuning.current` is `shipped` outside `#if DEBUG` (existing, unchanged). R3 rests on T5 (the shipped numbers) and T2 (the shipped flight) together with that unchanged `#else` branch; `swift build -c release` only shows that no Debug-only code leaks into Release.

## Slices

### S1: The launch animation leaves the pointer along a slanted line, tuned by Max slant

**What to build:** Every launch animation and every bounce ending that plays one rises along a line slanted toward its sway's side from the first moment it moves, by a share of Max slant equal to its sway's share, with the pop and the rise untouched and Reduce motion still fading in place. The Debug tuner's Launch tab gets a *Max slant* slider in its Sway section that the Launch reset restores to 4°, saves carry it, and older saves load it at 4°. Release builds ship Max slant 4°, Max sway 0.26, Min sway 0.1 and Sway curve 1.8.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, R10.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-data`.

- [ ] Prefactor first, no behaviour change (D1): the flight draw takes the tuning and the flight keeps it; the static knob accessors are gone; the overlay passes the current tuning and the system's Reduce motion alone; the overlay's pixel size reads the peak side from the tuning. The existing flight tests pass unchanged in meaning (the one read of the flight's duration becomes the shipped tuning's), and the whole suite is green.
- [ ] The motion carries side and share, and the pose is D2's, the tilt's guard included; Max sway's and Max slant's doc comments state the inequality in D3, and Sway curve's calls the sway's part the veer.
- [ ] `LaunchTuning.maximumSlant` shipped at 4, documented as the slant of the largest sway; the Launch reset, the Debug decoder (missing-or-shipped) and the synthesized encoder cover it.
- [ ] The tuner's Sway section shows *Max slant* last, 0…30 in 0.5° steps with the ° unit and the hint (D4). By hand on a Debug build, on the Launch tab: *Max slant* is the last knob of the Sway section; dragged fully left its field reads 0, fully right 30; typing 12.3 shows 12.5; the reset arrow's help reads "Shipped: 4" and pressing it restores 4; at 20 *Preview at pointer* is plainly slanted and at 0 it is today's flight, which shows the overlay reads the current tuning.
- [ ] T1–T12 green, written as the existing rows of their files are; T12's fixture is verbatim as D6 describes. `swift test` green; `swift build -c release` builds.
- [ ] By feel on a Debug build at shipped: launches lean left or right from the start rather than going straight up; Max slant 20° is plainly slanted; Max slant 0° is today's flight; a bounce's ending (launch an app that is not running) slants from where the icon is; Simulate Reduce motion fades in place.
- [ ] `docs/domain-model.md`'s *Sway*, *Launch animation* and *Launch bounce* entries, updated at planning, match the code as built.
