import Foundation
import Testing
import LauncherCore

extension Launcher {
    func app(for gesture: Gesture) -> RowApp? { rows.first { $0.gesture == gesture }?.app }
}

@MainActor @Suite struct LauncherTests {
    @Test func twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.launcher.openWindow()
        var broughtToFrontWhenAnimationRequested: [AppEntry]?
        world.system.onPlayLaunchAnimation = { [system = world.system] in
            broughtToFrontWhenAnimationRequested = system.broughtToFront
        }

        world.tap(2)

        #expect(world.system.launchAnimations == [world.app("Figma")])
        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(!world.launcher.isWindowOpen)
        #expect(
            broughtToFrontWhenAnimationRequested == [world.app("Figma")],
            "the app is brought to front before the animation is requested, so the animation cannot delay it")
    }

    @Test func withTheLaunchAnimationOffAGesturePulsesBringsToFrontAndClosesTheWindowWithoutAnIcon() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.openWindow()
        world.launcher.setLaunchAnimation(on: false)

        world.tap(1)

        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(!world.launcher.isWindowOpen)
        #expect(world.system.launchAnimations.isEmpty)
    }

    @Test func theSwitchAppliesToTheNextGestureWithoutARestart() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.tap(1)
        #expect(world.system.launchAnimations == [world.app("Arc")])

        world.launcher.setLaunchAnimation(on: false)
        world.tap(1)
        #expect(world.system.launchAnimations == [world.app("Arc")])
        #expect(world.hardware.feedback.count == 2)
        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Arc")])

        world.launcher.setLaunchAnimation(on: true)
        world.tap(1)
        #expect(world.system.launchAnimations == [world.app("Arc"), world.app("Arc")])
    }

    @Test func iconsAreStillPreparedWhileTheLaunchAnimationIsOff() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setLaunchAnimation(on: false)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        #expect(world.system.preparedLaunchAnimations == [world.app("Arc")])
        #expect(world.system.launchAnimations.isEmpty)
    }

    @Test func repeatedTapsWhileTheThumbStaysAnchoredFireEachTime() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).tap(fingers: 2).frames
        world.hardware.touch(frames, on: Trackpad.macBook14.id)

        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Figma")])
        #expect(world.system.launchAnimations == [world.app("Arc"), world.app("Figma")])
        #expect(world.hardware.feedback.count == 2)
    }

    @Test func fourFingerTapWithEarlyLiftsOpensTheFourFingerApp() {
        let world = World(apps: ["Spotify", "Notion"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Spotify")), for: .four)
        world.launcher.setAssignment(.app(world.app("Notion")), for: .three)

        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 4, stagger: .milliseconds(40), hold: .milliseconds(100)).frames
        world.hardware.touch(frames, on: Trackpad.macBook14.id)

        #expect(world.system.broughtToFront == [world.app("Spotify")])
        #expect(world.hardware.feedback.count == 1)
    }

    @Test func twoQuickOneFingerTapsOpenTheAppTwice() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
            .tap(fingers: 1).wait(.milliseconds(100)).tap(fingers: 1).frames
        world.hardware.touch(frames, on: Trackpad.macBook14.id)

        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Arc")])
        #expect(world.system.launchAnimations == [world.app("Arc"), world.app("Arc")])
    }

    @Test func unassignedGestureIsSilentAndLeavesTheWindowOpen() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.openWindow()

        world.tap(3)

        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
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
        #expect(world.system.launchAnimations.isEmpty)
    }

    @Test func withNothingAssignedNoLaunchAnimationIsPrepared() {
        let world = World(apps: ["Arc", "Figma"])

        world.launcher.start()

        #expect(world.system.preparedLaunchAnimations == [])
    }

    @Test func assigningPreparesTheLaunchAnimationsBeforeAnyGestureInGestureOrder() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()

        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        #expect(world.system.preparedLaunchAnimations == [world.app("Arc"), world.app("Figma")])
        #expect(world.system.launchAnimations.isEmpty, "preparing plays nothing")
    }

    @Test func anAppOnTwoGesturesIsPreparedOnce() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .four)

        #expect(
            world.system.preparedLaunchAnimations == [world.app("Arc"), world.app("Figma")],
            "one entry per bundle location, in gesture order")
    }

    @Test func unassigningAnAppStopsPreparingIt() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        world.launcher.setAssignment(.unassigned, for: .two)

        #expect(world.system.preparedLaunchAnimations == [world.app("Arc")])
    }

    @Test func anAppFoundMissingWhenTheWindowOpensIsNoLongerPrepared() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.registry[World.bundleID("Arc")] = [world.trash("Arc")]

        world.launcher.openWindow()

        #expect(
            world.system.preparedLaunchAnimations == [world.app("Figma")],
            "a missing app cannot fire, so it is not prepared")
    }

    @Test func creatingTheLauncherPreparesNothingAndStartingItPreparesTheAssignedApps() {
        let world = World(apps: ["Arc"])
        var earlierRun = Settings()
        earlierRun.assignments[.one] = AssignedApp(world.app("Arc"))
        world.store.save(earlierRun)

        world.relaunch()
        #expect(world.system.preparedLaunchAnimations == [], "creating the launcher prepares nothing")

        world.launcher.start()
        #expect(world.system.preparedLaunchAnimations == [world.app("Arc")])
        #expect(world.system.launchAnimations.isEmpty, "preparing plays nothing")
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
        #expect(world.hardware.feedback.isEmpty)

        world.hardware.wake()
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }
}
