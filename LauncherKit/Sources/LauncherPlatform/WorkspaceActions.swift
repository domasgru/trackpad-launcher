import AppKit
import LauncherCore

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    private let reader = RunningAppsReader()
    private let windows = FrontmostAppWindows()
    private let promptsUser: Bool
    /// One per bounce playing, from `bringToFrontBouncing` to `endLaunchBounce`.
    private var launches: [BundleID: Launch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    /// The frontmost app waiting to be hidden until the app being kept has come to the front.
    private var pendingHide: PendingHide?

    private struct PendingHide {
        let app: NSRunningApplication
        let kept: String
        let observer: any NSObjectProtocol
    }

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

    public func hideOtherApps(than app: BundleID) {
        forgetPendingHide()
        let kept = app.rawValue
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != kept
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let deferred = others.first { $0.processIdentifier == frontmost?.processIdentifier }
        let now = others.filter { $0.processIdentifier != deferred?.processIdentifier }
        // Hiding the frontmost app at once makes macOS activate the next visible app, which would land second in the
        // ⌘-Tab order above the app the user came from.
        Task { @MainActor in
            for other in now { Self.hide(other) }
        }
        guard let deferred else { return }
        // Alive only while the hide is pending.
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let activated =
                (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
            MainActor.assumeIsolated { self?.applicationActivated(activated) }
        }
        pendingHide = PendingHide(app: deferred, kept: kept, observer: observer)
    }

    /// This process hides with the app's own hide. The activation policy stays regular, so the Dock icon remains.
    private static func hide(_ app: NSRunningApplication) {
        if app.processIdentifier == NSRunningApplication.current.processIdentifier {
            NSApp.hide(nil)
        } else {
            app.hide()
        }
    }

    private func applicationActivated(_ bundleIdentifier: String?) {
        guard let pending = pendingHide else { return }
        forgetPendingHide()
        if bundleIdentifier == pending.kept { Self.hide(pending.app) }
    }

    private func forgetPendingHide() {
        guard let pending = pendingHide else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(pending.observer)
        pendingHide = nil
    }

    public func hasProcess(_ app: BundleID) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).allSatisfy(\.isTerminated)
    }

    public func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        let id = app.bundleID
        guard launches[id] == nil else { return bringToFront(app) }
        let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.report($0, of: id) }
        let watch = LaunchWatch(report: report)
        launches[id] = Launch(watch: watch)
        // The app first: nothing below can delay it.
        open(app, then: watch.opened)
        watch.start(cap: cap)
        bounces.start(app)
    }

    public func limitLaunchBounce(of app: BundleID, to limit: Duration) { launches[app]?.watch.limit(to: limit) }

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
