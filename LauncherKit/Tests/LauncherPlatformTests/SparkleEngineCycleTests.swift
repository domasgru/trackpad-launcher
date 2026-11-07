import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The real `SPUUpdater`, over a throwaway host bundle whose feed lies at a port nothing listens on.
@MainActor @Suite struct SparkleEngineCycleTests {
    private static let key = "pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ="

    private final class Host {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tl-host-\(UUID().uuidString)")
        var bundle: URL { folder.appending(path: "Host.app") }

        init(publicKey: String) throws {
            let contents = bundle.appending(path: "Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let info: [String: Any] = [
                "CFBundleIdentifier": "com.example.enginehost\(UUID().uuidString.prefix(8))",
                "CFBundleName": "Host", "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
                "CFBundlePackageType": "APPL",
                "SUFeedURL": "http://127.0.0.1:\(Host.closedPort())/appcast.xml",
                "SUEnableAutomaticChecks": false, "SUEnableInstallerLauncherService": true,
                "SUPublicEDKey": publicKey,
                "TLUpdateDownloads": "http://127.0.0.1/",
            ]
            try (info as NSDictionary).write(to: contents.appending(path: "Info.plist"))
        }

        deinit { try? FileManager.default.removeItem(at: folder) }

        /// A port that was free a moment ago: bound, read back and closed again.
        static func closedPort() -> UInt16 {
            let descriptor = socket(AF_INET, SOCK_STREAM, 0)
            defer { close(descriptor) }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard bound == 0 else { return 1 }
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
            }
            return UInt16(bigEndian: address.sin_port)
        }
    }

    private static func hop() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    private func answers(
        _ engine: SparkleEngine, after ask: () -> Void
    ) async -> UpdateEngineEvent? {
        await awaiting("the cycle's end") { deliver in
            engine.onEvent = { event in deliver(event) }
            ask()
        }
    }

    @Test func aProbeBuildsOneUpdaterAndDropsItWhenTheFeedRequestFails() async throws {
        let host = try Host(publicKey: Self.key)
        let engine = SparkleEngine(bundle: host.bundle, signer: Signer(team: "TEAM", identifier: "com.example.host"))
        weak var first: AnyObject?

        let event = await answers(engine) {
            engine.probe()
            first = engine.currentUpdater
        }

        #expect(event == .cycleEnded(.requestFailed))
        #expect(engine.currentUpdater == nil)
        await Self.hop()
        #expect(first == nil, "the updater is released once Sparkle's stack has unwound")
    }

    @Test func aSecondProbeBuildsASecondUpdaterAndAnswersAgain() async throws {
        let host = try Host(publicKey: Self.key)
        let engine = SparkleEngine(bundle: host.bundle, signer: Signer(team: "TEAM", identifier: "com.example.host"))
        _ = await answers(engine) { engine.probe() }
        await Self.hop()
        weak var second: AnyObject?

        let event = await answers(engine) {
            engine.probe()
            second = engine.currentUpdater
        }

        #expect(second != nil || event != nil)
        #expect(event == .cycleEnded(.requestFailed))
        await Self.hop()
        #expect(second == nil)
    }

    @Test func anUpdateBehavesTheSameWayAndItsUpdaterIsReleasedAtTheEnd() async throws {
        let host = try Host(publicKey: Self.key)
        let engine = SparkleEngine(bundle: host.bundle, signer: Signer(team: "TEAM", identifier: "com.example.host"))
        weak var updater: AnyObject?
        var alive = false

        let event = await answers(engine) {
            engine.update()
            updater = engine.currentUpdater
            alive = updater != nil
        }

        #expect(alive, "an updater exists while the cycle runs")
        #expect(event == .cycleEnded(.requestFailed))
        await Self.hop()
        #expect(updater == nil)
    }

    @Test func anEmptyKeyEndsTheCycleFailedAtOnceAndLeavesNoUpdater() async throws {
        let host = try Host(publicKey: "")
        let engine = SparkleEngine(bundle: host.bundle, signer: Signer(team: "TEAM", identifier: "com.example.host"))
        var events: [UpdateEngineEvent] = []
        engine.onEvent = { events.append($0) }

        engine.update()
        await Self.hop()

        #expect(events == [.cycleEnded(.failed)])
        #expect(engine.currentUpdater == nil)
    }

    @Test func aHostThatIsNoBundleEndsTheCycleFailed() async throws {
        let engine = SparkleEngine(
            bundle: URL(filePath: "/nonexistent/Host.app"), signer: Signer(team: "TEAM", identifier: "com.example.host"))
        var events: [UpdateEngineEvent] = []
        engine.onEvent = { events.append($0) }

        engine.probe()

        #expect(events == [.cycleEnded(.failed)])
        #expect(engine.currentUpdater == nil)
    }
}
