import Foundation

/// The strings the window quotes verbatim, kept in core so they are tested as values.
public enum Copy {
    public static let accessibilityHint = "Allow Accessibility access to make trackpad gestures work reliably."
    public static let accessibilityButton = "Open Accessibility Settings…"

    /// The red button that ends the settings window, beside *Close*.
    public static let quitButton = "Quit Trackpad Launcher"

    /// The move dialog's message and buttons.
    public static let moveDialogTitle = "Trackpad Launcher needs to be in the Applications folder"
    public static let moveDialogMessage = "Move it there to finish installing."
    public static let moveButton = "Move to Applications"
    public static let moveQuitButton = "Quit"
    public static let cannotWriteToApplications = "This account can't change the Applications folder."
    public static let applicationsFolderNotChanged = "The Applications folder could not be changed."
    public static let moveFailedTitle = "Trackpad Launcher couldn't be moved to the Applications folder"

    /// The update card's texts and buttons.
    public static func updateAvailable(_ version: Version) -> String { "App version \(version) is available" }
    public static let updateNowButton = "Update now"
    public static func updateDownloading(_ version: Version) -> String { "Downloading version \(version)…" }
    public static let cancelButton = "Cancel"
    public static func updateInstalling(_ version: Version) -> String { "Installing version \(version)…" }
    public static let updateFailed = "The update couldn't be installed."
    public static let tryAgainButton = "Try again"

    /// The settings window's thumb corner row and its pop-up's choices.
    public static let thumbCornerRow = "Thumb corner"
    public static func thumbCornerTitle(_ corner: ThumbCorner) -> String {
        switch corner {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }

    /// The app menu's item in Quit's place.
    public static let closeSettings = "Close Settings"

    /// Shown in the settings window while Screen Recording is missing and the window swipe is on.
    public static let screenRecordingHint = "Allow Screen Recording access to show previews in the window switcher."
    /// The same words whether the press asks macOS first or opens System Settings: either way the user ends up there.
    public static let screenRecordingButton = "Open Screen Recording Settings…"

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
