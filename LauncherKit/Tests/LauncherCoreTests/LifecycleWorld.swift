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

    /// `record` is what an earlier run saved: these apps on these gestures. nil is a Mac that holds no settings.
    init(
        apps: [String] = ["Arc", "Notes"], accessGranted: Bool = true, record: [Gesture: String]? = nil,
        loginItemOn: Bool = false
    ) {
        mac = World(apps: apps, accessGranted: accessGranted)
        if let record {
            var settings = Settings()
            for (gesture, name) in record { settings.assignments[gesture] = AssignedApp(mac.app(name)) }
            mac.freshStore().save(settings)
        }
        loginItem.isOn = loginItemOn
    }

    /// A process started by hand or at login, as `applicationDidFinishLaunching` hands it over.
    @discardableResult
    func launch(_ opening: Opening) -> OneProcess {
        let process = OneProcess(mac: mac)
        processes.append(process)
        process.launch(opening)
        return process
    }

    /// macOS at login: it starts a process, silently, only while the login item is on.
    func login() -> OneProcess? {
        loginItem.isOn ? launch(.atLogin) : nil
    }
}

@MainActor final class OneProcess {
    private let mac: World
    private(set) var lifecycle: Lifecycle!
    let copies = InMemoryRunningCopies()
    let hardware: InMemoryTrackpads
    let preferences = InMemoryTrackpadPreferences()
    let system = RecordingSystemActions()
    private(set) var residentsBuilt = 0
    /// The window after each intent, in order.
    private(set) var history: [Launcher.Window] = []
    /// Kept apart from `lifecycle.launcher`, which is nil once the process is ending.
    private var resident: Launcher?

    init(mac: World) {
        self.mac = mac
        hardware = InMemoryTrackpads(attached: [.macBook14])
        lifecycle = Lifecycle(copies: copies, makeResident: { [unowned self] in makeResident() })
        copies.lifecycle = lifecycle
    }

    private func makeResident() -> Launcher {
        residentsBuilt += 1
        let launcher = Launcher(
            hardware: hardware, preferences: preferences, permissions: mac.permissions, system: system,
            catalog: mac.catalog, scanner: InMemoryAppScanner(catalog: mac.catalog), store: mac.freshStore(),
            startAtLogin: StartAtLogin(item: mac.loginItem))
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

    func quit() {
        lifecycle.quit()
        history.append(window)
    }

    func tap(_ fingers: Int) {
        hardware.touch(
            TouchScript(Trackpad.macBook14.surface).thumb(atMM: (10, 10)).tap(fingers: fingers).frames,
            on: Trackpad.macBook14.id)
    }
}
