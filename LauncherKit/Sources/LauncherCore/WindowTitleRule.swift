import Foundation

/// A built-in rewording of a window's title for the window switcher, keyed by the app's bundle identifier. An app
/// without a rule shows its titles exactly as it gives them. Adding an app is one entry in `rules`; a new shape of
/// rewording is one new case with its own `apply`.
enum WindowTitleRule: Sendable {
    /// Splits the title on `separator`, then puts the second part first: `a — b — c` reads `b — a — c`. A title with
    /// fewer than two parts is left alone, and no part's text changes.
    case leadWithSecondPart(separator: String)

    private static let rules: [BundleID: WindowTitleRule] = [
        BundleID(rawValue: "com.microsoft.VSCode"): .leadWithSecondPart(separator: " — "),
        BundleID(rawValue: "com.microsoft.VSCodeInsiders"): .leadWithSecondPart(separator: " — "),
    ]

    /// `title` as the window switcher shows it for a window of `app`: reworded by the app's rule when it has one,
    /// otherwise unchanged.
    static func displayTitle(_ title: String, of app: BundleID) -> String {
        rules[app]?.apply(to: title) ?? title
    }

    func apply(to title: String) -> String {
        switch self {
        case .leadWithSecondPart(let separator):
            let parts = title.components(separatedBy: separator)
            guard parts.count >= 2 else { return title }
            return ([parts[1], parts[0]] + parts.dropFirst(2)).joined(separator: separator)
        }
    }
}
