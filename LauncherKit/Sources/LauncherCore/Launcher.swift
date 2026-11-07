import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or the launch bounce from a gesture; no gesture closes the window. `fire`
/// shows either only while the launch animation setting is on: the bounce for an app with no process, the animation for
/// one with a process. A launch with no process is watched while either setting needs it (the bounce shows, or the hide
/// background apps setting waits for the app's window); the progress handler hides the others after its first window.
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
    public var thumbCorner: ThumbCorner { settings.thumbCorner }
    public var isLaunchAnimationOn: Bool { settings.isLaunchAnimationOn }
    public var isSwipeOn: Bool { settings.isSwipeOn }
    public var isSwapOn: Bool { settings.isSwapOn }
    public var isHideBackgroundAppsOn: Bool { settings.isHideBackgroundAppsOn }
    public var isWindowSwipeOn: Bool { settings.isWindowSwipeOn }
    /// One derivation, read by the notice and the fire guard.
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)))
    }

    /// The sentence the settings window shows while gestures are inactive; nil while they are active.
    public var inactiveNotice: String? {
        guard case .inactive(let cause) = activity else { return nil }
        return Copy.inactiveNotice(for: cause)
    }

    /// The Accessibility hint shows while the permission is missing.
    public var showsAccessibilityHint: Bool { !isAccessibilityGranted }

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
    /// The launches being watched, one record per launched bundle. Written only by `fire` and `progress(_:of:)`: the one
    /// record of which launches are live; the adapter's watches and bounces follow its commands.
    @ObservationIgnored private var launches: [BundleID: WatchedLaunch] = [:]
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
            case .contactChanged: reportUse()
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

    /// App picker; nil = None. The same app on two gestures is fine. Answers the gesture's app when its row now shows
    /// it present, so the picker knows whether to play the pick animation: nil for None, for a bundle that is no app,
    /// and for an app the catalog cannot locate, whose row shows "not found".
    @discardableResult
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) -> AppEntry? {
        if let choice {
            guard let entry = entry(for: choice) else { return nil }
            settings.assignments[gesture] = AssignedApp(entry)
        } else {
            settings.assignments[gesture] = nil
        }
        store.save(settings)
        resolveRows()
        if case .present(let entry) = rows.first(where: { $0.gesture == gesture })?.app { return entry }
        return nil
    }

    private func entry(for choice: AppChoice) -> AppEntry? {
        switch choice {
        case .app(let entry): entry
        case .appBundle(let url): catalog.entry(at: url)
        }
    }

    /// Thumb corner change. Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setThumbCorner(_ corner: ThumbCorner) {
        guard corner != settings.thumbCorner else { return }
        settings.thumbCorner = corner
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

    /// Hide background apps switch. Saved at once; it hides and shows nothing now and applies to the next action.
    public func setHideBackgroundApps(on: Bool) {
        guard on != settings.isHideBackgroundAppsOn else { return }
        settings.isHideBackgroundAppsOn = on
        store.save(settings)
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
        let wasClosed = window == .closed
        window = .open(request: openings)
        if wasClosed { reportUse() }
        resolveRows()
        scanner.scan()
    }

    /// Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running.
    public func closeWindow() {
        guard window != .closed else { return }
        window = .closed
        reportUse()
    }

    /// A finger on any trackpad, or the settings window open, minimised or hidden included.
    public var isInUse: Bool { window != .closed || hardware.isTouched }

    @ObservationIgnored private var useWatcher: (@MainActor (Bool) -> Void)?

    /// While set: `onChange` now with the present reading, then at each change and after each `run`. nil stops it, and
    /// contact sensing with it. `Launcher` does not know why it is asked.
    public func watchUse(_ onChange: (@MainActor (Bool) -> Void)?) {
        useWatcher = onChange
        // Sensing first, then the reading: a lift landing as it turns on is neither lost nor stuck.
        hardware.sensesContact = onChange != nil
        reportUse()
    }

    private func reportUse() { useWatcher?(isInUse) }

    /// What the trackpads were last run with. A reconcile that would run them the same way leaves them, and any swipe
    /// in progress, alone: preference and trust notifications also fire for writes that change nothing here.
    private struct Run: Equatable {
        let trackpads: [Trackpad]
        let corner: ThumbCorner
        let blockClicks: Bool
        let blockTapClicks: Bool
        let slides: Set<SlideKind>
        let swaps: Bool
    }

    @ObservationIgnored private var lastRun: Run?
    @ObservationIgnored private var swapSeries = SwapSeries()

    /// The one convergent operation behind launch, hot-plug, wake, preference, thumb corner and trust changes.
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
        let blockClicks = active && granted
        let tapToClickIsOn = TapBoundSetting.on(connected: Set(connected.map(\.kind)), values: preferenceValues)
            .contains(.tapToClick)
        let run = Run(
            trackpads: active ? connected : [], corner: settings.thumbCorner, blockClicks: blockClicks,
            blockTapClicks: blockClicks && tapToClickIsOn,
            slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe]), swaps: settings.isSwapOn)
        guard restart || run != lastRun else { return }
        lastRun = run
        // Running replaces every recognizer, which ends any swipe or window swipe in progress.
        shown = nil
        hardware.run(run.trackpads, corner: run.corner, blockClicks: run.blockClicks,
            blockTapClicks: run.blockTapClicks, slides: run.slides, swaps: run.swaps)
        // `run` replaces sessions, so an in-flight lift can vanish: re-reading the level cannot stick.
        reportUse()
    }

    private func hideOtherApps(than app: BundleID) {
        guard settings.isHideBackgroundAppsOn else { return }
        system.hideOtherApps(than: app)
    }

    /// Every silent case decided here and only here: inactive, unassigned, missing. Reads `hasProcess` only when it
    /// decides something: the launch animation or the hide setting is on, and no launch of the app is watched.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        let animates = settings.isLaunchAnimationOn
        let hides = settings.isHideBackgroundAppsOn
        let id = app.bundleID
        // A watched launch keeps its one watch, bouncing or unseen; only its hide follows the latest gesture.
        if launches[id] != nil {
            launches[id]?.hidesOthersOnWindow = hides
            system.bringToFront(app)
            return
        }
        guard animates || hides else { return system.bringToFront(app) }
        guard system.hasProcess(id) else {
            launches[id] = WatchedLaunch(stage: .startingUp, hidesOthersOnWindow: hides)
            // Opens the app first, inside the call.
            system.bringToFrontWatching(app, cap: WatchedLaunch.cap, bouncing: animates)
            return
        }
        system.bringToFront(app)
        if animates {
            // After bring to front, so whatever the animation costs lands on the icon, never on the app.
            system.playLaunchAnimation(for: app)
        }
        hideOtherApps(than: id)
    }

    /// A report for an app whose launch ended finds no record: a late window plays and hides nothing.
    private func progress(_ progress: LaunchProgress, of app: BundleID) {
        guard let launch = launches[app] else { return }
        switch launch.stage.next(after: progress) {
        case .carryOn: break
        case .startUp(let limit):
            launches[app]?.stage = .startedUp
            system.limitLaunch(of: app, to: limit)
        case .end(let ending):
            launches[app] = nil
            system.endLaunch(of: app, with: ending)
            // After the end, so a bounce's launch animation starts first. The record decides, not the switch now.
            if progress == .windowShown, launch.hidesOthersOnWindow,
               system.runningApps().frontmost?.bundleID == app {
                system.hideOtherApps(than: app)
            }
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
            hideOtherApps(than: target.bundleID)
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
            if lift.playsHaptic { hideOtherApps(than: open.app.bundleID) }
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
        hideOtherApps(than: target.bundleID)
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
