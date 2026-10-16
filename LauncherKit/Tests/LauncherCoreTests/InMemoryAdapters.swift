import Foundation
import LauncherCore

/// Real recognizer, real click filter, scripted frames, synchronous main-actor delivery.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []
    /// Every haptic pulse, in order.
    private(set) var pulses: [Pulse] = []
    /// The fake click tap: armed iff the last `run` asked for it with trackpads.
    private var clickFilter: ClickFilter?
    var isBlockingClicks: Bool { clickFilter != nil }
    /// Armed and disarmed with `clickFilter`: one tap decides both.
    private var scrollFilter: ScrollFilter?
    /// What the fake tap did with each scripted press and release, in order.
    private(set) var pressVerdicts: [PointerVerdict] = []
    /// Each running trackpad's latest `Recognition.blocksClicks`.
    private var blocking: [TrackpadID: Bool] = [:]
    private var buttonWasDown = false
    private var pressInProgress: PressID?
    private var nextPressNumber: Int64 = 1

    struct Pulse: Equatable {
        let haptic: Haptic
        let trackpad: TrackpadID
    }

    /// The trackpads that pulsed the gesture haptic, in order.
    var feedback: [TrackpadID] { pulses.filter { $0.haptic == .gesture }.map(\.trackpad) }
    /// The trackpads that pulsed the light tick, in order.
    var lightTicks: [TrackpadID] { pulses.filter { $0.haptic == .lightTick }.map(\.trackpad) }

    init(attached: [Trackpad] = [.macBook14]) {
        self.attached = attached
    }

    func connected() -> [Trackpad] { attached }

    /// How many times `run` was called.
    private(set) var runCount = 0

    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, slides: Set<SlideKind>, swaps: Bool) {
        runCount += 1
        running = Dictionary(
            uniqueKeysWithValues: trackpads.map {
                ($0.id, GestureRecognizer(handMode: handMode, surface: $0.surface, slides: slides, swaps: swaps, travel: .linear))
            })
        deaf = []
        blocking = [:]
        buttonWasDown = false
        pressInProgress = nil
        clickFilter = blockClicks && !trackpads.isEmpty ? ClickFilter() : nil
        scrollFilter = clickFilter == nil ? nil : ScrollFilter()
    }

    func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID) { pulses.append(Pulse(haptic: haptic, trackpad: trackpad)) }

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
            if let event = recognition.event {
                onEvent?(TrackpadEvent(event, on: id))
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

    /// A scroll event reaching the fake tap on the flags the frames so far left, merged across trackpads.
    /// nil when no tap is armed, so the event reaches apps untouched.
    func scroll(_ event: ScrollEvent) -> ScrollVerdict? {
        scrollFilter?.decide(event, trackpadBlocking: blocking.values.contains(true))
    }

    /// An event the frame thread recognised just before activity flipped, delivered regardless of `running`.
    func inject(_ event: TrackpadEvent) { onEvent?(event) }
}

@MainActor final class InMemoryTrackpadPreferences: TrackpadPreferences {
    var onChange: (@MainActor () -> Void)?
    private var values: [TrackpadKind: TrackpadPreferenceValues] = [:]

    func current() -> [TrackpadKind: TrackpadPreferenceValues] { values }

    /// A notification for a write that changed nothing this app reads.
    func touch() { onChange?() }

    func set(_ setting: ConflictingSetting, rawValue: Int?, for kind: TrackpadKind) {
        values[kind, default: [:]][setting] = rawValue
        onChange?()
    }
}

@MainActor final class RecordingSystemActions: SystemActions {
    private(set) var broughtToFront: [AppEntry] = []
    private(set) var loginItemRegistrations = 0
    /// One entry per play, in order.
    private(set) var launchAnimations: [AppEntry] = []
    /// The latest set prepared; each prepare replaces the one before.
    private(set) var preparedLaunchAnimations: [AppEntry] = []
    /// The active app the next `runningApps()` answers; nil models no active app, or Trackpad Launcher itself.
    var frontmost: AppEntry?
    /// The ⌘-Tab apps the next `runningApps()` answers, most recently activated first.
    var running: [AppEntry] = []
    /// Runs inside `registerLoginItem()` so a test can observe what is stored at that moment.
    var onRegisterLoginItem: (() -> Void)?
    /// Runs inside `playLaunchAnimation(for:)` so a test can observe the other effects at that moment.
    var onPlayLaunchAnimation: (() -> Void)?

    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }

    func runningApps() -> RunningApps { RunningApps(frontmost: frontmost, apps: running) }

    /// The frontmost app's windows the next `frontmostWindows()` answers.
    let windows = FakeWindows()

    func frontmostWindows() -> FrontmostWindows { windows.read(frontmost: frontmost) }

    func registerLoginItem() {
        loginItemRegistrations += 1
        onRegisterLoginItem?()
    }

    func prepareLaunchAnimations(for apps: [AppEntry]) { preparedLaunchAnimations = apps }

    func playLaunchAnimation(for app: AppEntry) {
        launchAnimations.append(app)
        onPlayLaunchAnimation?()
    }
}

/// The frontmost app's window stack, by name: one fixed `WindowID` per name for the life of the test. A window's title is
/// its name unless the name is marked untitled. Answers reads only and carries no policy: full-screen and minimised
/// windows are reported as they are, uncut.
@MainActor final class FakeWindows {
    /// Front to back.
    private(set) var onScreenTitles: [String] = []
    /// In the order the app lists them.
    private(set) var minimisedTitles: [String] = []
    private var fullScreenFront = false
    private var untitled: Set<String> = []
    /// false: the app does not answer in time, so reads list nothing.
    var answers = true
    /// How many times the windows were read.
    private(set) var reads = 0
    private var ids: [String: WindowID] = [:]

    /// `untitled`: names whose windows report an empty title.
    func set(visible: [String], minimised: [String] = [], fullScreenFront: Bool = false, untitled: Set<String> = []) {
        onScreenTitles = visible
        minimisedTitles = minimised
        self.fullScreenFront = fullScreenFront
        self.untitled = untitled
    }

    /// A new visible window, in front.
    func open(_ title: String) { onScreenTitles.insert(title, at: 0) }

    func close(_ title: String) {
        onScreenTitles.removeAll { $0 == title }
        minimisedTitles.removeAll { $0 == title }
    }

    func id(_ title: String) -> WindowID {
        if let id = ids[title] { return id }
        let id = WindowID(rawValue: UInt32(1000 + ids.count))
        ids[title] = id
        return id
    }

    func read(frontmost: AppEntry?) -> FrontmostWindows {
        reads += 1
        guard let frontmost else { return .noApp }
        guard answers else { return .app(frontmost, visible: [], minimised: []) }
        let visible = onScreenTitles.enumerated().map { index, title in
            AppWindow(id: id(title), title: self.title(of: title), isFullScreen: index == 0 && fullScreenFront)
        }
        let minimised = minimisedTitles.map { AppWindow(id: id($0), title: title(of: $0)) }
        return .app(frontmost, visible: visible, minimised: minimised)
    }

    private func title(of name: String) -> String { untitled.contains(name) ? "" : name
    }
}

@MainActor final class InMemoryPermissions: Permissions {
    var onChange: (@MainActor () -> Void)?
    private(set) var granted: Set<Permission>
    /// Every `ask(_:)`, in order.
    private(set) var asks: [Permission] = []
    /// Runs inside `ask(_:)` so a test can observe what is stored at that moment.
    var onAsk: (() -> Void)?

    init(granted: Set<Permission> = []) { self.granted = granted }

    func isGranted(_ permission: Permission) -> Bool { granted.contains(permission) }

    func ask(_ permission: Permission) {
        asks.append(permission)
        onAsk?()
    }

    /// The user flips the switch in System Settings. Pushed synchronously on a real change only, as the real adapter
    /// does; `push: false` changes it silently, as when the system withholds its broadcast.
    func set(_ permission: Permission, granted: Bool, push: Bool = true) {
        guard granted != self.granted.contains(permission) else { return }
        if granted { self.granted.insert(permission) } else { self.granted.remove(permission) }
        if push { onChange?() }
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
