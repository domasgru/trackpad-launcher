import Testing
import LauncherCore

@Suite struct SwapRecognizerTests {
    private let h = HandFrames()

    private func rest(for ms: Int) -> TouchScript {
        TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(ms))
    }

    @Test(arguments: [(afterMS: 90, swaps: false), (110, true), (5000, true)])
    func theFingersMustHaveRestedAtLeastOneHundredMillisecondsBeforeTheThumbLands(afterMS: Int, swaps swapped: Bool) {
        let frames = rest(for: afterMS).thumbTap().frames
        #expect(swaps(frames) == (swapped ? [true] : []))
    }

    @Test(arguments: [(holdMS: 390, swaps: true), (410, false)])
    func theThumbMustLiftWithinTheTapWindow(holdMS: Int, swaps swapped: Bool) {
        let frames = rest(for: 150).thumbTap(hold: .milliseconds(holdMS)).frames
        #expect(swaps(frames) == (swapped ? [true] : []))
    }

    @Test(arguments: [(dragMM: 2.5, swaps: true), (3.5, false)])
    func theThumbMustNotDragMoreThanThreeMillimetres(dragMM: Double, swaps swapped: Bool) {
        let frames = rest(for: 150).thumbTap(dragMM: dragMM).frames
        #expect(swaps(frames) == (swapped ? [true] : []))
    }

    @Test func beforeTheFirstSwapTheThumbRulesBlockClicksForThreeSecondsAndDockSwipesWhileTheFingersAreDown() {
        let fingers = [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]
        let thumb = h.contact(9, atMM: 10, 10)
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, swaps: true, travel: .linear)
        _ = recognizer.step(h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]))
        _ = recognizer.step(h.frame(atMS: 150, fingers + [h.contact(9, .landing, atMM: 10, 10)]))
        let soon = recognizer.step(h.frame(atMS: 200, fingers + [thumb]))
        let late = recognizer.step(h.frame(atMS: 3200, fingers + [thumb]))
        let gone = recognizer.step(h.frame(atMS: 4000, [thumb]))

        #expect(soon.blocksClicks && soon.blocksDockSwipes)
        #expect(!late.blocksClicks && late.blocksDockSwipes)
        #expect(!gone.blocksClicks && !gone.blocksDockSwipes)
    }

    @Test func aThumbThatRollsOutOfTheCornerIsARestFingerAndTheNextLandingIsJudgedAnew() {
        let script = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
            .thumb(atMM: (10, 10)).wait(.milliseconds(200))
            .rollThumb(toMM: (40, 10)).wait(.milliseconds(550))
            .lift().wait(.milliseconds(150)).tap(fingers: 1)
            .liftThumb().wait(.milliseconds(100))
            .thumb(atMM: (10, 10)).tap(fingers: 1)
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, swaps: true, travel: .linear)
        let recognitions = script.frames.map { (time: $0.time.seconds - 1.0, recognition: recognizer.step($0)) }

        for (time, recognition) in recognitions where time >= 0.2 && time < 0.4 {
            #expect(recognition.blocksClicks && recognition.blocksDockSwipes, "held thumb at \(time)")
        }
        for (time, recognition) in recognitions where time >= 0.44 && time < 1.6 {
            #expect(!recognition.blocksClicks && !recognition.blocksDockSwipes, "rolled thumb at \(time)")
        }
        #expect(recognitions.compactMap(\.recognition.event) == [.fired(.one)])
        #expect(recognitions.last { $0.recognition.event != nil }!.time > 1.6)
    }

    @Test func aThumbThatRolledOutOfTheCornerAndLiftedDoesNotSpoilTheNextThumbTapUnderTheSameFingers() {
        let rolled = { (script: TouchScript) in
            script.thumb(atMM: (10, 10)).wait(.milliseconds(100)).rollThumb(toMM: (40, 10)).wait(.milliseconds(300))
                .liftThumb().wait(.milliseconds(100))
        }
        #expect(swaps(rolled(rest(for: 150)).thumbTap().frames) == [true])
        #expect(swaps(rolled(rest(for: 150).thumbTap()).thumbTap().frames) == [true, false])
    }

    @Test func withSwapsOffAThumbUnderRestingFingersOnlyFollowsTheThumbRules() {
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, swaps: false, travel: .linear)
        let frames = rest(for: 150).thumbTap().frames
        let recognitions = frames.map { recognizer.step($0) }
        let thumbDown = zip(frames, recognitions).filter { $0.0.touches.count == 3 }.map(\.1)
        #expect(recognitions.allSatisfy { $0.event == nil })
        #expect(!thumbDown.isEmpty)
        #expect(thumbDown.allSatisfy { $0.blocksClicks && $0.blocksDockSwipes })
    }

    @Test func theSeriesBlocksClicksAndDockSwipesWhileAnyRestFingerIsDownWhateverTheClockDid() {
        let first = [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]
        let thumb = h.contact(9, atMM: 10, 10)
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, swaps: true, travel: .linear)
        func step(_ ms: Int, _ touches: [Touch]) -> Recognition { recognizer.step(h.frame(atMS: ms, touches)) }

        _ = step(0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)])
        _ = step(150, first + [h.contact(9, .landing, atMM: 10, 10)])
        let swapped = step(250, first)
        #expect(swapped.event == .swap(startsSeries: true))
        #expect(swapped.blocksClicks && swapped.blocksDockSwipes)

        for ms in [1000, 3500, 5000] {
            let held = step(ms, first)
            #expect(held.blocksClicks && held.blocksDockSwipes, "series at \(ms)")
        }

        _ = step(5200, first + [h.contact(9, .landing, atMM: 10, 10)])
        let again = step(5300, first)
        #expect(again.event == .swap(startsSeries: false))

        let oneUp = step(6000, [first[1]])
        #expect(oneUp.blocksClicks && oneUp.blocksDockSwipes)
        let bothUp = step(7000, [])
        #expect(!bothUp.blocksClicks && !bothUp.blocksDockSwipes)
    }

    @Test func onlyTheFirstSwapOfARestStartsASeries() {
        let twoTaps = rest(for: 150).thumbTap().thumbTap().frames
        #expect(swaps(twoTaps) == [true, false])

        let fresh = rest(for: 150).thumbTap().lift().land(fingers: 2).wait(.milliseconds(150)).thumbTap().frames
        #expect(swaps(fresh) == [true, true])

        let rejoined = rest(for: 150).thumbTap().lift(.first).land(fingers: 1).wait(.milliseconds(150)).thumbTap().frames
        #expect(swaps(rejoined) == [true, false])
    }
}
