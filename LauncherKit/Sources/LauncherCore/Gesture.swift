import Foundation

/// One of the five launcher tap gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1, two, three, four, five

    /// nil outside 1...5: a six-finger tap is not a gesture.
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }

    public var fingerCount: Int { rawValue }
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

/// A swipe's progress as the frame thread reports it.
public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved sideways past 3 mm. Travel is 0 here.
    case began
    /// Sideways movement of the two fingers' midpoint since `began`, in trackpad millimetres, positive to the right in
    /// both hand modes. Absolute, not a delta. Sent only when it changed.
    case moved(travelMM: Double)
    /// The first of the two fingers lifted: the selection opens.
    case ended
    /// A finger landed outside the anchor corner, or a press reached apps: nothing opens.
    case cancelled
}

/// A swipe phase on a specific trackpad (its haptics play there; its switcher belongs to it).
public struct SwipeEvent: Equatable, Sendable {
    public let phase: SwipePhase
    public let trackpad: TrackpadID

    public init(phase: SwipePhase, trackpad: TrackpadID) {
        self.phase = phase
        self.trackpad = trackpad
    }
}

/// A swap that fired on a specific trackpad (its haptic plays there).
public struct SwapEvent: Equatable, Sendable {
    /// True for the first swap under a pair of resting fingers.
    public let startsSeries: Bool
    public let trackpad: TrackpadID

    public init(startsSeries: Bool, trackpad: TrackpadID) {
        self.startsSeries = startsSeries
        self.trackpad = trackpad
    }
}
