# How the move into /Applications works (grounding for in-app updates)

Angle: the move, end to end. All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates`. Facts only, with file:line.

## Components Found

| Name | File | What it is |
|---|---|---|
| `Lifecycle` (`@MainActor @Observable final class`) | `LauncherKit/Sources/LauncherCore/Lifecycle.swift:124-271` | Owns the process: routing at start/reopen, quit policy, and the move's ordering (`answer`, private `installed`). |
| `Lifecycle.Stage` (private enum) | `Lifecycle.swift:127-138` | `idle`, `replacingOthers(opensWindow:eject:)`, `resident(Launcher)`, `askingToMove(resident:)`, `moving(resident:)`, `moveFailed(reason:resident:)`, `ending`. |
| `Route` | `Lifecycle.swift:13-26` | Pure table `(Opening, Placement, olderCopyRuns) -> runSilently / runWithWindow / askToMove / end`. |
| `Opening` | `Lifecycle.swift:5-10` | `.atLogin` / `.byHand`. |
| `Launch` | `Lifecycle.swift:29-38` | `opening` + `diskImageToEject: DiskImage?` (only on the copy a move just installed). |
| `QuitRequest` | `Lifecycle.swift:41-47` | `.system` / `.other`. |
| `CopyID`, `RunningCopy` | `Lifecycle.swift:49-65` | pid wrapper; another running process with this bundle id plus `startedEarlier`. |
| `StartAtLogin` | `Lifecycle.swift:72-107` | Login-item intents `enrol/suspend/resume` with key `startAtLoginTurnedOffByQuit`. |
| `MoveDialog` | `Lifecycle.swift:110-115` | `.asking` / `.failed(reason: String)`. |
| `MoveAnswer` | `Lifecycle.swift:117` | `.move` / `.quit`. |
| `InstallOutcome` | `Lifecycle.swift:119-121` | `.installed`, `.cancelled`, `.failed(reason: String)`. |
| `Build`, `DiskImage`, `Location`, `Placement` | `LauncherKit/Sources/LauncherCore/Placement.swift:3-59` | Release/development; a volume URL; where this copy lies (running/original/isTranslocated/diskImage); `.installed/.development/.elsewhere`. |
| `RunningCopies` port | `LauncherKit/Sources/LauncherCore/Ports.swift:150-160` | `others()`, `stop(_:then:)`, `endThisCopy()`. |
| `Installer` port | `Ports.swift:173-186` | `install(then:)`, `removeOriginal()`, `openInstalledCopy()`, `eject(_:)`. |
| `ApplicationsInstaller` | `LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift:5-99` | Real `Installer`: stage, writability decision, unprivileged or administrator swap, remove original, open installed copy, eject. |
| `BundleInstall` (internal enum) | `LauncherKit/Sources/LauncherPlatform/BundleInstall.swift:5-65` | Every unprivileged file operation: `stage`, `swap`, `discard`, `removeOriginal`, `clearQuarantine`. |
| `Administrator` protocol, `AdministratorResult` | `LauncherKit/Sources/LauncherPlatform/PrivilegedInstall.swift:7-13` | The one privileged call (`run(script:arguments:)`), and its result `ran(exitStatus:) / cancelled / failed`. |
| `PrivilegedInstall` (internal enum) | `PrivilegedInstall.swift:16-49` | The one shell script and `swap(_:into:asideIn:by:)` mapping its result to `InstallOutcome`. |
| `AuthorizationAdministrator` | `PrivilegedInstall.swift:53-98` | Real `Administrator`: Authorization Services + `AuthorizationExecuteWithPrivileges` via `dlsym`. |
| `CodeSignature` (public enum) | `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift:7-39` | Developer ID requirement check of this process and of a bundle path. |
| `DiskImages` (internal enum) | `LauncherKit/Sources/LauncherPlatform/DiskImages.swift:6-34` | `image(holding:)` (statfs + DiskArbitration) and `eject(_:)` (FileManager unmount). |
| `ThisCopy` (public enum) + private `Translocation` | `LauncherKit/Sources/LauncherPlatform/ThisCopy.swift:5-61` | Parses the launch event/arguments into `Launch`; builds `Location` (translocation via private Security functions). |
| `SystemRunningCopies` | `LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift:4-71` | Real `RunningCopies`: `NSRunningApplication` list, `forceTerminate` + KVO `isTerminated`, `NSApp.terminate`. |
| `QuitSignals` | `LauncherKit/Sources/LauncherPlatform/QuitSignals.swift:5-34` | Classifies a quit Apple event as `.system` or `.other`. |
| `MoveDialogPresenter` | `LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift:7-44` | Observes `lifecycle.moveDialog`, runs an `NSAlert` modally, sends the answer. |
| `AppDelegate` (composition root) | `TrackpadLauncher/TrackpadLauncherApp.swift:17-92` | Builds `Lifecycle` with the real adapters; forwards launch/reopen/terminate. |
| `Copy` strings | `LauncherKit/Sources/LauncherCore/Copy.swift:14-21` | Dialog title/message/buttons and the two failure reasons. |

## Flow

### 0. Composition (before anything is decided)
- `AppDelegate.applicationWillFinishLaunching` (`TrackpadLauncherApp.swift:28-39`):
  - `NSApp.disableRelaunchOnLogin()` (`:30`).
  - `ThisCopy.location()` (`:31`) -> `Location`.
  - `Placement(build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location:)` (`:32-33`).
  - `StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement:)` (`:34`).
  - `Lifecycle(placement:, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location), startAtLogin:, makeResident:)` (`:35-37`).
  - `MoveDialogPresenter(lifecycle:)` (`:38`).
- `ApplicationsInstaller(location:)` convenience init uses `applications: URL(filePath: "/Applications")` and `administrator: AuthorizationAdministrator()` (`ApplicationsInstaller.swift:10-13`). The internal init (`:16-20`) takes a test folder and test administrator.

### 1. Where this copy lies: `ThisCopy.location()` (`ThisCopy.swift:22-35`)
- `location(of: Bundle.main.bundleURL, originalIfTranslocated: Translocation.original(of:), diskImage: DiskImages.image(holding:))`.
- `original = translocatedFrom ?? bundle`; `isTranslocated = translocatedFrom != nil` (stored from macOS, never inferred by URL compare: `Placement.swift:20`); `diskImage = diskImage(original)` — the disk image is looked up from the original, not the running bundle (`ThisCopy.swift:26-27` comment).
- Translocation (`ThisCopy.swift:40-61`): private, header-less Security functions resolved with `dlsym(UnsafeMutableRawPointer(bitPattern: -2) /* RTLD_DEFAULT */, name)`:
  - `SecTranslocateIsTranslocatedURL(CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UInt8`
  - `SecTranslocateCreateOriginalPathForURL(CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?` (`takeRetainedValue()`).
  - A missing symbol reads as "not translocated" (`:38-39`, `:52-54`).
- Disk image detection `DiskImages.image(holding:)` (`DiskImages.swift:9-22`): `statfs(url.path, &info)`; device `f_mntfromname` must start with `/dev/`; `DASessionCreate`, `DADiskCreateFromBSDName`, `DADiskCopyDescription`; `kDADiskDescriptionDeviceModelKey` trimmed must equal `"Disk Image"`; returns `DiskImage(volume: URL(filePath: f_mntonname))`.

### 2. Release vs development: `CodeSignature` (`CodeSignature.swift`)
- Requirement string (`:8-9`), quoted exactly:
  `"anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"`
  (Apple-anchored chain, Developer ID intermediate marker, Developer ID Application leaf marker). No team identifier is pinned anywhere; any Developer ID passes.
- `buildOfThisProcess(arguments:)` (`:14-22`): `SecCodeCopySelf([], &me)`, `SecCodeCheckValidity(me, [], requirement)`; success -> `.release`. Otherwise `.release` only if `arguments.contains("--as-release-build")` (exact element match), else `.development`.
- `build(of url:)` (`:26-32`, internal): `SecStaticCodeCreateWithPath`, `SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources), requirement)`. Resources NOT validated (comment `:24-25`: "a bundle edited after signing is still signed with a Developer ID"). Used only by tests today (`CodeSignatureTests.swift:12,45`); no production caller (grep of Sources/TrackpadLauncher).
- `requirement()` (`:34-38`): `SecRequirementCreateWithString(developerID as CFString, [], &requirement)`.
- No notarisation check, no bundle-identifier check, no team-ID comparison exists in the code.

### 3. Placement and route
- `Placement.init(build:location:applications:)` (`Placement.swift:42-50`): `.installed` if not translocated and `running` is inside `/Applications` at any depth (component-wise on standardized paths, `:54-58`), regardless of build; else `.development` for a development build; else `.elsewhere`. `~/Applications` is `.elsewhere`.
- `Route.init` (`Lifecycle.swift:18-25`): `(.atLogin, _, true) -> .end`, `(.atLogin, _, false) -> .runSilently`, `(.byHand, .elsewhere, _) -> .askToMove`, `(.byHand, .installed|.development, _) -> .runWithWindow`.

### 4. Who decides to show the move dialog
- `AppDelegate.applicationDidFinishLaunching` (`TrackpadLauncherApp.swift:42-46`): `ThisCopy.launch(event: NSAppleEventManager.shared().currentAppleEvent, arguments: CommandLine.arguments)` -> `lifecycle.launched(launch)`.
- `ThisCopy.launch` (`ThisCopy.swift:9-12`): `opening(of: event)` checks `keyAEPropData` enum code == `keyAELaunchedAsLogInItem` -> `.atLogin`, else `.byHand` (`:15-18`); `--eject-disk-image <volume>` -> `diskImageToEject`.
- `Lifecycle.launched` (`Lifecycle.swift:178-188`): only from `.idle`; `copies.others()`; `Route(...)`; `.askToMove` -> `stage = .askingToMove(resident: nil)`. No other copy is stopped and no resident (`Launcher`) is built while asking.
- Reopen: `applicationShouldHandleReopen` (`TrackpadLauncherApp.swift:48-53`) -> `lifecycle.openedAgain(opening)` (`Lifecycle.swift:191-198`): a `.resident` started at login whose route is `.askToMove` becomes `.askingToMove(resident: launcher)` (gestures keep running).
- `Lifecycle.moveDialog` (`:158-164`): `.askingToMove -> .asking`, `.moveFailed(reason) -> .failed(reason:)`, else nil.

### 5. How the dialog is shown and answered: `MoveDialogPresenter` (`MoveDialogPresenter.swift`)
- AppKit `NSAlert`, not SwiftUI. LauncherUI has `defaultIsolation(MainActor.self)` (`LauncherKit/Package.swift:15-19`).
- `init(lifecycle:)` (`:10-17`): `Task { for await dialog in Observations({ lifecycle.moveDialog }) { guard let dialog ...; self?.run(dialog, answering: lifecycle) } }` (Observation's `Observations` async sequence).
- `run` (`:23-43`): `alertStyle = .informational`. `.asking`: title `Copy.moveDialogTitle` ("Trackpad Launcher needs to be in the Applications folder"), message `Copy.moveDialogMessage` ("Move it there to finish installing."), buttons `Copy.moveButton` ("Move to Applications", first/default) and `Copy.moveQuitButton` ("Quit"). `.failed(reason)`: title `Copy.moveFailedTitle` ("Trackpad Launcher couldn't be moved to the Applications folder"), informative text = reason, one button "Quit".
- `NSApp.activate()` then `alert.runModal()` (`:37-38`). `.asking`: first button -> `lifecycle.answer(.move)`, else `.quit`. `.failed`: always `lifecycle.answer(.quit)`.

### 6. `Lifecycle.answer` (`Lifecycle.swift:215-223`)
- `(.askingToMove(resident), .move)`: `stage = .moving(resident:)`, then `installer.install { [unowned self] in installed($0) }`.
- `(.askingToMove, .quit)` and `(.moveFailed, _)`: `end()` -> `stage = .ending; copies.endThisCopy()` (`:233-236`).
- Any other combination: ignored (a second Move while installing is ignored; test `MoveToApplicationsTests.swift:101-103`).

### 7. The install: `ApplicationsInstaller.install(then:)` (`ApplicationsInstaller.swift:22-30`)
- `Task { let outcome = await Self.copy(location, into: applications, by: administrator); done(outcome) }`. The class is `@MainActor`, so the `Task` and `done` are on the main actor; `copy` is `@concurrent private static func` (`:70-98`) so the file work (and the blocking admin prompt) run off the main actor. `done` is a single completion push; there is no progress and no cancellation API.
- `copy` steps:
  1. `destination(of:in:)` (`:55-68`): bundle identifier read with `Bundle(url: location.running)?.bundleIdentifier`; enumerates `/Applications` (`.skipsPackageDescendants, .skipsHiddenFiles`) for `.app` bundles with the same identifier; sorts by depth then path; prefers a direct child named like the original, then any direct child, then the shallowest nested one, else `/Applications/<original.lastPathComponent>`. So it replaces the installed copy whatever its name or folder depth.
  2. `BundleInstall.stage(location.running, near: destination)` (`:77`). Staging happens BEFORE the writability check, so the copy is made before any admin prompt. Failure -> `.failed(reason: error.localizedDescription)`.
  3. Writability decision (`:81-84`), quoted:
     ```swift
     let canWrite =
         files.isWritableFile(atPath: applications.path)
         && (!files.fileExists(atPath: destination.path) || files.isWritableFile(atPath: destination.path))
     ```
     i.e. `/Applications` itself writable AND (no destination, or the destination bundle directory itself writable). Contents of the existing bundle are not checked.
  4. Not writable -> `PrivilegedInstall.swap(staged, into: destination, asideIn: staged.deletingLastPathComponent(), by: administrator)` then `BundleInstall.discard(staged)`; return the script's outcome (`:85-90`).
  5. Writable -> `try BundleInstall.swap(staged, into: destination)` -> `.installed`; on throw `discard(staged)` and `.failed(reason: error.localizedDescription)` (`:91-97`).

### 8. Unprivileged file operations: `BundleInstall` (`BundleInstall.swift`)
- `stage(_ source:, near destination:)` (`:10-23`), key calls:
  ```swift
  let anchor = files.fileExists(atPath: destination.path) ? destination : destination.deletingLastPathComponent()
  let folder = try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: anchor, create: true)
  let staged = folder.appending(path: destination.lastPathComponent)
  try files.copyItem(at: source, to: staged)
  try clearQuarantine(under: staged)
  ```
  A fresh temporary folder on the destination's volume (`.itemReplacementDirectory`), named copy inside it. On any error it `discard`s and rethrows. Nothing at destination changes.
- `clearQuarantine(under:)` (`:55-64`): walks root + every item; `removexattr(item.path, "com.apple.quarantine", XATTR_NOFOLLOW)`; ignores `ENOATTR`; any other error throws `CocoaError(.fileWriteUnknown)`. Comment (`:8-9`): "a copy that carries none is never translocated". It does not use `quarantinePropertiesKey` (dev log `plans/021-background-agent-lifecycle/development-logs.md:46`: chosen for symlinks' own marks and dangling links).
- `swap(_ staged:, into destination:)` (`:27-35`), quoted:
  ```swift
  if files.fileExists(atPath: destination.path) {
      _ = try files.replaceItemAt(destination, withItemAt: staged)
  } else {
      try files.moveItem(at: staged, to: destination)
  }
  discard(staged)
  ```
  Doc comment: "Puts `staged` at `destination` in one step: an atomic replace when something lies there, a move when not. Throws with `destination` untouched." Uses `FileManager.replaceItemAt(_:withItemAt:)` with no backup name and no options. No `renamex_np`, `RENAME_SWAP`, `exchangedata` or remove-then-copy in the code. The whole-or-nothing claim rests on Foundation's `replaceItemAt` (see Open Questions) and on staged + destination being on one volume.
- `discard(_ staged:)` (`:38-45`): `try? removeItem(at: staged)`; removes the parent temp folder only if empty. Never throws.
- `removeOriginal(_ original:)` (`:49-52`): only if `FileManager.default.isDeletableFile(atPath:)`, then `try? removeItem(at: original)`. A read-only share leaves the bundle whole (no half-deleted bundle).

### 9. Administrator path: `PrivilegedInstall` + `AuthorizationAdministrator` (`PrivilegedInstall.swift`)
- Protocol (`:7-11`): `protocol Administrator: Sendable { func run(script: String, arguments: [String]) -> AdministratorResult }` — synchronous, blocks, "called off the main actor"; runs `/bin/sh -c script sh arguments…` as root.
- `PrivilegedInstall.script` (`:22-35`), the one script, quoted:
  ```sh
  destination="$1"; staged="$2"; aside="$3"
  moved=no
  if [ -e "$destination" ] || [ -L "$destination" ]; then
      /bin/mv -- "$destination" "$aside" || exit 1
      moved=yes
  fi
  if ! /bin/mv -- "$staged" "$destination"; then
      if [ "$moved" = yes ]; then /bin/mv -- "$aside" "$destination"; fi
      exit 1
  fi
  /bin/rm -rf -- "$aside"
  exit 0
  ```
  Paths are positional args, never interpolated. Steps: (1) move the old copy aside into the staging folder (outside /Applications); (2) move the staged copy in; on failure move the old one back and exit 1; (3) `rm -rf` the aside copy, failure ignored, exit 0.
- Restart/kill safety (comment `:17-21`, and plan 021 `plan.md:500`): two renames, not one atomic step. "Only a kill between the two moves leaves /Applications without the app and the old copy in the staging folder, never inside /Applications." So the administrator path is NOT whole-or-nothing across a restart; the unprivileged path claims to be.
- `swap(_:into:asideIn:by:)` (`:37-48`): `aside = folder.appending(path: "Replaced " + destination.lastPathComponent)`; `administrator.run(script:, arguments: [destination.path, staged.path, aside.path])`. Mapping: `.ran(exitStatus: 0) -> .installed`; other `.ran -> .failed(reason: Copy.applicationsFolderNotChanged)` ("The Applications folder could not be changed."); `.cancelled -> .cancelled`; `.failed -> .failed(reason: Copy.cannotWriteToApplications)` ("This account can't change the Applications folder.").
- `AuthorizationAdministrator.run` (`:59-97`), step by step:
  1. `dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges")` (deprecated, no Swift import, still exported) cast to `@convention(c) (AuthorizationRef, UnsafePointer<CChar>, AuthorizationFlags, UnsafePointer<UnsafeMutablePointer<CChar>?>, UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?) -> OSStatus` (`:54-64`). Missing -> `.failed`.
  2. `AuthorizationCreate(nil, nil, [], &created)`; `defer AuthorizationFree(authorization, [])` (`:66-70`).
  3. `AuthorizationCopyRights` for `kAuthorizationRightExecute` with flags `[.interactionAllowed, .extendRights, .preAuthorize]` (`:72-79`) — this shows the system name-and-password prompt.
  4. Cancel detection (`:80`): `if granted == errAuthorizationCanceled { return .cancelled }`; any other non-success -> `.failed`.
  5. `argv = ["-c", script, "sh"] + arguments` (strdup'd, freed in defer); `execute(authorization, "/bin/sh", [], argv, &pipe)`; non-success -> `.failed` (`:83-86`).
  6. Reads the pipe to EOF, `fclose`, then `wait(&status)`; requires `status & 0x7f == 0` (normal exit) and returns `.ran(exitStatus: (status >> 8) & 0xff)` (`:88-96`). Note `wait` reaps any child of the process, not a specific pid.
- Not used: `osascript ... with administrator privileges`, SMJobBless, `NSWorkspace.requestAuthorization` (needs a restricted entitlement: plan 021 grounding F31, `development-logs.md:19`).
- Who owns the installed copy after an admin swap: the staged copy was made by the user's process and `/bin/mv` within one volume keeps its owner. (Inference from the code, not tested.)

### 10. After the install: `Lifecycle.installed` (`Lifecycle.swift:257-270`)
- Guard `.moving(resident)`.
- `.cancelled` -> `end()` (the move process quits, nothing changed).
- `.failed(reason)` -> `stage = .moveFailed(reason:, resident:)` -> presenter shows the failure alert; its Quit -> `end()`.
- `.installed`, in this order (comment `:254-256`: converges after a crash at any point):
  1. `startAtLogin.suspend()` — if the login item is on, remember `startAtLoginTurnedOffByQuit = true` then unregister (`:94-97`). The installed copy's first `openedByHand` -> `startAtLogin.resume()` re-registers (`Launcher.swift:190-197`).
  2. `installer.removeOriginal()` (`ApplicationsInstaller.swift:32-37`): no-op if on a disk image or if `original` equals the destination (standardized); else `BundleInstall.removeOriginal(location.original)` (the original place for a translocated copy).
  3. `copies.stop(copies.others()) { installer.openInstalledCopy(); end() }` — every other running copy (including the old one in /Applications) is stopped first; only after all exited does it open the installed copy and end itself.

### 11. Stopping other copies: `SystemRunningCopies` (`SystemRunningCopies.swift`)
- `others()` (`:10-20`): `NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")` minus own pid, with `startedEarlier` from the total order `started(_:before:)` (`:67-70`: launch date, nil = latest, then lower pid).
- `stop(_:then:)` (`:22-45`): live `NSRunningApplication`s not yet terminated; none -> call `exited()` synchronously. Else `app.forceTerminate()` for each and KVO `observe(\.isTerminated, options: [.initial, .new])`; on each termination hop `DispatchQueue.main.async { MainActor.assumeIsolated { if remaining.exit(pid) { finish() } } }`; `Remaining` counts each pid once (`:51-62`). No timer/deadline: a copy that survives `forceTerminate` blocks forever (accepted tradeoff, plan 021 `development-logs.md:33`).
- `endThisCopy()` (`:47`): `NSApp.terminate(nil)` -> `applicationShouldTerminate` (`TrackpadLauncherApp.swift:55-57`) -> `lifecycle.shouldEnd(...)`; stage is `.ending` so it returns `true` (`Lifecycle.swift:203`).

### 12. Opening the installed copy: `ApplicationsInstaller.openInstalledCopy()` (`ApplicationsInstaller.swift:39-47`)
- `NSWorkspace.OpenConfiguration()`, `activates = true`; when the mover lies on a disk image, `arguments = ["--eject-disk-image", diskImage.volume.path]`. No environment, no `createsNewApplicationInstance`, no completion handler (result ignored).
- `NSWorkspace.shared.openApplication(at: Self.destination(of: location, in: applications), configuration:)` — `destination` is recomputed (enumerating /Applications again).
- How the installed copy knows to open its settings window: nothing special is passed. Its open event lacks the login-item marker -> `Opening.byHand`; it is in /Applications -> `Placement.installed`; `Route` -> `.runWithWindow` -> `replace(others, opensWindow: true, eject:)` (`Lifecycle.swift:186, 239-242`) -> once others exited, `othersExited()` builds the resident, `launcher.start()`, `launcher.openedByHand()` (window open), and `installer.eject(eject)` if `--eject-disk-image` was passed (`:244-252`).
- The mover may still be alive when the installed copy starts (it calls `end()` right after `openInstalledCopy()` returns). The installed copy lists it in `others()` and force-terminates it in `replace` (by-hand opening stops every other copy), waiting for its exit before building the resident and ejecting. Comment `:250`: "The mover has exited, so its volume is free."
- How the old process exits: the mover ends itself via `end()` -> `NSApp.terminate(nil)`; the old installed copy (if running) was force-terminated by the mover in step 10.3.

### 13. Eject: `DiskImages.eject` (`DiskImages.swift:24-27`)
- `FileManager.default.unmountVolume(at: diskImage.volume, options: .allPartitionsAndEjectDisk) { _ in }` — returns at once; the completion is ignored; a file in use leaves it mounted. DiskArbitration is used only for detection, not ejection. Called from the installed copy (`Lifecycle.othersExited`), never from the mover.

### 14. Quit policy during the move (`Lifecycle.shouldEnd`, `Lifecycle.swift:201-212`)
- `.ending, .idle, .replacingOthers, .askingToMove, .moveFailed` -> `true`.
- `.moving` -> `request == .system` only (an ordinary quit during the install is refused; logout/restart/shutdown proceed).
- `.resident(launcher)`: `.other` with the window open -> `launcher.closeWindow()` and refuse; otherwise end.
- `QuitSignals.request(for:)` (`QuitSignals.swift:22-33`): `.system` if the event has `kAEQuitReason` (attribute or param), the sender is `com.apple.loginwindow`, or `NSWorkspace.willPowerOffNotification` was seen.

## Ports / adapters / tests

### Port signatures (LauncherCore, `Ports.swift`)
```swift
@MainActor public protocol RunningCopies: AnyObject {
    func others() -> [RunningCopy]
    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void)
    func endThisCopy()
}
@MainActor public protocol Installer: AnyObject {
    func install(then done: @escaping @MainActor (InstallOutcome) -> Void)
    func removeOriginal()
    func openInstalledCopy()
    func eject(_ diskImage: DiskImage)
}
```
Doc contract of `install` (`Ports.swift:175-177`): "Copies this copy into /Applications, replacing any Trackpad Launcher there whatever its version. Nothing there changes unless the outcome is `.installed`, and never a mix of two copies. Unprivileged, the replace is one atomic step. `done` runs once, on the main actor. The copy can block; a test holds `done`." Not async/await: completion pushes. The source of the copy is fixed at construction (`location.running`); there is no parameter for another source bundle.

Platform-internal (not a LauncherCore port): `protocol Administrator: Sendable { func run(script: String, arguments: [String]) -> AdministratorResult }` (`PrivilegedInstall.swift:7-11`).

### In-memory test adapters (`LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`)
- `InMemoryInstaller` (`:524-571`): `install` records `"install"` in the shared `EffectLog` and holds `done`; `release(_ outcome:)` fires it (for `.installed`, `onEffect`/`onInstalled`/`onEffect` around it to mark when /Applications changed); counts `installCalls`, `removeOriginalCalls`, `openInstalledCopyCalls`, `ejected`.
- `InMemoryRunningCopies` (`:575-621`): `listed`, `stopped`, `alreadyExited`; `stop` logs `"stop"` and holds `exited` until `letExit(id)` / `letStoppedCopiesExit()`; `deliverExitAgain()`; `endThisCopy()` asks `lifecycle.shouldEnd(.other)` and sets `hasEnded` when true.
- `LifecycleWorld` / `OneProcess` (`LifecycleWorld.swift`): one Mac with a shared suite, login item and permissions; each `launch(_:others:alreadyExited:placement:diskImageToEject:)` builds a real `Lifecycle` + real `Launcher` over in-memory adapters; snapshots around every effect so kill-anywhere convergence can be checked.
- `TestAdministrator` (`LauncherPlatformTests/PrivilegedInstallTests.swift:9-43`): records calls; `answer` non-nil returns it; nil runs the REAL script unprivileged with `Process` `/bin/sh -c script sh args…`. `TestAdministrator.refusing` answers `.cancelled`.
- `BundleFixture` (`LauncherPlatformTests/BundleFixture.swift`): temp folders, bundles with nested files and a symlink, quarantine set on every item via `/usr/bin/xattr -w` (`:51-54`), `manifest(of:)`, `extendedAttributes(under:)` via `xattr -r`, `appNames(in:)`.

### Tests covering the move
- `LauncherCoreTests/MoveToApplicationsTests.swift`:
  - `aLoginStartRunsSilentlyWhereverItLies` (`:12`): no dialog at login for any placement.
  - `aDevelopmentBuildOpenedByHandStopsTheInstalledCopyThenOpensItsWindowWithoutAsking` (`:29`).
  - `aCopyInDownloadsOpenedByHandOnlyAsksAndQuitLeavesTheMacAsItWas` (`:44`): asking state builds nothing, stops nothing, asks nothing; Quit ends with suite unchanged.
  - `aResidentStartedAtLoginKeepsItsGesturesWhileTheDialogAsks` (`:70`).
  - `movingFromDownloadsOnTheFirstRunInstallsOnceWithoutSpendingTheFirstRun` (`:93`): second Move ignored; log `["install", "removeOriginal", "openInstalledCopy"]`; installed copy does the first run and opens window.
  - `movingOverAnOlderCopyKeepsEverySettingAndHandsStartingAtLoginOver` (`:131`): log `["install", "unregister", "removeOriginal", "stop", "openInstalledCopy"]`; open happens only after the older copy exits; installed copy re-registers login item and keeps hand mode.
  - `movingKeepsStartingAtLoginOffWhenTheUserTurnedItOff` (`:161`).
  - `cancellingTheInstallEndsTheProcessWithNothingChanged` (`:175`), `cancellingTheInstallEndsAResidentStartedAtLoginToo` (`:191`).
  - `aFailedInstallShowsTheReasonAndQuitEndsWithNothingChanged` (`:203`): `.failed` dialog shows reason; resident gestures still work.
  - `aSystemQuitEndsWhileTheDialogAsksTheInstallIsHeldAndTheFailureShows` (`:224`): `.moving` refuses `.other`, accepts `.system`.
  - `aKillAnywhereInAFirstMoveConverges` (`:279`), `aKillAnywhereInAMoveOverAnOlderCopyConverges` (`:283`) via `convergesAfterAKillAnywhereIn` (`:244-277`).
- `LauncherCoreTests/ReplacingOtherCopiesTests.swift`: `theInstalledCopyEjectsTheMoversDiskImageOnlyAfterTheMoverHasExited` (`:108`, log `["stop", "eject"]`), `anOpeningByHandWhileWaitingKeepsTheDiskImageToEject` (`:123`), plus stop/wait tests (`:6-91`).
- `LauncherPlatformTests/ApplicationsInstallerTests.swift` (real file ops in temp folders, administrator `.refusing`): empty /Applications copy without quarantine (`:20`); replaces another version under the same name (`:36`); replaces the installed copy whatever its name (`:51`); replaces a copy nested in a subfolder (`:64`); translocated copy copied from the running bundle under the original's name (`:78`); unreadable source fails before anything changes (`:94`); `removeOriginal` deletes from Downloads (`:108`), keeps it in an unwritable folder (`:118`), keeps it on a disk image (`:131`), keeps the installed copy itself (`:143`).
- `LauncherPlatformTests/PrivilegedInstallTests.swift`: unwritable /Applications (`chmod 0o555`) asks the administrator once and leaves the old copy and no staged leftovers for `.cancelled`/`.failed` (`:59`); unwritable installed bundle likewise, `.failed` reason == `Copy.cannotWriteToApplications` (`:86`); unreadable running bundle fails before asking (`:106`); real script with paths containing quotes, spaces and `$(touch pwned)` (`:127`); second `mv` failing puts the old copy back and reports failure (`:154`); old copy not fully removable still leaves the new one installed (`:178`); a temp folder is not a disk image (`:195`).
- `LauncherPlatformTests/ThisCopyTests.swift` (login marker, `--eject-disk-image` parsing `:39-48`), `ThisCopyLocationTests.swift` (trailing slash `/Applications/...app/` is installed `:8`; translocated bundle finds disk image from the original `:20`), `CodeSignatureTests.swift` (test binary is development `:10`; `--as-release-build` exact match `:15`; every app in /Applications is release exactly when `codesign -dvv` says "Developer ID Application" `:35`), `RunningCopiesOrderTests.swift`, `QuitSignalsTests.swift`.
- Not covered by automated tests: `MoveDialogPresenter`, `AuthorizationAdministrator` itself, `openInstalledCopy`, `DiskImages.eject`, `SystemRunningCopies.stop` (only the order function is tested).

## Source-scan confinement (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`)
Scans `LauncherKit/Sources` and `TrackpadLauncher/` (`:157-162`), substring match per line, comments included, by file name only (`:265-271`).
- Move-related confinements (`:111-149`):
  - `SecCode`, `SecStaticCode`, `SecRequirement` -> `CodeSignature.swift` (`:111-113`)
  - `/bin/mv`, `/bin/rm` -> `PrivilegedInstall.swift` (`:114-115`)
  - `forceTerminate` -> `SystemRunningCopies.swift`; `.terminate(` -> `SystemRunningCopies.swift` (`:129-131`)
  - `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `quarantinePropertiesKey` -> `BundleInstall.swift` (`:132-138`)
  - `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` -> `PrivilegedInstall.swift` (`:139-143`)
  - `statfs`, `DADisk`, `unmountVolume` -> `DiskImages.swift` (`:144-146`)
  - `SecTranslocate` -> `ThisCopy.swift` (`:147`)
  - `runModal` -> `MoveDialogPresenter.swift` (`:148`)
  - `kAEQuitReason` -> `QuitSignals.swift` (`:149`)
  - `keyAELaunchedAsLogInItem` -> `ThisCopy.swift`; `currentAppleEvent` -> `ThisCopy.swift`, `TrackpadLauncherApp.swift`; `disableRelaunchOnLogin` -> `TrackpadLauncherApp.swift`; `SMAppService` -> `SystemLoginItem.swift`; `setActivationPolicy` -> `SettingsShell.swift` (`:116-128`).
- Banned outright and relevant to an updater (`:13-70`): `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream` ("network"); `FileHandle(forWriting`, `.write(to:`, `createFile(atPath` ("own files"); `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` ("timer"/"polling"); all logging; `nonisolated(unsafe)`; `SMAppService.agent/.daemon/.loginItem`, `SMLoginItemSetEnabled`.
- `LauncherCore` may import only `Foundation` and `Observation` (`:222-228`).
- Note: `Authorization*` other than the two names above, `removexattr`, `NSWorkspace.openApplication`, `dlsym`, `isWritableFile` are not confined. `removeItem(` is confined to `BundleInstall.swift` but `SourcePolicyTests.swift` itself is a test file (not scanned).

## Files Read
- `plans/022-in-app-updates/plan.md`
- `plans/022-in-app-updates/development-logs.md` (head)
- `LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift`
- `LauncherKit/Sources/LauncherPlatform/BundleInstall.swift`
- `LauncherKit/Sources/LauncherPlatform/PrivilegedInstall.swift`
- `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift`
- `LauncherKit/Sources/LauncherPlatform/DiskImages.swift`
- `LauncherKit/Sources/LauncherPlatform/ThisCopy.swift`
- `LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift`
- `LauncherKit/Sources/LauncherPlatform/QuitSignals.swift`
- `LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift`
- `LauncherKit/Sources/LauncherCore/Lifecycle.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Placement.swift`
- `LauncherKit/Sources/LauncherCore/Copy.swift` (lines 14-21)
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (lines 185-207)
- `LauncherKit/Package.swift`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/MoveToApplicationsTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 505-650)
- `LauncherKit/Tests/LauncherCoreTests/ReplacingOtherCopiesTests.swift` (lines 100-137, test list)
- `LauncherKit/Tests/LauncherPlatformTests/ApplicationsInstallerTests.swift`
- `LauncherKit/Tests/LauncherPlatformTests/PrivilegedInstallTests.swift`
- `LauncherKit/Tests/LauncherPlatformTests/CodeSignatureTests.swift`
- `LauncherKit/Tests/LauncherPlatformTests/ThisCopyLocationTests.swift`
- `LauncherKit/Tests/LauncherPlatformTests/BundleFixture.swift` (function list)
- `docs/architecture.md`, `docs/domain-model.md` (grep for move-related lines: architecture `:11-12, :20, :27, :30`; domain-model `:12, :23-24, :27`)
- `plans/021-background-agent-lifecycle/development-logs.md`, `plan.md`, `.temp/architect/grounding/index.md` (grep only)
- `project.yml`, `Config/Version.xcconfig` (grep only)

## Boundaries
- In: AppKit launch/reopen/terminate delegate calls and the current Apple event (`TrackpadLauncherApp.swift`), `CommandLine.arguments` (`--as-release-build`, `--eject-disk-image <volume>`), `Bundle.main.bundleURL`, the user's alert answer.
- Out: files under `/Applications` (stage in an `.itemReplacementDirectory` temp folder, then swap); removal of the opened original; root execution of `/bin/sh` with one script; `forceTerminate` of other copies; `NSWorkspace.openApplication` of the installed copy; `FileManager.unmountVolume`; login-item unregister (`StartAtLogin.suspend`).
- Model/adapter seam: `Lifecycle` (LauncherCore) only sees `Installer` and `RunningCopies` ports plus `StartAtLogin`; all platform tangles (translocation, staging, quarantine, authorization, swap, eject) are behind `ApplicationsInstaller`.
- The installed copy and the mover communicate only through: the open event (no login marker = by hand), the `--eject-disk-image` argument, the shared defaults domain (settings, `startAtLoginTurnedOffByQuit`), and process termination.

## Non-Obvious Things
1. `install` copies `location.running` — this process's own bundle — and the `Installer` port has no parameter for another source. An update would install a different (downloaded) bundle, so the port as shaped does not express that.
2. For the in-/Applications copy, `removeOriginal()` is a no-op (original equals destination, `ApplicationsInstaller.swift:35`), and the existing destination is the running bundle itself — the move today never replaces the bundle that is executing; it replaces another copy and force-terminates it first. In the move, the order is swap -> suspend login item -> remove original -> stop all others -> open installed -> end self.
3. The installed copy is opened while the mover is still running; the new copy force-terminates the mover if it has not exited yet (by-hand opening stops every other copy, `Lifecycle.swift:186, 239-242`) and only then builds its resident, opens its window and ejects. So "the old process exits" is double-covered: it terminates itself and the new copy force-terminates it.
4. The settings window opens in the new copy only because it is opened "by hand" from /Applications (route `.runWithWindow`); no argument or environment carries "open your window".
5. Staging (full copy, quarantine cleared) happens before the writability check, so the admin prompt appears only after the copy is staged (`ApplicationsInstaller.swift:77-85`).
6. Writability = `/Applications` writable AND destination bundle dir writable (if it exists). Inner contents and ownership are not checked (`:82-84`).
7. Unprivileged path claims atomicity via `FileManager.replaceItemAt` (no backup name/options); admin path is explicitly two renames and can leave /Applications without the app if killed between them (`PrivilegedInstall.swift:17-21`). The aside copy lives in the user's staging temp folder, not in /Applications.
8. Cancel detection is only `AuthorizationCopyRights == errAuthorizationCanceled` (`PrivilegedInstall.swift:80`). In the move, `.cancelled` ends the process (`Lifecycle.swift:260`) — the same outcome would need a different reaction for an update card (R11).
9. `AuthorizationAdministrator` uses `wait(&status)` (any child), not `waitpid` for a specific pid (`PrivilegedInstall.swift:95`); the deprecated `AuthorizationExecuteWithPrivileges` is resolved by `dlsym` (no link flags).
10. `CodeSignature.build(of:)` skips resource validation (`kSecCSDoNotValidateResources`) and checks only "is a Developer ID" — not the team, not the bundle id, not notarisation. It is unused in production. The `--as-release-build` argument makes an unsigned build behave as a release for hand-testing (`CodeSignature.swift:11-13, 21`).
11. Translocation is resolved through private `SecTranslocate*` functions via `dlsym`; a missing symbol silently means "not translocated" (`ThisCopy.swift:38-60`). A translocated copy is copied from its read-only mount (`running`) under the original's file name (test `ApplicationsInstallerTests.swift:78-92`).
12. Quarantine is cleared with `removexattr(..., XATTR_NOFOLLOW)` per item, not `quarantinePropertiesKey`, even though the latter is the confined token (`BundleInstall.swift:55-64`).
13. Eject uses `FileManager.unmountVolume(... .allPartitionsAndEjectDisk)` with an ignored completion; DiskArbitration is used only to recognise a disk image by device model `"Disk Image"` (`DiskImages.swift:9-27`).
14. During `.moving`, an ordinary quit is refused but a system quit is honoured (`Lifecycle.swift:204`) — a parallel to R13's installing state, though the move has no settings window.
15. `stop` has no deadline (timers banned); a copy that survives `forceTerminate` leaves the flow waiting forever (accepted, plan 021 `development-logs.md:33`).
16. The source scan matches substrings in comments too, by file name; adding a new file that mentions e.g. `replaceItemAt(` or `/bin/mv` even in a comment fails the test (plan 021 `.temp/slices/S5.md:202`, `S6.md:106`).
17. `destination(of:in:)` reads `Bundle(url: location.running)?.bundleIdentifier` and enumerates /Applications twice (in `copy` and again in `openInstalledCopy`). `Bundle(url:)` instances are cached by Foundation per URL (general Foundation behaviour, not verified here), which could matter if a bundle at the same path is read before and after a replace.

## Open Questions
- Whether `FileManager.replaceItemAt(_:withItemAt:)` on a bundle directory on APFS is a single atomic exchange (e.g. `renamex_np` with `RENAME_SWAP`) or a multi-step operation, and what a restart mid-call leaves behind, is not established in code or tests here; the code relies on the doc claim "one atomic step" (`Ports.swift:177`, `BundleInstall.swift:25-26`). Not probed.
- Whether `NSWorkspace.openApplication(at:)` launches a new instance of the bundle in /Applications while another process with the same bundle id (the mover) still runs from another path, versus activating the running one, is assumed (it works for the move) but not tested; for an update, the running process would be at the same path as the newly swapped bundle, which the move never does.
- Whether TCC (Accessibility/Screen Recording) and the SMAppService login item follow a bundle replaced in place was listed as open in plan 021 (grounding F38) and is not settled in this code.
- The ownership of a copy installed by the administrator path (stays the staging user, by inference from `mv` semantics) is not tested.
- `MoveDialogPresenter`, `AuthorizationAdministrator`, `openInstalledCopy` and `DiskImages.eject` have no automated tests; their behaviour is from code reading only.
