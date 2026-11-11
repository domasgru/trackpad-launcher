import Foundation

/// The update card's arrow drift, one repeating cycle: the arrow drops `distance` points over `dropTime` on `dropCurve`,
/// springs back into place, overshooting and settling as a damped spring does, then rests for `restTime`.
///
/// The spring is the one SwiftUI's `Spring(duration:bounce:)` describes: `returnTime` is its perceptual duration and
/// `bounciness` its bounce, 0 for no overshoot, up towards 1 for more and longer oscillation. It starts from the
/// bottom at rest, so the lift picks up speed, passes the arrow's place moving, and settles there.
public struct ArrowDrift: Equatable, Sendable {
    /// Points the arrow drops.
    public var distance: Double
    /// Seconds of the drop.
    public var dropTime: Double
    public var dropCurve: CubicCurve
    /// The spring's perceptual duration, in seconds: lower is quicker.
    public var returnTime: Double
    /// The spring's bounce, 0...0.95: how far past its place the arrow goes and how long it keeps swinging.
    public var bounciness: Double
    /// Seconds at rest before the next drop.
    public var restTime: Double

    /// The share of the drop the spring may still be off by when it counts as settled.
    static let settledWithin = 0.003

    public init(
        distance: Double, dropTime: Double, dropCurve: CubicCurve, returnTime: Double, bounciness: Double,
        restTime: Double
    ) {
        self.distance = distance
        self.dropTime = dropTime
        self.dropCurve = dropCurve
        self.returnTime = returnTime
        self.bounciness = bounciness
        self.restTime = restTime
    }

    /// A quick drop that slows as it lands, a soft spring back past its place, a long pause.
    public static let shipped = ArrowDrift(
        distance: 3, dropTime: 0.315, dropCurve: .easeOutCubic, returnTime: 0.45, bounciness: 0.4, restTime: 0.8)

    private var damping: Double { 1 - min(max(bounciness, 0), 0.95) }
    private var stiffness: Double { 2 * .pi / max(returnTime, 0.01) }

    /// The spring's progress from the bottom (0) to the arrow's place (1), `t` seconds into the return; above 1 while
    /// it overshoots.
    func springProgress(at t: Double) -> Double {
        let zeta = damping, omega = stiffness
        if zeta >= 1 { return 1 - exp(-omega * t) * (1 + omega * t) }
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    /// Seconds the return takes until the spring stays within `settledWithin` of the arrow's place.
    public var settleTime: Double {
        let zeta = damping, omega = stiffness
        // The spring's distance from its place never exceeds this envelope, so past its crossing it has settled.
        func envelope(_ t: Double) -> Double {
            zeta >= 1 ? exp(-omega * t) * (1 + omega * t) : exp(-zeta * omega * t) / (1 - zeta * zeta).squareRoot()
        }
        var t = 0.0
        while envelope(t) > Self.settledWithin, t < 10 { t += 0.001 }
        return t
    }

    /// Seconds of one whole cycle.
    public var period: Double { dropTime + settleTime + restTime }

    /// Points the arrow sits from its place `t` seconds into the cycle: negative below it, positive above it.
    public func offset(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t < dropTime { return -distance * dropCurve.value(at: t / dropTime) }
        let settle = settleTime
        if t < dropTime + settle { return -distance * (1 - springProgress(at: t - dropTime)) }
        return 0
    }

    /// The cycle sampled for Core Animation: key times as shares of the period, offsets alongside, with the bottom of
    /// the drop and the end of the return as samples of their own so both come out exact.
    public func keyframes(perSecond: Double) -> (keyTimes: [Double], offsets: [Double]) {
        let settle = settleTime
        let returned = dropTime + settle
        let steps = max(10, Int((returned * perSecond).rounded()))
        var times = (0...steps).map { returned * Double($0) / Double(steps) }
        times.append(dropTime)
        times.append(period)
        times = Array(Set(times)).sorted()
        let offsets = times.map { t -> Double in
            if abs(t - dropTime) < 1e-12 { return -distance }
            if t >= returned { return 0 }
            return offset(at: t)
        }
        return (times.map { $0 / period }, offsets)
    }
}
