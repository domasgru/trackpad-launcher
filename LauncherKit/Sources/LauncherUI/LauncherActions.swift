import AppKit
import LauncherCore

/// The System Settings panes the window opens.
enum SettingsPane {
    case trackpad
    case accessibility

    var url: URL {
        switch self {
        case .trackpad: URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")!
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}

/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    /// The cached icon, or a generic one: never draws, so the menu can use it on the click path.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot. Only for the closed button's app.
    let icon: (URL) -> NSImage
    let chooseOtherApp: (Gesture) -> Void
    /// Closes the window explicitly (System Settings takes focus; a held window must not sit over it), then opens the pane.
    let openSettings: (SettingsPane) -> Void
    let quit: () -> Void
}
