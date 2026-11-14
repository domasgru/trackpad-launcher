import LauncherCore

/// The manual check's limit. One `LaunchClock` per armed wait: a 1→1 opacity animation on a zero-size layer in the
/// clocks' never-ordered-in panel, whose completion is the push. Cancelling stops the clock, and its layer goes.
@MainActor public final class LayerCheckDeadline: CheckDeadline {
    public var onPassed: (@MainActor () -> Void)?
    private var clock: LaunchClock?

    public init() {}

    isolated deinit { clock?.stop() }

    public func arm(for wait: Duration) {
        let next = LaunchClock()
        let previous = clock
        clock = next
        previous?.stop()
        next.after(wait) { [weak self, weak next] in
            guard let self, let next, clock === next else { return }
            clock = nil
            next.stop()
            onPassed?()
        }
    }

    public func cancel() {
        clock?.stop()
        clock = nil
    }
}
