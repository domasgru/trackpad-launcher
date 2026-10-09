import AppKit
import LauncherCore
import ServiceManagement

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay

    public init() {
        overlay = LaunchOverlay()
    }

    /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates.
    /// The completion is ignored: its only reactions would be a log line or a dialog.
    public func bringToFront(_ app: AppEntry) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
    }

    /// Registration failing (unsigned build, user-disabled item) leaves the app running without a login item.
    public func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }

    public func prepareLaunchAnimations(for apps: [AppEntry]) {
        overlay.prepare(for: apps)
    }

    public func playLaunchAnimation(for app: AppEntry) {
        overlay.play(for: app)
    }
}
