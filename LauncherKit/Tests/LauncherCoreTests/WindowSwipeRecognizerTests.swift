import Testing
import LauncherCore

/// The phases a fresh recognizer reported for `kind`, in order.
private func slidePhases(_ kind: SlideKind, _ frames: [TouchFrame], slides: Set<SlideKind> = [.swipe, .windowSwipe]) -> [SwipePhase] {
    kind == .swipe ? phases(frames, slides: slides) : windowPhases(frames, slides: slides)
}

/// Every recognition a fresh recognizer with both kinds on gave, frame by frame.
private func recognitions(_ frames: [TouchFrame]) -> [Recognition] {
    var recognizer = GestureRecognizer(
        handMode: .right, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear)
    return frames.map { recognizer.step($0) }
}

/// Hand frames written for a sideways swipe, turned into the same hand sliding down for a window swipe: the finger
/// lane at 45 mm becomes x 62 mm and the sideways position becomes the height, 32 mm higher. The thumb stays put.
private struct SlideFrames {
    let kind: SlideKind
    private let h = HandFrames()

    func thumb(_ phase: Touch.Phase = .down) -> Touch { h.contact(9, phase, atMM: 10, 10) }

    /// A finger at `x` along a sideways swipe's lane.
    func finger(_ id: Int32, _ phase: Touch.Phase = .down, at x: Double) -> Touch {
        kind == .swipe ? h.contact(id, phase, atMM: x, 45) : h.contact(id, phase, atMM: 62, x - 32)
    }

    func frame(atMS ms: Int, _ touches: [Touch] = [], press: TouchFrame.Press? = nil) -> TouchFrame {
        h.frame(atMS: ms, touches, press: press)
    }
}

/// A slide of `mm` along `kind`: sideways for a swipe, down for a window swipe.
private func along(_ kind: SlideKind, _ mm: Double) -> (x: Double, y: Double) {
    kind == .swipe ? (mm, 0) : (0, mm)
}

/// Where a pair lands so that a long slide along `kind` stays clear of the bottom edge.
private func pairSpot(_ kind: SlideKind) -> (x: Double, y: Double) {
    kind == .swipe ? (62, 45) : (62, 30)
}

@Suite struct WindowSwipeBeginTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    @Test(arguments: [(2.9, 1.0), (3.1, 1.0), (2.9, -1.0), (3.1, -1.0)])
    func twoFingersBeginAWindowSwipeOnlyPastThreeMillimetresUpOrDown(distance: Double, sign: Double) {
        let frames = thumb.land(fingers: 2, atMM: (62, 40)).slide(byMM: (0, sign * distance)).lift().frames
        if distance > 3 {
            #expect(windowPhases(frames).first == .began)
            #expect(fired(frames).isEmpty)
            #expect(phases(frames).isEmpty)
        } else {
            #expect(windowPhases(frames).isEmpty)
            #expect(fired(frames) == [.two])
        }
    }

    @Test(arguments: [
        (surface: SurfaceSize.macBook14, hand: HandMode.right, thumbX: 10.0),
        (surface: SurfaceSize.macBook14, hand: HandMode.left, thumbX: 114.8),
        (surface: SurfaceSize.magicTrackpad, hand: HandMode.right, thumbX: 10.0),
        (surface: SurfaceSize.magicTrackpad, hand: HandMode.left, thumbX: 150.0),
    ])
    func travelIsInTrackpadMillimetresAndPositiveDownwardsInBothHandModes(
        surface: SurfaceSize, hand: HandMode, thumbX: Double
    ) {
        let start = TouchScript(surface).thumb(atMM: (thumbX, 10)).land(fingers: 2, atMM: (62, 30))
            .slide(byMM: (0, 3.5))
        let down = start.slide(byMM: (0, 12)).lift().frames
        let up = start.slide(byMM: (0, -12)).lift().frames
        let downPhases = windowPhases(down, handMode: hand, surface: surface)
        let upPhases = windowPhases(up, handMode: hand, surface: surface)
        let lastMove: ([SwipePhase]) -> SwipePhase? = { $0.last { if case .moved = $0 { true } else { false } } }
        #expect(lastMove(downPhases)?.isCloseTo(.moved(travelMM: 12.35)) == true)
        #expect(lastMove(upPhases)?.isCloseTo(.moved(travelMM: -11.65)) == true)
        #expect(downPhases.last == .ended && upPhases.last == .ended)
        #expect(phases(down, handMode: hand, surface: surface).isEmpty)
        #expect(phases(up, handMode: hand, surface: surface).isEmpty)
    }

    @Test(arguments: [
        (dx: 2.9, dy: 3.0, window: true, swipe: false),
        (dx: 3.0, dy: 2.9, window: false, swipe: true),
        (dx: 3.0, dy: 3.0, window: false, swipe: false),
    ])
    func theFirstMovePastThreeMillimetresDecidesTheKindAndATieIsNeither(
        dx: Double, dy: Double, window: Bool, swipe: Bool
    ) {
        // Power-of-two sides and a landing point equally far along both axes keep an equal move in millimetres equal
        // after the round trip through surface fractions, so the tie is exact.
        let surface = SurfaceSize(widthMM: 128, heightMM: 64)
        let frames = TouchScript(surface).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (32, 32))
            .slide(byMM: (dx, dy)).slide(byMM: (0, 20)).lift().tap(fingers: 2, atMM: (32, 32)).frames
        #expect(!windowPhases(frames, surface: surface).isEmpty == window)
        #expect(!phases(frames, surface: surface).isEmpty == swipe)
        #expect(fired(frames, surface: surface) == [.two])
    }

    @Test(arguments: [Duration.seconds(2), .seconds(4)])
    func twoFingersRestingAnyTimeStillBeginAWindowSwipeWhenTheyMove(rest: Duration) {
        let frames = thumb.land(fingers: 2, atMM: (62, 30)).wait(rest).slide(byMM: (0, 5)).lift().frames
        #expect(windowPhases(frames).first == .began)
        #expect(fired(frames).isEmpty)
    }

    @Test(arguments: [
        { (t: TouchScript) in t.thumb(atMM: (10, 10)).land(fingers: 1, atMM: (62, 30)) },
        { (t: TouchScript) in t.thumb(atMM: (10, 10)).land(fingers: 3, atMM: (62, 30)) },
        { (t: TouchScript) in t.land(fingers: 2, atMM: (62, 30)).wait(.milliseconds(50)).thumb(atMM: (10, 10)) },
    ] as [@Sendable (TouchScript) -> TouchScript])
    func oneOrThreeFingersOrFingersBeforeTheThumbNeverWindowSwipe(hand: @Sendable (TouchScript) -> TouchScript) {
        let frames = hand(TouchScript(.macBook14)).slide(byMM: (0, 20)).lift().tap(fingers: 1).frames
        #expect(windowPhases(frames).isEmpty)
        #expect(fired(frames) == [.one])
    }
}

@Suite struct WindowSwipeKindTests {
    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func aSlideNeverTurnsIntoTheOtherKind(kind: SlideKind) {
        let across: (x: Double, y: Double) = kind == .swipe ? (0, 20) : (20, 0)
        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (40, 30))
            .slide(byMM: along(kind, 3.5)).slide(byMM: across).slide(byMM: along(kind, 12)).lift().frames
        let seen = perFrame(frames)
        let other = seen.compactMap { kind == .swipe ? $0.windowSwipe : $0.swipe }
        let own = slidePhases(kind, frames)
        #expect(other.isEmpty)
        #expect(own.first == .began && own.last == .ended)
        let lastMove = own.last { if case .moved = $0 { true } else { false } }
        #expect(lastMove?.isCloseTo(.moved(travelMM: 12.35)) == true)
    }

    private static let vertical: @Sendable (TouchScript) -> TouchScript = {
        $0.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 20)).lift().tap(fingers: 2)
    }
    private static let sideways: @Sendable (TouchScript) -> TouchScript = {
        $0.land(fingers: 2, atMM: (62, 30)).slide(byMM: (20, 0)).lift().tap(fingers: 2)
    }
    private static let restingVertical: @Sendable (TouchScript) -> TouchScript = {
        $0.land(fingers: 2, atMM: (62, 30)).wait(.seconds(1)).slide(byMM: (0, 20)).lift().tap(fingers: 2)
    }

    /// What a vertical slide, a sideways slide and a resting pair sliding down begin with these kinds on.
    struct Row: Sendable {
        let slides: Set<SlideKind>
        let swipes: [Bool]
        let windowSwipes: [Bool]
    }

    static let rows: [Row] = [
        Row(slides: [], swipes: [false, false, false], windowSwipes: [false, false, false]),
        Row(slides: [.swipe], swipes: [false, true, false], windowSwipes: [false, false, false]),
        Row(slides: [.windowSwipe], swipes: [false, false, false], windowSwipes: [true, false, true]),
        Row(slides: [.swipe, .windowSwipe], swipes: [false, true, false], windowSwipes: [true, false, true]),
    ]

    @Test(arguments: rows)
    func eachKindBeginsOnlyWhileItIsOn(row: Row) {
        let (slides, swipes, windowSwipes) = (row.slides, row.swipes, row.windowSwipes)
        let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
        for (i, hand) in [Self.vertical, Self.sideways, Self.restingVertical].enumerated() {
            let frames = hand(thumb).frames
            let swiped = phases(frames, slides: slides).first == .began
            let windowSwiped = windowPhases(frames, slides: slides).first == .began
            #expect(swiped == swipes[i], "hand \(i)")
            #expect(windowSwiped == windowSwipes[i], "hand \(i)")
            if !swiped && !windowSwiped && i < 2 {
                #expect(fired(frames, slides: slides) == [.two], "hand \(i)")
            }
        }
    }
}

@Suite struct WindowSwipeTravelAndExitTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private static func thumbLiftsAndLandsAgain(_ kind: SlideKind) -> @Sendable (TouchScript) -> TouchScript {
        { $0.land(fingers: 2, atMM: pairSpot(kind)).slide(byMM: along(kind, 5)).liftThumb().slide(byMM: along(kind, 24))
            .thumb(atMM: (12, 10)).lift() }
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func theThumbLiftingAndLandingAgainLeavesTheSlideGoingAndTheNextTapFires(kind: SlideKind) {
        let frames = Self.thumbLiftsAndLandsAgain(kind)(thumb).tap(fingers: 1).frames
        let seen = slidePhases(kind, frames)
        #expect(seen.first == .began && seen.last == .ended && !seen.contains(.cancelled))
        #expect(fired(frames) == [.one])
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func aThumbRollingOutOfTheCornerChangesNothingAndTheRestIsInertUntilItLandsAnew(kind: SlideKind) {
        let slide = thumb.land(fingers: 2, atMM: pairSpot(kind)).slide(byMM: along(kind, 5))
            .rollThumb(toMM: (40, 10)).slide(byMM: along(kind, 24)).lift()
        let seen = slidePhases(kind, slide.frames)
        #expect(seen.first == .began && seen.last == .ended && !seen.contains(.cancelled))
        #expect(fired(slide.rollThumb(toMM: (10, 10)).tap(fingers: 1).frames).isEmpty)
        let landedAnew = slide.rollThumb(toMM: (10, 10)).liftThumb().thumb(atMM: (10, 10)).tap(fingers: 1)
        #expect(fired(landedAnew.frames) == [.one])
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func theThumbLiftingAndStayingAwayStillEndsTheSlideAndNothingFires(kind: SlideKind) {
        let frames = thumb.land(fingers: 2, atMM: pairSpot(kind)).slide(byMM: along(kind, 5)).liftThumb()
            .slide(byMM: along(kind, 24)).lift().frames
        #expect(slidePhases(kind, frames).last == .ended)
        #expect(fired(frames).isEmpty)
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func oneFingerLiftingLeavesTheSlideOnAndTheOtherKeepsSteering(kind: SlideKind) {
        let f = SlideFrames(kind: kind)
        let frames = [
            f.frame(atMS: 0, [f.thumb(.landing)]),
            f.frame(atMS: 50, [f.thumb(), f.finger(1, .landing, at: 62), f.finger(2, .landing, at: 70)]),
            f.frame(atMS: 60, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 70)]),
            f.frame(atMS: 100, [f.thumb(), f.finger(1, at: 80)]),
            f.frame(atMS: 150, [f.thumb(), f.finger(1, at: 90)]),
            f.frame(atMS: 200, [f.thumb()]),
        ]
        #expect(phasesMatch(slidePhases(kind, frames), [.began, .moved(travelMM: 14), .moved(travelMM: 24), .ended]))
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func aFingerThatDropsOutAndComesBackWithANewIDRejoinsWithoutAJump(kind: SlideKind) {
        let f = SlideFrames(kind: kind)
        let frames = [
            f.frame(atMS: 0, [f.thumb(.landing)]),
            f.frame(atMS: 50, [f.thumb(), f.finger(1, .landing, at: 62), f.finger(2, .landing, at: 70)]),
            f.frame(atMS: 60, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 74)]),
            f.frame(atMS: 70, [f.thumb(), f.finger(1, at: 70)]),
            f.frame(atMS: 80, [f.thumb(), f.finger(1, at: 74), f.finger(5, .landing, at: 90)]),
            f.frame(atMS: 90, [f.thumb(), f.finger(1, at: 78), f.finger(5, at: 94)]),
            f.frame(atMS: 100, [f.thumb()]),
        ]
        #expect(phasesMatch(
            slidePhases(kind, frames), [.began, .moved(travelMM: 4), .moved(travelMM: 8), .moved(travelMM: 12), .ended]))
    }

    @Test(arguments: [SlideKind.swipe, .windowSwipe])
    func theWholeHandLiftingTogetherEndsTheSlide(kind: SlideKind) {
        let f = SlideFrames(kind: kind)
        let frames = [
            f.frame(atMS: 0, [f.thumb(.landing)]),
            f.frame(atMS: 50, [f.thumb(), f.finger(1, .landing, at: 62), f.finger(2, .landing, at: 70)]),
            f.frame(atMS: 60, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 70)]),
            f.frame(atMS: 150, [f.thumb(), f.finger(1, at: 90), f.finger(2, at: 94)]),
            f.frame(atMS: 200, []),
        ]
        #expect(phasesMatch(slidePhases(kind, frames), [.began, .moved(travelMM: 24), .ended]))
        #expect(perFrame(frames).last?.blocks == false)
    }

    private var head: [TouchFrame] {
        let f = SlideFrames(kind: .windowSwipe)
        return [
            f.frame(atMS: 0, [f.thumb(.landing)]),
            f.frame(atMS: 50, [f.thumb(), f.finger(1, .landing, at: 62), f.finger(2, .landing, at: 70)]),
            f.frame(atMS: 60, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 70)]),
        ]
    }

    /// After the fingers lift with the thumb still down, a 1-finger tap.
    private var tapAfter: [TouchFrame] {
        let f = SlideFrames(kind: .windowSwipe)
        return [
            f.frame(atMS: 300, [f.thumb()]),
            f.frame(atMS: 400, [f.thumb(), f.finger(7, .landing, at: 62)]),
            f.frame(atMS: 450, [f.thumb()]),
        ]
    }

    @Test func aThirdFingerOutsideTheCornerCancelsAndNothingFollowsUntilTheFingersLift() {
        let f = SlideFrames(kind: .windowSwipe)
        let frames = head + [
            f.frame(atMS: 70, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 70), f.finger(3, .landing, at: 86)]),
            f.frame(atMS: 80, [f.thumb(), f.finger(1, at: 76), f.finger(2, at: 80), f.finger(3, at: 96)]),
        ] + tapAfter
        #expect(windowPhases(frames) == [.began, .cancelled])
        #expect(fired(frames) == [.one])
    }

    @Test(arguments: [TouchFrame.Press.blocked, .click])
    func aBlockedPressLeavesTheWindowSwipeAloneAndAClickCancelsIt(press: TouchFrame.Press) {
        let f = SlideFrames(kind: .windowSwipe)
        let frames = head + [
            f.frame(atMS: 70, [f.thumb(), f.finger(1, at: 66), f.finger(2, at: 70)], press: press),
            f.frame(atMS: 80, [f.thumb(), f.finger(1, at: 74), f.finger(2, at: 78)], press: press),
            f.frame(atMS: 100, [f.thumb()]),
        ] + tapAfter
        if press == .blocked {
            #expect(phasesMatch(windowPhases(frames), [.began, .moved(travelMM: 8), .ended]))
        } else {
            #expect(windowPhases(frames) == [.began, .cancelled])
        }
        #expect(fired(frames) == [.one])
    }

    @Test func twoFingersLiftingWhileAThirdLandsEndsItAndAClickOnTheLiftFrameCancelsIt() {
        let f = SlideFrames(kind: .windowSwipe)
        let landing = head + [f.frame(atMS: 100, [f.thumb(), f.finger(3, .landing, at: 86)])]
        let clicking = head + [f.frame(atMS: 100, [f.thumb()], press: .click)]
        #expect(windowPhases(landing) == [.began, .ended])
        #expect(windowPhases(clicking) == [.began, .cancelled])
        #expect(fired(clicking + tapAfter) == [.one])
    }

    @Test(arguments: [
        { (t: TouchScript) in t.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)).slide(byMM: (0, 24)).lift() },
        { (t: TouchScript) in t.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)).liftThumb()
            .slide(byMM: (0, 24)).thumb(atMM: (12, 10)).lift() },
        { (t: TouchScript) in t.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))
            .rollThumb(toMM: (40, 10)).slide(byMM: (0, 24)).lift() },
    ] as [@Sendable (TouchScript) -> TouchScript])
    func clicksAndDockSwipesStayBlockedForTheWholeWindowSwipe(script: @Sendable (TouchScript) -> TouchScript) {
        let frames = script(thumb).frames
        let seen = recognitions(frames)
        let began = seen.firstIndex { $0.windowSwipe == .began }!
        let ended = seen.firstIndex { $0.windowSwipe == .ended }!
        #expect(seen[began..<ended].allSatisfy { $0.blocksClicks && $0.blocksDockSwipes })
        #expect(seen[ended...].allSatisfy { !$0.blocksClicks })
    }
}
