import Foundation

/// Each app's window order, by the app's location, for one launch of the app and as long as Trackpad Launcher runs;
/// never saved. Owned by `Launcher`, written only when a window swipe starts.
package struct WindowOrders: Equatable, Sendable {
    private struct Remembered: Equatable, Sendable {
        let launch: AppLaunch
        var windows: [WindowID]
    }

    /// One entry per app location: a later launch of the app replaces it, so memory is bounded by the apps window-swiped.
    private var orders: [URL: Remembered] = [:]

    package init() {}

    /// What a slide up or down shows, from the read at its start, after bringing the app's order up to date with an
    /// answered read. nil (no window swipe) for no frontmost app, for an app that did not answer, and for a count
    /// below two. Otherwise the rows: the pick in the app's order, the front window's row noted. `stillOpen` answers
    /// which of the given windows the window server still holds; it is asked only when the order remembers a window
    /// the read did not list. Idempotent: the same read twice leaves the same order and gives the same content.
    package mutating func list(
        _ read: FrontmostWindows, stillOpen: (Set<WindowID>) -> Set<WindowID>
    ) -> WindowSwitcher.Content? {
        guard case .app(let app, let launch, let windowRead) = read, let count = windowRead.windowCount else { return nil }
        if case .windows(let windows) = windowRead {
            let remembered = orders[app.url].flatMap { $0.launch == launch ? $0.windows : nil }
            orders[app.url] = Remembered(
                launch: launch, windows: Self.updated(remembered, with: windows, stillOpen: stillOpen))
        }
        guard count >= 2, case .windows(let windows) = windowRead, let order = orders[app.url]?.windows else {
            return nil
        }
        return WindowSwitcher.Content(app: app, rows: WindowSwitcher.Rows(app: app, pick: WindowPick(windows), order: order))
    }

    /// The app's order now, for this launch; [] before its first window swipe.
    package func order(of app: AppEntry) -> [WindowID] { orders[app.url]?.windows ?? [] }

    /// The order brought up to date with one answered read. Pure but for `stillOpen`, which a test passes.
    /// - No order for this launch (`nil`: the first window swipe into this launch of the app): today's list, visible front
    ///   to back, then the minimised ones.
    /// - A remembered window the read did not list stays in its place if `stillOpen` holds it (another Space, a
    ///   full-screen Space), and leaves otherwise: it closed (numbers are never reused).
    /// - Listed windows the order lacks join at its end, in the order they opened (rising window numbers), even when
    ///   nothing remembered is left (the app's windows all closed, or it had none at its first window swipe).
    package static func updated(
        _ order: [WindowID]?, with windows: AppWindows, stillOpen: (Set<WindowID>) -> Set<WindowID>
    ) -> [WindowID] {
        let listed = (windows.visible + windows.minimised).map(\.id)
        let listedSet = Set(listed)
        guard let order else { return listed }
        let missing = Set(order).subtracting(listedSet)
        let open = missing.isEmpty ? [] : stillOpen(missing)
        let kept = order.filter { listedSet.contains($0) || open.contains($0) }
        let keptSet = Set(kept)
        return kept + listed.filter { !keptSet.contains($0) }.sorted { $0.rawValue < $1.rawValue }
    }
}
