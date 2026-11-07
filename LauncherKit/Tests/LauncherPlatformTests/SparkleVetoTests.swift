import Foundation
import Testing

@testable import LauncherPlatform

@Suite struct SparkleVetoTests {
    private static let identifier = "com.example.TrackpadLauncherFixture"

    private final class Caches {
        let root = FileManager.default.temporaryDirectory.appending(path: "tl-caches-\(UUID().uuidString)")
        init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        deinit { try? FileManager.default.removeItem(at: root) }

        /// A bundle in Sparkle's layout, its folder dated `age` seconds ago.
        @discardableResult
        func extract(
            build: String, name: String = "TrackpadLauncher.app", into inner: String = UUID().uuidString,
            age: TimeInterval = 0
        ) throws -> URL {
            let folder = root.appending(
                path: "\(SparkleVetoTests.identifier)/org.sparkle-project.Sparkle/Installation/outer/\(inner)")
            let contents = folder.appending(path: "\(name)/Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let info: [String: Any] = ["CFBundleIdentifier": SparkleVetoTests.identifier, "CFBundleVersion": build]
            try (info as NSDictionary).write(to: contents.appending(path: "Info.plist"))
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: folder.path)
            return folder.appending(path: name)
        }

        func found(build: String) -> URL? {
            SparkleInternals.extractedUpdate(identifier: SparkleVetoTests.identifier, build: build, caches: root)
        }
    }

    @Test func noFolderMeansNoBundle() throws {
        let caches = try Caches()

        #expect(caches.found(build: "2") == nil)
    }

    @Test func oneBundleOfTheBuildIsFoundAndAnotherBuildIsNot() throws {
        let caches = try Caches()
        let app = try caches.extract(build: "2")

        #expect(caches.found(build: "2")?.standardizedFileURL == app.standardizedFileURL)
        #expect(caches.found(build: "3") == nil)
    }

    @Test func aStaleOlderFolderOfTheSameBuildLosesToTheNewest() throws {
        let caches = try Caches()
        try caches.extract(build: "2", age: 3600)
        let newest = try caches.extract(build: "2")

        #expect(caches.found(build: "2")?.standardizedFileURL == newest.standardizedFileURL)
    }

    @Test func twoBundlesInTheNewestFolderAreNone() throws {
        let caches = try Caches()
        try caches.extract(build: "2", age: 3600)
        try caches.extract(build: "2", name: "One.app", into: "same")
        try caches.extract(build: "2", name: "Two.app", into: "same")

        #expect(caches.found(build: "2") == nil)
    }

    @Test func theInstallerJobIsNamedAfterTheIdentifier() {
        #expect(SparkleInternals.installerJob(of: "com.example.App") == "com.example.App-sparkle-updater")
    }

    private static func isLoaded(_ label: String) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = ["list", label]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard let exited = try? process.start() else { return false }
        exited()
        return process.terminationStatus == 0
    }

    private static func submitSleeper(label: String) -> Bool {
        LaunchdJob.submit(label: label, arguments: ["/bin/sleep", "300"]) && isLoaded(label)
    }

    @Test func vetoRemovesTheInstallerJobAndTheExtractedBundle() throws {
        let identifier = "com.example.vetotest\(UUID().uuidString.prefix(8))"
        let label = SparkleInternals.installerJob(of: identifier)
        defer { LaunchdJob.remove(label: label) }
        let caches = try Caches()
        let app = try caches.extract(build: "2")
        try #require(Self.submitSleeper(label: label), "the dummy job is running")

        SparkleInternals.veto(job: label, extracted: app)

        #expect(!Self.isLoaded(label))
        #expect(!FileManager.default.fileExists(atPath: app.path))
    }

    @Test func theBundleStillGoesWhenTheJobIsAbsent() throws {
        let label = SparkleInternals.installerJob(of: "com.example.vetotest\(UUID().uuidString.prefix(8))")
        let caches = try Caches()
        let app = try caches.extract(build: "2")
        try #require(!Self.isLoaded(label))

        SparkleInternals.veto(job: label, extracted: app)

        #expect(!FileManager.default.fileExists(atPath: app.path))
    }

    @Test func theJobStillGoesWhenThereIsNoBundle() throws {
        let label = SparkleInternals.installerJob(of: "com.example.vetotest\(UUID().uuidString.prefix(8))")
        defer { LaunchdJob.remove(label: label) }
        try #require(Self.submitSleeper(label: label), "the dummy job is running")

        SparkleInternals.veto(job: label, extracted: nil)

        #expect(!Self.isLoaded(label))
    }
}
