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
        let points = curve.cursorMove(dxMM: mmPerInch / 400, dyMM: 0, interval: 1 / 120).x
        let v = 67.0 / 400
        let f = 62915.0 / 65536 * v + pow(54395.0 / 65536 * v, 2) + pow(7864.0 / 65536 * v, 3)
        #expect(abs(points - f * 96 / 67) < 1e-9)
    }

    @Test func fasterMovementCoversMorePointsPerMillimetre() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let slow = curve.cursorMove(dxMM: 0.2, dyMM: 0, interval: 1 / 120).x / 0.2
        let medium = curve.cursorMove(dxMM: 1, dyMM: 0, interval: 1 / 120).x / 1
        let fast = curve.cursorMove(dxMM: 4, dyMM: 0, interval: 1 / 120).x / 4
        #expect(slow < medium && medium < fast)
        #expect(curve.cursorMove(dxMM: -4, dyMM: 0, interval: 1 / 120).x == -4 * fast)
    }

    @Test func aHigherTrackingSpeedMovesFartherAndBetweenNotchesItInterpolates() throws {
        let points = { (speed: Double) in
            try #require(PointerCurve(self.curves, trackingSpeed: speed)).cursorMove(dxMM: 2, dyMM: 0, interval: 1 / 120).x
        }
        let low = try points(0.5), mid = try points(0.6), high = try points(0.6875)
        #expect(low < mid && mid < high)
        #expect(try points(5) == (try points(3)))
    }

    @Test func aSlowerReportRateCountsAsSlowerMovement() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: 1))
        #expect(curve.cursorMove(dxMM: 2, dyMM: 0, interval: 1 / 30).x < curve.cursorMove(dxMM: 2, dyMM: 0, interval: 1 / 120).x)
    }

    @Test func noCurvesMeansNoCursorTravel() {
        #expect(PointerCurve([], trackingSpeed: 1) == nil)
    }

    @Test func cursorTravelScalesPointsPerStepToTwelveStepMillimetres() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: 1))
        let points = curve.cursorMove(dxMM: 3, dyMM: 0, interval: 1 / 120).x
        let travel = SwipeTravel.cursor(curve, pointsPerStep: 100).travel(along: .swipe, dxMM: 3, dyMM: 0, interval: 1 / 120)
        #expect(abs(travel - points * 0.12) < 1e-9)
    }

    /// The same hand-computed one count as above, straight down: y moves by the multiplier x would.
    @Test func oneCountDownwardsMovesWhatApplesFormulaGivesAlongY() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let move = curve.cursorMove(dxMM: 0, dyMM: mmPerInch / 400, interval: 1 / 120)
        let v = 67.0 / 400
        let f = 62915.0 / 65536 * v + pow(54395.0 / 65536 * v, 2) + pow(7864.0 / 65536 * v, 3)
        #expect(abs(move.y - f * 96 / 67) < 1e-9)
        #expect(move.x == 0)
    }

    @Test func aDiagonalMoveKeepsItsDirectionAndCoversWhatTheSameDistanceSidewaysWould() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let diagonal = curve.cursorMove(dxMM: 3, dyMM: 4, interval: 1 / 120)
        let sideways = curve.cursorMove(dxMM: 5, dyMM: 0, interval: 1 / 120)
        #expect(abs(diagonal.x / diagonal.y - 3.0 / 4) < 1e-9)
        #expect(abs(hypot(diagonal.x, diagonal.y) - sideways.x) < 1e-9)
    }

    @Test func aWindowSwipeTravelsAlongYAtAHundredPointsPerRowPositiveDownwards() throws {
        let curve = try #require(PointerCurve(curves, trackingSpeed: PointerCurve.defaultTrackingSpeed))
        let points = curve.cursorMove(dxMM: 0.3, dyMM: -3, interval: 1 / 120).y
        let travel = SwipeTravel.cursor(curve, pointsPerStep: 100)
            .travel(along: .windowSwipe, dxMM: 0.3, dyMM: -3, interval: 1 / 120)
        #expect(travel < 0)
        #expect(abs(travel - points * 0.12) < 1e-9)
    }

    @Test func linearTravelIsTheMillimetresAlongTheSlide() {
        #expect(SwipeTravel.linear.travel(along: .swipe, dxMM: 3, dyMM: 9, interval: 1) == 3)
        #expect(SwipeTravel.linear.travel(along: .windowSwipe, dxMM: 3, dyMM: 9, interval: 1) == 9)
    }
}
