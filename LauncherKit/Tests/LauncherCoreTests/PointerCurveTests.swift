import Foundation
import Testing
@testable import LauncherCore

@Suite struct PointerCurveTests {
    private let curves = PointerCurve.builtInCurves
    private let mmPerInch = 25.4

    /// Hand-computed from IOHIDFamily's formula for the default notch's curve (index 0.6875): one report of one count
    /// (1/400 inch) is a velocity of 1, standardised to 67/400, below the first tangent, so the polynomial segment
    /// applies: points = f(67/400) × 96/67.
    @Test func oneCountAtTheDefaultNotchMovesWhatApplesFormulaGives() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let points = curve.cursorPoints(dxMM: mmPerInch / 400, dyMM: 0, interval: 1 / 120)
        let v = 67.0 / 400
        let f = 62915.0 / 65536 * v + pow(54395.0 / 65536 * v, 2) + pow(7864.0 / 65536 * v, 3)
        #expect(abs(points - f * 96 / 67) < 1e-9)
    }

    @Test func fasterMovementCoversMorePointsPerMillimetre() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let slow = curve.cursorPoints(dxMM: 0.2, dyMM: 0, interval: 1 / 120) / 0.2
        let medium = curve.cursorPoints(dxMM: 1, dyMM: 0, interval: 1 / 120) / 1
        let fast = curve.cursorPoints(dxMM: 4, dyMM: 0, interval: 1 / 120) / 4
        #expect(slow < medium && medium < fast)
        #expect(curve.cursorPoints(dxMM: -4, dyMM: 0, interval: 1 / 120) == -4 * fast)
    }

    @Test func aHigherTrackingSpeedMovesFartherAndBetweenNotchesItInterpolates() throws {
        let points = { (speed: Double) in
            try #require(PointerCurve(self.curves, trackingSpeed: speed)).cursorPoints(dxMM: 2, dyMM: 0, interval: 1 / 120)
        }
        let low = try points(0.5), mid = try points(0.6), high = try points(0.6875)
        #expect(low < mid && mid < high)
        #expect(try points(5) == (try points(3)))
    }

    @Test func aSlowerReportRateCountsAsSlowerMovement() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: 1))
        #expect(curve.cursorPoints(dxMM: 2, dyMM: 0, interval: 1 / 30) < curve.cursorPoints(dxMM: 2, dyMM: 0, interval: 1 / 120))
    }

    @Test func noCurvesMeansNoCursorTravel() {
        #expect(PointerCurve([], trackingSpeed: 1) == nil)
    }

    @Test func cursorTravelScalesPointsPerIconToTwelveStepMillimetres() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: 1))
        let points = curve.cursorPoints(dxMM: 3, dyMM: 0, interval: 1 / 120)
        #expect(abs(SwipeTravel.cursor(curve, pointsPerIcon: 100).travel(dxMM: 3, dyMM: 0, interval: 1 / 120) - points * 0.12) < 1e-9)
        #expect(SwipeTravel.linear.travel(dxMM: 3, dyMM: 9, interval: 1) == 3)
    }
}
