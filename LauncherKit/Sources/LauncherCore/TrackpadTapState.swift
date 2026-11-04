import Foundation

/// What one trackpad's frames have told the click tap: its blocking level and the end of the lift window last opened
/// on it. One writer (that trackpad's frame callback); the tap's thread only reads. Clock-free: every read of the
/// process's clock is handed in.
public struct TrackpadTapState: Equatable, Sendable {
    public private(set) var level: Blocking = .none
    /// When the lift window last opened on this trackpad ends. nil: none pending.
    public private(set) var liftWindowEnd: Uptime?
    /// What `wantsTap` read on the last recognition taken, to see when it flips.
    private var wanted = false

    public init() {}

    /// Whether `wantsTap` flipped since the last recognition taken.
    public typealias WantsTapFlipped = Bool

    /// Whether taking this recognition needs the time: it opens a lift window, or a window end is pending. Pure, so the
    /// caller reads the clock only when this says so, and outside any lock.
    public func needsTime(for recognition: Recognition) -> Bool {
        recognition.opensLiftWindow || liftWindowEnd != nil
    }

    /// Takes one frame's recognition. `time` is the clock read, non-nil exactly when `needsTime(for:)` said yes, so an
    /// ordinary touch reads no clock. Returns whether `wantsTap` flipped since the last recognition, which includes the
    /// first one after a window ended: that frame is what lets the gate close.
    public mutating func take(_ recognition: Recognition, at time: Uptime?) -> WantsTapFlipped {
        level = recognition.blocking
        if recognition.opensLiftWindow, let time {
            liftWindowEnd = time + GestureRules.liftWindow
        } else if let end = liftWindowEnd, let time, time >= end {
            liftWindowEnd = nil
        }
        let wants = level.wantsTap || liftWindowEnd.map { end in time.map { $0 < end } ?? false } ?? false
        defer { wanted = wants }
        return wants != wanted
    }

    /// Strictly before the end is open.
    public func liftWindowIsOpen(at now: Uptime) -> Bool { liftWindowEnd.map { now < $0 } ?? false }

    public func wantsTap(at now: Uptime) -> Bool { level.wantsTap || liftWindowIsOpen(at: now) }

    /// The highest level of any trackpad, and whether any trackpad's lift window is open.
    public static func merged(_ states: some Sequence<TrackpadTapState>, at now: Uptime) -> (
        blocking: Blocking, liftWindowIsOpen: Bool
    ) {
        var blocking = Blocking.none
        var isOpen = false
        for state in states {
            blocking = max(blocking, state.level)
            isOpen = isOpen || state.liftWindowIsOpen(at: now)
        }
        return (blocking, isOpen)
    }
}
