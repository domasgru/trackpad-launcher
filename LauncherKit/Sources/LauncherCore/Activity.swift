import Foundation

/// A system trackpad setting that binds a system action to a tap rather than a press. Gestures work with it on; with
/// the Accessibility permission, click blocking keeps a gesture's tap from also acting.
/// This enum is the table: every case supplies its key and its on value through exhaustive switches, so adding a
/// setting is one case the compiler forces through both.
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

public enum InactiveCause: Equatable, Sendable {
    case noTrackpad
}

/// One value read by the notice and the fire guard.
public enum GestureActivity: Equatable, Sendable {
    case active
    case inactive(InactiveCause)

    public var isActive: Bool { self == .active }

    /// Pure. Gestures are active whenever a trackpad is connected, whatever its settings and the Accessibility
    /// permission: without the permission a gesture's tap may also click, look up or zoom.
    public init(connected: Set<TrackpadKind>) {
        self = connected.isEmpty ? .inactive(.noTrackpad) : .active
    }
}
