import Foundation
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

/// A tiny HTTP server on 127.0.0.1: serves one appcast, answers 404 to everything else, and records each path asked for.
private final class FeedServer: Sendable {
    let port: UInt16
    private let descriptor: Int32
    private final class Requests: Sendable { let paths = Mutex<[String]>([]) }
    private let requested = Requests()

    var paths: [String] { requested.paths.withLock { $0 } }

    init(appcast: @escaping @Sendable (UInt16) -> String) throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, size) }
        }
        guard bound == 0, listen(listener, 8) == 0 else { throw CocoaError(.fileWriteUnknown) }
        var length = size
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        descriptor = listener
        port = UInt16(bigEndian: address.sin_port)
        let port = port
        let requested = requested
        Thread.detachNewThread {
            while true {
                let client = accept(listener, nil, nil)
                if client < 0 { return }
                var buffer = [UInt8](repeating: 0, count: 8192)
                let count = recv(client, &buffer, buffer.count, 0)
                let request = String(decoding: buffer.prefix(max(count, 0)), as: UTF8.self)
                let path = request.split(separator: " ", maxSplits: 2).dropFirst().first.map(String.init) ?? ""
                requested.paths.withLock { $0.append(path) }
                let found = path == "/appcast.xml"
                let body = found ? appcast(port) : ""
                let head =
                    "HTTP/1.1 \(found ? "200 OK" : "404 Not Found")\r\nContent-Type: application/xml\r\n"
                    + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
                let reply = Array((head + body).utf8)
                _ = send(client, reply, reply.count, 0)
                close(client)
            }
        }
    }

    deinit {
        shutdown(descriptor, SHUT_RDWR)
        close(descriptor)
    }
}

/// The real `SPUUpdater` over a throwaway host at build 1, whose feed lists build 2 ("1.1.23") on a loopback server.
@MainActor @Suite struct SparkleEngineFeedTests {
    private nonisolated static let key = "pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ="

    private nonisolated static func appcast(port: UInt16) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
        <channel><title>Feed</title><item>
        <title>1.1.23</title>
        <sparkle:version>2</sparkle:version>
        <sparkle:shortVersionString>1.1.23</sparkle:shortVersionString>
        <enclosure url="http://127.0.0.1:\(port)/downloads/Host-2.aar" length="1000" type="application/octet-stream"
          sparkle:edSignature="\(String(repeating: "A", count: 86))=="/>
        </item></channel></rss>
        """
    }

    private final class Host {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tl-feedhost-\(UUID().uuidString)")
        let identifier = "com.example.feedhost\(UUID().uuidString.prefix(8))"
        var bundle: URL { folder.appending(path: "Host.app") }

        init(port: UInt16) throws {
            let contents = bundle.appending(path: "Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let info: [String: Any] = [
                "CFBundleIdentifier": identifier, "CFBundleName": "Host", "CFBundleVersion": "1",
                "CFBundleShortVersionString": "1.0", "CFBundlePackageType": "APPL",
                "SUFeedURL": "http://127.0.0.1:\(port)/appcast.xml",
                "SUEnableAutomaticChecks": false, "SUEnableInstallerLauncherService": true,
                "SUPublicEDKey": SparkleEngineFeedTests.key,
                "TLUpdateDownloads": "http://127.0.0.1:\(port)/downloads/",
            ]
            try (info as NSDictionary).write(to: contents.appending(path: "Info.plist"))
        }

        deinit {
            UserDefaults.standard.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private final class Model {
        private(set) var questions: [AppVersion] = []
        let answer: Bool

        init(answer: Bool) { self.answer = answer }

        func ask(_ version: AppVersion) -> Bool {
            questions.append(version)
            return answer
        }
    }

    private struct Setup {
        let server: FeedServer
        let host: Host
        let engine: SparkleEngine
    }

    private func setup() throws -> Setup {
        let server = try FeedServer { Self.appcast(port: $0) }
        let host = try Host(port: server.port)
        let engine = SparkleEngine(bundle: host.bundle, signer: Signer(team: "TEAM", identifier: "com.example.host"))
        return Setup(server: server, host: host, engine: engine)
    }

    private func cycle(_ engine: SparkleEngine, after ask: () -> Void) async -> UpdateEngineEvent? {
        await awaiting("the cycle's end") { deliver in
            engine.onEvent = { event in deliver(event) }
            ask()
        }
    }

    @Test func aProbeThatFindsTheVersionAsksNothingAndRequestsNoEnclosure() async throws {
        let setup = try setup()
        let model = Model(answer: true)
        setup.engine.shouldDownload = { model.ask($0) }

        let event = await cycle(setup.engine) { setup.engine.probe() }

        #expect(event == .cycleEnded(.found(AppVersion("1.1.23"))))
        #expect(model.questions.isEmpty)
        #expect(setup.server.paths == ["/appcast.xml"])
    }

    @Test func anUpdateTheModelDeclinesDownloadsNothingAndSkipsNoVersion() async throws {
        let setup = try setup()
        let model = Model(answer: false)
        setup.engine.shouldDownload = { model.ask($0) }

        let event = await cycle(setup.engine) { setup.engine.update() }

        #expect(event != nil)
        #expect(model.questions == [AppVersion("1.1.23")])
        #expect(!setup.server.paths.contains { $0.hasPrefix("/downloads/") })
        let defaults = UserDefaults(suiteName: setup.host.identifier)
        #expect(defaults?.object(forKey: "SUSkippedVersion") == nil)
        #expect(UserDefaults.standard.object(forKey: "SUSkippedVersion") == nil)

        _ = await cycle(setup.engine) { setup.engine.update() }

        #expect(model.questions == [AppVersion("1.1.23"), AppVersion("1.1.23")])
        #expect(!setup.server.paths.contains { $0.hasPrefix("/downloads/") })
    }

    @Test func anUpdateTheModelAcceptsRequestsTheEnclosureAndEndsFailedWhenItIsNotThere() async throws {
        let setup = try setup()
        let model = Model(answer: true)
        setup.engine.shouldDownload = { model.ask($0) }

        let event = await cycle(setup.engine) { setup.engine.update() }

        #expect(event == .cycleEnded(.failed))
        #expect(model.questions == [AppVersion("1.1.23")])
        #expect(setup.server.paths.contains("/downloads/Host-2.aar"))
    }
}
