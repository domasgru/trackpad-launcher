import LauncherCore
import QuartzCore
import Testing

@testable import LauncherUI

@Suite struct LiquidKeyframesTests {
    private func channel(_ element: LiquidElement, _ property: LiquidProperty) -> LiquidChannel {
        LiquidChannel(element: element, property: property)
    }

    private func track(_ channel: LiquidChannel, offsets: [Double]) -> LiquidTrack {
        LiquidTrack(channel: channel, begin: LiquidTime(seconds: 3), step: 1.0 / 120, offsets: offsets)
    }

    @Test(arguments: [
        (LiquidProperty.centreX, "position.x"), (.width, "bounds.size.width"), (.height, "bounds.size.height"),
    ])
    func eachChannelIsAnAdditiveLinearKeyframeTrackOnItsKeyPath(property: LiquidProperty, keyPath: String) throws {
        let offsets = [-12.5, -4, 3.25, 0.5, 0]
        let staged = LiquidKeyframes.animation(track(channel(.swell, property), offsets: offsets), beginTime: 5)

        #expect(staged.keyPath == keyPath)
        #expect(staged.isAdditive && staged.calculationMode == .linear)
        #expect(try #require(staged.values as? [NSNumber]).map(\.doubleValue) == offsets)
        #expect(abs(staged.duration - 4.0 / 120) < 1e-12)
        #expect(staged.beginTime == 5)
    }

    @Test func aHoldingTrackFillsForwardsAndAnyOtherIsRemovedOnCompletion() {
        let holding = LiquidKeyframes.animation(
            track(channel(.bead(3), .height), offsets: [0, 4, 6]), beginTime: 5)
        let ending = LiquidKeyframes.animation(track(channel(.swell, .width), offsets: [0, 4, 0]), beginTime: 5)

        #expect(holding.fillMode == .forwards && !holding.isRemovedOnCompletion)
        #expect(ending.fillMode == .removed && ending.isRemovedOnCompletion)
    }

    @Test func everyChannelHasItsOwnKeyUnderTheLiquidPrefix() {
        let swell = [LiquidProperty.centreX, .width, .height].map { channel(.swell, $0) }
        let beads = (0..<10).flatMap { index in [LiquidProperty.width, .height].map { channel(.bead(index), $0) } }
        let keys = (swell + beads).map(LiquidKeyframes.key)

        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { $0.hasPrefix("liquid.") })
        #expect(keys.contains("liquid.swell.width") && keys.contains("liquid.bead.3.height"))
    }
}
