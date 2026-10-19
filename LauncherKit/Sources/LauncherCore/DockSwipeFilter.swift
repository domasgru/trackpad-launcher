import Foundation

/// The phase of one Dock swipe event: the system's own trackpad swipe between desktops or full-screen apps, or into
/// Mission Control and App Exposé. Parsed in the tap; no event-system type crosses.
public enum DockSwipePhase: Equatable, Sendable { case mayBegin, began, changed, ended, cancelled }

public enum DockSwipeVerdict: Equatable, Sendable { case pass, drop }

/// Dock swipe blocking for one event stream, as a pure state machine. Like `ScrollFilter`, it knows no clock and no
/// device; `trackpadBlocking` is the merged level's `blocksDockSwipes`, read when the event arrives.
/// A Dock swipe is kept whole once dropped. Each opening event (`mayBegin`, `began`) is judged on its own and only a
/// drop is remembered: a passed `mayBegin` commits nothing, since nothing visible has happened at `mayBegin`, and a
/// `began` under blocking drops the rest of the swipe. A swipe first seen mid-way, or one that passed its `began`,
/// passes whole, since dropping one already under way could leave the Dock stranded between two desktops.
public struct DockSwipeFilter: Sendable {
    public init() {}

    public mutating func decide(_ phase: DockSwipePhase, trackpadBlocking: Bool) -> DockSwipeVerdict {
        let ends = phase == .ended || phase == .cancelled
        if isDropping {
            if ends { isDropping = false }
            return .drop
        }
        guard (phase == .mayBegin || phase == .began) && trackpadBlocking else { return .pass }
        isDropping = true
        return .drop
    }

    /// The system disabled the tap; events may have passed unseen. Forget the swipe in progress (under-blocking).
    public mutating func forgetSwipe() { isDropping = false }

    /// A dropped swipe is being held back until its end.
    package private(set) var isDropping = false
}
