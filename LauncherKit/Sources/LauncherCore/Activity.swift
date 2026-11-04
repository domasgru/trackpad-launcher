import Foundation

/// A system trackpad setting that binds a system action to a tap rather than a press. Gestures coexist with it only
/// through click blocking, which needs the Accessibility permission.
/// This enum is the table: every case supplies its key, its on value and its notice text through
/// exhaustive switches, so adding a setting is one case the compiler forces through all three.
/// `allCases` order is notice order.
public enum TapBoundSetting: CaseIterable, Hashable, Sendable {
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
    public func isOn(rawValue: Int?) -> Bool {
        switch self {
        case .tapToClick: rawValue == 1
        case .lookUpTapWithThreeFingers: rawValue == 2
        }
    }

    /// Exactly the words the tap-bound settings notice uses.
    var noticeName: String {
        switch self {
        case .tapToClick: "Tap to click"
        case .lookUpTapWithThreeFingers: "Look up: Tap with three fingers"
        }
    }

    /// The settings that are on for any connected trackpad, in table order.
    public static func on(
        connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues]
    ) -> [TapBoundSetting] {
        allCases.filter { setting in
            connected.contains { kind in setting.isOn(rawValue: values[kind]?[setting]) }
        }
    }
}

/// Raw values of the table keys as read from one domain. Absent keys are absent entries.
public typealias TrackpadPreferenceValues = [TapBoundSetting: Int]

/// Non-empty, in table order. The failable init is the only constructor.
public struct TapBoundSettings: Equatable, Sendable {
    public let settings: [TapBoundSetting]

    public init?(_ settings: [TapBoundSetting]) {
        guard !settings.isEmpty else { return nil }
        self.settings = settings
    }
}

public enum InactiveCause: Equatable, Sendable {
    case noTrackpad
    case settingsNeedAccessibility(TapBoundSettings)
}

/// One value read by the notice and the fire guard.
public enum GestureActivity: Equatable, Sendable {
    case active
    case inactive(InactiveCause)

    public var isActive: Bool { self == .active }

    /// Pure. No trackpad wins over settings; a tap-bound setting on for any connected kind makes gestures inactive
    /// only while the Accessibility permission is missing.
    public init(
        connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues], accessGranted: Bool
    ) {
        guard !connected.isEmpty else {
            self = .inactive(.noTrackpad)
            return
        }
        guard !accessGranted else {
            self = .active
            return
        }
        let on = TapBoundSetting.on(connected: connected, values: values)
        self = TapBoundSettings(on).map { .inactive(.settingsNeedAccessibility($0)) } ?? .active
    }
}

/// The button a notice carries.
public enum NoticeButton: Equatable, Sendable {
    case openAccessibilitySettings
}

/// What the settings window says while gestures are inactive.
public struct InactiveNotice: Equatable, Sendable {
    public let message: String
    public let button: NoticeButton?

    public init(message: String, button: NoticeButton?) {
        self.message = message
        self.button = button
    }

    init(_ cause: InactiveCause) {
        message = Copy.inactiveNotice(for: cause)
        switch cause {
        case .noTrackpad: button = nil
        case .settingsNeedAccessibility: button = .openAccessibilitySettings
        }
    }
}
