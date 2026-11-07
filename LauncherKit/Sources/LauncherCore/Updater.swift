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
    private let clock: any IdleClock
    private var launcher: Launcher?

    private enum Phase {
        /// Nothing to do. Sparkle's schedule, or a check, may be running.
        case resting
        /// A genuine update is held and installs at this process's end, however it ends. `Launcher`'s use is watched,
        /// and the idle minute runs exactly while the app is not in use.
        case ready
        /// Terminal. The restart is armed and the process is ending in this same turn.
        case handedOver
    }

    private var phase = Phase.resting

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, clock: any IdleClock) {
        self.engine = engine
        self.clock = clock
    }

    /// Once, from a resident only. Starts the engine and checks in the same turn: the one moment Sparkle's docs bless,
    /// and the only way to check at every start, because Sparkle's scheduler checks at start only past 24 hours.
    public func start(watching launcher: Launcher, opening: Opening) {
        self.launcher = launcher
        engine.onEvent = { [unowned self] event in handle(event) }
        engine.start()
        engine.check()
    }

    private func handle(_ event: UpdateEngineEvent) {
        guard phase != .handedOver else { return }
        switch event {
        case .held(.genuine): enter(.ready)
        case .held(.notGenuine): break
        case .cycleEnded: enter(.resting)
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
        if phase == .ready {
            clock.cancel()
            launcher?.watchUse(nil)
        }
        phase = next
        if next == .ready { launcher?.watchUse { [unowned self] in useChanged($0) } }
    }
}
