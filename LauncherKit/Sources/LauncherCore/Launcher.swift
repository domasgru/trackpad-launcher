import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or closes the window from a gesture. `fire` plays the launch
/// animation only while its setting is on.
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
    /// The window's hint, which mentions swiping only while the swipe is on.
    public var gestureHint: String { Copy.gestureHint(for: settings.handMode, swipe: settings.isSwipeOn) }
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

    /// `.heldOpen` is the first-launch window under the system's Accessibility prompt. The prompt takes focus when it
    /// appears and its buttons are outside clicks; both would close an ordinary window before the user saw the hint.
    /// A held window closes only on an explicit close, a fired gesture, or a grant.
    private enum Window: Equatable { case closed, open, heldOpen }

    private var window: Window = .closed
    /// At most one switcher of either kind at a time. Written only by `swipe(_:)`, `windowSwipe(_:)` and `reconcile()`.
    private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }

    private var shown: ShownSwitcher?
    @ObservationIgnored private var windowSwipesBegun = 0
    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let permissions: any Permissions
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let scanner: any AppScanner
    @ObservationIgnored private let store: SettingsStore

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore
    ) {
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

    /// Launch. Call once, after the status item exists.
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
        scanner.onScan = { [unowned self] in installedApps = $0 }
        scanner.scan()
        preferences.onChange = { [unowned self] in reconcile() }
        permissions.onChange = { [unowned self] in reconcile() }
        reconcile()
        if isFirstLaunch {
            // Both effects come before the first save: a crash in between repeats them next time instead of
            // losing them.
            system.registerLoginItem()
            let prompting = !isAccessibilityGranted
            if prompting { permissions.ask(.accessibility) }
            store.save(settings)
            window = prompting ? .heldOpen : .open
        }
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

    /// Show the launcher window, re-resolve the rows and refresh the app list in the background.
    public func openWindow() {
        if window == .closed { window = .open }
        resolveRows()
        scanner.scan()
    }

    /// Icon click, Escape, the window's own System Settings buttons: always closes.
    public func closeWindow() { window = .closed }

    /// An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt.
    public func dismissWindow() { if window == .open { window = .closed } }

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
        // A grant ends the hold: the hint has done its job and the user is in System Settings.
        if granted && !isAccessibilityGranted && window == .heldOpen { window = .closed }
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

    /// Every silent case decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        system.bringToFront(app)
        // After bring to front, so whatever the animation costs lands on the icon, never on the app.
        if settings.isLaunchAnimationOn { system.playLaunchAnimation(for: app) }
        window = .closed
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
            window = .closed
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
                window = .closed
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
        window = .closed
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
