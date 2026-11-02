# Why (Plans investigator): process lifecycle, the move into /Applications, and the no-network / source-scan rules

Source: `plans/` only (plan.md, development-logs.md, and the committed `.temp/` grounding, candidates and slice briefs
of earlier plans). `plans/022-in-app-updates/` was not read except for two grep hits (orientation only, not used as
evidence). `research/` was not read. Git history was not used.

Paths below are relative to the repo root unless stated.

---

## What I Searched

- Listed every plan dir: 001-017, 021, 022. There are no plan dirs 018, 019 or 020.
- Read in full:
  - `plans/021-background-agent-lifecycle/plan.md` (1365 lines) and `development-logs.md`.
  - `plans/001-trackpad-launcher-app/development-logs.md`.
  - `plans/003-dropdown-recents-performance/development-logs.md`.
  - `plans/021-background-agent-lifecycle/.temp/architect/grounding/index.md` (facts F1-F46 with their standing) and `grounding/why.md` (its Preserve/Change/Avoid/Risk set).
  - `plans/021-background-agent-lifecycle/.temp/slices/fixes.md` (the post-review fix brief).
- Read by section:
  - `plans/001-trackpad-launcher-app/plan.md`:
    - Problem statement and Solution (lines 1-18).
    - R17-R23 and Non-goals (lines 360-452).
    - Design Problem and Shape, including decisions 1-9 and the requirement trace (453-622).
    - Ports (921-958).
    - Tests and SourcePolicyTests sketch, Synthesis, Tradeoffs, Alternatives, Open questions, Testing strategy (1246-1425).
  - `plans/002-gesture-click-blocking/plan.md`:
    - Header (line 17).
    - Design problem (247).
    - Decisions 1-8 (375-382).
    - SourcePolicyTests sketch (1070-1101) and Docs paragraph (1115).
    - Alternatives (1144, 1148).
    - T48/T49.
  - `plans/003-dropdown-recents-performance/plan.md`:
    - Solution (15), R4 and R6 (86-122).
    - Implementation Decisions "Where the list lives" (136-162).
    - The AppScanner port and "Why a port" (190-202).
    - Docs (268-273).
  - `plans/006-five-finger-tap-and-corner-swipe/plan.md`: lines 491 and 650 (decision 12), plus T79.
  - `plans/012-window-switcher-gesture/development-logs.md`: lines 25-35.
  - `plans/017-launch-wait-bounce/plan.md`: lines 236-260 (constraints); `development-logs.md` lines 25-35.
  - The 021 slice briefs S1, S3, S4, S5, S6 and S7, via greps for rationale, privacy, confinement and source-scan lines. S6 "Why this API" was read in full.
  - The 021 `.temp/architect/candidate-1.md` (Tradeoffs, Alternatives, Open questions, lines 586-617), `candidate-2.md` (lines 740-810) and `task.md`.
- Greps across `plans/*/plan.md` and `plans/*/development-logs.md`, excluding 022:
  - `network|phones home|update check|auto.?update|Sparkle|self-update|updating itself`
  - `two adapters|exactly two adapter|deliver(s)? asynchronously|not put behind a port|pointable`
  - `source scan|SourcePolicy|confin|banned` (dev logs)
  - `confined|never weakened|banned to confined` (002, 006, 012, 014, 017 plans)
  - `each time the (launcher|settings)? window opens|when the window opens|window-open|on window open`
  - `two copies|single.instance|/Applications|terminate|notari|Developer ID|code.?sign` (plans 002-017)
- Listed the committed `.temp/` content of every plan: `git ls-files plans | grep .temp`. Plan 021 has `.temp/architect` (grounding, probes, sources, candidates, rubric, task), `.temp/design`, `.temp/slices` and `.temp/test-planner`.
- Not read: `plans/021-background-agent-lifecycle/.temp/architect/grounding/why-plans.md`, `why-source-control.md` and the `how*.md` files. These are the earlier investigators' raw outputs; `why.md` and `index.md` summarize them. Also not read: candidate-1 and candidate-2 in full, and the 021 S1-S7 briefs in full.

---

## Direct Evidence Found

### A. The no-network rule and "no self-update"

1. **Origin of no network, as a product promise.**
   - Plan 001 Problem statement (`plans/001-trackpad-launcher-app/plan.md:9`): "A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled."
   - Plan 001 Solution (line 15): "It starts at login, needs no permissions, never touches the network, and idles at zero cost."
   - Relevance: this is the stated motivation. It is a cost/trust argument ("gets uninstalled"), not a technical one.

2. **R21 wording** (`plans/001-trackpad-launcher-app/plan.md` § R21. No network, no logging, line 409): "Trackpad Launcher MUST make no network connection of any kind. It MUST write nothing to disk of its own except its settings (assignments, hand mode, whether it has launched before); files macOS writes on every app's behalf do not count. It MUST NOT write log messages of its own, to the system log or to any file."
   - Scenario "Silent on the network": "**WHEN** a network monitor watches the app through launch, configuration, ten gestures and quit **THEN** it records zero connections or connection attempts from Trackpad Launcher".
   - Relevance: this is where "no network of any kind" and "no files written other than settings" come from.

3. **Automatic updates were excluded because of the network rule.**
   - Plan 001 § Non-goals (line 448): "**Automatic updates.** Update checks are network calls; the app makes none."
   - Relevance: the earliest record that updating was ruled out, and the only reason given is the network rule.

4. **Plan 021 restates the exclusion and leaves it to a later product decision.**
   - Plan 021 § Non-goals (`plans/021-background-agent-lifecycle/plan.md:350`): "**Updating itself.** Checking for updates needs a network call, and the overview promises none. Changing that is its own product decision and a later feature."
   - Relevance: this is the direct precursor to plan 022. It names updating as deferred, not as rejected on merit.

5. **How R21 is enforced (plan 001 decision 9)** (`plans/001-trackpad-launcher-app/plan.md:556`): "*Rules are enforced by structure.* `LauncherCore` cannot import AppKit, IOKit or the private framework. `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit."
   - The original banned list, from the SourcePolicyTests sketch (lines 1318-1329):
     - Network: `("URLSession", "R21 network"), ("import Network", "R21 network"), ("NWConnection", "R21 network"), ("CFSocket", "R21 network"), ("CFStream", "R21 network")`.
     - Own files: `("FileHandle(forWriting", "R21 own files"), (".write(to:", "R21 own files"), ("createFile(atPath", "R21 own files")`.
     - Logging: `print(`, `NSLog(`, `os_log`, `Logger(`, `import os`, and others.
     - Timers and polling: `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`.
   - Relevance: these are the token rows a network-using update check must get past.

6. **Plan 001 Testing T22 and manual R21** (`plans/001-trackpad-launcher-app/plan.md`):
   - T22 (line 1453): a scan "Parametrised over the banned-token list … zero hits across every `.swift` under the package's Sources and the app target. Self-check: scanning a temp directory holding a file containing `print("x")` returns exactly that one hit".
   - Manual R21 (line 1517): "`nettop -p $(pgrep -x TrackpadLauncher)` (or Little Snitch) over launch, configuration, ten gestures and quit shows zero connections and attempts; … `lsof -p <pid>` during the session lists no file open for writing except through cfprefsd."
   - Relevance: the network rule was checked both by the scan and by a manual session.

7. **Plan 001 dev log, Implement** (`plans/001-trackpad-launcher-app/development-logs.md:52-53`):
   - "Review (plan): decision 9 'LauncherCore cannot import AppKit, IOKit or the private framework' was unenforced → `SourcePolicyTests` fails on any LauncherCore import other than Foundation and Observation, with a planted-import self-check."
   - "Review (plan): the source scan silently skipped the app target if absent → the visit check asserts `TrackpadLauncher/` was scanned."
   - Relevance: these are the origins of the import rule and of the app-target coverage in the scan.

### B. How the source scan evolved: banned → confined, "add to its list rather than adding prose"

8. **Plan 002 created the `confined` mechanism when a rule was revoked on purpose.**
   - Plan 002 header (`plans/002-gesture-click-blocking/plan.md:17`): "Its R20 'No permissions' is replaced by R9 here."
   - Decision 8 (line 382): "*Rules stay structure.* The scanner stops banning the two Accessibility APIs the design uses, confines each to the single file that owns it, adds bans for what R6 and R9 forbid, and pins the kept tokens with a self-check."
   - Sketch (lines 1079-1101):
     - "/// Unchanged: log, network, own files, timer, polling, `nonisolated(unsafe)`."
     - "/// Removed: 'AXIsProcessTrusted', 'tapCreate', 'CGEventTapCreate' (plan 002 R9 replaces 001 R20; now confined)."
     - "/// Each permission API lives in exactly one file, the adapter that owns it. Any other hit fails."
     - `confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans`
   - Relevance: this is the precedent for relaxing a no-X rule. Plan 002 revoked one requirement deliberately, moved the tokens from banned to confined in one file, and pinned the remaining bans with a self-check.

9. **Plan 002 dev log, Plan** (`plans/002-gesture-click-blocking/development-logs.md:20`): "Grounding (`why`): the press rule, the button-state sampling and the permission and timer bans were one package for 001's R20 and R22; 002 revokes R20 only → timers and polling stay banned".
   - Relevance: a precedent for revoking one rule narrowly while keeping the rules next to it.

10. **Plan 006 decision 12** (`plans/006-five-finger-tap-and-corner-swipe/plan.md:650`): "*The gate moves the token; it does not weaken it (F17).* `scrollWheel` leaves `banned` and becomes `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift")`".
    - Line 491 says the plan "has to pass a source gate that bans the very API it uses: the token moves from banned to confined, never weakened (F17)."
    - T79 cites "the architecture's 'add to its list rather than adding prose'".
    - Relevance: the same pattern applied a second time.

11. **The scan reads comments** (`plans/012-window-switcher-gesture/development-logs.md:30`): "Verify: the source scan reads comments, so a core doc comment naming a confined API would fail it → stated in the design."
    - Plan 021 dev log, Plan (line 29): "Verification: three Core doc comments spelled confined tokens (`keyAELaunchedAsLogInItem`, `kAEQuitReason`, `SMAppService`), which the source scan reads → reworded."
    - Relevance: a constraint on where any new confined token may be spelled, comments included.

12. **Plan 017: one token may be confined to a set of files** (`plans/017-launch-wait-bounce/plan.md:1102-1106`): "`Confined.onlyIn` becomes a `Set<String>`."
    - Dev log line 31 (cross-judge graft): "`addGlobalMonitorForEvents` is confined too", with the reason given at plan line 1121: "so every reader of pointer events is named".

13. **Architecture rule quoted in the 021 slice briefs**:
    - S3.md:141, S1.md:315 and S4.md:163 quote `docs/architecture.md` § Privacy: "A source-scan test in `LauncherCoreTests` fails the build on any banned API; add to its list rather than adding prose."
    - This is a quote of the doc as it stood, not plan text. Recorded so the synthesizer knows where it appears in plans.

### C. The "no files written other than settings" rule amended for the move

14. **021 grounding F37** (`.temp/architect/grounding/index.md`, Q6): "The source scan does not ban `FileManager.copyItem/moveItem/replaceItemAt/removeItem`, but `docs/architecture.md:27` says 'no files written other than settings in UserDefaults'; the move contradicts the prose, which must be amended on purpose. `Timer`, `asyncAfter`, `Task.sleep` are banned in shipped code, so 'wait for the old copy to exit' must be a push (KVO `NSRunningApplication.isTerminated`, `NSWorkspace.didTerminateApplicationNotification`)."
    - 021 `why.md` Avoid 4 says the same: "Logging, network, or own-file writes beyond settings. A move-to-/Applications copy and a relaunch must use APIs the scan does not ban, *and* the change must amend plan 001 R21 / architecture.md's 'no files written other than settings' on purpose, not slip past it".

15. **Plan 021 Docs list** (`plans/021-background-agent-lifecycle/plan.md:1024`): "Privacy: the launcher window's outside-click monitor goes; 'no files written other than settings in UserDefaults, and the app's own bundle into /Applications when the user chooses Move to Applications'."
    - Line 1028 gives the source-scan rows. Move-related: "`copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `quarantinePropertiesKey` to `BundleInstall.swift`; `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` to `PrivilegedInstall.swift`; `statfs`, `DADisk`, `unmountVolume` to `DiskImages.swift`; `runModal` to `MoveDialogPresenter.swift`". Signature: "`SecCode`, `SecStaticCode`, `SecRequirement` to `CodeSignature.swift`". Copies: "`forceTerminate` and `.terminate(` to `SystemRunningCopies.swift`".

16. **Why the move's file operations ended up in two files** (`plans/021-background-agent-lifecycle/development-logs.md:50`): "Review: the administrator script's `mv`/`rm` broke the doc's 'every file operation of that move is confined to one file' → the doc now names the unprivileged file and the script's file; `/bin/mv` and `/bin/rm` confined to `PrivilegedInstall.swift`."
    - `fixes.md` item 3 adds the reason: "The plan designed the administrator script as its own file deliberately (it confines `AuthorizationExecuteWithPrivileges` and the test runs the real script), so the doc is what's wrong."
    - Plan dev log line 38 explains the single-file confinement for unprivileged operations: "Test planner: the `removeItem(` confinement clashed with the installer's comments and its cancel path → every file operation goes through `BundleInstall`."

### D. Shape: ports, exactly two adapters, async-delivering types behind ports, two models

17. **Every port has two adapters (plan 001).**
    - Plan 001 Ports: each protocol is documented "Real: X. Test: Y" (lines 927, 942, 950).
    - Dev log line 25: "candidate-2's seven one-method protocols plus `openURL`/`terminate` closures in the hub rejected as a larger surface with no added policy."
    - Plan 001 Synthesis (line 1360) rejected "the seven-protocol split with `openURL`/`terminate` closures in the hub (shell actions carry no policy)".
    - Later plans restate the rule as carried over:
      - 002 line 247: "every port has exactly two adapters".
      - 006 line 491: "every port has exactly two adapters and framework types never cross one (F25)".
      - 012 line 405.
      - 017 line 258: "No framework type crosses a port, and every port has two adapters."

18. **Why the model stays synchronous, with the hop in the adapter (plan 001 dev log, Plan)** (`plans/001-trackpad-launcher-app/development-logs.md:28`): "Cross-judge: candidate-2's hub-owned `Task { @MainActor }` hop made its own negative test unable to fail → the main-actor hop lives in the hardware adapter so the in-memory adapter delivers gestures synchronously."
    - Plan 001 Alternatives (line 1385): "The core would contain threading, and tests would wait on an async hop to observe both 'nothing happened' and 'something happened'. Moving the hop into the adapter keeps the core synchronous and deterministic."

19. **Origin of "async-delivering types sit behind a port".**
    - Plan 003 § New port: AppScanner, "Why a port" (`plans/003-dropdown-recents-performance/plan.md:197`): "The threading stays in the adapter and the model stays synchronous. Plan 001 made the same choice for the hardware port, after rejecting a model-owned `Task` hop whose negative tests could not fail. A temp directory could drive the real scanner, and the architecture usually keeps such types concrete. It now names the exception: an adapter that delivers asynchronously sits behind a port, so the model's tests stay synchronous."
    - Plan 003 dev log, Plan (line 26): "The new port bent the architecture's 'temp-directory types stay concrete' rule silently → architecture.md now names the exception for asynchronous adapters, and the off-main rule for work that would delay a click."
    - Plan 003 Docs (line 272): "The port exception for adapters that deliver asynchronously."

20. **Plan 021 applies that rule to `Installer`.**
    - S5 brief (`.temp/slices/S5.md:236`) quotes architecture § Shape: "Every port has exactly two adapters … Concrete types that can be pointed at a temp directory … are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous." It then adds: "(`Installer` delivers asynchronously → a port; `BundleInstall` is tested directly over temp dirs.)"
    - Plan 021 dev log line 22: "Red-flag screen, candidate-1: the `Installer` port's four calls look shallow → kept, because `Lifecycle` must hand over the login item between the install and removing the original, and tests pin that order."

21. **Two models: why `Lifecycle` is separate from `Launcher` and builds it lazily.**
    - Plan 021 decision 1 (`plan.md:469`): "**`Lifecycle` sits above and beside `Launcher` and builds it lazily** (via `makeResident`). A copy that only asks to move never builds the sensing adapters, the catalog scan or the window's icon pass; a resident copy can still show the dialog while its gestures run."
    - Design Problem (line 369): "The gesture adapters start sensing in their `init`s and `Launcher.init` scans the disk (F11). A copy that only asks to move must never build them, yet a copy that already runs gestures must still be able to ask (R18, last scenario)."
    - Rejected alternatives (lines 1071-1072):
      - "**Decide in the AppKit delegate with pure helpers, no `Lifecycle`.** The interface is smaller, but the sequencing that R2, R18 and R21 hinge on would live in the untested app target (`why.md` Risk 9): wait for other copies before sensing, ask before building anything, install before handing over the login item."
      - "**Fold the lifecycle into `Launcher`, started by a `launch(_:)` intent.** It keeps one model, but `Launcher` exists only with its sensing adapters and its disk scan (F11). A copy that only asks must not build them, and a running copy must still be able to ask, so the owner of the decision has to exist before the gesture model and beside it."
    - Synthesis, rejected from candidate-2 (line 1047): "Lifecycle folded into `Launcher`: a copy that only asks would build every sensing adapter (F11), and it adds a public `Phase` that leaks its stages."
    - Dev log line 21: "Red-flag screen, candidate-2: `Launcher` absorbed peers, the move and quit classification (an owner of unrelated concerns), and its public `Phase` leaked internal stages → rejected as the base."
    - Candidate-2 argued the other way (candidate-2.md, Alternatives): "A separate `@Observable ProcessLifecycle` model beside `Launcher`. Cleaner file sizes. Lost: the start, the first run, the login item and the window are one invariant … two owners of it need a protocol between them that is as wide as the thing it splits." The synthesis did not adopt this view.

22. **Why the platform tangles sit behind ports** (`plan.md:509`, Depth): "Each new port hides a platform tangle behind two to four calls: `forceTerminate` plus KVO; translocation, staging, authorization and an atomic swap; `SMAppService` and its errors." Also: "The delegate knows nothing about copies, installs or login items."

23. **Ports live in `Ports.swift`** (`fixes.md` item 7): "`RunningCopies`, `LoginItem` and `Installer` are declared in `LauncherKit/Sources/LauncherCore/Lifecycle.swift:68-159`, while every other port lives in `Ports.swift`. **Fix:** move the three protocols … into `Ports.swift`."
    - Dev log line 51: "ports declared outside `Ports.swift` … → fixed."
    - Plan-vs-reality: the plan's Module map (line 969) put the ports in `Lifecycle.swift`.

### E. Process lifecycle: routing, single copy, stop not ask, wait by push

24. **Problem plan 021 set out to fix** (`plan.md:7`): "Nothing makes sure the app ends up in /Applications. An app run from ~/Downloads or straight from a disk image breaks in quiet ways: its login item points at a file the user later deletes, and macOS runs a quarantined download from a hidden, randomised copy."

25. **Every second process is a newcomer, never a reopen** (Design Problem, `plan.md:370`): "LaunchServices turns an open of the running copy's own bundle into a reopen; any other open (another place, or a bundle replaced at the same path, whatever its version) starts a second process (F4-F6, `checks/same-version-replace`). So every second process is a newcomer to resolve, never a reopen."
    - Dev log line 17: "Grounding: a reopen of the running bundle reaches it as `rapp`, but another place or a bundle replaced at the same path starts a second process (probed) → every second process is resolved by `Lifecycle`, never treated as a reopen."
    - Grounding F6 (probed): "Replacing the bundle **at the same path** with a different build (remove + copy, as Finder's Replace does) while the old one runs, then opening that path, **starts a new process from the new build**; the old one keeps running."
    - Relevance to 022: replacing the /Applications bundle in place does not stop the old process.

26. **Version stamping dropped** (Synthesis, line 1045): "Candidate-1's release-time version stamping is dropped. A post-fan-out check (`.temp/architect/checks/same-version-replace/output.txt`) showed that LaunchServices starts a new process for a bundle replaced at the same path even with the same `CFBundleVersion`, so R3 does not need it, and no requirement asks for it."
    - Dev log line 28 says the same.

27. **Other copies are stopped, not asked** (decision 3, `plan.md:482`): "`RunningCopies.stop` calls `forceTerminate()` and waits for KVO on `isTerminated` (with `.initial`), a push. A copy cannot refuse, hang, show its own dialog or be mistaken for the Dock's Quit, and no handshake binds versions together, the menu bar version included. A copy has nothing to flush: every setting is saved when it changes (F21). Gestures start only after every other copy has exited (R2). Which copy started earlier is one strict total order, a pure rule in the adapter: launch date, a missing date counting as latest, then pid. Two login starts therefore compute mirror-image answers and converge on one copy."
    - Dev log line 18: "Grounding: a peer's `terminate()` arrives exactly like the Dock's Quit (probed) → other copies are stopped with `forceTerminate()` and a KVO wait, not asked."
    - Grounding F16 (probed): "`NSRunningApplication.terminate()` from another process arrives the same way (sender pid = that process, no reason). It returns `true` (request sent) but the target stays alive if it cancels."
    - Rejected alternative (line 1073): "**Hand over with a quit Apple event that the running copy honours from a peer.** It exposes a sender-pid protocol to every future version, rests on sender resolution, and leaves the new copy waiting forever on a refusing or hung copy, with no timeout allowed."
    - Synthesis, rejected from candidate-2 (line 1048): "Asking peers to quit by classifying the sender: a peer can refuse or hang, and future versions would be bound to honour it."
    - Tradeoff (line 1056): "We accept stopping other copies with `forceTerminate()`, with no teardown, in exchange for a stop that cannot be refused, hung or confused with the Dock's Quit, and no protocol between versions. Nothing needs saving (F21)."

28. **No deadline while waiting for a copy to exit (accepted risk).**
    - Tradeoff (line 1062): "We accept that a copy which survives `forceTerminate()` (only one stuck in the kernel, such as on a hung network share) leaves the opened copy waiting with nothing shown or recognised until it exits, in exchange for no deadline (timers are banned) and no copy ever running gestures beside another."
    - Dev log line 33: "Test planner: a copy that survives `forceTerminate()` leaves the opened copy blank → rejected as a design change, because no deadline is allowed; recorded as an accepted tradeoff."
    - Testing strategy (line 1124): "No clock is owned. The design has no timer, deadline or retry, and every wait is a push the row withholds. The existing timer bans in `SourcePolicyTests` keep a timer from turning a row green."

29. **Precedent for KVO `isTerminated` with `[.initial, .new]`** (plan 017, `plans/017-launch-wait-bounce/plan.md:246`): "KVO on `isFinishedLaunching` and `isTerminated` pushes for every kind of app, menu bar apps included. Workspace notifications do not (F12, F13)."
    - Line 436: "`.initial` covers a completion that arrives after finishing".
    - Relevance: an earlier probe-backed choice that plan 021's copies-exit wait reuses.
    - `fixes.md` item 5: "`SystemRunningCopies.stop` reports already-exited copies a turn late … **Fix:** before registering KVO, drop every resolved copy whose `isTerminated` is already true; if none remain, call `exited` synchronously".

30. **Accepted tradeoff: simultaneous opens by hand** (line 1057): "We accept that two copies opened by hand at the same instant stop each other and the user opens it again, in exchange for no election or lock. At login, where simultaneous starts are real, the older copy wins."

31. **R2/R3 requirement text** (`plan.md:33, 51`):
    - R2: "At most one Trackpad Launcher MUST recognise gestures at any moment."
    - R3: "When the user opens the copy in /Applications by hand while a different build of Trackpad Launcher runs, or the same build from another place, Trackpad Launcher MUST stop the running one and start the opened one with its settings window open. One Trackpad Launcher MUST run afterwards, and it MUST be the opened version. This holds when the user dragged a newer version over a running one in Finder".
    - Specify dev log line 5: "Dragging a new build over a running one, or upgrading from the menu bar version, left two builds fighting → new R3".
    - 021 `why.md` Avoid 5 cites `docs/performance.md:8`: "two copies both react to gestures".

32. **The route table** (decision 1, lines 471-478):
    - (at login, any placement, older copy runs) → `end`
    - (at login, any placement, no older copy) → `runSilently`
    - (by hand, `installed` or `development`, any) → `runWithWindow`, after stopping every other copy
    - (by hand, `elsewhere`, any) → `askToMove`
    - "A reopen uses the same table". Grafted from candidate-2 per Synthesis line 1035: "The routing as one pure table: `Route`, used by launch and reopen alike."

33. **A login start does no first-run work** (decision 4, line 484; tradeoff line 1059): "We accept that a login start does no first-run work and the first opening by hand does it, in exchange for a login start that is always silent."

34. **Opening by hand raises the window, and the window's open state is a counter** (`plan.md:465`): "every opening by hand increments the request, so a reopen of an open or minimised window is still a state change the shell renders."
    - `Launcher.openedByHand()` doc (line 819): "Every time: `window = .open(request: n + 1)`, rows, scan."
    - Relevance to 022: this is the per-opening hook. Each opening by hand already re-resolves rows and requests a scan.

### F. Quit: only the Quit button stops the app

35. **R8 and R11** (`plan.md:110-118, 181-182`):
    - R8: "Every ordinary way to quit only closes the window … ⌘Q, or *Close Settings* in the app menu … *Quit* in the Dock icon's menu … The Dock menu's *Quit* label can't be changed. It is an accepted oddity. Logging out, restarting and shutting down MUST still end Trackpad Launcher without the user being asked."
    - R11: "Pressing *Quit Trackpad Launcher* MUST stop Trackpad Launcher at once, with no confirmation".
    - Specify dev log line 7: "The app menu's 'Quit Trackpad Launcher' would only close the window while the button of the same name quits → the app menu item reads 'Close Settings' (⌘Q); the Dock's 'Quit' label is an accepted oddity."
    - The plan gives no product reason for why ⌘Q should not quit. The Solution only states (line 11): "Of the app's own controls, only the *Quit Trackpad Launcher* button at the end of the settings window stops it."

36. **The quit mechanism and its reasoning** (decision 7, line 495): "Every ordinary way to quit (the app menu, the Dock icon's menu) exists only while the window is open. So `shouldEnd(.other)` with the window open closes it and refuses; any quit while it is closed ends the app. A logout with the window closed, the usual case, can never be held up, whatever the unprobed signals do. With the window open, three layers apply: `NSSupportsSuddenTermination = YES` lets the system kill instead of asking (F18); `QuitSignals` classifies as `.system` any quit that carries `kAEQuitReason`, comes from `com.apple.loginwindow`, or arrives after `willPowerOffNotification` (F17, F19); and the Quit button goes through `Lifecycle.quit()`, whose `.ending` stage lets AppKit's terminate through. The model never holds a `terminate` closure: `RunningCopies.endThisCopy()` is a port command".
    - Tradeoff (line 1063): "We accept that any quit while the settings window is closed ends the app (AppleScript, Activity Monitor), in exchange for a logout that can never be held up in the common case."
    - Shape sketch `shouldEnd` (lines 735-745): `case .moving: request == .system`. A moving process refuses an ordinary quit and accepts a system quit.

37. **Sudden termination during install: tried, then dropped.**
    - Synthesis (line 1051): "Sudden termination disabled while the install runs (first grafted, then dropped on the test planner's finding): a logout's quit still reaches `shouldEnd`, which ends a moving process (R8), so it protected nothing. The move's order carries the guarantee instead."
    - Dev log line 30: "Test planner: the sudden-termination claim for the install contradicted `shouldEnd(.moving)` → dropped; the move's order carries the guarantee."

38. **Open question 4, still open at plan time** (line 1084): "**Logout with the window open.** Do sudden termination, `kAEQuitReason`, the loginwindow sender and `willPowerOff` behave as assumed (F17-F19)? This needs an end-to-end check before release."
    - Dev log Implement line 55: "Not run (manual: need a real Mac session, logins, a standard account or a Developer ID certificate): C1-C24, except the local unsigned disk-image layout dry run."

### G. The move into /Applications: order, whole-or-nothing, admin script, cancel

39. **Move order, chosen for convergence** (decision 9, `plan.md:499-507`):
    1. "`installer.install`: stage a copy in a temporary folder on the /Applications volume, clear its quarantine, get the administrator's answer when this user cannot write there, then swap it in. That swap is the first change anywhere. Unprivileged it is one atomic replace. With an administrator it is two renames, the old copy moved aside into the staging folder (never left inside /Applications), then the new one in: a kill between them leaves /Applications without the app and the old copy in the staging folder, and the next Move installs again. Cancel → end with nothing changed (R21); failure → the failure dialog."
    2. "`startAtLogin.suspend()`: the item is handed over before the original can go, so a crash leaves it owed, never lost."
    3. "`installer.removeOriginal()`: unless it is on a disk image; a failure leaves it (R19)."
    4. "Stop every other copy, the one that ran from /Applications included (R20), so the next open starts a fresh process."
    5. "`installer.openInstalledCopy()`, passing `--eject-disk-image <volume>` when this copy came from one."
    6. "End. The installed copy is an opening by hand: first run (R5) or `resume()`, and it ejects the disk image once it has stopped the mover (R19)."

    It closes with: "A logout during the move ends the process (`shouldEnd(.system)` is true while moving, R8); the order above is what keeps that safe: before the swap nothing has changed, after it the installed copy is whole and the next opening by hand converges. Only the administrator path's gap between its two renames is not covered, as step 1 says."

40. **The Installer contract: whole or nothing** (`plan.md:631-638`): "Nothing there changes unless the outcome is `.installed`, and never a mix of two copies. Unprivileged, the replace is one atomic step. With an administrator it is two renames, the old copy moved into the staging folder first: a process killed between them leaves /Applications without the app, and the next Move installs again."
    - Dev log line 35: "Test planner: the installer's 'never a mix' promise contradicted the admin path's rename gap, and the aside copy could stay in /Applications → the aside goes into the staging folder; the port doc states the gap."
    - Dev log line 39: "Test planner (second pass): the admin script's failure paths could report `.failed` with /Applications changed → the script moves the aside copy back when the second move fails, and ignores a failed removal of the aside copy."

41. **The admin script** (`PrivilegedInstall` doc, lines 924-930): "The script takes the paths as '$1' (destination), '$2' (staged) and '$3' (aside, inside the staging folder), never interpolated: move an existing destination to the aside path; move the staged copy in, and when that fails move the aside copy back and exit non-zero (`.failed`, /Applications as it was); then remove the aside copy, ignoring a failure there, and exit zero (`.installed`). So a status matches what /Applications holds."
    - S6 brief (line 77): "The script uses `/bin/mv` and `/bin/rm -rf`, quotes every `"$n"`, uses `--` where appropriate, and never builds a command from a path string. Paths are passed as separate argv entries".
    - T38(c) tests paths holding "spaces, `'`, `"` and `$(touch pwned)`" and expects "no `pwned` file exists under the temp root".
    - `Administrator` placement, dev log line 32: "Test planner: `Administrator` had no shape → `run(script:arguments:)` placed below the script, so the real script runs in tests."

42. **Why `AuthorizationExecuteWithPrivileges` and not the public API.**
    - Design Problem (line 375): "The restricted Privileged File Operation entitlement is out (F31); the admin path is `AuthorizationExecuteWithPrivileges` through `dlsym` (F32)."
    - Alternatives (line 1076): "**`NSWorkspace.requestAuthorization(to: .replaceFile)`.** It is the public API, but it needs the Privileged File Operation entitlement Apple grants on request (F31)."
    - Tradeoff (line 1064): "We accept a deprecated `AuthorizationExecuteWithPrivileges`, resolved by `dlsym`, and a gap between the privileged swap's two renames in which /Applications holds no copy (the old one waits in the staging folder), in exchange for a Finder-like administrator prompt with no entitlement and no helper."
    - Dev log line 19: "Grounding: `NSWorkspace.requestAuthorization` needs a restricted entitlement (sourced) → the administrator path uses `AuthorizationExecuteWithPrivileges` through `dlsym`."
    - Grounding F32: "deprecated ('use a launchd-launched helper tool and/or the Service Management framework') but still exported by Security.framework; LetsMove resolves it with `dlsym` … a cancelled prompt is `errAuthorizationCanceled`."
    - S6 brief "Why this API": "`AuthorizationCopyRights(kAuthorizationRightExecute, interaction allowed | extend rights | preauthorize)`".
    - Plan 001 Shape (line 589) gives the base distribution constraint: "hardened runtime, no sandbox, no entitlements".

43. **When the administrator is asked** (S6 brief): "'Not writable' means `FileManager.isWritableFile(atPath:)` false for the /Applications folder, or for the existing destination bundle when there is one (a copy owned by another user/root)."
    - Plan installer TODO (line 897): "if /Applications or destination is not writable by this user".
    - Grounding F36 (probed): "This account is an admin and `/Applications` (root:admin 775) is writable, so the admin-prompt path (R21) cannot be exercised here without a standard account."

44. **Admin cancel stops the app with nothing moved.**
    - R21 (`plan.md:310`): "When the user's account cannot write to /Applications by itself, *Move to Applications* MUST ask for an administrator's name and password the way Finder does. Cancelling MUST stop Trackpad Launcher with nothing moved."
    - The cross-judge found candidate-2 "stopped the running copy before the admin prompt (R21)" (dev log line 24; Synthesis line 1033). That is why stopping other copies comes after the install in the move order.

45. **Quarantine and translocation.**
    - Decision 2 (line 480): "A translocated copy runs from a hidden mount, so it reads `elsewhere` even when its original is in /Applications, and re-installs itself without quarantine."
    - Installer TODO (line 895): "with quarantine cleared on every item (an unquarantined copy is never translocated)".
    - Tradeoff (line 1066): "We accept that a translocated copy sitting in /Applications shows the move dialog, in exchange for it re-installing itself without quarantine instead of running, and registering for login, from a hidden mount."
    - Dev log line 36: "Test planner: `isTranslocated` compared URLs, and a trailing slash would make the installed copy ask to move → stored from macOS; paths compared standardized; `ThisCopy.location(of:…)` as the test handle."
    - Dev log Implement line 46: "S5: quarantine is cleared with `removexattr` per item rather than `quarantinePropertiesKey` (a symlink's own mark, dangling links); `removeOriginal` checks `isDeletableFile` first so a read-only folder never leaves a half-removed bundle."
    - Grounding F34: `SecTranslocate*` is "the only way to find the original location of a translocated (quarantined, not-moved) app."
    - Grounding F38 (open): "Whether a notarised, stapled app opened from a quarantined disk image runs translocated, and whether the Accessibility grant follows a copy that moved or was replaced, are **not** settled."

46. **Which bundle in /Applications gets replaced.**
    - Dev log Implement line 48: "Review: R20 was partial (a copy nested inside /Applications, e.g. Utilities, was not replaced) → the installer searches /Applications at any depth; new T34 case."
    - `fixes.md` item 1: "search `applications` recursively for `.app` bundles whose `CFBundleIdentifier` matches (a `FileManager` enumerator with `.skipsPackageDescendants` and `.skipsHiddenFiles` …), preferring a direct child when there are several; fall back to `applications/<original's name>` when none."

47. **Replace whatever the version** (R20, `plan.md:302`): "The copy being moved MUST replace the one in /Applications whatever their versions, because the user chose that copy."
    - Non-goal (line 359): "**Refusing to downgrade.** Moving an older copy over a newer one replaces it. The user chose that copy (R20)."
    - Relevance to 022: the move has no version comparison by design. The stated reason is user choice.

48. **The move must not spend the first run.**
    - 021 `why.md` Risk 4: "The first-run vs move-to-/Applications ordering could spend the first launch (login registration, Accessibility ask, record save) in the copy that is about to be moved".
    - Plan Shape (line 465): `StartAtLogin`'s fact has "its own `UserDefaults` key beside the `settings` record, never inside it: the mover and the running copy then never write the same record, an older build's save cannot drop the fact (`Settings` ignores unknown keys), and a move never creates or spends a first run".
    - Tradeoff (line 1065): "We accept a second key in the defaults domain, in exchange for each key having one writer and a move never spending a first run."

49. **The mover ends rather than waiting.**
    - Synthesis, rejected from candidate-2 (line 1050): "The mover idling in `.replaced` until the installed copy stops it: it never ends if that copy fails to start."
    - Line 1052: "Deriving the disk image to eject from the stopped peers: it is implicit, and it ejects for any peer on an image. The explicit one-shot argument stays."

50. **Reference flow and how this design departs from it** (grounding F33, from LetsMove): "if the destination copy runs, LetsMove *switches to it and exits* (R20 wants the opposite: replace it); trash the old copy, `copyItem`, delete the original (failure tolerated), relaunch through a `sh` script that waits for the pid, strips `com.apple.quarantine` and `open`s the new copy; detach the disk image 5 s later from `sh`."
    - Plan 021 instead uses a KVO push wait, an explicit eject argument, and has the installed copy eject the image once the mover has exited. No 5 s delay, since timers are banned.

### H. Code-signature classification: release vs development

51. **Decision 2** (`plan.md:480`): "Otherwise `development` when the build is not signed with Developer ID (F7), never `#if DEBUG`, so the perf build is development too (F8)." And: "a build not signed for release reads as `release` when launched with `--as-release-build`; a release build ignores the argument, so it can never make a release copy skip the move dialog."
    - Alternatives (line 1077): "**`#if DEBUG` as the development-build rule.** It is trivial, but it calls the perf build a release, which would then move itself out of its build folder (F8)."
    - Grounding F7 (probed): the Developer ID requirement string "`anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists` is **true** for Developer ID apps (Ghostty, VS Code) and **false** for the Apple-Development-signed TrackpadLauncher … and for an ad-hoc binary".
    - Tradeoff (line 1061): "We accept a development-only `--as-release-build` argument, in exchange for checking the move and the login rules by hand before a Developer ID certificate exists."
    - Dev log line 31: "Test planner: 'development build leaves login alone' broke R5 for a development copy in /Applications, and the release-only paths could not be checked by hand without a Developer ID certificate → any copy inside /Applications is `installed`; a development-only `--as-release-build` argument."
    - Dev log Implement line 45: "S4: `CodeSignature.build(of:)` skips resource validation → a Developer ID app with a broken resource seal still reads release, as `codesign -dvv` reports it."
    - R23 (line 326): "A development build is a build not signed for release, for example one run from Xcode."

52. **"Installed" means anywhere inside /Applications** (Synthesis, line 1043): "'Installed' means anywhere inside /Applications, not directly in it, because R18 asks only about copies outside /Applications. Both candidates had this wrong."
    - Line 1042: "Any copy inside /Applications is `installed` whatever its build, because R5 binds every first run from /Applications (a test-planner finding)."
    - Tradeoff (line 1060): "On a developer's Mac whose first run was such a build, the first run is spent without registering, so the installed copy never registers by itself."

### I. The settings window's per-opening work

53. **Plan 003 R4** (`plans/003-dropdown-recents-performance/plan.md:90`): "The recent section MUST refresh each time the launcher window opens."
    - R6 (line 116): "While nobody uses the picker, Trackpad Launcher MUST do no periodic work to keep it current. It MUST only react when the launcher window opens or apps are installed or removed."
    - Implementation (line 155): scans start on "every `openWindow()` call (R4 'refresh each time the launcher window opens')". "Nothing else starts a scan, and there is no timer (R6)."
    - Dev log Specify line 12: "User review: recents need only be roughly current → recents refresh when the launcher window opens and are kept for instant display".
    - Rejected (line 228): "A live `NSMetadataQuery`: it would wake the app on every app launch anywhere, breaking R6".
    - Relevance: the precedent for work triggered by each window opening with no periodic work. It is carried into 021's `openedByHand()` ("Every time: … rows, scan").

54. **Plan 002 alternative** (`plans/002-gesture-click-blocking/plan.md:1148`): "**Polling `AXIsProcessTrusted`, or re-reading it only when the window opens.** Polling is banned; window-open-only misses R7's 'within 5 seconds' while the window is closed."
    - Relevance: window-open-only refresh was judged acceptable or not depending on whether the requirement bound freshness while the window is closed.

### J. Release and distribution

55. **Plan 001 R23** (line 427): "It MUST be distributed as a direct download, signed with Developer ID and notarized, so it opens without Gatekeeper warnings."
    - Non-goal: "**Mac App Store distribution.** The sandbox does not allow what the app needs to read trackpad touches."
    - Plan 021 R24 (line 333): "Each release MUST be a disk image signed with a Developer ID and notarised by Apple … One command MUST build the release disk image from the repository."
    - Plan 021 release step 5 (line 1003): "Notarise the app as a zip, then staple and validate the app, so a copy dragged out of the image opens offline (F39)."
    - Line 1011: "No `--deep`, no entitlements, the main executable signed last by Xcode (F41)."
    - Non-goal (line 360): "**Getting the Developer ID certificate.** The developer gets it."
    - Dev log Implement line 55: C1-C24 were not run, because they need a Developer ID certificate, a real session, or a standard account.

---

## Indirect / Circumstantial Evidence

- **Plan 021's whole design forbids timers, polling and deadlines.** Design Problem (line 373): "No timers, polling or sleeps (F37). `LauncherCore` imports Foundation and Observation only. Every port has a real and an in-memory adapter."
  - Suggests: any update flow in 022 (download, waiting for the old process to exit, a network timeout) meets the same ban. Plan 021 already accepted an unbounded wait rather than add a deadline (item 28).
  - Alternative reading: a network request's own timeout is a property of the request, not an app timer. The plans never discuss this case.

- **The privileged path was designed and tested on a non-standard-account machine only** (F36). Its manual check C20 is listed as not run (dev log line 55).
  - Suggests: the admin path, including cancel handling, has no end-to-end verification recorded in plans.

- **Several move-related facts were open when plan 021 shipped**: F2 (login marker), F17-F19 (logout signals), F25 (Login Items status), F38 (translocation of a stapled app; whether the Accessibility grant follows a moved or replaced copy), and open questions 5 and 6.
  - Open question 6 (line 1086): "**The Accessibility grant after a move.** Does it follow the copy into /Applications (F38)? If not, the installed copy's later runs only show the hint, because R5 forbids asking again."
  - Suggests: replacing the bundle in /Applications from inside the app (as 022 plans) runs into the same unresolved TCC question.

- **R5 forbids asking for Accessibility again after the first run.** R5 (line 72): "Later runs MUST NOT ask for the permission."
  - Suggests: an update that loses the grant cannot re-prompt under current requirements.

- **Plan 021 Open question 5** (line 1085): "What Background Task Management keys a main-app item by. Path or bundle identifier? The answer decides whether a Finder replace keeps the item (R25), and whether the move's hand-over makes macOS show 'login item added' again."
  - Suggests: an in-place replacement (022) has the same unknown about the login item.

- **The move dialog is the only `runModal`**, confined to `MoveDialogPresenter.swift` (line 1028).
  - Candidate-2 raised an open question (candidate-2.md): "`NSAlert.runModal` for the move dialog: does a peer's `terminate()` reach `applicationShouldTerminate` while the modal loop runs".
  - Plan 021 sidesteps this with `forceTerminate`. Not otherwise resolved in plans.

- **021 grounding `why.md` Preserve 5**: "every new platform dependency (login-item status, single instance, app location/move, activation policy) gets a port with a real and an in-memory adapter (plan 001 task/rubric; plan 002 constraint list)."
  - This is the grounding synthesizer's summary, not a decision.

- **Development builds and the network-free rule.** Plan 021 consistently treats development builds as never doing release-only behaviour (no move dialog; no login registration outside /Applications). The reasons given are R23 and F8 (the perf build).
  - Suggests: a precedent for gating release-only, side-effecting behaviour on `CodeSignature`, not on `#if DEBUG`.

---

## Contradictions

1. **Plan 001 R19 vs plan 021 R12.**
   - Plan 001 R19: "Quitting MUST NOT remove the login item."
   - Plan 021 R12: "Pressing *Quit Trackpad Launcher* MUST turn starting at login off, only if it was on at that moment."
   - Deliberate reversal (021 `why.md` Change 6).

2. **Plan 001 R21 "write nothing to disk of its own except its settings" vs plan 021's move.**
   - Amended on purpose (F37; Docs line 1024). The plan's wording "every file operation of that move is confined to one file" in the slice briefs and docs was then contradicted by the admin script. It was fixed in review by naming two files (dev log line 50; `fixes.md` item 3).

3. **Plan 001's rule "only completed gestures / temp-dir types stay concrete" vs plan 003's async exception.**
   - Plan 003's dev log says the new port "bent the architecture's 'temp-directory types stay concrete' rule silently" before it was written into the doc.

4. **Plan 001 decision "enumerate in `menuNeedsUpdate`, never cache" vs plan 003.**
   - Plan 003 (line 159): "This supersedes plan 001's decision to enumerate in `menuNeedsUpdate` and never cache."

5. **Plan 021 plan text vs implementation.**
   - Quarantine clearing via `quarantinePropertiesKey` (plan line 911, and its confinement row) became `removexattr` per item (dev log line 46).
   - Ports placed in `Lifecycle.swift` (Module map line 969) were moved to `Ports.swift` (`fixes.md` item 7).
   - The installer looked only directly inside /Applications, while the plan said any depth (`fixes.md` item 1).

6. **Candidate-2 vs synthesis on two models.**
   - Candidate-2 argued that splitting lifecycle from `Launcher` needs "a protocol between them that is as wide as the thing it splits".
   - The synthesis chose the split and rejected candidate-2's fold (items 21 and 22).

7. **Sudden termination during the move.** It was grafted, then dropped (Synthesis line 1051; dev log line 30). Candidate-2's open question had proposed disabling it for the install's duration.

8. **Plan 001 R20 "No permissions" vs plan 002 R9.** Replaced on purpose (plan 002 header). This is the precedent for retiring a privacy rule through the source scan's banned → confined move.

---

## Gaps

- Grepped all plans for `network|phones home|update check|auto.?update|Sparkle|self-update|updating itself`. The only hits are plan 001 (Problem, Solution, R21, Non-goal "Automatic updates", the SourcePolicyTests rows, the manual R21 check) and plan 021 (Non-goal "Updating itself"; "read-only network share"; "hung network share"). No plan discusses how an update mechanism would be designed, which network APIs would be acceptable, or what a release feed would look like.
- No plan gives a product reason why ⌘Q and the Dock's Quit should only close the window. The requirement and the dev log only fix the label clash ("Close Settings"). The tradeoff about logout is about mechanism.
- No plan records an incident or bug report that motivated the move into /Applications. Plan 021's problem statement lists two failure modes as reasoning ("its login item points at a file the user later deletes", "macOS runs a quarantined download from a hidden, randomised copy"), with no linked incident.
- No plan records an end-to-end run of the administrator path, translocation, notarisation, logout with the window open, or the Accessibility grant after a move. All are listed as not run (021 dev log line 55).
- No plan dirs exist for 018, 019 or 020.
- Grepped plans 002-017 for `two copies|single.instance|terminate|notari|Developer ID|code.?sign`. Nothing bears on the lifecycle beyond plan 017's KVO `isTerminated` precedent and plan 002's question about TCC clients (line 1163: "Are Debug (Apple Development) and Release (Developer ID) builds separate TCC clients that each need their own grant?").
- Did not read in full: 021 `.temp/architect/grounding/why-plans.md`, `why-source-control.md`, `how*.md`, candidate-1/2, rubric, and the S1-S7 briefs. Their key content is reflected in `index.md`, `why.md` and the plan. A follow-up pass could mine the candidates for more rejected move variants. For example, candidate-2 used a `.<name>.installing` sibling (candidate-2.md:581) where the plan uses the item-replacement directory.

---

## Additional Leads (other sources)

- **Source control:**
  - The PR for plan 021 is likely #28 (current HEAD commit c9125b6 "Trackpad Launcher runs in the background, with a settings window instead of a menu bar icon (#28)"). Review comments may hold rationale beyond the dev log.
  - The review-fix commit for `fixes.md` items 1-13.
- **`docs/architecture.md`:** check the current Privacy and Shape wording against items 13, 15, 16 and 19. It is the authoritative text the 022 change must amend. Not a plans source.
- **`plans/021-background-agent-lifecycle/.temp/architect/checks/same-version-replace/output.txt`** and **`grounding/probes/lifecycle-probe/output.txt`**: the probe outputs behind F4-F6, F15 and F16. These bear directly on "stop the old process and open the new one" after an in-place replace. They are within plans but were not read here.
- **`plans/021-background-agent-lifecycle/.temp/architect/grounding/sources/letsmove-PFMoveApplication.m`**: the reference move flow, including the `sh` relaunch script and the delayed detach that 021 chose not to copy.
