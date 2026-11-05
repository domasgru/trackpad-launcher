import AppKit
import Testing

@testable import LauncherPlatform

/// The real `stop` against real processes LaunchServices launched: a release copy and a Debug copy of a fixture app,
/// under an identifier family that is this test's alone.
@MainActor @Suite(.timeLimit(.minutes(1))) struct SystemRunningCopiesStopTests {
    @MainActor private final class Exits {
        var count = 0
        var onMainThread = true
        func record() {
            count += 1
            onMainThread = onMainThread && Thread.isMainThread
        }
    }

    private static func isGone(_ pid: pid_t) -> Bool { kill(pid, 0) == -1 && errno == ESRCH }

    private static func waitUntil(_ limit: Duration, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + limit
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    private static func uniqueIdentifier() -> String {
        "\(BundleFixture.identifier).t\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    @Test func stoppingNothingExitsAtOnce() {
        let copies = SystemRunningCopies(bundleIdentifier: Self.uniqueIdentifier())
        let none = Exits()
        autoreleasepool { copies.stop([]) { none.record() } }
        #expect(none.count == 1)
    }

    @Test func stoppedCopiesExitAndTheNewCopySurvives() async throws {
        let fixture = try BundleFixture()
        let releaseIdentifier = Self.uniqueIdentifier()
        let release = try fixture.makeRunnableBundle(in: fixture.folder("release"), identifier: releaseIdentifier)
        let debug = try fixture.makeRunnableBundle(in: fixture.folder("debug"), identifier: releaseIdentifier + ".debug")
        let runningPids = { BundleFixture.pids(runningExecutableOf: release) + BundleFixture.pids(runningExecutableOf: debug) }
        defer {
            for pid in runningPids() { kill(pid, SIGKILL) }
        }
        try BundleFixture.launch(release)
        try BundleFixture.launch(debug)

        let copies = SystemRunningCopies(bundleIdentifier: releaseIdentifier)
        let bothListed = await Self.waitUntil(.seconds(15)) { copies.others().count == 2 }
        try #require(bothListed, "both fixture copies are listed")
        let listed = copies.others()
        let pids = Set(runningPids())
        #expect(pids.count == 2)
        #expect(Set(listed.map(\.id.rawValue)) == pids)

        let exits = Exits()
        let completed: Void? = await awaiting("the copies to exit") { done in
            autoreleasepool {
                copies.stop(listed) {
                    exits.record()
                    done(())
                }
            }
        }
        try #require(completed != nil)
        for pid in pids {
            #expect(await Self.waitUntil(.seconds(2)) { Self.isGone(pid) }, "pid \(pid) is gone")
        }
        #expect(exits.count == 1)
        #expect(exits.onMainThread)

        try #require(copies.others().isEmpty, "macOS lists the stopped copies as gone")
        let gone = Exits()
        autoreleasepool { copies.stop(listed) { gone.record() } }
        #expect(gone.count == 1)
    }
}
