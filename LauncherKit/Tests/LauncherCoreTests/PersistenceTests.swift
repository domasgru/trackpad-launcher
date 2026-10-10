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
        #expect(world.launcher.isLaunchAnimationOn)
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
        #expect(relaunched.isLaunchAnimationOn)
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

    /// The record a build without the launch animation setting wrote for Left hand with Arc, Figma and Notion on
    /// gestures 1 to 3, with the World's own app URLs.
    private func recordFromBeforeTheLaunchAnimationSetting(_ world: World) throws -> Data {
        func assignment(_ name: String) -> [String: Any] {
            [
                "bundleID": ["rawValue": World.bundleID(name).rawValue],
                "lastKnownURL": ["relative": world.app(name).url.absoluteString],
                "name": name,
            ]
        }
        let record: [String: Any] = [
            "assignments": ["1": assignment("Arc"), "2": assignment("Figma"), "3": assignment("Notion")],
            "handMode": "left",
        ]
        return try PropertyListSerialization.data(fromPropertyList: record, format: .xml, options: 0)
    }

    @Test func upgradingFromARecordWithoutTheLaunchAnimationSettingKeepsEverythingElse() throws {
        let world = World(apps: ["Arc", "Figma", "Notion"])
        let old = try recordFromBeforeTheLaunchAnimationSetting(world)
        UserDefaults(suiteName: world.suiteName)!.set(old, forKey: "settings")

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.handMode == .left)
        #expect(
            relaunched.rows.map(\.app)
                == [.present(world.app("Arc")), .present(world.app("Figma")), .present(world.app("Notion")), .unassigned])
        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
    }

    @Test func theFirstSaveAfterAnUpgradeCarriesTheOldSettingsWithIt() throws {
        let world = World(apps: ["Arc", "Figma", "Notion"])
        let old = try recordFromBeforeTheLaunchAnimationSetting(world)
        UserDefaults(suiteName: world.suiteName)!.set(old, forKey: "settings")
        world.relaunch().start()

        world.launcher.setLaunchAnimation(on: false)
        let relaunched = world.relaunch()

        #expect(!relaunched.isLaunchAnimationOn)
        #expect(relaunched.handMode == .left)
        #expect(
            relaunched.rows.map(\.app)
                == [.present(world.app("Arc")), .present(world.app("Figma")), .present(world.app("Notion")), .unassigned])
    }

    @Test func anEmptyRecordDecodesAsDefaultsNotAsFirstLaunch() throws {
        let world = World()
        let empty = try PropertyListSerialization.data(fromPropertyList: [String: Any](), format: .xml, options: 0)
        UserDefaults(suiteName: world.suiteName)!.set(empty, forKey: "settings")

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.handMode == .right)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: 4))
        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
    }

    @Test func turningTheLaunchAnimationOffSurvivesARelaunchAndGesturesShowNoIcon() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setLaunchAnimation(on: false)

        let relaunched = world.relaunch()
        relaunched.start()
        world.tap(1)

        #expect(!relaunched.isLaunchAnimationOn)
        #expect(world.hardware.feedback.count == 1)
        #expect(world.system.launchAnimations.isEmpty)
    }
}
