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
    /// What the settings window shows above its rows. Derived from the phase, so no phase can show a stale card.
    public var card: UpdateCard? {
        switch phase {
        case .offering: .available
        case .updatingFromCard: .updating
        default: nil
        }
    }

    @ObservationIgnored private let engine: any UpdateEngine
    @ObservationIgnored private let connection: any Connection
    @ObservationIgnored private let canReplaceItself: Bool
    @ObservationIgnored private weak var launcher: Launcher?

    /// A login start's wait for a connection, carried through the phases it can pass through: none; owed with this
    /// reading's retry unmade; owed with it made, so only a drop and a return earn another.
    private enum RetryDebt: Equatable { case none, owed(spent: Bool) }

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
        /// The window's check runs. `debt`: what a login start's wait it interrupted still owes; any check that
        /// completes settles it.
        case probing(debt: RetryDebt)
        /// The window closed during its check. The check still runs, its answer is ignored, and no second check starts
        /// until it has come: one cycle at a time.
        case droppedProbe(debt: RetryDebt)
        /// The card shows *Update available*. Nothing of Sparkle exists.
        case offering
        /// *Update now*'s cycle runs; the card shows *Updating…*, window open or closed.
        case updatingFromCard
    }

    private var phase = Phase.resting

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection) {
        self.engine = engine
        self.connection = connection
        canReplaceItself = copy.canReplaceItself
    }

    /// Once, from a resident only. A login start of a copy that can replace itself runs the update cycle whatever the
    /// window is doing; a start with its window open makes one check; every other start makes no request.
    public func start(watching launcher: Launcher, opening: Opening, opensWindow: Bool) {
        self.launcher = launcher
        engine.onEvent = { [unowned self] event in handle(event) }
        connection.onChange = { [unowned self] connected in connectionChanged(connected) }
        launcher.onWindowEdge = { [unowned self] isOpen in windowEdge(isOpen) }
        switch opening {
        case .atLogin where canReplaceItself:
            enter(.updatingAtLogin(retry: false, dropped: false))
            engine.update()
        case .afterUpdate:
            break
        case .atLogin, .byHand:
            if opensWindow { probe(owing: .none) }
        }
    }

    /// *Update now*: only while the card offers it.
    public func updateNow() {
        guard phase == .offering else { return }
        enter(.updatingFromCard)
        engine.update()
    }

    private func probe(owing debt: RetryDebt) {
        enter(.probing(debt: debt))
        engine.probe()
    }

    private func windowEdge(_ isOpen: Bool) {
        switch (phase, isOpen) {
        case (.resting, true): probe(owing: .none)
        case (.awaitingConnection(let spent), true): probe(owing: .owed(spent: spent))
        case (.droppedProbe(let debt), true): enter(.probing(debt: debt))
        case (.probing(let debt), false): enter(.droppedProbe(debt: debt))
        case (.offering, false): enter(.resting)
        default: break
        }
    }

    private func handle(_ event: UpdateEngineEvent) {
        switch (phase, event) {
        case (.updatingAtLogin, .held):
            handOver(opensWindow: launcher?.isWindowOpen ?? false)
        case (.updatingFromCard, .held):
            handOver(opensWindow: true)
        case (.updatingAtLogin(let retry, let dropped), .cycleEnded(let outcome)):
            enter(outcome == .requestFailed ? .awaitingConnection(spent: retry && !dropped) : .resting)
        case (.probing(let debt), .cycleEnded(let outcome)):
            enter(outcome == .found ? .offering : afterCheck(outcome, owing: debt))
        case (.droppedProbe(let debt), .cycleEnded(let outcome)):
            enter(afterCheck(outcome, owing: debt))
        case (.updatingFromCard, .cycleEnded(let outcome)):
            enter(outcome != .nothingNew && launcher?.isWindowOpen == true ? .offering : .resting)
        default: break
        }
    }

    private func afterCheck(_ outcome: CycleOutcome, owing debt: RetryDebt) -> Phase {
        if outcome == .requestFailed, case .owed(let spent) = debt { return .awaitingConnection(spent: spent) }
        return .resting
    }

    private func handOver(opensWindow: Bool) {
        guard engine.armRestart(opensWindow: opensWindow) else {
            // Refused: the process never ends without a restart armed, so the held update goes; the cycle then ends
            // `.failed`.
            engine.discardHeldUpdate()
            return
        }
        enter(.handedOver)
        onHandOver?()
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
