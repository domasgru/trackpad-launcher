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

/// One swell edge: a leg is a Hermite approach from (x, v) to (target, arrival), then a damped sine around the target,
/// windowed to end at the target `settleBound` after the curve's start. A curve may hold its first leg's target until
/// a given time and then run a second leg back to a rest, the whole still ending `settleBound` after `start`. Flow,
/// finger follow, spring-back and end pull are parameter choices of it.
struct EdgeCurve: Sendable {
    private struct Leg {
        var begin = 0.0, from = 0.0, fromVelocity = 0.0, target = 0.0, arrival = 0.0, approach = 0.0

        func value(at s: Double, omega: Double, damping: Double) -> Double {
            if s >= Liquid.settleBound { return target }
            if from == target && fromVelocity == 0 && arrival == 0 { return target }
            let u = s - begin
            if u <= 0 { return from }
            if u < approach {
                let tau = u / approach
                let h00 = (2 * tau - 3) * tau * tau + 1, h10 = ((tau - 2) * tau + 1) * tau
                let h01 = (3 - 2 * tau) * tau * tau, h11 = (tau - 1) * tau * tau
                return h00 * from + h10 * approach * fromVelocity + h01 * target + h11 * approach * arrival
            }
            return target + tail(after: u - approach, omega: omega, damping: damping).value
        }

        func velocity(at s: Double, omega: Double, damping: Double) -> Double {
            if s >= Liquid.settleBound { return 0 }
            if from == target && fromVelocity == 0 && arrival == 0 { return 0 }
            let u = s - begin
            if u <= 0 { return fromVelocity }
            if u < approach {
                let tau = u / approach
                let d00 = 6 * tau * tau - 6 * tau, d10 = 3 * tau * tau - 4 * tau + 1
                let d01 = 6 * tau - 6 * tau * tau, d11 = 3 * tau * tau - 2 * tau
                return (d00 * from + d10 * approach * fromVelocity + d01 * target + d11 * approach * arrival) / approach
            }
            return tail(after: u - approach, omega: omega, damping: damping).slope
        }

        /// The damped sine's offset from the target and its slope, `u` seconds after the approach, under a window
        /// that is 1 with zero slope at the start and 0 at the end.
        private func tail(after u: Double, omega: Double, damping: Double) -> (value: Double, slope: Double) {
            let wd = omega * (1 - damping * damping).squareRoot()
            guard wd > 0, arrival != 0 else { return (0, 0) }
            let span = Liquid.settleBound - begin - approach
            let x = u / span
            let window = 1 - (3 - 2 * x) * x * x
            let windowSlope = -(6 * x - 6 * x * x) / span
            let decay = exp(-damping * omega * u), sine = sin(wd * u), cosine = cos(wd * u)
            let amplitude = arrival / wd
            let value = amplitude * decay * sine * window
            let slope = amplitude * ((-damping * omega * sine + wd * cosine) * decay * window + decay * sine * windowSlope)
            return (value, slope)
        }
    }

    private var start = LiquidTime(seconds: -.infinity)
    private var first = Leg()
    private var second: Leg?
    private var bounds: ClosedRange<Double> = -.infinity ... .infinity
    private let omega: Double, damping: Double, limit: Double

    /// At rest on `rest`. `wobble` is the most the tail may stray from the target.
    init(rest: Double, wobble: Double, hertz: Double, damping: Double) {
        first.target = rest
        first.from = rest
        limit = max(wobble, 0)
        omega = 2 * .pi * max(hertz, 0)
        self.damping = min(max(damping, 0), 0.95)
    }

    private var dampedOmega: Double { omega * (1 - damping * damping).squareRoot() }

    private func leg(at s: Double) -> Leg {
        if let second, s >= second.begin { return second }
        return first
    }

    func value(at t: LiquidTime) -> Double {
        let s = t.seconds - start.seconds
        return min(max(leg(at: s).value(at: s, omega: omega, damping: damping), bounds.lowerBound), bounds.upperBound)
    }

    func velocity(at t: LiquidTime) -> Double {
        let s = t.seconds - start.seconds
        let leg = leg(at: s)
        let raw = leg.value(at: s, omega: omega, damping: damping)
        guard bounds.contains(raw) else { return 0 }
        return leg.velocity(at: s, omega: omega, damping: damping)
    }

    /// Restarts from the curve's own value and velocity at `t`, so nothing kinks and nothing queues. The value never
    /// leaves `bounds`, wobble and Hermite overshoot included.
    mutating func retarget(
        to target: Double, arriving: Double, over approach: Double, at t: LiquidTime,
        within bounds: ClosedRange<Double> = -.infinity ... .infinity
    ) {
        let x = value(at: t), v = velocity(at: t)
        start = t
        self.bounds = bounds
        second = nil
        let ceiling = limit * dampedOmega
        first = Leg(
            begin: 0, from: x, fromVelocity: v, target: target, arrival: min(max(arriving, -ceiling), ceiling),
            approach: min(max(approach, 0), Liquid.settleBound / 2))
    }

    /// After the first leg has held its target until `hold` seconds past `start`, springs back to `rest` over
    /// `approach`, arriving at the wobble bound towards the rest, so the rest is crossed and the tail wobbles.
    mutating func springBack(to rest: Double, after hold: Double, over approach: Double) {
        let begin = min(max(hold, first.approach), Liquid.settleBound / 2)
        let ceiling = limit * dampedOmega
        let inward: Double = rest < first.target ? -1 : 1
        second = Leg(
            begin: begin, from: first.target, fromVelocity: 0, target: rest, arrival: inward * ceiling,
            approach: min(max(approach, 0), Liquid.settleBound / 4))
        first.arrival = 0
    }
}

/// The switcher's liquid during one swipe: a band under the icons, a bead around each, and a swell around the selected
/// one. Fed the selection on every input event, it answers what the render server must change. Under `.flowing` the
/// swell's two edges flow to the newly selected icon and wobble to rest, lean towards the fingers between changes and
/// pull past the ends, and the fingers' movement sends a wave of bead heights through the band, all staged whole as
/// sampled tracks; under `.still` the swell jumps.
public struct Liquid: Sendable {
    private let layout: SwitcherRowLayout
    private let motion: LiquidMotion
    private var last: SwitcherSelection?
    private var lastTime = LiquidTime(seconds: 0)
    private var left: EdgeCurve
    private var right: EdgeCurve
    /// Where each edge was last sent: the finger velocity is how fast this moves.
    private var leftTarget = 0.0, rightTarget = 0.0
    /// The edge was last sent out past an end, so a return to its rest springs back instead of following.
    private var leftPulled = false, rightPulled = false
    /// When each edge's flow is due to arrive: a later retarget may not make it arrive sooner.
    private var leftDue = -Double.infinity, rightDue = -Double.infinity
    private var flowDirection = 1.0
    private var waves: WaveTrain

    static let flowBound = 0.2, settleBound = 1.0, endPullBound = 0.2, sampleRate = 120.0
    /// The shortest time between two events that the finger velocity is estimated over.
    private static let velocityFloor = 0.008

    public init(layout: SwitcherRowLayout, motion: LiquidMotion) {
        self.layout = layout
        self.motion = motion
        (left, right) = Self.edges(resting: layout.swell(at: 0), layout: layout)
        waves = WaveTrain(layout: layout)
    }

    private static func edges(resting rest: LiquidRect, layout: SwitcherRowLayout) -> (EdgeCurve, EdgeCurve) {
        let look = layout.look
        func edge(_ x: Double) -> EdgeCurve {
            EdgeCurve(rest: x, wobble: look.wobble * layout.scale, hertz: look.wobbleHz, damping: look.wobbleDamping)
        }
        return (edge(rest.minX), edge(rest.maxX))
    }

    /// Takes the selection as an absolute target, never an increment: the caller may coalesce values.
    ///
    /// The first call returns the settled opening: the swell's rest, the icon at once, no tracks. Later calls return
    /// only what changed. On a selection change, that is the swell's new rest and the growing icon. They also return
    /// the tracks that replace their channels' running ones, each starting where and as fast as its channel is at
    /// `time`. The frame is empty when `selection` equals the last one fed: a repeated call, and resting fingers.
    /// `SwitcherSelection`'s `==` includes the travel last reported, so every move is a new value, even a push against
    /// the clamp past an end, which re-pulls the swell. Under `.still`, every call that keeps `selected` is empty.
    public mutating func follow(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        defer { last = selection }
        guard let previous = last else {
            let rest = layout.swell(at: selection.selected)
            (left, right) = Self.edges(resting: rest, layout: layout)
            (leftTarget, rightTarget, lastTime) = (rest.minX, rest.maxX, time)
            waves.open(at: selection.position, time: time)
            return jump(to: selection.selected)
        }
        guard selection != previous else { return .empty }
        switch motion {
        case .still:
            return selection.selected == previous.selected ? .empty : jump(to: selection.selected)
        case .flowing:
            if selection.selected == previous.selected { return stretch(selection, at: time) }
            return flow(from: previous.selected, to: selection, at: time)
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
        let beads = (0..<layout.iconCount).map { index in
            let bead = layout.bead(at: index), grown = waves.offset(bead: index, at: time)
            return LiquidRect(minX: bead.minX, minY: bead.minY - grown / 2, width: bead.width, height: bead.height + grown)
        }
        return LiquidShape(band: layout.band, beads: beads, swell: swell)
    }

    private func jump(to selected: Int) -> LiquidFrame {
        LiquidFrame(swell: layout.swell(at: selected), icon: IconChange(selected: selected, duration: 0))
    }

    private var settleTime: Double { max(min(layout.look.flowTime, Self.flowBound), 1 / Self.sampleRate) }
    private var followTime: Double { max(layout.look.followTime, 0.001) }

    /// The approach for an edge retargeted at `time` while its flow may still be under way.
    private func approach(due: Double, at time: LiquidTime) -> Double { max(followTime, due - time.seconds) }

    /// An edge still inside its flow keeps arriving with the flow's push past the target, so the wobble survives the
    /// retargets of a moving finger; after the deadline it arrives with its target's velocity.
    private func arrival(due: Double, targetVelocity: Double, at time: LiquidTime) -> Double {
        time.seconds < due ? flowDirection * .infinity : targetVelocity
    }

    /// Where each edge of the swell around `selection.selected` is headed inside the row: the edge on the lean's side
    /// reaches towards the fingers, the other stays on its rest.
    private func targets(for selection: SwitcherSelection, rest: LiquidRect) -> (left: Double, right: Double) {
        let lean = selection.position - Double(selection.selected)
        let reach = layout.look.reach * lean * layout.pitch
        return (rest.minX + (lean < 0 ? reach : 0), rest.maxX + (lean > 0 ? reach : 0))
    }

    private mutating func flow(from previous: Int, to selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        let look = layout.look
        let step = 1 / Self.sampleRate
        let selected = selection.selected
        let rest = layout.swell(at: selected)
        let goal = targets(for: selection, rest: rest)
        let direction: Double = selected > previous ? 1 : -1
        let total = settleTime
        let lead = max(min(max(look.leadShare, 0), 1) * total, step)
        func pull(_ edge: inout EdgeCurve, to target: Double, over approach: Double) {
            let distance = abs(target - edge.value(at: time))
            edge.retarget(to: target, arriving: direction * 1.5 * distance / approach, over: approach, at: time)
        }
        pull(&left, to: goal.left, over: direction > 0 ? total : lead)
        pull(&right, to: goal.right, over: direction > 0 ? lead : total)
        (leftTarget, rightTarget, lastTime) = (goal.left, goal.right, time)
        (leftPulled, rightPulled) = (false, false)
        flowDirection = direction
        (leftDue, rightDue) = (time.seconds + (direction > 0 ? total : lead), time.seconds + (direction > 0 ? lead : total))
        return LiquidFrame(
            swell: rest, icon: IconChange(selected: selected, duration: lead),
            tracks: tracks(over: rest, from: time) + waveTracks(for: selection, at: time))
    }

    /// The selection moved without changing: the swell leans towards the fingers, or is pulled past an end.
    private mutating func stretch(_ selection: SwitcherSelection, at time: LiquidTime) -> LiquidFrame {
        let selected = selection.selected
        let rest = layout.swell(at: selected)
        let pastLast = selection.travelMM - Double(selection.count - 1) * GestureRules.switcherStepMM
        var waving = false
        if selected == selection.count - 1 && pastLast > 0 {
            endPull(outerRight: true, by: pastLast, rest: rest, at: time)
        } else if selected == 0 && selection.travelMM < 0 {
            endPull(outerRight: false, by: -selection.travelMM, rest: rest, at: time)
        } else {
            lean(to: targets(for: selection, rest: rest), rest: rest, at: time)
            waving = true
        }
        lastTime = time
        return LiquidFrame(
            tracks: tracks(over: rest, from: time) + (waving ? waveTracks(for: selection, at: time) : []))
    }

    /// The beads' height tracks when the fingers' movement sends a crest through the band, else none.
    private mutating func waveTracks(for selection: SwitcherSelection, at time: LiquidTime) -> [LiquidTrack] {
        waves.emit(at: selection.position, time: time) ? waves.tracks(from: time) : []
    }

    /// Both edges glide to their targets over `followTime`, each arriving with its target's velocity. An edge coming
    /// back from a pull springs back instead.
    private mutating func lean(to goal: (left: Double, right: Double), rest: LiquidRect, at time: LiquidTime) {
        let dt = max(time.seconds - lastTime.seconds, Self.velocityFloor)
        let bound = pullBounds(rest: rest)
        if leftPulled && abs(left.value(at: time) - goal.left) > 1e-6 {
            left.retarget(to: goal.left, arriving: .infinity, over: settleTime, at: time, within: bound.left)
        } else {
            left.retarget(to: goal.left, arriving: arrival(due: leftDue, targetVelocity: (goal.left - leftTarget) / dt, at: time), over: approach(due: leftDue, at: time), at: time)
        }
        if rightPulled && abs(right.value(at: time) - goal.right) > 1e-6 {
            right.retarget(to: goal.right, arriving: -.infinity, over: settleTime, at: time, within: bound.right)
        } else {
            right.retarget(to: goal.right, arriving: arrival(due: rightDue, targetVelocity: (goal.right - rightTarget) / dt, at: time), over: approach(due: rightDue, at: time), at: time)
        }
        (leftTarget, rightTarget) = goal
        (leftPulled, rightPulled) = (false, false)
    }

    /// The most the outer edges may be beyond their rests.
    private var pullLimit: Double {
        max(min(layout.look.endPull * layout.scale, Self.endPullBound * layout.pitch), 0)
    }

    private func pullBounds(rest: LiquidRect) -> (left: ClosedRange<Double>, right: ClosedRange<Double>) {
        (rest.minX - pullLimit ... .infinity, -.infinity ... rest.maxX + pullLimit)
    }

    /// Only the outer edge moves, out to a share of `pullLimit` that grows with the overshoot `o` (in step-mm); it
    /// stays there for `pullHold` and then springs back to its rest. The inner edge stays on its rest.
    private mutating func endPull(outerRight: Bool, by o: Double, rest: LiquidRect, at time: LiquidTime) {
        let look = layout.look
        let reach = pullLimit * (1 - exp(-o / max(look.endPullMM, 0.001)))
        let hold = min(max(look.pullHold, 0), Self.settleBound / 2)
        let bound = pullBounds(rest: rest)
        let leftApproach = approach(due: leftDue, at: time), rightApproach = approach(due: rightDue, at: time)
        if outerRight {
            right.retarget(to: rest.maxX + reach, arriving: 0, over: rightApproach, at: time, within: bound.right)
            right.springBack(to: rest.maxX, after: hold, over: settleTime)
            left.retarget(to: rest.minX, arriving: 0, over: leftApproach, at: time)
        } else {
            left.retarget(to: rest.minX - reach, arriving: 0, over: leftApproach, at: time, within: bound.left)
            left.springBack(to: rest.minX, after: hold, over: settleTime)
            right.retarget(to: rest.maxX, arriving: 0, over: rightApproach, at: time)
        }
        (leftTarget, rightTarget) = (rest.minX, rest.maxX)
        (leftPulled, rightPulled) = (!outerRight, outerRight)
    }

    /// The swell's height when it is `stretch` wider than its rest: thinner as it stretches, never below the grown
    /// icon body plus a margin.
    private func height(stretchedBy stretch: Double, rest: LiquidRect) -> Double {
        let floor = layout.selectedIconBody + 4 * layout.scale
        return min(max(rest.height - layout.look.thinning * max(0, stretch), floor), rest.height)
    }

    /// Both edges' offsets from the rest, from `time` until they end, `sampleRate` samples a second. A curve that ends
    /// off the rest (a held lean) leaves its last offset non-zero, which the track then holds.
    private func tracks(over rest: LiquidRect, from time: LiquidTime) -> [LiquidTrack] {
        let step = 1 / Self.sampleRate
        let count = Int(Self.settleBound * Self.sampleRate) + 1
        var centre: [Double] = [], width: [Double] = [], height: [Double] = []
        for index in 0..<count {
            let at = index < count - 1 ? time + Double(index) * step : time + 2 * Self.settleBound
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
