import Foundation
import LauncherCore

/// What a Debug copy renders in place of the model's values, for the hand checks. A Debug build's updater has no ports,
/// since only a Developer ID copy gets them, so launching it with `-PreviewUpdates <state>` shows what such a copy would,
/// to work on its look. The argument is read inside `#if DEBUG` only; Release builds show the model's values unchanged.
enum UpdatesPreview {
    /// `available`: the card as *Update available*, with an *Update now* that does nothing. `updating`: the card as
    /// *Updating…*. Otherwise the model's card.
    static func card(_ modelCard: UpdateCard?) -> UpdateCard? {
        #if DEBUG
            switch UserDefaults.standard.string(forKey: "PreviewUpdates") {
            case "available": return .available
            case "updating": return .updating
            default: break
            }
        #endif
        return modelCard
    }
}
