import AppKit
import LauncherCore
import LauncherPlatform
import LauncherUI

@main
enum TrackpadLauncherApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}

/// The composition root and the only application delegate: it parses AppKit signals into values for `Lifecycle` and
/// builds the gesture model and its window only when `Lifecycle` asks for them.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var lifecycle: Lifecycle!
    private var shell: SettingsShell?
    private var moveDialog: MoveDialogPresenter?
    private let quitSignals = QuitSignals()
    private var event: NSAppleEventDescriptor? { NSAppleEventManager.shared().currentAppleEvent }
    #if DEBUG
    private var system: WorkspaceActions?
    private var hasShownTuner = false
    #endif

    func applicationWillFinishLaunching(_: Notification) {
        // Only the login item starts Trackpad Launcher at login.
        NSApp.disableRelaunchOnLogin()
        let location = ThisCopy.location()
        let placement = Placement(
            build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)
        let startAtLogin = StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)
        lifecycle = Lifecycle(
            placement: placement, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location),
            startAtLogin: startAtLogin, makeResident: { [unowned self] in makeResident(startAtLogin) })
        moveDialog = MoveDialogPresenter(lifecycle: lifecycle)
    }

    /// The open event exists only from here.
    func applicationDidFinishLaunching(_: Notification) {
        let launch = ThisCopy.launch(event: event, arguments: CommandLine.arguments)
        lifecycle.launched(launch)
        showAnimationTuner(for: launch.opening)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        let opening = ThisCopy.opening(of: event)
        lifecycle.openedAgain(opening)
        showAnimationTuner(for: opening)
        return false
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        lifecycle.shouldEnd(quitSignals.request(for: event)) ? .terminateNow : .terminateCancel
    }

    /// The gesture model and the window that renders it, built together, only for a copy that runs gestures. The shell
    /// comes first, so its first icon pass finishes before `Lifecycle` starts the gestures.
    private func makeResident(_ startAtLogin: StartAtLogin) -> Launcher {
        let catalog = AppCatalog.system
        let actions = WorkspaceActions()
        let launcher = Launcher(
            hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
            system: actions, catalog: catalog, scanner: SystemAppScanner(catalog: catalog),
            store: SettingsStore(defaults: .standard), startAtLogin: startAtLogin)
        shell = SettingsShell(launcher: launcher, quit: { [unowned self] in lifecycle.quit() })
        #if DEBUG
        system = actions
        #endif
        return launcher
    }

    /// Debug builds: the animation tuner opens with the first opening by hand, never at a login start.
    private func showAnimationTuner(for opening: Opening) {
        #if DEBUG
        guard opening == .byHand, !hasShownTuner else { return }
        hasShownTuner = true
        system?.showAnimationTuner()
        #endif
    }
}
