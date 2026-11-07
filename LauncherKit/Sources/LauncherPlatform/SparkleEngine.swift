import Foundation
import LauncherCore

/// `internal import Sparkle` lives in this file and nowhere else. SPUUpdater, SPUUserDriver and SPUUpdaterDelegate are
/// NS_SWIFT_UI_ACTOR, so main-actor classes conform with no escape hatch. The delegate is a private object, held here
/// because SPUUpdater keeps it weakly: a public conformance would put a Sparkle type on LauncherPlatform's surface.
internal import Sparkle

@MainActor public final class SparkleEngine: UpdateEngine {
    public var onEvent: (@MainActor (UpdateEngineEvent) -> Void)?
    private let signer: Signer
    private let driver = SilentUserDriver()
    private let delegate: UpdaterDelegate
    /// Kept only once `start()` succeeded, so a `check()` after a failed start does nothing.
    private var updater: SPUUpdater?

    private let bundle: URL
    /// This process's own build, read at start: after a swap, `Bundle.main` reads the new bundle.
    private let build: String?

    /// Reads the downloads prefix and the build now: after a swap, `Bundle.main` reads the new bundle.
    public init(bundle: URL, signer: Signer) {
        self.signer = signer
        self.bundle = bundle
        let info = Bundle(url: bundle)
        build = info?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let prefix = info?.object(forInfoDictionaryKey: "TLUpdateDownloads") as? String
        delegate = UpdaterDelegate(prefix: prefix, signer: signer)
        delegate.emit = { [weak self] event in self?.onEvent?(event) }
    }

    /// R12's predicate.
    public nonisolated static func canReplace(_ bundle: URL) -> Bool { SparkleInternals.canReplace(bundle) }

    public func start() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .never
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)
        let candidate = SPUUpdater(
            hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: delegate)
        candidate.userAgentString = "TrackpadLauncher"
        candidate.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]
        do {
            try candidate.start()
            updater = candidate
        } catch {
            onEvent?(.cycleEnded(.failed))
        }
    }

    public func check() { updater?.checkForUpdatesInBackground() }

    public func discardHeldUpdate() {
        SparkleInternals.veto(job: SparkleInternals.installerJob(of: signer.identifier), extracted: delegate.found)
        delegate.found = nil
    }

    /// Called in the turn that ends this process: the job outlives it and opens whichever copy /Applications holds.
    public func armRestart() -> Bool {
        guard let build else { return false }
        return LaunchdJob.submit(
            label: "\(signer.identifier).hand-over",
            arguments: LaunchdJob.handOverArguments(
                oldPID: getpid(), bundle: bundle, build: build, allowed: 5, open: "/usr/bin/open"))
    }

    /// nil and SUNoUpdateError are `.nothingNew`; SUDownloadError is `.requestFailed`; everything else `.failed`. Public
    /// codes: every failure of a request, feed or archive, reaches this level wrapped in SUDownloadError.
    nonisolated static func outcome(of error: (any Error)?) -> CycleOutcome {
        guard let error = error as NSError? else { return .nothingNew }
        guard error.domain == SUSparkleErrorDomain else { return .failed }
        switch error.code {
        case Int(SUError.noUpdateError.rawValue): return .nothingNew
        case Int(SUError.downloadError.rawValue): return .requestFailed
        default: return .failed
        }
    }
}

/// Every fact here is Sparkle's private business, proven on `provenOn`. Each names its proof. A test compares
/// `provenOn` with LauncherKit/Package.resolved, so an upgrade cannot land without re-proving this type.
enum SparkleInternals {
    static let provenOn = "2.10.1"

    /// Read-only: bundle writable, parent writable, bundle owned by this user, and its group one of this user's.
    /// Sparkle's rule proves the last two by chowning a temporary file; this creates nothing. A stricter future Sparkle
    /// costs a silent download at each check, never a prompt.
    nonisolated static func canReplace(_ bundle: URL) -> Bool {
        let path = bundle.path
        let parent = bundle.deletingLastPathComponent().path
        guard access(path, W_OK) == 0, access(parent, W_OK) == 0 else { return false }
        var info = stat()
        guard stat(path, &info) == 0, info.st_uid == getuid() else { return false }
        return userGroups().contains(info.st_gid)
    }

    /// `Installation/<random>/<random>/` under Sparkle's cache. nil unless the newest such folder holding `build` holds
    /// exactly one bundle: a logout leaves stale folders, and two bundles cannot be told apart from what Sparkle would
    /// choose. Proof: `selfquit.out` prints the layout.
    nonisolated static func extractedUpdate(identifier: String, build: String, caches: URL) -> URL? {
        let files = FileManager.default
        let root = caches.appending(path: "\(identifier)/org.sparkle-project.Sparkle/Installation")
        func children(_ folder: URL) -> [URL] {
            (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        }
        func bundles(in folder: URL) -> [URL] { children(folder).filter { $0.pathExtension == "app" } }
        func holdsBuild(_ folder: URL) -> Bool {
            bundles(in: folder).contains {
                Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String == build
            }
        }
        let inner = children(root).flatMap { children($0) }.filter(holdsBuild)
        func modified(_ folder: URL) -> Date {
            (try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
        }
        guard let newest = inner.max(by: { modified($0) < modified($1) }) else { return nil }
        let found = bundles(in: newest)
        return found.count == 1 ? found[0] : nil
    }

    /// Removing this job ends the installer; Sparkle then aborts with 4005. Proof: `vetonow.out`, `veto.out`.
    nonisolated static func installerJob(of identifier: String) -> String { "\(identifier)-sparkle-updater" }

    /// Both layers, each whatever the other did: remove the job, then discard the extracted bundle. Takes what it acts
    /// on, so a test can drive either layer alone. Inside the delegate call. Proof: `vetonow.out`, `discardquit.out`.
    nonisolated static func veto(job: String, extracted: URL?) {
        LaunchdJob.remove(label: job)
        if let extracted { BundleInstall.discard(extracted) }
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
    var emit: (@MainActor (UpdateEngineEvent) -> Void)?
    /// The extracted bundle of the held update, until the engine discards it.
    var found: URL?

    init(prefix: String?, signer: Signer) {
        self.prefix = prefix
        self.signer = signer
    }

    /// Runs before any download. Refusing keeps the disk-image key-rotation fallback unreachable, so the update key has
    /// no second door.
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck)
        throws
    {
        guard isPinned(enclosure: updateItem.fileURL, under: prefix) else {
            throw NSError(domain: "TrackpadLauncher.update", code: 1)
        }
    }

    /// Always true. The handler is dropped unused, so Sparkle's relaunch flag can never be set and the only way an
    /// install runs is at the process's end. The check runs here, synchronously on main (18 to 31 ms, once per
    /// release), so no turn exists in which an unchecked update is held. Anything not found or not read is not genuine.
    func updater(
        _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        found = caches.flatMap {
            SparkleInternals.extractedUpdate(identifier: signer.identifier, build: item.versionString, caches: $0)
        }
        let offer = ExpectedUpdate(
            version: item.displayVersionString, build: item.versionString,
            minimumMacOS: item.minimumSystemVersion ?? "")
        let genuine = found.map { CodeSignature.isGenuine($0, as: offer, signer: signer) } ?? false
        emit?(.held(genuine ? .genuine : .notGenuine))
        return true
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        emit?(.cycleEnded(SparkleEngine.outcome(of: error)))
    }
}

/// Required by the initializer; shows nothing.
@MainActor private final class SilentUserDriver: NSObject, SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(
            SUUpdatePermissionResponse(
                automaticUpdateChecks: true, automaticUpdateDownloading: true, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    func showUpdateFound(
        with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void
    ) { reply(.dismiss) }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}
    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() {}
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { reply(.dismiss) }
    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void
    ) {}
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }
    func dismissUpdateInstallation() {}
}
