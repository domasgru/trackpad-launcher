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

    private static let trackpadLauncher = entry("TrackpadLauncher")

    private func frontmost(listed apps: [AppEntry], activeEntry: AppEntry? = trackpadLauncher) -> AppEntry? {
        RunningAppsReader.frontmost(activePID: Self.own, activeEntry: activeEntry, ownPID: Self.own, apps: apps)
    }

    @Test func thisProcessActiveAndListedIsTheFrontmostAppWhereverTheListHasIt() {
        let launcher = Self.trackpadLauncher
        #expect(frontmost(listed: [launcher, Self.safari, Self.mail]) == launcher)
        #expect(frontmost(listed: [Self.safari, launcher, Self.mail]) == launcher)
    }

    @Test func thisProcessActiveAndUnlistedStandsForTheFirstCommandTabApp() {
        #expect(frontmost(listed: [Self.safari, Self.mail]) == Self.safari)
    }

    @Test func thisProcessListedUnderAnotherSpellingIsTheListedEntry() {
        let listed = AppEntry(
            bundleID: Self.trackpadLauncher.bundleID, name: "TrackpadLauncher",
            url: URL(fileURLWithPath: "/Applications/./TrackpadLauncher.app/"))
        let spelled = AppEntry(
            bundleID: Self.trackpadLauncher.bundleID, name: "TrackpadLauncher",
            url: URL(fileURLWithPath: "/private/Applications/TrackpadLauncher.app"))
        #expect(frontmost(listed: [listed, Self.safari], activeEntry: spelled) == listed)
    }

    @Test func thisProcessActiveWithAnUnreadableEntryIsTheFirstListedAppEvenWhenThatIsTrackpadLauncher() {
        let launcher = Self.trackpadLauncher
        #expect(frontmost(listed: [launcher, Self.safari], activeEntry: nil) == launcher)
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
