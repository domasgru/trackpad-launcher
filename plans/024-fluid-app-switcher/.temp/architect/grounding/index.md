# Grounding index: plan 024, liquid app switcher

Start here. Every fact a design decision rests on, with its standing. Paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/024-fluid-app-switcher/` unless absolute. `G/` = `plans/024-fluid-app-switcher/.temp/architect/grounding/`.

- **how ran**: four explorers plus an explainer. Read `G/how.md` first; the raw findings are `G/how-state-pipeline.md`, `G/how-rendering.md`, `G/how-animation-infra.md`, `G/how-tests-perf.md`.
- **why ran**: on the switcher's visual shape and on the per-display-frame ban. `G/why.md` ends with the Preserve / Change / Avoid / Risk constraint set; raw evidence is in `G/why-source-control.md` and `G/why-plans.md`.
- **Probes** ran on this machine today (macOS 26.6.2 25G83, Xcode 27.1 with SDK 27.0; deployment target stays macOS 26). Sources are in `G/probes/*.swift`, printed output in `G/probes/*-output.txt` and `G/probes/p6-and-cpu-output.txt`, and window captures in `G/probes/captures/`. Look at the captures: several facts below are visual.

## Facts the design rests on

### A. How Liquid Glass can form one liquid shape

- **A1. probed (P1, P1b).** `NSGlassEffectContainerView` merges its descendant `NSGlassEffectView`s into one continuous glass shape with smooth necks. AppKit mirrors each glass view into a separate render subtree under the container (`NSEffects`, then `SDFLayer`, then `CABackdropLayer` with `glassBackground`, then `CASDFLayer`, then one `CASDFElementLayer` per glass view, carrying its frame and `cornerRadius`). The merge is a signed-distance union computed by the render server from those element layers.
  - Captures: `captures/p1-view-layer-anim-rest.png`, `p1b-spacing40-necks.png`, `p3-rest.png`.
  - `CASDFLayer` properties: `effect`, `effectOffset`, `gaussianRadius`, `mergeElements`, `smoothness`.
  - `CASDFElementLayer` properties: `contentsOneValueDistance`, `contentsZeroValueDistance`, `gradientOvalization`, `hitTestsAsFill`, `mode`, `operation`.
  - Each element's delegate is `_SwiftUISDFLayerDelegate`. AppKit's glass is SwiftUI-backed underneath.
- **A2. probed (P1b).** `spacing` governs when two elements bridge.
  - At spacing 24, circles 16 pt apart stayed separate and circles 2 pt apart merged.
  - At spacing 40, circles 16 pt apart joined with a neck.
  - Conclusion from these two points only: bridging starts when the gap is below roughly half the spacing.
  - A band element (a capsule under every bead) gives an unbroken shape whatever the spacing (`p3-rest.png`: band 48 pt tall, beads 64 pt, swell 92 pt, spacing 40).
- **A3. probed (P1).** A Core Animation animation on a glass view's own backing layer, inside a container, does **not** move the glass. The `rest` and `mid` captures are byte-identical (74 874 bytes each), and the element layers carried no animation.
  - Conclusion: any design that animates `NSGlassEffectView.layer` inside a container shows nothing.
  - Not probed: whether today's standalone highlight spring on the glass view's layer moves its glass.
- **A4. probed (P1b, P2): public animation of merged glass runs in-process, once per display frame.**
  - `NSAnimationContext` with `view.animator().frame`: about 300 main run loop wake-ups during a 1.2 s animation. AppKit steps the element frames itself; the element layers carry no CA animation. Process CPU over the animation window was **133 to 167 ms**.
  - Implicit animation (`allowsImplicitAnimation`): same, about 290 wake-ups.
  - SwiftUI `GlassEffectContainer` + `.glassEffect(in:)`, custom `Shape`, `withAnimation(.spring)`: 200 wake-ups and **199 `Shape.path(in:)` calls** in 1.6 s (one per 120 Hz display frame). Process CPU was **381 to 422 ms**.
  - A custom-shape glass element became one `CASDFElementLayer` much larger than the shape. Conclusion, not verified: it is drawn as a distance-field image.
- **A5. probed (P1b element mode, P3): render-server animation of the merged shape is possible, but only through the private mirror.**
  - A `CABasicAnimation` or additive `CASpringAnimation` added straight onto a `CASDFElementLayer` moves or reshapes the merged glass, and the render server re-merges every frame (`p1b-element-anim-mid.png`, `p3-kick-early.png`, `p3-kick-mid.png`).
  - With only element-layer animations running: 2 to 3 main run loop wake-ups in 1.2 s (P1b), 13 to 15 in 2 s (P3, which includes the probe's own blocks). Process CPU was **2.5 to 4.5 ms**.
  - These element layers are AppKit's private implementation; their class names were found at runtime.
- **A6. probed (P3, P6): how the private mirror behaves.**
  - AppKit mirrors a glass view frame change at once (model equals presentation, no implicit animation).
  - An additive animation on an element layer **survives** AppKit re-syncing that element from its view.
  - A **direct write** to an element layer's frame is **reset** to the view's frame by the next AppKit re-sync. The probe triggered it with a layout pass plus another glass view's frame change.
  - Element layers keep their identity across `orderOut` / `orderFront` and an appearance change.
  - There is no link from an element back to its view: the delegate is SwiftUI's, there is no name, and the order differs from the subview order. Matching is by frame, and 21 of 21 matched in P6.
- **A7. probed (P6): per-input-event cost at the plans' ~100 Hz.** Measured over 200 events in 2 s, with 21 glass views (band, 10 beads, 9 necks, swell) and 11 of them changed per event:

  | Mode | Process CPU | Main wake-ups | Share of a core |
  |---|---|---|---|
  | Public `NSGlassEffectView.frame` sets | **516 to 548 ms** | 626 to 649 | about 26% |
  | Direct element-layer writes | **43 to 58 ms** | 208 to 255 | about 2.5% |
  | Keyed, held additive animations on element layers, replaced per event | **33 to 67 ms** | 438 to 493 | about 2.5% |

  - In the held-additive mode, element model frames stay equal to the views', so AppKit's re-sync clobbers nothing.
  - Compare today's switcher: 1.08 ms per frame (`docs/performance.md`, baseline 2026-10-17), about 11% of a core at 100 Hz.
- **A8. probed (P4).** The all-public render-server alternative fails R2's look. That alternative is one rectangular `NSGlassEffectView` masked by a `CAShapeLayer` blob path. It renders as a flat frosted cut-out: no lensing or rim at the edges, hard joins where shapes meet. The SDF-merged container shows refraction along every edge (`captures/p4-merged-top-vs-masked-bottom.png`: top is merged, bottom is masked).
- **A9. probed (P5).** In a clear, borderless, shadowed overlay window (`hasShadow = true`, `backgroundColor = .clear`):
  - The window-server shadow traces the merged shape, with no rectangle (`p5-light-white.png`). `GlassClip`'s reason does not arise for this shape.
  - The shadow **followed** the new outline 0.25 s after a public frame set, and also after an element-layer animation, with no `invalidateShadow()` (`p5-light-white-frameset.png`, `p5-light-white-element.png`).
  - This supersedes `G/how.md` gotcha 9 and the `why.md` risk on the shadow, both inferred from code.
  - Not probed: whether the shadow keeps up frame by frame during fast motion.
- **A10. probed (P5), judged by eye.**
  - Light appearance over a mostly white window: the band, each bead and the swell are distinguishable from the window and from each other, mostly by the rim and the window shadow (`p5-light-white.png`).
  - Dark appearance over a busy window: the shape reads as glass and every icon stays clear (`p5-dark-busy.png`).
  - Without the window shadow (P3, white window background), the same shape over white is very faint (`p3-rest.png`).
  - Conclusion: R2's light-over-white scenario leans on the window shadow.
- **A11. sourced** (`NSGlassEffectView.h` in the SDK).
  - `NSGlassEffectView`: `contentView`, `cornerRadius`, `tintColor`, `style` (`.regular`/`.clear`). `effectIsInteractive` is macOS 27 and not available at the macOS 26 deployment target.
  - `NSGlassEffectContainerView`: `contentView`, `spacing`.
  - No arbitrary glass shape exists in AppKit. SwiftUI's `.glassEffect(_:in:)` takes any `Shape` (see A4 for its cost).

### B. Architecture rules and the precedents that bind them

- **B1. sourced** (`docs/architecture.md` Concurrency; `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:13-70`).
  - "Animation is Core Animation keyframes, which the render server plays … No code of ours runs per display frame, and display links are banned along with timers. Code may run per input event while the effect it serves is on screen."
  - "Time passes only on Core Animation's clock."
  - The source scan bans the substrings `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` in every shipped file, comments included. `TimelineView`, `withAnimation` and `CACurrentMediaTime` are not token-banned. Per-display-frame code still violates the rule.
- **B2. sourced** (`G/why.md` What We Found). The ban's purpose is our own CPU, both at rest and while an effect shows. Sources: the product mandate of the least resources possible (`docs/product-overview.md`), 001 R22 (zero idle CPU), and plan 004 ("would run code of ours on every frame").
  - Plan 006 rejected SwiftUI for the switcher under this rule.
  - Plan 017's D1 made "per input event while on screen" the rule for later features; the user accepted it.
  - Changing the rule's wording goes to the user as an explicit open question (017 precedent).
- **B3. sourced** (`docs/architecture.md` Privacy and permissions; Shape). Private symbols are already used, each confined to one file by the source-scan test and each with a fallback when missing:
  - MultitouchSupport via `dlopen`;
  - two LaunchServices functions via `dlsym`, with a fallback order;
  - `_AXUIElementGetWindow`, with frame matching as the fallback.
  This is the precedent a design that reaches into the private glass mirror (A5, A6) would follow. No precedent reaches into another framework's private layer tree.
- **B4. sourced** (`docs/architecture.md` Shape; `LauncherKit/Package.swift`).
  - Module dependencies: `LauncherCore` imports only Foundation and Observation (source-scan enforced). `LauncherPlatform` depends on Core. `LauncherUI` depends on Core only, with main-actor default isolation. The app target is the composition root.
  - `LauncherUI` cannot see `LaunchTuning` or the DEBUG tuner in Platform.
  - Every port has exactly two adapters. There is **no switcher UI port**: the UI observes `Launcher.switcher` through `Observations` (`G/how.md` section 5).
- **B5. sourced** (`docs/architecture.md:22`; `G/how-animation-infra.md` section E).
  - Tuning pattern: one `Sendable` value whose property defaults are the shipped look (`LaunchTuning.shipped`; `WindowSwitcherLook` copies the pattern without a tuner). The DEBUG-only tuner lives in `LauncherPlatform`.
  - Shipping a tuning means copying values into the defaults.
  - A DEBUG build at login plays shipped values until the tuner is built.

### C. Today's switcher pipeline (what the new look consumes)

- **C1. sourced** (`G/how.md` sections 2 to 5).
  - Trackpad frames are recognized on the frame thread. `.moved(travelMM:)` carries absolute step-mm travel and is sent only when travel changed. It hops by `DispatchQueue.main.async` (FIFO).
  - `Launcher.swipe(_:)` rewrites `shown` on every `.moved`. `Observations` yields to `SwitcherPresenter` on a later turn and may coalesce several values into one.
  - The UI payload is `Switcher`: `row`, `selection.position` (fractional, clamped), `selection.selected`, `selection.stretch`, `selection.travelMM` (clamped to −3…last+3 step-mm), `selectsFrontmost`.
- **C2. sourced** (`G/how.md` section 5; `G/how-state-pipeline.md`).
  - Not in the payload: **no finger speed, no timestamps, no direction**.
  - `TouchFrame.time` (driver seconds) exists inside the recognizer. The frame interval is consumed by `PointerCurve.cursorMove` and dropped.
  - `SwipePhase` / `SwipeEvent` are shared with the window swipe. `SwitcherSelection` and `GestureRules` are shared with the window switcher, which must keep its look and behaviour.
- **C3. sourced** (`G/how.md` section 4).
  - `selected` changes at ±6 step-mm, then every 12.
  - Overshoot is clamped to 3 step-mm past an end and forgotten on the turn back.
  - Today's `stretch` peaks at about 0.111 items (about 11 pt), not 0.2.
  - R10 asks for up to 20 pt (0.2 pitch), most of it within 3 mm: a new curve over the same clamped overshoot.
  - On a turn back, `stretch` drops to 0 at once, so any spring-back must be animated from the presentation state.
- **C4. sourced** (`G/how.md` gotcha 3). "mm" in R5, R6, R10 and R13 means step-mm. On hardware, one icon is 100 accelerated cursor points. In tests (`.linear`), step-mm are finger mm.
- **C5. sourced and disputed: trackpad frame rate.** Plans 001 and 006 state about 100 Hz while touching. `PointerCurve.reportRate = 120` is a HID acceleration constant, not a measurement. Nobody has measured the rate. Either way it does not lock to a 120 Hz display (R15).
- **C6. sourced** (`G/how.md` section 6; `G/how-rendering.md`). Today's render:
  - `SwitcherPanel : OverlayPanel` is a rounded `.regular` glass in `roundedClip`, holding a `.clear` glass highlight under icon `CALayer`s.
  - Per event, with actions disabled, the highlight's frame is set. The icon transform scales to 1.12 through an implicit 0.12 s animation, re-launched every event.
  - The rubber band is a re-kicked additive `CASpringAnimation` (stiffness 420, damping 22) on the highlight layer.
  - Dismiss is a 150 ms opacity fade on the clip layer, with `orderOut` from completion guarded by a generation counter. Reduce Motion orders out at once.
  - The panel is created once at presenter init, to pay the first-window cost ahead.
  - `OverlayPanel` is shared with the window switcher and imposes the rounded-rect glass.
- **C7. sourced** (`G/how.md` sections 6 and 7).
  - Reduce Motion is read live from `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` in the presenter, `present` and `dismiss`. The model never sees it.
  - Narrow displays: `SwitcherRowLayout.scale` scales icon, gap, pitch and highlight. Padding (22) and corner radii (34, 24) are not scaled.
  - The panel is centred on the full `frame` of the display under the pointer at open.
- **C8. sourced** (`G/how.md` section 3). Lift: `shown = nil` and `bringToFront` run in one main-actor turn before any UI observer runs, so R12 holds structurally today.
- **C9. sourced** (`docs/performance.md`). Swipe cost baseline is 1.08 ms per frame, about a quarter of it the per-frame `show`. Hands off: 0 idle wake-ups. Nothing measures frames drawn, pacing or render-server cost.

## Sources by design question

- **Can the shape be real Liquid Glass, and how is it built?**
  - A1, A2, A8, A11.
  - Captures `p3-rest.png`, `p4-merged-top-vs-masked-bottom.png`.
  - Probes `p1`, `p1b`, `p3`, `p4`.
- **What drives motion after the fingers stop (flow, wobble, settle, spring-back)?**
  - A3 to A6.
  - B1, B2.
  - `G/why.md` Preserve and Avoid.
  - Probes `p1b`, `p2`, `p3`.
- **Per-event cost and smoothness (R15).**
  - A7, C1, C5, C9.
  - `docs/performance.md` (Method, Results 2026-10-17).
  - Probe `p6`, output `probes/p6-and-cpu-output.txt`.
- **Where finger speed comes from (R8).**
  - C2.
  - `G/how-state-pipeline.md` "Finger mm become step-mm" and "Pointer acceleration".
  - `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift:159-203`.
- **End pull (R10) and the travel numbers.**
  - C3, C4.
  - `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift`, `GestureRules.swift`.
- **Window, shadow, open and close (R1, R11, R12).**
  - A9, C6, C8.
  - `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`, `GlassClip.swift`.
  - `G/why.md` on `roundedClip` and `OverlayPanel`.
- **Appearance (R2).**
  - A10.
  - `G/why.md` Risk "Legibility of untinted glass" (PR #24).
  - Captures `p5-*.png`.
- **Tuning in one place (R17).**
  - B4, B5.
  - `G/how.md` sections 8 and 9.
  - `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift`, `AnimationTuner.swift`.
  - `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift:8-19`.
- **Narrow displays (R14).**
  - C7.
  - `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift`, `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`.
- **Private API discipline.**
  - B3.
  - `docs/architecture.md` Privacy and permissions (last two bullets of the second paragraph).
  - `SourcePolicyTests.swift` `confined` list.

## What a test can produce for real, and what needs a fake or a manual check

- **Real, in `swift test`:**
  - The model and recognizer through `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`). Scripted `TouchScript` frames run at 100 Hz, with real `GestureRecognizer` and `Launcher`, and synchronous delivery. `playFrameByFrame` observes per-frame values.
  - Any pure value type in `LauncherCore`, such as geometry, targets or kicks, as numbers.
  - `CAAnimation` objects built by pure staging code can be read back in a test target that imports QuartzCore. Precedent: `LauncherPlatformTests/LaunchFlightTests.swift`, `BounceStagingTests.swift`.
  - **No test target depends on `LauncherUI`.** One can be added. `LauncherCoreTests` cannot import AppKit or QuartzCore types from Core.
- **Needs a fake or a seam:**
  - Time. Animations play on the render server, so a test sees what was staged (keys, from/to, durations, settling), not what was drawn.
  - Reduce Motion. It is read from `NSWorkspace` today; a test needs it passed in.
  - Finger speed. Today a test cannot provoke it through the payload (C2).
  - The private glass mirror (A5, A6). It needs a real window on a real WindowServer. A test needs a seam where the element-layer lookup can be absent, to drive the fallback.
- **Manual on hardware only:**
  - R2's look in light and dark.
  - R15's smoothness at 120 Hz.
  - R16's "draws no new frames". There is no tool in the repo for frames drawn. App CPU and wake-ups come from `Scripts/perf/sampler.c`, and there is no "fingers resting on an open switcher" phase yet.
  - The feel of the wave, wobble and flow.
  - The 200 ms flow bound as seen.

## Open questions

1. **The private mirror versus the animation rule.**
   - Render-server motion of a merged Liquid Glass shape is reachable only through AppKit's private `CASDFElementLayer` mirror (A5, A6). That would be the first reach into another framework's private layer tree (B3).
   - Every public way to animate merged glass runs in-process per display frame (A4) and costs 30 to 100 times more CPU while moving. It would contradict `docs/architecture.md`'s animation rule unless the user changes it (B2).
   - Which way, and with what fallback if the mirror's shape changes in a macOS update?
2. **Per-event updates.** The public frame-set path costs about 26% of a core at 100 Hz (A7), more than twice today's switcher. Element-layer paths cost about 2.5%. Does the per-event path also go through the mirror?
3. **Trackpad frame rate** (C5, disputed), and whether render-server interpolation between input events is needed for R15.
4. **Finger speed for R8** (C2): carried on the event from `TouchFrame.time` (shared with the window swipe), or estimated in the UI from its own clock?
5. **R10 while the fingers rest past an end.** Does the pull hold, or spring back? R10 says it springs back "when the fingers slide left". R9 says the liquid settles when the fingers stop. Today's band springs back while the fingers rest.
6. **R2 light-over-white** leans on the window shadow (A10). It needs a hardware check by the user; a tint is a non-goal and goes back to the user.
7. **Whether the window shadow keeps up during fast motion** (A9, only a 0.25 s snapshot probed).
8. **`OverlayPanel`.** It imposes the rounded-rect glass on both switchers (C6). The app switcher needs a different content shape without changing the window switcher.
