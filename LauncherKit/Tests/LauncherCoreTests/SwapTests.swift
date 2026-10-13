import Testing
import LauncherCore

@MainActor @Suite struct SwapTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()

    private func rest() -> TouchScript { TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150)) }

    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.system.launchAnimations.isEmpty
            && world.launcher.switcher == nil
    }

    @Test func theThumbLiftingSwapsToThePreviousAppWithTheHapticAndNoAnimationAndClosesTheWindow() {
        let world = World.switcherWorld()
        world.launcher.openWindow()
        let base = rest()

        world.play(base.thumb(atMM: (10, 10)))
        #expect(nothingHappened(world))
        #expect(world.launcher.isWindowOpen)

        let tapped = base.thumbTap(hold: .milliseconds(60))
        world.play(tapped)
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses == [.init(haptic: .gesture, trackpad: trackpad.id)])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.launcher.switcher == nil)
        #expect(!world.launcher.isWindowOpen)

        world.play(tapped.lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.count == 1)
    }

    @Test func leftHandSwapsFromTheTopRightCornerOnly() {
        let left = World.switcherWorld()
        left.launcher.setHandMode(.left)
        left.play(rest().thumbTap(atMM: (114.8, 10)))
        #expect(left.system.broughtToFront == [left.app("Mail")])

        let right = World.switcherWorld()
        right.play(rest().thumbTap(atMM: (114.8, 10)))
        #expect(nothingHappened(right))
    }

    @Test func aThumbThatRestsTooLongOrDragsSwapsNothing() {
        let held = World.switcherWorld()
        held.play(rest().thumbTap(hold: .milliseconds(500)))
        #expect(nothingHappened(held))

        let dragged = World.switcherWorld()
        dragged.play(rest().thumbTap(dragMM: 3.5))
        #expect(nothingHappened(dragged))
    }

    @Test func aFirmThumbTapSwapsAndItsPressNeverReachesApps() {
        let world = World.switcherWorld(accessGranted: true)
        world.play(rest().thumbTap(click: .firm))
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }

    @Test func withoutAccessibilityAFirmThumbTapStillSwapsAndNoFilterIsArmed() {
        let pressed = World.switcherWorld()
        pressed.play(rest().thumbTap(click: .firm))
        #expect(pressed.system.broughtToFront == [pressed.app("Mail")])
        #expect(pressed.hardware.pressVerdicts.isEmpty)

        let after = World.switcherWorld()
        let script = after.swap(lift: false)
        after.play(script.press().lift())
        #expect(after.system.broughtToFront == [after.app("Mail")])
        #expect(after.hardware.pressVerdicts.isEmpty)
        #expect(!after.hardware.isBlockingClicks)
    }

    @Test func aMenuBarAppInFrontIsSkippedAndNoFrontmostAppSwapsToTheFirstRunningApp() {
        let menuBar = World(apps: ["Bartender", "Safari", "Mail"])
        menuBar.launcher.start()
        menuBar.makeRunning(["Safari", "Mail"])
        menuBar.makeFrontmost("Bartender")
        menuBar.swap()
        #expect(menuBar.system.broughtToFront == [menuBar.app("Safari")])

        let none = World(apps: ["Safari", "Mail"])
        none.launcher.start()
        let finder = none.app("Finder", in: none.coreServices)
        none.makeRunning([finder, none.app("Safari"), none.app("Mail")])
        none.makeFrontmost(nil)
        none.swap()
        #expect(none.system.broughtToFront == [finder])
    }

    @Test func tapsAfterEachActivationLandedAlternateBetweenTheTwoApps() {
        let world = World.switcherWorld()
        var script = world.swap(lift: false)
        world.activate("Mail")
        script = script.thumbTap()
        world.play(script)
        world.activate("Safari")
        script = script.thumbTap()
        world.play(script)

        #expect(world.system.broughtToFront == [world.app("Mail"), world.app("Safari"), world.app("Mail")])
        #expect(world.hardware.feedback.count == 3)
    }

    @Test func whenThePreviousAppQuitsBetweenTapsTheNextOneInTheOrderComesForward() {
        let world = World(apps: ["Safari", "Mail", "Notes"])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Notes"])
        world.makeFrontmost("Safari")
        var script = world.swap(lift: false)
        world.makeFrontmost("Mail")
        world.makeRunning(["Mail", "Notes"])
        script = script.thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail"), world.app("Notes")])
    }

    @Test func whenAnotherAppActivatesBetweenTapsTheSecondTapBringsTheFormerFrontAppBack() {
        let world = World(apps: ["Safari", "Mail", "Slack", "Notes", "Calendar"])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Slack", "Notes"])
        world.makeFrontmost("Safari")
        var script = world.swap(lift: false)
        world.makeFrontmost("Calendar")
        world.makeRunning(["Calendar", "Mail", "Safari", "Slack", "Notes"])
        script = script.thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail"), world.app("Mail")])
    }

    @Test func withNothingToSwapToNothingHappensAndTheWindowStaysOpen() {
        let only = World(apps: ["Safari"])
        only.launcher.start()
        let finder = only.app("Finder", in: only.coreServices)
        only.makeRunning([finder])
        only.system.frontmost = finder
        only.launcher.openWindow()
        only.swap()
        #expect(nothingHappened(only))
        #expect(only.launcher.isWindowOpen)

        let empty = World.switcherWorld()
        empty.makeRunning([String]())
        empty.makeFrontmost(nil)
        empty.swap()
        #expect(nothingHappened(empty))
    }

    @Test func oneOrThreeRestingFingersSwapNothingButAnEdgeContactDoesNotCount() {
        let one = World.switcherWorld()
        one.play(TouchScript(.macBook14).land(fingers: 1).wait(.milliseconds(150)).thumbTap())
        #expect(nothingHappened(one))

        let three = World.switcherWorld()
        three.play(TouchScript(.macBook14).land(fingers: 3).wait(.milliseconds(150)).thumbTap())
        #expect(nothingHappened(three))

        let palm = World.switcherWorld()
        palm.play(
            TouchScript(.macBook14).land(fingers: 1, atMM: (123.8, 45)).land(fingers: 2)
                .wait(.milliseconds(150)).thumbTap())
        #expect(palm.system.broughtToFront == [palm.app("Mail")])
    }

    @Test func fingersThatLandedJustBeforeTheThumbDoNotSwap() {
        let world = World.switcherWorld()
        world.hardware.touch([
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 20, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 60, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 100),
        ], on: trackpad.id)
        #expect(nothingHappened(world))
    }

    @Test func aThumbThatLandsFirstIsStillATapGestureOrASwipe() {
        let gesture = World.switcherWorld()
        gesture.launcher.setAssignment(.app(gesture.app("Notes")), for: .two)
        gesture.tap(2)
        #expect(gesture.system.broughtToFront == [gesture.app("Notes")])
        #expect(gesture.hardware.pulses == [.init(haptic: .gesture, trackpad: trackpad.id)])

        let swipe = World.switcherWorld()
        let script = swipe.swipe(3.5, 12, lift: false)
        #expect(swipe.launcher.switcher != nil)
        swipe.play(script.lift())
        #expect(swipe.system.broughtToFront == [swipe.app("Mail")])
        #expect(swipe.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])
    }

    @Test func aHeldThumbBecomesTheAnchorOnceTheFingersLiftAndNoSwapHappens() {
        let world = World.switcherWorld()
        world.launcher.setAssignment(.app(world.app("Notes")), for: .two)
        world.play(rest().thumb(atMM: (10, 10)).wait(.milliseconds(500)).lift().tap(fingers: 2))
        #expect(world.system.broughtToFront == [world.app("Notes")])
        #expect(world.hardware.feedback.count == 1)
    }

    @Test func aThumbThatLiftsAndLandsAgainIsJudgedByItsNewLanding() {
        let world = World.switcherWorld()
        world.hardware.touch([
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 200, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 250, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45), h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 350, [h.contact(1, atMM: 62, 45), h.contact(2, atMM: 70, 45)]),
        ], on: trackpad.id)
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test func fingersThatScrolledBeforeTheTapSwapNothing() {
        let world = World.switcherWorld()
        world.play(rest().slide(byMM: (0, 10)).thumbTap())
        #expect(nothingHappened(world))
    }

    @Test func withTapToClickOnNothingRunsAndASwapEventThatSlipsInIsIgnored() {
        let world = World.switcherWorld()
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        #expect(world.hardware.running.isEmpty)
        world.swap()
        world.hardware.inject(.swap(SwapEvent(startsSeries: true, trackpad: trackpad.id)))
        #expect(nothingHappened(world))
    }

    @Test func rapidTapsAlternateWhetherOrNotTheFirstActivationLandedYet() {
        let stale = World.switcherWorld()
        stale.swap(taps: 4, lift: false)
        #expect(stale.system.broughtToFront == ["Mail", "Safari", "Mail", "Safari"].map { stale.app($0) })

        let landed = World.switcherWorld()
        var script = landed.swap(lift: false)
        landed.activate("Mail")
        for _ in 0..<3 { script = script.thumbTap() }
        landed.play(script)
        #expect(landed.system.broughtToFront == ["Mail", "Safari", "Mail", "Safari"].map { landed.app($0) })
    }

    @Test func slightDriftBetweenTapsKeepsTheSeriesGoingFromWhereTheFingersWereAtTheLastSwap() {
        let small = World.switcherWorld()
        var script = small.swap(lift: false)
        small.activate("Mail")
        script = script.slide(byMM: (1, 0)).thumbTap()
        small.play(script)
        #expect(small.system.broughtToFront == [small.app("Mail"), small.app("Safari")])

        let cumulative = World.switcherWorld()
        script = cumulative.swap(lift: false)
        cumulative.activate("Mail")
        script = script.slide(byMM: (2, 0)).thumbTap()
        cumulative.play(script)
        cumulative.activate("Safari")
        script = script.slide(byMM: (2, 0)).thumbTap()
        cumulative.play(script)
        #expect(cumulative.system.broughtToFront == ["Mail", "Safari", "Mail"].map { cumulative.app($0) })
    }

    @Test func slidingEndsTheSeriesUntilBothFingersLiftAndLandAgain() {
        let world = World.switcherWorld()
        var script = world.swap(lift: false)
        world.activate("Mail")
        script = script.slide(byMM: (10, 0)).thumbTap().thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail")])

        script = script.lift().land(fingers: 2).wait(.milliseconds(150)).thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail"), world.app("Safari")])
    }

    @Test func aFingerThatLiftsAndLandsAgainRejoinsTheSeries() {
        let one = World.switcherWorld()
        var script = one.swap(lift: false)
        one.activate("Mail")
        script = script.lift(.first).land(fingers: 1).wait(.milliseconds(150)).thumbTap()
        one.play(script)
        #expect(one.system.broughtToFront == [one.app("Mail"), one.app("Safari")])

        let both = World.switcherWorld()
        script = both.swap(lift: false)
        both.activate("Mail")
        script = script.lift().land(fingers: 2).wait(.milliseconds(150)).thumbTap()
        both.play(script)
        #expect(both.system.broughtToFront == [both.app("Mail"), both.app("Safari")])
    }

    @Test func aThirdFingerStopsTheSeriesUntilEveryFingerLifts() {
        let world = World.switcherWorld()
        var script = world.swap(lift: false)
        world.activate("Mail")
        script = script.land(fingers: 1, atMM: (86, 45)).wait(.milliseconds(150)).thumbTap()
        world.play(script)
        script = script.lift(.last).wait(.milliseconds(150)).thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail")])

        script = script.lift().land(fingers: 2).wait(.milliseconds(150)).thumbTap()
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail"), world.app("Safari")])
    }

    @Test func fromTheFirstSwapUntilTheFingersLiftClicksAndScrollsAreBlocked() {
        let pressed = World.switcherWorld(accessGranted: true)
        var script = pressed.swap(lift: false)
        pressed.play(script.wait(.seconds(5)).press().lift())
        #expect(pressed.hardware.pressVerdicts == [.drop, .drop])

        let slid = World.switcherWorld(accessGranted: true)
        script = slid.swap(lift: false)
        slid.play(script.slide(byMM: (10, 0)))
        #expect(slid.hardware.scroll(.fingers(.began)) == .drop)

        let oneUp = World.switcherWorld(accessGranted: true)
        script = oneUp.swap(lift: false)
        oneUp.play(script.lift(.first).press().lift())
        #expect(oneUp.hardware.pressVerdicts == [.drop, .drop])

        let lifted = World.switcherWorld(accessGranted: true)
        script = lifted.swap(lift: false)
        lifted.play(script.lift())
        #expect(lifted.hardware.scroll(.fingers(.began)) == .pass)
    }
}
