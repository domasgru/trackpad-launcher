import Testing
import LauncherCore

/// A contact landing at the bottom edge or the lower part of the hand-side edge is a resting hand, not a finger, for as
/// long as it stays down. Anywhere else on the pad, the edges included, it is a finger.
@Suite struct EdgeContactRecognizerTests {
    private let h = HandFrames()

    /// One contact down from `from` (its landing frame) until `until` (the first frame it is absent), 10 ms frames.
    private struct Track {
        var id: Int32
        var from: Int
        var until: Int
        var firstPhase: Touch.Phase = .landing
        var at: @Sendable (Int) -> (x: Double, y: Double)

        static func still(_ id: Int32, from: Int, until: Int, atMM x: Double, _ y: Double, firstPhase: Touch.Phase = .landing) -> Track {
            Track(id: id, from: from, until: until, firstPhase: firstPhase) { _ in (x, y) }
        }

        static func line(_ id: Int32, from: Int, until: Int, fromMM a: (x: Double, y: Double), toMM b: (x: Double, y: Double), over: ClosedRange<Int>) -> Track {
            Track(id: id, from: from, until: until) { ms in
                let f = min(max(Double(ms - over.lowerBound) / Double(over.upperBound - over.lowerBound), 0), 1)
                return (a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)
            }
        }
    }

    private func frames(_ tracks: [Track], throughMS end: Int) -> [TouchFrame] {
        let start = tracks.map(\.from).min() ?? 0
        return stride(from: start, through: end, by: 10).map { ms in
            let touches = tracks.filter { ms >= $0.from && ms < $0.until }.map { track in
                let p = track.at(ms)
                return h.contact(track.id, ms == track.from ? track.firstPhase : .down, atMM: p.x, p.y)
            }
            return h.frame(atMS: ms, touches)
        }
    }

    private func recognitions(_ frames: [TouchFrame]) -> [Recognition] {
        var recognizer = GestureRecognizer(
            handMode: .right, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear)
        return frames.map { recognizer.step($0, answering: true) }
    }

    private func ms(_ frame: TouchFrame) -> Int {
        Int(((frame.time.seconds - 1) * 1000).rounded())
    }

    private func firedAt(_ frames: [TouchFrame]) -> [Int] {
        zip(frames, recognitions(frames)).filter { $0.1.fired != nil }.map { ms($0.0) }
    }

    private func swipeEvents(_ frames: [TouchFrame]) -> (at: [Int], phases: [SwipePhase]) {
        let events = zip(frames, recognitions(frames)).compactMap { frame, recognition in
            recognition.swipe.map { (ms(frame), $0) }
        }
        return (events.map(\.0), events.map(\.1))
    }

    private func windowSwipeEvents(_ frames: [TouchFrame]) -> (at: [Int], phases: [SwipePhase]) {
        let events = zip(frames, recognitions(frames)).compactMap { frame, recognition in
            recognition.windowSwipe.map { (ms(frame), $0) }
        }
        return (events.map(\.0), events.map(\.1))
    }

    private let thumb = Track.still(9, from: 0, until: 10_000, atMM: 10, 10)

    /// The thumb's x in the anchor corner for the hand mode, 10 mm from the anchor-side edge.
    private func thumbX(_ handMode: HandMode, _ surface: SurfaceSize = .macBook14) -> Double {
        handMode == .right ? 10 : surface.widthMM - 10
    }

    @Test func aPalmBrushingTheEdgeDuringAOneFingerSlideFiresNothing() {
        let slidingAndBack = Track(id: 3, from: 0, until: 600) { ms in
            let t = Double(ms < 250 ? ms : max(500 - ms, 0)) / 250
            return (11 + 10 * t, 10 + 10 * t)
        }
        let firstBrush = Track.still(2, from: 100, until: 130, atMM: 124.1, 52)
        let secondBrush = Track.line(2, from: 320, until: 380, fromMM: (123.9, 50), toMM: (123.4, 50), over: 320...370)
        let all = frames([slidingAndBack, firstBrush, secondBrush], throughMS: 600)
        #expect(fired(all) == [])
    }

    @Test(arguments: [
        (HandMode.right, SurfaceSize.macBook14, 123.8, 53.76),
        (.left, .macBook14, 1.0, 53.76),
        (.right, .macBook14, 123.8, 34.56),
        (.right, .magicTrackpad, 159.0, 51.75),
        (.right, .macBook14, 1.0, 75.8),
        (.right, .macBook14, 62.4, 75.8),
        (.right, .macBook14, 123.8, 75.8),
        (.left, .macBook14, 1.0, 75.8),
        (.left, .macBook14, 62.4, 75.8),
        (.left, .macBook14, 123.8, 75.8),
    ])
    func aTapLandingInTheBottomEdgeOrTheLowerHandSideEdgeFiresNothingAndTheNextTapStillFires(handMode: HandMode, surface: SurfaceSize, x: Double, y: Double) {
        let script = TouchScript(surface).thumb(atMM: (thumbX(handMode, surface), 10))
            .tap(fingers: 1, atMM: (x, y))
            .tap(fingers: 1, atMM: (62, 45))
        #expect(fired(script.frames, handMode: handMode, surface: surface) == [.one])
    }

    @Test(arguments: [
        (HandMode.right, SurfaceSize.macBook14, 62.4, 1.0),
        (.left, .macBook14, 62.4, 1.0),
        (.right, .macBook14, 30.0, 1.0),
        (.right, .macBook14, 123.8, 1.0),
        (.right, .macBook14, 1.0, 53.76),
        (.right, .macBook14, 1.0, 23.04),
        (.left, .macBook14, 123.8, 53.76),
        (.right, .macBook14, 123.8, 15.36),
        (.left, .macBook14, 1.0, 23.04),
        (.right, .macBook14, 123.8, 26.88),
        (.right, .magicTrackpad, 159.0, 40.25),
    ])
    func aTapNearTheTopEdgeTheOppositeEdgeOrTheUpperHandSideEdgeIsAFinger(handMode: HandMode, surface: SurfaceSize, x: Double, y: Double) {
        let script = TouchScript(surface).thumb(atMM: (thumbX(handMode, surface), 10)).tap(fingers: 1, atMM: (x, y))
        #expect(fired(script.frames, handMode: handMode, surface: surface) == [.one])
    }

    @Test(arguments: [
        (HandMode.right, 123.8, 53.76),
        (.left, 1.0, 53.76),
    ])
    func aPalmRestingAtTheHandSideEdgeDoesNotAddToATap(handMode: HandMode, palmX: Double, palmY: Double) {
        let all = frames([
            .still(9, from: 0, until: 10_000, atMM: thumbX(handMode), 10),
            .still(2, from: 50, until: 400, atMM: palmX, palmY),
            .still(1, from: 120, until: 240, atMM: 62, 45),
        ], throughMS: 500)
        #expect(fired(all, handMode: handMode) == [.one])
    }

    @Test func aFingerAtTheTopEdgeCountsInATwoFingerTap() {
        let all = frames([
            thumb,
            .still(1, from: 50, until: 170, atMM: 62, 45),
            .still(2, from: 50, until: 170, atMM: 62.4, 1),
        ], throughMS: 400)
        #expect(fired(all) == [.two])
    }

    @Test func aFingerAtTheTopEdgeTakesPartInASwipe() {
        let all = frames([
            Track.still(9, from: 0, until: 10_000, atMM: 10, 10),
            Track(id: 1, from: 100, until: 160) { ms in (62 + 0.4 * Double(min(ms, 150) - 100), 45) },
            Track(id: 2, from: 100, until: 160) { ms in (62.4 + 0.4 * Double(min(ms, 150) - 100), 1) },
        ], throughMS: 200)
        let events = swipeEvents(all)
        #expect(events.at == [110, 120, 130, 140, 150, 160])
        #expect(phasesMatch(events.phases, [.began, .moved(travelMM: 4), .moved(travelMM: 8), .moved(travelMM: 12), .moved(travelMM: 16), .ended]), "phases were \(events.phases)")
        #expect(fired(all) == [])
    }

    @Test func aFingerRestingAtTheTopEdgeCountsForASwap() {
        let all = frames([
            .still(1, from: 0, until: 400, atMM: 62, 45),
            .still(2, from: 0, until: 400, atMM: 62.4, 1),
            .still(9, from: 150, until: 270, atMM: 10, 10),
        ], throughMS: 500)
        #expect(swaps(all) == [true])
    }

    @Test(arguments: [(62.4, 1.0), (62.0, 45.0)])
    func aFingerRestingAtTheTopEdgeBlocksLikeOneInTheMiddleOfThePad(x: Double, y: Double) {
        let all = frames([
            thumb,
            .still(1, from: 100, until: 4100, atMM: x, y),
        ], throughMS: 4100).filter { [0, 100, 1000, 2990, 3010, 4000, 4100].contains(ms($0)) }
        let clicks = [false, true, true, true, false, false, false]
        let dockSwipes = [false, true, true, true, true, true, false]
        for (i, (frame, recognition)) in zip(all, recognitions(all)).enumerated() {
            #expect(recognition.blocksClicks == clicks[i], "clicks at \(ms(frame)) ms")
            #expect(recognition.blocksDockSwipes == dockSwipes[i], "dock swipes at \(ms(frame)) ms")
        }
    }

    @Test func aFingerSlidingIntoTheHandSideBandStaysAFingerInATap() {
        let all = frames([
            thumb,
            .still(1, from: 50, until: 150, atMM: 62, 45),
            .line(2, from: 50, until: 170, fromMM: (123.8, 29.18), toMM: (123.8, 31.18), over: 60...110),
        ], throughMS: 400)
        let twos = zip(all, recognitions(all)).filter { $0.1.fired == .two }.map { ms($0.0) }
        #expect(twos == [170])
        #expect(fired(all) == [.two])
    }

    @Test func twoEdgeContactsTogetherAreNotATwoFingerTap() {
        let all = frames([
            thumb,
            .still(2, from: 50, until: 170, atMM: 123.8, 40),
            .still(3, from: 50, until: 170, atMM: 123.8, 60),
        ], throughMS: 400)
        #expect(fired(all) == [])
    }

    @Test func anEdgeContactSlidingAlongTheEdgeNeitherPairsWithAFingerNorSwipesNorSpoilsItsTap() {
        let all = frames([
            thumb,
            .still(1, from: 50, until: 170, atMM: 62, 45),
            .line(2, from: 70, until: 300, fromMM: (62, 75.8), toMM: (82, 75.8), over: 70...110),
        ], throughMS: 400)
        #expect(firedAt(all) == [170])
        #expect(swipeEvents(all).phases.isEmpty)
    }

    @Test(arguments: [Touch.Phase.landing, .down])
    func anEdgeContactAlreadyDownWhenTheThumbLandsDoesNotStopItArming(firstPhase: Touch.Phase) {
        let all = frames([
            .still(2, from: 0, until: 400, atMM: 123.8, 45, firstPhase: firstPhase),
            .still(9, from: 50, until: 10_000, atMM: 10, 10),
            .still(1, from: 120, until: 240, atMM: 62, 45),
        ], throughMS: 500)
        #expect(fired(all) == [.one])
    }

    @Test(arguments: [
        (HandMode.right, 1.0),
        (.left, 123.8),
    ])
    func aThumbAtTheVeryCornerStillAnchors(handMode: HandMode, thumbX: Double) {
        let script = TouchScript(.macBook14).thumb(atMM: (thumbX, 1)).tap(fingers: 1)
        #expect(fired(script.frames, handMode: handMode) == [.one])
    }

    @Test(arguments: [
        (SurfaceSize.macBook14, 122.3, 45.0, false),
        (.macBook14, 121.3, 45.0, true),
        (.macBook14, 120.8, 45.0, true),
        (.macBook14, 62.0, 74.3, false),
        (.macBook14, 62.0, 73.3, true),
        (.magicTrackpad, 157.5, 60.0, false),
        (.magicTrackpad, 156.5, 60.0, true),
    ])
    func theBandIsThreeMillimetresOnTheGuardedEdgesOfEverySize(surface: SurfaceSize, x: Double, y: Double, fires: Bool) {
        let script = TouchScript(surface).thumb(atMM: (10, 10)).tap(fingers: 1, atMM: (x, y))
        #expect(fired(script.frames, surface: surface) == (fires ? [.one] : []))
    }

    @Test func aFingerSlidingIntoTheBandStaysAFingerForBlocking() {
        let all = frames([
            thumb,
            Track.line(1, from: 100, until: 600, fromMM: (115, 45), toMM: (123.8, 45), over: 100...200),
        ], throughMS: 700)
        for (frame, recognition) in zip(all, recognitions(all)) {
            let expected = (100..<600).contains(ms(frame))
            #expect(recognition.blocksClicks == expected && recognition.blocksDockSwipes == expected, "at \(ms(frame)) ms")
            #expect(recognition.fired == nil, "at \(ms(frame)) ms")
        }
    }

    @Test func anIDReusedAtTheFingerSpotAfterAnEdgeContactLiftedIsAFinger() {
        let all = frames([
            thumb,
            .still(2, from: 50, until: 170, atMM: 123.8, 45),
            .still(2, from: 180, until: 300, atMM: 62, 45),
        ], throughMS: 400)
        #expect(firedAt(all) == [300])
    }

    @Test func anIDReusedAtTheEdgeWithNoAbsentFrameAfterAFingerIsAnEdgeContact() {
        let all = frames([
            thumb,
            .still(2, from: 50, until: 80, atMM: 62, 45),
            .still(2, from: 80, until: 100, atMM: 123.8, 45),
        ], throughMS: 400)
        #expect(firedAt(all) == [80])
    }

    @Test func anIDReusedAtTheFingerSpotWithNoAbsentFrameAfterAnEdgeContactIsAFinger() {
        let all = frames([
            thumb,
            .still(2, from: 50, until: 70, atMM: 123.8, 45),
            .still(2, from: 70, until: 100, atMM: 62, 45),
        ], throughMS: 400)
        #expect(firedAt(all) == [100])
    }

    @Test func aThirdContactAtTheEdgeDoesNotCancelASwipe() {
        let all = frames([
            Track.still(9, from: 0, until: 170, atMM: 10, 10),
            Track(id: 1, from: 100, until: 140) { ms in (62 + 0.4 * Double(ms - 100), 45) },
            Track(id: 2, from: 100, until: 140) { ms in (70 + 0.4 * Double(ms - 100), 45) },
            Track(id: 3, from: 120, until: 160) { ms in (123.8, 60 + Double(ms - 120)) },
        ], throughMS: 200)
        #expect(phasesMatch(swipeEvents(all).phases, [.began, .moved(travelMM: 4), .moved(travelMM: 8), .ended]), "phases were \(swipeEvents(all).phases)")
        #expect(fired(all) == [])
    }

    @Test func anEdgeContactIsNotAnotherContactDownForBlocking() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(2, .landing, atMM: 123.8, 45)]),
            h.frame(atMS: 110, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 123.8, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 123.8, 45), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 130, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 123.8, 45)]),
        ]
        let flags = recognitions(frames).map { [$0.blocksClicks, $0.blocksDockSwipes] }
        #expect(flags == [[false, false], [false, false], [false, false], [true, true], [false, false]])
    }

    @Test func anEdgeContactRollingInwardStaysAnEdgeContact() {
        let script = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 1, atMM: (123.8, 45), dragMM: (-2.5, 0))
            .tap(fingers: 1, atMM: (62, 45))
        #expect(fired(script.frames) == [.one])
    }

    @Test func anEdgeContactCannotRejoinASwipeAfterAFingerLifts() {
        let all = frames([
            Track.still(9, from: 0, until: 160, atMM: 10, 10),
            Track(id: 1, from: 100, until: 150) { ms in (62 + 0.4 * Double(ms - 100), 45) },
            Track(id: 2, from: 100, until: 120) { ms in (70 + 0.4 * Double(ms - 100), 45) },
            Track(id: 3, from: 130, until: 160) { ms in (62 + 0.8 * Double(ms - 130), 75.8) },
        ], throughMS: 200)
        let events = swipeEvents(all)
        #expect(events.at == [110, 120, 130, 140, 150])
        #expect(phasesMatch(events.phases, [.began, .moved(travelMM: 4), .moved(travelMM: 8), .moved(travelMM: 12), .ended]), "phases were \(events.phases)")
        #expect(fired(all) == [])
    }

    @Test func aFingerAndAnEdgeContactSlidingUpTogetherAreNoWindowSwipe() {
        let all = frames([
            thumb,
            .line(1, from: 100, until: 300, fromMM: (62, 60), toMM: (62, 50), over: 100...200),
            .line(2, from: 100, until: 300, fromMM: (70, 75.8), toMM: (70, 65.8), over: 100...200),
        ], throughMS: 400)
        #expect(windowSwipeEvents(all).phases.isEmpty)
        #expect(swipeEvents(all).phases.isEmpty)
    }

    @Test func anEdgeContactLandingDuringAWindowSwipeDoesNotCancelIt() {
        let all = frames([
            Track.still(9, from: 0, until: 170, atMM: 10, 10),
            Track(id: 1, from: 100, until: 140) { ms in (62, 30 + 0.4 * Double(ms - 100)) },
            Track(id: 2, from: 100, until: 140) { ms in (70, 30 + 0.4 * Double(ms - 100)) },
            Track(id: 3, from: 120, until: 160) { ms in (123.8, 40 + Double(ms - 120)) },
        ], throughMS: 200)
        let phases = windowSwipeEvents(all).phases
        #expect(phasesMatch(phases, [.began, .moved(travelMM: 4), .moved(travelMM: 8), .ended]), "phases were \(phases)")
        #expect(fired(all) == [])
    }

    @Test func anEdgeContactCannotRejoinAWindowSwipeAfterAFingerLifts() {
        let all = frames([
            Track.still(9, from: 0, until: 160, atMM: 10, 10),
            Track(id: 1, from: 100, until: 150) { ms in (62, 30 + 0.4 * Double(ms - 100)) },
            Track(id: 2, from: 100, until: 120) { ms in (70, 30 + 0.4 * Double(ms - 100)) },
            Track(id: 3, from: 130, until: 160) { ms in (123.8, 40 + 0.8 * Double(ms - 130)) },
        ], throughMS: 200)
        let events = windowSwipeEvents(all)
        #expect(events.at == [110, 120, 130, 140, 150])
        #expect(phasesMatch(events.phases, [.began, .moved(travelMM: 4), .moved(travelMM: 8), .moved(travelMM: 12), .ended]), "phases were \(events.phases)")
        #expect(fired(all) == [])
    }
}
