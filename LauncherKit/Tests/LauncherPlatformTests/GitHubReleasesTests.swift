import Foundation
import LauncherCore
import Network
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct GitHubReleasesTests {
    private static let listPath = "/repos/domasgru/trackpad-launcher/releases"
    private static let downloads = "https://github.com/domasgru/trackpad-launcher/releases/download"

    @MainActor private final class Answers {
        var count = 0
    }

    /// The list `done` was first given, and how many times `done` ran once the main actor had turns to spare.
    private static func fetch(_ releases: GitHubReleases) async -> (list: [Release], answers: Int) {
        let answers = Answers()
        let list: [Release] = await withCheckedContinuation { continuation in
            releases.fetch { list in
                answers.count += 1
                if answers.count == 1 { continuation.resume(returning: list) }
            }
        }
        for _ in 0..<20 { await Task.yield() }
        return (list, answers.count)
    }

    private static func asset(_ name: String, state: String = "uploaded", size: Int = 4_000_000, base: String? = nil) -> String {
        let tag = "v1"
        return """
            {"name": "\(name)", "size": \(size), "state": "\(state)", "content_type": "application/octet-stream",
             "browser_download_url": "\(base ?? downloads)/\(tag)/\(name)"}
            """
    }

    private static func release(
        tag: String, draft: Bool = false, prerelease: Bool = false, assets: [String]
    ) -> String {
        """
        {"url": "https://api.github.com/repos/domasgru/trackpad-launcher/releases/1", "tag_name": "\(tag)",
         "name": "Release \(tag)", "body": "notes", "draft": \(draft), "prerelease": \(prerelease),
         "assets": [\(assets.joined(separator: ","))]}
        """
    }

    private static func serving(_ body: String, status: Int = 200) async throws -> (LocalReleaseServer, GitHubReleases) {
        let server = try await LocalReleaseServer()
        server.script(listPath, .respond(status: status, body: Data(body.utf8)))
        return (server, GitHubReleases(endpoint: server.url(path: listPath), stall: 5))
    }

    @Test func onlyAPublishedFullReleaseWithAWellNamedUploadedArchiveFromThisRepositoryCounts() async throws {
        let dmg = Self.asset("TrackpadLauncher-1.1.0.dmg", size: 9_000_000)
        let json = "["
            + [
                Self.release(
                    tag: "v1.1.0", assets: [dmg, Self.asset("TrackpadLauncher-1.1.0-macOS-26.0.aar", size: 4_321_000)]),
                Self.release(tag: "v1.3.0", draft: true, assets: [Self.asset("TrackpadLauncher-1.3.0-macOS-26.0.aar")]),
                Self.release(
                    tag: "v1.1.0-beta", prerelease: true,
                    assets: [Self.asset("TrackpadLauncher-1.1.0-beta-macOS-26.0.aar")]),
                Self.release(tag: "v1.2.0", assets: [Self.asset("TrackpadLauncher-1.2.0-beta-macOS-26.0.aar")]),
                Self.release(tag: "v1.2.1", assets: [Self.asset("TrackpadLauncher-1.2.1.dmg")]),
                Self.release(tag: "v1.4.0", assets: [Self.asset("TrackpadLauncher-1.4.0.aar")]),
                Self.release(
                    tag: "v1.7.0", assets: [Self.asset("TrackpadLauncher-1.7.0-macOS-26.0.aar", state: "open")]),
                Self.release(
                    tag: "v1.8.0",
                    assets: [
                        Self.asset(
                            "TrackpadLauncher-1.8.0-macOS-26.0.aar",
                            base: "https://github.com/someone-else/trackpad-launcher/releases/download")
                    ]),
                Self.release(tag: "v1.5.0", assets: [Self.asset("TrackpadLauncher-v1.5.0-macOS-26.0.aar")]),
                Self.release(tag: "v1.1234567890.0", assets: [Self.asset("TrackpadLauncher-1.1234567890.0-macOS-26.0.aar")]),
                Self.release(tag: "v1.123456789.0", assets: [Self.asset("TrackpadLauncher-1.123456789.0-macOS-26.0.aar", size: 7)]),
                Self.release(tag: "v9.9.9", assets: [Self.asset("TrackpadLauncher-1.6.0-macOS-26.0.aar", size: 8)]),
            ].joined(separator: ",") + "]"
        let (server, releases) = try await Self.serving(json)
        defer { server.stop() }

        let (list, answers) = await Self.fetch(releases)

        #expect(
            list == [
                Release(
                    version: Version(1, 1, 0), minimumMacOS: Version(26, 0),
                    archive: URL(string: "\(Self.downloads)/v1/TrackpadLauncher-1.1.0-macOS-26.0.aar")!,
                    archiveSize: 4_321_000),
                Release(
                    version: Version(1, 123_456_789, 0), minimumMacOS: Version(26, 0),
                    archive: URL(string: "\(Self.downloads)/v1/TrackpadLauncher-1.123456789.0-macOS-26.0.aar")!,
                    archiveSize: 7),
                Release(
                    version: Version(1, 6, 0), minimumMacOS: Version(26, 0),
                    archive: URL(string: "\(Self.downloads)/v1/TrackpadLauncher-1.6.0-macOS-26.0.aar")!,
                    archiveSize: 8),
            ])
        #expect(answers == 1)
    }

    @Test func everyCheckSendsTheSameConstantRequestAndStoresNothingTheServerOffers() async throws {
        let server = try await LocalReleaseServer()
        defer { server.stop() }
        server.script(
            Self.listPath,
            .respond(
                status: 200,
                headers: [
                    "Set-Cookie": "session=abc; Max-Age=3600", "Cache-Control": "max-age=3600", "ETag": "\"abc123\"",
                    "Last-Modified": "Wed, 21 Oct 2026 07:28:00 GMT",
                ],
                body: Data("[]".utf8)))
        let releases = GitHubReleases(endpoint: server.url(path: Self.listPath), stall: 5)

        _ = await Self.fetch(releases)
        _ = await Self.fetch(releases)

        let requests = server.requests
        #expect(requests.count == 2)
        #expect(requests.first == requests.last)
        for request in requests {
            #expect(request.line == "GET \(Self.listPath) HTTP/1.1")
            #expect(request.body.isEmpty)
            let named = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.name.lowercased(), $0.value) })
            #expect(named.count == request.headers.count)
            let constant = named.filter { !["host", "accept-encoding", "connection", "cache-control"].contains($0.key) }
            #expect(
                constant == [
                    "user-agent": "TrackpadLauncher", "accept-language": "en", "accept": "application/vnd.github+json",
                    "x-github-api-version": "2022-11-28",
                ])
            #expect(named["host"] != nil)
            #expect(named["cache-control"] == "no-cache")
            #expect(named["cookie"] == nil && named["if-none-match"] == nil && named["if-modified-since"] == nil)
        }
    }

    @Test func aFailedRequestAnswersNothingAtOnce() async throws {
        let silent = try await LocalReleaseServer()
        let closedPort = silent.port
        silent.stop()
        try await Task.sleep(for: .milliseconds(100))
        let nothingListening = GitHubReleases(endpoint: URL(string: "http://127.0.0.1:\(closedPort)\(Self.listPath)")!, stall: 5)

        let started = ContinuousClock.now
        let (list, answers) = await Self.fetch(nothingListening)

        #expect(list.isEmpty)
        #expect(answers == 1)
        #expect(ContinuousClock.now - started < .seconds(4))
    }

    @Test(arguments: [
        (403, "[]"), (404, "[]"), (500, "[]"), (200, "this is not json"), (200, "{\"message\": \"Not Found\"}"),
    ])
    func aStatusOrBodyThatIsNotTheListAnswersNothing(status: Int, body: String) async throws {
        let (server, releases) = try await Self.serving(body, status: status)
        defer { server.stop() }

        let (list, answers) = await Self.fetch(releases)

        #expect(list.isEmpty)
        #expect(answers == 1)
        #expect(server.requests.count == 1)
    }

    @Test func aServerThatNeverAnswersGivesUpAfterTheStall() async throws {
        let server = try await LocalReleaseServer()
        defer { server.stop() }
        server.script(Self.listPath, .neverAnswer)
        let releases = GitHubReleases(endpoint: server.url(path: Self.listPath), stall: 1)

        let started = ContinuousClock.now
        let (list, answers) = await Self.fetch(releases)
        let elapsed = ContinuousClock.now - started

        #expect(list.isEmpty)
        #expect(answers == 1)
        #expect(elapsed >= .milliseconds(950))
    }
}
