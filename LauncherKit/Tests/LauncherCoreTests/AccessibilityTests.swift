import Testing
import LauncherCore

@MainActor @Suite struct AccessibilityTests {
    @Test func accessHintFollowsTheGrantLiveAndNeverChangesActivity() {
        let world = World()
        world.launcher.start()
        #expect(!world.launcher.isAccessibilityGranted)
        #expect(world.launcher.activity == .active)

        world.permissions.set(.accessibility, granted: true)
        #expect(world.launcher.isAccessibilityGranted)
        #expect(world.launcher.activity == .active)

        world.permissions.set(.accessibility, granted: false)
        #expect(!world.launcher.isAccessibilityGranted)
        #expect(world.launcher.activity == .active)
    }

    @Test func firstLaunchPromptsOnceAndHoldsTheWindowOpenUntilAnExplicitClose() {
        let world = World()

        world.launcher.start()
        #expect(world.permissions.asks == [.accessibility])
        #expect(world.launcher.isWindowOpen)
        #expect(world.system.loginItemRegistrations == 1)

        world.launcher.dismissWindow()
        #expect(world.launcher.isWindowOpen)
        world.launcher.closeWindow()
        #expect(!world.launcher.isWindowOpen)

        world.relaunch().start()
        #expect(world.permissions.asks == [.accessibility])
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func firstLaunchWithAccessAlreadyGrantedSkipsThePromptAndOpensAnOrdinaryWindow() {
        let world = World(accessGranted: true)

        world.launcher.start()
        #expect(world.permissions.asks.isEmpty)
        #expect(world.launcher.isWindowOpen)
        world.launcher.dismissWindow()
        #expect(!world.launcher.isWindowOpen)

        world.relaunch().start()
        world.launcher.openWindow()
        world.launcher.dismissWindow()
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func aGrantEndsTheHoldAndClosesTheWindow() {
        let world = World()
        world.launcher.start()

        world.permissions.set(.accessibility, granted: true)

        #expect(!world.launcher.isWindowOpen)
        #expect(world.launcher.isAccessibilityGranted)
    }

    @Test func aFiredGestureClosesAHeldWindow() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        #expect(world.launcher.isWindowOpen)

        world.tap(1)

        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func promptComesBeforeTheFirstSave() {
        let world = World()
        var snapshots: [Settings?] = []
        world.permissions.onAsk = { [unowned world] in snapshots.append(world.store.load()) }

        world.launcher.start()

        #expect(snapshots == [nil])
        #expect(world.store.load() != nil)
    }
}
