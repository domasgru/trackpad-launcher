import Foundation

/// The update card's arrow drift, one repeating cycle: the arrow drops `distance` points over `dropTime` on `dropCurve`,
/// lifts back over `liftTime` on `liftCurve`, then rests in place for `restTime`.
public struct ArrowDrift: Equatable, Sendable {
    /// Points the arrow drops.
    public var distance: Double
    /// Seconds of the drop.
    public var dropTime: Double
    /// Seconds of the lift back.
    public var liftTime: Double
    /// Seconds at rest before the next drop.
    public var restTime: Double
    public var dropCurve: CubicCurve
    public var liftCurve: CubicCurve

    public init(
        distance: Double, dropTime: Double, liftTime: Double, restTime: Double, dropCurve: CubicCurve,
        liftCurve: CubicCurve
    ) {
        self.distance = distance
        self.dropTime = dropTime
        self.liftTime = liftTime
        self.restTime = restTime
        self.dropCurve = dropCurve
        self.liftCurve = liftCurve
    }

    /// A quick drop that eases in and lands softly, a long lift that slows into place, a short rest.
    public static let shipped = ArrowDrift(
        distance: 4, dropTime: 0.55, liftTime: 1.1, restTime: 0.25, dropCurve: CubicCurve(0.55, 0, 0.3, 1),
        liftCurve: CubicCurve(0.3, 0, 0.1, 1))

    /// Seconds of one whole cycle.
    public var period: Double { dropTime + liftTime + restTime }
}
