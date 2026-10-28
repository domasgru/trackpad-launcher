# Grounding: the menu bar shell and the launcher window (LauncherUI)

Root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle` (paths below are relative to it).

## Components Found

- **`MenuBarShell`**, `LauncherKit/Sources/LauncherUI/MenuBarShell.swift:14`. `public final class MenuBarShell: NSObject`. It is the only `public` type in LauncherUI (grep for `public ` finds only `:14` and `:25`). Its only initialiser is `public init(launcher: Launcher)` (`:25`). It owns the `NSStatusItem` (`:19`), the `LauncherPanel` (`:20`), an `AppIcons` cache with 16 pt icons (`:16`), `SwitcherPresenter` (`:17`), `WindowSwitcherPresenter` (`:18`), the outside-click monitor token `mouseDownMonitor: Any?` (`:21`), four `Observations` tasks (`:22`) and a status-window move observer (`:23`). The doc comment (`:6-13`) gives the dismissal contract and says to "Create it before `Launcher.start()`: a first-launch window needs the status item as its anchor."
- **`LauncherPanel`**, `LauncherKit/Sources/LauncherUI/LauncherPanel.swift:6`. `final class LauncherPanel: NSPanel` (internal). It is borderless and non-activating, can become key, and sits at pop-up-menu level. It hosts `NSHostingView<AnyView>` in an `NSGlassEffectView` inside a rounded clip. It exposes two callbacks, `onCancel` and `onResignKey` (`:7-8`), and `fitToContent(centeredOn:topEdge:within:)` (`:44`).
- **`StatusIcon`**, `LauncherKit/Sources/LauncherUI/StatusIcon.swift:5`. `enum StatusIcon { static func image(active: Bool) -> NSImage }`. It draws the SF Symbol `hand.tap` at 15 pt as a template image (`:6-12`). When `active` is false it knocks a diagonal slash out of the symbol (`:15-32`).
- **`LauncherView`**, `LauncherKit/Sources/LauncherUI/LauncherView.swift:11`. The root SwiftUI view, `init(launcher:actions:)` (memberwise, `:12-13`). It is fixed at 266 pt wide (`:53-54`).
- **`GestureRowView`** (`LauncherView.swift:64`), **`SettingsNotice`** (`:215`), **`ThumbPicker`** (`:162`, an `NSViewRepresentable` around `NSSegmentedControl`), **`LaunchAnimationSwitch`** (`:197`), **`BundleImage`** (`:122`), **`Illustration`** (`:105`) and **`Guide`** (`:150`).
- **`SwitcherSection`** and **`SettingRow`**, `LauncherKit/Sources/LauncherUI/SwitcherSection.swift:6,25`. Three SwiftUI `Toggle(.switch)` rows bound to `launcher.setSwipe`, `setWindowSwipe` and `setSwap` (`:11-19`).
- **`LauncherActions`**, `LauncherKit/Sources/LauncherUI/LauncherActions.swift:22`. An internal struct of closures: `cachedIcon`, `icon`, `chooseOtherApp: (@escaping (URL) -> Void) -> Void` and `openSettings: (SettingsPane) -> Void` (`:24-31`).
- **`SettingsPane`**, `LauncherActions.swift:5`. Three cases (`.trackpad`, `.accessibility`, `.screenRecording`), each mapped to an `x-apple.systempreferences:` URL (`:10-18`).
- **`AppPicker`**, `LauncherKit/Sources/LauncherUI/AppPicker.swift:15`. An `NSViewRepresentable` wrapping a real AppKit `NSPopUpButton(pullsDown: false)` (`:31`). Its `Coordinator: NSObject, NSMenuDelegate` (`:56`) builds the menu lazily in `menuNeedsUpdate` (`:90`).
- **`AppIcons`**, `LauncherKit/Sources/LauncherUI/AppIcons.swift:10`. The icon bitmap cache. Its entry points are `renderOnMainActor` (sync, `:67-71`), `renderOffMainActor` (`:75-89`), `cachedIcon` (never draws, `:39`) and `iconDrawingIfMissing` (draws synchronously, `:42-46`).
- **`Displays.screen(under:)`**, `LauncherKit/Sources/LauncherUI/Displays.swift:5`. Returns the display that holds the pointer, by the `NSMouseInRect` rule, or the nearest display when none holds it (`:7-8`). Today only the switcher presenters use it (`SwitcherPresenter.swift:130`, `WindowSwitcherPresenter.swift:60`); the launcher window does not.
- **`roundedClip(_:cornerRadius:)`**, `LauncherKit/Sources/LauncherUI/GlassClip.swift:6`. Wraps the glass view in a layer-masked view with continuous corners, so the borderless window's shadow follows the rounded edge (`:3-5`).
- **Model side (LauncherCore)**: `Launcher.isWindowOpen` (`LauncherKit/Sources/LauncherCore/Launcher.swift:22`), the private `enum Window { closed, open, heldOpen }` (`:47`), `openWindow()` (`:186`), `closeWindow()` (`:193`) and `dismissWindow()` (`:196`).
- **Composition root**: `TrackpadLauncher/TrackpadLauncherApp.swift:20`, `let shell = MenuBarShell(launcher: launcher)`, then `launcher.start()` (`:21`), then `withExtendedLifetime(shell) { application.run() }` (`:25`). There is no `NSApplicationDelegate`, no `mainMenu`, no `setActivationPolicy` and no `NSWindowDelegate` anywhere in Sources or the app target (grep returned nothing).

## Flow

### Construction (`MenuBarShell.init`, MenuBarShell.swift:25-76)

1. `:27`: `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)`.
2. `:28`: `icons.renderOnMainActor(Self.iconTargets(launcher))` runs a synchronous icon pass over `installedApps.all` plus each row's `.present` app (`iconTargets`, `:112-117`). This is the "first icon pass waited for before the run loop" exception in `docs/architecture.md:19`.
3. `:29-30`: `makeActions(...)` builds the actions, then `panel = LauncherPanel(content: LauncherView(launcher:actions:))`. The panel and its hosting view are created once and reused.
4. `:31-32`: creates `SwitcherPresenter(launcher:)` and `WindowSwitcherPresenter(launcher:)`. Both are internal and owned here (`SwitcherPresenter.swift:5,22`, `WindowSwitcherPresenter.swift:5,22`).
5. `:35`: the status image is set from `StatusIcon.image(active: launcher.activity.isActive)`.
6. `:36-38`: the button's target/action is `statusItemClicked`, with `sendAction(on: [.leftMouseUp, .rightMouseUp])`.
7. `:39`: `panel.onCancel = { launcher.closeWindow() }`, so Escape closes the window.
8. `:40`: `panel.onResignKey = { resignedKey() }`.
9. `:42-46`: observes `NSWindow.didMoveNotification` on the status button's window and calls `refit()`.
10. Four `Observations` loops:
    - `:47-52` reads `launcher.activity.isActive` and swaps the status icon image.
    - `:53-63` reads the tuple `(activity, isAccessibilityGranted, isSwipeOn, screenRecordingHint)` and calls `refit()`, because the notices change the window's height.
    - `:64-69` reads `launcher.installedApps` and calls `renderIcons()` off the main actor.
    - `:70-75` reads `launcher.isWindowOpen`: `true` calls `show()`, `false` calls `hide()`. **The window's visibility is driven only by model state.** The shell never shows or hides the panel directly in response to a click.

### Open

- **Status item left click.** `statusItemClicked` (`:83-92`): if the window is open it calls `launcher.closeWindow()`, otherwise `launcher.openWindow()`.
- **First launch.** `Launcher.start()` sets `window = prompting ? .heldOpen : .open` (`Launcher.swift:112`).
- **After the Other… chooser** (see below).
- **`Launcher.openWindow()`** (`Launcher.swift:186-190`): `if window == .closed { window = .open }`, then `resolveRows()`, then `scanner.scan()`. The scan refreshes the installed and recent apps; a test enforces that only `start` and `openWindow` request scans (`RecentAppsTests.swift:157-179`).
- **The observation fires `show()`** (`MenuBarShell.swift:121-131`):
  1. `renderIcons()` starts an off-main icon pass (`AppIcons.renderOffMainActor` spawns a `Task`, `AppIcons.swift:75-78`). The window therefore shows **before** that pass merges, and newly seen icons appear as the generic icon in the menus until it finishes (`cachedIcon` falls back to `generic`, `:39`).
  2. `refit()`.
  3. `panel.makeKeyAndOrderFront(nil)`. There is **no `NSApp.activate()` on open**: the panel is `.nonactivatingPanel`, so it becomes key while the app stays inactive.
  4. If no monitor exists yet, it installs `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown])`, which calls `launcher.dismissWindow()` (`:126-130`).
- **`refit()`** (`:143-155`): returns early unless the window is open. The screen is `statusItem.button?.window?.screen ?? NSScreen.main`. The anchor defaults to `visible.maxX` and the top edge to `visible.maxY`. If the status window has a real frame (`width > 0` and within 60 pt of the screen top), the anchor becomes `frame.midX` and the top edge `min(frame.minY, visible.maxY)`. It then calls `panel.fitToContent(centeredOn:topEdge:within: visible)`.
- **`LauncherPanel.fitToContent`** (`LauncherPanel.swift:44-50`): takes `hosting.fittingSize`, clamps x into the screen with an 8 pt inset (`screenEdgeInset`, `:31`), clamps y to `max(topEdge - height, minY + 8)`, then `setFrame(... display: true)` and `invalidateShadow()`. The window is placed and sized by code; it is never centred on anything other than the status icon.

### Panel configuration (`LauncherPanel.init`, LauncherPanel.swift:12-28)

- `styleMask: [.borderless, .nonactivatingPanel]`, `backing: .buffered`, `defer: true` (`:15`).
- `contentView = roundedClip(NSGlassEffectView(style: .regular, cornerRadius: 12))`, with `hosting` as the glass's `contentView` (`:16-20`, `cornerRadius = 12` at `:30`).
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true` (`:21-23`).
- `level = .popUpMenu` (`:24`).
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]` (`:25`).
- `isReleasedWhenClosed = false`, `hidesOnDeactivate = false` (`:26-27`).
- `override var canBecomeKey: Bool { true }` (`:33`). `canBecomeMain` is not overridden, so it defaults to false for a borderless panel.
- `override func cancelOperation(_:)` calls `onCancel()` (`:36`). This is Escape.
- `override func resignKey()` calls `super.resignKey()` and then `onResignKey()` (`:38-41`).

### Close paths

All close paths are model writes; the shell then reacts through the `isWindowOpen` observation and calls `hide()`.

| Trigger | Code | Model call | Closes a held (first-launch) window? |
|---|---|---|---|
| Status icon left click while open | `MenuBarShell.swift:87-88` | `closeWindow()` | yes |
| Status icon right-click or Control-click | `showContextMenu`, `:95-96` | `closeWindow()` | yes |
| Escape in the panel | `LauncherPanel.cancelOperation` `:36`, via `onCancel` `MenuBarShell.swift:39` | `closeWindow()` | yes |
| Panel resigns key | `resignedKey` `:105-109` | `dismissWindow()` unless the current event is a `.leftMouseDown` whose window is the status button's window | no |
| Global mouse-down in another app | monitor `:126-130` | `dismissWindow()` | no |
| Other… | `chooseOtherApp` `:162` | `closeWindow()` (and reopens later) | yes |
| Any System Settings button | `openSettings` `:177` | `closeWindow()` | yes |
| Gesture fires | `Launcher.fire` `Launcher.swift:265` | `window = .closed` | yes |
| Swipe lift that brings an app forward | `Launcher.swift:309` | `window = .closed` | yes |
| Window swipe lift with a haptic | `Launcher.swift:345` | `window = .closed` | yes |
| Swap | `Launcher.swift:361` | `window = .closed` | yes |
| Accessibility granted while held | `reconcile` `Launcher.swift:219` | `window = .closed` only when `heldOpen` | (it is the hold's own end) |

- **`closeWindow()`** (`Launcher.swift:192-193`) always closes. Its doc comment reads: "Icon click, Escape, the window's own System Settings buttons: always closes."
- **`dismissWindow()`** (`Launcher.swift:195-196`) closes only `.open`. The doc comment reads: "An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt." The `.heldOpen` rationale is at `Launcher.swift:44-46`.
- **`hide()`** (`MenuBarShell.swift:133-137`) removes the global monitor, sets it to nil and calls `panel.orderOut(nil)`. The monitor therefore exists only while the window is shown.
- **How a gesture closes the window:** through model state. `fire`, `swipe`, `windowSwipe` and `swap` write `window = .closed` directly. There is no callback or port to the shell; the `Observations({ launcher.isWindowOpen })` loop picks the change up.

### Status item click and toggle race

- The status bar button lives in its own window inside our process, so the global monitor (which only sees other processes' events) does not fire for it.
- A left mouse-down on the status button makes the panel resign key. `resignedKey` sees `.leftMouseDown` on the status window and skips the dismiss (`:107-108`). On `.leftMouseUp`, `statusItemClicked` toggles (`:83-91`). This is the "closing here would reopen it" case in the doc comment (`:11-12`).
- A right mouse-down on the status button is **not** exempted (only `.leftMouseDown` is checked at `:107`). The panel's `resignKey` therefore calls `dismissWindow()`, and then `rightMouseUp` reaches `showContextMenu`, which calls `closeWindow()` anyway.

### Quit (`showContextMenu`, MenuBarShell.swift:94-103)

- It first calls `launcher.closeWindow()`, then builds an `NSMenu` with one item: `"Quit Trackpad Launcher"`, `action: #selector(NSApplication.terminate(_:))`, `keyEquivalent: "q"`. The item has no target, so the responder chain reaches `NSApp`.
- It then sets `statusItem.menu = menu`, calls `statusItem.button?.performClick(nil)` and sets `statusItem.menu = nil`. The menu is attached only for that click so that left clicks still reach the action (`:94`).
- `terminate(_:)` runs with no delegate, so nothing can veto or intercept it: there is no `applicationShouldTerminate`.
- The "q" key equivalent works only while that menu is open. There is no main menu, so ⌘Q does nothing at any other time. ⌘W has no handler either: the panel is borderless, has no close button and installs no `performClose`.
- History: before commit `22d059a` (#25), Quit was a `Button("Quit", action: actions.quit)` in a bottom bar of `LauncherView`, with `LauncherActions.quit: () -> Void` wired as `quit: { NSApp.terminate(nil) }` in `MenuBarShell.makeActions`. #25 removed it (`git show 22d059a`).

### Other… chooser (`MenuBarShell.makeActions` `chooseOtherApp`, MenuBarShell.swift:161-175)

1. Trigger: the AppPicker menu item "Other…" (`AppPicker.swift:104`) runs `pickOther()` (`:152-155`), which calls `chooseOther()` and then `showCurrentOnly()` straight away. `begin` is asynchronous, so the button goes back to showing the row's app.
2. `GestureRowView` wires `chooseOther` as `actions.chooseOtherApp { launcher.setAssignment(.appBundle(at: $0), for: row.gesture) }` (`LauncherView.swift:85`).
3. `chooseOtherApp` then:
   - calls `launcher.closeWindow()` (`:162`), so the panel will `orderOut` through the observation;
   - calls `NSApp.activate()` (`:163`), the only `NSApp.activate()` in LauncherUI;
   - creates `NSOpenPanel()` with `allowedContentTypes = [.application]`, `canChooseDirectories = false`, `allowsMultipleSelection = false` and `directoryURL = /Applications` (`:164-168`);
   - calls `chooser.begin { response in ... }` (`:169`). This makes it a **free-standing, non-modal open panel**. It is not a sheet (`beginSheetModal(for:)` is not used) and not app-modal (`runModal` is not used);
   - in the completion: `if response == .OK, let url = chooser.url { completion(url) }`, then **always** `launcher.openWindow()` (`:170-173`). Cancel also reopens the launcher window.
4. The result reaches the model as `completion(url)`, which calls `launcher.setAssignment(.appBundle(at: url), for:)`. The model parses it with `catalog.entry(at:)` (`Launcher.swift:129-133`) and saves.
5. Interaction with `resignKey`: the launcher window is already closed by the time the open panel takes key, so `resignedKey` sees a closed window. `dismissWindow` on `.closed` is a no-op (`Launcher.swift:196`).
6. Side effect on a held first-launch window: `closeWindow()` sets `.closed`, and `openWindow()` then sets `.open` (not `.heldOpen`). Using Other… during first launch therefore drops the hold.
7. Model-level consequence: while the app is active (around the chooser), `NSWorkspace.frontmostApplication` is Trackpad Launcher, which the readers turn into `frontmost == nil` (`RunningAppsReader.swift:36-40`, `Apps.swift:34-35`). Both comments say "Trackpad Launcher itself, which never activates except around the Other… chooser". `docs/domain-model.md:66` says the same: "Trackpad Launcher is active only when macOS makes it so: right after it is opened (from Finder, or Run in Xcode) and around the Other… chooser." `ActivationTracker.note` and `fallbackApps` also skip our own pid (`ActivationTracker.swift:25`, `RunningAppsReader.swift:24-28`).
8. After the chooser closes, the shell never calls a deactivate. The app presumably stays active until the user clicks elsewhere. I did not verify this at runtime.

### System Settings buttons (LauncherView.swift:29-50, LauncherActions `openSettings`, MenuBarShell.swift:176-179)

- `openSettings(pane)` calls `launcher.closeWindow()` and then `NSWorkspace.shared.open(pane.url)`. **The window closes**, held or not. The reason is in `LauncherActions.swift:30`: "Closes the window explicitly (System Settings takes focus; a held window must not sit over it)". The panel's `.popUpMenu` level would otherwise float above System Settings.
- The trackpad settings notice is shown while `activity` is `.inactive(cause)`. Its button is "Trackpad settings…" and calls `openSettings(.trackpad)` (`LauncherView.swift:31-35`).
- The Accessibility hint is shown while `!isAccessibilityGranted`. Its button is "Grant access…" and calls `openSettings(.accessibility)` (`:36-40`).
- The screen recording hint is shown while `screenRecordingHint != nil` (`:41-47`):
  - `.ask` calls `launcher.askForScreenRecording()`. This does **not** call `closeWindow`. It records the ask, saves, and calls `permissions.ask(.screenRecording)` (`Launcher.swift:178-183`), which runs `CGRequestScreenCaptureAccess()` (`LauncherPlatform/SystemPermissions.swift:42-43`). If the system prompt takes focus, the panel resigns key and `dismissWindow()` closes an `.open` window. This is inferred from the code; I did not verify it at runtime.
  - `.openSettings` calls `openSettings(.screenRecording)`, which closes the window.
- Button labels come from `Copy.screenRecordingButton` (`LauncherCore/Copy.swift:12-17`): "Allow Screen Recording…" or "Open System Settings…". The hint texts are `Copy.accessibilityHint` (`:5-7`), `Copy.screenRecordingHint` (`:10`) and `Copy.inactiveNotice` (`:29-37`).
- `SettingsNotice` is a `Text` plus `Button(... ).buttonStyle(.bordered).buttonBorderShape(.capsule)` (`LauncherView.swift:215-229`).
- `hasNotices` (`:57-60`) decides whether the notices block is shown. The shell's refit loop observes the same inputs (`MenuBarShell.swift:56-59`).

### App pickers (AppPicker.swift)

- An `NSPopUpButton` (AppKit) wrapped in `NSViewRepresentable` (`:30-38`). It is not a SwiftUI `Menu` and not an `NSMenu` shown by our own code. `menu.autoenablesItems = false`, and `altersStateOfSelectedItem = false`.
- While closed, the button holds a single item showing the row's app (`showCurrentOnly`, `:66-73`). Opening the menu triggers `menuNeedsUpdate`, which rebuilds the items from `installedApps.pickerMenu(checking:)` using `cachedIcon` (it never draws), then calls `selectItem(at: 0)` so the list opens at the top (`:87-110`).
- `menuWillOpen` and `menuDidClose` track `isMenuOpen` (`:75-85`). `updateNSView` skips `showCurrentOnly` while the menu is open (`:48`).
- The closed button's own icon uses `icon` (`iconDrawingIfMissing`, which draws synchronously on the main actor) (`:117-119`).
- Escape inside an open menu: the code has no handling for this. With `NSPopUpButton`, AppKit runs its own menu-tracking loop and Escape dismisses the menu there, so the panel's `cancelOperation` is not called. This is standard AppKit behaviour that I inferred; nothing in this repo tests it. A second Escape, after the menu has closed, reaches `LauncherPanel.cancelOperation` and closes the window.
- `ThumbPicker` is an `NSSegmentedControl` (`LauncherView.swift:171-179`). The three switches and the Launch animations switch are SwiftUI `Toggle(.switch)`.

### Status icon active/inactive

- `StatusIcon.image(active:)` (`StatusIcon.swift:8-33`) is driven by `launcher.activity.isActive` at init (`MenuBarShell.swift:35`) and by the `Observations` loop (`:47-52`).
- `activity` is derived as `GestureActivity(connected:values:)` (`Launcher.swift:29-31`). `isActive` is `self == .active` (`LauncherCore/Activity.swift:59`). It means "a trackpad is connected and no conflicting trackpad setting is on".
- `isAccessibilityGranted` is deliberately kept out of `activity`, "so the icon never reads it" (`Launcher.swift:33`).

## Files Read

- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `LauncherKit/Package.swift`
- `LauncherKit/Sources/LauncherUI/MenuBarShell.swift`
- `LauncherKit/Sources/LauncherUI/LauncherPanel.swift`
- `LauncherKit/Sources/LauncherUI/StatusIcon.swift`
- `LauncherKit/Sources/LauncherUI/LauncherView.swift`
- `LauncherKit/Sources/LauncherUI/LauncherActions.swift`
- `LauncherKit/Sources/LauncherUI/AppPicker.swift`
- `LauncherKit/Sources/LauncherUI/AppIcons.swift`
- `LauncherKit/Sources/LauncherUI/Displays.swift`
- `LauncherKit/Sources/LauncherUI/GlassClip.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherSection.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift` (lines 1-40)
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift` (lines 1-30)
- `LauncherKit/Sources/LauncherUI/OverlayPanel.swift` (header)
- `LauncherKit/Sources/LauncherCore/Launcher.swift` (lines 1-372)
- `LauncherKit/Sources/LauncherCore/Copy.swift`
- `LauncherKit/Sources/LauncherCore/Activity.swift` (lines 50-62)
- `LauncherKit/Sources/LauncherCore/Apps.swift` (lines 28-40)
- `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift`
- `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift` (lines 15-41)
- `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift` (lines 10-62)
- `LauncherKit/Sources/LauncherPlatform/SystemPermissions.swift` (lines 38-45)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/AccessibilityTests.swift` (lines 1-80)
- `LauncherKit/Tests/LauncherCoreTests/RecentAppsTests.swift` (lines 95-180)
- `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift` (lines 10-45)
- `docs/architecture.md` (grep hits at lines 11, 12, 19, 25)
- `docs/domain-model.md` (grep hits at lines 6, 66, 81, 105, 140, 143)
- `project.yml` (lines 36-40)
- Git history: `git show 22d059a` (the Quit move), `git log` for MenuBarShell and LauncherPanel

## Boundaries

- **In from the app target:** `MenuBarShell(launcher: Launcher)` is the only public entry point of LauncherUI (`MenuBarShell.swift:25`). The composition root has to create it before `launcher.start()` and keep it alive with `withExtendedLifetime(shell)` around `application.run()` (`TrackpadLauncherApp.swift:20-25`). The ordering matters today only because the first-launch window anchors to the status item.
- **Out to the model (intents):** `openWindow`, `closeWindow`, `dismissWindow`, `setAssignment`, `setSwipe`, `setWindowSwipe`, `setSwap`, `setLaunchAnimation`, `setHandMode` and `askForScreenRecording`, all called directly on `Launcher` from the views and the shell.
- **In from the model (observed):** `activity` (icon and refit), `isAccessibilityGranted`, `isSwipeOn` and `screenRecordingHint` (refit), `installedApps` (icon passes), `isWindowOpen` (show/hide). SwiftUI views read `rows`, `handMode`, the setting flags and `installedApps` through `@Observable`.
- **Out to the system:** `NSWorkspace.shared.open(pane.url)` for the System Settings URLs (`LauncherActions.swift:12-16`), `NSOpenPanel`, `NSApp.activate()` and `NSApplication.terminate(_:)`.
- **Model and window state:** `Window { closed, open, heldOpen }` is private in `Launcher` (`Launcher.swift:47-49`). Only `isWindowOpen` is public. The shell cannot tell a held window from an open one.
- **Bundle:** `project.yml:39` sets `LSUIElement: true`, which is why there is no Dock icon and no main menu. The app's activation policy is therefore `.accessory` from launch. No code calls `setActivationPolicy` (grep).
- **Source-scan confinement** (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`):
  - `addGlobalMonitorForEvents` is allowed only in `["MenuBarShell.swift", "BounceOverlay.swift"]` (`:90-92`), with the rule text "pointer moves are read only while a launch bounce shows". `docs/architecture.md:25` calls this "the launcher window's outside-click monitor". If the outside-click monitor goes away or moves, this entry and the doc sentence need updating. If the file is renamed, the test fails.
  - `addLocalMonitorForEvents` is allowed only in `BounceOverlay.swift` (`:93-95`). A new local key or mouse monitor in the shell would fail the test.
  - `mouseMoved` is allowed only in `BounceOverlay.swift` and `ClickTap.swift` (`:87-89`).
  - Banned everywhere (`:43-48`, rule "R9 no keyboard"): the substrings `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged` and `FlagsChanged`. Any ⌘W or ⌘Q handling written as `override func keyDown`, `.keyDown` event matching or `NSEvent.EventType.keyDown` would fail the scan. `performKeyEquivalent`, `cancelOperation`, `performClose` and main-menu `keyEquivalent:` strings contain none of the banned substrings. The existing `keyEquivalent: "q"` passes.
  - Also banned: `Timer` (`:30`), which also catches any identifier containing "Timer", and `asyncAfter` (`:31`). Delayed show/hide tricks are ruled out.
  - The scan covers `LauncherKit/Sources` and the `TrackpadLauncher/` app directory (`:112-117`), so an `AppDelegate` in the app target is scanned too.
  - Only `LauncherCore` has an import whitelist (Foundation and Observation, `:177-183`).
- **Tests:** LauncherUI has no test target (`Package.swift:20-21`). All window behaviour that has tests is tested at the model level through `isWindowOpen`, `openWindow`, `closeWindow` and `dismissWindow`. Examples: `AccessibilityTests.swift:20-73` covers the held window, dismiss versus close, a grant ending the hold and a gesture closing a held window. Gesture, swipe and swap tests assert `!isWindowOpen` (for example `LauncherTests.swift:26,43`, `SwapTests.swift:31`, `WindowSwitchingTests.swift:74,97`). `RecentAppsTests.swift:105-121,157-179` covers opening the window refreshing the recent apps and opening being the only intent besides `start` that requests a scan.

## Non-Obvious Things

1. **Show and hide are driven only by model state** (`MenuBarShell.swift:70-75`). The status click, Escape, the Other… chooser and Settings only write to the model. `Observations` delivers on a later main-actor turn, so `panel.orderOut` happens after the intent returns, not inside it. This matters for the chooser: `closeWindow()`, `NSApp.activate()` and `begin` run synchronously first, and the `orderOut` follows.
2. **On first launch, `show()` comes from the first `Observations` emission.** `start()` sets `.open` or `.heldOpen` before `application.run()`. The shell's `Observations` task can only run once the main executor drains, so its first value is already `true`. I inferred this from the ordering; I did not test it.
3. **`dismissWindow` and `closeWindow` are distinct only because of `.heldOpen`.** An outside click or `resignKey` uses `dismissWindow`; everything the user does explicitly uses `closeWindow`. The new design (outside clicks never close the window) would make `dismissWindow` and the global monitor unnecessary for the settings window.
4. **The panel is non-activating and the app never activates when the window opens.** Typing focus works because the panel is key in an inactive app. `hidesOnDeactivate = false`. `NSApp.activate()` is called only for the Other… chooser (`:163`) and by the Debug-only `AnimationTuner` (`AnimationTuner.swift:57`, whose comment at `:41-42` says "the app is a menu bar app that is otherwise never active"). The platform readers and docs build on "Trackpad Launcher never activates except around the Other… chooser" (`Apps.swift:34-35`, `RunningAppsReader.swift:36-37`, `docs/domain-model.md:66`). An ordinary titled window that activates the app on open would make Trackpad Launcher the frontmost app much more often. While it is frontmost, the switcher's row loses its "frontmost" entry, a swap targets the most recently used app, and a slide up or down is no window swipe (`docs/domain-model.md:66`).
5. **The Other… chooser is a free-standing `NSOpenPanel.begin`, not a sheet.** It works only because the launcher window is closed first. A popUpMenu-level borderless panel would otherwise sit above the chooser, and its resignKey/outside-click dismissal would interfere. The completion **always** reopens the launcher window, including on cancel, and a held first-launch window becomes an ordinary `.open` one (`closeWindow` then `openWindow`, `Launcher.swift:186-193`).
6. **`pickOther` resets the button immediately** (`AppPicker.swift:152-155`). The assignment then arrives later through `setAssignment`, `rows` and `updateNSView`. Because the menu is closed by then, `updateNSView` calls `showCurrentOnly`, and the closed button's icon is drawn on the spot through `iconDrawingIfMissing`. This is the documented exception in `docs/architecture.md:19`.
7. **Escape in the screen-recording `.ask` path does not apply; the window simply stays open.** Pressing "Allow Screen Recording…" does not close the window (`LauncherView.swift:44`). The other two notice buttons, and "Open System Settings…", close it explicitly (`MenuBarShell.swift:177`).
8. **Right mouse-down on the status icon dismisses through `resignKey`** before `showContextMenu` closes the window. Only `.leftMouseDown` on the status window is exempt (`:107`).
9. **There is no main menu, so ⌘Q, ⌘W and ⌘M do nothing today**, except the "q" equivalent inside the transient status menu. There is no app delegate, so `terminate` cannot be intercepted, and no Dock-reopen handling exists.
10. **`refit` depends on the status item's window.** It falls back to the top-right of `NSScreen.main` until the status window has a real frame, and it is re-run on `NSWindow.didMoveNotification` of the status window (`:42-46`, `:139-155`). `Displays.screen(under: NSEvent.mouseLocation)` already exists in LauncherUI for "the pointer's display" and is used by both switcher presenters. The launcher window does not use it.
11. **`LauncherPanel.fitToContent` clamps both x and y.** The y clamp is `max(topEdge - h, minY + 8)`. An older grounding note (`plans/006-.../grounding/how.md:321`) says only x was clamped; that is no longer true.
12. **The refit observation tuple omits `isWindowSwipeOn`, `rows` and `handMode`.** `screenRecordingHint` reads `settings.isWindowSwipeOn`, so it is covered indirectly. The guide is an overlay and does not change the window's size.
13. **`MenuBarShell` also owns both switcher presenters** (`:17-18`, `:31-32`). They are independent of the window and the status item, but they live inside the shell object. Removing or renaming the shell means rehoming them: the doc comments in `SwitcherPresenter.swift:5` and `WindowSwitcherPresenter.swift:5` say "Owned by `MenuBarShell`".
14. **The status item exists for the whole process lifetime**, and the icon's slashed variant is the only visible "gestures inactive" signal outside the window. Without the status item, `activity` would show only through the trackpad settings notice inside the window.
15. **`LauncherView`'s doc comment says "Quit lives in the status item's right-click menu."** (`LauncherView.swift:10`), and `docs/domain-model.md:81` agrees: "The window that opens from the menu bar icon … Quit is in the menu that a right-click … opens". Both would need rewriting.

## Open Questions

- Runtime behaviour I could not verify from the code alone:
  - Does the app stay active after the `NSOpenPanel` closes, and for how long?
  - Does the reopened panel become key while the app is active?
  - Does `CGRequestScreenCaptureAccess()`'s prompt actually take key from the panel and dismiss it?
- Escape inside an open `NSPopUpButton` menu: I believe AppKit's menu tracking consumes it and `cancelOperation` is not called, but nothing in the repo exercises or documents this.
- I did not trace `SwitcherPresenter` or `WindowSwitcherPresenter` beyond their headers. They have no dependency on the status item or the launcher panel that I could see in lines 1-40 and 1-30.
- I did not read `BounceOverlay.swift`'s use of the global and local monitors. It is the other file allowed to call `addGlobalMonitorForEvents`.
