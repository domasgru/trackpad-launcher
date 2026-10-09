import AppKit
import LauncherCore

extension AppCatalog {
    /// The real folders and LaunchServices. Create once and share between the launcher and the shell.
    public static var system: AppCatalog {
        AppCatalog(
            roots: [
                URL(filePath: "/Applications"),
                URL(filePath: "/System/Applications"),
                FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications"),
            ],
            extras: [URL(filePath: "/System/Library/CoreServices/Finder.app")],
            registeredCopies: { NSWorkspace.shared.urlsForApplications(withBundleIdentifier: $0.rawValue) })
    }
}
