import AppKit
import LauncherCore

@MainActor public final class SystemRunningCopies: RunningCopies {
    /// The observations of a stop under way, alive until every listed copy has exited.
    private var watches: [NSKeyValueObservation] = []

    public init() {}

    public func others() -> [RunningCopy] {
        let own = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != own.processIdentifier }
            .map {
                RunningCopy(
                    id: CopyID(rawValue: $0.processIdentifier),
                    startedEarlier: Self.started(
                        ($0.launchDate, $0.processIdentifier), before: (own.launchDate, own.processIdentifier)))
            }
    }

    public func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void) {
        let apps = copies.compactMap { NSRunningApplication(processIdentifier: $0.id.rawValue) }
            .filter { !$0.isTerminated }
        let remaining = Remaining(count: apps.count)
        guard !apps.isEmpty else {
            exited()
            return
        }
        let finish: @MainActor () -> Void = { [weak self] in
            self?.watches = []
            exited()
        }
        watches = apps.map { app in
            app.forceTerminate()
            return app.observe(\.isTerminated, options: [.initial, .new]) { app, _ in
                guard app.isTerminated else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        if remaining.exit(app.processIdentifier) { finish() }
                    }
                }
            }
        }
    }

    public func endThisCopy() { NSApp.terminate(nil) }
}

/// Counts each listed copy's exit once; true on the one that completes the list.
private final class Remaining: @unchecked Sendable {
    private var count: Int
    private var seen: Set<pid_t> = []

    init(count: Int) { self.count = count }

    @MainActor func exit(_ pid: pid_t) -> Bool {
        guard seen.insert(pid).inserted else { return false }
        count -= 1
        return count == 0
    }
}

extension SystemRunningCopies {
    /// The one start order, a strict total order so two copies always give mirror-image answers: launch date first,
    /// a missing date counting as later than any date, then the lower pid. Pure; a test runs it over pairs.
    static func started(_ a: (launched: Date?, pid: pid_t), before b: (launched: Date?, pid: pid_t)) -> Bool {
        let (aDate, bDate) = (a.launched ?? .distantFuture, b.launched ?? .distantFuture)
        return aDate != bDate ? aDate < bDate : a.pid < b.pid
    }
}
