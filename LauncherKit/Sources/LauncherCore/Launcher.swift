import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or closes the window from a gesture.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
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
    @ObservationIgnored private let store: SettingsStore

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, access: any AccessibilityPermission,
        system: any SystemActions, catalog: AppCatalog, store: SettingsStore
    ) {
        self.hardware = hardware
        self.preferences = preferences
        self.access = access
        self.system = system
        self.catalog = catalog
        self.store = store
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
            case .trackpadsChanged: reconcile()
            }
        }
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

    /// App picker. The same app on two gestures is fine.
    public func setAssignment(_ choice: AppChoice, for gesture: Gesture) {
        switch choice {
        case .app(let entry):
            settings.assignments[gesture] = AssignedApp(entry)
        case .appBundle(let url):
            guard let entry = catalog.entry(at: url) else { return }
            settings.assignments[gesture] = AssignedApp(entry)
        case .unassigned:
            settings.assignments[gesture] = nil
        }
        store.save(settings)
        resolveRows()
    }

    /// Hand mode toggle. Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setHandMode(_ mode: HandMode) {
        guard mode != settings.handMode else { return }
        settings.handMode = mode
        store.save(settings)
        reconcile()
    }

    /// Show the launcher window and re-resolve the rows.
    public func openWindow() {
        if window == .closed { window = .open }
        resolveRows()
    }

    /// Icon click, Escape, the window's own System Settings buttons: always closes.
    public func closeWindow() { window = .closed }

    /// An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt.
    public func dismissWindow() { if window == .open { window = .closed } }

    /// The one convergent operation behind launch, hot-plug, wake, preference, hand-mode and trust changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        let granted = access.isGranted()
        // A grant ends the hold: the hint has done its job and the user is in System Settings.
        if granted && !isAccessibilityGranted && window == .heldOpen { window = .closed }
        isAccessibilityGranted = granted
        let active = activity.isActive
        // Blocking needs gestures active and access granted; without either, presses are plain clicks.
        hardware.run(active ? connected : [], handMode: settings.handMode, blockClicks: active && granted)
    }

    /// Every silent case decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(on: event.trackpad)
        system.bringToFront(app)
        // After bring to front, so whatever the animation costs lands on the icon, never on the app.
        system.playLaunchAnimation(for: app)
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
