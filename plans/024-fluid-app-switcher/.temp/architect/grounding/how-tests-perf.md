# Grounding: how the swipe switcher is tested and measured (angle: tests, verification, performance)

All paths relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/024-fluid-app-switcher`.

## Headline answers

- **No test renders a view or reads the switcher's layers.** `LauncherUI` has no test target (`LauncherKit/Package.swift:20-21`), and nothing under `LauncherKit/Tests` mentions `SwitcherPanel`, `SwitcherPresenter`, `OverlayPanel` or `LauncherUI` (grep returns nothing). Everything from `Launcher.switcher` down to pixels (`SwitcherPresenter.render`, `SwitcherPanel.show`/`springHighlight`, the `NSGlassEffectView` highlight, `OverlayPanel` fade) has **no automated test**.
- Three automated test layers cover the switcher, all in `LauncherCoreTests`:
  1. **Pure value tests**: `SwitcherSelection` / `Switcher` built directly (`SwitcherTests.swift`), and `SwitcherRowLayout` geometry numbers (`SwitcherRowLayoutTests.swift`).
  2. **Model-through-ports end-to-end ("World") tests**: the real `Launcher` + real `GestureRecognizer` + real `TapFilters`, driven by scripted `TouchFrame`s through an in-memory `TrackpadHardware` fake; they observe `world.launcher.switcher` (the @Observable model value), haptic pulses, `bringToFront` calls (`SwitcherOnScreenTests.swift`, `SwitcherAssignedAppsTests.swift`, `SwipeSettingTests.swift`).
  3. **Recognizer-level tests**: frames into `GestureRecognizer.step`, observing `SwipePhase`s (`SwipeTravelAndExitTests.swift`, `SwipeRecognizerTests.swift`, `PointerCurveTests.swift`), plus one `LauncherPlatformTests` test of the real `DeviceSession` (`DeviceSessionTravelTests.swift`).
- **A swipe is simulated with fake frames**, not direct model calls (except the pure `SwitcherSelection.follow` tests). `TouchScript` builds 10 ms-apart frames (100 Hz, not 120 Hz) in millimetres; `World.swipe(...)` / `World.play(...)` push them through `InMemoryTrackpads.touch`, which steps a real recognizer and delivers events synchronously to `Launcher` via `onEvent`. Tests can also `hardware.inject(.swipe(SwipeEvent(...)))` directly.
- **Visual output is verified by hand** (manual sequences written in each plan, screenshots measured in pixels, greps of UI source). There are no snapshot tests, no screenshot tests, no XCTest UI tests, no Xcode test target.
- **Performance is measured by hand on a Release ("perf") build**, not by tests: `Scripts/perf/build.sh` + a C `sampler` using `proc_pid_rusage` once a second, labelled with trackpad frame counts from its own MultitouchSupport callback; a spoken guided `session.sh`; Instruments Time Profiler via `xctrace` for attribution only. Nothing measures frames drawn, Core Animation commits, hitches or frame pacing. `docs/product-overview.md:7` says "We don't need performance tests".
- `swift test` (via `Scripts/test.sh`): 566 tests in 59 suites. Measured here: cold (first build in this worktree) 36.0 s wall; warm 11.35 s wall with the test run itself 3.09 s; `--filter Switcher` 1.73 s wall, 95 tests in 12 suites, 0.46 s run.

## Components Found

### Package and targets — `LauncherKit/Package.swift`
- `LauncherCore` (`:13`): no dependencies. A source-scan test enforces it imports only `Foundation` and `Observation` (`SourcePolicyTests.swift:222-228`).
- `LauncherPlatform` (`:14`): depends on `LauncherCore`.
- `LauncherUI` (`:15-19`): depends on `LauncherCore`; `swiftSettings: [.defaultIsolation(MainActor.self)]`. Holds `SwitcherPanel`, `SwitcherPresenter`, `OverlayPanel`, `GlassClip`.
- Test target `LauncherCoreTests` (`:20`): dependencies `["LauncherCore"]` only. So it may import `LauncherCore` (+ system frameworks). Actual imports seen: `Testing` (53 files), `LauncherCore` (55), `Foundation` (21), `Synchronization` (2), `@testable import LauncherCore` (2 files: `LaunchBounceTests.swift`, `PointerCurveTests.swift`). Cannot import `LauncherPlatform` or `LauncherUI`.
- Test target `LauncherPlatformTests` (`:21`): dependencies `["LauncherPlatform", "LauncherCore"]`. 25 files `@testable import LauncherPlatform`; some import `AppKit` (5), `QuartzCore` (1), `CoreGraphics` (2), `CryptoKit`, `notify`, `Synchronization`. Cannot import `LauncherUI`.
- **No test target depends on `LauncherUI`.** Adding switcher-rendering tests would need a new `LauncherUITests` target (or moving testable pieces into Core/Platform).
- `swiftLanguageModes: [.v6]`; platform `.macOS(.v26)`.
- The Xcode project (`project.yml`) has a single application target `TrackpadLauncher`; no test target, no "Performance"/"perf" configuration — only `Debug` and `Release` (`project.yml:6-11`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Base.xcconfig`). The "perf build" is the Release config re-signed with Apple Development (see below).

### Model under test
- `Switcher` — `LauncherKit/Sources/LauncherCore/Switcher.swift:6-33`: the row (fixed at swipe start), `selection: SwitcherSelection` (`package(set)`), `trackpad`, `selectedApp`, `selectsFrontmost`. `package init?(frontmost:running:leavingOut:trackpad:)` — callable from tests because tests are in the same package.
- `SwitcherSelection` — `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift:6-57`: `travelMM` (`package(set)`), `follow(_ reportedMM:) -> Int` (returns items crossed = light ticks), `selected`, `position` (items, fractional, clamped), `stretch` (signed rubber band, < `switcherMaxStretch`). **No time, velocity or history** — only absolute travel.
- `SwitcherRowLayout` — `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift:7-50`: pure geometry (80 pt icon, 20 pt gap, 92 pt highlight, 22 pt padding, `selectedIconScale` 1.12, shrink `scale` for narrow displays, `centreX(at:)`, `centreY`, `panelSize`). Lives in Core so it is testable.
- `Launcher.swipe(_:)` — `LauncherKit/Sources/LauncherCore/Launcher.swift:291-319`: `.began` builds `Switcher` from `system.runningApps()`; `.moved(travel)` calls `selection.follow`, reassigns `shown`, plays one `.lightTick` per crossed item; `.ended` brings to front with `.gesture` haptic unless on frontmost or app quit; `.cancelled` clears. `Launcher` is `@MainActor @Observable` (`:9-10`); `switcher` is a computed property over private `shown` (`:13-15`, `:54-56`).
- `SwipePhase.moved(travelMM:)` — `LauncherKit/Sources/LauncherCore/Gesture.swift:34-45`: absolute travel in step millimetres, "Sent only when it changed". No timestamp on the event (`SwipeEvent` carries phase + trackpad).

### The UI side (untested)
- `SwitcherPresenter` — `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`: observes `launcher.switcher` with `for await shown in Observations({ launcher.switcher })` (`:25-28`) and calls `render` (`:116-129`): `open` on first show/row change (`:131-140`), then `panel.show(position:selected:animatesSize:)` every update, and `panel.springHighlight(from: stretch * pitch)` when stretch changed and non-zero (`:125-127`); Reduce Motion disables size animation and spring.
- `SwitcherPanel` — `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`: `NSGlassEffectView` highlight (style `.clear`, radius 24) under an `iconsHost` with one `CALayer` per icon. `show` sets `highlight.frame.origin.x` with actions disabled, then sets each icon layer's transform with a 0.12 s implicit animation (`:65-79`). `springHighlight` adds an additive `CASpringAnimation` on `position.x` keyed `"stretch"` (stiffness 420, damping 22, `settlingDuration`) (`:83-94`).
- `OverlayPanel` — `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`: borderless non-activating click-through panel, `NSGlassEffectView` `.regular` content clipped by `roundedClip`; `present` instant (or with `OverlayAppear`), `dismiss` 150 ms opacity fade with a generation-checked completion (`:94-117`).

### Test fakes ("in-memory adapters")
- **There is no fake for a switcher UI port, because there is no switcher UI port.** The UI observes the `@Observable Launcher` directly (architecture: "adapters sense and act, the shell and views render", `Launcher.swift:3`). Tests read `world.launcher.switcher` instead of a recorded UI call. Ports are in `LauncherKit/Sources/LauncherCore/Ports.swift` (`TrackpadHardware`, `TrackpadPreferences`, `SystemActions`, …); the rule "Every port has exactly two adapters: the real one in LauncherPlatform and an in-memory one in the tests" is `docs/architecture.md:14`.
- `InMemoryTrackpads: TrackpadHardware` — `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:6-243`. "Real recognizer, real TapFilters, scripted frames, synchronous main-actor delivery" (`:3-4`). Key members:
  - `run(...)` (`:59-79`): creates one real `GestureRecognizer(..., travel: .linear)` per trackpad; counts `runCount`.
  - `touch(_ frames:on:)` (`:104-124`): per frame, models the press edge for the fake click tap, steps the recognizer, converts `recognition.event` with `TrackpadEvent(event, on:)` and delivers via `WindowSwipeConfirmation.deliver(..., to: onEvent)` **synchronously** (the real adapter hops with `DispatchQueue.main.async`).
  - `pulses: [Pulse]` with `feedback` (`.gesture`) and `lightTicks` (`.lightTick`) views (`:11-12, :40-48`); `playFeedback` just appends (`:81`).
  - `inject(_ event:)` (`:242`): delivers a `TrackpadEvent` directly (used to fake a second trackpad's swipe phases).
  - `wake()` (`:98`) fires `.trackpadsChanged` → reconcile (cancels a switcher mid-swipe).
  - `pressVerdicts`, `isBlockingClicks`, `scroll(_:)` for click/scroll blocking assertions.
- `RecordingSystemActions: SystemActions` — `InMemoryAdapters.swift:260+`: records `broughtToFront`, `launchAnimations`, `bounces`; `frontmost` and `running` are settable to stand in for the ⌘-Tab list.
- `InMemoryTrackpadPreferences` (`:245-258`): `touch()` fires `onChange` (used to prove a no-op preference notification leaves the swipe alone).
- `World` — `LauncherKit/Tests/LauncherCoreTests/World.swift:36-223`: the real `Launcher` over all in-memory adapters, a temp directory of fake `.app` bundles and a throwaway `UserDefaults` suite (removed in `deinit`). Switcher helpers (`:225-345`):
  - `switcherWorld(apps:running:frontmost:accessGranted:)` (`:252-261`): default Safari, Mail, Slack, Notes running, Safari frontmost, `launcher.start()` called.
  - `swipe(_ slidesMM: Double..., lift:on:)` (`:338-344`): thumb at (10,10) mm, two fingers land at (62,45), each slide in turn over 100 ms (positive right), lift unless `lift: false`; returns the `TouchScript` so a test can continue the same hand.
  - `play(_:on:)` (`:205-210`): delivers only frames newer than any already delivered on that trackpad (lets a test play a hand in pieces).
  - `playFrameByFrame(_:on:observing:)` (`:317-333`): delivers one frame at a time and records an observation after each — **used today only by window-switcher and tap-gate tests**, not by any app-switcher test.
  - `makeFrontmost`, `makeRunning`, `activate`, `swap(...)`, `windowSwipe(...)`.
- `TouchScript` — `LauncherKit/Tests/LauncherCoreTests/TouchScript.swift`: frames in mm on a `SurfaceSize`, `frameIntervalMS = 10` (`:46`), positions linearly interpolated between waypoints (`:24-33`); builders `thumb(atMM:)`, `land(fingers:atMM:)` (8 mm apart, `:133-143`), `slide(byMM:over:)` (default 100 ms, `:145-154`), `lift(_:)`, `press()`, `liftThumb()`, `rollThumb`, `wait`, `tap`, `thumbTap`; `frames` (`:209-224`) timestamps from 1.0 s.
- `HandFrames` — `LauncherKit/Tests/LauncherCoreTests/Fixtures.swift:113-127`: hand-built frames for interleavings `TouchScript` cannot sequence (rolling three-finger tap, whole hand lifting together).
- `Fixtures.swift:1-110`: `phases(...)`, `windowPhases(...)`, `perFrame(...)` run a fresh recognizer over frames and return `SwipePhase`s; `SwipePhase.isCloseTo` compares travel within 1e-9.

## Flow (how a simulated swipe reaches the assertions)

1. Test calls `World.switcherWorld()` → `World.init` builds `InMemoryTrackpads`, `RecordingSystemActions`, catalog over temp dirs, `SettingsStore` over a temp suite, `Launcher(...)` (`World.swift:60-97, 252-261`). `launcher.start()` calls `hardware.run(...)`, which creates the real `GestureRecognizer` with `.linear` travel (`InMemoryAdapters.swift:59-65`).
2. Test calls `world.swipe(3.5, 24, lift: false)` → builds a `TouchScript` (thumb, two fingers, slide 3.5 mm, slide 24 mm) → `play` → `hardware.touch(frames, on:)` (`World.swift:338-344, 205-210`).
3. `InMemoryTrackpads.touch` steps the recognizer per frame (`InMemoryAdapters.swift:104-124`). The recognizer emits `.slide(.swipe, .began)` after 3 mm, then `.moved(travelMM:)` each frame whose travel changed (`GestureRecognizer.swift:181-201`). Each event is delivered synchronously to `Launcher`'s `onEvent`.
4. `Launcher.swipe(_:)` (`Launcher.swift:291-319`) builds/updates `shown`, calls `hardware.playFeedback(.lightTick, ...)` per crossed item (recorded in `pulses`), and on `.ended` calls `system.bringToFront` (recorded in `broughtToFront`) and `.gesture` feedback.
5. Test asserts on `world.launcher.switcher` (`row`, `selectedApp`, `selection.selected/position/stretch/travelMM`, `selectsFrontmost`, `trackpad`), `world.hardware.lightTicks`/`feedback`/`pulses`/`pressVerdicts`/`runCount`/`scroll(...)`, `world.system.broughtToFront`/`launchAnimations`/`bounces`, `world.launcher.window`/`isWindowOpen`.
6. Nothing downstream of `Launcher.switcher` runs in tests: `SwitcherPresenter` is never constructed (it lives in `LauncherUI` and is owned by `SettingsShell`).

## What each switcher test file drives and observes

### `LauncherKit/Tests/LauncherCoreTests/SwitcherTests.swift` (13 tests, pure values)
- Drives: constructs `Switcher(...)` directly (`:17-22`) and `SwitcherSelection(count: 4)` with `travelMM` set directly (`:25-29`) or via `follow(...)` calls. No frames, no World.
- Observes: `row` contents/order (frontmost + 9 most recent = 10 max, `:31-35`; frontmost outside running at left, `:90-95`; identity by URL, `:97-101`; nil when nothing else, `:103-108`), `selected` thresholds at ±6 mm and every 12 mm (`:110-126`), `position` fractional between icons (`:128-134`), `stretch` bounded < 0.2 icon, 0 inside, rubber band forgiven on the turn (`:37-74, :136-147`).
- These are the only tests that check `position` and `stretch` numerically against travel.

### `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift` (36 tests, World, frames)
- Drives: `World.swipe(...)`, `TouchScript` continuations (`hand.slide(byMM:)`, `.lift()`, `.lift(.first)`, `.liftThumb()`, `.press()`, `land(fingers: 1, ...)` for a third finger), `HandFrames` hand-built frames, `hardware.inject(.swipe(...))` for a second trackpad, `hardware.wake()` for a reconcile, `preferences.touch()`, `setHandMode(.left)`.
- Observes: model state + effects only. Examples: half a step shows progress without changing selection or ticking (`:144-151`, asserts `0 < position < 0.5`); past the midpoint snaps and ticks once (`:153-159`); push past last icon → `position == 3`, `0 < stretch < 0.2` (`:161-175`); one 10 ms frame crossing three icons ticks three times (`:177-185`, uses `slide(byMM: (36, 0), over: .milliseconds(10))` — the only "fast finger" test); 30 running apps still 12 mm per icon (`:130-142`); left push stretch negative then the next app 7 mm after the turn (`:449-467`); row fixed for the swipe (`:471-519`); cancels by third finger / unblocked click (`:286-314`); reconcile mid-swipe removes the switcher (`:552-569`).
- Despite its name, "OnScreen" means "the switcher model is non-nil", not anything rendered.

### `LauncherKit/Tests/LauncherCoreTests/SwitcherAssignedAppsTests.swift` (11 tests, World, frames)
- Drives: `World.switcherWorld`, `launcher.setAssignment`, `world.swipe(3.5, lift: false)`, `world.swap()`.
- Observes: `switcher.row` names (assigned apps left out, freed slots go to next most recent, 10 max), `selectedApp`, `selectsFrontmost`, haptics, `broughtToFront`, click/scroll verdicts when no switcher can show (`:112-132`).

### `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift` (8 tests, pure geometry)
- Drives: `SwitcherRowLayout(iconCount:displayWidth:)`.
- Observes: numbers only — `scale`, `iconSide` 80, `iconGap` 20, `pitch` 100, `highlightSide` 92, `panelSize` 536×136 for 5 icons, `centreX(at:)` incl. fractional 2.5 → 318 (`:20-32`); 22 pt gaps on all four sides from highlight to panel edge, at full size and shrunk (10 icons on 1024 pt) (`:34-71`); `selectedIconScale == 1.12` and the selected icon fits inside the highlight (`:73-79`); non-positive display width = no constraint (`:81-84`).
- This is the existing precedent for "test the visual geometry as pure numbers in Core, verify the drawing by hand".

### Related, not switcher-specific
- `SwipeTravelAndExitTests.swift` (16 tests): recognizer-level travel semantics (mm, sign per hand mode, "sent only when it changed", exit conditions).
- `SwipeRecognizerTests.swift` (13), `SwipeSettingTests.swift` (4, World; swipe setting off/on).
- `PointerCurveTests.swift` (10): `SwipeTravel.cursor` math, intervals `1/120` and `1/30` (faster = farther, `:40`).
- `LauncherPlatformTests/DeviceSessionTravelTests.swift` (1 test): the real `DeviceSession` with `@testable import LauncherPlatform`, frames 10 ms apart; a window swipe travels as far down as a swipe travels right.
- `SourcePolicyTests.swift`: source scan (see Non-Obvious).

## Precedent for testing Core Animation output without rendering
- `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift:1-60`: the launch animation is staged as a pure `LaunchStage` (`LauncherKit/Sources/LauncherPlatform/LaunchFlight.swift:159-216`) holding `[CAKeyframeAnimation]`; tests read back `keyTimes`, `values` (`position`, `transform`, `opacity`) and sample them as `Keyframe`s — asserting the animation's numbers without any window or render. `BounceStagingTests.swift` does the same for the bounce row (`BounceMotion`, samples, opacities).
- This lives in `LauncherPlatform` (testable via `@testable import LauncherPlatform`), not in `LauncherUI`. Nothing like it exists for the switcher panel.

## How tests are run
- `Scripts/test.sh` (5 lines): `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; cd LauncherKit; exec swift test "$@"`. Arguments pass through (e.g. `--filter Switcher`).
- `docs/architecture.md:7-8`: "`swift test` runs the whole behavioural suite; `xcodebuild` is used only for the bundle." Tests use Swift Testing.
- Measured in this worktree today (2026-11-03): first run 36.03 s real (user 111.8 s — includes a build); warm rerun 11.35 s real, "Test run with 566 tests in 59 suites passed after 3.089 seconds"; `--filter Switcher` 1.73 s real, "95 tests in 12 suites passed after 0.459 seconds" (filter also matches window-switcher suites). Pure suites run in ~1-2 ms (`SwitcherTests` 0.001 s, `SwitcherRowLayoutTests` 0.002 s); the World suites take ~0.46 s (temp dirs, fake bundles, UserDefaults suites).
- No CI: no `.github` directory. `Scripts/release.sh` does not run tests.

## How performance is measured — `docs/performance.md` and `Scripts/perf/`
- **Build** (`docs/performance.md:7-8`, `Scripts/perf/build.sh`): compiles `sampler` and `mtidle` with `clang -O2`, runs `xcodegen generate`, then `xcodebuild ... -configuration Release ... CODE_SIGN_IDENTITY="Apple Development"` into `build/perf/dd/Build/Products/Release/TrackpadLauncher.app` (`build.sh:11-19`). Same optimisation and hardened runtime as the notarized release; Debug builds must never be measured ("it is unoptimised, and it opens the animation tuner"). There is no separate "Performance" configuration in `project.yml`/`Config/`.
- **sampler** (`Scripts/perf/sampler.c`): `sampler <pid> <interval_ms> <seconds> [label]`; every interval reads `proc_pid_rusage(RUSAGE_INFO_V6)` and prints TSV: frames, max fingers (from its own MultitouchSupport `MTRegisterContactFrameCallback`, `:21-40`), CPU ms and %, instructions, cycles, package idle wakeups, interrupt wakeups, phys footprint, billed energy (`:55-71`); a `#TOTAL` line adds QoS CPU split and lifetime peak footprint (`:74-84`).
- **mtidle** (`Scripts/perf/mtidle.c`): bare MultitouchSupport client with a no-op callback; the per-frame floor any touch reader pays.
- **summary.sh**: per TSV, CPU in seconds with frames > 0 divided by frames = ms/frame and share of a core; plus CPU in non-touching seconds.
- **session.sh** (`Scripts/perf/session.sh:21-32`): spoken cues (`say`), one TSV per phase, sampled at 1000 ms: 01 hands off 60 s, 02 pointer and scroll 40 s, 03 taps 40 s, **04 app switcher swipes 30 s ("about six times")**, 05 window switcher 30 s, 06 swap 20 s, 07 "menu bar window" + picker 25 s, 08 hands off 60 s. A person performs the gestures.
- **Time Profiler** (`docs/performance.md:15`): `xctrace record --template 'Time Profiler' --attach <pid> --time-limit 30s`, export the `time-profile` table, aggregate with `python3 -I Scripts/perf/profile.py` (per-thread totals, top self/inclusive frames). "Use it for attribution, never for the numbers."
- Memory: `footprint`, `vmmap --summary`, `heap` (`:16`).
- **Headline metric**: CPU per trackpad frame during ordinary pointer/scroll use (`:21`).
- **Switcher numbers on record** (baseline audit 2026-10-17, `docs/performance.md:42-65`): "App switcher swipes, about 6 in 30 s | 1362 ms (4.5%) | 1.08 ms per frame" — the highest per-frame cost of any scenario. "During swipes, about a quarter of the CPU was the switcher panels' per-frame `show` (Core Animation commits and `NSView.setFrame` on the glass highlight)" (`:65`). Hands off: 0.77 ms total in 60 s, 0 idle wakeups (`:47`).
- **Decision on record** (`:78`): "Fewer redraws in `SwitcherPanel.show`: rejected" — would save a few ms per swipe and "skipping unchanged transforms would likely change the icon-grow animation, which plan 013 keeps unchanged."
- **What is not measured anywhere**: frames rendered/committed, frame pacing, hitches, dropped frames, display refresh rate, GPU/WindowServer cost, render-server cost of `NSGlassEffectView`, latency from finger to pixel. No Core Animation / Animation Hitches / Metal System Trace instruments are in the method. The "hands off" idle check is with the switcher hidden; there is no scenario of "fingers resting on an open switcher". WindowServer's cost is not sampled (sampler watches only the app's pid).

## How visual output is verified today
- By hand, from plan-specified manual sequences. Example: `plans/013-simplify-switchers/plan.md:143` — "A test is not the right proof: what is drawn is observable only on screen, `LauncherUI` has no test target …"; manual sequence at `:153-158` (e.g. panel width "measured on a screenshot at the display's backing scale (720 px on a 2× display)"), plus greps of UI source as proof of absence (`:143, :145`). `plans/008-recent-apps-switcher/plan.md:302, :338` similarly ("judged against ⌘-Tab by eye; that is a hardware check"). `plans/010-swipe-switcher-hide-gesture-apps/development-logs.md:34`: "Left for the human: R8's manual check … and S1's hardware checks."
- Geometry that can be numbers is pushed into `LauncherCore` (`SwitcherRowLayout`, `WindowColumnLayout`) and tested there.
- Debug-only `AnimationTuner` (`LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift`, `#if DEBUG`): a floating SwiftUI panel with sliders for `LaunchTuning`; its only switcher knobs are travel ("Move like the cursor", "Points per step", "Tracking speed", `:199-208`), not visuals. Values persist in user defaults; shipping a tuning means copying values into `LaunchTuning` defaults. Shown from `TrackpadLauncherApp.swift:69-89` / `WorkspaceActions.swift:95-105`.

## Boundaries
- Input to the tested slice: `TouchFrame`s (scripted) → `InMemoryTrackpads` → `GestureRecognizer` → `TrackpadEvent.swipe(SwipeEvent)` → `Launcher.onEvent`. Or `inject` directly.
- Output of the tested slice: `Launcher.switcher: Switcher?` (observable value), `TrackpadHardware.playFeedback`, `SystemActions.bringToFront`.
- Untested boundary: `Observations({ launcher.switcher })` in `SwitcherPresenter` → `SwitcherPanel` (AppKit/Core Animation/Liquid Glass) → render server.
- Real adapter difference: `MultitouchTrackpads.run` delivers each event with `DispatchQueue.main.async` (`LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:95-103`); the fake delivers synchronously.

## Non-Obvious Things
1. **Tests use linear travel; the shipped app uses cursor-accelerated travel.** The fake builds recognizers with `travel: .linear` (`InMemoryAdapters.swift:63`). The real adapter also constructs with `.linear` (`MultitouchTrackpads.swift:92`) but `DeviceSession.receive` replaces it at each slide start with `CursorTravel.travel(curves:)` (`FrameStream.swift:61-63`), which returns `.cursor(curve, pointsPerStep: 100)` whenever `LaunchTuning.swipeFollowsCursor` is true — the shipped default (`LaunchTuning.swift:39-42`, `CursorTravel.swift:37-43`). So on hardware, travel per frame already depends on finger speed (the pointer acceleration curve uses the frame interval, `GestureRecognizer.swift:187-196`; `PointerCurveTests.swift:40` shows faster = farther). The World tests' "12 mm per icon" holds only under `.linear`.
2. **Finger speed is not available to the model or presenter.** `SwipePhase.moved(travelMM:)` carries only absolute travel (`Gesture.swift:39-40`); `SwipeEvent` has no timestamp; `SwitcherSelection` keeps no time. The recognizer knows the frame interval but consumes it in the travel curve. A speed-scaled wave needs a new datum across the port or a presenter-side clock.
3. **`.moved` is sent only when travel changed** (`GestureRecognizer.swift:197-200`). With fingers still, no event reaches `Launcher`, `shown` is not reassigned, `SwitcherPresenter.render` does not run — that is why today's switcher does no main-thread work at rest (apart from the recognizer stepping each trackpad frame and any `CASpringAnimation` still settling on the render server).
4. **Test frame rate is 100 Hz, hardware is ~120 Hz.** `TouchScript.frameIntervalMS = 10` (`TouchScript.swift:46`); `PointerCurve.reportRate = 120.0` ("The trackpad's HIDPointerReportRate", `PointerCurve.swift:36-37`). Default `slide` spans 100 ms (`TouchScript.swift:146`). No test exercises the presenter at any rate.
5. **`playFrameByFrame` exists but no app-switcher test uses it** (used in `WindowSwitchingTests`, `WindowSwipeNeedsTwoWindowsTests`, `TapGateTests`). It is the ready-made way to observe per-frame model values (e.g. a per-frame swell target) during a scripted slide.
6. **Source-scan bans constrain the redesign** (`SourcePolicyTests.swift:13-70`): substring tokens `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` (so `CADisplayLink`, `NSView.displayLink(...)`, `CAMetalDisplayLink` all fail the build); also `import os`, `os_log`, `Logger(` — so `OSSignposter`/signposts for Instruments cannot ship in sources. The scan covers `LauncherKit/Sources` and `TrackpadLauncher/` (`:156-162`), not tests or scripts. The scan is plain substring matching, so any identifier containing `Timer` fails. SwiftUI `TimelineView` is not caught by a token but violates `docs/architecture.md:21`: "Animation is Core Animation keyframes, which the render server plays … No code of ours runs per display frame, and display links are banned along with timers. Code may run per input event while the effect it serves is on screen: the switchers' highlight on trackpad frames".
7. **"Draws no new frames at rest" has no existing measurement.** The sampler sees app CPU and idle wakeups, not WindowServer/render-server frames; there is no "fingers resting on an open switcher" phase. Also, while fingers rest on the pad, MultitouchSupport likely still delivers frames (the sampler labels a second "touching" whenever frames > 0), so the app's CPU during that phase includes the recognizer even when nothing redraws.
8. **Delivery semantics differ between fake and real.** Fake: synchronous `onEvent` per frame. Real: one `DispatchQueue.main.async` per event, then the presenter's `Observations` async sequence. `Observations` (Swift 6.2) yields asynchronously and may coalesce several model changes into one render; tests cannot see that.
9. **`SwitcherOnScreenTests` is a model test**, named for the switcher being "shown" (non-nil). Likewise `SwitcherPanel.show` in perf notes is the per-frame UI cost.
10. **`docs/performance.md` warns against Debug builds** partly because Debug opens the animation tuner. The perf build is just Release with Apple Development signing; opening it stops other running copies itself.
11. `Scripts/perf/session.sh:29` still cues "Open the menu bar window", though the latest commit (#28) removed the menu bar icon in favour of a settings window — the script text is slightly stale.
12. `docs/product-overview.md:7`: "We don't need performance tests, but we should just pick the most performant technical path". Performance acceptance has historically been manual measurement against a budget (e.g. plan 014's 0.088 ms/frame budget, `docs/performance.md:74`).
13. The perf baseline's switcher figure (1.08 ms/frame, `docs/performance.md:50`) predates plan 014's tap gating; the 2026-10-18 entry re-measured only pointer/scroll, so there is no post-014 switcher number.

## Files Read
- `LauncherKit/Package.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherAssignedAppsTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/World.swift`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 1-245 in full, rest skimmed by grep)
- `LauncherKit/Tests/LauncherCoreTests/TouchScript.swift` (key parts)
- `LauncherKit/Tests/LauncherCoreTests/Fixtures.swift` (100-142, grep of rest)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwipeTravelAndExitTests.swift` (head)
- `LauncherKit/Tests/LauncherCoreTests/PointerCurveTests.swift` (40-95)
- `LauncherKit/Tests/LauncherCoreTests/SwipeSettingTests.swift` (test names)
- `LauncherKit/Tests/LauncherPlatformTests/DeviceSessionTravelTests.swift` (head)
- `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` (head)
- `LauncherKit/Tests/LauncherPlatformTests/BounceStagingTests.swift` (grep)
- `LauncherKit/Sources/LauncherCore/Ports.swift` (1-120)
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (1-60, 280-325)
- `LauncherKit/Sources/LauncherCore/Switcher.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift`
- `LauncherKit/Sources/LauncherCore/Gesture.swift` (34-45)
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (175-215)
- `LauncherKit/Sources/LauncherCore/PointerCurve.swift` (30-45, 125-160)
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`
- `LauncherKit/Sources/LauncherUI/GlassClip.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (75-130)
- `LauncherKit/Sources/LauncherPlatform/FrameStream.swift` (20-75)
- `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift`
- `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift` (1-40, 190-225)
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift` (grep)
- `docs/performance.md`
- `docs/architecture.md` (lines 7-27)
- `docs/product-overview.md` (grep)
- `Scripts/test.sh`, `Scripts/perf/build.sh`, `Scripts/perf/sampler.c`, `Scripts/perf/mtidle.c`, `Scripts/perf/session.sh`, `Scripts/perf/summary.sh`, `Scripts/perf/profile.py`
- `project.yml`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `.gitignore`
- `plans/024-fluid-app-switcher/plan.md` (160-198), `plans/024-fluid-app-switcher/development-logs.md`
- `plans/013-simplify-switchers/plan.md` (143-158), grep of 008/009/010/003/001 plans

## Open Questions
- Whether MultitouchSupport keeps delivering frames at ~120 Hz while fingers rest motionless on the pad (affects what "costs nothing at rest" can mean for app CPU). Not documented in the repo; not verified.
- Whether `@Observable` in this toolchain skips notifying when `shown` is reassigned an equal value, and how much `Observations` coalesces under 120 Hz input. Not traced; would change how often `render` runs per frame.
- Trackpad frame cadence vs display refresh (120 Hz ProMotion) phase alignment is not modelled anywhere; no tool in the repo measures finger-to-pixel latency or hitches.
- How long a full Release perf build takes was not measured (not run).
