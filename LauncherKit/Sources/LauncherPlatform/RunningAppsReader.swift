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
        var entries: [Int32: AppEntry] = [:]
        var running: [(pid: Int32, launched: Date?)] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let entry = RunningApp.entry(for: app) else { continue }
            entries[app.processIdentifier] = entry
            running.append((app.processIdentifier, app.launchDate))
        }
        return FallbackOrder.pids(running: running, recency: tracker?.recency ?? []).compactMap { entries[$0] }
    }

    /// The active app. Trackpad Launcher is the frontmost app only while ⌘-Tab lists it (its Dock icon shows), as its
    /// listed entry. Active without it (the move dialog, the Debug animation tuner, a closing settings window), it stands
    /// for the app that was in front before it, the first ⌘-Tab app. Pure.
    static func frontmost(activePID: pid_t?, activeEntry: AppEntry?, ownPID: pid_t, apps: [AppEntry]) -> AppEntry? {
        guard let activePID else { return nil }
        guard activePID == ownPID else { return activeEntry }
        // LaunchServices lists the active app first, so a spelling mismatch still lands on Trackpad Launcher's own entry.
        return apps.first { $0.url == activeEntry?.url } ?? apps.first
    }
}
