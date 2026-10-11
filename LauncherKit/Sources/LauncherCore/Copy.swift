import Foundation

/// The strings the window quotes verbatim, kept in core so they are tested as values.
public enum Copy {
    /// `●` and `◉` are the two marks the view draws as its template images.
    public static func gestureHint(for handMode: HandMode) -> String {
        "● Hold thumb on \(handMode.cornerName) corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps"
    }
}
