import Foundation

public struct TouchID: Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

/// A contact that is DOWN in this frame; the adapter drops hovering, lingering and lifted contacts.
/// A tracked ID that reappears with `.landing` was lifted and has landed anew (the driver reused the ID);
/// an ID that appears without `.landing` is treated as landed too.
public struct Touch: Sendable {
    public enum Phase: Sendable { case landing, down }

    public let id: TouchID
    public let phase: Phase
    public let position: SurfacePoint

    public init(id: TouchID, phase: Phase, position: SurfacePoint) {
        self.id = id
        self.phase = phase
        self.position = position
    }
}

/// Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads.
public struct FrameTime: Sendable {
    public var seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func - (lhs: FrameTime, rhs: FrameTime) -> Duration {
        .seconds(lhs.seconds - rhs.seconds)
    }
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot:
/// a contact absent from `touches` has lifted. `[]` is the frame after the last lift.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
    /// Any mouse button pressed, sampled when the frame arrived: a click is not a tap.
    public let buttonDown: Bool

    public init(time: FrameTime, touches: [Touch], buttonDown: Bool) {
        self.time = time
        self.touches = touches
        self.buttonDown = buttonDown
    }
}
