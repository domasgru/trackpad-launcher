import Testing
import LauncherCore

/// Look up and Smart zoom are blocked under an anchored thumb with another finger down and in the lift window, whatever
/// Tap to click is set to; with no thumb they reach the apps as macOS makes them. Look up arrives as a back-to-back pair.
@MainActor @Suite struct TapActionBlockingTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
    private let plain = TouchScript(.macBook14)
    private let droppedPair: [InMemoryTrackpads.Delivery] = [.decided(.tapAction(.drop)), .decided(.tapAction(.drop))]

    private func world(tapToClick: Bool = true, lookUp: Bool = true, accessGranted: Bool = true) -> World {
        let apps = ["Arc", "Figma", "Notes"]
        let world = World(apps: apps, accessGranted: accessGranted)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, apps) { world.launcher.setAssignment(.app(world.app(name)), for: gesture) }
        world.preferences.set(.tapToClick, rawValue: tapToClick ? 1 : 0, for: .builtIn)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: lookUp ? 2 : 0, for: .builtIn)
        return world
    }

    private func lookUpPair(_ world: World) -> [InMemoryTrackpads.Delivery] {
        [world.hardware.offer(.tapAction(.lookUp)), world.hardware.offer(.tapAction(.lookUp))]
    }

    @Test(arguments: [true, false])
    func aThreeFingerTapUnderTheThumbNeverLooksUp(tapToClick: Bool) {
        let world = world(tapToClick: tapToClick)
        world.play(thumb.tap(fingers: 3))

        #expect(lookUpPair(world) == droppedPair)
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func aThreeFingerTapWithNoThumbStillLooksUp() {
        let world = world()
        world.play(plain.tap(fingers: 3))

        #expect(lookUpPair(world) == [.notSent, .notSent])
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func lookUpIsDroppedInTheHalfSecondAfterTheLiftAndReachesAppsOnceTheWindowCloses() {
        let world = world()
        let gesture = thumb.land(fingers: 3).wait(.milliseconds(120)).lift().liftThumb()
        world.play(gesture)
        #expect(lookUpPair(world) == droppedPair)
        #expect(world.hardware.isGatedPortOn)

        world.play(gesture.wait(.milliseconds(600)))
        #expect(lookUpPair(world) == [.notSent, .notSent])
        #expect(!world.hardware.isGatedPortOn)
    }

    @Test func aTapActionBeforeAnyLiftIsDroppedUnderAThumbRestedPastThreeSeconds() {
        let lookUp = world()
        lookUp.play(thumb.wait(.seconds(4)).land(fingers: 3))
        #expect(lookUpPair(lookUp) == droppedPair)

        let zoom = world()
        zoom.play(thumb.wait(.seconds(4)).land(fingers: 2))
        #expect(zoom.hardware.offer(.tapAction(.smartZoom)) == .decided(.tapAction(.drop)))
    }

    @Test(arguments: [true, false])
    func aDoubleTapOfTwoUnderTheThumbNeverZooms(tapToClick: Bool) {
        let world = world(tapToClick: tapToClick)
        world.play(thumb.tap(fingers: 2).wait(.milliseconds(80)).tap(fingers: 2))

        #expect(world.hardware.offer(.tapAction(.smartZoom)) == .decided(.tapAction(.drop)))
        #expect(world.system.broughtToFront == [world.app("Figma"), world.app("Figma")])
    }

    @Test func aDoubleTapOfTwoWithNoThumbStillZooms() {
        let world = world()
        world.play(plain.tap(fingers: 2).wait(.milliseconds(80)).tap(fingers: 2))

        #expect(world.hardware.offer(.tapAction(.smartZoom)) == .notSent)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func smartZoomWithoutAccessHappensAsItDoesAndTurnsNothingOff() {
        let world = world(tapToClick: false, lookUp: false, accessGranted: false)
        world.play(thumb.tap(fingers: 2).wait(.milliseconds(80)).tap(fingers: 2))

        #expect(world.system.broughtToFront == [world.app("Figma"), world.app("Figma")])
        #expect(world.hardware.feedback.count == 2)
        #expect(world.hardware.offer(.tapAction(.smartZoom)) == .noTap)
    }

    @Test func aThumbAloneLetsEveryTapActionThrough() {
        let world = world()
        world.play(thumb.wait(.milliseconds(200)))

        #expect(world.hardware.offer(.tapAction(.lookUp)) == .decided(.tapAction(.pass)))
        #expect(world.hardware.offer(.tapAction(.smartZoom)) == .decided(.tapAction(.pass)))
    }

    @Test func theFirstEventAfterTheWindowClosedClosesTheGateAndTapActionsThenReachAppsUntouched() {
        let world = world()
        world.play(thumb.tap(fingers: 3).liftThumb())
        #expect(world.system.broughtToFront == [world.app("Notes")])

        world.hardware.advanceClock(by: .milliseconds(600))
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.pass)))
        #expect(!world.hardware.isGatedPortOn)
        #expect(world.hardware.offer(.tapAction(.lookUp)) == .notSent)
    }

    /// The gate closed on an event after the window, while the pad sent no frame; the next thumb touch must open it
    /// again, though the last frame before it already wanted the tap.
    @Test func aThumbLandingAfterAnEventClosedTheGateOpensItAgain() {
        let world = world()
        let first = thumb.tap(fingers: 3).liftThumb()
        world.play(first)
        world.hardware.advanceClock(by: .milliseconds(600))
        #expect(world.hardware.offer(.scroll(.fingers(.mayBegin))) == .decided(.scroll(.pass)))
        #expect(!world.hardware.isGatedPortOn)

        world.play(first.thumb(atMM: (10, 10)).tap(fingers: 3))

        #expect(world.hardware.isGatedPortOn)
        #expect(lookUpPair(world) == droppedPair)
        #expect(world.system.broughtToFront == [world.app("Notes"), world.app("Notes")])
    }
}
