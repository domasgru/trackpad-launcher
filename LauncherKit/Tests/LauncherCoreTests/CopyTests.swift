import Testing
import LauncherCore

@Suite struct CopyTests {
    @Test func theAccessibilityHintAsksForAccessAndItsButtonNamesThePane() {
        #expect(Copy.accessibilityHint == "Allow Accessibility access to make trackpad gestures work reliably.")
        #expect(Copy.accessibilityButton == "Open Accessibility Settings…")
    }

    @Test func theScreenRecordingHintSaysWhatNeedsItAndItsButtonNamesThePane() {
        #expect(Copy.screenRecordingHint == "Allow Screen Recording access to show previews in the window switcher.")
        #expect(Copy.screenRecordingButton == "Open Screen Recording Settings…")
    }

    @Test func theTrackpadSettingsNoticesButtonNamesThePane() {
        #expect(Copy.trackpadSettingsButton == "Open Trackpad Settings…")
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
