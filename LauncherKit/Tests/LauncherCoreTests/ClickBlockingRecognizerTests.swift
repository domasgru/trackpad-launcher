import Testing
import LauncherCore

@Suite struct ClickBlockingRecognizerTests {
    private let h = HandFrames()

    @Test(arguments: [1000, 2900, 3100, 4000])
    func clicksAreBlockedOnlyWithinThreeSecondsOfTheThumbLanding(landMS: Int) {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: landMS, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
        ]
        #expect(blocking(frames) == [false, landMS < 3000])
    }

    @Test func expiryIsSeenOnAFrameWhereNothingButTheClockMoved() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 2950, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 2990, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 3010, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]),
        ]
        #expect(blocking(frames) == [false, true, true, false])
    }

    @Test(arguments: [
        TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(1)).liftThumb(),
        TouchScript(.macBook14).tap(fingers: 1),
    ])
    func aThumbAloneOrNoThumbNeverBlocks(script: TouchScript) {
        #expect(blocking(script.frames).allSatisfy { !$0 })
    }

    @Test func liftingTheThumbEndsBlockingAtOnce() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 200, [h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 300, [h.contact(1, atMM: 62, 45)]),
        ]
        #expect(blocking(frames) == [false, true, false, false])
    }

    @Test(arguments: [(thumbXMM: 26.5, blocks: true), (thumbXMM: 28.0, blocks: false)])
    func aThumbSlidingOutOfTheCornerStopsBlocking(thumbXMM: Double, blocks: Bool) {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 24, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 24, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 200, [h.contact(9, atMM: thumbXMM, 10), h.contact(1, atMM: 62, 45)]),
        ]
        #expect(blocking(frames) == [false, true, blocks])
    }

    @Test(arguments: [Touch.Phase.down, .landing])
    func aThumbAlreadyRestingOnTheFirstFrameOpensNoWindow(phase: Touch.Phase) {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, phase, atMM: 10, 10)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 200, []),
            h.frame(atMS: 300, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 350, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
        ]
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
        #expect(frames.map { recognizer.step($0).blocksClicks } == [false, false, false, false, false, true])
    }

    @Test(arguments: [TouchFrame.Press.blocked, .click], [true, false])
    func aBlockedPressIsPartOfTheTapAndADeliveredClickCancelsIt(press: TouchFrame.Press, onLanding: Bool) {
        let fingerAt100: [Touch] = [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]
        let fingerDown: [Touch] = [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 62, 45)]
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, fingerAt100, press: onLanding ? press : nil),
            h.frame(atMS: 110, fingerDown, press: press),
            h.frame(atMS: 120, fingerDown, press: press),
            h.frame(atMS: 130, [h.contact(9, atMM: 10, 10)], press: press),
            h.frame(atMS: 140, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 300, fingerAt100),
            h.frame(atMS: 310, fingerDown),
            h.frame(atMS: 330, [h.contact(9, atMM: 10, 10)]),
        ]
        #expect(fired(frames) == (press == .blocked ? [.one, .one] : [.one]))
    }
}

@Suite struct ClickFilterTests {
    private let p = PressID(button: 0, number: 1)

    @Test(arguments: [0, 1, 2])
    func aPressIsBlockedOrPassedAsAWholeWhateverTheFlagDoesBetween(button: Int) {
        let press = PressID(button: button, number: 7)

        var blocked = ClickFilter()
        #expect(blocked.decide(.press(press), trackpadBlocking: true) == .drop)
        #expect(blocked.holding == .withheld)
        #expect(blocked.decide(.release(press), trackpadBlocking: false) == .drop)
        #expect(blocked.holding == .nothing)

        var passed = ClickFilter()
        #expect(passed.decide(.press(press), trackpadBlocking: false) == .pass)
        #expect(passed.holding == .passed)
        #expect(passed.decide(.release(press), trackpadBlocking: true) == .pass)
        #expect(passed.holding == .nothing)
    }

    @Test func aNewPressOfAButtonEndsAStaleOneAndAnyReleaseOfTheButtonClearsIt() {
        var filter = ClickFilter()
        let p1 = PressID(button: 0, number: 1), p2 = PressID(button: 0, number: 2)
        let p3 = PressID(button: 0, number: 3), p4 = PressID(button: 0, number: 4)
        #expect(filter.decide(.press(p1), trackpadBlocking: false) == .pass)
        #expect(filter.decide(.press(p2), trackpadBlocking: true) == .drop)
        #expect(filter.holding == .withheld)
        #expect(filter.decide(.release(p2), trackpadBlocking: false) == .drop)
        #expect(filter.holding == .nothing)

        #expect(filter.decide(.press(p3), trackpadBlocking: true) == .drop)
        #expect(filter.decide(.release(p4), trackpadBlocking: false) == .pass)
        #expect(filter.holding == .nothing)
    }

    @Test func dragsBecomeMovesOnlyDuringAWithheldPressOfTheSameButton() {
        var filter = ClickFilter()
        let r0 = PressID(button: 1, number: 9)
        #expect(filter.decide(.drag(button: 0), trackpadBlocking: false) == .pass)

        _ = filter.decide(.press(p), trackpadBlocking: true)
        #expect(filter.decide(.drag(button: 0), trackpadBlocking: false) == .passAsMove)
        #expect(filter.decide(.drag(button: 1), trackpadBlocking: false) == .pass)

        _ = filter.decide(.press(r0), trackpadBlocking: false)
        #expect(filter.decide(.drag(button: 1), trackpadBlocking: false) == .pass)

        _ = filter.decide(.release(p), trackpadBlocking: false)
        #expect(filter.decide(.drag(button: 0), trackpadBlocking: false) == .pass)
    }

    @Test func pressureIsDroppedOnlyWhileAPressIsWithheld() {
        var filter = ClickFilter()
        #expect(filter.decide(.pressure, trackpadBlocking: false) == .pass)

        _ = filter.decide(.press(p), trackpadBlocking: true)
        #expect(filter.decide(.pressure, trackpadBlocking: false) == .drop)

        _ = filter.decide(.release(p), trackpadBlocking: false)
        #expect(filter.decide(.pressure, trackpadBlocking: false) == .pass)

        _ = filter.decide(.press(PressID(button: 0, number: 2)), trackpadBlocking: false)
        #expect(filter.decide(.pressure, trackpadBlocking: true) == .pass)
    }

    @Test func forgettingHeldPressesLetsALostReleasePassAndClearsHolding() {
        var withheld = ClickFilter()
        _ = withheld.decide(.press(p), trackpadBlocking: true)
        withheld.forgetHeldPresses()
        #expect(withheld.holding == .nothing)
        #expect(withheld.decide(.pressure, trackpadBlocking: false) == .pass)
        #expect(withheld.decide(.release(p), trackpadBlocking: false) == .pass)

        var passed = ClickFilter()
        _ = passed.decide(.press(PressID(button: 0, number: 2)), trackpadBlocking: false)
        passed.forgetHeldPresses()
        #expect(passed.holding == .nothing)
    }

    @Test func aWithheldPressWinsOverAPassedOneAndHoldingFollowsTheReleases() {
        var filter = ClickFilter()
        let r0 = PressID(button: 1, number: 5)
        _ = filter.decide(.press(p), trackpadBlocking: false)
        _ = filter.decide(.press(r0), trackpadBlocking: true)
        #expect(filter.holding == .withheld)
        _ = filter.decide(.release(r0), trackpadBlocking: false)
        #expect(filter.holding == .passed)
        _ = filter.decide(.release(p), trackpadBlocking: false)
        #expect(filter.holding == .nothing)
    }
}

@Suite struct PressSamplingTests {
    @Test(arguments: [
        (holding: ClickFilter.Holding.withheld, down: false, expected: TouchFrame.Press.blocked),
        (.withheld, true, .blocked),
        (.passed, true, .click),
        (.passed, false, nil),
        (.nothing, true, nil),
        (.nothing, false, nil),
        (nil, true, .click),
        (nil, false, nil),
    ] as [(holding: ClickFilter.Holding?, down: Bool, expected: TouchFrame.Press?)])
    func holdingAndButtonStateDecideWhatAFrameReads(
        holding: ClickFilter.Holding?, down: Bool, expected: TouchFrame.Press?
    ) {
        #expect(TouchFrame.Press(holding: holding, buttonDown: down) == expected)
    }
}
