import Testing
import LauncherCore

/// The option changes nothing for any touch in which a contact lands in the anchor corner before the pad next empties.
@Suite struct ThumblessTapRecognizerTests {
    private let plain = TouchScript(.macBook14)

    struct Touch: CustomTestStringConvertible, Sendable {
        let name: String
        let frames: [TouchFrame]
        /// The answer given to a window swipe's start, as the adapters give it.
        let answering: Bool
        var testDescription: String { name }
    }

    static let touches: [Touch] = {
        let plain = TouchScript(.macBook14)
        let thumb = plain.thumb(atMM: (10, 10))
        let hand = HandFrames()
        var list: [Touch] = []
        func add(_ name: String, _ frames: [TouchFrame], answering: Bool = true) {
            list.append(Touch(name: name, frames: frames, answering: answering))
        }
        for n in 1...6 { add("thumb then a tap of \(n)", thumb.tap(fingers: n).liftThumb().frames) }
        add("firm-pressed tap", thumb.tap(fingers: 1, click: .firm).liftThumb().frames)
        add("dragged tap", thumb.tap(fingers: 1, dragMM: (3.5, 0)).liftThumb().frames)
        add("held tap", thumb.tap(fingers: 1, hold: .milliseconds(410)).liftThumb().frames)
        add("swipe", thumb.land(fingers: 2).slide(byMM: (3.5, 0)).settle().slide(byMM: (12, 0)).settle().lift().liftThumb().frames)
        let windowSwipe = thumb.land(fingers: 2).slide(byMM: (0, 3.5)).settle().slide(byMM: (0, 12)).settle().lift().liftThumb().frames
        add("window swipe answered yes", windowSwipe)
        add("window swipe answered no", windowSwipe, answering: false)
        add(
            "thumb taps under a pair",
            plain.land(fingers: 2).wait(.milliseconds(150)).thumbTap().thumbTap().land(fingers: 1).lift().frames)
        add(
            "held thumb then a tap",
            plain.land(fingers: 2).wait(.milliseconds(150)).thumb(atMM: (10, 10)).wait(.milliseconds(500)).lift()
                .tap(fingers: 2).liftThumb().frames)
        add("thumb and finger together", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ])
        add("thumb lifting with the last finger", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 10, [hand.contact(100, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ])
        add("thumb rolling out under a finger", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 10, [hand.contact(100, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 50, [hand.contact(100, atMM: 60, 60), hand.contact(1, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ])
        add("thumb lifting as a finger lands", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 50, [hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 150),
        ])
        add("thumb rolling out as a finger lands", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 50, [hand.contact(100, atMM: 60, 60), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 150),
        ])
        return list
    }()

    @Test(arguments: touches, [true, false])
    func aTouchWithAContactInTheCornerIsRecognisedAsWithTheOptionOff(touch: Touch, swaps: Bool) {
        var on = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: swaps,
            thumblessTaps: true, travel: .linear)
        var off = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: swaps, travel: .linear)
        for (index, frame) in touch.frames.enumerated() {
            #expect(
                on.step(frame, answering: touch.answering) == off.step(frame, answering: touch.answering),
                "frame \(index)")
        }
    }

    @Test func aThumblessTapFiresOnTheLastLiftAndBlocksNothing() {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [], swaps: true, thumblessTaps: true, travel: .linear)
        let results = plain.tap(fingers: 2).frames.map { recognizer.step($0) }
        #expect(results.compactMap(\.fired) == [.two])
        #expect(results.allSatisfy { $0.blocking == .none && $0.opensLiftWindow == false })
    }

    @Test func withTheOptionOffTheSameTapFiresNothing() {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [], swaps: true, travel: .linear)
        #expect(plain.tap(fingers: 2).frames.compactMap { recognizer.step($0).fired }.isEmpty)
    }
}
