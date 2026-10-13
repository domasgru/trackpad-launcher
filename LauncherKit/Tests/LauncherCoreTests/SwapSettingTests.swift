import Testing
import LauncherCore

@MainActor @Suite struct SwapSettingTests {
    private let trackpad = Trackpad.macBook14

    private func rest() -> TouchScript { TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150)) }

    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.system.launchAnimations.isEmpty
            && world.launcher.switcher == nil
    }

    @Test func withTheSwapOffAThumbUnderRestingFingersSwapsNothingAndIsTheAnchorOnceTheyLift() {
        let world = World.switcherWorld()
        world.launcher.setAssignment(.app(world.app("Notes")), for: .two)
        world.launcher.setSwap(on: false)
        #expect(!world.launcher.isSwapOn)

        world.play(rest().thumbTap())
        #expect(nothingHappened(world))

        world.play(rest().thumb(atMM: (10, 10)).wait(.milliseconds(500)).lift().tap(fingers: 2))
        #expect(world.system.broughtToFront == [world.app("Notes")])
        #expect(world.hardware.pulses == [.init(haptic: .gesture, trackpad: trackpad.id)])
    }

    @Test func withTheSwapOffAThumbFirstSwipeStillShowsTheSwitcher() {
        let world = World.switcherWorld()
        world.launcher.setSwap(on: false)

        let script = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher != nil)
        world.play(script.lift())

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])
    }

    @Test func theSwapSettingAppliesToTheNextThumbTapInBothDirectionsWithoutARelaunch() {
        let world = World.switcherWorld()
        world.launcher.setSwap(on: false)
        let off = rest().thumbTap().lift()
        world.play(off)
        #expect(nothingHappened(world))

        world.launcher.setSwap(on: true)
        world.play(off.land(fingers: 2).wait(.milliseconds(150)).thumbTap().lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test func withTheSwipeOffAThumbTapStillSwaps() {
        let world = World.switcherWorld()
        world.launcher.setSwipe(on: false)

        world.swap()

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.gesture])
    }
}
