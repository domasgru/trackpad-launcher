import Foundation

public struct BundleID: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// An app bundle on disk right now.
public struct AppEntry: Hashable, Sendable, Identifiable {
    public let bundleID: BundleID
    /// Display name without ".app".
    public let name: String
    public let url: URL
    public var id: BundleID { bundleID }

    public init(bundleID: BundleID, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }
}

/// What a gesture points at: identity, plus what is needed to show it while missing and to find it fast.
public struct AssignedApp: Codable, Hashable, Sendable {
    /// Identity.
    public let bundleID: BundleID
    /// Shown greyed with "not found".
    public let name: String
    /// Fast path only; never authoritative, never rewritten.
    public let lastKnownURL: URL

    public init(_ entry: AppEntry) {
        bundleID = entry.bundleID
        name = entry.name
        lastKnownURL = entry.url
    }
}

/// The app picker's three kinds of item.
public enum AppChoice: Sendable {
    case app(AppEntry)
    /// From Other…; parsed by `AppCatalog.entry(at:)`, ignored if not an app with a bundle ID.
    case appBundle(at: URL)
    /// None.
    case unassigned
}

public enum RowApp: Equatable, Sendable {
    case unassigned
    case present(AppEntry)
    case missing(name: String)
}

/// A gesture row as the launcher window shows it.
public struct GestureRow: Identifiable, Equatable, Sendable {
    public let gesture: Gesture
    public let app: RowApp
    public var id: Gesture { gesture }

    public init(gesture: Gesture, app: RowApp) {
        self.gesture = gesture
        self.app = app
    }
}

/// Apps on disk. Local-substitutable: tests point it at a temp directory of fake bundles and inject
/// `registeredCopies`.
public struct AppCatalog: Sendable {
    private let roots: [URL]
    private let extras: [URL]
    private let registeredCopies: @Sendable (BundleID) -> [URL]

    public init(roots: [URL], extras: [URL], registeredCopies: @escaping @Sendable (BundleID) -> [URL]) {
        self.roots = roots
        self.extras = extras
        self.registeredCopies = registeredCopies
    }

    /// Picker list: every .app under `roots` (recursing into folders, never into bundles, skipping hidden files)
    /// plus `extras`. One entry per bundle ID, first root wins; sorted like Finder. Enumerates on every call.
    public func installedApps() -> [AppEntry] {
        var seen = Set<BundleID>()
        var found: [AppEntry] = []
        for url in roots.flatMap(Self.appBundles(under:)) + extras {
            guard let entry = entry(at: url), seen.insert(entry.bundleID).inserted else { continue }
            found.append(entry)
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func appBundles(under directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return children.sorted { $0.path < $1.path }.flatMap { child -> [URL] in
            if child.pathExtension == "app" { return [child] }
            let values = try? child.resourceValues(forKeys: Set(keys))
            // Symlinked folders are not followed: they can loop back into the tree.
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { return [] }
            return appBundles(under: child)
        }
    }

    /// Boundary parse for Other…: the app bundle at `url`, if it has a bundle identifier.
    /// Reads Info.plist directly: `Bundle(url:)` caches by path and would hide a bundle replaced in place.
    public func entry(at url: URL) -> AppEntry? {
        guard url.pathExtension == "app",
              let data = try? Data(contentsOf: url.appending(path: "Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String, !identifier.isEmpty
        else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return AppEntry(bundleID: BundleID(rawValue: identifier), name: name, url: url)
    }

    /// Where the assigned app lives now; nil = missing.
    /// 1. lastKnownURL, if it is outside the Trash and still holds that bundle ID.
    /// 2. else the first of registeredCopies(bundleID) outside the Trash that still holds that bundle ID.
    public func locate(_ app: AssignedApp) -> AppEntry? {
        let candidates = [app.lastKnownURL] + registeredCopies(app.bundleID)
        return candidates.lazy
            .filter { !Self.isInTrash($0) }
            .compactMap { entry(at: $0) }
            .first { $0.bundleID == app.bundleID }
    }

    /// Any path component named ".Trash" or ".Trashes".
    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}
