import Testing
import LauncherCore

@Suite struct RecordedSwipeTravelTests {
    private static let cursor = SwipeTravel.cursor(
        PointerCurve(PointerCurve.builtInCurves, trackingSpeed: 0.6875)!, pointsPerStep: 100)

    @Test func aRecordedSwipeBeginsAndEndsWhereItsHeaderSaysAndTheHighlightNeverLeaps() throws {
        let swipe = try #require(RecordedSwipe.load().first { $0.number == 2 })
        let replay = swipe.replay(travel: Self.cursor)
        #expect(replay.beganAt == swipe.began)
        #expect(replay.endedAt == swipe.ended)
        #expect(replay.leaps.isEmpty)
        let index = try #require(replay.times.firstIndex { abs($0 - (swipe.began + 0.512)) < 1e-6 })
        #expect(abs(replay.steps[index] - 11.88) < 0.05)
    }
}
