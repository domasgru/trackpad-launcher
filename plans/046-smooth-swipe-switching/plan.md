# Plan: Smooth switcher travel

## Problem statement

During a swipe (and a window swipe) the switcher's highlight sometimes leaps, although the fingers move at a steady pace. The user sees the selector rectangle jump by up to several icons in one frame, or jerk forth and back.

The bug was reproduced end to end: a Debug build recorded 18 real swipes on the built-in trackpad (every multitouch frame, every recognised event, every main-actor delivery and every render). Two of them are kept in `recorded-swipes.txt` beside this plan. The recording rules out timing: frames arrive every 8.00 ms on the driver's clock, the hop to the main actor and each render take about a millisecond, and no frame is late. The leaps are in the travel the recognizer reports. Replaying the recorded frames through a port of today's travel maths reproduces the recorded travel to the last digit, and shows 99 single-frame leaps (a step over 2 step millimetres and over 2.2 times its neighbours) in 18 swipes, the worst 32 step millimetres (2.7 icons) in one 8 ms frame.

Two root causes, both in `GestureRecognizer`'s `.swiping` step (`LauncherKit/Sources/LauncherCore/GestureRecognizer.swift`), which turns each frame's finger movement into travel on its own:

1. **The driver's per-frame movement is uneven, and the cursor's acceleration is applied per frame.** At a steady pace the driver reports movement that alternates frame to frame (for example 15, 30, 15, 30 thousandths of the surface width), and just before the fingers stop it reports one catch-up frame of 3 to 5 times its neighbours (12, 62, 6, 5, 4, …; `recorded-swipes.txt`, swipe 2, the frame 0.512 s after its begin). The movement is real in total, only unevenly split over frames. `SwipeTravel.cursor` feeds each frame's movement alone into `PointerCurve.cursorMove`, whose gain grows with speed, so a frame with 5 times the movement gets 12 times the travel: 2.7 step millimetres on one frame, 32.2 on the next. Because the curve is convex, the unevenness also inflates the total.
2. **A swipe finger that loses contact for a moment makes the other finger's reported position snap away and back.** When one of the two fingers goes out of range for two or three frames (a light slide), the driver reports the remaining finger about 7 mm away on that frame, and back again one or two frames later, before the first finger returns (`recorded-swipes.txt`, swipe 4, the frames 1.136 s and 1.152 s after its begin: +22.9 then −18.5 step millimetres from a finger that was moving 0.2 mm a frame). The recognizer takes both snaps as movement. The existing rule "movement is what the fingers present on both frames did" covers the finger that dropped out, not the one that stayed.

No existing test covers either: every swipe test feeds evenly spaced, noise-free synthetic movement, and `aFingerThatDropsOutAndComesBackWithANewIDRejoinsWithoutAJump` keeps the remaining finger's reported position clean.

One more thing the recording shows is not part of this change (see Non-goals): the first render of a swipe takes 16 to 40 ms (90 ms for the first swipe of the process), so the highlight first appears wherever the fingers have got to.

## Requirements

### R1. Travel follows the fingers' movement averaged over a short window
A slide's travel on each frame MUST be derived from the swipe fingers' movement averaged over the last 4 frames (the frame's own and the 3 before it, frames before the slide began counting as no movement), not from the frame's movement alone: the averaged movement is what `SwipeTravel` turns into travel, so with `.cursor` the acceleration sees the averaged speed. A frame with no finger present on both frames, and a frame whose only movement R2 discards, counts as no movement and still advances the window, so travel keeps catching up while the fingers rest. With `.linear`, the travel after 3 further frames MUST equal the fingers' total movement along the slide. The window is a named constant in `GestureRules`.

#### Scenario: A catch-up frame no longer leaps
- **GIVEN** the recorded swipe 2 of `recorded-swipes.txt`, replayed frame by frame through a `GestureRecognizer` for a 124.8 × 76.8 mm surface with the recorded tracking speed's curve (`PointerCurve(PointerCurve.builtInCurves, trackingSpeed: 0.6875)`, 100 points per step)
- **WHEN** the frames around 0.512 s after its begin are stepped
- **THEN** no frame's travel step in the whole swipe is both over 2 step millimetres and over 2.2 times the mean of its two neighbours' steps (today: 32.2 after 2.7)

#### Scenario: Steady movement stays steady
- **GIVEN** two fingers sliding 4 mm a frame with `.linear` travel
- **WHEN** the slide has run for 4 frames or more
- **THEN** each frame adds 4 step millimetres, and once the fingers stop the travel reaches the fingers' total movement within 3 frames

### R2. A remaining finger's snap while the other is out of contact is not movement
While only one swipe finger is down, that finger's movement on each frame is judged in this order:

1. **The undo of a snap.** A discarded snap is remembered, as the vector the finger moved by, for the next 4 frames. While one is remembered, a movement that undoes it MUST be discarded too, and the snap is then forgotten. A movement undoes a snap when the sum of the two vectors is at most half as long as the snap.
2. **A snap.** Otherwise the movement MUST be discarded, and remembered as a snap, when it is longer than 2 mm and longer than 3 times the finger's movement on its previous counted frame plus 1 mm. Two movements are never judged so and MUST be counted, whatever their length: the first movement of a finger with no counted movement yet in the slide (on the first frame after the slide began, or the first after it rejoined), and a finger's movement on the frame right after a discarded one.
3. **Anything else** is counted. A counted movement becomes the reference for the next.

So a finger is never discarded on two frames in a row, save for a snap and its undo; its sustained movement is never swallowed; and a lone finger that starts abruptly loses one frame at most. A discarded movement still updates the finger's last position, so its later movement counts from where it is. A remembered snap is also forgotten when the finger lifts or the slide again has two fingers down. With both swipe fingers down, nothing is discarded. The 4 frames, the half and the three thresholds are named constants in `GestureRules`.

The snap the recording shows goes away on one frame and comes back two frames later: the away is discarded, the ordinary frame between is counted, and the back undoes the away. A snap that goes away and comes back on adjacent frames is discarded the same way, both frames, so the travel stays where the fingers are.

#### Scenario: The recorded snap
- **GIVEN** the recorded swipe 4 of `recorded-swipes.txt`, replayed as in R1
- **WHEN** the frames 1.136 s and 1.152 s after its begin are stepped (one finger out of range, the other reported about 7 mm away, then back)
- **THEN** the travel changes by less than 1 step millimetre across those frames (today: +22.9, then −18.5), and the R1 scenario's bound holds for the whole swipe

#### Scenario: One finger lifts for good and the other keeps sliding
- **GIVEN** a slide whose first finger lifts while the second keeps moving at its pace
- **WHEN** the second finger moves on
- **THEN** its movement still moves the travel, as today

#### Scenario: A lone finger that starts abruptly
- **GIVEN** a slide whose first finger has lifted, and whose second finger rests and then moves 2.4 mm a frame for five frames, with `.linear` travel
- **WHEN** those frames are stepped
- **THEN** only the first of the five is discarded: the other four move the travel, 9.6 step millimetres in all once it has caught up

#### Scenario: A snap away and back on adjacent frames
- **GIVEN** a slide with one finger out of contact while the other, moving 0.2 mm a frame, is reported 7 mm away on one frame and back on the very next, with `.linear` travel
- **WHEN** both frames are stepped
- **THEN** both are discarded, the back as the undo of the away, and the travel ends where the fingers are

#### Scenario: A lone finger that starts abruptly and turns back
- **GIVEN** a slide whose first finger has lifted, and whose second finger rests, moves 2.4 mm a frame for five frames and then moves back 2.4 mm a frame, with `.linear` travel
- **WHEN** those frames are stepped
- **THEN** only the first fast frame is discarded: the frame the finger turns back on is the fifth after it, the snap is no longer remembered, and the movement back is counted

### R3. Everything else about a slide is unchanged
The begin, end and cancel of a swipe and a window swipe, their blocking, the rejoin of a finger with a new ID, the selection's rules (`SwitcherSelection`) and the lift MUST behave as today. The lift selects what the highlight shows: movement still inside the averaging window when the fingers lift is not added. Travel stays 0 on the frame a slide begins. No timer, display link or per-display-frame code is added: travel advances only on trackpad frames, on the frame thread, as today.

## Non-goals

- **The first render of a swipe.** The row's first layout and presentation take 16 to 40 ms (90 ms once per process), during which the fingers already move, so the highlight first appears a little along the row. It is one late first frame, not a leap during the movement, and it lives in `LauncherUI`, not in the travel. A separate change if the user wants it.
- **Changing the acceleration curve, the 12 step millimetres per item or the 100 points per step.** The reach of a swipe changes only by what the unevenness used to inflate (about 5 % less travel over the recorded swipes).
- **Animating the highlight between frames.** The highlight keeps following travel directly; smoothing is in the travel, so the selection, the ticks and the highlight stay one thing.
- **Recording or diagnostics in the app.** The probe used for the reproduction was temporary and is not part of the change.

## Evidence

- `recorded-swipes.txt`: two of the recorded swipes, every frame, for the replay tests.
- Prototype on all 18 recorded swipes (travel maths ported to a script, checked against the recorded travel): leaps as defined in R1's scenario 99 today; 31 with only the speed averaged; 2 with the movement averaged over 4 frames; 0 with R1 and R2 together. Total travel 94 % of today's. Worst single step 11.9 step millimetres, in a sustained fast flick.

## Implementation Decisions

- **One module changes: the recognizer's slide step.** Both root causes sit where one frame of a slide becomes travel, inside `GestureRecognizer`, and both fixes go there. Its interface is unchanged (`init`, `step`, `answerWindowSwipe`, the settable `travel`), and so are `Recognition`, `SwipePhase`, `SwipeTravel`, `PointerCurve`, both hardware adapters, `Launcher`, `SwitcherSelection` and every view. `SwipeTravel.travel(along:dxMM:dyMM:interval:)` keeps its signature and its maths: it is handed the averaged movement where it was handed the frame's own. No new seam, no new port, no new type outside the recognizer.

- **What a slide remembers.** The recognizer's private slide state gains two things, both of which go when the slide does:
  - per swipe finger, beside its position on the last frame: the length in millimetres of its last counted movement, or nothing until one has been counted in this slide; whether its movement on the last frame was discarded; and the snap it is remembered for, if any, as that movement's vector in millimetres and the number of frames it is still remembered;
  - the fingers' movement on each of the last 4 frames, in millimetres along x and y: at most 4 entries, none on the frame the slide begins.

  This is slide state, not `SwipeTravel` state. The real adapter replaces `travel` on the frame a slide begins and the Debug tuner may replace it between frames; neither may empty the window.

- **One frame of a slide, in order.** For a frame on which the slide neither ends nor is cancelled (from the planning prototype, trimmed to the decisions; the names are the prototype's):

  ```swift
  let isAlone = swipe.fingers.count + joining.count == 1        // R2's "while": one still down, none rejoining
  var counted: [(dxMM: Double, dyMM: Double)] = []
  for (id, finger) in swipe.fingers {                           // the fingers present on both frames
      let move = millimetres(from: finger.position, to: down[id].position)
      let length = hypot(move.dxMM, move.dyMM)
      let snap = isAlone ? finger.rememberedSnap : nil          // two fingers down: nothing is remembered
      let undoesSnap = snap.map {                               // judged first, whatever the frame before was
          hypot(move.dxMM + $0.dxMM, move.dyMM + $0.dyMM) <= snapUndoShare * hypot($0.dxMM, $0.dyMM)
      } ?? false
      let isSnap = isAlone && !undoesSnap
          && !finger.wasDiscardedLastFrame                      // the frame right after a discard is counted
          && length > snapMinMM
          && finger.lastCountedMM.map { length > snapRatio * $0 + snapSlackMM } ?? false  // no counted movement yet: counted
      swipe.fingers[id].position = down[id].position            // always, discarded or not
      swipe.fingers[id].wasDiscardedLastFrame = isSnap || undoesSnap   // the mark lasts exactly one frame
      swipe.fingers[id].rememberedSnap =
          isSnap ? (move, framesLeft: snapMemoryFrames)         // the newest snap replaces an older one
          : undoesSnap ? nil                                    // undone: forgotten
          : snap?.agedByOneFrame                                // nil once its 4 frames are over, and with two fingers down
      if !(isSnap || undoesSnap) { counted.append(move); swipe.fingers[id].lastCountedMM = length }   // the reference
  }
  swipe.window.push(mean(counted) ?? (0, 0))                    // always: a frame with nothing counted is no movement
  let averaged = swipe.window.sum / Double(travelAveragingFrames)   // by the constant: frames before the begin are zeros
  let travel = swipe.travelMM
      + self.travel.travel(along: swipe.kind, dxMM: averaged.dxMM, dyMM: averaged.dyMM, interval: interval)
  if travel != swipe.travelMM { swipe.travelMM = travel; event = .moved(travelMM: travel) }
  ```

  The lift, the cancel, the thumb's bookkeeping and the rejoin of a finger keep the flow they have around this. On the frame a slide begins none of it runs: travel is 0 and the window is empty, so the frame after adds a quarter of its movement.

- **What the requirements leave open, decided here.**
  1. *The interval.* Only the movement is averaged. The conversion is given this frame's own interval, as today. Frames arrive every 8 ms for as long as a contact is down, so a mean interval would be the same number.
  2. *The sum is divided by the window's size, always.* That is what "frames before the slide began counting as no movement" means: travel ramps in over the first 3 frames and out over the 3 after the fingers stop, and the two ramps add up to the fingers' whole movement.
  3. *The swipe fingers down on a frame* are those still down plus those rejoining on it. So a finger the driver lifts and lands within one frame leaves two down and nothing is judged, and the frame on which a finger rejoins judges nothing either. A slide has at most two swipe fingers, so R2 only ever judges one finger, and the recognizer keeps no count from the frame before.
  4. *The frame after a discard.* The mark that a finger's last movement was discarded lasts exactly one frame, and an undo sets it as a snap does. The next frame is counted and becomes the reference whether the finger is still alone on it or not, unless it undoes the snap; the frame after that is judged as usual. So the longest run of discards is two frames, a snap and its undo.
  5. *What is remembered of a snap.* Its vector as measured on its own frame, for the 4 frames after it: a movement on the fifth is judged as if there had been no snap. An undo is one frame's movement set against that vector, whatever the finger did in between, so the ordinary frame between the recording's away and back changes nothing. The undo is judged before the snap rule: a snap back that the snap rule would discard too, as the recording's would be, is discarded as the undo and the memory is cleared. A new snap replaces a remembered one. The memory goes with the finger when it lifts, and is dropped on any frame with two swipe fingers down.
  6. *A frame on which a finger did not move is a counted frame*, of length 0. R2's wording has it so, and the recorded snap needs it: the finger was nearly still before it snapped.
  7. *"Longer than" is strict and "at most half" includes the half*; the lengths and vectors are the finger's own movement on the surface in millimetres (both axes), not travel.
  8. *Nothing is flushed.* When the slide ends or is cancelled the window is dropped with the rest of the slide state; no last `.moved` is sent. A window swipe still waiting for its answer fills its window like any slide.

- **Constants.** `GestureRules` gains six named numbers, each with the measurement behind it in its comment: the averaging window (4 frames); the snap's three thresholds (longer than 2 mm, longer than 3 times the last counted movement, plus 1 mm); how long a snap is remembered (4 frames); and the share of its length within which a movement undoes it (half). The recognizer reads them and holds no second copy.

- **Frame path.** The new state is private to the recognizer and lives beside its other slide state; no source file is added, so the source-scan test's lists stay as they are. Nothing runs outside `step`, no clock is read and nothing is scheduled.

- **Documents.** `docs/domain-model.md` gains the entry *Travel*, which holds the averaging, the snap rule and the lift rule; *Swipe*, *Switcher* and *Window switcher* point at it. `docs/architecture.md` does not change: travel still advances only on trackpad frames, on the frame thread.

## Testing Decisions

### Strategy

**Seams.** Three, all existing:

1. **`GestureRecognizer.step(_:)`**, the seam of every swipe travel test today (`LauncherKit/Tests/LauncherCoreTests/SwipeTravelAndExitTests.swift`, `WindowSwipeRecognizerTests.swift`, `EdgeContactRecognizerTests.swift`). Frames in, one `Recognition` out, no clock and no thread. It observes every frame's event and its travel to the last digit, with `.linear` travel or with a cursor curve. It carries R1 and R2 whole: the two recorded swipes replayed as the driver delivered them, and hand-built frames for the worked examples. It misses the hop to the main actor and the render, which the recording ruled out as causes, and the user's own tracking speed, which the replays pin at the recorded 0.6875.
2. **`World`** (`LauncherKit/Tests/LauncherCoreTests/World.swift`): the real `Launcher` over `InMemoryTrackpads`, which steps real recognizers with `.linear` travel. It observes the selection, the ticks, the raises and what a lift brings to the front. It carries R3's lift rule as the user meets it, and the existing switcher and window switcher tests. It misses the cursor curve.
3. **The source scan** (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`), for R3's "no timer, display link or per-display-frame code".

`DeviceSession.receive` (`LauncherKit/Tests/LauncherPlatformTests/DeviceSessionTravelTests.swift`) gets no new test: its code does not change, and the travel it installs follows the tracking speed of the Mac the tests run on, so no travel value can be asserted there. Its existing test stays green (T16).

**What is faked.** Nothing new. `World` runs over the in-memory adapters it has, and Rule C delivers its events through them. The recognizer reads no clock and nothing random; frame times come from the frames. The one file read is the tests' own fixture.

**What no test shows.** That the numbers are named constants in `GestureRules`: the tests pin their values with the requirements' literals (a window of 4 frames; 2 mm, 3 times and 1 mm; a memory of 4 frames and the half), and the naming is an acceptance criterion of S2 and S3, read in the diff.

**Harness changes** (test code only):

- **The recording as a fixture.** A byte-identical copy of `recorded-swipes.txt` lives in `LauncherKit/Tests/LauncherCoreTests/RecordedSwipes/`, found from the test file's own path as `LauncherKit/Tests/LauncherPlatformTests/UpdateFixtures.swift` finds its folder. The plan's copy stays as the evidence it is; no code reads it.
- **`RecordedSwipes`**, one helper beside it. It parses the file into its swipes: each `## swipe N: began at …, ended at …` header opens one, with the two timestamps kept. Every other line that does not start with `#` is one `TouchFrame` with no press. The core tests cannot reach the platform module, so the helper mirrors the adapter's parse rule, `TouchFrame(parsing:count:timestamp:press:)`, which `TouchFrameParsingTests` pins, and names it in its comment: only states 3 and 4 are contacts, 3 is a landing, each coordinate is read as a 32-bit float and then widened, and y is 1 minus the recorded value. It replays one swipe through a fresh recognizer for a 124.8 × 76.8 mm surface with the thumb corner top left (where the recorded thumb rests), both slide kinds and swaps on, and the travel a row names, from the recording's first frame, and returns the frame times on which `.began` and `.ended` came and the travel after every frame from the begin frame to the last frame before the end. A frame with no `.moved` keeps the travel of the frame before.
- **A leap**, as R1's scenario defines it, over that list: a frame's step is the absolute change of travel on it; a frame with a neighbour on both sides is a leap when its step is over 2 and over 2.2 times the mean of its two neighbours' steps.
- **`TouchScript.settle()`**: the fingers rest where they are for 3 frames. The 3 is R1's literal ("the travel after 3 further frames"), written as a literal and not read from `GestureRules`, so every test that settles fails if the window grows past 4. T2, T3, T11 and T12 are what hold it at exactly 4.
- **`World.swipe` and `World.windowSwipe`** settle after each slide and say so in their comments: their callers think in the millimetres the fingers reached.

**Existing tests, and why their update does not weaken them.** R1 changes every intermediate travel value and leaves every total alone once the fingers have rested 3 frames. A run of the whole suite against a prototype of R1 and R2 failed 26 existing tests and no other; each is updated by one of three rules, and no expected total, selection, tick count or window order changes:

- **Rule A, rest, then the same literal.** A scripted hand settles before its reach is read. The expected values stay the literals they are: 12.35 and −11.65 in every thumb corner on both surfaces, the midpoint at 6 mm, the turn-back points. These tests now also prove R1's "after 3 further frames equals the fingers' total movement".
- **Rule B, the whole sequence, re-derived.** A test of hand-built frames that asserts every phase keeps asserting every phase, compared to 1e-9 as today. Three rest frames are appended before the lift, so its last travel is the total it asserts today, and the values on the way come from the worked table below.
- **Rule C, one event that crosses several items arrives at the port.** After R1 no frame of finger movement makes a single `.moved` cross several items, but the model's rules for such an event still need their proof (one tick per item crossed; a raise only for the row landed on). Those tests begin and lift their slide by frames as before and deliver the jump as one `.moved` through the in-memory hardware's event stream, as `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored` in `SwitcherOnScreenTests.swift` already does, with the travel the frames used to produce: 36.35, 24.35, and 0.35 for the way back.

Rules A and C, and Rule B's rest frames, land first, in a tests-only slice (S1), against today's recognizer: a resting hand adds nothing today, so every edited test passes with the expected values it has now. That is the proof that nothing was loosened to fit the new behaviour. It was tried during planning: with the helpers' rests, Rule A's and Rule C's edits and no product change, the whole suite is green. Only Rule B's values on the way change afterwards, in S2.

**Worked table.** With `.linear` travel a frame adds a quarter of the sum of the fingers' movement on it and on the three frames before it. Travel after each frame, from the first frame after the begin:

| The fingers' movement on each frame after the begin (mm) | Travel after each frame (step mm) |
|---|---|
| 4, 4, 4, 4, 4, 4, then rest | 1, 3, 6, 10, 14, 18, then 21, 23, 24 |
| 2, 2, 2, 2, 2, then rest | 0.5, 1.5, 3, 5, 7, then 8.5, 9.5, 10 |
| 4, 4, then rest | 1, 3, then 5, 7, 8 |
| 4, 4, 4, then rest | 1, 3, 6, then 9, 11, 12 |
| 4, 4, 4, 4, then rest | 1, 3, 6, 10, then 13, 15, 16 |
| 24, then rest | 6, then 12, 18, 24 |
| 8, then rest | 2, then 4, 6, 8 |
| 14, 10, then rest | 3.5, 9.5, then 15.5, 21.5, 24 |
| 1, 1, 1, 1, 5, 1, 1, 1, 1, then rest | 0.25, 0.75, 1.5, 2.5, 4.5, 6.5, 8.5, 10.5, 11.5, then 12.25, 12.75, 13 |

In every row the third rest frame reaches the fingers' total, and a fourth sends nothing.

### Test scenarios

Hand-built frames are 10 ms apart on the 124.8 × 76.8 mm surface with the thumb anchored top left, as in `SwipeTravelAndExitTests.swift`: the pair lands, one frame moves it past 3 mm and begins the slide, and the movements a row lists are those of the frames after that one. "Out of contact" is a finger absent from the frame; it comes back as a landing with its own ID, as in the recording.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | `GestureRecognizer.step` | Given the recorded swipe 2, replayed with `.cursor(PointerCurve(PointerCurve.builtInCurves, trackingSpeed: 0.6875), pointsPerStep: 100)`. When every frame is stepped. Then the slide begins on the frame at 192530.758 and ends on the one at 192533.478; no frame of it is a leap; and the step on the frame 0.512 s after the begin is 11.88 within 0.05. Today: 8 leaps, the worst 32.16 after 2.69 on that frame. | The fixture and its header; R1's scenario (2 step mm, 2.2 times). The step, worked by hand from the fixture: over the four frames up to that one (192531.246 to 192531.270) the two fingers' mean movement along x is 1.87, 3.29, 1.58 and 7.75 mm, 14.48 in all, a quarter of which is 3.62 mm (and −0.09 mm along y); that is 57 counts a frame, for which `cursorMove(dxMM: 3.62, dyMM: -0.09, interval: 0.008)` gives 99.0 points along x; 99.0 ÷ 100 × 12 = 11.88, the worst step Evidence reports (11.9) |
| T2 | R1 | `GestureRecognizer.step` | Given `.linear` travel and two fingers sliding 4 mm a frame for 6 frames, then resting 4 frames, along a swipe and along a window swipe. Then the phases are `.began`, then travel 1, 3, 6, 10, 14, 18 (4 more on each frame from the fourth on), then 21, 23, 24 as the fingers rest, and the fourth rest frame sends nothing. Today: 4, 8, 12, 16, 20, 24, and nothing while they rest. | R1's scenario "Steady movement stays steady": each frame adds 4, and the total (6 × 4 = 24) within 3 frames; the worked table's first row |
| T3 | R1 | `GestureRecognizer.step` | Given `.linear` travel and both fingers moving 1, 1, 1, 1, 5, 1, 1, 1, 1 mm on successive frames, then resting. Then travel reads 0.25, 0.75, 1.5, 2.5, 4.5, 6.5, 8.5, 10.5, 11.5, 12.25, 12.75, 13: no frame adds more than 2 although one moved 5, and the total is 13. Today: 1, 2, 3, 4, 9, 10, 11, 12, 13, the fifth frame adding 5. | The worked table's last row; the total is the sum of the movements |
| T4 | R1 | `GestureRecognizer.step` | Given the recorded curve as in T1, one hand whose fingers move 1 and 3 mm on alternate frames for 10 frames, and one moving a steady 2 mm a frame for 10. Then from the fourth frame after the begin on, every frame of either hand adds the same travel, to 1e-9: `cursorMove(dxMM: 2, dyMM: 0, interval: 0.01).x` ÷ 100 × 12 (about 3.604). Today the 3 mm frames add several times what the 1 mm frames add. | R1: the acceleration sees the averaged speed, and the mean of 1, 3, 1, 3 is 2; the curve's own public conversion of one 2 mm frame; 100 points and 12 step mm an item from the domain model |
| T5 | R2 | `GestureRecognizer.step` | Given the recorded swipe 4, replayed as in T1. Then the slide begins at 192535.342 and ends at 192538.422; on the frames 1.136, 1.144 and 1.152 s after the begin the travel is within 1 step mm of the travel on the frame at 1.128 s; and no frame of the slide is a leap. Today: +22.88 on the first and −18.49 on the last. With R1 alone the leap bound already holds and the travel still moves 2.9 and 3.0 on the first two. The away (1.136 s) is discarded as a snap, the frame between is counted, and the back (1.152 s), two frames after the away, is discarded as its undo: the two vectors, about (5.6, −4.0) and (−4.7, 3.5) mm, sum to 1.0 mm against half the snap's 6.9. | The fixture and its header; R2's scenario (less than 1 step mm; R1's bound) |
| T6 | R2, R1 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move 0.2 mm a frame for 4 frames; finger 1 goes out of contact for 3 frames, on which finger 2 moves +7, +0.2 and −7 mm; finger 1 lands again while finger 2 moves 0.2; both move 0.2 for 2 frames; both rest 4 frames. Then travel reads 0.05, 0.15, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0, 1.15, 1.3, 1.45, 1.55, 1.6, and the last rest frame sends nothing. The away is discarded as a snap and the back, two frames later, as its undo, so neither adds anything; the 0.2 mm between them, the frame after a discard, counts from where the finger was reported; and travel keeps catching up on the frames whose only movement was discarded. With R1 alone the same frames read 2.4, 4.3, 4.4, 4.5, 2.9 after the first four. | Worked by hand from R1 and R2: the frames' movements are 0.2 × 4, 0, 0.2, 0, 0.2 × 3, then rest; the total is the eight counted frames × 0.2 |
| T7 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move `p` mm a frame for 4 frames, then finger 1 goes out of contact and on that frame finger 2 moves `a` mm, then rests 4 frames. For (`p`, `a`) = (0.2, 1.9), (0.5, 2.4) and (1.0, 3.9) the movement counts and the travel ends at 4 × `p` + `a`: 2.7, 4.4, 7.9. For (0.2, 2.1), (0.5, 2.6) and (1.0, 4.1) it is discarded and the travel ends at 4 × `p`: 0.8, 2.0, 4.0. | R2's literals: longer than 2 mm, and longer than 3 times the last counted movement plus 1 mm (1.6, 2.5 and 4.0 for the three `p`) |
| T8 | R2 | `GestureRecognizer.step` | Given `.linear` travel and both fingers down throughout: after 4 frames of 0.2 mm, (a) both jump 7 mm on one frame, (b) one jumps 7 mm while the other moves 0.2; then they rest 4 frames. Then the travel ends at (a) 7.8 and (b) 4.4: nothing is discarded. | R2: "With both swipe fingers down, nothing is discarded"; (a) 0.8 + 7, (b) 0.8 + the mean of 7 and 0.2 |
| T9 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers slide 4 mm a frame for 4 frames, finger 1 lifts for good, and finger 2 keeps sliding 4 mm a frame for 3 frames, then rests 4. Then travel reads 1, 3, 6, 10, 14, 18, 22, then 25, 27, 28: the frame of the lift and those after it add 4 like the ones before. | R2's scenario "One finger lifts for good and the other keeps sliding"; 7 frames × 4 = 28 |
| T10 | R2, R3 | `GestureRecognizer.step` | The existing `oneFingerLiftingLeavesTheSwipeOnAndTheOtherKeepsMovingItUntilItLifts` and `oneFingerLiftingLeavesTheSlideOnAndTheOtherKeepsSteering` (both kinds), by Rule B. On the first frame after the begin one finger has lifted and the other has moved 14 mm, then 10 mm, then rests 3 frames. Then the phases are `.began`, 3.5, 9.5, 15.5, 21.5, 24, `.ended`: a finger's first movement in a slide counts, whatever its length. | The tests' own total today (24); the worked table's row "14, 10"; R2: a finger's first movement in the slide is counted |
| T11 | R3 | `GestureRecognizer.step` | Given `.linear` travel and two fingers sliding 4 mm a frame for 6 frames, along a swipe and along a window swipe. When (a) both lift on the next frame, (b) a third finger lands outside the anchor corner on the next frame. Then the phases are `.began`, 1, 3, 6, 10, 14, 18 and then (a) `.ended`, (b) `.cancelled`, with no `.moved` after 18. Today the last travel is 24. | R3: movement still inside the window at the lift is not added; 24 less the window's (3 + 2 + 1) ÷ 4 × 4 = 6 |
| T12 | R3 | `World` | Given `switcherWorld` with Safari, Mail, Slack, Notes, Preview and Music, Safari frontmost. When the fingers slide 3.5 mm, then 48 mm in 100 ms, and lift on the very next frame, with no rest. Then on the last frame before the lift the selected app is Notes, the lift brings Notes to the front with one gesture haptic, and Preview is never selected. The same hand settling before the lift brings Preview. Today the first hand brings Preview. | R3: "The lift selects what the highlight shows". Worked: the fingers reach 0.35 + 48 = 48.35; the window still holds (3 + 2 + 1) ÷ 4 × 4.8 = 7.2; 41.15 ÷ 12 = 3.43, nearest 3 (Notes); 48.35 ÷ 12 = 4.03, nearest 4 (Preview) |
| T13 | R1, R3 | `GestureRecognizer.step` | The existing reach tests, by Rule A: `travelIsInTrackpadMillimetresAndPositiveToTheRightInEveryThumbCorner`, `travelIsInTrackpadMillimetresAndPositiveDownwardsInEveryThumbCorner` (8 corner and surface cases each) and `aSlideNeverTurnsIntoTheOtherKind` (both kinds). The fingers slide 3.5 mm and then 12 mm, and settle. Then the last travel is 12.35 to the right or downwards and −11.65 the other way, to 1e-9, as each test asserts today. | The tests' own literals: 3.5 mm less the 3.15 mm the begin frame had reached, plus 12; R1's "after 3 further frames" |
| T14 | R3 | `GestureRecognizer.step` | The existing hand-built sequences, by Rule B, each asserting every phase: `travelIsTheMidpointsMovementSinceTheBeginAndOnlySentWhenItChanged` (0.5, 1.5, 3, 5, 7, 8.5, 9.5, 10, and the rest frames after it send nothing); `aFingerThatDropsOutAndComesBackWithANewIDRejoinsWithoutAJump` in both files (1, 3, 6, 9, 11, 12); `theWholeHandLiftingTogetherEndsTheSwipeAndTheThumbLiftDoesNotCancelIt` and `theWholeHandLiftingTogetherEndsTheSlide` (6, 12, 18, 24); the `.blocked` case of `aBlockedPressLeavesTheSwipeAloneAndAClickCancelsIt` and `aBlockedPressLeavesTheWindowSwipeAloneAndAClickCancelsIt` (2, 4, 6, 8); in `EdgeContactRecognizerTests.swift`, `aFingerAtTheTopEdgeTakesPartInASwipe` (1, 3, 6, 10, 13, 15, 16), `aThirdContactAtTheEdgeDoesNotCancelASwipe` and `anEdgeContactLandingDuringAWindowSwipeDoesNotCancelIt` (1, 3, 5, 7, 8), `anEdgeContactCannotRejoinASwipeAfterAFingerLifts` and `anEdgeContactCannotRejoinAWindowSwipeAfterAFingerLifts` (1, 3, 6, 9, 11, 12), with the frame times their events come on. Every sequence starts with `.began` and ends with the phase it ends with today. | Each test's own total today (10, 12, 24, 8, 16, 8, 12); the worked table's rows |
| T15 | R3 | `World` | The existing switcher and window switcher tests. By Rule A: `theSelectionMovesOneRowPerTwelveMillimetresAtTheHalfwayPointWithOneTickEach` (5.55 mm stays, 0.2 more moves on), `turningBackFromPastTheLastRowMovesTheSelectionHalfARowAfterTheTurn` (−5.9 stays, −0.2 more moves), `turningBackFromPastTheFirstRowMovesTheSelectionHalfARowAfterTheTurn` (6.1), `pushingLeftPastTheFrontmostAppStretchesAndTheNextAppComesSevenMillimetresAfterTheTurn` (5, then 2 more), and every caller of `World.swipe` and `World.windowSwipe`. By Rule B: `theWholeHandLiftingTogetherOpensTheSelection` (three rest frames; Slack). By Rule C: `oneFrameCrossingThreeIconsTicksThreeTimes` (one `.moved` of 36.35: 3 ticks), `oneFrameCrossingTwoRowsTicksTwice` (24.35: row 2, 2 ticks), `slidingAwayAndBackThenLiftingRestoresTheOrderSilently` (24.35, then 0.35) and `aWindowMinimisedMidSwipeStaysMinimisedWhenTheLiftIsOnAnotherRow` (36.35, then 0.35), each with the selections, ticks, raises and window orders it asserts today. | The tests' own literals, unchanged |
| T16 | R3 | each test's own | Every existing test that T10 and T13 to T15 do not name runs unedited and stays green. Among them: the begin thresholds and kinds (`SwipeRecognizerTests`, and the other tests of `WindowSwipeBeginTests` and `WindowSwipeKindTests`), the ends and cancels that assert no travel (the other tests of `SwipeTravelAndExitTests` and `WindowSwipeTravelAndExitTests`), the answer (`WindowSwipeAnswerTests`, `WindowSwipeConfirmationTests`), blocking (`BlockingLevelRecognizerTests`, `ClickBlockingRecognizerTests`, `WindowSwipeBlockingTests`, `DockSwipeBlockingRecognizerTests`, `LiftWindowTests`), the selection's rules (`SwitcherTests`), the other on-screen tests of both switchers, and the real session (`DeviceSessionTravelTests`: a window swipe travels down exactly as far as a swipe travels right). | Their own expectations, unchanged: R3's "as today" |
| T17 | R3 | Source scan | Given the changed sources. When `SourcePolicyTests` runs. Then no source holds a timer, `asyncAfter`, `Task.sleep` or display link token, and every frame-path file is still listed and clean. | The scan's `banned` and `framePathFiles` lists |
| T18 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move 1 mm a frame for 4 frames; finger 1 goes out of contact for 2 frames while finger 2 keeps moving 1 mm a frame; finger 1 lands again while finger 2 moves 1; on the next frame finger 2 lifts for good and finger 1 moves 5 mm, its first movement since it rejoined; then finger 1 rests 4 frames. Then travel reads 0.25, 0.75, 1.5, 2.5, 3.5, 4.5, 5.5, 7.5, 9.25, 10.75, 12, and the last rest frame sends nothing: the 5 mm counts. Read as "none is 0 mm", the same hand would end at 7. | R2: a finger with no counted movement yet, on the first frame after it rejoined, is counted; worked by hand: the frames' movements are 1 × 7, then 5, then rest, and the total is 7 + 5 |
| T19 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move 1 mm a frame for 2 frames; finger 1 lifts for good and finger 2 rests 4 frames, then moves 2.4 mm a frame for 5 frames, then rests 4. Then travel reads 0.25, 0.75, 1.25, 1.75, 2, nothing on the next two frames (the last of the rest, and the first fast frame, which is discarded), then 2.6, 3.8, 5.6, 8, 9.8, 11, 11.6, and the last rest frame sends nothing. The second fast frame counts although it is longer than 2 mm and than 3 times the resting frame's 0 plus 1 mm, and it is the reference the third is judged against. With R1 alone nothing is discarded and the hand ends at 14; with a reference that a discard does not move it would stay at 2. | R2's scenario "A lone finger that starts abruptly": only the first of the five is discarded. Worked by hand: the frames' movements are 1, 1, 0 × 4, 0 for the discarded frame, 2.4 × 4, then rest; the total is 2 + 4 × 2.4 = 11.6 |
| T20 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move 0.2 mm a frame for 4 frames; finger 1 goes out of contact for 2 frames, on which finger 2 moves +7 mm and then `b` mm; finger 1 lands again while finger 2 moves 0.2; both move 0.2 for 2 frames; both rest 4 frames. For `b` = −7, the snap straight back, travel reads 0.05, 0.15, 0.3, 0.5, 0.65, 0.75, 0.85, 0.95, 1.1, 1.25, 1.35, 1.4, and the last rest frame sends nothing: both frames are discarded and the travel ends where the fingers are. For `b` = −4 (the sum is 3 mm, within half of 7) it reads the same and ends at 1.4. For `b` = −3 (the sum is 4 mm, over half) the movement is no undo and, being the frame after a discard, is counted: 0.65, then 0, −0.65, −1.3, −1.9, −1.75, −1.65, −1.6. With R1 alone the first hand bumps to 2.4, 2.5, 2.6, 2.7 before it returns. | R2's scenario "A snap away and back on adjacent frames", and its literal "at most half as long as the snap" (3.5 mm for a 7 mm snap). Worked by hand: the frames' movements are 0.2 × 4, 0, 0, 0.2 × 3, then rest, 7 counted frames × 0.2 = 1.4; with `b` = −3 the sixth is −3 and the total is 1.4 − 3 |
| T21 | R2 | `GestureRecognizer.step` | Given `.linear` travel: both fingers move 1 mm a frame for 2 frames; finger 1 lifts for good and finger 2 rests 4 frames; then finger 2 (a) moves 2.4 mm a frame for 5 frames, (b) for 4 frames; then moves back 2.4 mm a frame for 2 frames and rests 4. Then (a) travel after each frame reads 0.25, 0.75, 1.25, 1.75, 2, 2, 2, 2.6, 3.8, 5.6, 8, 9.2, 9.2, 8.6, 7.4, 6.8: the turn comes on the fifth frame after the discarded one, the snap is no longer remembered and both frames back count, so only the first fast frame is lost (the fingers are at 9.2). And (b) reads 0.25, 0.75, 1.25, 1.75, 2, 2, 2, 2.6, 3.8, 5.6, 7.4, 8, 8, 7.4, 6.8: the turn comes on the fourth frame after, is taken for the undo and discarded, and the travel ends where the fingers are. A memory of 5 frames would end (a) at 9.2; a memory of 3 would end (b) at 4.4. | R2's scenario "A lone finger that starts abruptly and turns back", and its literal "for the next 4 frames". Worked by hand: (a) the frames' movements are 1, 1, 0 × 4, 0 (discarded), 2.4 × 4, −2.4 × 2, then rest: 2 + 9.6 − 4.8 = 6.8; (b) 1, 1, 0 × 4, 0 (discarded), 2.4 × 3, 0 (the undo), −2.4, then rest: 2 + 7.2 − 2.4 = 6.8 |

### Verified without a test

None: every requirement has a test scenario.

## Further Notes

- **R2 was amended after the first plan review**, in two rounds, on points the plan had raised:
  - *Its condition is "while only one swipe finger is down".* The earlier "fewer swipe fingers down than on the frame before" said the same thing, a slide having two swipe fingers at most.
  - *A finger's first movement in the slide is counted.* The earlier text judged against "the previous counted frame" and was silent where there is none. Reading "none" as 0 mm was tried in the prototype and changes what four existing hands travel: `anEdgeContactCannotRejoinASwipeAfterAFingerLifts` and its window swipe twin send no `.moved` at all (12 mm today); T10's hand loses both its 14 mm and its 10 mm (24 today); and `aFingerThatDropsOutAndComesBackWithANewIDRejoinsWithoutAJump`, in both files, loses the 4 mm its finger moves alone and ends at 8, not 12.
  - *The frame after a discard is counted.* The earlier text left the reference where it was after a discard, so a lone finger that had been all but still and then moved more than 2 mm on every frame was discarded on every one of them: in the prototype, T19's hand stayed at 2. It now loses its first fast frame only and ends at 11.6.
  - *A snap's undo is discarded with it.* With the frame after a discard always counted, a snap that comes back on the very next frame, which the Problem statement describes ("one or two frames later"), had its away discarded and its back counted: in the prototype, T20's first hand ended at −5.6 where the fingers had moved +1.4. A discarded snap is therefore remembered for 4 frames, and a movement that undoes it is discarded too. The hand ends at 1.4, and the recording's back, two frames after its away, is discarded as an undo as well.
- **What R2 still loses**, one frame each:
  - *A lone finger's catch-up frame.* It is real movement, but with one finger down it cannot be told from a snap: a lone finger that rests, is reported 5 mm on in one frame and then moves 0.5 mm a frame ends 5 mm short.
  - *The first fast frame of a lone finger that starts abruptly* (T19): 2.4 of its 12 mm. If it turns back within the 4 frames the snap is remembered, the turn is taken for the undo and the travel ends where the fingers are (T21).
- **R1 alone already satisfies the leap bound on both recorded swipes** (0 leaps in each). What R2 adds on swipe 4 is that the highlight no longer drifts about 6 step mm out and back over eight frames; T5's 1 step mm bound is its proof.
- **What the prototype measured** on the two recorded swipes, replayed through the real recognizer: today, 8 and 7 leaps, 32.16 after 2.69 at 0.512 s of swipe 2, +22.88 and −18.49 at 1.136 s and 1.152 s of swipe 4, to the digits the Problem statement gives. With R1 and R2: no leap in either, a worst step of 11.88 (swipe 2, the same frame), and the travel across swipe 4's snap moving 0.19 in all (84.196 at 1.128 s, then 84.254, 84.331 and 84.386). Re-measured after each amendment of R2, every one of these numbers is the same to the last digit: in the two recordings R2 discards exactly two frames, swipe 4's at 1.136 s, as a snap, and at 1.152 s, as its undo, and the frame between them is counted. The whole suite was run against the prototype of the first amendment and fails the same 26 existing tests as before and no other; after the second, the two replays and the hands of T6, T7, T18, T19, T20 and T21 were run, and read as their rows say. The undo rule acts only after a discard, and R2 changed no existing test's travel in the full runs, so it cannot reach them.
- **The cost of the window.** At a steady pace the highlight trails the fingers by one and a half frames of movement, 12 ms at the trackpad's 8 ms frames, and has caught up 24 ms after they stop. A lift mid-movement selects what the highlight shows, which can be one item short of where a flick was heading (T12).
- **By hand, once the branch is built** (`make run`, with the swipe setting on and five or more apps running). Not a proof of a requirement, which the replays are, but the bug was found by feel:
  1. Swipe at a steady pace across the row and back. Expected: the highlight glides; it never jumps an icon or more in one step.
  2. Swipe fast and stop dead. Expected: no lurch forward as the fingers stop.
  3. Slide lightly, so that one finger skims and loses contact. Expected: the highlight never jerks forth and back.
  4. Lift one finger and keep sliding with the other. Expected: the highlight keeps following it.
  5. Repeat 1 to 3 sliding up and down with the window swipe setting on.
- **A flaky test to know about.** `stoppedCopiesExitAndTheNewCopySurvives` in `LauncherPlatformTests` failed once in six full runs during planning and passed in the others. It stops real processes and has nothing to do with this change.

## Slices

Three slices, in order. S1 makes the change easy: it moves the tests' hands to where the new travel will meet them, against today's recognizer. S2 and S3 are the two root causes, each proved by its own recorded swipe; S3's worked examples assume S2's window.

### S1: The tests' hands rest before they are read

**What to build:** nothing the user sees. The existing tests stop depending on travel arriving in the frame that moved the fingers, with every expected value as it is today:
- `TouchScript.settle()`, and `World.swipe` and `World.windowSwipe` settling after each slide;
- Rule A's settles in the tests T13 and T15 name;
- Rule B's three rest frames before the lift in the tests T10, T14 and T15 name, their expected sequences unchanged for now (a resting hand sends nothing today);
- Rule C's port deliveries in the four tests T15 names. `oneFrameCrossingTwoRowsTicksTwice` loses only its `history.count == 1`, which the single delivered event makes true by construction.

**Blocked by:** None (can start immediately).

**Requirements:** None delivered. It prepares R1 and R3: after it, the only existing tests R1 can fail are those that assert travel frame by frame.

**Test scenarios:** None turn green. The tests of T10, T13, T14 and T15 are edited here and stay green.

**Skills:** `macos-dev-workflow:swift-testing-pro`

- [ ] `make test` is green, and the slice's diff touches test code only: no product source changes.
- [ ] No expected travel, selection, tick count, haptic or window order in an edited test differs from today's. Besides adding settles and rest frames, the diff changes only: the frame counts, frame indices and event times that the added rest frames shift in the tests T10 and T14 name (a lift and its `.ended` three frames later; a track held still to rest); Rule C's one-frame jump slides, replaced by port deliveries; and the one `history.count` line, removed.
- [ ] `settle()` rests exactly 3 frames, as a literal with R1 named in its comment, and both `World` helpers' comments say they settle after each slide.

### S2: Travel follows the fingers' averaged movement

**What to build:** a swipe's and a window swipe's highlight no longer leaps when the trackpad reports the fingers unevenly. Travel on each frame comes from the fingers' movement averaged over the last 4 frames, so the acceleration sees the averaged speed; it has caught up 3 frames after the fingers stop; a lift selects what the highlight shows. The pieces: the window in the recognizer's slide state and its constant in `GestureRules`; the recording as a fixture with its `RecordedSwipes` helper and the leap check; the new tests; Rule B's sequences re-derived from the worked table.

**Blocked by:** S1.

**Requirements:** R1; R3.

**Test scenarios:** T1, T2, T3, T4, T11 and T12 turn green. T10 and T14 turn green again once their sequences are re-derived. T13, T15, T16 and T17 stay green as S1 left them.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`, `dev-workflow:codebase-design`

- [ ] T1, T2, T3, T4, T11 and T12 are each seen to fail against the recognizer as S1 left it, for the reason their row gives under "Today", before the change makes them pass.
- [ ] Rule B's tests assert every phase to 1e-9 with values taken from the worked table, and each ends on the total it asserted before this slice.
- [ ] The fixture is byte-identical to the recording beside this plan (`cmp` says so), and T1's replay begins and ends on the frames the file's header names.
- [ ] The window's size is one named constant in `GestureRules`, read by the recognizer; no other copy of the number is in the sources.
- [ ] `make test` is green, with the tests T16 covers unedited.

### S3: A remaining finger's snap is not movement

**What to build:** during a light slide, when one swipe finger loses contact for a moment and the other's reported position jumps away and back, the highlight stays where the fingers are. Each swipe finger remembers the length of its last counted movement, whether its last movement was discarded, and for 4 frames the snap it was discarded for. While only one swipe finger is down, a movement that undoes a remembered snap (the two sum to at most half the snap's length) is discarded and the snap forgotten; otherwise a movement longer than 2 mm and longer than 3 times the last counted length plus 1 mm is discarded and remembered as a snap; the finger's position follows the report either way. A finger's first movement in a slide always counts, and so does its movement on the frame after a discarded one unless it is the undo, and it becomes the reference: no finger is discarded two frames in a row but for a snap and its undo. The snap is also forgotten when the finger lifts or two fingers are down again. The thresholds, the 4 frames and the half are constants in `GestureRules`.

**Blocked by:** S2.

**Requirements:** R2.

**Test scenarios:** T5, T6, T19, T20, T21 and T7's three discarded cases turn green. T8, T9, T18 and T7's three counted cases are added here as guards against discarding too much, and pass from the start. T1 and T10 stay green.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`

- [ ] T5 and T6 are seen to fail against the recognizer as S2 left it, T5 on its 1 step mm bound alone, and so are T7's three discarded cases and T19 (which ends at 14 there, nothing being discarded), before the change makes them pass. T8, T9, T18 and T7's three counted cases already pass there and keep passing.
- [ ] T19 ends at 11.6, not at 2: after the one discarded frame the next is counted and is the reference for the one after.
- [ ] T20 and T21 assert the travel after every frame, not only where it ends, and are seen to fail as S2 left the recognizer: T20's first hand ends at 1.4 there too, by way of a bump to 2.7, and T21's second ends at 6.8 there too, with nothing discarded. After the change T20's snap straight back ends at 1.4 with no bump, and T21 ends at 6.8 both ways, which holds the memory at exactly 4 frames.
- [ ] T10 stays green without an edit, and T18 passes: a finger's first movement in a slide is counted, on the first frame after the begin and on the first after it rejoined.
- [ ] The three thresholds, the snap's 4 remembered frames and the undo's half are named constants in `GestureRules`, read by the recognizer; no other copy of the numbers is in the sources.
- [ ] `make test` is green, with the tests T16 covers unedited.
