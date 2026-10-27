# Why: Trackpad Launcher's lifecycle shell

### The Question

Why does the lifecycle shell look the way it does? That covers the LSUIElement menu bar app with a status item; the non-activating `NSPanel` under the icon that closes on resignKey and on a global outside-click monitor, with `.heldOpen` and `dismissWindow` vs `closeWindow`; Quit in the icon's right-click menu (#25); Accessibility asked on first launch only; login-item registration on first launch only, derived from "no settings record"; Other… as a free-standing `NSOpenPanel` with close/activate/reopen; gestures, swipes and swaps closing the window; and Trackpad Launcher never counting as frontmost or running. And what must plan 021 (background app, titled settings window, Dock icon only while it is open, single instance, Quit that turns login start off, move-to-/Applications, notarised DMG) preserve, change or avoid?

**Correction to the question's premise.** The question assumed there is no login-item registration in code. That is wrong. `WorkspaceActions.registerLoginItem()` calls `try? SMAppService.mainApp.register()` (`LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:88-91`). `Launcher.start()` calls it on first launch, before the first save (`LauncherKit/Sources/LauncherCore/Launcher.swift:105-113`). It has been there since PR #1 (1cf9c4b) and is tested in PersistenceTests. What is missing is any unregister call, any UI toggle, and any link to Quit.

### The Code in Question

- `TrackpadLauncher/TrackpadLauncherApp.swift`: the composition root. It has no `NSApplicationDelegate`. It creates `MenuBarShell`, then calls `launcher.start()`, shows the animation tuner in DEBUG, and runs inside `withExtendedLifetime(shell) { application.run() }`.
- `LauncherKit/Sources/LauncherUI/MenuBarShell.swift`: the status item, right-click Quit, the resignKey and global mouse-down dismissal, and the Other… `NSOpenPanel` flow.
- `LauncherKit/Sources/LauncherUI/LauncherPanel.swift`: `[.borderless, .nonactivatingPanel]`, `.popUpMenu` level, `hidesOnDeactivate = false`.
- `LauncherKit/Sources/LauncherCore/Launcher.swift`: `Window { closed, open, heldOpen }`, the first-launch branch, and the fire/swipe/swap paths that set `window = .closed`.
- `Settings.swift` (first launch means no record), `WorkspaceActions.swift`, the own-pid filters in `RunningAppsReader`/`LaunchServicesOrder`/`FrontmostAppWindows`, `SourcePolicyTests.swift`, `project.yml:39` (`LSUIElement: true`), and `Scripts/release.sh` (zip, notarytool, staple).

---

### What We Found

**Menu bar app, LSUIElement, status item**

- **[Direct]** The menu-bar-only, no-Dock shape is a product requirement. It came before any code. Source: `docs/product-overview.md` line 3 (commit fe0e0d7, 2026-10-08): "The app is displayed in the menubar only, you never see it in the dock." Line 6: "After installation trackpad should continously run in the background." Plan 001 restates it as R1 "Menu bar presence only": "no Dock icon, no entry in the ⌘-Tab app switcher" (`plans/001-trackpad-launcher-app/plan.md` § R1). Neither source gives a reason for the menu bar over other shapes. Plan 001's problem statement takes it as given: "A launcher only earns a place in the menu bar if it costs nothing to keep."
- **[Direct]** `LSUIElement` is how R1 is met. Source: plan 001 Design § Build ("Info.plist `LSUIElement = YES`") and grounding Q8 ("keeps the app out of the Dock and ⌘-Tab while allowing a status item"). `project.yml:39` `LSUIElement: true` comes from 1cf9c4b and has not changed since.
- **[Direct]** The team chose `NSStatusItem` + custom `NSPanel` over `MenuBarExtra` and `NSPopover`. `MenuBarExtra` cannot open or close its window programmatically, and both R18 (open on first launch) and R3 (a gesture closes the window) need that. `NSPopover`'s arrow and chrome did not match the design. Source: plan 001 § Design Problem (line 457) and § Alternatives considered. `.temp/architect/checks/status-item-and-hardened-runtime.md` adds that `NSStatusItemExpandedInterfaceSession` is macOS 27 only, so at a macOS 26 deployment target the shell uses a classic button toggle plus an `NSPanel`.
- **[Direct]** The panel is `.nonactivatingPanel` so it can become key (the pickers and toggle work) without activating the LSUIElement app. Source: plan 001 candidate-2 LauncherPanel sketch and grounding Q8.

**Closing paths, `.heldOpen`, `dismissWindow` vs `closeWindow`**

- **[Direct]** Close-on-outside-click comes from plan 001 R3: "The window MUST close when the user clicks outside it or presses Escape. Clicking the icon while the window is open MUST close it. A gesture that fires while the window is open closes the window". The plan gives no product reason for close-on-outside-click. The 001 dev log says the gesture and icon-click cases were added because they "[were] unspecified".
- **[Direct]** Two mechanisms implement it. resignKey (with a guard so a click on the status button is the toggle and does not cause close-then-reopen) comes from candidate-2. A global mouse-down monitor is installed on show and removed on hide, "no idle cost; mouse-only monitors need no permission". Source: plan 001 MenuBarShell sketch, § Deliberately not done, and § Synthesis. Inline: `MenuBarShell.swift:11-13` (1cf9c4b). No source explains why resignKey alone was not enough.
- **[Direct]** `.heldOpen` and the `dismissWindow`/`closeWindow` split exist because the system Accessibility prompt takes focus and its buttons count as outside clicks. Either one would close the first-launch window before the user saw the hint (plan 002 R10). Sources: plan 002 decision 6 ("Without the hold, R10 fails as soon as the prompt appears"); `Launcher.swift:44-46` comment (1cf9c4b, verified); pre-squash commit b43619b, which switched both soft-close paths from `closeWindow()` to `dismissWindow()`. Plan 002 rejected "opening the window only after the prompt is dismissed" because "Nothing observable tells the app when the system alert closes, so the window would need a timer or a heuristic" (plan 002 line 1150, verified). Tests: AccessibilityTests `firstLaunchPromptsOnceAndHoldsTheWindowOpenUntilAnExplicitClose`, `aGrantEndsTheHoldAndClosesTheWindow`, `promptComesBeforeTheFirstSave`.
- **[Direct]** The window's own System Settings buttons close it explicitly. Otherwise a held window could sit over System Settings. Source: plan 002 dev log, Cross-judge ("a grant closes a held window; the window's own settings buttons close it explicitly before opening a pane").

**First launch: login item and Accessibility**

- **[Direct]** First launch means "no settings record". It is derived, not stored as a flag. The login item is registered before the first save so a crash re-registers instead of losing the item. Undecodable data loads as defaults, not as a first launch, "so a user who turned the item off is never re-enrolled". Source: plan 001 decision 7 (line 554, verified) and the 001 dev log Cross-judge, which rejected candidate-2's "launched before" flag for exactly these two failure modes. Echoed in `Settings.swift:60-61` and tested by PersistenceTests `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch` and `loginItemIsRegisteredBeforeTheFirstSave`.
- **[Direct]** Registering only on first launch is how plan 001 meets R17 scenario 2: a user who turned the item off "does not re-enable itself on its next manual launch". Source: plan 001 R17 and grounding Q9.
- **[Direct]** Plan 001 R19 required Quit not to touch the login item: "Quitting MUST NOT remove the login item." Plan 021 R12 reverses this.
- **[Direct]** Accessibility is asked once, on first launch only, using the same derived first-launch fact. A second "prompted" flag was rejected as "a second boolean that must stay in sync". It sits before the first save "for the same crash reason". Source: plan 002 R10, decision 6, and § Alternatives. Plan 002 explicitly replaced plan 001 R20 "No permissions".
- **[Direct]** `registerLoginItem` uses `try?`. "Registration failing (unsigned build, user-disabled item) leaves the app running without a login item." Source: `WorkspaceActions.swift:88` (verified).

**Quit in the right-click menu (#25)**

- **[Direct]** Quit moved because of a window redesign, and the record gives no deeper reason. Source: PR #25 body (verified): "The menu bar window is rebuilt to the new design … and Quit leaves the window for a right-click menu on the menu bar icon." Commit 22d059a. Pre-squash 8a72f8e has only a title. PR #25 has no comments and no reviews, and no plan exists for #25 or #26.
- **[Direct]** Plan 001 also kept termination out of the model on purpose: "`openURL`/`terminate` closures in the hub rejected as a larger surface with no added policy" (plan 001 § Synthesis).

**Other… chooser**

- **[Direct]** Other… closes the window, activates the app, runs `NSOpenPanel`, then reopens the window. The plan accepted this "in exchange for not fighting window levels and resign-key dismissal while the chooser is up". Source: plan 001 § Tradeoffs (line 1375, verified). `NSOpenPanel` with `allowedContentTypes = [.application]` implements R5 ("a file chooser that only accepts applications", grounding Q7). Plan 006 kept the flow for Add app….

**Gestures, swipes and swaps close the window**

- **[Direct]** Closing on a fired gesture comes from plan 001 R3, filled in because it "was unspecified" (001 dev log). Plan 009 R15 extended it to swaps "as a gesture does", which is parity, not a new reason. Plan 017 R16 kept it ("as today").
- **[Direct]** The only technical reason recorded: "a key launcher window would otherwise keep the keyboard from the raised window". Source: plan 012 § Tradeoffs accepted (line 1459, verified). This applies to a key, non-activating panel.
- **[Direct]** Silent gestures leave the window open. Source: plan 001 T25 ("no target, no close"). Tests `unassignedGestureIsSilentAndLeavesTheWindowOpen` and `withNothingToSwapToNothingHappensAndTheWindowStaysOpen`.

**Never frontmost, never a running app**

- **[Direct]** This started as a statement of fact ("the app is never active"), not a filter. Sources: plan 004 panel recipe line 319 ("`hidesOnDeactivate` off, because the app is never active", verified); plan 006 F2 ("never activates except while the Other… file chooser is up"); plan 008 R1 ("never comes to the front, so it is never frontmost").
- **[Direct]** The assumption failed once. "Reported by the owner: after a rebuild the swipe did nothing … Trackpad Launcher stayed the active app afterwards. … Opening the app from Finder does the same." Source: `plans/008-recent-apps-switcher/development-logs.md:57` "Fix: the first swipe after opening the app did nothing" and plan 008 R14. Commit a17f139 (2026-10-13). The fix: with no readable frontmost app, the row is the running apps alone.
- **[Direct]** Plan 008 decision 2 says the own-pid / `Foreground` filters "are guards against a future macOS, not today's behaviour". Today's code excludes the own pid in `RunningAppsReader.swift:24-40` (verified), `LaunchServicesOrder`, and `FrontmostAppWindows`.

**Supporting constraints**

- **[Direct]** Running two copies at once is a known hazard: "two copies both react to gestures". Source: `docs/performance.md:8` (verified).
- **[Direct]** Distribution is direct download, Developer ID, notarised and stapled. Never `--deep`, main executable signed last. Source: plan 001 R23 and § Build, `docs/architecture.md` "Distribution". `Scripts/release.sh:68-74` zips the app (`ditto -c -k`), submits the zip, and staples the `.app`. There is no DMG and no install step. Plan 001's S6 boxes are unticked. No record shows a Developer ID release was ever produced.
- **[Direct]** The source scan bounds any new code. `addGlobalMonitorForEvents` is confined to `MenuBarShell.swift` and `BounceOverlay.swift`. Timers, `asyncAfter`, `Task.sleep`, `.write(to:`, `createFile(atPath`, `FileHandle(forWriting`, logging and network APIs are banned. Source: `SourcePolicyTests.swift:84-97` (verified) and plan 001 decision 9. Plan 001 R21: "write nothing to disk of its own except its settings". The confinement row came from plan 017 / a068ed5. Its rule string ("pointer moves are read only while a launch bounce shows") describes the bounce, not MenuBarShell's mouse-down monitor.
- **[Direct]** The panel's content is kept after first open so pickers open instantly. Releasing it on close (about 15 MB) was rejected. Source: `docs/performance.md` Decisions (bc56781, #18), citing plan 003. PR #26 reports that a SwiftUI `Picker` made the first open about 1 s instead of about 0.2 s.
- **[Direct]** The composition root depends on the status item existing before `start()`: "a first-launch window needs the status item as its anchor". Source: `MenuBarShell.swift:7`, plan 001 composition-root comment, and the 001 Implement log ("a first-launch off-screen bug found in S4").

---

### What We Can Reasonably Infer

- **[Inferred]** Many of the shell's oddities appear to follow from one root choice, a transient pop-up that closes on outside click (R3). Given that R3 is unargued (plan 001), and that the dev logs record three later workarounds for it (001's unreachable R15 scenario, 002's `.heldOpen`/`dismissWindow`, and 001/006's Other… close/activate/reopen), dropping the transient window plausibly makes `.heldOpen`, `dismissWindow`, the global monitor, the status-button guard and the Other… dance unnecessary. Plan 021's problem statement says the same from the user side: "closes at any outside click, so the user loses it".
- **[Inferred]** The "never frontmost / never running" rule seems to rest on the code filters now, not on the app never being active. Plan 008 R14 admits the app is active after a Finder or Xcode open, and the own-pid filters were kept "as guards". An ordinary activating settings window with a Dock icon would make the "Trackpad Launcher is active" case common rather than rare. Today's fallback ("no frontmost → running apps alone") then differs from what plan 021 R15 wants ("the app that was in front before it"). This likely needs new state, such as remembering the last non-self active app, which no current port provides.
- **[Inferred]** `hidesOnDeactivate = false` on `OverlayPanel` (and per plan 004 its siblings) was justified by "the app is never active". Once the app activates with the settings window, overlays may need that premise re-checked. The flag value may still be right, but its stated reason would no longer hold.
- **[Inferred]** Plan 012's keyboard-focus reason for closing on a gesture appears specific to a *key, non-activating* panel. With an ordinary window in a separate activated app, `bringToFront` should take key focus with the activation, so plan 021 R15 (leave it open) is likely compatible. That needs hardware confirmation.
- **[Inferred]** The first-launch derivation needs care under plan 021 R5 ("first run from /Applications"). Today first launch is "no record". A run from ~/Downloads that moves itself and relaunches could consume the first launch in the wrong copy if the record is saved before the move. Plan 021 R25 (an upgrade keeps login state) appears to fit the existing rule: an upgraded install has a record, so it is not a first launch and does not re-register.
- **[Inferred]** The status icon is currently the only always-visible surface for "gestures inactive" (`Launcher.swift:28`, StatusIcon's stroked variant). Without it, that state would show only inside the settings window. No source discusses this loss.

### Competing Hypotheses

**Why the window closes on outside click (R3)**
- **Hypothesis A:** It was copied from menu-bar-extra convention and has no specific product reason.
  - Evidence for: R3 states no reason. Candidate-2 framed `NSPopover`'s "transient dismissal" as a free feature it would lose. Plan 001's mechanism discussion is all about *how*, not *why*.
  - Evidence against or missing: no source says "we copied convention".
- **Hypothesis B:** It was a deliberate design choice from the (external) menu bar window design.
  - Evidence for: the design is an arrowless card under the icon (plan 001 candidate-2). The design lives in Figma and the product overview image.
  - Evidence against or missing: the Figma file and `menubar-window.png` were not examined for behaviour notes. Static designs rarely specify dismissal.

**Why Quit moved to the right-click menu (#25)**
- **Hypothesis A:** Purely visual, to free the bottom bar in the new design.
  - Evidence for: the PR body frames it as part of "the new design".
- **Hypothesis B:** To keep users from quitting by accident, since Quit stops gestures.
  - Evidence against or missing: nothing in the record mentions this. It is speculative.
- Plan 021's problem statement ("Quit hides in the icon's right-click menu") treats the outcome as a defect either way.

### What We Don't Know

- **Why menu bar rather than a background or Dock app.** The product overview and plan 001 R1 state it as a requirement. Plans 001–017 were grepped for `menu bar|LSUIElement|accessory|activationPolicy`, and git/PR bodies for `menu bar|LSUIElement|dock icon|background app`. None gives a rationale.
- **Why both resignKey and a global monitor.** Plan 001's sketch lists both and the checks file says resign-key gives close-on-outside-click, but no source says what resignKey misses. One possibility is clicks on the desktop or another non-activating surface, but nothing confirms it.
- **Why Quit moved (#25).** There is no plan, the PR body gives only "new design", there are no PR comments or reviews, and pre-squash 8a72f8e has only a title. The Claude session link `https://claude.ai/code/session_01UiUwasNcMidaLLfjWy87uh` and the Figma file were not followed.
- **Whether `SMAppService.mainApp.register()` re-enables an item the user turned off.** Plan 001 avoided the question by registering only once. No plan or probe records `SMAppService.Status` behaviour (`.requiresApproval`, `.notFound`, `.enabled`) after a user toggles it in System Settings. That matters directly for plan 021 R12/R13, which must tell "Quit turned it off" apart from "the user turned it off".
- **How an LSUIElement app (or a background app that switches activation policy) behaves on reopen.** No probe covers reopen from Finder or Spotlight, `applicationShouldHandleReopen`, `setActivationPolicy` toggling, or a second instance. The plan 001 activate-probe tested a *regular* target app opened from a CLI. It showed LaunchServices reuses a running instance and sends reopen. Plan 017 F8 showed a repeated `openApplication` during launch starts no second instance. Neither tested Trackpad Launcher, differing builds, or different paths. Code has no app delegate and no single-instance logic (grep: none).
- **Whether activating an LSUIElement app for `NSOpenPanel` is reliable.** Closed PR #9 (unmerged branch `verify-trackpad-launcher-skill`) reports the test copy "exited twice, about 2 s after the 'Other…' file chooser came to the front, with no crash report. The cause is unconfirmed". It also says a human Quit is not ruled out. That leaves the question unresolved.
- **Whether Developer ID signing or notarisation was ever done.** The plan 001 S6 boxes are unticked, and no commit records a release.
- **Plan 002's manual R10 check** ("Record whether the alert sits in front of the panel") has no recorded outcome.
- **No automated tests** cover `MenuBarShell`, `LauncherPanel`, `StatusIcon` or the `NSOpenPanel` flow. The shell is verified only by hand.
- **People who would know:** the repository owner (domasgru / Dominykas Grubys), who reported the plan 008 R14 bug and authored PRs #1 and #25.

### Sources Consulted

- **Source control history:** `git log --follow`/`blame` on MenuBarShell.swift, LauncherPanel.swift, StatusIcon.swift, TrackpadLauncherApp.swift, SystemPermissions.swift, Launcher.swift (cited ranges), SourcePolicyTests.swift, project.yml, Scripts/release.sh, Config/. Pickaxe searches for about 17 tokens (`SMAppService`, `addGlobalMonitorForEvents`, `nonactivatingPanel`, `NSApp.activate`, `setActivationPolicy`, `NSApplicationDelegate`, `applicationShouldHandleReopen`, own-pid). `--grep` over about 15 lifecycle terms. Pre-squash commits 002e62e, b43619b, 85ea6f2, 1d10f52, 3d94e03, 24993a0, a17f139, 8a72f8e, c49c12c. Squash commits 1cf9c4b (#1), 10b0e91 (#5), b67a5ca (#11), 858c61d (#12), 18acef7 (#15), bc56781 (#18), a068ed5 (#21), 22d059a (#25), 997a42f (#26). PR bodies, comments and reviews for #1, #5, #11, #15, #25, #26 and #9 (closed); all discussion threads were empty. docs/product-overview.md, architecture.md, domain-model.md, performance.md. Tests AccessibilityTests, PersistenceTests, SourcePolicyTests. The synthesizer spot-checked `Launcher.swift:44-46,105-113`, `WorkspaceActions.swift:88-91`, `SourcePolicyTests.swift:84-97`, `RunningAppsReader.swift`, `LauncherPanel.swift`/`OverlayPanel.swift` flags, `project.yml:39`, `release.sh:68-74`, `performance.md:8`, `product-overview.md:3,6`, PR #25's body, and the commit hashes above.
- **Plans:** read in full: 001 (plan, dev log, grounding Q6–Q10, checks/status-item-and-hardened-runtime.md, the activate-probe, candidates), 002 (plan and dev log). Relevant sections of 003, 004, 006 (grounding F1/F2, frontmost-probe), 008 (plan and full dev log), 009, 010, 012, 014, 017. Plan 021 for its problem statement and R1–R25. Greps across plans for login/SMAppService, own pid/accessory/LSUIElement, notarisation and /Applications, NSOpenPanel/chooser, monitor/resign/dismissWindow/Quit, confinement, activation, first launch, App Nap and single instance, and window-closes phrasing. There are no plan dirs for 019 or for PRs #22/#24/#25/#26. `research/` was not read.

### Confidence Summary

The mechanics and their stated reasons are well documented in plans 001/002/008/012 and code comments. That covers why `NSStatusItem` + `NSPanel` (programmatic open/close), why non-activating (key without activation), why `.heldOpen`/`dismissWindow` (the Accessibility prompt), why first launch is derived and the login item registered before the first save (crash safety, never re-enrol), and why Other… does close/activate/reopen (avoid fighting resign-key). The *product* reasons for the menu bar shape, close-on-outside-click, gestures closing the window, and Quit's move to the right-click menu are thin or absent. They read as requirements or design choices with no argument. The "never active" premise is documented as already wrong once. The question's premise that no login-item registration exists is incorrect.

---

## Constraint set for plan 021

### Preserve

1. **First launch derived from the absence of a settings record**, with its two invariants: side effects (login registration, the Accessibility ask) run *before* the first save, and an undecodable record is *not* a first launch (plan 001 decision 7; plan 002 decision 6; PersistenceTests). Plan 021 R13 ("never turn back on a user's Login Items choice") and R25 (upgrade keeps login state) depend on these.
2. **Accessibility asked once, on first launch only, with no separate "prompted" flag** (plan 002 R10 and § Alternatives). Plan 021 R5 restates this.
3. **The never-frontmost / never-running exclusion for the switcher and swap** (own-pid filters in RunningAppsReader, LaunchServicesOrder, FrontmostAppWindows; plan 008 decision 2). Plan 021 R15 keeps it.
4. **Window visibility as `Launcher` model state, with the shell mapping AppKit signals to intents** (plan 001 decision 8). This keeps lifecycle decisions testable through the in-memory adapters.
5. **Policy out of the shell: the model gets no `terminate`/`openURL` closures** (plan 001 § Synthesis), and every new platform dependency (login-item status, single instance, app location/move, activation policy) gets a port with a real and an in-memory adapter (plan 001 task/rubric; plan 002 constraint list).
6. **Source-policy rules:** no timers, polling, `asyncAfter` or `Task.sleep`; no logging; no network; no own-file writes other than settings; confined APIs named in one file (SourcePolicyTests; plan 001 R21; architecture.md).
7. **Distribution rules:** Developer ID, hardened runtime, no sandbox, notarised and stapled, never `--deep`, main executable signed last (plan 001 R23 and § Build; architecture.md).
8. **Instant first open of the window's content** (performance.md decision citing plan 003; PR #26's 0.2 s vs 1 s).
9. **Gesture feedback, bring-to-front and the launch animation unchanged** when a gesture fires with the window open (plan 021 R15).

### Change (each reverses a documented earlier decision; update the doc and tests that encode it)

1. **LSUIElement + status item → background app with no icon.** This retires plan 001 R1 and `product-overview.md`'s "menubar only" sentence (plan 021 says so). `project.yml:39`, `StatusIcon`, `MenuBarShell`, and the "status item first" ordering in `TrackpadLauncherApp.swift` / `Launcher.start()`'s doc comment all go or change.
2. **Transient panel → ordinary titled window.** This retires plan 001 R3's close-on-outside-click, so `.heldOpen`, `dismissWindow()`, the resignKey status-button guard and the global mouse-down monitor lose their reason. Remove them deliberately, with the AccessibilityTests that encode the hold (`firstLaunchPromptsOnceAndHoldsTheWindowOpenUntilAnExplicitClose`, `aGrantEndsTheHoldAndClosesTheWindow`, `aFiredGestureClosesAHeldWindow`). Re-check R5's first-run scenario on hardware: the system prompt must not hide or close the window. Also remove `MenuBarShell.swift` from the `addGlobalMonitorForEvents` confinement row and from architecture.md's sentence about "the launcher window's outside-click monitor".
3. **Gestures, swipes, window swipes and swaps no longer close the window** (plan 021 R15 reverses 001 R3, 009 R15, 012's tradeoff and 017 R16). Update LauncherTests, SwapTests, SwitcherOnScreenTests and the domain-model "Swap" and "Launch animation" entries.
4. **Other… becomes a sheet on the settings window** (plan 021 R16 reverses plan 001's close/activate/reopen tradeoff, which existed only to avoid fighting resign-key dismissal).
5. **System Settings buttons leave the window open** (plan 021 R17 reverses plan 002's explicit close).
6. **Quit turns login start off and restores it only if Quit turned it off** (plan 021 R12 reverses plan 001 R19 "Quitting MUST NOT remove the login item"). This needs a stored "Quit disabled login" fact in settings, the only allowed write, and an `unregister()`/`status` path that no current code or plan has used.
7. **Frontmost fallback.** Plan 021 R15 wants "the app that was in front before it", not today's "no frontmost → running apps alone" (plan 008 R14). This needs new state, plus updated tests for the `nil` frontmost case.
8. **Distribution:** `release.sh` zip → notarised DMG. There is no prior plan or code for a DMG.
9. **Glossary:** "launcher window" → "settings window" in domain-model.md. Naming has already drifted between PR #25 and PR #26.

### Avoid

1. **Re-enrolling a user who turned the login item off**: no `register()` on every launch, on upgrade, or on reopen after Quit unless Quit did the disabling (plan 001 R17 scenario 2; plan 021 R13).
2. **A second "first launch"/"prompted" boolean** that can drift from the derived fact (plan 002 § Alternatives).
3. **Timers or delayed calls** to wait for the Accessibility alert, the move, a relaunch or an activation-policy switch (plan 002 rejected the timer route; SourcePolicyTests bans `asyncAfter`/`Task.sleep`/`Timer`).
4. **Logging, network, or own-file writes beyond settings.** A move-to-/Applications copy and a relaunch must use APIs the scan does not ban, *and* the change must amend plan 001 R21 / architecture.md's "no files written other than settings" on purpose, not slip past it (`FileManager` copy/move is not on the banned list, but the prose forbids own writes).
5. **Letting two copies run**: "two copies both react to gestures" (`performance.md:8`).
6. **Spelling a confined API name in another file, even in a comment.** The scan reads comments (plan 012 dev log).
7. **Rebuilding the window's heavy content on every open** (performance.md; PR #26).

### Risk

1. **The "never active" premise breaks wholesale.** With a Dock icon and an activating window, Trackpad Launcher will often be the active app. Everything that assumed otherwise needs review: the frontmost read's `nil` path (plan 008 R14 bug history, a17f139), `hidesOnDeactivate = false` on the overlay/switcher panels ("because the app is never active", plan 004), and the `AnimationTuner` comment ("otherwise never active").
2. **Activation-policy switching and reopen are unprobed for this app.** No probe covers `setActivationPolicy` toggling, reopen from Finder or Spotlight for a background app, or a different build opening while one runs (plan 021 R2/R3). The only evidence is a regular-app probe (plan 001 activate-probe) and plan 017 F8.
3. **`SMAppService` status semantics are unverified.** Telling a Quit-disabled item apart from a user-disabled one, and `.requiresApproval` behaviour, are undocumented here. `try?` currently swallows every failure, including unsigned builds.
4. **The first-run vs move-to-/Applications ordering** could spend the first launch (login registration, Accessibility ask, record save) in the copy that is about to be moved (plan 021 R5, R18–R23 vs plan 001 decision 7).
5. **The TCC grant may not follow a moved or replaced copy** (plan 002's open question on separate TCC clients is unresolved).
6. **Activation reliability around system UI.** Closed PR #9 recorded unexplained exits about 2 s after an activated `NSOpenPanel`. The cause is unconfirmed, but it is the only signal on activation for this app.
7. **The "gestures inactive" status is no longer always visible** once the stroked status icon is gone. No source discusses this.
8. **DEBUG composition root** shows the animation tuner at every launch. Decide whether it counts as "a window open" for the Dock-icon rule (R6).
9. **No automated coverage of the shell.** Today the shell is verified only by hand, so lifecycle regressions will surface only through E2E checks unless the new lifecycle policy moves into tested model state.
