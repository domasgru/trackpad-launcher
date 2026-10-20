import AppKit
import LauncherCore
import ServiceManagement

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    private let reader = RunningAppsReader()
    private let windows = FrontmostAppWindows()
    private let promptsUser: Bool
    /// One per bounce playing, from `bringToFrontBouncing` to `endLaunchBounce`.
    private var launches: [BundleID: Launch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?

    private struct Launch {
        let watch: LaunchWatch
        var gate = LaunchReportGate()
    }

    public convenience init() { self.init(screen: ScreenRead.now) }

    /// Tests inject the pointer-and-displays read (for example, one with no display), and turn off the system alert
    /// macOS shows for a bundle it refuses to open.
    init(screen: @escaping @MainActor () -> ScreenRead, promptsUser: Bool = true) {
        overlay = LaunchOverlay()
        bounces = BounceOverlay(launchOverlay: overlay, screen: screen)
        self.promptsUser = promptsUser
        // The first lookup in a process costs 1.65 ms, later ones under 0.1 ms: pay it now, not at a gesture.
        _ = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
    }

    /// Every report for a bounce, from its watch or its deadlines, passes the bounce's gate first.
    private func report(_ progress: LaunchProgress, of app: BundleID) {
        guard var launch = launches[app], launch.gate.admits(progress) else { return }
        launches[app] = launch
        onLaunchProgress?(app, progress)
    }

    public func bringToFront(_ app: AppEntry) { open(app) }

    public func hasProcess(_ app: BundleID) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).allSatisfy(\.isTerminated)
    }

    public func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        let id = app.bundleID
        guard launches[id] == nil else { return bringToFront(app) }
        let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.report($0, of: id) }
        let watch = LaunchWatch(report: report) { [bounces] wait, passed in bounces.after(wait, in: id, passed) }
        launches[id] = Launch(watch: watch)
        // The app first: nothing below can delay it.
        open(app, then: watch.opened)
        bounces.start(app, cap: cap) { report(.ranOut) }
    }

    public func limitLaunchBounce(of app: BundleID, to limit: Duration) { bounces.limit(app, to: limit) }

    public func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) {
        launches.removeValue(forKey: app)?.watch.stop()
        bounces.end(app, with: ending)
    }

    /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates. `opened`, when given, hears
    /// macOS's answer from any thread: the launched pid, or nil when it could not launch the app or the process
    /// ended before checking in (pid -1).
    private func open(_ app: AppEntry, then opened: (@Sendable (pid_t?) -> Void)? = nil) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = promptsUser
        guard let opened else {
            NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
            return
        }
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { running, error in
            guard error == nil, let running, !running.isTerminated, running.processIdentifier != -1 else {
                return opened(nil)
            }
            opened(running.processIdentifier)
        }
    }

    public func runningApps() -> RunningApps { reader.read() }

    public func frontmostWindows() -> FrontmostWindows { windows.read() }

    public func raiseWindows(_ frontToBack: [WindowID]) { windows.raise(frontToBack) }

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

    #if DEBUG
    private var tuner: AnimationTuner?

    /// Debug builds only. Opens the launch animation and bounce tuner; its previews play Finder's icon at the pointer.

    public func showAnimationTuner() {
        if tuner == nil {
            let finder = AppEntry(
                bundleID: BundleID(rawValue: "com.apple.finder"), name: "Finder",
                url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
            tuner = AnimationTuner(
                preview: { [overlay] in overlay.play(for: finder) },
                previewBounce: { [bounces] isOn in isOn ? bounces.preview(finder) : bounces.stopPreview(finder) })
        }
        tuner?.show()
    }
    #endif
}

/// What may still be reported for one bounce: `.finishedLaunching` at most once, then exactly one of the others, then
/// nothing. Pure; it makes `onLaunchProgress`'s contract true whoever receives the reports.
struct LaunchReportGate: Equatable {
    private var hasFinished = false
    private var hasEnded = false

    mutating func admits(_ progress: LaunchProgress) -> Bool {
        guard !hasEnded else { return false }
        switch progress {
        case .finishedLaunching:
            guard !hasFinished else { return false }
            hasFinished = true
        case .windowShown, .wentNowhere, .ranOut:
            hasEnded = true
        }
        return true
    }
}
