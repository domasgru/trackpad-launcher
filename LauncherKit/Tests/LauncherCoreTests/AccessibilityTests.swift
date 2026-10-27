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


    @Test func firstRunPromptsOnceAndOpensTheWindow() {
        let world = World()

        world.launcher.start()
        #expect(world.permissions.asks.isEmpty)
        world.launcher.openedByHand()
        #expect(world.permissions.asks == [.accessibility])
        #expect(world.launcher.isWindowOpen)
        #expect(world.loginItem.calls == ["register"])

        world.launcher.closeWindow()
        world.relaunch().start()
        world.launcher.openedByHand()
        #expect(world.permissions.asks == [.accessibility])
    }

    @Test func firstRunWithAccessAlreadyGrantedSkipsThePrompt() {
        let world = World(accessGranted: true)

        world.launcher.start()
        world.launcher.openedByHand()

        #expect(world.permissions.asks.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test func aGrantLeavesTheWindowOpen() {
        let world = World()
        world.launcher.start()
        world.launcher.openedByHand()

        world.permissions.set(.accessibility, granted: true)

        #expect(world.launcher.isWindowOpen)
        #expect(world.launcher.isAccessibilityGranted)
    }

    @Test func promptComesBeforeTheFirstSave() {
        let world = World()
        var snapshots: [Settings?] = []
        world.permissions.onAsk = { [unowned world] in snapshots.append(world.store.load()) }

        world.launcher.start()
        world.launcher.openedByHand()

        #expect(snapshots == [nil])
        #expect(world.store.load() != nil)
    }
}
