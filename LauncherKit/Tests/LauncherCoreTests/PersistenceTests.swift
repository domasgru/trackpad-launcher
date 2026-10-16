import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct PersistenceTests {
    @Test func assignmentsAndHandModeSurviveARelaunch() {
        let names = ["Arc", "Figma", "Notion", "Spotify", "Slack"]
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

        #expect(world.launcher.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
        #expect(world.launcher.handMode == .right)
        #expect(world.launcher.isLaunchAnimationOn)
        #expect(world.launcher.isSwipeOn)
        #expect(world.launcher.isSwapOn)
        #expect(world.launcher.isWindowSwipeOn)
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
        world.seedSettingsRecord(Data("garbage".utf8))
        let relaunched = world.relaunch()

        relaunched.start()

        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
        #expect(relaunched.handMode == .right)
        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
    }

    @Test func loginItemIsRegisteredBeforeTheFirstSave() {
        let world = World()
        var storedAtRegistration: [Settings?] = []
        world.system.onRegisterLoginItem = { [unowned world] in storedAtRegistration.append(world.store.load()) }

        world.launcher.start()

        #expect(storedAtRegistration == [nil])
        #expect(world.store.load() != nil)
    }

    /// A record this build has already written must keep loading in every later build: a renamed field, key or raw
    /// value either fails the whole record, which loads as `Settings()` and silently wipes every assignment, or drops
    /// that one field back to its default. Records from before a field existed are covered by
    /// `upgradingFromARecordWithoutTheLaunchAnimationSettingKeepsEverythingElse`.
    @Test func settingsSavedInTheCurrentFormatStillLoad() {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(Self.savedSettings.utf8))

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(
            relaunched.rows.map(\.app) == [
                .present(world.app("Arc")), .present(world.app("Figma")), .unassigned, .unassigned,
                .present(world.app("Spotify")),
            ])
        #expect(relaunched.handMode == .left)
        #expect(!relaunched.isLaunchAnimationOn)
        #expect(!relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
        #expect(relaunched.isWindowSwipeOn)
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

    private func threeAppsThenUnassigned(_ world: World) -> [RowApp] {
        [.present(world.app("Arc")), .present(world.app("Figma")), .present(world.app("Notion")), .unassigned, .unassigned]
    }

    @Test func upgradingFromARecordWithoutTheLaunchAnimationSettingKeepsEverythingElse() throws {
        let world = World(apps: ["Arc", "Figma", "Notion"])
        let old = try recordFromBeforeTheLaunchAnimationSetting(world)
        world.seedSettingsRecord(old)

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.handMode == .left)
        #expect(relaunched.rows.map(\.app) == threeAppsThenUnassigned(world))
        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
    }

    @Test func theFirstSaveAfterAnUpgradeCarriesTheOldSettingsWithIt() throws {
        let world = World(apps: ["Arc", "Figma", "Notion"])
        let old = try recordFromBeforeTheLaunchAnimationSetting(world)
        world.seedSettingsRecord(old)
        world.relaunch().start()

        world.launcher.setLaunchAnimation(on: false)
        let relaunched = world.relaunch()

        #expect(!relaunched.isLaunchAnimationOn)
        #expect(relaunched.handMode == .left)
        #expect(relaunched.rows.map(\.app) == threeAppsThenUnassigned(world))
    }

    @Test func anEmptyRecordDecodesAsDefaultsNotAsFirstLaunch() throws {
        let world = World()
        let empty = try PropertyListSerialization.data(fromPropertyList: [String: Any](), format: .xml, options: 0)
        world.seedSettingsRecord(empty)

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.handMode == .right)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: Gesture.allCases.count))
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

    @Test func turningTheSwipeOffSurvivesARelaunchAndAnOlderRecordLoadsWithTheSwipeOn() {
        let world = World()
        world.launcher.start()
        world.launcher.setSwipe(on: false)

        #expect(!world.relaunch().isSwipeOn)

        let older = World(apps: ["Arc"])
        let arc = older.app("Arc")
        older.seedSettingsRecord(Fixtures.recordSavedByPlan002(handMode: .left, two: arc))
        let loaded = older.relaunch()

        #expect(loaded.isSwipeOn)
        #expect(loaded.isSwapOn)
        #expect(loaded.isWindowSwipeOn)
        #expect(loaded.handMode == .left)
        #expect(loaded.rows.map(\.app)[1] == .present(arc))
    }

    @Test func turningTheSwapOffSurvivesARelaunchAndAFreshWorldSwaps() {
        let fresh = World.switcherWorld()
        #expect(fresh.launcher.isSwapOn)
        fresh.swap()
        #expect(fresh.system.broughtToFront == [fresh.app("Mail")])

        let world = World()
        world.launcher.start()
        world.launcher.setSwap(on: false)
        #expect(!world.relaunch().isSwapOn)
    }

    @Test func aRecordHoldingOnlyTheSwapKeyLoadsWithTheSwapOffAndEveryOtherDefault() {
        let world = World()
        world.seedSettingsRecord(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>isSwapOn</key>
                <false/>
            </dict>
            </plist>
            """.utf8))

        var expected = Settings()
        expected.isSwapOn = false
        #expect(world.store.load() == expected)
    }

    @Test func turningTheWindowSwipeOffSurvivesARelaunch() {
        let world = World()
        world.launcher.start()
        world.launcher.setWindowSwipe(on: false)

        let relaunched = world.relaunch()

        #expect(!relaunched.isWindowSwipeOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
    }

    @Test func aRecordHoldingOnlyTheWindowSwipeKeyLoadsWithItOffAndEveryOtherDefault() {
        let world = World()
        world.seedSettingsRecord(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>isWindowSwipeOn</key>
                <false/>
            </dict>
            </plist>
            """.utf8))

        var expected = Settings()
        expected.isWindowSwipeOn = false
        #expect(world.store.load() == expected)
    }

    @Test func everySettingsFieldSurvivesTheStore() {
        let world = World(apps: ["Arc"])
        var settings = Settings()
        settings.handMode = .left
        settings.assignments = [.three: AssignedApp(world.app("Arc"))]
        settings.isLaunchAnimationOn = false
        settings.isSwipeOn = false
        settings.isSwapOn = false
        settings.isWindowSwipeOn = false
        settings.hasAskedForScreenRecording = true
        #expect(settings != Settings())

        world.store.save(settings)

        #expect(world.store.load() == settings)
    }

    /// Written by `SettingsStore.save` (binary plist) and converted with `plutil -convert xml1`: Left hand, Launch
    /// animation off, apps on gestures 1, 2 and 5, and two apps in the switcher list. Never regenerate: this is the
    /// format released builds write. It predates the swap and window swipe keys, so it also proves an upgrade keeps both on. The
    /// paths live under `/tl-fixture`, which no Mac has, so each app
    /// resolves through the world's registry and never through whatever this machine has installed.
    private static let savedSettings = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>assignments</key>
            <dict>
                <key>1</key>
                <dict>
                    <key>bundleID</key>
                    <dict>
                        <key>rawValue</key>
                        <string>company.thebrowser.Browser</string>
                    </dict>
                    <key>lastKnownURL</key>
                    <dict>
                        <key>relative</key>
                        <string>file:///tl-fixture/Applications/Arc.app</string>
                    </dict>
                    <key>name</key>
                    <string>Arc</string>
                </dict>
                <key>2</key>
                <dict>
                    <key>bundleID</key>
                    <dict>
                        <key>rawValue</key>
                        <string>com.figma.Desktop</string>
                    </dict>
                    <key>lastKnownURL</key>
                    <dict>
                        <key>relative</key>
                        <string>file:///tl-fixture/Applications/Figma.app/</string>
                    </dict>
                    <key>name</key>
                    <string>Figma</string>
                </dict>
                <key>5</key>
                <dict>
                    <key>bundleID</key>
                    <dict>
                        <key>rawValue</key>
                        <string>com.spotify.client</string>
                    </dict>
                    <key>lastKnownURL</key>
                    <dict>
                        <key>relative</key>
                        <string>file:///tl-fixture/Users/someone/Applications/Spotify.app</string>
                    </dict>
                    <key>name</key>
                    <string>Spotify</string>
                </dict>
            </dict>
            <key>handMode</key>
            <string>left</string>
            <key>isLaunchAnimationOn</key>
            <false/>
            <key>isSwipeOn</key>
            <false/>
        </dict>
        </plist>
        """
}
