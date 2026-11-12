import Testing
import LauncherCore

@MainActor @Suite struct ActivityTests {
    @Test func tapToClickOnBuiltInWithAccessKeepsGesturesActiveAndTheDevicesRunning() {
        let world = World(apps: ["Arc"], accessGranted: true)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        #expect(world.launcher.activity == .active)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        #expect(world.hardware.isBlockingClicks)
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    }

    @Test func settingsOnTheExternalTrackpadOnlyLetTheGestureFireOnEitherTrackpadWithAccess() {
        let world = World(apps: ["Notes"], attached: [.macBook14, .magicTrackpad], accessGranted: true)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Notes")), for: .three)
        world.preferences.set(.tapToClick, rawValue: 1, for: .external)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: 2, for: .external)
        #expect(world.launcher.activity == .active)

        world.tap(3, on: .magicTrackpad, thumbAtMM: (10, 105))
        world.tap(3)

        #expect(world.system.broughtToFront == [world.app("Notes"), world.app("Notes")])
        #expect(world.hardware.feedback == [Trackpad.magicTrackpad.id, Trackpad.macBook14.id])
    }

    @Test func swipeWindowSwipeAndSwapRunWithTapToClickOnAndAccess() {
        let swipe = World.switcherWorld(accessGranted: true)
        swipe.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        swipe.swipe(3.5, 12)
        #expect(swipe.system.broughtToFront == [swipe.app("Mail")])
        #expect(swipe.hardware.feedback == [Trackpad.macBook14.id])
        #expect(swipe.launcher.switcher == nil)

        let swap = World.switcherWorld(accessGranted: true)
        swap.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        swap.swap()
        #expect(swap.system.broughtToFront == [swap.app("Mail")])
        #expect(swap.hardware.feedback == [Trackpad.macBook14.id])

        let windows = World.windowWorld(visible: ["Docs", "Mail"])
        windows.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        windows.windowSwipe(3.5, 12, lift: false)
        #expect(windows.system.windows.raised == [[windows.window("Mail")]])
    }

    @Test func turningTapToClickOnWhileRunningRestartsTheTrackpadsAndTheNextGestureFires() {
        let world = World(apps: ["Arc"], accessGranted: true)
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        let runs = world.hardware.runCount

        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        #expect(world.launcher.activity == .active)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        #expect(world.hardware.runCount == runs + 1)
        #expect(world.hardware.isBlockingClicks)
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        let press = PressID(button: 0, number: 1)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.drop)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.drop)))
    }

    @Test(arguments: [
        (clicking: 1, lookUp: 0),
        (clicking: 0, lookUp: 2),
        (clicking: 1, lookUp: 2),
        (clicking: nil, lookUp: nil),
    ] as [(clicking: Int?, lookUp: Int?)])
    func withoutAccessNoSettingTurnsGesturesOffAndNothingIsBlocked(clicking: Int?, lookUp: Int?) {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.preferences.set(.tapToClick, rawValue: clicking, for: .builtIn)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: lookUp, for: .builtIn)

        #expect(world.launcher.activity == .active)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        #expect(!world.hardware.isBlockingClicks)
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.offer(.pointer(.press(PressID(button: 0, number: 1)))) == .noTap)
    }

    @Test func grantingAndRevokingAccessOnlyTurnsBlockingOnAndOff() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        #expect(world.launcher.activity == .active)
        #expect(!world.hardware.isBlockingClicks)

        world.permissions.set(.accessibility, granted: true)
        #expect(world.launcher.activity == .active)
        #expect(world.hardware.isBlockingClicks)
        world.tap(1)
        let press = PressID(button: 0, number: 1)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.drop)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.drop)))

        world.permissions.set(.accessibility, granted: false)
        #expect(world.launcher.activity == .active)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Arc")])
        #expect(world.hardware.offer(.pointer(.press(press))) == .noTap)
    }

    @Test func settingsOnTheConnectedExternalTrackpadLetTheGestureFireWithoutAccess() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.hardware.attach(.magicTrackpad)

        world.preferences.set(.tapToClick, rawValue: 1, for: .external)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: 2, for: .external)

        #expect(world.launcher.activity == .active)
        world.tap(1, on: .magicTrackpad, thumbAtMM: (10, 105))
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.hardware.feedback == [Trackpad.magicTrackpad.id])
    }

    @Test func noTrackpadIsTheOnlyCauseAndTracksHotPlug() {
        let world = World(attached: [])
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.launcher.start()
        #expect(world.launcher.activity == .inactive(.noTrackpad))
        #expect(world.launcher.inactiveNotice == "No trackpad connected. Connect a trackpad to use gestures.")
        #expect(world.launcher.showsAccessibilityHint)

        world.hardware.attach(.macBook14)
        #expect(world.launcher.activity == .active)
        #expect(world.launcher.inactiveNotice == nil)

        world.hardware.detach(Trackpad.macBook14.id)
        #expect(world.launcher.activity == .inactive(.noTrackpad))
    }

    @Test func theAccessibilityHintFollowsTheGrantLiveWhateverTheSettings() {
        let world = World()
        world.launcher.start()
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: 2, for: .builtIn)
        world.launcher.openedByHand()
        #expect(world.launcher.inactiveNotice == nil)
        #expect(world.launcher.showsAccessibilityHint)

        world.permissions.set(.accessibility, granted: true)
        #expect(!world.launcher.showsAccessibilityHint)
        #expect(world.launcher.isWindowOpen)

        world.permissions.set(.accessibility, granted: false)
        #expect(world.launcher.showsAccessibilityHint)
        #expect(world.launcher.inactiveNotice == nil)
    }

    @Test func rowsStayEditableWhileInactive() {
        let world = World(apps: ["Arc"], attached: [])
        world.launcher.start()

        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        #expect(world.launcher.app(for: .one) == .present(world.app("Arc")))
        #expect(world.relaunch().app(for: .one) == .present(world.app("Arc")))
    }

    @Test func gestureInFlightWhenActivityFlipsIsDropped() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.hardware.detach(Trackpad.macBook14.id)
        world.launcher.openedByHand()

        world.hardware.inject(.gesture(GestureEvent(gesture: .one, trackpad: Trackpad.macBook14.id)))

        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.bounces.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }
}
