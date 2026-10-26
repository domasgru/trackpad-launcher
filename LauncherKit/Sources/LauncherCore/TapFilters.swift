import Foundation

/// The click tap's filters and the gate over its busy event types, as one pure value. Clock-free, device-free.
/// Invariant: after every call, `gateIsOpen` == some trackpad wants the tap, or a press is withheld, or a scroll is
/// dropped or stilled (through its momentum), or a Dock swipe is dropped. It closes only when nothing is altered in
/// flight, so a press, scroll gesture or Dock swipe is never started in the app's view and then cut short, or the
/// reverse. The one exception is a system disable not yet noticed. A fresh value is closed.
public struct TapFilters: Sendable {
    public init() {}

    /// Frame threads, through the click tap's lock: the summary `TouchFrame.Press(holding:buttonDown:)` reads.
    public var holding: ClickFilter.Holding { click.holding }

    /// What this value last asked the gated port to be.
    public private(set) var gateIsOpen = false

    /// One event either port was handed, decided on the level read when it arrived.
    public mutating func decide(_ event: TapEvent, in context: TapContext) -> TapDecision {
        let was = gateIsOpen
        settle(context)
        let verdict: TapVerdict
        switch event {
        case .pointer(let pointer):
            verdict = .pointer(click.decide(
                pointer, trackpadBlocking: context.blocking.blocksClicks,
                trackpadBlocksPressDrags: context.blocking.blocksPressDrags))
        case .scroll(let scrollEvent):
            verdict = .scroll(scroll.decide(scrollEvent, trackpadBlocking: context.blocking.blocksClicks))
        case .dockSwipe(let phase, let stream):
            verdict = .dockSwipe(
                dock[stream, default: DockSwipeFilter()].decide(
                    phase, trackpadBlocking: context.blocking.blocksDockSwipes))
        }
        settle(context)
        return TapDecision(verdict: verdict, gate: change(since: was))
    }

    /// A trackpad's `wantsTap` flipped (the tap's thread was woken), or the thread's first turn. Idempotent: a second
    /// call returns nil.
    public mutating func follow(_ context: TapContext) -> GateChange? {
        let was = gateIsOpen
        settle(context)
        return change(since: was)
    }

    /// A `tapDisabledBy...` notice: the system's, or the echo of our own close. The ports' states as read now. The
    /// caller re-enables the press port whenever it read off.
    public mutating func portsWereDisabled(
        pressPortIsOn: Bool, gatedPortIsOn: Bool, in context: TapContext
    ) -> GateChange? {
        if !pressPortIsOn { click.forgetHeldPresses() }
        let gatedBySystem = gateIsOpen && !gatedPortIsOn
        if gatedBySystem {
            scroll.forgetGesture()
            dock = [:]
        }
        gateIsOpen = gatedPortIsOn
        settle(gatedBySystem ? TapContext(blocking: context.blocking, scrollMayBeUnderWay: false) : context)
        return change(since: gatedPortIsOn)
    }

    private func change(since was: Bool) -> GateChange? {
        gateIsOpen == was ? nil : (gateIsOpen ? .open : .close)
    }

    private mutating func settle(_ context: TapContext) {
        let wanted =
            context.blocking.wantsTap || click.isWithholding || scroll.isSuppressing
            || dock.values.contains { $0.isDropping }
        if wanted && !gateIsOpen {
            scroll.resume(scrollMayBeUnderWay: context.scrollMayBeUnderWay)
            gateIsOpen = true
        } else if !wanted && gateIsOpen {
            gateIsOpen = false
        }
    }

    private var click = ClickFilter()
    private var scroll = ScrollFilter()
    private var dock: [DockSwipeStream: DockSwipeFilter] = [:]
}
