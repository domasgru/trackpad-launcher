# How the app switcher renders today (angle: RENDERING)

All paths relative to repo root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/024-fluid-app-switcher/`.
Source dir abbreviation: `UI/` = `LauncherKit/Sources/LauncherUI/`, `Core/` = `LauncherKit/Sources/LauncherCore/`.

## Headline facts

- **No SwiftUI anywhere in the switcher.** Pure AppKit + Core Animation. SwiftUI is only the settings window. Plan 006 dev log explicitly rejected "SwiftUI content for the switcher (its springs are not Core Animation keyframes, the architecture's rule)" (`plans/006-five-finger-tap-and-corner-swipe/development-logs.md:30`).
- **Glass is AppKit `NSGlassEffectView`** (two of them: panel `.regular`, highlight `.clear`). No `NSGlassEffectContainerView`, no SwiftUI `.glassEffect`/`GlassEffectContainer`. The highlight is a glass view nested *inside* the panel glass's `contentView` (glass on glass), so nothing merges/morphs between glass shapes today.
- **Icons are bare `CALayer`s** (one per app) with `contents = CGImage`, hosted in a plain layer-backed `NSView`.
- **Motion is driven by Core Animation**, on the **main actor**, once per trackpad input event that changes travel. The highlight's follow is a **non-animated** frame set (actions disabled); the icon grow is a 0.12 s **implicit** CA animation; the end-of-row rubber band is an **explicit additive `CASpringAnimation`**; the dismiss is an **explicit `CABasicAnimation`** on opacity with a completion block.
- **Architecture rule** (`docs/architecture.md:21`): "Animation is Core Animation keyframes, which the render server plays. Whatever an animation leaves behind is cleaned up from its completion callback. No code of ours runs per display frame, and display links are banned along with timers. Code may run per input event while the effect it serves is on screen: the switchers' highlight on trackpad frames…". Enforced partly by `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:30-35` which bans the tokens `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` in shipped sources. (Highly relevant to a "liquid" redesign that wants per-frame shape updates or velocity-driven waves.)

## Components Found

| Name | File | What it is |
|---|---|---|
| `SwitcherPresenter` | `UI/SwitcherPresenter.swift:11` | Observes `launcher.switcher`, lays out/presents/updates/dismisses `SwitcherPanel`; owns the 80 pt icon cache (`AppIcons`) and its refresh observers. |
| `SwitcherPanel` | `UI/SwitcherPanel.swift:7` | `OverlayPanel` subclass holding the highlight glass view and the icon layers; `layoutRow`, `show`, `springHighlight`. |
| `OverlayPanel` | `UI/OverlayPanel.swift:17` | Shared `NSPanel` subclass for both switchers: borderless, non-activating, click-through, screen-saver level; wraps content in `.regular` glass under `roundedClip`; `present(appear:)` / `dismiss()` (150 ms fade) with a generation counter. |
| `OverlayAppear` | `UI/OverlayPanel.swift:6` | Optional appear animation (opacity fade + scale spring from top-left). App switcher never uses it (`present(appear: nil)`); window switcher does. |
| `roundedClip(_:cornerRadius:)` | `UI/GlassClip.swift:6` | Wraps a glass view in a layer-backed `NSView` with continuous-corner `cornerRadius` + `masksToBounds`, glass pinned by Auto Layout. |
| `SwitcherRowLayout` | `Core/SwitcherRowLayout.swift:7` | Pure value: all switcher geometry (icon side, gap, pitch, highlight side, padding, panel size, `centreX(at:)`, `centreY`, narrow-display `scale`). |
| `SwitcherSelection` | `Core/SwitcherSelection.swift:6` | Pure value: `position` (continuous, clamped, in items), `selected` (rounded int), `stretch` (signed saturating rubber band in items). This is what the renderer consumes. |
| `Switcher` | `Core/Switcher.swift:6` | Model value: fixed `row: [AppEntry]` + `selection`. |
| `AppIcons` | `UI/AppIcons.swift:10` | Icon bitmap cache keyed by app URL, stamped with Info.plist mtime + appearance name; draws 1x+2x `NSBitmapImageRep`s. |
| `Displays.screen(under:)` | `UI/Displays.swift:5` | Screen containing the pointer, else nearest screen. |
| `WindowSwitcherPanel` / `WindowSwitcherPresenter` | `UI/WindowSwitcherPanel.swift:23`, `UI/WindowSwitcherPresenter.swift:9` | Sibling window switcher; shares `OverlayPanel`, `roundedClip`, `Displays`, `AppIcons`, the highlight pattern and the identical spring. |

## View / window / layer hierarchy (app switcher)

```
SwitcherPanel : OverlayPanel : NSPanel        (styleMask [.borderless, .nonactivatingPanel], backing .buffered, defer: true)
  contentView = clip: NSView                  (roundedClip; layer.cornerRadius 34, cornerCurve .continuous, masksToBounds)   <- fade animates THIS layer's opacity
    NSGlassEffectView (style .regular, cornerRadius 34; pinned to clip by Auto Layout)
      .contentView = content: NSView          (wantsLayer; frame set manually to panel size)
        highlight: NSGlassEffectView          (style .clear, cornerRadius 24, wantsLayer; added first => drawn UNDER icons)
        iconsHost: NSView                     (wantsLayer; frame = content.bounds)
          layer
            CALayer x N                       (one per app; bounds iconSide², position = (centreX(i), centreY), contents = CGImage)
```
Sources: `UI/OverlayPanel.swift:27-45`, `UI/GlassClip.swift:6-21`, `UI/SwitcherPanel.swift:8-28,44-58`.

Panel config (`UI/OverlayPanel.swift:28-38`): `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`, `ignoresMouseEvents = true`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `animationBehavior = .none`, `isReleasedWhenClosed = false`; `canBecomeKey`/`canBecomeMain` overridden to `false` (`:47-48`).

The panel is created once, eagerly, when `SwitcherPresenter` is constructed (`UI/SwitcherPresenter.swift:13`, comment `:7`) — "so a swipe never pays the first window's cost". `SwitcherPresenter` is constructed in `SettingsShell.init` (`UI/SettingsShell.swift:28`).

## What GlassClip is for and why

`UI/GlassClip.swift:3-5` doc comment: "The glass alone leaves faint full-rectangle content behind its rounded corners, and the window shadow traces that rectangle as a square outline. Clipping the content to the glass's shape makes everything outside the rounded corners transparent, so the shadow follows the rounded edge."
- Mechanism: a layer-backed `NSView` with `cornerRadius` = the glass radius, `cornerCurve = .continuous`, `masksToBounds = true`; the glass is pinned edge-to-edge via constraints (`:12-19`).
- History: introduced by commit `85ea6f2` "Remove square window outline…" (first app); extracted into a shared file during plan 006 review ("`roundedClip` shared in `GlassClip.swift`", `plans/006-.../development-logs.md:43`).
- Only the outer panel glass is clipped. The highlight glass is not wrapped in a clip.
- Consequence for redesign: the window shadow (`hasShadow = true`) is the *window server* shadow derived from the window's alpha; `invalidateShadow()` is called after each `layoutRow` (`UI/SwitcherPanel.swift:60`). Any shape that changes at runtime (e.g. a swelling panel) would not automatically update the window shadow — it is only recomputed on `invalidateShadow()`.

## Exact numbers and where they live

| Value | Where |
|---|---|
| Icon side 80 pt (`fullIconSide`) | `Core/SwitcherRowLayout.swift:8` |
| Gap 20 pt (`fullIconGap`) | `Core/SwitcherRowLayout.swift:9` |
| Highlight side 92 pt (`fullHighlightSide`), square | `Core/SwitcherRowLayout.swift:10` |
| Padding 22 pt (panel edge to highlight edge, all four sides) | `Core/SwitcherRowLayout.swift:11` |
| Selected icon scale 1.12 (89.6 pt, < 92 pt highlight) | `Core/SwitcherRowLayout.swift:13`; tested `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift:73-79` |
| Pitch = iconSide + iconGap = 100 pt at scale 1 | `Core/SwitcherRowLayout.swift:36` |
| Panel size = (2·22 + ((n−1)·100 + 92)·scale, 2·22 + 92·scale); e.g. 5 icons → 536×136, 1 icon → 136×136 | `Core/SwitcherRowLayout.swift:39-41`; tests `:20-54` |
| `centreX(at p) = 22 + highlightSide/2 + p·pitch` (note: padding NOT scaled) | `Core/SwitcherRowLayout.swift:44-46` |
| `centreY = panelHeight/2` | `Core/SwitcherRowLayout.swift:49` |
| Panel glass corner radius 34 (`SwitcherPanel.cornerRadius`) | `UI/SwitcherPanel.swift:8` (passed to `OverlayPanel.init` → glass radius and clip radius) |
| Highlight glass corner radius 24 (hard-coded, NOT scaled by layout.scale) | `UI/SwitcherPanel.swift:24` |
| Icon grow animation duration 0.12 s (implicit) | `UI/SwitcherPanel.swift:73` |
| Rubber-band spring: mass 1, stiffness 420, damping 22, duration = `settlingDuration`, keyPath `position.x`, additive, key `"stretch"` | `UI/SwitcherPanel.swift:83-94` (damping ratio ≈ 22 / (2·√420) ≈ 0.54, underdamped) |
| Dismiss fade 150 ms ease-out, key `"fade"` | `UI/OverlayPanel.swift:18,20,109-115` |
| Max rubber band shown: 0.2 items (`switcherMaxStretch`) | `Core/GestureRules.swift:31` |
| Overshoot travel kept: 0.25 items (`switcherMaxOvershoot`) | `Core/GestureRules.swift:34` |
| Step 12 "step mm" per item (`switcherStepMM`) | `Core/GestureRules.swift:29` |
| Max 10 apps (`switcherMaxApps`) | `Core/GestureRules.swift:25` |

Note 34 − 22 = 12 ≠ 24: the app switcher's highlight corner is *not* concentric with the panel (the window switcher's look explicitly is: `panelRadius 22`, `highlightRadius 14`, comment "so the two corners are concentric", `UI/WindowSwitcherPanel.swift:9-10`).

## Flow

### 0. Input to model (context only; other explorers own this)
- Frame thread → `DispatchQueue.main.async { MainActor.assumeIsolated { … onEvent … } }` (`LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:95-104`), FIFO per frame thread.
- `GestureRecognizer` emits `.moved(travelMM:)` **only when travel changed** (`Core/GestureRecognizer.swift:196-199`).
- `Launcher.swipe(_:)` (`Core/Launcher.swift:290-321`): `.began` sets `shown = .apps(Switcher(...))`; `.moved` calls `open.selection.follow(travel)` and reassigns `shown`; `.ended`/`.cancelled` set `shown = nil`. `Launcher` is `@MainActor @Observable` (`Core/Launcher.swift:9`); `switcher` is a computed view of `shown` (`:13-15`).

### 1. Observation → render (main actor)
- `SwitcherPresenter.init` (`UI/SwitcherPresenter.swift:22-35`) starts a `Task` iterating `Observations({ launcher.switcher })` and calls `render(shown)` per yielded value (`:25-28`). LauncherUI has `defaultIsolation(MainActor.self)` (`LauncherKit/Package.swift:15-19`), so the class and the Task are main-actor isolated. `render` therefore runs on the main thread, on a later main-actor turn than the frame block that mutated the model (async sequence hop).

### 2. `render(_:)` (`UI/SwitcherPresenter.swift:116-129`)
- `nil` → `panel.dismiss()` and return (`:117-120`).
- Reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` fresh each call (`:121`) — no observer.
- If `!panel.isPresented || switcher.row != laidOutRow` → `open(row)` (`:122`). Row is fixed per swipe, so in practice `open` runs on the first render of each swipe (dismiss sets `isPresented = false` immediately, so even a swipe started during the previous fade re-opens).
- `panel.show(position: CGFloat(selection.position), selected: selection.selected, animatesSize: !reduceMotion)` (`:123-124`).
- If `selection.stretch != lastStretch && stretch != 0 && !reduceMotion` → `panel.springHighlight(from: stretch * layout.pitch)` (`:125-127`); `lastStretch = stretch` (`:128`).

### 3. `open(_:)` (`UI/SwitcherPresenter.swift:131-140`)
- `Displays.screen(under: NSEvent.mouseLocation)` (`UI/Displays.swift:5-9`): first screen whose `frame` contains the pointer (`NSMouseInRect`, not flipped), else the nearest by Euclidean distance to the frame.
- `layout = SwitcherRowLayout(iconCount: row.count, displayWidth: screen.frame.width)` (full frame width, not visibleFrame).
- Icons: `row.map { icons.icon(forSwitcher: $0) }` → `[NSImage]`.
- `panel.layoutRow(images, layout:, on: screen.frame, scale: screen.backingScaleFactor ?? 2)`.
- `laidOutRow = row; lastStretch = 0; panel.present(appear: nil)` (no appear animation for the app switcher — it pops in at full opacity).

### 4. `SwitcherPanel.layoutRow` (`UI/SwitcherPanel.swift:32-61`)
- Window frame: centred on `screen.midX/midY` (full display frame, i.e. centre of the display including menu bar area), size = `layout.panelSize`, `setFrame(..., display: false)` (`:34-38`).
- `content.frame = (0,0,size)`, `iconsHost.frame = content.bounds` (`:39-40`).
- Highlight size = `highlightSide²`; `origin.y = centreY − highlightSide/2` (`:41-42`). (x is set by `show`.)
- In a `CATransaction` with actions disabled (`:44-59`): removes old icon layers, creates one `CALayer` per image: `bounds = iconSide²` (layout-scaled), `position = (centreX(i), centreY)` (default anchor 0.5,0.5 so later scale transforms grow about the centre), `contents = image.cgImage(forProposedRect: 80·backingScale square)`, `contentsScale = backingScale`, `minificationFilter = .trilinear` (for narrow-display shrink), added to `iconsHost.layer`.
- `invalidateShadow()` (`:60`).
- Naming trap: the `scale` parameter here is the display's **backing** scale factor, not `layout.scale`.

### 5. `OverlayPanel.present(appear: nil)` (`UI/OverlayPanel.swift:52-80`)
- `isPresented = true; generation += 1`.
- On `contentView.layer` (the clip view's layer): with actions disabled, removes `"fade"` and `"appearScale"` animations, sets `opacity = 1` (cancels an in-flight dismiss fade instantly).
- `appear == nil` for app switcher → straight to `orderFrontRegardless()`.

### 6. Per input event: `SwitcherPanel.show` (`UI/SwitcherPanel.swift:65-79`)
- Highlight follow: in `CATransaction` with `setDisableActions(true)`: `highlight.frame.origin.x = layout.centreX(at: position) − highlightSide/2` (`:66-69`). This is an **NSView frame** set on a layer-backed view (perf doc: "Core Animation commits and `NSView.setFrame` on the glass highlight", `docs/performance.md:65`). No animation: the highlight jumps to the finger-derived position each event. `position` is continuous/fractional (`Core/SwitcherSelection.swift:44-46`), so the highlight slides smoothly between icons in proportion to travel, clamped to [0, count−1]; it does not snap to the selected icon.
- Icon grow: second `CATransaction`, `setDisableActions(!animatesSize)`, `setAnimationDuration(0.12)`; for **every** icon layer sets `transform = CATransform3DMakeScale(s, s, 1)` with `s = 1.12` for `selected` else 1 (`:71-78`). These are standalone `CALayer`s (not view-backing layers), so the property set triggers Core Animation's **implicit** action (default `CABasicAnimation` for `transform`), duration 0.12 s, no explicit timing function set. With Reduce Motion actions are disabled → instant.
  - `selected` = nearest item, `round(travel/12)`, so the grow flips at the halfway point between icons (`Core/SwitcherSelection.swift:39-42`).

### 7. Rubber band: `SwitcherPanel.springHighlight(from:)` (`UI/SwitcherPanel.swift:83-94`)
- Model position stays at the clamped end (step 6). Each time `stretch` changes (and is non-zero), an additive `CASpringAnimation` on the highlight's backing layer `position.x` from `stretch·pitch` points to 0 is added under key `"stretch"`, replacing the previous one. `stretch` is signed, saturating: `±0.2·(1 − 1/(1 + |excess|/0.2))` items (`Core/SwitcherSelection.swift:48-54`).
- Effect: while fingers keep pushing past an end, each new event restarts a spring at the current offset (so the highlight appears displaced by up to 0.2 pitch = up to 20 pt); when events stop (fingers still past the end but not moving) the last spring settles back to the end over `settlingDuration`. When stretch returns to 0 nothing new is added; the current spring finishes.
- Animates `highlight.layer` (the `NSGlassEffectView`'s backing layer) directly — bypasses the NSView frame.

### 8. Dismiss: `OverlayPanel.dismiss()` (`UI/OverlayPanel.swift:94-117`)
- No-op unless `isPresented`. Sets `isPresented = false`, `generation += 1`.
- Reduce Motion (or no layer) → `removeNow()` immediately: `orderOut(nil)` then `emptied()` (`:122-125`).
- Otherwise in a `CATransaction` with a completion block: `CABasicAnimation("opacity")` from `layer.presentation()?.opacity ?? layer.opacity` to 0, duration 0.15, `.easeOut`; model `layer.opacity = 0`; added under key `"fade"` on the clip view's layer. Completion (main thread, `MainActor.assumeIsolated`) checks `self.generation == current` (so a `present` during the fade wins) then `removeNow()`.
- `SwitcherPanel` does **not** override `emptied()`; icon layers and highlight remain in the panel after orderOut until the next `layoutRow` replaces them. (`WindowSwitcherPanel` overrides `emptied()` to drop previews, `UI/WindowSwitcherPanel.swift:93-95`.)
- History: originally `panel.animator().alphaValue`; changed in plan 006 review to a CA opacity fade with `orderOut` from completion guarded by a generation counter (`plans/006-.../development-logs.md:39`).

## How icons (NSImage) get into the views

- `AppIcons(side: 80)` owned by `SwitcherPresenter` (`UI/SwitcherPresenter.swift:14`).
- Pre-drawing ("icon passes") only while the swipe setting is on (`UI/SwitcherPresenter.swift:24,31-33,44-76`): at init (waiting, on main actor: `renderOnMainActor`), on `NSWorkspace.didLaunchApplicationNotification` (off-main pass for that app), on `didTerminateApplicationNotification` (evict unless another copy still runs), and on KVO of `NSApp.effectiveAppearance` (off-main redraw of all running Dock apps). Off-main = `@concurrent` static func with `DispatchQueue.concurrentPerform` (`UI/AppIcons.swift:106-126`).
- Each icon is an `NSImage` with two `NSBitmapImageRep`s: 80×80 px (1x) and 160×160 px (2x), drawn under `appearance.performAsCurrentDrawingAppearance` (`UI/AppIcons.swift:134-154`).
- At open: `icon(forSwitcher:)` (`UI/AppIcons.swift:50-64`) returns cache hit if the stamp's appearance matches current `NSApp.effectiveAppearance`; else draws from the running app's `NSRunningApplication.icon` on the main actor (~0.1 ms); else draws from the bundle on the spot.
- Into the layer: `image.cgImage(forProposedRect: 80·backingScale square)` → picks the matching rep → `CALayer.contents` (`UI/SwitcherPanel.swift:51-54`). On a 3x display it would ask for 240 px and AppKit would pick/scale from the 160 px rep (no 3x rep exists) — not verified on hardware.

## Narrow-display scale

- `SwitcherRowLayout.init` (`Core/SwitcherRowLayout.swift:19-26`): `scale = min(1, (displayWidth − 2·22) / fullSpan)`, `fullSpan = (n−1)·100 + 92`. Non-positive width → 1.
- Applied by multiplying icon side, gap, pitch, highlight side; padding stays 22 (`:33-41`). E.g. 10 icons on 1024 pt display → scale 980/992, panel exactly 1024 wide (tests `:56-71`).
- In the panel: icon layer bounds use scaled `iconSide`; bitmap stays the full 80 pt·backing (`SwitcherPanel.swift:51`) and is downsampled by `minificationFilter = .trilinear`. Highlight frame uses scaled `highlightSide`, but highlight `cornerRadius` 24 and panel radius 34 do NOT scale. Rubber band offset uses scaled `layout.pitch` (`SwitcherPresenter.swift:126`).

## What happens at rest

- Nothing redraws in our code. The recognizer emits `.moved` only when travel changed (`Core/GestureRecognizer.swift:197-199`); no timers/display links exist (banned). In-flight CA animations (0.12 s grow, spring, fade) play on the render server and end.
- `NSGlassEffectView` itself is a system-rendered material; whether the render server re-composites it continuously when the backdrop changes is system behaviour, not app code.

## Appearance (light/dark)

- No explicit appearance code in `SwitcherPanel`/`OverlayPanel`. The two `NSGlassEffectView`s inherit the app's effective appearance (system-managed). The highlight glass has no `tintColor` in the app switcher (the window switcher adds `labelColor` at 0.08 alpha, `UI/WindowSwitcherPanel.swift:11-12,37`).
- Icons: cached per appearance (stamp), redrawn off-main on `NSApp.effectiveAppearance` KVO (`UI/SwitcherPresenter.swift:64-66`), and `icon(forSwitcher:)` treats a stale-appearance stamp as a miss. Already-laid-out icon layers are only refreshed at the next `open` (next swipe), so an appearance change mid-swipe keeps old icons until the next swipe.

## Reduce Motion

- Read synchronously via `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` on each `render` (`UI/SwitcherPresenter.swift:121`) and in `dismiss` (`UI/OverlayPanel.swift:98`) and `present` (`:62`). Not observed.
- With it on: highlight still follows fingers (it is never animated anyway); icon grow is instant (`animatesSize: false` → actions disabled); no rubber-band spring (stretch not shown at all — the highlight just sits at the end); close is instant `orderOut`.

## Threads / actors

- All rendering on the main actor/main thread: LauncherUI default isolation is `MainActor` (`LauncherKit/Package.swift:18`). Workspace observers use `queue: .main` + `MainActor.assumeIsolated` (`UI/SwitcherPresenter.swift:53-62`); KVO callback uses `MainActor.assumeIsolated` (`:64-66`); CATransaction completion uses `MainActor.assumeIsolated` (`UI/OverlayPanel.swift:104`).
- Only icon drawing runs off main (`@concurrent`, `concurrentPerform`).
- Animations themselves run on the render server.

## What the window switcher shares (for reference)

- `OverlayPanel` (window config, `.regular` glass + `roundedClip`, `present`/`dismiss`, 150 ms fade, generation counter).
- Same highlight pattern: `.clear` `NSGlassEffectView` in the panel glass's content, frame set with actions disabled per event (`UI/WindowSwitcherPanel.swift:98-104`), plus an identical additive spring but on `position.y` with `-offset` because content isn't flipped (`:108-120`); stiffness/damping come from `WindowSwitcherLook` (420 / 22 — same numbers) (`:16`).
- Differences: window switcher uses an `OverlayAppear` (0.1 s fade + scale spring from 0.96 about the top-left) unless Reduce Motion (`UI/WindowSwitcherPresenter.swift:72-77`); its highlight radius scales with layout and is concentric; it sets the whole highlight `frame` (not just origin.x); uses `NSImageView`/`NSTextField` subviews rather than raw icon CALayers; positioned at top-left of `visibleFrame` + margin rather than centred on `frame`.
- `WindowSwitcherLook` (`UI/WindowSwitcherPanel.swift:8-19`) is a "look" value whose defaults are the shipped look; the app switcher has no equivalent — its look constants are scattered across `SwitcherRowLayout` (Core) and literals in `SwitcherPanel` (34, 24, 0.12, 420, 22).

## Boundaries

- **In:** `Launcher.switcher: Switcher?` (via `Observations`), specifically `row: [AppEntry]`, `selection.position: Double`, `selection.selected: Int`, `selection.stretch: Double`. No velocity/time/finger speed reaches the renderer today; the recognizer uses frame intervals only internally for pointer-acceleration travel (`Core/GestureRecognizer.swift:187,195`).
- **In:** `NSEvent.mouseLocation` + `NSScreen` (at open only), `NSWorkspace` notifications, `NSApp.effectiveAppearance`, Reduce Motion flag.
- **Out:** pixels only. The panel never takes focus, ignores mouse events, and posts nothing back to the model.
- Geometry policy lives in `LauncherCore` (`SwitcherRowLayout`, `SwitcherSelection`, `GestureRules`) and is unit-tested; the AppKit panel has no tests (no test target renders UI).

## Non-Obvious Things

1. **The icon-grow animation restarts on every input event.** `show` re-sets `transform` on every icon layer every event, even when unchanged. Each set fires a new implicit 0.12 s animation that replaces the previous one starting from the current presentation value, so while fingers move the selected icon's grow is continually re-launched (effectively an ease toward 1.12 that keeps getting re-targeted). `docs/performance.md:78` rejected skipping unchanged transforms precisely because it "would likely change the icon-grow animation, which plan 013 keeps unchanged". About a quarter of swipe CPU was this per-frame `show` (`docs/performance.md:65`).
2. **The highlight's follow is not animated at all**; smoothness comes purely from input-event rate. Only the rubber band is animated, and only as a spring *back* from a displaced offset re-added on each stretch change.
3. **Two different mechanisms move the highlight**: `NSView.frame.origin.x` for follow, an additive animation on the backing `CALayer`'s `position.x` for stretch. They compose because the spring is additive.
4. **Rubber band is not visible as a held offset**: if fingers stop moving past an end, the last spring settles to 0, so the highlight returns to the end icon while the fingers are still past it.
5. **Highlight is drawn under the icons** (added to `content` before `iconsHost`), and is a separate glass view nested in the panel glass, not in an `NSGlassEffectContainerView`.
6. **Padding is not scaled** on narrow displays, and corner radii (34, 24) are not scaled either.
7. **`layoutRow`'s `scale` parameter is the backing scale**, not `layout.scale`.
8. **Panel centred on the display's full `frame`** (not `visibleFrame`), on whichever display holds the pointer at swipe start; not re-centred mid-swipe.
9. **No appear animation** for the app switcher (it appears at full opacity instantly), while it does have a fade-out. The window switcher has both.
10. **The fade animates the clip view's layer opacity**, not `NSWindow.alphaValue`; the window is ordered out only from the completion block, guarded by `generation`, so a new swipe during the 150 ms fade cancels it (`present` removes the `"fade"` animation and resets opacity to 1).
11. `SwitcherPanel` leaves icon layers attached after dismiss (no `emptied()` override); they are swapped at next `layoutRow`.
12. Reduce Motion is read live, not observed, and also suppresses the rubber band entirely.
13. Window shadow is the window server's, recomputed only via `invalidateShadow()` after layout; GlassClip exists to make that shadow round.

## Open Questions

- Whether `Observations` coalesces several `.moved` frames into one `render` when multiple main-queue frame blocks run before the observing Task resumes (SE-0475 semantics allow coalescing). I did not verify empirically; it affects whether the renderer sees every frame.
- Whether `@Observable`'s setter skips notification when `shown` is reassigned with an equal value (e.g. travel clamped at the overshoot band so `follow` leaves the selection unchanged). If it notifies, `render` re-runs `show` with identical values (re-firing implicit icon animations).
- Exact implicit-animation timing for the 0.12 s icon grow: no `animationTimingFunction` is set on the transaction, so it uses Core Animation's default for implicit actions; I did not confirm which curve that is on macOS 26.
- How the window-server shadow behaves during the 150 ms opacity fade (whether it fades with the layer) — not determinable from code.
- Whether `NSGlassEffectView` resizes its `contentView` automatically; the code sets `content.frame` explicitly anyway (`UI/SwitcherPanel.swift:39`).
- Behaviour on a 3x backing display (no 3x icon rep is drawn).

## Files Read

- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/GlassClip.swift`
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`
- `LauncherKit/Sources/LauncherUI/Displays.swift`
- `LauncherKit/Sources/LauncherUI/AppIcons.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/SettingsShell.swift` (lines 1-40)
- `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift`
- `LauncherKit/Sources/LauncherCore/Switcher.swift`
- `LauncherKit/Sources/LauncherCore/GestureRules.swift` (lines 20-40)
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (lines 1-70, 280-330)
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (lines 175-215)
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (lines 80-120)
- `LauncherKit/Package.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (lines 1-80)
- `docs/architecture.md` (grep: lines 11, 12, 19-22)
- `docs/performance.md` (lines 55-85)
- `docs/domain-model.md` (grep: Switcher section line 51)
- `plans/006-five-finger-tap-and-corner-swipe/development-logs.md` (grep hits lines 25-49)
