# Grounding: the swipe's app switcher row (begin → model → presenter → panel → layers)

All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order/`.
Abbreviations: `Core` = `LauncherKit/Sources/LauncherCore`, `Platform` = `LauncherKit/Sources/LauncherPlatform`,
`UI` = `LauncherKit/Sources/LauncherUI`, `CoreTests` = `LauncherKit/Tests/LauncherCoreTests`.

## Components Found

| Component | File | What it is |
|---|---|---|
| `Switcher` (struct, `Equatable, Sendable`) | `Core/Switcher.swift:6-33` | The one swipe's switcher: the fixed `row: [AppEntry]`, a private `startsOnFrontmost`, the mutable `selection`, and `trackpad`. |
| `SwitcherSelection` (struct) | `Core/SwitcherSelection.swift:6-57` | Selection along a fixed list: travel in step mm, `selected`, `position`, `stretch`, `follow(_:) -> Int` (items crossed). Shared with the window switcher. |
| `SwitcherRowLayout` (struct) | `Core/SwitcherRowLayout.swift:7-50` | Pure geometry: 80 pt icon, 20 pt gap, 92 pt highlight, 22 pt padding, `selectedIconScale` 1.12, shrink `scale`, `centreX(at:)`, `centreY`, `panelSize`. |
| `GestureRules.switcherMaxApps` etc. | `Core/GestureRules.swift:31-41` | `switcherMaxApps = 10`, `switcherStepMM = 12.0`, `switcherMaxStretch = 0.2`, `switcherMaxOvershoot = 0.25`. |
| `AppEntry`, `RunningApps` | `Core/Apps.swift:12-51` | Domain app identity (`bundleID`, `name`, `url`; `id` is the bundleID) and the one running-apps read (`frontmost`, `apps`). |
| `Launcher` (`@MainActor @Observable`) | `Core/Launcher.swift:10-440` | The model. Holds `private var shown: ShownSwitcher?` (`:67-69`); exposes `public var switcher: Switcher?` (`:14-16`) derived from it; `swipe(_:)` (`:339-369`) is "the one place a swipe becomes effects". |
| `SystemActions` port | `Core/Ports.swift:61-139` | `runningApps() -> RunningApps` (`:128`), `frontmostWindows()` (`:132`), `bringToFront` (`:63`), `hideOtherApps` (`:70`). |
| `TrackpadHardware` port | `Core/Ports.swift:26-50` | `onEvent` (`:32`), `playFeedback(_:on:)` (`:46`). `Haptic { gesture, lightTick }` (`:23`). |
| `SwipePhase` / `SwipeEvent` | `Core/Gesture.swift:34-56` | `.began`, `.moved(travelMM:)` (absolute, sent only when changed), `.ended`, `.cancelled`; plus `trackpad`. |
| `RunningAppsReader` | `Platform/RunningAppsReader.swift:5-49` | Real read behind `runningApps()`: LaunchServices ⌘-Tab order (or fallback) + `NSWorkspace.frontmostApplication`. |
| `LaunchServicesOrder` | `Platform/LaunchServicesOrder.swift:8-56` | Private `_LSCopyApplicationArrayInFrontToBackOrder` / `_LSCopyApplicationInformation` via dlsym; parses into `[AppEntry]`. Asks for a `pid` key but drops it. |
| `RunningApp.entry(for:)` | `Platform/RunningApp.swift:5-20` | The one place a running app's `AppEntry` is built; location spelled by `AppEntry.location(ofBundleAtPath:)`. |
| `WorkspaceActions` | `Platform/WorkspaceActions.swift:7, 85-87` | Real `SystemActions`; `runningApps()` = `reader.read()`. |
| `MultitouchTrackpads` | `Platform/MultitouchTrackpads.swift:10, 92-135` | Real `TrackpadHardware`; hops each recognised event to the main queue; `playFeedback` actuates (gesture = 6, lightTick = 3). |
| `SwitcherPresenter` (final class, LauncherUI, main-actor default) | `UI/SwitcherPresenter.swift:11-139` | Observes `launcher.switcher`, owns the one `SwitcherPanel` and an 80 pt `AppIcons` cache, decides layout/show/spring. |
| `SwitcherPanel: OverlayPanel` | `UI/SwitcherPanel.swift:7-95` | AppKit window: glass highlight (`NSGlassEffectView`) + `iconsHost` NSView whose layer holds one plain `CALayer` per icon. |
| `OverlayPanel: NSPanel` | `UI/OverlayPanel.swift:17-128` | Shared borderless non-activating screen-saver-level panel for both switchers; Liquid Glass content under a rounded clip; `present(appear:)`, `dismiss()` (150 ms fade), `emptied()` hook. |
| `roundedClip` | `UI/GlassClip.swift:6-21` | Wraps the glass in a layer with `cornerRadius` and `masksToBounds = true` (clips everything the panel draws). |
| `AppIcons` | `UI/AppIcons.swift:10-158` | Bitmap icon cache keyed by app URL, stamped by Info.plist mod date + appearance; `icon(forSwitcher:)` is the switcher's accessor. |
| `Displays.screen(under:)` | `UI/Displays.swift:3-16` | Which `NSScreen` holds the pointer (nearest otherwise). |
| `SettingsShell` | `UI/SettingsShell.swift:20-68` | Creates `SwitcherPresenter(launcher:)` and `WindowSwitcherPresenter(launcher:)` once (`:67-68`); lives for the resident process. |
| `WindowSwitcherPresenter` (for contrast) | `UI/WindowSwitcherPresenter.swift:9-100` | Lays out once per window swipe by `serial`; previews arrive asynchronously into the panel. Precedent for async-arriving per-slot data. |

Note on the plan reference: `plans/023-app-selection-grow-animation/plan.md` is NOT about the switcher's selected-icon grow. It
is the app *picker*'s "pick animation" (`PickAnimation`, start 0.4 → peak 1.1 → 1.0, keyframes) and the Debug tuner's tabs
(commit `80e2b2c`, "Picking an app grows its icon into place…"). The switcher's selected-icon grow dates from commit `10b0e91`
("5-finger gesture and the swipe switcher (#5)", plan 006), and plan 013 (`plans/013-simplify-switchers/plan.md:103-105,136,172-174`)
moved the 1.12 constant into `SwitcherRowLayout.selectedIconScale` and pinned it with a test. `PickAnimation` is still a
useful precedent for a pure Core curve type rendered with Core Animation keyframes (`plans/023-.../plan.md:225-244`).

## Flow

### 0. Construction (once per resident process)
1. `TrackpadLauncherApp.makeResident` builds `Launcher` with `MultitouchTrackpads()` and `WorkspaceActions()`, then
   `SettingsShell(launcher:…)` (`TrackpadLauncher/TrackpadLauncherApp.swift:78-92`); `Lifecycle.othersExited` calls
   `launcher.start()` afterwards (`Core/Lifecycle.swift:263-265`). The shell comment: "Create it before `Launcher.start()`:
   its first icon pass must finish before gestures run" (`UI/SettingsShell.swift:15`).
2. `SettingsShell.init` creates `switcherPresenter = SwitcherPresenter(launcher: launcher)` (`UI/SettingsShell.swift:67`).
3. `SwitcherPresenter.init(launcher:)` (`UI/SwitcherPresenter.swift:22-35`):
   - `private let panel = SwitcherPanel()` (`:13`) — the panel is created up front "so a swipe never pays the first window's cost" (`:7`). One panel, reused for every swipe; never torn down per swipe.
   - `private let icons = AppIcons(side: SwitcherRowLayout.fullIconSide)` (`:14`).
   - If `launcher.isSwipeOn`, `startIconPasses(waiting: true)` (`:24`) — synchronous first pass on the main actor.
   - Two observation tasks:
     ```swift
     Task { [weak self] in
         for await shown in Observations({ launcher.switcher }) { self?.render(shown) }
     }
     Task { [weak self] in
         for await on in Observations({ launcher.isSwipeOn }) {
             if on { self?.startIconPasses(waiting: false) } else { self?.stopIconPasses() }
         }
     }
     ```
   - `isolated deinit` cancels both and calls `stopIconPasses()` (`:37-40`).
4. `SwitcherPanel.init()` (`UI/SwitcherPanel.swift:16-28`): `super.init(cornerRadius: 34, content:)`; `content.wantsLayer`;
   `iconsHost.wantsLayer`; `highlight = NSGlassEffectView()` with `.style = .clear`, `cornerRadius = 24`; subviews added
   `highlight` first, then `iconsHost` (so icons draw above the highlight).
5. `OverlayPanel.init` (`UI/OverlayPanel.swift:27-47`): borderless + `.nonactivatingPanel`, clear, `hasShadow`,
   `ignoresMouseEvents`, `level = .screenSaver`, all-Spaces/full-screen-auxiliary, `canHide = false`, `animationBehavior = .none`;
   content = `roundedClip(NSGlassEffectView(.regular, cornerRadius), …)`.

### 1. Recognition → main actor
- The recognizer emits `.slide(kind, .moved(travelMM:))` only when travel changed (`Core/GestureRecognizer.swift:208-212`);
  `TrackpadEvent.init(_:on:)` maps `.swipe(phase)` to `.swipe(SwipeEvent)` (`Core/Ports.swift:12-19`).
- `MultitouchTrackpads` delivers every event via `DispatchQueue.main.async { MainActor.assumeIsolated { … self.confirmation.deliver(event, to: self.onEvent) } }`,
  dropping events from a replaced session (`Platform/MultitouchTrackpads.swift:98-107`). FIFO from one frame thread, so frame order holds.
- `Launcher.start()` sets `hardware.onEvent`; `.swipe(let event)` → `swipe(event)` (`Core/Launcher.swift:112-120`).

### 2. Begin: building the row (`Launcher.swipe`, `.began`, `Core/Launcher.swift:341-348`)
```swift
case .began:
    guard shown == nil, activity.isActive else { return }
    let running = system.runningApps()
    shown = Switcher(
        frontmost: running.frontmost, running: running.apps,
        leavingOut: settings.assignedBundleIDs, trackpad: event.trackpad
    ).map(ShownSwitcher.apps)
```
- `guard shown == nil`: only one switcher of either kind at a time (`ShownSwitcher` is `.apps(Switcher)` or `.windows(WindowSwitcher)`, `:66-69`).
- One synchronous read: `system.runningApps()` → `WorkspaceActions.runningApps()` → `RunningAppsReader.read()` (`Platform/RunningAppsReader.swift:19-26`):
  `order?.apps() ?? fallbackApps()`, then the frontmost via `RunningAppsReader.frontmost(activePID:activeEntry:ownPID:apps:)` (`:43-48`;
  Trackpad Launcher counts as frontmost only while ⌘-Tab lists it).
- Exclusions: `settings.assignedBundleIDs` = `Set(assignments.values.map(\.bundleID))` (`Core/Settings.swift:43`) — read at begin.
- `Switcher.init?` (`Core/Switcher.swift:20-27`), verbatim signature:
  ```swift
  package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, trackpad: TrackpadID)
  ```
  - `others = running.filter { $0.url != frontmost?.url && !leavingOut.contains($0.bundleID) }` — the frontmost copy is
    dropped by *location*, exclusions by *bundle ID*; the frontmost is never excluded.
  - `guard !others.isEmpty else { return nil }` — nothing to switch to → no switcher, `shown` stays nil (the swipe still blocks until lift).
  - `row = Array(((frontmost.map { [$0] } ?? []) + others).prefix(GestureRules.switcherMaxApps))` — frontmost at index 0, cap 10.
  - `startsOnFrontmost = frontmost != nil`; `selection = SwitcherSelection(count: row.count)`.
- `row` is `public let` — immutable for the swipe. Doc: "The row is fixed when the swipe begins" (`Core/Switcher.swift:3`).

### 3. Move (`Core/Launcher.swift:349-353`)
```swift
case .moved(let travel):
    guard case .apps(var open)? = shown, open.trackpad == event.trackpad else { return }
    let crossed = open.selection.follow(travel)
    shown = .apps(open)
    for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
```
- Copy-mutate-write of the whole `Switcher` value into `shown` every move → one `@Observable` mutation per event.
- `SwitcherSelection.follow(_:)` (`Core/SwitcherSelection.swift:23-35`) clamps travel to `[-band, last + band]`, resets overshoot
  on the turn, returns `abs(selected - before)`; one light tick per item crossed.
- `selected` = round(travel/12) clamped (`:39-42`); `position` = travel/12 clamped (`:46`); `stretch` saturating rubber band (`:50-54`).

### 4. End / cancel / reconcile
- `.ended` (`Core/Launcher.swift:354-365`): `shown = nil` first; if `open.selectsFrontmost` → silent return; else re-read
  `system.runningApps()`, if the target quit → silent; else `playFeedback(.gesture)`, `system.bringToFront(open.selectedApp)`,
  `hideOtherApps(than:)`.
- `.cancelled` (`:366-367`): `shown = nil` if it's this trackpad's apps switcher.
- `reconcile()` sets `shown = nil` whenever it re-runs the trackpads (`:276-277`) — ends any switcher mid-swipe.
- So the `Switcher` value lives exactly from `.began` to `.ended/.cancelled/reconcile`. Nothing survives to the next swipe; the
  next swipe re-reads the order (`CoreTests/SwitcherOnScreenTests.swift:104`).

### 5. Model → view (`SwitcherPresenter.render`, `UI/SwitcherPresenter.swift:112-127`)
```swift
private func render(_ switcher: Switcher?) {
    guard let switcher else { panel.dismiss(); return }
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if !panel.isPresented || switcher.row != laidOutRow { open(switcher.row) }
    let selection = switcher.selection
    panel.show(position: CGFloat(selection.position), selected: selection.selected, animatesSize: !reduceMotion)
    if selection.stretch != lastStretch, selection.stretch != 0, !reduceMotion {
        panel.springHighlight(from: CGFloat(selection.stretch) * layout.pitch)
    }
    lastStretch = selection.stretch
}
```
- The view consumes the `Switcher` value itself (Core type), via the Swift 6.2 `Observations` async sequence over
  `launcher.switcher`. The presenter "holds nothing the model holds" (`:5`) but caches `laidOutRow`, `layout`, `lastStretch` (`:18-20`).
- The re-layout trigger is `!panel.isPresented || switcher.row != laidOutRow` — there is no per-swipe serial on `Switcher`.
- `open(_ row:)` (`:129-138`): screen under `NSEvent.mouseLocation`; `layout = SwitcherRowLayout(iconCount: row.count, displayWidth: screen.frame.width)`;
  `panel.layoutRow(row.map { icons.icon(forSwitcher: $0) }, layout:, on: screen.frame, scale: screen.backingScaleFactor ?? 2)`;
  `laidOutRow = row`; `lastStretch = 0`; `panel.present(appear: nil)` — the app switcher has no appear animation (the window
  switcher passes an `OverlayAppear`, `UI/WindowSwitcherPresenter.swift:72-77`).

### 6. Panel drawing (`UI/SwitcherPanel.swift`)
- `func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat)` (`:32-61`):
  sets the window frame centred on the screen (`setFrame(…, display: false)`), `content.frame`, `iconsHost.frame = content.bounds`,
  highlight size and y; then inside `CATransaction` with actions disabled: removes all old `iconLayers` and builds one `CALayer`
  per image: `bounds` = `iconSide` square, `position = (layout.centreX(at: index), layout.centreY)`, `contents =
  image.cgImage(forProposedRect: 80×scale square…)`, `contentsScale = scale`, `minificationFilter = .trilinear`, added to
  `iconsHost.layer`. Then `invalidateShadow()`.
- `func show(position: CGFloat, selected: Int, animatesSize: Bool)` (`:65-79`): (a) highlight x set with actions disabled
  (`highlight.frame.origin.x = layout.centreX(at: position) - highlightSide/2` — an `NSView.setFrame` on the glass view per event);
  (b) a second transaction with `setDisableActions(!animatesSize)` and `setAnimationDuration(0.12)` sets every icon layer's
  `transform = CATransform3DMakeScale(s, s, 1)` with `s = 1.12` for `selected`, else 1. This is the "grow": an **implicit**
  Core Animation action (0.12 s, default timing) on standalone `CALayer`s, about each layer's centre (default anchor 0.5,0.5).
  Every layer's transform is re-set on every call, even unchanged ones.
- `func springHighlight(from offset: CGFloat)` (`:83-94`): additive `CASpringAnimation` on `position.x` of the highlight's layer
  (mass 1, stiffness 420, damping 22, `duration = settlingDuration`), keyed `"stretch"` so each replaces the last.
- Hide: `OverlayPanel.dismiss()` (`UI/OverlayPanel.swift:96-119`): 150 ms opacity fade on `contentView.layer` (at once with
  Reduce motion), then `orderOut` + `emptied()` from the completion if no present happened meanwhile (generation check).
  `SwitcherPanel` does not override `emptied()` — its icon layers stay in `iconsHost` until the next `layoutRow` replaces them
  (the window switcher's panel does override it, `UI/WindowSwitcherPanel.swift:93`).

### 7. Geometry (`Core/SwitcherRowLayout.swift`)
- Constants (`:8-13`): `fullIconSide = 80.0`, `fullIconGap = 20.0`, `fullHighlightSide = 92.0`, `padding = 22.0`, `selectedIconScale = 1.12`.
- `init(iconCount: Int, displayWidth: Double)` (`:19-26`): `scale = min(1, (displayWidth - 2*padding) / fullSpan(iconCount))`,
  1 when `displayWidth <= 0`. `fullSpan = (n-1)*(80+20) + 92` (`:29-31`).
- `iconSide`, `iconGap`, `pitch`, `highlightSide` scale by `scale`; `padding` does NOT (`:33-37`).
- `panelSize = (2*22 + fullSpan*scale, 2*22 + highlightSide)` (`:39-41`) — at full size the panel is 136 pt tall.
- `centreX(at position: Double) = 22 + highlightSide/2 + position*pitch` (`:44-46`); `centreY = panelSize.height/2` (`:49`).
- Vertical budget at full size (derived): panel 136 pt, centre 68; icon top 108 (28 pt below the panel's top edge); selected
  icon (89.6 pt) top 112.8 (23.2 pt below the top); highlight top 114 (22 pt). The panel's rounded clip has radius 34
  (`UI/SwitcherPanel.swift:8`, `UI/GlassClip.swift:9-11`) and `masksToBounds = true`, so anything drawn above ~136 or into the
  corner arcs is cut. iconsHost's coordinate space is a non-flipped layer-backed NSView (y up), so "above" = larger y.

### 8. Icons (`UI/AppIcons.swift`)
- Cache `private var cache: [URL: Rendered]` (`:27`), `Rendered { icon: NSImage, stamp: Stamp(modified: Date?, appearance: NSAppearance.Name) }` (`:11-19`).
- `func icon(forSwitcher app: AppEntry) -> NSImage` (`:53-67`): hit when cached in the current appearance (does not re-check the
  Info.plist stamp); else the running app's already-loaded `NSRunningApplication.icon` (matched by bundle ID + `bundleURL == app.url`),
  drawn into an 80 pt bitmap on the main actor (~0.1 ms per the comment) and cached; else a synchronous `renderChanged` on the main actor.
- `bitmap(of:side:appearance:)` (`:137-157`) draws 1x and 2x `NSBitmapImageRep`s; the panel then asks `cgImage(forProposedRect:)`
  for an `80 × backingScale` rect, so it picks the 2x rep on Retina.
- Passes, owned by `SwitcherPresenter` (`UI/SwitcherPresenter.swift:44-110`), only while the swipe setting is on:
  start (synchronous `renderOnMainActor` when `waiting`, else off-main), `didLaunchApplicationNotification` → off-main pass for that
  app, `didTerminateApplicationNotification` → `evict` unless another copy still runs, `NSApp.effectiveAppearance` KVO → redraw all;
  off-main passes go through `@concurrent renderChangedOffMain` + `DispatchQueue.concurrentPerform` (`:109-129`) and are dropped if
  `removeAll()` bumped `generation` meanwhile (`:84-92`). `stopIconPasses()` removes observers and empties the cache (`:70-76`).
- The icon images reach the view only as `[NSImage]` passed to `layoutRow` at open; layers hold a `CGImage` in `contents`.

### 9. Haptics
- Light tick per item crossed during moves (`Core/Launcher.swift:353`), gesture haptic on a lift that brings an app forward (`:363`).
- Real: `MultitouchTrackpads.playFeedback` → `actuatorActuate(actuator, actuation(for:), 0,0,0)`; `.gesture` = 6, `.lightTick` = 3
  (`Platform/MultitouchTrackpads.swift:121-134`).

### 10. Reduce motion (app switcher)
- Read fresh at every `render` (`UI/SwitcherPresenter.swift:119`): disables the 0.12 s grow (`animatesSize: !reduceMotion`) and the
  highlight spring. `OverlayPanel.dismiss()` reads it itself and removes at once (`UI/OverlayPanel.swift:100`). `present(appear: nil)`
  has no appear animation in either mode.

## Module ownership
- `LauncherCore` (Foundation + Observation only): `Switcher`, `SwitcherSelection`, `SwitcherRowLayout`, `GestureRules`, `AppEntry`,
  `RunningApps`, `Launcher`, the ports. All selection/row/geometry policy is here.
- `LauncherPlatform`: `RunningAppsReader`, `LaunchServicesOrder`, `RunningApp`, `WorkspaceActions`, `MultitouchTrackpads`
  (haptics), `FrontmostAppWindows` (the Accessibility read).
- `LauncherUI` (main-actor default isolation, `LauncherKit/Package.swift:19-23`): `SwitcherPresenter`, `SwitcherPanel`,
  `OverlayPanel`, `roundedClip`, `AppIcons`, `Displays`, `SettingsShell`. AppKit windows/views + plain `CALayer`s + Core
  Animation; no SwiftUI anywhere in the switcher (`SwitcherSection.swift` is only the settings form's toggles).
- App target: composition only (`TrackpadLauncher/TrackpadLauncherApp.swift:78-92`).

## Tests and seams
- Pure Core tests:
  - `CoreTests/SwitcherTests.swift` constructs `Switcher(frontmost:running:leavingOut:trackpad:)` and `SwitcherSelection(count:)`
    directly (package access; `travelMM` is `package(set)`): cap of 10 (`:31-35`), frontmost first (`:82-88`), frontmost outside
    running at left end (`:90-95`), identity by location (`:97-101`), nil when nothing else (`:103-108`), selection rounding,
    rubber band and stretch (`:37-147`).
  - `CoreTests/SwitcherRowLayoutTests.swift:4-85`: 100 pt pitch, 536×136 for five icons, 22 pt on all four sides, shrink at
    1035 vs 1036 pt, `selectedIconScale == 1.12` and 89.6 ≤ 92, non-positive width = no constraint.
- Model-through-hardware tests (`World`):
  - `CoreTests/SwitcherOnScreenTests.swift` (row/selection/ticks/lift/cancel/reconcile/second trackpad, e.g. `:58-69`, `:505-523`)
    and `CoreTests/SwitcherAssignedAppsTests.swift` (exclusions). They drive real `GestureRecognizer`s through
    `InMemoryTrackpads.touch` / `World.swipe(_:lift:)` (`CoreTests/World.swift:374-383`) and read `world.launcher.switcher`.
  - Fakes: `InMemoryTrackpads` records `pulses` (`lightTicks`, `feedback`) (`CoreTests/InMemoryAdapters.swift:6-89`);
    `RecordingSystemActions` answers `runningApps()` from settable `frontmost` / `running` (`:275-311`) and `frontmostWindows()`
    from `FakeWindows` (`:313-316`, `:392-473`), which models only the *frontmost* app's windows (`answers = false` models a
    non-answering app). `World.makeRunning` / `makeFrontmost` / `switcherWorld` (`CoreTests/World.swift:232-266`).
  - Platform: `LauncherKit/Tests/LauncherPlatformTests/RunningAppsReaderTests.swift` (the reader alone, via its `order:` seam).
- No test covers `SwitcherPresenter`, `SwitcherPanel`, `OverlayPanel` or `AppIcons` (grep of `LauncherKit/Tests` finds none).
  `LauncherUITests` exists (`AppPickerTests`, `PickAnimationRuleTests`, benches) and reads back Core Animation keyframes for the
  pick animation (plan 023 dev log), so a layer-level test precedent exists in that target.
- `CoreTests/SourcePolicyTests.swift` bans `Timer`, `asyncAfter`, `Task.sleep`, `displayLink`/`DisplayLink`,
  `makeTimerSource`, `DispatchSourceTimer` (`:52-58`) and confines `AXUIElement` and `CGWindowList` to
  `FrontmostAppWindows.swift` and `LaunchWatch.swift` (`:172-173`), `_LSCopy…` to `LaunchServicesOrder.swift` (`:166-171`).

## Boundaries
- In: `SwipeEvent` from `TrackpadHardware.onEvent` (main actor); `SystemActions.runningApps()` at begin and end;
  `settings.assignedBundleIDs`; the pointer's screen and Reduce motion read by the presenter.
- Out: `launcher.switcher: Switcher?` (observed by `SwitcherPresenter`); `hardware.playFeedback`; `system.bringToFront`,
  `system.hideOtherApps`.
- The presenter reads AppKit directly (`NSEvent.mouseLocation`, `NSScreen`, `NSWorkspace` notifications,
  `accessibilityDisplayShouldReduceMotion`, `NSRunningApplication.icon`) — never through a port.

## Non-Obvious Things
1. **`switcher.row != laidOutRow` is the re-layout trigger** (`UI/SwitcherPresenter.swift:120`). `open` tears down every icon
   layer (`UI/SwitcherPanel.swift:46`) and re-presents. Any per-app data folded into `row` (e.g. a count inside the row's element
   type) that changes mid-swipe would rebuild all layers and kill any in-flight animation; it would also call `present` again. Data
   arriving mid-swipe has to sit beside `row` (or the trigger has to change to a per-swipe identity).
2. **No per-swipe identity on `Switcher`.** The window switcher has `serial` (from `windowSwipesBegun`, `Core/Launcher.swift:70, 381-386`)
   and lays out once per serial (`UI/WindowSwitcherPresenter.swift:17-18, 47`). The app switcher distinguishes "new swipe" only
   by `!panel.isPresented` (false from `dismiss()` on, even while fading) or a different row. A "rise once per swipe" needs a
   reliable new-swipe signal; today a new swipe is detectable because the previous one always went through `shown = nil` →
   `render(nil)` → `dismiss()` → `isPresented = false`. If `Observations` ever coalesced a nil→non-nil pair, a same-row new swipe
   would not be detected (see Open Questions).
3. **Every `shown` write is an observation.** `launcher.switcher` is a computed property over `shown` (`Core/Launcher.swift:14-16`),
   so window-swipe frames also wake `SwitcherPresenter.render(nil)` (cheap: `dismiss()` is a no-op when not presented,
   `UI/OverlayPanel.swift:97`). Each async count arrival written into `shown` would trigger a full `render`: `show()` re-sets the
   highlight frame and every icon transform with a 0.12 s implicit action. Harmless, but the per-arrival render path is the
   whole `render`, not a targeted update.
4. **`show()` sets the transform on every layer in `iconLayers` by index.** If stack copies became extra entries in `iconLayers`,
   they'd be scaled independently and indices would no longer equal row indices. A stack that "grows with" the selected icon
   (plan R5) needs the copies grouped under the front icon's transform (e.g. a per-app container layer whose transform `show` sets),
   or copies as sublayers of the icon layer. Note `contents` + `bounds` on the icon layer itself; sublayers of it would be scaled by
   its transform about its centre.
5. **The grow is an implicit action**, not an explicit animation: `CATransaction.setDisableActions(!animatesSize)` +
   `setAnimationDuration(0.12)`. Any new explicit animation added on the same layer's `transform` key would be fought by this
   per-event implicit action; a rise animation should animate a different key/layer (e.g. the copies' `position`/`transform` within
   a container) so the selection's implicit transform action doesn't replace it. `docs/performance.md:78` records that skipping
   unchanged transforms was rejected because it "would likely change the icon-grow animation".
6. **The panel's height is fixed by the highlight**, `2*22 + highlightSide` (`Core/SwitcherRowLayout.swift:40`), and the content is
   clipped by a 34 pt continuous-corner `masksToBounds` layer (`UI/GlassClip.swift:9-11`). At full size an icon's top is 28 pt below
   the panel's top; the selected icon's is 23.2 pt. Plan R5 keeps the panel size unchanged, so copies peeking up to ~18 pt above the
   front icon, scaled ×1.12 about the icon's centre when selected, land about 3 pt from the top edge (68 + (40+18)×1.12 ≈ 133 of 136),
   and the first/last icon's copies come near the 34 pt corner arcs. Worth checking against the clip; shrink `scale` reduces everything
   except the 22 pt padding.
7. **Copies can reuse the icon's `CGImage`.** One bitmap per app is already produced (`AppIcons.icon(forSwitcher:)`), and the layer
   uses `.trilinear` minification, so 92/84/76 % copies need no extra drawing.
8. **The model never sees pids.** `LaunchServicesOrder` asks for `"pid"` (`Platform/LaunchServicesOrder.swift:20`) but `entries`
   drops it (`:46-55`); `AppEntry` has `bundleID`, `name`, `url` only. A per-app Accessibility read needs a pid: the platform side must
   map `AppEntry.url` back to a process (as `AppIcons.icon(forSwitcher:)` does: `runningApplications(withBundleIdentifier:)` +
   `bundleURL == app.url`, `UI/AppIcons.swift:56-57`), or the read must carry it inside the adapter.
9. **Timers are banned and AX is confined.** No `Timer`/`asyncAfter`/`Task.sleep` (`CoreTests/SourcePolicyTests.swift:52-58`;
   `docs/architecture.md:20`: "Time passes only on Core Animation's clock … a deadline is an animation on a layer of the effect it
   belongs to, its completion is the push"). The existing 0.2 s bound is the process-wide AX messaging timeout, set once on the
   system-wide element (`Platform/FrontmostAppWindows.swift:15, 34`) — a per-app 0.2 s deadline can ride on that timeout rather than a
   timer. Any new window-reading code must live in `FrontmostAppWindows.swift` or `LaunchWatch.swift` or the confinement list changes.
   Off-main work precedent: `@concurrent` static functions (`FrontmostAppWindows.warmWindowList`, `AppIcons.renderChangedOffMain`).
10. **Async-delivering adapters sit behind ports so model tests stay synchronous** (`docs/architecture.md:14`); precedents are
    `AppScanner.onScan` and `SystemActions.onLaunchProgress` pushes (`Core/Ports.swift:125, 158-163`). The window switcher's
    previews are the counter-precedent: async data kept entirely in `LauncherUI` (capture `Task` guarded by `shownSerial`,
    `UI/WindowSwitcherPresenter.swift:82-99`), never in the model.
11. **Per-event code is allowed only while the effect is on screen** (`docs/architecture.md:21`): "Code may run per input event while
    the effect it serves is on screen: the switchers' highlight on trackpad frames". A rise animation must be Core Animation keyframes
    / implicit actions played by the render server, cleaned up from completion; no per-display-frame code.
12. **Row identity quirks**: the frontmost app is matched by URL, exclusions by bundle ID; two copies of one bundle are two icons
    (`Core/Switcher.swift:17-21`, `CoreTests/SwitcherOnScreenTests.swift:88`). Per-app counts keyed by `bundleID` would collide for two
    copies; keyed by `url` (or row index) they would not. `AppEntry.id` is the bundleID (`Core/Apps.swift:17`), so `Identifiable`
    identity is not unique across copies.
13. **The frontmost app may be absent from `running.apps`** (a menu bar app with a window in front) and may be Trackpad Launcher
    itself; `FrontmostAppWindows.read()` returns no windows for Trackpad Launcher (`Platform/FrontmostAppWindows.swift:50-52`).
14. **First-frame icon cost**: icons are normally cached by the presenter's passes; the frontmost app takes the running-app path at
    the swipe's first frame (`UI/AppIcons.swift:51-52`). With the swipe setting off the cache is empty and no observers run.

## Files Read
- `LauncherKit/Sources/LauncherCore/Switcher.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherRowLayout.swift`
- `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift`
- `LauncherKit/Sources/LauncherCore/Launcher.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Apps.swift`
- `LauncherKit/Sources/LauncherCore/GestureRules.swift` (lines 20-41)
- `LauncherKit/Sources/LauncherCore/Settings.swift` (grep, lines 43-51)
- `LauncherKit/Sources/LauncherCore/Gesture.swift` (lines 34-56)
- `LauncherKit/Sources/LauncherCore/GestureRecognizer.swift` (grep, lines 84-94, 208-212)
- `LauncherKit/Sources/LauncherCore/Lifecycle.swift` (lines 250-270)
- `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift`
- `LauncherKit/Sources/LauncherPlatform/RunningApp.swift`
- `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift`
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (lines 92-135)
- `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` (lines 80-90)
- `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift` (lines 1-60, grep)
- `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift`, `AnimationTuner.swift` (grep for swipe)
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift`
- `LauncherKit/Sources/LauncherUI/GlassClip.swift`
- `LauncherKit/Sources/LauncherUI/AppIcons.swift`
- `LauncherKit/Sources/LauncherUI/Displays.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherSection.swift`
- `LauncherKit/Sources/LauncherUI/SettingsShell.swift` (lines 1-95)
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift` (grep of functions)
- `LauncherKit/Package.swift`
- `TrackpadLauncher/TrackpadLauncherApp.swift` (lines 70-100)
- `LauncherKit/Tests/LauncherCoreTests/SwitcherTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift` (lines 1-70, 505-541, test list)
- `LauncherKit/Tests/LauncherCoreTests/SwitcherAssignedAppsTests.swift` (test list)
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (lines 1-90, 270-473)
- `LauncherKit/Tests/LauncherCoreTests/World.swift` (lines 225-384)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (lines 1-200)
- `docs/architecture.md` (lines 10-25), `docs/domain-model.md` (Swipe, Switcher, Running apps, Frontmost app), `docs/performance.md` (lines 50-80)
- `plans/023-app-selection-grow-animation/plan.md` and `development-logs.md`
- `plans/042-window-stacks-switcher-order/plan.md` (outline, R4-R7), `development-logs.md`
- `plans/013-simplify-switchers/plan.md` (grep)

## Open Questions
- **`Observations` coalescing.** Each recognised event is its own `DispatchQueue.main.async` block; whether the `Observations`
  iterator task always runs between consecutive blocks (one render per event) or sometimes coalesces several `shown` writes into one
  emission was not verified. If it can coalesce `nil` then a new non-nil, a same-row back-to-back swipe would not be re-laid out
  (`!panel.isPresented` would still be true from the earlier swipe only if `render(nil)` ran). A per-swipe serial would remove the doubt.
- **Implicit action on same-value sets.** Whether re-setting an unchanged `transform` each event adds a fresh 0.12 s implicit
  animation (and so would interact with a container/copy animation) was not measured; `docs/performance.md:78` only says skipping them
  "would likely change" the grow.
- **Clip margin for peeking copies** in the rounded 34 pt corners at the row ends was computed on paper only (see Non-Obvious 6), not
  probed.
- I did not trace the Accessibility read itself (another explorer's slice) beyond the timeout and confinement facts above.
