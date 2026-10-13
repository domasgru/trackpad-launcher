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
        #expect(!reader.isTrackingActivations)
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

    @Test func withoutTheOrderTheActiveAppIsStillRead() {
        let read = RunningAppsReader(order: nil).read()
        if let active = NSWorkspace.shared.frontmostApplication, active.bundleURL != nil,
            active.bundleIdentifier != nil, active.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            #expect(read.frontmost.map(Self.identity) == Self.identity(active))
        }
    }

    @Test func theFallbackOrderPutsRecentlyActivatedAppsFirstThenLaunchOrderWithUndatedLast() {
        let t0 = Date(timeIntervalSince1970: 0)
        let running: [(pid: Int32, launched: Date?)] = [
            (1, t0 + 1), (2, t0 + 3), (3, t0 + 2), (4, t0), (5, nil),
        ]
        #expect(FallbackOrder.pids(running: running, recency: [3, 1]) == [3, 1, 4, 2, 5])
        #expect(FallbackOrder.pids(running: running, recency: [99, 3]) == [3, 4, 1, 2, 5])
        #expect(FallbackOrder.pids(running: running, recency: [3]) == [3, 4, 1, 2, 5])
        #expect(FallbackOrder.pids(running: running, recency: []) == [4, 1, 3, 2, 5])
    }

    @Test func withoutTheOrderTheSeedAndThenEachActivationComeFirst() throws {
        guard Self.dockApps().count >= 3 else { return }
        let reader = RunningAppsReader(order: nil)
        #expect(reader.isTrackingActivations)
        let first = reader.read()
        #expect(Set(first.apps.map(Self.identity)) == Set(Self.dockApps().map(Self.identity)))
        if let active = NSWorkspace.shared.frontmostApplication, active.activationPolicy == .regular,
            active.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            #expect(first.apps.first.map(Self.identity) == Self.identity(active))
        }

        let lastEntry = try #require(first.apps.last)
        try activate(lastEntry)
        let second = reader.read().apps.map(Self.identity)
        #expect(second.first == Self.identity(lastEntry))
        #expect(Array(second.dropFirst()) == first.apps.dropLast().map(Self.identity))

        let nowLast = try #require(reader.read().apps.last)
        try activate(nowLast)
        let third = reader.read().apps.map(Self.identity)
        #expect(third.prefix(2) == [Self.identity(nowLast), Self.identity(lastEntry)])
    }

    private func activate(_ entry: AppEntry) throws {
        let app = try #require(Self.dockApps().first { Self.identity($0) == Self.identity(entry) })
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }
}
