import AppKit
import LauncherCore

/// The whole running-apps read behind `SystemActions.runningApps()`. Holds no window, so tests construct it alone.
@MainActor final class RunningAppsReader {
    private let order: LaunchServicesOrder?

    /// `order`: the ⌘-Tab order; resolved from the system by default. The one internal seam, used by tests.
    init(order: LaunchServicesOrder? = LaunchServicesOrder()) {
        self.order = order
    }

    /// The active app through the public read, and the ⌘-Tab apps. The list is empty when the order is missing.
    func read() -> RunningApps {
        RunningApps(frontmost: frontmost(), apps: order?.apps() ?? [])
    }

    /// nil when there is no active app, it has no bundle identifier or location, or it is this app, which never
    /// activates except around the Other… chooser.
    private func frontmost() -> AppEntry? {
        guard let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let identifier = app.bundleIdentifier, !identifier.isEmpty,
            let bundleURL = app.bundleURL
        else { return nil }
        let url = Self.location(ofBundleAtPath: bundleURL.path)
        return AppEntry(
            bundleID: BundleID(rawValue: identifier),
            name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, url: url)
    }

    /// One spelling of a running copy's location, so the same bundle read two ways compares equal.
    nonisolated static func location(ofBundleAtPath path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}
