import Testing
import LauncherCore

@MainActor @Suite struct WindowSwitcherOnScreenTests {
    private let trackpad = Trackpad.macBook14
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func titles(_ world: World) -> [String]? { world.launcher.windowSwitcher?.rows.map(\.title) }

    private func selected(_ world: World) -> Int? { world.launcher.windowSwitcher?.selection.selected }

    // MARK: Appearing

    @Test func theWindowSwitcherAppearsOnTheFrameTheWindowSwipeBeginsWithTheFrontWindowSelected() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let script = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))

        let history = world.playFrameByFrame(script) {
            (windowSwitcher: world.launcher.windowSwitcher, switcher: world.launcher.switcher,
             reads: world.system.windows.reads, answers: world.hardware.windowSwipeAnswers)
        }

        let beganAt = perFrame(script.frames).firstIndex { $0.windowSwipe == .began }
        #expect(beganAt != nil)
        #expect(history.firstIndex { $0.windowSwitcher != nil } == beganAt)
        #expect(history.prefix(beganAt ?? 0).allSatisfy { $0.reads == 0 })
        #expect(beganAt.map { history[$0].reads } == 1)
        #expect(beganAt.map { history[$0].answers } == [true])
        let shown = world.launcher.windowSwitcher
        #expect(shown?.rows.map(\.title) == ["Docs", "Mail", "News"])
        #expect(shown?.selection.selected == 0)
        #expect(shown?.frontWindow == world.window("Docs"))
        #expect(shown?.app == world.app("Safari"))
        #expect(history.allSatisfy { $0.switcher == nil })
        #expect(world.system.windows.reads == 1)
    }

    @Test func theWindowSwitcherShowsForTheWholeWindowSwipeAndGoesOnTheLiftFrame() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let first = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 24)).slide(byMM: (0, -12)).lift()
        let second = first.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 24)).lift()

        let history = world.playFrameByFrame(second)

        let seen = perFrame(second.frames)
        var serials: [Int] = []
        let begins = seen.indices.filter { seen[$0].windowSwipe == .began }
        let ends = seen.indices.filter { seen[$0].windowSwipe == .ended }
        #expect(begins.count == 2 && ends.count == 2)
        for (began, ended) in zip(begins, ends) {
            #expect(history[began..<ended].allSatisfy { $0.windowSwitcher != nil })
            let serial = history[began].windowSwitcher?.serial
            #expect(history[began..<ended].allSatisfy { $0.windowSwitcher?.serial == serial })
            serials.append(serial ?? -1)
        }
        let shownAt = Set(begins.flatMap { began in ends.first { $0 > began }.map { Array(began..<$0) } ?? [] })
        #expect(history.indices.filter { !shownAt.contains($0) }.allSatisfy { history[$0].windowSwitcher == nil })
        #expect(serials[1] > serials[0])
    }

    // MARK: The list

    @Test(arguments: [
        (visible: 14, minimised: 0, rows: (1...10).map { "W\($0)" }),
        (visible: 10, minimised: 0, rows: (1...10).map { "W\($0)" }),
        (visible: 11, minimised: 0, rows: (1...10).map { "W\($0)" }),
        (visible: 9, minimised: 3, rows: (1...10).map { "W\($0)" }),
        (visible: 0, minimised: 12, rows: (1...10).map { "W\($0)" }),
    ])
    func theListIsCutAtTenWithTheVisibleWindowsFirst(visible: Int, minimised: Int, rows: [String]) {
        let names = (1...(visible + minimised)).map { "W\($0)" }
        let world = World.windowWorld(visible: Array(names.prefix(visible)), minimised: Array(names.dropFirst(visible)))

        world.windowSwipe(3.5, lift: false)

        let shown = world.launcher.windowSwitcher?.rows
        #expect(shown?.map(\.title) == rows)
        #expect(shown?.filter { if case .minimised = $0 { true } else { false } }.count == max(0, 10 - visible))
    }

    @Test func theListIsFixedWhenTheWindowSwipeBegins() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let hand = world.windowSwipe(3.5, lift: false)

        world.system.windows.open("Draft")
        world.system.windows.close("Mail")
        world.makeFrontmost("Notes")
        world.play(hand.slide(byMM: (0, 12)))

        #expect(titles(world) == ["Docs", "Mail"])
        #expect(selected(world) == 1)
        #expect(world.system.windows.reads == 1)
    }

    @Test func minimisedWindowsComeLastAsMinimisedRows() {
        let world = World.windowWorld(visible: ["Home", "Desktop"], minimised: ["Downloads"], frontmost: "Finder")

        world.windowSwipe(3.5, lift: false)

        #expect(
            world.launcher.windowSwitcher?.rows == [
                .visible(world.window("Home"), title: "Home"), .visible(world.window("Desktop"), title: "Desktop"),
                .minimised(world.window("Downloads"), title: "Downloads"),
            ])
        #expect(world.launcher.windowSwitcher?.app == world.app("Finder", in: world.coreServices))
    }

    @Test(arguments: [
        (visible: ["U1", "U2"], rows: ["Preview — Window 1", "Preview — Window 2"]),
        (visible: ["Notes.pdf", "U1"], rows: ["Notes.pdf", "Preview — Window 2"]),
    ])
    func anUntitledWindowReadsAsTheAppNumberedByItsRow(visible: [String], rows: [String]) {
        let world = World.windowWorld(visible: visible, untitled: ["U1", "U2"], frontmost: "Preview")

        world.windowSwipe(3.5, lift: false)

        #expect(titles(world) == rows)
    }

    // MARK: The selection

    @Test func theSelectionMovesOneRowPerTwelveMillimetresAtTheHalfwayPointWithOneTickEach() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.windowSwipe(3.5, 5.55, lift: false)
        #expect(selected(world) == 0)
        #expect(world.hardware.lightTicks.isEmpty)

        let past = hand.slide(byMM: (0, 0.2))
        world.play(past)
        #expect(selected(world) == 1)
        #expect(world.hardware.lightTicks.count == 1)

        let further = past.slide(byMM: (0, 12))
        world.play(further)
        #expect(selected(world) == 2)
        #expect(world.hardware.lightTicks.count == 2)

        world.play(further.slide(byMM: (0, -12)))
        #expect(selected(world) == 1)
        #expect(world.hardware.lightTicks == [trackpad.id, trackpad.id, trackpad.id])
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
    }

    @Test func oneFrameCrossingTwoRowsTicksTwice() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.windowSwipe(3.5, lift: false)

        let history = world.playFrameByFrame(hand.slide(byMM: (0, 24), over: .milliseconds(10)))

        #expect(history.count == 1)
        #expect(selected(world) == 2)
        #expect(world.hardware.lightTicks.count == 2)
    }

    @Test func turningBackFromPastTheLastRowMovesTheSelectionHalfARowAfterTheTurn() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let pushed = world.windowSwipe(3.5, 12, 30, lift: false)
        #expect(selected(world) == 1)
        #expect((world.launcher.windowSwitcher?.selection.stretch ?? 0) > 0)
        #expect(world.hardware.lightTicks.count == 1)

        let turned = pushed.slide(byMM: (0, -5.9))
        world.play(turned)
        #expect(selected(world) == 1)

        world.play(turned.slide(byMM: (0, -0.2)))
        #expect(selected(world) == 0)
        #expect(world.hardware.lightTicks.count == 2)
    }

    @Test func turningBackFromPastTheFirstRowMovesTheSelectionHalfARowAfterTheTurn() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        let pushed = world.windowSwipe(-3.5, -30, lift: false)
        #expect(selected(world) == 0)
        #expect((world.launcher.windowSwitcher?.selection.stretch ?? 0) < 0)

        world.play(pushed.slide(byMM: (0, 6.1)))
        #expect(selected(world) == 1)
    }

    // MARK: One kind per slide

    @Test func sidewaysDriftDuringAWindowSwipeMovesNothingAndShowsNoAppSwitcher() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(selected(world) == 1)

        let history = world.playFrameByFrame(hand.slide(byMM: (20, 0)))

        #expect(history.allSatisfy { $0.switcher == nil && $0.windowSwitcher?.selection.selected == 1 })
        #expect(world.hardware.lightTicks.count == 1)
    }

    @Test func verticalDriftDuringASwipeMovesNothingAndShowsNoWindowSwitcher() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        let history = world.playFrameByFrame(hand.slide(byMM: (0, 20)))

        #expect(history.allSatisfy { $0.windowSwitcher == nil && $0.switcher?.selectedApp.name == "Mail" })
        #expect(world.system.windows.reads == 0)
    }

    // MARK: The thumb and the fingers

    @Test func theThumbLiftingChangesNothingAndARejoiningFingerKeepsSteering() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(selected(world) == 1)

        let thumbless = hand.liftThumb().slide(byMM: (0, 12))
        let thumblessHistory = world.playFrameByFrame(thumbless)
        #expect(selected(world) == 2)

        let rejoined = thumbless.lift(.first).land(fingers: 1, atMM: (62, 57.5)).slide(byMM: (0, -12))
        let rejoinedHistory = world.playFrameByFrame(rejoined)

        #expect((thumblessHistory + rejoinedHistory).allSatisfy { $0.windowSwitcher != nil })
        #expect(selected(world) == 1)
    }

    @Test func leftHandedTheSameSlideDownReachesTheNextWindow() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setHandMode(.left)

        world.windowSwipe(3.5, 12, lift: false, thumbAtMM: (114.8, 10))

        #expect(titles(world) == ["Docs", "Mail"])
        #expect(selected(world) == 1)
        #expect(world.hardware.lightTicks.count == 1)
    }

    @Test func aTwoFingerTapThatDriftsTwoMillimetresDownStaysATap() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)

        let history = world.playFrameByFrame(thumb.tap(fingers: 2, atMM: (62, 30), dragMM: (0, 2)))

        #expect(history.allSatisfy { $0.windowSwitcher == nil })
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.gesture])
        #expect(world.system.windows.reads == 0)
    }

    // MARK: One switcher at a time, and gestures inactive

    @Test func eventsFromASecondTrackpadNeverTouchTheWindowSwitcherUp() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"], attached: [.macBook14, .magicTrackpad])
        let magic = Trackpad.magicTrackpad.id
        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(selected(world) == 1)

        world.hardware.inject(.swipe(SwipeEvent(phase: .began, trackpad: magic)))
        #expect(world.launcher.switcher == nil)
        world.hardware.inject(.windowSwipe(SwipeEvent(phase: .moved(travelMM: 24), trackpad: magic)))
        #expect(selected(world) == 1)
        world.hardware.inject(.windowSwipe(SwipeEvent(phase: .ended, trackpad: magic)))
        world.hardware.inject(.windowSwipe(SwipeEvent(phase: .cancelled, trackpad: magic)))
        #expect(world.launcher.windowSwitcher?.trackpad == trackpad.id)
        #expect(selected(world) == 1)
        #expect(world.hardware.lightTicks.count == 1)

        world.play(hand.lift())
        #expect(world.launcher.windowSwitcher == nil)
    }

    @Test func aWindowSwipeFromASecondTrackpadWhileTheAppSwitcherIsUpRunsItsCourseWithNoSwitcher() {
        let world = World.windowWorld(visible: ["Docs", "Mail"], attached: [.macBook14, .magicTrackpad])
        world.swipe(3.5, lift: false)
        let appSwitcher = world.launcher.switcher
        #expect(appSwitcher != nil)

        let magic = TouchScript(Trackpad.magicTrackpad.surface).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30))
            .slide(byMM: (0, 20))
        let history = world.playFrameByFrame(magic, on: .magicTrackpad)

        #expect(history.allSatisfy { $0.windowSwitcher == nil && $0.switcher == appSwitcher })
        #expect(world.system.windows.reads == 1)
        #expect(world.hardware.windowSwipeAnswers == [true])
    }

    @Test func whileGesturesAreInactiveAWindowSwipeShowsNothingEvenIfOneWasInFlight() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        world.windowSwipe(3.5, 12, lift: false)
        #expect(world.launcher.windowSwitcher == nil)

        world.hardware.inject(.windowSwipe(SwipeEvent(phase: .began, trackpad: trackpad.id)))
        #expect(world.launcher.windowSwitcher == nil)
        #expect(world.system.windows.reads == 0)
    }
}
