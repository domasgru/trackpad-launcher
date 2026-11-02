import Foundation
import LauncherCore

/// The public release list. Every request uses its own ephemeral session (no cookie, cache or credential store, nothing
/// on disk) and HTTPS to GitHub, with no query string and constant headers that name neither the user, the Mac, this
/// version nor macOS, and fails after `stall` seconds in which no byte arrives (the request's own idle timeout: no timer
/// of ours). The one network file.
@MainActor public final class GitHubReleases: ReleaseList {
    nonisolated static let listURL = URL(string: "https://api.github.com/repos/domasgru/trackpad-launcher/releases")!
    nonisolated static let downloadsPrefix = "https://github.com/domasgru/trackpad-launcher/releases/download/"
    nonisolated static let headers = ["User-Agent": "TrackpadLauncher", "Accept-Language": "en", "X-GitHub-Api-Version": "2022-11-28"]
    private let endpoint: URL
    private let stall: TimeInterval

    public convenience init() { self.init(endpoint: Self.listURL, stall: 30) }

    /// Tests: a listener on 127.0.0.1 and a short stall.
    init(endpoint: URL, stall: TimeInterval) {
        self.endpoint = endpoint
        self.stall = stall
    }

    public func fetch(then done: @escaping @MainActor ([Release]) -> Void) {
        let endpoint = endpoint
        let stall = stall
        Task { done(await Self.list(at: endpoint, stall: stall) ?? []) }
    }

    /// nil for any failure: no connection, no answer, a status other than 200, a body that is not a release array.
    @concurrent static func list(at url: URL, stall: TimeInterval) async -> [Release]? {
        let session = session(accept: "application/vnd.github+json", stall: stall)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = stall
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = false
        guard let (data, response) = try? await session.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return parse(data)
    }

    private struct WireRelease: Decodable {
        let draft: Bool?
        let prerelease: Bool?
        let assets: [WireAsset]?
    }

    private struct WireAsset: Decodable {
        let name: String?
        let size: Int?
        let state: String?
        let browser_download_url: String?
    }

    /// The wire half of the newer-version rule, pure: each element that is not a draft and not a pre-release, with an
    /// asset whose `state` is "uploaded", whose `browser_download_url` starts with `downloadsPrefix`, and whose `name`
    /// parses with `archiveName`; the first such asset counts. Tag, title and body are ignored. nil only when the JSON is
    /// not a release array.
    nonisolated static func parse(_ json: Data) -> [Release]? {
        guard let wire = try? JSONDecoder().decode([WireRelease].self, from: json) else { return nil }
        return wire.compactMap { release in
            guard release.draft == false, release.prerelease == false else { return nil }
            return release.assets?.lazy.compactMap(counted).first
        }
    }

    nonisolated private static func counted(_ asset: WireAsset) -> Release? {
        guard asset.state == "uploaded", let name = asset.name, let size = asset.size,
            let address = asset.browser_download_url, address.hasPrefix(downloadsPrefix),
            let archive = URL(string: address), let declared = archiveName(name)
        else { return nil }
        return Release(
            version: declared.version, minimumMacOS: declared.minimumMacOS, archive: archive, archiveSize: size)
    }

    /// "TrackpadLauncher-<version>-macOS-<minimum>.aar", the contract with every shipped version; nil for any other.
    nonisolated static func archiveName(_ name: String) -> (version: Version, minimumMacOS: Version)? {
        let prefix = "TrackpadLauncher-"
        let suffix = ".aar"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix), name.count > prefix.count + suffix.count else { return nil }
        let declared = name.dropFirst(prefix.count).dropLast(suffix.count)
        let pieces = declared.components(separatedBy: "-macOS-")
        guard pieces.count == 2, let version = Version(pieces[0]), let minimum = Version(pieces[1]) else { return nil }
        return (version, minimum)
    }

    /// Ephemeral; cookies off and storage nil; urlCache nil; credential storage nil; reload ignoring caches;
    /// waitsForConnectivity false; timeoutIntervalForRequest = stall; httpAdditionalHeaders = headers + Accept.
    nonisolated private static func session(accept: String, stall: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = stall
        configuration.httpAdditionalHeaders = headers.merging(["Accept": accept]) { _, new in new }
        return URLSession(configuration: configuration)
    }
}
