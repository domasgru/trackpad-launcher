import AppKit
import LauncherCore
import LauncherPlatform
import LauncherUI

@main
enum TrackpadLauncherApp {
    static func main() {
        let application = NSApplication.shared
        let catalog = AppCatalog.system
        let system = WorkspaceActions()
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            access: SystemAccessibilityPermission(),
            system: system,
            catalog: catalog,
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher, catalog: catalog)
        launcher.start()
        #if DEBUG
        system.showAnimationTuner()
        #endif
        withExtendedLifetime(shell) { application.run() }
    }
}
