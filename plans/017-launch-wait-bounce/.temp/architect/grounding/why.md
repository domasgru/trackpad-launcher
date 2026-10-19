# Why: the launch animation and its surrounding rules

### The Question

Why is the launch animation built the way it is? Four parts:
1. Why are timers, polling, background loops, display links and per-frame code of ours banned?
2. Why is the overlay a fire-and-forget `SystemActions.playLaunchAnimation(for:)`, with a separate `prepareLaunchAnimations(for:)`?
3. Why does a `#if DEBUG` tuner in `LauncherPlatform` sit over `LaunchTuning`, whose defaults are the shipped animation, and how were presets meant to work?
4. Why is the haptic/overlay ordering what it is, and why is the icon 60 pt?

The answer feeds plan 017 (the launch bounce). That plan keeps an icon up for as long as 10 s, has it follow the pointer, ends it on app lifecycle events, and adds a tuner section and preset knobs.

### The Code in Question

- `docs/architecture.md:20-22`, Concurrency section: the no-timer rule, the animation rule, and the developer-tools rule.
- `LauncherKit/Sources/LauncherCore/Ports.swift:56-70`: `SystemActions.bringToFront`, `prepareLaunchAnimations(for:)` and `playLaunchAnimation(for:)`.
- `LauncherKit/Sources/LauncherPlatform/` `LaunchOverlay.swift`, `LaunchFlight.swift`, `LaunchTuning.swift` and `AnimationTuner.swift`. Tests are in `LaunchFlightTests.swift` and `SourcePolicyTests.swift`. `Launcher.fire` is in `LauncherCore/Launcher.swift` (around line 241).

---

### What We Found

#### (1) The ban on timers, polling, background loops, display links and per-frame code

- **[Direct]** The timer and polling ban dates from day one, and the stated reason is the cost of sitting idle. It did not come from the animation work. Sources:
  - Plan 001 R22 "Zero cost when idle": "While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU in Activity Monitor, with at most one momentary blip per minute."
  - The problem statement of plan 001: a launcher "that … burns CPU while idle gets uninstalled."
  - The first `docs/architecture.md` (commit ccd4654): "No timers, no polling, no background loops: every input is a push … This is what keeps idle CPU at zero." That sentence is still at `docs/architecture.md:20`.
- **[Direct]** Behind R22 is a product-level promise. `docs/product-overview.md` (fe0e0d7): "as performant as possible, consuming the least possible resources as it's technically possible." `docs/performance.md:3` repeats it.
- **[Direct]** The source-scan gate has banned these tokens since the first slice. Commit 4552ceb added `Timer`, `asyncAfter` and `makeTimerSource` under the rule "timer", and `Task.sleep` under "polling". Plan 001's sketch labels them "R22 timer" / "R22 polling". All four are still at `SourcePolicyTests.swift:30-33`.
- **[Direct]** Plan 001 chose to treat time as data instead of using a clock. Decision 1: "frames carry their own timestamps … so no clock object or timer exists anywhere." Its Alternatives section rejected "an injected `Clock` and a tap-timeout timer" because "a timer would be the app's only timer (R22)."
- **[Direct]** Plan 002 confirmed the ban and wrote the "no background loops" wording into the architecture.
  - The 002 dev log says the timer bans "were one package for 001's R20 and R22 … timers and polling stay banned, the frame clock stays the only clock."
  - 002 rejected "a deadline instead of a per-frame flag" for a specific reason: `FrameTime` and `CGEventTimestamp` "are not known to share a base." It also rejected "a heuristic over other apps' activation" because it would need a timer. Its "Deliberately not done" section says: "No grace delay, timer, deadline or second clock."
- **[Direct]** Plan 004 added the animation rule and the display-link ban.
  - Plan 004, "Source policy": "`SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule 'timer'. A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame."
  - Plan 004, "Lifetime": "The panel is closed from Core Animation's completion callback, never from a timer … Once the last panel has closed, no code of ours runs."
  - The commits are c81289d (architecture.md wording, verified at line 21) and fb5edcc (tokens, now `SourcePolicyTests.swift:34-35`).
- **[Direct]** Plan 004 also chose to read Reduce motion fresh on each call: "read fresh on every call. Nothing observes it and nothing polls." (plan 004, Play step 1.)
- **[Direct]** Later plans applied the rule to new animations, and a review enforced it once. Plan 006's dev log records a review finding: the switcher fade "used `panel.animator().alphaValue`, not Core Animation (architecture's animation rule)". It was replaced by a Core Animation fade with `orderOut` from the completion callback and a generation counter (commit b15701e). Plan 006:1313 says "No timer, deadline or display link."
- **[Direct]** The only time bound any plan accepted lives inside a system call. Plan 012:1604: "its one deadline, the AX messaging timeout, lives inside the system call."
- **[Direct]** Plans have judged code driven by input events to be compatible with "per frame". Plan 006 grounding F27 (`plans/006-*/.temp/architect/grounding/index.md:55`): "A switcher highlight driven by finger frames is input-driven work (~100 Hz while the fingers move), not a per-display-frame loop." Plan 006:1338 accepts AppKit and Core Animation "with no code of ours per display frame, as in the launch overlay." F27 is a grounding note, not a decision; see What We Don't Know.
- **[Direct]** `git log -G` over shipped sources for `asyncAfter|Timer\(|Task\.sleep|CADisplayLink|displayLink\(` finds no commit. No timer or display link was ever added and later removed, so no incident lies behind the rule. It was a design rule from the start (source-control investigator).

#### (2) The fire-and-forget port method and the separate prepare

- **[Direct]** "Every call plays its own" is a requirement. Plan 004 R14: "Every fired gesture MUST start its own animation. A new animation MUST NOT cancel or restart one already playing." The scenarios show two icons on screen at once. The glossary says the same (`docs/domain-model.md:114`: "every fired gesture plays its own"). It is pinned by the test `repeatedTapsWhileTheThumbStaysAnchoredFireEachTime`.
- **[Direct]** The animation is a method on `SystemActions` because plan 004 classed it as an effect: "No new port. The animation is one more effect the core decides and macOS performs, which is what `SystemActions` already describes." (plan 004, "The port".)
- **[Direct]** The adapter reads the pointer, the displays and Reduce motion itself for these reasons:
  - Plan 004 R4: the icon "MUST start on the pointer's position at the moment the gesture fires."
  - Plan 005: "Reduce motion is read inside `playLaunchAnimation` (its contract)".
  - The architecture rule in force since ccd4654: "Framework and wire types never cross a port."
  - Plan 004 "The launch flight" moved the motion into LauncherPlatform because "The motion is how the adapter renders an effect the model decided. It is not a model decision", and because it can use `CGPoint`, `CATransform3D` and `NSMouseInRect`, which LauncherCore cannot import.
- **[Direct]** `prepare` exists because of a review finding about R1. The 004 dev log, Plan: "R1's 'no later than the haptic feedback' knowingly broken by a first-ever icon render (45–120 ms) at the gesture … → added `SystemActions.prepareLaunchAnimations(for:)`." Plan 004 "The icon is ready before the gesture" cites a probe: 45–120 ms for the first render, 1–2 ms afterwards. The code comment at `Launcher.swift:328-329` repeats the reason.
- **[Direct]** Prepare also warms the window server: "Creating a panel's window-server window … 26–29 ms in a fresh process, against about 1 ms afterwards" (plan 004, "Warm-up"; `LaunchOverlay.swift:18-20`).
- **[Direct]** Prepare runs off the main actor because PR #2's architecture rule says "Work that would delay a click (… icon drawing) runs off the main actor." See the 004 dev log "Merge with main" and commit 9b27b80.
- **[Direct]** Preparing continues while the setting is off on purpose. Plan 005: "This is a performance decision … The alternative … adds a path and a way to get a cold icon." The test `iconsAreStillPreparedWhileTheLaunchAnimationIsOff` pins this.
- **[Direct]** The setting is enforced in the model, not in the adapter. Plan 005: "nothing below it learns about the setting: the `SystemActions` port, `WorkspaceActions` and the overlay are unchanged."
- **[Direct]** Each live panel is tracked separately until its own completion. Plan 004 "Lifetime": "Calls share nothing else, so a second call never touches a first call's panel (R14)." The set exists because "the probe found a closed panel staying in `NSApplication.shared.windows`."

#### (3) The tuner: `LauncherPlatform`, `#if DEBUG`, `LaunchTuning` and presets

- **[Direct]** The tuner came out of feel-based polishing, and its chosen preset became the shipped animation.
  - 004 dev log, "Tuning": "The user polished the animation by feel in a Debug-only tuner window and picked their 'Preset 2' → it is the shipped animation: 60 pt, 0.34 s, a 20 % pop over 75 ms, rise 70 pt … The tuner … stays in the codebase for future polishing; Release builds contain none of it."
  - Commit 37e5bc7 says the same and added the architecture.md:22 sentence.
- **[Direct]** The design of the tuner is in plan 004, "Tuning (Debug builds only)":
  - "Release builds read its defaults as constants. Debug builds read them through a `Mutex` the tuner writes."
  - The tuner has "a slider per number, live preview at the pointer, reset to shipped, and named presets saved in user defaults."
  - "To ship a new tuning, copy its values into `LaunchTuning`'s defaults and adjust the requirement bounds and tests if they move."
  - "Everything in the tuner sits inside `#if DEBUG`."
- **[Direct]** The tests check requirement bounds, not exact tuning values, so retuning within the bounds keeps the suite green. Plan 004 Curves and Further Notes: "The curve constants are feel choices. The tests check requirement bounds."
- **[Direct]** How presets work today (code, describing mechanics only):
  - A preset is a named snapshot of the whole `LaunchTuning`: `TuningPreset { name, tuning }` (`AnimationTuner.swift:55`).
  - The working tuning is stored as JSON under `AnimationTuner.current`, and the presets under `AnimationTuner.presets` (`:62-63`).
  - At launch the tuner loads `current`, or `.shipped` if nothing is saved (`:85`).
  - New presets are named automatically "Preset N" (`:119`).
  - Decoding is tolerant. Missing keys take shipped values (`LaunchTuning.swift:57-83`). Plan 005 notes "`LaunchTuning` already decodes this way."
- **[Direct]** The tuner already covers a second feature, so a new section has a precedent. Commit 5034e95 (plan 006) added a "Switcher swipe" section and swipe fields to `LaunchTuning`, whose doc became "Every number that shapes a launch flight, plus the switcher's swipe acceleration, which the same tuner tweaks" (`LaunchTuning.swift:4`). Those fields are still present (`:40-44`), and presets carry them.
- **[Direct]** The claim "defaults are the shipped animation" failed in practice once. Plan 005 had already warned: "A Debug build with a tuning saved by the tuner plays that tuning, not the shipped one; the manual checks reset to shipped first." In plan 014 that happened. The 014 dev log, Verify: "Release always plays `LaunchTuning.shipped` (40 pt, 47 pt rise), while Debug builds open the animation tuner at launch, which applies its saved 'current' tuning, equal to 'Preset 2' (60 pt, 70 pt rise)." The fix was plan 014 R6 (`plans/014-gate-event-tap/plan.md:44-45`), commit 62bf92a, squashed into bc56781 (#18).

#### (4) Haptic and overlay ordering, and the 60 pt size

- **[Direct]** The animation comes after bring-to-front so that its cost can never delay the app.
  - `Launcher.swift:241`: "// After bring to front, so whatever the animation costs lands on the icon, never on the app."
  - Plan 004 "When the animation plays": "Last in line, it cannot hold up the pulse or the app (R13)."
  - R13: showing the animation "MUST NOT … delay bringing the target app to front."
  - Test T1 checks that `broughtToFront` already holds the app when the animation is requested.
- **[Direct]** For R1 ("no later than the haptic feedback"), plan 004 reads "no later" as "same main-actor turn": "no picture can strictly precede a pulse. The plan therefore meets R1 by issuing the animation in the same main-actor turn as the pulse, with nothing slow in the way." The order in `fire` is pulse, bring to front, animation, close window. Plan 005 kept it.
- **[Direct]** The 60 pt size is a feel choice, made twice.
  1. Commit fb5edcc used 46 pt.
  2. In plan 004 the user picked "Preset 2" in the tuner, so 60 pt with a 70 pt rise (37e5bc7).
  3. Plan 005 cut it to 40 pt with a 47 pt rise because "60 × 60 points … is too big for a quick confirmation and draws more attention than it should" (`plans/005-launcher-icon-settings/plan.md:5`, `:146`).
  4. Plan 014 R6 restored 60/70 "at the human's request", because the Release icon "read as much smaller" than the Debug build's preset.
- **[Direct]** The bitmap is rendered at the pop's peak size so that it is never scaled up (`LaunchOverlay.swift:95-101`; plan 004 Curves). Keyframes are sampled at 240 per second so the short pop gets several keyframes (`LaunchFlight.swift:66`).

---

### What We Can Reasonably Infer

- **[Inferred]** The display-link ban probably comes from two motives that overlap. It is filed under "timer", so it inherits R22's idle-cost reasoning. Plan 004 also gives its own reason: a per-frame callback would "run code of ours on every frame", which is a cost while the animation runs, not while the app is idle. A bounce that runs for up to 10 s turns this second motive from a cost lasting a third of a second into a sustained one. That is likely why the rule matters more for 017 than it did for 004.
- **[Inferred]** The working interpretation seems to be "no code driven by the display refresh" rather than "no code during an animation". Evidence: 006 F27 and 006:1338 accept input-driven updates at about 100 Hz. Plan 004's alternative to keyframes is specifically a "per-frame callback". So a bounce that moves its icon in response to pushed events would plausibly fit the precedent, while one that samples the pointer on each display refresh would not. No plan or architecture text states this distinction as a rule.
- **[Inferred]** When a time bound was needed, the codebase pattern appears to be: hand the time to a system facility, or check it lazily against the next pushed event. Examples:
  - A Core Animation completion instead of a timer (004).
  - The AX messaging timeout (012).
  - The 3 s click-blocking window checked against frame timestamps (`GestureRules.swift:23`, 002 decision 1).
  - The FSEvents latency instead of a timer (PR #2).

  Each case may simply have had a convenient facility to hand, so this may not be a deliberate general pattern.
- **[Inferred]** The tuner probably lives in `LauncherPlatform` because what it tunes (`LaunchTuning`, `LaunchFlight`, `LaunchOverlay`) are internal types there, and its preview calls `overlay.play` directly (`WorkspaceActions.showAnimationTuner`, 37e5bc7). No source says this.
- **[Inferred]** The haptic-first order looks like a leftover from plan 001 (decision 5: "plays feedback …, brings the app to front and closes the window"), from before the animation existed, rather than a decision made for the animation. Plan 004 builds on it ("issuing the animation in the same main-actor turn as the pulse") but never argues for it.
- **[Inferred]** "Every call plays its own, never cancels or reuses" was designed for an animation lasting a third of a second, where overlapping copies are brief. Plan 004's non-goals put the bounce use case explicitly out of scope ("Showing the icon until the app's window appears … not a progress indicator"; "Tracking the pointer during the animation"). So the R14 contract was not written with long-lived icons in mind.

---

### Competing Hypotheses

**Why 60 pt (and not 40)?**
- **Hypothesis A:** 60 pt is the considered preferred size.
  - Evidence for: it was picked in the tuner twice (004 Preset 2, and 014 R6 reaffirming it after seeing both sizes).
  - Evidence against: plan 005 said 60 pt was "too big … draws more attention than it should", and plan 014 never answers that point.
- **Hypothesis B:** 60 pt won because the 40 pt choice was never actually seen.
  - Evidence for: per the 014 dev log, Debug builds kept playing Preset 2. The human may have judged 005's 40 pt only once they saw a Release build, and found it too small in contrast.
  - Evidence against: 014 R6 is an explicit human request after seeing both sizes. That is a real preference, whatever led to it.
- For 017, the R4 requirement ("the same size as the launch animation's icon") ties the bounce to whatever this value is. If the size is reopened, both features move together.

**What "no code of ours runs per frame" forbids.**
- **Hypothesis A:** it forbids only code driven by the display refresh or by timers. Input-driven updates are fine.
  - Evidence for: 006 F27, 006:1338, and the per-trackpad-frame `SwitcherPanel.show` accepted in `docs/performance.md`.
  - Evidence against: the architecture text has no qualifier, and F27 is a grounding note, not a recorded decision.
- **Hypothesis B:** it forbids any code of ours running for each animation frame while an animation is visible.
  - Evidence for: the literal wording, and 004's "Once the last panel has closed, no code of ours runs."
  - Evidence against: the switcher precedent above.

---

### What We Don't Know

- **Whether following the pointer was ever weighed against the event rules.** Plan 002 R9 says the app "MUST NOT read, record or change … pointer movement or any other event" (`plans/002-*/plan.md:181`), and 006 T76 parses `.mouseMoved` to nil. No plan discusses whether reading the pointer location or moved events for an on-screen effect would breach R9's privacy intent or only its letter. We grepped plans for `mouseMoved|follow.*pointer|track.*pointer` and found only 004's non-goal and the 002/006 exclusions.
- **App lifecycle signals for launch progress were never considered.** We grepped plans for `didLaunch|didFinishLaunching|isFinishedLaunching|didTerminate|kAXWindowCreated|AXObserver|first window|CGWindowList`. The only hits are switcher icon caching (008 decision 9, which accepts workspace launch/terminate notifications as pushes in `SwitcherPresenter`) and 012's rejected AX window-count observer ("Chromium and Electron trees are unreliable observers"). No source code observes finished launching, a first window, or a launch failure. `bringToFront` deliberately ignores `openApplication`'s completion (`WorkspaceActions.swift:14-15`: "its only reactions would be a log line or a dialog").
- **How a 10 s cap or a "+2 s" grace fits the timer ban.** No plan has had a time bound longer than the AX messaging timeout, and none has handled a time bound with no pushed event to check it against. Plan 001's open question shows a timer was once treated as a cost to justify ("is one bounded retry (the app's only timer) acceptable?"). From plan 002 on, every plan treats timers as banned.
- **Why haptic comes first.** We searched commit messages, code comments and plans for `haptic.*(first|before)`, `feedback.*(first|before)` and `latency`. Nothing explains it beyond plan 001's ordering.
- **Why the tuner lives in `LauncherPlatform` rather than `LauncherUI` or the app target.** No plan or commit says.
- **The preset UX design.** Plans say only "named presets saved in user defaults" (004), "Shipped" preset (005) and "Preset 2" (014). Nothing defines names, sections or migration. The mechanics are known only from code.
- **Why plan 005 found 60 pt "too big", and whether that still holds.** Plan 014 overrode the decision without discussing it.
- **Review discussion.** There are no PR review comments or reviews on PRs #1, #3 and #4. Review rationale exists only as dev-log bullets.
- **No test checks that Release excludes the tuner.** `#if DEBUG` is the only guard.
- **People who would know:** the repo owner (domasgru), who chose Preset 2, asked for the 60 pt restoration, and wrote the plan 004 non-goals at spec review.

---

### Sources Consulted

- **Source control history.**
  - All 21 commits on main, and pre-squash branches `origin/feature/004-*`, `005-*` and `006-*`. Key commits: ccd4654, 4552ceb, 735441d, c81289d, fb5edcc, b9f39ee, 37e5bc7, 9b27b80, 244096c, 46fcff6, 5034e95, b15701e, 62bf92a, bc56781 and eb90f96.
  - `git log -S`/`-G` pickaxe searches for timer and display-link tokens and for the architecture sentences.
  - `git blame` on `architecture.md:20-22` and `Ports.swift:56-70`.
  - `gh pr view` on 1, 3 and 4, plus a keyword scan of all 20 PR bodies.
  - Code comments in `LaunchOverlay.swift`, `LaunchFlight.swift`, `LaunchTuning.swift`, `AnimationTuner.swift`, `Launcher.swift`, `WorkspaceActions.swift`, `SourcePolicyTests.swift` and `LauncherTests.swift`.
  - Docs: `architecture.md`, `domain-model.md`, `performance.md` and `product-overview.md`.
- **Plans.**
  - Read in full: 004 plan and dev log, 005 plan and dev log.
  - Read the dev logs of 001, 006, 012 and 014.
  - Read sections of 001, 002, 003, 006, 008, 009, 012 and 014 plans, and 006 grounding F27.
  - Greps over all plans for: launch animation/tuner/preset terms; `timer|deadline|asyncAfter|display ?link|polling`; pointer and lifecycle terms; `bounce|progress indicator|cold launch|until the app`; `every input is a push`.
- **Spot-checked by the synthesizer:**
  - `docs/architecture.md:20-22`
  - `Ports.swift:56-70`
  - Plan 004 lines 5, 157, 190-191, 197-202 and 347
  - `plans/005-*/plan.md:5`, `:146`
  - `plans/014-*/plan.md:44-45`
  - `plans/002-*/plan.md:181`
  - 006 F27
  - `SourcePolicyTests.swift:30-35`
  - `LaunchTuning.swift`, `AnimationTuner.swift` (preset mechanics)
  - `Launcher.swift:241`
  - The 017 plan's requirement headings (for the constraint set below)

### Confidence Summary

These answers have direct support from plans and commits:
- The no-timer rule and its idle-CPU origin (R22).
- The display-link ban and the keyframe-only animation rule (plan 004, "per-frame callback … would run code of ours on every frame").
- The port's shape (004 R14, R4, "no new port").
- `prepare` (the 45–120 ms first-render probe).
- The tuner and its shipped-defaults workflow (004 "Tuning", 37e5bc7).
- Bring-to-front before the animation (004 R13, `Launcher.swift:241`).

These are weaker:
- The 60 pt size rests on a human feel preference that overrode an opposite one without saying why.
- Haptic-first is inherited, not argued.
- Whether "per frame" allows input-driven updates rests on one grounding note.
- How pointer following and lifecycle-based ending fit the event-privacy and timer rules has no precedent in the record. It is new ground that 017 has to settle explicitly.

---

## Constraint set for planning the launch bounce (plan 017)

### Preserve

- **No Swift timers, `asyncAfter`, `Task.sleep`, dispatch timer sources or display links in shipped sources, including DEBUG code.**
  - The R22 rationale and the source-scan gate (`SourcePolicyTests.swift:30-35`) still apply.
  - The scan is a plain substring match over `LauncherKit/Sources` and `TrackpadLauncher/`, with no awareness of `#if DEBUG`. Any identifier or comment containing `Timer` or `DisplayLink` will fail `swift test`.
- **Zero idle cost.** When no bounce is live, no observer, monitor or panel of ours may remain. The existing precedent is observers installed only while needed (`MenuBarShell` global monitor in `show`/`hide`; switcher observers removed while the setting is off, 008).
- **Animation motion is Core Animation, played by the render server.**
  - The bounce loop itself (jump, gravity fall, rest, repeat) can be a repeating keyframe animation, with no code of ours per bounce.
  - Cleanup happens from the completion callback.
  - A generation guard keeps a stale completion from acting (the b15701e/006 precedent).
- **Bring to front before any animation work.** The animation stays last in `fire` and must never delay the app (004 R13, `Launcher.swift:241`). The pulse and the first visible icon are issued in the same main-actor turn as the gesture (004 R1).
- **Prepared icons.** No first-time icon render on the gesture path. The bounce should reuse the prepared, peak-size bitmaps, and prepare must cover the bounce's largest on-screen size (plan 004 renders at the pop's peak "so it is never scaled up").
- **Model/adapter split.**
  - The core decides which effect plays: bounce or flight, and whether the setting allows it. This mirrors 005's "the model enforces it in `fire`".
  - Motion, pointer reads, display reads and Reduce motion stay in LauncherPlatform.
  - No framework types cross the port.
  - The model stays synchronous, so asynchronous lifecycle pushes sit behind a port (PR #2's rule).
- **The overlay never activates the app, becomes key, or takes clicks** (Ports.swift contract; 017 R16).
- **Tuner conventions.**
  - Add fields to `LaunchTuning`, whose defaults are the shipped values.
  - Keep tolerant decoding, so older saved presets load with shipped bounce values (017 R19).
  - Add one new `Section` to the existing `AnimationTuner`, as the switcher-swipe precedent did.
  - Everything stays under `#if DEBUG`.
  - Tests check requirement bounds, not exact numbers.
- **Shared size.** The bounce icon uses the same `iconSide` as the flight (017 R4), so the 60 pt decision stays in one place.

### Change (deliberately, and record why)

- **Plan 004's non-goals.** "Showing the icon until the app's window appears" and "Tracking the pointer during the animation" are reversed. 017 should say so explicitly, citing 004's own problem statement ("A cold app launch can take a second or more…"), which is the tension the non-goal left open.
- **The `playLaunchAnimation` contract.** It currently says "plays for about a third of a second", "every call plays its own and never cancels, restarts or reuses one already playing" (004 R14), and returns with nothing to end later. 017 needs a bounce that:
  - lasts up to 10 s,
  - is ended by events,
  - hands over into the flight from wherever it is (R9),
  - is reused when the same app is fired again (017 R14: "Firing the same app again keeps one bounce").

  That contradicts 004 R14 and `docs/domain-model.md:114` ("every fired gesture plays its own"). Update the port docs, the glossary and the tests (`repeatedTapsWhileTheThumbStaysAnchoredFireEachTime`) together, rather than quietly overloading the old method.
- **The architecture wording (`docs/architecture.md:20-21`).** If the bounce follows the pointer through pushed events, write down the interpretation 006 F27 relied on (input-driven updates allowed, display-driven loops not) as architecture text. Today it lives only in a grounding note.
- **`bringToFront` ignoring `openApplication`'s completion.** 017 R11 (fade quietly on failure) needs a failure signal. The original reason for ignoring it ("its only reactions would be a log line or a dialog") no longer holds.

### Avoid

- **A display link, `CADisplayLink`/`NSScreen.displayLink`, or a run-loop timer to sample the pointer each frame.** This is exactly the alternative plan 004 banned. A 10 s bounce would make it a sustained cost.
- **A Swift timer or `asyncAfter` for the 10 s cap or the "+2 s after finished launching" grace.** Prefer time owned by the system, as earlier plans did:
  - for example, a Core Animation animation whose duration is the cap, with its completion as the deadline,
  - or a lazy check against a pushed event.

  Then verify the cap still fires when no other event arrives.
- **The 017 R18 tuner preview "for 3 seconds" via `asyncAfter` or `Timer`.** Those tokens fail the scan even under `#if DEBUG`.
- **Leaving workspace, AX or event observers installed after the last bounce ends.** That breaks R22-style zero idle cost.
- **AX observers on Chromium/Electron trees as the only "first window" signal.** Plan 012 rejected AX window observers as unreliable for those apps.
- **Polling the window list or `isFinishedLaunching`.** Polling is banned.
- **Putting the setting check, or the "launching vs running" decision, inside the overlay.** Plan 005 kept the adapter ignorant of policy.

### Risk

- **Pointer following vs plan 002 R9.**
  - R9 says the app "MUST NOT read, record or change … pointer movement or any other event".
  - The tap mask excludes moved events, and 006 T76 pins `.mouseMoved` → nil.
  - A global mouse-moved monitor, or adding the moved bit to the tap, likely conflicts with the letter of R9 and with the T44/T47 tests.
  - Reading `NSEvent.mouseLocation` on another push (for example trackpad frames) may avoid moved events, but it couples the bounce to trackpad input and misses mouse movement.
  - No precedent settles this. Decide it explicitly and get the human's sign-off.
- **The 17 ms/frame expectation vs "no code of ours per frame".** 017 R7 asks for "every frame, with no lag the user can see." Any mechanism that meets that literally is likely to be per-display-frame code. The plan should say which reading of the architecture rule it relies on (see Competing Hypotheses).
- **The Debug vs Release divergence repeats.** Debug builds load the saved `AnimationTuner.current`, so a developer judging the bounce in Debug may be seeing tuned rather than shipped values. This is the plan 014 incident. Manual checks should "reset to shipped" first (the plan 005 practice) or run on Release.
- **Lifecycle signals are new ground.** None of first-window shown, finished launching, launch failure, or crash during startup is observed anywhere today. Their timing (017 R9: within 50 ms) and their reliability across app types (menu bar apps, splash screens, Gatekeeper prompts) are unverified. Probe them before committing to requirements.
- **Prepared bitmap size.** If bounce squash or the hand-off into the flight scales the icon above the pop's peak, prepared bitmaps will be upscaled or redrawn on the main actor at gesture time.
- **Revisiting the 60 pt size.** The bounce inherits `iconSide` (017 R4). If someone revives plan 005's "too big" concern for a 10 s on-screen icon, it changes the flight too.
- **Swipe and tuner coupling.** `LaunchTuning` already carries switcher-swipe fields, and presets snapshot everything. Bounce fields join that one value, so loading an old preset resets the bounce knobs to shipped, which is intended by tolerant decoding. Saving a preset captures the bounce, flight and swipe settings together.
