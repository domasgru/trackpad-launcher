import Foundation
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// `activity` is derived, never stored; `rows` derive from settings plus the catalog; `fire` is the only path
/// that pulses, launches, plays the launch animation or the launch bounce from a gesture; no gesture closes the window. `fire`
/// shows either only while the launch animation setting is on: the bounce for an app with no process, the animation for
/// one with a process. A launch with no process is watched while either setting needs it (the bounce shows, or the hide
/// background apps setting waits for the app's window); the progress handler hides the others after its first window.
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
    /// Called with true when the settings window goes from closed to open and false from open to closed; never on a
    /// re-front.
    @ObservationIgnored public var onWindowEdge: (@MainActor (Bool) -> Void)?
    public var thumbCorners: ThumbCorners { ThumbCorners(macBook: settings.thumbCorner, external: externalCorner) }
    /// The one corner every illustration draws.
    public var drawnThumbCorner: ThumbCorner { thumbCorners.drawn(connected: connectedKinds) }
    /// nil until the Mac has mixed trackpads.
    private var externalCorner: ThumbCorner?
    private var connectedKinds: Set<TrackpadKind> { Set(connected.map(\.kind)) }
    public var isLaunchAnimationOn: Bool { settings.isLaunchAnimationOn }
    public var isSwipeOn: Bool { settings.isSwipeOn }
    public var isSwapOn: Bool { settings.isSwapOn }
    public var isHideBackgroundAppsOn: Bool { settings.isHideBackgroundAppsOn }
    public var isWindowSwipeOn: Bool { settings.isWindowSwipeOn }
    /// One derivation, read by the notice and the fire guard.
    public var activity: GestureActivity {
        GestureActivity(connected: connectedKinds)
    }

    /// The sentence the settings window shows while gestures are inactive; nil while they are active.
    public var inactiveNotice: String? {
        guard case .inactive(let cause) = activity else { return nil }
        return Copy.inactiveNotice(for: cause)
    }

    /// The Accessibility hint shows while the permission is missing.
    public var showsAccessibilityHint: Bool { !isAccessibilityGranted }

    public private(set) var isAccessibilityGranted = false
    /// Read with Accessibility on every push, so a window swipe never reads it.
    private var isScreenRecordingGranted = false

    /// nil while the window swipe setting is off or Screen Recording is granted.
    public var screenRecordingHint: ScreenRecordingHint? {
        guard settings.isWindowSwipeOn, !isScreenRecordingGranted else { return nil }
        return settings.hasAskedForScreenRecording ? .openSettings : .ask
    }

    public enum Window: Equatable, Sendable {
        case closed
        /// `request` counts the openings by hand in this process. Each one brings the settings window to the front with
        /// the keyboard focus, restoring it when minimised; centring on the pointer's display happens only from
        /// `.closed`.
        case open(request: Int)
    }

    public private(set) var window: Window = .closed
    /// At most one switcher of either kind at a time. Written only by `swipe(_:)`, `windowSwipe(_:)` and `reconcile()`.
    private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }

    private var shown: ShownSwitcher?
    /// Both kinds of switcher take their serial from it, so an app switcher and a window switcher never share one.
    @ObservationIgnored private var switchersBegun = 0
    /// Each app's window order. Written only by `windowSwipe(.began)`; survives reconciles; never saved.
    @ObservationIgnored private var windowOrders = WindowOrders()
    /// The launches being watched, one record per launched bundle. Written only by `fire` and `progress(_:of:)`: the one
    /// record of which launches are live; the adapter's watches and bounces follow its commands.
    @ObservationIgnored private var launches: [BundleID: WatchedLaunch] = [:]
    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    /// The openings by hand in this process; `window`'s request number.
    @ObservationIgnored private var openings = 0
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let permissions: any Permissions
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let scanner: any AppScanner
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let startAtLogin: StartAtLogin

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore,
        startAtLogin: StartAtLogin
    ) {
        self.startAtLogin = startAtLogin
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
        externalCorner = store.loadExternalCorner()
        rows = makeRows()
    }

    /// Gestures on. Asks nothing, opens nothing and never saves the settings record, so a first run still waits for
    /// the first opening by hand. It may write one thing, once in a Mac's life: the External corner (see `reconcile`).
    /// Call once.
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
        system.onLaunchProgress = { [unowned self] app, progress in self.progress(progress, of: app) }
        scanner.onScan = { [unowned self] in installedApps = $0 }
        scanner.scan()
        preferences.onChange = { [unowned self] in reconcile() }
        permissions.onChange = { [unowned self] in reconcile() }
        reconcile()
        resolveRows()
    }

    /// The first picker; nil = None, which unassigns the gesture, second app included. An app becomes the first app
    /// and the second app stays, unless it is that app. The same app on two gestures is fine. Answers the app the
    /// first picker now shows present, so the picker knows whether to play the pick animation: nil for None, for a
    /// bundle that is no app, and for an app the catalog cannot locate, whose row shows "not found".
    @discardableResult
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) -> AppEntry? {
        if let choice {
            guard let entry = entry(for: choice) else { return nil }
            let app = AssignedApp(entry)
            settings.assignments[gesture] = settings.assignments[gesture]?.settingFirst(app) ?? Assignment(first: app)
        } else {
            settings.assignments[gesture] = nil
        }
        store.save(settings)
        resolveRows()
        if case .present(let entry) = rows.first(where: { $0.gesture == gesture })?.app { return entry }
        return nil
    }

    /// The plus button and the second picker. Answers the app the second picker now shows present, which plays the
    /// pick animation. nil, with nothing saved: no first app, the first app itself (also through Other…), a bundle that
    /// is no app, or an app the catalog cannot locate.
    @discardableResult
    public func setSecondApp(_ choice: AppChoice, for gesture: Gesture) -> AppEntry? {
        guard let assignment = settings.assignments[gesture], let entry = entry(for: choice),
            let split = assignment.settingSecond(AssignedApp(entry))
        else { return nil }
        settings.assignments[gesture] = split
        store.save(settings)
        resolveRows()
        if case .two(_, .present(let entry))? = rows.first(where: { $0.gesture == gesture })?.apps { return entry }
        return nil
    }

    /// The minus button. Does nothing, and saves nothing, without a second app.
    public func removeSecondApp(for gesture: Gesture) {
        guard let assignment = settings.assignments[gesture], assignment.second != nil else { return }
        settings.assignments[gesture] = assignment.removingSecond
        store.save(settings)
        resolveRows()
    }

    private func entry(for choice: AppChoice) -> AppEntry? {
        switch choice {
        case .app(let entry): entry
        case .appBundle(let url): catalog.entry(at: url)
        }
    }

    /// Thumb corner change. Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setThumbCorner(_ corner: ThumbCorner) {
        guard corner != settings.thumbCorner else { return }
        settings.thumbCorner = corner
        store.save(settings)
        reconcile()
    }

    /// The External trackpad corner. Saved at once under its own key; the reconcile re-runs the trackpads only if an
    /// external trackpad is connected, since only then does a corner in effect change. Does nothing on a Mac without
    /// mixed trackpads, which has no External corner and no row to set it from.
    public func setExternalThumbCorner(_ corner: ThumbCorner) {
        guard let current = externalCorner, corner != current else { return }
        externalCorner = corner
        store.saveExternalCorner(corner)
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

    /// Hide background apps switch. Saved at once; it hides and shows nothing now and applies to the next action.
    public func setHideBackgroundApps(on: Bool) {
        guard on != settings.isHideBackgroundAppsOn else { return }
        settings.isHideBackgroundAppsOn = on
        store.save(settings)
    }

    /// The screen recording hint's button while it asks. Records the ask and saves before asking, so a crash in
    /// between never asks twice; a later press opens System Settings instead.
    public func askForScreenRecording() {
        guard screenRecordingHint == .ask else { return }
        settings.hasAskedForScreenRecording = true
        store.save(settings)
        permissions.ask(.screenRecording)
    }

    /// The user opened Trackpad Launcher. The first time in this process, on a first run (no saved settings): start at
    /// login and ask for Accessibility when it is missing, then save; both effects come before the save, so a crash in
    /// between repeats them rather than losing them. On any other run, start at login again if a Quit turned it off.
    /// Every time: the settings window opens or comes to the front, the
    /// rows resolve again and the app list refreshes in the background.
    public func openedByHand() {
        if openings == 0 {
            if isFirstLaunch {
                startAtLogin.enrol()
                if !isAccessibilityGranted { permissions.ask(.accessibility) }
                store.save(settings)
            } else {
                startAtLogin.resume()
            }
        }
        openings += 1
        let wasOpen = isWindowOpen
        window = .open(request: openings)
        if !wasOpen { onWindowEdge?(true) }
        resolveRows()
        scanner.scan()
    }

    /// Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running.
    public func closeWindow() {
        guard window != .closed else { return }
        window = .closed
        onWindowEdge?(false)
    }

    /// What the trackpads were last run with. A reconcile that would run them the same way leaves them, and any swipe
    /// in progress, alone: preference and trust notifications also fire for writes that change nothing here.
    private struct Run: Equatable {
        let trackpads: [TrackpadRun]
        let blockClicks: Bool
        let blockTapClicks: Bool
        let slides: Set<SlideKind>
        let swaps: Bool
    }

    @ObservationIgnored private var lastRun: Run?
    @ObservationIgnored private var swapSeries = SwapSeries()

    /// The one convergent operation behind launch, hot-plug, wake, preference, thumb corner and trust changes.
    /// `restart`: run the trackpads even if nothing changed. Hot-plug and wake need it: devices stop delivering frames
    /// across sleep.
    private func reconcile(restart: Bool = false) {
        connected = hardware.connected()
        // Mixed trackpads seen for the first time: a start, a hot-plug, a wake, a login start or hand-over after an
        // update. Never the settings record. Idempotent: a later pass finds an External corner and writes nothing.
        if externalCorner == nil, ThumbCorners.areMixed(connectedKinds) {
            store.saveExternalCorner(ThumbCorners.defaultExternal)
            externalCorner = ThumbCorners.defaultExternal
        }
        preferenceValues = preferences.current()
        let granted = permissions.isGranted(.accessibility)
        isAccessibilityGranted = granted
        // Before the run guard: a Screen Recording change never re-runs the trackpads.
        isScreenRecordingGranted = permissions.isGranted(.screenRecording)
        let active = activity.isActive
        // Blocking needs gestures active and access granted; without either, presses are plain clicks. Without access
        // no window can be read, so a slide up or down is what it is with the window swipe setting off.
        let blockClicks = active && granted
        let tapToClickIsOn = TapBoundSetting.on(connected: connectedKinds, values: preferenceValues)
            .contains(.tapToClick)
        let corners = thumbCorners
        let run = Run(
            trackpads: active ? connected.map { TrackpadRun($0, corner: corners.corner(for: $0.kind)) } : [],
            blockClicks: blockClicks,
            blockTapClicks: blockClicks && tapToClickIsOn,
            slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe]), swaps: settings.isSwapOn)
        guard restart || run != lastRun else { return }
        lastRun = run
        // Running replaces every recognizer, which ends any swipe or window swipe in progress.
        shown = nil
        hardware.run(run.trackpads, blockClicks: run.blockClicks,
            blockTapClicks: run.blockTapClicks, slides: run.slides, swaps: run.swaps)
    }

    private func hideOtherApps(than app: BundleID) {
        guard settings.isHideBackgroundAppsOn else { return }
        system.hideOtherApps(keeping: KeptApps(front: app))
    }

    /// Every silent case decided here and only here: inactive, unassigned, every app missing. A one-app gesture reads
    /// `hasProcess` only when it decides something: the launch animation or the hide setting is on, and no launch of the
    /// app is watched. A split gesture reads it for each app without a watched launch, since the entrance decides who
    /// is activated.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive, let assignment = settings.assignments[event.gesture] else { return }
        let target = assignment.target(locate: catalog.locate)
        guard target != .nothing else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        switch target {
        case .nothing: break
        case .one(let app): bringOneToFront(app)
        case .split(let first, let second): splitToFront(first, second)
        }
    }

    private func bringOneToFront(_ app: AppEntry) {
        let animates = settings.isLaunchAnimationOn
        let hides = settings.isHideBackgroundAppsOn
        let id = app.bundleID
        let kept = hides ? KeptApps(front: id) : nil
        // A watched launch keeps its one watch, bouncing or unseen; only its hide follows the latest gesture.
        if launches[id] != nil {
            launches[id]?.hidesOnWindow = kept
            system.bringToFront(app)
            return
        }
        guard animates || hides else { return system.bringToFront(app) }
        guard system.hasProcess(id) else {
            launches[id] = WatchedLaunch(stage: .startingUp, hidesOnWindow: kept)
            // Opens the app first, inside the call.
            system.bringToFrontWatching(app, cap: WatchedLaunch.cap, bouncing: animates)
            return
        }
        system.bringToFront(app)
        if animates {
            // After bring to front, so whatever the animation costs lands on the icon, never on the app.
            system.playLaunchAnimation(for: app)
        }
        hideOtherApps(than: id)
    }

    /// Both apps in one port call, so the adapter keeps the open order. The first app ends active; a launching app
    /// hides the others once its window shows, and never hides the other app of the gesture.
    private func splitToFront(_ first: AppEntry, _ second: AppEntry) {
        let animates = settings.isLaunchAnimationOn
        let kept = settings.isHideBackgroundAppsOn ? KeptApps(front: first.bundleID, beside: second.bundleID) : nil
        func entrance(_ app: AppEntry) -> SplitApp {
            let id = app.bundleID
            if launches[id] != nil {
                launches[id]?.hidesOnWindow = kept
                return SplitApp(app, .alreadyLaunching)
            }
            guard !system.hasProcess(id) else { return SplitApp(app, .running(animates: animates, followed: false)) }
            let watched = animates || kept != nil
            if watched { launches[id] = WatchedLaunch(stage: .startingUp, hidesOnWindow: kept) }
            return SplitApp(app, .launching(watch: watched ? (animates ? .bouncing : .unseen) : nil))
        }
        let arrival = SplitArrival(first: entrance(first), second: entrance(second))
        system.bringToFront(arrival, cap: WatchedLaunch.cap)
        if let kept, launches[first.bundleID] == nil, launches[second.bundleID] == nil {
            system.hideOtherApps(keeping: kept)
        }
    }

    /// A report for an app whose launch ended finds no record: a late window plays and hides nothing.
    private func progress(_ progress: LaunchProgress, of app: BundleID) {
        guard let launch = launches[app] else { return }
        switch launch.stage.next(after: progress) {
        case .carryOn: break
        case .startUp(let limit):
            launches[app]?.stage = .startedUp
            system.limitLaunch(of: app, to: limit)
        case .end(let ending):
            launches[app] = nil
            system.endLaunch(of: app, with: ending)
            // After the end, so a bounce's launch animation starts first. The record decides, not the switch now.
            if progress == .windowShown, let kept = launch.hidesOnWindow,
               kept.hides(
                   onWindowOf: app, frontmost: system.runningApps().frontmost?.bundleID,
                   frontStillWaits: launches[kept.front]?.hidesOnWindow != nil) {
                system.hideOtherApps(keeping: kept)
            }
        }
    }

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        switch event.phase {
        case .began:
            guard shown == nil, activity.isActive else { return }
            // With nothing to show the swipe still runs its course: the fingers stay blocked until they lift.
            let running = system.runningApps()
            guard let switcher = Switcher(
                frontmost: running.frontmost, running: running.apps, leavingOut: settings.oneAppBundleIDs,
                serial: switchersBegun + 1, trackpad: event.trackpad)
            else { return }
            switchersBegun += 1
            // The row is up before any read starts. Without Accessibility no window can be read, and the window swipe
            // setting plays no part.
            shown = .apps(switcher)
            guard isAccessibilityGranted else { return }
            let serial = switcher.serial
            system.readWindows(of: switcher.row, within: GestureRules.windowReadDeadline) { [unowned self] slot, read in
                counted(read, at: slot, swipe: serial)
            }
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
            hideOtherApps(than: target.bundleID)
        case .cancelled:
            if case .apps(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
        }
    }

    /// A count lands only in the switcher it was read for, once per slot: an ended, cancelled, reconciled or later
    /// swipe's switcher drops it.
    private func counted(_ read: WindowRead, at slot: Int, swipe serial: Int) {
        guard case .apps(var open)? = shown, open.serial == serial, open.take(read, at: slot) else { return }
        shown = .apps(open)
    }

    /// The one place a window swipe becomes effects. Never the launch animation.
    private func windowSwipe(_ event: SwipeEvent) {
        switch event.phase {
        case .began:
            // A slide up or down is a window swipe whenever the one read knows the frontmost app's window count: rows
            // for two or more, the card below that. Unconfirmed, the recognizer makes it the slide the setting off would have made, before its next frame.
            guard activity.isActive,
                let content = windowOrders.list(
                    system.frontmostWindows(within: GestureRules.windowReadDeadline),
                    stillOpen: { system.openWindows(among: $0) })
            else { return }
            hardware.confirmWindowSwipe(on: event.trackpad)
            // One switcher at a time: a second trackpad's window swipe runs its course with none, as its swipe would.
            guard shown == nil else { return }
            switchersBegun += 1
            // The grant as the last TCC push left it: a fresh preflight would cost about 4 ms here.
            shown = .windows(
                WindowSwitcher(
                    content, showsPreviews: isScreenRecordingGranted, serial: switchersBegun,
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
            // Lifting on the card changes nothing: no second read, no raise, no haptic, no hide.
            guard !open.isCard else { return }
            // The second read: the lift follows the windows as they are now, whatever the raises while sliding did.
            let lift = open.lift(now: system.frontmostWindows(within: GestureRules.windowReadDeadline))
            if lift.playsHaptic {
                hardware.playFeedback(.gesture, on: event.trackpad)
            }
            system.raiseWindows(lift.raises)
            if lift.playsHaptic { hideOtherApps(than: open.app.bundleID) }
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
        hideOtherApps(than: target.bundleID)
    }

    /// Rows and the prepared launch animations change together, so the icon of any app that can fire is ready before
    /// its gesture: a first render of an app's icon can take over 100 ms.
    private func resolveRows() {
        rows = makeRows()
        var seen = Set<URL>()
        let present = rows.flatMap { row -> [GestureRow.Held] in
            switch row.apps {
            case .unassigned: []
            case .one(let first): [first]
            case .two(let first, let second): [first, second]
            }
        }.compactMap { held -> AppEntry? in
            guard case .present(let app) = held, seen.insert(app.url).inserted else { return nil }
            return app
        }
        system.prepareLaunchAnimations(for: present)
    }

    private func makeRows() -> [GestureRow] {
        func held(_ assigned: AssignedApp) -> GestureRow.Held {
            catalog.locate(assigned).map(GestureRow.Held.present)
                ?? .missing(name: assigned.name, bundleID: assigned.bundleID)
        }
        return Gesture.allCases.map { gesture in
            guard let assignment = settings.assignments[gesture] else {
                return GestureRow(gesture: gesture, apps: .unassigned)
            }
            let first = held(assignment.first)
            return GestureRow(
                gesture: gesture,
                apps: assignment.second.map { .two(first: first, second: held($0)) } ?? .one(first))
        }
    }
}
