import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct LiquidTests {
    private func close(_ value: Double, _ expected: Double, within tolerance: Double = 0.01) -> Bool {
        abs(value - expected) < tolerance
    }

    /// The row of one app: no app in front, one other app running.
    private func oneAppHand(displayWidth: Double = 1512) -> LiquidSwipe {
        World.liquidSwipe(apps: ["Safari"], frontmost: nil, displayWidth: displayWidth)
    }

    /// How tall the shape is at `x`: the tallest rect that spans it.
    private func height(of played: Played, at x: Double) -> Double {
        ([played.band, played.swell] + played.beads)
            .filter { $0.minX <= x && x <= $0.maxX }.map(\.height).max() ?? 0
    }

    // MARK: Geometry at full size

    @Test func fiveAppsAreOneUnbrokenShapeWithASwellAroundTheFirstIconAndABeadAroundEachOther() {
        let hand = World.liquidSwipe(apps: World.fiveApps)
        hand.begin()
        hand.rest(forMS: 1000)
        let run = hand.run
        let layout = run.layout

        #expect(
            run.calls[0].frame
                == LiquidFrame(swell: layout.swell(at: 0), icon: IconChange(selected: 0, duration: 0), tracks: []))
        #expect(layout.panelSize.width == 560 && layout.panelSize.height == 160)
        #expect(close(layout.radii.bead, 25.6) && close(layout.radii.swell, 33.28))

        for instant in run.instants {
            let played = run.played(at: instant)
            #expect(played.band.isClose(to: LiquidRect(minX: 80, minY: 54, width: 400, height: 52)))
            #expect(played.beads.count == 5)
            for (index, bead) in played.beads.enumerated() {
                #expect(bead.isClose(to: LiquidRect(minX: 40 + 100 * Double(index), minY: 40, width: 80, height: 80)))
                #expect(bead.overlaps(played.band))
            }
            #expect(played.swell.isClose(to: LiquidRect(minX: 28, minY: 28, width: 104, height: 104)))
            #expect(played.swell.overlaps(played.band))
            #expect(height(of: played, at: 180) == 80 && height(of: played, at: 280) == 80)
            #expect(height(of: played, at: 230) == 52)
            #expect(close(played.beads[1].minX - played.swell.maxX, 8))
            let grown = LiquidRect.centred(x: 80, y: 80, width: 71.68, height: 71.68)
            #expect(played.swell.contains(grown) && played.iconScales[0] == 1.12)
            for index in 1..<5 {
                let body = LiquidRect.centred(x: layout.centreX(at: Double(index)), y: 80, width: 64, height: 64)
                #expect(played.beads[index].contains(body) && played.iconScales[index] == 1)
            }
        }
    }

    @Test func spareBeadsLieExactlyOverTheBandAndAOneAppRowIsTheSwellAlone() {
        let one = oneAppHand()
        one.begin()
        one.rest(forMS: 100)
        let layout = one.run.layout
        #expect(layout.iconCount == 1)
        #expect(layout.band == layout.bead(at: 0))
        #expect(layout.radii.band == layout.radii.bead)
        for spare in 1..<10 { #expect(layout.bead(at: spare) == layout.band) }
        for instant in one.run.instants {
            let played = one.run.played(at: instant)
            #expect(played.beads == [layout.bead(at: 0)])
            #expect(played.swell.contains(played.band) && played.swell.contains(played.beads[0]))
        }

        let two = World.liquidSwipe(apps: ["Safari", "Mail"])
        two.begin()
        let twoLayout = two.run.layout
        #expect(twoLayout.radii.band == 26)
        for spare in 2..<10 { #expect(twoLayout.bead(at: spare) == twoLayout.band) }

        let ten = World.liquidSwipe(apps: World.tenApps)
        ten.begin()
        #expect(ten.run.layout.iconCount == 10)
        #expect(ten.run.played(at: ten.run.opened).beads.count == 10)
    }

    // MARK: A narrow display

    @Test func aTenAppRowOnANarrowDisplayShrinksEverythingByOneFactor() {
        let hand = World.liquidSwipe(apps: World.tenApps, displayWidth: 1024)
        hand.begin()
        hand.rest(forMS: 100)
        let layout = hand.run.layout
        let factor = 1024.0 / 1060

        #expect(layout.scale < 1 && close(layout.scale, factor, within: 1e-9))
        #expect(close(layout.iconSide, 80 * factor) && close(layout.pitch, 100 * factor))
        #expect(close(layout.bead(at: 3).width, 80 * factor) && close(layout.band.height, 52 * factor))
        #expect(close(layout.swell(at: 0).width, 104 * factor))
        #expect(close(layout.radii.bead, 25.6 * factor) && close(layout.radii.band, 26 * factor))
        #expect(close(layout.radii.swell, 33.28 * factor) && close(layout.spacing, 40 * factor))
        #expect(layout.panelSize.width <= 1024 + 1e-9)
        for instant in hand.run.instants {
            let played = hand.run.played(at: instant)
            for index in 0..<10 {
                let body = LiquidRect.centred(
                    x: layout.centreX(at: Double(index)), y: layout.centreY, width: 64 * factor, height: 64 * factor)
                let home = index == 0 ? played.swell : played.beads[index]
                #expect(home.contains(body))
            }
        }
    }

    @Test func aTenAppRowFitsAt1060PointsAndShrinksBelowIt() {
        for (width, fits) in [(1060.0, true), (1059.0, false)] {
            let hand = World.liquidSwipe(apps: World.tenApps, displayWidth: width)
            hand.begin()
            #expect((hand.run.layout.scale == 1) == fits)
            #expect(hand.run.layout.scale <= 1)
        }
    }

    // MARK: Reduce Motion

    @Test func withReduceMotionTheSwellJumpsToTheNextIconAndNothingElseIsStaged() {
        let hand = World.liquidSwipe(apps: World.fiveApps, motion: .still)
        let script = TouchScript(Trackpad.macBook14.surface).thumb(atMM: (10, 10)).land(fingers: 2)
            .slide(byMM: (3.5, 0)).slide(byMM: (7, 0))
        hand.play(script)
        hand.rest(forMS: 2000)
        let run = hand.run
        let layout = run.layout

        let moved = run.calls.filter { !$0.frame.isEmpty }
        #expect(moved.count == 2)
        #expect(
            moved[1].frame
                == LiquidFrame(swell: layout.swell(at: 1), icon: IconChange(selected: 1, duration: 0), tracks: []))
        #expect(moved.allSatisfy { $0.frame.tracks.isEmpty })
        let jump = moved[1].time
        for instant in run.instants {
            let played = run.played(at: instant)
            #expect(played.swell == (instant < jump ? layout.swell(at: 0) : layout.swell(at: 1)))
            #expect(played.beads == (0..<5).map { layout.bead(at: $0) })
        }
    }

    @Test func pushingPastTheLastAppWithReduceMotionStagesNothingAndAFlickNamesOnlyTheIconItLandsOn() {
        let push = World.liquidSwipe(apps: World.fiveApps, motion: .still)
        push.begin()
        push.move(toMM: 48, atMS: 10)
        let arrived = push.run.calls.count
        for step in 1...50 { push.move(toMM: 48 + 0.1 * Double(step), atMS: 10 + 10 * step) }
        push.rest(forMS: 500)
        let pushRun = push.run
        #expect(pushRun.calls[arrived...].allSatisfy { $0.frame.isEmpty })
        #expect(pushRun.played(at: pushRun.last).swell == pushRun.layout.swell(at: 4))

        let flick = World.liquidSwipe(apps: World.fiveApps, motion: .still)
        flick.begin()
        flick.move(toMM: 36, atMS: 10)
        flick.rest(forMS: 500)
        let named = flick.run.calls.compactMap(\.frame.icon).map(\.selected)
        #expect(named == [0, 3])
        #expect(flick.run.calls.compactMap(\.frame.swell) == [flick.run.layout.swell(at: 0), flick.run.layout.swell(at: 3)])
    }

    // MARK: The shape knobs

    @Test func aSubtleSwellChangesNothingButTheSwell() {
        var subtle = LiquidLook()
        subtle.swellRise = 3
        for (apps, width) in [(World.fiveApps, 1512.0), (World.tenApps, 1024.0)] {
            let shipped = World.liquidSwipe(apps: apps, displayWidth: width)
            let soft = World.liquidSwipe(apps: apps, displayWidth: width, look: subtle)
            shipped.begin()
            soft.begin()
            let a = shipped.run.layout, b = soft.run.layout

            #expect(close(b.swell(at: 0).width, (80 + 6) * b.scale))
            #expect(close(b.swellRise, 3 * b.scale))
            #expect(a.scale == b.scale && a.panelSize == b.panelSize && a.band == b.band)
            #expect((0..<10).allSatisfy { a.bead(at: $0) == b.bead(at: $0) })
            #expect(a.radii.band == b.radii.band && a.radii.bead == b.radii.bead && a.pitch == b.pitch)
            #expect(a.spacing == b.spacing && a.beadLimits == b.beadLimits)
            #expect(a.beadLimits.upperBound == 104 * a.scale)
            for index in 0..<a.iconCount {
                #expect(a.centreX(at: Double(index)) - a.panelSize.width / 2 == b.centreX(at: Double(index)) - b.panelSize.width / 2)
            }
        }
    }

    @Test(arguments: ["beadSide", "beadCorner", "bandThickness", "spacing", "swellRise", "swellCorner"])
    func eachShapeKnobMovesOnlyTheOutputItNames(knob: String) {
        var look = LiquidLook()
        switch knob {
        case "beadSide": look.beadSide *= 1.25
        case "beadCorner": look.beadCorner *= 1.25
        case "bandThickness": look.bandThickness *= 1.25
        case "spacing": look.spacing *= 1.25
        case "swellRise": look.swellRise *= 1.25
        default: look.swellCorner *= 1.25
        }
        let hand = World.liquidSwipe(apps: World.fiveApps, look: look)
        hand.begin()
        let layout = hand.run.layout

        #expect(layout.iconSide == 80 && layout.pitch == 100)
        #expect(close(layout.centreX(at: 4) - layout.centreX(at: 0), 400))
        #expect(layout.bead(at: 0).width == (knob == "beadSide" ? 100 : 80))
        #expect(close(layout.radii.bead, knob == "beadSide" ? 32 : knob == "beadCorner" ? 32 : 25.6))
        #expect(close(layout.band.height, knob == "bandThickness" ? 65 : 52))
        #expect(layout.spacing == (knob == "spacing" ? 50 : 40))
        #expect(close(layout.swell(at: 0).width, knob == "swellRise" ? 110 : knob == "beadSide" ? 124 : 104))
        let swellSide = layout.swell(at: 0).width
        #expect(close(layout.radii.swell, (knob == "swellCorner" ? 0.4 : 0.32) * swellSide))
    }
}
