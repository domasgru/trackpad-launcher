import Testing
import LauncherCore

@MainActor @Suite struct WindowOrderTests {
    /// Window swipes on one world, each continuing the hand before it.
    @MainActor final class Swiper {
        struct Start {
            let rows: [String]
            let minimised: [String]
            let selected: Int?
        }

        let world: World
        private var last: TouchScript?

        init(_ world: World) { self.world = world }

        /// The thumb rests on the trackpad again, as a new `Launcher` first sees it.
        func restTheThumbAgain() { last = last?.liftThumb().thumb(atMM: (10, 10)) }

        /// A window swipe whose fingers slide `slideMM` after it begins, then lift. Returns the switcher as it began.
        @discardableResult
        func swipe(slidingMM slideMM: Double? = nil, lift: Bool = true) -> Start {
            let base = last ?? TouchScript(.macBook14).thumb(atMM: (10, 10))
            var hand = base.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5))
            world.play(hand)
            let switcher = world.launcher.windowSwitcher
            let start = Start(
                rows: switcher?.rows.map(\.title) ?? [],
                minimised: switcher?.rows.compactMap { if case .minimised(_, let title) = $0 { title } else { nil } } ?? [],
                selected: switcher?.selection.selected)
            if let slideMM {
                hand = hand.slide(byMM: (0, slideMM))
                world.play(hand)
            }
            if lift { hand = hand.lift() }
            world.play(hand)
            last = hand
            return start
        }
    }

    private func safariWorld(_ visible: [String], minimised: [String] = []) -> (World, Swiper) {
        let world = World.windowWorld(visible: visible, minimised: minimised)
        world.launcher.openedByHand()
        return (world, Swiper(world))
    }

    // MARK: The order survives

    @Test(arguments: [(slideMM: 24.0, selected: 2), (slideMM: 12.0, selected: 1)])
    func liftingOnAnotherRowKeepsTheOrderAndTheNextWindowSwipeStartsOnTheWindowInFront(slideMM: Double, selected: Int) {
        let (world, swiper) = safariWorld(["Docs", "Mail", "News"])

        swiper.swipe(slidingMM: slideMM)
        let next = swiper.swipe()

        #expect(next.rows == ["Docs", "Mail", "News"])
        #expect(next.selected == selected)
        #expect(world.system.windows.onScreenTitles.first == ["Docs", "Mail", "News"][selected])
    }

    enum Intervention: String, CaseIterable, Sendable {
        case focusesB = "focuses B"
        case focusesCThenA = "focuses C, then A"
        case minimisesB = "minimises B"
        case minimisesAndRestoresB = "minimises B and focuses it again"
        case hidesAndShowsTheApp = "hides and shows Safari"
        case swipesAndLiftsElsewhere = "swipes with Safari in the row"
    }

    @Test(arguments: Intervention.allCases)
    func nothingButAWindowOpeningOrClosingChangesTheOrder(_ intervention: Intervention) {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        let safari = world.system.windows

        switch intervention {
        case .focusesB: safari.focus("B")
        case .focusesCThenA:
            safari.focus("C")
            safari.focus("A")
        case .minimisesB: safari.minimise("B")
        case .minimisesAndRestoresB:
            safari.minimise("B")
            safari.focus("B")
        case .hidesAndShowsTheApp:
            safari.hide()
            safari.show()
        case .swipesAndLiftsElsewhere: swiper.swipe(slidingMM: 24)
        }
        let next = swiper.swipe()

        #expect(next.rows == ["A", "B", "C"])
        #expect(next.minimised == (intervention == .minimisesB ? ["B"] : []))
    }

    @Test func aNewWindowJoinsAtTheEndAndEachLaterOneAfterIt() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.focus("C")

        world.system.windows.open("D")
        let withD = swiper.swipe()
        #expect(withD.rows == ["A", "B", "C", "D"])
        #expect(withD.selected == 3)

        world.system.windows.open("E")
        world.system.windows.open("F")
        #expect(swiper.swipe().rows == ["A", "B", "C", "D", "E", "F"])
    }

    @Test func aClosedWindowLeavesAfterTheWindowServerIsAskedAboutItAlone() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        #expect(world.system.openWindowsQueries.isEmpty)
        let b = world.window("B")

        world.system.windows.close("B")
        #expect(swiper.swipe().rows == ["A", "C"])
        #expect(world.system.openWindowsQueries == [[b]])

        #expect(swiper.swipe().rows == ["A", "C"])
        #expect(world.system.openWindowsQueries == [[b]])
    }

    @Test func aWindowOnAnotherSpaceIsNotListedButKeepsItsPlace() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()

        world.system.windows.moveToAnotherSpace("B")
        #expect(swiper.swipe().rows == ["A", "C"])

        world.system.windows.returnToThisSpace("B")
        #expect(swiper.swipe().rows == ["A", "B", "C"])
    }

    @Test func aRelaunchedAppSetsAnOrderFromItsWindowsAsTheyAre() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.focus("C")

        world.quit("Safari")
        world.relaunch("Safari", created: ["A2", "B2", "C2"], front: ["C2", "A2", "B2"])

        #expect(swiper.swipe().rows == ["C2", "A2", "B2"])
    }

    @Test func restartingTrackpadAppForgetsTheOrderAndSavesNothing() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        let before = Set(world.suiteDomain().keys)
        swiper.swipe()
        #expect(Set(world.suiteDomain().keys) == before)
        world.system.windows.focus("C")

        world.relaunch().start()
        swiper.restTheThumbAgain()
        let start = swiper.swipe()

        #expect(start.rows == ["C", "A", "B"])
        #expect(Set(world.suiteDomain().keys) == before)
    }

    @Test func whenEveryRememberedWindowClosedNewOnesStillJoinTheOrderInTheirOwnOrder() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        let closed = Set(["A", "B", "C"].map(world.window))
        for title in ["A", "B", "C"] { world.system.windows.close(title) }

        world.system.windows.open("D")
        world.system.windows.open("E")
        let start = swiper.swipe()

        #expect(start.rows == ["D", "E"])
        #expect(start.selected == 1)
        #expect(world.system.openWindowsQueries == [closed])
    }

    // MARK: The selection starts on the window in front

    @Test func theSelectionStartsOnTheWindowInFrontAndLiftingThereChangesNothing() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.focus("C")
        let ticks = world.hardware.lightTicks.count
        let feedback = world.hardware.feedback.count

        let start = swiper.swipe()

        #expect(start.selected == 2)
        #expect(world.hardware.lightTicks.count == ticks)
        #expect(world.hardware.feedback.count == feedback)
        #expect(world.system.windows.raised.allSatisfy { $0.isEmpty })
        #expect(world.system.windows.onScreenTitles == ["C", "A", "B"])
    }

    @Test func slidingUpOneRowAndLiftingPutsTheSelectedWindowInFrontOfTheOneThatWas() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.focus("C")
        let before = world.hardware.pulses.count

        swiper.swipe(slidingMM: -12)

        #expect(world.system.windows.onScreenTitles == ["B", "C", "A"])
        #expect(world.hardware.pulses.dropFirst(before).map(\.haptic) == [.lightTick, .gesture])
    }

    @Test func slidingPastTheEndAndLiftingRaisesNothing() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.focus("C")
        let before = world.hardware.pulses.count

        swiper.swipe(slidingMM: 30)

        #expect(world.system.windows.onScreenTitles == ["C", "A", "B"])
        #expect(world.system.windows.raised.allSatisfy { $0.isEmpty })
        #expect(world.hardware.pulses.count == before)
    }

    @Test func withEveryWindowMinimisedTheSelectionStartsOnTheFirstRow() {
        let (_, swiper) = safariWorld([], minimised: ["A", "B"])

        let start = swiper.swipe(lift: false)

        #expect(start.rows == ["A", "B"])
        #expect(start.selected == 0)
    }

    @Test func aMinimisedWindowLiftedOnIsRestoredAndTheNextWindowSwipeStartsOnIt() {
        let (world, swiper) = safariWorld(["A", "B", "C"])
        swiper.swipe()
        world.system.windows.minimise("B")
        let before = world.hardware.feedback.count

        swiper.swipe(slidingMM: 12)

        #expect(world.system.windows.minimisedTitles.isEmpty)
        #expect(world.system.windows.onScreenTitles == ["B", "A", "C"])
        #expect(world.hardware.feedback.count == before + 1)

        let next = swiper.swipe()
        #expect(next.rows == ["A", "B", "C"])
        #expect(next.minimised.isEmpty)
        #expect(next.selected == 1)
    }

    // MARK: More than ten windows

    @Test func theTenPickedByTheOldRuleAreListedInTheOrderAndTheSelectionStartsOnTheFrontOne() {
        let names = (1...12).map { "W\($0)" }
        let (world, swiper) = safariWorld(names)
        swiper.swipe()
        world.system.windows.minimise("W1")
        world.system.windows.minimise("W2")
        world.system.windows.focus("W12")

        let start = swiper.swipe()

        #expect(start.rows == Array(names[2...]))
        #expect(start.selected == 9)
    }
}
