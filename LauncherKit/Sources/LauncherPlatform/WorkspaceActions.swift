import AppKit
import LauncherCore
import ServiceManagement

@MainActor public final class WorkspaceActions: SystemActions {
    public init() {}

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
}
