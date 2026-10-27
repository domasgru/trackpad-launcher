import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or the launch bounce from a gesture; no gesture closes the window. `fire`
/// shows either only while the launch animation setting is on: the bounce for an app with no process, the animation for
/// one with a process.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    /// Non-nil exactly while a swipe shows the switcher.
    public var switcher: Switcher? {
        if case .apps(let switcher)? = shown { switcher } else { nil }
    }
    /// Non-nil for the whole of a window swipe: it always shows.
    public var windowSwitcher: WindowSwitcher? {
        if case .windows(let switcher)? = shown { switcher } else { nil }
    }
    /// Every app picker's list. Replaced only by a scan; never emptied while one runs.
    public private(set) var installedApps: InstalledApps
    public var isWindowOpen: Bool { window != .closed }
    public var handMode: HandMode { settings.handMode }
    public var isLaunchAnimationOn: Bool { settings.isLaunchAnimationOn }
    public var isSwipeOn: Bool { settings.isSwipeOn }
    public var isSwapOn: Bool { settings.isSwapOn }
    public var isWindowSwipeOn: Bool { settings.isWindowSwipeOn }
    /// One derivation, read by the icon, the notice and the fire guard.
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }

    /// Drives the Accessibility hint. Deliberately not part of `activity`, so the icon never reads it.
    public private(set) var isAccessibilityGranted = false
    /// Read with Accessibility on every push, so a window swipe never reads it.
    private var isScreenRecordingGranted = false

    /// nil while the window swipe setting is off or Screen Recording is granted.
    public var screenRecordingHint: ScreenRecordingHint? {
        guard settings.isWindowSwipeOn, !isScreenRecordingGranted else { return nil }
        return settings.hasAskedForScreenRecording ? .openSettings : .ask
    }

    public enum Window: Equatable, Sendable {
        case closed
        /// `request` counts the openings by hand in this process. Each one brings the settings window to the front with
        /// the keyboard focus, restoring it when minimised; centring on the pointer's display happens only from
        /// `.closed`.
        case open(request: Int)
    }

    public private(set) var window: Window = .closed
    /// At most one switcher of either kind at a time. Written only by `swipe(_:)`, `windowSwipe(_:)` and `reconcile()`.
    private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }

    private var shown: ShownSwitcher?
    @ObservationIgnored private var windowSwipesBegun = 0
    /// The launches whose bounce plays. Written only by `fire` and `progress(_:of:)`: the one record of which bounces
    /// are live; the adapter's row follows its commands.
    @ObservationIgnored private var bounces: [BundleID: LaunchBounce] = [:]
    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    /// The openings by hand in this process; `window`'s request number.
    @ObservationIgnored private var openings = 0
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let permissions: any Permissions
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let scanner: any AppScanner
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let startAtLogin: StartAtLogin

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore,
        startAtLogin: StartAtLogin
    ) {
        self.startAtLogin = startAtLogin
        self.hardware = hardware
        self.preferences = preferences
        self.permissions = permissions
        self.system = system
        self.catalog = catalog
        self.scanner = scanner
        self.store = store
        installedApps = catalog.installedApps()
        let stored = store.load()
        isFirstLaunch = stored == nil
        settings = stored ?? Settings()
        rows = makeRows()
    }

    /// Gestures on: wires the adapters, scans, reconciles. Asks nothing, opens nothing, saves nothing: all a login
    /// start does, so a first run waits for the first opening by hand. Call once.
    public func start() {
        hardware.onEvent = { [unowned self] event in
            switch event {
            case .gesture(let fired): fire(fired)
            case .swipe(let event): swipe(event)
            case .windowSwipe(let event): windowSwipe(event)
            case .swap(let event): swap(event)
            case .trackpadsChanged: reconcile(restart: true)
            }
        }
        system.onLaunchProgress = { [unowned self] app, progress in self.progress(progress, of: app) }
        scanner.onScan = { [unowned self] in installedApps = $0 }
        scanner.scan()
        preferences.onChange = { [unowned self] in reconcile() }
        permissions.onChange = { [unowned self] in reconcile() }
        reconcile()
        resolveRows()
    }

    /// App picker; nil = None. The same app on two gestures is fine.
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) {
        if let choice {
            guard let entry = entry(for: choice) else { return }
            settings.assignments[gesture] = AssignedApp(entry)
        } else {
            settings.assignments[gesture] = nil
        }
        store.save(settings)
        resolveRows()
    }

    private func entry(for choice: AppChoice) -> AppEntry? {
        switch choice {
        case .app(let entry): entry
        case .appBundle(let url): catalog.entry(at: url)
        }
    }

    /// Hand mode toggle. Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setHandMode(_ mode: HandMode) {
        guard mode != settings.handMode else { return }
        settings.handMode = mode
        store.save(settings)
        reconcile()
    }

    /// Launch animation switch. Saved at once; the next gesture obeys it.
    public func setLaunchAnimation(on: Bool) {
        guard on != settings.isLaunchAnimationOn else { return }
        settings.isLaunchAnimationOn = on
        store.save(settings)
    }

    /// Swipe switch. Saved at once; the recognizers are rebuilt, so the next swipe obeys it and one in progress ends.
    public func setSwipe(on: Bool) {
        guard on != settings.isSwipeOn else { return }
        settings.isSwipeOn = on
        store.save(settings)
        reconcile()
    }

    /// Window swipe switch. Saved at once; the recognizers are rebuilt, so the next slide obeys it and a window swipe in
    /// progress ends.
    public func setWindowSwipe(on: Bool) {
        guard on != settings.isWindowSwipeOn else { return }
        settings.isWindowSwipeOn = on
        store.save(settings)
        reconcile()
    }

    /// Swap switch. Saved at once; the recognizers are rebuilt, so the next thumb tap obeys it.
    public func setSwap(on: Bool) {
        guard on != settings.isSwapOn else { return }
        settings.isSwapOn = on
        store.save(settings)
        reconcile()
    }

    /// The screen recording hint's button while it asks. Records the ask and saves before asking, so a crash in
    /// between never asks twice; a later press opens System Settings instead.
    public func askForScreenRecording() {
        guard screenRecordingHint == .ask else { return }
        settings.hasAskedForScreenRecording = true
        store.save(settings)
        permissions.ask(.screenRecording)
    }

    /// The user opened Trackpad Launcher. The first time in this process, on a first run (no saved settings): start at
    /// login and ask for Accessibility when it is missing, then save; both effects come before the save, so a crash in
    /// between repeats them rather than losing them. On any other run, start at login again if a Quit turned it off.
    /// Every time: the settings window opens or comes to the front, the
    /// rows resolve again and the app list refreshes in the background.
    public func openedByHand() {
        if openings == 0 {
            if isFirstLaunch {
                startAtLogin.enrol()
                if !isAccessibilityGranted { permissions.ask(.accessibility) }
                store.save(settings)
            } else {
                startAtLogin.resume()
            }
        }
        openings += 1
        window = .open(request: openings)
        resolveRows()
        scanner.scan()
    }

    /// Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running.
    public func closeWindow() { window = .closed }

    /// What the trackpads were last run with. A reconcile that would run them the same way leaves them, and any swipe
    /// in progress, alone: preference and trust notifications also fire for writes that change nothing here.
    private struct Run: Equatable {
        let trackpads: [Trackpad]
        let handMode: HandMode
        let blockClicks: Bool
        let slides: Set<SlideKind>
        let swaps: Bool
    }

    @ObservationIgnored private var lastRun: Run?
    @ObservationIgnored private var swapSeries = SwapSeries()

    /// The one convergent operation behind launch, hot-plug, wake, preference, hand-mode and trust changes.
    /// `restart`: run the trackpads even if nothing changed. Hot-plug and wake need it: devices stop delivering frames
    /// across sleep.
    private func reconcile(restart: Bool = false) {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        let granted = permissions.isGranted(.accessibility)
        isAccessibilityGranted = granted
        // Before the run guard: a Screen Recording change never re-runs the trackpads.
        isScreenRecordingGranted = permissions.isGranted(.screenRecording)
        let active = activity.isActive
        // Blocking needs gestures active and access granted; without either, presses are plain clicks. Without access
        // no window can be read, so a slide up or down is what it is with the window swipe setting off.
        let run = Run(
            trackpads: active ? connected : [], handMode: settings.handMode, blockClicks: active && granted,
            slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe]), swaps: settings.isSwapOn)
        guard restart || run != lastRun else { return }
        lastRun = run
        // Running replaces every recognizer, which ends any swipe or window swipe in progress.
        shown = nil
        hardware.run(run.trackpads, handMode: run.handMode, blockClicks: run.blockClicks, slides: run.slides, swaps: run.swaps)
    }

    private enum Visual { case launchBounce, launchAnimation, bringToFrontOnly }

    /// Reads `hasProcess` only when it decides something.
    private func visual(for app: AppEntry) -> Visual {
        guard settings.isLaunchAnimationOn else { return .bringToFrontOnly }
        // The app's bounce still plays: it keeps the one bounce.
        if bounces[app.bundleID] != nil { return .bringToFrontOnly }
        return system.hasProcess(app.bundleID) ? .launchAnimation : .launchBounce
    }

    /// Every silent case decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        switch visual(for: app) {
        case .launchBounce:
            bounces[app.bundleID] = .startingUp
            // Opens the app first, inside the call.
            system.bringToFrontBouncing(app, cap: LaunchBounce.cap)
        case .launchAnimation:
            system.bringToFront(app)
            // After bring to front, so whatever the animation costs lands on the icon, never on the app.
            system.playLaunchAnimation(for: app)
        case .bringToFrontOnly:
            system.bringToFront(app)
        }
    }

    /// A report for an app whose bounce ended finds no record: a late window plays nothing.
    private func progress(_ progress: LaunchProgress, of app: BundleID) {
        guard let bounce = bounces[app] else { return }
        switch bounce.next(after: progress) {
        case .carryOn: break
        case .startUp(let limit):
            bounces[app] = .startedUp
            system.limitLaunchBounce(of: app, to: limit)
        case .end(let ending):
            bounces[app] = nil
            system.endLaunchBounce(of: app, with: ending)
        }
    }

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        switch event.phase {
        case .began:
            guard shown == nil, activity.isActive else { return }
            // With nothing to show the swipe still runs its course: the fingers stay blocked until they lift.
            let running = system.runningApps()
            shown = Switcher(
                frontmost: running.frontmost, running: running.apps,
                leavingOut: settings.assignedBundleIDs, trackpad: event.trackpad
            ).map(ShownSwitcher.apps)
        case .moved(let travel):
            guard case .apps(var open)? = shown, open.trackpad == event.trackpad else { return }
            let crossed = open.selection.follow(travel)
            shown = .apps(open)
            for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
        case .ended:
            guard case .apps(let open)? = shown, open.trackpad == event.trackpad else { return }
            shown = nil
            // Lifting on the frontmost app is silent and leaves the window as it was.
            guard !open.selectsFrontmost else { return }
            // An app that quit meanwhile is never relaunched.
            let running = system.runningApps()
            let target = open.selectedApp
            guard running.contains(target.url) else { return }
            hardware.playFeedback(.gesture, on: event.trackpad)
            system.bringToFront(open.selectedApp)
        case .cancelled:
            if case .apps(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
        }
    }

    /// The one place a window swipe becomes effects. Never the launch animation.
    private func windowSwipe(_ event: SwipeEvent) {
        switch event.phase {
        case .began:
            // A slide up or down is a window swipe only when the one read lists two or more rows. Unconfirmed, the
            // recognizer makes it the slide the setting off would have made, before its next frame.
            guard activity.isActive, let content = WindowSwitcher.Content(system.frontmostWindows()) else { return }
            hardware.confirmWindowSwipe(on: event.trackpad)
            // One switcher at a time: a second trackpad's window swipe runs its course with none, as its swipe would.
            guard shown == nil else { return }
            windowSwipesBegun += 1
            // The grant as the last TCC push left it: a fresh preflight would cost about 4 ms here.
            shown = .windows(
                WindowSwitcher(
                    content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun,
                    trackpad: event.trackpad))
        case .moved(let travel):
            guard case .windows(var open)? = shown, open.trackpad == event.trackpad else { return }
            let crossed = open.selection.follow(travel)
            shown = .windows(open)
            for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
            // Only a visible window comes forward while sliding: raising a minimised one would restore it.
            if crossed > 0, let window = open.selectedVisibleWindow { system.raiseWindows([window]) }
        case .ended:
            guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
            shown = nil
            // The second read: the lift follows the windows as they are now, whatever the raises while sliding did.
            let lift = open.lift(now: system.frontmostWindows())
            if lift.playsHaptic {
                hardware.playFeedback(.gesture, on: event.trackpad)
            }
            system.raiseWindows(lift.raises)
        case .cancelled:
            // The windows stay as they are: no reordering, silent.
            if case .windows(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
        }
    }

    /// The one place a swap becomes effects: never the launch animation, never the switcher.
    private func swap(_ event: SwapEvent) {
        if event.startsSeries { swapSeries = SwapSeries() }
        guard activity.isActive else { return }
        guard let target = swapSeries.next(in: system.runningApps()) else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        system.bringToFront(target)
    }

    /// Rows and the prepared launch animations change together, so the icon of any app that can fire is ready before
    /// its gesture: a first render of an app's icon can take over 100 ms.
    private func resolveRows() {
        rows = makeRows()
        var seen = Set<URL>()
        let present = rows.compactMap { row -> AppEntry? in
            guard case .present(let app) = row.app, seen.insert(app.url).inserted else { return nil }
            return app
        }
        system.prepareLaunchAnimations(for: present)
    }

    private func makeRows() -> [GestureRow] {
        Gesture.allCases.map { gesture in
            let app = settings.assignments[gesture].map { assigned in
                catalog.locate(assigned).map(RowApp.present) ?? .missing(name: assigned.name)
            } ?? .unassigned
            return GestureRow(gesture: gesture, app: app)
        }
    }
}
