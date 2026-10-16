import Testing
import LauncherCore

@MainActor @Suite struct WindowSwipeBlockingTests {
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    @Test func aWindowSwipeFromAFreshThumbDropsScrollingBeforeDuringAndAfterTheSwitcher() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let hand = thumb.land(fingers: 2, atMM: (62, 30))
        world.play(hand)
        #expect(world.hardware.scroll(.fingers(.mayBegin)) == .drop)

        world.play(hand.slide(byMM: (0, 3.5)).slide(byMM: (0, 12)))
        #expect(world.launcher.windowSwitcher != nil)
        #expect(world.hardware.scroll(.fingers(.changed)) == .drop)

        world.play(hand.slide(byMM: (0, 3.5)).slide(byMM: (0, 12)).lift())
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        #expect(world.hardware.scroll(.momentum(.began)) == .drop)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func aLateWindowSwipeScrollsOnlyUntilItBeginsThenStillsThePageThroughTheLift() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let early = thumb.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 2))
        world.play(early)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)

        world.play(early.slide(byMM: (0, 10)))
        #expect(world.launcher.windowSwitcher != nil)
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)

        world.play(early.slide(byMM: (0, 10)).press().lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.hardware.scroll(.fingers(.ended)) == .passStill)
        #expect(world.hardware.scroll(.momentum(.began)) == .passStill)
    }

    @Test func aPressOnTheFrameAfterALateStartPassesAndCancelsTheWindowSwipeSilently() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.setAssignment(.app(world.app("Notes")), for: .one)
        let begin = thumb.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5))
        let pressed = begin.press().slide(byMM: (0, 12)).lift()
        let frames = pressed.frames
        let beganAt = perFrame(frames).firstIndex { $0.windowSwipe == .began }!
        #expect(frames[beganAt].press == nil && frames[beganAt + 1].press != nil)

        let history = world.playFrameByFrame(pressed) {
            (windowSwitcher: world.launcher.windowSwitcher, pulses: world.hardware.pulses.count)
        }

        #expect(history[beganAt].windowSwitcher != nil)
        #expect(history[(beganAt + 1)...].allSatisfy { $0.windowSwitcher == nil && $0.pulses == 0 })
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.system.windows.raised.isEmpty)
        #expect(world.system.windows.reads == 1)
        #expect(world.system.broughtToFront.isEmpty)

        world.play(pressed.tap(fingers: 1))
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func withAccessibilityAPressDuringTheWindowSwipeIsDroppedAndTheSelectionFollowsOn() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)

        let pressed = hand.press().slide(byMM: (0, 12))
        world.play(pressed)
        #expect(world.launcher.windowSwitcher?.selection.selected == 2)

        world.play(pressed.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }
}

@MainActor @Suite struct WindowSwipeSettingTests {
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    @Test(arguments: ["window swipe off", "swipe off", "wake"])
    func aChangeMidWindowSwipeRemovesTheSwitcherAndTheFingersDoNothingUntilTheyLift(change: String) {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.setAssignment(.app(world.app("Notes")), for: .one)
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)
        let pulses = world.hardware.pulses

        switch change {
        case "window swipe off": world.launcher.setWindowSwipe(on: false)
        case "swipe off": world.launcher.setSwipe(on: false)
        default: world.hardware.wake()
        }
        #expect(world.launcher.windowSwitcher == nil)

        let lifted = hand.slide(byMM: (0, 24)).lift()
        world.play(lifted)
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.hardware.pulses == pulses)
        #expect(world.system.windows.reads == 1)

        world.play(lifted.tap(fingers: 1))
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func withTheWindowSwipeOffASlideDownShowsNothingAndScrollsOnlyAfterTheBlockingWindow() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setWindowSwipe(on: false)
        #expect(!world.launcher.isWindowSwipeOn)

        let early = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 20))
        world.play(early)
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        let pressedEarly = early.press().lift()
        world.play(pressedEarly)

        let late = pressedEarly.liftThumb().thumb(atMM: (10, 10)).wait(.seconds(4)).land(fingers: 2, atMM: (62, 30))
            .slide(byMM: (0, 20))
        world.play(late)
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
        world.play(late.press().lift())

        #expect(world.hardware.pressVerdicts == [.drop, .drop, .pass, .pass])
        #expect(world.system.windows.reads == 0)
        #expect(world.hardware.pulses.isEmpty)
    }

    @Test func withTheSwipeOffAndTheWindowSwipeOnOnlyTheSlideDownShowsASwitcher() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setSwipe(on: false)

        let vertical = world.windowSwipe(3.5, lift: false)
        #expect(world.launcher.windowSwitcher != nil)
        let sideways = vertical.lift().land(fingers: 2).slide(byMM: (20, 0))
        world.play(sideways)
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.launcher.switcher == nil)
    }

    @Test func withTheWindowSwipeOffTheSwipeAndTheSwapStillWork() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setWindowSwipe(on: false)

        let sideways = world.swipe(3.5, lift: false)
        #expect(world.launcher.switcher != nil)
        world.play(sideways.lift().liftThumb())

        let swapping = World.windowWorld(visible: ["Docs", "Mail"])
        swapping.launcher.setWindowSwipe(on: false)
        swapping.swap()
        #expect(swapping.system.broughtToFront == [swapping.app("Mail")])
    }

    @Test func turningTheWindowSwipeOffAndOnLeavesTheOtherSettingsAlone() {
        let world = World.windowWorld()
        world.launcher.setSwipe(on: false)

        world.launcher.setWindowSwipe(on: false)
        world.launcher.setWindowSwipe(on: true)

        #expect(world.launcher.isWindowSwipeOn)
        #expect(!world.launcher.isSwipeOn)
        #expect(world.launcher.isSwapOn)
    }
}
