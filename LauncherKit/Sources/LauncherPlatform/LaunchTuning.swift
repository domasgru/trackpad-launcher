import Foundation

/// Every number that shapes a launch flight. `shipped` is the animation release builds play; Debug builds can
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

    static let shipped = LaunchTuning()

    #if DEBUG
    /// The tuning flights read now: the tuner's while it is open, `shipped` otherwise.
    static var current: LaunchTuning { tunerOverride.withLock { $0 } }
    #else
    static var current: LaunchTuning { shipped }
    #endif
}

#if DEBUG
/// The tuner saves tunings as JSON. Keys missing from an older save keep their shipped values.
extension LaunchTuning: Codable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        let s = LaunchTuning.shipped
        self.init()
        iconSide = try value(.iconSide, s.iconSide)
        duration = try value(.duration, s.duration)
        popSize = try value(.popSize, s.popSize)
        popTime = try value(.popTime, s.popTime)
        rise = try value(.rise, s.rise)
        riseCurve = try value(.riseCurve, s.riseCurve)
        shrink = try value(.shrink, s.shrink)
        shrinkCurve = try value(.shrinkCurve, s.shrinkCurve)
        fadeCurve = try value(.fadeCurve, s.fadeCurve)
        maximumSway = try value(.maximumSway, s.maximumSway)
        minimumSway = try value(.minimumSway, s.minimumSway)
        swayCurve = try value(.swayCurve, s.swayCurve)
        maximumTilt = try value(.maximumTilt, s.maximumTilt)
        tiltCurve = try value(.tiltCurve, s.tiltCurve)
        forceReduceMotion = try value(.forceReduceMotion, s.forceReduceMotion)
    }
}
#endif
