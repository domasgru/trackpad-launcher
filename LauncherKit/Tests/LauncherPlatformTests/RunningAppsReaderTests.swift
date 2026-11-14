import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The reader's LaunchServices path against the workspace's own list of running apps.
@MainActor @Suite struct RunningAppsReaderTests {
    nonisolated private static let orderResolves = LaunchServicesOrder() != nil

    nonisolated private static var dockAppCount: Int {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
                && $0.bundleIdentifier != nil && $0.bundleURL != nil
        }.count
    }

    private struct Identity: Hashable {
        let bundleID: String
        let location: String
    }

    /// The Dock's apps as the workspace lists them: regular activation policy, not this process.
    private static func dockApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
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
    func theOrderHoldsEveryDockAppNamedAsMacOSNamesItWithTheActiveAppFirst() async throws {
        let reader = RunningAppsReader()
        #expect(!reader.isTrackingActivations)
        var before = Self.dockApps()
        var read = reader.read()
        var after = Self.dockApps()
        var active = Self.activeDockApp()
        // Another app launching, quitting or coming to the front reaches the reader first: NSWorkspace's list and its
        // frontmost app change only as the main run loop turns. So a difference gets a few turns of the loop to
        // settle; one that stays is the reader's.
        func settled() -> Bool {
            Set(read.apps.map(Self.identity)) == Set(before.map(Self.identity))
                && (active == nil || read.apps.first.map(Self.identity) == active.map(Self.identity))
        }
        for _ in 0..<20 where !settled() {
            try? await Task.sleep(for: .milliseconds(100))
            before = Self.dockApps()
            read = reader.read()
            after = Self.dockApps()
            active = Self.activeDockApp()
        }
        guard Set(before.map(Self.identity)) == Set(after.map(Self.identity)) else { return }

        #expect(Set(read.apps.map(Self.identity)) == Set(before.map(Self.identity)))
        #expect(read.apps.count == before.count)
        for app in before {
            let entry = try #require(read.apps.first { Self.identity($0) == Self.identity(app) })
            #expect(entry.name == app.localizedName)
        }
        if let active {
            #expect(read.frontmost.map(Self.identity) == Self.identity(active))
            #expect(read.apps.first.map(Self.identity) == Self.identity(active))
        }
    }

    /// The active app when it is a Dock app, as the workspace last saw it.
    private static func activeDockApp() -> NSRunningApplication? {
        guard let active = NSWorkspace.shared.frontmostApplication, active.activationPolicy == .regular,
            active.bundleIdentifier != nil, active.bundleURL != nil
        else { return nil }
        return active
    }

    @Test(arguments: [true, false])
    func theActiveAppIsSpelledLikeItsEntryInTheApps(withOrder: Bool) throws {
        guard !withOrder || Self.orderResolves else { return }
        let reader = RunningAppsReader(order: withOrder ? LaunchServicesOrder() : nil)
        let read = reader.read()
        guard let active = NSWorkspace.shared.frontmostApplication, active.activationPolicy == .regular,
            active.bundleIdentifier != nil, active.bundleURL != nil
        else { return }
        let frontmost = try #require(read.frontmost)
        let entry = try #require(read.apps.first { $0.bundleID == frontmost.bundleID })
        #expect(frontmost.url == entry.url)
        #expect(read.contains(frontmost.url))
    }

    @Test func withoutTheOrderTheActiveAppIsStillRead() {
        let read = RunningAppsReader(order: nil).read()
        if let active = NSWorkspace.shared.frontmostApplication, active.bundleURL != nil,
            active.bundleIdentifier != nil
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

    @Test(.enabled(if: dockAppCount >= 3, "Fewer than three Dock apps are running"))
    func withoutTheOrderTheSeedAndThenEachActivationComeFirst() throws {
        let activeBefore = Self.activeDockApp()
        let reader = RunningAppsReader(order: nil)
        #expect(reader.isTrackingActivations)
        let first = reader.read()
        #expect(Set(first.apps.map(Self.identity)) == Set(Self.dockApps().map(Self.identity)))
        // An app that came to the front meanwhile may not have reached the seed yet; only a steady one is checked.
        if let active = Self.activeDockApp(), active.processIdentifier == activeBefore?.processIdentifier {
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

    @Test(.enabled(if: dockAppCount >= 1, "No Dock app is running"))
    func theTrackerOrdersThisProcessAmongTheAppsItNotes() throws {
        let tracker = ActivationTracker()
        let other = try #require(Self.dockApps().first)
        for app in [NSRunningApplication.current, other] {
            NSWorkspace.shared.notificationCenter.post(
                name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
                userInfo: [NSWorkspace.applicationUserInfoKey: app])
        }
        #expect(
            tracker.recency.prefix(2) == [other.processIdentifier, NSRunningApplication.current.processIdentifier])
    }

    @Test func theParseKeepsEveryForegroundAppWithABundleThisProcessIncludedWhileItsIconShows() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tl-ls-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let own = ProcessInfo.processInfo.processIdentifier
        let ownBundle = folder.appending(path: "Own.app").path

        func answer(_ name: String, pid: Int32, type: String = "Foreground", path: String? = nil) -> [String: Any] {
            var answer: [String: Any] = [
                "pid": NSNumber(value: pid), "ApplicationType": type, "CFBundleIdentifier": "com.test.\(name)",
                "LSDisplayName": name,
            ]
            answer["LSBundlePath"] = path ?? "/Applications/\(name).app"
            return answer
        }
        var noPath = answer("Ghost", pid: 300)
        noPath["LSBundlePath"] = nil

        let whileShowing = LaunchServicesOrder.entries([
            answer("Safari", pid: 200), answer("Own", pid: own, path: ownBundle),
            answer("Menu", pid: 250, type: "UIElement"), answer("Mail", pid: 260), noPath,
        ])
        #expect(whileShowing.map(\.name) == ["Safari", "Own", "Mail"])
        #expect(whileShowing[1].url == AppEntry.location(ofBundleAtPath: ownBundle))

        let afterClosing = LaunchServicesOrder.entries([
            answer("Safari", pid: 200), answer("Own", pid: own, type: "UIElement", path: ownBundle),
            answer("Mail", pid: 260),
        ])
        #expect(afterClosing.map(\.name) == ["Safari", "Mail"])
    }

    private func activate(_ entry: AppEntry) throws {
        let app = try #require(Self.dockApps().first { Self.identity($0) == Self.identity(entry) })
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }
}
