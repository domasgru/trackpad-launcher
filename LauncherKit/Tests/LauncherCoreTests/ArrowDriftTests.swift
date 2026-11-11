import Foundation
import Testing
@testable import LauncherCore

@Suite struct ArrowDriftTests {
    private func drift(bounciness: Double) -> ArrowDrift {
        var drift = ArrowDrift.shipped
        drift.bounciness = bounciness
        return drift
    }

    @Test func theCycleDropsThenSpringsBackAndRestsInPlace() {
        let shipped = ArrowDrift.shipped
        let frames = shipped.keyframes(perSecond: 240)
        #expect(frames.keyTimes.first == 0 && frames.keyTimes.last == 1)
        #expect(frames.offsets.first == 0 && frames.offsets.last == 0)
        #expect(frames.offsets.min() == -3)
        let bottom = frames.keyTimes.firstIndex { abs($0 * shipped.period - shipped.dropTime) < 1e-9 }!
        #expect(frames.offsets[bottom] == -3)
        for i in 1...bottom { #expect(frames.offsets[i] < frames.offsets[i - 1], "drops") }
        #expect(zip(frames.keyTimes, frames.keyTimes.dropFirst()).allSatisfy { $0 < $1 })
        let rest = frames.keyTimes.filter { $0 * shipped.period > shipped.dropTime + shipped.settleTime + 1e-9 }
        #expect(rest.count == 1, "the pause is one still stretch")
    }

    @Test func aBouncySpringPassesItsPlaceAndSettlesBack() {
        for bounciness in [0.2, 0.4, 0.7] {
            let drift = drift(bounciness: bounciness)
            let offsets = drift.keyframes(perSecond: 240).offsets
            let zeta = 1 - bounciness
            // A damped spring's first overshoot, as a share of where it started from.
            let overshoot = exp(-zeta * .pi / (1 - zeta * zeta).squareRoot())
            #expect(abs(offsets.max()! - 3 * overshoot) < 0.01, "bounciness \(bounciness)")
        }
    }

    @Test func noBouncinessComesBackWithoutPassingItsPlace() {
        let offsets = drift(bounciness: 0).keyframes(perSecond: 240).offsets
        #expect(offsets.allSatisfy { $0 <= 0 })
    }

    @Test func moreBouncinessSwingsLonger() {
        #expect(drift(bounciness: 0.7).settleTime > drift(bounciness: 0.4).settleTime)
        var quick = ArrowDrift.shipped
        quick.returnTime = 0.2
        #expect(quick.settleTime < ArrowDrift.shipped.settleTime)
    }

    @Test func theSpringLeavesTheBottomAtRest() {
        let drift = ArrowDrift.shipped
        let start = drift.offset(at: drift.dropTime + 1e-6)
        #expect(abs(start - -3) < 1e-6)
        #expect(abs(drift.offset(at: drift.dropTime + drift.settleTime - 1e-6)) < 3 * 0.003 + 1e-9)
    }
}
