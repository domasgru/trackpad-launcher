import Foundation

/// The strings the window quotes verbatim, kept in core so they are tested as values.
public enum Copy {
    public static let accessibilityHint =
        "Clicks and scrolling aren't blocked during gestures, and windows can't be switched. "
        + "Allow Accessibility access to do both."

    /// The red button that ends the settings window.
    public static let quitButton = "Quit Trackpad Launcher"

    /// The move dialog's message and buttons.
    public static let moveDialogTitle = "Trackpad Launcher needs to be in the Applications folder"
    public static let moveDialogMessage = "Move it there to finish installing. The copy you opened will be removed."
    public static let moveButton = "Move to Applications"
    public static let moveQuitButton = "Quit"
    public static let cannotWriteToApplications = "This account can't change the Applications folder."
    public static let applicationsFolderNotChanged = "The Applications folder could not be changed."
    public static let moveFailedTitle = "Trackpad Launcher couldn't be moved to the Applications folder"

    /// The app menu's item in Quit's place.
    public static let closeSettings = "Close Settings"

    /// Shown in the settings window while Screen Recording is missing and the window swipe is on.
    public static let screenRecordingHint = "Window previews need Screen Recording."

    public static func screenRecordingButton(_ hint: ScreenRecordingHint) -> String {
        switch hint {
        case .ask: "Allow Screen Recording…"
        case .openSettings: "Open System Settings…"
        }
    }

    /// The badge on a minimised window's row.
    public static let minimisedBadge = "Minimised"

    /// What a window with no title reads as: the app's name and its 1-based row.
    public static func untitledWindow(of appName: String, position: Int) -> String {
        "\(appName) — Window \(position)"
    }

    /// The sentence shown in place of the hint while gestures are inactive. The list is joined in English whatever the
    /// user's locale, because the sentence around it is English.
    public static func inactiveNotice(for cause: InactiveCause) -> String {
        switch cause {
        case .noTrackpad:
            "No trackpad connected. Connect a trackpad to use gestures."
        case .settings(let conflicting):
            "Gestures are off while these trackpad settings are on: "
                + conflicting.settings.map(\.noticeName).formatted(.list(type: .and).locale(Locale(identifier: "en")))
                + "."
        }
    }
}
