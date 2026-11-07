import Foundation
import Testing
import LauncherCore

@Suite struct WindowOrdersTests {
    private let safari = AppEntry(
        bundleID: BundleID(rawValue: "com.test.safari"), name: "Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"))
    private let launch = AppLaunch("one")

    private func id(_ number: UInt32) -> WindowID { WindowID(rawValue: number) }

    private func window(_ number: UInt32) -> AppWindow { AppWindow(id: id(number), title: "W\(number)") }

    private func windows(visible: [UInt32], minimised: [UInt32] = []) -> AppWindows {
        AppWindows(visible: visible.map(window), minimised: minimised.map(window))
    }

    private func read(visible: [UInt32], minimised: [UInt32] = [], launch: AppLaunch? = nil) -> FrontmostWindows {
        .app(safari, launch ?? self.launch, .windows(windows(visible: visible, minimised: minimised)))
    }

    private func none(_ ids: Set<WindowID>) -> Set<WindowID> { [] }

    private func rows(_ content: WindowSwitcher.Content) -> WindowSwitcher.Rows? {
        if case .rows(let rows) = content.list { rows } else { nil }
    }

    private func card(_ content: WindowSwitcher.Content?) -> NoWindowsCard? {
        if case .card(let card)? = content?.list { card } else { nil }
    }

    // MARK: updated

    @Test func withoutAnOrderTheListIsVisibleFrontToBackThenMinimised() {
        let order = WindowOrders.updated(nil, with: windows(visible: [3, 1, 2], minimised: [9, 5]), stillOpen: none)
        #expect(order == [3, 1, 2, 9, 5].map(id))
    }

    @Test func aRememberedWindowTheReadDidNotListStaysWhileTheWindowServerHoldsIt() {
        let order = WindowOrders.updated(
            [1, 2, 3].map(id), with: windows(visible: [3, 1]), stillOpen: { $0.intersection([self.id(2)]) })
        #expect(order == [1, 2, 3].map(id))
    }

    @Test func aRememberedWindowTheWindowServerNoLongerHoldsLeaves() {
        let order = WindowOrders.updated([1, 2, 3].map(id), with: windows(visible: [3, 1]), stillOpen: none)
        #expect(order == [1, 3].map(id))
    }

    @Test func newWindowsJoinAtTheEndByRisingNumberWhateverTheirZOrder() {
        let order = WindowOrders.updated([1, 2].map(id), with: windows(visible: [7, 2, 5, 1]), stillOpen: none)
        #expect(order == [1, 2, 5, 7].map(id))
    }

    @Test func newWindowsJoinEvenWhenNothingRememberedIsLeft() {
        let order = WindowOrders.updated([1, 2].map(id), with: windows(visible: [9, 8]), stillOpen: none)
        #expect(order == [8, 9].map(id))
    }

    @Test func theWindowServerIsAskedOnlyAboutWhatTheReadDidNotList() {
        var asked: [Set<WindowID>] = []
        _ = WindowOrders.updated([1, 2, 3].map(id), with: windows(visible: [1], minimised: [3]), stillOpen: {
            asked.append($0)
            return $0
        })
        _ = WindowOrders.updated([1, 2].map(id), with: windows(visible: [2, 1]), stillOpen: {
            asked.append($0)
            return $0
        })
        #expect(asked == [[id(2)]])
    }

    // MARK: list

    @Test func theSameReadTwiceLeavesTheSameOrderAndGivesTheSameContent() {
        var orders = WindowOrders()
        let first = orders.list(read(visible: [2, 1, 3]), stillOpen: none)
        let second = orders.list(read(visible: [2, 1, 3]), stillOpen: none)

        #expect(first == second)
        #expect(orders.order(of: safari) == [2, 1, 3].map(id))
    }

    @Test func rowsFollowTheOrderAndStartOnTheWindowInFront() throws {
        var orders = WindowOrders()
        _ = orders.list(read(visible: [1, 2, 3]), stillOpen: none)

        let listing = orders.list(read(visible: [3, 1, 2]), stillOpen: none)
        let content = try #require(listing)

        #expect(rows(content)?.rows.map(\.window) == [1, 2, 3].map(id))
        #expect(rows(content)?.frontWindow == id(3))
    }

    @Test func aCountBelowTwoListsTheCardAndStillSetsTheOrder() {
        var orders = WindowOrders()

        let one = orders.list(read(visible: [4]), stillOpen: none)
        #expect(card(one)?.kind == .oneWindow)
        #expect(orders.order(of: safari) == [id(4)])

        let none = orders.list(read(visible: []), stillOpen: self.none)
        #expect(card(none)?.kind == .noWindows)
    }

    @Test func aLoneMinimisedWindowIsTheOneWindowCard() {
        var orders = WindowOrders()

        let content = orders.list(read(visible: [], minimised: [4]), stillOpen: none)

        #expect(card(content)?.kind == .oneWindow)
    }

    @Test func anotherLaunchStartsAnOrderOfItsOwn() {
        var orders = WindowOrders()
        _ = orders.list(read(visible: [1, 2, 3]), stillOpen: none)

        _ = orders.list(read(visible: [12, 10, 11], launch: AppLaunch("two")), stillOpen: none)

        #expect(orders.order(of: safari) == [12, 10, 11].map(id))
    }

    @Test func aReadThatDidNotAnswerTouchesNothingAndOurOwnIsTheOneWindowCard() {
        var orders = WindowOrders()
        _ = orders.list(read(visible: [1, 2]), stillOpen: none)

        #expect(orders.list(.app(safari, launch, .unanswered), stillOpen: none) == nil)
        #expect(card(orders.list(.app(safari, launch, .ownProcess), stillOpen: none))?.kind == .oneWindow)
        #expect(orders.list(.noApp, stillOpen: none) == nil)
        #expect(orders.order(of: safari) == [1, 2].map(id))
    }

    @Test func aMinimisedWindowKeepsItsRowAndShowsMinimised() throws {
        var orders = WindowOrders()
        _ = orders.list(read(visible: [1, 2, 3]), stillOpen: none)

        let listing = orders.list(read(visible: [3, 1], minimised: [2]), stillOpen: none)
        let content = try #require(listing)

        #expect(rows(content)?.rows.map(\.window) == [1, 2, 3].map(id))
        #expect(rows(content)?.rows[1] == .minimised(id(2), title: "W2"))
    }

    @Test func aWindowWithoutATitleReadsAsItsRow() throws {
        var orders = WindowOrders()
        let untitled = AppWindows(
            visible: [AppWindow(id: id(2), title: ""), window(1)], minimised: [])

        let listing = orders.list(.app(safari, launch, .windows(untitled)), stillOpen: none)
        let content = try #require(listing)

        #expect(rows(content)?.rows.map(\.title) == ["Safari — Window 1", "W1"])
    }

    // MARK: SwitcherSelection

    @Test func aSelectionCanStartOnALaterItem() {
        var selection = SwitcherSelection(count: 3, startingAt: 2)
        #expect(selection.selected == 2)
        #expect(selection.position == 2)
        #expect(selection.stretch == 0)

        #expect(selection.follow(0.5) == 0)
        #expect(selection.selected == 2)
        #expect(selection.stretch > 0)

        var back = SwitcherSelection(count: 3, startingAt: 2)
        #expect(back.follow(-6.1) == 1)
        #expect(back.selected == 1)
    }

    @Test func aStartPastEitherEndIsClamped() {
        #expect(SwitcherSelection(count: 3, startingAt: 5).selected == 2)
        #expect(SwitcherSelection(count: 3, startingAt: -1).selected == 0)
    }
}
