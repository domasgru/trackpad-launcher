import Foundation
import Synchronization
import Testing
import LauncherCore

@MainActor @Suite struct SwitcherListTests {
    private func names(_ launcher: Launcher) -> [String] { launcher.switcherRows.map(\.assigned.name) }

    private func started(_ apps: [String], listing listed: [String] = []) -> World {
        let world = World(apps: apps)
        world.launcher.start()
        for name in listed { world.launcher.addToSwitcher(.app(world.app(name))) }
        return world
    }

    @Test func rowsFollowTheListAndAMissingAppRecoversWithoutReadding() {
        let world = started(["Safari", "Mail", "Slack", "Notes", "Figma"], listing: ["Mail", "Slack", "Notes"])
        #expect(names(world.launcher) == ["Mail", "Slack", "Notes"])
        #expect(world.launcher.switcherRows.allSatisfy { $0.present != nil })

        world.launcher.addToSwitcher(.app(world.app("Figma")))
        world.trash("Figma")
        world.launcher.openWindow()
        #expect(world.launcher.switcherRows.last?.assigned.name == "Figma")
        #expect(world.launcher.switcherRows.last?.present == nil)

        world.install("Figma")
        world.registry[World.bundleID("Figma")] = [world.applications.appending(path: "Figma.app")]
        world.launcher.openWindow()
        #expect(world.launcher.switcherRows.last?.present == world.app("Figma"))
    }

    @Test func addingAppendsAndIgnoresAListedOrNonAppChoice() {
        let world = started(["Mail", "Slack", "Notes", "Arc"], listing: ["Mail", "Slack"])
        world.install("Sketch", in: world.downloads)
        try! Data().write(to: world.downloads.appending(path: "Notes.txt"))

        world.launcher.addToSwitcher(.app(world.app("Notes")))
        #expect(names(world.launcher) == ["Mail", "Slack", "Notes"])

        world.launcher.addToSwitcher(.app(world.app("Slack")))
        #expect(names(world.launcher) == ["Mail", "Slack", "Notes"])

        world.launcher.addToSwitcher(.appBundle(at: world.downloads.appending(path: "Sketch.app")))
        #expect(names(world.launcher) == ["Mail", "Slack", "Notes", "Sketch"])
        #expect(world.launcher.switcherRows.last?.present == world.app("Sketch", in: world.downloads))

        world.launcher.addToSwitcher(.appBundle(at: world.downloads.appending(path: "Notes.txt")))
        world.launcher.addToSwitcher(.appBundle(at: world.app("Slack").url))
        #expect(names(world.launcher) == ["Mail", "Slack", "Notes", "Sketch"])
        #expect(world.store.load()?.switcherList.apps.map(\.name) == names(world.launcher))
    }

    @Test func anAppOnATapGestureCanAlsoBeListed() {
        let world = started(["Arc"])
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.launcher.addToSwitcher(.app(world.app("Arc")))

        #expect(names(world.launcher) == ["Arc"])
        #expect(world.launcher.app(for: .one) == .present(world.app("Arc")))
    }

    @Test func removingTakesTheRowOutAndPersists() {
        let world = started(["Mail", "Slack", "Notes"], listing: ["Mail", "Slack", "Notes"])

        world.launcher.removeFromSwitcher(World.bundleID("Slack"))
        #expect(names(world.launcher) == ["Mail", "Notes"])
        world.launcher.removeFromSwitcher(World.bundleID("Notes"))
        #expect(names(world.launcher) == ["Mail"])
        world.launcher.removeFromSwitcher(World.bundleID("Notes"))
        #expect(names(world.launcher) == ["Mail"])
        world.launcher.removeFromSwitcher(World.bundleID("Mail"))

        #expect(world.launcher.switcherRows.isEmpty)
        #expect(world.store.load()?.switcherList.isEmpty == true)
    }

    @Test func aFreshInstallHasNoRows() {
        let world = started([])
        #expect(world.launcher.switcherRows.isEmpty)
        #expect(world.relaunch().switcherRows.isEmpty)
    }

    @Test func movingReordersAndTheOrderSurvivesARelaunch() {
        let world = started(["Mail", "Slack", "Notes"], listing: ["Mail", "Slack", "Notes"])

        world.launcher.moveInSwitcher(World.bundleID("Notes"), to: 0)
        #expect(names(world.launcher) == ["Notes", "Mail", "Slack"])
        world.launcher.moveInSwitcher(World.bundleID("Mail"), to: 99)
        #expect(names(world.launcher) == ["Notes", "Slack", "Mail"])

        #expect(names(world.relaunch()) == ["Notes", "Slack", "Mail"])
    }

    @Test func theFifthAssignmentTheListAndItsOrderSurviveARelaunch() {
        let world = started(["Safari", "Slack", "Notes", "Mail", "Arc"])
        let gestureApps = ["Safari", "Arc", "Notes", "Mail", "Slack"]
        for (gesture, name) in zip(Gesture.allCases, gestureApps) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
        world.launcher.setHandMode(.left)
        world.launcher.addToSwitcher(.app(world.app("Mail")))
        world.launcher.addToSwitcher(.app(world.app("Notes")))
        world.launcher.moveInSwitcher(World.bundleID("Notes"), to: 0)

        let relaunched = world.relaunch()

        #expect(relaunched.rows.map(\.app) == gestureApps.map { .present(world.app($0)) })
        #expect(relaunched.handMode == .left)
        #expect(names(relaunched) == ["Notes", "Mail"])
    }

    @Test(arguments: [HandMode.right, .left])
    func aRecordSavedBeforeTheSwitcherLoadsWithItsAssignmentsAndNoList(handMode: HandMode) {
        let world = World(apps: ["Arc"])
        UserDefaults(suiteName: world.suiteName)!.set(
            Fixtures.recordSavedByPlan002(handMode: handMode, two: world.app("Arc")), forKey: "settings")

        let relaunched = world.relaunch()
        relaunched.start()

        #expect(relaunched.app(for: .two) == .present(world.app("Arc")))
        #expect(relaunched.handMode == handMode)
        #expect(relaunched.switcherRows.isEmpty)
        #expect(relaunched.rows.count == 5)
        #expect(world.system.loginItemRegistrations == 0)
        #expect(!relaunched.isWindowOpen)
    }
}

@MainActor @Suite struct SwitcherListValueTests {
    private func assigned(_ name: String, at path: String? = nil) -> AssignedApp {
        AssignedApp(
            AppEntry(
                bundleID: World.bundleID(name), name: name, url: URL(filePath: path ?? "/Applications/\(name).app")))
    }

    @Test func appendRemoveAndMoveKeepEachAppOnce() {
        let a = assigned("A"), b = assigned("B"), c = assigned("C")
        var list = SwitcherList()
        list.append(a)
        list.append(b)
        list.append(assigned("A", at: "/Elsewhere/A.app"))
        #expect(list.apps == [a, b])

        list.remove(c.bundleID)
        #expect(list.apps == [a, b])
        list.remove(a.bundleID)
        #expect(list.apps == [b])

        list = SwitcherList()
        [a, b, c].forEach { list.append($0) }
        list.move(c.bundleID, to: 0)
        #expect(list.apps == [c, a, b])
        list.move(a.bundleID, to: 2)
        #expect(list.apps == [c, b, a])
        list.move(b.bundleID, to: 1)
        #expect(list.apps == [c, b, a])
        list.move(c.bundleID, to: 99)
        #expect(list.apps == [b, a, c])
        list.move(c.bundleID, to: -1)
        #expect(list.apps == [c, b, a])
        list.move(assigned("D").bundleID, to: 0)
        #expect(list.apps == [c, b, a])
    }

    @Test func settingsRoundTripAndTheListIsAPlainArrayThatDropsDuplicates() throws {
        let a = assigned("A"), b = assigned("B")
        var settings = Settings()
        settings.assignments[.five] = assigned("Slack")
        settings.append(a, b)

        let encoded = try PropertyListEncoder().encode(settings)
        #expect(try PropertyListDecoder().decode(Settings.self, from: encoded) == settings)

        struct Plain: Codable { var switcherList: [AssignedApp] }
        #expect(try PropertyListDecoder().decode(Plain.self, from: encoded).switcherList == [a, b])

        let duplicated = try PropertyListEncoder().encode(Plain(switcherList: [a, b, a]))
        struct Wrapper: Codable { var switcherList: SwitcherList }
        #expect(try PropertyListDecoder().decode(Wrapper.self, from: duplicated).switcherList.apps == [a, b])
    }
}

private extension Settings {
    mutating func append(_ apps: AssignedApp...) { for app in apps { switcherList.append(app) } }
}

@MainActor @Suite struct LocateTests {
    @Test func registeredCopiesAreConsultedOnlyWhenTheLastKnownLocationMisses() {
        let world = World(apps: ["Figma"])
        let calls = Mutex(0)
        let registry = world.registry
        let catalog = AppCatalog(
            roots: [world.applications], extras: [],
            registeredCopies: { calls.withLock { $0 += 1 }; return registry[$0] },
            lastOpened: { _ in nil }, displayName: World.displayName)
        let figma = AssignedApp(world.app("Figma"))

        #expect(catalog.locate(figma) == world.app("Figma"))
        #expect(calls.withLock { $0 } == 0)

        let trashed = world.trash("Figma")
        let live = world.install("Figma", in: world.userApplications)
        registry[World.bundleID("Figma")] = [live]
        #expect(catalog.locate(figma)?.url == live)
        #expect(calls.withLock { $0 } == 1)

        registry[World.bundleID("Figma")] = [trashed]
        #expect(catalog.locate(figma) == nil)
        #expect(calls.withLock { $0 } == 2)
    }
}
