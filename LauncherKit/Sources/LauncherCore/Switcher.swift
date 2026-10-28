import Foundation

/// The switcher during one swipe. The row is fixed when the swipe begins; the selection follows the travel.
/// The selection starts on the first icon: the frontmost app, or the most recently used running app when no app is
/// active.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app, if any, then the running apps in ⌘-Tab order without the copy at the frontmost
    /// app's location and without any app whose bundle identifier is left out, at most `switcherMaxApps` in all.
    /// Always holds an app besides the frontmost one.
    public let row: [AppEntry]
    /// Whether the first icon is the frontmost app, so lifting on it changes nothing.
    private let startsOnFrontmost: Bool
    /// Where the swipe has taken the selection along the row. Written only by `Launcher` (and tests).
    public package(set) var selection: SwitcherSelection
    public let trackpad: TrackpadID

    /// nil when the row would hold nothing besides the frontmost app. Identity for the frontmost app's copy is the
    /// running copy's location: two copies of one bundle at two locations are two icons. Leaving out goes by bundle
    /// identifier instead: every running copy of a left-out bundle is dropped, and the frontmost app is never left out.
    package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, trackpad: TrackpadID) {
        let others = running.filter { $0.url != frontmost?.url && !leavingOut.contains($0.bundleID) }
        guard !others.isEmpty else { return nil }
        row = Array(((frontmost.map { [$0] } ?? []) + others).prefix(GestureRules.switcherMaxApps))
        startsOnFrontmost = frontmost != nil
        selection = SwitcherSelection(count: row.count)
        self.trackpad = trackpad
    }

    public var selectedApp: AppEntry { row[selection.selected] }

    /// Lifting here is a silent no-op.
    public var selectsFrontmost: Bool { startsOnFrontmost && selection.selected == 0 }
}
