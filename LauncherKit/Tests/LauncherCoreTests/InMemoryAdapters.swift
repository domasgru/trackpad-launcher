import LauncherCore

/// Real recognizer, real click filter, scripted frames, synchronous main-actor delivery.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []
    private(set) var feedback: [TrackpadID] = []
    /// The fake click tap: armed iff the last `run` asked for it with trackpads.
    private var clickFilter: ClickFilter?
    var isBlockingClicks: Bool { clickFilter != nil }
    /// What the fake tap did with each scripted press and release, in order.
    private(set) var pressVerdicts: [PointerVerdict] = []
    /// Each running trackpad's latest `Recognition.blocksClicks`.
    private var blocking: [TrackpadID: Bool] = [:]
    private var buttonWasDown = false
    private var pressInProgress: PressID?
    private var nextPressNumber: Int64 = 1

    init(attached: [Trackpad] = [.macBook14]) {
        self.attached = attached
    }

    func connected() -> [Trackpad] { attached }

    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool) {
        running = Dictionary(
            uniqueKeysWithValues: trackpads.map {
                ($0.id, GestureRecognizer(handMode: handMode, surface: $0.surface))
            })
        deaf = []
        blocking = [:]
        buttonWasDown = false
        pressInProgress = nil
        clickFilter = blockClicks && !trackpads.isEmpty ? ClickFilter() : nil
    }

    func playFeedback(on trackpad: TrackpadID) { feedback.append(trackpad) }

    func attach(_ trackpad: Trackpad) {
        attached.append(trackpad)
        onEvent?(.trackpadsChanged)
    }

    func detach(_ id: TrackpadID) {
        attached.removeAll { $0.id == id }
        onEvent?(.trackpadsChanged)
    }

    /// After sleep the real devices deliver nothing until `run` restarts them; so does this fake.
    func sleep() { deaf = Set(running.keys) }

    func wake() { onEvent?(.trackpadsChanged) }

    /// Scripted frames carry the physical press as any non-nil `press`. Per frame, as on hardware: a press edge
    /// reaches the tap between frames, so it is decided on the flags the previous frame left, merged across
    /// trackpads; then the frame's press is re-sampled through the filter's `holding`, as the frame callback does.
    /// Frames on a trackpad that is not running, or deaf since `sleep()`, are dropped like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) {
        for frame in frames {
            guard !deaf.contains(id), running[id] != nil else { return }
            let buttonDown = frame.press != nil
            deliverPressEdge(buttonDown: buttonDown)
            let sampled = TouchFrame(
                time: frame.time, touches: frame.touches,
                press: TouchFrame.Press(holding: clickFilter?.holding, buttonDown: buttonDown))
            guard let recognition = running[id]?.step(sampled) else { return }
            blocking[id] = recognition.blocksClicks
            if let gesture = recognition.fired {
                onEvent?(.gesture(GestureEvent(gesture: gesture, trackpad: id)))
            }
        }
    }

    private func deliverPressEdge(buttonDown: Bool) {
        defer { buttonWasDown = buttonDown }
        guard clickFilter != nil, buttonDown != buttonWasDown else { return }
        if buttonDown {
            let press = PressID(button: 0, number: nextPressNumber)
            nextPressNumber += 1
            pressInProgress = press
            let verdict = clickFilter!.decide(.press(press), trackpadBlocking: blocking.values.contains(true))
            pressVerdicts.append(verdict)
        } else if let press = pressInProgress {
            pressInProgress = nil
            let verdict = clickFilter!.decide(.release(press), trackpadBlocking: blocking.values.contains(true))
            pressVerdicts.append(verdict)
        }
    }

    /// A gesture the frame thread recognised just before activity flipped, delivered regardless of `running`.
    func inject(_ event: GestureEvent) { onEvent?(.gesture(event)) }
}

@MainActor final class InMemoryTrackpadPreferences: TrackpadPreferences {
    var onChange: (@MainActor () -> Void)?
    private var values: [TrackpadKind: TrackpadPreferenceValues] = [:]

    func current() -> [TrackpadKind: TrackpadPreferenceValues] { values }

    func set(_ setting: ConflictingSetting, rawValue: Int?, for kind: TrackpadKind) {
        values[kind, default: [:]][setting] = rawValue
        onChange?()
    }
}

@MainActor final class RecordingSystemActions: SystemActions {
    private(set) var broughtToFront: [AppEntry] = []
    private(set) var loginItemRegistrations = 0
    /// Runs inside `registerLoginItem()` so a test can observe what is stored at that moment.
    var onRegisterLoginItem: (() -> Void)?

    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }

    func registerLoginItem() {
        loginItemRegistrations += 1
        onRegisterLoginItem?()
    }
}

@MainActor final class InMemoryAccessibilityPermission: AccessibilityPermission {
    var onChange: (@MainActor () -> Void)?
    private(set) var granted: Bool
    private(set) var prompts = 0
    /// Runs inside `prompt()` so a test can observe what is stored at that moment.
    var onPrompt: (() -> Void)?

    init(granted: Bool = false) { self.granted = granted }

    func isGranted() -> Bool { granted }

    func prompt() {
        prompts += 1
        onPrompt?()
    }

    /// The user flips the switch in System Settings. Pushed synchronously on a real change only, as the real adapter does.
    func set(granted: Bool) {
        guard granted != self.granted else { return }
        self.granted = granted
        onChange?()
    }
}

/// Runs the real `catalog.installedApps()` synchronously. `foldersChanged()` stands in for the FSEvents push.
@MainActor final class InMemoryAppScanner: AppScanner {
    var onScan: (@MainActor (InstalledApps) -> Void)?
    private(set) var scanRequests = 0
    private let catalog: AppCatalog
    private var holding = false
    private var held = false

    init(catalog: AppCatalog) {
        self.catalog = catalog
    }

    func scan() {
        scanRequests += 1
        deliver()
    }

    func foldersChanged() { deliver() }

    /// Defers deliveries until `deliverHeldScan()`.
    func holdScans() { holding = true }

    func deliverHeldScan() {
        holding = false
        guard held else { return }
        held = false
        deliver()
    }

    private func deliver() {
        if holding {
            held = true
        } else {
            onScan?(catalog.installedApps())
        }
    }
}
