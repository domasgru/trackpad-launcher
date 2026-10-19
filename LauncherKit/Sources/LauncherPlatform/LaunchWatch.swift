import AppKit
import LauncherCore

/// Watches one launch a gesture started, from macOS's answer to `openApplication` until `stop()`: the process's
/// finishing and ending by key-value observation, which macOS pushes for every kind of app. Reports each fact at most
/// once, nothing after `stop()`, and holds nothing once stopped.
@MainActor final class LaunchWatch {
    private let report: @MainActor (LaunchProgress) -> Void
    private var process: NSRunningApplication?
    private var observations: [NSKeyValueObservation] = []
    private var hasFinished = false
    private var hasGoneNowhere = false
    private var isStopped = false

    init(report: @escaping @MainActor (LaunchProgress) -> Void) { self.report = report }

    /// macOS's answer, from any thread. Hops to the main actor with only the pid.
    nonisolated func opened(_ pid: pid_t?) {
        Task { @MainActor [weak self] in self?.adopt(pid) }
    }

    /// Invalidates the observations. Idempotent.
    func stop() {
        isStopped = true
        observations.forEach { $0.invalidate() }
        observations = []
        process = nil
    }

    private func adopt(_ pid: pid_t?) {
        guard !isStopped else { return }
        guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        else { return wentNowhere() }
        process = app
        // Each handler hops to the main actor: KVO pushes on whichever thread changed the property.
        observations = [
            app.observe(\.isTerminated, options: [.initial, .new]) { [weak self] _, change in
                guard change.newValue == true else { return }
                Task { @MainActor [weak self] in self?.wentNowhere() }
            },
            app.observe(\.isFinishedLaunching, options: [.initial, .new]) { [weak self] _, change in
                guard change.newValue == true else { return }
                Task { @MainActor [weak self] in self?.finished() }
            },
        ]
    }

    private func finished() {
        guard !isStopped, !hasFinished else { return }
        hasFinished = true
        report(.finishedLaunching)
    }

    private func wentNowhere() {
        guard !isStopped, !hasGoneNowhere else { return }
        hasGoneNowhere = true
        report(.wentNowhere)
    }
}
