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
        guard let (data, response) = try? await session.data(for: request(for: url, stall: stall)),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return parse(data)
    }

    /// The download half, used by `ApplicationsUpdater`, kept here so the network API has one file. The archive is
    /// received into memory: nothing is written until all of it has arrived, so a cancel, a quit, a crash or a logout
    /// mid-download leaves nothing on disk. The request carries the same constant headers as the list's, with
    /// `Accept: application/octet-stream`, across the one redirect to the release assets' host.
    struct ArchiveDownload: Sendable {
        /// Seconds with no byte after which the request fails (the request's own idle timeout).
        let stall: TimeInterval

        /// The whole archive, exactly `release.archiveSize` bytes, or nil (failed, stalled, cancelled, wrong length).
        /// `progress` runs on the main actor, in whole percents of `archiveSize`, in order, and has run for every
        /// percent reached by the time this returns. Cancelling the calling task cancels the request.
        @concurrent func archive(of release: Release, progress: @escaping @MainActor (Double) -> Void) async -> Data? {
            let session = GitHubReleases.session(accept: "application/octet-stream", stall: stall)
            defer { session.finishTasksAndInvalidate() }
            let request = GitHubReleases.request(for: release.archive, stall: stall)

            let (percents, push) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .unbounded)
            let reporter = Task { @MainActor in
                for await percent in percents { progress(Double(percent) / 100) }
            }
            let watcher = ByteWatcher(total: release.archiveSize, push: push)
            let received = try? await session.data(for: request, delegate: watcher)
            push.finish()
            await reporter.value

            guard let (data, response) = received, (response as? HTTPURLResponse)?.statusCode == 200,
                data.count == release.archiveSize
            else { return nil }
            return data
        }
    }

    /// Pushes each whole percent of the declared size the task has received, and cancels the task once more than that
    /// arrives. Observes the task's byte count by KVO, so every push is the system's own.
    private final class ByteWatcher: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let total: Int
        private let push: AsyncStream<Int>.Continuation
        private let lock = NSLock()
        private var observation: NSKeyValueObservation?
        private var lastPercent = 0

        init(total: Int, push: AsyncStream<Int>.Continuation) {
            self.total = total
            self.push = push
        }

        func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
            let observation = task.observe(\.countOfBytesReceived, options: [.new]) { [self] task, _ in
                received(Int(task.countOfBytesReceived), by: task)
            }
            lock.lock()
            self.observation = observation
            lock.unlock()
        }

        private func received(_ bytes: Int, by task: URLSessionTask) {
            // Only the archive's own bytes count: an error page's body is not progress.
            guard (task.response as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard bytes <= total else { return task.cancel() }
            let percent = total > 0 ? bytes * 100 / total : 0
            lock.lock()
            defer { lock.unlock() }
            guard percent > lastPercent else { return }
            lastPercent = percent
            push.yield(percent)
        }
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

    /// A plain GET with no cookie, no cache and `stall` as its idle timeout.
    nonisolated private static func request(for url: URL, stall: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = stall
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = false
        return request
    }
}
