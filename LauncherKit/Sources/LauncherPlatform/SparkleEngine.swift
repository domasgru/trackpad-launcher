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

    /// Reads the downloads prefix now: after a swap, `Bundle.main` reads the new bundle.
    public init(bundle: URL, signer: Signer) {
        self.signer = signer
        let prefix = Bundle(url: bundle)?.object(forInfoDictionaryKey: "TLUpdateDownloads") as? String
        delegate = UpdaterDelegate(prefix: prefix)
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

    public func discardHeldUpdate() {}

    public func armRestart() -> Bool { false }

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
    var emit: (@MainActor (UpdateEngineEvent) -> Void)?

    init(prefix: String?) { self.prefix = prefix }

    /// Runs before any download. Refusing keeps the disk-image key-rotation fallback unreachable, so the update key has
    /// no second door.
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck)
        throws
    {
        guard isPinned(enclosure: updateItem.fileURL, under: prefix) else {
            throw NSError(domain: "TrackpadLauncher.update", code: 1)
        }
    }

    /// Always true and the handler dropped unused, so Sparkle's relaunch flag can never be set and the only way an
    /// install runs is at the process's end.
    func updater(
        _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        emit?(.held(.genuine))
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
