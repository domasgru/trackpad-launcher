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

    @Test func theHandGuideShowsOnlyWhileTheCornerDrawnIsTopLeft() {
        let world = startedWorld()
        #expect(world.launcher.showsHandGuide)

        for corner in [ThumbCorner.topRight, .bottomLeft, .bottomRight] {
            world.launcher.setThumbCorner(corner)
            #expect(world.launcher.showsHandGuide == false)
        }

        world.launcher.setThumbCorner(.topLeft)
        #expect(world.launcher.showsHandGuide)
    }

    @Test func theHandGuideFollowsTheExternalTrackpadComingAndGoing() {
        let world = startedWorld(attached: [.macBook14, .magicTrackpad])
        world.launcher.setExternalThumbCorner(.bottomLeft)
        #expect(world.launcher.showsHandGuide == false)

        world.hardware.detach(Trackpad.magicTrackpad.id)
        #expect(world.launcher.showsHandGuide)

        world.hardware.attach(.magicTrackpad)
        #expect(world.launcher.showsHandGuide == false)
    }

    @Test func theHandGuideGoesWithHoldThumbAndReturnsWithIt() {
        let world = startedWorld()

        world.launcher.setHoldThumb(on: false)
        #expect(world.launcher.showsHandGuide == false)

        world.launcher.setHoldThumb(on: true)
        #expect(world.launcher.showsHandGuide)
    }

    @Test(arguments: [ThumbCorner.topRight, .bottomLeft, .bottomRight], [true, false])
    func theHandGuideStaysAwayFromTheOtherCorners(corner: ThumbCorner, holdThumb: Bool) {
        let world = startedWorld()
        world.launcher.setThumbCorner(corner)
        world.launcher.setHoldThumb(on: holdThumb)

        #expect(world.launcher.showsHandGuide == false)
    }

    @Test func theHandGuideStaysOffAfterARelaunchWithHoldThumbOff() {
        let world = startedWorld()
        world.launcher.setHoldThumb(on: false)

        world.relaunch().start()
        world.launcher.openedByHand()

        #expect(world.launcher.showsHandGuide == false)
    }
}
