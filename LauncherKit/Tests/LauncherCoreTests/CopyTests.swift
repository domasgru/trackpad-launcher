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

    @Test func theAccessibilityHintNamesScrollingAndSwitchingWindows() {
        #expect(
            Copy.accessibilityHint
                == "Clicks and scrolling aren't blocked during gestures, and windows can't be switched. "
                + "Allow Accessibility access to do both.")
    }

    @Test func theScreenRecordingHintSaysPreviewsNeedItAndItsButtonNamesWhatItDoes() {
        #expect(Copy.screenRecordingHint == "Window previews need Screen Recording.")
        #expect(Copy.screenRecordingButton(.ask) == "Allow Screen Recording…")
        #expect(Copy.screenRecordingButton(.openSettings) == "Open System Settings…")
    }

    @Test func theWindowSwitcherNamesItsBadgeVerbatim() {
        #expect(Copy.minimisedBadge == "Minimised")
    }

    @Test(arguments: [
        (cause: InactiveCause.noTrackpad, notice: "No trackpad connected. Connect a trackpad to use gestures."),
        (cause: .settings(ConflictingSettings([.tapToClick])!),
         notice: "Gestures are off while these trackpad settings are on: Tap to click."),
        (cause: .settings(ConflictingSettings([.tapToClick, .lookUpTapWithThreeFingers])!),
         notice: "Gestures are off while these trackpad settings are on: Tap to click and Look up: Tap with three fingers."),
    ])
    func theInactiveNoticeNamesTheCauseInTheSettingsOwnWords(cause: InactiveCause, notice: String) {
        #expect(Copy.inactiveNotice(for: cause) == notice)
    }
}
