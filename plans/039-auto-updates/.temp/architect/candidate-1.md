## Design

### Problem

A new version reaches a user only through a card in a window most users never open. Sparkle 2 replaces the hand-written check, download and install, and the card goes. The shape is not obvious because Sparkle's silent path falls short of this app's rules in specific, probed ways. It installs at any end of the process and offers no cancel (A5, D5). Its immediate handler quits with an event `Lifecycle` reads as the Dock's Quit, relaunches as an opening by hand, stays armed after a refused quit, and recovers nothing from a failed swap (B1-B3, C1). It enforces neither half of "same Developer ID and identifier" (D1-D3). It keeps cookies (E2). Its scheduler misses "a check at every start" and "again when a connection arrives" (A7, A8). The design must also honour what is already here: `LauncherCore` imports Foundation and Observation only, every port has two adapters, the gate is an object's absence, `Opening` is matched exhaustively, the card's `.aar` contract outlives the card's code (F7, F9), releases are immutable (F3), and idle stays at zero (`why.md` Preserve 11).

### Usage (caller's view)

**The caller is the rest of the app.** There is no interface, so what a maintainer learns is small. The composition root builds an `Updater` only for a copy the gate lets through. `Lifecycle` starts it once the process is resident and ends the process when it asks. `Launcher` knows nothing about updates; it can be asked whether the app is in use. Everything else happens behind those three facts.

```swift
// Composition root. The gate is a value only `UpdatableCopy.init?` can make, and `Updater` will not build without one.
private func makeUpdater(placement: Placement, location: Location) -> Updater? {
    let signer = CodeSignature.developerIDSigner()
    guard
        let copy = UpdatableCopy(
            placement: placement, developerIDSigned: signer != nil,
            canReplaceItself: SparkleEngine.canReplace(location.running)),
        let signer
    else { return nil }
    return Updater(
        copy, engine: SparkleEngine(bundle: location.running, signer: signer),
        connection: SystemConnection(), clock: SystemIdleClock())
}
```

```swift
// Lifecycle: the only place it starts, so a copy about to end, or asking to move, never reaches the network.
private func othersExited() {
    guard case .replacingOthers(let opensWindow, let eject, let checksNow) = stage else { return }
    let launcher = makeResident()
    launcher.start()
    stage = .resident(launcher)
    if opensWindow { launcher.openedByHand() }
    if let eject { installer.eject(eject) }
    updater?.start(watching: launcher, checkingNow: checksNow)
}

// Lifecycle.init: the update asks; `end()`, never `quit()`, so starting at login stays as it is.
updater?.onHandOver = { [unowned self] in handedOver() }
```

```swift
// A scenario, at the one seam: real Lifecycle, Launcher and Updater over in-memory adapters.
@Test func installsAMinuteAfterTheLaterOfTheLastTouchAndTheWindowClosing() {
    let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    let process = world.launch(.atLogin, running: .release)
    process.engine.push(.held(.genuine))
    process.touch(.finger)
    #expect(process.idleClock.pending == nil)
    process.lift()
    process.lifecycle.launcher?.openedByHand()
    #expect(process.idleClock.pending == nil)
    process.lifecycle.launcher?.closeWindow()
    #expect(process.idleClock.pending == .seconds(60))
    process.idleClock.pass()
    #expect(world.log.entries.suffix(2) == ["arm restart", "end"])

    let next = world.finishHandOver(installed: true)      // what the job and Sparkle's installer do
    #expect(next.lifecycle.launcher?.window == .closed)
    #expect(world.loginItem.isOn)
    #expect(next.engine.startedCheckingNow == true)
}
```

```text
Releasing is unchanged:   Scripts/release.sh patch
New once, by hand:        generate_keys, then generate_keys -x into offline storage
After upgrading Sparkle:  a test fails until Scripts/update-e2e.sh has been run and SparkleInternals.provenOn raised
```

### Shape

#### Load-bearing decisions

1. **The automatic path, always held.** `willInstallUpdateOnQuit` returns true and its immediate handler is thrown away unused. So Sparkle's relaunch flag is never set, B1-B3 are unreachable, and A5 is the only way an install runs.
2. **We end ourselves.** A one-shot launchd job is armed in the same main-actor turn that ends the process. It is the only thing that restarts the app (B4, C2).
3. **`Updater` survives as the one owner of update decisions**, smaller and deeper, with no version in it. Sparkle sits behind one port. Sparkle's private behaviour sits in one type in one file.
4. **`Launcher` learns "in use", not "update".** Contact sensing and the idle minute exist only while a verified update waits.
5. **R6's second half is checked synchronously inside the delegate call**, so no main-actor turn exists in which an unchecked update is held.
6. **The feed is a release asset**, published by the same `gh release create` as the app.
7. **The card's rules move to a target that never ships**, and the release runs them on the real archive.

#### What an update can be in

Sparkle owns "checking" and "downloading", and nothing here reads them. `Updater` holds only what it must act on. Each lasting effect belongs to exactly one phase, and all of them start and stop in one transition function. That makes a running minute without a verified update, or a connection watch beside a held update, unwritable.

```swift
private enum Phase {
    /// Nothing to do. Sparkle's schedule, or a check, may be running.
    case resting
    /// R1. The last cycle failed for lack of a connection, and the connection watch runs. `retrySpent`: a retry has
    /// already failed on this reading, so only a drop and a return earn another. One bit; no timer, no backoff.
    case awaitingConnection(retrySpent: Bool)
    /// R8. A genuine update is held and installs at this process's end, however it ends. `Launcher`'s use is watched,
    /// and the idle minute runs exactly while the app is not in use.
    case ready
    /// Terminal. The restart is armed and the process is ending in this same turn.
    case handedOver
}
```

| Lasting effect | Exists only in |
|---|---|
| `Connection.watch` | `.awaitingConnection` |
| `Launcher.watchUse`, frame-thread contact pushes | `.ready` |
| The 60 s deadline | `.ready` and not in use |
| The launchd job | `.handedOver`, and that phase lasts one turn |

Persisted state: none of ours. An interrupted update resolves from what is on disk and in Sparkle's cache (`why.md` Change 6: the archive now goes to disk, which R8 needs).

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` | `Updater` rewritten; `UpdatableCopy` replaces `InstalledRelease`; `Opening.afterUpdate`; ports `UpdateEngine`, `Connection`, `IdleClock`; `TrackpadEvent.contactChanged`; `Launcher.isInUse`, `watchUse`. `Lifecycle` loses every install guard. `Release`, `UpdateEvent`, `UpdateCard`, `Version`, `ReleaseList`, `UpdateInstaller` are deleted. Core no longer holds a version number. |
| `LauncherPlatform` | `SparkleEngine` (with `SparkleInternals`, `SilentUserDriver`), `LaunchdJob` (with the hand-over script), `SystemConnection`, `SystemIdleClock`, contact in `DeviceSession` and `MultitouchTrackpads`. `GitHubReleases`, `ApplicationsUpdater` and `BundleInstall`'s unpacking are deleted. `CodeSignature.isGenuine` stays, against `ExpectedUpdate`. |
| `LauncherUI` | The card, its layout input and every `updater` reference go. |
| `CardContract` (new, never linked by the app) | Frozen copy of the card's rules; library, `card-contract` tool, its own tests. |
| App target | `makeUpdater` as above. No decision. |

#### Types and signatures

```swift
// ─── LauncherCore ───────────────────────────────────────────────────────────────────────────────

public enum Opening: Equatable, Sendable {
    case atLogin
    case byHand
    /// The hand-over job started this process. `installed` false: the install failed and this is the old copy again.
    case afterUpdate(installed: Bool)
}

public enum Route: Equatable, Sendable {
    case runSilently, runWithWindow, askToMove, end
    /// The new row is compile-forced. The argument means something only where an update lands; anywhere else it reads
    /// as an opening by hand, so "every other opening still reaches .byHand" holds by the table.
    public init(_ opening: Opening, placement: Placement, olderCopyRuns: Bool) {
        switch (opening, placement, olderCopyRuns) {
        case (.atLogin, _, true): self = .end
        case (.atLogin, _, false): self = .runSilently
        case (.afterUpdate, .installed, _): self = .runSilently        // silent, and `replace` stops everyone: R9
        case (.byHand, .elsewhere, _), (.afterUpdate, .elsewhere, _): self = .askToMove
        case (.byHand, .installed, _), (.byHand, .development, _), (.afterUpdate, .development, _):
            self = .runWithWindow
        }
    }
}

public struct Launch: Equatable, Sendable {
    public var opening: Opening
    public var diskImageToEject: DiskImage?
    /// False only after a failed install: the recovered copy must not retry at once, or a failure that persists
    /// would hand over once a minute for ever. Sparkle's own schedule retries within 24 hours (R11).
    public var checksForUpdatesNow: Bool { opening != .afterUpdate(installed: false) }
}

/// R2 and R12, the gate, whole. Pure, called by the composition root and the tests. Read once, at start.
public struct UpdatableCopy: Equatable, Sendable {
    public init?(placement: Placement, developerIDSigned: Bool, canReplaceItself: Bool) {
        guard developerIDSigned, placement == .installed, canReplaceItself else { return nil }
    }
}

public enum CycleOutcome: Equatable, Sendable { case nothingNew, noConnection, failed }

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
    /// A cycle ended: no update, a failure, or a held update lost (a helper died, C5).
    case cycleEnded(CycleOutcome)
}

/// Sparkle, and the restart that follows it. No Sparkle type, feed value or version crosses this port.
/// Real: SparkleEngine. Test: InMemoryUpdateEngine.
@MainActor public protocol UpdateEngine: AnyObject {
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? { get set }
    /// Makes no request before this call. Starts the 24-hour schedule; with `checkingNow`, one check follows at once.
    func start(checkingNow: Bool)
    /// One background check. Does nothing while a cycle runs or an update is held.
    func check()
    /// Stops the held update ever installing. False: it could not be stopped, and it installs at this process's end.
    func discardHeldUpdate() -> Bool
    /// Arms the start of whichever version /Applications holds once this process has ended. The caller ends the
    /// process in the same turn. False: nothing is armed.
    func armRestart() -> Bool
}

/// Whether a network path exists. Real: SystemConnection. Test: InMemoryConnection.
@MainActor public protocol Connection: AnyObject {
    var onChange: (@MainActor (Bool) -> Void)? { get set }
    /// Pushes the present reading, then every change, until `stop`. Nothing runs before or after.
    func watch()
    func stop()
}

/// One pending wait that does not advance while the Mac sleeps. Real: SystemIdleClock. Test: InMemoryIdleClock.
@MainActor public protocol IdleClock: AnyObject {
    /// Replaces any pending wait.
    func wait(_ duration: Duration, then passed: @escaping @MainActor () -> Void)
    func cancel()
}

// TrackpadEvent gains, for the real adapter and the in-memory one alike:
//   /// Some trackpad went empty or occupied, only while `sensesContact`. Carries no data: re-read `isTouched`.
//   case contactChanged
// TrackpadHardware gains:
//   /// Contact of any kind on any running trackpad, read now: palms yes, hovers no. Never prompts, reads no clock.
//   var isTouched: Bool { get }
//   /// While true, each flip pushes `.contactChanged`. Off costs one flag read per flip and no hop.
//   var sensesContact: Bool { get set }

extension Launcher {
    /// A finger on any trackpad, or the settings window open, minimised or hidden included.
    public var isInUse: Bool { fatalError("not implemented") }   // window != .closed || hardware.isTouched

    /// While set: `onChange` now with the present reading, then on every flip. nil stops it, and contact sensing with
    /// it. `Launcher` does not know why it is asked.
    public func watchUse(_ onChange: (@MainActor (Bool) -> Void)?) { fatalError("not implemented") }
    // TODO: reportUse() runs on `.contactChanged`, in openedByHand, in closeWindow and after hardware.run in reconcile.
    // The last is the reset rule (H3): `run` replaces sessions, so an in-flight lift can vanish; re-reading the level
    // cannot stick. A resting finger comes back on its next frame.
}

/// Owns every update decision: R1's retry, R8's rule, R6's verdict, the order of the hand-over.
@MainActor public final class Updater {
    /// The process must end now, through `end()`. Set once by `Lifecycle`.
    public var onHandOver: (@MainActor () -> Void)?

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection, clock: any IdleClock) {
        fatalError("not implemented")
    }

    /// Once, from a resident only.
    public func start(watching launcher: Launcher, checkingNow: Bool) { fatalError("not implemented") }

    private func handle(_ event: UpdateEngineEvent) {
        // .held(.genuine)            → enter(.ready)
        // .held(.notGenuine)         → _ = engine.discardHeldUpdate(); stay .resting. No restart is ever armed for it.
        //                              .cycleEnded(.failed) follows from Sparkle once its helper has gone (D5).
        // .cycleEnded(.noConnection) → awaiting already ? enter(.awaitingConnection(retrySpent: true))
        //                                               : enter(.awaitingConnection(retrySpent: false))
        // .cycleEnded(other)         → enter(.resting)
        fatalError("not implemented")
    }

    private func connectionChanged(_ connected: Bool) {
        // Only while .awaitingConnection(let spent):
        //   !connected           → spent = false
        //   connected && !spent  → engine.check()
        // No hot loop: a check needs a reading that was not already spent, and a spent reading needs a real drop.
        fatalError("not implemented")
    }

    private func useChanged(_ inUse: Bool) {
        // Only while .ready: inUse ? clock.cancel() : clock.wait(.seconds(60)) { idleMinutePassed() }
        fatalError("not implemented")
    }

    private func idleMinutePassed() {
        // guard .ready, launcher.isInUse == false       // the level, read now: an edge may still be queued
        // guard engine.armRestart() else { return }     // stays .ready; the next idle edge tries, so no loop
        // enter(.handedOver); onHandOver?()             // same turn, nothing can interleave
        fatalError("not implemented")
    }

    /// The one place a lasting effect starts or stops, so leaving a phase cannot leave one armed.
    private func enter(_ next: Phase) {
        // leaving .awaitingConnection for anything else → connection.stop()
        // leaving .ready                                → clock.cancel(); launcher.watchUse(nil)
        // phase = next
        // entering .awaitingConnection from outside it  → connection.watch()
        // entering .ready                               → launcher.watchUse { useChanged($0) }
        fatalError("not implemented")
    }
}

// ─── LauncherPlatform ───────────────────────────────────────────────────────────────────────────

/// `import Sparkle` lives in this file and nowhere else. SPUUpdater, SPUUserDriver and SPUUpdaterDelegate are
/// NS_SWIFT_UI_ACTOR, so a @MainActor class conforms with no escape hatch.
@MainActor public final class SparkleEngine: NSObject, UpdateEngine, SPUUpdaterDelegate {
    public var onEvent: (@MainActor (UpdateEngineEvent) -> Void)?

    /// Reads CFBundleVersion now: after a swap, `Bundle.main` reads the new bundle (M36).
    public init(bundle: URL, signer: Signer) { fatalError("not implemented") }

    /// R12's predicate. Sparkle's private rule read-only: `SparkleInternals.canReplace`.
    public nonisolated static func canReplace(_ bundle: URL) -> Bool { SparkleInternals.canReplace(bundle) }

    public func start(checkingNow: Bool) {
        // HTTPCookieStorage.shared.cookieAcceptPolicy = .never         // before the first request (E3)
        // let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        // updater.userAgentString = "TrackpadLauncher"
        // updater.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]
        // do { try updater.start() } catch { onEvent?(.cycleEnded(.failed)); return }
        // if checkingNow { updater.checkForUpdatesInBackground() }     // the one moment the docs bless (A8)
        fatalError("not implemented")
    }

    public func check() { fatalError("not implemented") }     // guard !sessionInProgress; checkForUpdatesInBackground()
    public func discardHeldUpdate() -> Bool { fatalError("not implemented") }
    public func armRestart() -> Bool { fatalError("not implemented") }   // LaunchdJob.armHandOver(...)

    /// A12. Refuses, before any download, an enclosure outside this repository's tagged assets or not an `.aar`. That
    /// keeps the disk-image key-rotation fallback (D3) unreachable, so R6's update-key half has no second door.
    public func updater(
        _ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck
    ) throws { fatalError("not implemented") }

    /// Always true. The handler is dropped unused, so Sparkle's relaunch flag can never be set.
    public func updater(
        _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        // let found = SparkleInternals.extractedUpdate(identifier: signer.identifier, build: item.versionString, ...)
        // let genuine = found.map { CodeSignature.isGenuine($0, as: ExpectedUpdate(item), signer: signer) } ?? false
        // onEvent?(.held(genuine ? .genuine : .notGenuine))
        // return true
        fatalError("not implemented")
    }

    public func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor check: SPUUpdateCheck, error: (any Error)?) {
        fatalError("not implemented")  // onEvent?(.cycleEnded(SparkleInternals.outcome(of: error)))
    }
}

/// Every fact here is Sparkle's private business, proven on `provenOn`. Each names its proof. A test compares
/// `provenOn` with LauncherKit/Package.resolved, so an upgrade cannot land without re-proving this type.
enum SparkleInternals {
    static let provenOn = "2.10.1"

    /// A11, read-only: bundle writable, parent writable, bundle owned by this user, and its group one of this user's.
    /// Sparkle's rule proves the last two by chowning a temporary file; this creates nothing. A stricter future Sparkle
    /// costs one silent download, never a prompt (A10).
    nonisolated static func canReplace(_ bundle: URL) -> Bool { fatalError("not implemented") }

    /// D4. `Installation/<random>/<random>/` under Sparkle's cache. nil unless the newest such folder holding `build`
    /// holds exactly one bundle: a stale folder from an interrupted cycle must not be read for the current one, and two
    /// bundles cannot be told apart from what Sparkle would choose (D2).
    static func extractedUpdate(identifier: String, build: String, caches: URL) -> URL? { fatalError("not implemented") }

    /// D5. Removing this job ends the installer; Sparkle then aborts with 4005.
    static func installerJob(of identifier: String) -> String { "\(identifier)-sparkle-updater" }

    /// A7. nil and 1001 are `.nothingNew`. Any NSURLErrorDomain error anywhere down the NSUnderlyingError chain is
    /// `.noConnection`, whatever the depth. Everything else is `.failed`.
    static func outcome(of error: (any Error)?) -> CycleOutcome { fatalError("not implemented") }
}

/// What the running app's Info.plist key `SUFeedURL` implies: `…/releases/latest/download/appcast.xml` allows only
/// `…/releases/download/<tag>/<name>.aar`. No address exists in Swift.
func isPinned(enclosure: URL?, feed: URL) -> Bool { fatalError("not implemented") }

/// The offer, from the feed, that the extracted bundle's sealed Info.plist must equal.
struct ExpectedUpdate: Sendable { let version, build, minimumMacOS: String }

/// `SMJob` lives in this file and nowhere else. Deprecated since 10.10, and the only way to submit a non-permanent job:
/// Sparkle's own comment says so, and it shares this API's fate.
enum LaunchdJob {
    static func remove(label: String) -> Bool { fatalError("not implemented") }
    /// Removes any stale job of this label first.
    static func submit(label: String, arguments: [String]) -> Bool { fatalError("not implemented") }
    /// The hand-over job. `allowed` is 5 s in production; a test passes 1 s and a stub for `open`.
    static func handOverArguments(oldPID: Int32, bundle: URL, build: String, allowed: Int, open: String) -> [String] {
        fatalError("not implemented")
    }
    static let handOverScript = "…"   // below, in "The hand-over"
}

/// One-shot `DispatchSource` timer on the main queue, 1 s leeway, on the clock that stops during sleep. Cancel and fire
/// are both on main, so a cancelled wait cannot fire.
@MainActor public final class SystemIdleClock: IdleClock { /* not implemented */ }

/// NWPathMonitor on the main queue; a reading is `path.status == .satisfied`. Exists only between `watch` and `stop`.
@MainActor public final class SystemConnection: Connection { /* not implemented */ }

// DeviceSession gains:
//   /// Writer: this device's frame callback. Reader: main, through `isTouched`.
//   private let occupied = Mutex(false)
//   var isOccupied: Bool { occupied.withLock { $0 } }
//   // First lines of `receive`, on frame.touches, so before the recognizer's palm filter (H2):
//   let touched = !frame.touches.isEmpty
//   let flipped = occupied.withLock { was in defer { was = touched }; return was != touched }
//   if flipped, contactSensed.withLock({ $0 }) { deliver(.contactChanged, nil) }
//
// Beside `sessions`: `let contactSensed = Mutex(false)`, one writer (main). It outlives `run`, a session does not.
// `isTouched` copies sessions out and asks each, as `mergedTapState` does: never two locks at once.
```

**Depth.** `Updater` shows three things: an initializer, `start`, `onHandOver`. Behind them sit R1's retry, R8's rule, R6's verdict and the hand-over order. `UpdateEngine` has four methods and one push. Behind them sit Sparkle's configuration, the cookie policy, headers, the feed pin, the silent driver, error parsing, the extraction lookup, the signature check, a two-layer veto and the launchd job. Callers keep only what they must decide with: held or not, and how a cycle ended. The deletion test passes: remove either and R6, R8 and R1 reappear across `Lifecycle` and the app target.

#### 1. The Sparkle path, and what crosses

The path is section A's: `SUAutomaticallyUpdate`, `SUEnableAutomaticChecks`, `SUVerifyUpdateBeforeExtraction`, `SUPublicEDKey`, `SUFeedURL`, plus a required driver that shows nothing. No `SPUStandardUpdaterController`. XPC services stay in the bundle, unused (G6): `project.yml` needs no strip step inside a signed framework.

| Coupling | Standing | Where it lives |
|---|---|---|
| Info.plist keys, `SPUUpdater`, `start`, `userAgentString`, `httpHeaders`, `shouldProceedWithUpdate`, `willInstallUpdateOnQuit` returning true, `didFinishUpdateCycle` | Public | `SparkleEngine` |
| "Sparkle will always attempt to install the update when the app terminates", no relaunch unless requested | Public, in the header | The basis of `armRestart` |
| `checkForUpdatesInBackground` at start | Blessed by the docs | `SparkleEngine.start` |
| The same call when a connection arrives | **Departure.** The docs warn it "could interfere with Sparkle's scheduler". It invalidates and re-arms the 24-hour timer, so the mark moves to the retry, which is what R1 means. No public call forces a check, because a failed check stamps `SULastCheckTime` (A8). | `SparkleEngine.check` |
| Driver that shows nothing | Required by the initializer. The docs' warning is about using a driver *to* install silently; `SUAutomaticallyUpdate` does that here. Its only live use is `.dismiss` on the refused-install path. | `SilentUserDriver` |
| Extraction layout (D4), installer label (D5), writability rule (A11), nested error shape (A7) | **Private** | `SparkleInternals`, one type |

An upgrade is findable twice. `SourcePolicyTests` confines `import Sparkle`, `org.sparkle-project` and `sparkle-updater` to one file, and a test fails until `provenOn` equals `Package.resolved`'s Sparkle version.

#### 2. Ownership

`Updater` survives (Preserve 7). It stops being `@Observable`, because nothing renders it. `Launcher` loses its `updater` parameter and `SettingsShell` loses its stored one; `Updater` watches `Launcher` as a concrete Core type, so no one-adapter protocol appears. `Lifecycle` keeps its one exhaustive quit switch, loses `isInstalling` from `shouldEnd` and `quit`, and gains `handedOver()`, which is today's `replaced()` renamed. No update decision lives in `Lifecycle`, `Launcher` or the app target.

`Updater` stays built in `applicationWillFinishLaunching`, because that is where the gate reads the running copy. Building it does nothing: `SparkleEngine.start` creates the `SPUUpdater`.

#### 3. R8's gate

**Contact** is read at `DeviceSession.receive` on `frame.touches`: it sees palms and not hovers, and it reads no clock (H2). Normal touches cost one uncontended lock per frame and, on a flip, one flag read, with no hop. "No finger down means no work" holds as it does today.

**Window edges** arrive through `Launcher`'s own model, which flips before AppKit's `orderOut` (H4).

**One input.** Both reach `Updater` as one boolean, `inUse`. So "1 minute after the later of the last touch and the window closing" needs no timestamps: the minute starts on the last edge to not-in-use and is cancelled by any edge back. When it fires, `Updater` re-reads the level, so an edge still queued on main cannot lose a touch.

**The minute** is a one-shot `DispatchSource` timer in one file, and `docs/architecture.md:20` changes on purpose. The reasons:

- The rule's motive is idle CPU. This timer exists for minutes per release and only while a verified update waits, inside the "one momentary blip per minute" that 001 R22 allows (H6).
- `LaunchClock` is the wrong tool. It reports a system stop as *passed*, which is right for a cap and wrong here. Its 60 s behaviour with the display asleep is unmeasured, which is exactly when R8 fires (H5). Its rule says a deadline cannot outlive its effect, and this one has no effect on screen.
- The clock stops during sleep. A Mac that sleeps mid-minute finishes the minute after waking, rather than installing at the moment the user lifts the lid.

Proposed text for that line: *"…Time passes only on Core Animation's clock, with these exceptions, each confined to one owner: a network-free one-shot timer for R8's idle minute (armed only while a verified update waits and nothing uses the app), Sparkle's own 24-hour one-shot, and the hand-over job's bounded wait, which runs after this process has ended."*

A dead trackpad reads as idle, which R8's "no trackpad in use" scenario wants. A stuck `occupied` delays the install until the next touch or `run` (L4): it fails safe.

#### 4. The hand-over (R9, R11)

Order of effects. Steps 1 to 3 run in one main-actor turn, so nothing can interleave.

| # | Effect | If the process or helper dies right after it |
|---|---|---|
| 1 | Minute passes; level re-read | Held update installs at the end, no relaunch (A5). A later login or opening runs the new version: "never relaunches after a crash" stands. |
| 2 | `armRestart`: remove a stale job, `SMJobSubmit` the one-shot with old pid, bundle, old build | Job carries on and finishes the hand-over: the crash happened after the decision. If `armRestart` returns false: stay `.ready`, keep running, try on the next idle edge. The update still installs at the next end. No loop. |
| 3 | `.handedOver`, `Lifecycle.end()`: `.ending`, `NSApp.terminate` | As step 2. `shouldEnd` answers yes in `.ending`, so the old copy cannot refuse. |
| 4 | `Updater.app` sees the exit; `Autoupdate` runs stage 3 | Installer killed before the swap: bundle untouched; job's budget runs out; old copy returns. |
| 5 | `renamex_np(RENAME_SWAP)` | Atomic: one whole copy on disk (C4, D-4). `archive_and_check` requires `Autoupdate` to carry the release's Team ID, or Sparkle would fall back to two moves. |
| 6 | Job sees the build change; `open -g -a <bundle> --args --after-update` | Job killed (only logout does): nothing runs until login, and the login item is intact. |
| 7 | `.afterUpdate(installed: true)`, `.runSilently`, stop others, resident, first check | New version crashes: nothing runs until the next login or opening. This is `P022:1082`'s accepted cost; no older copy exists to return to (rollback is a non-goal). |

**On failure** (C1), `Autoupdate` exits and nothing restarts the app. The job's budget runs out, 5 s from the old pid's exit on **wall time** (C2's lesson), and it runs `open -g -a <bundle> --args --after-failed-update`. That process is `.afterUpdate(installed: false)`: silent, and `checksForUpdatesNow` is false. Without that flag, `failquit.out`'s loop becomes real: start, check, download, a minute, fail, for ever. Sparkle's schedule retries within 24 hours of the stamped check, which is R11's "a later check". Worst case to gestures: about 6 s, `date +%s` granularity included, plus `open` and the app's own start (about a second of CPU, `docs/performance.md:54`), inside 10 s. `update-e2e.sh` measures it.

**Why a job at all.** D-1 is settled by R11: Sparkle cannot recover from a failed swap (C1), and only something outside the old process, created before it ends, can (C3). Avoid 4 and 5 came from plans where the old process was alive at hand-over, or from another failure, and did not weigh R11. The glossary's "never relaunches itself after a crash or a force quit" still holds: the job is only ever created in the same turn as a deliberate end.

```sh
# launchd: /bin/sh -c "$script" handover <pid> <bundle> <build> <allowed> <open>
# LaunchOnlyOnce, RunAtLoad, EnableTransactions false, ProcessType Interactive. kSMDomainUserLaunchd. Parent: launchd.
old=$1; bundle=$2; build=$3; allowed=$4; open=$5
begun=$(/bin/date +%s)
while /bin/kill -0 "$old" 2>/dev/null; do
  # Still alive: nothing failed, and opening it would only show its window.
  [ $(( $(/bin/date +%s) - begun )) -lt 10 ] || exit 0
  /bin/sleep 0.05
done
gone=$(/bin/date +%s)
while :; do
  now=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null)
  if [ -n "$now" ] && [ "$now" != "$build" ]; then
    exec "$open" -g -a "$bundle" --args --after-update
  fi
  [ $(( $(/bin/date +%s) - gone )) -lt "$allowed" ] || break
  /bin/sleep 0.1
done
exec "$open" -g -a "$bundle" --args --after-failed-update
```

`open -g` leaves focus alone (B4, H8), the argument is a positive signal with nothing persisted (B6), and a copy that once had a window hands over cleanly (B11). The version comparison couples to nothing of Sparkle's. An opening by hand during the 200 ms gap either receives a re-front or, on a different build, is stopped by the silent copy. The user reopens; it is one window lost in a race that needs an opening in that exact gap.

#### 5. R13 and R14

| Way of quitting | Nothing, or a check or download running | Verified update waiting |
|---|---|---|
| *Quit Trackpad Launcher* | `suspend`, `end`, at once. The download dies with the process. | Same. Sparkle installs at exit with no relaunch (`plainquit.out`); the app stays stopped until opened. |
| ⌘Q, close, Escape, Dock's Quit, window open | Window closes only | Window closes only; the idle minute may start |
| `.other`, window closed (script, Activity Monitor) | Ends | Ends; installs at exit; no restart |
| `.system` | Ends at once | Ends at once; Sparkle may install; no job exists, no restart |
| Crash, force quit, another copy's stop | Ends | Installs at exit; no restart |

Nothing is left armed because an update holds only two things that could restart the app, and neither can be pending after a quit. Sparkle's relaunch flag is set only by the immediate handler, which is never called (B3 unreachable). The job is submitted only in the turn that ends the process, so a Quit lands either before it, when no job exists, or after the process has gone. The `isInstalling` guards are reversed (`why.md` Change 8). `shouldEnd`'s table is otherwise unchanged, and `.system` always wins (Preserve 8). R14's dependence on a real logout reading as `.system` is the shipped risk D-3; see Open questions. A minute that passes between `willPowerOff` and the quit event hands over as usual: the old copy ends, which is what logout wants, and the job's `open` meets a session already ending.

#### 6. R6

**The update-key half.** `SUVerifyUpdateBeforeExtraction` makes Sparkle check EdDSA before extracting. The only way past a failed EdDSA check is a same-team Developer ID disk image (D3). `isPinned`, in the public `shouldProceedWithUpdate` (A12), refuses every enclosure but a tagged `.aar` of this repository, silently and before any download. An `.aar` cannot carry a code signature, so that door does not exist. We do not adopt `SURequireSignedFeed`: R6 is about the download, and it would add a failure mode that silently stops every copy.

**The Developer ID and identifier half.** Sparkle checks only validity (D1, D2), so at A3's moment `SparkleEngine` runs `CodeSignature.isGenuine` on the extracted bundle: Developer ID, this team, this identifier, `notarized`, strict and nested validation, offline, sealed versions equal to the offer (D7). Notarisation at install stays: it is free, and it is what older copies already enforce (`why.md` Change 10). The check runs synchronously on main, about 19 ms once per release, so there is no phase in which `Quit` could install an unchecked update. It is a named exception to "work that would delay a click runs off main".

**Fail closed.** No bundle found, two bundles, a stale layout or an unreadable signature all read `.notGenuine`.

**The veto.** `discardHeldUpdate` has two independent layers:

1. `LaunchdJob.remove(installerJob)`, probed (D5): abort 4005, cycle ends, nothing installs, a later check runs normally.
2. Whatever the first returned, `BundleInstall.discard` on the extracted bundle's folder, so stage 3 has nothing to install. This also stops a vetoed bundle reading as stale later. By reading, stage 3 then fails as in C1; this layer alone is unprobed, so a spike scenario proves it before it is relied on.

It returns true if either worked.

**When a veto fails.** Both layers failed, which needs Sparkle's label and its layout to have changed together, and `provenOn` blocks that. The result: `.resting`, no restart is ever armed, Sparkle's cycle stays stalled, and the update installs at the next end of the process. It still carries the publisher's EdDSA signature. **Residual gaps, named:** this one; and a process end during the 0.4 s between stage 1 and the delegate call, which installs an EdDSA-valid update unchecked (A5, `AppInstaller.m:742`). Neither is reachable without the private key.

#### 7. R1

| Trigger | Mechanism |
|---|---|
| Every start | `checkingNow` true: `checkForUpdatesInBackground` straight after `start()` (A8). Not after a failed install. |
| Every 24 hours | Sparkle's one-shot walltime source (A9). `SUScheduledCheckInterval` stays at its default. |
| Wake past the mark | The same source: its wall clock counts sleep, so it fires on wake (A9). |
| Connection after a failure | `.awaitingConnection`, `Connection.watch`, `engine.check()` |

No hot loop: `retrySpent` means a check needs a fresh reading. The first failure earns one retry on the first "connected" reading, which also covers the race where the path came up before the watch armed. A retry that fails again needs a real drop and return. A persistent failure with a steady path (DNS, a captive portal) therefore makes one extra request, then waits for the 24-hour mark. There is no floor, backoff or timer, and no decision that needs testing with time. A cycle that ends some other way (a 500, a veto) waits for the next check, which is R5's and R6's "later check".

`NWPathMonitor` is the push; `SCNetworkReachability` is deprecated since macOS 14.4 and its header names `NWPathMonitor` as the replacement. The ban on `import Network` becomes a confinement, on purpose: a path monitor makes no request, and `NWConnection` stays banned.

#### 8. R2 and R12

The gate is decided in `UpdatableCopy.init?`, read once in `applicationWillFinishLaunching`, and enforced by absence: `Updater?` is nil, so `SparkleEngine` is never built (Preserve 6). `developerIDSigner()` takes no arguments, so `--as-release-build` cannot fake it. `Updater.start` runs only from `othersExited`, so a `.end` or `.askToMove` route never reaches it, and a move's new process runs the gate itself.

`canReplace` runs before any request. It mirrors A11 read-only (`stat` and group membership), so a standard account, or an admin looking at another admin's copy, stays silent, including the root-owned, group-writable case Sparkle's third test exists for. If it ever says yes wrongly, A10 still guarantees no prompt: one silent download, no password.

#### 9. R3

| Property | How it holds | Evidence |
|---|---|---|
| User-Agent | `userAgentString = "TrackpadLauncher"` | E1 |
| Language, encoding | `httpHeaders` sets `Accept-Language: en`, `Accept-Encoding: gzip`; applies to feed and download, survives a 302 | E1 |
| Cookies | `cookieAcceptPolicy = .never` before the first request, in-process because the XPC downloader is off | E2, E3 |
| Query string, profile | Profiling off by default; no key sets it | E6 |
| Validators | The feed is `reloadIgnoringLocalCacheData`; a repeated download sent none, with `Last-Modified` offered | `SPUDownloadDriver.m:129`, `failquit.out` |
| Redirects | Same headers on every hop | E1, E5 |

The feed's redirect hop on real GitHub is the one link not yet run on the wire. `update-e2e.sh`'s server reproduces the two 302s, sets `Set-Cookie`, `ETag` and `Last-Modified` on every response, and fails on any request header outside an allowlist, any `Cookie`, any validator, and any query string on an address the app forms.

**A limit to name.** The last hop of a download follows GitHub's redirect to `release-assets.githubusercontent.com`, whose URL carries GitHub's own signed, expiring query string (`server-redirect.py` models it). GitHub forms it and it names nothing of the user's, the Mac's or the versions, so R3's purpose holds, but a network monitor will show a `?` on that one request.

**Feed address:** `https://github.com/domasgru/trackpad-launcher/releases/latest/download/appcast.xml`, in `project.yml` as `SUFeedURL`. It is a permanent contract with every automatic copy, like the `.aar` name.

#### 10. The feed and the release

**Where.** `appcast.xml` is an asset of each release. `gh release create` uploads before it publishes, so app, archive and feed appear in one step (Preserve 13), and a feed failure stops the release because no separate step exists. Immutability stops being a problem: each release carries a complete snapshot and `latest` moves atomically. Deleting a release withdraws it with no edit, which R4's "a higher one was withdrawn" wants. Other assets do not disturb the card (F7).

**Contents.** Items accumulate from the previous release's feed, so R4's "needs a newer macOS" finds older ones (F2). The script renders items by hand: `generate_appcast` fits poorly (F5). Only the script writes the feed, so a pre-release can never appear (R4).

**Key.** `generate_keys` keeps it in the login keychain; `SUPublicEDKey` is in `project.yml`; the private half is never in the repo; preflight proves the two match before anything changes. Backup with `generate_keys -x` is a human step, because a lost key cannot rotate under R6 (F6, and the pin closes the disk-image door on purpose).

**Build numbers.** Sparkle compares `CFBundleVersion` (F1), so a hand-raised marketing version with an old build number would be invisible. The script refuses a build number not above every item in the previous feed.

```bash
# In preflight_checkout: every credential is checked before anything changes.
(cd "$ROOT/LauncherKit" && swift package --disable-keychain resolve) || fail "cannot resolve the package."
SPARKLE_BIN="$(dirname "$(find "$ROOT/LauncherKit/.build/artifacts" -type f -path '*/bin/sign_update' | head -1)")"
[ -x "$SPARKLE_BIN/sign_update" ] || fail "Sparkle's tools are missing from the resolved package."
[ "$("$SPARKLE_BIN/generate_keys" -p)" = "$(sed -n 's/^ *SUPublicEDKey: *//p' "$ROOT/project.yml")" ] ||
  fail "the keychain's update key is not the one project.yml ships; import the backup with generate_keys -f."

# Before preflight_version. A failed publish can leave a draft nothing sees, and it would block this retry.
[ "$(gh release view "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --json isDraft --jq .isDraft 2>/dev/null)" != true ] ||
  gh release delete "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --yes

# After `rm -rf "$OUT"`, before the long build.
read_previous_feed() {
  if gh release view --repo "$REPOSITORY" --json assets --jq '.assets[].name' | grep -qx appcast.xml; then
    gh release download --repo "$REPOSITORY" --pattern appcast.xml --output "$OUT/previous.xml" ||
      fail "cannot read the latest release's feed; nothing changed."
  else
    # Only the first automatic-update release.
    printf '%s\n' '<?xml version="1.0" standalone="yes"?>' \
      '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">' \
      '<channel><title>Trackpad Launcher</title>' '</channel></rss>' > "$OUT/previous.xml"
  fi
  local highest
  highest="$(sed -n 's:.*<sparkle\:version>\([0-9]*\)</sparkle\:version>.*:\1:p' "$OUT/previous.xml" | sort -n | tail -1)"
  [ -z "$highest" ] || [ "$(read_setting CURRENT_PROJECT_VERSION)" -gt "$highest" ] ||
    fail "build number is not above the feed's $highest; Sparkle would never offer this release."
}

# In archive_and_check, strict mode: Sparkle's atomic swap needs Autoupdate and the update on one team (C4).
codesign -dv "$copy/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1 |
  grep -qx "TeamIdentifier=$TEAM_ID" || fail "Sparkle's installer is not signed by team $TEAM_ID."

# After archive_and_check strict: the stapled archive, against every shipped card's own rules (R16).
swift run --package-path "$ROOT/LauncherKit" --disable-keychain card-contract \
  "$AAR" --team "$TEAM_ID" --identifier "$BUNDLE_ID" || fail "an older copy's card would refuse this release."

# After the disk image is notarised: the last step that can fail before anything is pushed.
write_feed() {
  local attributes signature item plist="$APP/Contents/Info.plist" name
  name="$(basename "$AAR")"
  attributes="$("$SPARKLE_BIN/sign_update" "$AAR")" || fail "cannot sign the update with the update key."
  signature="$(sed -n 's/.*edSignature="\([^"]*\)".*/\1/p' <<<"$attributes")"
  "$SPARKLE_BIN/sign_update" --verify "$AAR" "$signature" || fail "the update's signature does not verify."
  item="<item><title>$EXPECTED_VERSION</title>"
  item+="<pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>"
  item+="<sparkle:version>$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")</sparkle:version>"
  item+="<sparkle:shortVersionString>$EXPECTED_VERSION</sparkle:shortVersionString>"
  item+="<sparkle:minimumSystemVersion>$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")</sparkle:minimumSystemVersion>"
  item+="<enclosure url=\"https://github.com/$REPOSITORY/releases/download/v$EXPECTED_VERSION/$name\" $attributes type=\"application/octet-stream\"/></item>"
  awk -v item="$item" '/<\/channel>/ { print item } { print }' "$OUT/previous.xml" > "$OUT/appcast.xml"
  xmllint --noout "$OUT/appcast.xml" || fail "the feed is not well-formed."
}

# Publishing: one more asset, nothing else changes.
gh release create "v$EXPECTED_VERSION" "$DMG" "$AAR" "$OUT/appcast.xml" --repo "$REPOSITORY" --latest ...
```

| Step, in order | Failure leaves |
|---|---|
| Preflight, now with the update key and Sparkle's tools | Nothing changed |
| Tests, bump, `preflight_version` | Version commit undone |
| `read_previous_feed` with the build-number check | Undone |
| Archive, export, notarise, staple, `stapler validate` (R7) | Undone. No `.aar` exists yet, so no feed item can exist. |
| `archive_and_check strict`, with `Autoupdate`'s team | Undone |
| `card-contract` on the stapled `.aar` (R16) | Undone |
| Image, sign, notarise, staple, Gatekeeper | Undone |
| `write_feed` | Undone |
| Push the version commit | Nothing published; undone |
| `gh release create` with three assets | Main holds the version, nothing visible; run with no argument. A leftover draft is removed first. |

Publishing a broken or unnotarised update takes defeating `set -e`: the feed is built only from a stapled, card-checked archive, and the feed goes up with it or not at all.

#### 11. R16

The `.aar` stays the one archive, read by both the card and Sparkle (A6). Asset name, inner `TrackpadLauncher.app`, stapled ticket, identity and tag path are unchanged. The first automatic version carries `SUVerifyUpdateBeforeExtraction`, so one file serves both.

The rules outlive the card through `CardContract`. Its code is the shipped code moved, not rewritten: `admits`, `extract`, `MemoryStream`, the asset-name parse, `Version`, and a copy of `isGenuine` with the card's own requirement. It is frozen, with its tests moved beside it, and imports neither `LauncherCore` nor `LauncherPlatform`, so a change to the running app cannot weaken it. It sits under `LauncherKit/Sources`, so the scan binds it too: the tool reports through standard error and its exit code, never `print(`. `release.sh` runs it on every release, before anything is pushed. It also closes F8's gap: the Developer ID, identifier and `notarized` requirement over nested Sparkle code runs on the real stapled archive before the first automatic release is public. This answers L8.

#### 12. Build

- `.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")`, a dependency of `LauncherPlatform` (variant A, G1). `project.yml` gains only Info.plist keys; the app embeds it automatically.
- `LauncherKit/Package.resolved` is committed (G4), so `release.sh`'s clean-tree check holds.
- `xcodebuild -exportArchive` re-signs every nested helper with the Developer ID and hardened runtime (G2). No `--deep`, no entitlements. Debug and perf builds keep ad hoc helpers and never start the updater.
- **The keychain stall (G3).** `Scripts/test.sh` runs `swift test --disable-keychain`; every `xcodebuild` (`Makefile`, `release.sh`, `Scripts/perf/build.sh`) passes `-packageAuthorizationProvider netrc`. Implementation proves the cold path once by clearing the SwiftPM cache for a scratch `--cache-path`. If that still blocks, the fallback is a vendored `.binaryTarget(path:)` plus the tools; the interface above does not change.
- Sparkle links at load with WebKit in every build (G5). No weak-linking: `docs/performance.md` gets a re-measured baseline.

#### 13. Deletions and the rules

**Goes.** `GitHubReleases`, `ApplicationsUpdater`, `UpdateCardView`, `Release`, `UpdateEvent`, `UpdateCard`, `InstalledRelease`, `ThisCopy.version` and `macOS`, `Copy.update*`, `Fit.card`, `SettingsShell.updater`, `SettingsView`'s card and Quit disable. Tests: `UpdateCheckTests`, `UpdateInstallTests`, `ApplicationsUpdaterTests`, `GitHubReleasesTests`, `InstalledReleaseTests`, `VersionTests` (moved to `CardContract`), `LocalReleaseServer`.

**The move keeps** the `Installer` port, `ApplicationsInstaller`, `PrivilegedInstall`, `Administrator`, `BundleInstall`'s `quarantine`, `newFolder`, `stage`, `swap`, `discard`, `removeOriginal`, `clearQuarantine`, `Placement`, `MoveDialog`, `Copy.cannotWriteToApplications`. `UpdateFixtures` and `make-update-fixtures.sh` stay for `isGenuine`'s tests.

| Standing rule | Where | Change, on purpose | Reason |
|---|---|---|---|
| "Three `@Observable` models"; `Updater` owns the card; `Launcher` reports the window to it; new version arrives by hand | `architecture.md:11`, `domain-model` | Rewritten to this shape | R1, R9, R15 |
| Sudden-termination rule | `architecture.md:11`, `SourcePolicyTests` | Kept; reworded to name the move, since no update opens a child now | Preserve 2. New copies have launchd as parent (B5), and the old copy's own declaration still matters for the first update. |
| "No timers, no polling" | `architecture.md:20` | Amended, text in section 3 | R1, R8; `why.md` Change 4 |
| "No network code except…" | `architecture.md:27` | One kind, Sparkle's, in the plan's wording | Plan's privacy rule |
| "No files written other than" | `architecture.md:27-30` | Adds Sparkle's caches, `HTTPStorages` and defaults keys (A13); drops the staged update | `why.md` Change 6 |
| "No logging" | `architecture.md:27`, Preserve 14 | Binds our Swift. Sparkle's `SULog` writes to the local unified log with no off switch (D-5); the docs say so plainly. | D-5 |
| "Nothing relaunches the app" | `SourcePolicyTests` | Stays for `SMAppService.*`. Glossary keeps "never after a crash or a force quit". The job is named as the one exception and confined. | D-1, C1 |
| Update check, Newer version, Update card, Quit's *Installing…* text, "by an update opening the new version" | `domain-model.md` | Per the plan; adds *Hand-over* | R13, R15 |
| Reversals of "the user decides when", "never in the background" | `README.md:71`, `product-overview.md:8`, `release.sh` header | Recorded | `why.md` Change 1, 2 |

| `SourcePolicyTests` row | Change |
|---|---|
| `Timer`, `makeTimerSource` | Banned → confined to `SystemIdleClock.swift`. `theNetworkBansAreAllStillListed` moves `Timer` to a twin check on `confined`. `asyncAfter`, `Task.sleep`, display links stay banned. |
| `import Network` | Banned → confined to `SystemConnection.swift`, with new `NWPathMonitor`. `NWConnection` stays banned. |
| `URLSession` | Confined to a deleted file → banned: our Swift makes no request |
| `http` | Confined to `SparkleEngine.swift`, for `httpHeaders`; no address in Swift |
| `downloadTask`, `.download(` | Stay banned, rule reworded: our Swift downloads nothing. Their `required` entries stay. |
| `AppleArchive`, `ArchiveStream`, `ArchiveByteStream` | Confined to `CardContract.swift` |
| `SecCode`, `SecStaticCode`, `SecRequirement` | Add `CardContract.swift` |
| `Data(contentsOf:` | Adds `CardContract.swift`: the tool reads the archive it is given |
| `createsNewApplicationInstance` | Removed; the code is gone |
| New confinements | `import Sparkle`, `HTTPCookieStorage`, `org.sparkle-project`, `sparkle-updater` to `SparkleEngine.swift`; `SMJob` to `LaunchdJob.swift`; `/bin/sh` to `LaunchdJob.swift`, `PrivilegedInstall.swift` |
| New test | `provenOn` equals `Package.resolved`'s Sparkle version |

`Process()`, `posix_spawn` and the rest of "no child processes" are untouched: the job is launchd's, not a child. Under `why.md`'s Hypothesis B the rule's spirit does bend, so the `/bin/sh` row says so.

**`why.md` bindings.** Preserve 1-14 hold; 2, 9 and 13 are shown above, 14 is narrowed by D-5. Avoid 2 holds: nothing passes between versions except two arguments the job writes, and an older copy ignores unknown arguments (B6). Avoid 3 holds through the new `Route` row. Avoid 4 and 5 are overridden for the relauncher only, on C1-C3 and R11. Avoid 6 holds: nothing ends before the verdict. Avoid 1 and 11 hold through `update-e2e.sh`, which proves Sparkle's behaviour on the wire and on screen rather than from the scan or its options. Avoid 7 is moot, since the opener starts after the old process has gone. Avoid 9 and 10 hold: the gate is no `#if DEBUG`, and the feed is named `appcast.xml`.

#### 14. Testing seam

**The seam** is `LifecycleWorld`: real `Lifecycle`, `Launcher` and `Updater`, with every scenario in plain Swift Testing and no waiting.

| Cannot be waited for or provoked | Handle |
|---|---|
| The clock | `InMemoryIdleClock`: `pending`, `pass()` |
| Contact | `InMemoryTrackpads` touches; `isTouched`, `sensesContact` |
| Window | `Launcher` intents |
| Connectivity | `InMemoryConnection.set(_:)`, `isWatching` |
| Sparkle's callbacks | `InMemoryUpdateEngine.push(.held(.notGenuine))`, `.cycleEnded(.noConnection)`, and so on |
| A veto or a job that fails | `discardWorks`, `armWorks` flags |
| The process ending, and what follows | `copies.hasEnded`, `EffectLog` order, `world.finishHandOver(installed:)` starting the next process |
| Death at any effect | `snapshots` around "arm restart", as "kill at any effect" works today |

| Level | What runs there |
|---|---|
| `swift test`, world | R1 retry, spent reading, no hot loop; R2 and R12 gate; a `.end` or `.askToMove` route never starts the engine; R8's scenarios; R9 silent route, login item untouched; R11's no-check flag; R13 and R14 tables; R15 |
| `swift test`, Platform | `DeviceSession.receive` by direct call (palm, hover, `run` reset, sensing off makes no hop); `SparkleInternals` on temp folders and hand-built `NSError` chains (stale folder, two bundles, none, A7 shape at any depth); `isPinned`; `isGenuine` against the real fixture, whose other identity is R6's mismatch; the hand-over script run for real under `/bin/sh` with a stub `open`, a held pid and `allowed` of 1 s, asserting the wall-time bound and which argument arrived, which catches C2's bug; `CardContract`'s moved tests |
| `Scripts/update-e2e.sh`, built app | Two real builds from a patched spec (bundle identifier `.e2e`, local `SUFeedURL`, `NSAllowsLocalNetworking`), Developer ID signed and notarised, because the gate cannot be faked. In /Applications, nested one folder deep for the failure case. The local server mirrors GitHub's paths, redirects, cookies and validators. R1 login start, R3 on the wire, R5, R6 (tampered signature; signed by another identity, including another identifier), R7's client side, R9 with focus and timing, R11 by a read-only parent, R13, A10. It is the spike's scenarios ported to the real app. |
| By hand | Real logout, restart, shutdown (D-3); TCC and login item (L2); offline start (L3); sleep past the mark, with `defaults write SULastCheckTime`; a real 1.0.15 pressing *Update now* (R16) |

`why.md`'s lesson binds here: fakes hid plans 035's and 038's bugs, so the world tests prove decisions and the E2E proves the hand-over. Neither stands in for the other.

### Synthesis decision

### Tradeoffs accepted

- We accept a shell script polling for at most a few seconds, once per update, in exchange for R11, which nothing else can meet (C1), and for a helper that needs no signing and survives the swap.
- We accept `SMJobSubmit`, deprecated since 10.10 and declared removable, in exchange for the only non-permanent job API. Sparkle shares its fate, so its removal is one problem, not two.
- We accept private coupling to a cache layout and a job label in exchange for staying on the automatic path, the only path with A10's no-prompt guarantee, with an upgrade that fails a test until re-proven.
- We accept a synchronous signature check on main, about 19 ms once per release, in exchange for no phase in which an unchecked update waits. It looks like a slip against the concurrency rule and is not one.
- We accept a 0.4 s window where a process end installs an EdDSA-valid update without our check, because Sparkle offers no earlier hook. Exploiting it takes the private key.
- We accept that the idle minute starts no earlier than the moment an update is held, even if the pad was idle before, in exchange for no contact work in normal use. R8's "no trackpad" scenario reads the same way.
- We accept that a persistent install failure retries once per 24 hours, not sooner.
- We accept one extra `.afterUpdate(installed: false)` opening so the retry rule needs no persisted state.
- We accept that a new version which crashes at start leaves nothing running until the next login or opening; no older copy exists (`P022:1082`, rollback is a non-goal).
- We accept cookies being *offered* on the `latest` redirect (E4), refused by client policy, in exchange for atomic publishing. The policy is needed anyway: GitHub's cookie-free paths are a server fact that can change.
- We accept a feed that grows about half a kilobyte per release, in exchange for not pruning XML in shell.
- We accept Sparkle and WebKit loading in every build, measured, not avoided (G5).
- We accept a frozen duplicate of `isGenuine` in `CardContract`. It looks like a DRY violation and is the point: the card's rules must not move when the app's do.

### Alternatives considered

- **Sparkle's immediate handler, with a marker for the relaunch.** The documented "take control" path, and it hides the most from us. It exposes the window race (a quit refused after the handler leaves relaunch armed, B3), needs a stale-prone persisted marker because the relaunch carries no argument (B2), and still recovers nothing (C1). So it adds a watcher to a second restart path. It lost on R13 and R11.
- **The UI-based driver with `.skip` as a public veto (D6).** Removes the private label. It leaves the documented silent path (A2), allows a password prompt to be reached (A10 lost), and `.install` can show a progress window after 0.7 s. It lost on R9, R12 and R15.
- **Delete `Updater`; a thin wrapper in the app target, with decisions in `Lifecycle` and `Launcher`.** Fewest types. It scatters R8, R1 and R6 across two models and an untested target (`L022:27`) and breaks Preserve 7.
- **A committed feed on `raw.githubusercontent.com`.** Sends no `Set-Cookie` on any hop and stays editable, so its interface is simplest for R3. It adds a second publish effect after the release, with its own failure and retry path, against Preserve 13, and withdrawing a release becomes a hand edit.
- **R8's minute on `LaunchClock`, keeping the rule's text.** No rule change. It reports a system stop as passed, which can install early, and runs unmeasured in the exact state R8 fires in (H5).
- **Contact as an always-on `TrackpadEvent`, with a main-side timestamp.** Simple, and it gives "last touch" before the hold. It costs a main hop on every touch for a feature active minutes per release, and a flag that sticks across `run` (H3).
- **A watcher helper embedded in the bundle instead of `/bin/sh`.** A compiled tool could wait on a kernel exit source instead of polling. It is nested code the swap replaces under itself, with its own signing and notarisation, to save a few seconds of polling once per update.

### Open questions and risks

Only the human or a real Mac can settle these.

- **Does a real logout read as `.system` with the window open (D-3)?** If not, the shipped app cancels logouts today, and R14 fails with it. Can this be run before the first automatic release?
- **Do Accessibility, Screen Recording and the login item survive a Developer ID, notarised swap (L2)?** Same path, identifier and team say yes; no one has measured it, and a loss would be invisible under R15.
- **Does a true offline start surface a URL error in the chain (L3)?** If not, `outcome(of:)` reads `.failed`, and R1's "network arrives after login" silently waits 24 hours. Toggling Wi-Fi once settles it.
- **Does the Developer ID, notarised form of the hand-over match the Apple Development form (L7), for well past B11's 126 s?** `update-e2e.sh` answers on this Mac, but it needs a live login session and stops the running E2E copy only.
- **Does a Mac asleep past the mark fire on wake (A9), and does App Nap delay the idle minute on a windowless process (L5)?** A late minute is harmless; a timer that never fires is not, and it would leave the update for the next end of the process.
- **Do `Updater.app` and `Autoupdate`, idle while an update waits, delay a logout or cost idle CPU?** Sparkle's long use says no; it counts under Preserve 11 and R14.
- **Where does the exported private update key live?** It needs a place outside this Mac before the first automatic release. Losing it means every copy needs one manual install.
- **Is Sparkle's local `os_log` acceptable under "no logging" (D-5)?** The design says yes and states it in the docs. It names the update address and paths, on this Mac only.
- **What is the memory cost of loading Sparkle and WebKit (G5)?** If it breaks `product-overview.md`'s promise, is the cost accepted?
- **First automatic release:** R16's one press needs a real 1.0.15 copy after publishing, and no release can be recalled. `card-contract` covers the rules; only the real press covers the rest.

This branch is two commits behind `origin/main`, whose settings redesign (#45) moves the card's lines. Rebase before touching `LauncherUI`.

### Next implementation step

Add Sparkle to `Package.swift` with `Package.resolved`, prove the cold `--disable-keychain` build, then write `UpdatableCopy`, the three ports, their in-memory adapters and the new `Updater` against `LifecycleWorld`, test first, starting with R8's scenarios.
