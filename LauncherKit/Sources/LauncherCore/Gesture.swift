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

/// What two fingers sliding under an anchored thumb start. Decided once, on the frame the farthest-moved finger passes
/// 3 mm, and held until both fingers lift.
public enum SlideKind: Hashable, Sendable {
    /// More sideways than up or down: the app switcher. Travel is positive to the right in both hand modes.
    case swipe
    /// More up or down than sideways: the window switcher. Travel is positive downwards in both hand modes.
    case windowSwipe
}

/// A swipe's or a window swipe's progress; the event case says which.
public enum SwipePhase: Equatable, Sendable {
    /// One of two fingers under an anchored thumb moved past 3 mm. Travel is 0 here: the 3 mm do not count.
    /// A window swipe's start is a question: it is a window swipe only if the model confirms it while handling this
    /// phase (`TrackpadHardware.confirmWindowSwipe(on:)`).
    case began
    /// Travel along the slide since `began`, in step millimetres (12 per item), absolute. Sent only when it changed.
    case moved(travelMM: Double)
    /// Both fingers have lifted.
    case ended
    /// A third finger landed outside the anchor corner while both were down, or a click reached apps.
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
