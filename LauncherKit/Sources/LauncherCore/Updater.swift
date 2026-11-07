import Foundation
import Observation

/// The gate: a copy that is signed with a Developer ID and lies in /Applications. Pure, called by the composition root and
/// the tests, read once at start. Only a copy that can also replace its own bundle runs the login cycle.
public struct UpdatableCopy: Equatable, Sendable {
    public let canReplaceItself: Bool

    public init?(placement: Placement, developerIDSigned: Bool, canReplaceItself: Bool) {
        guard developerIDSigned, placement == .installed else { return nil }
        self.canReplaceItself = canReplaceItself
    }
}

/// The update card the settings window shows, as values.
public enum UpdateCard: Equatable, Sendable {
    case available
    case updating

    public var text: String { Copy.updateAvailable }

    public var buttonTitle: String {
        switch self {
        case .available: Copy.updateNowButton
        case .updating: Copy.updatingButton
        }
    }

    public var isButtonEnabled: Bool { self == .available }
}

public enum CycleOutcome: Equatable, Sendable {
    /// A probe found a newer version. Never an update's outcome.
    case found
    case nothingNew
    /// The feed's request failed: what a lost connection looks like, and what earns a login start's retry.
    case requestFailed
    /// Anything after the feed was read: a download that failed, a refused enclosure, a cancelled prompt, a bad
    /// signature, a discarded update.
    case failed
}

public enum UpdateEngineEvent: Equatable, Sendable {
    /// A genuine update is extracted and prepared; it installs at this process's end. Pushed inside Sparkle's
    /// callback, so nothing else runs on the main actor first.
    case held
    /// A cycle ended. For a probe, its one answer.
    case cycleEnded(CycleOutcome)
}

/// Owns every update decision. Exists only for a copy the gate lets through.
@MainActor @Observable
public final class Updater {
    /// The process must end now, through `end()`. Set once by `Lifecycle`.
    @ObservationIgnored public var onHandOver: (@MainActor () -> Void)?
    /// What the settings window shows beside its rows; nil in every phase that exists so far.
    public private(set) var card: UpdateCard?

    @ObservationIgnored private let engine: any UpdateEngine
    @ObservationIgnored private let connection: any Connection
    @ObservationIgnored private let canReplaceItself: Bool
    @ObservationIgnored private weak var launcher: Launcher?

    private enum Phase: Equatable {
        case resting
        /// The login check failed for the network; the path monitor runs. `spent`: this reading's one retry has been
        /// made, so only a drop and a return earn another. One bit; no timer, no backoff.
        case awaitingConnection(spent: Bool)
        /// The login cycle runs: the check, the download, the preparation. `retry`: a returned connection started it, so
        /// the watch stays through it; `dropped`: the connection fell during that retry, so its network failure owes a
        /// fresh retry rather than a spent one.
        case updatingAtLogin(retry: Bool, dropped: Bool)
        /// Terminal. The restart is armed and the process is ending in this same turn.
        case handedOver
    }

    @ObservationIgnored private var phase = Phase.resting

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection) {
        self.engine = engine
        self.connection = connection
        canReplaceItself = copy.canReplaceItself
    }

    /// Once, from a resident only. A login start of a copy that can replace itself runs the update cycle whatever the
    /// window is doing; every other start makes no request.
    public func start(watching launcher: Launcher, opening: Opening, opensWindow: Bool) {
        self.launcher = launcher
        engine.onEvent = { [unowned self] event in handle(event) }
        connection.onChange = { [unowned self] connected in connectionChanged(connected) }
        guard opening == .atLogin, canReplaceItself else { return }
        enter(.updatingAtLogin(retry: false, dropped: false))
        engine.update()
    }

    private func handle(_ event: UpdateEngineEvent) {
        guard case .updatingAtLogin(let retry, let dropped) = phase else { return }
        switch event {
        case .held:
            guard engine.armRestart(opensWindow: launcher?.isWindowOpen ?? false) else {
                // Refused: the process never ends without a restart armed, so the held update goes; the cycle then ends
                // `.failed`.
                engine.discardHeldUpdate()
                return
            }
            enter(.handedOver)
            onHandOver?()
        case .cycleEnded(.requestFailed):
            enter(.awaitingConnection(spent: retry && !dropped))
        case .cycleEnded:
            enter(.resting)
        }
    }

    private func connectionChanged(_ connected: Bool) {
        switch phase {
        case .awaitingConnection(let spent):
            if !connected {
                phase = .awaitingConnection(spent: false)
            } else if !spent {
                // Written before the cycle: the engine may answer inside the call.
                enter(.updatingAtLogin(retry: true, dropped: false))
                engine.update()
            }
        case .updatingAtLogin(true, _):
            if !connected { phase = .updatingAtLogin(retry: true, dropped: true) }
        default: break
        }
    }

    private func watches(_ phase: Phase) -> Bool {
        switch phase {
        case .awaitingConnection, .updatingAtLogin(retry: true, _): true
        default: false
        }
    }

    /// The one place a lasting effect starts or stops, so leaving a phase cannot leave one armed.
    private func enter(_ next: Phase) {
        let previous = phase
        phase = next
        // After the assignment: the watch pushes the present reading inside the call.
        if case .awaitingConnection = next {
            connection.watch()
        } else if watches(previous), !watches(next) {
            connection.stop()
        }
    }
}
