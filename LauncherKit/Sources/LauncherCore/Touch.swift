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
    /// nil: no press matters to this tap.
    public let press: Press?

    public init(time: FrameTime, touches: [Touch], press: Press?) {
        self.time = time
        self.touches = touches
        self.press = press
    }

    /// A pressed button, as it matters to a tap.
    public enum Press: Equatable, Sendable {
        /// macOS delivered this press to apps as a click (any pointing device). It cancels a tap.
        case click
        /// The click filter is withholding this press from apps. It is part of the tap.
        case blocked

        /// The one precedence rule, used by both hardware adapters. `holding` is the click filter's summary, nil when
        /// no filter is live (no tap, no permission). A withheld press is `.blocked` whatever the button state reads;
        /// a passed press is `.click` while the button is still down (so a release the tap missed heals on the next
        /// frame); a press the filter has not seen yet is nothing (it reads `.click` once the tap passes it, or
        /// `.blocked` once it drops it). Without a filter the button state alone decides.
        public init?(holding: ClickFilter.Holding?, buttonDown: Bool) {
            switch holding {
            case .withheld:
                self = .blocked
            case .passed:
                guard buttonDown else { return nil }
                self = .click
            case .nothing:
                return nil
            case nil:
                guard buttonDown else { return nil }
                self = .click
            }
        }
    }
}

