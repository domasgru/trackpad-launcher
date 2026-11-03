import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct LiquidStretchTests {
    private func at(_ seconds: Double) -> LiquidTime { LiquidTime(seconds: seconds) }

    /// Travel in steps of at most 1 mm, one event every 10 ms, from `from` to `target`.
    private func ramp(_ hand: LiquidSwipe, from: Double, to target: Double) {
        let events = max(Int(abs(target - from).rounded(.up)), 1)
        for event in 1...events {
            hand.move(toMM: from + (target - from) * Double(event) / Double(events), atMS: hand.nowMS + 10)
        }
    }

    private func crossings(_ values: [Double]) -> Int {
        var count = 0, sign = 0.0
        for value in values where value != 0 {
            if sign != 0 && value.sign != sign.sign { count += 1 }
            sign = value
        }
        return count
    }

    private func instants(of run: LiquidRun, from start: LiquidTime) -> [LiquidTime] {
        run.instants.filter { start <= $0 }
    }

    private let swellChannels = Set(
        [LiquidProperty.centreX, .width, .height].map { LiquidChannel(element: .swell, property: $0) })

    // MARK: Between changes

    @Test(arguments: [1.0, 2, 3, 4, 5, 5.9])
    func slidingShortOfAChangeStretchesOnlyTheLeadingEdge(travel: Double) throws {
        for rise in [12.0, 3] {
            var look = LiquidLook()
            look.swellRise = rise
            let hand = World.liquidSwipe(apps: World.fiveApps, look: look)
            hand.begin()
            ramp(hand, from: 0, to: travel)
            hand.rest(forMS: 2000)
            let run = hand.run
            let layout = run.layout, rest = layout.swell(at: 0)

            #expect(run.calls.dropFirst().allSatisfy { $0.frame.swell == nil && $0.frame.icon == nil })
            let floor = layout.selectedIconBody + 4
            for instant in run.instants {
                let swell = run.played(at: instant).swell
                #expect(abs(swell.minX - rest.minX) < 1e-6)
                #expect(swell.height >= floor - 1e-6 && swell.height <= rest.height + 1e-6)
            }
            let settled = run.played(at: run.last + 2).swell
            #expect(settled.maxX < layout.centreX(at: 1))
            if rise == 12 && travel >= 5 { #expect(settled.maxX - rest.maxX >= 10) }
        }
    }

    @Test func theStretchGrowsWithTheDistanceTravelled() {
        var settled: [Double] = []
        for travel in [1.0, 2, 3, 4, 5, 5.9] {
            let hand = World.liquidSwipe(apps: World.fiveApps)
            hand.begin()
            ramp(hand, from: 0, to: travel)
            hand.rest(forMS: 2000)
            settled.append(hand.run.played(at: hand.run.last + 2).swell.maxX)
        }
        #expect(zip(settled, settled.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func aDeadStopAtFiveMillimetresOvershootsItsSettleByAtMostTheWobble() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.move(toMM: 5, atMS: 10)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout, rest = layout.swell(at: 0)

        let settled = run.played(at: run.last + 2).swell.maxX
        #expect(settled - rest.maxX >= 10)
        for instant in run.instants {
            let swell = run.played(at: instant).swell
            #expect(swell.maxX <= settled + layout.look.wobble)
            #expect(abs(swell.minX - rest.minX) < 1e-6)
        }
    }

    @Test func slidingBackBeforeTheChangeSpringsTheSwellBackAroundTheFirstIcon() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        ramp(hand, from: 0, to: 5)
        ramp(hand, from: 5, to: 0)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout, rest = layout.swell(at: 0)

        for instant in run.instants {
            let swell = run.played(at: instant).swell
            #expect(abs(swell.minX - rest.minX) < 1e-6)
            #expect(swell.maxX >= rest.maxX - layout.look.wobble)
        }
        #expect(abs(run.played(at: run.last + 1).swell.maxX - rest.maxX) < 1e-6)
        for instant in instants(of: run, from: run.last + 1) {
            #expect(run.played(at: instant) == run.played(at: run.opened))
        }
    }

    // MARK: Past an end

    enum End: String { case last, first }

    /// Settles on the end app, then returns the travel that is exactly at the end.
    private func settledAtEnd(_ hand: LiquidSwipe, _ end: End) -> Double {
        hand.begin()
        guard end == .last else {
            hand.rest(forMS: 2000)
            return 0
        }
        hand.move(toMM: 48, atMS: 10)
        hand.rest(forMS: 2000)
        return 48
    }

    /// How far the outer edge is beyond the end icon's swell rest.
    private func pull(_ run: LiquidRun, _ end: End, at instant: LiquidTime) -> Double {
        let swell = run.played(at: instant).swell
        return end == .last
            ? swell.maxX - run.layout.swell(at: 4).maxX : run.layout.swell(at: 0).minX - swell.minX
    }

    private func innerEdge(_ run: LiquidRun, _ end: End, at instant: LiquidTime) -> Double {
        let swell = run.played(at: instant).swell
        return end == .last ? swell.minX : swell.maxX
    }

    @Test(arguments: [End.last, .first])
    func pushingPastAnEndPullsOnlyTheOuterEdgeAndItSpringsBackWhenTheFingersRest(end: End) throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        let edge = settledAtEnd(hand, end)
        let sign = end == .last ? 1.0 : -1.0
        let pushStart = hand.nowMS
        ramp(hand, from: edge, to: edge + sign * 3)
        let threeMM = hand.nowMS
        for event in 1...9 { hand.move(toMM: edge + sign * (3 + Double(event)), atMS: hand.nowMS + 10) }
        let pushEnd = hand.nowMS
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout, wobble = layout.look.wobble
        let settledInner = innerEdge(run, end, at: at(Double(pushStart) / 1000))
        func seconds(_ ms: Int) -> LiquidTime { at(Double(ms) / 1000) }

        for instant in run.instants {
            #expect(pull(run, end, at: instant) <= 20 + 1e-6)
            if seconds(pushStart) <= instant && instant <= seconds(pushEnd + 2000) {
                let played = run.played(at: instant)
                #expect(abs(innerEdge(run, end, at: instant) - settledInner) < 1e-6)
                #expect(played.band == layout.band && (0..<5).allSatisfy { played.beads[$0] == layout.bead(at: $0) })
            }
        }
        #expect(run.nonEmptyFrames.allSatisfy { $0.tracks.allSatisfy { $0.channel.element == .swell } })
        #expect(pull(run, end, at: seconds(threeMM + 10)) >= 10)
        for call in run.calls where seconds(pushStart) < call.time && call.time <= seconds(pushEnd) {
            #expect(!call.frame.isEmpty)
        }
        let pulled = pull(run, end, at: seconds(threeMM + 10))
        for instant in instants(of: run, from: seconds(threeMM + 10)).filter({ $0 <= seconds(pushEnd) }) {
            #expect(abs(pull(run, end, at: instant) - pulled) <= wobble)
        }

        let springBack = instants(of: run, from: seconds(pushEnd)).map { pull(run, end, at: $0) }
        #expect(crossings(springBack) >= 2)
        #expect(springBack.min()! >= -wobble)
        for instant in instants(of: run, from: seconds(pushEnd + 60 + 1000)) {
            #expect(pull(run, end, at: instant) == 0)
        }
        for call in run.calls where call.time > seconds(pushStart) {
            #expect(call.frame.tracks.allSatisfy { !$0.holds })
        }
    }

    @Test func turningBackFromPastTheEndSpringsTheOuterEdgeBackWithAWobble() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        _ = settledAtEnd(hand, .last)
        ramp(hand, from: 48, to: 51)
        let turn = hand.nowMS + 10
        hand.move(toMM: 49, atMS: turn)
        hand.rest(forMS: 2000)
        let run = hand.run

        let after = instants(of: run, from: at(Double(turn) / 1000)).map { pull(run, .last, at: $0) }
        #expect(crossings(after) >= 2)
        #expect(after.min()! >= -run.layout.look.wobble)
        #expect(abs(after.last!) < 1e-6)
    }

    @Test func thePullGrowsWithTheDistancePastTheEnd() {
        var peaks: [Double] = []
        for past in [0.5, 1, 2, 3] {
            let hand = World.liquidSwipe(apps: World.fiveApps)
            _ = settledAtEnd(hand, .last)
            hand.move(toMM: 48 + past, atMS: hand.nowMS + 10)
            hand.rest(forMS: 2000)
            let run = hand.run
            peaks.append(run.instants.map { pull(run, .last, at: $0) }.max()!)
        }
        #expect(zip(peaks, peaks.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test(arguments: ["tenApps", "highEndPull", "highRise"])
    func thePullNeverExceedsAFifthOfThePitchAndTheSwellStaysInThePanel(setup: String) {
        var look = LiquidLook()
        var apps = World.fiveApps, width = 1512.0
        switch setup {
        case "tenApps": apps = World.tenApps; width = 1024
        case "highEndPull": look.endPull = 50
        default: look.swellRise = 30
        }
        let hand = World.liquidSwipe(apps: apps, displayWidth: width, look: look)
        let last = Double(apps.count - 1) * 12
        hand.begin()
        hand.move(toMM: last, atMS: 10)
        hand.rest(forMS: 2000)
        let settledAt = hand.nowMS
        hand.move(toMM: last + 3, atMS: settledAt + 10)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout, rest = layout.swell(at: apps.count - 1)
        let panel = layout.panelSize

        var peak = 0.0
        for instant in instants(of: run, from: at(Double(settledAt) / 1000)) {
            let swell = run.played(at: instant).swell
            peak = max(peak, swell.maxX - rest.maxX)
            #expect(swell.maxX - rest.maxX <= 0.2 * layout.pitch + 1e-6)
            #expect(swell.minX >= -1e-6 && swell.maxX <= panel.width + 1e-6)
            #expect(swell.minY >= -1e-6 && swell.maxY <= panel.height + 1e-6)
        }
        #expect(peak >= 0.9 * 0.2 * layout.pitch)
    }

    @Test func liftingDuringAStretchChangesNothingAndClosesTheSwitcher() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.move(toMM: 2.5, atMS: 10)
        hand.move(toMM: 5, atMS: 20)
        let run = hand.run
        #expect(run.played(at: at(0.03)).swell.maxX - run.layout.swell(at: 0).maxX >= 10)

        hand.end(atMS: 30)

        #expect(hand.world.system.broughtToFront.isEmpty)
        #expect(hand.world.hardware.pulses.isEmpty)
        #expect(hand.world.launcher.switcher == nil)
    }

    @Test func theLeadingEdgeIsNeverAFrameBehindTheFingers() {
        let hand = World.liquidSwipe(apps: World.tenApps)
        hand.begin()
        var travel = 0.0
        var checked = 0
        for _ in 0..<24 {
            travel += 1
            hand.move(toMM: travel, atMS: hand.nowMS + 10)
        }
        hand.rest(forMS: 400)
        for _ in 0..<8 {
            for (direction, count) in [(1.0, 5), (-1.0, 10), (1.0, 5)] {
                for _ in 0..<count {
                    travel += direction
                    hand.move(toMM: travel, atMS: hand.nowMS + 10)
                }
            }
        }
        hand.rest(forMS: 2000)
        let run = hand.run, wobble = run.layout.look.wobble
        var previous = run.calls[0]
        var direction = 1.0
        var flowDue = -Double.infinity
        for (index, call) in run.calls.enumerated().dropFirst() {
            defer { previous = call }
            if call.selection.selected != previous.selection.selected {
                flowDue = call.time.seconds + min(run.layout.look.flowTime, 0.2)
            }
            let moved = call.selection.travelMM - previous.selection.travelMM
            if moved != 0 { direction = moved > 0 ? 1 : -1 }
            guard call.selection.selected == previous.selection.selected, !call.frame.isEmpty,
                call.time.seconds >= flowDue else { continue }
            let known = LiquidRun(layout: run.layout, calls: Array(run.calls.prefix(index + 1)))
            let edge: (Played) -> Double = { direction > 0 ? $0.swell.maxX : $0.swell.minX }
            let soon = edge(known.played(at: call.time + 1.0 / 60))
            let settled = edge(known.played(at: call.time + 2))
            #expect(abs(soon - settled) <= wobble)
            checked += 1
        }
        #expect(checked > 100)
    }
}
