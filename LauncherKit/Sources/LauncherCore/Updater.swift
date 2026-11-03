import Foundation
import Observation

/// The update model, beside `Lifecycle` and `Launcher`. It exists only where an update check is allowed (see
/// `InstalledRelease`). It owns every update decision: the check each opening makes and dropping a stale one, choosing
/// the offer, the download's cancel rules, what each outcome does to the card, whether an install is under way and when
/// the hand-over to the new version is done. `Launcher` reports the settings window's two transitions; `Lifecycle`
/// reads `isInstalling` and answers `onReplaced`; the window drives `updateNow` and `cancel`.
@MainActor @Observable
public final class Updater {
    /// Every legal situation, and nothing else.
    private enum Phase {
        case idle
        case checking(ticket: Int)
        case offering(Release)
        case downloading(Release, ticket: Int, progress: Double)
        /// Unpacking, verifying, maybe the administrator prompt, the swap. Survives the window closing.
        case installing(Release, ticket: Int)
        /// Swapped in and asked to open; ends with this process.
        case opening(Release)
        case failed(Release)
    }

    private var phase: Phase = .idle
    @ObservationIgnored private var tickets = 0
    @ObservationIgnored private let installed: InstalledRelease
    @ObservationIgnored private let releases: any ReleaseList
    @ObservationIgnored private let installer: any UpdateInstaller
    /// The new version runs: this process ends. Set only by `Lifecycle`.
    @ObservationIgnored var onReplaced: (@MainActor () -> Void)?

    public init(_ installed: InstalledRelease, releases: any ReleaseList, installer: any UpdateInstaller) {
        self.installed = installed
        self.releases = releases
        self.installer = installer
    }

    /// nil while no newer version is known.
    public var card: UpdateCard? {
        switch phase {
        case .idle, .checking: nil
        case .offering(let release): .available(release.version)
        case .downloading(let release, _, let progress): .downloading(release.version, progress: progress)
        case .installing(let release, _), .opening(let release): .installing(release.version)
        case .failed(let release): .failed(release.version)
        }
    }

    /// While true, *Quit Trackpad Launcher* is disabled and an ordinary quit only closes the window. The one source of
    /// that rule.
    public var isInstalling: Bool {
        switch phase {
        case .installing, .opening: true
        default: false
        }
    }

    /// From `Launcher`, only when the window goes from closed to open, after it has opened. An opening while an update
    /// installs makes no check: the card keeps showing the install.
    func windowOpened() {
        guard !isInstalling else { return }
        let ticket = nextTicket()
        // First: an in-memory list may answer inside `fetch`.
        phase = .checking(ticket: ticket)
        releases.fetch { [unowned self] in checked($0, ticket: ticket) }
    }

    /// From `Launcher`, only when the window goes from open to closed. A check's result is never kept; a download
    /// stops; an install continues.
    func windowClosed() {
        switch phase {
        case .downloading:
            phase = .idle
            installer.cancelDownload()
        case .checking, .offering, .failed: phase = .idle
        case .idle, .installing, .opening: break
        }
    }

    /// *Update now* and *Try again*.
    public func updateNow() {
        switch phase {
        case .offering(let release), .failed(let release):
            let ticket = nextTicket()
            // First: an in-memory installer may answer inside `update`.
            phase = .downloading(release, ticket: ticket, progress: 0)
            installer.update(to: release) { [unowned self] in progressed($0, ticket: ticket) }
        default: break
        }
    }

    /// *Cancel*, only while downloading.
    public func cancel() {
        guard case .downloading(let release, _, _) = phase else { return }
        phase = .offering(release)
        installer.cancelDownload()
    }

    private var liveTicket: Int? {
        switch phase {
        case .checking(let ticket), .downloading(_, let ticket, _), .installing(_, let ticket): ticket
        case .idle, .offering, .opening, .failed: nil
        }
    }

    private func nextTicket() -> Int {
        tickets += 1
        return tickets
    }

    /// A check from an earlier opening, or one the window closed on, is dropped. An empty list (including a failed
    /// request) is silent.
    private func checked(_ list: [Release], ticket: Int) {
        guard ticket == liveTicket else { return }
        phase = Release.newerVersion(in: list, than: installed.version, on: installed.macOS).map(Phase.offering) ?? .idle
    }

    private func progressed(_ event: UpdateEvent, ticket: Int) {
        guard ticket == liveTicket else { return }
        switch (phase, event) {
        case (.downloading(let release, _, _), .progress(let fraction)):
            phase = .downloading(release, ticket: ticket, progress: fraction)
        case (.downloading(let release, _, _), .downloaded):
            phase = .installing(release, ticket: ticket)
        case (.downloading(let release, _, _), .failed), (.installing(let release, _), .failed):
            phase = .failed(release)
        case (.installing(let release, _), .declined):
            phase = .offering(release)
        case (.installing(let release, _), .installed):
            phase = .opening(release)
            installer.openNewVersion { [unowned self] in opened($0) }
        default: break
        }
    }

    /// Started: this process ends, and the new version, opened by hand from /Applications, stops anything left. Not
    /// started: /Applications holds the new version and *Try again* converges (a same-version swap, a second open).
    private func opened(_ started: Bool) {
        guard case .opening(let release) = phase else { return }
        if started { onReplaced?() } else { phase = .failed(release) }
    }
}
