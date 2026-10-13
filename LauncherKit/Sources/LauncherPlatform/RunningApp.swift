import AppKit
import LauncherCore

/// The one place a running app's `AppEntry` is built, with its location spelled by `AppEntry.location(ofBundleAtPath:)`.
enum RunningApp {
    /// nil without a bundle identifier or a location.
    static func entry(for app: NSRunningApplication) -> AppEntry? {
        guard let identifier = app.bundleIdentifier, let bundleURL = app.bundleURL else { return nil }
        return entry(bundleIdentifier: identifier, name: app.localizedName, path: bundleURL.path)
    }

    /// nil with an empty bundle identifier. Without a name, the bundle's file name stands in.
    static func entry(bundleIdentifier: String, name: String?, path: String) -> AppEntry? {
        guard !bundleIdentifier.isEmpty else { return nil }
        let url = AppEntry.location(ofBundleAtPath: path)
        return AppEntry(
            bundleID: BundleID(rawValue: bundleIdentifier),
            name: name ?? url.deletingPathExtension().lastPathComponent, url: url)
    }
}
