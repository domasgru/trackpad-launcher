import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches or closes the window from a gesture.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    public private(set) var isWindowOpen = false
    public var handMode: HandMode { settings.handMode }
    /// One derivation, read by the icon, the notice and the fire guard.
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }

    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let store: SettingsStore

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, system: any SystemActions,
        catalog: AppCatalog, store: SettingsStore
    ) {
        self.hardware = hardware
        self.preferences = preferences
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
        reconcile()
        guard isFirstLaunch else { return }
        // Before the first save: a crash in between registers again next time instead of losing the item.
        system.registerLoginItem()
        store.save(settings)
        openWindow()
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
        rows = makeRows()
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
        isWindowOpen = true
        rows = makeRows()
    }

    public func closeWindow() { isWindowOpen = false }

    /// The one convergent operation behind launch, hot-plug, wake, preference and hand-mode changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        hardware.run(activity.isActive ? connected : [], handMode: settings.handMode)
    }

    /// Every silent case decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(on: event.trackpad)
        system.bringToFront(app)
        isWindowOpen = false
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
