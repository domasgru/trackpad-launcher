# Grounding index: plan 021, background app with a settings window

The starting point for the runners, the judge and the test planner. Every fact a design decision rests on is listed
with its standing: **probed** (what a probe printed on this machine, macOS 26.6.2 / Xcode 27.1, on 2026-10-27),
**sourced** (file and heading that state it), or **disputed** (both sides). A conclusion drawn from a probe is marked
as a conclusion.

Paths are relative to `plans/021-background-agent-lifecycle/.temp/architect/grounding/` unless they start with a repo
directory (`LauncherKit/`, `docs/`, `plans/`, `Scripts/`, `project.yml`).

## How the grounding was done

- `how` ran (4 explorers + explainer): `how.md` is the traced model of today's lifecycle and shell. The explorer files
  `how-composition-root.md`, `how-shell.md`, `how-activation.md`, `how-build-release.md` hold the raw file:line
  findings.
- `why` ran (source control + plans investigators + synthesizer): `why.md` ends with the **Preserve / Change / Avoid /
  Risk** constraint set the design must answer. Raw findings in `why-source-control.md`, `why-plans.md`.
- Probes: `probes/lifecycle-probe/` (`run.sh` → `output.txt`; `sudden.sh` → `sudden-output.txt`) and
  `probes/signature-probe/` (`run.sh` → `output.txt`). Each left the machine as found (processes quit, LaunchServices
  registrations removed, temp dirs deleted, Calculator quit).
- Sources fetched to `sources/` and read in full where cited.
- Not greenfield. No `research/` directory exists in the repo.

## The facts, by design question

### Q1. What a launch does: login start, opened by hand, development build, other copies

| # | Fact | Standing |
|---|---|---|
| F1 | For an `open` launch, `NSAppleEventManager.shared().currentAppleEvent` is **nil in `applicationWillFinishLaunching`** and is `aevt/oapp` (no `keyAEPropData`, sender = the app's own pid) in `applicationDidFinishLaunching`; `NSApplication.launchIsDefaultUserInfoKey` is `true`. | probed: `probes/lifecycle-probe/output.txt`, first two log lines |
| F2 | An app launched at login through `SMAppService.mainApp` receives `oapp` whose `keyAEPropData` is `keyAELaunchedAsLogInItem` (`'lgit'`), read in `applicationDidFinishLaunching`. The key itself: "If present in a kAEOpenApplication event, application was launched as a login item". | sourced: `sources/so-74699425-answers.txt` (accepted, self-answered by an `SMAppService.mainApp` user); SDK `AE.framework/Headers/AERegistry.h:1052`. **Not probed**: it needs a real logout/login. Conclusion: read it in `didFinishLaunching` (or an `oapp` handler), never in `willFinishLaunching` (F1). |
| F3 | `-[NSApplication disableRelaunchOnLogin]` stops macOS relaunching the app at login when it was running at logout ("Reopen windows when logging back in"). Recommended usage for apps launched by another mechanism: call once, never pair with enable. | sourced: SDK `AppKit.framework/Headers/NSApplication.h:579-589`; `sources/apple-disablerelaunchonlogin.json` |
| F4 | Opening the **same path** while that copy runs starts **no second process**: the running one gets `aevt/rapp` (`applicationShouldHandleReopen`, `hasVisibleWindows` reported), sender = the `open` process. | probed: `output.txt` E2, E3, E7 |
| F5 | Opening the **same build at another path** while one runs **starts a second process**. | probed: `output.txt` E4 (pids 17061 and 17443) |
| F6 | Replacing the bundle **at the same path** with a different build (remove + copy, as Finder's Replace does) while the old one runs, then opening that path, **starts a new process from the new build**; the old one keeps running. | probed: `output.txt` E8 (v1 pid 17061 and v2 pid 18445 both alive) |
| C1 | Conclusion from F4-F6: any second process of the bundle id that starts while one runs is a different build or a different place. LaunchServices itself routes a same-build same-place open to the running copy as a reopen. | conclusion |
| F7 | A development build is "not signed for release". The Developer ID requirement `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists` is **true** for Developer ID apps (Ghostty, VS Code) and **false** for the Apple-Development-signed TrackpadLauncher (installed and DerivedData) and for an ad-hoc binary, both via `SecStaticCode` and via `SecCodeCopySelf` on the running process. | probed: `probes/signature-probe/output.txt` |
| F8 | `#if DEBUG` and "signed for release" disagree on the perf build: `Scripts/perf/build.sh` builds Release config signed Apple Development. A signature rule calls it development (no move dialog); a `DEBUG` rule would call it release. Hardened runtime is on in both configs, so the runtime flag cannot discriminate. | sourced: `how-build-release.md` § "How a running app could tell development from release"; `Config/*.xcconfig` |
| F9 | Debug and Release share bundle id `com.domasgru.TrackpadLauncherApp`, so they share the settings domain and the `SMAppService.mainApp` identity. The bundle on disk is `TrackpadLauncher.app` (display name "Trackpad Launcher"). | sourced: `how-composition-root.md` § Info.plist; `/Applications/TrackpadLauncher.app` exists on this Mac |
| F10 | "First run" is derived today: no `"settings"` record in `UserDefaults`. Undecodable data loads as defaults, not as a first run. First-run side effects (login registration, Accessibility ask) run **before** the first save so a crash repeats them. | sourced: `LauncherKit/Sources/LauncherCore/Settings.swift:60-65`, `Launcher.swift:105-113`; `why.md` Preserve 1-2 |
| F11 | Adapters start sensing in their `init`s (IOKit, tccd push, FSEvents, KVO); gestures start only at `hardware.run` in `reconcile()`; `Launcher.init` runs a synchronous catalog scan and saves nothing. | sourced: `how.md` § 1 and Gotcha 5 |

### Q2. Dock icon and activation policy

| # | Fact | Standing |
|---|---|---|
| F12 | With `LSUIElement = true` the app starts as `ApplicationType = "UIElement"` (no Dock icon, never a flash). `setActivationPolicy(.regular)` makes it `"Foreground"` (Dock, ⌘-Tab); `.accessory` on window close makes it `"UIElement"` again, the app deactivates and another app becomes frontmost. | probed: `output.txt` E1-E3 and the "after close" log lines |
| F13 | On a reopen, `.regular` + `makeKeyAndOrderFront` + `NSApp.activate()` leaves the app active with the window key; `frontmostApplication` is the app itself. | probed: `output.txt` "after show" lines |
| F14 | No `NSApplicationDelegate`, no main menu, no `setActivationPolicy` exist today; ⌘Q/⌘W/⌘M do nothing. The source scan bans `keyDown`/`keyUp`/`flagsChanged` in any spelling; menu key equivalents, `performClose`, `cancelOperation` pass. | sourced: `how.md` § 3, Gotcha 11; `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:43-48` |

### Q3. Quitting: user quits, peer copies, logout

| # | Fact | Standing |
|---|---|---|
| F15 | A quit Apple event from `osascript` (stand-in for the Dock's Quit) reaches `applicationShouldTerminate` with sender = osascript's pid and **no** `kAEQuitReason`; `.terminateCancel` keeps the app running and returns userCanceled (-128) to the sender. | probed: `output.txt` E5 |
| F16 | `NSRunningApplication.terminate()` from another process arrives the same way (sender pid = that process, no reason). It returns `true` (request sent) but the target stays alive if it cancels. `NSRunningApplication(processIdentifier:)` of the sender resolves only when the sender is an app. | probed: `output.txt` E6 |
| F17 | A quit for logout/restart/shutdown may carry `kAEQuitReason` (`kAEQuitAll`, `kAEShutDown`, `kAERestart`, `kAEReallyLogOut`). | sourced: SDK `AERegistry.h:602`, `AppleEvents.h:67`. **Not probed.** |
| F18 | Sudden termination (`NSSupportsSuddenTermination = YES` or `enableSuddenTermination()`) lets the system **kill** the app at logout/shutdown instead of asking it; `UserDefaults` disables it briefly around a write. With the key set, a user quit (osascript) and a peer `terminate()` still reach `applicationShouldTerminate` and can be cancelled. | sourced: `sources/apple-processinfo.json` § "Support Sudden Termination", `sources/apple-suddentermination.json`; probed: `probes/lifecycle-probe/sudden-output.txt` |
| F19 | `NSWorkspaceWillPowerOffNotification` is posted when the user requested logout or power off. Its order relative to the quit event is not documented. | sourced: SDK `NSWorkspace.h:320` |
| F20 | The menu bar version has no app delegate, so a quit event (from a peer's `terminate()`) ends it; nothing can veto. | sourced: `how-composition-root.md` § Termination |
| F21 | Every setting is saved at once on each intent; nothing is saved at quit. | sourced: `how-composition-root.md` § Settings persistence |

### Q4. Starting at login (R5, R9, R12-R14, R22, R25)

| # | Fact | Standing |
|---|---|---|
| F22 | `SMAppService.Status`: `.notRegistered` (never registered, or unregistered), `.enabled`, `.requiresApproval` ("returned if the user revokes consent for the service to run in System Settings"), `.notFound`. `register()` on an already registered service → `kSMErrorAlreadyRegistered`; on one the user has not approved → `kSMErrorLaunchDeniedByUser`; `unregister()` of the main app keeps it running and stops future login launches; unregistering an unregistered service → `kSMErrorJobNotFound`. "Apps that use SMAppService APIs must be code signed." | sourced: SDK `ServiceManagement.framework/Headers/SMAppService.h` (enum doc, `registerAndReturnError`, `unregisterAndReturnError` discussions) |
| F23 | For the main app, registration means "launched on subsequent logins". Only a LoginItem *helper* "will be relaunched" after a crash, so the main app is not relaunched after a crash or force quit (R14). | sourced: `SMAppService.h` `registerAndReturnError` discussion |
| F24 | Today: `WorkspaceActions.registerLoginItem()` = `try? SMAppService.mainApp.register()`, called only on first run, before the first save; no status read, no unregister. The menu bar version therefore already registered the login item on its first run, and an upgraded Mac has a settings record (not a first run). | sourced: `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:88-91`; `how.md` § 6; `why.md` "Correction to the question's premise" |
| F25 | How System Settings → General → Login Items on macOS 26 shows an `SMAppService.mainApp` item (toggle or list entry removable with −), and which status each user action produces, is **not** settled: the header says revocation gives `.requiresApproval`; removal from a list may give `.notRegistered`. | disputed: `SMAppService.h` vs no source for the removal path; not probeable without driving System Settings |

### Q5. Frontmost app and running apps with the settings window in front (R15)

| # | Fact | Standing |
|---|---|---|
| F26 | Self-exclusion is by pid at five sites, all below the `SystemActions` port: `RunningAppsReader.frontmost()` (nil when the frontmost is this process), `FrontmostAppWindows.read()` (`.noApp`), `LaunchServicesOrder.apps()` (`Foreground` and pid ≠ own), the fallback list and `ActivationTracker` (`.regular` and pid ≠ own). A `.regular` Trackpad Launcher stays excluded. | sourced: `how-activation.md` § C; `how.md` § 7 |
| F27 | Today the window is a non-activating panel, so the user's app stays frontmost while it is key; an activating settings window makes `frontmost == nil`, which today means "row = running apps alone, swap brings `apps.first`, no window swipe" (plan 008 R14) — not R15's "the app that was in front before it". `RunningApps.frontmost == nil` conflates "Trackpad Launcher active", "no app active", "frontmost has no bundle". No memory of the last non-self frontmost app exists; `ActivationTracker` exists only on the fallback path. A menu bar app that was in front is not in `apps`. | sourced: `how-activation.md` § D, E, Non-obvious 2-5; `why.md` Change 7, Risk 1 |
| F28 | With the probe active and its window key, `NSWorkspace.openApplication(Calculator, activates: true)` brought Calculator to front: Calculator frontmost, the probe inactive, its window still visible (not key). | probed: `output.txt` E7 "after bring" |
| F29 | Bring to front is `NSWorkspace.openApplication(at:configuration:)` with `activates = true` everywhere; window raising is `kAXRaiseAction` only and relies on the app already being frontmost. | sourced: `how-activation.md` § F |
| F30 | Overlay panels set `hidesOnDeactivate = false` explicitly, so they do not depend on the app being inactive; their comments ("the app is never active") go stale. | sourced: `how-activation.md` § E; `why.md` Infer 3 |

### Q6. Moving into /Applications (R18-R21)

| # | Fact | Standing |
|---|---|---|
| F31 | `NSWorkspace.requestAuthorization(to:)` + `FileManager(authorization:)` (`replaceItemAt`) needs the Privileged File Operation entitlement, which is requested from Apple. | sourced: `sources/apple-nsworkspace-authorization.json`, `sources/apple-privileged-file-ops-entitlement.json`; SDK `NSWorkspace.h` 240-275 |
| F32 | `AuthorizationExecuteWithPrivileges` is deprecated ("use a launchd-launched helper tool and/or the Service Management framework") but still exported by Security.framework; LetsMove resolves it with `dlsym` and runs `/bin/rm -rf <dst>` then `/bin/cp -pR <src> <dst>` under `AuthorizationCopyRights(kAuthorizationRightExecute, interaction allowed)`; a cancelled prompt is `errAuthorizationCanceled`. | sourced: SDK `Security.framework/Headers/Authorization.h:423-427`, `Security.tbd`; `sources/letsmove-PFMoveApplication.m` `AuthorizedInstall` |
| F33 | LetsMove's whole flow (reference): skip when in an Applications folder (it counts `~/Applications`, which R18 forbids); detect a disk image by `statfs` `f_mntfromname` matched against `hdiutil info -plist`; need authorization when `/Applications` or the existing copy is not writable; `NSAlert.runModal` after activating; if the destination copy runs, LetsMove *switches to it and exits* (R20 wants the opposite: replace it); trash the old copy, `copyItem`, delete the original (failure tolerated), relaunch through a `sh` script that waits for the pid, strips `com.apple.quarantine` and `open`s the new copy; detach the disk image 5 s later from `sh`. | sourced: `sources/letsmove-PFMoveApplication.m` |
| F34 | Security.framework exports `SecTranslocateIsTranslocatedURL` and `SecTranslocateCreateOriginalPathForURL` (no public header): the only way to find the original location of a translocated (quarantined, not-moved) app. | sourced: SDK `Security.framework/Security.tbd` |
| F35 | Public eject and image APIs exist: `FileManager.unmountVolume(at:options: .allPartitionsAndEjectDisk, completionHandler:)` (asynchronous completion, a push), `NSWorkspace.unmountAndEjectDevice(at:)`, DiskArbitration `kDADiskDescriptionDeviceModelKey`/`VolumePathKey`; `URLResourceKey.quarantinePropertiesKey` clears quarantine. | sourced: SDK `NSFileManager.h:102-165`, `NSWorkspace.h:105`, `DADisk.h:43-69`, `NSURL.h:459` |
| F36 | This account is an admin and `/Applications` (root:admin 775) is writable, so the admin-prompt path (R21) cannot be exercised here without a standard account. | probed: `id -Gn`, `test -w /Applications` (Bash, 2026-10-27) |
| F37 | The source scan does not ban `FileManager.copyItem/moveItem/replaceItemAt/removeItem`, but `docs/architecture.md:27` says "no files written other than settings in UserDefaults"; the move contradicts the prose, which must be amended on purpose. `Timer`, `asyncAfter`, `Task.sleep` are banned in shipped code, so "wait for the old copy to exit" must be a push (KVO `NSRunningApplication.isTerminated`, `NSWorkspace.didTerminateApplicationNotification`). | sourced: `how-build-release.md` § SourcePolicyTests; `why.md` Avoid 3-4 |
| F38 | Whether a notarised, stapled app opened from a quarantined disk image runs translocated, and whether the Accessibility grant follows a copy that moved or was replaced, are **not** settled. | open (not probeable here: needs a Developer ID notarised build) |

### Q7. Releasing a disk image (R24)

| # | Fact | Standing |
|---|---|---|
| F39 | The notary service accepts UDIF disk images and makes tickets for the top-level file and each nested item; `stapler staple` works on a disk image; a zip cannot be stapled. | sourced: `sources/apple-notarization-workflow.json` § "Staple the ticket to your distribution" |
| F40 | `Scripts/release.sh` builds a zip (archive → export developer-id → verify → notarytool → staple the `.app` → spctl), never runs `xcodegen generate`, and has never run end to end; this Mac has no Developer ID certificate (non-goal). `hdiutil` is present; `create-dmg`, `dmgbuild`, `appdmg` are not. There is no app icon. | sourced: `how-build-release.md` § Scripts/release.sh, Non-obvious 1-3, 12; probed: `security find-identity` lists only Apple Development |
| F41 | Distribution rules: Developer ID, hardened runtime, no sandbox, no entitlements, notarised and stapled, never `--deep`, main executable signed last. | sourced: `docs/architecture.md` § Distribution; `why.md` Preserve 7 |

### Q8. The settings window itself (R7, R8, R10, R16, R17)

| # | Fact | Standing |
|---|---|---|
| F42 | Window visibility is model state (`Launcher.Window { closed, open, heldOpen }`, private; `isWindowOpen` public); the shell renders it through `Observations`. `.heldOpen` and `dismissWindow()` exist only because outside clicks and the Accessibility prompt would close a transient panel. | sourced: `how.md` § 2; `why.md` Change 2 |
| F43 | Today's close paths, the four gesture-effect writes (`Launcher.swift:265, 309, 345, 361`), the Other… close/activate/reopen dance and the System Settings buttons' explicit close are all listed with their call sites. | sourced: `how.md` § 2-3 |
| F44 | `Displays.screen(under:)` gives the display under the pointer (nearest when none). The window content (`LauncherView`, 266 pt wide) is built once and kept; releasing it on close was rejected for instant pickers. | sourced: `how-shell.md` Components; `docs/performance.md` Decisions |
| F45 | App pickers are `NSPopUpButton` menus (AppKit menu tracking); whether Escape inside an open picker menu is consumed by the menu and never reaches the window's `cancelOperation` is assumed, not verified. | open (manual) |
| F46 | `MenuBarShell` owns both switcher presenters and the first synchronous icon pass `docs/architecture.md:19` relies on; it is LauncherUI's only public type. `addGlobalMonitorForEvents` is confined to `MenuBarShell.swift` and `BounceOverlay.swift`. | sourced: `how.md` "What plan 021 will touch" |

### Q9. Constraints from the architecture and history

- `docs/architecture.md` § Shape: one `@MainActor @Observable` model owns every decision; adapters behind small ports;
  `LauncherCore` imports Foundation and Observation only (enforced); every port has exactly two adapters (real +
  in-memory); concrete types pointable at a temp dir or a throwaway `UserDefaults` suite are not put behind a port
  unless they deliver asynchronously.
- `docs/architecture.md` § Concurrency: no timers, no polling; every input is a push.
- `why.md` § Constraint set for plan 021: Preserve 1-9, Change 1-9, Avoid 1-7, Risk 1-9. In particular: keep "first
  run" derived from the absence of a record (Preserve 1); no second "prompted"/"launched" boolean (Avoid 2); never
  re-enrol a user who turned login off (Avoid 1); window state stays model state (Preserve 4); no `terminate`/`openURL`
  closures in the model (Preserve 5); the move must not spend the first run in the copy about to move (Risk 4).
- `how.md` § "What plan 021 will touch or invalidate": the full list of tests whose expectations flip, stale comments,
  source-scan rows and doc sentences.

## Sources, grouped by the design question they answer

- **Launch kind, reopen, single instance:** `probes/lifecycle-probe/output.txt` (E1-E4, E8);
  `sources/so-74699425-answers.txt`; SDK `AERegistry.h:1052`; SDK `NSApplication.h:579-589`
  (`sources/apple-disablerelaunchonlogin.json`); `sources/apple-lsmultipleinstancesprohibited.json` (the key is about
  *multiple users*, not multiple copies for one user).
- **Activation policy, Dock:** `probes/lifecycle-probe/output.txt` (E1-E3); `how-shell.md` § Panel configuration.
- **Quit, logout:** `probes/lifecycle-probe/output.txt` (E5, E6), `sudden-output.txt`; `sources/apple-processinfo.json`
  § Support Sudden Termination; SDK `AERegistry.h:602`; SDK `NSWorkspace.h:320`.
- **Login item:** SDK `SMAppService.h` (whole header); `sources/apple-smappservice-mainapp.json`;
  `how-composition-root.md` § Login item; `why.md` § First launch; `plans/001-trackpad-launcher-app/plan.md` R17,
  decision 7.
- **Frontmost / running apps:** `how-activation.md` (all); `probes/lifecycle-probe/output.txt` (E7);
  `plans/008-recent-apps-switcher/development-logs.md` "Fix: the first swipe after opening the app did nothing".
- **Move to /Applications:** `sources/letsmove-PFMoveApplication.m` (all); `sources/apple-nsworkspace-authorization.json`;
  `sources/apple-privileged-file-ops-entitlement.json`; SDK `Authorization.h:423-427`; SDK `Security.tbd`; SDK
  `NSFileManager.h:102-165`, `NSWorkspace.h:105`, `DADisk.h`, `NSURL.h:459`.
- **Development build:** `probes/signature-probe/output.txt`; `how-build-release.md` § How a running app could tell
  development from release.
- **Release:** `sources/apple-notarization-workflow.json`; `how-build-release.md` § Scripts/release.sh; `Scripts/release.sh`.
- **Settings window, existing shell:** `how.md` § 2-3; `how-shell.md`; `docs/performance.md` § Decisions.
- **Constraints:** `docs/architecture.md`; `docs/domain-model.md` (Frontmost app, Launcher window, Swap, Launch
  animation entries); `why.md` constraint set.

## What a test can produce for real, and what needs a fake or a manual check

**Real, in `swift test`:**
- All policy in `LauncherCore` through `World` (real `Launcher`, in-memory adapters, throwaway `UserDefaults` suite):
  how a launch, a reopen and a quit are decided; window state; login-item policy against a recording fake; first-run
  derivation; the frontmost-app rule as a pure function or through the fake's frontmost/activation history.
- `SettingsStore` against a throwaway suite (new persisted fields, decoder rule: missing key → default).
- File operations of the move against temp directories with real `FileManager` (copy, replace, remove original,
  read-only source), per the architecture rule that temp-dir-pointable concrete types are not put behind ports.
- The code-signature rule against binaries the test can build or find: an ad-hoc/unsigned test binary must read as a
  development build (F7). A Developer ID positive case exists only on a machine with Developer ID apps installed, so it
  is not a portable test.
- The source scan (new banned/confined rows).

**Needs a fake (an in-memory adapter at a port):**
- `SMAppService` status/register/unregister (registering in tests would change the machine's Login Items).
- Other running copies and stopping them; their termination push.
- How the process was started (login item, by hand, reopen) — Apple events cannot be produced by a unit test.
- Activation, the Dock icon, the main window's open/close as seen by AppKit.
- The move dialog's answer, the administrator prompt's answer, disk-image detection and ejection, translocation.
- The Accessibility prompt (already faked by `InMemoryPermissions`).

**Manual or E2E only (record in the slices' acceptance):**
- A real login launch (F2) and logout with the window open (F3); restart/shutdown not held up (F17-F19).
- The Dock icon's real Quit (F15 used osascript as a stand-in).
- Finder drag-over-replace of a running copy; Spotlight/Launchpad opens; ⌘-Tab and Dock presence.
- Login Items UI toggling and the status it produces (F25).
- A downloaded, quarantined, notarised disk image: Gatekeeper, translocation (F38), move + eject; a standard account's
  admin prompt (F36).
- Notarisation and stapling (needs the Developer ID certificate the developer obtains).
- Escape with a picker menu open (F45); the window centred on a second display.

## Open questions (not settled by any source or probe here)

1. **Login launch marker on macOS 26 (F2).** Does an `SMAppService.mainApp` login launch on macOS 26 still carry
   `keyAELaunchedAsLogInItem`? Sourced from one accepted third-party answer; the whole silent-login rule (R9, R22)
   rests on it. A design should name its fallback if it does not.
2. **Login Items UI and status (F25).** Toggle vs remove for a main-app item on macOS 26, and the resulting status
   (`.requiresApproval` vs `.notRegistered`). R12/R13 need "Quit turned it off" told apart from "the user turned it off".
3. **Logout signals (F17-F19).** Is `kAEQuitReason` present on macOS 26 logout quits, does the system honour sudden
   termination for an app that is `.regular` with a window open, and does `willPowerOff` arrive before the quit event?
4. **Finder replacing a running app (R3 scenario).** Does Finder let the user drag a new copy over a running one? F6
   shows what LaunchServices does once the bundle is replaced.
5. **Translocation and the Accessibility grant after a move (F38).**
6. **Producing the disk image's drag cue** (background picture and icon positions) with no third-party tool.
7. **R2 versus R23.** A development build run from Xcode while the installed copy runs: should it stop the installed
   one ("at most one recognises gestures") or run beside it? `docs/performance.md:8` asks developers to quit other
   copies by hand today.
8. **First run of a development build.** R5 says "the first run from /Applications" registers login. Should a
   development build's first run register its DerivedData copy (today it does), or skip registration?
9. **No app icon.** The Dock (R6) and the disk image (R24) will show the generic icon. A product question, not a
   design one, but the design should not hide it.
