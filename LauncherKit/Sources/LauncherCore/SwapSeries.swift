import Foundation

/// Picks the app a swap brings to the front, and remembers the last swap of the series in progress.
struct SwapSeries {
    private struct Last {
        /// The frontmost app the swap started from.
        let from: URL?
        let to: AppEntry
    }

    private var last: Last?

    /// The first of the running apps, in ⌘-Tab order, that is not the frontmost app; nil when there is none.
    /// Bringing an app to the front lands some tens of milliseconds late: while the read still shows the app the last
    /// swap started from, and the app it brought forward still runs, that swap's target stands in as the frontmost app.
    mutating func next(in running: RunningApps) -> AppEntry? {
        let inFlight = last.flatMap {
            running.frontmost?.url == $0.from && running.contains($0.to.url) ? $0.to : nil
        }
        let frontmost = inFlight ?? running.frontmost
        guard let target = running.apps.first(where: { $0.url != frontmost?.url }) else { return nil }
        last = Last(from: frontmost?.url, to: target)
        return target
    }
}
