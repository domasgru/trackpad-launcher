import Testing
import LauncherCore

@Suite struct ScrollFilterTests {
    private func run(_ steps: [(ScrollEvent, Bool)], from filter: ScrollFilter = ScrollFilter()) -> [ScrollVerdict] {
        var filter = filter
        return steps.map { filter.decide($0.0, trackpadBlocking: $0.1) }
    }

    @Test func aWheelNeverScrollsAwayAndAGestureIsJudgedOnItsOpeningEventThenKeptWhole() {
        let verdicts = run([
            (.wheel, true), (.unphased, true), (.unphased, false),
            (.fingers(.mayBegin), true), (.fingers(.began), false), (.fingers(.changed), false),
            (.fingers(.ended), false), (.momentum(.began), false), (.momentum(.changed), false),
            (.momentum(.ended), false),
            (.fingers(.began), false), (.fingers(.ended), false),
        ])
        #expect(
            verdicts == [
                .pass, .drop, .pass,
                .drop, .drop, .drop, .drop, .drop, .drop, .drop,
                .pass, .pass,
            ])
        #expect(run([(.fingers(.began), true)]) == [.drop])
    }

    @Test func aGesturePassingWhenBlockingArrivesIsStilledToItsMomentumsEnd() {
        let verdicts = run([
            (.fingers(.began), false), (.fingers(.changed), true), (.fingers(.changed), false),
            (.fingers(.ended), false), (.momentum(.began), false), (.momentum(.ended), false),
            (.fingers(.began), false),
        ])
        #expect(verdicts == [.pass, .passStill, .passStill, .passStill, .passStill, .passStill, .pass])
        #expect(run([(.fingers(.changed), true), (.fingers(.ended), false)]) == [.passStill, .passStill])
    }

    @Test func momentumFollowsItsGestureAndNothingKnownIsNeverInterrupted() {
        let verdicts = run([
            (.fingers(.began), false), (.fingers(.ended), false),
            (.momentum(.began), true), (.momentum(.changed), true), (.momentum(.ended), true),
            (.momentum(.changed), true),
            (.fingers(.mayBegin), true), (.fingers(.cancelled), false), (.fingers(.began), false),
        ])
        #expect(verdicts == [.pass, .pass, .pass, .pass, .pass, .pass, .drop, .drop, .pass])
    }

    @Test func forgettingTheGestureTreatsTheRestAsFirstSeenMidWay() {
        var dropped = ScrollFilter()
        #expect(dropped.decide(.fingers(.began), trackpadBlocking: true) == .drop)
        dropped.forgetGesture()
        #expect(dropped.decide(.fingers(.changed), trackpadBlocking: false) == .pass)

        var blocked = ScrollFilter()
        #expect(blocked.decide(.fingers(.began), trackpadBlocking: true) == .drop)
        blocked.forgetGesture()
        #expect(blocked.decide(.fingers(.changed), trackpadBlocking: true) == .passStill)
    }
}
