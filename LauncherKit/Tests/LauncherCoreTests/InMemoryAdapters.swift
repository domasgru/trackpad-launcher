import Foundation
import LauncherCore

/// Real recognizer, real `TapFilters`, scripted frames, synchronous main-actor delivery. Models the window server's side
/// of the tap's two ports; every gate, routing and notice rule is the real `TapFilters`'.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []
    /// Every haptic pulse, in order.
    private(set) var pulses: [Pulse] = []
    /// The fake tap: armed iff the last `run` asked for click blocking with trackpads.
    private var tap: TapFilters?
    var isBlockingClicks: Bool { tap != nil }
    /// What the fake tap did with each scripted press and release, in order.
    private(set) var pressVerdicts: [PointerVerdict] = []
    /// Whether the gated port is on (false with no tap).
    private(set) var isGatedPortOn = false
    private var isPressPortOn = false
    /// Each running trackpad's latest `Recognition.blocking`.
    private var levels: [TrackpadID: Blocking] = [:]
    /// Whether the system's current fingers scroll has events the tap was not sent and has not since seen end. Offered
    /// events update it whether sent or not, and `run` leaves it alone: it describes the system's stream, not the tap.
    private var scrollUnderWayUnseen = false
    /// false: the context is exact, built from what the fake withheld. true: built as the real tap builds it,
    /// `TapContext.estimated(from:)`, so a row can show the divergence.
    var usesEstimatedContext = false
    private enum Turn { case wake, notice }
    private var pendingTurns: [Turn] = []
    private var holdsTurns = false
    private var isDraining = false
    private var buttonWasDown = false
    private var pressInProgress: PressID?
    private var nextPressNumber: Int64 = 1
    private let confirmation = WindowSwipeConfirmation()
    /// The answer to every window swipe start a frame reported, in order.
    private(set) var windowSwipeAnswers: [Bool] = []

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
        levels = [:]
        buttonWasDown = false
        pressInProgress = nil
        pendingTurns = []
        isGatedPortOn = false
        if blockClicks && !trackpads.isEmpty {
            tap = TapFilters()
            isPressPortOn = true
            queue(.wake)
        } else {
            tap = nil
            isPressPortOn = false
        }
    }

    func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID) { pulses.append(Pulse(haptic: haptic, trackpad: trackpad)) }

    func confirmWindowSwipe(on trackpad: TrackpadID) { confirmation.confirm(on: trackpad) }

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
    /// reaches the tap between frames, so it is decided on the level the previous frame left, merged across
    /// trackpads; then the frame's press is re-sampled through the filters' `holding`, as the frame callback does.
    /// A trackpad whose `wantsTap` flipped wakes the tap's thread. Frames on a trackpad that is not running, or deaf since `sleep()`, are dropped like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) {
        for frame in frames {
            guard !deaf.contains(id), running[id] != nil else { return }
            let buttonDown = frame.press != nil
            deliverPressEdge(buttonDown: buttonDown)
            let sampled = TouchFrame(
                time: frame.time, touches: frame.touches,
                press: TouchFrame.Press(holding: tap?.holding, buttonDown: buttonDown))
            guard let recognition = running[id]?.step(sampled) else { return }
            let previous = levels[id] ?? .none
            levels[id] = recognition.blocking
            if previous.wantsTap != recognition.blocking.wantsTap { queue(.wake) }
            guard let event = recognition.event,
                  let answer = confirmation.deliver(TrackpadEvent(event, on: id), to: onEvent) else { continue }
            windowSwipeAnswers.append(answer)
            // As the real adapter's reply: taken between frames, before the next one. A `run` inside `onEvent`
            // replaced the recognizer with one that has no such start, and it ignores the answer.
            running[id]?.answerWindowSwipe(began: sampled.time, isWindowSwipe: answer)
        }
    }

    private func deliverPressEdge(buttonDown: Bool) {
        defer { buttonWasDown = buttonDown }
        guard tap != nil, buttonDown != buttonWasDown else { return }
        let event: PointerEvent
        if buttonDown {
            let press = PressID(button: 0, number: nextPressNumber)
            nextPressNumber += 1
            pressInProgress = press
            event = .press(press)
        } else if let press = pressInProgress {
            pressInProgress = nil
            event = .release(press)
        } else {
            return
        }
        switch offer(.pointer(event)) {
        case .decided(.pointer(let verdict)): pressVerdicts.append(verdict)
        default: pressVerdicts.append(.pass)
        }
    }

    enum Delivery: Equatable { case noTap, notSent, decided(TapVerdict) }
    enum Port: Hashable { case presses, gated }

    /// An event as the window server would hand it: `.noTap` with no tap; `.notSent` while its port is off.
    /// Never appends to `pressVerdicts` (the frames' presses do).
    func offer(_ event: TapEvent) -> Delivery {
        guard tap != nil else { return .noTap }
        let isSent = event.ridesGatedPort ? isGatedPortOn : isPressPortOn
        if case .scroll(.fingers(let phase)) = event {
            switch phase {
            case .mayBegin, .began, .changed: scrollUnderWayUnseen = !isSent
            case .ended, .cancelled: scrollUnderWayUnseen = false
            }
        }
        guard isSent else { return .notSent }
        let decision = tap!.decide(event, in: context())
        apply(decision.gate)
        return .decided(decision.verdict)
    }

    /// A scroll event reaching the fake tap, as the apps see it. nil when no tap is armed, so the event reaches apps
    /// untouched.
    func scroll(_ event: ScrollEvent) -> ScrollVerdict? {
        switch offer(.scroll(event)) {
        case .noTap: nil
        case .notSent: .pass
        case .decided(.scroll(let verdict)): verdict
        case .decided: preconditionFailure("a scroll event is decided as a scroll verdict")
        }
    }

    /// Wakes and notices queue while `body` runs, then run in order: the open latency, made visible.
    func withLateWakes(_ body: () -> Void) {
        let outer = holdsTurns
        holdsTurns = true
        body()
        holdsTurns = outer
        if !outer { drain() }
    }

    /// The system's disable of one or both ports: each goes off and its notice is queued.
    func systemDisables(_ ports: Set<Port> = [.presses, .gated]) {
        guard tap != nil else { return }
        if ports.contains(.presses) {
            isPressPortOn = false
            queue(.notice)
        }
        if ports.contains(.gated) {
            isGatedPortOn = false
            queue(.notice)
        }
    }

    private func context() -> TapContext {
        let merged = levels.values.max() ?? .none
        return usesEstimatedContext
            ? TapContext.estimated(from: merged)
            : TapContext(blocking: merged, scrollMayBeUnderWay: scrollUnderWayUnseen)
    }

    private func apply(_ change: GateChange?) {
        switch change {
        case .open: isGatedPortOn = true
        case .close:
            isGatedPortOn = false
            queue(.notice)
        case nil: break
        }
    }

    private func queue(_ turn: Turn) {
        pendingTurns.append(turn)
        if !holdsTurns { drain() }
    }

    private func drain() {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        while !pendingTurns.isEmpty {
            let turn = pendingTurns.removeFirst()
            guard tap != nil else { continue }
            switch turn {
            case .wake:
                apply(tap!.follow(context()))
            case .notice:
                let pressesWereOff = !isPressPortOn
                apply(
                    tap!.portsWereDisabled(
                        pressPortIsOn: isPressPortOn, gatedPortIsOn: isGatedPortOn, in: context()))
                if pressesWereOff { isPressPortOn = true }
            }
        }
    }

    /// An event the frame thread recognised just before activity flipped, delivered regardless of `running`.
    func inject(_ event: TrackpadEvent) { _ = confirmation.deliver(event, to: onEvent) }
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
    /// One entry per play, in order.
    private(set) var launchAnimations: [AppEntry] = []
    /// The latest set prepared; each prepare replaces the one before.
    private(set) var preparedLaunchAnimations: [AppEntry] = []
    /// The active app the next `runningApps()` answers; nil models no active app.
    var frontmost: AppEntry?
    /// The ⌘-Tab apps the next `runningApps()` answers, most recently activated first.
    var running: [AppEntry] = []
    /// Runs inside `playLaunchAnimation(for:)` so a test can observe the other effects at that moment.
    var onPlayLaunchAnimation: (() -> Void)?

    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }

    func runningApps() -> RunningApps { RunningApps(frontmost: frontmost, apps: running) }

    /// The frontmost app's windows the next `frontmostWindows()` answers.
    let windows = FakeWindows()

    func frontmostWindows() -> FrontmostWindows { windows.read(frontmost: frontmost) }

    func raiseWindows(_ frontToBack: [WindowID]) { windows.raise(frontToBack) }

    func prepareLaunchAnimations(for apps: [AppEntry]) { preparedLaunchAnimations = apps }

    func playLaunchAnimation(for app: AppEntry) {
        launchAnimations.append(app)
        onPlayLaunchAnimation?()
    }

    /// Processes ⌘-Tab does not show: menu bar apps, apps still starting from the Dock.
    var processes: Set<BundleID> = []
    /// The bounces playing, in start order: the row, newest last. Every `bringToFrontBouncing` call appends, a repeated
    /// one too, so a second start shows; the fake does not copy the adapter's one-bounce-per-app guard.
    private(set) var bounces: [Bounce] = []
    /// Every `endLaunchBounce` call, in order, so a double end shows.
    private(set) var bounceEndings: [BounceEnd] = []
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    /// Runs inside `bringToFrontBouncing`, like `onPlayLaunchAnimation`, so a test can see the other effects then.
    var onBringToFrontBouncing: (() -> Void)?

    struct Bounce: Equatable {
        let app: AppEntry
        let cap: Duration
        /// Every limit the model set, in order. Recorded, not applied: which deadline passes first is the adapter's.
        var limits: [Duration] = []
    }

    struct BounceEnd: Equatable {
        let app: BundleID
        let ending: LaunchBounceEnding
    }

    /// Derived, never synced: a ⌘-Tab app and the frontmost app have a process too.
    func hasProcess(_ app: BundleID) -> Bool {
        processes.contains(app) || frontmost?.bundleID == app || running.contains { $0.bundleID == app }
    }

    /// Records the bring to front, then the bounce, in that order.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        broughtToFront.append(app)
        bounces.append(Bounce(app: app, cap: cap))
        onBringToFrontBouncing?()
    }

    func limitLaunchBounce(of app: BundleID, to limit: Duration) {
        guard let index = bounces.firstIndex(where: { $0.app.bundleID == app }) else { return }
        bounces[index].limits.append(limit)
    }

    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) {
        bounceEndings.append(BounceEnd(app: app, ending: ending))
        bounces.removeAll { $0.app.bundleID == app }
    }

    /// The launch reports `progress` inline, as the real adapter pushes it on the main actor. A test withholds a report
    /// by not calling this, delivers one late by calling it after the end, and passes time with `.ranOut`.
    func report(_ progress: LaunchProgress, for app: BundleID) { onLaunchProgress?(app, progress) }
}

/// The frontmost app's window stack, by name: one fixed `WindowID` per name for the life of the test. A window's title is
/// its name unless the name is marked untitled. Carries no policy: reads report full-screen and minimised windows as
/// they are, uncut, and raises do what the system's raise does and nothing more.
@MainActor final class FakeWindows {
    /// Front to back.
    private(set) var onScreenTitles: [String] = []
    /// In the order the app lists them.
    private(set) var minimisedTitles: [String] = []
    private var fullScreenFront = false
    private var untitled: Set<String> = []
    /// false: the app does not answer in time, so reads list nothing.
    var answers = true
    /// true: raises are logged and change nothing, as with an app that ignores them.
    var dropsRaises = false
    /// How many times the windows were read.
    private(set) var reads = 0
    /// Every `raise(_:)` call, in order, empty ones included.
    private(set) var raised: [[WindowID]] = []
    private var ids: [String: WindowID] = [:]
    /// The names the latest read listed: the only windows a raise may touch.
    private var listed: Set<String> = []

    /// `untitled`: names whose windows report an empty title.
    func set(visible: [String], minimised: [String] = [], fullScreenFront: Bool = false, untitled: Set<String> = []) {
        onScreenTitles = visible
        minimisedTitles = minimised
        self.fullScreenFront = fullScreenFront
        self.untitled = untitled
    }

    /// A new visible window, in front.
    func open(_ title: String) { onScreenTitles.insert(title, at: 0) }

    /// The user minimises a visible window; it goes last among the minimised ones.
    func minimise(_ title: String) {
        guard let index = onScreenTitles.firstIndex(of: title) else { return }
        onScreenTitles.remove(at: index)
        minimisedTitles.append(title)
    }

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
        listed = []
        guard let frontmost else { return .noApp }
        guard answers else { return .app(frontmost, visible: [], minimised: []) }
        listed = Set(onScreenTitles + minimisedTitles)
        let visible = onScreenTitles.enumerated().map { index, title in
            AppWindow(id: id(title), title: self.title(of: title), isFullScreen: index == 0 && fullScreenFront)
        }
        let minimised = minimisedTitles.map { AppWindow(id: id($0), title: title(of: $0)) }
        return .app(frontmost, visible: visible, minimised: minimised)
    }

    /// The last first, each to the front of the visible stack; a minimised one is restored. Closed windows and windows
    /// the latest read did not list are skipped.
    func raise(_ frontToBack: [WindowID]) {
        raised.append(frontToBack)
        guard answers, !dropsRaises else { return }
        for id in frontToBack.reversed() {
            guard let name = ids.first(where: { $0.value == id })?.key, listed.contains(name) else { continue }
            if let index = minimisedTitles.firstIndex(of: name) {
                minimisedTitles.remove(at: index)
            } else if let index = onScreenTitles.firstIndex(of: name) {
                onScreenTitles.remove(at: index)
            } else {
                continue
            }
            onScreenTitles.insert(name, at: 0)
        }
    }

    private func title(of name: String) -> String { untitled.contains(name) ? "" : name }
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

@MainActor final class InMemoryLoginItem: LoginItem {
    /// The user's Login Items choice for this app.
    var isOn = false
    /// Every `register()` call, in order.
    private(set) var calls: [String] = []
    /// Runs inside `register()` so a test can observe what is stored at that moment.
    var onRegister: (() -> Void)?

    @discardableResult func register() -> Bool {
        calls.append("register")
        isOn = true
        onRegister?()
        return true
    }
}

/// Ending a process asks its `Lifecycle` first, as `NSApp.terminate` asks `applicationShouldTerminate`.
@MainActor final class InMemoryRunningCopies: RunningCopies {
    weak var lifecycle: Lifecycle?
    private(set) var hasEnded = false

    func endThisCopy() {
        if lifecycle?.shouldEnd(.other) == true { hasEnded = true }
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
