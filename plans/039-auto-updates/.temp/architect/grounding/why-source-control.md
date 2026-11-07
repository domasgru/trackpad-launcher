# Why the updater has its current shape: Source Control evidence

### Source
Source control: git history, PR bodies and comments (via `gh`), inline code comments, tests, tracked docs (`docs/`, `README.md`), GitHub releases. `plans/` contents were NOT read (Plans investigator's scope). `research/` was not used.

### What I Searched
- `git log --all --no-merges -n 120`; `git log --follow` on `Updater.swift`, `Lifecycle.swift`, `BundleInstall.swift`; `git log` on `SystemRunningCopies.swift`, `Version.swift`, `Config/Version.xcconfig`.
- `git log --all --since=2026-11-01 --until=2026-11-04` commit bodies across the updater file set (`Updater`, `Update`, `ApplicationsUpdater`, `GitHubReleases`, `BundleInstall`, `PrivilegedInstall`, `CodeSignature`, `release.sh`, `make-update-fixtures.sh`, `architecture.md`).
- Pickaxe `-S`: `NSSupportsSuddenTermination` (whole repo; then limited to `project.yml docs LauncherKit TrackpadLauncher Scripts`; then `"NSSupportsSuddenTermination: true"` on `project.yml` with `--all`), `Sparkle` (`-i`, `--all`, plus `--name-only`), `No network`, `No timers`, `idle CPU`, `0 network calls`, `createsNewApplicationInstance`, `forceTerminate`, `no child processes`, `nothing relaunches the app`, `Entry(token: "Timer"`.
- `--grep` (`-i`): `pdate`, `sparkle`, `logout`, `crash`.
- `git grep -i "sparkle|appcast|EdDSA|no timers|polling|ephemeral|sudden"` over `docs README.md AGENTS.md CLAUDE.md project.yml Scripts LauncherKit Config TrackpadLauncher Makefile`; `git grep -i sparkle 9a99471 -- . ":!plans"`; `git grep -i "update|network|internet|phone home|telemetry"` over `docs/product-overview.md docs/domain-model.md docs/performance.md README.md`.
- `gh pr list --state all`; `gh pr view` with `title,body,author,createdAt,mergedAt,comments,reviews` for #28, #29, #32, #40, #42, #43, #44; `gh api .../pulls/{28,29,44}/comments`; `gh issue list --state all`; `gh release list`; `gh release view v1.0.15`.
- Commit diffs read: 9a99471 (docs, `SourcePolicyTests`, `Lifecycle`, `Launcher`), c9125b6 (docs, `SourcePolicyTests`, `project.yml`), d5b2201, e8be794, 8e1acf0, a18fcbd, 7568ec7, 4d1d892 (sources, `release.sh`), e00ce47 (docs). Messages and stats read: 3fc5f1a, 7107c6f, 0f11238, 31536c1, f94b02c, aa9a2ce, 58ae670. First versions read: `1cf9c4b:docs/architecture.md`, `1cf9c4b:docs/product-overview.md`.
- Current code read in full: `Updater`, `Update`, `Lifecycle`, `Version`, `ApplicationsUpdater`, `GitHubReleases`, `BundleInstall`, `PrivilegedInstall`, `CodeSignature`, `QuitSignals`, `SystemRunningCopies`, `release.sh`, `project.yml`, `SourcePolicyTests`, `UpdateCardView`. Partly: `TrackpadLauncherApp.swift`, `Ports.swift`, `ApplicationsInstaller.swift`, `make-update-fixtures.sh`. Test names or excerpts: `UpdateCheckTests`, `UpdateInstallTests`, `ApplicationsUpdaterTests`, `GitHubReleasesTests`, `BundleInstallTests`, `ReplacingOtherCopiesTests`, `SystemRunningCopiesStopTests`, `PrivilegedInstallTests`.

### Direct Evidence Found

#### 1. Hand-written updater instead of Sparkle
No direct evidence exists in source control proper. See Gaps. The only rationale-adjacent items:

- **What it says**: "Trackpad launcher should be secure and privat - it should do 0 network calls, no logging."
  **Where**: `docs/product-overview.md`, first version in fe0e0d7 (2026-10-08), still readable at `1cf9c4b:docs/product-overview.md`. Amended at 9a99471 to "it should do 0 network calls but one: when its settings window opens, a copy signed with a Developer ID in /Applications reads the public list of releases to see whether a newer version is out, and downloads one only when the user presses *Update now*; no logging."
  **Author and date**: Dominykas Grubys; 2026-10-08, amended 2026-11-03.
  **Relevance**: product-level forcing function behind every network rule. It says nothing about Sparkle.
- **What it says**: Hardening of the source scan in 9a99471 replaced the blanket `Entry(token: "URLSession", rule: "network")` with a list of narrower bans and `Confined(token: "URLSession", onlyIn: ["GitHubReleases.swift"], rule: "the update check and its download are the one network path")`, and `Confined(token: "http", onlyIn: ["GitHubReleases.swift"], rule: "the one network file holds every address")`.
  **Where**: 9a99471, `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`.
  **Relevance**: the app's own source is what is mechanically policed. `scannedRoots` is `LauncherKit/Sources` plus `TrackpadLauncher/` (SourcePolicyTests.swift:221-226), and `.swift` files only, so a binary framework would not be scanned. This is a fact about the test, not a statement of intent.

#### 2. Check only when the settings window opens
- **What it says**: "The one request Trackpad Launcher makes on its own. Each time the settings window opens from closed, a release build in /Applications reads the public list of Trackpad Launcher releases on GitHub, once. Bringing an open window to the front makes no check, and neither does an opening while an update installs. A login start, a closed window, a development build, a copy outside /Applications and a copy showing the move dialog never check."
  **Where**: `docs/domain-model.md` "Update check" (added 9a99471).
  **Relevance**: states the rule, not the reason.
- **What it says**: "The check runs only in a Developer ID copy in /Applications: never at login, while the window is closed, or in development builds."
  **Where**: PR #29 body; author domasgru; 2026-11-03.
  **Relevance**: same rule, stated in the PR.
- **What it says**: "Every installed copy checks for a newer release each time its settings window opens, never in the background, and offers it on a card with *Update now*."
  **Where**: `README.md` "How users get it" (line 71).
  **Relevance**: "never in the background" is the user-facing promise that auto-updates would change.
- **What it says**: test `aLoginStartAndAWholeDayNeverMakeARequestButAnOpeningMakesExactlyOne`; `reopeningAnOpenWindowChecksNothingAndLaterOpeningsCheckAgain`; `aCheckThatTheWindowClosedOnIsDropped`; `aFailedCheckIsSilentAndTheNextOpeningChecksAgain`; `aReleaseCopyOpenedFromDownloadsWithTheDialogUnansweredNeverChecks`; `aDevelopmentBuildOpensItsWindowWithoutACheckOrACard`.
  **Where**: `LauncherKit/Tests/LauncherCoreTests/UpdateCheckTests.swift`.
  **Relevance**: these tests encode the behaviour and will fail or need rewriting under scheduled checks.
- **What it says**: "// A re-front is not an opening: only the edge from closed asks the updater."
  **Where**: `LauncherKit/Sources/LauncherCore/Launcher.swift:229`.
- **What it says**: "A check's result is never kept; a download stops; an install continues."
  **Where**: `LauncherKit/Sources/LauncherCore/Updater.swift:68-69`.

#### 3. Fixed-header ephemeral request
- **What it says**: "The request carries nothing that identifies the user, the Mac or the versions."
  **Where**: PR #29 body.
  **Relevance**: states the purpose directly.
- **What it says**: "The public release list. Every request uses its own ephemeral session (no cookie, cache or credential store, nothing on disk) and HTTPS to GitHub, with no query string and constant headers that name neither the user, the Mac, this version nor macOS, and fails after `stall` seconds in which no byte arrives (the request's own idle timeout: no timer of ours). The one network file."
  **Where**: `LauncherKit/Sources/LauncherPlatform/GitHubReleases.swift:4-7`.
- **What it says**: "No network code except the update check and the download the user starts with *Update now*, confined to one file: one ephemeral session per request, a fixed address with no query string, and fixed headers that name neither the user, the Mac nor any version."
  **Where**: `docs/architecture.md` Privacy and permissions (line 27), introduced 9a99471; it replaced "No network code of any kind".
- **What it says**: "The request is the same on every Mac and every version: a fixed address with no query string, fixed headers that name neither the user, the Mac nor any version, and no cookie."
  **Where**: `docs/domain-model.md` "Update check".
- **What it says**: test `everyCheckSendsTheSameConstantRequestAndStoresNothingTheServerOffers` feeds `Set-Cookie`, `Cache-Control`, `ETag`, `Last-Modified` and asserts two requests are identical, with no `cookie`, `if-none-match` or `if-modified-since`; constant headers exactly `user-agent: TrackpadLauncher`, `accept-language: en`, `accept`, `x-github-api-version`. Second test: `everyRequestOfTheDownloadCarriesTheSameConstantHeadersAcrossTheRedirectAndNoCookie`.
  **Where**: `GitHubReleasesTests.swift:103`, `ApplicationsUpdaterTests.swift:355`.
  **Relevance**: the "same on every version" property is tested, including no conditional-request state.

#### 4. "No timers, no polling"
- **What it says**: "No timers, no polling, no background loops: every input is a push (frames, cfprefs KVO, IOKit notifications, workspace notifications, the TCC Darwin notification, user events). This is what keeps idle CPU at zero."
  **Where**: `1cf9c4b:docs/architecture.md` (2026-10-09, PR #1). The rule predates the updater by 25 days.
  **Relevance**: stated motive is idle CPU. The rule is general, not updater-specific.
- **What it says**: "Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible."
  **Where**: `docs/product-overview.md`, Additional notes.
  **Relevance**: product-level source of the rule.
- **What it says**: 9a99471 extended the push list with "the release list's answer, an update's download progress and outcome, LaunchServices' answer to opening the new version" and added: "Time passes only on Core Animation's clock, and in one network request's own idle timeout (30 s without a byte, reset by every byte, the system's and not a timer of ours)".
  **Where**: `docs/architecture.md` Concurrency (line 20) as changed by 9a99471.
  **Relevance**: the updater was fitted to the rule, with one documented carve-out.
- **What it says**: banned tokens `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink` with rule "timer"; `Task.sleep` with rule "polling". `Timer` entry dates from 1cf9c4b. `theNetworkBansAreAllStillListed` requires `Timer`, `asyncAfter`, `Task.sleep` to stay listed.
  **Where**: `SourcePolicyTests.swift:52-57, 204-214`.
  **Relevance**: any Sparkle glue in `LauncherKit/Sources` or `TrackpadLauncher/` that names these tokens fails the build. Note `Timer` is a substring match per line, so a comment containing it also fails.
- **What it says**: "To forbid something new, add it to `banned` or `neverDeclared`; do not write prose."
  **Where**: `SourcePolicyTests.swift:6`.

#### 5. `Lifecycle` / `Updater` ownership
- **What it says**: "`Updater` owns the update check, the update card and replacing this copy with a newer version. It exists only in a copy truly signed with a Developer ID that lies in /Applications. `Launcher` reports the window's openings and closings to it, and `Lifecycle` reads whether it installs and ends the process once the new version has started."
  **Where**: `docs/architecture.md` Shape (line 11), from 9a99471. The sentence before it changed from "Two" to "Three `@MainActor @Observable` models own every decision."
- **What it says**: "The update model, beside `Lifecycle` and `Launcher`. It exists only where an update check is allowed (see `InstalledRelease`). It owns every update decision: the check each opening makes and dropping a stale one, choosing the offer, the download's cancel rules, what each outcome does to the card, whether an install is under way and when the hand-over to the new version is done. `Launcher` reports the settings window's two transitions; `Lifecycle` reads `isInstalling` and answers `onReplaced`; the window drives `updateNow` and `cancel`."
  **Where**: `Updater.swift:4-8`.
- **What it says**: "While true, *Quit Trackpad Launcher* is disabled and an ordinary quit only closes the window. The one source of that rule."
  **Where**: `Updater.swift:49-50`.
- **What it says**: Lifecycle's `shouldEnd` in 9a99471 gained "// Logout, restart and shutdown always end, mid-install too." and "// With the window closed, an ordinary quit is a script's: end, unless an update installs (as `.moving`)." and `quit()` gained `updater?.isInstalling != true`.
  **Where**: 9a99471, `Lifecycle.swift`; now lines 208-217, 233-237.
  **Relevance**: the rule is that a system quit always wins, even mid-install.
- **What it says**: "Only a copy truly signed with a Developer ID and lying in /Applications ever reaches the network. The rule itself is `InstalledRelease.init?`, which the tests call too. `developerIDSigner()` takes no arguments, so `--as-release-build` cannot fake it."
  **Where**: `TrackpadLauncher/TrackpadLauncherApp.swift` (comment on `makeUpdater`).
  **Relevance**: why Updater is optional and gated in the composition root.
- **What it says**: "Read once at start: after a swap, `Bundle.main` would read the new bundle."
  **Where**: `Update.swift:30-31`.
  **Relevance**: a constraint on any code that reads version info after the bundle is replaced in place.
- **What it says**: origin of Lifecycle: "Lifecycle decides what a start, a reopen and a quit do; the menu bar shell is replaced by an ordinary settings window that puts the app in the Dock while open."
  **Where**: c9125b6 squash body (commit acc137d in the branch).

#### 6. New version arrives as an ordinary opening by hand
- **What it says**: "The new version arrives as an ordinary opening by hand."
  **Where**: `docs/architecture.md` Shape (from 9a99471).
- **What it says**: "Any other start or opening of Trackpad Launcher: from Spotlight, Finder, Launchpad, the Dock or Xcode, by a move finishing, or by an update opening the new version."
  **Where**: `docs/domain-model.md` "Opened by hand" (the "update" clause added at 9a99471).
- **What it says**: "Started: this process ends, and the new version, opened by hand from /Applications, stops anything left. Not started: /Applications holds the new version and *Try again* converges (a same-version swap, a second open)."
  **Where**: `Updater.swift:136-137`.
- **What it says**: "// By default the old process, whose bundle was just replaced, only gets a reopen." then `configuration.createsNewApplicationInstance = true`.
  **Where**: `ApplicationsUpdater.swift:68-69`. Confined by the test: `rule: "the new version is opened as a new process in one place"`. Port doc in `Ports.swift`: "Opens the copy now in /Applications as a new process, an opening by hand, never a reopen of this one."
  **Relevance**: states a concrete failure the option prevents.
- **What it says**: "The new version has started: end, as the mover does once it has opened the installed copy."
  **Where**: `Lifecycle.swift:239`.
  **Relevance**: the update hand-over is modelled on the existing move hand-over.
- **What it says**: "Finally it opens the new version with its settings window open and stops the old one. Gestures keep working until then. Every setting, starting at login and the permissions carry over, with no prompt and no first run."
  **Where**: `docs/domain-model.md` "Update card".
  **Relevance**: stated reason-adjacent requirements for the hand-over. A silent update has to re-decide "with its settings window open".
- **What it says**: `Opening.byHand` doc: "Finder, Spotlight, Launchpad, the Dock, Xcode: every opening that is not at login." `Route`: `(.byHand, .installed, _) -> .runWithWindow`. `ThisCopy.opening` reads `marker == OSType(keyAELaunchedAsLogInItem) ? .atLogin : .byHand`.
  **Where**: `Lifecycle.swift:8-9, 23`; `ThisCopy.swift` (seen in the 4d1d892 hunk context).
  **Relevance**: any process start without the login marker opens the settings window. There is no third `Opening` case today.
- **What it says**: test `updateNowDownloadsInstallsOpensTheNewVersionAndEndsTheOldOne(oldCopyAlreadyExited:)` asserts `replacement.window == .open(request: 1)`, `replacement.releases.fetches == 1`, the login item unchanged, no permission asks, and the settings domain identical at every snapshot.
  **Where**: `UpdateInstallTests.swift:46-96`.

#### 7. Single-instance stop-and-wait
- **What it says**: "Only one copy runs at a time, and opening a different build replaces the running one."
  **Where**: PR #28 body; 2026-10-27.
- **What it says**: "At most one Trackpad Launcher runs gestures: an opening by hand stops every other running copy, Debug or release, and waits for their exit."
  **Where**: `docs/architecture.md` Shape (first form in c9125b6; ", Debug or release," added later).
- **What it says**: "`SystemRunningCopies` counts both IDs as the same app (`family(of:)`), so a Debug build and the release still stop each other and only one copy reacts to gestures."
  **Where**: PR #32 body; 2026-11-03.
  **Relevance**: the stated motive for the rule: only one copy reacts to gestures.
- **What it says**: "Stops each at once without asking: a copy can neither refuse, nor ask its user, nor hang the stop. Calls `exited` once, on the main actor, when every listed copy has exited; synchronously when none still runs. The signal is the processes' own termination, never a wait or a poll."
  **Where**: `Ports.swift:170-172`.
  **Relevance**: why `forceTerminate`, not a polite terminate.
- **What it says**: "`stop` waited for `isTerminated` to change on `NSRunningApplication`. On a busy machine that change never arrived for copies already gone, and the caller has no timeout, so a new copy could wait forever without starting. Each exit now comes from the kernel through a process source."
  **Where**: PR #43 body (2026-11-06); commit e8be794; comment at `SystemRunningCopies.swift:28-31`.
  **Relevance**: the second production-relevant failure of the wait. Blast Radius in that PR: "`stop` runs when a new copy replaces an older one and during installation. The stop test covers it with real processes, but the update and install flows were not run end to end."
- **What it says**: "Fixes the crash of a new copy that stops a copy still running, which is what the update hand-over usually does. `SystemRunningCopies.stop` kept the KVO observations but not the observed `NSRunningApplication`s, so an application could deallocate with observers registered when the Apple Event's autorelease pool drained." "Before: the new copy died in 15 of 15 rounds of `plans/035-post-update-crash/repro.sh` on a Release build. After: 15 of 15 alive".
  **Where**: PR #40 body, 2026-11-05; commit 3fc5f1a.
  **Relevance**: the first shipped failure of the hand-over, a crash of the new copy. The fix's `Watch` type was removed one day later by e8be794 when KVO was replaced by a process source.
- **What it says**: Blast Radius (#40): "Every launch that finds another copy running goes through this code, including updates, `make run` beside the installed app, and a move into /Applications. A defect here could stop a new copy from starting."
  **Where**: PR #40 body.
- **What it says**: test names `openingByHandStopsAnEarlierCopyAndStartsOnlyOnceItHasExited`, `aCopyThatAlreadyExitedStartsTheResidentBeforeLaunchedReturns`, `ofTwoLoginStartsTheOlderKeepsRunningAndTheNewerEnds`, `theInstalledCopyEjectsTheMoversDiskImageOnlyAfterTheMoverHasExited`; `stoppedCopiesExitAndTheNewCopySurvives`.
  **Where**: `ReplacingOtherCopiesTests.swift`, `SystemRunningCopiesStopTests.swift`.
  **Relevance**: at login the rule is inverted: the OLDER copy keeps running and the newer ends (Route `(.atLogin, _, true) -> .end`, Lifecycle.swift:20).
- **What it says**: "`olderCopyRuns` matters only at login: two login starts converge on the older copy."
  **Where**: `Lifecycle.swift:16`.

#### 8. No `NSSupportsSuddenTermination`
- **What it says**: "After every in-app update the new version vanished about 3 s after the old one ended, with no crash report. macOS was killing it: loginwindow treats the new copy as a child of the old, and force quits a windowless UI-element child that declares sudden termination." "This removes `NSSupportsSuddenTermination`, adds a policy test so it cannot come back, and documents the rule. The decision rests on the new copy's own Info.plist, so the first update from 1.0.13 is protected too." "Hand-over repro on the real Release app: 0 of 5 alive before, 5 of 5 alive after, both from shipped 1.0.13's Info.plist and from a fixed one."
  **Where**: PR #44 body; domasgru; 2026-11-06.
  **Relevance**: full stated cause, with reproduction.
- **What it says**: "**Not yet verified:** a real logout. Without sudden termination, loginwindow now sends the app a quit event instead of killing it, which the app has never received in practice. A human check is pending; the steps are in `plans/038-post-update-force-quit/development-logs.md`. Run it before releasing."
  **Where**: PR #44 body.
  **Relevance**: an open verification item, not closed by anything I found. Versions 1.0.14 (aafb049) and 1.0.15 were released after this PR. I found no source-control record of the check being run.
- **What it says**: Blast Radius (#44): "Every system-initiated end of the process now goes through `applicationShouldTerminate`. If a logout's quit were misread as an ordinary quit while the settings window is open, the app could cancel that logout."
  **Where**: PR #44 body.
- **What it says**: "The bundle never declares `NSSupportsSuddenTermination`, and no code enables sudden termination: that opening makes the new process a child of the old in LaunchServices, and when a foreground app ends, loginwindow force-quits, 3 s later, every child of it that is a UI element without a visible window and declares sudden termination, which the new version is for its first moments; the opened copy's own declaration decides, so the rule protects even the first update from a version that still declares it. Without the declaration a logout, restart or shutdown reaches the app as the quit event, which `Lifecycle` answers at once. The source-scan test keeps the key out of `project.yml` and the API out of the code."
  **Where**: `docs/architecture.md` Shape (line 11), d5b2201.
- **What it says**: `suddenTerminationRule = "loginwindow force-quits, 3 s after a foreground app ends, every child of it that is a UI element without a visible window and declares sudden termination; the new version is that child for its first moments after an update"`, with `Entry(token: "SuddenTermination", ...)` in `banned`, `Entry(token: "NSSupportsSuddenTermination", ...)` in `neverDeclared`, and `manifestNeverDeclares`.
  **Where**: `SourcePolicyTests.swift:14-18, 95-97, 234-238`.
  **Relevance**: any text "SuddenTermination" in a scanned `.swift` file fails, comments included. `neverDeclared` scans `project.yml` only.
- **What it says**: key was added in `project.yml` as `NSSupportsSuddenTermination: true`, without comment.
  **Where**: acc137d (2026-10-27), squashed into c9125b6 (#28). Removed d5b2201.
  **Relevance**: no stated reason for adding it in the commit message or PR #28.

#### 9. Exchange-based install
- **What it says**: "It downloads the update in memory, installs it only when it is signed with the same Developer ID, notarised and the offered version, swaps it into /Applications in one atomic step, and reopens the new version."
  **Where**: PR #29 body.
- **What it says**: "BundleInstall.swap exchanges the two directory entries with renamex_np(RENAME_SWAP), atomic by contract, rather than relying on how FileManager.replaceItemAt does it. The observer test no longer asserts that no lookup ever misses: the swap-atomicity probe shows a lookup racing even the bare syscall can find no entry for a moment, so a miss cannot tell a swap from a gap. It still asserts no observer reads a mixed or broken copy."
  **Where**: a18fcbd; domasgru; 2026-11-03.
  **Relevance**: direct rationale for `RENAME_SWAP` over `replaceItemAt`.
- **What it says**: Earlier admin script's doc: "Only a kill between the two moves leaves /Applications without the app and the old copy in the staging folder, never inside /Applications." Replaced by "With something at the destination, Foundation's replace runs as root: one exchange of the two directory entries; else one move. The exit status matches what /Applications holds, and a kill at any instant leaves a whole copy there. The script removes nothing."
  **Where**: 8e1acf0 (2026-11-02), `PrivilegedInstall.swift`.
  **Relevance**: the exact failure the exchange removed from the move path of #28: a kill between two `mv` calls.
- **What it says**: "Replaces the running copy in /Applications with a release, then opens it as a new process. The order of effects is unpack, verify, swap, open, end; the swap is the first change anywhere, so a kill at any instant leaves a whole old or a whole new version, and the administrator prompt comes only after the new version is verified. The archive is held in memory until it has all arrived; nothing of the update is on disk except the staging folder while it unpacks and the installed app."
  **Where**: `ApplicationsUpdater.swift:4-8`.
- **What it says**: "At every moment /Applications holds either the whole old version or the whole new one, a restart included." "When the account cannot write there, it asks for an administrator's name and password, after the download and never before; cancelling that returns the card to *Update now*."
  **Where**: `docs/domain-model.md` "Update card".
- **What it says**: "The archive is received into memory: nothing is written until all of it has arrived, so a cancel, a quit, a crash or a logout mid-download leaves nothing on disk."
  **Where**: `GitHubReleases.swift:39-42`. Enforced by `Entry(token: "downloadTask", rule: "the update archive is received into memory, never into a file")` and `.download(`, added by 0f11238.
- **What it says**: Blast Radius: "The administrator path of the existing move to Applications now uses the same atomic swap, so moving into /Applications changes too. This privileged path has not yet run for real as root."
  **Where**: PR #29 body.
- **What it says**: tests `aKillAtAnyEffectOfTheUpdateLeavesAMacThatOpensWholeAndUntouched`, `killingTheRealScriptAtAnyMomentLeavesAWholeCopyAndTheNewOneOnceItExitedZero` (100 rounds), `anObserverNeverReadsAMixedOrBrokenCopyWhilePutAlternatesTwoVersionsIn`, `anArchiveThatIsNotGenuineIsRefusedBeforeAnyPromptEvenWhereThePromptWouldBeNeeded`.
  **Where**: `UpdateInstallTests.swift:247`, `PrivilegedInstallTests.swift:241`, `PrivilegedInstallTests.swift:287`, `ApplicationsUpdaterTests.swift:161`.

#### 10. Verification and the release contract (cross-cutting, directly bears on replacement)
- **What it says**: "Whether a downloaded bundle is the release the card offered: the Developer ID requirement with this copy's team and identifier and Apple's notarisation, checked with strict validation of every architecture, nested code and resource, reading the stapled ticket rather than asking the network; and its sealed Info.plist names exactly `release.version` and `release.minimumMacOS`."
  **Where**: `CodeSignature.swift:56-59`.
- **What it says**: "**Door:** two-way. Reverting removes the updater. But once a release with the updater ships, users' installed copies will check GitHub Releases, so the published release format becomes a contract to keep."
  **Where**: PR #29 body, Merge Danger.
  **Relevance**: the author predicted the exact constraint for a replacement.
- **What it says**: "That asset name, the one bundle in it, `TrackpadLauncher.app`, and the repository's path are a contract with every shipped version's update check."
  **Where**: `docs/architecture.md` Distribution (line 36). Echoed at `GitHubReleases.swift:141` ("the contract with every shipped version"), `BundleInstall.swift:10-11`, `release.sh:39-40`, and 7107c6f ("The update archive keeps TrackpadLauncher.app inside, the name every shipped version accepts").
- **What it says**: `gh release list`: 16 published releases, v1.0.0 (2026-11-03) through v1.0.15 (2026-11-06). `gh release view v1.0.15`: assets `TrackpadLauncher-1.0.15-macOS-26.0.aar`, `TrackpadLauncher.dmg`.
  **Where**: GitHub releases of `domasgru/trackpad-launcher`.
  **Relevance**: 16 versions contain the hand-written check, so `.aar` naming, `api.github.com/repos/domasgru/trackpad-launcher/releases`, `state: "uploaded"`, the `downloadsPrefix`, and the `isGenuine` signature, notarisation and version match must hold for any release those copies should be able to reach.
- **What it says**: "The developer tests the build before running it. gh uploads both assets to a draft and then publishes it, so no older copy, and no immutability lock, sees a half-made release."
  **Where**: 7568ec7; 2026-11-03. README: "Releases are immutable once published: a broken one is fixed by releasing a higher version."
- **What it says**: "Under another identifier a release would be a different app to macOS (fresh grants, settings and login item), and no installed copy would accept it as an update, since the update's genuineness check pins the signer's identifier."
  **Where**: `release.sh:216-217`.
- **What it says**: "The first real release must be checked by hand: start at login and the Accessibility and Screen Recording permissions should survive the update."
  **Where**: PR #29 body.
  **Relevance**: states which user outcomes the author regarded as at risk.

### Indirect / Circumstantial Evidence
- **What it is**: Two independent hand-over defects were found in shipped versions within three days of the first release: #40 (crash, 15 of 15 before fix, 2026-11-05) and #44 (force quit, 0 of 5 alive before fix, 2026-11-06). #43 added a third hand-over-adjacent hang fix.
  **Where**: PRs #40, #43, #44.
  **What it suggests**: the launch of a replacement copy into a running old copy is the riskiest moment in this code. Each defect depended on the old and new copies overlapping in time. The inference is mine and rests only on those PR bodies.
  **Alternative readings**: both may be specific to `NSWorkspace.openApplication` from the old process. PR #44's cause names a parent/child relation in LaunchServices. Whether a different launcher of the new copy creates the same relation is not addressed anywhere in source control.
- **What it is**: `disableRelaunchOnLogin` and "nothing relaunches the app".
  **Where**: `TrackpadLauncherApp.swift:29-30` ("Only the login item starts Trackpad Launcher at login."), `SourcePolicyTests.swift:88-91`, `docs/domain-model.md`: "Trackpad Launcher never relaunches itself after a crash or a force quit."
  **What it suggests**: the product has a stated stance against automatic relaunch of a stopped app, from c9125b6. A quit app stays quit until opened (`Quit` turns off login too). An update that relaunches after install must not break it for a user who pressed *Quit*.
  **Alternative readings**: the rule concerns launch agents and crash relaunch, not updates. The update's own relaunch is already permitted by the docs ("an update also stops the old version and opens the new one").
- **What it is**: The ban "no child processes" (`Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`), added in 9a99471, not in #28.
  **Where**: 9a99471 `SourcePolicyTests.swift`; the same commit's `theNetworkBansAreAllStillListed` lists them among "network bans".
  **What it suggests**: the bans were added when the blanket `URLSession` ban was loosened, so they look like closing network escape hatches (a child `curl`, for example), rather than a general stance on processes. This is inferred from the placement, name of the test, and timing; no text says so.
  **Alternative readings**: a general stance against child processes. The Plans investigator may find the real wording.
- **What it is**: The no-logging scan. The `SourcePolicyTests` doc says "APIs the product promises never to use". `no logging` is enforced by tokens `print(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os`.
  **Where**: `SourcePolicyTests.swift:4, 19-26`; `docs/product-overview.md`.
  **What it suggests**: product promise includes no logging, and it applies to shipped source. A linked framework that logs would meet the letter of the scan but not obviously the "no logging" promise. That tension is unaddressed in history because no third-party dependency has shipped.
  **Alternative readings**: none found.
- **What it is**: No third-party dependency exists in the app. `project.yml` `packages:` lists only the local `LauncherKit`. Docs: "hardened runtime, no entitlements", and on MultitouchSupport "it is Apple-signed, so the hardened runtime needs no library-validation exception."
  **Where**: `project.yml:12-14`, `docs/architecture.md` lines 26, 35.
  **What it suggests**: a framework would be the first third-party code, and would change the "no entitlements" and "Never sign with `--deep`; the main executable is signed last" surfaces (`release.sh:15-16`: "Signing of the app is left to xcodebuild, which signs nested code first and the main executable last; --deep is never used.").
  **Alternative readings**: neither rule forbids a framework. `CodeSignature.isGenuine` already checks nested code (`kSecCSCheckNestedCode`), so nested code was anticipated by the check.
- **What it is**: The architecture rule "Every port has exactly two adapters: the real one in `LauncherPlatform` and an in-memory one in the tests".
  **Where**: `docs/architecture.md` Shape.
  **What it suggests**: `ReleaseList` and `UpdateInstaller` ports exist because of that rule. A Sparkle-backed adapter would have to sit behind ports for `Updater`'s synchronous tests, or those tests go.
  **Alternative readings**: Updater could be deleted outright with its ports.
- **What it is**: Rapid release cadence: 16 releases in under four days, all from `Scripts/release.sh` run on the developer's Mac.
  **Where**: `gh release list`; `README.md` "Releasing".
  **What it suggests**: release tooling is one human-run command. A signing key for update feeds would sit on that one Mac. Inference only.
- **What it is**: `Version` deliberately rejects non-numeric versions and ignores trailing zeros; `release.sh` mirrors it (`NUMERIC`, `normalise_version`, "exactly what the app's Version parses").
  **Where**: `Version.swift:3-5`; 4d1d892 `release.sh`. Commit title: "the release preflight refuses an equal version".
  **What it suggests**: version comparison was treated as a contract. Build number (`CFBundleVersion`) is never compared by the current updater, only `CFBundleShortVersionString`. That is a fact of the code; no evidence says it was a considered choice.
  **Alternative readings**: none found.

### Contradictions
1. **Admin path atomicity basis.** a18fcbd moves the unprivileged path off `FileManager.replaceItemAt` "rather than relying on how FileManager.replaceItemAt does it". Yet `PrivilegedInstall.exchange` (8e1acf0, current) still runs the same Foundation call (`replaceItemAtURLWithItemAtURL...`) as root via JXA, and its doc claims "one exchange of the two directory entries". `docs/architecture.md` line 32: "The administrator's, one atomic exchange". The test comment distinguishes them: "That a kill at any instant leaves a whole copy rests on that exchange's contract and, for the administrator's script, on the kill test above" (`PrivilegedInstallTests.swift:313-317`). So the two paths rest on different guarantees while the docs present them as one.
2. **"At every moment" vs "for a moment".** `docs/domain-model.md`: "At every moment /Applications holds either the whole old version or the whole new one". a18fcbd: "a lookup racing even the bare syscall can find no entry for a moment, so a miss cannot tell a swap from a gap", and the assertion on `report.missing` was deleted. On-disk state and observed lookups differ; the doc does not mention it.
3. **`stop` promise vs observed behaviour.** `Ports.swift:170`: "a copy can neither refuse, nor ask its user, nor hang the stop". e8be794 and PR #43: stop could wait forever on `isTerminated`, "and the caller has no timeout". Current code answers this with a process source, but still has no timeout: the `.replacingOthers` stage has no deadline, and no text discusses adding one.
4. **"No child processes" vs the administrator path.** The ban exists, yet `PrivilegedInstall` runs `/bin/sh`, which runs `/usr/bin/osascript` or `/bin/mv`, through `AuthorizationExecuteWithPrivileges`, which is confined rather than banned (`SourcePolicyTests.swift:191-195`). Comment there: "`AuthorizationExecuteWithPrivileges` is deprecated and has no public Swift import, but is still exported: resolved with `dlsym`, no link flags."
5. **PR #29 body vs the commits in it.** Body: "The release script now also publishes the archive older copies look for, as a draft GitHub release." and "Pending: `Scripts/make-update-fixtures.sh` needs the notary profile (7 tests skip until it runs)." Commits in the same PR: 7568ec7 publishes in one step (draft removed), 0d54e01 "the seven tests that skipped without them now run." The body is stale; trust the commits.
6. **Who ends the old copy.** `docs/domain-model.md`: "it opens the new version ... and stops the old one." Code: the old process ends itself on `started` (`Updater.opened` -> `onReplaced` -> `Lifecycle.replaced` -> `end()`), and the new copy `stop`s "anything left". PR #40 says stopping "a copy still running ... is what the update hand-over usually does." The test takes both orders as `oldCopyAlreadyExited: [true, false]`. So the order is a race, handled but described inconsistently.
7. **"The one request."** `docs/domain-model.md` calls the check "The one request Trackpad Launcher makes on its own", and product-overview says "0 network calls but one". The download is a further user-started request, with a redirect to a second host ("across the one redirect to the release assets' host", `GitHubReleases.swift:41-42`). Consistent only under "on its own". A silent background download would make that wording false.

### Gaps
- `git log --all -i --grep=sparkle`: no commit message mentions Sparkle. `git log --all -i -S Sparkle`: only b47e860 and 9a99471, and `--name-only` shows only files under `plans/022-in-app-updates/` (`plan.md` and `.temp/architect/...`). `git grep -i sparkle 9a99471 -- . ":!plans"`: nothing. Current tracked docs, code and scripts: nothing for `sparkle`, `appcast`, `EdDSA`. So no rationale for rejecting Sparkle exists in commit messages, PR bodies, code comments or docs. Whatever exists is in plans.
- PR #29 body gives no reason for writing the updater by hand, and no reason why the check runs at window-open rather than on a schedule.
- `gh pr view` shows `comments: []` and `reviews: []` for #28, #29, #32, #40, #42, #43, #44. `gh api .../pulls/{28,29,44}/comments` returned 0 for each. No review discussion exists on GitHub for these PRs. Time from PR open to merge by the author: #40 9 s, #32 7 s, #44 under 6 min, #29 49 min, #43 under 3 h, #28 about 22 h.
- `gh issue list --state all`: no issues in the repository.
- `git log --all -i --grep=logout`: no commit message mentions logout. No record that the PR #44 real-logout check ran, nor that the #29 privileged path ("has not yet run for real as root"), or the #28 unverified items ("Starting silently at login on macOS 26, logging out with the window open, and Accessibility following a moved copy") were later confirmed.
- No source-control statement explains why `acc137d` added `NSSupportsSuddenTermination`. Nor why GitHub Releases rather than another host. The fixed-header purpose is stated, the choice of host is not.
- No statement on delta updates, update cadence, channel policy, or what happens to a user who never opens settings. The last is an implicit consequence of the window-only check: nothing states it was accepted knowingly.
- No statement on why Apple Archive `.aar` rather than zip or dmg. Only that it is received into memory and streamed through the selection hook (`BundleInstall.swift:21-22`).
- Squash merges: PR commit bodies are preserved in the squash messages, and the original branch commits remain reachable via `--all`, so individual commit messages were readable. Most carry only a title; bodies exist for a18fcbd, 7568ec7, 4a5eeb8, 0d54e01, 0f11238, 7107c6f, e00ce47.
- No commit after 9a99471 changed `Updater.swift`, `Update.swift`, `ApplicationsUpdater.swift`, `GitHubReleases.swift`, `PrivilegedInstall.swift` or `CodeSignature.swift`. The post-release hand-over fixes landed in `SystemRunningCopies`, `project.yml` and tests.
- 58ae670's "log the checks" is a development-log update, not app logging: it touches `GearView.swift` and plan files. No contradiction of the no-logging rule.

### Additional Leads
For the Plans investigator:
- `plans/022-in-app-updates/plan.md` and committed `.temp/architect/candidate-1.md`, `.temp/architect/grounding/{how,how-build-release,why,why-plans}.md`, `.temp/architect/grounding/probes/github-api.{sh,out}` all mention Sparkle. This is the most likely home of the rejection rationale. `development-logs.md` got review fixes in 4d1d892 (`.temp/slices/fixes.md`). `.temp/probes/swap-atomicity.swift` holds the RENAME_SWAP probe.
- `plans/021-background-agent-lifecycle/plan.md` (R1-R25, hand checks C1-C24, open questions): single instance, login, quit, move; and possibly why sudden termination was declared.
- `plans/038-post-update-force-quit/` (`plan.md`, `development-logs.md`, `repro.sh`, `old-copy.swift`): the diagnosis and pending logout steps. Critical for whether a non-parent launcher of the new copy avoids the loginwindow rule.
- `plans/035-post-update-crash/repro.sh`, `plans/036-settings-form-padding/`, `plans/034-launch-window-to-front/.temp/repro`, `plans/026-separate-debug-bundle-id/`.
- `plans/037-settings-window-design/`: touched the update card layout most recently (`preview-update-above-hint.png`).

For external or runtime follow-up:
- Whether Sparkle's installer launches the new copy in a way that LaunchServices treats as a child of the old app, and whether a UI-element app with no window is affected. Source control only documents the behaviour for `NSWorkspace.openApplication` from the old process.
- Whether a Sparkle relaunch reaches `Lifecycle` as `.byHand` (it would open the settings window per `Route`), and how it interacts with `stop` and `disableRelaunchOnLogin`.
