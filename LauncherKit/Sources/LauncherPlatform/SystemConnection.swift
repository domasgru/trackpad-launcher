import LauncherCore
import Network

/// NWPathMonitor on the main queue; a reading is `path.status == .satisfied`. Exists only between `watch` and `stop`.
@MainActor public final class SystemConnection: Connection {
    public var onChange: (@MainActor (Bool) -> Void)?
    private var monitor: NWPathMonitor?

    public init() {}

    /// A cancelled monitor cannot start again, so each watch makes a fresh one.
    public func watch() {
        stop()
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            let connected = path.status == .satisfied
            MainActor.assumeIsolated {
                // A push already queued when `stop` ran finds another monitor, or none.
                guard let self, let monitor, self.monitor === monitor else { return }
                self.onChange?(connected)
            }
        }
        monitor.start(queue: .main)
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
