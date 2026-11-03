import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct LiquidWaveTests {
    private func at(_ seconds: Double) -> LiquidTime { LiquidTime(seconds: seconds) }

    /// From `startMS` (the swipe's clock), travels linearly from `from` to `to` mm in events every 10 ms.
    private func slide(_ hand: LiquidSwipe, from: Double = 0, to: Double, overMS duration: Int) {
        let events = max(duration / 10, 1)
        let start = hand.nowMS
        for event in 1...events {
            hand.move(toMM: from + (to - from) * Double(event) / Double(events), atMS: start + 10 * event)
        }
    }

    /// The most bead `index` is ever taller or thinner than its rest, from `start` on.
    private func peak(_ run: LiquidRun, bead index: Int, from start: LiquidTime = LiquidTime(seconds: 0)) -> Double {
        let rest = run.layout.bead(at: index).height
        return run.instants.filter { start <= $0 }.map { abs(run.played(at: $0).beads[index].height - rest) }.max()!
    }

    /// The first instant bead `index` is a tenth of its own peak off its rest.
    private func onset(_ run: LiquidRun, bead index: Int, from start: LiquidTime) -> Double? {
        let rest = run.layout.bead(at: index).height
        let top = peak(run, bead: index, from: start)
        return run.instants.filter { start <= $0 }
            .first { abs(run.played(at: $0).beads[index].height - rest) >= top / 10 }?.seconds
    }

    private func beadTracks(_ frame: LiquidFrame) -> [LiquidTrack] {
        frame.tracks.filter { if case .bead = $0.channel.element { true } else { false } }
    }

    private func swellTracks(_ frame: LiquidFrame) -> [LiquidTrack] {
        frame.tracks.filter { $0.channel.element == .swell }
    }

    // MARK: Size and reach

    @Test(arguments: ["everyValue", "jittered", "everyThird"])
    func aQuickSwipeMakesABiggerWaveThanASlowOneOverTheSameDistance(variant: String) {
        func wave(overMS duration: Int) -> Double {
            var delivery = Delivery()
            if variant == "jittered" { delivery.jitterSeed = 11 }
            if variant == "everyThird" {
                delivery.withheld = Set((1...(duration / 10)).filter { $0 % 3 != 0 })
            }
            let hand = World.liquidSwipe(apps: World.fiveApps, delivery: delivery)
            hand.begin()
            slide(hand, to: 7, overMS: duration)
            hand.rest(forMS: 2000)
            return peak(hand.run, bead: 2)
        }
        let quick = wave(overMS: 60), slow = wave(overMS: 600)

        #expect(slow > 0)
        #expect(quick > 1.5 * slow, "quick \(quick), slow \(slow)")
    }

    @Test func coalescingKeepsTheAverageSpeedSoTheWaveStaysWithinAFifth() {
        func wave(_ delivery: Delivery, overMS duration: Int) -> Double {
            let hand = World.liquidSwipe(apps: World.fiveApps, delivery: delivery)
            hand.begin()
            slide(hand, to: 7, overMS: duration)
            hand.rest(forMS: 2000)
            return peak(hand.run, bead: 2)
        }
        for duration in [60, 600] {
            var thirds = Delivery()
            thirds.withheld = Set((1...(duration / 10)).filter { $0 % 3 != 0 })
            let every = wave(Delivery(), overMS: duration), third = wave(thirds, overMS: duration)
            #expect(abs(third - every) <= 0.2 * every, "\(duration) ms: every \(every), third \(third)")
        }
    }

    @Test(arguments: [true, false])
    func beadsNearTheSwellRippleMoreAndLaterThanBeadsFarFromIt(rightward: Bool) {
        let hand = World.liquidSwipe(apps: World.tenApps)
        hand.begin()
        var start = LiquidTime(seconds: 0)
        if !rightward {
            hand.move(toMM: 108, atMS: 10)
            hand.rest(forMS: 2000)
            start = at(Double(hand.nowMS) / 1000)
        }
        slide(hand, from: rightward ? 0 : 108, to: rightward ? 5 : 101, overMS: 50)
        hand.rest(forMS: 2000)
        let run = hand.run
        let beads = rightward ? [1, 5, 9] : [8, 4, 0]

        let peaks = beads.map { peak(run, bead: $0, from: start) }
        #expect(peaks[0] > peaks[1] && peaks[1] > peaks[2] && peaks[2] > 0, "\(peaks)")
        let onsets = beads.map { onset(run, bead: $0, from: start) }
        #expect(onsets.allSatisfy { $0 != nil })
        #expect(onsets[0]! < onsets[1]! && onsets[1]! < onsets[2]!, "\(onsets)")
    }

    @Test func aWaveRipplesOnlyTheHeightsOfBeadsAndStartsWithTheFirstMovement() throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        slide(hand, to: 5, overMS: 50)
        hand.rest(forMS: 2000)
        let run = hand.run
        let first = run.calls[1]

        #expect(first.selection.selected == 0 && first.frame.swell == nil)
        let beads = beadTracks(first.frame)
        #expect(beads.map(\.channel) == (0..<5).map { LiquidChannel(element: .bead($0), property: .height) })
        #expect(beads.allSatisfy { $0.begin == first.time && $0.offsets.count >= 2 })
        #expect(abs(run.played(at: first.time + 0.1).beads[1].height - run.layout.bead(at: 1).height) > 0)
        #expect(run.calls[0].frame.tracks.isEmpty)
    }

    // MARK: Bounds

    enum Flick: String, CaseIterable {
        case shipped, extreme, smallRise
    }

    /// Every bound a wave must keep, at the played shape of every `stride` ms: what is wrong, if anything.
    private func violations(of run: LiquidRun, stride: Int = 1) -> [String] {
        let layout = run.layout, look = layout.look
        let panel = layout.panelSize
        let tallest = 2 * min(look.waveMax, look.room) * layout.scale
        var found: [String] = []
        for (index, instant) in run.instants.enumerated() where index % stride == 0 {
            let played = run.played(at: instant)
            let rects = [played.band, played.swell] + played.beads
            let at = "at \(instant.seconds)"
            if !rects.allSatisfy({ [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite) }) {
                found.append("not finite \(at)")
                continue
            }
            if !played.swell.overlaps(played.band) { found.append("swell off the band \(at)") }
            for (bead, rect) in played.beads.enumerated() {
                let rest = layout.bead(at: bead)
                if !rect.overlaps(played.band) { found.append("bead \(bead) off the band \(at)") }
                if rect.height < played.band.height - 1e-6 { found.append("bead \(bead) thinner than the band \(at)") }
                if rect.height > rest.height + tallest + 1e-6 { found.append("bead \(bead) too tall \(at)") }
                let side = look.iconBody * layout.scale * played.iconScales[bead]
                let body = LiquidRect.centred(x: layout.centreX(at: Double(bead)), y: layout.centreY, width: side, height: side)
                if !rect.contains(body) && !played.swell.contains(body) { found.append("icon \(bead) out of its bead \(at)") }
            }
            let inside = LiquidRect(minX: 0, minY: 0, width: panel.width, height: panel.height)
            if !rects.allSatisfy({ inside.contains($0, within: 1e-6) }) { found.append("outside the panel \(at)") }
        }
        for frame in run.nonEmptyFrames {
            for track in frame.tracks {
                if case .bead(let index) = track.channel.element,
                    index >= layout.iconCount || track.channel.property != .height
                {
                    found.append("track on \(track.channel)")
                }
            }
        }
        return found
    }

    /// Across the whole ten-app row and past it in one 10 ms frame, and back, five times, then rest.
    private func hardestFlick(width: Double, look: LiquidLook, delivery: Delivery = Delivery()) -> LiquidRun {
        let hand = World.liquidSwipe(apps: World.tenApps, displayWidth: width, look: look, delivery: delivery)
        hand.begin()
        for _ in 0..<5 {
            hand.move(toMM: 140, atMS: hand.nowMS + 10)
            hand.move(toMM: -40, atMS: hand.nowMS + 10)
        }
        hand.rest(forMS: 2000)
        return hand.run
    }

    private func look(_ flick: Flick) -> LiquidLook {
        var look = LiquidLook()
        switch flick {
        case .shipped: break
        case .extreme:
            look.waveHeight = 1000
            look.waveFullSpeed = 0.01
        case .smallRise: look.swellRise = 3
        }
        return look
    }

    @Test(arguments: [1512.0, 1024], Flick.allCases)
    func theHardestFlickKeepsTheBandOneShapeAndEveryIconInsideItsBead(width: Double, flick: Flick) {
        for squeezed in [false, true] {
            var delivery = Delivery()
            if squeezed { delivery.squeezed = [2, 3, 6, 7] }
            let run = hardestFlick(width: width, look: look(flick), delivery: delivery)

            let found = violations(of: run)
            #expect(found.isEmpty, "squeezed \(squeezed): \(found.prefix(3))")
            #expect(run.nonEmptyFrames.contains { !beadTracks($0).isEmpty })
        }
    }

    // MARK: Budget

    @Test func aBackAndForthSlideStagesOnlyWhatTheBudgetAllows() {
        let hand = World.liquidSwipe(apps: World.tenApps)
        hand.begin()
        for event in 1...300 {
            let phase = Double(event % 100) / 100
            hand.move(toMM: 100 * (phase < 0.5 ? 2 * phase : 2 - 2 * phase), atMS: 10 * event)
        }
        hand.rest(forMS: 2000)
        let run = hand.run

        var crestPosition: Double?
        var waves = 0
        for call in run.calls {
            let channels = call.frame.tracks.map(\.channel)
            #expect(Set(channels).count == channels.count)
            #expect(swellTracks(call.frame).count <= 3)
            #expect(call.frame.tracks.allSatisfy { Double($0.offsets.count - 1) * $0.step <= 1 + 1e-9 })
            let beads = beadTracks(call.frame)
            guard !beads.isEmpty else { continue }
            waves += 1
            #expect(beads.count == 10)
            let position = call.selection.position
            if let previous = crestPosition { #expect(abs(position - previous) >= 0.5 - 1e-9) }
            crestPosition = position
        }
        #expect(waves > 20)
    }

    @Test func stillMotionAndRestingFingersStageNoWave() {
        let still = World.liquidSwipe(apps: World.fiveApps, motion: .still)
        still.begin()
        slide(still, to: 30, overMS: 300)
        still.rest(forMS: 500)
        #expect(still.run.nonEmptyFrames.allSatisfy { $0.tracks.isEmpty })

        let resting = World.liquidSwipe(apps: World.fiveApps)
        resting.begin()
        slide(resting, to: 30, overMS: 300)
        resting.rest(forMS: 2000)
        let run = resting.run
        let quiet = run.calls.filter { $0.time > run.calls.last { !$0.frame.isEmpty }!.time }
        #expect(!quiet.isEmpty && quiet.allSatisfy { $0.frame.isEmpty })
    }

    // MARK: Whatever the hand

    private struct Hand {
        let run: LiquidRun
        let lift: (front: [String], expected: [String])
    }

    private func play(seed: UInt64) -> Hand {
        var generator = SeededGenerator(state: seed)
        let count = Int.random(in: 2...10, using: &generator)
        let width = [1512.0, 1024, 800].randomElement(using: &generator)!
        var delivery = Delivery()
        if Bool.random(using: &generator) {
            delivery.withheld = Set((1..<3000).filter { _ in Double.random(in: 0..<1, using: &generator) < 0.25 })
        }
        delivery.twice = Int.random(in: 0..<4, using: &generator) == 0
        if Bool.random(using: &generator) { delivery.jitterSeed = seed }
        let hand = World.liquidSwipe(apps: Array(World.tenApps.prefix(count)), displayWidth: width, delivery: delivery)
        hand.begin()
        let slides = Int.random(in: 1...8, using: &generator)
        let liftSlide = Int.random(in: 0..<slides, using: &generator)
        var travel = 0.0
        var lifted = false
        for slideIndex in 0..<slides where !lifted {
            let target = travel + Double.random(in: -60...60, using: &generator)
            let events = max(Int.random(in: 10...600, using: &generator) / 10, 1)
            let liftAt = slideIndex == liftSlide ? Int.random(in: 1...events, using: &generator) : -1
            let from = travel
            for event in 1...events {
                hand.move(toMM: from + (target - from) * Double(event) / Double(events), atMS: hand.nowMS + 10)
                if event == liftAt {
                    lifted = true
                    break
                }
            }
            travel = target
            if !lifted { hand.rest(forMS: 10 * Int.random(in: 0...50, using: &generator)) }
        }
        let switcher = hand.world.launcher.switcher!
        let expected = switcher.selectsFrontmost ? [] : [switcher.selectedApp.name]
        hand.end(atMS: hand.nowMS + 10)
        return Hand(run: hand.run, lift: (hand.world.system.broughtToFront.map(\.name), expected))
    }

    @Test(arguments: Array(0..<200))
    func anyHandKeepsTheLiquidInsideItsBoundsAndSettles(seed: Int) {
        let hand = play(seed: UInt64(seed))
        let run = hand.run, layout = run.layout, wobble = layout.look.wobble

        let found = violations(of: run, stride: 4)
        #expect(found.isEmpty, "seed \(seed): \(found.prefix(3))")
        #expect(hand.lift.front == hand.lift.expected, "seed \(seed)")

        let first = layout.swell(at: 0), last = layout.swell(at: layout.iconCount - 1)
        for instant in run.instants.enumerated().filter({ $0.offset % 4 == 0 }).map(\.element) {
            let swell = run.played(at: instant).swell
            #expect(first.minX - swell.minX <= 0.2 * layout.pitch + 1e-6 && swell.maxX - last.maxX <= 0.2 * layout.pitch + 1e-6)
        }

        var previous: LiquidCall?
        for call in run.calls {
            defer { previous = call }
            if call.frame.swell != nil { #expect(call.frame.swell == layout.swell(at: call.selection.selected)) }
            #expect(call.frame.tracks.allSatisfy { Double($0.offsets.count - 1) * $0.step <= 1 + 1e-9 })
            if let previous, previous.selection == call.selection { #expect(call.frame.isEmpty, "seed \(seed)") }
        }

        let staging = run.calls.enumerated().filter { !$0.element.frame.isEmpty }
        for (position, entry) in staging.enumerated() {
            let (index, call) = entry
            guard call.frame.swell != nil, index > 0 else { continue }
            let next = position + 1 < staging.count ? staging[position + 1].element.time : nil
            let known = LiquidRun(layout: layout, calls: Array(run.calls.prefix(index + 1)))
            let direction = call.selection.selected > run.calls[index - 1].selection.selected ? 1.0 : -1.0
            let far: (Played) -> Double = { direction > 0 ? $0.swell.maxX : $0.swell.minX }
            let settled = far(known.played(at: call.time + 2))
            let from = call.time + 0.2
            if let next, next < from { continue }
            let until = next ?? call.time + 2
            for instant in run.instants.filter({ from <= $0 && $0 < until }) {
                #expect(abs(far(run.played(at: instant)) - settled) <= wobble + 1e-6, "seed \(seed) change at \(call.time.seconds)")
            }
        }

        if let lastStaged = staging.last?.element.time {
            let settled = run.played(at: lastStaged + 1.001)
            for instant in run.instants.filter({ lastStaged + 1.001 <= $0 }) {
                #expect(run.played(at: instant) == settled, "seed \(seed)")
            }
        }

        checkShape(run, seed: seed)
    }

    /// The closed form and the staged samples agree at every sample instant, until the channel's track is replaced.
    private func checkShape(_ run: LiquidRun, seed: Int) {
        let staging = run.calls.enumerated().filter { !$0.element.frame.isEmpty }
        var bad: [String] = []
        for (position, entry) in staging.enumerated() {
            for track in entry.element.frame.tracks {
                if track.channel.element == .swell && track.channel.property != .height { continue }
                let replaced = staging[(position + 1)...].first { $0.element.frame.tracks.contains { $0.channel == track.channel } }
                for sample in track.offsets.indices {
                    let instant = track.begin + Double(sample) * track.step
                    if let replaced, replaced.element.time <= instant { break }
                    let copy = staging.last { $0.element.time <= instant }!.element.liquid
                    let shape = copy.shape(at: instant), played = run.played(at: instant)
                    switch track.channel.element {
                    case .swell: if !shape.swell.isClose(to: played.swell, within: 1e-6) { bad.append("swell \(instant.seconds)") }
                    case .bead(let index):
                        if !shape.beads[index].isClose(to: played.beads[index], within: 1e-6) { bad.append("bead \(index) \(instant.seconds)") }
                    }
                }
            }
        }
        #expect(bad.isEmpty, "seed \(seed): \(bad.prefix(3))")
    }

    // MARK: Knobs

    private func oneStep(_ look: LiquidLook) -> LiquidRun {
        let hand = World.liquidSwipe(apps: World.fiveApps, look: look)
        hand.begin()
        slide(hand, to: 12, overMS: 100)
        hand.rest(forMS: 2000)
        return hand.run
    }

    private func slideRight(_ look: LiquidLook) -> LiquidRun {
        let hand = World.liquidSwipe(apps: World.tenApps, look: look)
        hand.begin()
        slide(hand, to: 5, overMS: 50)
        hand.rest(forMS: 2000)
        return hand.run
    }

    /// The right edge's offsets from where it settles, from the change on.
    private func tail(_ run: LiquidRun) -> [Double] {
        let settled = run.layout.swell(at: 1).maxX
        return run.instants.filter { at(0.05) <= $0 }.map { run.played(at: $0).swell.maxX - settled }
    }

    private func crossingInstants(_ values: [Double]) -> [Int] {
        var result: [Int] = []
        for index in values.indices.dropFirst() where values[index - 1] != 0 && values[index - 1].sign != values[index].sign {
            result.append(index)
        }
        return result
    }

    @Test func eachMotionKnobChangesTheOutputItNames() {
        let base = LiquidLook()
        func raised(_ keyPath: WritableKeyPath<LiquidLook, Double>) -> LiquidLook {
            var look = base
            look[keyPath: keyPath] *= 1.5
            return look
        }
        let shipped = oneStep(base)
        let shippedTail = tail(shipped)
        let overshoot = shippedTail.max()!, crossings = crossingInstants(shippedTail)

        let wobble = tail(oneStep(raised(\.wobble)))
        #expect(wobble.max()! > overshoot, "wobble: \(wobble.max()!) vs \(overshoot)")

        let faster = crossingInstants(tail(oneStep(raised(\.wobbleHz))))
        #expect(faster.count >= 2 && crossings.count >= 2 && faster[1] - faster[0] < crossings[1] - crossings[0])

        func decay(_ values: [Double]) -> Double {
            let crossing = crossingInstants(values)
            let first = values[0..<crossing[1]].map(abs).max()!, second = values[crossing[1]...].map(abs).max()!
            return second / first
        }
        #expect(decay(tail(oneStep(raised(\.wobbleDamping)))) < decay(shippedTail))

        let ripple = slideRight(base)
        let strong = slideRight(raised(\.waveHeight))
        #expect(peak(strong, bead: 1) > 1.2 * peak(ripple, bead: 1))

        let wide = slideRight(raised(\.waveReach))
        let share = { (run: LiquidRun) in self.peak(run, bead: 9) / self.peak(run, bead: 1) }
        #expect(share(wide) > share(ripple))

        let taller = SwitcherRowLayout(iconCount: 10, displayWidth: 1512, look: raised(\.waveMax))
        let usual = SwitcherRowLayout(iconCount: 10, displayWidth: 1512, look: base)
        #expect(taller.beadLimits.upperBound > usual.beadLimits.upperBound)
        let flick = hardestFlick(width: 1512, look: raised(\.waveMax)), flicked = hardestFlick(width: 1512, look: base)
        #expect(peak(flick, bead: 1) > peak(flicked, bead: 1))

        for knob in [raised(\.wobble), raised(\.waveHeight), raised(\.waveReach), raised(\.waveMax), raised(\.wobbleHz)] {
            let layout = SwitcherRowLayout(iconCount: 5, displayWidth: 1512, look: knob)
            let reference = SwitcherRowLayout(iconCount: 5, displayWidth: 1512, look: base)
            #expect(layout.band == reference.band && layout.swell(at: 1) == reference.swell(at: 1))
        }
    }
}
