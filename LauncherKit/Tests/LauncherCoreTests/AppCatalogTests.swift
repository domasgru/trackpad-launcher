import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct AppCatalogTests {
    @Test func pickerListCoversFoldersSubfoldersAndFinderInFinderOrder() {
        let world = World(apps: ["Zed", "arc", "Figma"])
        let applications = world.applications
        let utilities = applications.appending(path: "Utilities")
        try! FileManager.default.createDirectory(at: utilities, withIntermediateDirectories: true)
        world.install("Terminal", in: utilities)
        try! Data().write(to: applications.appending(path: "Notes.txt"))
        let helpers = applications.appending(path: "Figma.app/Contents/Helpers")
        try! FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        world.install("Helper", in: helpers)
        let noID = world.install("NoID")
        try! PropertyListSerialization.data(fromPropertyList: ["CFBundleName": "NoID"], format: .xml, options: 0)
            .write(to: noID.appending(path: "Contents/Info.plist"))
        world.install(".Hidden")
        world.install("arc", in: world.systemApplications)
        world.install("App 10", in: world.userApplications)
        world.install("App 2", in: world.userApplications)

        let apps = world.catalog.installedApps().others

        #expect(apps.map(\.name) == ["App 2", "App 10", "arc", "Figma", "Finder", "Terminal", "Zed"])
        let arc = apps.first { $0.name == "arc" }?.url.resolvingSymlinksInPath().path
        #expect(arc?.hasPrefix(world.applications.resolvingSymlinksInPath().path) == true)
    }

    @Test func everyCallEnumeratesAfresh() {
        let world = World(apps: ["Zed"])
        #expect(!world.catalog.installedApps().others.map(\.name).contains("Slack"))

        world.install("Slack")
        #expect(world.catalog.installedApps().others.map(\.name).contains("Slack"))

        world.remove("Zed")
        #expect(!world.catalog.installedApps().others.map(\.name).contains("Zed"))
    }
}
