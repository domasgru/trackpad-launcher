import Foundation
import Testing
@testable import LauncherCore

@Suite struct PickAnimationTests {
    private func sample(_ animation: PickAnimation, nearest seconds: Double) -> Double {
        let frames = animation.keyframes(perSecond: 240)
        let index = frames.keyTimes.indices.min {
            abs(frames.keyTimes[$0] * animation.duration - seconds) < abs(frames.keyTimes[$1] * animation.duration - seconds)
        }!
        return frames.scales[index]
    }

    private func firstTime(_ animation: PickAnimation, reaching scale: Double) -> Double? {
        let frames = animation.keyframes(perSecond: 240)
        let from = frames.scales.firstIndex(of: frames.scales.max()!)!
        return frames.scales.indices[from...].first { frames.scales[$0] == scale }.map {
            frames.keyTimes[$0] * animation.duration
        }
    }

    @Test func shippedAnimationGrowsFromFiftyFiveToOneOEightAndSettlesAtOneHundredPercent() {
        let shipped = PickAnimation.shipped
        #expect(shipped.scale(at: 0) == 0.55)
        #expect(shipped.scale(at: 0.16) == 1.08)
        #expect(shipped.scale(at: 0.26) == 1.0)
        #expect(abs(shipped.duration - 0.26) < 1e-12)

        let frames = shipped.keyframes(perSecond: 240)
        // 62 even steps, 63 samples, and the peak at 0.16 s between two of them.
        #expect(frames.keyTimes.count == 64)
        #expect(frames.scales.count == 64)
        #expect(frames.drops.count == 64)
        #expect(frames.keyTimes.first == 0)
        #expect(frames.keyTimes.last == 1)
        #expect(zip(frames.keyTimes, frames.keyTimes.dropFirst()).allSatisfy { $0 < $1 })
        #expect(frames.scales.first == 0.55)
        #expect(frames.scales.last == 1.0)

        let peak = frames.keyTimes.indices.first { abs(frames.keyTimes[$0] * shipped.duration - 0.16) < 1e-9 }!
        #expect(frames.scales[peak] == 1.08)
        #expect(frames.scales.max() == 1.08)
        for i in 1...peak { #expect(frames.scales[i] > frames.scales[i - 1]) }
        for i in (peak + 1)..<frames.scales.count { #expect(frames.scales[i] < frames.scales[i - 1]) }
        #expect(frames.scales[peak...].allSatisfy { $0 >= 1.0 })
    }

    @Test func growStartsFastAndSettleSlowsIntoRest() throws {
        let shipped = PickAnimation.shipped
        // Half the grow time in, an ease-out cubic has covered seven eighths of the way.
        #expect(abs(shipped.scale(at: 0.08) - (0.55 + 0.53 * 0.875)) < 1e-9)

        let scales = shipped.keyframes(perSecond: 240).scales
        let peak = try #require(scales.indices.max { scales[$0] < scales[$1] })
        let drops = zip(scales[peak...], scales[(peak + 1)...]).map { $0 - $1 }
        #expect(try #require(drops.last) < (try #require(drops.max())) / 4)
    }

    @Test func theIconJumpsFromBelowPastItsPlaceAndSettlesIntoIt() {
        let shipped = PickAnimation.shipped
        #expect(shipped.drop(at: 0) == 9)
        #expect(shipped.drop(at: shipped.duration) == 0)
        let lift = shipped.drop(at: 0.16)
        #expect(abs(lift - -9 * 0.08 / 0.45) < 1e-9)

        let drops = shipped.keyframes(perSecond: 240).drops
        let top = drops.indices.min { drops[$0] < drops[$1] }!
        #expect(drops[top] == lift)
        for i in 1...top { #expect(drops[i] < drops[i - 1]) }
        for i in (top + 1)..<drops.count { #expect(drops[i] > drops[i - 1]) }
    }

    @Test func noRiseKeepsTheIconInPlace() {
        let animation = PickAnimation(startScale: 0.55, peakScale: 1.08, growTime: 0.16, settleTime: 0.1, rise: 0)
        #expect(animation.keyframes(perSecond: 240).drops.allSatisfy { $0 == 0 })
    }

    @Test func shippedValuesAreFiftyFiveOneOEightAndAQuickJumpFromNinePointsBelow() {
        #expect(
            PickAnimation.shipped
                == PickAnimation(startScale: 0.55, peakScale: 1.08, growTime: 0.16, settleTime: 0.1, rise: 9))
    }

    @Test func aPeakBetweenEvenStepsIsStillSampled() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.2, growTime: 0.123, settleTime: 0.1, rise: 6)
        let frames = animation.keyframes(perSecond: 240)
        #expect(frames.scales.max() == 1.2)
        #expect(frames.keyTimes.contains { abs($0 * animation.duration - 0.123) < 1e-12 })
    }

    @Test func slowerGrowMovesThePeakLater() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.5, settleTime: 0.15, rise: 6)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.5) < 1e-9)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.65) < 1e-9)
    }

    @Test func smallerStartSizeLowersTheFirstScaleOnly() {
        let animation = PickAnimation(startScale: 0.2, peakScale: 1.1, growTime: 0.2, settleTime: 0.15, rise: 6)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.2)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.35) < 1e-9)
    }

    @Test func largerPeakRaisesTheLargestScale() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.3, growTime: 0.2, settleTime: 0.15, rise: 6)
        let scales = animation.keyframes(perSecond: 240).scales
        #expect(scales.max() == 1.3)
        #expect(scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.3)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.35) < 1e-9)
    }

    @Test func longerSettleReachesRestLater() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.2, settleTime: 0.3, rise: 6)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.5) < 1e-9)
        #expect(sample(animation, nearest: 0.49) > 1.0)
    }
}
