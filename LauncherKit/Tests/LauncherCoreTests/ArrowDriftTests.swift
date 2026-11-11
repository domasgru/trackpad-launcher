import Foundation
import Testing
@testable import LauncherCore

@Suite struct ArrowDriftTests {
    private func drift(bounciness: Double) -> ArrowDrift {
        var drift = ArrowDrift.shipped
        drift.bounciness = bounciness
        return drift
    }

    @Test func theCycleDropsThenSpringsBackAndRestsInPlace() throws {
        let shipped = ArrowDrift.shipped
        let frames = shipped.keyframes(perSecond: 240)
        #expect(frames.keyTimes.first == 0 && frames.keyTimes.last == 1)
        #expect(frames.offsets.first == 0 && frames.offsets.last == 0)
        #expect(frames.offsets.min() == -4)
        let top = try #require(frames.keyTimes.firstIndex { abs($0 * shipped.period - shipped.windUpTime) < 1e-9 })
        let bottom = try #require(frames.keyTimes.firstIndex { abs($0 * shipped.period - shipped.dropEnd) < 1e-9 })
        #expect(frames.offsets[top] == 1)
        #expect(frames.offsets[bottom] == -4)
        for i in 1...top { #expect(frames.offsets[i] > frames.offsets[i - 1], "winds up") }
        for i in (top + 1)...bottom { #expect(frames.offsets[i] < frames.offsets[i - 1], "drops") }
        #expect(zip(frames.keyTimes, frames.keyTimes.dropFirst()).allSatisfy { $0 < $1 })
        let rest = frames.keyTimes.filter { $0 * shipped.period > shipped.dropEnd + shipped.settleTime + 1e-9 }
        #expect(rest.count == 1, "the pause is one still stretch")
    }

    @Test func noWindUpDropsStraightFromThePlace() throws {
        var drift = ArrowDrift.shipped
        drift.windUp = 0
        let offsets = drift.keyframes(perSecond: 240).offsets
        let bottom = try #require(offsets.firstIndex(of: -4))
        #expect(offsets[...bottom].allSatisfy { $0 <= 0 })
    }

    @Test(arguments: [0.2, 0.4, 0.7])
    func aBouncySpringPassesItsPlaceAndSettlesBack(bounciness: Double) throws {
        let frames = drift(bounciness: bounciness).keyframes(perSecond: 240)
        let bottom = try #require(frames.offsets.firstIndex(of: -4))
        let highest = try #require(frames.offsets[bottom...].max())
        let zeta = 1 - bounciness
        // A damped spring's first overshoot, as a share of where it started from.
        let overshoot = exp(-zeta * .pi / (1 - zeta * zeta).squareRoot())
        #expect(abs(highest - 4 * overshoot) < 0.01)
    }

    @Test func noBouncinessComesBackWithoutPassingItsPlace() throws {
        let offsets = drift(bounciness: 0).keyframes(perSecond: 240).offsets
        let bottom = try #require(offsets.firstIndex(of: -4))
        #expect(offsets[bottom...].allSatisfy { $0 <= 0 })
    }

    @Test(arguments: [0, 0.2, 0.4, 0.7])
    func theSettleTimeIsWhereTheSpringStaysWithinItsMargin(bounciness: Double) {
        let drift = drift(bounciness: bounciness)
        let settle = drift.settleTime
        let after = stride(from: settle, through: settle + 2, by: 0.001).map {
            abs(drift.offset(at: drift.dropEnd + $0 - 1e-9))
        }
        #expect(after.allSatisfy { $0 <= 4 * 0.003 + 1e-9 })
        #expect(settle > 0.1 && settle < 3)
    }

    @Test func moreBouncinessSwingsLonger() {
        #expect(drift(bounciness: 0.7).settleTime > drift(bounciness: 0.4).settleTime)
        var quick = ArrowDrift.shipped
        quick.returnTime = 0.2
        #expect(quick.settleTime < ArrowDrift.shipped.settleTime)
    }

    @Test func theSpringLeavesTheBottomAtRest() {
        let drift = ArrowDrift.shipped
        let start = drift.offset(at: drift.dropEnd + 1e-6)
        #expect(abs(start - -4) < 1e-6)
        #expect(abs(drift.offset(at: drift.dropEnd + drift.settleTime - 1e-6)) < 4 * 0.003 + 1e-9)
    }
}
