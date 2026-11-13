import Testing
import LauncherCore

/// The option changes nothing for any touch in which a contact lands in the anchor corner before the pad next empties.
@Suite struct ThumblessTapRecognizerTests {
    private let plain = TouchScript(.macBook14)
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
    private let hand = HandFrames()

    private func touches() -> [(name: String, frames: [TouchFrame])] {
        var list: [(String, [TouchFrame])] = []
        for n in 1...6 { list.append(("thumb then a tap of \(n)", thumb.tap(fingers: n).liftThumb().frames)) }
        list.append(("firm-pressed tap", thumb.tap(fingers: 1, click: .firm).liftThumb().frames))
        list.append(("dragged tap", thumb.tap(fingers: 1, dragMM: (3.5, 0)).liftThumb().frames))
        list.append(("held tap", thumb.tap(fingers: 1, hold: .milliseconds(410)).liftThumb().frames))
        list.append((
            "swipe",
            thumb.land(fingers: 2).slide(byMM: (3.5, 0)).settle().slide(byMM: (12, 0)).settle().lift().liftThumb().frames
        ))
        list.append((
            "window swipe",
            thumb.land(fingers: 2).slide(byMM: (0, 3.5)).settle().slide(byMM: (0, 12)).settle().lift().liftThumb().frames
        ))
        list.append((
            "thumb taps under a pair",
            plain.land(fingers: 2).wait(.milliseconds(150)).thumbTap().thumbTap().land(fingers: 1).lift().frames
        ))
        list.append((
            "held thumb then a tap",
            plain.land(fingers: 2).wait(.milliseconds(150)).thumb(atMM: (10, 10)).wait(.milliseconds(500)).lift()
                .tap(fingers: 2).liftThumb().frames
        ))
        list.append(("thumb and finger together", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ]))
        list.append(("thumb lifting with the last finger", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 10, [hand.contact(100, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ]))
        list.append(("thumb rolling out under a finger", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 10, [hand.contact(100, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 50, [hand.contact(100, atMM: 60, 60), hand.contact(1, atMM: 60, 40)]),
            hand.frame(atMS: 100),
        ]))
        list.append(("thumb lifting as a finger lands", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 50, [hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 150),
        ]))
        list.append(("thumb rolling out as a finger lands", [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 50, [hand.contact(100, atMM: 60, 60), hand.contact(1, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 150),
        ]))
        return list
    }

    @Test(arguments: [true, false]) func aTouchWithAContactInTheCornerIsRecognisedAsWithTheOptionOff(swaps: Bool) {
        for (name, frames) in touches() {
            var on = GestureRecognizer(
                corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: swaps,
                thumblessTaps: true, travel: .linear)
            var off = GestureRecognizer(
                corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: swaps, travel: .linear)
            for (index, frame) in frames.enumerated() {
                #expect(on.step(frame, answering: true) == off.step(frame, answering: true), "\(name), frame \(index)")
            }
        }
    }

    @Test func aThumblessTapFiresOnTheLastLiftAndBlocksNothing() {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [], swaps: true, thumblessTaps: true, travel: .linear)
        let results = plain.tap(fingers: 2).frames.map { recognizer.step($0) }
        #expect(results.compactMap(\.fired) == [.two])
        #expect(results.allSatisfy { $0.blocking == .none && !$0.opensLiftWindow })
    }

    @Test func withTheOptionOffTheSameTapFiresNothing() {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [], swaps: true, travel: .linear)
        #expect(plain.tap(fingers: 2).frames.compactMap { recognizer.step($0).fired }.isEmpty)
    }
}
