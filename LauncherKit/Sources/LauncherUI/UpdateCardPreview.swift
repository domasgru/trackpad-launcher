import Foundation
import LauncherCore

/// What the settings window shows as the update card. A Debug build's updater has no ports, since only a Developer ID
/// copy gets them, so launching it with `-PreviewUpdateCard YES` shows the card as *Update available*, with an
/// *Update now* that does nothing, to work on its look. Release builds always show the updater's own card.
enum UpdateCardPreview {
    static func card(_ updaterCard: UpdateCard?) -> UpdateCard? {
        #if DEBUG
            if updaterCard == nil, UserDefaults.standard.bool(forKey: "PreviewUpdateCard") { return .available }
        #endif
        return updaterCard
    }
}
