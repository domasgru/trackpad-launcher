## Design

### Problem

Replace the window-driven, hand-written update path with Sparkle 2's automatic path so that a copy signed with a Developer ID, in /Applications, that can write to its own bundle, checks at every start and every 24 hours, downloads in the background, installs only after a minute with no finger on any trackpad and the settings window closed, and comes back silently, with the old quit rules intact and nothing on screen. The shape is non-obvious because Sparkle's documented automatic path ends with a quit Apple event our `Lifecycle` reads as the Dock's Quit and a relaunch that reads as an opening by hand (B1, B2); because Sparkle alone neither enforces R6's same-team-and-identifier rule (D1, D2) nor restarts anything after a failed install once the host has ended (C1); because the codebase bans timers, reachability and relaunchers by a source scan that cannot see into Sparkle's binary; and because every release must stay installable by the 16 shipped versions' update card (R16, F7). The constraints the design honours: `LauncherCore` imports Foundation and Observation only; every port has a real and an in-memory adapter; `Lifecycle` keeps its one exhaustive quit switch and `Launcher` stays ignorant of versions; the gate is an object's absence; a hand-over never goes through `quit()`; no `NSSupportsSuddenTermination`; and the `.aar` asset, its name and its inner bundle are a contract.

The fourteen decisions the task lists are settled in Shape, each under a heading that names its number.

### Usage (caller's view)

**The composition root** builds the updater through the gate, as today, and wires nothing else. `Updater` exists only for a copy that may update; Sparkle is started only once the process is resident.

```swift
// TrackpadLauncherApp.swift, applicationWillFinishLaunching
let updater = makeUpdater(placement: placement, location: location)
lifecycle = Lifecycle(placement: placement, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location),
                      startAtLogin: startAtLogin, updater: updater,
                      makeResident: { [unowned self] in makeResident(startAtLogin, updater) })

/// Only a copy truly signed with a Developer ID, lying in /Applications, that can replace its own bundle without a
/// password ever reaches the network. The rule itself is `UpdatableCopy.init?`, which the tests call too.
private func makeUpdater(placement: Placement, location: Location) -> Updater? {
    let signer = CodeSignature.developerIDSigner()
    guard let copy = UpdatableCopy(
            placement: placement, developerIDSigned: signer != nil,
            canReplaceOwnBundle: BundleInstall.canReplace(bundleAt: location.running),
            version: ThisCopy.version(), macOS: ThisCopy.macOS()),
          let signer
    else { return nil }
    return Updater(
        copy,
        service: SparkleUpdates(copy: copy, signer: signer, bundle: location.running, build: ThisCopy.build()),
        minute: WallClockMinute(), connectivity: NetworkReachability())
}
```

**`Lifecycle`** touches the updater in three places and reads nothing from it at quit time: it starts it once resident with the opening it already holds, it ends the process when the updater says the hand-over is arranged, and that is all. The quit table loses its `isInstalling` terms.

```swift
// Core/Lifecycle.swift
init(...) { updater?.onHandOver = { [unowned self] in handedOver() } }   // as onReplaced today

private func othersExited() {
    guard case .replacingOthers(let launch, let opensWindow) = stage else { return }
    let launcher = makeResident()
    launcher.start()
    stage = .resident(launcher)
    if opensWindow { launcher.openedByHand() }
    updater?.start(launch.opening)          // never for a copy that ends or asks to move: they never get here
    if let eject = launch.diskImageToEject { installer.eject(eject) }
}

public func shouldEnd(_ request: QuitRequest) -> Bool {
    switch stage {
    case .ending, .idle, .replacingOthers, .askingToMove, .moveFailed: return true
    case .moving: return request == .system
    case .resident(let launcher):
        guard request == .other else { return true }      // logout, restart, shutdown: always, an update waiting too
        if launcher.isWindowOpen { launcher.closeWindow(); return false }
        return true                                       // a script's quit with the window closed ends; Sparkle may install then, and relaunches nothing
    }
}

public func quit() {                                      // Quit Trackpad Launcher: at once, in any update state
    guard case .resident = stage else { return }
    startAtLogin.suspend()
    end()
}
```

**`Launcher`** reports facts, as it reports the window today, and decides nothing about updates.

```swift
// Core/Launcher.swift
hardware.onEvent = { [unowned self] event in
    switch event {
    case .gesture(let fired): fire(fired)
    case .swipe(let event): swipe(event)
    case .windowSwipe(let event): windowSwipe(event)
    case .swap(let event): swap(event)
    case .contact(let edge): updater?.trackpadContact(edge)      // new: compile-forced by the exhaustive switch
    case .trackpadsChanged: reconcile(restart: true)
    }
}
// in reconcile(), right after hardware.run(...):
updater?.trackpadsRestarted()                                   // sessions are new: occupancy is unknown, the minute restarts
// openedByHand / closeWindow keep calling updater?.windowOpened() / updater?.windowClosed() on the edges, as today
```

**The new copy** is told it is the new copy by the one-shot job that opens it, through an argument, as the mover tells the installed copy which disk image to eject. Nothing is persisted, so nothing can go stale.

```swift
// Platform/ThisCopy.swift
let launch = ThisCopy.launch(event: event, arguments: CommandLine.arguments)   // "--after-update" → Opening.afterUpdate
// Core/Lifecycle.swift: Route(.afterUpdate, .installed, _) == .runSilently: no window, no Dock icon, stops every other copy
```

**A test** runs the requirement scenarios at `LifecycleWorld` over real `Lifecycle`, `Launcher` and `Updater`, with handles on the clock, the pad, the window, the network and Sparkle's answers.

```swift
@Test func anUpdateInstallsOneMinuteAfterTheLaterOfTheLastTouchAndTheWindowClosing() {
    let world = LifecycleWorld(record: [.oneFinger: "Arc"])
    let process = world.launch(.atLogin, running: .release("1.0.0"))
    #expect(process.updates.checks == 1)                       // R1: a check at every start
    process.holdUpdate(.version("1.1.0"))                      // Sparkle: downloaded, EdDSA ok, extracted, genuine, installer armed
    #expect(process.minute.isCounting)                         // pad empty, window closed: the minute runs
    process.tap(1)                                             // a touch: the minute stops at the first contact
    #expect(!process.minute.isCounting)
    process.openAgain(.byHand)                                 // window open: still blocked after the fingers lift
    process.passMinute()                                       // a late fire is ignored
    #expect(process.updates.relaunchesArranged == 0)
    process.closeWindow()
    #expect(process.minute.isCounting)
    process.passMinute()
    #expect(world.log.entries.suffix(2) == ["arrangeRelaunch", "endThisCopy"])   // order of effects
    #expect(process.copies.hasEnded)
}

@Test func quitTrackpadLauncherWithAnUpdateWaitingStaysFinal() {
    let process = world.launch(.byHand, running: .release("1.0.0"))
    process.holdUpdate(.version("1.1.0"))
    process.quit()
    #expect(process.copies.hasEnded && process.updates.relaunchesArranged == 0 && !world.loginItem.isOn)
}
```

### Shape

Decisions are numbered as in the task. The module map is at the end of this section.

#### Data shape: what an update can be

Core holds the state in one sum type whose payload makes the illegal combinations unrepresentable (`per model-the-domain`, `per type-system-discipline`): an install can only be counting its minute while nothing blocks it, because the wait is a variant, not two booleans.

```swift
// Core/Update.swift

/// The running copy as the updater sees it. The gate, whole (R2, R12): exists only for a copy truly signed with a
/// Developer ID, inside /Applications, that can replace its own bundle without a password, whose version the adapter
/// could read. Read once at start; the tests and the composition root call this one rule.
public struct UpdatableCopy: Equatable, Sendable {
    public let version: Version     // CFBundleShortVersionString: what R4 compares
    public let macOS: Version
    public init?(placement: Placement, developerIDSigned: Bool, canReplaceOwnBundle: Bool, version: Version?, macOS: Version) {
        guard developerIDSigned, placement == .installed, canReplaceOwnBundle, let version else { return nil }
        self.version = version
        self.macOS = macOS
    }
}

/// One item of the feed, parsed by the adapter. A draft or a pre-release never becomes one: only the release process
/// writes the feed.
public struct UpdateOffer: Equatable, Sendable {
    public let version: Version
    public let minimumMacOS: Version
    /// The enclosure. R4 and R6 both need it pinned: this repository's release downloads, and an Apple Archive.
    public let archive: URL
}

/// R4 as one rule, and the one place in Swift that names where a download may come from.
public enum FeedPolicy {
    static let downloads = "https://github.com/domasgru/trackpad-launcher/releases/download/"
    /// The highest offer above `copy.version` whose minimum macOS this Mac meets and whose archive is an `.aar` under
    /// `downloads`; nil when none. An `.aar` cannot carry a code signature, so with `SUVerifyUpdateBeforeExtraction`
    /// only the update key can admit it (D3): R6's first half holds by this choice.
    public static func choose(from offers: [UpdateOffer], for copy: UpdatableCopy) -> UpdateOffer? { fatalError("not implemented") }
}

/// What Sparkle's cycle reports, as the model needs it. Parsed from Sparkle's errors and items behind the port.
public enum UpdateEvent: Equatable, Sendable {
    /// The feed answered and nothing counts.
    case noUpdate
    /// The feed could not be read: offline, no answer, a bad body. The next connection retries, once.
    case checkFailed
    /// After an offer was chosen: the download, Sparkle's EdDSA check, the extraction, our genuineness check or the
    /// installer failed, or the held update was lost. The schedule tries again in 24 h.
    case updateFailed
    /// A genuine update is extracted and Sparkle's installer waits for this process to end.
    case held(UpdateOffer)
}

/// What a trackpad's contact did: a frame with any contact after one with none, or the reverse. Edge contacts and
/// palms count; hovers do not.
public struct ContactEdge: Equatable, Sendable {
    public enum Phase: Sendable { case began, ended }
    public let trackpad: TrackpadID
    public let phase: Phase
}
```

```swift
// Core/Updater.swift

/// The update model, beside `Lifecycle` and `Launcher`, in a copy that may update (`UpdatableCopy`). It owns every
/// update decision: when a check runs beyond Sparkle's schedule, when a failed check is retried, R8's wait, the
/// hand-over's order of effects, and what an after-update start does. `Lifecycle` starts it once resident and answers
/// `onHandOver`; `Launcher` reports the window's and the trackpads' edges. Nothing renders it.
@MainActor public final class Updater {
    /// Every legal situation, and nothing else.
    private enum Phase {
        /// Sparkle's schedule decides the next check; a cycle may be running inside Sparkle.
        case idle
        /// The last check could not reach the feed: the next not-reachable-to-reachable flip checks once more.
        case awaitingConnection
        /// A genuine update is extracted; Sparkle's installer waits for this process to end (A3, A4).
        case holding(UpdateOffer, InstallWait)
        /// The silent relaunch is arranged and `Lifecycle` has been asked to end the process.
        case handingOver(UpdateOffer)
    }
    /// R8's wait. Derived after every input by `reconcileWait()`: counting exactly while no pad is occupied, the window
    /// is closed and a relaunch can still be arranged.
    private enum InstallWait: Equatable {
        case blocked
        case counting(MinuteTicket)
        /// launchd refused the hand-over job: the update installs when this process next ends, with no relaunch.
        case untilQuit
    }
    private struct MinuteTicket: Equatable { let number: Int }

    private var phase: Phase = .idle
    private var tickets = 0
    /// R8's facts, kept whatever the phase: trackpads with a contact down, and the window.
    private var occupied: Set<TrackpadID> = []
    private var windowOpen = false
    private let copy: UpdatableCopy
    private let service: any UpdateService
    private let minute: any IdleMinute
    private let connectivity: any Connectivity
    /// The relaunch is arranged: `Lifecycle` ends the process through `end()`, never `quit()`. Set only by `Lifecycle`.
    var onHandOver: (@MainActor () -> Void)?

    public init(_ copy: UpdatableCopy, service: any UpdateService, minute: any IdleMinute, connectivity: any Connectivity)

    /// From `Lifecycle`, once the process is resident. Starts Sparkle and, except after an update, checks now (R1).
    /// An after-update start leaves the next check to the schedule, so a failing install cannot loop the hand-over.
    public func start(_ opening: Opening) {
        service.onEvent = { [unowned self] in handle($0) }
        service.start()
        if opening != .afterUpdate { service.check() }
    }

    // From `Launcher`, the four facts. Each one ends in `reconcileWait()`.
    public func windowOpened()                     // windowOpen = true
    public func windowClosed()                     // windowOpen = false
    public func trackpadContact(_ edge: ContactEdge) // insert or remove edge.trackpad
    /// `run` replaced every session: a pending edge may never arrive, so occupancy is forgotten and a resting finger
    /// re-enters on its next frame. The minute restarts, which also covers waking (wake is a `run`).
    public func trackpadsRestarted()               // occupied = []; a counting minute is cancelled; then reconcile

    private func handle(_ event: UpdateEvent) {
        switch (phase, event) {
        case (.holding, .held), (.handingOver, _): break
        case (_, .held(let offer)): phase = .holding(offer, .blocked); reconcileWait()
        case (.holding, .updateFailed): minute.cancel(); phase = .idle          // helper died (C5), veto, lost
        case (_, .noUpdate), (_, .updateFailed): stopWaitingForConnection(); phase = .idle
        case (.idle, .checkFailed), (.awaitingConnection, .checkFailed):
            phase = .awaitingConnection
            connectivity.waitForConnection { [unowned self] in connected() }    // idempotent in the adapter
        case (.holding, .checkFailed): break                                     // cannot happen: no check runs while holding
        }
    }

    /// One retry per connection flip, never a loop: the watch is armed only by a failed check and consumed here.
    private func connected() {
        guard case .awaitingConnection = phase else { return }
        phase = .idle
        service.check()
    }

    /// The one place the wait is derived. "Install 1 minute after the later of the last touch and the window closing."
    private func reconcileWait() {
        guard case .holding(let offer, let wait) = phase else { return }
        let blocked = !occupied.isEmpty || windowOpen
        switch (wait, blocked) {
        case (.untilQuit, _), (.blocked, true), (.counting, false): return
        case (.counting, true): minute.cancel(); phase = .holding(offer, .blocked)
        case (.blocked, false):
            tickets += 1
            let ticket = MinuteTicket(number: tickets)
            phase = .holding(offer, .counting(ticket))
            minute.start { [unowned self] in minutePassed(ticket) }
        }
    }

    /// A fire for any other ticket is a late one: ignored (the real clock never fires once cancelled; the ticket makes
    /// the rule total anyway).
    private func minutePassed(_ ticket: MinuteTicket) {
        guard case .holding(let offer, .counting(ticket)) = phase else { return }
        // Order of effects: the job exists before this process ends (C3), then Lifecycle ends the process, then
        // Sparkle installs on termination with no relaunch (A5), then the job opens whatever is at the path.
        if service.arrangeRelaunch() {
            phase = .handingOver(offer)
            onHandOver?()
        } else {
            phase = .holding(offer, .untilQuit)      // R8: "the update MAY install then"; nothing restarts the app
        }
    }
}
```

Trace of the dominant access patterns: a contact edge is one set insert or removal and one switch; a minute fire is one pattern match; a Sparkle event is one switch. No map or index is added later.

#### Ports

Three ports, each with exactly two adapters (`per boundary-discipline`: wire types, Sparkle's items and errors, dispatch sources and reachability flags stay behind them).

```swift
// Core/Ports.swift

/// Sparkle's automatic path. Real: SparkleUpdates. Test: InMemoryUpdateService.
@MainActor public protocol UpdateService: AnyObject {
    /// On the main actor, in cycle order: any number of `.noUpdate`/`.checkFailed`/`.updateFailed`, or `.held` once per
    /// cycle, after which only `.updateFailed` can follow (the held update was lost). Nothing before `start()`.
    var onEvent: (@MainActor (UpdateEvent) -> Void)? { get set }
    /// Starts the updater and its 24 h wall-clock schedule (sleep counts). Returns at once. Sets the process's cookie
    /// policy to never and its URL cache to nothing, before the first request. Every request carries the same fixed
    /// headers on every Mac and version, no query string, no cookie, no validator. A misconfiguration (no feed, no key)
    /// starts nothing, silently.
    func start()
    /// One background check now. A no-op while a cycle runs or an update is held.
    func check()
    /// Arranges for the copy at this bundle's path to be opened silently, with `--after-update`, once this process has
    /// ended: whether it is the new version or, after a failed install, the old one, within the bound (R11). Nothing of
    /// ours runs it; it is nobody's child. Returns whether it is arranged; false leaves nothing armed.
    func arrangeRelaunch() -> Bool
}

/// R8's minute. Real: WallClockMinute. Test: InMemoryIdleMinute.
@MainActor public protocol IdleMinute: AnyObject {
    /// Calls `passed` once, on the main actor, one minute of awake time later, unless cancelled or started again first.
    /// At most one runs. Costs nothing until it fires.
    func start(then passed: @escaping @MainActor () -> Void)
    func cancel()
}

/// Whether the network is there. Real: NetworkReachability. Test: InMemoryConnectivity.
@MainActor public protocol Connectivity: AnyObject {
    /// Calls `connected` once, on the main actor, the next time the default route goes from unreachable to reachable;
    /// never for the state at the call. Replaces an earlier wait. A push from the system, never a poll, no request made.
    func waitForConnection(then connected: @escaping @MainActor () -> Void)
    func stopWaiting()
}

/// TrackpadEvent gains one case; both hardware adapters produce it.
public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent), swipe(SwipeEvent), windowSwipe(SwipeEvent), swap(SwapEvent)
    /// A pad went from no contact to some, or back: at most two per touch sequence, in frame order.
    case contact(ContactEdge)
    case trackpadsChanged
}
```

#### 1. Which Sparkle path, and what crosses into our code

The documented automatic path (A1): `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUVerifyUpdateBeforeExtraction` in the Info.plist through `project.yml`, `SPUUpdater(hostBundle:applicationBundle:userDriver:delegate:)`, a user driver that shows nothing and answers `.dismiss` to everything (A2 requires one; on this path it is never called, and a call means the path was left). XPC services stay in the bundle (G6: unused, harmless, export signs them). Public API used: `start`, `checkForUpdatesInBackground` (once, right after start, the moment the docs bless, A8), `userAgentString`, `httpHeaders`, and five delegate methods: `bestValidUpdate(in:for:)` (R4), `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)` returning true (hold; the handler is never invoked), `updater(_:didFinishUpdateCycleFor:error:)` (the one event source), `updater(_:didFindValidUpdate:)` (marks that an offer was chosen this cycle, to tell `.checkFailed` from `.updateFailed`), and `updater(_:didAbortWithError:)` is not needed (the cycle end carries the error).

Private behaviour we depend on, all in one file, `SparklePrivate`, each fact with the Sparkle source it was read from and the version it was read at, so an upgrade re-checks three lines:

- the extracted update's location, `~/Library/Caches/<id>/org.sparkle-project.Sparkle/Installation/<r>/<r>/<name>.app` (D4, `AppInstaller.m`);
- the installer job's launchd label, `<id>-sparkle-updater` (D5, `SUInstallerLauncher.m`);
- that a plain exit installs without a relaunch unless the immediate handler ran (A5, documented in the header, so public in effect).

`import Sparkle` is confined to `SparkleUpdates.swift` by the scan. `SparklePrivate` imports nothing of Sparkle: paths and a label only.

```swift
// Platform/SparkleUpdates.swift
@MainActor public final class SparkleUpdates: NSObject, UpdateService {
    public var onEvent: (@MainActor (UpdateEvent) -> Void)?
    private let copy: UpdatableCopy
    private let signer: Signer          // this process's team and identifier: R6's second half
    private let bundle: URL             // Location.running
    private let build: String           // CFBundleVersion at start: the job's "changed" test
    private let driver = SilentDriver() // every answer .dismiss; a call on it is a path this design never takes
    private var updater: SPUUpdater?
    private var offerThisCycle: UpdateOffer?

    public func start() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .never                       // E2, E3
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)             // no validators (Preserve 5)
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        updater.userAgentString = "TrackpadLauncher"                              // E1: default names the version
        updater.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]
        guard (try? updater.start()) != nil else { return }                        // misconfigured: no updates, silently
        self.updater = updater
    }
    public func check() { updater?.checkForUpdatesInBackground() }               // no-op with sessionInProgress (A3)
    public func arrangeRelaunch() -> Bool { HandOverJob.submit(bundle: bundle, oldBuild: build) }
}

extension SparkleUpdates: SPUUpdaterDelegate {        // NS_SWIFT_UI_ACTOR: the conformance is main-actor isolated
    /// R4 is ours: the whole list, one pure rule. `emptyAppcastItem` when nothing counts, so Sparkle never picks for us.
    /// Sparkle still requires the chosen item's CFBundleVersion to be above the running one (SUAppcastDriver), so the
    /// build number must rise with every release: the release script enforces it.
    public func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {   // -bestValidUpdateInAppcast:forUpdater:
        let parsed = appcast.items.compactMap { item in UpdateOffer(item).map { (item, $0) } }
        guard let chosen = FeedPolicy.choose(from: parsed.map(\.1), for: copy) else { return SUAppcastItem.empty() }   // +emptyAppcastItem
        return parsed.first { $0.1 == chosen }?.0
    }
    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { offerThisCycle = UpdateOffer(item) }

    /// Stage 1 is done: EdDSA verified, extracted, installer waiting (A3). Hold, always; never invoke the handler (B1-B3).
    /// Then R6's second half, off the main actor (19 ms, M40): every extracted bundle must be this team's, this
    /// identifier's, notarised, and sealed with the offered version and minimum; one that is not is vetoed.
    public func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                        immediateInstallationBlock handler: @escaping () -> Void) -> Bool {
        guard let offer = offerThisCycle else { veto(); return true }
        let signer = signer, id = Bundle.main.bundleIdentifier!
        Task { @concurrent in
            let bundles = SparklePrivate.extractedUpdates(for: id)
            let genuine = !bundles.isEmpty && bundles.allSatisfy {
                CodeSignature.isGenuine($0, team: signer.team, identifier: signer.identifier,
                                        version: offer.version, minimumMacOS: offer.minimumMacOS)
            }
            await MainActor.run { genuine ? self.onEvent?(.held(offer)) : self.veto() }
        }
        return true
    }

    /// The one event source. 1001 is "up to date"; an error before an offer was chosen is a failed check; anything
    /// else, a nil error with no hold included (A10's dismissed authorisation), is a failed update.
    public func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor check: SPUUpdateCheck, error: Error?) {
        defer { offerThisCycle = nil }
        // TODO: pseudocode
        //   error nil and held this cycle         → nothing (the hold stalls the cycle; this is the lost-helper path only when error != nil)
        //   error code 1001                       → .noUpdate
        //   error != nil, offerThisCycle == nil   → .checkFailed
        //   otherwise                             → .updateFailed
    }

    /// D5 plus a belt: removing the job ends the cycle (4005 reaches the delegate, the model goes idle, the schedule
    /// tries again in 24 h); discarding the extracted bundles leaves an installer that survived the removal nothing to
    /// install, so the next termination installs nothing (R6: "install nothing and show nothing").
    private func veto() {
        SparklePrivate.removeInstallerJob(for: Bundle.main.bundleIdentifier!)
        SparklePrivate.discardExtractedUpdates(for: Bundle.main.bundleIdentifier!)   // through BundleInstall.discard
    }
}

extension UpdateOffer {
    /// Parsed at the boundary: display version and minimum as `Version`s, the enclosure URL. nil for an item that
    /// cannot be an offer (no version, no minimum, no enclosure, information-only, delta).
    init?(_ item: SUAppcastItem) { fatalError("not implemented") }
}

/// Shows nothing and agrees to nothing. On the automatic path Sparkle never consults it.
@MainActor final class SilentDriver: NSObject, SPUUserDriver { /* every reply .dismiss; every acknowledgement called */ }
```

```swift
// Platform/SparklePrivate.swift — the only file that knows Sparkle's private layout. Re-check on every Sparkle upgrade.
enum SparklePrivate {
    /// Sparkle 2.10.1, Autoupdate/AppInstaller.m: `<caches>/<id>/org.sparkle-project.Sparkle/Installation/<r>/<r>/`.
    static func extractedUpdates(for bundleID: String) -> [URL]
    /// Sparkle 2.10.1, InstallerLauncher/SUInstallerLauncher.m: label `<id>-sparkle-updater`, user launchd domain.
    @discardableResult static func removeInstallerJob(for bundleID: String) -> Bool       // SMJobRemove
    static func discardExtractedUpdates(for bundleID: String)                            // BundleInstall.discard on each
}
```

#### 2. Ownership

`Updater` survives as the one owner of update decisions, in `LauncherCore`, no longer `@Observable` (nothing renders it). It owns: the gate's value, the start rule, the retry rule, R8's wait, the hand-over order, the after-update start rule. `Lifecycle` learns `Opening.afterUpdate`, one `Route` row, `updater?.start(opening)` in `othersExited`, and loses `isInstalling` from both quit paths; `onReplaced` becomes `onHandOver`. `Launcher` learns one `TrackpadEvent` case to forward and one call after `hardware.run`. The gate stays an object's absence (`Preserve 6`): no `Updater`, no Sparkle object, no network path; the Sparkle object itself is made inside `SparkleUpdates.start()`, which only a resident calls.

Interface depth: the public surface is `start(_:)`, four fact-reporting methods and one callback; behind it sit the hold-and-verify protocol with Sparkle, the veto, the idle rule, the retry rule and the hand-over. A caller learns the facts to report and nothing of Sparkle.

#### 3. R8's gate: contact, window, the minute

Contact is read at `DeviceSession.receive`, on `frame.touches` before the recognizer (H2): it sees palms and edge contacts, not hovers, and resets with every `run`. The session keeps one frame-thread flag, `wasOccupied`, behind a `Mutex` as the recognizer is, and calls `deliver` only on a flip: at most two main hops per touch sequence, zero while nothing touches the pad (H1). `MultitouchTrackpads`' generation guard drops an edge from a replaced session; `trackpadsRestarted()` makes that harmless. `InMemoryTrackpads.touch` produces the same edges per scripted frame, so `LifecycleWorld.tap` drives R8.

```swift
// Platform/FrameStream.swift, DeviceSession.receive, after the recognizer step:
let occupied = !frame.touches.isEmpty
let flipped = wasOccupied.withLock { let f = $0 != occupied; $0 = occupied; return f }
if flipped, occupied { deliver(.contact(ContactEdge(trackpad: trackpad, phase: .began)), nil) }
// ... existing event delivery ...
if flipped, !occupied { deliver(.contact(ContactEdge(trackpad: trackpad, phase: .ended)), nil) }
```

The window's edges come from `Launcher.openedByHand` and `closeWindow` as today (H4); a minimised or hidden window stays open and blocks.

The minute is a one-shot `DispatchSourceTimer` on the main queue, on the monotonic clock (`deadline:`, which does not advance in system sleep), leeway a few seconds, in one file, armed only while a verified update waits with no blocker, cancelled on any blocker, restarted by `run` (so a wake restarts it). It costs no wakeup until it fires. This is a reasoned amendment of `docs/architecture.md:20`, not a bypass (`Change 4`): the rule becomes "no timers, no polling, no background loops, with one exception: the update's idle minute, a one-shot source that exists only while a verified update waits for a minute with nothing on the trackpads and the window closed, re-armed by the edges that end that state, never while no update waits; Sparkle's own 24-hour wall-clock timer lives in its framework". The scan moves `makeTimerSource` from `banned` to `confined` (`IdleMinute.swift`); `Timer`, `asyncAfter`, `Task.sleep` stay banned. `LaunchClock` was rejected for this (see Alternatives): a render-server animation may stretch across display sleep and reports passed on a system stop (H5), and the display asleep is exactly when the install should land.

```swift
// Platform/IdleMinute.swift
@MainActor public final class WallClockMinute: IdleMinute {
    private var source: DispatchSourceTimer?
    public func start(then passed: @escaping @MainActor () -> Void) {
        cancel()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + .seconds(60), leeway: .seconds(5))
        source.setEventHandler { [weak source] in
            guard let source, !source.isCancelled else { return }
            source.cancel()
            MainActor.assumeIsolated { passed() }
        }
        source.resume()
        self.source = source
    }
    public func cancel() { source?.cancel(); source = nil }
}
```

#### 4. The hand-over, R9 and R11

Order of effects when the minute passes (B4, proven in `selfquit.out`, `applications.out`, `survival.out`):

1. `Updater` asks `service.arrangeRelaunch()`: `HandOverJob.submit` registers a one-shot launchd job in the user domain with `SMJobSubmit` (deprecated, and what Sparkle itself uses for both helpers, B5). The job is nobody's child. If launchd refuses, nothing is armed and the update waits for the next end of the process (`.untilQuit`).
2. `Updater` goes `.handingOver` and calls `onHandOver`; `Lifecycle.end()` sets `.ending` and terminates. `shouldEnd` answers yes. Starting at login is untouched (B8).
3. The process exits. Sparkle's `Autoupdate` sees the termination and installs with no relaunch (A5): an atomic `renamex_np` swap under a shared Team ID (C4), owner and group kept (B10), the installed copy's name kept (B9).
4. The job, which has been waiting for this pid to exit, waits for the bundle's `CFBundleVersion` to differ from the old build, bounded by 6 s of wall time, then runs `/usr/bin/open -g -a <bundle> --args --after-update` and exits. On a failed install (C1) the version never changes, the bound passes, and the same `open` starts the whole old copy (C4's restore): 6 s plus 0.2 s to open plus about a second to gestures is under R11's 10 s. C2's 7.4 s came from an unbounded count of `plutil` spawns; the bound here is wall time.
5. The new process reads `--after-update` as `Opening.afterUpdate`; `Route(.afterUpdate, .installed, _)` is `.runSilently`: no window, the accessory policy, no activation (H8), and it stops every other copy (B7). It does not check for updates at start (a failed install would otherwise hand over again a minute later); Sparkle's schedule, from `SULastCheckTime`, tries again in 24 h (R11 "a later check").

If the process dies at each step: before 1, Sparkle installs at that termination and nothing relaunches; the next login or opening starts the new version (R8 "the next start keeps the update waiting"). Between 1 and 2, the job behaves as in 4. After 2, as designed. If the job never runs (launchd accepted it and did not run it), nothing runs until the next opening or login: P022:1082's accepted cost, now narrower. If the new copy crashes at start, the same, by the glossary's rule that nothing relaunches after a crash.

The shell inside the job is the one place a shell waits; `why.md` Avoid 4 and 5 were written for hand-overs with the old process alive (D-1) and do not weigh R11, which only something outside the old process can satisfy (C3). The argument is the only signal: positive, one-shot, never persisted, so a lost relaunch leaves nothing stale and the next opening by hand opens the window as usual (B6).

```swift
// Platform/HandOverJob.swift — the one-shot job that opens the installed copy after this process has ended.
enum HandOverJob {
    /// One label per bundle identifier; a stale job of that label is replaced.
    static func label(for bundleID: String) -> String { "\(bundleID).hand-over" }
    /// true when launchd accepted the job. `/bin/sh` is the program; the script is the one below, with the pid, the
    /// bundle path, the old build and the bound as its arguments. No Authorization right is asked (B5).
    static func submit(bundle: URL, oldBuild: String, bound: Duration = .seconds(6)) -> Bool { fatalError("not implemented") }
    static let script = """
        pid=$1; bundle=$2; old=$3; bound=$4
        while kill -0 "$pid" 2>/dev/null; do sleep 0.05; done
        start=$SECONDS
        while [ $((SECONDS - start)) -lt "$bound" ]; do
          now=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null) && [ "$now" != "$old" ] && break
          sleep 0.1
        done
        exec /usr/bin/open -g -a "$bundle" --args --after-update
        """
}
```

```swift
// Core/Lifecycle.swift
public enum Opening: Equatable, Sendable {
    case atLogin
    case byHand
    /// Opened by the hand-over job after an update, the argument `--after-update`: silent, and it stops every other copy.
    case afterUpdate
}
// Route.init gains two rows; the switch stays exhaustive:
//   case (.afterUpdate, .elsewhere, _): self = .askToMove             // only a hand-typed argument reaches this
//   case (.afterUpdate, .installed, _), (.afterUpdate, .development, _): self = .runSilently
// Stage.replacingOthers carries the Launch, so othersExited can hand the opening to the updater:
//   case replacingOthers(launch: Launch, opensWindow: Bool)
```

#### 5. R13 and R14: every way to quit, in every update state

| Way out | `idle` / `awaitingConnection` | `holding` | `handingOver` |
|---|---|---|---|
| Quit Trackpad Launcher | ends, login off | ends, login off; Sparkle installs at termination, no relaunch, no job (A5, `plainquit.out`); stays stopped | same as `holding` (the job is already armed: the relaunch happens; the user pressed Quit a few milliseconds before the process ended anyway) |
| Close Settings, ⌘W, Escape, Close, Dock Quit | window closes | window closes; the edge may start the minute | window closes |
| A script's or peer's quit, window closed | ends | ends; installs at termination, no relaunch | ends |
| Logout, restart, shutdown | ends at once | ends at once; `Autoupdate` installs during the logout or is killed with the session, whole either way (C4); the next login starts whichever whole copy is there, and a kept download (A4) is re-verified by the next check | ends at once |

Nothing is left armed that restarts the app later: the immediate handler is never invoked (B3's hazard cannot arise), `arrangeRelaunch` is called only from the minute's fire, and `Quit` and `.system` never reach it. The `holding` row of `handingOver` is a window of milliseconds and is accepted.

#### 6. R6: both halves, the veto, a failed veto

First half, the update key: `SUPublicEDKey` in the plist, `SUVerifyUpdateBeforeExtraction` on, and `FeedPolicy` admitting only `.aar` enclosures under this repository's download prefix. An `.aar` cannot carry a code signature, so Sparkle's Developer-ID-disk-image fallback (D3) is unreachable; only the key admits an update. Second half, same Developer ID and identifier: at `willInstallUpdateOnQuit`, off the main actor, `CodeSignature.isGenuine` on every extracted bundle (D4), with this process's team and identifier, `notarized` (kept, `Change 10`: R7 guarantees it, the stapled ticket makes it offline and 19 ms), strict nested validation, and the sealed version and minimum equal to the offer. A mismatch vetoes (D5): the installer job is removed, which ends Sparkle's cycle with 4005 and takes the model to `.idle`, and the extracted bundles are discarded. If `SMJobRemove` fails, the discard still holds: an installer that reaches stage 3 with nothing to install fails and exits (C1's path), and nothing changes in /Applications. If both fail, the installer is armed with a bundle that passed EdDSA with our key and Sparkle's Gatekeeper pre-scan: that is a stolen update key and a failed authorisation call on one Mac at once, and it is named in Open questions rather than papered over.

#### 7. R1: every start, every 24 hours, wake, and a connection after a failure

Every start: `checkForUpdatesInBackground()` right after `start()`, except an after-update start. Every 24 hours: Sparkle's own one-shot `dispatch_walltime` source, re-armed after each cycle (A9), so a Mac that sleeps past the mark checks on wake. A connection after a failure: `.checkFailed` arms `NetworkReachability`, a `SCNetworkReachability` callback on the main run loop for the default route (no DNS, no request, a push from `configd`); it reports only a not-reachable-to-reachable flip, once, and is consumed by the one retry. A persistent failure with a stable network produces no flip and no retry until the schedule; a flapping network produces at most one feed request per flip. The interval in Sparkle restarts from each check (`SULastCheckTime`), which is the behaviour R1 asks for.

```swift
// Platform/NetworkReachability.swift
@MainActor public final class NetworkReachability: Connectivity {
    private var target: SCNetworkReachability?
    private var wasReachable: Bool?
    public func waitForConnection(then connected: @escaping @MainActor () -> Void) {
        stopWaiting()
        // TODO: SCNetworkReachabilityCreateWithAddress over a zero sockaddr_in (the default route);
        //       SCNetworkReachabilitySetCallback with a context carrying `connected`;
        //       SCNetworkReachabilityScheduleWithRunLoop(main, common modes);
        //       the callback computes reachable = flags.reachable && !flags.connectionRequired, and on a false→true flip
        //       calls stopWaiting() then connected(), inside MainActor.assumeIsolated.
        fatalError("not implemented")
    }
    public func stopWaiting() { /* unschedule, drop the target */ }
}
```

#### 8. R2 and R12: the gate

Decided once at start, in `applicationWillFinishLaunching`, by `UpdatableCopy.init?`: `Placement.installed` (inside /Applications, not translocated), `developerIDSigner() != nil` (takes no arguments; `--as-release-build` cannot fake it), and `BundleInstall.canReplace(bundleAt:)`, the same expression `put` uses today (parent writable and bundle writable, what the atomic swap needs), extracted and shared with the move. A copy that fails any term has no `Updater`, no Sparkle object, no network path, no prompt; it checks again at its next start (R12). A copy showing the move dialog is `.elsewhere` by construction. A development build has no signer. The Debug and perf builds carry Sparkle's plist keys and never build an `Updater`. If the account's writability changes while the process runs, Sparkle's own rule (A11) stops at `AuthorizeLater`, the silent driver dismisses, no prompt appears (A10), and the model sees `.updateFailed`.

#### 9. R3: what a request carries

`userAgentString = "TrackpadLauncher"`, `httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]` (E1: applied to the feed and the download, across the redirect), `HTTPCookieStorage.shared.cookieAcceptPolicy = .never` before the first request (E2, E3), `URLCache.shared` at zero capacity so no `If-None-Match` or `If-Modified-Since` can be sent on a repeat, no `SUEnableSystemProfiling` (E6; the scan's `neverDeclared` gains it). The feed lives on `raw.githubusercontent.com` (E4, F4: 200, no redirect, no cookie), the enclosure on `/releases/download/<tag>/<asset>` (E4: no cookie; E5: one redirect to `release-assets.githubusercontent.com`, followed with the same headers). Neither address carries a query string. The feed's address is in `project.yml` as `SUFeedURL`; the download prefix in `FeedPolicy`, the one `http` in Swift.

#### 10. The feed and the release

The feed is a committed file, `appcast.xml` at the repository root on `main`, served raw. Each release appends one `<item>` at the top and keeps every older item, so a Mac on an older macOS still finds the highest it can run (F2, R4's third scenario). The enclosure is the same `.aar` the card reads (A6, F7): one asset, one contract. `generate_appcast` is not used (F5); `sign_update --ed-key-file` is replaced by the keychain key (`generate_keys` stores it there; F6) and a rendered item.

Build-number discipline: Sparkle compares `CFBundleVersion` (F1) after our choice, so `preflight_version` now also requires `CURRENT_PROJECT_VERSION` above every `<sparkle:version>` in `appcast.xml` and above the previous tag's build. The key: `generate_keys -p` must print the `SUPublicEDKey` in `project.yml`, or the release stops before anything changes; the private key's export (`generate_keys -x`) to the developer's password manager is a documented manual step, because with `.aar`-only enclosures it cannot be rotated (see Tradeoffs).

Order of effects, with what each failure leaves behind:

```sh
# Scripts/release.sh, new or changed steps (sketch; existing steps unchanged unless named)

FEED="$ROOT/appcast.xml"
SPARKLE_BIN="$ROOT/LauncherKit/.build/artifacts/sparkle/Sparkle/bin"   # swift test resolves it; release runs the tests first

preflight_update_key() {                                 # in preflight_checkout, before anything changes
  local declared keychain
  declared="$(sed -n 's/^ *SUPublicEDKey: *//p' "$ROOT/project.yml")"
  keychain="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null)" || fail "no Sparkle update key in the login keychain; import it with generate_keys -f."
  [ "$declared" = "$keychain" ] || fail "the update key in the keychain is not the one project.yml trusts."
}

preflight_build_number() {                                # in preflight_version
  local build highest previous_tag previous_build
  build="$(read_setting CURRENT_PROJECT_VERSION)"
  highest="$(sed -n 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/p' "$FEED" | sort -n | tail -1)"
  [ "$build" -gt "${highest:-0}" ] || fail "build $build is not above the feed's highest ($highest); Sparkle compares build numbers."
  previous_tag="$(git -C "$ROOT" tag --list 'v*' | sort -V | tail -1)"
  previous_build="$(git -C "$ROOT" show "$previous_tag:Config/Version.xcconfig" | sed -n 's/^CURRENT_PROJECT_VERSION *= *//p')"
  [ "$build" -gt "${previous_build:-0}" ] || fail "build $build is not above $previous_tag's $previous_build."
}

# archive_and_check gains the two rules the deleted card code enforced and the script did not (F9):
#   every entry under TrackpadLauncher.app/, no '.' or '..', symlinks relative and inside:
#     aa list -v -i "$AAR" | awk '...' || fail "an entry breaks the card's entry rules"
#   the genuineness requirement, strict, nested, offline, with the stapled ticket:
#     codesign --verify --strict --deep -R="anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$TEAM_ID\" and identifier \"$BUNDLE_ID\" and notarized" "$copy"
#     || fail "the unpacked app fails the card's genuineness requirement"
# These are the frozen rules of versions 1.0.0 to 1.0.15; the comment above them says so and names the deleted Swift.

render_feed_item() {                                      # after archive_and_check, before the image: the .aar is final
  local signature length
  signature="$("$SPARKLE_BIN/sign_update" "$AAR")"      # prints sparkle:edSignature="..." length="..."
  ITEM="$(cat <<XML
    <item>
      <title>$EXPECTED_VERSION</title>
      <sparkle:version>$(read_setting CURRENT_PROJECT_VERSION)</sparkle:version>
      <sparkle:shortVersionString>$EXPECTED_VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_MACOS</sparkle:minimumSystemVersion>
      <pubDate>$(date -R)</pubDate>
      <enclosure url="https://github.com/$REPOSITORY/releases/download/v$EXPECTED_VERSION/$(basename "$AAR")" $signature type="application/octet-stream"/>
    </item>
XML
  )"
}

write_feed() {                                            # the new item first, every older item kept; the file is not committed yet
  # insert $ITEM after <channel>...<title> in $FEED (awk); fail if $FEED has no <channel>
}

publish_feed() {                                          # after gh release create: the asset exists before the feed names it (Preserve 13)
  git -C "$ROOT" add "$FEED"
  git -C "$ROOT" commit --quiet -m "Feed $EXPECTED_VERSION" -- "$FEED"
  git -C "$ROOT" push --quiet origin HEAD:main ||
    fail "v$EXPECTED_VERSION is published but the feed is not; run release.sh --feed-only $EXPECTED_VERSION."
}

# cleanup(): on a failure before the push, also `git -C "$ROOT" checkout -- "$FEED"` so the worktree is clean for the retry.
# --feed-only <version>: downloads the published .aar, re-renders the item, write_feed, publish_feed. Idempotent: a
#   version already in the feed is replaced, not duplicated.
# Scripts/test.sh: `exec swift test --disable-keychain "$@"`; both xcodebuild calls add `-packageAuthorizationProvider netrc` (G3).
# LauncherKit/Package.resolved is committed (G4).
# Main sequence: preflight_checkout (+key) → tests → bump → preflight_version (+build) → archive → export → notarise →
#   archive_and_check (+rules) → render_feed_item → write_feed → image → notarise → push version commit → gh release create → publish_feed
```

What a failure leaves: before the push, the version commit is undone and `appcast.xml` restored, nothing published, nothing seen (R7: notarisation fails before the push). Between `gh release create` and `publish_feed`: the release is published, older cards see it (R16), Sparkle copies do not until `--feed-only` pushes the feed; nothing is half-published to either reader, because the feed changes in one commit and the asset was uploaded before publishing.

`project.yml` gains, in `info.properties`: `SUFeedURL: https://raw.githubusercontent.com/domasgru/trackpad-launcher/main/appcast.xml`, `SUPublicEDKey`, `SUEnableAutomaticChecks: true`, `SUAutomaticallyUpdate: true`, `SUVerifyUpdateBeforeExtraction: true`, `SUScheduledCheckInterval: 86400`. `Package.swift` gains `.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")` and the product on `LauncherPlatform` (G1, variant A: no `project.yml` change, `swift test` loads it, the adapter sits with every other real adapter).

#### 11. R16: every future release installable from the card

Every release keeps the asset the card requires (F7): the `.aar` named `TrackpadLauncher-<v>-macOS-<min>.aar`, uploaded before publishing, exactly one bundle `TrackpadLauncher.app` inside, stapled, same team and identifier, sealed version and minimum equal to the name's. Sparkle's enclosure is that asset, so there is no second `.aar` (Avoid 10). The card's deleted Swift rules move into `archive_and_check` as shell (`admits`' entry rules over `aa list`, `isGenuine`'s requirement text through `codesign -R`), marked as frozen, run on every release and by `--archive-only`. The first automatic version arrives through the old card as an opening by hand with a window: old code writes nothing, the new copy sees no argument, `Route` is `.runWithWindow` (Preserve 3). The first notarised build with Sparkle goes through `--archive-only` and a real 1.0.15 copy before it is published (Risk 9).

#### 12. Build

Sparkle is a dependency of `LauncherPlatform`, pinned `exact: "2.10.1"`, `Package.resolved` committed. Export re-signs every helper with the Developer ID and keeps the hardened runtime; no `--deep`, no entitlements (G2). `swift test --disable-keychain` and `-packageAuthorizationProvider netrc` on `xcodebuild` keep the artifact step off the keychain (G3; cold-cache behaviour is an open risk). Sparkle loads in every build (G5): accepted, measured later.

#### 13. Deletions and the rules

Deleted whole: `Core/Updater.swift`'s state machine (replaced in place), `Release`, `UpdateEvent`'s old cases, `UpdateCard` and `Layout`, `Platform/GitHubReleases.swift`, `Platform/ApplicationsUpdater.swift`, `UI/UpdateCardView.swift`, `BundleInstall`'s AppleArchive half (`extract`, `admitted`, `unpack`, `admits`, `MemoryStream`), the `UpdateInstaller` and `ReleaseList` ports, `Copy.update*`, `SettingsView`'s card and Quit-disable, `SettingsShell.updater` and `Fit.card`, the update test suites, fixtures and `Scripts/make-update-fixtures.sh`. Kept: `Version`, `Signer`, `CodeSignature.isGenuine` (reshaped to take team, identifier, version and minimum), `ThisCopy.version()`, `macOS()`, plus a new `build()`; everything the move uses (`Installer`, `ApplicationsInstaller`, `PrivilegedInstall`, `BundleInstall.stage/swap/discard/...`). `InstalledRelease` becomes `UpdatableCopy`.

`SourcePolicyTests` rows, each a deliberate change:

| Row | Change | Why |
|---|---|---|
| `URLSession` confined to `GitHubReleases.swift` | becomes `banned` | our Swift makes no request at all; Sparkle makes the one kind |
| `http` confined to `GitHubReleases.swift` | confined to `FeedPolicy.swift` | the one address downloads may come from; the feed's address is in `project.yml` |
| `downloadTask`, `.download(` rule text | reworded: "our Swift downloads nothing; Sparkle receives the update into its own cache" | tokens stay (`required`) |
| `makeTimerSource` banned | confined to `IdleMinute.swift` | the one timer, rule amended on purpose |
| `createsNewApplicationInstance`, `AppleArchive`, `ArchiveStream`, `ArchiveByteStream` confined rows | removed | no code, no vacuous allowance |
| "nothing relaunches the app" rule text | "nothing relaunches the app after a crash or a force quit; the hand-over job opens it once after an update" | tokens stay banned |
| new confined: `import Sparkle` → `SparkleUpdates.swift`; `SMJob` → `HandOverJob.swift`, `SparklePrivate.swift`; `/bin/sh` → `HandOverJob.swift`; `org.sparkle-project`, `-sparkle-updater` → `SparklePrivate.swift`; `after-update` → `ThisCopy.swift`, `HandOverJob.swift`; `SCNetworkReachability`, `import SystemConfiguration` → `NetworkReachability.swift`; `HTTPCookieStorage`, `URLCache` → `SparkleUpdates.swift` | added | each coupling has one home |
| `neverDeclared` | adds `SUEnableSystemProfiling`, `SUEnableInstallerLauncherService`, `SUEnableDownloaderService` | R3; not sandboxed |
| new `alwaysDeclared` list over `project.yml` | `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUVerifyUpdateBeforeExtraction` | the automatic path's keys cannot be lost silently (`per encode-lessons-in-structure`) |

Standing rules in `docs/architecture.md` changed on purpose: line 11 (ownership, the silent after-update start, the quit table), 12 (modules: `LauncherPlatform` adds Sparkle, SystemConfiguration's reachability, ServiceManagement's job submission; URL Loading and AppleArchive leave), 20 (the timer exception above; reachability as a push), 27 to 32 (network: Sparkle's feed and download are the one kind; files: Sparkle's caches, defaults and the kept download; processes: Sparkle's two helpers and the one-shot hand-over job; logging: our code logs nothing, Sparkle's helpers write to the unified log locally, D-5), 35 to 36 (the feed, the key, the build number). `docs/domain-model.md`: drop *Update card*; *Update check* and *Newer version* redefined; *Opened by hand* loses "by an update opening the new version"; *Quit Trackpad Launcher* loses the greyed-out state; *Starting at login*'s "never relaunches itself" gains "the hand-over job opens it once after an update"; new entries *Automatic update* and *Hand-over*. `README.md:17-18, 34, 69-72` and `docs/product-overview.md:8` follow.

#### 14. Testing seam

The seam is `LifecycleWorld` / `OneProcess` over real `Lifecycle`, `Launcher` and `Updater`, as today. Handles a test needs on everything it cannot wait for or provoke:

| Thing | Handle |
|---|---|
| the minute | `InMemoryIdleMinute`: `isCounting`, `pass()` (fires the latest start only; a `pass()` after `cancel()` fires nothing) |
| contact edges | `InMemoryTrackpads.touch` produces `.contact` per scripted frame, so `process.tap(1)` is a began and an ended edge |
| the window | `openAgain(.byHand)`, `closeWindow()`, `shouldEnd(.other)` |
| `run` | `process.preferences.push()` or `hardware.wake()` reaches `trackpadsRestarted()` through the real `reconcile` |
| connectivity | `InMemoryConnectivity`: `isWaiting`, `connect()` |
| Sparkle's callbacks | `InMemoryUpdateService`: `starts`, `checks`, `deliver(.noUpdate / .checkFailed / .updateFailed / .held(offer))`, `relaunchesArranged`, `arrangeAnswer: Bool` |
| the process ending | `InMemoryRunningCopies.hasEnded` through `shouldEnd(.other)`, as today; `EffectLog` records `"arrangeRelaunch"` and `"endThisCopy"` in order |
| the gate | `RunningBuild.release(version, macOS:, canWrite:)` through the real `UpdatableCopy.init?` |
| the start class | `world.launch(.afterUpdate, others: [...])`: silent, stops everyone, `checks == 0`; `.byHand` and `.atLogin`: `checks == 1` |
| R4 | `FeedPolicy.choose` directly, pure |

Scenarios that cannot run below a built, signed app, and run on a notarised build with the spike's shape instead (K): the wire (headers, no cookie, no validator against real GitHub), EdDSA, the hold, the veto, the swap, the silent relaunch and its 10 s, the failed-install recovery, TCC and the login item across the swap (R10), a real logout with an update waiting (R14, D-3), 1.0.15's card installing the first automatic version (R16).

#### Module map

- `LauncherCore`: `Updater` (model), `Update` (`UpdatableCopy`, `UpdateOffer`, `UpdateEvent`, `ContactEdge`), `FeedPolicy`, `Version`, `Ports` (`UpdateService`, `IdleMinute`, `Connectivity`, `TrackpadEvent.contact`), `Lifecycle` (`Opening.afterUpdate`, `Route`, `onHandOver`), `Launcher` (forwarding).
- `LauncherPlatform`: `SparkleUpdates` (the adapter; `import Sparkle`), `SparklePrivate` (two private facts), `HandOverJob`, `IdleMinute` (`WallClockMinute`), `NetworkReachability`, `CodeSignature.isGenuine` (reshaped), `BundleInstall.canReplace`, `ThisCopy` (`--after-update`, `build()`), `FrameStream` (`DeviceSession.wasOccupied`).
- `LauncherUI`: the card and its wiring removed; nothing added.
- App target: `makeUpdater` as in Usage.
- Tests: `InMemoryUpdateService`, `InMemoryIdleMinute`, `InMemoryConnectivity`, `InMemoryTrackpads.touch` edges, `LifecycleWorld` intents (`holdUpdate`, `passMinute`, `connect`, `failCheck`).
- Release: `appcast.xml`, `Scripts/release.sh` (above), `LauncherKit/Package.resolved`, `project.yml` keys.

Concurrency: `Updater`, the three ports and `SparkleUpdates` are `@MainActor`; `SPUUpdater` and both Sparkle protocols are `NS_SWIFT_UI_ACTOR`, so the conformances are main-actor isolated with no `nonisolated` escape. The genuineness check runs in a `Task { @concurrent in }` and hops back with `MainActor.run` for the one state change. The timer source and the reachability callback are scheduled on the main queue or run loop and enter with `MainActor.assumeIsolated`. The contact flag is frame-thread state behind a `Mutex` with one writer, as the recognizer is.

### Synthesis decision

### Tradeoffs accepted

- We accept two private Sparkle couplings (the extracted update's path, the installer job's label) in one file, re-checked on each upgrade, in exchange for R6's second half and a veto that stays silent and prompt-free.
- We accept a shell one-shot job with 50 ms and 100 ms sleeps, bounded by wall time, in exchange for a working copy within 10 s after a failed install, which nothing inside the old process can provide (C1, C3); `why.md` Avoid 4 and 5 are overridden for this one case, by D-1.
- We accept one timer of ours, a confined one-shot that exists only while a verified update waits, in exchange for installing during display sleep rather than at the moment the user returns; the no-timer rule is amended, not bypassed.
- We accept `.aar`-only enclosures, which makes the update key unrotatable for automatic copies, in exchange for R6's "carries a signature made with the update key" holding literally; the key's backup becomes a release-process obligation.
- We accept keeping the client's notarisation check beside R7, 19 ms off the main actor once per update, in exchange for the same protection the card had.
- We accept that an after-update start does not check at start, an exception to R1's "every start", in exchange for a failing install not handing over once a minute.
- We accept that a refused hand-over job leaves the update to install at the next end of the process with no relaunch, in exchange for never ending the process without a way back.
- We accept Sparkle loading, with WebKit, in every build (G5), and Sparkle's helpers writing to the unified log (D-5), in exchange for the documented common path; the privacy prose is narrowed to our own code.
- We accept process-wide cookie and cache settings, in exchange for no `Cookie` and no validator on any request; the app makes no other request.
- We accept `URLSession` becoming banned outright in our Swift, stricter than today.
- We accept Debug and perf builds carrying Sparkle's plist keys, in exchange for one Info.plist; the gate keeps them from ever building an `Updater`.

### Alternatives considered

- **Sparkle's immediate handler and stock relaunch** (B1, B2, B3): the quit arrives as `.other`, the relaunch arrives as an opening by hand with a window, and a refused quit leaves the installer armed with relaunch on, which breaks R13. It hides the hand-over but exposes a loud start and a stale-marker problem. Lost.
- **The UI-based driver with its public veto** (D6): a documented cancel, but it leaves the automatic path, loses A10's no-prompt guarantee for an unwritable copy, and shows a progress window past 0.7 s. Lost on R9, R12, R15.
- **`LaunchClock` for the minute**: no rule change, but a render-server animation may stretch across display sleep (017's accepted cost) and `Deadline` reports passed on a system stop (H5), so the install would land either late, when the user returns, or early. Lost to a confined monotonic one-shot.
- **A persisted marker for the silent start** (`UserDefaults` written at hand-over): needs a validity rule for a failed install and a lost relaunch, and a stale one makes a real opening look broken. The argument is positive and one-shot (B6). Lost.
- **The feed as a release asset**: immutable releases forbid a rolling asset (F3) and `/releases/latest/download/` sets cookies (E4). Lost to a committed file on `raw.githubusercontent.com`.
- **Folding the minute and connectivity into the Sparkle port**: two fewer ports, but the adapter would own three OS facilities and the test would lose separate handles on the clock and the network. Lost on testability.
- **`shouldProceedWithUpdate` instead of `bestValidUpdateInAppcast`**: a veto of Sparkle's choice rather than our choice; R4's "highest that counts" would then be Sparkle's by build number, not ours by version. Selection is ours; Sparkle's newer-by-build check stays as a second gate.
- **A fourth LauncherKit target for the adapter**: keeps Sparkle out of `LauncherPlatform`'s test link, unprobed, and the in-memory adapter is already the test seam. Lost on reader load.
- **`SURequireSignedFeed`**: a signed feed on top of the signed archive; the feed is ours and the enclosure is pinned to our downloads, so a tampered feed can at most replay a lower version, which `FeedPolicy` refuses. Not taken; noted as a later hardening.

### Open questions and risks

1. Does a real logout read as `.system` with the window open (D-3)? R14 rests on it today, Sparkle or not. Can the pending human check from plan 038 run before this ships?
2. Do the Accessibility and Screen Recording grants and the `SMAppService.mainApp` item survive a Developer ID, notarised Sparkle swap (R10, L2)? Same path, team and identifier say yes; only a notarised build on a real Mac shows it.
3. Where should the exported EdDSA private key live, and is the no-rotation tradeoff acceptable? A lost key strands every automatic copy at its version, with the hand-installed disk image as the only way forward.
4. On a cold cache, does `swift test --disable-keychain` finish, and does `xcodebuild -packageAuthorizationProvider netrc` resolve the binary target without a prompt (G3)? One cold run on this Mac answers it.
5. On a notarised build in /Applications, is the hand-over under 10 s end to end with the 6 s bound, on success and after a forced failure (C2)?
6. Against real GitHub, does the feed request stay free of `If-None-Match` with `URLCache.shared` at zero, across a relaunch? The spike's server sent no validators to provoke one.
7. Does `DispatchTime` pause across system sleep on macOS 26 and 27, so the minute is awake time? The `run`-at-wake reset makes the design hold either way; the answer only tightens the documentation's wording.
8. What is the memory cost of Sparkle and WebKit loading in every build (G5), against `docs/product-overview.md`'s promise?
9. If both the job removal and the discard fail in a veto, an installer stays armed with an update that passed EdDSA with our key: is "a stolen key plus a failed Authorization call" a case the human wants a third defence for, such as refusing to end the process voluntarily while such an update is armed?
10. Should the first automatic release be installed through a real 1.0.15 copy's card (R16) before it is published, as Risk 9 asks?

### Next implementation step

Add `TrackpadEvent.contact`, `ContactEdge` and the flip in `DeviceSession.receive` and `InMemoryTrackpads.touch`, with a `DeviceSessionAnswerTests` row that two frames with a contact and one empty frame deliver exactly one began and one ended edge, so R8's gate has its signal before the model is written.
