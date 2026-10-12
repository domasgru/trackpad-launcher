import Testing
import LauncherCore

@Suite struct SwipeTravelAndExitTests {
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func began(_ t: TouchScript) -> TouchScript { t.land(fingers: 2).slide(byMM: (3.5, 0)) }

    private func firstIndex(of phase: SwipePhase, in frames: [TouchFrame]) -> Int? {
        perFrame(frames).firstIndex { $0.swipe == phase }
    }

    @Test(arguments: [
        (surface: SurfaceSize.macBook14, hand: HandMode.right, thumbX: 10.0),
        (surface: SurfaceSize.macBook14, hand: HandMode.left, thumbX: 114.8),
        (surface: SurfaceSize.magicTrackpad, hand: HandMode.right, thumbX: 10.0),
        (surface: SurfaceSize.magicTrackpad, hand: HandMode.left, thumbX: 150.0),
    ])
    func travelIsInTrackpadMillimetresAndPositiveToTheRightInBothHandModes(
        surface: SurfaceSize, hand: HandMode, thumbX: Double
    ) {
        let start = TouchScript(surface).thumb(atMM: (thumbX, 10)).land(fingers: 2).slide(byMM: (3.5, 0))
        let right = phases(start.slide(byMM: (12, 0)).frames, handMode: hand, surface: surface)
        let left = phases(start.slide(byMM: (-12, 0)).frames, handMode: hand, surface: surface)
        #expect(right.last?.isCloseTo(.moved(travelMM: 12.35)) == true)
        #expect(left.last?.isCloseTo(.moved(travelMM: -11.65)) == true)
    }

    @Test func travelIsTheMidpointsMovementSinceTheBeginAndOnlySentWhenItChanged() {
        func frame(_ ms: Int, _ x1: Double) -> TouchFrame {
            h.frame(atMS: ms, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: x1, 45), h.contact(2, atMM: 70, 45)])
        }
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            frame(110, 66), frame(120, 70), frame(130, 74), frame(140, 78), frame(150, 82), frame(160, 86), frame(170, 86),
        ]
        let expected: [SwipePhase] = [.began, .moved(travelMM: 2), .moved(travelMM: 4), .moved(travelMM: 6), .moved(travelMM: 8), .moved(travelMM: 10)]
        #expect(phasesMatch(phases(frames), expected))
    }

    @Test func theFirstFingerToLiftEndsTheSwipeAndNothingFollowsUntilTheHandIsUp() {
        let frames = began(thumb).slide(byMM: (24, 0)).lift(.first).slide(byMM: (24, 0)).lift().frames
        let seen = phases(frames)
        #expect(seen.last == .ended)
        #expect(seen.filter { $0 == .ended }.count == 1)
        #expect(fired(frames).isEmpty)
    }

    @Test func oneFingerLiftingLeavesTheSwipeOnAndTheOtherKeepsMovingItUntilItLifts() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 80, 45)]),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 90, 45)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(phasesMatch(phases(frames), [.began, .moved(travelMM: 14), .moved(travelMM: 24), .ended]))
    }

    @Test func aFingerThatDropsOutAndComesBackWithANewIDRejoinsWithoutAJump() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)]),
            h.frame(atMS: 70, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 70, 45)]),
            h.frame(atMS: 80, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 74, 45), h.contact(5, .landing, atMM: 90, 45)]),
            h.frame(atMS: 90, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 78, 45), h.contact(5, atMM: 94, 45)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(phasesMatch(
            phases(frames), [.began, .moved(travelMM: 4), .moved(travelMM: 8), .moved(travelMM: 12), .ended]))
    }

    @Test func aThirdFingerLandingWhileBothAreDownStillCancels() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)]),
            h.frame(atMS: 70, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45), h.contact(3, .landing, atMM: 90, 45)]),
        ]
        #expect(phases(frames) == [.began, .cancelled])
    }

    @Test func theWholeHandLiftingTogetherEndsTheSwipeAndTheThumbLiftDoesNotCancelIt() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 90, 45), h.contact(2, atMM: 94, 45)]),
            h.frame(atMS: 200, []),
        ]
        #expect(phasesMatch(phases(frames), [.began, .moved(travelMM: 24), .ended]))
        #expect(perFrame(frames).last?.blocks == false)
    }

    @Test(arguments: [Duration.zero, .seconds(4)])
    func afterTheEndOnlyTheThreeSecondRuleBlocks(rest: Duration) {
        let script = began(thumb.wait(rest)).slide(byMM: (12, 0)).lift().tap(fingers: 1)
        let frames = script.frames
        let seen = perFrame(frames)
        let ended = firstIndex(of: .ended, in: frames)!
        #expect(phases(frames).last == .ended)
        #expect(fired(frames) == [.one])
        #expect(seen[(ended + 1)...].contains(where: \.blocks) == (rest == .zero))
    }

    private static let thumbLiftsAndLandsAgain: @Sendable (TouchScript) -> TouchScript = {
        $0.land(fingers: 2).slide(byMM: (5, 0)).liftThumb().slide(byMM: (24, 0)).thumb(atMM: (12, 10)).lift()
    }

    @Test func theThumbLiftingAndLandingAgainMidSwipeLeavesTheSwipeGoingAndTheNextTapFires() {
        let swipe = Self.thumbLiftsAndLandsAgain(thumb)
        let frames = swipe.tap(fingers: 1).frames
        let seen = perFrame(swipe.frames)
        let began = seen.firstIndex { $0.swipe == .began }!
        let ended = seen.firstIndex { $0.swipe == .ended }!
        #expect(phases(frames).first == .began)
        #expect(phases(frames).last == .ended)
        #expect(!phases(frames).contains(.cancelled))
        #expect(seen[began..<ended].allSatisfy { $0.blocks })
        #expect(fired(frames) == [.one])
        let tapFrames = zip(frames, perFrame(frames)).dropFirst(ended + 1).filter { $0.0.touches.count > 1 }
        #expect(!tapFrames.isEmpty && tapFrames.allSatisfy { $0.1.blocks })
    }

    @Test func theThumbLiftingMidSwipeAndStayingAwayStillEndsTheSwipeAndNothingFires() {
        let frames = thumb.land(fingers: 2).slide(byMM: (5, 0)).liftThumb().slide(byMM: (24, 0)).lift().frames
        #expect(phases(frames).last == .ended)
        #expect(fired(frames).isEmpty)
    }

    @Test func aThumbRollingOutOfTheCornerMidSwipeChangesNothingAndTheRestIsInertUntilItLandsAnew() {
        let swipe = thumb.land(fingers: 2).slide(byMM: (5, 0)).rollThumb(toMM: (40, 10)).slide(byMM: (24, 0)).lift()
        #expect(phases(swipe.frames).first == .began)
        #expect(phases(swipe.frames).last == .ended)
        #expect(!phases(swipe.frames).contains(.cancelled))

        let backInside = swipe.rollThumb(toMM: (10, 10)).tap(fingers: 1)
        #expect(fired(backInside.frames).isEmpty)

        let landedAnew = swipe.rollThumb(toMM: (10, 10)).liftThumb().thumb(atMM: (10, 10)).tap(fingers: 1)
        #expect(fired(landedAnew.frames) == [.one])
    }

    @Test func aThirdFingerCancelsOnceAndTheNextTapStillFires() {
        let frames = began(thumb).slide(byMM: (24, 0)).land(fingers: 1, atMM: (86, 45)).slide(byMM: (12, 0)).lift()
            .tap(fingers: 1).frames
        #expect(phases(frames).filter { $0 == .cancelled }.count == 1)
        #expect(phases(frames).last == .cancelled)
        #expect(fired(frames) == [.one])
    }

    @Test func aThumbLandingOnTheExitFrameIsTheAnchorAfterwards() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 100, [h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 150, [h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 250, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 270, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 62, 45)]),
            h.frame(atMS: 330, [h.contact(9, atMM: 10, 10)]),
        ]
        let seen = perFrame(frames)
        #expect(seen.map(\.swipe) == [nil, nil, .began, nil, nil, nil, .ended, nil, nil, nil])
        #expect(seen[5].blocks)
        #expect(fired(frames) == [.one])
    }

    @Test func twoFingersLiftingWhileAThirdLandsEndsTheSwipeAndAClickOnTheLiftFrameCancelsIt() {
        let head = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
        ]
        let landing = head + [h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 86, 45)])]
        let clicking = head + [h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)], press: .click)]
        #expect(phases(landing) == [.began, .ended])
        #expect(phases(clicking) == [.began, .cancelled])
    }

    @Test(arguments: [TouchFrame.Press.blocked, .click])
    func aBlockedPressLeavesTheSwipeAloneAndAClickCancelsIt(press: TouchFrame.Press) {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 70, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)], press: press),
            h.frame(atMS: 80, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 74, 45), h.contact(2, atMM: 78, 45)], press: press),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)]),
        ]
        let seen = perFrame(frames).map(\.swipe)
        if press == .blocked {
            #expect(seen.count == 6 && seen[3] == nil && seen[5] == .ended)
            #expect(phasesMatch(phases(frames), [.began, .moved(travelMM: 8), .ended]))
        } else {
            #expect(seen == [nil, nil, .began, .cancelled, nil, nil])
        }
    }

    @Test(arguments: [
        { (t: TouchScript) in t.wait(.seconds(4)).land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (24, 0)).lift() },
        { (t: TouchScript) in SwipeTravelAndExitTests.thumbLiftsAndLandsAgain(t) },
        { (t: TouchScript) in t.land(fingers: 2).slide(byMM: (5, 0)).rollThumb(toMM: (40, 10)).slide(byMM: (24, 0)).lift() },
    ] as [@Sendable (TouchScript) -> TouchScript])
    func clicksStayBlockedForTheWholeSwipeWhateverTheThumbOrTheClockDid(script: @Sendable (TouchScript) -> TouchScript) {
        let frames = script(thumb).frames
        let seen = perFrame(frames)
        let began = seen.firstIndex { $0.swipe == .began }!
        let ended = seen.firstIndex { $0.swipe == .ended }!
        #expect(seen[began..<ended].allSatisfy { $0.blocks })
        #expect(seen[ended...].allSatisfy { !$0.blocks })
    }
}
