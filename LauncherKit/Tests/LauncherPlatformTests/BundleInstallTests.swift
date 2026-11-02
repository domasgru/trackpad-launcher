import Foundation
import Testing

@testable import LauncherPlatform

@Suite struct BundleInstallTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let path: String
        let kind: ArchiveEntryKind
        let target: String?
        var testDescription: String { "\(path) \(kind) \(target ?? "")" }
    }

    @Test(arguments: [
        Row(path: "TrackpadLauncher.app", kind: .directory, target: nil),
        Row(path: "TrackpadLauncher.app/Contents/Info.plist", kind: .file, target: nil),
        Row(path: "TrackpadLauncher.app/Contents/Frameworks/X.framework/Versions/Current", kind: .symbolicLink, target: "A"),
        Row(path: "TrackpadLauncher.app/Contents/Frameworks/X.framework/X", kind: .symbolicLink, target: "Versions/Current/X"),
    ])
    func anEntryInsideTheBundleIsAdmitted(_ row: Row) {
        #expect(BundleInstall.admits(path: row.path, kind: row.kind, linkTarget: row.target))
    }

    @Test(arguments: [
        Row(path: "", kind: .directory, target: nil),
        Row(path: ".", kind: .directory, target: nil),
        Row(path: "Other.app", kind: .directory, target: nil),
        Row(path: "TrackpadLauncher.appx/a", kind: .file, target: nil),
        Row(path: "../x", kind: .file, target: nil),
        Row(path: "TrackpadLauncher.app/../x", kind: .file, target: nil),
        Row(path: "TrackpadLauncher.app/a/../../x", kind: .file, target: nil),
        Row(path: "/TrackpadLauncher.app/x", kind: .file, target: nil),
        Row(path: "TrackpadLauncher.app/l", kind: .symbolicLink, target: "/etc"),
        Row(path: "TrackpadLauncher.app/Contents/l", kind: .symbolicLink, target: "../../x"),
        Row(path: "TrackpadLauncher.app/Contents/l", kind: .symbolicLink, target: "../../TrackpadLauncher.app/x"),
        Row(path: "TrackpadLauncher.app/Contents/l", kind: .symbolicLink, target: nil),
        Row(path: "TrackpadLauncher.app/Contents/l", kind: .other, target: nil),
        Row(path: "TrackpadLauncher.app/Contents/l", kind: .other, target: "x"),
    ])
    func anEntryThatCouldEscapeTheBundleIsRefused(_ row: Row) {
        #expect(!BundleInstall.admits(path: row.path, kind: row.kind, linkTarget: row.target))
    }

    @Test func unpackingAnArchiveHeldInMemoryGivesTheBundleWholeAndLeavesTheDestinationAlone() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "TrackpadLauncher.app", in: fixture.folder("Release"), version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
        let oldManifest = try BundleFixture.manifest(of: old)
        let archive = try BundleFixture.archive("TrackpadLauncher.app", in: fixture.folder("Release"))

        let unpacked = try BundleInstall.unpack(archive, near: old)
        defer { BundleInstall.discard(unpacked) }

        #expect(unpacked.lastPathComponent == "TrackpadLauncher.app")
        #expect(try BundleFixture.manifest(of: unpacked) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.extendedAttributes(under: unpacked).contains("com.apple.quarantine") == false)
        let volume = { (url: URL) in try url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? NSObject }
        #expect(try volume(unpacked) == volume(applications))
        #expect(unpacked.deletingLastPathComponent() != applications)
        #expect(try BundleFixture.manifest(of: old) == oldManifest)
        #expect(try BundleFixture.appNames(in: applications) == ["TrackpadLauncher.app"])
    }

    @Test func anArchiveWithAnEntryBesideTheBundleIsRefusedAndNothingIsInstalled() throws {
        let fixture = try BundleFixture()
        let release = try fixture.folder("Release")
        try fixture.makeBundle(named: "TrackpadLauncher.app", in: release, version: "1.1.0")
        try fixture.makeBundle(named: "Other.app", in: release, version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
        let archive = try BundleFixture.archiveEverything(in: release)

        #expect(throws: (any Error).self) { try BundleInstall.unpack(archive, near: old) }
        #expect(try BundleFixture.appNames(in: applications) == ["TrackpadLauncher.app"])
    }

    @Test func anArchiveWhoseLinkLeavesTheBundleIsRefused() throws {
        let fixture = try BundleFixture()
        let release = try fixture.folder("Release")
        let app = try fixture.makeBundle(named: "TrackpadLauncher.app", in: release, version: "1.1.0")
        try FileManager.default.createSymbolicLink(
            atPath: app.appending(path: "Contents/escape").path, withDestinationPath: "/etc")
        let applications = try fixture.folder("Applications")
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
        let archive = try BundleFixture.archive("TrackpadLauncher.app", in: release)

        #expect(throws: (any Error).self) { try BundleInstall.unpack(archive, near: old) }
    }

    @Test func dataThatIsNotAnArchiveIsRefused() throws {
        let fixture = try BundleFixture()
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: fixture.folder("Applications"), version: "1.0.0")

        #expect(throws: (any Error).self) { try BundleInstall.unpack(Data("not an archive".utf8), near: old) }
        #expect(throws: (any Error).self) { try BundleInstall.unpack(Data(), near: old) }
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "the committed update fixtures are not generated yet"))
    func theCommittedFixturesArchiveUnpacksToItsRecordedManifest() throws {
        let fixture = try BundleFixture()
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: fixture.folder("Applications"), version: "1.0.0")
        let record = try UpdateFixtures.loadRecord()

        let unpacked = try BundleInstall.unpack(Data(contentsOf: UpdateFixtures.archive), near: old)
        defer { BundleInstall.discard(unpacked) }

        #expect(try BundleFixture.manifest(of: unpacked) == record.manifest)
        #expect(try BundleFixture.extendedAttributes(under: unpacked).contains("com.apple.quarantine") == false)
    }
}
