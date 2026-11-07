# Plan: Updates at login, and a card for the rest

Revision 2. The user replaced the first revision's rules: no background schedule, no wait for an idle trackpad, an update card instead of no interface. The design after the requirements is revision 2's, as changes on top of what the branch holds; revision 1's design text is in the git history.

## Problem statement

A new version reaches a user only if they open the settings window and press *Update now*. Trackpad Launcher runs in the background, so most users rarely open that window. They stay on old versions with bugs that are already fixed.

Revision 1 made updates fully automatic, but it paid for that in places this app must not pay. It watched every trackpad touch, ran a daily timer, and kept Sparkle and WebKit loaded all day.

## Solution

Each login or restart, a copy of Trackpad Launcher that can write to its own bundle checks for a new version. If one exists, it downloads and installs it straight away and restarts silently. Gestures may stop for up to 10 seconds at login, and that is fine: updates are rare.

At any other time, nothing updates by itself. Opening the settings window makes one check. If a new version exists, an update card shows at the top of the window (design: [Figma, node 2200-2970](https://www.figma.com/design/EB5ptBWZnAot7J3vx3cYLw/TapLauncher?node-id=2200-2970)). *Update now* downloads and installs it straight away, and the new version opens with its settings window.

Updates add nothing to trackpad use. The app holds as little of the updater in memory as it can.

Updating uses Sparkle 2, built without its user interface, so WebKit is not loaded.

The privacy rule becomes: Trackpad Launcher makes no network calls but one kind: a copy signed with a Developer ID in /Applications checks a public update list on GitHub at each login start, if it can write to its own bundle, and each time its settings window opens, and downloads a new version from GitHub releases at a login start or when the user presses *Update now*; no logging, except what Sparkle writes to the Mac's local system log, which never leaves the Mac.

`docs/product-overview.md`, `docs/domain-model.md` and `docs/architecture.md` change to match.

## Requirements

### R1. Each login start checks for a newer version

A copy signed with a Developer ID in /Applications that can write to its own bundle MUST check for a newer version once when macOS starts it at login, restart included. A check that fails for lack of a network connection MUST run again each time a connection returns, until a check completes.

#### Scenario: Restart with a newer version out

- **GIVEN** version 1.0.0 is installed, version 1.1.0 has been released, and macOS starts Trackpad Launcher at login
- **WHEN** the start finishes
- **THEN** a network monitor shows one update check and the download of version 1.1.0

#### Scenario: Network arrives after login

- **GIVEN** login completes before Wi-Fi connects, and a newer version exists
- **WHEN** the connection comes up a few minutes later
- **THEN** the check runs and the newer version installs

### R2. A login start installs straight after the download

When a login start finds a newer version, Trackpad Launcher MUST download it and install it as soon as the download finishes. It MUST wait for nothing else: not for the trackpad, a gesture or the settings window. A login download that fails MUST NOT retry until the next login start or the card.

#### Scenario: User is already using the trackpad

- **GIVEN** a login start found version 1.1.0 and the user is swiping on the trackpad
- **WHEN** the download finishes
- **THEN** the install starts at once, and version 1.1.0 runs within 10 seconds of the download finishing

#### Scenario: Connection lost during a login download

- **GIVEN** a login download runs
- **WHEN** the Wi-Fi drops
- **THEN** nothing shows, version 1.0.0 keeps running, and the next login start checks again

### R3. A login install restarts silently

After a login install, unless R4's window was open, the new version MUST run with no settings window, no Dock icon, no dialog and no permission prompt. It MUST make no update check at that start. Gestures MUST work again within 10 seconds of the old version stopping.

#### Scenario: Silent restart

- **GIVEN** version 1.0.0 runs from a login start and version 1.1.0 is downloaded
- **WHEN** the update installs
- **THEN** version 1.1.0 runs from /Applications, no window or Dock icon appears, keyboard focus stays in the user's app, gestures work, and exactly one Trackpad Launcher runs

### R4. The settings window during a login update

While a login start downloads or installs an update, opening the settings window MUST make no check and MUST show no card. The update MUST carry on. When the window is open at the moment the old version stops, the new version MUST open with its settings window.

#### Scenario: Opening the window during a login download

- **GIVEN** a login download runs
- **WHEN** the user opens the settings window and leaves it open
- **THEN** the window shows no card, no second download starts, and version 1.1.0 opens with its settings window

### R5. Each opening of the settings window checks

When the settings window goes from closed to open, a copy signed with a Developer ID in /Applications MUST make one update check, unless an update is already under way (R4, R13). The window MUST open at once, without waiting for the check. Restoring a minimised or hidden window or bringing it to the front MUST NOT check. A check still running when the window closes MUST be dropped. Every opening starts with no card: the card appears only after that opening's check finds a newer version.

#### Scenario: Reopening an open window

- **GIVEN** the settings window is open behind another app's window
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the window comes to the front and no second check runs

#### Scenario: Closing during a check

- **GIVEN** a newer version exists and the user opens the settings window
- **WHEN** the user closes the window within a second of opening it
- **THEN** no card ever appears and Trackpad Launcher makes no later request

#### Scenario: Reopened offline

- **GIVEN** an earlier opening showed the card for 1.1.0 and the Mac is now offline
- **WHEN** the user opens the window again
- **THEN** no card and no error show

### R6. A window check downloads nothing

A check from the settings window MUST download nothing until the user presses *Update now*.

#### Scenario: Opening with a newer version out

- **GIVEN** version 1.0.0 has run for a week and version 1.1.0 has been released
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the window opens at once, the update card appears moments later, and no download starts

### R7. No other network use

Trackpad Launcher MUST make no update request outside R1, R5 and a download from R2 or *Update now*. It MUST run no update schedule or timer.

#### Scenario: Running for a week

- **GIVEN** Trackpad Launcher has run for a week since login, with its window closed and no newer version at login
- **WHEN** version 1.1.0 is released and days pass
- **THEN** it makes no network request

### R8. Other builds and copies never update

A development build, a copy outside /Applications and a copy showing the move dialog MUST make no update request and MUST show no update card. A development build is one not signed with a Developer ID.

#### Scenario: Development build

- **GIVEN** a development build and a newer version
- **WHEN** the user opens its settings window
- **THEN** it makes no network request and shows no card

#### Scenario: Copy in ~/Applications

- **GIVEN** a copy signed with a Developer ID in ~/Applications that macOS starts at login
- **WHEN** a day passes
- **THEN** it makes no network request and stays on its version

### R9. A request reveals nothing about the user

Every request the updater makes, including the download, MUST carry nothing that identifies the user, the Mac, the app's version or the macOS version. Headers MUST be the same on every Mac and every version from this one on. Trackpad Launcher MUST send no system profile, setting or usage data.

#### Scenario: What a check sends

- **GIVEN** a network monitor watches Trackpad Launcher's traffic
- **WHEN** an update check runs
- **THEN** the request has no query string, no cookie and no header that names the user, the Mac, the app's version or the macOS version

#### Scenario: What a download sends

- **GIVEN** a network monitor watches Trackpad Launcher's traffic
- **WHEN** a release download runs
- **THEN** the request has no query string, no cookie and no header that names the user, the Mac, the app's version or the macOS version

### R10. Only a newer full release this Mac's macOS can run counts

A *newer version* MUST be a published full release, with a higher version than the running one, whose minimum macOS this Mac meets. When several count, Trackpad Launcher MUST take the highest. It MUST never install an older version.

#### Scenario: Pre-release

- **GIVEN** version 1.0.0 runs and the only release above it is pre-release 1.1.0-beta
- **WHEN** an update check runs
- **THEN** nothing downloads and no card shows

#### Scenario: Needs a newer macOS

- **GIVEN** the Mac runs macOS 26, version 1.1.0 needs macOS 26 and version 1.2.0 needs macOS 27
- **WHEN** an update check runs from version 1.0.0
- **THEN** version 1.1.0 is the one offered or installed

#### Scenario: Already the highest

- **GIVEN** version 1.1.0 runs and it is the highest full release
- **WHEN** an update check runs
- **THEN** nothing downloads and no card shows

### R11. The update card

When the current opening's check finds a newer version, the settings window MUST show the update card as its first group, as in the design: *Update available* above an *Update now* button, with a large tray-and-arrow picture clipped at the card's right side, and a thin border. Otherwise the card MUST NOT show. The card MUST NOT be dismissable.

#### Scenario: Card layout

- **GIVEN** an update check found a newer version
- **WHEN** the check finishes
- **THEN** the card appears above the gesture rows, matching the design, and the rest of the window moves down to make room

#### Scenario: Failed check

- **GIVEN** the Mac is offline
- **WHEN** the user opens the settings window
- **THEN** no card and no error show, and the next opening checks again

### R12. Only the arrow moves

While the card shows, the picture's arrow MUST drift up and down by about 4 points, about every 3 seconds. The tray MUST stay still. The arrow MUST stay inside the card's clip. The motion MUST stop while the window is closed. When *Reduce motion* is on, the arrow MUST NOT move.

#### Scenario: Card on screen

- **GIVEN** the card shows
- **WHEN** the user watches it for ten seconds
- **THEN** the arrow drifts gently, and the tray, the text and the button do not move

#### Scenario: Reduce Motion

- **GIVEN** *Reduce motion* is on in System Settings
- **WHEN** the card shows
- **THEN** the arrow stays still

### R13. Update now installs straight away

Pressing *Update now* MUST grey the button out and change its label to *Updating…*. Closing and reopening the window during the update MUST show the card the same way, with no check. Trackpad Launcher MUST download the version and install it as soon as the download finishes, then open the new version with its settings window open and stop the old one. The new version MUST make no update check at that start. There MUST be no progress bar and no *Cancel*.

#### Scenario: Update now

- **GIVEN** version 1.0.0 shows the card for version 1.1.0
- **WHEN** the user presses *Update now*
- **THEN** the button reads *Updating…*, version 1.1.0 replaces version 1.0.0, version 1.1.0 opens with its settings window and no card, and exactly one Trackpad Launcher runs

#### Scenario: Closing the window during an update

- **GIVEN** the button reads *Updating…*
- **WHEN** the user closes the settings window
- **THEN** the update carries on, and the new version opens with its settings window

### R14. A failed update from the card offers the button again

When a download or install started by *Update now* fails, the card MUST return to *Update available* with *Update now*, and show no error. The running version MUST keep working. When the install fails after the old version stopped, a working copy MUST run within 10 seconds of that stop, with its settings window open.

#### Scenario: Connection lost

- **GIVEN** the button reads *Updating…*
- **WHEN** the Mac loses its network connection
- **THEN** the card reads *Update available* with *Update now*, and version 1.0.0 keeps running

#### Scenario: Install fails after the old version stopped

- **GIVEN** the user pressed *Update now* and version 1.0.0 has stopped
- **WHEN** the install fails
- **THEN** a working copy runs within 10 seconds of that stop, with its settings window open

### R15. Only a genuine update installs

Trackpad Launcher MUST install a download only when it carries a signature made with the publisher's update key and is signed with the same Developer ID and bundle identifier as the running copy. Otherwise it MUST install nothing. At login it MUST show nothing; from the card, R14 applies.

#### Scenario: Tampered download

- **GIVEN** the downloaded update fails its signature check
- **WHEN** the download finishes
- **THEN** nothing installs and version 1.0.0 keeps running

#### Scenario: Different Developer ID

- **GIVEN** a download passes the update key signature but is signed by another Developer ID
- **WHEN** the download finishes
- **THEN** nothing installs and version 1.0.0 keeps running

### R16. Every release is notarised

The release process MUST notarise every update and MUST NOT publish one that is not.

#### Scenario: Notarisation fails

- **GIVEN** a build fails notarisation
- **WHEN** the release runs
- **THEN** nothing is published and no copy sees it

### R17. Settings and permissions carry over

Every setting, starting at login and the Accessibility and Screen Recording permissions MUST carry over to the new version.

#### Scenario: After an update

- **GIVEN** version 1.0.0 has gestures assigned, starting at login on, Accessibility and Screen Recording granted, a non-default thumb corner and *Hide background apps* on
- **WHEN** version 1.1.0 installs
- **THEN** all of them are the same in version 1.1.0, and no permission prompt appears

### R18. A failed login install keeps the current version

At every moment /Applications MUST hold either the whole old version or the whole new one. A failed install MUST end with a working copy running within 10 seconds, with nothing shown. Trackpad Launcher MUST NOT try again until the next login start or the card.

#### Scenario: Install fails

- **GIVEN** a login start is installing an update
- **WHEN** the install fails
- **THEN** a whole working copy stays in /Applications, gestures work within 10 seconds, and no second attempt runs at that start

#### Scenario: Mac loses power during a login install

- **GIVEN** a login start is installing an update
- **WHEN** the Mac loses power
- **THEN** at the next login a whole copy of one version starts and the check runs again

### R19. Accounts that cannot write to /Applications update from the card

A copy that cannot write to its own bundle MUST make no check, download or prompt at a login start. Its settings window MUST check and show the card as usual. *Update now* MUST ask for an administrator's name and password after the download. Cancelling that prompt MUST return the card to *Update available*, with nothing changed and no error.

#### Scenario: Login on a standard account

- **GIVEN** a standard account and a newer version
- **WHEN** macOS starts Trackpad Launcher at login
- **THEN** it makes no network request and no prompt appears

#### Scenario: Standard account uses the card

- **GIVEN** a standard account and the card
- **WHEN** the user presses *Update now* and enters an administrator's password
- **THEN** the new version installs and opens with its settings window

#### Scenario: Prompt cancelled

- **GIVEN** a standard account pressed *Update now*
- **WHEN** the user cancels the administrator prompt
- **THEN** the card reads *Update available* with *Update now*, and the current version keeps running

### R20. The app's own quit stays final

*Quit Trackpad Launcher* MUST stop the app at once, in any update state. An update MUST NOT start the app again afterwards.

#### Scenario: Quit during an update

- **GIVEN** the button reads *Updating…*
- **WHEN** the user presses *Quit Trackpad Launcher*
- **THEN** the app stops and stays stopped until the user opens it

#### Scenario: Quit during a login install

- **GIVEN** a login start is installing an update
- **WHEN** the user presses *Quit Trackpad Launcher*
- **THEN** a whole copy remains and nothing restarts

### R21. Updates never block quitting

Logging out, restarting and shutting down MUST end the app with no dialog and no delay from an update.

#### Scenario: Restart during a login download

- **GIVEN** an update is downloading
- **WHEN** the user restarts the Mac
- **THEN** the restart proceeds with no dialog, and the next login start checks again

### R22. Updates add nothing to trackpad use

The code that handles trackpad frames MUST contain no update logic in any update state. No update code MUST run for a trackpad frame. A review of the code and a source check confirm this; it is not measured.

#### Scenario: Touching the trackpad during an update

- **GIVEN** any update state: none, checking, downloading or installing
- **WHEN** the user uses the trackpad
- **THEN** no update code runs on any frame

### R23. The updater holds the least memory it can

Trackpad Launcher MUST NOT load WebKit, and MUST show no updater interface of its own. The updater MUST exist in memory only during a check or an update, and during R1's wait for a connection. While the card waits for its button, only the version it offers stays.

#### Scenario: After a check that found nothing

- **GIVEN** a login start's check found no newer version
- **WHEN** the check ends
- **THEN** no updater object runs, and WebKit is not among the app's loaded libraries

### R24. Older copies can still update

Every new release MUST stay installable from the update card of versions before this one. This binds every future release's assets for as long as such copies may exist.

#### Scenario: Last old card

- **GIVEN** version 1.0.14 runs and the first version with these rules has been released
- **WHEN** the user opens the settings window and presses *Update now*
- **THEN** the new version installs

## Non-goals

- **A daily check or any background schedule.** The card only shows in the window, so a check at opening is enough.
- **Installing on wake from sleep.** Only a login start or the card installs.
- **Installing at logout or shutdown.** It depends on the system giving the installer time.
- **A smarter moment to install.** Updates are rare, and a few lost seconds are fine. It can come later if needed.
- **A progress bar, *Cancel* or an error message.** The card stays minimal.
- **A separate helper process for the updater.** It would save little more memory and add a process that can fail.
- **Measuring memory or CPU.** The rules above hold by construction.
- **An off switch for updates.**
- **Rolling back a release.** A bad release is fixed by publishing a higher version.
- **Fast user switching.** Two accounts running the app at once on one Mac get no special handling.
- **Updating standard accounts at login.** It would need an administrator prompt at login.
- **The version number or release notes on the card.** The design shows neither.
- **A beta channel.** Pre-releases never count.
- **A notice after a silent update.** Updates at login stay invisible.

## Implementation Decisions

### What the branch holds today (revision 1), and what of it stays

Revision 1 is implemented on this branch and its design text lives in the git history (`324d3d0`, `d815a2c`). It built, on Sparkle 2.10.1 from the prebuilt package: an `Updater` in `LauncherCore` with phases *resting*, *awaiting connection*, *ready* and *handed over*; contact sensing on the frame thread and an idle-minute clock, so a held update installed a minute after the last touch; `SparkleEngine` on Sparkle's automatic path (a 24-hour schedule, a check at every start, the hold at `willInstallUpdateOnQuit`, our genuineness check and a two-layer veto inside that call); `LaunchdJob` and the hand-over script that reopens whichever copy /Applications holds with `--after-update`; `SystemConnection` for the retry; `CardContract` and the release's feed. Its E2E script has never been run by a person, and `SUPublicEDKey` is still empty.

What stays unchanged: the gate's shape (an object's absence), the genuineness check and the veto, the hand-over job and its script's wall-time budget, the retry on a returned connection, the feed, `release.sh`, `CardContract`, the privacy configuration of the requests (user agent, headers, no cookies, no cache), `SourcePolicyTests`' structure, and the source-scan rule that `import Sparkle` lives in one file.

What changes: Sparkle is built from its pinned source without its UI and vendored; the updater exists per cycle; nothing of updates touches the frame path; the login start installs the moment the update is prepared; the window's opening checks and shows the card; *Update now* installs at once; the hand-over can bring the window.

### 1. Sparkle from its pinned source, without its UI, vendored as a binary target

One script builds Sparkle from a shallow clone of the pinned tag with `SPARKLE_BUILD_UI_BITS=0`, `SPARKLE_BUILD_LEGACY_SUUPDATER=0`, `SPARKLE_BUILD_LEGACY_DSA_SUPPORT=0`, `SPARKLE_BUILD_LEGACY_DELTA_SUPPORT=0` and `SPARKLE_EMBED_DOWNLOADER_XPC_SERVICE=0`, keeping `SPARKLE_EMBED_INSTALLER_LAUNCHER_XPC_SERVICE=1` (Sparkle's own `Sparkle` scheme, Release, ad hoc signed), packs the framework into an xcframework, builds `sign_update` and `generate_keys` from the same clone with Sparkle's default flags, writes a manifest (tag, commit, flags, Xcode version) beside them, and fails if `WebKit` or `AppKit` appears in the framework binary's load commands. The output is committed under the package as a local `.binaryTarget`, with the two tools in a `bin` folder beside it; the remote package dependency goes, `Package.resolved` loses its pin, and the keychain flags revision 1 added for the remote binary (`--disable-keychain`, `-packageAuthorizationProvider netrc`) go with it. `release.sh` takes the tools from the vendored folder.

Proven in this planning session on 2.10.1: the build succeeds, the framework is 2.2 MB (the prebuilt package is 20 MB) and links Foundation, Security, ServiceManagement, SystemConfiguration and libcompression only: neither WebKit nor AppKit; `SPUUpdater` present and every UI class absent; the two tools run standalone. Three helpers stay nested, each a separate process that exists only during an update: `Autoupdate`, the installer; `Updater.app`, its termination agent, whose progress window shows only on a stage-2 request this app never sends; and the installer launcher XPC service (180 KB, AppKit-linked), which exists only while the installer is launched and is where Sparkle asks for an administrator. It is kept, and `SUEnableInstallerLauncherService` declared `true`, because the in-process launcher runs that prompt synchronously on the main queue, which would freeze gestures, Quit and a logout for as long as the prompt is up (R20, R21). The downloader service, which would be a process for every download, stays out. The embedded UI headers remain in the umbrella header and compile to nothing, since the app never names them.

`SparkleInternals.provenOn` is compared with the manifest's tag, no longer with `Package.resolved`. The source-scan stays as it is for `import Sparkle`.

### 2. One Sparkle path, used on demand

`SparkleEngine` creates an `SPUUpdater` when a cycle starts and drops its reference inside `didFinishUpdateCycle`, so the object dies when Sparkle's own stack unwinds; between cycles the engine holds a delegate and a user driver and nothing else. Two kinds of cycle, each one Sparkle call on a fresh updater after `start()`:

- **A probe** (`checkForUpdateInformation`): Sparkle's probing driver reads the feed, runs `shouldProceedWithUpdate` (the enclosure pin), reports `didFindValidUpdate` and aborts the moment it has an answer. Nothing downloads.
- **An update** (`checkForUpdates`): Sparkle's user-initiated driver over this app's silent user driver. It reads the feed again (one more request than the probe, named under R7 below), records the offer at `didFindValidUpdate`, and `showUpdateFound` is answered by the state's stage: *install* for an update not yet downloaded or downloaded, *skip* for one whose installer is already running, which can only follow a crash and would otherwise send Sparkle's own relaunch. The download runs. Then, in the order Sparkle calls them:
  1. **`didDownloadUpdate`**, after the download and before any installer exists: the engine finds the downloaded archive (Sparkle's persistent download, a private layout under the user's caches, owned by the user on every account), expands it into a scratch folder of its own, runs `isGenuine` on the one bundle inside against the offer, and removes the scratch folder. A genuine verdict is remembered. A refused one removes the downloaded archive, so Sparkle's own extraction fails and the cycle ends `.failed`; no installer was ever launched for it, so no quit, crash or termination can install it. All of it synchronous, on the main actor, once per release.
  2. The installer is launched through the launcher service, with interaction allowed: a copy this user cannot replace gets the administrator prompt here, after the download and before extraction, in that service's process. Extraction and preparation follow.
  3. **`showReady(toInstallAndRelaunch:)`** is the hold point. The reply closure is kept and `.held` is pushed; with no genuine verdict remembered the reply is *skip* instead, which cannot happen but costs one line. A held update never gets a reply: `Updater` arms the restart and ends the process in that same turn. `discardHeldUpdate()` replies *skip*, which cancels the installer in either launchd domain and is not a skipped version in Sparkle's sense; the cycle then ends `.failed`. A *dismiss* would refuse nothing: Sparkle's header says the update may still install at the application's end.

Why this holds at the process's end: Autoupdate commits to the installation (`_willCompleteInstallation`) when it starts, listens for the host's termination through its agent, and installs on that termination with no UI and no relaunch, since the UI and relaunch flags travel only in a stage-2 message this app never sends. A connection that drops afterwards does not abort it. Read in the 2.10.1 sources; the E2E rows prove it on a notarised build.

Why the check moves before the installer: on a standard account Sparkle's installer runs as root and extracts under root's caches, where the app cannot read, and once launched it installs at the host's end whether or not this app has judged the update. Expanding the user-owned download ourselves checks the same bytes on every account before Sparkle commits. The archive code is a copy of the frozen `CardContract` extraction, kept apart from it on purpose, as `isGenuine`'s copy is. What could still install an unchecked bundle is an EdDSA-valid archive swapped under the installer after our check, which needs the publisher's private key.

Why one driver: the automatic driver cannot prompt (R19), and for a copy this user can replace, the user-initiated driver over a silent user driver shows nothing either. The automatic path, `willInstallUpdateOnQuit`, `checkForUpdatesInBackground`, the extraction-layout lookup, the installer-job veto and Sparkle's scheduler go. `SUEnableAutomaticChecks` is declared `false`, so Sparkle asks no permission and arms no timer; `SUAutomaticallyUpdate` leaves the Info.plist and joins the keys that must never be declared, with `SUScheduledCheckInterval`. The download runs in the foreground on both paths, so a login download is never deferred by the system. Every fresh updater gets the user agent, the headers and the cookie and cache policy revision 1 set; `start()` throwing (an empty key) is `.cycleEnded(.failed)`.

A probe cannot be cancelled. The engine never suppresses an answer and never runs two cycles: `Updater`'s phases ask for a probe or an update only when no cycle runs, and a probe whose window has closed is remembered as running until it answers, with its answer ignored.

### 3. The `UpdateEngine` port, revised

```swift
public enum CycleOutcome: Equatable, Sendable {
    /// A probe found a newer version. Never an update's outcome.
    case found
    case nothingNew
    /// The feed's request failed: what a lost connection looks like, and what earns a login start's retry.
    case requestFailed
    /// Anything after the feed was read: a download that failed, a refused enclosure, a cancelled prompt, a bad
    /// signature, a discarded update.
    case failed
}

public enum UpdateEngineEvent: Equatable, Sendable {
    /// A genuine update is extracted and prepared; it installs at this process's end. Pushed inside Sparkle's
    /// callback, so nothing else runs on the main actor first.
    case held
    /// A cycle ended. For a probe, its one answer.
    case cycleEnded(CycleOutcome)
}

@MainActor public protocol UpdateEngine: AnyObject {
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? { get set }
    /// Reads the feed and downloads nothing. Answers once, `.cycleEnded(.found | .nothingNew | .requestFailed | .failed)`.
    /// Never asked while a cycle runs.
    func probe()
    /// Reads the feed, downloads the newest version, refuses one that is not genuine before any installer exists, asks
    /// for an administrator when this user cannot replace the bundle, prepares it and pushes `.held`; the update
    /// installs at this process's end. `.cycleEnded` follows only when `.held` is never reached or the held update is
    /// discarded. Never asked while a cycle runs.
    func update()
    /// Stops the held update: the installer is cancelled, then Sparkle's cycle ends `.failed`.
    func discardHeldUpdate()
    /// Arms the job that opens whichever copy /Applications holds once this process has ended: silently, or with its
    /// settings window. The caller ends the process in the same turn. False: nothing is armed.
    func armRestart(opensWindow: Bool) -> Bool
}
```

`HeldUpdate` goes: a refused update never reaches the hold. The engine's outcome function takes the cycle's kind and two facts its delegate records, whether the feed was read (`didFinishLoadingAppcast`) and whether an update was found (`didFindValidUpdate`, which also records the offer the download is checked against):

| Kind | Sparkle's error | Outcome |
|---|---|---|
| probe | none, found | `.found` |
| probe | none, not found; `SUNoUpdateError` (1001) | `.nothingNew` |
| probe | `SUDownloadError` (2001) | `.requestFailed` |
| probe | anything else | `.failed` |
| update | `SUNoUpdateError` | `.nothingNew` |
| update | `SUDownloadError`, feed not read | `.requestFailed` |
| update | everything else: none (an abort after a skip), `SUDownloadError` after the feed, 3001 (the extraction of a removed archive), 4004, 4005, 4007, 4008, another domain | `.failed` |

### 4. `Updater`, rewritten

`Updater` is `@Observable` again, because the card renders it. It shows an initializer, `start(watching:opening:opensWindow:)`, `onHandOver`, `card` and `updateNow()`. Behind them: the login cycle and its retry, the window's check and its dropping, the card's two faces, the hand-over's order and its window. Each lasting effect belongs to a known set of phases and starts and stops in one transition function.

```swift
/// R1's debt, carried through the phases a login start's wait for a connection can pass through: none; owed with this
/// reading's retry unmade; owed with it made, so only a drop and a return earn another.
enum RetryDebt: Equatable { case none, owed(spent: Bool) }

private enum Phase: Equatable {
    case resting
    /// R1. The login check failed for the network; the path monitor runs.
    case awaitingConnection(spent: Bool)
    /// R2. The login cycle runs: the check, the download, the preparation. `retry`: a returned connection started it,
    /// so the watch stays through it; `dropped`: the connection fell during that retry, so its network failure owes a
    /// fresh retry rather than a spent one.
    case updatingAtLogin(retry: Bool, dropped: Bool)
    /// R5. The window's check runs. `debt`: what a login start's wait it interrupted still owes; any check that
    /// completes settles it.
    case probing(debt: RetryDebt)
    /// The window closed during its check. The check still runs, its answer is ignored, and no second check starts
    /// until it has come: one cycle at a time.
    case droppedProbe(debt: RetryDebt)
    /// R11. The card shows *Update available*. Nothing of Sparkle exists.
    case offering
    /// R13. *Update now*'s cycle runs; the card shows *Updating…*, window open or closed.
    case updatingFromCard
    /// Terminal: the restart is armed and the process ends in this turn.
    case handedOver
}
```

| Lasting effect | Exists only in |
|---|---|
| The connection watch | `.awaitingConnection`, `.updatingAtLogin(retry: true, _)` |
| An `SPUUpdater`, inside the engine | `.updatingAtLogin`, `.probing`, `.droppedProbe`, `.updatingFromCard` |
| The card | `.offering` (*Update available*), `.updatingFromCard` (*Updating…*) |
| The hand-over job | `.handedOver`, which lasts one turn |

No phase asks the engine for a cycle while one of the four above runs: that is the "one updater at a time" guarantee, and the in-memory engine counts any call that breaks it.

Inputs and what they do:

- **`start(watching:opening:opensWindow:)`**, once, from `Lifecycle` after the resident exists and after the start's own `openedByHand()`, so that opening never arrives as an edge. Wires the engine, the connection and the window edges. `.atLogin` and the copy can replace itself → `.updatingAtLogin(retry: false, dropped: false)`, `update()`, whatever the window (R4). `.atLogin` and it cannot, or `.byHand`, with a window → `.probing(debt: .none)`, `probe()`. `.afterUpdate` → `.resting`, whatever the window: R3 and R13.
- **The window opens** (closed to open): `.resting` → `.probing(.none)`, `probe()`; `.awaitingConnection(spent)` → `.probing(.owed(spent: spent))`, `probe()`, the watch stops; `.droppedProbe(debt)` → `.probing(debt)` with no engine call: the running check answers, and the card is nil until it does. In `.updatingAtLogin`, `.updatingFromCard` and `.handedOver` nothing happens: R4, R13.
- **The window closes**: `.probing(debt)` → `.droppedProbe(debt)`; `.offering` → `.resting`. In `.updatingFromCard` nothing: the card persists.
- **`updateNow()`**: only in `.offering` → `.updatingFromCard`, `update()`.
- **`.held`**: in `.updatingAtLogin` → `armRestart(opensWindow: launcher.isWindowOpen)`; in `.updatingFromCard` → `armRestart(opensWindow: true)`. Armed → `.handedOver`, `onHandOver()`, in the same turn. Refused → `discardHeldUpdate()` and the phase stays, so the cycle ends `.failed` and the rule below decides; the process never ends without a restart armed.
- **`.cycleEnded(outcome)`** in `.updatingAtLogin(retry, dropped)`: `.requestFailed` → `.awaitingConnection(spent: retry && !dropped)`; anything else → `.resting`. In `.probing(debt)`: `.found` → `.offering`; `.requestFailed` → `.awaitingConnection(spent)` if the debt is owed, else `.resting`; `.nothingNew` or `.failed` → `.resting`. In `.droppedProbe(debt)`: `.requestFailed` → `.awaitingConnection(spent)` if owed, else `.resting`; anything else → `.resting`, a found update included, since nobody is looking. In `.updatingFromCard`: `.nothingNew` → `.resting` (the release went away); anything else → `.offering` if the window is open, else `.resting`, so an opening never meets a stale card and always checks. Elsewhere ignored.
- **A connection reading**: in `.awaitingConnection(spent)`, not connected clears `spent`; connected and not spent → `.updatingAtLogin(retry: true, dropped: false)`, `update()`. In `.updatingAtLogin(retry: true, _)`, not connected sets `dropped`; connected is ignored. Elsewhere ignored. Entering `.awaitingConnection` restarts the watch, which pushes the present reading: connected and spent means nothing until a real drop and return; not connected clears the debt; connected and not spent retries at once, which is the flap case, a drop and a return inside the retry that then fails.
- **`card`**: `.available` in `.offering`, `.updating` in `.updatingFromCard`, nil elsewhere.

The transition function: entering `.awaitingConnection` always (re)starts the watch; leaving it for anything but `.updatingAtLogin(retry: true, _)` stops it; leaving `.updatingAtLogin(retry: true, _)` for anything but `.awaitingConnection` stops it. No other effect lives in it.

Quit, logout, restart and shutdown need no table: `Lifecycle` keeps its one `shouldEnd` switch with no update guard. A quit before the download has completed kills the download with the process and no installer exists; one after the genuineness check and before `.held` lets Sparkle's installer, already committed, install a genuine update at that end with nothing to restart the app, which R15 and R20 allow; one after `.held` cannot land, since the process ends in that same turn.

### 5. The window's edges reach `Updater` through one closure on `Launcher`

`Launcher` gains `onWindowEdge: (@MainActor (Bool) -> Void)?`: true when the window goes from closed to open, false from open to closed, never on a re-front; it replaces revision 1's `watchUse`. `Updater.start` sets it; `Launcher` knows nothing about updates. The view reads `card` from the `Updater` the composition root hands the shell, as the original card did.

### 6. The gate splits in two

`UpdatableCopy` keeps its initializer and fails only for a copy not signed with a Developer ID or not in /Applications; `canReplaceItself` becomes a stored fact. The updater exists for every such copy, so its window checks and shows the card (R19's second half); only a copy that can replace itself runs the login cycle (R19's first half). `SparkleEngine.canReplace` stays as the read-only mirror of Sparkle's rule.

### 7. The hand-over can bring the window

`Opening.afterUpdate` gains `withWindow: Bool`. `Route`: `(.afterUpdate(withWindow: false), .installed)` → `.runSilently`; `(.afterUpdate(withWindow: true), .installed)` → `.runWithWindow`; the `.elsewhere` and `.development` rows are unchanged for either. `ThisCopy` parses `--with-window` beside `--after-update`, and `--at-login`, which makes a start read as a login start for the hand tests (the E2E script cannot send the login item's event); the reopen still reads only the event. The hand-over script takes one more argument and opens with `-g` only without the window, so the shell's own activation gives the window the focus when there is one. `Lifecycle` passes `opensWindow` to `Updater.start`; `Stage.replacingOthers` already carries both.

A failed install from the card reopens the old version with its window and no check (R14); the next opening of the window checks again and shows the card.

### 8. Nothing of updates on the frame path

Deleted: `TrackpadEvent.contactChanged`; `TrackpadHardware.isTouched` and `sensesContact`; the session's occupancy flag, its sensing closure and `isAnyTrackpadTouched`; the hardware adapter's sensing flag; `Launcher.isInUse`, `watchUse` and `reportUse`; the `IdleClock` port, `SystemIdleClock` and its in-memory twin; the in-memory trackpad's press, lift and held-edge handles. The frame callback is as it was before revision 1: no lock, no flag, no hop for contact.

The scan gains a kept-out table: the frame-path files (the frame stream and its parsing, the multitouch adapter and its framework shim, the click tap, the gesture recognizer and its rules, the touch, tap-state, tap, click, scroll and Dock-swipe filters) contain none of `Updater`, `UpdateEngine`, `Sparkle`, `contactChanged`, `isTouched`, `sensesContact`, `isInUse`, `occupied`, `IdleClock`. The timer tokens (`Timer`, `makeTimerSource`, `DispatchSourceTimer`) return to the banned list, and the twin check that kept them in the confined list keeps only the path monitor's half.

### 9. The card

`UpdateCardView(card:updateNow:)` is a rounded group in the Accessibility hint card's style: the group fill, the 12 pt radius, the 1 pt `#DEDEDE` border. *Update available* in the window's label font (SF Pro Regular 11 pt, line height 14) above the *Update now* button in the *Close* button's style; while the card is `.updating` the button is disabled and reads *Updating…*. The picture sits at the card's trailing edge, overflowing it and clipped by the card's shape, takes no clicks and is hidden from accessibility, as the gear is. It is the first part of the window's column, above the Accessibility hint; the shell's `Fit` gains the card so the window refits when it appears or goes; the Quit button is never disabled. Its exact insets and the picture's offset come from the Figma node at implementation, compared side by side; this session had no Figma access and the requirement names the parts, not the numbers. `Copy` gains `updateAvailable`, `updateNowButton` and `updatingButton`.

### 10. The picture: the arrow and its hole move together

Rendered, the design's symbol is a solid rounded tray whose arrow is a knockout where the two overlap, with the arrow's shaft filled above the tray (the compound path's two subpaths wind in opposite directions). So "only the arrow moves" means the filled shaft and the tray's arrow-shaped hole move as one.

`UpdatePictureView`, an `NSView` with layers, from two SVG assets split from the design's path on the same 71 × 89 canvas, fill `#DEDEDE`: `update-tray.svg` (the first subpath) and `update-arrow.svg` (the second). The design's path data, from node 2200:2983, so that the assets can be regenerated and checked without the Figma file:

```text
tray:  M16.72 85.7513H54.24C65 85.7513 71 79.7748 71 68.9858V38.1026C71 27.3537 65 21.3375 54.24 21.3375H16.72C5.96 21.3375 0 27.3537 0 38.1026V68.9858C0 79.7748 5.96 85.7513 16.72 85.7513Z
arrow: M35.52 0C37.24 0 38.68 1.40378 38.68 3.08832V43.9183L38.44 49.8944L40.68 47.528L46.88 40.9102C47.44 40.2684 48.24 39.9476 49.04 39.9476C50.68 39.9476 51.96 41.1509 51.96 42.7552C51.96 43.6375 51.6 44.2792 51 44.8809C45.8451 49.8618 37.8 57.6352 37.8 57.6352C37 58.4374 36.32 58.7181 35.52 58.7181C34.68 58.7181 34 58.4374 33.2 57.6352L20 44.8809C19.4 44.2792 19.04 43.6375 19.04 42.7552C19.04 41.1509 20.24 39.9476 21.92 39.9476C22.72 39.9476 23.56 40.2684 24.12 40.9102L30.32 47.528L32.56 49.8944L32.32 43.9183V3.08832C32.32 1.40378 33.8 0 35.52 0Z
``` The tray layer's mask is a layer whose contents is a solid rectangle with the arrow knocked out, drawn once at view creation from the arrow image with a destination-out blend, 4 pt taller than the canvas at the top and the bottom so the moving hole never uncovers an edge. The arrow layer sits inside a static container, masked to outside the tray, so only the shaft above the tray shows while the hole moves with it; the view has more than three layers. The mask layer and the arrow layer carry the same animation under one key: `position.y` by −4 pt, 1.5 s, ease-in-out, autoreversing, repeating for ever, not removed on completion. The tray layer never animates.

The animation exists while the view is in a window whose occlusion state is visible and Reduce motion is off; it is removed when the view leaves the window, when the window's occlusion state loses visibility (`NSWindow.didChangeOcclusionStateNotification`, so a closed window stops it as R12 asks, while the card persists through a close during *Updating…*), or when Reduce motion turns on (the workspace's display-options notification, as the gear does); and added again on the reverse. Both readers are injected, as the gear's Reduce motion reader is, so a bench can drive them. The contents follow the backing scale, as the gear's do. Only the render server plays it; no code of ours runs per frame.

### 11. Info.plist keys and the scan

| Row | Change |
|---|---|
| `alwaysDeclared` | `SUEnableAutomaticChecks` must be declared with the value `false`, and `SUEnableInstallerLauncherService` with the value `true`; `SUAutomaticallyUpdate` leaves the list. `SUFeedURL`, `SUPublicEDKey`, `SUVerifyUpdateBeforeExtraction`, `TLUpdateDownloads` stay. |
| `neverDeclared` | Adds `SUAutomaticallyUpdate` and `SUScheduledCheckInterval`; `SUEnableInstallerLauncherService` leaves it; `SUEnableDownloaderService` and `SUEnableSystemProfiling` stay. |
| `banned` | `Timer`, `makeTimerSource`, `DispatchSourceTimer` return, rule "no timers: every input is a push". The bans-still-listed check covers them. |
| `confined` | The clock's three rows go, and `sparkle-updater` with the veto. `import Network`, `NWPathMonitor`, `import Sparkle`, `HTTPCookieStorage`, `URLCache`, `org.sparkle-project` (now the download's path), `SMJob`, `/bin/sh` stay. The archive rows (`AppleArchive`, `ArchiveStream`, `ArchiveByteStream`) and the file rows they need (`removeItem(`, `itemReplacementDirectory` or whichever scratch-folder call the copy uses) gain the one Platform file that expands the download. |
| Kept out, new | Decision 8's table. A planted token in a frame-path file fails the scan. |

### 12. The E2E script and the docs

`update-e2e.sh` keeps its build, signing, notarisation, local server, sampler and cleanup, and its rows are re-cut to revision 2 (the Test scenarios below). Its builds carry `SUEnableAutomaticChecks: false` like the shipped one, and start with `--at-login` where a login start is meant.

`docs/architecture.md` and `docs/domain-model.md` are rewritten with this plan. `docs/product-overview.md`, `README.md` and `release.sh`'s header change in the last slice.

On R7: *Update now* reads the update list once more before its download, because Sparkle has no way to download an item a probe found without a fresh read. The plan's Solution and the docs say so; R7's text lists "a download from *Update now*", and this is the request that download needs. The human should confirm that reading.

### 13. Deletions and the module map

| Module | Change |
|---|---|
| `LauncherCore` | `Updater` rewritten (decision 4); `UpdatableCopy` keeps its fact (6); `Opening.afterUpdate(withWindow:)` and its `Route` rows (7); `UpdateEngine`, `CycleOutcome`, `UpdateEngineEvent` revised (3); `UpdateCard` with its button's title and enabled state as values, and `Copy`'s three strings (9); `Launcher.onWindowEdge` (5). Goes: `IdleClock`, `HeldUpdate`, `TrackpadEvent.contactChanged`, `TrackpadHardware.isTouched`/`sensesContact`, `Launcher.isInUse`/`watchUse`. |
| `LauncherPlatform` | `SparkleEngine` rewritten on one driver family, one updater per cycle, the check at the download (2, 3); one new file that expands an `.aar` into a scratch folder and names the one bundle inside, a copy of `CardContract`'s extraction (2); `SparkleInternals` keeps `canReplace`, gains the persistent download's lookup, loses the extraction lookup, the installer job's label and the veto; `LaunchdJob` with the window argument (7), its `remove` kept for stale labels; `ThisCopy` with `--with-window` and `--at-login` (7). Goes: `SystemIdleClock`, the contact code in the session and the adapter. `CodeSignature.isGenuine`, `SystemConnection` unchanged. |
| `LauncherUI` | `UpdateCardView`, `UpdatePictureView` and its representable (9, 10); `SettingsView` and `SettingsShell` take the updater; two SVG assets. |
| App target | Keeps the `Updater` it builds and hands it to the shell; no decision. |
| Package | The vendored Sparkle (1); the remote package and the keychain flags go. |
| Tests | The world's `InMemoryUpdateEngine` learns the new port and counts overlapping cycles; the idle clock and contact handles go; `UpdateWaitsTests` goes, `UpdaterStartTests`, `UpdateRetryTests` and `HandOverTests` are rewritten; `DeviceSessionContactTests`, `SystemIdleClockTests` and `SparkleVetoTests` go, the last replaced by the download lookup's and the extraction's rows; new UI bench and asset tests. |

## Testing Decisions

### Strategy

The one seam for every decision is `LifecycleWorld`: real `Lifecycle`, `Launcher`, `Updater` and `UpdatableCopy` over in-memory ports, with no waiting. It sees each process's effects in order, its window and card after every intent, and a Mac's whole history across processes and hand-overs. It cannot see Sparkle, launchd, the frame thread, AppKit or the screen. The new rows resemble `LauncherKit/Tests/LauncherCoreTests/UpdaterStartTests.swift`, `UpdateRetryTests.swift` and `HandOverTests.swift`, whose world and in-memory engine they extend: the engine gains `probes`, `updates`, `discards`, `arms` (each `armRestart`'s window flag, in order) and `overlaps`, a count of every `probe()` or `update()` asked while a cycle it started has not yet been answered by a `push(.cycleEnded)` (a `.held` keeps it running), and keeps `armWorks` and `push(_:)`; every world row ends by expecting `overlaps == 0`. The process's published history gains the card, and `finishHandOver` reads the last arm's window flag.

Three seams cover what the world fakes, each as high as a real run allows:

- **Platform adapters by direct call, in `swift test`**: the outcome table, the user driver's reply by stage, `ThisCopy`, the hand-over script run for real under `/bin/sh` with a stub `open` (as `LaunchdJobTests.swift` does), the download lookup over temp folders in Sparkle's layout (as `SparkleVetoTests.swift` did), the extraction and the check over the fixture archive and bundles in `LauncherPlatformTests/UpdateFixtures` (as `CodeSignatureTests.swift` does), and `SparkleEngine` over a real `SPUUpdater` on a temporary host bundle whose feed points at a local port nothing listens on (a connection refused before any network use), observed through a weak reference after a main-queue hop, plus the process's loaded images. They miss Sparkle in a signed bundle.
- **`LauncherUITests` benches**: `UpdatePictureView` in a borderless window that is never ordered in, with injected Reduce motion and on-screen readers, as `GearBench.swift` and `GearViewTests.swift` do; the two SVG assets rasterised, as `GearAssetTests` does. They miss SwiftUI's layout of the card, which the slice checks by eye against the Figma node.
- **`Scripts/update-e2e.sh` on two notarised builds, run by a person**, with revision 1's server, sampler and cleanup. It proves Sparkle's behaviour on the wire, on disk and on screen, and the hand-over's timing. Its login rows start the build with `--at-login`.

`SourcePolicyTests` and the release harness (`LauncherKit/Tests/ReleaseTests`) stay as the existing scan and release seams; the harness's rows are unchanged and prove R16 by staying green.

**What is faked**: Sparkle (`InMemoryUpdateEngine`), connectivity (`InMemoryConnection`), the trackpads (`InMemoryTrackpads`), the window's occlusion and Reduce motion (closures), GitHub (the E2E's local server) and `open` (a stub). Everything we own runs for real.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R5, R13 | `LifecycleWorld` | Given a gated copy that can write. When it starts at login. Then `updates == 1` and `probes == 0` inside the launch turn and `windows == [.closed]`. Started by hand: `probes == 1`, `updates == 0`, the window open. Started `.afterUpdate(withWindow: false)` and `.afterUpdate(withWindow: true)`: no engine call at all, the window closed and open respectively. | R1 "once when macOS starts it at login"; R5 "each opening"; R13 "no update check at that start" |
| T2 | R1, R7 | `LifecycleWorld` | Given reading false and `.cycleEnded(.requestFailed)` at login. Then `isWatching` and `updates == 1`; `set(false)` adds none; `set(true)` gives `updates == 2`. Its failure leaves `isWatching` and `set(true)` 100 times adds none. `set(false)` then `set(true)` gives 3. `.cycleEnded(.nothingNew)` on any of them leaves `isWatching` false. | R1 scenario "Network arrives after login"; R7: no schedule, so no second request without a drop and a return |
| T3 | R1 | `LifecycleWorld` | Given reading already true when the login check fails. Then the reading `watch` pushes gives `updates == 2` with no `set` ever called. | Decision 4: entering the wait restarts the watch, which pushes the present reading |
| T4 | R2, R3, R4 | `LifecycleWorld` | Given a login cycle running, two fingers resting on the trackpad through a touch script with no lift, and the window open from a reopen. When `.held`. Then the log ends `["arm restart with window", "end"]` in that same turn with nothing between, and `arms == [true]`. With the window closed and the fingers still down: `arms == [false]`, the same two entries. | R2 "wait for nothing else"; R4 "open at the moment the old version stops"; R3 |
| T5 | R2 | `LifecycleWorld` | Given a login cycle. When `.cycleEnded(.failed)` (the download failed after the feed). Then `isWatching` is false, `set(true)` adds nothing and `updates == 1`. The next login on that Mac gives a new process with `updates == 1`. | R2 "MUST NOT retry until the next login start" |
| T6 | R3 | `LifecycleWorld` | Given Arc assigned, the login item on, a non-default thumb corner and *Hide background apps* on, and a hand-over armed silently. When `finishHandOver()`. Then the new process has `windows == [.closed]`, no asks, `probes == 0`, `updates == 0`, the seeded settings, `loginItem.calls` empty, and `tap(1)` brings Arc to the front. | R3 literals; the seed |
| T7 | R4, R13 | `LifecycleWorld` | Given a login cycle running. When `openAgain(.byHand)`. Then the window is open, `probes == 0` and `card == nil`; `closeWindow()` and `openAgain` again add no probe. When `.held`. Then `arms == [true]`, and `finishHandOver(withWindow: true)` gives a process whose last window is `.open(request: 1)` with `probes == 0` and `card == nil`. | R4 scenario; R13 "no update check at that start" |
| T8 | R5, R11 | `LifecycleWorld` | Given a by-hand resident whose start's probe ended `.nothingNew`. When the window closes and opens. Then `probes == 2` and `card == nil` before any answer. `openAgain` while open adds none. When the window closes during a probe and `.cycleEnded(.found)` arrives. Then `card == nil`, and the next opening gives `probes == 3`. When the window closes during a probe and opens again before the answer. Then `probes` is unchanged, `card == nil`, and `.cycleEnded(.found)` then gives `card == .available`. When a probe ends `.requestFailed` on this copy. Then `card == nil` and `isWatching` is false. | R5 scenarios "Reopening", "Closing during a check", "Reopened offline"; R11 "Failed check"; decision 4's dropped probe |
| T9 | R6, R11 | `LifecycleWorld` | Given a probe running. Then `updates == 0`. When `.cycleEnded(.found)`. Then `card == .available` and `updates == 0` still. When the window closes. Then `card == nil`. | R6 "downloads nothing"; R11 "the card appears only after that opening's check" |
| T10 | R1, R5 | `LifecycleWorld` | Given a login check failed for the network with reading false. When the window opens. Then `isWatching` is false and `probes == 1`. The probe ends `.requestFailed`: `isWatching` again and `card == nil`; `set(true)` then gives `updates == 2`. Separately, the window closes during the probe and `set(true)` arrives before its answer: `updates` stays 1 and `overlaps == 0`; the answer `.requestFailed` then makes `isWatching` true and the present reading gives `updates == 2`. Separately, the retry had already been spent on a steady reading of true before the window opened: the probe's `.requestFailed` makes `isWatching` true and `updates` stays 2 until a `set(false)` and `set(true)`. Separately, the probe ends `.nothingNew`: `isWatching` stays false for ever. | R1 "until a check completes"; R5 "Reopened offline"; decision 4: one cycle at a time, the debt carries its spent bit |
| T11 | R8, R19 | `LifecycleWorld` | Given every combination of `Placement`, Developer ID signed and can write, at login and by hand. Then only a signed copy in /Applications has an `Updater`; of those, at login only one that can write has `updates == 1`, the other has no engine call; by hand every one of them has `probes == 1`. A release copy `.elsewhere` by hand shows the dialog with no engine call, and the installed copy it opens probes. | R8's and R19's rules written out as a literal table; R8 scenario "Copy in ~/Applications" |
| T12 | R13 | `LifecycleWorld` | Given `card == .available`. When `updateNow()`. Then `updates == 1` and `card == .updating`. When the window closes and opens. Then `probes` is unchanged and `card == .updating`. When `.held` with the window closed. Then `arms == [true]` and the log ends `["arm restart with window", "end"]`. `finishHandOver(withWindow: true)` gives a process with the window open, `probes == 0` and `card == nil`. | R13 scenarios |
| T13 | R14, R18, R19 | `LifecycleWorld` | Given `card == .updating` with the window open. `.cycleEnded(.requestFailed)` gives `card == .available`, `isWatching` false; `.cycleEnded(.failed)` the same; `.cycleEnded(.nothingNew)` gives `card == nil`. `updateNow()` after a failure gives `updates == 2`. With `armWorks = false`, `.held` gives `discards == 1`, no "arm restart", the process running, `tap(1)` working, and `.cycleEnded(.failed)` returns the card. Given `card == .updating` with the window closed: `.cycleEnded(.failed)` gives `card == nil`, and the next opening gives `probes + 1` and `card == nil` until its answer. `finishHandOver(installed: false, withWindow: true)` gives a process with the window open, `probes == 0`, and the world's `installedAt` still nil. | R14 scenarios; R19 "Prompt cancelled"; R18 "a working copy"; decision 4: never end without a restart armed, never a stale card |
| T14 | R15, R18 | `LifecycleWorld` | Given a login cycle and `armWorks = false`. When `.held`. Then `discards == 1`, nothing armed, the process runs on, and `.cycleEnded(.failed)` leaves `isWatching` false, `card == nil` and no "arm restart" in the whole history. A login cycle that ends `.failed` with no `.held` (a refused download) does the same with `discards == 0`. | R18 "MUST NOT try again until the next login start"; R15 "At login it MUST show nothing" |
| T15 | R20 | `LifecycleWorld` | Given each phase: awaiting a connection, a login cycle, a probe, the card, *Updating…*. When `quit()`. Then the process has ended, the login item is off, and the whole history holds no "arm restart". `world.login()` is nil. | R20 scenarios |
| T16 | R21 | `LifecycleWorld` | Given each phase of T15. `shouldEnd(.system)` answers true with the window open and closed, and nothing is armed. `shouldEnd(.other)` with the window open answers false and closes it, and in *Updating…* the card stays `.updating`; with it closed it answers true. | R21; `Lifecycle.shouldEnd`'s table, unchanged |
| T17 | R3, R13, R14 | `LifecycleWorld`, `Route` | `Route` over `.afterUpdate(withWindow: false)` and `(withWindow: true)` × placement × older copy gives: installed → `.runSilently` and `.runWithWindow`; elsewhere → `.askToMove`; development → `.runWithWindow`; every `.atLogin` and `.byHand` row is unchanged. A process started `.afterUpdate(withWindow: true)` with an older copy running stops it rather than ending. | Decision 7's rows; revision 1's `HandOverTests` route table |
| T18 | R1, R14 | Platform, direct | The outcome function over decision 3's table, every row, both kinds, with the feed-read and found flags as the row says. | Decision 3's table; `SUErrors.h` literals |
| T19 | R3, R13 | Platform, direct | `ThisCopy.launch` with `--after-update` gives `.afterUpdate(withWindow: false)`; with `--after-update --with-window`, in either order and beside `--eject-disk-image`, `.afterUpdate(withWindow: true)`; `--with-window` alone is ignored; `--at-login` gives `.atLogin` with no event; the reopen ignores every argument. | Decision 7; existing `ThisCopyTests.swift` |
| T20 | R3, R13, R14, R18 | Platform, real launchd | The real hand-over arguments through `LaunchdJob.submit` with a held `sleep` as the old pid and a temp bundle: without the window, the stub `open` is called once with `-g -a <bundle> --args --after-update`; with it, once with `-a <bundle> --args --after-update --with-window` and no `-g`. The wall-time budget rows of `LaunchdJobTests` stay as they are. | Decision 7; the existing `LaunchdJobTests` call shape |
| T21 | R7, R23 | Platform, real `SPUUpdater` | Given `SparkleEngine` over a temporary host bundle whose Info.plist declares the feed at a closed local port, `SUEnableAutomaticChecks` false, the launcher service key and a key. When `probe()`. Then a weak reference the engine exposes for tests is non-nil, `.cycleEnded(.requestFailed)` arrives, and after one hop through the main queue the reference is nil. A second `probe()` builds a second updater and answers again. `update()` behaves the same. With an empty `SUPublicEDKey`, `update()` answers `.cycleEnded(.failed)` and the reference is nil after the hop. | R23 "exist in memory only during a check"; decision 2 |
| T22 | R23 | Platform, direct | After a Sparkle symbol has been touched, Sparkle's own dependency closure holds neither WebKit nor AppKit (the test host already has WebKit loaded; the whole-process check on the real app is T37's `vmmap` row). `SparkleInternals.provenOn` equals the vendored manifest's tag, and the manifest's flags hold `SPARKLE_BUILD_UI_BITS=0`. | R23 "MUST NOT load WebKit"; decision 1 |
| T23 | R12 | UI bench | Given the view in a window reading on-screen with Reduce motion off. Then the arrow layer and the mask layer each carry exactly one animation, under the same key, on `position.y`, by −4, duration 1.5, autoreversing, repeating for ever, ease-in-out, not removed on completion; the tray layer and the view's own layer carry none. | R12 literals: about 4 points, about every 3 seconds; decision 10 |
| T24 | R12 | UI bench | Reduce motion on from the start: no animation. Turned on live, with the notification: none; off again: as T23. Leaving the window: none; returning: as T23. The on-screen reader answering false, with the occlusion notification: none; true again: as T23. A repeated notification leaves the same animation object in place. | R12 "stop while the window is closed", "Reduce motion" |
| T25 | R11, R12 | UI asset | Both SVGs are 71 × 89. Rasterised, the tray's drawn pixels lie within y 21.3 to 85.8 and x 0 to 71; the arrow's within y 0 to 58.8 and x 19.0 to 52.0; neither is empty. The derived mask is 71 × 97, opaque at a point beside the shaft and transparent on it. | The design path's own coordinates (node 2200:2983) |
| T26 | R22 | `SourcePolicyTests` | The kept-out table finds none of its tokens in any frame-path file; a planted `isTouched` in a copy of the frame stream fails the scan. `Timer`, `makeTimerSource` and `DispatchSourceTimer` are banned and listed in the bans-still-listed check. | Decision 8 |
| T27 | R7 | `SourcePolicyTests` | `SUEnableAutomaticChecks` is declared `false` and `SUEnableInstallerLauncherService` `true`; a planted `true` or `false` respectively fails. `SUAutomaticallyUpdate`, `SUScheduledCheckInterval` and `SUEnableDownloaderService` are absent; a planted one fails. | Decision 11 |
| T28 | R1, R2, R3, R22 | `update-e2e.sh` | Given v1 started with `--at-login`, v2 in the feed, the person resting two fingers on the trackpad. Then the feed request and the `.aar` GET arrive with no input; v2 runs from /Applications with `--after-update` within 10 s of the download completing, and the person's gesture reaches the front under 10 s after the old pid's exit. Over the sampler's whole history: no window from any process, activation type `UIElement`, neither the app nor a Sparkle helper frontmost. No request comes from v2 for 180 s. | R2 scenario's 10 s; R3 scenario's 10 s; R22 |
| T29 | R4 | `update-e2e.sh` | Given a login start whose download the server holds mid-body. When the person opens the window and leaves it open. Then no card shows and no second feed request comes; when the server releases the body, v2 opens with its settings window, one process, no feed request at that start. | R4 scenario |
| T30 | R5, R6, R7, R11, R12, R13 | `update-e2e.sh` | Given v1 by hand with its window closed and v2 released. When the person opens the window. Then one feed request and no asset request; the card appears above the gesture rows; the person confirms the arrow drifts and the tray, text and button stay still for ten seconds. Closing and reopening adds one feed request. Pressing *Update now*: the button reads *Updating…*, exactly one more feed request precedes the asset GET, v2 opens with its window and no card, exactly one process runs, and no request comes at that start. | R5, R6, R11, R12, R13 scenarios; decision 12's reading of R7 |
| T31 | R9 | `update-e2e.sh` | With the server offering `Set-Cookie`, `ETag`, `max-age` and a 302 on the asset, over a probe and an update of v1 and a probe of v2 under a changed `AppleLanguages`: every request has no query, no `Cookie` and no validator; `User-Agent` is `TrackpadLauncher`, `Accept-Language` `en`, `Accept-Encoding` `gzip`, the header sets of both versions equal. | R9 scenarios |
| T32 | R10 | `update-e2e.sh` | Feed items of 1.1 and 1.2: the card's update downloads 1.2 and a login start downloads 1.2. 1.1 and a higher one needing macOS 99.0: 1.1. Only the running build, or a lower one, or a pre-release above it: no card and no asset request. | R10 scenarios |
| T33 | R7, R1 | `update-e2e.sh` | A resident by hand with its window closed for 10 minutes after a probe: no request. A feed that answers 503 once to a login start: exactly 2 feed requests within 5 s; one that always answers 503: exactly 2 in 60 s. | R7 scenario; decision 4: no hot loop |
| T34 | R14, R18 | `update-e2e.sh` | A read-only parent set after *Update now*'s download: v1 reopens with its window 5 to 7 s after the exit, `codesign --verify --strict` passes, no request comes at that start, the next opening shows the card. The same from a login start: v1 reopens silently. The server resets the connection during an *Update now* download: the card reads *Update available*, v1 runs. 20 rounds of `kill -9` on the app and 10 on `Autoupdate` at random moments: every sampled read is a whole v1 or v2, no job is left, a relaunch runs with one process. | R14, R18 scenarios |
| T35 | R15 | `update-e2e.sh` | A tampered EdDSA signature; a valid signature on a v2 signed by Apple Development; one not notarised; one with another bundle identifier. From the card: nothing installs, no `Autoupdate` process ever appears in the sampler for the three the update key accepts, the card returns to *Update available*, v1 runs. From a login start: nothing installs, nothing shows. On a standard account, from the card: the same, and no prompt appears. An enclosure of `.dmg` or another host: no asset request. After each, no Sparkle helper process remains and the persistent download is gone. | R15 scenarios; decision 2: refused before any installer exists |
| T36 | R19, R20, R21 | `update-e2e.sh` | On a standard account on this Mac: a login start makes no request and no prompt appears for 60 s. The card's *Update now* shows the administrator prompt only after the asset GET completes; while the prompt is up the person's gesture reaches the front under a second, the window's Quit button ends the app at once and the prompt goes with it, and on another run a logout proceeds at once; the password installs v2, which opens with its window; cancelling returns the card to *Update available* with v1 whole and no error. | R19 scenarios; R20, R21 during the prompt, decision 1 |
| T37 | R20, R23 | `update-e2e.sh` | *Quit Trackpad Launcher* pressed while the button reads *Updating…* with the download held mid-body: the process is gone at once, the bundle stays v1, nothing runs for 120 s, no job is listed. After a probe that found nothing: no `Autoupdate`, `Updater.app` or launcher service process runs, `heap` of the app shows no `SPUUpdater`, and `vmmap` shows no WebKit. | R20 scenario; R23 scenario |
| T38 | R13 | `LauncherCoreTests`, direct | `UpdateCard.available` has the button title *Update now* and is enabled; `.updating` has *Updating…* and is disabled; the title text is *Update available* for both. | R13 literals; the design's words |
| T39 | R15 | Platform, direct | The persistent download lookup over temp folders in Sparkle's layout: no folder is nil; one `.aar` in the item's build folder under one random folder is it; two folders, the newest wins; another file name or a different extension is nil. The extraction over the fixture archive yields exactly one bundle in a scratch folder that is gone after the check; `isGenuine` on it against the fixture's recorded offer is true, and against another team, identifier, version, build or minimum macOS false; the Apple Development bundle false. A refused archive is removed from the temp layout and a genuine one is left. | `fixture.json`; `make-update-fixtures.sh`; decision 2 |
| T40 | R15 | Platform, direct | The user driver's reply at `showUpdateFound` is *install* for the not-downloaded and downloaded stages and *skip* for the installing stage, through its pure rule over an internal mirror of the stage. | Decision 2; Sparkle's `SPUUserUpdateStage` |
| T41 | R21 | `update-e2e.sh`, by hand | A real logout, a restart and a shutdown, each while a login download is held mid-body and once with the window open: each proceeds at once with no dialog, and the next login start checks again and installs. | R21 scenario |

### Verified without a test

- **R16.** The release harness's rows (`ReleaseTests`) and `CardContract`'s tests stay green with `release.sh` unchanged but for the tools' path; the harness's stub for `sign_update` points at the vendored binary.
- **R17.** By hand on a notarised copy with Accessibility and Screen Recording granted, the login item on, a non-default thumb corner and *Hide background apps* on: let a login update and a card update install. Expected: System Settings shows all of it unchanged, click blocking and window previews work, the next login starts the app, no prompt appeared. A test cannot grant TCC or log in.
- **R24.** Before publishing: `card-contract` and its tests are untouched by this revision (a diff shows no change under `CardContract`), and the release runs it on the archive. After the first revision-2 release is published, by hand: install the published 1.0.15, open its window, press *Update now*. Expected: it installs and opens with its window. The old card reads the published list, so this step can only follow publishing; its result goes in the development log then.

## Further Notes

- **Residual gaps, named.** An EdDSA-valid archive swapped in the user's cache between our check and Sparkle's extraction would install unchecked; it needs the publisher's private key. The login path's no-prompt rule rests on `canReplace` agreeing with Sparkle's own test of the bundle; where a temporary failure makes them disagree, the launcher service shows the system's prompt once at login, in its own process, and a cancel ends the cycle `.failed`. The engine's comment that claims "never a prompt" is corrected.
- **The probe cannot be cancelled.** A window closed within a second of opening still lets the in-flight feed request complete; its answer is ignored, and no later request follows. R5's scenario holds as written.
- **Sparkle's persistent download layout** (`PersistentDownloads/<random>/<host name> <build>/<file>` under the app's Sparkle cache, the build folder named by Sparkle's download driver) is the one private fact this revision adds to `SparkleInternals`; T39 proves the lookup over the layout, T35 proves it on the real cache. The extraction layout and the installer job's label leave that type.
- **The design's measurements.** This session could not open the Figma file; the card's insets and the picture's offset are read from node 2200-2970 at implementation and checked by eye. The symbol's path data is in decision 10.
- **Revision 1's E2E never ran.** Its infrastructure is kept on trust and proven only when a person runs the re-cut script (S5). The human's `generate_keys` is still needed before any release.
- **`heap` and `vmmap` in T37** are observations of what exists, not measurements of how much: the non-goal stands.

## Slices

Each slice lands green on `swift test` and is a change on top of the current branch. The E2E and by-hand rows need a person with credentials, so they sit in their own slice. Nothing here ships before the last slice, so a slice may leave the app with a partial update path.

### S1: Sparkle from its pinned source, without its UI

**What to build:** the app links a Sparkle built by one script from the pinned tag with the UI and legacy parts off, vendored as a local binary target with its two signing tools and a manifest; the framework loads neither WebKit nor AppKit; `release.sh` signs with the vendored tool.

**Blocked by:** None (can start immediately).

**Requirements:** R23 (WebKit and the interface half).

**Test scenarios:** T22.

**Skills:** `axiom-macos`

- [ ] The build script fails on a `WebKit` or `AppKit` load command in the framework binary, and its manifest records the tag, commit, flags and Xcode version.
- [ ] The remote package, `Package.resolved`'s pin, `--disable-keychain` and `-packageAuthorizationProvider netrc` are gone; `swift test`, `make run` and `release.sh --archive-only` build with the vendored framework.
- [ ] The framework embeds the installer launcher service and no downloader service; `project.yml` declares `SUEnableInstallerLauncherService: true`.
- [ ] The exported archive still re-signs `Autoupdate`, `Updater.app` and the launcher service with the Developer ID, and the strict check on `Autoupdate`'s team passes.
- [ ] The preflight finds `sign_update` and `generate_keys` in the vendored folder.

### S2: Install the moment the update is prepared, and the trackpad knows nothing

**What to build:** a held genuine update arms the restart and ends the process in the same turn; nothing waits for the trackpad or the window; every trace of contact sensing and the idle clock is gone from the frame path, the model, the ports and the tests, and the scan keeps it out.

**Blocked by:** None (can start immediately).

**Requirements:** R2 (install at once), R22.

**Test scenarios:** T4 (the arm's flag lands in S3; here the arm is unflagged), T26.

**Skills:** `swift-concurrency`, `swift-testing-pro`

- [ ] The frame callback has no lock, flag or hop that revision 1 added; a diff against `38af524` shows the frame-path files equal but for unrelated lines.
- [ ] The review, recorded in the development log, reads every frame-path file and finds no update code (R22's review half).
- [ ] `UpdateWaitsTests`, `DeviceSessionContactTests` and `SystemIdleClockTests` are gone, and the rest of the suite is green.

### S3: The engine on demand, and the login path with its window

**What to build:** a login start of a copy that can replace itself reads the feed, downloads, refuses an archive that is not genuine before any installer exists, prepares and hands over at once, silently or with its settings window when one is open; a start by hand or after an update makes no check at start (the window's check arrives in S4); the engine builds one `SPUUpdater` per cycle on the user-initiated driver with the same headers and policies on each and drops it at the cycle's end; no schedule exists; a failed login check retries when a connection returns; a failed install reopens the old copy the same way. `Updater`'s card property exists from here, always nil until S4 makes its phases reachable.

**Blocked by:** S1, S2.

**Requirements:** R1, R2, R3, R4, R7, R8 (the login half), R9, R10, R15, R18, R19 (the login half), R20, R21 (the login phases), R23 (the on-demand half).

**Test scenarios:** T1 (the login and after-update rows), T2, T3, T4, T5, T6, T7, T11 (the login rows), T14, T15 (the login phases: awaiting a connection, a login cycle), T16 (the same phases), T17, T18, T19, T20, T21, T27, T39, T40.

**Skills:** `swift-concurrency`, `swift-testing-pro`, `axiom-macos`

- [ ] `checkForUpdatesInBackground`, `willInstallUpdateOnQuit`, `sessionInProgress`, the pending-check flag, the extraction-layout lookup and the job veto are gone from the engine; `import Sparkle` and `AppleArchive` are each in one Platform file.
- [ ] The genuineness check runs inside `didDownloadUpdate` on the engine's own extraction, a refused archive is removed there, and `showReady` holds a genuine update and replies *skip* on discard.
- [ ] Every fresh updater gets `userAgentString`, `httpHeaders`, the cookie policy and the empty cache, as revision 1 set them; the enclosure pin and Sparkle's selection are untouched (R9, R10).
- [ ] `project.yml` declares `SUEnableAutomaticChecks: false`, `SUEnableInstallerLauncherService: true` and no `SUAutomaticallyUpdate`.
- [ ] `Lifecycle` calls `openedByHand()` before `updater.start`, and `start` takes `opensWindow`.

### S4: The card

**What to build:** each opening of the settings window checks; a newer version shows the card as the window's first group, its arrow drifting and its tray still; *Update now* downloads, installs at once and opens the new version with its window; a failure returns the card; closing the window drops a check or the card, and keeps the card through an update.

**Blocked by:** S3.

**Requirements:** R5, R6, R8 (the card half), R11, R12, R13, R14, R19 (the card half), R20 and R21 (the card phases).

**Test scenarios:** T1 (the by-hand row), T8, T9, T10, T11 (the by-hand rows), T12, T13, T15 (the card phases: a probe, the card, *Updating…*), T16 (the same phases), T23, T24, T25, T38.

**Skills:** `axiom-swiftui`, `axiom-macos`, `swift-testing-pro`

- [ ] The card's insets, fonts and the picture's offset match Figma node 2200-2970 side by side, in light and dark appearance; the picture is clipped at the card's trailing edge, and at the arrow's highest and lowest positions nothing of it shows outside the card.
- [ ] The card has no dismiss control and no version text; the Quit button stays enabled during *Updating…*.
- [ ] The window refits when the card appears and when it goes.
- [ ] `Launcher` holds no reference to `Updater`; the window's edges reach it through `onWindowEdge` only.

### S5: Real builds prove it

**What to build:** `update-e2e.sh` re-cut to revision 2's rows, its builds starting with `--at-login` where a login start is meant, run by a person with the Developer ID, the notary profile, `sudo` and a standard account on this Mac; the real logout, restart and shutdown during a login download, by hand.

**Blocked by:** S4.

**Requirements:** The proof of R1, R2, R3, R4, R5, R6, R7, R9, R10, R11, R12, R13, R14, R15, R18, R19, R20, R21, R22, R23 on notarised builds.

**Test scenarios:** T28, T29, T30, T31, T32, T33, T34, T35, T36, T37, T41.

**Skills:** `axiom-macos`

- [ ] A person runs the script and its report, T41's hand-run rows included, is attached to the PR.
- [ ] Cleanup leaves no `.e2e` copy, job, defaults domain, login item or standard-account leftover.

### S6: The docs match what shipped, and the first release is cleared

**What to build:** `docs/architecture.md` and `docs/domain-model.md` confirmed against the shipped code; `docs/product-overview.md`, `README.md` and `release.sh`'s header rewritten to revision 2; the by-hand checks run; the update key created and backed up.

**Blocked by:** S5.

**Requirements:** R16, R17, R24, the checks under Verified without a test.

**Test scenarios:** None.

**Skills:** None.

- [ ] The product overview's privacy sentence and the README's update paragraphs say what the plan's Solution says, *Update now*'s second read of the list included.
- [ ] The human runs `generate_keys` from the vendored tools, stores `generate_keys -x` outside this Mac, puts the public key in `project.yml`, and the preflight passes.
- [ ] Every check under Verified without a test is run and its result is in the development log, except R24's press of the old card, which follows the first published release and is logged then.


## Card measurements from Figma (node 2200:2979, read in the session)

- Group: its own rounded group, corner radius 12, fill `rgba(0,0,0,0.03)` like the other groups, plus a 1 pt border `#DEDEDE` that the other groups lack. Horizontal padding 10. Clips its content.
- Row: a vertical stack, spacing 8, vertical padding 8, at least 42 pt tall; leading-aligned.
  - *Update available*: SF Pro Regular 11 pt, line height 14, primary label colour.
  - *Update now*: the same button as *Close* (24 pt tall, horizontal padding 16, radius 6, fill `rgba(0,0,0,0.08)`, SF Pro Medium 13 pt).
- Picture (node 2200:2983, `square.and.arrow.down.fill` drawn as `plans/039-auto-updates/assets/update-card-symbol.svg`): 71 × 89 pt, fill `#DEDEDE`, placed at x = 203 and y = −8 within the group's padded content (the group is 274 pt wide inside its padding in the design), so it is clipped at the top and the bottom. The design shows it beside the text and button, on the right half of the card.
- The window's other groups follow 10 pt below, as in the current layout.
