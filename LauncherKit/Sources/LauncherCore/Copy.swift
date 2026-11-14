import Foundation

/// The strings the window quotes verbatim, kept in core so they are tested as values.
public enum Copy {
    public static let accessibilityHint = "Allow Accessibility access to make trackpad gestures work reliably."

    /// Both permission hints' button: the same words whether a press asks macOS first or opens System Settings, since
    /// either way the user ends up there.
    public static let openSettingsButton = "Open Settings…"

    /// The red button that ends the settings window, beside *Close*.
    public static let quitButton = "Quit Trackpad App"

    /// The move dialog's message and buttons.
    public static let moveDialogTitle = "Trackpad App needs to be in the Applications folder"
    public static let moveDialogMessage = "Move it there to finish installing."
    public static let moveButton = "Move to Applications"
    public static let moveQuitButton = "Quit"
    public static let cannotWriteToApplications = "This account can't change the Applications folder."
    public static let applicationsFolderNotChanged = "The Applications folder could not be changed."
    public static let moveFailedTitle = "Trackpad App couldn't be moved to the Applications folder"

    /// The update card's text and its button's two titles.
    public static let updateAvailable = "Update available"
    public static let updateNowButton = "Update now"
    public static let checkingWord = "Checking"
    public static let updatingWord = "Updating"

    /// The settings window's Automatic updates row.
    public static let automaticUpdatesRow = "Automatic updates"
    public static func currentVersion(_ version: AppVersion) -> String { "Current version: \(version)" }
    public static let checkForUpdatesButton = "Check for updates…"

    /// The update alerts.
    public static let restartToUpdateTitle = "Restart Trackpad App to update?"
    public static func restartToUpdateMessage(from running: AppVersion, to new: AppVersion) -> String {
        "Update Trackpad App from \(running) to \(new).\n\nTrackpad App will quit to install the update and open again."
    }
    public static let upToDateTitle = "Trackpad App is up to date"
    public static func upToDateMessage(_ running: AppVersion) -> String { "You're running the latest version, \(running)." }
    public static let checkFailedTitle = "Couldn't check for updates"
    public static let checkFailedMessage = "Check your internet connection and try again."
    public static let installFailedTitle = "Couldn't install the update"
    public static func installFailedMessage(running: AppVersion) -> String {
        "Trackpad App \(running) keeps running. Try again later."
    }
    public static let updatesUnavailableTitle = "Updates aren't available for this copy"
    public static let updatesUnavailableMessage = "This copy of Trackpad App can't update itself."
    public static let updateButton = "Update"
    public static let notNowButton = "Not now"
    public static let okButton = "OK"

    /// The settings window's thumb corner row and its pop-up's choices.
    public static let thumbCornerRow = "Thumb corner"
    public static let thumbCornerGroupTitle = "Thumb corner:"
    public static let macBookTrackpadRow = "MacBook trackpad"
    public static let externalTrackpadRow = "External trackpad"
    public static func thumbCornerTitle(_ corner: ThumbCorner) -> String {
        switch corner {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }

    /// The plus and minus buttons beside a gesture's app pickers: tooltip and accessibility label.
    public static let addSecondApp = "Add a second app"
    public static let removeSecondApp = "Remove the second app"

    /// The window switcher's card for an app with one window, or none.
    public static let noOtherWindowsTitle = "No other windows"
    public static func noOtherWindowsMessage(of app: String) -> String { "\(app) has no other windows on this desktop." }
    public static let noOpenWindowsTitle = "No open windows"
    public static func noOpenWindowsMessage(of app: String) -> String { "\(app) has no windows on this desktop." }

    /// The app menu's item in Quit's place.
    public static let closeSettings = "Close Settings"

    /// Shown in the settings window while Screen Recording is missing and the window swipe is on.
    public static let screenRecordingHint = "Allow Screen Recording access to show previews in the window switcher."

    /// The badge on a minimised window's row.
    public static let minimisedBadge = "Minimised"

    /// What a window with no title reads as: the app's name and its 1-based row.
    public static func untitledWindow(of appName: String, position: Int) -> String {
        "\(appName) — Window \(position)"
    }

    /// The sentence the settings window shows while gestures are inactive.
    public static func inactiveNotice(for cause: InactiveCause) -> String {
        switch cause {
        case .noTrackpad: "No trackpad connected. Connect a trackpad to use gestures."
        }
    }
}
