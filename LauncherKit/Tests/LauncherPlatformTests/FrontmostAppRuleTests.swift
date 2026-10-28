import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct FrontmostAppRuleTests {
    private static let own: pid_t = 100

    private static func entry(_ name: String) -> AppEntry {
        AppEntry(bundleID: BundleID(rawValue: "com.test.\(name)"), name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))
    }

    private static let safari = entry("Safari")
    private static let mail = entry("Mail")
    private static let menuBarApp = entry("MenuBarApp")

    @Test func thisProcessActiveHoldsTheFirstCommandTabApp() {
        let frontmost = RunningAppsReader.frontmost(
            activePID: Self.own, activeEntry: Self.entry("TrackpadLauncher"), ownPID: Self.own,
            apps: [Self.safari, Self.mail])
        #expect(frontmost == Self.safari)
    }

    @Test func thisProcessActiveWithNoAppsHoldsNone() {
        let frontmost = RunningAppsReader.frontmost(
            activePID: Self.own, activeEntry: nil, ownPID: Self.own, apps: [])
        #expect(frontmost == nil)
    }

    @Test func anotherProcessActiveHoldsItsOwnEntryEvenOffTheCommandTabList() {
        let frontmost = RunningAppsReader.frontmost(
            activePID: 200, activeEntry: Self.menuBarApp, ownPID: Self.own, apps: [Self.safari, Self.mail])
        #expect(frontmost == Self.menuBarApp)
    }

    @Test func noActiveAppHoldsNone() {
        let frontmost = RunningAppsReader.frontmost(
            activePID: nil, activeEntry: nil, ownPID: Self.own, apps: [Self.safari])
        #expect(frontmost == nil)
    }
}
