# S2a: The launch bounce's pure parts: vocabulary, row geometry, motion, report gate, tuning knobs

(Slice S2 of the plan is built in two dispatches, S2a then S2b, committed together. This one builds every pure value the bounce needs and its tests. S2b wires them into the model, the port and the adapter. Build nothing from S2b here: no `SystemActions` change, no `Launcher` change, no panel, no watch.)

## Goal

The launch bounce is coming: when a gesture fires for an app that is not running, the app's icon bounces just above the pointer, like the Dock's bounce, until the app's window shows; then it plays the launch animation from wherever it is, or fades out in place when the launch goes nowhere. This slice builds, as pure and tested values: the model's vocabulary for a bounce's progress and ending (`LauncherCore`); the row geometry (`BounceRow`), the motion keyframes (`BounceMotion`) and the per-bounce report gate (`LaunchReportGate`) in `LauncherPlatform`; and the bounce's tuning knobs on `LaunchTuning`.

## Requirements

- **R4.** The bouncing icon MUST be the target app's own icon, the same size as the launch animation's icon: 60 × 60 points as shipped. It MUST show no blur or pixelation at any point of the bounce.
- **R5.** (single icon, except as R6 and R13 say) At rest, between jumps, the icon MUST sit centred horizontally on the pointer's tip, its bottom edge 8 points above the tip. It MUST jump upward from there and never cover the pointer.
- **R6.** The icon, or the whole row of icons (R13), MUST always rest and bounce above the pointer, wherever the pointer is. Near the top edge, the part that does not fit MUST be cut off by the edge; the icon MUST NOT move below the pointer or onto another display. Near the left or right edge, it MUST slide sideways just enough to stay entirely on the pointer's display. Scenario: pointer's tip 10 points from the right edge → the icon is entirely on the display, its right edge at the display's edge.
- **R8.** Each bounce MUST rise quickly to about half the icon's height, slow at the top, and fall back with gravity, about 0.7 seconds per bounce, repeated until the bounce ends. With the shipped tuning the icon MUST keep its size and shape while it bounces; the tuner may set squash for experiments.
- **R11 (the fade's shape).** On a quiet end the icon MUST fade out in place within about 0.2 seconds.
- **R13 (geometry).** Bouncing icons MUST sit in one row centred above the pointer, newest on the right, 12 points apart. When one ends, the others MUST slide to their new places over about 0.2 seconds.
- **R15 (motion).** With the system's Reduce motion setting on, the icon MUST stay at its resting spot above the pointer and gently pulse its opacity instead of bouncing.
- **R17 (knobs' effects).** Knobs for: the jump height, the time up, the time down, the rest between bounces, the squash on landing (none by default), the resting gap above the pointer, the horizontal offset from the pointer, trailing behind the pointer (none by default), the gap between icons, and the fade out on a quiet end. (The tuner UI is a later slice; here each knob must shape what it names.)
- **R9–R12 (report contract, for the gate).** A launch reports "finished launching" at most once, then at most one terminal fact (window shown, went nowhere, ran out), then nothing.

## Design

### `LauncherCore` · launch bounce vocabulary (new file, e.g. `Sources/LauncherCore/LaunchBounce.swift`)

```swift
/// What the adapter learned about a launch a gesture started, pushed while its launch bounce plays.
public enum LaunchProgress: Equatable, Sendable {
    /// macOS reports the app finished launching; menu bar apps too (key-value observation).
    case finishedLaunching
    /// A window of the app is on screen, on any display; a splash screen counts (R9).
    case windowShown
    /// macOS could not launch it, or its process ended before the bounce did (R11).
    case wentNowhere
    /// The bounce reached a time limit: its cap, or the limit set once the app finished launching.
    case ranOut
}

/// How a launch bounce ends.
public enum LaunchBounceEnding: Equatable, Sendable {
    /// The launch animation, from wherever the icon is at that moment, even mid-jump (R9, R10, R12).
    case launchAnimation
    /// A fade in place, about 0.2 s, with no launch animation (R11).
    case quietFade
}

/// One app's launch bounce as the model sees it: how far its launch has got, as far as the ending depends on it.
/// A bounce that ended is absent from `Launcher.bounces`, so a late report finds nothing and plays nothing (R12).
enum LaunchBounce: Equatable, Sendable {
    case startingUp
    case startedUp

    /// No bounce lasts longer than this after its gesture fired (R12).
    static let cap = Duration.seconds(10)
    /// Once its app finished launching, how long a bounce waits for a window (R10).
    static let grace = Duration.seconds(2)

    enum Step: Equatable, Sendable {
        case carryOn
        /// The bounce becomes `.startedUp` and now runs out within `limit` at the latest.
        case startUp(limit: Duration)
        case end(LaunchBounceEnding)
    }

    /// R9–R12 as one total table.
    func next(after progress: LaunchProgress) -> Step {
        // (_, .windowShown)                  -> .end(.launchAnimation)              R9
        // (_, .wentNowhere)                  -> .end(.quietFade)                    R11
        // (.startingUp, .finishedLaunching)  -> .startUp(limit: Self.grace)         R10
        // (.startedUp, .finishedLaunching)   -> .carryOn                            a repeat changes nothing
        // (.startingUp, .ranOut)             -> .end(.quietFade)                    R11, R12: still starting
        // (.startedUp, .ranOut)              -> .end(.launchAnimation)              R10 limit, or R12 cap
    }
}
```

Write `next(after:)` as an exhaustive `switch` over `(self, progress)` with no `default`, so a new case is a compile error. `LaunchBounce` is internal; S2b's `Launcher` uses it. (No model tests here: S2b tests it through `World`. A tiny direct table test is welcome but not required.)

### `LauncherPlatform` · `LaunchReportGate` (pure; put it in `WorkspaceActions.swift`, where S2b uses it)

```swift
/// What may still be reported for one bounce: `.finishedLaunching` at most once, then exactly one of the others, then
/// nothing. Pure; it makes `onLaunchProgress`'s contract true whoever receives the reports.
struct LaunchReportGate: Equatable {
    private var hasFinished = false
    private var hasEnded = false
    mutating func admits(_ progress: LaunchProgress) -> Bool
    // guard !hasEnded else { return false }
    // .finishedLaunching: admit once (hasFinished)
    // .windowShown, .wentNowhere, .ranOut: hasEnded = true; admit
}
```

### `LauncherPlatform` · `LaunchTuning.Bounce` (in `LaunchTuning.swift`)

`LaunchTuning` gains a stored `var bounce = Bounce()`.

```swift
extension LaunchTuning {
    /// Every number that shapes a launch bounce. The defaults are the shipped bounce.
    struct Bounce: Equatable, Sendable {
        /// Points the icon jumps: about half the icon (R8).
        var height: Double = 30
        var timeUp: Double = 0.30
        var timeDown: Double = 0.30
        /// Seconds on the ground between jumps.
        var rest: Double = 0.10
        /// Share of its height the icon loses on landing, widening to keep its area. 0 = none (R8).
        var squash: Double = 0
        /// Points between the pointer's tip and the icons' bottoms at rest (R5).
        var gap: Double = 8
        /// Sideways from the tip to the row's centre (R5: none).
        var offset: Double = 0
        /// Seconds the row takes to catch up with the pointer. 0 = glued to it (R7).
        var trailing: Double = 0
        /// Points between icons in the row (R13).
        var spacing: Double = 12
        /// Seconds of the quiet fade (R11).
        var fadeOut: Double = 0.2
        /// Seconds the others take to slide when one ends (R13).
        var slide: Double = 0.2
        /// Reduce motion: the pulse's dimmest opacity, and its period in seconds (R15).
        var pulseLow: Double = 0.5
        var pulsePeriod: Double = 1.4
    }
}
```

- `LaunchTuning` is `Codable` in `#if DEBUG` with a hand-written tolerant `init(from:)`. To keep it compiling, give `Bounce` a plain synthesized `Codable` conformance inside `#if DEBUG` now. Do **not** add the tolerant `Bounce.init(from:)` or a `bounce` line to `LaunchTuning.init(from:)`: a later slice (S5) does that with its own tests. Until then a saved tuning decodes with the shipped bounce, which is correct.
- Update `LaunchTuning`'s doc comment, which today says it holds every number of a launch flight plus the swipe's, to say it holds the launch bounce's too.

### `LauncherPlatform` · bounce staging (new file, e.g. `Sources/LauncherPlatform/BounceStaging.swift`; pure, tested like `LaunchFlight`)

```swift
/// Where the bouncing icons rest for a pointer: one row, newest on the right, `spacing` apart, centred on the pointer's
/// tip plus `offset`, bottoms `gap` above the tip (R5, R13). It slides sideways just enough to stay on the pointer's
/// display and never moves down, so the top edge cuts it (R6). Pixel-snapped to the display.
struct BounceRow: Equatable {
    let display: LaunchDisplay
    /// Each icon's bottom centre, global y-up, in row order.
    let rests: [CGPoint]

    /// Nil with no display. The display is AppKit's rule for the pointer, shared with the flight.
    init?(count: Int, pointer: CGPoint, among displays: [LaunchDisplay], side: CGFloat, tuning: LaunchTuning.Bounce)

    /// The re-flow: an additive position animation from `old − new` to zero over `duration`, easing out; nil when the
    /// rest did not move. Additive, so pointer moves during the slide compose with it.
    static func slide(from old: CGPoint, to new: CGPoint, over duration: CFTimeInterval) -> CABasicAnimation?
}

/// One launch bounce's motion, which Core Animation repeats forever: a Dock-like jump on `transform` about the icon's
/// bottom centre, or under Reduce motion an opacity pulse in place (R8, R15). 240 samples a second; starts at rest.
struct BounceMotion {
    init(tuning: LaunchTuning.Bounce, side: CGFloat, reduceMotion: Bool)
    /// timeUp + timeDown + rest, or the pulse period.
    var period: CFTimeInterval { get }
    /// `repeatCount = .infinity`, `calculationMode = .linear`, easing baked into the samples, as in `LaunchFlight`.
    func animations() -> [CAKeyframeAnimation]
    /// The quiet end: opacity from `opacity` to 0 over `tuning.fadeOut`, easing out (R11).
    func quietFade(from opacity: Float) -> CABasicAnimation
}
```

Details the plan fixes:

- `BounceRow`:
  - The display is `LaunchDisplay.containing(pointer, among: displays)` (S1 built it). Nil when there is none.
  - Row width = `count × side + (count − 1) × spacing`. Its centre is `pointer.x + offset`. Rests are the icons' bottom centres, oldest at the left, newest at the right. Every rest's y is `pointer.y + gap` (never moved vertically, even when that is above the display's top: the display's top edge cuts the icon off, R6).
  - Slide the whole row sideways only as much as needed so its left edge ≥ `display.frame.minX` and its right edge ≤ `display.frame.maxX`; spacing unchanged.
  - Pixel-snap every coordinate to the display's scale (`(v × scale).rounded() / scale`), as `LaunchFlight.staged` snaps its start.
  - The display is the pointer's display even when the rests lie above it, inside a display arranged above.
- `BounceRow.slide`: `CABasicAnimation(keyPath: "position")`, `isAdditive = true`, `fromValue = old − new`, `toValue = .zero`, `duration`, ease-out timing function. Nil when `old == new`.
- `BounceMotion`, Reduce motion off: one cycle = up for `timeUp` easing out to `height` (fast rise, slowing at the top: speed falls throughout), then down for `timeDown` with gravity (speed grows throughout), then `rest` on the ground. The cycle starts at the ground and leaves it at once (first sample at lift 0, off the ground within 20 ms). Samples 240 per second over one period; `CAKeyframeAnimation` on `"transform"` with `keyTimes` over 0…1, `duration = period`, `repeatCount = .infinity`, `calculationMode = .linear`. The transform is a vertical translation by the lift composed with a scale; the icon layer's `anchorPoint` will be its bottom centre (S2b sets that), so scale keeps the bottom fixed. With `squash > 0`, during the rest phase the icon squashes on landing to height factor `1 − squash` and width factor `1 / (1 − squash)` (area kept) and recovers, bottom staying at rest; with `squash == 0`, every sample's scale is exactly 1. The lift is never negative.
- `BounceMotion`, Reduce motion on: no transform at all (or identity at every sample); an `"opacity"` keyframe animation pulsing between 1 and `pulseLow` once every `pulsePeriod`, forever, starting at 1.
- `quietFade(from:)`: `CABasicAnimation(keyPath: "opacity")` from `opacity` to 0 over `fadeOut`, ease-out, never rising. Nothing moves.
- `side` is the icon's side (`LaunchTuning.iconSide`, 60 shipped). The bitmap is the overlay's prepared 72 pt one, so at the shipped tuning it is never upscaled (R4); that is S2b's concern.
- Keep samples and easing in pure functions so tests can read the keyframes back (as `LaunchFlightTests` decodes `LaunchStage` keyframes; reuse its `LaunchDisplay.builtIn` / `.external` fixtures).

## Rules that apply

- `docs/architecture.md`, Shape: "`LauncherCore` (domain types, pure policy, ports, the model; imports Foundation and Observation only)". The vocabulary file imports Foundation only; `SourcePolicyTests.coreImportsOnlyFoundationAndObservation` checks it. Animation geometry lives in `LauncherPlatform`.
- `docs/architecture.md`, Shape: "Policy lives in pure functions and value types". `LaunchBounce.next(after:)`, `BounceRow`, `BounceMotion` and `LaunchReportGate` are pure values with no AppKit state.
- `docs/architecture.md`, Concurrency: "Animation is Core Animation keyframes, which the render server plays … No code of ours runs per display frame, and display links are banned along with timers." The source scan bans the substrings `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` anywhere under `LauncherKit/Sources`, comments included. Do not name anything with those substrings (e.g. no `BounceTimer`).
- `docs/architecture.md`, Concurrency: "`LauncherCore` and `LauncherPlatform` are nonisolated by default".
- `docs/architecture.md`, Concurrency: "Developer tools live in `#if DEBUG` and never ship … `LaunchTuning`, whose defaults are the shipped launch animation and launch bounce." Release reads `LaunchTuning.shipped`.
- `docs/domain-model.md`, Launch bounce: "The icon is the launch animation's, 60 × 60 points … At rest it sits centred on the pointer's tip, its bottom edge 8 points above it. It jumps about half its height, slows at the top and falls back with gravity, about once every 0.7 seconds, like the Dock's bounce … Near the left or right edge it slides just enough to stay on the pointer's display; the display's top edge cuts it off, and it never moves below the pointer. Several launches bounce side by side in one row above the pointer, newest on the right, 12 points apart, and when one ends the others slide to their new places." Use the glossary's words in names and comments: *launch bounce*, *launch animation*.

## Tests

Pure units in `LauncherPlatformTests` (keyframes read back and requirement bounds asserted, not formulas, as in `LaunchFlightTests.swift`; fixture displays `LaunchDisplay.builtIn` 1512 × 982 @2x at origin and `.external` 2560 × 1440 @1x at (−524, 982)):

| ID | Requirements | Seam | Given / When / Then | Source of truth |
|----|--------------|------|---------------------|-----------------|
| T14 | R5 | `BounceRow` | Given the shipped tuning, side 60, the built-in display (1512 × 982 @2x) and the pointer at (700, 400). When the count is 1. Then the rest (bottom centre) is (700, 408): centred on the tip, its bottom 8 pt above it. | R5 literal 8 pt and its scenario |
| T15 | R13 | `BounceRow` | Given the pointer at (700, 400). When the count is 2, then 5 (five gestures, so at most five bounces). Then two icons rest at (664, 408) and (736, 408): 12 pt between their edges, centred on the tip, the newest on the right. Five icons are centred on 700, 72 pt apart, every bottom at 408. | R13 literal 12 pt; R4 60 pt |
| T16 | R6 | `BounceRow` | Given the built-in display with the external one above it. When the tip is 10 pt from the right edge (x 1502), Then the icon's right edge is 1512. At x 1482, exactly half an icon in, it is not slid; at x 1483 it slides 1 pt. With the tip 10 pt from the left edge, the left edge is 0. Five icons at x 1502 slide as one, the rightmost edge at 1512, spacing unchanged. With the tip on the menu bar (y 970 and y 981), the rests sit at tip + 8 above the display's top, so the edge cuts them, and the display is the built-in one, never the one above. In every case `rest.y == tip.y + 8`. | R6 scenarios; literals 10 pt and 8 pt |
| T17 | R6, R7 | `BounceRow` | Given the pointer on the external 1x display at (1000, 2000), Then the display is the external one and the rest is (1000, 2008), integral. Given (700.3, 400.2) on the built-in @2x display, Then every coordinate is a multiple of 0.5. With no displays, the init returns nil. | `LaunchFlightTests` fixture displays; R7 |
| T18 | R13 | `BounceRow.slide` | Given the old rest (664, 408), the new rest (700, 408) and 0.2 s. Then an additive position animation whose presented point is the old rest at 0 s and the new rest at 0.2 s, easing out. Identical rests give nil. | R13 "over about 0.2 seconds" |
| T19 | R8, R4, R5 | `BounceMotion` | Given the shipped tuning, side 60, Reduce motion off. Then one cycle lasts 0.65–0.75 s and repeats forever. The first sample is on the ground, and the icon is off it within 20 ms. The top is 27–33 pt, reached by a rise whose speed falls throughout (slow at the top), followed by a fall whose speed grows throughout (gravity), then ground. At every sample the scale is 1 (60 × 60, shape kept) and the lift is ≥ 0, so with T14 the icon never covers the tip. | R8 "about half the icon's height", "about 0.7 seconds"; R4; R5 |
| T20 | R8, R17 | `BounceMotion` | Given squash 0.2, Then on landing the icon is 0.8 of its height and 1.25 of its width (area kept), its bottom still at rest. Given squash 0, Then no sample differs from 60 × 60. | R8 "keep its size and shape" as shipped; R17 squash "none by default" |
| T21 | R15 | `BounceMotion` | Given Reduce motion on. Then no sample lifts, scales or moves the icon, and its opacity stays within 0.5–1, pulsing once every 1.4 s, forever. | R15; shipped `pulseLow` and `pulsePeriod` |
| T22 | R11, R15 | `BounceMotion.quietFade(from:)` | Given a presentation opacity of 1, 0.73 or 0.5. Then the opacity starts there, reaches 0 at 0.2 s and never rises, and nothing moves. | R11 "fade out in place within about 0.2 seconds" |
| T23 | R17 | `BounceRow`, `BounceMotion` | Each knob set away from its shipped value moves what it names and nothing else: `height` 50 gives a 50 pt top; `timeUp` 0.5 puts the top at 0.5 s; `timeDown` 0.5 makes the fall last 0.5 s; `rest` 0.3 gives 0.3 s on the ground; `gap` 20 puts the bottom 20 pt above the tip; `offset` 15 centres the row 15 pt right of the tip; `spacing` 20 puts 20 pt between icons; `fadeOut` 0.5 makes the fade last 0.5 s; `slide` 0.4 makes the slide last 0.4 s; `pulseLow` and `pulsePeriod` set the pulse's range and period. (Squash is T20; trailing is a later slice.) | R17's list; the values the row sets |
| T51 | R9, R10, R11, R12 | `LaunchReportGate` | Fed `[.finishedLaunching, .finishedLaunching, .windowShown, .windowShown, .ranOut, .wentNowhere]`, it admits `[.finishedLaunching, .windowShown]`. Fed `[.ranOut, .finishedLaunching, .windowShown]`, it admits `[.ranOut]`. Each of `.windowShown`, `.wentNowhere` and `.ranOut` is admitted alone, and nothing after it. | Port contract: "`.finishedLaunching` at most once, then at most one of the others" |

## Starting point

S1 (committed) built: `ScreenRead` (pointer + displays, `ScreenRead.now()`) and `LaunchDisplay.containing(_:among:)`, both in `LaunchFlight.swift`; `LaunchOverlay.play(for:from:among:)`; internal `LaunchOverlay.bitmap(for:scale:)` and `makePanel(frame:)`; the set-valued `Confined.onlyIn` in `SourcePolicyTests`; a test-only `LaunchProbe` executable (`LauncherKit/Tests/LaunchProbe/main.swift`) and `ProbeBundles.withProbes { … }` in `LauncherPlatformTests` (not needed in this slice). The suite had 583 tests after S1.

## Done when

- [ ] The launch bounce vocabulary (`LaunchProgress`, `LaunchBounceEnding`, `LaunchBounce` with its `Step` table) exists in `LauncherCore` as designed.
- [ ] `LaunchReportGate`, `BounceRow` (with `slide`) and `BounceMotion` (with `quietFade`) exist as designed and pass T14–T23 and T51.
- [ ] `LaunchTuning.Bounce` carries the shipped defaults, and `LaunchTuning` has `var bounce = Bounce()`; Debug decoding of older saves still works.
- [ ] The quick gate is green: `Scripts/test.sh` (runs `swift test` in `LauncherKit`).
