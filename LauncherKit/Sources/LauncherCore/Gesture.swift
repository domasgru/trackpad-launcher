import Foundation

/// One of the four launcher gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Comparable {
    case one = 1, two, three, four

    /// nil outside 1...4: a five-finger tap is not a gesture.
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }

    public var fingerCount: Int { rawValue }

    public static func < (a: Gesture, b: Gesture) -> Bool { a.rawValue < b.rawValue }
}

/// A gesture that fired on a specific trackpad (feedback plays on that one).
public struct GestureEvent: Equatable, Sendable {
    public let gesture: Gesture
    public let trackpad: TrackpadID

    public init(gesture: Gesture, trackpad: TrackpadID) {
        self.gesture = gesture
        self.trackpad = trackpad
    }
}
