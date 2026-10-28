# Grounding: build, test and release tooling, and the test harness shape

Angle: project.yml, xcconfigs, Scripts/release.sh, Scripts/test.sh, Package.swift, SourcePolicyTests, the in-memory harness (InMemoryAdapters / World), real-adapter tests, docs/performance.md, research notes.
All paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle` unless absolute.

## Components Found

- **project.yml** (xcodegen spec): one target `TrackpadLauncher` (application, macOS), composition root only. `project.yml:15-45`.
- **Config/Base.xcconfig**: deployment target, universal arch, Swift 6, strict concurrency, MainActor default isolation, hardened runtime, manual signing. `Config/Base.xcconfig:1-8`.
- **Config/Debug.xcconfig**: Apple Development identity + team. `Config/Debug.xcconfig:1-3`.
- **Config/Release.xcconfig**: Developer ID Application identity + team + `--timestamp`. `Config/Release.xcconfig:1-4`.
- **Scripts/release.sh**: archive -> developer-id export -> verify -> zip -> notarytool -> staple -> spctl -> final zip. `Scripts/release.sh:1-75`.
- **Scripts/test.sh**: `swift test` in LauncherKit with Xcode's DEVELOPER_DIR. `Scripts/test.sh:1-5`.
- **Scripts/perf/build.sh**: Release-config build signed with Apple Development, runs `xcodegen generate` first. `Scripts/perf/build.sh:1-19`.
- **LauncherKit/Package.swift**: 3 library targets + 2 test targets, macOS 26, Swift 6 mode. `LauncherKit/Package.swift:1-24`.
- **SourcePolicyTests** (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`): substring scan of shipped sources for banned tokens, per-file confinement, LauncherCore import allow-list.
- **InMemoryAdapters.swift** (`LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`): the test adapter for every port: `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `RecordingSystemActions` (+ `FakeWindows`), `InMemoryPermissions`, `InMemoryAppScanner`.
- **World** (`LauncherKit/Tests/LauncherCoreTests/World.swift`): real `Launcher` over the in-memory adapters, a temp dir of fake `.app` bundles, and a throwaway `UserDefaults` suite stored as a path-named cfprefs domain under the temp root.
- **SettingsStore** (`LauncherKit/Sources/LauncherCore/Settings.swift:52-75`): not a port; concrete over a `UserDefaults` instance; tests pass a throwaway suite.
- **WorkspaceActions.registerLoginItem** (`LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:88-91`): the only `SMAppService` call: `try? SMAppService.mainApp.register()`.
- **TrackpadLauncherApp** (`TrackpadLauncher/TrackpadLauncherApp.swift:6-27`): the `@main` composition root; the only `#if DEBUG` in the app target (opens the animation tuner).

## project.yml (xcodegen)

- `name: TrackpadLauncher`, `bundleIdPrefix: com.domasgru`, `deploymentTarget.macOS: "26.0"` (`project.yml:1-5`).
- Two configs: `Debug: debug`, `Release: release` (`project.yml:6-8`); each bound to its xcconfig (`project.yml:9-11`). The `debug`/`release` config *types* are what make xcodegen emit the Xcode preset settings, including `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` for Debug (verified in the generated project, see below).
- Local package `LauncherKit` at `path: LauncherKit` (`project.yml:12-14`).
- Target `TrackpadLauncher`, `type: application`, `platform: macOS` (`project.yml:16-18`).
  - Sources: `TrackpadLauncher/` excluding `Info.plist` (`project.yml:19-21`); `assets/*.svg` and `assets/*.png` as resources (`project.yml:22-24`). (PNG include was added in commit 997a42f, PR #26.)
  - Dependencies: products `LauncherCore`, `LauncherPlatform`, `LauncherUI` (`project.yml:25-31`).
  - `info:` block makes xcodegen *write* `TrackpadLauncher/Info.plist` (`project.yml:32-40`): `CFBundleName`/`CFBundleDisplayName` "Trackpad Launcher", `CFBundleShortVersionString "1.0"`, `CFBundleVersion "1"`, `LSUIElement: true`, `LSMinimumSystemVersion "26.0"`.
  - Settings base: `PRODUCT_BUNDLE_IDENTIFIER: com.domasgru.TrackpadLauncherApp`, `GENERATE_INFOPLIST_FILE: NO`, `ONLY_ACTIVE_ARCH: NO` (`project.yml:41-45`).
- **Not present** in project.yml: no `entitlements:` / `CODE_SIGN_ENTITLEMENTS` (no entitlements file exists anywhere in `git ls-files`), no `schemes:`, no `preBuildScripts`/`postBuildScripts`, no `postCompileScripts`, no asset catalog / app icon, no `CFBundleIconFile`, no login-item helper target, no `SMAppService` daemon/agent plist, no `LSApplicationCategoryType`, no copyright key.
- Version keys are hard-coded literals in project.yml (`1.0` / `1`); nothing derives them from git or an env var.
- Bundle ID note: `com.domasgru.TrackpadLauncherApp` because "the plain ID is taken by an older experiment on this Mac" (`plans/001-trackpad-launcher-app/development-logs.md:60`). Bundle ID continuity matters for R25 (upgrade keeps settings and the SMAppService registration).

### Generated artefacts (gitignored)
- `.gitignore:4-5,7` ignores `TrackpadLauncher.xcodeproj/`, `TrackpadLauncher/Info.plist`, `build/`. The worktree has neither the `.xcodeproj` nor `Info.plist` (only `TrackpadLauncher/TrackpadLauncherApp.swift`); the main checkout at `/Users/dominykasgrubys/code/trackpad-launcher/` has both, generated Oct 26.
- Generated `/Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher/Info.plist:1-28` contains exactly the project.yml keys plus xcodegen defaults (`CFBundleExecutable=$(EXECUTABLE_NAME)`, `CFBundleIdentifier=$(PRODUCT_BUNDLE_IDENTIFIER)`, `CFBundlePackageType APPL`, `CFBundleDevelopmentRegion`), `LSUIElement <true/>` at lines 25-26.
- Generated `/Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher.xcodeproj/project.pbxproj`:
  - Project-level Debug (`:258-318`, base `Debug.xcconfig` at `:260`): `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` (`:314`), `GCC_PREPROCESSOR_DEFINITIONS DEBUG=1` (`:300-303`), `-Onone` (`:315`), `ENABLE_TESTABILITY = YES` (`:295`).
  - Project-level Release (`:319-373`, base `Release.xcconfig` at `:321`): no `DEBUG` condition, `SWIFT_COMPILATION_MODE = wholemodule` (`:369`), `-O` (`:370`), `ENABLE_NS_ASSERTIONS = NO` (`:355`), `dwarf-with-dsym` (`:354`).
  - Target-level Debug/Release (`:241-257`, `:374-390`): `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` (no catalog exists, so no icon), `INFOPLIST_FILE`, `LD_RUNPATH_SEARCH_PATHS @executable_path/../Frameworks`, bundle id.
  - No shared `.xcscheme` files in the generated project (`find ... -name '*.xcscheme'` returned nothing); `xcodebuild -scheme TrackpadLauncher` relies on Xcode auto-creating a scheme for the target.

## Config/*.xcconfig

- Base (`Config/Base.xcconfig:1-8`): `MACOSX_DEPLOYMENT_TARGET = 26.0`, `ARCHS = $(ARCHS_STANDARD)`, `ONLY_ACTIVE_ARCH = NO`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_STYLE = Manual`.
- Debug (`Config/Debug.xcconfig:1-3`): `CODE_SIGN_IDENTITY = Apple Development`, `DEVELOPMENT_TEAM = CQK27876UL`.
- Release (`Config/Release.xcconfig:1-4`): `CODE_SIGN_IDENTITY = Developer ID Application`, `DEVELOPMENT_TEAM = CQK27876UL`, `OTHER_CODE_SIGN_FLAGS = --timestamp`.
- No compile flag in the xcconfigs themselves; `DEBUG` comes only from xcodegen's debug preset (above). Hardened runtime is on in **both** configs, so a Debug build from Xcode is Apple-Development-signed with the runtime flag.
- No `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` override; for Debug, Xcode injects `com.apple.security.get-task-allow` by default (standard Xcode behaviour, not verified on a built product here).

## How a running app could tell development from release (R23) - existing mechanisms

1. **`#if DEBUG` compile condition.** Used today in:
   - `TrackpadLauncher/TrackpadLauncherApp.swift:22-24` (`system.showAnimationTuner()`).
   - `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:101-117` (`tuner`, `showAnimationTuner()`).
   - `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift:51-57` (`current` reads tuner override in DEBUG, `shipped` otherwise) and `:59-...` (Codable extension).
   - `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift:1` (whole file).
   - `LauncherKit/Sources/LauncherPlatform/BounceOverlay.swift:164` (`preview(_:)`).
   This proves the `DEBUG` condition reaches SwiftPM package targets when Xcode builds the Debug config (package code under `#if DEBUG` is called from the app's `#if DEBUG` and links). `docs/architecture.md:22`: "Developer tools live in `#if DEBUG` and never ship."
2. **Code signature** - nothing in the code reads its own signature today: grep for `SecCode`, `SecStaticCode`, `codesign`, `isDevelopment`, `isRelease` over `LauncherKit/Sources` and `TrackpadLauncher` finds nothing.
3. **Bundle location** - nothing reads `Bundle.main.bundleURL` for lifecycle today; the only `Bundle.main` use is resources (`LauncherKit/Sources/LauncherUI/LauncherView.swift:130`).

Mismatch to note: R23 defines a development build as "a build not signed for release" (`plans/021-background-agent-lifecycle/plan.md:325-326`). `Scripts/perf/build.sh:15-16` builds the **Release** configuration (no `DEBUG`) signed with **Apple Development**. So `#if DEBUG` and "signed for release" disagree on the perf build: by signature it is a development build, by compile condition it is a release build. `docs/performance.md:8` requires perf runs on that Release/Apple-Development build. Also, `swift test` builds debug, so `DEBUG` is set in tests.

## Scripts/release.sh (full behaviour)

- Header comment (`Scripts/release.sh:2-6`): archive, export developer-id, notarize, staple; needs a "Developer ID Application" identity and a notarytool keychain profile named by `NOTARY_PROFILE`; "Signing is left to xcodebuild, which signs nested code first and the main executable last; --deep is never used."
- `set -euo pipefail` (`:7`); `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` hard-coded (`:9`); `ROOT` = repo root (`:10`); `TEAM_ID` defaults to `CQK27876UL` (`:11`); `APP_NAME="TrackpadLauncher"` (`:12`); `OUT` = `$RELEASE_OUT` or `$ROOT/build/release` (`:13`).
- Preflight:
  - `security find-identity -v -p codesigning | grep -q "Developer ID Application"` else fail (`:17-18`).
  - `NOTARY_PROFILE` must be set (`:20-21`).
  - `xcrun notarytool history --keychain-profile "$NOTARY_PROFILE"` must succeed (`:23-24`).
- `rm -rf "$OUT"; mkdir -p "$OUT"` (`:26-27`).
- `xcodebuild archive -project "$ROOT/TrackpadLauncher.xcodeproj" -scheme TrackpadLauncher -configuration Release -destination 'generic/platform=macOS' -archivePath "$OUT/TrackpadLauncher.xcarchive" CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID"` (`:29-37`). Generic destination gives the universal binary (`plans/001-trackpad-launcher-app/development-logs.md:60`).
- Writes `ExportOptions.plist`: `method developer-id`, `teamID`, `signingStyle manual`, `signingCertificate Developer ID Application` (`:39-50`).
- `xcodebuild -exportArchive ... -exportPath "$OUT/export"` (`:52-55`); asserts `$OUT/export/TrackpadLauncher.app` exists (`:57-58`).
- Verify: `codesign --verify --strict --verbose=2` (`:60`); `codesign -dv --verbose=2` output must contain `Authority=Developer ID Application` (`:61-63`) and `flags=0x10000(runtime)` (`:64-65`).
- Notarize: `ditto -c -k --keepParent "$APP" "$OUT/TrackpadLauncher-notarize.zip"` (`:67-68`); `xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait` (`:69`); `xcrun stapler staple "$APP"` (`:70`); `xcrun stapler validate "$APP"` (`:71`); `spctl --assess --type execute --verbose=2 "$APP"` (`:72`).
- **Artefact: a zip**, `ditto -c -k --keepParent "$APP" "$OUT/TrackpadLauncher.zip"` (`:74-75`). **No disk image**: no `hdiutil`, no DMG layout, no Applications symlink, no DMG signing/notarisation. The ticket is stapled to the `.app`, not to any container.
- Does **not** run `xcodegen generate` first, unlike `Scripts/perf/build.sh:14`. On a fresh clone or this worktree (no `.xcodeproj`), `release.sh` fails at the archive step unless xcodegen ran.
- Does not check the notarytool result log on failure (`--wait` exit status only, under `set -e`).
- History: unchanged since the first commit `1cf9c4b` (only `project.yml` changed later, in 997a42f). No development log records a successful run; plan 001 says it was "Blocked until a Developer ID certificate exists" (`plans/001-trackpad-launcher-app/plan.md:580`, `:603`, `:1402`, `:1601`).
- Machine state now: `security find-identity -v -p codesigning` lists only one identity, an "Apple Development" one; **no Developer ID Application certificate installed**, so `release.sh` fails at its first preflight. Plan 021 non-goal: "Getting the Developer ID certificate. The developer gets it." (`plans/021-background-agent-lifecycle/plan.md:360`). No DMG tool is installed (`create-dmg`, `dmgbuild`, `appdmg` not on PATH); `hdiutil` is the built-in option. Toolchain present: Xcode 27.1 (27A9275), xcodegen 2.46.0 (docs/architecture.md:6 still says Xcode 26 toolchain).

## Scripts/test.sh and Package.swift

- `Scripts/test.sh:1-5`: `set -euo pipefail`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, `cd LauncherKit`, `exec swift test "$@"`. Tests only the package; the app target is never compiled by tests, but its sources are scanned by SourcePolicyTests.
- `LauncherKit/Package.swift`:
  - `swift-tools-version: 6.2` (`:1`), `platforms: [.macOS(.v26)]` (`:6`), `swiftLanguageModes: [.v6]` (`:23`).
  - Products: `LauncherCore`, `LauncherPlatform`, `LauncherUI` libraries (`:7-11`).
  - Targets: `LauncherCore` (no deps, no settings; nonisolated default) (`:13`); `LauncherPlatform` depends on `LauncherCore` (nonisolated default) (`:14`); `LauncherUI` depends on `LauncherCore` only, with `.defaultIsolation(MainActor.self)` (`:15-19`). Note `LauncherUI` does **not** depend on `LauncherPlatform`; the app target wires them.
  - Test targets: `LauncherCoreTests` -> `LauncherCore` (`:20`); `LauncherPlatformTests` -> `LauncherPlatform`, `LauncherCore` (`:21`). There is **no `LauncherUITests`** target; LauncherUI (where `MenuBarShell` lives) has no tests.
- Tests use Swift Testing (`docs/architecture.md:8`; `import Testing`, `@Suite`, `@Test`).
- `TunerCodingTests` (`LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`) exercises `LaunchTuning: Codable`, which only exists under `#if DEBUG` (`LaunchTuning.swift:59`), and the test has no `#if DEBUG` guard (grep for DEBUG in Tests: no hits). So `swift test -c release` would not compile; the suite depends on the debug configuration.

## SourcePolicyTests - full rules

File: `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`. Doc: "To forbid something new, add it to `banned`; do not write prose." (`:4-5`). Mechanism: plain substring match per line (`scan`, `:219-227`), so comments and string literals count. Confinement matches by `lastPathComponent` (`:221`), so a file name anywhere in the scanned trees qualifies.

Scanned roots (`:111-117`): `LauncherKit/Sources` and `<repo>/TrackpadLauncher` (the app target dir). Tests are not scanned (tests use `Task.sleep`, `.write(to:` freely). `scanVisitsEveryLibraryTarget` asserts files under each of `LauncherCore`, `LauncherPlatform`, `LauncherUI` and `/TrackpadLauncher/` were visited (`:169-175`).

### `banned` (`:13-64`) - token -> rule
- log: `print(`, `debugPrint(`, `dump(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os` (`:14-21`)
- network: `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream` (`:22-26`)
- own files: `FileHandle(forWriting`, `.write(to:`, `createFile(atPath` (`:27-29`)
- timer: `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink` (`:30-31,33-35`); polling: `Task.sleep` (`:32`)
- no Input Monitoring or event posting: `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `IOHIDRequestAccess`, `IOHIDCheckAccess`, `CGRequestPostEventAccess`, `CGPreflightPostEventAccess` (`:36-42`)
- R9 no keyboard: `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged` (`:43-48`)
- `ScrollWheel` - "scrolling is read only by the click tap" (`:49`)
- R9 never synthesise: `.post(tap:`, `CGEventPost`, `postToPid` (`:50-52`)
- `nonisolated(unsafe)` - one writer per field (`:53`)
- `perform: {` - run-loop source perform must be a file-scope constant (`:54-56`)
- window switcher only raises: `AXUIElementSetAttributeValue`, `kAXPressAction` (`:57-58`)
- previews: `SCStream(`, `SCRecordingOutput`, `CGImageDestination`, `representation(using`, `tiffRepresentation` (`:59-63`)

### `confined` (`:75-105`) - token -> only in files
- `AXIsProcessTrusted` -> `SystemPermissions.swift` ("R9 one permission, one adapter") (`:76`)
- `notify_register` -> `SystemPermissions.swift` ("R7 the trust push") (`:77`)
- `ScreenCaptureAccess` -> `SystemPermissions.swift` (`:78-79`)
- `ScreenCaptureKit`, `SCShareableContent`, `SCScreenshotManager` -> `PreviewCapture.swift` (`:80-82`)
- `tapCreate`, `CGEventTapCreate`, `tapEnable`, `tapIsEnabled` -> `ClickTap.swift` (`:83-86`)
- `mouseMoved` -> `BounceOverlay.swift`, `ClickTap.swift` (`:87-89`)
- **NSEvent monitors**:
  ```
  Confined(
      token: "addGlobalMonitorForEvents", onlyIn: ["MenuBarShell.swift", "BounceOverlay.swift"],
      rule: "pointer moves are read only while a launch bounce shows"),
  Confined(
      token: "addLocalMonitorForEvents", onlyIn: ["BounceOverlay.swift"],
      rule: "pointer moves are read only while a launch bounce shows"),
  ```
  (`:90-95`). The MenuBarShell use is the launcher window's outside-click monitor: `LauncherKit/Sources/LauncherUI/MenuBarShell.swift:126-130` (`.leftMouseDown, .rightMouseDown, .otherMouseDown` -> `launcher.dismissWindow()`), removed in `hide()` (`:133-137`). If MenuBarShell.swift is deleted/renamed in the lifecycle change, this entry's allow-list must be edited (a stale allowed name is harmless to the test but misleading; a new file using the monitor fails it).
- `scrollWheel` -> `ClickTap.swift` (`:96`)
- `_LSCopyApplicationArrayInFrontToBackOrder`, `_LSCopyApplicationInformation` -> `LaunchServicesOrder.swift` (`:97-102`)
- `AXUIElement`, `CGWindowList` -> `FrontmostAppWindows.swift`, `LaunchWatch.swift` (`:103-104`)
- **Permissions**: the three permission entries above (`:76-79`) all point at `SystemPermissions.swift`.
- **Lifecycle-related**: there is **no** entry for `SMAppService`, `ServiceManagement`, `NSApplication.terminate`, `setActivationPolicy`, `NSStatusItem`/`NSStatusBar`, `SecCode*`/`SecStaticCode*`, `Bundle.main.bundleURL`, `FileManager.moveItem/copyItem/replaceItem`, `hdiutil`/`Process`, or `NSWorkspace.openApplication`. Today `SMAppService` appears only in `WorkspaceActions.swift:3,90` (import + call) by convention, not by rule. `docs/architecture.md:12` lists ServiceManagement as a LauncherPlatform dependency.

### Import allow-list
- `coreAllowedImports = ["Foundation", "Observation"]` (`:177`); `coreImportsOnlyFoundationAndObservation` scans `Sources/LauncherCore` (`:179-183`). Import parser handles `@preconcurrency`/`public`/`internal` prefixes and submodules (`:198-210`). So a new port protocol in LauncherCore cannot import ServiceManagement/Security/AppKit.

### Adding a rule
Append an `Entry(token:rule:)` to `banned` or a `Confined(token:onlyIn:rule:)` to `confined`; both are `@Test(arguments:)`-parameterised (`:119-129`), so each entry becomes its own test case. Meta-tests prove the scanner works on planted temp files (`:131-167`, `:185-195`).

### Rules the lifecycle/release work will brush against
- "own files" ban (`.write(to:`, `createFile(atPath`, `FileHandle(forWriting`) + `docs/architecture.md:27` "no files written other than settings in `UserDefaults`". A self-move into /Applications (R18-R19) would write files via `FileManager.copyItem`/`moveItem`/`replaceItemAt` which are not banned tokens, but contradict the architecture prose; the prose may need amending and a confinement entry added.
- `Timer`, `asyncAfter`, `Task.sleep` bans (`:30-35`): any "wait then relaunch"/"wait for the old process to exit" logic cannot use them; `docs/architecture.md:20` requires pushes only.
- `Timer` is a bare substring: even a comment or identifier containing `Timer` (e.g. `NSBackgroundActivityScheduler` is fine, but `relaunchTimer` is not) fails.

## Test harness shape

### Rules (docs/architecture.md:14)
"Every port has exactly two adapters: the real one in `LauncherPlatform` and an in-memory one in the tests. Concrete types that can be pointed at a temp directory or a throwaway `UserDefaults` suite are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous." Also `:13`: framework/wire types (`NSRunningApplication`, `UserDefaults` keys, ...) never cross a port.

### Ports (LauncherCore/Ports.swift)
- `TrackpadHardware` (`:26-46`), `TrackpadPreferences` (`:49-54`), `SystemActions` (`:57-125`), `Permissions` (`:133-...`), plus `AppScanner` (used by `InMemoryAppScanner`). All `@MainActor`, `AnyObject`, callbacks as `var onX: (@MainActor ...)?`.
- `SystemActions.registerLoginItem()` doc: "Open at Login. Idempotent. Called only on first launch." (`Ports.swift:60-61`). No unregister, no status read, no "is enabled" query on any port.

### Model's use of the login item
- `Launcher.start()` (`LauncherKit/Sources/LauncherCore/Launcher.swift:89-115`): wires callbacks, `reconcile()`, then `if isFirstLaunch { system.registerLoginItem(); if !isAccessibilityGranted { permissions.ask(.accessibility) }; store.save(settings); window = prompting ? .heldOpen : .open }` (`:105-112`). Comment: both effects come before the first save so a crash repeats them (`:106-107`).
- `isFirstLaunch = stored == nil` (`Launcher.swift:83`); undecodable record loads as `Settings()`, not first launch (`Settings.swift:62-67`), so a user who turned the item off is never re-enrolled.
- Real adapter: `try? SMAppService.mainApp.register()` with comment "Registration failing (unsigned build, user-disabled item) leaves the app running without a login item." (`WorkspaceActions.swift:88-91`).

### InMemoryAdapters.swift
- `InMemoryTrackpads: TrackpadHardware` (`:6-243`): real `GestureRecognizer` + real `TapFilters`, scripted frames, synchronous delivery; `attach/detach/sleep/wake` (`:85-98`); `touch(_:on:)` (`:104-123`); `inject` (`:242`).
- `InMemoryTrackpadPreferences` (`:245-258`): `set(_:rawValue:for:)` pushes `onChange` synchronously.
- `RecordingSystemActions: SystemActions` (`:260-347`): records `broughtToFront`, `loginItemRegistrations` (`:262`, incremented in `registerLoginItem()` `:287-290`), `onRegisterLoginItem` hook "so a test can observe what is stored at that moment" (`:271-272`), launch animations, bounces, `report(_:for:)` to push launch progress (`:346`).
- `FakeWindows` (`:352-433`).
- `InMemoryPermissions: Permissions` (`:435-459`): `granted`, `asks` log, `onAsk` hook, `set(_:granted:push:)` (push only on real change; `push: false` models a withheld broadcast).
- `InMemoryAppScanner: AppScanner` (`:462-497`): runs real `catalog.installedApps()` synchronously; `foldersChanged()` stands in for FSEvents; `holdScans()/deliverHeldScan()`.
- Pattern for a new port: a `@MainActor final class` conforming to the protocol, recording every command in `private(set)` arrays/counters, exposing `onX` hooks to snapshot state at call time, and test-only methods that push callbacks synchronously.

### World.swift
- `@MainActor final class World` (`:36-190`): creates `tl-world-<UUID>` under `FileManager.default.temporaryDirectory` with `Applications`, `SystemApplications`, `UserApplications`, `CoreServices`, `Downloads` (`:63-73`); suite name is an absolute path under root so the cfprefs domain lives at `<root>/Preferences.plist` (`:43-45,70`); `deinit` removes root (`:107-109`). Hooks must capture the World `unowned` or the temp dir leaks (`:34-35`).
- Builds the real `AppCatalog` over temp roots with injected `registeredCopies`, `lastOpened`, `displayName` closures (`:81-86`), real `SettingsStore(defaults: UserDefaults(suiteName:))` (`:89`), and the real `Launcher` via `makeLauncher` (`:98-105`). Constructor params: `apps`, `attached`, `accessGranted`, `screenRecording` (`:59-62`).
- `relaunch()` (`:182-189`): new `SettingsStore` + new `Launcher` over the same adapters and suite - this is how tests model a second launch (no process restart).
- `seedSettingsRecord(_:)` (`:112-114`) plants a raw record, as an earlier build would.
- `install/remove/move/trash` fake bundles (`:125-165`); `install` writes `Contents/Info.plist` with a `CFBundleIdentifier` (`:126-134`).
- Gesture drivers `tap`, `play`, `swipe`, `windowSwipe`, `swap`, `playFrameByFrame` (`:167-311`); fixtures `switcherWorld`, `windowWorld` (`:219-264`).
- Test style: `World()` -> `world.launcher.start()` -> act through `world.launcher.<intent>` / adapter pushes -> `#expect` on `world.launcher.<state>` and adapter logs. Examples: `PersistenceTests.swift:21-34` (first launch: window open, `loginItemRegistrations == 1`), `:36-45` (relaunch does not register again), `:47-61` (undecodable record = not first launch, 0 registrations), `:63-71` (login item registered before first save, via `onRegisterLoginItem`); `AccessibilityTests.swift:20-36` (prompt once, window `.heldOpen` until explicit close, `loginItemRegistrations == 1`).
- Note: the model owns `isWindowOpen`/`window` state (`.open`, `.heldOpen`) and `dismissWindow()`/`closeWindow()` intents; the shell only renders it.

### Real adapter tests (LauncherPlatformTests)
- Use `@testable import LauncherPlatform` to reach internal inits/constants.
- `SystemPermissionsTests.swift:9-63`: real `SystemPermissions(trusted:capturing:)` with injected `Mutex<Bool>` reads (`SystemPermissions.swift:15-25`), real Darwin notifications posted with `notify_post(SystemPermissions.changeNotification)`; push awaited through an `AsyncStream` with a `Task.sleep` bound ("the push is awaited, never polled", `:10-26`).
- `SystemTrackpadPreferencesTests.swift:7-77`: throwaway cfprefs domains named by absolute temp paths, written by a child `/usr/bin/defaults` process (`:12-32`), adapter built with `SystemTrackpadPreferences(domains:)` (`:54`), same AsyncStream-with-bound pattern (`:35-48`).
- `SystemAppScannerTests.swift:10-...`: `Tree` temp dir `tl-scanner-<UUID>` with real FSEvents, removed in `deinit`; `Gate` semaphore to block off-main reads.
- `AppCatalogSystemTests.swift:8-15`: reads the real `/System/Applications/FindMy.app`.
- `WorkspaceActions` has a test-only `init(screen:promptsUser:)` (`WorkspaceActions.swift:22-30`); there is **no** test of `registerLoginItem` / `SMAppService` (no WorkspaceActions login-item test file).
- Convention: real adapters get injectable seams (closures, domain names, root URLs) via default-argument inits, the public default reaching the real system; temp names are `tl-<kind>-<UUID>`.

## docs/performance.md constraints

- Measure Release builds only (`docs/performance.md:3`). `Scripts/perf/build.sh` = Release config, `-O`, WMO, universal, hardened runtime, Apple Development signing "in place of Developer ID, which does not change runtime cost" (`:8`). "Never measure a Debug build: it is unoptimised, and it opens the animation tuner." (`:8`). Quit other copies first, "including one paused under Xcode, because two copies both react to gestures" (`:8`). "Accessibility stays granted across rebuilds signed by the same identity." (`:8`).
- Startup method: quit, relaunch with `open`, sample every 500 ms for 6 s (`:25`).
- Baseline (`:42-54`): hands off 60 s: 0.77 ms total CPU, 0 idle wakeups, 1-4 interrupt wakeups/min (`:47`); startup first 6 s: 1078 ms, almost all in the first second, settles at 0 (`:54`).
- Memory (`:56-59`): 37-42 MB after launch; 57 MB after the menu window first opened and stays after close (MALLOC_SMALL 22->36 MB, CG images, CA).
- Decision: "Release the menu window's content on close (about 15 MB): rejected" (`:79`) because plan 003 keeps pickers instant on every open. Relevant if the lifecycle change closes/destroys the settings window on close.
- Architecture idle constraint: "No timers, no polling, no background loops: every input is a push ... This is what keeps idle CPU at zero." (`docs/architecture.md:20`).

## Distribution policy (docs)
- `docs/architecture.md:30`: "Direct download only, signed with Developer ID, hardened runtime, notarized with `notarytool` and stapled. Never sign with `--deep`; the main executable is signed last."
- `docs/architecture.md:7`: xcodegen project builds only the bundle (Info.plist, resources, hardened runtime, signing, archiving); `swift test` runs all behaviour.
- `docs/architecture.md:26` + `plans/001-trackpad-launcher-app/.temp/architect/checks/status-item-and-hardened-runtime.md:9-11`: MultitouchSupport `dlopen` needs no entitlement / no library-validation exception under hardened runtime (Apple-signed); "Do not add `--deep` when signing; sign the main executable last with `-o runtime`."
- Plan 001 R23 verification list (`plans/001-trackpad-launcher-app/plan.md:1519`): `lipo -archs`, `codesign -dv` `flags=0x10000(runtime)` and `Authority=Developer ID Application`, `spctl` `source=Notarized Developer ID`, macOS 15 VM alert. Plan 001 open question: "Is a login item registered by an Apple Development-signed debug build acceptable on the developer's machine?" (`:1402`), and "Apple Development signing is enough for `SMAppService` locally" (`:580`).

## research/ directory
- None. `find . -type d -iname '*research*'` in the worktree and `find /Users/dominykasgrubys/code/trackpad-launcher -maxdepth 3 -type d -iname '*research*'` both return nothing. No tracked file name matches research/notar/dmg/login/smapp.
- Nearest prior notes: `plans/001-trackpad-launcher-app/.temp/architect/checks/status-item-and-hardened-runtime.md` (hardened runtime, no `--deep`); `plans/017-launch-wait-bounce/.temp/architect/grounding/how-lifecycle.md:177-197` (NSWorkspace launch notifications are not posted for LSUIElement apps; KVO on `runningApplications` instead). Plan 021 itself: `plans/021-background-agent-lifecycle/plan.md:317-338` (R22-R24), `:360` (certificate is a non-goal).

## Flow

### Test run
1. `Scripts/test.sh` sets `DEVELOPER_DIR`, `cd LauncherKit`, `exec swift test "$@"` (`Scripts/test.sh:3-5`).
2. SwiftPM builds the debug config (DEBUG defined), builds `LauncherCoreTests` and `LauncherPlatformTests` (`Package.swift:20-21`).
3. `SourcePolicyTests` scans `LauncherKit/Sources` and `TrackpadLauncher/` (`SourcePolicyTests.swift:111-117`); behavioural tests build `World`s over temp dirs and throwaway suites; platform tests drive real adapters against temp dirs, path-named cfprefs domains and real Darwin notifications.

### Development build (Xcode Run)
1. `xcodegen generate` (manual; not scripted except in perf/build.sh) writes `TrackpadLauncher.xcodeproj` and `TrackpadLauncher/Info.plist` from `project.yml`.
2. Xcode builds Debug: `Debug.xcconfig` -> Apple Development, team CQK27876UL, hardened runtime, `DEBUG` condition; package targets built with DEBUG too.
3. App launches: `TrackpadLauncherApp.main()` builds adapters, `Launcher`, `MenuBarShell`, calls `launcher.start()`, opens the animation tuner under `#if DEBUG`, runs `NSApplication` (`TrackpadLauncherApp.swift:8-25`). `LSUIElement` keeps it out of the Dock.
4. On first launch (no settings record) `SMAppService.mainApp.register()` registers whatever bundle is running (e.g. the DerivedData copy) as the login item.

### Release build
1. (Precondition, not automated) `xcodegen generate`.
2. `Scripts/release.sh`: preflight identity + notary profile -> `xcodebuild archive` Release generic macOS with Developer ID -> export developer-id -> codesign verify + authority + runtime flag checks -> zip -> `notarytool submit --wait` -> `stapler staple` + `validate` -> `spctl --assess` -> `TrackpadLauncher.zip` in `build/release/` (`Scripts/release.sh:17-75`).

## Files Read
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/project.yml
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Config/Base.xcconfig
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Config/Debug.xcconfig
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Config/Release.xcconfig
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/.gitignore
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Scripts/release.sh
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Scripts/test.sh
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/Scripts/perf/build.sh
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Package.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/TrackpadLauncher/TrackpadLauncherApp.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherCoreTests/World.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherCoreTests/PersistenceTests.swift (lines 1-80)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherCoreTests/AccessibilityTests.swift (lines 1-40)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherPlatformTests/SystemPermissionsTests.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherPlatformTests/SystemTrackpadPreferencesTests.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherPlatformTests/AppCatalogSystemTests.swift
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherPlatformTests/SystemAppScannerTests.swift (lines 1-60)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift (lines 1-20)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherCore/Ports.swift (lines 1-140)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherCore/Launcher.swift (lines 80-130)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherCore/Settings.swift (lines 40-75)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift (lines 1-120)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift (lines 40-75)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherPlatform/BounceOverlay.swift (lines 155-180)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift (lines 1-30)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift (lines 1-30)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/LauncherKit/Sources/LauncherUI/MenuBarShell.swift (lines 124-137 via grep)
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/docs/performance.md
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/docs/architecture.md
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/plans/001-trackpad-launcher-app/.temp/architect/checks/status-item-and-hardened-runtime.md
- /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/plans/021-background-agent-lifecycle/plan.md (lines 315-361 + grep)
- Grep only: plans/001-trackpad-launcher-app/plan.md, plans/001-trackpad-launcher-app/development-logs.md, plans/017-launch-wait-bounce/.temp/architect/grounding/how-lifecycle.md
- /Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher/Info.plist (main checkout, generated)
- /Users/dominykasgrubys/code/trackpad-launcher/TrackpadLauncher.xcodeproj/project.pbxproj (main checkout, generated; lines 236-395)

## Boundaries
- Inputs to the build: `project.yml` + `Config/*.xcconfig` -> xcodegen -> `.xcodeproj` + `Info.plist` (both gitignored). `LauncherKit` is consumed as a local package (`project.yml:12-14`).
- Release script inputs: keychain Developer ID identity, `NOTARY_PROFILE` env, optional `TEAM_ID`, `RELEASE_OUT`; hard-coded `/Applications/Xcode.app`. Output: `build/release/TrackpadLauncher.zip` (+ xcarchive, export, notarize zip).
- Runtime boundary with login items: `SystemActions.registerLoginItem()` port (`Ports.swift:60-61`) -> `WorkspaceActions` -> `SMAppService.mainApp.register()` (`WorkspaceActions.swift:89-90`). The model calls it only on first launch (`Launcher.swift:105-108`). Test double: `RecordingSystemActions.loginItemRegistrations` (`InMemoryAdapters.swift:262,287-290`).
- Test boundary: `swift test` only sees LauncherKit; the app target is only text-scanned. LauncherUI has no test target.
- Policy boundary: SourcePolicyTests reads `LauncherKit/Sources/**` and `TrackpadLauncher/**` Swift files; it is the enforcement point for "no timers / no logging / no network / no own files / confined APIs".

## Non-Obvious Things
1. `release.sh` produces a **zip, not a disk image** (`Scripts/release.sh:74-75`); R24 needs a new DMG step (create, sign with Developer ID, notarise, staple the DMG). The notarised/stapled object today is the `.app` only.
2. `release.sh` never runs `xcodegen generate`, while `Scripts/perf/build.sh:14` does. The `.xcodeproj` is gitignored (`.gitignore:4`), so "one command from the repository" (R24) fails on a clean checkout/worktree today.
3. No Developer ID certificate on this Mac (only Apple Development); `release.sh` exits at `:17-18`. The release script has never been run end-to-end per the logs.
4. `#if DEBUG` vs "signed for release" diverge: the perf build is Release-config but Apple-Development-signed (`Scripts/perf/build.sh:15-16`). A runtime check based on the signature would treat perf builds as development (no move dialog), a check based on `#if DEBUG` would treat them as release (move dialog when run from `build/perf/dd/...`).
5. Hardened runtime is on in Debug too (`Config/Base.xcconfig:7`), so "has the runtime flag" cannot discriminate development from release; `Authority=Developer ID Application` (what `release.sh:62` checks) can.
6. `SMAppService.mainApp.register()` registers the *currently running* bundle; a first launch from Xcode/DerivedData or `build/perf` registers that copy. Errors are swallowed (`WorkspaceActions.swift:88-91`). There is no unregister or status read anywhere; R10/R11 (Quit turns login off and back on) and R22 need new port surface.
7. SourcePolicyTests is a substring scan including comments; `Timer`, `asyncAfter`, `Task.sleep` are banned outright in shipped code. Confinement is keyed by file *name* only (`SourcePolicyTests.swift:221`).
8. `addGlobalMonitorForEvents` is allowed in `MenuBarShell.swift` (the outside-click dismiss monitor, `MenuBarShell.swift:126-130`) - its rule text says "pointer moves are read only while a launch bounce shows", which does not describe the MenuBarShell use; the architecture doc covers it ("the launcher window's outside-click monitor", `docs/architecture.md:25`). Removing the menu bar shell should drop that file from the allow-list.
9. No LauncherUI test target: shell behaviour (status item, panel, activation policy) is untested by `swift test`; only the model's `isWindowOpen`/`window` state is.
10. `TunerCodingTests` depend on `DEBUG` being defined in tests (`LaunchTuning.swift:59`), so the suite only builds in the debug configuration.
11. `docs/architecture.md:27` "no files written other than settings in UserDefaults" - a move-to-Applications feature would write the app bundle; the token bans do not catch `FileManager.copyItem/moveItem`, so the doc and the test disagree in scope.
12. No app icon: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in the generated project but no asset catalog exists. Once the app shows in the Dock (plan 021 R6) and in a DMG window, the generic icon would show. (Observation; not in my angle's requirements.)
13. Version is a literal `1.0`/`1` in `project.yml:37-38`; nothing bumps it.

## Open Questions
- Whether Xcode 27.1 / xcodegen 2.46 still auto-creates a scheme named `TrackpadLauncher` for `xcodebuild -scheme` with no shared schemes; it evidently worked when perf/build.sh was last run, but I did not run a build.
- Whether Xcode's Debug build actually injects `com.apple.security.get-task-allow` here (standard behaviour; not verified on a built product).
- Whether `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` reaches SwiftPM package targets via Xcode is inferred from the code compiling/linking (`TrackpadLauncherApp.swift:22-24` calls a `#if DEBUG` public method of `LauncherPlatform`), not from build logs.
- Team ID `CQK27876UL` in xcconfigs vs the installed Apple Development identity name suffix `(JFC6LR2268)`: the suffix is likely the certificate's own identifier, not the team; I did not confirm the team of the installed cert.
