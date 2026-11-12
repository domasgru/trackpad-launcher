import Testing
import LauncherCore

@Suite struct CopyTests {
    @Test func theAccessibilityHintAsksForAccessAndBothHintsShareOneButtonTitle() {
        #expect(Copy.accessibilityHint == "Allow Accessibility access to make trackpad gestures work reliably.")
        #expect(Copy.openSettingsButton == "Open Settings…")
    }

    @Test func theMixedTrackpadsRowsAreNamedAndTitled() {
        #expect(Copy.thumbCornerGroupTitle == "Thumb corner:")
        #expect(Copy.macBookTrackpadRow == "MacBook trackpad")
        #expect(Copy.externalTrackpadRow == "External trackpad")
    }

    @Test func theThumbCornerRowNamesItsFourChoicesInOrder() {
        #expect(Copy.thumbCornerRow == "Thumb corner")
        #expect(ThumbCorner.allCases == [.topLeft, .topRight, .bottomLeft, .bottomRight])
        #expect(
            ThumbCorner.allCases.map(Copy.thumbCornerTitle) == ["Top left", "Top right", "Bottom left", "Bottom right"])
    }

    @Test func theScreenRecordingHintSaysWhatNeedsIt() {
        #expect(Copy.screenRecordingHint == "Allow Screen Recording access to show previews in the window switcher.")
    }

    @Test func theWindowSwitcherNamesItsBadgeVerbatim() {
        #expect(Copy.minimisedBadge == "Minimised")
    }

    @Test func theNoTrackpadNoticeSaysWhatToDo() {
        #expect(Copy.inactiveNotice(for: .noTrackpad) == "No trackpad connected. Connect a trackpad to use gestures.")
    }
}
