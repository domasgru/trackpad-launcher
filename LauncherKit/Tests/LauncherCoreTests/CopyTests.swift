import Testing
import LauncherCore

@Suite struct CopyTests {
    @Test func theAccessibilityHintAsksForAccessAndBothHintsShareOneButtonTitle() {
        #expect(Copy.accessibilityHint == "Allow Accessibility access to make trackpad gestures work reliably.")
        #expect(Copy.openSettingsButton == "Open Settings…")
    }

    @Test func aProgressLabelIsItsWordAndAnEllipsis() {
        #expect(ProgressLabel.checking.word == "Checking")
        #expect(ProgressLabel.checking.label == "Checking…")
        #expect(ProgressLabel.updating.word == "Updating")
        #expect(ProgressLabel.updating.label == "Updating…")
    }

    @Test func onlyAProgressTitleIsTypedAsWorkUnderWay() {
        #expect(ButtonTitle.plain("Check for updates…").text == "Check for updates…")
        #expect(ButtonTitle.progress(.checking).text == "Checking…")
    }

    @Test func theUpdatesRowIsTitledAndQuotesTheVersionWithoutABuildNumber() {
        #expect(Copy.automaticUpdatesRow == "Automatic updates")
        #expect(Copy.currentVersion("1.1.22") == "Current version: 1.1.22")
    }

    @Test func theCheckButtonTitlesItselfAndOnlyIdleIsEnabled() {
        #expect(CheckButton.idle.title == .plain("Check for updates…"))
        #expect(CheckButton.checking.title == .progress(.checking))
        #expect(CheckButton.updating.title == .progress(.updating))
        #expect(CheckButton.allCases.filter(\.isEnabled) == [.idle])
    }

    @Test func theInstallFailedAlertSaysTheRunningVersionKeepsRunning() {
        let alert = UpdateAlert.installFailed(running: "1.1.22")
        #expect(alert.title == "Couldn't install the update")
        #expect(alert.message == "Trackpad App 1.1.22 keeps running. Try again later.")
        #expect(alert.buttons.map(\.title) == ["OK"])
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
