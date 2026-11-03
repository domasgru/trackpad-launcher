# Plan: Liquid app switcher

## Problem statement

The switcher (two fingers sliding sideways with the thumb held in the corner) works, but it feels mechanical. It is a glass rectangle with a square glass highlight sliding under a row of icons. Nothing in it answers the fingers with any life. The tap gestures already land with a playful launch bounce, so the switcher feels flat next to them.

## Solution

The switcher becomes one liquid shape. A Liquid Glass band hugs the row of icons, pooling into a soft bead around each one. Around the selected app the liquid swells into a big drop. As the fingers slide, the drop stretches toward the next app and a wave runs through the band. The wave is driven by the fingers: faster slides make bigger waves. When the selection moves on, the liquid flows over and wraps the new app, and the old drop drains back into its bead. When the fingers stop, the liquid settles with a small wobble and goes still. Which apps show, how far the fingers travel per app, the ticks and what lifting does all stay as they are.

The liquid replaces today's look for everyone. There is no setting.

## Requirements

### R1. The switcher is one liquid shape
The switcher MUST show as a single continuous shape that encloses every icon in its row, with no rectangular panel around it.

#### Scenario: Five running apps
- **GIVEN** five apps in the switcher's row
- **WHEN** the switcher opens
- **THEN** one unbroken shape surrounds all five icons, and no rectangle frames the row

#### Scenario: One app
- **GIVEN** a row of one app (no app is in front, and one other app runs)
- **WHEN** the switcher opens
- **THEN** the shape is a single swell around that one enlarged icon

### R2. The liquid is Liquid Glass
The shape MUST look like the system's Liquid Glass, like today's switcher panel, in both light and dark appearance. The swell carries no tint.

#### Scenario: Dark appearance
- **GIVEN** the Mac uses the dark appearance
- **WHEN** the switcher opens over a busy window
- **THEN** the shape reads as glass over that window, and every icon and the swell stay clearly visible

#### Scenario: Light appearance over a white window
- **GIVEN** the Mac uses the light appearance and a mostly white window sits under the switcher
- **WHEN** the switcher opens
- **THEN** the band, each bead and the swell are each distinguishable from the window and from each other

### R3. Each unselected icon sits in its own bead
Around each unselected icon the band MUST form a soft rounded bump, and between two neighbouring icons it MUST narrow into a neck that still joins them.

#### Scenario: Still row
- **GIVEN** an open switcher with fingers at rest
- **WHEN** the user looks at two neighbouring unselected icons
- **THEN** each sits in its own rounded bump and the band between them is narrower but unbroken

### R4. The selected app sits in a swell
Around the selected icon the liquid MUST swell clearly bigger than a bead, by 12 pt beyond the beads on each side. The selected icon MUST still be drawn larger than the others (1.12×), and it stays inside the swell.

#### Scenario: Switcher opens on the frontmost app
- **WHEN** the switcher opens
- **THEN** the first icon, the app in front, sits enlarged in the swell and every other icon sits in a bead

### R5. The swell stretches toward where the fingers head
While the fingers slide but the selection has not changed yet, the swell's trailing edge and the enlarged icon MUST NOT move. Only the swell's leading edge extends toward the direction of the slide, and it grows with the distance travelled. When the fingers slide back, the swell MUST spring back toward the selected icon.

#### Scenario: Slide just under half a step
- **GIVEN** an open switcher with the first app selected
- **WHEN** the fingers slide right 5 mm, short of the 6 mm that changes the selection
- **THEN** the swell still wraps the first icon, its left edge and the enlarged icon stay put, and its right edge visibly reaches toward the second

#### Scenario: Slide back before the change
- **GIVEN** the swell stretched toward the second icon
- **WHEN** the fingers slide back to where they started
- **THEN** the swell springs back around the first icon and settles there

### R6. The liquid flows to the newly selected app
When the selection changes, the swell MUST flow from the old icon to the new one and wrap it, while the old icon's liquid drains back to a bead. The swell MUST reach the new icon within 200 ms of the change, ending with a small wobble. A selection change that arrives while a flow is still running MUST retarget that flow to the newest selected icon rather than queue behind it.

#### Scenario: One step right
- **GIVEN** the first app selected
- **WHEN** the fingers slide right past 6 mm
- **THEN** the liquid flows to the second icon, swells around it, and the first icon is left in a bead

#### Scenario: Steady slide across five apps
- **GIVEN** the first app selected
- **WHEN** the fingers slide right steadily so the selection changes about every 150 ms
- **THEN** the swell is always around or flowing into the currently selected icon, never two icons behind, and does not play catch-up after the fingers stop

### R7. Crossing several apps at once ends on the final one
When the selection crosses several apps at once, the liquid MUST end around the app finally selected.

#### Scenario: Fast flick across three apps
- **GIVEN** the first app selected
- **WHEN** one quick movement moves the selection to the fourth app
- **THEN** the liquid ends in a swell around the fourth icon, and the first three icons are left in beads

### R8. A finger-driven wave runs through the band
Finger movement MUST send a wave through the band in the direction of the slide. The wave is biggest near the swell and weakens with distance from it. Its size MUST grow with finger speed: a fast slide makes a bigger wave than a slow one over the same distance. However fast the slide, the wave MUST NOT break the band, move an icon out of its bead or swell, or raise a bead beyond the wave's own maximum. That maximum is 12 pt beyond the beads on each side by default (as far as the swell rises), and it does not follow the swell's size.

#### Scenario: Fast versus slow slide
- **GIVEN** two swipes that each move the selection by one app
- **WHEN** one moves quickly and the other slowly
- **THEN** the quick one makes a visibly bigger wave through the band than the slow one

#### Scenario: Far icons ripple less
- **GIVEN** a row of ten apps with the first selected
- **WHEN** the fingers slide right
- **THEN** the beads near the swell ripple more than the beads at the far end

#### Scenario: Hardest flick
- **GIVEN** an open switcher
- **WHEN** the user flicks as fast as they can across the row
- **THEN** the band stays one unbroken shape and every icon stays inside its bead or swell

### R9. The liquid settles when the fingers stop
When the fingers stop moving, the liquid MUST settle with a small wobble within one second. Once settled, the liquid MUST NOT move again until the fingers move.

#### Scenario: Pause mid-swipe
- **GIVEN** the fingers have just moved the selection to the third app
- **WHEN** the fingers rest without moving for two seconds
- **THEN** the liquid has stopped moving, with the swell around the third icon

### R10. Past an end the drop stretches outward
The selection stops at the first and last app. Finger travel past an end MUST pull only the swell's outer edge outward past that end icon, like a drop being pulled. The band and the other beads MUST NOT move. The pull grows with the extra travel and MUST NOT exceed a fifth of the distance between two icon centres (20 pt at full size). Most of it is reached within 3 mm past the end. The pull lasts only while the fingers keep moving past the end: when they stop moving or turn back, the swell MUST spring back around the end icon with a wobble.

#### Scenario: Push past the last app
- **GIVEN** the last app selected
- **WHEN** the fingers keep sliding right
- **THEN** the swell's right edge stretches out past the last icon while the band and other beads stay put, stops growing at 20 pt, and springs back around the last icon with a wobble when the fingers slide left

#### Scenario: Rest past the last app
- **GIVEN** the last app selected and the swell pulled out past it
- **WHEN** the fingers stop moving, still past the end
- **THEN** the swell springs back around the last icon with a wobble and settles there, though the fingers have not turned back

### R11. The switcher opens at once
The switcher MUST appear the moment the swipe begins, already settled, with the swell around the first icon. There is no grow-in or pour animation. Any wave from the opening movement MUST begin at once. When the switcher closes, the shape fades out over 150 ms, as the switcher does today.

#### Scenario: Swipe starts
- **WHEN** the swipe begins
- **THEN** the liquid shape is fully on screen in the same moment with the swell around the first icon, and nothing grows or pours in

### R12. Lifting never waits for the liquid
Lifting MUST bring the selected app to the front and start closing the switcher at once, even while the liquid is flowing, stretching or wobbling.

#### Scenario: Lift during a flow
- **GIVEN** the selection just changed from the first to the fourth app and the liquid is still flowing
- **WHEN** the fingers lift
- **THEN** the fourth app comes to the front immediately and the switcher closes

#### Scenario: Lift during a stretch
- **GIVEN** the first app, the app in front, selected and the swell stretched toward the second
- **WHEN** the fingers lift
- **THEN** no app changes and the switcher closes

### R13. Reduce Motion keeps the shape and drops the motion
With Reduce Motion on, the shape, beads and swell MUST still show. There MUST be no wave, stretch, flow or wobble: the swell jumps straight to the newly selected icon.

#### Scenario: Step with Reduce Motion on
- **GIVEN** Reduce Motion is on and the first app is selected
- **WHEN** the fingers slide right past 6 mm
- **THEN** the swell appears around the second icon at once, the first icon is in a bead, and nothing ripples

#### Scenario: Push past the last app with Reduce Motion on
- **GIVEN** Reduce Motion is on and the last app is selected
- **WHEN** the fingers keep sliding right
- **THEN** the swell stays around the last icon and nothing stretches

### R14. The shape follows the row's size
The shape MUST keep its proportions to the icons when the row shrinks to fit a narrow display, so every icon still sits in its bead or swell. The row stays centred on the display under the pointer.

#### Scenario: Ten apps on a narrow display
- **GIVEN** ten apps and a display too narrow for the row at full size
- **WHEN** the switcher opens
- **THEN** the icons, beads, swell and band all shrink by the same factor, and the shape still fits on the display

### R15. The liquid keeps up with the fingers
The liquid MUST respond to finger movement without visible lag, and its motion MUST stay smooth at the display's full refresh rate, including 120 Hz displays, with ten apps in the row.

#### Scenario: Continuous slide on a 120 Hz display
- **GIVEN** ten apps on a 120 Hz display
- **WHEN** the fingers slide back and forth for several seconds
- **THEN** the motion shows no stutter, and the swell never trails visibly behind the fingers

### R16. The liquid costs nothing at rest
While the liquid is settled and while the switcher is hidden, the liquid MUST NOT redraw or run animation work.

#### Scenario: Fingers resting on a settled switcher
- **GIVEN** an open switcher with fingers resting and the liquid settled
- **WHEN** two seconds pass
- **THEN** the switcher draws no new frames

### R17. The look is easy to tune
The swell's size, the bead and neck shape, the wave's strength and reach, and the wobble MUST each be adjustable in one place. Making the swell subtle MUST take changing one setting in that place.

#### Scenario: Make the swell subtle
- **GIVEN** a developer who wants a subtler swell
- **WHEN** they lower the swell size there
- **THEN** the swell rises only a few points beyond the band, and nothing else about the switcher changes

## Non-goals

- **The window switcher** (two fingers up or down) keeps its look. It can adopt the liquid later if this one works out.
- **A setting to switch back** to the old look. The liquid replaces it for everyone.
- **A liquid open or close animation.** Opening must be instant (R11). A liquid close can be a later extra.
- **Idle motion.** The liquid does not breathe or undulate while the fingers rest (R9).
- **An accent tint on the swell.** Plain glass is the look; if the light-appearance scenario fails, a tint goes back to the user to decide.
- **The tap gestures' launch bounce** is unchanged.
- **An app quitting while the switcher shows.** The row and its icons behave as they do today; the shape does not re-form.
- **Selection, ticks, row contents and lifting.** Travel per app, the half-step change point, the stop at each end, haptic ticks, which apps show and what lifting does all stay as they are.

## Design

### Problem

The app switcher becomes one Liquid Glass shape: a band with a bead around each icon, and a swell around the selected icon. The swell stretches, flows, wobbles and settles, and a wave driven by the fingers runs through the beads (R1 to R17). Four facts make the shape non-obvious. All were probed on this machine (grounding `index.md`, checks `checks/index.md` under `.temp/architect/`).

- **Only SDF-merged glass reads as Liquid Glass.** That means `NSGlassEffectView`s merged by an `NSGlassEffectContainerView` (A1, A2, A8). AppKit glass comes only as rounded rectangles (A11), so the shape is a union of rounded-rect glass views.
- **The render server animates the merged shape only through AppKit's private `CASDFElementLayer` mirror** of each glass view (A5).
  - An additive animation on a mirrored element survives AppKit's re-sync. A direct write does not (A6).
  - Every public path steps frames in our process once per display frame, at 30 to 100 times the CPU (A4). That is against `docs/architecture.md`'s rule that the render server plays animation and no code of ours runs per display frame (B1, B2).
- **The mirror has a lifecycle the design must respect.**
  - It exists only once the window has been ordered front and a transaction flushed (K1).
  - Adding, removing or hiding a glass view rebuilds the elements as new objects, lazily (K4, K5).
  - With a fixed set of views, the elements keep their identity across order-out, re-layout and order-in (K3).
  - A view frame set reaches its element during the transaction's commit, together with any animation added in that transaction (K9).
- **Flow, wobble, settle, spring-back and wave decay all continue after the last input event**, and nothing triggers our code then (`how.md` gotcha 2). So each motion is staged whole, at an input event, and ends by itself.

Constraints carried over:

- These stay untouched: the window switcher, `SwitcherSelection`, `GestureRules`, the recognizer, `SwipeEvent` and every port.
- `LauncherUI` cannot see `LauncherPlatform` (B4).
- `OverlayPanel` is shared with the window switcher (C6).
- R12 already holds in `Launcher.swipe` (C8).
- `Observations` may coalesce values, so every observed value is an absolute target, never an increment.

### Usage (caller's view)

> **`Liquid`** (LauncherCore) is the switcher's liquid, as numbers.
>
> 1. Build a `SwitcherRowLayout` for the row from a `LiquidLook`.
> 2. Make one `Liquid` per swipe.
> 3. Hand it every selection the model shows, with the time on your clock.
>
> Each call returns a `LiquidFrame`: the swell view's new resting rect (only when the selection moved), the icon to grow, and the keyframe tracks to stage. Each track replaces the running track of its channel. Apply the frame and forget it: nothing calls back, none of your code runs between calls, and every track ends by itself within a second. `shape(at:)` tells you what the render server shows at any instant. `.still` is the Reduce Motion look, and the look whenever the glass mirror is not available.

**Call site 1: `SwitcherPresenter` (LauncherUI), once per observed value.**

```swift
private func render(_ switcher: Switcher?) {
    guard let switcher else { liquid = nil; return panel.dismiss() }     // 150 ms fade (R11); the lift never waits (R12)
    let now = LiquidTime(seconds: CACurrentMediaTime())                    // Core Animation's clock, read per input event
    if !panel.isPresented || switcher.row != laidOutRow { return open(switcher, at: now) }
    guard let frame = liquid?.follow(switcher.selection, at: now), !frame.isEmpty else { return }   // nothing changed: no commit
    panel.apply(frame)
}

private func open(_ switcher: Switcher, at now: LiquidTime) {
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let layout = SwitcherRowLayout(
        iconCount: switcher.row.count, displayWidth: Double(screen?.frame.width ?? 0), look: look())   // one snapshot per swipe
    panel.lay(out: switcher.row.map { icons.icon(forSwitcher: $0) }, layout: layout,
              on: screen?.frame ?? .zero, backingScale: screen?.backingScaleFactor ?? 2)
    panel.present(appear: nil)                                             // on screen now, settled (R11)
    // checkMirror flushes the laid-out frames, then checks the mirror once for the whole swipe (K1, K3)
    let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !panel.checkMirror()
    var liquid = Liquid(layout: layout, motion: still ? .still : .flowing)
    panel.apply(liquid.follow(switcher.selection, at: now))                // first call: settled, no tracks
    self.liquid = liquid
    laidOutRow = switcher.row
}
```

**Call site 2: `SwitcherPanel.apply` (LauncherUI), the only code that moves glass.**

```swift
func apply(_ frame: LiquidFrame) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if let rest = frame.swell { swellView.frame = NSRect(rest) }      // public; mirrored at this commit, with the tracks (K9)
    if let icon = frame.icon { grow(icon) }                            // our own icon layers
    if let mirror = liveMirror {                                       // checked once at open; nil: the rests alone show
        for track in frame.tracks {
            let layer = mirror.layer(for: track.channel.element)
            layer.add(LiquidKeyframes.animation(track, beginTime: layer.convertTime(track.begin.seconds, from: nil)),
                      forKey: LiquidKeyframes.key(track.channel))   // a channel's key replaces its running track: never queues
        }
    }
    CATransaction.commit()
}
```

**Call site 3: scenario tests (LauncherCoreTests, through `World`).**

```swift
@Test func quickSwipeMakesABiggerWaveThanASlowOne() {                       // R8
    let fast = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(60))
    let slow = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(600))
    #expect(fast.peakRipple(bead: 2) > 1.5 * slow.peakRipple(bead: 2))
}

@Test func liquidReachesTheNewIconWithin200ms() throws {                     // R6
    let run = World.switcherWorld().liquidSwipe(rightMM: 12, over: .milliseconds(80))   // a whole step: no lean left
    let change = try #require(run.selectionChanges.first)
    #expect(run.liquid.shape(at: change.time + 0.2).swell.isWithin(run.layout.look.wobble, of: run.layout.swell(at: 1)))
}

@Test func reduceMotionJumpsAndNothingRipples() {                           // R13
    let run = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(80), motion: .still)
    #expect(run.frames.allSatisfy { $0.frame.tracks.isEmpty })
    #expect(run.frames.compactMap(\.frame.swell).last == run.layout.swell(at: 1))
}
```

**Call site 4: the composition root, and making the swell subtle.**

```swift
// App target: Release passes { .shipped }; DEBUG builds read the tuner's override.
shell = SettingsShell(launcher: launcher, liquidLook: { LiquidTuning.current }, quit: { [unowned self] in lifecycle.quit() })

// LauncherCore, LiquidLook: the only edit a subtler swell needs (R17)
public var swellRise = 12.0   // → 3
```

### Shape

**Data first. There are three values, each with one owner.**

1. **Geometry: `SwitcherRowLayout(iconCount:displayWidth:look:)`.** It stays the one geometry source (plan 008, decision 10) and carries the `LiquidLook` it was built from. Everything hangs off one `centreX(at:)` and one `scale`: every resting rect, every corner radius, the container's spacing, the panel size, the wave's limits and the icons' places.
   - The full-size defaults are probe P5's look: icon 80 pt, pitch 100 pt; bead 80 pt with corner 0.32 of its side; band 52 pt thick, a capsule from the first icon's centre to the last; swell = bead + 2 × `swellRise` = 104 pt; spacing 40.
   - Every length, radius, the spacing and every limit is multiplied by `scale` (R14).
   - The panel reserves `room` (40 pt at full size) beyond the beads on every side. That room holds the swell's rise, R10's 20 pt pull and the wave's cap, `waveMax`. The swell's rise and the wave's cap are each clamped so they always fit. The scale depends on the icons and that fixed room, never on the swell's size, so a subtler swell changes nothing else (R17). The panel is centred on the display as today.
2. **Motion state: `Liquid`, one per swipe.** It holds the last selection fed (from which come `selected`, `position` and the overshoot from `travelMM`), two `EdgeCurve`s (the swell's left and right edges, in panel points), a `WaveTrain` of crests, a speed estimate, and the mode.
   - **A new selection value means the fingers moved.** `SwitcherSelection`'s `==` includes the travel last reported, so every move event yields a new value, even a push against the clamp past an end. Resting fingers yield none, and a repeated value is no movement.
   - **`EdgeCurve` is the single motion primitive.** It approaches a target along a cubic Hermite, from its current position and velocity to the target and an arrival velocity, over a time `T`. Then it wobbles around the target as a damped sine seeded by that arrival velocity. It is windowed to end exactly at the target at most 1 s after it starts. Flow, finger follow, spring-back and end pull are four parameter choices of this one curve.
   - **Every tail is bounded.** Every arrival velocity, the flow's and the finger follow's alike, is clamped so its damped sine stays within `wobble` of the target (R9's small wobble). Past an end, the outer edge's whole curve, wobble included, stays within the pull cap (R10).
   - **The end pull lasts only while the fingers move (R10).** Past an end, each new selection value re-pulls the outer edge toward P(overshoot) and keeps it there for `pullHold` (60 ms, several trackpad frames). The curve then springs back around the end icon with a wobble and ends at the rest within the 1 s window. A track that ends at 0 is not held.
     - A continuous push, even against the clamp, keeps the pull out.
     - Resting fingers spring it back after `pullHold`.
     - Turning back sets the overshoot to 0, so the edge follows back at once.
   - **`WaveTrain` is a list of crests**, each with an emission time, an origin in items, a direction and a strength. Bead `i`'s height offset is `saturate(Σ strength × falloff(d) × ripple(t − emitted − d / c))`, where `d` is the distance in items and `c` the wave's speed.
3. **Output: `LiquidFrame`.** It carries three things:
   - `swell`: the swell view's new rest, only on a selection change;
   - `icon`: the selected icon and how long it grows;
   - `tracks`: additive offsets per channel `(element, property)`, sampled at 120 Hz from the same functions `shape(at:)` evaluates.

   So what a test reads is what the render server plays.

Derived, never stored: the swell's rest (from `selected`); the swell's height (from its width, by `thinning`, never below the grown icon's visible body plus 4 pt and never above its rest height); every track; and `shape(at:)`. The access patterns, traced:

| When | Work |
|---|---|
| Each event | Compare the input. Retarget two edges from their closed-form state at `t`. Sample three swell tracks. |
| Each crest (at most every half icon) | Sample the beads' height tracks. |
| Each test | `shape(at:)` at any instant, in closed form. |

No index or cache is needed.

**D1. The glass: a fixed set of twelve views, with the band as the neck.**

- One `NSGlassEffectContainerView` holds twelve `.regular` glass views, created with the panel and never added, removed or hidden: the band, ten beads and the swell. This is fixed membership, so the mirror keeps its identity (K3, K4, K5).
- Between beads the band is the narrower neck (R3). The shape is therefore unbroken whatever the spacing (A2, `p3-rest.png`, `p5-light-white.png`).
- A row shorter than ten lays its spare beads exactly over the band. The band never animates, so the spares never mask a real bead's motion. Identical shapes are neutral to the union (K6, K8), and the SDF bounds stay the row's (K3). Parking spares outside the window would grow the render area (K2).
- With one app, the band and the nine spares lie exactly over its bead, and the swell encloses them (R1's one-app scenario).
- No tint (R2). The window stays clear, borderless and shadowed. Its shadow traces the merged shape and follows it, with no `roundedClip` (A9). R2's light-over-white look leans on that shadow (A10).
- Icons are our own `CALayer`s, in a sibling view above the container, placed by the same `centreX`. Icons and shape cannot drift apart.

**D2. Motion: render-server keyframes on the private mirror, with the views as the truth.**

- **Views.** Glass views get public frames only in `lay(out:)` (all of them) and on a selection change (the swell only). Each frame set reaches its element in the same commit as that frame's tracks (K9). The offsets are computed in Core against the new rest; nothing is read back from the element.
- **Tracks.** Everything else is an additive `CAKeyframeAnimation` on the swell's or a bead's mirrored element, one key per channel, with linear calculation mode (the `LaunchFlight` precedent).
  - A track whose last offset is 0 removes itself when it completes.
  - A track that ends on a held offset (R5's lean, while the fingers rest inside the row) stays filled forwards, as the launch bounce's inflate does. A finished, filled animation costs nothing at rest (K11). R10's pull never holds: its tracks end at 0.
  - Additive animations survive AppKit's re-sync (A6), so nothing staged is clobbered. If anything private misbehaves, the views already show the correct resting shape.
- **`GlassMirror` (LauncherUI) is the one place that knows the mirror.** The source scan confines the token `CASDFElementLayer` to its file.
  - It is matched once, at a pre-warm. When the panel is created, it is laid out with a ten-icon template in which all twelve frames are distinct, ordered front at zero opacity, flushed, matched by class name and frame (each view to exactly one element within 0.5 pt), and ordered out. A zero-opacity pre-warm builds the mirror and shows nothing (K12). It also pays the first window's cost ahead of any swipe.
  - The match is then kept by identity (K3, K12).
  - It only reads the tree and adds public `CAAnimation`s: no `dlsym`, no private properties.
- **Liveness, once per swipe.** After `present`, `checkMirror()` flushes the laid-out frames, so every element holds its view's frame (K9). It then checks that every matched layer is still in the container's tree at its view's frame.
  - The answer holds for the whole swipe, and `apply` stages tracks only if it was yes. Liveness is never read inside `apply`'s transaction, where a frame set has not reached its element yet.
  - If the answer is no, that swipe opens `.still`. After the fade, `emptied()` checks the mirror itself and re-runs the pre-warm only if it is not live, so a Reduce Motion swipe, which never calls `checkMirror()`, does no work while hidden. Motion never latches off.
  - If the class is gone in a macOS update, every swipe opens `.still`: the swell jumps by a view frame on each selection change and nothing else runs per event, which is R13's look.
- **No rule change.** This is the architecture rule's own text: "Animation is Core Animation keyframes, which the render server plays". Only wording is added (see Docs below).

**D3. The per-event path, and 120 Hz (R15).**

- **One `.moved` event** runs `Observations`, then `render`, `follow` and `apply`: one Core Animation commit with at most three swell tracks. A crest adds ten bead tracks. A selection change adds one view frame set and the icon grow.
- **Between trackpad frames** (about 100 Hz, C5), the follow approach restarts from the current state at every event, over `followTime` (1/60 s). The render server therefore moves the swell on every display frame, and the lag is at most `followTime`.
- **Cost.** Tracks are sampled at 120 Hz, the fastest display rate, which is half the samples of the measured 240 Hz case.
  - At 240 Hz, three 240-sample tracks per event plus ten bead tracks every fifth event cost about 7% of a core (K10).
  - That compares with about 11% for today's switcher (C9) and 26% for public frame sets (A7).
- **Under `.still`**, `follow` returns an empty frame unless the selection changed, so there is no commit per event at all.

**D4. Finger speed (R8) is measured inside `Liquid`, on the liquid's clock.**

- **Speed.** A crest's strength comes from the change in position since the last crest, divided by the time between them, with an 8 ms floor. Coalescing only lengthens the time span, which still gives the correct average. No new signal crosses the recognizer, the port or the model.
- **Bounds hold whatever the speed:**
  - strength = `waveHeight × tanh(speed / waveFullSpeed)`;
  - each bead's offset is soft-saturated into limits the layout derives. A bead grows at most `waveMax` beyond its rest on each side. That is the wave's own cap, 12 pt by default, independent of the swell's size, so a subtle swell does not lower it. A bead dips at most to `iconBody + 4` pt, and never below the band.
  - The band never animates and icons never move.

  So R8's hardest flick holds by construction.

**D5. Retarget, lift, open, close (R6, R7, R11, R12).**

- **Retarget.** Every `follow` takes an absolute target, and every curve restarts from its own current position and velocity: no velocity kink, no queue. The swell view jumps to the newest selected icon's rest, and the tracks carry the shape the rest of the way.
- **Flow.** The leading edge arrives at `leadShare × T` and the trailing edge at `T`, with `T = min(flowTime, 0.2 s)`. Mid-flow the drop spans both icons; it ends on the new icon with a wobble. The icon grows over the leading edge's arrival time, so the icon and the drop arrive together.
- **Flick.** A flick across three apps is one jump of the rest and one flow. The middle icons are never targeted (R7).
- **Lift.** The model brings the app to front first (C8). `render(nil)` then fades the window over 150 ms over whatever is still moving.
- **Open.** The first `follow` returns a settled frame: the swell at rest, the icon at 1.12× at once, no tracks. Crests begin on the first movement.
- **Re-open during the fade.** The existing generation guard cancels the fade. `lay(out:)` removes every liquid animation and sets every frame again, so laying out twice is harmless.
- **Close.** `emptied()`, the fade's completion, removes every liquid animation and puts the swell at its rest. Nothing staged outlives the switcher.

**D6. Reduce Motion, and zero work at rest (R13, R16).**

- Reduce Motion is read once at open and selects `.still`.
- At rest no events arrive, so none of our code runs. Every curve ends at most 1 s after its event. Held offsets are finished, filled animations, which cost nothing (K11). While hidden, the window is ordered out and empty.
- Nothing loops or repeats.

**D7. Tuning (R17).**

- `LiquidLook` lives in LauncherCore: plain numbers, `shipped` as the defaults, and `Codable` only in DEBUG builds, with a missing-key fallback (the `LaunchTuning` precedent).
- Every module that needs it can reach it:
  - the UI renders it;
  - `LaunchTuning.liquid` lets the DEBUG tuner edit it in a "Liquid switcher" section;
  - the app target injects `{ LiquidTuning.current }` into `SettingsShell` and on to `SwitcherPresenter`, which reads it once per swipe.
- `swellRise` is the one swell setting. `waveMax` is the wave's own cap, and no other setting moves it.
- The requirement bounds are private constants of `Liquid`, so no look can break them: flow at most 0.2 s, settle at most 1 s, end pull at most 0.2 pitch.

**D8. `OverlayPanel` (C6).**

- Its designated initialiser becomes `init(content:)`, which keeps the window configuration, `present`, the 150 ms fade and the generation guard.
- Today's rounded `.regular` glass in `roundedClip` becomes a helper, `roundedGlass(_:cornerRadius:)`. `WindowSwitcherPanel` passes its content through it, so the window switcher is unchanged.
- `SwitcherPanel` passes its own layer-backed root view: the container plus the icon host.

**Interface depth.**

- The public surface of `Liquid` is `init(layout:motion:)`, `follow(_:at:)`, `shape(at:)` and plain value types.
- Behind that surface: the lean, pull and flow policy, the curves and the wave, the speed estimate, saturation, windowing, sampling, idempotence, and the R6, R9 and R10 bounds.
- The adapter decides nothing. It maps a channel to a key and a layer.
- The Core Animation key string is the adapter's. Core knows only the channel and that a channel's new track replaces its old one.

**What the design deliberately does not do.**

- The band never moves.
- No motion while hidden or settled, and no idle motion.
- The shape does not re-form when an app quits.
- A Reduce Motion change applies from the next swipe.
- No motion carries over from one swipe to the next.

**Traceability.**

| R | Carried by |
|---|---|
| R1 | `SwitcherRowLayout.band` / `bead(at:)` / `swell(at:)` in one container; spares and, with one app, the band lie over existing shapes |
| R2 | `.regular` glass, no tint, a clear shadowed window; checked by hand |
| R3 | `bandThickness` < `beadSide`; the band between beads is the neck |
| R4 | `swell(at:)` = bead + 2 × `swellRise`; the icon drawn at 1.12×; the swell never thinner than `selectedIconBody` + 4 pt, the grown icon's visible body, so the icon stays inside even with a subtle swell |
| R5 | The leading-edge target is rest + `reach` × lean × pitch, with lean = position − selected; the trailing edge is pinned; the follow curve's tail springs back |
| R6 | `LiquidFrame.swell` plus the flow `EdgeCurve` (arrival ≤ 0.2 s, then a wobble), retargeted from the current state |
| R7 | The rest jumps to the final icon; one flow |
| R8 | `WaveTrain`: tanh(speed), e^(−d / `waveReach`) falloff, the slide's direction, saturation into `beadLimits` (the wave's own cap, `waveMax`), a static band |
| R9 | Every curve windowed to end ≤ 1 s after its cause; every tail within `wobble`; empty frames at rest |
| R10 | pull = P × (1 − e^(−o / `endPullMM`)), with P = min(`endPull`, 0.2 × pitch), the outer edge's whole curve capped at P; the outer edge only; no crests past an end; each move re-pulls, and with no move for `pullHold`, or on the turn back, the edge springs back to the end icon with a wobble (never held) |
| R11 | The first `follow` is settled; `present(appear: nil)`; the fade in `OverlayPanel.dismiss` |
| R12 | `Launcher.swipe(.ended)` unchanged; `render(nil)` never waits |
| R13 | `LiquidMotion.still` |
| R14 | `SwitcherRowLayout.scale` on every length, from the icons and the fixed `room` |
| R15 | D3 |
| R16 | D6; `emptied()` |
| R17 | `LiquidLook`, `swellRise` (it moves no other dimension: the scale comes from `room`) |

**Module map.**

| Module | What it holds |
|---|---|
| LauncherCore | `LiquidLook`; `SwitcherRowLayout` (extended); `Liquid` with its private `EdgeCurve`, `WaveTrain` and sampler; the frame values. `Switcher`, `SwitcherSelection`, `GestureRules`, `Launcher` and the recognizer are unchanged. |
| LauncherUI | `SwitcherPresenter` (thin); `SwitcherPanel` (rewritten); `LiquidKeyframes`; `GlassMirror` (the only private reach); `OverlayPanel(content:)`; `roundedGlass`. `WindowSwitcherPanel` changes one init line. |
| LauncherPlatform | `LaunchTuning.liquid` and a tuner section; the public `LiquidTuning.current`. |
| App target | Injects the look closure. |
| Tests | `LiquidTests` and a `World.liquidSwipe` helper in LauncherCoreTests; `SwitcherRowLayoutTests` retired; a new `LauncherUITests` target for `LiquidKeyframes`, `GlassMirror.match` and a real-window `SwitcherPanel` suite; `SourcePolicyTests` confines `CASDFElementLayer` to `GlassMirror.swift`. |

**LauncherCore.**

```swift
/// Every number of the switcher's liquid look and motion, at full size (points, seconds, items). The defaults ARE the
/// shipped look. Requirement bounds are not here: `Liquid` enforces them whatever this holds.
public struct LiquidLook: Equatable, Sendable {
    // Shape (R1–R4; R17 "bead and neck shape")
    public var beadSide = 80.0, beadCorner = 0.32          // corner as a share of the side
    public var bandThickness = 52.0                         // the neck
    public var spacing = 40.0                               // the container's merge distance: how soft the necks' fillets are
    /// THE swell setting (R4, R17): how far the swell rises beyond a bead on each side. 3 is subtle. It moves nothing
    /// else: the scale and the panel come from `room`; the rise is clamped to fit it with the pull.
    public var swellRise = 12.0, swellCorner = 0.32
    /// The panel's clear margin beyond the beads on every side: the swell's rise, R10's pull and the wave's cap live in it.
    public var room = 40.0
    /// The visible body of an 80 pt icon. A wave never dips a bead within 4 pt of it (R8), and the swell never thins
    /// below the grown body plus 4 pt (R4). Checked by hand against real icons.
    public var iconBody = 64.0
    // Stretch, flow, end pull (R5, R6, R10)
    public var reach = 0.5                                  // leading-edge stretch per item of lean
    public var followTime = 1.0 / 60                        // glide between input events (R15)
    public var flowTime = 0.18, leadShare = 0.6             // Liquid caps flowTime at 0.2 s
    public var endPull = 20.0, endPullMM = 1.0              // capped at 0.2 pitch; e-fold per step-mm, so 95% by 3 mm
    public var pullHold = 0.06                              // the pull stays out this long after the last move, then springs back (R10)
    public var thinning = 0.25                              // swell height lost per point of stretch
    // Wobble (R6, R9)
    public var wobble = 4.0, wobbleHz = 4.5, wobbleDamping = 0.35
    // Wave (R8)
    public var waveHeight = 6.0, waveFullSpeed = 8.0        // crest in points at full speed; items per second for full speed
    /// THE wave cap (R8): the most a wave raises a bead's edge beyond its rest, on each side. Its own setting: the
    /// swell's size never lowers it (R17). Clamped to fit `room`.
    public var waveMax = 12.0
    public var waveReach = 2.5, waveSpeed = 14.0            // items to 1/e; items per second along the band
    public var waveHz = 5.0, waveDamping = 0.4, waveBehind = 0.3, waveEvery = 0.5

    public static let shipped = LiquidLook()
    public init() {}
}

#if DEBUG
/// Missing keys decode as shipped, so saved tuner presets survive new knobs (TunerCodingTests precedent).
extension LiquidLook: Codable {
    public init(from decoder: any Decoder) throws { fatalError("not implemented") }
}
#endif

/// The one geometry source: icons, band, beads and swell all hang off `centreX(at:)` and `scale`, so they cannot drift.
public struct SwitcherRowLayout: Equatable, Sendable {
    public static let fullIconSide = 80.0, fullPitch = 100.0, selectedIconScale = 1.12
    public let iconCount: Int
    /// The look both the geometry and the motion read: one snapshot per swipe.
    public let look: LiquidLook
    /// One factor for every length, radius, spacing and limit (R14):
    /// min(1, displayWidth / ((n − 1) × 100 + beadSide + 2 × room)). Independent of the swell's size (R17).
    /// A non-positive width means 1.
    public let scale: Double
    public init(iconCount: Int, displayWidth: Double, look: LiquidLook = .shipped) { fatalError("not implemented") }

    public var iconSide: Double { Self.fullIconSide * scale }
    /// The grown icon's visible body: `iconBody` × 1.12, scaled. The swell never thins below it plus 4 pt (R4).
    public var selectedIconBody: Double { look.iconBody * Self.selectedIconScale * scale }
    /// The rise actually drawn: `swellRise`, clamped so the swell pulled by R10's cap still fits in `room`.
    public var swellRise: Double { fatalError("not implemented") }
    public var pitch: Double { Self.fullPitch * scale }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    public func centreX(at position: Double) -> Double { fatalError("not implemented") }
    public var centreY: Double { panelSize.height / 2 }
    /// First icon centre to last, a capsule; with one icon, exactly the bead.
    public var band: LiquidRect { fatalError("not implemented") }
    /// A bead per icon; `index` ≥ `iconCount` is a spare, laid exactly over the band.
    public func bead(at index: Int) -> LiquidRect { fatalError("not implemented") }
    public func swell(at index: Int) -> LiquidRect { fatalError("not implemented") }   // bead + 2 × rise, same centre
    public var radii: (band: Double, bead: Double, swell: Double) { fatalError("not implemented") }
    public var spacing: Double { look.spacing * scale }
    /// How far a wave may raise or dip a bead (R8): up to bead + 2 × `waveMax` (clamped to fit `room`, independent of
    /// the swell), down to iconBody + 4, never below the band.
    public var beadLimits: ClosedRange<Double> { fatalError("not implemented") }
}

public struct LiquidRect: Equatable, Sendable { public var minX, minY, width, height: Double }

/// Seconds on the clock tracks begin on: Core Animation's media time on hardware, frame times in tests.
public struct LiquidTime: Comparable, Sendable {
    public var seconds: Double
    public static func + (t: Self, s: Double) -> Self { fatalError("not implemented") }
}

public enum LiquidMotion: Sendable {
    /// Render-server motion: stretch, flow, wobble, wave, end pull.
    case flowing
    /// Reduce Motion, or the glass mirror is not live: the swell jumps to the selected icon; nothing stretches or ripples (R13).
    case still
}

/// The switcher's liquid during one swipe.
public struct Liquid: Sendable {
    public init(layout: SwitcherRowLayout, motion: LiquidMotion) { fatalError("not implemented") }

    /// The first call returns the settled opening (R11): the swell's rest, the icon at once, no tracks. Later calls
    /// return only what changed: on a selection change, the swell's new rest and the growing icon; and the tracks that
    /// replace their channels' running ones, each starting where and as fast as its channel is at `time`. The frame
    /// is empty when `selection` equals the last one fed: a repeated call, and resting fingers. `SwitcherSelection`'s
    /// `==` includes the travel last reported, so every move is a new value, even a push against the clamp past an end,
    /// which re-pulls the swell (R10). Under `.still`, every call that keeps `selected` is empty.
    public mutating func follow(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        // guard selection != last else { return .empty }
        // opening: settle at input; return (swell: rest(selected), icon: (selected, 0), tracks: [])
        // .still: return selected changed ? (swell: rest, icon: (selected, 0)) : .empty
        // targets: trailing edge = rest edge; leading edge = rest edge + reach × lean × pitch, lean = position − selected;
        //          past an end no crest is emitted
        // selection changed: both edges flow (lead over leadShare × T, trail over T, T = min(flowTime, flowBound)),
        //                    arriving with a velocity whose damped tail stays within `wobble`; the icon grows over lead
        // else: the leading edge follows over followTime, arriving at the estimated finger velocity clamped so its
        //       damped tail stays within `wobble` (the R5/R9 wobble)
        // past an end: the outer edge approaches P(overshoot) over followTime, stays there until `pullHold` after this
        //       call, then springs back to the end icon's rest with a wobble, ending at 0 (never held); each new value
        //       restarts this from the edge's current state; the whole curve, wobble included, stays within the cap P
        // the wave emits a crest each `waveEvery` items of travel (and on the first move); strength tanh(speed)
        // tracks: swell centreX, width, height (thinned, clamped to [selectedIconBody + 4, rest height]) sampled from
        //         the edges against the new rest; on a crest, each real bead's height, saturated into `beadLimits`
        fatalError("not implemented")
    }

    /// What the render server shows at `time`, from what has been staged; constant once settled. Valid for times at or
    /// after the last call that returned a non-empty frame (an empty frame changes no state). It evaluates the same
    /// closed forms the tracks are sampled from, so tests of what plays rebuild the shape from the staged frames instead.
    public func shape(at time: LiquidTime) -> LiquidShape { fatalError("not implemented") }

    static let flowBound = 0.2, settleBound = 1.0, endPullBound = 0.2, sampleRate = 120.0   // R6, R9, R10; K10
}

public struct LiquidFrame: Equatable, Sendable {
    public var swell: LiquidRect?              // the swell view's new frame; nil = unchanged
    public var icon: IconChange?
    public var tracks: [LiquidTrack]           // at most one per channel
    public var isEmpty: Bool { swell == nil && icon == nil && tracks.isEmpty }
}
public struct IconChange: Equatable, Sendable { public let selected: Int; public let duration: Double }   // 0 under .still
public enum LiquidElement: Hashable, Sendable { case swell, bead(Int) }
public enum LiquidProperty: Hashable, Sendable { case centreX, width, height }
/// A channel holds at most one running track: a new track replaces the old one, which is how motion retargets.
public struct LiquidChannel: Hashable, Sendable { public let element: LiquidElement; public let property: LiquidProperty }
/// Additive offsets in points over the element's rest, `step` seconds apart from `begin`. Ends ≤ its cause + settleBound.
public struct LiquidTrack: Equatable, Sendable {
    public let channel: LiquidChannel
    public let begin: LiquidTime, step: Double
    public let offsets: [Double]               // at least two samples, by construction of the sampler
    /// Whether the track ends on a held offset (R5's lean): kept filled; otherwise removed on completion. R10's pull
    /// tracks always end at 0.
    public var holds: Bool { offsets.last != 0 }
}
public struct LiquidShape: Equatable, Sendable { public let band: LiquidRect, beads: [LiquidRect], swell: LiquidRect }

/// One swell edge: a Hermite approach from (x, v) to (target, arrival) over `approach`, then a damped sine around the
/// target, windowed to end at the target ≤ settleBound after `start`.
struct EdgeCurve: Sendable {
    func value(at t: LiquidTime) -> Double { fatalError("not implemented") }
    func velocity(at t: LiquidTime) -> Double { fatalError("not implemented") }
    mutating func retarget(to target: Double, arriving: Double, over approach: Double, at t: LiquidTime) {
        fatalError("not implemented")
    }
}

/// Crests travelling from the swell in the slide's direction; a bead's offset is the saturated sum of their ripples.
struct WaveTrain: Sendable {
    struct Crest { let emitted: LiquidTime; let origin: Double; let direction: Double; let strength: Double }
    mutating func emit(at position: Double, time: LiquidTime) -> Bool { fatalError("not implemented") }
    func offset(bead: Int, at t: LiquidTime) -> Double { fatalError("not implemented") }   // within the layout's limits
}
```

**LauncherUI.**

```swift
/// The app switcher's window. It renders `LiquidFrame`s and decides nothing: twelve glass views in one container and
/// the icon layers above them.
final class SwitcherPanel: OverlayPanel {
    /// Internal, not private, so `@testable` tests can reach the twelve glass views (to make the mirror stale, K4).
    let container = NSGlassEffectContainerView()
    let band = NSGlassEffectView(), beads = (0..<10).map { _ in NSGlassEffectView() }, swellView = NSGlassEffectView()
    private var mirror: GlassMirror?
    /// The mirror for this swipe, set by `checkMirror()` and cleared by `lay(out:)`; nil: the rests alone show.
    private var liveMirror: GlassMirror?
    /// Pre-warms: the ten-icon template laid out, ordered front at zero opacity, flushed, the mirror matched, ordered
    /// out (K12).
    init() { fatalError("not implemented") }
    /// Call once per swipe, after `present`: flushes the laid-out frames (K9), then checks that every matched layer is
    /// still in the tree at its view's frame. True: this swipe's `apply` stages tracks.
    func checkMirror() -> Bool { fatalError("not implemented") }
    func lay(out images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, backingScale: CGFloat) {
        // removes every "liquid." animation; clears liveMirror; sets every view frame and radius (spares over the band)
        // and the spacing; places one icon layer per image at centreX; setFrame once (never per event); idempotent
        fatalError("not implemented")
    }
    func apply(_ frame: LiquidFrame) { fatalError("not implemented") }   // call site 2
    /// After the fade: every liquid animation removed, the swell at rest. Checks `mirror?.isLive` itself, never
    /// `liveMirror` (nil all swipe under Reduce Motion), and re-runs the pre-warm only when the mirror is not live, so a
    /// Reduce Motion swipe does no work while hidden (R16).
    override func emptied() { fatalError("not implemented") }
}

/// Pure staging, read back by tests like LaunchFlightTests: additive, linear calculation, values = offsets, duration
/// from step and count; filled forwards and not removed when the track holds.
enum LiquidKeyframes {
    static func key(_ channel: LiquidChannel) -> String { fatalError("not implemented") }   // "liquid.swell.width", …
    static func animation(_ track: LiquidTrack, beginTime: CFTimeInterval) -> CAKeyframeAnimation { fatalError("not implemented") }
}

/// The one file that knows how AppKit mirrors Liquid Glass (A1, A6); the source scan confines `CASDFElementLayer` here.
/// Matched once by class name and frame, then kept by identity (K3).
struct GlassMirror {
    /// nil when the class is missing, the element count differs from the views', or any view matches no single element.
    static func matched(in container: NSGlassEffectContainerView, views: [(LiquidElement?, NSGlassEffectView)]) -> GlassMirror? {
        fatalError("not implemented")
    }
    /// Each view matched to exactly one element by frame within 0.5 pt, else nil. Pure, so tests drive the fallback.
    static func match(elements: [CGRect], views: [CGRect]) -> [Int]? { fatalError("not implemented") }
    /// Every matched layer still in the container's tree, at its view's frame.
    var isLive: Bool { fatalError("not implemented") }
    func layer(for element: LiquidElement) -> CALayer { fatalError("not implemented") }
}

class OverlayPanel: NSPanel {
    init(content: NSView) { fatalError("not implemented") }   // the window config, present, the fade and generation as today
}
/// Today's `.regular` glass in `roundedClip`, now the window switcher's own choice.
func roundedGlass(_ content: NSView, cornerRadius: CGFloat) -> NSView { fatalError("not implemented") }
```

**LauncherPlatform and the app target.**

- `LaunchTuning` gains `var liquid = LiquidLook.shipped`, nested as `bounce` is, with a "Liquid switcher" tuner section. Its hand-written `init(from:)` gets the matching line (`how.md` gotcha 11).
- `public enum LiquidTuning { public static var current: LiquidLook }` returns the tuner's override in DEBUG and `.shipped` in Release.
- `SettingsShell.init` gains `liquidLook: @escaping () -> LiquidLook = { .shipped }` and passes it to `SwitcherPresenter`.

**The seam tests run at: `Liquid`, driven through `World`.** `World.liquidSwipe(...)` plays a `TouchScript` frame by frame. After each frame it feeds `launcher.switcher?.selection` to a `Liquid`, at `LiquidTime(frame.time.seconds)`. It returns every frame staged and the final `Liquid`. The test handles:

- **Time:** frame times are the liquid's clock. `shape(at:)` evaluates any instant from the last non-empty frame on, and what played earlier is rebuilt from the staged frames (Testing Decisions).
- **Finger speed:** `slide(byMM:over:)` sets it.
- **Reduce Motion and a missing mirror:** `motion: .still`, which is exactly what the panel selects in both cases. `GlassMirror.match` returning nil is tested in `LauncherUITests`.

**Docs this needs.** No rule changes.

- `docs/architecture.md`: the per-input-event example names the app switcher's liquid, and the private-symbol list names the mirrored glass elements with their fallback.
- `docs/domain-model.md`: the Switcher entry's look.
- `docs/performance.md`: a "fingers resting on an open switcher" phase, and the measurements, once built.

### Synthesis decision

- **Base: candidate 1.** It scored ahead on all six rubric criteria in my reading, and in the cross-judge's (26 to 18). The cross-judge found no claim in it contradicted by a probe, a check or the code. The two agreed on the base, for the same reasons:
  - all motion policy, including the shape at any instant and every requirement bound, sits in one pure, deep module (`Liquid`);
  - retargeting starts from each curve's own position and velocity, so there is no kink at a crossing;
  - crests begin on the first movement (R8, R11);
  - the shared port type and the recognizer stay untouched.
- **Strong convergence.** Both candidates independently chose:
  - band, beads and swell in one container, with the band as the neck;
  - render-server additive animation on the private mirror, with the Reduce Motion look as the fallback and no rule change;
  - `LiquidLook` in Core, with `swellRise` as the one swell setting, injected from the app target and tuned through `LaunchTuning.liquid`;
  - `OverlayPanel` taking its content from the subclass;
  - the same reading of R4 (beyond the beads), which the user then confirmed, and a held pull past an end, which the user then replaced with a spring-back while the fingers rest.
- **Grafted from candidate 2, and amended by the checks:**
  - **A fixed set of twelve glass views** that is never added to, removed or hidden. That replaces candidate 1's pooled beads, which K4 and K5 show rebuild the mirror lazily.
  - **A mirror that never latches off.** Candidate 2's retry on every open replaces candidate 1's latching `playsMotion`. A failed liveness check costs that one swipe its motion and re-runs the pre-warm.
  - **`emptied()` cleanup** after the fade.
- **My amendments to both, from the checks:**
  - Spares lie over the band, not outside the window (K2) and not over the last bead: static coincident spares would mask that bead's wave troughs.
  - The match happens at a pre-warm with distinct frames (K1, K3), because a match under coincident spares would be ambiguous.
  - Sampling is at 120 Hz rather than 240 Hz (K10).
  - The icon's grow time is tied to the flow's lead arrival.
  - The swell's thinning is clamped so the grown icon stays inside (R4).
  - The Core Animation key string moved out of Core, which was the cross-judge's information-leakage note.
  - `Codable` is DEBUG-only, per the precedent.
- **Rejected from candidate 2, with reasons:**
  - `CASpringAnimation` kicks with from equal to to. These are probably inert: the spring interpolates its from-to fraction, so the R8 wave and the squash would not move.
  - Finger speed on `SwipePhase.moved`. It threads a field through a type shared with the window swipe. It stays the named remedy if clock-measured speed jitters on hardware.
  - Waves only at selection changes. Those miss R11's opening wave and R8's "finger movement".
  - `LiquidGeometry` as a separate type. It would be a pass-through over `SwitcherRowLayout`.
  - Its `OverlayPanel` convenience-init delegation, which is invalid for `WindowSwitcherPanel`'s `super.init`.
- **Candidate 1's P7 probe was run as a check before synthesis:**
  - (a) holds cost nothing (K11);
  - (b) a frame set and tracks share a commit (K9);
  - (c) per-event cost is measured (K10);
  - (d) is answered by K5 and made moot by the fixed set;
  - (e), the shadow during fast motion, stays a hand check.
- **No dropout:** both runners delivered.

### Tradeoffs accepted

- **The private mirror.** We accept the first reach into another framework's private layer tree in exchange for render-server motion at about a fiftieth of the public paths' CPU, with no rule change. The reach is confined to one file and only reads the tree and adds public animations. When it fails, the swipe shows the tested R13 look.
- **Twelve glass views always alive**, spares lying over the band, in exchange for a mirror whose identity never churns.
- **One public frame set on the swell per selection change**, a few per second, in exchange for views that always hold the correct resting shape when the mirror is gone.
- **Sampled keyframes** (about 7% of a core at 240 Hz, about half that at 120 Hz) instead of Core Animation's springs (about 2.5%). In exchange, the curves can be bounded, windowed, continued from the current velocity, and tested exactly.
- **Main-queue jitter in the measured finger speed**, in exchange for no new signal through the recognizer, the port or the model.
- **Crests only every half icon of travel**, in exchange for per-event work of three tracks. A sub-half-step creep makes one crest.
- **`Liquid` (visual policy) in LauncherCore**, as `SwitcherRowLayout` already is, in exchange for testing it through `World`.
- **Reduce Motion read once per swipe.**
- **The wave's cap is its own setting, `waveMax`**, independent of `swellRise` (the user's choice). A subtle swell keeps the full wave, so beads can rise past a subtle swell's height. R8's bound now names the wave's maximum, not the swell.
- **A fixed `room` around the beads**, sized for the shipped swell, R10's pull and the wave's cap, in exchange for a scale that a subtler swell cannot change (R17). A swell or a wave cap raised beyond what `room` holds is clamped.
- **The end pull re-pulls on every move and springs back `pullHold` (60 ms) after the last one** (the user's choice: spring back while resting, as today's rubber band does). It relies on `SwitcherSelection`'s `==` seeing every move, even against the clamp. If that equality ever ignored the reported travel, a push held against the clamp would spring back while the fingers still push.
- **A zero-opacity pre-warm at panel creation**, including at a login start, where no window may show. It is invisible (K12) and is the precedent of `LaunchOverlay`'s first-window warm-up.
- **`SwitcherSelection.stretch` and `switcherMaxStretch` now serve only the window switcher.** That is not dead code.
- **`CACurrentMediaTime` and `beginTime` are new to the codebase**, read once per input event, on Core Animation's own clock.

### Alternatives considered

- **Public in-process animation** (`animator()`, implicit animation, SwiftUI `GlassEffectContainer` with `withAnimation`). It hides the private mirror from callers, but runs per display frame in our process at 30 to 100 times the CPU (A4), needs the animation rule rewritten, and plan 006 rejected SwiftUI here. Lost.
- **One masked glass view with an animated `CAShapeLayer` path.** It is public and runs on the render server, but it renders as flat frosted glass (A8), which fails R2. Lost.
- **Direct writes to the element layers per event, with springs on top.** It is the cheapest per event (A7), but AppKit's re-sync resets those writes whenever a view changes or a layout runs (A6). Lost on robustness.
- **Stacked additive `CASpringAnimation`s per kick.** Fewer values per commit, but the springs pile up without bound, the 200 ms arrival depends on the state, a sum of springs cannot be saturated (so R8's and R9's bounds are unenforceable), and tests could observe it only by mirroring Core Animation's spring formula. Lost.
- **The swell as beads that grow, with no swell element.** Nothing travels between icons, so it reads as two bulges cross-fading. Lost.

### Open questions and risks

**Answered by the user (2026-11-03):**

1. **R4:** 12 pt beyond the beads (a 104 pt swell). R4 now says so.
2. **R10:** the pull springs back around the end icon when the fingers stop moving or turn back. It does not hold. R10 now says so and gains a "Rest past the last app" scenario.
3. **R8 and R17:** the wave's maximum is its own setting, `waveMax`, and a subtle swell must not lower it. R8's bound now names the wave's maximum.
4. **The private mirror:** accepted, confined to one file with the Reduce Motion fallback, with the `docs/architecture.md` wording. S3 is unblocked.
5. **R2 over white:** fine as is. A tint stays a non-goal unless it fails the hand check.
6. **The DEBUG tuner (S6):** kept.

**Still open: risks for hand checks on hardware**

1. **Risks for hand checks on hardware:**
   - whether the shadow keeps up during a fast flow (A9);
   - whether wave-size jitter from clock-measured speed is visible (remedy: driver frame times on the event);
   - `iconBody` against real icons;
   - smoothness at 120 Hz with ten apps (R15);
   - zero frames drawn at rest (R16).
   - R2 light over white, which leans on the window shadow (A10);
   - whether `pullHold` (60 ms) keeps a slow push past an end looking pulled rather than pulsing.
2. **The numbers in `LiquidLook` are starting points from the probes,** to be settled by feel in the tuner, as plans 004 and 017 were.

### Next implementation step

Give `OverlayPanel` an `init(content:)` with today's rounded glass as `roundedGlass(_:cornerRadius:)` for both switchers (S1), then build `LiquidLook`, the extended `SwitcherRowLayout` and `Liquid`'s opening and `.still` test-first through `World.liquidSwipe` (S2).

## Testing Decisions

### Strategy

**Seam 1, where most rows run: `Liquid` driven through `World`, in LauncherCoreTests.** This is the design's seam. The real recognizer and the real `Launcher` sit in front of the liquid, so a row proves what the switcher stages for a hand on the trackpad. `World.liquidSwipe` is the design's helper, given the parameters the rows need:

- It builds a switcher world with the row's apps, a display width, a `LiquidLook` and a `LiquidMotion`. For the one-icon row it uses no frontmost app and one running app.
- It plays the hand in one of two ways:
  - as a `TouchScript` continuation after `World.swipe`'s 3.5 mm begin slide, for finger speed, flicks and lifts;
  - as `.moved(travelMM:)` values injected through `hardware.inject` at given milliseconds after an injected `.began`. This gives exact travel at boundary values (5.9, 6.0 and 12.0 mm, 3 mm past an end), which the begin slide's leftover travel (about 0.35 mm) would blur.
- After every frame it feeds `launcher.switcher?.selection` to one `Liquid` per switcher, at `LiquidTime` equal to the frame's time. It keeps feeding the unchanged selection on every frame while the fingers rest. The test owns the liquid's clock; nothing reads a wall clock.
- Every value passes through a delivery stage. The stage can withhold values (as `Observations` coalescing does), feed a value twice, delay a value's time by a seeded 0 to 4 ms (main-queue jitter), or stamp two values 0.5 ms apart (to hit D4's 8 ms floor).
- It records every call: its time, the selection fed, the `LiquidFrame`, and a copy of the `Liquid` after it.

**What the rows read.** `run.played(at:)` rebuilds what the render server shows from the staged frames alone. It follows Core Animation's rules, not `Liquid`'s formulas:

- per channel, it takes the latest track added at or before the instant;
- it interpolates linearly between that track's samples;
- after the track ends, it holds the last offset if the track holds, and is 0 otherwise;
- it adds the result to the element's rest: the swell's last staged rest, the layout's bead, or the band, which never moves.

The selected icon's scale comes from the last `IconChange`, taken as linear over its duration.

Every motion row samples `played(at:)` every 1 ms over the whole history, from the open to 2 s after the last call. No row reads `shape(at:)` on its own: it evaluates the same closed form the sampler samples, so a row on it stays green when the tracks are wrong. T34 ties `shape(at:)` to the played shape instead.

Terms the rows use:

- An icon's **body** is an `iconBody × scale` square. The selected icon's body is `selectedIconBody`, and an icon changing size moves between the two linearly over the `IconChange`'s duration. "Inside" is checked by rects; the rounded corners are a hand check.
- The **far edge** is the swell edge on the side the selection or the fingers last moved toward.
- **Where it settles** is the played shape 2 s after the last call, built from the frames staged so far.

**Rows resemble these existing tests:**

- `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift` and `World.playFrameByFrame` (a hand in, model effects out);
- `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` (staged Core Animation read back);
- `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`.

`LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift` is retired. Every row in it asserts today's highlight, gap and 22 pt padding, which the design removes. T1 to T3, T6 and T7 prove the new geometry through the run.

**Seam 2: the new `LauncherUITests` target**, which the design adds.

- **Pure staging**, read back as LaunchFlightTests does: `LiquidKeyframes` and `GlassMirror.match`.
- **A suite on the real `SwitcherPanel` and the real WindowServer.** The private mirror exists only there (grounding `index.md`).
  - The suite is serialized and main-actor. It runs only in a logged-in GUI session: `swift test` in Terminal on the developer's Mac. There is no CI.
  - Slice S3's acceptance requires that it ran, not that it was skipped.
  - It reads AppKit's mirror the way the probes did: it walks the container's layer tree by class name and frame, independently of `GlassMirror`.
  - It injects the platform's mirror rebuild by hiding and showing one of the panel's bead views, the trigger K4 used. The design keeps those views internal for `@testable` tests.
  - It observes whether `emptied()` re-ran the pre-warm from the glass views' frames: a pre-warm leaves them at its ten-icon template, and a plain cleanup leaves them as the swipe laid them out.
  - It forces the fade and re-open interleaving by presenting again while the fade animation is still on the layer.

**Seam 3: the existing `TunerCodingTests`**, for `LaunchTuning.liquid`.

**What is faked, and what is real:**

- Faked:
  - the clock: frame times stand in for it;
  - Reduce Motion and a missing mirror: both are `motion: .still`, exactly what the panel selects;
  - the main-queue hop and `Observations`: the delivery stage stands in for them.
- Real: the recognizer, `Launcher`, `Liquid`, `LiquidKeyframes`, `GlassMirror`, the panel, AppKit and the WindowServer.

**What the seams miss:**

- pixels, the SDF merge's fillets, the glass look and the window shadow;
- frame pacing and render-server cost;
- the presenter's thin wiring: Reduce Motion and `checkMirror()` to `.still`, `follow`, `apply`, `dismiss`.

Those are under Verified without a test. `SourcePolicyTests` keeps banning timers and display links, and gains `CASDFElementLayer` confined to `GlassMirror.swift`.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R3, R4 | Liquid via World | **Given** five apps, Safari frontmost, a 1512 pt display. **When** the swipe begins and the fingers rest 1 s. **Then** the first call returns the swell at `swell(at: 0)`, icon 0 at once (duration 0) and no tracks. At every instant the played shape is: a band 52 pt tall spanning the first icon's centre to the last's; five beads, 80 pt square with corner 25.6, on the icons' centres; a 104 pt swell on icon 0, corner 33.3. Every bead and the swell overlap the band. Between icons 2 and 3 the shape is 80 pt tall at each centre and 52 pt at the midpoint: a neck, not a gap. The swell ends 8 pt short of bead 1. Icon 0's grown body (71.7 pt) is inside the swell, and every other body is inside its bead. | P5's look as the design records it: icon 80, pitch 100, bead 80 with corner 0.32, band 52 (`p5-light-white.png`). R4's 12 pt beyond the beads on each side, and R4's 1.12×. R3's "narrower but unbroken". |
| T2 | R1 | Liquid via World | **Given** a row of one app (no app active, one running: the only one-icon row the model makes), a row of two and a row of ten. **When** each swipe begins. **Then** every spare bead (index n to 9) is exactly the band. With one app, the band and every spare are exactly bead 0, and the played shape is the swell alone: every other rect lies inside it. With ten apps there is no spare. | R1's one-app scenario: no app in front, one other app running. D1's spare rule. `withNoActiveAppOneRunningAppIsEnoughToSwitchTo`, for how a one-icon row arises. |
| T3 | R14 | Liquid via World | **Given** ten apps. **When** the swipe begins on a 1024 pt display, and on 1060 and 1059 pt. **Then** on 1024 pt one factor f < 1 scales everything from T1's values: icon, bead, band thickness, swell, pitch, every radius and the container's spacing. The panel is at most 1024 pt wide, and every icon body is inside its bead or the swell. On 1060 pt f is 1; on 1059 pt f < 1. | R14 ("shrink by the same factor", "still fits"). T1's values. The 1060 pt is worked from the layout's denominator, (n − 1) × 100 + `beadSide` + 2 × `room`: 900 + 80 + 80 pt. |
| T4 | R13, R16 | Liquid via World, `.still` | **Given** Reduce Motion (`motion: .still`) and five apps. **When** the fingers slide right 7 mm past the begin, then rest 2 s. **Then** exactly two calls return a non-empty frame: the opening, and the call where `selected` became 1, which carries `swell(at: 1)`, icon 1 at once and no tracks. No frame carries a track. The played swell is `swell(at: 0)` at every instant before that call and `swell(at: 1)` from it on, with nothing between. Every bead is at rest throughout. | R13's step scenario. D3: no commit per event under `.still`. |
| T5 | R13, R7 | Liquid via World, `.still` | **Given** `.still` and five apps. **When** the fingers reach the last app and push 5 mm past it; and, in a second swipe, flick 36 mm in one 10 ms frame. **Then** the push returns only empty frames and the swell stays at `swell(at: 4)`. The flick stages `swell(at: 3)` once and never names icon 1 or 2. | R13's push scenario. R7. |
| T6 | R17, R14 | Liquid via World | **Given** the shipped look, and a look that changes only `swellRise`, to 3. **When** each swipe begins with five apps on 1512 pt, and with ten apps on 1024 pt, where the row shrinks. **Then** the subtle swell is 3 pt beyond the bead on each side, 86 pt at full size. In both cases these equal the shipped look's: the scale, the panel's size, the band, every bead, every other radius, the pitch, every icon's place on the display (its centre minus half the panel's width), and `beadLimits` (the wave's cap). | R17's scenario ("a few points", "nothing else changes"). `LiquidLook`'s "3 is subtle". The design's `room`: the scale never depends on the swell's size. The user's answer: a subtle swell must not lower the wave's cap. |
| T7 | R17 | Liquid via World | **Given**, one at a time, `beadSide`, `beadCorner`, `bandThickness`, `spacing`, `swellRise` and `swellCorner`, each raised by a quarter, with five apps on 1512 pt. **When** the swipe begins. **Then** the output that knob names changes by its documented rule: bead side, bead radius, band height, container spacing, swell side, swell radius. The icons, the pitch and the band's span stay as shipped. | R17 ("each adjustable in one place"). |
| T8 | R6, R4 | Liquid via World, injected travel | **Given** five apps. **When** travel ramps from 0 to 12.0 mm in ten 10 ms events, reaching exactly 6.0 mm at the fifth, then rests 2 s. **Then** the call at 6.0 mm returns `swell(at: 1)`, icon 1 with 0 < duration ≤ 0.2 s, and swell tracks. No played edge moves more than 0.5 pt across that instant, so the offsets were computed against the new rest (K9). 100 ms later the right edge is strictly between the right edges of `swell(at: 0)` and `swell(at: 1)`: it flows, it does not jump. From 200 ms after the change, both edges are within `wobble` (4 pt) of `swell(at: 1)`'s, and the right edge crosses its rest at least twice (a wobble). From 1 s after the last event the played swell is exactly `swell(at: 1)` and does not overlap bead 0. | R6: 200 ms, a small wobble, the first icon left in a bead. `LiquidLook.wobble` as the bound of "small". T1's geometry. |
| T9 | R6 | Liquid via World, injected travel | **Given** five apps. **When** travel jumps to 12.0 mm in one event and, 50 ms later, to 24.0 mm. Before the second jump the row checks that the played right edge is mid-flow, at least 10 pt from both rests. **Then** the second call returns `swell(at: 2)` and replaces all three swell channels. No played edge jumps more than 0.5 pt at that instant. The right edge moves only rightwards until it first reaches `swell(at: 2)`'s right edge. Both edges are within `wobble` of `swell(at: 2)` by 200 ms after the second change. A flow queued behind the first would arrive about 310 ms after the second change. | R6 ("retarget … rather than queue", 200 ms). D5: every curve restarts from its current position and velocity. |
| T10 | R6 | Liquid via World | **Given** five apps. **When** the fingers slide right 48 mm in 600 ms, so the selection changes about every 150 ms, then rest. **Then** the staged swell rests are `swell(at: 1)` to `swell(at: 4)`, in order, each in the call where that selection first appeared. At every instant the played swell's centre is less than one pitch behind the selected icon's. Within 200 ms of the last change, the far edge is within `wobble` of where it settles, and the settled swell holds icon 4's grown body. A queue of 180 ms flows would still be moving 270 ms after the last change. | R6's steady-slide scenario. |
| T11 | R7 | Liquid via World | **Given** five apps with the first selected. **When** the fingers move 36 mm in one 10 ms frame; again over 30 ms (three frames); and over 30 ms with the middle two values withheld. **Then** in the one-frame flick and the withheld one, exactly one call after the opening stages a swell rest, `swell(at: 3)`, with icon 3, and no call names icon 1 or 2. In all three, from 200 ms after the last change, the swell holds icon 3's grown body, and beads 0 to 2 are at rest and outside it. | R7's flick scenario. `oneFrameCrossingThreeIconsTicksThreeTimes`: the same frame crosses three icons in the model. |
| T12 | R6, R7 | Liquid via World, delivery stage | **Given** T10's slide and T11's 30 ms flick. **When** the values reach the liquid (a) every frame, (b) only every third value, (c) a seeded random half of the values, (d) every value twice. **Then** every staged rest is the selection fed in that call. The settled played shape equals (a)'s to 1e-9 pt. In (d) every repeat returns an empty frame, and the played history equals (a)'s exactly. The 200 ms reach holds after the last change fed. | The design's constraint that `Observations` may coalesce, so every value is an absolute target. (a) is the reference. |
| T13 | R9, R16 | Liquid via World, injected travel | **Given** five apps. **When** travel ramps to 24.0 mm (the third app) over 200 ms, and the unchanged selection is then fed every 10 ms for 2 s. **Then** every one of those calls returns an empty frame, and every track ends at most 1 s after its call. Before settling, the far edge crosses its rest at least twice. From 1.000 s after the last moving event to the end, the played shape is identical at every 1 ms sample, with the swell exactly at `swell(at: 2)`. | R9 (settles within one second; does not move again until the fingers move). R16's two seconds. |
| T14 | R6, R9 | Liquid via World, injected travel | **Given** a look with `flowTime` 0.5, and a look with `wobbleDamping` 0. **When** T8's travel plays. **Then** the swell still reaches `swell(at: 1)` within 200 ms of the change, and is still from 1 s after the last event. | R6's 200 ms and R9's one second. D7: the bounds are `Liquid`'s, not the look's. |
| T15 | R11 | Liquid via World | **Given** five apps, and a swipe that flicks to the fourth app and lifts on the next frame, while the played right edge is still more than 10 pt short of `swell(at: 3)`'s. **When** a second swipe begins 50 ms later. **Then** its first call returns `swell(at: 0)`, icon 0 at once and no tracks, and its played shape at that instant is T1's. | R11 ("already settled", "nothing grows or pours in"). D5: no motion carries over. |
| T16 | R12 | Liquid via World | **Given** five apps, and the fingers flicking to the fourth app (Notes). **When** they lift on the next frame, while the played swell is still mid-flow (more than 10 pt short of `swell(at: 3)`). **Then**, right after the lift frame is delivered, Notes is brought to front with the gesture haptic, and `launcher.switcher` is nil. | R12's lift-during-a-flow scenario. The lift rows of `SwitcherOnScreenTests.swift`. |
| T17 | R15 | Liquid via World | **Given** T10's slide. **When** it plays. **Then** every track's step is at most 1/120 s, and every track has at least two samples. Each non-empty frame's swell tracks last until the next non-empty frame, or hold their last offset. So the render server always has a track in flight between input events. | R15's 120 Hz. D3. |
| T18 | R5, R6, R10, R16 | `LiquidKeyframes` | **Given** tracks on each channel (the swell's centre, width and height; a bead's height), some holding and some not. **When** `animation(_:beginTime: 5)` and `key(_:)` stage them. **Then** each is a `CAKeyframeAnimation` on `position.x`, `bounds.size.width` or `bounds.size.height`. It is additive, with linear calculation, values equal to the offsets, duration step × (count − 1) and begin time 5. A holding track is filled forwards and not removed on completion; any other is removed on completion. The keys of the swell's three channels and of every bead's channels are distinct and share the `liquid.` prefix. | The key paths and additive keyframes that moved the merged glass in probes P3 and P6 and check C5 (K10, K11). Core Animation's keyframe timing. `LaunchFlightTests.swift`. |
| T19 | R13 | `GlassMirror.match` | **Given** twelve distinct view frames. **When** they are matched against: the same frames shuffled; one element 0.4 pt off; one element 0.6 pt off; two elements within 0.5 pt of one view; eleven elements; one element that matches no view. **Then** the first two return the permutation, and the rest return nil. So the panel never plays motion on an ambiguous or partial mirror, and that swipe gets R13's look. | The design's match rule: each view matches exactly one element within 0.5 pt. A6: frame matching, 21 of 21 in P6. |
| T20 | R6, R11, R16 | `SwitcherPanel`, real window | **Given** a `SwitcherPanel()`, after its pre-warm at zero opacity, laid out for five icons, presented, with `checkMirror()` called. **When**: a real `Liquid(.flowing)` steps to icon 1 and its frame is applied; the panel is laid out again for four icons, a flowing frame is applied before `checkMirror()`, then `checkMirror()` is called; `emptied()` runs; and a third swipe is laid out and presented without calling `checkMirror()` (Reduce Motion's path), then `emptied()` runs. **Then**: `checkMirror()` returns true each time, including right after the switch from five icons to four. Right after `apply`, the element layer at the swell view's frame has the model frame `swell(at: 1)` and carries the three swell tracks, and no other element carries any. The frame applied before the second `checkMirror()` staged no track. After the second `checkMirror()` the same twelve element objects are matched, and none carries a `liquid.` animation. After each `emptied()` no element carries a `liquid.` animation, the swell view is at its rest, and every glass view keeps that swipe's layout: no pre-warm ran. | K1, K3, K9 and K12 as probed. The test's own walk of the container's layer tree by class name and frame, which is how the probes found the elements (A6). D2 (liveness once per swipe; the pre-warm re-runs only when the mirror is not live). |
| T21 | R6, R13 | `SwitcherPanel`, real window | **Given** T20's presented panel, after `checkMirror()`. **When** one bead view is hidden and shown again (by K4, AppKit then rebuilds its element as a new object), and the test waits up to 2 s for twelve elements; the next swipe is laid out, presented and checked; `emptied()` runs; and a swipe after that is laid out, presented and checked. **Then** for the first swipe `checkMirror()` returns false, and applying a flowing frame moves the swell view but adds no animation to any element. After `emptied()` the glass views hold the pre-warm's ten distinct frames, because it re-ran. For the last swipe `checkMirror()` returns true. | K4. D2 ("motion never latches off"). |
| T22 | R11 | `SwitcherPanel`, real window | **Given** a presented, checked panel with tracks applied. **When** it is dismissed and then, while its fade animation is still on the content layer, laid out, presented and checked again, tracks are applied, and the main run loop then runs for 0.4 s. **Then** the window is still on screen, `checkMirror()` returned true, and the newest tracks are still on the swell's element. The stale fade's completion neither ordered the window out nor ran `emptied()`. | `OverlayPanel`'s generation guard (C6). D5: re-open during the fade. |
| T23 | R5, R9 | Liquid via World, injected travel | **Given** five apps with the first selected. **When** travel ramps to 1, 2, 3, 4, 5 and 5.9 mm (one run each, 10 ms per mm) and rests 2 s; and, separately, reaches 5 mm in one 10 ms event and stops dead. **Then** no call after the opening stages a swell rest or an icon. At every instant, the played swell's left edge is `swell(at: 0)`'s to 1e-6 pt. The settled right edge is at least 10 pt beyond `swell(at: 0)`'s at 5 mm, strictly farther at each larger travel, and still left of icon 1's centre. The swell's height stays between `selectedIconBody` + 4 pt (75.7 pt) and its rest height, here 104 pt, and also with a look whose `swellRise` is 3, where the rest height is 86 pt. After the dead stop, the right edge overshoots where it settles by at most `wobble`. | R5's scenario ("left edge and the enlarged icon stay put", "visibly reaches toward the second", grows with the distance). 10 pt, a tenth of a pitch, as "visibly". R4 (the icon stays inside, even in a subtle swell) and the design's height clamp. R9's "small wobble", bounded by the design's "Every tail is bounded". |
| T24 | R5 | Liquid via World, injected travel | **Given** five apps. **When** travel ramps to 5 mm over 50 ms, back to 0 over 50 ms, and rests 2 s. **Then** the left edge never moves. The right edge comes back to `swell(at: 0)`'s, and never passes inside it by more than `wobble`. From 1 s after the last event the played shape is exactly T1's. | R5's slide-back scenario. |
| T25 | R10, R9, R16 | Liquid via World, injected travel | **Given** five apps with the last selected and the liquid settled. **When** (a) travel pushes 3 mm past the end over 30 ms, keeps pushing 9 mm more over 90 ms (which the model clamps), then rests 2 s past the end; (b) pushes 3 mm past the end over 30 ms, then turns back 2 mm in one event and rests 2 s; and (a) again past the first app, to the left. **Then**: during each push only the outer edge moves, and the inner edge, the band and every bead stay as settled at every instant, with no bead track staged. The pull at the end of the 3 mm push is at least 10 pt. The pull never exceeds 20 pt at any instant, wobble included. While the push continues against the clamp, every call returns a non-empty frame and the outer edge stays within `wobble` of the 3 mm pull: it does not spring back while the fingers move. In (a), once the fingers rest, the outer edge springs back to the end icon's swell rest within `pullHold` plus 1 s, crossing that rest at least twice within `wobble`, and is still from 1 s after the last move on. No pull track ends on a non-zero offset. In (b) the same spring-back happens from the turn. The peak pull for pushes of 0.5, 1, 2 and 3 mm strictly increases. | R10: 20 pt, a fifth of 100 pt, "most of it within 3 mm", band and beads still, and a spring-back with a wobble when the fingers stop moving or turn back (its push and rest scenarios). R9's one second. C3: the model clamps at 3 step-mm and forgets the overshoot on the turn. The design's `pullHold`, its cap on the outer edge's whole curve, and `SwitcherSelection`'s `==` seeing a push against the clamp. |
| T26 | R10, R14 | Liquid via World, injected travel | **Given** ten apps on 1024 pt (f < 1); five apps on 1512 pt with a look whose `endPull` is 50; and five apps on 1512 pt with a look whose `swellRise` is 30. **When** travel reaches 3 mm past the last app in one event. **Then** the pull never exceeds 0.2 × pitch at any instant: f × 20 pt on the narrow display, 20 pt on the wide one. With the raised rise, the drawn rise is clamped, and the pulled swell stays inside the panel at every instant. | R10's "a fifth of the distance between two icon centres". D7. The design's `room`: the rise is clamped so the pulled swell always fits. |
| T27 | R12 | Liquid via World | **Given** five apps, with the frontmost app first. **When** the fingers slide 5 mm and lift, while the played right edge is stretched at least 10 pt. **Then**, after the lift frame, nothing is brought to front, no haptic plays, and `launcher.switcher` is nil. | R12's lift-during-a-stretch scenario. |
| T28 | R15 | Liquid via World | **Given** ten apps. **When** the fingers slide 30 mm right and back, 300 ms each way, four times, then rest. **Then**, for every event, in the played history of the frames up to that event alone, the swell's leading edge is within `wobble` of where it would settle, one 60 Hz frame (1/60 s) after the event. | R15 ("never trails visibly behind the fingers"), read as one 60 Hz frame: the design's `followTime`. |
| T29 | R8 | Liquid via World, delivery stage | **Given** two five-app swipes that each move the selection by one app. **When** one slides 7 mm in 60 ms and the other in 600 ms; again with each value's time delayed by a seeded 0 to 4 ms; and again with only every third value fed. **Then** in each variant, bead 2's peak ripple (its largest height change from rest) in the quick swipe is more than 1.5 times the slow one's. The every-third peak is within 20% of the every-value peak. | R8's scenario ("visibly bigger"), read as 1.5 times, the design's own threshold at call site 3. D4: coalescing keeps the average speed. |
| T30 | R8 | Liquid via World | **Given** ten apps with the first selected; and ten with the last selected. **When** the fingers slide 5 mm in 50 ms (right in the first case, left in the second) and rest. **Then** the peak ripple falls from bead 1 to bead 5 to bead 9 (from 8 to 4 to 0 in the second case). Each bead's onset, the first instant it reaches a tenth of its own peak, comes later the farther the bead is from the swell. | R8 ("biggest near the swell and weakens with distance", "in the direction of the slide") and its far-icons scenario. |
| T31 | R8, R14 | Liquid via World, delivery stage | **Given** ten apps on 1512 and on 1024 pt; the shipped look, and a look with `waveHeight` 1000 and `waveFullSpeed` 0.01. **When** the fingers flick across the whole row and past it in one 10 ms frame, back the same way, five times, then rest; and again with two values stamped 0.5 ms apart. **Then**, at every 1 ms sample: every value is finite; every bead and the swell overlap the band; no bead is thinner than the band; no bead is taller than its rest plus 2 × `waveMax` (12 pt each side at full size, scaled), the same with the shipped swell and with a look whose `swellRise` is 3; every icon body is inside its bead or the swell; every rect is inside the panel; no track is on a spare; and beads carry only height tracks. | R8 ("never break the band, move an icon out of its bead or swell, or raise a bead beyond the wave's own maximum", which does not follow the swell's size). `waveMax`. `iconBody` 64 pt, checked by hand against real icons. D4's 8 ms floor. |
| T32 | R11, R8 | Liquid via World | **Given** five apps. **When** the fingers slide 5 mm in 50 ms after the begin. **Then** the call for the first `.moved` event stages a height track for every real bead, beginning at that call's time, though the selection has not changed. | R11 ("any wave from the opening movement MUST begin at once"). R8 ("finger movement MUST send a wave"). |
| T33 | R15, R16 | Liquid via World | **Given** ten apps. **When** the fingers slide back and forth across the row for 3 s. **Then** no frame holds more than one track per channel, or more than three swell tracks. Bead tracks appear only in calls where the position has moved at least half an icon since the last crest, or on the first move. No track runs longer than 1 s. | D3's per-event budget. K10: about 7% of a core at 240 Hz, about half that at 120 Hz. |
| T34 | R6, R8, R9, R10, R12, R16 | Liquid via World, delivery stage | **Given** 200 seeded hands: 2 to 10 apps; displays of 1512, 1024 and 800 pt; 1 to 8 slides of −60 to +60 mm, each over 10 to 600 ms, with rests of 0 to 500 ms; random withholding, repeats and jitter; a lift on a random frame. **When** each hand plays. **Then**: T31's bounds hold at every sample; the pull never passes 0.2 × pitch; every staged rest is the selection fed in that call; when no value follows a change for 200 ms, the far edge is within `wobble` of where it settles by then; every track ends within 1 s of its call; every call with an unchanged selection is empty; the shape is constant from 1 s after the last non-empty frame. At every sample instant of every track before it is replaced, `shape(at:)` of the latest copy equals the played shape to 1e-6 pt. The lift brings the app selected at that moment to front, or nothing when it is the frontmost. | The requirement literals above. The played shape. |
| T35 | R17 | Liquid via World | **Given**, one at a time, `wobble`, `wobbleHz`, `wobbleDamping`, `waveHeight`, `waveReach` and `waveMax`, each raised by half. **When** T8's step and T30's slide play. **Then** the output each knob names changes: the wobble's largest overshoot, its period and its decay; bead 1's peak ripple; bead 9's peak as a share of bead 1's; the top of `beadLimits`, and bead 1's largest height in T31's hardest flick. The swell's rests and the band stay as shipped. | R17 ("the wave's strength and reach, and the wobble MUST each be adjustable in one place"). |
| T36 | R8 | `SwitcherPanel`, real window | **Given** T20's presented panel for five icons. **When** a crest frame from a real `Liquid(.flowing)` is applied. **Then** each of the five real beads' elements carries its height track, and no spare's element carries any. | D1 (spares never animate). The test's own walk of the layer tree, as in T20. |
| T37 | R17 | `TunerCodingTests` | **Given** the presets saved before the bounce existed (the suite's verbatim fixture); `{"liquid":{"swellRise":3}}`; and a tuning with every liquid knob changed. **When** each is decoded, or saved and loaded. **Then** the old presets decode with `liquid == .shipped`. The partial one decodes with `swellRise` 3 and every other liquid knob shipped. The full one survives unchanged. | `TunerCodingTests.swift`'s fixture. `how.md` gotcha 11: a field missing from the hand-written `init(from:)` silently decodes as its default. |

### Verified without a test

- **R1, R3 and R4 (the look):** on the developer's Mac with five apps running, swipe.
  - Expected: one glass shape with soft necks between the beads, and no rectangle around it.
  - A screenshot at the 2× backing scale shows the swell 208 px tall around the 1.12× icon.
  - The one-icon row arises only with no active app, so on hardware T2 alone covers it.
- **R2, dark:** dark appearance, a busy photo full screen under the switcher, swipe with five apps.
  - Expected: the shape reads as glass, with refraction at the rim, and every icon and the swell stay clearly visible. Compare `p5-dark-busy.png`.
- **R2, light:** light appearance over a maximised empty TextEdit document.
  - Expected: the band, each bead and the swell are each distinguishable from the window and from each other. Compare `p5-light-white.png`.
  - In a fast flick, the window shadow keeps up with the outline (A9).
  - If this fails, the tint goes back to the user.
- **R11:**
  - The shape appears at once, with the swell settled and nothing growing in.
  - Lifting fades it over about 150 ms; with Reduce Motion on, it goes at once.
  - The diff leaves `OverlayPanel.present` and `dismiss` unchanged apart from the initialiser (D8).
- **R12:** flick to the fourth app and lift at once. Expected: the app comes to the front with no wait while the switcher fades.
- **R13:** with Reduce Motion on:
  - a step makes the swell appear at once around the next icon, and nothing ripples;
  - pushing past the last app stretches nothing;
  - turning Reduce Motion on mid-swipe changes nothing until the next swipe.

  Read the presenter: it selects `.still` when Reduce Motion is on or `checkMirror()` returns false.
- **R14:** set the built-in display to a scaled resolution under 1060 pt wide (1024 wide), with ten apps running. Expected: the whole shape fits, centred on that display, with every icon in its bead or the swell.
- **R15:**
  - On the 120 Hz built-in display with ten apps, slide back and forth for 5 s. Expected, by eye: no stutter, and the swell never trails the fingers.
  - On the perf build, run `Scripts/perf/session.sh` phase 04. Expected: CPU per trackpad frame no higher than the 1.08 ms baseline (`docs/performance.md`, 2026-10-17). Enter it as a dated result.
- **R16:** on the perf build, add a session phase "fingers resting on an open switcher": open the switcher, then rest the fingers for 10 s. Expected:
  - after the first second, the app's CPU and wake-ups match the same fingers resting under the thumb with no switcher showing;
  - WindowServer CPU over 5 s matches the hidden switcher's, within K11's spread (0.47 to 0.49 s);
  - Quartz Debug's "Flash screen updates" shows no update over the settled switcher;
  - phase 08 (hands off) still has 0 idle wake-ups;
  - `SourcePolicyTests` stays green: no timer and no display link.
- **R17:**
  - In a DEBUG build, set "Swell rise" to 3 in the tuner's "Liquid switcher" section. Expected: the next swipe shows the subtle swell.
  - A grep of the switcher's LauncherUI files finds no numeric look literal other than 0, 1 and 2.
  - In Release, `LiquidTuning.current` is `.shipped`: check the `#if DEBUG` branches.
- **R6, R8 and R9 (the feel), on hardware:**
  - the flow lands in under 200 ms by eye;
  - the wobble is small;
  - the wave grows with finger speed and shows no jitter from the clock-measured speed (the design's still-open risks).

## Slices

### S1: Overlay panels take their content from the subclass

**What to build:** `OverlayPanel(content:)` keeps the window configuration, `present`, the 150 ms fade and the generation guard. Today's rounded glass becomes `roundedGlass(_:cornerRadius:)`. For now both switchers pass their content through it, so neither looks or behaves differently.

**Blocked by:** None (can start immediately).

**Requirements:** None. This is the prefactor that lets S2 meet R1.

**Test scenarios:** None.

**Skills:** macos-dev-workflow:axiom-macos

- [ ] The package builds and the existing suite stays green.
- [ ] By hand: the app switcher and the window switcher look, open and fade exactly as before.

### S2: One liquid shape that jumps between icons

**What to build:** the switcher shows as one Liquid Glass shape: a band, a bead around each icon, and a swell around the selected icon. A selection change moves the swell straight to the new icon. That is R13's look, and everyone sees it until S3, because the glass mirror does not exist yet.

- **LauncherCore:**
  - `LiquidLook`, with every knob at its shipped default;
  - `SwitcherRowLayout(iconCount:displayWidth:look:)`, with the band, the beads and spares, the swell and its clamped rise, `selectedIconBody`, the radii, the spacing, the scale and panel from the fixed `room`, and `beadLimits`;
  - `Liquid` with `init(layout:motion:)` and `follow(_:at:)`, for the opening and for `.still`;
  - the frame value types.
- **LauncherUI:**
  - `SwitcherPanel` rewritten: the container, the fixed twelve glass views, the icon layers above them, `lay(out:)`, `apply` for rests and the icon, and `emptied()`;
  - `checkMirror()` returns false, because no mirror exists yet;
  - `SwitcherPresenter` works as call site 1.
- **Tests:** `World.liquidSwipe` with its delivery stage, and the played model for rests and icons.

**Blocked by:** S1.

**Requirements:** R1, R2, R3, R4, R11 (the switcher opens at once, settled), R13, R14, R16 (the still part), R17 (the shape knobs and the subtle swell).

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7.

**Skills:** dev-workflow:tdd, macos-dev-workflow:swift-testing-pro, dev-workflow:codebase-design, macos-dev-workflow:axiom-macos

- [ ] T1 to T7 are green, `SwitcherRowLayoutTests` is retired, and the rest of the suite stays green.- [ ] These checks under Verified without a test pass: the look (R1, R3, R4), R2 dark and light, R11's instant open and fade, R13, and R14.
- [ ] `docs/domain-model.md`'s Switcher entry, rewritten with this plan to describe the band, the beads and the swell, matches what was built.

### S3: The swell flows on the render server

**What to build:** on a selection change, the swell flows to the new icon within 200 ms, ends with a small wobble and goes still within a second. A change during a running flow retargets it rather than queuing. Lifting never waits.

- **LauncherCore:** `.flowing`: `EdgeCurve` with its arrival velocity clamped so every tail stays within `wobble`, the flow and its retarget, the 0.2 s and 1 s bounds, the 120 Hz sampler and `LiquidTrack`s.
- **LauncherUI:**
  - `LiquidKeyframes`;
  - `GlassMirror`: the zero-opacity pre-warm, `match`, liveness and the layer lookup;
  - `checkMirror()` and the swipe's `liveMirror`, which `lay(out:)` clears;
  - `apply`'s tracks, staged only through `liveMirror`;
  - `emptied()`'s cleanup, and its re-run of the pre-warm only when the mirror is not live;
  - the presenter selects `.flowing` when Reduce Motion is off and `checkMirror()` returns true.
- **Tests:** the `LauncherUITests` target, with its real-window suite; the played model's tracks.

**Blocked by:** S2. (The user accepted the private mirror on 2026-11-03.)

**Requirements:** R6, R7, R9, R11 (no carry-over, re-open during the fade), R12 (lift mid-flow), R13 (the fallback look), R15 (120 Hz sampling), R16 (tracks end by themselves, and nothing is left after closing).

**Test scenarios:** T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22.

**Skills:** dev-workflow:tdd, macos-dev-workflow:swift-testing-pro, macos-dev-workflow:axiom-graphics, macos-dev-workflow:axiom-macos, macos-dev-workflow:swift-concurrency

- [ ] T8 to T22 are green, and T20 to T22 ran, not skipped, on the developer's Mac.
- [ ] `SourcePolicyTests` confines `CASDFElementLayer` to `GlassMirror.swift`, and its scanner rows still find planted hits.
- [ ] `docs/architecture.md`, updated with this plan (the per-input-event example names the app switcher's liquid; the private-symbol list names the mirrored glass elements and their fallback, the Reduce Motion look), matches what was built, as the user accepted.
- [ ] By hand:
  - R12's lift mid-flow;
  - R2's shadow keeps up during a fast flow;
  - the flow lands in under 200 ms by eye;
  - the first swipe after launch flows, which shows the pre-warm matched.

### S4: The swell stretches toward the fingers and pulls past the ends

**What to build:**

- Between selection changes, the swell's leading edge follows the fingers while its trailing edge stays pinned, and it springs back when they return.
- Past an end, only the outer edge pulls out, up to a fifth of a pitch, and springs back with a wobble when the fingers stop moving or turn back.
- Thinning keeps the swell's height between the grown icon's body plus 4 pt and its rest height.

This is LauncherCore only: the follow over `followTime` with its tail bounded by `wobble`, the lean, the end pull with its whole curve capped at 0.2 pitch, re-pulled by every new selection value and springing back `pullHold` after the last (never held), and thinning. The channels are the same, so the UI does not change.

**Blocked by:** S3.

**Requirements:** R5, R9 (a small wobble after a dead stop), R10, R12 (lift mid-stretch), R14 (the pull at scale), R15 (the swell keeps up with the fingers).

**Test scenarios:** T23, T24, T25, T26, T27, T28.

**Skills:** dev-workflow:tdd, macos-dev-workflow:swift-testing-pro

- [ ] T23 to T28 are green, and T1 to T22 stay green.
- [ ] By hand: the stretch toward the next icon and the end pull read as a drop being pulled. The pull springs back with a wobble when the fingers rest past the end, and when they turn back. A slow, steady push past the end stays pulled rather than pulsing (`pullHold`).

### S5: A finger-driven wave runs through the beads

**What to build:** finger movement sends a wave through the beads, from the first movement on. The wave is bigger for faster fingers and biggest near the swell, and it travels in the slide's direction. It is bounded, so the band never breaks and no icon leaves its bead.

- **LauncherCore:** `WaveTrain`, a crest every half icon, the speed estimate with its 8 ms floor, the tanh strength, saturation into `beadLimits`, and the bead tracks.
- **LauncherUI:** nothing beyond the bead channels `apply` already maps.

**Blocked by:** S4.

**Requirements:** R6, R9, R10 and R12 (whatever the hand), R8, R11 (the opening wave), R14 (the wave's bounds at scale), R15 (the per-event budget, and 120 Hz on hardware), R16 (at rest, on hardware), R17 (the motion knobs).

**Test scenarios:** T29, T30, T31, T32, T33, T34, T35, T36.

**Skills:** dev-workflow:tdd, macos-dev-workflow:swift-testing-pro, macos-dev-workflow:axiom-graphics

- [ ] T29 to T36 are green, and every earlier row stays green.
- [ ] R15's check under Verified without a test passes at 120 Hz with ten apps, and the wave's feel shows no visible jitter.
- [ ] R16's check passes on the perf build.
- [ ] The "fingers resting on an open switcher" phase is added to `Scripts/perf/session.sh` and to the method in `docs/performance.md`, and both measurements are entered as a dated result.

### S6: The look is tuned in one place

**What to build:** in DEBUG builds, the animation tuner gets a "Liquid switcher" section over `LaunchTuning.liquid`, saved with the presets. The app target injects `{ LiquidTuning.current }` into `SettingsShell`, which hands it to `SwitcherPresenter`. The presenter reads it once per swipe. Release plays `.shipped`.

- **LauncherCore:** `LiquidLook: Codable` in DEBUG builds only, with the missing-key fallback.
- **LauncherPlatform:** `LaunchTuning.liquid` with its line in `init(from:)`, the tuner section, and `LiquidTuning.current`.
- **LauncherUI:** `SettingsShell.init(liquidLook:)`.
- **App target:** the closure.

**Blocked by:** S2.

**Requirements:** R17.

**Test scenarios:** T37.

**Skills:** dev-workflow:tdd, macos-dev-workflow:swift-testing-pro, macos-dev-workflow:axiom-swiftui, macos-dev-workflow:axiom-macos

- [ ] T37 is green.
- [ ] R17's check under Verified without a test passes: the tuner, the grep and the Release branch.
