import AppKit
import CoreServices
import LauncherCore

extension AppCatalog {
    /// The real folders, LaunchServices and Spotlight. Create once and share between the launcher and the scanner.
    public static var system: AppCatalog {
        AppCatalog(
            roots: [
                URL(filePath: "/Applications"),
                URL(filePath: "/System/Applications"),
                FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications"),
            ],
            extras: [URL(filePath: "/System/Library/CoreServices/Finder.app")],
            registeredCopies: { NSWorkspace.shared.urlsForApplications(withBundleIdentifier: $0.rawValue) },
            lastOpened: { spotlightLastUsed($0) })
    }

    /// `kMDItemLastUsedDate` of the bundle at `url`; nil when Spotlight has none. Safe off the main actor.
    static func spotlightLastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
