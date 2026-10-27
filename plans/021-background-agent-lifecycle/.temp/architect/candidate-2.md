## Design

### Problem

Trackpad Launcher becomes a background app whose whole lifecycle is new: how a process behaves when it starts (login,
by hand, from /Applications or elsewhere, a development build, beside other copies), how it keeps one copy
recognising gestures, how it quits and when quitting turns starting at login off, how it moves itself into
/Applications, and how it ships. Today none of that exists: no app delegate, no activation policy switch, no
single-instance rule, no unregister, no move, a zip release. What makes the shape non-obvious is the set of
constraints the grounding fixed. Policy must stay in the one `@MainActor @Observable` model, testable through
in-memory adapters, with window visibility as model state and no `terminate`/`openURL` closures in the model
(`why.md` Preserve 4-5). "First run" must stay derived from the absence of a settings record, with no second boolean
that can drift, and a user who turned the login item off must never be re-enrolled (Preserve 1-2, Avoid 1-2). No
timers, polling or `Task.sleep` anywhere, so waiting for another process to end must be a push (F37). The
login-start marker (F2), the Login Items status after a user's own change (F25) and the logout signals (F17-F19) are
unverified on macOS 26, so every rule that rests on them needs a fallback that converges. And the move must not spend
the first run (login registration, Accessibility prompt, first save) in the copy about to be replaced (Risk 4).

### Usage (caller's view)

**README.** One `Launcher` owns every lifecycle decision. A process tells it how it was started, once; after that
the shell renders two observable facts, `launcher.phase` and `launcher.window`, and forwards user intents. Nothing
senses gestures, prompts, registers or saves before `launch(_:)`, and a copy that must move never gets past the move
dialog.

```swift
// 1. When the process has finished launching (the Apple event is readable only then):
launcher.launch(LaunchFacts.read())          // Launch: how, build, place, peers, pid → the model decides

// 2. The shell renders. `window` drives the Dock icon and the settings window; `phase` drives the rest.
for await window in Observations({ launcher.window }) { ... }   // .open(presentation:) → present, .closed → hide
for await phase in Observations({ launcher.phase }) { ... }     // .offeringMove → dialog, .quitting → NSApp.terminate

// 3. Every way to quit is a question to the model, never a decision of the shell:
launcher.terminationRequested(.user)     // Dock Quit: closes the window, keeps running  → .keepRunning
launcher.terminationRequested(.peer)     // a newer copy taking over                     → .terminate
launcher.terminationRequested(.session)  // logout, restart, shutdown                    → .terminate

// 4. The user's intents, from the window and the move dialog:
launcher.openWindow(); launcher.closeWindow(); launcher.quit(); launcher.answerMoveDialog(.move)
```

**Call site 1: the app delegate (the app target, thin).**

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launcher: Launcher
    private let quits: QuitEvents          // LauncherPlatform: parses the quit being handled into a TerminationRequest

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.disableRelaunchOnLogin()      // "Reopen windows" never starts us (F3); SMAppService does, or the user
        launcher.launch(LaunchFacts.read())
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        launcher.openWindow()               // Spotlight, Finder, Launchpad while running: the same window, presented again
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        launcher.terminationRequested(quits.current()) == .terminate ? .terminateNow : .terminateCancel
    }
}
```

**Call site 2: the shell renders `window` and `phase`.**

```swift
observations.append(Task { [weak self] in
    for await window in Observations({ launcher.window }) {
        switch window {
        case .open: self?.present()         // .regular policy, centred on the pointer's display, deminiaturised, key, active
        case .closed: self?.hide()          // orderOut, .accessory policy: Dock icon gone, gestures untouched
        }
    }
})
observations.append(Task { [weak self] in
    for await phase in Observations({ launcher.phase }) {
        switch phase {
        case .offeringMove: launcher.answerMoveDialog(MoveDialog.ask())
        case .quitting(let notice): if notice == .moveFailed { MoveDialog.showMoveFailed() }; NSApp.terminate(nil)
        default: break
        }
    }
})
```

**Call site 3: a test at the model's seam, with the fakes delivering every push.**

```swift
@Test func quitTurnsLoginOffAndTheNextOpenByHandFromApplicationsTurnsItBackOn() {
    let world = World()
    world.launch(.byHand(from: .installed))          // first run: registers, asks, saves, opens the window
    #expect(world.system.isLoginItemEnabled())

    world.launcher.quit()
    #expect(world.launcher.phase == .quitting(notice: nil))
    #expect(!world.system.isLoginItemEnabled())

    world.relaunch(.byHand(from: .installed))
    #expect(world.system.isLoginItemEnabled())       // R12: Quit turned it off, so the open turned it back on
}

@Test func aReleaseCopyOpenedFromADiskImageMovesAndHandsOverToTheInstalledCopy() {
    let world = World()
    world.launch(.byHand(from: .elsewhere(World.diskImageCopy)))
    #expect(world.launcher.phase == .offeringMove(World.diskImageCopy))
    #expect(world.hardware.runCount == 0 && world.permissions.asks.isEmpty && world.store.load() == nil)

    world.launcher.answerMoveDialog(.move)
    world.peers.allEnded()                           // the push: the running copy in /Applications has quit
    world.installer.finish(.installed)               // the push: copied, replaced, quarantine cleared
    #expect(world.installer.openedInstalledCopy == 1)
    #expect(world.launcher.phase == .replaced)
    #expect(world.launcher.terminationRequested(.peer) == .terminate)
}
```

### Shape

**Data first.** Three structures carry the whole lifecycle, and each is a sum type so that no combination a comment
would have to explain can exist (per `type-system-discipline`):

- `Launch` is what a process knows once, at start: *how* (`atLogin` | `byHand`), *build* (`development` |
  `release`), *place* (`installed` | `elsewhere(Copy)`), the *peers* (other running copies, each with its `Copy`) and
  its own pid. `Launch.plan` is the one pure table that turns it into a `LaunchPlan`: `run(opensWindow:)`,
  `offerMove(Copy)` or `yield`. Every row of task items 1, 2, 6 and 7 is a line of that table.
- `Phase` is the process's lifecycle as the model owns it: `launching → stoppingPeers(then:) → running`, or
  `offeringMove → stoppingPeers(then: .install) → moving → replaced`, or `quitting(notice:)`. The two pushes a test
  cannot wait for, peers ending and the install finishing, are the only transitions not driven by an intent, and each
  is a port callback the fake delivers by hand.
- `WindowState` is `closed | open(presentation: Int)`. The counter grows on every open request, including one for a
  window already open, so "every time it opens: centred on the pointer's display, in front, with the keyboard focus,
  restored if minimised" (R2, R7) is one observable change the shell renders, not a shell-side special case.

Starting at login is one persisted fact, `Settings.isLoginItemSuspended`: Trackpad Launcher itself turned the login
item off and must turn it back on at the next start by hand from /Applications. Quit sets it when the item was on
(R12); a copy that moves away from where it was registered sets it the same way (R20's "starting at login kept"). The
user's own Login Items choice is never written anywhere: Quit and the move read `isLoginItemEnabled()` and do nothing
when it is off, and no start registers unless it is the first run from /Applications or the flag says so (R13). This
makes the disputed status semantics (F25, open question 2) moot: the design only asks "enabled now?", never "who
turned it off?". The order of writes is chosen so a crash at any point converges (per `make-operations-idempotent`):
set the flag, save, then unregister; later register, clear the flag, save. A crash between leaves the item on with
the flag set, which the next start repairs with a harmless `kSMErrorAlreadyRegistered`.

**Seams.** Two new ports, each hiding an asynchronous system interaction behind one method and one push (per
`boundary-discipline`): `Peers.stopAll()` + `onAllEnded` (terminate every other copy of the bundle id and watch each
`isTerminated` by KVO, no timer) and `Installer.install(_:)` + `onInstalled` (authorisation when needed, copy via a
sibling temp directory, atomic replace, quarantine cleared, original removed where it can be), plus
`Installer.openInstalledCopy()` and `Installer.eject(diskImage:)`. The login item stays on `SystemActions`, now with
`isLoginItemEnabled()`, `registerLoginItem()`, `unregisterLoginItem()`. Everything else the lifecycle needs is read
once at the boundary into `Launch` by `LaunchFacts.read()` in LauncherPlatform (the Apple event, the code signature,
the bundle's place with translocation resolved and its disk image found, the running copies) and never crosses a port
as a framework type. `QuitEvents.current()` likewise parses the quit being handled into a `TerminationRequest`
(`peer` when the sender's bundle id is ours, `session` when the event carries `kAEQuitReason` or
`willPowerOff` was seen, `user` otherwise).

**The frontmost app while Trackpad Launcher is active (R15)** is solved below the port, not in the model: a
`FrontmostApp` memory in LauncherPlatform observes every activation (a push) and answers "the app in front, never
this one; while this one is active, the app that was in front before it". `RunningAppsReader` and
`FrontmostAppWindows` share it, so `RunningApps.frontmost == nil` goes back to meaning only "no active app, or one
with no bundle". The switcher, the swap and the window swipe need no change, and the four `window = .closed` writes
in the gesture paths are deleted (R15).

**What the public surface hides.** The shell learns four intents and two observables; the delegate learns one call
per AppKit hook. Behind them sit the launch table, single-instance replacement with its wait, the login-item
bookkeeping and its crash ordering, the move's gate, the disk-image ejection decided from the peers that ended, and
the quit classification. Nothing exposes a stage: there is no `startAfterPeersEnded()` for a caller to sequence. The
move dialog and the administrator prompt are the only UI the model does not drive through state, because both are
modal questions whose answers are intents.

**Deliberately not done.** No relaunch after a crash (R14; `SMAppService.mainApp` never relaunches, F23). No
"wait then force-quit" for a peer that ignores the request: without timers the process waits, and the user
force-quits the old one. No argument hand-over from the mover to the installed copy: the installed copy derives the
disk image to eject from the peer it stopped. No `LSMultipleInstancesProhibited` (it is about users, not copies).

#### Type sketch: LauncherCore

```swift
// Lifecycle.swift

/// A process identifier, branded so it is never compared with another integer.
public struct ProcessID: Hashable, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
}

/// A copy of Trackpad Launcher on disk, where the user sees it: for a translocated copy the bundle the user opened,
/// never the hidden mount it runs from. `diskImage`: the volume of the disk image it lies on; nil anywhere else.
public struct Copy: Equatable, Sendable {
    public let url: URL
    public let diskImage: URL?
    public init(url: URL, diskImage: URL? = nil) { fatalError("not implemented") }
}

/// Where this process's bundle is. `installed`: directly inside /Applications, under any name. ~/Applications and
/// every other folder, a disk image and a network share are `elsewhere` (R18).
public enum Place: Equatable, Sendable {
    case installed
    case elsewhere(Copy)
}

/// Another running Trackpad Launcher, whatever its version or place.
public struct Peer: Equatable, Sendable {
    public let pid: ProcessID
    public let copy: Copy
    public init(pid: ProcessID, copy: Copy) { fatalError("not implemented") }
}

/// How this process came to run, read once when it has finished launching. A reopen of the running copy is not a
/// launch: LaunchServices routes it to the running process (`Launcher.openWindow()`), and a second process means a
/// different build or a different place (C1).
public struct Launch: Equatable, Sendable {
    public enum How: Equatable, Sendable {
        /// macOS started it as a login item. Never a window, a dialog or a prompt (R9, R22).
        case atLogin
        /// The user, through Finder, Spotlight, Launchpad or Xcode, or the copy that just installed this one.
        case byHand
    }

    public enum Build: Equatable, Sendable {
        /// Not signed with a Developer ID: Xcode, the perf build, an ad-hoc binary (R23, F7-F8).
        case development
        case release
    }

    public let how: How
    public let build: Build
    public let place: Place
    public let peers: [Peer]
    public let pid: ProcessID

    public init(how: How, build: Build, place: Place, peers: [Peer], pid: ProcessID) { fatalError("not implemented") }

    /// The whole launch table, in one place:
    ///
    /// | how     | build       | place     | plan                                                      |
    /// |---------|-------------|-----------|-----------------------------------------------------------|
    /// | atLogin | any         | any       | run silently; yield when a peer with a lower pid runs     |
    /// | byHand  | development | any       | run with the window, wherever it was built (R23)          |
    /// | byHand  | release     | installed | run with the window (R2-R4)                               |
    /// | byHand  | release     | elsewhere | offer the move and nothing else (R18)                     |
    ///
    /// Running always stops every peer first (R2, R3): a by-hand open wins over whatever runs. Two login starts
    /// (two registrations, as before a move converged them) keep the older process.
    public var plan: LaunchPlan { fatalError("not implemented") }
}

public enum LaunchPlan: Equatable, Sendable {
    /// Stop every peer, then run: gestures on, the window open when `opensWindow`.
    case run(opensWindow: Bool)
    /// Show the move dialog for this copy and nothing else.
    case offerMove(Copy)
    /// Quit at once.
    case yield
}

/// The process's lifecycle, owned by the model. The shell renders it and writes nothing.
public enum Phase: Equatable, Sendable {
    /// Before `launch(_:)`: nothing senses gestures, prompts, registers or saves.
    case launching
    /// Every other copy was asked to quit; waiting for the adapter's push, then `then`.
    case stoppingPeers(then: AfterPeersEnd)
    /// Gestures on. `window` says whether the settings window is open.
    case running
    /// The move dialog is up: the only thing of Trackpad Launcher on screen (R18).
    case offeringMove(Copy)
    /// Move pressed: the install is in flight (the administrator prompt, the copy, the replace).
    case moving(Copy)
    /// The copy in /Applications was opened; this process idles until that copy stops it (`.peer`).
    case replaced
    /// Terminate now, after showing `notice` when there is one.
    case quitting(notice: Notice?)

    public enum AfterPeersEnd: Equatable, Sendable {
        case start(opensWindow: Bool)
        case install(Copy)
    }

    public enum Notice: Equatable, Sendable { case moveFailed }
}

/// The settings window as the model holds it. Minimised is AppKit's business: a minimised window is `open`, so the
/// Dock shows the app (R6).
public enum WindowState: Equatable, Sendable {
    case closed
    /// `presentation` grows with every open request, one for an already open window included, so each request
    /// presents the window again: centred on the pointer's display, restored if minimised, in front, key (R2, R7).
    case open(presentation: Int)
}

/// Who asked the process to quit, parsed at the boundary from the quit event (F15-F17, F19).
public enum TerminationRequest: Equatable, Sendable {
    /// Another Trackpad Launcher: a newer copy taking over (R3, R20), or the copy this one installed.
    case peer
    /// Logout, restart or shutdown (R8).
    case session
    /// The Dock's Quit, a scripted quit, anything else: the window closes, the process stays (R8).
    case user
}

public enum TerminationReply: Equatable, Sendable { case terminate, keepRunning }

public enum MoveAnswer: Equatable, Sendable { case move, quit }

public enum InstallOutcome: Equatable, Sendable {
    case installed
    /// The administrator prompt was cancelled: nothing was touched (R21).
    case cancelled
    case failed
}
```

```swift
// Settings.swift (one field added; the decoder rule covers it: a missing key is false)

public struct Settings {
    // …existing fields…
    /// Starting at login was turned off by Trackpad Launcher itself, by the Quit button or by a copy that moved away
    /// from where it was registered, and is to be turned back on at the next start by hand from /Applications. Never
    /// set when the user turned it off in Login Items. The key is this field's name, permanently.
    public var isLoginItemSuspended = false
}
```

```swift
// Ports.swift

@MainActor public protocol SystemActions: AnyObject {
    // …existing members unchanged…

    /// Whether macOS holds this app as a login item that may run now. Reads only; never prompts.
    func isLoginItemEnabled() -> Bool
    /// Open at Login on, for this bundle. Idempotent: already registered is not an error. A refusal (an unsigned
    /// build, a user who turned it off in Login Items) is silent and leaves the app running without it.
    func registerLoginItem()
    /// Open at Login off. Idempotent. This process keeps running.
    func unregisterLoginItem()
}

/// The other running copies of this app. Real: RunningCopies. Test: InMemoryPeers.
@MainActor public protocol Peers: AnyObject {
    /// Asks every other running copy of this bundle identifier to quit, now, and watches each until it ends.
    /// `onAllEnded` runs on the main actor once none runs: before this call returns when none ran. Idempotent while
    /// waiting. Never a timer: a copy that will not end leaves this one waiting, and the user force-quits it.
    func stopAll()
    var onAllEnded: (@MainActor () -> Void)? { get set }
}

/// Moving a copy into /Applications. Real: AppInstaller. Test: InMemoryInstaller.
@MainActor public protocol Installer: AnyObject {
    /// Puts `copy` at /Applications/<its name>, replacing whatever is there, with an administrator's authorisation
    /// when /Applications or the existing copy is not writable; clears quarantine on the new copy; then removes the
    /// original where it can (never from a disk image; a read-only share is tolerated). Nothing is touched until the
    /// authorisation, when needed, has succeeded; leftovers of an interrupted install are removed first. Returns at
    /// once; `onInstalled` reports exactly once, on the main actor.
    func install(_ copy: Copy)
    var onInstalled: (@MainActor (InstallOutcome) -> Void)? { get set }
    /// Opens the copy in /Applications as Finder would. This process runs elsewhere, so a new process starts.
    func openInstalledCopy()
    /// Ejects the disk image at `volume` when nothing on it is in use; silently leaves it mounted otherwise (R19).
    func eject(diskImage volume: URL)
}
```

```swift
// Launcher.swift (what changes; the gesture, switcher and settings paths stay as they are, minus the window closes)

@MainActor @Observable
public final class Launcher {
    public private(set) var phase: Phase = .launching
    public private(set) var window: WindowState = .closed
    public var isWindowOpen: Bool { window != .closed }
    // `.heldOpen` and `dismissWindow()` are gone: an ordinary window never closes on an outside click (R7).

    @ObservationIgnored private var launch: Launch?
    @ObservationIgnored private var presentations = 0
    @ObservationIgnored private let peers: any Peers
    @ObservationIgnored private let installer: any Installer

    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, peers: any Peers,
        installer: any Installer, store: SettingsStore
    ) { fatalError("not implemented") }   // as today: the synchronous catalog scan, `isFirstLaunch = stored == nil`, no save

    /// The one entry from the process. Call once, from `applicationDidFinishLaunching`.
    public func launch(_ launch: Launch) {
        // TODO:
        // self.launch = launch
        // peers.onAllEnded = { [unowned self] in peersEnded() }
        // installer.onInstalled = { [unowned self] in installed($0) }
        // switch launch.plan {
        // case .yield:                 phase = .quitting(notice: nil)
        // case .offerMove(let copy):   phase = .offeringMove(copy)
        // case .run(let opensWindow):  stopPeers(then: .start(opensWindow: opensWindow))
        // }
        fatalError("not implemented")
    }

    /// The move dialog's answer (R18-R21).
    public func answerMoveDialog(_ answer: MoveAnswer) {
        // TODO: guard case .offeringMove(let copy) = phase else { return }
        // .quit → phase = .quitting(notice: nil)                                   // nothing was changed
        // .move → suspendLoginItemIfEnabled(); stopPeers(then: .install(copy))    // R20: stop the running one first
        fatalError("not implemented")
    }

    /// The Quit button (R11, R12). No confirmation.
    public func quit() {
        // TODO: guard phase == .running else { return }
        // suspendLoginItemIfEnabled()
        // window = .closed
        // phase = .quitting(notice: nil)
        fatalError("not implemented")
    }

    /// Every quit the process is asked for, decided here (R8, R3, R20).
    public func terminationRequested(_ request: TerminationRequest) -> TerminationReply {
        // TODO:
        // if case .quitting = phase { return .terminate }; if phase == .replaced { return .terminate }
        // switch request {
        // case .peer, .session: return .terminate      // no login bookkeeping: a replacement keeps it as it was (R25)
        // case .user: closeWindow(); return .keepRunning
        // }
        fatalError("not implemented")
    }

    /// Opens the settings window, or presents it again when it is open. Only while running.
    public func openWindow() {
        // TODO: guard phase == .running else { return }
        // presentations += 1; window = .open(presentation: presentations)
        // resolveRows(); scanner.scan()                       // as today: the only scan request besides launch
        fatalError("not implemented")
    }

    /// The close button, ⌘W, Escape, ⌘Q, the Dock's Quit, Close Settings: all one intent.
    public func closeWindow() { window = .closed }

    private func stopPeers(then next: Phase.AfterPeersEnd) {
        // phase = .stoppingPeers(then: next)   // before the call: the adapter may push back inside it
        // peers.stopAll()
        fatalError("not implemented")
    }

    private func peersEnded() {
        // TODO: guard case .stoppingPeers(let next) = phase, let launch else { return }
        // for peer in launch.peers { if let image = peer.copy.diskImage { installer.eject(diskImage: image) } }
        // switch next {
        // case .start(let opensWindow): start(opensWindow: opensWindow)
        // case .install(let copy):      phase = .moving(copy); installer.install(copy)
        // }
        fatalError("not implemented")
    }

    private func installed(_ outcome: InstallOutcome) {
        // TODO: guard case .moving = phase else { return }
        // .installed → installer.openInstalledCopy(); phase = .replaced
        // .cancelled → phase = .quitting(notice: nil)
        // .failed    → phase = .quitting(notice: .moveFailed)
        fatalError("not implemented")
    }

    /// Today's `start()`, under the launch's rules. Gestures run from here (R4, R9).
    private func start(opensWindow: Bool) {
        // TODO: wire hardware/system/scanner/preferences/permissions callbacks; scanner.scan(); reconcile()
        // if launch.how == .byHand {
        //     if isFirstLaunch {                                        // R5: the first run from /Applications
        //         if launch.place == .installed { system.registerLoginItem() }
        //         let prompting = !isAccessibilityGranted
        //         if prompting { permissions.ask(.accessibility) }
        //         store.save(settings)                                  // after both effects, as today
        //     } else if settings.isLoginItemSuspended, launch.place == .installed {
        //         system.registerLoginItem()                            // R12: only because Quit (or a move) turned it off
        //         settings.isLoginItemSuspended = false
        //         store.save(settings)
        //     }
        // }
        // phase = .running
        // if opensWindow { openWindow() }
        // resolveRows()
        fatalError("not implemented")
    }

    /// Quit and the move turn starting at login off only when it is on now, and record that before touching it: a
    /// crash in between leaves it on with the record set, which the next start by hand repairs.
    private func suspendLoginItemIfEnabled() {
        // guard system.isLoginItemEnabled() else { return }           // R13: the user's own choice is never overridden
        // settings.isLoginItemSuspended = true; store.save(settings); system.unregisterLoginItem()
        fatalError("not implemented")
    }

    // fire / swipe / windowSwipe / swap: unchanged, except the four `window = .closed` writes are removed (R15).
    // reconcile(): unchanged, except the held-window line is removed.
}
```

#### Type sketch: LauncherPlatform

```swift
// LaunchFacts.swift: the one composition of the four reads below. Call from `applicationDidFinishLaunching`; the
// Apple event is nil earlier (F1).
public enum LaunchFacts {
    public static func read() -> Launch { fatalError("not implemented") }
    // Launch(how: LaunchEvent.how(NSAppleEventManager.shared().currentAppleEvent, ownPID:),
    //        build: CodeSignature.isDeveloperIDSigned() ? .release : .development,
    //        place: BundlePlace.place(of: BundlePlace.copy(at: Bundle.main.bundleURL)),
    //        peers: RunningCopies.peers(), pid: ProcessID(rawValue: getpid()))
}

// LaunchEvent.swift: the only file that reads the launch Apple event. Pure over a descriptor, so a test builds one.
enum LaunchEvent {
    /// `.atLogin` when an `oapp` event carries `keyAEPropData == keyAELaunchedAsLogInItem` (F2).
    /// Fallback if macOS 26 does not carry the marker (open question 1): an `oapp` whose sender is neither this
    /// process (an `open`, F1) nor any running app (Finder, Spotlight, Launchpad, a peer) is a login launch.
    static func how(_ event: NSAppleEventDescriptor?, ownPID: pid_t) -> Launch.How { fatalError("not implemented") }
}

// CodeSignature.swift: confines SecCode* / SecRequirement*. The Developer ID requirement from the probe (F7).
enum CodeSignature {
    static let developerID = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
        + "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    /// The running code, via `SecCodeCopySelf`.
    static func isDeveloperIDSigned() -> Bool { fatalError("not implemented") }
    /// Any bundle or binary on disk; the test runs it over its own binary and expects false.
    static func isDeveloperIDSigned(at url: URL) -> Bool { fatalError("not implemented") }
}

// BundlePlace.swift: confines SecTranslocate* (dlsym, as LaunchServicesOrder resolves its symbols), statfs and
// DiskArbitration. Pure over URLs otherwise, so the test points it at temp paths.
enum BundlePlace {
    /// Translocation resolved to the bundle the user opened; the disk image's volume found by `statfs` →
    /// `f_mntfromname` → `DADiskCopyDescription` → device model "Disk Image" (F34, F35).
    static func copy(at bundleURL: URL) -> Copy { fatalError("not implemented") }
    static func place(of copy: Copy, applications: URL = URL(filePath: "/Applications")) -> Place {
        fatalError("not implemented")   // .installed iff copy.url's parent is `applications`
    }
}

// RunningCopies.swift: the Peers adapter. Confines `NSRunningApplication.terminate`.
@MainActor public final class RunningCopies: Peers {
    public var onAllEnded: (@MainActor () -> Void)?
    public init(bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "") { fatalError("not implemented") }
    /// Every other process of this bundle id, each with its `Copy` (translocation resolved, disk image found).
    public static func peers() -> [Peer] { fatalError("not implemented") }
    public func stopAll() {
        // TODO: let others = runningApplications(withBundleIdentifier:) minus own pid
        // if others.isEmpty { onAllEnded?(); return }
        // for app in others { app.terminate(); observe(app, \.isTerminated) { if all terminated { onAllEnded?() } } }
        fatalError("not implemented")
    }
}

// QuitEvents.swift: parses the quit being handled (F15-F17) and remembers `willPowerOff` (F19).
@MainActor public final class QuitEvents {
    public init() { fatalError("not implemented") }   // observes NSWorkspace.willPowerOffNotification
    /// `.session` with `kAEQuitReason` or after `willPowerOff`; `.peer` when the sender pid is an app with our
    /// bundle id; `.user` otherwise. `NSSupportsSuddenTermination` makes logout a kill in the common case (F18),
    /// so this classification is the fallback for a logout that still asks.
    public func current() -> TerminationRequest { fatalError("not implemented") }
}

// AppInstaller.swift: the Installer adapter. Decides the privileged path, runs the install off the main actor,
// reports once. Disables sudden termination for the duration of the install.
@MainActor public final class AppInstaller: Installer {
    public var onInstalled: (@MainActor (InstallOutcome) -> Void)?
    public init(applications: URL = URL(filePath: "/Applications")) { fatalError("not implemented") }
    public func install(_ copy: Copy) {
        // TODO: needsAuthorization = !isWritable(applications) || (exists(dst) && !isWritable(dst))
        // Task { @concurrent: PrivilegedInstall or BundleInstall; hop back; onInstalled?(outcome) }
        fatalError("not implemented")
    }
    public func openInstalledCopy() { fatalError("not implemented") }   // NSWorkspace.openApplication(at:, activates: true)
    public func eject(diskImage volume: URL) { fatalError("not implemented") }   // confined to DiskImages.swift
}

// BundleInstall.swift: the unprivileged file operations, a concrete value over roots a test points at temp dirs.
// Confines `copyItem(` and `replaceItemAt(`.
struct BundleInstall: Sendable {
    let applications: URL
    /// Removes any `.<name>.installing` leftover; copies to that sibling; `replaceItemAt` the destination (atomic);
    /// clears `quarantinePropertiesKey` on every item of the new copy; removes the original unless on a disk image,
    /// tolerating failure (R19).
    func perform(_ copy: Copy) throws { fatalError("not implemented") }
}

// PrivilegedInstall.swift: the administrator path (R21). `AuthorizationCreate` + `AuthorizationCopyRights` with
// interaction, then `AuthorizationExecuteWithPrivileges` resolved with dlsym (F32): `ditto` to the sibling, `rm -rf`
// the destination, `mv` the sibling into place. `errAuthorizationCanceled` → `.cancelled` with nothing touched.
enum PrivilegedInstall {
    static func perform(_ copy: Copy, into applications: URL) -> InstallOutcome { fatalError("not implemented") }
}

// FrontmostApp.swift: R15 below the port. One activation observer for the life of the process.
/// The app in front, never this one: while this app is active, the app that was in front before it, as long as it
/// still runs. Seeded with the app in front at creation.
@MainActor final class FrontmostApp {
    init() { fatalError("not implemented") }
    func current() -> NSRunningApplication? { fatalError("not implemented") }
}
// RunningAppsReader.frontmost() and FrontmostAppWindows.read() take `FrontmostApp` in their inits and read
// `current()` instead of `NSWorkspace.shared.frontmostApplication`; the pid filters stay.

// WorkspaceActions.swift: the login item, confining `SMAppService`.
extension WorkspaceActions {
    public func isLoginItemEnabled() -> Bool { fatalError("not implemented") }   // SMAppService.mainApp.status == .enabled
    public func registerLoginItem() { fatalError("not implemented") }           // try? register(); already registered is fine
    public func unregisterLoginItem() { fatalError("not implemented") }         // try? unregister(); not found is fine
}
```

#### Type sketch: LauncherUI and the app target

```swift
// SettingsWindowShell.swift: replaces MenuBarShell; LauncherUI's one public type. Owns the settings window, both
// switcher presenters, the first synchronous icon pass and the main menu. Confines `setActivationPolicy`.
public final class SettingsWindowShell: NSObject, NSWindowDelegate {
    public init(launcher: Launcher) { fatalError("not implemented") }
    // observes launcher.window → present() / hide(); launcher.phase → the move dialog, the failure notice, terminate
    private func present() {
        // NSApp.setActivationPolicy(.regular); window.fitToContent(); window.center(in: Displays.screen(under:
        // NSEvent.mouseLocation)); if miniaturized { deminiaturize }; makeKeyAndOrderFront; NSApp.activate()
    }
    private func hide() { /* orderOut; NSApp.setActivationPolicy(.accessory) */ }
    /// The close button and ⌘W (`performClose`): an intent, never a direct close. The window is kept (Preserve 8).
    public func windowShouldClose(_ sender: NSWindow) -> Bool { fatalError("not implemented") }  // launcher.closeWindow(); false
    @objc private func closeSettings(_ sender: Any?) { fatalError("not implemented") }           // ⌘Q: launcher.closeWindow()
}

/// Titled, closable, miniaturisable, not resizable; normal level; the glass content built once.
final class SettingsWindow: NSWindow {
    var onCancel: () -> Void = {}
    override func cancelOperation(_ sender: Any?) { onCancel() }   // Escape: an open picker menu consumes it first (F45)
    func fitToContent() { fatalError("not implemented") }
    func center(in screen: NSScreen?) { fatalError("not implemented") }
}

/// App menu: "Close Settings" ⌘Q (R8). Window menu: "Close" ⌘W → performClose:, "Minimize" ⌘M. No keyDown anywhere.
enum MainMenu { static func make(closeSettings: Selector, target: AnyObject) -> NSMenu { fatalError("not implemented") } }

/// The move dialog (R18) and the failure notice: NSAlert.runModal after activating, like LetsMove.
enum MoveDialog {
    static func ask() -> MoveAnswer { fatalError("not implemented") }   // "Move to Applications" default, "Quit"
    static func showMoveFailed() { fatalError("not implemented") }
}

struct LauncherActions {
    let cachedIcon: (URL) -> NSImage
    let icon: (URL) -> NSImage
    /// Other…: `NSOpenPanel.beginSheetModal(for: window)`; the window stays open; Cancel changes nothing (R16).
    let chooseOtherApp: (@escaping (URL) -> Void) -> Void
    /// Opens the pane; the window stays open (R17).
    let openSettings: (SettingsPane) -> Void
}
// LauncherView: ends with `Button("Quit Trackpad Launcher") { launcher.quit() }` in `.glassProminent` tinted
// `.red`, `.buttonBorderShape(.capsule)`, `.controlSize(.regular)`, trailing-aligned below every notice (R10).
```

```swift
// TrackpadLauncher/AppDelegate.swift (call site 1 above) and TrackpadLauncherApp.swift

@main enum TrackpadLauncherApp {
    static func main() {
        // let application = NSApplication.shared
        // adapters as today, plus RunningCopies(), AppInstaller(), QuitEvents()
        // let launcher = Launcher(…, peers:, installer:, store:)
        // let shell = SettingsWindowShell(launcher:)        // before launch: the first icon pass, the window built once
        // let delegate = AppDelegate(launcher:, quits:)
        // application.delegate = delegate
        // #if DEBUG: observe launcher.phase == .running once → system.showAnimationTuner()
        // withExtendedLifetime((shell, delegate)) { application.run() }
    }
}
// Info.plist (project.yml): LSUIElement stays true (the process starts as UIElement, no Dock flash, F12);
// NSSupportsSuddenTermination true (logout kills instead of asking, F18).
```

#### Release: `Scripts/release.sh` → a notarised, stapled disk image (R24)

```
xcodegen generate → archive (Release, Developer ID) → export → codesign --verify, Authority and runtime checks
→ ditto zip → notarytool submit --wait → stapler staple TrackpadLauncher.app
→ hdiutil create -srcfolder <staging: app + "Applications" symlink + .background/dmg-background.png> -format UDRW
→ hdiutil attach → osascript: Finder sets icon view, background picture, icon positions (app left, Applications
  right), window bounds → hdiutil detach → hdiutil convert -format UDZO → codesign -s "Developer ID Application" dmg
→ notarytool submit dmg --wait → stapler staple dmg → stapler validate → spctl --assess the app → build/release/TrackpadLauncher.dmg
```
The app is stapled before it goes into the image and the image is stapled after, so both carry tickets offline
(F39). The drag cue is a committed `assets/dmg-background.png` and Finder-set positions; no third-party tool.

#### The test seam

Requirement scenarios run at `World`: the real `Launcher` over the in-memory adapters, now including `InMemoryPeers`
(records `stopAll` calls; `allEnded()` delivers the push) and `InMemoryInstaller` (records installs, opens and ejects;
`finish(_:)` delivers the outcome). `RecordingSystemActions` gains `isLoginItemEnabled` state with registration and
unregistration logs and the existing `onRegisterLoginItem` hook for ordering. `World.launch(_:)` and
`World.relaunch(_:)` take a `Launch`; fixtures `Launch.byHand(from:peers:)`, `.atLogin(peers:)`, `.development`.
Nothing in the model waits on a clock: every signal a test cannot provoke for real is a fake's method. Platform
tests: `LaunchEvent.how` over constructed descriptors; `CodeSignature.isDeveloperIDSigned(at:)` over the test binary
(false, F7); `BundleInstall.perform` over temp roots (copy, replace, read-only source, leftover cleanup, quarantine
cleared); `FrontmostApp` over posted activation notifications, as `RunningAppsReaderTests` already does. Manual: a
real login launch, logout with the window open, the Dock's Quit, the administrator prompt on a standard account, a
quarantined notarised image, Escape over an open picker.

#### Module map

- **LauncherCore**: `Lifecycle` (`Launch`, `LaunchPlan`, `Phase`, `WindowState`, `TerminationRequest`, `Copy`,
  `Peer`, …), `Settings.isLoginItemSuspended`, `Ports` (+ `Peers`, `Installer`, login item on `SystemActions`),
  `Launcher` (`launch`, `answerMoveDialog`, `quit`, `terminationRequested`, `openWindow`, `closeWindow`), `Copy`
  strings for the dialog.
- **LauncherPlatform**: `LaunchFacts`, `LaunchEvent`, `CodeSignature`, `BundlePlace`, `RunningCopies`, `QuitEvents`,
  `AppInstaller` + `BundleInstall` + `PrivilegedInstall` + `DiskImages`, `FrontmostApp`, `WorkspaceActions` login item.
- **LauncherUI**: `SettingsWindowShell`, `SettingsWindow`, `MainMenu`, `MoveDialog`, `LauncherActions`,
  `LauncherView` (Quit button); `MenuBarShell`, `LauncherPanel`, `StatusIcon` deleted.
- **App target**: `AppDelegate`, `TrackpadLauncherApp`.
- **Scripts**: `release.sh`; `assets/dmg-background.png`.

#### Docs and the source scan

- `docs/domain-model.md`: *Trackpad Launcher* ("a macOS background app…"); *Launcher window* → *Settings window*
  (opened by opening the app; the Dock shows the app while it is open; the Quit button ends it); every "launcher
  window" mention; *Frontmost app* (drop "Trackpad Launcher is active only when…"; add "while Trackpad Launcher is
  active, the app that was in front before it"); *Swap* and *Launch animation setting* (no window closes). New
  entries: *Starting at login* (on from the first run from /Applications; Quit turns it off and the next open by hand
  turns it back on; the user's Login Items choice stands), *Move to Applications* (the dialog, the copy, the
  replacement, the disk image), *Development build* (not Developer ID signed; never moves), *Release disk image*.
- `docs/architecture.md`: §Shape LauncherUI "settings window shell"; §Concurrency the first icon pass's owner
  (`SettingsWindowShell`) and "two pushes the lifecycle waits on: other copies ending, the install finishing";
  §Privacy the NSEvent monitors sentence loses the outside-click monitor; "no files written other than settings" gains
  "and, when the user asks, its own bundle copied into /Applications"; §Distribution "a notarised, stapled disk
  image"; the module list adds Security (code signature, authorization) and DiskArbitration.
- `docs/performance.md:8`: quitting other copies by hand becomes "opening the perf build stops any other copy".
- `docs/product-overview.md:3`: the menu bar sentences and the image reference.
- `SourcePolicyTests`: drop `MenuBarShell.swift` from `addGlobalMonitorForEvents`; confine `SMAppService` →
  `WorkspaceActions.swift`; `setActivationPolicy` → `SettingsWindowShell.swift`; `SecCode`, `SecRequirement` →
  `CodeSignature.swift`; `SecTranslocate`, `statfs`, `DADisk` → `BundlePlace.swift`; `AuthorizationExecuteWithPrivileges`,
  `AuthorizationCreate` → `PrivilegedInstall.swift`; `copyItem(`, `replaceItemAt(` → `BundleInstall.swift`;
  `unmountAndEjectDevice`, `unmountVolume` → `DiskImages.swift`; `currentAppleEvent` → `LaunchEvent.swift`,
  `QuitEvents.swift`; `.terminate(` → `RunningCopies.swift`, `SettingsWindowShell.swift`; `runModal` → `MoveDialog.swift`.

### Synthesis decision

### Tradeoffs accepted

- We accept one more persisted field, `isLoginItemSuspended`, in exchange for never having to tell "the user turned
  it off" from "Quit turned it off" through `SMAppService.Status`, whose semantics after a user's change are disputed.
  It is not a second "launched before" boolean: it records an action of ours, and a crash at any point converges.
- We accept that a development build opened by hand stops the installed copy, in exchange for one rule ("a by-hand
  open wins") and R2's "at most one recognises gestures"; a developer who wants the installed copy back opens it.
- We accept that a development build's first run outside /Applications never registers for login, and consumes the
  first run for the shared defaults domain, in exchange for not registering DerivedData paths; this affects only the
  developer's Mac.
- We accept that the mover idles in `.replaced` until the installed copy stops it, in exchange for ejecting the disk
  image deterministically from the one process that can (the installed copy, after the mover's executable is no
  longer mapped), with no arguments passed between processes and no delay.
- We accept the Dock icon showing while the move dialog is up (the alert needs the app active), since R18 forbids only
  gestures, prompts, registration and the settings window.
- We accept `AuthorizationExecuteWithPrivileges` through `dlsym`, deprecated but exported (F32), in exchange for the
  Finder-style prompt without the restricted Privileged File Operation entitlement (F31).
- We accept that a peer that refuses to quit leaves the new copy waiting with nothing on screen, in exchange for no
  timers; today's menu bar version has no delegate and always quits (F20), and this version honours `.peer`.
- We accept the login tiebreak by pid for the two-registrations edge in exchange for a deterministic outcome where
  "everyone stops everyone" would leave nothing running.

### Alternatives considered

- **Lifecycle policy in the app delegate and shell, `Launcher` untouched.** Smallest diff and the shape LetsMove
  takes. Lost: the launch table, the quit classification and the login bookkeeping would live where no test runs
  (LauncherUI has no test target, the app target is only scanned), and the first-run rule would be split across two
  objects. It hides nothing from a reader who must trace both.
- **A separate `@Observable ProcessLifecycle` model beside `Launcher`.** Cleaner file sizes. Lost: the start, the
  first run, the login item and the window are one invariant (`isFirstLaunch`, `settings`, `window`), and two owners
  of it need a protocol between them that is as wide as the thing it splits.
- **`#if DEBUG` as the development-build rule.** Trivial. Lost: it calls the perf build a release and would make it
  move itself out of `build/perf` (F8); the signature rule matches R23's own definition.
- **Hand the disk image to the installed copy as a launch argument.** Explicit. Lost: a second channel between
  processes and argument parsing at launch, when the fact is derivable from the peer that ended.
- **`NSWorkspace.requestAuthorization(to: .replaceFile)`.** The public API. Lost: it needs an entitlement Apple grants
  on request (F31), and the project ships with none.
- **Register on every by-hand start from /Applications when status is `.notRegistered`.** No persisted field. Lost:
  `.notRegistered` may be what a user's removal in Login Items reads as (F25), which would re-enrol them (R13).

### Open questions and risks

- Does an `SMAppService.mainApp` login launch on macOS 26 carry `keyAELaunchedAsLogInItem` (open question 1)? The
  fallback is the sender rule in `LaunchEvent.how`; should the first slice's acceptance be a real logout and login
  before any other lifecycle work lands?
- Does `SMAppService.mainApp.status` read `.enabled` again after the user turns the item back on in Login Items, so
  that Quit then sees it on (R13's third scenario)? And is the main-app service identified by path or by bundle id,
  which decides whether a copy outside /Applications reads the installed copy's status? The design converges either
  way, but which one should the manual check record?
- Is a Developer ID, notarised, stapled app opened from a quarantined disk image translocated (F38), and does the
  Accessibility grant survive the copy into /Applications? If the grant does not follow, should the first run from
  /Applications after a move ask again, which R5's "later runs never ask" forbids as written?
- Should "installed" accept a subfolder of /Applications (`/Applications/Utilities/…`)? The sketch says directly
  inside; a user who files apps into folders would be asked to move every time.
- Is a window title of "Trackpad Launcher" right, or should it read "Settings"?
- With `NSSupportsSuddenTermination` the system may kill the mover during the copy at logout; the install disables
  sudden termination for its duration, and an interrupted copy leaves only the `.installing` sibling, removed by the
  next install. Acceptable?
- `NSAlert.runModal` for the move dialog: does a peer's `terminate()` reach `applicationShouldTerminate` while the
  modal loop runs, so a newer copy can replace a copy stuck on its dialog? If not, the Finder-replace scenario needs
  the dialog as a sheet on an invisible window.
- The administrator path cannot be exercised on this Mac (F36). Who runs it on a standard account before release?
- There is no app icon (open question 9): the Dock, the move dialog and the disk image show the generic icon.

### Next implementation step

Add `Lifecycle.swift` to LauncherCore with `Launch`, `LaunchPlan`, `Phase`, `WindowState` and `TerminationRequest`,
and write the launch-table test over `Launch.plan` before giving `Launcher` its `launch(_:)`.
