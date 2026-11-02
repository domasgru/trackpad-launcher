# Grounding: lifecycle (Lifecycle model, composition root, app delegate)

Repo root: /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates
All paths below are relative to it. Facts only; no recommendations.

## Components Found

| Name | File | What it is |
|---|---|---|
| `TrackpadLauncherApp` (`@main` enum) | TrackpadLauncher/TrackpadLauncherApp.swift:6-13 | Creates `AppDelegate`, sets it as `NSApplication.shared.delegate`, runs the app. No SwiftUI `App`. |
| `AppDelegate` | TrackpadLauncher/TrackpadLauncherApp.swift:17-92 | Composition root and only app delegate. Builds `Placement`, `StartAtLogin`, `Lifecycle`, `MoveDialogPresenter`; builds `Launcher` + `SettingsShell` lazily via `makeResident`. Forwards launch/reopen/terminate to `Lifecycle`. |
| `Opening` | LauncherKit/Sources/LauncherCore/Lifecycle.swift:5-10 | `.atLogin` / `.byHand`. |
| `Route` | Lifecycle.swift:13-26 | Pure table `(Opening, Placement, olderCopyRuns) -> .runSilently/.runWithWindow/.askToMove/.end`. |
| `Launch` | Lifecycle.swift:29-38 | One process start: `opening` + optional `diskImageToEject`. |
| `QuitRequest` | Lifecycle.swift:41-47 | `.system` (logout/restart/shutdown) / `.other` (Dock Quit, AppleScript, Activity Monitor, another app). |
| `CopyID`, `RunningCopy` | Lifecycle.swift:49-65 | Another running process with this bundle id; `id` is the pid; `startedEarlier` from a total order. |
| `StartAtLogin` | Lifecycle.swift:72-107 | Owner of "turn starting at login back on only if we turned it off"; one defaults key `startAtLoginTurnedOffByQuit`. |
| `MoveDialog`, `MoveAnswer`, `InstallOutcome` | Lifecycle.swift:110-121 | Move dialog states, answers, installer outcome (`installed`, `cancelled`, `failed(reason:)`). |
| `Lifecycle` | Lifecycle.swift:123-271 | `@MainActor @Observable` process model; private `Stage` state machine. |
| `Build`, `Location`, `DiskImage`, `Placement` | LauncherKit/Sources/LauncherCore/Placement.swift | Build kind, where the copy lies, and the derived placement rule. |
| `ThisCopy` | LauncherKit/Sources/LauncherPlatform/ThisCopy.swift | Parses the open/reopen Apple event, the `--eject-disk-image` argument, and the location (translocation via dlsym'd `SecTranslocate*`). |
| `CodeSignature` | LauncherKit/Sources/LauncherPlatform/CodeSignature.swift | Developer ID requirement check of this process (`buildOfThisProcess`) and of a bundle on disk (`build(of:)`, internal). |
| `SystemRunningCopies` | LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift | Real `RunningCopies`: lists, force-terminates and observes exit of other copies; ends this copy via `NSApp.terminate`. |
| `QuitSignals` | LauncherKit/Sources/LauncherPlatform/QuitSignals.swift | Classifies the quit Apple event into `QuitRequest`. |
| `SystemLoginItem` | LauncherKit/Sources/LauncherPlatform/SystemLoginItem.swift | Real `LoginItem` over `SMAppService.mainApp`. |
| `ApplicationsInstaller` | LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift | Real `Installer` (move into /Applications, remove original, open installed copy, eject). |
| `MoveDialogPresenter` | LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift | Observes `lifecycle.moveDialog`, runs an `NSAlert` modally, sends `lifecycle.answer(_:)`. |
| `SettingsShell` | LauncherKit/Sources/LauncherUI/SettingsShell.swift | Renders `launcher.window`; main menu with Close Settings (⌘Q); activation policy changes. |
| Ports `RunningCopies`, `LoginItem`, `Installer` | LauncherKit/Sources/LauncherCore/Ports.swift:150-186 | The three ports Lifecycle/StartAtLogin use. |

## Flow

### 1. Process start (applicationWillFinishLaunching) — TrackpadLauncherApp.swift:28-39
1. `NSApp.disableRelaunchOnLogin()` (line 30): macOS's "reopen windows at login" relaunch is disabled; only the login item starts it at login. Source policy confines this call to TrackpadLauncherApp.swift (SourcePolicyTests.swift:120-122).
2. `let location = ThisCopy.location()` (line 31) → ThisCopy.swift:22-35: `running = Bundle.main.bundleURL`; `original` = `SecTranslocateCreateOriginalPathForURL` result if `SecTranslocateIsTranslocatedURL` says translocated (both resolved by `dlsym(RTLD_DEFAULT)`, ThisCopy.swift:40-61; a missing symbol reads as "not translocated"); `isTranslocated` stored; `diskImage = DiskImages.image(holding: original)`.
3. `Placement(build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)` (lines 32-33).
4. `StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)` (line 34).
5. `Lifecycle(placement:, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location), startAtLogin:, makeResident: { [unowned self] in makeResident(startAtLogin) })` (lines 35-37).
6. `moveDialog = MoveDialogPresenter(lifecycle: lifecycle)` (line 38).

Note: `Build` is computed inline and only fed to `Placement`; the delegate keeps no `Build` value, and neither does `Lifecycle` (it stores only `placement`, Lifecycle.swift:141).

### 2. Build classification — CodeSignature.swift:7-39
- Requirement string (line 8-9): `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists` (Developer ID intermediate + Developer ID Application leaf).
- `public static func buildOfThisProcess(arguments: [String]) -> Build` (line 14): `SecCodeCopySelf` + `SecCodeCheckValidity(me, [], requirement)`; success → `.release`. Otherwise `arguments.contains("--as-release-build") ? .release : .development` (line 21). So a development build launched with `--as-release-build` reads as release; a release build ignores the argument.
- `static func build(of url: URL) -> Build` (line 26, internal, not public): `SecStaticCodeCreateWithPath` + `SecStaticCodeCheckValidity` with `kSecCSDoNotValidateResources`; unsigned/unreadable → `.development`. Doc: "Resources are not validated: a bundle edited after signing is still signed with a Developer ID." Used where? Only tests found in this pass (CodeSignatureTests.swift); see Open Questions.
- `Build` doc (Placement.swift:5): "Not signed with a Developer ID: Xcode, the perf build, an ad-hoc binary. Never `#if DEBUG`."
- SourcePolicyTests confines `SecCode`, `SecStaticCode`, `SecRequirement` to CodeSignature.swift (SourcePolicyTests.swift:111-113).
- Tests: LauncherKit/Tests/LauncherPlatformTests/CodeSignatureTests.swift: `theTestsOwnAdHocBinaryIsADevelopmentBuild` (l.10), `thisProcessIsReleaseOnlyWithTheExactArgument` (l.15), `everyAppInApplicationsIsReleaseExactlyWhenCodesignSaysDeveloperID` (l.35).

### 3. Location classification — Placement.swift:33-59
- `Placement.init(build:location:applications: URL = URL(filePath: "/Applications"))` (line 42):
  - `!location.isTranslocated && isInside(location.running, applications)` → `.installed` — **whatever the build** (a development build inside /Applications is `.installed`).
  - else `build == .development` → `.development`.
  - else → `.elsewhere` (disk image, ~/Downloads, ~/Applications, any translocated copy).
- `isInside` (lines 54-58): component-wise on `standardizedFileURL.pathComponents`, strictly deeper than the root → any depth inside /Applications (e.g. /Applications/Utilities); `/ApplicationsOld` is not inside; `..` resolved; trailing slash irrelevant.
- ~/Applications is not /Applications → `.elsewhere` (release) or `.development`.
- Translocated copy is never `.installed`, even if its original is in /Applications (PlacementTests.swift:36-42).
- Tests: LauncherKit/Tests/LauncherCoreTests/PlacementTests.swift (l.19-20: both builds in /Applications → `.installed`; l.32-33 elsewhere/development; l.36-42 translocation), LauncherPlatformTests/ThisCopyLocationTests.swift.

### 4. Start classification — ThisCopy.swift:9-18
- `applicationDidFinishLaunching` (TrackpadLauncherApp.swift:42-46) reads `NSAppleEventManager.shared().currentAppleEvent` (line 22) — the `oapp` event exists only from didFinishLaunching (comment line 41; ThisCopy.swift:6).
- `ThisCopy.launch(event:arguments:)`: `opening(of: event)` + `--eject-disk-image <volume>` → `DiskImage`. Any other argument ignored.
- `ThisCopy.opening(of:)`: `event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem` → `.atLogin`; otherwise and for nil → `.byHand`.
- Tests: LauncherPlatformTests/ThisCopyTests.swift (l.19-48).

### 5. Route table (what each combination does) — Lifecycle.swift:18-25
| Opening | Placement | olderCopyRuns | Route |
|---|---|---|---|
| atLogin | any | true | `.end` |
| atLogin | any | false | `.runSilently` |
| byHand | `.elsewhere` | any | `.askToMove` |
| byHand | `.installed` or `.development` | any | `.runWithWindow` |

`olderCopyRuns` = `others.contains(where: \.startedEarlier)` (Lifecycle.swift:181). By hand never defers to other copies; it stops them.

### 6. `Lifecycle.launched(_:)` — Lifecycle.swift:178-188
Guarded to run once (`guard case .idle`). Reads `copies.others()`, computes `Route`:
- `.end` → `end()` (stage `.ending`, `copies.endThisCopy()`).
- `.askToMove` → stage `.askingToMove(resident: nil)` — no `Launcher` is built, no other copy is stopped, no gestures.
- `.runSilently` / `.runWithWindow` → `replace(others, opensWindow: false/true, eject: launch.diskImageToEject)`.

`replace` (l.239-242): stage `.replacingOthers(opensWindow:eject:)` first, then `copies.stop(others) { othersExited() }` (stop may call back synchronously).

`othersExited` (l.244-252): guard still `.replacingOthers`; `launcher = makeResident()`; `launcher.start()`; stage `.resident(launcher)`; `if opensWindow { launcher.openedByHand() }`; `if let eject { installer.eject(eject) }`.

### 7. Building Launcher — TrackpadLauncherApp.swift:61-74 (`makeResident(_:)`)
Called only via the `makeResident` closure from `Lifecycle.othersExited`. Builds:
```
Launcher(hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
         system: actions /* WorkspaceActions() */, catalog: AppCatalog.system, scanner: SystemAppScanner(catalog: catalog),
         store: SettingsStore(defaults: .standard), startAtLogin: startAtLogin)
```
then `shell = SettingsShell(launcher: launcher, quit: { [unowned self] in lifecycle.quit() })` — the shell is built **before** `Launcher.start()` (comment l.59-60, SettingsShell.swift:7). DEBUG: stores `system = actions` and may show the animation tuner. The same `StartAtLogin` instance is shared by `Lifecycle` and `Launcher`.

`Launcher.start()` (Launcher.swift:98-115): wires hardware/scanner/preferences/permissions callbacks, scans, reconciles. "Asks nothing, opens nothing, saves nothing: all a login start does."

### 8. Opening the settings window — Launcher.swift:190-207
`Launcher.openedByHand()`:
- First time in this process (`openings == 0`): if first launch (no stored settings, `isFirstLaunch`, l.91) → `startAtLogin.enrol()`, ask Accessibility if missing, `store.save(settings)`; otherwise → `startAtLogin.resume()`.
- Every time: `openings += 1`; `window = .open(request: openings)`; `resolveRows()`; `scanner.scan()`.
- `Launcher.Window` (l.44-50): `.closed` | `.open(request: Int)`. `request` counts openings by hand in this process; a reopen while open moves `.open(request: n)` → `.open(request: n+1)` (no `.closed` in between).
- `isWindowOpen` (l.22): `window != .closed`.
- `closeWindow()` (l.207): `window = .closed`. Doc: "Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running."

`SettingsShell.render(_:)` (SettingsShell.swift:96-116) observes `launcher.window` via `Observations` (l.53-58): on `.open` from not shown (`isShown == false`): `setActivationPolicy(.regular)`, renderIcons, fit, centre; on every `.open`: deminiaturize, `makeKeyAndOrderFront`, `NSApp.activate()`. On `.closed`: end attached sheet, `orderOut`, `.accessory`. So the closed→open transition is distinguishable both in the model (`window` from `.closed`) and in the shell (`isShown`).

### 9. Opening again — TrackpadLauncherApp.swift:48-53
`applicationShouldHandleReopen(_:hasVisibleWindows:)` → `ThisCopy.opening(of: event)` (the `rapp` event; `.atLogin` only with the login marker) → `lifecycle.openedAgain(opening)` → DEBUG tuner → **returns `false`** (AppKit does no default reopen handling).

`Lifecycle.openedAgain(_:)` (Lifecycle.swift:191-198), computing `Route(opening, placement:, olderCopyRuns: false)`:
- `.replacingOthers` + `.runWithWindow` → keep waiting, but set `opensWindow: true` (keeps `eject`).
- `.resident(launcher)` + `.runWithWindow` → `launcher.openedByHand()` (window opens or comes to front).
- `.resident(launcher)` + `.askToMove` → stage `.askingToMove(resident: launcher)` (a login-started copy outside /Applications keeps its gestures while the dialog asks).
- everything else (atLogin reopen of a resident, any reopen while asking/moving/failed/ending/idle) → nothing.
There is no separate "open document"/"open URL" handler; the delegate implements only willFinishLaunching, didFinishLaunching, shouldHandleReopen, shouldTerminate.

### 10. Quit paths
- **Quit Trackpad Launcher button**: SettingsView.swift:53 `Button(Copy.quitButton, action: actions.quit)` → `LauncherActions.quit` (LauncherActions.swift:32-33) → closure from SettingsShell init → `lifecycle.quit()` (TrackpadLauncherApp.swift:68). `Lifecycle.quit()` (l.226-230): only in `.resident`; `startAtLogin.suspend()` then `end()`. The window stays `.open` (test `theQuitButtonEndsTheProcessAtOnceWithTheWindowOpen`, LifecycleTests.swift:148-157).
- **Close button / ⌘W / Escape**: SettingsView.swift:55 `launcher.closeWindow()`; `SettingsShell.windowShouldClose` → `launcher.closeWindow()`, returns false (SettingsShell.swift:66-69); `SettingsWindow.cancelOperation` → `onCancel` → `launcher.closeWindow()` (SettingsWindow.swift:7,29; SettingsShell.swift:33). Window menu "Close" is `performClose(_:)` ⌘W (SettingsShell.swift:89) → windowShouldClose.
- **Close Settings (⌘Q)**: app menu item `Copy.closeSettings` with keyEquivalent "q" and action `closeSettings(_:)` → `launcher.closeWindow()` (SettingsShell.swift:71, 74-83). There is no `terminate:` menu item at all.
- **Dock Quit / AppleScript / Activity Monitor Quit / other app**: sends a quit Apple event → `applicationShouldTerminate` (TrackpadLauncherApp.swift:55-57): `lifecycle.shouldEnd(quitSignals.request(for: event)) ? .terminateNow : .terminateCancel`. Only `.terminateNow` / `.terminateCancel` are used (never `.terminateLater`).
- `Lifecycle.shouldEnd(_:) -> Bool` (l.201-212):
  - `.ending`, `.idle`, `.replacingOthers`, `.askingToMove`, `.moveFailed` → `true`.
  - `.moving` → `request == .system` (an ordinary quit during the move's install is refused, the window is not touched).
  - `.resident(launcher)`: if `request == .other && launcher.isWindowOpen` → `launcher.closeWindow()`, return `false`; else `true` (a quit with the window closed always ends, so a logout is never held up).
- **Logout/restart/shutdown**: `QuitSignals.request(for:)` (QuitSignals.swift:22-33) → `.system` if the event has `kAEQuitReason` (attribute or param), or the sender pid (`keySenderPIDAttr`) is `com.apple.loginwindow`, or `NSWorkspace.willPowerOffNotification` was already observed (l.12-15). Otherwise `.other`. Plus Info.plist `NSSupportsSuddenTermination: true` (project.yml:40) lets the system kill without asking. No code calls `ProcessInfo.disableSuddenTermination` / `disableAutomaticTermination` (grep found none).
- **Ending this copy**: `Lifecycle.end()` (l.233-236) sets `.ending` first, then `copies.endThisCopy()` → `NSApp.terminate(nil)` (SystemRunningCopies.swift:47) → AppKit calls `applicationShouldTerminate` again synchronously → `.ending` → true. `.terminate(` is confined to SystemRunningCopies.swift (SourcePolicyTests.swift:131).
- **What turns starting at login off on Quit**: only `Lifecycle.quit()` (the button) calls `startAtLogin.suspend()`; Dock Quit/system quits do not. Also the move's `.installed` outcome calls `suspend()` (l.263).

### 11. Stopping other copies — SystemRunningCopies.swift
- "Another copy" = `NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")` minus own pid (l.10-20). Any build, any path (bundle id `com.domasgru.TrackpadLauncherApp`, project.yml:43; the comment at Lifecycle.swift:54 says "the menu bar version included").
- `startedEarlier` via `started(_:before:)` (l.67-70): launch date, nil date = `.distantFuture`, then lower pid. Tests: LauncherPlatformTests/RunningCopiesOrderTests.swift.
- `stop(_:then:)` (l.22-45): maps ids to `NSRunningApplication(processIdentifier:)`, drops already-terminated; empty → `exited()` synchronously. Otherwise for each: `app.forceTerminate()` then KVO `app.observe(\.isTerminated, options: [.initial, .new])`; on terminated, hops `DispatchQueue.main.async { MainActor.assumeIsolated { ... } }`, counts each pid once in `Remaining`; when count hits 0 → clears `watches`, calls `exited()`. No wait/poll/timer. Note `watches` is a single array, so a second concurrent `stop` call replaces the first's observations.
- `forceTerminate` is confined to this file (SourcePolicyTests.swift:129-130). A force-terminated copy gets no `applicationShouldTerminate`.

### 12. Starting at login — Lifecycle.swift:72-107 + SystemLoginItem.swift
- `StartAtLogin(item: any LoginItem, defaults: UserDefaults, placement: Placement)`; key `"startAtLoginTurnedOffByQuit"` in the app's defaults domain, beside (not inside) the `settings` record.
- `enrol()` (first run by hand): no-op for `.development`; `item.register()`; forget key.
- `suspend()` (Quit button, or a move): no-op for `.development` or when `!item.isOn`; set key true **then** `item.unregister()`.
- `resume()` (any non-first opening by hand, first time in the process): no-op for `.development` or key unset; `if item.register() { forget() }`.
- Note: `.development` placement means a development build **outside** /Applications; a development build inside /Applications is `.installed` and does touch the login item.
- `SystemLoginItem` (SystemLoginItem.swift): `isOn` = `SMAppService.mainApp.status == .enabled`; `register()` → `try SMAppService.mainApp.register()`, true on success or `kSMErrorAlreadyRegistered`; `unregister()` → `try? SMAppService.mainApp.unregister()`. `SMAppService` confined to this file; `SMAppService.agent/.daemon/.loginItem` and `SMLoginItemSetEnabled` banned (SourcePolicyTests.swift:66-69, 116).
- Tests: LauncherCoreTests/StartAtLoginTests.swift (quit off/next opening on; user-off readings; upgrade from menu bar version; kill-anywhere convergence; development build never touches it).

### 13. Move into /Applications (as it relates to Lifecycle) — Lifecycle.swift:215-270
- `answer(.move)` in `.askingToMove(resident)` → stage `.moving(resident:)`; `installer.install { installed($0) }`. `answer(.quit)` in asking, or any answer in `.moveFailed` → `end()`.
- `installed(.cancelled)` → `end()`; `.failed(reason)` → `.moveFailed(reason:resident:)`; `.installed` → `startAtLogin.suspend()`; `installer.removeOriginal()`; `copies.stop(copies.others()) { installer.openInstalledCopy(); end() }`.
- Comment l.254-256: the swap is the first change anywhere, the login item is handed over before the original can go, "and every other copy stops before the installed one opens, so that open always starts a fresh process."
- The installed copy then starts as a normal by-hand opening: Placement `.installed` → `.runWithWindow`; it lists the mover (if still alive) among `others()`, force-stops it, waits for exit, builds the resident, opens the window, ejects the disk image (test `theInstalledCopyEjectsTheMoversDiskImageOnlyAfterTheMoverHasExited`, ReplacingOtherCopiesTests.swift:108-121). Its first `openedByHand` runs `startAtLogin.resume()`, which re-registers the login item because the mover set the key (MoveToApplicationsTests.swift:131-159; log `["install", "unregister", "removeOriginal", "stop", "openInstalledCopy"]`).

### 14. "Open the installed copy" — ApplicationsInstaller.swift:39-47
```swift
public func openInstalledCopy() {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    if let diskImage = location.diskImage {
        configuration.arguments = ["--eject-disk-image", diskImage.volume.path]
    }
    NSWorkspace.shared.openApplication(at: Self.destination(of: location, in: applications), configuration: configuration)
}
```
- No completion handler; `createsNewApplicationInstance` is not set (grep found none anywhere).
- "Opens the installed copy as by hand" (Ports.swift:182-183): the opened process gets an `oapp` without the login marker → `.byHand` → `.runWithWindow` for an `.installed` placement → its settings window opens. There is no dedicated "open with settings window" flag/argument: the settings window opening is a consequence of `.byHand` + `.installed`. The only launch argument the app reads is `--eject-disk-image <volume>` (ThisCopy.swift:10), plus `--as-release-build` (CodeSignature.swift:21).
- `destination(of:in:)` (l.55-68): first bundle with this app's bundle id anywhere inside /Applications (direct child preferred, then same name, then shallowest), else `/Applications/<original name>`.
- `Installer` port also: `install(then:)`, `removeOriginal()`, `eject(_:)` (Ports.swift:173-186).

## Ports used by Lifecycle (all `@MainActor`, `AnyObject`, none `async`) — Ports.swift:150-186
```swift
@MainActor public protocol RunningCopies: AnyObject {
    func others() -> [RunningCopy]
    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void)
    func endThisCopy()
}
@MainActor public protocol LoginItem: AnyObject {
    var isOn: Bool { get }
    @discardableResult func register() -> Bool
    func unregister()
}
@MainActor public protocol Installer: AnyObject {
    func install(then done: @escaping @MainActor (InstallOutcome) -> Void)
    func removeOriginal()
    func openInstalledCopy()
    func eject(_ diskImage: DiskImage)
}
```
Completion is via callbacks, not async/await. `LoginItem` is used through `StartAtLogin`, not directly by `Lifecycle`. `makeResident: @MainActor () -> Launcher` is the fourth injected dependency.

Real adapters: `SystemRunningCopies`, `SystemLoginItem`, `ApplicationsInstaller` (its `install` runs a `@concurrent static func copy` in a `Task` and calls `done` on the main actor, ApplicationsInstaller.swift:22-30, 70-98).

In-memory adapters (LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift):
- `InMemoryLoginItem` (l.456-516): `isOn`, `isOffByUser`, `userOffReading` (`.refusesRegistering` / `.acceptsRegistering`), `calls`, `onRegister`, `onEffect`, `log`, `userTurnsOff/On`, `restore`.
- `EffectLog` (l.519-521): shared ordered `entries` of login item/copies/installer calls.
- `InMemoryInstaller` (l.524-~573): holds `done` until `release(_:)`; counts `installCalls`, `removeOriginalCalls`, `openInstalledCopyCalls`, `ejected`; `onInstalled`, `onEffect`, `isHolding`.
- `InMemoryRunningCopies` (l.575-620): `listed`, `stopped`, `alreadyExited` (fires inside `stop` like KVO `.initial`), `letExit(_:)`, `letStoppedCopiesExit()`, `deliverExitAgain()`, `hasEnded`; `endThisCopy()` calls `lifecycle?.shouldEnd(.other)` and sets `hasEnded` if true (mirrors AppKit asking again).

Test harness: LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift
- `LifecycleWorld` (l.8-87): one Mac (`World` with suite-backed defaults, `InMemoryLoginItem`, permissions), `launch(_ opening:, others:, alreadyExited:, placement: = .installed, diskImageToEject:) -> OneProcess`, `login(others:)` (only if login item on), `snapshot()`/`snapshots`/`init(restoring:)` for kill-anywhere convergence tests, `installedAt`.
- `OneProcess` (l.89-188): a real `Lifecycle` over the in-memory adapters, building a real `Launcher` (`residentsBuilt`, `history` of `Launcher.Window` after each intent), intent helpers `launch`, `openAgain`, `letExit`, `letStoppedCopiesExit`, `deliverExitAgain`, `closeWindow`, `shouldEnd`, `answer`, `releaseInstall`, `quit`, `tap`.
- `World.startAtLogin(item:suiteName:placement:)` (World.swift:118-125).
- `RunningCopy.earlier` (pid 100, startedEarlier), `.later` (300), `.tools` (400) in LifecycleTests.swift:197-201.

Test files: LifecycleTests.swift (launch/reopen/window/quit/system quit), ReplacingOtherCopiesTests.swift, MoveToApplicationsTests.swift, StartAtLoginTests.swift, PlacementTests.swift (core); ThisCopyTests.swift, ThisCopyLocationTests.swift, QuitSignalsTests.swift, RunningCopiesOrderTests.swift, CodeSignatureTests.swift, ApplicationsInstallerTests.swift (platform).

## Observable state of Lifecycle
- Observed: `private var stage: Stage` (l.140). Everything else `@ObservationIgnored` (l.141-145).
- Public derived: `launcher: Launcher?` (l.149-155; non-nil in `.resident`, and `.askingToMove/.moving/.moveFailed` with a resident; nil in idle/replacingOthers/ending) and `moveDialog: MoveDialog?` (l.158-164).
- Only `MoveDialogPresenter` observes Lifecycle in the app (`Observations({ lifecycle.moveDialog })`, MoveDialogPresenter.swift:12). Nothing in the app reads `lifecycle.launcher`; the delegate gets the `Launcher` through `makeResident` and hands it to `SettingsShell`. Tests read `lifecycle.launcher`.

## Files Read
- plans/022-in-app-updates/plan.md, plans/022-in-app-updates/development-logs.md (head)
- TrackpadLauncher/TrackpadLauncherApp.swift
- LauncherKit/Sources/LauncherCore/Lifecycle.swift, Placement.swift, Ports.swift (l.150-186), Launcher.swift (l.1-215)
- LauncherKit/Sources/LauncherPlatform/ThisCopy.swift, CodeSignature.swift, SystemRunningCopies.swift, QuitSignals.swift, SystemLoginItem.swift, ApplicationsInstaller.swift, RunningApp.swift
- LauncherKit/Sources/LauncherUI/SettingsShell.swift, MoveDialogPresenter.swift, SettingsView.swift (l.1-80), LauncherActions.swift, SettingsWindow.swift (grep)
- LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift, InMemoryAdapters.swift (l.456-620), LifecycleTests.swift (l.140-201), ReplacingOtherCopiesTests.swift, MoveToApplicationsTests.swift (parts), SourcePolicyTests.swift (l.1-200), World.swift (l.110-130), PlacementTests.swift (grep)
- LauncherKit/Tests/LauncherPlatformTests/*Tests.swift (test names only for QuitSignals, RunningCopiesOrder, ThisCopy, ThisCopyLocation, CodeSignature)
- project.yml (l.1-46), Config/Base.xcconfig, Config/Version.xcconfig
- docs/architecture.md (l.1-35 relevant rules), plans/021-background-agent-lifecycle/plan.md (grep hits)

## Boundaries
- In: AppKit delegate callbacks (willFinishLaunching, didFinishLaunching, shouldHandleReopen, shouldTerminate), `currentAppleEvent`, `CommandLine.arguments`, `Bundle.main.bundleURL`, code signature, `NSRunningApplication` lists and KVO termination, `NSWorkspace.willPowerOffNotification`, the move dialog's answers, the Quit button closure.
- Out: `Launcher` construction (+ `start()`, `openedByHand()`, `closeWindow()`, `isWindowOpen`), `forceTerminate` of other copies, `NSApp.terminate`, `SMAppService.mainApp` register/unregister, `NSWorkspace.openApplication` of the installed copy, file ops of the move (BundleInstall/PrivilegedInstall), disk image eject, defaults key `startAtLoginTurnedOffByQuit`.
- `Launcher` owns the window state; `Lifecycle` only asks it (`isWindowOpen`, `closeWindow()`, `openedByHand()`).
- `SettingsShell` only knows `Launcher` and a `quit` closure; it does not know `Lifecycle`.

## Non-Obvious Things
- **Placement does not encode release vs development inside /Applications.** `.installed` is "inside /Applications, not translocated, whatever the build" (Placement.swift:35, 43-44). The `Build` value is computed in the delegate (TrackpadLauncherApp.swift:33) and discarded after building `Placement`; neither `Lifecycle` nor `Launcher` holds it. "Release build in /Applications" is therefore not available from any existing stored value.
- **`--as-release-build`** makes a non-Developer-ID build read as `.release` (CodeSignature.swift:21). It exists to exercise release-only paths by hand without a certificate (plans/021 development-logs; plan 021 line 480/1061).
- **Settings window opening on a fresh process is not a flag**: it is `.byHand` + `.installed`/`.development` → `.runWithWindow`. `openInstalledCopy` relies on this; the only argument it passes is `--eject-disk-image`.
- **Reopen vs new launch**: `openInstalledCopy` uses `NSWorkspace.openApplication(at:configuration:)` with no `createsNewApplicationInstance`. In the move flow the target path is different from the running mover and all other copies are stopped first (Lifecycle.swift:254-256, 265-268) "so that open always starts a fresh process". If the target app is already running (for instance a process whose own bundle path is the target), LaunchServices' default would be to activate/reopen that running instance, which here would arrive as `applicationShouldHandleReopen` → `openedAgain(.byHand)` → `launcher.openedByHand()` in the existing process. Not tested by this code; behaviour with a bundle replaced in place under a running process is not verified anywhere in the repo.
- **The new copy stops the old one, not vice versa**: any by-hand opening force-terminates every other copy with the same bundle id (no version comparison) and waits for KVO `isTerminated` before building `Launcher`. Gestures in the old copy keep working until it is killed or ends itself. The order in the move flow: mover ends itself right after `openApplication` returns (no completion awaited); the new process may also find and force-kill it.
- **`forceTerminate` means the stopped copy runs no termination code** (no `applicationShouldTerminate`, no `StartAtLogin.suspend`).
- **Ordinary quit with the window open never quits**: Dock Quit / AppleScript quit while the window is open only closes it (`shouldEnd(.other)` → `closeWindow()`, false). With the window closed, any quit ends, so the Dock Quit cannot exist then anyway (accessory policy, no Dock icon).
- **`.moving` refuses `.other` quits without closing the window** (Lifecycle.swift:204); `.askingToMove` and `.moveFailed` accept any quit.
- **`quit()` works only in `.resident`** (Lifecycle.swift:227); in other stages the Quit button does nothing (it only exists in the settings window, which exists only with a resident).
- **Only the Quit button turns starting at login off**; Dock/system quits leave it on. The move also suspends it, and the next by-hand opening's first `openedByHand` resumes it via the defaults key. `resume()` runs only on the first opening in a process and only if not a first run.
- **Development placement leaves login items alone, but a development build in /Applications does not** (it is `.installed`).
- **Window request counter**: `Launcher.Window.open(request:)` increments on every opening by hand, including reopen while already open; "opened from closed" is the transition `.closed → .open`, which SettingsShell tracks with `isShown` (SettingsShell.swift:105-111).
- **`NSSupportsSuddenTermination: true`** (project.yml:40) and nothing disables sudden termination; the system may kill the app without calling `applicationShouldTerminate` while it is "clean".
- **Source policy bans relevant to new code** (SourcePolicyTests.swift:13-70): `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream` (network); `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource` (timers/polling); `.write(to:`, `FileHandle(forWriting`, `createFile(atPath` (own files). Confined: `forceTerminate` and `.terminate(` to SystemRunningCopies.swift; `SecCode`/`SecStaticCode`/`SecRequirement` to CodeSignature.swift; `copyItem(`/`moveItem(`/`replaceItemAt(`/`removeItem(`/`quarantinePropertiesKey` to BundleInstall.swift; `AuthorizationExecuteWithPrivileges`/`AuthorizationCopyRights` to PrivilegedInstall.swift; `runModal` to MoveDialogPresenter.swift; `currentAppleEvent` to ThisCopy.swift and TrackpadLauncherApp.swift; `SMAppService` to SystemLoginItem.swift. docs/architecture.md:20 (no timers/polling, only pushes) and :27 (no network code of any kind; no files written other than UserDefaults and the move's copy).
- App target build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Config/Base.xcconfig).
- Version source: Config/Version.xcconfig (untracked, new on this branch) `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`, included from Base.xcconfig; project.yml maps them to `CFBundleShortVersionString`/`CFBundleVersion`.

## Open Questions
- Whether `CodeSignature.build(of:)` (internal) is used by any production code path (e.g. the installer) — I only confirmed its tests; another explorer covering the installer may know.
- Whether `SMAppService.mainApp` registration survives replacing the bundle in place at the same /Applications path (by bundle id/team vs path), and whether the move-style `suspend()`/`resume()` handover is needed for an in-place replacement. Not determinable from code.
- What LaunchServices does for `openApplication(at:)` when a process launched from that exact path is still running after its bundle was replaced on disk (new instance vs reopen to the old process). No code or test in the repo covers this.
- How `QuitSignals` classifies `NSApp.terminate(nil)` called from inside the app (current Apple event may be nil or whatever event is being handled); it does not matter today because `end()` sets `.ending` first, which accepts any request.
