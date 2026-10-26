import Testing
import LauncherCore

/// `Recognition.blocking`: the one ordered level per frame that the two Bools derive from.
@Suite struct BlockingLevelRecognizerTests {
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    /// Every frame's level from a fresh recognizer, checking on each that the two Bools follow the level.
    private func levels(_ frames: [TouchFrame], answering: Bool? = true) -> [Blocking] {
        var recognizer = makeRecognizer()
        return frames.map {
            let recognition = recognizer.step($0, answering: answering)
            #expect(recognition.blocksClicks == (recognition.blocking >= .clicks))
            #expect(recognition.blocksDockSwipes == (recognition.blocking >= .dockSwipes))
            #expect(recognition.blocking.blocksPressDrags == (recognition.blocking == .pressDrags))
            #expect(!recognition.blocking.blocksPressDrags || recognition.blocksClicks)
            #expect(!recognition.blocksClicks || recognition.blocksDockSwipes)
            #expect(!recognition.blocksDockSwipes || recognition.blocking.wantsTap)
            return recognition.blocking
        }
    }

    private func makeRecognizer() -> GestureRecognizer {
        GestureRecognizer(
            handMode: .right, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear)
    }

    private static let thumbID = 100

    private func thumbIsGone(_ frame: TouchFrame) -> Bool {
        !frame.touches.contains { $0.id.rawValue == Self.thumbID }
    }

    /// The thumb is beyond the anchor corner (24.96 mm) plus the 2 mm release margin.
    private func thumbIsPastTheRelease(_ frame: TouchFrame) -> Bool {
        frame.touches.contains { $0.id.rawValue == Self.thumbID && $0.position.x * SurfaceSize.macBook14.widthMM > 26.96 }
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

    @Test func aConfirmedSwipeReadsDragsFromItsFirstFrameAndAfterTheThumbLifted() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 20, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)]),
            h.frame(atMS: 30, [h.contact(1, atMM: 70, 45), h.contact(2, atMM: 78, 45)]),
            h.frame(atMS: 4000, [h.contact(1, atMM: 80, 45), h.contact(2, atMM: 88, 45)]),
            h.frame(atMS: 4010, []),
        ]
        #expect(levels(frames) == [.possible, .clicks, .pressDrags, .pressDrags, .pressDrags, .none])
    }

    @Test func aConfirmedWindowSwipeReadsDragsFromTheFrameAfterItsConfirmationUntilItEnds() {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).lift().liftThumb().frames
        var recognizer = makeRecognizer()
        let recognitions = frames.map { recognizer.step($0, answering: true) }
        let began = recognitions.firstIndex { $0.windowSwipe == .began }!
        let ended = recognitions.firstIndex { $0.windowSwipe == .ended }!
        #expect(recognitions[began].blocking == .clicks)
        #expect(recognitions[(began + 1)..<ended].allSatisfy { $0.blocking == .pressDrags })
        #expect(recognitions[ended].blocking == .possible)
        let thumbAlone = frames.indices.filter { $0 > ended && frames[$0].touches.count == 1 }
        #expect(!thumbAlone.isEmpty)
        #expect(thumbAlone.allSatisfy { recognitions[$0].blocking == .possible })
        let gone = frames.indices.filter { $0 > ended && frames[$0].touches.isEmpty }
        #expect(!gone.isEmpty)
        #expect(gone.allSatisfy { recognitions[$0].blocking == .none })
    }

    @Test(arguments: [nil, false] as [Bool?])
    func aWindowSwipeNobodyConfirmedNeverReadsDrags(answer: Bool?) {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).lift().liftThumb().frames
        let result = levels(frames, answering: answer)
        #expect(!result.contains(.pressDrags))
        for (frame, level) in zip(frames, result) where frame.touches.count == 3 {
            #expect(level == .clicks)
        }
    }

    @Test func anUnconfirmedWindowSwipeWhoseThumbLiftedIsDockSwipes() {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).liftThumb().slide(byMM: (0, 5)).frames
        let result = levels(frames, answering: nil)
        let gone = frames.firstIndex(where: thumbIsGone)!
        #expect(gone < frames.count - 1)
        #expect(result[gone...].allSatisfy { $0 == .dockSwipes })
    }

    @Test func aDeclinedWindowSwipeWithTheThumbGoneIsDockSwipes() {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).liftThumb().slide(byMM: (0, 5)).frames
        let result = levels(frames, answering: false)
        let gone = frames.firstIndex(where: thumbIsGone)!
        #expect(result[gone...].allSatisfy { $0 == .dockSwipes })
    }

    @Test func aDeclinedWindowSwipeUnderAThumbRested4sIsDockSwipesAndNeverClicks() {
        let frames = thumb.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 10)).frames
        let result = levels(frames, answering: false)
        let landed = frames.firstIndex { $0.touches.count == 3 }!
        #expect(result[landed...].allSatisfy { $0 == .dockSwipes })
    }

    @Test func aThumbRolledOutOfTheCornerIsStillPossible() {
        let frames = thumb.wait(.milliseconds(100)).rollThumb(toMM: (40, 10)).wait(.milliseconds(300)).frames
        let result = levels(frames)
        #expect(result.first == .possible)
        #expect(result.allSatisfy { $0 == .possible })
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

    @Test func aThumbTouchBlocksDockSwipesOnEveryFrameWithTwoContactsWhateverTheThumbDid() {
        let script = thumb.land(fingers: 2).slide(byMM: (10, 0)).rollThumb(toMM: (40, 10)).lift()
            .land(fingers: 2).slide(byMM: (20, 0)).lift().liftThumb()
        let frames = script.frames
        var recognizer = makeRecognizer()
        let recognitions = frames.map { recognizer.step($0, answering: true) }

        let swipe = recognitions.compactMap(\.swipe)
        #expect(swipe.first == .began)
        #expect(swipe.last == .ended)
        #expect(swipe.filter { $0 == .began || $0 == .ended }.count == 2)
        #expect(recognitions.compactMap(\.windowSwipe).isEmpty)
        #expect(recognitions.compactMap(\.fired).isEmpty)

        for (frame, recognition) in zip(frames, recognitions) {
            switch frame.touches.count {
            case 0: #expect(recognition.blocking == .none)
            case 1: #expect(recognition.blocking == .possible)
            default: #expect(recognition.blocking >= .dockSwipes)
            }
        }
        let firstLanding = frames.firstIndex { $0.touches.count == 3 }!
        let ended = recognitions.firstIndex { $0.swipe == .ended }!
        for (index, recognition) in recognitions.enumerated() {
            #expect(recognition.blocksClicks == (index >= firstLanding && index < ended), "clicks at frame \(index)")
        }
    }

    @Test func aWindowSwipeStartAwaitingItsAnswerBlocksDockSwipesOnceTheThumbRolledOut() {
        let script = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)).rollThumb(toMM: (40, 10))
            .wait(.milliseconds(100)).lift().liftThumb()
        let frames = script.frames
        var recognizer = makeRecognizer()
        let recognitions = frames.map { recognizer.step($0, answering: nil) }

        #expect(recognitions.compactMap(\.windowSwipe).filter { $0 == .began }.count == 1)
        let rolled = frames.firstIndex(where: thumbIsPastTheRelease)!
        for (index, (frame, recognition)) in zip(frames, recognitions).enumerated() {
            if index >= rolled { #expect(recognition.blocking != .clicks, "clicks at frame \(index)") }
            if frame.touches.count >= 3 {
                #expect(recognition.blocking == (index < rolled ? .clicks : .dockSwipes), "frame \(index)")
            }
            if frame.touches.count == 1 { #expect(recognition.blocking == .possible) }
            if frame.touches.isEmpty { #expect(recognition.blocking == .none) }
        }
        #expect(recognitions.compactMap(\.windowSwipe).filter { $0 == .began }.count == 1)
    }

    @Test func aThumbBlippingBackInsideTheReleaseMarginStillBlocksDockSwipes() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 110, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 120, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 26, 10)]),
            h.frame(atMS: 130, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, atMM: 26, 10)]),
            h.frame(atMS: 140),
        ]
        var recognizer = makeRecognizer()
        let recognitions = frames.map { recognizer.step($0, answering: true) }
        #expect(recognitions.map(\.blocking) == [.possible, .clicks, .dockSwipes, .dockSwipes, .dockSwipes, .none])
        #expect(recognitions.map(\.blocksClicks) == [false, true, false, false, false, false])
    }

    @Test func aTouchWithNoThumbAfterAThumbTouchHasEndedIsNotBlocked() {
        let script = thumb.land(fingers: 2).slide(byMM: (10, 0)).lift().liftThumb()
            .land(fingers: 3, atMM: (50, 45)).slide(byMM: (40, 0), over: .milliseconds(300)).lift()
        var recognizer = makeRecognizer()
        let recognitions = script.frames.map { (touches: $0.touches.count, recognition: recognizer.step($0, answering: true)) }
        let emptied = recognitions.firstIndex { $0.touches == 0 }!
        #expect(recognitions[emptied...].contains { $0.touches == 3 })
        #expect(recognitions[emptied...].allSatisfy { $0.recognition.blocking == .none && $0.recognition.event == nil })
    }
}
