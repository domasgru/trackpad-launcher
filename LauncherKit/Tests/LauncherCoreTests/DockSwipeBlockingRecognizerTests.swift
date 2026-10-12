import Testing
import LauncherCore

/// `Recognition.blocksDockSwipes`: an anchored thumb plus another contact, with no time limit, and the whole of a swipe.
@Suite struct DockSwipeBlockingRecognizerTests {
    private let h = HandFrames()

    private func blocking(_ frames: [TouchFrame]) -> [Bool] {
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, acceleration: .none)
        return frames.map { recognizer.step($0).blocksDockSwipes }
    }

    @Test func aThumbWithAnotherFingerBlocksLongPastTheClickWindowAndAThumbAloneNever() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 5000, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 5010, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 5020, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 5030, []),
        ]
        #expect(blocking(frames) == [false, false, true, false, false])
    }

    @Test func aThumbAlreadyRestingWhenRecognitionStartedBlocksToo() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .down, atMM: 10, 10)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
        ]
        #expect(blocking(frames) == [false, true])
    }

    @Test func fingersWithNoThumbInTheCornerNeverBlock() {
        let frames = [
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 50, 45), h.contact(2, .landing, atMM: 58, 45), h.contact(3, .landing, atMM: 66, 45)]),
            h.frame(atMS: 10, [h.contact(1, atMM: 60, 45), h.contact(2, atMM: 68, 45), h.contact(3, atMM: 76, 45)]),
        ]
        #expect(blocking(frames) == [false, false])
    }

    @Test func aSwipeBlocksToItsEndAfterTheThumbLifts() {
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 10, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 20, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 74, 45)]),
            h.frame(atMS: 30, [h.contact(1, atMM: 70, 45), h.contact(2, atMM: 78, 45)]),
            h.frame(atMS: 4000, [h.contact(1, atMM: 80, 45), h.contact(2, atMM: 88, 45)]),
            h.frame(atMS: 4010, []),
        ]
        let swipe = perFrame(frames).map(\.swipe)
        #expect(swipe[2] == .began && swipe[5] == .ended)
        #expect(blocking(frames) == [false, true, true, true, true, false])
    }
}
