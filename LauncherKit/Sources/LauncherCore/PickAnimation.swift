import Foundation

/// The pick animation: an app picker's icon growing into place when the user picks an app in it. It starts at
/// `startScale` of its side, grows to `peakScale` in `growTime` starting fast and slowing like the launch animation's
/// pop, then settles back to 100% over `settleTime`, at rest at the peak and at 100% so there is no second wobble.
public struct PickAnimation: Equatable, Sendable {
    /// Share of the icon's side at the pick.
    public var startScale: Double
    /// Share of the icon's side at the top of the grow.
    public var peakScale: Double
    /// Seconds from the pick to the peak.
    public var growTime: Double
    /// Seconds from the peak to rest.
    public var settleTime: Double

    public init(startScale: Double, peakScale: Double, growTime: Double, settleTime: Double) {
        self.startScale = startScale
        self.peakScale = peakScale
        self.growTime = growTime
        self.settleTime = settleTime
    }

    public static let shipped = PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.2, settleTime: 0.15)

    /// Seconds from the pick to rest.
    public var duration: Double { growTime + settleTime }

    /// The icon's side as a share of its resting side, `t` seconds after the pick.
    public func scale(at t: Double) -> Double {
        // Sampled times can land a hair off a boundary; the peak and the rest must come out exact.
        let t = [growTime, duration].first { abs(t - $0) < 1e-9 } ?? t
        if t <= 0 { return startScale }
        if t < growTime {
            let p = t / growTime
            return startScale + (peakScale - startScale) * (1 - (1 - p) * (1 - p))
        }
        if t < duration {
            let q = (t - growTime) / settleTime
            return peakScale + (1 - peakScale) * (3 * q * q - 2 * q * q * q)
        }
        return 1
    }

    /// The curve sampled for Core Animation: key times as shares of the duration, scales alongside. At least ten
    /// steps, like the launch animation's sampling.
    public func keyframes(perSecond: Double) -> (keyTimes: [Double], scales: [Double]) {
        let steps = max(10, Int((duration * perSecond).rounded()))
        let keyTimes = (0...steps).map { Double($0) / Double(steps) }
        return (keyTimes, keyTimes.map { scale(at: $0 * duration) })
    }
}
