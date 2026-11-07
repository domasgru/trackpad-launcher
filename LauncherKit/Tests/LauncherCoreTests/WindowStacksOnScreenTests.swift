import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct WindowStacksOnScreenTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func give(_ world: World, _ name: String, windows count: Int, answering: FakeWindows.Answering = .now) {
        world.windows(of: name).set(visible: (0..<count).map { "\(name)\($0)" }, answering: answering)
    }

    private func stack(_ windows: Int) -> SlotStack { .stack(WindowStack(windows: windows)!) }

    /// Each slot leaves `.pending` at most once, and never changes after.
    private func settlesOnce(_ states: [[SlotStack]]) -> Bool {
        guard let slots = states.first?.indices else { return true }
        return slots.allSatisfy { slot in
            let column = states.map { $0[slot] }
            guard let settled = column.firstIndex(where: { $0 != .pending }) else { return true }
            return column[settled...].allSatisfy { $0 == column[settled] }
        }
    }

    // MARK: Counting

    @Test(arguments: [false, true])
    func appsWithSeveralWindowsShowStacksWhateverTheWindowSwipeSetting(windowSwipeOn: Bool) {
        let world = World.switcherWorld(accessGranted: true)
        world.launcher.setWindowSwipe(on: windowSwipeOn)
        give(world, "Safari", windows: 2)
        give(world, "Mail", windows: 3)
        give(world, "Slack", windows: 7)
        give(world, "Notes", windows: 1)

        world.swipe(3.5, lift: false)

        #expect(world.launcher.switcher?.stacks == [stack(2), stack(3), stack(4), .alone])
    }

    @Test func twoRunningCopiesOfOneBundleAreCountedEachFromItsOwnCopy() {
        let world = World(apps: ["Safari", "Slack"], accessGranted: true)
        world.launcher.start()
        world.install("Slack", in: world.downloads)
        let applicationsCopy = world.app("Slack")
        let downloadsCopy = world.app("Slack", in: world.downloads)
        world.makeRunning([world.app("Safari"), applicationsCopy, downloadsCopy])
        world.system.frontmost = downloadsCopy
        world.system.windows(of: downloadsCopy).set(visible: ["only"])
        world.system.windows(of: applicationsCopy).set(visible: ["a", "b", "c"])

        world.swipe(3.5, lift: false)

        #expect(world.launcher.switcher?.row.map(\.url) == [downloadsCopy.url, world.app("Safari").url, applicationsCopy.url])
        #expect(world.launcher.switcher?.stacks == [.alone, .alone, stack(3)])
    }

    enum Listing: String, CaseIterable, Sendable {
        case oneVisibleOneMinimised, threeVisible, oneVisibleTwoOnAnotherSpace, none, tenVisibleTwoMinimised
        case fullScreenFrontWithTwoOthers

        var stack: Int? {
            switch self {
            case .oneVisibleOneMinimised: 2
            case .threeVisible: 3
            case .tenVisibleTwoMinimised: 4
            case .oneVisibleTwoOnAnotherSpace, .none, .fullScreenFrontWithTwoOthers: nil
            }
        }

        var rows: Int? {
            switch self {
            case .oneVisibleOneMinimised: 2
            case .threeVisible: 3
            case .tenVisibleTwoMinimised: 10
            case .oneVisibleTwoOnAnotherSpace, .none, .fullScreenFrontWithTwoOthers: nil
            }
        }

        @MainActor func list(_ world: World) {
            let safari = world.system.windows
            switch self {
            case .oneVisibleOneMinimised: safari.set(visible: ["A"], minimised: ["B"])
            case .threeVisible: safari.set(visible: ["A", "B", "C"])
            case .oneVisibleTwoOnAnotherSpace:
                safari.set(visible: ["A", "B", "C"])
                safari.moveToAnotherSpace("B")
                safari.moveToAnotherSpace("C")
            case .none: safari.set(visible: [])
            case .tenVisibleTwoMinimised:
                safari.set(visible: (1...10).map { "V\($0)" }, minimised: ["M1", "M2"])
            case .fullScreenFrontWithTwoOthers: safari.set(visible: ["A", "B", "C"], fullScreenFront: true)
            }
        }
    }

    @Test(arguments: Listing.allCases)
    func aStackCountsWhatTheWindowSwitcherListsForTheSameWindows(_ listing: Listing) {
        let world = World.windowWorld()
        listing.list(world)

        let hand = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(hand)
        let slot = world.launcher.switcher?.stacks.first
        world.play(hand.lift())

        #expect(slot == listing.stack.map(stack) ?? .alone)

        let slide = hand.lift().wait(.milliseconds(500)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))
        world.play(slide)
        let windowSwitcher = world.launcher.windowSwitcher
        #expect(windowSwitcher != nil)
        #expect(windowSwitcher?.rows.count == (listing.rows ?? 0))
        #expect(windowSwitcher?.isCard == (listing.rows == nil))
    }

    // MARK: Accessibility

    @Test func withoutAccessibilityNothingIsReadAndEverySlotStaysPending() {
        let world = World.switcherWorld(accessGranted: false)
        give(world, "Safari", windows: 2)
        let script = thumb.land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (12, 0)).slide(byMM: (12, 0)).lift()

        let history = world.playFrameByFrame(script) { world.launcher.switcher?.stacks }

        #expect(world.system.countReads.isEmpty)
        #expect(history.contains { $0 != nil })
        #expect(history.compactMap { $0 }.allSatisfy { $0 == Array(repeating: .pending, count: 4) })
    }

    // MARK: Never waiting

    @Test func aSlowAppDoesNotHoldTheSwitcherOrTheOtherStacksAndItsStackAppearsWhenItAnswers() {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], accessGranted: true)
        give(world, "Safari", windows: 2)
        give(world, "Mail", windows: 2, answering: .held)
        give(world, "Notes", windows: 1)
        var atRead: [Switcher?] = []
        world.system.onReadWindows = { [unowned world] in atRead.append(world.launcher.switcher) }
        var states: [[SlotStack]] = []
        func note() { if let stacks = world.launcher.switcher?.stacks { states.append(stacks) } }

        let begin = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        for _ in world.playFrameByFrame(begin, observing: { note() }) {}

        #expect(atRead.count == 1)
        #expect(atRead.first??.stacks == [.pending, .pending, .pending])
        #expect(world.system.countReads.first?.apps.map(\.name) == ["Safari", "Mail", "Notes"])
        #expect(world.system.countReads.first?.deadline == .milliseconds(200))
        #expect(world.launcher.switcher?.stacks == [stack(2), .pending, .alone])

        let slid = begin.slide(byMM: (12, 0))
        world.play(slid)
        note()
        world.answerCountReads(of: "Mail")
        note()

        #expect(world.launcher.switcher?.stacks == [stack(2), stack(2), .alone])
        #expect(settlesOnce(states))
    }

    @Test func anAppThatNeverAnswersStaysPendingForTheWholeSwipeAndHoldsNothingUp() {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], accessGranted: true)
        give(world, "Safari", windows: 2)
        give(world, "Mail", windows: 2, answering: .never)
        give(world, "Notes", windows: 2)
        let script = thumb.land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (12, 0)).slide(byMM: (12, 0)).lift()

        let history = world.playFrameByFrame(script) { world.launcher.switcher?.stacks }

        let shown = history.compactMap { $0 }
        #expect(shown.count >= 3)
        #expect(shown.allSatisfy { $0 == [stack(2), .pending, stack(2)] })
        #expect(history.last! == nil)
    }

    @Test func anAppThatGivesUpIsAloneFromThenOnAndTheOthersDoNotChange() {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], accessGranted: true)
        give(world, "Safari", windows: 2)
        give(world, "Mail", windows: 2, answering: .held)
        give(world, "Notes", windows: 2)
        let hand = world.swipe(3.5, lift: false)
        #expect(world.launcher.switcher?.stacks == [stack(2), .pending, stack(2)])

        world.giveUpCountReads(of: "Mail")

        #expect(world.launcher.switcher?.stacks == [stack(2), .alone, stack(2)])
        world.play(hand.slide(byMM: (12, 0)))
        #expect(world.launcher.switcher?.stacks == [stack(2), .alone, stack(2)])
    }

    @Test func aWindowThatOpensOrClosesMidSwipeChangesNoStack() {
        let world = World.switcherWorld(apps: ["Safari", "Notes"], accessGranted: true)
        give(world, "Notes", windows: 1)
        give(world, "Safari", windows: 2)
        let hand = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        var states: [[SlotStack]] = []

        for _ in world.playFrameByFrame(hand, observing: { states.append(world.launcher.switcher?.stacks ?? []) }) {}
        world.windows(of: "Notes").open("second")
        world.windows(of: "Safari").close("Safari1")
        let rest = hand.slide(byMM: (12, 0)).lift()
        for _ in world.playFrameByFrame(rest, observing: { states.append(world.launcher.switcher?.stacks ?? []) }) {}

        let shown = states.filter { !$0.isEmpty }
        #expect(!shown.isEmpty)
        #expect(shown.allSatisfy { $0 == [stack(2), .alone] })
        #expect(world.system.countReads.count == 1)
    }

    @Test func aCountReadForAnEarlierSwipeNeverLandsInALaterOne() {
        let world = World.switcherWorld(apps: ["Safari", "Mail"], accessGranted: true)
        give(world, "Safari", windows: 1)
        give(world, "Mail", windows: 2, answering: .held)
        let first = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(first)
        world.play(first.lift())
        #expect(world.launcher.switcher == nil)

        world.windows(of: "Mail").open("third")
        let second = first.lift().wait(.milliseconds(500)).land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(second)
        #expect(world.launcher.switcher?.stacks == [.alone, .pending])
        #expect(world.system.countReads.count == 2)

        world.answerCountReads(of: "Mail")

        #expect(world.launcher.switcher?.stacks == [.alone, stack(3)])
    }

    @Test func aHeldReadAnsweredAfterTheLiftOrAfterASettingRemovedTheSwitcherLeavesNoSwitcher() {
        let lifted = World.switcherWorld(apps: ["Safari", "Mail"], accessGranted: true)
        give(lifted, "Mail", windows: 2, answering: .held)
        let hand = lifted.swipe(3.5, lift: false)
        lifted.play(hand.lift())
        lifted.answerCountReads(of: "Mail")
        #expect(lifted.launcher.switcher == nil)

        let removed = World.switcherWorld(apps: ["Safari", "Mail"], accessGranted: true)
        give(removed, "Mail", windows: 2, answering: .held)
        removed.swipe(3.5, lift: false)
        removed.launcher.setSwipe(on: false)
        #expect(removed.launcher.switcher == nil)
        removed.answerCountReads(of: "Mail")
        #expect(removed.launcher.switcher == nil)
    }

    // MARK: Window order

    @Test func aCountReadDoesNotSetTheWindowOrder() {
        let world = World.windowWorld(visible: ["X", "Y"], frontmost: "Mail")

        let hand = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(hand)
        #expect(world.launcher.switcher?.stacks.first == stack(2))
        world.play(hand.lift())

        world.system.windows.focus("Y")
        let slide = hand.lift().wait(.milliseconds(500)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))
        world.play(slide)

        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["Y", "X"])
    }
}
