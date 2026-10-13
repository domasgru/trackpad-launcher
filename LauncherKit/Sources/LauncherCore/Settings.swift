import Foundation

/// Everything persisted besides the implicit "launched before".
///
/// Decoding rule, for every field present and future: a key missing from the record decodes as that field's default;
/// a key this build does not know is ignored; a key whose value does not decode fails the whole record.
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    /// Absent = unassigned.
    public var assignments: [Gesture: AssignedApp] = [:]
    /// Whether a gesture plays the launch animation. The key is this field's name, permanently.
    public var isLaunchAnimationOn = true

    public init() {}

    public init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handMode = try container.decodeIfPresent(HandMode.self, forKey: .handMode) ?? handMode
        assignments = try container.decodeIfPresent([Gesture: AssignedApp].self, forKey: .assignments) ?? assignments
        isLaunchAnimationOn =
            try container.decodeIfPresent(Bool.self, forKey: .isLaunchAnimationOn) ?? isLaunchAnimationOn
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
