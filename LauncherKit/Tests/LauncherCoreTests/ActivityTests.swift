import Testing
import LauncherCore

@MainActor @Suite struct ActivityTests {
    private func inactive(_ settings: ConflictingSetting...) -> GestureActivity {
        .inactive(.settings(ConflictingSettings(settings)!))
    }

    @Test func tapToClickOnBuiltInDeactivatesAndStopsTheDevices() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        #expect(world.launcher.activity == inactive(.tapToClick))
        #expect(world.hardware.running.isEmpty)
        world.tap(1)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func settingOnlyOnTheConnectedExternalTrackpadDeactivates() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.hardware.attach(.magicTrackpad)

        world.preferences.set(.tapToClick, rawValue: 1, for: .external)

        #expect(world.launcher.activity == inactive(.tapToClick))
        world.tap(1)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func settingOnAnExternalTrackpadThatIsNotConnectedIsIgnored() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.preferences.set(.tapToClick, rawValue: 1, for: .external)

        #expect(world.launcher.activity == .active)
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func turningTheSettingOffActivatesLive() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)

        #expect(world.launcher.activity == .active)
        #expect(Set(world.hardware.running.keys) == [Trackpad.macBook14.id])
        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test(arguments: [
        (clicking: nil, lookUp: 2, expected: [ConflictingSetting.lookUpTapWithThreeFingers]),
        (clicking: 1, lookUp: 2, expected: [.tapToClick, .lookUpTapWithThreeFingers]),
        (clicking: 1, lookUp: 0, expected: [.tapToClick]),
        (clicking: 0, lookUp: 0, expected: []),
        (clicking: nil, lookUp: nil, expected: []),
    ] as [(clicking: Int?, lookUp: Int?, expected: [ConflictingSetting])])
    func noticeNamesExactlyTheOffendingSettingsInTableOrder(
        clicking: Int?, lookUp: Int?, expected: [ConflictingSetting]
    ) {
        let world = World()
        world.launcher.start()

        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: lookUp, for: .builtIn)
        world.preferences.set(.tapToClick, rawValue: clicking, for: .builtIn)

        let want = ConflictingSettings(expected).map { GestureActivity.inactive(.settings($0)) } ?? .active
        #expect(world.launcher.activity == want)
    }

    @Test func noticeWordsAreTheSettingsOwnNames() {
        #expect(ConflictingSetting.tapToClick.noticeName == "Tap to click")
        #expect(ConflictingSetting.lookUpTapWithThreeFingers.noticeName == "Look up: Tap with three fingers")
        #expect(ConflictingSettings([]) == nil)
    }

    @Test func noTrackpadWinsOverSettingsAndTracksHotPlug() {
        let world = World(attached: [])
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.launcher.start()
        #expect(world.launcher.activity == .inactive(.noTrackpad))

        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)
        world.hardware.attach(.macBook14)
        #expect(world.launcher.activity == .active)

        world.hardware.detach(Trackpad.macBook14.id)
        #expect(world.launcher.activity == .inactive(.noTrackpad))
    }

    @Test func rowsStayEditableWhileInactive() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        #expect(world.launcher.app(for: .one) == .present(world.app("Arc")))
        #expect(world.relaunch().app(for: .one) == .present(world.app("Arc")))
    }

    @Test func gestureInFlightWhenActivityFlipsIsDropped() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.launcher.openWindow()

        world.hardware.inject(GestureEvent(gesture: .one, trackpad: Trackpad.macBook14.id))

        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }
}
