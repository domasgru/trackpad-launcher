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

    @Test func aPassedWarningCommitsNothingSoABeganUnderBlockingDropsTheRestOfTheSwipe() {
        #expect(
            run([(.mayBegin, false), (.began, true), (.changed, false), (.ended, false)])
                == [.pass, .drop, .drop, .drop])
    }

    @Test func aSwipeWhoseWarningAndBeganBothPassedPassesWhole() {
        #expect(
            run([(.mayBegin, false), (.began, false), (.changed, true), (.ended, true)])
                == [.pass, .pass, .pass, .pass])
    }

    @Test func aPassedSwipeWhoseEndWasNeverSeenDoesNotPassTheNextSwipeUnderBlocking() {
        #expect(run([(.began, false), (.began, true), (.changed, false)]) == [.pass, .drop, .drop])
    }

    @Test func aSwipeIsDroppingFromItsDroppedBeganNotFromAPassedWarning() {
        var filter = DockSwipeFilter()
        _ = filter.decide(.mayBegin, trackpadBlocking: false)
        #expect(!filter.isDropping)
        _ = filter.decide(.began, trackpadBlocking: true)
        _ = filter.decide(.changed, trackpadBlocking: false)
        #expect(filter.isDropping)
        _ = filter.decide(.ended, trackpadBlocking: false)
        #expect(!filter.isDropping)
    }

    @Test func aDockSwipeIsDroppingOnlyFromADroppedOpeningToItsEnd() {
        var filter = DockSwipeFilter()
        #expect(!filter.isDropping)
        _ = filter.decide(.began, trackpadBlocking: true)
        #expect(filter.isDropping)
        _ = filter.decide(.changed, trackpadBlocking: false)
        #expect(filter.isDropping)
        _ = filter.decide(.ended, trackpadBlocking: false)
        #expect(!filter.isDropping)
        _ = filter.decide(.began, trackpadBlocking: true)
        _ = filter.decide(.cancelled, trackpadBlocking: true)
        #expect(!filter.isDropping)
    }
}
