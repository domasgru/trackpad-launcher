# How: the signals the idle condition needs, and how time passes

Scope: what R8 ("no finger has made contact of any kind with any trackpad for 1 minute, and the settings window is closed") can read today, and what any new clock or dependency would trip. Paths are relative to the worktree root. `Core` = `LauncherKit/Sources/LauncherCore`, `Platform` = `LauncherKit/Sources/LauncherPlatform`, `UI` = `LauncherKit/Sources/LauncherUI`.

## Answers first

- **Frames arrive on MultitouchSupport's own thread** and are recognised there. Only recognised events hop to main (`Platform/MultitouchTrackpads.swift:6`, `:98-108`; `docs/architecture.md:18`).
- **No frames arrive while nothing touches the pad.** The code assumes it (`Core/GestureRecognizer.swift:111`, `LauncherKit/Tests/LauncherCoreTests/TouchScript.swift:209`). I also measured it: 40 s hands off on this Mac's built-in trackpad gave 0 callbacks, including none after `MTDeviceStart` (probe below). So "no callback" is the normal idle state, and a last-touch signal cannot be confirmed by a heartbeat.
- **Empty frames do reach the recognizer.** `[]` is "the frame after the last lift" (`Core/Touch.swift:47`). Parsing also yields `[]` from a non-empty raw frame holding only dropped states (`Platform/TouchFrameParsing.swift:45-46`). A raw `count == 0` callback is parsed safely, but I did not observe one on hardware.
- **Recognition stops only when there is nothing to read**: no trackpad connected, the framework failed to load, the device is not a trackpad, or the process has no resident yet. No permission and no setting stops it (`Core/Activity.swift:51-54`, `Core/Launcher.swift:270-273`).
- **The tap point is `DeviceSession.receive(_:)`** (`Platform/FrameStream.swift:57`), on `frame.touches` before the recognizer. It is per device, replaced by every `run`, already on the frame thread, and sees edge contacts, which the recognizer removes at its first line (`Core/GestureRecognizer.swift:97`). Use edges (empty to occupied, occupied to empty), not per-frame stamps. Per-frame clock reads are explicitly avoided today (`Core/TrackpadTapState.swift:24-25`).
- **The settings window's edges reach `Updater` by direct method call** from `Launcher` (`Core/Launcher.swift:230`, `:237`). There is no port and no observation involved.
- **No timer exists anywhere in the sources.** The only `DispatchSource` is a process-exit source (`Platform/SystemRunningCopies.swift:42`). There is no reachability code. Wake is observed in exactly one place and is folded into `.trackpadsChanged` (`Platform/MultitouchTrackpads.swift:48-52`, `Core/Ports.swift:8-9`).
- **SourcePolicyTests does not scan dependencies.** Its roots are `LauncherKit/Sources` and `TrackpadLauncher/`, `.swift` only (`SourcePolicyTests.swift:221-226`, `:350-355`). `import Sparkle` is banned only in `LauncherCore` (`:315-321`).

## Components Found

| Component | File | What it does |
|---|---|---|
| `MultitouchSupport` | `Platform/MultitouchSupport.swift:7` | `dlopen`s the private framework and resolves 13 symbols; any missing symbol fails the whole `init?`, which reads as "no trackpad" (`:6`, `:29-56`). |
| `MultitouchTrackpads` | `Platform/MultitouchTrackpads.swift:10` | `@MainActor` `TrackpadHardware` adapter: lists devices, runs sessions, IOKit hot-plug, wake observer, haptics. |
| `DeviceSession` | `Platform/FrameStream.swift:23` | One running trackpad on the frame thread; replaced by every `run`, holds the recognizer and tap state behind `Mutex`es. |
| `sessions` | `Platform/FrameStream.swift:104` | Global `Mutex<[UInt: DeviceSession]>`, keyed by device ref bit pattern; "the only state shared with the frame thread". |
| `contactFrameCallback` | `Platform/FrameStream.swift:106` | The C callback: finds the session, samples the press, parses, calls `receive`. |
| `mergedTapState(at:)` | `Platform/FrameStream.swift:120` | Tap thread reads all sessions' state and merges it: the precedent for reading per-device state from another thread with no per-frame hop. |
| `MTTouchMirror`, `TouchFrame(parsing:…)`, `DriverState` | `Platform/TouchFrameParsing.swift:4`, `:40`, `:59` | 96-byte record mirror; keeps states 3 (`makeTouch`) and 4 (`touching`) only. |
| `TouchFrame`, `Touch`, `FrameTime` | `Core/Touch.swift:48`, `:14`, `:34` | Core's frame snapshot and the driver's clock value. |
| `GestureRecognizer`, `Recognition`, `Blocking` | `Core/GestureRecognizer.swift:81`, `:4`, `:50` | Pure per-trackpad state machine, one per session. |
| `EdgeContacts` | `Core/Surface.swift:68` | Removes palm-band contacts inside `step`, so `Recognition` does not describe pad occupancy. |
| `TrackpadTapState` | `Core/TrackpadTapState.swift:6` | Clock-free per-trackpad value: blocking level and lift window end. The precedent for a Core value stamped by the adapter. |
| `TrackpadHardware`, `TrackpadEvent` | `Core/Ports.swift:26`, `:3` | The port and its event enum; `.trackpadsChanged` means "Attached, detached, or the Mac woke". |
| `WindowSwipeConfirmation` | `Core/WindowSwipeConfirmation.swift:6` | Every event reaches `onEvent` through it; events other than a window swipe start pass straight through (`:16-20`). |
| `Launcher` | `Core/Launcher.swift:11` | Owns `window`, `isWindowOpen`, `reconcile`; reports window edges to `Updater`. |
| `Updater` | `Core/Updater.swift:10` | Receives `windowOpened()` and `windowClosed()`; both are internal, so only Core can call them. |
| `Lifecycle` | `Core/Lifecycle.swift:125` | Builds the resident; reads `launcher.isWindowOpen` in `shouldEnd`. |
| `SettingsShell`, `SettingsWindow` | `UI/SettingsShell.swift:20`, `UI/SettingsWindow.swift:6` | Render `launcher.window`; the window never closes on its own. |
| `LaunchClock`, `LaunchClock.Deadline` | `Platform/LaunchClock.swift:7`, `:86` | The one general deadline facility: a 1-to-1 opacity animation on a zero-size layer in a never-shown panel. |
| `Uptime`, `Uptime.now` | `Core/Uptime.swift:5`, `Platform/UptimeNow.swift:6` | The process clock value (Core never reads it) and its single read site. |
| `ClickTap` | `Platform/ClickTap.swift:13` | The one extra thread; frame threads only read `holding` and call `wake()`. |
| `QuitSignals` | `Platform/QuitSignals.swift:5` | Observes `willPowerOffNotification`; distinct from sleep. |
| `InMemoryTrackpads` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:6` | Test adapter with `sleep()`, `wake()`, `attach`, `detach`, `advanceClock(by:)`. A new port member needs a mirror here (`docs/architecture.md:14`). |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:7` | Source scan for banned and confined APIs; full list below. |

## Flow

### The frame path

1. **Device start.** `Launcher.start()` (`Core/Launcher.swift:110`) calls `reconcile()` (`:125`), which calls `hardware.run(...)` (`:278`). `MultitouchTrackpads.run` (`Platform/MultitouchTrackpads.swift:68`):
   - increments `runs` (`:72`), then returns if `framework` is nil (`:73`);
   - empties `sessions` first (`:74`), so an in-flight frame finds nothing and is dropped (`FrameStream.swift:102-103`);
   - removes the click tap (`:76-77`), unregisters and stops every started device (`:78-82`), closes actuators (`:83-85`);
   - for each wanted device, builds a `DeviceSession` with a fresh recognizer (`:93-108`), inserts it (`:114`), registers the callback (`:115`), and calls `MTDeviceStart` (`:116`).
2. **A frame.** On the framework's thread (`MultitouchSupport.swift:9-10`), `contactFrameCallback` (`FrameStream.swift:106-111`) runs. The callback is context-free, so it finds state through the registry:
   - `sessions.withLock` lookup (`:107`);
   - `session.holding`, a read of `ClickTap.filters`' Mutex when a tap is live, and `anyMouseButtonDown()`, up to three `CGEventSource.buttonState` reads (`:108`, `:114-116`);
   - `TouchFrame(parsing:…)` (`:109`) allocates an array and keeps states 3 and 4 only (`TouchFrameParsing.swift:41-53`). Nil pointer or `count == 0` gives `[]` (`:42`, tested at `TouchFrameParsingTests.swift:31-35`).
3. **`DeviceSession.receive`** (`FrameStream.swift:57-84`), still on the frame thread:
   - reads `answer` Mutex (`:58`);
   - `recognizer.withLock` runs `answerWindowSwipe` then `step` (`:59-68`);
   - `state.withLock { needsTime }` (`:71`), reads the clock only if needed (`:72`), then `state.withLock { take }` (`:73`). The clock is deliberately read outside any lock (`:69-70`);
   - `tap?.wake()` only if `wantsTap` flipped (`:74`);
   - `deliver(...)` only when `recognition.event` is non-nil (`:75-83`).
4. **The hop.** The `deliver` closure (`MultitouchTrackpads.swift:98-108`) does `DispatchQueue.main.async`, guards `self.runs == generation` (`:103`), and goes through `confirmation.deliver(event, to: self.onEvent)` (`:104`). So an event from a replaced session is dropped, reply included.
5. **The model.** `Launcher.start`'s `onEvent` switch (`Core/Launcher.swift:111-119`) routes to `fire`, `swipe`, `windowSwipe`, `swap` or `reconcile(restart: true)`. The switch is exhaustive, so a new `TrackpadEvent` case is compile-forced here.

What is behind a Mutex: `sessions` (`FrameStream.swift:104`); per session `recognizer` (`:25`, "the compiler's proof… never contended", `:21-22`), `state` (`:29`, writer frame callback, reader click tap thread), `answer` (`:37`, writer main, reader frame callback). On `ClickTap`: `filters`, `ports`, `runLoop`, `wakeUp` (`ClickTap.swift:15-22`). `nonisolated(unsafe)` is banned (`SourcePolicyTests.swift:75`). The rule is `docs/architecture.md:18`: "State shared with that thread lives behind a `Mutex` with one writer."

### What arrives at the frame callback, by state

Touches parsed (`TouchFrameParsing.swift:58-62`): only `makeTouch = 3` (phase `.landing`) and `touching = 4` (phase `.down`). "every other state is dropped". `TouchFrameParsingTests.swift:15-16` confirms states 2 and 5 are dropped. `Touch`'s doc names them "hovering, lingering and lifted contacts" (`Core/Touch.swift:11`). Consequences:

- A frame with hover-only or lift-only records has raw `count > 0` and parsed `touches == []`.
- "Any callback arrived" is therefore not "a finger made contact". `!frame.touches.isEmpty` is the right read.
- `Touch.swift:47` documents `[]` as "the frame after the last lift", and `Core/GestureRecognizer.swift:237` relies on an empty frame to end a thumb touch. `DeviceSessionAnswerTests.swift:163-164` plays two successive empty frames, so a tap must tolerate repeats.

### Trackpad connect/disconnect and sleep/wake

- **IOKit.** `MultitouchTrackpads.init` registers `kIOFirstMatchNotification` and `kIOTerminatedNotification` on `"AppleMultitouchDevice"` delivered on main (`:28-47`). Initial matches are drained so they do not count (`:45`, `:8`). Each notification calls `onEvent(.trackpadsChanged)` (`:40`). The match covers every multitouch device, so a Magic Mouse or Touch Bar fires it too, and `listTrackpads` filters later (`TrackpadClassification.swift:3-8`).
- **Wake.** `NSWorkspace.didWakeNotification` on main calls `onEvent(.trackpadsChanged)` (`:48-52`). Reason in the header: "devices stop delivering frames across sleep and `run` restarts them" (`:8-9`, also `Core/Launcher.swift:255-256`). The test double models it: "After sleep the real devices deliver nothing until `run` restarts them" (`InMemoryAdapters.swift:101-102`; test at `LauncherTests.swift:267-280`).
- **Handling.** `.trackpadsChanged` calls `reconcile(restart: true)` (`Core/Launcher.swift:117`), which re-reads `connected()` and runs regardless of `lastRun` (`:274`).
- **Other `run`s.** `reconcile()` without `restart` re-runs when the `Run` value differs (`:274`): thumb corner, swipe, window swipe and swap settings, a connected-set change, a trust change, or a tap-to-click preference change (`:158`, `:173`, `:182`, `:190`, `:123-124`). So `run` can happen with the window closed, on a preference or permission push, mid-touch.
- `willSleepNotification` is not observed anywhere. Neither are screen lock, display sleep or session switch notifications.

### When recognition stops

| Condition | Effect | Source |
|---|---|---|
| No trackpad connected | `activity` inactive, `run([])`, no sessions | `Core/Activity.swift:53-55`, `Core/Launcher.swift:264`, `:271` |
| `dlopen` or any `dlsym` fails | `framework` nil, `connected()` empty, `run` returns after `runs += 1` | `MultitouchSupport.swift:6`, `:31`, `:56`; `MultitouchTrackpads.swift:25`, `:73`, `:140` |
| Device read fails, or Product lacks "Trackpad" | Not listed, never run | `MultitouchTrackpads.swift:147-151`, `TrackpadClassification.swift:6` |
| Process has no resident yet (`.idle`, `.replacingOthers`) | `MultitouchTrackpads()` not constructed yet | `TrackpadLauncherApp.swift:79-85`, `Core/Lifecycle.swift:257-261` |
| System asleep, before `run` on wake | Devices deliver nothing | `MultitouchTrackpads.swift:8-9` |
| `run` in progress | Sessions empty; in-flight frames dropped | `FrameStream.swift:102-103` |

Does **not** stop recognition:

- **Accessibility or Screen Recording missing.** Gestures are "active whenever a trackpad is connected, whatever its settings and the Accessibility permission" (`Core/Activity.swift:51-52`). Without access only `blockClicks` and window swipe slides change (`Core/Launcher.swift:267`, `:273`). MultitouchSupport needs no permission (`docs/architecture.md:26`).
- **All gestures unassigned, or every slide and swap setting off.** `run.trackpads` depends only on `active`.
- **Settings window open or closed.** No relation.

A resident therefore has sessions whenever a trackpad exists, for its whole life.

### Settings window reporting

- **State.** `Launcher.window: Window` is `.closed` or `.open(request:)` (`Core/Launcher.swift:54-62`), with `isWindowOpen` at `:23`. It is `@Observable`.
- **Opening.** `openedByHand()` (`:214-231`) computes `opens = window == .closed` (`:224`), sets `.open(request:)` (`:226`), and calls `updater?.windowOpened()` only on the edge, last (`:229-230`). Callers: `Lifecycle.openedAgain` (`Core/Lifecycle.swift:197`), `othersExited` (`:262`).
- **Closing.** `closeWindow()` (`:234-238`) guards, sets `.closed`, then `updater?.windowClosed()`. Callers:
  - `SettingsShell.windowShouldClose`, which returns false so AppKit never closes it (`UI/SettingsShell.swift:111-114`);
  - the ⌘Q item (`:116`);
  - Escape via `window.onCancel` (`:74`, `UI/SettingsWindow.swift:34`);
  - the Close button in the view (`UI/SettingsView.swift:108`);
  - `Lifecycle.shouldEnd` for the Dock's Quit (`Core/Lifecycle.swift:212-213`).
- **Updater's side.** `windowOpened()` and `windowClosed()` are internal (`Core/Updater.swift:60`, `:70`). `Updater` is a Core object injected into `Launcher` (`Core/Launcher.swift:85`, `:90`, built at `TrackpadLauncherApp.swift:54-56`, `:85`). No port is involved, since both are models in one module. `Updater`'s header states the contract (`Core/Updater.swift:7-8`).
- **Rendering.** `SettingsShell` observes `launcher.window` in a `Task` over `Observations` (`UI/SettingsShell.swift:98-103`) and renders it (`:141-166`). So the model flips before AppKit's `orderOut`. The activation policy flip is there too, and is confined to this file (`SourcePolicyTests.swift:157-159`).
- **Minimised or hidden.** The state stays `.open`; `render` deminiaturises and unhides on re-opening (`:159-162`). A minimised window keeps R8's window condition false, and nothing today reports miniaturisation.
- **Today's `windowClosed()` has update semantics R8 reverses.** It cancels a download (`Core/Updater.swift:70-78`), and `windowOpened()` starts the check (`:60-66`). Under the plan both behaviours go, and only the edges stay useful.

### How time passes

The rule (`docs/architecture.md:20`): "No timers, no polling, no background loops: every input is a push". "This is what keeps idle CPU at zero." "Time passes only on Core Animation's clock, and in one network request's own idle timeout". "a deadline is an animation on a layer of the effect it belongs to, its completion is the push, and it cannot outlive that effect." Also `:21`: display links are banned along with timers.

Existing mechanisms:

1. **`LaunchClock`** (`Platform/LaunchClock.swift`). Each clock is a `CALayer` in a shared 1×1 `NSPanel` (`.borderless`, `.nonactivatingPanel`, `defer: false`) that is never ordered in (`:69-81`), made with the first clock and closed with the last (`:19-21`, `:62-66`). `after(_:_:)` adds a 1-to-1 `opacity` `CABasicAnimation` with `Deadline` as delegate (`:31-49`). A layer needs a window: "an animation on a detached layer stops at once" (`:8-9`). `stop()` cancels all deadlines (`:52-67`).
   - Users: `LaunchWatch` (`Platform/LaunchWatch.swift:46-48`, `:55`, `:121`) and `BackgroundHider` (`Platform/BackgroundHider.swift:57`, `:66`, `:86`).
   - Longest production deadline: 10 s (`Core/WatchedLaunch.swift:55`).
   - `LaunchClock` is internal to `LauncherPlatform`, and `@MainActor`.
2. **Other Core Animation completions.** `CATransaction.setCompletionBlock` in `UI/OverlayPanel.swift:105`, `Platform/BounceOverlay.swift:284`, `Platform/LaunchOverlay.swift:54`. Effect-local cleanup only.
3. **`Uptime`** (`Core/Uptime.swift:3-5`): "Seconds on the process's own monotonic clock… Not `FrameTime`… the two cannot be compared by mistake. Core defines the value and never reads the clock." Single read at `Platform/UptimeNow.swift:6` (`systemUptime`, confined by `SourcePolicyTests.swift:121`). `Uptime` has `<` and `+ Duration` only.
4. **The lift window** (`docs/architecture.md:20`, the "one deadline outside both"). `DeviceSession` is built with `clock: { .now }` (`MultitouchTrackpads.swift:97`). `TrackpadTapState.needsTime` (`Core/TrackpadTapState.swift:20-22`) says yes only when a lift window opens or one is pending: "an ordinary touch reads no clock" (`:24-25`). The stamp is `time + GestureRules.liftWindow` (`:33`, `Core/GestureRules.swift:26`). It is compared on the click tap thread via `mergedTapState(at: .now)` (`ClickTap.swift:98`). "nothing fires at the end" (`docs/architecture.md:20`). The frame's own timestamp is explicitly not used.
5. **`FrameTime`** (`Core/Touch.swift:33-34`): the driver's clock, "the only time recognition ever reads". All recognizer rules use it.
6. **The network idle timeout.** `timeoutIntervalForRequest = stall` (`Platform/GitHubReleases.swift:163`, `:172`), 30 s, plus `waitsForConnectivity = false` (`:162`). It goes away if `GitHubReleases` goes.

Search result for `Timer|DispatchSource|asyncAfter|Task.sleep|NSBackgroundActivityScheduler|makeTimerSource|CADisplayLink|displayLink|DisplayLink|afterDelay|CFRunLoopTimer|ContinuousClock|SuspendingClock|usleep|nanosleep|Thread.sleep|IORegisterForSystemPower|IOPM|SCDynamicStore`, over `LauncherKit/Sources` and `TrackpadLauncher`:

- The single hit is `DispatchSource.makeProcessSource` (`Platform/SystemRunningCopies.swift:6`, `:42`), an exit source and not a timer.
- `Task.sleep` and `ContinuousClock` appear only in tests (for example `LaunchWatchClockTests.swift:33`), which are not scanned.

Sleep and wake observers, complete list:

- `NSWorkspace.didWakeNotification` at `MultitouchTrackpads.swift:49`, exists only in a resident, not exposed separately to Core.
- `NSWorkspace.willPowerOffNotification` at `QuitSignals.swift:12`, created with the `AppDelegate` (`TrackpadLauncherApp.swift:21`).
- Nothing else.

Network reachability: none. Grep for `Reachab|NWPath` over the sources finds nothing. `import Network` is banned (`SourcePolicyTests.swift:45`). The nearest thing is `waitsForConnectivity = false` above.

App Nap and activity assertions: `beginActivity`, `NSAppSleepDisabled` and automatic termination appear nowhere in sources, `project.yml` or `Config`. The bundle is `LSUIElement: true` (`project.yml:39`).

## Where a contact signal can be tapped

R8 wants "contact of any kind". `Recognition` cannot supply that: `step` first calls `edgeContacts.fingers(in: frame)` (`Core/GestureRecognizer.swift:97`), removing palm contacts for as long as they stay down (`Core/Surface.swift:64-67`, `:79-92`). `blocking` and `isInThumbTouch` are "edge contacts aside" (`docs/domain-model.md:195`). `TrackpadTapState.level` is `.none` for an ordinary finger, so it cannot serve either. `state == .idle` is also not "empty".

| Tap point | Sees palm contacts | Sees hover as contact | Per-device, resets on `run` | Notes |
|---|---|---|---|---|
| `contactFrameCallback` raw `count` (`FrameStream.swift:106`) | yes | **yes, wrong** | no | Before parsing; has to read raw states itself, breaking "only this file knows its layout" (`TouchFrameParsing.swift:3`). |
| `DeviceSession.receive`, `frame.touches` (`FrameStream.swift:57`) | yes | no | **yes** | Best fit. Already testable by direct call (`DeviceSessionAnswerTests.swift:35`). |
| Inside `GestureRecognizer.step`, before line 97 | yes | no | yes | Would add to `Recognition`, and `InMemoryTrackpads.touch` would get it for free (`InMemoryAdapters.swift:118`). Needs care: `frame` is shadowed at `:97`. |
| After `step`, from `Recognition` | **no** | no | yes | Misses resting palms. |

Without per-frame main-actor hops, two shapes fit existing precedents:

1. **Edge hop.** Each session keeps "was occupied" as frame-thread state. Only on a flip does it call `deliver` with a new `TrackpadEvent` (at most two hops per touch sequence). Precedents: `tap?.wake()` fires only on a flip (`FrameStream.swift:74`, `TrackpadTapState.swift:15`, `docs/architecture.md:20`: "A trackpad's frame thread only wakes that thread when what it needs flips"). The main queue preserves order from one frame thread (`MultitouchTrackpads.swift:99`). The model cancels or re-arms a deadline on these edges.
2. **Stamp and read on demand.** Each session keeps a Mutex-guarded value, stamped only on flips, read by a main-actor deadline through a merge over `sessions` (`mergedTapState` shape, `FrameStream.swift:118-122`: "Copies the sessions out first: never two locks at once"). This needs a re-check when the deadline fires, and one repeating deadline while an update waits.

Either way, a stamp must not be read per frame while contacts stay down. Occupied state plus "time of the occupied-to-empty flip" is enough, because while occupied the answer is simply no.

**The reset rule for both shapes.** A replaced session vanishes with its state, and its in-flight `deliver` is dropped by the generation guard (`MultitouchTrackpads.swift:103`). So:

- A main-actor "some pad occupied" flag fed by edge hops will stick at true if `run` replaces an occupied session. `run` must reset it, or the aggregate must derive from live sessions.
- A stamp held only in a session is lost on `run`, so a "last touch 5 s ago" followed by a preference push or a wake would read as "never touched". Keep the last stamp outside the session, or treat `run` as a touch.
- After `run`, a finger still resting produces frames marked `.down` on the first frame (`Core/GestureRecognizer.swift:111-114`, `docs/domain-model.md:192`), so occupancy rebuilds itself. A hand resting during a `run` is seen again on the next frame.

**How a "last touch" goes stale.**

- It does not go stale from recognition stopping for a permission or setting.
- It can go stale only by a device silently stopping without an IOKit termination or a `didWake`. Nothing in the repo shows that happening, but nothing would detect it either, because no-callback is also the idle state. The failure direction is toward installing (fail open), not stuck.
- With a framework load failure there is no signal at all, so the touch half of R8 is always satisfied. That matches "Mac with no trackpad in use".
- Between process start and the resident there is no signal. A login start with an update already waiting should not read that gap as idle time before a first `run`.

## Live probe (this Mac, 2026-11-06)

Read-only, `python3 -I -B -u -c` with ctypes, no file written. It registered a counting callback and ran `MTDeviceStart`, the same as `Scripts/perf/mtidle.c`. Hardware: one device, Product `Apple Internal Keyboard / Trackpad`.

- **40 s, 0 frames**, no callback at start, no callback after. `MTDeviceStart` returned 0.
- **Not covered: frames during touch.** Nobody touched the pad, so a real empty frame, state sequence after a lift, frame rate, and how `timestamp` relates to `Uptime` are all unmeasured.
- **Clock read:** `systemUptime` 20222.989, `CLOCK_UPTIME_RAW` 20222.989, `CLOCK_MONOTONIC_RAW` 20222.989, `CLOCK_MONOTONIC` 20216.108. Those first three agree because this Mac has not slept since boot, so this says **nothing** about which clock `systemUptime` follows across sleep.
- Side note: the framework itself printed `*** Recognized (0x6d) family*** (24 cols X 18 rows)` at list or start time. It is the framework's output and not the app's logging.

Corroboration for idle silence: `docs/performance.md:47`, hands off 60 s twice, 0 idle wakeups and 0.77 ms CPU.

Rate: `docs/performance.md:71`, 0.391 ms per frame and 2.34% of a core works out to about 60 frames per second of touching (my arithmetic). `TouchScript.frameIntervalMS = 10` (`TouchScript.swift:46`) is a test value and not a measured rate.

## SourcePolicyTests

File: `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`. Run by `Scripts/test.sh` (`exec swift test`), `make test`.

### Scan mechanics

- **Roots** (`:221-226`): `LauncherKit/Sources` and `TrackpadLauncher/`, each only if it exists.
- **Files** (`:350-355`): recursive, `pathExtension == "swift"` only.
- **Match** (`:369-374`): plain case-sensitive substring per line. Comments and string literals count. There is no word boundary.
- **Confined** (`:358-362`): allowed by `lastPathComponent`, so any file of that name in any folder passes.
- **Manifest** (`:365-367`): only `project.yml`, only for `neverDeclared`. A missing manifest throws, which fails (`:252-261`).
- **Not scanned:** tests, `Scripts/`, `.c`, `.m`, `.h`, `.plist`, `Config/`, `LauncherKit/Package.swift`, and `LauncherKit/.build` (including any SwiftPM checkout, which lies outside `Sources`). **A dependency is not scanned** unless its Swift source is placed under `LauncherKit/Sources` or `TrackpadLauncher/`. `Sparkle.framework` as a binary or package is invisible to it. The rules bind this repository's own Swift only.
- **`scanVisitsEveryLibraryTarget`** (`:307-313`) requires hits under `Sources/LauncherCore`, `LauncherPlatform`, `LauncherUI`, and `/TrackpadLauncher/`.
- **`theNetworkBansAreAllStillListed`** (`:204-214`) fails if any of these leaves `banned`: `URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier`, `String(contentsOf:`, `NSURLConnection`, `NSURLDownload`, `downloadTask`, `.download(`, `CFHTTP`, `import WebKit`, `WKWebView`, `curl`, `NSAppleScript`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`, `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn`, `Timer`, `asyncAfter`, `Task.sleep`, `.write(to:`, `FileHandle(forWriting`, `createFile(atPath`.
- **Imports** (`:315-321`, `:336-348`): `LauncherCore` may import only `Foundation` and `Observation`. There is no import rule for Platform, UI or the app, other than the banned `import` tokens below.

### `banned` (`:17-93`), everywhere, no exception

| Rule | Tokens | Lines |
|---|---|---|
| sudden termination: `suddenTerminationRule` (`:14-15`), "loginwindow force-quits, 3 s after a foreground app ends, every child of it that is a UI element without a visible window and declares sudden termination; the new version is that child for its first moments after an update" | `SuddenTermination` | 18 |
| "log" | `print(`, `debugPrint(`, `dump(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os` | 19-26 |
| "network" | `URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier`, `String(contentsOf:`, `NSURLConnection`, `NSURLDownload` | 27-32 |
| "the update archive is received into memory, never into a file" | `downloadTask`, `.download(` | 33-34 |
| "network" | `CFHTTP`, `import WebKit`, `WKWebView`, `curl`, `NSAppleScript` | 35-39 |
| "no child processes" | `Process()`, `Process.run(`, `executableURL`, `NSTask`, `posix_spawn` | 40-44 |
| "network" | `import Network`, `NWConnection`, `CFSocket`, `CFStream` | 45-48 |
| "own files" | `FileHandle(forWriting`, `.write(to:`, `createFile(atPath` | 49-51 |
| "timer" | `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink` | 52-53, 55-57 |
| "polling" | `Task.sleep` | 54 |
| "no Input Monitoring or event posting" | `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `IOHIDRequestAccess`, `IOHIDCheckAccess`, `CGRequestPostEventAccess`, `CGPreflightPostEventAccess` | 58-64 |
| "R9 no keyboard" | `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged` | 65-70 |
| "scrolling is read only by the click tap" | `ScrollWheel` | 71 |
| "R9 never synthesise" | `.post(tap:`, `CGEventPost`, `postToPid` | 72-74 |
| "one writer per field" | `nonisolated(unsafe)` | 75 |
| "a run-loop source's perform is a file-scope constant: written inside main-actor code it traps off main" | `perform: {` | 76-78 |
| "the window switcher only raises a window" | `AXUIElementSetAttributeValue`, `kAXPressAction` | 79-80 |
| "previews are pictures, never a stream" | `SCStream(` | 81 |
| "previews are pictures, never a recording" | `SCRecordingOutput` | 82 |
| "a preview is never encoded or written" | `CGImageDestination`, `representation(using`, `tiffRepresentation` | 83-85 |
| "no menu bar icon" | `NSStatusBar`, `NSStatusItem` | 86-87 |
| "nothing relaunches the app" | `SMAppService.agent`, `SMAppService.daemon`, `SMAppService.loginItem`, `SMLoginItemSetEnabled` | 88-91 |
| "the administrator's swap removes nothing" | `/bin/rm` | 92 |

### `neverDeclared` (`:95-97`), in `project.yml` only

`NSSupportsSuddenTermination`, rule `suddenTerminationRule`.

### `confined` (`:108-202`), token allowed only in the named files

| Token | Allowed in | Rule | Line |
|---|---|---|---|
| `URLSession` | `GitHubReleases.swift` | the update check and its download are the one network path | 110 |
| `http` | `GitHubReleases.swift` | the one network file holds every address | 112 |
| `Data(contentsOf:` | `Apps.swift` | the one local-file reader; a URL read is a request | 113 |
| `AXIsProcessTrusted` | `SystemPermissions.swift` | R9 one permission, one adapter | 114 |
| `notify_register` | `SystemPermissions.swift` | R7 the trust push | 115 |
| `ScreenCaptureAccess` | `SystemPermissions.swift` | one permission check, one adapter | 117 |
| `ScreenCaptureKit`, `SCShareableContent`, `SCScreenshotManager` | `PreviewCapture.swift` | one file captures the screen | 118-120 |
| `systemUptime` | `UptimeNow.swift` | the process's clock is read in one place | 121 |
| `tapCreate`, `CGEventTapCreate`, `tapEnable`, `tapIsEnabled` | `ClickTap.swift` | the click tap's event taps, one file | 122-125 |
| `mouseMoved` | `BounceOverlay.swift`, `ClickTap.swift` | pointer moves are read only while a launch bounce shows; the click tap only rewrites to one | 127-128 |
| `addGlobalMonitorForEvents`, `addLocalMonitorForEvents` | `BounceOverlay.swift` | pointer moves are read only while a launch bounce shows | 130-134 |
| `scrollWheel` | `ClickTap.swift` | scrolling is read only by the click tap's event taps | 135 |
| `_LSCopyApplicationArrayInFrontToBackOrder`, `_LSCopyApplicationInformation` | `LaunchServicesOrder.swift` | the private ⌘-Tab order has one reader | 137-141 |
| `AXUIElement`, `CGWindowList` | `FrontmostAppWindows.swift`, `LaunchWatch.swift` | the window reads have two readers | 142-143 |
| `.hide(` | `BackgroundHider.swift` | apps are hidden in one place | 144 |
| `SecCode`, `SecStaticCode`, `SecRequirement` | `CodeSignature.swift` | the code signature is read in one place | 145-147 |
| `ignoringOtherApps` | `AppActivation.swift` | the override of the active app has one home, with its reason | 149-150 |
| `.activate()` | `AnimationTuner.swift` | the plain call is refused when an opening by hand starts the process; it lives only in the Debug tuner, whose click-time call is user intent | 152-153 |
| `/bin/mv` | `PrivilegedInstall.swift` | the administrator's move has one script | 154 |
| `osascript` | `PrivilegedInstall.swift` | the administrator's exchange has one script | 155 |
| `SMAppService` | `SystemLoginItem.swift` | one login item, one adapter | 156 |
| `setActivationPolicy` | `SettingsShell.swift` | the Dock icon follows the settings window, in one place | 158-159 |
| `disableRelaunchOnLogin` | `TrackpadLauncherApp.swift` | only the login item starts the app at login | 161-162 |
| `keyAELaunchedAsLogInItem` | `ThisCopy.swift` | the launch event is parsed in one place | 164-165 |
| `currentAppleEvent` | `ThisCopy.swift`, `TrackpadLauncherApp.swift` | the launch event is read at the app delegate and parsed in one place | 167-168 |
| `forceTerminate` | `SystemRunningCopies.swift` | other copies are stopped in one place | 170 |
| `.terminate(` | `SystemRunningCopies.swift` | processes are ended in one place | 171 |
| `copyItem(`, `moveItem(`, `replaceItemAt(`, `renamex_np(`, `removeItem(` | `BundleInstall.swift` | the move's file operations are in one file | 172-176 |
| `AppleArchive`, `ArchiveStream`, `ArchiveByteStream` | `BundleInstall.swift` | the update's unpacking is in one file | 177-182 |
| `removexattr` | `BundleInstall.swift` | the quarantine is cleared in one file | 183-184 |
| `itemReplacementDirectory` | `BundleInstall.swift` | the staging folder is made in one file | 185-187 |
| `createsNewApplicationInstance` | `ApplicationsUpdater.swift` | the new version is opened as a new process in one place | 188-190 |
| `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` | `PrivilegedInstall.swift` | the one privileged call has one file | 191-195 |
| `statfs`, `DADisk`, `unmountVolume` | `DiskImages.swift` | disk images are read and ejected in one place | 196-198 |
| `SecTranslocate` | `ThisCopy.swift` | translocation is read in one place | 199 |
| `runModal` | `MoveDialogPresenter.swift` | the move dialog is the one modal | 200 |
| `kAEQuitReason` | `QuitSignals.swift` | the quit event is parsed in one place | 201 |

### What a new dependency or clock would trip

- **`import Sparkle`.** Not banned as a token. Fails only in `LauncherCore`. `LauncherUI` depends only on `LauncherCore` (`LauncherKit/Package.swift:15-19`). `LauncherKit/Package.swift` has no package dependencies today, and `project.yml` wires only the local `LauncherKit` package (`:12-14`, `:25-30`).
- **`Timer` substring.** Any scanned line containing it fails, comments included, and any identifier such as `SPUUpdaterTimer`. Lowercase "timer" passes.
- **Gaps in the timer rules (these pass the scan, but break `docs/architecture.md:20`):** `NSBackgroundActivityScheduler`, `Thread.sleep`, `ContinuousClock` and its `sleep(for:)`, `usleep`, `perform(_:with:afterDelay:)`, `DispatchSource` kinds other than timer. `SCNetworkReachability` also passes the scan.
- **`NWPathMonitor`.** Not a token itself, but needs `import Network`, which fails.
- **A URL literal in Swift.** Any `http` substring outside `GitHubReleases.swift` fails, so a feed address in code needs a new allowance. An Info.plist key in `project.yml` is not scanned for it.
- **`.write(to:`, `FileHandle(forWriting`, `createFile(atPath`.** Any new persisted state must use `UserDefaults`, or a rule change. `docs/architecture.md:27-30` also lists allowed writes in prose.
- **`SuddenTermination`** catches `disableSuddenTermination`/`enableSuddenTermination` in our code too. `neverDeclared` looks at `project.yml` only, not at the plists of embedded helpers.
- **Child processes, relaunch, swaps.** `Process()`, `SMAppService.*`, `/bin/rm`, `.terminate(`: these bind our Swift only. Sparkle's helpers doing the same are invisible to the scan, but `docs/architecture.md:11`, `:20`, `:27-32` state the product rules in prose, and those need rewording.
- **Stale after removal.** Deleting `GitHubReleases.swift`, `BundleInstall`'s update parts, `ApplicationsUpdater.swift` or `PrivilegedInstall.swift` does not fail a `Confined` rule: zero hits pass. Rules would stay as dead allowances, some with now-false rule strings (`:33-34`, `:110-112`, `:177-190`). `:204-214` forces the network tokens themselves to stay listed.
- **`systemUptime`.** A new clock read must go through `Uptime.now`. `Uptime.now` is internal to `LauncherPlatform`.
- **A new `@MainActor` file-scope closure as a run-loop source's perform** must avoid `perform: {`.
- **`print(`** also matches `fingerprint(`, and `dump(` any function ending that way.

## Files Read

`plans/039-auto-updates/plan.md`, `plans/039-auto-updates/development-logs.md`, `docs/architecture.md`, `docs/performance.md`, `docs/domain-model.md` (grep), `project.yml`, `Makefile`, `Scripts/test.sh` (grep), `Scripts/perf/mtidle.c`, `Scripts/perf/sampler.c`, `LauncherKit/Package.swift`, `TrackpadLauncher/TrackpadLauncherApp.swift`.

Core: `Activity`, `GestureRecognizer`, `Launcher`, `Lifecycle`, `Ports`, `Surface`, `Touch`, `Trackpad`, `TrackpadTapState`, `Update` (first 80 lines), `Updater`, `Uptime`, `WindowSwipeConfirmation`.

Platform: `BackgroundHider`, `ClickTap` (first 135 lines), `FrameStream`, `LaunchClock`, `MultitouchSupport`, `MultitouchTrackpads`, `QuitSignals`, `TouchFrameParsing`, `TrackpadClassification`, `UptimeNow`; `GitHubReleases`, `LaunchWatch` (grep).

UI: `SettingsShell`, `SettingsWindow`, `SettingsView` (lines 98-114 plus grep).

Tests: `SourcePolicyTests`, `TouchFrameParsingTests`, `LaunchWatchClockTests`, `LauncherTests` (255-281), `InMemoryAdapters` (1-136), `TouchScript` (200-229), `DeviceSessionAnswerTests` (1-50 not displayed; grep lines only), `LiftWindowTests` (first 40).

## Boundaries

- **In from the OS:** MultitouchSupport frames (frame thread); IOKit match and terminate (main queue); `didWakeNotification` and `willPowerOffNotification` (main queue); render server animation completions (main).
- **Frame thread to main:** only `deliver` (`FrameStream.swift:82`) on a recognised event, generation-guarded. Main to frame thread: only `answer` (`:79`), `run`'s `sessions` writes.
- **Frame thread to tap thread:** `TrackpadTapState` via Mutex, plus `wake()`.
- **Into `Updater` today:** `windowOpened()`, `windowClosed()` from `Launcher`; `onReplaced` set by `Lifecycle`; `isInstalling` read by `Lifecycle` and `SettingsView:107`.
- **Port rule:** framework and wire types never cross a port (`docs/architecture.md:13`); every port has a real and an in-memory adapter (`:14`). `InMemoryTrackpads.advanceClock(by:)` (`InMemoryAdapters.swift:135-136`) is the existing test form of "time passing with the pad empty and nothing arriving".
- **Core stays clock-free:** a pure idle rule in Core must take times handed in (`Uptime.swift:4`, `TrackpadTapState.swift:4-5`). Core may not import Sparkle or AppKit.

## Non-Obvious Things

- **`Deadline` reports passed on a system stop.** `animationDidStop(finished: false)` that was not cancelled counts as passed (`LaunchClock.swift:83-84`, `:91-96`, tested at `LaunchWatchClockTests.swift:78-90`). That is right for a cap ("no launch can outlive its cap") and wrong for an idle minute: a deadline used for R8 can fire early and must re-check the condition before installing.
- **The deadline's effect-lifetime rule.** The docs say a deadline "cannot outlive that effect". An install wait has no on-screen effect, and one-minute deadlines would run while nothing else of the app does. `hostPanel` would exist for the whole wait, and a shared `LaunchClock` host is closed only by the last clock.
- **`.trackpadsChanged` carries no reason.** Wake is not distinguishable from hot-plug in Core (`Ports.swift:8`). The wake observer lives in the hardware adapter, so it exists only for a resident and only as `reconcile`.
- **`run` happens for more than sleep and hot-plug.** Preference and trust pushes can run it with the window closed. Any state held in a session resets there.
- **`run` empties `sessions` before anything else**, and a stale session's events are dropped on main, so an occupied-to-empty edge can vanish silently.
- **Edge contacts are invisible past line 97.** A resting palm holds the pad occupied for R8 but not for the recognizer. `isInThumbTouch` is not an emptiness signal, and `TrackpadTapState` is not either.
- **A hover is not a contact.** Raw frames can exist with parsed `[]`. Reading "a frame came in" over-reports contact.
- **`FrameTime` and `Uptime` must not be mixed.** Frame stamps cannot be compared with anything on main. `Uptime.swift:3-4` makes this a type-level rule. The lift window deliberately reads the clock at receipt.
- **An ordinary touch reads no clock**, by stated design (`TrackpadTapState.swift:24-25`, `FrameStream.swift:30`). A stamp on every frame would be a visible regression against `docs/performance.md:21`'s headline number (CPU per frame). Flips cost two reads per touch.
- **`Launcher.window` flips before AppKit does.** Anything reading the model sees "closed" while the window may still be on screen for a turn.
- **`SettingsShell.windowShouldClose` always returns false.** There is no `windowWillClose` to hook, and the only truth is the model.
- **The Dock's Quit reaches `closeWindow` through `Lifecycle.shouldEnd`**, so it is a window close for R8, and it matters to R13.
- **A minimised settings window counts as open** by the model, for as long as it stays minimised.
- **`Updater` exists before `Launcher`.** It is built in `applicationWillFinishLaunching`; multitouch only starts in `makeResident`. `Updater` has no `Launcher` reference: the arrow goes the other way.
- **`Task.sleep` in tests is fine.** Tests are unscanned, which is why `LaunchWatchClockTests` uses it.
- **The `Timer` token is case-sensitive.** `GitHubReleases.swift:6` says "no timer" in a comment and passes only because the token is capitalised. A comment reading "Timer" would fail.

## Open Questions

1. **Empty frame on real hardware.** Not observed: nobody touched the pad during the probe. Whether the last frame after a lift is always raw `count == 0`, whether state 5 frames come first, and how many follow, are all unconfirmed. `parsed touches.isEmpty` covers each case, but it assumes some frame arrives after the last lift. If a pad ever stopped with a contact still reported, a session would stay occupied until the next `run`. A short probe with a person at the pad would settle it.
2. **Does `systemUptime` stop during sleep?** Not determinable here: this Mac has not slept since boot. General platform knowledge says it behaves like `CLOCK_UPTIME_RAW` and stops, but neither the repo nor my probe confirms it. It decides whether a pre-sleep touch counts toward the minute after wake.
3. **Does a `LaunchClock` deadline run for 60 s with the display asleep, or while the Mac is asleep?** Deadlines never ran beyond 10 s in production, and nothing in the repo tests sleep. `CAAnimation` timing across display sleep is unmeasured. R8's install is most likely exactly when the display is asleep, so a late fire is plausible: the install could wait until the display wakes, at the moment the user returns. Needs a probe with `pmset displaysleepnow`, which I did not run because it would disturb this Mac.
4. **Idle cost of a 60 s animation.** Whether a pending deadline in a never-ordered window wakes the render server or the app during the wait, against `docs/performance.md`'s zero idle wakeups, is unmeasured.
5. **App Nap.** Nothing in the repo opts out. Whether a windowless `LSUIElement` process has callbacks delayed while napped is unmeasured.
6. **One frame thread per device, or one shared?** Comments say "that device's frame callbacks" and "one frame thread" (`FrameStream.swift:21`, `MultitouchTrackpads.swift:99`), and `docs/performance.md:40` says "the MultitouchSupport frame thread". I could not determine it. A per-session value with a merged read is safe either way.
7. **Frames during screen lock, or while the session is switched out.** No observer exists and no doc covers it. Fast user switching is a non-goal, but a locked screen is an ordinary case for "idle".
8. **Does a stationary resting contact keep producing frames?** `docs/domain-model.md:192` implies frames arrive for a resting thumb on restart, but no measurement covers a contact held still for a minute. With edge-based logic this does not matter, unless a stamp approach is used.
9. **Sparkle's own timers, sudden termination calls and helper plists** are outside this angle and outside the scan. I did not read Sparkle's source.
