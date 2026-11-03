import Foundation
import Synchronization
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The events an update reported, with a way to wait for one.
@MainActor private final class EventLog {
    private(set) var events: [UpdateEvent] = []
    private var waiters: [(check: ([UpdateEvent]) -> Bool, resume: @Sendable (()) -> Void)] = []

    func record(_ event: UpdateEvent) {
        events.append(event)
        let ready = waiters.filter { $0.check(events) }
        waiters = waiters.filter { !$0.check(events) }
        ready.forEach { $0.resume(()) }
    }

    /// Returns once `check` holds of the events so far; fails the test when it never does.
    func until(_ check: @escaping ([UpdateEvent]) -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        if check(events) { return }
        _ = await awaiting("an expected update event", sourceLocation: sourceLocation) {
            (resume: @escaping @Sendable (()) -> Void) in
            waiters.append((check, resume))
        }
    }

    var progress: [Double] {
        events.compactMap { if case .progress(let fraction) = $0 { fraction } else { nil } }
    }

    /// The order `UpdateEvent` promises: any progress, then failed, or downloaded and exactly one outcome.
    var followsTheContract: Bool {
        var rest = events[...]
        while case .progress? = rest.first { rest = rest.dropFirst() }
        switch Array(rest) {
        case [], [.failed], [.downloaded], [.downloaded, .installed], [.downloaded, .declined], [.downloaded, .failed]: return true
        default: return false
        }
    }
}

@MainActor @Suite(.timeLimit(.minutes(1))) struct ApplicationsUpdaterTests {
    private static let archivePath = "/downloads/TrackpadLauncher-1.1.0-macOS-26.0.aar"
    private static let signer = Signer(team: "ABCDE12345", identifier: BundleFixture.identifier)

    @MainActor private struct Rig {
        let fixture: BundleFixture
        let applications: URL
        let old: URL
        let oldManifest: [String: String]
        let server: LocalReleaseServer
        let administrator: TestAdministrator
        let updater: ApplicationsUpdater
        let log = EventLog()
        /// The name of a file in the ad-hoc release app, to find an unpacked copy of it.
        let marker = BundleFixture.newMarker()
        let downloadFilesBefore: [String]

        init(
            administrator: TestAdministrator = TestAdministrator(answer: nil), signer: Signer = ApplicationsUpdaterTests.signer,
            stall: TimeInterval = 10, download: ApplicationsUpdater.Download? = nil
        ) async throws {
            downloadFilesBefore = await BundleFixture.downloadFiles()
            fixture = try BundleFixture()
            applications = try fixture.folder("Applications")
            old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
            oldManifest = try BundleFixture.manifest(of: old)
            server = try await LocalReleaseServer()
            self.administrator = administrator
            updater = ApplicationsUpdater(
                replacing: old, signer: signer, administrator: administrator,
                download: download ?? GitHubReleases.ArchiveDownload(stall: stall).archive)
        }

        /// An ad-hoc signed 1.1.0 app carrying the marker, archived as release.sh does.
        func adHocArchive() throws -> Data {
            let release = try fixture.folder("Release")
            try fixture.makeBundle(named: "TrackpadLauncher.app", in: release, version: "1.1.0", marker: marker)
            return try BundleFixture.archive("TrackpadLauncher.app", in: release)
        }

        /// Serves `archive` as a stream of two chunks, the first `percent` of it, each when the gate lets it go.
        func stream(_ archive: Data, firstChunkPercent percent: Int) -> LocalReleaseServer.ChunkGate {
            let gate = LocalReleaseServer.ChunkGate()
            let cut = (archive.count * percent + 99) / 100
            server.script(
                ApplicationsUpdaterTests.archivePath,
                .stream(length: archive.count, chunks: [Data(archive.prefix(cut)), Data(archive.dropFirst(cut))], gate: gate))
            return gate
        }

        func untilTheServerSeesTheClientClose() async -> Bool {
            for _ in 0..<100 {
                if !server.clientClosures.isEmpty { return true }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return false
        }

        func release(size: Int) -> Release {
            Release(
                version: Version(1, 1, 0), minimumMacOS: Version(26, 0), archive: server.url(path: ApplicationsUpdaterTests.archivePath),
                archiveSize: size)
        }

        func update(size: Int) {
            let log = log
            updater.update(to: release(size: size)) { log.record($0) }
        }

        func expectOldBundleUntouched() async throws {
            #expect(try BundleFixture.manifest(of: old) == oldManifest)
            #expect(try BundleFixture.appNames(in: applications) == ["TrackpadLauncher.app"])
            #expect(administrator.calls.isEmpty)
            await expectNothingOfTheUpdateOnDisk()
        }

        func expectNothingOfTheUpdateOnDisk() async {
            #expect(await BundleFixture.downloadFiles() == downloadFilesBefore)
            #expect(await BundleFixture.copies(carrying: marker) == [])
        }
    }

    /// Lets the chunks of a body go one at a time, waiting after each for the progress the bytes so far amount to.
    private static func release(_ chunks: [Data], through gate: LocalReleaseServer.ChunkGate, untilReportedBy log: EventLog) async {
        let total = chunks.reduce(0) { $0 + $1.count }
        var received = 0
        for chunk in chunks {
            gate.release()
            received += chunk.count
            let expected = Double(received * 100 / total) / 100
            await log.until { $0.contains(.progress(expected)) }
        }
    }

    private static func quarters(of data: Data) -> [Data] {
        let size = data.count / 4
        return (0..<4).map { data[($0 * size)..<(($0 == 3) ? data.count : ($0 + 1) * size)] }
    }

    @Test func aDownloadReportsEveryWholePercentAsItsQuartersArriveThenFailsOnAnArchiveThatHoldsSomethingElse() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let junk = Data(repeating: 7, count: 4000)
        let gate = LocalReleaseServer.ChunkGate()
        let quarters = Self.quarters(of: junk)
        rig.server.script(Self.archivePath, .stream(length: junk.count, chunks: quarters, gate: gate))

        rig.update(size: junk.count)
        await Self.release(quarters, through: gate, untilReportedBy: rig.log)
        await rig.log.until { $0.contains(.failed) }

        let progress = rig.log.progress
        #expect(progress == progress.sorted() && Set(progress).count == progress.count)
        #expect(progress.allSatisfy { ($0 * 100).rounded() == $0 * 100 })
        #expect(progress.last == 1.0)
        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test func anArchiveThatIsNotGenuineIsRefusedBeforeAnyPromptEvenWhereThePromptWouldBeNeeded() async throws {
        let rig = try await Rig(administrator: .refusing)
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        chmod(rig.applications.path, 0o555)

        rig.update(size: archive.count)
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test(arguments: [3999, 4001])
    func aBodyOfTheWrongLengthFailsWithoutEverReportingTheDownloaded(size: Int) async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))

        rig.update(size: archive.count + (size - 4000))
        await rig.log.until { $0.contains(.failed) }

        #expect(!rig.log.events.contains(.downloaded))
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test func aConnectionClosedAfterFortyPercentFails() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        let cut = (archive.count * 40 + 99) / 100
        let gate = LocalReleaseServer.ChunkGate()
        rig.server.script(Self.archivePath, .stream(length: archive.count, chunks: [Data(archive.prefix(cut)), Data()], gate: gate))

        rig.update(size: archive.count)
        gate.release()
        await rig.log.until { $0.contains(.progress(0.4)) }
        gate.release()
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.progress.last == 0.4)
        #expect(!rig.log.events.contains(.downloaded))
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test(arguments: [false, true])
    func aCompleteArchiveIsDownloadedWhetherItComesAtOnceOrSlowerInTotalThanTheStallButNeverIdleThatLong(trickle: Bool) async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        if trickle {
            let size = archive.count / 6 + 1
            let gate = LocalReleaseServer.ChunkGate()
            let pieces = stride(from: 0, to: archive.count, by: size).map { Data(archive[$0..<min($0 + size, archive.count)]) }
            rig.server.script(Self.archivePath, .stream(length: archive.count, chunks: pieces, gate: gate))
            rig.update(size: archive.count)
            await Task.detached {
                for _ in pieces {
                    gate.release()
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }.value
        } else {
            rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
            rig.update(size: archive.count)
        }
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.log.progress.last == 1.0)
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test(arguments: [404, 500])
    func aStatusOtherThan200Fails(status: Int) async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        rig.server.script(Self.archivePath, .respond(status: status, body: Data(repeating: 7, count: 4000)))

        rig.update(size: 4000)
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.events == [.failed])
        try await rig.expectOldBundleUntouched()
    }

    @Test func aServerThatStopsSendingFailsAfterTheStall() async throws {
        let rig = try await Rig(stall: 1)
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        let gate = rig.stream(archive, firstChunkPercent: 40)
        rig.update(size: archive.count)

        let lastByte = ContinuousClock.now
        gate.release()
        await rig.log.until { $0.contains(.failed) }

        #expect(ContinuousClock.now - lastByte >= .seconds(1))
        #expect(rig.log.progress.last == 0.4)
        #expect(!rig.log.events.contains(.downloaded))
        #expect(rig.log.followsTheContract)
        try await rig.expectOldBundleUntouched()
    }

    @Test func cancellingAtFortyPercentClosesTheConnectionAndLeavesNothingAndTheNextUpdateWorks() async throws {
        let rig = try await Rig(administrator: .refusing)
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        let gate = rig.stream(archive, firstChunkPercent: 40)
        chmod(rig.applications.path, 0o555)
        rig.update(size: archive.count)
        gate.release()
        await rig.log.until { $0.contains(.progress(0.4)) }

        rig.updater.cancelDownload()
        let seen = await rig.untilTheServerSeesTheClientClose()
        gate.release()
        try await Task.sleep(for: .milliseconds(400))

        #expect(seen)
        #expect(rig.log.progress.last == 0.4)
        #expect(rig.log.events == rig.log.progress.map { .progress($0) })
        try await rig.expectOldBundleUntouched()

        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        let again = EventLog()
        rig.updater.update(to: rig.release(size: archive.count)) { again.record($0) }
        await again.until { $0.contains(.failed) }
        #expect(again.events.contains(.downloaded))
        #expect(again.followsTheContract)
        #expect(again.events.suffix(2) == [.downloaded, .failed])
    }

    @Test func cancellingTheMomentTheArchiveArrivesStopsBeforeTheDownloadedIsReported() async throws {
        let hold = Hold()
        let rig = try await Rig(download: { _, _ in await hold.wait() })
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        chmod(rig.applications.path, 0o555)
        rig.update(size: archive.count)
        await hold.untilWaiting()

        hold.release(archive)
        rig.updater.cancelDownload()
        try await Task.sleep(for: .milliseconds(500))

        #expect(rig.log.events.isEmpty)
        try await rig.expectOldBundleUntouched()
    }

    @Test func cancellingFromInsideTheDownloadedEventChangesNothingAndOneOutcomeFollows() async throws {
        let hold = Hold()
        let rig = try await Rig(download: { _, _ in await hold.wait() })
        defer { rig.server.stop() }
        let archive = try rig.adHocArchive()
        let log = rig.log
        let updater = rig.updater
        updater.update(to: rig.release(size: archive.count)) { event in
            if event == .downloaded { updater.cancelDownload() }
            log.record(event)
        }
        await hold.untilWaiting()

        hold.release(archive)
        await log.until { $0.contains(.failed) }

        #expect(log.events == [.downloaded, .failed])
        try await rig.expectOldBundleUntouched()
    }

    @Test func cancellingStopsTheDownloadAndNothingMoreIsReported() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let junk = Data(repeating: 7, count: 4000)
        let gate = LocalReleaseServer.ChunkGate()
        rig.server.script(Self.archivePath, .stream(length: 4000, chunks: Self.quarters(of: junk), gate: gate))
        rig.update(size: 4000)
        gate.release()
        await rig.log.until { $0.contains(.progress(0.25)) }

        rig.updater.cancelDownload()
        for _ in 0..<3 { gate.release() }
        try await Task.sleep(for: .milliseconds(400))

        #expect(rig.log.events == [.progress(0.25)])
        try await rig.expectOldBundleUntouched()
    }

    @Test func everyRequestOfTheDownloadCarriesTheSameConstantHeadersAcrossTheRedirectAndNoCookie() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let assets = "/assets/archive"
        rig.server.script(
            Self.archivePath,
            .respond(
                status: 302,
                headers: ["Location": rig.server.url(path: assets).absoluteString, "Set-Cookie": "session=abc; Max-Age=3600"]))
        rig.server.script(assets, .respond(status: 200, headers: ["Set-Cookie": "other=1"], body: Data(repeating: 7, count: 4000)))

        rig.update(size: 4000)
        await rig.log.until { $0.contains(.downloaded) }

        let requests = rig.server.requests
        #expect(requests.map(\.path) == [Self.archivePath, assets])
        for request in requests {
            #expect(request.line.hasPrefix("GET "))
            #expect(request.body.isEmpty)
            let named = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.name.lowercased(), $0.value) })
            #expect(named.count == request.headers.count)
            let constant = named.filter { !["host", "accept-encoding", "connection", "cache-control"].contains($0.key) }
            #expect(
                constant == [
                    "user-agent": "TrackpadLauncher", "accept-language": "en", "accept": "application/octet-stream",
                    "x-github-api-version": "2022-11-28",
                ])
            #expect(named["cookie"] == nil)
            #expect(named["cache-control"] == "no-cache")
        }
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"))
    func theCommittedFixtureInstallsOverTheOldBundleAsWholeAndWithoutQuarantine() async throws {
        let record = try UpdateFixtures.loadRecord()
        let signer = Signer(team: record.team, identifier: record.identifier)
        let archive = try Data(contentsOf: UpdateFixtures.archive)
        for overFixtureItself in [false, true] {
            let rig = try await Rig(signer: signer)
            defer { rig.server.stop() }
            if overFixtureItself {
                try FileManager.default.removeItem(at: rig.old)
                try FileManager.default.copyItem(at: UpdateFixtures.developerIDApp, to: rig.old)
            }
            let gate = LocalReleaseServer.ChunkGate()
            let quarters = Self.quarters(of: archive)
            rig.server.script(Self.archivePath, .stream(length: archive.count, chunks: quarters, gate: gate))
            let offered = Release(
                version: Version(record.version)!, minimumMacOS: Version(record.minimumMacOS)!,
                archive: rig.server.url(path: Self.archivePath), archiveSize: archive.count)
            let log = rig.log
            rig.updater.update(to: offered) { log.record($0) }

            await Self.release(quarters, through: gate, untilReportedBy: log)
            await log.until { $0.contains(.installed) || $0.contains(.failed) }

            #expect(log.events.suffix(2) == [.downloaded, .installed])
            #expect(log.progress.last == 1.0)
            #expect(log.followsTheContract)
            #expect(try BundleFixture.manifest(of: rig.old) == record.manifest)
            #expect(try BundleFixture.extendedAttributes(under: rig.old).contains("com.apple.quarantine") == false)
            #expect(rig.administrator.calls.isEmpty)
            #expect(try BundleFixture.appNames(in: rig.applications) == ["TrackpadLauncher.app"])
        }
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"))
    func aCancelledAdministratorPromptDeclinesAndLeavesTheOldBundleAsItWas() async throws {
        let record = try UpdateFixtures.loadRecord()
        let rig = try await Rig(administrator: .refusing, signer: Signer(team: record.team, identifier: record.identifier))
        defer { rig.server.stop() }
        let archive = try Data(contentsOf: UpdateFixtures.archive)
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        chmod(rig.applications.path, 0o555)
        let offered = Release(
            version: Version(record.version)!, minimumMacOS: Version(record.minimumMacOS)!,
            archive: rig.server.url(path: Self.archivePath), archiveSize: archive.count)
        let log = rig.log

        rig.updater.update(to: offered) { log.record($0) }
        await log.until { $0.contains(.declined) || $0.contains(.failed) }

        #expect(log.events.suffix(2) == [.downloaded, .declined])
        #expect(rig.administrator.calls.count == 1)
        #expect(try BundleFixture.manifest(of: rig.old) == rig.oldManifest)
    }

    // MARK: Refused before any prompt

    enum Refusal: CaseIterable {
        case signedByAnotherTeam, anotherIdentifier, anotherVersionThanOffered, anotherMinimumMacOS, oneResourceByteChanged
    }

    @Test(
        .enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"),
        arguments: Refusal.allCases)
    func aGenuineLookingArchiveThatIsNotTheOneOfferedIsRefusedBeforeAnyPromptAndNothingOfItRemains(_ refusal: Refusal) async throws {
        let record = try UpdateFixtures.loadRecord()
        var signer = Signer(team: record.team, identifier: record.identifier)
        var version = Version(record.version)!
        var minimum = Version(record.minimumMacOS)!
        var archive = try Data(contentsOf: UpdateFixtures.archive)
        switch refusal {
        case .signedByAnotherTeam: signer = Signer(team: "ZZZZZZZZZZ", identifier: record.identifier)
        case .anotherIdentifier: signer = Signer(team: record.team, identifier: "com.example.NotTheLauncher")
        case .anotherVersionThanOffered: version = Version(1, 0, 5)
        case .anotherMinimumMacOS: minimum = Version(99)
        case .oneResourceByteChanged: break
        }
        let rig = try await Rig(administrator: .refusing, signer: signer)
        defer { rig.server.stop() }
        if refusal == .oneResourceByteChanged {
            let folder = try rig.fixture.folder("Tampered")
            let copy = folder.appending(path: "TrackpadLauncher.app")
            try FileManager.default.copyItem(at: UpdateFixtures.developerIDApp, to: copy)
            guard try Self.changeOneByteOfAResource(in: copy) else { return }
            archive = try BundleFixture.archive("TrackpadLauncher.app", in: folder)
        }
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        chmod(rig.applications.path, 0o555)
        let offered = Release(version: version, minimumMacOS: minimum, archive: rig.server.url(path: Self.archivePath), archiveSize: archive.count)
        let log = rig.log

        rig.updater.update(to: offered) { log.record($0) }
        await log.until { $0.contains(.failed) || $0.contains(.declined) || $0.contains(.installed) }

        #expect(log.events.suffix(2) == [.downloaded, .failed])
        #expect(log.followsTheContract)
        #expect(rig.administrator.calls.isEmpty, "the administrator is never asked about an archive that is not the one offered")
        #expect(await BundleFixture.bundles(identifiedBy: record.identifier) == [])
        try await rig.expectOldBundleUntouched()
    }

    /// False, with an issue recorded, when the fixture app has no sealed resource file to change.
    private static func changeOneByteOfAResource(in app: URL) throws -> Bool {
        let resource = app.appending(path: "Contents/Resources/fixture.txt")
        guard var bytes = try? Data(contentsOf: resource), !bytes.isEmpty else {
            Issue.record("The fixture app has no Contents/Resources/fixture.txt to tamper with; run Scripts/make-update-fixtures.sh")
            return false
        }
        bytes[bytes.startIndex] ^= 0xFF
        chmod(resource.path, 0o644)
        try bytes.write(to: resource)
        return true
    }

    enum Crafted: CaseIterable {
        case besideTheBundle, climbingOutOfTheBundle, absolutePath, lookalikeBundleName, fileBeneathALinkOutOfTheBundle, namedPipe

        func extras(sentinel: URL) -> [CraftedArchive.Entry] {
            let data = Data("x".utf8)
            switch self {
            case .besideTheBundle: return [.directory("Other.app"), .file("Other.app/x", data)]
            case .climbingOutOfTheBundle: return [.file("TrackpadLauncher.app/../escape", data)]
            case .absolutePath: return [.file(sentinel.path + "/pwned", data)]
            case .lookalikeBundleName: return [.directory("TrackpadLauncher.appx"), .file("TrackpadLauncher.appx/x", data)]
            case .fileBeneathALinkOutOfTheBundle:
                return [.link("TrackpadLauncher.app/Contents/out", to: sentinel.path), .file("TrackpadLauncher.app/Contents/out/pwned", data)]
            case .namedPipe: return [.fifo("TrackpadLauncher.app/Contents/pipe")]
            }
        }
    }

    @Test(arguments: Crafted.allCases)
    func anArchiveHoldingAnythingButTheAppIsRefusedAndNothingIsWrittenOutsideTheStagingFolder(_ crafted: Crafted) async throws {
        let rig = try await Rig(administrator: .refusing)
        defer { rig.server.stop() }
        let release = try rig.fixture.folder("Release")
        let app = try rig.fixture.makeBundle(named: "TrackpadLauncher.app", in: release, version: "1.1.0", marker: rig.marker)
        let sentinel = try rig.fixture.folder("Sentinel")
        let archive = try CraftedArchive.make(CraftedArchive.entries(of: app) + crafted.extras(sentinel: sentinel))
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        chmod(rig.applications.path, 0o555)

        rig.update(size: archive.count)
        await rig.log.until { $0.contains(.failed) || $0.contains(.declined) || $0.contains(.installed) }

        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.administrator.calls.isEmpty, "the administrator is never asked about an archive holding more than the app")
        #expect(try FileManager.default.contentsOfDirectory(atPath: sentinel.path) == [])
        try await rig.expectOldBundleUntouched()
        #expect(!FileManager.default.fileExists(atPath: rig.fixture.root.appending(path: "escape").path))
    }

    // MARK: The administrator's prompt

    /// The order in which the update's events and the administrator's prompt happened.
    private final class Happenings: @unchecked Sendable {
        private let lock = NSLock()
        private var all: [String] = []

        func add(_ what: String) {
            lock.lock()
            all.append(what)
            lock.unlock()
        }

        var list: [String] {
            lock.lock()
            defer { lock.unlock() }
            return all
        }
    }

    enum PromptCase: CaseIterable { case cancelledWithReadOnlyApplications, cancelledWithReadOnlyOldBundle, runUnprivileged }

    @Test(
        .enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"),
        arguments: PromptCase.allCases)
    func theAdministratorIsAskedOnceAfterTheDownloadedEventAndCancellingDeclinesWhileApprovingInstalls(_ row: PromptCase) async throws {
        let record = try UpdateFixtures.loadRecord()
        let happenings = Happenings()
        let applicationsPath = Mutex<String>("")
        let administrator = TestAdministrator(
            answer: row == .runUnprivileged ? nil : .cancelled,
            beforeRunning: { _ in
                happenings.add("asked")
                if row == .runUnprivileged { chmod(applicationsPath.withLock { $0 }, 0o755) }
            })
        let rig = try await Rig(administrator: administrator, signer: Signer(team: record.team, identifier: record.identifier))
        defer { rig.server.stop() }
        applicationsPath.withLock { $0 = rig.applications.path }
        let archive = try Data(contentsOf: UpdateFixtures.archive)
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        switch row {
        case .cancelledWithReadOnlyOldBundle: chmod(rig.old.path, 0o555)
        case .cancelledWithReadOnlyApplications, .runUnprivileged: chmod(rig.applications.path, 0o555)
        }
        let offered = Release(
            version: Version(record.version)!, minimumMacOS: Version(record.minimumMacOS)!,
            archive: rig.server.url(path: Self.archivePath), archiveSize: archive.count)
        let log = rig.log

        rig.updater.update(to: offered) {
            happenings.add(String(describing: $0))
            log.record($0)
        }
        await log.until { $0.contains(.declined) || $0.contains(.failed) || $0.contains(.installed) }

        let outcome: UpdateEvent = row == .runUnprivileged ? .installed : .declined
        #expect(log.events.suffix(2) == [.downloaded, outcome])
        #expect(log.followsTheContract)
        #expect(administrator.calls.count == 1)
        #expect(happenings.list.filter { !$0.hasPrefix("progress") } == ["downloaded", "asked", String(describing: outcome)])
        let staged = URL(fileURLWithPath: try #require(administrator.calls.first?.arguments[1]))
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
        if row == .runUnprivileged {
            #expect(try BundleFixture.manifest(of: rig.old) == record.manifest)
        } else {
            #expect(try BundleFixture.manifest(of: rig.old) == rig.oldManifest)
        }
    }
}

/// A download that ignores cancellation and returns the archive when the test lets it.
private final class Hold: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data?, Never>?

    func wait() async -> Data? {
        await withCheckedContinuation { next in
            lock.lock()
            continuation = next
            lock.unlock()
        }
    }

    var isWaiting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return continuation != nil
    }

    /// Returns once the update has begun waiting here; fails the test when it has not within half a minute.
    func untilWaiting(sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0..<600 where !isWaiting { try? await Task.sleep(for: .milliseconds(50)) }
        if !isWaiting { Issue.record("The update never started its download", sourceLocation: sourceLocation) }
    }

    func release(_ archive: Data) {
        lock.lock()
        let next = continuation
        continuation = nil
        lock.unlock()
        next?.resume(returning: archive)
    }
}

/// The updater as the composition root builds it, with its literal 30 seconds. Not main-actor isolated, so the half
/// minute does not hold up the other suites.
@Suite(.timeLimit(.minutes(2))) struct ShippedUpdaterStallTests {
    @Test func aDownloadThatMakesNoProgressFailsAfterThirtySeconds() async throws {
        let fixture = try BundleFixture()
        let applications = try fixture.folder("Applications")
        let old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
        let server = try await LocalReleaseServer()
        defer { server.stop() }
        let gate = LocalReleaseServer.ChunkGate()
        let body = Data(repeating: 7, count: 4000)
        server.script("/archive", .stream(length: 4000, chunks: [body.prefix(1600), body.dropFirst(1600)].map { Data($0) }, gate: gate))
        let release = Release(version: Version(1, 1, 0), minimumMacOS: Version(26, 0), archive: server.url(path: "/archive"), archiveSize: 4000)

        let lastByte = Mutex<ContinuousClock.Instant?>(nil)
        let failure = await awaiting("the stalled download to fail", within: .seconds(60)) {
            (done: @escaping @Sendable (ContinuousClock.Instant) -> Void) in
            Task { @MainActor in
                let updater = ApplicationsUpdater(replacing: old, signer: Signer(team: "ABCDE12345", identifier: BundleFixture.identifier))
                updater.update(to: release) { event in
                    if event == .failed { done(.now) }
                    _ = updater
                }
                lastByte.withLock { $0 = .now }
                gate.release()
            }
        }
        guard let failedAt = failure else { return }

        let elapsed = failedAt - lastByte.withLock { $0 }!
        #expect(elapsed >= .seconds(30))
        #expect(elapsed <= .seconds(35))
    }
}
