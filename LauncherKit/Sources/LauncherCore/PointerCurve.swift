import Foundation

/// macOS's trackpad pointer acceleration, reproduced from the open-source HID event system (IOHIDFamily's
/// `IOHIDParametricAcceleration` and `IOHIDPointerAccelerator`), so the switcher's highlight moves exactly as far as
/// the cursor would for the same finger movement. The driver publishes one curve per tracking-speed notch; the
/// tracking speed picks or interpolates between them.
public struct PointerCurve: Equatable, Sendable {
    /// One curve as the trackpad driver publishes it (`HIDAccelCurves`), its 16.16 fixed-point values as doubles.
    public struct Point: Equatable, Sendable {
        public var index: Double
        public var gainLinear: Double
        public var gainParabolic: Double
        public var gainCubic: Double
        public var gainQuartic: Double
        public var tangentSpeedLinear: Double
        public var tangentSpeedParabolicRoot: Double

        public init(
            index: Double, gainLinear: Double, gainParabolic: Double = 0, gainCubic: Double = 0,
            gainQuartic: Double = 0, tangentSpeedLinear: Double = 0, tangentSpeedParabolicRoot: Double = 0
        ) {
            self.index = index
            self.gainLinear = gainLinear
            self.gainParabolic = gainParabolic
            self.gainCubic = gainCubic
            self.gainQuartic = gainQuartic
            self.tangentSpeedLinear = tangentSpeedLinear
            self.tangentSpeedParabolicRoot = tangentSpeedParabolicRoot
        }
    }

    /// The tracking speed macOS uses while the user has never moved the slider (its fourth notch).
    public static let defaultTrackingSpeed = 0.6875
    /// Pointer counts per inch of finger travel (the trackpad's `HIDPointerResolution`).
    static let countsPerInch = 400.0
    /// The trackpad's `HIDPointerReportRate`, in reports per second.
    static let reportRate = 120.0
    /// The HID event system's nominal frame rate, against which curves are defined (`FRAME_RATE`).
    static let frameRate = 67.0
    /// Cursor points per accelerated unit (`kCursorScale`).
    static let cursorScale = 96.0 / 67.0

    private let curve: Point
    /// The tangent line's slope and intercept, and the square-root segment's, as the HID event system derives them.
    private var m0 = 0.0, b0 = 0.0, m1 = 0.0, b1 = 0.0
    private var tangent0 = Double.greatestFiniteMagnitude, tangent1 = Double.greatestFiniteMagnitude

    /// nil when there are no curves. `points` are in the driver's order (ascending index). Above the last index the
    /// last curve applies; between two indices the gains and tangents are interpolated, as macOS does.
    public init?(_ points: [Point], trackingSpeed: Double) {
        guard !points.isEmpty, trackingSpeed >= 0 else { return nil }
        var current = 0
        for (i, point) in points.enumerated() where trackingSpeed >= point.index { current = i }
        var c = points[current]
        if c.index < trackingSpeed, current + 1 < points.count {
            let low = points[current], high = points[current + 1]
            let r = (trackingSpeed - low.index) / (high.index - low.index)
            func lerp(_ k: KeyPath<Point, Double>) -> Double { low[keyPath: k] + r * (high[keyPath: k] - low[keyPath: k]) }
            c = Point(
                index: lerp(\.index), gainLinear: lerp(\.gainLinear), gainParabolic: lerp(\.gainParabolic),
                gainCubic: lerp(\.gainCubic), gainQuartic: lerp(\.gainQuartic),
                tangentSpeedLinear: lerp(\.tangentSpeedLinear), tangentSpeedParabolicRoot: lerp(\.tangentSpeedParabolicRoot))
        }
        curve = c
        // Apple's own construction, including its powers of the gains in y0 and m0.
        func f1(_ x: Double) -> Double {
            c.gainLinear * x + pow(c.gainParabolic * x, 2) + pow(c.gainCubic * x, 3) + pow(c.gainQuartic * x, 4)
        }
        func slope(_ x: Double) -> Double {
            c.gainLinear + 2 * x * pow(c.gainParabolic, 2) + 3 * pow(x, 2) * pow(c.gainCubic, 3)
                + 4 * pow(x, 3) * pow(c.gainQuartic, 4)
        }
        if c.tangentSpeedLinear != 0 {
            m0 = slope(c.tangentSpeedLinear)
            b0 = f1(c.tangentSpeedLinear) - m0 * c.tangentSpeedLinear
            tangent0 = c.tangentSpeedLinear
            if c.tangentSpeedParabolicRoot != 0 {
                let y1 = m0 * c.tangentSpeedParabolicRoot + b0
                m1 = 2 * y1 * m0
                b1 = y1 * y1 - m1 * c.tangentSpeedParabolicRoot
                tangent1 = c.tangentSpeedParabolicRoot
            }
        } else if c.tangentSpeedParabolicRoot != 0 {
            let y0 = f1(c.tangentSpeedParabolicRoot)
            m1 = slope(c.tangentSpeedParabolicRoot)
            b1 = y0 * y0 - m1 * c.tangentSpeedParabolicRoot
            tangent0 = c.tangentSpeedParabolicRoot
        }
    }

    /// Cursor points the pointer moves along x for one report of finger movement (`dxMM`, `dyMM`), `interval`
    /// seconds after the previous one. Reproduces `IOHIDPointerAccelerator::accelerate`.
    public func cursorPoints(dxMM: Double, dyMM: Double, interval: Double) -> Double {
        let dx = dxMM / 25.4 * Self.countsPerInch
        let dy = dyMM / 25.4 * Self.countsPerInch
        let period = 1 / Self.reportRate
        let rateMultiplier = interval > 0 ? period / max(interval, period) : 1
        let velocity = max((hypot(dx, dy)).rounded(.down) * rateMultiplier, 1 / 65536)
        return dx * multiplier(velocity) / velocity
    }

    /// `IOHIDParametricAcceleration::multiplier`.
    private func multiplier(_ velocity: Double) -> Double {
        let value = velocity / (Self.countsPerInch / Self.frameRate)
        let y: Double
        if value <= tangent0 {
            y = curve.gainLinear * value + pow(curve.gainParabolic * value, 2) + pow(curve.gainCubic * value, 3)
                + pow(curve.gainQuartic * value, 4)
        } else if value <= tangent1 && tangent0 == curve.tangentSpeedLinear {
            y = m0 * value + b0
        } else {
            y = (m1 * value + b1).squareRoot()
        }
        return y * Self.cursorScale
    }

    /// The curves a built-in MacBook trackpad publishes, for a trackpad that publishes none. Values are the driver's
    /// 16.16 fixed-point numbers.
    public static let builtInCurves: [Point] = [
        (0, 65536, 0, 0, 484966, 1376256), (8192, 64881, 32768, 5243, 478413, 1310720),
        (32768, 64225, 43254, 6554, 471859, 1245184), (45056, 62915, 54395, 7864, 465306, 1179648),
        (57344, 61604, 65536, 9830, 458752, 1114112), (65536, 60293, 75366, 11796, 458752, 1048576),
        (98304, 58327, 85197, 13763, 458752, 983040), (131072, 56361, 95027, 15729, 458752, 917504),
        (163840, 54395, 108790, 18350, 458752, 851968), (196608, 65536, 123208, 23593, 458752, 786432),
    ].map { (i: Double, l: Double, p: Double, c: Double, t: Double, r: Double) in
        Point(
            index: i / 65536, gainLinear: l / 65536, gainParabolic: p / 65536, gainCubic: c / 65536,
            tangentSpeedLinear: t / 65536, tangentSpeedParabolicRoot: r / 65536)
    }
}

/// How finger movement becomes switcher travel. Travel is in step millimetres: 12 per icon.
public enum SwipeTravel: Equatable, Sendable {
    /// One step millimetre per millimetre of sideways finger movement.
    case linear
    /// As far as the cursor would move: `pointsPerIcon` cursor points make one icon.
    case cursor(PointerCurve, pointsPerIcon: Double)

    /// The switcher's icon pitch, 80 pt icons with 20 pt between: the highlight moves exactly like the cursor over the row.
    public static let shippedPointsPerIcon = 100.0

    func travel(dxMM: Double, dyMM: Double, interval: Double) -> Double {
        switch self {
        case .linear:
            return dxMM
        case .cursor(let curve, let pointsPerIcon):
            return curve.cursorPoints(dxMM: dxMM, dyMM: dyMM, interval: interval)
                / pointsPerIcon * GestureRules.switcherStepMM
        }
    }
}
