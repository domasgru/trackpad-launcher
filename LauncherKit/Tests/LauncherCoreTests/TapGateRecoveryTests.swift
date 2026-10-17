import Testing
import LauncherCore

@MainActor @Suite struct TapGateRecoveryTests {
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    private func world() -> World { World.switcherWorld(accessGranted: true) }

    private func arcWorld() -> World {
        let world = World(apps: ["Arc"], accessGranted: true)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        return world
    }

    @Test func aSystemDisableOfBothPortsIsRecoveredAndTheGestureInFlightIsForgotten() {
        let world = world()
        world.play(thumb.land(fingers: 2))
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        world.hardware.systemDisables()
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)
    }

    @Test func aSystemDisableDuringAWithheldPressForgetsThePressButTheTapStillFires() {
        let world = arcWorld()
        let script = thumb.land(fingers: 1).wait(.milliseconds(20)).press()
        world.play(script)
        world.hardware.systemDisables()
        world.play(script.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .pass])
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aSystemDisableWithNothingInFlightWaitsForItsNoticeAndTurnsNothingOnAfterIt() {
        let world = world()
        world.hardware.withLateWakes {
            world.hardware.systemDisables()
            #expect(world.hardware.offer(.pointer(.release(PressID(button: 2, number: 7)))) == .notSent)
        }
        #expect(world.hardware.offer(.pointer(.release(PressID(button: 2, number: 7)))) == .decided(.pointer(.pass)))
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.scroll(.fingers(.changed))) == .notSent)
    }

    @Test func theGatedPortDisabledAloneForgetsTheScrollAndKeepsThePress() {
        let world = world()
        let script = thumb.land(fingers: 1).wait(.milliseconds(20)).press()
        world.play(script)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        world.hardware.systemDisables([.gated])
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.pointer(.drag(button: 0))) == .decided(.pointer(.passAsMove)))
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)
        world.play(script.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }

    @Test func thePressPortDisabledAloneForgetsThePressAndKeepsTheScroll() {
        let world = world()
        let script = thumb.land(fingers: 1).wait(.milliseconds(20)).press()
        world.play(script)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        world.hardware.systemDisables([.presses])
        #expect(world.hardware.scroll(.fingers(.changed)) == .drop)
        #expect(world.hardware.offer(.pointer(.drag(button: 0))) == .decided(.pointer(.pass)))
        world.play(script.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .pass])
    }

    @Test func revokingAccessibilityRemovesTheTapAndGrantingItAgainRestartsItClosed() {
        let world = world()
        let hand = thumb.land(fingers: 2)
        world.play(hand)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)

        world.permissions.set(.accessibility, granted: false)
        #expect(!world.hardware.isBlockingClicks)
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.scroll(.fingers(.changed))) == .noTap)
        #expect(world.hardware.scroll(.fingers(.changed)) == nil)

        world.permissions.set(.accessibility, granted: true)
        world.play(hand.wait(.milliseconds(50)))
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func aWakeRestartsTheTapClosedWithNothingInFlight() {
        let world = world()
        world.play(thumb.land(fingers: 2))
        let runs = world.hardware.runCount
        world.hardware.wake()
        #expect(world.hardware.runCount == runs + 1)
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.scroll(.momentum(.began))) == .notSent)
        #expect(world.hardware.scroll(.fingers(.changed)) == .pass)
    }

    @Test func sleepLeavesTheLatchedGateUntilTheWakeReplacesTheTap() {
        let world = world()
        let script = thumb.land(fingers: 1)
        world.play(script)
        world.hardware.sleep()
        #expect(world.hardware.isGatedPortOn)
        world.play(script.lift().liftThumb())
        #expect(world.hardware.isGatedPortOn)
        world.hardware.wake()
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func aHotPlugMidGestureRestartsTheTapClosed() {
        let world = world()
        let script = thumb.land(fingers: 1)
        world.play(script)
        #expect(world.hardware.isGatedPortOn)
        world.hardware.attach(.magicTrackpad)
        #expect(!world.hardware.isGatedPortOn)
        world.play(script.wait(.milliseconds(50)))
        world.hardware.detach(Trackpad.magicTrackpad.id)
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func turningTheSwipeOffOrChangingTheHandMidGestureRestartsTheTapClosed() {
        let world = world()
        let hand = thumb.land(fingers: 2)
        world.play(hand)
        #expect(world.hardware.isGatedPortOn)
        world.launcher.setSwipe(on: false)
        #expect(!world.hardware.isGatedPortOn)

        world.play(hand.wait(.milliseconds(50)))
        world.launcher.setHandMode(.left)
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func tapToClickTurnsTheTapOff() {
        let world = world()
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        #expect(world.hardware.offer(.scroll(.fingers(.changed))) == .noTap)
    }

    @Test func twoTrackpadsMergeToTheHighestLevelAndTheGateFollowsTheOneThatStillWantsIt() {
        let world = World(attached: [.macBook14, .magicTrackpad], accessGranted: true)
        world.launcher.start()
        let magic = TouchScript(.magicTrackpad).thumb(atMM: (10, 10))
        world.play(magic, on: .magicTrackpad)
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.scroll(.unphased) == .pass)

        let rest = TouchScript(.macBook14).land(fingers: 2)
        world.play(rest)
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.scroll(.unphased) == .pass)

        let under = rest.wait(.milliseconds(10)).thumb(atMM: (10, 10)).wait(.seconds(1))
        world.play(under)
        #expect(world.hardware.scroll(.unphased) == .drop)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)

        world.play(under.liftThumb())
        #expect(world.hardware.scroll(.unphased) == .pass)
        #expect(world.hardware.isGatedPortOn)
    }
}
