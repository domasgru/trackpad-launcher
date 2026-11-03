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

    @Test func shippedAnimationGrowsFromFortyToOneTenAndSettlesAtOneHundredPercent() {
        let shipped = PickAnimation.shipped
        #expect(shipped.scale(at: 0) == 0.4)
        #expect(shipped.scale(at: 0.2) == 1.1)
        #expect(shipped.scale(at: 0.35) == 1.0)
        #expect(shipped.duration == 0.35)

        let frames = shipped.keyframes(perSecond: 240)
        #expect(frames.keyTimes.count == 85)
        #expect(frames.scales.count == 85)
        #expect(frames.keyTimes.first == 0)
        #expect(frames.keyTimes.last == 1)
        for (i, time) in frames.keyTimes.enumerated() {
            #expect(abs(time - Double(i) / 84) < 1e-12)
        }
        #expect(frames.scales.first == 0.4)
        #expect(frames.scales.last == 1.0)

        let peak = frames.keyTimes.indices.first { abs(frames.keyTimes[$0] * 0.35 - 0.2) < 1e-9 }!
        #expect(frames.scales[peak] == 1.1)
        #expect(frames.scales.max() == 1.1)
        for i in 1...peak { #expect(frames.scales[i] > frames.scales[i - 1]) }
        for i in (peak + 1)..<frames.scales.count { #expect(frames.scales[i] < frames.scales[i - 1]) }
        #expect(frames.scales[peak...].allSatisfy { $0 >= 1.0 })
    }

    @Test func growStartsFastAndSettleSlowsIntoRest() {
        let shipped = PickAnimation.shipped
        #expect(abs(shipped.scale(at: 0.1) - 0.925) < 1e-9)

        let scales = shipped.keyframes(perSecond: 240).scales
        let drops = zip(scales[48...], scales[49...]).map { $0 - $1 }
        #expect(drops.last! < drops.max()! / 4)
    }

    @Test func shippedValuesAreFortyOneTenTwoTenthsAndFifteenHundredths() {
        #expect(PickAnimation.shipped == PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.2, settleTime: 0.15))
    }

    @Test func slowerGrowMovesThePeakLater() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.5, settleTime: 0.15)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.5) < 1e-9)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.65) < 1e-9)
    }

    @Test func smallerStartSizeLowersTheFirstScaleOnly() {
        let animation = PickAnimation(startScale: 0.2, peakScale: 1.1, growTime: 0.2, settleTime: 0.15)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.2)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.35) < 1e-9)
    }

    @Test func largerPeakRaisesTheLargestScale() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.3, growTime: 0.2, settleTime: 0.15)
        let scales = animation.keyframes(perSecond: 240).scales
        #expect(scales.max() == 1.3)
        #expect(scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.3)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.35) < 1e-9)
    }

    @Test func longerSettleReachesRestLater() {
        let animation = PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.2, settleTime: 0.3)
        #expect(animation.keyframes(perSecond: 240).scales.first == 0.4)
        #expect(abs(firstTime(animation, reaching: 1.1)! - 0.2) < 1e-9)
        #expect(abs(firstTime(animation, reaching: 1.0)! - 0.5) < 1e-9)
        #expect(sample(animation, nearest: 0.49) > 1.0)
    }
}
