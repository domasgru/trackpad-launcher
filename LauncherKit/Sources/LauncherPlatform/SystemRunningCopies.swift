import AppKit
import LauncherCore

@MainActor public final class SystemRunningCopies: RunningCopies {
    /// The watches of a stop under way, alive until every listed copy has exited.
    private var watches: [Watch] = []

    private let bundleIdentifier: String?

    public convenience init() { self.init(bundleIdentifier: Bundle.main.bundleIdentifier) }

    init(bundleIdentifier: String?) { self.bundleIdentifier = bundleIdentifier }

    public func others() -> [RunningCopy] {
        let own = NSRunningApplication.current
        guard let bundleIdentifier else { return [] }
        return Self.family(of: bundleIdentifier)
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
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
            if let self {
                for watch in self.watches { watch.invalidate() }
                self.watches = []
            }
            exited()
        }
        watches = apps.map { app in
            app.forceTerminate()
            return Watch(app) { app in
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

/// One stopped copy's application and the observation of its exit. An observation does not retain the object it
/// observes, and an `NSRunningApplication` that deallocates with observers still registered crashes in
/// `removeObserver:forKeyPath:` (the autorelease pool of the Apple Event that runs `stop` can be what releases it). So
/// the watch owns the application, and invalidates the observation before the application is released: a class's
/// deinit body runs while its stored properties are still alive, whichever path drops the watch.
@MainActor private final class Watch {
    private let app: NSRunningApplication
    private let observation: NSKeyValueObservation

    init(_ app: NSRunningApplication, onChange: @escaping @Sendable (NSRunningApplication) -> Void) {
        self.app = app
        observation = app.observe(\.isTerminated, options: [.initial, .new]) { app, _ in onChange(app) }
    }

    /// Idempotent: Foundation ignores a second invalidation.
    func invalidate() { observation.invalidate() }

    isolated deinit { invalidate() }
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
    /// The identifiers of every build of the app a bundle identifier belongs to: the release one and its `.debug`
    /// twin, whichever of the two is given. Pure.
    static func family(of bundleIdentifier: String) -> Set<String> {
        let suffix = ".debug"
        let release = bundleIdentifier.hasSuffix(suffix) ? String(bundleIdentifier.dropLast(suffix.count)) : bundleIdentifier
        return [release, release + suffix]
    }

    /// The one start order, a strict total order so two copies always give mirror-image answers: launch date first,
    /// a missing date counting as later than any date, then the lower pid. Pure; a test runs it over pairs.
    static func started(_ a: (launched: Date?, pid: pid_t), before b: (launched: Date?, pid: pid_t)) -> Bool {
        let (aDate, bDate) = (a.launched ?? .distantFuture, b.launched ?? .distantFuture)
        return aDate != bDate ? aDate < bDate : a.pid < b.pid
    }
}
