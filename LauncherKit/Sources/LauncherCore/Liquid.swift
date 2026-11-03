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

/// One swell edge: a Hermite approach from (x, v) to (target, arrival) over `approach`, then a damped sine around the
/// target, windowed to end at the target `settleBound` after `start`.
struct EdgeCurve: Sendable {
    private var start = LiquidTime(seconds: -.infinity)
    private var from = 0.0, fromVelocity = 0.0, target = 0.0, arrival = 0.0, approach = 0.0
    private let omega: Double, damping: Double, limit: Double

    /// At rest on `rest`. `wobble` is the most the tail may stray from the target.
    init(rest: Double, wobble: Double, hertz: Double, damping: Double) {
        target = rest
        from = rest
        limit = max(wobble, 0)
        omega = 2 * .pi * max(hertz, 0)
        self.damping = min(max(damping, 0), 0.95)
    }

    private var dampedOmega: Double { omega * (1 - damping * damping).squareRoot() }

    func value(at t: LiquidTime) -> Double {
        let s = t.seconds - start.seconds
        if s >= Liquid.settleBound { return target }
        if s <= 0 { return from }
        if s < approach {
            let tau = s / approach
            let h00 = (2 * tau - 3) * tau * tau + 1, h10 = ((tau - 2) * tau + 1) * tau
            let h01 = (3 - 2 * tau) * tau * tau, h11 = (tau - 1) * tau * tau
            return h00 * from + h10 * approach * fromVelocity + h01 * target + h11 * approach * arrival
        }
        return target + tail(after: s - approach).value
    }

    func velocity(at t: LiquidTime) -> Double {
        let s = t.seconds - start.seconds
        if s >= Liquid.settleBound { return 0 }
        if s <= 0 { return fromVelocity }
        if s < approach {
            let tau = s / approach
            let d00 = 6 * tau * tau - 6 * tau, d10 = 3 * tau * tau - 4 * tau + 1
            let d01 = 6 * tau - 6 * tau * tau, d11 = 3 * tau * tau - 2 * tau
            return (d00 * from + d10 * approach * fromVelocity + d01 * target + d11 * approach * arrival) / approach
        }
        return tail(after: s - approach).slope
    }

    /// Restarts from the curve's own value and velocity at `t`, so nothing kinks and nothing queues.
    mutating func retarget(to target: Double, arriving: Double, over approach: Double, at t: LiquidTime) {
        let x = value(at: t), v = velocity(at: t)
        from = x
        fromVelocity = v
        start = t
        self.target = target
        let ceiling = limit * dampedOmega
        arrival = min(max(arriving, -ceiling), ceiling)
        self.approach = min(max(approach, 0), Liquid.settleBound / 2)
    }

    /// The damped sine's offset from the target and its slope, `u` seconds after the approach, under a window that is
    /// 1 with zero slope at the start and 0 at the end.
    private func tail(after u: Double) -> (value: Double, slope: Double) {
        let span = Liquid.settleBound - approach
        let x = u / span
        let window = 1 - (3 - 2 * x) * x * x
        let windowSlope = -(6 * x - 6 * x * x) / span
        let wd = dampedOmega
        guard wd > 0 else { return (0, 0) }
        let decay = exp(-damping * omega * u), sine = sin(wd * u), cosine = cos(wd * u)
        let amplitude = arrival / wd
        let value = amplitude * decay * sine * window
        let slope = amplitude * ((-damping * omega * sine + wd * cosine) * decay * window + decay * sine * windowSlope)
        return (value, slope)
    }
}

/// The switcher's liquid during one swipe: a band under the icons, a bead around each, and a swell around the selected
/// one. Fed the selection on every input event, it answers what the render server must change. Under `.flowing` the
/// swell's two edges flow to the newly selected icon and wobble to rest, staged whole as sampled tracks; under `.still`
/// the swell jumps.
public struct Liquid: Sendable {
    private let layout: SwitcherRowLayout
    private let motion: LiquidMotion
    private var last: SwitcherSelection?
    private var left: EdgeCurve
    private var right: EdgeCurve

    static let flowBound = 0.2, settleBound = 1.0, endPullBound = 0.2, sampleRate = 120.0

    public init(layout: SwitcherRowLayout, motion: LiquidMotion) {
        self.layout = layout
        self.motion = motion
        (left, right) = Self.edges(resting: layout.swell(at: 0), layout: layout)
    }

    private static func edges(resting rest: LiquidRect, layout: SwitcherRowLayout) -> (EdgeCurve, EdgeCurve) {
        let look = layout.look
        func edge(_ x: Double) -> EdgeCurve {
            EdgeCurve(rest: x, wobble: look.wobble * layout.scale, hertz: look.wobbleHz, damping: look.wobbleDamping)
        }
        return (edge(rest.minX), edge(rest.maxX))
    }

    /// Takes the selection as an absolute target, never an increment: the caller may coalesce values.
    public mutating func follow(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        defer { last = selection }
        guard let previous = last else {
            (left, right) = Self.edges(resting: layout.swell(at: selection.selected), layout: layout)
            return jump(to: selection.selected)
        }
        guard selection != previous, selection.selected != previous.selected else { return .empty }
        switch motion {
        case .still: return jump(to: selection.selected)
        case .flowing: return flow(from: previous.selected, to: selection.selected, at: time)
        }
    }

    /// What the render server shows at `time`: valid at or after the last call that returned a non-empty frame.
    public func shape(at time: LiquidTime) -> LiquidShape {
        let rest = layout.swell(at: last?.selected ?? 0)
        var swell = rest
        if motion == .flowing {
            let l = left.value(at: time), r = right.value(at: time)
            let h = height(stretchedBy: (r - rest.maxX) - (l - rest.minX), rest: rest)
            swell = LiquidRect(minX: l, minY: rest.minY + (rest.height - h) / 2, width: r - l, height: h)
        }
        return LiquidShape(band: layout.band, beads: (0..<layout.iconCount).map { layout.bead(at: $0) }, swell: swell)
    }

    private func jump(to selected: Int) -> LiquidFrame {
        LiquidFrame(swell: layout.swell(at: selected), icon: IconChange(selected: selected, duration: 0))
    }

    private mutating func flow(from previous: Int, to selected: Int, at time: LiquidTime) -> LiquidFrame {
        let look = layout.look
        let step = 1 / Self.sampleRate
        let rest = layout.swell(at: selected)
        let direction: Double = selected > previous ? 1 : -1
        let total = max(min(look.flowTime, Self.flowBound), step)
        let lead = max(min(max(look.leadShare, 0), 1) * total, step)
        func pull(_ edge: inout EdgeCurve, to target: Double, over approach: Double) {
            let distance = abs(target - edge.value(at: time))
            edge.retarget(to: target, arriving: direction * 1.5 * distance / approach, over: approach, at: time)
        }
        pull(&left, to: rest.minX, over: direction > 0 ? total : lead)
        pull(&right, to: rest.maxX, over: direction > 0 ? lead : total)
        return LiquidFrame(
            swell: rest, icon: IconChange(selected: selected, duration: lead), tracks: tracks(over: rest, from: time))
    }

    /// The swell's height when it is `stretch` wider than its rest: thinner as it stretches, never below the grown
    /// icon body plus a margin.
    private func height(stretchedBy stretch: Double, rest: LiquidRect) -> Double {
        let floor = layout.selectedIconBody + 4 * layout.scale
        return min(max(rest.height - layout.look.thinning * max(0, stretch), floor), rest.height)
    }

    /// Both edges' offsets from the new rest, from `time` until they end, `sampleRate` samples a second.
    private func tracks(over rest: LiquidRect, from time: LiquidTime) -> [LiquidTrack] {
        let step = 1 / Self.sampleRate
        let count = Int(Self.settleBound * Self.sampleRate) + 1
        var centre: [Double] = [], width: [Double] = [], height: [Double] = []
        for index in 0..<count {
            guard index < count - 1 else {
                centre.append(0)
                width.append(0)
                height.append(0)
                break
            }
            let at = time + Double(index) * step
            let l = left.value(at: at) - rest.minX, r = right.value(at: at) - rest.maxX
            centre.append((l + r) / 2)
            width.append(r - l)
            height.append(self.height(stretchedBy: r - l, rest: rest) - rest.height)
        }
        func track(_ property: LiquidProperty, _ offsets: [Double]) -> LiquidTrack {
            LiquidTrack(
                channel: LiquidChannel(element: .swell, property: property), begin: time, step: step, offsets: offsets)
        }
        return [track(.centreX, centre), track(.width, width), track(.height, height)]
    }
}
