# Plan: A palm brushing the trackpad edge is not a finger

## Problem statement

With one finger sliding quickly around the edge of the anchor corner, the 1-finger gesture fires, and less often the 2-finger gesture. The user moved only one finger.

Reproduced end to end: raw MultitouchSupport frames recorded on the built-in trackpad (right-hand mode) while the user reproduced the bug twice, then replayed through the real `GestureRecognizer` with the adapter's own parsing rules (`plans/007-one-finger-false-tap/.temp/recorder/rec1.txt`, `.temp/replay/main.swift`). The replay fires the 1-finger gesture exactly twice, at the two moments the user saw it.

Root cause: the second "finger" is the edge of the user's palm, resting on the palm rest beside the trackpad and brushing its right edge. The driver reports it as a contact (mostly hovering, now and then touching for 20–60 ms). Every such contact in the recording landed within 1.5 mm of the right edge (normalised x ≥ 0.988), elongated (major axis 11–19 vs 7–11 for fingertips). Every real finger landing was more than 57 mm from that edge. While the sliding finger sits in the anchor corner it is the anchored thumb, so a brief palm contact reads as a one-finger tap: it lands, stays still, lifts within 400 ms, and the 1-finger gesture fires. Two palm contacts within one tap read as a 2-finger tap.

The recognizer treats every contact the driver reports as a finger. No test covers a contact that is not a finger; the test fixtures place every finger well inside the surface.

Options considered:
- **Edge band (chosen).** A contact that lands within a few millimetres of an edge of the trackpad, outside the anchor corner, is a resting hand, not a finger, for as long as it stays down. It is deterministic and geometric, measured in millimetres, so it is the same on every trackpad size, and it is one rule, easy to test. A deliberate tap has its fingertip centred well inside the surface: a centre within 3 mm of the edge means most of the fingertip is off the pad.
- **Contact shape or pressure** (major axis, axis ratio, `zTotal`). Rejected: a fast-sliding fingertip stretches to a major axis of 17–18 in the same recording, so shape overlaps with palms exactly in the motion that triggers the bug, and pressure overlaps too (palm 0.4–1.0, fingers 0.3–1.5 at landing).
- **The driver's own hand/finger classification** (`fingerID`, `handID`). Rejected: undocumented private fields with no known palm flag, so the fix would rest on guesses about Apple's internals.

## Requirements

### R1. A contact landing at the trackpad's edge is not a finger
A contact whose landing point is within 3 mm of any edge of the trackpad's surface (left, right, top or bottom), and outside the anchor corner's admission zone, MUST NOT count as a finger for the rest of its contact. It does not start, join, count toward, drag, spoil or fire a tap. It does not begin, join, move or cancel a swipe. It counts as neither "another contact down" for click and Dock swipe blocking nor a second contact that stops a thumb from arming. A contact that lands outside the band and later slides into it stays a finger. A driver ID that lifts and lands anew is judged afresh by its new landing point.

#### Scenario: Palm brushing the edge during a one-finger slide (the reproduction)
- **GIVEN** right-hand mode, gestures active, the 1-finger and 2-finger gestures assigned
- **WHEN** the recorded frames of `plans/007-one-finger-false-tap/.temp/recorder/rec1.txt` are fed to the recognizer: one finger sliding in and around the anchor corner while a palm contact lands 1 mm from the right edge and lifts after 24 ms, and again after 56 ms
- **THEN** no gesture fires

#### Scenario: Palm resting at the edge does not block a gesture
- **GIVEN** right-hand mode, a contact resting 1 mm from the right edge
- **WHEN** the thumb anchors in the top-left corner and one finger taps the middle of the trackpad
- **THEN** the 1-finger gesture fires

#### Scenario: The anchored thumb at the corner edge still anchors
- **GIVEN** right-hand mode
- **WHEN** the thumb lands 1 mm from the left and top edges, inside the anchor corner, and one finger taps the middle of the trackpad
- **THEN** the 1-finger gesture fires

#### Scenario: A finger just outside the band still counts
- **GIVEN** right-hand mode, a thumb anchored
- **WHEN** one finger taps 4 mm from the right edge
- **THEN** the 1-finger gesture fires

### R2. Taps and swipes away from the edges are unchanged
Every existing gesture, swipe, click blocking and Dock swipe blocking behaviour for contacts landing outside the edge band MUST stay as it is. The existing test suite MUST pass unchanged.

### R3. The rule is in the glossary and in one place in code
The 3 mm band MUST be a named constant in `GestureRules`. `docs/domain-model.md` MUST describe it: the *Tap* entry's finger count excludes contacts landing at the edge, with a short new entry for the edge contact, and `docs/architecture.md` follows if it describes what the recognizer counts as a finger.

## Non-goals

- **Rejecting palms that land inside the surface.** The recording shows palms only at the edge, and a palm well inside the pad cannot be told from a flat finger by position. Shape-based rejection is left out for the reasons above.
- **A contact landing inside the anchor corner while a thumb is already anchored.** It keeps counting as a finger, as today. Changing it would touch the anchor rules, which this bug does not involve.
- **Making the band user-tunable.** It is a fixed rule like the other `GestureRules` numbers.
- **Changing the platform adapter's parsing** (which driver states count as down). The palm contact really is in the touching state on the frames that cause the fire, so the parsing is right.

## Implementation Decisions

1. **One new rule number: the edge band, 3 mm, in `GestureRules`.** `edgeBandMM = 3.0`, documented like its neighbours: a contact landing closer than this to any edge of the surface, outside the anchor corner's admission zone, is an edge contact, not a finger. Strictly less than 3 mm is inside the band, matching how `anchorReleaseMarginMM` and `clickBlockingWindow` read their bounds; the normalised coordinates make an exact 3.000 mm meaningless in practice, and the tests sit at 2.5 and 3.5 mm like the drag threshold's.

2. **A new module beside `AnchorCorner`: `EdgeContacts`.** A `package struct`, `Sendable`, in the same file and at the same visibility as `AnchorCorner`. It is the recognizer's memory of which contact IDs are edge contacts. Its whole interface is an initialiser taking the recognizer's `AnchorCorner` and `SurfaceSize`, and one mutating function that takes a `TouchFrame` and returns the same frame (same time, same press) with its edge contacts removed from `touches`; it must be called once per frame, in frame order, like `step` itself. Nothing else is exposed: no "is this an edge contact" query, no band geometry.

   Inside it:
   - The band test is the distance to the nearest edge in millimetres (the smallest of the four edge distances, scaled by the surface's width or height) compared with `edgeBandMM`, and then `AnchorCorner.admits` as the carve-out. Anything the corner admits is never an edge contact, whether or not a thumb is anchored (the non-goal on a second contact inside the corner holds).
   - A contact is *landing* on a frame when its phase is `.landing` or its ID was not down on the previous frame. This is the same rule `step` already applies and the `Touch` doc states; `EdgeContacts` keeps its own set of the IDs down on its previous frame (every contact, before any is dropped), because the recognizer's own `previouslyDown` will no longer contain edge contacts.
   - A landing contact is judged afresh by its landing point: into the set if it is in the band outside the corner, out of the set otherwise (so an ID the driver reuses straight from a palm to a finger is cleared, not just added). A contact that is not landing keeps its judgement, so a finger that slides into the band stays a finger and an edge contact that slides inward stays an edge contact. An ID absent from the frame is forgotten, so a driver ID that lifts and lands anew is judged by its new landing point.
   - The returned frame keeps `touches` in their original order with the edge contacts removed, nothing reordered: `step` picks the thumb as the first admitted landing in frame order, and that choice must not change.

3. **The recognizer drops edge contacts before its state machine sees the frame.** `GestureRecognizer` holds one `EdgeContacts`, built in `init` from the corner and surface it already builds, and the first line of `step` replaces the frame with the frame without edge contacts. Every line after that is unchanged: `previouslyDown`, `landed`, `lifted` and `reused`, the arming test that the thumb is the only contact down, the tap's finger count, the drag check, the swipe's joining and cancelling, and both blocking flags all see fingers only. The first-frame rule (a thumb landing on the first frame gets a click-blocking window; an already-resting one does not) is untouched; an edge contact alone on the first frame yields an empty first frame.

   Two hand-offs follow from "landed" meaning the same thing on both sides: when the driver reuses an ID and a finger's ID re-lands at the edge with no absent frame between, the recognizer sees the ID vanish, which is a lift, and the tap fires or spoils as it would for any lift; when an edge contact's ID re-lands inside the surface, the recognizer sees a new ID land. No special case is needed in `step` for either.

4. **No change anywhere else.** The platform adapter's parsing stays as it is (the non-goal: the palm really is in the touching state on the frames that fire). No port, no public type and no public signature changes; `GestureRecognizer.init` keeps its four parameters. The `Recognition` doc comments on `blocksClicks` and `blocksDockSwipes` that say "another contact is down" are reworded to "another finger is down", since that is what the flags mean once edge contacts are dropped; left as they are they would be wrong.

5. **Docs.** `docs/domain-model.md`: the *Tap* entry's finger count also excludes edge contacts, and a new *Edge contact* entry sits after *Anchored thumb*. `docs/architecture.md` is unchanged: it never describes what the recognizer counts as a finger, only where recognition runs.

## Testing Decisions

### Strategy

One seam, the one every gesture rule is already proven at: `GestureRecognizer.step`, fed hand-built frames and read through the existing `fired`, `phases` and `phasesMatch` helpers in `LauncherKit/Tests/LauncherCoreTests/Fixtures.swift` plus one private helper of the new suite's own that runs a fresh recognizer over the frames and returns the full `Recognition` per frame (the existing `perFrame` returns only the swipe phase and `blocksClicks`; the rows here read `fired`, both blocking flags and the swipe phase per frame, so one helper serves them all), in the style of `ClickBlockingRecognizerTests` and `DockSwipeBlockingRecognizerTests`. Frames come from `TouchScript` where its builder can say the sequence and from `HandFrames` where contacts must move or land while others are down. The new tests live in one new suite beside `GestureRecognizerTests`, `SwipeRecognizerTests` and the two blocking suites in `LauncherKit/Tests/LauncherCoreTests/`, and resemble them line for line.

This seam observes everything R1 lists: what fires and on which frame, every swipe phase and its travel, and both blocking flags per frame. `EdgeContacts` is reachable at package visibility but is not tested on its own: the recognizer seam proves every one of its behaviours, and its interface is not something a caller other than the recognizer needs. What the seam misses is the real driver's parsing and the real palm's shape; the replay harness under `.temp`, rebuilt against the changed sources, covers that once by hand (see the slice) and is not committed. Nothing is faked: the recognizer is a pure value, and the clock is the frame timestamps.

### Test scenarios

Surface `macBook14` (124.8 × 76.8 mm), right-hand mode, thumb ID 9 at (10, 10) mm and fingers at (62, 45) mm unless a row says otherwise; coordinates are millimetres from the top-left corner as `HandFrames` and `TouchScript` take them. "Edge" positions: 1 mm from the right edge is x = 123.8.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | recognizer, `fired` | The reproduction, mirrored by hand with `HandFrames` at 10 ms as two palm bursts under one anchored thumb: thumb 3 lands at (11, 10) and slides inside the corner toward (21, 20) and back; while it slides, contact 2 lands at (124.1, 52), is down on the next two frames and absent on the third (the recording's 24 ms burst); 200 ms later contact 2 lands again at (123.9, 50), is down for five more frames moving under 1 mm (the recording's 56 ms burst), then lifts; the thumb lifts last. Then nothing fires. Before the fix the same frames fire `.one` twice. (The recording's own two fires were 5 s apart with the thumb re-landing between them; the mirror compresses that, which changes nothing the recognizer reads.) | R1 scenario 1: "no gesture fires"; the recording's geometry (palm at x ≥ 0.988, 24 ms and 56 ms contacts) |
| T2 | R1 | recognizer, `fired` | Thumb anchored. An edge contact lands and lifts after 120 ms, parametrised over its landing point: left (1, 45), top (62, 1), bottom (62, 75.8), right (123.8, 45), top edge just outside the corner's admission zone but inside its 2 mm hold margin (26, 1), and on `magicTrackpad` right (159, 60). Then a finger taps at (62, 45). Then `fired == [.one]`: the edge tap fired nothing and the next tap still fires. Before the fix every point gives `[.one, .one]`; so does the (26, 1) point if the carve-out were `holds` instead of `admits`. | R1: "does not start … a tap", "within 3 mm of any edge", "outside the anchor corner's admission zone"; the problem statement: measured in millimetres, so the same on every size |
| T3 | R1 | recognizer, `fired` | Thumb anchored. Two edge contacts land together at (123.8, 40) and (123.8, 60) (`HandFrames`: the script builder spaces fingers 8 mm apart in x, which would leave the surface) and lift together after 120 ms. Then nothing fires. | Problem statement: "Two palm contacts within one tap read as a 2-finger tap"; R1 |
| T4 | R1 | recognizer, per-frame `fired`, `phases` | Thumb anchored. Finger 1 lands at (62, 45); 20 ms later contact 2 lands at the bottom edge at (62, 75.8) and slides 20 mm sideways along it to (82, 75.8) over the following frames; finger 1 lifts 120 ms after landing; contact 2 stays until 300 ms. Then `.one` fires on the frame finger 1 is first absent and on no other, and no swipe phase is reported. Before the fix contact 2 and finger 1 form a pair whose sideways drag begins a swipe, and nothing fires. | R1: "does not … join, count toward, drag, spoil or fire a tap", "does not begin … a swipe"; glossary *Tap* finger count, *Swipe* |
| T5 | R1 | recognizer, `fired` | Contact 2 is down at (123.8, 45) on the first frame, parametrised over its phase on that frame: `.landing` (it just landed) and `.down` (recognition restarted while a palm rested; `HandFrames`, since the script builder always emits `.landing` on a contact's first frame). It stays down, unmoved, until after the finger has lifted. The thumb lands 50 ms later and a finger taps at (62, 45). Then `fired == [.one]`. Before the fix the thumb lands with another contact down, never arms, and nothing fires. | R1 scenario 2: "the 1-finger gesture fires"; R1: "nor a second contact that stops a thumb from arming"; `Touch` doc: an ID appearing without `.landing` is landed too |
| T6 | R1 | recognizer, `fired` | The thumb lands 1 mm from both corner edges and a finger taps at (62, 45): right-hand thumb at (1, 1); left-hand thumb at (123.8, 1). Then `fired == [.one]` in each. A guard: it passes before and after the fix and catches a band that forgets the corner carve-out. | R1 scenario 3: "the 1-finger gesture fires"; glossary *Anchor corner* |
| T7 | R1 | recognizer, `fired` | Thumb anchored. One finger taps at a distance from an edge, parametrised over surface, edge and distance: `macBook14` right edge 2.5 mm (x = 122.3) fires nothing, 3.5 mm (x = 121.3) fires `.one`, 4 mm (x = 120.8) fires `.one`; `macBook14` bottom edge 2.5 mm (y = 74.3) fires nothing, 3.5 mm (y = 73.3) fires `.one`; `magicTrackpad` right edge 2.5 mm (x = 157.5) fires nothing, 3.5 mm (x = 156.5) fires `.one`. The "fires nothing" rows fail before the fix; the "fires" rows are guards: the bottom rows catch a y scaled by the width, the Magic Trackpad rows a band measured as a fraction of the surface instead of millimetres. | R1: "within 3 mm", "of any edge"; R1 scenario 4: "4 mm from the right edge … fires"; the problem statement: "measured in millimetres, so it is the same on every trackpad size" |
| T8 | R1 | recognizer, per-frame `Recognition` | Thumb lands at 0 ms. At 100 ms a finger lands at (115, 45), slides to (123.8, 45) by 200 ms, rests there and lifts at 600 ms. Then both blocking flags are true on every frame from the finger's landing to its last frame down, including the frames it spends inside the band, false before and after, and nothing fires (an overlong drag). A guard: it passes before the fix, when everything is a finger; it catches a filter that judges each contact by its current position on every frame instead of at its landing. | R1: "A contact that lands outside the band and later slides into it stays a finger"; glossary *Click blocking* and *Dock swipe* rule: "another finger is on the trackpad" |
| T9 | R1 | recognizer, per-frame `fired` | Thumb anchored. (a) ID 2 lands at (123.8, 45), lifts after 120 ms (absent for a frame), lands at (62, 45), lifts after 120 ms: `.one` fires on the second lift only. (b) ID 2 lands at (62, 45), is down for two frames, then appears with `.landing` at (123.8, 45) on the very next frame (the driver reused the ID with no absent frame), stays two frames and lifts: `.one` fires on the frame it re-lands at the edge, and nothing after. (c) ID 2 lands at (123.8, 45), is down for one more frame, then appears with `.landing` at (62, 45) on the very next frame, stays two frames and lifts: `.one` fires on its lift frame only. Before the fix (a) and (c) fire twice and (b) fires on the re-landing and again on the lift; a filter that only ever adds IDs to its set and never clears one on an inward re-landing fires nothing in (c). | R1: "A driver ID that lifts and lands anew is judged afresh"; `Touch` doc on reused IDs; `GestureRecognizerTests.reusedTouchIDLandingAgainStartsASecondTap` |
| T10 | R1 | recognizer, `phases`, `fired` | Thumb lands at 0 ms. At 100 ms fingers 1 and 2 land at (62, 45) and (70, 45); at 110 both have moved 4 mm right; at 120 both have moved 4 mm more and contact 3 lands at (123.8, 60); at 130 both move 4 mm more and contact 3 has moved to (123.8, 70); at 140 only the thumb and contact 3 remain; at 150 the thumb alone. Then the phases match (`phasesMatch`, travel within 1e-9) `.began`, `.moved(4)`, `.moved(8)`, `.ended`: no `.cancelled`, and nothing fires. Before the fix contact 3's landing cancels the swipe at 120 ms. | R1: "does not … cancel a swipe"; glossary *Swipe*: ends when both fingers lift, cancelled only by a third finger; travel convention of `SwipeTravelAndExitTests.travelIsTheMidpointsMovementSinceTheBeginAndOnlySentWhenItChanged` with `.linear` |
| T11 | R1 | recognizer, per-frame `Recognition` | Thumb lands at 0 ms; at 100 ms contact 2 lands at (123.8, 45); at 110 it is still down; at 120 finger 1 lands at (62, 45); at 130 finger 1 is absent and contact 2 still down. Then (clicks, Dock) per frame are (false, false), (false, false), (false, false), (true, true), (false, false). Before the fix both flags are true from 100 ms on. | R1: "counts as neither 'another contact down' for click and Dock swipe blocking"; glossary *Click blocking*, *Blocking window* |
| T12 | R1 | recognizer, `fired` | Thumb anchored. Contact 2 lands at (123.8, 45), slides 2.5 mm inward over its hold to (121.3, 45), 3.5 mm from the edge and outside the band, and lifts 120 ms after landing (`TouchScript`'s `dragMM: -2.5`). Then a finger taps at (62, 45). Then `fired == [.one]`. Before the fix `[.one, .one]`, since 2.5 mm is under the drag threshold; a filter that re-judges a contact when it leaves the band gives `[.one, .one]` too, because the recognizer then sees a new contact land at 121.3 that never drags. | R1: "MUST NOT count as a finger for the rest of its contact"; glossary *Edge contact*: "ignored for as long as it stays down"; the recording: the palm rolls from 1.2 mm to 2.1 mm off the edge within the 56 ms burst |
| T13 | R1 | recognizer, per-frame `Recognition` (`phasesMatch`) | Thumb lands at 0 ms. At 100 ms fingers 1 and 2 land at (62, 45) and (70, 45); at 110 both have moved 4 mm right (`.began`); at 120 finger 2 has lifted and finger 1 is at (70, 45); at 130 finger 1 is at (74, 45) and contact 3 lands at the bottom edge at (62, 75.8); at 140 finger 1 is at (78, 45) and contact 3 at (70, 75.8); at 150 only the thumb and contact 3 remain; at 160 the thumb alone. Then the phases per frame are `.began` at 110, `.moved(4)` at 120, `.moved(8)` at 130, `.moved(12)` at 140, `.ended` at 150 and nothing at 160; nothing fires. Before the fix contact 3 rejoins the swipe as its second finger, its 8 mm averages into the move at 140 (`.moved(14)`), and `.ended` waits for its lift at 160. | R1: "does not begin, join, move … a swipe"; glossary *Swipe*: "a finger that briefly loses contact and lands again rejoins it", "ends when both fingers have lifted"; the one-finger travel convention of `SwipeTravelAndExitTests.oneFingerLiftingLeavesTheSwipeOnAndTheOtherKeepsMovingItUntilItLifts` |

### Verified without a test

- **R2** (everything away from the edges unchanged): the existing suite stays green through `Scripts/test.sh` with no existing `@Test` edited or removed; the suite's contacts all land at least 10 mm from every edge (the nearest is the left-hand thumb at x = 114.8 mm), so a green run proves the rule changed nothing for them. A new test cannot prove "unchanged" better than the tests that defined the behaviour.
- **R3** (one constant, in the glossary): `grep -rn edgeBandMM LauncherKit/Sources` returns exactly two lines, the declaration in `GestureRules.swift` and its one read in `Surface.swift` (the literal `3.0` cannot be grepped for, since `dragThresholdMM` is 3.0 too); `git diff main -- docs/domain-model.md` shows the *Tap* entry excluding edge contacts and the new *Edge contact* entry, and `git diff main -- docs/architecture.md` is empty, since that document does not describe finger counting. Where a number lives and what a document says are not test subjects.

## Further Notes

- **The regression lives in the hand-written T1, not the recording.** The raw recording (96 KB) and the recorder and replay binaries under `plans/007-one-finger-false-tap/.temp/` are not committed; `.temp` is not git-ignored, so the implementer removes it or excludes it from the commit. The replay stays available during the work: rebuild it with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftc -swift-version 6 -package-name LauncherKit -O LauncherKit/Sources/LauncherCore/*.swift plans/007-one-finger-false-tap/.temp/replay/main.swift -o plans/007-one-finger-false-tap/.temp/replay/replay` and run it on `rec1.txt`; it prints two `fired(Gesture.one)` events today and must print nothing after the fix.
- **Why the carve-out is the admission zone, not the held zone.** `AnchorCorner.holds` grows the corner by 2 mm for a thumb that is already anchored; a contact landing in that margin was never admitted as a thumb and is a finger or an edge contact by its position like any other. Using `admits` keeps the thumb rule and the edge rule from overlapping.
- **The hovering palm never reaches the recognizer.** In the recording the palm hovers (driver states 1 and 2) far longer than it touches; the adapter drops those states, so only its 24–60 ms touching bursts arrive. The second brief contact near the bottom-right corner in the recording only ever hovered and was never seen. The 2-finger case from the problem statement is two touching bursts overlapping, which T3 covers.
- **Top edge beside the corner.** In right-hand mode a contact landing 1 mm from the top at x = 30 mm is outside the corner and so an edge contact; it was never a thumb (not admitted) and until now counted as a finger. That is the intended reading of R1.

## Slices

### S1: Edge contacts dropped before the state machine

**What to build:** A palm's edge brushing any edge of the trackpad while the thumb is anchored no longer fires a tap, spoils a tap, cancels a swipe or blocks clicks and Dock swipes, and a thumb can still anchor at the very corner. The band constant, the `EdgeContacts` module beside `AnchorCorner`, the one-line change at the top of `step`, the new test suite, and the glossary already updated in this plan.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13.

- [x] T1 is written first and fails on the unchanged recognizer by firing `.one` twice, then passes.
- [x] T2–T13 pass; the rows the table marks as failing before the fix were seen red first, and the guard rows (T6, T7's "fires" rows, T8) were not expected to be.
- [x] R2: `Scripts/test.sh` is green with no existing `@Test` edited or removed.
- [x] R3: `grep -rn edgeBandMM LauncherKit/Sources` returns exactly the declaration in `GestureRules.swift` and one read in `Surface.swift`; `EdgeContacts` sits beside `AnchorCorner` at the same visibility; `docs/domain-model.md` matches the code (the *Tap* entry and the *Edge contact* entry) and `git diff main -- docs/architecture.md` is empty.
- [x] The replay harness, rebuilt against the changed sources, prints nothing for `rec1.txt`.
- [x] `plans/007-one-finger-false-tap/.temp/` is not in the commit.
