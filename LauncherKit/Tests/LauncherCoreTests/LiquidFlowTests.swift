import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct LiquidFlowTests {
    private func at(_ seconds: Double) -> LiquidTime { LiquidTime(seconds: seconds) }

    /// Begins, then travels linearly to `total` mm in events every 10 ms.
    private func slide(_ hand: LiquidSwipe, toMM total: Double, overMS duration: Int) {
        hand.begin()
        let events = duration / 10
        for event in 1...events { hand.move(toMM: total * Double(event) / Double(events), atMS: 10 * event) }
    }

    /// How many times `values` changes sign, ignoring zeros.
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

    /// Both edges stay within `tolerance` of icon `selected`'s swell from `start` on.
    private func settles(_ run: LiquidRun, on selected: Int, from start: LiquidTime, within tolerance: Double) -> Bool {
        let rest = run.layout.swell(at: selected)
        return instants(of: run, from: start).allSatisfy {
            let swell = run.played(at: $0).swell
            return abs(swell.minX - rest.minX) <= tolerance && abs(swell.maxX - rest.maxX) <= tolerance
        }
    }

    private func swellChannels(_ tracks: [LiquidTrack]) -> Set<LiquidChannel> {
        Set(tracks.map(\.channel).filter { $0.element == .swell })
    }

    private let allSwellChannels = Set(
        [LiquidProperty.centreX, .width, .height].map { LiquidChannel(element: .swell, property: $0) })

    @Test func oneStepFlowsToTheNextIconWobblesAndLeavesTheFirstInABead() throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        slide(hand, toMM: 12, overMS: 100)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout
        let change = try #require(run.calls.first { $0.frame.swell == layout.swell(at: 1) })

        #expect(change.time.seconds == 0.05)
        let icon = try #require(change.frame.icon)
        #expect(icon.selected == 1 && icon.duration > 0 && icon.duration <= 0.2)
        #expect(swellChannels(change.frame.tracks) == allSwellChannels)

        let continued = LiquidRun(layout: layout, calls: Array(run.calls.prefix { $0.time < change.time }))
        let before = continued.played(at: change.time).swell, after = run.played(at: change.time).swell
        #expect(abs(before.minX - after.minX) <= 0.5 && abs(before.maxX - after.maxX) <= 0.5)
        let flowing = run.played(at: at(0.15)).swell.maxX
        #expect(layout.swell(at: 0).maxX < flowing && flowing < layout.swell(at: 1).maxX)
        #expect(settles(run, on: 1, from: at(0.25), within: layout.look.wobble))
        let rightEdge = instants(of: run, from: change.time).map {
            run.played(at: $0).swell.maxX - layout.swell(at: 1).maxX
        }
        #expect(crossings(rightEdge) >= 2)
        for instant in instants(of: run, from: at(1.1)) {
            let played = run.played(at: instant)
            #expect(played.swell == layout.swell(at: 1) && !played.swell.overlaps(played.beads[0]))
        }
    }

    @Test func aChangeDuringAFlowRetargetsItInsteadOfQueueing() throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.move(toMM: 12, atMS: 10)
        hand.move(toMM: 24, atMS: 60)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout
        let second = try #require(run.calls.last { $0.frame.swell != nil })

        let mid = run.played(at: at(0.059)).swell.maxX
        #expect(abs(mid - layout.swell(at: 0).maxX) >= 10 && abs(mid - layout.swell(at: 1).maxX) >= 10)
        #expect(second.frame.swell == layout.swell(at: 2))
        #expect(swellChannels(second.frame.tracks) == allSwellChannels)
        let continued = LiquidRun(layout: layout, calls: Array(run.calls.prefix { $0.time < second.time }))
        let before = continued.played(at: second.time).swell, after = run.played(at: second.time).swell
        #expect(abs(before.minX - after.minX) <= 0.5 && abs(before.maxX - after.maxX) <= 0.5)
        var previous = after.maxX
        for instant in instants(of: run, from: second.time) {
            let edge = run.played(at: instant).swell.maxX
            if previous >= layout.swell(at: 2).maxX { break }
            #expect(edge >= previous - 1e-9)
            previous = edge
        }
        #expect(settles(run, on: 2, from: at(0.26), within: layout.look.wobble))
    }

    @Test func aSteadySlideKeepsTheSwellAtTheSelectedIconAndStopsWhenTheFingersDo() throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        slide(hand, toMM: 48, overMS: 600)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout

        #expect(run.calls.compactMap(\.frame.swell) == (0...4).map { layout.swell(at: $0) })
        for call in run.calls where call.frame.swell != nil {
            #expect(call.frame.swell == layout.swell(at: call.selection.selected))
        }
        for instant in run.instants {
            let selected = run.calls.last { $0.time <= instant }!.selection.selected
            let behind = layout.centreX(at: Double(selected)) - run.played(at: instant).swell.midX
            #expect(behind < layout.pitch + layout.look.wobble)
        }
        let lastChange = try #require(run.calls.last { $0.frame.swell != nil }).time
        #expect(settles(run, on: 4, from: lastChange + 0.2, within: layout.look.wobble))
        let settled = run.played(at: run.last + 2).swell
        #expect(settled.contains(.centred(x: layout.centreX(at: 4), y: layout.centreY, width: 71.68, height: 71.68)))
    }

    @Test(arguments: ["oneFrame", "threeFrames", "middleWithheld"])
    func aFlickAcrossSeveralAppsEndsAroundTheLastOne(flick: String) throws {
        var delivery = Delivery()
        if flick == "middleWithheld" { delivery.withheld = [1, 2] }
        let hand = World.liquidSwipe(apps: World.fiveApps, delivery: delivery)
        if flick == "oneFrame" {
            hand.begin()
            hand.move(toMM: 36, atMS: 10)
        } else {
            slide(hand, toMM: 36, overMS: 30)
        }
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout

        if flick != "threeFrames" {
            #expect(run.calls.compactMap(\.frame.swell) == [layout.swell(at: 0), layout.swell(at: 3)])
            #expect(run.calls.compactMap(\.frame.icon).map(\.selected) == [0, 3])
        }
        let lastChange = try #require(run.calls.last { $0.frame.swell != nil }).time
        #expect(settles(run, on: 3, from: lastChange + 0.2, within: layout.look.wobble))
        let body = LiquidRect.centred(x: layout.centreX(at: 3), y: layout.centreY, width: 71.68, height: 71.68)
        for instant in instants(of: run, from: lastChange + 0.2) {
            let played = run.played(at: instant)
            #expect(played.swell.contains(body))
            for index in 0..<3 {
                let rest = layout.bead(at: index), bead = played.beads[index]
                #expect(bead.minX == rest.minX && bead.width == rest.width && abs(bead.midY - rest.midY) < 1e-9)
                #expect(!bead.overlaps(played.swell))
            }
        }
    }

    @Test(arguments: ["slide", "flick"], ["everyThird", "randomHalf", "twice"])
    func skippedAndRepeatedValuesLeaveTheSameSettledShape(scenario: String, delivery name: String) throws {
        func play(_ delivery: Delivery) -> LiquidRun {
            let hand = World.liquidSwipe(apps: World.fiveApps, delivery: delivery)
            if scenario == "slide" { slide(hand, toMM: 48, overMS: 600) } else { slide(hand, toMM: 36, overMS: 30) }
            hand.rest(forMS: 2000)
            return hand.run
        }
        let events = scenario == "slide" ? 60 : 3
        var delivery = Delivery()
        switch name {
        case "everyThird": delivery.withheld = Set((1...events).filter { $0 % 3 != 0 })
        case "randomHalf":
            var generator = SeededGenerator(state: 7)
            delivery.withheld = Set((1...events).filter { _ in Bool.random(using: &generator) })
        default: delivery.twice = true
        }
        let reference = play(Delivery()), run = play(delivery)
        let layout = run.layout

        for call in run.calls where call.frame.swell != nil {
            #expect(call.frame.swell == layout.swell(at: call.selection.selected))
        }
        let settled = run.played(at: run.last + 2), expected = reference.played(at: reference.last + 2)
        #expect(settled.swell.isClose(to: expected.swell, within: 1e-9))
        #expect(zip(settled.beads, expected.beads).allSatisfy { $0.isClose(to: $1, within: 1e-9) })
        if name == "twice" {
            for pair in stride(from: 0, to: run.calls.count, by: 2) { #expect(run.calls[pair + 1].frame.isEmpty) }
            #expect(run.instants.allSatisfy { run.played(at: $0) == reference.played(at: $0) })
        }
        let lastChange = try #require(run.calls.last { $0.frame.swell != nil }).time
        let final = run.calls.last!.selection.selected
        #expect(settles(run, on: final, from: lastChange + 0.2, within: layout.look.wobble))
    }

    @Test func settlingWobblesAndThenNothingMovesUntilTheFingersDo() throws {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        slide(hand, toMM: 24, overMS: 200)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout

        let lastChange = try #require(run.calls.last { $0.frame.swell != nil })
        #expect(run.calls.filter { $0.time > at(0.2) }.allSatisfy { $0.frame.isEmpty })
        for call in run.calls {
            for track in call.frame.tracks { #expect(Double(track.offsets.count - 1) * track.step <= 1 + 1e-9) }
        }
        let farEdge = instants(of: run, from: lastChange.time).map {
            run.played(at: $0).swell.maxX - layout.swell(at: 2).maxX
        }
        #expect(crossings(farEdge) >= 2)
        let still = instants(of: run, from: at(1.2))
        let settled = run.played(at: still[0])
        #expect(settled.swell == layout.swell(at: 2))
        #expect(still.allSatisfy { run.played(at: $0) == settled })
    }

    @Test(arguments: ["slowFlow", "undamped"])
    func noLookCanBreakTheTwoHundredMillisecondOrOneSecondBounds(name: String) throws {
        var look = LiquidLook()
        if name == "slowFlow" { look.flowTime = 0.5 } else { look.wobbleDamping = 0 }
        let hand = World.liquidSwipe(apps: World.fiveApps, look: look)
        slide(hand, toMM: 12, overMS: 100)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout

        let change = try #require(run.calls.last { $0.frame.swell != nil })
        #expect(settles(run, on: 1, from: change.time + 0.2, within: layout.look.wobble))
        let still = instants(of: run, from: at(1.1))
        #expect(still.allSatisfy { run.played(at: $0).swell == layout.swell(at: 1) })
    }

    @Test func aNewSwipeStartsSettledWithNothingCarriedOver() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.move(toMM: 36, atMS: 10)
        hand.move(toMM: 36, atMS: 20)
        let flying = hand.run
        #expect(flying.layout.swell(at: 3).maxX - flying.played(at: at(0.02)).swell.maxX > 10)

        hand.end(atMS: 21)
        hand.begin(atMS: 71)
        let run = hand.run

        #expect(run.calls.count == 1)
        #expect(
            run.calls[0].frame == LiquidFrame(swell: run.layout.swell(at: 0), icon: IconChange(selected: 0, duration: 0)))
        let played = run.played(at: run.opened)
        #expect(played.swell == run.layout.swell(at: 0) && played.beads == (0..<5).map { run.layout.bead(at: $0) })
        #expect(played.iconScales == [1.12, 1, 1, 1, 1])
    }

    @Test func liftingDuringAFlowBringsTheSelectedAppToTheFrontAtOnce() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.move(toMM: 36, atMS: 10)
        hand.move(toMM: 36, atMS: 20)
        #expect(hand.run.layout.swell(at: 3).maxX - hand.run.played(at: at(0.02)).swell.maxX > 10)

        hand.end(atMS: 21)

        #expect(hand.world.system.broughtToFront == [hand.world.app("Notes")])
        #expect(hand.world.hardware.pulses.last == .init(haptic: .gesture, trackpad: Trackpad.macBook14.id))
        #expect(hand.world.launcher.switcher == nil)
    }

    @Test func everyTrackIsSampledAtTheDisplayRateAndTheSwellAlwaysHasOneInFlight() {
        let hand = World.liquidSwipe(apps: World.tenApps)
        slide(hand, toMM: 48, overMS: 600)
        hand.rest(forMS: 2000)
        let frames = hand.run.calls.filter { !$0.frame.isEmpty }

        for (index, call) in frames.enumerated() {
            for track in call.frame.tracks {
                #expect(track.step <= 1.0 / 120 + 1e-12 && track.offsets.count >= 2)
                guard index + 1 < frames.count, !track.holds else { continue }
                #expect(
                    track.begin.seconds + Double(track.offsets.count - 1) * track.step >= frames[index + 1].time.seconds)
            }
        }
    }
}
