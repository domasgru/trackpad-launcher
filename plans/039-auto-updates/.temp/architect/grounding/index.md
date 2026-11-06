# Grounding index: automatic updates (plan 039)

Start here. Every fact a design decision rests on is below with its standing. Paths are relative to the worktree root unless absolute.

**Standing.** `probed`: what a probe printed on this machine (macOS 27.2 26B123, Xcode 27.1, Swift 6.4, Apple silicon, 2026-11-06), naming the probe; a conclusion drawn from that output is marked *conclusion*. `sourced`: the file and heading or lines that state it. `disputed`: both sides, with evidence.

**Where things are.**

- Sparkle 2.10.1 source, read for this plan: `/tmp/039-sparkle/src`. Its docs site: `/tmp/039-sparkle/site/documentation`. The framework and tools as shipped: `/tmp/039-sparkle/spm/extracted`. These stay until the arena ends.
- The spike: `grounding/probes/sparkle-spike/`. A real LSUIElement host on Sparkle 2.10.1, signed inside-out with Apple Development and the hardened runtime, one team across host and helpers, XPC services removed, updating from a `.aar` signed with a throwaway EdDSA key, from a local server. Each scenario's raw output is its `.out` file. `SpikeHost.swift` is short and worth reading: it is a working sketch of every Sparkle call this feature needs.
- Traced model of the code: `grounding/how.md`, built from `how-updater.md`, `how-lifecycle.md`, `how-signals.md`, `how-build-release.md`. Rationale and the Preserve / Change / Avoid / Risk constraints: `grounding/why.md`, built from `why-source-control.md`, `why-plans.md`.

## Status

`how` and `why` both ran; this is not greenfield. The design redefines ownership (`Updater`, `Lifecycle`) and reverses standing rules, so `why.md` is a constraint set, not background. Where a probe below changes a `why.md` line, the fact says so.

## A. The Sparkle path that works

| # | Fact | Standing |
|---|---|---|
| A1 | The automatic path is silent. `SUAutomaticallyUpdate`, `SUEnableAutomaticChecks`, `SUVerifyUpdateBeforeExtraction` in Info.plist, with `SPUUpdater(hostBundle:applicationBundle:userDriver:delegate:)` and a user driver that shows nothing. A whole check, download, EdDSA check, extraction and preparation ran with **zero** user driver calls, 0.4 s from `found` to `willInstallUpdateOnQuit`. | probed `selfquit.out` |
| A2 | Sparkle's docs say a custom `SPUUserDriver` "must present a user interface" and "is not used in a way that eliminates UI or installs updates silently"; silent install is `SUAutomaticallyUpdate`. A driver is still required by the initializer. | sourced `custom-user-interfaces/index.md` |
| A3 | `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)` fires after stage 1: archive verified, extracted, validated, Gatekeeper pre-scanned, helpers waiting. Returning true "stalls the current update cycle and prevents future update cycles"; `sessionInProgress` stays true, so `checkForUpdatesInBackground` does nothing while an update waits. Returning false ends the cycle, and the next automatic check waits `max(interval, impatient interval)`, default one week, then runs through the UI-based driver, which calls the user driver. | probed `selfquit.out`; sourced `SPUUpdaterDelegate.h:421-440`, `SPUUpdater.m` `scheduleNextUpdateCheckFiringImmediately` |
| A4 | While an update waits, two helpers stay alive as launchd jobs from inside the bundle: `Autoupdate` (`<id>-sparkle-updater`) and `Updater.app` (`<id>-sparkle-progress`, `LSUIElement`). Both still alive after 75 s of holding. | probed `hold.out` |
| A5 | "In either case Sparkle will always attempt to install the update when the app terminates." Any end of the process with an update waiting installs it, with no relaunch and no job left behind. | probed `plainquit.out` (version 2 on disk, nothing running, no job); sourced `SPUUpdaterDelegate.h:433`, `AppInstaller.m:399-416` |
| A6 | Automatic path requires `SUVerifyUpdateBeforeExtraction = YES` for `.aar`: without it, in the old app, extraction fails. The same `.aar` the card reads can be Sparkle's enclosure. | sourced `AppInstaller.m:270-275`; probed `selfquit.out` |
| A7 | A failed check reaches the delegate as `didAbortWithError` and `didFinishUpdateCycle` with `SUSparkleErrorDomain` code 2001, the URL error nested two levels down. "You're up to date" is code 1001. After a failed check the next one is 86,400 s away. | probed `noserver.out`, `selfquit.out`; sourced `SUErrors.h` |
| A8 | Sparkle's scheduler alone does not satisfy R1. At start it checks only if the last check is over 24 h old, and every check stamps `SULastCheckTime` even when it fails. So a check at every start needs `checkForUpdatesInBackground()` immediately after `start()`, the one moment the docs bless. The docs warn that calling it "at later points can interfere with Sparkle's update scheduler". | sourced `SPUUpdater.m` `checkForUpdatesWithDriver`, `SPUUpdater.h:118-123`, `programmatic-setup/index.md` API Expectations; probed `selfquit.out` (check at start with `lastCheck` absent) |
| A9 | Sparkle's own 24-hour timer is a one-shot `dispatch_walltime` source with 15 s leeway, re-armed after each cycle; its comment says the wall clock is used so that sleep counts. So "sleeping past the mark" fires on wake with no code of ours. Not run across a real sleep. | sourced `SPUUpdaterTimer.m`, `SPUUpdaterSettings.m` |
| A10 | Copies of the app on an unwritable path cannot reach a password prompt on the automatic path: the automatic driver launches the installer with interaction refused, gets `AuthorizeLater`, and hands to the scheduled driver, which asks the user driver; a driver that answers `.dismiss` ends it. Run with the parent folder read-only: no prompt, cycle ended with no error, the download kept in `PersistentDownloads`. | probed `failquit.out` (second half); sourced `SUInstallerLauncher.m`, `SPUInstallerDriver.m:445-447` |
| A11 | Sparkle's own writability rule, private: `SPUSystemNeedsAuthorizationAccessForBundlePath`: bundle writable, parent writable, and a temp file can be chowned to the bundle's owner and group. | sourced `SUInstallerLauncher.m` |
| A12 | A delegate-pinned feed choice exists: `updater(_:shouldProceedWithUpdate:updateCheck:)` runs before any download and can refuse an item with an error, silently on this path. | sourced `SPUUpdaterDelegate.h:236-252`, `SPUBasicUpdateDriver.m` |
| A13 | Files and defaults Sparkle adds: `~/Library/Caches/<id>/org.sparkle-project.Sparkle/{PersistentDownloads,Installation}`, URLSession's `Cache.db` beside them, `~/Library/HTTPStorages/<id>*`, defaults keys such as `SULastCheckTime`, `SUHasLaunchedBefore`. Stale items are removed after 10 days. | probed `selfquit.out`; sourced `SPULocalCacheDirectory.m` |

## B. How the old copy ends and the new one starts

| # | Fact | Standing |
|---|---|---|
| B1 | Sparkle's immediate handler ends the host with a quit Apple event from its `Updater.app` agent: `aevt/quit`, sender pid = the agent, no quit reason. `QuitSignals` reads that as `.other`, the Dock's Quit, which `shouldEnd` can refuse and which closes an open window. | probed `immediate.out`; sourced `how-lifecycle.md` §5 |
| B2 | That relaunch is `[NSWorkspace openURL:]`: no arguments, `aevt/oapp`, no `keyAEPropData`, args empty. It cannot be told from an opening by hand, so it opens the settings window unless an out-of-band marker says otherwise. | probed `immediate.out`; sourced `InstallerProgressAppController.m:408` |
| B3 | With the handler, relaunch is always requested; `updaterShouldRelaunchApplication` returning false aborts the install rather than skipping the relaunch. A quit refused after the handler leaves the installer armed with relaunch on, so a later *Quit Trackpad Launcher* would restart the app and break R13. | sourced `SPUInstallerDriver.m:503-519`, `AppInstaller.m:654-664`; `how-lifecycle.md` non-obvious 4 |
| B4 | The alternative, proven here: the host holds the install, submits a one-shot launchd job, and ends itself. Sparkle installs on termination with relaunch off; the job then runs `/usr/bin/open -g -a <bundle> --args --after-update`. Version 2 ran 203 ms after the old process ended, 190 ms from /Applications. The argument arrived, `active=false`, policy accessory, the frontmost app unchanged, no job left. | probed `selfquit.out`, `applications.out` |
| B5 | The job was submitted with `SMJobSubmit` to `kSMDomainUserLaunchd`, deprecated since 10.10 and still what Sparkle itself uses for both helpers on this macOS. No prompt, no child process of the app. The new process's parent is launchd (pid 1). | probed `selfquit.out`; sourced `SUInstallerLauncher.m` |
| B6 | *Conclusion:* a launch argument is a positive signal that needs no persisted marker, so a failed or lost relaunch leaves nothing stale. `--eject-disk-image` is the precedent; `ThisCopy.launch` ignores unknown arguments, so older code is unaffected. An opening by hand or a login start is untouched. | probed B4; sourced `how-lifecycle.md` §2 |
| B7 | A process in `--after-update` must not pose as `.atLogin`: `Route(.atLogin, _, olderRuns)` is `.end`. It needs "silent, and stop everyone". `Opening` is matched exhaustively in `Route`, so a third case is compile-forced. | sourced `Core/Lifecycle.swift:18-25`, `how-lifecycle.md` §3 |
| B8 | `Lifecycle.end()` is the way out that leaves starting at login alone; `quit()` turns it off. A hand-over must use `end()`. | sourced `how-lifecycle.md` §5 |
| B9 | Installed copy's name is kept: an archive holding `TrackpadLauncher.app` installed over `SpikeHost.app`, with the host's bundle identifier, and the path stayed `SpikeHost.app`. | probed `renamed.out`; sourced `SUInstaller.m` |
| B10 | Works from /Applications with team-matched helpers: no App Management prompt, owner and group preserved, atomic swap path taken. | probed `applications.out`; sourced `SUPlainInstaller.m:347-369` |
| B11 | A silent new copy survives a hand-over from a copy that once had a window. The old copy was a regular app with a window, then an accessory with it closed: R8's normal state and plan 038's open question. The new copy ran with no window for 126 s until the script stopped it; loginwindow logged the old copy's death and the new copy's check-in, and no "UI element without a visible window" or "terminating subordinate" line. Launched by `open` from a launchd job, it has no app as a parent. The new copy declares no sudden termination, as the shipped rule requires. | probed `survival.out` |

## C. A failed install (R11)

| # | Fact | Standing |
|---|---|---|
| C1 | After the host has ended, a stage 3 failure makes `Autoupdate` clean up and exit 1. Nothing restarts the app: the relaunch call sits only on the success path. Sparkle alone cannot meet R11. | probed `failquit.out`; sourced `AppInstaller.m:799-808`, `:819-824` |
| C2 | With the job of B4, the failed install was recovered: the job waited, found the version unchanged, opened the old copy silently, and the next check tried again. **It took 7.4 s, not the intended 5**: 100 rounds of `sleep 0.05` plus a `plutil` spawn. A bound must be on wall time. | probed `failquit.out` |
| C3 | *Conclusion:* only something outside the old process can recover from C1, and it has to exist before the old process ends. `why.md` Avoid 4 and 5 (no relauncher, no shell with sleeps or pid polling) come from plan 038 and 022, where the old process was alive at hand-over or the failure was another one; they did not weigh R11. See D-1. | conclusion from C1, C2 |
| C4 | The swap is `renamex_np(RENAME_SWAP)`. It needs `Autoupdate` and the update to share a Team ID (`_canPerformSafeAtomicSwap`); otherwise, or when the swap fails, Sparkle falls back to two moves, with a gap. On that fallback a failed second move tries to restore the old app. | sourced `SUFileManager.m:360-363`, `SUPlainInstaller.m:236-314`, `:361-365` |
| C5 | If a helper dies while an update waits, the host learns through `didAbortWithError` (code 4005), the cycle ends and the next check starts over. | probed `veto.out` |

## D. Genuineness (R6)

| # | Fact | Standing |
|---|---|---|
| D1 | **Sparkle does not enforce R6's "same Developer ID".** With `SUVerifyUpdateBeforeExtraction` on, after the EdDSA check it requires only that the update's code signature is valid, with any identity. Without the flag it accepts EdDSA **or** a matching code signature, by design, so keys can rotate. | sourced `SUUpdateValidator.m:170-235`, `:371-375`; `index.md` "Rotating signing keys" |
| D2 | **Nor "same bundle identifier".** The update bundle is found by file name first, then by identifier; a bundle with the host's file name and another identifier passes. | sourced `SUInstaller.m:83-108`. Probed the inverse: another name and identifier is rejected silently, `github.out` |
| D3 | With the flag on, EdDSA failure can still fall back to a Developer ID signed **disk image** of the same team (key rotation), so "carries a signature made with the update key" holds only if the enclosure can never be a `.dmg`. An `.aar` cannot carry a code signature. | sourced `SUUpdateValidator.m:76-95`, `SUCodeSigningVerifier.m:323-` |
| D4 | The extracted update can be read at `willInstallUpdateOnQuit`: `~/Library/Caches/<id>/org.sparkle-project.Sparkle/Installation/<random>/<random>/<name>.app`. This layout is Sparkle's private business, not API. | probed `selfquit.out`; sourced `AppInstaller.m:463`, `:617` |
| D5 | The automatic path gives the host no cancel. A veto that worked: `SMJobRemove(kSMDomainUserLaunchd, "<id>-sparkle-updater", …)`. Result: `didAbortWithError` 4005, cycle finished, next check in 24 h, nothing installed, a later check runs normally. That label is also private. Without a veto the update installs at the next termination (A5). | probed `veto.out` |
| D6 | The UI-based path has a public veto: `showReady(toInstallAndRelaunch:)` answered `.skip` cancels and does not skip the version. It requires leaving the automatic path: A2, and installer interaction allowed, so A10's no-prompt guarantee is lost, and `.install` there shows a progress window if the swap takes over 0.7 s. | sourced `SPUUIBasedUpdateDriver.m`, `SPUUserDriver.h:208-224`, `AppInstaller.m:46`, `:771-787` |
| D7 | `CodeSignature.isGenuine` already does R6's check on a bundle at a path: Developer ID, team, identifier, `notarized`, strict nested validation, offline, in about 19 ms on a stapled app. It also pins the sealed version and minimum macOS to the offer. | sourced `how-updater.md` "What isGenuine checks"; `why-plans.md` M40 |
| D8 | *Conclusion:* R6's second half needs a check of ours. Its inputs are A3's moment, D4's path and D5's or D6's veto; each candidate has to pick and own the coupling to Sparkle's internals. | conclusion from D1-D6 |

## E. What a request reveals (R3)

| # | Fact | Standing |
|---|---|---|
| E1 | Sparkle's default User-Agent is `<name>/<version> Sparkle/<version>`; `userAgentString` overrides it. `httpHeaders` applies to the feed and the download, and survives a 302. With both set, every request carried: `Host`, `Accept`, `Accept-Language: en`, `Accept-Encoding`, `Connection`, `User-Agent: TrackpadLauncher`, and no query string, no validators. `Accept-Encoding` is CFNetwork's default unless `httpHeaders` sets it; setting `gzip` held. | probed `immediate.out`, `applications.out`, `nocookies.out`; sourced `SPUUserAgent+Private.m`, `SPUDownloadDriver.m:124-143`, `SUAppcastDriver.m:66-76` |
| E2 | **Sparkle's session keeps cookies.** It uses `URLSessionConfiguration.default`, and Sparkle has no cookie code at all. A server's `Set-Cookie` came back on the very next request and across a relaunch, in the persistent jar `~/Library/HTTPStorages/<id>.binarycookies`. | probed `immediate.out`; sourced `SPUDownloader.m:89` |
| E3 | `HTTPCookieStorage.shared.cookieAcceptPolicy = .never` before the first request stopped this: no `Cookie` on any later request, a relaunch included. An empty jar file is still created. | probed `nocookies.out` |
| E4 | Real GitHub answers. Sets `_gh_sess`, `_octo` (a year), `logged_in`: `/releases/latest/download/<asset>`. **Sets no cookie:** `/releases/download/<tag>/<asset>`, `raw.githubusercontent.com`, `api.github.com`, `release-assets.githubusercontent.com`. | probed `probes/github-urls/probe.out` |
| E5 | The asset URL redirects once to `release-assets.githubusercontent.com`; Sparkle follows it, the `.aar` is recognised by name, and EdDSA verified, on a real v1.0.15 asset. | probed `github.out` |
| E6 | No system profile is sent unless `SUEnableSystemProfiling` or the setting enables it; then it adds a query string. Default off. | sourced `SPUUpdater.m` `parameterizedFeedURL`, `system-profiling/index.md` |
| E7 | `why-plans.md` M41: URLSession's defaults leak the Darwin version and the user's languages, the reason today's request has fixed headers. | sourced |

## F. The feed and the release (R4, R7, R16)

| # | Fact | Standing |
|---|---|---|
| F1 | Sparkle compares `CFBundleVersion`, not `CFBundleShortVersionString`. Build numbers are plain integers rising by 1, but nothing enforces it: `preflight_version` checks only the marketing version. | sourced `index.md` step 5, `how-build-release.md` "Version and build numbers" |
| F2 | Sparkle filters by `sparkle:minimumSystemVersion` and takes the best remaining item, so R4's "needs a newer macOS" scenario needs older items kept in the feed. Pre-releases stay out because only the release process writes the feed. | sourced `SUAppcastDriver.m`, `publishing/index.md` |
| F3 | **GitHub immutable releases are on for this repository**: assets cannot be added to a published release. A feed as a release asset must go up with `gh release create`, and a rolling asset is impossible. | probed `how-build-release.md` headline 7 |
| F4 | `raw.githubusercontent.com` answers a committed file with 200, no redirect, no cookie, `cache-control: max-age=300`. | probed `probes/github-urls/probe.out` |
| F5 | `generate_appcast` fits poorly: one `--download-url-prefix`, but each release asset has its own tag in its URL; `--maximum-versions` defaults to 3; `rm -rf "$OUT"` removes a local feed; it wrote no EdDSA signature for a bundle with no key. `sign_update --ed-key-file` plus a rendered `<item>` worked. | probed `how-build-release.md` "What Sparkle needs", spike `build.sh` |
| F6 | No EdDSA key exists yet. `generate_keys` stores it in the login keychain; `-x`/`-f` export and import. With `SUVerifyUpdateBeforeExtraction` a lost key can rotate only through a Developer ID signed disk image. | probed `how-build-release.md`; sourced `index.md` |
| F7 | A published asset is the card's contract for as long as older copies may exist; `.aar` name, inner `TrackpadLauncher.app`, stapled, same identity. A second matching `.aar` is forbidden; other assets are ignored. | sourced `how-build-release.md` "What an old update card requires", `why.md` Preserve 4 |
| F8 | Shipped `admits` accepted all 143 entries of a bundle with `Sparkle.framework` (8 symlinks), 0 refused; the real `BundleInstall.unpack` accepted a real export through `--archive-only`, and strict signature flags passed. **Not exercised:** the Developer ID, identifier and `notarized` requirement over nested Sparkle code. | probed `probes/admits-sparkle/admits.out`, `how-build-release.md` headline 4 |
| F9 | The release's self-check is not the card's check. Once the card's code is deleted nothing in the repo runs those rules, yet R16 binds every future release. | sourced `how-build-release.md` non-obvious 4 |
| F10 | Release sequence today: tests, bump, archive, export, notarise, staple, `.aar`, image, notarise, gatekeeper, push, `gh release create`. The notarised, stapled `.aar` exists before anything is pushed, so a notarisation failure publishes nothing. | sourced `how-build-release.md` flow |

## G. Build and packaging

| # | Fact | Standing |
|---|---|---|
| G1 | Sparkle as a dependency of `LauncherPlatform` builds, embeds and archives with `project.yml` unchanged, and `swift test` loads it. Sparkle as a dependency of the app target works too, but its adapter would sit outside `swift test`. A fourth library target was not probed. | probed `how-build-release.md` "Embedding Sparkle" |
| G2 | `-exportArchive` re-signs every nested helper with the export identity and keeps the hardened runtime; inside the `.xcarchive` they are ad hoc. Debug and perf builds keep ad hoc helpers, which is harmless if they never start the updater. No `--deep`, no entitlements needed. | probed `how-build-release.md` |
| G3 | **SwiftPM's binary download touched the keychain: the first `swift test` blocked about 8 minutes** in `SecItemCopyMatching`, probably on a dialog. `xcodebuild -packageAuthorizationProvider netrc` finished; a cold `--disable-keychain` is unverified. The artifact is now in this Mac's shared cache. Release and `make test` run plain `swift test`. | probed `how-build-release.md` non-obvious 1 |
| G4 | `LauncherKit/Package.resolved` becomes a new file, not gitignored, and `release.sh:139` refuses a dirty tree. | sourced `how-build-release.md` non-obvious 2 |
| G5 | Sparkle links at load time, with WebKit, in every build, so Debug, perf and copies that never update load it too. Memory cost unmeasured. | probed `how-build-release.md` non-obvious 6 |
| G6 | Removing `XPCServices` is optional for a non-sandboxed app; the spike ran without them; `start()` requires them only when enabled. They are not used by the path in section A. | probed spike; sourced `sandboxing/index.md` "Removing XPC Services" |
| G7 | `LauncherCore` may import Foundation and Observation only. `SourcePolicyTests` scans this repo's `.swift` only, not dependencies. `Timer`, `asyncAfter`, `makeTimerSource`, `Task.sleep`, `import Network`, `Process()`, `.terminate(` outside its file, `http` outside its file, and `URLSession` outside its file all fail or need new rows. Each entry's reason is in `how-signals.md` "SourcePolicyTests". | sourced |

## H. Touch, time and survival (R1, R8, R9)

| # | Fact | Standing |
|---|---|---|
| H1 | No frames arrive while nothing touches the pad, so no-callback is the idle state and there is no heartbeat. | probed `how-signals.md` live probe |
| H2 | The tap point for "contact of any kind" is `DeviceSession.receive`, on `frame.touches` before the recognizer: it sees palm contacts, which `Recognition` and `TrackpadTapState` do not, and not hovers. Use edges (empty to occupied, occupied to empty), because per-frame clock reads are deliberately avoided and each flip costs one hop. | sourced `how-signals.md` "Where a contact signal can be tapped" |
| H3 | `run` replaces sessions: occupied state must reset, and an in-flight edge can vanish. It runs on wake, hot-plug, and preference or trust pushes, with the window closed. | sourced `how-signals.md` "The reset rule" |
| H4 | The window's edges are in `Launcher` (`openedByHand` on `opens`, `closeWindow`). A minimised or hidden window is `.open`. | sourced `how-signals.md` "Settings window reporting" |
| H5 | `LaunchClock`, the one deadline facility, has run 10 s at most in production. A system stop counts as passed, which is right for a cap and wrong for an idle minute. Whether a 60 s deadline runs with the display asleep, and its idle cost, are unmeasured. Its rule says a deadline "cannot outlive that effect", and an install wait has no on-screen effect. | sourced `how-signals.md`, open questions 3, 4 |
| H6 | `docs/architecture.md:20` bans timers and polling so idle CPU stays zero. R8's minute runs only while an update waits, which is minutes a release; nothing about it runs in normal idle. | sourced; *conclusion* |
| H7 | Nothing in the sources observes reachability. `NWPathMonitor` needs `import Network`, banned. `SCNetworkReachability` passes the scan. | sourced `how-signals.md` |
| H8 | With a window shown and closed before the hand-over, focus went to the app for that window only and back; `active=false`, accessory policy and the same frontmost app held across the hand-over itself. | probed `survival.out` |

## I. Disputed

| # | Question | One side | Other side |
|---|---|---|---|
| D-1 | May the app have a relauncher? | `why.md` Avoid 4, 5; `P038:52`; `SourcePolicyTests` "nothing relaunches the app"; glossary: never relaunches itself after a crash or a force quit; `P021`. | R11 requires a working copy within 10 s; C1 shows Sparkle will not do it; C2 shows a one-shot job does. The glossary and the scan's rule are about crashes and force quits, and a hand-over is neither. |
| D-2 | Do "no timers" and R1/R8 fit? | `docs/architecture.md:20`; the scan; `why.md` Change 4 says amend on purpose, not bypass. | Sparkle's 24 h timer lives in its binary (A9). R8's minute needs a place: `LaunchClock` (H5) or a confined one-shot timer. Either way the rule's text changes. |
| D-3 | Does a logout reach `Lifecycle` as `.system`? | `docs/architecture.md:11` says so. | `L038:15`: "PENDING HUMAN CHECK (R2), NOT DONE"; no record shows it ran; M25: no one has observed a real logout's quit event. R14 rests on it. |
| D-4 | "At every moment" whole in /Applications. | R11; the `RENAME_SWAP` contract. | a18fcbd: a lookup racing the bare syscall "can find no entry for a moment". |
| D-5 | "No logging." | The plan's privacy rule; the scan covers our Swift. | `SULog` writes to `os_log` under `org.sparkle-project.Sparkle` with no off switch (`SULog.m`), update URL and paths included. Local only. |

## J. Sources by design question

- **Sparkle integration:** `Sparkle/SPUUpdaterDelegate.h` (all), `SPUUserDriver.h`, `SPUUpdater.m`, `SPUAutomaticUpdateDriver.m`, `SPUCoreBasedUpdateDriver.m`, `SPUUIBasedUpdateDriver.m`; docs `customization`, `custom-user-interfaces`, `programmatic-setup` "API Expectations".
- **Install, relaunch, failure:** `Autoupdate/AppInstaller.m`, `SUPlainInstaller.m`, `SUInstaller.m`, `InstallerLauncher/SUInstallerLauncher.m`, `Sparkle/InstallerProgress/InstallerProgressAppController.m`.
- **Validation:** `Sparkle/SUUpdateValidator.m`, `Autoupdate/SUCodeSigningVerifier.m`; docs `index.md` "Rotating signing keys".
- **Requests:** `Downloader/SPUDownloader.m`, `Sparkle/SPUDownloadDriver.m`, `SUAppcastDriver.m`.
- **Feed and release:** docs `publishing/index.md`; `how-build-release.md`.
- **Lifecycle, quit, start classes:** `how-lifecycle.md`; `why.md` Preserve 1-3, 8, 12.
- **Touch and window signals, clocks, source policy:** `how-signals.md`.
- **Deletion inventory, what the move keeps:** `how-updater.md`.

## K. What a test can produce for real

| Thing | Real in `swift test` | Real only in a built-app run | Manual or field |
|---|---|---|---|
| R8's rule, R1's retry and start rules, R2/R12's gate, the feed-item policy | Yes, pure or model level, clock and pad and connectivity behind in-memory adapters | | |
| Start classification, quit table, hand-over order | Yes, through `LifecycleWorld` | | |
| Contact edges | Yes, `DeviceSession.receive` by direct call (`DeviceSessionAnswerTests`) | | Real lift on real hardware |
| Sparkle delegate calls, headers, cookies, EdDSA, install, relaunch, failed install, veto | No: needs a built, signed bundle with helpers | Yes: the spike does each in about 15 s with Apple Development signing and a local server. `applications.sh` shows the /Applications form | |
| A real offline-then-online check | Connectivity adapter fake | | Toggling Wi-Fi by hand |
| Sleep past the 24 h mark | | | By hand; `defaults write SULastCheckTime` shortens the wait |
| TCC grants and the login item across a Developer ID, notarised install | | | By hand on a notarised build: open in every plan (`why.md` Risk 4) |
| A real logout, restart, shutdown with an update waiting | | | By hand (D-3) |
| R16: 1.0.14 or 1.0.15 installing the first automatic version | | | By hand with a real older copy and a notarised build |

`why.md` Inferred: fakes and stand-ins hid plans 035's and 038's bugs, so the hand-over needs an end-to-end check, not only unit tests.

## L. Open questions

1. Does a real logout read as `.system` with the window open? (D-3, `why.md` Risk 1.) Human check; also binds shipped copies today.
2. Do TCC grants and the `SMAppService.mainApp` item survive a Developer ID, notarised swap? Same path, identifier and team say yes; never measured.
3. Does a real offline start surface the same error shape as A7? The spike's refusal is `cannotConnectToHost`; a true no-network failure was not produced, because toggling this Mac's network would disturb it.
4. Does an empty frame always follow the last lift on real hardware? (`how-signals.md` open 1.) If not, occupied sticks until the next touch or `run`, which delays the install and fails safe.
5. A 60 s `LaunchClock` deadline with the display asleep, its idle cost, and App Nap on a windowless process. Not probed: `pmset displaysleepnow` would disturb this Mac.
6. Does `systemUptime` stop during sleep? (`how-signals.md` open 2.)
7. Is the Developer ID, notarised form of B4 identical to the Apple Development form? Team matching says yes; only a real notarised build proves it.
8. What should happen to the release's self-check once the card's rules leave the source tree? (F9.)
