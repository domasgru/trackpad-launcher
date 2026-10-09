import Foundation
import Testing
import LauncherCore

extension Launcher {
    func app(for gesture: Gesture) -> RowApp? { rows.first { $0.gesture == gesture }?.app }
}

@MainActor @Suite struct LauncherTests {
    @Test func twoFingerTapBringsItsAppToFrontPulsesAndClosesTheWindow() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.launcher.openWindow()

        world.tap(2)

        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func repeatedTapsWhileTheThumbStaysAnchoredFireEachTime() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).tap(fingers: 2).frames
        world.hardware.touch(frames, on: Trackpad.macBook14.id)

        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Figma")])
        #expect(world.hardware.feedback.count == 2)
    }

    @Test func unassignedGestureIsSilentAndLeavesTheWindowOpen() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.openWindow()

        world.tap(3)

        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test func missingTargetIsSilent() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.remove("Figma")

        world.tap(2)

        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func handModeDefaultsToRightAndSwitchingMovesTheCorner() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        #expect(world.launcher.handMode == .right)

        world.launcher.setHandMode(.left)
        world.tap(1, thumbAtMM: (114.8, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])

        world.tap(1, thumbAtMM: (10, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func hotPluggedExternalTrackpadWorksAndPulsesItself() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.hardware.attach(.magicTrackpad)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id, Trackpad.magicTrackpad.id])
        world.tap(1, on: .magicTrackpad)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.feedback == [Trackpad.magicTrackpad.id])

        world.hardware.detach(Trackpad.magicTrackpad.id)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        world.tap(1, on: .magicTrackpad)
        #expect(world.system.broughtToFront.count == 1)
    }

    @Test func gesturesWorkAgainAfterTheMacWakesFromSleep() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.hardware.sleep()
        world.tap(1)
        #expect(world.system.broughtToFront.isEmpty)

        world.hardware.wake()
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }
}
