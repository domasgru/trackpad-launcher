import Foundation
import LauncherCore
import Testing

/// The corner the gesture illustrations draw their thumb in follows the Hold thumb setting and the corner drawn.
@MainActor @Suite struct IllustrationThumbTests {
    private func startedWorld(attached: [Trackpad] = [.macBook14]) -> World {
        let world = World(apps: ["Arc"], attached: attached)
        world.launcher.start()
        world.launcher.openedByHand()
        return world
    }

    @Test(arguments: ThumbCorner.allCases) func gesturePicturesDrawTheThumbInTheCornerPicked(corner: ThumbCorner) {
        let world = startedWorld()

        world.launcher.setThumbCorner(corner)

        #expect(world.launcher.gestureThumbCorner == corner)
        #expect(world.launcher.drawnThumbCorner == corner)
    }

    @Test(arguments: ThumbCorner.allCases) func turningHoldThumbOffTakesTheThumbOffTheGesturePicturesOnly(
        corner: ThumbCorner
    ) {
        let world = startedWorld()
        world.launcher.setThumbCorner(corner)

        world.launcher.setHoldThumb(on: false)
        #expect(world.launcher.gestureThumbCorner == nil)
        #expect(world.launcher.drawnThumbCorner == corner)

        world.launcher.setHoldThumb(on: true)
        #expect(world.launcher.gestureThumbCorner == corner)
    }

    @Test func aCornerPickWhileHoldThumbIsOffLeavesTheGesturePicturesWithoutAThumb() {
        let world = startedWorld()
        world.launcher.setHoldThumb(on: false)

        world.launcher.setThumbCorner(.bottomRight)

        #expect(world.launcher.gestureThumbCorner == nil)
        #expect(world.launcher.drawnThumbCorner == .bottomRight)
    }

    @Test func aTrackpadComingAndGoingWhileHoldThumbIsOffMovesOnlyTheCornerDrawn() {
        let world = startedWorld(attached: [.macBook14, .magicTrackpad])
        world.launcher.setExternalThumbCorner(.bottomLeft)
        world.launcher.setHoldThumb(on: false)
        var gesture: [ThumbCorner?] = [world.launcher.gestureThumbCorner]
        var drawn = [world.launcher.drawnThumbCorner]

        world.hardware.detach(Trackpad.magicTrackpad.id)
        gesture.append(world.launcher.gestureThumbCorner)
        drawn.append(world.launcher.drawnThumbCorner)
        world.hardware.attach(.magicTrackpad)
        gesture.append(world.launcher.gestureThumbCorner)
        drawn.append(world.launcher.drawnThumbCorner)

        #expect(gesture == [nil, nil, nil])
        #expect(drawn == [.bottomLeft, .topLeft, .bottomLeft])
    }

    @Test func holdThumbOffIsStillOffAfterARelaunch() {
        let world = startedWorld()
        world.launcher.setHoldThumb(on: false)

        world.relaunch().start()
        world.launcher.openedByHand()

        #expect(world.launcher.gestureThumbCorner == nil)
    }
}
