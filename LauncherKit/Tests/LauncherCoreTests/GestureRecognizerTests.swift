import Testing
import LauncherCore

@Suite struct GestureRecognizerTests {
    @Test(arguments: 1...4)
    func thumbThenNFingerTapFiresThatGestureOnce(fingers: Int) {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: fingers).frames
        #expect(fired(frames) == [Gesture(fingerCount: fingers)!])
    }

    @Test func fiveFingerTapFiresNothing() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 5).frames
        #expect(fired(frames).isEmpty)
    }

    @Test(arguments: [(thumbXMM: 10.0, fires: true), (thumbXMM: 40.0, fires: false)])
    func anchorCornerGeometryOnMacBook(thumbXMM: Double, fires: Bool) {
        let frames = TouchScript(.macBook14).thumb(atMM: (thumbXMM, 10)).tap(fingers: 1).frames
        #expect(fired(frames) == (fires ? [.one] : []))
    }

    @Test(arguments: [(thumbXMM: 10.0, fires: true), (thumbXMM: 40.0, fires: false)])
    func anchorCornerGeometryOnMagicTrackpad(thumbXMM: Double, fires: Bool) {
        let frames = TouchScript(.magicTrackpad).thumb(atMM: (thumbXMM, 10)).tap(fingers: 1).frames
        #expect(fired(frames, surface: .magicTrackpad) == (fires ? [.one] : []))
    }

    @Test(arguments: [
        (thumbMM: (x: 24.0, y: 10.0), fires: true),
        (thumbMM: (x: 26.0, y: 10.0), fires: false),
        (thumbMM: (x: 10.0, y: 18.0), fires: true),
        (thumbMM: (x: 10.0, y: 20.0), fires: false),
    ])
    func cornerIsTwentyPercentByTwentyFivePercentOfTheSurface(thumbMM: (x: Double, y: Double), fires: Bool) {
        let frames = TouchScript(.macBook14).thumb(atMM: thumbMM).tap(fingers: 1).frames
        #expect(fired(frames) == (fires ? [.one] : []))
    }

    @Test func leftHandAnchorsInTheTopRightCorner() {
        let topRight = TouchScript(.macBook14).thumb(atMM: (114.8, 10)).tap(fingers: 1).frames
        let topLeft = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).frames
        #expect(fired(topRight, handMode: .left) == [.one])
        #expect(fired(topLeft, handMode: .left).isEmpty)
    }
}

extension GestureRecognizerTests {
    @Test func repeatedTapsWhileThumbStaysAnchored() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).tap(fingers: 2).frames
        #expect(fired(frames) == [.one, .two])
    }

    @Test func fingersDownBeforeTheThumbNeverFire() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 10, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 50, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 62, 45)]),
            h.frame(atMS: 210, [h.contact(9, atMM: 10, 10), h.contact(3, atMM: 62, 45)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 400, []),
        ]
        #expect(fired(frames) == [.one])
    }

    @Test func thumbAndFingerLandingInTheSameFrameNeverFire() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(2, .landing, atMM: 62, 45)]),
            h.frame(atMS: 210, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 62, 45)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(fired(frames) == [.one])
    }

    @Test func thumbInTheBottomCornerArmsNothing() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 66)).tap(fingers: 1).frames
        #expect(fired(frames).isEmpty)
    }

    @Test func thumbRestingAloneForFiveSecondsFiresNothing() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(5)).liftThumb().frames
        #expect(fired(frames).isEmpty)
    }

    @Test func fingersLandingAndLiftingTenMillisecondsApartFireOnce() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 3, stagger: .milliseconds(10)).frames
        #expect(fired(frames) == [.three])
    }

    @Test func everyFingerThatTouchedCountsNotTheMostDownAtOnce() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 3, stagger: .milliseconds(50)).frames
        #expect(fired(frames) == [.three])
    }

    @Test func thumbLiftingBeforeTheFingersFiresNothing() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 100, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 150, []),
        ]
        #expect(fired(frames).isEmpty)
    }

    @Test func thumbLiftingInTheSameFrameAsTheLastFingerFiresNothing() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 100, []),
        ]
        #expect(fired(frames).isEmpty)
    }

    @Test func onlyTheTapMadeWhileTheThumbIsAnchoredFires() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).liftThumb().tap(fingers: 1).frames
        #expect(fired(frames) == [.one])
    }
}

extension GestureRecognizerTests {
    @Test func draggingFingersIsNotATapAndTheNextTapStillFires() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 2, dragMM: 20).tap(fingers: 2).frames
        #expect(fired(frames) == [.two])
    }

    @Test(arguments: [(dragMM: 2.5, fires: true), (dragMM: 3.5, fires: false)])
    func fingerMovementPastThreeMillimetresIsADrag(dragMM: Double, fires: Bool) {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1, dragMM: dragMM).frames
        #expect(fired(frames) == (fires ? [.one] : []))
    }

    @Test(arguments: [1, 3], [TouchScript.ClickTiming.onLanding, .midway])
    func physicalClickIsNotATapAndTheNextTapStillFires(fingers: Int, click: TouchScript.ClickTiming) {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: fingers, click: click).tap(fingers: fingers).frames
        #expect(fired(frames) == [Gesture(fingerCount: fingers)!])
    }

    @Test(arguments: [(holdMS: 390, fired: [Gesture.one, .one]), (holdMS: 410, fired: [.one])])
    func tapMustEndWithinFourHundredMillisecondsOfItsFirstLanding(holdMS: Int, fired expected: [Gesture]) {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 1, hold: .milliseconds(holdMS)).tap(fingers: 1).frames
        #expect(fired(frames) == expected)
    }

    @Test func twoFingersHeldFiveHundredMillisecondsFireNothing() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2, hold: .milliseconds(500)).frames
        #expect(fired(frames).isEmpty)
    }

    @Test(arguments: [(rollToXMM: 26.5, fires: true), (rollToXMM: 28.0, fires: false)])
    func thumbMayRollTwoMillimetresPastTheCornerEdge(rollToXMM: Double, fires: Bool) {
        let frames = TouchScript(.macBook14).thumb(atMM: (24, 10))
            .rollThumb(toMM: (rollToXMM, 10)).tap(fingers: 1).frames
        #expect(fired(frames) == (fires ? [.one] : []))
    }

    @Test func reusedTouchIDLandingAgainStartsASecondTap() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(7, .landing, atMM: 62, 45)]),
            h.frame(atMS: 110, [h.contact(9, atMM: 10, 10), h.contact(7, atMM: 62, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(7, atMM: 62, 45)]),
            h.frame(atMS: 130, [h.contact(9, atMM: 10, 10), h.contact(7, .landing, atMM: 62, 45)]),
            h.frame(atMS: 140, [h.contact(9, atMM: 10, 10), h.contact(7, atMM: 62, 45)]),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10), h.contact(7, atMM: 62, 45)]),
            h.frame(atMS: 160, [h.contact(9, atMM: 10, 10)]),
        ]
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
        let perFrame = frames.map { recognizer.step($0) }
        #expect(perFrame == [nil, nil, nil, nil, .one, nil, nil, .one])
    }
}

extension GestureRecognizerTests {
    @Test func fourFingersLandingOneByOneWhileEarlierOnesLiftFireFour() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 4, stagger: .milliseconds(40), hold: .milliseconds(100)).frames
        #expect(fired(frames) == [.four])
    }

    @Test func fiveFingersInARollingTapFireNothing() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 5, stagger: .milliseconds(40), hold: .milliseconds(100)).frames
        #expect(fired(frames).isEmpty)
    }

    @Test func tapsTwoHundredMillisecondsApartBothFire() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 1).wait(.milliseconds(100)).tap(fingers: 1).frames
        #expect(fired(frames) == [.one, .one])
    }

    @Test func aFingerThatBouncesCountsOnce() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)] + (1...4).map { h.contact(Int32($0), .landing, atMM: 62 + 8 * Double($0), 45) }),
            h.frame(atMS: 110, [h.contact(9, atMM: 10, 10)] + (1...4).map { h.contact(Int32($0), atMM: 62 + 8 * Double($0), 45) }),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 70, 45), h.contact(2, .landing, atMM: 78, 45),
                                h.contact(3, atMM: 86, 45), h.contact(4, atMM: 94, 45)]),
            h.frame(atMS: 130, [h.contact(9, atMM: 10, 10)] + (1...4).map { h.contact(Int32($0), atMM: 62 + 8 * Double($0), 45) }),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(fired(frames) == [.four])
    }

    @Test func unevenThreeFingerTapOverThreeHundredFiftyMillisecondsFires() {
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 3, stagger: .milliseconds(75), hold: .milliseconds(200)).frames
        #expect(fired(frames) == [.three])
    }

    @Test func noTapBeginsWhileAnOverlongTapsFingersAreStillDown() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 520, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 540, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 560, [h.contact(9, atMM: 10, 10), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 600, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 700, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 62, 45)]),
            h.frame(atMS: 800, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(fired(frames) == [.one])
    }

    @Test func firesOnTheFirstFrameTheLastFingerIsAbsentAndOnNoLaterOne() {
        let h = HandFrames()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 110, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 130, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 140, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 150, []),
        ]
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
        #expect(frames.map { recognizer.step($0) } == [nil, nil, nil, nil, .one, nil, nil])
    }
}

@Suite struct HandModeTests {
    @Test func cornerNamesMatchTheHint() {
        #expect(HandMode.right.cornerName == "top-left")
        #expect(HandMode.left.cornerName == "top-right")
    }
}
