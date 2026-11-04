import Foundation
import LauncherCore

extension Uptime {
    /// The one read of the process's monotonic clock.
    static var now: Uptime { Uptime(seconds: ProcessInfo.processInfo.systemUptime) }
}
