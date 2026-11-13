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

    /// The one spelling of a running app's location, whichever API reported the path, so the frontmost app, the
    /// ⌘-Tab apps and the switcher's icon cache keys compare equal when they name the same bundle.
    public static func location(ofBundleAtPath path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}

/// What the apps on screen are right now, as one read of the system.
public struct RunningApps: Equatable, Sendable {
    /// The active app; nil when there is none or it has no bundle identifier or location. Trackpad Launcher itself while its
    /// settings window is in front; active without its Dock icon (behind the move dialog), the app that was in front
    /// before it, the most recently used ⌘-Tab app.
    public let frontmost: AppEntry?
    /// The apps ⌘-Tab shows, most recently activated first. May lack `frontmost` (a menu bar app with a window in
    /// front). Named as macOS names a running app, which can differ from the Finder name the pickers show.
    public let apps: [AppEntry]

    public init(frontmost: AppEntry?, apps: [AppEntry]) {
        self.frontmost = frontmost
        self.apps = apps
    }

    /// Whether an app at `location` is running, the active app included.
    public func contains(_ location: URL) -> Bool {
        frontmost?.url == location || apps.contains { $0.url == location }
    }
}

/// What a gesture points at: identity, plus what is needed to show it while missing and to find it fast.
public struct AssignedApp: Codable, Hashable, Sendable {
    /// Identity.
    public let bundleID: BundleID
    /// Shown greyed, marked not found.
    public let name: String
    /// Fast path only; never authoritative, never rewritten.
    public let lastKnownURL: URL

    public init(_ entry: AppEntry) {
        bundleID = entry.bundleID
        name = entry.name
        lastKnownURL = entry.url
    }
}

/// What a gesture holds: a first app and, for a split gesture, a second app that is never the first app.
///
/// Wire: the first app's `bundleID`, `name` and `lastKnownURL` at the entry's top level, as every version wrote them,
/// plus `secondApp`, holding the same three keys. A version without second apps ignores `secondApp`.
public struct Assignment: Codable, Equatable, Sendable {
    public let first: AssignedApp
    public let second: AssignedApp?

    private enum SecondKey: String, CodingKey { case secondApp }

    /// The only initializer, decoding included: a second app with the first app's bundle identifier is dropped.
    public init(first: AssignedApp, second: AssignedApp? = nil) {
        self.first = first
        self.second = second?.bundleID == first.bundleID ? nil : second
    }

    /// A new first app keeps the second app, unless it is that app, which then is the only app.
    public func settingFirst(_ app: AssignedApp) -> Assignment { Assignment(first: app, second: second) }

    /// nil when `app` is the first app, so nothing changes.
    public func settingSecond(_ app: AssignedApp) -> Assignment? {
        app.bundleID == first.bundleID ? nil : Assignment(first: first, second: app)
    }

    public var removingSecond: Assignment { Assignment(first: first) }

    public init(from decoder: any Decoder) throws {
        let first = try AssignedApp(from: decoder)
        let second = try decoder.container(keyedBy: SecondKey.self).decodeIfPresent(AssignedApp.self, forKey: .secondApp)
        self.init(first: first, second: second)
    }

    public func encode(to encoder: any Encoder) throws {
        try first.encode(to: encoder)
        var container = encoder.container(keyedBy: SecondKey.self)
        try container.encodeIfPresent(second, forKey: .secondApp)
    }
}

/// An app the user chose: from a menu, or any bundle on disk through Other…. None is `nil` where one is taken.
public enum AppChoice: Sendable {
    case app(AppEntry)
    /// From Other…; parsed by `AppCatalog.entry(at:)`, ignored if not an app with a bundle ID.
    case appBundle(at: URL)
}

public enum RowApp: Equatable, Sendable {
    case unassigned
    case present(AppEntry)
    case missing(name: String)
}

/// A gesture row as the launcher window shows it.
public struct GestureRow: Identifiable, Equatable, Sendable {
    public let gesture: Gesture
    public let apps: Apps
    public var id: Gesture { gesture }

    public enum Apps: Equatable, Sendable {
        /// "Choose app…", no plus button.
        case unassigned
        /// One line: the picker, then the plus button, missing app included.
        case one(Held)
        /// Line 1: the picker; line 2: the minus button, then the second picker.
        case two(first: Held, second: Held)
    }

    /// An app a gesture holds: on disk, or missing and shown by its saved name, greyed.
    public enum Held: Equatable, Sendable {
        case present(AppEntry)
        case missing(name: String, bundleID: BundleID)

        public var rowApp: RowApp {
            switch self {
            case .present(let entry): .present(entry)
            case .missing(let name, _): .missing(name: name)
            }
        }

        public var bundleID: BundleID {
            switch self {
            case .present(let entry): entry.bundleID
            case .missing(_, let bundleID): bundleID
            }
        }
    }

    public init(gesture: Gesture, apps: Apps) {
        self.gesture = gesture
        self.apps = apps
    }

    /// The apps the row holds, the first then the second; empty while unassigned.
    public var held: [Held] {
        switch apps {
        case .unassigned: []
        case .one(let first): [first]
        case .two(let first, let second): [first, second]
        }
    }

    /// The first picker's app.
    public var app: RowApp {
        switch apps {
        case .unassigned: .unassigned
        case .one(let first), .two(let first, _): first.rowApp
        }
    }

    /// nil while unassigned; `.add` for one app; `.app` for the second app.
    public var second: SecondSlot? {
        switch apps {
        case .unassigned: nil
        case .one: .add
        case .two(_, let second): .app(second)
        }
    }

    /// The first app, present or missing: shown disabled in the second app's menu.
    public var firstBundleID: BundleID? {
        switch apps {
        case .unassigned: nil
        case .one(let first), .two(let first, _): first.bundleID
        }
    }

    public var lineCount: Int { if case .two = apps { 2 } else { 1 } }
}

public enum SecondSlot: Equatable, Sendable {
    case add
    case app(GestureRow.Held)
}

/// The apps an app picker lists: the most recently launched first, then the rest.
public struct InstalledApps: Equatable, Sendable {
    /// Most recently launched first, at most `recentLimit`.
    public let recent: [AppEntry]
    /// Every other listed app, in Finder order.
    public let others: [AppEntry]

    private static let recentLimit = 10
    /// `recent` then `others`: every listed app in menu order.
    public var all: [AppEntry] { recent + others }

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

    /// An app picker's menu, top to bottom. The row's present app is `.current` wherever it sits; `unavailable`'s item,
    /// when listed, is `.unavailable`. They never coincide: the second picker's current app is never the first app.
    public func pickerMenu(checking app: RowApp, unavailable: BundleID? = nil) -> [PickerItem] {
        var currentID: BundleID?
        if case .present(let entry) = app { currentID = entry.bundleID }
        return menu {
            if $0.bundleID == unavailable { .unavailable } else if $0.bundleID == currentID { .current } else { .plain }
        } + [.unassigned]
    }

    private func menu(state: (AppEntry) -> AppItemState) -> [PickerItem] {
        var items = all.map { PickerItem.app($0, state: state($0)) }
        if !recent.isEmpty && !others.isEmpty { items.insert(.divider, at: recent.count) }
        if !items.isEmpty { items.append(.divider) }
        return items + [.other]
    }
}

/// One line of an app menu.
public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, state: AppItemState)
    case divider
    /// Other…
    case other
    /// None.
    case unassigned
}

public enum AppItemState: Equatable, Sendable {
    case plain
    /// Checked: the picker's current app.
    case current
    /// Shown disabled.
    case unavailable
}

/// Apps on disk. Local-substitutable: tests point it at a temp directory of fake bundles and inject what
/// LaunchServices and Spotlight know: `registeredCopies`, `lastOpened` and `displayName`.
public struct AppCatalog: Sendable {
    /// The folders `installedApps()` enumerates.
    public let roots: [URL]
    private let extras: [URL]
    private let registeredCopies: @Sendable (BundleID) -> [URL]
    private let lastOpened: @Sendable (URL) -> Date?
    private let displayName: @Sendable (URL) -> String

    /// `lastOpened`: when the app bundle at that URL was last launched, as Spotlight records it; nil when unknown.
    /// `displayName`: the name Finder shows for the bundle at that URL, with or without ".app".
    public init(
        roots: [URL], extras: [URL], registeredCopies: @escaping @Sendable (BundleID) -> [URL],
        lastOpened: @escaping @Sendable (URL) -> Date?, displayName: @escaping @Sendable (URL) -> String
    ) {
        self.roots = roots
        self.extras = extras
        self.registeredCopies = registeredCopies
        self.lastOpened = lastOpened
        self.displayName = displayName
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
        var name = displayName(url)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return AppEntry(bundleID: BundleID(rawValue: identifier), name: name, url: url)
    }

    /// Where the assigned app lives now; nil = missing.
    /// 1. lastKnownURL, if it is outside the Trash and still holds that bundle ID.
    /// 2. else the first of registeredCopies(bundleID) outside the Trash that still holds that bundle ID.
    public func locate(_ app: AssignedApp) -> AppEntry? {
        func holdsApp(_ url: URL) -> AppEntry? {
            guard !Self.isInTrash(url), let found = entry(at: url), found.bundleID == app.bundleID else { return nil }
            return found
        }
        if let found = holdsApp(app.lastKnownURL) { return found }
        return registeredCopies(app.bundleID).lazy.compactMap(holdsApp).first
    }

    /// Any path component named ".Trash" or ".Trashes".
    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}
