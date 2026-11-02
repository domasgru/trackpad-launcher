# Why: process lifecycle, the move into /Applications, and the no-network / source-scan rules

### The Question

Why do Trackpad Launcher's process lifecycle (`Lifecycle`, split from `Launcher`), its move into /Applications (file operations, the administrator script, code-signature classification, stopping other running copies, reopening the installed copy) and its no-network / source-scan rules have their current shape? Plan 022 (in-app updates) will change this code, so the answer also has to say which parts of that rationale still hold for an update and which do not.

### The Code in Question

- `LauncherKit/Sources/LauncherCore/Lifecycle.swift` (`Lifecycle`, its stages, `shouldEnd`, the move order at about lines 254-276), `Launcher.swift`, and the `RunningCopies` / `LoginItem` / `Installer` ports in `Ports.swift:148-185`.
- The move adapters in `LauncherKit/Sources/LauncherPlatform/`: `ApplicationsInstaller`, `BundleInstall`, `PrivilegedInstall`, `CodeSignature`, `ThisCopy`, `QuitSignals`, `SystemRunningCopies` and `DiskImages`. The dialog is in `LauncherUI/MoveDialogPresenter.swift` and the composition root is `TrackpadLauncher/TrackpadLauncherApp.swift`.
- The rules: `docs/architecture.md` "Shape" and "Privacy and permissions" (line 27), and `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (banned list at about lines 22-35, confined list at about lines 105-145).
- Shipped in 1cf9c4b (PR #1, plan 001) and c9125b6 (PR #28, plan 021). The pre-squash commits of #28 (a87d363, acc137d, 6e06660, 1d53d4d, f7ebaf4, 84a12f8, 4873ecd, and others) are still reachable.

---

### What We Found

#### 1. The no-network rule is a product promise. Updates were excluded only because of it.

- **[Direct]** The rule starts with the product owner. Source: `docs/product-overview.md:8`, first committed in fe0e0d7. It says: "Trackpad launcher should be secure and privat - it should do 0 network calls, no logging." A pickaxe for `0 network calls` finds only fe0e0d7, so the wording has never changed.
- **[Direct]** Plan 001 explains the promise in terms of user trust and cost, not a technical limit. Source: `plans/001-trackpad-launcher-app/plan.md:9`: "One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled." The same plan's R21 (line 409) says: "MUST make no network connection of any kind." R21 also has a manual network-monitor scenario (line 1517: `nettop` / Little Snitch shows zero connections).
- **[Direct]** Plan 001 excluded automatic updates, and the only reason it gives is the network rule. Source: `plans/001-trackpad-launcher-app/plan.md:448` (Non-goals): "**Automatic updates.** Update checks are network calls; the app makes none." (Spot-checked.)
- **[Direct]** Plan 021 deferred updating rather than rejecting it on its merits. Source: `plans/021-background-agent-lifecycle/plan.md:350`: "**Updating itself.** Checking for updates needs a network call, and the overview promises none. Changing that is its own product decision and a later feature." (Spot-checked.)
- **[Direct]** The architecture doc turns the promise into a rule that a scan enforces. Source: `docs/architecture.md:27` (from ccd4654, shipped in 1cf9c4b): "No network code of any kind ... A source-scan test in `LauncherCoreTests` fails the build on any banned API; add to its list rather than adding prose." The network rows in `SourcePolicyTests.swift:22-26` (`URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`) date from 4552ceb / 1cf9c4b. Outside `plans/`, `URLSession` has never appeared in Swift sources except in this ban.

#### 2. The source scan is how rules are enforced, and there is an established way to relax one

- **[Direct]** The project enforces its rules through structure, not prose. Source: plan 001 decision 9 (`plan.md:556`): "*Rules are enforced by structure.* ... `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit." The scan's own doc comment says the same (`SourcePolicyTests.swift:4-5`): "APIs the product promises never to use. / To forbid something new, add it to `banned`; do not write prose."
- **[Direct]** The project has retired a privacy rule before. It did so explicitly, by moving the tokens from banned to confined in one owning file and pinning the remaining bans. Plan 002 did this for plan 001's R20 "No permissions" (`plans/002-gesture-click-blocking/plan.md:17`, decision 8 at line 382). The dev log adds: "002 revokes R20 only → timers and polling stay banned" (`plans/002-gesture-click-blocking/development-logs.md:20`). Plan 006 decision 12 (`plan.md:650`) repeats the pattern: "The gate moves the token; it does not weaken it."
- **[Direct]** The scan reads comments. Source: `plans/012-window-switcher-gesture/development-logs.md:30`, and plan 021's dev log line 29: "three Core doc comments spelled confined tokens ... which the source scan reads → reworded."
- **[Direct]** Plan 021 widened the "no files written" rule on purpose, only for the move. Source: plan 021 grounding F37 (`.temp/architect/grounding/index.md`) said the move "contradicts the prose, which must be amended on purpose." The resulting wording is in `docs/architecture.md:27`: "...and the app's own bundle copied into /Applications when the user chooses *Move to Applications*; the unprivileged file operations of that move are confined to one file, and the administrator's to the one script that runs them, in one more file."
- **[Direct]** The rule went from one file to two because review found the administrator script broke the "one file" wording. Sources: `plans/021-background-agent-lifecycle/development-logs.md:50` and review-fix commit 4873ecd, which added the `/bin/mv` and `/bin/rm` confinement to `PrivilegedInstall.swift` (`SourcePolicyTests.swift`, about lines 114-115). The fix brief (`.temp/slices/fixes.md` item 3) says the separate script file was deliberate, "so the doc is what's wrong."

#### 3. Why `Lifecycle` is a second model, separate from `Launcher`

- **[Direct]** `Lifecycle` builds `Launcher` lazily because a process that only asks to move, or that is waiting for other copies to stop, must not start sensing or scanning. Source: plan 021 decision 1 (`plan.md:469`): "A copy that only asks to move never builds the sensing adapters, the catalog scan or the window's icon pass; a resident copy can still show the dialog while its gestures run." The Design Problem (line 369) says: "The gesture adapters start sensing in their `init`s and `Launcher.init` scans the disk (F11)."
- **[Direct]** Two alternatives were rejected by name. Source: plan 021 `plan.md:1071-1072`:
  - "Decide in the AppKit delegate with pure helpers": rejected because the sequencing "would live in the untested app target."
  - "Fold the lifecycle into `Launcher`": rejected because "`Launcher` exists only with its sensing adapters and its disk scan."
  - Candidate-2 had argued for one model (candidate-2.md, Alternatives), and the synthesis overruled it. Dev log line 21 records the "red-flag screen".
- **[Supported]** Tests encode the "nothing gesture-related yet" property:
  - `ReplacingOtherCopiesTests.openingByHandStopsAnEarlierCopyAndStartsOnlyOnceItHasExited` asserts `residentsBuilt == 0` until the other copy exits.
  - `MoveToApplicationsTests.aCopyInDownloadsOpenedByHandOnlyAsksAndQuitLeavesTheMacAsItWas` asserts `launcher == nil`, no permission asks and an unchanged defaults suite.
  - The `acc137d` commit message says: "Lifecycle decides what a start, a reopen and a quit do."
- **[Direct]** Ports exist where an adapter delivers asynchronously, so the model's tests stay synchronous. This rule came from plan 003, not from the lifecycle work. Sources: `plans/003-dropdown-recents-performance/plan.md:197` ("an adapter that delivers asynchronously sits behind a port"), and `docs/architecture.md` Shape. Plan 021's S5 brief (line 236) applies it: "`Installer` delivers asynchronously → a port; `BundleInstall` is tested directly over temp dirs." Plan 021's dev log line 22 says `Installer`'s calls were kept separate "because `Lifecycle` must hand over the login item between the install and removing the original, and tests pin that order."

#### 4. Only one copy runs gestures. Other copies are stopped, not asked, and their exit arrives as a push.

- **[Direct]** The problem this solves is that two copies both react to gestures. Sources:
  - `docs/performance.md` (36c3803) used to tell developers to "Quit every other copy ... because two copies both react to gestures"; 6e06660 replaced that with automatic stopping.
  - Plan 021's Specify dev log line 5: "Dragging a new build over a running one, or upgrading from the menu bar version, left two builds fighting → new R3."
  - R2 (`plan.md:33`): "At most one Trackpad Launcher MUST recognise gestures at any moment."
- **[Direct]** Opening a bundle that was replaced at the same path starts a second process. The old process keeps running. Source: plan 021 grounding F6 (probed, `index.md:35`): "Replacing the bundle **at the same path** with a different build ... while the old one runs, then opening that path, **starts a new process from the new build**; the old one keeps running." The Design Problem (`plan.md:370`) draws the conclusion: "every second process is a newcomer to resolve, never a reopen." The same-version check (`.temp/architect/checks/same-version-replace`) showed this holds even with an identical `CFBundleVersion`, so plan 021 dropped release-time version stamping (`plan.md:1045`).
- **[Direct]** Copies are stopped with `forceTerminate`, not asked politely, so no protocol binds future versions together. Source: plan 021 decision 3 (`plan.md:482`): "A copy cannot refuse, hang, show its own dialog or be mistaken for the Dock's Quit, and no handshake binds versions together, the menu bar version included. A copy has nothing to flush: every setting is saved when it changes (F21)." The rejected alternative (`plan.md:1073`) reads: "Hand over with a quit Apple event ... exposes a sender-pid protocol to every future version ... leaves the new copy waiting forever on a refusing or hung copy, with no timeout allowed." The probe behind this is F16: a peer's `terminate()` looks exactly like the Dock's Quit.
- **[Direct]** Waiting for a copy to exit has no deadline. This was accepted knowingly because timers are banned. Source: `plan.md:1062`: "We accept that a copy which survives `forceTerminate()` ... leaves the opened copy waiting with nothing shown or recognised until it exits, in exchange for no deadline (timers are banned)." The port contract is at `Ports.swift:150-160`: "never a wait or a poll."
- **[Direct]** Review fix 4873ecd added a filter that drops already-terminated copies before the KVO wait. Source: `.temp/slices/fixes.md` item 5: "`SystemRunningCopies.stop` reports already-exited copies a turn late." Source control had no message for this change, so the plan's fix brief is what explains it.

#### 5. "Only Quit Trackpad Launcher stops the app"

- **[Direct]** The behaviour is stated in the PR #28 body: "Closing the window, ⌘Q and the Dock's Quit only close the window. The red *Quit Trackpad Launcher* button ... is what stops the app." It is also in plan 021 R8 / R11 (`plan.md:110-118, 181-182`) and the domain model's "Quit Trackpad Launcher" entry.
- **[Direct]** The mechanism exists so that a logout is never held up. Sources: plan 021 decision 7 (`plan.md:495`), the tradeoff at `plan.md:1063`, and the comment at `Lifecycle.swift:206-207`: "With it closed, a quit is the system's or a script's: end, never hold up a logout." During a move, `shouldEnd` accepts only a system quit (`case .moving: return request == .system`). The test `aSystemQuitEndsWhileTheDialogAsksTheInstallIsHeldAndTheFailureShows` pins this.
- **[Direct]** Disabling sudden termination during the install was tried, then dropped. Source: plan 021 Synthesis (`plan.md:1051`): "a logout's quit still reaches `shouldEnd`, which ends a moving process (R8), so it protected nothing. The move's order carries the guarantee instead." This is also in dev log line 30.
- **[Direct]** Before #28, ⌘Q did quit the app. PR #25 put "*Quit Trackpad Launcher* (⌘Q)" in the menu bar icon's menu. #28 reversed this on purpose.

#### 6. The move: its order and crash convergence

- **[Direct]** The move's steps are ordered so that a crash or kill at any point converges. Source: plan 021 decision 9 (`plan.md:499-507`), summarised in the comment at `Lifecycle.swift:254-256` (spot-checked): "the swap inside `install` is the first change anywhere, the login item is handed over before the original can go, and every other copy stops before the installed one opens, so that open always starts a fresh process." The order is pinned by `MoveToApplicationsTests.swift:149` (`["install", "unregister", "removeOriginal", "stop", "openInstalledCopy"]`) and by `aKillAnywhereInAFirstMoveConverges` / `aKillAnywhereInAMoveOverAnOlderCopyConverges` (lines 279-283). Review declined to loosen these order assertions: "the plan pins the move's order on purpose" (dev log line 53).
- **[Direct]** Other copies are stopped after the install, not before it, because a cancelled admin prompt must leave everything as it was. Source: plan 021 dev log line 24 and Synthesis line 1033. Candidate-2 "stopped the running copy before the admin prompt (R21)", and that was rejected.
- **[Direct]** The mover ends instead of waiting to be stopped. Source: `plan.md:1050`, which rejected the mover idling until the installed copy stops it: "it never ends if that copy fails to start." The disk image to eject is passed explicitly as `--eject-disk-image` and is not derived from the peers (`plan.md:1052`).
- **[Direct]** The login item is handed over through `StartAtLogin`, which lives under its own defaults key, so a move never creates or spends a first run. Sources: `plan.md:465` and the tradeoff at line 1065. Plan 021 grounding `why.md` Risk 4 flagged "spend the first launch ... in the copy that is about to be moved". The comment at `Lifecycle.swift:91-92` says: "Remembering comes first, so a crash before the unregister leaves it on and remembered."

#### 7. Whole-or-nothing replacement and the administrator script

- **[Direct]** The installer promises "Nothing there changes unless the outcome is `.installed`, and never a mix of two copies. Unprivileged, the replace is one atomic step." Source: `Ports.swift` `Installer.install` doc (spot-checked) and `plan.md:631-638`. `BundleInstall.swift` stages a copy in a temporary folder on the destination volume, then uses `replaceItemAt` / `moveItem`, and states "Throws with `destination` untouched" (lines 25-26).
- **[Direct]** The admin path is two renames, and the gap between them is documented. Source: the `PrivilegedInstall.swift:17-21` script contract (spot-checked): "So a status matches what /Applications holds. Only a kill between the two moves leaves /Applications without the app and the old copy in the staging folder, never inside /Applications." Test-planner passes shaped this:
  - Dev log line 35: the aside copy "could stay in /Applications → the aside goes into the staging folder".
  - Dev log line 39: "failure paths could report `.failed` with /Applications changed → the script moves the aside copy back".
- **[Direct]** Paths are passed as separate arguments and never interpolated, to prevent shell injection. Sources: the S6 brief (line 77) and test `theRealScriptSwapsTheCopyInThroughPathsHoldingQuotesSpacesAndCommandSubstitution`, which uses a path containing `$(touch pwned)` and asserts no `pwned` file appears.
- **[Direct]** The app uses `AuthorizationExecuteWithPrivileges` through `dlsym`, not the public API, because the public API needs a restricted entitlement. Sources:
  - Grounding F31 (sourced): `NSWorkspace.requestAuthorization` "needs the Privileged File Operation entitlement, which is requested from Apple".
  - Alternatives at `plan.md:1076`.
  - Tradeoff at `plan.md:1064` (spot-checked): "in exchange for a Finder-like administrator prompt with no entitlement and no helper."
  - The base constraint from plan 001 (line 589): "hardened runtime, no sandbox, no entitlements".
- **[Direct]** Cancelling the admin prompt stops the app with nothing changed. Source: plan 021 R21 (`plan.md:310`): "Cancelling MUST stop Trackpad Launcher with nothing moved." The mapping is `errAuthorizationCanceled` → `.cancelled` → `end()` (`Lifecycle.swift:260`, spot-checked). Before f7ebaf4 there was no admin path: an unwritable /Applications was simply `.failed`.
- **[Direct]** The move replaces whatever version is installed. This is deliberate. Source: R20 (`plan.md:302`): "whatever their versions, because the user chose that copy." The Non-goal at line 359 is "Refusing to downgrade."
- **[Direct]** The installer searches /Applications at any depth because review found that a copy nested in a subfolder (for example Utilities) was not replaced. Source: dev log line 48 and `fixes.md` item 1 (commit 4873ecd). The search prefers a direct child.

#### 8. Release vs development, by code signature

- **[Direct]** Builds are classified by Developer ID signature, never by `#if DEBUG`, so the perf build counts as development and never moves itself out of its build folder. Sources: plan 021 decision 2 (`plan.md:480`), the Alternative at line 1077 ("`#if DEBUG` ... calls the perf build a release, which would then move itself out of its build folder (F8)"), and the comment at `Placement.swift:5`. The requirement string was probed against real Developer ID apps (grounding F7).
- **[Direct]** `--as-release-build` exists only so the move and login rules can be checked by hand before a Developer ID certificate exists. A release build ignores it. Sources: `plan.md:1061` and `CodeSignature.swift:11-13`.
- **[Direct]** `CodeSignature.build(of:)` deliberately skips resource validation. Sources: the comment at `CodeSignature.swift:24-25` ("a bundle edited after signing is still signed with a Developer ID") and dev log line 45 ("as `codesign -dvv` reports it"). Grep confirms it has no production caller: only `buildOfThisProcess(arguments:)` is used, at `TrackpadLauncherApp.swift:33`. The classification arrived in 84a12f8 together with the login-item rules.

#### 9. Translocation and quarantine

- **[Direct]** The move clears quarantine so the installed copy is never translocated. A translocated copy, even one inside /Applications, asks to move. Sources: plan 021 decision 2 and the tradeoff at `plan.md:1066`, and the `BundleInstall.swift:8-9` comment ("a copy that carries none is never translocated"). The problem statement (`plan.md:7`) gives the motivation: "macOS runs a quarantined download from a hidden, randomised copy", and the login item "points at a file the user later deletes".
- **[Direct]** Quarantine is cleared with `removexattr` on each item instead of `quarantinePropertiesKey`, so symlinks and dangling links are handled. Source: dev log line 46. `isTranslocated` is read from macOS and never inferred by comparing URLs, because a trailing slash made the installed copy ask to move (dev log line 36).

---

### What We Can Reasonably Infer

- **[Inferred]** The protective shape of the move (convergence after a kill, whole-or-nothing replacement, cancel leaving nothing changed, never interpolating paths) appears to come from design review and test-planner passes, not from field incidents. Reasoning: plan 021's dev log records each guard as a test-planner or review finding (lines 24, 30, 35, 36, 39, 46, 48, 50). Searches of git history for `incident|revert|crash|relaunch|translocat|quarantin` and of plans for incidents found no bug report. PR #28's Merge Danger says the release path "has never run end to end". So these guards were reasoned out ahead of time, not learned from failures.
- **[Inferred]** Several properties were justified by the conditions of a move, not by general principle, and may need fresh justification for an update:
  - "Replace whatever the version" rests on "the user chose that copy" (R20).
  - "Cancel ends the process" rests on the canceller being a copy outside /Applications that should not keep running from there (R21, R18).
  - Neither reason obviously carries over to an update started from the running, installed copy.
- **[Inferred]** The existing newcomer routing seems likely to make "stop the old process, open the new one" work almost for free. Reasoning:
  - F6 (probed) shows that opening a bundle replaced at the same path starts a new process.
  - The route table sends (by hand, installed) to "runWithWindow, after stopping every other copy" (`plan.md:471-478`).
  - So a new copy opened as by hand would `forceTerminate` the old process and open its window.
  - This has not been tested for the case where the process doing the replacing is the running /Applications copy itself. No test or commit covers a self-replace (`removeOriginal` skips "the installed copy itself", `ApplicationsInstallerTests.theInstalledCopyItselfStays`). F6 was probed with an external remove-and-copy, not with the running process replacing its own bundle.
- **[Inferred]** `CodeSignature.build(of:)` looks unfit to verify a downloaded update without change. Reasoning:
  - By its own doc (`CodeSignature.swift:5-6`), its requirement accepts any Developer ID Application leaf, not this developer's team.
  - It skips resource validation on purpose (§8).
  - It was written to tell release builds from development builds, not to authenticate downloads (§8, commit 84a12f8).
  - Nothing in the record discusses using it for authenticity.
- **[Inferred]** Plan 022's trigger (check each time the settings window opens) fits an existing precedent. Reasoning: plan 003 R4/R6 made recents refresh "each time the launcher window opens" with "no periodic work" (`plans/003-dropdown-recents-performance/plan.md:90, 116`). Plan 021 kept a per-opening counter in `openedByHand()` (`plan.md:465, 819`). Plan 002 (`plan.md:1148`) shows the counter-case: refreshing only when the window opens was judged insufficient when a requirement bound freshness while the window is closed. Plan 022's R1 explicitly does not require that.

---

### Competing Hypotheses

**Why ⌘Q and the Dock's Quit only close the window**

- **Hypothesis A:** It is a product choice to keep a background utility running when users reach for the usual quit.
  - Evidence for: the PR #28 body and plan 021 R8 state the behaviour; the product overview says the app "should continously run in the background".
  - Evidence against or missing: no plan or commit states this reason. Plan 021's dev log line 7 only resolves a label clash ("Close Settings").
- **Hypothesis B:** It is a consequence of the logout-safety mechanism.
  - Evidence for: decision 7 and tradeoff line 1063 explain the mechanism entirely in terms of never holding up a logout.
  - Evidence against: the mechanism could have let ⌘Q quit and still not held up a logout. So the mechanism explains how, not why.
- The record does not decide between these. This matters for 022 only in that plan 022 rewrites the "only Quit stops it" sentence. The evidence suggests the sentence's core worry is that no ordinary user action stops gestures by accident, and an update stopping the old process to start a new one does not obviously conflict with that. This reading is inferred.

**What the source scan's "own files" and confinement rules protect**

- **Hypothesis A:** Privacy. Nothing the user does gets persisted (plan 001 R21).
- **Hypothesis B:** Auditability. Every risky API is named in one file, so a reviewer can find it (plan 017 line 1121: "so every reader of pointer events is named").
- Both are documented, for different tokens. A new download path touches both: it writes a file, and it is a new risky capability.

---

### What We Don't Know

- **Why updating, specifically, was not reconsidered earlier.** Both plans that mention updates (001 Non-goals line 448, 021 line 350) give only the network rule as the reason. We grepped all plans (excluding 022) for `network|phones home|update check|auto.?update|Sparkle|self-update|updating itself` and searched git history (`-S'URLSession'`, `--grep` for `update|network`). No plan or commit discusses an update design, an acceptable network API, a release feed, or what "secure" would require of a download.
- **Whether the "0 network calls" promise has any wording that permits exceptions.** `docs/product-overview.md:8` is absolute. Plan 021 calls changing it "its own product decision". Only the product owner can say how far the exception may go, for example whether a GitHub releases endpoint counts as "sends nothing about the user."
- **Whether a network request's own timeout counts as a banned "timer".** The plans investigator raised the reading that a request's timeout is a property of the request, not an app timer. No plan discusses it. Plan 021 accepted an unbounded wait rather than add any deadline (`plan.md:1062`).
- **Whether the Accessibility grant survives a bundle replaced in /Applications.** This is grounding F38 and Open question 6 (`plan.md:1086`), still open. R5 (`plan.md:72`) forbids asking again after the first run, so a lost grant cannot be re-requested under current requirements.
- **Whether Background Task Management keys the login item by path or by bundle identifier.** This is Open question 5 (`plan.md:1085`), still open. It decides whether an in-place replace keeps the login item and whether macOS shows "login item added" again.
- **Whether logout with the window open behaves as assumed.** This is Open question 4 (`plan.md:1084`): `kAEQuitReason`, the loginwindow sender, `willPowerOff` and sudden termination.
- **Whether any of the move ever ran end to end with a real release build.** Plan 021's dev log line 55 says hand checks C1-C24 were not run ("need a real Mac session, logins, a standard account or a Developer ID certificate"). PR #28's Merge Danger says the same. Grounding F36 says the admin-prompt path could not be exercised because the dev account is an admin.
- **What happens when the running copy replaces its own bundle and opens it.** F6 was probed with an external replace. No probe or test covers a self-replace, or whether `open` from the process being replaced reaches it as a reopen.
- **The product reason for ⌘Q interception** (see Competing Hypotheses). Not found in any plan, commit or PR.
- **Why `NSSupportsSuddenTermination: true` is set.** It was added in acc137d with no commit explanation. Plan 021 decision 7 gives it as one of three logout-safety layers (grounding F18), but it was then dropped as a guard for the install.
- **What the rejected alternatives in plan 021's saved sources say in detail.** Neither investigator read the LetsMove source, the `lsmultipleinstancesprohibited`, `suddentermination` and `requestauthorization` source files, or the `lifecycle-probe` / `same-version-replace` outputs in full. Only their summaries in `index.md` and `plan.md` were used. LetsMove's own relaunch flow (an `sh` script waiting for a pid, then a 5 s delayed detach; F33) is the closest prior art to an updater's relaunch, and plan 021 declined to copy its timing.
- **People who would know:** the product owner and author (domasgru) for the network exception and the ⌘Q rationale. PR #1 and PR #28 have no review comments or discussion (`gh api` returned 0 comments and 0 reviews), so no second person's reasoning is recorded.

### Contradictions in the record

- **A confined token is not used, and the real API is unconfined.** `SourcePolicyTests.swift:136-138` confines `quarantinePropertiesKey` to `BundleInstall.swift`, but no source uses it. The code clears quarantine with `removexattr(..., "com.apple.quarantine", XATTR_NOFOLLOW)` (`BundleInstall.swift:61`, spot-checked), and neither `removexattr` nor `com.apple.quarantine` is confined. The plan's confinement row (`plan.md:1028`) predates the dev-log change to `removexattr` (dev log line 46), and the scan was not updated.
- **"No files written other than ..." does not mention the staging folder.** The rule allows UserDefaults and the move. The move also creates a temporary staging folder through `FileManager.url(for: .itemReplacementDirectory, ...)` (`BundleInstall.swift:13`), which is neither banned nor confined.
- **Plan 001 R19 vs plan 021 R12.** R19 said "Quitting MUST NOT remove the login item"; R12 turns it off on Quit. This reversal is deliberate.
- **Candidate-2 vs synthesis on the two-model split.** Candidate-2 argued the split needs "a protocol between them that is as wide as the thing it splits". The synthesis rejected that, and review listed "the start-at-login split between `Lifecycle` and `Launcher`" as raised but not fixed (dev log line 53). Both views are on record.

---

### Sources Consulted

- **Source control history:**
  - `git log` of main and all branches, including the 10 pre-squash commits of #28 (a87d363 to 7db2e49).
  - Diffs of acc137d, 6e06660, 84a12f8, 1d53d4d, f7ebaf4, 4873ecd; `git show` of 1cf9c4b's `architecture.md` and `SourcePolicyTests.swift`, and fe0e0d7's `product-overview.md`.
  - Pickaxe for `0 network calls`, `URLSession`, `.write(to:`, `Task.sleep`, the "deliver asynchronously" and "Two models" wording, and "two copies both react".
  - Grep of messages for relaunch/crash/translocation/quarantine/administrator/sudden/network/update/incident/revert.
  - `git blame` on `Lifecycle.swift`.
  - PRs #1, #2, #25 and #28 via `gh`. #1 and #28 have 0 review or issue comments.
  - Read in full: every file named in the code anchor, plus `Placement.swift`, `SystemLoginItem.swift`, `SettingsShell.swift` and `Scripts/release.sh`. Test names and doc comments were read in the Lifecycle, move, copies, login, installer, privileged-install, code-signature, quit-signal and this-copy test suites.
  - No TODO/FIXME/HACK in the target files.
- **Plans:**
  - Read in full: `plans/021-background-agent-lifecycle/plan.md` and `development-logs.md`, its grounding `index.md` (F1-F46) and `why.md`, and `.temp/slices/fixes.md`.
  - Read in part: plan 001 (Problem, Solution, R17-R23, Non-goals, Shape decisions 1-9, Ports, SourcePolicyTests sketch, Alternatives, Testing), plan 002 (header, decisions, scan sketch, alternatives), plan 003 (R4, R6, the AppScanner "Why a port" section, Docs), plan 006 (decision 12), plan 012's and 017's dev logs and constraints, the 021 S1/S3-S7 slice briefs (S6 "Why this API" in full), and the 021 candidate-1/2 alternatives sections.
  - Greps as listed in What We Don't Know.
  - Not read: plan 021's `why-plans.md`, `why-source-control.md`, `how*.md`, the probe outputs and the saved `sources/` files. `research/` was not read.
- **Synthesizer spot-checks:**
  - `docs/product-overview.md:8` and `docs/architecture.md` Shape and Privacy.
  - Plan 001 line 448; plan 021 lines 350, 370, 482, 1062-1064, 1073 and 1084-1086; plan 021 dev log lines 50-55; grounding F6, F16, F31 and F38.
  - `Lifecycle.swift:250-262`, `Ports.swift:148-182`, `PrivilegedInstall.swift:1-30`, `CodeSignature.swift:20-28`, and the `SourcePolicyTests.swift` banned and confined rows.
  - The `quarantinePropertiesKey` / `removexattr` grep, the `build(of` callers grep, and `NSSupportsSuddenTermination` in `project.yml`.
  - `MoveToApplicationsTests.swift:149, 279, 283`, `ApplicationsInstallerTests.swift:143`, and the PR #28 Merge Danger text.
  - All matched the investigators' quotes.

### Confidence Summary

The rationale for each major shape is well documented, mostly in plan 021's decisions, tradeoffs and dev log, with commit messages and code comments that agree:

- the no-network rule as a product trust promise, with updates excluded only because of it
- the scan as the enforcement mechanism, with an established banned-to-confined precedent
- `Lifecycle` split out so a process that only asks never senses
- `forceTerminate` plus a push wait instead of a handshake
- the move's order chosen for crash convergence
- whole-or-nothing replacement and the documented admin gap
- classification by signature instead of `#if DEBUG`

Two things are weaker. First, how much of this protective design was ever validated on a real release build: the record says none of the end-to-end checks ran. Second, how the move-specific reasons (user choice of version, cancel-ends, the mover being outside /Applications) transfer to an update. Those transfers are inferred here, not documented. The product reason for intercepting ⌘Q, and whether a request timeout counts as a timer, are not recorded anywhere.

---

## Constraint set for plan 022 (in-app updates)

### Preserve

1. **At most one copy runs gestures (R2), and every second process is a newcomer resolved by `Lifecycle`** (plan 021 decision 1, F6). The updated copy should arrive through the existing "opened by hand, installed" route, which stops every other copy and waits for their exit before sensing. Do not add a separate handover path.
2. **Stop, don't ask.** Use `RunningCopies.stop` (`forceTerminate` plus a KVO push). Add no quit handshake between versions. The plan rejected a handshake because it "binds versions together", and an updater is exactly the case where an old version hands over to a new one (`plan.md:482, 1073`).
3. **The source scan, and the precedent for relaxing a rule.** The network exception should follow the plan 002 / 006 pattern:
   - Move the needed network token(s) from `banned` to `Confined` in exactly one file.
   - Keep the other network tokens banned.
   - Pin the remaining bans with a self-check.
   - Amend `docs/architecture.md:27` and `product-overview.md:8` explicitly, not quietly (F37's "amended on purpose").
   - Remember the scan reads comments, so do not spell confined tokens in Core doc comments.
4. **Confine the new file operations.** Unprivileged bundle operations stay in `BundleInstall.swift`. Privileged `mv`/`rm` stays in `PrivilegedInstall.swift`'s one script, with arguments passed as `"$n"` and never interpolated. If the download needs a file write, confine it to one file and add it to the doc's list of allowed writes.
5. **Whole-or-nothing replacement.** Stage on the destination volume, swap in as the first change anywhere, and never leave a mix of two copies. Keep the admin path's documented gap, with the aside copy kept in the staging folder and never inside /Applications.
6. **Crash convergence as a tested property.** Plan 021 pins the move's effect order and its "kill anywhere converges" tests on purpose (dev log line 53). An update flow is a new sequence of effects and should get its own order and kill-anywhere tests in the same style.
7. **No timers, polling or sleeps; every wait is a push.** This includes waiting for the old process to exit and for the download to complete. An app-level retry or deadline would break the rule. Plan 021 chose an unbounded wait over a timer.
8. **Release vs development by Developer ID signature, never `#if DEBUG`.** This keeps the perf build and Xcode builds from checking or self-updating (plan 022 R2 already depends on it). `--as-release-build` must stay ignored by a real release build.
9. **The login-item handover and first-run invariants.** `StartAtLogin`'s separate key means an update never creates or spends a first run, and an older build ignores unknown keys. Settings must stay readable across versions in both directions.
10. **Quarantine-free installation.** The installed bundle must carry no quarantine on any item, so it is never translocated (`removexattr` per item, without following symlinks).
11. **The model stays synchronous.** The network check and the download deliver asynchronously, so they belong behind ports with real and in-memory adapters (plan 003's rule). Framework types such as `URL` responses must not cross a port.
12. **Logout is never held up.** Whatever new stage the update adds should accept `.system` quits, as `.moving` does.

### Change (legitimately, and how the original rationale bears on it)

1. **The no-network rule gains one named exception.** Updates were excluded only because of this rule (plan 001 line 448; plan 021 line 350 calls it "its own product decision"). So plan 022 is the deferred decision, not a reversal of a technical judgement. The original reason ("phones home ... gets uninstalled") is about trust, and it argues for keeping the exception as narrow as plan 022 R1/R2 already state: window-open only, release build in /Applications only, nothing about the user sent.
2. **"Only Quit Trackpad Launcher stops it" gains the update as a second stopper.** The record gives logout safety and keeping gestures running as the mechanism's purpose. A user-confirmed *Update now* that immediately starts the replacement does not appear to conflict with either. This is inferred.
3. **Admin-prompt cancel semantics.** In the move, cancel ends the process because the canceller is a copy outside /Applications (R21). In an update, the canceller is the running, installed copy. Ending it on cancel would stop gestures for no reason the record supports. The update's cancel should most likely leave the old copy running with nothing changed. Treat this as a deliberate new rule, not as inherited behaviour.
4. **The version policy.** The move replaces "whatever the version" because the user chose that copy (R20). An update replaces only with a newer version chosen by a feed, so it needs a version comparison the move deliberately lacks. The "Refusing to downgrade" non-goal (`plan.md:359`) does not apply to updates.
5. **"Files written" grows.** A downloaded artefact (and possibly an unpacked disk image) is a new write. Plan 021's precedent is to name it in `architecture.md:27` and confine its APIs. While doing that, fix the `quarantinePropertiesKey` / `removexattr` and staging-folder contradictions listed above.
6. **Authenticity is a new requirement.** Nothing in the record verifies that a bundle comes from this developer. The existing `build(of:)` accepts any Developer ID and skips resources by design. A genuineness check needs its own requirement (team-pinned, with resources validated) and should not reuse the classification helper as it is. Keep `SecStaticCode`/`SecRequirement` confined to `CodeSignature.swift`.

### Avoid

1. **Relaunching through a helper `sh` script with sleeps or pid polling** (LetsMove's pattern, F33). Plan 021 declined it, and the timer and polling bans forbid it.
2. **Stopping the running copy before the swap or before the admin prompt.** Candidate-2 did this in 021 and it was rejected, because a cancel or failure must leave everything as it was.
3. **A grandfathered network path that the scan cannot see,** such as a call through `NSWorkspace`, `curl` via `Process`, or `Data(contentsOf:)` on an https URL that is not in the banned list. This would satisfy the letter of the scan but break the rule "enforced by structure". The new network API should be confined explicitly, and the obvious bypasses should be banned.
4. **`#if DEBUG` as the gate for update behaviour** (rejected in `plan.md:1077`).
5. **Folding update state into `Launcher`'s concerns in a way that brings back what the split prevents.** For example, a copy that only checks or downloads should not build sensing, and the network check must not run at a login start (plan 022 R2).
6. **Treating the existing move tests as proof that a self-replace works.** None covers the running /Applications copy replacing itself.

### Risk

1. **The Accessibility grant after a replace (F38, Open question 6) is unresolved.** R5 forbids re-asking. An update that loses the grant would silently degrade click blocking and window switching for every updated user, with no way to recover in the app under current requirements.
2. **Login-item identity after a replace (Open question 5) is unresolved.** An update could trigger a "login item added" notification on every release, or lose the item.
3. **Self-replace and reopen is unprobed.** F6 covers an external replace. It is not established that `open` of the new bundle, issued by the process being replaced, starts a new process rather than reaching itself as a reopen. The mover avoids this case by stopping other copies first (`Lifecycle.swift:254-256`), and an updater cannot stop itself first.
4. **The admin path and the release signature path have never run for real** (plan 021 dev log line 55; PR #28 Merge Danger; F36). An updater built on them adds a network and download layer on top of unverified ground. The first real Developer ID release is also the first real test of the move.
5. **Unbounded waits.** With no timers, a stuck download or a copy that survives `forceTerminate` leaves the user waiting indefinitely. Plan 021 accepted this for the exit wait. For a network request the cost is higher and more common, so plan 022 needs a documented position on request timeouts relative to the timer ban.
6. **Logout during an update.** It must converge the way the move does. Plan 021 found that disabling sudden termination "protected nothing" and relied on effect order instead, and the logout signals themselves (Open question 4) remain unverified.
7. **Settings compatibility across versions.** Updates make version skew routine. The current tolerance ("`Settings` ignores unknown keys", `plan.md:465`) has only been reasoned about for the menu-bar-version upgrade.
