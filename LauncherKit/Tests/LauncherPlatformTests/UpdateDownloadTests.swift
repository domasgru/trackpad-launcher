import Foundation
import Testing

@testable import LauncherPlatform

@Suite struct UpdateDownloadTests {
    private static let identifier = "com.example.TrackpadLauncherFixture"

    /// A caches folder holding downloads in Sparkle's layout.
    private final class Caches {
        let root = FileManager.default.temporaryDirectory.appending(path: "tl-caches-\(UUID().uuidString)")
        init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        deinit { try? FileManager.default.removeItem(at: root) }

        /// `<random>/<folder>/<file>`, the random folder dated `age` seconds ago.
        @discardableResult
        func download(
            file: String = "TrackpadLauncher-fixture.aar", folder: String = "Trackpad App 2",
            age: TimeInterval = 0, contents: Data = Data("archive".utf8)
        ) throws -> URL {
            let random = root.appending(
                path:
                    "\(UpdateDownloadTests.identifier)/org.sparkle-project.Sparkle/PersistentDownloads/\(UUID().uuidString.prefix(8))"
            )
            let inside = random.appending(path: folder)
            try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
            let archive = inside.appending(path: file)
            try contents.write(to: archive)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: random.path)
            return archive
        }

        func found(build: String) -> URL? {
            SparkleInternals.persistentDownload(identifier: UpdateDownloadTests.identifier, build: build, caches: root)
        }
    }

    @Test func noFolderMeansNoDownload() throws {
        #expect(try Caches().found(build: "2") == nil)
    }

    @Test func oneArchiveOfTheBuildIsFoundAndAnotherBuildIsNot() throws {
        let caches = try Caches()
        let archive = try caches.download()

        #expect(caches.found(build: "2")?.standardizedFileURL == archive.standardizedFileURL)
        #expect(caches.found(build: "3") == nil)
        #expect(caches.found(build: "12") == nil)
    }

    @Test func theNewestOfTwoDownloadsOfTheSameBuildWins() throws {
        let caches = try Caches()
        try caches.download(age: 3600)
        let newest = try caches.download()

        #expect(caches.found(build: "2")?.standardizedFileURL == newest.standardizedFileURL)
    }

    @Test func aFolderHoldingAnythingButOneFileIsNone() throws {
        let caches = try Caches()
        let archive = try caches.download()
        try Data("second".utf8).write(to: archive.deletingLastPathComponent().appending(path: "other.aar"))

        #expect(caches.found(build: "2") == nil)
    }

    @Test(arguments: ["Update.dmg", "Update.zip", "Update"])
    func aFileNamedForAnotherKindOfArchiveIsNone(file: String) throws {
        let caches = try Caches()
        try caches.download(file: file)

        #expect(caches.found(build: "2") == nil)
    }

    @Test(arguments: ["two files", "no folder for the build"])
    func aLayoutTheLookupCannotResolveEndsWithTheDownloadsGone(layout: String) throws {
        let caches = try Caches()
        let archive: URL
        if layout == "two files" {
            archive = try caches.download()
            try Data("second".utf8).write(to: archive.deletingLastPathComponent().appending(path: "other.aar"))
        } else {
            archive = try caches.download(folder: "Trackpad App 3")
        }
        #expect(caches.found(build: "2") == nil)

        let folder = SparkleInternals.persistentDownloads(identifier: Self.identifier, caches: caches.root)
        UpdateArchive.discard(downloads: folder)

        #expect(!FileManager.default.fileExists(atPath: archive.path))
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func aFolderNamedForAnotherBuildIsNone() throws {
        let caches = try Caches()
        try caches.download(folder: "Trackpad App 3")

        #expect(caches.found(build: "2") == nil)
    }

    // MARK: the archive

    private static let missingFixtures = "run Scripts/make-update-fixtures.sh to generate the fixtures"

    private static func offer(_ record: UpdateFixtures.Record, build: String = "1") -> ExpectedUpdate {
        ExpectedUpdate(version: record.version, build: build, minimumMacOS: record.minimumMacOS)
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, Comment(rawValue: missingFixtures)))
    func theFixtureArchiveExpandsToOneBundleInAScratchFolderThatIsGoneAfterwards() throws {
        var scratch: URL?

        let listing = UpdateArchive.withExpandedBundle(of: UpdateFixtures.archive) { bundle -> [String] in
            scratch = bundle.deletingLastPathComponent()
            return (try? FileManager.default.contentsOfDirectory(atPath: scratch!.path)) ?? []
        }

        #expect(listing == ["TrackpadLauncher.app"])
        let folder = try #require(scratch)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, Comment(rawValue: missingFixtures)))
    func theExpandedFixtureIsGenuineOnlyForTheOfferItWasMadeFor() throws {
        let record = try UpdateFixtures.loadRecord()
        let signer = Signer(team: record.team, identifier: record.identifier)
        let offered = Self.offer(record)

        func verdict(_ expected: ExpectedUpdate, _ signer: Signer) -> Bool? {
            UpdateArchive.withExpandedBundle(of: UpdateFixtures.archive) {
                CodeSignature.isGenuine($0, as: expected, signer: signer)
            }
        }

        #expect(verdict(offered, signer) == true)
        #expect(verdict(ExpectedUpdate(version: "9.9.9", build: "1", minimumMacOS: record.minimumMacOS), signer) == false)
        #expect(verdict(Self.offer(record, build: "2"), signer) == false)
        #expect(verdict(ExpectedUpdate(version: record.version, build: "1", minimumMacOS: "99.0"), signer) == false)
        #expect(verdict(offered, Signer(team: "AAAAAAAAAA", identifier: record.identifier)) == false)
        #expect(verdict(offered, Signer(team: record.team, identifier: "com.example.other")) == false)
        #expect(
            CodeSignature.isGenuine(UpdateFixtures.appleDevelopmentApp, as: offered, signer: signer) == false)
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, Comment(rawValue: missingFixtures)))
    func aRefusedArchiveIsRemovedFromTheDownloadLayoutAndAGenuineOneIsLeft() throws {
        let record = try UpdateFixtures.loadRecord()
        let signer = Signer(team: record.team, identifier: record.identifier)
        let genuine = Self.offer(record)
        let caches = try Caches()
        let bytes = try Data(contentsOf: UpdateFixtures.archive)
        let kept = try caches.download(folder: "Trackpad App 1", contents: bytes)
        let refused = try caches.download(folder: "Trackpad App 9", contents: bytes)

        #expect(UpdateArchive.admit(kept, as: genuine, signer: signer))
        #expect(FileManager.default.fileExists(atPath: kept.path))

        let wrongVersion = ExpectedUpdate(version: "9.9.9", build: "1", minimumMacOS: record.minimumMacOS)
        #expect(!UpdateArchive.admit(refused, as: wrongVersion, signer: signer))
        #expect(!FileManager.default.fileExists(atPath: refused.path))
        #expect(FileManager.default.fileExists(atPath: kept.path))
    }

    @Test func anArchiveThatIsNotOneIsRefusedAndRemoved() throws {
        let caches = try Caches()
        let junk = try caches.download(contents: Data("not an archive".utf8))

        let admitted = UpdateArchive.admit(
            junk, as: ExpectedUpdate(version: "1", build: "2", minimumMacOS: "26.0"),
            signer: Signer(team: "ABCDE12345", identifier: Self.identifier))

        #expect(!admitted)
        #expect(!FileManager.default.fileExists(atPath: junk.path))
    }

    @Test(arguments: [
        (path: "TrackpadLauncher.app", kind: UpdateArchive.EntryKind.directory, link: String?.none, admitted: true),
        (path: "TrackpadLauncher.app/Contents/Info.plist", kind: .file, link: nil, admitted: true),
        (path: "Other.app/Contents/Info.plist", kind: .file, link: nil, admitted: false),
        (path: "/TrackpadLauncher.app/x", kind: .file, link: nil, admitted: false),
        (path: "TrackpadLauncher.app/../x", kind: .file, link: nil, admitted: false),
        (path: "TrackpadLauncher.app/Contents/x", kind: .other, link: nil, admitted: false),
        (path: "TrackpadLauncher.app/Contents/Frameworks/A", kind: .symbolicLink, link: "Versions/B/A", admitted: true),
        (path: "TrackpadLauncher.app/Contents/Frameworks/A", kind: .symbolicLink, link: "/etc/passwd", admitted: false),
        (path: "TrackpadLauncher.app/Contents/Frameworks/A", kind: .symbolicLink, link: "../../..", admitted: false),
        (path: "TrackpadLauncher.app/Contents/Frameworks/A", kind: .symbolicLink, link: "../../../../x", admitted: false),
    ])
    func onlyTheBundleItsFilesAndLinksStayingInsideItAreAdmitted(
        row: (path: String, kind: UpdateArchive.EntryKind, link: String?, admitted: Bool)
    ) {
        #expect(UpdateArchive.admits(path: row.path, kind: row.kind, linkTarget: row.link) == row.admitted)
    }
}
