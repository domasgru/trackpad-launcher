# Plan: Automatic updates

## Problem statement

A new version reaches a user only if they open the settings window and press *Update now*. Trackpad Launcher runs in the background, so most users rarely open that window. They stay on old versions with bugs that are already fixed. The update card also asks users to manage something they should never have to think about.

## Solution

Trackpad Launcher keeps itself up to date with no user action. It checks for a new version when it starts and every 24 hours after that. It downloads a new version in the background. It installs the version when the user is not using it, then restarts silently with no window, no Dock icon and no prompt. The update card goes away, and the settings window shows nothing about updates.

Updating uses Sparkle 2, the standard updater for Mac apps outside the App Store. It replaces Trackpad Launcher's own download and install code.

The privacy rule becomes: Trackpad Launcher makes no network calls but one kind: a copy signed with a Developer ID in /Applications that can write to its own bundle checks a public update list on GitHub at each start and every 24 hours, and downloads a new version from GitHub releases; no logging. `docs/domain-model.md` drops *Update card* and redefines *Update check* and *Newer version*.

## Requirements

### R1. Trackpad Launcher checks for updates on its own

A copy signed with a Developer ID in /Applications that can write to its own bundle MUST check for a newer version when it starts, at login or by hand, and every 24 hours while it runs. The check MUST NOT depend on the settings window. A check that fails for lack of a network connection MUST run again once a connection is available, not at the next 24-hour mark. The 24 hours are clock time: a Mac that sleeps past the mark checks when it wakes.

#### Scenario: Login start

- **GIVEN** version 1.0.0 is installed and version 1.1.0 has been released
- **WHEN** macOS starts Trackpad Launcher at login and the user never opens the settings window
- **THEN** version 1.1.0 downloads, as a network monitor shows, and installs once R8's conditions hold

#### Scenario: Running for days

- **GIVEN** Trackpad Launcher has run for three days without a restart
- **WHEN** version 1.1.0 is released
- **THEN** version 1.1.0 downloads within 24 hours, given a network connection

#### Scenario: Network arrives after login

- **GIVEN** login completes before Wi-Fi connects and a newer version exists
- **WHEN** the connection comes up a few minutes later
- **THEN** the check runs and the newer version downloads that day

#### Scenario: Sleeping past the mark

- **GIVEN** the last check ran 30 hours ago and the Mac slept for most of them
- **WHEN** the Mac wakes
- **THEN** a check runs

### R2. Other builds and copies never update

A development build, a copy outside /Applications and a copy showing the move dialog MUST make no network request for updates. A development build is a build not signed with a Developer ID. Once a move puts a copy in /Applications, the moved copy checks as in R1.

#### Scenario: Development build

- **GIVEN** a development build runs and a newer version has been released
- **WHEN** a day passes
- **THEN** it makes no network request

#### Scenario: Copy in ~/Applications

- **GIVEN** a copy signed with a Developer ID in ~/Applications that macOS starts at login
- **WHEN** a day passes
- **THEN** it makes no network request and stays on its version

#### Scenario: Moved to /Applications

- **GIVEN** a copy opened from ~/Downloads
- **WHEN** the user chooses *Move to Applications*
- **THEN** the installed copy makes an update check

### R3. A check reveals nothing about the user

Every request the updater makes, including the download, MUST carry nothing that identifies the user, the Mac, the app's version or the macOS version. Their headers MUST be the same on every Mac and every version. Trackpad Launcher MUST send no system profile, setting or usage data.

#### Scenario: What a check sends

- **GIVEN** a network monitor watches Trackpad Launcher's traffic
- **WHEN** an update check runs
- **THEN** the request has no query string, no cookie and no header that names the user, the Mac, the app's version or the macOS version

### R4. Only a newer full release that runs on this Mac counts

A *newer version* MUST be a published full release, with a higher version than the running one, whose minimum macOS this Mac meets. When several count, Trackpad Launcher MUST take the highest. It MUST never install an older version.

#### Scenario: Pre-release

- **GIVEN** version 1.0.0 runs and the only release above it is pre-release 1.1.0-beta
- **WHEN** an update check runs
- **THEN** nothing downloads

#### Scenario: Needs a newer macOS

- **GIVEN** the Mac runs macOS 26, version 1.1.0 needs macOS 26 and version 1.2.0 needs macOS 27
- **WHEN** an update check runs from version 1.0.0
- **THEN** version 1.1.0 is the one that installs

#### Scenario: Already the highest

- **GIVEN** version 1.1.0 runs and it is the highest full release (a higher one was withdrawn or none exists)
- **WHEN** an update check runs
- **THEN** nothing downloads

### R5. A newer version downloads in the background

Trackpad Launcher MUST download a newer version with no user action. The download MUST show nothing to the user. Gestures MUST keep working during it. A download that fails or stops MUST be retried at a later check.

#### Scenario: Gestures during a download

- **GIVEN** a download is running
- **WHEN** the user makes a 1-finger gesture
- **THEN** its assigned app comes to the front as usual

#### Scenario: Connection lost

- **GIVEN** a download is running
- **WHEN** the Mac loses its network connection
- **THEN** the user sees nothing, version 1.0.0 keeps running, and a later check downloads the update again

### R6. Only a genuine update installs

Trackpad Launcher MUST install a download only when it carries a signature made with the publisher's update key and is signed with the same Developer ID and bundle identifier as the running copy. Otherwise it MUST install nothing and show nothing, and a later check MUST try again.

#### Scenario: Tampered download

- **GIVEN** the downloaded update fails its signature check
- **WHEN** the download finishes
- **THEN** nothing installs, version 1.0.0 keeps running, and the user sees nothing

#### Scenario: Different Developer ID

- **GIVEN** a download passes the update key signature but is signed by another Developer ID
- **WHEN** the download finishes
- **THEN** nothing installs and version 1.0.0 keeps running

### R7. Every release is notarised

The release process MUST notarise every update. It MUST NOT publish one that is not notarised.

#### Scenario: Notarisation fails

- **GIVEN** a new version is being released
- **WHEN** its build fails notarisation
- **THEN** nothing is published and no copy sees it

### R8. The update installs only when the user is not using the app

After a download finishes, Trackpad Launcher MUST wait until both of these hold: no finger has made contact of any kind with any trackpad for 1 minute, and the settings window is closed. It MUST install 1 minute after the later of the last touch and the window closing. Logging out, restarting or shutting down before that MUST NOT delay the system. The update MAY install then. Otherwise the next start keeps the update waiting, or a later check downloads it again, and it installs under the same conditions.

#### Scenario: User is working on the trackpad

- **GIVEN** a download finished and the user is touching the trackpad
- **WHEN** the user keeps using it, with gaps under 1 minute
- **THEN** nothing installs until the trackpad has been untouched for 1 minute

#### Scenario: Settings window is open

- **GIVEN** a download finished and the settings window is open
- **WHEN** the trackpad stays untouched for 10 minutes
- **THEN** nothing installs while the window stays open
- **AND** the update installs 1 minute after the later of the last touch and the window closing

#### Scenario: Mac with no trackpad in use

- **GIVEN** a download finished, the settings window is closed and the trackpad is never touched
- **WHEN** 1 minute passes
- **THEN** the update installs

#### Scenario: Shutting down with an update waiting

- **GIVEN** a downloaded update is waiting and the user shuts down
- **WHEN** macOS starts Trackpad Launcher at the next login
- **THEN** either version 1.1.0 runs, or 1.0.0 runs and 1.1.0 installs once the conditions hold
- **AND** either way no window, Dock icon or dialog appears and gestures work

### R9. The new version restarts silently

After installing, the new version MUST run with no settings window, no Dock icon, no dialog and no permission prompt. It MUST stop the old version. Gestures MUST work again within 10 seconds.

#### Scenario: Update while the user works in another app

- **GIVEN** version 1.0.0 runs with gestures assigned, the window closed, and the trackpad idle for 1 minute
- **WHEN** the update installs
- **THEN** version 1.1.0 runs from /Applications, no window or Dock icon appears, keyboard focus stays in the user's app, and gestures work

#### Scenario: Opening by hand afterwards

- **GIVEN** version 1.1.0 restarted silently
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the settings window opens as usual

### R10. Settings and permissions carry over

Every setting, starting at login and the Accessibility and Screen Recording permissions MUST carry over to the new version.

#### Scenario: After an automatic update

- **GIVEN** version 1.0.0 has gestures assigned, starting at login on, Accessibility and Screen Recording granted, a non-default thumb corner and *Hide background apps* on
- **WHEN** version 1.1.0 installs automatically
- **THEN** the same apps are assigned, starting at login is still on, Accessibility and Screen Recording are still granted, the thumb corner is the same and *Hide background apps* is still on

### R11. A failed install keeps the current version

At every moment /Applications MUST hold either the whole old version or the whole new one. A failed install MUST end with a working copy running again within 10 seconds. The user MUST see nothing, and a later check MUST try again.

#### Scenario: Install fails

- **GIVEN** the update is installing
- **WHEN** the install fails
- **THEN** a whole working copy stays in /Applications, gestures work again within 10 seconds, and the next check tries again

### R12. A copy that cannot write to its own bundle stays on its version

A copy that cannot write to its own bundle MUST make no update check and no download, and MUST NOT ask for a password. It checks again at its next start whether it can write.

#### Scenario: Standard account

- **GIVEN** a standard account that cannot write to /Applications, and a newer version
- **WHEN** Trackpad Launcher starts
- **THEN** it makes no network request, no password prompt appears, and the current version keeps running

### R13. The app's own quit stays final

*Quit Trackpad Launcher* MUST stop the app at once, in any update state, and an update MUST NOT start the app again afterwards. Every other way to quit MUST keep closing only the settings window.

#### Scenario: Quit with an update waiting

- **GIVEN** a downloaded update is waiting for the trackpad to go idle
- **WHEN** the user presses *Quit Trackpad Launcher*
- **THEN** the app stops and stays stopped until the user opens it

### R14. Updates never block quitting

Logging out, restarting and shutting down MUST end the app without asking and with no delay from an update.

#### Scenario: Restart with an update pending

- **GIVEN** an update is downloading or waiting
- **WHEN** the user restarts the Mac
- **THEN** the restart proceeds with no dialog

### R15. No update interface

The settings window MUST show no update card, no update setting and no update status. Nothing takes the card's place.

#### Scenario: Settings window with an update waiting

- **GIVEN** a downloaded update is waiting
- **WHEN** the user opens the settings window
- **THEN** the window opens as it does with no update known, and shows nothing about updates

### R16. Older copies can still update

Every new release MUST stay installable from the update card of versions before the first automatic-update version. This binds every future release's assets for as long as such copies may exist. Those copies MUST reach an automatic-update version with one press of *Update now*.

#### Scenario: Last card

- **GIVEN** version 1.0.14 runs and the first automatic-update version has been released
- **WHEN** the user opens the settings window and presses *Update now*
- **THEN** the new version installs, and later versions arrive automatically

## Non-goals

- **An off switch for updates.** The user chose no update interface at all.
- **A password prompt or notice for standard accounts.** A surprise password prompt looks suspicious, and most copies run on single-admin Macs. These Macs update when an administrator installs a new version by hand.
- **Showing the version number or a *Check for Updates* button.** The user chose no update interface at all.
- **Telling the user an update happened.** Updates stay invisible, including failures.
- **Release notes in the app.** With no interface, nothing would show them.
- **Mandatory or staged rollouts.** Every copy takes every full release.
- **Rolling back a release.** A bad release is fixed by publishing a higher version.
- **Fast user switching.** Two accounts running the app at once on one Mac get no special handling; the other session's copy picks up the new version at its next start.

## Design

### Problem

A new version reaches a user only through a card in a window most users never open. Sparkle 2 replaces the hand-written check, download and install, and the card goes. The shape is not obvious because Sparkle's silent path falls short of this app's rules in specific, probed ways. It installs at any end of the process and offers no cancel. Its immediate handler quits with an event `Lifecycle` reads as the Dock's Quit, relaunches as an opening by hand, stays armed after a refused quit, and recovers nothing from a failed swap. It enforces neither "same Developer ID" nor "same bundle identifier". It keeps cookies. Its scheduler misses "a check at every start" and "again when a connection arrives". The design also has to honour what is already here: `LauncherCore` imports Foundation and Observation only, every port has two adapters, the gate is an object's absence, `Opening` is matched exhaustively, the card's `.aar` contract outlives the card's code, releases are immutable, and idle stays at zero.

Evidence for every claim below is in `.temp/architect/grounding/index.md` (fact numbers such as A5 or C1) and `.temp/architect/checks/`.

### Usage (caller's view)

There is no interface, so what a maintainer learns is small. The composition root builds an `Updater` only for a copy the gate lets through. `Lifecycle` starts it once the process is resident and ends the process when it asks. `Launcher` knows nothing about updates; it can be asked whether the app is in use.

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
    guard case .replacingOthers(let opening, let opensWindow, let eject) = stage else { return }
    let launcher = makeResident()
    launcher.start()
    stage = .resident(launcher)
    if opensWindow { launcher.openedByHand() }
    if let eject { installer.eject(eject) }
    updater?.start(watching: launcher, opening: opening)
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

    let next = world.finishHandOver()                      // what the job and Sparkle's installer do
    #expect(next.lifecycle.launcher?.window == .closed)
    #expect(world.loginItem.isOn)
    #expect(next.engine.checks == 0)
}
```

```text
Releasing is unchanged:   Scripts/release.sh patch
Once, by hand:            generate_keys, then generate_keys -x into offline storage
After a failed feed push: Scripts/release.sh --feed-only <version>
After upgrading Sparkle:  a test fails until Scripts/update-e2e.sh has run and SparkleInternals.provenOn is raised
```

### Shape

#### Load-bearing decisions

1. **The automatic path, always held.** `willInstallUpdateOnQuit` returns true and its immediate handler is dropped unused. So Sparkle's relaunch flag is never set, B1 to B3 are unreachable, and A5 is the only way an install runs.
2. **We end ourselves.** A one-shot launchd job, armed in the same main-actor turn that ends the process, is the only thing that restarts the app (B4, C2).
3. **`Updater` survives as the one owner of update decisions**, smaller and deeper, with no version in it. Sparkle sits behind one port. Sparkle's private behaviour sits in one type in one file.
4. **`Launcher` learns "in use", not "update".** Contact sensing and the idle minute exist only while a verified update waits.
5. **R6's second half is checked synchronously inside the delegate call**, so no main-actor turn exists in which an unchecked update is held. It costs 18 to 31 ms on a stapled app, once per release.
6. **The feed is a committed file on `raw.githubusercontent.com`.** One hop, no query string, no cookie, correctable after publishing.
7. **The card's rules move to a target that never ships**, and the release runs them on the real archive.

#### What an update can be in

Sparkle owns "checking" and "downloading", and nothing here reads them. `Updater` holds only what it must act on. Each lasting effect belongs to exactly one phase, and all of them start and stop in one transition function, so a running minute without a verified update, or a connection watch beside a held update, cannot be written (per `model-the-domain`).

```swift
private enum Phase {
    /// Nothing to do. Sparkle's schedule, or a check, may be running.
    case resting
    /// R1. The last cycle's request failed, and the connection watch runs. `retrySpent`: this reading's one retry has
    /// been made, so only a drop and a return earn another. One bit; no timer, no backoff.
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
| `Launcher.watchUse`, contact pushes from the frame thread | `.ready` |
| The 60 s wait | `.ready` and not in use |
| The launchd job | `.handedOver`, and that phase lasts one turn |

Persisted state: none of ours. An interrupted update resolves from what is on disk and in Sparkle's cache.

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` | `Updater` rewritten; `UpdatableCopy` replaces `InstalledRelease`; `Opening.afterUpdate`; ports `UpdateEngine`, `Connection`, `IdleClock`; `TrackpadEvent.contactChanged`; `Launcher.isInUse`, `watchUse`. `Lifecycle` loses every install guard. `Release`, `UpdateEvent`, `UpdateCard`, `Version`, `ReleaseList`, `UpdateInstaller` go. Core no longer holds a version number. |
| `LauncherPlatform` | `SparkleEngine` (with `SparkleInternals`, `SilentUserDriver`, `isPinned`), `LaunchdJob` (with the hand-over script), `SystemConnection`, `SystemIdleClock`, contact in `DeviceSession` and `MultitouchTrackpads`. `GitHubReleases`, `ApplicationsUpdater` and `BundleInstall`'s unpacking go. `CodeSignature.isGenuine` stays, against `ExpectedUpdate`. |
| `LauncherUI` | The card, its layout input and every `updater` reference go. |
| `CardContract`, `card-contract` (new, never linked by the app) | Frozen copy of the card's rules: a library, a tool, their tests. |
| App target | `makeUpdater` as above. No decision. |

#### Types and signatures

```swift
// ─── LauncherCore ───────────────────────────────────────────────────────────────────────────────

public enum Opening: Equatable, Sendable {
    case atLogin
    case byHand
    /// The hand-over job started this process, `--after-update`: the new version, or the old one after a failed install.
    case afterUpdate
}

public enum Route: Equatable, Sendable {
    case runSilently, runWithWindow, askToMove, end
    /// The new rows are compile-forced. The argument means something only where an update lands; anywhere else it reads
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

// Lifecycle.Stage: case replacingOthers(opening: Opening, opensWindow: Bool, eject: DiskImage?)

/// R2 and R12, the gate, whole. Pure, called by the composition root and the tests. Read once, at start.
public struct UpdatableCopy: Equatable, Sendable {
    public init?(placement: Placement, developerIDSigned: Bool, canReplaceItself: Bool) {
        guard developerIDSigned, placement == .installed, canReplaceItself else { return nil }
    }
}

public enum CycleOutcome: Equatable, Sendable {
    /// Up to date, or nothing that could be taken.
    case nothingNew
    /// A request failed, the feed's or the archive's. What a lost connection looks like, and what earns R1's retry.
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
    /// A cycle ended: no update, a failure, or a held update lost (a helper died, C5).
    case cycleEnded(CycleOutcome)
}

/// Sparkle, and the restart that follows it. No Sparkle type, feed value or version crosses this port.
/// Real: SparkleEngine. Test: InMemoryUpdateEngine.
@MainActor public protocol UpdateEngine: AnyObject {
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? { get set }
    /// Makes no request before this call. Starts the 24-hour schedule.
    func start()
    /// One background check. Asked while a cycle runs or is ending, it runs once that cycle has finished, so a retry is
    /// never lost. It never runs while an update is held.
    func check()
    /// Stops the held update installing. Best effort, two layers; if both fail it installs at this process's end.
    func discardHeldUpdate()
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
//   /// Contact of any kind on any running trackpad, read now: palms yes, hovers no. Reads no clock.
//   var isTouched: Bool { get }
//   /// While true, each flip pushes `.contactChanged`. Off costs one flag read per flip and no hop.
//   var sensesContact: Bool { get set }

extension Launcher {
    /// A finger on any trackpad, or the settings window open, minimised or hidden included.
    public var isInUse: Bool { fatalError("not implemented") }   // window != .closed || hardware.isTouched

    /// While set: `onChange` now with the present reading, then at each change and after each `run`. nil stops it, and
    /// contact sensing with it. `Launcher` does not know why it is asked.
    public func watchUse(_ onChange: (@MainActor (Bool) -> Void)?) { fatalError("not implemented") }
    // TODO: reportUse() runs on `.contactChanged`, in openedByHand on the edge from closed, in closeWindow, and after
    // hardware.run in reconcile. The last is the reset rule (H3): `run` replaces sessions, so an in-flight lift can
    // vanish, and re-reading the level cannot stick. A report of "not in use" after a `run` restarts the minute, which
    // is what a wake wants: the user has a minute to touch the pad before an install. A resting finger comes back on
    // its next frame.
}

/// Owns every update decision: R1's retry, R8's rule, R6's verdict, the order of the hand-over.
@MainActor public final class Updater {
    /// The process must end now, through `end()`. Set once by `Lifecycle`.
    public var onHandOver: (@MainActor () -> Void)?

    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection, clock: any IdleClock) {
        fatalError("not implemented")
    }

    /// Once, from a resident only. Starts the engine and, unless this process is the hand-over's, checks in the same
    /// turn (A8). A failed install must not check at once, or it would hand over once a minute for ever (`discardquit.out`).
    public func start(watching launcher: Launcher, opening: Opening) { fatalError("not implemented") }

    private func handle(_ event: UpdateEngineEvent) {
        // .held(.genuine)             → enter(.ready)
        // .held(.notGenuine)          → engine.discardHeldUpdate(); stay .resting. No restart is ever armed for it.
        //                               .cycleEnded(.failed) follows from Sparkle once its helper has gone (D5).
        // .cycleEnded(.requestFailed) → already awaiting: stay as it is, so a drop during the retry still earns the next
        //                               one. Otherwise enter(.awaitingConnection(retrySpent: false)).
        // .cycleEnded(other)          → enter(.resting)
        fatalError("not implemented")
    }

    private func connectionChanged(_ connected: Bool) {
        // Only while .awaitingConnection(let spent):
        //   !connected           → spent = false
        //   connected && !spent  → spent = true; engine.check()
        // No hot loop: a check spends the reading before it runs, and a spent reading needs a real drop.
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

/// `internal import Sparkle` lives in this file and nowhere else. SPUUpdater, SPUUserDriver and SPUUpdaterDelegate are
/// NS_SWIFT_UI_ACTOR, so main-actor classes conform with no escape hatch. The delegate below is a private object, held
/// here because SPUUpdater keeps it weakly: a public conformance would put a Sparkle type on `LauncherPlatform`'s surface.
@MainActor public final class SparkleEngine: UpdateEngine {
    public var onEvent: (@MainActor (UpdateEngineEvent) -> Void)?

    /// Reads CFBundleVersion and the downloads prefix now: after a swap, `Bundle.main` reads the new bundle (M36).
    public init(bundle: URL, signer: Signer) { fatalError("not implemented") }

    /// R12's predicate. Sparkle's private rule read-only: `SparkleInternals.canReplace`.
    public nonisolated static func canReplace(_ bundle: URL) -> Bool { SparkleInternals.canReplace(bundle) }

    public func start() {
        // HTTPCookieStorage.shared.cookieAcceptPolicy = .never                     // before the first request (E3)
        // URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)           // no Cache.db (textplain.out)
        // let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        // updater.userAgentString = "TrackpadLauncher"
        // updater.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]
        // do { try updater.start() } catch { onEvent?(.cycleEnded(.failed)) }      // an empty key lands here, silently
        fatalError("not implemented")
    }

    public func check() {
        // sessionInProgress ? checkPending = true : updater.checkForUpdatesInBackground()
        // Sparkle's session stays on for an async probe after didFinishUpdateCycle, and a connection reading lands in
        // that window: the next main turn read true on the first try (pendingcheck.out). Nothing else would ask again.
        fatalError("not implemented")
    }
    public func discardHeldUpdate() { fatalError("not implemented") }  // SparkleInternals.veto(job:, extracted: found)
    public func armRestart() -> Bool { fatalError("not implemented") } // LaunchdJob.submit(hand-over script, ...)

    /// nil and SUNoUpdateError are `.nothingNew`; SUDownloadError is `.requestFailed`; everything else `.failed`. Public
    /// codes: every URLSession failure, feed or archive, reaches this level wrapped in SUDownloadError (noserver.out).
    nonisolated static func outcome(of error: (any Error)?) -> CycleOutcome { fatalError("not implemented") }

    private final class Delegate: NSObject, SPUUpdaterDelegate {
        /// A12. Refuses, before any download, an enclosure outside this repository's tagged assets or not an `.aar`.
        /// That keeps the disk-image key-rotation fallback (D3) unreachable, so R6's update-key half has no second door.
        func updater(
            _ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck
        ) throws { fatalError("not implemented") }

        /// Always true. The handler is dropped unused, so Sparkle's relaunch flag can never be set.
        func updater(
            _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
            immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
        ) -> Bool {
            // checkPending = false      // a held update stalls the cycle; a veto must not re-download at once
            // let found = SparkleInternals.extractedUpdate(identifier: signer.identifier, build: item.versionString, ...)
            // let genuine = found.map { CodeSignature.isGenuine($0, as: ExpectedUpdate(item), signer: signer) } ?? false
            // onEvent?(.held(genuine ? .genuine : .notGenuine))
            // return true
            fatalError("not implemented")
        }

        func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor check: SPUUpdateCheck, error: (any Error)?) {
            fatalError("not implemented")  // onEvent?(.cycleEnded(outcome(of: error)))
        }

        /// The cycle has fully ended and the session is off: a check `check()` remembered runs here. It re-arms the
        /// 24-hour timer through its own cycle (pendingcheck.out).
        func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
            fatalError("not implemented")
        }
    }
}

/// Every fact here is Sparkle's private business, proven on `provenOn`. Each names its proof. A test compares
/// `provenOn` with LauncherKit/Package.resolved, so an upgrade cannot land without re-proving this type.
enum SparkleInternals {
    static let provenOn = "2.10.1"

    /// A11, read-only: bundle writable, parent writable, bundle owned by this user, and its group one of this user's.
    /// Sparkle's rule proves the last two by chowning a temporary file; this creates nothing. A stricter future Sparkle
    /// costs a silent download at each check, never a prompt (A10).
    nonisolated static func canReplace(_ bundle: URL) -> Bool { fatalError("not implemented") }

    /// D4. `Installation/<random>/<random>/` under Sparkle's cache. nil unless the newest such folder holding `build`
    /// holds exactly one bundle: a logout leaves stale folders, and two bundles cannot be told apart from what Sparkle
    /// would choose (D2).
    static func extractedUpdate(identifier: String, build: String, caches: URL) -> URL? { fatalError("not implemented") }

    /// D5. Removing this job ends the installer; Sparkle then aborts with 4005.
    static func installerJob(of identifier: String) -> String { "\(identifier)-sparkle-updater" }

    /// Both layers, each whatever the other did: remove the job, then discard the extracted bundle. Takes what it acts
    /// on, so a test can drive either layer alone. Inside the delegate call (vetonow.out).
    static func veto(job: String, extracted: URL?) { fatalError("not implemented") }
}

/// Under `prefix`, ending in `.aar`, with no `..`. A missing prefix admits nothing. The prefix is the Info.plist key
/// `TLUpdateDownloads`, so no address exists in Swift and a local server can stand in for GitHub; that the shipped key
/// is `https` is the scan's rule, `alwaysDeclared`, not this function's.
func isPinned(enclosure: URL?, under prefix: String?) -> Bool { fatalError("not implemented") }

/// The offer, from the feed, that the extracted bundle's sealed Info.plist must equal.
struct ExpectedUpdate: Sendable { let version, build, minimumMacOS: String }

/// `SMJob` lives in this file and nowhere else. Deprecated since 10.10, and the only way to submit a non-permanent job:
/// Sparkle's own comment says so, and it shares this API's fate.
enum LaunchdJob {
    static func remove(label: String) -> Bool { fatalError("not implemented") }
    /// Removes any stale job of this label first.
    static func submit(label: String, arguments: [String]) -> Bool { fatalError("not implemented") }
    /// The hand-over job. `allowed` is 5 s in production; a test passes its own, and a stub for `open`.
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
//   // init takes `sensesContact: @Sendable () -> Bool`, as it takes `clock`, so a test owns its own flag.
//   // First lines of `receive`, on frame.touches, so before the recognizer's palm filter (H2):
//   let touched = !frame.touches.isEmpty
//   let flipped = occupied.withLock { was in defer { was = touched }; return was != touched }
//   if flipped, sensesContact() { deliver(.contactChanged, nil) }
//
// MultitouchTrackpads holds `private let contactSensed = Mutex(false)`, one writer (main), and passes a closure over
// it: the flag outlives `run`, a session does not. `isTouched` copies sessions out and asks each, as `mergedTapState`
// does: never two locks at once.
```

**Depth.** `Updater` shows three things: an initializer, `start`, `onHandOver`. Behind them sit R1's retry, R8's rule, R6's verdict and the hand-over's order. `UpdateEngine` has four methods and one push. Behind them sit Sparkle's configuration, the cookie and cache policy, headers, the enclosure pin, the silent driver, error parsing, the extraction lookup, the signature check, a two-layer veto and the launchd job. Callers keep only what they decide with: held or not, and how a cycle ended. The deletion test passes: remove either and R6, R8 and R1 reappear across `Lifecycle` and the app target.

#### 1. The Sparkle path, and what crosses

The path is the documented automatic one (A1): `SUAutomaticallyUpdate`, `SUEnableAutomaticChecks`, `SUVerifyUpdateBeforeExtraction`, `SUPublicEDKey`, `SUFeedURL` in `project.yml`'s Info.plist properties, beside our own `TLUpdateDownloads`, plus the driver the initializer requires, which shows nothing. No `SPUStandardUpdaterController`. Selection stays Sparkle's: it filters by minimum macOS and takes the highest build, which is R4, and its header asks integrators not to reimplement that. XPC services stay in the bundle unused (G6), so nothing has to strip a signed framework.

| Coupling | Standing | Where it lives |
|---|---|---|
| Info.plist keys, `SPUUpdater`, `start`, `userAgentString`, `httpHeaders`, `shouldProceedWithUpdate`, `willInstallUpdateOnQuit` returning true, `didFinishUpdateCycle`, `willScheduleUpdateCheckAfterDelay`, `SUError` codes | Public | `SparkleEngine` |
| "Sparkle will always attempt to install the update when the app terminates", no relaunch unless requested | Public, in the header | The basis of `armRestart` |
| `checkForUpdatesInBackground` straight after `start` | Blessed by the docs | `Updater.start` |
| The same call when a connection arrives | **Departure.** The docs warn it "could interfere with Sparkle's scheduler". It invalidates and re-arms the 24-hour timer, so the mark moves to the retry, which is what R1 means. No public call forces a check, because a failed check stamps `SULastCheckTime` (A8). | `SparkleEngine.check` |
| Driver that shows nothing | Required by the initializer. The docs' warning is about using a driver *to* install silently; `SUAutomaticallyUpdate` does that here. Its only live use is `.dismiss` on the refused-install path (A10). | `SilentUserDriver` |
| Extraction layout (D4), installer label (D5), writability rule (A11) | **Private** | `SparkleInternals`, one type |

An upgrade is findable twice: `SourcePolicyTests` confines `import Sparkle`, `org.sparkle-project` and `sparkle-updater` to one file, and a test fails until `provenOn` equals `Package.resolved`'s Sparkle version (per `encode-lessons-in-structure`).

#### 2. Ownership

`Updater` survives. It stops being `@Observable`, because nothing renders it. `Launcher` loses its `updater` parameter and `SettingsShell` loses its stored one; `Updater` watches `Launcher` as a concrete Core type, so no one-adapter protocol appears. `Lifecycle` keeps its one exhaustive quit switch, loses `isInstalling` from `shouldEnd` and `quit`, and gains `handedOver()`, which is today's `replaced()` renamed. `Stage.replacingOthers` carries the opening, so `othersExited` can pass it on. No update decision lives in `Lifecycle`, `Launcher` or the app target.

`Updater` stays built in `applicationWillFinishLaunching`, because that is where the gate reads the running copy. Building it does nothing: `SparkleEngine.start` creates the `SPUUpdater`.

#### 3. R8's gate

**Contact** is read at `DeviceSession.receive` on `frame.touches`: it sees palms and not hovers, and reads no clock (H2). Normal touches cost one uncontended lock per frame and, on a flip, one flag read, with no hop. So "no finger down means no work" holds as today, and a touch costs no main-actor hop unless an update waits.

**Window edges** arrive through `Launcher`'s own model, which flips before AppKit's `orderOut` (H4). A minimised or hidden window stays `.open` and blocks.

**One input.** Both reach `Updater` as one boolean, `inUse`. So "1 minute after the later of the last touch and the window closing" needs no timestamps: each report of "not in use" starts the minute, any report of "in use" cancels it, and at the fire `Updater` re-reads the level, so an edge still queued on main cannot lose a touch. The minute counts from the moment an update is held at the earliest, which is R8's "no trackpad in use" scenario.

**The minute** is a one-shot `DispatchSource` timer in one file, and the no-timer rule changes on purpose:

- The rule's motive is idle CPU. This timer exists for minutes per release and only while a verified update waits (H6).
- `LaunchClock` is the wrong tool. It reports a system stop as *passed*, which is right for a cap and wrong here. Its 60 s behaviour with the display asleep is unmeasured, which is exactly when R8 fires (H5). Its rule says a deadline cannot outlive its effect, and this one has no effect on screen.
- The clock stops during sleep, and the `run` at wake restarts the minute, so an install never lands the moment a lid opens.

Rule text for `docs/architecture.md`: *"…Time passes only on Core Animation's clock, with these exceptions, each confined to one owner: a one-shot timer for an automatic update's idle minute, armed only while a verified update waits and nothing uses the app; Sparkle's own 24-hour one-shot; and the hand-over job's bounded wait, which runs after this process has ended."*

A dead trackpad reads as idle, which R8's scenario wants. A stuck `occupied` delays the install until the next touch or `run`: it fails safe.

#### 4. The hand-over (R9, R11)

Order of effects. Steps 1 to 3 run in one main-actor turn, so nothing can interleave.

| # | Effect | If the process or a helper dies right after it |
|---|---|---|
| 1 | Minute passes; level re-read | Held update installs at the end, no relaunch (A5). A later login or opening runs the new version: "never relaunches after a crash" stands. |
| 2 | `armRestart`: remove a stale job, `SMJobSubmit` the one-shot with old pid, bundle, old build | Job carries on and finishes the hand-over: the crash came after the decision. `armRestart` false: stay `.ready`, keep running, try on the next idle edge. The update still installs at the next end. No loop. |
| 3 | `.handedOver`, `Lifecycle.end()`: `.ending`, `NSApp.terminate` | As step 2. `shouldEnd` answers yes in `.ending`, so the old copy cannot refuse. |
| 4 | `Updater.app` sees the exit; `Autoupdate` runs stage 3 | Installer killed before the swap: bundle untouched; job's budget runs out; old copy returns. |
| 5 | `renamex_np(RENAME_SWAP)` | Atomic: one whole copy on disk (C4, D-4). `archive_and_check` requires `Autoupdate` to carry the release's Team ID, or Sparkle would fall back to two moves. |
| 6 | Job sees the build change; `open -g -a <bundle> --args --after-update` | Job killed (only logout does): nothing runs until login, and the login item is intact. |
| 7 | `.afterUpdate`, `.runSilently`, stop others, resident, no check at start | New version crashes: nothing runs until the next login or opening. This is plan 022's accepted cost; no older copy exists to return to (rollback is a non-goal). |

**On failure** (C1), `Autoupdate` exits and nothing restarts the app. The job's budget runs out, at least 5 s and at most 6 s from the old pid's exit on **wall time** (C2's lesson; `date +%s` counts whole seconds), and it opens whatever is there with the same `--after-update`: the old copy, silent. So a swap gets a full 5 s before the job gives up on it. That start does not check (`discardquit.out` shows the loop if it did: check, download, a minute, fail, for ever). Sparkle's schedule retries within 24 hours of the stamped check, which is R11's "a later check", and an overdue stamp checks once at start and then is fresh, so no tight loop exists either way. Worst case to gestures: about 6 s, plus `open` and the app's own start (about a second of CPU), inside 10 s. The app logs nothing and nothing outside it shows gestures running, so `update-e2e.sh` times this with a person's tap, and the process's start with its sampler.

One argument serves both ends because a process needs to know only that it should start silently. The cost is that a successful update does not check at start, and the next check comes at the 24-hour mark. R1's "when it starts, at login or by hand" does not cover this start.

**Why a job at all.** D-1 is settled by R11: Sparkle cannot recover from a failed swap (C1), and only something outside the old process, created before it ends, can (C3). `why.md` Avoid 4 and 5 came from plans where the old process was alive at hand-over, or from another failure, and did not weigh R11. The glossary's "never relaunches itself after a crash or a force quit" still holds: the job is only ever created in the same turn as a deliberate end.

```sh
# launchd: /bin/sh -c "$script" handover <pid> <bundle> <build> <allowed> <open>
# LaunchOnlyOnce, RunAtLoad, EnableTransactions false, ProcessType Interactive. kSMDomainUserLaunchd. Parent: launchd.
old=$1; bundle=$2; build=$3; allowed=$4; open=$5
# Never open while the old process lives: it would only show its window. It ends in this same turn; if it hangs, the
# wait holds until it goes, so a late end still installs and still comes back.
while /bin/kill -0 "$old" 2>/dev/null; do /bin/sleep 0.05; done
gone=$(/bin/date +%s)
while [ $(( $(/bin/date +%s) - gone )) -le "$allowed" ]; do
  now=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null)
  if [ -n "$now" ] && [ "$now" != "$build" ]; then break; fi
  /bin/sleep 0.1
done
exec "$open" -g -a "$bundle" --args --after-update
```

`ThisCopy.launch` turns `--after-update` into `Opening.afterUpdate`, beside `--eject-disk-image`, and a reopen still reads only the event. `open -g` leaves focus alone (B4, H8), the argument is a positive signal with nothing persisted (B6), and a copy that once had a window hands over cleanly (B11). The version comparison couples to nothing of Sparkle's. An opening by hand during the 200 ms gap either receives a re-front or, on a different build, is stopped by the silent copy; the user reopens, one window lost in a race that needs an opening in that exact gap.

**R10 carries over because an update changes nothing but the bundle at the same path.** The identifier and team stay, so the designated requirement macOS keeps with each permission still matches, and the installed copy's path and name stay (B9, B10). The defaults domain is the same, and `Updater` writes nothing to it. The hand-over goes through `end()`, never `quit()`, so it makes no login-item call (B8). The `.afterUpdate` route never runs `openedByHand`, so no first run, no `resume` and no ask. Whether macOS really keeps the grants and the login item across this swap has never been measured, so it is a by-hand check on a notarised build (L2).

#### 5. R13 and R14

| Way of quitting | Nothing, or a check or download running | Verified update waiting |
|---|---|---|
| *Quit Trackpad Launcher* | `suspend`, `end`, at once. The download dies with the process. | Same. Sparkle installs at exit with no relaunch (`plainquit.out`); the app stays stopped until opened. |
| ⌘Q, close, Escape, Dock's Quit, window open | Window closes only | Window closes only; the idle minute may start |
| `.other`, window closed (script, Activity Monitor) | Ends | Ends; installs at exit; no restart |
| `.system` | Ends at once | Ends at once; Sparkle may install; no job exists, no restart |
| Crash, force quit, another copy's stop | Ends | Installs at exit; no restart |

Nothing is left armed, because only two things could restart the app and neither can be pending after a quit. Sparkle's relaunch flag is set only by the immediate handler, which is never called (B3 unreachable). The job is submitted only in the turn that ends the process, so a Quit lands either before it, when no job exists, or after the process has gone. The `isInstalling` guards go. `shouldEnd`'s table is otherwise unchanged, and `.system` always wins. R14's dependence on a real logout reading as `.system` is the shipped risk D-3. A minute that passes between `willPowerOff` and the quit event hands over as usual: the old copy ends, which is what logout wants, and the job's `open` meets a session already ending.

#### 6. R6

**The update-key half.** `SUVerifyUpdateBeforeExtraction` makes Sparkle check EdDSA before extracting. The only way past a failed EdDSA check is a same-team Developer ID disk image (D3). `isPinned`, in the public `shouldProceedWithUpdate` (A12), refuses every enclosure but a tagged `.aar` of this repository, silently and before any download. An `.aar` cannot carry a code signature, so that door does not exist. `SURequireSignedFeed` is not adopted: R6 is about the download, and it would add a failure mode that silently stops every copy.

**The Developer ID and identifier half.** Sparkle checks only validity (D1, D2), so at A3's moment `SparkleEngine` runs `CodeSignature.isGenuine` on the extracted bundle: Developer ID, this team, this identifier, `notarized`, strict and nested validation, offline, sealed versions equal to the offer (D7). Notarisation at install stays: it is free, and older copies already enforce it. The check runs synchronously on main, 18 to 31 ms on the stapled 6 MB app (`genuine.out`), once per release, so there is no phase in which `Quit` could install an unchecked update. It is a named exception to "work that would delay a click runs off main".

**Fail closed.** No bundle found, two bundles, a stale layout or an unreadable signature all read `.notGenuine`.

**The veto.** `discardHeldUpdate` has two independent layers. Each is proven alone, and both together inside the delegate call, which is where `.held(.notGenuine)` runs it: the cycle ended with 4005 a millisecond later, and ending the process three seconds on installed nothing (`vetonow.out`).

1. `LaunchdJob.remove(installerJob)`: abort 4005, cycle ends, nothing installs, a later check runs normally (`veto.out`).
2. Whatever the first did, `BundleInstall.discard` on the extracted bundle, so stage 3 has nothing to install. Run alone with the job left alive: stage 3 failed, the old app stayed whole, nothing installed (`discardquit.out`).

**When a veto fails.** Both layers failed, which needs Sparkle's label and its layout to have changed together, and `provenOn` blocks that. The result: `.resting`, no restart is ever armed, Sparkle's cycle stays stalled, and the update installs at the next end of the process. It still carries the publisher's EdDSA signature. **Residual gaps, named:** this one; and a process end in the moments between Autoupdate finishing stage 1 and the delegate call, which installs an EdDSA-valid update unchecked (A5). Neither is reachable without the private key.

#### 7. R1

| Trigger | Mechanism |
|---|---|
| Every start | `checkForUpdatesInBackground` straight after `start()` (A8). Not at an after-update start. |
| Every 24 hours | Sparkle's one-shot walltime source (A9). `SUScheduledCheckInterval` stays at its default. |
| Wake past the mark | The same source: its wall clock counts sleep, so it fires on wake (A9). |
| Connection after a failure | `.awaitingConnection`, `Connection.watch`, `engine.check()` |

No hot loop: `retrySpent` is set as the retry is made, so a check needs a fresh reading. The first failure earns one retry on the first "connected" reading, and `NWPathMonitor` pushes that reading at once (`path.out`, 2.5 ms), which closes the race where the path came up before the watch armed. That reading lands while Sparkle's session is still on for its end-of-cycle probe, so `check()` remembers it and fires from `willScheduleUpdateCheckAfterDelay`, the moment the session is off; the retry that ran there re-armed the 24-hour timer (`pendingcheck.out`). A retry that fails on a steady path needs a real drop and return; a drop during the retry earns the next one, so a link that falls mid-retry still comes back. A persistent failure on a steady path (DNS, a captive portal, a 404) therefore makes one extra request, then waits for the 24-hour mark. There is no floor, backoff or timer. A cycle that ends some other way (a bad signature, a veto) waits for the next check, which is R5's and R6's "later check". A download lost mid-way is `.requestFailed` too, so it retries when the connection returns (R5).

`NWPathMonitor` is the push. `SCNetworkReachability` is deprecated since macOS 14.4, and its header names `NWPathMonitor` as the replacement. The ban on `import Network` becomes a confinement, on purpose: a path monitor makes no request, and `NWConnection` stays banned.

#### 8. R2 and R12

The gate is decided in `UpdatableCopy.init?`, read once in `applicationWillFinishLaunching`, and enforced by absence: `Updater?` is nil, so `SparkleEngine` is never built. `developerIDSigner()` takes no arguments, so `--as-release-build` cannot fake it. `Updater.start` runs only from `othersExited`, so a `.end` or `.askToMove` route never reaches it, and a move's new process runs the gate itself.

`canReplace` runs before any request. It mirrors A11 read-only (`stat` and group membership), so a standard account, or an admin looking at another admin's copy, stays silent, including the group-writable case Sparkle's third test exists for. If it ever says yes wrongly, A10 still guarantees no prompt, at the cost of a silent download at each check.

#### 9. R3

| Property | How it holds | Evidence |
|---|---|---|
| User-Agent | `userAgentString = "TrackpadLauncher"` | E1 |
| Language, encoding | `httpHeaders` sets `Accept-Language: en`, `Accept-Encoding: gzip`; applies to feed and download, survives a 302 | E1 |
| Cookies | `cookieAcceptPolicy = .never` before the first request; no URL the app forms sets one anyway | E2, E3, E4 |
| Query string, profile | Profiling off by default; `neverDeclared` keeps it off; the feed and enclosure addresses have none | E6 |
| Validators | The feed is `reloadIgnoringLocalCacheData`; none sent with `ETag` and `max-age` on offer; `URLCache` at zero stores nothing | `textplain.out` |
| Redirects | The feed has none. The download's same headers go on every hop | E1, E5 |

**Feed address:** `https://raw.githubusercontent.com/domasgru/trackpad-launcher/main/appcast.xml`, in `project.yml` as `SUFeedURL`. It is a permanent contract with every automatic copy, like the `.aar` name. **A check is one request with no query string and no cookie, as R3's scenario says.**

**A limit to name.** The last hop of a *download* follows GitHub's redirect to `release-assets.githubusercontent.com`, whose URL carries GitHub's own signed, expiring query string. GitHub forms it and it names nothing of the user's, the Mac's or the versions, so R3's purpose holds, but a network monitor will show a `?` on that one request. CFNetwork's own transport fields sit outside what this design sets, as plan 022 recorded.

#### 10. The feed and the release

**Where.** `appcast.xml` is a committed file at the repository root on `main`, starting as an empty channel with `</channel>` on its own line. Each release adds one single-line item and keeps every older one, so R4's "needs a newer macOS" finds them (F2). The file is rendered by the script, not by `generate_appcast` (F5), and only the script writes it, so a pre-release can never appear (R4). `gh release create` still publishes the app and its assets as one step (immutable releases, F3); the feed names the asset only after it exists. Withdrawing a release is one commit removing its item, and a bad feed can be corrected the same way, which a feed inside an immutable release could not.

`why.md` Preserve 13 says a feed's failure must stop the release. R3's scenario overrides it in one narrow place: all the feed's content is rendered, signed and validated before anything is pushed, so only the final `git push` can fail after publishing. That leaves the release visible to cards and not yet to Sparkle copies, and `--feed-only` finishes it.

**Key.** `generate_keys` keeps it in the login keychain; `SUPublicEDKey` is in `project.yml`; the private half is never in the repo; preflight proves the two match before anything changes. Backup with `generate_keys -x` is a human step, because a lost key cannot rotate (F6), and the pin closes the disk-image door on purpose. Until the key exists, `start()` fails silently and preflight refuses, so nothing half-configured can ship.

**Build numbers.** Sparkle compares `CFBundleVersion` (F1), so a hand-raised marketing version with an old build number would be invisible. The script refuses a build number not above every item in the feed and the previous tag's.

```bash
FEED="$ROOT/appcast.xml"
SPARKLE_BIN="$ROOT/LauncherKit/.build/artifacts/sparkle/Sparkle/bin"

# In preflight_checkout: every credential is checked before anything changes.
(cd "$ROOT/LauncherKit" && swift package --disable-keychain resolve) || fail "cannot resolve the package."
[ -x "$SPARKLE_BIN/sign_update" ] || fail "Sparkle's tools are missing from the resolved package."
[ "$("$SPARKLE_BIN/generate_keys" -p)" = "$(sed -n 's/^ *SUPublicEDKey: *//p' "$ROOT/project.yml")" ] ||
  fail "the keychain's update key is not the one project.yml ships; import the backup with generate_keys -f."
xmllint --noout "$FEED" || fail "appcast.xml is not well-formed."

# Before preflight_version. A failed publish can leave a draft nothing sees, and it would block this retry.
[ "$(gh release view "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --json isDraft --jq .isDraft 2>/dev/null)" != true ] ||
  gh release delete "v$(read_setting MARKETING_VERSION)" --repo "$REPOSITORY" --yes

# In preflight_version: the feed's highest and the previous tag's, so an empty feed cannot bypass the check.
preflight_build_number() {
  local build highest tag tagged
  build="$(read_setting CURRENT_PROJECT_VERSION)"
  highest="$(sed -n 's:.*<sparkle\:version>\([0-9]*\)</sparkle\:version>.*:\1:p' "$FEED" | sort -n | tail -1)"
  [ "$build" -gt "${highest:-0}" ] || fail "build $build is not above the feed's $highest; Sparkle would never offer it."
  tag="$(git -C "$ROOT" tag --list 'v*' | sort -V | tail -1)"
  tagged="$(git -C "$ROOT" show "$tag:Config/Version.xcconfig" | sed -n 's/^CURRENT_PROJECT_VERSION *= *//p')"
  [ "$build" -gt "${tagged:-0}" ] || fail "build $build is not above $tag's $tagged."
}

# In archive_and_check, strict mode: Sparkle's atomic swap needs Autoupdate and the update on one team (C4).
codesign -dv "$copy/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1 |
  grep -qx "TeamIdentifier=$TEAM_ID" || fail "Sparkle's installer is not signed by team $TEAM_ID."

# After archive_and_check strict: the stapled archive, against every shipped card's own rules (R16).
swift run --package-path "$ROOT/LauncherKit" --disable-keychain card-contract \
  "$AAR" --team "$TEAM_ID" --identifier "$BUNDLE_ID" || fail "an older copy's card would refuse this release."

# After the disk image is notarised: renders into $OUT, so a failure leaves the tree clean.
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
  # A version already in the feed is replaced, so --feed-only can run twice.
  awk -v item="$item" -v version="<title>$EXPECTED_VERSION</title>" \
    'index($0, version) { next } /<\/channel>/ { print item } { print }' "$FEED" > "$OUT/appcast.xml"
  xmllint --noout "$OUT/appcast.xml" || fail "the feed is not well-formed."
}

# Publishing: the asset exists before the feed names it.
gh release create "v$EXPECTED_VERSION" "$DMG" "$AAR" --repo "$REPOSITORY" --latest ...
publish_feed() {
  cp "$OUT/appcast.xml" "$FEED"
  git -C "$ROOT" add "$FEED" && git -C "$ROOT" commit --quiet -m "Feed $EXPECTED_VERSION" -- "$FEED" &&
    git -C "$ROOT" push --quiet origin HEAD:main ||
    fail "v$EXPECTED_VERSION is published but the feed is not; run release.sh --feed-only $EXPECTED_VERSION."
}
# --feed-only <version>: downloads the published .aar, unpacks it so $APP names the sealed plist, write_feed, publish_feed.
```

| Step, in order | Failure leaves |
|---|---|
| Preflight, now with the update key, Sparkle's tools and the feed | Nothing changed |
| Tests, bump, `preflight_version` with the build-number check | Version commit undone |
| Archive, export, notarise, staple, `stapler validate` (R7) | Undone. No `.aar` exists yet, so no feed item can exist. |
| `archive_and_check strict`, with `Autoupdate`'s team | Undone |
| `card-contract` on the stapled `.aar` (R16) | Undone |
| Image, sign, notarise, staple, Gatekeeper | Undone |
| `write_feed`, into `$OUT` | Undone; the tree is clean |
| Push the version commit | Nothing published; undone |
| `gh release create` | Main holds the version, nothing visible; run with no argument. A leftover draft is removed first. |
| `publish_feed` | Release public, feed not: cards see it, Sparkle copies do not yet. `--feed-only` finishes it. |

Publishing a broken or unnotarised update takes defeating `set -e`: the feed is built only from a stapled, card-checked archive, and it names only an asset that already exists.

#### 11. R16

The `.aar` stays the one archive, read by both the card and Sparkle (A6). Asset name, inner `TrackpadLauncher.app`, stapled ticket, identity and tag path are unchanged. The first automatic version carries `SUVerifyUpdateBeforeExtraction`, so one file serves both, and the first version arrives through the old card as an opening by hand with a window, because old code passes no argument.

The rules outlive the card through `CardContract`. Its code is the shipped code moved, not rewritten: `admits`, `extract`, `MemoryStream`, the asset-name parse, `Version`, and a copy of `isGenuine` with the card's own requirement. It is frozen, with its tests moved beside it, and imports neither `LauncherCore` nor `LauncherPlatform`, so a change to the running app cannot weaken it. It sits under `LauncherKit/Sources`, so the scan binds it too: the tool reports through standard error and its exit code, never `print(`. `release.sh` runs it on every release, before anything is pushed. On `--archive-only`, which runs lenient on an unnotarised app, it reports its verdict and does not fail, as the stapler check does there. It also closes F8's gap: the Developer ID, identifier and `notarized` requirement over nested Sparkle code runs on the real stapled archive before the first automatic release is public.

#### 12. Build

- `.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")`, a dependency of `LauncherPlatform` (G1). `project.yml` gains only Info.plist keys; the app embeds it automatically. `CardContract`, `card-contract` and `CardContractTests` join `Package.swift`; `project.yml` does not link them.
- `LauncherKit/Package.resolved` is committed (G4), so `release.sh`'s clean-tree check holds.
- `xcodebuild -exportArchive` re-signs every nested helper with the Developer ID and the hardened runtime (G2). No `--deep`, no entitlements. Debug and perf builds keep ad hoc helpers and never start the updater.
- **The keychain stall (G3).** `Scripts/test.sh` runs `swift test --disable-keychain`; every `xcodebuild` (`Makefile`, `release.sh`, `Scripts/perf/build.sh`) passes `-packageAuthorizationProvider netrc`. Implementation proves the cold path once with a scratch `--cache-path`. If that still blocks, the fallback is a vendored `.binaryTarget(path:)` plus the tools; the interface above does not change.
- Sparkle links at load with WebKit in every build (G5). No weak-linking: `docs/performance.md` gets a re-measured baseline.

#### 13. Deletions and the rules

**Goes.** `GitHubReleases`, `ApplicationsUpdater`, `UpdateCardView`, `Release`, `UpdateEvent`, `UpdateCard`, `InstalledRelease`, `ThisCopy.version` and `macOS`, `Copy.update*`, `Fit.card`, `SettingsShell.updater`, `SettingsView`'s card and Quit disable, `BundleInstall`'s unpacking (moved). Tests: `UpdateCheckTests`, `UpdateInstallTests`, `ApplicationsUpdaterTests`, `GitHubReleasesTests`, `InstalledReleaseTests`, `LocalReleaseServer`; `VersionTests`, `BundleInstallTests` and `CraftedArchive` move to `CardContract`.

**The move keeps** the `Installer` port, `ApplicationsInstaller`, `PrivilegedInstall`, `Administrator`, `BundleInstall`'s `quarantine`, `newFolder`, `stage`, `swap`, `discard`, `removeOriginal`, `clearQuarantine`, `Placement`, `MoveDialog`, `Copy.cannotWriteToApplications`. `UpdateFixtures` and `make-update-fixtures.sh` stay for `isGenuine`'s tests.

| Standing rule | Where | Change, on purpose | Reason |
|---|---|---|---|
| "Three `@Observable` models"; `Updater` owns the card; `Launcher` reports the window to it; new version arrives by hand | `architecture.md:11`, `domain-model` | Rewritten to this shape | R1, R9, R15 |
| Module list: URL Loading and AppleArchive in `LauncherPlatform` | `architecture.md:12` | Sparkle, Network's path monitor and ServiceManagement's job submission arrive; URL Loading and AppleArchive leave; `CardContract` named as never shipping | Design |
| Off-main rule for work that would delay a click | `architecture.md:19` | Adds the one exception: the update's signature check, 18 to 31 ms, once per release | R6 |
| Sudden-termination rule | `architecture.md:11`, `SourcePolicyTests` | Kept; reworded to name the move, since no update opens a child now | The old copy's own declaration still matters for the first update (B5, B11) |
| "No timers, no polling" | `architecture.md:20` | Amended, text in section 3 | R1, R8 |
| "No network code except…" | `architecture.md:27` | One kind, Sparkle's, in the plan's wording | Plan's privacy rule |
| "No files written other than" | `architecture.md:27-30` | Adds Sparkle's caches, the empty `HTTPStorages` jar and defaults keys (A13); drops the staged update | R8 keeps an update on disk |
| "No logging" | `architecture.md:27` | Binds our Swift. Sparkle's `SULog` writes to the local unified log with no off switch (D-5); the docs say so plainly. | D-5 |
| Distribution: assets and contract | `architecture.md:35-36` | Adds the feed, the update key, the build-number rule, nested helpers | R4, R6, R7 |
| "Nothing relaunches the app" | `SourcePolicyTests` | Tokens stay; rule reads "after a crash or a force quit; the hand-over job opens it once after an update". The glossary keeps its sentence and gains that clause. | D-1, C1 |
| Update check, Newer version, Update card, Quit's *Installing…* text, "by an update opening the new version" | `domain-model.md` | Per the plan; adds *Automatic update*, *Hand-over* | R13, R15 |
| "The user decides when", "never in the background" | `README.md:17-18, 34, 69-72`, `product-overview.md:8`, `release.sh` header | Recorded as reversed | R1, R8 |

| `SourcePolicyTests` row | Change |
|---|---|
| `Timer`, `makeTimerSource` | Banned → confined to `SystemIdleClock.swift` (`DispatchSourceTimer` holds the token). `asyncAfter`, `Task.sleep`, display links stay banned. |
| `import Network` | Banned → confined to `SystemConnection.swift`, with new `NWPathMonitor`. `NWConnection` stays banned. |
| `theNetworkBansAreAllStillListed` | `Timer` and `import Network` leave `required`; a twin check requires them in `confined`, so neither can drop out of the scan. |
| `URLSession` | Confined to a deleted file → banned: our Swift makes no request |
| `http` | Confined to `SparkleEngine.swift`, for `httpHeaders`; no address in Swift |
| `downloadTask`, `.download(` | Stay banned, rule reworded: our Swift downloads nothing |
| `AppleArchive`, `ArchiveStream`, `ArchiveByteStream` | Confined to `CardContract.swift` |
| `SecCode`, `SecStaticCode`, `SecRequirement`, `Data(contentsOf:`, `removeItem(`, `itemReplacementDirectory` | Add `CardContract.swift`: the tool reads the archive it is given and unpacks it to a scratch folder |
| `createsNewApplicationInstance` | Removed; the code is gone |
| New confinements | `import Sparkle`, `HTTPCookieStorage`, `URLCache`, `org.sparkle-project`, `sparkle-updater` to `SparkleEngine.swift`; `SMJob` to `LaunchdJob.swift`; `/bin/sh` to `LaunchdJob.swift`, `PrivilegedInstall.swift` |
| `neverDeclared` | Adds `SUEnableSystemProfiling`, `SUEnableInstallerLauncherService`, `SUEnableDownloaderService` |
| New `alwaysDeclared` over `project.yml` | `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUVerifyUpdateBeforeExtraction`, `TLUpdateDownloads`: the automatic path's keys cannot be lost silently. `SUFeedURL` and `TLUpdateDownloads` must start `https://`, and `TLUpdateDownloads` must end `/`, so a sibling such as `…/download-x/` is not under it. |
| New test, in `LauncherPlatformTests`, which can see `SparkleInternals` | `provenOn` equals `Package.resolved`'s Sparkle version |

`Process()`, `posix_spawn` and the rest of "no child processes" are untouched: the job is launchd's, not a child. Under `why.md`'s Hypothesis B the rule's spirit does bend, so the `/bin/sh` row says so.

**`why.md` bindings.** Preserve 1 to 14 hold, with two narrowings: 13 by R3's scenario (section 10), 14 by D-5. Avoid 2 is narrowed: one argument, `--after-update`, passes between versions and binds every future version, which is named under Tradeoffs. Avoid 3 holds through the new `Route` row. Avoid 4 and 5 are overridden for the hand-over only, on C1 to C3 and R11. Avoid 6 holds: nothing ends before the verdict. Avoid 1 and 11 hold through `update-e2e.sh`, which proves Sparkle's behaviour on the wire and on screen rather than from the scan or its options. Avoid 7 is moot, since the opener starts after the old process has gone. Avoid 9 and 10 hold: the gate is no `#if DEBUG`, and the feed is no second `.aar`.

#### 14. Testing seam

**The seam** is `LifecycleWorld`: real `Lifecycle`, `Launcher` and `Updater`, with every scenario in plain Swift Testing and no waiting.

| Cannot be waited for or provoked | Handle |
|---|---|
| The clock | `InMemoryIdleClock`: `pending`, `pass()` |
| Contact | `InMemoryTrackpads` touches; `isTouched`, `sensesContact` |
| Window | `Launcher` intents |
| Connectivity | `InMemoryConnection.set(_:)`, `isWatching` |
| Sparkle's callbacks | `InMemoryUpdateEngine.push(.held(.notGenuine))`, `.cycleEnded(.requestFailed)`, `starts`, `checks`, `discards` |
| A job that fails | `armWorks` flag |
| The process ending, and what follows | `copies.hasEnded`, `EffectLog` order, `world.finishHandOver()` starting the next process |
| Death at any effect | `snapshots` around "arm restart", as "kill at any effect" works today |

| Level | What runs there |
|---|---|
| `swift test`, world | R1 retry, spent reading, no hot loop; R2 and R12 gate; a `.end` or `.askToMove` route never starts the engine; R8's scenarios; R9 silent route, login item untouched; R11's no check at an after-update start; R13 and R14 tables; R15 |
| `swift test`, Platform | `DeviceSession.receive` by direct call (palm, hover, `run` reset, sensing off makes no hop); `SparkleInternals` on temp folders (stale folder, two bundles, none); `outcome(of:)`; `isPinned`; `isGenuine` against the real fixture, whose other identity is R6's mismatch; the hand-over script run for real under `/bin/sh` with a stub `open`, a held pid and `allowed` of 5 s, asserting the wall-time bound, which catches C2's bug (a budget of 1 s would not: a loop that counts rounds also lands inside its window); `CardContract`'s moved tests |
| `Scripts/update-e2e.sh`, built app | Two real builds from a patched spec (bundle identifier `.e2e`, local `SUFeedURL` and `TLUpdateDownloads`, `NSAllowsLocalNetworking`), Developer ID signed and notarised, because the gate cannot be faked. In /Applications, nested one folder deep for the failure case. The local server mirrors GitHub's paths, redirects, cookies and validators. R1 login start, R3 on the wire, R5, R6 (tampered signature; signed by another identity), R7's client side, R9 with focus and timing, R11 by a read-only parent, R13, A10. It is the spike's scenarios ported to the real app. |
| By hand | Real logout, restart, shutdown (D-3); TCC and login item (L2); offline start; sleep past the mark, with `defaults write SULastCheckTime`; a real 1.0.15 pressing *Update now* (R16) |

Fakes hid plans 035's and 038's bugs, so the world tests prove decisions and the E2E proves the hand-over. Neither stands in for the other.

### Synthesis decision

**Base: candidate 1** (Opus). I scored it first on every rubric criterion, and the cross-judge agreed, 26 to 17, on the same criteria and for the same reasons: its model is smaller (`Updater` shows three things, Core holds no version, `Launcher` learns only "in use"), it stays on Sparkle's documented selection, its private coupling is enforced by a test, and its failure table is complete. Candidate 2 reached the same core on its own (automatic path, held, one-shot job, `--after-update`, `Updater` in Core, one file for private facts). That convergence is a strong signal for those decisions.

**Grafted from candidate 2, by hand:**

- **The feed as a committed file on `raw.githubusercontent.com`,** with `--feed-only`. *Here I overruled the cross-judge,* which kept the release asset for Preserve 13 and R4's withdrawal. R3's scenario says a check has "no query string", and the task says a Preserve yields to a requirement. The release asset's last hop carries one, and its first offers cookies. A feed in an immutable release also cannot be corrected, and a raw feed needs one request instead of three. Sparkle parsed a `text/plain` feed with `ETag` and `max-age` on offer and sent no validators (`textplain.out`). Withdrawal stays one commit.
- **One argument, `--after-update`, and no check at that start.** Candidate 1 split success from failure with a second argument, to check after a success. One argument means one branch less in the job and one case less in `Opening`; the 24-hour mark covers the rest.
- **`alwaysDeclared` and the wider `neverDeclared`,** which the judge called candidate 2's best idea.
- **`URLCache.shared` at zero.** *The judge said not to port it,* because the feed already ignores the cache. That is right about validators and misses that it removes `Cache.db` from disk (`textplain.out`), one persistent file fewer in a rule that lists every file.
- **The previous-tag build check,** so an empty feed cannot bypass the rule, and **candidate 2's wider doc list.**
- **Waiting on the old pid without a bound.** Candidate 1 abandoned the job after 10 s, so an old process that ended late installed and nothing reopened it (from the judge's list).

**Changed from both:**

- Failure classification rests on the public `SUDownloadError`, not on walking nested errors or marking an offer. Every URLSession failure reaches that level wrapped (`SPUDownloadDriver.m`, `noserver.out`), which closes L3 and retires a private coupling.
- `isPinned` reads a new Info.plist key, so no address exists in Swift and a local server can stand in for GitHub.
- `discardHeldUpdate` returns nothing, because `Updater` could not act on the answer.

**Kept from candidate 1 against candidate 2:** the synchronous check, now measured at 18 to 31 ms (`genuine.out`) and sparing an interleaving window; `NWPathMonitor`, which reports the present reading at once (`path.out`) and is not deprecated (the SDK header confirms `SCNetworkReachability` is); `canReplace` mirroring all of A11; Sparkle's own selection; `CardContract` over shell approximations of the card's rules.

**Rejected from candidate 2:** `FeedPolicy` and `bestValidUpdate`, which reimplement what Sparkle's header asks integrators not to; always-on contact edges, a main-actor hop on every touch for minutes of use per release; `.untilQuit`, since staying `.ready` retries on the next idle edge; its `Timer` and `http` scan rows, which would fail on arrival.

**From the test planner's review of this design:** `retrySpent` is set as the retry is made, because a drop during a retry used to lose the return; `check()` remembers a check refused in Sparkle's end-of-cycle window, which `pendingcheck.out` hit on the first try; `isPinned` no longer demands `https`, which the scan now holds, so a local server can stand in; `DeviceSession` takes its sensing flag as it takes its clock, and `veto(job:extracted:)` takes what it acts on, so tests can drive them; the job's budget is at least its stated 5 s; `card-contract` reports without failing on `--archive-only`; and the in-call veto was probed (`vetonow.out`).

**Red-flag screen.** No shallow modules survive: `Launcher.watchUse` is the thinnest surface, and it hides the sensing switch, the reset rule and the merge across pads. No information leakage: Sparkle's private facts have one home, and `ExpectedUpdate` stays in Platform. No temporal decomposition: `Updater` owns check, hold and hand-over as one body of knowledge. No pass-through: `UpdateEngine.check` adds the `sessionInProgress` guard, and `armRestart` hides the job.

### Tradeoffs accepted

- We accept a shell script polling for at most a few seconds, once per update, in exchange for R11, which nothing else can meet (C1), and for a helper that needs no signing and survives the swap.
- We accept `SMJobSubmit`, deprecated since 10.10, in exchange for the only non-permanent job API. Sparkle shares its fate, so its removal is one problem, not two.
- We accept private coupling to a cache layout and a job label in exchange for staying on the automatic path, the only path with A10's no-prompt guarantee, with an upgrade that fails a test until re-proven.
- We accept a synchronous signature check on main, 18 to 31 ms once per release, in exchange for no phase in which an unchecked update waits. It looks like a slip against the concurrency rule and is not one.
- We accept a moment where a process end installs an EdDSA-valid update without our check, because Sparkle offers no earlier hook. Exploiting it takes the private key.
- We accept that the idle minute starts no earlier than the moment an update is held, even if the pad was idle before, in exchange for no contact work in normal use.
- We accept that a persistent install failure retries once per 24 hours, not sooner, and that a successful update does not check again until the 24-hour mark.
- We accept that `--after-update` binds every future version, as the `.aar` name does, in exchange for a signal with nothing persisted. A future version that dropped it would open a window once, harmlessly.
- We accept a second publish effect after `gh release create`, with its own retry, in exchange for a check that is one request with no query string and a feed that can be corrected.
- We accept that a path reading "connected" while nothing answers spends its one retry, leaving the 24-hour mark, in exchange for no timer and no backoff.
- We accept that a new version which crashes at start leaves nothing running until the next login or opening; no older copy exists, and rollback is a non-goal.
- We accept a feed that grows about half a kilobyte per release, in exchange for not pruning XML in shell.
- We accept Sparkle and WebKit loading in every build, measured, not avoided (G5).
- We accept a frozen duplicate of `isGenuine` in `CardContract`. It looks like a DRY violation and is the point: the card's rules must not move when the app's do.

### Alternatives considered

- **Sparkle's immediate handler, with a marker for the relaunch.** The documented "take control" path, and it hides the most from us. It exposes the window race (a quit refused after the handler leaves relaunch armed), needs a stale-prone persisted marker because the relaunch carries no argument, and still recovers nothing from a failed swap, so it adds a watcher to a second restart path. It lost on R13 and R11.
- **The UI-based driver with `.skip` as a public veto.** Removes the private label. It leaves the documented silent path, allows a password prompt to be reached, and `.install` can show a progress window after 0.7 s. It lost on R9, R12 and R15.
- **Delete `Updater`; a thin wrapper in the app target, with decisions in `Lifecycle` and `Launcher`.** Fewest types. It scatters R8, R1 and R6 across two models and an untested target, and exposes all of that to callers.
- **The feed as a release asset, published by `gh release create`.** Hides the second publish step, atomically. It exposes every check to GitHub's redirect chain, with a signed query string on the last hop and cookies offered on the first, against R3's scenario, and a bad feed cannot be corrected under immutable releases.
- **R8's minute on `LaunchClock`, keeping the rule's text.** No rule change. It reports a system stop as passed, which can install early, and runs unmeasured in the exact state R8 fires in.
- **Contact as an always-on `TrackpadEvent`, with a model that tracks occupied pads.** A simpler port. It costs a main-actor hop on every touch for a feature active minutes per release, a set that can stick across `run`, and a `Launcher` that keeps its `updater` reference.
- **A watcher helper embedded in the bundle instead of `/bin/sh`.** A compiled tool could wait on a kernel exit source instead of polling. It is nested code the swap replaces under itself, with its own signing and notarisation, to save a few seconds of polling once per update.

### Open questions and risks

Only the human or a real Mac can settle these.

- **Does a real logout read as `.system` with the window open (D-3)?** If not, the shipped app cancels logouts today, and R14 fails with it. Can this be run before the first automatic release?
- **Do Accessibility, Screen Recording and the login item survive a Developer ID, notarised swap (L2)?** Same path, identifier and team say yes; no one has measured it, and a loss would be invisible under R15.
- **Who creates the update key, and where does the exported private half live?** `generate_keys` writes to the human's login keychain, so the first run is theirs. It needs a place outside this Mac before the first automatic release. Losing it means every copy needs one manual install.
- **Does the Developer ID, notarised form of the hand-over match the Apple Development form (L7), for well past B11's 126 s?** `update-e2e.sh` answers on this Mac, but it needs a live login session.
- **Does a Mac asleep past the mark fire on wake (A9), and does App Nap delay the idle minute on a windowless process (L5)?** A late minute is harmless; a timer that never fires is not, and it would leave the update for the next end of the process.
- **Do `Updater.app` and `Autoupdate`, idle while an update waits, delay a logout or cost idle CPU?** Sparkle's long use says no; it counts under R14 and the idle promise.
- **Is Sparkle's local `os_log` acceptable under "no logging" (D-5)?** The design says yes and states it in the docs. It names the update address and paths, on this Mac only.
- **What is the memory cost of loading Sparkle and WebKit (G5)?** If it breaks `product-overview.md`'s promise, is the cost accepted?
- **First automatic release:** R16's one press needs a real 1.0.15 copy after publishing, and no release can be recalled. `card-contract` covers the rules; only the real press covers the rest.

This branch is two commits behind `origin/main`, whose settings redesign (#45) moves the card's lines. Rebase before touching `LauncherUI`.

### Next implementation step

Rebase onto `origin/main`, add Sparkle to `Package.swift` with `Package.resolved`, put `--disable-keychain` and `-packageAuthorizationProvider netrc` on every build path in that same change, and prove the cold build once.

## Testing Decisions

### Strategy

**The one seam for every decision is `LifecycleWorld`:** real `Lifecycle`, `Launcher`, `Updater` and `UpdatableCopy` over in-memory ports, with no waiting. It sees what each process did, `EffectLog`'s order and a process's whole history. It cannot see Sparkle, launchd, the frame thread or AppKit's terminate. The models are `LauncherKit/Tests/LauncherCoreTests/UpdateInstallTests.swift`, `LifecycleTests.swift` and `StartAtLoginTests.swift`.

Three more seams cover what the world fakes, each as high as a real run allows (grounding K):

- **Platform adapters by direct call, in `swift test`.** `DeviceSession.receive`, `SparkleInternals`, `outcome(of:)`, `isPinned`, `isGenuine`, `ThisCopy`, and the real `SystemIdleClock`, `SystemConnection`, launchd and `/bin/sh`. They miss Sparkle running in a signed bundle. The models are `LauncherKit/Tests/LauncherPlatformTests/DeviceSessionAnswerTests.swift`, `CodeSignatureTests.swift`, `PrivilegedInstallTests.swift` (a real script, unprivileged) and `SystemRunningCopiesStopTests.swift` (real processes under a test's own identifier).
- **A release harness, new, in `swift test`.** The real `Scripts/release.sh` in a throwaway clone with a local bare `origin`. `gh`, `xcrun`, `xcodebuild`, `xcodegen`, `codesign`, `spctl`, `security`, `hdiutil`, `osascript` and `swift` are stubs on `PATH` that log to one ordered file and fail on request. `git`, `awk`, `sed`, `xmllint`, `aa`, `ditto` and `PlistBuddy` are real, and so is `sign_update`, behind a wrapper that passes a throwaway `--ed-key-file`. It exists because `write_feed`, `preflight_build_number`, `--feed-only` and the failure table hold logic no other seam reaches. It misses what Apple and GitHub really answer.
- **`Scripts/update-e2e.sh`, on two real builds, run by a person** with the Developer ID, the notary profile and `sudo`, as design section 14 lays out. Its feed is rendered by `release.sh --feed-only` in the harness's clone with only the address replaced, so Sparkle reads what a release publishes. Its key is a throwaway, so it does not wait for the human's `generate_keys`. A sampler records, every 100 ms, every process's on-screen windows, the frontmost app, the app's activation type, and /Applications' `CFBundleVersion` and executable. This Mac's frontmost app flips between other apps on its own, as `hold.out` shows with nothing happening, so a row asserts only that the app and Sparkle's helpers never become frontmost. The app logs nothing, so the server's request log, that sampler, `launchctl` and the disk are the record. A person's finger stands in for what nothing can synthesise: the script prompts, the person taps the 1-finger gesture, and the script times the assigned app reaching the front.

`SourcePolicyTests.swift` and `CardContract`'s moved tests stay as the existing scan and contract seams.

**What is faked:** Sparkle (`InMemoryUpdateEngine`), the idle clock (`InMemoryIdleClock`), connectivity (`InMemoryConnection`), the trackpads and the frame thread's hop (`InMemoryTrackpads`), the tools above, GitHub (the local server, which mirrors its paths, redirects, cookies and validators) and `open` (a stub that records its arguments and the time). Everything we own runs for real.

**Handles the rows use beyond section 14's table, in test adapters only:**

- `InMemoryIdleClock.advance(by:)` and `waits`, so a row proves 59 s and 60 s rather than only `pass()`.
- `InMemoryTrackpads.press()`, `lift()`, `holdContactEdges()`, `releaseContactEdges()` and `onSensesContactSet`. `run` clears contact and drops held edges, as the generation guard does.
- `InMemoryConnection.reading`, `watches`.
- `RunningBuild.release(canWrite:)` and `world.finishHandOver(installed:)`.
- `EffectLog` entries "engine start", "check", "discard" and "arm restart".

**Sparkle's 24-hour timer cannot be owned.** `update-e2e.sh` shifts `SULastCheckTime` and starts with `--after-update`, which makes no check of its own, so only Sparkle's timer can produce the request.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2, R12 | `LifecycleWorld` | Given every combination of `Placement`, Developer ID signed and can write, each at login and by hand. When the process starts. Then only installed, signed and writable builds an `Updater`, with `engine.starts == 1`. Every other has `process.updater == nil`, and its whole history holds no engine call, no connection watch and no clock wait. | R2's and R12's rules, written out as a literal table |
| T2 | R1 | `LifecycleWorld` | Given a gated copy. When it starts at login, and on another Mac by hand. Then `EffectLog` holds "engine start", "check" inside the launch turn. At login `windows == [.closed]`. Opening and closing the window three times adds no check. | R1: "when it starts, at login or by hand"; "MUST NOT depend on the settings window" |
| T3 | R2 | `LifecycleWorld` | Given a release copy at login with an older copy running. Then it ends with `engine.starts == 0`. Given one opened by hand while another copy is stopping. Then `starts == 0` until `letExit`, then 1. | Design section 8: a `.end` route never reaches `start`, and a copy still replacing others has no resident |
| T4 | R1, R2 | `LifecycleWorld` | Given a release copy `.elsewhere`, opened by hand. Then `updater == nil` with the dialog up. When `.move` and `.installed` arrive. Then that process made no engine call and the installed copy it opens has `checks == 1`. | R2 scenario "Moved to /Applications" |
| T5 | R12 | `LifecycleWorld` | Given a Mac whose copy cannot write. When it starts. Then no engine, `permissions.asks` and `installer.installCalls` are empty, and `tap(1)` brings Arc to the front. When the next start can write. Then `checks == 1`. | R12: no prompt; "checks again at its next start" |
| T6 | R6 | `LifecycleWorld` | Given a resident. When `push(.held(.notGenuine))`. Then `discards == 1` before any other effect, `sensesContact` stays false, no wait is pending, the window is unchanged and `advance(1 h)` arms nothing. `.cycleEnded(.failed)` then changes nothing. A later `.held(.genuine)` starts the minute. A `quit()` right after the verdict logs "discard" before "end", and no "arm restart". | R6 scenarios: nothing installs, nothing shows, a later check tries again |
| T7 | R8 | `LifecycleWorld` | Given `.held(.genuine)`. When a finger touches and lifts three times, 59 s apart. Then nothing is armed at any step. After the last lift, `advance(59 s)` does nothing and `advance(1 s)` leaves `["arm restart", "end"]`, each once in the log's whole history. | R8 scenario "User is working on the trackpad"; 1 minute literal |
| T8 | R8 | `LifecycleWorld` | Given a held update and the window open. When `advance(10 min)`. Then `pending == nil` and nothing is armed. In turn: the window closes last; a finger lifts 30 s after the window closed; the window reopens during the minute and closes again. Each time 59 s after the later event does nothing and 60 s hands over. A re-front of an open window restarts nothing. | R8 scenario "Settings window is open": "the later of the last touch and the window closing" |
| T9 | R8 | `LifecycleWorld` | Given no update held and `advance(1 h)`. Then `waits` is empty. When `.held(.genuine)` arrives on a Mac with `attached: []`, and on one with an untouched pad. Then `pending == .seconds(60)`, and 60 s later it hands over. | R8 scenario "Mac with no trackpad in use"; Tradeoffs: the minute starts at the hold |
| T10 | R8 | `LifecycleWorld` | Given 100 taps, window openings and failed cycles with no update held. Then over the whole history `sensesContact` is false and `waits` is empty. Then `sensesContact` is true exactly from `.held(.genuine)` until the phase ends. | Design's "Exists only in" table |
| T11 | R8 | `LifecycleWorld` | Given a finger down and `onSensesContactSet` lifting it the moment sensing turns on. When `.held(.genuine)` arrives. Then `pending == .seconds(60)`: the lift is neither lost nor stuck. | `watchUse`: "`onChange` now with the present reading, then at each change" |
| T12 | R8 | `LifecycleWorld` | Given a held update, the minute running and `holdContactEdges()`. When a finger lands, so `isTouched` is true with its edge still queued, and `advance(60 s)` fires the wait. Then nothing is armed. `releaseContactEdges()` leaves `pending == nil`. A lift and 60 s hand over. | Design section 3: at the fire `Updater` re-reads the level, so a queued edge cannot lose a touch |
| T13 | R8 | `LifecycleWorld` | Given a finger down and its lift edge held. When `wake()` replaces the sessions. Then `pending == .seconds(60)`, and the resting finger's next frame cancels it. Given the minute 30 s in. When `wake()`, or a preference or permission push that changes the run, arrives. Then 59 s later nothing happens and 60 s later it hands over. | H3's reset rule; design section 3: "the `run` at wake restarts the minute" |
| T14 | R8 | `LifecycleWorld` | Given the minute running. When `.cycleEnded(.failed)` arrives (a helper died). Then `pending == nil`, `sensesContact` is false and `advance(1 h)` arms nothing. A later `.held(.genuine)` starts the minute again. | C5; design phase table |
| T15 | R8 | `LifecycleWorld` | Given `armWorks = false`. When the minute passes. Then the process runs on, nothing is pending, `advance(1 h)` calls `armRestart` once and `tap(1)` works. A touch and lift, `armWorks = true` and 60 s hand over. | Hand-over table, step 2: "stay `.ready` ... try on the next idle edge ... No loop." |
| T16 | R8, R14 | `LifecycleWorld` | Given a held update and `shouldEnd(.system)`. When the next login runs the new version; and separately runs the old one, which holds the update again. Then the first has no update pending. The second hands over at 60 s. In both, `windows == [.closed]`, no asks, and `tap(1)` works. | R8 scenario "Shutting down with an update waiting" |
| T17 | R9, R10 | `LifecycleWorld` | Given Arc assigned, the login item on, a non-default thumb corner and *Hide background apps* on. When the minute passes. Then straight after `advance` returns, the log ends `["arm restart", "end"]`, `loginItem.calls` is empty and the suite is unchanged. `finishHandOver()` gives a copy with `windows == [.closed]`, no asks, `starts == 1`, `checks == 0`, the seeded settings, and `tap(1)` bringing Arc to the front. | R9, R10 literals; the seed |
| T18 | R9 | `LifecycleWorld` | Given the copy after a hand-over. When `openAgain(.byHand)`. Then `window == .open(request: 1)`. `Route` over every `.afterUpdate` × placement × older copy gives design's rows, and the `.atLogin` and `.byHand` rows are unchanged. | R9 scenario "Opening by hand afterwards"; design's `Route` table |
| T19 | R9 | `LifecycleWorld` | Given `launch(.afterUpdate, others: [.earlier])`. Then it does not end as a login start would: `stopped == [.earlier]` and no engine call until the exit. When `openAgain(.byHand)` lands during the stop. Then the window opens once resident and `checks == 0`. | R9 "MUST stop the old version"; design section 4's opening in the gap |
| T20 | R11 | `LifecycleWorld` | Given a hand-over. When `finishHandOver(installed: false)`. Then the same version runs with `windows == [.closed]`, `checks == 0` and nothing pending, and `advance(1 h)` logs nothing. A later `.held(.genuine)` gives exactly a second "arm restart". | `discardquit.out`: a check here loops once a minute for ever; R11 "a later check" |
| T21 | R8, R10, R11 | `LifecycleWorld` | Given snapshots before and after "arm restart". When each is restored and started at login and by hand. Then assignments, login item and permissions equal the seed, a login start stays silent, and a start by hand opens one window. | The seed; design: "Persisted state: none of ours" |
| T22 | R13 | `LifecycleWorld` | Given each of: a cycle running, a held update in use, the minute running. When `quit()`. Then the process has ended and the login item is off, and the log's whole history holds no "arm restart". `world.login() == nil`. A later `launch(.byHand)` opens the window and turns the login item back on. | R13 scenario; design section 5 table |
| T23 | R13, R14 | `LifecycleWorld` | Given each phase above. `shouldEnd(.other)` with the window open answers false and closes it, and with a held update the minute starts. With the window closed it answers true. `shouldEnd(.system)` answers true with the window open or closed and nothing armed. After a hand-over ended the process, both answer true. | Design section 5 table; R14 |
| T24 | R1 | `LifecycleWorld` | Given reading false and `.cycleEnded(.requestFailed)`. Then `isWatching`, `checks == 1`, and `set(false)` adds none. When `set(true)`. Then `checks == 2`. `.cycleEnded(.nothingNew)` leaves `isWatching` false. | R1 scenario "Network arrives after login" |
| T25 | R1 | `LifecycleWorld` | Given reading already true when the failure arrives, and no change ever pushed. Then the reading `watch` pushes gives `checks == 2`. | Design section 7: the race where the path came up before the watch armed |
| T26 | R1 | `LifecycleWorld` | Given `checks == 2` and the retry failed. When `set(true)` 1000 times, and Sparkle's own check fails at the mark. Then `checks == 2`. When `set(false)`, `set(true)`. Then `checks == 3`. | Design section 7: "A retry that fails again needs a real drop and return" |
| T27 | R1, R5 | `LifecycleWorld` | Given a retry in flight, `checks == 2`. When `set(false)`, then `.cycleEnded(.requestFailed)`, then `set(true)`. Then `checks == 3`. Separately, a drop and a return while that retry still runs give `checks == 3`, and its failure then earns no fourth. | R1: "once a connection is available, not at the next 24-hour mark"; design section 7: "a drop during the retry earns the next one" |
| T28 | R1, R5, R13 | `LifecycleWorld` | `.cycleEnded(.failed)` and `.nothingNew` start no watch. A retry that finds an update leaves `isWatching` false and R8's rules on. A download lost mid-way, which arrives as `.requestFailed`, watches like a failed check. While watching, `quit()` ends at once and `shouldEnd(.system)` is true. | Design section 7; R5 scenario "Connection lost" |
| T29 | R1, R5 | Platform, direct | `outcome(of:)`: nil and `SUSparkleErrorDomain` 1001 give `.nothingNew`; 2001 gives `.requestFailed`; 1000, 1002, 2000, 3001, 4005, 4007, 4008 and code 2001 in another domain give `.failed`. | `SUErrors.h` literals; `noserver.out` (2001), `veto.out` (4005) |
| T30 | R6 | Platform, direct | `isPinned` admits `https://github.com/domasgru/trackpad-launcher/releases/download/v1.2.3/TrackpadLauncher-1.2.3-macOS-26.0.aar` under that repository's prefix, and `http://127.0.0.1:8765/v2/TrackpadLauncher-2-macOS-26.0.aar` under a local `http` prefix. It refuses nil URL, nil prefix, another host, another repository, a lookalike sibling of the prefix, `.dmg`, `http` under an `https` prefix, `.dmg?.aar`, and `..` plain or percent-encoded. | The enclosure line of `write_feed`; `isPinned`'s contract; D3 |
| T31 | R12 | Platform, direct | `canReplace` on a temp bundle: true. Bundle mode 555, parent mode 555, and `/System/Applications/Calculator.app`: false. The parent's listing is the same before and after every call. | A11; design: "this creates nothing" |
| T32 | R6 | Platform, direct | `extractedUpdate` on temp caches in Sparkle's layout. No folder: nil. One bundle of that build: it. A stale older folder of the same build: the newest. Two bundles in the newest: nil. Another build: nil. | D2, D4; the layout printed in `selfquit.out` |
| T33 | R6, R7 | Platform, direct | `isGenuine` against `ExpectedUpdate`. The Developer ID fixture with its recorded values: true. Another team, identifier, version, build or minimum macOS: false. The Apple Development copy and an unsigned bundle: false. | `fixture.json`; build `1` in `make-update-fixtures.sh` |
| T34 | R6 | Platform, real launchd | `SparkleInternals.veto(job:extracted:)` with a dummy job under `installerJob(of:)`'s label and a bundle in temp caches removes both. With the job absent, the bundle still goes. With `extracted: nil`, the job still goes. | Design section 6: two independent layers, "Whatever the first did" |
| T35 | R8 | Platform, direct | With the session's own `sensesContact` answering true, `DeviceSession.receive` over empty, finger, two fingers, one lift, empty, palm-only, empty: `.contactChanged` on exactly the four flips, in frame order, and `isOccupied` matches at each step. A contact the recognizer ignores counts. Frames parsed from states 2 and 5 only are no contact. | H2; driver states in `TouchFrameParsingTests.swift` |
| T36 | R8 | Platform, direct | With `sensesContact` answering false, the same frames deliver no `.contactChanged`, `isOccupied` still tracks, and the injected clock is read as often as in a session with no contact code. Turned on with a finger down, it delivers nothing until the next flip. | H2; `docs/architecture.md`: no per-frame clock read |
| T37 | R8 | Platform, direct | With two sessions, `isTouched` is true when either is occupied and false when neither is. A replaced session's contact reads false. | Design: "Contact of any kind on any running trackpad"; H3 |
| T38 | R8 | Platform, real timer | `SystemIdleClock`: a wait fires once within its duration plus the 1 s leeway. A second `wait` replaces the first, which never fires. `cancel` stops it. With main held past the deadline, a `cancel` in that same turn still means it never fires. | Design: "a cancelled wait cannot fire"; "Replaces any pending wait" |
| T39 | R9, R11 | Platform, real launchd | Given a held `sleep` as the old pid and a temp bundle at build 1. When the real `handOverArguments` run through `LaunchdJob.submit`. Then the stub `open` is not called while the pid lives, even past `allowed`. With the pid gone and the plist rewritten to build 2 after 0.5 s, it is called once with `-g -a <bundle> --args --after-update`, within 1 s of the rewrite. No job stays listed. | B4's exact call; design's script |
| T40 | R11 | Platform, real launchd | `allowed: 5` with the build never changing: `open` runs once, 5 to 6.5 s after the pid's death. `allowed: 1` with `Info.plist` removed at the pid's death and back at build 2 after 0.5 s: `open` runs once, after the plist returns and within 1 s of it. | Section 4: "at least 5 s and at most 6 s", plus one poll; C2 took 7.4 s for an intended 5, a drift only a budget this long shows |
| T41 | R9 | Platform, real launchd | `submit` of a stale label replaces the job. `remove` of a live job ends it. `remove` of an absent one answers false. | Design's `LaunchdJob` contract |
| T42 | R9 | Platform, direct | `ThisCopy.launch` with `--after-update` gives `.afterUpdate`, also beside `--eject-disk-image`. With no argument or an unrelated one it gives the existing openings. `opening(of:)` of a reopen ignores arguments. | B6; existing `ThisCopyTests.swift` |
| T43 | R6, R12 | Platform, direct | `SparkleInternals.provenOn` equals the Sparkle version in `LauncherKit/Package.resolved`. | `Package.resolved` |
| T44 | R1, R3 | `SourcePolicyTests` | `import Sparkle`, `HTTPCookieStorage`, `URLCache`, `org.sparkle-project` and `sparkle-updater` are confined to `SparkleEngine.swift`, `http` too, `URLSession` is banned, the `neverDeclared` profiling and service keys are absent, and `alwaysDeclared` finds the six keys. `SUFeedURL` and `TLUpdateDownloads` start `https://`, and `TLUpdateDownloads` ends `/`. A planted hit, a planted missing key and a planted `http://` value each fail. | Design's `SourcePolicyTests` table; T30's lookalike refusal needs the final `/` |
| T45 | R8 | `SourcePolicyTests` | `DispatchSourceTimer` and `makeTimerSource` are confined to `SystemIdleClock.swift`; `Timer` moves from `required` to the twin check. `asyncAfter`, `Task.sleep` and display links stay banned. | Design's `SourcePolicyTests` table |
| T46 | R9, R11 | `SourcePolicyTests` | `SMJob` is confined to `LaunchdJob.swift`, `/bin/sh` to `LaunchdJob.swift` and `PrivilegedInstall.swift`. The "nothing relaunches" tokens stay. | Design's `SourcePolicyTests` table |
| T47 | R1 | `SourcePolicyTests` | `import Network` is confined to `SystemConnection.swift` with `NWPathMonitor`, and `NWConnection` stays banned. | Design's `SourcePolicyTests` table |
| T48 | R16 | `CardContract` tests | `VersionTests`, `BundleInstallTests` and `CraftedArchive` pass beside `CardContract` with their expected values unchanged. | The shipped tests, moved unedited |
| T49 | R16 | `CardContract` tool | `card-contract` on the fixture archive under a contract name, with the recorded team and identifier: exit 0. Another team, a refused entry, or a name off the contract: non-zero. Standard output stays empty. | `fixture.json`; the card's `admits` |
| T50 | R16 | `SourcePolicyTests` | `CardContract` imports neither `LauncherCore` nor `LauncherPlatform`, and the app target does not link it. | Design section 11: frozen |
| T51 | R7, R16 | Release harness | When the stubs fail in turn at `notarytool` on the app, `stapler validate`, the strict archive check, `card-contract`, `notarytool` on the image, `sign_update` and the version push. Then each time the exit is non-zero, `gh release create` is absent from the log, the bare origin has no new ref, `appcast.xml` is unchanged, the tree is clean and the version commit is undone. With `--archive-only`, a failing `card-contract` prints its verdict and the exit is 0. | Design's "Failure leaves" table; section 11 |
| T52 | R4 | Release harness | A build equal to the feed's highest is refused, and highest + 1 passes. With an empty feed, a build equal to the previous tag's is refused, and + 1 passes. | F1; design's `preflight_build_number` |
| T53 | R4, R16 | Release harness | Two releases from an empty channel leave `appcast.xml` equal to a hand-written expected file, apart from the signature and length: single-line items, the older one kept, build, short version, minimum macOS, tag path. `sign_update --verify` accepts the signature. `MARKETING_VERSION = 1.1.0-beta` is refused with the feed unchanged. `gh release create` carries the `.dmg` and exactly one `.aar` under the contract name. | The expected file; F2, F7 |
| T54 | R7 | Release harness | `gh release create` comes before the feed's push. A failed push exits naming `--feed-only`, with the release public and the feed old. `--feed-only <version>` run twice leaves one item for that version and a clean tree. A leftover draft is deleted before a retry. | Design's step table; F3 |
| T55 | R6, R11 | Release harness | Preflight refuses, with nothing changed, a keychain key that differs from `SUPublicEDKey`, an empty `SUPublicEDKey`, missing Sparkle tools and a malformed feed. The strict check refuses an `Autoupdate` signed by another team. | Design section 10; C4 |
| T56 | R16 | `update-e2e.sh` | `card-contract` on the real stapled `.e2e` archive, nested Sparkle code included, exits 0 with that build's identifier. | F8's gap |
| T57 | R1, R5 | `update-e2e.sh` | Given v1 by hand, its window closed by a quit event, v2 in the feed. Then the feed request and the `.aar` GET arrive with no input, and over the sampler's whole history no window appears beyond the one closed, the activation type stays `UIElement`, and neither the app nor a Sparkle helper is ever frontmost. | R1 "Login start", R5 |
| T58 | R3 | `update-e2e.sh` | With the server offering `Set-Cookie`, `ETag`, `max-age` and a 302 on the asset, over two checks of v1 and one of v2, under a changed `AppleLanguages`: every feed request has no query, no `Cookie` and no validator. `User-Agent` is `TrackpadLauncher`, `Accept-Language` is `en`, `Accept-Encoding` is `gzip`, and the header sets of the two versions are equal. | R3 scenario; E1 to E3 |
| T59 | R4 | `update-e2e.sh` | Feed items of 1.1 and 1.2: the highest downloads. 1.1 and a higher one needing macOS 99.0: 1.1 downloads. Only the running build, or a lower one: no asset request. | R4 scenarios |
| T60 | R2, R12 | `update-e2e.sh` | With an overdue `SULastCheckTime`, so any started engine would check: an Apple Development copy in /Applications; a Developer ID copy in ~/Applications with the dialog up; `root:wheel` mode 755; `root:admin` group-writable; a group not this user's. Each makes zero requests in 30 s, and no `SecurityAgent` window appears. After *Move to Applications*, the installed copy makes one. | R2, R12 scenarios; A11's third test |
| T61 | R1 | `update-e2e.sh` | `--after-update` with `SULastCheckTime` at now minus 86,380 s: no request for 20 s, then one by 36 s, with no restart. At now minus 30 h: one at once. | R1's 24 h and 30 h; A9's 15 s leeway |
| T62 | R13 | `update-e2e.sh` | Given an update waiting. When the person presses *Quit Trackpad Launcher*. Then the process is gone at once, the bundle reads v2 within 5 s, nothing runs for 120 s and no job is listed. Pressed during a stalled download instead, the bundle stays v1. | R13 scenario; `plainquit.out` |
| T63 | R8, R9 | `update-e2e.sh` | Given v2 held and no touch. Then the old pid ends 60 to 63 s after the later of the hold and the window closing, and v2 runs from /Applications with `--after-update` within 1 s of that. Over the sampler's whole history: no new window from any process, type `UIElement`, and neither the app nor a Sparkle helper is ever frontmost. No job stays listed, no feed request comes from v2 for 180 s, and its pid is unchanged at 180 s. The person's gesture reaches the front under 10 s after the exit. Spotlight then opens the window. | R9 scenarios, 10 s literal; B4, B11 |
| T64 | R8 | `update-e2e.sh` | With an update held, a finger resting 90 s and then a palm resting 90 s each keep the old pid alive past the mark. It ends 60 to 63 s after the lift. | R8; L4 on real hardware |
| T65 | R5 | `update-e2e.sh` | The server holds the `.aar` mid-body, and the person's gesture reaches the front. The server then resets the connection: nothing shows, v1 keeps running, and a second GET completes the download. | R5 scenarios |
| T66 | R1, R5 | `update-e2e.sh` | On a steady path, a feed that answers 503 once gives exactly 2 feed requests within 2 s, in all 20 of 20 rounds. The reading lands in Sparkle's end-of-cycle window, so this proves the real `check()` remembers the retry and runs it from `willScheduleUpdateCheckAfterDelay`: only here does a real `SPUUpdater` refuse a check. A feed that always answers 503: exactly 2 in 60 s, so the remembered check does not loop. | R1 retry; `pendingcheck.out`; design section 7, no hot loop |
| T67 | R6, R7 | `update-e2e.sh` | A tampered EdDSA signature; a valid EdDSA signature on v2 signed by Apple Development; one signed by the Developer ID but not notarised; one with another bundle identifier under the host's file name. Each: no install, no hand-over past the minute, v1 running, nothing shown, and a later check tries again. An enclosure of `.dmg` or another host: no asset request at all. | R6 scenarios; D1 to D3 |
| T68 | R11 | `update-e2e.sh` | Given a read-only parent set while an update waits, in a folder one level inside /Applications. Then stage 3 fails, v1 is opened with `--after-update` 5 to 7 s after the exit, and `codesign --verify --strict` passes. The gesture reaches the front under 10 s. No feed request comes for 120 s, so no hand-over loop. With the parent writable and the stamp overdue, the next start installs v2. | R11 scenario; C1, C2, `discardquit.out` |
| T69 | R8, R11, R13 | `update-e2e.sh` | 20 rounds of `kill -9` on the app at a random moment from check to hand-over, and 10 of `kill -9` on `Autoupdate` in the second after the exit. After each: every sampled read was a whole v1 or v2, `codesign --verify --strict` passes, nothing restarted unless the job had been armed, no job is left, and a relaunch runs with one process. | Design's hand-over table; R11 "at every moment" |
| T70 | R12 | `update-e2e.sh` | `--after-update`, the parent made read-only after the gate read it, and a stamp that fires 20 s later. Then the update does not install, no `SecurityAgent` window appears, and the cycle ends silently. | A10 |
| T71 | R6, R8 | `update-e2e.sh` | With an update waiting, remove `<id>-sparkle-updater`. Then no hand-over at the mark, v1 runs, and a later check downloads again. | C5 |
| T72 | R1 | `update-e2e.sh` | A build with an empty `SUPublicEDKey`: zero requests, nothing shown, gestures work. | Design: "an empty key lands here, silently" |
| T73 | R1 | Platform, real monitor | `SystemConnection`: `watch` pushes one reading with no change on the path. After `stop`, nothing more arrives. A second `watch` pushes again. | `Connection`'s contract; `path.out` |

### Verified without a test

- **R1, a real login start.** Log out and in with an installed copy that has a newer release to find. Expected: no window, and the update installs a minute after the session settles.
- **R1, offline (L3).** Turn Wi-Fi off. Open an installed release copy with a newer release to find, and close its window. Read `defaults read <id> SULastCheckTime`. Wait a minute, then turn Wi-Fi on. Expected: within 10 s the stamp is newer and Sparkle's cache holds the download.
- **R1, sleeping past the mark (A9).** Quit. Run `defaults write <id> SULastCheckTime -date "<now minus 23 h 58 min>"`, then `open -g -a <app> --args --after-update`, then `pmset sleepnow`. Wake after 5 minutes. Expected: the stamp changes within 30 s of waking.
- **R2.** The existing `theAdHocSignedTestRunnerHasNoDeveloperIDSignerEvenWhenItIsToldItIsARelease` row stays green.
- **R3, the real hosts.** `curl -sIL` the feed address: one 200, no redirect, no `Set-Cookie`. The asset URL: one redirect, no cookie (E4).
- **R7, the first real release.** Its output shows `notarytool` Accepted and `stapler validate` passing before `gh release create`.
- **R8 and R14, a real logout, restart and shutdown (D-3).** With an update waiting, the window open, then closed, then during a stalled download. Expected: each proceeds at once with no dialog. At the next login either v2 runs, or v1 runs and v2 installs under R8's conditions, with no window, Dock icon or dialog.
- **R8, a sleeping display and App Nap (L5).** Hold an update and run `pmset displaysleepnow`. Expected: the hand-over still comes within a few seconds of the mark.
- **R10, permissions and the login item (L2).** On a notarised copy with Accessibility and Screen Recording granted, the login item on, a non-default thumb corner and *Hide background apps* on, let a real update install. Expected: System Settings shows all of it unchanged, click blocking and window previews work, and the next login starts the app.
- **R15.** `grep -rniE 'update|sparkle' LauncherKit/Sources/LauncherUI` finds nothing, and `Copy` holds no update string. Open the window with an update waiting: it matches a window with none.
- **R16, the last card (F8).** Install the published 1.0.15 in /Applications, open the window and press *Update now* on the first automatic version. Expected: it installs, opens with the window, and the next release arrives on its own.

## Slices

The rows of `update-e2e.sh` and the by-hand checks need a person with credentials, so they sit in their own slices. The behaviour slices finish on `swift test`. Nothing here ships before the last slice, so a slice may leave the app with no update path.

### S1: Sparkle in the build

**What to build:** the branch sits on `origin/main`, `LauncherPlatform` links Sparkle 2.10.1, and every way of building resolves it without the keychain stall. Nothing calls Sparkle yet.

**Blocked by:** None (can start immediately).

**Requirements:** None. Every later slice needs it.

**Test scenarios:** None.

**Skills:** `axiom-macos`

- [ ] The branch is rebased onto `origin/main` first.
- [ ] `Scripts/test.sh` passes `--disable-keychain` in the same change that adds the dependency, and every `xcodebuild` passes `-packageAuthorizationProvider netrc` in that change too.
- [ ] The cold path is proven once with a scratch `--cache-path`. If it blocks, the vendored `.binaryTarget(path:)` fallback is taken and the development log says so.
- [ ] `Package.resolved` is committed, and the tree stays clean after a test run and a build.
- [ ] The app builds with Sparkle embedded and the existing suite stays green.

### S2: The card's rules outlive the card

**What to build:** `CardContract` and `card-contract` hold a frozen copy of what every shipped card demands of a release, with its tests, and `release.sh` runs it on the stapled archive. The shipped code stays in place until S3.

**Blocked by:** S1.

**Requirements:** R16, in part.

**Test scenarios:** T48, T49, T50.

**Skills:** `swift-testing-pro`, `axiom-macos`

- [ ] A diff shows the moved code's bodies unchanged.
- [ ] The tool reports through standard error and its exit code, and passes the scan.
- [ ] `project.yml` does not link the new targets.
- [ ] A failing verdict stops a release. On `--archive-only` it is reported and the script goes on, as the stapler check does there.

### S3: The card and the hand-written updater go

**What to build:** the settings window shows nothing about updates, the app makes no network request, and *Quit Trackpad Launcher* and every quit answer with no update guard. `Updater`, the `InstalledRelease` gate and everything in design section 13's deletion list go, and what the move shares stays.

**Blocked by:** S2.

**Requirements:** R15; R13 and R14, the removal of the install guards.

**Test scenarios:** None. The existing lifecycle, move and start-at-login rows stay green with the update rows removed.

**Skills:** `axiom-swiftui`

- [ ] R15's grep finds nothing.
- [ ] The move's `Installer` path and its tests are untouched.
- [ ] `LauncherCore` holds no version number.
- [ ] The scan's rows for deleted code go, with the bans the design keeps still listed.

### S4: A gated copy checks on its own and holds the update

**What to build:** the tracer through every layer. A copy that passes `UpdatableCopy` starts `SparkleEngine` once resident and checks in that turn. It reveals nothing, downloads silently, and the held update installs at the process's end with no relaunch. The world gains `InMemoryUpdateEngine` and the release form of `RunningBuild`.

**Blocked by:** S3.

**Requirements:** R1 (start and schedule), R2, R3, R4 (Sparkle's selection), R5 (silent download), R12.

**Test scenarios:** T1, T2, T3, T4, T5, T29, T30, T31, T43, T44.

**Skills:** `swift-concurrency`, `swift-testing-pro`, `axiom-macos`

- [ ] `Updater` shows an initializer, `start` and `onHandOver`, with no version in it.
- [ ] `Stage.replacingOthers` carries the opening.
- [ ] `import Sparkle` is in one file and no Sparkle type crosses the port.
- [ ] The Info.plist keys are in `project.yml`, with `SUPublicEDKey` empty until S12, which `start` reads as a silent failure.

### S5: Every release publishes a feed, or nothing

**What to build:** `appcast.xml`, `write_feed`, `publish_feed`, `--feed-only`, the build-number check, the key preflight and `card-contract` in the release order, proven in the new harness. The harness itself is part of this slice.

**Blocked by:** S2, S4.

**Requirements:** R4 (the feed), R7, R16 (the release step).

**Test scenarios:** T51, T52, T53, T54, T55.

**Skills:** `swift-testing-pro`

- [ ] `appcast.xml` starts as an empty channel with `</channel>` on its own line.
- [ ] Nothing in the harness touches the real `origin`, keychain or GitHub.

### S6: Real builds prove the path

**What to build:** `Scripts/update-e2e.sh`: two patched builds, signing, notarising, the local server, the sampler and cleanup, with the rows that need no hand-over. Its build step and report hold up without credentials, and a person runs the rows.

**Blocked by:** S5.

**Requirements:** R16's archive check, and the proof of R1, R2, R3, R4, R5, R12 and R13 on real builds.

**Test scenarios:** T56, T57, T58, T59, T60, T61, T62.

**Skills:** `axiom-macos`

- [ ] A person runs the script and its report is attached to the PR.
- [ ] The feed comes from `release.sh --feed-only`, not from a template of its own.
- [ ] Cleanup leaves no `.e2e` copy, job, defaults domain or login item.

### S7: The update waits for an idle minute

**What to build:** contact in `DeviceSession` and `MultitouchTrackpads`, `Launcher.isInUse` and `watchUse`, `IdleClock` and `SystemIdleClock`, and `.ready`. `Updater` calls `armRestart` when the minute passes. The real `armRestart` answers false until S9, so the app still installs at its next end.

**Blocked by:** S4.

**Requirements:** R8.

**Test scenarios:** T7, T8, T9, T10, T11, T12, T13, T14, T35, T36, T37, T38, T45.

**Skills:** `swift-concurrency`, `swift-testing-pro`

- [ ] No new main-actor hop exists while `sensesContact` is off.
- [ ] Each lasting effect starts and stops in `enter`.

### S8: Only a genuine update installs

**What to build:** at `willInstallUpdateOnQuit`, `SparkleEngine` runs `isGenuine` on the extracted bundle against `ExpectedUpdate`, inside the delegate call. A `.notGenuine` verdict discards the update through both layers of `SparkleInternals.veto(job:extracted:)`, inside that same call.

**Blocked by:** S7.

**Requirements:** R6; R7, the client's half.

**Test scenarios:** T6, T32, T33, T34.

**Skills:** `swift-concurrency`, `swift-testing-pro`

- [ ] `extractedUpdate` and `installerJob` live in `SparkleInternals`, each naming its proof.
- [ ] Every failure to find or read a bundle reads `.notGenuine`.

### S9: The silent hand-over

**What to build:** `LaunchdJob`, the hand-over script, `armRestart`, `.handedOver`, `Lifecycle.handedOver`, `Opening.afterUpdate`, its `Route` rows and `ThisCopy`'s argument. The old copy ends itself, the new one comes up silent, and a failed install brings the old one back. *Quit* and logout answer as design section 5 says in every phase.

**Blocked by:** S8.

**Requirements:** R8 (the install), R9, R10, R11, R13, R14.

**Test scenarios:** T15, T16, T17, T18, T19, T20, T21, T22, T23, T39, T40, T41, T42, T46.

**Skills:** `swift-concurrency`, `swift-testing-pro`, `axiom-macos`

- [ ] `handedOver` uses `end()`, never `quit()`.
- [ ] Arming and ending happen in one main-actor turn.
- [ ] An after-update start makes no check of its own.

### S10: A failed request retries when the connection returns

**What to build:** `Connection`, `SystemConnection` and `.awaitingConnection`. A request that failed runs again once a connection is there, with no timer and no hot loop. `SparkleEngine.check` remembers a check refused in Sparkle's end-of-cycle window and runs it from `willScheduleUpdateCheckAfterDelay`; only T66, in S11, can prove that part on a real `SPUUpdater`.

**Blocked by:** S4.

**Requirements:** R1 (the retry), R5 (the later try).

**Test scenarios:** T24, T25, T26, T27, T28, T47, T73.

**Skills:** `swift-concurrency`, `swift-testing-pro`

- [ ] A path monitor exists only while `.awaitingConnection` lasts.

### S11: Real builds prove the hand-over

**What to build:** the remaining rows in `update-e2e.sh`: the full silent update, real contact, lost and failing requests, refused updates, failed installs, random kills and a dead helper.

**Blocked by:** S6, S9, S10.

**Requirements:** The proof of R1, R5, R6, R7, R8, R9, R11, R12 and R13 on notarised builds.

**Test scenarios:** T63, T64, T65, T66, T67, T68, T69, T70, T71, T72.

**Skills:** `axiom-macos`

- [ ] A person runs the script and its report is attached to the PR.
- [ ] T63 and T68 hold their 10 s bounds, and T63's copy survives its 180 s.

### S12: The docs match what shipped, and the first automatic release is cleared

**What to build:** `docs/architecture.md` and `docs/domain-model.md` are already rewritten, so this slice confirms they match what shipped and corrects any drift. It writes the rest of design section 13's table: `docs/product-overview.md`, `README.md` and `release.sh`'s header. It also re-measures the performance baseline, creates the update key and runs the by-hand checks.

**Blocked by:** S11.

**Requirements:** R1, R3, R7, R8, R10, R14, R15 and R16, the checks under Verified without a test.

**Test scenarios:** None.

**Skills:** None.

- [ ] `docs/architecture.md` and `docs/domain-model.md` are read against the shipped code, and any drift is corrected.
- [ ] `docs/product-overview.md`, `README.md` and `release.sh`'s header are written, as design section 13's table says.
- [ ] `docs/performance.md` holds a re-measured baseline with Sparkle and WebKit loaded, and with an update waiting, as `Scripts/perf` measures them (G5).
- [ ] The human runs `generate_keys`, stores `generate_keys -x` outside this Mac and puts the public key in `project.yml`, and `release.sh` preflight passes.
- [ ] Every check under Verified without a test is run, and its result is in the development log.
- [ ] D-3 and L2 are answered before the first automatic release is published.
