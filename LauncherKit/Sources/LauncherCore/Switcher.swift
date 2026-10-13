import Foundation

/// The switcher during one swipe. The row is fixed when the swipe begins; everything else follows the travel.
/// The selection starts on the first icon: the frontmost app, or the most recently used running app when no frontmost
/// app can be read, as while Trackpad Launcher itself is active.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app, if any, then the running apps in ⌘-Tab order without the copy at the frontmost
    /// app's location, at most `switcherMaxApps` in all. Always holds an app besides the frontmost one.
    public let row: [AppEntry]
    /// Whether the first icon is the frontmost app, so lifting on it changes nothing.
    private let startsOnFrontmost: Bool
    /// Sideways midpoint travel since the swipe began, in trackpad millimetres. Written only by `Launcher` (and tests).
    public package(set) var travelMM: Double = 0
    /// The travel `follow` was last given, so the next call can tell which way a frame moved.
    private var reportedMM: Double = 0
    public let trackpad: TrackpadID

    /// nil when the row would hold nothing besides the frontmost app. Identity is the running copy's location: two
    /// copies of one bundle at two locations are two icons.
    package init?(frontmost: AppEntry?, running: [AppEntry], trackpad: TrackpadID) {
        let others = running.filter { $0.url != frontmost?.url }
        guard !others.isEmpty else { return nil }
        row = Array(((frontmost.map { [$0] } ?? []) + others).prefix(GestureRules.switcherMaxApps))
        startsOnFrontmost = frontmost != nil
        self.trackpad = trackpad
    }

    /// The nearest icon, never past an end: round(travel / 12 mm), half away from zero, clamped. Changes at
    /// ±6 mm, then every 12 mm, in either direction.
    public var selected: Int {
        let steps = (travelMM / GestureRules.switcherStepMM).rounded(.toNearestOrAwayFromZero)
        return min(max(Int(steps), 0), row.count - 1)
    }

    public var selectedApp: AppEntry { row[selected] }

    /// Takes the swipe's reported travel and moves by what the frame moved, keeping at most `switcherMaxOvershoot`
    /// icons of it past either end. A frame that moves back towards the row from past an end restarts the travel at
    /// that end plus the frame's movement, so the selection changes the usual half icon after the turn however far
    /// the fingers went past the end.
    package mutating func follow(_ reportedMM: Double) {
        let step = GestureRules.switcherStepMM
        let band = GestureRules.switcherMaxOvershoot * step
        let last = Double(row.count - 1) * step
        let moved = reportedMM - self.reportedMM
        self.reportedMM = reportedMM
        var next = travelMM + moved
        if travelMM < 0 && moved > 0 { next = moved }
        if travelMM > last && moved < 0 { next = last + moved }
        travelMM = min(max(next, -band), last + band)
    }

    /// Lifting here is a silent no-op.
    public var selectsFrontmost: Bool { startsOnFrontmost && selected == 0 }

    /// Where the highlight rests, in icons: travel / 12 mm, clamped to the row. Between two icons it sits between
    /// them in proportion.
    public var position: Double { min(max(unclampedPosition, 0), Double(row.count - 1)) }

    /// The rubber band past an end, in icons, signed, bounded below `switcherMaxStretch`:
    /// sign(excess) × max × (1 − 1 / (1 + |excess| / max)), where excess = unclamped position − position. 0 inside the row.
    public var stretch: Double {
        let excess = unclampedPosition - position
        let max = GestureRules.switcherMaxStretch
        return excess.sign == .minus ? -max * (1 - 1 / (1 + -excess / max)) : max * (1 - 1 / (1 + excess / max))
    }

    private var unclampedPosition: Double { travelMM / GestureRules.switcherStepMM }
}
