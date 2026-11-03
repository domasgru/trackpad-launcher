import AppKit
import LauncherCore

/// Replaces the running copy in /Applications with a release, then opens it as a new process. The order of effects is
/// unpack, verify, swap, open, end; the swap is the first change anywhere, so a kill at any instant leaves a whole old
/// or a whole new version, and the administrator prompt comes only after the new version is verified. The archive is
/// held in memory until it has all arrived; nothing of the update is on disk except the staging folder while it unpacks
/// and the installed app.
@MainActor public final class ApplicationsUpdater: UpdateInstaller {
    /// The bundle an update replaces: `Location.running` of an installed copy.
    private let bundle: URL
    private let signer: Signer
    private let administrator: any Administrator
    /// The whole archive, or nil; `GitHubReleases.ArchiveDownload.archive` when shipped.
    typealias Download = @Sendable (Release, @escaping @MainActor (Double) -> Void) async -> Data?
    private let download: Download
    private var job: Task<Void, Never>?
    private var isPastDownload = false
    /// Bumped by every attempt and every cancel: a progress push from an attempt that is no longer live is dropped.
    private var attempt = 0

    public convenience init(replacing bundle: URL, signer: Signer) {
        self.init(
            replacing: bundle, signer: signer, administrator: AuthorizationAdministrator(),
            download: GitHubReleases.ArchiveDownload(stall: 30).archive)
    }

    /// Tests: a temp "Applications", a test administrator, and a download that is either a local listener's
    /// `ArchiveDownload` with a short stall or a function returning the bytes on the test's own signal.
    init(replacing bundle: URL, signer: Signer, administrator: any Administrator, download: @escaping Download) {
        self.bundle = bundle
        self.signer = signer
        self.administrator = administrator
        self.download = download
    }

    public func update(to release: Release, events: @escaping @MainActor (UpdateEvent) -> Void) {
        isPastDownload = false
        attempt += 1
        let mine = attempt
        job = Task {
            let archive = await download(release) { [self] fraction in
                guard attempt == mine else { return }
                events(.progress(fraction))
            }
            guard let archive else {
                if !Task.isCancelled { events(.failed) }
                return
            }
            // One main-actor turn: a cancel either landed before this check (nothing more happens), or finds the
            // install begun.
            guard !Task.isCancelled else { return }
            isPastDownload = true
            events(.downloaded)
            events(await Self.install(archive, as: release, replacing: bundle, signer: signer, by: administrator))
        }
    }

    public func cancelDownload() {
        guard !isPastDownload else { return }
        attempt += 1
        job?.cancel()
    }

    public func openNewVersion(then started: @escaping @MainActor (Bool) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // By default the old process, whose bundle was just replaced, only gets a reopen.
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { app, _ in
            let didStart = app != nil
            DispatchQueue.main.async { MainActor.assumeIsolated { started(didStart) } }
        }
    }

    /// Unpack, verify, swap. Nothing interrupts it. The staging folder is gone on every outcome but `.installed`.
    @concurrent private static func install(
        _ archive: Data, as release: Release, replacing bundle: URL, signer: Signer, by administrator: any Administrator
    ) async -> UpdateEvent {
        let staged: URL
        do { staged = try BundleInstall.unpack(archive, near: bundle) } catch { return .failed }
        guard CodeSignature.isGenuine(staged, as: release, signer: signer) else {
            BundleInstall.discard(staged)
            return .failed
        }
        switch ApplicationsInstaller.put(staged, at: bundle, by: administrator) {
        case .installed: return .installed
        case .cancelled: return .declined
        case .failed: return .failed
        }
    }
}
