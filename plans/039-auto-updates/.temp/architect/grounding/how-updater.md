# How the updater subsystem works today (grounding for plan 039)

Angle: the updater itself: `Updater`, `Update`, `Version`, the update ports, the real adapters, the card and its wiring, the tests. Paths are relative to the worktree root. `Core/` means `LauncherKit/Sources/LauncherCore/`, `Platform/` means `LauncherKit/Sources/LauncherPlatform/`, `UI/` means `LauncherKit/Sources/LauncherUI/`, `App` means `TrackpadLauncher/TrackpadLauncherApp.swift`, `CoreTests/` and `PlatformTests/` are under `LauncherKit/Tests/`.

Everything below was read from code unless marked "inferred" or listed under Open Questions. I ran no tests and no binary.

## Summary

- Today an update is entirely window-driven. Nothing happens unless the settings window opens from closed. No timer, no persisted state, no background work.
- `Updater` is a pure state machine in Core. It sits behind two ports, `ReleaseList` and `UpdateInstaller`, and renders one enum, `UpdateCard`.
- Whether a copy may update is decided once at start by `InstalledRelease.init?`, fed by `Placement` and `CodeSignature.developerIDSigner()`. Whether it can write to its bundle is **not** part of that gate. It is checked only at swap time in `ApplicationsInstaller.put`, which falls back to an administrator prompt.
- The move-to-Applications flow shares `ApplicationsInstaller`, `PrivilegedInstall`, part of `BundleInstall`, and `CodeSignature.buildOfThisProcess`. Those must stay.
- The new version always arrives as an opening by hand, so it opens its window. That is the opposite of R9 and is pinned by tests.

## Components Found

### Core

| Name | Where | What it does |
|---|---|---|
| `Updater` | `Core/Updater.swift:9-142` | `@MainActor @Observable` state machine: check, offer, download, install, open, fail. Owns card state and `isInstalling`. |
| `Updater.Phase` (private) | `Core/Updater.swift:12-22` | `idle`, `checking(ticket)`, `offering(Release)`, `downloading(Release, ticket, progress)`, `installing(Release, ticket)`, `opening(Release)`, `failed(Release)`. |
| `Release` | `Core/Update.swift:6-26` | Version, minimum macOS, archive URL, archive size. `newerVersion(in:than:on:)` (`:23-25`) is the one "what counts as newer" rule. |
| `InstalledRelease` | `Core/Update.swift:32-41` | The gate. `init?(placement:developerIDSigned:version:macOS:)` returns nil unless Developer ID signed, `.installed`, and version readable. |
| `UpdateEvent` | `Core/Update.swift:45-57` | `.progress`, `.downloaded`, `.installed`, `.declined`, `.failed`, in a stated order. |
| `UpdateCard` / `UpdateCard.Layout` | `Core/Update.swift:60-82` | What the card renders (`available`, `downloading`, `installing`, `failed`), and the progress-erased form that decides window height. |
| `Version` | `Core/Version.swift:6-42` | Dotted whole numbers. Compared part by part, trailing zeros dropped. Each part 1-9 ASCII digits. |
| `UpdateInstaller` port | `Core/Ports.swift:204-220` | `update(to:events:)`, `cancelDownload()`, `openNewVersion(then:)`. |
| `ReleaseList` port | `Core/Ports.swift:222-228` | `fetch(then:)`. |
| `Installer` port (the move, not updates) | `Core/Ports.swift:189-202` | `install`, `removeOriginal`, `openInstalledCopy`, `eject`. |
| `Placement`, `Build`, `Location` | `Core/Placement.swift` | Where this copy lies. `.installed` means inside /Applications at any depth, not translocated, whatever the build (`:35`, `:42-50`). |
| `Copy.update*` strings | `Core/Copy.swift:20-27` | Card text and buttons. |

### Platform

| Name | Where | What it does |
|---|---|---|
| `GitHubReleases` | `Platform/GitHubReleases.swift:8-177` | Real `ReleaseList`. The one network file. Also holds `ArchiveDownload` (`:43-69`), `ByteWatcher` (`:73-105`), `parse` (`:124-130`), `archiveName` (`:142-150`), `session` (`:154-166`), `request` (`:169-176`). |
| `ApplicationsUpdater` | `Platform/ApplicationsUpdater.swift:9-92` | Real `UpdateInstaller`: download, then unpack, verify, swap off-main, then open. |
| `BundleInstall` | `Platform/BundleInstall.swift:8-160` | Every unprivileged file operation, for both the move and the update. |
| `PrivilegedInstall` | `Platform/PrivilegedInstall.swift:16-52` | The root swap script and JXA exchange. |
| `Administrator`, `AdministratorResult`, `AuthorizationAdministrator` | `Platform/PrivilegedInstall.swift:7-13`, `:56-101` | The prompt. `AuthorizationExecuteWithPrivileges` resolved by `dlsym`. |
| `ApplicationsInstaller` | `Platform/ApplicationsInstaller.swift:5-106` | Real `Installer`. `put` (`:87-105`) is "the move's and the update's one swap" (comment at `:84`). |
| `CodeSignature`, `Signer` | `Platform/CodeSignature.swift:7-104`, `:107-110` | Developer ID checks. |
| `ThisCopy` | `Platform/ThisCopy.swift:5-49` | Launch event parsing, version, macOS, location. |

### UI and composition

| Name | Where | What it does |
|---|---|---|
| `UpdateCardView` | `UI/UpdateCardView.swift:6-40` | One `FormGroup` with a row per card state. |
| `SettingsView` | `UI/SettingsView.swift:13-118` | Holds `updater: Updater?` (`:15`), shows the card (`:41-46`), disables Quit (`:107`). |
| `SettingsShell` | `UI/SettingsShell.swift:20-258` | Passes `updater` to the view (`:64`), refits the window on `card?.layout` (`:48`, `:84`). |
| `LauncherActions` | `UI/LauncherActions.swift:20-34` | **Does not touch `Updater` at all.** It only carries the `quit` closure (`:33`). |
| `AppDelegate.makeUpdater` | `App:46-57` | The one place the real updater is built. |

## Flow

### 1. Composition, at process start

1. `applicationWillFinishLaunching` (`App:28`) reads `ThisCopy.location()` (`:31`) and computes `Placement` from `CodeSignature.buildOfThisProcess(arguments:)` (`:32-33`).
2. `makeUpdater(placement:location:)` (`App:35`, `:46-57`):
   - `CodeSignature.developerIDSigner()` (`:47`).
   - `InstalledRelease(placement:, developerIDSigned: signer != nil, version: ThisCopy.version(), macOS: ThisCopy.macOS())` (`:49-51`).
   - On success, `Updater(installed, releases: GitHubReleases(), installer: ApplicationsUpdater(replacing: location.running, signer: signer))` (`:54-56`).
3. `updater` goes to `Lifecycle` (`App:38`) and into the `makeResident` closure (`:39`), then to `Launcher` (`:85`) and `SettingsShell` (`:86`), which gives it to `SettingsView` (`UI/SettingsShell.swift:64`).
4. `Lifecycle.init` sets `updater?.onReplaced` (`Core/Lifecycle.swift:177`).

The `Updater` is built in `applicationWillFinishLaunching`, **before** `Lifecycle.launched` decides the route. It exists even in a process about to take route `.end` (an `.atLogin` start with an older copy running, `Core/Lifecycle.swift:20`, `:186`) or one still in `.replacingOthers`. That is harmless today because it does nothing until a window opens. Inferred: a replacement that starts checking on its own must start only from a resident, for example in `Lifecycle.othersExited` (`Core/Lifecycle.swift:257-265`).

### 2. The check

1. `Launcher.openedByHand` (`Core/Launcher.swift:214`) computes `opens = window == .closed` (`:224`), and calls `updater?.windowOpened()` only on that edge (`:230`). Opening happens from `Lifecycle.othersExited` (`:262`) or `Lifecycle.openedAgain` (`:197`).
2. `Updater.windowOpened` (`Core/Updater.swift:60-66`): returns if `isInstalling`, otherwise takes a new ticket, sets `.checking` first (an in-memory list may answer inline), and calls `releases.fetch`.
3. `GitHubReleases.fetch` (`Platform/GitHubReleases.swift:23-27`) calls `list` (`:30-37`) with a fresh ephemeral session. A plain GET to `https://api.github.com/repos/domasgru/trackpad-launcher/releases` (`:9`), no query string. Failure of any kind yields `[]` (`:26`).
4. `parse` (`:124-130`) keeps elements with `draft == false` and `prerelease == false`, taking the first asset for which `counted` (`:132-139`) holds: `state == "uploaded"`, `browser_download_url` starts with `https://github.com/domasgru/trackpad-launcher/releases/download/` (`:10`), and the name parses with `archiveName` (`:142-150`), `TrackpadLauncher-<version>-macOS-<minimum>.aar`. Tag, title and body are ignored.
5. `Updater.checked` (`Core/Updater.swift:113-116`) drops a stale ticket, otherwise applies `Release.newerVersion` against `installed.version` and `installed.macOS`, going to `.offering` or `.idle`.
6. `card` (`:39-47`) changes, SwiftUI redraws (`UI/SettingsView.swift:41`), and the `Fit` observation refits the window (`UI/SettingsShell.swift:77-91`).

`Launcher.closeWindow` (`Core/Launcher.swift:234-238`) calls `updater?.windowClosed()`, which drops any check and any offer, and cancels a download, but leaves an install alone (`Core/Updater.swift:70-78`).

### 3. Download

1. *Update now* or *Try again* calls `UpdateCardView.updateNow` (`UI/UpdateCardView.swift:15`, `:23`), which is `{ updater?.updateNow() }` from `UI/SettingsView.swift:42`.
2. `Updater.updateNow` (`Core/Updater.swift:81-90`) works from `.offering` or `.failed` only. New ticket, `.downloading(progress: 0)`, then `installer.update(to:)`.
3. `ApplicationsUpdater.update` (`Platform/ApplicationsUpdater.swift:37-57`) bumps `attempt`, and starts a `Task` calling `download` (the shipped value is `GitHubReleases.ArchiveDownload(stall: 30).archive`, `:25`).
4. `ArchiveDownload.archive` (`Platform/GitHubReleases.swift:50-68`) receives into memory with `session.data(for:delegate:)`. `ByteWatcher` turns the task's `countOfBytesReceived` KVO into whole percents, and cancels the task above `archiveSize`. The result must be status 200 and exactly `archiveSize` bytes. `timeoutIntervalForRequest = 30` is the idle timeout, so no timer of ours is involved.
5. `Updater.progressed` (`Core/Updater.swift:118-134`) drops stale tickets and updates progress.

*Cancel* goes through `Updater.cancel` (`:93-97`) to `.offering` and `cancelDownload()`. `ApplicationsUpdater.cancelDownload` (`Platform/ApplicationsUpdater.swift:59-63`) is a no-op past the download.

Two independent stale guards exist: the `Updater` ticket, and the `ApplicationsUpdater.attempt` counter (`:20`, `:43`).

### 4. Install

After the download, `isPastDownload = true`, `.downloaded` fires (phase `.installing`), then `ApplicationsUpdater.install` runs off the main actor (`Platform/ApplicationsUpdater.swift:77-91`):

1. `BundleInstall.unpack(archive, near: bundle)` (`Platform/BundleInstall.swift:76-89`): a fresh `.itemReplacementDirectory` on the destination's volume (`:15-19`), extraction from a memory stream with AppleArchive (`:23-41`), each entry checked by `admits` (`:94-115`) before it is written, the first refusal cancelling. `admits` requires a relative path under `TrackpadLauncher.app`, no `.` or `..`, and only directories, regular files, or relative symlinks staying strictly inside the bundle. Quarantine is then cleared (`:150-159`).
2. `CodeSignature.isGenuine(staged, as: release, signer: signer)` (`Platform/CodeSignature.swift:60-82`). Failure discards the staged copy and reports `.failed`.
3. `ApplicationsInstaller.put(staged, at: bundle, by: administrator)` (`Platform/ApplicationsInstaller.swift:87-105`), mapped to `.installed`, `.declined` (from `.cancelled`) or `.failed` (`Platform/ApplicationsUpdater.swift:86-90`).

### 5. Hand-over

1. `.installed` sets `.opening` and calls `installer.openNewVersion` (`Core/Updater.swift:129-131`).
2. `ApplicationsUpdater.openNewVersion` (`Platform/ApplicationsUpdater.swift:65-74`): `activates = true`, `createsNewApplicationInstance = true`.
3. `Updater.opened(true)` calls `onReplaced`, which is `Lifecycle.replaced` (`Core/Lifecycle.swift:240-243`), which calls `end()`, which sets `.ending` and calls `copies.endThisCopy()`, which is `NSApp.terminate(nil)`. `opened(false)` goes to `.failed`, with /Applications already holding the new version, and *Try again* re-downloads (a same-version swap, comment `Core/Updater.swift:136-137`).
4. The new process: no login marker in the open event (`Platform/ThisCopy.swift:9-18`), so `.byHand`, so `Route.runWithWindow` (`Core/Lifecycle.swift:23`), so `replace(others, opensWindow: true)`. `SystemRunningCopies.stop` force-terminates any old process and waits on the kernel's exit source. Then `makeResident`, `launcher.start()`, and `launcher.openedByHand()` (`Core/Lifecycle.swift:257-265`).

Result: the settings window always opens on the new version, it activates, and the Dock icon shows.

### Quit interaction

- `Lifecycle.shouldEnd` (`Core/Lifecycle.swift:204-219`): a system request always ends. For `.other`, an open window closes and the process stays. With the window closed, it ends unless `updater?.isInstalling == true` (`:217`).
- `Lifecycle.quit` (`:233-237`) is a no-op while `isInstalling` (`:234`).
- The Quit button is disabled while `isInstalling` (`UI/SettingsView.swift:107`).

R13 requires Quit at once in any update state, so all three go.

## What decides each gate

### "Developer ID in /Applications"

`InstalledRelease.init?` (`Core/Update.swift:36-40`): `guard developerIDSigned, placement == .installed, let version`.

- `placement == .installed` comes from `Placement.init` (`Core/Placement.swift:42-50`): `!location.isTranslocated && isInside(location.running, /Applications)`.
  - `isInside` (`:54-58`) compares standardized path components, at any depth. `/ApplicationsOld` is not inside. `~/Applications` is not inside, so it is `.elsewhere` for a release build.
  - `.installed` does not look at the build. A development build in /Applications is `.installed` (`:35`), so the `developerIDSigned` term is what excludes it.
- `developerIDSigned` is `signer != nil`, from `CodeSignature.developerIDSigner()` (`Platform/CodeSignature.swift:36-44`): `SecCodeCopySelf`, then `SecCodeCheckValidity(me, [], requirement)`, then `SecCodeCopyStaticCode`, then read team and identifier from signing information. A missing team or identifier gives nil (`:91-97`).
- It takes no arguments, so `--as-release-build` cannot fake it, while `buildOfThisProcess` (`:14-22`) honours that flag for the move and login rules. A test pins the difference (`PlatformTests/CodeSignatureTests.swift:49-52`).
- The requirement (`:8-9`): `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists`.
- `version` is `ThisCopy.version()`, the `CFBundleShortVersionString` parsed by `Version` (`Platform/ThisCopy.swift:21-25`). The doc comment explains it is read once at start because `Bundle.main` would read the new bundle after a swap (`Core/Update.swift:30-31`).

R2's "copy showing the move dialog" already holds by construction: `Route.askToMove` comes only from `.elsewhere` (`Core/Lifecycle.swift:22`), and `.elsewhere` gets no `Updater`.

The moved copy qualifies because a move opens a new process (`Core/Lifecycle.swift:278-281`), which runs `makeUpdater` itself from /Applications.

### "Can write to its own bundle"

**Nothing decides this at start.** No gate reads it, and Core has no such concept. The only check is at swap time, `ApplicationsInstaller.put` (`Platform/ApplicationsInstaller.swift:89-91`):

```swift
let canWrite =
    files.isWritableFile(atPath: destination.deletingLastPathComponent().path)
    && (!files.fileExists(atPath: destination.path) || files.isWritableFile(atPath: destination.path))
```

So it needs the **parent folder** and the **bundle directory** writable, neither recursive. When false, `PrivilegedInstall.swap` runs and prompts. A standard account today reaches the prompt after the download and verification.

R12 needs a new predicate, read at start, never prompting. The existing expression is the only precedent. R12's words are "its own bundle"; the code's rule also requires the parent, which is what the atomic swap needs. Inferred: a directory moved across parents needs write on itself, and the exchange needs write on the parent.

### What `isGenuine` checks

`Platform/CodeSignature.swift:60-82`:

- Team and identifier contain no `"` or `\` (`:61-63`).
- Requirement text: the Developer ID requirement, plus `certificate leaf[subject.OU] = "<team>"`, `identifier "<identifier>"`, and `notarized` (`:65`).
- `SecStaticCodeCheckValidity` with `kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | noNetworkAccess` (`1 << 29`, not imported into Swift) (`:72-75`). Resources are validated (the default, no `DoNotValidateResources`). `notarized` is satisfied by the stapled ticket rather than the network.
- The sealed Info.plist's `CFBundleShortVersionString` and `LSMinimumSystemVersion` equal the offered release's exactly (`:76-81`).

Client-side protections that exist today and that R6 does not name. A replacement keeps or knowingly drops each:

| Protection | Where |
|---|---|
| `notarized` checked on the client | `CodeSignature.swift:65` |
| The bundle's version and minimum macOS equal the offer | `CodeSignature.swift:81` |
| Strict validation of nested code and all architectures | `CodeSignature.swift:73-75` |
| Archive entries filtered before they are written | `BundleInstall.swift:94-115` |
| Quarantine cleared on every item | `BundleInstall.swift:150-159` |
| Download URL prefix pinned to this repository | `GitHubReleases.swift:10`, `:134` |
| Exact byte length | `GitHubReleases.swift:64-66`, `:97` |
| Archive held in memory only, so a kill leaves nothing on disk | `GitHubReleases.swift:39-42` |
| Constant headers, across the redirect too | `GitHubReleases.swift:11`, tested at `PlatformTests/ApplicationsUpdaterTests.swift:355` |

Current constant headers: `User-Agent: TrackpadLauncher`, `Accept-Language: en`, `X-GitHub-Api-Version: 2022-11-28`, plus `Accept`.

## Every call site of each update port and `Updater` member

### `UpdateInstaller`

| Method | Production caller | Implementations | Direct test callers |
|---|---|---|---|
| `update(to:events:)` | `Core/Updater.swift:87` | `ApplicationsUpdater.swift:37`, `InMemoryAdapters.swift:722` | `ApplicationsUpdaterTests.swift:108, 293, 324, 406, 434, 478, 588, 663` |
| `cancelDownload()` | `Core/Updater.swift:74` (`windowClosed`), `:96` (`cancel`) | `ApplicationsUpdater.swift:59`, `InMemoryAdapters.swift:731` | `ApplicationsUpdaterTests.swift:281, 310, 325, 347` |
| `openNewVersion(then:)` | `Core/Updater.swift:131` | `ApplicationsUpdater.swift:65`, `InMemoryAdapters.swift:733` | none: the real adapter's method has no direct test |

### `ReleaseList`

| Method | Production caller | Implementations |
|---|---|---|
| `fetch(then:)` | `Core/Updater.swift:65` | `GitHubReleases.swift:23`, `InMemoryAdapters.swift:677` |

### `Updater` members

| Member | Callers |
|---|---|
| `init` | `App:54`, `CoreTests/LifecycleWorld.swift:152` |
| `card` | `UI/SettingsView.swift:41`, `UI/SettingsShell.swift:84`, `LifecycleWorld.swift:142` |
| `isInstalling` | `Core/Updater.swift:61`, `Core/Lifecycle.swift:217`, `:234`, `UI/SettingsView.swift:107`, `LifecycleWorld.swift:143` |
| `windowOpened()` | `Core/Launcher.swift:230` |
| `windowClosed()` | `Core/Launcher.swift:237` |
| `updateNow()` | `UI/SettingsView.swift:42` (invoked via `UpdateCardView.swift:15`, `:23`), `LifecycleWorld.swift:251` |
| `cancel()` | `UI/SettingsView.swift:42` (invoked via `UpdateCardView.swift:17`), `LifecycleWorld.swift:256` |
| `onReplaced` | set `Core/Lifecycle.swift:177`, called `Core/Updater.swift:140` |

`Updater?` is held at `Core/Lifecycle.swift:145`, `Core/Launcher.swift:85`, `UI/SettingsShell.swift:24`, `UI/SettingsView.swift:15`, and is an init parameter at `Lifecycle.swift:169`, `Launcher.swift:90` (both default nil), `SettingsShell.swift:51`, `App:79`.

`SettingsShell.updater` (`:24`) is stored but never read outside `init`, where the parameter of the same name is what is used.

### Helpers behind the ports

| Symbol | Callers |
|---|---|
| `InstalledRelease.init?` | `App:49`, `LifecycleWorld.swift:100`, `:102`, `InstalledReleaseTests.swift` |
| `Release.newerVersion` | `Core/Updater.swift:115` |
| `CodeSignature.developerIDSigner()` | `App:47`, `CodeSignatureTests.swift:50` |
| `CodeSignature.developerIDSigner(of:)` | tests only (`CodeSignatureTests.swift:73, 81, 85`) |
| `CodeSignature.build(of:)` | tests only (`CodeSignatureTests.swift:12, 45`) |
| `CodeSignature.buildOfThisProcess` | `App:33`, tests |
| `CodeSignature.isGenuine` | `ApplicationsUpdater.swift:82`, `CodeSignatureTests.swift` |
| `ThisCopy.version()` | `App:50` |
| `ThisCopy.macOS()` | `App:51` |
| `ThisCopy.version(of:)` | `ThisCopy.swift:21`, `ThisCopyTests.swift:19-36` |
| `BundleInstall.unpack` | `ApplicationsUpdater.swift:81`, `BundleInstallTests.swift` |
| `BundleInstall.admits` | `BundleInstall.swift:54`, `BundleInstallTests.swift` |
| `BundleInstall.stage` | `ApplicationsInstaller.swift:77`, `PrivilegedInstallTests.swift` |
| `BundleInstall.swap` | `ApplicationsInstaller.swift:95` |
| `BundleInstall.discard` | `ApplicationsInstaller.swift:103`, `ApplicationsUpdater.swift:83`, `BundleInstall.swift:67`, `:129` |
| `BundleInstall.removeOriginal` | `ApplicationsInstaller.swift:36` |
| `ApplicationsInstaller.put` | `ApplicationsInstaller.swift:81`, `ApplicationsUpdater.swift:86`, `PrivilegedInstallTests.swift` |
| `PrivilegedInstall.swap` | `ApplicationsInstaller.swift:101` |
| `AuthorizationAdministrator()` | `ApplicationsInstaller.swift:12`, `ApplicationsUpdater.swift:24` |

## What must be deleted (assuming the whole hand-written path goes)

### Whole source files

- `Core/Updater.swift`, if the Sparkle design keeps no model of this name. Any new model replaces it, but none of this state machine survives R5, R13 or R15.
- `Core/Update.swift`. `Release`, `UpdateEvent` and `UpdateCard` have no remaining use. `InstalledRelease` is the gate and is a design decision: R2 and R12 still need a gate, and `CoreTests/LifecycleWorld.swift:91-105` and `InstalledReleaseTests` go through it.
- `Core/Version.swift`, if nothing else adopts it. Every non-update use is gone with these files: `Copy.swift:21-25`, `GitHubReleases.swift`, `CodeSignature.swift:78-79`, `ThisCopy.swift:21-30`. Its only other job would be `InstalledRelease.version`.
- `Platform/GitHubReleases.swift`.
- `Platform/ApplicationsUpdater.swift`.
- `UI/UpdateCardView.swift`.

### Parts of source files

| File | Remove | Keep |
|---|---|---|
| `Core/Ports.swift` | `:204-228` | everything else |
| `Core/Copy.swift` | `:20-27` (`cancelButton` and `tryAgainButton` have no other source user) | `:11-18`, including the two strings `PrivilegedInstall.swap` uses |
| `Core/Lifecycle.swift` | `updater` at `:145`, `:169`, `:175`, `:177`; `replaced()` `:239-243`; `:216-217` becomes `return true`; `:234` guard term | rest |
| `Core/Launcher.swift` | `:85`, `:90`, `:93`, `:229-230`, `:237` | the `opens` edge at `:224` and `closeWindow`'s guard, which are exact window edges a new idle rule could use |
| `UI/SettingsShell.swift` | `:24`, `:48`, `:51`, `:53`, `:64` argument, `:84`, comment `:86` | rest of `Fit` |
| `UI/SettingsView.swift` | `:15`, `:41-46`, `:107`; comments `:5`, `:18`, `:22`; `FormRow` `:131-141` (its only user is `UpdateCardView.swift:29`) | `FormGroup` `:120-129`, used by `SettingsNotice` `:296` |
| `Platform/BundleInstall.swift` | `import AppleArchive`, `import System`, `archivedBundleName` `:10-12`, `extract` `:21-41`, `admitted` `:43-55`, `unpack` `:73-89`, `admits` `:91-115`, `ArchiveEntryKind` `:162`, `MemoryStream` `:164-192` | see below |
| `Platform/CodeSignature.swift` | `isGenuine` `:56-82` | see below |
| `Platform/ThisCopy.swift` | `version()` and `version(of:)` `:20-25`, `macOS()` `:27-31`, if `Version` goes | `launch`, `opening`, `location`, `Translocation` |
| `App` | `:35`, the `updater:` argument at `:38`, the `updater` at `:39`, `:43-57`, `:79`, `:85`, `:86` | rest |

`CodeSignature`: `developerIDSigner()`, `signer(of:)`, `signingInformation`, and `Signer` are needed only if the gate keeps asking for the signer. The gate only needs a Bool (`signer != nil`, `App:50`). The strongest form to keep is a Developer ID check that takes no arguments, because of `--as-release-build`.

### Tests and fixtures

Delete whole:

- `CoreTests/UpdateCheckTests.swift`
- `CoreTests/UpdateInstallTests.swift`
- `PlatformTests/ApplicationsUpdaterTests.swift` (including `ShippedUpdaterStallTests`)
- `PlatformTests/GitHubReleasesTests.swift`
- `PlatformTests/BundleInstallTests.swift`: every test is `admits` or `unpack`
- `PlatformTests/LocalReleaseServer.swift`: only those two suites use it
- `PlatformTests/CraftedArchive.swift`: only `ApplicationsUpdaterTests` uses it
- `PlatformTests/UpdateFixtures.swift` and `PlatformTests/UpdateFixtures/` (both apps, the `.aar`, `fixture.json`), unless a new test wants a notarised Developer ID app
- `Scripts/make-update-fixtures.sh`
- `CoreTests/VersionTests.swift`, if `Version` goes
- `CoreTests/InstalledReleaseTests.swift`, if `InstalledRelease` goes, otherwise rewrite

Edit:

- `CoreTests/InMemoryAdapters.swift`: remove `InMemoryReleaseList` and `InMemoryUpdateInstaller` (`:671-761`).
- `CoreTests/LifecycleWorld.swift`:
  - `:76-77` hooks, `:91-105` `RunningBuild`, `:107-115` `Release.version`, `:123`, `:127-129`, `:135-136` and `:139-143` (`Published.card`, `card`, `isInstalling`), `:149-152`, `:159`, `:168`, `:173`, `:175-191`, `:250-288`.
  - `launch(running:)` at `:71`, `login(running:)` at `:86`.
  - Only `UpdateCheckTests` and `UpdateInstallTests` pass `running: .release`. `installedAt` is shared with `MoveToApplicationsTests.swift:250` through `InMemoryInstaller.onInstalled` (`:75`), so it stays.
- `CoreTests/CopyTests.swift:26-35`.
- `PlatformTests/CodeSignatureTests.swift`: `:77-92` and `:94-120`, and `:49-52`, `:58-75` depending on what stays.
- `PlatformTests/ThisCopyTests.swift:19-36`, if `Version` goes.
- `PlatformTests/BundleFixture.swift`: `archive` `:119`, `archiveEverything` `:129`, `newMarker` `:137`, `unpackedBundles` `:143`, `copies(carrying:)` `:154`, `bundles(identifiedBy:)` `:161`, and the `marker` parameter of `makeBundle` `:31` lose all users. `BundleFixture.swift` itself stays.
- `CoreTests/SourcePolicyTests.swift`, see below.

### `SourcePolicyTests` entries that go stale

- Bans about the archive: `downloadTask` `:33` and `.download(` `:34`. Removing them also needs the `required` set at `:206-212` edited, because `theNetworkBansAreAllStillListed` requires both.
- Confined to a deleted file, passing vacuously afterwards:
  - `URLSession` `:110`
  - `http` `:112`
  - `createsNewApplicationInstance` `:189`
- Confined to code that disappears from `BundleInstall.swift`: `AppleArchive` `:178`, `ArchiveStream` `:180`, `ArchiveByteStream` `:182`.

Confinements that stay true because the move still uses them: `copyItem(`, `moveItem(`, `renamex_np(`, `removeItem(`, `removexattr`, `itemReplacementDirectory`, `/bin/mv`, `osascript`, `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights`.

### Docs that describe the deleted behaviour

- `docs/architecture.md:11, 12, 20, 27, 30, 36`
- `docs/domain-model.md:12` (opening by hand mentions an update), `:21` (Quit), `:32-52` (*Update check*, *Newer version*, *Update card*)
- `docs/product-overview.md:8`
- `README.md:17-18, 34, 39, 72`
- The header of `Scripts/release.sh:8-9` ("the next time its settings window opens")

## What the move-to-Applications flow uses, and so must stay

| Stays | Why |
|---|---|
| `Installer` port, `ApplicationsInstaller` whole | The move itself (`Core/Lifecycle.swift:226`, `:277-280`). `put` stays; only comment `:84` needs an edit. |
| `PrivilegedInstall`, `Administrator`, `AdministratorResult`, `AuthorizationAdministrator` whole | `put`'s fallback at `ApplicationsInstaller.swift:101`, `Copy` strings at `:47`, `:49`. Updates will never reach them under R12, but the move still does. |
| `BundleInstall`: `quarantine`, `newFolder`, `stage`, `swap`, `discard`, `removeOriginal`, `clearQuarantine` | `stage` `:59-71` uses `newFolder`, `clearQuarantine`, `discard`. |
| `CodeSignature.buildOfThisProcess`, `requirement()`, `developerID` | `Placement`'s build input (`App:33`). |
| `ThisCopy.launch`, `opening`, `location`, `Translocation`; `DiskImages` | Openings, placement, eject. |
| `Placement`, `Build`, `Location`, `Route`, `MoveDialog`, `InstallOutcome` | The move and every start. |
| `Copy.cannotWriteToApplications`, `Copy.applicationsFolderNotChanged`, move strings | `Core/Copy.swift:11-18`. |
| `InMemoryInstaller`; `ApplicationsInstallerTests`, `PrivilegedInstallTests` (including `TestAdministrator`, `PrivilegedSwapAtomicityTests`), `MoveToApplicationsTests`; `BundleFixture` core | They pin the move. `TestAdministrator` is defined in `PrivilegedInstallTests.swift:9` and is also used by `ApplicationsInstallerTests`. |

`BoundedWait.swift`, `OwnThread.swift` and `ProcessWait.swift` stay: `awaiting` has users outside the update suites.

## Boundaries

- **In:** the window's two transitions from `Launcher`; `onReplaced` from `Lifecycle`; `updateNow` and `cancel` from the view; `Placement`, `Location`, and signature facts at start.
- **Out to the network:** `api.github.com/repos/domasgru/trackpad-launcher/releases`, then the release asset under `github.com/.../releases/download/`.
- **Out to disk:** a staging folder beside /Applications, then the swap at `location.running`. The update always goes over the running copy's own path, whatever its name (`Platform/BundleInstall.swift:10-11`), which can be `Trackpad Launcher.app`, `TrackpadLauncher.app`, or nested.
- **Out to macOS:** `AuthorizationExecuteWithPrivileges`, `NSWorkspace.openApplication`.
- **Out to `Lifecycle`:** `isInstalling`, `onReplaced`.
- **Persisted state:** none. `Updater` writes no defaults. `UpdateInstallTests.swift:94-95` pins the suite domain unchanged across an update, and `:91-92` pins no login-item call and no permission ask.
- **Release process contract:** `Scripts/release.sh:39-42`, `:184-236`, `:413` produce and publish the `.aar`, which is what shipped copies read.
- **Module rules:** `LauncherCore` may import only Foundation and Observation (`SourcePolicyTests.swift:315-321`), so any Sparkle import cannot be in Core. `LauncherKit/Package.swift` has no external package today, and `project.yml` has no Sparkle.

## Non-Obvious Things

1. **The `.aar` contract outlives its code (R16).** Deleting `GitHubReleases.archiveName`, `BundleInstall.admits` and `isGenuine` removes the implementation, but shipped copies keep those exact rules. `Scripts/release.sh`'s `archive_and_check` and `gh release create ... "$DMG" "$AAR"` must stay. After deletion nothing in the repo tests what an older copy would accept, because the script's self-check is weaker than the shipped code:
   - It uses `aa extract` and `codesign --verify --strict --deep`, not `admits`, and not the `notarized` requirement text.
   - `admits` refuses absolute or escaping symlinks and anything other than a directory, file or link. A framework's relative version links pass by reading the logic (a link at `.../Sparkle.framework/Sparkle` to `Versions/Current/Sparkle` resolves inside). Sparkle.framework's real entries were not inspected in this repo.
   - An older copy also runs strict nested-code validation over the embedded framework, offline, requiring the stapled ticket (`CodeSignature.swift:65`, `:73-75`).
2. **New assets do not disturb older copies.** `parse` takes the first asset that `counted` accepts and skips any other name (`GitHubReleases.swift:128`, `:132-139`). A `.zip` or appcast beside the `.aar` is ignored. A release with no valid `.aar` is simply invisible to them.
3. **A relaunch reads as an opening by hand.** `Opening` has only `.atLogin` and `.byHand` (`Core/Lifecycle.swift:5-10`). Anything without the login marker is `.byHand`, and for an `.installed` copy that is `.runWithWindow`. There is no silent-by-hand route. `UpdateInstallTests.swift:84` pins the window opening on the new version.
4. **`.atLogin` is not a safe way to be silent.** `Route` sends `(.atLogin, _, true)` to `.end` (`Core/Lifecycle.swift:20`): a new copy marked login that sees the older process still running ends itself. `--eject-disk-image` (`Platform/ThisCopy.swift:10`) is the precedent for one process telling the next something through arguments.
5. **Every start other than route `.end` stops other copies.** `replace` runs for `.runSilently` too (`Core/Lifecycle.swift:188`), so the "new version stops the old one" half of R9 exists on the silent route as well, provided the route is reached.
6. **`createsNewApplicationInstance` matters.** Without it the old process only gets a reopen (`ApplicationsUpdater.swift:68-69`).
7. **The sudden-termination rule exists because of updates.** `docs/architecture.md:11` and `SourcePolicyTests.swift:14-18`, `:95-97`: the opened copy is a LaunchServices child of the old one, and loginwindow can force-quit it 3 s later if it declares sudden termination. The scan covers our Swift and `project.yml` only, not a binary framework.
8. **Source policy bans constrain the replacement.** `SourcePolicyTests.banned` scans every `.swift` line under `Sources/` and `TrackpadLauncher/` for substrings: `Timer` (`:52`), `asyncAfter`, `Task.sleep`, `makeTimerSource`, `import Network` (`:45`), `NWConnection`, `print(`, `Process()`. A 1-minute idle rule (R8) or a network-arrival trigger (R1) in our Swift would need the rule changed or would have to live in Sparkle. `docs/architecture.md:20` states the no-timers rule as architecture. Binary frameworks and `Info.plist` values are not scanned, so an `https` feed URL in `project.yml` does not hit the `http` confinement, while one in Swift does.
9. **`docs/architecture.md:27-30` lists every file the app may write.** A staged download or Sparkle's own files and defaults change that list.
10. **`CFBundleShortVersionString` decides today, not `CFBundleVersion`.** `Version` compares the marketing version. `Config/Version.xcconfig` holds `MARKETING_VERSION = 1.0.14` and `CURRENT_PROJECT_VERSION = 15`, and they are different numbers. Anything comparing the build number must use that one.
11. **Minimum macOS comes from the asset's file name**, then is cross-checked against the sealed plist. `ThisCopy.macOS()` includes the patch number, so 26.6.2 against 26.6.3 matters (`UpdateCheckTests.swift:140-141`).
12. **A failed check is silent, and a closed window erases everything.** No retry exists at all: `checked` with `[]` goes to `.idle`. R1's retry has no precedent here.
13. **`waitsForConnectivity = false`** (`GitHubReleases.swift:162`): a request made offline fails at once.
14. **Fixture identity differs from the app.** `com.domasgru.TrackpadLauncherUpdateFixture`, version 1.0.0 (`Scripts/make-update-fixtures.sh:18-19`). `Contents/CodeResources` inside the Developer ID fixture is the stapled ticket location. Regenerating needs `NOTARY_PROFILE`. Nothing in the Makefile, `release.sh`, README or `docs/architecture.md` calls the script; only test skip messages name it.
15. **`LauncherActions` is a red herring.** The Quit button's action is the closure from `App:86` (`lifecycle.quit()`), through `SettingsShell.makeActions` (`:233-257`). Its disabled state comes straight from `updater`, not from the actions.

## Files Read

- `plans/039-auto-updates/plan.md`, `plans/039-auto-updates/development-logs.md`
- `LauncherKit/Package.swift`, `project.yml`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Version.xcconfig`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- Core: `Updater.swift`, `Update.swift`, `Version.swift`, `Ports.swift` (`:155-228`), `Placement.swift`, `Lifecycle.swift`, `Copy.swift`, `Launcher.swift` (`:75-135`, `:205-260`)
- Platform: `GitHubReleases.swift`, `ApplicationsUpdater.swift`, `BundleInstall.swift`, `PrivilegedInstall.swift`, `CodeSignature.swift`, `ThisCopy.swift`, `ApplicationsInstaller.swift`, `DiskImages.swift`, `SystemRunningCopies.swift` (`:1-80`)
- UI: `UpdateCardView.swift`, `LauncherActions.swift`, `SettingsShell.swift`, `SettingsWindow.swift`, `SettingsView.swift` (`:1-150`, `:285-320`)
- CoreTests: `UpdateCheckTests.swift`, `UpdateInstallTests.swift`, `InMemoryAdapters.swift` (`:560-775`), `LifecycleWorld.swift` (`:60-295`), `SourcePolicyTests.swift`, `CopyTests.swift` (`:20-40`)
- PlatformTests: `UpdateFixtures.swift`, `UpdateFixtures/fixture.json`, `ApplicationsUpdaterTests.swift` (`:1-140`, `:380-500`, `:640-678`), `CodeSignatureTests.swift` (`:1-60` and grep), `CraftedArchive.swift` (`:1-20`), test lists of the other suites by grep
- `Scripts/make-update-fixtures.sh`, `Scripts/release.sh` (`:1-140`, `:184-236`, `:405-420`), `Scripts/test.sh`, `Makefile`
- `docs/architecture.md`, `docs/domain-model.md`, `docs/product-overview.md`, `README.md` (update-related lines only)

## Open Questions

- **Sparkle behaviour was not in scope and is not established here.** In particular: how it handles an archive whose bundle name differs from the installed one (`TrackpadLauncher.app` versus `Trackpad Launcher.app`), what headers it sends, what it writes to defaults and disk, whether it enables or depends on sudden termination, and how it treats a standard account.
- **Does the shipped `admits` accept every entry of a real Sparkle.framework?** By reading, relative links inside the bundle pass and non-file entries are refused, but no real framework was run through it. A check needs the real binary from 1.0.14, or at least `BundleInstall.unpack` before it is deleted.
- **Does an older copy's strict `isGenuine` pass a bundle with an embedded Sparkle.framework?** That depends on how the release signs nested code. `release.sh:15-16` leaves signing to xcodebuild. Not tested.
- **Should `InstalledRelease`, `Version` and `Signer` survive?** It depends on the design. Their removal or reshaping is listed above; I did not decide it.
- **`PlatformTests/ApplicationsUpdaterTests.swift:140-380` and `:500-640`, `GitHubReleasesTests.swift`, and `BundleInstallTests.swift` were read through test names and grep, not line by line.** They are deleted as whole files, so this does not change the inventory, but individual assertions there are not summarised.
- **The GitHub list's page size** (no query string, so the server's default) is not stated in the repo. It bounds how many recent releases an older copy sees, which only matters if that many releases lack an `.aar`.
