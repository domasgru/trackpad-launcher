import Foundation

/// The switcher during one swipe. The row is fixed when the swipe begins; everything else follows the travel.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app first when the list lacks it, then the list's present apps in list order.
    /// Always at least two icons.
    public let row: [AppEntry]
    /// The frontmost app's index: the selection at travel 0.
    public let home: Int
    /// Sideways midpoint travel since the swipe began, in trackpad millimetres. Written only by `Launcher` (and tests).
    public package(set) var travelMM: Double = 0
    /// Reported travel the switcher has dropped past its ends: `follow` keeps `travelMM` = reported − this.
    private var droppedMM: Double = 0
    public let trackpad: TrackpadID

    /// nil when the row would hold nothing besides the frontmost app. `listed`: the list's present apps, in order.
    package init?(listed: [AppEntry], frontmost: AppEntry, trackpad: TrackpadID) {
        let holdsFrontmost = listed.contains { $0.bundleID == frontmost.bundleID }
        let row = holdsFrontmost ? listed : [frontmost] + listed
        guard row.count >= 2, let home = row.firstIndex(where: { $0.bundleID == frontmost.bundleID }) else {
            return nil
        }
        self.row = row
        self.home = home
        self.trackpad = trackpad
    }

    /// The nearest icon, never past an end: home + round(travel / 12 mm), half away from zero, clamped. Changes at
    /// ±6 mm, then every 12 mm, in either direction.
    public var selected: Int {
        let steps = (travelMM / GestureRules.switcherStepMM).rounded(.toNearestOrAwayFromZero)
        return min(max(home + Int(steps), 0), row.count - 1)
    }

    public var selectedApp: AppEntry { row[selected] }

    /// Takes the swipe's reported travel, keeping at most `switcherMaxOvershoot` icons of it past either end and
    /// dropping the rest, so turning back moves the selection at once however far the fingers went.
    package mutating func follow(_ reportedMM: Double) {
        let step = GestureRules.switcherStepMM
        let overshoot = GestureRules.switcherMaxOvershoot * step
        let lowest = -Double(home) * step - overshoot
        let highest = Double(row.count - 1 - home) * step + overshoot
        let travel = reportedMM - droppedMM
        let kept = min(max(travel, lowest), highest)
        droppedMM += travel - kept
        travelMM = kept
    }

    /// Lifting here is a silent no-op.
    public var selectsFrontmost: Bool { selected == home }

    /// Where the highlight rests, in icons: home + travel / 12 mm, clamped to the row. Between two icons it sits
    /// between them in proportion.
    public var position: Double { min(max(unclampedPosition, 0), Double(row.count - 1)) }

    /// The rubber band past an end, in icons, signed, bounded below `switcherMaxStretch`:
    /// sign(excess) × max × (1 − 1 / (1 + |excess| / max)), where excess = unclamped position − position. 0 inside the row.
    public var stretch: Double {
        let excess = unclampedPosition - position
        let max = GestureRules.switcherMaxStretch
        return excess.sign == .minus ? -max * (1 - 1 / (1 + -excess / max)) : max * (1 - 1 / (1 + excess / max))
    }

    private var unclampedPosition: Double { Double(home) + travelMM / GestureRules.switcherStepMM }
}
