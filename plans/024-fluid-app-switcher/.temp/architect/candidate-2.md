## Design

### Problem

The switcher must become one Liquid Glass shape that answers the fingers: a band with a bead per icon, a swell around the selected icon that leans toward where the fingers head, flows to a new selection within 200 ms, ripples the band in proportion to finger speed, and goes still within a second of the fingers stopping (R1 to R17). Four facts shape the answer. Only an `NSGlassEffectContainerView` merging `NSGlassEffectView`s reads as Liquid Glass (A1, A8); AppKit offers no other shape. Every public way to animate that merged shape runs our code once per display frame at 30 to 100 times the CPU (A4), against `docs/architecture.md`'s rule that the render server plays animation and nothing of ours runs per display frame (B1). The render server does animate the merged shape, but only through AppKit's private per-view `CASDFElementLayer` mirror, where additive animations survive AppKit's own re-sync and direct writes do not (A5, A6), at 2.5% of a core per event path against 26% for public frame sets (A7). And the payload the UI observes carries no finger speed (C2), while R8 needs one. The design must also leave the window switcher, `SwitcherSelection`, `GestureRules`, selection, ticks, row contents and lifting untouched, keep framework types out of `LauncherCore`, keep every number in one tunable value whose defaults ship (B4, B5), and name a fallback for the day the private mirror changes (B3).

### Usage (caller's view)

**The quickstart a maintainer reads.** The liquid is three pure Core values and one AppKit panel. `LiquidLook` holds every number of the look and motion; its defaults are the shipped look, and `swellRise` alone makes the swell subtle. `LiquidGeometry(iconCount:displayWidth:look:)` places the band, the beads, the swell's rest and the icons from one `SwitcherRowLayout`, scaled together for narrow displays. `LiquidMotion` is the policy: feed it each observed `SwitcherSelection` with the finger speed and it returns the `LiquidCommand`s that make the liquid move, already bounded; it never sees Core Animation. `LiquidPanel` is the only code that turns commands into glass: it owns the container, twelve glass views, the icon layers, and the private mirror lookup, and it animates nothing after an input stops except self-ending springs the render server plays.

**Call site 1: the presenter's render loop (`SwitcherPresenter`).**

```swift
private func render(_ switcher: Switcher?) {
    guard let switcher else {
        panel.dismiss()            // the 150 ms fade; in-flight springs finish under it, then emptied() drops them
        return
    }
    if !panel.isPresented || switcher.row != laidOutRow { open(switcher) }
    let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && panel.canAnimate
    panel.apply(motion.step(switcher.selection, speedMMPerS: switcher.speedMMPerS, animated: animated))
}

private func open(_ switcher: Switcher) {
    let look = lookProvider()                           // snapshot per swipe, never per event
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let geometry = LiquidGeometry(iconCount: switcher.row.count, displayWidth: Double(screen?.frame.width ?? 0), look: look)
    motion = LiquidMotion(geometry: geometry, look: look)
    panel.layoutRow(switcher.row.map { icons.icon(forSwitcher: $0) }, geometry: geometry, on: screen?.frame ?? .zero,
                    backingScale: screen?.backingScaleFactor ?? 2)
    panel.apply(motion.open(switcher.selection))        // settled around the first icon, grown icon, no grow-in (R11)
    panel.present(appear: nil)
    laidOutRow = switcher.row
}
```

**Call site 2: a Core test through `World`, at the seam the scenarios run at.**

```swift
@Test func oneStepRightFlowsToTheSecondIconAndRipplesTheBand() {
    let world = World.switcherWorld()                   // Safari, Mail, Slack, Notes; Safari in front
    let look = LiquidLook.shipped
    var motion = LiquidMotion(geometry: LiquidGeometry(iconCount: 4, displayWidth: 1440, look: look), look: look)
    var commands: [LiquidCommand] = []
    world.playFrameByFrame(world.swipe([.right(7, over: .milliseconds(100))], lift: false)) {
        if let switcher = $0.launcher.switcher {
            commands += motion.step(switcher.selection, speedMMPerS: switcher.speedMMPerS, animated: true)
        }
    }
    #expect(commands.flows.map(\.to) == [1])                                   // never two behind, never queued
    #expect(commands.waves.flatMap(\.kicks).allSatisfy { $0.amplitude <= look.waveAmplitude })
    #expect(look.flow.firstArrival(from: 100) < 0.2)                           // R6's 200 ms, as a number
}

@Test func reduceMotionJumpsAndNeverStretches() {
    // same swipe with animated: false
    #expect(commands == [.settle(at: 1), .grow(selected: 1, over: 0)])
}
```

**Call site 3: the staging test in a new `LauncherUITests` target, reading back what would play.**

```swift
let kicks = [BeadKick(index: 1, amplitude: 4, delay: 0), BeadKick(index: 2, amplitude: 2.4, delay: 0.08)]
let staged = LiquidStaging.wave(kicks, serial: 7, look: .shipped, now: 100)
#expect(staged.map(\.key) == ["wave-1", "wave-1"])                 // serial % waveKeys: bounded superposition
#expect(staged.map(\.animation.beginTime) == [100, 100.08])        // propagation on Core Animation's clock
#expect(staged.allSatisfy { ($0.animation as! CASpringAnimation).isAdditive })
```

**Call site 4: tuning.** A Debug build opens the animation tuner, which binds sliders to `\.liquid.swellRise`, `\.liquid.beadSide`, `\.liquid.waveAmplitude` and the rest through `LaunchTuning.liquid`; shipping a tuning copies the values into `LiquidLook`'s defaults, as for `LaunchTuning`.

### Shape

**Data first.** Four value types in `LauncherCore`, plain numbers only (per boundary-discipline: no CoreGraphics, no QuartzCore on any surface):

- `LiquidLook`: the one tunable value (R17). Lengths are points at full size; `LiquidGeometry` scales them.
- `Spring`: stiffness and damping with the closed-form numbers the requirements bound (first arrival, settling time, peak per unit velocity, undershoot). A test asserts R6's and R9's bounds on `LiquidLook.shipped` without rendering, and `LiquidStaging` maps it one to one onto `CASpringAnimation`.
- `LiquidGeometry`: every rectangle of the shape and every icon centre, from one `SwitcherRowLayout`, so icons and glass cannot drift (R1, R3, R4, R14).
- `LiquidCommand`: what the liquid must do next, in points and seconds, bounded by construction. `LiquidMotion` emits them; `LiquidPanel` plays them.

```swift
// LauncherCore

/// Every number of the liquid's look and motion, in one place (R17). The defaults are the shipped look; the Debug tuner
/// edits a copy through `LaunchTuning.liquid`. Lengths are points at full size and scale with the row.
public struct LiquidLook: Equatable, Sendable {
    // The shape (R1, R3, R4)
    /// The band's thickness between two beads: the neck.
    public var bandHeight = 56.0
    /// Each unselected icon's bump; must leave the 80 pt icon inside it after the deepest wave trough (see `isSound`).
    public var beadSide = 88.0
    /// Corner radius as a share of the side, for beads and the swell.
    public var beadRoundness = 0.4
    /// How far the swell stands beyond a bead on each side. The one setting that makes the swell subtle (R17):
    /// 0 makes the selected icon's bead no bigger than the others and changes nothing else.
    public var swellRise = 12.0
    /// `NSGlassEffectContainerView.spacing`: how soon two elements bridge into a neck (A2).
    public var merge = 40.0
    /// Clear glass between the shape's resting bounds and the window's edge, on every side: room for the pull and the
    /// wave, so neither is ever clipped. Must exceed `pullShare × pitch` and the wave's headroom.
    public var margin = 24.0

    // Per-event reach (R5, R10)
    /// How far the swell's leading edge reaches per item of lean (position − selected), as a share of the pitch.
    public var leanShare = 0.5
    /// The most the swell is pulled past an end icon, as a share of the pitch: R10's fifth, 20 pt at full size.
    public var pullShare = 0.2
    /// Step millimetres past the end at which the pull has reached 1 − 1/e of its most: most of it within 3 mm.
    public var pullReachMM = 1.0
    /// Seconds each per-event reach takes, so a 120 Hz display gets in-between frames from the render server, not
    /// from us. Shorter than the trackpad's frame interval, so each tween ends before the next event replaces it.
    public var followSmoothing = 0.012

    // After-input motion: every spring ends on its own (R6, R9, R10)
    /// The swell's flow to a newly selected icon; underdamped, so it ends with the small wobble.
    public var flow = Spring(stiffness: 420, damping: 26)
    /// The spring-back of a held pull when the fingers turn (R10).
    public var wobble = Spring(stiffness: 420, damping: 22)
    /// The swell's width is kicked by this much, in points per second, as it lands: the drop squashes then settles.
    public var flowSquash = 90.0
    /// Seconds the icons take to grow to 1.12× and back.
    public var iconGrow = 0.12

    // The wave (R8)
    /// The most one wave raises the nearest bead, in points.
    public var waveAmplitude = 4.0
    /// Items over which a wave's amplitude falls by 1/e.
    public var waveReach = 2.5
    /// Items per second the wave travels along the band: its delay per bead.
    public var waveSpeed = 14.0
    /// Step millimetres per second at which the wave reaches 1 − 1/e of `waveAmplitude`; the curve saturates, so no
    /// speed exceeds the amplitude.
    public var waveSaturationSpeed = 80.0
    /// Beads behind the swell ripple this share of those ahead: the wave reads as going the slide's way.
    public var wakeShare = 0.5
    /// The bead spring of a wave.
    public var wave = Spring(stiffness: 320, damping: 14)
    /// How many waves may overlap on one bead; older ones are replaced. Bounds the superposition: `waveKeys ×
    /// waveAmplitude` is the most the band ever rises.
    public var waveKeys = 3

    public static let shipped = LiquidLook()

    public var swellSide: Double { beadSide + 2 * swellRise }

    /// The invariants a tuning must keep, each a reason when broken: the wave never rises above the swell, never shrinks
    /// a bead below its icon (the deepest trough is `wave.undershoot` of the crest), the pull and wave fit the margin,
    /// the flow arrives within 200 ms, every spring settles within a second. `LiquidMotion` clamps to these at runtime;
    /// a test asserts `shipped` needs no clamp.
    public var violations: [String] { fatalError("not implemented") }
}

/// A damped spring (mass 1) with the closed-form numbers the requirements bound. The same two constants become a
/// `CASpringAnimation` in `LiquidStaging`, so what a test asserts is what the render server plays.
public struct Spring: Equatable, Sendable {
    public var stiffness: Double
    public var damping: Double

    public var naturalFrequency: Double { stiffness.squareRoot() }
    public var dampingRatio: Double { damping / (2 * stiffness.squareRoot()) }
    /// Seconds after release until the first time the spring is within `tolerance` points of rest, from `offset` away.
    public func firstArrival(from offset: Double, tolerance: Double = 0.5) -> Double { fatalError("not implemented") }
    /// Seconds until the motion stays within `tolerance` points of rest forever.
    public func settlingTime(from offset: Double, tolerance: Double = 0.5) -> Double { fatalError("not implemented") }
    /// The crest, in points, of a spring kicked from rest with one point per second of velocity (underdamped only).
    public var peakPerUnitVelocity: Double { fatalError("not implemented") }
    /// The deepest trough after the crest, as a share of the crest: e^(−ζπ/√(1−ζ²)).
    public var undershoot: Double { fatalError("not implemented") }
}

/// One of the twelve glass elements the shape is made of. Fixed for the panel's life, so AppKit's mirror of each is
/// matched once and never churns: a bead beyond the row is parked, not removed.
public enum LiquidElement: Hashable, Sendable {
    case band
    case bead(Int)      // 0..<10
    case swell
}

/// A rectangle in the window's coordinates, points, y up, with its corner radius.
public struct LiquidRect: Equatable, Sendable {
    public var x, y, width, height, cornerRadius: Double
    public var midX: Double { x + width / 2 }
}

/// Where everything sits for a row of `iconCount` icons on a display `displayWidth` wide: the window's size, the band
/// under every bead, one bead per icon, the parked beads, the swell at rest around any icon, and each icon's centre.
/// All of it comes from one `SwitcherRowLayout` (cell = the swell's side, padding = the margin) and one `scale`, so the
/// icons, beads, swell and band shrink by the same factor on a narrow display (R14) and cannot drift from each other.
public struct LiquidGeometry: Equatable, Sendable {
    public let layout: SwitcherRowLayout
    public let look: LiquidLook
    public let windowSize: (width: Double, height: Double)
    /// The container's spacing, scaled.
    public let merge: Double

    public init(iconCount: Int, displayWidth: Double, look: LiquidLook) {
        // layout = SwitcherRowLayout(iconCount:, displayWidth:, cellSide: look.swellSide, padding: look.margin)
        fatalError("not implemented")
    }

    public var scale: Double { layout.scale }
    public var pitch: Double { layout.pitch }
    public var iconSide: Double { layout.iconSide }
    public func iconCentre(at index: Int) -> (x: Double, y: Double) { fatalError("not implemented") }

    /// The resting rectangle of each element. A one-icon row has a band no wider than its bead, so the shape is the
    /// swell alone (R1, one app). Parked beads sit at distinct spots beyond the band's far end by more than `merge`,
    /// outside the window, where the union cannot see them.
    public func rest(of element: LiquidElement, selected: Int) -> LiquidRect { fatalError("not implemented") }
    /// Every element's resting rectangle with the swell around `selected`.
    public func rests(selected: Int) -> [LiquidElement: LiquidRect] { fatalError("not implemented") }

    /// The most the swell is pulled past an end, scaled: `look.pullShare × pitch` (R10's 20 pt).
    public var maxPull: Double { fatalError("not implemented") }
    /// The most one wave may raise a bead here, after the look's invariants: never above the swell's rise, never a trough
    /// below the icon, never beyond the margin.
    public var waveBound: Double { fatalError("not implemented") }
}
```

`SwitcherRowLayout` keeps its job as the row's one geometry source and gains the two numbers it hard-codes today: `init(iconCount:displayWidth:cellSide:padding:)`, with `highlightSide` renamed `cellSide`; `fullHighlightSide` and `padding` go. `LiquidGeometry` is its only caller. Its tests pass 92 and 22 explicitly and keep their numbers.

**Finger speed (R8, C2) crosses the port on the event the recognizer already computes it for.** `GestureRecognizer` has the frame interval and the frame's travel at line 187 to 199; the rate is one division. `SwipePhase.moved` carries it; the window swipe ignores it; `Launcher.swipe(.moved)` writes it into `Switcher`. On hardware it is accelerated cursor travel per second, what the user feels; under `.linear` in tests it is the script's finger speed, so `TouchScript.slide(byMM:over:)` is the test's handle on speed.

```swift
// LauncherCore, changed
public enum SwipePhase: Equatable, Sendable {
    case began
    /// Travel along the slide since `began`, in step millimetres, absolute, sent only when it changed; and the rate it
    /// changed at over the frame that changed it, signed, step millimetres per second (0 on a frame with no interval).
    case moved(travelMM: Double, speedMMPerS: Double)
    case ended
    case cancelled
}

public struct Switcher: Equatable, Sendable {
    // ... as today, plus:
    /// The rate of the last move, signed, step millimetres per second. 0 until the first move. Written only by
    /// `Launcher` (and tests).
    public package(set) var speedMMPerS: Double = 0
}
```

**The motion policy** is one pure state machine. Its state is what it last commanded, so each step is a diff, and a selection change always retargets to the newest selection from wherever the swell is (R6, R7). The reach (lean inside the row, pull past an end) is a per-event held offset of the swell's one edge; the flow, the release and the wave are springs. Under `animated == false` (Reduce Motion, or no mirror) it emits only settles and instant grows (R13 and the fallback share one path).

```swift
// LauncherCore

/// A wave's kick of one bead: raise it by `amplitude` points at its crest, starting `delay` seconds after the kick.
public struct BeadKick: Equatable, Sendable {
    public var index: Int
    public var amplitude: Double    // ≤ geometry.waveBound by construction
    public var delay: Double
}

/// What the liquid must do next. Points and seconds; nothing about layers. `.settle` and `.grow(over: 0)` are the whole
/// vocabulary under Reduce Motion and without the mirror.
public enum LiquidCommand: Equatable, Sendable {
    /// The swell at rest around `index` at once, every held offset dropped, every spring removed. Open, Reduce Motion,
    /// the fallback.
    case settle(at: Int)
    /// The swell's outer edge reaches `to` points (signed, + right) from its rest, from the `from` it last reached,
    /// over `over` seconds. The trailing edge and the icon never move (R5). Past an end this is the pull (R10).
    case reach(from: Double, to: Double, over: Double)
    /// The held reach springs back to 0 with a wobble: the fingers turned back from past an end (R10).
    case release(from: Double, spring: Spring)
    /// The selection changed: the swell flows from wherever it is now to `to`'s centre on `spring`, its width kicked by
    /// `squash` points per second, while the reach is held at `holdingReach` at once (continuity: the lean the drop
    /// had toward the new icon becomes the flow's start). Replaces any flow still running (R6, R7).
    case flow(to: Int, holdingReach: Double, spring: Spring, squash: Double)
    /// The selected icon grows to 1.12×, the others shrink to 1×, over `over` seconds (0: at once).
    case grow(selected: Int, over: Double)
    /// One wave through the band: a kick per bead other than the selected one, nearer first (R8).
    case wave(serial: Int, kicks: [BeadKick])
}

/// The liquid's policy, pure: each observed selection in, the commands that answer it out. Its state is what it last
/// commanded, so a step is a diff against the shown liquid, and a selection change retargets whatever is in flight.
/// One per swipe; `open` starts it.
public struct LiquidMotion: Equatable, Sendable {
    private let geometry: LiquidGeometry
    private let look: LiquidLook
    private var selected = 0
    /// The reach last commanded, points; the next `.reach` starts here.
    private var reach = 0.0
    private var isPulled = false
    private var waves = 0

    public init(geometry: LiquidGeometry, look: LiquidLook)

    /// Settled around the selection, icon grown, nothing moving: the switcher is on screen in the same moment (R11).
    public mutating func open(_ selection: SwitcherSelection) -> [LiquidCommand] {
        // [.settle(at: selection.selected), .grow(selected: selection.selected, over: 0)]
        fatalError("not implemented")
    }

    /// The commands for one observed value. `animated` false: Reduce Motion or no mirror; only `.settle`/`.grow(over: 0)`,
    /// and only when the selection changed (R13).
    public mutating func step(_ selection: SwitcherSelection, speedMMPerS: Double, animated: Bool) -> [LiquidCommand] {
        // let crossed = selection.selected != selected
        // let lean = (selection.position − Double(selection.selected)) × pitch × look.leanShare        // R5, signed
        // let excess = overshoot of selection.travelMM past either end, step-mm, signed (0 inside the list)
        // let pull = sign(excess) × geometry.maxPull × (1 − exp(−|excess| / look.pullReachMM))         // R10's curve
        // let target = lean + pull
        // if !animated { defer { selected = …; reach = 0 }; return crossed ? [.settle, .grow(over: 0)] : [] }
        // if crossed:
        //     commands = [.flow(to:, holdingReach: target, spring: look.flow, squash: look.flowSquash),
        //                 .grow(selected:, over: look.iconGrow),
        //                 .wave(serial: waves, kicks: kicks(toward: selection.selected, speed: speedMMPerS))]
        //     waves += 1
        // else if isPulled && pull == 0: commands = [.release(from: reach, spring: look.wobble)]     // the turn back
        // else if target != reach:      commands = [.reach(from: reach, to: target, over: look.followSmoothing)]
        // selected = selection.selected; reach = target; isPulled = pull != 0
        fatalError("not implemented")
    }

    /// The wave's kicks for a crossing: amplitude = bound × (1 − exp(−|speed| / saturation)) × exp(−(d − 1) / reach),
    /// halved by `wakeShare` for beads behind the slide's direction (the sign of `speed`), delay = d / waveSpeed, for
    /// every bead but the selected one, where d is the distance in items. Every amplitude ≤ `geometry.waveBound`,
    /// whatever the speed (R8's bounds).
    private func kicks(toward selected: Int, speed: Double) -> [BeadKick] { fatalError("not implemented") }
}
```

Trace of R5 through this structure: sliding right 5 mm from the first icon makes `position − selected = 0.42`, so `.reach(to: 21)` extends the swell's right edge; the swell's left edge and the icon are untouched because the reach only adds to the width and moves the centre by half of it. Sliding back shrinks the reach event by event and leaves it at 0. R10: past the last icon `position` is clamped so the lean is 0 and the pull takes over from 0, continuous; the turn back makes `travelMM` restart at the end (C3), so the pull drops to 0 in one event and `.release` springs it back with a wobble. R6 and R7: a crossing by one or by three emits one `.flow(to:)` to the final selection; a crossing while a flow runs replaces it from the presentation. R9: every after-input motion is a `Spring` whose `settlingTime` the look bounds under one second, and resting fingers produce no events, so nothing is kicked.

**The glass and its motion live in one AppKit module.** `LiquidPanel` is an `OverlayPanel` whose content is a plain layer-backed view holding an `NSGlassEffectContainerView` and, above it, the icon layers. Twelve `.regular` glass views are created once and never added or removed: band, ten beads, swell. A row shorter than ten parks its spare beads outside the window. The private mirror is matched by frame once it exists and kept by identity (A6); the token `CASDFElementLayer` is confined to this file by the source-scan test, as the other private symbols are (B3).

```swift
// LauncherUI

/// AppKit's private mirror of each glass view: the `CASDFElementLayer` the render server merges (A1, A5). Matched by
/// frame once, since each element's resting frame is distinct, then kept by identity; nil until the mirror exists,
/// when its count differs from the views', or when any view matches no layer: a macOS change. Without it the liquid
/// moves as under Reduce Motion. The only code that names the private class; the source-scan test confines it here.
private struct GlassMirror {
    let layers: [LiquidElement: CALayer]
    static func match(_ views: [LiquidElement: NSGlassEffectView], in container: NSGlassEffectContainerView) -> GlassMirror? {
        // every layer under container.layer whose class name is "CASDFElementLayer"; count == views.count;
        // each view frame equals exactly one layer frame within 0.5 pt; else nil
        fatalError("not implemented")
    }
    /// Still AppKit's, not a stale copy: every layer still in the tree.
    var isLive: Bool { fatalError("not implemented") }
}

/// The app switcher's window: the merged glass shape and the icons over it. Plays `LiquidCommand`s; decides nothing.
/// Every per-event change is an additive animation on an element layer (held or a 12 ms tween) so AppKit's re-sync
/// never clobbers it (A6); every after-input motion is a spring the render server plays and removes when it ends
/// (R9, R16). Public view frames change only at layout, at `.settle` and at a `.flow` (one set per crossing).
final class LiquidPanel: OverlayPanel {
    private let container = NSGlassEffectContainerView()
    private let glass: [LiquidElement: NSGlassEffectView]       // twelve, fixed
    private let iconsHost = NSView()
    private var iconLayers: [CALayer] = []
    private var geometry: LiquidGeometry?
    private var mirror: GlassMirror?

    init() {
        // super.init(content: root)  — the new OverlayPanel init: no rounded glass, no roundedClip; hasShadow stays
        // true: the window-server shadow traces the merged shape and follows it (A9), and the light-over-white look
        // leans on it (A10)
        fatalError("not implemented")
    }

    /// The mirror is matched, so reach, flow and waves can play. Tries to match on every open until it does.
    var canAnimate: Bool { mirror?.isLive == true }

    /// Sets every element's resting frame for `geometry` (parked beads included), the container's spacing, one icon
    /// layer per image at `geometry.iconCentre`, centres the window on `screen`, then matches the mirror if it is not
    /// matched yet. Removes every element animation. Idempotent: a second call with the same row changes nothing.
    func layoutRow(_ images: [NSImage], geometry: LiquidGeometry, on screen: NSRect, backingScale: CGFloat) {
        fatalError("not implemented")
    }

    /// Plays `commands` in one transaction with actions disabled.
    func apply(_ commands: [LiquidCommand]) {
        // .settle(at:): swell view frame = geometry.rest(of: .swell, selected:); remove every element animation
        // .grow(selected:, over:): icon transforms, over `over` as an explicit CABasicAnimation (0: none)
        // the rest need the mirror; without it they are dropped (LiquidMotion never emits them then)
        // .reach(from:to:over:): LiquidStaging.reach(...) → two additive animations on the swell element, keys
        //     "reach.x" (position.x, from/2 → to/2) and "reach.w" (bounds.size.width, |from| → |to|), fill forwards,
        //     not removed on completion: the hold the next event replaces
        // .release(from:spring:): the same two keys as additive CASpringAnimations from `from` to 0
        // .flow(to:holdingReach:spring:squash:):
        //     let c1 = geometry.rest(of: .swell, selected: to).midX
        //     let x = swellElement.presentation()?.position.x ?? model        // where the drop is right now
        //     let w = swellElement.presentation()?.bounds.width ?? model
        //     swellView.frame = rest(.swell, to)                              // AppKit mirrors it at once (A6)
        //     hold "reach.x"/"reach.w" at holdingReach (from == to)
        //     "flow": additive CASpringAnimation position.x from (x − c1 − holdingReach/2) → 0 on `spring`
        //     "squash": additive CASpringAnimation bounds.size.width from (w − rest.width − |holdingReach|) → 0,
        //               initialVelocity = squash, on `spring`
        // .wave(serial:kicks:): LiquidStaging.wave(kicks, serial:, look:, now: convertTime(CACurrentMediaTime()))
        //     → one additive CASpringAnimation on bounds.size.height per kick, from 0 → 0, initialVelocity =
        //       amplitude / spring.peakPerUnitVelocity, beginTime = now + delay, fillMode .backwards, key
        //       "wave-\(serial % look.waveKeys)" so at most waveKeys overlap per bead
        fatalError("not implemented")
    }

    /// After the fade: every element animation removed, the swell at its rest, so nothing outlives the switcher (R16).
    override func emptied() { fatalError("not implemented") }
}

/// Commands to Core Animation objects, pure given `now`, so a test reads back keys, from/to, durations, begin times
/// and spring constants (precedent: `LaunchFlightTests`, `BounceStagingTests`).
enum LiquidStaging {
    struct Staged: Equatable { let element: LiquidElement; let key: String; let animation: CAAnimation }
    static func reach(from: Double, to: Double, over: Double) -> [Staged] { fatalError("not implemented") }
    static func release(from: Double, spring: Spring) -> [Staged] { fatalError("not implemented") }
    static func wave(_ kicks: [BeadKick], serial: Int, look: LiquidLook, now: CFTimeInterval) -> [Staged] { fatalError("not implemented") }
    static func spring(_ spring: Spring, keyPath: String) -> CASpringAnimation { fatalError("not implemented") }
}
```

`OverlayPanel` gains a second designated initializer, `init(content: NSView)`, that installs `content` as the window's content view with no glass and no clip; `init(cornerRadius:content:)` builds the rounded glass under `roundedClip` as today and calls it. `present`, `dismiss`, the fade, the generation guard and Reduce Motion's instant order-out are untouched, so the window switcher's window is byte-for-byte what it was (C6, non-goals).

**Tuning (R17, B4, B5).** `LiquidLook` lives in `LauncherCore` because both pure consumers do, and `LauncherUI` cannot see `LauncherPlatform`. `LaunchTuning` gains `var liquid = LiquidLook.shipped` so the Debug tuner's sliders bind to `\.liquid.swellRise` and friends with the machinery that exists; `LiquidLook` is `Codable` under `#if DEBUG` with the lenient decoder, and `LaunchTuning.init(from:)` gets its one line (gotcha 11). `SettingsShell` and `SwitcherPresenter` take `look: @escaping () -> LiquidLook`; the app target, the composition root, passes `{ .shipped }` in Release and `{ LaunchTuning.current.liquid }` in Debug. The presenter snapshots it once per swipe, at open.

**The per-event path and its cost (R15, A7).** Per `.moved`: `Observations` yields, `LiquidMotion.step` runs (a few multiplications), and the panel commits two additive animations on one element layer. P6 measured eleven such replacements per event at 2.5% of a core; two is well under 1%, against today's 1.08 ms per frame. Per crossing, at most about twenty a second: one public frame set (P6: about 0.25 ms per set), two swell springs, up to nine bead springs, ten icon transforms: about a millisecond. Interpolation on a 120 Hz display comes from the 12 ms reach tween, the springs and the render server's own clock, never from code of ours per display frame; the only clock we read is Core Animation's, once per crossing, to schedule the wave's propagation.

**What the public surface hides.** A caller learns four values and two methods (`open`, `step`) plus `apply`. Behind them: the SDF element set and its parking, the frame-matched private mirror and its liveness, additive-versus-model composition, continuity at a crossing (the lean becoming the flow's start), wave propagation and bounded superposition, amplitude clamps, the Reduce Motion and fallback vocabulary, and every number. What stays exposed: `animated` (the presenter owns Reduce Motion and the mirror's presence, both test handles), and `speedMMPerS` on the event.

**Requirement trace.**

| R | Carried by |
|---|---|
| R1 | `LiquidGeometry.rests` (band under every bead; one-icon row is the swell alone); `LiquidPanel` content with no rounded glass, `OverlayPanel.init(content:)` |
| R2 | `.regular` glass, no `tintColor`, `hasShadow` kept (A10); manual |
| R3 | `LiquidLook.bandHeight`, `beadSide`, `merge`; `LiquidGeometry.rest(of: .bead(i))` |
| R4 | `LiquidLook.swellRise`; `LiquidGeometry.rest(of: .swell)`; `.grow(selected:)` with `SwitcherRowLayout.selectedIconScale` |
| R5 | `LiquidCommand.reach`, `LiquidLook.leanShare`, `followSmoothing` |
| R6 | `LiquidCommand.flow` from the presentation, keyed (replaces); `Spring.firstArrival(look.flow) < 0.2`; `flowSquash` wobble |
| R7 | `LiquidMotion.step` emits one `.flow(to: selection.selected)` per observed change |
| R8 | `SwipePhase.moved(speedMMPerS:)`, `Switcher.speedMMPerS`, `LiquidMotion.kicks`, `LiquidGeometry.waveBound`, `waveKeys` |
| R9 | `Spring.settlingTime` bounded by `LiquidLook.violations`; springs removed on completion; no event, no kick |
| R10 | `LiquidGeometry.maxPull` (0.2 × pitch), `LiquidLook.pullReachMM`, `LiquidCommand.release` |
| R11 | `LiquidMotion.open` → `.settle` + `.grow(over: 0)`; `present(appear: nil)`; `OverlayPanel.dismiss` fade |
| R12 | `Launcher.swipe(.ended)` unchanged (C8); `dismiss` never waits; `emptied` drops what is left |
| R13 | `step(animated: false)`; the presenter reads Reduce Motion |
| R14 | one `SwitcherRowLayout` with `cellSide`/`padding` from the look; `LiquidGeometry.scale` on every length |
| R15 | per-event path above; manual at 120 Hz |
| R16 | nothing loops; held tweens are complete; `emptied` removes all; manual (sampler phase) |
| R17 | `LiquidLook`, `LaunchTuning.liquid`, the tuner |

**The seam tests run at** is `LiquidMotion.step` fed by `World.playFrameByFrame` observing `launcher.switcher`: real recognizer, real `Launcher`, real `SwitcherSelection`, synchronous delivery. A test drives travel and speed with `TouchScript.slide(byMM:over:)`, Reduce Motion and the mirror's absence with `animated`, and observes commands as numbers. Time is a number too: `Spring`'s closed forms and `LiquidStaging`'s `now`. `LiquidStaging` is tested in a new `LauncherUITests` target that imports QuartzCore and never opens a window. `GlassMirror.match` is covered only by a hand check and the P6 precedent. R2's look in both appearances, R15's smoothness at 120 Hz with ten apps, and R16's frames drawn are hand checks on hardware; `Scripts/perf/session.sh` gains a "fingers resting on an open switcher" phase so R16 at least shows zero wake-ups.

**What the design deliberately does not do.** It does not animate per event on every bead (the wave is kicked per crossing), does not read a clock in the presenter, does not move the window per event, does not change `SwitcherSelection`, `GestureRules`, `OverlayPanel.init(cornerRadius:content:)` or the window switcher, and does not add a port: the switcher stays rendered from observed state.

**Changes to `docs/architecture.md`, for the user to accept (017 precedent).** Two sentences, no rule change. Privacy: add "AppKit's private per-view glass element layers, matched by frame and confined to the liquid switcher's panel file; when they are missing or not as expected, the liquid moves only on input events, as under Reduce Motion" to the list of private symbols with fallbacks. Concurrency: the animation bullet's example list reads "the liquid switcher's swell on trackpad frames" in place of "the switchers' highlight on trackpad frames". The animation rule itself holds: the render server plays every flow, wobble, release and wave; no code of ours runs per display frame.

### Synthesis decision

### Tradeoffs accepted

- We accept the first dependency on another framework's private layer tree (`CASDFElementLayer`, class name looked up at runtime, matched by frame) in exchange for render-server motion of real Liquid Glass at about a tenth of the public path's CPU and full compliance with the animation rule. It is confined to one file, its absence is a tested path (the Reduce Motion vocabulary), and its loss in a macOS update degrades the look to jumps rather than breaking the switcher.
- We accept waves kicked only at selection changes rather than on every event, in exchange for a per-event path of two animations on one layer and a propagation delay that actually propagates: a per-event replacement would restart every far bead's delay before it fires.
- We accept a 12 ms reach tween that can be replaced before it ends (a sub-point step when events arrive faster than it plays) in exchange for in-between frames on 120 Hz displays without per-frame code.
- We accept changing the shared `SwipePhase.moved` case (about thirty construction and match sites, most in tests whose `phasesMatch`/`isCloseTo` compare travel only) in exchange for a speed the recognizer already has and a test can provoke through `TouchScript`.
- We accept reading `CACurrentMediaTime()` once per crossing and using `beginTime`, both new to the codebase, in exchange for ten spring objects per wave instead of thousands of keyframe samples.
- We accept the pull holding still while the fingers rest past an end (it springs back on the turn, per R10's wording and R9's "settled means not moving"), where today's band springs back while resting.
- We accept the window's padding becoming the look's `margin` (room for pull and wave) rather than the domain model's 22 pt rule, and `SwitcherRowLayout` taking its cell and padding as parameters.
- We accept twelve glass views always alive, with spares parked outside the window, in exchange for a mirror matched once per panel life rather than re-matched under time pressure at every open.

### Alternatives considered

- **All-public: `NSGlassEffectView.frame` per event plus `NSAnimationContext` or implicit springs for the after-motion.** Hides nothing from the caller that this design does not; costs 26% of a core per event path and 133 to 167 ms of in-process per-display-frame stepping per flow (A4, A7), and contradicts the animation rule unless the user rewrites it (B2). Lost on cost and on the rule.
- **SwiftUI `GlassEffectContainer` with a custom `Shape` and `withAnimation`.** One `Shape.path(in:)` per display frame, 381 to 422 ms per spring (A4); plan 006 rejected SwiftUI here on the same rule. Lost.
- **One rectangular glass masked by an animated `CAShapeLayer` path (public, render-server).** Fails R2: a flat frosted cut-out with no lensing or rim (A8). Lost on the look, which is the point.
- **The mirror with direct writes to element frames per event (P6 "elements", 2.5%).** AppKit's re-sync resets a direct write (A6), so any layout pass mid-swipe snaps the swell to its view frame; additive held animations survive at the same cost. Lost on robustness.
- **Speed estimated in the presenter from its own clock and successive `travelMM`.** No test can provoke it, `Observations` coalescing and main-queue jitter add noise, and a clock read in the presenter has no precedent; the recognizer divides two numbers it already holds. Lost on testability.
- **Glass views added and removed per row.** Churns the mirror's identity every swipe and forces a re-match before the first event, when the mirror may not exist yet. Lost to twelve fixed views with parked spares.
- **A `LauncherUI` port with a fake panel for the motion tests.** Would make the seam `LiquidPanel.apply` rather than `LiquidMotion.step`, with the motion policy and its bounds behind AppKit; a pure command vocabulary tests the same scenarios without a window and leaves the panel thin. Lost on depth.

### Open questions and risks

1. Private mirror: is a confined, frame-matched dependency on AppKit's `CASDFElementLayer` acceptable, with the Reduce Motion look as the fallback when it is missing, and are the two `docs/architecture.md` sentences above the wording you want?
2. R4 reads "12 pt beyond the band on each side"; this design makes `swellRise` the rise beyond a *bead* (so the swell is clearly bigger than a bead whatever the band's thickness). Is that the intended meaning?
3. Past an end with the fingers resting (R9 versus R10, grounding open question 5): should the pull hold until the turn, as designed, or spring back while the fingers rest, as today's band does?
4. Waves kick on selection changes with the speed at that moment; between changes only the swell's reach answers the fingers. Does that read as "fully reactive", or should a sustained fast slide inside one cell also ripple?
5. R2 light over white leans on the window-server shadow (A10). If the hardware check fails, is a faint tint the answer, or a thicker rim through `merge`?
6. Risks needing a probe before the first slice: (a) whether the mirror exists before the panel is first ordered front, else the first event of the first swipe plays as a settle; (b) whether parked beads outside the window leave the union byte-identical, else `isHidden` on the spare views; (c) whether the window-server shadow keeps up during a fast flow, else `hasShadow = false` and question 5 comes back; (d) whether a completed fill-forward additive animation costs render work at rest (R16), else the hold is re-expressed as a from == to spring of zero duration.
7. The shipped numbers in `LiquidLook` are starting points for the tuner, not measurements; the look is settled on hardware by you, as plan 004 and 017 were.

### Next implementation step

Scaffold `LiquidLook`, `Spring` and `LiquidGeometry` in `LauncherCore` with their tests (the look's invariants, the springs' bounds, the rests and the parking), then write the first `LiquidMotion` test through `World.playFrameByFrame` for R5's 5 mm lean and let it drive the state machine.
