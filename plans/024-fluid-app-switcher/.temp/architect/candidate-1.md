## Design

### Problem

The app switcher becomes one Liquid Glass shape: a band with a bead per icon and a swell around the selected icon. The swell stretches, flows, wobbles and settles, and a wave driven by the fingers runs through the beads (R1 to R17). Three facts make the shape non-obvious.

1. Only SDF-merged glass in an `NSGlassEffectContainerView` reads as Liquid Glass (A1, A2, A8). AppKit glass comes only as rounded rectangles (A11). So the shape has to be a union of rounded-rect glass views.
2. Merged glass moves on the render server only through AppKit's private `CASDFElementLayer` mirror (A5, A6). Every public path steps frames in-process once per display frame, at 30 to 100 times the CPU (A4), against `docs/architecture.md`'s animation rule (B1, B2).
3. The flow, wobble, settle, spring-back and wave decay continue after the last input event, and nothing triggers code then (how.md gotcha 2). So each motion has to be staged whole at an input event and end on its own.

Constraints honoured:

- These stay untouched (non-goals, how.md wall 3): the window switcher, `SwitcherSelection`, `GestureRules`, the recognizer, `SwipeEvent` and every port.
- `LauncherUI` cannot see `LauncherPlatform` (B4).
- `OverlayPanel` is shared with the window switcher (C6).
- R12 already holds in `Launcher.swipe` (C8).
- `Observations` may coalesce values (how.md section 5), so every input is treated as an absolute target, never an increment.
- Animating a glass view's own layer inside a container shows nothing (A3).
- A direct write to an element layer is reset by AppKit's re-sync, but an additive animation survives it (A6).

### Usage (caller's view)

> **`Liquid`** (LauncherCore) is the switcher's liquid as numbers.
>
> 1. Build a `SwitcherRowLayout` for the row from a `LiquidLook`.
> 2. Make one `Liquid` per swipe.
> 3. Give it every selection the model shows, with the time on your clock. Each call returns a `LiquidFrame`:
>    - the swell view's new resting rect, only when the selection moved;
>    - the icon to grow;
>    - the keyframe tracks to stage, each of which replaces the running track of its channel.
>
> Apply the frame and forget it. Nothing calls back, none of your code runs between calls, and every track ends by itself within a second. `shape(at:)` tells you what the render server shows at any instant. `.still` is the Reduce Motion look, and the fallback when the mirror is missing.

**Call site 1: `SwitcherPresenter` (LauncherUI), once per observed value.**

```swift
private func render(_ switcher: Switcher?) {
    guard let switcher else { liquid = nil; return panel.dismiss() }      // 150 ms fade (R11); the lift never waits (R12)
    let now = LiquidTime(seconds: CACurrentMediaTime())                     // Core Animation's clock, read per input event
    if !panel.isPresented || switcher.row != laidOutRow { return open(switcher, at: now) }
    guard let frame = liquid?.follow(switcher.selection, at: now), !frame.isEmpty else { return }   // nothing changed: no commit
    panel.apply(frame)
}

private func open(_ switcher: Switcher, at now: LiquidTime) {
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let layout = SwitcherRowLayout(
        iconCount: switcher.row.count, displayWidth: Double(screen?.frame.width ?? 0), look: look())   // look snapshot per swipe
    let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !panel.playsMotion
    var liquid = Liquid(layout: layout, motion: still ? .still : .flowing)
    panel.lay(out: switcher.row.map { icons.icon(forSwitcher: $0) }, layout: layout,
              on: screen?.frame ?? .zero, backingScale: screen?.backingScaleFactor ?? 2)
    panel.apply(liquid.follow(switcher.selection, at: now))                 // first call: settled, no tracks (R11)
    panel.present(appear: nil)
    self.liquid = liquid
    laidOutRow = switcher.row
}
```

**Call site 2: `SwitcherPanel.apply` (LauncherUI). It is the only code that touches glass.**

```swift
func apply(_ frame: LiquidFrame) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if let rest = frame.swell { swellView.frame = NSRect(rest) }       // public; AppKit mirrors it at once (A6)
    if let icon = frame.icon { grow(icon) }                             // our own icon layers
    if !frame.tracks.isEmpty, let elements = mirroredElements() {       // nil: mirror missing, and the rests alone show
        for track in frame.tracks {
            let layer = elements[track.element]!
            layer.add(LiquidKeyframes.animation(track, beginTime: layer.convertTime(track.begin.seconds, from: nil)),
                      forKey: track.key)                                // replaces the channel's track; never queues
        }
    }
    CATransaction.commit()
}
```

**Call site 3: a scenario test (LauncherCoreTests, through `World`).**

```swift
@Test func quickSwipeMakesABiggerWaveThanASlowOne() {                       // R8
    let fast = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(60))
    let slow = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(600))
    #expect(fast.peakRipple(bead: 2) > 1.5 * slow.peakRipple(bead: 2))
}

@Test func liquidReachesTheNewIconWithin200ms() throws {                     // R6
    let run = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(80))
    let change = try #require(run.selectionChanges.first)
    #expect(run.liquid.shape(at: change.time + 0.2).swell.isWithin(run.layout.look.wobble, of: run.layout.swell(at: 1)))
}

@Test func reduceMotionJumpsAndNothingRipples() {                           // R13
    let run = World.switcherWorld().liquidSwipe(rightMM: 7, over: .milliseconds(80), motion: .still)
    #expect(run.frames.allSatisfy { $0.frame.tracks.isEmpty })
    #expect(run.frames.compactMap(\.frame.swell).last == run.layout.swell(at: 1))
}
```

**Call site 4: the composition root (app target), and making the swell subtle.**

```swift
shell = SettingsShell(launcher: launcher, liquidLook: { LiquidTuning.current }, quit: { [unowned self] in lifecycle.quit() })

// LauncherCore, LiquidLook: the only edit a subtler swell needs (R17)
public var swellRise = 12.0   // → 3
```

### Shape

**Data first.** There are three values, each with one owner.

1. **Geometry.** `SwitcherRowLayout(iconCount:displayWidth:look:)` stays the one geometry source (008 decision 10). It now carries the `LiquidLook` it was built from. From one `centreX(at:)` and one `scale` it derives every resting rect, corner radius, the container spacing, the panel size and the wave's limits. The full-size defaults are p5's proven look:
   - icon 80 pt, pitch 100 pt;
   - bead 80 pt, radius 0.32 of its side;
   - band 52 pt thick, a capsule running from the first icon centre to the last;
   - swell = bead + 2 × `swellRise`, so 104 pt;
   - spacing 40.

   Every length, radius, the spacing and every limit is multiplied by `scale` (R14). The panel is the liquid's farthest reach on every side: half a bead, plus the rise, plus R10's 20 pt pull, plus 8 pt. It is centred on the display as today.
2. **Motion state.** `Liquid` owns one swipe's motion:
   - the last input: `selected`, `position`, and `overshootMM` derived from `selection.travelMM`;
   - two `EdgeCurve`s, the swell's left and right edges in panel points;
   - a `WaveTrain` of crests;
   - a velocity estimate for the swell's leading edge;
   - the mode.

   An `EdgeCurve` is the single motion primitive. It approaches a target along a cubic Hermite, from its current position and velocity to the target and an arrival velocity, over `T`. Then it wobbles around the target as a damped sine seeded by that arrival velocity. It is windowed to end at the target at most 1 s after it starts. Flow, finger follow, spring-back and end pull are four parameter choices of this one curve.

   The wave is a list of crests, each with an emission time, an origin in items, a direction and a strength. Bead `i`'s height offset is `saturate(Σ strength × falloff(d) × ripple(t − emitted − d / c))`.
3. **Output.** A `LiquidFrame` carries three things:
   - `swell`, the swell view's new rest, only on a selection change;
   - `icon`, the selected icon and how long it grows;
   - `tracks`, additive offsets keyed per `(element, property)`, sampled at 240 Hz from the same functions `shape(at:)` evaluates.

   So what a test reads is what the render server plays.

These are derived, never stored: the swell's rest (from `selected`), the swell's height (from its width, by `thinning`), every track, and `shape(at:)`. Each access pattern was traced:

| When | Work | Cost |
|---|---|---|
| Each event | compare the input; retarget two edges from their closed-form state at `t`; sample three swell tracks | about 150 samples each |
| Each crest (at most every half icon) | sample the beads' height tracks | N × about 150 samples |
| Each test | `shape(at:)` at any instant | closed form |

No index or cache is needed.

**D1. The glass: band + beads + swell, the band being the neck.**

- One `NSGlassEffectContainerView` holds N + 2 `.regular` glass views: the band, N beads and the swell.
- Between beads, the band is the narrower neck (R3), so the shape is unbroken whatever the spacing (A2, `p3-rest.png`, `p5-light-white.png`).
- With one app, the band shrinks inside its bead and the swell encloses both (R1's one-app scenario).
- No tint (R2).
- The window stays clear, borderless and shadowed. Its shadow traces the merged shape without `roundedClip` (A9). R2's light-over-white scenario leans on that shadow (A10).
- Icons are our `CALayer`s in a sibling view above the container, placed by the same `centreX`, so icons and shape cannot drift.
- Ten bead views are created with the panel, so the first swipe pays nothing extra. Beads a row does not use are taken off the container.

**D2. Motion: render-server keyframes on the private mirror, with the views as the truth.**

- *Views.* Glass views get public frames only at open (all of them) and on a selection change (the swell only). AppKit mirrors those at once (A6).
- *Tracks.* Everything else is an additive `CAKeyframeAnimation` on the swell's or a bead's `CASDFElementLayer`. Each is keyed per channel (`liquid.swell.width`, …), sampled from `Liquid`'s curves with linear calculation mode (the `LaunchFlight` precedent).
- *Ending.* A track whose last offset is 0 removes itself. A track that ends on a held offset (the R5 lean, the R10 pull) stays filled forwards, as the launch bounce's inflate does (`BounceStaging`).
- *Why it is robust.* Additive animations survive AppKit's re-sync (A6), so nothing we stage is clobbered. If anything private misbehaves, the views already show the correct resting shape.
- *No rule change.* This is the architecture rule's own text: "Animation is Core Animation keyframes, which the render server plays". `docs/architecture.md` only needs wording added (see the open questions).
- *Least resources.* The render server plays motion for 2.5 to 4.5 ms of our CPU per 1.2 s, against 133 to 422 ms on the public paths (A5, A4). Each event stages about 3 tracks, where A7's additive mode moved 11 channels for about 0.2 to 0.3 ms per event. That stays below today's 1.08 ms per frame (C9).
- *Private-API precedent (B3).*
  - The reach is confined to one file, `GlassElements`, by the source scan.
  - The lookup is read-only: by class name and by frame.
  - Only public `CALayer` API is ever called on those layers.
  - No `dlsym` and no private properties.
- *Fallback.* `GlassElements.find` returns nil when the class is gone or the element count or frames do not match. Then `playsMotion` turns false and later swipes open `.still`, which is R13's look: the swell jumps by a view frame on each selection change, and nothing else runs per event. In the swipe where the mirror vanishes, tracks are dropped and the rests still show.

**D3. The per-event path, and 120 Hz (R15).**

- One `.moved` event runs `Observations` → `render` → `follow` → `apply`. That is one Core Animation commit with at most three swell tracks. A crest adds N bead tracks, and a selection change adds one frame set and the icon grow.
- Between trackpad frames, the follow approach restarts from the current state at every event over `followTime` (1/60 s), sampled at 240 Hz. So the render server moves the swell on every display frame whatever the trackpad's rate (C5), and the lag is at most `followTime`.
- Under `.still`, `follow` is empty unless the selection changed, so there is no commit per event at all.

**D4. Finger speed (R8, C2) is measured inside `Liquid`, on the liquid's clock.**

- A crest's strength comes from the change in position since the last crest divided by the time between them, with an 8 ms floor. The leading edge's arrival velocity is a moving average of the target's change over time.
- Coalescing only lengthens the time span, which still gives the correct average speed. No new signal goes through the recognizer, the port or the model.
- The bounds hold whatever the speed:
  - strength = `waveHeight × tanh(speed / waveFullSpeed)`;
  - a bead's offset is soft-saturated into limits the geometry derives;
  - a bead grows at most to the swell's height, so the shape never reaches beyond its resting bounds by more than the swell does;
  - a bead shrinks at most to the icon body plus 4 pt, and never below the band;
  - the band never animates, and icons never move.

  So R8's hardest flick holds by construction, not by tuning.

**D5. Retarget, lift, open and close (R6, R7, R11, R12).**

- *Retarget.* Every `follow` is an absolute target. Every curve restarts from its own current position and velocity. The swell view jumps to the newest selected icon, and the curves carry the shape the rest of the way.
- *Flow.* The leading edge arrives at `leadShare × flowTime` and the trailing edge at `flowTime`, which is capped at 0.2 s. So mid-flow the drop spans both icons, and it ends on the new one with a wobble.
- *Flick.* A flick across three apps is one jump of the rest and one flow. The middle icons are never targeted (R7).
- *Lift.* The model already brings the app to front first (C8). `render(nil)` then fades the window over 150 ms over whatever is still moving.
- *Open.* The first `follow` returns a settled frame: the swell at rest, the icon at 1.12× at once, no tracks. Waves begin on the first movement.
- *Re-open during the fade.* `present` cancels the fade through the existing generation guard. `lay(out:)` removes every liquid animation and sets every frame again, so laying out twice is harmless.

**D6. Reduce Motion and zero work at rest (R13, R16).**

- Reduce Motion is read once at open and selects `.still`.
- At rest no events arrive, so none of our code runs. Every curve ends at most 1 s after its event.
- Held offsets are finished, filled animations, which should draw no frames (probe P7 checks this).
- While hidden, the window is ordered out.
- Nothing loops or repeats.

**D7. Tuning (R17, B4, B5).**

- `LiquidLook` lives in LauncherCore: Foundation-only numbers, `Codable` with the missing-key fallback, and `shipped`.
- Every module can reach it: the UI renders it, the Platform tuner edits it as `LaunchTuning.liquid`, and the app target injects `{ LiquidTuning.current }` into `SettingsShell` and on to `SwitcherPresenter`. It is read once per swipe.
- `swellRise` is the one swell setting.
- The requirement bounds are private constants of `Liquid`, so no look can break them: flow at most 0.2 s, settle at most 1 s, end pull at most 0.2 pitch.

**D8. `OverlayPanel` (C6).**

- It no longer chooses the content. `OverlayPanel(content:)` keeps the window configuration, `present`, the 150 ms fade and the generation guard.
- Today's rounded `.regular` glass in `roundedClip` becomes a helper, `roundedGlass(_:cornerRadius:)`. `WindowSwitcherPanel` passes its content through it, so the window switcher stays pixel-identical.
- `SwitcherPanel` passes its own root view: the container plus the icon host.

**Interface depth.** `Liquid`'s public surface is `init(layout:motion:)`, `follow(_:at:)`, `shape(at:)` and plain value types. Behind it sit:

- the lean, pull and flow policy;
- the curves and the wave;
- the speed estimate, saturation, windowing and sampling;
- idempotence;
- the R6, R9 and R10 bounds.

The adapter knows no policy: it maps a track to a key path and a layer.

**What it deliberately does not do:**

- the band never moves;
- no motion while hidden or settled;
- the shape does not re-form when an app quits;
- a Reduce Motion change takes effect from the next swipe;
- no motion carries over from one swipe to the next;
- no idle motion.

**Traceability.**

| R | Carried by |
|---|---|
| R1 | `SwitcherRowLayout.band` / `bead(at:)` / `swell(at:)` in one container. One app: the band sits inside its bead. |
| R2 | `.regular` glass, no tint, a clear shadowed window. Checked by hand. |
| R3 | `bandThickness` < `beadSide`; the band between beads is the neck. |
| R4 | `swell(at:)` = bead + 2 × `swellRise`; `selectedIconScale` 1.12; `IconChange`. |
| R5 | The lean: the leading-edge target is rest + `reach × lean × pitch`, the trailing edge is pinned, and the follow curve's tail springs back. |
| R6 | `LiquidFrame.swell` plus the flow `EdgeCurve` (arrival ≤ 0.2 s, then a wobble), retargeted from the current state. |
| R7 | The rest jumps to the final icon; one flow. |
| R8 | `WaveTrain`: tanh(speed), e^(−d/reach) falloff, direction of the slide, saturation limits from the layout, a static band. |
| R9 | Every curve windowed to end ≤ 1 s after its cause. |
| R10 | pull = P × (1 − e^(−o / `endPullMM`)) with P = min(`endPull`, 0.2 pitch); the outer edge only; no crests while past an end; the turn back is a follow to 0 with a wobble. |
| R11 | The first `follow` is settled; `present(appear: nil)`; the fade in `OverlayPanel.dismiss`. |
| R12 | `Launcher.swipe(.ended)` unchanged; `render(nil)` never waits. |
| R13 | `LiquidMotion.still`. |
| R14 | `SwitcherRowLayout.scale` applied to every length. |
| R15 | D3. |
| R16 | D6: empty frames at rest. |
| R17 | `LiquidLook`, `swellRise`. |

**Module map.**

| Module | What it holds |
|---|---|
| LauncherCore | `LiquidLook`, `SwitcherRowLayout` (extended), `Liquid` with its private `EdgeCurve`, `WaveTrain` and sampler, and the frame values. `Switcher`, `SwitcherSelection`, `GestureRules`, `Launcher` and the recognizer are unchanged. |
| LauncherUI | `SwitcherPresenter` (thin), `SwitcherPanel` (rewritten), `LiquidKeyframes`, `GlassElements` (the only private reach), `OverlayPanel(content:)`, `roundedGlass`. `WindowSwitcherPanel` changes one init line. |
| LauncherPlatform | `LaunchTuning.liquid` plus a tuner section; the public `LiquidTuning.current`. |
| App target | Injects the look closure. |
| Tests | `LiquidTests` and the `liquidSwipe` helper in LauncherCoreTests; `SwitcherRowLayoutTests` rewritten; a new `LauncherUITests` target (`LiquidKeyframesTests`, `GlassElementsMatchTests`); `SourcePolicyTests` confines `CASDFElementLayer` to `GlassElements.swift`. |

**LauncherCore.**

```swift
/// Every number of the switcher's liquid look and motion, at full size (points, seconds, items). The defaults ARE the
/// shipped look. Requirement bounds are not here: `Liquid` enforces them whatever this holds.
public struct LiquidLook: Equatable, Sendable, Codable {
    // Shape (R1–R4; R17 "bead and neck shape")
    public var beadSide = 80.0, beadCorner = 0.32          // corner as a share of the side
    public var bandThickness = 52.0                         // the neck
    public var spacing = 40.0                               // the container's merge distance: how soft the necks' fillets are
    /// THE swell setting (R4, R17): how far the swell rises beyond the beads on each side. 3 is subtle.
    public var swellRise = 12.0, swellCorner = 0.32
    // Stretch, flow, end pull (R5, R6, R10)
    public var reach = 0.5                                  // leading-edge stretch per item of lean
    public var followTime = 1.0 / 60                        // glide between input events (R15)
    public var flowTime = 0.18, leadShare = 0.6             // Liquid caps flowTime at 0.2 s
    public var endPull = 20.0, endPullMM = 1.0              // capped at 0.2 pitch; e-fold per step-mm, so 95% by 3 mm
    public var thinning = 0.25                              // swell height lost per point of stretch
    // Wobble (R6, R9)
    public var wobble = 4.0, wobbleHz = 4.5, wobbleDamping = 0.35
    // Wave (R8)
    public var waveHeight = 6.0, waveFullSpeed = 8.0        // crest in points at full speed; items per second for full speed
    public var waveReach = 2.5, waveSpeed = 14.0            // items to 1/e; items per second of travel
    public var waveHz = 5.0, waveDamping = 0.4, waveBehind = 0.3, waveEvery = 0.5

    public static let shipped = LiquidLook()
    public init() {}
    /// Missing keys decode as shipped, so saved tuner presets survive new knobs (TunerCodingTests precedent).
    public init(from decoder: any Decoder) throws { fatalError("not implemented") }
}

/// The one geometry source: icons, band, beads and swell all hang off `centreX(at:)` and `scale`, so they cannot drift.
public struct SwitcherRowLayout: Equatable, Sendable {
    public static let fullIconSide = 80.0, fullPitch = 100.0, selectedIconScale = 1.12
    public let iconCount: Int
    /// The look both the geometry and the motion read: one snapshot per swipe.
    public let look: LiquidLook
    /// One factor for every length, radius, spacing and limit (R14): min(1, displayWidth / ((n − 1) × 100 + 2 × reach)),
    /// reach = beadSide / 2 + swellRise + 0.2 × 100 + 8. A non-positive width means 1.
    public let scale: Double
    public init(iconCount: Int, displayWidth: Double, look: LiquidLook = .shipped) { fatalError("not implemented") }

    public var iconSide: Double { Self.fullIconSide * scale }
    public var pitch: Double { Self.fullPitch * scale }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    public func centreX(at position: Double) -> Double { fatalError("not implemented") }
    public var centreY: Double { panelSize.height / 2 }
    public var band: LiquidRect { fatalError("not implemented") }                     // first centre to last; capsule
    public func bead(at index: Int) -> LiquidRect { fatalError("not implemented") }
    public func swell(at index: Int) -> LiquidRect { fatalError("not implemented") }   // bead + 2 × rise, same centre
    public var radii: (band: Double, bead: Double, swell: Double) { fatalError("not implemented") }
    public var spacing: Double { look.spacing * scale }
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
    /// Reduce Motion, or the glass mirror is missing: the swell jumps to the selected icon; nothing stretches or ripples (R13).
    case still
}

/// The switcher's liquid during one swipe.
public struct Liquid: Sendable {
    public init(layout: SwitcherRowLayout, motion: LiquidMotion) { fatalError("not implemented") }

    /// The first call returns the settled opening (R11): the swell's rest, the icon at once, no tracks. Later calls
    /// return only what changed. On a selection change that is the swell's new rest and the growing icon. In any case
    /// it is the tracks that replace their channels' running ones, each starting where its channel is, and as fast
    /// as it moves, at `time`. The frame is empty when nothing the liquid reads changed: `selected`, `position`, and
    /// the overshoot taken from `travelMM`. So pushing against the clamp is empty, a repeated call is empty, and
    /// under `.still` every call that keeps the selection is empty.
    public mutating func follow(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        // guard input != last else { return .empty }
        // opening: settle at input, return (swell: rest(selected), icon: (selected, 0), tracks: [])
        // .still: return selection changed ? (swell: rest, icon: (selected, 0)) : .empty
        // targets: trailing edge = rest edge; leading edge = rest edge + reach × lean × pitch, lean = position − selected;
        //          outer edge past an end += pull(overshoot)
        // selection changed: both edges flow (lead over leadShare × T, trail over T, T = min(flowTime, flowBound)),
        //                    arriving with a velocity whose damped tail stays within `wobble`
        // else: the leading edge follows over followTime, arriving at the estimated finger velocity (its tail is the
        //       R5/R9/R10 wobble)
        // the wave emits a crest each `waveEvery` items of travel (and on the first move), but not past an end; strength
        //   tanh(speed)
        // tracks: swell centreX, width, height sampled from the edges; on a crest, each bead's height
        fatalError("not implemented")
    }

    /// What the render server shows at `time` from what has been staged; constant once settled.
    public func shape(at time: LiquidTime) -> LiquidShape { fatalError("not implemented") }

    static let flowBound = 0.2, settleBound = 1.0, endPullBound = 0.2, sampleRate = 240.0   // R6, R9, R10, LaunchFlight
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
/// Additive offsets in points over the element's rest, `step` seconds apart from `begin`. The last offset is held
/// (filled forwards) when it is not 0, and removed on completion when it is. `end` ≤ the causing call + settleBound.
public struct LiquidTrack: Equatable, Sendable {
    public let element: LiquidElement, property: LiquidProperty
    public let begin: LiquidTime, step: Double
    public let offsets: [Double]               // at least two samples, by construction of the sampler
    public var key: String { fatalError("not implemented") }   // one per channel: replacing is retargeting
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
/// The app switcher's window. It renders `LiquidFrame`s and decides nothing: N + 2 glass views in one container, and the
/// icon layers above them.
final class SwitcherPanel: OverlayPanel {
    /// False once the mirror could not be found; the presenter then opens `.still`.
    private(set) var playsMotion = GlassElements.exist
    func lay(out images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, backingScale: CGFloat) {
        // Sets every view frame, radius and the spacing; adds or removes pooled beads; removes every "liquid." animation;
        // forgets matched elements; places icons at centreX; setFrame once (never per event)
        fatalError("not implemented")
    }
    func apply(_ frame: LiquidFrame) { fatalError("not implemented") }   // call site 2
    private func mirroredElements() -> [LiquidElement: CALayer]? { fatalError("not implemented") }   // lazy; cached until lay(out:)
}

/// Pure staging, read back by tests like LaunchFlightTests: additive, linear calculation, values = offsets, duration from
/// step and count; fillMode forwards and not removed if the last offset ≠ 0.
enum LiquidKeyframes {
    static func animation(_ track: LiquidTrack, beginTime: CFTimeInterval) -> CAKeyframeAnimation { fatalError("not implemented") }
}

/// The one file that knows how AppKit mirrors Liquid Glass (A1, A6); the source scan confines `CASDFElementLayer` here.
enum GlassElements {
    static var exist: Bool { fatalError("not implemented") }   // NSClassFromString("CASDFElementLayer") != nil
    static func find(in container: NSGlassEffectContainerView, for views: [NSGlassEffectView]) -> [CALayer]? {
        fatalError("not implemented")
    }
    /// Each view matched to exactly one element by frame within 0.5 pt, else nil. Pure, so tests drive the fallback.
    static func match(elements: [CGRect], views: [CGRect]) -> [Int]? { fatalError("not implemented") }
}

class OverlayPanel: NSPanel {
    init(content: NSView) { fatalError("not implemented") }   // the window config, present, fade and generation as today
}
/// Today's `.regular` glass in `roundedClip`, now the window switcher's own choice.
func roundedGlass(_ content: NSView, cornerRadius: CGFloat) -> NSView { fatalError("not implemented") }
```

**LauncherPlatform and the app target.** `LaunchTuning` gains `var liquid = LiquidLook.shipped`, nested as `bounce` is, with a "Liquid switcher" tuner section. `public enum LiquidTuning { public static var current: LiquidLook }` returns the tuner's override in DEBUG and `.shipped` in Release. `SettingsShell.init` gains `liquidLook: @escaping @MainActor () -> LiquidLook = { .shipped }` and passes it to `SwitcherPresenter`.

**The seam the tests run at: `Liquid`, driven through `World`.** `World.liquidSwipe(...)` plays a `TouchScript` frame by frame. After each frame it feeds `launcher.switcher?.selection` to a `Liquid`, at `LiquidTime(frame.time.seconds)`. It returns every frame staged and the final `Liquid`. The test handles:

| Handle | How a test uses it |
|---|---|
| Time | Frame times are the liquid's clock, and `shape(at:)` evaluates any instant (for example, the scenario's 2 s rest). |
| Finger speed | `slide(byMM:over:)` sets how long a slide takes. |
| Reduce Motion | `motion: .still`. |
| The missing mechanism | `.still` is exactly what the panel selects. `GlassElements.match` returning nil is tested in `LauncherUITests`. |

What each scenario observes:

| R | Scenario check |
|---|---|
| R5 | At 5 mm, the left edge and the icon are unchanged and the right edge is beyond rest; sliding back, the shape returns to rest by settle. |
| R6 | The swell arrives within the wobble of `swell(at: 1)` by change + 0.2 s. A steady slide stays within one pitch of the newest rest at every 150 ms change. |
| R7 | One frame with `swell(at: 3)`. |
| R8 | Fast against slow peak ripple; ripple falls with distance; a 36 mm flick in 10 ms keeps every bead within its limits and the band rect constant. |
| R9 | Every track ends ≤ last event + 1 s; `shape(at:)` is constant afterwards. |
| R10 | `swell.maxX` − rest ≤ 0.2 × pitch; the beads constant. |
| R11 | The first frame has no tracks. |
| R13 | No tracks. |
| R14 | Every rect × scale; the panel fits the display. |
| R16 | After settle, an identical selection gives an empty frame. |

R2, R15 and R16 can only be checked by hand, on a Release perf build:

- **R2:** light over white and dark over busy, captured as p5 was.
- **R15:** 10 apps on a 120 Hz display, under Instruments' Animation Hitches, plus `sampler` CPU per frame against the 1.08 ms baseline.
- **R16:**
  - Quartz Debug's flash screen updates, and Core Animation FPS, both read 0 while the fingers rest;
  - a new `session.sh` phase, "fingers resting on an open switcher", shows no app wake-ups beyond the recognizer's.

Also by hand: the 200 ms flow in a 240 fps screen recording, the shadow keeping up, and the feel.

**Docs this needs.** No rule change. These additions go to the user (the 017 precedent):

- `architecture.md`:
  - the per-input-event example becomes "the app switcher's liquid on trackpad frames";
  - a Privacy-and-permissions sentence: "the app switcher animates the private layers AppKit mirrors Liquid Glass into, confined to one file; when they are missing it shows without motion, as with Reduce motion";
  - the Shape bullet: Core holds the liquid as numbers.
- `domain-model.md`: the Switcher entry's look.
- `performance.md`: the new phase and the measurements.

### Synthesis decision

### Tradeoffs accepted

- We accept the first reach into another framework's private layer tree in exchange for render-server motion at about 1/50 of the CPU, with no rule change. The reach is confined to one file, it only reads and adds public animations, and it falls back to the tested R13 look.
- We accept one public frame set on the swell per selection change, a few per second, in exchange for views that always hold the correct resting shape. This needs P7(b): a view set and a re-based track have to land in one commit. If they do not, the fallback carries the swell's travel as a held track, with views fixed during a swipe.
- We accept held offsets as finished, filled animations (R16 rests on P7(a)) in exchange for no baking step. If they turn out to draw frames, the fallback bakes the held offset into the swell's view frame from the track's completion, which the architecture rule's "cleaned up from its completion callback" sanctions.
- We accept main-queue jitter in the measured speed in exchange for no new signal through the recognizer, the port or the model.
- We accept crests only every half icon of travel in exchange for per-event work of three tracks. A sub-half-step creep makes one crest.
- We accept boxing about 150 sampled numbers per track per event in exchange for curves we can bound, window and test exactly. CA's own springs could not be.
- We accept `Liquid` (a visual policy) living in LauncherCore, as `SwitcherRowLayout` already does, in exchange for testing it through `World`.
- We accept Reduce Motion being read once per swipe.
- We accept that `swellRise` also sets R8's wave ceiling and, on narrow displays, the scale.
- We accept that `SwitcherSelection.stretch` and `switcherMaxStretch` now serve only the window switcher. That is not dead code.

### Alternatives considered

- **Public in-process animation** (`animator()`, implicit animation, SwiftUI `GlassEffectContainer` with `withAnimation`). It hides the mirror but runs per display frame in our process at 30 to 100 times the CPU (A4). It needs the animation rule rewritten, and plan 006 rejected SwiftUI here. Lost.
- **One masked glass view with an animated `CAShapeLayer` path.** It is public and runs on the render server, but it renders as flat frosted glass (A8). That fails R2. Lost.
- **Direct writes to the element layers per event, with springs on top.** It is the cheapest per event (A7), but AppKit's re-sync resets those writes whenever any glass view changes or a layout runs (A6). The design would then depend on never touching views, and a re-sync would land on stale geometry. Lost on robustness.
- **Stacked additive `CASpringAnimation`s, one per kick, with the render server computing the springs.** It needs fewer values per commit and keeps velocity by superposition. But the animations pile up without bound, the 200 ms arrival depends on the state, a sum of springs cannot be saturated (so R8 and R9 bounds are not enforceable), and tests cannot observe it without mirroring CA's spring formula. Lost on bounds by construction.
- **Finger speed from driver frame times, carried on `SwipeEvent` into `Switcher`.** It is accurate, but it threads a new field through a port type shared with the window swipe and both hardware adapters. It is kept as the remedy if the hardware shows wave-size jitter.
- **The swell as beads that grow (no swell element).** Nothing could travel between icons, and R5's moving leading edge would still need another element. It reads as two bulges cross-fading, not liquid flowing. Lost.

### Open questions and risks

1. **R10 while the fingers rest past an end:** should the pull hold (this design, consistent with R5's held stretch and the model's clamped travel), or spring back as today's band does?
2. **R4's "12 pt beyond the band on each side":** does it mean beyond the beads (swell 104 pt, as p5 shows)? Read literally against a 52 pt neck it gives 76 pt, which is smaller than a bead.
3. **R17 against R8:** a subtle swell lowers R8's ceiling, so crests taller than `swellRise` get capped. Is that change acceptable, or should the wave's ceiling be its own setting?
4. **Do you accept the private glass mirror, and the three architecture-doc additions, as the 017 precedent requires?**
5. **R2 light over white leans on the window shadow (A10).** If it fails on your Mac, a tint is your call (non-goal).
6. **P7, a probe to run before the adapter.** It has to show:
   - (a) a finished, filled additive keyframe on an element layer draws no frames;
   - (b) a swell view frame set and a re-based additive track land in one commit, with no one-frame jump;
   - (c) the cost of 3 tracks per event plus 10 bead tracks per crest on a 10-app row;
   - (d) a bead view taken off the container drops its element;
   - (e) whether the shadow keeps up frame by frame.
7. Is wave-size jitter from presenter-clock speed visible on hardware? If it is, switch to driver times (alternative 5).
8. Should a Reduce Motion change apply mid-swipe? Here it waits for the next swipe.

### Next implementation step

Run probe P7, and meanwhile build `SwitcherRowLayout`'s liquid geometry and `Liquid` in LauncherCore test-first through `World.liquidSwipe`, starting with R11, R13 and R6.
