import Foundation

/// The phase of one Dock swipe event: the system's own trackpad swipe between desktops or full-screen apps, or into
/// Mission Control and App Exposé. Parsed in the tap; no event-system type crosses.
public enum DockSwipePhase: Equatable, Sendable { case mayBegin, began, changed, ended, cancelled }

public enum DockSwipeVerdict: Equatable, Sendable { case pass, drop }

/// Dock swipe blocking for one event stream, as a pure state machine. Like `ScrollFilter`, it knows no clock and no
/// device; `trackpadBlocking` is the merged level's `blocksDockSwipes`, read when the event arrives.
/// A Dock swipe is judged once, on its opening event, and kept whole: dropping one already under way could leave the
/// Dock stranded between two desktops. So a swipe first seen mid-way always passes.
public struct DockSwipeFilter: Sendable {
    public init() {}

    public mutating func decide(_ phase: DockSwipePhase, trackpadBlocking: Bool) -> DockSwipeVerdict {
        let verdict: DockSwipeVerdict
        if let current {
            verdict = current
        } else if phase == .mayBegin || phase == .began {
            verdict = trackpadBlocking ? .drop : .pass
        } else {
            verdict = .pass
        }
        current = phase == .ended || phase == .cancelled ? nil : verdict
        return verdict
    }

    /// The system disabled the tap; events may have passed unseen. Forget the swipe in progress (under-blocking).
    public mutating func forgetSwipe() { current = nil }

    /// A dropped swipe is being held back until its end.
    package var isDropping: Bool { current == .drop }

    /// Keeps a dropped swipe; forgets a passing one (a missed `ended` must not pass the next swipe under the flag).
    /// TODO(D2): if real Dock swipes send `mayBegin`, take the scroll's hint so a `began` after a no-warning open passes.
    public mutating func resume() {
        if current == .pass { current = nil }
    }

    /// The verdict of the Dock swipe in progress; nil between swipes.
    private var current: DockSwipeVerdict?
}
