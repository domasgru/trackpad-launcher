import Foundation

/// The two gesture event types a Dock swipe may arrive as; each has its own filter.
public enum DockSwipeStream: Hashable, Sendable { case gesture, dockControl }

/// The system's actions for a tap of fingers that the click tap can block besides the click: the Look up panel for a
/// tap of three and Smart zoom for a double tap of two.
public enum TapAction: Equatable, Sendable { case lookUp, smartZoom }

/// Everything the click tap is told about, parsed. No event-system type crosses.
public enum TapEvent: Equatable, Sendable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    /// The system's own trackpad swipe between desktops, or into Mission Control or App Exposé, on its way to the
    /// Dock.
    case dockSwipe(DockSwipePhase, DockSwipeStream)
    /// The system's Look up or Smart zoom, arriving as a gesture event at the lift of the fingers that made it. Every
    /// other gesture event (pinch, rotate, an app's swipe) parses as nothing and passes untouched.
    case tapAction(TapAction)

    /// Presses and releases ride the press port; drags, pressure, scrolls, Dock swipes and tap actions ride the gated port.
    public var ridesGatedPort: Bool {
        switch self {
        case .pointer(.press), .pointer(.release): false
        case .pointer(.drag), .pointer(.pressure), .scroll, .dockSwipe, .tapAction: true
        }
    }
}

public enum TapVerdict: Equatable, Sendable {
    case pointer(PointerVerdict)
    case scroll(ScrollVerdict)
    case dockSwipe(DockSwipeVerdict)
    case tapAction(TapActionVerdict)
}

public enum TapActionVerdict: Equatable, Sendable { case pass, drop }

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
    /// Whether any trackpad's lift window is open: presses are blocked when the run blocks tap clicks, and the gated
    /// port stays on. It never raises the scroll estimate or opens a closed gate by itself.
    public let liftWindowIsOpen: Bool
    /// Whether a scroll gesture may be under way that the gated port was never sent. Read only when the gate opens.
    public let scrollMayBeUnderWay: Bool

    public init(blocking: Blocking, liftWindowIsOpen: Bool, scrollMayBeUnderWay: Bool) {
        self.blocking = blocking
        self.liftWindowIsOpen = liftWindowIsOpen
        self.scrollMayBeUnderWay = scrollMayBeUnderWay
    }

    /// The real tap's view: it cannot see what it was not sent, so it takes fingers down beside a thumb (the openings
    /// with no warning frame) as "a scroll may be under way". The in-memory adapter knows what it withheld instead.
    /// A window never opens a closed gate (the lifting contact was down, so the port was already on), so the estimate
    /// comes from the level alone.
    public static func estimated(from blocking: Blocking, liftWindowIsOpen: Bool) -> TapContext {
        TapContext(blocking: blocking, liftWindowIsOpen: liftWindowIsOpen, scrollMayBeUnderWay: blocking >= .dockSwipes)
    }
}
