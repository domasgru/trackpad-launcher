# Why: lifecycle shell. Source: Plans

Investigator: plans. Repo root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle`. All paths are relative to it. `research/` was not read. Plan 021 was read only for its problem statement, R15–R17, its non-goals and its development log.

## What I searched

- Listed `plans/` (001–017 and 021 in the tree). Ran `git log --all --name-only -- plans`. Plan dirs ever committed on any branch: 001–018 and 020. **No plan dir exists for 019, or for PRs #22, #24, #25 or #26.** 018 (thumb-edge guard) and 020 (swipe-click cursor drift) touch nothing in the lifecycle.
- Read in full: `plans/001-trackpad-launcher-app/plan.md` (Requirements R1–R23, Non-goals, Design, Synthesis, Tradeoffs, Alternatives, Open questions, Testing, Slices), `001/development-logs.md`, `001/.temp/architect/grounding/index.md` Q6–Q10, `001/.temp/architect/checks/status-item-and-hardened-runtime.md`, `001/.temp/architect/grounding/probes/README.md`, and `activate-probe/{run.sh,output.txt}`.
- Read in full: `plans/002-gesture-click-blocking/plan.md` (requirements, design decisions 1–8, Launcher sketch, shell mapping, synthesis, tradeoffs, alternatives, open questions) and `002/development-logs.md`.
- Read the relevant sections of 003, 004, 006, 008 (and its full dev log), 009 (and its full dev log), 010, 012, 014 and 017.
- Greps across `plans/0*/{plan.md,development-logs.md,design.md,testing.md}`:
  - `login|SMAppService|LaunchAgent|launch at`
  - `Trackpad Launcher itself|own pid|processIdentifier|accessory|LSUIElement|activationPolicy|menu bar app`
  - `release\.sh|notar|Developer ID|--deep|Gatekeeper|quarantin|/Applications`
  - `NSOpenPanel|Other… (chooser|file)|chooser`
  - `global monitor|addGlobalMonitor|outside click|resign|dismissWindow|nonactivating|canBecomeKey|status item|right-click|Quit`
  - `confine|onlyIn|SourcePolicy|source scan`
  - `never active|hidesOnDeactivate|NSApp\.activate|takes? focus|key window`
  - `first launch|first-launch|prompt`
  - `App Nap|NSSupportsAutomaticTermination|fast user|single instance|second instance`
  - `window (closes|close)|closes the (launcher )?window|launcher window`
- Grepped the plan 001 architect candidates (`.temp/architect/candidate-1.md`, `candidate-2.md`, `task.md`, `rubric.md`) for `monitor|nonactivating|NSApp.activate|resign|popover|LSUIElement|login`.
- Read `plans/006-.../.temp/architect/grounding/index.md` F1/F2 and `probes/frontmost-probe/output.txt`.
- Grepped `plans/012-.../.temp/architect/grounding/how-shell.md` for activation, monitor and key terms.

---

## Direct evidence

### A. Why a menu bar app (plan 001)

1. **Requirement R1.** `plans/001-trackpad-launcher-app/plan.md` § R1 "Menu bar presence only": "Trackpad Launcher MUST appear as an icon in the menu bar and nowhere else: no Dock icon, no entry in the ⌘-Tab app switcher." *(Requirement. It states no reason.)*
2. **Solution.** Same plan, § Solution: "The app lives in the menu bar only. Its window shows the four gestures, each with an app picker, and a hand-mode toggle. It starts at login, needs no permissions, never touches the network, and idles at zero cost."
3. **Problem statement.** Same plan, § Problem statement: "A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled." This frames the menu bar as a given ("earns a place in the menu bar"). It argues for low cost, not for the menu bar over other shapes.
4. **Mechanism.** Same plan, Design § Build: "Info.plist `LSUIElement = YES`". Trace row: "R1 | App target `LSUIElement` | manual". Grounding Q8 (`001/.temp/architect/grounding/index.md`): "**sourced** (Apple Info.plist key reference): `LSUIElement = true` keeps the app out of the Dock and ⌘-Tab while allowing a status item."
5. **Why `NSStatusItem` + `NSPanel` and not `MenuBarExtra` or `NSPopover`.**
   - Plan 001 Design § Problem: "`MenuBarExtra` cannot open or close its window programmatically, so the launcher window is an `NSStatusItem` plus an `NSPanel` hosting SwiftUI on Liquid Glass (Q8; the macOS 27 expanded-interface session API is not in SDK 26.5, see checks)."
   - Alternatives considered: "**`MenuBarExtra(.window)` or `NSPopover` as the shell.** The first cannot be opened or closed programmatically (R18, R3); the second adds an arrow and chrome the design does not have, with the same status-click wrinkle."
   - Grounding Q8: "R18 (open on first launch) and R3 (a gesture closes the open window) need programmatic open/close, so a custom `NSStatusItem` + `NSPanel` hosting SwiftUI is the fit; `MenuBarExtra` is not."
   - `001/.temp/architect/checks/status-item-and-hardened-runtime.md`: "`NSStatusItemExpandedInterfaceSession` … is a macOS 27 API. Consequence for the design: at deployment target macOS 26 the status item uses the classic `button.target/action` toggle plus an `NSPanel`; close-on-click-outside comes from key-window resignation, Escape from the panel's `cancelOperation(_:)`."
   - 001 dev log, Plan: "Verification: `NSStatusItemExpandedInterfaceSession` (the modern status-item API the macOS skill recommends) is absent from SDK 26.5 → classic button action + `NSPanel` with resign-key guard and a mouse-down monitor while open; recorded in `checks/`."
   - Candidate-2 (`001/.temp/architect/candidate-2.md`): "**`NSPopover` from the status item.** Gives transient dismissal and Escape for free, but the arrow and popover chrome do not match the arrowless card in the design … Rejected."
6. **Why `.nonactivatingPanel`.**
   - `001/.temp/architect/candidate-2.md` (LauncherPanel sketch): "`.nonactivatingPanel` lets it become key (so the picker and toggle work) without activating this LSUIElement app."
   - Grounding Q8: "an `NSPanel` with `.nonactivatingPanel` can become key without activating the app; `NSWindow.didResignKeyNotification` fires when the user clicks elsewhere (R3 'click outside closes')".
   - Plan 001 sketch: "Borderless, non-activating, key-capable; pop-up-menu level; joins all Spaces and full-screen apps."

### B. Why the panel closes on outside click / resign key / global monitor (plan 001 R3)

1. **Requirement R3.** `001/plan.md` § R3: "The window MUST close when the user clicks outside it or presses Escape. Clicking the icon while the window is open MUST close it. A gesture that fires while the window is open closes the window as the target app comes to the front." *(Requirement. The plan gives no product reason for close-on-outside-click. It reads as standard menu-bar-popover behaviour taken from the design.)*
2. **Dev log origin of "gesture/icon click closes".** `001/development-logs.md` § Specify: "Window behaviour when a gesture fires or the icon is clicked while open was unspecified → R3: both close the window."
3. **Close-on-outside-click made a scenario unreachable.** Same log: "R15 'notice disappears live' was unreachable because the window closes on click outside → scenario now reopens the window; requirement says the next showing has the hint."
4. **Mechanism and its cost argument.** `001/plan.md` MenuBarShell sketch:
   - "panel resigns key → launcher.closeWindow(), unless NSApp.currentEvent is a mouse-down in the status item's button window (that click is the toggle above; otherwise it would close and reopen)"
   - "mouse-down elsewhere → global monitor [.leftMouseDown, .rightMouseDown, .otherMouseDown], installed on show and removed on hide (no idle cost; mouse-only monitors need no permission)"
   - § Deliberately not done: "No key-event monitors; the only global monitor is mouse-down and exists only while the window is open."
5. **Where the resign-key guard came from.** § Synthesis decision "Grafted from candidate-2: … the resign-key guard for the status-button click". Candidate-2 tradeoff: "the status-button click wrinkle (resign-key firing before the toggle) is handled with an event guard in the shell rather than the macOS 27 expanded-interface session API, because the deployment target is macOS 26."
6. **Window as model state.** Decision 8: "*Window visibility is model state* (`isWindowOpen`): R18 opens and R3 closes it from the core, so both are testable; the shell maps AppKit signals to `openWindow()`/`closeWindow()` and renders the state."
7. **Open question left for E2E.** § Open questions: "**Window behaviour to confirm in E2E.** Is closing and reopening the window around Other… acceptable? Does the resign-key guard make an icon click while open close (not close-then-reopen)? Does the `NSPopUpButton` picker open correctly inside a non-activating panel …?"
8. **Close-on-outside-click broke the first-launch window and forced "heldOpen" (plan 002).**
   - `002/plan.md` Design § Problem: "the shell closes the launcher window on any outside mouse-down and whenever the panel resigns key, so the system's Accessibility prompt (another process, which takes focus and whose buttons are outside clicks) would close the first-launch window and break R10".
   - Decision 6: "The shell now sends two kinds of close: explicit closes (icon click, Escape, and the window's own System Settings buttons) call `closeWindow()`; soft closes (an outside click, the panel resigning key) call `dismissWindow()`, which a held window ignores. The hold ends at the first explicit close, a fired gesture, or a grant … Without the hold, R10 fails as soon as the prompt appears."
   - Launcher sketch doc comment: "`.heldOpen` is the first-launch window under the system's Accessibility prompt. The prompt takes focus when it appears, and its buttons are outside clicks; both would close an ordinary window before the user saw the hint (R10)."
   - 002 dev log, Plan: "Cross-judge … candidate-2 opened the first-launch window after the prompt, but the shell closes the window when the panel resigns key or an outside click lands, so the system prompt would close it and R10 would fail on hardware → candidate-1's held window kept (`closed | open | heldOpen`, `dismissWindow()` for soft closes)."
   - Also: "Cross-judge: candidate-1's held window could sit over System Settings → a grant closes a held window; the window's own settings buttons close it explicitly before opening a pane."
   - Tradeoff: "We accept that the first-launch window, held open under the prompt, ignores outside clicks until the user closes it from the icon or with Escape, grants access, or fires a gesture. In exchange, R10 holds."
   - Alternative rejected: "**Opening the window only after the prompt is dismissed.** Nothing observable tells the app when the system alert closes, so the window would need a timer or a heuristic over other apps' activation. The hold needs neither."
9. **Plan 021's restatement of the problem.** `021/plan.md` § Problem statement: "The window hangs under the icon and closes at any outside click, so the user loses it while trying a gesture or picking an app with *Other…*. Quit hides in the icon's right-click menu."

### C. Gestures and swaps close the launcher window: how it was decided and why

1. **Plan 001.** R3 (quoted in B1). The dev log says it was filled in because it "was unspecified" (B2). The fire path sketch reads: `isWindowOpen = false   // R3: the window closes as the target app comes to the front`. Decision 5: "If all pass it plays feedback on `event.trackpad`, brings the app to front and closes the window." Test T25: "R3 'closes the window as the target app comes to the front' (no target, no close)". In other words, a silent gesture does not close the window.
2. **Plan 004 R4 scenario** (`004/plan.md` lines 67–70): "Pointer over the launcher window … **THEN** the window closes, and the icon animates at the pointer."
3. **Plan 009 R15** (`009/plan.md` § R15 "A swap closes the launcher window"): "A swap that brings an app to front MUST close the launcher window if it is open, as a gesture does." The only stated reason is parity ("as a gesture does"). 009 dev log, Specify: "Rejected: … folding R15 into R2."
4. **Plan 008 decision 4** (switcher lift): "the gesture haptic plays, the app is brought to front through the unchanged `bringToFront` … and the window closes". Plan 008 T13: "T13 never checked 'the window is as it was' → it opens the window and asserts it stays open" (a silent lift leaves the window open).
5. **Plan 012, the one stated rationale found.** `012/plan.md` § Tradeoffs accepted: "We accept that a lift that changes the window in front closes the launcher window, as the swipe's lift does, because a key launcher window would otherwise keep the keyboard from the raised window." *(This is the only plan text that gives a technical reason for closing the launcher window on an action. It is about keyboard focus held by the key, non-activating panel.)* In the same plan, § Synthesis "From candidate-3: … closing the launcher window on the ask" and the scoring note "[candidate-3] closes the launcher window on the ask, neither asked for".
6. **Plan 017 R16**: "The launcher window MUST close on the gesture as today."
7. **Reversal in plan 021 R15**: "A gesture, a swipe, a window swipe or a swap that fires while the settings window is open MUST leave the window open. The app it brings to front comes over the window."

### D. Why Trackpad Launcher is never the frontmost app / never a running app (plans 004, 006, 008, 009, 010, 012)

1. **Plan 004 (launch overlay)**:
   - R13: "Showing it MUST NOT take focus from any app". Scenario: "**THEN** Arc becomes the active app, and Trackpad Launcher never does".
   - Panel recipe: "`hidesOnDeactivate` off, because the app is never active".
   - Port doc: "Nothing it shows activates Trackpad Launcher, becomes key or receives a click."
   - Manual check (b): "Trackpad Launcher never shows as the active app."
2. **Plan 006 decision 6**: "`frontmostApp() -> URL?` returns the active app's bundle location, or nil when there is none or when it is Trackpad Launcher itself. … F1 shows a frontmost app always exists in practice; F2 shows self is possible only while the Other… chooser is up."
   - Grounding F2 (`006/.temp/architect/grounding/index.md`): "**sourced** (`LaunchOverlay.swift`, `makePanel` comment 'The app is never active, so it never deactivates either'; `LauncherPanel.swift` `styleMask: [.borderless, .nonactivatingPanel]`; `MenuBarShell.makeActions` `chooseOtherApp` calls `NSApp.activate()` only around the `NSOpenPanel`): Trackpad Launcher never activates except while the Other… file chooser is up."
   - Port comment (006 plan line 1064): "Launcher itself (which never activates except around the Other… chooser, F2)."
   - Open question: "When the frontmost app cannot be read (or is Trackpad Launcher itself, only while Other… is open), the swipe shows nothing. Is that right …?"
3. **Plan 008 R1**: "Trackpad Launcher never comes to the front, so it is never frontmost and never in the row." Scenario "Menu bar apps are left out": "… that app is not in the row, and Trackpad Launcher is not in the row".
   - Decision 1: "`frontmost`, the active app as an `AppEntry` (nil when there is none, it has no bundle identifier or location, or it is Trackpad Launcher itself, exactly as the old read)".
   - Decision 2: "An entry is kept only when its type is `Foreground`, its pid is not this process and all three bundle fields are present; the probe showed the array never holds anything else, so the two filters are guards against a future macOS, not today's behaviour." Also: "`keep where ApplicationType == "Foreground" && pid != getpid()`" and "The frontmost app keeps its public read (`NSWorkspace.frontmostApplication`, own process excluded)".
   - Dev log, Plan: "`apps` might carry a menu bar app or Trackpad Launcher after one had been in front → the membership probe (`.temp/.../membership.swift`) showed the array holds only `Foreground` apps even after an accessory app activated itself; the keyed read now asks for the application type and pid and filters both as guards".
4. **Plan 008 R14** (added by a fix): "**R14. The switcher works while Trackpad Launcher itself is active.** macOS makes Trackpad Launcher the active app right after it is opened, from Finder or by Run in Xcode. While it is, the row MUST be the running apps alone, in ⌘-Tab order, with the selection on the most recently used one."
   - Dev log § "Fix: the first swipe after opening the app did nothing": "Reported by the owner: after a rebuild the swipe did nothing until a tap gesture had fired. Reproduced by watching the active app across Xcode's Run: Trackpad Launcher stayed the active app afterwards. The switcher skipped itself as frontmost, so no row was built. A tap brought another app forward, which hid the problem. Opening the app from Finder does the same. → R14: with no readable frontmost app the row is the running apps alone, starting on the most recent".
5. **Plan 009 R2**: "When there is no frontmost app, as while Trackpad Launcher itself is active, the swap MUST bring the most recently used running app to the front." Scenario: "**GIVEN** Trackpad Launcher was just opened from Finder and is active … **THEN** Finder comes to the front, since there is no frontmost app". Dev log: "Scenario 'Trackpad Launcher is active' was self-contradictory → corrected to bring Finder to front."
6. **Plan 010 R5**: "When there is no frontmost app, as while Trackpad Launcher itself is active, the row MUST be the running apps without a gesture alone, up to 10".
7. **Plan 012 R13**: "or there is no frontmost app (as the glossary defines it, such as while Trackpad Launcher itself is active), the slide MUST NOT be a window swipe." Sketch: "`case noApp` — There is no active app, or it is Trackpad Launcher itself."
8. **Plan 021 R15** keeps the rule: "Trackpad Launcher MUST never count as a running app or as the frontmost app for the switcher or the swap. With the settings window in front, the switcher's row and the swap MUST work from the app that was in front before it, as the glossary's *Frontmost app* says." 021 dev log: "Switcher and swap with the settings window in front were unstated → Trackpad Launcher never counts as a running or frontmost app (R15)." Note the change: today the rule falls back to "no frontmost → running apps alone". Plan 021 asks for "the app that was in front before it".

### E. Login items / SMAppService

**This contradicts the question's premise.** Plans 001–017 all specify login-item registration on first launch, and they never discuss leaving it out. No plan text says registration was removed. (Code read for orientation only: `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:89-90` has `public func registerLoginItem() { try? SMAppService.mainApp.register() }`, and `LauncherCore/Launcher.swift:108` calls `system.registerLoginItem()`.)

1. **Plan 001 R17 "Starts at login"**: "On first launch, Trackpad Launcher MUST register itself to open at login. It MUST keep running in the background until the user quits it or logs out." Scenario: "**GIVEN** the user turned Trackpad Launcher off under Login Items **WHEN** the user logs in **THEN** the app does not start, and the app does not re-enable itself on its next manual launch".
2. **Plan 001 R19 "Quit"**: "The Quit button MUST quit Trackpad Launcher immediately: the icon leaves the menu bar and gestures stop. Quitting MUST NOT remove the login item." Shell sketch: "Quit (R19): NSApp.terminate(nil); the login item is untouched." Candidate-2: "`public func quit() { source.stopAll(); terminate() }` // R19; never touches the login item".
3. **Plan 001 decision 7**: "*First launch is derived, not flagged:* it is a first launch exactly when no settings record is stored. `start()` registers the login item before its first save, so a crash between the two re-registers next time (registration is idempotent) instead of losing the item; an undecodable record loads as defaults, not as a first launch, so a user who turned the item off is never re-enrolled (R17)."
4. **Plan 001 dev log**, Plan: "Cross-judge: candidate-2 saved the 'launched before' flag before registering the login item (a crash in between loses the login item for good) and treated an unreadable settings blob as a fresh install (would re-enrol a login item the user turned off) → first launch derived from the absence of a record; register before the first save; undecodable data loads as defaults." Also "Test planner: register-before-save order (decision 7) was unobservable … → `onRegisterLoginItem` hook added". Implement: "Review (rejected): assertions on `hardware.running` and `loginItemRegistrations` → kept".
5. **Grounding Q9** (`001/.temp/architect/grounding/index.md`): "`SMAppService.mainApp` (macOS 13+) with `register()`, `unregister()`, `status`; 'Apps that use SMAppService APIs must be code signed'. Registering the main app is what adds 'Open at Login' under Login Items; macOS posts its own 'login item added' notification (R17). The requirement that the app not re-enable itself after the user turns it off (R17 scenario 2) is met by registering only on first launch, gated on the persisted first-launch flag".
6. **Plan 001 tradeoff**: "We accept that first launch is derived from the absence of a settings record, so a user who deletes the app's preferences gets a first launch again, including the login item."
7. **Plan 001 open question**: "**Signing.** No Developer ID Application certificate is installed … Is a login item registered by an Apple Development-signed debug build acceptable on the developer's machine?" Candidate-2 raised the same: "should Debug skip registration behind a build flag?"
8. **Plan 002 decision 6**: "`start()` calls `prompt()` before the first save, next to the login item and for the same crash reason". Sketch: "Both effects come before the first save: a crash in between repeats them next time, never loses them."
9. **Later plans keep it unchanged**:
   - 005 T7/T10 expect `loginItemRegistrations` 0 on upgrade or empty records.
   - 006 T33 and the sketch "bringToFront, registerLoginItem, … : unchanged".
   - 012 sketch "registerLoginItem(), …".
   - 017 sketch "bringToFront, registerLoginItem, runningApps, frontmostWindows, raiseWindows: as today."
10. **Plan 003** assumes a login item in its verification: "with the Release build installed in /Applications and registered as a login item" (§ verification R1), and "Installed in /Applications, Trackpad Launcher is listed like any app and is launched at every login" (§ Further notes).
11. **No unregistration anywhere.** Grep found no `unregister` call in any plan sketch. Only grounding Q9 mentions that `unregister()` exists.

### F. First launch and the Accessibility prompt

1. **Plan 001 R18**: "On first launch Trackpad Launcher MUST open the launcher window without the user clicking the icon. Later launches MUST NOT open it." Composition-root comment: "status item first: a first-launch window needs its anchor".
2. **Plan 001 R20 "No permissions"**: "Trackpad Launcher MUST work without asking the user for any system permission (no Accessibility, Input Monitoring or other prompt)." Non-goal: "**Working with *Tap to click* on.** The app requires it off instead of fighting the system's own clicks; this keeps the app free of permissions."
3. **Plan 002 reverses R20.** § Solution: "Trackpad Launcher asks for the Accessibility permission on first launch. With it, clicks are blocked for the first 3 seconds after the thumb lands in the anchor corner." Intro: "Its R20 'No permissions' is replaced by R9 here. The reason in its non-goal 'Working with Tap to click on' no longer holds, because the app now asks for one permission."
   - R9: "Trackpad Launcher MUST NOT ask for any permission other than Accessibility. Every feature except click blocking MUST work without it."
   - R10: "On first launch Trackpad Launcher MUST show the system's Accessibility prompt once, unless access is already granted. Once the prompt is dismissed, the launcher window MUST be open, showing the Accessibility hint if access was not granted. Later launches MUST NOT show the prompt." Scenario "Second launch": "**GIVEN** the user dismissed the prompt on first launch **WHEN** the app starts at login **THEN** no prompt appears".
   - Non-goal: "**Prompting installs that already launched an earlier build.** The prompt appears only on first launch. Such installs see only the hint."
   - Alternative rejected: "**A stored 'prompted' flag.** A second boolean that must stay in sync with first launch".
4. **The prompt key and strict concurrency.** Plan 002 Design: "`kAXTrustedCheckOptionPrompt` imports as a global `var` that strict concurrency rejects, and its value is `"AXTrustedCheckOptionPrompt"` (checked)". Dev log: "→ the adapter spells the key out".
5. **Plan 012** merges the permission ports. "`Permissions` … `ask(_ permission: Permission)` — The system's prompt for it. Returns at once; the prompt belongs to another process." Sketch: "the first-launch prompt becomes permissions.ask(.accessibility)". `SystemPermissions.ask`: "`.accessibility: AXIsProcessTrustedWithOptions with the prompt key. .screenRecording: CGRequestScreenCaptureAccess()`." Screen Recording is never asked on first launch. 012 R8: "The first press MUST ask macOS for the permission"; Solution: "The window swipe itself never prompts."
6. **Open question in plan 002**: "Are Debug (Apple Development) and Release (Developer ID) builds separate TCC clients that each need their own grant? Manual; affects only development."

### G. The Other… chooser as `NSOpenPanel`

1. **Plan 001 R5**: "*Other…* MUST open a file chooser that only accepts applications." Grounding Q7: "`NSOpenPanel` … `allowedContentTypes = [.application]` with `canChooseDirectories = false` lets only application bundles be chosen".
2. **Plan 001 shell sketch**: "Other… (R5): closeWindow(); NSApp.activate(); NSOpenPanel(allowedContentTypes: [.application], canChooseDirectories: false).begin { url → setAssignment(.appBundle(at:)) }; then openWindow()." Row sketch: "chooseOther: { actions.chooseOtherApp(row.gesture) }) // NSOpenPanel lives in the shell".
3. **Plan 001 tradeoff (the reason)**: "We accept that Other… closes the launcher window, runs `NSOpenPanel` with the app activated, then reopens the window, in exchange for not fighting window levels and resign-key dismissal while the chooser is up." Candidate-1 says the same: "This avoids fighting window levels and resign-key dismissal while the chooser is up."
4. **Plan 001 Implement log**: "Review (standards, rejected): the shell opens System Settings with `NSWorkspace` and owns the Other… close/reopen flow → kept, per the Plan's rejection of `openURL`/`terminate` in the hub."
5. **Plan 006** keeps the flow for Add app…: "'Other…' closes the window, activates the app, shows the file chooser accepting only applications; … reopens the window". Sketch: "`LauncherActions.chooseOtherApp` … close, activate, NSOpenPanel, completion, reopen."
6. **Plan 021 R16 reverses it**: "Choosing *Other…* in an app picker MUST show the file chooser attached to the settings window, which stays open."

### H. Release and distribution (plan 001; no later plan before 021)

1. **Plan 001 R23**: "Trackpad Launcher MUST run on macOS 26 and later on Apple silicon and Intel Macs. It MUST be distributed as a direct download, signed with Developer ID and notarized, so it opens without Gatekeeper warnings."
2. **Non-goals**:
   - "**Mac App Store distribution.** The sandbox does not allow what the app needs to read trackpad touches."
   - "**Automatic updates.** Update checks are network calls; the app makes none."
3. **Design § Build**:
   - App target: "hardened runtime, no sandbox, no entitlements; `Config/Debug.xcconfig` signs with Apple Development, `Config/Release.xcconfig` with Developer ID Application".
   - "`Scripts/release.sh`: `xcodebuild archive`, export with the developer-id method, `notarytool submit --wait`, `stapler staple`. Blocked until a Developer ID certificate exists; Apple Development signing is enough for `SMAppService` locally."
4. **S6 acceptance**: "[ ] The release script is the only path that signs the release; `--deep` is not used and the main executable is signed last (per `docs/architecture.md`)." All S6 boxes are unticked in the plan.
5. **Checks file** (`001/.temp/architect/checks/status-item-and-hardened-runtime.md`): "Library validation allows libraries signed by Apple, so `dlopen` of `/System/Library/PrivateFrameworks/MultitouchSupport.framework` needs no exception and no entitlement. Do not add `--deep` when signing; sign the main executable last with `-o runtime`."
6. **Implement log**: "universal binaries need the generic macOS destination, which `release.sh` uses"; "bundle ID `com.domasgru.TrackpadLauncherApp` (the plain ID is taken by an older experiment on this Mac)".
7. **Plans 002–017**: no plan changes distribution. 017 mentions only the Gatekeeper prompt for *launched target apps* (R11).

### I. Architecture rules a new lifecycle module must follow (from plans)

1. **Plan 001 decision 9**: "*Rules are enforced by structure.* `LauncherCore` cannot import AppKit, IOKit or the private framework. `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit." 001 Implement log: "`SourcePolicyTests` fails on any LauncherCore import other than Foundation and Observation, with a planted-import self-check" and "the visit check asserts `TrackpadLauncher/` was scanned".
2. **Plan 001 banned tokens (initial)**: logging (`print(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os`), network (`URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`), own files (`FileHandle(forWriting`, `.write(to:`, `createFile(atPath`), timers (`Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`), and permissions (R20). T22 adds `nonisolated(unsafe)` "for the one-writer rule".
3. **Plan 001 R21**: "It MUST write nothing to disk of its own except its settings (assignments, hand mode, whether it has launched before); files macOS writes on every app's behalf do not count." *(Constraint on any move-to-/Applications file copy in a redesign: the `.write(to:` / `createFile(atPath` / `FileHandle(forWriting` bans.)*
4. **Plan 002 constraint list** (Design § Problem): "one `@MainActor @Observable` `Launcher` owns every decision; every port has exactly two adapters; policy is pure and lives in `LauncherCore`, which imports Foundation and Observation only; … one idempotent `reconcile()` …; the frame timestamp is the only clock; no timers, no polling; rules are enforced by the source-policy gate."
5. **Plan 001 task.md** (architect brief): "Platform adapters, each behind a small interface with a real adapter and an in-memory adapter (per 'one adapter means a hypothetical seam, two means a real one', name the test adapter)". Rubric: "Each platform dependency (… persistence, login item) sits behind an interface with one real and one in-memory adapter".
6. **Plan 001 Synthesis**: "Rejected from candidate-2: … the seven-protocol split with `openURL`/`terminate` closures in the hub (shell actions carry no policy)". Plan Red-flag: "candidate-2's seven one-method protocols plus `openURL`/`terminate` closures in the hub rejected as a larger surface with no added policy." *(Quit/terminate was kept out of the model on purpose.)*
7. **Confinement evolution**:
   - Plan 002 decision 8 made the policy two lists, banned and confined: "`AXIsProcessTrusted` and `notify_register` only in `SystemAccessibilityPermission.swift`; `tapCreate` and `CGEventTapCreate` only in `ClickTap.swift`".
   - Plan 006: `scrollWheel` confined to `ClickTap.swift`.
   - Plan 012 (§ line 1317): "Confined, each to one file: `AXIsProcessTrusted`, `notify_register` and `ScreenCaptureAccess` … to `SystemPermissions.swift`; `AXUIElement` … and `CGWindowList` to …". Also "the source scan matches comments, so no other file may spell a confined name, even in a doc comment." 012 dev log: "the source scan reads comments, so a core doc comment naming a confined API would fail it".
   - Plan 017 § Docs and source policy: "`Confined.onlyIn` becomes a `Set<String>`. … `addGlobalMonitorForEvents` is confined to `MenuBarShell.swift` and `BounceOverlay.swift`. `addLocalMonitorForEvents` is confined to `BounceOverlay.swift`." Synthesis: "`addGlobalMonitorForEvents` is confined too, so every reader of pointer events is named." *(Any rename or removal of `MenuBarShell.swift` touches this confinement row.)*
   - Plan 004 bans display links: "`SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule 'timer'".
   - Plan 008: the two private LaunchServices symbols are confined to the LaunchServices order's file.
8. **Plan 001 decision 8 / 002 decision 6**: window visibility belongs to `Launcher` (`closed | open | heldOpen`), and the shell maps AppKit signals to intents.

### J. Startup ordering and startup cost

1. **Plan 001 composition root**: `MenuBarShell(...)` comes before `launcher.start()` "status item first: a first-launch window needs its anchor". 001 Implement log: "the panel falls back to top-right until the status item has a frame (a first-launch off-screen bug found in S4)".
2. **Plan 003 § Startup cost (accepted)**: "The first scan and the first icon pass run before the menu bar icon appears. Launch gets about 0.3 s longer with warm caches, and up to 1–2 s on a cold login. **Why it is acceptable.** At login nobody waits for a menu bar app. On a first launch, the window appears that much later." 003 dev log: "The first open could find an empty list (first-launch window, cold login), which R1 forbids … → `Launcher.init` reads the list synchronously and the shell's first icon pass runs and is waited for before the run loop starts".
3. **Plan 014 non-goal**: "Startup cost (about 1 s of CPU in the first second after launch), paid once per login."

### K. #25 and #26 (Quit to right-click menu; window design)

- **No plan exists** for #25 or #26. `git log --all -- plans` shows no plan dir past 020, and 019 is missing. Grepping plans for `right-click` found only plan 006 (switcher list "Remove" context menu) and plan 021.
- The only plan text on these PRs' outcome is plan 021's problem statement: "Quit hides in the icon's right-click menu."
- Plan 001's R3/R4 put Quit in the window: "a Quit button" and "the bottom bar holds only Quit". Plan 006 R22 kept it reachable: "the hand-mode toggle, the hint and Quit are reachable". Plan 008 dev log: "The launcher window's height cap would clip Quit with no scrolling region left → the cap goes."

### L. Probes that tested activation

1. **`plans/001-trackpad-launcher-app/.temp/architect/grounding/probes/activate-probe`** (`run.sh`, `driver.swift`, `target.swift`, `output.txt`).
   - **What it tests.** It drives `NSWorkspace.openApplication(at:configuration:)` with `activates = true` from a background CLI against a throwaway `TLProbeTarget.app`. It tests *bringing other apps forward* (R12). It does not test Trackpad Launcher's own activation policy.
   - **Machine** (probes README): "macOS 26.6.2, Mac15,6, 2026-10-09".
   - **Findings**, quoting `output.txt`:
     - "1. launch (not running) … [launch] instances=1 isActive=true"
     - "2. hide … [after-open] instances=1 isActive=true isHidden=false"
     - "4. close the only window, then open (expect reopen hasVisibleWindows=false)". The target log shows "reopen hasVisibleWindows=false".
     - "5. already active: open again". The target log shows "reopen hasVisibleWindows=true … frame=(200.0, 200.0, 320.0, 208.0)" (frame unchanged).
     - "6. quit, then open twice within 50 ms … open[double-1] -> pid=37541 … open[double-2] -> pid=37541 … [double] instances=1".
   - Grounding Q6 conclusion: "this one call reproduces the Dock-click contract of R12 from a process that is not active (macOS 14+ cooperative activation does not block it), and is idempotent under a double tap." Also: "**sourced** (`NSWorkspace.h` line 175): `createsNewApplicationInstance` defaults to NO, 'prefers to reuse a running instance'."
   - **Indirect relevance to the redesign.** The probe shows LaunchServices sends a *reopen* event (`applicationShouldHandleReopen`) to an already-running app when it is opened again. It also shows two near-simultaneous opens yield one pid. Both bear on "opening the app while it runs opens the settings window" and on single-instance handling. The probe did not test this for Trackpad Launcher itself, an `LSUIElement` app, or Finder/Spotlight opens.
2. **`plans/006-five-finger-tap-and-corner-swipe/.temp/architect/grounding/probes/frontmost-probe/output.txt`**: "frontmostApplication: bundleIdentifier=com.google.Chrome … activationPolicy=0 isActive=true … activations seen: 0". Its header says "0 is 'not observed', not 'never fires'".
3. **Plan 008 membership probe** (`008/.temp/planner/probes/switcher-order-probe/membership.swift`, via the 008 dev log): "the array holds only `Foreground` apps even after an accessory app activated itself". I did not open the probe source. This finding comes from the dev log and plan text.
4. **Plan 017 F8** (`017/.temp/architect/grounding/index.md`, seen in grep only): "a second `openApplication` 150 ms into a launch starts no second instance; its completion arrives when the app finishes launching, with the same pid."

---

## Indirect / circumstantial evidence

- **"hidesOnDeactivate off, because the app is never active"** (plan 004 recipe). The same assumption is repeated in the 012 shell grounding for `SwitcherPanel`. The panels' `hidesOnDeactivate = false` rests on the app never being active. A redesign that makes the app a regular, active Dock app while the settings window is open changes that premise. That is an inference from the stated reason. No plan discusses it.
- **The "never frontmost" rule was first a consequence of activation, then a filter.** Plans 004 and 006 describe it as a fact ("the app is never active"; F2 "never activates except while the Other… file chooser is up"). Plan 008 turned it into explicit code filters ("own process excluded", "`pid != getpid()`") "as guards". After the owner's report, plan 008 R14 then admits the app *does* become active when opened from Finder or Xcode. Reading: the exclusion survives because it is filtered, not because the app is never active.
- **R3's close-on-outside-click looks like inherited menu-bar-popover convention.** It is not argued for in any plan. The dev logs show it caused downstream fixes: the unreachable R15 scenario in 001, `heldOpen`/`dismissWindow` in 002, and the Other… close/activate/reopen dance in 001 and 006. A different reading: it is simply what R3 asked for, and the fixes are routine consequences. Nothing shows it was felt as a problem before plan 021.
- **Plan 012's keyboard-focus rationale** (C5) is specific to a key, non-activating panel. It suggests the close-on-gesture rule partly protects keyboard focus for the raised app. Plan 021 R15 keeps the window open but makes it an ordinary window. Whether the focus concern carries over is not discussed in plans 001–017.
- **Login item tied to "first launch = no stored record".** Plans 001, 002, 003, 005, 006, 012 and 017 all keep `registerLoginItem` and the first-launch derivation. Plan 021 R12/R13 (Quit turns login off; never re-enable a user's System Settings choice) extends the R17 rule "the app does not re-enable itself". It replaces R19's "Quitting MUST NOT remove the login item".

## Contradictions

1. **Premise vs plans.** The question says "no login-item registration in code". Plans 001–017 specify and keep `registerLoginItem()` → `SMAppService.mainApp.register()` on first launch (E1–E9), and current code still has it (`WorkspaceActions.swift:89-90`, `Launcher.swift:108`). No plan removes it.
2. **"Never active" vs "active after open".**
   - Plan 004 says "`hidesOnDeactivate` off, because the app is never active".
   - Plan 006 F2 says "Trackpad Launcher never activates except while the Other… file chooser is up".
   - Plan 008 R1 says "Trackpad Launcher never comes to the front, so it is never frontmost".
   - Against these, plan 008 R14 says "macOS makes Trackpad Launcher the active app right after it is opened, from Finder or by Run in Xcode", and the 008 dev log "Fix" section reports this as a bug. Plans 009, 010 and 012 then cite "while Trackpad Launcher itself is active" as a real case.
   - Plan 008 R1 and R14 sit in the same plan and disagree.
3. **Plan 001 R20 "No permissions" vs plan 002 R9/R10.** These are explicitly superseded. 002: "Its R20 'No permissions' is replaced by R9 here."
4. **Window closes on System Settings buttons (002) vs stays open (021).** Plan 002 dev log: "the window's own settings buttons close it explicitly before opening a pane". Plan 021 R17: "MUST open System Settings and leave the settings window open."
5. **Quit and the login item.** 001 R19: "Quitting MUST NOT remove the login item." 021 R12: "Pressing *Quit Trackpad Launcher* MUST turn starting at login off, only if it was on at that moment."
6. **Gesture closes window (001 R3, 009 R15, 012 tradeoff, 017 R16) vs plan 021 R15** (leave it open).
7. **Other… closes, activates and reopens (001 tradeoff, 006) vs plan 021 R16** (sheet attached, window stays).

## Gaps (searched, not found)

- **No plan states *why* a menu bar app** was chosen over a background app, a Dock app or another shape. R1 is a bare requirement. The problem statement assumes the menu bar ("earns a place in the menu bar"). Grepped `menu bar` across plans: no rationale beyond B and A3.
- **No plan discusses leaving out login items or SMAppService.** It is always in (E). There is no discussion of `SMAppService.Status` (e.g. `.requiresApproval`, `.notFound`) beyond grounding Q9 listing `status`.
- **No plan for #25 (Quit → right-click menu) or #26 (settings window design).** No plan dirs exist for 019, 021-predecessors #22/#24/#25/#26 (`git log --all -- plans`).
- **No plan discusses single-instance handling, App Nap, sudden or automatic termination, or fast user switching** beyond:
  - 001 open question "Fast user switching. The plan does not mention it."
  - candidate-1's "Does App Nap delay the gesture hop or activation for a background `LSUIElement` app? This should be measured in E2E." and "no `NSSupportsAutomaticTermination`"
  - 017 F8 (no second instance from a repeated `openApplication` during launch).
- **No probe tested Trackpad Launcher's own activation policy**, `NSApp.setActivationPolicy`, or what happens when an `LSUIElement` app is reopened from Finder or Spotlight. The activate-probe tested a regular target app opened by a background process.
- **No plan records the outcome of plan 002's manual R10 check** ("Record whether the alert sits in front of the panel"). The slice boxes are unticked in the plan text I read.
- **Plan 001 S4/S6 manual checks** (R1, R3, R17, R19, R23) are unticked in the plan (`- [ ]`). No plan records that Developer ID signing or notarisation was ever done.
- **No plan states why Quit lives in the shell rather than the model** beyond the rejection of "`openURL`/`terminate` closures in the hub (shell actions carry no policy)".

## Additional leads (other sources)

- **Source control**:
  - #25 commit `22d059a` message says "Quit moves to a right-click (or Control-click) menu on the menu bar icon". The PR body and review comments may hold the reason. No plan exists.
  - #26 `997a42f` (window design) also has no plan. Check the PR discussion.
  - The plan 001 Implement log mentions "the panel falls back to top-right until the status item has a frame (a first-launch off-screen bug found in S4)". Find that commit.
- **Docs (not plans)**:
  - `docs/product-overview.md` is the product source behind plan 001 R1. Plan 009 dev log mentions "the overview's 'menubar window'", and plan 001 cites "the overview asks for a subtle sound".
  - `docs/architecture.md` "Privacy and permissions" and "Concurrency" sections are where plans 002, 012 and 017 wrote the permission, confinement and `--deep` rules (001 S6: "per `docs/architecture.md`").
  - `docs/domain-model.md` *Frontmost app* / *Launcher window* glossary entries are cited by 010, 012 and 021.
  - `docs/performance.md:8` reportedly "warns that two copies both react to gestures". Seen only in a grep hit inside plan 021's `.temp` (not read further, per instructions).
- **Code** (for the synthesizer to confirm): `SourcePolicyTests.swift`'s current confined list (`addGlobalMonitorForEvents` → `MenuBarShell.swift`, `BounceOverlay.swift`; `AXIsProcessTrusted` → `SystemPermissions.swift`) per plans 012 and 017.
