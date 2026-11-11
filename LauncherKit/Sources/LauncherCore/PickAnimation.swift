import Foundation

/// The pick animation: an app picker's icon jumping into place from below when the user picks an app in it. It starts
/// at `startScale` of its side, `rise` points below its place, and grows from its bottom edge to `peakScale` in
/// `growTime`, starting fast and slowing, while it rises; it then settles back to 100% over `settleTime`, at rest at the
/// peak and at 100% so there is no second wobble. The rise follows the grow, so as the icon overshoots its size it
/// overshoots its place by the same share, then settles down into it.
public struct PickAnimation: Equatable, Sendable {
    /// Share of the icon's side at the pick.
    public var startScale: Double
    /// Share of the icon's side at the top of the grow.
    public var peakScale: Double
    /// Seconds from the pick to the peak.
    public var growTime: Double
    /// Seconds from the peak to rest.
    public var settleTime: Double
    /// Points the icon's bottom edge starts below its resting place.
    public var rise: Double

    public init(startScale: Double, peakScale: Double, growTime: Double, settleTime: Double, rise: Double) {
        self.startScale = startScale
        self.peakScale = peakScale
        self.growTime = growTime
        self.settleTime = settleTime
        self.rise = rise
    }

    public static let shipped = PickAnimation(
        startScale: 0.5, peakScale: 1.08, growTime: 0.25, settleTime: 0.2, rise: 6)

    /// Seconds from the pick to rest.
    public var duration: Double { growTime + settleTime }

    /// The icon's side as a share of its resting side, `t` seconds after the pick.
    public func scale(at t: Double) -> Double {
        // Sampled times can land a hair off a boundary; the peak and the rest must come out exact.
        let t = [growTime, duration].first { abs(t - $0) < 1e-9 } ?? t
        if t <= 0 { return startScale }
        if t < growTime {
            // An ease-out cubic: a quick jump that slows into the peak.
            let p = 1 - t / growTime
            return startScale + (peakScale - startScale) * (1 - p * p * p)
        }
        if t < duration {
            let q = (t - growTime) / settleTime
            return peakScale + (1 - peakScale) * (3 * q * q - 2 * q * q * q)
        }
        return 1
    }

    /// Points the icon's bottom edge sits below its resting place, `t` seconds after the pick; negative above it. It
    /// follows the scale: `rise` at the start, 0 at 100%, and above its place while the icon is bigger than it rests.
    public func drop(at t: Double) -> Double {
        guard startScale != 1 else { return t <= 0 ? rise : 0 }
        return rise * (1 - scale(at: t)) / (1 - startScale)
    }

    /// The curve sampled for Core Animation: key times as shares of the duration, scales and drops alongside. At least
    /// ten steps, like the launch animation's sampling.
    public func keyframes(perSecond: Double) -> (keyTimes: [Double], scales: [Double], drops: [Double]) {
        let steps = max(10, Int((duration * perSecond).rounded()))
        let keyTimes = (0...steps).map { Double($0) / Double(steps) }
        return (keyTimes, keyTimes.map { scale(at: $0 * duration) }, keyTimes.map { drop(at: $0 * duration) })
    }
}
