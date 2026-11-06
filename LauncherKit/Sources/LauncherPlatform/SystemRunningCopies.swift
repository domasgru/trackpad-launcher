import AppKit
import LauncherCore

@MainActor public final class SystemRunningCopies: RunningCopies {
    /// The exit sources of a stop under way, alive until every listed copy has exited.
    private var exitSources: [DispatchSourceProcess] = []

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

    /// Each exit comes from the kernel. Observing `isTerminated` on an `NSRunningApplication` is not enough: on a busy
    /// machine that change was seen never to arrive for copies already gone and no longer listed, and the caller, which
    /// has no timeout, would wait forever. A source also reports a process gone before it registers, so a copy that
    /// exits at any moment here still counts.
    public func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void) {
        let apps = copies.compactMap { NSRunningApplication(processIdentifier: $0.id.rawValue) }
            .filter { !$0.isTerminated }
        guard !apps.isEmpty else {
            exited()
            return
        }
        let remaining = Remaining(count: apps.count)
        exitSources = apps.map { app in
            let pid = app.processIdentifier
            let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    guard remaining.exit(pid) else { return }
                    self?.endExitSources()
                    exited()
                }
            }
            source.resume()
            return source
        }
        for app in apps { app.forceTerminate() }
    }

    private func endExitSources() {
        for source in exitSources { source.cancel() }
        exitSources = []
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
