import Testing
import LauncherCore

/// A press held through a swipe or a window swipe: its drags are dropped for as long as the slide lasts, and move the
/// pointer everywhere else.
@MainActor @Suite struct PressedSwipeTests {
    private let h = HandFrames()
    private let trackpad = Trackpad.macBook14
    private let drag = PointerEvent.drag(button: 0)
    private var landed: TouchScript {
        TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2).wait(.milliseconds(20))
    }

    @Test func aPressedSwipeDropsTheHeldPressDragsAndRunsAsWithoutThePress() {
        let world = World.switcherWorld(accessGranted: true)
        let plain = World.switcherWorld(accessGranted: true)
        let hand = landed.press().slide(byMM: (3.5, 0)).slide(byMM: (12, 0))
        let unpressed = landed.slide(byMM: (3.5, 0)).slide(byMM: (12, 0))
        world.play(hand)
        plain.play(unpressed)

        #expect(world.launcher.switcher != nil)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect(world.launcher.switcher?.selectedApp.name == plain.launcher.switcher?.selectedApp.name)
        #expect(world.hardware.pressVerdicts == [.drop])
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.drop)))
        #expect(world.hardware.offer(.pointer(.pressure)) == .decided(.pointer(.drop)))
        #expect(world.hardware.isGatedPortOn)

        world.play(hand.lift())
        plain.play(unpressed.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront.map(\.name) == ["Mail"])
        #expect(world.system.broughtToFront.map(\.name) == plain.system.broughtToFront.map(\.name))
        #expect(world.hardware.feedback == [trackpad.id])
        #expect(world.hardware.feedback == plain.hardware.feedback)
        #expect(world.hardware.lightTicks.count == 1)
        #expect(world.hardware.lightTicks == plain.hardware.lightTicks)
    }

    @Test func aPressedWindowSwipeDropsTheHeldPressDrags() {
        let world = World.windowWorld(visible: ["One", "Two"])
        let hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30))
            .wait(.milliseconds(20)).press().slide(byMM: (0, 3.5)).slide(byMM: (0, 12))
        world.play(hand)
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)
        #expect(world.system.windows.raised == [[world.window("Two")]])
        #expect(world.hardware.pressVerdicts == [.drop])
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.drop)))

        world.play(hand.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.windows.onScreenTitles == ["Two", "One"])
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])
    }

    @Test func aPressedSwapSeriesStillMovesThePointer() {
        let world = World.switcherWorld(accessGranted: true)
        let series = world.swap(lift: false)
        let hand = series.press().slide(byMM: (12, 0))
        world.play(hand)
        #expect(world.system.broughtToFront.map(\.name) == ["Mail"])
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.pressVerdicts == [.drop])
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.passAsMove)))

        world.play(hand.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront.map(\.name) == ["Mail"])
    }

    @Test func aPressedSlideWithNoWindowSwipeStillMovesThePointer() {
        let world = World.windowWorld(visible: ["One"])
        let hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30))
            .wait(.milliseconds(20)).press().slide(byMM: (0, 3.5)).slide(byMM: (0, 12))
        world.play(hand)
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.pressVerdicts == [.drop])
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.passAsMove)))

        world.play(hand.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.windows.raised.isEmpty)
        #expect(world.hardware.pulses.isEmpty)
    }

    @Test func aPressHeldPastTheSwipesEndMovesThePointerAgain() {
        let world = World.switcherWorld(accessGranted: true)
        let thumbDown = h.contact(9, atMM: 10, 10)
        let frames: [(ms: Int, frame: TouchFrame)] = [
            (0, h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)])),
            (100, h.frame(atMS: 100, [thumbDown, h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)])),
            (110, h.frame(atMS: 110, [thumbDown, h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)], press: .click)),
            (120, h.frame(atMS: 120, [thumbDown, h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)], press: .click)),
            (130, h.frame(atMS: 130, [thumbDown, h.contact(1, atMM: 78, 45), h.contact(2, atMM: 86, 45)], press: .click)),
            (140, h.frame(atMS: 140, [thumbDown], press: .click)),
            (150, h.frame(atMS: 150)),
        ]
        var gated: [Int: Bool] = [:]
        var switcherShown: [Int: Bool] = [:]
        var drags: [Int: InMemoryTrackpads.Delivery] = [:]
        for (ms, frame) in frames {
            world.hardware.touch([frame], on: trackpad.id)
            gated[ms] = world.hardware.isGatedPortOn
            switcherShown[ms] = world.launcher.switcher != nil
            if ms == 130 || ms == 140 { drags[ms] = world.hardware.offer(.pointer(drag)) }
        }
        #expect(switcherShown[130] == true)
        #expect(switcherShown[140] == false)
        #expect(drags[130] == .decided(.pointer(.drop)))
        #expect(drags[140] == .decided(.pointer(.passAsMove)))
        #expect([100, 110, 120, 130, 140].allSatisfy { gated[$0] == true })
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront.map(\.name) == ["Mail"])
    }

    @Test func aSwipeOnOneTrackpadDropsTheDragsWithTheBlockingWindowStillOpenOnTheOther() {
        let apps = ["Safari", "Mail", "Slack", "Notes"]
        let world = World(apps: apps, attached: [.macBook14, .magicTrackpad], accessGranted: true)
        world.launcher.start()
        world.makeRunning(apps)
        world.makeFrontmost("Safari")
        let magic = HandFrames(Trackpad.magicTrackpad.surface)
        let magicThumb = magic.contact(9, atMM: 10, 10)

        world.hardware.touch(
            [h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
             h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
             h.frame(atMS: 110, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)], press: .click)],
            on: Trackpad.macBook14.id)
        let first = world.hardware.offer(.pointer(drag))

        let landing = [magic.contact(1, .landing, atMM: 62, 45), magic.contact(2, .landing, atMM: 70, 45)]
        world.hardware.touch(
            [magic.frame(atMS: 0, [magic.contact(9, .landing, atMM: 10, 10)], press: .click),
             magic.frame(atMS: 10, [magicThumb] + landing, press: .click),
             magic.frame(atMS: 20, [magicThumb, magic.contact(1, atMM: 66, 45), magic.contact(2, atMM: 74, 45)], press: .click),
             magic.frame(atMS: 30, [magicThumb, magic.contact(1, atMM: 78, 45), magic.contact(2, atMM: 86, 45)], press: .click)],
            on: Trackpad.magicTrackpad.id)
        let shown = world.launcher.switcher != nil
        let second = world.hardware.offer(.pointer(drag))

        world.hardware.touch([magic.frame(atMS: 40, [magicThumb], press: .click)], on: Trackpad.magicTrackpad.id)
        let ended = world.launcher.switcher == nil
        let third = world.hardware.offer(.pointer(drag))
        world.hardware.touch(
            [h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)])], on: Trackpad.macBook14.id)

        #expect(first == .decided(.pointer(.passAsMove)))
        #expect(shown)
        #expect(second == .decided(.pointer(.drop)))
        #expect(ended)
        #expect(third == .decided(.pointer(.passAsMove)))
        #expect(world.system.broughtToFront.map(\.name) == ["Mail"])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }

    @Test func aPressedSecondStepOfASwipeDropsTheDragsFromThenOn() {
        let world = World.switcherWorld(accessGranted: true)
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.pass)))
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        let pressed = hand.press().slide(byMM: (12, 0))
        world.play(pressed)
        #expect(world.launcher.switcher?.selectedApp.name == "Slack")
        #expect(world.hardware.pressVerdicts == [.drop])
        #expect(world.hardware.offer(.pointer(drag)) == .decided(.pointer(.drop)))

        world.play(pressed.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront.map(\.name) == ["Slack"])
    }
}
