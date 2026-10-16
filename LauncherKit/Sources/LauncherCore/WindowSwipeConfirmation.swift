import Foundation

/// The main-actor half of the answer to a window swipe's start, one rule both hardware adapters share, as they share
/// `TrackpadEvent.init(_:on:)`: every event reaches `onEvent` through `deliver`, and a start comes back with its answer
/// for the adapter to send to that trackpad's recognizer.
@MainActor public final class WindowSwipeConfirmation {
    /// The start being handed over now, and whether it was confirmed so far. nil outside a start's delivery.
    private var asking: (trackpad: TrackpadID, confirmed: Bool)?

    public init() {}

    /// Hands `event` to `handler`; nil drops it. For a `.windowSwipe(.began)`, returns whether `confirm(on:)` named the
    /// event's trackpad while `handler` ran, so false when it did not, or `handler` is nil. nil for every other event,
    /// which gets no reply.
    public func deliver(_ event: TrackpadEvent, to handler: (@MainActor (TrackpadEvent) -> Void)?) -> Bool? {
        guard case .windowSwipe(let start) = event, start.phase == .began else {
            handler?(event)
            return nil
        }
        let outer = asking
        asking = (start.trackpad, false)
        defer { asking = outer }
        handler?(event)
        return asking?.confirmed ?? false
    }

    /// What the adapter's `confirmWindowSwipe(on:)` calls. Counts only while `deliver` hands over a start from
    /// `trackpad`; any other call does nothing, and nothing carries over to the next start.
    public func confirm(on trackpad: TrackpadID) {
        if asking?.trackpad == trackpad { asking?.confirmed = true }
    }
}
