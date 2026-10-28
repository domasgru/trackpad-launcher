# Why: lifecycle shell (source control findings)

### Source
Source control: git history (main, feature/001 branch pre-squash commits, unmerged/closed branches), `gh` PR bodies, comments and reviews, inline code comments, tests, and `docs/` as committed. I did not read `plans/` content. Plan files committed inside PR commits are listed under Additional Leads.

### What I Searched
- `git log --follow` on MenuBarShell.swift, LauncherPanel.swift, StatusIcon.swift, TrackpadLauncherApp.swift, SystemPermissions.swift, project.yml, Scripts/release.sh, Config/.
- `git blame` on all of MenuBarShell.swift; Launcher.swift l.28-35, 44-49, 88-113, 185-196, 265, 309, 343-346, 361; SourcePolicyTests.swift l.85-96; project.yml l.30-45; StatusIcon.swift.
- Pickaxe (`-S`) for: `SMAppService`, `LoginItem`, `never Trackpad Launcher`, `around the Other… chooser`, `outside-click monitor`, `asked for on first launch`, `addGlobalMonitorForEvents`, `processIdentifier != own`, `ownPID`, `NSApp.activate`, `nonactivatingPanel`, `activationPolicy`, `setActivationPolicy`, `otherwise never active`, `NSApplicationDelegate`, `applicationShouldHandleReopen`, `NSRunningApplication.current`.
- `git log --all --grep` (case-insensitive) for: menu bar, status item, login, LSUIElement, dock icon, quit, single instance, second instance, /Applications, background app, activation policy, accessory, frontmost, closes the window, launcher window.
- `gh pr view` for #1, #5, #11, #15, #25, #26, #9 (closed). `gh pr list --state all` bodies grepped for: menu bar, status item, LSUIElement, login, dock icon, activat, first launch, Quit, outside click, resign, /Applications, single instance, second copy. `gh api .../pulls/{1,25}/comments` and `.../issues/25/comments`.
- Pre-squash commits on `origin/feature/001-trackpad-launcher-app` (002e62e, b43619b, 85ea6f2, 1d10f52, 3d94e03, 24993a0) and on `origin/claude/lucid-newton-p6ylb4` (8a72f8e, c49c12c).
- Unmerged branch `origin/verify-trackpad-launcher-skill` (PR #9, closed): `.claude/skills/verify-trackpad-launcher/features/launcher-window.md`, `features/gesture-assignments.md`, `SKILL.md`.
- docs: `docs/product-overview.md` (HEAD and at fe0e0d7), `docs/architecture.md` (HEAD and at 1cf9c4b), `docs/domain-model.md` (HEAD, at 1cf9c4b, diffs in 10b0e91, b67a5ca, 22d059a), `docs/performance.md`.
- Tests: AccessibilityTests.swift, PersistenceTests.swift, SourcePolicyTests.swift; grep for tests naming MenuBarShell, LauncherPanel, StatusIcon, NSOpenPanel, LSUIElement, SMAppService (none besides SourcePolicyTests).
- Code grep for self-exclusion (`processIdentifier`, `itself`), activation (`NSApp.activate`, `nonactivatingPanel`, `canBecomeKey`), app delegate / reopen handling.

---

### Direct Evidence Found

**1. Origin of "menu bar only, never in the Dock" and "runs in the background": the product brief**
- What it says: "Trackpad launcher is an app to launch apps on MacOS using gestures on trackpad. The app is displayed in the menubar only, you never see it in the dock. Menubar window design - [image](./menubar-window.png). In menubar window you can select an app for each available gesture." And under Additional notes: "After installation trackpad should continously run in the background", plus "Trackpad launcher should be as performant as possible, consuming the least possible resources".
- Where: `docs/product-overview.md`, first added in commit fe0e0d7 "Add product overview and design assets". The sentence is still unchanged at HEAD.
- Author/date: domasgru, 2026-10-08 (co-authored by Claude Fable 5.1).
- Relevance: This is the stated product requirement behind LSUIElement, the status item and the "menubar window". It comes before any code.

**2. The whole shell (LSUIElement, status item, NSPanel under the icon, resignKey plus global outside-click monitor, NSOpenPanel for Other…, Quit, login item, first-launch AX prompt) was created in one PR**
- Commit 1cf9c4b "Trackpad Launcher app (#1)", PR #1, head branch `feature/001-trackpad-launcher-app`, merged 2026-10-09. PR body (verbatim): "Implements the Trackpad Launcher macOS menu bar app: a corner-tap gesture on the trackpad launches an assigned app, with a settings window for per-corner assignments, login item registration, and a release/notarization script. Follow-up changes: window outline, spacing and hint line-height fixes; more forgiving taps (400 ms, every finger counts); optional Accessibility permission that blocks trackpad clicks for 3 seconds after the thumb anchors." PR #1 has no comments and no reviews.
- Blame: 117 of the 181 lines of MenuBarShell.swift still come from 1cf9c4b, including the class doc comment on dismissal (l.11-13), statusItem creation (l.27), resignedKey (l.105-109), show() with `NSEvent.addGlobalMonitorForEvents` (l.121-131), hide (l.133-137), refit body (l.143-155) and the NSOpenPanel chooser (l.162-175). project.yml `LSUIElement: true` (l.39) is also from 1cf9c4b and has never changed since.
- Pre-squash: the shell appeared in 002e62e "S4: Menu bar app, launcher window and real adapters without frames" (2026-10-09 08:33). The message has no body beyond the title. That commit already had both closing paths (resignKey and the global mouse-down monitor), both calling `launcher.closeWindow()`.
- Relevance: The current shape is mostly the original #1 design. The git messages give no rationale beyond the titles. The design rationale, if written down, is in plans/001 and plans/002 (see Leads).

**3. The two closing paths and why the status-button click is excluded: inline comment from #1**
- Verbatim (MenuBarShell.swift l.6-13, l.6-7 and l.11-13 from 1cf9c4b, l.9 from 22d059a):
  "/// The thin AppKit shell: maps AppKit signals to `Launcher` intents and renders `Launcher` state.
  /// Create it before `Launcher.start()`: a first-launch window needs the status item as its anchor.
  ...
  /// Dismissal: an icon click toggles; the panel resigning key dismisses it, except for a mouse-down on the status
  /// item's own button (that click is the toggle, and closing here would reopen it); a mouse-down monitor
  /// exists only while the window is open and dismisses; Escape closes; a fired gesture closes it through the model."
- Author/date: Dominykas Grubys, 2026-10-09.
- Relevance: States the resignKey exception (a click on the status button would otherwise close the window and then reopen it). It also says the global monitor exists only while the window is open. It does not say why both paths are needed.

**4. Why "dismiss" differs from "close": the held first-launch window under the Accessibility prompt**
- Verbatim (Launcher.swift l.44-47, blame 1cf9c4b, 2026-10-09):
  "/// `.heldOpen` is the first-launch window under the system's Accessibility prompt. The prompt takes focus when it
  /// appears and its buttons are outside clicks; both would close an ordinary window before the user saw the hint.
  /// A held window closes only on an explicit close, a fired gesture, or a grant."
- Launcher.swift l.192-196 (1cf9c4b): "/// Icon click, Escape, the window's own System Settings buttons: always closes." / "/// An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt."
- Launcher.swift reconcile (1cf9c4b, still at l.218-219): "// A grant ends the hold: the hint has done its job and the user is in System Settings."
- Pre-squash history: commit b43619b "S2: Accessibility permission, first-launch prompt, held window, live hint" (feature/001 branch, 2026-10-09 13:43) changed both MenuBarShell closing paths from `launcher.closeWindow()` to `launcher.dismissWindow()`. Diff: `- if !isStatusButtonClick { launcher.closeWindow() }` / `+ if !isStatusButtonClick { launcher.dismissWindow() }` and `- MainActor.assumeIsolated { launcher.closeWindow() }` / `+ MainActor.assumeIsolated { launcher.dismissWindow() }`.
- Tests encode it. AccessibilityTests.swift `firstLaunchPromptsOnceAndHoldsTheWindowOpenUntilAnExplicitClose` (dismissWindow keeps it open, closeWindow closes, and a relaunch does not prompt again: `#expect(world.permissions.asks == [.accessibility])`). Also `firstLaunchWithAccessAlreadyGrantedSkipsThePromptAndOpensAnOrdinaryWindow`, `aGrantEndsTheHoldAndClosesTheWindow`, `aFiredGestureClosesAHeldWindow`, `promptComesBeforeTheFirstSave`.
- Relevance: This directly explains why the outside-click and resignKey paths go through `dismissWindow`. Both would otherwise close the first-launch window when the system AX prompt appears. The redesign has to keep, or deliberately replace, the held-window semantics.

**5. Accessibility asked only at first launch, crash-safe ordering, and silent login item registration**
- Verbatim (Launcher.swift l.105-113, lines from ee9a3f0 #3 restructuring 1cf9c4b's code, l.110 from 18acef7):
  "if isFirstLaunch {
      // Both effects come before the first save: a crash in between repeats them next time instead of
      // losing them.
      system.registerLoginItem()
      let prompting = !isAccessibilityGranted
      if prompting { permissions.ask(.accessibility) }
      store.save(settings)
      window = prompting ? .heldOpen : .open
  }"
- In 1cf9c4b the same block read `guard isFirstLaunch else { return }` with the identical comment "Both effects come before the first save: a crash in between repeats them next time instead of losing them."
- docs/architecture.md (HEAD): "The app may ask for two permissions, both optional. Accessibility, asked for on first launch, is used only to block trackpad clicks, ..." The phrase "asked for on first launch" appears in 18acef7 (#15) and a068ed5 (#21). At 1cf9c4b, architecture.md read: "The app asks for one permission, Accessibility, and uses it only to block trackpad clicks during gestures. ... works fully without it except click blocking."
- After first launch, the Accessibility hint's button opens System Settings rather than re-prompting: LauncherView.swift l.36-39 `button: "Grant access…", open: { actions.openSettings(.accessibility) }`.
- Relevance: First-launch-only prompting is tied to the `isFirstLaunch = stored == nil` detection, which also gates login item registration and opening the window.

**6. CONTRADICTION WITH THE QUESTION'S PREMISE: login item registration DOES exist in code at HEAD**
- `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` l.88-91 (HEAD):
  "/// Registration failing (unsigned build, user-disabled item) leaves the app running without a login item.
  public func registerLoginItem() {
      try? SMAppService.mainApp.register()
  }"
- Called once from `Launcher.start()` on first launch (Launcher.swift l.108). Port: `Ports.swift:61 func registerLoginItem()`.
- `Settings.swift` l.60-61 (SettingsStore.load): "/// nil means nothing was ever saved, which is a first launch. Undecodable data loads as `Settings()`, / /// not as a first launch, so a user who turned the login item off is never re-enrolled."
- Tests: PersistenceTests `firstLaunchShowsFreshDefaultsOpensTheWindowAndRegistersTheLoginItem` (`loginItemRegistrations == 1`), `secondLaunchStaysQuietAndDoesNotRegisterAgain`, `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch` (`== 0`), `loginItemIsRegisteredBeforeTheFirstSave`, and upgrade tests asserting `loginItemRegistrations == 0`.
- Pickaxe `SMAppService`: only 1cf9c4b (#1). It has been present since the first PR. The PR #1 body names "login item registration".
- What does NOT exist: no UI toggle for the login item, no unregister call (`grep SMAppService` finds only `register()`), and Quit does not touch it.
- Relevance: The redesign's "login-item registration that Quit turns off" changes an existing mechanism (register once at first launch, never re-enrol a user who turned it off). It is not a new addition. The "never re-enrolled" invariant is explicit in a code comment and a test.

**7. Quit moved to the status icon's right-click menu: design-driven, no deeper rationale recorded**
- PR #25 body (verbatim, Quit section): "**Quit** - The Quit button is removed. A right-click or Control-click on the menu bar icon closes the window and opens a menu with *Quit Trackpad Launcher* (⌘Q). A left click still toggles the window." Opening line: "The menu bar window is rebuilt to the new design (252 × 524 pt), and Quit leaves the window for a right-click menu on the menu bar icon."
- Commit 22d059a message: "... Quit moves to a right-click (or Control-click) menu on the menu bar icon."
- Pre-squash commit 8a72f8e "Quit moves from the launcher window to the menu bar icon's right-click menu" (author "Claude", 2026-10-21) has only a title. Head branch `claude/lucid-newton-p6ylb4`, which is not a `feature/NNN` branch, so there is probably no plan.
- Inline: MenuBarShell.swift l.9 "/// A right-click (or Control-click) on the icon opens a menu holding Quit instead of toggling the window." and l.94 "/// Set only for the click, so a left click still reaches `statusItemClicked` instead of opening the menu." (both 22d059a).
- docs/domain-model.md "Launcher window" (22d059a): "Quit is in the menu that a right-click (or Control-click) on the menu bar icon opens."
- PR #25: no comments, no reviews (`gh api pulls/25/comments` → `[]`).
- Relevance: The only stated reason is "the new design". In #1 Quit was a button in the window (`quit: { NSApp.terminate(nil) }` in LauncherActions). In the current code, the status item is the only place Quit is reachable.

**8. "Trackpad Launcher never counts as the frontmost app or a running app": history and a bug it caused**
- 10b0e91 (#5, plan 006, 2026-10-12) introduced in domain-model: "The active app at the moment a swipe begins; never Trackpad Launcher, which never activates."
- b67a5ca (#11, plan 008, 2026-10-13) revised it to: "never Trackpad Launcher. Trackpad Launcher is active only when macOS makes it so: right after it is opened (from Finder, or Run in Xcode) and around the Other… chooser. ... When there is none, as while Trackpad Launcher itself is active, the row is the running apps alone..." and added to running apps "never a menu bar app, and never Trackpad Launcher."
- Pre-squash commit a17f139 "Swipe works while Trackpad Launcher itself is active" (domasgru, 2026-10-13), verbatim body: "Right after the app is opened (Finder, or Run in Xcode) macOS makes it the active app. The switcher skipped itself as frontmost and showed nothing until a tap brought another app forward. Now the row is the running apps alone, starting on the most recent, and lifting on any of them brings it forward." It also touched plans/008 plan.md and development-logs.md.
- Code (from b67a5ca): RunningAppsReader.swift l.36-41 "/// nil when there is no active app, it has no bundle identifier or location, or it is this app, which never / /// activates except around the Other… chooser." and `app.processIdentifier != ProcessInfo.processInfo.processIdentifier`. Fallback list filters `app.activationPolicy == .regular && app.processIdentifier != own` (l.28). LaunchServicesOrder.swift l.36-44 filters `pid != ownPID` ("Every foreground app other than this process"). FrontmostAppWindows.swift l.48-49 returns `.noApp` for own pid. WindowSwitcher.swift: "/// There is no active app, or it is Trackpad Launcher itself." Apps.swift l.34-35: "or it is Trackpad Launcher / itself, which never activates except around the Other… chooser."
- Tests: World.swift l.193 and InMemoryAdapters.swift l.267 "nil models no active app, or Trackpad Launcher itself". Also SwitcherAssignedAppsTests `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst`, SwapTests `aMenuBarAppInFrontIsSkippedAndNoFrontmostAppSwapsToTheFirstRunningApp`, WindowSwipeNeedsTwoWindowsTests `.noFrontmostApp`.
- Relevance: The self-exclusion was written on the assumption that TL "never activates except around the Other… chooser". a17f139 shows that assumption already failed once (an incident-like bug fix). A settings window that is an ordinary activating window with a Dock icon makes TL the active app much more often. That widens the case these comments describe as rare.

**9. The NSEvent monitor confinement in the source-scan test is newer than the monitor, and its rule text describes the bounce**
- SourcePolicyTests.swift l.90-92 (blame a068ed5, #21 "launch bounce", 2026-10-19): `Confined(token: "addGlobalMonitorForEvents", onlyIn: ["MenuBarShell.swift", "BounceOverlay.swift"], rule: "pointer moves are read only while a launch bounce shows")`. `addLocalMonitorForEvents` is confined to BounceOverlay.swift only.
- Same commit added to architecture.md: "... the NSEvent monitors to the launch bounce's overlay and the launcher window's outside-click monitor."
- Commit a068ed5 sub-message (S1): "the source scan confines a token to several files". S4: "While any bounce shows, passive NSEvent monitors for moves and drags keep the row glued above the pointer ... once the last bounce ends nothing of ours reads the pointer."
- Relevance: The confinement was added when the bounce introduced pointer-move monitors. MenuBarShell's existing mouse-down monitor (from #1) was allow-listed rather than motivating the rule. The rule string attached to the MenuBarShell entry talks only about the launch bounce. Removing the launcher panel means removing "MenuBarShell.swift" from this allow-list and updating the architecture.md sentence. Adding any new global monitor (for example in a new shell file) would fail this test.

**10. Other… chooser is NSOpenPanel with explicit app activation, which is the one sanctioned activation**
- MenuBarShell.swift l.161-175 (1cf9c4b; `completion` from 10b0e91): closes the window, `NSApp.activate()`, NSOpenPanel at `/Applications`, `.application` only, reopens the window in the completion.
- LauncherActions.swift (doc on the field): "/// Other…: closes the window, activates, runs the file chooser for applications, hands the chosen app to the / /// completion, and reopens the window."
- domain-model "Frontmost app" names this as one of the two times TL is active (see item 8).
- Relevance: The code comments state the activation around NSOpenPanel. They give no reason for NSOpenPanel over another chooser.

**11. Gestures/swipes/swaps close the launcher window: what the record shows**
- Gesture fire `window = .closed`: Launcher.swift l.265, blame 1cf9c4b (doc comment l.13 "a fired gesture closes it through the model"; Launcher.swift l.46 "A held window closes only on an explicit close, a fired gesture, or a grant").
- Swipe lift: l.309, blame 10b0e91 (#5). Window swipe lift with haptic: l.343-346, blame 18acef7 (#15). Swap: l.361, blame 858c61d (#12).
- domain-model "Swap": "It fires when the thumb lifts: the gesture haptic, bring to front, and the launcher window closes". "Launch animation setting": "the feedback, bring to front and closing the launcher window are unchanged."
- Tests: LauncherTests `twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow`, `unassignedGestureIsSilentAndLeavesTheWindowOpen`; SwapTests `theThumbLiftingSwapsToThePreviousAppWithTheHapticAndNoAnimationAndClosesTheWindow`, `withNothingToSwapToNothingHappensAndTheWindowStaysOpen`; SwitcherOnScreenTests `liftingOpensTheSelectionWithTheGestureHapticNoLaunchAnimationAndClosesTheWindow`; SwipeSettingTests `turningTheSwipeOffShowsNoSwitcherAndKeepsTheWindowOpen`.
- No commit message or PR body states *why* a gesture closes the window (searched `--grep 'closes the window|window closes|close the window|launcher window'`). The pattern is "effect happened → window closes; silent no-op → window stays".

---

### Indirect / Circumstantial Evidence

**A. Non-activating, pop-up-level, all-Spaces panel**
- LauncherPanel.swift l.4 (1cf9c4b): "/// Borderless, non-activating, key-capable; pop-up-menu level; joins every Space and full-screen apps." styleMask `[.borderless, .nonactivatingPanel]`, `level = .popUpMenu`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`, `hidesOnDeactivate = false`.
- Suggests: the panel was built so opening the window does not activate TL. That is consistent with item 8's "never activates", but no commit states that link.
- Alternative reading: it may simply copy the standard menu-bar-extra pattern.

**B. Debug tuner comment confirms the "never active" premise**
- AnimationTuner.swift l.41-42 (from ee9a3f0, #3): "/// Takes keyboard focus and activates the app on any click, so the preset name field receives typing even though / /// the app is a menu bar app that is otherwise never active." The tuner opens at launch in DEBUG builds (TrackpadLauncherApp.swift l.22-24 `#if DEBUG system.showAnimationTuner() #endif`, from ee9a3f0).
- Suggests: the DEBUG composition root already shows a window at every launch. A redesign that ties Dock-icon visibility to "a window is open" has to decide whether the DEBUG tuner panel counts.

**C. Status icon reflects gesture activity only, never Accessibility**
- Launcher.swift l.28 (1cf9c4b): "/// One derivation, read by the icon, the notice and the fire guard." l.33: "/// Drives the Accessibility hint. Deliberately not part of `activity`, so the icon never reads it."
- StatusIcon.swift (1cf9c4b, unchanged since): "Template images for light and dark menu bars. Inactive is the same symbol with a diagonal stroke drawn once".
- MenuBarShell l.47-52 observes `launcher.activity.isActive` and swaps the image.
- Suggests: the status icon is the only always-visible surface for "gestures inactive" (no trackpad / Tap to click on / Look up three-finger tap). Without a menu bar icon, that state is visible only in the settings window's trackpad notice. No commit discusses this.

**D. Status-item anchor ordering constraint**
- MenuBarShell l.7 "Create it before `Launcher.start()`: a first-launch window needs the status item as its anchor." Launcher.swift l.88 "/// Launch. Call once, after the status item exists." refit doc (l.141-142, 1cf9c4b): "The status item's window sits off-screen until the menu bar lays it out, so until it has a real frame the panel goes to the top-right corner, and it moves under the icon when the frame arrives."
- Suggests: the composition-root order and `Launcher.start()`'s doc comment both reference the status item, and would need rewording.

**E. Closed PR #9 / unmerged branch `verify-trackpad-launcher-skill`: LSUIElement activation pain with the Other… chooser**
- `features/gesture-assignments.md` (branch only, never merged), verbatim: "**Open issue: the app may exit after Other….** Twice during skill creation, the verification build exited about two seconds after the Other… chooser came to the front, with no crash report. It was during agent-driven attempts while the user was at the Mac, so a person dismissing the chooser and clicking Quit isn't ruled out." And: "The agent must not drive the Other… chooser itself. After an AX press, macOS cooperative activation can leave the chooser behind the user's frontmost app, and nothing short of a real click brings this `LSUIElement` app forward."
- `features/launcher-window.md` (same branch): "The app never shows a Dock icon." "`window-no-dock` keeps the app out of the Dock and app switcher." "Any `status` record above has `"activationPolicy":"accessory"`". "Outside-click dismissal can only be proven by a person clicking. AX actions and posted events don't produce the global mouse-down the app listens for." "`$T escape` refuses with `window is open but not key` when the panel lost focus without closing. That itself is unexpected (the app closes the panel on resign-key)".
- PR #9 body: "## Known issue The test copy exited twice, about 2 s after the "Other…" file chooser came to the front, with no crash report. The cause is unconfirmed". PR #9 closed 2026-10-13, not merged, no comments or reviews.
- Suggests: activating an LSUIElement app for NSOpenPanel can be unreliable under macOS cooperative activation. The exit is unexplained. Partial evidence: the exit cause is unconfirmed and a human Quit is not ruled out.
- Alternative reading: the exits may be unrelated to activation (the user may have quit).

**F. Memory retained after the window first opens; release-on-close was rejected**
- docs/performance.md (bc56781, #18), verbatim: "After the menu window was first opened: 57 MB, and it stays there after the window closes." Decisions: "**Release the menu window's content on close (about 15 MB): rejected.** Plan 003 keeps pickers instant on every open, and freed small-heap memory is often not returned to the system, so the saving is uncertain. Measure what the 15 MB is before revisiting."
- PR #26 body: "A SwiftUI menu `Picker` was tried and dropped: it builds every item up front (about 545 with icons), which made the window's first open about 1 s instead of about 0.2 s." Commit 997a42f: "made the window's first open take about 1 s instead of about 0.2 s".
- Suggests: the panel is created once in `MenuBarShell.init` and kept for instant opens. A redesign that creates or destroys a titled window per open interacts with this decision.

**G. Banned APIs that bound a redesign (source-scan test)**
- SourcePolicyTests.swift `banned` includes `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource` (timer/polling), `.write(to:`, `FileHandle(forWriting`, `createFile(atPath` ("own files"), `keyDown`/`keyUp`/`flagsChanged` ("R9 no keyboard"), `URLSession` etc. ("network").
- architecture.md: "No network code of any kind, no logging of any kind ..., no files written other than settings in `UserDefaults`." "No timers, no polling, no background loops: every input is a push".
- Suggests: a move-to-/Applications copy, single-instance detection and login-item status checks must fit the "no files written other than settings" and "no timers/polling" constraints, or change these docs and tests on purpose. `FileManager.copyItem`/`moveItem` are not in the banned list, but the architecture prose forbids writing files.

**H. Distribution context**
- architecture.md "Distribution": "Direct download only, signed with Developer ID, hardened runtime, notarized with `notarytool` and stapled. Never sign with `--deep`; the main executable is signed last." Scripts/release.sh (1cf9c4b, unchanged): zips the exported .app (`ditto -c -k --keepParent`). There is no DMG and no /Applications install step.
- WorkspaceActions comment: "Registration failing (unsigned build, user-disabled item) leaves the app running without a login item."
- Suggests: a zip download means the user may run the app from ~/Downloads (relevant to a move-to-/Applications dialog). No commit says so.

**I. No app delegate and no reopen handling**
- No `NSApplicationDelegate`, `applicationShouldHandleReopen` or `applicationDidFinishLaunching` in LauncherKit/Sources or TrackpadLauncher at HEAD. Pickaxe hits for these names in #1/#21 are all in plan probe files under `plans/` (e.g. plans/001 `.temp/architect/grounding/probes/activate-probe`).
- Composition root: `withExtendedLifetime(shell) { application.run() }` with no delegate (TrackpadLauncherApp.swift, 1cf9c4b).
- Suggests: relaunching from Finder while running does nothing visible today (observation from code, not stated intent). There is no single-instance logic.

---

### Contradictions
1. **Question premise vs code**: the question says "no login-item registration in code". HEAD has `SMAppService.mainApp.register()` on first launch (WorkspaceActions.swift l.88-91, Launcher.swift l.108), tested in PersistenceTests and AccessibilityTests, and present since 1cf9c4b. What is absent is any unregister call, UI toggle, or tie to Quit.
2. **"Never activates" vs reality**: 10b0e91's domain-model said TL "never activates". a17f139 (in #11) records it does activate "Right after the app is opened (Finder, or Run in Xcode)", which caused a switcher bug. Code comments (Apps.swift l.34-35, RunningAppsReader.swift l.36-37) still say "never activates except around the Other… chooser" and do not mention the post-launch activation that the domain model (b67a5ca) does mention.
3. **SourcePolicyTests rule text vs allow-list**: the `addGlobalMonitorForEvents` entry allows MenuBarShell.swift but its rule string is "pointer moves are read only while a launch bounce shows". MenuBarShell's monitor reads mouse-downs, not pointer moves. architecture.md describes it correctly ("the launcher window's outside-click monitor").
4. **Naming drift**: PR #25 / 22d059a call it the "launcher window" / "menu bar window". PR #26 / 997a42f / efee3a6 / e1c932f call the same window the "settings window". docs/domain-model.md still defines "Launcher window" as "The window that opens from the menu bar icon". PR #1 body calls it "a settings window". product-overview calls it "Menubar window".

### Gaps
- No PR review comments or discussion threads exist on any PR checked (#1, #5, #11, #15, #25, #26, #9). All `reviews` and `comments` arrays are empty.
- No commit message or PR body explains why both resignKey and a global monitor are needed. The closest is the MenuBarShell doc comment and the `.heldOpen` comment.
- No commit or PR explains choosing LSUIElement over a regular app beyond product-overview's "menubar only, you never see it in the dock".
- No commit or PR explains choosing NSOpenPanel for Other….
- No commit or PR explains why a gesture/swap/swipe closes the window.
- No commit/PR mentions single instance, a second copy, /Applications relocation, Dock icon toggling, or `setActivationPolicy` (searched; zero hits outside plan probes).
- No commit/PR records an incident for the outside-click monitor or resignKey path. The only incident-like items are a17f139 (TL active after open broke the switcher) and the unconfirmed Other… exit in closed PR #9.
- No tests exist for MenuBarShell, LauncherPanel, StatusIcon, or the NSOpenPanel flow (grep of LauncherKit/Tests). The shell is verified only by hand or by the unmerged verify skill.
- `git log --follow` on SystemPermissions.swift shows only 18acef7. The file was a rename of SystemAccessibilityPermission.swift (1cf9c4b), and rename detection did not link them. The `prompt()` → `ask(.accessibility)` code is from 1cf9c4b in substance.

### Additional Leads (for the Plans investigator)
- `plans/001-trackpad-launcher-app/plan.md`, `development-logs.md`, and `.temp/architect/checks/status-item-and-hardened-runtime.md`, plus `.temp/architect/grounding/probes/activate-probe/` (driver.swift, target.swift, output.txt with an `applicationShouldHandleReopen` / NSApplicationDelegate probe). All committed in 1cf9c4b, and likely the rationale for the status item, the non-activating panel, the closing paths and activation.
- `plans/002-gesture-click-blocking/plan.md`, `development-logs.md`, `.temp/architect/grounding/why.md`: from the pre-squash commit b43619b "S2: Accessibility permission, first-launch prompt, held window, live hint". Likely the source of `.heldOpen` and first-launch-only prompting.
- `plans/003-dropdown-recents-performance/`: cited by docs/performance.md as why the window content is kept ("Plan 003 keeps pickers instant on every open").
- `plans/008-recent-apps-switcher/plan.md` and `development-logs.md`: a17f139 edited both (13 lines in plan.md, 4 in the log) for "Swipe works while Trackpad Launcher itself is active".
- `plans/017-launch-wait-bounce/`: introduced the NSEvent monitor confinement (a068ed5).
- PR #25 and #26 came from `claude/*` branches, not `feature/NNN`, so there are probably no plans for the Quit move or the "settings window" redesign. A Figma link is in PR #26's body: https://www.figma.com/design/EB5ptBWZnAot7J3vx3cYLw/TapLauncher?node-id=2067-6790 (outside source control).
- Claude session links in commits: 8a72f8e/c49c12c/22d059a `https://claude.ai/code/session_01UiUwasNcMidaLLfjWy87uh`; 997a42f `https://claude.ai/code/session_01Fw6qQacjfqPSL7XJeQf2DR` (external, not followed).
