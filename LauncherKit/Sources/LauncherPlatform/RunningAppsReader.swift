import AppKit
import LauncherCore

/// The whole running-apps read behind `SystemActions.runningApps()`. Holds no window, so tests construct it alone.
@MainActor final class RunningAppsReader {
    private let order: LaunchServicesOrder?
    private let tracker: ActivationTracker?

    /// True on the fallback path, where workspace activations are observed.
    var isTrackingActivations: Bool { tracker != nil }

    /// `order`: the ⌘-Tab order; resolved from the system by default. The one internal seam, used by tests.
    init(order: LaunchServicesOrder? = LaunchServicesOrder()) {
        self.order = order
        tracker = order == nil ? ActivationTracker() : nil
    }

    /// The active app through the public read, and the ⌘-Tab apps. Without the order, the apps are the workspace's Dock apps in the fallback order.
    func read() -> RunningApps {
        RunningApps(frontmost: frontmost(), apps: order?.apps() ?? fallbackApps())
    }

    private func fallbackApps() -> [AppEntry] {
        let own = ProcessInfo.processInfo.processIdentifier
        var entries: [Int32: AppEntry] = [:]
        var running: [(pid: Int32, launched: Date?)] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != own {
            guard let entry = RunningApp.entry(for: app) else { continue }
            entries[app.processIdentifier] = entry
            running.append((app.processIdentifier, app.launchDate))
        }
        return FallbackOrder.pids(running: running, recency: tracker?.recency ?? []).compactMap { entries[$0] }
    }

    /// nil when there is no active app, it has no bundle identifier or location, or it is this app, which never
    /// activates except around the Other… chooser.
    private func frontmost() -> AppEntry? {
        guard let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return RunningApp.entry(for: app)
    }
}
