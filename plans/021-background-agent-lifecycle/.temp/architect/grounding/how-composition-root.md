# Grounding: process start and composition root

Repo root: /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle (all paths below relative to it).

## Components Found

- `TrackpadLauncherApp` (enum with `@main static func main()`), `TrackpadLauncher/TrackpadLauncherApp.swift:6-27`: the whole composition root. No `NSApplicationDelegate`, no SwiftUI `App`, no `main.swift`. It is the only file in the app target (`TrackpadLauncher/` holds just this file; `Info.plist` there is generated and gitignored, `.gitignore` line `TrackpadLauncher/Info.plist`).
- `Launcher` (`@MainActor @Observable final class`), `LauncherKit/Sources/LauncherCore/Launcher.swift:9-384`: the model; owns first-launch policy, login-item registration call, Accessibility prompt call, window open/close state, persistence calls.
- `SettingsStore` (`@MainActor public struct`), `LauncherKit/Sources/LauncherCore/Settings.swift:52-73`: one binary-plist record under the `UserDefaults` key `"settings"`. Not behind a port (concrete, substitutable with a throwaway suite).
- `Settings` (`Codable` struct), `LauncherKit/Sources/LauncherCore/Settings.swift:7-49`: the persisted fields.
- `SystemPermissions` (`Permissions` adapter), `LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift:10-62`: AX trust + screen-capture reads, prompts, and tccd Darwin notification push.
- `WorkspaceActions` (`SystemActions` adapter), `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:5-118`: includes `registerLoginItem()` via `SMAppService.mainApp.register()`.
- `MenuBarShell` (`NSObject`), `LauncherKit/Sources/LauncherUI/MenuBarShell.swift:14-181`: status item, panel, Quit menu, outside-click monitor; constructed by `main` before `launcher.start()`.
- Ports (protocols) `TrackpadHardware`, `TrackpadPreferences`, `SystemActions`, `Permissions`, `AppScanner`: `LauncherKit/Sources/LauncherCore/Ports.swift:26-150`.
- Other real adapters wired in main: `MultitouchTrackpads` (`LauncherPlatform/MultitouchTrackpads.swift:10-53`), `SystemTrackpadPreferences` (`LauncherPlatform/SystemTrackpadPreferences.swift:6-24`), `AppCatalog.system` (`LauncherPlatform/AppCatalog+System.swift:7-18`), `SystemAppScanner` (`LauncherPlatform/SystemAppScanner.swift:7-17`).

## Flow (process start)

`TrackpadLauncher/TrackpadLauncherApp.swift`:
1. L9 `let application = NSApplication.shared` — creates NSApp first (needed later because `AppIcons` reads `NSApp.effectiveAppearance`, `AppIcons.swift:35,51,70,83`). No `setActivationPolicy` call anywhere in shipped sources (grep of `LauncherKit/Sources` and `TrackpadLauncher/` finds none); activation policy comes solely from `LSUIElement = true` in Info.plist (agent app: no Dock icon, no app menu bar).
2. L10 `let catalog = AppCatalog.system` — roots `/Applications`, `/System/Applications`, `~/Applications`; extra Finder.app (`AppCatalog+System.swift:7-18`). Value type, shared by launcher and scanner.
3. L11 `let system = WorkspaceActions()` — convenience init (`WorkspaceActions.swift:20`) builds `LaunchOverlay`, `BounceOverlay`, `RunningAppsReader`, `FrontmostAppWindows`, and pre-pays a `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")` lookup (L28-29).
4. L12-19 `Launcher(...)` with these port→adapter wirings:
   - `hardware:` `MultitouchTrackpads()` — dlopens MultitouchSupport, registers IOKit first-match/terminated notifications on main queue, drains initial matches, observes `NSWorkspace.didWakeNotification` (`MultitouchTrackpads.swift:26-53`).
   - `preferences:` `SystemTrackpadPreferences()` — KVO on `com.apple.AppleMultitouchTrackpad` and `com.apple.driver.AppleBluetoothMultitouch.trackpad` suites (`SystemTrackpadPreferences.swift:7-24`).
   - `permissions:` `SystemPermissions()` — registers `notify_register_dispatch("com.apple.tcc.access.changed", ..., .main)` in init (`SystemPermissions.swift:12,16-25`), snapshots both grants into `lastKnown` (L21).
   - `system:` the `WorkspaceActions` from step 3.
   - `catalog:` the `AppCatalog.system` value.
   - `scanner:` `SystemAppScanner(catalog: catalog)` — starts an FSEvents stream on the catalog roots in init (`SystemAppScanner.swift:14-17,45-58`).
   - `store:` `SettingsStore(defaults: .standard)`.
   `Launcher.init` (`Launcher.swift:70-86`): stores ports; **L81 `installedApps = catalog.installedApps()` — the synchronous "first scan" on the main thread before the run loop**; L82 `store.load()`; L83 `isFirstLaunch = stored == nil`; L84 `settings = stored ?? Settings()`; L85 `rows = makeRows()`.
5. L20 `let shell = MenuBarShell(launcher: launcher)` (`MenuBarShell.swift:25-76`): creates `NSStatusItem` (L27); **L28 `icons.renderOnMainActor(...)` — the synchronous "first icon pass"** for picker apps + present row apps; builds `LauncherPanel` with `LauncherView` (L30); `SwitcherPresenter(launcher:)` (L31) which, if swipe is on, does another synchronous icon pass of running Dock apps (`SwitcherPresenter.swift:24,44-47`); `WindowSwitcherPresenter` (L32); status button target/action (L35-38); `Observations`-driven tasks for icon image, refit, icon re-render, and `isWindowOpen` → `show()`/`hide()` (L47-75). Doc comment L7: "Create it before `Launcher.start()`: a first-launch window needs the status item as its anchor." Also `Launcher.start()` doc L88: "Call once, after the status item exists."
6. L21 `launcher.start()` (`Launcher.swift:89-115`): wires `hardware.onEvent` (L90-98), `system.onLaunchProgress` (L99), `scanner.onScan` (L100), **`scanner.scan()` (L101, async, off-main)**, `preferences.onChange` and `permissions.onChange` → `reconcile()` (L102-103), then `reconcile()` (L104) which reads connected trackpads, preference values and both permission grants and calls `hardware.run(...)` (L214-234). Then first-launch branch L105-113:
   ```
   if isFirstLaunch {
       system.registerLoginItem()
       let prompting = !isAccessibilityGranted
       if prompting { permissions.ask(.accessibility) }
       store.save(settings)
       window = prompting ? .heldOpen : .open
   }
   ```
   then `resolveRows()` (L114) → `system.prepareLaunchAnimations(for:)`.
7. L22-24 `#if DEBUG system.showAnimationTuner() #endif` — debug builds open the tuner panel at every launch (`WorkspaceActions.swift:101-117`; `AnimationTuner.swift:36-37` `panel.orderFrontRegardless()`).
8. L25 `withExtendedLifetime(shell) { application.run() }` — keeps the shell (which strongly holds `launcher`, `MenuBarShell.swift:15`) alive; `NSApplication.run()` starts the loop (it calls `finishLaunching` itself). The shell's `Observations` loop then yields the initial `isWindowOpen`, so a first-launch window is shown by `show()` (`MenuBarShell.swift:121-131`, `panel.makeKeyAndOrderFront(nil)`) on the first main-actor turn after the run loop starts; on later launches the initial value `false` calls `hide()` (harmless `orderOut`).

## Info.plist (generated by xcodegen from `project.yml`)

`project.yml` `targets.TrackpadLauncher.info.properties`:
- `CFBundleName: Trackpad Launcher`, `CFBundleDisplayName: Trackpad Launcher`, `CFBundleShortVersionString: "1.0"`, `CFBundleVersion: "1"`, `LSUIElement: true`, `LSMinimumSystemVersion: "26.0"`.
- `settings.base`: `PRODUCT_BUNDLE_IDENTIFIER: com.domasgru.TrackpadLauncherApp`, `GENERATE_INFOPLIST_FILE: NO`, `ONLY_ACTIVE_ARCH: NO`. `options.bundleIdPrefix: com.domasgru`.
- Generated file seen in the main checkout (`/Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher/Info.plist`) contains exactly: CFBundleDevelopmentRegion, CFBundleDisplayName, CFBundleExecutable, CFBundleIdentifier=$(PRODUCT_BUNDLE_IDENTIFIER), CFBundleInfoDictionaryVersion, CFBundleName, CFBundlePackageType=APPL, CFBundleShortVersionString=1.0, CFBundleVersion=1, LSMinimumSystemVersion=26.0, LSUIElement=true.
- Absent: `NSPrincipalClass` (not needed since `main` uses `NSApplication.shared` directly), `CFBundleIconFile`/`CFBundleIconName` (no app icon/asset catalog; sources only include `assets/*.svg, *.png` as resources), `NSSupportsSuddenTermination`, `NSSupportsAutomaticTermination`, `LSMultipleInstancesProhibited`, `SMPrivilegedExecutables`, any usage-description strings. No entitlements file, no sandbox (grep of project.yml/Config finds none; plan 001 line 579 states "no sandbox, no entitlements").
- Same bundle id for Debug and Release (only `settings.base`), so both share one `UserDefaults` domain and one `SMAppService.mainApp` identity per bundle path.

Build config (`Config/Base.xcconfig`): deployment 26.0, `ARCHS_STANDARD`, Swift 6, strict concurrency complete, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_STYLE = Manual`. `Debug.xcconfig`: `Apple Development`, team `CQK27876UL`. `Release.xcconfig`: `Developer ID Application`, team `CQK27876UL`, `OTHER_CODE_SIGN_FLAGS = --timestamp`.

Release: `Scripts/release.sh` — checks Developer ID identity and `NOTARY_PROFILE` (L17-24), `xcodebuild archive` Release (L29-37), export with `method developer-id` (L39-55), `codesign --verify --strict` and checks hardened-runtime flag (L60-65), `notarytool submit --wait`, `stapler staple/validate`, `spctl --assess` (L67-72), zips `build/release/TrackpadLauncher.zip` (L74). Note release.sh does NOT run `xcodegen generate`; it assumes `TrackpadLauncher.xcodeproj` exists (gitignored). `Scripts/perf/build.sh:14` does run `xcodegen generate`. `Scripts/test.sh` runs `swift test` in `LauncherKit`.

## Permission prompting

- `Permissions.ask` call sites (only two, grep): `Launcher.swift:110` (`.accessibility`, first launch only, only if not already granted) and `Launcher.swift:182` (`.screenRecording`, from `askForScreenRecording()`, only when hint is `.ask`).
- `SystemPermissions.ask(.accessibility)` → `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true])` (`SystemPermissions.swift:38-45`; literal key because `kAXTrustedCheckOptionPrompt` is a non-Sendable global var). `.screenRecording` → `CGRequestScreenCaptureAccess()`.
- Accessibility is NOT re-prompted on later launches: test `firstLaunchPromptsOnceAndHoldsTheWindowOpenUntilAnExplicitClose` (`LauncherKit/Tests/LauncherCoreTests/AccessibilityTests.swift:20-36`) asserts `asks == [.accessibility]` after relaunch. No persisted "asked for accessibility" flag; it is tied to the first-launch derivation. Afterwards the window's Accessibility hint button "Grant access…" opens System Settings (`LauncherUI/LauncherView.swift:39` → `SettingsPane.accessibility` URL `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, `LauncherUI/LauncherActions.swift:14`).
- Ordering: prompt comes before the first save (test `promptComesBeforeTheFirstSave`, `AccessibilityTests.swift:75+`), and login item registration before the first save (`PersistenceTests.swift:63-72`).
- How the model learns state: `SystemPermissions` registers for tccd's Darwin notification `com.apple.tcc.access.changed` on the main queue (`SystemPermissions.swift:12,22-24`); on each broadcast `refresh()` re-reads both grants and fires `onChange` only if the set changed (L51-56). `Launcher.start` sets `permissions.onChange = { reconcile() }` (`Launcher.swift:103`); `reconcile()` reads `isGranted(.accessibility)` and `.screenRecording` (L217-222). A grant while `window == .heldOpen` closes the window (L219). No polling.
- Source-scan confinement: `AXIsProcessTrusted` and `notify_register` only in `SystemPermissions.swift` (`SourcePolicyTests.swift:76-77`).

## Settings persistence

- `SettingsStore` (`Settings.swift:52-73`): `defaults` injected; `key = "settings"` (L54). `load()` (L62-65): returns `nil` iff `defaults.data(forKey: "settings")` is nil; undecodable data → `Settings()` (NOT nil). `save()` (L67-72): `PropertyListEncoder` binary, `defaults.set(data, forKey: "settings")`. No explicit `synchronize`.
- Domain: `UserDefaults.standard` (`TrackpadLauncherApp.swift:19`) → the app's bundle id domain `com.domasgru.TrackpadLauncherApp` (no suite name).
- `Settings` fields and defaults (`Settings.swift:8-21`): `handMode = .right`, `assignments: [Gesture: AssignedApp] = [:]`, `isLaunchAnimationOn = true`, `isSwipeOn = true`, `isSwapOn = true`, `isWindowSwipeOn = true`, `hasAskedForScreenRecording = false`. Custom decoder: missing key → default, unknown key ignored, bad value fails the whole record (L5-6, L36-48).
- Saves happen immediately on every intent: `setAssignment` L125, `setHandMode` L140, `setLaunchAnimation` L148, `setSwipe` L155, `setWindowSwipe` L164, `setSwap` L172, `askForScreenRecording` L181, and the first-launch save L111. Nothing is saved at termination.
- First run vs later: "launched before" is implicit = presence of the `"settings"` data key (`Settings.swift:3` "Everything persisted besides the implicit 'launched before'"; `Launcher.swift:83`). There is no separate "has run before" marker key. Doc comment L60-61: "nil means nothing was ever saved, which is a first launch. Undecodable data loads as `Settings()`, not as a first launch, so a user who turned the login item off is never re-enrolled." Tests: `PersistenceTests.swift:21-61,153-167` (empty dict record and garbage both = not first launch, 0 login registrations, window closed).
- Other keys in the same standard domain: Debug-only `AnimationTuner.current`, `AnimationTuner.presets`, `AnimationTuner.selected` (`LauncherPlatform/AnimationTuner.swift:71-73,88,150,154`). So a non-empty defaults domain does not imply settings exist; only the `"settings"` key matters.
- Tests use a throwaway suite and `World.relaunch()` builds a new `Launcher` over a fresh `UserDefaults(suiteName:)` (`Tests/LauncherCoreTests/World.swift:89,113,180-189`).

## Login item (exists today)

- Port: `SystemActions.registerLoginItem()` doc "Open at Login. Idempotent. Called only on first launch." (`Ports.swift:60-61`).
- Real adapter: `WorkspaceActions.registerLoginItem()` = `try? SMAppService.mainApp.register()` (`WorkspaceActions.swift:3` imports ServiceManagement; L88-91, comment "Registration failing (unsigned build, user-disabled item) leaves the app running without a login item."). Error swallowed.
- Only caller: `Launcher.start()` first-launch branch (`Launcher.swift:108`).
- No `unregister`, no `SMAppService.status` read, no `LSSharedFileList`, no UI toggle for it anywhere (grep `SMAppService|LSSharedFileList|ServiceManagement|loginItem` in sources).
- Test double: `RecordingSystemActions.loginItemRegistrations` / `onRegisterLoginItem` (`Tests/LauncherCoreTests/InMemoryAdapters.swift:262,271-272,287-290`).
- Present since the first commit `1cf9c4b Trackpad Launcher app (#1)`. Original requirement plans/001 R17 (`plans/001-trackpad-launcher-app/plan.md:366-378`) and R19-ish Quit "MUST NOT remove the login item" (`plan.md:393-399`).

## Termination

- No `NSApplicationDelegate` at all, so no `applicationShouldTerminate`, `applicationWillTerminate`, `applicationShouldHandleReopen`, `applicationShouldTerminateAfterLastWindowClosed` (grep of sources: no `NSApplicationDelegate`, no `.delegate =` on NSApp).
- Only quit path: right-click/Control-click status item menu with item "Quit Trackpad Launcher", `action: #selector(NSApplication.terminate(_:))`, key equivalent "q", nil target → responder chain → `NSApp.terminate` (`MenuBarShell.swift:95-103`). Menu attached only for the click (`statusItem.menu = menu; performClick; statusItem.menu = nil`).
- No `disableSuddenTermination`/`enableSuddenTermination`/`disableAutomaticTermination` calls; no `NSSupportsSuddenTermination`/`NSSupportsAutomaticTermination` keys. No `NSWorkspace.willPowerOffNotification` / session observers. On logout the default AppKit path (terminate with no delegate veto) applies; no state is flushed at quit because every change is saved immediately.
- `isolated deinit`s exist on adapters (e.g. `SystemPermissions.swift:27`, `MultitouchTrackpads.swift:55-59`, `MenuBarShell.swift:78-81`) but process exit does not run them (objects are kept alive by `withExtendedLifetime` until `run()` returns, which `terminate` never does—it calls `exit`).

## Launcher public surface used by shell / composition root

- `init(hardware:preferences:permissions:system:catalog:scanner:store:)` (`Launcher.swift:70-86`).
- `start()` (L89-115) — call once, after status item exists.
- Intents: `setAssignment(_:for:)` L118, `setHandMode(_:)` L137, `setLaunchAnimation(on:)` L145, `setSwipe(on:)` L152, `setWindowSwipe(on:)` L161, `setSwap(on:)` L169, `askForScreenRecording()` L178, `openWindow()` L186 (sets `.open` if closed, `resolveRows()`, `scanner.scan()`), `closeWindow()` L193 (always closes: icon click, Escape, System Settings buttons), `dismissWindow()` L196 (closes only from `.open`, not `.heldOpen`: outside click / resign key).
- Observable reads: `rows`, `switcher`, `windowSwitcher`, `installedApps`, `isWindowOpen` (L22, `window != .closed`), `handMode`, `isLaunchAnimationOn`, `isSwipeOn`, `isSwapOn`, `isWindowSwipeOn`, `activity`, `isAccessibilityGranted`, `screenRecordingHint`.
- Private window state `enum Window { closed, open, heldOpen }` (L44-49): `.heldOpen` is the first-launch window under the AX prompt (prompt takes focus and its buttons are outside clicks). Closed by `closeWindow`, a fired gesture/swipe/swap/window-swipe lift (L265, L309, L345, L361), or an AX grant (L219).

## Own-activation exclusions (seen while tracing; other explorers may go deeper)

- `RunningAppsReader.frontmost()` returns nil when the frontmost app is this process (`LauncherPlatform/RunningAppsReader.swift:36-43`); comment: "it is this app, which never activates except around the Other… chooser."
- Fallback running-apps list excludes own pid and non-`.regular` apps (`RunningAppsReader.swift:24-28`); LaunchServices order excludes own pid (`LauncherPlatform/LaunchServicesOrder.swift:38,44`); `ActivationTracker.note` ignores own pid (`ActivationTracker.swift:25`); `FrontmostAppWindows.read()` returns `.noApp` for own pid (`FrontmostAppWindows.swift:46-51`).
- All keyed on `ProcessInfo.processInfo.processIdentifier`, not on activation policy of self, so they keep working if the app becomes `.regular` while its window is open. But `RunningAppsReader`'s fallback path and `SwitcherPresenter.dockLocation` filter on `activationPolicy == .regular` (`SwitcherPresenter.swift:102-104`) — a `.regular` Trackpad Launcher would pass that filter in `SwitcherPresenter` (no own-pid check there; I did not trace whether that matters).
- `NSApp.activate()` calls: `MenuBarShell.swift:163` (before Other… `NSOpenPanel`), `AnimationTuner.swift:57` (debug tuner click). Launcher panel is `[.borderless, .nonactivatingPanel]`, `level = .popUpMenu`, `hidesOnDeactivate = false`, `canBecomeKey` true (`LauncherUI/LauncherPanel.swift:4,15,24-27,33`).
- Docs: `docs/domain-model.md:66` "Trackpad Launcher is active only when macOS makes it so: right after it is opened (from Finder, or Run in Xcode) and around the Other… chooser."

## Boundaries

- Inputs at start: `UserDefaults.standard["settings"]`, file system app folders (sync scan in `Launcher.init`), TCC state (AX + screen capture preflight), IOKit multitouch device list, trackpad preference domains.
- Outputs at start: `SMAppService.mainApp.register()` (first launch), AX prompt (first launch, if untrusted), first save of `Settings()`, `hardware.run(...)` via `reconcile`, status item creation, panel shown on first launch.
- Composition root is the only place real adapters meet the model; `docs/architecture.md:12` "the app target (composition root only)"; `docs/architecture.md:14` every port has a real and an in-memory adapter.

## Non-Obvious Things

- "First launch" is derived purely from absence of the `"settings"` key; an undecodable or empty record is deliberately NOT first launch so the login item is never re-registered after the user disabled it (`Settings.swift:60-61`). Any new "has run before"/login-state logic must respect this; there is no other marker.
- Login item registration happens once ever (first launch), not every launch; it is idempotent and failures are silently ignored. Unsigned/ad-hoc builds may fail to register.
- The Accessibility prompt is tied to the first launch too; there is no persisted "asked for AX" flag analogous to `hasAskedForScreenRecording`.
- Two synchronous main-thread passes run before `application.run()`: the full catalog enumeration in `Launcher.init` (`Launcher.swift:81`) and the icon pass(es) in `MenuBarShell.init` (`MenuBarShell.swift:28`) / `SwitcherPresenter.init` (`SwitcherPresenter.swift:24,47`). `docs/architecture.md:19` documents this as an intentional exception ("so no click can arrive before their results exist"). Then `start()` triggers a second, async scan (`Launcher.swift:101`).
- `MenuBarShell` must exist before `start()` because the first-launch window is anchored under the status item; `refit()` falls back to top-right of the screen until the status window has a real frame (`MenuBarShell.swift:139-155`) and re-fits on `NSWindow.didMoveNotification` of the status window (L42-46).
- The shell (not the model) is kept alive by `withExtendedLifetime(shell)`; the model is retained by the shell. Nothing else holds the adapters besides the model.
- Debug builds always open the animation tuner at launch (`TrackpadLauncherApp.swift:22-24`) and write `AnimationTuner.*` keys into the same defaults domain.
- Source-scan bans relevant to future lifecycle work: `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `nonisolated(unsafe)`, all logging, `.write(to:` / `createFile(atPath` / `FileHandle(forWriting` (`SourcePolicyTests.swift:13-63`). The scanned roots include `LauncherKit/Sources` and the app target dir `TrackpadLauncher/` (L112-118).
- No single-instance handling anywhere (no `LSMultipleInstancesProhibited`, no own-bundle-id `runningApplications` check, no distributed notification). `docs/performance.md:8` warns that two copies both react to gestures.
- No move-to-/Applications logic anywhere (`Bundle.main` used only for resource lookup in `LauncherUI/LauncherView.swift:130`).
- `release.sh` does not regenerate the xcodeproj; xcodegen must be run first.

## Files Read

- TrackpadLauncher/TrackpadLauncherApp.swift
- project.yml
- Config/Base.xcconfig, Config/Debug.xcconfig, Config/Release.xcconfig
- .gitignore
- /Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher/Info.plist (generated, main checkout)
- LauncherKit/Package.swift
- LauncherKit/Sources/LauncherCore/Launcher.swift
- LauncherKit/Sources/LauncherCore/Settings.swift
- LauncherKit/Sources/LauncherCore/Ports.swift
- LauncherKit/Sources/LauncherCore/Apps.swift (L150-235)
- LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift
- LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift
- LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift (L1-80)
- LauncherKit/Sources/LauncherPlatform/SystemTrackpadPreferences.swift
- LauncherKit/Sources/LauncherPlatform/AppCatalog+System.swift
- LauncherKit/Sources/LauncherPlatform/SystemAppScanner.swift (L1-80)
- LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift
- LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift
- LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift (L25-52)
- LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift (L40-60)
- LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift (parts)
- LauncherKit/Sources/LauncherUI/MenuBarShell.swift
- LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift (L1-80)
- LauncherKit/Sources/LauncherUI/AppIcons.swift (L67-94)
- LauncherKit/Sources/LauncherUI/LauncherPanel.swift (grep)
- LauncherKit/Sources/LauncherUI/LauncherActions.swift, LauncherView.swift (grep)
- LauncherKit/Tests/LauncherCoreTests/PersistenceTests.swift (L1-175)
- LauncherKit/Tests/LauncherCoreTests/AccessibilityTests.swift (L1-80)
- LauncherKit/Tests/LauncherCoreTests/World.swift (L80-120, L175-195)
- LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift (L255-300)
- LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift (L1-118)
- Scripts/release.sh, Scripts/test.sh, Scripts/perf/build.sh
- docs/architecture.md (L7,12-14,19,25,27,30), docs/domain-model.md (L6,66,81), docs/performance.md (L8)
- plans/001-trackpad-launcher-app/plan.md (grep: R17/R18/Quit, L366-399, 554, 579)

## Open Questions

- Whether `SMAppService.mainApp.register()` currently succeeds for the released build and what `status` it reaches (never read in code); no code observes user disabling it.
- Exact AppKit behaviour on logout for this delegate-less LSUIElement app (assumed default terminate; not verified at runtime).
- Whether `SwitcherPresenter.dockLocation`'s lack of an own-pid check would include Trackpad Launcher in switcher icon passes if it became `.regular` while its window is open (not traced; `LaunchServicesOrder` excludes own pid for the row itself).
- Whether `NSApplication.run()` without explicit `finishLaunching` delivers `applicationDidFinishLaunching`-time behaviours a future delegate would rely on (no delegate exists today, so untested here).
