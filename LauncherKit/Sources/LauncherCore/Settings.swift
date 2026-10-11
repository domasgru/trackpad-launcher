import Foundation

/// Everything persisted besides the implicit "launched before".
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    /// Absent = unassigned.
    public var assignments: [Gesture: AssignedApp] = [:]
    public var switcherList = SwitcherList()

    public init() {}

    /// A key added after the first release decodes as absent -> default, so a record saved by an older build keeps
    /// its assignments. Encoding stays synthesized.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handMode = try container.decode(HandMode.self, forKey: .handMode)
        assignments = try container.decode([Gesture: AssignedApp].self, forKey: .assignments)
        switcherList = try container.decodeIfPresent(SwitcherList.self, forKey: .switcherList) ?? SwitcherList()
    }
}

/// The user-ordered apps the switcher shows. No bundle ID appears twice.
public struct SwitcherList: Codable, Equatable, Sendable {
    public private(set) var apps: [AssignedApp] = []
    public var isEmpty: Bool { apps.isEmpty }

    public init() {}

    /// Appends at the end; an app already listed (same bundle ID) leaves the list unchanged.
    package mutating func append(_ app: AssignedApp) {
        guard !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        apps.append(app)
    }

    package mutating func remove(_ id: BundleID) { apps.removeAll { $0.bundleID == id } }

    /// Moves the app to `index`, clamped into the list; an app not listed leaves it unchanged.
    package mutating func move(_ id: BundleID, to index: Int) {
        guard let from = apps.firstIndex(where: { $0.bundleID == id }) else { return }
        let app = apps.remove(at: from)
        apps.insert(app, at: min(max(index, 0), apps.count))
    }

    /// A plain array; a duplicate bundle ID keeps its first copy.
    public init(from decoder: any Decoder) throws {
        let decoded = try decoder.singleValueContainer().decode([AssignedApp].self)
        decoded.forEach { append($0) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apps)
    }
}

/// One plist-encoded record under one key. Local-substitutable: tests use a throwaway `UserDefaults` suite.
@MainActor public struct SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// nil means nothing was ever saved, which is a first launch. Undecodable data loads as `Settings()`,
    /// not as a first launch, so a user who turned the login item off is never re-enrolled.
    public func load() -> Settings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return (try? PropertyListDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    public func save(_ settings: Settings) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
