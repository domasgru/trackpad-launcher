import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or closes the window from a gesture. `fire` plays the launch
/// animation only while its setting is on.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    /// Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`.
    public private(set) var switcher: Switcher?
    /// Every app picker's list. Replaced only by a scan; never emptied while one runs.
    public private(set) var installedApps: InstalledApps
    public var isWindowOpen: Bool { window != .closed }
    public var handMode: HandMode { settings.handMode }
    public var isLaunchAnimationOn: Bool { settings.isLaunchAnimationOn }
    public var isSwipeOn: Bool { settings.isSwipeOn }
    public var isSwapOn: Bool { settings.isSwapOn }
    /// The window's hint, which mentions swiping only while the swipe is on.
    public var gestureHint: String { Copy.gestureHint(for: settings.handMode, swipe: settings.isSwipeOn) }
    /// One derivation, read by the icon, the notice and the fire guard.
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }

    /// Drives the Accessibility hint. Deliberately not part of `activity`, so the icon never reads it.
    public private(set) var isAccessibilityGranted = false

    /// `.heldOpen` is the first-launch window under the system's Accessibility prompt. The prompt takes focus when it
    /// appears and its buttons are outside clicks; both would close an ordinary window before the user saw the hint.
    /// A held window closes only on an explicit close, a fired gesture, or a grant.
    private enum Window: Equatable { case closed, open, heldOpen }

    private var window: Window = .closed
    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let access: any AccessibilityPermission
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let scanner: any AppScanner
    @ObservationIgnored private let store: SettingsStore

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, access: any AccessibilityPermission,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore
    ) {
        self.hardware = hardware
        self.preferences = preferences
        self.access = access
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
            case .swap(let event): swap(event)
            case .trackpadsChanged: reconcile(restart: true)
            }
        }
        scanner.onScan = { [unowned self] in installedApps = $0 }
        scanner.scan()
        preferences.onChange = { [unowned self] in reconcile() }
        access.onChange = { [unowned self] in reconcile() }
        reconcile()
        if isFirstLaunch {
            // Both effects come before the first save: a crash in between repeats them next time instead of
            // losing them.
            system.registerLoginItem()
            let prompting = !isAccessibilityGranted
            if prompting { access.prompt() }
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

    /// Swap switch. Saved at once; the recognizers are rebuilt, so the next thumb tap obeys it.
    public func setSwap(on: Bool) {
        guard on != settings.isSwapOn else { return }
        settings.isSwapOn = on
        store.save(settings)
        reconcile()
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
        let swipes: Bool
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
        let granted = access.isGranted()
        // A grant ends the hold: the hint has done its job and the user is in System Settings.
        if granted && !isAccessibilityGranted && window == .heldOpen { window = .closed }
        isAccessibilityGranted = granted
        let active = activity.isActive
        // Blocking needs gestures active and access granted; without either, presses are plain clicks.
        let run = Run(
            trackpads: active ? connected : [], handMode: settings.handMode, blockClicks: active && granted,
            swipes: settings.isSwipeOn, swaps: settings.isSwapOn)
        guard restart || run != lastRun else { return }
        lastRun = run
        // Running replaces every recognizer, which ends any swipe in progress.
        switcher = nil
        hardware.run(run.trackpads, handMode: run.handMode, blockClicks: run.blockClicks, swipes: run.swipes, swaps: run.swaps)
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
            guard switcher == nil, activity.isActive else { return }
            // With nothing to show the swipe still runs its course: the fingers stay blocked until they lift.
            let running = system.runningApps()
            switcher = Switcher(
                frontmost: running.frontmost, running: running.apps,
                leavingOut: Set(settings.assignments.values.map(\.bundleID)), trackpad: event.trackpad)
        case .moved(let travel):
            guard var open = switcher, open.trackpad == event.trackpad else { return }
            let before = open.selected
            open.follow(travel)
            switcher = open
            for _ in 0..<abs(open.selected - before) { hardware.playFeedback(.lightTick, on: event.trackpad) }
        case .ended:
            guard let open = switcher, open.trackpad == event.trackpad else { return }
            switcher = nil
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
            if switcher?.trackpad == event.trackpad { switcher = nil }
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
