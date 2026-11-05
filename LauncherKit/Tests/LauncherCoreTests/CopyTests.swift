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

    @Test func theWindowSwitcherNamesItsBadgeVerbatim() {
        #expect(Copy.minimisedBadge == "Minimised")
    }

    @Test func theUpdateCardQuotesItsTextsAndButtonsVerbatim() {
        let version = Version(1, 10, 0)
        #expect(Copy.updateAvailable(version) == "App version 1.10.0 is available")
        #expect(Copy.updateNowButton == "Update now")
        #expect(Copy.updateDownloading(version) == "Downloading version 1.10.0…")
        #expect(Copy.cancelButton == "Cancel")
        #expect(Copy.updateInstalling(version) == "Installing version 1.10.0…")
        #expect(Copy.updateFailed == "The update couldn't be installed.")
        #expect(Copy.tryAgainButton == "Try again")
    }

    @Test func theNoTrackpadNoticeSaysWhatToDo() {
        #expect(Copy.inactiveNotice(for: .noTrackpad) == "No trackpad connected. Connect a trackpad to use gestures.")
    }
}
