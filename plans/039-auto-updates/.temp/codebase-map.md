# Codebase map for revision 2 (as of 0bcf172)

Root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/039-auto-updates` (paths below are relative to it).
Branch `feature/039-auto-updates`. Merge-base with `main` is `38af524` (Version 1.0.15). Revision 1 commits:
`8f4aa98..d815a2c`, and `0bcf172` is the plan revision 2 commit (docs/architecture.md, docs/domain-model.md, plan.md,
`plans/039-auto-updates/assets/update-card-symbol.svg`).
**Note:** `main` is one commit ahead (`365ec42` "Turn the Accessibility hint's gear counter-clockwise": GearView.swift,
GearViewTests.swift, docs/domain-model.md). The branch still turns the gear clockwise (`GearView.swift:87` comment
"a positive angle turns clockwise"). Expect a conflict there on rebase/merge.

---

## 1. Package, build, scripts

### LauncherKit/Package.swift (39 lines, tools 6.2, `.macOS(.v26)`, `swiftLanguageModes: [.v6]`)
- L7-11 products: libraries `LauncherCore`, `LauncherPlatform`, `LauncherUI`.
- L12-14 `dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")]`
- L16 `.target(name: "LauncherCore")`
- L17-20 `LauncherPlatform` deps `["LauncherCore", .product(name: "Sparkle", package: "Sparkle")]`
- L21-25 `LauncherUI` deps `["LauncherCore"]`, `swiftSettings: [.defaultIsolation(MainActor.self)]`
- L26 `.target(name: "CardContract")`; L27 `.executableTarget(name: "card-contract", dependencies: ["CardContract"])`
- Test targets: L28 `CardContractTests` (CardContract, card-contract); L29 `ReleaseTests` (no deps); L30
  `LauncherCoreTests` (LauncherCore); L31-35 `LauncherUITests` (LauncherUI, LauncherCore; MainActor default isolation);
  L36 `LauncherPlatformTests` (LauncherPlatform, LauncherCore).
- **No `resources:` anywhere.** No binaryTarget yet.

### LauncherKit/Package.resolved
One pin: `identity "sparkle"`, `remoteSourceControl`, `revision ab7d71291238df6e0492143b120c9b696a35f603`,
`version "2.10.1"`; `originHash ab922dca…`. Read by `SparkleEngineTests.sparkleInternalsWereProvenOnThePinnedVersion`
(see section 5). Revision 1 added it (main had no Package.resolved).

### Makefile
- L5 `export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer`
- L13-14 `test:` → `Scripts/test.sh`; L16-17 `project:` → `xcodegen generate`
- L19-24 `run:` → `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath build/dev -quiet -packageAuthorizationProvider netrc` (the `-packageAuthorizationProvider netrc` was added by revision 1), then pkill + `open`.
- L26-36 `release`, `release-patch|minor|major` → `Scripts/release.sh [patch|minor|major]`.

### Scripts/test.sh (5 lines)
`exec swift test --disable-keychain "$@"` (L5). `--disable-keychain` added by revision 1 (main: `swift test "$@"`).

### project.yml (59 lines)
- L12-14 `packages: LauncherKit: path: LauncherKit` (local package only; **no Sparkle package reference in project.yml**;
  Sparkle reaches the app only through LauncherPlatform's dependency).
- L19-24 sources: `TrackpadLauncher` (excludes Info.plist) and `assets` `includes: ["*.svg", "*.png"]`,
  `buildPhase: resources` → this is how `gear.svg`, `guide.svg` and the PNGs reach `Bundle.main`.
- L25-31 dependencies: LauncherKit products LauncherCore, LauncherPlatform, LauncherUI.
- Info.plist keys (L35-46):
  - L41 `SUFeedURL: https://raw.githubusercontent.com/domasgru/trackpad-launcher/main/appcast.xml`
  - L42 `SUPublicEDKey: ""` (empty)
  - L43 `SUEnableAutomaticChecks: true`
  - L44 `SUAutomaticallyUpdate: true`
  - L45 `SUVerifyUpdateBeforeExtraction: true`
  - L46 `TLUpdateDownloads: https://github.com/domasgru/trackpad-launcher/releases/download/`
- Build settings (L47-59): nothing about keychain/netrc. Config/*.xcconfig: Base (Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, hardened runtime, manual signing), Debug (Apple Development, team CQK27876UL), Release (Developer ID Application, `OTHER_CODE_SIGN_FLAGS = --timestamp`), Version (`MARKETING_VERSION = 1.0.15`, `CURRENT_PROJECT_VERSION = 16`).
- `SourcePolicyTests.cardContractStaysFrozenApartFromTheApp` asserts project.yml contains neither `CardContract` nor `card-contract`.

### Scripts/release.sh (Sparkle-related parts)
- L12-18 header prose: feed `appcast.xml`, signing with keychain key, "back it up with generate_keys -x".
- L62 `FEED="$ROOT/appcast.xml"`; **L63 `SPARKLE_BIN="$ROOT/LauncherKit/.build/artifacts/sparkle/Sparkle/bin"`** (where `sign_update` / `generate_keys` are found: SwiftPM's artifact extraction of the binary xcframework zip).
- `preflight_checkout()` L142-161:
  - L150 `(cd "$ROOT/LauncherKit" && swift package --disable-keychain resolve) || fail "cannot resolve the package."`
  - L151 `[ -x "$SPARKLE_BIN/sign_update" ] || fail "Sparkle's tools are missing from the resolved package."`
  - L152-153 `[ "$("$SPARKLE_BIN/generate_keys" -p)" = "$(sed -n 's/^ *SUPublicEDKey: *//p' "$ROOT/project.yml")" ] || fail "the keychain's update key is not the one project.yml ships; ..."`
  - L154 `xmllint --noout "$FEED"`
  - plus gh auth, Developer ID identity, notarytool profile, xcodegen, git clean/main/origin checks.
- `preflight_build_number()` L188: reads `<sparkle:version>` max from feed.
- `archive_and_check()` L222-273: `aa archive ... -exclude-field uid,gid,xat,acl,flg`, `aa extract`, codesign checks; L265-267 strict mode: `codesign -dv "$copy/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"` must have `TeamIdentifier=$TEAM_ID` ("Sparkle's atomic swap needs its installer and the update on one team").
- `write_feed()` L358-374: `"$SPARKLE_BIN/sign_update" "$AAR"` (L361) and `--verify` (L363); builds `<item>` with `sparkle:version`, `shortVersionString`, `minimumSystemVersion`.
- `publish_feed()` L378.
- `--archive-only` L399-407 runs `swift run --package-path "$ROOT/LauncherKit" --disable-keychain card-contract "$AAR" --team ... --identifier ...` (L403).
- Main flow: `xcodebuild archive -packageAuthorizationProvider netrc ...` (L449-450), `xcodebuild -exportArchive -packageAuthorizationProvider netrc ...` (L473-474), card-contract again L499 with `--disable-keychain`.

### Every hit of `--disable-keychain` / `-packageAuthorizationProvider netrc` (git grep, excluding plans/)
All were added by revision 1 (none exist on main).
| File:line | Text |
|---|---|
| Makefile:21 | `-derivedDataPath build/dev -quiet -packageAuthorizationProvider netrc` |
| Scripts/perf/build.sh:16 | `-packageAuthorizationProvider netrc \` |
| Scripts/release.sh:150 | `swift package --disable-keychain resolve` |
| Scripts/release.sh:403 | `swift run --package-path ... --disable-keychain card-contract` |
| Scripts/release.sh:450 | `-packageAuthorizationProvider netrc \` (archive) |
| Scripts/release.sh:474 | `-packageAuthorizationProvider netrc \` (exportArchive) |
| Scripts/release.sh:499 | `swift run --package-path ... --disable-keychain card-contract` |
| Scripts/test.sh:5 | `exec swift test --disable-keychain "$@"` |
| Scripts/update-e2e.sh:511 | `swift package --disable-keychain resolve` (in `ensure_sparkle_tools`) |
| Scripts/update-e2e.sh:573 | `-packageAuthorizationProvider netrc \` (archive) |
| Scripts/update-e2e.sh:599 | `-packageAuthorizationProvider netrc \` (exportArchive) |
| Scripts/update-e2e.sh:777 | `swift run ... --disable-keychain card-contract` |
Plans files also mention them (plan.md, development-logs.md, .temp/slices/S*.md, .temp/architect/*), not code.

Other places naming `.build/artifacts/sparkle/Sparkle/bin`: `Scripts/update-e2e.sh:42` (`SPARKLE_BIN`),
`LauncherKit/Tests/ReleaseTests/ReleaseHarness.swift:16` (`realSparkleBin`), `README.md:71-72` (generate_keys -x backup
instructions). README L74-80 "How users get it" describes the revision 1 idle-minute behaviour.

---

## 2. LauncherCore update model

### LauncherCore/Updater.swift (136 lines)
- L5-9 `public struct UpdatableCopy: Equatable, Sendable { public init?(placement: Placement, developerIDSigned: Bool, canReplaceItself: Bool) }` → nil unless `developerIDSigned, placement == .installed, canReplaceItself`.
- L11-18 `public enum CycleOutcome { case nothingNew, requestFailed, failed }`
- L20-25 `public enum HeldUpdate { case genuine, notGenuine }`
- L27-33 `public enum UpdateEngineEvent { case held(HeldUpdate); case cycleEnded(CycleOutcome) }`
- L36 `@MainActor public final class Updater` (not @Observable)
  - L38 `public var onHandOver: (@MainActor () -> Void)?` (set by Lifecycle)
  - private: `engine: any UpdateEngine`, `connection: any Connection`, `clock: any IdleClock`, `launcher: Launcher?`
  - L44-55 `private enum Phase { resting, ready, awaitingConnection(retrySpent: Bool), handedOver }`
  - L59 `public init(_ copy: UpdatableCopy, engine:, connection:, clock:)`
  - L67-73 `public func start(watching launcher: Launcher, opening: Opening)`: sets `engine.onEvent`, `connection.onChange`, `engine.start()`, `if opening != .afterUpdate { engine.check() }`.
  - L75-88 `handle(_:)`: `.held(.genuine)` → `.ready`; `.held(.notGenuine)` → `engine.discardHeldUpdate()`; `.cycleEnded(.requestFailed)` → `.awaitingConnection(retrySpent: false)` unless already awaiting; other `.cycleEnded` → `.resting`.
  - L90-99 `connectionChanged`: drop resets `retrySpent`; up with `!spent` → set spent, `engine.check()`.
  - L101-108 `useChanged(_ inUse:)`: in `.ready`: in use → `clock.cancel()`, else `clock.wait(.seconds(60)) { idleMinutePassed() }`.
  - L110-117 `idleMinutePassed`: guards `phase == .ready, launcher?.isInUse == false`, `engine.armRestart()` else stay; `enter(.handedOver); onHandOver?()`.
  - L120-135 `enter(_:)`: stops/starts connection watch on entering/leaving awaiting; leaving `.ready` → `clock.cancel(); launcher?.watchUse(nil)`; entering `.ready` → `launcher?.watchUse { useChanged($0) }`.
- Public surface: `UpdatableCopy`, `CycleOutcome`, `HeldUpdate`, `UpdateEngineEvent`, `Updater.init`, `start(watching:opening:)`, `onHandOver`. No observable state, no card.

### LauncherCore/Ports.swift (update-relevant)
- L3-22 `public enum TrackpadEvent { gesture, swipe, windowSwipe, swap, trackpadsChanged, contactChanged }` — **L10-11 `contactChanged` added by rev 1**.
- L28-57 `@MainActor public protocol TrackpadHardware` — **L47-50 added by rev 1**:
  `/// Contact of any kind on any running trackpad, read now: palms yes, hovers no. Reads no clock.` `var isTouched: Bool { get }`;
  `/// While true, each flip pushes .contactChanged...` `var sensesContact: Bool { get set }`.
- L173-182 `RunningCopies` (`others()`, `stop(_:then:)`, `endThisCopy()`); L185-193 `LoginItem`; L196-208 `Installer`.
- L210-215 `@MainActor public protocol IdleClock { func wait(_ duration: Duration, then passed: @escaping @MainActor () -> Void); func cancel() }` (rev 1)
- L217-223 `@MainActor public protocol Connection { var onChange: (@MainActor (Bool) -> Void)? {get set}; func watch(); func stop() }` (rev 1)
- L225-239 `@MainActor public protocol UpdateEngine { var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? {get set}; func start(); func check(); func discardHeldUpdate(); func armRestart() -> Bool }` (rev 1). Doc: "No Sparkle type, feed value or version crosses this port."
- Rev 1 deleted from Ports.swift the old `UpdateInstaller` and `ReleaseList` protocols (main's hand-written updater; see `git show main:LauncherKit/Sources/LauncherCore/Ports.swift`). Also deleted: `LauncherCore/Update.swift` (82 lines), `LauncherPlatform/ApplicationsUpdater.swift`, `GitHubReleases.swift`, `LauncherUI/UpdateCardView.swift` — all retrievable from `main`.
- No LaunchdJob-ish port in core: the restart is behind `UpdateEngine.armRestart()`.

### LauncherCore/Lifecycle.swift (294 lines)
- L5-12 `public enum Opening { case atLogin, byHand, afterUpdate }` (`.afterUpdate` = "The hand-over job started this process, `--after-update`").
- L15-31 `public enum Route { runSilently, runWithWindow, askToMove, end }`, `init(_ opening:, placement:, olderCopyRuns:)`:
  ```
  (.atLogin, _, true) → .end ; (.atLogin, _, false) → .runSilently
  (.afterUpdate, .installed, _) → .runSilently
  (.byHand, .elsewhere, _), (.afterUpdate, .elsewhere, _) → .askToMove
  (.byHand, .installed|.development, _), (.afterUpdate, .development, _) → .runWithWindow
  ```
- L34-43 `public struct Launch { opening, diskImageToEject }`.
- L132-143 `private enum Stage { idle; replacingOthers(opening: Opening, opensWindow: Bool, eject: DiskImage?); resident(Launcher); askingToMove(resident:); moving(resident:); moveFailed(reason:, resident:); ending }`
- L151 `@ObservationIgnored private let updater: Updater?`
- L172-183 `public init(placement:, copies:, installer:, startAtLogin:, makeResident:, updater: Updater? = nil)`; L182 `updater?.onHandOver = { [unowned self] in handedOver() }`.
- L186-198 `launched(_:)`; L201-209 `openedAgain(_:)` (resident + `.runWithWindow` → `launcher.openedByHand()`).
- L212-227 `shouldEnd(_ request: QuitRequest) -> Bool`: `.ending, .idle, .replacingOthers, .askingToMove, .moveFailed` → true; `.moving` → `request == .system`; `.resident`: `.system` → true; `.other` with window open → `launcher.closeWindow(); return false`; else true.
- L241-245 `quit()` (suspends start at login, `end()`); L248-251 `end()` sets `.ending` then `copies.endThisCopy()`.
- **L260-269 `othersExited()` — the only place the updater starts**: `makeResident()`, `launcher.start()`, `stage = .resident`, `if opensWindow { launcher.openedByHand() }`, eject, then `updater?.start(watching: launcher, opening: opening)` (L268).
- L272-275 `handedOver()`: `guard case .resident = stage else { return }; end()`.

### LauncherCore/Launcher.swift (456 lines; rev-1 diff vs main)
- L23 `public var isWindowOpen: Bool { window != .closed }`
- L56-62 `public enum Window { closed; open(request: Int) }`, `public private(set) var window: Window = .closed`
- L84-88 init: `(hardware:, preferences:, permissions:, system:, catalog:, scanner:, store:, startAtLogin:)` — rev 1 removed `updater: Updater? = nil` param and `private let updater` (main had `updater?.windowOpened()` in `openedByHand` and `updater?.windowClosed()` in `closeWindow`).
- L108-130 `start()`: `hardware.onEvent` switch; **L116 `case .contactChanged: reportUse()` (rev 1)**.
- L213-230 `openedByHand()`: first opening enrol/resume; `openings += 1`; **L223-226 `let wasClosed = window == .closed; window = .open(request: openings); if wasClosed { reportUse() }` (rev 1)**; `resolveRows(); scanner.scan()`.
- L232-236 `closeWindow()`: `guard window != .closed; window = .closed; reportUse()` (reportUse rev 1).
- **L238-252 (rev 1)**: `public var isInUse: Bool { window != .closed || hardware.isTouched }`; `@ObservationIgnored private var useWatcher`; `public func watchUse(_ onChange: (@MainActor (Bool) -> Void)?) { useWatcher = onChange; hardware.sensesContact = onChange != nil; reportUse() }`; `private func reportUse() { useWatcher?(isInUse) }`.
- **L294-295 (rev 1)** in `reconcile`: after `hardware.run(...)`: `// run replaces sessions... reportUse()`.

### LauncherCore/Copy.swift (54 lines)
`public enum Copy` static strings: `accessibilityHint`, `openSettingsButton = "Open Settings…"`, `quitButton = "Quit Trackpad Launcher"`, move dialog strings, `thumbCornerRow`, `thumbCornerTitle(_:)`, `closeSettings`, `screenRecordingHint`, `minimisedBadge`, `untitledWindow(of:position:)`, `inactiveNotice(for:)`. Rev 1 deleted the card strings (main L23-31): `updateAvailable(_ version: Version) -> "App version \(version) is available"`, `updateNowButton = "Update now"`, `updateDownloading(_:) "Downloading version \(version)…"`, `cancelButton = "Cancel"`, `updateInstalling(_:) "Installing version \(version)…"`, `updateFailed = "The update couldn't be installed."`, `tryAgainButton = "Try again"`. `Version` moved to `CardContract/Version.swift` (no longer in LauncherCore).

---

## 3. LauncherPlatform

### SparkleEngine.swift (247 lines)
- L7 `internal import Sparkle` (only file).
- L9 `@MainActor public final class SparkleEngine: UpdateEngine`
  - fields: `onEvent`, `signer: Signer`, `driver = SilentUserDriver()`, `delegate: UpdaterDelegate`, `updater: SPUUpdater?` (only after successful start), `bundle: URL`, `build: String?` (CFBundleVersion read at init).
  - L22-30 `public init(bundle: URL, signer: Signer)`: reads `CFBundleVersion` and `TLUpdateDownloads` via `Bundle(url: bundle)`; `delegate = UpdaterDelegate(prefix:, signer:)`; `delegate.emit = { [weak self] in self?.onEvent?($0) }`.
  - L33 `public nonisolated static func canReplace(_ bundle: URL) -> Bool { SparkleInternals.canReplace(bundle) }`
  - L35-48 `start()`: **request privacy config**: `HTTPCookieStorage.shared.cookieAcceptPolicy = .never`; `URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)`; `SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: delegate)`; `candidate.userAgentString = "TrackpadLauncher"`; `candidate.httpHeaders = ["Accept-Language": "en", "Accept-Encoding": "gzip"]`; `try candidate.start()` else `onEvent?(.cycleEnded(.failed))`.
  - L52-59 `check()`: `if updater.sessionInProgress { delegate.checkPending = true } else { updater.checkForUpdatesInBackground() }` (automatic path).
  - L61-64 `discardHeldUpdate()` (**the veto**): `SparkleInternals.veto(job: SparkleInternals.installerJob(of: signer.identifier), extracted: delegate.found); delegate.found = nil`.
  - L67-73 `armRestart()`: `LaunchdJob.submit(label: "\(signer.identifier).hand-over", arguments: LaunchdJob.handOverArguments(oldPID: getpid(), bundle: bundle, build: build, allowed: 5, open: "/usr/bin/open"))`.
  - L77-85 `nonisolated static func outcome(of error: (any Error)?) -> CycleOutcome` (**outcome mapping**): nil → `.nothingNew`; non-`SUSparkleErrorDomain` → `.failed`; `SUError.noUpdateError` → `.nothingNew`; `SUError.downloadError` → `.requestFailed`; else `.failed`.
- L90-149 `enum SparkleInternals`:
  - L91 `static let provenOn = "2.10.1"` (compared to Package.resolved by a test).
  - L96-103 `canReplace(_:)`: `access(path, W_OK)`, `access(parent, W_OK)`, `stat` uid == `getuid()`, gid in `userGroups()`.
  - L108-128 `extractedUpdate(identifier:build:caches:) -> URL?`: `caches/<identifier>/org.sparkle-project.Sparkle/Installation/<r>/<r>/`, newest folder holding a bundle with that CFBundleVersion, exactly one `.app`.
  - L131 `installerJob(of:) -> "\(identifier)-sparkle-updater"`.
  - L135-138 `veto(job:extracted:)`: `LaunchdJob.remove(label: job)`; `BundleInstall.discard(extracted)`.
  - L140-148 `userGroups()`.
- L154-160 `func isPinned(enclosure: URL?, under prefix: String?) -> Bool`: prefix match on absoluteString, path ends `.aar`, no `..`/`%2e`.
- L162-217 `@MainActor private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate`:
  - vars `emit`, `found: URL?`, `checkPending = false`.
  - L178-184 `updater(_:shouldProceedWithUpdate:updateCheck:) throws` — throws `NSError(domain: "TrackpadLauncher.update", code: 1)` unless `isPinned(enclosure: updateItem.fileURL, under: prefix)`.
  - L189-204 `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:) -> Bool` (**genuineness check**): `checkPending = false`; `found = SparkleInternals.extractedUpdate(identifier: signer.identifier, build: item.versionString, caches:)`; `ExpectedUpdate(version: item.displayVersionString, build: item.versionString, minimumMacOS: item.minimumSystemVersion ?? "")`; `genuine = found.map { CodeSignature.isGenuine($0, as: offer, signer: signer) } ?? false`; `emit?(.held(genuine ? .genuine : .notGenuine))`; `return true` (handler dropped).
  - L208-212 `updater(_:willScheduleUpdateCheckAfterDelay:)`: runs pending `checkForUpdatesInBackground()`.
  - L214-216 `updater(_:didFinishUpdateCycleFor:error:)` → `emit?(.cycleEnded(SparkleEngine.outcome(of: error)))`.
- L220-247 `@MainActor private final class SilentUserDriver: NSObject, SPUUserDriver` (**user driver**): `show(_ request:reply:)` replies `SUUpdatePermissionResponse(automaticUpdateChecks: true, automaticUpdateDownloading: true, sendSystemProfile: false)`; `showUpdateFound(...)` → `reply(.dismiss)`; `showReady(toInstallAndRelaunch:)` → `reply(.dismiss)`; `showUpdateNotFoundWithError`/`showUpdaterError`/`showUpdateInstalledAndRelaunched` → `acknowledgement()`; all others empty (`showUserInitiatedUpdateCheck(cancellation:)`, `showUpdateReleaseNotes`, `showUpdateReleaseNotesFailedToDownloadWithError`, `showDownloadInitiated(cancellation:)`, `showDownloadDidReceiveExpectedContentLength`, `showDownloadDidReceiveData(ofLength:)`, `showDownloadDidStartExtractingUpdate`, `showExtractionReceivedProgress`, `showInstallingUpdate(withApplicationTerminated:retryTerminatingApplication:)`, `dismissUpdateInstallation`).

### CodeSignature.swift (114 lines)
- L8-9 `developerID` requirement string: `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists`.
- L14 `public static func buildOfThisProcess(arguments: [String]) -> Build` (`--as-release-build`).
- L26 `static func build(of url: URL) -> Build`.
- L36 `public static func developerIDSigner() -> Signer?` (this process); L47 `static func developerIDSigner(of bundle: URL) -> Signer?`.
- **L60 `static func isGenuine(_ bundle: URL, as expected: ExpectedUpdate, signer: Signer) -> Bool`**: rejects `"`/`\` in team/identifier; requirement `"\(developerID) and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(identifier)\" and notarized"`; flags `kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | (1 << 29 /* kSecCSNoNetworkAccess */)`; then sealed Info.plist (`kSecCodeInfoPList`) must have `CFBundleShortVersionString == expected.version && CFBundleVersion == expected.build && LSMinimumSystemVersion == expected.minimumMacOS`.
- L108-111 `public struct Signer { team, identifier }`; L114 `struct ExpectedUpdate: Sendable { let version, build, minimumMacOS: String }` (internal).

### LaunchdJob.swift (71 lines, rev 1)
- `enum LaunchdJob` (internal); only file using `SMJob`.
- L9 `@discardableResult static func remove(label: String) -> Bool` (looks up with `SMJobCopyDictionary` first, then `SMJobRemove(... wait: true)`).
- L23 `@discardableResult static func submit(label: String, arguments: [String]) -> Bool` — removes stale, submits `{Label, ProgramArguments, RunAtLoad: true, LaunchOnlyOnce: true, EnableTransactions: false, ProcessType: "Interactive"}` to `kSMDomainUserLaunchd`.
- L44-46 `static func handOverArguments(oldPID: Int32, bundle: URL, build: String, allowed: Int, open: String) -> [String]` → `["/bin/sh", "-c", handOverScript, "handover", pid, bundle.path, build, allowed, open]`.
- L51-64 `static let handOverScript`: waits `kill -0 $old` every 0.05 s; then up to `allowed` s wall time polls `plutil -extract CFBundleVersion raw` until it differs from `$build`; **L63 `exec "$open" -g -a "$bundle" --args --after-update`**.
- L66-70 `authorization()` via `AuthorizationCreate`.

### ThisCopy.swift (67 lines)
- L10-14 `public static func launch(event: NSAppleEventDescriptor?, arguments: [String]) -> Launch`: `--eject-disk-image <volume>`; **`let opening = arguments.contains("--after-update") ? Opening.afterUpdate : opening(of: event)`** (L12, rev 1).
- L17-20 `public static func opening(of event:) -> Opening` (`keyAELaunchedAsLogInItem` → `.atLogin`, else `.byHand`).
- L24-37 `location()` / `location(of:originalIfTranslocated:diskImage:)`; L42-63 private `Translocation` (dlsym).
- Rev 1 removed `ThisCopy.version()` and `ThisCopy.macOS()` (main).

### SystemConnection.swift (31 lines, rev 1)
`@MainActor public final class SystemConnection: Connection`; `NWPathMonitor` per `watch()` (fresh each time), `pathUpdateHandler` → `MainActor.assumeIsolated` with identity guard `self.monitor === monitor`, `start(queue: .main)`; `stop()` cancels.

### SystemIdleClock.swift (39 lines, rev 1)
`@MainActor public final class SystemIdleClock: IdleClock`; `DispatchSource.makeTimerSource(queue: .main)`, `schedule(deadline: .now() + seconds, leeway: .seconds(1))`, generation counter guard; `cancel()` bumps generation and cancels.

### Contact sensing on the frame path (`git diff 38af524 HEAD`; 38af524 exists and is the merge-base)
**FrameStream.swift** (`final class DeviceSession: Sendable`), hunks:
1. L39-42 added fields: `/// Writer: this device's frame callback. Reader: main, through isTouched.` `private let occupied = Mutex(false)`; `private let sensesContact: @Sendable () -> Bool`; `var isOccupied: Bool { occupied.withLock { $0 } }`.
2. init signature (L47-50): added parameter `sensesContact: @escaping @Sendable () -> Bool,` between `clock:` and `deliver:`; L57 `self.sensesContact = sensesContact`.
3. `receive(_ frame:)` head (L62-69) added:
   ```swift
   // Before the recognizer's palm filter, so palms count; reads no clock.
   let touched = !frame.touches.isEmpty
   let contactFlipped = occupied.withLock { was in
       defer { was = touched }
       return was != touched
   }
   if contactFlipped, sensesContact() { deliver(.contactChanged, nil) }
   ```
4. File end (L135-140) added: `func anyOccupied(_ sessions: [DeviceSession]) -> Bool { sessions.contains { $0.isOccupied } }` and `func isAnyTrackpadTouched() -> Bool { anyOccupied(Array(sessions.withLock { $0.values })) }`.

**MultitouchTrackpads.swift**, hunks:
1. L4 `import Synchronization`; L6-9 `private final class ContactSensing: Sendable { let isOn = Mutex(false) }` ("The contact-sensing flag, which outlives run").
2. L30-37 in the class: `private let contact = ContactSensing()`; `public var isTouched: Bool { isAnyTrackpadTouched() }`; `public var sensesContact: Bool { get { contact.isOn.withLock { $0 } } set { contact.isOn.withLock { $0 = newValue } } }`.
3. In `run(...)` per-device loop: L107 `let sensing = contact`; L112 `tap: clickTap, clock: { .now }, sensesContact: { sensing.isOn.withLock { $0 } },`.
(Check after removal whether `import Synchronization` is still needed in MultitouchTrackpads.swift; FrameStream.swift already used Mutex before rev 1.)

Other contact code to delete: `Ports.swift` L10-11, L47-50; `Launcher.swift` L116, L223-226 (`wasClosed`/reportUse), L235 reportUse, L238-252, L294-295; test-side `InMemoryTrackpads` L59-91 (`occupiedPads`, `holdsContactEdges`, `heldContactEdges`, `isTouched`, `onSensesContactSet`, `sensesContact`, `press(on:)`, `lift()`, `holdContactEdges()`, `releaseContactEdges()`, `setOccupied`); `OneProcess.touch(_:)`/`lift()`/`enum Contact` (LifecycleWorld L227-232); `sensesContact: { false },` args in `DeviceSessionAnswerTests.swift:39` and `DeviceSessionTravelTests.swift:22`; all of `DeviceSessionContactTests.swift`.

---

## 4. LauncherUI

### SettingsView.swift (321 lines)
- L13 `struct SettingsView: View { let launcher: Launcher; let actions: LauncherActions }` (rev 1 removed `let updater: Updater?`).
- L18 `static let labelFont = Font.system(size: 13, weight: .medium)`; L20 `inset = 16`; L22 `partSpacing = 20`; L26 `formMargins = (20, 20, 20)`.
- L28-84 body: `VStack(spacing: 20)` → `if launcher.showsAccessibilityHint { AccessibilityHintCard(actions:).padding(.horizontal, 16) }` (L30-33) → grouped `Form` (L34-67) → `SettingsNotice` (L68-70) → buttons HStack (L71-79) → `.padding(.vertical, 16).frame(width: 326).fixedSize(horizontal: true, vertical: false)`.
- **Close button (L75-77)**: `Button("Close") { launcher.closeWindow() }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 6))`. Quit (L73-74): `Button(Copy.quitButton, action: actions.quit).buttonStyle(TintedButtonStyle(tint: .red))` (rev 1 removed `.disabled(updater?.isInstalling == true)`).
- L88-92 `enum GroupStyle { cornerRadius = 12; sideInset = 10; fill = Color(nsColor: .quaternarySystemFill) }`.
- L95-103 `FormGroup` (padding sides 10, background fill rounded 12); L106-114 `FormRow` (min height 46, vertical padding 2).
- L173-187 `extension View { formRowContent() (height 26); hintMessage(maxWidth:) (11 pt, wraps) }`.
- L206-231 `enum BundleImage { static func nsImage(_ name: String, type: String = "svg") -> NSImage?` (cached, `Bundle.main.url(forResource:withExtension:)`); `@ViewBuilder static func view(_ name:, type: = "svg", size: CGSize? = nil, template: Bool = false)` }.
- L277-321 `struct TintedButtonStyle: ButtonStyle { enum Fill { wash, solid }; let tint: Color; var fill: Fill = .wash }`: 13 pt medium label, `.padding(.horizontal, 16).frame(height: 24)`, `RoundedRectangle(cornerRadius: 6)` background; wash = tint label on `shade.mix(with: .black, by: 0.1).opacity(pressed ? 0.3 : 0.2)`; solid = white label on tint (pressed mixes 0.15 black); disabled uses `Color.secondary`.

### AccessibilityHintCard.swift (34 lines) — style reference for a new card
```swift
let shape = RoundedRectangle(cornerRadius: GroupStyle.cornerRadius)   // 12
VStack(alignment: .leading, spacing: 8) {
    Text(Copy.accessibilityHint).hintMessage(maxWidth: Self.messageWidth)   // 216
    Button(Copy.openSettingsButton) { actions.openSettings(.accessibility) }
        .buttonStyle(TintedButtonStyle(tint: .accentColor, fill: .solid))
}
.padding(.vertical, 8).padding(.horizontal, GroupStyle.sideInset)   // 10
.frame(maxWidth: .infinity, alignment: .leading)
.background(alignment: .topTrailing) { TurningGear().frame(width: GearView.side, height: GearView.side).offset(x: 19, y: -23).allowsHitTesting(false).accessibilityHidden(true) }
.background(GroupStyle.fill, in: shape)       // quaternarySystemFill
.clipShape(shape)
.overlay(shape.strokeBorder(Self.border, lineWidth: 1))   // border = #DEDEDE
```

### GearView.swift (111 lines)
- L6 `final class GearView: NSView`; `static let side: CGFloat = 91`, `period: CFTimeInterval = 30`, `animationKey = "turn"`.
- `let gearLayer = CALayer()` added as sublayer of the view's own layer (`wantsLayer = true`); bounds 91×91, centred anchor; `gearLayer.actions` nulls for contents/bounds/position/transform/contentsScale.
- **Reduce-motion injection**: `init(image: NSImage?, reduceMotion: @escaping () -> Bool)`; `TurningGear.makeNSView` passes `{ NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }`; tests pass a `ReduceMotionReader`.
- `isFlipped = true`, `intrinsicContentSize` 91, `hitTest` → nil.
- `viewDidMoveToWindow`: `updateContents()`; in window → `startObserving()` (NSWorkspace notification center, `accessibilityDisplayOptionsDidChangeNotification`) + `applyReduceMotion()`; out → `stopObserving()` + `removeAnimation(forKey:)`.
- **Backing scale**: `viewDidChangeBackingProperties` → `updateContents()`: `scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2`; `gearLayer.contentsScale = scale`; `gearLayer.contents = image?.layerContents(forContentsScale: scale)`.
- **Animation add/remove** (`applyReduceMotion`, L83-99): reduce → `removeAnimation`; else if none: `CABasicAnimation(keyPath: "transform.rotation.z")`, from 0 to `2π` (branch; main flipped sign to counter-clockwise), linear, `repeatCount = .infinity`, `duration = 30`, `isRemovedOnCompletion = false`, `gearLayer.add(turn, forKey: "turn")`.
- L103-111 `struct TurningGear: NSViewRepresentable` → `GearView(image: BundleImage.nsImage("gear"), reduceMotion: ...)`.

### SettingsShell.swift (253 lines)
- L20 `public final class SettingsShell: NSObject, NSWindowDelegate`; L49 **`public init(launcher: Launcher, quit: @escaping () -> Void)`** (rev 1 removed `updater: Updater?`).
- L42-47 **`private struct Fit: Equatable { inactiveNotice: String?; showsAccessibilityHint: Bool; isSwipeOn: Bool; screenRecordingHint: ScreenRecordingHint? }`** (main had `let card: UpdateCard.Layout?`).
- L61 `window.install(content: SettingsView(launcher: launcher, actions: actions))`.
- **Refit** (L74-86): `Task { for await fit in Observations({ Fit(...) }) { guard fit != last else { continue }; last = fit; self?.refit() } }`; L180-183 `refit()` → `guard isShown; fit()`; L174-178 `fit()`: keeps top edge, `window.setContentSize(window.contentFittingSize)` (`SettingsWindow.contentFittingSize` = `hosting.fittingSize`).
- L93-98 observes `launcher.window` → `render(_:)` (L136-161: activation policy, fit+centre on first show, deminiaturize, unhide, `makeKeyAndOrderFront`, `AppActivation.activateOverOtherApps()`).
- L228-252 `makeActions(...)` builds `LauncherActions(cachedIcon:, icon:, chooseOtherApp:, pickAnimation:, openSettings:, quit:)` (LauncherActions.swift L20-34; `SettingsPane { accessibility, screenRecording }`).
- SettingsWindow.swift: `final class SettingsWindow: NSWindow`, `pinnedAppearance = .aqua`, `install(content:)` into `NSHostingView<AnyView>`, `contentFittingSize`, `cancelOperation` → `onCancel`.

### Composition root: TrackpadLauncher/TrackpadLauncherApp.swift (110 lines)
- L28-41 `applicationWillFinishLaunching`: `ThisCopy.location()`, `Placement(build: CodeSignature.buildOfThisProcess(...), location:)`, `StartAtLogin`, `Lifecycle(placement:, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location:), startAtLogin:, makeResident: { makeResident(startAtLogin) }, updater: makeUpdater(placement:location:))`.
- L44-54 `makeUpdater(placement:location:) -> Updater?`: `CodeSignature.developerIDSigner()`; `UpdatableCopy(placement:, developerIDSigned: signer != nil, canReplaceItself: SparkleEngine.canReplace(location.running))`; `Updater(copy, engine: SparkleEngine(bundle: location.running, signer: signer), connection: SystemConnection(), clock: SystemIdleClock())`.
- L57-61 `applicationDidFinishLaunching` → `ThisCopy.launch(event:arguments: CommandLine.arguments)` → `lifecycle.launched`.
- L76-90 `makeResident(_:)`: builds `Launcher(hardware: MultitouchTrackpads(), ...)` and **`shell = SettingsShell(launcher: launcher, quit: { lifecycle.quit() })`** (L83).
- **Updater does not reach the shell or any view today.** Only `Lifecycle` holds it. On main (before rev 1) it was threaded: `makeResident(startAtLogin, updater)`, `Launcher(..., updater:)`, `SettingsShell(launcher:, updater:, quit:)`, `SettingsView(launcher:, updater:, actions:)` with `if let card = updater?.card { UpdateCardView(card:, updateNow: { updater?.updateNow() }, cancel: { updater?.cancel() }).font(Self.labelFont).padding(.horizontal, 16) }` placed **first** in the VStack. Precedent: `git show main:LauncherKit/Sources/LauncherUI/UpdateCardView.swift` (FormGroup + FormRow, 11 pt text, `.bordered` button radius 6, `ProgressView` while downloading).

### Assets
- `assets/gear.svg`, `assets/guide.svg`, `assets/*.png` (repo root) → app bundle resources via project.yml L22-24; loaded with `BundleImage.nsImage(name, type:)` from `Bundle.main`. **Package.swift declares no resources**, so in `swift test` `Bundle.main` has none (GearBench passes `image: nil`).
- Design asset for the new card: `plans/039-auto-updates/assets/update-card-symbol.svg` (added in 0bcf172; not yet in `assets/`).
- `GearAssetTests` reads `CornerIllustrationFileTests.assets` = `ThumbCornerRuleTests.swift:38` `nonisolated static let assets = URL(fileURLWithPath: #filePath)...` (the repo `assets/` folder).

---

## 5. Tests

### Files touching updates / contact / idle clock / Sparkle / LaunchdJob / ThisCopy / policy / gear
LauncherCoreTests:
- `UpdaterStartTests.swift` (137) — gate table `rows` (placement × signed × canWrite), `engineEntries = ["engine start","check","discard","arm restart"]`; tests: `onlyAnInstalledSignedWritableCopyBuildsAnUpdaterThatStartsItsEngine`, `aGatedCopyStartsAndChecksInTheTurnItBecomesResident` (expects log `["engine start","check"]`), `openingAndClosingTheWindowAddsNoCheck`, `aLoginStartThatEndsForAnOlderCopyNeverStartsTheEngine`, `aCopyStillReplacingOthersStartsTheEngineOnlyOnceTheyHaveExited`, `aCopyOutsideApplicationsMakesNoEngineCallUntilTheMovedCopyOpens`, `aCopyThatCannotWriteMakesNoRequestAndAsksForNothingThenChecksOnceItCan`.
- `UpdateWaitsTests.swift` (292) — idle minute + contact (`process.touch(.finger)`, `lift()`, `hardware.sensesContact`, `onSensesContactSet`, `holdContactEdges`, `idleClock.pass()/advance`). Whole file is about the idle minute.
- `UpdateRetryTests.swift` (150) — connection retry; L115/L126 assert `hardware.sensesContact`.
- `HandOverTests.swift` (247) — `armings(world)` counts `"arm restart"`; `heldLogin` pushes `.held(.genuine)`; `RouteRow` table (L125-157) for `Route` incl. `.afterUpdate`; `finishHandOver`; phases `cycleRunning, heldInUse, minuteRunning`.
- `SourcePolicyTests.swift` (472) — see below.
- `LifecycleWorld.swift`, `InMemoryAdapters.swift` — harness (below).
LauncherPlatformTests:
- `SparkleEngineTests.swift` (104): `outcome(of:)` table (L8-25), `noErrorIsNothingNew`, `isPinned` tests with `github = "https://github.com/domasgru/trackpad-launcher/releases/download/"`, `local = "http://127.0.0.1:8765/v2/"`, `aWritableBundleCanReplaceItselfAndTheListingNeverChanges`, `aSystemBundleCannotReplaceItself`, **`sparkleInternalsWereProvenOnThePinnedVersion` (L92-103)**: reads `LauncherKit/Package.resolved` → `pins[identity == "sparkle"].state.version` and `#expect(SparkleInternals.provenOn == ...)`.
- `SparkleVetoTests.swift` (120): `extractedUpdate` layout tests, `installerJob` name, `veto` with a real submitted sleeper job (`submitSleeper`, `isLoaded`).
- `LaunchdJobTests.swift` (164, `.serialized`): `Rig` (temp bundle at build 1, `open-stub` script recording args, `/bin/sleep 300` as old process); tests on hand-over script timing; `submittingAStaleLabelReplacesTheJob`; `removingALiveJobEndsItAndRemovingAnAbsentOneAnswersFalse`.
- `ThisCopyTests.swift` (68): `theAfterUpdateFlagIsTheHandOversStartWhateverTheEventSays` (L48), `theAfterUpdateFlagSitsBesideTheEjectFlag` (L54), plus login-marker/eject/reopen tests. `ThisCopyLocationTests.swift` (location only).
- `SystemConnectionTests.swift` (56), `SystemIdleClockTests.swift` (69).
- `CodeSignatureTests.swift` (120): `isGenuine` tests gated on `UpdateFixtures.arePresent` (L77, L106), `anUnsignedBundleIsNeverGenuine`, `aSignerWhoseNamesCouldBreakOutOfTheRequirementIsNeverMatched`, `offer(_:build:needs:)` helper → `ExpectedUpdate`.
- `DeviceSessionContactTests.swift` (163) — all contact sensing; `DeviceSessionAnswerTests.swift:39`, `DeviceSessionTravelTests.swift:22` pass `sensesContact: { false }`.
- `UpdateFixtures.swift` + `UpdateFixtures/` (below).
LauncherUITests: `GearViewTests.swift` (110; `GearViewTests` suite L5-77 + `GearAssetTests` L79-110 `theGearFileIs91PointsSquareAndCentred`), `GearBench.swift` (46).
CardContractTests: `CardContractToolTests.swift`, `BundleInstallTests.swift`, `UpdateFixtures.swift` (reads the platform fixtures folder), `CraftedArchive.swift`, `BundleFixture.swift`, `VersionTests.swift`.
ReleaseTests: `ReleaseTests.swift` (299), `ReleaseHarness.swift` (448; `realSparkleBin` L16, stubs `sign_update`/`generate_keys` L289-296, fake `Sparkle.framework/Versions/B/Autoupdate` L319-334, team check L416).

### LifecycleWorld (LauncherCoreTests/LifecycleWorld.swift, 241 lines)
- `@MainActor final class LifecycleWorld`: `mac: World`, `loginItem`, `permissions`, `log = EffectLog()`, `installedAt: Int?`, `snapshots`, `snapshot()`, `init(apps:accessGranted:record:corner:hidesBackgroundApps:loginItemOn:)`, `init(restoring:apps:)`.
- `@discardableResult func launch(_ opening: Opening, others: [RunningCopy] = [], alreadyExited: Set<RunningCopy> = [], placement: Placement = .installed, diskImageToEject: DiskImage? = nil, running: RunningBuild = .development, attached: [Trackpad] = [.macBook14]) -> OneProcess` (L69-84; wires `process.engine.onEffect` to snapshots).
- `@discardableResult func finishHandOver(installed: Bool = true) -> OneProcess` (L89-93) → `launch(.afterUpdate, placement: .installed, running: .release)`.
- `func login(others: [RunningCopy] = [], running: RunningBuild = .development) -> OneProcess?` (L96-98) → `.atLogin` only while `loginItem.isOn`.
- `struct RunningBuild { developerIDSigned, canWrite }` with `.development`, `.release`, `.release(canWrite:)` (L102-109).
- `@MainActor final class OneProcess` (L111-241): `lifecycle`, `copies`, `installer`, `hardware: InMemoryTrackpads`, `preferences`, `system`, `residentsBuilt`; `struct Published { window }`, `history`, **`var windows: [Launcher.Window]`**; `let updater: Updater?` (built from `UpdatableCopy(...)` L149-151), `let engine = InMemoryUpdateEngine()`, `let idleClock = InMemoryIdleClock()`, `let connection = InMemoryConnection()`; `launcher`, `window`; intents (each `record()`s): `launch(_:diskImageToEject:)`, **`openAgain(_:)`**, `letExit(_:)`, `letStoppedCopiesExit()`, `deliverExitAgain()`, **`closeWindow()`**, `shouldEnd(_:) -> Bool`, `moveDialog`, `answer(_:)`, `releaseInstall(_:)`, `quit()`; contact: `enum Contact { case finger }`, `touch(_:)` → `hardware.press()`, `lift()`; `wake()`; `tap(_:thumbAtMM:)`.

### InMemory adapters (LauncherCoreTests/InMemoryAdapters.swift)
- `InMemoryTrackpads` L6 (contact part L59-91, `wake()` L139 pushes `.trackpadsChanged`, `inject(_:)` L293).
- `InMemoryIdleClock` L297-328: `pending`, `waits`, `wait`, `cancel`, `pass()`, `advance(by:)`.
- `EffectLog` L637-640 `var entries: [String]`. Entries written: `"register"`/`"unregister"` (login item L616/L628), `"engine start"` L652, `"check"` L657, `"discard"` L662, **`"arm restart"` L670**, `"install"` L720, `"removeOriginal"` L737, `"openInstalledCopy"` L743, `"eject"` L749, `"stop"` L772, `"end"` L801.
- **`InMemoryUpdateEngine`** L642-676: `log`, `onEvent`, `starts`, `checks`, `discards`, **`var armWorks = true`**, `start()`, `check()`, `discardHeldUpdate()`, `var onEffect`, `armRestart()` (onEffect, log, onEffect, `return armWorks`), **`func push(_ event: UpdateEngineEvent) { onEvent?(event) }`**.
- **`InMemoryConnection`** L680-702: `onChange`, `var reading = false`, **`private(set) var isWatching`**, `watches`, `watch()` (pushes `reading`), `stop()`, **`func set(_ connected: Bool)`** (pushes while watching).
- `InMemoryInstaller` L705+, `InMemoryRunningCopies` (after L755).

### SourcePolicyTests.swift structure
- L8-12 `struct Entry { token, rule }`; L14-15 `suddenTerminationRule`.
- **L17-91 `static let banned: [Entry]`**: logs (L18-26), network (L27-48: `URLSession`, `URLSession.shared`, …, `curl`, `NSAppleScript`, `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`, `NWConnection`, `CFSocket`, `CFStream`), own files (L49-51), **timer/polling L52-55: `asyncAfter`, `Task.sleep`, `displayLink`, `DisplayLink`** (no `Timer` here now), input monitoring, keyboard, synthesis, `nonisolated(unsafe)`, `perform: {`, window switcher, previews, `NSStatusBar`/`NSStatusItem`, `SMAppService.agent/.daemon/.loginItem`, `SMLoginItemSetEnabled` (rule mentions "the hand-over job opens it once after an update"), `/bin/rm`.
- **L93-98 `static let neverDeclared`**: `NSSupportsSuddenTermination`, `SUEnableSystemProfiling`, `SUEnableInstallerLauncherService`, `SUEnableDownloaderService`.
- L101-106 `struct Declared { key, valuePrefix, valueSuffix }`; **L108-115 `static let alwaysDeclared`**: `SUFeedURL` (prefix `https://`), `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUVerifyUpdateBeforeExtraction`, `TLUpdateDownloads` (prefix `https://`, suffix `/`).
- L118-124 `struct Confined { token, onlyIn: Set<String>, rule }`; **L126-239 `static let confined`**. Update rows:
  - L127-128 `http` only in `SparkleEngine.swift`
  - **L129-137 `Timer`, `makeTimerSource`, `DispatchSourceTimer` only in `SystemIdleClock.swift`** (rule "the one timer is an automatic update's idle minute")
  - L138-143 `import Network`, `NWPathMonitor` only in `SystemConnection.swift`
  - **L144 `Confined(token: "import Sparkle", onlyIn: ["SparkleEngine.swift"], rule: "the update engine is one file")`**
  - L145 `HTTPCookieStorage`, L146 `URLCache`, L147 `org.sparkle-project`, L148 `sparkle-updater` — all only in `SparkleEngine.swift`
  - L149 `Data(contentsOf:` only in `Apps.swift`, `CardContract.swift`
  - L181-183 `SecCode`/`SecStaticCode`/`SecRequirement` in `CodeSignature.swift`, `CardContract.swift`
  - L190-192 `/bin/sh` in `LaunchdJob.swift`, `PrivilegedInstall.swift`; L195 `SMJob` in `LaunchdJob.swift`
  - L212-216 `copyItem(`/`moveItem(`/`replaceItemAt(`/`renamex_np(`/`removeItem(` (BundleInstall.swift, some + CardContract.swift)
  - **L217-222 `AppleArchive`, `ArchiveStream`, `ArchiveByteStream` only in `CardContract.swift`** (rule "the card's rules unpack an archive, frozen") — a SparkleEngine extraction copy would need these rows widened.
  - L223-227 `removexattr`, `itemReplacementDirectory` in BundleInstall.swift + CardContract.swift.
- **Bans-still-listed checks**: L241-251 `theNetworkBansAreAllStillListed` (required set of banned tokens, incl. `asyncAfter`, `Task.sleep`; `Timer` and `import Network` were removed from it by rev 1 — main had them in `banned` at L45/L52/L55 and in `required`); L253-260 `theTimerAndPathMonitorBansAreStillScannedInTheConfinedList` (asserts the three timer tokens are confined exactly to `["SystemIdleClock.swift"]` and the two monitor tokens to `["SystemConnection.swift"]`). Deleting SystemIdleClock means moving `Timer`/`makeTimerSource`/`DispatchSourceTimer` back to `banned` + `required` and dropping/rewriting this test.
- Scan helpers: `scannedRoots` L267-272 = `LauncherKit/Sources` + `TrackpadLauncher/` (tests and Scripts are not scanned); `scanVisitsEveryLibraryTarget` L379-385 requires files under LauncherCore, LauncherPlatform, LauncherUI, CardContract; `coreImportsOnlyFoundationAndObservation` L389-393; `cardContractStaysFrozenApartFromTheApp` L395-406 (CardContract imports only `AppleArchive, CardContract, Foundation, Security, System`; project.yml must not mention CardContract).

### UpdateFixtures (LauncherPlatformTests/UpdateFixtures.swift + folder)
- `enum UpdateFixtures`: `folder`, `developerIDApp` (`DeveloperID/TrackpadLauncher.app`, notarised + stapled), `appleDevelopmentApp` (`AppleDevelopment/TrackpadLauncher.app`), `archive` (`TrackpadLauncher-fixture.aar`), `record` (`fixture.json`), `arePresent`, `struct Record: Decodable { version, minimumMacOS, team, identifier, manifest: [String: String] }`, `loadRecord()`.
- `fixture.json`: `identifier "com.domasgru.TrackpadLauncherUpdateFixture"`, `version "1.0.0"`, `minimumMacOS "26.0"`, `team "CQK27876UL"`, `manifest` (relative path → sha256 or `"dir"`/`"link:…"`). **No build field**; the app's `CFBundleVersion` is `"1"` (Info.plist), so `ExpectedUpdate(build: "1")`.
- The fixture app is a stub (`int main(void){return 0;}` universal binary + `Resources/fixture.txt`), no Sparkle framework inside.
- `Scripts/make-update-fixtures.sh`: needs `NOTARY_PROFILE`; `make_app` writes Info.plist; Developer ID codesign `--options runtime --timestamp`, notarise, staple; Apple Development copy; `aa archive -d ... -subdir TrackpadLauncher.app -exclude-field uid,gid,xat,acl,flg`; python writes fixture.json.
- `CardContractTests/UpdateFixtures.swift` reuses the same folder (`developerIDApp`, `archive`, `record`).

---

## 6. Scripts/update-e2e.sh (1407 lines) and Scripts/update-e2e/
- Header L1-23: two real patched builds (v1 1.0.0 build 1000, v2 2.0.0 build 2000), local server, `build/update-e2e/report.md`; modes: full (Developer ID + notary + sudo), selected rows `T58 T59`, `--check` (ad-hoc, every row SKIPPED). Bundle id `com.domasgru.TrackpadLauncherApp.e2e`, installs as `Trackpad Launcher E2E.app`.
- Config L27-59: `PORT=${E2E_PORT:-18765}`, `FEED_URL=http://127.0.0.1:$PORT/domasgru/trackpad-launcher/main/appcast.xml`, `DOWNLOADS_BASE=http://127.0.0.1:$PORT/domasgru/trackpad-launcher/releases/download`, `SPARKLE_BIN` (L42).
- `rows_table()` L65-85: `id|function|title`, rows T56-T72 (T57 hand-started copy updates with window closed; T58 request privacy; T59 highest compatible; T60 cannot-update copy makes no request; T61 `--after-update` leaves 24 h timer; T62 Quit installs; **T63 idle minute hand-over; T64 finger/palm resting keeps update waiting** (contact-dependent); T65 reset download; T66 feed retry; T67 not-genuine / wrong host; T68 failed install; T69 kill -9; T70 password needed; T71 removed installer job; T72 empty key).
- Helpers: world reset/cleanup (L139-241), `analyze()` → `analyze.py`, `wait_for`, `install_copy`, `set_last_check` (writes `SULastCheckTime`), `launch_hidden` (`open -g -j`), `start_sampler`, `stage_assets`, `use_feed`/`edit_feed`, `ask_person`/`tell_person`, gesture checks, `check`/`expect_count`, `row_done/row_fail/row_skip`, `run_row` (L475).
- Builds: `ensure_key` (keygen.swift → `ed.key`/`ed.pub`), `ensure_sampler`, `ensure_sparkle_tools` (L509-514), **`prepare_tree [variant]` (L516-551)**: rsync tree to `build/update-e2e/tree`, awk-patch project.yml (bundle id `.e2e`, `SUFeedURL`, `SUPublicEDKey` (empty for variant `emptykey`), `TLUpdateDownloads`, inserts `NSAppTransportSecurity: NSAllowsLocalNetworking: true`), `xcodegen generate`. **`ensure_build <name> <version> <number> <kind> [identifier] [variant]` (L553-631)**: kinds `release|unnotarised|appledev`; `xcodebuild archive -packageAuthorizationProvider netrc ... MARKETING_VERSION= CURRENT_PROJECT_VERSION=`, export, notarise/staple, cache under `$CACHE/<name>`, `make_archive` (L634-643, `aa archive` with release flags). Builds cached by commit (`commit_key` L118).
- Feed: `render_feed` (L651+) runs `release.sh --feed-only` in a throwaway clone with stubs (as ReleaseHarness does).
- `start_server` (L720-730) → `server.py <serve-dir> <request-log> <control-file> <port>` (feed at raw path with ETag/max-age 300/`text/plain`, release path 302 → `/assets/...` with a cookie, control words `feed=ok|503|503once|404|reset|hold`, `payload=...`; logs every request with headers). `frame_check` (L735-770) proves feed/server/redirect/control/sampler with curl.
- `sampler.swift`: 100 ms JSON lines (`t`, `front`, `app {pids, policy}`, `windows`, `installed {version, exec}`), `SAMPLER_BUNDLE_ID` env.
- `analyze.py` commands: `requests`, `count --kind feed|release|payload|download|any`, `privacy`, `same-headers`, `samples-ok`, `quiet`, `pids`, `first-version`, `window-open`, `first-at`.
- `feed.py`: `set-minimum`, `derive`, `replace`, `tamper-signature`. `keygen.swift`: throwaway Ed25519 key, no keychain.
- `main()` L1377-1404: key, tools, sampler, `reset_world`, build v1/v2, server, frame_check, rows, `write_report`.

---

## 7. CardContract extraction (AppleArchive)
File `LauncherKit/Sources/CardContract/CardContract.swift` (234 lines; imports `AppleArchive`, `Foundation`, `Security`, `System`). Frozen copy of the old card's rules; header comment: "do not merge it back".
- L11 `public func refusal(ofArchive archive: URL, team: String, identifier: String) -> String?` (name check → `Data(contentsOf:)` → `BundleInstall.unpack(data, near: temporaryDirectory)` → `isGenuine(...)`).
- L51 `func isGenuine(_ bundle: URL, version: Version, minimumMacOS: Version, signer: Signer) -> Bool`.
- L88 `enum BundleInstall` (CardContract's own copy):
  - L95 `private static func newFolder(near destination: URL) throws -> URL` (`.itemReplacementDirectory`).
  - **L103-121 `private static func extract(_ archive: Data, into folder: URL) throws`**:
    ```swift
    guard let raw = ArchiveByteStream.customStream(instance: MemoryStream(archive)),
        let decompressed = ArchiveByteStream.decompressionStream(readingFrom: raw),
        let decoded = ArchiveStream.decodeStream(readingFrom: decompressed),
        let extractor = ArchiveStream.extractStream(
            extractingTo: FilePath(folder.path),
            selectUsing: { message, path, data in
                guard message == .extractBegin else { return .ok }
                return admitted(path: path.string, data: data) ? .ok : .cancel
            }, flags: [.ignoreOperationNotPermitted])
    else { throw CocoaError(.fileReadCorruptFile) }
    defer { try? extractor.close(); try? decoded.close(); try? decompressed.close(); try? raw.close() }
    _ = try ArchiveStream.process(readingFrom: decoded, writingTo: extractor)
    ```
  - L123-137 `admitted(path:data:)` maps `ArchiveHeader.entryType` and `LNK` field → `admits`.
  - L140-153 `static func unpack(_ archive: Data, near destination: URL) throws -> URL` (extract, require `TrackpadLauncher.app`, `clearQuarantine`).
  - L158-179 `static func admits(path:kind:linkTarget:) -> Bool` (under `TrackpadLauncher.app/`, no `..`/`.`, symlinks stay inside).
  - L182-189 `discard(_:)`; L192-201 `clearQuarantine(under:)` (`removexattr(..., XATTR_NOFOLLOW)`).
- L204 `enum ArchiveEntryKind { directory, file, symbolicLink, other }`; L207-234 `private final class MemoryStream: ArchiveByteStreamProtocol` (read-only over `Data`).
- LauncherPlatform's own `BundleInstall.swift` (separate, internal): `stage(_:near:)` L17, `swap(_:into:)` L34, `discard(_:)` L47 (used by `SparkleInternals.veto`), `removeOriginal(_:)` L58, `clearQuarantine` L64. It has no archive extraction since rev 1.

---

## Local Sparkle checkout
- `~/Library/Developer/Xcode/DerivedData` first entries: `apple-fjgqwtpwlwxibpduokvkdyiphfrl`, `CompilationCache.noindex`, `FilesCore-fjgqwtpwlwxibpduokvkdyiphfrl` (none for this project).
- **Full source checkout exists**: `LauncherKit/.build/checkouts/Sparkle` (detached HEAD `ab7d71291238df6e0492143b120c9b696a35f603` = 2.10.1). Contains `Sparkle.xcodeproj`, `Configurations/`, `Autoupdate/`, `Downloader/`, `InstallerLauncher/`, `InstallerConnection/`, `InstallerStatus/`, `sign_update/`, `generate_keys/`, `Makefile`, `Package.swift` (binary target from `https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip`, checksum `4c2e48a3…022a`).
- Headers: `LauncherKit/.build/checkouts/Sparkle/Sparkle/SPUUpdater.h` (`checkForUpdates` L109, `checkForUpdatesInBackground` L134, `checkForUpdateInformation` L154, `canCheckForUpdates` L171, `sessionInProgress` L189, `automaticallyChecksForUpdates` L210, `automaticallyDownloadsUpdates` L250, `resetUpdateCycle` L379), `.../Sparkle/SPUUserDriver.h`, `.../Sparkle/SPUUpdaterDelegate.h`, `.../Sparkle/SPUStandardUserDriver.h`.
- Build switches in `Configurations/ConfigCommon.xcconfig`: L6 `SPARKLE_EMBED_INSTALLER_LAUNCHER_XPC_SERVICE = 1`, L8 `SPARKLE_EMBED_DOWNLOADER_XPC_SERVICE = 1`, L9-10 status/connection XPC `= 0`, L13 `SPARKLE_BUILD_LEGACY_SUUPDATER = 1`, L19 `SPARKLE_BUILD_LEGACY_DSA_SUPPORT = 1`, L27 `SPARKLE_BUILD_LEGACY_DELTA_SUPPORT = 1`, L34 `SPARKLE_BUILD_PACKAGE_SUPPORT = 1`, L37 `SPARKLE_BUILD_UI_BITS = 1`, L40 `SPARKLE_COPY_LOCALIZATIONS = 1`; L43-46 note: when turning off legacy delta / package support, also remove the matching `-D` flags from `OTHER_SWIFT_FLAGS_COMMON`.
- Prebuilt artifact: `LauncherKit/.build/artifacts/sparkle/Sparkle/{bin/{BinaryDelta,generate_appcast,generate_keys,old_dsa_scripts,sign_update}, Sparkle.xcframework/macos-arm64_x86_64, CHANGELOG, INSTALL, LICENSE, SampleAppcast.xml}`.
- `.gitignore` ignores `.build/`, `.swiftpm/`, `build/`, `TrackpadLauncher.xcodeproj/`, `TrackpadLauncher/Info.plist`.
- `appcast.xml` (repo root) is an empty channel: `<rss ... xmlns:sparkle=...><channel><title>Trackpad Launcher</title></channel></rss>`.
