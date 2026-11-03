# Plan: In-app updates

## Problem statement

Trackpad Launcher has no way to update itself. To get a new version, a user must learn that one exists, download the disk image again and drag the app over the old one. Most users will never do this. They stay on old versions with bugs that are already fixed.

The app makes no network calls today, by rule. So it cannot learn that a newer version exists.

## Solution

When the user opens the settings window, Trackpad Launcher checks once whether a newer version has been released. If one has, an **update card** appears at the top of the settings window: "App version 1.1.0 is available" with an **Update now** button (design: [Figma, node 2143-1845](https://www.figma.com/design/EB5ptBWZnAot7J3vx3cYLw/TapLauncher?node-id=2143-1845)). **Update now** downloads the new version, checks that it is genuine, replaces the app in /Applications and reopens it with the settings window open. Settings, starting at login and permissions all carry over.

The update check is the one exception to the no-network rule. It runs only when the settings window opens, in a copy installed in /Applications. It never runs at a login start, while the window is closed, or in a development build. It reads only the public list of releases and sends nothing about the user or the Mac.

The product overview's privacy rule changes to name this exception. The product overview's sentence "Of the app's own controls, only the *Quit Trackpad Launcher* button ... stops it" changes to note that an update also stops the old version and opens the new one. `docs/domain-model.md` (the glossary) gains *Update check*, *Newer version* and *Update card*.

## Requirements

### R1. The settings window checks for a newer version when it opens
Each time the settings window opens, a release build running from /Applications MUST make one update check. Every opening counts, including the one an update opens (R9), except an opening while an update installs (R7's installing state): the card then keeps showing the install, and that opening makes no check. A release build is one signed with a Developer ID, as the release process produces; any other build is a development build. The window MUST open at once, without waiting for the check. A window that stays open MUST NOT check again. The next opening checks again. A check still running when the window closes MUST be dropped, and its result MUST NOT be kept for the next opening.

#### Scenario: A newer version is out
- **GIVEN** version 1.0.0 runs from /Applications with its settings window closed, and version 1.1.0 has been released
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the settings window opens at once, and the update card appears at the top of it moments later, reading "App version 1.1.0 is available"

#### Scenario: A version released while the window stays open
- **GIVEN** the settings window opened with no update card, and stays open
- **WHEN** version 1.1.0 is released an hour later
- **THEN** the open window still shows no update card; after the user clicks *Close* and opens Trackpad Launcher again, the card shows

#### Scenario: Reopening an open window
- **GIVEN** the settings window is open behind another app's window
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the window comes to the front and no second update check is made

### R2. No update check anywhere else
Trackpad Launcher MUST make no network request at any time other than an update check from R1 and a download the user started with *Update now* or *Try again*. A login start, a running app with its settings window closed, a development build and a copy running from anywhere outside /Applications MUST make none.

#### Scenario: Login start
- **GIVEN** a newer version has been released
- **WHEN** macOS starts Trackpad Launcher at login and the user works for a day without opening the settings window
- **THEN** Trackpad Launcher makes no network request

#### Scenario: Development build
- **GIVEN** a development build (glossary)
- **WHEN** the user opens its settings window
- **THEN** it makes no network request and shows no update card

#### Scenario: Release build outside /Applications
- **GIVEN** a release build in ~/Applications that macOS starts at login, and a newer version has been released
- **WHEN** the user works for a day, then opens that copy by hand and answers *Quit* in its move dialog
- **THEN** that copy makes no network request at any point

#### Scenario: Move dialog
- **GIVEN** a release build opened from ~/Downloads, showing the move dialog
- **WHEN** the dialog is still unanswered
- **THEN** that copy makes no network request

### R3. The update check reveals nothing about the user
An update check MUST read only the public list of Trackpad Launcher releases. The request MUST carry nothing that identifies the user, the Mac, the app's version or the macOS version: no identifying User-Agent, no cookie and no query string. It MUST send no setting and no usage data. The Mac's network address, the time of the request, and what the system itself adds to every connection (its secure-connection handshake and its transport headers, such as the encodings it accepts) are inherent to any request. Beyond them, the request's address, the headers Trackpad Launcher sets, and the body MUST be the same on every Mac and every version. Trackpad Launcher MUST write nothing to disk for updates other than the downloaded update (R7), which it MUST delete once the update is installed, cancelled or failed, and the installed app.

#### Scenario: What a check sends
- **GIVEN** a network monitor watches Trackpad Launcher's traffic
- **WHEN** the user opens the settings window
- **THEN** the only traffic is a request for the public release list, with no query string, no cookie and no User-Agent or other header that names the user, the Mac, the app's version or the macOS version

### R4. Only a newer full release that runs on this Mac counts
A *newer version* MUST be a published full release with a higher version than the running one, whose minimum macOS this Mac meets. Drafts, pre-releases, the same version and older versions MUST NOT count. A release with no declared minimum macOS or no downloadable app MUST NOT count. When several count, the update card MUST offer the highest. Trackpad Launcher MUST never install an older version.

#### Scenario: Pre-release
- **GIVEN** version 1.0.0 runs, and the only release above it is pre-release 1.1.0-beta
- **WHEN** the user opens the settings window
- **THEN** no update card shows

#### Scenario: Needs a newer macOS
- **GIVEN** the Mac runs macOS 26, and version 1.1.0 needs macOS 27
- **WHEN** the user opens the settings window
- **THEN** no update card shows

#### Scenario: The highest release this Mac can run
- **GIVEN** version 1.0.0 runs on macOS 26, version 1.1.0 needs macOS 26 and version 1.2.0 needs macOS 27
- **WHEN** the user opens the settings window
- **THEN** the card reads "App version 1.1.0 is available"

#### Scenario: Versions compare by number
- **GIVEN** version 1.9.0 runs, and version 1.10.0 has been released
- **WHEN** the user opens the settings window
- **THEN** the card offers 1.10.0 (versions compare numerically, part by part)

#### Scenario: Already up to date
- **GIVEN** version 1.1.0 runs and 1.1.0 is the latest release
- **WHEN** the user opens the settings window
- **THEN** no update card shows

### R5. The update card
While a newer version is known, the settings window MUST show the update card as its first group, above the gesture rows, as in the design: the text "App version <version> is available" on the left and the *Update now* button on the right. The card MUST NOT be dismissable. While no newer version is known, the card MUST NOT show and the gesture rows MUST be the first group, as in the window without the card.

#### Scenario: Card layout
- **GIVEN** version 1.1.0 has been released and 1.0.0 runs
- **WHEN** the update check finishes
- **THEN** the card appears above the gesture rows, in its own rounded group, reading "App version 1.1.0 is available" with *Update now* on the right, and the rest of the window moves down to make room

### R6. A failed check is silent
When an update check fails, for example offline or with no answer, the settings window MUST show no update card and no error.

#### Scenario: Offline
- **GIVEN** the Mac has no network connection and a newer version exists
- **WHEN** the user opens the settings window
- **THEN** the window shows no update card and no error, and the next opening checks again

### R7. Updating shows progress and can be cancelled
Pressing *Update now* MUST turn the card into its downloading state: the text "Downloading version <version>…", a progress bar that fills as the download goes, and a *Cancel* button. *Cancel* MUST stop the download and return the card to "App version <version> is available" with *Update now*, with nothing changed. When the download finishes, the card MUST enter its installing state: the text "Installing version <version>…", with no progress bar and no *Cancel*. *Cancel* MUST exist only in the downloading state.

#### Scenario: Cancelling a download
- **GIVEN** the card reads "Downloading version 1.1.0…" with the progress bar at 40%
- **WHEN** the user presses *Cancel*
- **THEN** the card reads "App version 1.1.0 is available" with *Update now*, and version 1.0.0 stays installed and running

#### Scenario: Download finishes
- **GIVEN** the card reads "Downloading version 1.1.0…"
- **WHEN** the download finishes
- **THEN** the card reads "Installing version 1.1.0…", with no progress bar and no *Cancel*

### R8. Only a genuine update is installed
Trackpad Launcher MUST install a downloaded version only when it is signed with the same Developer ID as the running one, notarised by Apple, has the same bundle identifier, and is the version the card offered. Otherwise it MUST install nothing and show the failed state (R12).

#### Scenario: Tampered download
- **GIVEN** the downloaded app's signature does not match Trackpad Launcher's Developer ID
- **WHEN** the download finishes
- **THEN** nothing is installed, version 1.0.0 keeps running, and the card reads "The update couldn't be installed." with *Try again*

#### Scenario: Wrong version downloaded
- **GIVEN** the card offered version 1.1.0
- **WHEN** the downloaded app is version 1.0.5
- **THEN** nothing is installed, version 1.0.0 keeps running, and the card reads "The update couldn't be installed." with *Try again*

### R9. Installing replaces the app and reopens it
Once a genuine download finishes, Trackpad Launcher MUST replace the copy in /Applications with the new version, stop the old version and open the new one with its settings window open. Gestures MUST keep working until the old version stops. The reopened window MUST make an update check (R1), and MUST show no update card when the installed version is the latest.

#### Scenario: The new version opens
- **GIVEN** version 1.0.0 runs from /Applications and the card reads "Installing version 1.1.0…"
- **WHEN** the install finishes
- **THEN** /Applications holds version 1.1.0, version 1.0.0 no longer runs, and version 1.1.0 runs with its settings window open, checks for a newer version and shows no update card

#### Scenario: Gestures during the download
- **GIVEN** the card reads "Downloading version 1.1.0…"
- **WHEN** the user makes a 1-finger gesture
- **THEN** its assigned app comes to the front as usual

### R10. Settings and permissions carry over
Every setting, starting at login and the Accessibility and Screen Recording permissions MUST carry over to the new version. The new version MUST show no permission prompt and no first-run step.

#### Scenario: Successful update
- **GIVEN** version 1.0.0 runs from /Applications with gestures assigned, starting at login on and Accessibility granted
- **WHEN** the user presses *Update now* and the download finishes
- **THEN** version 1.1.0 runs from /Applications with its settings window open and no update card; the same apps are assigned, starting at login is still on, Accessibility is still granted, and no permission prompt or first-run step appears

### R11. An administrator's password when /Applications is not writable
When the user's account cannot write to /Applications, the update MUST ask for an administrator's name and password, as the move dialog does. The prompt MUST appear after the download finishes and is verified, never before. Cancelling that prompt MUST return the card to "App version <version> is available" with *Update now*, with nothing changed and no error.

#### Scenario: Standard account cancels the prompt
- **GIVEN** a standard account that cannot write to /Applications
- **WHEN** the user presses *Update now*, the download finishes and the user cancels the administrator prompt
- **THEN** version 1.0.0 stays installed and running, and the card reads "App version 1.1.0 is available" with *Update now*

### R12. A failed update keeps the current version
When a download or install fails for any reason other than R7's *Cancel* or R11's cancelled prompt, the card MUST read "The update couldn't be installed." with a *Try again* button. A download that makes no progress for 30 seconds MUST count as failed. *Try again* MUST start the update again, as *Update now* does. A failure before the new version is in place MUST leave the running version installed and working. When the new version is in place but macOS does not open it, the card MUST read the same failed text with *Try again*, the running version MUST keep working until it ends, and *Try again* MUST put the new version in place again and open it. On a failure and on a cancel, the downloaded file MUST be deleted.

#### Scenario: Connection lost mid-download
- **GIVEN** the card reads "Downloading version 1.1.0…"
- **WHEN** the network drops
- **THEN** the card reads "The update couldn't be installed." with *Try again*, and version 1.0.0 keeps running with its gestures

#### Scenario: Replacing the app fails
- **GIVEN** the download of version 1.1.0 is genuine
- **WHEN** replacing the copy in /Applications fails, for example because the disk is full
- **THEN** /Applications still holds a whole version 1.0.0, it keeps running with its gestures, and the card reads "The update couldn't be installed." with *Try again*

#### Scenario: Trying again
- **GIVEN** the card reads "The update couldn't be installed."
- **WHEN** the network is back and the user presses *Try again*
- **THEN** the card reads "Downloading version 1.1.0…" and the update proceeds as from *Update now*

### R13. Closing or quitting during an update
Closing the settings window or pressing *Quit Trackpad Launcher* while a download runs MUST cancel the download and change nothing. During the installing state, *Quit Trackpad Launcher* MUST be disabled (greyed out), and every other ordinary quit, *Close Settings* (⌘Q) in the app menu and *Quit* in the Dock icon's menu, MUST do nothing more than close the settings window. *Close* MUST close the window while the install continues, and the new version then opens with its settings window open. Logging out, restarting and shutting down MUST still end Trackpad Launcher, leaving either the old or the new version whole in /Applications.

#### Scenario: Closing the window mid-download
- **GIVEN** the card reads "Downloading version 1.1.0…"
- **WHEN** the user clicks *Close*
- **THEN** the window closes, the download stops, version 1.0.0 keeps running, and the next opening shows "App version 1.1.0 is available"

#### Scenario: Closing the window while installing
- **GIVEN** the card reads "Installing version 1.1.0…"
- **WHEN** the user clicks *Close*
- **THEN** the window closes, the install continues, and version 1.1.0 then opens with its settings window open

#### Scenario: Restart while the new version is put in place
- **WHEN** the Mac restarts while the new version replaces the old one in /Applications
- **THEN** after the restart /Applications holds a whole Trackpad Launcher, either 1.0.0 or 1.1.0, that opens and works

### R14. Each release is offered to running copies
Each release made with the release process MUST be found by the update check of every older version that has the update check, at its next settings-window opening. Each release MUST declare its minimum macOS and carry a downloadable app, signed and notarised. A release MUST carry a version higher than every earlier release.

#### Scenario: Publishing a release
- **GIVEN** version 1.0.0 is installed on a Mac
- **WHEN** the developer raises the version to 1.1.0, runs the release process and publishes the release
- **THEN** opening 1.0.0's settings window shows "App version 1.1.0 is available", and *Update now* installs 1.1.0

## Non-goals

- **Checking in the background or at login.** The card shows only in the settings window, so a check at any other time would make network requests for nothing a user can see.
- **Notifications, Dock badges or dialogs about updates.** The card is the only place an update shows.
- **A switch to turn update checks off.** The check runs only when the user opens the settings window, and reads only the public release list.
- **Release notes in the app.** The card names the version only.
- **Skipping a version or dismissing the card.** The card stays until the app is up to date, so users do not get stranded on old versions.
- **Installing updates without the user pressing *Update now*.** The user decides when the app replaces itself.
- **Updating a development build.** Development builds never check.
- **Beta or pre-release channels.** Only full releases count.
- **A *Check for updates* button.** Reopening the settings window is the manual check.
- **Showing the installed version in the window.** The card names only the new version.

## Design

### Problem

Trackpad Launcher has to learn of a newer version and install it, while making no other network request. The shape is not obvious because the update spans both existing models. It starts at `Launcher`'s settings-window closed→open edge, which today shows only as `window` leaving `.closed`. It renders in `Launcher`'s window, and closing that window must drop it. Yet it replaces the running process's own bundle, changes `Lifecycle`'s quit policy, and must hand the process over to the new version.

Constraints the design honours (the facts are in the grounding index, `.temp/architect/grounding/index.md`):
- `Launcher` knows nothing of `Placement`, `Build` or quitting.
- Every port has exactly two adapters and none is `async`. The model drops a late result by guarding on its own state.
- No timers: every input is a push.
- The source scan bans `URLSession` outright. A rule is relaxed by moving the token to one owning file (plans 002, 006, 021).
- No stored value holds "release build in /Applications". `--as-release-build` makes a development build read `.release`, and Debug and perf builds are signed with Apple Development under the same team as releases.
- When the running app opens its own replaced bundle with the default configuration, LaunchServices only reopens the old process (probed, R-3).
- The move's administrator path is two renames, a gap R13's restart scenario does not allow.
- GitHub refuses a request without a User-Agent. URLSession's defaults reveal the Darwin version and the user's languages.
- A release has no minimum-macOS field, and R3 allows one request for the list.

### Usage (caller's view)

**README: in-app updates.** A release build in /Applications owns one `Updater`, a third `@MainActor @Observable` model beside `Lifecycle` and `Launcher`.
- **The check.** Each time the settings window opens from closed, the `Updater` reads the public release list once. If a newer version runs on this Mac, `updater.card` becomes `.available(version)` and the window shows it as its first group.
- **Actions.** `updateNow()` downloads, checks and installs; *Try again* calls the same method. `cancel()` stops a download.
- **Close.** Closing the window drops a check in flight and cancels a download. An install keeps going.
- **Quit.** While `isInstalling`, *Quit Trackpad Launcher* is disabled and every ordinary quit only closes the window.
- **Hand-over.** Once the new version is in place, the `Updater` opens it as a new process and this process ends. The new version is an ordinary opening by hand from /Applications: it stops any copy still running, opens its settings window, and that opening checks again.

The following have no `Updater` at all, so they have no path to the network: a development build (Xcode, Debug, perf), a copy started with `--as-release-build`, a copy outside /Applications, and a copy showing the move dialog.

Call site 1, the composition root. This is the one place the gate is decided and the network adapters are built:

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

/// R1, R2: only a copy truly signed with a Developer ID and lying in /Applications ever reaches the network. The rule
/// itself is `InstalledRelease.init?`, which the tests call too. `developerIDSigner()` takes no arguments, so
/// `--as-release-build` cannot fake it.
private func makeUpdater(placement: Placement, location: Location) -> Updater? {
    let signer = CodeSignature.developerIDSigner()
    guard let installed = InstalledRelease(
              placement: placement, developerIDSigned: signer != nil, version: ThisCopy.version(), macOS: ThisCopy.macOS()),
          let signer
    else { return nil }
    return Updater(installed, releases: GitHubReleases(),
                   installer: ApplicationsUpdater(replacing: location.running, signer: signer))
}

private func makeResident(_ startAtLogin: StartAtLogin, _ updater: Updater?) -> Launcher {
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
    // ... as today ...
    HStack(spacing: 8) {
        Spacer(minLength: 0)
        Button(Copy.quitButton, action: actions.quit)
            .buttonStyle(TintedButtonStyle(tint: .red))
            .disabled(updater?.isInstalling == true)
        Button("Close") { launcher.closeWindow() } // ... as today
    }
}
```

Call site 3, a requirement scenario at the one high seam. A process is a real `Lifecycle`, `Launcher` and `Updater` over in-memory adapters. Every completion is held until the test releases it:

```swift
@Test func aFinishedDownloadInstallsOpensTheNewVersionAndEndsTheOld() {   // R1, R7, R9, R10
    let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    let old = world.launch(.byHand, running: .release("1.0.0"))
    #expect(old.releases.fetches == 1)                                     // the opening checked
    old.releases.deliver([.version("1.1.0", needs: "26.0")])
    #expect(old.updater.card == .available(Version(1, 1, 0)))

    old.updater.updateNow()
    old.updates.progress(0.4)
    #expect(old.updater.card == .downloading(Version(1, 1, 0), progress: 0.4))
    old.tap(1)                                                             // R9: gestures during the download
    #expect(old.system.broughtToFront == [world.mac.app("Arc")])

    old.updates.finishDownload()
    #expect(old.updater.card == .installing(Version(1, 1, 0)) && old.updater.isInstalling)
    old.updates.swapIn()
    old.updates.answerOpen(started: true)
    #expect(old.copies.hasEnded)                                           // R9: the old version stops

    let new = world.launch(.byHand, others: [.earlier], alreadyExited: [.earlier], running: .release("1.1.0"))
    #expect(new.window == .open(request: 1) && new.releases.fetches == 1)  // R9: the reopened window checks
    new.releases.deliver([.version("1.1.0", needs: "26.0")])
    #expect(new.updater.card == nil)
    #expect(world.loginItem.isOn && world.loginItem.calls.isEmpty && world.permissions.asks.isEmpty)   // R10
}
```

Call site 4, the release process (R14):

```sh
# raise MARKETING_VERSION and CURRENT_PROJECT_VERSION in Config/Version.xcconfig, commit, push
NOTARY_PROFILE=<profile> Scripts/release.sh     # builds, notarises, staples, archives, creates the draft release v1.1.0
gh release edit v1.1.0 --draft=false --latest   # publishing is the deliberate second step
```

### Shape

**Data first.**
- `Version` is the one ordering: dotted whole numbers compared part by part (R4: 1.9.0 < 1.10.0). Trailing zeros are dropped for comparison, so `==`, hashing and `<` agree (1.1 == 1.1.0). `description` is the text as written, for the card.
- `Release` is a release as the app understands it, built only in a form that counts. The list's adapter builds one only for a published full release that carries an uploaded archive whose name declares both a version and a minimum macOS. A draft, a pre-release, a release with no app and a release with no declared minimum therefore never reach the model (per type-system-discipline: types are constructions).
- `InstalledRelease` is the running copy as an update sees it: its version and this Mac's macOS, read once at start. Its initializer is the whole R1/R2 gate, pure, in one place: it builds only for a copy truly signed with a Developer ID, at `Placement.installed`, with a version that parses. `Updater` takes one, so an `Updater` can exist only where R1 allows a check (per encode-lessons-in-structure). The composition root and the test harness call the same initializer. Reading once matters: after the swap, `Bundle.main` would read the new bundle (R-6).
- `UpdateCard` holds the four visible states. *Cancel* and the bar exist only in `.downloading`. Its `layout` is the card with the progress erased, which is what the window refits on.
- `UpdateEvent` is what an update reports, in a fixed order: progress, then the download's end, then one install outcome.
- The model's private `Phase` adds `idle`, `checking` and `opening` to the card's states, and carries the ticket that drops late results.

**Ownership: one deep model, peer to the two existing ones.** `Updater` (`LauncherCore`, `@MainActor @Observable`) owns every update decision:
- the R1 trigger and the dropping of a stale check;
- choosing the offer (pure);
- the download's cancel rules;
- what each outcome does to the card;
- whether an install is under way;
- when the hand-over is done.

Its public surface is `card`, `isInstalling`, `updateNow()` and `cancel()`. Three more members are internal to `LauncherCore`: `windowOpened()` and `windowClosed()`, called only by `Launcher`, and `onReplaced`, set only by `Lifecycle`. It follows the `StartAtLogin` precedent: one object built by the composition root and shared, with each holder using a different part.
- **`Launcher`** only reports its own two window transitions. It learns nothing about builds, placement, versions or the network. The edge lives where the window state lives (single source of truth). The shell is no place for it, because Observation coalesces a `.closed` then `.open` within one turn.
- **`Lifecycle`** reads `isInstalling` in its one exhaustive quit switch, and answers `onReplaced` with `end()`. This is the settable-callback idiom the ports already use.

**Two ports, each deep, each with two adapters.**
- `ReleaseList.fetch` hides everything about the list: the address, the headers, the privacy configuration, GitHub's JSON, the asset-name contract and every R4 wire filter. It answers `[Release]`, empty on any failure.
- `UpdateInstaller` hides replacing this copy, in three methods:
  - `update(to:events:)` runs the whole sequence: download into memory, the 30 s stall rule, the length check, the safe unpack, genuineness, the writability check, the administrator prompt, the atomic swap, and every clean-up.
  - `cancelDownload()` stops it before the download ends.
  - `openNewVersion(then:)` hides the LaunchServices configuration.

  The model never holds a file path, so no caller can forget R3/R12's "delete the download".
- **Asynchronous delivery keeps model tests synchronous**, as with the existing ports. Each port takes an `@escaping @MainActor` completion or event sink, and the model sets its phase before calling, since an in-memory adapter may answer inline. The in-memory adapters hold each closure until the test delivers it, withholds it, or delivers it late. The real adapters start a `Task` that awaits `@concurrent` statics and calls back on the main actor.

**The check (R1, R2, R4, R6).**
- `windowOpened()` starts a check from every phase except an install, which R1 exempts. So any card left from earlier (an offer, a failure, a cancelled prompt that arrived while the window was closed) is replaced by a fresh check. A re-front is not an edge, so it never checks.
- `windowClosed()` drops a check, an offer or a failure and cancels a download, but leaves an install alone. A late answer carries a ticket that no longer matches the live one and is dropped.
- A failed request delivers `[]`. The model stays idle: no card, no error, and the next opening checks again.
- `Release.newerVersion(in:than:on:)` is the pure R4 rule.
- Eligibility is decided at construction. There is no `Updater` without an `InstalledRelease`, whose initializer requires the real Developer ID signature and `.installed`. That covers development builds (Xcode, Debug and the perf build, all Apple Development-signed under the release team), ~/Applications, the move dialog and `--as-release-build`. A login start never opens the window, so it never checks.

**The request (R3).**
- Exactly one `GET https://api.github.com/repos/domasgru/trackpad-launcher/releases`, with no query string. It reads the default first page, the newest 30 releases.
- Each request gets its own `URLSessionConfiguration.ephemeral` session, invalidated when the request ends, with:
  - cookies neither set nor accepted, and cookie storage, URL cache and credential storage all nil;
  - a request cache policy that ignores local and remote caches;
  - `waitsForConnectivity = false`, so offline fails at once (R6);
  - `timeoutIntervalForRequest = 30`.
- Constant headers replace the identifying defaults, including across GitHub's redirect: `User-Agent: TrackpadLauncher`, `Accept-Language: en`, `X-GitHub-Api-Version: 2022-11-28`, and `Accept: application/vnd.github+json` for the list or `application/octet-stream` for the archive.
- Pinning the API version keeps every shipped version parsing the same JSON after GitHub changes its default (R14). The list is parsed into `[Release]` inside the adapter, and no wire type crosses the port.

**The download (R7, R12).**
- The archive, about 3 MB, is received into memory. Nothing is written until all of it has arrived, so a *Cancel*, a *Close*, a Quit, a crash or a logout mid-download leaves nothing on disk.
- Progress comes from the task's own progress, observed by KVO (a push). It is reported in whole percents against the size the list declared.
- A body longer or shorter than that declared size fails.
- 30 s with no byte fails through the request's own idle timeout, which every byte resets (probed, N3). The app has no timer of its own.
- *Cancel* cancels the task.
- The adapter's `.downloaded` push and its cancellation check run in one main-actor turn. Either a *Cancel* lands first and nothing more happens, or the model is already `.installing`, where *Cancel* does not exist and closing does not cancel.

**Genuineness (R8).** `CodeSignature.isGenuine` holds the check, so `SecStaticCode` and `SecRequirement` stay confined to their one file.
- It runs against the unpacked bundle with strict validation of every architecture, nested code and resource, plus `kSecCSNoNetworkAccess`. That flag makes `notarized` read the stapled ticket, with no third request; the release always staples.
- The requirement is `anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = "<team>" and identifier "<id>" and notarized`.
- The team and identifier come from this process's own signature, read once at start (`Signer`), never from Swift literals.
- The sealed Info.plist must name exactly the offered version and minimum macOS. A wrongly named asset therefore cannot install an app this Mac cannot run.

**Unpacking.** The asset is an Apple Archive, unpacked in-process from memory into an item-replacement folder on the /Applications volume (checked after fan-out: `checks/checks.out`).
- The archive's selection hook checks every entry before it is written. Only these are admitted: a relative path equal to or under `TrackpadLauncher.app/` with no `..` component, that is a directory, a regular file, or a symbolic link whose target resolves inside the bundle.
- The first refused entry cancels the extraction and the folder is discarded. Nothing outside the staging folder is written before verification.
- Quarantine is cleared on every item, as the move does.
- `release.sh` archives with `-exclude-field uid,gid,xat,acl,flg`, so no build-machine owners or extended attributes ship.

**Installing and relaunching (R9, R11, R13).** The effect order is unpack, verify, swap, open, end. The swap is the first change anywhere.
- **The swap.** It is shared with the move: `ApplicationsInstaller.put`, extracted from today's `copy`.
  - When /Applications and the bundle are writable, `put` uses `BundleInstall.swap` (`replaceItemAt`, one atomic rename, probed R-1). Otherwise it uses `PrivilegedInstall.swap`.
  - The administrator's script becomes one atomic exchange as root: `osascript -l JavaScript` calling Foundation's `replaceItemAt`, with the paths passed as arguments, or a single `mv` when nothing lies at the destination. This closes the two-rename gap for the move too, so a restart at any instant leaves a whole version (R13).
- **The prompt.** It therefore comes only after the download is verified (R11). Cancelling it reports `.declined`, which returns the card to *available* with nothing changed. The move's "cancel ends the process" stays the move's own rule.
- **The destination** is `Location.running`, the running bundle, which lies in /Applications by construction. It is not the move's identifier search.
- **The open.** `openNewVersion` calls `openApplication` with `createsNewApplicationInstance = true` and `activates = true`; with the default configuration the old process only receives a reopen (probed, R-3).
  - When LaunchServices reports a started process, `onReplaced` fires and `Lifecycle` ends this process, as the mover ends once it has opened the installed copy (plan 021: a copy that waits to be stopped "never ends if that copy fails to start"). The new process is an opening by hand from /Applications, so its `.runWithWindow` route stops any copy still running, builds its resident, opens its window, and that first opening checks (R9). The old copy keeps its gestures until it ends.
  - When LaunchServices does not start it, the card shows the failed state. *Try again* converges: a same-version swap, then a second open.

**Carry-over (R10).** The update changes nothing but the bundle at the same path:
- the same identifier and team, so the designated requirement still matches (probed, V5);
- the same defaults domain;
- no login-item call at all;
- no first run, because settings exist.

The move's login-item handover exists because the copy changes path, and that reason is absent here. A suspend/resume on every update would risk a "login item added" notice each time. Whether the item survives is a manual check (open question 1).

**Quit and close (R13).**
- A *Close* during a download cancels it.
- *Quit* during a download ends the process. The in-memory download dies with it, with nothing changed on disk.
- While `isInstalling` (installing and opening):
  - `quit()` does nothing, and the button is disabled and greyed;
  - `shouldEnd(.other)` closes an open window and otherwise refuses, as `.moving` does;
  - `.system` (logout, restart, shutdown) always ends. The swap is atomic on both paths.

**The card (R5, R7, R12).**
- `UpdateCardView` is one `FormGroup` with the text left and the button right in one row. The downloading state adds a linear progress bar under the row. Measurements, button style and the bar's placement come from Figma node 2143-1845 at implementation.
- The shell's refit observation gains `updater?.card?.layout`. It changes only when the card appears, goes or changes state, never on a progress push. The window grows downward under a pinned top edge.
- `TintedButtonStyle` reads `isEnabled`, so a disabled Quit renders greyed.
- The strings live in `Copy` and are asserted verbatim.

**What the design deliberately does not do:** check at login or while closed, retry, poll, resume a download, keep a check's result across openings, show an error, downgrade, read release notes, authenticate to GitHub, or write a downloaded file to disk.

```swift
// MARK: LauncherCore — domain types (Foundation + Observation only)

/// A version as releases and Info.plists write it: dotted whole numbers ("1.10.0"). Compared part by part, a
/// missing part counting as zero: 1.9.0 < 1.10.0, 1.1 == 1.1.0. "1.1.0-beta", "v1.1" and "" are not versions, so a
/// release named with one never counts (R4).
public struct Version: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// As written, for the card: "App version 1.10.0 is available".
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
/// adapter: a draft, a pre-release, an asset still uploading, or a release without a well-named archive never
/// becomes one.
public struct Release: Equatable, Sendable {
    public let version: Version
    public let minimumMacOS: Version
    /// Where the app's archive downloads from: this repository's release downloads.
    public let archive: URL
    /// The archive's size as the list declares it: the progress denominator and the exact expected length.
    public let archiveSize: Int
    public init(version: Version, minimumMacOS: Version, archive: URL, archiveSize: Int)

    /// R4, the one rule: the highest release above `running` whose minimum `macOS` meets; nil when none.
    public static func newerVersion(in releases: [Release], than running: Version, on macOS: Version) -> Release? {
        releases.filter { $0.version > running && $0.minimumMacOS <= macOS }.max { $0.version < $1.version }
    }
}

/// The running copy as an update check sees it. The R1/R2 gate, whole: exists only for a copy truly signed with a
/// Developer ID, in /Applications (`Placement.installed`), whose version parses. The composition root and the tests
/// call this one rule. Read once at start: after a swap, `Bundle.main` would read the new bundle.
public struct InstalledRelease: Equatable, Sendable {
    public let version: Version
    public let macOS: Version
    public init?(placement: Placement, developerIDSigned: Bool, version: String?, macOS: Version) {
        guard developerIDSigned, placement == .installed, let version = version.flatMap(Version.init) else { return nil }
        self.version = version
        self.macOS = macOS
    }
}

/// The update card, the settings window's first group while a newer version is known. Not dismissable.
public enum UpdateCard: Equatable, Sendable {
    /// "App version 1.1.0 is available" · *Update now*
    case available(Version)
    /// "Downloading version 1.1.0…" · a bar at `progress` (0...1) · *Cancel*. The only state with *Cancel*.
    case downloading(Version, progress: Double)
    /// "Installing version 1.1.0…": no bar, no *Cancel*; *Quit Trackpad Launcher* is disabled.
    case installing(Version)
    /// "The update couldn't be installed." · *Try again*
    case failed(Version)

    /// The card with its progress erased: what decides its height, so the window refits when the card appears,
    /// goes or changes state, never on a progress push.
    public enum Layout: Equatable, Sendable { case available, downloading, installing, failed }
    public var layout: Layout { fatalError("not implemented") }
}

/// What an update reports, in this order: any `.progress`; then `.failed`, or `.downloaded` followed by exactly one of
/// `.installed`, `.declined`, `.failed`.
public enum UpdateEvent: Equatable, Sendable {
    /// 0...1 of the archive received, in whole percents.
    case progress(Double)
    /// The whole archive arrived. From here on nothing cancels the update.
    case downloaded
    /// /Applications holds the new version.
    case installed
    /// The administrator prompt was cancelled; nothing changed.
    case declined
    /// Nothing changed: the download failed, stalled or had the wrong length; the archive held something else; the
    /// app was not genuine; or the swap failed.
    case failed
}

// MARK: LauncherCore — ports (beside the existing eight)

/// The public list of Trackpad Launcher releases. Real: GitHubReleases. Test: InMemoryReleaseList.
@MainActor public protocol ReleaseList: AnyObject {
    /// One request for the list. Returns at once; `done` runs once on the main actor, possibly inside this call, with
    /// every release that counts (see `Release`), or none when the request failed (offline, no answer, any status but
    /// 200, a body that does not parse). Sends nothing about the user, the Mac, this version or macOS.
    func fetch(then done: @escaping @MainActor ([Release]) -> Void)
}

/// Replacing this copy in /Applications with a newer version, and opening it. Real: ApplicationsUpdater.
/// Test: InMemoryUpdateInstaller.
@MainActor public protocol UpdateInstaller: AnyObject {
    /// Downloads `release`'s archive into memory, then installs it: unpacks it into a staging folder beside
    /// /Applications, checks that it is genuine (this copy's Developer ID team, notarised, this identifier, `release`'s
    /// version and minimum macOS, every resource sealed), and swaps it in for this copy in one atomic step, as an
    /// administrator when this account cannot write there; the prompt comes only at that step. Returns at once;
    /// `events` runs on the main actor, possibly inside this call, in `UpdateEvent`'s order. 30 s without a byte fails.
    /// /Applications changes only with `.installed`. On every outcome nothing of the update is left on disk except the
    /// installed app.
    func update(to release: Release, events: @escaping @MainActor (UpdateEvent) -> Void)
    /// Before `.downloaded`: stops the download, and no further event arrives. From `.downloaded` on: does nothing.
    func cancelDownload()
    /// Opens the copy now in /Applications as a new process, an opening by hand, never a reopen of this one.
    /// `started` runs once, on the main actor: whether macOS started it.
    func openNewVersion(then started: @escaping @MainActor (Bool) -> Void)
}

// MARK: LauncherCore — the model

/// The update check, the update card and replacing this copy with a newer version. Exists only in a release build in
/// /Applications. `Launcher` reports the settings window's openings from closed and its closings; `Lifecycle` reads
/// `isInstalling` and ends the process on `onReplaced`; the view renders `card` and sends `updateNow` / `cancel`.
@MainActor @Observable
public final class Updater {
    /// Every legal situation, and nothing else.
    private enum Phase {
        case idle
        case checking(ticket: Int)
        case offering(Release)
        case downloading(Release, ticket: Int, progress: Double)
        /// Unpacking, verifying, maybe the administrator prompt, the swap. Survives the window closing.
        case installing(Release, ticket: Int)
        /// Swapped in and asked to open; ends with this process.
        case opening(Release)
        case failed(Release)
    }

    private var phase: Phase = .idle
    @ObservationIgnored private var tickets = 0
    @ObservationIgnored private let installed: InstalledRelease
    @ObservationIgnored private let releases: any ReleaseList
    @ObservationIgnored private let installer: any UpdateInstaller
    /// The new version runs: this process ends. Set only by `Lifecycle`.
    @ObservationIgnored var onReplaced: (@MainActor () -> Void)?

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
        guard !isInstalling else { return }  // R1's exemption: the card keeps "Installing…"
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
        case (.downloading(let r, _, _), .progress(let fraction)):
            phase = .downloading(r, ticket: ticket, progress: fraction)
        case (.downloading(let r, _, _), .downloaded): phase = .installing(r, ticket: ticket)
        case (.downloading(let r, _, _), .failed), (.installing(let r, _), .failed): phase = .failed(r)  // R8, R12
        case (.installing(let r, _), .declined): phase = .offering(r)  // R11
        case (.installing(let r, _), .installed):
            phase = .opening(r)
            installer.openNewVersion { [unowned self] in opened($0) }  // R9
        default: break
        }
    }

    /// Started: this process ends, and the new version, opened by hand from /Applications, stops anything left.
    /// Not started (R12's last case): /Applications holds the new version; Try again converges (a same-version swap,
    /// a second open).
    private func opened(_ started: Bool) {
        guard case .opening(let r) = phase else { return }
        if started { onReplaced?() } else { phase = .failed(r) }
    }
}

// MARK: LauncherCore — the two existing models, the whole diff

// Launcher: one optional collaborator, two edges. Launcher learns no build, placement, version or network.
@ObservationIgnored private let updater: Updater?
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

// Lifecycle: reads one fact and answers one push. The new version arrives through its ordinary route.
@ObservationIgnored private let updater: Updater?

public init(
    placement: Placement, copies: any RunningCopies, installer: any Installer, startAtLogin: StartAtLogin,
    updater: Updater? = nil, makeResident: @escaping @MainActor () -> Launcher)
// ...as today, then last: updater?.onReplaced = { [unowned self] in replaced() }

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

/// The new version has started: end, as the mover does once it has opened the installed copy.
private func replaced() {
    guard case .resident = stage else { return }
    end()
}

// MARK: LauncherCore — Copy (asserted verbatim by CopyTests)
//   updateAvailable(v)   = "App version \(v) is available"     updateNowButton = "Update now"
//   updateDownloading(v) = "Downloading version \(v)…"     cancelButton    = "Cancel"
//   updateInstalling(v)  = "Installing version \(v)…"
//   updateFailed         = "The update couldn't be installed."   tryAgainButton = "Try again"
```

```swift
// MARK: LauncherPlatform — GitHubReleases.swift: the one network file

/// The public release list and a release's archive. Every request uses its own ephemeral session (no cookie, cache or
/// credential store, nothing on disk) and HTTPS to GitHub, with no query string and constant headers that name neither
/// the user, the Mac, this version nor macOS, and fails after 30 s in which no byte arrives (the request's own idle
/// timeout: no timer of ours).
@MainActor public final class GitHubReleases: ReleaseList {
    static let listURL = URL(string: "https://api.github.com/repos/domasgru/trackpad-launcher/releases")!
    static let downloadsPrefix = "https://github.com/domasgru/trackpad-launcher/releases/download/"
    static let headers = ["User-Agent": "TrackpadLauncher", "Accept-Language": "en", "X-GitHub-Api-Version": "2022-11-28"]
    private let endpoint: URL
    private let stall: TimeInterval

    public convenience init() { self.init(endpoint: Self.listURL, stall: 30) }
    /// Tests: a listener on 127.0.0.1 and a short stall.
    init(endpoint: URL, stall: TimeInterval)

    public func fetch(then done: @escaping @MainActor ([Release]) -> Void) {
        Task { done(await Self.list(at: endpoint, stall: stall) ?? []) }
    }

    @concurrent static func list(at url: URL, stall: TimeInterval) async -> [Release]? { fatalError("not implemented") }
    // TODO: session(accept: "application/vnd.github+json", stall:) → data(for: GET url) → 200 → parse; invalidate.

    /// The wire half of R4, pure: each element that is not a draft and not a pre-release, with an asset whose `state`
    /// is "uploaded", whose `browser_download_url` starts with `downloadsPrefix`, and whose `name` parses with
    /// `archiveName`; the first such asset counts. Tag, title and body are ignored. nil only when the JSON is not a
    /// release array.
    static func parse(_ json: Data) -> [Release]? { fatalError("not implemented") }

    /// "TrackpadLauncher-<version>-macOS-<minimum>.aar", the contract with every shipped version; nil for any other.
    static func archiveName(_ name: String) -> (version: Version, minimumMacOS: Version)? { fatalError("not implemented") }

    /// The download half, used by ApplicationsUpdater, kept here so the network API has one file.
    struct ArchiveDownload: Sendable {
        let stall: TimeInterval
        /// The whole archive, exactly `release.archiveSize` bytes, or nil (failed, stalled, cancelled, wrong length).
        /// `progress` pushes on the main actor, at most once per whole percent. Task cancellation cancels the request.
        func archive(of release: Release, progress: @escaping @MainActor (Double) -> Void) async -> Data? {
            fatalError("not implemented")
            // TODO: session(accept: "application/octet-stream", stall:); data(for:delegate:) with a task delegate that
            // takes the task in didCreateTask and KVO-observes its progress (a push) → fraction of archiveSize → main;
            // cancel the task once countOfBytesReceived exceeds archiveSize; withTaskCancellationHandler { cancel }.
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
    /// The whole archive, or nil; `GitHubReleases.ArchiveDownload.archive` when shipped.
    typealias Download = @Sendable (Release, @escaping @MainActor (Double) -> Void) async -> Data?
    private let download: Download
    private var job: Task<Void, Never>?
    private var isPastDownload = false

    public convenience init(replacing bundle: URL, signer: Signer) {
        self.init(replacing: bundle, signer: signer, administrator: AuthorizationAdministrator(),
                  download: GitHubReleases.ArchiveDownload(stall: 30).archive)
    }
    /// Tests: a temp "Applications", TestAdministrator, and a download that is either a local listener's
    /// `ArchiveDownload` with a short stall or a function returning the bytes on the test's own signal, so a test can
    /// place `cancelDownload()` exactly between the download's return and the next main-actor turn.
    init(replacing bundle: URL, signer: Signer, administrator: any Administrator, download: @escaping Download)

    public func update(to release: Release, events: @escaping @MainActor (UpdateEvent) -> Void) {
        isPastDownload = false
        job = Task {
            guard let archive = await download(release, { events(.progress($0)) }) else {
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
        configuration.createsNewApplicationInstance = true  // by default the old process only gets a reopen (R-3)
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
        // TODO: staged = try BundleInstall.unpack(archive, near: bundle)          else .failed
        //       CodeSignature.isGenuine(staged, as: release, signer: signer)      else discard; .failed  (before any prompt: R11)
        //       switch ApplicationsInstaller.put(staged, at: bundle, by: administrator) {
        //       .installed → .installed; .cancelled → discard, .declined; .failed → discard, .failed }
    }
}

// MARK: LauncherPlatform — the existing files, additions and changes

extension ApplicationsInstaller {
    /// The move's and the update's one swap: `BundleInstall.swap` when /Applications and `destination` are writable,
    /// else `PrivilegedInstall.swap`, which shows the prompt. Atomic on both paths; `destination` untouched unless
    /// `.installed`. Extracted from today's `copy`, whose behaviour is otherwise unchanged.
    nonisolated static func put(_ staged: URL, at destination: URL, by administrator: any Administrator) -> InstallOutcome
}

extension BundleInstall {  // BundleInstall.swift: the only file that may say AppleArchive, removexattr, itemReplacementDirectory
    /// `archive` unpacked from memory into a fresh item-replacement folder on `destination`'s volume; returns the bundle
    /// in it. Every entry is checked before it is written (`admits`); the first refused entry cancels the extraction and
    /// the folder is discarded. Quarantine is cleared on every item. Nothing at `destination` changes.
    static func unpack(_ archive: Data, near destination: URL) throws -> URL { fatalError("not implemented") }
    // TODO: ArchiveByteStream.customStream over `archive` → decompressionStream → decodeStream → extractStream(
    // extractingTo: folder, selectUsing: { message, path, data in message == .extractBegin && !admits(...) ? .cancel : .ok });
    // then clearQuarantine(under:).

    /// Pure, tested over crafted entries: a relative path equal to or under "TrackpadLauncher.app/", with no ".." and no
    /// leading "/"; a directory, a regular file, or a symbolic link whose target, resolved from the link's folder, stays
    /// inside the bundle. Anything else is refused.
    static func admits(path: String, kind: ArchiveEntryKind, linkTarget: String?) -> Bool { fatalError("not implemented") }
}

enum ArchiveEntryKind { case directory, file, symbolicLink, other }

extension CodeSignature {  // CodeSignature.swift keeps every SecCode / SecStaticCode / SecRequirement
    /// Who signed this process, when the signature truly is a Developer ID: the team and identifier an update must
    /// match. It takes no arguments, so `--as-release-build` cannot fake it. nil for Xcode, Debug, the perf build, ad hoc.
    public static func developerIDSigner() -> Signer? { fatalError("not implemented") }
    // TODO: SecCodeCopySelf; SecCodeCheckValidity(the Developer ID requirement); SecCodeCopySigningInformation → team, identifier.

    /// The same rule for a bundle on disk, so a test can hold it against `codesign -dvv` over every app in
    /// /Applications, App Store and Apple Development-signed apps (a team, but no Developer ID) included.
    static func developerIDSigner(of bundle: URL) -> Signer? { fatalError("not implemented") }

    /// R8 for a bundle on disk: the requirement above (Developer ID markers, team, identifier, notarized), checked
    /// with strict validation of every architecture, nested code and resource and kSecCSNoNetworkAccess (the stapled
    /// ticket); and its sealed Info.plist names exactly `release.version` and `release.minimumMacOS`.
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
    /// "$1" destination, "$2" staged, "$3" the exchange program; never interpolated. With something at the destination:
    /// Foundation's replaceItemAt as root, one exchange of the two directory entries; else one mv. The exit status
    /// matches what /Applications holds, and a kill at any instant leaves a whole copy there.
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
    /// Replaces today's swap(_:into:asideIn:by:): no aside copy any more.
    static func swap(_ staged: URL, into destination: URL, by administrator: any Administrator) -> InstallOutcome
    // .ran(0) → .installed; .ran(_) → .failed(applicationsFolderNotChanged); .cancelled → .cancelled; .failed → .failed(cannotWrite…)
}
```

```swift
// MARK: LauncherUI

/// The card as one rounded group, text left and its button right (R5); downloading adds the bar under the row (R7).
/// Measurements, button style and the bar's placement come from Figma node 2143-1845 at implementation.
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void
    let cancel: () -> Void
    var body: some View { fatalError("not implemented") }
    // .available(v):      Text(Copy.updateAvailable(v))   · Button(Copy.updateNowButton, action: updateNow)
    // .downloading(v, p): Text(Copy.updateDownloading(v)) · Button(Copy.cancelButton, action: cancel); ProgressView(value: p)
    // .installing(v):     Text(Copy.updateInstalling(v))
    // .failed:            Text(Copy.updateFailed)         · Button(Copy.tryAgainButton, action: updateNow)
}

// SettingsShell: init(launcher:updater:quit:), passing `updater` to SettingsView. The refit observation gains the
// card's layout:
//   Observations({ (launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn,
//                   launcher.screenRecordingHint, updater?.card?.layout) })
// TintedButtonStyle: its label reads @Environment(\.isEnabled) and renders greyed when disabled.
```

**Module map.**

| Module | Owns | New / changed |
|---|---|---|
| `LauncherCore` | `Version`, `Release` + `newerVersion`, `InstalledRelease`, `UpdateCard`, `UpdateEvent`, `Updater`, ports `ReleaseList` and `UpdateInstaller`, `Copy` strings | new model; `Launcher` (+1 init parameter, 2 edges, `closeWindow` guard); `Lifecycle` (+1 init parameter, 2 reads, 1 push) |
| `LauncherPlatform` | `GitHubReleases` (network), `ApplicationsUpdater` (sequence, LaunchServices), `BundleInstall.unpack/admits`, `CodeSignature.developerIDSigner/isGenuine` + `Signer`, atomic `PrivilegedInstall`, `ApplicationsInstaller.put`, `ThisCopy.version/macOS` | 2 new files; URL Loading in 1 file, AppleArchive in 1 file |
| `LauncherUI` | `UpdateCardView`, the card group, disabled Quit, refit | `SettingsShell` and `SettingsView` gain `updater` |
| app target | `makeUpdater`, the gate | composition only |
| `Scripts/release.sh`, `project.yml` | the release's archive and draft GitHub release | below |

**Source policy (`SourcePolicyTests`)**, the plan 002/006/021 pattern:
- **Moves from banned to confined:** `URLSession` → `GitHubReleases.swift` ("the update check and its download are the one network path").
- **New confinements:**

  | Token | Confined to | Note |
  |---|---|---|
  | `http` | `GitHubReleases.swift` | Lowercase. Catches every web address and every `http…` session setting; no Swift source mentions it today. |
  | `createsNewApplicationInstance` | `ApplicationsUpdater.swift` | "Only an update opens a second copy of itself." |
  | `AppleArchive`, `ArchiveStream`, `ArchiveByteStream`, `removexattr`, `itemReplacementDirectory` | `BundleInstall.swift` | Replaces the unused `quarantinePropertiesKey` row and names the staging folder, the two contradictions `why.md` found. |
  | `osascript` | `PrivilegedInstall.swift` | |
  | `Data(contentsOf:` | `Apps.swift` | Its one local-file reader today. |
- **Newly banned:**
  - The script no longer removes anything, so the `/bin/rm` confinement becomes a ban.
  - The obvious network bypasses: `URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier`, `String(contentsOf:`, `NSURLConnection`, `NSURLDownload`, `CFHTTP`, `import WebKit`, `WKWebView`, `curl`, `NSAppleScript`.
  - Child processes: `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`. Not `Process(`: the scan matches substrings, and `hasProcess(` and `buildOfThisProcess(` would trip it.
- **Still banned:** `import Network`, `NWConnection`, `CFSocket`, `CFStream`, `.write(to:`, `FileHandle(forWriting`, `createFile(atPath`, `Timer`, `asyncAfter`, `Task.sleep`, logging.
- **A self-check test** pins the remaining network bans by name.
- **The scan reads comments.** Core doc comments say "the network file", never a confined token.

**The release process (R14).**

`Scripts/release.sh`:

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
# Self-check, as an older version will: unpack the archive, then codesign --verify --strict --deep,
# stapler validate, and the identifier and TeamIdentifier from codesign -dv.
# ... disk image: as today (stays TrackpadLauncher.dmg, so .../releases/latest/download/TrackpadLauncher.dmg is stable) ...
gh release create "v$VERSION" "$DMG" "$AAR" --draft --target "$(git rev-parse HEAD)" \
  --title "Trackpad Launcher $VERSION" --notes "Requires macOS $MIN_MACOS or later."
echo "Draft v$VERSION created. Publish with: gh release edit v$VERSION --draft=false --latest"
```

`project.yml` sets `LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)`, so the declared minimum has one source.

**The testing seam.** Every R1, R2 and R4-R13 scenario runs at `LifecycleWorld` / `OneProcess`, synchronously. A process there is a real `Lifecycle`, `Launcher` and `Updater` over in-memory adapters, driven by the same intents the shell sends.
- `launch(_:others:alreadyExited:running:)` takes `.release("1.0.0")` or `.development`. Both go through the real `InstalledRelease` initializer, with `developerIDSigned` true or false, so the harness applies the gate rather than repeating it.
- Committed test fixtures, made once by one script with the project's own identities, so no row depends on what a Mac happens to have in /Applications:
  - a minimal app signed with the project's Developer ID, notarised and stapled: the genuine update for R8's positive case and the install rows;
  - the same app signed with the project's Apple Development identity: the signature Debug and perf builds carry, which `developerIDSigner(of:)` must reject (R2).

  `Signer` is injected, so the fixture's own team and identifier stand in.
- Handles for every boundary a test cannot wait for or provoke:

  | Boundary | Handle |
  |---|---|
  | The list's answer | `releases.deliver(_:)` and `fail()`, held until called; `fetches` counts requests |
  | The download's progress | `updates.progress(_:)` |
  | The download's end | `finishDownload()` |
  | The install outcome | `swapIn()`, which fires `onInstalled`; `decline()`; `fail()` |
  | A late event, after a cancel or from an earlier attempt | `deliverLate(_:)` |
  | `cancelDownload` | `cancels` count |
  | LaunchServices' answer | `answerOpen(started:)` |
  | The old copy's exit | the existing `letExit` |

  "No network request" is `releases.fetches == 0 && updates.requests.isEmpty`.
- The update's only lasting effect is the swap. Kill-anywhere tests snapshot around it and assert that a restored Mac opened by hand converges.

### Synthesis decision

**Base: candidate 1 (Opus).** The cross-judge independently recommended it, scoring 27 against 19. My own criterion-by-criterion read agreed. Its interface is deeper:
- one install port whose sequence keeps "verify before the prompt" and "delete the download" as one adapter's invariants;
- a model that never holds a file path;
- tickets that drop late results without trusting an adapter's cancel contract;
- an archive-entry filter before verification;
- source tokens that do not trip on today's code;
- a gate that rejects Debug and perf builds, which are Apple Development signed under the release team.

**Convergence.** Both candidates independently reached the same overall shape:
- a third `Updater` model told of the window's edges by `Launcher`;
- two ports;
- the release list read once from GitHub, with the minimum macOS in the asset name;
- an Apple Archive asset unpacked in-process;
- `createsNewApplicationInstance` for the open;
- an atomic `osascript` exchange for the administrator path, shared with the move.

This is shipped as the consensus.

**Grafted from candidate 2:**
- **The old copy ends itself once LaunchServices reports the new one started** (`onReplaced` → `Lifecycle.end()`). This replaces candidate 1's waiting to be stopped, which leaves Quit disabled indefinitely if the new version dies at start. Plan 021 rejected the same thing for the mover. The cross-judge named it the one structural graft.
- **Its source-scan additions:**
  - `Data(contentsOf:` confined to `Apps.swift`;
  - bans on `URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier` and `String(contentsOf:`.

**Fixed while re-deriving the base:**
- The refit key `layout` was used but never defined. It is now `UpdateCard.Layout`, the card with its progress erased.
- Two of the base's unprobed claims were checked after fan-out (`checks/checks.out`): AppleArchive extracts from in-memory `Data` through a custom byte stream, and its selection hook's `.cancel` stops the extraction; an `-exclude-field xat` archive unpacks with clean attributes and verifies.
- `notarized` with `kSecCSNoNetworkAccess` passes on a stapled app (`checks/nonetwork-notarized.out`). The base's planned test "an unstapled notarised app fails offline" was dropped: an unstapled app with a cached ticket also passes, so that test would be unreliable.

**Rejected from candidate 2:**
- Its `Process(` ban, which would fail on `hasProcess(` and `buildOfThisProcess(`.
- Its team-presence gate, which lets Debug and perf builds check.
- `windowOpened` guarded on `.idle`, which skips the check after an outcome that arrived while the window was closed.
- A file path carried by the model between two ports.
- A `Version` whose `==` and `<` disagree.
- A refit on every progress push.
- "Exactly one uploaded asset", which would hide a future release carrying two.
- A login-item handover on every update. That is kept as open question 1, not decided silently.

### Tradeoffs accepted

- We accept the whole archive in memory (a few MB), in exchange for nothing on disk until it has all arrived. A Quit, crash or logout mid-download then leaves nothing to delete.
- We accept that the old copy ends once LaunchServices reports the new one started, before the new one has stopped it. In exchange, the old copy never lingers with Quit disabled when the new version dies at start. A new version that dies leaves no Trackpad Launcher running until the next opening or login, with the new version whole in /Applications.
- We accept that after a successful swap whose open macOS refuses, the card reads "couldn't be installed" although /Applications holds the new version, and the old process, still running, would load any resource it reads afresh from the new bundle. R12 names this case. *Try again* converges with a same-version swap and a second open.
- We accept running `osascript`'s JavaScript bridge as root in the administrator path, and changing the move's script with it. In exchange, one atomic exchange closes the two-rename gap for both flows, as R13's restart scenario requires.
- We accept not touching the login item on an update, gated on a manual check (open question 1). In exchange, no "login item added" notice appears on every release.
- We accept the asset name `TrackpadLauncher-<v>-macOS-<min>.aar` and the repository path as a permanent contract with every shipped version. In exchange, the version and minimum macOS are machine-written from the app's own Info.plist and parsed from the one request R3 allows.
- We accept that only the 30 newest releases are seen, because R3 forbids a query string. A copy more than 30 releases behind still gets the highest of those 30.
- We accept a request's own idle timeout as the one deadline that is not a Core Animation animation, in exchange for the app having no timer of its own.
- We accept that only a real Developer ID build in /Applications can exercise the network path by hand; `--as-release-build` cannot. Development builds are covered by the local-listener platform tests.
- We accept that a staging folder left in the system's temporary items after a crash mid-install stays until macOS clears that folder. This is assumed, not probed. In exchange, there is no startup sweep of our own.
- We accept that a release takes two commands (build and draft, then publish), in exchange for the developer inspecting the assets before every older copy sees them.

### Alternatives considered

- **The install as a `Lifecycle` stage, with the check and the download in `Launcher`.** One state machine split across two models by phase (temporal decomposition): the card would derive from two sources and the stale-result logic would be duplicated. Both interfaces grow, and nothing gets deeper.
- **Fold the update into `Launcher`.** `Launcher` would learn `Build`, `Placement`, versions and the quit policy, which is exactly what the plan 021 split prevents. It exposes process concerns to every `Launcher` caller.
- **A port per step (list, download, verify, unpack, swap, open).** A shallow interface: the model would sequence platform steps and carry a downloaded file's path across ports. Every caller would then have to remember to delete it, and "verify before the prompt" would become model coordination rather than one adapter's invariant.
- **The old copy waits to be stopped by the new one.** No callback from `Updater` to `Lifecycle`. But a new version that dies at start leaves the old one installing forever with Quit disabled, which plan 021 rejected for the mover.
- **Asset format.**
  - *The DMG:* verifying before mounting is strong, but it needs an `hdiutil` child process, leaves mount state behind after a crash, and its `notarized` check on a disk image is unprobed.
  - *A `ditto` zip:* needs a child process with unknown traversal behaviour.
  - *The Apple Archive* won: in-process, probed whole, with our own entry filter.
- **Minimum macOS in the release body, a manifest asset, or `/releases/latest`.** The body is hand-edited prose. A manifest is a second request, which R3 forbids. `latest` ignores the minimum macOS.
- **Sparkle.** It brings its own network code outside the scan, dialogs (a non-goal), an appcast to host and XPC installers. It is far wider than the one narrow exception the product owner granted.

### Open questions and risks

1. **The login item (O2).** Does the `SMAppService.mainApp` login item survive a same-path, same-team replacement? If the first real update shows it was lost, should the update adopt the move's `suspend()` / `resume()` hand-over, accepting a possible "login item added" notice per update? The fallback is one effect inserted before `openNewVersion`.
2. **The permissions (O3).** Do the Accessibility and Screen Recording grants survive in practice? The designated requirement says yes on paper. A loss could not be re-asked under R10, so should the release checklist require a hand check on the first real update?
3. **The atomic administrator swap.** Does `osascript -l JavaScript` run as root through `AuthorizationExecuteWithPrivileges` without a further prompt? It was probed only unprivileged. Is changing the move's script in this plan acceptable, or should the move keep its two `mv`s until the new script has run by hand?
4. **Publishing.** Should `release.sh` stop at a draft, as designed, or publish in the same command?
5. **Immutable releases.** Should the repository turn on GitHub's immutable releases, so a published archive can never be swapped afterwards?
6. **The card's look (O1).** The Figma node was not inspected in this session. Should its downloading, installing and failed states be confirmed before the UI slice?
7. **Risk, accepted: an old copy whose new version macOS will not open keeps running over the new bundle** (R12's last case). A check after fan-out (`checks/after-swap/after-swap.out`) shows such a process keeps running. It reads every resource's contents afresh from the new bundle, still believes a resource only the old version had exists, and keeps its cached Info.plist. Gestures live in memory, so only illustrations read afresh can show the new version's art or none. No row covers it, because macOS cannot be made to refuse the open on demand.
8. **Risk: the hand-over path is unproven on a real release.** The self-replace-and-open was probed with ad-hoc bundles in /tmp. The first real release is the first run with a notarised app in /Applications, on top of a move and administrator path that have also never run end to end.

### Next implementation step

Slice S1. Extract `ApplicationsInstaller.put(_:at:by:)` from today's `copy`, and turn `PrivilegedInstall.script` into the one atomic exchange (`osascript -l JavaScript` running Foundation's replace, or a single `mv` when nothing lies at the destination). Rewrite `PrivilegedInstallTests` for the script without an aside, and keep the move's suites green through `put`. S2, starting with `Version`, `Release.newerVersion` and the `InstalledRelease` gate, can run alongside.

## Testing Decisions

### Strategy

The requirements are proven at four seams, highest first. Each resembles an existing suite.

1. **The model seam, `LifecycleWorld` / `OneProcess`**, as in `LifecycleTests.swift` and `MoveToApplicationsTests.swift`. A process there is a real `Lifecycle`, `Launcher` and `Updater` over in-memory adapters, driven synchronously by the intents the shell sends. Every R1, R2, R4-R7 and R9-R13 scenario runs here.
   - `launch(_:others:alreadyExited:placement:running:)` takes `.release("1.0.0", macOS: "26.0")` or `.development`. Both go through the real gate, `InstalledRelease(placement:developerIDSigned:version:macOS:)`, with `developerIDSigned` true or false. Where it answers nil, the process has no `Updater`. The harness applies the rule rather than repeating it.
   - Each intent appends `(window, card, isInstalling)` to the process's `history`. Rows about "at no moment" read every published state, in order.
   - `InMemoryReleaseList` counts `fetches` and keeps each fetch's completion in order.
     - `deliver(_:)` answers the oldest fetch still open.
     - `deliver(_:toFetch:)` answers the fetch it names.
     - `fail()` answers `[]`.
     - `answersInline(_:)` makes the next fetch answer inside the call.
   - `InMemoryUpdateInstaller` records `requests` and keeps every attempt's event sink.
     - `progress(_:)`, `finishDownload()`, `swapIn()`, `decline()` and `fail()` speak for the live attempt. `swapIn()` runs `onEffect` and `onInstalled` before it delivers `.installed`, as `InMemoryInstaller.release(.installed)` does.
     - `deliverLate(_:attempt:)` replays an event into an earlier attempt.
     - `failsInline()` makes the next attempt fail inside `update(to:events:)`.
     - `cancels` counts `cancelDownload()` calls.
     - `opens` counts `openNewVersion` calls, which `answerOpen(started:)` answers.
   - "No network request" here means `releases.fetches == 0 && updates.requests.isEmpty`.
   - This seam misses the real adapters, the composition root's gate and the view.
2. **The release list, `GitHubReleases.fetch`**. Rows build it with `init(endpoint:stall:)`, pointed at a local server.
3. **The update, `ApplicationsUpdater.update(to:events:)` and `cancelDownload()`**, as in `ApplicationsInstallerTests.swift` and `PrivilegedInstallTests.swift`. Rows build it with `init(replacing:signer:administrator:download:)` from these parts:
   - a `BundleFixture` 1.0.0 bundle named `TrackpadLauncher.app` in a temp "Applications";
   - `TestAdministrator`;
   - a `Download` function. It is usually `GitHubReleases.ArchiveDownload(stall: 1).archive`, fetching a `Release` whose `archive` is on the local server. Where a row must place a cancel exactly, it is instead a function that returns the archive's bytes when the row releases them.

   Every row checks the event log against `UpdateEvent`'s order. Rows go below this seam only where it cannot see:
   - `BundleInstall.admits` and `unpack`. An archive that fails verification never shows whether it unpacked whole.
   - The shared swap, `ApplicationsInstaller.put` and `PrivilegedInstall.swap`. A restart can be simulated only by killing the script's own process, and the in-process swap can only be watched.
4. **The gate.** The rule is the pure `InstalledRelease.init?(placement:developerIDSigned:version:macOS:)`, which the composition root and the harness both call. Its signing input comes from `CodeSignature.developerIDSigner(of:)`, the same rule as `developerIDSigner()` applied to a bundle on disk. That function is cross-checked against `codesign -dvv`, as `CodeSignatureTests.swift` does for `build(of:)`. `makeUpdater`, in the app target, only passes `developerIDSigner() != nil`; C2 checks that by grep.

`SourcePolicyTests.swift` proves the structural rules.

Faked boundaries:
- **GitHub** is a `LocalReleaseServer`: a test-only HTTP/1.1 server on 127.0.0.1, built on `NWListener`. Tests are not source-scanned, so it may use the network framework.
  - Per path, it answers a scripted status, headers and body.
  - It can hold a body in chunks that the row releases one at a time, trickle a body, close the connection mid-body, or redirect with a 302.
  - It records each request's line, headers and body, and notices when the client closes the connection.
  - The real GitHub hosts appear only in manual checks.
- **The clock.** The app owns no clock. Its one deadline is URLSession's idle timeout. Rows inject a 1 s stall through the internal initialisers, and one row runs the shipped 30 s.
- **LaunchServices, other running copies, the login item and permissions** use the in-memory adapters that seam 1 already has.
- **The administrator prompt** is `TestAdministrator`. It runs the real script unprivileged, or answers cancelled or failed, and records the paths it was handed.
- **A genuine release** is a committed fixture, made once by a fixture script:
  - The fixture is a minimal app named `TrackpadLauncher.app`, with its own bundle identifier. It is signed with the project's own Developer ID, notarised and stapled, and archived with release.sh's `aa archive` line.
  - Beside the archive, the script records the fixture's version, minimum macOS, team, identifier and file manifest. Rows take their expected values from that record, and inject the `Signer` from it.
  - The script also commits a copy of the fixture signed with the project's Apple Development identity, so that T35 always sees the signature that Debug and perf builds carry.

  Every row that needs a genuine app runs on every Mac.
- **Disk checks.**
  - Each ad-hoc fixture app carries a file with a unique name, so a row can search the temporary folder for any unpacked copy left behind.
  - Rows built from the committed fixture search for any bundle with the fixture's identifier. Their suites are serialised.
  - "Nothing written mid-download" means that no `CFNetworkDownload_*` file appears in the temporary folder (probe N5).

Everything else runs for real: `Version`, `Release`, the three models, `StartAtLogin`, `SettingsStore` on a throwaway suite, AppleArchive, Security's static-code checks, FileManager on temp folders, the script and `osascript`.

### Test scenarios

Model rows run on this Mac's macOS 26.0 and use releases that need macOS 26.0, unless the row says otherwise.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R5 | `LifecycleWorld` | **Given** 1.0.0 started at login, with its window closed and the release list held (variant: the list answers inside `fetch`). **When** it is opened by hand. **Then** the first published state is `.open(request: 1)`, with `fetches == 1` and `card == nil`, and the card stays nil until the answer. `deliver([1.1.0])` (the inline variant: at once) gives `.available(1.1.0)`, which `Copy` renders as "App version 1.1.0 is available" with "Update now". | R1 "A newer version is out"; R5's text |
| T2 | R1 | `LifecycleWorld` | **Given** the window opened and its check answered `[]`. **When** the user opens it by hand twice more, taps every gesture, flips Accessibility and changes a trackpad preference, and macOS sends a login reopen. **Then** the window goes to `.open(request: 2)`, then `.open(request: 3)`, `fetches` stays 1, and no card shows. **When** the window is closed and opened again, and that check answers [1.1.0]. **Then** `fetches == 2` and the card shows. | R1 "Reopening an open window" and "A version released while the window stays open": one check per closed-to-open edge |
| T3 | R1 | `LifecycleWorld` | **Given** an opening's check held. **When** (a) the window closes, then that check answers [1.1.0]; or (b) the window closes and reopens in the same turn (the second check held), then the first check answers [1.1.0] and the second answers `[]`. **Then** the card is nil at every published state of both runs, and `fetches` is 1 in (a) and 2 in (b). A further opening whose check answers [1.1.0] shows the card. | R1: "A check still running when the window closes MUST be dropped, and its result MUST NOT be kept" |
| T4 | R6, R1 | `LifecycleWorld` | **Given** 1.0.0. **When** the opening's check fails (`fail()`). **Then** no card shows and no other state changes. **When** the window is closed and opened again, and the check answers [1.1.0]. **Then** `fetches == 2` and the card shows. | R6 "Offline" |
| T5 | R4 | `LifecycleWorld` | One opening per case, given as running version, this Mac's macOS and the delivered list, then the card:<br>- 1.0.0, 26.0, [1.1.0, 1.2.0 needing 27.0] → 1.1.0<br>- 1.9.0, 26.0, [1.10.0] → 1.10.0, rendered "App version 1.10.0 is available"<br>- 1.0.0, 26.0, [1.2.0, 1.10.0, 1.9.0] → 1.10.0<br>- 1.0.0, 26.0, [1.1.0 needing 27.0] → no card<br>- 1.1.0, [1.1.0] → no card<br>- 1.1, [1.1.0] → no card<br>- 1.1.0, [1.0.5] → no card<br>- 1.0.0, 26.6.2, [1.1.0 needing 26.6.2] → 1.1.0<br>- 1.0.0, 26.6.2, [1.1.0 needing 26.6.3] → no card | R4's scenarios; the boundary where the minimum equals this Mac's macOS |
| T6 | R2 | `LifecycleWorld` | **Given** a 1.0.0 release build in /Applications, with the login item on and a newer version released. **When** macOS starts it at login and a day passes: every gesture tapped, a permission flipped, a trackpad changed, a login reopen. In a second process, the window opens, its check answers, the window closes, and the same day passes. **Then** in the first process `fetches == 0` and `requests` is empty throughout. In the second, `fetches` is 1 (the opening's check) and stays 1. | R2 "Login start" |
| T7 | R2 | `LifecycleWorld` | **Given** a copy that may not check:<br>- (a) `.release("1.0.0")` at `.elsewhere`, started at login from ~/Applications. Gestures are used, then it is opened by hand (the move dialog asks), and the user answers *Quit*.<br>- (b) `.release("1.0.0")` opened by hand from ~/Downloads, with the dialog unanswered.<br>- (c) `.development`, opened by hand at `.installed` (a Debug or perf build in /Applications, or one started with `--as-release-build`) and at `.development` (one run where it was built).<br>**When** each runs its course. **Then** none has an `Updater`, because the real `InstalledRelease` initializer answers nil. No request is made at any step. (c) opens its window and shows no card, and (a) ends. | R2 "Development build", "Release build outside /Applications" and "Move dialog" |
| T8 | R1, R5, R7, R9, R10 | `LifecycleWorld` | **Given** 1.0.0 opened by hand, with Arc on the 1-finger gesture, the login item on, Accessibility granted, and the check answering [1.1.0]. **When** *Update now*. **Then** the card is `.downloading(1.1.0, progress: 0)`, rendered "Downloading version 1.1.0…" with "Cancel". **When** `progress(0.4)`, then a 1-finger tap. **Then** the card is `.downloading(1.1.0, progress: 0.4)` and Arc comes to the front. **When** `finishDownload()`, then a tap. **Then** the card is `.installing(1.1.0)` ("Installing version 1.1.0…"), `isInstalling` is true, and Arc comes to the front. **When** `swapIn()`, then a tap. **Then** the card still reads installing, `opens == 1`, and Arc comes to the front. **When** `answerOpen(started: true)`. **Then** the old copy has ended. **When** the 1.1.0 process is opened by hand, with the old copy (a) already exited or (b) still listed until `letExit`. **Then** its window is `.open(request: 1)`, `fetches == 1`, and [1.1.0] leaves no card. Throughout: the login item stays on with no call, nothing is asked, the suite at the swap and at the end equals the suite before *Update now*, and the new process's 1-finger row is Arc. | R9 "The new version opens" and "Gestures during the download"; R10 "Successful update"; the world's seeded record |
| T9 | R7 | `LifecycleWorld` | **Given** 1.1.0 downloading at 40%. **When** *Cancel*. **Then** the card is `.available(1.1.0)` and `cancels == 1`. A late `.progress(0.6)` or `.downloaded` from that attempt changes nothing, nothing is swapped, the process keeps running and gestures work. **When** *Update now*. **Then** `requests.count == 2` and the card is `.downloading(1.1.0, progress: 0)`. | R7 "Cancelling a download" |
| T10 | R7, R13 | `LifecycleWorld` | **Given** each of these states in turn: available; installing, after `finishDownload()` landed first; opening; failed. **When** *Cancel*. **Then** the card is unchanged and `cancels == 0`. Over the history of the T8 run plus one failure and one decline, `card` is `.installing` exactly when `isInstalling` is true. | R7 "*Cancel* MUST exist only in the downloading state"; R13 "During the installing state, *Quit Trackpad Launcher* MUST be disabled" |
| T11 | R13 | `LifecycleWorld` | **Given** 1.1.0 downloading at 40%, with the window open. **When** (a) *Close*; or (b) the Dock's Quit (`shouldEnd(.other)`). **Then** the window closes, (b) answers false, and `cancels == 1`. A late `.downloaded` installs nothing, 1.0.0 keeps running with its gestures, and the next opening's check, answering [1.1.0], shows "App version 1.1.0 is available". **When** (c) *Quit Trackpad Launcher*. **Then** the process ends at once, with nothing swapped. | R13 "Closing the window mid-download" |
| T12 | R13 | `LifecycleWorld` | **Given** 1.1.0 installing with the window open, and separately 1.1.0 opening (after `swapIn()`). **When** *Quit Trackpad Launcher*. **Then** nothing happens: the process keeps running and the window stays open. **When** *Close Settings* (⌘Q) or the Dock's Quit. **Then** the window closes, the quit answers false, the card stays installing, and `cancels == 0`. **When** an ordinary quit arrives with the window closed. **Then** it answers false and the process keeps running. **When** a logout arrives (`.system`). **Then** it answers true. | R13's quit rules |
| T13 | R13, R1 | `LifecycleWorld` | **Given** 1.1.0 installing. **When** *Close*, then an opening by hand before the swap, then *Close* and an opening again after `swapIn()`. **Then** each time, the window closes and reopens showing `.installing(1.1.0)`, and `fetches` is unchanged. **When** `answerOpen(started: true)`. **Then** the old copy ends, and the 1.1.0 process, opened by hand, opens its window. | R1, amended: "except an opening while an update installs (R7's installing state): the card then keeps showing the install, and that opening makes no check"; R13 "Closing the window while installing" |
| T14 | R10, R13 | `LifecycleWorld` | **Given** 1.0.0 with a saved record and the login item on. **When** the T8 run is cut at each snapshot taken around its effects (the swap's `onEffect` and `onInstalled`). **Then** a Mac restored from each snapshot, and opened by hand as 1.0.0 (before the swap) or 1.1.0 (after it), opens its window and checks once. It keeps the seeded record and the login item on, makes no login-item call and asks for nothing. | The snapshot taken before the update; `MoveToApplicationsTests`' kill-anywhere pattern |
| T15 | R12 | `LifecycleWorld` | **Given** 1.1.0 downloading at 40%. **When** the download fails (variant: the installer fails inside `update(to:events:)`). **Then** the card is `.failed(1.1.0)`, rendered "The update couldn't be installed." with "Try again"; the process keeps running and gestures work. **When** *Try again*. **Then** the card is `.downloading(1.1.0, progress: 0)` and `requests == [1.1.0, 1.1.0]`. A late `.progress` or `.downloaded` from the first attempt changes nothing, and the second attempt reaches installing. | R12 "Connection lost mid-download" and "Trying again"; R12: "A failure before the new version is in place MUST leave the running version installed and working" |
| T16 | R12 | `LifecycleWorld` | **Given** 1.1.0 installing. **When** (a) the install fails before the new version is in place (the swap failed); (b) `swapIn()` puts the new version in place, then LaunchServices answers that it did not start the app; or (c) the window closes during the install, the swap then fails, and the window opens again. **Then** in (a) and (b), the card is `.failed(1.1.0)`, rendered "The update couldn't be installed." with "Try again". `isInstalling` is false, the process keeps running, gestures work, and Quit ends the process again. In (b), *Try again* makes a second request for 1.1.0; after `finishDownload()` and `swapIn()`, a second open follows (`opens == 2`), and `answerOpen(started: true)` ends the old copy. In (c), the opening checks (`fetches` + 1) and shows no card until the answer. | R12 "Replacing the app fails"; R12: "When the new version is in place but macOS does not open it, the card MUST read the same failed text with *Try again*, the running version MUST keep working until it ends, and *Try again* MUST put the new version in place again and open it" |
| T17 | R11 | `LifecycleWorld` | **Given** 1.1.0 installing, downloaded and verified. **When** (a) the administrator prompt is cancelled (`decline()`); or (b) the window closes during the install, the prompt is cancelled, and the window opens again. **Then** in (a) the card is `.available(1.1.0)` with *Update now*. There is no failed card, nothing is swapped, Quit is enabled and gestures work. In (b) the opening checks again and shows no card until the answer. | R11 "Standard account cancels the prompt" |
| T18 | R4, R14 | `GitHubReleases.fetch` | **Given** the server answers the list with a JSON fixture shaped like GitHub's documented "List releases" response. It holds:<br>- a published 1.1.0 with the DMG and `TrackpadLauncher-1.1.0-macOS-26.0.aar`, "uploaded", under the repository's download prefix;<br>- a draft 1.3.0;<br>- a pre-release with `TrackpadLauncher-1.1.0-beta-macOS-26.0.aar`;<br>- a full release with `TrackpadLauncher-1.2.0-beta-macOS-26.0.aar`;<br>- a release with only the DMG;<br>- `TrackpadLauncher-1.4.0.aar`, which declares no minimum;<br>- an asset whose state is "open";<br>- an asset whose URL is another repository's;<br>- `TrackpadLauncher-v1.5.0-macOS-26.0.aar`;<br>- `TrackpadLauncher-1.1234567890.0-macOS-26.0.aar`;<br>- `TrackpadLauncher-1.123456789.0-macOS-26.0.aar`;<br>- a release tagged `v9.9.9` whose asset is 1.6.0.<br>**When** fetched. **Then** `done` runs once, on the main actor, with exactly three releases: 1.1.0 (needing 26.0, with the aar's URL and size), 1.123456789.0, and 1.6.0. | The fixture and its expected list, written by hand from GitHub's schema (`sources/github-rest-releases.md`, probe G3) and the asset-name contract |
| T19 | R3 | `GitHubReleases.fetch` | **Given** the server's first answer sets `Set-Cookie`, `Cache-Control: max-age=3600` and an `ETag`. **When** two checks run, one after the other. **Then** the server receives two requests, identical to each other and to the expected request. That request is `GET /repos/domasgru/trackpad-launcher/releases`, with no query string and no body. Its headers are exactly User-Agent `TrackpadLauncher`, Accept-Language `en`, Accept `application/vnd.github+json` and X-GitHub-Api-Version `2022-11-28`, besides the transport headers CFNetwork adds over plain HTTP (Host, Accept-Encoding, Connection). Neither request carries Cookie, If-None-Match or If-Modified-Since. | R3: beyond the address, the time and what the system adds to every connection, "the request's address, the headers Trackpad Launcher sets, and the body MUST be the same on every Mac and every version". The expected request is therefore the design's constant one, compared exactly; probe N1 lists the defaults it replaces |
| T20 | R6 | `GitHubReleases.fetch` | **Given** (a) nothing listening on the port; (b) status 403, 404 or 500; (c) a body that is not JSON; (d) a JSON object rather than an array; or (e) a server that accepts and never answers, with a 1 s stall. **When** fetched. **Then** `done` runs once with `[]`: at once for (a)-(d), and no sooner than 1 s for (e). | R6: "fails, for example offline or with no answer" |
| T21 | R7, R8, R9, R12 | `ApplicationsUpdater.update` | **Given** the committed fixture's archive, served in four quarters that the row releases one at a time. **When** updated over the 1.0.0 bundle; variant: over a bundle that already is the fixture, as after an open that macOS refused. **Then** progress rises in whole percents and reaches 0.25, 0.5, 0.75 and 1.0 as each quarter is released, followed by `.downloaded`, then `.installed`. The old path holds the fixture's recorded manifest, with no quarantine attribute, and the administrator was never asked. | The fixture generator's record (manifest, version, minimum, team, identifier); `xattr -r`; the quarter sizes; R12: "*Try again* MUST put the new version in place again" |
| T22 | R7, R11, R13, R3 | `ApplicationsUpdater.update` | **Given** an ad-hoc fixture archive, a read-only "Applications", and a server that sends 40% and holds. **When** the events reach progress 0.4, the row calls `cancelDownload()`, and then the server releases the rest. **Then** the server sees the client close the connection, and no event follows 0.4. The administrator was never asked, the old bundle is unchanged, no `CFNetworkDownload_*` file appeared, and no copy holding the marker exists. **When** `update(to:events:)` runs again, without the hold. **Then** it reaches `.downloaded` and one outcome. | R7: "*Cancel* MUST stop the download ... with nothing changed"; R11: "never before" |
| T23 | R7, R13 | `ApplicationsUpdater.update` | **Given** an ad-hoc fixture archive, and an injected `Download` function that ignores cancellation and returns the archive's bytes when the row releases them. **When** (a) the row releases the bytes and calls `cancelDownload()` in the same main-actor turn, before yielding; or (b) the row calls `cancelDownload()` from inside the `.downloaded` event. **Then** in (a), neither `.downloaded` nor any later event arrives, nothing is unpacked, and the old bundle is unchanged. In (b), exactly one outcome (`.failed`) follows `.downloaded`. | `UpdateEvent`'s documented order; R7: "*Cancel* MUST stop the download ... with nothing changed" |
| T24 | R3 | `ApplicationsUpdater.update` | **Given** the archive path answers with a 302 to another path on the server, setting `Set-Cookie`. **When** updated. **Then** the request and the redirected request both carry exactly User-Agent `TrackpadLauncher`, Accept-Language `en`, Accept `application/octet-stream`, X-GitHub-Api-Version `2022-11-28` and the transport headers. Neither carries a Cookie or a body, and the download completes. | R3: "the request's address, the headers Trackpad Launcher sets, and the body MUST be the same on every Mac and every version", compared exactly against the design's constant headers; probes G6 (one redirect) and N2 |
| T25 | R8, R11, R3 | `ApplicationsUpdater.update` | **Given** a read-only "Applications" and an archive holding one of:<br>- (a) an ad-hoc fixture app;<br>- (b) the committed fixture, with a `Signer` naming another team;<br>- (c) the committed fixture, with another identifier;<br>- (d) the committed fixture, with a `Release` naming 1.0.5 while the fixture is another version;<br>- (e) the committed fixture, with another minimum macOS;<br>- (f) the committed fixture, unpacked, one resource byte changed, and archived again with release.sh's line.<br>**When** the download finishes. **Then** the events end with `.downloaded`, then `.failed`. The old bundle is unchanged, the administrator was never asked, and no unpacked copy (the ad-hoc marker, or a bundle with the fixture's identifier) remains in the temporary folder. | R8 "Tampered download" and "Wrong version downloaded"; the fixture generator's record |
| T26 | R8, R3 | `ApplicationsUpdater.update` | **Given** archives written with the AppleArchive encoder, each holding the fixture app plus one extra entry:<br>- `Other.app/x`;<br>- `TrackpadLauncher.app/../escape`;<br>- an absolute path into a sentinel folder;<br>- `TrackpadLauncher.appx/x`;<br>- the symlink `TrackpadLauncher.app/Contents/out`, pointing at the sentinel folder, followed by `TrackpadLauncher.app/Contents/out/pwned`;<br>- a FIFO.<br>**When** each is downloaded. **Then** the events end with `.failed`. The sentinel folder stays empty, the old bundle is unchanged, the administrator is never asked, and no copy holding the marker remains. | The crafted entries |
| T27 | R11, R3 | `ApplicationsUpdater.update` | **Given** the committed fixture's archive and an administrator who (a) cancels, with a read-only "Applications"; (b) cancels, with a read-only old bundle; or (c) runs the real script unprivileged. **When** updated. **Then** in (a) and (b), the administrator is asked once, after `.downloaded` in one shared log. The events end with `.declined`, the old bundle is unchanged, and the staged path the administrator was handed (`$2`) and its folder are gone. In (c), the events end with `.installed`, the old path holds the fixture's recorded manifest, and the folder of `$2` is gone. | R11's scenario; `TestAdministrator`'s record; the fixture generator's record |
| T28 | R12, R3 | `ApplicationsUpdater.update` | **Given** an ad-hoc fixture archive of N bytes, declared as N, with a 1 s stall. **When** the server:<br>- (a) closes after 40%;<br>- (b) sends N−1 bytes and ends;<br>- (c) sends N+1 bytes;<br>- (d) sends exactly N bytes;<br>- (e) answers 404;<br>- (f) sends 40% and holds;<br>- (g) sends a chunk every 0.5 s for 3 s.<br>**Then** (a), (b), (c) and (e) end with `.failed`, with no `.downloaded`. (f) ends with `.failed`, no sooner than 1 s after its last byte. (d) and (g) reach `.downloaded`. After each failure, no `CFNetworkDownload_*` file and no copy holding the marker exists. | R12; probe N3 (the timeout measures idle time, not total time) |
| T29 | R12 | `ApplicationsUpdater`, as shipped | **Given** `ApplicationsUpdater(replacing:signer:)`, as the composition root builds it, and a `Release` whose archive the server sends 40% of and then holds. **When** updated. **Then** `.failed` arrives no sooner than 30 s and no later than 35 s after the last byte. | R12's literal 30 seconds |
| T30 | R8 | `BundleInstall.admits` | One case per entry (path, kind and link target), then admitted or refused.<br>Admitted:<br>- `TrackpadLauncher.app` (a directory);<br>- `TrackpadLauncher.app/Contents/Info.plist` (a file);<br>- `TrackpadLauncher.app/Contents/Frameworks/X.framework/Versions/Current`, linking to `A`;<br>- `.../X.framework/X`, linking to `Versions/Current/X`.<br>Refused:<br>- "" and ".";<br>- `Other.app`;<br>- `TrackpadLauncher.appx/a`;<br>- `../x`;<br>- `TrackpadLauncher.app/../x`;<br>- `TrackpadLauncher.app/a/../../x`;<br>- `/TrackpadLauncher.app/x`;<br>- a link to `/etc`;<br>- `TrackpadLauncher.app/Contents/l`, linking to `../../x`;<br>- any `.other` kind. | The design's admission rule; a framework's standard symlink layout |
| T31 | R14, R9 | `BundleInstall.unpack` | **Given** a fixture app (a nested folder, a symlink, and quarantine on every item), archived with release.sh's line `aa archive -d … -subdir TrackpadLauncher.app -exclude-field uid,gid,xat,acl,flg`. **When** unpacked near a destination in a temp folder. **Then** it returns `TrackpadLauncher.app` in a new folder on that volume, with the source's manifest and no quarantine attribute, and the destination is untouched. The committed fixture's archive, made by the same line, unpacks to its recorded manifest. | `BundleFixture.manifest`; `xattr -r`; the fixture generator's record |
| T32 | R13, R12 | `PrivilegedInstall.swap`'s script | **Given** 1.0.0 at the destination and 1.1.0 staged on its volume, repeated 100 times. **When** the real script runs unprivileged in its own process group, and is killed with SIGKILL at a random moment within twice its measured run time. **Then** the destination holds either the old manifest or the new one, never neither and never a mix. It holds the new one whenever the script exited 0 before the kill. The folder holds exactly one app. | `BundleFixture` manifests; the script's exit status, as its own log |
| T33 | R13, R12 | `ApplicationsInstaller.put` | **Given** a writable destination, and an observer thread reading both marker files through one directory handle as fast as it can. **When** 200 calls put 1.0.0 and 1.1.0 in, alternately. **Then** no observation finds the destination missing, unreadable or mixed. | The fixtures' markers; the method of probe R-1 |
| T34 | R11, R12 | `ApplicationsInstaller.put` | **Given** a read-only destination folder or bundle. **When** (a) the administrator cancels; (b) the script fails, because the staged copy is removed before it runs; (c) the real script runs with paths holding quotes, spaces and `$(touch pwned)`; or (d) nothing lies at the destination. **Then** (a) gives `.cancelled` and (b) gives `.failed`. (c) and (d) give `.installed`, with the staged manifest at the destination and no `pwned` file. In every case the destination is the old copy or the new one, whole, and the staged path and its folder are gone. The move's existing `install` rows stay green through `put`. | `BundleFixture` manifests; the existing `PrivilegedInstallTests` |
| T35 | R1, R2 | `InstalledRelease.init?`, `CodeSignature.developerIDSigner` | **Given** the pure gate, `InstalledRelease(placement:developerIDSigned:version:macOS:)`. **Then** it is nil:<br>- with `developerIDSigned: false` at `.installed` (a development build in /Applications, or one started with `--as-release-build`);<br>- at `.elsewhere` and at `.development`, even when signed;<br>- for the versions nil, "" and "1.0.0-beta".<br>At `.installed`, signed, with "1.0.0", it holds 1.0.0 and the given macOS.<br>**Given** the ad-hoc-signed test runner. **Then** `developerIDSigner()` is nil, while `buildOfThisProcess(arguments: ["--as-release-build"])` is `.release`.<br>**Given** every app in /Applications and /System/Applications, the committed Developer ID fixture, and its committed Apple Development copy. **Then** `developerIDSigner(of:)` gives a signer exactly when `codesign -dvv` names a "Developer ID Application" authority, with `codesign`'s TeamIdentifier and Identifier. App Store apps (a team, but no Developer ID), Apple's own apps and the Apple Development copy give nil. | R1's definition of a release build; R2's development build and copies outside /Applications; `codesign -dvv` as an independent reader; the fixture generator's record |
| T36 | R13 | `SourcePolicyTests` | `osascript` is confined to `PrivilegedInstall.swift`, `/bin/rm` is banned, and the scan passes. | The design's token table |
| T37 | R1, R2, R3, R12 | `SourcePolicyTests` | `URLSession` and `http` are confined to `GitHubReleases.swift`, and `Data(contentsOf:` to `Apps.swift`. The listed network bypasses and child-process tokens are banned. `Timer`, `asyncAfter`, `Task.sleep`, `.write(to:`, `createFile(atPath` and `FileHandle(forWriting` stay banned. The self-check finds every remaining network ban by name. | The design's token table |
| T38 | R9, R3 | `SourcePolicyTests` | `createsNewApplicationInstance` is confined to `ApplicationsUpdater.swift`. `AppleArchive`, `ArchiveStream`, `ArchiveByteStream`, `removexattr` and `itemReplacementDirectory` are confined to `BundleInstall.swift`, replacing the `quarantinePropertiesKey` row. | The design's token table |
| T39 | R5 | `UpdateCard.layout` | `.downloading(v, progress: 0.4).layout == .downloading(v, progress: 0.9).layout`, and the four states' layouts differ pairwise. So the shell's refit key changes when the card appears, goes away or changes state, and never on a progress push. | The design: "never on a progress push" |

### Verified without a test

- **C1, R2: development builds stay off the network.**
  1. Build Debug from Xcode and the perf build (`Scripts/perf/build.sh`), and copy each into /Applications.
  2. Open each by hand.
  3. Open the Debug copy again with `--as-release-build`.

  Expected: no update card, and Little Snitch or `nettop -P -L 1 -p <pid>` shows no connection from the process.
- **C2, R1 and R2: the gate, by grep.** In shipped sources:
  - `makeUpdater` passes `developerIDSigner() != nil` as `developerIDSigned`, and builds `GitHubReleases` and `ApplicationsUpdater` only once `InstalledRelease` exists;
  - `GitHubReleases(` and `ApplicationsUpdater(` appear only in `makeUpdater`;
  - `releases.fetch` and `installer.update(to:` are called only inside `Updater`;
  - `CodeSignature.developerIDSigner` reads no `CommandLine`.
- **C3, R1, R2 and R3: the requests, seen from outside.** Use a Developer ID build in /Applications, set up as in C4.
  1. Watch Little Snitch or `nettop`. Expected:
     - one connection to api.github.com per opening from closed;
     - none on bringing an open window to the front;
     - none after a login start while the window stays closed;
     - during an update, connections to github.com and release-assets.githubusercontent.com only.
  2. Run `sudo fs_usage -w -f filesys <pid>` through an opening and an update. Expected: no file is created or written except the staging folder in the temporary items and /Applications/TrackpadLauncher.app.
  3. Use two Macs, or a Mac and a macOS virtual machine, that differ in macOS version and preferred languages. On each, route the app through an HTTPS-intercepting proxy whose root certificate the Mac trusts (mitmproxy or Proxyman). Record the decrypted list request and archive request from an opening and an update. Expected: on both Macs, the method, path, body and the design's constant headers are identical, and every other header is a transport header the system adds (such as Accept-Encoding) that names no user, Mac or version. This is R3's "the same on every Mac and every version" in its HTTPS form; T19 and T24 see the request only over plain HTTP.
- **C4, R5, R7, R12 and R13: the card in the real window.**

  Setup: once a release vN is published (S5), archive and export a Developer ID build of the same commit with `MARKETING_VERSION` lowered (for example to 0.9.0), as release.sh does but without notarising or publishing. Put it in /Applications.
  1. Open it from Spotlight. Expected:
     - the window opens at once;
     - moments later, the card "App version vN is available" appears in its own rounded group above the gesture rows, with *Update now* on the right, as in Figma node 2143-1845;
     - the window grows downward, and the button row stays fully visible;
     - the card has no close control.
  2. Press *Update now*. Expected: "Downloading version vN…" with a filling bar and *Cancel*, and the window grows for the bar. Press *Cancel*. Expected: the card returns to "App version vN is available".
  3. Press *Update now*, then ⌘W while the download runs. Expected: the window closes. Reopen it. Expected: the card reads "App version vN is available".
  4. Set Network Link Conditioner to 100% loss and press *Update now*. Expected: about 30 s after progress stops, the card reads "The update couldn't be installed." with *Try again*. Turn the conditioner off and press *Try again*. Expected: the card goes back to downloading.
  5. Check the installing state with C7's steps.
- **C5, R6: offline.** Turn Wi-Fi off and open the window. Expected: no card and no error. Turn Wi-Fi on, then close and reopen the window. Expected: the card shows.
- **C6, R9 and R10: the hand-over and what carries over (open questions 1 and 2).** Let C4's update run to completion. Expected:
  - the old process is gone;
  - vN runs from /Applications with its settings window open and no card;
  - the same apps are assigned;
  - System Settings → Login Items still lists Trackpad Launcher as on;
  - Accessibility is still granted, and click blocking works during a gesture;
  - window-switcher previews still show, so Screen Recording carried over;
  - no permission prompt and no first-run step appears;
  - after logging out and back in, vN starts silently.
- **C7, R11 and R13: a standard account (open question 3).** Use C4's setup on a standard account that cannot write to /Applications.
  1. Press *Update now*. Expected: the administrator prompt appears only after the bar has filled.
  2. While the prompt shows. Expected: the card reads "Installing version vN…", *Quit Trackpad Launcher* is greyed and does nothing, and ⌘Q and the Dock's Quit only close the window.
  3. Cancel the prompt. Expected: the card reads "App version vN is available", and the old version still runs.
  4. Repeat, and enter an administrator's name and password. Expected: vN is installed and opens. This runs the `osascript` exchange as root.
- **C8, R14: the release process.** Expected:
  - With `Config/Version.xcconfig` unchanged since the last release, `release.sh` exits non-zero in its preflight, before building.
  - With a raised version, it prints its self-check's success and creates a draft vX holding `TrackpadLauncher.dmg` and `TrackpadLauncher-X-macOS-26.0.aar`. Confirm with `gh release view vX --json assets,isDraft`.
  - The built app's `LSMinimumSystemVersion`, read with PlistBuddy, equals `MACOSX_DEPLOYMENT_TARGET`.
  - While vX is a draft, an older copy shows no card.
  - After `gh release edit vX --draft=false --latest`, the older copy shows "App version X is available", and C6 completes.
- **C9, the docs.**
  - `docs/product-overview.md` names the update check as the one network exception, and says that an update also stops the old version and opens the new one.
  - `docs/domain-model.md` gains *Update check*, *Newer version* and *Update card*.
  - In `docs/architecture.md`, the network, file-writes, ports and distribution lines name the exception, the staging folder, the two new ports and the release archive.
- **C10, every requirement.** `swift test` passes, including the unchanged lifecycle, move and source-scan suites, and so does the `xcodebuild` build of the app.

A restart during the swap (R13) has no manual check, because it cannot be timed by hand. T32 and T33 prove it.

## Slices

### S1: One atomic swap for the move and the update

**What to build:** The administrator's swap becomes one atomic exchange: `PrivilegedInstall.script` with its `exchange`, and `swap(_:into:by:)` with no aside. `ApplicationsInstaller.put(_:at:by:)` is extracted from today's `copy` and becomes the one swap the move and the update both use. The move behaves as today, except that a kill during its administrator swap now leaves a whole copy.

**Blocked by:** None (can start immediately).

**Requirements:** R13 (a restart during the swap leaves a whole version), R12 (a failed replace leaves the old version whole), R11 (the administrator path the update shares).

**Test scenarios:** T34, T32, T33, T36.

- [ ] T32, T33, T34 and T36 pass, with `PrivilegedInstallTests` rewritten for the script without an aside.
- [ ] The move's existing suites pass unchanged through `put`.
- [ ] C10.

### S2: Opening the settings window shows the update card

**What to build:** A Developer ID build in /Applications reads the public release list once each time its settings window opens from closed. When a newer full release runs on this Mac, the window's first group is "App version X is available" with *Update now*. Nothing else, in any build, makes a request. The slice builds:
- the data types: `Version`, `Release` with `newerVersion(in:than:on:)`, `InstalledRelease`, and `UpdateCard` with `layout`;
- the `ReleaseList` port, with `InMemoryReleaseList`;
- the check half of `Updater`: `windowOpened()`, `windowClosed()` and `card`;
- `Launcher`'s two edges and its `closeWindow` guard;
- `GitHubReleases`: `fetch`, `parse`, `archiveName` and the session;
- the gate: `InstalledRelease.init?(placement:developerIDSigned:version:macOS:)`, `CodeSignature.developerIDSigner()` and `developerIDSigner(of:)`, `ThisCopy.version()` and `macOS()`, and `makeUpdater`;
- the fixture script and the fixtures it commits, which T35 is the first row to need: the Developer ID fixture's archive with the generator's record, and the fixture's Apple Development copy;
- `UpdateCardView`'s available state, placed first in `SettingsView`, and the shell's refit key.

The *Update now* button is drawn; S3 gives it its action.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3 (the check's request), R4, R5, R6, R14 (the asset-name contract older copies read).

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T18, T19, T20, T35, T37, T39.

- [ ] Every listed row passes. `OneProcess` takes `running:` and applies the real `InstalledRelease` rule, and its `history` records the card.
- [ ] One command regenerates the committed fixtures and their record: version, minimum macOS, team, identifier and file manifest.
- [ ] C1, and C2 for the list.
- [ ] C9 for the network exception and the three glossary entries.
- [ ] C10.

### S3: Update now replaces the app and reopens it

**What to build:** *Update now* downloads into memory, with a filling bar and *Cancel*. It then unpacks and verifies the new version, swaps it into /Applications, opens it as a new process with its settings window, and ends the old one. *Cancel*, *Close* and *Quit* during the download keep the current version. While the update installs:
- *Quit Trackpad Launcher* is greyed and does nothing;
- ordinary quits only close the window;
- *Close* lets the install finish.

A failure shows the failed card with *Try again*, and a cancelled prompt returns to *Update now*. The slice builds:
- the `UpdateInstaller` port, with `InMemoryUpdateInstaller`, and `UpdateEvent`;
- the rest of `Updater`: `updateNow()`, `cancel()`, `isInstalling` and `onReplaced`;
- `Lifecycle`'s quit reads and `replaced()`;
- `GitHubReleases.ArchiveDownload` (progress and the request);
- `ApplicationsUpdater`'s `update(to:events:)` over its `Download` function, and `openNewVersion(then:)`;
- `BundleInstall.unpack` and `admits`;
- `CodeSignature.isGenuine`, with `Signer`;
- the card's downloading, installing and failed states;
- `TintedButtonStyle` reading `isEnabled`.

**Blocked by:** S1, S2.

**Requirements:** R1 (the opening the update opens), R3 (the download's request), R7, R8 (a genuine update installs), R9, R10, R11 (the model's side of a cancelled prompt), R12 (the model's failure and *Try again*), R13, R14 (the release's archive unpacks whole).

**Test scenarios:** T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T21, T24, T30, T31, T38.

- [ ] Every listed row passes on any Mac, T21 against the committed fixture.
- [ ] C2 for the installer.
- [ ] C9 for the Quit sentence and the staging folder.
- [ ] C10.

### S4: Cancelled, refused and failed downloads leave nothing behind

**What to build:** `ApplicationsUpdater` handles everything other than a clean install:
- *Cancel* stops the real download, including at the moment the archive arrives;
- a lost connection, a 30 s stall or a wrong length fails the download;
- an archive that holds anything but the app is refused before verification;
- an app that is not genuine, or not the version offered, is refused before any prompt;
- the administrator's prompt comes only after verification, and cancelling it gives `.declined`.

Each case leaves the running version installed, and leaves nothing of the download on disk. The slice builds `ArchiveDownload`'s length and stall rules, `cancelDownload()` with its check past the download, and the install step's refusals and discards.

**Blocked by:** S3.

**Requirements:** R3 (nothing of the download left), R7 (*Cancel* stops the real download), R8 (the refusals), R11 (the prompt only after verification), R12 (the adapter's failures and the 30 s stall), R13 (*Cancel* against the archive's arrival).

**Test scenarios:** T22, T23, T25, T26, T27, T28, T29.

- [ ] Every listed row passes on any Mac. T25 (b)-(f) and T27 run against the committed fixture, and T23 against an injected `Download` function.
- [ ] C10.

### S5: Each release reaches older copies

**What to build:** The release script refuses a version that is not above every earlier release. It archives the stapled app as `TrackpadLauncher-<version>-macOS-<minimum>.aar`, self-checks the archive the way an older copy will, and creates a draft GitHub release with the archive and the disk image. `LSMinimumSystemVersion` comes from the deployment target. The architecture's distribution line names the release archive. The first release then goes through every manual check end to end.

**Blocked by:** S4. The end-to-end checks need every other slice; the script alone needs only S2.

**Requirements:** R14; the manual parts of R1, R2, R3, R5, R6, R7, R9, R10, R11, R12 and R13.

**Test scenarios:** None.

- [ ] C8.
- [ ] C3, C4, C5, C6 and C7 pass on the first published release, using a Developer ID build of the same commit with a lowered version, before a second release is published.
- [ ] C9 for the distribution line.
- [ ] C10.
