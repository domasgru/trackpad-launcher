import Foundation

/// A scroll event as suppression needs it. Parsed in the tap; no event-system type crosses.
public enum ScrollEvent: Equatable, Sendable {
    /// Line-based, no phases: a scroll wheel. Never suppressed.
    case wheel
    /// Fingers on a surface: a trackpad or a Magic Mouse, which the system reports alike.
    case fingers(Phase)
    /// Coasting after the fingers lifted.
    case momentum(Momentum)
    /// Continuous without phases: decided alone, on the flag.
    case unphased

    public enum Phase: Equatable, Sendable { case mayBegin, began, changed, ended, cancelled }
    public enum Momentum: Equatable, Sendable { case began, changed, ended }
}

public enum ScrollVerdict: Equatable, Sendable {
    case pass
    case drop
    /// Delivered with every delta zeroed: the app's gesture ends cleanly and nothing moves.
    case passStill
}

/// Scroll suppression for one event stream, as a pure state machine. Like `ClickFilter`, it knows no clock and no
/// device; `trackpadBlocking` is the same merged flag, read when the event arrives. One per tap, fed in order.
public struct ScrollFilter: Sendable {
    public init() {}

    public mutating func decide(_ event: ScrollEvent, trackpadBlocking: Bool) -> ScrollVerdict {
        switch event {
        case .wheel:
            return .pass
        case .unphased:
            return trackpadBlocking ? .drop : .pass
        case .fingers(let phase):
            let treatment: Treatment
            switch stage {
            case .touching(let current):
                // Never relaxes inside a gesture: a passing one that meets blocking mid-way is stilled.
                treatment = current == .passed && trackpadBlocking ? .stilled : current
            case .coasting, nil:
                // A gesture first seen mid-way was already seen by apps: only stilling keeps it whole.
                if !trackpadBlocking {
                    treatment = .passed
                } else {
                    treatment = phase == .mayBegin || phase == .began ? .dropped : .stilled
                }
            }
            stage = phase == .ended || phase == .cancelled ? .coasting(treatment) : .touching(treatment)
            return treatment.verdict
        case .momentum(let momentum):
            // Momentum inherits its gesture's treatment and never escalates; unknown coasting is never interrupted.
            let treatment: Treatment
            switch stage {
            case .coasting(let current), .touching(let current): treatment = current
            case nil: return .pass
            }
            if momentum == .ended { stage = nil }
            return treatment.verdict
        }
    }

    /// The system disabled the tap; events may have passed unseen. Forget the gesture in progress (under-blocking).
    public mutating func forgetGesture() { stage = nil }

    private enum Treatment: Sendable {
        case passed, dropped, stilled

        var verdict: ScrollVerdict {
            switch self {
            case .passed: .pass
            case .dropped: .drop
            case .stilled: .passStill
            }
        }
    }

    private enum Stage: Sendable { case touching(Treatment), coasting(Treatment) }

    private var stage: Stage?
}
