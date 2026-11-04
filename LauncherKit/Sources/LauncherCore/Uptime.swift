import Foundation

/// Seconds on the process's own monotonic clock (the system uptime of Foundation's process info). Not `FrameTime`, which is the
/// multitouch driver's clock: the two cannot be compared by mistake. Core defines the value and never reads the clock.
public struct Uptime: Comparable, Sendable {
    public var seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func < (lhs: Uptime, rhs: Uptime) -> Bool { lhs.seconds < rhs.seconds }

    public static func + (lhs: Uptime, rhs: Duration) -> Uptime {
        Uptime(seconds: lhs.seconds + rhs / .seconds(1))
    }
}
