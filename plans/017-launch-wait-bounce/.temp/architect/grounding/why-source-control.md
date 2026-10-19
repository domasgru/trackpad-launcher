# Why: launch animation and its rules (Source Control findings)

## Source
Source control only: git history (incl. pre-squash commits on `origin/feature/*` branches), commit messages, diffs, `gh pr view` bodies/comments/reviews, inline code comments, tests, and `docs/` (architecture.md, domain-model.md, performance.md, product-overview.md). `plans/` content was NOT read (Plans investigator's scope); where commit diffs touched `plans/`, only what appeared in the diff of a commit already under inspection is quoted, and flagged.

## What I Searched
- `git log --oneline` (21 commits on main; 131 across all refs). Repo squash-merges PRs; pre-squash commits survive on `origin/feature/<NNN-slug>` branches.
- `git log --format=... origin/feature/004-launch-icon-animation --not 6f21145` → c81289d, fb5edcc, b9f39ee, 37e5bc7, 9b27b80.
- `git log ... origin/feature/005-launcher-icon-settings --not ee9a3f0` → 486078b, 244096c, 218c161.
- `git log ... origin/feature/006-five-finger-tap-and-corner-swipe --not ee9a3f0 --no-merges` → 5f9a694 … f38cf95, b15701e.
- Pickaxe (`git log --all -S`): `'No timers'`, `'display links are banned'`, `'Developer tools live in'`, `'idle CPU at zero'`, `'Entry(token: "Timer"'`, `'"asyncAfter"'`, `'playFeedback(on: event.trackpad)'`, `'After bring to front'`, `'The completion is ignored'`, `'addGlobalMonitorForEvents'`, `'unless they deliver asynchronously'`, `'Work that would delay a click'`.
- `git log --all -G'(asyncAfter|Timer\(|Task\.sleep|CADisplayLink|displayLink\()' -- LauncherKit/Sources TrackpadLauncher` → **no commits** (no timer/display link ever entered shipped sources).
- `git log --all -i --grep='revert\|timer\|display link\|per frame\|per-frame\|idle'` → 36c3803, b3ce568, bc56781, ee9a3f0, fb5edcc (none is a revert).
- `git log -G'iconSide: Double|var rise: Double' -- LaunchTuning.swift` (value history 60→40→60).
- `git blame` architecture.md 20-22; Ports.swift 56-70.
- `gh pr view` 1, 3, 4; `gh pr list --state all` bodies of all 20 PRs scanned for `timer|display ?link|per[- ]frame|animation|tuner|idle|haptic|60 pt|40 pt|polling`.
- Full reads: LaunchOverlay.swift, LaunchFlight.swift, LaunchTuning.swift, AnimationTuner.swift, SourcePolicyTests.swift, LauncherTests.swift (1-190), LaunchFlightTests.swift (test names + helpers), WorkspaceActions.swift, docs/performance.md, docs/product-overview.md (current and fe0e0d7), ccd4654:docs/architecture.md.
- grep of Sources for `timestamp|seconds|deadline|clickBlockingWindow`, `per frame|every frame|render server|mouseLocation|addGlobalMonitor`, NSWorkspace lifecycle notifications, `#if DEBUG`.
- GitHub PR comments/reviews: PRs #1, #3, #4 have `"comments":[]`, `"reviews":[]`.

---

## Direct Evidence Found

### (1) No timers / polling / background loops / display links / per-frame code

**D1. The no-timer rule predates the launch animation; its stated reason is idle CPU.**
- Quote (ccd4654, first version of docs/architecture.md): "No timers, no polling, no background loops: every input is a push (frames, cfprefs KVO, IOKit notifications, workspace notifications, user events). This is what keeps idle CPU at zero."
- Where: commit ccd4654 "Add Trackpad Launcher plan, architecture and domain model docs", domasgru, 2026-10-09 08:12. Same sentence survives at docs/architecture.md:20 ("…This is what keeps idle CPU at zero.").
- Relevance: the only written reason in source control for the no-timer rule is idle CPU.

**D2. The product-level forcing function.**
- Quote (fe0e0d7, docs/product-overview.md, 2026-10-08, still present): "Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible. We don't need performance tests, but we should just pick the most performant technical path available when doin technical research."
- Also docs/performance.md:3 (added 36c3803 / PR #18): "The product promise is the least resources technically possible (`product-overview.md`)."
- Relevance: the upstream requirement the architecture rules derive from.

**D3. Animation rule and display-link ban introduced together by plan 004.**
- Quote (c81289d "Plan launch animation", 2026-10-09 23:31, docs/architecture.md diff): "+- Animation is Core Animation keyframes, which the render server plays. Whatever an animation leaves behind is cleaned up from its completion callback. No code of ours runs per frame, and display links are banned along with timers."
- Quote (fb5edcc commit message, 2026-10-09 23:44): "- Display links are banned in shipped sources." and "LaunchOverlay, a click-through, non-activating panel owned by WorkspaceActions and closed from Core Animation's completion."
- fb5edcc diff to SourcePolicyTests.swift added `Entry(token: "displayLink", rule: "timer")`, `Entry(token: "DisplayLink", rule: "timer")` and extended the pin test's doc: "Pins both halves of the policy edit so neither drifts back: … the kept IOHID, Input Monitoring, timer, display-link and polling tokens are still banned." and its `kept` list with `"displayLink", "DisplayLink"`.
- Relevance: display links are classified under the existing "timer" rule, not a separate rationale.

**D4. Code comment restating the rule in the overlay.**
- Quote (LaunchOverlay.swift:7-9, from fb5edcc): "Plays launch animations. Each play gets its own borderless, click-through panel above everything on every Space, holding one icon layer that Core Animation drives through the keyframes `LaunchFlight` staged. The panel is closed from the animation's completion callback; no code of ours runs while it plays."

**D5. Timer bans in the source-scan test date from the first slice.**
- 4552ceb "S1: LauncherKit package, gesture recognizer and source policy gate" (2026-10-09 08:17) created SourcePolicyTests.swift with `Entry(token: "Timer", rule: "timer")`, `"asyncAfter"` (timer), `"Task.sleep"` (polling), `"makeTimerSource"` (timer). File header (unchanged since): "Scans every Swift source file the app ships for APIs the product promises never to use. / To forbid something new, add it to `banned`; do not write prose."
- No commit message gives a reason for the timer bans beyond the rule names "timer"/"polling".

**D6. Measured idle cost (evidence the rule holds, not why it was made).**
- docs/performance.md (36c3803/bc56781, 2026-10-18), baseline audit at 9557bc2: "Hands off, 60 s (twice) | 0.77 ms in total (0.001%) | – | 0 idle wakeups, 1–4 interrupt wakeups per minute"; "Launcher taps, about 10 in 40 s | 779 ms (1.9%) | 0.25 ms | Includes the launch animation".

### (2) Fire-and-forget port method + separate prepare

**D7. Port contract text (as introduced).**
- fb5edcc diff to Ports.swift: "The apps the next launch animations may be for. Each call replaces the previous set. Readies whatever a later `playLaunchAnimation` for one of them needs now, so that play does no slow work." and "Returns at once. Reads the pointer, the displays and Reduce motion at the moment of the call, plays for about 500 ms and removes itself. Every call plays its own animation and never cancels, restarts or reuses one already playing. Nothing it shows activates Trackpad Launcher, becomes key or receives a click."
- 244096c (PR #4 branch, 2026-10-11) changed only "about 500 ms" → "about a third of a second". Current Ports.swift:65-67 (blame 46fcff6).
- Relevance: "every call plays its own" is a contract; the commit messages do not argue for it beyond the domain-model sentence (D9).

**D8. Why prepare exists: first icon render > 100 ms.**
- Launcher.swift:328-329 (fb5edcc): "Rows and the prepared launch animations change together, so the icon of any app that can fire is ready before its gesture: a first render of an app's icon can take over 100 ms."
- fb5edcc message: "Launcher prepares the present assigned apps whenever it resolves rows, so icons are rendered before any gesture."
- LaunchOverlay.swift:23-25 (9b27b80 merge, 2026-10-10): "Renders each app's icon away from the main actor, then replaces the previous set: a first render of an icon at this size can take over 100 ms, which must land on neither a gesture nor a click. Until the new set arrives the old one serves. Overlapping passes are harmless: the last to finish wins."
- 9b27b80 message: "Icon pre-rendering for the launch animation now runs off the main actor, following main's new rule for icon drawing." (main's rule = PR #2 6f21145, architecture "Work that would delay a click … runs off the main actor").
- LaunchOverlay.swift:18-20 (fb5edcc): "A process's first window-server window costs about 27 ms to create, against 1 ms afterwards; pay it now instead of at the first gesture."
- LaunchOverlay.swift:71-72 (b9f39ee review fix): "…Otherwise, because the app moved or a sharper display was connected since the last prepare, it is rendered and cached now." b9f39ee message: "Re-render a cached icon that is too small for the display it plays on, so icons prepared on a 1x screen are not stretched on a 2x one."
- Tests encoding the prepare contract (LauncherTests.swift): `assigningPreparesTheLaunchAnimationsBeforeAnyGestureInGestureOrder` ("preparing plays nothing"), `anAppOnTwoGesturesIsPreparedOnce` ("one entry per bundle location, in gesture order"), `unassigningAnAppStopsPreparingIt`, `anAppFoundMissingWhenTheWindowOpensIsNoLongerPrepared` ("a missing app cannot fire, so it is not prepared"), `creatingTheLauncherPreparesNothingAndStartingItPreparesTheAssignedApps`, `iconsAreStillPreparedWhileTheLaunchAnimationIsOff` (added PR #4).

**D9. Glossary wording behind "every call plays its own" (docs, not plans).**
- c81289d docs/domain-model.md: "## Launch animation … It never takes focus or receives clicks, and every fired gesture plays its own. There is no setting to turn it off." (the last sentence later replaced by PR #4's setting).
- Current docs/domain-model.md:114: "…Only gestures play it: a swipe, a window swipe and a swap never do. … It never takes focus or receives clicks, and every fired gesture plays its own. The *launch animation setting* turns it off."
- Test: `repeatedTapsWhileTheThumbStaysAnchoredFireEachTime` expects `launchAnimations == [Arc, Figma]`.

**D10. Ports never carry framework types; the model stays synchronous.**
- docs/architecture.md (ccd4654 onward): "Framework and wire types never cross a port …" ; 6f21145 (PR #2) added: "Concrete types … are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous."
- Relevance (circumstantial for "port method that reads pointer/displays/Reduce motion itself"): pointer, NSScreen and Reduce motion are AppKit reads kept inside the adapter. No commit message states this as the reason for the play method's shape.

### (3) Tuner in LauncherPlatform under #if DEBUG over LaunchTuning

**D11. Introduction.**
- 37e5bc7 "Ship the tuned launch animation with a quick puff, keep the tuner in Debug builds" (2026-10-10 11:58): "The animation now matches the preset picked in the tuner: a 60 pt icon that puffs up 20% in 75 ms, then rises 70 pt, shrinks, sways and fades in 0.34 s. Every number lives in LaunchTuning; the AnimationTuner window and its live overrides are compiled only into Debug builds."
- Same commit added architecture.md line: "Developer tools live in `#if DEBUG` and never ship. Today that is the launch animation tuner in `LauncherPlatform`: a SwiftUI window over `LaunchTuning`, whose defaults are the shipped animation."
- PR #3 body: "Debug builds also open a launch animation tuner window for polishing the animation live; Release builds contain none of it."
- AnimationTuner.swift:11-13: "Debug builds only: a floating window with a slider per `LaunchTuning` knob, for polishing the launch animation. Changes apply to the next gesture at once. The current tuning and named presets persist in user defaults. To ship a tuning, copy its values into `LaunchTuning`'s defaults."
- LaunchTuning.swift:48-53: `#if DEBUG static var current { tunerOverride.withLock { $0 } } #else static var current { shipped } #endif`; doc: "The tuning flights read now: the tuner's while it is open, `shipped` otherwise."
- LaunchTuning.swift:57 (Codable, DEBUG only): "The tuner saves tunings as JSON. Keys missing from an older save keep their shipped values."
- Why LauncherPlatform: no commit states it. Circumstantial: LaunchTuning is read by LaunchFlight/LaunchOverlay (LauncherPlatform, internal types), and the tuner is opened via `WorkspaceActions.showAnimationTuner()` (DEBUG) whose preview closure calls `overlay.play(for: finder)` (37e5bc7, WorkspaceActions.swift:41-55; TrackpadLauncherApp.swift calls it under `#if DEBUG`).

**D12. Precedent: the same tuner extended with a second feature's section.**
- 5034e95 "Accelerate switcher swipes by finger speed" (2026-10-12, PR #5 branch): "The four numbers are knobs in the Debug animation tuner, applied live." Added `Section { … } header: { Text("Switcher swipe") } footer: { Text("Applies from the next frame. Preview plays only the launch animation; swipe to try these.") }` and swipe fields to LaunchTuning, whose doc became "Every number that shapes a launch flight, plus the switcher's swipe acceleration, which the same tuner tweaks." Later reshaped by f38cf95 and f4590b1 (current knobs: swipeFollowsCursor, swipePointsPerStep, swipeTrackingSpeed).
- Relevance: existing precedent for adding a new section + new LaunchTuning fields (with Codable fallbacks) rather than a new tuner.

**D13. Incident: Debug tuner preset diverged from shipped defaults → shipped values changed (the "defaults are the shipped animation" invariant was violated once).**
- 62bf92a "Release plays the launch animation Debug plays" (2026-10-18 02:08, branch feature/014-gate-event-tap, squashed into bc56781 / PR #18): "Debug builds' animation tuner applies its saved preset (60 pt icon, 70 pt rise) instead of the shipped tuning (40 pt, 47 pt), so the Release icon read as much smaller. The shipped tuning now equals that preset; the flight tests' bounds scale with the start side."
- The same commit's diff to plans/014-gate-event-tap/development-logs.md (seen in the commit, flagged for Plans investigator): "During M2 the human saw the launch icon much smaller than in Debug builds. The tap change was not the cause: Release always plays `LaunchTuning.shipped` (40 pt, 47 pt rise), while Debug builds open the animation tuner at launch, which applies its saved "current" tuning, equal to "Preset 2" (60 pt, 70 pt rise) → at the human's request the shipped tuning now equals Preset 2 (R6)…"
- PR #18 body: "Also in this PR, at the user's request: the Release launch animation now matches the Debug tuner's preset (60 pt icon, 70 pt rise; previously 40 pt and 47 pt)."
- Relevance: the mechanism (TunerModel.init loads persisted `AnimationTuner.current` from UserDefaults and writes it to `tunerOverride`, AnimationTuner.swift:84-89) means Debug builds play the last tuner state, not `shipped`, unless reset. This caused a user-visible mismatch.

### (4) Haptic/overlay ordering and icon size

**D14. Animation after bring-to-front — explicit reason.**
- Launcher.swift:241 (fb5edcc): "// After bring to front, so whatever the animation costs lands on the icon, never on the app."
- Test LauncherTests.swift:10-29 `twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow`: "the app is brought to front before the animation is requested, so the animation cannot delay it".

**D15. Haptic first — order predates the animation; no stated reason found.**
- 735441d "S2: Launcher decision core on in-memory adapters" (2026-10-09): `hardware.playFeedback(on: event.trackpad)` then `system.bringToFront(app)` then `isWindowOpen = false`. fb5edcc inserted the animation between bringToFront and closing the window. No comment or commit message explains why feedback precedes bringToFront. The test above asserts feedback happened but not its order relative to bringToFront.
- Haptic strength comment (MultitouchTrackpads.swift:126): "Chosen by feel: 3 weak, 4 medium, 6 strong. …"

**D16. Icon size history: 46 → 60 → 40 → 60 pt.**
- fb5edcc: `static let iconSide: CGFloat = 46`, `duration = 0.5`, `rise = 44`, "120 samples a second", steps 60.
- 37e5bc7 (2026-10-10): `iconSide = 60`, `rise = 70`, `duration = 0.34`, `popSize 0.2`, `popTime 0.075` — "matches the preset picked in the tuner".
- 244096c / 46fcff6 PR #4 (2026-10-11/12): `iconSide = 40`, `rise = 47`. PR #4 body: "The launch animation icon now starts at 40 pt instead of 60 pt, and its rise is scaled down to match." No reason for "smaller" given in PR body or commit message (commit message is just the title).
- 62bf92a / bc56781 PR #18 (2026-10-18/19): back to `iconSide = 60`, `rise = 70` (D13). Test renamed `iconRisesFasterAndFasterToBetween40And53PointsAboveItsStart` → `…Between60And80…`; bounds 66…78 peak, ≤36 end, ≥20 when invisible.
- Peak-size bitmap: LaunchOverlay.swift:95-101 (37e5bc7): "The icon's side at the pop's peak, in pixels at `scale`." / "…as a bitmap of the icon's peak size in pixels at `scale`, so it never has to be scaled up."
- Keyframe sampling: LaunchFlight.swift:66 (37e5bc7): "240 samples a second, so a pop of a few tens of milliseconds still gets several keyframes."

---

## Indirect / Circumstantial Evidence

**C1. Time limits in the codebase are evaluated against input timestamps, not timers.**
- Touch.swift:33: "Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads." GestureRules.swift:23 `clickBlockingWindow = Duration.seconds(3)` compared as `frame.time - $0 < GestureRules.clickBlockingWindow` (GestureRecognizer.swift:213).
- Suggests: the established pattern for "after N seconds" is lazy evaluation on the next pushed event. Alternative reading: this is just what recognition needed; nobody wrote it as a general pattern.
- PR #2 body: "refreshed … within ~5 s of an app being installed or removed (folder watch, no timers)" — delay via FSEvents latency rather than a timer.

**C2. Core Animation completion as the cleanup/timing mechanism has been enforced in review.**
- b15701e "Fix implementation review findings" (PR #5 branch, 2026-10-11): "Core Animation fade for the switcher …" — replaced `NSAnimationContext.runAnimationGroup { panel.animator().alphaValue … }` with a CABasicAnimation + `CATransaction.setCompletionBlock` and a generation counter ("Bumped by every open and close, so a fade's completion that a later open or close outlived does nothing.").
- Suggests reviewers treat the architecture animation rule as binding for non-launch overlays too.

**C3. Code of ours already runs per *trackpad* frame for switchers (input-driven, not display-driven).**
- docs/performance.md: "During swipes, about a quarter of the CPU was the switcher panels' per-frame `show` (Core Animation commits and `NSView.setFrame` on the glass highlight)." and Decision "Fewer redraws in `SwitcherPanel.show`: rejected."
- Suggests the "no code of ours runs per frame" sentence is read as display frames / animation ticks, while pushed input events (trackpad frames) may drive updates. A Plans-side grounding note (see Leads) states this distinction explicitly. Alternative reading: the architecture sentence is literally broader and the switcher is a tolerated exception — no source-control text resolves this.

**C4. The source-scan is a textual substring match over all shipped sources, DEBUG code and comments included.**
- SourcePolicyTests.swift:197-205 `scan` filters lines with `.contains(token)`; scannedRoots = `LauncherKit/Sources` + `TrackpadLauncher/` (no `#if DEBUG` awareness). Tokens "Timer", "asyncAfter", "Task.sleep", "makeTimerSource", "displayLink", "DisplayLink".
- Consequence (mechanical): any identifier or comment containing `Timer` (e.g. `CFRunLoopTimer`, `DispatchSourceTimer`, a type named `…Timer…`), `DisplayLink` (`CADisplayLink`, `NSScreen.displayLink`), `asyncAfter`, `Task.sleep` in Sources fails `swift test`, including inside the DEBUG tuner.

**C5. `bringToFront` ignores openApplication's completion.**
- WorkspaceActions.swift:14-15 (002e62e/1cf9c4b): "One call reproduces a Dock click: launches, unhides, restores, reopens and activates. / The completion is ignored: its only reactions would be a log line or a dialog."
- Relevant to "end on failure": today no failure signal is consumed. Reason given is only that there was nothing to do with it.

**C6. Existing app-lifecycle observation lives in LauncherUI / LauncherPlatform adapters.**
- SwitcherPresenter.swift:51-58 observes `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` (for switcher icon pre-rendering); ActivationTracker.swift observes `didActivateApplicationNotification`. These are "workspace notifications" in the architecture's push list. No finished-launching or first-window observer exists (grep found none of `isFinishedLaunching`, `AXObserver`, `kAXWindowCreated`).

**C7. Scoped push observers precedent.**
- MenuBarShell.swift:105 (1cf9c4b) installs `NSEvent.addGlobalMonitorForEvents` only in `show()` and removes it in `hide()` — an observer that exists only while needed. No commit text explains it.

**C8. "Only gestures play it."**
- docs/domain-model.md:114 and :39 (swap: "never the launch animation"); 10b0e91 grounding/design text "No launch animation on a swipe." (in a plans/.temp file within the PR #5 diff — Plans scope).

---

## Contradictions

1. **Icon size: PR #4 vs PR #18.** PR #4 (46fcff6, 2026-10-12) deliberately shrank the shipped icon "to 40 pt instead of 60 pt"; PR #18 (62bf92a, 2026-10-18) restored 60 pt / 70 pt "at the user's request" because the Debug tuner preset (60 pt) had been what the user was actually seeing. Both are current history; the 40 pt decision was never observed in Debug builds per 62bf92a's message. docs/domain-model.md does not state a pt size for the launch icon (grep found none), so the docs don't arbitrate.
2. **Architecture "defaults are the shipped animation" vs. Debug behaviour.** architecture.md:22 says the tuner is "over `LaunchTuning`, whose defaults are the shipped animation", but AnimationTuner.swift:85-88 loads the persisted `AnimationTuner.current` at launch and pushes it into `tunerOverride`, so Debug plays the last tuned values, not the defaults. 62bf92a is the incident this produced.
3. **"No code of ours runs per frame" vs. per-trackpad-frame switcher updates** (C3). docs/performance.md measures per-frame `show` work in the switcher panels. Not a contradiction if "frame" means display frame; source control contains no text defining it.
4. **Ports.swift contract vs. setting.** Ports.swift:65 says play "Reads … Reduce motion at the moment of the call", and LaunchOverlay.play also ORs `LaunchTuning.current.forceReduceMotion` (37e5bc7) — a DEBUG-only override reaching the port's behaviour (in Release `current` = `shipped`, so forceReduceMotion false). Minor.
5. **Duration in Ports doc.** fb5edcc's "plays for about 500 ms" was changed to "about a third of a second" only in PR #4 (244096c), although 37e5bc7 (PR #3) had already set 0.34 s — the port doc lagged one PR.

## Gaps
- No PR review comments or review threads exist for PRs #1, #3, #4 (`comments: []`, `reviews: []`); review findings were applied as commits (b9f39ee, 218c161, b15701e) whose rationale lives in plan development logs (not read).
- No commit message or code comment explains why the haptic is played before bringToFront (searched `haptic.*(first|before)`, `feedback.*(first|before)`, `latency` in Sources/docs; pickaxe on the feedback line → only 735441d/1cf9c4b/cb7b432/10b0e91, none explains).
- No commit message explains why the tuner lives in LauncherPlatform rather than LauncherUI or the app target.
- No commit message explains why PR #4 wanted a smaller icon (PR #4 body states the change only).
- No reason recorded for "every call plays its own / never cancels, restarts or reuses" beyond the glossary sentence.
- No commit ever introduced a timer, display link, `asyncAfter` or `Task.sleep` into Sources (`-G` search returned nothing); no reverts found. So no incident drove the no-timer rule; it was a day-one design rule.
- No test or script checks that the Release build excludes the tuner (`grep -rn tuner Scripts LauncherKit/Tests` → nothing); exclusion relies on `#if DEBUG` alone.
- No existing code observes "finished launching", first window shown, or launch failure for an app the launcher opened.

## Additional Leads (for Plans investigator)
- plans/004-launch-icon-animation/plan.md and development-logs.md (c81289d, b9f39ee, 37e5bc7 edited them; 37e5bc7 changed plan.md by 58 lines when shipping the tuner). A plans/.temp document visible in the PR #15 diff (18acef7) quotes plan 004: "Docs: 'Concurrency gains the animation rule: Core Animation keyframes, cleaned up from the completion callback, no display links.'" and "Source policy: '`SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule "timer". A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame.'" — verify in plan 004.
- plans/006-five-finger-tap-and-corner-swipe grounding F27 (quoted inside the 10b0e91 diff): "A switcher highlight driven by finger frames is input-driven work (~100 Hz while the fingers move), not a per-display-frame loop; springs and fades at the ends and on dismissal are animations the render server plays." Also 006 Alternatives: "SwiftUI for the switcher's content … its springs and scale animations are not Core Animation keyframes, the architecture's animation rule…" — directly bears on how "per frame" has been interpreted.
- plans/005-launcher-icon-settings/plan.md (why 40 pt; 486078b) and development-logs (218c161).
- plans/014-gate-event-tap/plan.md R6 and development-logs Verify bullet (62bf92a) — the 60 pt restoration.
- plans/001-trackpad-launcher-app/plan.md and its `.temp/architect` (ccd4654) for the original "idle CPU at zero" / timer-ban reasoning; plans/001 and 003 reportedly "rejected hops 'whose negative tests could not fail'" (quoted in an 18acef7 .temp file).
- plans/003-dropdown-recents-performance (PR #2, 6f21145): origin of "Work that would delay a click … off the main actor" and "deliver asynchronously → behind a port so the model's tests stay synchronous".
