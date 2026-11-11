#if DEBUG
import LauncherCore
import Testing
@testable import LauncherPlatform

struct TunerEasingTests {
    @Test func `speed changes the move time and keeps the split between drop and lift`() {
        var drift = ArrowDrift.shipped
        #expect(abs(drift.moveTime - 1.65) < 1e-9)
        #expect(abs(drift.dropPercent - 100.0 / 3) < 1e-9)

        drift.moveTime = 3.3

        #expect(abs(drift.dropTime - 1.1) < 1e-9)
        #expect(abs(drift.liftTime - 2.2) < 1e-9)
        #expect(drift.restTime == ArrowDrift.shipped.restTime)
    }

    @Test func `drop vs lift changes the split and keeps the move time`() {
        var drift = ArrowDrift.shipped

        drift.dropPercent = 50

        #expect(abs(drift.dropTime - 0.825) < 1e-9)
        #expect(abs(drift.liftTime - 0.825) < 1e-9)
    }

    @Test func `the shipped curves read as their names and anything else as custom`() {
        #expect(NamedCurve.matching(ArrowDrift.shipped.dropCurve) == .fallAndLand)
        #expect(NamedCurve.matching(ArrowDrift.shipped.liftCurve) == .slowSettle)
        #expect(NamedCurve.matching(CubicCurve(0.64, 0.7, 0.13, 0.92)) == .custom)
        for named in NamedCurve.allCases {
            if let curve = named.curve { #expect(NamedCurve.matching(curve) == named) }
        }
    }
}
#endif
