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

/// The apps an app picker lists: the most recently launched first, then the rest.
public struct InstalledApps: Equatable, Sendable {
    /// Most recently launched first, at most `recentLimit`.
    public let recent: [AppEntry]
    /// Every other listed app, in Finder order.
    public let others: [AppEntry]

    public static let recentLimit = 10
    public static let empty = InstalledApps(recent: [], others: [])

    init(recent: [AppEntry], others: [AppEntry]) {
        self.recent = recent
        self.others = others
    }

    /// `entries` are in Finder order. An entry without a date is never recent; there is no age limit.
    init(_ entries: [AppEntry], lastOpened: [BundleID: Date]) {
        let dated = entries.enumerated().compactMap { index, entry in
            lastOpened[entry.bundleID].map { (index: index, entry: entry, date: $0) }
        }
        let newestFirst = dated.sorted { $0.date != $1.date ? $0.date > $1.date : $0.index < $1.index }
        let recent = newestFirst.prefix(Self.recentLimit)
        let recentIDs = Set(recent.map(\.entry.bundleID))
        self.init(recent: recent.map(\.entry), others: entries.filter { !recentIDs.contains($0.bundleID) })
    }

    /// An app picker's menu, top to bottom. The row's present app is checked wherever it sits.
    public func pickerMenu(checking app: RowApp) -> [PickerItem] {
        var checkedID: BundleID?
        if case .present(let entry) = app { checkedID = entry.bundleID }
        var items = (recent + others).map { PickerItem.app($0, checked: $0.bundleID == checkedID) }
        if !recent.isEmpty && !others.isEmpty { items.insert(.divider, at: recent.count) }
        if !items.isEmpty { items.append(.divider) }
        return items + [.other, .unassigned]
    }
}

/// One line of an app picker's menu.
public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, checked: Bool)
    case divider
    /// Other…
    case other
    /// None.
    case unassigned
}

/// Apps on disk. Local-substitutable: tests point it at a temp directory of fake bundles and inject
/// `registeredCopies` and `lastOpened`.
public struct AppCatalog: Sendable {
    /// The folders `installedApps()` enumerates.
    public let roots: [URL]
    private let extras: [URL]
    private let registeredCopies: @Sendable (BundleID) -> [URL]
    private let lastOpened: @Sendable (URL) -> Date?

    /// `lastOpened`: when the app bundle at that URL was last launched, as Spotlight records it; nil when unknown.
    public init(
        roots: [URL], extras: [URL], registeredCopies: @escaping @Sendable (BundleID) -> [URL],
        lastOpened: @escaping @Sendable (URL) -> Date?
    ) {
        self.roots = roots
        self.extras = extras
        self.registeredCopies = registeredCopies
        self.lastOpened = lastOpened
    }

    /// Picker list: every .app under `roots` (recursing into folders, never into bundles, skipping hidden files)
    /// plus `extras`. One entry per bundle ID, first root wins; Finder order, the most recently launched split out
    /// first. Dates are read only for listed apps. Enumerates on every call.
    public func installedApps() -> InstalledApps {
        var seen = Set<BundleID>()
        var found: [AppEntry] = []
        for url in roots.flatMap(Self.appBundles(under:)) + extras {
            guard let entry = entry(at: url), seen.insert(entry.bundleID).inserted else { continue }
            found.append(entry)
        }
        found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var dates: [BundleID: Date] = [:]
        for entry in found { dates[entry.bundleID] = lastOpened(entry.url) }
        return InstalledApps(found, lastOpened: dates)
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
