import Foundation
import Testing
@testable import LauncherCore

extension World {
    /// Sets the first app, then the second, through the two intents.
    func split(_ first: String, _ second: String, on gesture: Gesture) {
        launcher.setAssignment(.app(app(first)), for: gesture)
        launcher.setSecondApp(.app(app(second)), for: gesture)
    }

    func row(_ gesture: Gesture) throws -> GestureRow { try #require(launcher.rows.first { $0.gesture == gesture }) }
}

@MainActor @Suite struct SplitAssignmentTests {
    private func one(_ world: World, _ name: String) -> GestureRow.Apps { .one(.present(world.app(name))) }

    private func two(_ world: World, _ first: String, _ second: String) -> GestureRow.Apps {
        .two(first: .present(world.app(first)), second: .present(world.app(second)))
    }

    @Test func aRowShowsItsAppsItsSecondSlotAndItsLines() throws {
        let world = World(apps: ["Music", "Notes", "Safari"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Music")), for: .two)
        world.split("Notes", "Safari", on: .one)

        let split = try world.row(.one)
        #expect(split.apps == two(world, "Notes", "Safari"))
        #expect(split.app == .present(world.app("Notes")))
        #expect(split.second == .app(.present(world.app("Safari"))))
        #expect(split.firstBundleID == World.bundleID("Notes"))
        #expect(split.lineCount == 2)

        let alone = try world.row(.two)
        #expect(alone.second == .add)
        #expect(alone.firstBundleID == World.bundleID("Music"))
        #expect(alone.lineCount == 1)

        let unassigned = try world.row(.three)
        #expect(unassigned.app == .unassigned)
        #expect(unassigned.second == nil)
        #expect(unassigned.firstBundleID == nil)
        #expect(unassigned.lineCount == 1)

        world.trash("Music")
        world.trash("Safari")
        world.launcher.openedByHand()

        let missingFirst = try world.row(.two)
        #expect(missingFirst.apps == .one(.missing(name: "Music", bundleID: World.bundleID("Music"))))
        #expect(missingFirst.app == .missing(name: "Music"))
        #expect(missingFirst.second == .add)
        #expect(missingFirst.firstBundleID == World.bundleID("Music"))
        #expect(
            try world.row(.one).second == .app(.missing(name: "Safari", bundleID: World.bundleID("Safari"))))
    }

    @Test func aSecondAppIsAcceptedOnlyWhenItIsAnotherAppThanTheFirstOne() throws {
        let world = World(apps: ["Notes", "Safari", "Mail", "Music"])
        world.launcher.start()
        world.install("Tool", in: world.downloads, bundleID: World.bundleID("Notes").rawValue)
        world.install("Notes", in: world.downloads)
        try FileManager.default.createDirectory(
            at: world.downloads.appending(path: "Folder"), withIntermediateDirectories: true)
        for (name, gesture) in [("Notes", Gesture.one), ("Mail", .two), ("Safari", .four), ("Music", .five)] {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
        world.trash("Music")
        world.launcher.openedByHand()

        #expect(world.launcher.setSecondApp(.app(world.app("Safari")), for: .one) == world.app("Safari"))
        #expect(try world.row(.one).apps == two(world, "Notes", "Safari"))
        #expect(world.system.preparedLaunchAnimations.filter { $0 == world.app("Safari") }.count == 1)

        let tool = world.app("Tool", in: world.downloads)
        #expect(world.launcher.setSecondApp(.appBundle(at: tool.url), for: .two) == tool)
        #expect(try world.row(.two).apps == .two(first: .present(world.app("Mail")), second: .present(tool)))

        let rows = world.launcher.rows
        let bytes = world.settingsRecordBytes()
        #expect(world.launcher.setSecondApp(.app(world.app("Notes")), for: .one) == nil)
        #expect(
            world.launcher.setSecondApp(.appBundle(at: world.downloads.appending(path: "Notes.app")), for: .one) == nil)
        #expect(
            world.launcher.setSecondApp(.appBundle(at: world.downloads.appending(path: "Folder")), for: .one) == nil)
        #expect(world.launcher.setSecondApp(.app(world.app("Safari")), for: .three) == nil)
        #expect(world.settingsRecordBytes() == bytes)
        #expect(world.launcher.rows == rows)

        let music = try world.row(.five).apps
        #expect(world.launcher.setSecondApp(.app(world.app("Safari")), for: .five) == world.app("Safari"))
        #expect(music == .one(.missing(name: "Music", bundleID: World.bundleID("Music"))))
        #expect(
            try world.row(.five).apps
                == .two(first: .missing(name: "Music", bundleID: World.bundleID("Music")), second: .present(world.app("Safari"))))
    }

    @Test func aGestureNeverHoldsOneAppTwiceAndEveryChangeIsSavedAtOnce() throws {
        let world = World(apps: ["Notes", "Safari", "Mail"])
        world.launcher.start()
        let launcher = world.launcher

        func check(_ apps: GestureRow.Apps, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let row = try world.row(.one)
            #expect(row.apps == apps, sourceLocation: sourceLocation)
            let ids = row.held.map(\.bundleID)
            #expect(Set(ids).count == ids.count, "no app on both lines", sourceLocation: sourceLocation)
            let saved = world.freshStore().load()?.assignments[.one]
            let savedIDs = saved.map { [$0.first.bundleID] + ($0.second.map { [$0.bundleID] } ?? []) } ?? []
            #expect(savedIDs == ids, "saved is what the row shows", sourceLocation: sourceLocation)
        }

        launcher.setAssignment(.app(world.app("Notes")), for: .one)
        try check(one(world, "Notes"))
        launcher.setSecondApp(.app(world.app("Safari")), for: .one)
        try check(two(world, "Notes", "Safari"))
        #expect(launcher.setSecondApp(.app(world.app("Mail")), for: .one) == world.app("Mail"))
        try check(two(world, "Notes", "Mail"))
        launcher.setAssignment(.app(world.app("Safari")), for: .one)
        try check(two(world, "Safari", "Mail"))
        #expect(launcher.setAssignment(.app(world.app("Mail")), for: .one) == world.app("Mail"))
        try check(one(world, "Mail"))
        #expect(try world.row(.one).second == .add)
        launcher.setSecondApp(.app(world.app("Notes")), for: .one)
        try check(two(world, "Mail", "Notes"))
        launcher.removeSecondApp(for: .one)
        try check(one(world, "Mail"))
        #expect(try world.row(.one).second == .add)
        let bytes = world.settingsRecordBytes()
        launcher.removeSecondApp(for: .one)
        try check(one(world, "Mail"))
        #expect(world.settingsRecordBytes() == bytes)
        launcher.setSecondApp(.app(world.app("Safari")), for: .one)
        try check(two(world, "Mail", "Safari"))
        launcher.setAssignment(nil, for: .one)
        try check(.unassigned)
        #expect(try world.row(.one).second == nil)
        #expect(world.freshStore().load()?.assignments[.one] == nil)

        world.relaunch().start()
        #expect(try world.row(.one).apps == .unassigned)
    }

    private func entry(_ world: World, _ name: String) -> [String: Any] {
        [
            "bundleID": ["rawValue": World.bundleID(name).rawValue],
            "lastKnownURL": ["relative": world.app(name).url.absoluteString],
            "name": name,
        ]
    }

    private func record(_ world: World) throws -> [String: Any] {
        let bytes = try #require(world.settingsRecordBytes())
        return try #require(try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
    }

    private func assignment(_ world: World, _ gesture: String) throws -> [String: Any] {
        let assignments = try #require(try record(world)["assignments"] as? [String: [String: Any]])
        return try #require(assignments[gesture])
    }

    @Test func aSecondAppSurvivesARelaunchAndIsSavedBesideTheFirstAppsThreeKeys() throws {
        let world = World(apps: ["Notes", "Safari"])
        world.launcher.start()
        world.split("Notes", "Safari", on: .one)

        world.relaunch().start()
        #expect(try world.row(.one).apps == two(world, "Notes", "Safari"))
        world.launcher.openedByHand()
        #expect(try world.row(.one).apps == two(world, "Notes", "Safari"))

        let saved = try assignment(world, "1")
        #expect(Set(saved.keys) == ["bundleID", "name", "lastKnownURL", "secondApp"])
        #expect((saved["bundleID"] as? [String: String])?["rawValue"] == World.bundleID("Notes").rawValue)
        #expect(saved["name"] as? String == "Notes")
        let second = try #require(saved["secondApp"] as? [String: Any])
        #expect(Set(second.keys) == ["bundleID", "name", "lastKnownURL"])
        #expect((second["bundleID"] as? [String: String])?["rawValue"] == World.bundleID("Safari").rawValue)

        world.launcher.removeSecondApp(for: .one)
        #expect(Set(try assignment(world, "1").keys) == ["bundleID", "name", "lastKnownURL"])
    }

    @Test func aRecordHoldingTheFirstAppAsTheSecondLoadsAsOneApp() throws {
        let world = World(apps: ["Notes"])
        var saved = entry(world, "Notes")
        saved["secondApp"] = entry(world, "Notes")
        world.seedSuite([
            "settings": try PropertyListSerialization.data(
                fromPropertyList: ["assignments": ["1": saved]], format: .xml, options: 0)
        ])

        world.relaunch().start()

        #expect(try world.row(.one).apps == one(world, "Notes"))
        #expect(try world.row(.one).second == .add)
    }

    @Test func aReleasedRecordLoadsWithoutSecondAppsAndFiresItsFirstAppAlone() throws {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(PersistenceTests.savedSettings.utf8))

        world.relaunch().start()

        for gesture in [Gesture.one, .two, .five] {
            guard case .one = try world.row(gesture).apps else {
                Issue.record("gesture \(gesture) holds one app")
                continue
            }
            #expect(try world.row(gesture).second == .add)
        }
        #expect(try world.row(.three).apps == .unassigned)
        #expect(try world.row(.four).apps == .unassigned)

        world.tap(1, thumbIn: .topRight)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.system.splits.isEmpty)
    }

    @Test func aRecordTheReleasedVersionWroteShowsItsAppAsOneApp() throws {
        let world = World(apps: ["Notes"])
        var old = PersistenceTests.Build1018Settings()
        old.assignments[.three] = AssignedApp(world.app("Notes"))
        old.isHideBackgroundAppsOn = true
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        world.seedSettingsRecord(try encoder.encode(old))

        world.relaunch().start()

        #expect(try world.row(.three).apps == one(world, "Notes"))
        #expect(world.launcher.isHideBackgroundAppsOn)
    }

    @Test func theReleasedVersionReadsASplitRecordAndSavesItsFirstAppsOnly() throws {
        let world = World(apps: ["Notes", "Safari", "Mail"])
        world.launcher.start()
        world.split("Notes", "Safari", on: .one)
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.launcher.setHideBackgroundApps(on: true)

        let old = try PropertyListDecoder().decode(
            PersistenceTests.Build1018Settings.self, from: try #require(world.settingsRecordBytes()))
        #expect(old.assignments[.one]?.bundleID == World.bundleID("Notes"))
        #expect(old.assignments[.two]?.bundleID == World.bundleID("Mail"))
        #expect(old.isHideBackgroundAppsOn)

        try world.previousVersionSaves { $0.isSwipeOn = false }
        world.relaunch().start()

        #expect(try world.row(.one).apps == one(world, "Notes"))
        #expect(try world.row(.one).second == .add)
        #expect(try world.row(.two).apps == one(world, "Mail"))
        #expect(world.launcher.isHideBackgroundAppsOn)
        #expect(world.launcher.isSwipeOn == false)
    }
    @Test(arguments: [(aloneToo: false, row: ["Music", "Safari", "Mail", "Notes"]), (true, ["Music", "Mail", "Notes"])])
    func theSwitcherLeavesOutOnlyTheAppsAGestureHoldsAlone(aloneToo: Bool, row: [String]) {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes", "Music"], frontmost: "Music")
        world.split("Notes", "Safari", on: .one)
        if aloneToo { world.launcher.setAssignment(.app(world.app("Safari")), for: .two) }

        world.swipe(3.5, lift: false)

        #expect(world.launcher.switcher?.row.map(\.name) == row)
    }
}
