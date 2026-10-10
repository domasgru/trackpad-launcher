# Plan: Launch animation

## Problem statement

A gesture gives a haptic pulse, then the target app comes to the front. Nothing on screen marks the moment. A cold app launch can take a second or more. During that time the user sees no sign that the gesture worked or which app is coming. A pulse alone does not tell them whether they tapped the right finger count.

## Solution

When a gesture fires, the target app's icon appears at the pointer. It puffs up for a split second, like a balloon taking a last breath. It then floats away like a small balloon letting its air out. Escaping air shoots the balloon upward, and the balloon shrinks as it empties. Its path wanders a little to the left and right, differently each time. The icon fades out before the balloon would be empty. The whole animation lasts about a third of a second. With Reduce motion on, the icon simply fades out in place.

The animation confirms the gesture and names the app at a glance. The app's icon is the confirmation of which gesture fired; no separate finger-count indicator is shown. It stays out of the way: it never takes focus and never blocks a click.

## Requirements

### R1. The animation plays when a gesture fires
The launch animation MUST play when a gesture fires for an assigned, present target app. It MUST appear no later than the haptic feedback. It MUST play whether the target app is launching or already running.

#### Scenario: Assigned app that is running
- **GIVEN** the 1-finger gesture is assigned to Arc, and Arc is running
- **WHEN** the user makes the 1-finger gesture
- **THEN** Arc's icon animates at the pointer, and Arc comes to the front

#### Scenario: Assigned app that is not running
- **GIVEN** the 2-finger gesture is assigned to Figma, and Figma is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** Figma's icon animates at the pointer at once, before Figma has finished launching

### R2. No animation for a gesture that does nothing
The launch animation MUST NOT play when a gesture is unassigned, its assignment is missing, or gestures are inactive.

#### Scenario: Unassigned gesture
- **GIVEN** the 3-finger gesture is unassigned
- **WHEN** the user makes the 3-finger gesture
- **THEN** no icon appears

#### Scenario: Missing assignment
- **GIVEN** the 4-finger gesture is assigned to Spotify, and Spotify has been moved to the Trash
- **WHEN** the user makes the 4-finger gesture
- **THEN** no icon appears

#### Scenario: Gestures inactive
- **GIVEN** the 1-finger gesture is assigned to Arc, and Tap to click is on, which makes gestures inactive
- **WHEN** the user makes the 1-finger gesture
- **THEN** no icon appears

### R3. The icon is the target app's icon
The animated image MUST be the target app's own icon, the one Finder shows for it. It MUST start at 60 × 60 points.

#### Scenario: Icon matches the app
- **GIVEN** the 1-finger gesture is assigned to Notion, and the pointer is on a Retina display
- **WHEN** the user makes the 1-finger gesture
- **THEN** the icon that appears is Notion's icon, 60 points square, and it shows no blur or pixelation at any point

### R4. The icon starts at the pointer
The icon's centre MUST start on the pointer's position at the moment the gesture fires, on the display the pointer is on. If an app has hidden the pointer, the icon MUST start at the pointer's current position anyway.

#### Scenario: Pointer on a second display
- **GIVEN** an external display is connected and the pointer is on it
- **WHEN** the user makes an assigned gesture
- **THEN** the icon appears centred on the pointer, on the external display

#### Scenario: Pointer hidden while typing
- **GIVEN** the user is typing in a text editor and the pointer is hidden
- **WHEN** the user makes an assigned gesture
- **THEN** the icon appears at the pointer's position

#### Scenario: Pointer over the launcher window
- **GIVEN** the launcher window is open and the pointer is over it
- **WHEN** the user makes an assigned gesture
- **THEN** the window closes, and the icon animates at the pointer

### R5. The icon appears at once at full size
The icon MUST appear at full size and full opacity as soon as the gesture fires. It MUST NOT fade in or grow in from a smaller size.

#### Scenario: First frame
- **WHEN** the user makes an assigned gesture
- **THEN** the icon is at full size and fully opaque the instant it becomes visible; there is no fade-in or grow-in

### R6. The icon rises faster and faster
Unless Reduce motion is on (R15), the icon MUST end between 60 and 80 points above its start. Its upward speed MUST grow as it goes, as if pushed by escaping air.

#### Scenario: Rise speeds up
- **WHEN** the user makes an assigned gesture
- **THEN** the icon ends 60 to 80 points above where it started, and it covers more height in the second half of the animation than in the first

#### Scenario: Pointer near the top edge
- **GIVEN** the pointer is within 20 points of the top of the display
- **WHEN** the user makes an assigned gesture
- **THEN** the icon rises over the menu bar and is cut off at the display's top edge; it never jumps to another display

### R7. The icon shrinks
Unless Reduce motion is on (R15), the icon MUST shrink steadily from the end of its puff (R16). It MUST end no larger than 60 % of its start size.

#### Scenario: Icon gets smaller
- **WHEN** the user makes an assigned gesture
- **THEN** after the puff the icon gets smaller throughout the animation, and ends no larger than 36 points square

### R8. The icon fades out before it shrinks away
Unless Reduce motion is on (R15), the icon MUST fade to invisible. Its opacity MUST stay high in the early part of the animation. It MUST become fully invisible while it is still clearly larger than a dot.

#### Scenario: Fade outruns the shrink
- **WHEN** the user makes an assigned gesture
- **THEN** the icon stays nearly opaque at first, then fades out completely while it is still clearly larger than a dot

### R9. The icon sways to one side
Unless Reduce motion is on (R15), the icon's path MUST veer a small random amount to the left or right. Its sideways drift MUST never be more than a third of its rise.

#### Scenario: Paths differ
- **GIVEN** the 1-finger gesture is assigned
- **WHEN** the user makes the 1-finger gesture ten times without moving the pointer
- **THEN** the icon does not always drift the same way, the sideways offsets are not all identical, and it always ends above where it started

### R10. The icon tilts with its sway
Unless Reduce motion is on (R15), the icon MUST tilt slightly with its sway. The tilt MUST never be more than 5 degrees.

#### Scenario: Slight tilt
- **WHEN** the user makes an assigned gesture
- **THEN** the icon leans toward the side it drifts to, never more than 5 degrees

### R11. The animation lasts about a third of a second
The icon MUST be fully invisible between 300 and 400 ms after it appears.

#### Scenario: Gone after a third of a second
- **WHEN** the user makes an assigned gesture
- **THEN** the icon is fully invisible between 300 and 400 ms after it appeared

### R12. The animation floats above everything
The icon MUST show above all other windows, including full-screen apps and the menu bar, on whichever Space is current. It MUST stay visible on top while macOS switches Spaces to bring the target app to front.

#### Scenario: Full-screen app
- **GIVEN** Safari is in full screen and the pointer is over it
- **WHEN** the user makes an assigned gesture
- **THEN** the icon animates on top of Safari

#### Scenario: Target app on another Space
- **GIVEN** Arc is full screen on another Space
- **WHEN** the user makes Arc's gesture
- **THEN** the icon stays visible at its place while macOS switches to Arc's Space

### R13. The animation never gets in the way
The icon MUST NOT receive clicks: a click under it MUST reach whatever is beneath. Showing it MUST NOT take focus from any app, nor delay bringing the target app to front.

#### Scenario: Click through the icon
- **WHEN** the user makes an assigned gesture and clicks a button under the icon while it is still visible
- **THEN** the button receives the click

#### Scenario: Focus goes to the target app
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user makes the 1-finger gesture
- **THEN** Arc becomes the active app, and Trackpad Launcher never does

#### Scenario: No delay to the target app
- **GIVEN** the 1-finger gesture is assigned to Arc, and Arc is running
- **WHEN** the user makes the 1-finger gesture
- **THEN** Arc comes to the front as fast as it would without the animation

### R14. Each gesture gets its own animation
Every fired gesture MUST start its own animation. A new animation MUST NOT cancel or restart one already playing.

#### Scenario: Two gestures in quick succession
- **GIVEN** the 1-finger gesture is assigned to Arc and the 2-finger gesture to Figma
- **WHEN** the user makes the 1-finger gesture, then the 2-finger gesture 200 ms later
- **THEN** Arc's icon and Figma's icon each play their full animation, overlapping briefly

#### Scenario: Same gesture twice
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user makes the 1-finger gesture, then makes it again 200 ms later
- **THEN** two Arc icons are visible at once, each completing its own animation

### R15. Reduce motion is respected
While the macOS "Reduce motion" accessibility setting is on, the icon MUST NOT move, puff up, shrink or tilt. It MUST appear at the pointer at full size and fade out in place over the same duration as the full animation (R11).

#### Scenario: Reduce motion on
- **GIVEN** Reduce motion is on
- **WHEN** the user makes an assigned gesture
- **THEN** the icon appears at the pointer and fades out where it is, without moving, puffing up or shrinking

### R16. The icon puffs up before it deflates
Unless Reduce motion is on (R15), the icon MUST swell in place to between 110 % and 130 % of its start size within the first 100 ms, then start deflating. While it swells it MUST NOT move, tilt or fade.

#### Scenario: Quick puff
- **WHEN** the user makes an assigned gesture
- **THEN** the icon swells almost at once to about a fifth bigger, without moving, and only then starts to rise and shrink

## Non-goals

- **A setting to turn the animation off.** It is short, quiet and never blocks anything; Reduce motion covers users who want less motion.
- **Animation for gestures that do nothing.** A gesture that is unassigned, missing or inactive stays silent everywhere, as today.
- **Sound.** The product overview asks for a sound effect with each gesture; that is a separate change.
- **Tracking the pointer during the animation.** The icon starts at the pointer and then moves on its own path.
- **Showing the icon until the app's window appears.** The animation is a fixed-length confirmation, not a progress indicator.
- **A finger-count indicator.** The app's icon already tells the user which gesture fired.

## Implementation Decisions

### When the animation plays: `Launcher.fire`
- `fire` stays the one place a gesture's effects are decided. Behind its existing guard (gestures active, gesture assigned, app located) it runs four effects in one synchronous main-actor turn: the pulse, bring to front, the launch animation, then closing the window.
  - There is no new guard and no new state.
  - Every silent case (inactive, unassigned, missing) stays silent for the animation, because the animation sits behind the same guard (R2).
  - Every call that passes the guard plays exactly one animation (R1, R14).
- The animation comes after bring to front. Its icon is rendered ahead of time (next decision), so its work at fire time is 1–2 ms: building a panel and handing Core Animation its keyframes (planning probe). Last in line, it cannot hold up the pulse or the app (R13). If some slowness is left, such as an icon that is not ready (see Further Notes), it lands on the icon, never on the app.
- How the plan reads R1's "no later than the haptic feedback":
  - The pulse is a synchronous actuator call. Any picture reaches the screen on the first display refresh after its layers are committed, so no picture can strictly precede a pulse.
  - The plan therefore meets R1 by issuing the animation in the same main-actor turn as the pulse, with nothing slow in the way. The icon is ready before the gesture, so the animation reaches the screen on the first refresh after the pulse.
- `Launcher`'s doc comment, which says `fire` is the only path that pulses, launches or closes the window, gains "or plays the launch animation".

### The icon is ready before the gesture: `Launcher` prepares it
- The model passes every present assigned app to `prepareLaunchAnimations(for:)`. These are the rows' `.present` entries, one per bundle location, in gesture order.
- It does so in `start()` once the rows are final, and again every time it re-resolves the rows: on an assignment change and on opening the window.
- `init` stays free of effects.
- Why: the planning probe measured 45–120 ms for the first render ever of an app's icon at this size, against 1–2 ms afterwards. Rendering at assignment, at launch or when the window opens keeps that cost off the gesture.

### The port: two methods on `SystemActions`
- **`prepareLaunchAnimations(for apps: [AppEntry])`**
  - The apps the next launch animations may be for.
  - Each call replaces the previous set.
  - The adapter readies what it needs for them now, so a later `playLaunchAnimation` for one of them does no slow work.
- **`playLaunchAnimation(for app: AppEntry)`**
  - Returns at once.
  - Reads the pointer, the connected displays and Reduce motion at the moment of the call.
  - Plays for about a third of a second and removes itself.
  - Every call plays its own animation and never cancels, restarts or reuses one already playing.
  - Nothing it shows activates Trackpad Launcher, becomes key or receives a click.
- No new port. The animation is one more effect the core decides and macOS performs, which is what `SystemActions` already describes. `Launcher`'s initialiser, `World` and the composition root keep their shape.
- `RecordingSystemActions` grows by three members:
  - `launchAnimations: [AppEntry]`, one entry per play;
  - `preparedLaunchAnimations: [AppEntry]`, the latest set prepared;
  - an `onPlayLaunchAnimation` hook that runs inside the play call, so a test can read the other effects at that moment. `onRegisterLoginItem` already works this way.

### The launch flight (LauncherPlatform, internal, pure)
Internal value types beside the overlay in LauncherPlatform, tested through `@testable import`:
- `LaunchFlights`
- `LaunchFlight`
- `LaunchStage`
- `LaunchDisplay`, a display's frame plus its backing scale.

They are pure. They touch no window, no `NSScreen` and no clock. They build `CAKeyframeAnimation` objects but never add them to a layer. They hold every number in R5–R11 and R15, and the R6 placement rule.

Why LauncherPlatform and not LauncherCore:
- The motion is how the adapter renders an effect the model decided. It is not a model decision. The trackpad adapter already works this way: its pulse strength, `feedbackActuation`, lives inside it.
- Living here, the flight can use `CGPoint`, `CGRect`, `CATransform3D` and `NSMouseInRect` directly. LauncherCore can use none of these, since it imports only Foundation and Observation, and Foundation-only code has `CGRect` without its initialisers or geometry (a planning compile checked this).
- It can also build the exact keyframe animations the overlay adds. Tests then read what Core Animation will play, so copying the flight into Core Animation is itself under test.

**`LaunchFlights`** draws flights through `mutating next(draw:reduceMotion:) -> LaunchFlight`. The caller supplies `draw`, a uniform random number in −1…1; the overlay draws it from the system generator.
- **Side.** A negative draw veers left. Zero or a positive draw veers right, so every flight veers.
- **Size.** The magnitude maps linearly onto 40–100 % of the maximum sway.
- **Streak memory.** It remembers the sides of the last two moving flights. A draw that would make a third in a row on one side goes to the other side, with the same magnitude.
  - With a plain coin, all ten flights in R9's "Paths differ" scenario would drift the same way in 1 run of ten in 512 (2 × 2⁻¹⁰).
  - The memory makes the scenario hold for every sequence of draws, and it is what the domain model's *Sway* promises.
- **Reduce motion.** Reduce-motion flights do not sway and do not touch the memory.
- `next` is the only way to make a `LaunchFlight`.

**`LaunchFlight.staged(at pointer: CGPoint, among displays: [LaunchDisplay]) -> LaunchStage?`** decides everything about where and how the icon moves:
1. **Choose the display.** It is the one whose frame contains the pointer under AppKit's mouse rule: `NSMouseInRect`, unflipped.
   - Checked while planning: a display's top edge counts as inside and its bottom edge as outside. So y = 982 belongs to a 982-point-high display at the origin, not to the display above it that starts at 982. y = 0 belongs to no display.
   - When no display contains the pointer (its bottom edge, or a gap between displays), the nearest display is chosen.
   - With no displays at all, it returns nil.
2. **Round the pointer** to that display's pixel grid, so the nearly still first frames are sharp.
3. **Place the window.** Put the flight's reach around the rounded pointer. The reach is the box that holds every pose's square, rotated. Clip the box to the display's full frame (menu bar included), in whole points. Return nil if nothing is left.
   - Clipping to the pointer's own display keeps the window from straddling two displays. A straddling window is what macOS may show on the other display (R6 "never jumps to another display").
4. **Build three `CAKeyframeAnimation`s** from the flight's poses, sampled every 1/120 s: 61 values over a 0.5 s duration, with keyTimes evenly spaced and linear interpolation.
   - `position`: the icon centre, in the window's coordinates.
   - `transform`: a z-rotation, then a uniform scale of side ÷ 46.
   - `opacity`.

**`LaunchStage`** carries what `staged` decided:
- `frame`: the window frame, in global screen coordinates;
- `scale`: the chosen display's backing scale;
- `iconSide`: 46 pt;
- `iconCentre`: the start point, in the window's coordinates;
- `animations`: the three keyframe animations.

**Conventions.**
- Everything is y up: AppKit's global screen space, and the window's coordinates.
- Rotation is counter-clockwise positive. That is what a Core Animation z-rotation does in a non-flipped layer tree.
- The overlay must therefore host the icon layer as a direct sublayer of a plain, non-flipped, layer-backed content view. With that tree, the keyframes need no further conversion.

**Curves.** Retuned by feel with the Debug-only tuner (see "Tuning" below); the tests check the requirement bounds, not these formulas. Every number lives in `LaunchTuning`, whose defaults are the shipped animation. The duration is 0.34 s. The pop takes the first 75 ms; v is the time since the pop ended ÷ the remaining 265 ms.

| | Motion | Reduce motion |
|---|---|---|
| pop | side 60 · (1 + 0.2 · (1 − (1 − p)²)), p = time ÷ 75 ms: eases out to 72 pt, in place, fully opaque | none |
| rise y | 70 · v^1.8: accelerates from rest | 0 |
| side | 72 · (1 − 0.55 · v^1.4), ending at 32.4 pt | 60 |
| opacity | 1 − v⁴: at least 0.95 through 200 ms; 0 at 340 ms, when the icon is 32.4 pt | 1 − u⁴ |
| sway x | k · y · v^1.8, where k = ±(0.1…1.0) × 0.26. The end drift is 1.8–18.2 pt, never more than 0.26 of the rise | 0 |
| rotation | −(k ÷ 0.26) · 4° · v: leans toward the drift, at most 4° | 0 |

Keyframes are sampled every 1/240 s, so the 75 ms pop gets 18 of them. The icon bitmap is rendered at the pop's peak size (72 pt), so it is never scaled up.

### Tuning (Debug builds only)
- `LaunchTuning` holds every number above. Release builds read its defaults as constants. Debug builds read them through a `Mutex` the tuner writes.
- `AnimationTuner` is a floating window that opens when a Debug build launches. It has a slider per number, live preview at the pointer, reset to shipped, and named presets saved in user defaults.
- To ship a new tuning, copy its values into `LaunchTuning`'s defaults and adjust the requirement bounds and tests if they move.
- Everything in the tuner sits inside `#if DEBUG`, so Release builds contain none of it.

### The overlay (LauncherPlatform)
`LaunchOverlay` is internal, created and owned by `WorkspaceActions`, which forwards both port methods to it.
- `WorkspaceActions` stays the one real `SystemActions` adapter.
- The composition root already creates `WorkspaceActions`, so the app target does not change.

**Prepare.** For each app, the overlay renders its Finder icon (`NSWorkspace.icon(forFile:)`) to a bitmap.
- The bitmap is 46 pt at the highest backing scale among the connected screens. For 92 px the probe got a 128 px representation.
- The new set of bitmaps, keyed by bundle location, replaces the old one.
- This runs on the main thread and costs 1–2 ms per app once the system's icon cache holds the icon. It happens at launch, on an assignment change or when the window opens, never during a gesture.

**Play.** Each call runs on the main actor:
1. **Read.**
   - The pointer: `NSEvent.mouseLocation`, the window server's pointer position, whether or not an app has hidden the cursor.
   - The displays: `NSScreen.screens`, as `LaunchDisplay`s.
   - Reduce motion: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, read fresh on every call. Nothing observes it and nothing polls.
2. **Draw the flight and stage it.** Call `next(draw: .random(in: -1...1), reduceMotion:)`, then `staged(at:among:)`. A nil stage means the call does nothing.
3. **Make a fresh `NSPanel`** at the stage frame, created with `defer: false`:
   - borderless and non-activating; clear and non-opaque;
   - no shadow, since the icon art carries its own;
   - `ignoresMouseEvents` on (R13);
   - level `.screenSaver`. That puts it above the menu bar (levels 24–25), menus and the launcher panel (101), and every app window, full-screen ones included (R12);
   - collection behaviour `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary` and `ignoresCycle`: on every Space, over full-screen apps, and held still while Spaces slide (R12);
   - `hidesOnDeactivate` off, because the app is never active;
   - `animationBehavior` none, so the window adds no fade-in;
   - not released when closed, because the overlay owns its lifetime;
   - its content view is a plain, non-flipped, layer-backed `NSView`.

   It is ordered in with `orderFrontRegardless` and is never made key (R13).
4. **Add one icon layer**, as a direct sublayer of the content view's layer:
   - bounds `iconSide`, position `iconCentre`;
   - contents: the prepared bitmap for the app's bundle location. If the app has moved since the last prepare, the bitmap is rendered on the spot;
   - `contentsScale` set to the stage's scale;
   - trilinear minification and edge antialiasing, so shrinking and tilting stay clean.
5. **Animate in one `CATransaction` with implicit actions disabled**, so Core Animation adds no default fade or grow-in:
   - Set the layer's model values to the last keyframe's, so nothing flashes after the final frame.
   - Add the stage's three animations.
   - The transaction's completion block closes the panel and removes it from the overlay's set of live panels.

**Lifetime.** The overlay keeps each live panel in a set until that panel's completion. Calls share nothing else, so a second call never touches a first call's panel (R14).
- The panel is closed from Core Animation's completion callback, never from a timer: `Timer`, `asyncAfter` and `Task.sleep` are banned from shipped sources.
- The callback runs on the main thread and steps onto the main actor with `MainActor.assumeIsolated`, as the shell's callbacks do.
- In the probe, the callback fired 9–19 ms after a 300 ms animation ended, for a window on screen and one off screen.
- Core Animation renders the frames in the render server. Once the last panel has closed, no code of ours runs.
- The overlay keeps its own set because the probe found a closed panel staying in `NSApplication.shared.windows`.

**Warm-up.** The overlay's initialiser creates one panel with `defer: false` and closes it without ever ordering it in.
- Creating a panel's window-server window is the step the probe timed at 26–29 ms in a fresh process, against about 1 ms afterwards.
- The icon's first-use cost (about 6 ms) is paid by the prepare that `start()` triggers.

### Source policy
- `SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule "timer". A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame.

### Docs
- `docs/domain-model.md` gains the terms *Launch animation* and *Sway*.
- `docs/architecture.md`:
  - Concurrency gains the animation rule: Core Animation keyframes, cleaned up from the completion callback, no display links.
  - Shape names Core Animation among the frameworks behind LauncherPlatform.

## Testing Decisions

### Strategy

There are two seams. One already exists. The other is a new pure seam inside LauncherPlatform that ends in exactly the keyframe animations Core Animation will play.

1. **`Launcher` through `World` (LauncherCoreTests): the high seam, with its shape unchanged.**
   - Rows read the following right after a scripted tap or an intent:
     - `system.launchAnimations`, `system.preparedLaunchAnimations` and `system.broughtToFront`;
     - `hardware.feedback`;
     - `isWindowOpen`.
   - The `onPlayLaunchAnimation` hook captures the other effects at the moment the animation is requested.
   - The seam is synchronous end to end. A row that sees the animation already recorded when `tap` returns proves that nothing defers it: no `Task`, no observation hop, no wait on the launch.
   - It proves when the animation plays, for which app, and that the icon is prepared before any gesture. It cannot see the overlay.
   - Rows extend existing ones in place, in `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift`, `ActivityTests.swift` and `AppResolutionTests.swift`. Each silent-case row already asserts that nothing happens; "nothing" now includes the animation.
2. **The launch flight: `LaunchFlights.next` → `staged(at:among:)` → `LaunchStage`.** It is tested in LauncherPlatformTests through `@testable import`, in one new file, and needs no window server.
   - Rows read the stage's frame, scale and icon centre, and the values, keyTimes and duration of its three animations.
     - Screen position is the frame's origin plus the position value.
     - Side is 46 × √(m11² + m12²) of the transform.
     - Rotation is atan2(m12, m11).
   - Because these are the objects the overlay adds unchanged, the copy from the flight into Core Animation is under test. That includes the lean's sign and the conversion to window coordinates.
   - Rows are parametrised over draws, modes and display layouts, like `LauncherKit/Tests/LauncherPlatformTests/TrackpadClassificationTests.swift`. They build and read back framework objects the way `PointerEventTests.swift` does with `CGEvent`.
   - It proves every number in R5–R11 and R15, and R6's placement.
   - It misses the overlay's impure remainder: reading the pointer, displays and Reduce motion, the panel's configuration, the icon art, the bitmap cache, and the window server itself.

**The overlay's impure remainder has no in-process test.**
- It decides nothing. It reads three inputs, makes a panel, sets one layer and adds the stage's animations.
- What it produces is pixels and window-server behaviour: the level over full-screen apps, Spaces, click-through, focus, timing against the pulse. No in-process observer sees any of these.
- It is checked by eye under Verified without a test, as the shell and views were in plans 001 and 002.

**Fakes and boundaries.**
- Trackpad frames come from scripts. The hardware and system-action ports are in memory, as today.
- Randomness needs no fake: the draw is an argument of `next`, so rows pass the worst cases (constant draws, zero, the extremes) directly.
- There is no clock to fake: the keyframes carry their own times, and Core Animation owns real time.
- Everything we own runs for real.

**Readings of the requirements.** These are the plan's readings where a requirement gives no number. They are written here so the requirement owner can confirm them at plan review:
- R1, "no later than the haptic feedback": issued in the same main-actor turn as the pulse, with the icon prepared beforehand. The display pipeline puts any picture at least one refresh after its commit.
- R8, "stays high in the early part": opacity at least 0.9 through the first 200 ms (40 %).
- R8, "clearly larger than a dot": at least a third of the start size (15.3 pt) when the icon becomes fully invisible.
- R9, "never more than a third of its rise": true at every moment, not only at the end.
- R11, "fully invisible between 400 and 600 ms": the first fully transparent keyframe falls between 400 and 600 ms.

### Test scenarios

Conventions:
- **World rows** call `start()` before acting. "Nothing" means `broughtToFront`, `hardware.feedback` and `launchAnimations` all stay empty.
- **D** is the set of draws {−1, −0.5, −0.01, 0, 0.01, 0.5, 1}, each given to a fresh `LaunchFlights`. A draw of 0 counts as positive.
- **Both modes** means `reduceMotion` false and true; **motion** means false.
- **Displays.** *Built-in* is (0, 0, 1512, 982) at scale 2: this 14" MacBook Pro, read in the planning probe. *External* is (−524, 982, 2560, 1440) at scale 1, sitting above it.
- **"Staged at p"** means `staged(at: p, among: [built-in, external])`. Rows without their own point stage at (700, 400), the middle of the built-in display, where nothing is clipped.
- **Keyframes** are the 61 values of each animation, at time t = keyTime × duration.
  - Screen position is the frame origin plus the position value.
  - Rise and drift are the screen position's y and x minus their values at t = 0.
  - Side and rotation are read from the transform as the Strategy describes.
  - Rotation is counter-clockwise positive, so a top leaning right is a negative rotation.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | World | Figma on 2, window open. `tap(2)`. → When `tap` returns: `launchAnimations == [Figma]`, `broughtToFront == [Figma]`, `feedback == [macBook14]`, window closed. The `onPlayLaunchAnimation` snapshot shows `broughtToFront == [Figma]` already at the moment the animation is requested. Extends `twoFingerTapBringsItsAppToFrontPulsesAndClosesTheWindow`. | R1 scenarios "Assigned app that is not running" and "…that is running": World apps never run, and the model has no running branch. Recorded within `tap` matches R1's "at once". The snapshot's expected value is the ordering decision above (the animation after bring to front), which the R13 manual check relies on. |
| T2 | R1 | World | Arc on 1, Figma on 2. One script: thumb, tap 1, tap 2. → `launchAnimations == [Arc, Figma]`. Extends `repeatedTapsWhileTheThumbStaysAnchoredFireEachTime`. | R1 "MUST play when a gesture fires": two gestures, two plays, each for its own target app. |
| T3 | R1 | World | Arc on 1. Thumb, tap 1, wait 100 ms, tap 1. → `launchAnimations == [Arc, Arc]`. Extends `twoQuickOneFingerTapsOpenTheAppTwice`. | R1 "MUST play when a gesture fires": the same gesture twice, two plays. |
| T4 | R1 | World | Nothing assigned: `preparedLaunchAnimations == []`. Assign Arc to 1 and Figma to 2 → `[Arc, Figma]`, before any tap. Unassign 2 → `[Arc]`. `relaunch()` then `start()` → `[Arc]`. Trash Arc (LaunchServices still listing the trashed copy), then open the window → `[]`. New row in `LauncherTests.swift`. | R1 "no later than the haptic feedback": the icon is ready before the gesture, because a first render takes up to 120 ms (probe). The expected lists follow from the assignments made, and only present, assigned apps can fire. |
| T5 | R2 | World | Arc installed, nothing on 3, window open. `tap(3)`. → Nothing; window still open. Extends `unassignedGestureIsSilentAndLeavesTheWindowOpen`. | R2 scenario "Unassigned gesture". |
| T6 | R2 | World | Figma on 2. Figma moved to the Trash, with LaunchServices still listing the trashed copy. `tap(2)`. → Nothing. Extends `trashedAppIsMissingSilentAndStillReplaceable`. | R2 scenario "Missing assignment" (Spotify there; the app does not matter). |
| T7 | R2 | World | Arc on 1. Tap to click turned on for the built-in trackpad. `tap(1)`. → Nothing. Extends `tapToClickOnBuiltInDeactivatesAndStopsTheDevices`. | R2 scenario "Gestures inactive". |
| T8 | R2 | World | Arc on 1, Tap to click on, window open. A 1-finger gesture recognised just before the flip is injected. → Nothing; window still open. Extends `gestureInFlightWhenActivityFlipsIsDropped`. | R2 "MUST NOT play when … gestures are inactive". |
| T9 | R5, R15 | flight | Both modes × D. The first keyframe has screen position (700, 400), side 46, opacity 1 and rotation 0. Across the keyframes, side never exceeds 46 and opacity never rises. | R5 "at full size and full opacity … MUST NOT fade in or grow in". Full size is the 46 × 46 start size R3 sets. R15 "appear at the pointer at full size". |
| T10 | R6 | flight | Motion × D. The last keyframe's rise is within 30…60. The rise from 250 to 500 ms is greater than the rise from 0 to 250 ms. Each keyframe's rise step is larger than the one before it. | R6 "between 30 and 60 points above its start". R6 scenario "Rise speeds up". |
| T11 | R7 | flight | Motion × D. Side strictly falls from each keyframe to the next. The last keyframe's side is ≤ 23. | R7 "shrink steadily". R7 scenario "ends no larger than 23 points square". |
| T12 | R8 | flight | Motion × D. Opacity ≥ 0.9 at every keyframe up to 200 ms. Opacity reaches 0. At the first keyframe where it is 0, side ≥ 46 ÷ 3. | R8 "stays nearly opaque at first, then fades out completely while it is still clearly larger than a dot", under the readings listed above. |
| T13 | R9 | flight | Motion × D. At every keyframe, \|drift\| ≤ rise ÷ 3. The last keyframe's drift is non-zero, negative for negative draws and positive otherwise. The last keyframe's rise is > 0. | R9 "veer … to the left or right" and "never more than a third of its rise". R9 scenario "always ends above where it started". |
| T14 | R9 | flight | A fresh `LaunchFlights` given 0.6 ten times: no three end drifts in a row are on the same side, and the ten are not all equal. Every end rise is > 0. The same with −0.6 and with 0. A fresh one given −0.6, 0.6, −0.6, 0.6 ends left, right, left, right. | R9 scenario "Paths differ" (ten gestures): not always the same way, not all identical, always above. The domain model's *Sway*: never the same side three times in a row. A constant draw is the worst a random source can produce. Otherwise the side follows the draw ("a small random amount to the left or right"). |
| T15 | R10 | flight | Motion × D. \|rotation\| ≤ 5° at every keyframe. At the last keyframe, rotation ≠ 0 and its sign is opposite to the drift. | R10 "never more than 5 degrees". R10 scenario "leans toward the side it drifts to". A Core Animation z-rotation is counter-clockwise for positive angles in a non-flipped, y-up layer tree (the overlay's tree, as decided above), so a top leaning toward +x is a negative rotation. |
| T16 | R11, R15 | flight | Both modes × D. Each animation's duration is within 0.4…0.6 s. Opacity > 0 at every keyframe before 400 ms. The first keyframe with opacity 0 is at or before 600 ms. | R11 "fully invisible between 400 and 600 ms after it appears". R15 "fade out in place over about 500 ms". |
| T17 | R15 | flight | Reduce motion × D. Every keyframe has screen position (700, 400), side 46 and rotation 0. | R15 "MUST NOT move, shrink or tilt". |
| T18 | R6 | flight | A motion flight staged at (700, 975). → The frame lies inside the built-in display with its top at 982. Scale is 2. Frame origin + `iconCentre` = (700, 975). The frame is shorter than the frame staged at (700, 400). | R6 scenario "Pointer near the top edge": within 20 points, here 7. It "is cut off at the display's top edge". Display size and scale from the planning probe. |
| T19 | R6 | flight | Staged at (1000, 2410). → The frame lies inside (−524, 982)…(2036, 2422), with its top at 2422. Scale is 1. Frame origin + `iconCentre` = (1000, 2410). | R6 "never jumps to another display": the window lies on the display the pointer is on, at that display's scale. |
| T20 | R6 | flight | Staged at (700, 982), the edge the two displays share. → The frame lies inside the built-in display, top 982. Staged at (700, 0). → The frame lies inside the built-in display. | AppKit's mouse rule, observed while planning: `NSMouseInRect`, unflipped, counts a display's top edge as inside and its bottom edge as outside. A pointer at y = 0 is on no display's inside, and the built-in display is the only one it touches. R6 "never jumps to another display". |
| T21 | R5, R6 | flight | Both modes × D, staged at (700, 400). → The frame lies inside the built-in display. Every keyframe's square (side `side`, rotated by `rotation`, centred on the position value) lies inside (0, 0, frame width, frame height). | R5 "appear at full size": nothing of the icon is cut. R6: the icon is "cut off at the display's top edge" and by nothing else. |

### Verified without a test

Setup for the manual checks:
- A Debug build of the app, with the apps named in each check installed.
- This 14" MacBook Pro, plus a second display for R4 (c). Any of these gives macOS a real second display: an external monitor, an iPad over Sidecar, another Mac or an Apple TV through AirPlay's "Use as Separate Display", or an HDMI dummy plug.
- "Recording" means a QuickTime screen recording at 60 fps, stepped frame by frame with the arrow keys.
- "Slow-motion film" means an iPhone filming the trackpad and the screen together at 240 fps.

**R3: the icon is the target app's icon.**
- Steps: assign Notion to 1. Start a recording and make the gesture with the pointer on the built-in display.
- Expected on the icon's first frame: the same artwork Finder shows for Notion in /Applications, 92 px square in the recording (46 pt at 2×), with crisp edges.
- Expected through the last visible frame: no blocky edges or blur as it shrinks and tilts.
- Why not a test: whether the artwork is right and sharp is a matter of pixels the process cannot see.

**R4: the icon starts at the pointer.**
- (a) In TextEdit, type until the pointer hides, then make an assigned gesture. Expected: the icon is centred where the pointer was; moving the mouse shows the pointer there.
- (b) Open the launcher window, put the pointer over a gesture row, and make an assigned gesture. Expected: the window closes and the icon animates at the pointer.
- (c) With the second display attached:
  - Pointer on the second display, gesture. Expected: the icon is centred on the pointer on that display.
  - Pointer on the built-in display, a few points below the edge it shares with the second display (arranged above it), gesture. Expected: the icon stays on the built-in display, cut off at its top edge.
- This check is required, not optional.
- Why not a test: where the pointer is read from, and where the window server puts the window, cannot be observed in-process. The geometry beneath is under T18–T20.

**R12: the animation floats above everything.**
- (a) Put Safari in full screen with the pointer over it, and make Safari's gesture. Expected: the icon animates on top of Safari. Repeat with Arc's gesture. Expected: the icon stays on top while macOS leaves Safari's Space.
- (b) Put Arc in full screen on another Space, and make Arc's gesture from the desktop Space. Expected: the icon stays where it is, fully visible, while the Spaces slide, and finishes over Arc.
- (c) With the pointer just below the menu bar, make a gesture. Expected: the icon passes over the menu bar, not under it.
- Why not a test: window levels, Spaces and full-screen behaviour belong to the window server.

**R13: the animation never gets in the way.**
- (a) Click-through.
  - Assign Finder to 1. Bring a Finder window to the front with its view switcher under the pointer. Start a recording.
  - Make the gesture, lift all fingers (thumb included, so click blocking from plan 002 is off), then press the trackpad within about 300 ms.
  - Expected: the view changes. The recording shows the icon over the switcher at the frame the click lands.
- (b) Focus. Assign Arc to 1 and bring another app to the front. Make the gesture ten times. Expected:
  - Arc's name shows in the menu bar.
  - `lsappinfo front` reports Arc.
  - Trackpad Launcher never shows as the active app.
- (c) No delay.
  - Arc is running and assigned to 1. With slow-motion film, make ten gestures on a build of `main` and ten on this branch.
  - For each, count frames from the fingers lifting to Arc's window coming to the front.
  - Expected: the medians are within 4 frames (one 60 Hz refresh) of each other.
  - T1's snapshot pins the order this relies on.
- Why not a test: focus, click routing and real latency live in the window server and in other processes.

**R14: each gesture gets its own animation.**
- Steps: assign Arc to 1 and Figma to 2. Start a recording. With the thumb held, tap 1 and then 2 about 200 ms apart. Then tap 1 twice, about 200 ms apart.
- Expected for 1 then 2: two icons are visible at once, and each runs to its own fade-out.
- Expected for 1 twice: two Arc icons are visible at once, and each completes.
- Why not a test: whether a second overlay leaves the first one playing is window-server output.

**Design mechanisms.** These have no requirement of their own and are not proofs of R5–R10 or R15. Those are T9–T21.
- **Overlay fidelity.** This checks that the overlay hosts the icon as decided: a non-flipped tree, no implicit actions, the window adding no animation of its own, the model values left at the last keyframe.
  - With Reduce motion off, record one gesture. Expected:
    - The first frame is at the pointer, full size and fully opaque.
    - The icon rises, shrinks, drifts and leans its top toward the drift.
    - Nothing flashes after it has gone.
  - With the app still running, turn Reduce motion on (System Settings › Accessibility › Display), make a gesture, turn it off, and make another. Expected: a fade in place, then the full motion, with no relaunch.
- **Icon ready before the gesture.**
  - Quit and relaunch the app, then make an assigned gesture. Expected: the icon appears together with the pulse on the slow-motion film.
  - Assign an app whose icon has never been shown at this size (for example, a utility from /System/Applications/Utilities you have never opened), and make its gesture straight away. Expected: the same.
- **Cleanup and idle.**
  - Count Trackpad Launcher's on-screen windows before and after 20 gestures, waiting 2 s after the last one: `echo 'import CoreGraphics; let w = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]; print(w.filter { $0[kCGWindowOwnerName as String] as? String == "Trackpad Launcher" }.count)' | swift -`. Expected: the same count both times.
  - Activity Monitor then shows 0.0 % CPU for Trackpad Launcher while idle, as in plan 001's idle check.
- **Policy and build.**
  - `Scripts/test.sh` passes with the new banned tokens, and `grep -rni displaylink LauncherKit/Sources TrackpadLauncher` finds nothing.
  - `swift build` succeeds in Swift 6 mode with strict concurrency, and so does the `xcodebuild` app bundle.
  - LauncherCore still imports only Foundation and Observation (existing `coreImportsOnlyFoundationAndObservation`).

## Slices

The feature is one slice. The flight, the port and the overlay are each small, and nothing among them needs sequencing: the flight and the port are independent, and the overlay needs both but fits in the same context. No prefactoring is needed. The seams already exist, and `RecordingSystemActions` only grows.

### S1: Launch animation

**What to build:** Every gesture that brings an app to front also floats that app's icon up from the pointer. The icon appears at once at full size and full opacity. It rises faster and faster, shrinks, veers a little to a random side and leans toward it, and fades out by 500 ms. With Reduce motion on, it fades in place instead. It shows above everything on every Space, passes clicks through, never takes focus, and each gesture gets its own icon.
- The two `SystemActions` methods. `Launcher` prepares the present assigned apps from `start()` and whenever it re-resolves rows, and plays from `fire` after bring to front.
- The `RecordingSystemActions` additions.
- In LauncherPlatform: `LaunchFlights`, `LaunchFlight`, `LaunchStage` and `LaunchDisplay`, plus `LaunchOverlay` with its bitmap cache and warm-up, owned by `WorkspaceActions`.
- The display-link tokens added to the source policy.

**Blocked by:** None (can start immediately).

**Requirements:** R1–R15.

**Test scenarios:** T1–T21.

- [ ] T1–T21 pass through `Scripts/test.sh`. Every new row is synchronous and needs no window server.
- [ ] `Launcher`'s initialiser and the composition root are unchanged. `WorkspaceActions` is still the only real `SystemActions`.
- [ ] The overlay adds the stage's animations unchanged. The icon layer is a direct sublayer of a non-flipped, layer-backed content view.
- [ ] No `Timer`, `asyncAfter`, `Task.sleep` or display link appears in shipped sources; the source-policy test passes.
- [ ] The manual checks for R3, R4 (including (c) on a second display), R12, R13 and R14, and the design-mechanism checks, are ticked on hardware.

## Further Notes

- **Planning probe.** A throwaway Swift Testing suite, run in fresh `swift test` processes on this machine (macOS 26, 1512 × 982 at 2×) and since deleted, measured:
  - First panel created with `defer: false`: 26–29 ms. First icon fetch: ~6 ms. Each overlay after that: 1–2 ms.
  - First render ever of an app's icon at this size: 45–120 ms (Stickies 45, Safari 60, Grapher 71, Chess 117). After that, 1–2 ms in every process, served by the system's icon cache.
  - Core Animation's completion fired 9–19 ms after a 300 ms animation ended, for a window on screen and one off screen.
  - A closed panel stays in `NSApplication.shared.windows`.
  - Keyframe transform values read back faithfully: scale 0.4 rotated −5° read back as −5°.
  - `NSMouseInRect`, unflipped, counts a rect's top edge as inside and its bottom edge as outside.
- **Remaining icon delay.** An app that has moved since the last prepare (rows are re-resolved when the window opens, not on every file move) has its icon rendered at the gesture. If that is its first render ever, the icon can lag the pulse once. It never delays the pulse or the app.
- **Tuning.** The curve constants are feel choices. The tests check requirement bounds, so tuning within those bounds keeps the suite green.
- **Sound.** The product overview's sound effect would be another effect in `fire`, next to this one. It is out of scope here.
