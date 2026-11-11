import Foundation

/// A CSS-style timing curve: a cubic Bézier from (0, 0) to (1, 1) through two control points. `x1` and `x2` stay within
/// 0...1 so the curve is a function of time; `y1` and `y2` may leave 0...1 to overshoot.
public struct CubicCurve: Equatable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// 1 − (1 − x)³ exactly: with the x control points at thirds, x is linear in the curve's parameter.
    public static let easeOutCubic = CubicCurve(1.0 / 3, 1, 2.0 / 3, 1)
    /// 3x² − 2x³ exactly, for the same reason.
    public static let smoothstep = CubicCurve(1.0 / 3, 0, 2.0 / 3, 1)

    /// The curve's progress at time share `x`, 0 at 0 and 1 at 1.
    public func value(at x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        // x(t) is monotonic for x control points in 0...1, so bisection always finds t.
        var low = 0.0, high = 1.0, t = x
        for _ in 0..<60 {
            let current = Self.bezier(t, x1, x2)
            if abs(current - x) < 1e-12 { break }
            if current < x { low = t } else { high = t }
            t = (low + high) / 2
        }
        return Self.bezier(t, y1, y2)
    }

    private static func bezier(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
    }
}
