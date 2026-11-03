## Design

### Problem

Trackpad Launcher must learn, once per opening of its settings window, that a newer release exists, offer it in an update card, and on *Update now* download it, prove it genuine, swap it into /Applications in the running copy's own place and hand over to it, all without a timer, without a second network path, and without disturbing the two models that already own the process and the window. The shape is non-obvious because the update straddles both models: the trigger is the window's closed→open transition, which only `Launcher.window` knows (E3); the quit policy, the ending of the process and the relaunch belong to `Lifecycle` (E5, E6); and "release build in /Applications", the gate for every network request, is held by no stored value today (E2). Constraints the design honours: the no-network rule gains exactly one confined exception (why.md Change 1, Preserve 3); every asynchronous deliverer sits behind a port with a real and an in-memory adapter so model tests stay synchronous (E4, Preserve 11); framework and wire types never cross a port; the swap is whole-or-nothing, as the first change anywhere (Preserve 5); the new version arrives as an ordinary opening by hand from /Applications that stops every other copy (Preserve 1, R-4); no handshake between versions (Preserve 2); logout is never held up (Preserve 12); the login item is handed over through `StartAtLogin`'s own key and never spends a first run (Preserve 9); the existing move never replaces the running bundle and its tests prove nothing about a self-replace (Avoid 6); and the release pipeline today publishes nothing (E13).

### Usage (caller's view)

**README.** An installed release build owns one `Updater`, a third `@MainActor @Observable` model in `LauncherCore`. It is built by the composition root only when the process has a Developer ID team to pin its genuineness check to (`CodeSignature.releaseIdentityOfThisProcess()` is nil for a development build, `--as-release-build` included), and `Lifecycle` hands it to the resident `Launcher` only when the copy lies in /Applications. `Launcher` tells it `windowOpened()` on every closed→open transition and `windowClosed()` on every close; the view renders `launcher.updater?.card` as the window's first group and sends `updateNow()` and `cancelDownload()`; `Lifecycle` reads `isInstalling` for the quit policy and ends the process when the Updater says the new copy is running. Everything between those five calls (one check per opening, choosing the offer, the download with progress and the 30 s stall rule, genuineness, the atomic swap with the administrator prompt, the login-item handover, opening the new copy) is the Updater's and its two ports', `Releases` (the public release list and one download) and `UpdateInstaller` (unpack, verify, swap, open).

Composition root (the only place the gate's inputs exist):

```swift
// TrackpadLauncherApp.applicationWillFinishLaunching
let location = ThisCopy.location()
let placement = Placement(build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)
let startAtLogin = StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)
// nil for a development build: no team to pin the genuineness check to, so no Updater can exist (R2).
let updater = CodeSignature.releaseIdentityOfThisProcess().map { running in
    Updater(
        running: running, macOS: ThisCopy.macOSVersion(),
        releases: GitHubReleases(), installer: SystemUpdateInstaller(location: location, running: running),
        startAtLogin: startAtLogin)
}
lifecycle = Lifecycle(
    placement: placement, updater: updater, copies: SystemRunningCopies(),
    installer: ApplicationsInstaller(location: location), startAtLogin: startAtLogin,
    makeResident: { [unowned self] updater in makeResident(startAtLogin, updater: updater) })
```

The model side, two lines in `Launcher` (the only writer of `window`):

```swift
public func openedByHand() {
    // ... first-run work, openings += 1 ...
    let wasClosed = window == .closed
    window = .open(request: openings)
    resolveRows()
    scanner.scan()
    if wasClosed { updater?.windowOpened() }   // R1: one check per opening, none on a re-front
}

public func closeWindow() {
    window = .closed
    updater?.windowClosed()                     // R1, R13: a check is dropped, a download cancelled, an install goes on
}
```

The view, first group of `SettingsView`:

```swift
if let updater = launcher.updater, let card = updater.card {
    UpdateCardView(card: card, updateNow: { updater.updateNow() }, cancel: { updater.cancelDownload() })
}
FormGroup { /* gesture rows, as today */ }
// ...
Button(Copy.quitButton, action: actions.quit)
    .buttonStyle(TintedButtonStyle(tint: .red))
    .disabled(launcher.updater?.isInstalling == true)   // R13
```

A requirement scenario at the high seam (R7 *Cancelling a download*, then R13 *Closing the window mid-download*):

```swift
@Test func cancellingADownloadReturnsTheCardToAvailableWithNothingChanged() {
    let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    let process = world.launch(.byHand, placement: .installed, running: .version("1.0.0"))
    #expect(process.releases.fetchCount == 1)
    process.releases.deliver([.release("1.1.0", macOS: "26.0")])
    #expect(process.card == UpdateCard(version: "1.1.0", phase: .available))

    process.updateNow()
    process.releases.report(progress: 0.4)
    #expect(process.card == UpdateCard(version: "1.1.0", phase: .downloading(progress: 0.4)))

    process.cancelDownload()
    #expect(process.releases.cancelledDownloads == 1)
    #expect(process.card == UpdateCard(version: "1.1.0", phase: .available))
    #expect(process.installer.installCalls == 0)
    process.tap(1)
    #expect(process.system.broughtToFront == [world.mac.app("Arc")])

    process.updateNow()
    process.closeWindow()                               // R13
    #expect(process.releases.cancelledDownloads == 2)
    #expect(process.card == nil)
    process.openAgain(.byHand)
    #expect(process.releases.fetchCount == 2)           // the next opening checks again
    process.releases.deliver([.release("1.1.0", macOS: "26.0")])
    #expect(process.card == UpdateCard(version: "1.1.0", phase: .available))
}
```

### Shape

**Data first.** A `Version` is a non-empty list of integers compared part by part (R4 *Versions compare by number*); a missing part is 0, so `1.0` equals `1.0.0`. `ReleaseIdentity` is this process as a release: version, bundle identifier and Developer ID team, read once at start from the code signature (V2, O8), so a lazy read after the swap (R-6) never happens; a development build has no team and so no identity, which is what makes an `Updater` for it unrepresentable (per **type-system-discipline**, O7 decided: the hand-testing hook never enables updates). A `Release` is a published full release the app can act on: version, minimum macOS, download URL and size; drafts, pre-releases and releases without a usable app asset never become one, because the adapter's parse rejects them (per **boundary-discipline**). Both the version and the minimum macOS come from one declaration the release process writes from the built app's own Info.plist and the app reads with one rule: the asset name `TrackpadLauncher-<version>-macOS<minimum>.aar` (`Release.Asset`, in Core, shared by the parse, the tests and mirrored by `release.sh`; O5 and O6 decided). The card is `UpdateCard { version, phase }` with `phase` a sum type (`available`, `downloading(progress:)`, `installing`, `failed`): the version is the same through every phase, so it sits outside the phase, and *Try again* needs nothing the failed phase does not carry (per **model-the-domain**). The Updater's own state is a private `Stage` machine (`idle`, `checking`, `offered(Release)`, `downloading(Release, progress)`, `installing(Release)`, `failed(Release)`); the card is derived from it, never stored (single source of truth).

**Ownership (question 1).** Three models now: `Lifecycle` (the process), `Launcher` (gestures, settings, the window), `Updater` (the update). `Updater` knows nothing of `Placement`, `Lifecycle`, quitting or sensing; `Launcher` learns one collaborator it pokes on the two window transitions, as it already pokes `StartAtLogin`; `Lifecycle` learns one fact (`isInstalling`) and one push (`onReplaced`, which it answers with `end()`). The gate "release build in /Applications" is split across its two natural owners: the *build* half is structural (no identity, no `Updater`), the *placement* half is `Lifecycle`'s one line, `placement == .installed ? updater : nil`, so the R2 scenarios run at the `Lifecycle` seam. A resident outside /Applications, a copy that only asks to move, a login start and a re-front never reach `windowOpened()` at all (E3, Route table); nothing has to remember not to check.

**The check (question 3).** `windowOpened()` starts one fetch only from `idle`; `offered`, `failed` and `checking` cannot be present at an opening because `windowClosed()` resets them, and `downloading` cannot because close cancels it; only `installing` survives a close, and an opening during it shows the install and checks nothing. `windowClosed()` cancels the fetch at the port, so its result never arrives; the stage guard on every completion is the second line of defence the codebase already uses (E4). `NewerVersion.choose` is the pure policy for R4 (highest release above the running version whose minimum this Mac meets). A failed fetch is `idle`, which is "no card and no error" (R6).

**The request and the download (questions 4, 5).** `GitHubReleases` is the one file that names the network API. One ephemeral session, cookies refused, no cache, `timeoutIntervalForRequest` 30 s: that idle timer is the request's own and resets on every byte (N3), which is R12's 30-second rule with no timer of ours. The fetch is `GET …/repos/domasgru/trackpad-launcher/releases` with no query string (the default newest 30, G4), a constant `User-Agent: TrackpadLauncher` (G2: an absent header is refused; a constant one names nothing), a constant `Accept-Language: en` and `Accept: application/vnd.github+json` (N1, N2). The download follows GitHub's one redirect with the same headers (G6, N2), pushes progress as a fraction of the asset's size, and lands as a temporary file that `BundleInstall.keep(download:)` moves into the update's own temp folder: `DownloadedUpdate` names it. Cancel deletes it; nothing is pushed after cancel. The adapter's test seam is its init (`endpoint`, `stall`), so a local listener on 127.0.0.1 asserts the exact headers and the stall (tests are not scanned).

**Genuineness and installing (questions 6, 7).** `SystemUpdateInstaller.install` runs off the main actor and does, in order: unpack the archive in-process (`UpdateArchive`, the one file for the AppleArchive API, V4) into an item-replacement folder on the destination's volume; verify with `CodeSignature.isGenuine(_:team:identifier:version:)`, a new requirement `anchor apple generic and certificate leaf[subject.OU] = "<team>" and identifier "<id>" and notarized` checked strictly with nested code and resources (V1), plus the signing information's `CFBundleShortVersionString` equal to the offered version (V2, R8); clear quarantine per item (Preserve 10, N5); then the move's own writability check and swap (`ApplicationsInstaller.swap`, now a shared internal static over any staged source). Unprivileged, the swap is `replaceItemAt`, one rename (R-1). Privileged, `PrivilegedInstall.script` becomes one atomic exchange through `/usr/bin/osascript -l JavaScript` calling Foundation's replace as root, paths as `"$n"` arguments never interpolated (R-5), with the two-`mv` form kept only for a missing destination, which the probe showed crashes the exchange; the move adopts the same script, so one script, one gap closed (O4 decided, R13 *Restart while the new version is put in place*). The prompt comes only here, after the download is verified (R11). The archive is deleted on every outcome, the staged copy on every outcome but `.installed` (R3, R12). `openReplacedCopy` is a second port method, so the model's effect order is visible and the kill-anywhere tests can snapshot between the swap and the open: `NSWorkspace.openApplication(at: location.running)` with `createsNewApplicationInstance = true` and `activates = true`, whose completion is the push (R-3: the default configuration would only reopen the old process). The new process is an opening by hand from /Applications → `.runWithWindow`: it force-stops the old one, waits, senses, opens its window, and that first opening checks again (R-4, R9). The old process keeps its gestures until macOS reports the new one launched, then ends itself (the newcomer stops it anyway if it is still alive; ending on the push means a newcomer that dies at start never leaves an old process with Quit disabled forever). A launch error puts the card in `failed`; *Try again* downloads and swaps again, convergently (per **make-operations-idempotent**: a swap over an already-swapped destination is the same swap).

**Carry-over (question 8).** Settings are the shared defaults domain; the settings record ignores unknown keys both ways. The login item is handed over as the move does it: `startAtLogin.suspend()` between the swap and the open, and the new copy's first `openedByHand()` resumes it (E9); a failed open resumes it in the old process so nothing is lost. The TCC grants follow the designated requirement, which names team and identifier but no version (V5). No first run is spent: the record exists. O2 and O3 stay manual checks on the first real release.

**Quit and close (question 9).** `Lifecycle.shouldEnd`: in `.resident`, an `.other` request is refused while the window is open *or an install is in flight*, closing the window if open; `.system` always ends. `Lifecycle.quit()` is a no-op while installing and otherwise calls `updater?.windowClosed()` before ending, so a download is cancelled with nothing changed (R13). ⌘Q and the close button already go through `closeWindow()`.

**The card (question 10).** `UpdateCardView` is a `FormGroup` with the text left and the button right in one row, plus a linear `ProgressView` under it in the downloading phase; it is the first group whenever `card` is non-nil and absent otherwise (R5). The shell's refit tuple gains `launcher.updater?.card?.phase` (E10), and `TintedButtonStyle` reads `isEnabled` to dim the disabled Quit. Strings live in `Copy` and are asserted verbatim.

**Ports, adapters, policy (question 11).** Two new ports, each with exactly two adapters: `Releases` (`GitHubReleases` / `InMemoryReleases`) and `UpdateInstaller` (`SystemUpdateInstaller` / `InMemoryUpdateInstaller`). Both deliver through `@escaping @MainActor` completions and a settable progress push, and the in-memory ones hold every completion until the test releases it, so the model's tests stay synchronous. `SourcePolicyTests`: `URLSession` moves from `banned` to confined in `GitHubReleases.swift`; `import Network`, `NWConnection`, `CFSocket`, `CFStream` stay banned; new bans close the bypasses (`URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier`, `String(contentsOf:`, `Process(`, `NSTask`, `posix_spawn`); `Data(contentsOf:` is confined to `Apps.swift`, its one local-file reader; new confinements: `AppleArchive`/`ArchiveStream` → `UpdateArchive.swift`, `createsNewApplicationInstance` → `SystemUpdateInstaller.swift`, `osascript` → `PrivilegedInstall.swift`, `itemReplacementDirectory` and `removexattr` → `BundleInstall.swift` (replacing the dead `quarantinePropertiesKey` row and naming the staging folder, the two contradictions in why.md). Core doc comments never spell a confined token. Docs: `architecture.md` Shape names the third model; its privacy line reads "no network code except the update check and the download the user starts, confined to one file"; its files-written list gains "the downloaded update and its unpacked copy, until installed, cancelled or failed"; Distribution gains the GitHub release and the asset's name. `product-overview.md` line 8 names the exception and the second stopper. The glossary gains *Update check*, *Newer version*, *Update card* and amends *Quit Trackpad Launcher* and *Development build*.

**The release process (question 12).** `release.sh` reads `CFBundleShortVersionString` and `LSMinimumSystemVersion` from the exported app's Info.plist, refuses to run unless the version is higher than every tag the repository already has and the tree is clean on `main`, packs the stapled app with `aa archive` as `TrackpadLauncher-<version>-macOS<minimum>.aar` (the asset the app downloads, V4) beside the DMG (the human download), and publishes `gh release create v<version>` with both assets, not draft, not pre-release, so every older copy's next opening finds it (R14). `--no-publish` builds everything and stops.

**Testing seams (question 13).** The one high seam is `LifecycleWorld`/`OneProcess`, which now builds the `Updater` for a process given a `running: ReleaseIdentity?` and exposes `releases` and `installer`. Handles for everything a test cannot wait for or provoke: `InMemoryReleases.deliver/failFetch/report(progress:)/finishDownload/failDownload` and its `cancelledFetches/cancelledDownloads` counts; `InMemoryUpdateInstaller.release(_:)` with `onInstalled` (the moment /Applications changed) and `releaseOpen(launched:)`; the `EffectLog` gains `fetch`, `download`, `installUpdate`, `unregister`, `openReplacedCopy`, pinning the order and feeding kill-anywhere convergence in the move's style. Pure: `VersionTests`, `NewerVersionTests`, `ReleaseAssetTests`. Platform: `GitHubReleasesTests` (headers, no query, no cookie, parse fixtures shaped like G3, stall, progress, cancel deletes), `UpdateArchiveTests`, `SystemUpdateInstallerTests` over temp folders with `BundleFixture` (negative genuineness, writable swap, the real exchange script unprivileged through `TestAdministrator` with metacharacter paths, cancel leaves everything, archive deleted on every outcome), `CodeSignatureTests` (positive only against a notarised Developer ID app found on the machine, team read from it). Manual: one real update between two published releases, the login item and the grants afterwards, the administrator prompt on a standard account, a restart during the swap, `nettop`, the card against Figma.

**Interface depth.** Five intents and one observable value hide the whole flow; the ports have three and two methods; nothing about GitHub, URLs' redirects, archives, requirements, authorization or LaunchServices reaches the model. What stays exposed: the version in the card, and the three handles `Lifecycle` needs. Deliberately not done: no retries, no deadline on the exchange, no second request for a manifest, no digest check (the signature is the authenticity check), no version shown for the running copy.

```swift
// LauncherCore: Version.swift

/// A version compared numerically part by part: 1.10.0 is above 1.9.0. A missing part is 0, so "1.0" equals "1.0.0".
public struct Version: Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    /// Non-empty; every part non-negative.
    public let parts: [Int]
    /// nil for anything that is not digits separated by dots ("1.1.0-beta", "", "v1").
    public init?(_ text: String)
    public var description: String { parts.map(String.init).joined(separator: ".") }
    public static func < (a: Version, b: Version) -> Bool   // compare padded with zeros
}

/// The Developer ID team an app is signed under. Branded: never interchangeable with a bundle identifier.
public struct TeamID: Hashable, Sendable { public let rawValue: String }

/// This process as a release: read once at start from its code signature. Only a Developer ID build has one, so a
/// development build (the hand-testing argument included) can never own an `Updater`.
public struct ReleaseIdentity: Equatable, Sendable {
    public let version: Version
    public let bundleID: BundleID
    public let team: TeamID
}

// LauncherCore: Release.swift

/// A published full release this copy could install: the adapter admits only non-draft, non-pre-release entries whose
/// app asset declares both numbers (`Asset`). Everything else never becomes a `Release`.
public struct Release: Equatable, Sendable {
    public let version: Version
    public let minimumMacOS: Version
    /// The asset's download address, followed through the host's redirect by the adapter.
    public let download: URL
    /// The asset's size in bytes, for progress when the server does not say.
    public let size: Int

    /// The one declaration a release makes, written by the release process from the built app's Info.plist and read
    /// here: `TrackpadLauncher-<version>-macOS<minimum>.aar`.
    public enum Asset {
        public static func name(version: Version, minimumMacOS: Version) -> String
        /// nil for any other name, so a release with no declared minimum or no app does not count (R4).
        public static func parse(_ name: String) -> (version: Version, minimumMacOS: Version)?
    }
}

/// R4, pure: the highest release above `running` whose minimum this Mac meets; nil when none.
public enum NewerVersion {
    public static func choose(from releases: [Release], above running: Version, macOS: Version) -> Release? {
        releases.filter { $0.version > running && $0.minimumMacOS <= macOS }.max { $0.version < $1.version }
    }
}

/// A downloaded release archive, kept in the update's own temporary folder until installed, cancelled or failed.
public struct DownloadedUpdate: Equatable, Sendable {
    public let archive: URL
}

// LauncherCore: UpdateCard.swift

/// What the settings window shows as its first group while a newer version is known (R5, R7, R12).
public struct UpdateCard: Equatable, Sendable {
    public let version: Version
    public let phase: Phase

    public enum Phase: Equatable, Sendable {
        /// "Version <v> is available", Update now.
        case available
        /// "Downloading version <v>…", a bar at `progress` (0...1), Cancel.
        case downloading(progress: Double)
        /// "Installing version <v>…", nothing else.
        case installing
        /// "The update couldn't be installed.", Try again.
        case failed
    }
}

// LauncherCore: Ports.swift (additions)

public enum FetchOutcome: Equatable, Sendable {
    case found([Release])
    /// Offline, no answer, an unreadable answer: all the same to the model (R6).
    case failed
}

public enum DownloadOutcome: Equatable, Sendable {
    case downloaded(DownloadedUpdate)
    /// Any error, including thirty seconds without a byte (R12). The file is gone.
    case failed
}

/// The public release list and one download from it. Real: GitHubReleases. Test: InMemoryReleases.
@MainActor public protocol Releases: AnyObject {
    /// One request for the newest published releases, carrying nothing about the user, the Mac or this version (R3).
    /// `done` runs once, on the main actor; never after `cancelFetch()`. A second `fetch` while one runs replaces it.
    func fetch(then done: @escaping @MainActor (FetchOutcome) -> Void)
    /// Stops a fetch in flight; nothing is delivered for it.
    func cancelFetch()
    /// Downloads the release's archive. `progress` is pushed on the main actor as the fraction received, rising;
    /// `done` runs once, on the main actor, never after `cancelDownload()`. The file exists only in `.downloaded`.
    func download(_ release: Release, progress: @escaping @MainActor (Double) -> Void,
                  then done: @escaping @MainActor (DownloadOutcome) -> Void)
    /// Stops the download in flight and deletes what arrived; nothing is delivered for it.
    func cancelDownload()
}

/// Putting a downloaded release in this copy's place and opening it. Real: SystemUpdateInstaller.
/// Test: InMemoryUpdateInstaller.
@MainActor public protocol UpdateInstaller: AnyObject {
    /// Unpacks the archive, installs it only when it is genuine (signed under this copy's team, notarised, this bundle
    /// identifier, exactly `release`'s version: R8), puts it in /Applications in this copy's place in one atomic step
    /// (asking for an administrator only now, when the account cannot write there: R11), with nothing changed on any
    /// other outcome and the archive deleted on every outcome (R3, R12). `done` runs once, on the main actor; a test
    /// holds it. `.failed`'s reason is not shown.
    func install(_ download: DownloadedUpdate, as release: Release,
                 then done: @escaping @MainActor (InstallOutcome) -> Void)
    /// Opens the bundle now at this copy's path as a fresh process, as by hand, never as a reopen of this one (R9).
    /// `launched` runs once, on the main actor, with whether macOS started it.
    func openReplacedCopy(then launched: @escaping @MainActor (Bool) -> Void)
}

// LauncherCore: Updater.swift

/// The update: one check per opening of the settings window, the offer, the download, the install and the handover
/// to the new version. Owns the card. Knows nothing of the process, placement or gestures: `Lifecycle` gives it
/// only to a resident in /Applications, and takes from it only `isInstalling` and `onReplaced`.
@MainActor @Observable
public final class Updater {
    /// Every legal situation of the update, and nothing else. Written only by the intents and the completions.
    private enum Stage: Equatable {
        /// No card, no request in flight. Where every close lands, except from `installing`.
        case idle
        /// A fetch in flight for the opening that started it.
        case checking
        case offered(Release)
        case downloading(Release, progress: Double)
        /// From the download's end until the process ends or the install fails: a close does not touch it.
        case installing(Release)
        case failed(Release)
    }

    private var stage: Stage = .idle
    @ObservationIgnored private let running: ReleaseIdentity
    @ObservationIgnored private let macOS: Version
    @ObservationIgnored private let releases: any Releases
    @ObservationIgnored private let installer: any UpdateInstaller
    @ObservationIgnored private let startAtLogin: StartAtLogin
    /// The new copy is running: end this process. Set by `Lifecycle`.
    @ObservationIgnored public var onReplaced: (@MainActor () -> Void)?

    /// Derived from the stage, never stored.
    public var card: UpdateCard? {
        switch stage {
        case .idle, .checking: nil
        case .offered(let r): UpdateCard(version: r.version, phase: .available)
        case .downloading(let r, let p): UpdateCard(version: r.version, phase: .downloading(progress: p))
        case .installing(let r): UpdateCard(version: r.version, phase: .installing)
        case .failed(let r): UpdateCard(version: r.version, phase: .failed)
        }
    }

    /// R13: Quit is disabled and every ordinary quit only closes the window.
    public var isInstalling: Bool { if case .installing = stage { true } else { false } }

    public init(running: ReleaseIdentity, macOS: Version, releases: any Releases, installer: any UpdateInstaller,
                startAtLogin: StartAtLogin)

    /// The settings window went from closed to open (R1): one check, unless an install is under way.
    public func windowOpened() {
        guard case .idle = stage else { return }
        stage = .checking
        releases.fetch { [unowned self] in checked($0) }
    }

    /// The settings window closed, or Quit is ending the process (R1, R13): a check is dropped and never kept, a
    /// download is cancelled with nothing changed and its file deleted, an offer or a failure is forgotten so the next
    /// opening checks afresh; an install goes on.
    public func windowClosed() {
        switch stage {
        case .checking: releases.cancelFetch(); stage = .idle
        case .downloading: releases.cancelDownload(); stage = .idle
        case .offered, .failed: stage = .idle
        case .idle, .installing: break
        }
    }

    /// Update now, and Try again (R7, R12).
    public func updateNow() {
        switch stage {
        case .offered(let release), .failed(let release):
            stage = .downloading(release, progress: 0)
            releases.download(release, progress: { [unowned self] in progressed($0) }) { [unowned self] in downloaded($0) }
        default: break
        }
    }

    /// Cancel, only in the downloading state (R7).
    public func cancelDownload() {
        guard case .downloading(let release, _) = stage else { return }
        releases.cancelDownload()
        stage = .offered(release)
    }

    private func checked(_ outcome: FetchOutcome) {
        guard case .checking = stage else { return }
        switch outcome {
        case .found(let releases):
            stage = NewerVersion.choose(from: releases, above: running.version, macOS: macOS).map(Stage.offered) ?? .idle
        case .failed: stage = .idle   // R6: silent
        }
    }

    private func progressed(_ fraction: Double) {
        guard case .downloading(let release, _) = stage else { return }
        stage = .downloading(release, progress: fraction)
    }

    private func downloaded(_ outcome: DownloadOutcome) {
        guard case .downloading(let release, _) = stage else { return }
        switch outcome {
        case .downloaded(let file):
            stage = .installing(release)
            installer.install(file, as: release) { [unowned self] in installed($0) }
        case .failed: stage = .failed(release)
        }
    }

    /// The order converges after a kill at any point: the swap inside `install` is the first change anywhere; the
    /// login item is handed over before the new copy opens and handed back if it fails to start; the open is the last
    /// effect and the process ends only on macOS's word that the new one runs.
    private func installed(_ outcome: InstallOutcome) {
        guard case .installing(let release) = stage else { return }
        switch outcome {
        case .cancelled: stage = .offered(release)        // R11: back to available, nothing changed
        case .failed: stage = .failed(release)            // R12, R8
        case .installed:
            startAtLogin.suspend()
            installer.openReplacedCopy { [unowned self] launched in
                guard case .installing = stage else { return }
                if launched { onReplaced?() } else { startAtLogin.resume(); stage = .failed(release) }
            }
        }
    }
}

// LauncherCore: Launcher.swift (changes)

public final class Launcher {
    /// The update, for a resident release build in /Applications; nil everywhere else.
    public let updater: Updater?
    public init(/* as today */, updater: Updater? = nil)
    // openedByHand() and closeWindow() as in Usage.
}

// LauncherCore: Lifecycle.swift (changes)

public final class Lifecycle {
    /// Kept only for a copy inside /Applications (R2): a release build anywhere else never checks.
    @ObservationIgnored private let updater: Updater?
    @ObservationIgnored private let makeResident: @MainActor (Updater?) -> Launcher

    public init(placement: Placement, updater: Updater?, copies: any RunningCopies, installer: any Installer,
                startAtLogin: StartAtLogin, makeResident: @escaping @MainActor (Updater?) -> Launcher) {
        self.updater = placement == .installed ? updater : nil
        // ...
        self.updater?.onReplaced = { [unowned self] in replaced() }
    }

    private func othersExited() {
        guard case .replacingOthers(let opensWindow, let eject) = stage else { return }
        let launcher = makeResident(updater)
        // as today
    }

    public func shouldEnd(_ request: QuitRequest) -> Bool {
        switch stage {
        case .ending, .idle, .replacingOthers, .askingToMove, .moveFailed: return true
        case .moving: return request == .system
        case .resident(let launcher):
            // An ordinary quit only closes the window; while an install runs it does that even with the window closed.
            // A system quit always ends: the swap is atomic, so a logout mid-install leaves either copy whole (R13).
            guard request == .other, launcher.isWindowOpen || updater?.isInstalling == true else { return true }
            if launcher.isWindowOpen { launcher.closeWindow() }
            return false
        }
    }

    /// Disabled while installing (R13). A download in flight is cancelled with nothing changed.
    public func quit() {
        guard case .resident = stage, updater?.isInstalling != true else { return }
        updater?.windowClosed()
        startAtLogin.suspend()
        end()
    }

    /// The new version runs: this one ends, as the mover does. It would be force-stopped anyway (Preserve 1).
    private func replaced() {
        guard case .resident = stage else { return }
        end()
    }
}

// LauncherCore: Copy.swift (additions)

extension Copy {
    public static func updateAvailable(_ version: Version) -> String { "Version \(version) is available" }
    public static let updateNowButton = "Update now"
    public static func downloadingUpdate(_ version: Version) -> String { "Downloading version \(version)…" }
    public static let cancelUpdateButton = "Cancel"
    public static func installingUpdate(_ version: Version) -> String { "Installing version \(version)…" }
    public static let updateFailed = "The update couldn't be installed."
    public static let tryAgainButton = "Try again"
}

// LauncherPlatform: CodeSignature.swift (additions; every Sec* call stays in this file)

extension CodeSignature {
    /// This process's version, identifier and team from its signing information; nil without a team (a development
    /// build, with or without the hand-testing argument).
    public static func releaseIdentityOfThisProcess() -> ReleaseIdentity?
    /// R8: `anchor apple generic and certificate leaf[subject.OU] = "<team>" and identifier "<id>" and notarized`,
    /// checked with strict validation, all architectures and nested code (resources included), and the bundle's
    /// CFBundleShortVersionString equal to `version`. A stapled app is checked offline (V3).
    static func isGenuine(_ bundle: URL, team: TeamID, identifier: BundleID, version: Version) -> Bool
}

// LauncherPlatform: ThisCopy.swift (addition)

extension ThisCopy {
    /// `ProcessInfo.operatingSystemVersion` as a `Version`, read once at start.
    public static func macOSVersion() -> Version
}

// LauncherPlatform: GitHubReleases.swift (the one file that names the network API)

/// The public release list of github.com/domasgru/trackpad-launcher over one ephemeral session: no cache, no cookies
/// sent or kept, nothing on disk but the download. Every request carries the constant User-Agent, Accept and
/// Accept-Language (G2, N1, N2), no query string, and the session's 30 s idle timeout (N3). Parses the answer into
/// `Release`s here: tag and body are ignored; a release counts only when it is neither draft nor pre-release and has
/// exactly one uploaded asset whose name `Release.Asset.parse` accepts.
@MainActor public final class GitHubReleases: Releases {
    public convenience init()
    /// Tests: a listener on 127.0.0.1 and a short stall.
    init(endpoint: URL, stall: Duration)
    // fetch: one Task awaiting a @concurrent static over `session.data(for:)`; `done` held in a property that
    //        cancelFetch() nils and the Task's cancel() honours, so nothing is delivered after cancel.
    // download: a download task with a delegate for didWriteData → progress (fraction of max(expected, release.size))
    //           and didFinishDownloadingTo → BundleInstall.keep(download:) → .downloaded; cancelDownload() cancels the
    //           task, nils `done`, and deletes anything kept.
    // parse(_ data: Data) -> [Release]? : private Decodable wire structs, never exported.
}

// LauncherPlatform: UpdateArchive.swift (the one file for the AppleArchive API)

enum UpdateArchive {
    /// Extracts `archive` in-process into `folder` and returns the one `.app` it held. Throws on anything else.
    static func unpack(_ archive: URL, into folder: URL) throws -> URL
}

// LauncherPlatform: BundleInstall.swift (additions; every unprivileged file operation of the move and the update)

extension BundleInstall {
    /// Moves a finished download out of the system's temporary file into the update's own temporary folder.
    static func keep(download temporary: URL, named name: String) throws -> URL
    /// A fresh item-replacement folder on `destination`'s volume: where the update unpacks and stages.
    static func stagingFolder(near destination: URL) throws -> URL
    /// Now internal: the update clears quarantine on the unpacked copy as the move does on the staged one.
    static func clearQuarantine(under root: URL) throws
    /// Removes the archive. Nothing throws.
    static func delete(_ file: URL)
}

// LauncherPlatform: PrivilegedInstall.swift (the script changes; one script for the move and the update)

enum PrivilegedInstall {
    /// Takes "$1" (destination) and "$2" (staged), never interpolated. With a destination present, one atomic exchange:
    /// /usr/bin/osascript -l JavaScript runs Foundation's replace as root, the old copy discarded by it (R-5); with
    /// none, one /bin/mv. The exit status matches what /Applications holds: a kill at any instant leaves either copy
    /// whole there (R13).
    static let script: String
    static func swap(_ staged: URL, into destination: URL, by administrator: any Administrator) -> InstallOutcome
}

// LauncherPlatform: ApplicationsInstaller.swift (one shared static; the move's behaviour unchanged)

extension ApplicationsInstaller {
    /// The move's writability check and swap over any staged bundle: unprivileged when /Applications and the
    /// destination are writable, the administrator's script otherwise. Discards `staged` on every outcome.
    nonisolated static func swap(_ staged: URL, into destination: URL, by administrator: any Administrator) -> InstallOutcome
}

// LauncherPlatform: SystemUpdateInstaller.swift

/// Installs a downloaded release over this copy. The work runs off the main actor; only `done` hops back.
@MainActor public final class SystemUpdateInstaller: UpdateInstaller {
    public convenience init(location: Location, running: ReleaseIdentity)
    /// Tests: a temp folder for the destination and a test administrator.
    init(destination: URL, running: ReleaseIdentity, administrator: any Administrator)

    public func install(_ download: DownloadedUpdate, as release: Release,
                        then done: @escaping @MainActor (InstallOutcome) -> Void) {
        // Task { done(await Self.replace(download, as: release, ...)) }
    }

    @concurrent private static func replace(/* ... */) async -> InstallOutcome {
        // defer { BundleInstall.delete(download.archive) }                      // every outcome (R3, R12)
        // let folder = try BundleInstall.stagingFolder(near: destination)       // same volume: one rename later
        // let staged = try UpdateArchive.unpack(download.archive, into: folder)
        // guard CodeSignature.isGenuine(staged, team: running.team, identifier: running.bundleID,
        //                               version: release.version) else { discard; return .failed(reason:) }   // R8
        // try BundleInstall.clearQuarantine(under: staged)                       // never translocated
        // return ApplicationsInstaller.swap(staged, into: destination, by: administrator)   // prompt only now (R11)
        // any throw: discard staged, .failed(reason:)
    }

    public func openReplacedCopy(then launched: @escaping @MainActor (Bool) -> Void) {
        // NSWorkspace.OpenConfiguration: activates = true, createsNewApplicationInstance = true (R-3);
        // openApplication(at: destination) { app, error in hop to main; launched(error == nil) }
    }
}

// LauncherUI: SettingsView.swift (additions)

/// Text left, button right, in a group of its own; the progress bar under them only while downloading (R5, R7, R12).
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void
    let cancel: () -> Void
    // available: Copy.updateAvailable(v) + Button(Copy.updateNowButton)
    // downloading: Copy.downloadingUpdate(v) + Button(Copy.cancelUpdateButton); ProgressView(value: progress)
    // installing: Copy.installingUpdate(v)
    // failed: Copy.updateFailed + Button(Copy.tryAgainButton)
}

// SettingsShell: the refit tuple gains `launcher.updater?.card?.phase`.
// TintedButtonStyle: reads @Environment(\.isEnabled) and dims when disabled.

// Tests: InMemoryAdapters.swift (additions)

/// Holds every completion until the test releases it; counts and records; delivers nothing after a cancel.
@MainActor final class InMemoryReleases: Releases {
    var log: EffectLog?
    private(set) var fetchCount = 0, cancelledFetches = 0, cancelledDownloads = 0
    private(set) var downloads: [Release] = []
    var isFetching: Bool { get }
    var isDownloading: Bool { get }
    func deliver(_ releases: [Release])
    func failFetch()
    func report(progress: Double)
    func finishDownload(_ file: DownloadedUpdate = .fixture)
    func failDownload()
}

@MainActor final class InMemoryUpdateInstaller: UpdateInstaller {
    var log: EffectLog?
    private(set) var installCalls = 0, openCalls = 0
    private(set) var installed: [(DownloadedUpdate, Release)] = []
    var isHolding: Bool { get }
    /// Runs after the swap, before `done`: the moment /Applications changed.
    var onInstalled: (() -> Void)?
    var onEffect: (() -> Void)?
    func release(_ outcome: InstallOutcome)
    func releaseOpen(launched: Bool)
}

// Tests: LifecycleWorld.swift (additions)
// launch(_:others:alreadyExited:placement:diskImageToEject:running: ReleaseIdentity? = nil)
// OneProcess: releases, updateInstaller; card; updateNow(); cancelDownload(); every call appends to `history`.
```

### Synthesis decision

### Tradeoffs accepted

- We accept a third model, and `Launcher` and `Lifecycle` each learning one collaborator, in exchange for the whole update reading top to bottom in one file and neither existing model growing a second state machine.
- We accept that the running copy ends itself on macOS's word that the new one launched, a short gap before the newcomer senses, in exchange for never leaving a lingering old process with Quit disabled when a newcomer dies at start.
- We accept a login-item handover (unregister, then the new copy registers) that may show a "login item added" notice on each update, in exchange for never silently losing starting at login if macOS keys the item by something an in-place replace changes (O2).
- We accept that each opening starts from no card, a previously known offer forgotten on close, in exchange for one rule for R1, R6 and R13 and no stale offer surviving a failed check.
- We accept `osascript` as root for the administrator's exchange, one more stock tool in the one script, in exchange for an atomic swap on both paths and R13's restart guarantee for standard accounts; the move gains it too.
- We accept an Apple Archive asset unfamiliar to people browsing the release page, in exchange for an in-process unpack with no child process (the DMG stays the human download).
- We accept reading the newest 30 releases with no paging, in exchange for a request with no query string; a user more than 30 releases behind still sees the highest of those 30, and the next update brings the rest.
- We accept no retry and no deadline beyond the request's own 30 s idle timeout, in exchange for the timer ban staying intact.
- We accept two reads of this process's code signature at start (the build and the identity), in exchange for leaving `Placement` and `--as-release-build` exactly as they are.

### Alternatives considered

- **The update as new `Lifecycle` stages (`checking`, `offering`, `downloading`…) with a card value the shell reads.** Rejected: `Lifecycle` would carry progress and a second machine beside the move's, the shell would need `Lifecycle` or a relay for the card, and the window's transitions would have to be routed back through `Lifecycle`. It hides nothing the Updater does not and exposes the move's machine to every update change.
- **Fold the update into `Launcher` (no third model).** Rejected: `Launcher` would learn the identity, the placement rule, two ports and the quit policy's input, and the gate would move into the window model, which Avoid 5 warns against; the interface of `Launcher` would grow by five intents to hide what `Updater` hides anyway.
- **One port `Updates` for fetch, download, unpack, verify and install.** Rejected: one real adapter mixing the network API with the Security and file APIs defeats the one-file confinements, and its tests would need a listener and temp bundles at once. Two ports keep each adapter testable at its own seam at the cost of one more in-memory adapter.
- **Let the newcomer alone stop the old process (no self-end).** Rejected for the reason in Tradeoffs: a newcomer that dies at start would leave the old process installing forever with Quit disabled.
- **Declare the minimum macOS in the release body or a manifest asset.** Rejected: a body is hand-edited prose; a manifest is a second request R3's "only the public list" does not cover. The asset name is written by the script from the plist and is the same string the genuineness check later cross-checks.
- **A zip asset unpacked with `ditto` as a child process.** Rejected: a child process is a thing the scan cannot see into, and the bans added for network bypasses (`Process(`) would have to carve it out.

### Open questions and risks

- Should the hand-testing argument `--as-release-build` stay unable to exercise the update (this design: no team, no `Updater`), given it means the card and the flow can only be hand-tested with two real notarised releases?
- Does the administrator's exchange through `osascript -l JavaScript` behave as root under `AuthorizationExecuteWithPrivileges` as it did unprivileged (R-5 was probed unprivileged only), and is making the move share the script acceptable, or should the move keep its two-`mv` script until a release has run the new one?
- Do the login item (O2) and the Accessibility and Screen Recording grants (O3) survive the in-place replace plus the handover on a real release, and does the handover show a "login item added" notice on every update? If the item survives without the handover, should the handover go?
- Is forgetting a known offer on close the intended reading of R1 and R6, so that a reopen shows the card only after its own check answers?
- With the window closed while installing, an AppleScript or Activity Monitor quit is now refused (R13's wording); is that intended, or should only the Dock's Quit be refused?
- Should the Figma card (O1, uninspected) change height between phases? The refit observes the phase, so either way works, but the downloading layout is a guess until read.
- Risk: the self-replace-and-open path has been probed only with ad-hoc bundles in /tmp (R-3); the first real release is the first run of it with a notarised app in /Applications, on top of a move path that has also never run for real (why.md Risk 4).
- Risk: the asset's name is the one declaration; a release uploaded by hand with a wrong name is invisible to every copy, and a wrong version in the name fails every install at the genuineness check rather than at the offer.

### Next implementation step

Add `Version`, `ReleaseIdentity`, `Release` with `Asset`, `NewerVersion`, `UpdateCard`, the two ports and `Updater` to `LauncherCore` with their in-memory adapters, and drive the R1, R4, R7, R11, R12 and R13 scenarios through `LifecycleWorld` before any adapter exists.
