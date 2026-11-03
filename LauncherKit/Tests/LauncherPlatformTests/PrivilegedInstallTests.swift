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
        beforeRunning(arguments)
        if let answer { return answer }
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script, "sh"] + arguments
        process.currentDirectoryURL = workingDirectory
        let waitForExit: @Sendable () -> Void
        do { waitForExit = try process.start() } catch { return .failed }
        waitForExit()
        return .ran(exitStatus: process.terminationStatus)
    }
}

@MainActor @Suite(.timeLimit(.minutes(1))) struct PrivilegedInstallTests {
    private func location(running: URL) -> Location {
        Location(running: running, original: running, isTranslocated: false, diskImage: nil)
    }

    private func install(_ installer: ApplicationsInstaller) async -> InstallOutcome {
        await awaiting("the install's outcome") { (resume: @escaping @Sendable (InstallOutcome) -> Void) in
            installer.install { resume($0) }
        } ?? .failed(reason: "no outcome")
    }

    /// The staged copy `$2` the administrator was handed, as the installer made it.
    private func stagedPath(_ administrator: TestAdministrator) -> String? { administrator.calls.first?.arguments[1] }

    private func expectStagedGone(_ staged: URL) {
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
    }

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

    @Test func putLeavesTheInstalledCopyWholeWhenTheAdministratorCancels() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "1.0.0")
        let before = try BundleFixture.manifest(of: older)
        chmod(older.path, 0o555)
        let administrator = TestAdministrator.refusing
        let staged = try BundleInstall.stage(source, near: older)

        let outcome = ApplicationsInstaller.put(staged, at: older, by: administrator)

        #expect(outcome == .cancelled)
        #expect(administrator.calls.count == 1)
        #expect(try BundleFixture.manifest(of: older) == before)
        expectStagedGone(staged)
    }

    @Test func putReportsAFailureWhenTheScriptFailsAndLeavesTheOldCopyWhole() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "1.0.0")
        let before = try BundleFixture.manifest(of: older)
        chmod(older.path, 0o555)
        let staged = try BundleInstall.stage(source, near: older)
        let administrator = TestAdministrator(answer: nil) { arguments in
            try? FileManager.default.removeItem(atPath: arguments[1])
        }

        let outcome = ApplicationsInstaller.put(staged, at: older, by: administrator)

        guard case .failed = outcome else {
            Issue.record("expected a failure, got \(outcome)")
            return
        }
        #expect(try BundleFixture.manifest(of: older) == before)
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        expectStagedGone(staged)
    }

    @Test func theRealScriptSwapsTheCopyInThroughPathsHoldingQuotesSpacesAndCommandSubstitution() throws {
        let fixture = try BundleFixture()
        let nasty = "a b ' \" $(touch pwned)"
        let source = try fixture.makeBundle(
            named: "Trackpad Launcher.app", in: fixture.folder("Downloads \(nasty)"), version: "1.1.0")
        let applications = try fixture.folder("Applications \(nasty)")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "1.0.0")
        chmod(older.path, 0o555)
        let administrator = TestAdministrator(answer: nil, workingDirectory: fixture.root) { arguments in
            chmod(arguments[0], 0o755)
        }
        let staged = try BundleInstall.stage(source, near: older)

        let outcome = ApplicationsInstaller.put(staged, at: older, by: administrator)

        #expect(outcome == .installed)
        let arguments = try #require(administrator.calls.first?.arguments)
        #expect(arguments == [older.path, staged.path, PrivilegedInstall.exchange])
        #expect(try BundleFixture.manifest(of: older) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        let names = (FileManager.default.enumerator(atPath: fixture.root.path)?.allObjects as? [String] ?? [])
            .map { ($0 as NSString).lastPathComponent }
        #expect(!names.contains("pwned"))
        expectStagedGone(staged)
    }

    @Test func putMovesTheCopyInWhenNothingLiesAtTheDestinationOfAFolderOnlyTheAdministratorCanWrite() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let destination = applications.appending(path: "Trackpad Launcher.app")
        let staged = try BundleInstall.stage(source, near: destination)
        chmod(applications.path, 0o555)
        let administrator = TestAdministrator(answer: nil) { _ in chmod(applications.path, 0o755) }

        let outcome = ApplicationsInstaller.put(staged, at: destination, by: administrator)

        #expect(outcome == .installed)
        #expect(administrator.calls.count == 1)
        #expect(try BundleFixture.manifest(of: destination) == BundleFixture.manifest(of: source))
        #expect(try BundleFixture.appNames(in: applications) == ["Trackpad Launcher.app"])
        expectStagedGone(staged)
    }

    @Test func putSwapsInProcessWithoutAskingWhenTheDestinationIsWritable() throws {
        let fixture = try BundleFixture()
        let source = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Downloads"), version: "1.1.0")
        let applications = try fixture.folder("Applications")
        let older = try fixture.makeBundle(named: "Trackpad Launcher.app", in: applications, version: "1.0.0")
        let staged = try BundleInstall.stage(source, near: older)
        let administrator = TestAdministrator.refusing

        let outcome = ApplicationsInstaller.put(staged, at: older, by: administrator)

        #expect(outcome == .installed)
        #expect(administrator.calls.isEmpty)
        #expect(try BundleFixture.manifest(of: older) == BundleFixture.manifest(of: source))
        expectStagedGone(staged)
    }

    @Test func aTemporaryFolderIsNotOnADiskImage() {
        #expect(DiskImages.image(holding: FileManager.default.temporaryDirectory) == nil)
    }
}

/// These block for seconds, so each runs its work on a thread of its own and records what it found afterwards.
@Suite(.timeLimit(.minutes(1))) struct PrivilegedSwapAtomicityTests {
    @Test func killingTheRealScriptAtAnyMomentLeavesAWholeCopyAndTheNewOneOnceItExitedZero() async throws {
        let fixture = try BundleFixture()
        let old = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Templates/old"), version: "1.0.0")
        let new = try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Templates/new"), version: "1.1.0")
        let oldManifest = try BundleFixture.manifest(of: old)
        let newManifest = try BundleFixture.manifest(of: new)
        let applications = try fixture.folder("Applications")
        let destination = applications.appending(path: "Trackpad Launcher.app")

        let failures = try await onItsOwnThread("the script to be killed in 100 rounds") { () throws -> [String] in
            let files = FileManager.default
            var failures: [String] = []

            func prepare(_ round: Int) throws -> URL {
                try? files.removeItem(at: destination)
                try files.copyItem(at: old, to: destination)
                let staged = try fixture.folder("Staging \(round)").appending(path: "Trackpad Launcher.app")
                try files.copyItem(at: new, to: staged)
                return staged
            }

            let clock = ContinuousClock()
            let started = clock.now
            let firstStatus = try ScriptRun.start(destination: destination, staged: try prepare(0)).finish(killAfter: .seconds(60))
            let runTime = started.duration(to: clock.now)
            if firstStatus != 0 { failures.append("the unkilled script exited with \(String(describing: firstStatus))") }
            if try BundleFixture.manifest(of: destination) != newManifest { failures.append("the unkilled script left no new copy") }
            let limit = max(runTime.seconds * 2, 0.05)

            for round in 1...100 {
                let staged = try prepare(round)
                let status = try ScriptRun.start(destination: destination, staged: staged)
                    .finish(killAfter: .seconds(Double.random(in: 0...limit)))
                let held = try BundleFixture.manifest(of: destination)
                if held != oldManifest && held != newManifest { failures.append("round \(round): neither the old copy nor the new one") }
                if status == 0 && held != newManifest { failures.append("round \(round): exited 0 without the new copy") }
                if try BundleFixture.appNames(in: applications) != ["Trackpad Launcher.app"] {
                    failures.append("round \(round): the Applications folder holds something else")
                }
            }
            return failures
        }

        for failure in failures ?? [] { Issue.record(Comment(rawValue: failure)) }
    }

    @Test func anObserverNeverReadsAMixedOrBrokenCopyWhilePutAlternatesTwoVersionsIn() async throws {
        let fixture = try BundleFixture()
        let applications = try fixture.folder("Applications")
        let destination = applications.appending(path: "Trackpad Launcher.app")
        let sources = [
            try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Templates/old"), version: "1.0.0"),
            try fixture.makeBundle(named: "Trackpad Launcher.app", in: fixture.folder("Templates/new"), version: "1.1.0"),
        ]
        try FileManager.default.copyItem(at: sources[0], to: destination)

        let found = try await onItsOwnThread("200 swaps under observation") { () throws -> (DestinationObserver.Report, [String]) in
            let observer = DestinationObserver(folder: applications, appName: "Trackpad Launcher.app")
            observer.start()
            var failures: [String] = []
            for round in 0..<200 {
                let staged = try BundleInstall.stage(sources[(round + 1) % 2], near: destination)
                let outcome = ApplicationsInstaller.put(staged, at: destination, by: TestAdministrator.refusing)
                if outcome != .installed { failures.append("round \(round): \(outcome)") }
            }
            return (observer.stop(), failures)
        }
        guard let (report, failures) = found else { return }

        for failure in failures { Issue.record(Comment(rawValue: failure)) }
        #expect(report.observations > 0)
        // Not asserted: a lookup racing the kernel's own atomic exchange (renamex_np RENAME_SWAP) can find no entry
        // for a moment although one is always on disk (plans/022-in-app-updates/.temp/probes/swap-atomicity.swift
        // shows it for the bare syscall), so `missing` cannot tell a swap from a gap. That a kill at any instant leaves
        // a whole copy rests on that exchange's contract and, for the administrator's script, on the kill test above;
        // this one proves no observer ever reads a mixed or broken copy.
        _ = report.missing
        #expect(report.unreadable == 0, "unreadable in \(report.unreadable) observations")
        #expect(report.mixed == 0, "mixed in \(report.mixed) observations")
    }
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}

/// The real script in its own process group, so a kill takes `osascript` with it.
struct ScriptRun {
    let pid: pid_t

    static func start(destination: URL, staged: URL) throws -> ScriptRun {
        let arguments = [
            "/bin/sh", "-c", PrivilegedInstall.script, "sh", destination.path, staged.path, PrivilegedInstall.exchange,
        ]
        let pointers = arguments.map { strdup($0) } + [nil]
        defer { pointers.forEach { free($0) } }
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)
        var pid: pid_t = 0
        guard posix_spawn(&pid, "/bin/sh", nil, &attributes, pointers, environ) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        return ScriptRun(pid: pid)
    }

    /// Waits up to `killAfter`, then kills the whole group. Returns the exit status when the script exited by itself
    /// (or won the race), nil when the kill ended it. Returns only once nothing of the group is left running.
    func finish(killAfter: Duration) throws -> Int32? {
        let deadline = ContinuousClock.now.advanced(by: killAfter)
        var status: Int32 = 0
        while ContinuousClock.now < deadline {
            if waitpid(pid, &status, WNOHANG) == pid { return Self.exitStatus(status) }
            usleep(500)
        }
        kill(-pid, SIGKILL)
        let reaped = waitpid(pid, &status, 0)
        for _ in 0..<4000 where kill(-pid, 0) == 0 { usleep(500) }
        return reaped == pid ? Self.exitStatus(status) : nil
    }

    private static func exitStatus(_ status: Int32) -> Int32? {
        status & 0x7f == 0 ? (status >> 8) & 0xff : nil
    }
}

/// Reads two files of the destination bundle through one directory handle as fast as it can, off the main thread.
final class DestinationObserver: @unchecked Sendable {
    struct Report { var observations = 0, missing = 0, unreadable = 0, mixed = 0 }

    private let folder: URL
    private let appName: String
    private let lock = NSLock()
    private var report = Report()
    private var stopping = false
    private let finished = DispatchSemaphore(value: 0)

    init(folder: URL, appName: String) {
        self.folder = folder
        self.appName = appName
    }

    func start() {
        let thread = Thread { [self] in
            let folderFD = open(folder.path, O_RDONLY | O_DIRECTORY)
            defer { close(folderFD); finished.signal() }
            while !isStopping {
                let result = observe(folderFD)
                lock.lock()
                report.observations += 1
                switch result {
                case .whole, .swappedOut: break
                case .missing: report.missing += 1
                case .unreadable: report.unreadable += 1
                case .mixed: report.mixed += 1
                }
                lock.unlock()
            }
        }
        thread.start()
    }

    func stop() -> Report {
        lock.lock()
        stopping = true
        lock.unlock()
        finished.wait()
        lock.lock()
        defer { lock.unlock() }
        return report
    }

    private var isStopping: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopping
    }

    private enum Observation { case whole, missing, unreadable, mixed, swappedOut }

    /// One resolution of the app's name, then both reads through that handle, so a mix is a defect and never a swap
    /// between two reads.
    private func observe(_ folderFD: Int32) -> Observation {
        let appFD = openat(folderFD, appName, O_RDONLY | O_DIRECTORY)
        guard appFD >= 0 else { return .missing }
        defer { close(appFD) }
        guard let binary = read(appFD, "Contents/MacOS/fixture"), let deep = read(appFD, "Contents/Resources/nested/deep.txt")
        else {
            // The handle may already name the copy that was just replaced and is being removed.
            var held = stat()
            var current = stat()
            let stillThere =
                fstat(appFD, &held) == 0 && fstatat(folderFD, appName, &current, 0) == 0 && held.st_ino == current.st_ino
            return stillThere ? .unreadable : .swappedOut
        }
        return binary.dropFirst("binary ".count) == deep.dropFirst("deep ".count) ? .whole : .mixed
    }

    private func read(_ directoryFD: Int32, _ path: String) -> Substring? {
        let fd = openat(directoryFD, path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var buffer = [UInt8](repeating: 0, count: 64)
        let count = Foundation.read(fd, &buffer, buffer.count)
        guard count > 0 else { return nil }
        return Substring(String(decoding: buffer[0..<count], as: UTF8.self))
    }
}
