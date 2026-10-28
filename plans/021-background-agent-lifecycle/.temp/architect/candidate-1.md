## Design

### Problem

Today the whole lifecycle is one first-launch branch in `Launcher.start()`. Plan 021 needs every process to decide for itself, as it starts or is opened again, between five outcomes: run gestures silently, run them and open the settings window, replace other running copies first, ask to move, or end. It also needs gestures to keep working while the app's own ordinary, activating window is in front. The grounding fixes the constraints:

- The login marker can be read only in `applicationDidFinishLaunching` (F1, F2), so nothing can be decided before the run loop starts.
- The gesture adapters start sensing in their `init`s (F11), so a copy that only asks to move must never build them. A copy that already runs gestures must still be able to ask (R18, last scenario).
- LaunchServices already turns a same-build, same-place open into a reopen, so every second process is a different build or a different place (C1).
- A peer's `terminate()` looks exactly like the Dock's Quit (F15, F16), and the menu bar version vetoes nothing (F20).
- First run means no `settings` record, and its effects come before the first save (F10, Preserve 1).
- No timers, no polling, no sleeps (F37). `LauncherCore` imports Foundation and Observation only. Every port has a real and an in-memory adapter.
- The five own-pid filters keep Trackpad Launcher out of `apps`, but they make `frontmost == nil` whenever it is active (F26, F27).

### Usage (caller's view)

There is one process-level owner, `Lifecycle`. The AppKit delegate forwards four AppKit signals to it, builds the gesture model only when `Lifecycle` asks for one, and does nothing else. The settings window talks to `Launcher` as it does today, plus one Quit closure.

```swift
// TrackpadLauncher/TrackpadLauncherApp.swift: the composition root and the only NSApplicationDelegate.
@main enum TrackpadLauncherApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var lifecycle: Lifecycle!
    private var shell: SettingsShell?
    private var moveDialog: MoveDialogPresenter?
    private let quitSignals = QuitSignals()          // remembers willPowerOff; classifies quit events
    private var event: NSAppleEventDescriptor? { NSAppleEventManager.shared().currentAppleEvent }

    func applicationWillFinishLaunching(_: Notification) {
        NSApp.disableRelaunchOnLogin()                 // R9: only the login item starts it at login (F3)
        let startAtLogin = StartAtLogin(item: SystemLoginItem(), defaults: .standard)
        lifecycle = Lifecycle(
            placement: ThisCopy.placement(), copies: SystemRunningCopies(), installer: ApplicationsInstaller(),
            startAtLogin: startAtLogin, makeLauncher: { [unowned self] in makeResident(startAtLogin) })
        moveDialog = MoveDialogPresenter(lifecycle: lifecycle)
    }
    func applicationDidFinishLaunching(_: Notification) {       // the open event exists only from here (F1)
        lifecycle.launched(ThisCopy.launch(event: event, arguments: CommandLine.arguments))
    }
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        lifecycle.openedAgain(ThisCopy.opening(of: event)); return false
    }
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        lifecycle.shouldEnd(quitSignals.request(for: event)) ? .terminateNow : .terminateCancel
    }

    private func makeResident(_ startAtLogin: StartAtLogin) -> Launcher {
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
            system: WorkspaceActions(), catalog: catalog, scanner: SystemAppScanner(catalog: catalog),
            store: SettingsStore(defaults: .standard), startAtLogin: startAtLogin)
        shell = SettingsShell(launcher: launcher, quit: { [unowned self] in lifecycle.quit() })
        return launcher
    }
}
```

The settings shell's own call sites:

```swift
func windowShouldClose(_: NSWindow) -> Bool { launcher.closeWindow(); return false }   // close button, ⌘W
override func cancelOperation(_: Any?) { onCancel() }                                   // Escape → launcher.closeWindow()
@objc func closeSettings(_: Any?) { launcher.closeWindow() }                            // app menu "Close Settings" ⌘Q
Button(Copy.quitButton, action: actions.quit)                                           // the red capsule, last in the view
```

A requirement scenario, run at the one high seam:

```swift
@Test func openingAnotherBuildByHandStopsTheRunningOneAndRunsOnlyOnceItHasExited() {
    let world = LifecycleWorld(placement: .settled, others: [.startedEarlier])
    world.lifecycle.launched(Launch(opening: .byHand))
    #expect(world.copies.stopped == world.copies.others)
    #expect(world.lifecycle.launcher == nil)          // R2: nothing of ours recognises gestures yet
    world.copies.letStoppedCopiesExit()               // the push the test withheld
    #expect(world.lifecycle.launcher?.isWindowOpen == true)
}

@Test func aCopyOutsideApplicationsAsksFirstAndItsQuitChangesNothing() {
    let world = LifecycleWorld(placement: .unsettled, others: [.startedEarlier])
    world.lifecycle.launched(Launch(opening: .byHand))
    #expect(world.lifecycle.moveDialog == .asking)
    #expect(world.residentsBuilt == 0 && world.copies.stopped.isEmpty)   // R18: the running copy keeps its gestures
    world.lifecycle.answer(.quit)
    #expect(world.copies.hasEnded && !world.hasSettingsRecord && world.loginItem.calls.isEmpty)
}
```

### Shape

**Data first.** A process is in exactly one `Lifecycle.Stage`. That private enum is the only record of what the process is doing, and `moveDialog` and `launcher` are derived from it (per model-the-domain, single source of truth). The facts it acts on are values parsed at the AppKit boundary: `Opening`, `Placement`, `Launch`, `QuitRequest` (per boundary-discipline). The settings window is `Launcher.SettingsWindow { closed, open(request:) }`. Each opening by hand increments the request, so a reopen of an open or minimised window still reaches the shell. Starting at login is owned by `StartAtLogin`, whose one remembered fact lives under its own `UserDefaults` key and not in the `settings` record. A move or a Quit writing that key therefore never creates or uses up a first run, and never races the model's saves (per separate-before-serializing-shared-state).

**Load-bearing decisions.**

1. **`Lifecycle` sits above and beside `Launcher`, and builds it lazily.** A copy that only asks to move never builds the gesture adapters. A resident copy can still show the dialog while its gestures run. The routing is short:
   - At login: silent, wherever the copy lies (R9, R22).
   - By hand, settled: replace the other copies, then run with the window open.
   - By hand, unsettled: the move dialog.

2. **`Placement` is one rule for R18 and R23.** A copy is `settled` when it sits directly in /Applications or is a development build anywhere. A copy is a development build when it fails the Developer ID requirement checked on itself (F7). The rule does not use `#if DEBUG` (F8), so the perf build also counts as development. A translocated copy reads as unsettled even when its original is in /Applications, so it re-installs itself without quarantine.

3. **Other copies are stopped, not asked.** `RunningCopies.stop` calls `forceTerminate()` and waits for KVO on `isTerminated` (with `.initial`), which is a push. A peer cannot refuse, hang, or be mistaken for the Dock's Quit, and no handshake ties versions together, the menu bar version included. A peer has nothing to flush, because every setting is saved when it changes (F21). The process starts gestures only after every peer has exited (R2).

4. **A login start never does first-run work.** The first run, meaning the first opening by hand on a Mac with no record, does it instead. `Launcher.start()` turns gestures on and asks, opens and saves nothing. `Launcher.openedByHand()` does the first-run setup or pays back starting at login once per process, then raises the window. At login, a copy that finds an older copy running ends silently, so two login starts converge on one whichever reads first.

5. **`StartAtLogin` has three intents.**
   - `enrol` on a first run.
   - `suspend` on Quit and on a move: if starting at login is on now, remember that, then unregister.
   - `resume` on any opening by hand: re-register only if remembered.

   The rule rests only on "is it `.enabled`", so it works whichever status macOS gives a user's choice (F25 is moot). A user's off is never on, so nothing is remembered and nothing is undone (R13). The crash order is: remember before unregistering, and register before forgetting. Every crash point converges on the next opening by hand (per make-operations-idempotent).

6. **The Dock follows the window, and only in the shell.** `SettingsShell` maps `settingsWindow`:
   - `.open(request:)`, newly opened: `.regular`, size to content, centre on `Displays.screen(under: NSEvent.mouseLocation)`.
   - `.open(request:)`, every time: de-miniaturise, `makeKeyAndOrderFront`, `NSApp.activate()`.
   - `.closed`: cancel any attached sheet, `orderOut`, `.accessory`.

   `LSUIElement` stays `true`, so a login start never flashes a Dock icon (F12). The window is an ordinary titled window at normal level with no monitors. `.heldOpen`, `dismissWindow()` and the four effect-closes are deleted (R7, R15).

7. **Quit.** Every ordinary way to quit (its menu, its Dock icon) exists only while the window is open. So `shouldEnd(.other)` closes an open window and refuses, and any quit while the window is closed ends the app. Logout with the window closed, the usual case, therefore can never be held up, whatever the unprobed signals do. With the window open, three layers apply:
   - `NSSupportsSuddenTermination = YES` lets the system kill the app without asking (F18).
   - `QuitSignals` classifies as `.system` any quit that carries `kAEQuitReason`, is sent by `com.apple.loginwindow`, or arrives after `willPowerOffNotification`.
   - The Quit button goes through `Lifecycle.quit()`: `suspend`, then `endThisCopy()`. The stage `.ending` lets AppKit's terminate through.

   This is no `terminate` closure in the model "without policy" (Preserve 5): Quit now carries policy.

8. **R15 frontmost.** The rule stays below the port, where self-exclusion already lives. While this process is the active app, `RunningAppsReader` reports as frontmost the first ⌘-Tab app. That order already drops this process by pid, so it holds the app that was in front before it, and Spotlight never counts. This is one pure function and needs no new state. `FrontmostAppWindows` is unchanged: while Trackpad Launcher is active, a slide up or down is no window swipe, because its windows sit behind the settings window.

9. **The move is ordered for crash convergence.** The order is fixed in `Lifecycle` and pinned by tests:
   1. Install. The installer stages the copy outside /Applications and gets the administrator's answer before touching anything. Swapping the staged copy into /Applications is the first change.
   2. Suspend starting at login.
   3. Remove the original.
   4. Stop the other copies, so the next open launches a fresh process that receives the eject argument.
   5. Open the installed copy.
   6. End.

   Cancel and failure change nothing (R21). The installed copy ejects the disk image only after the mover has exited.

10. **Release.** A single `Scripts/release.sh` builds a disk image that is notarised and stapled, and whose app is itself notarised and stapled.

**Depth.**
- `Lifecycle` has five intents and two derived reads. Behind them sit routing, replacement and its wait, the login tie-break, move sequencing and its crash order, the login hand-over and quit policy. The delegate knows nothing about copies, installs or login items.
- `StartAtLogin` has three intents. Behind them sit a key, an ordering and the meaning of macOS's errors.
- `Launcher`'s lifecycle surface shrinks: `openWindow`, `dismissWindow` and the first-launch branch become `openedByHand()`.
- Each port hides a real platform tangle behind two to four methods: `forceTerminate` plus KVO, translocation plus staging plus authorization plus an atomic swap, and `SMAppService` errors.

#### Type sketch: LauncherCore

```swift
// MARK: Lifecycle.swift: one process, from start to exit. Imports Foundation and Observation only.

/// How macOS started this process, or opened it again. Parsed from the open/reopen Apple event by `ThisCopy`.
public enum Opening: Equatable, Sendable {
    /// As a login item (`keyAELaunchedAsLogInItem` in the open event). Silent: no window, dialog or prompt.
    case atLogin
    /// Finder, Spotlight, Launchpad, the Dock, Xcode, or a move finishing: every opening that is not at login.
    case byHand
}

/// Where this copy lives, as it bears on an opening by hand. Read once, before anything runs.
public enum Placement: Equatable, Sendable {
    /// Directly in /Applications, or a development build anywhere: opened by hand, it runs here.
    case settled
    /// A release build anywhere else: a disk image, ~/Downloads, ~/Applications, a translocated copy.
    case unsettled

    public enum Build: Sendable { case release, development }
    /// R18 and R23 as one rule. `development` = not signed with Developer ID (F7), never `#if DEBUG` (F8).
    public init(build: Build, isDirectlyInApplications: Bool) {
        self = build == .development || isDirectlyInApplications ? .settled : .unsettled
    }
}

public struct DiskImage: Hashable, Sendable { public let volume: URL }

/// One process start.
public struct Launch: Equatable, Sendable {
    public var opening: Opening
    /// Only on the copy a move just installed: the disk image the mover ran from, ejected once it has exited.
    public var diskImageToEject: DiskImage?
    public init(opening: Opening, diskImageToEject: DiskImage? = nil) { fatalError("not implemented") }
}

/// What AppKit asks about in `applicationShouldTerminate`, as `QuitSignals` classifies it.
public enum QuitRequest: Equatable, Sendable {
    /// Logout, restart, shutdown: carried kAEQuitReason, came from loginwindow, or arrived after willPowerOff.
    case system
    /// The Dock's Quit, AppleScript, Activity Monitor's Quit, another app.
    case other
}

public enum MoveDialog: Equatable, Sendable {
    /// "Trackpad Launcher needs to be in the Applications folder": Move to Applications (default), Quit.
    case asking
    /// The move failed before /Applications changed: the reason, and Quit.
    case failed(reason: String)
}
public enum MoveAnswer: Sendable { case move, quit }
public enum InstallOutcome: Equatable, Sendable { case installed, cancelled, failed(reason: String) }

public struct CopyID: Hashable, Sendable { public let rawValue: Int32 }
/// Another running Trackpad Launcher process: any build, any place, the menu bar version included.
public struct RunningCopy: Hashable, Sendable {
    public let id: CopyID
    /// Launched before this process (launch date, then pid). At login, this process defers to such a copy.
    public let startedEarlier: Bool
}

/// The running Trackpad Launcher processes. Real: SystemRunningCopies. Test: InMemoryRunningCopies.
@MainActor public protocol RunningCopies: AnyObject {
    /// Every other process with this bundle identifier, read now.
    func others() -> [RunningCopy]
    /// Stops each at once without asking: a copy can neither refuse, nor ask its user, nor hang the stop. Calls
    /// `exited` once, on the main actor, when every listed copy has exited; synchronously when none still runs. The
    /// signal is the processes' own termination (KVO on isTerminated), never a wait or a poll.
    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void)
    /// AppKit's terminate for this process; `Lifecycle.shouldEnd` has already agreed (stage `.ending`).
    func endThisCopy()
}

/// Putting this copy into /Applications. Real: ApplicationsInstaller. Test: InMemoryInstaller.
@MainActor public protocol Installer: AnyObject {
    /// Copies this copy into /Applications, replacing any Trackpad Launcher there whatever its version, and asks for an
    /// administrator's name and password the way Finder does when this user cannot write there. /Applications holds the
    /// copy it held or this one, never a mix, whatever happens to this process. Nothing there changes unless the outcome
    /// is `.installed`. `done` runs once, on the main actor. The prompt and the copy can block; a test holds `done`.
    func install(then done: @escaping @MainActor (InstallOutcome) -> Void)
    /// Removes the copy the user opened (its original place when translocated), unless it is on a disk image or is the
    /// installed copy itself. A failure (a read-only share) leaves it there (R19).
    func removeOriginal()
    /// Opens the installed copy as by hand, passing the disk image to eject, if this copy came from one.
    func openInstalledCopy()
    /// Ejects it; returns at once. A file on it in use leaves it mounted (R19).
    func eject(_ diskImage: DiskImage)
}

/// This copy's login item (`SMAppService.mainApp`). Real: SystemLoginItem. Test: InMemoryLoginItem.
@MainActor public protocol LoginItem: AnyObject {
    /// `.enabled`: the next login starts this copy. Every other status (never registered, the user's off) is off.
    var isOn: Bool { get }
    /// True when registered afterwards, already-registered included; false when macOS refused (the user turned it off
    /// in Login Items, an unsigned build).
    @discardableResult func register() -> Bool
    /// This process keeps running. A no-op when not registered.
    func unregister()
}

/// Starting at login: the one owner of "Trackpad Launcher turns back on only what it turned off itself" (R5, R12, R13,
/// R20, R25). Its one fact is its own key in the app's defaults domain, beside the `settings` record, never inside it.
@MainActor public final class StartAtLogin {
    public init(item: any LoginItem, defaults: UserDefaults) { fatalError("not implemented") }

    /// The first run: turn it on and forget any stale debt. A user's earlier off stands: macOS refuses.
    public func enrol() { fatalError("not implemented") }      // item.register(); forget()

    /// Quit, or a move leaving this place: if it is on now, remember that Trackpad Launcher turned it off, then turn it
    /// off. Off already (the user's choice, or ours), nothing changes.
    public func suspend() {
        // guard item.isOn else { return }
        // remember()          // first: a crash before unregister leaves it on and remembered; resume converges
        // item.unregister()
        fatalError("not implemented")
    }

    /// Opened by hand: turn it back on only if Trackpad Launcher turned it off. The debt stays until macOS accepts.
    public func resume() {
        // guard isRemembered else { return }
        // if item.register() { forget() }   // register first: a crash before forget re-registers, harmlessly
        fatalError("not implemented")
    }
}

/// What this process does as it starts, is opened again and is asked to quit, and how it moves into /Applications.
@MainActor @Observable
public final class Lifecycle {
    /// Every legal situation of the process, and nothing else. Written only by the five intents and two callbacks.
    private enum Stage {
        case idle                                                       // before `launched`
        case replacingOthers(openedByHand: Bool, eject: DiskImage?)     // others stopping; nothing of ours senses
        case resident(Launcher)                                         // gestures run
        case askingToMove(resident: Launcher?)                          // dialog up; a resident keeps its gestures
        case moving(resident: Launcher?)                                // after Move, until the process ends
        case moveFailed(reason: String, resident: Launcher?)
        case ending                                                     // `endThisCopy` called; every quit goes through
    }
    private var stage: Stage = .idle

    /// Derived: the shell's move dialog presenter renders it.
    public var moveDialog: MoveDialog? { fatalError("not implemented") }   // .askingToMove → .asking, .moveFailed → .failed
    /// Derived: the gesture model once it runs (resident, asking, moving, failed); nil for a copy that only asks.
    public var launcher: Launcher? { fatalError("not implemented") }

    public init(
        placement: Placement, copies: any RunningCopies, installer: any Installer, startAtLogin: StartAtLogin,
        makeLauncher: @escaping @MainActor () -> Launcher
    ) { fatalError("not implemented") }

    /// Once, from applicationDidFinishLaunching. A second call does nothing.
    public func launched(_ launch: Launch) {
        // guard case .idle = stage
        // switch (launch.opening, placement) {
        // case (.atLogin, _):
        //     let others = copies.others()
        //     if others.contains(where: \.startedEarlier) { return end() }   // two login starts converge on the older
        //     replace(others, openedByHand: false, eject: launch.diskImageToEject)
        // case (.byHand, .settled):   replace(copies.others(), openedByHand: true, eject: launch.diskImageToEject)
        // case (.byHand, .unsettled): stage = .askingToMove(resident: nil)  // nothing built, sensed, asked, registered, saved
        // }
        fatalError("not implemented")
    }

    /// From applicationShouldHandleReopen.
    public func openedAgain(_ opening: Opening) {
        // guard opening == .byHand   // a login start reaching the running copy as a reopen opens nothing
        // switch stage {
        // case .replacingOthers(_, let eject): stage = .replacingOthers(openedByHand: true, eject: eject)
        // case .resident(let launcher):
        //     placement == .settled ? launcher.openedByHand()                 // R2: front, restored, focused
        //                           : (stage = .askingToMove(resident: launcher))   // R18: started at login elsewhere
        // default: break   // the dialog already shows (activation brings it forward), or the process is leaving
        // }
        fatalError("not implemented")
    }

    /// From applicationShouldTerminate.
    public func shouldEnd(_ request: QuitRequest) -> Bool {
        // switch stage {
        // case .ending: true
        // case .resident(let launcher):
        //     // Every ordinary way to quit exists only while the window is open (R8): close it, keep running.
        //     // With it closed, a quit is the system's or a script's: end, never hold up a logout.
        //     if request == .other && launcher.isWindowOpen { launcher.closeWindow(); false } else { true }
        // case .moving: request == .system
        // case .idle, .replacingOthers, .askingToMove, .moveFailed: true
        // }
        fatalError("not implemented")
    }

    /// The move dialog's buttons.
    public func answer(_ answer: MoveAnswer) {
        // (.askingToMove(r), .move) → stage = .moving(resident: r); installer.install { installed($0) }
        // (.askingToMove, .quit), (.moveFailed, _) → end()        // R18: nothing changed
        fatalError("not implemented")
    }

    /// The Quit Trackpad Launcher button (R11, R12).
    public func quit() {
        // guard launcher != nil; startAtLogin.suspend(); end()
        fatalError("not implemented")
    }

    private func replace(_ others: [RunningCopy], openedByHand: Bool, eject: DiskImage?) {
        // stage = .replacingOthers(...)                      // before stop: the callback may run synchronously
        // copies.stop(others) { [unowned self] in othersExited() }
        fatalError("not implemented")
    }

    private func othersExited() {
        // guard case .replacingOthers(let byHand, let eject) = stage
        // let launcher = makeLauncher(); launcher.start(); stage = .resident(launcher)
        // if byHand { launcher.openedByHand() }
        // if let eject { installer.eject(eject) }           // the mover has exited, so its volume is free
        fatalError("not implemented")
    }

    private func installed(_ outcome: InstallOutcome) {
        // guard case .moving(let resident) = stage
        // .cancelled → end()                                  // R21: nothing moved
        // .failed(r) → stage = .moveFailed(reason: r, resident: resident)
        // .installed:
        //     startAtLogin.suspend()        // hand over before the original goes: a crash between leaves it owed, never lost
        //     installer.removeOriginal()
        //     copies.stop(copies.others()) {                  // includes a copy running from the destination
        //         installer.openInstalledCopy()                // so this open always starts a fresh process (R19, R20)
        //         end()
        //     }
        fatalError("not implemented")
    }

    private func end() { /* stage = .ending; copies.endThisCopy() */ fatalError("not implemented") }
}
```

```swift
// MARK: Launcher.swift: the lifecycle-facing surface after the change (everything else as today)

@MainActor @Observable public final class Launcher {
    public enum SettingsWindow: Equatable, Sendable {
        case closed
        /// `request` counts openings by hand in this process. Each one makes the shell bring the window to the front with
        /// the keyboard focus, restoring it when minimised. Centring on the pointer's display happens only from `.closed`.
        case open(request: Int)
    }
    public private(set) var settingsWindow: SettingsWindow = .closed
    public var isWindowOpen: Bool { settingsWindow != .closed }

    /// `startAtLogin` replaces `SystemActions.registerLoginItem()`, which leaves the port.
    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore,
        startAtLogin: StartAtLogin
    ) { fatalError("not implemented") }

    /// Gestures on: wires the adapters, scans, reconciles. Asks nothing, opens nothing, saves nothing: all a login start
    /// does, so a first run waits for the first opening by hand. Call once.
    public func start() { fatalError("not implemented") }

    /// The user opened Trackpad Launcher. The first time in this process: on a first run (no `settings` record), turn
    /// starting at login on and ask for Accessibility when missing, then save: both before the first save (Preserve 1);
    /// on any other run, `startAtLogin.resume()`. Every time: `settingsWindow = .open(request: n + 1)`, rows, scan.
    public func openedByHand() { fatalError("not implemented") }

    /// Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running.
    public func closeWindow() { fatalError("not implemented") }

    // Deleted: openWindow(), dismissWindow(), Window.heldOpen, the grant ending a hold in reconcile(), and
    // `window = .closed` in fire, swipe, windowSwipe and swap (R15, R16, R17).
}
```

#### Type sketch: LauncherPlatform, LauncherUI

```swift
// ThisCopy.swift: facts about this process, parsed once into Core types. Confines the AE keys and SecCode*.
public enum ThisCopy {
    /// Directly in /Applications, plus SecCodeCopySelf against the Developer ID requirement F7 probed. A few ms, once.
    public static func placement() -> Placement { fatalError("not implemented") }
    /// The `oapp` of a start (read in didFinishLaunching, F1), plus `--eject-disk-image <path>` from a move.
    public static func launch(event: NSAppleEventDescriptor?, arguments: [String]) -> Launch { fatalError("not implemented") }
    /// A reopen: `.atLogin` only when it carries the login marker; otherwise `.byHand`.
    public static func opening(of event: NSAppleEventDescriptor?) -> Opening { fatalError("not implemented") }
}
@MainActor public final class QuitSignals {
    public init(workspace: NotificationCenter = NSWorkspace.shared.notificationCenter) { fatalError("not implemented") }
    public func request(for event: NSAppleEventDescriptor?) -> QuitRequest { fatalError("not implemented") }
    /// Pure; tested with built descriptors.
    static func request(hasQuitReason: Bool, senderBundleID: String?, afterPowerOff: Bool) -> QuitRequest {
        hasQuitReason || senderBundleID == "com.apple.loginwindow" || afterPowerOff ? .system : .other
    }
}

// SystemRunningCopies.swift: NSRunningApplication by bundle id minus own pid; forceTerminate; KVO isTerminated
// [.initial, .new]; endThisCopy = NSApp.terminate(nil). Confines forceTerminate and .terminate(.
// SystemLoginItem.swift: SMAppService.mainApp; status == .enabled; kSMErrorAlreadyRegistered → true. Confines SMAppService.

// ApplicationsInstaller.swift: the only code that writes outside UserDefaults. Confines every call below.
@MainActor public final class ApplicationsInstaller: Installer {
    public convenience init() { fatalError("not implemented") }   // Bundle.main.bundleURL, /Applications, the real prompt
    /// Tests: a temp dir for /Applications and a scripted administrator (granted, cancelled).
    init(running: URL, applications: URL, askAdministrator: @escaping @Sendable () -> AdministratorAnswer) { fatalError("not implemented") }

    public func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
        // TODO, off the main actor (a concurrent function; only `done` hops back):
        // 1. original = SecTranslocateIsTranslocatedURL ? SecTranslocateCreateOriginalPathForURL : running (dlsym, F34)
        //    diskImage = DADiskCopyDescription(original's volume) model "Disk Image" (F35)
        // 2. destination = this bundle ID's bundle directly in /Applications (LaunchServices), else /Applications/TrackpadLauncher.app
        // 3. staged = copyItem(running → itemReplacementDirectory appropriateFor: /Applications), then clear
        //    quarantinePropertiesKey on every item: an unquarantined copy is never translocated
        // 4. if /Applications or destination is not writable by this user: AuthorizationCopyRights(execute,
        //    interaction allowed); errAuthorizationCanceled → .cancelled (staged removed, nothing touched)
        // 5. swap: replaceItemAt(destination, withItemAt: staged), atomic; moveItem when there is none. With an
        //    administrator: AuthorizationExecuteWithPrivileges (dlsym, F32) "/bin/sh -c 'mv "$1" "$3" && mv "$2" "$1"
        //    && rm -rf "$3"' sh <destination> <staged> <aside>": paths as arguments, never interpolated; one rename's gap
        // 6. any error before the swap → .failed(localizedDescription), destination untouched
        fatalError("not implemented")
    }
    public func removeOriginal() { fatalError("not implemented") }       // removeItem unless disk image / destination
    public func openInstalledCopy() { fatalError("not implemented") }    // openApplication(activates, ["--eject-disk-image", path])
    public func eject(_ diskImage: DiskImage) { fatalError("not implemented") }  // unmountVolume(.allPartitionsAndEjectDisk) { _ in }
}

// RunningAppsReader.swift (changed): frontmost = Self.frontmost(activePID:activeEntry:ownPID:apps:).
/// Never this process. While it is active (its settings window in front), the app that was in front before it: the first
/// ⌘-Tab app, an order this process never enters (LaunchServices drops its pid; the tracker never notes it). Pure.
static func frontmost(activePID: pid_t?, activeEntry: AppEntry?, ownPID: pid_t, apps: [AppEntry]) -> AppEntry? {
    guard let activePID else { return nil }
    return activePID == ownPID ? apps.first : activeEntry
}

// LauncherUI
/// The settings window, its Dock icon and main menu, and the switchers' presenters. Renders `launcher.settingsWindow`;
/// the only caller of setActivationPolicy: .regular exactly while the window is open, minimised included (R6).
/// Main menu: the app menu with "Close Settings" ⌘Q in Quit's place (R8); Window: Minimize ⌘M, Close ⌘W.
public final class SettingsShell: NSObject, NSWindowDelegate {
    public init(launcher: Launcher, quit: @escaping () -> Void) { fatalError("not implemented") }
}
/// Renders `lifecycle.moveDialog` as an NSAlert (activating the accessory app first, no Dock icon) and answers it.
public final class MoveDialogPresenter {
    public init(lifecycle: Lifecycle) { fatalError("not implemented") }
}
```

#### Module map

| Module | Change |
|---|---|
| LauncherCore | **New** `Lifecycle`, `StartAtLogin`, the value types above, and the `RunningCopies`, `Installer` and `LoginItem` ports. **Changed** `Launcher`: `start()`, `openedByHand()`, `closeWindow()`, `settingsWindow`. `SystemActions.registerLoginItem` is removed. `Copy` gains the move dialog strings and the Quit label. The `RunningApps.frontmost` doc is updated. |
| LauncherPlatform | **New** `ThisCopy` (with `QuitSignals`), `SystemRunningCopies`, `SystemLoginItem`, `ApplicationsInstaller`. **Changed** the `RunningAppsReader` frontmost rule and the stale "never active" comments. `WorkspaceActions` loses `SMAppService`. |
| LauncherUI | **Replaced** `MenuBarShell` with `SettingsShell`, `LauncherPanel` with `SettingsWindow`, and `LauncherView` with `SettingsView`, which ends with the Quit button: `.glassProminent`, `.tint(.red)`, capsule, regular size, right-aligned (R10). Other… becomes `beginSheetModal(for:)` (R16). `openSettings` only opens the pane (R17). **New** `MoveDialogPresenter`. **Deleted** `StatusIcon`. `SwitcherPresenter.dockLocation` gains the own-pid filter. |
| App target | `AppDelegate`, as in Usage. DEBUG: the animation tuner opens only on an opening by hand and never drives the Dock (Risk 8). |
| `project.yml` | Keeps `LSUIElement: true`. Adds `NSSupportsSuddenTermination: true`. The version is stamped by `release.sh`. |
| Tests | `LifecycleWorld`: a real `Lifecycle` building a real `Launcher` over the existing in-memory adapters, plus `InMemoryRunningCopies` (others, `stopped`, `letStoppedCopiesExit()`, `hasEnded`), `InMemoryInstaller` (holds `done`; records `removeOriginal`, `openInstalledCopy` and `eject` in one ordered log shared with the login item) and `InMemoryLoginItem` (`isOn` is settable to stand for the user's Login Items choice). The flipped tests listed in `how.md` are updated. Platform tests: `ThisCopy` parsing with built descriptors (the login marker, `kAEQuitReason`), `Placement`, an ad-hoc test binary that reads as development, the pure frontmost rule, and `ApplicationsInstaller` against temp dirs (staging, quarantine cleared, atomic replace, a read-only original left in place, a cancelled administrator changes nothing). |

**The test seam is `Lifecycle`, with `Launcher` behind it.** Every R2-R5, R9, R11-R14 and R18-R23 scenario runs there. The tests hold a handle on every signal they cannot produce for real:

- How a process was opened is passed in as a value.
- Peers exiting is held back and released by the test.
- The administrator prompt and the copy are held by not calling `done`.
- Dialog answers, quit requests and the user's Login Items choice are values.
- No clock is needed, because nothing in the design waits on time. These are checked by hand and recorded in each slice's acceptance: a real login start (F2), logout and restart with the window open (F17-F19), the Dock's real Quit, a Finder drag over a running copy, Escape inside an open picker (F45), a quarantined disk image and a translocated move (F38), a standard account's prompt (F36), the eject, and notarisation.

**Requirement coverage.**

| Requirements | How the design covers them |
|---|---|
| R1 | `StatusIcon` and the status item are deleted. |
| R2, R3, R4 | LaunchServices sends a reopen to `openedAgain`. Any second process replaces the other copies and then runs. |
| R5 | `openedByHand` on a first run. |
| R6, R7 | `SettingsShell`. |
| R8 | Window intents and `shouldEnd`. |
| R9, R22 | `.atLogin` is silent, together with `disableRelaunchOnLogin`. |
| R10, R11 | The Quit button calls `Lifecycle.quit`. |
| R12, R13, R25 | `StartAtLogin`. |
| R14 | `mainApp` is never relaunched (F23). |
| R15, R16, R17 | No effect closes the window, plus the frontmost rule, the sheet and the panes. |
| R18-R21 | The move. |
| R23 | `Placement`. |
| R24 | `release.sh`. |

**`release.sh` (R24).** The script runs these steps:

1. Preflight: a Developer ID identity, `NOTARY_PROFILE` and xcodegen.
2. `xcodegen generate`.
3. Archive and export with the developer-id method.
4. Verify the signature authority and the runtime flag.
5. Notarise the app as a zip and staple it, so a dragged-out copy opens offline.
6. Stage `TrackpadLauncher.app` beside an `Applications` symlink and `.background/arrow.png`.
7. `hdiutil create -format UDRW`, attach it, and lay it out with a Finder `osascript` (icon view, 128 pt icons, the background with its drag arrow, both icon positions).
8. Detach, then `hdiutil convert -format ULFO`.
9. `codesign --timestamp` the image.
10. `notarytool submit --wait` the image, then `stapler staple` and `stapler validate` it.
11. `spctl --assess --type open --context context:primary-signature`.

The output is `build/release/TrackpadLauncher.dmg`. No `--deep` signing and no entitlements, per the distribution rules (F41).

**Docs and the source scan.**

`docs/domain-model.md`:
- *Launcher window* becomes *Settings window* in the heading and all ten mentions, rewritten as an ordinary window that closes only by its own controls and ends with the Quit button.
- *Trackpad Launcher* is "a macOS background app; in the Dock only while its settings window is open".
- *Frontmost app*: while Trackpad Launcher is active, the app that was in front before it, meaning the most recently used running app, with no window swipe; the "never active" sentence goes.
- *Swap* and *Launch animation setting* lose "the launcher window closes".
- New entries: *Opened by hand* / *Login start*, *First run*, *Starting at login*, *Move dialog*, *Development build*, *Quit Trackpad Launcher*.

`docs/architecture.md`:
- Shape: two observable models. `Lifecycle` owns process start, reopen, quit and the move, and builds `Launcher`. "At most one Trackpad Launcher runs gestures: an opening by hand stops every other copy and waits for their exit."
- LauncherUI is described as "settings window shell and move dialog".
- Platform gains Security (code signature, Authorization, two private translocation functions via dlsym) and DiskArbitration.
- Concurrency: the first scan and icon pass run "before gestures run and before the window can show". The push list gains Apple events, copies' termination, `willPowerOff`, the installer's and the eject's completions.
- Privacy: the outside-click monitor goes. "No files written other than settings in UserDefaults, and the app's own bundle into /Applications when the user chooses Move to Applications."
- Distribution: a notarised, stapled disk image.

`docs/performance.md:8`: opening the perf build stops other copies by itself; the "menu window" wording is updated.

`docs/product-overview.md`: per plan line 15.

`SourcePolicyTests` changes:
- Drop `MenuBarShell.swift` from `addGlobalMonitorForEvents`.
- Confine `SMAppService` to `SystemLoginItem.swift`.
- Confine `forceTerminate` and `.terminate(` to `SystemRunningCopies.swift`.
- Confine `setActivationPolicy` to `SettingsShell.swift`.
- Confine `disableRelaunchOnLogin` to `TrackpadLauncherApp.swift`.
- Confine `keyAELaunchedAsLogInItem`, `kAEQuitReason` and `SecCodeCopySelf` to `ThisCopy.swift`.
- Confine `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights`, `SecTranslocate`, `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `unmountVolume` and `quarantinePropertiesKey` to `ApplicationsInstaller.swift`.

### Synthesis decision

### Tradeoffs accepted

- We accept stopping other copies with `forceTerminate()`, with no teardown, in exchange for a stop that cannot be refused, hung, or confused with the Dock's Quit, and no protocol between versions. Nothing needs saving (F21).
- We accept that two settled copies opened by hand at the same instant stop each other, and the user opens it again. In exchange we have no election or lock. At login, where simultaneous starts are real, the older copy wins.
- We accept that while Trackpad Launcher is active the frontmost app is the most recent ⌘-Tab app, so a menu bar app that was in front is not it, and a slide is no window swipe. In exchange we need no new state, and Spotlight never counts as the app before it.
- We accept that a login start does no first-run work: the first opening by hand does. In exchange, login is always silent, even with no record.
- We accept that a development build stops the installed copy and, on a first run, registers its own path, as today. In exchange R2 holds strictly and one rule decides placement.
- We accept that any quit while the settings window is closed ends the app (AppleScript, Activity Monitor). In exchange a logout can never be held up in the common case.
- We accept a deprecated `AuthorizationExecuteWithPrivileges`, resolved by `dlsym`, and a one-rename gap in the privileged swap. In exchange the admin prompt looks like Finder's, with no entitlement and no helper.
- We accept a second key in the defaults domain. In exchange each key has one writer, and a move never spends a first run.

### Alternatives considered

- **Decide in the AppKit delegate with pure helpers, and drop `Lifecycle`.** The interface is smaller, but the sequencing would live in the untested app target (Risk 9): wait for peers before sensing, ask before building, and install before handing over login. That sequencing is exactly what R2, R18 and R21 hinge on.
- **Fold the lifecycle into `Launcher`, started lazily.** This keeps a single model, but `Launcher` exists only with its sensing adapters (F11). A copy that only asks must not build them, while a resident must still ask. The owner of the decision has to exist before the gesture model and beside it.
- **Hand off with a quit Apple event that the running copy honours from a peer.** This exposes a sender-pid protocol to every future version, depends on unprobed sender resolution, and leaves the new copy waiting forever on a hung or refusing peer, with no timeout allowed.
- **Derive "Quit turned it off" from `.notRegistered` on a later run.** This removes the key, but it cannot be told apart from a failed registration, a path move or a removal from the list (F25).
- **Remember the last non-self activation for R15.** The open by Spotlight itself would become "the app before".

### Open questions and risks

1. Does an `SMAppService.mainApp` login start on macOS 26 carry `keyAELaunchedAsLogInItem` (F2)? R9 and R22 rest on it. If it does not, should the login item become `SMAppService.agent` with a `--launched-at-login` argument? That change stays behind `LoginItem` and `ThisCopy` and changes nothing else.
2. Should a development build stop the installed copy (R2 over convenience), and register its DerivedData path on a first run? This design answers yes to both.
3. Is "the most recently used ⌘-Tab app, and no window swipe while Trackpad Launcher is active" an acceptable reading of R15 and the glossary?
4. With the settings window open at logout, do sudden termination, `kAEQuitReason`, the loginwindow sender or `willPowerOff` arrive as assumed (F17-F19)? This needs an E2E check before release.
5. Does Background Task Management key a main-app item by path or by bundle ID? This decides whether a Finder replace keeps it (R25), and whether a move's hand-over makes macOS show "login item added" again.
6. Should the disk image's layout come from a Finder script at release time, or from a committed `.DS_Store`? Who supplies the app icon, now that the Dock and the image show it?
7. Is it acceptable that a translocated copy sitting in /Applications shows the move dialog in order to re-install itself without quarantine?

### Next implementation step

Write LauncherCore's `StartAtLogin` and `Lifecycle` against the in-memory `LoginItem`, `RunningCopies` and `Installer` with a `LifecycleWorld`, test-first from the R2-R4, R9, R12-R14 and R18-R23 scenarios. In parallel, a signed build probes the login marker on a real logout and login.
