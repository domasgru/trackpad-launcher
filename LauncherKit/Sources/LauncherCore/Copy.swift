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
        "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them."

    /// The window switcher's single row when the frontmost app has no windows, or there is no frontmost app.
    public static let noOpenWindows = "No open windows"

    /// The window switcher's single row while Trackpad Launcher lacks the Accessibility permission.
    public static let accessibilityForWindows = "Allow Accessibility to switch windows"

    /// The badge on a minimised window's row.
    public static let minimisedBadge = "Minimised"

    /// What a window with no title reads as: the app's name, plus its 1-based row when the list has more than one.
    public static func untitledWindow(of appName: String, position: Int, rows: Int) -> String {
        rows > 1 ? "\(appName) — Window \(position)" : appName
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
