import Foundation

/// The pick animation: an app picker's icon jumping into place from below when the user picks an app in it. It starts
/// at `startScale` of its side, `rise` points below its place, and grows from its bottom edge to `peakScale` in
/// `growTime` on `growCurve` while it rises; it then settles back to 100% over `settleTime` on `settleCurve`. The
/// shipped curves start the grow fast and slow it into the peak, and rest at the peak and at 100% so there is no second
/// wobble. The rise follows the grow, so as the icon overshoots its size it
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
    /// Progress from the start to the peak over the grow.
    public var growCurve: CubicCurve
    /// Progress from the peak to rest over the settle.
    public var settleCurve: CubicCurve

    public init(
        startScale: Double, peakScale: Double, growTime: Double, settleTime: Double, rise: Double,
        growCurve: CubicCurve = .easeOutCubic, settleCurve: CubicCurve = .smoothstep
    ) {
        self.startScale = startScale
        self.peakScale = peakScale
        self.growTime = growTime
        self.settleTime = settleTime
        self.rise = rise
        self.growCurve = growCurve
        self.settleCurve = settleCurve
    }

    public static let shipped = PickAnimation(
        startScale: 0.55, peakScale: 1.08, growTime: 0.16, settleTime: 0.1, rise: 9)

    /// Seconds from the pick to rest.
    public var duration: Double { growTime + settleTime }

    /// The icon's side as a share of its resting side, `t` seconds after the pick.
    public func scale(at t: Double) -> Double {
        // Sampled times can land a hair off a boundary; the peak and the rest must come out exact.
        let t = [growTime, duration].first { abs(t - $0) < 1e-9 } ?? t
        if t <= 0 { return startScale }
        if t < growTime {
            return startScale + (peakScale - startScale) * growCurve.value(at: t / growTime)
        }
        if t < duration {
            return peakScale + (1 - peakScale) * settleCurve.value(at: (t - growTime) / settleTime)
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
    /// ten even steps, like the launch animation's sampling, with the peak as a sample of its own wherever it falls, so
    /// the icon always reaches it.
    public func keyframes(perSecond: Double) -> (keyTimes: [Double], scales: [Double], drops: [Double]) {
        let steps = max(10, Int((duration * perSecond).rounded()))
        let even = (0...steps).map { duration * Double($0) / Double(steps) }
        let times = even.contains { abs($0 - growTime) < 1e-9 } ? even : (even + [growTime]).sorted()
        return (times.map { $0 / duration }, times.map { scale(at: $0) }, times.map { drop(at: $0) })
    }
}
