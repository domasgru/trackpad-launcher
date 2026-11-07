import AppKit
import LauncherCore

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    private let reader = RunningAppsReader()
    private let windows = AppWindowReader()
    private let promptsUser: Bool
    /// One per watched launch, from `bringToFrontWatching` to `endLaunch`.
    private var launches: [BundleID: Launch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    private let hider = BackgroundHider()

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

    /// Every report for a launch, from its watch or its deadlines, passes the launch's gate first.
    private func report(_ progress: LaunchProgress, of app: BundleID) {
        guard var launch = launches[app], launch.gate.admits(progress) else { return }
        launches[app] = launch
        onLaunchProgress?(app, progress)
    }

    public func bringToFront(_ app: AppEntry) { open(app) }

    public func hideOtherApps(than app: BundleID) { hider.hideOthers(than: app) }

    public func hasProcess(_ app: BundleID) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).allSatisfy(\.isTerminated)
    }

    public func bringToFrontWatching(_ app: AppEntry, cap: Duration, bouncing: Bool) {
        let id = app.bundleID
        guard launches[id] == nil else { return bringToFront(app) }
        let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.report($0, of: id) }
        let watch = LaunchWatch(report: report)
        launches[id] = Launch(watch: watch)
        // The app first: nothing below can delay it.
        open(app, then: watch.opened)
        watch.start(cap: cap)
        if bouncing { bounces.start(app) }
    }

    public func limitLaunch(of app: BundleID, to limit: Duration) { launches[app]?.watch.limit(to: limit) }

    public func endLaunch(of app: BundleID, with ending: LaunchBounceEnding) {
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

    public func frontmostWindows(within deadline: Duration) -> FrontmostWindows {
        windows.readFrontmost(within: deadline)
    }

    public func readWindows(
        of apps: [AppEntry], within deadline: Duration,
        answer: @escaping @Sendable @MainActor (Int, WindowRead) -> Void
    ) {
        windows.readEach(apps, within: deadline, answer: answer)
    }

    public func raiseWindows(_ frontToBack: [WindowID]) { windows.raise(frontToBack) }

    public func openWindows(among ids: Set<WindowID>) -> Set<WindowID> { windows.openWindows(among: ids) }

    public func prepareLaunchAnimations(for apps: [AppEntry]) {
        overlay.prepare(for: apps)
    }

    public func playLaunchAnimation(for app: AppEntry) {
        overlay.play(for: app)
    }

    #if DEBUG
    private var tuner: AnimationTuner?

    /// The tuner's pick animation and Simulate Reduce motion switch now; during a preset's preview, that preset's
    /// pick animation.
    public var pickTuning: (animation: PickAnimation, simulateReduceMotion: Bool) {
        let tuning = LaunchTuning.current
        return (tuning.pick, tuning.forceReduceMotion)
    }

    /// Debug builds only. Opens the animation tuner; its launch and bounce previews play Finder's icon at the pointer,
    /// and its pick preview plays on the settings window's pickers, through the closures.
    public func showAnimationTuner(
        previewPick: @escaping @MainActor () -> Void, canPreviewPick: @escaping @MainActor () -> Bool
    ) {
        if tuner == nil {
            let finder = AppEntry(
                bundleID: BundleID(rawValue: "com.apple.finder"), name: "Finder",
                url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
            tuner = AnimationTuner(
                preview: { [overlay] in overlay.play(for: finder) },
                previewBounce: { [bounces] isOn in isOn ? bounces.preview(finder) : bounces.stopPreview(finder) },
                previewPick: previewPick, canPreviewPick: canPreviewPick)
        }
        tuner?.show()
    }
    #endif
}

/// What may still be reported for one launch: `.finishedLaunching` at most once, then exactly one of the others, then
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
