import Foundation
import LauncherCore

extension LiquidRect {
    func isClose(to other: LiquidRect, within tolerance: Double = 0.001) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance
            && abs(width - other.width) < tolerance && abs(height - other.height) < tolerance
    }

    func contains(_ inner: LiquidRect, within tolerance: Double = 0.001) -> Bool {
        inner.minX >= minX - tolerance && inner.maxX <= maxX + tolerance && inner.minY >= minY - tolerance
            && inner.maxY <= maxY + tolerance
    }

    func overlaps(_ other: LiquidRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }
}

/// What reaches the liquid between the model and `follow`: by default every value, once, on time. A row turns on what
/// `Observations` and the main actor can do to a value.
struct Delivery {
    /// Values (counted from 0 per swipe) that never arrive, as a coalesced observation.
    var withheld: Set<Int> = []
    /// Every value arrives twice.
    var twice = false
    /// Each value's time is delayed by a seeded 0 to 4 ms.
    var jitterSeed: UInt64?
    /// Values (counted from 0) stamped 0.5 ms after the one before.
    var squeezed: Set<Int> = []
}

/// One call to `Liquid.follow` and what it left behind.
struct LiquidCall {
    let time: LiquidTime
    let selection: SwitcherSelection
    let frame: LiquidFrame
    let liquid: Liquid
}

/// What the render server shows at an instant.
struct Played: Equatable {
    let band: LiquidRect
    let beads: [LiquidRect]
    let swell: LiquidRect
    /// Each icon's drawn scale.
    let iconScales: [Double]
}

/// Every call of one swipe, and the means to replay what its staged frames put on screen.
struct LiquidRun {
    let layout: SwitcherRowLayout
    let calls: [LiquidCall]
    /// Per channel, every track staged in call order, with the time of the call that staged it.
    private let trackLog: [LiquidChannel: [(time: LiquidTime, track: LiquidTrack)]]
    private let swellLog: [(time: LiquidTime, rest: LiquidRect)]
    private let iconLog: [(time: LiquidTime, change: IconChange)]

    init(layout: SwitcherRowLayout, calls: [LiquidCall]) {
        self.layout = layout
        self.calls = calls
        var tracks: [LiquidChannel: [(time: LiquidTime, track: LiquidTrack)]] = [:]
        for call in calls {
            for track in call.frame.tracks { tracks[track.channel, default: []].append((call.time, track)) }
        }
        trackLog = tracks
        swellLog = calls.compactMap { call in call.frame.swell.map { (call.time, $0) } }
        iconLog = calls.compactMap { call in call.frame.icon.map { (call.time, $0) } }
    }

    var opened: LiquidTime { calls[0].time }
    var last: LiquidTime { calls[calls.count - 1].time }
    /// The last call that fed a selection different from the one before it: the fingers' last movement.
    var lastMove: LiquidTime {
        Array(zip(calls, calls.dropFirst())).last { $0.selection != $1.selection }?.1.time ?? opened
    }
    var nonEmptyFrames: [LiquidFrame] { calls.map(\.frame).filter { !$0.isEmpty } }

    /// Every millisecond from the open to 2 s after the last call.
    var instants: [LiquidTime] {
        let from = Int((opened.seconds * 1000).rounded(.up)), to = Int((last.seconds * 1000).rounded(.up)) + 2000
        return (from...to).map { LiquidTime(seconds: Double($0) / 1000) }
    }

    /// How many of `log`'s entries were staged at or before `instant`.
    private func count<Entry>(in log: [Entry], time: (Entry) -> LiquidTime, through instant: LiquidTime) -> Int {
        var low = 0, high = log.count
        while low < high {
            let middle = (low + high) / 2
            if time(log[middle]) <= instant { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// By Core Animation's rules, from the staged frames alone: a swell frame is the swell's rest from its call on; an
    /// icon change runs linearly over its duration from wherever the icon was. Per channel the latest track added at
    /// or before the instant is interpolated linearly between its samples, then holds its last offset if it holds and
    /// is 0 otherwise; the offsets add to the rests.
    func played(at instant: LiquidTime) -> Played {
        let swellCount = count(in: swellLog, time: \.time, through: instant)
        let swellRest = swellCount > 0 ? swellLog[swellCount - 1].rest : layout.swell(at: 0)
        func offset(_ element: LiquidElement, _ property: LiquidProperty) -> Double {
            let channel = LiquidChannel(element: element, property: property)
            guard let log = trackLog[channel] else { return 0 }
            let latest = count(in: log, time: \.time, through: instant)
            guard latest > 0 else { return 0 }
            let track = log[latest - 1].track
            let elapsed = instant.seconds - track.begin.seconds
            let end = Double(track.offsets.count - 1) * track.step
            if elapsed >= end { return track.holds ? track.offsets[track.offsets.count - 1] : 0 }
            let position = elapsed / track.step
            let index = Int(position)
            let fraction = position - Double(index)
            return track.offsets[index] + (track.offsets[index + 1] - track.offsets[index]) * fraction
        }
        func shown(_ rest: LiquidRect, _ element: LiquidElement) -> LiquidRect {
            let centre = offset(element, .centreX), width = offset(element, .width), height = offset(element, .height)
            return LiquidRect(
                minX: rest.minX + centre - width / 2, minY: rest.minY - height / 2, width: rest.width + width,
                height: rest.height + height)
        }
        let changes = count(in: iconLog, time: \.time, through: instant)
        let scales = (0..<layout.iconCount).map { index in iconScale(index, at: instant, changes: changes) }
        return Played(
            band: layout.band, beads: (0..<layout.iconCount).map { shown(layout.bead(at: $0), .bead($0)) },
            swell: shown(swellRest, .swell), iconScales: scales)
    }

    private func iconScale(_ index: Int, at instant: LiquidTime, changes: Int) -> Double {
        var from = 1.0, target = 1.0, began = opened, duration = 0.0
        func value(at time: LiquidTime) -> Double {
            guard duration > 0 else { return target }
            return from + (target - from) * min(max((time.seconds - began.seconds) / duration, 0), 1)
        }
        // A change over a second old has finished, so the replay starts from the latest such change's target.
        var first = 0
        if let settled = iconLog[..<changes].lastIndex(where: { $0.time.seconds <= instant.seconds - 1 }) {
            target = iconLog[settled].change.selected == index ? SwitcherRowLayout.selectedIconScale : 1
            first = settled + 1
        }
        for (time, change) in iconLog[first..<changes] {
            from = value(at: time)
            target = change.selected == index ? SwitcherRowLayout.selectedIconScale : 1
            began = time
            duration = change.duration
        }
        return value(at: instant)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// One swipe on a switcher world, played by hand, with the model's selection fed to one `Liquid` after every frame or
/// injected event. The test owns the clock: times are milliseconds from the swipe's start.
@MainActor final class LiquidSwipe {
    let world: World
    private let displayWidth: Double
    private let look: LiquidLook
    private let motion: LiquidMotion
    private let delivery: Delivery
    private var layout: SwitcherRowLayout?
    private var liquid: Liquid?
    private var calls: [LiquidCall] = []
    private var delivered = 0
    private var generator: SeededGenerator
    private var scriptMS = -1
    private(set) var nowMS = 0

    init(world: World, displayWidth: Double, look: LiquidLook, motion: LiquidMotion, delivery: Delivery) {
        self.world = world
        self.displayWidth = displayWidth
        self.look = look
        self.motion = motion
        self.delivery = delivery
        generator = SeededGenerator(state: delivery.jitterSeed ?? 0)
    }

    private var trackpad: TrackpadID { Trackpad.macBook14.id }

    var run: LiquidRun { LiquidRun(layout: layout!, calls: calls) }

    /// The first icon's swell opens at once: the swipe's `.began`, no movement.
    func begin(atMS ms: Int = 0) {
        inject(.began, atMS: ms)
    }

    /// The slide's absolute travel in step millimetres.
    func move(toMM travel: Double, atMS ms: Int) {
        inject(.moved(travelMM: travel), atMS: ms)
    }

    func end(atMS ms: Int) {
        inject(.ended, atMS: ms)
    }

    /// The fingers rest: the unchanged selection is fed on every 10 ms frame.
    func rest(forMS duration: Int) {
        let until = nowMS + duration
        while nowMS < until {
            nowMS += 10
            feed(atMS: nowMS)
        }
    }

    /// Plays the frames of `script` newer than any played, one at a time, feeding after each at the frame's time.
    func play(_ script: TouchScript) {
        let newer = script.frames.filter { Int(($0.time.seconds * 1000).rounded()) > scriptMS }
        var times = newer.map { Int(($0.time.seconds * 1000).rounded()) }.makeIterator()
        _ = world.playFrameByFrame(script) {
            let ms = times.next()!
            scriptMS = ms
            nowMS = ms
            feed(atMS: ms)
        }
    }

    private func inject(_ phase: SwipePhase, atMS ms: Int) {
        nowMS = ms
        world.hardware.inject(.swipe(SwipeEvent(phase: phase, trackpad: trackpad)))
        feed(atMS: ms)
    }

    private func feed(atMS ms: Int) {
        guard let switcher = world.launcher.switcher else {
            liquid = nil
            return
        }
        if liquid == nil {
            let layout = SwitcherRowLayout(iconCount: switcher.row.count, displayWidth: displayWidth, look: look)
            self.layout = layout
            calls = []
            liquid = Liquid(layout: layout, motion: motion)
        }
        let index = delivered
        delivered += 1
        guard !delivery.withheld.contains(index) else { return }
        var seconds = Double(ms) / 1000
        if delivery.jitterSeed != nil { seconds += Double.random(in: 0...0.004, using: &generator) }
        if delivery.squeezed.contains(index), let previous = calls.last { seconds = previous.time.seconds + 0.0005 }
        for _ in 0..<(delivery.twice ? 2 : 1) {
            let time = LiquidTime(seconds: seconds)
            let frame = liquid!.follow(switcher.selection, at: time)
            calls.append(LiquidCall(time: time, selection: switcher.selection, frame: frame, liquid: liquid!))
        }
    }
}

extension World {
    /// Apps installed and running (default: all, in that order) with `frontmost` in front, over a display
    /// `displayWidth` points wide; swipe with the returned hand.
    static func liquidSwipe(
        apps: [String], running: [String]? = nil, frontmost: String? = "Safari", displayWidth: Double = 1512,
        look: LiquidLook = .shipped, motion: LiquidMotion = .flowing, delivery: Delivery = Delivery()
    ) -> LiquidSwipe {
        LiquidSwipe(
            world: switcherWorld(apps: apps, running: running, frontmost: frontmost), displayWidth: displayWidth,
            look: look, motion: motion, delivery: delivery)
    }

    static let fiveApps = ["Safari", "Mail", "Slack", "Notes", "Preview"]
    static let tenApps = ["Safari", "Mail", "Slack", "Notes", "Preview", "TextEdit", "Pages", "Numbers", "Keynote", "Maps"]
}
