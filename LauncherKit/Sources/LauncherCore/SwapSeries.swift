import Foundation

/// Picks the app a swap brings to the front.
struct SwapSeries {
    /// The first of the running apps, in ⌘-Tab order, that is not the frontmost app; nil when there is none.
    mutating func next(in running: RunningApps) -> AppEntry? {
        running.apps.first { $0.url != running.frontmost?.url }
    }
}
