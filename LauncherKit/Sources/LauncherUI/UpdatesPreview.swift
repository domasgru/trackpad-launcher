import Foundation
import LauncherCore

/// What a Debug copy renders in place of the model's values, for the hand checks. A Debug build's updater has no ports,
/// since only a Developer ID copy gets them, so launching it with `-PreviewUpdates <state>` shows what such a copy would,
/// to work on its look. The argument is read inside `#if DEBUG` only; Release builds show the model's values unchanged.
enum UpdatesPreview {
    /// `available`: the card as *Update available*, with an *Update now* that does nothing. `updating`: the card as
    /// *Updating…*, whatever the switch says. Otherwise the model's card. `available` shows only while the switch is on,
    /// so turning it off removes the card as it does a real one.
    static func card(_ modelCard: UpdateCard?, isAutomaticUpdatesOn: Bool) -> UpdateCard? {
        #if DEBUG
            switch UserDefaults.standard.string(forKey: "PreviewUpdates") {
            case "available": return isAutomaticUpdatesOn ? .available : nil
            case "updating": return .updating
            default: break
            }
        #endif
        return modelCard
    }
}
