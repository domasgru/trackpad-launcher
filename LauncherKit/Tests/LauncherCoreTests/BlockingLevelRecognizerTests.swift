import Testing
import LauncherCore

/// `Recognition.blocking`: the one ordered level per frame that the two Bools derive from.
@Suite struct BlockingLevelRecognizerTests {
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    /// Every frame's level from a fresh recognizer, checking on each that the two Bools follow the level.
    private func levels(_ frames: [TouchFrame], answering: Bool? = true) -> [Blocking] {
        var recognizer = GestureRecognizer(
            handMode: .right, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear)
        return frames.map {
            let recognition = recognizer.step($0, answering: answering)
            #expect(recognition.blocksClicks == (recognition.blocking == .clicks))
            #expect(recognition.blocksDockSwipes == (recognition.blocking >= .dockSwipes))
            return recognition.blocking
        }
    }

    private func thumbIsGone(_ frame: TouchFrame) -> Bool {
        !frame.touches.contains { $0.id.rawValue == 100 }
    }

    @Test func noTouchesAreNone() {
        #expect(levels([h.frame(atMS: 0, [])]) == [.none])
    }

    @Test func aThumbAloneIsPossibleUntilItLifts() {
        let frames = thumb.wait(.seconds(1)).liftThumb().wait(.milliseconds(50)).frames
        let result = levels(frames)
        #expect(result.first == .possible)
        #expect(result.contains(.possible))
        #expect(result.last == Blocking.none)
        #expect(Set(result) == [Blocking.possible, Blocking.none])
    }

    @Test func aThumbAndAnEdgeContactInTheBottomBandOnlyIsPossible() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 60, 75.5)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 60, 75.5)]),
        ]
        #expect(levels(frames) == [.possible, .possible, .possible])
    }

    @Test func aFingerLandingWithinTheClickWindowIsClicksUntilItsEndAndDockSwipesAfter() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 1000, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 2990, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 3010, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
        ]
        #expect(levels(frames) == [.possible, .clicks, .clicks, .dockSwipes])
    }

    @Test func aThumbAlreadyDownOnTheFirstFrameWithAFingerIsDockSwipesAsItsLandingIsUnknown() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .down, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
        ]
        #expect(levels(frames) == [.dockSwipes, .dockSwipes])
    }

    @Test func fingersRestingWithNoThumbAreNoneAndTheThumbLandingUnderThemIsClicks() {
        let fingers = [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]
        let frames = [
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 150, fingers),
            h.frame(atMS: 200, fingers + [h.contact(9, .landing, atMM: 10, 10)]),
        ]
        #expect(levels(frames) == [.none, .none, .clicks])
    }

    @Test func aSeriesWithOneRestFingerAndNoThumbIsClicks() {
        let first = [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]
        let frames = [
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 150, first + [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 250, first),
            h.frame(atMS: 6000, [first[1]]),
            h.frame(atMS: 7000, []),
        ]
        let result = levels(frames)
        #expect(Array(result[2...3]) == [.clicks, .clicks])
        #expect(result[4] == .none)
    }

    @Test func aConfirmedSwipeStaysClicksAfterTheThumbLifted() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 20, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)]),
            h.frame(atMS: 30, [h.contact(1, atMM: 70, 45), h.contact(2, atMM: 78, 45)]),
            h.frame(atMS: 4000, [h.contact(1, atMM: 80, 45), h.contact(2, atMM: 88, 45)]),
            h.frame(atMS: 4010, []),
        ]
        #expect(levels(frames) == [.possible, .clicks, .clicks, .clicks, .clicks, .none])
    }

    @Test func anUnconfirmedWindowSwipeWhoseThumbLiftedIsPossible() {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).liftThumb().slide(byMM: (0, 5)).frames
        let result = levels(frames, answering: nil)
        let gone = frames.firstIndex(where: thumbIsGone)!
        #expect(gone < frames.count - 1)
        #expect(result[gone...].allSatisfy { $0 == .possible })
    }

    @Test func aDeclinedWindowSwipeWithTheThumbGoneIsNone() {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).liftThumb().slide(byMM: (0, 5)).frames
        let result = levels(frames, answering: false)
        let gone = frames.firstIndex(where: thumbIsGone)!
        #expect(result[gone...].allSatisfy { $0 == .none })
    }

    @Test func aDeclinedWindowSwipeUnderAThumbRested4sIsDockSwipesAndNeverClicks() {
        let frames = thumb.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).frames
        let result = levels(frames, answering: false)
        let landed = frames.firstIndex { $0.touches.count == 3 }!
        #expect(result[landed...].allSatisfy { $0 == .dockSwipes })
    }

    @Test func aThumbRolledOutOfTheCornerIsNone() {
        let frames = thumb.wait(.milliseconds(100)).rollThumb(toMM: (40, 10)).wait(.milliseconds(300)).frames
        let result = levels(frames)
        #expect(result.first == .possible)
        #expect(result.last == Blocking.none)
    }

    @Test func theEmptyFrameAfterAThumbIsNone() {
        let frames = [h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]), h.frame(atMS: 10, [])]
        #expect(levels(frames) == [.possible, .none])
    }

    @Test(arguments: [
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 3),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 4),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 5),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2).slide(byMM: (10, 0)),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1, click: .firm),
        TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(4)).land(fingers: 2),
    ])
    func theTapIsWantedOnTheFrameBeforeAnyVerdict(script: TouchScript) throws {
        let result = levels(script.frames)
        let verdict = try #require(result.firstIndex { $0 >= .dockSwipes })
        #expect(verdict > 0)
        #expect(result[verdict - 1].wantsTap)
    }

    @Test func aThumbAndAFingerOnOneFrameHaveNoWarningFrame() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
        ]
        #expect(levels(frames) == [.clicks])
    }
}
