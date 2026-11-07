import Foundation
import Testing

@testable import LauncherPlatform

/// Real launchd, a real `sleep` standing in for the old process and a stub `open`. The timing rows run one at a time:
/// a loaded machine would otherwise blur the bounds they measure.
@Suite(.serialized) struct LaunchdJobTests {
    private static func launchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard let exited = try? process.start() else { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        exited()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func isLoaded(_ label: String) -> Bool { launchctl(["list", label]).status == 0 }

    private static func uniqueLabel() -> String { "com.example.handovertest\(UUID().uuidString.prefix(8))" }

    /// A bundle at build 1, a stub `open` that records its arguments, and an old process that lives until `killOld`.
    private final class Rig {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tl-handover-\(UUID().uuidString)")
        var bundle: URL { folder.appending(path: "Trackpad Launcher.app") }
        var plist: URL { bundle.appending(path: "Contents/Info.plist") }
        var stub: URL { folder.appending(path: "open-stub") }
        var calls: URL { folder.appending(path: "calls") }
        let old = Process()
        private var oldExited: (@Sendable () -> Void)?
        let label = LaunchdJobTests.uniqueLabel()

        init() throws {
            try FileManager.default.createDirectory(
                at: bundle.appending(path: "Contents"), withIntermediateDirectories: true)
            try writeBuild("1")
            try """
                #!/bin/sh
                echo "$@" >> "\(calls.path)"
                """.write(to: stub, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)
            old.executableURL = URL(filePath: "/bin/sleep")
            old.arguments = ["300"]
            oldExited = try old.start()
        }

        deinit {
            LaunchdJob.remove(label: label)
            if old.isRunning { old.terminate() }
            try? FileManager.default.removeItem(at: folder)
        }

        func writeBuild(_ build: String) throws {
            let info: [String: Any] = ["CFBundleIdentifier": "com.example.fixture", "CFBundleVersion": build]
            try (info as NSDictionary).write(to: plist)
        }

        func submit(allowed: Int, withWindow: Bool = false) -> Bool {
            LaunchdJob.submit(
                label: label,
                arguments: LaunchdJob.handOverArguments(
                    oldPID: old.processIdentifier, bundle: bundle, build: "1", allowed: allowed, open: stub.path,
                    withWindow: withWindow))
        }

        func killOld() {
            old.terminate()
            oldExited?()
        }

        var openCalls: [String] {
            ((try? String(contentsOf: calls, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        }

        /// How long after `since` the stub first ran; nil when it has not within `limit`.
        func opened(since: ContinuousClock.Instant, within limit: Duration) async -> Duration? {
            let clock = ContinuousClock()
            while clock.now - since < limit {
                if !openCalls.isEmpty { return clock.now - since }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return nil
        }
    }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    @Test func theStubIsNotCalledWhileTheOldProcessLivesEvenPastTheBudget() async throws {
        let rig = try Rig()
        try #require(rig.submit(allowed: 1))
        try await Task.sleep(for: .milliseconds(2500))
        #expect(rig.openCalls.isEmpty)

        rig.killOld()
        try await Task.sleep(for: .milliseconds(500))
        try rig.writeBuild("2")
        let rewritten = ContinuousClock.now

        let delay = try #require(await rig.opened(since: rewritten, within: .seconds(3)))
        #expect(seconds(delay) < 1)
        try await Task.sleep(for: .milliseconds(500))
        #expect(rig.openCalls == ["-g -a \(rig.bundle.path) --args --after-update"])
        #expect(!Self.isLoaded(rig.label))
    }

    @Test(arguments: [false, true])
    func theStubIsOpenedOnceWithOrWithoutBackgroundAndTheWindowFlagAsTheJobWasArmed(withWindow: Bool) async throws {
        let rig = try Rig()
        try #require(rig.submit(allowed: 1, withWindow: withWindow))

        rig.killOld()
        try rig.writeBuild("2")
        let died = ContinuousClock.now

        _ = try #require(await rig.opened(since: died, within: .seconds(5)))
        try await Task.sleep(for: .milliseconds(500))
        let expected =
            withWindow
            ? "-a \(rig.bundle.path) --args --after-update --with-window"
            : "-g -a \(rig.bundle.path) --args --after-update"
        #expect(rig.openCalls == [expected])
    }

    @Test func aBuildThatNeverChangesOpensWhateverIsThereFiveToSixSecondsAfterTheDeath() async throws {
        let rig = try Rig()
        try #require(rig.submit(allowed: 5))

        rig.killOld()
        let died = ContinuousClock.now
        let delay = try #require(await rig.opened(since: died, within: .seconds(10)))

        #expect(seconds(delay) >= 5)
        #expect(seconds(delay) <= 6.5)
        try await Task.sleep(for: .milliseconds(500))
        #expect(rig.openCalls.count == 1)
    }

    @Test func aBundleMissingAtTheDeathIsWaitedForAndOpenedOnceItReturnsAtANewBuild() async throws {
        let rig = try Rig()
        try #require(rig.submit(allowed: 1))
        try FileManager.default.removeItem(at: rig.plist)

        rig.killOld()
        try await Task.sleep(for: .milliseconds(500))
        #expect(rig.openCalls.isEmpty)
        try rig.writeBuild("2")
        let returned = ContinuousClock.now

        let delay = try #require(await rig.opened(since: returned, within: .seconds(3)))
        #expect(seconds(delay) < 1)
        try await Task.sleep(for: .milliseconds(500))
        #expect(rig.openCalls.count == 1)
    }

    @Test func submittingAStaleLabelReplacesTheJob() throws {
        let label = Self.uniqueLabel()
        defer { LaunchdJob.remove(label: label) }

        try #require(LaunchdJob.submit(label: label, arguments: ["/bin/sleep", "300"]))
        try #require(LaunchdJob.submit(label: label, arguments: ["/bin/sleep", "301"]))

        let listing = Self.launchctl(["list", label])
        #expect(listing.status == 0)
        #expect(listing.output.contains("301"))
        #expect(!listing.output.contains("\"300\""))
    }

    @Test func removingALiveJobEndsItAndRemovingAnAbsentOneAnswersFalse() throws {
        let label = Self.uniqueLabel()
        try #require(LaunchdJob.submit(label: label, arguments: ["/bin/sleep", "300"]))
        try #require(Self.isLoaded(label))

        #expect(LaunchdJob.remove(label: label))
        #expect(!Self.isLoaded(label))
        #expect(!LaunchdJob.remove(label: Self.uniqueLabel()))
    }
}
