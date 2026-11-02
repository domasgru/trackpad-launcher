## Design

### Problem

Trackpad Launcher has to learn of a newer version and install it, while making no other network request. The shape is not obvious because the update spans both models. It starts at `Launcher`'s settings-window closed→open edge, which today shows only as `window` leaving `.closed` (E3). It renders in `Launcher`'s window and must be dropped when that window closes. Yet it replaces the running process's own bundle, changes `Lifecycle`'s quit policy and must hand the process over to the new version.

Constraints the design honours:
- `Launcher` knows nothing of `Placement`, `Build` or quitting (E1).
- Every port has exactly two adapters. None is `async`, and the model drops a late result by guarding on its own state (E4).
- No timers. Every input is a push.
- The source scan bans `URLSession` outright. Relaxing a ban means moving the token to one owning file (E11, Preserve 3).
- No stored value holds "release build in /Applications", and `--as-release-build` makes a development build read `.release` (E2, O7).
- With the default configuration, when the running app opens its own replaced bundle, LaunchServices only reopens the old process (R-3).
- The administrator path is two renames (E8), which R13's restart scenario does not allow.
- GitHub rejects a request without a User-Agent, and URLSession's default headers reveal the Darwin version and the user's languages (G2, N1).
- A release object has no minimum-macOS field (G3), and R3 allows exactly one request.

### Usage (caller's view)

**README: in-app updates.** A release build in /Applications owns an `Updater`. Each time the settings window opens from closed, the `Updater` reads the public release list once. If a newer version runs on this Mac, `updater.card` becomes `.available(version)`, and the window shows it as its first group.
- `updateNow()` downloads, checks and installs the version. *Try again* calls the same method.
- `cancel()` stops a download.
- Closing the window drops a check in flight and cancels a download. An install keeps going.
- While `isInstalling` is true, *Quit Trackpad Launcher* is disabled and every ordinary quit only closes the window.
- Once installed, the new version opens as an ordinary opening by hand from /Applications. Like any such opening, it stops every other copy, this one included.

A development build, a copy outside /Applications, a copy showing the move dialog and a copy started with `--as-release-build` have no `Updater` at all, so they have no path to the network.

Call site 1, the composition root. This is the one place the network adapters are built:

```swift
func applicationWillFinishLaunching(_: Notification) {
    NSApp.disableRelaunchOnLogin()
    let location = ThisCopy.location()
    let placement = Placement(
        build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)
    let startAtLogin = StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)
    let updater = makeUpdater(placement: placement, location: location)
    lifecycle = Lifecycle(
        placement: placement, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location),
        startAtLogin: startAtLogin, updater: updater,
        makeResident: { [unowned self] in makeResident(startAtLogin, updater) })
    moveDialog = MoveDialogPresenter(lifecycle: lifecycle)
}

/// R1, R2: only a release build lying in /Applications ever reaches the network. "Release" here means the process's
/// own Developer ID signature, whatever `--as-release-build` says: `developerIDSigner()` takes no arguments.
private func makeUpdater(placement: Placement, location: Location) -> Updater? {
    guard let signer = CodeSignature.developerIDSigner(),
          let installed = InstalledRelease(placement: placement, version: ThisCopy.version(), macOS: ThisCopy.macOS())
    else { return nil }
    return Updater(
        installed, releases: GitHubReleases(),
        installer: ApplicationsUpdater(replacing: location.running, signer: signer))
}

private func makeResident(_ startAtLogin: StartAtLogin, _ updater: Updater?) -> Launcher {
    // ... as today, plus:
    let launcher = Launcher(/* ...as today... */, startAtLogin: startAtLogin, updater: updater)
    shell = SettingsShell(launcher: launcher, updater: updater, quit: { [unowned self] in lifecycle.quit() })
    return launcher
}
```

Call site 2, the settings window. The card is the first group, and Quit follows `isInstalling`:

```swift
VStack(spacing: 10) {
    if let updater, let card = updater.card {
        UpdateCardView(card: card, updateNow: updater.updateNow, cancel: updater.cancel)
    }
    FormGroup { /* gesture rows, as today */ }
    // ...
    HStack(spacing: 8) {
        Spacer(minLength: 0)
        Button(Copy.quitButton, action: actions.quit)
            .buttonStyle(TintedButtonStyle(tint: .red))
            .disabled(updater?.isInstalling == true)
        Button("Close") { launcher.closeWindow() } // ...
    }
}
```

Call site 3, a requirement scenario at the one high seam. A process is a real `Lifecycle`, `Launcher` and `Updater` over in-memory adapters, and every completion is held until the test releases it:

```swift
@Test func aDownloadThatFinishesInstallsReopensTheNewVersionAndCarriesEverythingOver() {   // R7, R9, R10
    let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    let old = world.launch(.byHand, running: .release("1.0.0"))
    old.releases.deliver([.version("1.1.0", needs: "26.0")])
    #expect(old.updater.card == .available(Version(1, 1, 0)))

    old.updater.updateNow()
    old.updates.progress(0.4)
    #expect(old.updater.card == .downloading(Version(1, 1, 0), progress: 0.4))
    old.tap(1)                                                  // R9: gestures during the download
    #expect(old.system.broughtToFront == [world.mac.app("Arc")])

    old.updates.finishDownload()
    #expect(old.updater.card == .installing(Version(1, 1, 0)) && old.updater.isInstalling)
    old.updates.swapIn()
    old.updates.answerOpen(started: true)
    #expect(!old.copies.hasEnded)                               // the old copy waits to be stopped

    let new = world.launch(.byHand, others: [.earlier], running: .release("1.1.0"))
    #expect(new.copies.stopped == [.earlier])
    new.letExit(RunningCopy.earlier.id)
    #expect(new.window == .open(request: 1) && new.releases.fetches == 1)   // R9: the reopened window checks
    new.releases.deliver([.version("1.1.0", needs: "26.0")])
    #expect(new.updater.card == nil)
    #expect(world.log.entries == ["update", "swap", "openNewVersion", "stop"])   // no login-item call, ever
    #expect(world.loginItem.isOn && world.permissions.asks.isEmpty)        // R10
}
```

Call site 4, the release process (R14):

```sh
# raise MARKETING_VERSION / CURRENT_PROJECT_VERSION in Config/Version.xcconfig, commit, push
Scripts/release.sh                                # builds, notarises, staples, archives, creates a draft release
gh release edit v1.1.0 --draft=false --latest     # publishing is the deliberate second step
```

### Shape

**Data first.**
- `Version` is the one ordering. It holds dotted whole numbers and compares them part by part (R4, "1.9.0 < 1.10.0").
- `Release` is a release as the app understands it, and it can only be built in a form that counts. The adapter builds one only for a published full release that carries an uploaded `.aar` asset whose name declares both a version and a minimum macOS. So a draft, a pre-release, a release with no app and a release with no minimum cannot reach the model (per type-system-discipline, "types are constructions").
- `InstalledRelease` is the running copy as an update sees it. It can be built only for `Placement.installed` with a parseable version. Together with the `Signer` gate, an `Updater` can only exist where R1 allows a check (per encode-lessons-in-structure).
- `UpdateCard` is the four visible states. *Cancel* exists only in `.downloading`, and only `.downloading` has a bar.
- The model's private `Phase` adds `idle`, `checking` and `opening`, and carries the ticket that drops late results.

**One deep model, peer to the two existing ones.** `Updater` (`@MainActor @Observable`, `LauncherCore`) owns everything an update decides:
- the R1 trigger
- dropping a stale check
- choosing the offer (pure)
- the download's cancel rules
- what each outcome does to the card
- whether an install is under way

Its public surface is `card`, `isInstalling`, `updateNow()` and `cancel()`. Two internal edges, `windowOpened()` and `windowClosed()`, are called only by `Launcher`. It follows the `StartAtLogin` precedent: one object built by the composition root and shared by both models, each using a different part.
- `Launcher` only reports its own two window transitions. It learns nothing about builds, placement, versions or the network. The edge lives where the window state lives (single source of truth). The shell is no place for it, because Observation coalesces a `.closed` then `.open` within one turn (Gotcha 7).
- `Lifecycle` only reads `isInstalling` in `shouldEnd` and `quit()`, so the quit policy stays in `Lifecycle`'s one exhaustive switch.
- No path leads from `Updater` into `Lifecycle`. The hand-over is the existing route (Preserve 1, 2): the old process opens the swapped bundle with `createsNewApplicationInstance = true` (R-3, R-4) and then waits. The new process starts by hand from /Applications, so `.runWithWindow` force-stops every other copy, waits for its exit, builds its resident and opens its window, and that first opening checks (R9). The old copy keeps its gestures until it is stopped.

**Two ports, each deep, each with two adapters.**
- `ReleaseList.fetch` hides everything about the release list: the URL, the headers, the privacy configuration, GitHub's JSON, the asset-name contract and every R4 wire filter.
- `UpdateInstaller` covers replacing this copy and has three methods:
  - `update(to:events:)` hides the whole sequence: download into memory, the 30 s stall rule, the size check, safe unpacking, genuineness, the writability check, the administrator prompt, the atomic swap and every clean-up.
  - `cancelDownload()`.
  - `openNewVersion`, which hides the LaunchServices configuration.

  The model never holds a file path, so R3/R12's "delete the download" cannot be forgotten by a caller.
- Asynchronous delivery keeps model tests synchronous, as the existing ports do (E4). Each port takes an `@escaping @MainActor` completion or event sink, and the model sets its phase before calling, since an in-memory adapter may answer inline. The in-memory adapters hold each closure until the test delivers, withholds, or delivers late. The real adapters start a `Task` that awaits `@concurrent` statics and calls back on the main actor.

**The check (R1, R2, R4, R6).**
- `windowOpened()` starts a check unless an install is under way, and the window has already opened. A re-front is not an edge, so it never checks.
- `windowClosed()` drops a check, an offer or a failure, and cancels a download, but leaves an install alone. A late answer carries a ticket that no longer matches the live one and is dropped.
- A failed request delivers `[]`, which leaves the model idle: no card and no error, and the next opening checks again.
- `Release.newerVersion(in:than:on:)` is the pure R4 rule.
- Eligibility is decided at construction. There is no `Updater` without a `Signer` (the real Developer ID signature, which `--as-release-build` cannot fake) and an `InstalledRelease` (`.installed` only). That covers dev builds, ~/Applications, the move dialog and O7. A login start never opens the window, so it never checks.

**The request (R3, N1-N4, G1-G6).**
- One `GET https://api.github.com/repos/domasgru/trackpad-launcher/releases` with no query string. It reads the default first page, the newest 30 releases (G4).
- Each request gets a fresh `URLSessionConfiguration.ephemeral` session, invalidated when the request finishes, with:
  - `httpShouldSetCookies = false`, `httpCookieAcceptPolicy = .never`, `httpCookieStorage = nil`
  - `urlCache = nil`, `urlCredentialStorage = nil`, `requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData`
  - `waitsForConnectivity = false`
  - `timeoutIntervalForRequest = 30`
  - `httpAdditionalHeaders`: `User-Agent: TrackpadLauncher`, `Accept-Language: en`, `X-GitHub-Api-Version: 2022-11-28`, and `Accept: application/vnd.github+json` for the list or `application/octet-stream` for the archive.

  These replace the identifying defaults (N2 b2) and apply across GitHub's redirect.
- Pinning the API version keeps every shipped version parsing the same JSON after GitHub changes its default (R14).
- The release list is parsed into `[Release]` inside the adapter, and no wire type crosses the port.

**The download (R7, R12).**
- The archive (about 3 MB, V4) is received into memory. Nothing is written until all of it has arrived, so a *Cancel*, a *Close*, a Quit, a crash or a logout mid-download leave nothing on disk, and "delete the download" holds by construction.
- Progress comes from the task's own `progress` push (KVO), throttled to whole percents and computed against the size the list declared.
- A body longer or shorter than that declared size fails.
- 30 s with no byte fails through the request's own idle timeout. That timeout is reset by every byte (N3), so the app has no timer of its own.
- *Cancel* cancels the task.
- The `.downloaded` push and the adapter's cancellation check run in one main-actor turn. Either a *Cancel* lands first, and nothing more happens, or the model is already `.installing`, where *Cancel* does not exist and closing does not cancel. A cancel can therefore never meet a swap that has already started.

**Genuineness (R8).** The check lives in `CodeSignature.isGenuine`, where `SecStaticCode` and `SecRequirement` stay confined (V1-V4, E14).
- It runs against the unpacked bundle with `kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSNoNetworkAccess`. The last flag makes `notarized` read the stapled ticket offline, so no third request is made (V3).
- The requirement is `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = "<team>" and identifier "<id>" and notarized`.
- The team and identifier come from this process's own signature, read once at start (`Signer`). They are never Swift literals.
- The sealed Info.plist (`kSecCodeInfoPList`) must name exactly the offered `version` and `minimumMacOS`. A release whose asset name lies cannot install an app this Mac cannot run.

**Unpacking.** The asset is an Apple Archive (O6, V4), unpacked in-process into an `.itemReplacementDirectory` on the /Applications volume.
- Every entry is checked before it is written: a relative path under `TrackpadLauncher.app/` with no `..` component; a directory, a regular file, or a symbolic link whose target resolves inside the bundle; and nothing else.
- One refused entry aborts the unpack and discards the folder. Nothing outside the staging folder is ever written before verification.
- Quarantine is cleared per item, as the move does (Preserve 10).
- `release.sh` archives with `-exclude-field uid,gid,xat,acl,flg`, so no build-machine extended attributes or owners ship.

**Installing and relaunching (R9, R11, R13).**
- The effect order is: unpack, verify, then swap. The swap is the first change anywhere.
  - The swap is shared with the move: `ApplicationsInstaller.put`, which uses `BundleInstall.swap` (`replaceItemAt`, atomic per R-1) when /Applications and the bundle are writable, else `PrivilegedInstall.swap`.
  - The privileged script now runs one atomic exchange as root, `osascript -l JavaScript` calling Foundation's `replaceItemAt` with the paths as argv (R-5), or a single `mv` when the destination is missing. This closes E8's two-rename gap for the move too. A restart at any instant leaves a whole version (R13).
  - The administrator prompt therefore comes only after the download is verified (R11). Cancelling it gives `.declined`, which returns the card to `.available` with nothing changed. The move's "cancel ends the process" stays the move's own rule (Change 3).
- Then `openNewVersion` (`createsNewApplicationInstance = true`, `activates = true`).
  - If LaunchServices reports a started process, the old copy shows "Installing…" until the new one stops it.
  - If not, the card shows the failed state. *Try again* converges: same-version swap, open again.
- The destination is `Location.running`, the bundle that runs, which lies in /Applications by construction. It is not the move's search for an identifier.

**Carry-over (R10).** The update changes nothing but the bundle at the same path:
- the same identifier and team, so the designated requirement still matches (V5);
- the same defaults domain;
- no login-item call at all;
- no first run, because settings exist.

The login item is not handed over the way the move does it (O2): the reason for that handover, a different path the user may delete, is absent here. A suspend/resume on every update would risk a "login item added" notice each time.

**Quit and close (R13).**
- A *Close* during a download cancels it.
- *Quit* during a download ends the process, and an in-memory download dies with it, with nothing changed on disk.
- While `isInstalling`, which covers `installing` and `opening`:
  - `quit()` does nothing and the button is disabled;
  - `shouldEnd(.other)` closes an open window and otherwise refuses, as `.moving` does;
  - `.system` always ends (Preserve 12).

**What the design deliberately does not do:** check at login or while closed, retry, poll, resume a download, keep a check's result across openings, show an error, downgrade, read release notes, authenticate to GitHub, or write a downloaded file to disk.

```swift
// MARK: LauncherCore — domain types (one file with the model). Foundation + Observation only.

/// A version as releases and Info.plists write it: dotted whole numbers ("1.10.0"). Compared part by part
/// numerically, a missing part counting as zero: 1.9.0 < 1.10.0, 1.1 == 1.1.0. "1.1.0-beta", "v1.1", "" are not
/// versions, so a release named with one never counts (R4).
public struct Version: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// As written, for the card: "Version 1.10.0 is available".
    public let description: String
    /// Trailing zeros dropped, so ==, hash and < agree.
    private let parts: [Int]

    /// Non-empty by construction: this Mac's macOS, fixtures.
    public init(_ first: Int, _ rest: Int...) { fatalError("not implemented") }
    /// Digits and single dots only; each part at most 9 digits.
    public init?(_ text: String) { fatalError("not implemented") }
    public static func < (a: Version, b: Version) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
    public static func == (a: Version, b: Version) -> Bool { a.parts == b.parts }
    public func hash(into hasher: inout Hasher) { hasher.combine(parts) }
}

/// A published full release that carries an app and declares the macOS it needs. Built only by the release list's
/// adapter: a draft, a pre-release, an asset still uploading, or a release without a well-named archive never becomes one.
public struct Release: Equatable, Sendable {
    public let version: Version
    public let minimumMacOS: Version
    /// Where the app's archive downloads from (HTTPS, this repository's release downloads).
    public let archive: URL
    /// The archive's size as the list declares it: the download's progress denominator and exact expected length.
    public let archiveSize: Int
    public init(version: Version, minimumMacOS: Version, archive: URL, archiveSize: Int)

    /// R4, the one rule: the highest release above `running` that `macOS` meets the minimum of; nil when none.
    public static func newerVersion(in releases: [Release], than running: Version, on macOS: Version) -> Release? {
        releases.filter { $0.version > running && $0.minimumMacOS <= macOS }.max { $0.version < $1.version }
    }
}

/// The running copy as an update check sees it. Exists only for a copy in /Applications (`Placement.installed`) whose
/// version parses; the composition root also requires the Developer ID signer before it builds an `Updater` (R1, R2).
/// Read once at start: after a swap, `Bundle.main` would read the new bundle (R-6).
public struct InstalledRelease: Equatable, Sendable {
    public let version: Version
    public let macOS: Version
    public init?(placement: Placement, version: String?, macOS: Version) {
        guard placement == .installed, let version = version.flatMap(Version.init) else { return nil }
        self.version = version
        self.macOS = macOS
    }
}

/// The update card, the settings window's first group while a newer version is known. Not dismissable.
public enum UpdateCard: Equatable, Sendable {
    /// "Version 1.1.0 is available" · *Update now*
    case available(Version)
    /// "Downloading version 1.1.0…" · a bar at `progress` (0...1) · *Cancel*. The only state with *Cancel*.
    case downloading(Version, progress: Double)
    /// "Installing version 1.1.0…": no bar, no *Cancel*; *Quit Trackpad Launcher* is disabled.
    case installing(Version)
    /// "The update couldn't be installed." · *Try again*
    case failed(Version)
}

/// What an update reports, in this order: any `.progress`; then `.failed`, or `.downloaded` followed by exactly one
/// of `.installed`, `.declined`, `.failed`.
public enum UpdateEvent: Equatable, Sendable {
    /// 0...1 of the archive received.
    case progress(Double)
    /// The whole archive arrived. From here on nothing cancels the update.
    case downloaded
    /// /Applications holds the new version.
    case installed
    /// The administrator prompt was cancelled; nothing changed.
    case declined
    /// Nothing changed: the download failed or stalled, the app was not genuine, or the swap failed.
    case failed
}
```

```swift
// MARK: LauncherCore — ports (beside the existing eight)

/// The public list of Trackpad Launcher releases. Real: GitHubReleases. Test: InMemoryReleaseList.
@MainActor public protocol ReleaseList: AnyObject {
    /// One request for the list. Returns at once; `done` runs once on the main actor, possibly inside this call, with
    /// every release that counts (see `Release`), or none when the request failed (offline, no answer, any status but
    /// 200, a body that does not parse). Sends nothing about the user, the Mac, this version or macOS.
    func fetch(then done: @escaping @MainActor ([Release]) -> Void)
}

/// Replacing this copy in /Applications with a newer version, and opening it. Real: ApplicationsUpdater. Test:
/// InMemoryUpdateInstaller.
@MainActor public protocol UpdateInstaller: AnyObject {
    /// Downloads `release`'s archive into memory, then installs it. Installing means: unpack into a staging folder
    /// beside /Applications, check that it is genuine (this copy's Developer ID team, notarised, this identifier,
    /// `release`'s version and minimum macOS, every resource sealed), and swap it in for this copy in one atomic step,
    /// as an administrator when this account cannot write there. The prompt comes only at that step. Returns at once;
    /// `events` runs on the main actor, possibly inside this call, in `UpdateEvent`'s order. 30 s without a byte fails.
    /// /Applications changes only with `.installed`. On every outcome nothing of the update is left on disk except
    /// the installed app.
    func update(to release: Release, events: @escaping @MainActor (UpdateEvent) -> Void)
    /// Before `.downloaded`: stops the download, and no further event arrives. From `.downloaded` on: does nothing;
    /// the install finishes.
    func cancelDownload()
    /// Opens the copy now in /Applications as a new process, as an opening by hand, which then stops this one.
    /// `started` runs once on the main actor: whether macOS started it.
    func openNewVersion(then started: @escaping @MainActor (Bool) -> Void)
}
```

```swift
// MARK: LauncherCore — the model

/// The update check, the update card and replacing this copy with a newer version. Exists only in a release build in
/// /Applications. `Launcher` reports the settings window's openings from closed and its closings; `Lifecycle` reads
/// `isInstalling`; the view renders `card` and sends `updateNow` / `cancel`.
@MainActor @Observable
public final class Updater {
    /// Every legal situation, and nothing else. While the window is closed it is `idle`, `installing` or `opening`,
    /// or a card that the next opening replaces with a fresh check.
    private enum Phase {
        case idle
        case checking(ticket: Int)
        case offering(Release)
        case downloading(Release, ticket: Int, progress: Double)
        /// Unpacking, verifying, maybe the administrator prompt, the swap. Survives the window closing.
        case installing(Release, ticket: Int)
        /// Swapped in and asked to open; this process waits for the new version to stop it.
        case opening(Release)
        case failed(Release)
    }

    private var phase: Phase = .idle
    @ObservationIgnored private var tickets = 0
    @ObservationIgnored private let installed: InstalledRelease
    @ObservationIgnored private let releases: any ReleaseList
    @ObservationIgnored private let installer: any UpdateInstaller

    public init(_ installed: InstalledRelease, releases: any ReleaseList, installer: any UpdateInstaller) {
        self.installed = installed
        self.releases = releases
        self.installer = installer
    }

    /// nil while no newer version is known (R5).
    public var card: UpdateCard? {
        switch phase {
        case .idle, .checking: nil
        case .offering(let r): .available(r.version)
        case .downloading(let r, _, let progress): .downloading(r.version, progress: progress)
        case .installing(let r, _), .opening(let r): .installing(r.version)
        case .failed(let r): .failed(r.version)
        }
    }

    /// R13: Quit is disabled and an ordinary quit only closes the window. The one source of that rule.
    public var isInstalling: Bool {
        switch phase {
        case .installing, .opening: true
        default: false
        }
    }

    /// From `Launcher`, only when the window goes from closed to open, after it has opened (R1: at once).
    func windowOpened() {
        guard !isInstalling else { return }  // the card keeps "Installing…"
        let ticket = nextTicket()
        phase = .checking(ticket: ticket)  // first: an in-memory list may answer inside `fetch`
        releases.fetch { [unowned self] in checked($0, ticket: ticket) }
    }

    /// From `Launcher`, only when the window goes from open to closed. A check's result is never kept for the next
    /// opening (R1); a download stops (R13); an install continues (R13).
    func windowClosed() {
        switch phase {
        case .downloading:
            phase = .idle
            installer.cancelDownload()
        case .checking, .offering, .failed: phase = .idle
        case .idle, .installing, .opening: break
        }
    }

    /// *Update now* and *Try again* (R7, R12).
    public func updateNow() {
        switch phase {
        case .offering(let release), .failed(let release):
            let ticket = nextTicket()
            phase = .downloading(release, ticket: ticket, progress: 0)
            installer.update(to: release) { [unowned self] in progressed($0, ticket: ticket) }
        default: break
        }
    }

    /// *Cancel*, only while downloading (R7).
    public func cancel() {
        guard case .downloading(let release, _, _) = phase else { return }
        phase = .offering(release)
        installer.cancelDownload()
    }

    private var liveTicket: Int? {
        switch phase {
        case .checking(let t), .downloading(_, let t, _), .installing(_, let t): t
        case .idle, .offering, .opening, .failed: nil
        }
    }

    private func nextTicket() -> Int { tickets += 1; return tickets }

    /// R1: a check from an earlier opening, or one the window closed on, is dropped. R4: pure choice. R6: [] is silent.
    private func checked(_ list: [Release], ticket: Int) {
        guard ticket == liveTicket else { return }
        phase = Release.newerVersion(in: list, than: installed.version, on: installed.macOS).map(Phase.offering) ?? .idle
    }

    private func progressed(_ event: UpdateEvent, ticket: Int) {
        guard ticket == liveTicket else { return }  // a cancelled or earlier attempt
        switch (phase, event) {
        case (.downloading(let r, _, _), .progress(let fraction)): phase = .downloading(r, ticket: ticket, progress: fraction)
        case (.downloading(let r, _, _), .downloaded): phase = .installing(r, ticket: ticket)
        case (.downloading(let r, _, _), .failed), (.installing(let r, _), .failed): phase = .failed(r)  // R8, R12
        case (.installing(let r, _), .declined): phase = .offering(r)  // R11
        case (.installing(let r, _), .installed):
            phase = .opening(r)
            installer.openNewVersion { [unowned self] in opened($0) }  // R9
        default: break
        }
    }

    /// Started: the new version, opened by hand from /Applications, stops this process through its own route.
    private func opened(_ started: Bool) {
        guard case .opening(let r) = phase, !started else { return }
        phase = .failed(r)  // /Applications holds the new version; Try again converges (same-version swap, open again)
    }
}
```

```swift
// MARK: LauncherCore — the two existing models, the whole diff

// Launcher: one optional collaborator, two edges. Launcher learns no build, placement, version or network.
public init(/* ...as today... */, startAtLogin: StartAtLogin, updater: Updater? = nil)

public func openedByHand() {
    // ...first-opening work as today...
    let opens = window == .closed
    openings += 1
    window = .open(request: openings)
    resolveRows()
    scanner.scan()
    if opens { updater?.windowOpened() }  // a re-front is not an opening (R1)
}

public func closeWindow() {
    guard window != .closed else { return }
    window = .closed
    updater?.windowClosed()
}

// Lifecycle: reads one fact. The hand-over is the new process's ordinary `.runWithWindow` route.
public init(
    placement: Placement, copies: any RunningCopies, installer: any Installer, startAtLogin: StartAtLogin,
    updater: Updater? = nil, makeResident: @escaping @MainActor () -> Launcher)

public func shouldEnd(_ request: QuitRequest) -> Bool {
    switch stage {
    case .ending, .idle, .replacingOthers, .askingToMove, .moveFailed: return true
    case .moving: return request == .system
    case .resident(let launcher):
        guard request == .other else { return true }  // logout, restart, shutdown: always, mid-install too (R13)
        if launcher.isWindowOpen { launcher.closeWindow(); return false }
        // With the window closed, an ordinary quit is a script's: end, unless an update installs (as `.moving`).
        return updater?.isInstalling != true
    }
}

public func quit() {
    guard case .resident = stage, updater?.isInstalling != true else { return }  // disabled while installing (R13)
    startAtLogin.suspend()
    end()
}
```

```swift
// MARK: LauncherPlatform — GitHubReleases.swift: the one network file (the only file that may say URLSession or http)

/// The public release list and a release's archive. Every request uses its own ephemeral session (no cookie, cache or
/// credential store, nothing on disk) and HTTPS to GitHub, with no query string, constant headers that name neither
/// the user, the Mac, this version nor macOS, and fails after 30 s in which no byte arrives (the request's own idle
/// timeout: no timer of ours).
@MainActor public final class GitHubReleases: ReleaseList {
    static let listURL = URL(string: "https://api.github.com/repos/domasgru/trackpad-launcher/releases")!
    static let downloadsPath = "/domasgru/trackpad-launcher/releases/download/"
    static let headers = ["User-Agent": "TrackpadLauncher", "Accept-Language": "en", "X-GitHub-Api-Version": "2022-11-28"]
    private let endpoint: URL
    private let stall: TimeInterval

    public convenience init() { self.init(endpoint: Self.listURL, stall: 30) }
    /// Tests: a listener on 127.0.0.1 and a short stall.
    init(endpoint: URL, stall: TimeInterval) { self.endpoint = endpoint; self.stall = stall }

    public func fetch(then done: @escaping @MainActor ([Release]) -> Void) {
        Task { done(await Self.list(at: endpoint, stall: stall) ?? []) }
    }

    @concurrent static func list(at url: URL, stall: TimeInterval) async -> [Release]? { fatalError("not implemented") }
    // TODO: session(accept: "application/vnd.github+json", stall:) → data(for: GET url) → 200 → parse; then invalidate.

    /// The wire half of R4, pure: each element that is not a draft and not a pre-release, with an asset whose
    /// `state` is "uploaded", whose `browser_download_url` is https://github.com + `downloadsPath`, and whose `name`
    /// parses with `archiveName`. Tag, title and body are ignored. nil only when the JSON is not a release array.
    static func parse(_ json: Data) -> [Release]? { fatalError("not implemented") }

    /// "TrackpadLauncher-<version>-macOS-<minimum>.aar", the contract with every shipped version; nil for any other.
    static func archiveName(_ name: String) -> (version: Version, minimumMacOS: Version)? { fatalError("not implemented") }

    /// The download half, used by ApplicationsUpdater. Tests inject a short stall.
    struct Download: Sendable {
        let stall: TimeInterval
        /// The whole archive, exactly `release.archiveSize` bytes, or nil (failed, stalled, cancelled, wrong length).
        /// `progress` pushes on the main actor, at most once per whole percent. Task cancellation cancels the request.
        func archive(of release: Release, progress: @escaping @MainActor (Double) -> Void) async -> Data? {
            fatalError("not implemented")
            // TODO: session(accept: "application/octet-stream", stall:); data(for:delegate:) with a task delegate that
            // KVO-observes task.progress (a push) → fraction of archiveSize → hop to main; cancel the task when
            // countOfBytesReceived exceeds archiveSize; withTaskCancellationHandler { task.cancel() }.
        }
    }

    /// Ephemeral; cookies off and storage nil; urlCache nil; credential storage nil; reload ignoring caches;
    /// waitsForConnectivity false; timeoutIntervalForRequest = stall; httpAdditionalHeaders = headers + Accept.
    private static func session(accept: String, stall: TimeInterval) -> URLSession { fatalError("not implemented") }
}

// MARK: LauncherPlatform — ApplicationsUpdater.swift (the only file that may say createsNewApplicationInstance)

/// Replaces the running copy in /Applications with a release, then opens it as a new process.
@MainActor public final class ApplicationsUpdater: UpdateInstaller {
    private let bundle: URL  // Location.running of an `.installed` copy: the bundle an update replaces
    private let signer: Signer
    private let administrator: any Administrator
    private let download: GitHubReleases.Download
    private var job: Task<Void, Never>?
    private var isPastDownload = false

    public convenience init(replacing bundle: URL, signer: Signer) {
        self.init(replacing: bundle, signer: signer, administrator: AuthorizationAdministrator(),
                  download: GitHubReleases.Download(stall: 30))
    }
    /// Tests: a temp "Applications", TestAdministrator, a local server's download with a short stall.
    init(replacing bundle: URL, signer: Signer, administrator: any Administrator, download: GitHubReleases.Download)

    public func update(to release: Release, events: @escaping @MainActor (UpdateEvent) -> Void) {
        isPastDownload = false
        job = Task {
            guard let archive = await download.archive(of: release, progress: { events(.progress($0)) }) else {
                if !Task.isCancelled { events(.failed) }
                return
            }
            // One main-actor turn: a Cancel either landed before this check (nothing more), or finds the install begun.
            guard !Task.isCancelled else { return }
            isPastDownload = true
            events(.downloaded)
            events(await Self.install(archive, as: release, replacing: bundle, signer: signer, by: administrator))
        }
    }

    public func cancelDownload() {
        guard !isPastDownload else { return }
        job?.cancel()
    }

    public func openNewVersion(then started: @escaping @MainActor (Bool) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true  // R-3: by default the old process only gets a reopen
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { app, _ in
            let didStart = app != nil
            DispatchQueue.main.async { MainActor.assumeIsolated { started(didStart) } }
        }
    }

    /// Unpack → verify → swap. Nothing interrupts it. Discards the staging folder on every outcome but `.installed`.
    @concurrent private static func install(
        _ archive: Data, as release: Release, replacing bundle: URL, signer: Signer, by administrator: any Administrator
    ) async -> UpdateEvent {
        fatalError("not implemented")
        // TODO: staged = try BundleInstall.unpack(archive, near: bundle)           else .failed
        //       CodeSignature.isGenuine(staged, as: release, signer: signer)       else discard; .failed  (before any prompt: R11)
        //       switch ApplicationsInstaller.put(staged, at: bundle, by: administrator) {
        //       .installed → .installed; .cancelled → discard, .declined; .failed → discard, .failed }
    }
}

// MARK: LauncherPlatform — the existing files, additions only

extension ApplicationsInstaller {
    /// The move's and the update's one swap: `BundleInstall.swap` when /Applications and `destination` are writable,
    /// else `PrivilegedInstall.swap`, which shows the prompt. Atomic on both paths; `destination` untouched unless
    /// `.installed`. (Extracted from today's `copy`.)
    nonisolated static func put(_ staged: URL, at destination: URL, by administrator: any Administrator) -> InstallOutcome
}

extension BundleInstall {  // BundleInstall.swift, the only file that may say AppleArchive / ArchiveStream / removexattr / itemReplacementDirectory
    /// `archive` unpacked into a fresh item-replacement folder on `destination`'s volume; returns the bundle in it.
    /// Every entry is checked before it is written (`admits`); one refused entry aborts and discards the folder.
    /// Quarantine is cleared on every item. Nothing at `destination` changes.
    static func unpack(_ archive: Data, near destination: URL) throws -> URL { fatalError("not implemented") }
    // TODO: ArchiveByteStream.customStream over `archive` → decompression → decode → extractStream(extractingTo:
    // folder, selectUsing: { admits(...) ? .ok : .abort }); then clearQuarantine(under:).

    /// Pure, tested over crafted entries: a relative path equal to or under "TrackpadLauncher.app/", no "..", no
    /// leading "/"; a directory, a regular file, or a symbolic link whose target, resolved from the link's folder, stays
    /// inside the bundle. Anything else is refused.
    static func admits(path: String, kind: ArchiveEntryKind, linkTarget: String?) -> Bool { fatalError("not implemented") }
}

enum ArchiveEntryKind { case directory, file, symbolicLink, other }

extension CodeSignature {  // CodeSignature.swift keeps every SecCode / SecStaticCode / SecRequirement
    /// Who signed this process, when the signature truly is a Developer ID: the team and identifier an update must
    /// match. Never from `--as-release-build`: it takes no arguments. nil for Xcode, the perf build, ad hoc.
    public static func developerIDSigner() -> Signer? { fatalError("not implemented") }
    // TODO: SecCodeCopySelf; SecCodeCheckValidity(developerID requirement); SecCodeCopySigningInformation → team, identifier.

    /// R8 for a bundle on disk: the requirement string above (team, identifier, Developer ID markers, notarized),
    /// checked with strict validation of every architecture, nested code and resource, offline
    /// (kSecCSNoNetworkAccess: the stapled ticket only); and its sealed Info.plist names exactly `release.version`
    /// and `release.minimumMacOS`.
    static func isGenuine(_ bundle: URL, as release: Release, signer: Signer) -> Bool { fatalError("not implemented") }
}

public struct Signer: Sendable, Equatable { let team: String; let identifier: String }

extension ThisCopy {
    /// CFBundleShortVersionString as this process started with it.
    public static func version() -> String? { fatalError("not implemented") }
    /// ProcessInfo's operatingSystemVersion.
    public static func macOS() -> Version { fatalError("not implemented") }
}

enum PrivilegedInstall {  // the one script, now atomic, for the move and the update; the only file that may say osascript
    /// "$1" destination, "$2" staged, "$3" the exchange program; never interpolated. With something at the
    /// destination: Foundation's replaceItemAt as root, one exchange of the two directory entries (R-1, R-5); else one
    /// mv. A status matches what /Applications holds, and a kill at any instant leaves a whole copy there.
    static let script = """
        destination="$1"; staged="$2"; exchange="$3"
        if [ -e "$destination" ] || [ -L "$destination" ]; then
            /usr/bin/osascript -l JavaScript -e "$exchange" "$destination" "$staged" >/dev/null || exit 1
        else
            /bin/mv -- "$staged" "$destination" || exit 1
        fi
        exit 0
        """
    /// JXA: replaceItemAtURLWithItemAtURL…(argv[0], argv[1], no backup, options 0); throws on failure (exit ≠ 0).
    static let exchange: String = { fatalError("not implemented") }()
    static func swap(_ staged: URL, into destination: URL, by administrator: any Administrator) -> InstallOutcome
    // .ran(0) → .installed; .ran(_) → .failed(applicationsFolderNotChanged); .cancelled → .cancelled; .failed → .failed(cannotWrite…)
}
```

```swift
// MARK: LauncherUI

/// The card as one rounded group, text left and its button right (R5); downloading adds the bar under the row (R7).
/// Measurements, button style and the bar's placement come from Figma node 2143-1845 at implementation (O1).
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void
    let cancel: () -> Void
    var body: some View { fatalError("not implemented") }
    // .available(v):        Text(Copy.updateAvailable(v))   · Button(Copy.updateNowButton, action: updateNow)
    // .downloading(v, p):   Text(Copy.updateDownloading(v)) · Button(Copy.cancelButton, action: cancel); ProgressView(value: p)
    // .installing(v):       Text(Copy.updateInstalling(v))
    // .failed:              Text(Copy.updateFailed)         · Button(Copy.tryAgainButton, action: updateNow)
}

// SettingsShell: init(launcher:updater:quit:). The refit observation gains the card's layout, which changes only
// when the card appears, goes or changes rows (never per progress push), so the window grows downward under a pinned
// top edge when the card appears (E10, R5 "the rest of the window moves down").
//   Observations({ (launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn,
//                   launcher.screenRecordingHint, updater?.card?.layout) })
// TintedButtonStyle renders a disabled button greyed: its label view reads @Environment(\.isEnabled).

// Copy (LauncherCore), asserted by CopyTests:
//   updateAvailable(v) = "Version \(v) is available"     updateNowButton = "Update now"
//   updateDownloading(v) = "Downloading version \(v)…"   cancelButton = "Cancel"
//   updateInstalling(v) = "Installing version \(v)…"
//   updateFailed = "The update couldn't be installed."   tryAgainButton = "Try again"
```

**Module map.**

| Module | Owns | New / changed |
|---|---|---|
| `LauncherCore` | `Version`, `Release` + `newerVersion`, `InstalledRelease`, `UpdateCard`, `UpdateEvent`, `Updater`, ports `ReleaseList` and `UpdateInstaller`, `Copy` strings | new model; `Launcher` (+1 init param, 2 edges), `Lifecycle` (+1 init param, 2 reads) |
| `LauncherPlatform` | `GitHubReleases` (network), `ApplicationsUpdater` (sequence + LaunchServices), `BundleInstall.unpack/admits`, `CodeSignature.developerIDSigner/isGenuine` + `Signer`, atomic `PrivilegedInstall`, `ApplicationsInstaller.put`, `ThisCopy.version/macOS` | 2 new files; frameworks gain URL Loading (1 file) and AppleArchive (1 file) |
| `LauncherUI` | `UpdateCardView`, card group, disabled Quit, refit | `SettingsShell` gains `updater` |
| app target | `makeUpdater` gate | composition only |
| tests | `InMemoryReleaseList`, `InMemoryUpdateInstaller`; `OneProcess(running:)`; update scenarios; platform tests with a local listener | below |

**Source policy (`SourcePolicyTests`).** These changes follow the plan 002/006/021 pattern:
- **Moves from `banned` to confined:** `URLSession` → `GitHubReleases.swift` ("the update check and its download are the one network path").
- **New confinements:**
  - `http` → `GitHubReleases.swift`. This lowercase substring catches every web address and every `http…` session setting; no source mentions it today.
  - `createsNewApplicationInstance` → `ApplicationsUpdater.swift` ("only an update opens a second copy of itself").
  - `AppleArchive`, `ArchiveStream`, `removexattr` and `itemReplacementDirectory` → `BundleInstall.swift`. This also fixes the unused `quarantinePropertiesKey` row and the unconfined staging folder (`why.md` Contradictions).
  - `osascript` → `PrivilegedInstall.swift`.
- **Removed:** the `/bin/rm` confinement, now unused, becomes a ban.
- **Still banned:** `import Network`, `NWConnection`, `CFSocket`, `CFStream`, `.write(to:`, `FileHandle(forWriting`, `createFile(atPath`, `Timer`, `asyncAfter`, `Task.sleep`, logging.
- **Newly banned, the obvious bypasses (Avoid 3):** `NSURLConnection`, `NSURLDownload`, `CFHTTP`, `import WebKit`, `WKWebView`, `curl`, `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`, `NSAppleScript`. Do not ban `Process(`: the scan matches substrings, and `hasProcess(` and `buildOfThisProcess(` would trip it.
- **A self-check test** pins the remaining network bans by name, so a later edit cannot drop them quietly.
- **Confinements are by file name, and the scan reads comments.** So Core doc comments say "the network file", never the token.

**Testing seam.** Every R1, R2 and R4-R13 scenario runs at `LifecycleWorld`/`OneProcess`, synchronously. A process there is a real `Lifecycle`, `Launcher` and `Updater` over in-memory adapters, driven by the same intents the shell sends.
- `launch(_:others:running:)` takes `.release("1.0.0")` or `.development` and builds the `Updater` the way `makeUpdater` does.
- Handles for every boundary a test cannot wait for or provoke:

  | Boundary | Handle |
  |---|---|
  | The list's answer | `releases.deliver(_:)`, `fail()`, held by default, or `answersAtOnce`; `fetches` counts requests |
  | The download's progress | `updates.progress(_:)` |
  | Download end | `finishDownload()` |
  | Install outcome | `swapIn()`, which fires `onInstalled` and logs `"swap"`; `decline()`; `fail()` |
  | A late event after a cancel | `deliverLate(_:)` |
  | `cancelDownload` | `cancels` count |
  | LaunchServices' answer | `answerOpen(started:)` |
  | The old copy's exit | the existing `letExit` |

  "No network request" is `releases.fetches == 0 && updates.requests.isEmpty`.
- **Kill-anywhere:** the update's only lasting effect is the swap. The test asserts the suite, the login item and the permissions are identical in every snapshot. A restored Mac opened by hand converges to the uncrashed end, which is either version (Preserve 6).
- **Pure tests:** `Version`, `Release.newerVersion` and `InstalledRelease.init?`.
- **Platform tests, real behaviour:**
  - `GitHubReleases`, against a 127.0.0.1 listener in the test target:
    - the exact request line (no `?`) and the exact header set;
    - no `Cookie` on a second request after a `Set-Cookie`;
    - `parse` over fixtures shaped like G3 (draft, pre-release, `state: open`, a foreign URL, bad names, two valid releases);
    - a stall with `stall: 0.3` fails, and a trickle slower overall but never idle succeeds (N3);
    - a cancel gives no event, and a wrong length fails.
  - `ApplicationsUpdater` and `BundleInstall`, over temp folders with `TestAdministrator` and `BundleFixture`:
    - crafted archives (`..`, absolute path, an escaping symlink, two top-level items) fail with nothing written outside staging;
    - an ad-hoc bundle fails `isGenuine` and the administrator is never called;
    - the atomic script runs with metacharacter paths;
    - a cancelled prompt gives `.declined`, with staging discarded each time.
  - `CodeSignature`:
    - `developerIDSigner() == nil` in the test runner;
    - the positive `isGenuine` runs against a stapled notarised app found on the machine (skipped when none), with the signer read from it;
    - an unstapled notarised app fails offline.
- **Manual:**
  - a real update between two published releases (R14, R9, and R10's login item and TCC grants: O2, O3);
  - the administrator prompt on a standard account, which runs osascript as root (R11);
  - a restart during the swap (R13);
  - `nettop` or Little Snitch on the check (R3);
  - the card against Figma (R5).

**Requirement trace.**

| R | Where it holds |
|---|---|
| R1 | `Launcher.openedByHand` edge only from `.closed`; fetch after the window opens; ticket drop in `checked`; `windowClosed` → idle |
| R2 | No `Updater` without `Signer` (no arguments: O7) and `InstalledRelease` (`.installed`); a login start never opens the window |
| R3 | `GitHubReleases` session and headers; no query; in-memory download; scan confinements; header test |
| R4 | `GitHubReleases.parse` (draft, pre-release, no app, no minimum) + `Release.newerVersion` (higher, meets macOS, highest) + `Version` |
| R5 | `UpdateCardView` first in the `VStack`; refit on the card's layout |
| R6 | Failure delivers `[]` → idle; the next opening checks |
| R7 | `.downloading` with bar and *Cancel*; `cancel()` → `.available`; `.downloaded` → `.installing` |
| R8 | `CodeSignature.isGenuine` (team, notarized offline, identifier, version, minimum) → `.failed` |
| R9 | `put` swap → `openNewVersion(createsNewApplicationInstance)` → the new process's `.runWithWindow` stops the old and opens its window → `windowOpened` checks |
| R10 | Same path, identifier and team (V5); no login-item or defaults call; not a first run |
| R11 | Verify before `put`; the prompt only in `PrivilegedInstall`; `.declined` → `.available` |
| R12 | Download, stall, length, unpack, verify or swap failure → `.failed`; *Try again* = `updateNow()`; nothing on disk |
| R13 | `windowClosed` cancels downloads, not installs; `isInstalling` gates `quit()` and `shouldEnd(.other)`; `.system` always ends; atomic swap on both paths |
| R14 | `release.sh` below; the asset-name contract; the API version header |

**The release process (R14), `Scripts/release.sh` changes:**

```sh
# Preflight (before building): gh auth status; a clean worktree whose HEAD is on origin; VERSION from
# Config/Version.xcconfig matches ^[0-9]+(\.[0-9]+)*$, has no tag v$VERSION, and is above every v* tag (sort -V)
# and every release, drafts included (gh release list).
# ... archive, export, verify, notarise and staple the app: as today ...
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
MIN_MACOS=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")
# both must match the numeric pattern, and VERSION must equal the preflight's
AAR="$OUT/$APP_NAME-$VERSION-macOS-$MIN_MACOS.aar"
aa archive -d "$OUT/export" -subdir "$APP_NAME.app" -exclude-field uid,gid,xat,acl,flg -o "$AAR"
# Self-check, as an older version will: unpack, then codesign --verify --strict --deep, stapler validate,
# and the identifier and TeamIdentifier from codesign -dv.
# ... disk image: as today (stays TrackpadLauncher.dmg, so .../releases/latest/download/TrackpadLauncher.dmg is stable) ...
gh release create "v$VERSION" "$DMG" "$AAR" --draft --target "$(git rev-parse HEAD)" \
  --title "Trackpad Launcher $VERSION" --notes "Requires macOS $MIN_MACOS or later."
echo "Draft v$VERSION created. Publish with: gh release edit v$VERSION --draft=false --latest"
```

`project.yml` sets `LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)`, so the declared minimum has one source. A rejected notarisation fails at `stapler staple` under `set -e` (O9).

**Docs.**
- **`docs/architecture.md`:**
  - **Shape:** three models. `Updater` exists only in a release build in /Applications. `Launcher` reports its window's openings and closings to it, `Lifecycle` reads `isInstalling`, and the new version arrives as an ordinary opening by hand.
  - **Frameworks:** URL Loading in one file and AppleArchive in one file.
  - **Concurrency:** the push list gains the list's answer, the download's progress and outcome, and LaunchServices' answer. "Time passes only on Core Animation's clock" gains its one exception: a request's own idle timeout, 30 s, reset by every byte.
  - **Privacy:** the network exception exactly as R1-R3 state it, naming the one file. Files written gain "a newer version unpacked into a staging folder beside /Applications and swapped in when the user presses *Update now*". The download stays in memory.
  - **Distribution:** GitHub releases tagged `v<version>` carry the disk image and `TrackpadLauncher-<version>-macOS-<minimum>.aar`. That asset name is a contract with every shipped version, and a release is a draft until published.
- **`docs/product-overview.md`:**
  - "0 network calls" becomes "no network calls except one exception". The settings window reads the public release list when it opens, and *Update now* downloads the new version. Nothing about the user or the Mac is sent.
  - "only the *Quit Trackpad Launcher* button ... stops it" gains: "; an update also stops the old version and opens the new one".
- **`docs/domain-model.md`:**
  - New entries: *Update check*, *Newer version* and *Update card*.
  - Edits:
    - *Settings window*: the card is the first group while a newer version is known.
    - *Quit Trackpad Launcher*: disabled while the card shows "Installing…".
    - *Development build*: never checks.
    - *Opened by hand*: includes an update opening the new version.

### Synthesis decision

### Tradeoffs accepted

- We accept the whole archive in memory, a few MB, in exchange for nothing on disk until it has all arrived. A Quit, crash or logout mid-download then leaves nothing to delete, and R3/R12's deletion rule holds without a caller remembering it.
- We accept that an old copy whose new version starts and then dies before stopping it shows "Installing…" with Quit disabled until a logout or a force quit. In exchange, the update has no hand-over path of its own: the newer version arrives through the existing opened-by-hand route (Preserve 1-2), the old copy keeps its gestures to the end, and `Updater` never reaches into `Lifecycle`.
- We accept that after a successful swap, if macOS refuses to open the new version, the card reads "couldn't be installed" although /Applications holds the new version. *Try again* converges with a same-version swap and a second open.
- We accept running `osascript`'s JavaScript bridge as root in the administrator path, and changing the move's script too. In exchange, one atomic exchange closes E8's two-rename gap for both flows, as R13's restart scenario requires.
- We accept not touching the login item on an update (O2). In exchange, no "login item added" notice appears on every release. A manual check gates this.
- We accept the asset name `TrackpadLauncher-<v>-macOS-<min>.aar` and the repository path as a permanent contract with every shipped version. In exchange, the version and minimum macOS are machine-written from the app's own Info.plist and parsed from the one request R3 allows.
- We accept that only the 30 newest releases are seen, because R3 forbids `?per_page`.
- We accept a request's own idle timeout as the one deadline that is not an animation, against the letter "time passes only on Core Animation's clock". In exchange, the app has no timer of its own (N3).
- We accept that only a real Developer ID build in /Applications can exercise the network path by hand. Development builds are covered by the local-listener platform tests.
- We accept a staging folder left in the system's temporary items after a crash mid-install, which macOS clears. In exchange, there is no startup sweep of our own.
- We accept `Updater` being referenced by four holders: the composition root, `Lifecycle`, `Launcher` and the shell. This is the `StartAtLogin` precedent, and in exchange each holder uses one narrow part.

### Alternatives considered

- **The install as a `Lifecycle` stage, with check and download in `Launcher`.** This splits one state machine across two models by phase (temporal decomposition). The card would derive from two sources, and the ticket logic would be duplicated. The interface grows on both models, and nothing gets deeper.
- **Fold the update into `Launcher`.** `Launcher` would have to learn `Build`, `Placement`, versions and quit policy, which is exactly what the plan 021 split prevents (Avoid 5). It exposes process concerns to every `Launcher` caller.
- **End-after-open: the old copy ends itself once LaunchServices answers, like the mover.** This bounds the "Installing…" state, but it needs an `Updater`→`Lifecycle` end hook (a two-phase-initialised closure or a public "end" intent). Leaving the old copy to be stopped reuses a route that already exists and keeps gestures until the end. This was the close second.
- **A port per step (list, download, verify, unpack, swap, open).** This interface is shallow: the model would sequence platform steps and carry a downloaded file's path across ports. Every caller would then have to remember to delete it, and the R11 "verify before prompt" order would become model coordination rather than one adapter's invariant.
- **Asset format: the DMG.** Verifying the DMG's signature before mounting is the strongest pre-parse guarantee. But it needs an `hdiutil` child process, leaves mount state behind after a crash, and an unprobed `notarized` check on a disk image. **A ditto zip** needs a child process with unknown traversal behaviour. The Apple Archive won: in-process, probed whole (V4), with our own entry filter.
- **Minimum macOS in the release body, a manifest asset, or `/releases/latest`.** The body is human-edited and fragile. A manifest is a second request, which R3 forbids. `latest` ignores the minimum macOS (G5).
- **Sparkle.** It brings its own network code outside the scan, dialogs (a non-goal), an appcast to host and XPC installers. It is far wider than the one narrow exception the product owner granted.

### Open questions and risks

- **O2.** Does the `SMAppService.mainApp` login item survive a same-path, same-team replacement? If the first real update shows it lost, should the update adopt the move's `suspend()`/`resume()` handover, accepting a notice per update? The fallback is one effect inserted before `openNewVersion`.
- **O3.** Do the Accessibility and Screen Recording grants survive in practice? V5 says yes on paper. A loss could not be re-asked under R10, so should the release checklist require a hand check on the first real update?
- **The atomic administrator swap.** Does `osascript -l JavaScript` run as root through `AuthorizationExecuteWithPrivileges` without any prompt or TCC hop? It was probed only unprivileged (R-5). Is changing the move's script in the same plan acceptable, or should the move keep its two `mv`s until this is hand-checked?
- **Unprobed APIs to confirm in the first platform slice:**
  - `kSecCSNoNetworkAccess` together with `notarized` (stapled passes, unstapled fails);
  - AppleArchive's custom byte stream over in-memory `Data`, and its selection hook. V4 probed only a file stream. The fallback writes the archive into the staging folder first, which brings back a file for R12 to delete.
- **Publishing.** Should `release.sh` stop at a draft, as proposed, so the developer can inspect the assets before every older copy sees them? Or should it publish in the same command?
- **Immutable releases.** Should the repository turn on GitHub's immutable releases (G3 `immutable`), so a published archive can never be swapped afterwards?
- **The card's look (O1).** Should Figma node 2143-1845's downloading, installing and failed states be confirmed before the UI slice, or derived from the available state?
- **The "Installing…" state when the new version dies.** Should it be bounded? Doing so would need either the end-after-open hook or a push that the new process sends.

### Next implementation step

Write `Version`, `Release.newerVersion` and `InstalledRelease` with their pure tests. Then build the `Updater` model, its two ports and their in-memory adapters, and `OneProcess(running:)`, and drive the R1, R2, R4-R7 and R11-R13 scenarios at `LifecycleWorld`.
