import Foundation
import LauncherCore
import Observation
import Synchronization
import Testing

/// Each trackpad kind has its own thumb corner to choose, and choosing one leaves the other alone.
@MainActor @Suite struct CornerChoiceTests {
    private let both: [Trackpad] = [.macBook14, .magicTrackpad]

    private func bothWorld() -> World {
        let world = World(apps: ["Arc", "Figma"], attached: both)
        world.launcher.start()
        world.launcher.openedByHand()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        return world
    }

    @Test(arguments: [
        ("topLeft", ThumbCorner.topLeft), ("topRight", .topRight), ("bottomLeft", .bottomLeft),
        ("bottomRight", .bottomRight),
    ]) func theExternalCornerAppliesAtOnceAndIsSaved(wire: String, corner: ThumbCorner) {
        let world = bothWorld()
        let runs = world.hardware.runCount

        world.launcher.setExternalThumbCorner(corner)

        #expect(world.hardware.runCount == runs + (corner == .bottomLeft ? 0 : 1))
        #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: corner))
        #expect(world.launcher.drawnThumbCorner == corner)
        #expect(world.savedExternalCorner() == wire)
        world.tap(1, on: .magicTrackpad, thumbIn: corner)
        #expect(world.firedCount == 1)
        world.tap(1, on: .magicTrackpad, thumbIn: corner.diagonallyOpposite)
        #expect(world.firedCount == 1)
        world.tap(1, on: .macBook14, thumbIn: .topLeft)
        #expect(world.firedCount == 2)
    }

    @Test func aThumbAlreadyDownIsJudgedAfreshWhenItsKindsCornerChanges() {
        let magic = Trackpad.magicTrackpad.surface
        let entering = bothWorld()
        let resting = TouchScript(.magicTrackpad).thumb(atMM: magic.thumbMM(in: .bottomRight))
        entering.play(resting, on: .magicTrackpad)
        entering.launcher.setExternalThumbCorner(.bottomRight)
        entering.play(resting.wait(.milliseconds(20)).tap(fingers: 1), on: .magicTrackpad)
        #expect(entering.firedCount == 1)

        let leaving = bothWorld()
        let firstTap = TouchScript(.magicTrackpad).thumb(atMM: magic.thumbMM(in: .bottomLeft)).tap(fingers: 1)
        leaving.play(firstTap, on: .magicTrackpad)
        #expect(leaving.firedCount == 1)
        leaving.launcher.setExternalThumbCorner(.bottomRight)
        leaving.play(firstTap.tap(fingers: 1), on: .magicTrackpad)
        #expect(leaving.firedCount == 1)

        let other = bothWorld()
        let macBookResting = TouchScript(.macBook14).thumb(atMM: Trackpad.macBook14.surface.thumbMM(in: .topLeft))
        other.play(macBookResting, on: .macBook14)
        other.launcher.setExternalThumbCorner(.bottomRight)
        other.play(macBookResting.wait(.milliseconds(20)).tap(fingers: 1), on: .macBook14)
        #expect(other.firedCount == 1)
    }

    @Test func theMacBookCornerChangesWithoutTouchingTheExternalOne() {
        let world = bothWorld()

        world.launcher.setThumbCorner(.topRight)

        #expect(world.launcher.thumbCorners == .perKind(macBook: .topRight, external: .bottomLeft))
        world.tap(1, on: .magicTrackpad, thumbIn: .bottomLeft)
        #expect(world.firedCount == 1)
        world.tap(1, on: .macBook14, thumbIn: .topRight)
        #expect(world.firedCount == 2)
        world.tap(1, on: .macBook14, thumbIn: .topLeft)
        #expect(world.firedCount == 2)
    }

    @Test func bothCornersSurviveARelaunchWithoutTheMagicTrackpad() {
        let world = bothWorld()
        world.launcher.setExternalThumbCorner(.bottomRight)
        world.hardware.detach(Trackpad.magicTrackpad.id)

        world.relaunch().start()
        world.launcher.openedByHand()

        #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: .bottomRight))
        #expect(world.launcher.drawnThumbCorner == .topLeft)
    }

    @Test func anExternalCornerChosenWhileNoExternalTrackpadIsConnectedWaitsForOne() {
        let world = bothWorld()
        world.hardware.detach(Trackpad.magicTrackpad.id)
        let runs = world.hardware.runCount

        world.launcher.setExternalThumbCorner(.topRight)

        #expect(world.hardware.runCount == runs)
        #expect(world.launcher.drawnThumbCorner == .topLeft)
        #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: .topRight))
        world.hardware.attach(.magicTrackpad)
        #expect(world.launcher.drawnThumbCorner == .topRight)
        world.tap(1, on: .magicTrackpad, thumbIn: .topRight)
        #expect(world.firedCount == 1)
    }

    @Test func aMacBookCornerChosenWhileTheLidIsClosedRerunsNothingAndLeavesTheMagicTrackpadAlone() {
        let world = bothWorld()
        world.hardware.detach(Trackpad.macBook14.id)
        let runs = world.hardware.runCount

        world.launcher.setThumbCorner(.bottomRight)

        #expect(world.hardware.runCount == runs)
        world.tap(1, on: .magicTrackpad, thumbIn: .bottomLeft)
        #expect(world.firedCount == 1)
        #expect(world.launcher.drawnThumbCorner == .bottomLeft)
    }

    @Test func aMacWithoutMixedTrackpadsHasNoExternalCornerToChoose() {
        let world = World()
        world.launcher.start()
        let runs = world.hardware.runCount

        world.launcher.setExternalThumbCorner(.topRight)

        #expect(world.launcher.thumbCorners == .single(.topLeft))
        #expect(world.savedExternalCorner() == nil)
        #expect(world.hardware.runCount == runs)
        world.hardware.attach(.magicTrackpad)
        #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft))
    }

    @Test func theChosenExternalCornerSurvivesDisconnectsSleepAndRelaunch() {
        let world = bothWorld()
        world.launcher.setExternalThumbCorner(.topRight)
        var kept: [Bool] = []
        func step(_ action: () -> Void) {
            action()
            kept.append(
                world.savedExternalCorner() == "topRight"
                    && world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: .topRight))
        }

        step { world.hardware.detach(Trackpad.magicTrackpad.id) }
        step { world.hardware.attach(.magicTrackpad) }
        step { world.hardware.sleep() }
        step { world.hardware.wake() }
        step { world.relaunch().start() }

        #expect(kept == Array(repeating: true, count: 5))
    }

    @Test func theRowsAndTheWindowsFitAreObservable() {
        let alone = World()
        alone.launcher.start()
        let joined = Mutex(false)
        withObservationTracking {
            _ = alone.launcher.thumbCorners.hasMixedTrackpads
        } onChange: {
            joined.withLock { $0 = true }
        }
        alone.hardware.attach(.magicTrackpad)
        #expect(joined.withLock { $0 })

        let world = bothWorld()
        world.hardware.detach(Trackpad.magicTrackpad.id)
        let chosen = Mutex(false)
        withObservationTracking {
            _ = world.launcher.thumbCorners
        } onChange: {
            chosen.withLock { $0 = true }
        }
        world.launcher.setExternalThumbCorner(.topRight)
        #expect(chosen.withLock { $0 })
    }

    enum PreviousVersionChange: CaseIterable, CustomStringConvertible {
        case nothing, switchRecentOff, cornerTopRight, notesOnGestureThree

        var description: String {
            switch self {
            case .nothing: "nothing"
            case .switchRecentOff: "Switch recent turned off"
            case .cornerTopRight: "the corner set to Top right"
            case .notesOnGestureThree: "Notes put on gesture 3"
            }
        }
    }

    @Test(arguments: PreviousVersionChange.allCases) func theVersionBeforeKeepsTheMacBookCornerForEveryTrackpad(
        change: PreviousVersionChange
    ) throws {
        let world = World(apps: ["Arc", "Notes"], attached: both)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setThumbCorner(.bottomRight)
        world.launcher.setExternalThumbCorner(.topLeft)
        let notes = AssignedApp(world.app("Notes"))

        let saved = try world.previousVersionSaves { settings in
            switch change {
            case .nothing: break
            case .switchRecentOff: settings.isSwipeOn = false
            case .cornerTopRight: settings.isThumbAtBottom = false
            case .notesOnGestureThree: settings.assignments[.three] = notes
            }
        }

        #expect(saved.handMode == .left)
        #expect(saved.isThumbAtBottom == (change != .cornerTopRight))
        #expect(saved.assignments[.one]?.bundleID == World.bundleID("Arc"))

        let relaunched = world.relaunch()
        relaunched.start()
        let expectedCorner: ThumbCorner = change == .cornerTopRight ? .topRight : .bottomRight
        #expect(relaunched.thumbCorners == .perKind(macBook: expectedCorner, external: .topLeft))
        let reloaded = try #require(world.freshStore().load())
        #expect(reloaded.isSwipeOn == (change != .switchRecentOff))
        #expect(reloaded.assignments[.three] == (change == .notesOnGestureThree ? notes : nil))
    }
}
