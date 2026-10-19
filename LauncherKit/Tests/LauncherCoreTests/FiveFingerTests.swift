import Testing
import LauncherCore

@MainActor @Suite struct FiveFingerTests {
    private let trackpad = Trackpad.macBook14
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    @Test func aRollingFiveFingerTapOpensTheFiveFingerAppOnceAndNotTheFourFingerOne() {
        let world = World(apps: ["Slack", "Spotify"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Slack")), for: .five)
        world.launcher.setAssignment(.app(world.app("Spotify")), for: .four)
        world.startProcess("Slack")

        let frames = thumb.tap(fingers: 5, stagger: .milliseconds(40), hold: .milliseconds(100)).frames
        world.hardware.touch(frames, on: trackpad.id)

        #expect(world.system.broughtToFront == [world.app("Slack")])
        #expect(world.hardware.feedback == [trackpad.id])
        #expect(world.system.launchAnimations == [world.app("Slack")])
    }

    @Test func aSixFingerTapOpensNothingWhenEveryGestureIsAssigned() {
        let apps = ["Arc", "Figma", "Notion", "Spotify", "Slack"]
        let world = World(apps: apps)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, apps) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }

        world.tap(6)

        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.bounces.isEmpty)
    }

    @Test func aFreshInstallHasFiveUnassignedRowsOneToFiveInOrder() {
        let world = World()
        world.launcher.start()

        #expect(world.launcher.rows.map(\.gesture) == [.one, .two, .three, .four, .five])
        #expect(world.launcher.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
    }

    @Test func assigningTheFifthRowMakesAFiveFingerTapOpenThatApp() {
        let world = World(apps: ["Slack"])
        world.launcher.start()

        world.launcher.setAssignment(.app(world.app("Slack")), for: .five)
        world.tap(5)

        #expect(world.launcher.app(for: .five) == .present(world.app("Slack")))
        #expect(world.system.broughtToFront == [world.app("Slack")])
    }

    @Test func playDeliversOnlyTheFramesNewerThanAnythingAlreadyDelivered() {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        let first = thumb.tap(fingers: 1)
        world.play(first)
        world.play(first.tap(fingers: 2))

        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Figma")])
    }

    @Test func aSidewaysTwoFingerSlideIsAnOrdinaryDragForNowAndASwipeEventChangesNothing() {
        let world = World(apps: ["Slack"], accessGranted: true)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Slack")), for: .two)

        world.hardware.touch(thumb.wait(.seconds(1)).land(fingers: 2).slide(byMM: (20, 0)).lift().frames, on: trackpad.id)
        world.hardware.inject(.swipe(SwipeEvent(phase: .ended, trackpad: trackpad.id)))

        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.feedback.isEmpty)
    }
}
