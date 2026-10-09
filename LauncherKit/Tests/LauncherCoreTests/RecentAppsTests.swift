import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct RecentAppsTests {
    /// The menu as plain text: checked apps carry "✓ ", dividers are "—".
    private func menu(_ launcher: Launcher, checking app: RowApp) -> [String] {
        launcher.installedApps.pickerMenu(checking: app).map {
            switch $0 {
            case .app(let entry, let checked): (checked ? "✓ " : "") + entry.name
            case .divider: "—"
            case .other: "Other…"
            case .unassigned: "None"
            }
        }
    }

    private func names(_ apps: [AppEntry]) -> [String] { apps.map(\.name) }

    @Test func mostRecentlyLaunchedComeFirstAndAreNotRepeated() {
        let world = World(apps: ["Figma", "Slack", "Arc", "Notion", "Zed"])
        world.recordLaunch("Figma")
        world.recordLaunch("Slack")
        world.recordLaunch("Arc")

        world.launcher.start()

        #expect(names(world.launcher.installedApps.recent) == ["Arc", "Slack", "Figma"])
        #expect(names(world.launcher.installedApps.others) == ["Finder", "Notion", "Zed"])
    }

    @Test func onlyTheTenMostRecentCountHoweverOldTheLaunches() {
        let world = World(apps: (1...15).map { "App \(String(format: "%02d", $0))" })
        for number in [8, 3, 12, 1, 15, 6, 10, 2, 14, 5, 9, 13, 4, 11, 7] {
            world.recordLaunch("App \(String(format: "%02d", number))")
        }

        world.launcher.start()

        #expect(
            names(world.launcher.installedApps.recent)
                == ["App 07", "App 11", "App 04", "App 13", "App 09", "App 05", "App 14", "App 02", "App 10", "App 06"])
        #expect(
            names(world.launcher.installedApps.others)
                == ["App 01", "App 03", "App 08", "App 12", "App 15", "Finder"])
    }

    @Test func finderCountsLikeAnyOtherListedApp() {
        let world = World(apps: ["Arc", "Notion", "Slack", "Zed"])
        world.recordLaunch("Notion")
        world.recordLaunch("Finder", in: world.coreServices)
        world.recordLaunch("Arc")

        world.launcher.start()

        #expect(names(world.launcher.installedApps.recent) == ["Arc", "Finder", "Notion"])
        #expect(names(world.launcher.installedApps.others) == ["Slack", "Zed"])
    }

    @Test func anAppOutsideTheListedFoldersIsNeverListedNorRecent() {
        let world = World(apps: ["Arc"])
        world.install("Sketch", in: world.downloads)
        world.launcher.start()
        world.launcher.setAssignment(.appBundle(at: world.downloads.appending(path: "Sketch.app")), for: .one)
        world.recordLaunch("Arc")
        world.recordLaunch("Sketch", in: world.downloads)

        world.launcher.openWindow()

        let installed = world.launcher.installedApps
        #expect(names(installed.recent) == ["Arc"])
        #expect(!installed.all.map(\.name).contains("Sketch"))
        #expect(world.launcher.app(for: .one) == .present(world.app("Sketch", in: world.downloads)))
        let row = world.launcher.app(for: .one)!
        #expect(!menu(world.launcher, checking: row).contains { $0.hasPrefix("✓ ") })
    }

    @Test func everyPickerSharesOneRecentSectionAndChecksItsOwnApp() {
        let world = World(apps: ["Arc", "Figma", "Zed"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.launcher.setAssignment(.app(world.app("Zed")), for: .four)
        world.recordLaunch("Figma")
        world.recordLaunch("Arc")

        world.launcher.openWindow()

        #expect(
            menu(world.launcher, checking: world.launcher.app(for: .two)!)
                == ["Arc", "✓ Figma", "—", "Finder", "Zed", "—", "Other…", "None"])
        #expect(
            menu(world.launcher, checking: world.launcher.app(for: .four)!)
                == ["Arc", "Figma", "—", "Finder", "✓ Zed", "—", "Other…", "None"])
    }

    @Test func withoutLaunchDataThereIsNoRecentSectionAndNoExtraDivider() {
        let world = World(apps: ["Arc", "Zed"])

        world.launcher.start()

        #expect(world.launcher.installedApps.recent.isEmpty)
        #expect(menu(world.launcher, checking: .unassigned) == ["Arc", "Finder", "Zed", "—", "Other…", "None"])
    }

    @Test func openingTheWindowRefreshesTheRecentApps() {
        let world = World(apps: ["Arc", "Notion"])
        world.recordLaunch("Arc")
        world.launcher.start()
        world.launcher.closeWindow()
        #expect(!world.launcher.isWindowOpen)
        #expect(names(world.launcher.installedApps.recent) == ["Arc"])

        world.recordLaunch("Notion")
        world.launcher.openWindow()
        #expect(names(world.launcher.installedApps.recent) == ["Notion", "Arc"])

        world.launcher.closeWindow()
        world.recordLaunch("Arc")
        world.launcher.openWindow()
        #expect(names(world.launcher.installedApps.recent) == ["Arc", "Notion"])
    }

    @Test func theLastKnownListStaysUntilANewScanArrives() {
        let world = World(apps: ["Arc", "Figma"])
        world.recordLaunch("Figma")
        world.launcher.start()
        #expect(names(world.launcher.installedApps.recent) == ["Figma"])

        world.scanner.holdScans()
        world.recordLaunch("Arc")
        world.launcher.openWindow()
        #expect(names(world.launcher.installedApps.recent) == ["Figma"])

        world.scanner.deliverHeldScan()
        #expect(names(world.launcher.installedApps.recent) == ["Arc", "Figma"])
    }

    @Test func installsAndRemovalsShowUpWhileTheWindowIsClosed() {
        let world = World(apps: ["Figma", "Zed"])
        world.recordLaunch("Figma")
        world.launcher.start()
        world.launcher.closeWindow()
        #expect(!world.launcher.isWindowOpen)

        world.install("Slack")
        world.scanner.foldersChanged()
        #expect(names(world.launcher.installedApps.others) == ["Finder", "Slack", "Zed"])

        world.trash("Figma")
        world.scanner.foldersChanged()
        let installed = world.launcher.installedApps
        #expect(installed.recent.isEmpty)
        #expect(!installed.all.map(\.name).contains("Figma"))
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func onlyStartAndOpeningTheWindowRequestAScan() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        #expect(world.scanner.scanRequests == 1)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setHandMode(.left)
        world.launcher.setHandMode(.right)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)
        world.hardware.attach(.magicTrackpad)
        world.hardware.detach(Trackpad.magicTrackpad.id)
        world.hardware.wake()
        world.access.set(granted: true)
        world.tap(1)
        world.launcher.closeWindow()
        world.launcher.dismissWindow()
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.scanner.scanRequests == 1)

        world.launcher.openWindow()
        #expect(world.scanner.scanRequests == 2)
    }
}
