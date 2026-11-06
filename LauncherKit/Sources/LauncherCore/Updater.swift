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

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine) {
        self.engine = engine
    }

    /// Once, from a resident only. Starts the engine and checks in the same turn: the one moment Sparkle's docs bless,
    /// and the only way to check at every start, because Sparkle's scheduler checks at start only past 24 hours.
    public func start(watching launcher: Launcher, opening: Opening) {
        engine.onEvent = { [unowned self] event in handle(event) }
        engine.start()
        engine.check()
    }

    private func handle(_ event: UpdateEngineEvent) {
        switch event {
        case .held: break
        case .cycleEnded: break
        }
    }
}
