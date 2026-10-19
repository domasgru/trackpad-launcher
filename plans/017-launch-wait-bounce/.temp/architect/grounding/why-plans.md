# Why: the launch animation and its rules (Plans investigator)

### Source
Plans: `plans/<NNN-slug>/plan.md`, `development-logs.md`, and committed `.temp/` notes (they are tracked in git). `plans/017-launch-wait-bounce/` and `research/` were not used.

### What I Searched
- Read in full: `plans/004-launch-icon-animation/plan.md` and `development-logs.md`, and `plans/005-launcher-icon-settings/plan.md` and `development-logs.md`. Also read in full: the dev logs of 001, 006, 012 and 014, and 014 plan.md lines 1-56 (Problem and Requirements).
- Read sections: 001 plan.md (Problem/Solution 1-20, R22 at 419-425, Load-bearing decisions and Concurrency 545-575, `SourcePolicyTests` sketch 1315-1330, Alternatives and Open questions 1380-1400). 002 plan.md (decisions 372-380, Docs 1113-1118, Alternatives 1140-1152) and its dev log Plan bullets. 003 R6 and 150-160. 006 plan.md lines 1313, 1338, 1350 and decision 8 (646). 008 decisions 2 and 9. 009 lines 104-109, 283 and 306. 012 plan.md 400-420, 1220-1240, 1450-1530 and 1604. 006 `.temp/architect/grounding/index.md` F27.
- Grep queries over `plans/*/plan.md`, `development-logs.md`, `design.md` and `testing.md`, with 017 excluded:
  - `launch ?animation|LaunchTuning|LaunchOverlay|AnimationTuner|tuner|preset|playLaunch|prepareLaunch|iconSide`
  - `timer|deadline|asyncAfter|Task.sleep|display ?link|polling|\bpoll\b|time limit`
  - `mouseMoved|mouse moved|follow.*pointer|track.*pointer|window (appear|shown|creat)|first window|didLaunch|didFinishLaunching|isFinishedLaunching|didTerminate|kAXWindowCreated|AXObserver|didActivateApplication|CGWindowList`
  - `bounce|progress indicator|still launching|cold launch|until the app|Dock.*bounc`
  - `background loop|every input is a push|push-only|pushes`
- Grep over committed `plans/*/.temp/**/*.md`, with 017 excluded: `LaunchTuning|tuner|preset|LaunchOverlay|launch animation|keyframe`.

---

## Direct Evidence Found

### (1) Why timers, polling, background loops, display links and per-frame code are banned

**1a. Origin: plan 001's zero-idle-cost requirement (R22) and the source-scan gate.**
- 001 plan.md, Problem statement: "A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled." Solution: "...never touches the network, and idles at zero cost."
- 001 plan.md, R22 "Zero cost when idle": "While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU in Activity Monitor, with at most one momentary blip per minute."
- 001 plan.md, Load-bearing decision 1: "Time is data: frames carry their own timestamps and the tap duration is checked against them, so no clock object or timer exists anywhere. ... Only fired gestures hop to the main actor; the main thread wakes for gestures, not frames".
- 001 plan.md, decision 9: "`SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit." The sketch's banned list includes `("Timer", "R22 timer"), ("asyncAfter", "R22 timer"), ("Task.sleep", "R22 polling"), ("makeTimerSource", "R22 timer")`.
- 001 plan.md, Alternatives: "**An injected `Clock` and a tap-timeout timer.** Conventional, but every lift is observed as a frame, so the frame timestamp is a sufficient clock, and a timer would be the app's only timer (R22)." The same section rejects "Hop every frame to the main actor": "it wakes the main thread ~100 times a second whenever a finger is on the trackpad ... Rejected on cost."
- 001 plan.md, Open questions: "...should `screensDidWake` be a second signal, or is one bounded retry (the app's only timer) acceptable?" A timer was treated as a cost to be justified, not banned outright, at plan time.
- 001 plan.md, the trace table: "R20–R22 | Module boundaries, push-only adapters, `run([])` when inactive, `SourcePolicyTests`".
- Relevance: this is the stated root of the timer/polling ban. It is tied to idle CPU (R22). The architecture prose "every input is a push" is grounded in 001's "every input is a push from a different thread and framework, and the whole app must cost nothing while idle" (001 plan.md:457).

**1b. Plan 002 kept the timer and polling bans and wrote "No timers, no polling, no background loops" into the architecture.**
- 002 development-logs.md, Plan: "Grounding (`why`): the press rule, the button-state sampling and the permission and timer bans were one package for 001's R20 and R22; 002 revokes R20 only → timers and polling stay banned, the frame clock stays the only clock, and the design decides the 3-second window on frames."
- 002 plan.md, "Docs changed in Phase D": "In 'Concurrency', 'No timers, no polling, no background loops' gains: 'the one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives'".
- 002 plan.md, decision 1: "No timer: frames keep arriving while the thumb rests, so expiry is seen on the next frame (within about 10 ms), and when nothing touches, nothing is anchored and nothing is blocked."
- 002 plan.md, Alternatives:
  - "**A deadline instead of a per-frame flag** ('blocking until T' ...). It is self-expiring, but needs a clock both threads trust. `FrameTime` and `CGEventTimestamp` are not known to share a base, and frames already observe expiry within one frame. Rejected."
  - "**Polling `AXIsProcessTrusted` ...** Polling is banned".
  - "**Opening the window only after the prompt is dismissed.** Nothing observable tells the app when the system alert closes, so the window would need a timer or a heuristic over other apps' activation. The hold needs neither."
- 002 plan.md:437, "Deliberately not done": "No grace delay, timer, deadline or second clock."
- 002 development-logs.md, Plan: "Test planner (rejected): a `tapCreate` refusal right after a grant ... a retry would be the app's only timer".
- 002 plan.md, test T49: `confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans` pins `Timer`, `asyncAfter`, `makeTimerSource` and `Task.sleep` in `banned`.
- Relevance: deadlines were considered and rejected for one specific reason (no clock shared across threads), not only on idle cost. There is a precedent for rejecting "a heuristic over other apps' activation" when it would need a timer.

**1c. Plan 004 added the animation rule and the display-link ban.**
- 004 plan.md, "Source policy": "`SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule 'timer'. A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame."
- 004 plan.md, "Docs": "`docs/architecture.md`: Concurrency gains the animation rule: Core Animation keyframes, cleaned up from the completion callback, no display links."
- 004 plan.md, "Lifetime":
  - "The panel is closed from Core Animation's completion callback, never from a timer: `Timer`, `asyncAfter` and `Task.sleep` are banned from shipped sources."
  - "Core Animation renders the frames in the render server. Once the last panel has closed, no code of ours runs."
- 004 plan.md, "Play" step 1: "Reduce motion: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, read fresh on every call. Nothing observes it and nothing polls."
- 004 plan.md, Testing "Fakes and boundaries": "There is no clock to fake: the keyframes carry their own times, and Core Animation owns real time."
- 004 plan.md, "Cleanup and idle" check: "Activity Monitor then shows 0.0 % CPU for Trackpad Launcher while idle, as in plan 001's idle check."
- 004 plan.md, S1 checklist: "No `Timer`, `asyncAfter`, `Task.sleep` or display link appears in shipped sources; the source-policy test passes."
- Relevance: this is the direct origin of "display links are banned along with timers" and "no code of ours runs per frame". The stated reason is that a per-frame callback would run our code on every frame. It is filed under the existing "timer" rule, which traces back to R22.

**1d. Later plans applied and interpreted the rule.**
- 006 `.temp/architect/grounding/index.md` F27: "A switcher highlight driven by finger frames is input-driven work (~100 Hz while the fingers move), not a per-display-frame loop; springs and fades at the ends and on dismissal are animations the render server plays." This interprets "per frame" as per display frame. Work driven by input pushes was judged allowed.
- 006 plan.md:1338, Tradeoffs: "We accept that rendering the switcher in AppKit and Core Animation is more imperative than SwiftUI, in exchange for springs and fades played by the render server with no code of ours per display frame, as in the launch overlay."
- 006 plan.md:1350, Alternatives: "**SwiftUI for the switcher's content.** ... But its springs and scale animations are not Core Animation keyframes, the architecture's animation rule, and the overlay precedent is Core Animation."
- 006 plan.md:1313: "**Deliberately not done.** No timer, deadline or display link."
- 006 development-logs.md, Implement: "Review → switcher close fade used `panel.animator().alphaValue`, not Core Animation (architecture's animation rule) → now a Core Animation opacity fade on the content layer with `orderOut` from its completion, guarded by a generation counter".
- 006 development-logs.md, Implement: "The tracking speed has no push ... so it is read at each swipe start: a read on a user event, not a poll."
- 012 plan.md:409: "No timers, no polling: the TCC broadcast, user events and frames are the pushes".
- 012 plan.md:1604: "The design adds no timer or poll; its one deadline, the AX messaging timeout, lives inside the system call and is checked by hand (M18)." This is the only accepted "deadline" in the plans, and it lives inside a system call.
- 003 plan.md, R6 "No work while idle": "Trackpad Launcher MUST do no periodic work to keep it current." 003 plan.md:158: "Nothing else starts a scan, and there is no timer (R6)."
- 008 plan.md, decision 9: "redraws off the main actor for each app the workspace reports launched (a push, never a poll) ... drops an app's icon when the workspace reports it terminated". Workspace launch and terminate notifications are an accepted push pattern, but they live in `SwitcherPresenter` (the shell).

### (2) Why the overlay is a fire-and-forget port method with a separate prepare

- 004 plan.md, "The port: two methods on `SystemActions`":
  - "**`playLaunchAnimation(for app: AppEntry)`** — Returns at once. — Reads the pointer, the connected displays and Reduce motion at the moment of the call. — Plays for about a third of a second and removes itself. — Every call plays its own animation and never cancels, restarts or reuses one already playing. — Nothing it shows activates Trackpad Launcher, becomes key or receives a click."
  - "No new port. The animation is one more effect the core decides and macOS performs, which is what `SystemActions` already describes. `Launcher`'s initialiser, `World` and the composition root keep their shape."
- The fire-and-forget and "every call its own" contract comes from requirement R14 (004 plan.md): "Every fired gesture MUST start its own animation. A new animation MUST NOT cancel or restart one already playing." Scenarios: "Two gestures in quick succession" and "Same gesture twice", with two Arc icons visible at once.
- Reading the pointer, displays and Reduce motion inside the adapter is backed by R4 ("The icon's centre MUST start on the pointer's position at the moment the gesture fires") and R15. 005 plan.md, decision: "Reduce motion is read inside `playLaunchAnimation` (its contract), so with the setting off there is no fade-in-place path left to leak through (R6, 'whatever the Reduce motion setting')."
- Why prepare exists, from the 004 development-logs.md Plan bullet (an accepted review finding): "R1's 'no later than the haptic feedback' knowingly broken by a first-ever icon render (45–120 ms) at the gesture; T1 claimed timing it cannot see → added `SystemActions.prepareLaunchAnimations(for:)`. `Launcher` passes the present assigned apps from `start()` and whenever it re-resolves rows; the overlay renders and caches their bitmaps."
- 004 plan.md, "The icon is ready before the gesture": "Why: the planning probe measured 45–120 ms for the first render ever of an app's icon at this size, against 1–2 ms afterwards. Rendering at assignment, at launch or when the window opens keeps that cost off the gesture."
- 004 plan.md, prepare contract: "The apps the next launch animations may be for. Each call replaces the previous set. The adapter readies what it needs for them now, so a later `playLaunchAnimation` for one of them does no slow work."
- 004 plan.md, "Warm-up": "Creating a panel's window-server window is the step the probe timed at 26–29 ms in a fresh process, against about 1 ms afterwards."
- 004 plan.md, "Lifetime": "The overlay keeps each live panel in a set until that panel's completion. Calls share nothing else, so a second call never touches a first call's panel (R14)." Also: "The overlay keeps its own set because the probe found a closed panel staying in `NSApplication.shared.windows`."
- 005 plan.md, "Preparing continues regardless of the setting": "This is a performance decision: the first gesture after the switch is turned on then plays a prepared icon instead of rendering one on the main actor ... The alternative (prepare only while on, re-prepare on turning on) adds a path and a way to get a cold icon. T14 pins it."
- 005 plan.md, "The setting lives in `Settings`; the model enforces it in `fire`": "Because the model decides, nothing below it learns about the setting: the `SystemActions` port, `WorkspaceActions` and the overlay are unchanged. An overlay that is never asked to play shows nothing."
- 004 development-logs.md, Merge with main: "Main (PR #2) made icon drawing an off-main-actor rule → `LaunchOverlay.prepare` renders on all cores away from the main actor and swaps the set in when done. `play` draws on the spot only when no ready icon is sharp enough."
- 004 development-logs.md, Implement: "Not changed: `WorkspaceActions` forwarding to the overlay, and the streak rule living in LauncherPlatform. Both are plan decisions ('no new port'; motion is rendering)."

### (3) Why the tuner lives in `LauncherPlatform` under `#if DEBUG` over `LaunchTuning`, and how presets work

- Why the motion lives in LauncherPlatform (004 plan.md, "The launch flight"):
  - "Why LauncherPlatform and not LauncherCore: The motion is how the adapter renders an effect the model decided. It is not a model decision. The trackpad adapter already works this way: its pulse strength, `feedbackActuation`, lives inside it."
  - "Living here, the flight can use `CGPoint`, `CGRect`, `CATransform3D` and `NSMouseInRect` directly. LauncherCore can use none of these, since it imports only Foundation and Observation".
  - 004 development-logs.md, Plan: "Four public LauncherCore types plus two custom geometry values existed only for the overlay → the flight moved into LauncherPlatform as internal types using CG and Core Animation types directly, tested through `@testable import`."
- The tuner and `LaunchTuning` (004 plan.md, "Tuning (Debug builds only)"):
  - "`LaunchTuning` holds every number above. Release builds read its defaults as constants. Debug builds read them through a `Mutex` the tuner writes."
  - "`AnimationTuner` is a floating window that opens when a Debug build launches. It has a slider per number, live preview at the pointer, reset to shipped, and named presets saved in user defaults."
  - "To ship a new tuning, copy its values into `LaunchTuning`'s defaults and adjust the requirement bounds and tests if they move."
  - "Everything in the tuner sits inside `#if DEBUG`, so Release builds contain none of it."
- 004 plan.md, "Curves": "Retuned by feel with the Debug-only tuner ...; the tests check the requirement bounds, not these formulas. Every number lives in `LaunchTuning`, whose defaults are the shipped animation." Further Notes: "The curve constants are feel choices. The tests check requirement bounds, so tuning within those bounds keeps the suite green."
- 004 development-logs.md, "Tuning" section:
  - "The user polished the animation by feel in a Debug-only tuner window and picked their 'Preset 2' → it is the shipped animation: 60 pt, 0.34 s, a 20 % pop over 75 ms, rise 70 pt, and new rise, shrink, fade and sway curves. New R16 (the puff)."
  - "Every animation number moved into `LaunchTuning`, whose defaults are the shipped animation. The tuner (`AnimationTuner`, `#if DEBUG`) stays in the codebase for future polishing; Release builds contain none of it."
- How presets interact with the shipped values:
  - 005 plan.md, "The icon: two tuning numbers": "The Debug tuner needs no change; its 'Shipped' preset is the new defaults. A Debug build with a tuning saved by the tuner plays that tuning, not the shipped one; the manual checks reset to shipped first."
  - 005 plan.md, Verified without a test: "a Release build, or a Debug build after 'Reset to shipped' in the animation tuner (a Debug build plays a tuning the tuner saved, if any)."
  - 005 plan.md, Further Notes: "**The tuner's previews** play through the overlay directly and ignore the setting. They are a Debug-only developer tool, not a gesture."
  - 014 development-logs.md, Verify: "Release always plays `LaunchTuning.shipped` (40 pt, 47 pt rise), while Debug builds open the animation tuner at launch, which applies its saved 'current' tuning, equal to 'Preset 2' (60 pt, 70 pt rise) → at the human's request the shipped tuning now equals Preset 2 (R6)".
- The tuner grew beyond the launch animation:
  - 006 development-logs.md, Implement: "The four numbers are knobs in the Debug animation tuner, read live on every frame." Later in the same log: "The tuner's four gain knobs became a follow-the-cursor toggle, points per icon and a tracking-speed override."
  - 012 plan.md:1457: "We accept one `pointsPerStep` (100) for both slides, so the Debug tuner moves them together." 012 plan.md:700 lists "`CursorTravel` and `LaunchTuning` use `pointsPerStep`".
  - 012 plan.md:1225: "The look and motion, in one value whose defaults are the shipped look, as `LaunchTuning` is for the launch animation: refining it later together touches no policy." (`WindowSwitcherLook`, a parallel pattern.)
  - 012 `.temp/architect/grounding/how-recognition.md:38` (committed grounding note): "`LaunchTuning` swipe fields ... `swipeFollowsCursor = true`, `swipePointsPerIcon = 100`, `swipeTrackingSpeed = -1` ... `current` is `shipped` in Release, the DEBUG tuner's `tunerOverride` Mutex (`LP/AnimationTuner.swift:9`) in Debug."
  - 012 `.temp/architect/grounding/how-platform.md:286`: "The Debug-only `AnimationTuner` writes tuning JSON into `UserDefaults.standard` (`AnimationTuner.swift:79, 141`), the only other `UserDefaults` writer besides `SettingsStore`."
  - 012 `.temp/architect/grounding/how-shell.md:144`: the overlay reads "Reduce motion (or `LaunchTuning.current.forceReduceMotion`)". This is a grounding note describing code, not a plan decision.
- Tolerant decoding: 005 plan.md: "`LaunchTuning` already decodes this way" (missing keys take defaults). 006 `.temp/architect/grounding/how.md:415` cites "the same tolerant pattern exists in `LaunchTuning.init(from:)`".

### (4) Why haptic and overlay ordering, and the 60 pt icon size

**Ordering**
- 001 plan.md, decision 5: "If all pass it plays feedback on `event.trackpad`, brings the app to front and closes the window." This was the original order, before any animation existed.
- 004 plan.md, "When the animation plays: `Launcher.fire`":
  - "Behind its existing guard ... it runs four effects in one synchronous main-actor turn: the pulse, bring to front, the launch animation, then closing the window."
  - "The animation comes after bring to front. Its icon is rendered ahead of time ..., so its work at fire time is 1–2 ms ... Last in line, it cannot hold up the pulse or the app (R13). If some slowness is left, such as an icon that is not ready ..., it lands on the icon, never on the app."
  - "How the plan reads R1's 'no later than the haptic feedback': The pulse is a synchronous actuator call. Any picture reaches the screen on the first display refresh after its layers are committed, so no picture can strictly precede a pulse. The plan therefore meets R1 by issuing the animation in the same main-actor turn as the pulse, with nothing slow in the way."
- 004 requirements: R1 "It MUST appear no later than the haptic feedback." R13 "Showing it MUST NOT take focus from any app, nor delay bringing the target app to front." Scenario "No delay to the target app": "Arc comes to the front as fast as it would without the animation".
- 004 development-logs.md, Specify: "Trigger tied to haptic feedback → R1 triggers on the gesture firing; appears no later than the feedback." Also: "No scenario for 'does not delay bringing the app to front' → added 'No delay to the target app' scenario to R13."
- 004 development-logs.md, Plan: "R13 'no delay' rested on reading code and 'no perceptible difference' → T1 captures through an `onPlayLaunchAnimation` hook that `broughtToFront` already holds the app when the animation is requested."
- 005 plan.md: "`fire` keeps its guard and its four effects in their order. The third, `playLaunchAnimation`, now runs only while the setting is on. The pulse, bring to front and closing the window stay unconditional (R6)."
- Not every bring-to-front plays the animation:
  - 006 plan.md non-goal: "**A launch animation for apps opened from the switcher.** The icon is already large on screen; the user chose a plain disappearance."
  - 009 plan.md non-goal: "**An on-screen indicator or launch animation for swaps.** Swaps are fast and repeated. Visuals would get noisy, and the app coming to the front is feedback enough."
  - 012 R12: "The window swipe MUST never play the launch animation."

**Icon size history (60, then 40, then 60)**
- 004 R3 (as committed): "It MUST start at 60 × 60 points." The 004 implementation sections still say 46 pt (see Contradictions). 004 development-logs.md, Tuning: "picked their 'Preset 2' → it is the shipped animation: 60 pt ... R3, R6, R7, R11 and R15 bounds follow the new numbers".
- 005 plan.md, Problem statement: "The icon starts at 60 × 60 points. That is too big for a quick confirmation and draws more attention than it should." Solution: "starts at 40 × 40 points instead of 60". Decision: "the icon side 60 → 40, and the rise 70 → 47". Non-goal: "**A user-chosen icon size.** One fixed size, 40 points."
- 014 plan.md, R6 "Release builds play the launch animation Debug builds play": "Added during verification, at the human's request: the Release build's launch icon read as much smaller than the one seen in Debug builds, whose animation tuner applies its saved preset ('Preset 2') instead of the shipped tuning. The shipped `LaunchTuning` MUST equal that preset: a 60 pt start side and a 70 pt rise, every other value as already shipped. Plan 005's bounds scale with the start side: a 66–78 pt peak (110–130%), at most 36 pt at the end (60%), at least 20 pt when it becomes invisible (a third), and a 60–80 pt rise."
- Relevance: 60 pt is the result of a feel choice in the Debug tuner (Preset 2). Plan 005 reduced it to 40 for Release, but Debug kept playing Preset 2 at 60. Plan 014 restored 60 because the human preferred what they saw in Debug. Plan 005's "too big" rationale was effectively superseded, though no plan says the 005 problem statement was wrong.

### Past plans on observing other apps' windows, mouse-moved tracking and timers

- **Showing the icon until the window appears was explicitly ruled out (004).**
  - 004 plan.md, Non-goals: "**Showing the icon until the app's window appears.** The animation is a fixed-length confirmation, not a progress indicator."
  - Also: "**Tracking the pointer during the animation.** The icon starts at the pointer and then moves on its own path."
  - 004 development-logs.md, Specify: "non-goals add 'icon until the app's window appears' and 'finger-count indicator'". These were added during spec review.
  - 004 Problem statement, in tension with the non-goal: "A cold app launch can take a second or more. During that time the user sees no sign that the gesture worked or which app is coming."
- **Accessibility observers for windows were rejected (012, change 1).** 012 plan.md, Alternatives: "**Change 1: a window count the frame thread reads, kept current by pushes.** Accessibility observers on the frontmost app for windows created, closed, minimised and restored, plus activation and Space notifications. No round trip, but no push exists for a window entering full screen or moving Space, Chromium and Electron trees are unreliable observers, a read would run on every window change even when no slide happens, and a pushed count could disagree with the begin read's rows, which R1 forbids. Rejected."
- **AX calls are bounded only by the system messaging timeout (012).**
  - 012 plan.md:411: "AX calls are synchronous IPC bounded by a messaging timeout, set process-wide on the system-wide element".
  - 012 dev log, Cross-judge: "the AX messaging timeout was set on the app element only → set once on the system-wide element, process-wide per `AXUIElement.h`".
  - 012 plan.md:1266: "The decision waits up to one messaging timeout (0.2 s)".
  - Also rejected: "**Raises on a serial background queue, or an async window read.** ... the model would gain a loading state and a lift that can arrive before the read lands. For a read of about a millisecond, bounded timeouts instead."
- **Workspace launch and terminate notifications are an accepted push (008).** Decision 9: "for each app the workspace reports launched (a push, never a poll) ... drops an app's icon when the workspace reports it terminated". The observers sit in the shell's `SwitcherPresenter` and are removed while the swipe setting is off. Decision 2: an activation tracker "observes the workspace's did-activate notification" only on the fallback path; "the shipped path on today's macOS registers no observer".
- **Mouse-moved events are never received (002, 006).**
  - 002 R9: the app "MUST NOT read, record or change keyboard input, scrolling, pointer movement or any other event".
  - 006 T76: "`.mouseMoved` and `.keyDown` parse to nil" and the tap mask has "no bit 5".
  - Plan 006 later amended R12 so that scrolling may be suppressed. Pointer movement stayed excluded.
- **No timer or deadline in later plans.** 002 ("No grace delay, timer, deadline or second clock"); 006:1313 ("No timer, deadline or display link"); 012:1604 ("its one deadline, the AX messaging timeout, lives inside the system call").
- **Plan 014 (gate event tap)** is about routing scroll, drag, pressure and gesture events through the active tap. It does not discuss mouse-moved tracking or launch-animation timing. Its only launch-animation content is R6 (icon size) and the Verify bullet quoted above. Its measurements (proc_pid_rusage per trackpad frame; "Idle, nothing touching (shipped) | 0.77 ms per 60 s, 0 idle wakeups | 0.001%") show what the plans count as acceptable per-frame cost.

---

## Indirect / Circumstantial Evidence

- **"Per frame" means per display frame, not per input event.**
  - Source: 006 grounding F27; 006 plan.md:1338.
  - Inference: the plans treat code driven by input pushes at about 100 Hz as compatible with the rule. They treat code running on every display refresh (display link, timer) as banned.
  - Alternative reading: F27 is a grounding note, not a decision. The architecture text itself reads "No code of ours runs per frame" without that qualifier.
- **The display-link ban is filed under "timer".**
  - Source: 004 Source policy, "under the rule 'timer'".
  - Inference: the display-link ban inherits R22's justification (idle cost) rather than having its own requirement.
  - Alternative: 004's own stated reason is that "it would run code of ours on every frame". That is about cost while animating, not idle cost.
- **The no-timer rule has been bent toward system-owned time.**
  - Source: 004 "Lifetime" (CA completion instead of a timer); 012 (the AX messaging timeout is the one deadline, inside the system call).
  - Inference: when a time bound was needed, plans pushed it into a system facility (render server, AX IPC) rather than adding a Swift timer.
  - Alternative: these may be incidental, since each case had a natural system facility available.
- **Ownership of workspace observers.**
  - Source: 008 decision 9 (observers in `SwitcherPresenter`); 004 (overlay owned by `WorkspaceActions`).
  - Inference: no plan places a workspace or app-lifecycle observer inside `WorkspaceActions` or the launch overlay. The precedent for lifecycle pushes sits in the shell, tied to a setting.
- **Sharpness and render size are tuning-coupled.**
  - Source: 004 Curves: "The icon bitmap is rendered at the pop's peak size (72 pt), so it is never scaled up." 004 dev log Tuning: "keyframes are sampled at 240 per second so the short pop stays smooth." 005: "the bitmap is drawn at the peak side × the display's scale in pixels".
  - Inference: the prepared bitmap's size depends on the largest scale any animation reaches. A new animation with a larger peak would need a matching prepare size. No plan states this as a rule.

---

## Contradictions

1. **Plan 004 is internally inconsistent after its tuning pass.**
   - The Requirements (R3 60 pt, R6 60–80 pt, R11 300–400 ms, R16) and "Curves" (60 pt, 0.34 s, sampled every 1/240 s) reflect the tuned animation.
   - The rest of the plan still has pre-tuning numbers:
     - "The launch flight" step 4: "sampled every 1/120 s: 61 values over a 0.5 s duration"; "uniform scale of side ÷ 46"; `LaunchStage.iconSide`: "46 pt".
     - Overlay Prepare: "The bitmap is 46 pt".
     - Testing: T9 "side 46"; T10 "within 30…60"; T11 "≤ 23"; T16 "0.4…0.6 s".
     - "Readings": "R11, 'fully invisible between 400 and 600 ms'".
     - Slice S1: "fades out by 500 ms".
   - The 004 dev log Specify also records "R6 rise (30–60 pt ...)" and "R11 says fully invisible between 400 and 600 ms". The dev log Tuning bullet explains the change. The plan body was only partly updated.
2. **Plans 005 and 014 disagree on icon size.** 005: 60 pt was "too big", so 40 pt and 47 pt rise. 014 R6: the human preferred the Debug build's 60 pt (Preset 2), so shipped returns to 60 and 70. 014 does not revisit 005's "too big" rationale. The 014 dev log attributes the change to "at the human's request".
3. **Plan 004 is in tension with itself on progress.** Its Problem statement cites "A cold app launch can take a second or more. During that time the user sees no sign that the gesture worked". The Non-goals then exclude "Showing the icon until the app's window appears ... not a progress indicator". Both are in the same plan; the non-goal was added at spec review (dev log Specify).
4. **Plan 001 left room for a timer that later plans removed.** 001 Open questions: "one bounded retry (the app's only timer) acceptable?" 002 dev log: "a retry would be the app's only timer" (rejected). In 001 a timer was a cost to weigh; from 002 on it is treated as banned.

---

## Gaps

- No plan explains why `AnimationTuner` lives in `LauncherPlatform` as opposed to the app target or `LauncherUI`. It follows from `LaunchTuning` and the flight living in LauncherPlatform (004 "The launch flight"), but nothing says so. Grepped `tuner` across all plan.md and dev logs.
- No plan describes how presets are structured: names, storage keys, "current" versus named presets, or how a new section is added. 004 says "named presets saved in user defaults". 005 names a "Shipped" preset. 014 names "Preset 2" and a saved "current" tuning. A 012 grounding note says the tuner writes JSON to `UserDefaults.standard`.
- No plan considered `NSWorkspace` `didLaunchApplication` or `didTerminateApplication`, `NSRunningApplication.isFinishedLaunching`, or KVO for a launch-progress purpose. They appear only for switcher icon caching (008).
- No plan considered `kAXWindowCreatedNotification` or `AXObserver` for a launched app. The only AX observer discussion is 012's rejected window-count alternative, which was about the frontmost app.
- No plan discusses a bounded animation longer than about a third of a second, a repeating or bouncing animation, or any timing beyond the CA completion callback.
- Grepped for "bounce", "progress indicator", "cold launch" and "until the app". The only hits are 004's problem statement and non-goal, and unrelated finger-bounce hits in 002.
- No plan discusses the launch overlay following the pointer after it starts, beyond 004's non-goal.
- The 004 dev log records no accepted review finding that motivated the display-link ban. It appears only as a plan decision in "Source policy".

---

## Additional Leads

- For the source-control investigator:
  - The commit that added `displayLink`/`DisplayLink` to `SourcePolicyTests`, and the architecture.md commit for the animation rule. 012 grounding `why-source-control.md:161` names `c81289d` as the architecture.md change; this was not verified here.
  - The 014 commit that set `LaunchTuning.shipped` to Preset 2. Also `AnimationTuner.swift` (UserDefaults keys, preset names, `tunerOverride` Mutex) and `LaunchTuning.swift` (`forceReduceMotion`, swipe fields), to confirm the present preset mechanism.
  - PR #2 ("Main (PR #2) made icon drawing an off-main-actor rule", 004 dev log), for the off-main `prepare` rationale.
- 012 `.temp/architect/grounding/why-plans.md` and `why.md` are an earlier investigator's notes on related questions (the overlay's placement, the animation rule's origin). They agree with the findings above but were not re-verified line by line.
- `docs/architecture.md` lines 20-22 (out of my source): check the exact wording against 002's "No timers, no polling, no background loops" and 004's "Core Animation keyframes, cleaned up from the completion callback, no display links".
