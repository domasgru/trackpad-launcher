import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The events an update reported, with a way to wait for one.
@MainActor private final class EventLog {
    private(set) var events: [UpdateEvent] = []
    private var waiters: [(check: ([UpdateEvent]) -> Bool, continuation: CheckedContinuation<Void, Never>)] = []

    func record(_ event: UpdateEvent) {
        events.append(event)
        let ready = waiters.filter { $0.check(events) }
        waiters = waiters.filter { !$0.check(events) }
        ready.forEach { $0.continuation.resume() }
    }

    func until(_ check: @escaping ([UpdateEvent]) -> Bool) async {
        if check(events) { return }
        await withCheckedContinuation { waiters.append((check, $0)) }
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

@MainActor @Suite(.timeLimit(.minutes(2))) struct ApplicationsUpdaterTests {
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

        init(administrator: TestAdministrator = TestAdministrator(answer: nil), signer: Signer = ApplicationsUpdaterTests.signer)
            async throws
        {
            fixture = try BundleFixture()
            applications = try fixture.folder("Applications")
            old = try fixture.makeBundle(named: "TrackpadLauncher.app", in: applications, version: "1.0.0")
            oldManifest = try BundleFixture.manifest(of: old)
            server = try await LocalReleaseServer()
            self.administrator = administrator
            updater = ApplicationsUpdater(
                replacing: old, signer: signer, administrator: administrator,
                download: GitHubReleases.ArchiveDownload(stall: 1).archive)
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

        func expectOldBundleUntouched() throws {
            #expect(try BundleFixture.manifest(of: old) == oldManifest)
            #expect(try BundleFixture.appNames(in: applications) == ["TrackpadLauncher.app"])
            #expect(administrator.calls.isEmpty)
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
        rig.server.script(
            Self.archivePath, .stream(length: junk.count, chunks: Self.quarters(of: junk), gate: gate))

        rig.update(size: junk.count)
        for quarter in [0.25, 0.5, 0.75, 1.0] {
            gate.release()
            await rig.log.until { events in events.contains(.progress(quarter)) }
        }
        await rig.log.until { $0.contains(.failed) }

        let progress = rig.log.progress
        #expect(progress == progress.sorted() && Set(progress).count == progress.count)
        #expect(progress.allSatisfy { ($0 * 100).rounded() == $0 * 100 })
        #expect(progress.last == 1.0)
        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.log.followsTheContract)
        try rig.expectOldBundleUntouched()
    }

    @Test func anArchiveThatIsNotGenuineIsRefusedBeforeAnyPromptEvenWhereThePromptWouldBeNeeded() async throws {
        let rig = try await Rig(administrator: .refusing)
        defer { rig.server.stop() }
        let release = try rig.fixture.folder("Release")
        try rig.fixture.makeBundle(named: "TrackpadLauncher.app", in: release, version: "1.1.0")
        let archive = try BundleFixture.archive("TrackpadLauncher.app", in: release)
        rig.server.script(Self.archivePath, .respond(status: 200, body: archive))
        chmod(rig.applications.path, 0o555)

        rig.update(size: archive.count)
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.events.suffix(2) == [.downloaded, .failed])
        #expect(rig.log.followsTheContract)
        try rig.expectOldBundleUntouched()
    }

    @Test(arguments: [3999, 4001])
    func aBodyOfTheWrongLengthFailsWithoutEverReportingTheDownloaded(size: Int) async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        rig.server.script(Self.archivePath, .respond(status: 200, body: Data(repeating: 7, count: 4000)))

        rig.update(size: size)
        await rig.log.until { $0.contains(.failed) }

        #expect(!rig.log.events.contains(.downloaded))
        #expect(rig.log.followsTheContract)
        try rig.expectOldBundleUntouched()
    }

    @Test func aBodyCutShortFails() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let gate = LocalReleaseServer.ChunkGate()
        rig.server.script(Self.archivePath, .stream(length: 4000, chunks: [Data(repeating: 7, count: 1000)], gate: gate))

        rig.update(size: 4000)
        gate.release()
        await rig.log.until { $0.contains(.failed) }

        #expect(!rig.log.events.contains(.downloaded))
        try rig.expectOldBundleUntouched()
    }

    @Test(arguments: [404, 500])
    func aStatusOtherThan200Fails(status: Int) async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        rig.server.script(Self.archivePath, .respond(status: status, body: Data(repeating: 7, count: 4000)))

        rig.update(size: 4000)
        await rig.log.until { $0.contains(.failed) }

        #expect(rig.log.events == [.failed])
        try rig.expectOldBundleUntouched()
    }

    @Test func aServerThatStopsSendingFailsAfterTheStall() async throws {
        let rig = try await Rig()
        defer { rig.server.stop() }
        let gate = LocalReleaseServer.ChunkGate()
        rig.server.script(Self.archivePath, .stream(length: 4000, chunks: [Data(repeating: 7, count: 1000), Data(repeating: 7, count: 3000)], gate: gate))

        let started = ContinuousClock.now
        rig.update(size: 4000)
        gate.release()
        await rig.log.until { $0.contains(.failed) }

        #expect(ContinuousClock.now - started >= .milliseconds(950))
        #expect(!rig.log.events.contains(.downloaded))
        try rig.expectOldBundleUntouched()
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
        try rig.expectOldBundleUntouched()
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
            rig.server.script(Self.archivePath, .stream(length: archive.count, chunks: Self.quarters(of: archive), gate: gate))
            let offered = Release(
                version: Version(record.version)!, minimumMacOS: Version(record.minimumMacOS)!,
                archive: rig.server.url(path: Self.archivePath), archiveSize: archive.count)
            let log = rig.log
            rig.updater.update(to: offered) { log.record($0) }

            for _ in 0..<4 { gate.release() }
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
}
