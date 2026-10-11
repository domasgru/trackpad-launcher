import Testing
import LauncherCore

@MainActor @Suite struct ScrollSuppressionTests {
    private let trackpad = Trackpad.macBook14
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    @Test func slidingTwoFingersUpAndDownWithinTheWindowDoesNotScrollAndShowsNoSwitcher() {
        let world = World.switcherWorld(accessGranted: true)
        world.play(thumb.land(fingers: 2).slide(byMM: (0, 10)))
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        #expect(world.launcher.switcher == nil)
    }

    @Test func scrollingReturnsAfterThreeSecondsAndWhenTheThumbLifts() {
        let late = World.switcherWorld(accessGranted: true)
        late.play(thumb.wait(.seconds(4)).land(fingers: 2))
        #expect(late.hardware.scroll(.fingers(.began)) == .pass)

        let lifted = World.switcherWorld(accessGranted: true)
        lifted.play(thumb.liftThumb().land(fingers: 2))
        #expect(lifted.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func aWheelPassesWhileFingersOnTheSameFlagsWouldNot() {
        let world = World.switcherWorld(accessGranted: true)
        world.play(thumb.land(fingers: 1))
        #expect(world.hardware.scroll(.wheel) == .pass)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
    }

    @Test func withoutAccessNothingIsSuppressedAndTheSwipeStillWorks() {
        let world = World.switcherWorld(accessGranted: false)
        world.play(thumb.land(fingers: 2))
        #expect(world.hardware.scroll(.fingers(.began)) == nil)

        world.play(thumb.land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (12, 0)))
        #expect(world.launcher.switcher != nil)
        #expect(world.hardware.scroll(.fingers(.changed)) == nil)

        world.play(thumb.land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (12, 0)).lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pressVerdicts.isEmpty)
    }

    @Test func aLateSwipeScrollsOnlyUntilItBeginsThenStillsThePageThroughTheLiftAndItsMomentum() {
        let world = World.switcherWorld(accessGranted: true)
        let early = thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (2, 0))
        world.play(early)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)

        world.play(early.slide(byMM: (10, 0)))
        #expect(world.launcher.switcher != nil)
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)

        world.play(early.slide(byMM: (10, 0)).press().slide(byMM: (12, 0)).lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.hardware.scroll(.fingers(.ended)) == .passStill)
        #expect(world.hardware.scroll(.momentum(.began)) == .passStill)
        #expect(world.system.broughtToFront == [world.app("Slack")])
    }

    @Test func aSwipeFromAFreshThumbDropsScrollingBeforeDuringAndAfterTheSwitcher() {
        let world = World.switcherWorld(accessGranted: true)
        let hand = thumb.land(fingers: 2)
        world.play(hand)
        #expect(world.hardware.scroll(.fingers(.mayBegin)) == .drop)

        world.play(hand.slide(byMM: (3.5, 0)).slide(byMM: (12, 0)))
        #expect(world.hardware.scroll(.fingers(.changed)) == .drop)

        world.play(hand.slide(byMM: (3.5, 0)).slide(byMM: (12, 0)).lift())
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        #expect(world.hardware.scroll(.momentum(.began)) == .drop)
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func aFlickWithinTheWindowDoesNotCoastAfterTheLift() {
        let world = World.switcherWorld(accessGranted: true)
        let hand = thumb.land(fingers: 2).slide(byMM: (0, -20))
        world.play(hand)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        #expect(world.hardware.scroll(.fingers(.changed)) == .drop)

        world.play(hand.lift())
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        for momentum in [ScrollEvent.Momentum.began, .changed, .ended] {
            #expect(world.hardware.scroll(.momentum(momentum)) == .drop)
        }

        world.play(hand.lift().liftThumb())
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func coastingFromBeforeIsNotInterruptedWhenTheThumbLands() {
        let world = World.switcherWorld(accessGranted: true)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
        #expect(world.hardware.scroll(.fingers(.ended)) == .pass)
        #expect(world.hardware.scroll(.momentum(.began)) == .pass)

        world.play(thumb.land(fingers: 1))
        #expect(world.hardware.scroll(.momentum(.changed)) == .pass)
        #expect(world.hardware.scroll(.momentum(.ended)) == .pass)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
    }
}
