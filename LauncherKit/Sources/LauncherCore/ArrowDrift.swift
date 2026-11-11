import Foundation

/// The update card's arrow drift, one repeating cycle: the arrow winds up, easing `windUp` points above its place over
/// `windUpTime`, drops from there to `distance` points below its place over `dropTime` on `dropCurve`, springs back into
/// place, overshooting and settling as a damped spring does, then rests for `restTime`.
///
/// The spring is the one SwiftUI's `Spring(duration:bounce:)` describes: `returnTime` is its perceptual duration and
/// `bounciness` its bounce, 0 for no overshoot, up towards 1 for more and longer oscillation. It starts from the
/// bottom at rest, so the lift picks up speed, passes the arrow's place moving, and settles there.
public struct ArrowDrift: Equatable, Sendable {
    /// Points the arrow lifts above its place before it drops.
    public var windUp: Double
    /// Seconds of the wind-up.
    public var windUpTime: Double
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

    /// The wind-up's curve: leaves the place and stops at the top gently, so the drop starts from a still arrow.
    public static let windUpCurve = CubicCurve(0.37, 0, 0.63, 1)

    /// The share of the drop the spring may still be off by when it counts as settled.
    static let settledWithin = 0.003

    public init(
        distance: Double, dropTime: Double, dropCurve: CubicCurve, returnTime: Double, bounciness: Double,
        restTime: Double, windUp: Double = 0, windUpTime: Double = 0
    ) {
        self.windUp = windUp
        self.windUpTime = windUpTime
        self.distance = distance
        self.dropTime = dropTime
        self.dropCurve = dropCurve
        self.returnTime = returnTime
        self.bounciness = bounciness
        self.restTime = restTime
    }

    /// A small wind-up, a quick drop that slows as it lands, a soft spring back past its place, a long pause.
    public static let shipped = ArrowDrift(
        distance: 4, dropTime: 0.26, dropCurve: CubicCurve(0.33, 1, 0.68, 1), returnTime: 0.45, bounciness: 0.4,
        restTime: 0.9, windUp: 1, windUpTime: 0.2)

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

    /// Seconds the return takes until the spring stays within `settledWithin` of the arrow's place: where the
    /// envelope its distance from the place never exceeds falls to that share.
    public var settleTime: Double {
        let zeta = damping, omega = stiffness, within = Self.settledWithin
        if zeta < 1 {
            // e^(−ζωt) / √(1 − ζ²) = within
            return log(1 / (within * (1 - zeta * zeta).squareRoot())) / (zeta * omega)
        }
        // e^(−u)(1 + u) = within, u = ωt: Newton's method from u = 1, short of the root. Past 1 the function falls and
        // is convex, so from where it is still above `within` each step lands closer without overshooting.
        var u = 1.0
        for _ in 0..<20 { u -= (exp(-u) * (1 + u) - within) / (-u * exp(-u)) }
        return u / omega
    }

    /// Seconds of one whole cycle.
    public var period: Double { windUpTime + dropTime + settleTime + restTime }

    /// Seconds from the cycle's start to the bottom of the drop.
    public var dropEnd: Double { windUpTime + dropTime }

    /// Points the arrow sits from its place `t` seconds into the cycle: negative below it, positive above it.
    public func offset(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t < windUpTime { return windUp * Self.windUpCurve.value(at: t / windUpTime) }
        let lifted = windUpTime > 0 ? windUp : 0
        if t < dropEnd { return lifted - (lifted + distance) * dropCurve.value(at: (t - windUpTime) / dropTime) }
        let settle = settleTime
        if t < dropEnd + settle { return -distance * (1 - springProgress(at: t - dropEnd)) }
        return 0
    }

    /// The cycle sampled for Core Animation: key times as shares of the period, offsets alongside, with the top of the
    /// wind-up, the bottom of the drop and the end of the return as samples of their own so all come out exact.
    public func keyframes(perSecond: Double) -> (keyTimes: [Double], offsets: [Double]) {
        let settle = settleTime
        let returned = dropEnd + settle
        let steps = max(10, Int((returned * perSecond).rounded()))
        var times = (0...steps).map { returned * Double($0) / Double(steps) }
        times += [windUpTime, dropEnd, period]
        times = Array(Set(times)).sorted()
        let offsets = times.map { t -> Double in
            if windUpTime > 0, abs(t - windUpTime) < 1e-12 { return windUp }
            if abs(t - dropEnd) < 1e-12 { return -distance }
            if t >= returned { return 0 }
            return offset(at: t)
        }
        return (times.map { $0 / period }, offsets)
    }
}
