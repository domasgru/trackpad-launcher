import LauncherCore

/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    /// The catalog, enumerated each time a picker's menu opens.
    let installedApps: () -> [AppEntry]
    let chooseOtherApp: (Gesture) -> Void
    let openTrackpadSettings: () -> Void
    let quit: () -> Void
}
