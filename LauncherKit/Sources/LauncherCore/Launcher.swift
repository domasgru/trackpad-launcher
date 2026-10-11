import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or closes the window from a gesture.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    /// The switcher list as the window shows it, in switcher order. Resolved with `rows`.
    public private(set) var switcherRows: [SwitcherRow] = []
    /// Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`.
    public private(set) var switcher: Switcher?
    /// Every app picker's list. Replaced only by a scan; never emptied while one runs.
    public private(set) var installedApps: InstalledApps
    public var isWindowOpen: Bool { window != .closed }
    public var handMode: HandMode { settings.handMode }
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
        switcherRows = makeSwitcherRows()
    }

    /// Launch. Call once, after the status item exists.
    public func start() {
        hardware.onEvent = { [unowned self] event in
            switch event {
            case .gesture(let fired): fire(fired)
            case .swipe(let event): swipe(event)
            case .trackpadsChanged: reconcile()
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

    /// Add app… and its Other…: appends; an app already listed stays where it is. The list is the only thing it edits.
    public func addToSwitcher(_ choice: AppChoice) {
        guard let entry = entry(for: choice) else { return }
        editSwitcherList { $0.append(AssignedApp(entry)) }
    }

    public func removeFromSwitcher(_ app: BundleID) { editSwitcherList { $0.remove(app) } }

    /// Drag to reorder: `index` is where the row lands, clamped into the list.
    public func moveInSwitcher(_ app: BundleID, to index: Int) { editSwitcherList { $0.move(app, to: index) } }

    private func editSwitcherList(_ edit: (inout SwitcherList) -> Void) {
        var list = settings.switcherList
        edit(&list)
        guard list != settings.switcherList else { return }
        let emptinessFlipped = list.isEmpty != settings.switcherList.isEmpty
        settings.switcherList = list
        store.save(settings)
        resolveRows()
        // Swipes are recognised only while the list holds an app; the recognizers learn that only through a run.
        if emptinessFlipped { reconcile() }
    }

    /// Hand mode toggle. Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setHandMode(_ mode: HandMode) {
        guard mode != settings.handMode else { return }
        settings.handMode = mode
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

    /// The one convergent operation behind launch, hot-plug, wake, preference, hand-mode and trust changes.
    private func reconcile() {
        // Running replaces every recognizer, which ends any swipe in progress.
        switcher = nil
        connected = hardware.connected()
        preferenceValues = preferences.current()
        let granted = access.isGranted()
        // A grant ends the hold: the hint has done its job and the user is in System Settings.
        if granted && !isAccessibilityGranted && window == .heldOpen { window = .closed }
        isAccessibilityGranted = granted
        let active = activity.isActive
        // Blocking needs gestures active and access granted; without either, presses are plain clicks.
        hardware.run(active ? connected : [], handMode: settings.handMode, blockClicks: active && granted,
            swipes: !settings.switcherList.isEmpty)
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
        system.playLaunchAnimation(for: app)
        window = .closed
    }

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        switch event.phase {
        case .began:
            guard switcher == nil, activity.isActive else { return }
            let frontmost = system.frontmostApp().flatMap(catalog.entry(at:))
            let listed = settings.switcherList.apps.compactMap(catalog.locate)
            switcher = frontmost.flatMap { Switcher(listed: listed, frontmost: $0, trackpad: event.trackpad) }
            // Nothing to show: the frame thread cannot know, so main ends the swipe by replacing the recognizers.
            // Otherwise the fingers would stay blocked until they lift.
            if switcher == nil { reconcile() }
        case .moved(let travel):
            guard var open = switcher, open.trackpad == event.trackpad else { return }
            let before = open.selected
            open.travelMM = travel
            switcher = open
            for _ in 0..<abs(open.selected - before) { hardware.playFeedback(.lightTick, on: event.trackpad) }
        case .ended:
            guard let open = switcher, open.trackpad == event.trackpad else { return }
            switcher = nil
            // Lifting on the frontmost app is silent and leaves the window as it was.
            guard !open.selectsFrontmost else { return }
            hardware.playFeedback(.gesture, on: event.trackpad)
            system.bringToFront(open.selectedApp)
            window = .closed
        case .cancelled:
            if switcher?.trackpad == event.trackpad { switcher = nil }
        }
    }

    /// Rows and the prepared launch animations change together, so the icon of any app that can fire is ready before
    /// its gesture: a first render of an app's icon can take over 100 ms.
    private func resolveRows() {
        rows = makeRows()
        switcherRows = makeSwitcherRows()
        var seen = Set<URL>()
        let present = rows.compactMap { row -> AppEntry? in
            guard case .present(let app) = row.app, seen.insert(app.url).inserted else { return nil }
            return app
        }
        system.prepareLaunchAnimations(for: present)
    }

    private func makeSwitcherRows() -> [SwitcherRow] {
        settings.switcherList.apps.map { SwitcherRow(assigned: $0, present: catalog.locate($0)) }
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
