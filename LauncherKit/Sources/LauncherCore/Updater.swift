import Foundation

/// The gate, whole: a copy that is signed with a Developer ID, lies in /Applications and can replace its own bundle.
/// Pure, called by the composition root and the tests. Read once, at start.
public struct UpdatableCopy: Equatable, Sendable {
    public init?(placement: Placement, developerIDSigned: Bool, canReplaceItself: Bool) {
        guard developerIDSigned, placement == .installed, canReplaceItself else { return nil }
    }
}

public enum CycleOutcome: Equatable, Sendable {
    /// Up to date, or nothing that could be taken.
    case nothingNew
    /// A request failed, the feed's or the archive's. What a lost connection looks like, and what earns a retry.
    case requestFailed
    /// Anything else: a refused enclosure, a bad signature, a veto, a held update lost.
    case failed
}

public enum HeldUpdate: Equatable, Sendable {
    /// Our check passed: same Developer ID, identifier, notarised, sealed versions equal the offer.
    case genuine
    /// It failed, or could not be run. Fail closed.
    case notGenuine
}

public enum UpdateEngineEvent: Equatable, Sendable {
    /// Sparkle verified, extracted and prepared an update, and will install it at this process's end. Pushed inside the
    /// delegate call, so nothing else runs on the main actor first.
    case held(HeldUpdate)
    /// A cycle ended: no update, a failure, or a held update lost (a helper died).
    case cycleEnded(CycleOutcome)
}

/// Owns every update decision. Exists only for a copy the gate lets through.
@MainActor public final class Updater {
    /// The process must end now, through `end()`. Set once by `Lifecycle`.
    public var onHandOver: (@MainActor () -> Void)?
    private let engine: any UpdateEngine
    private let connection: any Connection
    private let clock: any IdleClock
    private var launcher: Launcher?

    private enum Phase: Equatable {
        /// Nothing to do. Sparkle's schedule, or a check, may be running.
        case resting
        /// A genuine update is held and installs at this process's end, however it ends. `Launcher`'s use is watched,
        /// and the idle minute runs exactly while the app is not in use.
        case ready
        /// The last cycle's request failed, and the connection watch runs. `retrySpent`: this reading's one retry has
        /// been made, so only a drop and a return earn another. One bit; no timer, no backoff.
        case awaitingConnection(retrySpent: Bool)
        /// Terminal. The restart is armed and the process is ending in this same turn.
        case handedOver
    }

    private var phase = Phase.resting

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection, clock: any IdleClock) {
        self.engine = engine
        self.connection = connection
        self.clock = clock
    }

    /// Once, from a resident only. Starts the engine and, unless this process is the hand-over's, checks in the same
    /// turn. A failed install must not check at once, or it would hand over once a minute for ever.
    public func start(watching launcher: Launcher, opening: Opening) {
        self.launcher = launcher
        engine.onEvent = { [unowned self] event in handle(event) }
        connection.onChange = { [unowned self] connected in connectionChanged(connected) }
        engine.start()
        if opening != .afterUpdate { engine.check() }
    }

    private func handle(_ event: UpdateEngineEvent) {
        guard phase != .handedOver else { return }
        switch event {
        case .held(.genuine): enter(.ready)
        case .held(.notGenuine):
            // No restart is ever armed for it; Sparkle ends the cycle itself once its helper has gone.
            engine.discardHeldUpdate()
        case .cycleEnded(.requestFailed):
            // Already awaiting: stay as it is, so a drop during the retry still earns the next one.
            if case .awaitingConnection = phase { return }
            enter(.awaitingConnection(retrySpent: false))
        case .cycleEnded: enter(.resting)
        }
    }

    private func connectionChanged(_ connected: Bool) {
        guard case .awaitingConnection(let spent) = phase else { return }
        if !connected {
            phase = .awaitingConnection(retrySpent: false)
        } else if !spent {
            // Written before the check: the engine may answer inside the call.
            phase = .awaitingConnection(retrySpent: true)
            engine.check()
        }
    }

    private func useChanged(_ inUse: Bool) {
        guard phase == .ready else { return }
        if inUse {
            clock.cancel()
        } else {
            clock.wait(.seconds(60)) { [unowned self] in idleMinutePassed() }
        }
    }

    private func idleMinutePassed() {
        // The level, read now: an edge may still be queued on the main actor.
        guard phase == .ready, launcher?.isInUse == false else { return }
        // Stays ready when refused: the next idle edge tries again, so there is no loop.
        guard engine.armRestart() else { return }
        enter(.handedOver)
        onHandOver?()
    }

    /// The one place a lasting effect starts or stops, so leaving a phase cannot leave one armed.
    private func enter(_ next: Phase) {
        guard next != phase else { return }
        let wasAwaiting: Bool
        if case .awaitingConnection = phase { wasAwaiting = true } else { wasAwaiting = false }
        let willAwait: Bool
        if case .awaitingConnection = next { willAwait = true } else { willAwait = false }
        if wasAwaiting && !willAwait { connection.stop() }
        if phase == .ready {
            clock.cancel()
            launcher?.watchUse(nil)
        }
        phase = next
        // After the assignment: the watch may push inside the call.
        if willAwait && !wasAwaiting { connection.watch() }
        if next == .ready { launcher?.watchUse { [unowned self] in useChanged($0) } }
    }
}
