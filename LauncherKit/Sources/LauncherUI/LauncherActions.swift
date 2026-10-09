import Foundation
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
    /// The catalog, enumerated each time a picker's menu opens.
    let installedApps: () -> [AppEntry]
    let chooseOtherApp: (Gesture) -> Void
    /// Closes the window explicitly (System Settings takes focus; a held window must not sit over it), then opens the pane.
    let openSettings: (SettingsPane) -> Void
    let quit: () -> Void
}
