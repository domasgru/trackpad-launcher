import Testing
import LauncherCore

@MainActor @Suite struct SwipeSettingTests {
    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.system.launchAnimations.isEmpty && world.system.bounces.isEmpty
    }

    @Test func turningTheSwipeOffShowsNoSwitcherAndKeepsTheWindowOpen() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()

        world.launcher.setSwipe(on: false)
        #expect(!world.launcher.isSwipeOn)
        #expect(world.launcher.isWindowOpen)

        let script = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher == nil)
        world.play(script.lift())
        #expect(nothingHappened(world))

        world.launcher.setSwipe(on: true)
        #expect(world.launcher.isSwipeOn)
    }

    @Test func afterTurningTheSwipeBackOnTheNextSwipeShowsTheRowAndOpensTheSelection() {
        let world = World.switcherWorld()
        world.launcher.setSwipe(on: false)
        world.launcher.setSwipe(on: true)

        let script = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"])
        world.play(script.lift())

        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test func withTheSwipeOffASlideShowsNothingAndScrollsOnlyAfterTheBlockingWindow() {
        let world = World.switcherWorld(accessGranted: true)
        world.launcher.setSwipe(on: false)
        let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

        let early = thumb.land(fingers: 2).slide(byMM: (20, 0))
        world.play(early)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        let pressedEarly = early.press().lift()
        world.play(pressedEarly)

        let late = pressedEarly.liftThumb().thumb(atMM: (10, 10)).wait(.seconds(4)).land(fingers: 2).slide(byMM: (20, 0))
        world.play(late)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
        world.play(late.press().lift())

        #expect(world.hardware.pressVerdicts == [.drop, .drop, .pass, .pass])
        #expect(nothingHappened(world))
    }

    @Test func withTheSwipeOffATwoFingerTapStillOpensItsApp() {
        let world = World.switcherWorld()
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.launcher.setSwipe(on: false)

        world.tap(2)

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.gesture])
    }
}
