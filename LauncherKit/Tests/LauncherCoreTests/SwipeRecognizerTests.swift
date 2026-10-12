import Testing
import LauncherCore

@Suite struct SwipeBeginTests {
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    @Test(arguments: [2.9, 3.1])
    func twoFingersBeginASwipeOnlyPastThreeMillimetres(dx: Double) {
        let frames = thumb.land(fingers: 2).slide(byMM: (dx, 0)).lift().frames
        if dx > 3 {
            #expect(phases(frames).first == .began)
            #expect(fired(frames).isEmpty)
        } else {
            #expect(phases(frames).isEmpty)
            #expect(fired(frames) == [.two])
        }
    }

    @Test func twoFingersRestingForTwoSecondsStillBeginASwipeWhenTheyMove() {
        let frames = thumb.land(fingers: 2).wait(.seconds(2)).slide(byMM: (5, 0)).lift().frames
        #expect(phases(frames).first == .began)
        #expect(fired(frames).isEmpty)
    }

    @Test func aMoveOnTheFrameThatCrossesFourHundredMillisecondsStillBegins() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 500, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 510, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 65.5, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 520, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 65.5, 45), h.contact(2, atMM: 70, 45)]),
        ]
        #expect(perFrame(frames).map(\.swipe) == [nil, nil, nil, nil, .began, nil])
    }

    @Test func movingUpOrDownFirstIsNeverASwipeAndTheNextTapStillFires() {
        let frames = thumb.land(fingers: 2).slide(byMM: (0, 10)).slide(byMM: (20, 0)).lift().tap(fingers: 2).frames
        #expect(phases(frames).isEmpty)
        #expect(fired(frames) == [.two])
    }

    @Test(arguments: [(dx: 3.0, dy: 2.9, begins: true), (dx: 2.9, dy: 3.0, begins: false)])
    func theMoveMustBeMoreSidewaysThanVerticalWhereItPassesThreeMillimetres(dx: Double, dy: Double, begins: Bool) {
        let frames = thumb.land(fingers: 2).slide(byMM: (dx, dy)).lift().frames
        #expect(phases(frames).first == (begins ? .began : nil))
    }

    @Test(arguments: [1, 3])
    func oneOrThreeFingersSlidingSidewaysAreNotASwipe(fingers: Int) {
        let frames = thumb.land(fingers: fingers).slide(byMM: (20, 0)).lift().frames
        #expect(phases(frames).isEmpty)
    }

    @Test func aThirdFingerLandingOnTheFrameThePairMovesPastThreeMillimetresIsNotASwipe() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45), h.contact(3, .landing, atMM: 86, 45)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 300, [h.contact(9, atMM: 10, 10), h.contact(4, .landing, atMM: 62, 45)]),
            h.frame(atMS: 330, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(phases(frames).isEmpty)
        #expect(fired(frames) == [.one])
    }

    @Test func fingersThatLandedBeforeTheThumbNeverSwipe() {
        let frames = [
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 50, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 82, 45), h.contact(2, atMM: 90, 45)]),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 62, 45)]),
            h.frame(atMS: 230, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(phases(frames).isEmpty)
        #expect(fired(frames) == [.one])
    }

    @Test(arguments: [
        { (t: TouchScript) in t.land(fingers: 1, atMM: (86, 45)).slide(byMM: (20, 0)).lift() },
        { (t: TouchScript) in t.slide(byMM: (0, 10)).slide(byMM: (20, 0)).lift() },
        { (t: TouchScript) in t.lift(.first).slide(byMM: (20, 0)).lift() },
    ] as [@Sendable (TouchScript) -> TouchScript])
    func aRestingPairThatIsDisturbedOrMovesVerticallyNeverSwipes(rest: @Sendable (TouchScript) -> TouchScript) {
        let frames = rest(thumb.land(fingers: 2).wait(.seconds(1))).tap(fingers: 1).frames
        #expect(phases(frames).isEmpty)
        #expect(fired(frames) == [.one])
    }

    @Test func aClickOnARestingPairSpoilsItEvenIfTheFingersThenMoveSideways() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 500, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 1100, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)], press: .click),
            h.frame(atMS: 1200, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 82, 45), h.contact(2, atMM: 90, 45)]),
            h.frame(atMS: 1300, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 1400, [h.contact(9, atMM: 10, 10), h.contact(3, .landing, atMM: 62, 45)]),
            h.frame(atMS: 1450, [h.contact(9, atMM: 10, 10), h.contact(3, atMM: 62, 45)]),
            h.frame(atMS: 1500, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(phases(frames).isEmpty)
        #expect(fired(frames) == [.one])
    }

    @Test func aThirdFingerLandingAfterTheBeginCancelsTheSwipeAndFiresNothing() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 140, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45), h.contact(3, .landing, atMM: 86, 45)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 300, []),
        ]
        #expect(phases(frames) == [.began, .cancelled])
        #expect(fired(frames).isEmpty)
    }

    @Test func aDriftingTwoFingerTapBeginsAndEndsASwipeAndFiresNoTap() {
        let frames = thumb.land(fingers: 2).slide(byMM: (4, 0)).lift().frames
        let seen = phases(frames)
        #expect(seen.first == .began)
        #expect(seen.last == .ended)
        #expect(!seen.contains(.cancelled))
        #expect(seen.allSatisfy { if case .moved(let t) = $0 { abs(t) < 1 } else { true } })
        #expect(fired(frames).isEmpty)
    }

    @Test func withSwipesOffASidewaysPairSpoilsLikeAnyDragAndARestingPairNeverBegins() {
        let slid = thumb.land(fingers: 2).slide(byMM: (20, 0)).lift().tap(fingers: 2).frames
        let rested = thumb.land(fingers: 2).wait(.seconds(1)).slide(byMM: (20, 0)).lift().frames
        #expect(phases(slid, swipes: true).first == .began)
        #expect(phases(slid, swipes: false).isEmpty)
        #expect(fired(slid, swipes: false) == [.two])
        #expect(fired(slid, swipes: true) == [.two])
        #expect(phases(rested, swipes: true).first == .began)
        #expect(phases(rested, swipes: false).isEmpty)
        #expect(fired(rested, swipes: false).isEmpty)
    }
}
