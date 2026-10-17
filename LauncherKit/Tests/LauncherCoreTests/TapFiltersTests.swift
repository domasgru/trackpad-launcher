import LauncherCore
import Testing

@Suite struct TapFiltersTests {
    private let p = PressID(button: 0, number: 7)

    private func at(_ level: Blocking) -> TapContext { TapContext(blocking: level, scrollMayBeUnderWay: false) }

    private func decision(_ verdict: TapVerdict, _ gate: GateChange?) -> TapDecision {
        TapDecision(verdict: verdict, gate: gate)
    }

    /// Open, a press withheld and a scroll dropped.
    private func busy() -> TapFilters {
        var filters = TapFilters()
        _ = filters.follow(at(.clicks))
        _ = filters.decide(.pointer(.press(p)), in: at(.clicks))
        _ = filters.decide(.scroll(.fingers(.began)), in: at(.clicks))
        return filters
    }

    @Test func aFreshValueIsClosedAndHoldsNothing() {
        let filters = TapFilters()
        #expect(!filters.gateIsOpen)
        #expect(filters.holding == .nothing)
    }

    @Test func aDroppedScrollKeepsTheGateOpenThroughItsMomentumEnd() {
        var filters = TapFilters()
        #expect(filters.follow(at(.clicks)) == .open)
        #expect(filters.decide(.scroll(.fingers(.began)), in: at(.clicks)) == decision(.scroll(.drop), nil))
        #expect(filters.follow(at(.none)) == nil)
        #expect(filters.gateIsOpen)
        #expect(filters.decide(.scroll(.fingers(.ended)), in: at(.none)) == decision(.scroll(.drop), nil))
        #expect(filters.decide(.scroll(.momentum(.began)), in: at(.none)) == decision(.scroll(.drop), nil))
        #expect(filters.decide(.scroll(.momentum(.ended)), in: at(.none)) == decision(.scroll(.drop), .close))
    }

    @Test func aLoweringBeforeTheReadPassesAndLeavesNothingInFlight() {
        var filters = TapFilters()
        #expect(filters.follow(at(.clicks)) == .open)
        #expect(filters.follow(at(.none)) == .close)
        #expect(filters.decide(.scroll(.fingers(.began)), in: at(.none)) == decision(.scroll(.pass), nil))
        #expect(!filters.gateIsOpen)
    }

    @Test func aPressBeforeAPendingWakeOpensTheGateAndItsReleaseClosesIt() {
        var filters = TapFilters()
        #expect(filters.decide(.pointer(.press(p)), in: at(.clicks)) == decision(.pointer(.drop), .open))
        #expect(filters.decide(.pointer(.release(p)), in: at(.none)) == decision(.pointer(.drop), .close))
    }

    @Test func aStragglerBeforeAPendingWakeIsDecidedAfterTheReopenRules() {
        var filters = TapFilters()
        let context = TapContext.estimated(from: .clicks)
        #expect(filters.decide(.scroll(.fingers(.changed)), in: context) == decision(.scroll(.passStill), .open))
    }

    @Test func followIsIdempotent() {
        var filters = TapFilters()
        #expect(filters.follow(at(.possible)) == .open)
        #expect(filters.follow(at(.possible)) == nil)
    }

    @Test func aDroppedDockSwipeKeepsTheGateOpenUntilItsEnd() {
        var filters = TapFilters()
        #expect(
            filters.decide(.dockSwipe(.began, .gesture), in: at(.dockSwipes))
                == decision(.dockSwipe(.drop), .open))
        #expect(
            filters.decide(.dockSwipe(.changed, .gesture), in: at(.none)) == decision(.dockSwipe(.drop), nil))
        #expect(
            filters.decide(.dockSwipe(.ended, .gesture), in: at(.none)) == decision(.dockSwipe(.drop), .close))
    }

    @Test func theSystemTurningTheGatedPortOffForgetsScrollsAndSwipesButNotPresses() {
        var filters = busy()
        #expect(filters.portsWereDisabled(pressPortIsOn: true, gatedPortIsOn: false, in: at(.none)) == .open)
        #expect(filters.holding == .withheld)
        #expect(filters.decide(.scroll(.fingers(.changed)), in: at(.none)).verdict == .scroll(.pass))
    }

    @Test func thePressPortReadingOffForgetsHeldPressesAndLeavesTheGate() {
        var filters = busy()
        let change = filters.portsWereDisabled(
            pressPortIsOn: false, gatedPortIsOn: true, in: TapContext.estimated(from: .none))
        #expect(change == nil)
        #expect(filters.holding == .nothing)
        #expect(filters.gateIsOpen)
        #expect(filters.decide(.scroll(.fingers(.changed)), in: at(.none)).verdict == .scroll(.drop))
    }

    @Test func anUnseenScrollSurvivesAnEchoWithBothPortsOn() {
        var filters = TapFilters()
        _ = filters.follow(TapContext.estimated(from: .dockSwipes))
        #expect(filters.portsWereDisabled(pressPortIsOn: true, gatedPortIsOn: true, in: at(.clicks)) == nil)
        #expect(filters.decide(.scroll(.fingers(.began)), in: at(.clicks)).verdict == .scroll(.passStill))
    }

    @Test func anEchoOfOurOwnCloseChangesNothing() {
        var closed = TapFilters()
        #expect(closed.portsWereDisabled(pressPortIsOn: true, gatedPortIsOn: false, in: at(.none)) == nil)
        #expect(!closed.gateIsOpen)

        var idle = TapFilters()
        _ = idle.follow(at(.possible))
        #expect(idle.portsWereDisabled(pressPortIsOn: true, gatedPortIsOn: false, in: at(.none)) == nil)
        #expect(!idle.gateIsOpen)
    }

    @Test func bothPortsOffResetsEverythingToNilAndReopensWhenWanted() {
        var filters = busy()
        #expect(filters.portsWereDisabled(pressPortIsOn: false, gatedPortIsOn: false, in: at(.clicks)) == .open)
        #expect(filters.holding == .nothing)
        #expect(filters.decide(.scroll(.fingers(.began)), in: at(.clicks)).verdict == .scroll(.drop))
    }
}
