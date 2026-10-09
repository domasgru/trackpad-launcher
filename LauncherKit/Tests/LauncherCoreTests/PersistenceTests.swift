import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct PersistenceTests {
    @Test func assignmentsAndHandModeSurviveARelaunch() {
        let names = ["Arc", "Figma", "Notion", "Spotify"]
        let world = World(apps: names)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, names) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
        world.launcher.setHandMode(.left)

        let relaunched = world.relaunch()

        #expect(relaunched.rows.map(\.app) == names.map { .present(world.app($0)) })
        #expect(relaunched.handMode == .left)
    }

    @Test func firstLaunchShowsFreshDefaultsOpensTheWindowAndRegistersTheLoginItem() {
        let world = World()

        world.launcher.start()

        #expect(world.launcher.rows.map(\.app) == Array(repeating: .unassigned, count: 4))
        #expect(world.launcher.handMode == .right)
        #expect(world.launcher.isWindowOpen)
        #expect(world.system.loginItemRegistrations == 1)
    }

    @Test func secondLaunchStaysQuietAndDoesNotRegisterAgain() {
        let world = World()
        world.launcher.start()

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(!relaunched.isWindowOpen)
        #expect(world.system.loginItemRegistrations == 1)
    }

    @Test func undecodableRecordLoadsAsDefaultsNotAsFirstLaunch() {
        let world = World()
        UserDefaults(suiteName: world.suiteName)!.set(Data("garbage".utf8), forKey: "settings")
        let relaunched = world.relaunch()

        relaunched.start()

        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: 4))
        #expect(relaunched.handMode == .right)
    }

    @Test func loginItemIsRegisteredBeforeTheFirstSave() {
        let world = World()
        var storedAtRegistration: [Settings?] = []
        world.system.onRegisterLoginItem = { storedAtRegistration.append(world.store.load()) }

        world.launcher.start()

        #expect(storedAtRegistration == [nil])
        #expect(world.store.load() != nil)
    }

    @Test func assignmentReachesTheSystemDefaultsNotAnInstanceCache() {
        let world = World(apps: ["Arc"])
        world.launcher.start()

        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        let fresh = SettingsStore(defaults: UserDefaults(suiteName: world.suiteName)!)
        #expect(fresh.load()?.assignments[.one]?.bundleID == World.bundleID("Arc"))
    }
}
