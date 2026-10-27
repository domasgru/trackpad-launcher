import Foundation
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

/// Runs the real script as the current user, answering as configured, and records what it was handed.
final class TestAdministrator: Administrator {
    struct Call: Equatable { let script: String; let arguments: [String] }

    private let answer: AdministratorResult?
    private let beforeRunning: @Sendable ([String]) -> Void
    private let workingDirectory: URL?
    private let recorded = Mutex<[Call]>([])

    /// `answer` nil runs the script unprivileged.
    init(
        answer: AdministratorResult?, workingDirectory: URL? = nil,
        beforeRunning: @escaping @Sendable ([String]) -> Void = { _ in }
    ) {
        self.answer = answer
        self.workingDirectory = workingDirectory
        self.beforeRunning = beforeRunning
    }

    static var refusing: TestAdministrator { TestAdministrator(answer: .cancelled) }

    var calls: [Call] { recorded.withLock { $0 } }

    func run(script: String, arguments: [String]) -> AdministratorResult {
        recorded.withLock { $0.append(Call(script: script, arguments: arguments)) }
        if let answer { return answer }
        beforeRunning(arguments)
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script, "sh"] + arguments
        process.currentDirectoryURL = workingDirectory
        do { try process.run() } catch { return .failed }
        process.waitUntilExit()
        return .ran(exitStatus: process.terminationStatus)
    }
}

@MainActor @Suite struct PrivilegedInstallTests {
    private func location(running: URL) -> Location {
        Location(running: running, original: running, isTranslocated: false, diskImage: nil)
    }

    private func install(_ installer: ApplicationsInstaller) async -> InstallOutcome {
        await withCheckedContinuation { continuation in
            installer.install { continuation.resume(returning: $0) }
        }
    }

    /// The staged copy `$2` the administrator was handed, as the installer made it.
    private func stagedPath(_ administrator: TestAdministrator) -> String? { administrator.calls.first?.arguments[1] }

    @Test(arguments: [AdministratorResult.cancelled, .failed])
    func anApplicationsFolderThisAccountCannotWriteAsksTheAdministratorAndLeavesTheCopyThereAsItWas(
        answer: AdministratorResult
    ) async throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        let before = try BundleFixture.manifest(of: older)
        chmod(applications.path, 0o555)
        let administrator = TestAdministrator(answer: answer)

        let outcome = await install(
            ApplicationsInstaller(location: location(running: source), applications: applications, administrator: administrator))

        switch (answer, outcome) {
        case (.cancelled, .cancelled): break
        case (.failed, .failed(let reason)): #expect(!reason.isEmpty)
        default: Issue.record("\(answer) gave \(outcome)")
        }
        #expect(administrator.calls.count == 1)
        #expect(administrator.calls.first?.script == PrivilegedInstall.script)
        #expect(try BundleFixture.manifest(of: older) == before)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        let staged = try #require(stagedPath(administrator))
        #expect(!FileManager.default.fileExists(atPath: staged))
    }

    @Test(arguments: [AdministratorResult.cancelled, .failed])
    func anInstalledCopyThisAccountCannotWriteAsksTheAdministratorAndLeavesItAsItWas(answer: AdministratorResult) async throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        let before = try BundleFixture.manifest(of: older)
        chmod(older.path, 0o555)
        let administrator = TestAdministrator(answer: answer)

        let outcome = await install(
            ApplicationsInstaller(location: location(running: source), applications: applications, administrator: administrator))

        #expect(administrator.calls.count == 1)
        #expect(outcome == (answer == .cancelled ? .cancelled : .failed(reason: Copy.cannotWriteToApplications)))
        #expect(try BundleFixture.manifest(of: older) == before)
        let staged = try #require(stagedPath(administrator))
        #expect(!FileManager.default.fileExists(atPath: staged))
    }

    @Test func aRunningBundleThatCannotBeReadFailsBeforeTheAdministratorIsAsked() async throws {
        let fixture = try BundleFixture()
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        let before = try BundleFixture.manifest(of: older)
        chmod(applications.path, 0o555)
        let administrator = TestAdministrator(answer: .cancelled)

        let outcome = await install(
            ApplicationsInstaller(
                location: location(running: fixture.root.appending(path: "Gone.app")), applications: applications,
                administrator: administrator))

        guard case .failed = outcome else {
            Issue.record("expected a failure, got \(outcome)")
            return
        }
        #expect(administrator.calls.isEmpty)
        #expect(try BundleFixture.manifest(of: older) == before)
    }

    @Test func theRealScriptSwapsTheCopyInThroughPathsHoldingQuotesSpacesAndCommandSubstitution() throws {
        let fixture = try BundleFixture()
        let nasty = "a b ' \" $(touch pwned)"
        let source = try fixture.makeBundle(
            named: "Trackpad Launcher.app", in: fixture.folder("Downloads \(nasty)"), version: "1.0")
        let applications = try fixture.folder("Applications \(nasty)")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        let administrator = TestAdministrator(answer: nil, workingDirectory: fixture.root)
        let staged = try BundleInstall.stage(source, near: older)
        let result = PrivilegedInstall.swap(
            staged, into: older, asideIn: staged.deletingLastPathComponent(), by: administrator)

        #expect(result == .installed)
        let arguments = try #require(administrator.calls.first?.arguments)
        #expect(arguments == [older.path, staged.path, staged.deletingLastPathComponent().appending(path: "Replaced Trackpad Launcher.app").path])
        let aside = URL(filePath: arguments[2])
        #expect(aside.deletingLastPathComponent() == staged.deletingLastPathComponent())
        #expect(!aside.path.hasPrefix(applications.path))
        #expect(try BundleFixture.manifest(of: older) == BundleFixture.manifest(of: source))
        #expect(try FileManager.default.contentsOfDirectory(atPath: staged.deletingLastPathComponent().path).isEmpty)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        let names = (FileManager.default.enumerator(atPath: fixture.root.path)?.allObjects as? [String] ?? [])
            .map { ($0 as NSString).lastPathComponent }
        #expect(!names.contains("pwned"))
        BundleInstall.discard(staged)
    }

    @Test func aSecondMoveThatFailsPutsTheOldCopyBackAndReportsFailure() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        let before = try BundleFixture.manifest(of: older)
        let staged = try BundleInstall.stage(source, near: older)
        let administrator = TestAdministrator(answer: nil) { arguments in
            try? FileManager.default.removeItem(atPath: arguments[1])
        }

        let result = PrivilegedInstall.swap(
            staged, into: older, asideIn: staged.deletingLastPathComponent(), by: administrator)

        guard case .failed = result else {
            Issue.record("expected a failure, got \(result)")
            return
        }
        #expect(try BundleFixture.manifest(of: older) == before)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: staged.deletingLastPathComponent().path).isEmpty)
        BundleInstall.discard(staged)
    }

    @Test func anOldCopyThatCannotBeFullyRemovedStillLeavesTheNewCopyInstalled() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "0.9")
        chmod(older.appending(path: "Contents/Resources/nested").path, 0o555)
        let staged = try BundleInstall.stage(source, near: older)

        let result = PrivilegedInstall.swap(
            staged, into: older, asideIn: staged.deletingLastPathComponent(), by: TestAdministrator(answer: nil))

        #expect(result == .installed)
        #expect(try BundleFixture.manifest(of: older) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        BundleInstall.discard(staged)
    }

    @Test func aTemporaryFolderIsNotOnADiskImage() {
        #expect(DiskImages.image(holding: FileManager.default.temporaryDirectory) == nil)
    }
}
