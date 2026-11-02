import Foundation
import Observation

/// The update model, beside `Lifecycle` and `Launcher`. It exists only where an update check is allowed (see
/// `InstalledRelease`). `Launcher` reports the settings window's two transitions; each opening from closed checks the
/// release list once, and a window that closes drops the check and whatever it found.
@MainActor @Observable
public final class Updater {
    private enum Phase {
        case idle
        case checking(ticket: Int)
        case offering(Release)
    }
    private var phase: Phase = .idle
    @ObservationIgnored private var tickets = 0
    @ObservationIgnored private let installed: InstalledRelease
    @ObservationIgnored private let releases: any ReleaseList

    public init(_ installed: InstalledRelease, releases: any ReleaseList) {
        self.installed = installed
        self.releases = releases
    }

    /// nil while no newer version is known.
    public var card: UpdateCard? {
        switch phase {
        case .idle, .checking: nil
        case .offering(let release): .available(release.version)
        }
    }

    /// From `Launcher`, only when the window goes from closed to open, after it has opened.
    func windowOpened() {
        let ticket = nextTicket()
        // First: an in-memory list may answer inside `fetch`.
        phase = .checking(ticket: ticket)
        releases.fetch { [unowned self] in checked($0, ticket: ticket) }
    }

    /// From `Launcher`, only when the window goes from open to closed. A check's result is never kept.
    func windowClosed() {
        switch phase {
        case .checking, .offering: phase = .idle
        case .idle: break
        }
    }

    private var liveTicket: Int? { if case .checking(let ticket) = phase { ticket } else { nil } }
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
}
