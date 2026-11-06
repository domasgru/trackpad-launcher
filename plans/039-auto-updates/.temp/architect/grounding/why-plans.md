# Why (Plans investigator): the shape of Trackpad Launcher's updater

## Source

`plans/` only: `plan.md`, `development-logs.md`, and tracked `.temp/` material (architect candidates, grounding, probes and their outputs, slice briefs, fix briefs). `docs/` was read only to confirm what plans said would land there. Git history, PRs and `research/` were not used.

Paths are relative to the worktree root. `P022` = `plans/022-in-app-updates/plan.md`, `L022` = its `development-logs.md`, `G022` = `plans/022-in-app-updates/.temp/architect/grounding/`. Same pattern for 021 (`P021`, `L021`, `G021`), 035, 038, 026, 039. `:N` is a line number.

Labels: **[Req]** requirement, **[Dec]** implementation decision, **[Log]** development log entry, **[Probe]** measured output, **[Note]** other plan text.

---

## What I Searched

Read in full:
- `plans/039-auto-updates/plan.md`, `development-logs.md`
- P022 (all 1389 lines), L022
- `G022/index.md`, `G022/why.md`, `.temp/architect/task.md`, `.temp/architect/rubric.md`, `.temp/slices/fixes.md`
- P035, L035, `plans/035-post-update-crash/repro.sh`
- P038, L038, `plans/038-post-update-force-quit/repro.sh`, `old-copy.swift`, `.temp/slices/fixes.md`
- P026, L026
- L021, `G021/index.md` (facts F1-F46)

Every 022 and 021 probe output, read in full:
- 022: `probes/relaunch/relaunch.out`, `self-relaunch.out`, `replace-atomicity.out`, `jxa-swap.out`, `codesign-requirement.out`, `designated-requirement.out`, `urlsession-probe.out`, `github-api.out`, `archive/archive.out`, `checks/checks.out`, `checks/nonetwork-notarized.out`, `checks/after-swap/after-swap.out`
- 021: `lifecycle-probe/output.txt`, `sudden-output.txt`, `signature-probe/output.txt`, `checks/same-version-replace/output.txt`
- Probe programs read: `relaunch/SelfSwapApp.swift`, `self-relaunch.sh`, `after-swap.sh`, `lifecycle-probe/sudden.sh`, parts of `urlsession-probe.swift`

Read by section:
- P021: Non-goals, Design Problem, decisions 1-9, Rejected, Tradeoffs, Alternatives, Open questions, plus grep hits
- Candidates' Alternatives sections: `022/.temp/architect/candidate-1.md`, `candidate-2.md`
- Plan 001 grep hits (:9, :15, :409, :419-420, :448, :556, :1609)
- Plan 002 dev log :19-20
- Plan 003 :90, :116, :155-158
- Plan 017 :238, :456-462, :1147-1151, :1174-1179
- Plan 032 :325, :333, :387
- Plan 022 slice briefs S1, S3, S5 (grep)
- `G022/how-build-release.md` and `G022/how-lifecycle.md` (grep)

Queries (over `plans/`, `docs/`):
- `sparkle` (case-insensitive, all files)
- `SPU` in P022 and the 039 plan (0 hits in both)
- `after (an|the|every) (in-app )?update|first real|first update|real update|login item.*(surviv|kept|lost|carr)|(grant|permission)s?.*(surviv|carr|lost|kept)|surviv.*(grant|login|permission)|Screen Recording.*(update|lost|reset)|C6\b`, excluding 022 and 039
- `\b1\.0\.[0-9]+\b` in plans other than 022, 035, 038, 039
- `sudden|loginwindow`, `Core Animation.*clock|LaunchClock|no timer|asyncAfter|Task\.sleep|Timer\b`, `-- --deep`, `Trackpad Launcher\.app`

`.temp` is tracked: `git ls-files` lists the 022 relaunch probes.

---

## Direct Evidence Found

### 1. Sparkle: considered and rejected in one bullet, with no probe

- **Quote [Dec, Alternatives considered]:** "**Sparkle.** It brings its own network code outside the scan, dialogs (a non-goal), an appcast to host and XPC installers. It is far wider than the one narrow exception the product owner granted." (P022:1104, copied verbatim from `candidate-1.md:863`)
  - **Relevance:** the only recorded rationale. It has four technical reasons and one scope reason.
- **What the record shows about how much weight it had:**
  - Candidate 1 wrote the bullet and the synthesis kept it. `candidate-2.md` does not mention Sparkle. `task.md`, `rubric.md`, `index.md` and L022 do not mention it as an option.
  - No probe tested Sparkle. The `sparkle-project/Sparkle` hits in `G022/probes/github-api.sh` and `.out` use that repo only as "a public repo with releases", because this repo had none then.
  - `how.md:326` and `how-build-release.md:122,154` only say no Sparkle or appcast existed in the repo.
  - No plan names `SPUUpdater`, `SPUStandardUserDriver`, a custom user driver, or any Sparkle setting. So the "dialogs" reason was never tested against Sparkle's configurability.
- **The human's reported words (the "exception" the bullet refers to) [Note]:** "I am against network requests, but the app updates would be exception. I want trackpad launcher app to be able to receive an update. When update is available I would like to show the CTA as in this design" ... "go ahead". "The network exception must stay as narrow as R1-R3 state." (`022/.temp/architect/task.md:15`; the last sentence is the task author's, not a quote of the human.)
- **039's standing [Log]:** "Not taken: moving the Sparkle choice out of the Solution, because the user chose it and planning needs it." (`plans/039-auto-updates/development-logs.md:12`)
- **Mapping of 022's reasons to 039 requirements (my juxtaposition, not stated in any plan):**

| 022 reason | Rule it rested on | 039 text that bears on it |
|---|---|---|
| "own network code outside the scan" | Scan confinement: `URLSession` in `GitHubReleases.swift`, `http` confined (P022:973-978) | 039 Solution: Sparkle "replaces Trackpad Launcher's own download and install code"; R3 still binds every request's headers |
| "dialogs (a non-goal)" | P022:213 "Notifications, Dock badges or dialogs about updates" | R9, R15, Non-goals: no interface at all, stricter than 022 |
| "an appcast to host" | R3 "one request for the list", GitHub API only | 039:13 "a public update list on GitHub" |
| "XPC installers" | Not stated. Nearby: child-process bans (P022:986), "no entitlements" (`docs/architecture.md:35`) | 039:R12 no password, no prompt |
| "far wider than the one narrow exception" | Product scope | 039:13 widens the exception by the human's own choice |

### 2. No update of any kind before 022: the promise that shaped everything

- **[Note]** "A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled." (`plans/001-trackpad-launcher-app/plan.md:9`)
- **[Req]** "Trackpad Launcher MUST make no network connection of any kind." (001:409)
- **[Req, Non-goal]** "**Automatic updates.** Update checks are network calls; the app makes none." (001:448)
- **[Req, Non-goal]** "**Updating itself.** Checking for updates needs a network call, and the overview promises none. Changing that is its own product decision and a later feature." (P021:350)
- **[Req]** P022:5,7 give the forcing function: "Most users will never do this. They stay on old versions with bugs that are already fixed." and "The app makes no network calls today, by rule. So it cannot learn that a newer version exists."
- **Relevance:** the reason updates were absent was the promise, not a technical judgement. 039's Problem statement repeats 022's forcing function.

### 3. The check runs only when the settings window opens

- **[Req, Solution]** "The update check is the one exception to the no-network rule. It runs only when the settings window opens, in a copy installed in /Applications. It never runs at a login start, while the window is closed, or in a development build." (P022:13)
- **[Req, Non-goal]** "**Checking in the background or at login.** The card shows only in the settings window, so a check at any other time would make network requests for nothing a user can see." (P022:212)
- **[Req, Non-goal]** "**A switch to turn update checks off.** The check runs only when the user opens the settings window, and reads only the public release list." (P022:214)
- **[Req, Non-goal]** "**Installing updates without the user pressing *Update now*.** The user decides when the app replaces itself." (P022:217)
- **[Dec]** "`Launcher` only reports its own two window transitions. ... The edge lives where the window state lives (single source of truth). The shell is no place for it, because Observation coalesces a `.closed` then `.open` within one turn." (P022:363)
- **[Dec]** "A login start never opens the window, so it never checks." (P022:381)
- **Relevance:** the window trigger's stated reason is tied to the card's existence. With 039 removing the card (R15), the reason given at P022:212 no longer has its premise. That last step is my inference, though 039:R1 ("The check MUST NOT depend on the settings window") states the outcome.

### 4. The fixed-header ephemeral request

- **[Req]** "The request MUST carry nothing that identifies the user, the Mac, the app's version or the macOS version: no identifying User-Agent, no cookie and no query string. ... Beyond them, the request's address, the headers Trackpad Launcher sets, and the body MUST be the same on every Mac and every version." (P022:61)
- **[Dec]** Constraints the design names: "GitHub refuses a request without a User-Agent. URLSession's defaults reveal the Darwin version and the user's languages." (P022:237)
- **[Dec]** "Each request gets its own `URLSessionConfiguration.ephemeral` session, invalidated when the request ends", "Constant headers replace the identifying defaults, including across GitHub's redirect: `User-Agent: TrackpadLauncher`, `Accept-Language: en`, `X-GitHub-Api-Version: 2022-11-28`" (P022:385,390)
- **[Dec]** "`waitsForConnectivity = false`, so offline fails at once (R6)"; "`timeoutIntervalForRequest = 30`" (P022:388-389)
- **[Dec]** "Pinning the API version keeps every shipped version parsing the same JSON after GitHub changes its default (R14)." (P022:391)
- **[Dec]** `kSecCSNoNetworkAccess` "makes `notarized` read the stapled ticket, with no third request; the release always staples." (P022:402)
- **[Dec]** The archive goes into memory because "Nothing is written until all of it has arrived, so a *Cancel*, a *Close*, a Quit, a crash or a logout mid-download leaves nothing on disk." (P022:394)
- **[Log]** "the base keeps the archive inside one install port, in memory" (L022:17); "CFNetwork adds `Cache-Control: no-cache` because of the reload-ignoring cache policy. It is constant on every Mac, so T19 and T24 allow it" (L022:41); R3 was amended to treat the handshake and system-added transport headers as inherent (L022:32).
- **Probed basis:** N1, N2, G1-G6 in section 12.

### 5. "No timers, no polling"

- **[Req]** "While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU in Activity Monitor, with at most one momentary blip per minute." (001 R22, :420)
- **[Dec]** "*Rules are enforced by structure.* ... `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit." (001:556)
- **[Dec]** Plan 001 rejected "**An injected `Clock` and a tap-timeout timer.** ... a timer would be the app's only timer (R22)." (001:1389)
- **[Log]** "the press rule, the button-state sampling and the permission and timer bans were one package for 001's R20 and R22; 002 revokes R20 only → timers and polling stay banned" (`plans/002-gesture-click-blocking/development-logs.md:20`)
- **[Req]** "While nobody uses the picker, Trackpad Launcher MUST do no periodic work to keep it current." (`plans/003-dropdown-recents-performance/plan.md:116`)
- **[Dec]** Plan 021 chose an unbounded wait over a deadline: "We accept that a copy which survives `forceTerminate()` ... leaves the opened copy waiting with nothing shown or recognised until it exits, in exchange for no deadline (timers are banned)" (P021:1062). Also L021:33.
- **[Dec]** Plan 022: "No timers: every input is a push." (P022:232); "30 s with no byte fails through the request's own idle timeout, which every byte resets (probed, N3). The app has no timer of its own." (P022:397); "We accept a request's own idle timeout as the one deadline that is not a Core Animation animation, in exchange for the app having no timer of its own." (P022:1088); "What the design deliberately does not do: check at login or while closed, retry, poll, resume a download..." (P022:445)
- **[Dec]** The Core Animation precedent: "Core Animation is the clock, and every deadline belongs to a bounce." (017:456). Rejected alternative: a dispatch-source deadline port "needs `asyncAfter` or `makeTimerSource` unbanned and the architecture rewritten ... it gives the model a general clock where only bounce-scoped time is needed." (017:1175-1178). Accepted: "time borrowed from the render server's clock, which may stretch across display sleep" (017:1147).
- **[Dec]** Plan 032 generalised it: `LaunchClock` is "one zero-size layer per watched launch in a one-point borderless panel that is never ordered in" (032:325). Risk: "the watch's deadlines are the first in the app with no visible window of ours, in a process that is an accessory most of the time; the probes' deadlines were in unbundled scripts and no longer than 1 s." (032:387) L032:48: "`LaunchWatch` read `ContinuousClock` to skip later limits → removed: the first deadline to pass reports, and time stays on Core Animation's clock."
- **[Note, final rule]** `docs/architecture.md:20`: "This is what keeps idle CPU at zero. Time passes only on Core Animation's clock, and in one network request's own idle timeout ... a deadline is an animation on a layer of the effect it belongs to, its completion is the push, and it cannot outlive that effect."
- **Banned tokens as of P022:987:** `Timer`, `asyncAfter`, `Task.sleep` (plus `makeTimerSource`, per `G022/index.md` E11). "**Still banned:** `import Network`, `NWConnection`, `CFSocket`, `CFStream`, `.write(to:`, `FileHandle(forWriting`, `createFile(atPath`, `Timer`, `asyncAfter`, `Task.sleep`, logging."
- **Relevance:** the rule's stated purpose is idle CPU (R22) plus enforcement by a scan. 039 R1 (every 24 h, "clock time") and R8 (1 minute idle) both need time to pass. No plan has decided how; 039 has no Implementation Decisions yet. See Contradictions 5.

### 6. `Lifecycle` / `Updater` ownership

- **[Dec]** "**Ownership: one deep model, peer to the two existing ones.** `Updater` (`LauncherCore`, `@MainActor @Observable`) owns every update decision" (P022:354). Its surface is `card`, `isInstalling`, `updateNow()`, `cancel()`; internal `windowOpened()`, `windowClosed()`, `onReplaced` (P022:362). "It follows the `StartAtLogin` precedent: one object built by the composition root and shared, with each holder using a different part."
- **[Dec]** "**`Lifecycle`** reads `isInstalling` in its one exhaustive quit switch, and answers `onReplaced` with `end()`." (P022:364)
- **[Dec]** Existence as gate: "There is no `Updater` without an `InstalledRelease`, whose initializer requires the real Developer ID signature and `.installed`." (P022:381) "The following have no `Updater` at all, so they have no path to the network" (P022:249)
- **[Dec]** Why not elsewhere (P022:1095-1097):
  - "**The install as a `Lifecycle` stage, with the check and the download in `Launcher`.** One state machine split across two models by phase (temporal decomposition)"
  - "**Fold the update into `Launcher`.** `Launcher` would learn `Build`, `Placement`, versions and the quit policy, which is exactly what the plan 021 split prevents."
  - "**A port per step** ... A shallow interface: the model would sequence platform steps and carry a downloaded file's path across ports."
- **[Dec]** The split it builds on: "A copy that only asks to move never builds the sensing adapters, the catalog scan or the window's icon pass" (P021:469); P021:1071-1072 rejected deciding in the AppKit delegate ("would live in the untested app target") and folding into `Launcher`.
- **[Log]** "Test planner: the R1/R2 gate lived in the untested app target → the whole gate is the pure `InstalledRelease.init?(...)`" (L022:27)
- **[Dec]** Gate by signature, not build flag: "`--as-release-build` makes a development build read `.release`, and Debug and perf builds are signed with Apple Development under the same team as releases." (P022:234). L022:22 rejected candidate 2's team-presence gate for this reason. `developerIDSigner()` "takes no arguments, so `--as-release-build` cannot fake it." (P022:269-270)
- **[Dec]** Read once: "Reading once matters: after the swap, `Bundle.main` would read the new bundle (R-6)." (P022:349)

### 7. The new version arrives as an ordinary opening by hand

- **[Dec]** "Once the new version is in place, the `Updater` opens it as a new process and this process ends. The new version is an ordinary opening by hand from /Applications: it stops any copy still running, opens its settings window, and that opening checks again." (P022:247)
- **[Dec]** "The new process is an opening by hand from /Applications, so its `.runWithWindow` route stops any copy still running, builds its resident, opens its window, and that first opening checks (R9). The old copy keeps its gestures until it ends." (P022:420)
- **[Note, reasoning from 021's rationale]** `G022/why.md` Preserve 1: "The updated copy should arrive through the existing 'opened by hand, installed' route ... Do not add a separate handover path." Preserve 2: "Add no quit handshake between versions."
- **[Dec]** Route table (P021:471-476): at login + older copy runs → `end`; at login + no older → `runSilently`; by hand, `installed` or `development` → `runWithWindow`, after stopping every other copy; by hand `elsewhere` → `askToMove`.
- **How "by hand" is decided [Note]:** `ThisCopy.opening(of:)`: `event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem` → `.atLogin`; otherwise and for nil → `.byHand`. (`G022/how-lifecycle.md:64`). So anything without the login marker is by hand.
- **[Note]** `G022/index.md` E6: "No argument says 'open your window': `.byHand` + `.installed` does."
- **Precedent for an explicit launch argument [Dec]:** the mover passes `--eject-disk-image <volume>`; "The explicit one-shot argument stays." (P021:504, :1052). `ThisCopy.launch(event:arguments:)`: any other argument ignored (`G022/how-lifecycle.md:63`).
- **[Dec]** "**The old copy ends itself once LaunchServices reports the new one started** (`onReplaced` → `Lifecycle.end()`). This replaces candidate 1's waiting to be stopped, which leaves Quit disabled indefinitely if the new version dies at start. Plan 021 rejected the same thing for the mover. The cross-judge named it the one structural graft." (P022:1059; L022:20)
- **[Dec]** Accepted cost: "A new version that dies leaves no Trackpad Launcher running until the next opening or login, with the new version whole in /Applications." (P022:1082)
- **[Req, Non-goal]** "Changing the hand-over order in `Lifecycle` or `ApplicationsUpdater`. Ending the old copy only once the new one has started is deliberate: a copy that waited to be stopped would never end if the new one failed to start, and gestures keep working until the swap." (P035:39)
- **[Log]** `createsNewApplicationInstance = true` "is load-bearing" (L022:26). Confined: "Only an update opens a second copy of itself." (P022:979)

### 8. Single-instance stop-and-wait

- **[Req]** "At most one Trackpad Launcher MUST recognise gestures at any moment." (P021 R2, cited by `G022/why.md`)
- **[Log]** "Dragging a new build over a running one, or upgrading from the menu bar version, left two builds fighting → new R3" (L021:5)
- **[Dec]** "**Other copies are stopped, not asked.** `RunningCopies.stop` calls `forceTerminate()` and waits for KVO on `isTerminated` (with `.initial`), a push. A copy cannot refuse, hang, show its own dialog or be mistaken for the Dock's Quit, and no handshake binds versions together, the menu bar version included. A copy has nothing to flush: every setting is saved when it changes (F21). Gestures start only after every other copy has exited (R2)." (P021:482)
- **[Dec, rejected alternative]** "**Hand over with a quit Apple event that the running copy honours from a peer.** It exposes a sender-pid protocol to every future version, rests on sender resolution, and leaves the new copy waiting forever on a refusing or hung copy, with no timeout allowed." (P021:1073)
- **[Dec]** "We accept stopping other copies with `forceTerminate()`, with no teardown ... and no protocol between versions." (P021:1056). "We accept that two copies opened by hand at the same instant stop each other and the user opens it again, in exchange for no election or lock. At login, where simultaneous starts are real, the older copy wins." (P021:1057)
- **[Req]** Debug and release are one family: "Every copy of Trackpad Launcher, Debug or release, MUST count the other's running copies as its own when deciding which copy stays" (P026 R2:20)
- **[Req, bug fix]** P035: the wait crashed the new copy. Root cause: "`SystemRunningCopies.stop` keeps the `NSKeyValueObservation`s in `watches` but holds the observed `NSRunningApplication`s only in the local `apps`. ... `NSKeyValueObservation` does not retain the object it observes." (P035:9) "Eight local crash reports from 1.0.0 to 1.0.10 share this stack"; "the new copy died in 15 of 15 rounds"; "With the old copy ended right after opening the new one, 0 of 12 rounds crashed" (P035:13-15). Why it did not show earlier: `Lifecycle.replaced()` "ends the old copy only after macOS reports the new one started, so the new copy usually finds the old one alive." (P035:7)

### 9. The no-`NSSupportsSuddenTermination` rule

- **Origin [Dec]:** "With the window open, three layers apply: `NSSupportsSuddenTermination = YES` lets the system kill instead of asking (F18); `QuitSignals` classifies as `.system` any quit ...; and the Quit button goes through `Lifecycle.quit()`" (P021:495). `project.yml` "Keeps `LSUIElement: true`; adds `NSSupportsSuddenTermination: true`." (P021:973)
- **Mechanism [Req, Problem statement]:** "The app's Info.plist declares `NSSupportsSuddenTermination: true` (`project.yml`). The old version opens the new one with `NSWorkspace.openApplication`, so Launch Services records the new process as a child of the old. When a foreground-type app dies, loginwindow looks through its children for 'non-visible terminatable apps'. The new version, at that instant, is a UI element (`LSUIElement`) with no visible window yet, and it declares sudden termination, so loginwindow schedules it for termination in 3 seconds and then force quits it (`_LSForceQuitApplication`, SIGTERM). The new version opening its window in the meantime does not cancel that." (P038:7)
- **[Req]** "Trackpad Launcher MUST NOT declare sudden termination ... This MUST hold for the first update onto the fix, from a version that still declares it." (P038:27)
- **[Req]** Run-time route also closed: `ProcessInfo.enableSuddenTermination`, "which has the key's effect without the key." (P038:44; L038:10)
- **[Dec]** Key absent, not `false`: "`false` is harmless to loginwindow, but then the test would have to parse YAML to tell `true` from `false`" (P038:106). The test scans `project.yml` lines. "A missing `project.yml` is a failure, not a skip" (P038:73).
- **[Req, Non-goals]** "Starting the new version through a helper so it has no parent would also break the parent link, but it does nothing for the first update onto the fix, and the source policy bans child processes. The new copy's own declaration decides the outcome" (P038:51). "**Catching SIGTERM, or a watchdog or relauncher.** They would hide the mechanism and add moving parts." (P038:52)
- **The point made explicitly for this feature [Req, Non-goal]:** "**Automatic updates.** They come next, and this is their prerequisite. A silent update's new copy never opens a window, so it stays a UI element without one, and loginwindow says it schedules future checks for such a child 'to see if we need to alert about it'. That is an alert, not a termination, and it did nothing within the 75 s watched here; that feature's own plan must look at it." (P038:54)
- **Logout effect of removing the key [Dec]:** without the key, "at logout it takes the quit-event route, for the first time in this app's history." (P038:61)
- **Open item [Log]:** "PENDING HUMAN CHECK (R2), NOT DONE: logout is not held up by the app." (L038:15) See Contradictions 3.

### 10. The exchange-based install

- **[Req]** "**WHEN** the Mac restarts while the new version replaces the old one in /Applications **THEN** after the restart /Applications holds a whole Trackpad Launcher, either 1.0.0 or 1.1.0, that opens and works" (P022:198-200). R12: "/Applications still holds a whole version 1.0.0" (P022:178).
- **[Dec]** "The move's administrator path is two renames, a gap R13's restart scenario does not allow." (P022:236)
- **[Dec]** "The swap is the first change anywhere." "When /Applications and the bundle are writable, `put` uses `BundleInstall.swap` (`replaceItemAt`, one atomic rename, probed R-1). Otherwise it uses `PrivilegedInstall.swap`." "The administrator's script becomes one atomic exchange as root: `osascript -l JavaScript` calling Foundation's `replaceItemAt`, with the paths passed as arguments, or a single `mv` when nothing lies at the destination. This closes the two-rename gap for the move too" (P022:413-416)
- **[Dec]** Why `osascript`: "No stock command-line tool on this Mac does an atomic directory exchange" (`G022/index.md` R-5).
- **[Dec]** "We accept running `osascript`'s JavaScript bridge as root in the administrator path, and changing the move's script with it. In exchange, one atomic exchange closes the two-rename gap for both flows, as R13's restart scenario requires." (P022:1084)
- **[Dec]** Order: "The effect order is unpack, verify, swap, open, end." (P022:413) "The prompt ... comes only after the download is verified (R11)." (P022:417)
- **[Dec]** Destination: "`Location.running`, the running bundle, which lies in /Applications by construction. It is not the move's identifier search." (P022:418)
- **[Dec]** Earlier source of the rule: "Unprivileged it is one atomic replace. With an administrator it is two renames" and the "first change anywhere" order (P021:499-501). Other copies are stopped after the install because a cancelled prompt must change nothing: candidate 2 "stopped the running copy before the admin prompt (R21)" and was rejected (L021:24).
- **[Dec]** Asset choice (P022:1099-1102): DMG needs "an `hdiutil` child process, leaves mount state behind after a crash"; ditto zip "needs a child process with unknown traversal behaviour"; "*The Apple Archive* won: in-process, probed whole, with our own entry filter."
- **[Dec]** Genuineness pins team, identifier and `notarized`, with strict validation, and "The sealed Info.plist must name exactly the offered version and minimum macOS." (P022:401-405)
- **[Dec]** Quarantine: "Quarantine is cleared on every item, as the move does." (P022:410). Reason from 021: a copy that carries none is never translocated, and "a translocated copy sitting in /Applications shows the move dialog" (P021:1066).
- **Relevance to 039:** 039 R11 keeps the outcome ("At every moment /Applications MUST hold either the whole old version or the whole new one"). 039 R12 drops the administrator path for updates. The move keeps it (`PrivilegedInstall`, shared script).

### 11. Carry-over rationale (022), and what was never verified

- **[Dec]** "The update changes nothing but the bundle at the same path: the same identifier and team, so the designated requirement still matches (probed, V5); the same defaults domain; no login-item call at all; no first run, because settings exist. The move's login-item handover exists because the copy changes path, and that reason is absent here. A suspend/resume on every update would risk a 'login item added' notice each time. Whether the item survives is a manual check (open question 1)." (P022:423-429)
- **[Dec]** Open question 1: "Does the `SMAppService.mainApp` login item survive a same-path, same-team replacement? If the first real update shows it was lost, should the update adopt the move's `suspend()` / `resume()` hand-over" (P022:1108). Open question 2: "Do the Accessibility and Screen Recording grants survive in practice? The designated requirement says yes on paper. A loss could not be re-asked under R10" (P022:1109). Risk 8: "The self-replace-and-open was probed with ad-hoc bundles in /tmp." (P022:1115)
- **[Log]** "No update has yet run `.installed` through a real swap." (L022:39) "Not run (manual: ...): C1, C3-C8, and generating the fixtures." (L022:52). C6 is the permissions and login-item check (P022:1258-1266).
- **[Dec]** Settings: "an older build's save cannot drop the fact (`Settings` ignores unknown keys)" (P021:465). `StartAtLogin` lives under its own key, and a move "never creates or spends a first run".

---

## 12. Measured platform facts bearing on a Sparkle relaunch

All 021 probes ran on macOS 26.6.2 / Xcode 27.1 on 2026-10-27; 022 probes on macOS 26.6.2 (25G83), Apple silicon, 2026-11-02. Unless noted, probes used ad-hoc signed bundles in /tmp, not a notarised app in /Applications. P038 and P035 runs used a Release build under a throwaway identifier, signed Apple Development (038) or ad hoc (035 per L035:21).

### LaunchServices: who is opened, who is a child

| # | Fact | Where | Standing |
|---|---|---|---|
| M1 | Opening the same path while it runs starts no second process; the running one gets `aevt/rapp` | F4, `lifecycle-probe/output.txt` E2, E3, E7 | probed |
| M2 | Same build at another path while one runs starts a second process | F5, E4 | probed |
| M3 | Replacing the bundle at the same path (rm + copy) while the old runs, then opening that path from another process, starts a new process; the old keeps running | F6, E8 | probed |
| M4 | M3 holds with an identical version and with a same-version different executable | `checks/same-version-replace/output.txt` | probed |
| M5 | When another process replaces a running app in place and opens it, both default and `createsNewApplicationInstance = true` start a new process from the new bundle; the old keeps running and gets no reopen | R-2, `relaunch.out` | probed |
| M6 | When the running app itself replaces its own bundle and opens its own path with default config: `openApplication answered pid=44690 ... (caller pid=44690)`, `reopen pid=44690 version=1`, no new process. With `createsNewApplicationInstance = true`: new pid, `launch pid=44917 version=2`, old pid keeps running | R-3, `self-relaunch.out` | probed |
| M7 | "the old version opens the new one with `NSWorkspace.openApplication`, so Launch Services records the new process as a child of the old" | P038:7 | stated as root cause from the unified log; the record does not show a direct read of the parent link |
| M8 | Only a new instance's launchd job label has a UUID suffix: "the launchd job labels with a UUID suffix, which only a new instance gets" | P038:12 | field log |
| M9 | `open`-launched app: `currentAppleEvent` is nil in `willFinishLaunching`, and `aevt/oapp` (no `keyAEPropData`, sender = own pid) in `didFinishLaunching`; `launchIsDefaultUserInfoKey` true | F1 | probed |
| M10 | Login marker `keyAELaunchedAsLogInItem` in `oapp` | F2 | sourced from one SO answer, "**Not probed**" on 2026-10-27 |
| M11 | `openApplication`'s completion for an app that never checks in with LaunchServices arrives after a 30 s launch timeout (30.04 s, 30.10 s); a second launch from the same client queues behind it | P035:62, :93 | probed (script app) |
| M12 | `lsappinfo info -pid` prints `type="Foreground"` for a regular-policy app, `type="UIElement"` for a background one | P035:94, F12 | probed |

### loginwindow's rule

| # | Fact | Where |
|---|---|---|
| M13 | Field sequence, 1.0.12 → 1.0.13 on 2026-11-06: old pid 22948 exits status 0 at 21:52:41.05; `subprocess … "Trackpad Launcher" is a UI element without a visible window`; `checking children and related applications for non-visbile terminatable apps`; `terminateAppIf: app=… (23523) supports sudden termination, so terminating all subordinate processes in 3 seconds`; at 21:52:44.297 `supported sudden termination, so terminating all remaining subordinate processes now`; `_LSForceQuitApplication(… (23523)`; `termination reported by launchd (2, 15, 15)` | P038:11 |
| M14 | "Six of six update hand-overs in the last three days ... ended 3.2 to 3.3 s after the old copy exited." | P038:12 |
| M15 | No crash report: "macOS itself kills the process" (P038:5). None since 1.0.10 (P038:13) | P038 |
| M16 | `repro.sh`: key on new copy: 0 of 5 alive. Key removed from new, old on 1.0.13's plist: 5 of 5. Removed from both: 5 of 5 | P038:15-17 |
| M17 | Key removed from the new copy, old on 1.0.13's plist, 75 s: alive. "loginwindow logged the child as a UI element without a visible window, and ran 'terminating all remaining subordinate processes' for the old copy, and left the child alone. The child's own declaration is what decides it." | P038:18 |
| M18 | "loginwindow ignores the death of such an app (`has died, is non-foreground and never tracked, so ignoring it`)": an old copy opened with `open -g` that never showed a window was "never a foreground-type app". First repro attempt: "5 of 5 alive until the stand-in opened a window." | P038:20 |
| M19 | "A silent update's new copy never opens a window, so it stays a UI element without one, and loginwindow says it schedules future checks for such a child 'to see if we need to alert about it'. That is an alert, not a termination, and it did nothing within the 75 s watched here" | P038:54 |
| M20 | At restart, with the key: GUI-quit phase lists foreground apps only ("App is UI Element, do not add it"); `quitUIElementApps` phase; `appIsKillable:` "IS killable"; `tryToKillApp:` killed it with no quit event ("Trackpad Launcher killed, telling CAS"). Non-killable apps get a quit Apple event with logout attributes (`addLogOutAttibutesToQuitAppleEvent`) and a termination timer, then `App:<name> quit, tear down entries` | P038:61, :111 (2026-11-06 18:06) |
| M21 | Foundation disables sudden termination while `UserDefaults` holds unsaved changes (per `NSProcessInfo.h`), so the quit-event route already existed | P038:70 |

### Quit events

| # | Fact | Where | Standing |
|---|---|---|---|
| M22 | `osascript` quit reaches `applicationShouldTerminate`: sender = osascript, no `kAEQuitReason`; `.terminateCancel` gives -128 | F15 | probed |
| M23 | A peer's `terminate()` looks identical; returns true but target stays alive if it cancels | F16, E6: `shouldTerminate allow=false event aevt/quit ... quitReasonAttr=none sender=17682` | probed |
| M24 | With the key set, those quits still reach `applicationShouldTerminate` | `sudden-output.txt` | probed |
| M25 | No one in the repo has observed a real loginwindow quit event's attributes | P038:68, L038:7 | stated gap |

Consequence to weigh: any tool that asks the app to quit with a plain quit event arrives as `.other`. `shouldEnd(.other)` with the window open closes the window and refuses; with the window closed it ends, unless an update installs (P022:720-730). This comes from the plan's sketch; check it against the shipped `Lifecycle`.

### TCC

| # | Fact | Where | Standing |
|---|---|---|---|
| M26 | A Developer ID designated requirement names identifier, Developer ID markers and team; no version or cdhash (Shottr, Ghostty) | V5, `designated-requirement.out` | probed for the requirement; "Not proved for TCC itself" |
| M27 | "macOS stores each Accessibility and Screen Recording grant under the bundle identifier, together with the designated requirement of the copy that was granted. After a Debug build was granted, System Settings showed 'Trackpad Launcher' as allowed, yet the installed release copy was refused because its signature did not match the stored requirement. ... This happened on the developer's Mac with release 1.0.1 (TCC entries inspected on 2026-11-03)." The toggle "looked already on" | P026:5 | field observation |
| M28 | Recovery: `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp`, `tccutil reset ScreenCapture ...` | P026:68 | noted |
| M29 | The perf build keeps the release identifier, "so its Accessibility grant and the installed release's still share one TCC entry, and allowing one can refuse the other" | P026:35 | noted |
| M30 | R5 forbids asking again: "a lost grant could not be re-requested" | `G022/index.md` O3, P022:1109 | requirement consequence |

### Login item

| # | Fact | Where | Standing |
|---|---|---|---|
| M31 | Whether a same-path replace keeps the `SMAppService.mainApp` item, and what BTM keys it by | P021:1085 ("Path or bundle identifier?"), P022:1108, `G022/index.md` O2 | **open in every plan** |
| M32 | Only a LoginItem helper is relaunched after a crash; a main-app registration is not | F23 | sourced (`SMAppService.h`) |
| M33 | `unregister()` of the main app keeps it running; re-`register()` when already registered gives `kSMErrorAlreadyRegistered` | F22 | sourced |
| M34 | How Login Items UI maps to status is disputed | F25 | disputed |

### Replacing a bundle

| # | Fact | Where |
|---|---|---|
| M35 | `replaceItemAt`: `rounds: 1500 observations: 9135126 destination missing: 0 half-filled: 0`; destination inode == staged inode 1500 of 1500; nothing left in staging | `replace-atomicity.out` (same volume as /Applications, in a bundle-shaped directory) |
| M36 | After a self-swap the old process keeps running; `after swap: marker=v2 only-in-v1=true infoVersion=v1`; alive 3 s later. It reads resources afresh from the new bundle, still believes a v1-only resource exists, and keeps the cached Info.plist | `checks/after-swap/after-swap.out`, P022:1114 |
| M37 | `osascript -l JavaScript` did an atomic swap unprivileged, passed `$(touch pwned)` paths intact; a missing destination gave SIGSEGV | `jxa-swap.out`. Not probed as root (P022:1110) |
| M38 | `aa archive` carries source xattrs (`com.apple.macl`, `com.dropbox.attrs` seen); `-exclude-field xat` gives only `com.apple.provenance`. Selection hook `.cancel` stopped extraction after 4 entries | `archive.out`, `checks.out` |
| M39 | A ditto zip of a notarised, stapled app unpacks with `codesign --verify --strict --deep` ok and `stapler validate` ok (3.18 MB vs 3.04 MB aar) | `archive.out` |
| M40 | `notarized` took 19 ms on a stapled app, 281 ms unstapled; `kSecCSNoNetworkAccess` passes on stapled and also on unstapled with a cached ticket | V3, `nonetwork-notarized.out` |

### Network

| # | Fact | Where |
|---|---|---|
| M41 | Default URLSession: `User-Agent: swift-frontend (unknown version) CFNetwork/3860.700.1 Darwin/25.6.0`, `Accept-Language: en-US,en;q=0.9` | `urlsession-probe.out` (a); for an app, the name and build per N1 |
| M42 | Setting User-Agent and Accept-Language replaces defaults, also via `httpAdditionalHeaders` | (b), (b2) |
| M43 | Across a redirect a per-request User-Agent is carried. The probe set only User-Agent in (e), so its after-redirect Accept-Language was the default `en-US,en;q=0.9` | (e); `urlsession-probe.swift:38-39` |
| M44 | `timeoutIntervalForRequest` is an idle timer: 3 s stall failed at 3.1 s (-1001); a slower trickle completed | (c), (c2) |
| M45 | GitHub API: 403 with no User-Agent; `x-ratelimit-limit: 60` unauthenticated; asset URL redirects once to `release-assets.githubusercontent.com` | `github-api.out` |
| M46 | `download(for:)` file in the temp folder: `CFNetworkDownload_*.tmp` with `com.apple.provenance`, no quarantine (command-line process, not the app) | (d), N5 |

### Sudden-termination counter

| # | Fact | Where |
|---|---|---|
| M47 | Default counter is 1; `enableSuddenTermination` decrements it; key overrides it in Info.plist | `G021/sources/apple-suddentermination.json`, P038:74 |

---

## Indirect / Circumstantial Evidence

1. **The window-open precedent.** Plan 003 R4 and R6 tie refreshes to window opening with "no periodic work". `G022/why.md` calls this a fit ("[Inferred]"). P022 itself does not cite plan 003 as the reason. *Suggests* the trigger was natural in this codebase, not only a privacy call. *Alternative:* it may be coincidence, since P022:212 gives its own reason.
2. **The guards are from review and failures in the field, in that order.** `G022/why.md` inferred move guards came from review, not incidents. Plans 035 and 038 are the first field-driven bugs in the update path. *Suggests* that review-derived claims about the hand-over are less reliable than measured ones: both bugs lay on a path P022 Risk 8 flagged as unproven. *Alternative:* two bugs do not show other reasoned claims are wrong.
3. **Both post-update bugs hid behind fakes.** "No test should have caught it as things stand: `InMemoryRunningCopies` replaces the adapter" (P035:17). "No existing test could catch this" (P038:22). P038:100 says a test is "not the right proof: the verdict is loginwindow's". *Suggests* a Sparkle relaunch needs an end-to-end check on the live login session. This is an inference.
4. **The repro's old copy matters.** P038:20 says 035's repro missed the bug because the stand-in never showed a window. `old-copy.swift:10-11`: "The old version hands over from its settings window, which makes it a foreground-type app". An automatic update under 039 R8 hands over with the window closed. *Suggests* neither repro stands in for the 039 hand-over as is. Whether a copy that once showed a window and closed it counts as "never tracked" was not measured (see Gaps).
5. **P038's R1 rationale for "child's own declaration".** M16/M17 show the key on the *new* copy decides. So 1.0.14 onward (no key) and any later copy are unaffected whichever parent runs them. *Caveat:* M17's new copy went on to open its window (it was opened by hand), so a new copy that never opens one is not what M16-M17 measured. P038:54 says so itself.
6. **Admin path never exercised at update time.** F36: the account is an admin. P022 open question 3 unresolved; L022:52 lists C7 not run. *Suggests* the exchange as root may still be unverified. No later plan says otherwise.
7. **Bundle name.** `docs/architecture.md:36` says the DMG ships `Trackpad Launcher.app`, while "an update goes over the installed copy, whatever it is named, so copies installed as `TrackpadLauncher.app` keep that name." `.aar` still holds `TrackpadLauncher.app`. P038 repro uses the binary `Trackpad Launcher`. *Suggests* installed copies differ in bundle file name and executable name, which any new installer must handle. No plan under `plans/` records that rename (grep of `Trackpad Launcher\.app`).
8. **Debug bundle ID.** P026:42: "one no installed copy would accept as an update, since the update's genuineness check pins the signer's identifier." The release guard pins the identifier. Sparkle's own bundle ID and signing checks are not discussed in any plan.
9. **Release assets as a permanent contract.** "We accept the asset name `TrackpadLauncher-<v>-macOS-<min>.aar` and the repository path as a permanent contract with every shipped version." (P022:1086); "only the 30 newest releases are seen, because R3 forbids a query string." (P022:1087). This is the base of 039 R16. A copy more than 30 releases behind "still gets the highest of those 30".
10. **Distribution rules.** "Never sign with `--deep`; the main executable is signed last." (`docs/architecture.md:35`; 001:1609; P021:1011). "hardened runtime, no entitlements". Their stated origin is plan 001's rules. No plan assesses them against nested helpers.
11. **Source policy bans likely to touch Sparkle:** child-process tokens `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`; `URLSession` confined; `http` confined to `GitHubReleases.swift` (P022:978, :986). *Caveat:* "Tests are not source-scanned" (P022:1157), and the scan reads this repo's Swift sources by file name. Whether a linked binary framework falls inside it is not discussed. The rejection's "outside the scan" implies it does not.
12. **Rule from plan 021 R14 and its scan row:** `SMAppService.agent`, `.daemon`, `.loginItem` and `SMLoginItemSetEnabled` banned for "R14: nothing relaunches the app" (P021:1140). Non-goals in 021, 035 and 038 all refuse automatic relaunch mechanisms. Those are about crashes and force quits, not updates; R14 says "after it crashes or is force-quit".

---

## Contradictions

1. **Earlier non-goals versus 039's Solution.** P022:217 ("The user decides when the app replaces itself"), P022:212 ("Checking in the background or at login") and 001:448 ("Automatic updates") all oppose 039. These are deliberate product reversals, not errors. Item 5 covers the timer rule.

2. **Reopen versus new process depends on who opens.** M1 and M6 (self open, default config: reopen) versus M3 and M5 (another process opens: new process). F4 and F6 agree only given the replace. P021:370 says "any other open ... starts a second process", which P022 refined with R-3 for the self case. Nothing was measured for a helper that opens after the old process is gone, which is the shape relevant to an external installer.

3. **`docs/architecture.md` states as fact what L038 lists as unverified.** Architecture:11: "Without the declaration a logout, restart or shutdown reaches the app as the quit event, which `Lifecycle` answers at once." L038:15: "PENDING HUMAN CHECK (R2), NOT DONE". L038:18: "Review, not taken: ... softening 'which `Lifecycle` answers at once', since R4 names that claim and the pending logout check above decides it." P038:68 names the failure: a logout's quit read as `.other` with the window open, mid-move or mid-install "would answer `.terminateCancel` and cancel the logout". No later plan records the result. 039 R14 depends on this.

4. **Sudden termination: safety layer, then cause of the bug.** P021:495 and C25 (P021:1197, "`LSUIElement` and `NSSupportsSuddenTermination` are both true") set it for logout safety. P038 bans it. P038:68 says "With the key, the kill made that unknown harmless; this fix removes the kill." P021:1051 already dropped it as a guard during install ("it protected nothing").

5. **The no-timer rule and its escape hatches.** P022:1088 calls the request's idle timeout "the one deadline that is not a Core Animation animation". `docs/architecture.md:20` adds a third, "the lift window" stamped on a monotonic clock, where "nothing fires at the end". The Core Animation rule says a deadline "cannot outlive that effect" and belongs to "a layer of the effect it belongs to". A 24-hour clock-time check (039 R1) that fires at wake has no such effect, and 017:1147 says the render server's clock "may stretch across display sleep". 039 R1 requires the opposite. P022:445 said the design does not "retry, poll". 039 R1 and R5 require retry. If Sparkle owns a timer in its own binary, it may sit outside the scan but not outside "No timers, no polling, no background loops". No plan reconciles this.

6. **Plan vs reality, hand-over order.** `G022/index.md` R-4 concludes the new process "force-stops the old process, waits for its exit". P022:1059 grafted self-end. Both now happen, and P035:7 shows the two paths race: the old copy "usually" is still alive at `stop`, the condition for the crash.

7. **P022 R13 vs L022/testing depth.** P022:1283: "A restart during the swap (R13) has no manual check, because it cannot be timed by hand. T32 and T33 prove it." T32 is unprivileged only (P022:1215). Open question 3 says root was not probed.

8. **"Automatic updates... prerequisite" scope.** P038:53: the move's `openInstalledCopy` "had the same exposure". R1 covers it with no code. So the sudden-termination rule protects the move as well as updates, a fact the Sparkle removal must not lose: the source-scan rule must stay after `ApplicationsUpdater` goes.

---

## Gaps

- **Sparkle evaluation.** Grepped everything under `plans/` and `docs/` for `sparkle` (case-insensitive). Outside 039: P022:1104, `candidate-1.md:863`, `how.md:326`, `how-build-release.md:122,154`, `why.md:144`, `why-plans.md:45,416`, `github-api.sh/.out`. No probe, no benefit analysis, no discussion of a custom user driver, of Sparkle's request headers or system profile, or of its relaunch mechanism. 039's plan has no Implementation Decisions yet.
- **Whether grants survive a real update.** Searched the carry-over regex above, excluding 022 and 039. No plan records C6's result, though L022:52 says it was not run and copies have updated since. P038:12 shows real updates occurred. P026 (TCC) concerns Debug vs release, not version to version. M26 is a conclusion, not a measurement of TCC.
- **Whether the login item survives a replace.** Same search: no result in any plan. P021:1085, P022:1108 and `G022/index.md` O2 all leave it open. No plan records a "login item added" notice or its absence. Plan 039 R10 requires it.
- **A silent new copy's fate.** P038:54 is the only text. Watched 75 s only. The "alert" behaviour was not observed or characterised beyond one log line, and the new copy in that run did open a window (the plan's round requires `type="Foreground"`; the 75 s run's own setup is summarised, not itemised). So the claim is about a child "logged ... as a UI element without a visible window" at the moment of the old copy's death.
- **An old copy that once had a window, then closed it, at hand-over.** P038:20 covers "never a foreground-type app" and a copy with its window open. A UI element copy that was foreground earlier in its life is unmeasured. 039 R8's install happens in exactly this state whenever the user opened the window earlier in the run.
- **Parent link for a process started by an installer or helper.** All measurements have the old app itself call `openApplication`. Nothing covers a relaunch by a helper, launchd, or after the old copy has already exited. P038:51 says a helper parent "would also break the parent link" as reasoning, unmeasured.
- **Silent launch signal.** No plan defines a launch that is not `.atLogin` but stays silent. E6: "No argument says 'open your window'". 039 R9 needs this. P022:419 and :847 use `activates = true`. `activates = false`, `addsToRecentItems` and `hides` appear in none of P022, P035, P038 or the 039 plan. Plan 032 and 034 touch activation only for other subjects (not read in depth).
- **Which `Route` applies when an updated copy starts while the old runs.** The table only has `.atLogin`/`.byHand`. "at login + older copy runs → end" (P021:473) would end a new copy that claimed to be a login start while the old one runs. Not addressed for updates.
- **App Nap for a window-less resident.** P032:387 flags it for 2 s deadlines. No measurement for hours or for network work. `grep 'App Nap'` over `plans/` hits only plan 032, a plan 001 candidate and plan 021's grounding `why` files.
- **Quit Apple event sender for an updater.** No probe of what `applicationShouldTerminate` sees when an installer helper quits the app. M22/M23 show plain quits read `.other`.
- **Standard account with Sparkle.** No plan measures bundle-writability detection. 022 used "/Applications writable and destination bundle dir writable" (`G022/index.md` E7).
- **`.temp` of 038/035 has no probes dir.** Their evidence is in the plan text and repro scripts; the unified-log extracts themselves are not saved in the repo. M13, M17, M19 and M20 can be cited only from the prose.
- **Reasons for specific non-network 022 choices that had no stated reason:** why the reopened window checks (R9) beyond "Every opening counts" (L022:8); why `activates = true`. Nothing beyond the sketch.
- **Why `NSSupportsSuddenTermination` was originally set beyond decision 7.** P021:495 and F18 only.

---

## Additional Leads

- **Source control:** the `Trackpad Launcher.app` rename and the `Scripts/release.sh patch|minor|major` flow have no plan. Their commits or PRs should say why.
- **Source control:** whether the R2 logout check of L038:15 was done after the 038 PR, and whether real updates since 1.0.x recorded login-item or TCC results in PR text or `gh release` notes.
- **Source control:** PR text for 1.0.13 and 1.0.14 (#44, "The new version outlives the old one after an update") and how many copies in the field run a version that declares the key, which bounds R16's first-update path.
- **Source control / code:** shipped `Lifecycle.shouldEnd`, `QuitSignals`, `SourcePolicyTests` rows, which P022 only sketches. `Updater.swift`, `ApplicationsUpdater.swift`, `GitHubReleases.swift`, `BundleInstall.swift`, `PrivilegedInstall.swift` should be checked against P022:447-937, since S3 made `admits` stricter (L022:42) and L022:41 records a header deviation.
- **Direct measurement for the 039 planner:** the Gaps above are probe candidates. Priority by their effect on R9, R10 and R14: silent child after a window-closed old copy dies; TCC and login item across a Developer ID in-place replace; a quit event from an installer; a real logout with the window open.
- **Plan 039 itself:** R10 lists "starting at login"; R13 and R14 inherit `shouldEnd` and `QuitSignals`. `plans/032-hide-background-apps/plan.md:327` says "`Launcher.window` stays open while the app is hidden" so "the updater, the quit rules and the window's request count are untouched"; 039 R8's "settings window is closed" should use the model's state, not visibility, given that (inference).
- **Saved sources:** `G021/sources/apple-processinfo.json`, `apple-smappservice-mainapp.json`, `letsmove-PFMoveApplication.m` (`Relaunch`, :539) are prior art for a relaunch. `G021/index.md` F33 summarises LetsMove: a `sh` script waits for the pid, strips quarantine, then opens the new copy. `G022/why.md` Avoid 1 said not to copy that with sleeps or pid polling.
</content>
</invoke>
