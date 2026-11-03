import Foundation

/// Seconds on the clock tracks begin on: Core Animation's media time on hardware, frame times in tests.
public struct LiquidTime: Comparable, Sendable {
    public var seconds: Double

    public init(seconds: Double) { self.seconds = seconds }

    public static func < (a: Self, b: Self) -> Bool { a.seconds < b.seconds }
    public static func + (t: Self, s: Double) -> Self { Self(seconds: t.seconds + s) }
}

public enum LiquidMotion: Sendable {
    /// Render-server motion: stretch, flow, wobble, wave, end pull.
    case flowing
    /// Reduce Motion, or the glass mirror is not live: the swell jumps; nothing stretches or ripples.
    case still
}

public enum LiquidElement: Hashable, Sendable { case swell, bead(Int) }
public enum LiquidProperty: Hashable, Sendable { case centreX, width, height }

/// A channel holds at most one running track: a new track replaces the old one, which is how motion retargets.
public struct LiquidChannel: Hashable, Sendable {
    public let element: LiquidElement
    public let property: LiquidProperty

    public init(element: LiquidElement, property: LiquidProperty) {
        self.element = element
        self.property = property
    }
}

/// Additive offsets in points over the element's rest, `step` seconds apart from `begin`.
public struct LiquidTrack: Equatable, Sendable {
    public let channel: LiquidChannel
    public let begin: LiquidTime
    public let step: Double
    public let offsets: [Double]

    public init(channel: LiquidChannel, begin: LiquidTime, step: Double, offsets: [Double]) {
        self.channel = channel
        self.begin = begin
        self.step = step
        self.offsets = offsets
    }

    public var holds: Bool { offsets.last != 0 }
}

public struct IconChange: Equatable, Sendable {
    public let selected: Int
    /// 0 under `.still`.
    public let duration: Double

    public init(selected: Int, duration: Double) {
        self.selected = selected
        self.duration = duration
    }
}

/// What one `follow` asks the render server to change.
public struct LiquidFrame: Equatable, Sendable {
    /// The swell view's new frame; nil = unchanged.
    public var swell: LiquidRect?
    public var icon: IconChange?
    /// At most one per channel.
    public var tracks: [LiquidTrack]

    public init(swell: LiquidRect? = nil, icon: IconChange? = nil, tracks: [LiquidTrack] = []) {
        self.swell = swell
        self.icon = icon
        self.tracks = tracks
    }

    public static let empty = LiquidFrame()
    public var isEmpty: Bool { swell == nil && icon == nil && tracks.isEmpty }
}

public struct LiquidShape: Equatable, Sendable {
    public let band: LiquidRect
    public let beads: [LiquidRect]
    public let swell: LiquidRect

    public init(band: LiquidRect, beads: [LiquidRect], swell: LiquidRect) {
        self.band = band
        self.beads = beads
        self.swell = swell
    }
}

/// The switcher's liquid during one swipe: a band under the icons, a bead around each, and a swell around the selected
/// one. Fed the selection on every input event, it answers what the render server must change. For now the swell jumps
/// straight to the newly selected icon in both motions.
public struct Liquid: Sendable {
    private let layout: SwitcherRowLayout
    private let motion: LiquidMotion
    private var last: SwitcherSelection?

    static let flowBound = 0.2, settleBound = 1.0, endPullBound = 0.2, sampleRate = 120.0

    public init(layout: SwitcherRowLayout, motion: LiquidMotion) {
        self.layout = layout
        self.motion = motion
    }

    /// Takes the selection as an absolute target, never an increment: the caller may coalesce values.
    public mutating func follow(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        defer { last = selection }
        guard let previous = last else { return jump(to: selection.selected) }
        guard selection != previous, selection.selected != previous.selected else { return .empty }
        return jump(to: selection.selected)
    }

    /// What the render server shows at `time`.
    public func shape(at time: LiquidTime) -> LiquidShape {
        LiquidShape(
            band: layout.band, beads: (0..<layout.iconCount).map { layout.bead(at: $0) },
            swell: layout.swell(at: last?.selected ?? 0))
    }

    private func jump(to selected: Int) -> LiquidFrame {
        LiquidFrame(swell: layout.swell(at: selected), icon: IconChange(selected: selected, duration: 0))
    }
}
