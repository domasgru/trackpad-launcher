import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The reader's LaunchServices path against the workspace's own list of running apps.
@MainActor @Suite struct RunningAppsReaderTests {
    nonisolated private static let orderResolves = LaunchServicesOrder() != nil

    private struct Identity: Hashable {
        let bundleID: String
        let location: String
    }

    /// The Dock's apps as the workspace lists them: regular activation policy, not this process.
    private static func dockApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && $0.bundleIdentifier != nil && $0.bundleURL != nil
        }
    }

    private static func identity(_ app: NSRunningApplication) -> Identity {
        Identity(bundleID: app.bundleIdentifier!, location: app.bundleURL!.standardizedFileURL.path)
    }

    private static func identity(_ entry: AppEntry) -> Identity {
        Identity(bundleID: entry.bundleID.rawValue, location: entry.url.standardizedFileURL.path)
    }

    @Test(.enabled(if: orderResolves, "The private LaunchServices order does not resolve on this Mac"))
    func theOrderHoldsEveryDockAppNamedAsMacOSNamesItWithTheActiveAppFirst() throws {
        let reader = RunningAppsReader()
        let before = Self.dockApps()
        let read = reader.read()
        let after = Self.dockApps()
        guard Set(before.map(Self.identity)) == Set(after.map(Self.identity)) else { return }

        #expect(Set(read.apps.map(Self.identity)) == Set(before.map(Self.identity)))
        #expect(read.apps.count == before.count)
        for app in before {
            let entry = try #require(read.apps.first { Self.identity($0) == Self.identity(app) })
            #expect(entry.name == app.localizedName)
        }
        if let active = NSWorkspace.shared.frontmostApplication, active.activationPolicy == .regular,
            active.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            #expect(read.frontmost.map(Self.identity) == Self.identity(active))
            #expect(read.apps.first.map(Self.identity) == Self.identity(active))
        }
    }

    @Test func withoutTheOrderTheListIsEmptyButTheActiveAppIsStillRead() {
        let read = RunningAppsReader(order: nil).read()
        #expect(read.apps.isEmpty)
        if let active = NSWorkspace.shared.frontmostApplication, active.bundleURL != nil,
            active.bundleIdentifier != nil, active.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            #expect(read.frontmost.map(Self.identity) == Self.identity(active))
        }
    }
}
