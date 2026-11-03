import AppKit
import Testing

@testable import LauncherPlatform

/// A Debug and a release copy count each other as running copies of the one app.
@MainActor @Suite struct RunningCopiesFamilyTests {
    nonisolated private static let finderRuns =
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").isEmpty

    @Test(arguments: ["com.domasgru.TrackpadLauncherApp", "com.domasgru.TrackpadLauncherApp.debug"])
    func eitherIdentifierNamesBothBuilds(identifier: String) {
        #expect(
            SystemRunningCopies.family(of: identifier)
                == ["com.domasgru.TrackpadLauncherApp", "com.domasgru.TrackpadLauncherApp.debug"])
    }

    @Test(
        .enabled(if: finderRuns, "Finder is not running"),
        arguments: ["com.apple.finder.debug", "com.apple.finder"])
    func eitherBuildListsEveryRunningCopyOfTheFamily(identifier: String) {
        let finder = Set(
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                .map(\.processIdentifier))
        let listed = SystemRunningCopies(bundleIdentifier: identifier).others().map(\.id.rawValue)
        #expect(Set(listed) == finder)
        #expect(listed.count == finder.count)
    }
}
