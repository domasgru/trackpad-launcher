import Foundation

/// The two gesture event types a Dock swipe may arrive as; each has its own filter.
public enum DockSwipeStream: Hashable, Sendable { case gesture, dockControl }

/// Everything the click tap is told about, parsed. No event-system type crosses.
public enum TapEvent: Equatable, Sendable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    /// The system's own trackpad swipe between desktops, or into Mission Control or App Exposé, on its way to the
    /// Dock. Every other gesture event (pinch, rotate, an app's swipe) parses as nothing and passes untouched.
    case dockSwipe(DockSwipePhase, DockSwipeStream)

    /// Presses and releases ride the press port; drags, pressure, scrolls and Dock swipes ride the gated port.
    public var ridesGatedPort: Bool {
        switch self {
        case .pointer(.press), .pointer(.release): false
        case .pointer(.drag), .pointer(.pressure), .scroll, .dockSwipe: true
        }
    }
}

public enum TapVerdict: Equatable, Sendable {
    case pointer(PointerVerdict)
    case scroll(ScrollVerdict)
    case dockSwipe(DockSwipeVerdict)
}

/// What to do to the gated port now.
public enum GateChange: Equatable, Sendable { case open, close }

public struct TapDecision: Equatable, Sendable {
    public let verdict: TapVerdict
    /// nil: leave the gated port as it is. Applied before the verdict returns to the window server.
    public let gate: GateChange?

    public init(verdict: TapVerdict, gate: GateChange?) {
        self.verdict = verdict
        self.gate = gate
    }
}

/// The trackpads as the tap's thread reads them when it acts.
public struct TapContext: Equatable, Sendable {
    /// The highest level of any running trackpad.
    public let blocking: Blocking
    /// Whether a scroll gesture may be under way that the gated port was never sent. Read only when the gate opens.
    public let scrollMayBeUnderWay: Bool

    public init(blocking: Blocking, scrollMayBeUnderWay: Bool) {
        self.blocking = blocking
        self.scrollMayBeUnderWay = scrollMayBeUnderWay
    }

    /// The real tap's view: it cannot see what it was not sent, so it takes fingers down beside a thumb (the openings
    /// with no warning frame) as "a scroll may be under way". The in-memory adapter knows what it withheld instead.
    public static func estimated(from blocking: Blocking) -> TapContext {
        TapContext(blocking: blocking, scrollMayBeUnderWay: blocking >= .dockSwipes)
    }
}
