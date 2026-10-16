import Foundation

/// The strings the window quotes verbatim, kept in core so they are tested as values.
public enum Copy {
    /// `●` and `◉` are the two marks the view draws as its template images.
    public static func gestureHint(for handMode: HandMode, swipe: Bool) -> String {
        let tap =
            "● Hold thumb on \(handMode.cornerName) corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app"
        return swipe ? tap + ", or swipe left or right with 2 fingers to switch apps" : tap
    }

    public static let accessibilityHint =
        "Clicks and scrolling aren't blocked during gestures, and windows can't be switched. "
        + "Allow Accessibility access to do both."

    /// Shown in the launcher window while Screen Recording is missing and the window swipe is on.
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
