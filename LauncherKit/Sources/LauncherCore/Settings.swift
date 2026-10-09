import Foundation

/// Everything persisted besides the implicit "launched before".
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    /// Absent = unassigned.
    public var assignments: [Gesture: AssignedApp] = [:]

    public init() {}
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
