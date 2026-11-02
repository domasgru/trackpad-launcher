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
        placement: Placement = .installed, running: RunningBuild = .development, diskImageToEject: DiskImage? = nil
    ) -> OneProcess {
        let process = OneProcess(mac: mac, placement: placement, running: running, log: log)
        process.installer.onEffect = { [unowned self] in snapshots.append(snapshot()) }
        process.installer.onInstalled = { [unowned self] in installedAt = snapshots.count }
        process.copies.listed = others
        process.copies.alreadyExited = Set(alreadyExited.map(\.id))
        processes.append(process)
        process.launch(opening, diskImageToEject: diskImageToEject)
        return process
    }

    /// macOS at login: it starts a process, silently, only while the login item is on.
    func login(others: [RunningCopy] = [], running: RunningBuild = .development) -> OneProcess? {
        loginItem.isOn ? launch(.atLogin, others: others, running: running) : nil
    }
}

/// What the running copy is, as the composition root would read it: a release build signed with a Developer ID at some
/// version on this Mac's macOS, or a development build. Both go through the real `InstalledRelease` gate.
enum RunningBuild {
    case release(String, macOS: String = "26.0")
    case development

    func installed(at placement: Placement) -> InstalledRelease? {
        switch self {
        case .release(let version, let macOS):
            InstalledRelease(placement: placement, developerIDSigned: true, version: version, macOS: Version(macOS)!)
        case .development:
            InstalledRelease(placement: placement, developerIDSigned: false, version: "1.0.0", macOS: Version(26, 0))
        }
    }
}

extension Release {
    /// A release that needs `macOS` or newer, with a well-formed archive.
    static func version(_ version: String, needs macOS: String = "26.0") -> Release {
        Release(
            version: Version(version)!, minimumMacOS: Version(macOS)!,
            archive: URL(string: "https://example.invalid/TrackpadLauncher-\(version)-macOS-\(macOS).aar")!,
            archiveSize: 1000)
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
    let releases: InMemoryReleaseList
    /// nil where the real gate refuses an update check: a development build, a copy outside /Applications.
    let updater: Updater?
    private(set) var residentsBuilt = 0

    /// What the settings window shows after an intent.
    struct Published: Equatable {
        let window: Launcher.Window
        let card: UpdateCard?
    }

    /// The window and the card after each intent, in order.
    private(set) var history: [Published] = []
    var windows: [Launcher.Window] { history.map(\.window) }
    var card: UpdateCard? { updater?.card }
    /// Kept apart from `lifecycle.launcher`, which is nil once the process is ending.
    private var resident: Launcher?

    init(mac: World, placement: Placement, running: RunningBuild, log: EffectLog) {
        self.mac = mac
        let releases = InMemoryReleaseList()
        self.releases = releases
        updater = running.installed(at: placement).map { Updater($0, releases: releases) }
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
            startAtLogin: startAtLogin, updater: updater)
        resident = launcher
        return launcher
    }

    private func record() { history.append(Published(window: window, card: card)) }

    /// The oldest check still open answers.
    func deliver(_ list: [Release]) {
        releases.deliver(list)
        record()
    }

    /// Fetch number `number` (1-based) answers, whatever else is open.
    func deliver(_ list: [Release], toFetch number: Int) {
        releases.deliver(list, toFetch: number)
        record()
    }

    /// The oldest check still open fails.
    func failCheck() {
        releases.fail()
        record()
    }

    var launcher: Launcher { resident! }
    var window: Launcher.Window { resident?.window ?? .closed }

    func launch(_ opening: Opening, diskImageToEject: DiskImage? = nil) {
        lifecycle.launched(Launch(opening: opening, diskImageToEject: diskImageToEject))
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

    func tap(_ fingers: Int, thumbAtMM thumb: (x: Double, y: Double) = (10, 10)) {
        hardware.touch(
            TouchScript(Trackpad.macBook14.surface).thumb(atMM: thumb).tap(fingers: fingers).frames,
            on: Trackpad.macBook14.id)
    }
}
