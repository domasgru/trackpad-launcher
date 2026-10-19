import Testing
import LauncherCore

@MainActor @Suite struct TapGateEstimateTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()

    private func world(estimating: Bool) -> World {
        let world = World.switcherWorld(accessGranted: true)
        world.hardware.usesEstimatedContext = estimating
        return world
    }

    private func readings(_ body: (World) -> ScrollVerdict?) -> (estimated: ScrollVerdict?, exact: ScrollVerdict?) {
        (body(world(estimating: true)), body(world(estimating: false)))
    }

    @Test func fingersRestingUnderAThumbThatLandsReadAsAScrollUnderWayOnlyUnderTheEstimate() {
        let result = readings { world in
            let rest = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
            world.play(rest)
            world.play(rest.wait(.milliseconds(10)).thumb(atMM: (10, 10)).slide(byMM: (10, 0)))
            return world.hardware.scroll(.fingers(.began))
        }
        #expect(result.estimated == .passStill)
        #expect(result.exact == .drop)
    }

    @Test func aSwapSeriesReadsTheSameWay() {
        let result = readings { world in
            let rest = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
            world.play(rest)
            world.play(rest.wait(.milliseconds(10)).thumbTap().slide(byMM: (10, 0)))
            return world.hardware.scroll(.fingers(.began))
        }
        #expect(result.estimated == .passStill)
        #expect(result.exact == .drop)
    }

    @Test func aFreshThumbThenFingersWithAWarningFrameDropsUnderBothContexts() {
        for estimating in [true, false] {
            let world = world(estimating: estimating)
            let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
            world.play(thumb)
            world.play(thumb.wait(.milliseconds(10)).land(fingers: 2))
            #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop)))
        }
    }

    @Test func aThumbAndAFingerOnOneFrameReadAsAScrollUnderWayOnlyUnderTheEstimateWithNoWarning() {
        let landing = [h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)])]
        let warned = readings { world in
            world.hardware.touch(landing, on: trackpad.id)
            #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop)))
            return world.hardware.scroll(.fingers(.began))
        }
        #expect(warned.estimated == .drop)
        #expect(warned.exact == .drop)

        let unwarned = readings { world in
            world.hardware.touch(landing, on: trackpad.id)
            return world.hardware.scroll(.fingers(.began))
        }
        #expect(unwarned.estimated == .passStill)
        #expect(unwarned.exact == .drop)
    }
}
