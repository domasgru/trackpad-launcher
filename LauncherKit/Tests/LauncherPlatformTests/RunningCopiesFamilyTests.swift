import AppKit
import Testing

@testable import LauncherPlatform

/// A Debug and a release copy count each other as running copies of the one app.
@MainActor @Suite struct RunningCopiesFamilyTests {
    nonisolated private static let finderRuns =
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").isEmpty

    private static let both: Set<String> = ["com.domasgru.TrackpadLauncherApp", "com.domasgru.TrackpadLauncherApp.debug"]

    @Test func theReleaseIdentifierNamesBothBuilds() {
        #expect(SystemRunningCopies.family(of: "com.domasgru.TrackpadLauncherApp") == Self.both)
    }

    @Test func theDebugIdentifierNamesTheSameTwoBuilds() {
        #expect(SystemRunningCopies.family(of: "com.domasgru.TrackpadLauncherApp.debug") == Self.both)
    }

    @Test(.enabled(if: finderRuns, "Finder is not running"))
    func eitherBuildListsEveryRunningCopyOfTheFamily() {
        let finder = Set(
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                .map(\.processIdentifier))
        for identifier in ["com.apple.finder.debug", "com.apple.finder"] {
            let listed = SystemRunningCopies(bundleIdentifier: identifier).others().map(\.id.rawValue)
            #expect(Set(listed) == finder, "as \(identifier)")
            #expect(listed.count == finder.count, "as \(identifier)")
        }
    }
}
