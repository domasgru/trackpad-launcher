import AppKit
import LauncherCore

/// The System Settings panes the settings window opens.
enum SettingsPane {
    case accessibility
    case screenRecording

    var url: URL {
        switch self {
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .screenRecording:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        }
    }
}

/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    /// The cached icon, or a generic one: never draws, so the menu can use it on the click path.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot. Only for the closed button's app.
    let icon: (URL) -> NSImage
    /// Other…: runs the file chooser for applications as a sheet on the settings window and hands the chosen app to the
    /// completion. Cancel, or closing the window, hands nothing over.
    let chooseOtherApp: (@escaping (URL) -> Void) -> Void
    /// The pick animation to play for an app pick now, or nil for none (Reduce motion).
    let pickAnimation: () -> PickAnimation?
    /// The update card arrow's drift now: the shipped one, or the Debug tuner's.
    let arrowDrift: () -> ArrowDrift
    /// Opens the System Settings pane; the settings window stays open.
    let openSettings: (SettingsPane) -> Void
    /// The *Quit Trackpad App* button.
    let quit: () -> Void
}
