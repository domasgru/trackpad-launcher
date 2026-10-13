import Testing
import LauncherCore

@Suite struct CopyTests {
    @Test func theHintNamesFiveFingersAndTheCornerOfTheHandAndMentionsTheSwipeOnlyWhileItIsOn() {
        let tail = ", or swipe left or right with 2 fingers to switch apps"
        let right = "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app"
        let left = "● Hold thumb on top-right corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app"
        #expect(Copy.gestureHint(for: .right, swipe: true) == right + tail)
        #expect(Copy.gestureHint(for: .right, swipe: false) == right)
        #expect(Copy.gestureHint(for: .left, swipe: true) == left + tail)
        #expect(Copy.gestureHint(for: .left, swipe: false) == left)
    }

    @Test func theAccessibilityHintNamesScrolling() {
        #expect(
            Copy.accessibilityHint
                == "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them.")
    }
}
