import Foundation
import LauncherCore

/// One Mac: what outlives a process (the saved settings, the login item, the permissions, the installed apps) and the
/// processes started on it. Each process is a real `Lifecycle` building a real `Launcher` over fresh in-memory sensing
/// adapters. A process that gets no further intent has crashed or been force-quit; the Mac keeps it alive only because
/// the shared permissions still push to it.
@MainActor final class LifecycleWorld {
    let mac: World
    var loginItem: InMemoryLoginItem { mac.loginItem }
    var permissions: InMemoryPermissions { mac.permissions }
    private var processes: [OneProcess] = []
    /// The login item's calls, the copies stopped and the installer's calls of every process, in order.
    let log = EffectLog()
    /// How many snapshots existed when /Applications changed; nil while it has not.
    private(set) var installedAt: Int?

    /// `record` is what an earlier run saved: these apps on these gestures. nil is a Mac that holds no settings.
    init(
        apps: [String] = ["Arc", "Notes"], accessGranted: Bool = true, record: [Gesture: String]? = nil,
        corner: ThumbCorner = .topLeft, hidesBackgroundApps: Bool = false, loginItemOn: Bool = false,
        automaticUpdates: Bool = true
    ) {
        mac = World(apps: apps, accessGranted: accessGranted)
        if let record {
            var settings = Settings()
            settings.thumbCorner = corner
            settings.isHideBackgroundAppsOn = hidesBackgroundApps
            for (gesture, name) in record { settings.assignments[gesture] = Assignment(first: AssignedApp(mac.app(name))) }
            mac.freshStore().save(settings)
        }
        if !automaticUpdates { mac.seedSuite(["automaticUpdatesOff": true]) }
        loginItem.isOn = loginItemOn
        recordEveryEffect()
    }

    /// What outlives every process, so a Mac can be rebuilt from it.
    struct Snapshot {
        let suite: [String: Any]
        let loginItemIsOn: Bool
        let loginItemIsOffByUser: Bool
        let granted: Set<Permission>
    }

    /// Taken before and after each effect that leaves something behind (the login item's calls, the Accessibility ask),
    /// in order: a process killed between two effects leaves exactly one of these. The first save follows the ask with
    /// nothing in between, so the snapshot before the ask and the final state cover a kill around it.
    private(set) var snapshots: [Snapshot] = []

    func snapshot() -> Snapshot {
        Snapshot(
            suite: mac.suiteDomain(), loginItemIsOn: loginItem.isOn, loginItemIsOffByUser: loginItem.isOffByUser,
            granted: permissions.granted)
    }

    /// A Mac that holds only what `snapshot` found left behind, with no process running.
    init(restoring snapshot: Snapshot, apps: [String] = ["Arc", "Notes"]) {
        mac = World(apps: apps, accessGranted: snapshot.granted.contains(.accessibility))
        mac.seedSuite(snapshot.suite)
        loginItem.restore(isOn: snapshot.loginItemIsOn, isOffByUser: snapshot.loginItemIsOffByUser)
        recordEveryEffect()
    }

    private func recordEveryEffect() {
        loginItem.log = log
        loginItem.onEffect = { [unowned self] in snapshots.append(snapshot()) }
        permissions.onEffect = { [unowned self] in snapshots.append(snapshot()) }
    }

    /// A process started by hand or at login, as `applicationDidFinishLaunching` hands it over.
    @discardableResult
    func launch(
        _ opening: Opening, others: [RunningCopy] = [], alreadyExited: Set<RunningCopy> = [],
        placement: Placement = .installed, diskImageToEject: DiskImage? = nil, running: RunningBuild = .development,
        attached: [Trackpad] = [.macBook14]
    ) -> OneProcess {
        let process = OneProcess(mac: mac, placement: placement, running: running, attached: attached, log: log)
        process.installer.onEffect = { [unowned self] in snapshots.append(snapshot()) }
        process.engine.onEffect = { [unowned self] in snapshots.append(snapshot()) }
        process.installer.onInstalled = { [unowned self] in installedAt = snapshots.count }
        process.copies.listed = others
        process.copies.alreadyExited = Set(alreadyExited.map(\.id))
        processes.append(process)
        process.launch(opening, diskImageToEject: diskImageToEject)
        return process
    }

    /// What the hand-over job and Sparkle's installer do once the old process has ended: the next process starts with
    /// `--after-update`, as a release copy, on this same Mac. `installed: false` is a swap that failed, so the old
    /// version comes back.
    @discardableResult
    func finishHandOver(installed: Bool = true, withWindow: Bool? = nil) -> OneProcess {
        if installed { installedAt = snapshots.count }
        let armedWithWindow = processes.compactMap { $0.engine.arms.last }.last ?? false
        return launch(
            .afterUpdate(withWindow: withWindow ?? armedWithWindow), placement: .installed, running: .release)
    }

    /// macOS at login: it starts a process, silently, only while the login item is on.
    func login(others: [RunningCopy] = [], running: RunningBuild = .development) -> OneProcess? {
        loginItem.isOn ? launch(.atLogin, others: others, running: running) : nil
    }
}

/// What the process is: `.release` passes the gate wherever it lies, given placement; `.development` does not.
struct RunningBuild {
    var developerIDSigned: Bool
    var canWrite: Bool
    var version: AppVersion = "1.1.22"

    static let development = RunningBuild(developerIDSigned: false, canWrite: true)
    static let release = RunningBuild(developerIDSigned: true, canWrite: true)
    static func release(canWrite: Bool) -> RunningBuild { RunningBuild(developerIDSigned: true, canWrite: canWrite) }
}

extension AppVersion: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

@MainActor final class OneProcess {
    private let mac: World
    private let startAtLogin: StartAtLogin
    private(set) var lifecycle: Lifecycle!
    let copies = InMemoryRunningCopies()
    let installer = InMemoryInstaller()
    let hardware: InMemoryTrackpads
    let preferences = InMemoryTrackpadPreferences()
    let system = RecordingSystemActions()
    private(set) var residentsBuilt = 0

    /// What the settings window shows after an intent or a delivery.
    struct Published: Equatable {
        let window: Launcher.Window
        let card: UpdateCard?
        let isAutomaticUpdatesOn: Bool
        let button: CheckButton
        let alert: UpdateAlert?
        /// Taken after a fake delivered something, not after an intent.
        var afterDelivery = false
    }

    /// The window and the update card after each intent and each delivery of a fake, in order.
    private(set) var history: [Published] = []
    /// The window after each intent: a delivery of a fake is not one.
    var windows: [Launcher.Window] { history.filter { !$0.afterDelivery }.map(\.window) }
    var cards: [UpdateCard?] { history.map(\.card) }
    var card: UpdateCard? { updater.card }
    /// Kept apart from `lifecycle.launcher`, which is nil once the process is ending.
    private var resident: Launcher?

    /// Every copy has one; the gate decides only whether it has ports.
    let updater: Updater
    /// Nil when the gate lets this copy through nowhere.
    let ports: UpdatePorts?
    let engine = InMemoryUpdateEngine()
    let connection = InMemoryConnection()
    let deadline = InMemoryCheckDeadline()

    init(mac: World, placement: Placement, running: RunningBuild, attached: [Trackpad], log: EffectLog) {
        self.mac = mac
        copies.log = log
        installer.log = log
        engine.log = log
        startAtLogin = mac.startAtLogin(placement: placement)
        hardware = InMemoryTrackpads(attached: attached)
        let engine = self.engine
        let connection = self.connection
        let deadline = self.deadline
        ports = UpdatableCopy(
            placement: placement, developerIDSigned: running.developerIDSigned, canReplaceItself: running.canWrite
        ).map { UpdatePorts($0, engine: engine, connection: connection, deadline: deadline) }
        updater = Updater(version: running.version, store: mac.freshStore(), ports: ports)
        lifecycle = Lifecycle(
            placement: placement, copies: copies, installer: installer, startAtLogin: startAtLogin,
            makeResident: { [unowned self] in makeResident() }, updater: updater)
        copies.lifecycle = lifecycle
        engine.onDelivered = { [unowned self] in record(afterDelivery: true) }
        connection.onDelivered = { [unowned self] in record(afterDelivery: true) }
        deadline.onDelivered = { [unowned self] in record(afterDelivery: true) }
    }

    private func makeResident() -> Launcher {
        residentsBuilt += 1
        let launcher = Launcher(
            hardware: hardware, preferences: preferences, permissions: mac.permissions, system: system,
            catalog: mac.catalog, scanner: InMemoryAppScanner(catalog: mac.catalog), store: mac.freshStore(),
            startAtLogin: startAtLogin)
        resident = launcher
        return launcher
    }

    private func record(afterDelivery: Bool = false) {
        history.append(Published(
            window: window, card: card, isAutomaticUpdatesOn: updater.isAutomaticUpdatesOn, button: updater.checkButton,
            alert: updater.alert, afterDelivery: afterDelivery))
    }

    var launcher: Launcher { resident! }
    var window: Launcher.Window { resident?.window ?? .closed }

    func launch(_ opening: Opening, diskImageToEject: DiskImage? = nil) {
        lifecycle.launched(Launch(opening: opening, diskImageToEject: diskImageToEject))
        record()
    }

    func setAutomaticUpdates(on: Bool) {
        updater.setAutomaticUpdates(on: on)
        record()
    }

    func checkForUpdates() {
        updater.checkForUpdates()
        record()
    }

    /// Answers the alert that shows.
    func answer(_ answer: AlertAnswer) {
        updater.answer(answer, to: updater.alert!)
        record()
    }

    func openAgain(_ opening: Opening) {
        lifecycle.openedAgain(opening)
        record()
    }

    func letExit(_ id: CopyID) {
        copies.letExit(id)
        record()
    }

    func letStoppedCopiesExit() {
        copies.letStoppedCopiesExit()
        record()
    }

    func deliverExitAgain() {
        copies.deliverExitAgain()
        record()
    }

    func closeWindow() {
        launcher.closeWindow()
        record()
    }

    @discardableResult
    func shouldEnd(_ request: QuitRequest) -> Bool {
        let answer = lifecycle.shouldEnd(request)
        record()
        return answer
    }

    var moveDialog: MoveDialog? { lifecycle.moveDialog }

    func answer(_ answer: MoveAnswer) {
        lifecycle.answer(answer)
        record()
    }

    func releaseInstall(_ outcome: InstallOutcome) {
        installer.release(outcome)
        record()
    }

    func quit() {
        lifecycle.quit()
        record()
    }

    func wake() { hardware.wake() }

    /// Two fingers land and stay: the script has no lift.
    func restTwoFingers() {
        hardware.touch(TouchScript(Trackpad.macBook14.surface).land(fingers: 2).frames, on: Trackpad.macBook14.id)
    }

    func tap(
        _ fingers: Int, on trackpad: Trackpad = .macBook14, thumbAtMM thumb: (x: Double, y: Double) = (10, 10)
    ) {
        hardware.touch(TouchScript(trackpad.surface).thumb(atMM: thumb).tap(fingers: fingers).frames, on: trackpad.id)
    }

    func tap(_ fingers: Int, on trackpad: Trackpad = .macBook14, thumbIn corner: ThumbCorner) {
        tap(fingers, on: trackpad, thumbAtMM: trackpad.surface.thumbMM(in: corner))
    }
}

/// What the update rows share: the one world they all build, its engine requests, and the list's answers.
extension LifecycleWorld {
    static func updateWorld(automaticUpdates: Bool = true, corner: ThumbCorner = .topLeft) -> LifecycleWorld {
        LifecycleWorld(record: [.one: "Arc"], corner: corner, loginItemOn: true, automaticUpdates: automaticUpdates)
    }

    static let engineRequests: Set<String> = ["probe", "update", "discard", "arm restart", "arm restart with window"]

    static let offeredAlert = UpdateAlert.updateAvailable(from: "1.1.22", to: "1.1.23")

    /// How many requests every process of this world has made of its engine.
    var requests: Int { log.entries.filter { Self.engineRequests.contains($0) }.count }

    /// A release copy started by hand whose start's probe ended `.nothingNew`.
    func answeredLaunch() -> OneProcess {
        let process = launch(.byHand, running: .release)
        process.engine.push(.cycleEnded(.nothingNew))
        return process
    }
}

extension OneProcess {
    /// The running probe ends having found 1.1.23.
    func found() { engine.push(.cycleEnded(.found("1.1.23"))) }
}
