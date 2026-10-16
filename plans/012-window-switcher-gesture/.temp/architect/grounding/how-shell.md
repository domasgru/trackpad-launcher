# How the on-screen shell works (LauncherUI, the launch overlay, the composition root)

Paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/012-window-switcher-gesture`. `K/` = `LauncherKit/`.

## Components Found

- **`MenuBarShell`** (`K/Sources/LauncherUI/MenuBarShell.swift:12`): the only `public` type in LauncherUI (`public final class MenuBarShell: NSObject`, `public init(launcher:)` :22). Owns the status item, the 16 pt `AppIcons`, the `LauncherPanel`, and the `SwitcherPresenter`. It maps AppKit signals to `Launcher` intents and renders `Launcher` state through `Observations` loops.
- **`LauncherPanel`** (`K/Sources/LauncherUI/LauncherPanel.swift:6`): the launcher window. An `NSPanel` that is borderless, non-activating and can become key, hosting `LauncherView` in an `NSHostingView` inside an `NSGlassEffectView`.
- **`LauncherView`** (`K/Sources/LauncherUI/LauncherView.swift:7`): the SwiftUI content. Five `GestureRowView`s, `SwitcherSection`, `HandModeToggle`, `LaunchAnimationSwitch`, a `Divider`, then `HintText` or `SettingsNotice` (trackpad settings notice), the Accessibility `SettingsNotice`, and Quit.
- **`SwitcherSection`** (`K/Sources/LauncherUI/SwitcherSection.swift:6`): two `HStack` rows (an illustration, a title and a `Toggle(.switch)`) bound to `launcher.isSwipeOn`/`setSwipe(on:)` and `launcher.isSwapOn`/`setSwap(on:)`.
- **`SettingsNotice`** (`LauncherView.swift:161-175`): a message plus one bordered capsule `Button` with an `open` closure. The trackpad settings notice and the Accessibility hint both use it.
- **`HintText`** (`LauncherView.swift:139-158`): renders `launcher.gestureHint` and draws `●`/`◉` as template images.
- **`LauncherActions` / `SettingsPane`** (`K/Sources/LauncherUI/LauncherActions.swift`): a struct of AppKit-only closures the views call (`cachedIcon`, `icon`, `chooseOtherApp`, `openSettings`, `quit`). `SettingsPane` has two cases, `.trackpad` and `.accessibility`, each with an `x-apple.systempreferences:` URL (:5-16).
- **`AppMenuButton`** (`K/Sources/LauncherUI/AppMenuButton.swift:8`): an `NSViewRepresentable` `NSPopUpButton`. Its menu is rebuilt in `menuNeedsUpdate` from values already in memory. It has nothing to do with the switcher.
- **`StatusIcon`** (`K/Sources/LauncherUI/StatusIcon.swift:5`): the `hand.tap` SF Symbol template, with a knocked-out slash when gestures are inactive.
- **`SwitcherPresenter`** (`K/Sources/LauncherUI/SwitcherPresenter.swift:11`): renders `launcher.switcher` into one `SwitcherPanel`. It owns the 80 pt `AppIcons` cache and the workspace and appearance observers that keep that cache current. It holds nothing the model holds.
- **`SwitcherPanel`** (`K/Sources/LauncherUI/SwitcherPanel.swift:8`): the switcher's `NSPanel`. A Liquid Glass body holds one icon `CALayer` per app, a glass highlight view, and one centred name label.
- **`roundedClip(_:cornerRadius:)`** (`K/Sources/LauncherUI/GlassClip.swift:6`): wraps an `NSGlassEffectView` in a layer-backed view that is corner-rounded (continuous) and `masksToBounds`, so the window shadow follows the rounded edge. Both panels use it.
- **`AppIcons`** (`K/Sources/LauncherUI/AppIcons.swift:10`): a square bitmap icon cache keyed by app URL. Each entry is stamped with its bundle's Info.plist modification date and the appearance name. It has main-actor and off-main (`@concurrent`) passes and a switcher-specific lookup.
- **`SwitcherRowLayout`** (`K/Sources/LauncherCore/SwitcherRowLayout.swift:6`): pure geometry in **LauncherCore**, not UI. It gives icon side, gap, pitch, highlight side, panel width and `centreX(at:)` for a horizontal row on a display of a given width, shrinking by one factor.
- **`Switcher`** (`K/Sources/LauncherCore/Switcher.swift:6`): the model value the presenter renders (`row`, `selected`, `selectedApp`, `position`, `stretch`, `trackpad`).
- **`LaunchOverlay`** (`K/Sources/LauncherPlatform/LaunchOverlay.swift:10`): `@MainActor` class. It creates one throwaway click-through panel per launch animation play, at the pointer.
- **`LaunchFlight` / `LaunchFlights` / `LaunchDisplay` / `LaunchStage`** (`K/Sources/LauncherPlatform/LaunchFlight.swift`): pure staging of the launch animation's keyframes and of the panel frame on the pointer's display.
- **`WorkspaceActions`** (`K/Sources/LauncherPlatform/WorkspaceActions.swift:5`): the real `SystemActions` adapter. It owns the `LaunchOverlay` (created in `init`, :9-11) and forwards `prepareLaunchAnimations`/`playLaunchAnimation` to it (:28-34).
- **`TrackpadLauncherApp`** (`TrackpadLauncher/TrackpadLauncherApp.swift:7`): the `@main` composition root.

## Flow

### A. Composition root: `TrackpadLauncherApp.main()` (`TrackpadLauncher/TrackpadLauncherApp.swift:8-26`)
1. `NSApplication.shared` (:9). There is no app delegate. The app has no Dock icon because of `LSUIElement: true` in the generated Info.plist (`project.yml:39`).
2. `AppCatalog.system` (:10; defined at `K/Sources/LauncherPlatform/AppCatalog+System.swift:7-18`).
3. `WorkspaceActions()` (:11). Its `init` creates the `LaunchOverlay`. `LaunchOverlay.init` creates a 1x1 panel and closes it at once, to pay the process's first window-server window cost (about 27 ms, against 1 ms afterwards) before any gesture (`LaunchOverlay.swift:17-21`).
4. `Launcher(hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), access: SystemAccessibilityPermission(), system:, catalog:, scanner: SystemAppScanner(catalog:), store: SettingsStore(defaults: .standard))` (:12-19). `Launcher.init` runs `catalog.installedApps()` synchronously, which is the "first scan, waited for" (`K/Sources/LauncherCore/Launcher.swift`, `init`: `installedApps = catalog.installedApps()`). It then loads the settings with `store.load()` and builds the rows.
5. `MenuBarShell(launcher:)` (:20). It must come before `launcher.start()` because a first-launch window needs the status item as its anchor (doc comment at `MenuBarShell.swift:7`). Inside it, in order (`MenuBarShell.swift:22-66`):
   - `NSStatusBar.system.statusItem(withLength: .squareLength)` (:24).
   - `icons.renderOnMainActor(Self.iconTargets(launcher))` (:25). This is the 16 pt picker icon pass over every installed app plus the present row apps, waited for.
   - `makeActions` (:26), then `LauncherPanel(content: LauncherView(...))` (:27).
   - `SwitcherPresenter(launcher:)` (:28). If `launcher.isSwipeOn`, it runs `startIconPasses(waiting: true)`: the 80 pt icons of every running Dock app, drawn on the main actor and waited for (`SwitcherPresenter.swift:27`, :49-50).
   - `super.init()`. Then the status button image, target and action, `panel.onCancel` → `launcher.closeWindow()`, `panel.onResignKey` → `resignedKey()` (:31-35).
   - An `NSWindow.didMoveNotification` observer on the status item's window, which calls `refit()` (:37-41).
   - Four `Observations` loops (:42-65), covered in section B.
6. `launcher.start()` (:21). It wires `hardware.onEvent`, `scanner.onScan`, `preferences.onChange` and `access.onChange`, calls `scanner.scan()` (asynchronous), `reconcile()` (which runs the trackpads) and, on first launch, `registerLoginItem`, `access.prompt()` and `window = .heldOpen`/`.open`, then `resolveRows()` (`Launcher.swift`, `start()`).
7. `#if DEBUG system.showAnimationTuner()` (:22-24).
8. `withExtendedLifetime(shell) { application.run() }` (:25). The shell, and with it the presenter and both panels, lives for the whole process. Nothing else retains the shell.

The architecture doc states that the first scan and the first icon pass are waited for before the run loop starts. These are, respectively, step 4 (`catalog.installedApps()` inside `Launcher.init`) and step 5 (`renderOnMainActor` in `MenuBarShell.init`, plus `SwitcherPresenter.init` when the swipe is on).

### B. How the shell observes the model
Every view-model link uses the Observation module's `Observations { ... }` async sequence, iterated in a `Task` stored in `observations: [Task<Void, Never>]`. It is not `withObservationTracking` and not a callback from the model.
- `MenuBarShell.swift:44-47`: `launcher.activity.isActive` → status icon image.
- `MenuBarShell.swift:50-53`: `(launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn)` → `refit()`, so the window resizes when the notice, the Accessibility hint or the hint's swipe clause appears or goes away.
- `MenuBarShell.swift:56-59`: `launcher.installedApps` → `renderIcons()` (off-main 16 pt pass).
- `MenuBarShell.swift:62-65`: `launcher.isWindowOpen` → `show()` / `hide()`.
- `SwitcherPresenter.swift:29-31`: `launcher.switcher` → `render(_:)`.
- `SwitcherPresenter.swift:33-37`: `launcher.isSwipeOn` → `startIconPasses(waiting: false)` / `stopIconPasses()`.
- SwiftUI views read `launcher` directly (`@Observable`) and send intents through `Binding(get:set:)` closures (`SwitcherSection.swift:20,34`; `LauncherView.swift:112,131`).
- Plan 006's design (`plans/006-five-finger-tap-and-corner-swipe/plan.md:646`) says `Observations` "coalesces to the latest value per main-actor turn, a natural back-pressure at ~100 Hz". The presenter therefore sees only the latest `Switcher` per turn, not every frame.
- Each `Observations` sequence also emits its current value once at start. For `isSwipeOn`, the first emission calls `startIconPasses(waiting: false)`, which does nothing because `workspaceObservers` is already non-empty (guard at :48). With the swipe off, the first emission calls `stopIconPasses()`, which is harmless. For `switcher`, the first emission is `nil`, and `hide()` returns at its `guard isShown` (:148).

### C. The switcher panel: construction (`SwitcherPanel.init`, `SwitcherPanel.swift:26-57`)
- `NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)` (:27-28).
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`, `ignoresMouseEvents = true`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `animationBehavior = .none`, `isReleasedWhenClosed = false` (:29-37).
- `override var canBecomeKey: Bool { false }` and `canBecomeMain { false }` (:59-60). `becomesKeyOnlyIfNeeded` is **not** set anywhere, and neither is `worksWhenModal`.
- View tree: outer `NSGlassEffectView` (`style = .regular`, `cornerRadius = 34`, :52-55) whose `contentView = content`. `content` is a layer-backed `NSView` holding, in z-order, `highlight` (an `NSGlassEffectView`, `style = .clear`, `cornerRadius = 24`, layer-backed, :41-43), `iconsHost` (a layer-backed `NSView` for the icon `CALayer`s), and `name` (an `NSTextField(labelWithString:)`, centred, 13 pt medium, `labelColor`, `byTruncatingTail`, :44-47). The panel's `contentView` is `roundedClip(glass, cornerRadius: 34)` (:56).
- The doc comment (:5-7) says this is "the launch overlay's configuration (borderless, non-activating, click-through, above everything on every Space, never key) around Liquid Glass." The configuration matches `LaunchOverlay.makePanel` line for line, apart from `hasShadow` (overlay: `false`), `defer` (overlay: `false`) and the never-key overrides (overlay: a plain `NSPanel` with no overrides).
- The presenter creates the panel as a stored property (`private let panel = SwitcherPanel()`, `SwitcherPresenter.swift:13`) when `MenuBarShell.init` runs. The presenter's doc comment (:7) says this is "so a swipe never pays the first window's cost". The panel uses `defer: true`, though, so its window-server window is created on the first `orderFrontRegardless`. The process-wide first-window cost is paid earlier, by `LaunchOverlay.init` (step A3).

### D. The switcher panel: open, per-update and close (`SwitcherPresenter.render`, :117-131)
1. `render(nil)` → `hide()` (:118-121).
2. `render(switcher)`: reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (:122). If the panel is not shown, or `switcher.row != laidOutRow`, it calls `open(switcher.row)` (:123). The row is fixed for a swipe, so in practice this lays out once per swipe.
3. `open(_:)` (:133-145):
   - `Self.screen(under: NSEvent.mouseLocation)` (:134; :165-169) uses `NSMouseInRect(pointer, $0.frame, false)`, or the nearest display by distance (:171-175). This copies `LaunchFlight.display(for:among:)` (`LaunchFlight.swift:132-141`). LauncherUI cannot import LauncherPlatform (see Boundaries).
   - `SwitcherRowLayout(iconCount: row.count, displayWidth: screen.frame.width)` (:135).
   - `panel.layoutRow(row.map { icons.icon(forSwitcher: $0) }, layout:, on: screen.frame, scale: screen.backingScaleFactor)` (:136-138). Icons are fetched synchronously here, in the same turn as the first frame.
   - Sets `laidOutRow`, `lastStretch = 0`, `isShown = true`, `fadeGeneration += 1`, then `panel.restoreOpacity()`, then `panel.orderFrontRegardless()` (:139-144).
4. `SwitcherPanel.layoutRow` (`SwitcherPanel.swift:89-123`):
   - Panel size: width is `layout.panelWidth`. Height is `bottomPadding(18) + nameHeight(18) + nameGap(10) + layout.highlightSide + topPadding(22)` (:91-93).
   - **Position: centred on `screen` (the full `NSScreen.frame`, not `visibleFrame`)**: `x = screen.midX - w/2, y = screen.midY - h/2` (:94-96).
   - `name` frame spans the width minus `SwitcherRowLayout.padding` on each side, at y = 18 (:100-102). The highlight is sized `highlightSide` square at `rowY` (:103-104).
   - Inside a `CATransaction` with actions disabled, it removes the old icon layers and creates one `CALayer` per image, sized `layout.iconSide` and positioned at `(layout.centreX(at: index), rowY + highlightSide/2)`. Each layer's `contents` is `image.cgImage(forProposedRect:)` at `80 × scale` pixels, with `contentsScale = scale` and `minificationFilter = .trilinear` (:106-121). It then calls `invalidateShadow()` (:122).
5. `panel.show(position:selected:name:animatesSize:)` (`SwitcherPanel.swift:127-142`), called on every render:
   - **Highlight follows continuously, not animated**: `highlight.frame.origin.x = layout.centreX(at: position) - highlightSide/2` inside a `CATransaction` with actions disabled (:128-131). `position` is a `Double` between icons (`Switcher.position`, `Switcher.swift:60`), so the highlight tracks the fingers.
   - Icon scale: a second transaction with `setDisableActions(!animatesSize)` and `setAnimationDuration(0.12)` sets each icon layer's `transform` to 1.12× (`selectedScale`, :9) for the selected one and 1× for the rest (:133-140). These are implicit Core Animation actions on standalone `CALayer`s. Under Reduce motion the change is instant.
   - `name.stringValue = selectedName` (:141). This is the running app's name from `switcher.selectedApp.name`.
6. The rubber band: when `switcher.stretch` changed and is non-zero, and Reduce motion is off, `panel.springHighlight(from: stretch * layout.pitch)` (`SwitcherPresenter.swift:127-130`). This adds an additive `CASpringAnimation` on `position.x` of the highlight's layer (mass 1, stiffness 420, damping 22, duration = `settlingDuration`, key `"stretch"`, so each one replaces the last) (`SwitcherPanel.swift:146-157`).
7. Close: `hide()` (`SwitcherPresenter.swift:147-162`). It sets `isShown = false`. Under Reduce motion it calls `orderOut` at once. Otherwise it bumps `fadeGeneration` and calls `panel.fadeOut(duration: 0.15)`, a `CABasicAnimation` on the content view layer's `opacity` to 0 with ease-out, whose model value is set to 0 and whose completion is set with `CATransaction.setCompletionBlock` (`SwitcherPanel.swift:63-75`). The completion orders the panel out only if `fadeGeneration` still matches, so a swipe that opened during the fade is not hidden. `restoreOpacity()` removes the `"fade"` animation and sets opacity back to 1 (:78-85).
8. Teardown: the panel is never closed or released. It is ordered out between swipes and reused. `SwitcherPresenter` has an `isolated deinit` that cancels the observation tasks and calls `stopIconPasses()` (:40-43), but in practice it lives as long as the process (step A8).

All animation is Core Animation, run by the render server. There is no SwiftUI animation, no display link and no timer. `Timer`, `asyncAfter`, `displayLink`/`DisplayLink` and `Task.sleep` are banned tokens in `SourcePolicyTests.swift:30-35`.

### E. Row geometry (`SwitcherRowLayout`, `K/Sources/LauncherCore/SwitcherRowLayout.swift`)
- Constants: `fullIconSide = 80`, `fullIconGap = 20`, `fullHighlightSide = 92`, `padding = 28` (:7-10).
- `scale = min(1, (displayWidth - 2*padding) / (n*80 + (n-1)*20))` when `displayWidth > 0`, else 1 (:16-24). One factor applies to the icons, the gaps and the highlight.
- `centreX(at:)` = `padding + iconSide/2 + position*pitch` (:35-37). Icons and highlight both go through it "so they cannot drift apart" (doc :5).
- The layout is horizontal-only and width-constrained only. The height does not take part.

### F. Icons for the switcher (`AppIcons`, `K/Sources/LauncherUI/AppIcons.swift`)
- The presenter's instance is `AppIcons(side: SwitcherRowLayout.fullIconSide)` = 80 pt (`SwitcherPresenter.swift:14`). The shell has a second instance at 16 pt for the pickers (`MenuBarShell.swift:14`).
- `init` draws a generic `.applicationBundle` icon as the miss fallback (:32-36).
- Bitmaps: `bitmap(of:side:appearance:)` draws an `NSImage` with two `NSBitmapImageRep`s, at 1x and 2x, under `appearance.performAsCurrentDrawingAppearance` (:134-154).
- `renderChanged` is nonisolated static. It uses `DispatchQueue.concurrentPerform` over the URLs with a `Mutex` for results and redraws only when a URL's `Stamp(modified: Info.plist mtime, appearance: name)` differs from the cached one (:113-126).
- `renderOnMainActor(urls:)` merges synchronously (:69-71). `renderOffMainActor(urls:) async` captures `generation` and calls a `@concurrent` static (:106-110). It drops the result if `removeAll()` bumped `generation` meanwhile (:81-89).
- `icon(forSwitcher:)` (:50-64) is the swipe-time lookup:
  1. Cache hit whose stamp's appearance equals the current `NSApp.effectiveAppearance.name`. The modification date is not checked here.
  2. Else the running copy's already-loaded `NSRunningApplication.icon` (matched by bundle ID and `bundleURL == app.url`), drawn on the main actor (the doc says about 0.1 ms) and cached.
  3. Else a synchronous main-actor `renderChanged` for that one URL.
- `SwitcherPresenter.startIconPasses(waiting:)` (:47-70) does the initial pass over `runningDockApps()` (`NSWorkspace.shared.runningApplications` with `.regular` activation policy and a `bundleURL`, location spelled by `AppEntry.location(ofBundleAtPath:)`, :105-113). It also adds two `NSWorkspace.notificationCenter` observers on `.main`:
  - `didLaunchApplicationNotification` → `pass(over: [location])`, off-main.
  - `didTerminateApplicationNotification` → `evict` unless another copy at that location is still running.
  It also adds a KVO on `NSApp.effectiveAppearance` → `redrawRunningApps()`. `pass(over:)` renders off-main, then, if still observing, calls `retainOnly(current running locations)` (:96-103).
- `stopIconPasses()` removes the observers, drops the KVO and calls `icons.removeAll()` (:73-79). With the swipe off, nothing is drawn or observed for the switcher.

### G. The launcher window
- `LauncherPanel.init` (`LauncherPanel.swift:12-28`):
  - `[.borderless, .nonactivatingPanel]`, `defer: true`.
  - Content is a glass `.regular` view with radius 26 hosting `NSHostingView<AnyView>`, wrapped in `roundedClip`.
  - `level = .popUpMenu`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]` (no `.stationary`), `hidesOnDeactivate = false`.
  - `canBecomeKey` true (:33). It does not ignore mouse events.
  - Escape → `onCancel` (:36). `resignKey` → `onResignKey` (:38-41).
- `fitToContent(centeredOn:topEdge:within:)` (:44-50) sizes the panel to `hosting.fittingSize`, keeps the top edge, clamps into the screen with an 8 pt inset, then calls `invalidateShadow()`.
- `MenuBarShell.refit()` (:114-126) anchors the panel under the status item, or at the top-right of `visibleFrame` until the status window has a real frame.
- `show()` (:93-103) runs an icon pass and `refit()`, calls `makeKeyAndOrderFront`, and installs a global mouse-down monitor that calls `launcher.dismissWindow()`. `hide()` (:105-109) removes the monitor and calls `orderOut`.
- `LauncherView` (`LauncherView.swift:11-51`) has a fixed width of 266 (`.frame(width: 266)`, `.fixedSize(horizontal: true, vertical: false)`). The order is:
  1. `ForEach(launcher.rows)` → `GestureRowView` (:14-16).
  2. `SwitcherSection` (:17).
  3. `HandModeToggle` with `.padding(.top, 16)` (:18-19).
  4. `LaunchAnimationSwitch` (:20).
  5. `Divider` (:21).
  6. `switch launcher.activity`: `.active` → `HintText(hint: launcher.gestureHint)`; `.inactive(cause)` → `SettingsNotice(message: Copy.inactiveNotice(for: cause), button: "Trackpad settings…", open: { actions.openSettings(.trackpad) })` (:22-29).
  7. `if !launcher.isAccessibilityGranted` → `SettingsNotice(message: Copy.accessibilityHint, button: "Grant access…", open: { actions.openSettings(.accessibility) })` (:30-34).
  8. A bottom `HStack` with Quit (:40-46).
- The Accessibility hint's button **only opens System Settings**. It never calls `access.prompt()`. `openSettings` closes the window first, then calls `NSWorkspace.shared.open(pane.url)` (`MenuBarShell.swift:147-150`; doc `LauncherActions.swift:27`). The only place that prompts for Accessibility is first launch, inside `Launcher.start()`.
- `SwitcherSection` (`SwitcherSection.swift:9-40`) is a `VStack(spacing: 16)` of two identical `HStack`s: `TemplateImage.view("swipe"|"thumb-tap")` mirrored by `scaleEffect(x: -1)` in left-hand mode, `.accessibilityHidden(true)`, a `Text` title in `.body`, a `Spacer(minLength: 8)`, and a `Toggle` with `.switch` style and hidden label. The setters are `launcher.setSwipe(on:)` and `launcher.setSwap(on:)`. Both save at once and `reconcile()` (`Launcher.swift`, `setSwipe`/`setSwap`).
- Illustrations are SVGs in `assets/` (`gesture-1..5.svg`, `swipe.svg`, `thumb-tap.svg`, `thumb-mark.svg`, `other-finger-mark.svg`), bundled as resources by `project.yml:22-24` (`includes: ["*.svg"]`, `buildPhase: resources`). `TemplateImage.nsImage` loads one from `Bundle.main` and draws nothing when it is missing (`LauncherView.swift:89-104`).
- Copy lives in core: `Copy.gestureHint(for:swipe:)` appends ", or swipe left or right with 2 fingers to switch apps" only while the swipe is on (`K/Sources/LauncherCore/Copy.swift:6-10`). `Copy.accessibilityHint` is at :12-13.

### H. The launch overlay (second non-activating overlay)
- `LaunchOverlay.makePanel(frame:)` (`LaunchOverlay.swift:120-139`):
  - It is a plain `NSPanel` with `[.borderless, .nonactivatingPanel]` and `defer: false`.
  - It is configured with `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false` (the comment says "The icon art carries its own shadow"), `ignoresMouseEvents = true`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false` (the comment says "The app is never active, so it never deactivates either"), `animationBehavior = .none` and `isReleasedWhenClosed = false`.
  - Its content view is a plain, non-flipped, layer-backed `NSView`.
  - The doc at :116-119 says: "Screen-saver level puts it above the menu bar, menus, the launcher window and full-screen apps; it shows on every Space and holds still while Spaces slide."
- `play(for:)` (:34-69):
  - It reads `NSEvent.mouseLocation`, `NSScreen.screens` as `LaunchDisplay` values, and Reduce motion (or `LaunchTuning.current.forceReduceMotion`).
  - It draws a `LaunchFlight`, then `staged(at:among:)` → `LaunchStage(frame, scale, iconSide, iconCentre, animations)`.
  - It makes a panel at `stage.frame`, the union of every pose's bounds clipped to the pointer's display (`LaunchFlight.swift:116-129`).
  - It inserts the panel into `playingPanels` ("AppKit keeps closed panels in its window list, so the overlay tracks its own", :14), then calls `orderFrontRegardless`.
  - In a `CATransaction` it adds one icon `CALayer` with the keyframe animations, sets the model to the last keyframe, and closes the panel and removes it from `playingPanels` in the completion block.
- Icon cache: `prepare(for:)` renders `CGImage`s off-main at the highest connected display's scale (:26-32). `bitmap(for:scale:)` re-renders on the main actor only on a miss or when a sharper scale is needed (:73-79).
- Why it lives in LauncherPlatform while the switcher lives in LauncherUI:
  - What the code says: the overlay is the implementation behind the `SystemActions` port's `playLaunchAnimation(for:)`. The port doc says it "Returns at once. Reads the pointer, the displays and Reduce motion at the moment of the call, plays for about a third of a second and removes itself... Nothing it shows activates Trackpad Launcher, becomes key or receives a click" (`K/Sources/LauncherCore/Ports.swift`, `SystemActions`).
  - The switcher, by contrast, is `Launcher.switcher` model state that `SwitcherPresenter` renders.
  - The rationale written in plan 006's working notes: "The launch overlay stays an effect because it has no state; the switcher has state tests must read, so it is state" (`plans/006-five-finger-tap-and-corner-swipe/.temp/architect/candidate-2.md:170`).
  - The adopted decision, plan 006 decision 8 (`plans/006-five-finger-tap-and-corner-swipe/plan.md:646`), reads: "The switcher is model state rendered by `LauncherUI`... a test reads `launcher.switcher` with no fake."

## Boundaries

- **Module dependencies** (`K/Package.swift:12-22`): LauncherUI depends on LauncherCore only, and the app target depends on all three (`project.yml:25-31`). LauncherUI therefore cannot see LauncherPlatform types (`LaunchOverlay`, `RunningApp`, `LaunchDisplay`). This is why `SwitcherPresenter.screen(under:)` duplicates `LaunchFlight.display(for:)`, and why the location spelling was moved to core as `AppEntry.location(ofBundleAtPath:)` (`plans/008-recent-apps-switcher/development-logs.md:45`).
- **Model to shell inputs** (read-only): `launcher.switcher: Switcher?`, `isSwipeOn`, `isSwapOn`, `isLaunchAnimationOn`, `handMode`, `rows`, `installedApps`, `activity`, `isAccessibilityGranted`, `gestureHint`, `isWindowOpen` (`Launcher.swift:10-28`). `switcher` is "Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`". `reconcile()` sets `switcher = nil` before every `hardware.run`.
- **Shell to model intents**: `setSwipe(on:)`, `setSwap(on:)`, `setHandMode(_:)`, `setLaunchAnimation(on:)`, `setAssignment(_:for:)`, `openWindow()`, `closeWindow()`, `dismissWindow()`.
- **Shell to macOS directly** (no port):
  - `NSWorkspace.shared.open(pane.url)` for System Settings.
  - `NSWorkspace.shared.runningApplications` and workspace launch/terminate notifications.
  - `NSApp.effectiveAppearance` KVO.
  - `NSEvent.mouseLocation`, `NSScreen.screens`.
  - `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
  - `NSOpenPanel` for Other….
  - `NSEvent.addGlobalMonitorForEvents` for mouse-downs.
  - The architecture says AppKit types stay in the shell. Plan 008 notes "The presenter reads `NSWorkspace` itself" (`plans/008-recent-apps-switcher/plan.md:286`).
- **Settings persistence**: the shell never touches `UserDefaults`. It calls `Launcher` setters, which call `store.save(settings)` (`SettingsStore(defaults: .standard)` in the composition root).
- **Isolation**:
  - LauncherUI uses `.defaultIsolation(MainActor.self)` (`K/Package.swift:15-19`).
  - The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (`Config/Base.xcconfig:6`).
  - LauncherPlatform has no default isolation, so `LaunchOverlay` and `WorkspaceActions` are explicitly `@MainActor`.
  - Swift 6, `SWIFT_STRICT_CONCURRENCY = complete` (`Config/Base.xcconfig:4-5`; `swiftLanguageModes: [.v6]`, `K/Package.swift:23`).
  - In LauncherUI, off-main work is marked explicitly: `nonisolated struct`/`nonisolated static func` and `@concurrent` (`AppIcons.swift:11-25,106-126`).
  - AppKit callbacks hop with `MainActor.assumeIsolated` (`SwitcherPresenter.swift:59,64,68,157`; `MenuBarShell.swift:40,101`).
- **Platform/deployment**:
  - Deployment target is macOS 26.0 in `project.yml:4-5`, `Config/Base.xcconfig:1` and `K/Package.swift:6` (`.macOS(.v26)`), with `LSMinimumSystemVersion: "26.0"` (`project.yml:40`). `NSGlassEffectView` is used with no availability checks.
  - `ENABLE_HARDENED_RUNTIME = YES` (`Config/Base.xcconfig:7`). Universal: `ARCHS = $(ARCHS_STANDARD)`, `ONLY_ACTIVE_ARCH = NO`.
- **Info.plist**:
  - It is generated by xcodegen from `project.yml:32-40` (`GENERATE_INFOPLIST_FILE: NO`, file `TrackpadLauncher/Info.plist`, which is gitignored per `.gitignore`).
  - Keys present today: `CFBundleName`, `CFBundleDisplayName`, `CFBundleShortVersionString`, `CFBundleVersion`, `LSUIElement: true`, `LSMinimumSystemVersion`.
  - There are **no `NS…UsageDescription` keys of any kind** and no entitlements file in the repo.
- **Source policy gate**: `SourcePolicyTests` (`K/Tests/LauncherCoreTests/SourcePolicyTests.swift`) scans `K/Sources` (including LauncherUI) and `TrackpadLauncher/`.
  - It bans logging, network, file writes (`.write(to:`, `createFile(atPath`, `FileHandle(forWriting`), `Timer`, `asyncAfter`, `Task.sleep`, display links, keyboard tokens, `nonisolated(unsafe)` and others (:13-54).
  - It confines `AXIsProcessTrusted` and `notify_register` to `SystemAccessibilityPermission.swift` (:64-76).
  - Matching is plain substring `contains` per line (:179-185), so any identifier containing `Timer` fails the build.
  - There is no Screen Recording token in either list today.

## Testing seams (what is and is not tested)
- **There is no LauncherUI test target** (`K/Package.swift:20-21`: only `LauncherCoreTests` and `LauncherPlatformTests`). `SwitcherPresenter`, `SwitcherPanel`, `AppIcons`, `MenuBarShell`, `LauncherPanel` and every SwiftUI view are untested by code. The only test file that mentions LauncherUI is `SourcePolicyTests` (scan coverage, :128-134).
- `K/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift` tests **the model value only**: `world.launcher.switcher` (row names and URLs, `selected`, `selectedApp`, `position`, `stretch`, `selectsFrontmost`, nil after lift or cancel), haptics on `world.hardware`, and `world.system.broughtToFront` and `launchAnimations`, all through `World` with in-memory adapters and `TouchScript` frames. Nothing on screen is checked.
- `K/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift` tests the pure geometry: full size, the 100 pt pitch, a panel width of 536 for 5 icons, shrinking at 15 and 30 icons on 1512 pt, and a non-positive width meaning no constraint. The layout lives in core for this reason.
- `K/Tests/LauncherPlatformTests/LaunchFlightTests.swift` tests `LaunchFlights.next` and `LaunchFlight.staged(at:among:)` through `@testable import LauncherPlatform`, reading back the `CAKeyframeAnimation` values. It covers pop, rise, shrink, fade, sway, tilt, Reduce motion, display choice with two `LaunchDisplay`s (built-in 1512×982 @2x and an external 2560×1440 @1x above it), clipping at the top edge and the shared edge. `LaunchOverlay` itself (panel creation, ordering, completion close) is untested.
- Manual checks cover the rest. Plan 006's verification table lists, for the switcher, "Glass, sizes, display, full screen, focus, dark mode, Reduce motion, ≤ 200 ms, no perceptible delay: manual" (`plans/006-five-finger-tap-and-corner-swipe/plan.md:1272`). Plans 008 and 009 list on-hardware checks for the window's switcher section ("no test target renders the SwiftUI window", `plans/008-recent-apps-switcher/plan.md:338`; `plans/009-app-switch-gesture/plan.md:434`), for icons ready on the first swipe and after an appearance switch (`plans/008-recent-apps-switcher/plan.md:395`), and for row shrink on the 14" display (:408).
- `Scripts/test.sh` runs `swift test` in `LauncherKit` only.

## Places the window swipe's requirements touch the shell (named, not designed)

- **A second panel (R5)**:
  - `SwitcherPresenter` owns exactly one `SwitcherPanel` (`SwitcherPresenter.swift:13`) and observes exactly one model value (`Observations({ launcher.switcher })`, :30).
  - `MenuBarShell` constructs exactly one presenter (`MenuBarShell.swift:15,28`).
  - The panel configuration to mirror is `SwitcherPanel.init` (:26-57) and `LaunchOverlay.makePanel` (:120-139).
- **Top-left placement just below the menu bar (R5)**:
  - Today's placement is a centring on `screen.frame` in `SwitcherPanel.layoutRow` (:94-96).
  - The presenter passes `screen?.frame` (`SwitcherPresenter.swift:137`), not `visibleFrame`.
  - The only code that uses `visibleFrame` today is `MenuBarShell.refit()` (:118).
  - The pointer-display rule is `SwitcherPresenter.screen(under:)` (:165-169).
- **A vertical column that shrinks to fit the height (R5)**: `SwitcherRowLayout` is horizontal and width-only (`SwitcherRowLayout.swift:16-37`). The panel's height formula is fixed constants plus `highlightSide` (`SwitcherPanel.swift:91-93`).
- **Rows with a preview and a one-line truncated title, and a highlight per row (R6, R13, R14)**:
  - Today the panel has one shared `name` label under the row (`SwitcherPanel.swift:22,44-47,100-102,141`) and a highlight moved only along x (`:130`, spring on `position.x` at :148).
  - The icon layer creation is at :106-121.
- **Icons in place of previews**: the 80 pt `AppIcons` instance and its `icon(forSwitcher:)` fallback chain (`AppIcons.swift:50-64`) exist only while the swipe setting is on (`SwitcherPresenter.swift:27,33-37,73-79`).
- **A third switch (R16)**:
  - The pattern is `SwitcherSection.swift:25-38`. Its doc comment says "Two setting rows" (:5).
  - It needs an illustration resource in `assets/` (picked up by `project.yml:22-24`) and `TemplateImage.view`.
  - The `LauncherView` doc comment lists the window's contents (`LauncherView.swift:5-6`).
- **A screen recording hint with a button whose first press prompts and later presses open Settings (R8)**:
  - `SettingsNotice` takes one `open` closure (`LauncherView.swift:161-175`).
  - The Accessibility hint's placement and condition are at `LauncherView.swift:30-34`.
  - `SettingsPane` has only `.trackpad` and `.accessibility` (`LauncherActions.swift:5-16`).
  - `openSettings` always closes the window, then opens a URL (`MenuBarShell.swift:147-150`).
  - No existing hint button prompts. The Accessibility prompt is called only from `Launcher.start()` on first launch.
- **Window refit when the hint appears or disappears**: the refit observation tuple is `(launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn)` at `MenuBarShell.swift:50`.
- **Hint copy**: `Copy.gestureHint(for:swipe:)` mentions only the sideways swipe (`Copy.swift:6-10`). `Copy.accessibilityHint` is at :12-13.
- **Info.plist**: there are no usage-description keys today (`project.yml:34-40`).
- **Source policy**: there is no confined entry for any screen-capture API yet (`SourcePolicyTests.swift:64-76`).

## Non-Obvious Things

- `SwitcherRowLayout` lives in **LauncherCore**, not LauncherUI. It is the only switcher geometry that is tested, and the panel positions icons and highlight through `centreX(at:)` alone.
- The highlight is not animated between icons. It is placed at the continuous `position` on every model update with implicit actions disabled (`SwitcherPanel.swift:128-131`), so it "follows the fingers one to one". Only the icon scale (0.12 s implicit), the end spring and the fade animate.
- `SwitcherPanel` is created at shell init but with `defer: true` (`SwitcherPanel.swift:28`). The window-server cost the presenter's comment mentions is in practice absorbed by `LaunchOverlay.init`'s warm-up panel, which is created earlier in the composition root (`LaunchOverlay.swift:17-21`, `TrackpadLauncherApp.swift:11`).
- The switcher panel is centred on the full `NSScreen.frame`, including the menu bar area. `visibleFrame` is not used.
- `render` re-lays out only when the panel is hidden or the row changed (`SwitcherPresenter.swift:123`). Each layout replaces every icon layer.
- `icon(forSwitcher:)` treats a cache entry as fresh by appearance name only. The Info.plist-date stamp is checked only by the passes (`renderChanged`).
- `AppIcons` draws bitmap reps at 1x and 2x only (`AppIcons.swift:137`). `SwitcherPanel.layoutRow` asks for an `80 × scale` pixel `CGImage` (`SwitcherPanel.swift:113-115`).
- The two observation loops in `SwitcherPresenter.init` both emit their initial value immediately. Correctness relies on the `guard workspaceObservers.isEmpty` in `startIconPasses` (:48) and the `guard isShown` in `hide` (:148).
- `fadeGeneration` is bumped by both `open` and `hide`. A fade's completion orders the panel out only if no later open or close happened (`SwitcherPresenter.swift:22-23,142,154-160`).
- Neither panel sets `becomesKeyOnlyIfNeeded`. `SwitcherPanel` overrides `canBecomeKey`/`canBecomeMain` to false. The overlay panels have no overrides and rely on `.nonactivatingPanel` plus `ignoresMouseEvents`.
- `LauncherPanel` (the launcher window) is `.popUpMenu` level. Both overlays are `.screenSaver`, above the launcher window and the menu bar. `LauncherPanel`'s collection behaviour lacks `.stationary`.
- The Accessibility hint's button does not prompt. It closes the window and opens the Privacy_Accessibility pane URL.
- `SourcePolicyTests` matches substrings, so a new identifier containing a banned token (for example `Timer`) fails the build even when it is not the banned API.
- `MenuBarShell` is the only public LauncherUI symbol. Everything the app target sees of the UI is `MenuBarShell(launcher:)`.

## Files Read
- `docs/architecture.md`
- `docs/domain-model.md`
- `plans/012-window-switcher-gesture/plan.md`
- `K/Sources/LauncherUI/SwitcherPresenter.swift`
- `K/Sources/LauncherUI/SwitcherPanel.swift`
- `K/Sources/LauncherUI/GlassClip.swift`
- `K/Sources/LauncherUI/AppIcons.swift`
- `K/Sources/LauncherUI/MenuBarShell.swift`
- `K/Sources/LauncherUI/LauncherPanel.swift`
- `K/Sources/LauncherUI/LauncherView.swift`
- `K/Sources/LauncherUI/SwitcherSection.swift`
- `K/Sources/LauncherUI/LauncherActions.swift`
- `K/Sources/LauncherUI/AppMenuButton.swift`
- `K/Sources/LauncherUI/StatusIcon.swift`
- `K/Sources/LauncherCore/SwitcherRowLayout.swift`
- `K/Sources/LauncherCore/Switcher.swift`
- `K/Sources/LauncherCore/Launcher.swift`
- `K/Sources/LauncherCore/Ports.swift` (`SystemActions`, `AccessibilityPermission`, `AppScanner`, `TrackpadPreferences`)
- `K/Sources/LauncherCore/Copy.swift`
- `K/Sources/LauncherCore/Apps.swift` (`installedApps()` only)
- `K/Sources/LauncherPlatform/LaunchOverlay.swift`
- `K/Sources/LauncherPlatform/LaunchFlight.swift` (lines 1-150)
- `K/Sources/LauncherPlatform/WorkspaceActions.swift`
- `K/Sources/LauncherPlatform/AppCatalog+System.swift` (lines 1-25)
- `K/Sources/LauncherPlatform/SystemAccessibilityPermission.swift`
- `K/Package.swift`
- `project.yml`
- `Config/Base.xcconfig`
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `.gitignore`
- `Scripts/test.sh`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `K/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift`
- `K/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`
- `K/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `K/Tests/LauncherPlatformTests/LaunchFlightTests.swift` (lines 1-82, plus the test names)
- Excerpts of `plans/006-five-finger-tap-and-corner-swipe/plan.md`, `plans/006-.../.temp/architect/candidate-2.md`, `plans/008-recent-apps-switcher/plan.md`, `plans/008-.../development-logs.md` and `plans/009-app-switch-gesture/plan.md` (found by grep)

## Open Questions
- I did not verify at runtime whether `Observations` delivers every intermediate `Switcher` value or only the latest per main-actor turn. The claim that it coalesces comes from plan 006's design text, not from code or a test.
- I did not confirm whether `SwitcherPanel` with `defer: true` pays any measurable cost on its first `orderFrontRegardless`, beyond the process-first-window cost that `LaunchOverlay.init` absorbs. No code or test measures it.
- `AnimationTuner.swift` (Debug-only) was not read beyond its use in `WorkspaceActions.showAnimationTuner()`.
- The System Settings URL for the Screen Recording pane, and whether macOS needs any Info.plist key for Screen Recording, appear nowhere in the repo. I made no claims about them from code.
