import Foundation
import Testing
@testable import LauncherCore

@Suite struct CubicCurveTests {
    @Test func theNamedCurvesAreTheirClosedForms() {
        for x in stride(from: 0.0, through: 1.0, by: 0.01) {
            let back = 1 - x
            #expect(abs(CubicCurve.easeOutCubic.value(at: x) - (1 - back * back * back)) < 1e-9)
            #expect(abs(CubicCurve.smoothstep.value(at: x) - (3 * x * x - 2 * x * x * x)) < 1e-9)
        }
    }

    @Test func aCurveRunsFromZeroToOneWhateverItsControlPoints() throws {
        let overshoot = CubicCurve(0.2, 1.6, 0.4, 1)
        #expect(overshoot.value(at: 0) == 0)
        #expect(overshoot.value(at: 1) == 1)
        #expect(overshoot.value(at: -1) == 0)
        #expect(overshoot.value(at: 2) == 1)
        #expect(try #require((0...100).map { overshoot.value(at: Double($0) / 100) }.max()) > 1)
    }

    @Test func anEaseInCurveLagsTheLinearOne() {
        let easeIn = CubicCurve(0.55, 0, 1, 0.45)
        #expect(easeIn.value(at: 0.5) < 0.5)
        #expect(abs(CubicCurve(0, 0, 1, 1).value(at: 0.3) - 0.3) < 1e-9)
    }
}
