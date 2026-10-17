import LauncherCore
import Testing

@Suite struct FilterResumeTests {
    private func resumed(mayBeUnderWay: Bool = true) -> ScrollFilter {
        var filter = ScrollFilter()
        filter.resume(scrollMayBeUnderWay: mayBeUnderWay)
        return filter
    }

    private func scroll(_ filter: inout ScrollFilter, _ event: ScrollEvent, _ blocking: Bool) -> ScrollVerdict {
        filter.decide(event, trackpadBlocking: blocking)
    }

    @Test func aFreshStartAfterResumingIsStillDropped() {
        var filter = resumed()
        #expect(scroll(&filter, .fingers(.mayBegin), true) == .drop)
    }

    @Test func aGestureOpenedAfterResumingWhileBlockingIsStilledToItsEnd() {
        var filter = resumed()
        #expect(scroll(&filter, .fingers(.began), true) == .passStill)
        #expect(scroll(&filter, .fingers(.changed), false) == .passStill)
    }

    @Test func aMidPhaseUnblockedAfterResumingPasses() {
        var filter = resumed()
        #expect(scroll(&filter, .fingers(.changed), false) == .pass)
    }

    @Test func momentumAfterResumingPassesAndItsEndForgetsTheUnseen() {
        var filter = resumed()
        #expect(scroll(&filter, .momentum(.changed), true) == .pass)
        #expect(scroll(&filter, .momentum(.ended), true) == .pass)
        #expect(scroll(&filter, .fingers(.began), true) == .drop)
    }

    @Test func resumingWithNothingUnderWayForgetsAPassedGesture() {
        var filter = ScrollFilter()
        #expect(scroll(&filter, .fingers(.began), false) == .pass)
        filter.resume(scrollMayBeUnderWay: false)
        #expect(scroll(&filter, .fingers(.began), true) == .drop)
    }

    @Test func resumingKeepsADroppedCoastThroughItsMomentum() {
        var filter = ScrollFilter()
        #expect(scroll(&filter, .fingers(.began), true) == .drop)
        #expect(scroll(&filter, .fingers(.ended), true) == .drop)
        filter.resume(scrollMayBeUnderWay: false)
        #expect(scroll(&filter, .momentum(.began), false) == .drop)
    }

    @Test func aScrollIsSuppressingWhileItsGestureIsDroppedOrStilled() {
        var filter = ScrollFilter()
        #expect(!filter.isSuppressing)
        _ = scroll(&filter, .fingers(.began), true)
        #expect(filter.isSuppressing)
        _ = scroll(&filter, .fingers(.ended), true)
        #expect(filter.isSuppressing)

        var stilled = ScrollFilter()
        _ = scroll(&stilled, .fingers(.began), false)
        #expect(!stilled.isSuppressing)
        _ = scroll(&stilled, .fingers(.changed), true)
        #expect(stilled.isSuppressing)
        _ = scroll(&stilled, .fingers(.ended), true)
        _ = scroll(&stilled, .momentum(.ended), true)
        #expect(!stilled.isSuppressing)

        #expect(!resumed().isSuppressing)
    }

    @Test func resumingKeepsASuppressedGesture() {
        var filter = ScrollFilter()
        _ = scroll(&filter, .fingers(.began), true)
        filter.resume(scrollMayBeUnderWay: false)
        #expect(scroll(&filter, .fingers(.changed), false) == .drop)
    }

    @Test func aPassingDockSwipeIsForgottenOnResume() {
        var filter = DockSwipeFilter()
        #expect(filter.decide(.began, trackpadBlocking: false) == .pass)
        filter.resume()
        #expect(filter.decide(.began, trackpadBlocking: true) == .drop)
    }

    @Test func aDroppedDockSwipeSurvivesResume() {
        var filter = DockSwipeFilter()
        #expect(filter.decide(.began, trackpadBlocking: true) == .drop)
        filter.resume()
        #expect(filter.decide(.changed, trackpadBlocking: false) == .drop)
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
