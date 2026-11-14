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

/// A version as people read it ("1.1.22"), never the build number: `CFBundleShortVersionString`, or the feed's
/// `sparkle:shortVersionString`. Made at the two boundaries that read one. Display text only: Sparkle compares builds.
public struct AppVersion: Equatable, Sendable, CustomStringConvertible {
    public let description: String

    public init(_ text: String) { description = text }
}

/// Work under way: a still word, then three dots that step while it runs.
public enum Progress: Equatable, Sendable {
    case checking
    case updating

    /// The part that never moves.
    public var word: String {
        switch self {
        case .checking: Copy.checkingWord
        case .updating: Copy.updatingWord
        }
    }

    /// What VoiceOver reads and Reduce motion shows.
    public var label: String { word + "…" }
}

/// A button's title. Only `.progress` animates; an ellipsis meaning "opens something" is `.plain`.
public enum ButtonTitle: Equatable, Sendable {
    case plain(String)
    case progress(Progress)

    public var text: String {
        switch self {
        case .plain(let text): text
        case .progress(let progress): progress.label
        }
    }
}

/// The update card the settings window shows, as values.
public enum UpdateCard: Equatable, Sendable {
    case available
    case updating

    public var text: String { Copy.updateAvailable }

    public var buttonTitle: ButtonTitle {
        switch self {
        case .available: .plain(Copy.updateNowButton)
        case .updating: .progress(.updating)
        }
    }

    public var isButtonEnabled: Bool { self == .available }
}

public enum CycleOutcome: Equatable, Sendable {
    /// A probe found a newer version: the newest, as its display version. Never an update's outcome.
    case found(AppVersion)
    case nothingNew
    /// The feed's request failed: what a lost connection looks like, and the only outcome that earns a login start's
    /// retry.
    case requestFailed
    /// Anything else after the feed was read: a download that failed, a refused or ungenuine archive, a discarded update.
    case failed
}

public enum UpdateEngineEvent: Equatable, Sendable {
    /// A genuine update is extracted and prepared; it installs at this process's end. Pushed inside Sparkle's
    /// callback, so nothing else runs on the main actor first.
    case held
    /// A cycle ended. For a probe, its one answer.
    case cycleEnded(CycleOutcome)
}

/// What an update-capable copy updates through. Only the gate's value makes one, so a copy the gate turns away has no
/// engine and no path monitor: nothing in it can make a request.
@MainActor public struct UpdatePorts {
    let engine: any UpdateEngine
    let connection: any Connection
    let canReplaceItself: Bool

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection) {
        self.engine = engine
        self.connection = connection
        canReplaceItself = copy.canReplaceItself
    }
}

/// Owns every update decision, in every copy. Without ports its phase never leaves `resting`, so it makes no request.
@MainActor @Observable
public final class Updater {
    public let version: AppVersion
    /// The process must end now, through `end()`. Set once by `Lifecycle`.
    @ObservationIgnored public var onHandOver: (@MainActor () -> Void)?

    /// What the settings window shows above its rows. Derived, so no state can show a stale card.
    public var card: UpdateCard? {
        switch state.phase {
        case .installing(let install): return install.showsCard ? .updating : nil
        case .updatingAtLogin, .handedOver: return nil
        default: break
        }
        if let install = state.queued { return install.showsCard ? .updating : nil }
        return state.window == .card ? .available : nil
    }

    /// The Automatic updates switch. Read once at init; saved at once by `setAutomaticUpdates`.
    public private(set) var isAutomaticUpdatesOn: Bool

    @ObservationIgnored private let ports: UpdatePorts?
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private weak var launcher: Launcher?
    private var state = State()

    private struct State: Equatable {
        var phase = Phase.resting
        /// What the open window has at stake in the list's next answer. `.none` while it is closed or the switch is off.
        var window = WindowStake.none
        /// A download the user asked for while a cycle ran; it starts when the engine is free.
        var queued: Install?
    }

    /// What the engine is doing, and what a login start is still owed. A cycle runs in every phase but `resting`,
    /// `awaitingConnection` and `handedOver`.
    private enum Phase: Equatable {
        case resting
        /// The login check failed for the network; the path monitor runs. `spent`: this reading's one retry has been
        /// made, so only a drop and a return earn another. One bit; no timer, no backoff.
        case awaitingConnection(spent: Bool)
        /// A read that downloads nothing. `debt`: what an interrupted login wait still owes.
        case checking(debt: RetryDebt)
        /// The login cycle reads the list. `retry`: a returned connection started it, so the watch stays through it;
        /// `dropped`: the connection fell during that retry, so its network failure owes a fresh retry rather than a
        /// spent one.
        case checkingAtLogin(retry: Bool, dropped: Bool)
        /// The switch went off while the login cycle read the list. It cannot be stopped, so it runs on; its offer is
        /// declined, so nothing downloads. `listAnswered`: the offer has come.
        case abandonedAtLogin(listAnswered: Bool)
        /// The login update: its offer was taken, it downloads, is checked and prepared. Silent.
        case updatingAtLogin
        /// A download the user asked for: it reads the list once more, then downloads, the newest it finds.
        case installing(Install)
        /// Terminal: the restart is armed and the process ends in this turn.
        case handedOver
    }

    /// A login start's wait for a connection, carried through the phases it can pass through: none; owed with this
    /// reading's retry unmade; owed with it made, so only a drop and a return earn another.
    private enum RetryDebt: Equatable { case none, owed(spent: Bool) }

    /// A download the user asked for, and whether the card reads *Updating…* through it.
    private enum Install: Equatable {
        case fromCard
        var showsCard: Bool { self == .fromCard }
    }

    private enum WindowStake: Equatable {
        case none
        /// This opening's check has not answered yet.
        case check
        /// It found a newer version: the card shows *Update available*.
        case card
    }

    public init(version: AppVersion, store: SettingsStore, ports: UpdatePorts?) {
        self.version = version
        self.store = store
        self.ports = ports
        isAutomaticUpdatesOn = store.loadAutomaticUpdates()
    }

    /// Once, from a resident only. A login start of a copy that can replace itself runs the update cycle whatever the
    /// window is doing; any other start with its window open goes through the open edge, standing in for the first
    /// window edge, which never reaches `onWindowEdge`. A start after an update makes no request. Without ports it
    /// only watches the window.
    public func start(watching launcher: Launcher, opening: Opening, opensWindow: Bool) {
        self.launcher = launcher
        launcher.onWindowEdge = { [unowned self] isOpen in windowEdge(isOpen) }
        guard let ports else { return }
        ports.engine.onEvent = { [unowned self] event in handle(event) }
        ports.engine.shouldDownload = { [unowned self] version in offered(version) }
        ports.connection.onChange = { [unowned self] connected in connectionChanged(connected) }
        switch opening {
        case .atLogin where ports.canReplaceItself && isAutomaticUpdatesOn:
            begin(.checkingAtLogin(retry: false, dropped: false))
        case .afterUpdate:
            break
        case .atLogin, .byHand:
            if opensWindow { windowEdge(true) }
        }
    }

    /// *Update now*: only while the card offers it.
    public func updateNow() {
        guard card == .available else { return }
        want(.fromCard)
        settle()
    }

    /// Saved at once, on a change only. Off drops what waits on a check and keeps every download; on starts nothing.
    public func setAutomaticUpdates(on: Bool) {
        guard on != isAutomaticUpdatesOn else { return }
        store.saveAutomaticUpdates(on)
        isAutomaticUpdatesOn = on
        guard ports != nil, !on else { return }
        var next = state
        next.window = .none
        switch state.phase {
        case .awaitingConnection: next.phase = .resting
        case .checking: next.phase = .checking(debt: .none)
        case .checkingAtLogin: next.phase = .abandonedAtLogin(listAnswered: false)
        case .resting, .abandonedAtLogin, .updatingAtLogin, .installing, .handedOver: break
        }
        enter(next)
        settle()
    }

    // MARK: Inputs

    private func windowEdge(_ isOpen: Bool) {
        var next = state
        if isOpen {
            guard ports != nil, isAutomaticUpdatesOn, state.queued == nil else { return }
            switch state.phase {
            case .checkingAtLogin, .updatingAtLogin, .installing, .handedOver: return
            case .resting, .awaitingConnection, .checking, .abandonedAtLogin: break
            }
            next.window = .check
        } else {
            next.window = .none
        }
        enter(next)
        settle()
    }

    private func handle(_ event: UpdateEngineEvent) {
        var next = state
        switch (state.phase, event) {
        case (.updatingAtLogin, .held):
            handOver(opensWindow: launcher?.isWindowOpen ?? false)
            return
        case (.installing, .held):
            handOver(opensWindow: true)
            return
        case (.checking(let debt), .cycleEnded(let outcome)):
            listAnswered(outcome, into: &next)
            if outcome == .requestFailed, case .owed(let spent) = debt {
                next.phase = .awaitingConnection(spent: spent)
            } else {
                next.phase = .resting
            }
        case (.checkingAtLogin(let retry, let dropped), .cycleEnded(let outcome)):
            listAnswered(outcome, into: &next)
            next.phase = outcome == .requestFailed ? .awaitingConnection(spent: retry && !dropped) : .resting
        case (.abandonedAtLogin(false), .cycleEnded(let outcome)):
            listAnswered(outcome, into: &next)
            next.phase = .resting
        case (.abandonedAtLogin(true), .cycleEnded), (.updatingAtLogin, .cycleEnded):
            next.phase = .resting
        case (.installing(let install), .cycleEnded(let outcome)):
            installEnded(install, outcome, into: &next)
            next.phase = .resting
        default:
            return
        }
        enter(next)
        settle()
    }

    private func connectionChanged(_ connected: Bool) {
        switch state.phase {
        case .awaitingConnection(let spent):
            if !connected {
                state.phase = .awaitingConnection(spent: false)
            } else if !spent {
                begin(.checkingAtLogin(retry: true, dropped: false))
            }
        case .checkingAtLogin(true, _):
            if !connected { state.phase = .checkingAtLogin(retry: true, dropped: true) }
        default: break
        }
    }

    /// `shouldDownload`, asked inside Sparkle's `showUpdateFound`.
    private func offered(_ version: AppVersion) -> Bool {
        switch state.phase {
        case .checkingAtLogin:
            var next = state
            listAnswered(.found(version), into: &next)
            next.window = .none
            next.phase = .updatingAtLogin
            enter(next)
            settle()
            return true
        case .abandonedAtLogin(false):
            var next = state
            listAnswered(.found(version), into: &next)
            next.phase = .abandonedAtLogin(listAnswered: true)
            enter(next)
            settle()
            return false
        case .installing:
            return true
        default:
            return false
        }
    }

    // MARK: Transitions

    /// After every input. A free engine takes what waits: first a download the user asked for, then a check someone
    /// waits for. Idempotent.
    private func settle() {
        guard ports != nil else { return }
        let debt: RetryDebt
        switch state.phase {
        case .resting: debt = .none
        case .awaitingConnection(let spent): debt = .owed(spent: spent)
        default: return
        }
        if let install = state.queued {
            var next = state
            next.queued = nil
            enter(next)
            begin(.installing(install))
        } else if state.window == .check {
            begin(.checking(debt: debt))
        }
    }

    /// The one place a cycle starts, and only from a phase that runs none. The phase is entered first: the engine may
    /// answer inside the call.
    private func begin(_ next: Phase) {
        guard let ports else { return }
        switch state.phase {
        case .resting, .awaitingConnection: break
        default: return
        }
        var entered = state
        entered.phase = next
        enter(entered)
        switch next {
        case .checking: ports.engine.probe()
        case .checkingAtLogin, .installing: ports.engine.update()
        case .resting, .awaitingConnection, .abandonedAtLogin, .updatingAtLogin, .handedOver: break
        }
    }

    /// The one place a lasting effect starts or stops, from the diff of `state` and `next`: the connection watch runs in
    /// `awaitingConnection` and through a login retry. Last, because the watch pushes the present reading inside the
    /// call.
    private func enter(_ next: State) {
        let previous = state.phase
        state = next
        guard let ports else { return }
        if case .awaitingConnection = next.phase {
            if case .awaitingConnection = previous { return }
            ports.connection.watch()
        } else if watches(previous), !watches(next.phase) {
            ports.connection.stop()
        }
    }

    private func watches(_ phase: Phase) -> Bool {
        switch phase {
        case .awaitingConnection, .checkingAtLogin(retry: true, _): true
        default: false
        }
    }

    /// The list answered. Everyone waiting takes the answer; a read nobody waits for answers no one.
    private func listAnswered(_ outcome: CycleOutcome, into next: inout State) {
        switch (next.window, outcome) {
        case (.check, .found): next.window = .card
        case (.check, _): next.window = .none
        case (.card, .nothingNew): next.window = .none
        default: break
        }
    }

    /// At most one download.
    private func want(_ install: Install) {
        switch state.phase {
        case .installing, .handedOver: return
        default: break
        }
        guard state.queued == nil else { return }
        var next = state
        next.window = .none
        next.queued = install
        enter(next)
    }

    private func installEnded(_ install: Install, _ outcome: CycleOutcome, into next: inout State) {
        if install.showsCard, outcome != .nothingNew, launcher?.isWindowOpen == true, isAutomaticUpdatesOn {
            next.window = .card
        }
    }

    /// Arm, or discard and let the cycle's `.failed` resolve through the phase.
    private func handOver(opensWindow: Bool) {
        guard let ports else { return }
        guard ports.engine.armRestart(opensWindow: opensWindow) else {
            // Refused: the process never ends without a restart armed, so the held update goes; the cycle then ends
            // `.failed`.
            ports.engine.discardHeldUpdate()
            return
        }
        var next = state
        next.phase = .handedOver
        enter(next)
        onHandOver?()
    }
}
