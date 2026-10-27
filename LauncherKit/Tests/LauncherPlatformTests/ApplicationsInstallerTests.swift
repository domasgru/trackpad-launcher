import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct ApplicationsInstallerTests {
    private func install(_ installer: ApplicationsInstaller) async -> InstallOutcome {
        await withCheckedContinuation { continuation in
            installer.install { continuation.resume(returning: $0) }
        }
    }

    private func location(running: URL, original: URL? = nil, translocated: Bool = false, diskImage: DiskImage? = nil)
        -> Location
    {
        Location(running: running, original: original ?? running, isTranslocated: translocated, diskImage: diskImage)
    }

    @Test func installingIntoAnEmptyApplicationsFolderCopiesTheBundleWithoutQuarantine() async throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let installer = ApplicationsInstaller(location: location(running: source), applications: applications, administrator: TestAdministrator.refusing)

        let outcome = await install(installer)

        let destination = applications.appending(path: "Trackpad Launcher.app")
        #expect(outcome == .installed)
        #expect(try BundleFixture.manifest(of: destination) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.extendedAttributes(under: destination).contains("com.apple.quarantine") == false)
        #expect(try BundleFixture.extendedAttributes(under: source).contains("com.apple.quarantine"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: applications.path) == ["Trackpad Launcher.app"])
    }

    @Test func installingReplacesAnotherVersionUnderTheSameName() async throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let newer = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "2.0")
        #expect(try BundleFixture.manifest(of: newer) != BundleFixture.manifest(of: source))

        let outcome = await install(ApplicationsInstaller(location: location(running: source), applications: applications, administrator: TestAdministrator.refusing))

        #expect(outcome == .installed)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        #expect(try BundleFixture.manifest(of: newer) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.extendedAttributes(under: newer).contains("com.apple.quarantine") == false)
    }

    @Test func installingReplacesTheInstalledCopyWhateverItIsNamed() async throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let renamed = try fixture.makeBundle(named: "Trackpad Launcher Old.app", in: applications, version: "2.0")

        let outcome = await install(ApplicationsInstaller(location: location(running: source), applications: applications, administrator: TestAdministrator.refusing))

        #expect(outcome == .installed)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher Old.app"])
        #expect(try BundleFixture.manifest(of: renamed) == BundleFixture.manifest(of: source))
    }

    @Test func aTranslocatedCopyIsCopiedFromTheRunningBundleUnderTheOriginalsName() async throws {
        let fixture = try BundleFixture()
        let running = try fixture.makeBundle(named: "Mounted.app", in: fixture.folder("AppTranslocation"), version: "1.0")
        let original = try fixture.folder("Downloads").appending(path: "Trackpad Launcher.app")
        let applications = try fixture.folder("Applications")
        let place = location(running: running, original: original, translocated: true)

        let outcome = await install(ApplicationsInstaller(location: place, applications: applications, administrator: TestAdministrator.refusing))

        #expect(outcome == .installed)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        #expect(
            try BundleFixture.manifest(of: applications.appending(path: "Trackpad Launcher.app"))
                == BundleFixture.manifest(of: running))
    }

    @Test func anUnreadableSourceFailsBeforeAnythingChanges() async throws {
        let fixture = try BundleFixture()
        let applications = try fixture.folder("Applications")
        let missing = fixture.root.appending(path: "Gone.app")

        let outcome = await install(ApplicationsInstaller(location: location(running: missing), applications: applications, administrator: TestAdministrator.refusing))

        guard case .failed = outcome else {
            Issue.record("expected a failure, got \(outcome)")
            return
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: applications.path).isEmpty)
    }

    @Test func removingTheOriginalDeletesItFromDownloads() throws {
        let fixture = try BundleFixture()
        let original = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let installer = ApplicationsInstaller(location: location(running: original), applications: try fixture.folder("Applications"), administrator: TestAdministrator.refusing)

        installer.removeOriginal()

        #expect(!FileManager.default.fileExists(atPath: original.path))
    }

    @Test func aFolderThatCannotBeWrittenKeepsTheOriginalWhole() throws {
        let fixture = try BundleFixture()
        let downloads = try fixture.folder("Share")
        let original = try fixture.makeBundle(named: "Trackpad Launcher.app", in: downloads, version: "1.0")
        let before = try BundleFixture.manifest(of: original)
        chmod(downloads.path, 0o555)
        let installer = ApplicationsInstaller(location: location(running: original), applications: try fixture.folder("Applications"), administrator: TestAdministrator.refusing)

        installer.removeOriginal()

        #expect(try BundleFixture.manifest(of: original) == before)
    }

    @Test func aCopyOnADiskImageStays() throws {
        let fixture = try BundleFixture()
        let original = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Volume"), version: "1.0")
        let image = DiskImage(volume: original.deletingLastPathComponent())
        let installer = ApplicationsInstaller(
            location: location(running: original, diskImage: image), applications: try fixture.folder("Applications"), administrator: TestAdministrator.refusing)

        installer.removeOriginal()

        #expect(FileManager.default.fileExists(atPath: original.path))
    }

    @Test func theInstalledCopyItselfStays() throws {
        let fixture = try BundleFixture()
        let applications = try fixture.folder("Applications")
        let installed = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "1.0")
        let installer = ApplicationsInstaller(location: location(running: installed), applications: applications, administrator: TestAdministrator.refusing)

        installer.removeOriginal()

        #expect(FileManager.default.fileExists(atPath: installed.path))
    }
}
