import Testing
import LauncherCore

@MainActor @Suite struct ClickBlockingTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()

    private func script() -> TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    private func world(apps: [String] = ["Arc"], granted: Bool = true) -> World {
        let world = World(apps: apps, accessGranted: granted)
        world.launcher.start()
        if apps.contains("Arc") { world.launcher.setAssignment(.app(world.app("Arc")), for: .one) }
        return world
    }

    @Test(arguments: 1...4)
    func aFirmTapOpensItsAppAndTheWholePressNeverReachesApps(fingers: Int) {
        let apps = ["Arc", "Figma", "Notion", "Spotify"]
        let world = World(apps: apps, accessGranted: true)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, apps) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }

        world.hardware.touch(script().tap(fingers: fingers, click: .firm).frames, on: trackpad.id)

        #expect(world.system.broughtToFront == [world.app(apps[fingers - 1])])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.hardware.feedback == [trackpad.id])
    }

    @Test func pressAndHoldOpensNothingAndBlocksThePress() {
        let world = world()
        world.hardware.touch(script().tap(fingers: 1, hold: .seconds(1), click: .firm).frames, on: trackpad.id)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }

    @Test func afterFourSecondsAPressIsAClickAndOpensNothing() {
        let world = world()
        world.hardware.touch(script().wait(.seconds(4)).tap(fingers: 1, click: .firm).frames, on: trackpad.id)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
    }

    @Test func withoutAccessAGestureStillWorksButNothingIsBlocked() {
        let world = world(granted: false)
        world.hardware.touch(script().tap(fingers: 1).frames, on: trackpad.id)
        #expect(world.system.broughtToFront == [world.app("Arc")])

        world.hardware.touch(script().tap(fingers: 1, click: .firm).frames, on: trackpad.id)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.pressVerdicts.isEmpty)
        #expect(!world.hardware.isBlockingClicks)
    }

    @Test func aPressAcrossTheThreeSecondMarkIsBlockedWholeAndStillCountsAsTheTap() {
        let world = world()
        let frames = script().wait(.milliseconds(2850)).tap(fingers: 1, hold: .milliseconds(200), click: .firm).frames
        world.hardware.touch(frames, on: trackpad.id)
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aThumbLandingDuringADragLeavesTheDragAlone() {
        let world = world()
        let finger = h.contact(1, atMM: 62, 45)
        let thumb = h.contact(9, atMM: 10, 10)
        let frames = [
            h.frame(atMS: -10),
            h.frame(atMS: 0, [h.contact(1, .landing, atMM: 62, 45)], press: .click),
            h.frame(atMS: 50, [finger, h.contact(9, .landing, atMM: 10, 10)], press: .click),
            h.frame(atMS: 100, [finger, thumb], press: .click),
            h.frame(atMS: 150, [finger, thumb]),
            h.frame(atMS: 200, [thumb]),
        ]
        world.hardware.touch(frames, on: trackpad.id)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func aPressWithOnlyTheThumbDownPassesAndTheNextTapStillOpensItsApp() {
        let world = world()
        let thumb = h.contact(9, atMM: 10, 10)
        let frames = [
            h.frame(atMS: -10),
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [thumb], press: .click),
            h.frame(atMS: 100, [thumb], press: .click),
            h.frame(atMS: 150, [thumb]),
            h.frame(atMS: 300, [thumb, h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 310, [thumb, h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 320, [thumb, h.contact(1, atMM: 62, 45)]),
            h.frame(atMS: 330, [thumb]),
        ]
        world.hardware.touch(frames, on: trackpad.id)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aPressReachingTheTapBeforeTheLandingFrameIsAClickThatCancelsTheTap() {
        let world = world()
        world.hardware.touch(script().tap(fingers: 1, click: .onLanding).frames, on: trackpad.id)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
    }

    @Test func blockingIsArmedOnlyWhileGesturesAreActiveAndAccessIsGranted() {
        let world = world()
        #expect(world.hardware.isBlockingClicks)

        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        #expect(!world.hardware.isBlockingClicks)
        #expect(world.hardware.running.isEmpty)

        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)
        #expect(world.hardware.isBlockingClicks)

        let none = World(attached: [], accessGranted: true)
        none.launcher.start()
        #expect(!none.hardware.isBlockingClicks)
    }

    @Test func blockingFollowsTheGrantAndTheRevokeWithoutRelaunching() {
        let world = world(granted: false)
        #expect(!world.hardware.isBlockingClicks)

        world.access.set(granted: true)
        #expect(world.hardware.isBlockingClicks)
        world.hardware.touch(script().tap(fingers: 1, click: .firm).frames, on: trackpad.id)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])

        world.access.set(granted: false)
        #expect(!world.hardware.isBlockingClicks)
        world.hardware.touch(script().tap(fingers: 1, click: .firm).frames, on: trackpad.id)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
    }

    @Test func aReconcileUnderARestingThumbDoesNotRestartTheWindow() {
        let world = world()
        world.hardware.touch(script().wait(.milliseconds(3500)).frames, on: trackpad.id)
        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)

        let thumb = h.contact(9, atMM: 10, 10)
        let frames = [
            h.frame(atMS: 0, [thumb]),
            h.frame(atMS: 50, [thumb, h.contact(1, .landing, atMM: 62, 45)]),
            h.frame(atMS: 60, [thumb, h.contact(1, atMM: 62, 45)], press: .click),
            h.frame(atMS: 100, [thumb], press: .click),
            h.frame(atMS: 110, [thumb]),
        ]
        world.hardware.touch(frames, on: trackpad.id)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.system.broughtToFront.isEmpty)
    }
}
