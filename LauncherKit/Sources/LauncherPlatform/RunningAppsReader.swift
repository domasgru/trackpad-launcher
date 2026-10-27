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
        let apps = order?.apps() ?? fallbackApps()
        let active = NSWorkspace.shared.frontmostApplication
        let frontmost = Self.frontmost(
            activePID: active?.processIdentifier, activeEntry: active.flatMap(RunningApp.entry(for:)),
            ownPID: ProcessInfo.processInfo.processIdentifier, apps: apps)
        return RunningApps(frontmost: frontmost, apps: apps)
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

    /// Never this process. While it is active (its settings window in front), the app that was in front before it: the
    /// first ⌘-Tab app, an order this process never enters (LaunchServices drops its pid; the tracker never notes it). Pure.
    static func frontmost(activePID: pid_t?, activeEntry: AppEntry?, ownPID: pid_t, apps: [AppEntry]) -> AppEntry? {
        guard let activePID else { return nil }
        return activePID == ownPID ? apps.first : activeEntry
    }
}
