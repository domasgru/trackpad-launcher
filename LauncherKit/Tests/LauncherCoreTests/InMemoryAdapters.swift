import LauncherCore

/// Real recognizer, scripted frames, synchronous main-actor delivery.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []
    private(set) var feedback: [TrackpadID] = []

    init(attached: [Trackpad] = [.macBook14]) {
        self.attached = attached
    }

    func connected() -> [Trackpad] { attached }

    func run(_ trackpads: [Trackpad], handMode: HandMode) {
        running = Dictionary(
            uniqueKeysWithValues: trackpads.map {
                ($0.id, GestureRecognizer(handMode: handMode, surface: $0.surface))
            })
        deaf = []
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

    /// Frames on a trackpad that is not running, or deaf since `sleep()`, are dropped like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) {
        for frame in frames {
            guard !deaf.contains(id), running[id] != nil else { return }
            if let gesture = running[id]?.step(frame) {
                onEvent?(.gesture(GestureEvent(gesture: gesture, trackpad: id)))
            }
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
