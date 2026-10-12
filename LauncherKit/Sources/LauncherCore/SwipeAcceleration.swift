import Foundation

/// How finger speed scales swipe travel, like pointer acceleration: slow movement keeps its distance (precise, one
/// icon at a time), fast movement covers more, so the far end of a long row fits on the trackpad.
/// gain(speed) = slowGain + (fastGain − slowGain) × smoothstep((speed − slowSpeed) / (fastSpeed − slowSpeed)).
public struct SwipeAcceleration: Equatable, Sendable {
    /// Travel per millimetre of finger movement at or below `slowSpeed`.
    public var slowGain: Double
    /// Travel per millimetre of finger movement at or above `fastSpeed`.
    public var fastGain: Double
    /// Millimetres per second up to which the gain stays `slowGain`.
    public var slowSpeed: Double
    /// Millimetres per second from which the gain is `fastGain`.
    public var fastSpeed: Double

    public init(slowGain: Double, fastGain: Double, slowSpeed: Double, fastSpeed: Double) {
        self.slowGain = slowGain
        self.fastGain = fastGain
        self.slowSpeed = slowSpeed
        self.fastSpeed = fastSpeed
    }

    /// Release builds' acceleration. Debug builds can override it live from the tuner.
    public static let shipped = SwipeAcceleration(slowGain: 1, fastGain: 3, slowSpeed: 40, fastSpeed: 200)
    /// Travel equals finger movement at every speed.
    public static let none = SwipeAcceleration(slowGain: 1, fastGain: 1, slowSpeed: 40, fastSpeed: 200)

    /// The gain at `speed` millimetres per second.
    public func gain(atSpeed speed: Double) -> Double {
        let span = fastSpeed - slowSpeed
        let t = span > 0 ? min(max((speed - slowSpeed) / span, 0), 1) : (speed >= fastSpeed ? 1 : 0)
        return slowGain + (fastGain - slowGain) * t * t * (3 - 2 * t)
    }
}
