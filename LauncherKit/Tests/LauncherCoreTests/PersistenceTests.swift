import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct PersistenceTests {
    @Test func assignmentsAndThumbCornerSurviveARelaunch() {
        let names = ["Arc", "Figma", "Notion", "Spotify", "Slack"]
        let world = World(apps: names)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, names) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
        world.launcher.setThumbCorner(.topRight)

        let relaunched = world.relaunch()

        #expect(relaunched.rows.map(\.app) == names.map { .present(world.app($0)) })
        #expect(relaunched.thumbCorner == .topRight)
    }

    @Test func firstRunShowsFreshDefaultsOpensTheWindowAndRegistersTheLoginItem() {
        let world = World()
        world.launcher.start()
        world.launcher.openedByHand()
        world.launcher.start()

        #expect(world.launcher.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
        #expect(world.launcher.thumbCorner == .topLeft)
        #expect(world.launcher.isLaunchAnimationOn)
        #expect(world.launcher.isSwipeOn)
        #expect(world.launcher.isSwapOn)
        #expect(!world.launcher.isWindowSwipeOn)
        #expect(world.launcher.isWindowOpen)
        #expect(world.loginItem.calls == ["register"])
    }

    @Test func secondLaunchStaysQuietAndDoesNotRegisterAgain() {
        let world = World()
        world.launcher.start()
        world.launcher.openedByHand()

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(!relaunched.isWindowOpen)
        #expect(world.loginItem.calls == ["register"])
    }

    @Test func undecodableRecordLoadsAsDefaultsNotAsFirstLaunch() {
        let world = World()
        world.seedSettingsRecord(Data("garbage".utf8))
        let relaunched = world.relaunch()

        relaunched.start()
        relaunched.openedByHand()

        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
        #expect(relaunched.thumbCorner == .topLeft)
        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
    }

    @Test func loginItemIsRegisteredBeforeTheFirstSave() {
        let world = World()
        var storedAtRegistration: [Settings?] = []
        world.loginItem.onRegister = { [unowned world] in storedAtRegistration.append(world.store.load()) }

        world.launcher.start()
        world.launcher.openedByHand()

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
        #expect(relaunched.thumbCorner == .topRight)
        #expect(!relaunched.isLaunchAnimationOn)
        #expect(!relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
        #expect(!relaunched.isWindowSwipeOn)
    }

    @Test func aReleasedRecordWithRightThumbLoadsAsTopRightAndAnchorsThereAtLogin() {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(Self.savedSettings.utf8))

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(!relaunched.isWindowOpen)
        #expect(relaunched.thumbCorner == .topRight)
        world.tap(1, thumbAtMM: (114.8, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])
        world.tap(1, thumbAtMM: (10, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])

        relaunched.openedByHand()
        #expect(relaunched.isWindowOpen)
        #expect(relaunched.thumbCorner == .topRight)
    }

    @Test func aRecordSavedWithLeftThumbLoadsAsTopLeft() {
        let world = World()
        world.seedSettingsRecord(Fixtures.recordSavedByPlan002(handMode: "right"))
        #expect(world.relaunch().thumbCorner == .topLeft)
    }

    @Test func aChosenCornerOpensTheWindowShowingIt() {
        let world = World()
        world.launcher.start()
        world.launcher.setThumbCorner(.bottomLeft)

        let relaunched = world.relaunch()
        relaunched.start()
        relaunched.openedByHand()

        #expect(relaunched.thumbCorner == .bottomLeft)
        #expect(relaunched.isWindowOpen)
    }

    @Test func aBottomRightChoiceSurvivesARelaunchAndTheThumbAnchorsThere() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setThumbCorner(.bottomRight)

        let relaunched = world.relaunch()
        relaunched.start()
        #expect(relaunched.thumbCorner == .bottomRight)

        world.tap(1, thumbAtMM: (114.8, 66.8))
        #expect(world.system.broughtToFront == [world.app("Arc")])
        world.tap(1, thumbAtMM: (114.8, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])

        relaunched.openedByHand()
        #expect(relaunched.thumbCorner == .bottomRight)
    }

    @Test func aFirstRunAnchorsTopLeft() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.openedByHand()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        #expect(world.launcher.thumbCorner == .topLeft)

        world.tap(1, thumbAtMM: (10, 10))
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    /// What build 1.0.6 reads and writes: the hand under `handMode` and no key for the bottom corners.
    struct Build106Settings: Codable {
        enum HandMode: String, Codable { case right, left }

        var handMode: HandMode = .right
        var assignments: [Gesture: AssignedApp] = [:]
        var isLaunchAnimationOn = true
        var isSwipeOn = true
        var isSwapOn = true
        var isWindowSwipeOn = false
        var hasAskedForScreenRecording = false

        init() {}

        init(from decoder: any Decoder) throws {
            self.init()
            let container = try decoder.container(keyedBy: CodingKeys.self)
            handMode = try container.decodeIfPresent(HandMode.self, forKey: .handMode) ?? handMode
            assignments = try container.decodeIfPresent([Gesture: AssignedApp].self, forKey: .assignments) ?? assignments
            isLaunchAnimationOn = try container.decodeIfPresent(Bool.self, forKey: .isLaunchAnimationOn) ?? isLaunchAnimationOn
            isSwipeOn = try container.decodeIfPresent(Bool.self, forKey: .isSwipeOn) ?? isSwipeOn
            isSwapOn = try container.decodeIfPresent(Bool.self, forKey: .isSwapOn) ?? isSwapOn
            isWindowSwipeOn = try container.decodeIfPresent(Bool.self, forKey: .isWindowSwipeOn) ?? isWindowSwipeOn
            hasAskedForScreenRecording =
                try container.decodeIfPresent(Bool.self, forKey: .hasAskedForScreenRecording) ?? hasAskedForScreenRecording
        }
    }

    private func savedRecord(_ world: World) throws -> [String: Any] {
        let bytes = try #require(world.settingsRecordBytes())
        return try #require(try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
    }

    @Test(arguments: [
        (corner: ThumbCorner.bottomRight, hand: "left", hand106: Build106Settings.HandMode.left),
        (.bottomLeft, "right", .right),
    ])
    func aBottomCornerIsSavedSoThatBuild106KeepsEverythingElseAndAnchorsOnTheSameSide(
        corner: ThumbCorner, hand: String, hand106: Build106Settings.HandMode
    ) throws {
        let world = World(apps: ["Arc", "Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.launcher.setLaunchAnimation(on: false)
        world.launcher.setSwipe(on: false)
        world.launcher.setSwap(on: false)
        world.launcher.setWindowSwipe(on: true)
        world.launcher.setThumbCorner(corner)

        let record = try savedRecord(world)
        #expect(record["handMode"] as? String == hand)
        #expect(record["isThumbAtBottom"] as? Bool == true)
        #expect(record["isLaunchAnimationOn"] as? Bool == false)
        #expect(record["isSwipeOn"] as? Bool == false)
        #expect(record["isSwapOn"] as? Bool == false)
        #expect(record["isWindowSwipeOn"] as? Bool == true)
        let assignments = try #require(record["assignments"] as? [String: [String: Any]])
        #expect((assignments["1"]?["bundleID"] as? [String: String])?["rawValue"] == World.bundleID("Arc").rawValue)
        #expect((assignments["2"]?["bundleID"] as? [String: String])?["rawValue"] == World.bundleID("Figma").rawValue)

        let old = try PropertyListDecoder().decode(
            Build106Settings.self, from: try #require(world.settingsRecordBytes()))
        #expect(old.handMode == hand106)
        #expect(old.assignments[.one]?.bundleID == World.bundleID("Arc"))
        #expect(old.assignments[.two]?.bundleID == World.bundleID("Figma"))
        #expect(!old.isLaunchAnimationOn && !old.isSwipeOn && !old.isSwapOn && old.isWindowSwipeOn)
    }

    private func plist(_ record: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: record, format: .xml, options: 0)
    }

    private func loaded(_ record: [String: Any]) throws -> Settings {
        let world = World()
        world.seedSettingsRecord(try plist(record))
        return try #require(world.store.load())
    }

    @Test(arguments: [
        (hand: String?.none, isAtBottom: Bool?.some(true), corner: ThumbCorner.bottomLeft),
        ("left", nil, .topRight),
        ("left", true, .bottomRight),
        ("right", false, .topLeft),
        (nil, nil, .topLeft),
    ])
    func theTwoCornerKeysDecodeIndependentlyAndEveryOtherFieldKeepsItsDefault(
        hand: String?, isAtBottom: Bool?, corner: ThumbCorner
    ) throws {
        var record: [String: Any] = [:]
        record["handMode"] = hand
        record["isThumbAtBottom"] = isAtBottom
        var expected = Settings()
        expected.thumbCorner = corner
        #expect(try loaded(record) == expected)
    }

    @Test func aRecordBuild106WroteLoadsWithItsHandAsATopCornerAndEverythingElseAsWritten() throws {
        let world = World(apps: ["Arc"])
        var old = Build106Settings()
        old.handMode = .left
        old.assignments = [.three: AssignedApp(world.app("Arc"))]
        old.isLaunchAnimationOn = false
        old.isSwipeOn = false
        old.isSwapOn = false
        old.isWindowSwipeOn = true
        old.hasAskedForScreenRecording = true
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        world.seedSettingsRecord(try encoder.encode(old))

        let settings = try #require(world.store.load())

        var expected = Settings()
        expected.thumbCorner = .topRight
        expected.assignments = [.three: AssignedApp(world.app("Arc"))]
        expected.isLaunchAnimationOn = false
        expected.isSwipeOn = false
        expected.isSwapOn = false
        expected.isWindowSwipeOn = true
        expected.hasAskedForScreenRecording = true
        #expect(settings == expected)
    }

    @Test func aNonBooleanBottomKeyFailsTheWholeRecord() throws {
        #expect(try loaded(["isThumbAtBottom": "yes", "isSwapOn": false]) == Settings())
    }

    @Test(arguments: ThumbCorner.allCases)
    func eachThumbCornerSurvivesTheStore(corner: ThumbCorner) {
        let world = World()
        var settings = Settings()
        settings.thumbCorner = corner
        world.store.save(settings)
        #expect(world.store.load()?.thumbCorner == corner)
    }

    /// The record a build without the launch animation setting wrote for the top-right corner with Arc, Figma and Notion on
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
        relaunched.openedByHand()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.thumbCorner == .topRight)
        #expect(relaunched.rows.map(\.app) == threeAppsThenUnassigned(world))
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
    }

    @Test func theFirstSaveAfterAnUpgradeCarriesTheOldSettingsWithIt() throws {
        let world = World(apps: ["Arc", "Figma", "Notion"])
        let old = try recordFromBeforeTheLaunchAnimationSetting(world)
        world.seedSettingsRecord(old)
        world.relaunch().start()

        world.launcher.setLaunchAnimation(on: false)
        let relaunched = world.relaunch()

        #expect(!relaunched.isLaunchAnimationOn)
        #expect(relaunched.thumbCorner == .topRight)
        #expect(relaunched.rows.map(\.app) == threeAppsThenUnassigned(world))
    }

    @Test func anEmptyRecordDecodesAsDefaultsNotAsFirstLaunch() throws {
        let world = World()
        let empty = try PropertyListSerialization.data(fromPropertyList: [String: Any](), format: .xml, options: 0)
        world.seedSettingsRecord(empty)

        let relaunched = world.relaunch()
        relaunched.start()
        relaunched.openedByHand()

        #expect(relaunched.isLaunchAnimationOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.thumbCorner == .topLeft)
        #expect(relaunched.rows.map(\.app) == Array(repeating: .unassigned, count: Gesture.allCases.count))
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
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
        #expect(world.system.bounces.isEmpty)
    }

    @Test func turningTheSwipeOffSurvivesARelaunchAndAnOlderRecordLoadsWithTheSwipeOn() {
        let world = World()
        world.launcher.start()
        world.launcher.setSwipe(on: false)

        #expect(!world.relaunch().isSwipeOn)

        let older = World(apps: ["Arc"])
        let arc = older.app("Arc")
        older.seedSettingsRecord(Fixtures.recordSavedByPlan002(handMode: "left", two: arc))
        let loaded = older.relaunch()

        #expect(loaded.isSwipeOn)
        #expect(loaded.isSwapOn)
        #expect(!loaded.isWindowSwipeOn)
        #expect(loaded.thumbCorner == .topRight)
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

    @Test func turningTheWindowSwipeOnSurvivesARelaunch() {
        let world = World()
        world.launcher.start()
        world.launcher.setWindowSwipe(on: true)

        let relaunched = world.relaunch()

        #expect(relaunched.isWindowSwipeOn)
        #expect(relaunched.isSwipeOn)
        #expect(relaunched.isSwapOn)
    }

    @Test func aRecordHoldingOnlyTheWindowSwipeKeyLoadsWithItOnAndEveryOtherDefault() {
        let world = World()
        world.seedSettingsRecord(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>isWindowSwipeOn</key>
                <true/>
            </dict>
            </plist>
            """.utf8))

        var expected = Settings()
        expected.isWindowSwipeOn = true
        #expect(world.store.load() == expected)
    }

    @Test func everySettingsFieldSurvivesTheStore() {
        let world = World(apps: ["Arc"])
        var settings = Settings()
        settings.thumbCorner = .bottomRight
        settings.assignments = [.three: AssignedApp(world.app("Arc"))]
        settings.isLaunchAnimationOn = false
        settings.isSwipeOn = false
        settings.isSwapOn = false
        settings.isWindowSwipeOn = true
        settings.hasAskedForScreenRecording = true
        #expect(settings != Settings())

        world.store.save(settings)

        #expect(world.store.load() == settings)
    }

    /// Written by `SettingsStore.save` (binary plist) and converted with `plutil -convert xml1`: top-right corner, Launch
    /// animation off, apps on gestures 1, 2 and 5, and two apps in the switcher list. Never regenerate: this is the
    /// format released builds write. It predates the swap and window swipe keys, so it also proves an upgrade takes both defaults:
    /// the swap on, the window swipe off. The paths live under `/tl-fixture`, which no Mac has, so each app
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
