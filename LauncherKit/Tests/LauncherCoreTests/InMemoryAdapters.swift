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
    /// What each running trackpad's frames have told the tap, as the real session keeps it.
    private var states: [TrackpadID: TrackpadTapState] = [:]
    /// The process's monotonic clock: never goes backwards, follows the latest frame time handed on any trackpad, and
    /// moves on its own only through `advanceClock(by:)`.
    private(set) var clock = Uptime(seconds: 0)
    /// Whether the system's current fingers scroll has events the tap was not sent and has not since seen end. Offered
    /// events update it whether sent or not, and `run` leaves it alone: it describes the system's stream, not the tap.
    private var scrollUnderWayUnseen = false
    /// false: the context is exact, built from what the fake withheld. true: built as the real tap builds it,
    /// `TapContext.estimated(from:liftWindowIsOpen:)`, so a row can show the divergence.
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

    func run(
        _ trackpads: [Trackpad], corner: ThumbCorner, blockClicks: Bool, blockTapClicks: Bool, slides: Set<SlideKind>,
        swaps: Bool
    ) {
        runCount += 1
        running = Dictionary(
            uniqueKeysWithValues: trackpads.map {
                ($0.id, GestureRecognizer(corner: corner, surface: $0.surface, slides: slides, swaps: swaps, travel: .linear))
            })
        deaf = []
        states = [:]
        buttonWasDown = false
        pressInProgress = nil
        pendingTurns = []
        isGatedPortOn = false
        if blockClicks && !trackpads.isEmpty {
            tap = TapFilters(blocksTapClicks: blockTapClicks)
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
            clock = max(clock, Uptime(seconds: frame.time.seconds))
            let now = clock
            var state = states[id, default: TrackpadTapState()]
            let time = state.needsTime(for: recognition) ? now : nil
            let flipped = state.take(recognition, at: time)
            states[id] = state
            if flipped { queue(.wake) }
            guard let event = recognition.event,
                  let answer = confirmation.deliver(TrackpadEvent(event, on: id), to: onEvent) else { continue }
            windowSwipeAnswers.append(answer)
            // As the real adapter's reply: taken between frames, before the next one. A `run` inside `onEvent`
            // replaced the recognizer with one that has no such start, and it ignores the answer.
            running[id]?.answerWindowSwipe(began: sampled.time, isWindowSwipe: answer)
        }
    }

    /// Time passing with the pad empty and nothing arriving: no frame, no event.
    func advanceClock(by duration: Duration) { clock = clock + duration }

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
        let merged = TrackpadTapState.merged(states.values, at: clock)
        return usesEstimatedContext
            ? TapContext.estimated(from: merged.blocking, liftWindowIsOpen: merged.liftWindowIsOpen)
            : TapContext(
                blocking: merged.blocking, liftWindowIsOpen: merged.liftWindowIsOpen,
                scrollMayBeUnderWay: scrollUnderWayUnseen)
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

    func set(_ setting: TapBoundSetting, rawValue: Int?, for kind: TrackpadKind) {
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

    /// Runs inside `bringToFront`, after recording, as the system acts on the app coming forward.
    var onBringToFront: ((AppEntry) -> Void)?

    func bringToFront(_ app: AppEntry) {
        broughtToFront.append(app)
        hiddenApps.remove(app.bundleID)
        onBringToFront?(app)
    }

    /// Every hide, by the app it kept, in order.
    private(set) var hidesOthers: [BundleID] = []
    /// Which apps are hidden now. A hide adds every ⌘-Tab app and the frontmost app but the kept one at once: the
    /// adapter's deferral and next-turn hop are its own mechanics. Any bring to front shows the app again.
    private(set) var hiddenApps: Set<BundleID> = []
    /// Runs inside `hideOtherApps`, after recording, so a test can see what was already recorded.
    var onHideOtherApps: (() -> Void)?

    func hideOtherApps(than app: BundleID) {
        hidesOthers.append(app)
        hiddenApps.formUnion((running + (frontmost.map { [$0] } ?? [])).map(\.bundleID).filter { $0 != app })
        onHideOtherApps?()
    }

    func runningApps() -> RunningApps { RunningApps(frontmost: frontmost, apps: running) }

    private let windowNumbers = WindowNumbers()
    private var windowSets: [URL: FakeWindows] = [:]
    private let noAppWindows: FakeWindows
    /// The app whose reads are `.ownProcess`: Trackpad Launcher.
    var ownApp: AppEntry?
    /// The deadline each `frontmostWindows(within:)` call asked for, in order.
    private(set) var frontmostDeadlines: [Duration] = []

    init() { noAppWindows = FakeWindows(numbers: windowNumbers) }

    /// The windows of this app, one set per running location.
    func windows(of app: AppEntry) -> FakeWindows {
        if let windows = windowSets[app.url] { return windows }
        let windows = FakeWindows(numbers: windowNumbers)
        windowSets[app.url] = windows
        return windows
    }

    /// The frontmost app's windows; with no frontmost app, a set no app reads.
    var windows: FakeWindows { frontmost.map { windows(of: $0) } ?? noAppWindows }

    func frontmostWindows(within deadline: Duration) -> FrontmostWindows {
        frontmostDeadlines.append(deadline)
        guard let frontmost else {
            noAppWindows.noteRead()
            return .noApp
        }
        let fake = windows(of: frontmost)
        return .app(frontmost, fake.launch, fake.read(isOwnProcess: ownApp?.url == frontmost.url))
    }

    func raiseWindows(_ frontToBack: [WindowID]) { windows.raise(frontToBack) }

    func prepareLaunchAnimations(for apps: [AppEntry]) { preparedLaunchAnimations = apps }

    func playLaunchAnimation(for app: AppEntry) {
        launchAnimations.append(app)
        onPlayLaunchAnimation?()
    }

    /// Processes ⌘-Tab does not show: menu bar apps, apps still starting from the Dock.
    var processes: Set<BundleID> = []
    /// The launches being watched, in start order, newest last. Every `bringToFrontWatching` call appends, a repeated
    /// one too, so a second start shows; the fake does not copy the adapter's one-watch-per-app guard.
    private(set) var launches: [Launch] = []
    /// The bounces playing: the watched launches that bounce.
    var bounces: [Bounce] {
        launches.filter(\.bouncing).map { Bounce(app: $0.app, cap: $0.cap, limits: $0.limits) }
    }
    /// Every `endLaunch` call, in order, so a double end shows.
    private(set) var launchEndings: [LaunchEnd] = []
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    /// Runs inside `bringToFrontWatching`, like `onPlayLaunchAnimation`, so a test can see the other effects then.
    var onBringToFrontWatching: (() -> Void)?

    struct Launch: Equatable {
        let app: AppEntry
        let cap: Duration
        let bouncing: Bool
        /// Every limit the model set, in order. Recorded, not applied: which deadline passes first is the adapter's.
        var limits: [Duration] = []
    }

    struct Bounce: Equatable {
        let app: AppEntry
        let cap: Duration
        var limits: [Duration] = []
    }

    struct LaunchEnd: Equatable {
        let app: BundleID
        let ending: LaunchBounceEnding
    }

    /// Derived, never synced: a ⌘-Tab app and the frontmost app have a process too.
    func hasProcess(_ app: BundleID) -> Bool {
        processes.contains(app) || frontmost?.bundleID == app || running.contains { $0.bundleID == app }
    }

    /// Records the bring to front, then the watch, in that order.
    func bringToFrontWatching(_ app: AppEntry, cap: Duration, bouncing: Bool) {
        broughtToFront.append(app)
        hiddenApps.remove(app.bundleID)
        launches.append(Launch(app: app, cap: cap, bouncing: bouncing))
        onBringToFrontWatching?()
    }

    func limitLaunch(of app: BundleID, to limit: Duration) {
        guard let index = launches.firstIndex(where: { $0.app.bundleID == app }) else { return }
        launches[index].limits.append(limit)
    }

    func endLaunch(of app: BundleID, with ending: LaunchBounceEnding) {
        launchEndings.append(LaunchEnd(app: app, ending: ending))
        launches.removeAll { $0.app.bundleID == app }
    }

    /// The launch reports `progress` inline, as the real adapter pushes it on the main actor. A test withholds a report
    /// by not calling this, delivers one late by calling it after the end, and passes time with `.ranOut`.
    func report(_ progress: LaunchProgress, for app: BundleID) { onLaunchProgress?(app, progress) }
}

/// The one counter every app's windows draw numbers from, as the window server's numbers rise in creation order.
@MainActor final class WindowNumbers {
    private var last: UInt32 = 999
    private var launches = 0

    func nextWindow() -> WindowID {
        last += 1
        return WindowID(rawValue: last)
    }

    func nextLaunch() -> AppLaunch {
        launches += 1
        return AppLaunch("fake-launch-\(launches)")
    }
}

/// One app's windows, by name: one fixed `WindowID` per name for the life of the test, given when the window is
/// created. A window's title is its name unless the name is marked untitled. Carries no policy: reads report
/// full-screen and minimised windows as they are, uncut, and raises do what the system's raise does and nothing more.
@MainActor final class FakeWindows {
    enum Answering {
        /// Answers at once.
        case now
        /// Answers, but later than any deadline a read allows.
        case held
        /// Never answers.
        case never
    }

    /// Front to back.
    private(set) var onScreenTitles: [String] = []
    /// In the order the app lists them.
    private(set) var minimisedTitles: [String] = []
    private var fullScreenFront = false
    private var untitled: Set<String> = []
    var answering = Answering.now
    /// true: raises are logged and change nothing, as with an app that ignores them.
    var dropsRaises = false
    /// How many times the windows were read.
    private(set) var reads = 0
    /// Every `raise(_:)` call, in order, empty ones included.
    private(set) var raised: [[WindowID]] = []
    private let numbers: WindowNumbers
    private var ids: [String: WindowID] = [:]
    /// The names the latest read listed: the only windows a raise may touch.
    private var listed: Set<String> = []
    /// The app's current launch, which its frontmost reads carry.
    let launch: AppLaunch

    init(numbers: WindowNumbers) {
        self.numbers = numbers
        launch = numbers.nextLaunch()
    }

    /// `untitled`: names whose windows report an empty title.
    func set(
        visible: [String], minimised: [String] = [], fullScreenFront: Bool = false, untitled: Set<String> = [],
        answering: Answering = .now
    ) {
        onScreenTitles = visible
        minimisedTitles = minimised
        self.fullScreenFront = fullScreenFront
        self.untitled = untitled
        self.answering = answering
        for title in visible + minimised { _ = id(title) }
    }

    /// A new visible window, in front.
    func open(_ title: String) {
        _ = id(title)
        onScreenTitles.insert(title, at: 0)
    }

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
        let id = numbers.nextWindow()
        ids[title] = id
        return id
    }

    /// A read that found no app to ask.
    func noteRead() {
        reads += 1
        listed = []
    }

    func read(isOwnProcess: Bool) -> WindowRead {
        noteRead()
        if isOwnProcess { return .ownProcess }
        guard answering == .now else { return .unanswered }
        listed = Set(onScreenTitles + minimisedTitles)
        let visible = onScreenTitles.enumerated().map { index, title in
            AppWindow(id: id(title), title: self.title(of: title), isFullScreen: index == 0 && fullScreenFront)
        }
        let minimised = minimisedTitles.map { AppWindow(id: id($0), title: title(of: $0)) }
        return .windows(AppWindows(visible: visible, minimised: minimised))
    }

    /// The last first, each to the front of the visible stack; a minimised one is restored. Closed windows and windows
    /// the latest read did not list are skipped.
    func raise(_ frontToBack: [WindowID]) {
        raised.append(frontToBack)
        guard answering == .now, !dropsRaises else { return }
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
    /// Runs before `ask(_:)` takes effect, so a test can observe what a crash there would leave.
    var onEffect: (() -> Void)?

    init(granted: Set<Permission> = []) { self.granted = granted }

    func isGranted(_ permission: Permission) -> Bool { granted.contains(permission) }

    func ask(_ permission: Permission) {
        onEffect?()
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
    /// How macOS may report the user's own off, which is disputed: both readings read `isOn == false`.
    enum UserOffReading {
        /// `register()` fails and the item stays off (`.requiresApproval`).
        case refusesRegistering
        /// `register()` succeeds and turns it on (`.notRegistered`, as after removal from the list).
        case acceptsRegistering
    }

    var userOffReading: UserOffReading = .refusesRegistering
    /// Next login starts the app.
    var isOn = false
    /// True from the user's off in Login Items until anything turns it on again.
    private(set) var isOffByUser = false
    /// Every `register()` and `unregister()` call of ours, in order.
    private(set) var calls: [String] = []
    /// Runs inside `register()` so a test can observe what is stored at that moment.
    var onRegister: (() -> Void)?
    /// Runs before and after every call of ours, so a test can observe what a crash there would leave.
    var onEffect: (() -> Void)?
    var log: EffectLog?

    /// The user switches it off in System Settings → Login Items. Not one of our calls.
    func userTurnsOff() {
        isOn = false
        isOffByUser = true
    }

    /// The user switches it back on in System Settings → Login Items. Not one of our calls.
    func userTurnsOn() {
        isOn = true
        isOffByUser = false
    }

    /// Puts the item back as a snapshot found it.
    func restore(isOn: Bool, isOffByUser: Bool) {
        self.isOn = isOn
        self.isOffByUser = isOffByUser
    }

    @discardableResult func register() -> Bool {
        calls.append("register")
        log?.entries.append("register")
        onEffect?()
        defer { onEffect?() }
        if isOffByUser, userOffReading == .refusesRegistering { return false }
        isOn = true
        isOffByUser = false
        onRegister?()
        return true
    }

    func unregister() {
        calls.append("unregister")
        log?.entries.append("unregister")
        onEffect?()
        isOn = false
        isOffByUser = false
        onEffect?()
    }
}

/// What the login item, the copies and the installer did, in one order.
final class EffectLog {
    var entries: [String] = []
}

/// Counts the engine's calls and records them in the shared log; a test pushes the events Sparkle would.
@MainActor final class InMemoryUpdateEngine: UpdateEngine {
    var log: EffectLog?
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)?
    private(set) var probes = 0
    private(set) var updates = 0
    private(set) var discards = 0
    /// The window flag of each `armRestart`, in order.
    private(set) var arms: [Bool] = []
    /// Every `probe()` or `update()` asked while a cycle it started has not yet been answered by a `.cycleEnded`; a
    /// `.held` keeps the cycle running.
    private(set) var overlaps = 0
    private var cycleRuns = false
    var armWorks = true

    func probe() {
        probes += 1
        log?.entries.append("probe")
        startCycle()
    }

    func update() {
        updates += 1
        log?.entries.append("update")
        startCycle()
    }

    private func startCycle() {
        if cycleRuns { overlaps += 1 }
        cycleRuns = true
    }

    func discardHeldUpdate() {
        discards += 1
        log?.entries.append("discard")
    }

    /// Runs before and after each arm restart, as the world's snapshot hook.
    var onEffect: (() -> Void)?

    func armRestart(opensWindow: Bool) -> Bool {
        onEffect?()
        arms.append(opensWindow)
        if armWorks { log?.entries.append(opensWindow ? "arm restart with window" : "arm restart") }
        onEffect?()
        return armWorks
    }

    /// A cycle's end is recorded before the event is delivered: the answer may start the next cycle.
    func push(_ event: UpdateEngineEvent) {
        if case .cycleEnded = event { cycleRuns = false }
        onEvent?(event)
    }
}

/// A network path the test moves. `watch` pushes the present reading inside the call; `set` pushes every time while
/// watching, an unchanged value included, as a real path monitor does on an interface change.
@MainActor final class InMemoryConnection: Connection {
    var onChange: (@MainActor (Bool) -> Void)?
    /// The reading a `watch` pushes. Settable before a failure.
    var reading = false
    private(set) var isWatching = false
    /// How many times `watch` was called.
    private(set) var watches = 0

    func watch() {
        isWatching = true
        watches += 1
        onChange?(reading)
    }

    func stop() { isWatching = false }

    func set(_ connected: Bool) {
        reading = connected
        guard isWatching else { return }
        onChange?(connected)
    }
}

/// Holds `done` until a row releases an outcome, and records its calls in the shared log.
@MainActor final class InMemoryInstaller: Installer {
    var log: EffectLog?
    private(set) var installCalls = 0
    private(set) var removeOriginalCalls = 0
    private(set) var openInstalledCopyCalls = 0
    private(set) var ejected: [DiskImage] = []
    /// Runs after the swap, before `done`: the moment /Applications changed.
    var onInstalled: (() -> Void)?
    /// Runs before and after each call that leaves something behind.
    var onEffect: (() -> Void)?
    private var held: (@MainActor (InstallOutcome) -> Void)?

    var isHolding: Bool { held != nil }

    func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
        installCalls += 1
        log?.entries.append("install")
        held = done
    }

    func release(_ outcome: InstallOutcome) {
        guard let done = held else { return }
        held = nil
        if outcome == .installed {
            onEffect?()
            onInstalled?()
            onEffect?()
        }
        done(outcome)
    }

    func removeOriginal() {
        removeOriginalCalls += 1
        log?.entries.append("removeOriginal")
        onEffect?()
    }

    func openInstalledCopy() {
        openInstalledCopyCalls += 1
        log?.entries.append("openInstalledCopy")
        onEffect?()
    }

    func eject(_ diskImage: DiskImage) {
        ejected.append(diskImage)
        log?.entries.append("eject")
    }
}

/// Ending a process asks its `Lifecycle` first, as `NSApp.terminate` asks `applicationShouldTerminate`. Other copies
/// exit only when a row lets them.
@MainActor final class InMemoryRunningCopies: RunningCopies {
    weak var lifecycle: Lifecycle?
    var log: EffectLog?
    private(set) var hasEnded = false
    var listed: [RunningCopy] = []
    /// Every copy passed to `stop`, in order.
    private(set) var stopped: [RunningCopy] = []
    /// Copies that exited before `stop` ran: `stop` then calls back inside itself, as KVO's `.initial` does.
    var alreadyExited: Set<CopyID> = []
    private var waitingFor: Set<CopyID> = []
    private var pending: (@MainActor () -> Void)?
    private var lastPush: (@MainActor () -> Void)?

    func others() -> [RunningCopy] { listed }

    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void) {
        stopped += copies
        if !copies.isEmpty { log?.entries.append("stop") }
        waitingFor = Set(copies.map(\.id)).subtracting(alreadyExited)
        pending = exited
        lastPush = exited
        if waitingFor.isEmpty { fire() }
    }

    func letExit(_ id: CopyID) {
        guard waitingFor.remove(id) != nil, waitingFor.isEmpty else { return }
        fire()
    }

    func letStoppedCopiesExit() {
        waitingFor = []
        fire()
    }

    /// The same exit push arriving a second time.
    func deliverExitAgain() { lastPush?() }

    private func fire() {
        guard let exited = pending else { return }
        pending = nil
        exited()
    }

    func endThisCopy() {
        if lifecycle?.shouldEnd(.other) == true {
            hasEnded = true
            log?.entries.append("end")
        }
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
