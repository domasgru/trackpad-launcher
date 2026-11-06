# How the process lifecycle works (angle: process lifecycle)

All paths are relative to the worktree root unless marked otherwise. `Core/` = `LauncherKit/Sources/LauncherCore/`, `Platform/` = `LauncherKit/Sources/LauncherPlatform/`, `UI/` = `LauncherKit/Sources/LauncherUI/`, `Tests/` = `LauncherKit/Tests/`.

Sparkle facts come from upstream branch `2.x` (CHANGELOG head 2.10.1), read with `gh api`, cited as `Sparkle: <file>:<line>`. The strings of Sparkle 2.9.6 in `/Applications/Ghostty.app` hold the same selectors. Line numbers may drift with the version actually pinned. Nothing about Sparkle here was run; all of it is read from source. Other explorers own Sparkle proper; it is cited only where it hits the lifecycle.

Headline answers:

- A Sparkle relaunch reads as `.byHand`, so today it opens the settings window, a Dock icon and takes focus. Nothing in the launch event can tell it apart. A silent relaunch needs an out-of-band fact and a new route input.
- Sparkle ends the old process with a quit Apple event from `Updater.app`. It reads as `QuitRequest.other`, the same as the Dock's Quit. With the window closed `shouldEnd` says yes unless `isInstalling` is true. With the window open it closes the window and cancels.
- `updaterShouldRelaunchApplication:` returning NO aborts the install; it does not mean "install without relaunch".
- A refused quit leaves Sparkle's installer armed with relaunch = YES, which can break R13 later.
- A stage-3 install failure after the old process has ended relaunches nothing, which matters for R11.

## Components Found

| Name | Where | What it is |
|---|---|---|
| `Opening` | `Core/Lifecycle.swift:5-10` | Enum `.atLogin` / `.byHand`: how macOS started or reopened this process. |
| `Route` | `Core/Lifecycle.swift:13-26` | Pure table: `(Opening, Placement, olderCopyRuns)` to `.runSilently`, `.runWithWindow`, `.askToMove`, `.end`. |
| `Launch` | `Core/Lifecycle.swift:29-38` | One start: `opening` plus optional `diskImageToEject`. The existing way to carry an extra fact about a start. |
| `QuitRequest` | `Core/Lifecycle.swift:41-47` | `.system` (logout, restart, shutdown) or `.other` (Dock, AppleScript, Activity Monitor, another app). |
| `CopyID`, `RunningCopy` | `Core/Lifecycle.swift:49-65` | Another running copy: pid and `startedEarlier`. |
| `StartAtLogin` | `Core/Lifecycle.swift:72-107` | Owns "turn back on only what we turned off"; one defaults key, `startAtLoginTurnedOffByQuit` (line 76), beside `settings`, never inside it. |
| `MoveDialog`, `MoveAnswer`, `InstallOutcome` | `Core/Lifecycle.swift:110-121` | Move dialog state and answers. |
| `Lifecycle` | `Core/Lifecycle.swift:124-284` | `@MainActor @Observable`; the process state machine. Private `Stage` enum at 127-138. |
| `Launcher` | `Core/Launcher.swift:10-` | The gesture model. `start()` 110-127, `openedByHand()` 214-231, `closeWindow()` 234-238, `isWindowOpen` 23, `Window` 54-60. |
| `Updater` | `Core/Updater.swift:9-142` | Today's update model; `isInstalling` 51-56, `onReplaced` 30, `opened(_:)` 138-141. |
| `Placement`, `Location`, `Build`, `DiskImage` | `Core/Placement.swift:3-59` | `.installed` (inside /Applications at any depth, not translocated, any build), `.development`, `.elsewhere`. |
| `InstalledRelease` | `Core/Update.swift:32-41` | The one update gate: `developerIDSigned`, `placement == .installed`, version readable. |
| Ports `RunningCopies`, `LoginItem`, `Installer`, `UpdateInstaller`, `ReleaseList` | `Core/Ports.swift:167-176`, `179-187`, `190-202`, `206-220`, `223-228` | Lifecycle's and Updater's ports. |
| `TrackpadLauncherApp`, `AppDelegate` | `TrackpadLauncher/TrackpadLauncherApp.swift:6-13`, `17-113` | `@main` and the composition root; the only `NSApplicationDelegate`. |
| `ThisCopy` | `Platform/ThisCopy.swift:5-49` | Parses the launch event and arguments into `Launch`, `Opening`; reads version, macOS, location. |
| `QuitSignals` | `Platform/QuitSignals.swift:5-34` | Classifies a quit from the Apple event plus `willPowerOffNotification`. |
| `SystemRunningCopies` | `Platform/SystemRunningCopies.swift:4-93` | `others()`, `stop` (forceTerminate plus kernel exit sources), `endThisCopy` (`NSApp.terminate(nil)`). |
| `SystemLoginItem` | `Platform/SystemLoginItem.swift:6-22` | `SMAppService.mainApp` wrapper. |
| `RunningApp` | `Platform/RunningApp.swift:5-20` | Not a lifecycle type: builds an `AppEntry` from an `NSRunningApplication`. It has no part in process start or stop. |
| `ApplicationsInstaller` | `Platform/ApplicationsInstaller.swift:5-106` | The move into /Applications; `put` (87-105) is the swap shared with today's update. |
| `ApplicationsUpdater` | `Platform/ApplicationsUpdater.swift:9-92` | Today's unpack, verify, swap, open. `openNewVersion` 65-74. |
| `MoveDialogPresenter` | `UI/MoveDialogPresenter.swift:7-48` | Renders `lifecycle.moveDialog` as a modal `NSAlert`. |
| `SettingsShell` | `UI/SettingsShell.swift:20-258` | Renders `launcher.window`; the only place the activation policy changes (line 18 comment, enforced by source policy). |
| `AppActivation` | `UI/AppActivation.swift:19-23` | The one `activate(ignoringOtherApps:)`. |
| `LifecycleWorld`, `OneProcess`, `RunningBuild` | `Tests/LauncherCoreTests/LifecycleWorld.swift:8-89`, `117-295`, `93-105` | One Mac and its processes, over real `Lifecycle` and `Launcher` and in-memory adapters. |
| `InMemoryRunningCopies` | `Tests/LauncherCoreTests/InMemoryAdapters.swift:623-669` | Test double; `endThisCopy` asks `lifecycle.shouldEnd(.other)` (667), as AppKit's terminate would. |

## Flow

### 1. Boot, up to the point gestures work

Everything below runs synchronously on the main thread inside AppKit's launch callbacks.

1. `TrackpadLauncherApp.main()` builds `AppDelegate`, sets it, runs `NSApplication` (`TrackpadLauncherApp.swift:8-12`). `QuitSignals()` is a stored property (line 21), so the power-off observer exists before the run loop.
2. `applicationWillFinishLaunching` (28-41):
   - `NSApp.disableRelaunchOnLogin()` (30).
   - `ThisCopy.location()` (31) resolves translocation and disk image.
   - `Placement` from `CodeSignature.buildOfThisProcess` (32-33).
   - `StartAtLogin` (34).
   - `makeUpdater` (35, 46-57): `InstalledRelease` gate; nil unless Developer ID signed and `.installed`. **Built before the route is known**, so it exists even in a copy that will `.end`.
   - `Lifecycle(...)` (36-39). Its init wires `updater?.onReplaced` (`Lifecycle.swift:177`).
   - `MoveDialogPresenter` (40).
   - The launch event does not exist here: `currentAppleEvent` is nil in willFinishLaunching (comment `ThisCopy.swift:6`; plan 021 grounding F1, probed).
3. `applicationDidFinishLaunching` (60-64): `ThisCopy.launch(event:arguments:)` then `lifecycle.launched(launch)`, then the Debug tuner hook.
4. `Lifecycle.launched` (181-191): guard `.idle`; `copies.others()`; `Route(...)`; switch.
5. Route runs: `replace(others, opensWindow:, eject:)` (252-255) sets `.replacingOthers`, calls `copies.stop(others)`. With no others, `stop` calls back synchronously (`SystemRunningCopies.swift:35-38`).
6. `othersExited` (257-265): `makeResident()`, `launcher.start()`, `stage = .resident`, `openedByHand()` if `opensWindow`, then eject if asked.
7. `makeResident` (`TrackpadLauncherApp.swift:79-93`) builds `AppCatalog.system`, `WorkspaceActions`, `Launcher`, then `SettingsShell`.
   - `Launcher.init` does the first app read synchronously (`Launcher.swift:101`, `catalog.installedApps()`) and loads settings (102-105). `isFirstLaunch = stored == nil` (103).
   - `SettingsShell.init` does the first icon pass on the main actor (`SettingsShell.swift:54`), builds the window and hosting view (55, 64), the two switcher presenters (69-70), the main menu (75), and three observation tasks (77-103).
8. `Launcher.start()` (`Launcher.swift:110-127`): wires callbacks, starts a scan that runs off main (`SystemAppScanner.swift:21-31`), `reconcile()` (257-280), which calls `hardware.run(...)` (278). **Gestures are live when `hardware.run` returns**, inside `applicationDidFinishLaunching`. `start()` "asks nothing, opens nothing, saves nothing" (108-109).

**How long.** No measurement of launch-to-first-gesture exists in the repo. The nearest number is `docs/performance.md:54` (baseline 2026-10-17, heading at line 42): "Startup, first 6 s: 1078 ms, almost all in the first second", CPU time on the Mac15,6 (M3 Pro) named at line 31, measured by quitting, relaunching with `open` and sampling every 500 ms (line 25). The app has grown since. Inference: because gestures go live synchronously in the launch callback, startup takes on the order of a second on that machine when no other copy has to exit, comfortably inside R9's 10 s for the app's own share. The rest of R9's 10 s belongs to Sparkle's quit, swap and relaunch.

The wait for other copies has **no timeout** (`SystemRunningCopies.swift:28-31`). In `.replacingOthers` nothing senses: gestures are off until the last listed copy has exited. `forceTerminate` cannot be refused.

### 2. Classifying a start

`ThisCopy.opening(of:)` (`ThisCopy.swift:15-18`) is the only classifier: it reads `keyAEPropData` from the event and compares its enum code with `keyAELaunchedAsLogInItem` (`'lgit'`). Marker present is `.atLogin`. **Anything else, nil event included, is `.byHand`.** There is no third value. `.byHand` is the default bucket (`Lifecycle.swift:8`), not a positive signal.

`launch(event:arguments:)` (9-12) adds `--eject-disk-image <volume>`; any other argument is ignored. The test suite pins this (`Tests/LauncherPlatformTests/ThisCopyTests.swift:41-73`).

`Route` (`Lifecycle.swift:18-25`):

| Opening | Placement | Older copy runs | Route | What `launched` does |
|---|---|---|---|---|
| `.atLogin` | any | yes | `.end` | `end()`: terminate; stops nobody |
| `.atLogin` | any | no | `.runSilently` | `replace(others, opensWindow: false)`; stops *later* copies |
| `.byHand` | `.elsewhere` | any | `.askToMove` | `.askingToMove(resident: nil)`; stops nobody, no resident |
| `.byHand` | `.installed`, `.development` | any | `.runWithWindow` | `replace(others, opensWindow: true)`; stops every other copy |

Reopen. An open of the same path while that build runs starts no process; the running copy gets `aevt/rapp` (plan 021 F4, probed). `applicationShouldHandleReopen` (`TrackpadLauncherApp.swift:66-71`) calls `openedAgain` and returns false. `openedAgain` (`Lifecycle.swift:194-201`) computes the route with `olderCopyRuns: false`:

| Stage | Route | Result |
|---|---|---|
| `.replacingOthers` | `.runWithWindow` | Remembers `opensWindow: true`, keeps `eject` |
| `.resident` | `.runWithWindow` | `launcher.openedByHand()` |
| `.resident` | `.askToMove` | `.askingToMove(resident: launcher)`, gestures stay on |
| anything else, including `.atLogin` reopens | any | Nothing |

A different build at the same path, or another path, starts a second process even while one runs (F5, F6, probed). `Lifecycle` resolves those as starts, never as reopens.

What each class does downstream:

- **Login start**: resident with window closed. No enrol, no ask, no save, no `resume` (`openedByHand` never runs). `aLoginStartIsSilentAndLeavesTheSavedSettingsAlone` (`Tests/LauncherCoreTests/LifecycleTests.swift:47-64`).
- **By hand, installed or development**: resident then `Launcher.openedByHand()` (`Launcher.swift:214-231`): on the first opening in this process, a first run does `enrol`, Accessibility ask, `store.save`; any other run does `startAtLogin.resume()`. Then `window = .open(request:)`, rows resolve, scan, and `updater?.windowOpened()` on the edge from closed.
- **Reopen**: same `openedByHand()`; `openings > 0`, so only the window, rows, scan and check.

### 3. What a Sparkle relaunch would do today

Sparkle's agent (`Updater.app`, `LSUIElement` = 1 in its Info.plist) relaunches with a plain `[[NSWorkspace sharedWorkspace] openURL:fileURL]` (`Sparkle: Sparkle/InstallerProgress/InstallerProgressAppController.m:402`), then exits 0.3 s later (406-412). That passes no arguments and no launch options.

An `open`-style launch delivers `aevt/oapp` with no `keyAEPropData` and **sender = the app's own pid** (plan 021 F1, probed for `open`, not for `openURL` from another process). So the sender attribute does not help, and `NSApplication.launchIsDefaultUserInfoKey` is simply true. The exact code path:

1. `ThisCopy.opening` gives `.byHand` (`ThisCopy.swift:17`).
2. `Route(.byHand, .installed, _)` gives `.runWithWindow` (`Lifecycle.swift:23`).
3. `replace(others, opensWindow: true)` then `othersExited`, which calls `launcher.openedByHand()` (`Lifecycle.swift:262`).
4. `Launcher.window = .open(request: 1)` (`Launcher.swift:226`). On the first opening, `startAtLogin.resume()` runs (221). `updater?.windowOpened()` runs (230).
5. The shell's observation (`SettingsShell.swift:98-103`) calls `render(.open)` (151-165): `NSApp.setActivationPolicy(.regular)` (154) is the Dock icon; `window.makeKeyAndOrderFront(nil)` (163); `AppActivation.activateOverOtherApps()` (164) is the focus theft.

This is what `docs/domain-model.md:12` promises today: "by an update opening the new version" counts as opened by hand.

**What has to change so a relaunch is silent.** Facts first, then the implied changes. The design is the architect's.

- Nothing in the launch event or arguments can carry the fact: stock Sparkle relaunches with `openURL`, so the `--eject-disk-image` route used by the move has no equivalent. The fact has to be out of band, such as a defaults key written by the old process, or derived.
- The in-process hook: `updaterWillRelaunchApplication:` fires once per install (guarded by `_notifiedDelegateInstallationWillFinish`), from `installerWillFinishInstallationAndRelaunch:` when `relaunch` is YES, before the resume message goes to the installer (`Sparkle: Sparkle/SPUUpdateDriver.m:880-897`; `Sparkle/SPUInstallerDriver.m:549-558`). `updater:willInstallUpdate:` fires just before it.
- `StartAtLogin` is the direct precedent for one fact under its own key beside `settings` (`Lifecycle.swift:67-76`), and `Launch` is the precedent for handing a start's extra fact to `Lifecycle` (29-38). `SourcePolicyTests` confines `currentAppleEvent` to `ThisCopy.swift` and `TrackpadLauncherApp.swift`, and `keyAELaunchedAsLogInItem` to `ThisCopy.swift` (`SourcePolicyTests.swift:163-168`), so classification stays there.
- **Reusing `.atLogin` is wrong as it stands.** `Route(.atLogin, _, true)` is `.end` (`Lifecycle.swift:20`): a relaunched copy that saw any earlier copy (a Debug build, a hung old version) would end itself, leaving nothing or the wrong copy, and R9 says the new version MUST stop the old one. The relaunch needs "silent, and stop everyone": `.runSilently` with no `.end` branch. Today's `Route` has no input for that; `Opening` needs a third case, or `Launch` needs a fact that `launched` feeds into `Route`. `Route.init`'s `switch` is exhaustive, so the compiler forces the decision there; `openedAgain` has a `default`, so a silent route is already a no-op on reopen.
- Once the route is `.runSilently`, the rest is already silent, and no shell change is needed:
  - `launcher.window` stays `.closed`; `render(.closed)` returns at `guard isShown` (`SettingsShell.swift:144`).
  - The activation policy stays what `LSUIElement` gave, because the only `setActivationPolicy(.regular)` is in `render(.open)`.
  - `AppActivation` is called only from `render(.open)` and the move dialog.
  - `openedByHand` never runs, so no `resume`, no enrol, no Accessibility ask, no save.
  - `openings` stays 0, so a later real opening does a normal first opening: R9's "Opening by hand afterwards" holds (`aLoginStartOnAMacWithoutSettingsDoesNothingUntilOpenedByHand`, `LifecycleTests.swift:66-89`, is the same shape).
- Focus: the app is `LSUIElement`, so a cold LaunchServices launch does not make it active (`AppActivation.swift:5-8`; plan 034 logged `active=false key=false front=<previous app>`). No window means no activation call. Sparkle's agent activates itself only in `showProgress` (`Sparkle: InstallerProgressAppController.m:417-425`), which is reached only with `showUI` true; the immediate handler passes `displayingUserInterface:NO` (`Sparkle: SPUUpdateDriver.m:866`).
- The marker must be one-shot and must survive being stale (see Non-Obvious 6): a by-hand opening must still open the window after any failed or interrupted relaunch.
- Debug: `showAnimationTuner(for:)` compares `opening == .byHand` (`TrackpadLauncherApp.swift:99`); a new case stays closed, which is right.

### 4. How the old process ends after an update today

1. `ApplicationsUpdater.update` runs download, then `install` off main; `events(.installed)` lands on the main actor (`ApplicationsUpdater.swift:37-57`, `77-91`).
2. `Updater.progressed` moves `.installing` to `.opening` and calls `installer.openNewVersion` (`Updater.swift:129-131`).
3. `openNewVersion` (`ApplicationsUpdater.swift:65-74`): `activates = true`, `createsNewApplicationInstance = true`, because the default would only reopen the old process (comment at 68). The completion reports `app != nil`.
4. `Updater.opened(true)` calls `onReplaced?()`; `false` goes to `.failed` (`Updater.swift:138-141`).
5. `Lifecycle.replaced()`: guard `.resident`, then `end()` (`Lifecycle.swift:240-243`).
6. `end()` (246-249): `stage = .ending` **first**, then `copies.endThisCopy()`, which is `NSApp.terminate(nil)` (`SystemRunningCopies.swift:61`). AppKit calls `applicationShouldTerminate` synchronously; `shouldEnd` sees `.ending` and answers yes.
7. Meanwhile the new process is `.byHand`, `.installed`, so it `stop`s the old one with `forceTerminate`. Whichever comes first, the old process ends. `Updater.swift:136-137` states this; the `oldCopyAlreadyExited` argument of `updateNowDownloadsInstallsOpensTheNewVersionAndEndsTheOldOne` covers both orders (`UpdateInstallTests.swift:46-47`).

**How `Lifecycle` asks `Updater`.** Two reads and one callback, nothing else:

- `updater?.isInstalling != true` at `shouldEnd` (`Lifecycle.swift:217`), after the window check.
- The same expression at `quit()` (234).
- `updater?.onReplaced` set in `init` (177).
- `isInstalling` is true in `.installing` and `.opening` (`Updater.swift:51-56`). The view also reads it to grey the button (`UI/SettingsView.swift:107`).

### 5. Every way to quit

`applicationShouldTerminate` (`TrackpadLauncherApp.swift:73-75`) is the one gate: `lifecycle.shouldEnd(quitSignals.request(for: event)) ? .terminateNow : .terminateCancel`. Never `.terminateLater`. `event` is a computed property reading `currentAppleEvent` at call time (22). It is the quit event for a quit Apple event and **nil for a programmatic `NSApp.terminate(nil)`** outside an Apple event handler.

`QuitSignals.request` (`QuitSignals.swift:22-33`): `.system` if `kAEQuitReason` is present as attribute or param, or the sender pid's bundle id is `com.apple.loginwindow`, or `willPowerOffNotification` was seen. Otherwise `.other`, nil event included (`QuitSignalsTests.swift:52-57`).

`Lifecycle.shouldEnd` (`Lifecycle.swift:204-219`):

| Stage | `.system` | `.other` |
|---|---|---|
| `.ending`, `.idle`, `.replacingOthers`, `.askingToMove`, `.moveFailed` | yes | yes |
| `.moving` | yes | **no** |
| `.resident`, window open | yes | `closeWindow()`, **no** |
| `.resident`, window closed, not installing | yes | yes |
| `.resident`, window closed, `isInstalling` | yes | **no** |

Note the order in `.resident`: the window check comes before `isInstalling`, so during an install the first `.other` closes the window and the second refuses (`UpdateInstallTests.swift:202-220`).

| Way to quit | Path | Result |
|---|---|---|
| *Quit Trackpad Launcher* | `SettingsView.swift:105` to `actions.quit` to `{ lifecycle.quit() }` (`TrackpadLauncherApp.swift:86`) to `Lifecycle.quit()` (233-237): guard `.resident` and not installing; `startAtLogin.suspend()`; `end()` | Ends, login item off. Disabled during an install (`SettingsView.swift:107`). |
| Close Settings (⌘Q) | Menu item with `keyEquivalent: "q"` (`SettingsShell.swift:124`) to `closeSettings` (116) to `launcher.closeWindow()` | Window closes. **Never reaches `NSApp.terminate`**; no Quit menu item exists. |
| Close button, ⌘W, Escape, Close | `windowShouldClose` (111-114), `onCancel` (74), `SettingsView.swift:108` | `closeWindow()` |
| Dock Quit | Quit Apple event to `.other`, `.resident`, window open | Window closes, cancel. The Dock icon exists only with the window open. Closing while hidden is handled at `SettingsShell.swift:149-150`. |
| AppleScript, Activity Monitor, peer `terminate()` | `.other` | Window open: closes, cancels. Window closed: ends, unless installing. |
| Logout, restart, shutdown | `.system` | Ends in every stage. |
| Move dialog Quit, or cancelled admin prompt | `answer` (`Lifecycle.swift:227`), `installed(.cancelled)` (273) | `end()`, login item untouched |
| New version hand-over | `replaced()` | `end()`, login item untouched |
| Another copy opened by hand | `forceTerminate()` | Forced kill; no gate runs |

Only `Lifecycle.quit()` calls `startAtLogin.suspend()` on the quit path. **A hand-over must not go through `quit()`**, or it would turn starting at login off and break R10.

**Programmatic terminate, and what Sparkle actually does.** Sparkle's framework does not call `NSApp terminate:` (the selector `terminate:` is absent from the strings of the 2.9.6 framework binary). The request comes from another process:

- `AppInstaller` sends `sendTerminationSignal` to the agent after stage 2 (`Sparkle: Autoupdate/AppInstaller.m:756-770`).
- The agent calls `[runningApplication terminate]` on every running app with that bundle identifier **and** path (`Sparkle: InstallerProgressAppController.m:369-379`, match at 190-262). Its comment: "we are sending an Apple quit event, which gives the application or user a chance to delay or cancel the request".
- Plan 021 probed that a peer's `terminate()` "arrives exactly like the Dock's Quit" and reaches `applicationShouldTerminate` and can be cancelled (`plans/021-background-agent-lifecycle/development-logs.md:18`, grounding F18).

So in `QuitSignals` it has no quit reason, sender bundle id `org.sparkle-project.Sparkle.Updater`, hence `.other` unless power-off was announced. Under today's rules:

| Situation | Answer | Consequence |
|---|---|---|
| Resident, window closed, no `Updater` or `isInstalling` false | `.terminateNow` | Right result. `end()` is skipped and stage stays `.resident`; harmless, as nothing runs after terminate. Login item untouched. |
| Resident, window closed, `isInstalling` true | `.terminateCancel` | Sparkle is refused. If a new model keeps an "installing" flag with today's meaning, the update deadlocks against itself. |
| Resident, window open | `closeWindow()`, `.terminateCancel` | Refused, and the window the user just opened closes on them. R8's gate should keep this from happening, but the quit event is asynchronous, so a window can open between the gate passing and the event arriving. |
| `.replacingOthers`, `.askingToMove` | yes | Not reachable for an installed copy that is running Sparkle, if Sparkle starts only once resident. |

A hypothetical in-process `NSApp.terminate(nil)` from Sparkle or a new adapter gets a nil event, which reads `.other`, with the same table. Anything the app itself wants to end must go through `Lifecycle.end()` so `.ending` makes the answer yes; `.terminate(` is confined to `SystemRunningCopies.swift` (`SourcePolicyTests.swift:171`).

R13 requires *Quit Trackpad Launcher* to work "in any update state", so `Lifecycle.quit()`'s `isInstalling` guard (234) and `SettingsView.swift:107` both go against it as written.

### 6. Single-instance rule

- `others()` (`SystemRunningCopies.swift:14-26`): `NSRunningApplication.runningApplications` for the identifier family (release and `.debug`, `family(of:)` 81-85), minus own pid. `startedEarlier` uses `started(_:before:)` (89-92): launch date, missing date as latest, then lower pid; a strict total order, so two copies give mirror-image answers. Sparkle's `Autoupdate` (a plain tool) and `Updater.app` (a different bundle id) are not counted.
- `stop` (32-54): resolves live apps; none means synchronous callback. Otherwise a `DispatchSourceProcess(.exit)` on the main queue per pid, resumed **before** `forceTerminate()`, kept in `exitSources`, counted by `Remaining` so a duplicate is ignored. The kernel source replaced KVO on `isTerminated` after plan 035 (crash) and because KVO was seen never to arrive (comment 28-31).
- Port contract: "Stops each at once without asking: a copy can neither refuse, nor ask its user, nor hang the stop" (`Core/Ports.swift:170-172`).
- By hand from /Applications or as a development build: stop **everyone**, wait for all, then build the resident (`ReplacingOtherCopiesTests.swift:6-38`). Copies outside /Applications that ask to move stop nobody until the move succeeds (`Lifecycle.swift:278`).
- Login: the older copy wins. The newer ends and stops nobody; the older stops later ones (`ReplacingOtherCopiesTests.swift:91-106`).
- Sparkle's own view is narrower: it signals only the same identifier at the same path (or translocated) and watches only the *first* match (`InstallerProgressAppController.m:289-305`). A running Debug copy is outside its view but inside the app's rule.
- If a Debug or other-path copy opened by hand force-kills the /Applications copy while Sparkle's installer is waiting, the installer sees the target die and goes on to install (`AppInstaller.m:410-418`).

### 7. Activation policy, Dock icon, LSUIElement

- `LSUIElement: true`, `project.yml:39`. `TrackpadLauncher/Info.plist` is git-ignored and generated by xcodegen (`.gitignore`, `project.yml:32-40`). The shipped 1.0.14 plist has `LSUIElement => true` and no sudden termination key (read with `plutil`).
- No code sets the policy at start. The process is `.accessory` from the plist.
- Only `SettingsShell.render` changes it: `.regular` on opening from closed (154), `.accessory` on closing (148). Confined by `SourcePolicyTests.swift:157-159`.
- `render(.open)` runs on every request, ordering front and activating; `.closed` is a no-op when never shown (144).
- `AppActivation.activateOverOtherApps()` is the override, confined by `SourcePolicyTests.swift:148-150`, because plain `activate()` is refused on a cold launch. It must be called with a window on screen, hence the modal-mode `RunLoop.main.perform` in the presenter (`MoveDialogPresenter.swift:37-41`).
- `applicationShouldHandleReopen` returns false (70), so AppKit does nothing of its own.

### 8. Main actor and ports

- App target: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (`Config/Base.xcconfig`). `LauncherUI`: `.defaultIsolation(MainActor.self)` (`LauncherKit/Package.swift:17`). `LauncherCore` and `LauncherPlatform`: nonisolated by default (`docs/architecture.md:17`), with the models, ports and public adapters marked `@MainActor`.
- `@MainActor`: `Lifecycle`, `StartAtLogin`, `Launcher`, `Updater`, `QuitSignals`, `SystemRunningCopies`, `SystemLoginItem`, `ApplicationsInstaller`, `ApplicationsUpdater`. `ThisCopy` is nonisolated pure parsing. `MoveDialogPresenter` is main-actor by module default, and its `Task` inherits that; `runModal` blocks inside the task.
- Off main: `ApplicationsInstaller.copy` and `ApplicationsUpdater.install` (`@concurrent`), only `done` and `events` hop back. Exit sources and the power-off observer use the `.main` queue with `MainActor.assumeIsolated`.
- `Lifecycle` depends on: `Placement` (value), `RunningCopies` (port), `Installer` (port), `StartAtLogin` (concrete, over the `LoginItem` port and `UserDefaults`), `Updater?` (concrete, optional, default nil), `makeResident` (closure, `@MainActor () -> Launcher`). It knows no AppKit. `LauncherCore` imports Foundation and Observation only (`docs/architecture.md:12`).

### 9. How the tests drive it

- `LifecycleWorld` is one Mac: `World` (settings suite, login item, permissions, apps), a shared `EffectLog`, and `snapshots` taken around each lasting effect. `init(restoring:)` rebuilds a Mac from a snapshot, which is how the "kill at any effect" tests work (`LifecycleWorld.swift:45-59`; for example `UpdateInstallTests.swift:247-272`).
- `world.launch(_:others:alreadyExited:placement:running:diskImageToEject:)` (69-83) builds a `OneProcess` and calls `lifecycle.launched(Launch(...))`, exactly what `applicationDidFinishLaunching` passes. `world.login()` starts a process only if the login item is on (86-88).
- `OneProcess` builds a real `Lifecycle` and real `Launcher` and, for `.release(...)`, a real `Updater` through the real `InstalledRelease` gate (147-161). `.development` gets nil.
- Intents, each recording the window, card and `isInstalling` into `history`: `openAgain`, `letExit`, `letStoppedCopiesExit`, `deliverExitAgain`, `closeWindow`, `shouldEnd(_:)`, `answer`, `releaseInstall`, `quit`, `updateNow`, `cancel`, `progress`, `finishDownload`, `swapIn`, `decline`, `failUpdate`, `answerOpen`. `tap` drives gestures without recording.
- `QuitRequest` and `Opening` are injected directly, so `QuitSignals` and `ThisCopy` have their own suites over built descriptors (`QuitSignalsTests.swift`, `ThisCopyTests.swift`).
- `InMemoryRunningCopies.endThisCopy` calls `shouldEnd(.other)` and sets `hasEnded` only on yes (`InMemoryAdapters.swift:666-668`), reproducing AppKit's re-entry into the gate.
- Real-process coverage of `stop` is in `Tests/LauncherPlatformTests/SystemRunningCopiesStopTests.swift`, with LaunchServices-launched fixture apps.
- Suites that pin today's update flow through Lifecycle: `UpdateInstallTests`, `UpdateCheckTests`, and the update cases in `LifecycleWorld` (`Published.card`, `RunningBuild`, `Release.version`, `process.updates`).

## Files Read

- `plans/039-auto-updates/plan.md`, `plans/039-auto-updates/development-logs.md`
- `project.yml`, `Makefile`, `.gitignore`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `LauncherKit/Package.swift`
- `Core/Lifecycle.swift`, `Core/Updater.swift`, `Core/Placement.swift`, `Core/Ports.swift` (lifecycle ports), `Core/Launcher.swift` (1-132, 205-282), `Core/Update.swift` (gate and events)
- `Platform/ThisCopy.swift`, `Platform/QuitSignals.swift`, `Platform/SystemRunningCopies.swift`, `Platform/RunningApp.swift`, `Platform/SystemLoginItem.swift`, `Platform/ApplicationsInstaller.swift`, `Platform/ApplicationsUpdater.swift`, `Platform/SystemAppScanner.swift` (scan), `Platform/MultitouchTrackpads.swift` (run, first part), `Platform/CodeSignature.swift` (grep)
- `UI/MoveDialogPresenter.swift`, `UI/SettingsShell.swift`, `UI/SettingsWindow.swift`, `UI/AppActivation.swift`, `UI/AppIcons.swift` (renderOnMainActor), `UI/SettingsView.swift` (quit button)
- `Tests/LauncherCoreTests/LifecycleWorld.swift`, `LifecycleTests.swift`, `ReplacingOtherCopiesTests.swift`, `MoveToApplicationsTests.swift` (part), `UpdateInstallTests.swift` (part), `StartAtLoginTests.swift` (part), `SourcePolicyTests.swift` (1-215), `InMemoryAdapters.swift` (623-730)
- `Tests/LauncherPlatformTests/QuitSignalsTests.swift`, `ThisCopyTests.swift`, `SystemRunningCopiesStopTests.swift` (part), `ApplicationsUpdaterTests.swift` (head)
- `docs/architecture.md`, `docs/domain-model.md` (lifecycle entries), `docs/performance.md` (startup)
- `plans/038-post-update-force-quit/plan.md`, `development-logs.md`; `plans/035-post-update-crash/plan.md` (part), `development-logs.md` (part); `plans/034-launch-window-to-front/plan.md` (grep); `plans/021-background-agent-lifecycle/plan.md` (grep), `development-logs.md`, `.temp/architect/grounding/index.md` (F1-F20); `plans/022-in-app-updates/plan.md` (grep)
- Upstream Sparkle `2.x`, read with `gh api`: `Sparkle/InstallerProgress/InstallerProgressAppController.m`, `Autoupdate/AppInstaller.m`, `Sparkle/SPUInstallerDriver.m`, `Sparkle/SPUUpdateDriver.m`, `Sparkle/SPUUpdaterDelegate.h`, `CHANGELOG`
- Local: `/Applications/Ghostty.app/Contents/Frameworks/Sparkle.framework` (strings, plists), `/Applications/Trackpad Launcher.app/Contents/Info.plist`

## Boundaries

**In:**

- AppKit delegate callbacks (4 only: willFinish, didFinish, shouldHandleReopen, shouldTerminate; no `applicationWillTerminate`, no `applicationShouldTerminateAfterLastWindowClosed`).
- Apple events through `currentAppleEvent`.
- `willPowerOffNotification`.
- Kernel exit sources.
- `SMAppService.mainApp` status.
- The `--eject-disk-image` argument; `--as-release-build` (development builds only, `CodeSignature.swift:11-21`).

**Out:**

- `NSApp.terminate(nil)`, `forceTerminate()`.
- `NSWorkspace.openApplication` (the move and today's update).
- `SMAppService` register and unregister.
- `NSApp.setActivationPolicy`, `activate(ignoringOtherApps:)`.

**What removing today's updater touches on this angle:**

- `Lifecycle` init parameter, `onReplaced`, `replaced()`, `shouldEnd:217`, `quit:234`.
- `Launcher` `updater` (85, 93), `openedByHand:230`, `closeWindow:237`.
- `AppDelegate.makeUpdater`, `makeResident`.
- `SettingsShell` `updater` and `Fit.card`, `SettingsView:107`.
- Test helpers `Published.card`, `isInstalling`, `RunningBuild`, `OneProcess.updates` and `releases`.
- `ApplicationsInstaller.put` stays, used by the move; its doc comment mentions the update.
- The `createsNewApplicationInstance` confinement names `ApplicationsUpdater.swift` (`SourcePolicyTests.swift:188-190`).
- `docs/domain-model.md:12` lists "by an update opening the new version" under *Opened by hand*, and `docs/architecture.md:11` calls the new version "an ordinary opening by hand". Both stop being true for an automatic update.

**Where Sparkle must attach.** `Updater`'s check today runs only through `Launcher` window edges. Plan R1 needs it at each start, login included, with no dependence on the window. Today's `Updater` object is built in `applicationWillFinishLaunching`, before the route. A `SPUUpdater` started there would run in copies about to `.end` or still in `.replacingOthers`. The natural point is once resident (`othersExited`, or `makeResident`). R2's "copy showing the move dialog" is already excluded, since the `.installed` gate and `.askToMove` (needs `.elsewhere`) are mutually exclusive.

## Non-Obvious Things

1. **`.byHand` means "not proven to be a login"**, including a nil event. Anything launching the app is a hand opening, so an unattended relaunch is the loud path by default.
2. **`updaterShouldRelaunchApplication:` is not a "don't relaunch" switch in practice.** NO makes `installWithToolAndRelaunch:` call `installerIsRequestingAbortInstallWithError:` and return: the install aborts (`Sparkle: SPUInstallerDriver.m:502-516`).
3. **The silent path relaunches.** `updater:willInstallUpdateOnQuit:immediateInstallationBlock:` is documented to "install the update and relaunch the application without any UI interaction" (`Sparkle: SPUUpdaterDelegate.h:430-431`). Its block calls `finishInstallationWithResponse:SPUUserUpdateChoiceInstall displayingUserInterface:NO`, which always passes `installWithToolAndRelaunch:YES` (`SPUUpdateDriver.m:862-866`, `937-938`). A plain exit installs without a relaunch unless relaunch was requested: "Sparkle will always attempt to install the update when the app terminates" (`SPUUpdaterDelegate.h:433`), and `_shouldRelaunch` is set only by the resume message (`AppInstaller.m:661-670`, `828`). That is what R13 wants for *Quit Trackpad Launcher* with an update waiting.
4. **A refused quit leaves the installer armed.** Once the resume message has set `_shouldRelaunch = YES` and the quit is cancelled, nothing clears it. The installer stays waiting for the target's termination (`AppInstaller.m:410-418`). If the user later presses *Quit Trackpad Launcher*, or logs out, the process ends, the installer installs and **relaunches**, which breaks R13 ("an update MUST NOT start the app again") and possibly R14. A repeat of the resume request can change the flag but also re-sends the termination signal (672-684). So the hand-over needs `shouldEnd` to say yes once it has begun, not a best-effort window gate. Inferred from reading; not run.
5. **`sendTerminationSignal` is one shot per request.** Sparkle does not retry on its own; the retry is the `retryTerminatingApplication` path for a user driver (`SPUInstallerDriver.m:547`, `AppInstaller.m:678-683`).
6. **A failed install after the old process ended relaunches nothing.** `performFinalInstallationProgressBlock` failure goes to `cleanupAndExitWithStatus:EXIT_FAILURE` with no relaunch (`AppInstaller.m:806-815`). The agent then exits on invalidation (`InstallerProgressAppController.m:125-141`). R11 requires a working copy running again within 10 s. Nothing in the app could do that: the old process is gone, and the repo forbids its own relaunchers (`SMAppService.agent`, `.daemon`, `.loginItem`, `SMLoginItemSetEnabled`, rule "nothing relaunches the app", `SourcePolicyTests.swift:88-91`; child processes banned, 40-44; timers banned, 52-55; glossary, `docs/domain-model.md:18`). The same failure also leaves any pre-termination marker stale, so a marker needs a validity rule. Otherwise the next real opening by hand would be silent and look broken. A version comparison handles "install failed, same version". A time bound handles "install fine, relaunch lost". A stale marker met by a login start is harmless and should be consumed.
7. **`.terminateCancel` during a hand-over closes the user's window** as a side effect, since `shouldEnd(.other)` has `closeWindow()` inside it (`Lifecycle.swift:212-214`). It is a query with an effect.
8. **`powerOffAnnounced` is never reset** (`QuitSignals.swift:6`, `14`). If a logout is announced and then cancelled by another app, every later ordinary quit in this process reads `.system`: a Dock Quit ends the process instead of closing the window. Existing behaviour. It would also make a Sparkle quit pass, by accident.
9. **The logout route has never been observed in this repo.** Plan 038 removed the key that used to let loginwindow kill the app silently, so `QuitSignals` is now the only route. Its development log still reads "PENDING HUMAN CHECK (R2), NOT DONE" (`plans/038-post-update-force-quit/development-logs.md:15`). If a real logout read as `.other` with the window open, the app would cancel the logout. R8 and R14 rest on this. Likewise the login marker (F2) is sourced from one third-party answer and was recorded as not probed, plan 021 open question 1; I found no later proof. It has been shipping, but nothing I read records a probe.
10. **The loginwindow rule changes shape with Sparkle.** Plan 038's kill needed three things: a foreground parent dying, a child that is a UI element with no visible window, and the child declaring sudden termination. The key is gone, enforced by `SourcePolicyTests.neverDeclared` (95-97). Under Sparkle the LS parent of the new copy is `Updater.app`, a UI element that shows no window with `showUI` NO, and loginwindow ignores non-foreground deaths ("has died, is non-foreground and never tracked, so ignoring it", plans 035, 038). Inference, unprobed. Plan 038 explicitly left open that a windowless silent child gets loginwindow's "schedules future checks ... to see if we need to alert about it" (Non-goals, Automatic updates): "that feature's own plan must look at it".
11. **R16's last run of the update card is old code.** 1.0.14's `ApplicationsUpdater` opens the first automatic-update version as its child, and that start must stay `.byHand` with a window: old code writes no marker, so a marker design passes this automatically. A "version changed since last run" design would make it silent, and would also silence a user's manual install. Version change alone is not a usable signal.
12. **`Bundle.main` after a swap reads the new bundle.** `InstalledRelease` and `ThisCopy.version()` are read once at start for this reason (`Core/Update.swift:30-31`). Sparkle's swap happens after the old process exits, so this hazard goes away with it.
13. **The same path with a replaced build starts a new process** (F6), so `others()` can list an old copy while the new one starts. Under Sparkle, the old one has exited before the swap, so `others()` is normally empty on relaunch and startup is synchronous. If a user opened the app by hand in the gap, Sparkle's `openURL` reaches that running copy as a reopen, `rapp`, `.byHand`: a window re-front, harmless since the user asked for the window.
14. **`RunningApp` is unrelated to the lifecycle** despite the name. `SystemRunningCopies` is the copy-related type.
15. **`isInstalling`'s reason goes away with Sparkle.** Today it protects an in-process install, as `.moving` protects the move. Under Sparkle the swap runs in another process after this one has ended, so there is nothing in-process left to protect. The `.moving` refusal of `.other` stays for the move.
16. **Ending order is a real constraint**: `end()` sets `.ending` before terminate because AppKit re-enters synchronously (`Lifecycle.swift:245`). `replace` sets the stage before `stop` because `stop` may call back inside (251).
17. **`applicationShouldTerminate` is not reached for a `forceTerminate`** from a peer. A Debug copy opened by hand kills the installed copy with no chance to react.
18. **The gesture stack dies with the process** with no teardown: no `applicationWillTerminate`, and an event tap vanishes with its owner. `MultitouchTrackpads.run` notes a withheld press's release may leak as a stray mouse-up (75); R8's idle gate makes that moot for updates.

## Open Questions

- **`openURL` launch event from another process.** F1 was probed with `open`. Does a launch through `NSWorkspace openURL:` from `Updater.app` also deliver a marker-free `oapp` with sender = own pid? Reading says yes; a probe should confirm, and it is the premise of classification.
- **Whether the marker would be needed at all.** I found no Sparkle-owned signal readable by a new process that says "you were relaunched by me". I checked the driver and agent paths above only, not all of Sparkle's defaults keys.
- **Focus under `openURL` from an agent.** Plan 034's "cold launch does not make it active" comes from Finder and Spotlight openings. Sparkle's comment at `InstallerProgressAppController.m:406` hopes the relaunched app ends up frontmost. Whether a windowless accessory process can visibly disturb the frontmost app on macOS 26 needs a probe. By reading, it should not, because no activation call runs.
- **Time from quit to gestures back.** No measurement exists. R9's 10 s needs an end-to-end number: quit event, Autoupdate swap, `openURL`, startup. Startup alone was about a second of CPU on the 2026-10-17 baseline.
- **Whether a Sparkle quit during `.replacingOthers` or at the first moments of a start can occur.** Unlikely if Sparkle starts only once resident; not traced further.
- **Behaviour of a relaunch during logout** when stage 2 was already requested with relaunch = YES. The installer would try to relaunch as the session ends. Not traced.
- **Whether a marker written in `updaterWillRelaunchApplication:` is readable by the new process.** It runs synchronously before the resume message (`SPUInstallerDriver.m:549-558`), and `UserDefaults` writes reach cfprefsd asynchronously but normally before exit. Not probed. The `.terminateNow` path does not synchronise defaults in app code.
- **`SMAppService.mainApp` across a Sparkle swap** (R10). Plan 021 open question 5 left "path or bundle identifier" unanswered. Path and identifier both stay the same in an update, so it should hold; the current update tests only assert that no login item call is made.
- **Whether the pending logout check of plan 038 was done** outside the repo. The log still says pending.
