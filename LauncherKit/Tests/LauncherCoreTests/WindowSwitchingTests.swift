import Testing
import LauncherCore

@MainActor @Suite struct WindowSwitchingTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func stack(_ world: World) -> [String] { world.system.windows.onScreenTitles }

    // MARK: Sliding

    @Test func eachWindowTheSelectionReachesComesToTheFrontAndSlidingBackBringsTheFrontWindowBack() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let down = world.windowSwipe(3.5, 12, lift: false)

        #expect(stack(world).first == "Mail")
        #expect(world.system.windows.raised == [[world.window("Mail")]])

        world.play(down.slide(byMM: (0, -12)))
        #expect(stack(world).first == "Docs")
        #expect(world.system.windows.raised == [[world.window("Mail")], [world.window("Docs")]])
    }

    @Test func passingAMinimisedWindowNeitherRestoresItNorChangesTheStack() {
        let world = World.windowWorld(visible: ["A", "B"], minimised: ["M"])
        let script = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)).slide(byMM: (0, 24))
            .slide(byMM: (0, -24))
        struct Seen { let selected: Int?, visible: [String], minimised: [String], raised: [[WindowID]] }

        let history = world.playFrameByFrame(script) {
            Seen(
                selected: world.launcher.windowSwitcher?.selection.selected, visible: world.system.windows.onScreenTitles,
                minimised: world.system.windows.minimisedTitles, raised: world.system.windows.raised)
        }

        let m = world.window("M")
        #expect(history.allSatisfy { !$0.raised.joined().contains(m) })
        #expect(history.allSatisfy { $0.minimised == ["M"] && !$0.visible.contains("M") })
        let reachedB = history.firstIndex { $0.selected == 1 }
        let reachedM = history.firstIndex { $0.selected == 2 }
        #expect(reachedB != nil && reachedM != nil)
        if let reachedB, let reachedM {
            #expect(history[reachedB...reachedM].allSatisfy { $0.visible == ["B", "A"] })
        }
        #expect(world.launcher.windowSwitcher?.selection.selected == 0)
        #expect(world.system.windows.onScreenTitles == ["A", "B"])
    }

    @Test func selectingAWindowThatClosedChangesNothingOnScreenAndItStaysListed() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let atMail = world.windowSwipe(3.5, 12, lift: false)
        let ticks = world.hardware.lightTicks.count

        world.system.windows.close("News")
        world.play(atMail.slide(byMM: (0, 12)))

        #expect(stack(world) == ["Mail", "Docs"])
        #expect(world.hardware.lightTicks.count == ticks + 1)
        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["Docs", "Mail", "News"])
        #expect(world.launcher.windowSwitcher?.selection.selected == 2)
    }

    // MARK: Lifting

    @Test func liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.openWindow()

        let lifted = world.windowSwipe(3.5, 24)

        #expect(stack(world) == ["News", "Docs", "Mail"])
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .lightTick, .gesture])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(!world.launcher.isWindowOpen)

        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)))
        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["News", "Docs", "Mail"])
        #expect(world.launcher.windowSwitcher?.selection.selected == 0)
    }

    @Test(arguments: ["back to the first row", "onto the second row", "one minimised window"])
    func withEveryWindowMinimisedLiftingRestoresTheSelectedOneWithTheHaptic(path: String) {
        let world = World.windowWorld(
            minimised: path == "one minimised window" ? ["X"] : ["X", "Y"], frontmost: "Finder")
        world.launcher.openWindow()

        let hand: TouchScript
        switch path {
        case "back to the first row": hand = world.windowSwipe(3.5, 12, -12, lift: false)
        case "onto the second row": hand = world.windowSwipe(3.5, 12, lift: false)
        default: hand = world.windowSwipe(3.5, lift: false)
        }
        #expect(world.system.windows.raised.isEmpty)
        #expect(stack(world).isEmpty)

        world.play(hand.lift())

        let restored = path == "onto the second row" ? "Y" : "X"
        #expect(stack(world) == [restored])
        #expect(world.system.windows.minimisedTitles == (path == "one minimised window" ? [] : [restored == "X" ? "Y" : "X"]))
        #expect(world.hardware.feedback.count == 1)
        #expect(!world.launcher.isWindowOpen)
    }

    @Test(arguments: ["no slide", "full-screen front window", "one window"])
    func liftingOnTheFrontWindowRaisesNothingAndIsSilent(world kind: String) {
        let world: World
        switch kind {
        case "no slide": world = .windowWorld(visible: ["Docs", "Mail", "News"])
        case "full-screen front window": world = .windowWorld(visible: ["Film", "Docs", "Mail"], fullScreenFront: true)
        default: world = .windowWorld(visible: ["Letter"], frontmost: "TextEdit")
        }
        world.launcher.openWindow()
        let before = stack(world)

        if kind == "no slide" { world.windowSwipe(3.5) } else { world.windowSwipe(3.5, 24) }

        #expect(world.system.windows.raised.allSatisfy { $0.isEmpty })
        #expect(world.system.windows.raised.count == 1)
        #expect(stack(world) == before)
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test func slidingAwayAndBackThenLiftingRestoresTheOrderSilently() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.openWindow()
        let hand = world.windowSwipe(3.5, lift: false)
        let down = hand.slide(byMM: (0, 24), over: .milliseconds(10))
        world.play(down)
        world.play(down.slide(byMM: (0, -24), over: .milliseconds(10)))
        #expect(stack(world) == ["Docs", "News", "Mail"])

        world.play(down.slide(byMM: (0, -24), over: .milliseconds(10)).lift())

        #expect(stack(world) == ["Docs", "Mail", "News"])
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test func liftingOnAMinimisedWindowRestoresItInFrontOfTheFrontWindowWithTheHaptic() {
        let world = World.windowWorld(visible: ["A", "B"], minimised: ["M"])

        world.windowSwipe(3.5, 24)

        #expect(stack(world) == ["M", "A", "B"])
        #expect(world.system.windows.minimisedTitles.isEmpty)
        #expect(world.hardware.feedback.count == 1)
    }

    @Test(arguments: [(slidesMM: [3.5, 12], stack: ["Docs", "News"], haptic: false),
                      (slidesMM: [3.5, 24, -12], stack: ["News", "Docs"], haptic: true)])
    func liftingOnAWindowThatClosedReordersNothingAndPlaysTheHapticOnlyIfTheFrontWindowChanged(
        slidesMM: [Double], stack expected: [String], haptic: Bool
    ) {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        var hand = thumb.land(fingers: 2, atMM: (62, 30))
        for slide in slidesMM { hand = hand.slide(byMM: (0, slide)) }
        world.play(hand)
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)
        let raisedWhileSliding = world.system.windows.raised.count

        world.system.windows.close("Mail")
        world.play(hand.lift())

        #expect(world.system.windows.raised.dropFirst(raisedWhileSliding).map(\.isEmpty) == [true])
        #expect(stack(world) == expected)
        #expect(world.hardware.feedback.isEmpty == !haptic)
    }

    @Test(arguments: [(slidesMM: [3.5, 12], stack: ["Mail", "Draft", "Docs", "News"], haptic: true),
                      (slidesMM: [3.5], stack: ["Docs", "Draft", "Mail", "News"], haptic: false)])
    func aWindowOpenedMidSwipeEndsJustBehindTheSelectedWindow(slidesMM: [Double], stack expected: [String], haptic: Bool) {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        var hand = thumb.land(fingers: 2, atMM: (62, 30))
        for slide in slidesMM { hand = hand.slide(byMM: (0, slide)) }
        world.play(hand)

        world.system.windows.open("Draft")
        world.play(hand.lift())

        #expect(stack(world) == expected)
        #expect(world.hardware.feedback.isEmpty == !haptic)
    }

    @Test func liftingOrdersTheWindowsEvenWhenRaisesWhileSlidingWereIgnored() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.system.windows.dropsRaises = true
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(stack(world).first == "Docs")

        world.system.windows.dropsRaises = false
        world.play(hand.lift())

        #expect(stack(world) == ["Mail", "Docs", "News"])
        #expect(world.system.windows.reads == 2)
        #expect(world.hardware.feedback.count == 1)
    }

    @Test(arguments: ["the app stops answering", "Notes becomes the frontmost app", "every listed window closes"])
    func whenTheSelectedWindowCannotBeReachedTheLiftChangesNothingAndIsSilent(change: String) {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.openWindow()
        let hand = world.windowSwipe(3.5, 12, lift: false)
        let raisedWhileSliding = world.system.windows.raised.count
        let before = stack(world)

        switch change {
        case "the app stops answering": world.system.windows.answers = false
        case "Notes becomes the frontmost app": world.makeFrontmost("Notes")
        default: for title in ["Docs", "Mail", "News"] { world.system.windows.close(title) }
        }
        world.play(hand.lift())

        #expect(world.system.windows.raised.dropFirst(raisedWhileSliding).map(\.isEmpty) == [true])
        #expect(stack(world) == (change == "every listed window closes" ? [] : before))
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test(arguments: ["no windows", "no frontmost app", "no Accessibility"])
    func liftingOnAMessageReadsNothingRaisesNothingAndIsSilent(world kind: String) {
        let world: World
        switch kind {
        case "no windows": world = .windowWorld(frontmost: "Finder")
        case "no frontmost app": world = .windowWorld(frontmost: nil)
        default: world = .windowWorld(visible: ["Docs", "Mail"], accessGranted: false)
        }

        world.windowSwipe(3.5, 24)

        #expect(world.system.windows.raised.isEmpty)
        #expect(world.system.windows.reads == 1)
        #expect(world.hardware.pulses.isEmpty)
    }

    // MARK: Cancelling

    @Test func aThirdFingerCancelsTheWindowSwipeAndKeepsTheWindowInFrontAsItIs() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.setAssignment(.app(world.app("Notes")), for: .one)
        let hand = world.windowSwipe(3.5, 24, -12, lift: false)
        #expect(stack(world) == ["Mail", "News", "Docs"])
        let pulses = world.hardware.pulses
        let raised = world.system.windows.raised

        let third = hand.wait(.milliseconds(10)).land(fingers: 1, atMM: (86, 45))
        let history = world.playFrameByFrame(third)
        #expect(history.last?.windowSwitcher == nil)

        let lifted = third.slide(byMM: (0, 12)).lift()
        world.play(lifted)
        #expect(stack(world) == ["Mail", "News", "Docs"])
        #expect(world.hardware.pulses == pulses)
        #expect(world.system.windows.raised == raised)
        #expect(world.system.windows.reads == 1)

        world.play(lifted.tap(fingers: 1))
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }
}
