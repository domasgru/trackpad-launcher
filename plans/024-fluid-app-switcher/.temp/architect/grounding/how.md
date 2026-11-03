# How the swipe switcher works today, from trackpad frames to pixels

Paths are relative to the worktree root. Abbreviations: `Core/` = `LauncherKit/Sources/LauncherCore/`, `Platform/` = `LauncherKit/Sources/LauncherPlatform/`, `UI/` = `LauncherKit/Sources/LauncherUI/`, `Tests/` = `LauncherKit/Tests/LauncherCoreTests/`.

This document merges four explorer reports (state pipeline, rendering, animation infrastructure, tests and performance). Where they disagreed or left something open, I checked the code. Those points are marked **Settled**.

---

## Overview

The app switcher runs while the thumb rests in the corner and two fingers slide sideways. A private-framework callback (MultitouchSupport) delivers touch frames on its own thread. A pure `GestureRecognizer` turns those frames into swipe phases: began, moved with absolute travel, ended, cancelled. Each recognized event hops to the main actor. There, the `@MainActor @Observable` model `Launcher` keeps the switcher as a value (`Switcher`, which holds a `SwitcherSelection`). The UI never receives commands. `SwitcherPresenter` in `LauncherUI` observes `launcher.switcher` with Swift 6.2 `Observations` and drives an AppKit panel, `SwitcherPanel`. That panel is a rounded-rectangle `NSGlassEffectView(.regular)` holding a square `.clear` glass highlight under a row of bare icon `CALayer`s. Motion comes entirely from Core Animation:

- the highlight's position is set with no animation on every input event;
- the selected icon grows 1.12x through an implicit 0.12 s animation;
- past an end, a rubber band plays as an additive `CASpringAnimation`;
- closing is a 150 ms opacity fade.

The redesign replaces this render layer. One rule constrains it more than any other: **no code may run per display frame.** Timers and display links are banned by `docs/architecture.md:21` and by a source-scan test. Code may run only per trackpad input event while the switcher shows, and everything time-based must be a Core Animation animation that the render server plays and that ends on its own. Today, the model-to-UI payload already carries a continuous fractional `position`, the integer `selected` and a rubber-band `stretch`. It carries **no finger speed, no timestamps and no direction**. The app-switcher UI has **no automated tests at all**: there is no `LauncherUI` test target, so visuals are checked by hand.

---

## Key concepts

| Name | Where | What it is |
|---|---|---|
| `TouchFrame` / `FrameTime` | `Core/Touch.swift:34-58` | One MultitouchSupport frame, parsed into domain types. `time` is monotonic driver seconds. |
| `GestureRecognizer` | `Core/GestureRecognizer.swift:73` | Pure `Sendable` state machine for one trackpad. On hardware it is stepped on the frame thread inside a `Mutex`. |
| `SwipePhase` | `Core/Gesture.swift:34-45` | `.began`, `.moved(travelMM:)` (absolute travel since began, **sent only when it changed**), `.ended`, `.cancelled`. |
| `SwipeTravel` / `PointerCurve` | `Core/PointerCurve.swift:7-157` | Converts each frame's finger mm into "step-mm". `.linear` is 1:1. `.cursor` reproduces macOS pointer acceleration, so that 100 cursor points = 12 step-mm = one icon. |
| `CursorTravel` | `Platform/CursorTravel.swift:7-44` | Builds the `.cursor` travel at each slide start from the device's `HIDAccelCurves` and the user's tracking speed. |
| `Launcher` | `Core/Launcher.swift:9` | The model. `swipe(_:)` (`:291-320`) is the one place a swipe becomes state and effects. |
| `Switcher` | `Core/Switcher.swift:6-33` | One swipe's switcher: `row: [AppEntry]` (at most 10, fixed for the swipe), `selection`, `trackpad`, `selectedApp`, `selectsFrontmost`. |
| `SwitcherSelection` | `Core/SwitcherSelection.swift:6-57` | Travel-to-selection policy: `travelMM` (clamped), `selected`, `position`, `stretch`. **Shared with the window switcher.** |
| `SwitcherRowLayout` | `Core/SwitcherRowLayout.swift:7-50` | Pure geometry (icon side, gap, pitch, highlight side, padding, panel size, `centreX(at:)`, narrow-display `scale`). Lives in Core so it can be tested, but **only the UI builds one**. |
| `GestureRules` | `Core/GestureRules.swift:24-34` | `switcherMaxApps 10`, `switcherStepMM 12`, `switcherMaxStretch 0.2`, `switcherMaxOvershoot 0.25`. |
| `SwitcherPresenter` | `UI/SwitcherPresenter.swift:11-141` | Observes `launcher.switcher`. Opens, updates and dismisses the panel. Owns the 80 pt icon cache. |
| `SwitcherPanel` | `UI/SwitcherPanel.swift:7-95` | The app switcher's window: highlight glass, icon layers, `layoutRow`, `show`, `springHighlight`. |
| `OverlayPanel` | `UI/OverlayPanel.swift:17-126` | Base class of **both** switchers' windows: borderless, non-activating, click-through, `.screenSaver` level. Its content is rounded-rect `.regular` glass inside `roundedClip`. Provides `present` and `dismiss` (the 150 ms fade). |
| `LaunchTuning` / `AnimationTuner` | `Platform/LaunchTuning.swift`, `Platform/AnimationTuner.swift` | The "one value whose defaults are the shipped look" pattern, plus a DEBUG-only slider window. It covers the launch animation and the switcher's **travel** knobs only, not the switcher's visuals. |

---

## How it works

### Runtime flow at a glance

```mermaid
sequenceDiagram
    participant MT as MultitouchSupport thread
    participant DS as DeviceSession (Platform)
    participant GR as GestureRecognizer (Core)
    participant MQ as main queue
    participant L as Launcher (@Observable)
    participant P as SwitcherPresenter (UI)
    participant SP as SwitcherPanel / OverlayPanel
    participant RS as Render server

    MT->>DS: contactFrameCallback(frame)
    DS->>GR: step(frame) under Mutex
    Note over DS,GR: on beginsSlide: install CursorTravel (.cursor curve)
    GR-->>DS: Recognition(.swipe(.moved(travelMM)))  (only if travel changed)
    DS->>MQ: DispatchQueue.main.async { assumeIsolated { onEvent } }
    MQ->>L: swipe(.moved(travel))
    L->>L: selection.follow(travel); shown = .apps(open)
    L-->>MT: playFeedback(.lightTick) x crossed
    L-->>P: Observations yields (async, may coalesce)
    P->>SP: show(position, selected, animatesSize)
    P->>SP: springHighlight(from: stretch*pitch)  (if stretch changed)
    SP->>RS: CATransaction commits (frame set, implicit 0.12 s, spring)
```

### 1. Frames to swipe phases (frame thread)

`contactFrameCallback` (`Platform/FrameStream.swift:96-101`) looks up the `DeviceSession` for the device and calls `session.receive(frame)`. `DeviceSession.receive` (`FrameStream.swift:54-80`) takes the recognizer `Mutex`, applies any pending window-swipe answer, and calls `recognizer.step(frame)`.

When a recognition `beginsSlide`, the session installs `recognizer.travel = CursorTravel.travel(curves:)` (`:61-63`). Acceleration is therefore chosen once per slide, and the user's tracking speed is re-read at that moment.

Inside the recognizer:

- **Begin.** The slide's direction is decided once, with a strict `|dx| > |dy|`. This happens on the first frame where the farther-moved finger of the pair passes the 3 mm drag threshold (`beginOrSpoil`, `GestureRecognizer.swift:300-309`). The begin frame carries travel 0; the 3 mm before it do not count.
- **Each frame after that** (`:159-203`):
  - A click or a third finger emits `.cancelled`. Both fingers lifting emits `.ended`.
  - Otherwise the per-finger deltas, taken only from fingers present on both frames, are averaged and converted to mm.
  - The frame interval `frame.time - swipe.lastTime` is computed and passed to `SwipeTravel.travel(along:dxMM:dyMM:interval:)`.
  - The result is added to the running sum. **`.moved` is emitted only if the sum changed** (`:197-200`).

The `.cursor` travel (`PointerCurve.cursorMove`, `PointerCurve.swift:94-117`) converts mm to counts at 400 per inch. It computes a velocity normalised to a nominal 120 Hz report rate and applies the driver's parametric acceleration. That velocity is the **only** place finger speed exists in the system, and it is thrown away inside the function. Shipped settings: `swipeFollowsCursor = true` and `swipePointsPerStep = 100` (`Platform/LaunchTuning.swift:39-44`). So on hardware, one icon is 100 accelerated cursor points, not 12 physical mm.

### 2. The hop to the main actor

`MultitouchTrackpads.deliver` (`Platform/MultitouchTrackpads.swift:95-103`) posts one `DispatchQueue.main.async { MainActor.assumeIsolated { … } }` block per recognized event. The queue is FIFO from a single frame thread, so frame order is kept. Events from a replaced session (an older `runs` generation) are dropped. `WindowSwipeConfirmation.deliver` passes app-swipe events straight through. The payload is `TrackpadEvent.swipe(SwipeEvent(phase, trackpad))`: one absolute `Double` of travel. **There is no timestamp, velocity or delta.**

### 3. The model: `Launcher.swipe(_:)` (`Core/Launcher.swift:291-320`)

- **`.began`**
  - Ignored unless no switcher already shows and gestures are active.
  - Reads `system.runningApps()` and builds `Switcher(frontmost:running:leavingOut:trackpad:)`: the frontmost app first, then the ⌘-Tab order, minus assigned apps, capped at 10.
  - Returns nil if only the frontmost app exists. In that case nothing shows, but the recognizer still blocks clicks until the fingers lift.
- **`.moved(travel)`**
  - Calls `open.selection.follow(travel)`, then reassigns `shown = .apps(open)` **on every event**.
  - Plays one `.lightTick` per item crossed.
- **`.ended`**
  - Sets `shown = nil` first.
  - Then, unless the selection is on the frontmost app or the selected app has quit, plays the `.gesture` haptic and calls `system.bringToFront`.
  - All of this runs in one main-actor turn, so the app switch never waits for the UI. R12 is already satisfied structurally.
- **`.cancelled`, and `reconcile()`** (settings toggles, hot-plug, wake; `Launcher.swift:240-242`) both set `shown = nil`.

### 4. Selection policy: `SwitcherSelection` (`Core/SwitcherSelection.swift`)

`follow(reportedMM)` (`:23-35`):

- Turns the absolute travel into a per-event delta using a private `reportedMM`.
- Adds the delta to `travelMM`.
- If the fingers turn back from past an end, restarts travel at that end plus the delta.
- Clamps to `[-3, last + 3]` step-mm, a quarter step past each end.

The overshoot is therefore "forgotten" on the turn: the next app comes the usual 6 mm after the turn, however far the fingers went past the end.

Derived values:

- `selected = clamp(round_awayFromZero(travelMM / 12), 0, count-1)`. It changes at ±6 mm, then every 12 mm.
- `position = clamp(travelMM / 12, 0, count-1)`. **Continuous and fractional.**
- `stretch = sign(e) · 0.2 · (1 − 1/(1 + |e|/0.2))`, where `e` is the overshoot in items. It is 0 inside the list.

**Settled: the largest rubber band ever shown is about 0.111 items (about 11 pt at full size), not 0.2 items (20 pt).** The rendering explorer said "up to 20 pt". That is wrong. The overshoot clamp stops `e` at 0.25 items, and `0.2 · (1 − 1/2.25) ≈ 0.111`. `switcherMaxStretch = 0.2` is the asymptote of the curve, which is never reached, and tests only assert `< 0.2` (`Tests/SwitcherTests.swift:136-148`). Plan R10 asks for 20 pt at most, with most of it reached within 3 mm. Today's curve does not meet that.

### 5. The model-to-UI boundary and its payload

There is **no switcher UI port**. `Ports.swift` has none, and the architecture says "adapters sense and act, the shell and views render". The boundary is the single observable computed property `Launcher.switcher: Switcher?` (`Launcher.swift:13-15`), derived from the private `shown: ShownSwitcher?` (`:54-56`, `enum { apps(Switcher), windows(WindowSwitcher) }`). Show, move and hide are three transitions of that one value: nil to value, value to another value, value to nil.

| Field the UI can read | Type | Notes |
|---|---|---|
| `row` | `[AppEntry]` | Fixed for the swipe. |
| `selection.count` | `Int` | |
| `selection.travelMM` | `Double` | Clamped to −3…last+3 step-mm. Lets the UI compute its own overshoot curve (0…3 mm). |
| `selection.position` | `Double` | Continuous, clamped to `[0, count-1]`. |
| `selection.selected` | `Int` | |
| `selection.stretch` | `Double` | Signed, at most about 0.111 items. |
| `selectedApp`, `selectsFrontmost`, `trackpad` | | |

**Not available to the UI:**

- finger speed or velocity;
- frame timestamps or intervals;
- direction of motion (it could only be derived by diffing successive values);
- overshoot beyond 3 step-mm;
- the number of items one event crossed (`crossed` is used for haptics and not stored).

**How often the value changes.** Once per `.moved` event, which means once per trackpad frame in which travel changed. This holds whether or not `selected` changed. **Settled:** the `@Observable` macro in this toolchain generates `shouldNotifyObservers`, so it does skip notifications for equal values (checked in the SDK's `Observation.swiftinterface`). In practice it never skips here: `SwitcherSelection`'s synthesized `Equatable` includes the private `reportedMM`, which changes on every event, even at the clamp. When the fingers rest, the recognizer emits nothing, so the model and the presenter do no work.

**Open: coalescing.** `Observations` yields asynchronously on a later main-actor turn than the block that wrote `shown`. If several frame blocks run before the presenter's Task resumes, the presenter sees only the latest value. Nobody measured how often that happens at roughly 120 Hz input. For a redesign this means the presenter must treat each value as an absolute target, not as an increment. It already does.

### 6. Rendering (`UI/SwitcherPresenter.swift`, `UI/SwitcherPanel.swift`, `UI/OverlayPanel.swift`)

The switcher uses no SwiftUI. It is pure AppKit plus Core Animation; plan 006 rejected SwiftUI here because its springs are not Core Animation animations. The view tree:

```
SwitcherPanel : OverlayPanel : NSPanel   (borderless, nonactivating, click-through, .screenSaver, hasShadow)
  contentView = clip NSView              (roundedClip: cornerRadius 34, .continuous, masksToBounds)  <- fade animates this layer
    NSGlassEffectView(.regular, cornerRadius 34)
      .contentView = content NSView      (frame set by hand to panelSize)
        highlight: NSGlassEffectView(.clear, cornerRadius 24)   <- added first, so drawn UNDER the icons
        iconsHost NSView (layer-backed)
          CALayer × N                    (bounds iconSide², position (centreX(i), centreY), contents = CGImage)
```

The panel is created once, eagerly, in `SwitcherPresenter.init`, so that a swipe never pays the first window's cost. `SettingsShell.init` constructs the presenter (`UI/SettingsShell.swift:28`).

**`render(_:)`** (`SwitcherPresenter.swift:116-129`), per observed value:

1. If the value is nil, call `panel.dismiss()`.
2. Read Reduce Motion fresh from `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. It is not observed, and the model never sees it.
3. If the panel is not presented, or the row differs from the laid-out row, call `open(row)`. That happens once per swipe:
   - picks the screen under the pointer;
   - builds `SwitcherRowLayout(iconCount:, displayWidth: screen.frame.width)` from the full frame, not `visibleFrame`;
   - calls `panel.layoutRow(…)`, which centres the window on the display's midpoint, creates the icon layers and calls `invalidateShadow()`;
   - calls `present(appear: nil)`, so the switcher appears at once at full opacity with no grow-in. That already meets R11.
4. `panel.show(position:selected:animatesSize: !reduceMotion)` (`SwitcherPanel.swift:65-79`):
   - **Highlight follow:** in a transaction with actions disabled, it sets `highlight.frame.origin.x = centreX(at: position) − highlightSide/2`. The highlight jumps to each event's fractional position. It is never animated, so its smoothness depends entirely on the input event rate.
   - **Icon grow:** in a second transaction with `setAnimationDuration(0.12)` (actions disabled under Reduce Motion), it sets **every** icon layer's `transform`: 1.12 for `selected`, 1 for the rest. These are standalone `CALayer`s, so each set fires an implicit animation, re-launched from the current presentation value on every event.
5. If `stretch` changed, is non-zero and Reduce Motion is off, call `springHighlight(from: stretch × layout.pitch)` (`SwitcherPanel.swift:83-94`). This adds an **additive** `CASpringAnimation` on the highlight layer's `position.x` from that offset to 0, with mass 1, stiffness 420 and damping 22 (damping ratio about 0.54, underdamped). Its duration is `settlingDuration` and its key is `"stretch"`, so each new spring replaces the previous one. `initialVelocity` is never set, so the spring carries no momentum between kicks.

The rubber band is therefore **a series of re-kicked springs decaying back to the end icon, not a held offset.** If the fingers stop past the end, no events arrive and the highlight springs back while the fingers stay out. Two mechanisms move the highlight: the `NSView` frame for the follow, and an additive layer animation for the stretch. They compose only because the spring is additive.

**`dismiss()`** (`OverlayPanel.swift:94-117`):

- Under Reduce Motion, the window is ordered out at once.
- Otherwise, in a transaction with a completion block, an explicit `CABasicAnimation("opacity")` runs on the clip view's layer from its presentation value to 0, over 0.15 s ease-out. The completion calls `orderOut` only if `generation` still matches. `present` bumps `generation` and removes the `"fade"` animation, so a swipe that starts during the fade cancels the cleanup.
- `SwitcherPanel` does not override `emptied()`, so its icon layers stay attached until the next `layoutRow`.

**Glass and shadow.** There are two `NSGlassEffectView`s: the panel uses `.regular` and the highlight uses `.clear`. The highlight is nested inside the panel glass's `contentView` (glass on glass) and is not in an `NSGlassEffectContainerView`, so nothing merges or morphs today. `roundedClip` (`UI/GlassClip.swift:3-21`) exists because the glass alone leaves faint rectangle content behind its corners, and the window-server shadow (`hasShadow = true`) traced that rectangle. The shadow is recomputed only on `invalidateShadow()`, which is called after `layoutRow`.

**What the SDK offers (checked in `NSGlassEffectView.h`).** AppKit's glass API on macOS 26 is limited:

- `NSGlassEffectView` exposes `contentView`, `cornerRadius`, `tintColor` and `style`. `effectIsInteractive` arrives in macOS 27.
- `NSGlassEffectContainerView` exposes `contentView` and `spacing`.

There is no arbitrary-path glass shape in AppKit. The codebase uses no SwiftUI `.glassEffect` or `GlassEffectContainer`, and no `CAShapeLayer`, masks or filters anywhere.

**Icons.** `AppIcons(side: 80)` pre-draws 1x and 2x bitmaps off the main actor for running Dock apps, and redraws them on launch, terminate and appearance-change notifications. At open, `icon(forSwitcher:)` returns from the cache or draws on the main actor. `layoutRow` feeds `cgImage(forProposedRect: 80·backingScale)` into `CALayer.contents` with trilinear minification for shrunk rows.

### 7. Narrow displays (`Core/SwitcherRowLayout.swift:19-46`)

`scale = min(1, (displayWidth − 44) / ((n−1)·100 + 92))`. For 10 icons, the row shrinks on displays narrower than 1036 pt.

- **Scaled:** icon side, gap, pitch and highlight side.
- **Not scaled:** the 22 pt padding (`centreX(at p) = 22 + highlightSide/2 + p·pitch`) and the corner radii 34 and 24 in `SwitcherPanel`.

Travel per icon stays at 12 step-mm whatever the scale, so on a shrunk row the highlight no longer tracks the cursor 1:1. R14 needs every look dimension to scale with `layout.scale`, which today's radii do not.

### 8. Where geometry and look constants live

The app switcher's look is split across a Core type and UI literals. There is no "look" value for it. The window switcher has one (`WindowSwitcherLook`, `UI/WindowSwitcherPanel.swift:8-19`), but it is neither tunable nor `Codable`.

| Value | Where |
|---|---|
| Icon 80, gap 20, highlight 92, padding 22, selected scale 1.12, pitch | `Core/SwitcherRowLayout.swift:8-13, 36` |
| Panel and clip corner radius 34 | `UI/SwitcherPanel.swift:8` |
| Highlight corner radius 24 (not scaled; not concentric with 34 − 22) | `UI/SwitcherPanel.swift:24` |
| Icon grow 0.12 s, implicit, default timing | `UI/SwitcherPanel.swift:73` |
| Rubber-band spring 1 / 420 / 22, `settlingDuration` | `UI/SwitcherPanel.swift:89-92` |
| Fade 150 ms ease-out | `UI/OverlayPanel.swift:20` |
| Step 12 step-mm, overshoot 0.25, max stretch 0.2, 10 apps | `Core/GestureRules.swift:25-34` |
| Travel knobs (`swipeFollowsCursor`, `swipePointsPerStep` 100, `swipeTrackingSpeed` −1) | `Platform/LaunchTuning.swift:39-44` |

### 9. Tuning machinery

`LaunchTuning` (`Platform/LaunchTuning.swift`) is the established pattern:

- One `Equatable, Sendable` struct whose property defaults are the shipped values (`static let shipped = LaunchTuning()`).
- `LaunchTuning.current` returns `shipped` in Release. In DEBUG it returns the `tunerOverride` `Mutex` (`Platform/AnimationTuner.swift:9`).
- `AnimationTuner` is a DEBUG-only floating panel hosting a SwiftUI `Form` of sliders bound by `WritableKeyPath<LaunchTuning, Double>`. Every write updates `tunerOverride` and persists JSON plus named presets to `UserDefaults`.
- Shipping a tuning means copying its values into the defaults.
- `Codable` exists only under `#if DEBUG`, through a hand-written `init(from:)` that falls back to shipped values for missing keys (tested in `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`).
- Readers snapshot `current` at the start of an effect, never per frame. That is why `TunerModel.preview` can swap the override around a synchronous `play()`.

The tuner's only switcher knobs are travel ("Move like the cursor", "Points per step", "Tracking speed"). **It cannot reach switcher visuals** because of the module wall described below.

### 10. Animation machinery elsewhere (precedents a redesign can reuse)

- **Launch flight** (`Platform/LaunchFlight.swift`, `Platform/LaunchOverlay.swift`):
  - Poses are sampled at 240 Hz into `CAKeyframeAnimation`s with `calculationMode = .linear`, so easing is baked into the values, not into timing functions.
  - The model value is set to the last keyframe before the animation is added.
  - A `CATransaction` completion block closes the panel.
  - The flight is staged as a pure `LaunchStage` value, which tests read back without rendering.
- **Launch bounce** (`Platform/BounceOverlay.swift`, `Platform/BounceStaging.swift`):
  - Repeating keyframes; additive `CABasicAnimation` slides.
  - Pointer following runs per input event through NSEvent monitors.
  - Deadlines are inert 1→1 opacity animations on a clock layer whose `animationDidStop` is the push. This is the concrete form of "time passes only on Core Animation's clock" (`docs/architecture.md:21`).
  - `presentation()` reads let an in-flight animation be handed off.
- **APIs used:** `CAKeyframeAnimation`, `CABasicAnimation`, `CASpringAnimation`, `CATransaction` (disable actions, duration, completion), `isAdditive`, `fillMode` together with `isRemovedOnCompletion`, `repeatCount = .infinity`, and `presentation()`.
- **APIs absent:** `CAShapeLayer`, `CAAnimationGroup`, masks, `CAMetalLayer`, `beginTime`/`timeOffset`/`speed`, `CACurrentMediaTime`, and any SwiftUI animation.

---

## Module walls that matter to a redesign

```
LauncherCore      (Foundation + Observation only; enforced by SourcePolicyTests:222-228)
   ^        ^
   |        |
LauncherPlatform   LauncherUI  (defaultIsolation(MainActor); depends on Core ONLY)
   ^        ^
   +---- app target (composition root; imports all three)
```

1. **`LauncherUI` cannot see `LauncherPlatform`** (`LauncherKit/Package.swift:15-19`). `LaunchTuning`, `tunerOverride`, `AnimationTuner` and `CursorTravel` are all out of the switcher panel's reach. The tuner's "Simulate Reduce motion" (`forceReduceMotion`) does not affect either switcher. R17 (one tunable place) therefore needs one of these:
   - a look value in `LauncherUI`, with a tuner there;
   - a plain-number look value in `LauncherCore`;
   - injection from the app target.
2. **`LauncherCore` cannot import Core Animation or AppKit.** Shape maths can live there as numbers and paths of numbers, and is then testable. `CGPath`, layers and animations cannot.
3. **`SwitcherSelection` and `GestureRules` are shared with the window switcher** (`Core/WindowSwitcher.swift:73, 87`; `Launcher.swift:338-344`). The window switcher must keep its look (a non-goal of the plan). Any change to `follow`, `stretch`, the overshoot band or the step therefore changes the window switcher's behaviour and its tests. Data the app switcher alone needs is safer derived in the presenter, or added to `Switcher`.
4. **`OverlayPanel` imposes a rounded-rectangle `.regular` glass container plus `roundedClip`** on both switchers. R1 ("no rectangular panel") cannot be met by subclassing it unchanged without either changing the window switcher's base or giving the app switcher a different base window.
5. **Finger speed lives only inside `PointerCurve.cursorMove`,** in the Core recognizer, which runs on the frame thread. For R8 (a speed-driven wave) it has to either:
   - cross the port: `SwipePhase.moved` is shared with `.windowSwipe` events, and `SwipeEvent` has no timestamp;
   - or be estimated in the presenter from successive `travelMM` values and the presenter's own clock. That estimate is subject to `Observations` coalescing and main-queue jitter. Reading a clock is not banned by token (`CACurrentMediaTime` is not in the ban list), but it has no precedent in the code.

---

## How it is tested

The test layers all sit in `LauncherCoreTests`. **No test target depends on `LauncherUI`**, and nothing under `LauncherKit/Tests` constructs `SwitcherPresenter`, `SwitcherPanel` or `OverlayPanel`.

| Layer | Files | Drives | Observes |
|---|---|---|---|
| Pure values | `Tests/SwitcherTests.swift` (13), `Tests/SwitcherRowLayoutTests.swift` (8) | `SwitcherSelection(count:)` and `follow`; `SwitcherRowLayout(iconCount:displayWidth:)` | `selected`, `position`, `stretch` numerically; layout numbers such as 536×136 for 5 icons, `centreX(2.5) = 318`, 22 pt gaps, and the 1.12 icon fitting inside 92 pt |
| Model through ports ("World") | `Tests/SwitcherOnScreenTests.swift` (36), `SwitcherAssignedAppsTests.swift` (11), `SwipeSettingTests.swift` | Scripted `TouchFrame`s through `InMemoryTrackpads`, with a real recognizer and real tap filters | `world.launcher.switcher` fields, `hardware.lightTicks`/`pulses`, `system.broughtToFront` |
| Recognizer | `SwipeTravelAndExitTests`, `SwipeRecognizerTests`, `PointerCurveTests`; `LauncherPlatformTests/DeviceSessionTravelTests` | Frames into `step`, or the real `DeviceSession` | `SwipePhase`s and travel |

Simulation machinery:

- **`TouchScript`** (`Tests/TouchScript.swift`) builds frames 10 ms apart (100 Hz) in mm. Builders: `thumb`, `land`, `slide(byMM:over:)` (default 100 ms), `lift`, `press`, …
- **`World`** (`Tests/World.swift`):
  - `switcherWorld()` sets up Safari, Mail, Slack and Notes running, with Safari frontmost.
  - `swipe(_ slidesMM:…, lift:)` returns the script so a test can continue the same hand.
  - `play` delivers in pieces.
  - `playFrameByFrame(_:on:observing:)` records an observation after every frame. **No app-switcher test uses it yet**; it is the ready-made way to assert per-frame targets.
- **`InMemoryTrackpads`** (`Tests/InMemoryAdapters.swift:6-243`) delivers events **synchronously** and always uses `.linear` travel. The real adapter hops asynchronously and uses cursor travel. `hardware.inject(.swipe(...))` fakes a second trackpad.
- **Run with** `Scripts/test.sh`, which is `swift test` and passes arguments through. 566 tests in 59 suites, about 3 s for the run and about 11 s warm wall time. `--filter Switcher` runs 95 tests in under 2 s. There is no CI.

**Precedent for testing animation without rendering:** `LauncherPlatformTests/LaunchFlightTests.swift` and `BounceStagingTests.swift` read back `keyTimes`/`values` from staged `CAKeyframeAnimation`s. Nothing like this exists for the switcher. `SwitcherRowLayout` in Core is the existing pattern: push visual geometry into pure numbers, test those, and check the drawing by hand.

**Visual verification is manual.** Each plan writes hand sequences (for example `plans/013-simplify-switchers/plan.md:143-158`: widths measured in pixels on screenshots, plus greps of UI source as proof of absence). There are no snapshot or UI tests.

---

## How it is measured

All measurement is manual, on a Release build re-signed with Apple Development (`Scripts/perf/build.sh`). Debug builds must never be measured: they are unoptimised and open the tuner.

- **`Scripts/perf/sampler.c`** reads `proc_pid_rusage` once a second. It labels each second with trackpad frame counts from its own MultitouchSupport callback.
- **`session.sh`** runs spoken phases, including "04 app switcher swipes 30 s". Its menu-bar-window cue is stale since #28.
- **`summary.sh`** gives ms per frame.
- **Time Profiler via `xctrace`** is used for attribution only.

Switcher numbers on record (baseline 2026-10-17, `docs/performance.md:42-65`, before plan 014):

- **1.08 ms per frame (4.5% of a core)**, the most expensive scenario per frame.
- **About a quarter of that is the per-frame `SwitcherPanel.show`** (Core Animation commits and `NSView.setFrame` on the glass highlight).
- An optimisation that would skip unchanged transforms was rejected because it would change the icon-grow feel (`:78`).
- Hands off: 0 idle wakeups.

**Not measured anywhere:**

- frames drawn or committed, hitches, or frame pacing at 120 Hz;
- finger-to-pixel latency;
- WindowServer and render-server cost (including `NSGlassEffectView`);
- a "fingers resting on an open switcher" phase.

R15 and R16 therefore need new verification method, not just new code. Signposts cannot ship: `import os`, `os_log` and `Logger(` are banned. `docs/product-overview.md:7` says performance tests are not needed; acceptance has been manual measurement against a budget.

---

## Where things live

| Path | Why you would open it |
|---|---|
| `Core/GestureRecognizer.swift`, `Core/Gesture.swift` | Swipe phases, travel accumulation, emit-on-change |
| `Core/PointerCurve.swift`, `Platform/CursorTravel.swift` | Accelerated travel; the only place finger speed is computed |
| `Platform/FrameStream.swift`, `Platform/MultitouchTrackpads.swift` | Frame thread, per-slide travel install, main-queue hop |
| `Core/Launcher.swift:291-320` | Swipe to model state and effects |
| `Core/Switcher.swift`, `Core/SwitcherSelection.swift`, `Core/GestureRules.swift` | Payload and selection policy (shared with the window switcher) |
| `Core/SwitcherRowLayout.swift` | Row geometry and narrow-display scale |
| `UI/SwitcherPresenter.swift` | Observation loop, Reduce Motion, open/show/spring/dismiss decisions |
| `UI/SwitcherPanel.swift` | Highlight glass, icon layers, every hard-coded look literal |
| `UI/OverlayPanel.swift`, `UI/GlassClip.swift` | Shared window base, rounded glass, fade, shadow clip |
| `UI/WindowSwitcherPanel.swift` | `WindowSwitcherLook`: the look-value precedent; it must not change |
| `Platform/LaunchTuning.swift`, `Platform/AnimationTuner.swift` | Tuning pattern and DEBUG tuner |
| `Platform/LaunchFlight.swift`, `Platform/BounceOverlay.swift`, `Platform/BounceStaging.swift` | Core Animation precedents: keyframes, deadlines, presentation hand-off |
| `Tests/SourcePolicyTests.swift` | Token bans |
| `Tests/World.swift`, `Tests/TouchScript.swift`, `Tests/InMemoryAdapters.swift` | Swipe simulation |
| `docs/architecture.md:21`, `docs/performance.md` | Animation rule; perf method and numbers |

---

## Gotchas

1. **The no-per-frame-code rule is enforced by substring.** `SourcePolicyTests.swift:13-70` bans `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink` and `Task.sleep` anywhere in shipped sources, comments and identifiers included. A type named `WobbleTimer`, or a comment saying "no DisplayLink", fails the build. `TimelineView`, `withAnimation`, `CACurrentMediaTime` and `ContinuousClock` are not caught by any token, but per-display-frame code still violates `docs/architecture.md:21`. The sanctioned cadence is trackpad input events.
2. **"Settle when the fingers stop" (R9) has no trigger event.** Resting fingers produce no `.moved`, so the UI never learns that the fingers stopped. Whatever plays after the last event must already be a self-terminating Core Animation animation that was launched with that event. Today's re-kicked `"stretch"` spring is the existing example.
3. **Step-mm are not finger mm on hardware.** Tests and plan scenarios ("5 mm", "past 6 mm") are literal finger mm only under `.linear` travel, which every test uses. Shipped travel is 100 accelerated cursor points per icon, so "6 mm" depends on speed. Test frames run at 100 Hz; the hardware rate is assumed to be about 120 Hz, but nobody has measured it.
4. **The icon-grow animation is re-launched on every event,** because `show` re-sets every icon's transform. That is part of today's feel and roughly a quarter of the swipe CPU.
5. **On a turn back from past an end, `stretch` drops to 0 at once,** because travel restarts at the end. Today the running spring just finishes. R10's "springs back with a wobble" must be animated from the current presentation state, not from a model value.
6. **The current highlight slides as a whole with `position`.** R5 needs the trailing edge pinned and only the leading edge growing. Both inputs are already in the payload: `selected` gives the anchor, and `position − selected` gives the signed lean.
7. **`layoutRow`'s `scale` parameter is the backing scale factor,** not `layout.scale`.
8. **The panel is centred on the display's full `frame`** (menu bar area included), on the display under the pointer at swipe start, and is never re-centred mid-swipe.
9. **The window-server shadow follows window alpha** and is recomputed only on `invalidateShadow()`. A shape whose outline animates will leave a stale shadow unless the design avoids the window shadow or accepts that.
10. **Reduce Motion is read live in three UI places** (`render`, `present`, `dismiss`) and never observed. The model does not know about it.
11. **A DEBUG build launched at login plays shipped tuning,** because `tunerOverride` loads saved values only once the tuner is constructed. Adding a `LaunchTuning` field also needs a line in the hand-written `init(from:)`; without it, the field silently decodes as its default.

---

## Open questions (not settled from code)

- The real MultitouchSupport frame cadence during a swipe, and whether frames keep coming while the fingers rest. `PointerCurve.reportRate = 120` is an acceleration constant, not a measurement.
- How often `Observations` coalesces back-to-back `.moved` values, and how far `render` lags the frame block.
- Whether `NSGlassEffectView`'s backing layer always accepts layer animations without AppKit re-laying it out. The current spring assumes it does, and it ships.
- The default timing curve of the implicit 0.12 s icon grow on macOS 26.
- Whether the window shadow fades with the clip layer during dismissal, and how icons look on a 3x display (no 3x icon bitmap is drawn).
