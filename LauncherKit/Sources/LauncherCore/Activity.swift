import Foundation

/// A system trackpad setting that binds an action to a tap, so gestures cannot coexist with it.
/// This enum is the table: every case supplies its key, its conflicting value and its notice text through
/// exhaustive switches, so adding a setting is one case the compiler forces through all three.
/// `allCases` order is notice order.
public enum ConflictingSetting: CaseIterable, Hashable, Sendable {
    case tapToClick
    case lookUpTapWithThreeFingers

    /// Key within each trackpad preference domain. Read only by the preferences adapter.
    package var preferenceKey: String {
        switch self {
        case .tapToClick: "Clicking"
        case .lookUpTapWithThreeFingers: "TrackpadThreeFingerTapGesture"
        }
    }

    /// True when the raw value means the action is bound to a tap. nil (key absent) is off.
    public func conflicts(rawValue: Int?) -> Bool {
        switch self {
        case .tapToClick: rawValue == 1
        case .lookUpTapWithThreeFingers: rawValue == 2
        }
    }

    /// Exactly the words the trackpad settings notice uses.
    public var noticeName: String {
        switch self {
        case .tapToClick: "Tap to click"
        case .lookUpTapWithThreeFingers: "Look up: Tap with three fingers"
        }
    }
}

/// Raw values of the table keys as read from one domain. Absent keys are absent entries.
public typealias TrackpadPreferenceValues = [ConflictingSetting: Int]

/// Non-empty, in table order. The failable init is the only constructor.
public struct ConflictingSettings: Equatable, Sendable {
    public let settings: [ConflictingSetting]

    public init?(_ settings: [ConflictingSetting]) {
        guard !settings.isEmpty else { return nil }
        self.settings = settings
    }
}

public enum InactiveCause: Equatable, Sendable {
    case noTrackpad
    case settings(ConflictingSettings)
}

/// One value read by the icon, the notice and the fire guard.
public enum GestureActivity: Equatable, Sendable {
    case active
    case inactive(InactiveCause)

    public var isActive: Bool { self == .active }

    /// Pure. No trackpad wins over settings; a setting blocks when it conflicts on any connected kind.
    public init(connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues]) {
        guard !connected.isEmpty else {
            self = .inactive(.noTrackpad)
            return
        }
        let blocking = ConflictingSetting.allCases.filter { setting in
            connected.contains { kind in setting.conflicts(rawValue: values[kind]?[setting]) }
        }
        self = ConflictingSettings(blocking).map { .inactive(.settings($0)) } ?? .active
    }
}
