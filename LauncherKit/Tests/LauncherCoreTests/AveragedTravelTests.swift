import Foundation
import Testing
import LauncherCore

@Suite struct AveragedTravelTests {
    private static let cursor = SwipeTravel.cursor(
        PointerCurve(PointerCurve.builtInCurves, trackingSpeed: 0.6875)!, pointsPerStep: 100)

    private let h = HandFrames()

    /// The pair lands 8 mm apart, one frame moves it 3.5 mm and begins the slide, then each entry of `movesMM` is how
    /// far both fingers move on one frame along `kind`, then `rest` frames with the fingers still; `ending` follows.
    private func hand(
        _ movesMM: [Double], rest: Int, along kind: SlideKind, ending: ((Int, [Touch]) -> [TouchFrame])? = nil
    ) -> [TouchFrame] {
        var along = 0.0
        let thumb = h.contact(9, atMM: 10, 10)
        func fingers(_ phase: Touch.Phase = .down) -> [Touch] {
            let origin = kind == .swipe ? (x: 62.0 + along, y: 45.0) : (x: 62.0, y: 30.0 + along)
            return [h.contact(1, phase, atMM: origin.x, origin.y), h.contact(2, phase, atMM: origin.x + 8, origin.y)]
        }
        var frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [thumb] + fingers(.landing)),
        ]
        var ms = 50
        for move in [3.5] + movesMM + Array(repeating: 0, count: rest) {
            ms += 10
            along += move
            frames.append(h.frame(atMS: ms, [thumb] + fingers()))
        }
        if let ending { frames += ending(ms + 10, fingers()) }
        return frames
    }

    private func travel(_ frames: [TouchFrame], kind: SlideKind, using swipeTravel: SwipeTravel = .linear) -> [SwipePhase] {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: swipeTravel)
        return frames.compactMap { frame in
            let recognition = recognizer.step(frame)
            if kind == .windowSwipe, recognition.windowSwipe == .began {
                recognizer.answerWindowSwipe(began: frame.time, isWindowSwipe: true)
            }
            return kind == .swipe ? recognition.swipe : recognition.windowSwipe
        }
    }

    private func moved(_ values: [Double]) -> [SwipePhase] { [.began] + values.map { .moved(travelMM: $0) } }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func travelRampsInOverTheFirstFramesAndCatchesUpWithinThreeFramesOfTheFingersStopping(kind: SlideKind) {
        let frames = hand([4, 4, 4, 4, 4, 4], rest: 4, along: kind)
        let expected = moved([1, 3, 6, 10, 14, 18, 21, 23, 24])
        #expect(phasesMatch(travel(frames, kind: kind), expected))
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func oneFrameOfFiveAmongOnesAddsNoMoreThanTheirAverageAndTheTotalIsKept(kind: SlideKind) {
        let frames = hand([1, 1, 1, 1, 5, 1, 1, 1, 1], rest: 4, along: kind)
        let expected = moved([0.25, 0.75, 1.5, 2.5, 4.5, 6.5, 8.5, 10.5, 11.5, 12.25, 12.75, 13])
        #expect(phasesMatch(travel(frames, kind: kind), expected))
    }

    @Test func theCursorSeesTheAveragedSpeedSoAnUnevenHandTravelsLikeASteadyOne() {
        let uneven = travel(hand([1, 3, 1, 3, 1, 3, 1, 3, 1, 3], rest: 0, along: .swipe), kind: .swipe, using: Self.cursor)
        let steady = travel(hand(Array(repeating: 2, count: 10), rest: 0, along: .swipe), kind: .swipe, using: Self.cursor)
        let curve = PointerCurve(PointerCurve.builtInCurves, trackingSpeed: 0.6875)!
        let each = curve.cursorMove(dxMM: 2, dyMM: 0, interval: 0.01).x / 100 * 12
        for phases in [uneven, steady] {
            let travels = phases.compactMap { phase -> Double? in if case .moved(let mm) = phase { mm } else { nil } }
            #expect(travels.count >= 10)
            for (before, after) in zip(travels.dropFirst(3), travels.dropFirst(4)) {
                #expect(abs(after - before - each) < 1e-9)
            }
        }
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func movementStillInTheWindowWhenTheFingersLiftIsNotAdded(kind: SlideKind) {
        let lifting: (Int, [Touch]) -> [TouchFrame] = { ms, _ in [self.h.frame(atMS: ms, [self.h.contact(9, atMM: 10, 10)])] }
        let thirdLanding: (Int, [Touch]) -> [TouchFrame] = { ms, fingers in
            [self.h.frame(atMS: ms, [self.h.contact(9, atMM: 10, 10), self.h.contact(3, .landing, atMM: 100, 70)] + fingers)]
        }
        let lifted = travel(hand([4, 4, 4, 4, 4, 4], rest: 0, along: kind, ending: lifting), kind: kind)
        #expect(phasesMatch(lifted, moved([1, 3, 6, 10, 14, 18]) + [.ended]))
        let cancelled = travel(hand([4, 4, 4, 4, 4, 4], rest: 0, along: kind, ending: thirdLanding), kind: kind)
        #expect(phasesMatch(cancelled, moved([1, 3, 6, 10, 14, 18]) + [.cancelled]))
    }
}
