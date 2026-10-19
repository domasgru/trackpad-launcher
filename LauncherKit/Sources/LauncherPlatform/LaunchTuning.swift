import Foundation
import LauncherCore

/// Every number that shapes a launch flight and a launch bounce, plus the switcher's swipe acceleration, which the same tuner tweaks. `shipped` is the animation release builds play; Debug builds can
/// override it live from the animation tuner (AnimationTuner.swift).
struct LaunchTuning: Equatable, Sendable {
    /// The icon's start side, in points.
    var iconSide: Double = 60
    /// Seconds from appearing to fully invisible.
    var duration: Double = 0.34
    /// How much bigger the icon swells right after it appears, as a share of its start side. 0 = no pop.
    var popSize: Double = 0.2
    /// Seconds the swell takes to reach its peak, easing out. The flight (rise, shrink, sway, tilt, fade) starts
    /// from the peak and plays in what is left of the duration.
    var popTime: Double = 0.075
    /// Points the icon rises by the end.
    var rise: Double = 70
    /// Rise = rise × t^riseCurve. 1 is constant speed, above 1 accelerates.
    var riseCurve: Double = 1.8
    /// The share of its peak side the icon loses by the end.
    var shrink: Double = 0.55
    /// Side = peak × (1 − shrink × t^shrinkCurve). Below 1 shrinks early, above 1 late.
    var shrinkCurve: Double = 1.4
    /// Opacity = 1 − t^fadeCurve. Higher stays opaque longer.
    var fadeCurve: Double = 4
    /// Sideways drift per point of rise at the end, for the largest sway. Below a third, so the drift never
    /// outgrows the rise.
    var maximumSway: Double = 0.26
    /// The smallest sway, as a share of the maximum, so every moving flight veers.
    var minimumSway: Double = 0.1
    /// Drift = sway × rise(t) × t^swayCurve. Higher veers later.
    var swayCurve: Double = 1.8
    /// The end tilt of the largest sway, in degrees.
    var maximumTilt: Double = 4
    /// Tilt = tilt × t^tiltCurve.
    var tiltCurve: Double = 1
    /// Plays the Reduce motion flight whatever the system setting. Only the tuner sets it.
    var forceReduceMotion = false
    /// Switcher swipes move like the cursor, with macOS's acceleration; off, one millimetre of finger is one of travel.
    var swipeFollowsCursor = true
    /// Cursor points of travel per step. The icon pitch makes the highlight move exactly like the cursor over the row.
    var swipePointsPerStep = SwipeTravel.shippedPointsPerStep
    /// The tracking speed swipes use, 0...3; −1 uses System Settings' value.
    var swipeTrackingSpeed = -1.0

    /// The launch bounce's numbers.
    var bounce = Bounce()

    static let shipped = LaunchTuning()

    #if DEBUG
    /// The tuning flights read now: the tuner's while it is open, `shipped` otherwise.
    static var current: LaunchTuning { tunerOverride.withLock { $0 } }
    #else
    static var current: LaunchTuning { shipped }
    #endif
}

#if DEBUG
extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, or fallback: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback
    }
}

/// The tuner saves tunings as JSON. Keys missing from an older save keep their shipped values.
extension LaunchTuning: Codable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let s = LaunchTuning.shipped
        self.init()
        iconSide = try c.decode(.iconSide, or: s.iconSide)
        duration = try c.decode(.duration, or: s.duration)
        popSize = try c.decode(.popSize, or: s.popSize)
        popTime = try c.decode(.popTime, or: s.popTime)
        rise = try c.decode(.rise, or: s.rise)
        riseCurve = try c.decode(.riseCurve, or: s.riseCurve)
        shrink = try c.decode(.shrink, or: s.shrink)
        shrinkCurve = try c.decode(.shrinkCurve, or: s.shrinkCurve)
        fadeCurve = try c.decode(.fadeCurve, or: s.fadeCurve)
        maximumSway = try c.decode(.maximumSway, or: s.maximumSway)
        minimumSway = try c.decode(.minimumSway, or: s.minimumSway)
        swayCurve = try c.decode(.swayCurve, or: s.swayCurve)
        maximumTilt = try c.decode(.maximumTilt, or: s.maximumTilt)
        tiltCurve = try c.decode(.tiltCurve, or: s.tiltCurve)
        forceReduceMotion = try c.decode(.forceReduceMotion, or: s.forceReduceMotion)
        swipeFollowsCursor = try c.decode(.swipeFollowsCursor, or: s.swipeFollowsCursor)
        swipePointsPerStep = try c.decode(.swipePointsPerStep, or: s.swipePointsPerStep)
        swipeTrackingSpeed = try c.decode(.swipeTrackingSpeed, or: s.swipeTrackingSpeed)
        bounce = try c.decode(.bounce, or: s.bounce)
    }
}

extension LaunchTuning.Bounce: Codable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let s = LaunchTuning.Bounce()
        self.init()
        height = try c.decode(.height, or: s.height)
        timeUp = try c.decode(.timeUp, or: s.timeUp)
        timeDown = try c.decode(.timeDown, or: s.timeDown)
        rest = try c.decode(.rest, or: s.rest)
        squash = try c.decode(.squash, or: s.squash)
        gap = try c.decode(.gap, or: s.gap)
        offset = try c.decode(.offset, or: s.offset)
        trailing = try c.decode(.trailing, or: s.trailing)
        spacing = try c.decode(.spacing, or: s.spacing)
        fadeOut = try c.decode(.fadeOut, or: s.fadeOut)
        slide = try c.decode(.slide, or: s.slide)
        pulseLow = try c.decode(.pulseLow, or: s.pulseLow)
        pulsePeriod = try c.decode(.pulsePeriod, or: s.pulsePeriod)
        style = try c.decode(.style, or: s.style)
        inflateFrom = try c.decode(.inflateFrom, or: s.inflateFrom)
        inflateTime = try c.decode(.inflateTime, or: s.inflateTime)
        inflateCurve = try c.decode(.inflateCurve, or: s.inflateCurve)
        creep = try c.decode(.creep, or: s.creep)
        creepTime = try c.decode(.creepTime, or: s.creepTime)
    }
}
#endif

extension LaunchTuning {
    /// Every number that shapes a launch bounce. The defaults are the shipped bounce.
    struct Bounce: Equatable, Sendable {
        /// The motion while the app starts up. The tuner switches between them, to pick one to ship.
        enum Style: String, CaseIterable, Codable, Sendable {
            /// A Dock-like jump, over and over.
            case jump
            /// A balloon inflating: from small to the icon's side, then on, ever slower.
            case inflate
        }

        var style: Style = .inflate
        /// Points the icon jumps: about half the icon.
        var height: Double = 30
        var timeUp: Double = 0.30
        var timeDown: Double = 0.30
        /// Seconds on the ground between jumps.
        var rest: Double = 0.10
        /// Share of its height the icon loses on landing, widening to keep its area. 0 = none.
        var squash: Double = 0
        /// Points between the pointer's tip and the icons' bottoms at rest.
        var gap: Double = 8
        /// Sideways from the tip to the row's centre.
        var offset: Double = 0
        /// Seconds the row takes to catch up with the pointer. 0 = glued to it.
        var trailing: Double = 0
        /// Points between icons in the row.
        var spacing: Double = 12
        /// Seconds of the quiet fade.
        var fadeOut: Double = 0.2
        /// Seconds the others take to slide when one ends.
        var slide: Double = 0.2
        /// Reduce motion: the pulse's dimmest opacity, and its period in seconds.
        var pulseLow: Double = 0.5
        var pulsePeriod: Double = 1.4
        /// Inflate: the icon's side when it appears, in points.
        var inflateFrom: Double = 24
        /// Inflate: seconds to grow to the icon's side.
        var inflateTime: Double = 0.4
        /// Inflate: the easing. The growth's speed falls as (1 + t/τ)^−inflateCurve, smoothly, with no stop at the icon's
        /// side. Low: a quick puff, then a long slow swell. High: rounder, and it settles sooner.
        var inflateCurve: Double = 2
        /// Inflate: the share of its side the icon has grown by past the icon's side when it stops.
        var creep: Double = 0.4
        /// Inflate: seconds from reaching the icon's side to stopping; the icon then holds its size.
        var creepTime: Double = 5
    }
}
