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
        handMode: HandMode = .right, loginItemOn: Bool = false
    ) {
        mac = World(apps: apps, accessGranted: accessGranted)
        if let record {
            var settings = Settings()
            settings.handMode = handMode
            for (gesture, name) in record { settings.assignments[gesture] = AssignedApp(mac.app(name)) }
            mac.freshStore().save(settings)
        }
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
        placement: Placement = .installed
    ) -> OneProcess {
        let process = OneProcess(mac: mac, placement: placement, log: log)
        process.installer.onEffect = { [unowned self] in snapshots.append(snapshot()) }
        process.installer.onInstalled = { [unowned self] in installedAt = snapshots.count }
        process.copies.listed = others
        process.copies.alreadyExited = Set(alreadyExited.map(\.id))
        processes.append(process)
        process.launch(opening)
        return process
    }

    /// macOS at login: it starts a process, silently, only while the login item is on.
    func login(others: [RunningCopy] = []) -> OneProcess? {
        loginItem.isOn ? launch(.atLogin, others: others) : nil
    }
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
    /// The window after each intent, in order.
    private(set) var history: [Launcher.Window] = []
    /// Kept apart from `lifecycle.launcher`, which is nil once the process is ending.
    private var resident: Launcher?

    init(mac: World, placement: Placement, log: EffectLog) {
        self.mac = mac
        copies.log = log
        installer.log = log
        startAtLogin = mac.startAtLogin(placement: placement)
        hardware = InMemoryTrackpads(attached: [.macBook14])
        lifecycle = Lifecycle(
            placement: placement, copies: copies, installer: installer, startAtLogin: startAtLogin,
            makeResident: { [unowned self] in makeResident() })
        copies.lifecycle = lifecycle
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

    var launcher: Launcher { resident! }
    var window: Launcher.Window { resident?.window ?? .closed }

    func launch(_ opening: Opening) {
        lifecycle.launched(Launch(opening: opening))
        history.append(window)
    }

    func openAgain(_ opening: Opening) {
        lifecycle.openedAgain(opening)
        history.append(window)
    }

    func letExit(_ id: CopyID) {
        copies.letExit(id)
        history.append(window)
    }

    func letStoppedCopiesExit() {
        copies.letStoppedCopiesExit()
        history.append(window)
    }

    func deliverExitAgain() {
        copies.deliverExitAgain()
        history.append(window)
    }

    func closeWindow() {
        launcher.closeWindow()
        history.append(window)
    }

    @discardableResult
    func shouldEnd(_ request: QuitRequest) -> Bool {
        let answer = lifecycle.shouldEnd(request)
        history.append(window)
        return answer
    }

    var moveDialog: MoveDialog? { lifecycle.moveDialog }

    func answer(_ answer: MoveAnswer) {
        lifecycle.answer(answer)
        history.append(window)
    }

    func releaseInstall(_ outcome: InstallOutcome) {
        installer.release(outcome)
        history.append(window)
    }

    func quit() {
        lifecycle.quit()
        history.append(window)
    }

    func tap(_ fingers: Int, thumbAtMM thumb: (x: Double, y: Double) = (10, 10)) {
        hardware.touch(
            TouchScript(Trackpad.macBook14.surface).thumb(atMM: thumb).tap(fingers: fingers).frames,
            on: Trackpad.macBook14.id)
    }
}
