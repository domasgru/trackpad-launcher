import Foundation

/// The update card's arrow drift, one repeating cycle: the arrow drops `distance` points over `dropTime` on `dropCurve`,
/// lifts back over `liftTime` on `liftCurve` past its place to `bounce` points above it, settles back into place over
/// `bounceTime` on `settleCurve`, then rests for `restTime`. With no bounce the lift ends in place and the settle is a
/// pause.
public struct ArrowDrift: Equatable, Sendable {
    /// Points the arrow drops.
    public var distance: Double
    /// Seconds of the drop.
    public var dropTime: Double
    /// Seconds of the lift, to the top of the bounce.
    public var liftTime: Double
    /// Seconds at rest before the next drop.
    public var restTime: Double
    public var dropCurve: CubicCurve
    public var liftCurve: CubicCurve
    /// Points the arrow overshoots above its place at the end of the lift.
    public var bounce: Double
    /// Seconds from the top of the bounce back into place.
    public var bounceTime: Double

    /// The settle from the top of the bounce: leaves the top and lands in place gently, so the overshoot reads as one
    /// soft spring.
    public static let settleCurve = CubicCurve(0.37, 0, 0.63, 1)

    public init(
        distance: Double, dropTime: Double, liftTime: Double, restTime: Double, dropCurve: CubicCurve,
        liftCurve: CubicCurve, bounce: Double = 0, bounceTime: Double = 0
    ) {
        self.distance = distance
        self.dropTime = dropTime
        self.liftTime = liftTime
        self.restTime = restTime
        self.dropCurve = dropCurve
        self.liftCurve = liftCurve
        self.bounce = bounce
        self.bounceTime = bounceTime
    }

    /// A quick drop that eases in and lands softly, a long lift that slows past its place, a small bounce back, a short
    /// rest.
    public static let shipped = ArrowDrift(
        distance: 4, dropTime: 0.55, liftTime: 1.1, restTime: 0.25, dropCurve: CubicCurve(0.55, 0, 0.3, 1),
        liftCurve: CubicCurve(0.3, 0, 0.1, 1), bounce: 1.5, bounceTime: 0.4)

    /// Seconds of one whole cycle.
    public var period: Double { dropTime + liftTime + bounceTime + restTime }
}
