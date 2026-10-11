import Testing
import LauncherCore

@Suite struct CopyTests {
    @Test func theHintNamesFiveFingersAndTheSwipeWithTheCornerOfTheHand() {
        #expect(
            Copy.gestureHint(for: .right)
                == "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps"
        )
        #expect(
            Copy.gestureHint(for: .left)
                == "● Hold thumb on top-right corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps"
        )
    }
}
