import LauncherCore
import Testing

@Suite struct DockSwipeFilterTests {
    private func run(_ steps: [(DockSwipePhase, Bool)], from filter: DockSwipeFilter = DockSwipeFilter()) -> [DockSwipeVerdict] {
        var filter = filter
        return steps.map { filter.decide($0.0, trackpadBlocking: $0.1) }
    }

    @Test func aSwipeOpeningWhileBlockingIsDroppedWholeEvenIfBlockingEnds() {
        #expect(
            run([(.mayBegin, true), (.began, false), (.changed, false), (.ended, false)])
                == [.drop, .drop, .drop, .drop])
        #expect(run([(.began, true), (.changed, false), (.cancelled, false)]) == [.drop, .drop, .drop])
    }

    @Test func aSwipeOpeningUnblockedPassesWholeEvenIfBlockingArrives() {
        #expect(run([(.began, false), (.changed, true), (.ended, true)]) == [.pass, .pass, .pass])
    }

    @Test func eachSwipeIsJudgedAfreshOnceTheLastEnded() {
        #expect(
            run([(.began, true), (.ended, true), (.began, false), (.ended, false), (.began, true)])
                == [.drop, .drop, .pass, .pass, .drop])
    }

    @Test func aSwipeFirstSeenMidWayAlwaysPasses() {
        #expect(run([(.changed, true), (.changed, true), (.ended, true)]) == [.pass, .pass, .pass])
    }

    @Test func forgettingTheSwipeTreatsTheRestAsFirstSeenMidWay() {
        var filter = DockSwipeFilter()
        #expect(filter.decide(.began, trackpadBlocking: true) == .drop)
        filter.forgetSwipe()
        #expect(filter.decide(.changed, trackpadBlocking: true) == .pass)
    }
}
