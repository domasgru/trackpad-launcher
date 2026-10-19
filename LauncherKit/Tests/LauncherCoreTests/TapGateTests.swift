import Testing
import LauncherCore

@MainActor @Suite struct TapGateTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    private func world() -> World { World.switcherWorld(accessGranted: true) }

    @Test func fortySecondsOfOrdinaryScrollingNeverOpensTheGate() {
        let world = world()
        let script = TouchScript(.macBook14).land(fingers: 2).slide(byMM: (0, 400), over: .seconds(40))
        let observed = world.playFrameByFrame(script) { world.hardware.isGatedPortOn }
        #expect(observed.count > 4000)
        #expect(observed.allSatisfy { !$0 })

        let hardware = world.hardware
        #expect(hardware.offer(.scroll(.fingers(.changed))) == .notSent)
        #expect(hardware.offer(.pointer(.drag(button: 0))) == .notSent)
        #expect(hardware.offer(.pointer(.pressure)) == .notSent)
        #expect(hardware.offer(.dockSwipe(.changed, .gesture)) == .notSent)
        #expect(hardware.offer(.dockSwipe(.changed, .dockControl)) == .notSent)
        #expect(hardware.offer(.pointer(.release(PressID(button: 2, number: 7)))) == .decided(.pointer(.pass)))
        #expect(hardware.scroll(.fingers(.changed)) == .pass)
        #expect(hardware.isBlockingClicks)
    }

    @Test func aPressedDragAwayFromTheCornerNeverOpensTheGate() {
        let world = world()
        let script = TouchScript(.macBook14).tap(fingers: 1, dragMM: (0, 30), click: .firm)
        var offers: [InMemoryTrackpads.Delivery] = []
        var count = 0
        let observed = world.playFrameByFrame(script) {
            count += 1
            if count == 8 {
                offers.append(world.hardware.offer(.pointer(.drag(button: 0))))
                offers.append(world.hardware.offer(.pointer(.pressure)))
            }
            return world.hardware.isGatedPortOn
        }
        #expect(observed.allSatisfy { !$0 })
        #expect(offers == [.notSent, .notSent])
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.launcher.switcher == nil)
    }

    @Test func theGateOpensOnTheThumbsFrameAndHoldsForTheFingersWakeStillPending() {
        let world = world()
        let rest = thumb.wait(.milliseconds(200))
        let observed = world.playFrameByFrame(rest) { world.hardware.isGatedPortOn }
        #expect(observed.allSatisfy { $0 })
        #expect(world.hardware.scroll(.unphased) == .pass)
        #expect(world.hardware.offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.pass)))
        #expect(world.playFrameByFrame(rest.liftThumb()) { world.hardware.isGatedPortOn }.last == false)

        let late = self.world()
        late.play(thumb)
        late.hardware.withLateWakes {
            late.play(thumb.wait(.milliseconds(10)).land(fingers: 2))
            #expect(late.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop)))
        }
        #expect(late.hardware.isGatedPortOn)
    }

    @Test func aThumbAndAFingerOnOneFrameAreHeardOnlyOnceTheOpenHasRun() {
        let landing = [h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)])]
        let late = world()
        late.hardware.withLateWakes {
            late.hardware.touch(landing, on: trackpad.id)
            #expect(!late.hardware.isGatedPortOn)
            #expect(late.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)
        }
        #expect(late.hardware.isGatedPortOn)
        #expect(late.hardware.scroll(.fingers(.began)) == .passStill)

        let prompt = world()
        prompt.hardware.touch(landing, on: trackpad.id)
        #expect(prompt.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop)))
        #expect(prompt.hardware.scroll(.fingers(.began)) == .drop)
    }

    @Test func aThumbLandingUnderRestingFingersKeepsAScrollTheAppsAlreadyHaveWhole() {
        let world = world()
        let rest = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
        world.play(rest)
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)
        world.play(rest.wait(.milliseconds(10)).thumb(atMM: (10, 10)).slide(byMM: (10, 0)))
        #expect(world.hardware.scroll(.fingers(.began)) == .passStill)
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)

        let swap = self.world()
        swap.play(rest)
        #expect(swap.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)
        swap.play(rest.wait(.milliseconds(10)).thumbTap().slide(byMM: (10, 0)))
        #expect(swap.hardware.scroll(.fingers(.began)) == .passStill)
    }

    @Test func aSwipesScrollStaysDroppedThroughTheLiftsAndTheMomentumAndTheGateClosesAfterTheLast() {
        let world = world()
        let swipe = thumb.land(fingers: 2).slide(byMM: (10, 0))
        world.play(swipe)
        #expect(world.hardware.offer(.scroll(.fingers(.began))) == .decided(.scroll(.drop)))

        let lifted = world.playFrameByFrame(swipe.lift().liftThumb()) { world.hardware.isGatedPortOn }
        #expect(lifted.allSatisfy { $0 })
        for event: ScrollEvent in [.fingers(.ended), .momentum(.began), .momentum(.changed)] {
            #expect(world.hardware.offer(.scroll(event)) == .decided(.scroll(.drop)))
            #expect(world.hardware.isGatedPortOn)
        }
        #expect(world.hardware.offer(.scroll(.momentum(.ended))) == .decided(.scroll(.drop)))
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)
    }

    @Test func aStilledScrollStaysStilledThroughTheLiftsAndItsMomentum() {
        let world = world()
        let early = thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (2, 0))
        world.play(early)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
        let slid = early.slide(byMM: (10, 0))
        world.play(slid)
        #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)

        let lifted = world.playFrameByFrame(slid.lift().liftThumb()) { world.hardware.isGatedPortOn }
        #expect(lifted.allSatisfy { $0 })
        for event: ScrollEvent in [.fingers(.ended), .momentum(.began), .momentum(.ended)] {
            #expect(world.hardware.offer(.scroll(event)) == .decided(.scroll(.passStill)))
        }
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func aPressStaysWithheldThroughTheThumbsLiftUntilTheButtonIsUp() {
        let world = world()
        let thumbDown = h.contact(9, atMM: 10, 10)
        let finger = h.contact(1, atMM: 62, 45)
        let frames: [(ms: Int, frame: TouchFrame)] = [
            (0, h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)])),
            (100, h.frame(atMS: 100, [thumbDown, h.contact(1, .landing, atMM: 62, 45)])),
            (110, h.frame(atMS: 110, [thumbDown, finger], press: .click)),
            (200, h.frame(atMS: 200, [finger], press: .click)),
            (250, h.frame(atMS: 250, [finger], press: .click)),
            (300, h.frame(atMS: 300, [finger])),
            (350, h.frame(atMS: 350)),
        ]
        var gated: [Int: Bool] = [:]
        var between: [InMemoryTrackpads.Delivery] = []
        var after: InMemoryTrackpads.Delivery?
        for (ms, frame) in frames {
            if ms == 300 {
                between.append(world.hardware.offer(.pointer(.drag(button: 0))))
                between.append(world.hardware.offer(.pointer(.pressure)))
            }
            world.hardware.touch([frame], on: trackpad.id)
            gated[ms] = world.hardware.isGatedPortOn
            if ms == 300 { after = world.hardware.offer(.pointer(.drag(button: 0))) }
        }
        #expect([100, 110, 200, 250].allSatisfy { gated[$0] == true })
        #expect(between == [.decided(.pointer(.passAsMove)), .decided(.pointer(.drop))])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(gated[300] == true)
        #expect(after == .decided(.pointer(.pass)))
        #expect(gated[350] == false)
    }

    @Test func aDockSwipeDroppedAtItsStartStaysDroppedUntilItsOwnStreamEnds() {
        let world = world()
        let hand = thumb.land(fingers: 2)
        world.play(hand)
        #expect(world.hardware.offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(world.hardware.offer(.dockSwipe(.began, .dockControl)) == .decided(.dockSwipe(.drop)))
        world.play(hand.lift().liftThumb())
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.dockSwipe(.changed, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(world.hardware.offer(.dockSwipe(.ended, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.dockSwipe(.ended, .dockControl)) == .decided(.dockSwipe(.drop)))
        #expect(!world.hardware.isGatedPortOn)

        let alone = self.world()
        alone.play(thumb)
        #expect(alone.hardware.offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.pass)))
        alone.play(thumb.liftThumb())
        #expect(!alone.hardware.isGatedPortOn)
    }

    @Test func aPassingScrollWhoseEndWasNeverSeenHoldsNothingOpenAndDoesNotStillTheNextHand() {
        let world = world()
        let late = thumb.wait(.seconds(4)).land(fingers: 2)
        world.play(late)
        #expect(world.hardware.scroll(.fingers(.mayBegin)) == .pass)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)

        let lifted = late.lift().liftThumb()
        world.play(lifted)
        #expect(!world.hardware.isGatedPortOn)

        world.play(lifted.thumb(atMM: (10, 10)).land(fingers: 2))
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.drop)))
    }

    @Test func aScrollWhoseStartWentUnsentAndWhoseEndWasDecidedDoesNotLeaveALaterThumbFirstHandUnseen() {
        let world = world()
        let resting = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(100))
        world.play(resting)
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .notSent)

        let thumbUnder = resting.thumb(atMM: (10, 10)).wait(.milliseconds(100))
        world.play(thumbUnder)
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.scroll(.fingers(.ended))) == .decided(.scroll(.passStill)))

        let lifted = thumbUnder.lift().liftThumb()
        world.play(lifted)
        #expect(world.hardware.offer(.scroll(.momentum(.ended))) == .decided(.scroll(.passStill)))
        #expect(!world.hardware.isGatedPortOn)

        let fresh = lifted.thumb(atMM: (10, 10)).wait(.milliseconds(200)).land(fingers: 2)
        world.play(fresh)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
    }

    @Test func aDroppedSwipeWithNoMomentumLeavesTheGateOpenUntilTheNextScrollEventPasses() {
        let world = world()
        let swipe = thumb.land(fingers: 2).slide(byMM: (10, 0))
        world.play(swipe)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)

        let lifted = swipe.lift().liftThumb()
        world.play(lifted)
        #expect(world.hardware.isGatedPortOn)

        world.play(lifted.land(fingers: 2, atMM: (62, 45)))
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.pass)))
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func aPassedPressAndATapOnTheThumbsWayInAndOutNeverFiresAnApp() {
        func world() -> World {
            let world = World(apps: ["Arc"], accessGranted: true)
            world.launcher.start()
            world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
            return world
        }
        let thumbDown = h.contact(9, atMM: 10, 10)
        let finger = h.contact(1, atMM: 62, 45)
        let straight = world()
        straight.hardware.touch(
            [
                h.frame(atMS: 0, press: .click),
                h.frame(atMS: 50, [h.contact(9, .landing, atMM: 10, 10)], press: .click),
                h.frame(atMS: 100, [thumbDown, h.contact(1, .landing, atMM: 62, 45)], press: .click),
                h.frame(atMS: 150, [thumbDown, finger], press: .click),
                h.frame(atMS: 200, [thumbDown], press: .click),
                h.frame(atMS: 300, [thumbDown]),
            ], on: trackpad.id)
        #expect(straight.system.broughtToFront.isEmpty)
        #expect(straight.hardware.pressVerdicts == [.pass, .pass])

        let bounced = world()
        bounced.hardware.touch(
            [
                h.frame(atMS: 0, press: .click),
                h.frame(atMS: 50, [h.contact(9, .landing, atMM: 10, 10)], press: .click),
                h.frame(atMS: 100, [thumbDown], press: .click),
                h.frame(atMS: 150, press: .click),
                h.frame(atMS: 200, [h.contact(9, .landing, atMM: 10, 10)], press: .click),
                h.frame(atMS: 250, [thumbDown, h.contact(1, .landing, atMM: 62, 45)], press: .click),
                h.frame(atMS: 300, [thumbDown, finger], press: .click),
                h.frame(atMS: 350, [thumbDown], press: .click),
                h.frame(atMS: 400, [thumbDown]),
            ], on: trackpad.id)
        #expect(bounced.system.broughtToFront.isEmpty)
        #expect(bounced.hardware.pressVerdicts == [.pass, .pass])
    }

    @Test func theGateStaysOpenThroughARolledThumbAndTheFingersLiftsUntilThePadIsEmpty() {
        let world = world()
        let hand = thumb.land(fingers: 2).slide(byMM: (10, 0)).rollThumb(toMM: (40, 10)).lift()
            .land(fingers: 2).wait(.milliseconds(50))
        let observed = world.playFrameByFrame(hand) { world.hardware.isGatedPortOn }
        #expect(observed.allSatisfy { $0 })
    }

    @Test func aDockSwipeOpeningAfterTheThumbRolledOutIsDroppedWholeAndHoldsTheGateToItsEnd() {
        let world = world()
        let hand = thumb.land(fingers: 2).slide(byMM: (10, 0)).rollThumb(toMM: (40, 10)).lift()
            .land(fingers: 2).wait(.milliseconds(50))
        world.play(hand)
        var offers = [world.hardware.offer(.dockSwipe(.mayBegin, .gesture))]
        let slid = hand.slide(byMM: (20, 0))
        world.play(slid)
        offers.append(world.hardware.offer(.dockSwipe(.began, .gesture)))
        offers.append(world.hardware.offer(.dockSwipe(.changed, .gesture)))
        world.play(slid.lift().liftThumb())
        #expect(world.hardware.isGatedPortOn)
        offers.append(world.hardware.offer(.dockSwipe(.ended, .gesture)))
        #expect(offers == Array(repeating: .decided(.dockSwipe(.drop)), count: 4))
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func aDockSwipeWarningThatSlippedThroughIsDroppedFromItsBeganOnceTheFingersAreDown() {
        let world = world()
        world.play(thumb.wait(.milliseconds(100)))
        #expect(world.hardware.offer(.dockSwipe(.mayBegin, .gesture)) == .decided(.dockSwipe(.pass)))

        let hand = thumb.wait(.milliseconds(100)).land(fingers: 2).wait(.milliseconds(500))
        world.play(hand)
        #expect(world.hardware.offer(.dockSwipe(.began, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(world.hardware.offer(.dockSwipe(.changed, .gesture)) == .decided(.dockSwipe(.drop)))

        world.play(hand.lift().liftThumb())
        #expect(world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.dockSwipe(.ended, .gesture)) == .decided(.dockSwipe(.drop)))
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.system.broughtToFront.isEmpty)
    }
}
