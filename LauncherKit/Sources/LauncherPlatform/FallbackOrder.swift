import Foundation

/// The order of running apps when the LaunchServices order is missing.
enum FallbackOrder {
    /// The recently activated apps still running, most recent first, then the rest by launch date; an app without
    /// one goes last, in its given order.
    static func pids(running: [(pid: Int32, launched: Date?)], recency: [Int32]) -> [Int32] {
        let alive = Set(running.map(\.pid))
        var seen = Set<Int32>()
        let recent = recency.filter { alive.contains($0) && seen.insert($0).inserted }
        let rest = running.filter { !seen.contains($0.pid) }
        let dated = rest.compactMap { app in app.launched.map { (app.pid, $0) } }.sorted { $0.1 < $1.1 }.map(\.0)
        let undated = rest.filter { $0.launched == nil }.map(\.pid)
        return recent + dated + undated
    }
}
