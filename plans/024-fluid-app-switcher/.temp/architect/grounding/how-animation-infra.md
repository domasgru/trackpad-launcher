# Grounding: animation infrastructure and tuning (angle: ANIMATION INFRASTRUCTURE AND TUNING)

All paths relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/024-fluid-app-switcher/`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `LaunchTuning` (struct, internal) | `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift:6-57` | One `Equatable, Sendable` value holding every launch-flight number, the swipe-travel knobs, and a nested `Bounce`; its property defaults ARE the shipped look (`static let shipped = LaunchTuning()`, :49). |
| `LaunchTuning.Bounce` | `LaunchTuning.swift:122-168` | Nested struct of every launch-bounce number; defaults are the shipped bounce; nested `Style` enum `.jump/.inflate` (:126-131). |
| `LaunchTuning.current` | `LaunchTuning.swift:51-56` | The runtime read point: DEBUG reads `tunerOverride` (a `Mutex`), release returns `shipped`. |
| `tunerOverride` | `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift:9` | DEBUG-only global `Mutex(LaunchTuning.shipped)`; the tuner writes it, `LaunchTuning.current` reads it. |
| `AnimationTuner` | `AnimationTuner.swift:14-39` | DEBUG-only floating `NSPanel` ("Launch animation & bounce tuner", 420x760, `.floating` level) hosting SwiftUI `TunerView` via `NSHostingView`. |
| `TunerPanel` | `AnimationTuner.swift:43-62` | `NSPanel` subclass that can become key and activates the app on left-mouse-down so the preset name field gets typing. |
| `TunerModel` | `AnimationTuner.swift:70-156` | `@MainActor @Observable`; holds `tuning`, presets, selection; every write to `tuning` updates `tunerOverride` and persists JSON to UserDefaults. |
| `TuningPreset` | `AnimationTuner.swift:64-68` | `Codable` `{name, tuning}` preset. |
| `TunerView` | `AnimationTuner.swift:158-345` | SwiftUI `Form` of sliders (`knob(...)` helper, :315-344) bound by `WritableKeyPath<LaunchTuning, Double>`. |
| `LaunchTuning: Codable` (DEBUG only) | `LaunchTuning.swift:59-120` | Hand-written `init(from:)` that falls back to shipped value for any missing key (forward-compatible saves). Encoding is synthesized. |
| `KeyedDecodingContainer.decode(_:or:)` | `LaunchTuning.swift:60-64` | DEBUG-only helper: `decodeIfPresent ?? fallback`. |
| `LaunchOverlay` | `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift:10-149` | Plays one launch flight per call in its own throwaway borderless panel with one `CALayer` icon driven by `CAKeyframeAnimation`s; closes the panel in the `CATransaction` completion block. Also owns the icon bitmap cache and `makePanel(frame:)` (shared by `BounceOverlay`). |
| `LaunchFlights` / `LaunchFlight` / `LaunchStage` | `LauncherKit/Sources/LauncherPlatform/LaunchFlight.swift:40-217` | Pure-ish staging: samples a pose curve at 240 Hz into `CAKeyframeAnimation`s on `position`, `transform`, `opacity` (linear calculation mode, easing baked into samples). |
| `LaunchDisplay`, `ScreenRead` | `LaunchFlight.swift:6-36` | Display frame+scale value; pointer+displays snapshot (`NSEvent.mouseLocation`, `NSScreen.screens`). |
| `BounceOverlay` | `LauncherKit/Sources/LauncherPlatform/BounceOverlay.swift:10-366` | Launch-bounce row above pointer: one display-sized panel; per-bounce `slot`/`icon`/`clock` layers; deadlines are 1→1 opacity `CABasicAnimation`s on the clock layer. |
| `BounceOverlay.Deadline` | `BounceOverlay.swift:358-365` | `NSObject, CAAnimationDelegate`; `animationDidStop` calls `passed()` unless `isCancelled` (any stop, finished or not). |
| `BounceRow` | `LauncherKit/Sources/LauncherPlatform/BounceStaging.swift:7-42` | Row rest positions (pixel-snapped) and `slide(from:to:)`: additive `CABasicAnimation` on `position`, ease-out. |
| `BounceMotion` | `BounceStaging.swift:46-134` | Builds the bounce's `CAKeyframeAnimation` (jump on `transform`, repeat forever; or inflate scale once with `fillMode .forwards`, `isRemovedOnCompletion = false`; or Reduce-Motion opacity pulse) and `quietFade` `CABasicAnimation`. |
| `InflateCurve` | `BounceStaging.swift:139-172` | Private analytic curve; τ solved by 80-step bisection. |
| `OverlayPanel` | `LauncherKit/Sources/LauncherUI/OverlayPanel.swift:17-126` | Base class of BOTH switchers' windows: borderless, non-activating, screen-saver level, `NSGlassEffectView(.regular)` content clipped by `roundedClip`; `present(appear:)` and `dismiss()` (150 ms fade, completion-block cleanup with generation guard). |
| `OverlayAppear` | `OverlayPanel.swift:6-11` | Appear params: fade duration, optional spring-from-scale, stiffness, damping. |
| `roundedClip` | `LauncherKit/Sources/LauncherUI/GlassClip.swift:6-21` | Wraps the glass in a `masksToBounds`, continuous-corner layer so the window shadow follows the rounded edge. |
| `SwitcherPanel` | `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift:7-95` | App switcher window: icon `CALayer`s in `iconsHost`, a `NSGlassEffectView` highlight (`.clear`, cornerRadius 24) under them; `show(...)` per frame; `springHighlight(from:)` additive `CASpringAnimation` on `position.x` with HARD-CODED stiffness 420 / damping 22. |
| `SwitcherPresenter` | `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift:11-141` | Observes `launcher.switcher` via `Observations`, calls `panel.show` each change, fires `springHighlight` when stretch changes; reads Reduce Motion per render. |
| `WindowSwitcherLook` | `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift:8-19` | The window switcher's "one value whose defaults are the shipped look, as `LaunchTuning` is for the launch animation" (radii, tint, fades, appear 0.1 s / 0.96 scale, spring 420/22). NOT tunable by the tuner, not Codable. |
| `WindowSwitcherPanel` / `WindowRowView` | `WindowSwitcherPanel.swift:23-248` | Window switcher: glass highlight moved by frame per frame, `springHighlight(fromY:)` on `position.y` using `look.springStiffness/Damping`; implicit-action fades via `CATransaction.setAnimationDuration` and one `NSAnimationContext`/`animator()` fade. |
| `SwitcherRowLayout` (core) | `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift` | `fullIconSide 80`, `fullIconGap 20`, `fullHighlightSide 92`, `padding 22`, `selectedIconScale 1.12` (:8-13); `pitch` (:36), `centreX(at:)` (:44). |
| `SwitcherSelection.stretch` (core) | `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift:49-51` | Rubber-band overshoot past the list ends: `sign(excess) × max × (1 − 1/(1+|excess|/max))`. |
| `CursorTravel.travel(curves:)` | `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift:37-43` | Only non-animation runtime reader of `LaunchTuning.current`: swipe-travel knobs, read at the start of each slide. |
| `SwipeTravel` (core) | `LauncherKit/Sources/LauncherCore/PointerCurve.swift:135-157` (file lines) | `.linear` or `.cursor(curve, pointsPerStep:)`; `shippedPointsPerStep = 100` (the switcher's icon pitch). |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Source-text scanner banning tokens / confining tokens to files. |
| `BounceDeadlineTests` | `LauncherKit/Tests/LauncherPlatformTests/LaunchWatchLookTests.swift:18-30` | Tests the Deadline stop rule directly. |
| `TunerCodingTests` | `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift` | Tests the tolerant Codable decoding of `LaunchTuning` / presets. |

## Flow

### A. How a Core Animation effect is built and handed to the render server (launch flight)

1. `WorkspaceActions.playLaunchAnimation(for:)` (`WorkspaceActions.swift:91-93`) → `LaunchOverlay.play(for:)` (`LaunchOverlay.swift:34-37`) reads `ScreenRead.now()` → `play(for:from:among:size:)` (:42).
2. Reduce Motion read at play time: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || LaunchTuning.current.forceReduceMotion` (:43-44).
3. `flights.next(draw: .random(in: -1...1), reduceMotion:)` (`LaunchFlight.swift:64-71`) returns `.fadeInPlace` under Reduce Motion, else `.sway(signed size)`; `.sized(size)` (:94-98).
4. `flight.staged(at:among:)` (`LaunchFlight.swift:159-172`): samples `poses` at `steps = max(10, round(duration × 240))` (:104, :153-155) using `unsizedPose(at:)` (:126-151), which reads `LaunchTuning.current` for every number; computes union of rotated bounds → panel frame clipped to the display; builds `animations` (:181-204): three `CAKeyframeAnimation`s (`position`, `transform` = rotation×scale, `opacity`), `keyTimes` evenly spaced, `calculationMode = .linear`, `duration = LaunchTuning.current.duration`. Easing is baked into the sampled values, not into timing functions.
5. Back in `play`: `LaunchOverlay.makePanel(frame:)` (:129-148) builds a borderless non-activating click-through `.screenSaver`-level panel whose content `NSView` is layer-backed (non-flipped, y-up) and returns `(panel, host layer)`. `panel.orderFrontRegardless()` (:50).
6. One explicit transaction (:52-74): `CATransaction.begin()`, `setDisableActions(true)`, `setCompletionBlock { MainActor.assumeIsolated { panel.close(); self?.playingPanels.remove(panel) } }`, a fresh `CALayer` (bounds/position/contents/contentsScale/trilinear minification/edge AA), for each keyframe animation: model value set to `animation.values?.last` ("so nothing flashes once the animation is removed", :69-70) then `icon.add(animation, forKey: keyPath)`; `host.addSublayer(icon)`; `CATransaction.commit()`.
7. The render server plays it; the completion block (fires when all animations added in that transaction finish) closes the panel and drops it from `playingPanels` (a `Set<NSPanel>` because "AppKit keeps closed panels in its window list", :14-15). No code of ours runs during the animation (doc comment :7-9).

Pre-warming: `LaunchOverlay.init` creates and closes a 1x1 panel to pay the ~27 ms first-window cost up front (:17-21). Icons rendered off-main via `@concurrent` + `DispatchQueue.concurrentPerform` (:88-95) at the pop's peak side (and inflate creep) in pixels (:103-107).

### B. Launch bounce (repeating animation, deadlines on layers, presentation reads)

1. `WorkspaceActions.bringToFrontBouncing` (`WorkspaceActions.swift:44-53`) → `bounces.start(app, cap:ranOut:)`; `LaunchWatch` gets `wait` = `bounces.after(wait, in: id, passed)` (:48), so the watch's 50 ms re-looks (`LaunchWatch.swift:15-16, 98`) are scheduled as bounce deadlines.
2. `BounceOverlay.start` (`BounceOverlay.swift:51-95`): snapshots `LaunchTuning.current` into the `Bouncing` (so a tuner preview's override restore does not affect it, :32-33), reads Reduce Motion (:54), computes `BounceRow` layout, gets/creates row panel via `stage(on:)` (:279-294, reuses `LaunchOverlay.makePanel`). Inside `CATransaction.begin()/setDisableActions(true)/commit()`: creates `slot` (positioned), `icon` (anchor bottom-centre, :266-275), adds `BounceMotion.animations()` keyed by keyPath (:75-79) WITHOUT setting model values (the jump repeats forever; inflate uses `fillMode .forwards` + `isRemovedOnCompletion = false`, `BounceStaging.swift:120-121`), adds a zero-size `clock` layer, appends the cap deadline (:88), `settle(...)` siblings with additive slide (:298-310).
3. Deadline = `deadline(on:after:passed:)` (`BounceOverlay.swift:341-353`): `CABasicAnimation(keyPath: "opacity")`, `fromValue 1`, `toValue 1` (visually inert), `duration = Duration.seconds`, `delegate = Deadline` object, keyed `"deadline-\(n)"` on the clock layer. When the animation stops, `Deadline.animationDidStop` (:362-364) runs `passed()` unless cancelled. `finished == false` (system-caused stop) still counts as passed "so no bounce can outlive its cap" (:355-357). Cancel = set `isCancelled = true` before removing the slot ("removing an animated layer stops its deadlines at the next commit", :121-122). This is the concrete form of docs/architecture.md:20 "Time passes only on Core Animation's clock".
4. `limit(_:to:)` (:97-105) and `after(_:in:_:)` (:109-116) append more deadlines on the same clock layer.
5. `end(_:with:)` (:118-162): cancels deadlines, reads `slot.presentation()` / `icon.presentation()` (:127-128) to get the in-flight transform/opacity/position, then either hands off to `launchOverlay.play(... size:)` (the flight continues from the inflated size, :139-144) or `fade(...)` a frozen copy in its own panel with `quietFade` and a `CATransaction` completion block closing the panel (:312-338). Removes slot, re-settles remaining row, closes the row panel when empty.
6. Pointer following: `follow()` installs `NSEvent` global+local monitors for moves/drags only while the row is non-empty (:198-209); `moved()` (:217-251) repositions slots; with `trailing > 0` adds a `CABasicAnimation("position")` keyed `"trail"` from presentation position, ease-out. This is code per input event, not per display frame.

### C. App switcher (what the liquid redesign will replace) — animation-relevant parts only

1. `SwitcherPresenter.init` observes `launcher.switcher` via `for await shown in Observations({ launcher.switcher })` (`SwitcherPresenter.swift:25-28`) → `render(_:)` (:116-129) on every model change (i.e. per trackpad frame that changes the selection while swiping).
2. `render`: `nil` → `panel.dismiss()` (OverlayPanel 150 ms fade). Otherwise reads Reduce Motion (:121), lays out on first show (`open`, :131-140, `present(appear: nil)` — the app switcher has NO appear animation), then `panel.show(position:selected:animatesSize: !reduceMotion)` (:124) and, if `selection.stretch` changed and non-zero and not Reduce Motion, `panel.springHighlight(from: stretch × layout.pitch)` (:125-127).
3. `SwitcherPanel.show` (`SwitcherPanel.swift:65-79`): transaction 1 with actions disabled sets `highlight.frame.origin.x = layout.centreX(at: position) − highlightSide/2` (highlight follows the continuous `position` exactly, no animation). Transaction 2 with `setDisableActions(!animatesSize)` and `setAnimationDuration(0.12)` sets each icon layer's `transform` to scale 1.12 (selected) or 1 → this is an IMPLICIT action animation (standalone `CALayer`s in a layer-hosting `iconsHost.layer`, so default actions run) of 0.12 s, hard-coded.
4. `SwitcherPanel.springHighlight(from:)` (:83-94): `CASpringAnimation(keyPath: "position.x")`, `isAdditive = true`, `fromValue = offset`, `toValue = 0`, mass 1, stiffness 420, damping 22, `duration = settlingDuration`, `forKey: "stretch"` (replaces the previous one). Applied to `highlight.layer` (the `NSGlassEffectView`'s backing layer).
5. Window switcher mirrors this: `WindowSwitcherPresenter.render` (`WindowSwitcherPresenter.swift:38-54`), `WindowSwitcherPanel.show` (:98-104), `springHighlight(fromY:)` on `position.y` with `look.springStiffness/Damping` (:108-120), and an appear via `OverlayAppear` from `WindowSwitcherLook` (:72-77).

### D. OverlayPanel present/dismiss (shared by both switchers)

- `present(appear:)` (`OverlayPanel.swift:52-80`): bumps `generation`, removes `"fade"` and `"appearScale"` animations in a no-actions transaction, sets opacity 1; if `appear` and not Reduce Motion: `CABasicAnimation("opacity")` 0→1 ease-out, and optional `CASpringAnimation("transform")` from a top-left-anchored scale (`transform(_:scaledBy:)`, :83-90) to identity, `duration = settlingDuration`. Then `orderFrontRegardless()`.
- `dismiss()` (:94-117): Reduce Motion → `removeNow()` immediately. Else opacity fade from `presentation()?.opacity` to 0 over 0.15 s ease-out with model opacity set to 0, inside a transaction whose completion block calls `removeNow()` (`orderOut` + `emptied()` hook) only if `generation` still matches (a re-present during the fade cancels the cleanup).

### E. Tuning: defaults → runtime → tuner

1. Defaults: property initialisers of `LaunchTuning` (`LaunchTuning.swift:7-47`) and `LaunchTuning.Bounce` (:133-167). `static let shipped = LaunchTuning()` (:49). Shipping a tuning = "copy its values into `LaunchTuning`'s defaults" (`AnimationTuner.swift:11-13`).
2. Runtime read: `LaunchTuning.current` (:51-56). Release: `{ shipped }`. DEBUG: `tunerOverride.withLock { $0 }`. Readers: `LaunchFlight` static vars and `unsizedPose` (`LaunchFlight.swift:101-110, 127`), `LaunchOverlay.play` and `pixels(at:)` (`LaunchOverlay.swift:44, 104`), `BounceOverlay.start` (`BounceOverlay.swift:53`), `CursorTravel.travel` (`CursorTravel.swift:38`). Reads happen at the start of each effect (not per frame of the animation).
3. Tuner creation: `AppDelegate.makeResident` stores `WorkspaceActions` under `#if DEBUG` and calls `showAnimationTuner()` (`TrackpadLauncher/TrackpadLauncherApp.swift:69-72`); opens only for an opening `.byHand`, never at a login start (:76-91). `WorkspaceActions.showAnimationTuner()` (`WorkspaceActions.swift:95-111`, public, DEBUG-only) builds `AnimationTuner(preview: { overlay.play(for: finder) }, previewBounce: { isOn in isOn ? bounces.preview(finder) : bounces.stopPreview(finder) })`.
4. `TunerModel.init` (`AnimationTuner.swift:93-98`) loads `AnimationTuner.current` JSON from `UserDefaults.standard` (or `.shipped`), presets from `AnimationTuner.presets`, selection from `AnimationTuner.selected`, and writes `tunerOverride`. NOTE: until the tuner is constructed, `tunerOverride` holds `.shipped` even in DEBUG (it is initialised `Mutex(LaunchTuning.shipped)`, :9), so a DEBUG build launched at login plays shipped values, not the saved tuning.
5. Every slider write → `tuning.didSet` (:75-80) → `tunerOverride` and UserDefaults. Knob binding rounds to `step` (:319-321); each knob shows a reset-to-shipped button disabled when equal to shipped (:322-339).
6. `TunerModel.preview(_:play:)` (:101-105) temporarily swaps `tunerOverride` to a preset, calls `play()`, then restores — works because `LaunchOverlay.play` reads `LaunchTuning.current` synchronously while building keyframes; `BounceOverlay` snapshots the tuning into `Bouncing` for the same reason (`BounceOverlay.swift:32-33`).
7. Live bounce preview: `.onChange(of: model.tuning) { if isPreviewingBounce { previewBounce(true) } }` (`AnimationTuner.swift:263`) restarts the bounce in place (`BounceOverlay.preview`, `BounceOverlay.swift:167-182`, cap 24 h).
8. Tuner UI sections: Size & timing, Pop, Rise, Shrink, Fade, Sway, Tilt, Simulate Reduce motion toggle, "Switcher swipe" (`swipeFollowsCursor`, `swipePointsPerStep` 20…300, `swipeTrackingSpeed` −1…3 step 0.0625), Launch bounce (style picker + per-style knobs), Presets (`AnimationTuner.swift:165-313`).

## Files Read

- `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift`
- `LauncherKit/Sources/LauncherPlatform/BounceOverlay.swift`
- `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchFlight.swift`
- `LauncherKit/Sources/LauncherPlatform/BounceStaging.swift`
- `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift`
- `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift`
- `LauncherKit/Sources/LauncherCore/PointerCurve.swift` (lines 120-175)
- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`
- `LauncherKit/Sources/LauncherUI/GlassClip.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift` (lines 1-100)
- `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Package.swift`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `docs/architecture.md` (grep: lines 12, 20, 21, 22)
- `docs/performance.md` (grep: lines 8, 50, 65, 78)
- grep-only: `SwitcherRowLayout.swift`, `SwitcherSelection.swift`, `LaunchWatch.swift`, `LaunchWatchLookTests.swift`, `BounceStagingTests.swift`, `LaunchFlightTests.swift`

## Boundaries

- Module graph (`LauncherKit/Package.swift`): `LauncherCore` (no deps); `LauncherPlatform` → `LauncherCore`; `LauncherUI` → `LauncherCore` ONLY, with `swiftSettings: [.defaultIsolation(MainActor.self)]`. `LauncherUI` does NOT depend on `LauncherPlatform`. Therefore `LaunchTuning`, `tunerOverride` and `AnimationTuner` (all internal to `LauncherPlatform`) are unreachable from `SwitcherPanel`/`SwitcherPresenter`. The app target imports all three (`TrackpadLauncherApp.swift:1-4`).
- `LauncherCore` may import only Foundation and Observation (`SourcePolicyTests.swift:222-228`; architecture.md:12). No Core Animation types in core; core exports numbers (`SwitcherSelection.position/selected/stretch`, `SwitcherRowLayout` geometry).
- Inputs to the animation layer: model values observed via `Observations` (switchers), `SystemActions` port calls (`playLaunchAnimation`, `bringToFrontBouncing`, `limitLaunchBounce`, `endLaunchBounce`), `ScreenRead.now()` (pointer, screens), Reduce Motion (`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`), `LaunchTuning.current`.
- Outputs: layers/animations committed to the render server; completion callbacks (`CATransaction.setCompletionBlock`, `CAAnimationDelegate.animationDidStop`) are the only way time-based work returns to our code; `Deadline.passed` → `BounceOverlay.runOut` → `WorkspaceActions.report(.ranOut)` → `onLaunchProgress`.
- The per-frame input cadence for the switcher is the trackpad frame stream → `Launcher` model → `Observations` → `render`. There is no display-frame callback anywhere.

## Reduce Motion: every read site

| Site | Behaviour |
|---|---|
| `LaunchOverlay.swift:43-44` | `|| LaunchTuning.current.forceReduceMotion`; flight becomes `.fadeInPlace` (opacity only, no move/scale/tilt; `LaunchFlight.swift:65, 129-130`) and does not count toward sway streak. |
| `BounceOverlay.swift:54` | `|| tuning.forceReduceMotion`; stored per bounce; `BounceMotion` uses opacity pulse between `pulseLow` and 1 with period `pulsePeriod` (`BounceStaging.swift:82-100`). |
| `OverlayPanel.swift:62` | No appear animation under Reduce Motion. |
| `OverlayPanel.swift:98` | Dismiss is immediate (no 150 ms fade). |
| `SwitcherPresenter.swift:121-127` | No 0.12 s icon-size implicit animation (`animatesSize: false`), no rubber-band spring. Highlight still tracks position. |
| `WindowSwitcherPresenter.swift:35, 50, 73, 93, 97` | No spring, no appear, preview fades instant. |

The switchers do NOT honour `LaunchTuning.forceReduceMotion` (they cannot see it — module boundary); only the launch flight and bounce do. Reduce Motion is read fresh at each effect start / each render; nothing observes changes to it.

## Timing APIs actually present (exhaustive grep over `LauncherKit/Sources` and `TrackpadLauncher`)

- Used: `CAKeyframeAnimation` (LaunchFlight, BounceMotion), `CABasicAnimation` (deadlines, slide, trail, quiet fade, overlay fades), `CASpringAnimation` (SwitcherPanel.springHighlight, WindowSwitcherPanel.springHighlight, OverlayPanel appear scale), `CATransaction` begin/commit/`setDisableActions`/`setAnimationDuration`/`setCompletionBlock`, `CAMediaTimingFunction(name: .easeOut)`, `presentation()` reads, `isAdditive`, `fillMode`/`isRemovedOnCompletion`, `repeatCount = .infinity`, one `NSAnimationContext.runAnimationGroup` + `animator().alphaValue` (`WindowSwitcherPanel.swift:199-202`).
- Layer types: only plain `CALayer` plus AppKit view-backing layers and `NSGlassEffectView` (`SwitcherPanel.swift:11`, `WindowSwitcherPanel.swift:26`, `OverlayPanel.swift:40`). No `CAShapeLayer`, `CAGradientLayer`, `CAMetalLayer`, `CAReplicatorLayer`, `CAAnimationGroup`, masks or filters anywhere.
- NOT present anywhere in sources: `CADisplayLink`, `CVDisplayLink`, `NSView.displayLink`, `Timer`, `DispatchSourceTimer`/`makeTimerSource`, `asyncAfter`, `Task.sleep`, any `Clock`/`sleep`, `CACurrentMediaTime`, `beginTime`/`timeOffset`/`speed`, SwiftUI `TimelineView`, `withAnimation`, `.animation(`, `PhaseAnimator`, `KeyframeAnimator`, `matchedGeometryEffect`, `.glassEffect` / `GlassEffectContainer`. (The only SwiftUI in Platform is the DEBUG tuner form; the settings window is SwiftUI in LauncherUI but uses none of these.)

## Source-policy test: exact bans (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`)

Scanner: plain `String.contains(token)` per line, case-sensitive, comments and strings included, over every `.swift` file under `LauncherKit/Sources` and `TrackpadLauncher/` (:153-162, :265-272). Tests are not scanned.

`banned` (:13-70) — NO file exceptions at all (there is no allow-list for `banned`; `scan` is called with default `outside: []`, :166):
- log: `print(`, `debugPrint(`, `dump(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os`
- network: `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`
- own files: `FileHandle(forWriting`, `.write(to:`, `createFile(atPath`
- timer: `Timer` (covers `Timer`, `DispatchSourceTimer`, `NSTimer`, any identifier containing `Timer`), `asyncAfter`, `makeTimerSource`, `displayLink` (covers `NSView.displayLink(target:selector:)`, `NSScreen.displayLink`), `DisplayLink` (covers `CADisplayLink`, `CVDisplayLink*`)
- polling: `Task.sleep`
- input monitoring / posting: `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `IOHIDRequestAccess`, `IOHIDCheckAccess`, `CGRequestPostEventAccess`, `CGPreflightPostEventAccess`
- R9 no keyboard: `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged`
- `ScrollWheel` (scrolling read only by the click tap)
- R9 never synthesise: `.post(tap:`, `CGEventPost`, `postToPid`
- `nonisolated(unsafe)` (one writer per field)
- `perform: {` (run-loop source perform must be a file-scope constant)
- window switcher only raises: `AXUIElementSetAttributeValue`, `kAXPressAction`
- previews: `SCStream(`, `SCRecordingOutput`, `CGImageDestination`, `representation(using`, `tiffRepresentation`
- no menu bar icon: `NSStatusBar`, `NSStatusItem`
- nothing relaunches: `SMAppService.agent`, `SMAppService.daemon`, `SMAppService.loginItem`, `SMLoginItemSetEnabled`

NOT banned by token: `TimelineView`, `withAnimation`, `.animation(`, `CASpringAnimation`, `CAKeyframeAnimation`, `ContinuousClock`, `Clock.sleep(for:)`/`try await clock.sleep` (only the literal `Task.sleep` is caught), `CACurrentMediaTime`, `Metal`, `CAShapeLayer`, `CAMediaTimingFunction`. A SwiftUI `TimelineView(.animation)` would not be caught by the scanner but contradicts architecture.md:21 ("No code of ours runs per display frame, and display links are banned along with timers"). Writing the word "Timer" or "DisplayLink" even in a comment fails the test.

`confined` (:81-150), animation/pointer-relevant entries:
- `mouseMoved` only in `BounceOverlay.swift`, `ClickTap.swift` (:93-95)
- `addGlobalMonitorForEvents`, `addLocalMonitorForEvents` only in `BounceOverlay.swift` (:96-101) — "pointer moves are read only while a launch bounce shows"
- `scrollWheel` only in `ClickTap.swift` (:102)
- Others: `AXIsProcessTrusted`/`notify_register`/`ScreenCaptureAccess` → `SystemPermissions.swift`; `ScreenCaptureKit`/`SCShareableContent`/`SCScreenshotManager` → `PreviewCapture.swift`; `tapCreate`/`CGEventTapCreate`/`tapEnable`/`tapIsEnabled` → `ClickTap.swift`; `_LSCopyApplicationArrayInFrontToBackOrder`/`_LSCopyApplicationInformation` → `LaunchServicesOrder.swift`; `AXUIElement`/`CGWindowList` → `FrontmostAppWindows.swift`, `LaunchWatch.swift`; `SecCode`/`SecStaticCode`/`SecRequirement` → `CodeSignature.swift`; `/bin/mv`, `/bin/rm`, `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` → `PrivilegedInstall.swift`; `SMAppService` → `SystemLoginItem.swift`; `setActivationPolicy` → `SettingsShell.swift`; `disableRelaunchOnLogin` → `TrackpadLauncherApp.swift`; `keyAELaunchedAsLogInItem`, `SecTranslocate` → `ThisCopy.swift`; `currentAppleEvent` → `ThisCopy.swift`, `TrackpadLauncherApp.swift`; `forceTerminate`, `.terminate(` → `SystemRunningCopies.swift`; `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `quarantinePropertiesKey` → `BundleInstall.swift`; `statfs`, `DADisk`, `unmountVolume` → `DiskImages.swift`; `runModal` → `MoveDialogPresenter.swift`; `kAEQuitReason` → `QuitSignals.swift`.

Other tests in the file: planted-hit self-tests (:176-212), `scanVisitsEveryLibraryTarget` (:214-220) asserts LauncherCore, LauncherPlatform, LauncherUI and the app target are all scanned; `coreImportsOnlyFoundationAndObservation` (:224-228).

## TunerCodingTests (`LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift`)

- `@testable import LauncherPlatform` (test runs in DEBUG, so `Codable` conformance exists).
- Test 1 (:31-48): verbatim JSON of two presets saved before the bounce existed decodes with the 14 flight numbers intact, `forceReduceMotion == false`, and `bounce == LaunchTuning.Bounce()` (shipped) — proves missing-key fallback.
- Test 2 (:50-60): every bounce knob round-trips encode/decode (uses memberwise `Bounce(height:...pulsePeriod:)` init, i.e. the Bounce memberwise init is positional/labelled by declaration order of the listed props; style/inflate/creep omitted → defaults).
- Test 3 (:62-71): partial `{"bounce":{"height":55,"gap":3}}` keeps shipped values for the rest.
- Not tested: swipe knobs' decoding (`swipeFollowsCursor` etc.), though the decoder handles them (`LaunchTuning.swift:87-89`).

## Non-Obvious Things

1. `LaunchTuning` is named for the launch animation but already carries non-launch knobs: switcher swipe acceleration (`swipeFollowsCursor`, `swipePointsPerStep`, `swipeTrackingSpeed`, `LaunchTuning.swift:39-44`); the doc comment (:4) admits this. Yet the switcher's VISUAL motion (spring 420/22, 0.12 s icon grow, 1.12 selected scale, highlight radius 24, panel radius 34) is not in `LaunchTuning`; it is hard-coded in `SwitcherPanel.swift:8, 24, 73, 90-91` and `SwitcherRowLayout.swift:13`. The window switcher instead has its own `WindowSwitcherLook` (`WindowSwitcherPanel.swift:8-19`) that explicitly copies the `LaunchTuning` "defaults are the shipped look" pattern but is not Codable and not wired to the tuner.
2. Module wall: `LauncherUI` cannot import `LauncherPlatform`, so the existing tuner cannot reach switcher visuals without (a) moving the look type to `LauncherUI` and putting a tuner there, (b) moving a look value into `LauncherCore` (Foundation-only; fine for plain numbers), or (c) injecting from the app target. The tuner itself lives in Platform and uses SwiftUI + `NSHostingView` there.
3. `Codable` conformance for `LaunchTuning` exists only under `#if DEBUG` (`LaunchTuning.swift:59-120`); release builds have no JSON path and `current` is a constant `shipped`. Adding a field requires: property with default, a line in the hand-written `init(from:)` (otherwise it silently decodes as the default because `self.init()` runs first — no compile error), and a `knob(...)` in `TunerView`.
4. Easing is baked into keyframe values sampled at 240 Hz with `calculationMode = .linear` (`LaunchFlight.swift:103-104, 188`; `BounceStaging.swift:63, 80, 99`); timing functions are used only for simple ease-outs (fades, slides, trail). Springs use `CASpringAnimation` with `duration = settlingDuration`.
5. Model-value discipline differs: `LaunchOverlay` sets the model to the last keyframe before adding (:69-70); `OverlayPanel.dismiss` sets model opacity 0 then animates; `springHighlight` is additive toward 0 so the model (set by `show`) is the resting place and each new spring replaces the previous under key `"stretch"` (no velocity carry-over: a new spring restarts from `stretch × pitch` with zero initial velocity — `initialVelocity` is never set).
6. `SwitcherPanel.show` relies on IMPLICIT actions for the icon grow (second transaction, `setAnimationDuration(0.12)`, :71-78), and it runs on every model change, re-setting the same transforms each frame; performance.md:65 says about a quarter of swipe CPU is this per-frame `show` (CA commits + `NSView.setFrame` on the glass highlight), and performance.md:78 records a rejected optimisation because skipping unchanged transforms "would likely change the icon-grow animation".
7. The highlight is moved via `highlight.frame.origin.x` on an `NSGlassEffectView` (an NSView frame change, inside a no-actions transaction), while the spring animates its backing `layer`'s `position.x` additively. Changing frame on a view whose layer has an additive animation composes because the animation is additive.
8. Deadlines treat `finished == false` as passed (`BounceOverlay.swift:355-364`), so a layer removal without cancellation would fire `passed` — that is why `end` and `preview` set `isCancelled` before removing the slot.
9. `CATransaction.setCompletionBlock` must be set before adding animations in that transaction; it fires after all animations added in that transaction complete. Completion closures hop with `MainActor.assumeIsolated` (`LaunchOverlay.swift:55`, `BounceOverlay.swift:330`, `OverlayPanel.swift:104`).
10. Panels are tracked in Swift sets until completion (`playingPanels`, `fading`) because AppKit keeps closed panels in its window list and `isReleasedWhenClosed = false`.
11. In DEBUG, saved tuner values apply only after the tuner is constructed (opening by hand); before that `tunerOverride` is `.shipped` (`AnimationTuner.swift:9, 93-98`; `TrackpadLauncherApp.swift:76-91`).
12. The scanner bans the substring `Timer` everywhere in shipped sources, including identifiers and comments (e.g. a type named `WobbleTimer` or a comment "no Timer here" would fail). `TimelineView` is not caught, but would violate architecture.md:21.
13. `TunerModel.preview` swaps the global override for the duration of a synchronous call — works only because every reader snapshots `LaunchTuning.current` synchronously at effect start.
14. architecture.md:21 explicitly allows "code may run per input event while the effect it serves is on screen: the switchers' highlight on trackpad frames" — the sanctioned cadence for a finger-driven shape is trackpad frames, not display frames.

## Open Questions

- I did not read `SwitcherSelection.swift` in full (only the `stretch` formula lines) or how `Launcher` publishes `switcher` per frame (other explorers' angle). Frame rate of model updates during a swipe is therefore not established here.
- I did not verify whether `NSGlassEffectView`'s backing layer reliably accepts `CASpringAnimation` on `position.x` vs. AppKit re-laying it out; the code assumes it works.
- Whether `CATransaction` implicit actions on the `iconsHost` sublayers actually animate (they are standalone `CALayer`s, not view-backing layers, so they should) was inferred, not measured.
- Did not inspect `SettingsView`/`SettingsWindow` for SwiftUI animations beyond the grep (grep found no `withAnimation`/`.animation(`).
- No test asserts that `TimelineView`/`withAnimation` are absent; only the doc forbids per-display-frame code.
