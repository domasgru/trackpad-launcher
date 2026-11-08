import Testing
import LauncherCore

@MainActor @Suite struct SettingsWindowAsAppTests {
    private let trackpad = Trackpad.macBook14

    private func names(_ switcher: Switcher?) -> [String]? { switcher?.row.map(\.name) }

    private func settingsComesForward(_ world: World) {
        #expect(world.system.broughtToFront == [world.trackpadLauncher])
        #expect(world.hardware.feedback == [trackpad.id])
        #expect(world.launcher.window == .open(request: 2))
    }

    @Test func swipingFromAnotherAppBackToTheSettingsBringsTheWindowForwardWithTheHaptic() {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"])
        world.openSettings()
        world.activate("Safari")

        let hand = world.swipe(3.5, 12, lift: false)
        #expect(names(world.launcher.switcher) == ["Safari", "Trackpad Launcher", "Mail", "Notes"])
        #expect(world.launcher.switcher?.selectedApp == world.trackpadLauncher)

        world.play(hand.lift())
        settingsComesForward(world)
    }

    @Test func swappingFromAnotherAppBackToTheSettingsBringsTheWindowForwardWithTheHaptic() {
        let world = World.switcherWorld()
        world.openSettings()
        world.activate("Safari")

        world.swap()
        settingsComesForward(world)
    }

    @Test func aClosedSettingsWindowIsLeftOutOfTheRowAndTheSwap() {
        let world = World.switcherWorld(apps: ["Safari", "Mail"])
        world.openSettings()
        world.activate("Safari")
        world.closeSettings()

        let hand = world.swipe(3.5, lift: false)
        #expect(names(world.launcher.switcher) == ["Safari", "Mail"])

        world.play(hand.lift())
        #expect(world.system.broughtToFront.isEmpty)
        world.play(
            TouchScript(.macBook14).wait(.seconds(5)).land(fingers: 2).wait(.milliseconds(150)).thumbTap().lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test func swipingFromTheSettingsWindowShowsItFirstAndSelectedAndLiftingThereDoesNothing() {
        let world = World.switcherWorld(apps: ["Mail", "Safari"], running: ["Safari", "Mail"], frontmost: "Safari")
        world.openSettings()

        let hand = world.swipe(3.5, lift: false)
        #expect(names(world.launcher.switcher) == ["Trackpad Launcher", "Safari", "Mail"])
        #expect(world.launcher.switcher?.selection.selected == 0)

        let history = world.playFrameByFrame(hand.lift()) { (world.system.broughtToFront, world.hardware.pulses) }
        #expect(history.allSatisfy { $0.0.isEmpty && $0.1.isEmpty })
        #expect(world.launcher.window == .open(request: 1))
    }

    @Test(arguments: [true, false])
    func swappingFromTheSettingsWindowAndBackGoesToTheAppUsedBeforeIt(activationLanded: Bool) {
        let world = World.switcherWorld(apps: ["Safari", "Mail"], running: ["Safari", "Mail"], frontmost: "Safari")
        world.openSettings()

        let hand = world.swap(taps: 1, lift: false)
        #expect(world.system.broughtToFront == [world.app("Safari")])
        if activationLanded { world.activate("Safari") }
        world.play(hand.thumbTap().lift())

        #expect(world.system.broughtToFront == [world.app("Safari"), world.trackpadLauncher])
        #expect(world.hardware.pulses.count == 2)
        #expect(world.hardware.pulses.allSatisfy { $0.haptic == .gesture })
        #expect(world.launcher.window == .open(request: 2))
    }

    @Test func theSettingsWindowAndFinderAreAllTheSwitcherShowsWhenFinderIsTheOnlyOtherApp() {
        let world = World(apps: [])
        world.launcher.start()
        world.makeRunning([world.app("Finder", in: world.coreServices)])
        world.openSettings()

        world.swipe(3.5, lift: false)
        #expect(names(world.launcher.switcher) == ["Trackpad Launcher", "Finder"])
    }
}
