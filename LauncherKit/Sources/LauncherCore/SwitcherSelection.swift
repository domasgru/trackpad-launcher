import Foundation

/// Where the fingers have taken a switcher's selection along its fixed list: the nearest item; hard stops at both
/// ends; a rubber band of at most a quarter step, forgotten the moment the fingers turn back (no dead zone).
/// The selection starts on the first item.
public struct SwitcherSelection: Equatable, Sendable {
    /// At least 1: a one-item switcher rubber-bands at both ends.
    public let count: Int
    /// Travel along the slide since it began, in step millimetres (12 per item), kept within a quarter step of either
    /// end. Written only by `follow` (and tests).
    public package(set) var travelMM: Double = 0
    /// The travel `follow` was last given, so the next call can tell which way a frame moved.
    private var reportedMM: Double = 0

    package init(count: Int) {
        self.count = max(count, 1)
    }

    /// Takes the slide's absolute travel and moves by what the frame moved, keeping at most `switcherMaxOvershoot`
    /// items of it past either end. A frame that moves back towards the list from past an end restarts the travel at
    /// that end plus the frame's movement, so the selection changes the usual half item after the turn however far
    /// the fingers went past the end. Returns how many items the selection crossed: one light tick each.
    @discardableResult package mutating func follow(_ reportedMM: Double) -> Int {
        let before = selected
        let step = GestureRules.switcherStepMM
        let band = GestureRules.switcherMaxOvershoot * step
        let last = Double(count - 1) * step
        let moved = reportedMM - self.reportedMM
        self.reportedMM = reportedMM
        var next = travelMM + moved
        if travelMM < 0 && moved > 0 { next = moved }
        if travelMM > last && moved < 0 { next = last + moved }
        travelMM = min(max(next, -band), last + band)
        return abs(selected - before)
    }

    /// The nearest item, never past an end: round(travel / 12 mm), half away from zero, clamped. Changes at
    /// ±6 mm, then every 12 mm, in either direction.
    public var selected: Int {
        let steps = (travelMM / GestureRules.switcherStepMM).rounded(.toNearestOrAwayFromZero)
        return min(max(Int(steps), 0), count - 1)
    }

    /// Where the highlight rests, in items: travel / 12 mm, clamped to the list. Between two items it sits between
    /// them in proportion.
    public var position: Double { min(max(unclampedPosition, 0), Double(count - 1)) }

    /// The rubber band past an end, in items, signed, bounded below `switcherMaxStretch`:
    /// sign(excess) × max × (1 − 1 / (1 + |excess| / max)), where excess = unclamped position − position. 0 inside the list.
    public var stretch: Double {
        let excess = unclampedPosition - position
        let max = GestureRules.switcherMaxStretch
        return excess.sign == .minus ? -max * (1 - 1 / (1 + -excess / max)) : max * (1 - 1 / (1 + excess / max))
    }

    private var unclampedPosition: Double { travelMM / GestureRules.switcherStepMM }
}
