# Why the updater has its current shape

Citation shorthand: `P022` = `plans/022-in-app-updates/plan.md`, `L022` = its `development-logs.md`, `G022` = its `.temp/architect/grounding/`. The same pattern applies to 021, 026, 035, 038 and 039. `M<n>` is a measured-fact row in `why-plans.md`, section 12. PR links are to `github.com/domasgru/trackpad-launcher`.

Requirement numbers are ambiguous across plans. "R13" here always carries its plan: 039 R13 is not 022 R13.

---

### The Question

Why does Trackpad Launcher's updater have its current shape: hand-written check, download and install instead of Sparkle; a check only when the settings window opens; a fixed-header ephemeral request; the "no timers, no polling" rule; the `Lifecycle` and `Updater` ownership split; the new version arriving as an ordinary opening by hand; the single-instance stop-and-wait; the no-`NSSupportsSuddenTermination` rule; and the exchange-based install? The answer feeds plan 039 (Sparkle 2, automatic and silent), so each reason has to become a constraint, not a guess.

### The Code in Question

- `LauncherCore`: `Updater.swift`, `Update.swift`, `Lifecycle.swift`, `Version.swift`.
- `LauncherPlatform`: `ApplicationsUpdater.swift`, `GitHubReleases.swift`, `BundleInstall.swift`, `PrivilegedInstall.swift`, `CodeSignature.swift`, `QuitSignals.swift`, `SystemRunningCopies.swift`.
- `LauncherUI/UpdateCardView.swift`, `Scripts/release.sh`, `project.yml`, and `docs/architecture.md` (Shape, Concurrency, Privacy, Distribution).

The updater landed whole in 9a99471 ([#29](https://github.com/domasgru/trackpad-launcher/pull/29), 2026-11-03). It sits on the background lifecycle from c9125b6 ([#28](https://github.com/domasgru/trackpad-launcher/pull/28)). Later fixes went into `SystemRunningCopies` and `project.yml`; no commit after 9a99471 changed the core updater files.

### What We Found

#### Hand-written updater instead of Sparkle

- **[Direct]** One bullet is the only recorded reason for rejecting Sparkle. Source: `P022:1104`: "**Sparkle.** It brings its own network code outside the scan, dialogs (a non-goal), an appcast to host and XPC installers. It is far wider than the one narrow exception the product owner granted."
- **[Supported]** That rejection was not an investigation. Evidence: the bullet was copied from `candidate-1.md:863`; `candidate-2.md` has 0 hits for "sparkle" (re-checked); no probe tested Sparkle; the `sparkle-project/Sparkle` hits in the 022 probes use that repository only as a public repo with releases; no plan names `SPUUpdater`, a user driver or any Sparkle setting; commit messages, PR bodies, docs and code have no mention of it (`why-source-control.md`, Gaps).
- **[Direct]** The product owner's stance was a narrow exception. Source: `plans/022-in-app-updates/.temp/architect/task.md:15`: "I am against network requests, but the app updates would be exception." The next sentence, "The network exception must stay as narrow as R1-R3 state", is the task author's, not the owner's.
- **[Direct]** Plan 039 chooses Sparkle by the user's decision, and that choice is out of scope for reopening. Source: `L039:12`: "Not taken: moving the Sparkle choice out of the Solution, because the user chose it and planning needs it."
- **[Direct]** Updating was absent before 022 because of the no-network promise, deferred as a product decision. Sources: `plans/001-trackpad-launcher-app/plan.md:448` ("Update checks are network calls; the app makes none."); `P021:350` ("Changing that is its own product decision and a later feature."); `001:9` ("One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled.").

#### A check only when the settings window opens

- **[Direct]** The stated reason is the card, not privacy as such. Source: `P022:212`: "The card shows only in the settings window, so a check at any other time would make network requests for nothing a user can see."
- **[Direct]** Installing without a press was excluded on the principle of user control. Source: `P022:217`: "The user decides when the app replaces itself."
- **[Direct]** The missing off switch leaned on the same trigger. Source: `P022:214`: "The check runs only when the user opens the settings window, and reads only the public release list."
- **[Direct]** The opening edge lives in `Launcher` as the holder of window state. Source: `P022:363`.

#### The fixed-header ephemeral request

- **[Direct]** Purpose: the request identifies nobody. Sources: [#29](https://github.com/domasgru/trackpad-launcher/pull/29) body ("The request carries nothing that identifies the user, the Mac or the versions."); `P022:61` (address, set headers and body "MUST be the same on every Mac and every version").
- **[Direct]** The fixed headers exist because the defaults leak and GitHub requires a User-Agent. Source: `P022:237`: "GitHub refuses a request without a User-Agent. URLSession's defaults reveal the Darwin version and the user's languages." Measured in M41-M45.
- **[Direct]** Other request details each have a stated reason. Sources: `P022:388` (`waitsForConnectivity = false`, offline fails at once); `P022:391` (pinning the API version keeps every shipped version parsing the same JSON); `GitHubReleases.swift:39-42` and `P022:394` (in memory, so a cancel, quit, crash or logout leaves nothing on disk).
- **[Direct]** Constancy covers stored state too. Source: `GitHubReleasesTests.swift:103` (`everyCheckSendsTheSameConstantRequestAndStoresNothingTheServerOffers`) asserts no `cookie`, `if-none-match` or `if-modified-since`.

#### "No timers, no polling"

- **[Direct]** The rule predates the updater by 25 days, and its stated motive is idle CPU. Source: `1cf9c4b:docs/architecture.md`: "This is what keeps idle CPU at zero." The requirement behind it allows slightly more than zero: 001 R22 (`001:420`) says "0% CPU in Activity Monitor, with at most one momentary blip per minute."
- **[Direct]** Plan 002 kept timers banned when it revoked a sibling requirement. Source: `plans/002-gesture-click-blocking/development-logs.md:20`.
- **[Direct]** The updater was fitted to the rule with one carve-out. Source: `P022:1088`: "We accept a request's own idle timeout as the one deadline that is not a Core Animation animation, in exchange for the app having no timer of its own."
- **[Direct]** The rule has a real cost that was knowingly accepted. Source: `P021:1062`: a copy that survives `forceTerminate()` leaves the opened copy waiting, "in exchange for no deadline (timers are banned)".
- **[Direct]** Time is modelled as an effect's own animation. Sources: `docs/architecture.md:20` ("a deadline is an animation on a layer of the effect it belongs to ... it cannot outlive that effect"); `plans/017`'s accepted cost at `:1147` ("time borrowed from the render server's clock, which may stretch across display sleep"). Quoted from `why-plans.md`, not re-read.

#### `Lifecycle` and `Updater` ownership

- **[Direct]** `Updater` is one deep model, a peer of the other two, so that one state machine is not split by phase. Sources: `P022:354`; `P022:1095-1097` (rejected: install as a `Lifecycle` stage, "temporal decomposition"; fold into `Launcher`, "exactly what the plan 021 split prevents"; a port per step, "a shallow interface").
- **[Direct]** The object's existence is the network gate. Sources: `P022:381`; `P022:249` ("no path to the network"); the `makeUpdater` comment in `TrackpadLauncherApp.swift` ("`developerIDSigner()` takes no arguments, so `--as-release-build` cannot fake it").
- **[Direct]** The gate became pure so that tests can reach it. Source: `L022:27` ("the R1/R2 gate lived in the untested app target").
- **[Direct]** System quits always win, mid-install too. Source: `Lifecycle.swift:208-217` comment, "Logout, restart and shutdown always end, mid-install too."
- **[Direct]** Version information is read once. Source: `Update.swift:30-31` and `P022:349`: "after the swap, `Bundle.main` would read the new bundle". M36 measured an old process with mixed views after a swap.

#### The new version as an ordinary opening by hand

- **[Direct]** Decision: reuse the existing route. Source: `P022:247`, `P022:420`.
- **[Direct]** Grounding reason: no second hand-over path and no protocol between versions. Source: `G022/why.md:210-211` ("Do not add a separate handover path"; "Add no quit handshake between versions"). This is advice to 022 that the plan followed, marked in that file as reasoning from 021.
- **[Direct]** The old copy ends itself only after LaunchServices reports the new one started, and this order is deliberate. Sources: `P022:1059`; `P035:39` ("a copy that waited to be stopped would never end if the new one failed to start, and gestures keep working until the swap").
- **[Direct]** The accepted cost of that order. Source: `P022:1082`: a new version that dies leaves no Trackpad Launcher running until the next opening or login.
- **[Direct]** `createsNewApplicationInstance` guards a concrete failure. Source: `ApplicationsUpdater.swift:68`: "By default the old process, whose bundle was just replaced, only gets a reopen." M6 measured it; `L022:26` calls it "load-bearing".
- **[Direct]** "By hand" is not a positive signal; it is whatever lacks the login marker. Sources: `G022/how-lifecycle.md:64`; `G022/index.md` E6 ("No argument says 'open your window': `.byHand` + `.installed` does.").

#### Single-instance stop-and-wait

- **[Direct]** Origin: two builds fighting. Source: `L021:5`: "Dragging a new build over a running one, or upgrading from the menu bar version, left two builds fighting → new R3". Requirement: at most one copy recognises gestures (021 R2).
- **[Direct]** Force, not a request, so no protocol binds versions. Sources: `P021:482`; `P021:1073` (rejecting a quit event: it "exposes a sender-pid protocol to every future version ... and leaves the new copy waiting forever on a refusing or hung copy, with no timeout allowed").
- **[Direct]** Debug and release are one family, so only one reacts to gestures. Sources: `P026` R2; [#32](https://github.com/domasgru/trackpad-launcher/pull/32).
- **[Direct]** The wait crashed in production: [#40](https://github.com/domasgru/trackpad-launcher/pull/40) and `P035:9-15` (the new copy died in 15 of 15 rounds; eight local crash reports across 1.0.0 to 1.0.10).
- **[Direct]** The wait then hung: [#43](https://github.com/domasgru/trackpad-launcher/pull/43), e8be794 (`isTerminated` KVO never fired on a busy machine, "and the caller has no timeout"), fixed with a process source.

#### No `NSSupportsSuddenTermination`

- **[Direct]** The cause is specific and reproduced. Sources: `P038:7`; [#44](https://github.com/domasgru/trackpad-launcher/pull/44) ("0 of 5 alive before, 5 of 5 alive after"); M13-M17. LaunchServices records the new process as a child of the old; when a foreground-type app ends, loginwindow force-quits, 3 s later, a child that is a UI element with no visible window and declares sudden termination.
- **[Direct]** The opened copy's own declaration decides. Sources: `P038:18`; `docs/architecture.md:11`. This also protects the first update from a version that still declares the key.
- **[Direct]** The key was originally a logout-safety layer, not an oversight. Source: `P021:495` ("lets the system kill instead of asking"). Its commit (acc137d) gives no reason, but the plan does.
- **[Direct]** Automatic updates were named as this fix's dependent, with an open question handed to this plan. Source: `P038:54`: "They come next, and this is their prerequisite. A silent update's new copy never opens a window, so it stays a UI element without one, and loginwindow says it schedules future checks for such a child 'to see if we need to alert about it'. That is an alert, not a termination, and it did nothing within the 75 s watched here; that feature's own plan must look at it."
- **[Direct]** The move depends on the same rule, with no code of its own. Source: `P038:53`.
- **[Direct]** A helper, a watchdog and catching SIGTERM were rejected for this bug. Sources: `P038:51-52`.

#### The exchange-based install

- **[Direct]** Requirement: a restart mid-replace leaves a whole version. Sources: `P022:198-200`; `P022:236` ("two renames, a gap R13's restart scenario does not allow").
- **[Direct]** `RENAME_SWAP` replaced `replaceItemAt` on the unprivileged path for its contract. Source: a18fcbd: "atomic by contract, rather than relying on how FileManager.replaceItemAt does it."
- **[Direct]** The administrator path uses `osascript` because no stock tool exchanges directories. Sources: `G022/index.md` R-5; `P022:1084`. The same change closed the two-rename gap for the move (8e1acf0).
- **[Direct]** Order: unpack, verify, swap, open, end. The swap is the first change anywhere, so the prompt comes after verification. Sources: `ApplicationsUpdater.swift:4-8`; `P022:413,417`.
- **[Direct]** Other copies are stopped only after the install, so that a cancelled prompt changes nothing. Source: `L021:24`.
- **[Direct]** `.aar` beat DMG and zip for having no child process. Source: `P022:1099-1102`.

#### The release contract (bears on every option above)

- **[Direct]** The author predicted this constraint. Source: [#29](https://github.com/domasgru/trackpad-launcher/pull/29), Merge Danger: "once a release with the updater ships, users' installed copies will check GitHub Releases, so the published release format becomes a contract to keep." Reinforced at `P022:1086` ("a permanent contract with every shipped version") and `docs/architecture.md:36`.
- **[Direct]** 16 releases carry the hand-written check, v1.0.0 to v1.0.15 (`gh release list`, re-checked for the newest four).

### What We Can Reasonably Infer

- **[Inferred]** The window trigger's stated reason appears to lose its premise under 039. Reasoning: `P022:212` rests on the card being the only place a result can show. 039 R15 removes the card, and 039 R1 says the check "MUST NOT depend on the settings window". The trust argument behind the narrow exception (`001:9`) does not disappear; 039 reaffirms it through R2, R3 and R12.
- **[Inferred]** 022's no-off-switch reasoning does not carry over. Reasoning: `P022:214` justified it by the check being user-triggered. 039's non-goal gives a different reason ("The user chose no update interface at all"). That is a valid product choice, but it is a new one.
- **[Inferred]** The "no timers" rule is not about the updater, so replacing the updater does not retire it. Reasoning: it is 25 days older, it serves idle CPU, and its plan 002 and 003 reaffirmations are unrelated to updates. A timer inside Sparkle's binary would pass the scan, but the docs' wording, "No timers, no polling, no background loops", has no such exception.
- **[Inferred]** The hand-over is likely the riskiest moment in this code. Reasoning: #40, #43 and #44 all fell on it within three days of first release, and `P022:1115` had flagged it as unproven. The 022 probes used ad-hoc bundles in /tmp.
- **[Inferred]** Fakes and field-shape stand-ins both hid these bugs, so a Sparkle relaunch likely needs an end-to-end check in a live login session. Reasoning: `P035:17` and `P038:22` say no test could have caught them; `P038:20` says 035's repro missed the bug because its old copy never showed a window.
- **[Inferred]** Older copies' pipeline tolerates extra assets, and appears to tolerate a framework's symlinks, on reading the code. Reasoning: `GitHubReleases.parse` takes the first asset matching the `.aar` name and ignores the rest; `BundleInstall.admits` accepts relative symlinks that stay inside the bundle; `isGenuine` already passes `kSecCSCheckNestedCode`. None of this has run against a bundle holding a framework.
- **[Inferred]** The 022 Sparkle objections divide unevenly under 039. Reasoning: "far wider than the exception" is overruled by the owner's choice. "Dialogs" becomes an implementation demand, since 039 R15 and R9 are stricter than 022. "Network code outside the scan" and "XPC installers" remain true facts to deal with. "An appcast to host" becomes new release work. The mapping is this document's and is not stated in a plan.

### Competing Hypotheses

**How much weight should the Sparkle rejection carry?**

- **Hypothesis A:** a considered technical judgement.
  - **Evidence for:** four concrete technical reasons in `P022:1104`.
  - **Evidence against or missing:** no probe, one candidate only, no mention in `candidate-2.md`, `task.md`, `rubric.md` or `L022`.
- **Hypothesis B:** a scope judgement, with the technical items as supporting colour.
  - **Evidence for:** the closing sentence is about the narrow exception; the requirements left no room for automatic behaviour.
  - **Evidence against or missing:** no text weighs the reasons. Either way the technical items should be checked, not dismissed.

**What does the "no child processes" ban protect?**

- **Hypothesis A:** closing network escape hatches.
  - **Evidence for:** added in 9a99471 as `URLSession` was loosened; listed in `theNetworkBansAreAllStillListed`.
  - **Evidence against or missing:** no text states this purpose.
- **Hypothesis B:** a general stance against helper processes.
  - **Evidence for:** `P038:51` cites it against a helper: "the source policy bans child processes." DMG and zip lost to `.aar` partly for needing one (`P022:1099-1102`).
  - **Evidence against or missing:** `PrivilegedInstall` runs `/bin/sh` through `AuthorizationExecuteWithPrivileges`, confined rather than banned.

This matters for 039: under A, Sparkle's installer processes are outside the rule's concern unless they make network calls; under B, the rule needs an explicit amendment.

**Would Sparkle avoid the hand-over bugs?**

- **Hypothesis A:** the bugs are specific to the old process calling `NSWorkspace.openApplication`.
  - **Evidence for:** `P038:7` names that call as what creates the parent link.
  - **Evidence against or missing:** the parent link is reasoned from the unified log (M7), not read directly; a relaunch by a helper is unmeasured.
- **Hypothesis B:** the bugs are inherent to two copies overlapping or to a windowless first moment.
  - **Evidence for:** `P035:7` ties the crash to the old copy being alive at `stop`; `P038:54` says the silent case stays a UI element without a window.
  - **Evidence against or missing:** nothing measured a silent new copy, or an opener other than the old app.

**Why does the check run at window open?**

- **Hypothesis A:** the card's visibility (stated, `P022:212`).
- **Hypothesis B:** habit of the codebase. Plan 003 ties refreshes to window opening with "no periodic work" (`G022/why.md` calls this a fit, marked inferred); `P022` does not cite it.
- **Evidence missing:** whether either weighed the cost of users who never open settings. 039's Problem statement names that cost; 022 recorded it as the problem but not as an accepted cost of the trigger.

#### Contradictions in the record

1. **`P022:414` versus shipped code.** The plan says `BundleInstall.swap` uses `replaceItemAt`; a18fcbd moved it to `renamex_np`. The plan is stale. The shipped `PrivilegedInstall.exchange` still uses Foundation's call as root. The docs present both as "one atomic exchange", but they rest on different guarantees.
2. **"At every moment" versus "for a moment".** `docs/domain-model.md` and 039 R11 say /Applications always holds a whole version. a18fcbd says a lookup racing the bare syscall "can find no entry for a moment". Earlier, M35 measured 0 misses in 1500 rounds of `replaceItemAt`. The on-disk state and observed lookups differ, and 039 R11 inherits the wording.
3. **`docs/architecture.md:11` versus `L038:15`.** The doc says a logout "reaches the app as the quit event, which `Lifecycle` answers at once." The log says "PENDING HUMAN CHECK (R2), NOT DONE". #44 said "Run it before releasing"; 1.0.14 and 1.0.15 shipped; no record shows it ran.
4. **Sudden termination's two roles.** It was a safety layer (`P021:495`), then the cause (`P038:7`). `P038:68`: "With the key, the kill made that unknown harmless; this fix removes the kill."
5. **`Ports.swift:170` "nor hang the stop" versus #43.** The wait did hang. It now has a kernel source, but still has no deadline.
6. **Who ends the old copy.** `docs/domain-model.md` says the update "stops the old one". Code and `P022:1059` have the old copy end itself, and the new one stops anything left. The two race (`P035:7`). `G022/index.md` R-4 predates this.
7. **Earlier non-goals versus 039.** `001:448`, `P021:350`, `P022:212,217` and `P022:445` ("retry, poll") all oppose 039. These are deliberate product reversals, not errors.
8. **The no-timer rule versus 039 R1 and R8.** Clock-time checks across sleep contradict the "cannot outlive that effect" model and `017:1147`. No plan reconciles them.
9. **Stale PR #29 body.** It says "as a draft GitHub release" and that fixtures are pending; 7568ec7 and 0d54e01 in the same PR changed both. Trust the commits.

### What We Don't Know

- **Sparkle's fit.** We grepped `plans/`, `docs/`, code and all commit messages and diffs for `sparkle`, plus `SPU`, `appcast` and `EdDSA`. No record covers Sparkle's request headers or system profile, its relaunch mechanism, whether the old process must exit before the swap, how it handles failure, how it swaps, what it logs, or which version key it compares. Nothing here says it fails any of these; they are simply unmeasured.
- **Whether grants and the login item survive a real replace.** `P022:1108-1109` left both open. `L022:52` lists C6 as not run. A regex search across plans found no later result. M26 proves the designated requirement, not TCC. Real updates have happened (`P038:12`), with nothing recorded either way.
- **Whether the real logout check ran.** `git log --grep=logout` is empty, and no plan records it. No one in this repo has observed a real loginwindow quit event's attributes (M25).
- **The fate of a silent new copy.** `P038:54` is the only text, based on 75 s, on a child that in that run was logged as windowless at the old copy's death. The "alert" is one log line, never observed as an alert.
- **Hand-over from a window-closed old copy.** Measured: a window-open old copy, and a never-foreground one (M18). Not measured: one that showed a window earlier and closed it. This is 039 R8's normal state.
- **Parent link for a helper or launchd start,** or for an opener running after the old process has gone. All measurements have the old app call `openApplication`.
- **How a silent start is signalled.** No plan defines a start that is neither `.atLogin` nor window-opening. `activates = false` appears in none of P022, P035, P038 or 039.
- **What a Sparkle-sent quit looks like to `QuitSignals`.** Plain quits read as `.other` (M22, M23). No probe covers an installer's.
- **App Nap for a windowless resident over hours.** `P032:387` flags it for 2 s deadlines only.
- **How standard-account writability is detected** for 039 R12 under Sparkle.
- **Why GitHub Releases was chosen as host,** and the size of the installed base running pre-1.0.14 copies. No telemetry exists, by design.
- **Whether the administrator path has run as root at update time.** `P022:1283`, `L022:52` and #29's Blast Radius leave it unverified. It still matters to the move.
- **Review discussion.** PRs #28, #29, #32, #40, #42, #43 and #44 have no comments or reviews, and the repository has no issues. The original reasoning exists only in plans. The unified-log extracts behind M13, M17, M19 and M20 were not saved, so they survive only as prose.
- **People who would know:** domasgru, for product intent, and for whether the logout, TCC and login-item checks happened informally.

### Sources Consulted

- **Source control history:** `git log` across the updater file set (about 120 commits scanned), pickaxe searches, diffs of 9a99471, c9125b6, d5b2201, e8be794, 8e1acf0, a18fcbd, 7568ec7 and 4d1d892; PRs #28, #29, #32, #40, #42, #43, #44; issues; releases; code comments and tests. Re-checked for this synthesis: all listed commits exist, the a18fcbd and e00ce47 messages, the #44 "Not yet verified" text, `gh release list`, `BundleInstall`, `GitHubReleases`, `QuitSignals`, `Updater`, `Lifecycle` routes and `shouldEnd`, `CodeSignature.isGenuine`, the `SourcePolicyTests` rows and `Config/Version.xcconfig`.
- **Plans:** 039, 022 (plan, log, candidates, grounding, all probe outputs), 021, 026, 035, 038, with grep hits in 001, 002, 003, 017, 032. Queries included `sparkle`, `SPU`, `sudden|loginwindow`, timer tokens and a grant-survival regex. Re-read by this synthesis: `P022:212,214,217,445,1059,1082,1084,1086-1088,1104,1108-1109,1115`; `P038` root cause, non-goals and the logout gap; `L038:15`; `P035:39`; `P021:350,482,495,1051,1062,1073`; `001:9,420,448`; `task.md:15`; `G022/why.md:204-255`; all of `039/plan.md`.
- **Branch note:** this branch is two commits behind `origin/main`, which adds #45 (settings window design, touching `SettingsView.swift`, `docs/architecture.md` and `docs/domain-model.md`) and Version 1.0.15. `git diff` shows no change to the updater source files. Line numbers here are for this branch.
- **Not used:** `research/`; external Sparkle documentation. Questions about Sparkle below are questions, not findings.

### Confidence Summary

> The reasons for the sudden-termination rule, the exchange install, the hand-over order, stop-and-wait, the ownership split and the request's privacy shape are well documented and largely measured, so those constraints can be relied on. The "why not Sparkle" rationale is a single unprobed bullet, and it should be read as a list of things to check, not a verdict. The most important unknowns are empirical, not historical: nothing has measured a silent new copy, a window-closed hand-over, a real logout quit, or TCC and login-item survival, and 039 R9, R10 and R14 rest on them.

---

## Constraint set for plan 039 (automatic updates)

Each item names what bears on it. "Unknown" means the record does not settle it. Probes are listed under Risk.

### Preserve

1. **At most one copy recognises gestures, and a new copy stops others by force without asking** (021 R2; `P021:482,1056,1073`; `P026` R2; 039 R9). Debug and release stay one family. The kernel process source from e8be794 stays, since #40 and #43 are the two failures it replaced.
2. **No `NSSupportsSuddenTermination`, in key or API form.** The `banned` and `neverDeclared` rows must survive deleting `ApplicationsUpdater`: the move depends on them (`P038:53`). Reword the rule's text if it names only updates; do not drop it.
3. **The `.byHand` + `.installed` route, stopping others and opening the window.** Older copies deliver the first automatic version through it (039 R16), and it is what 039 R9's "Opening by hand afterwards" scenario expects. Silent start is an addition, not a replacement.
4. **The release contract, for as long as older copies may exist** (`P022:1086`; 039 R16; `docs/architecture.md:36`). Every release keeps all of: tag and repository path; a non-draft, non-prerelease GitHub release; an `uploaded` asset under `downloadsPrefix` named `TrackpadLauncher-<v>-macOS-<min>.aar`; exactly the one bundle `TrackpadLauncher.app` inside; a stapled ticket; the same team and identifier; a sealed Info.plist matching the asset name's version and minimum macOS. Only the 30 newest releases are visible to those copies (`P022:1087`).
5. **Every 039 R3 property, proven on the wire.** No query string, no cookie, no version or OS in any header, the same headers on every Mac and version, across the redirect, with no conditional-request state (`GitHubReleasesTests.swift:103` pins this today). A framework's defaults are not assumed safe: the 022 finding was that URLSession's own defaults leak (`P022:237`).
6. **The gate as an object's absence.** No updater object, and so no network path, without the Developer ID signature and /Applications placement (`P022:249,381`), decided by something `--as-release-build` cannot fake (`P022:234`), pure and tested (`L022:27`). 039 R2 and R12 extend this; they do not replace it. Debug and perf builds may link Sparkle, but they must never start it.
7. **One owner for update decisions.** `Launcher` stays ignorant of versions and quit policy (`P022:1096`); no decision lives in the untested app target (`L022:27`); `Lifecycle` keeps its one exhaustive quit switch. Any Sparkle use goes behind a port with an in-memory adapter (`docs/architecture.md`, "Every port has exactly two adapters"), unless the design deletes `Updater` outright and says so.
8. **System quits always end** (`Lifecycle.swift`, "mid-install too"; 039 R14).
9. **Whole-bundle outcome in /Applications** (039 R11). For the move, keep `BundleInstall.swap`, `RENAME_SWAP`, `PrivilegedInstall` and their confinement rows. `BundleInstall` is shared; only `unpack`, `extract`, `admits` and `MemoryStream` are update-only. Note contradiction 2 when writing the requirement's proof.
10. **Same identity, same path.** The same identifier, team and installed path, no login-item call, no first-run, no permission ask, the same defaults domain (`P022:423-429`; `UpdateInstallTests.swift:46-96`). An update goes over the installed copy "whatever it is named" (`docs/architecture.md:36`).
11. **Idle CPU as a measured outcome** (001 R22; `docs/product-overview.md`). No finger down means 0%, with at most one momentary blip per minute. Sparkle's work counts, wherever it lives.
12. **Quit semantics.** *Quit Trackpad Launcher* turns login off and stays final (039 R13). Automated termination must not go through `quit()`, or it would turn off starting at login.
13. **Nothing-half-published releases.** Assets are uploaded before publishing, and published releases are immutable (7568ec7; README). Any update feed must follow the same order, and its failure must stop the release.
14. **The "no logging" promise** (039:13 keeps it). The scan cannot see a framework's logging, so this needs a decision and a check.

### Change (legitimately)

1. **The window-only check becomes 039 R1.** Its premise goes with the card. `UpdateCheckTests` encodes the old rule and needs rewriting, not patching. `P022:445`'s refusal of retries is reversed by 039 R1 and R5.
2. **"The user decides when the app replaces itself" is reversed** by owner decision. Record it as a reversal in the docs. `README.md:71` ("never in the background"), `docs/product-overview.md` and domain-model's "The one request" all become false.
3. **Sparkle replaces the hand-written path, and the 022 objection list becomes work items:** network code outside the scan needs a wire proof (Preserve 5); dialogs need no-interface behaviour proven (039 R9, R15); the appcast needs a home on GitHub and a release step; XPC installers need an assessment against "hardened runtime, no entitlements" and the child-process rule.
4. **The no-timer rule gets an explicit, reasoned amendment,** following the pattern at `G022/why.md:212-216`: amended on purpose, not bypassed. The 24 hours (039 R1) and the 1 minute (039 R8) need a named place. Decide which side owns them and write the exception into `docs/architecture.md:20`, whichever way the design goes. The scan bans `Timer`, `asyncAfter` and `Task.sleep` in shipped Swift, comments included.
5. **The scan's confinement rows are rewritten.** If all network code leaves the repo's Swift, `URLSession` and `http` have no home file. One option is returning to a blanket ban, which would be stricter than today. Confining Sparkle's import to one file is the natural analogue. Keep `theNetworkBansAreAllStillListed`.
6. **The in-memory download goes, if the design persists it.** Its reason was that a cancel, quit, crash or logout leaves nothing on disk (`P022:394`). 039 R8 allows an update to wait across a start, so this is a real change. The `downloadTask` and `.download(` rows and the architecture's list of files written need updating to match.
7. **A new way to start silently.** 039 R9 needs a start that is not `.atLogin` and does not open the window. `Opening` has only two cases, and anything without the login marker is `.byHand`. The mover's explicit one-shot argument is the only precedent (`P021:504,1052`). Every other opening must still reach `.byHand`.
8. **`Lifecycle`'s install guards are reversed.** Today `quit()` refuses while `isInstalling`, and `shouldEnd` holds an `.other` quit. 039 R13 requires Quit "at once, in any update state". A quit event from an installer also reads as `.other` (M22), so a still-true `isInstalling` could refuse it.
9. **The administrator path leaves updates** (039 R12), and stays for the move. A cancelled prompt no longer exists for updates.
10. **Genuineness.** Today it pins team, identifier, notarisation and the exact offered version, read offline. 039 R6 adds the update key and names team and identifier; 039 R7 moves notarisation to the release process. Say explicitly whether the install-time notarisation check is being dropped or kept. Older copies keep enforcing it regardless.

### Avoid

1. **Treating the scan as evidence about Sparkle.** `scannedRoots` covers this repo's `.swift` sources only; a binary framework is unscanned (`P022:1104` says so in its own terms).
2. **A quit handshake or any version-to-version protocol** (`P021:1073`). It binds future versions, which is the opposite of what 039 R16 already costs.
3. **Posing as a login start.** `Route` is `(.atLogin, _, true) -> .end`: a new copy claiming to be a login start while the old one runs would end itself.
4. **Reintroducing sudden termination, or adding a watchdog, a SIGTERM handler or a relauncher** to fix a hand-over symptom (`P038:52`).
5. **A shell relauncher with sleeps or pid polling** (`G022/why.md:239`; `P021`).
6. **Stopping the running copy before the update is verified** (`L021:24`; `G022/why.md:240`).
7. **Carrying `createsNewApplicationInstance` assumptions to another opener.** It was measured for self-open (M6). Another process needs no such option in M5, but that was with the old copy still alive.
8. **Citing `docs/architecture.md:11`'s "answers at once" as verified** (contradiction 3), or `P022:414` and the #29 body for current mechanics (contradictions 1, 9).
9. **`#if DEBUG` as the gate** (`G022/why.md:242`), and `--deep` signing (`docs/architecture.md:35`; `release.sh:15-16`).
10. **A second asset matching the `.aar` name pattern in a release.** "The first such asset counts" (`GitHubReleases.swift:120-123`).
11. **Assuming "no update interface" follows from setting Sparkle's options.** No plan tested it, and 039 R9 and R15 allow no dialog, Dock icon or focus change, on success or on failure.

### Risk

Listed in order of consequence. Each is a probe or a check for the 039 planner.

1. **The real logout.** 039 R14 rests on `QuitSignals` reading a loginwindow quit as `.system`, unobserved in this repo (M25; `P038:68`; `L038:15`). If it fails with the window open, the app cancels a logout. This is in shipped 1.0.14 and later today, regardless of Sparkle. Run the pending check first.
2. **A silent new copy with no window** (`P038:54`). 039 R9's normal state, watched for 75 s at most, on a different shape of run. Probe with a Developer ID, notarised build in /Applications, for well beyond 75 s, on the live login session, and look for any alert.
3. **A window-closed old copy at hand-over.** Unmeasured (see gaps). `plans/038-post-update-force-quit/old-copy.swift` hands over from an open window, so neither existing repro stands in for 039 R8's case without changes.
4. **TCC and the login item across a real replace** (`P022:1108-1109`; M27 shows a stored-requirement mismatch looks "already on"). 039 R10 needs a recorded measurement. A loss would be invisible: no re-ask (`M30`), no card, no log.
5. **Failure recovery order.** Today, gestures run until the swap and the old copy ends only after the new one has started (`P035:39`). 039 R11 needs a working copy within 10 s after a failed install. Unknown: whether Sparkle exits the old process first, what happens if its installer dies, and who restarts the app. `P022:1082`'s accepted cost (nothing running if the new copy dies) gets worse with nobody watching.
6. **039 R3 on the wire.** Unknown what Sparkle sends by default: User-Agent, system profile, cache validators, cookie store across GitHub's redirect.
7. **Field diagnosis is gone.** #40 and #44 were found by a user seeing failure and by local crash reports and loginwindow's log. Under 039 failures are invisible (Non-goals), there is no logging, and there is no card to fall back on. A release that breaks its own update path may strand copies with no signal. With no rollback and no staged rollout (Non-goals) every copy takes each release, and the record shows 16 releases in four days (inferred risk).
8. **Quit finality with an update waiting** (039 R13). Unknown whether Sparkle installs or relaunches at app exit. A pressed Quit must leave nothing that starts the app again, and login must stay off.
9. **Older copies installing the first Sparkle build.** Strict nested-code validation and `admits` have never seen a framework in this bundle. The first Sparkle build should go through `Scripts/release.sh --archive-only`, and a real older copy, before release. `P022:1099`'s `aa` probes did not cover it.
10. **Time.** App Nap on a windowless resident (`P032:387`), 24 h across sleep, a network-arrival trigger (039 R1) as a push, and a per-touch 1-minute deadline (039 R8), which must not cost idle CPU. 017's and 032's clocks are short-lived and may stretch across sleep.
11. **Signing.** "Hardened runtime, no entitlements" and "main executable signed last" have never met nested third-party helpers (`docs/architecture.md:35`). MultitouchSupport needs no library-validation exception because it is Apple-signed; Sparkle is not.
12. **The update key.** 039 R6 adds a secret, and `Scripts/release.sh` runs on one developer Mac. No plan covers storage, rotation or loss (inferred from the release flow; no source discusses it).
13. **Version comparison.** Today only `CFBundleShortVersionString` is compared, through `Version`. The build number exists and "only ever goes up" (`Config/Version.xcconfig`). Confirm which one Sparkle compares and that it matches `Version`'s rules (039 R4). The feed must also express pre-release and minimum macOS.
14. **Bundle name.** Copies are installed as either `TrackpadLauncher.app` or `Trackpad Launcher.app` (7107c6f). The archive's internal name must not rename an installed copy, given Preserve 10.
15. **By-hand opening during an install.** A user opening the app mid-install, with the old copy gone or going, is unmeasured against 039 R11. So is an old copy `forceTerminate`d by a Debug build (`family(of:)`) in that window.
16. **Tests that cannot see it.** `InMemoryRunningCopies` hid #40 (`P035:17`), and `P038:100` says loginwindow's verdict is not provable by a unit test. A Sparkle path needs end-to-end checks on a notarised build, separate from the unit suite.
