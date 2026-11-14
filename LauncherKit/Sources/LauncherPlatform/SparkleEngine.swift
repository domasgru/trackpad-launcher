import Foundation
import LauncherCore

/// `internal import Sparkle` lives in this file and nowhere else. SPUUpdater, SPUUserDriver and SPUUpdaterDelegate are
/// NS_SWIFT_UI_ACTOR, so main-actor classes conform with no escape hatch. The delegate and the user driver are private
/// objects, held here because SPUUpdater keeps its delegate weakly: a public conformance would put a Sparkle type on
/// LauncherPlatform's surface.
internal import Sparkle

/// One `SPUUpdater` per cycle, dropped inside `didFinishUpdateCycle` so it dies when Sparkle's own stack unwinds. Between
/// cycles the engine holds a delegate and a user driver and nothing else, and no schedule exists.
@MainActor public final class SparkleEngine: UpdateEngine {
    public var onEvent: (@MainActor (UpdateEngineEvent) -> Void)?
    public var shouldDownload: (@MainActor (AppVersion) -> Bool)?
    private let signer: Signer
    private let driver = UpdateUserDriver()
    private let delegate: UpdaterDelegate
    private var updater: SPUUpdater?
    private var kind = CycleKind.probe
    /// Sparkle's reply to `showReady`, kept while a genuine update is held. Never called when the process ends.
    private var held: ((SPUUserUpdateChoice) -> Void)?

    private let bundle: URL
    private let host: Bundle?
    /// This process's own build, read at start: after a swap, `Bundle.main` reads the new bundle.
    private let build: String?

    /// Reads the downloads prefix and the build now: after a swap, `Bundle.main` reads the new bundle. `bundle` is the
    /// host every updater is built for.
    public init(bundle: URL, signer: Signer) {
        self.signer = signer
        self.bundle = bundle
        host = Bundle(url: bundle)
        build = host?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let prefix = host?.object(forInfoDictionaryKey: "TLUpdateDownloads") as? String
        delegate = UpdaterDelegate(
            prefix: prefix, signer: signer, identifier: host?.bundleIdentifier ?? signer.identifier)
        delegate.finished = { [weak self] updater, error in self?.cycleFinished(updater, error) }
        driver.ready = { [weak self] reply in self?.ready(reply) }
        driver.offered = { [weak self] version, stage in
            UpdateOffer.reply(for: stage, version: version, asking: self?.shouldDownload)
        }
    }

    /// The read-only mirror of Sparkle's rule that a user can replace the bundle. Where a temporary failure makes the
    /// two disagree, the launcher service shows the system's prompt once, in its own process, and a cancel ends the
    /// cycle `.failed`.
    public nonisolated static func canReplace(_ bundle: URL) -> Bool { SparkleInternals.canReplace(bundle) }

    /// For tests only: the updater of the cycle that runs, nil between cycles.
    var currentUpdater: AnyObject? { updater }

    public func probe() { begin(.probe) }

    public func update() { begin(.update) }

    /// Replies *skip*, which cancels the installer in either launchd domain; Sparkle's cycle then ends. A *dismiss*
    /// would refuse nothing: the update may still install at the application's end.
    public func discardHeldUpdate() {
        guard let reply = held else { return }
        held = nil
        reply(.skip)
    }

    /// Called in the turn that ends this process: the job outlives it and opens whichever copy /Applications holds.
    public func armRestart(opensWindow: Bool) -> Bool {
        guard let build else { return false }
        return LaunchdJob.submit(
            label: "\(signer.identifier).hand-over",
            arguments: LaunchdJob.handOverArguments(
                oldPID: getpid(), bundle: bundle, build: build, allowed: 5, open: "/usr/bin/open",
                withWindow: opensWindow))
    }

    private func begin(_ cycle: CycleKind) {
        guard updater == nil else { return }
        HTTPCookieStorage.shared.cookieAcceptPolicy = .never
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)
        guard let host else {
            onEvent?(.cycleEnded(.failed))
            return
        }
        kind = cycle
        delegate.beginCycle()
        let candidate = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: delegate)
        candidate.userAgentString = "TrackpadApp"
        candidate.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]
        do {
            try candidate.start()
        } catch {
            onEvent?(.cycleEnded(.failed))
            return
        }
        updater = candidate
        switch cycle {
        case .probe: candidate.checkForUpdateInformation()
        case .update: candidate.checkForUpdates()
        }
    }

    /// The reference goes before the event, so the answer may start the next cycle.
    private func cycleFinished(_ finished: SPUUpdater, _ error: (any Error)?) {
        guard finished === updater else { return }
        let outcome = Self.outcome(of: error, kind: kind, feedRead: delegate.feedRead, found: delegate.found)
        updater = nil
        held = nil
        onEvent?(.cycleEnded(outcome))
    }

    private func ready(_ reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard delegate.genuine else {
            reply(.skip)
            return
        }
        held = reply
        onEvent?(.held)
    }

    /// Public codes of Sparkle's error domain: every failure of a request, feed or archive, reaches this level wrapped in
    /// SUDownloadError, so `feedRead` tells the feed's from the archive's.
    nonisolated static func outcome(
        of error: (any Error)?, kind: CycleKind, feedRead: Bool, found: AppVersion?
    ) -> CycleOutcome {
        let code = (error as NSError?).flatMap { $0.domain == SUSparkleErrorDomain ? $0.code : nil }
        switch kind {
        case .probe:
            if error == nil { return found.map { .found($0) } ?? .nothingNew }
            switch code {
            case Int(SUError.noUpdateError.rawValue): return .nothingNew
            case Int(SUError.downloadError.rawValue): return .requestFailed
            default: return .failed
            }
        case .update:
            switch code {
            case Int(SUError.noUpdateError.rawValue): return .nothingNew
            case Int(SUError.downloadError.rawValue) where !feedRead: return .requestFailed
            default: return .failed
            }
        }
    }
}

enum CycleKind: Equatable { case probe, update }

/// What the offer's stage and the model's answer say to reply, as a value a test can call: Sparkle's own
/// `SPUUserUpdateStage` mirrored.
enum UpdateOffer {
    enum Stage: Sendable { case notDownloaded, downloaded, installing }
    enum Reply: Sendable { case install, dismiss, skip }

    /// An installer already running can only follow a crash, and an *install* would send Sparkle's own relaunch: it is
    /// skipped, and the model is never asked. Otherwise the model is asked once: *dismiss* when it declines or nobody
    /// listens, which downloads nothing and remembers nothing, where *skip* would remember the version.
    @MainActor static func reply(
        for stage: Stage, version: AppVersion, asking shouldDownload: (@MainActor (AppVersion) -> Bool)?
    ) -> Reply {
        switch stage {
        case .installing: .skip
        case .notDownloaded, .downloaded: shouldDownload?(version) == true ? .install : .dismiss
        }
    }

    fileprivate static func stage(of stage: SPUUserUpdateStage) -> Stage {
        switch stage {
        case .notDownloaded: .notDownloaded
        case .downloaded: .downloaded
        case .installing: .installing
        @unknown default: .installing
        }
    }
}

/// Every fact here is Sparkle's private business, proven on `provenOn`. Each names its proof. A test compares
/// `provenOn` with the vendored manifest, so an upgrade cannot land without re-proving this type.
enum SparkleInternals {
    static let provenOn = "2.10.1"

    /// Read-only: bundle writable, parent writable, bundle owned by this user, and its group one of this user's.
    /// Sparkle's rule proves the last two by chowning a temporary file; this creates nothing.
    nonisolated static func canReplace(_ bundle: URL) -> Bool {
        let path = bundle.path
        let parent = bundle.deletingLastPathComponent().path
        guard access(path, W_OK) == 0, access(parent, W_OK) == 0 else { return false }
        var info = stat()
        guard stat(path, &info) == 0, info.st_uid == getuid() else { return false }
        return userGroups().contains(info.st_gid)
    }

    nonisolated static func persistentDownloads(identifier: String, caches: URL) -> URL {
        caches.appending(path: "\(identifier)/org.sparkle-project.Sparkle/PersistentDownloads")
    }

    /// `PersistentDownloads/<random>/<host name> <build>/<file>` under Sparkle's cache for the host. The newest random
    /// folder holding a folder named for `build` holds the downloaded archive; nil unless that folder holds exactly one
    /// file. Proof: `SPUDownloader.m` (`rootPersistentDownloadCachePath`, `downloaderDidFinishWithTemporaryDownloadData`)
    /// and `SPUDownloadDriver.m` (`desiredFilename`).
    nonisolated static func persistentDownload(identifier: String, build: String, caches: URL) -> URL? {
        let files = FileManager.default
        let root = persistentDownloads(identifier: identifier, caches: caches)
        func children(_ folder: URL) -> [URL] {
            (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        }
        func modified(_ folder: URL) -> Date {
            (try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
        }
        func archive(in random: URL) -> URL? {
            let named = children(random).filter { $0.lastPathComponent.hasSuffix(" \(build)") }
            guard named.count == 1 else { return nil }
            let inside = children(named[0])
            return inside.count == 1 && inside[0].pathExtension == "aar" ? inside[0] : nil
        }
        return children(root).sorted { modified($0) > modified($1) }.lazy.compactMap(archive).first
    }

    private nonisolated static func userGroups() -> Set<gid_t> {
        var groups = Set([getgid(), getegid()])
        let count = getgroups(0, nil)
        guard count > 0 else { return groups }
        var buffer = [gid_t](repeating: 0, count: Int(count))
        let filled = getgroups(count, &buffer)
        if filled > 0 { groups.formUnion(buffer.prefix(Int(filled))) }
        return groups
    }
}

/// Under `prefix`, ending in `.aar`, with no `..`. A missing prefix admits nothing. The prefix is the Info.plist key
/// `TLUpdateDownloads`, so no address exists in Swift and a local server can stand in for GitHub; that the shipped key
/// is `https` is the scan's rule, `alwaysDeclared`, not this function's.
func isPinned(enclosure: URL?, under prefix: String?) -> Bool {
    guard let enclosure, let prefix, !prefix.isEmpty else { return false }
    let whole = enclosure.absoluteString
    guard whole.hasPrefix(prefix), enclosure.path.hasSuffix(".aar") else { return false }
    let lowered = whole.lowercased()
    return !lowered.contains("..") && !lowered.contains("%2e")
}

@MainActor private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let prefix: String?
    private let signer: Signer
    private let identifier: String
    var finished: ((SPUUpdater, (any Error)?) -> Void)?
    /// The facts of the cycle that runs.
    private(set) var feedRead = false
    private(set) var found: AppVersion?
    private(set) var genuine = false
    private var offer: ExpectedUpdate?

    init(prefix: String?, signer: Signer, identifier: String) {
        self.prefix = prefix
        self.signer = signer
        self.identifier = identifier
    }

    func beginCycle() {
        feedRead = false
        found = nil
        genuine = false
        offer = nil
    }

    /// Runs before any download. Refusing keeps the disk-image key-rotation fallback unreachable, so the update key has
    /// no second door.
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck)
        throws
    {
        guard isPinned(enclosure: updateItem.fileURL, under: prefix) else {
            throw NSError(domain: "TrackpadApp.update", code: 1)
        }
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) { feedRead = true }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        found = AppVersion(item.displayVersionString)
        offer = ExpectedUpdate(
            version: item.displayVersionString, build: item.versionString,
            minimumMacOS: item.minimumSystemVersion ?? "")
    }

    /// After the download and before any installer exists. The check runs here, synchronously on main (18 to 31 ms, once
    /// per release), so no turn exists in which an unchecked update is held: a refused archive is removed, which makes
    /// Sparkle's own extraction fail. Anything not found or not read is not genuine.
    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let archive = caches.flatMap {
            SparkleInternals.persistentDownload(identifier: identifier, build: item.versionString, caches: $0)
        }
        genuine = false
        guard let archive, let offer else {
            if let caches {
                UpdateArchive.discard(downloads: SparkleInternals.persistentDownloads(identifier: identifier, caches: caches))
            }
            return
        }
        genuine = UpdateArchive.admit(archive, as: offer, signer: signer)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        finished?(updater, error)
    }
}

/// Shows nothing and answers every question the same way each time. Sparkle's UI is not built into the vendored copy.
@MainActor private final class UpdateUserDriver: NSObject, SPUUserDriver {
    var ready: ((@escaping (SPUUserUpdateChoice) -> Void) -> Void)?
    var offered: ((AppVersion, UpdateOffer.Stage) -> UpdateOffer.Reply)?

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(
            SUUpdatePermissionResponse(
                automaticUpdateChecks: false, automaticUpdateDownloading: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    func showUpdateFound(
        with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let stage = UpdateOffer.stage(of: state.stage)
        let version = AppVersion(appcastItem.displayVersionString)
        switch offered?(version, stage) ?? .dismiss {
        case .install: reply(.install)
        case .dismiss: reply(.dismiss)
        case .skip: reply(.skip)
        }
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}
    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() {}
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { ready?(reply) }
    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void
    ) {}
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }
    func dismissUpdateInstallation() {}
}
