import AppKit
import LauncherCore
import LauncherPlatform
import LauncherUI

@main
enum TrackpadLauncherApp {
    static func main() {
        let application = NSApplication.shared
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            access: SystemAccessibilityPermission(),
            system: WorkspaceActions(),
            catalog: catalog,
            scanner: SystemAppScanner(catalog: catalog),
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher)
        launcher.start()
        withExtendedLifetime(shell) { application.run() }
    }
}
