import Foundation

/// One press: its button and its `kCGMouseEventNumber`, which the press's down and up share.
public struct PressID: Hashable, Sendable {
    /// 0 left, 1 right, 2+ other.
    public let button: Int
    public let number: Int64

    public init(button: Int, number: Int64) {
        self.button = button
        self.number = number
    }
}

/// Everything the click tap is ever told about, parsed. The tap's mask admits nothing else.
public enum PointerEvent: Equatable, Sendable {
    case press(PressID)
    case release(PressID)
    /// The pointer moved with `button` held.
    case drag(button: Int)
    /// A Force Touch pressure or stage change.
    case pressure
}

public enum PointerVerdict: Equatable, Sendable {
    case pass
    case drop
    /// Delivered as a plain pointer move: the pointer keeps moving, and no app sees a drag whose press it never got.
    case passAsMove
}

/// Click blocking for one event stream, as a pure state machine. One filter per click tap, fed every event in order.
/// It knows no clock and no device. `trackpadBlocking` is "some running trackpad's latest
/// `Recognition.blocksClicks` is true", read when the event arrives.
public struct ClickFilter: Sendable {
    /// What a frame needs to know about the press in progress. `.withheld` wins when buttons disagree.
    public enum Holding: Equatable, Sendable { case nothing, withheld, passed }

    public init() {}

    public mutating func decide(_ event: PointerEvent, trackpadBlocking: Bool) -> PointerVerdict {
        switch event {
        case .press(let press):
            // A new press of a button ends any stale one.
            held[press.button] = trackpadBlocking ? .withheld(press) : .passed(press)
            return trackpadBlocking ? .drop : .pass
        case .release(let press):
            // That button is up, whatever came before. The press is blocked or passed whole: the flag is ignored.
            defer { held[press.button] = nil }
            return held[press.button] == .withheld(press) ? .drop : .pass
        case .drag(let button):
            if case .withheld = held[button] { return .passAsMove }
            return .pass
        case .pressure:
            // A Force Click's stages belong to its press.
            return holding == .withheld ? .drop : .pass
        }
    }

    /// Read by the frame thread when it samples a press: `.withheld` from a dropped press until its release, else
    /// `.passed` from a passed press until its release, else `.nothing`.
    public var holding: Holding {
        var result = Holding.nothing
        for entry in held.values {
            switch entry {
            case .withheld: return .withheld
            case .passed: result = .passed
            }
        }
        return result
    }

    /// The system disabled the tap, and releases may have passed meanwhile. Forget every held press.
    public mutating func forgetHeldPresses() { held = [:] }

    private enum Held: Equatable {
        case withheld(PressID)
        case passed(PressID)
    }

    private var held: [Int: Held] = [:]
}
