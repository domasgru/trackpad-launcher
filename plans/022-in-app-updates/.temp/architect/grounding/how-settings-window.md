# Grounding: settings window, `Launcher` ownership, `LauncherUI` shell, ports and test conventions

Angle: "settings-window". Raw facts with file:line citations. Paths are relative to the repo root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates/`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `Launcher` | `LauncherKit/Sources/LauncherCore/Launcher.swift:9-389` | `@MainActor @Observable public final class`; owns gestures, settings and the settings window's open/closed state (`window`). |
| `Launcher.Window` | `Launcher.swift:44-50` | `enum Window: Equatable, Sendable { case closed; case open(request: Int) }`; the one piece of window state. |
| `Lifecycle` | `LauncherKit/Sources/LauncherCore/Lifecycle.swift:124-271` | `@MainActor @Observable`; process stages, builds the `Launcher` (via `makeResident`), routes reopen and quit to it. |
| `SettingsShell` | `LauncherKit/Sources/LauncherUI/SettingsShell.swift:12-169` | `NSObject, NSWindowDelegate`; thin AppKit shell rendering `launcher.window`, sole owner of activation policy, main menu, icon passes, window fitting. |
| `SettingsWindow` | `LauncherKit/Sources/LauncherUI/SettingsWindow.swift:6-30` | `NSWindow` subclass hosting the SwiftUI view in an `NSHostingView<AnyView>`; Escape → `onCancel`. |
| `SettingsView` | `LauncherKit/Sources/LauncherUI/SettingsView.swift:10-67` | Root SwiftUI view: a `VStack` of `FormGroup`s plus the Quit/Close button row. |
| `FormGroup`, `FormRow`, `FormDivider`, `SwitchRow`, `SettingsNotice`, `TintedButtonStyle` | `SettingsView.swift:70-293` | Reusable building blocks/styles of the window. |
| `SwitcherSection`, `SettingRow` | `LauncherKit/Sources/LauncherUI/SwitcherSection.swift:6-39` | The three switch rows of the second group. |
| `LauncherActions` | `LauncherKit/Sources/LauncherUI/LauncherActions.swift:22-34` | Struct of AppKit-only closures views use (icons, Other… chooser, open System Settings pane, quit). |
| `SettingsPane` | `LauncherActions.swift:5-19` | enum of the three System Settings URLs. |
| `AppIcons` | `LauncherKit/Sources/LauncherUI/AppIcons.swift:10-155` | Icon cache; on-main and off-main passes with a `generation` counter. |
| `MoveDialogPresenter` | `LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift:7-44` | Renders `lifecycle.moveDialog` as a modal `NSAlert`. |
| `Copy` | `LauncherKit/Sources/LauncherCore/Copy.swift:4-51` | Every verbatim user-facing string, in core so tests assert them. |
| Ports | `LauncherKit/Sources/LauncherCore/Ports.swift` | `TrackpadHardware`, `TrackpadPreferences`, `SystemActions`, `Permissions`, `AppScanner`, `RunningCopies`, `LoginItem`, `Installer`. |
| `StartAtLogin`, `SettingsStore`, `AppCatalog` | `Lifecycle.swift:72-107`, `Settings.swift:52`, `Apps.swift:155` | Concrete (non-port) types injected into `Launcher`. |
| `AppDelegate` (composition root) | `TrackpadLauncher/TrackpadLauncherApp.swift:17-92` | Builds `Lifecycle`, `MoveDialogPresenter`; builds `Launcher` + `SettingsShell` in `makeResident`. |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Source-scan test: banned tokens, confined tokens, LauncherCore import allow-list. |
| `World` | `LauncherKit/Tests/LauncherCoreTests/World.swift:36-345` | Real `Launcher` over in-memory adapters, a temp dir and a throwaway `UserDefaults` suite. |
| `LifecycleWorld` / `OneProcess` | `LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift` | One Mac with real `Lifecycle` processes building real `Launcher`s. |
| In-memory adapters | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` | `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `FakeWindows`, `InMemoryPermissions`, `InMemoryLoginItem`, `EffectLog`, `InMemoryInstaller`, `InMemoryRunningCopies`, `InMemoryAppScanner`. |

## Flow

### 1. Composition root: where `Launcher` is built and injected

- `TrackpadLauncherApp.main()` (`TrackpadLauncherApp.swift:8-12`) installs `AppDelegate`.
- `applicationWillFinishLaunching` (`:28-39`):
  - `NSApp.disableRelaunchOnLogin()`.
  - `let location = ThisCopy.location()`; `let placement = Placement(build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)` (`:31-33`). Note `Build` is computed here but only `Placement` is kept/passed on.
  - `StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)` (`:34`).
  - `Lifecycle(placement:copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location), startAtLogin:, makeResident: { [unowned self] in makeResident(startAtLogin) })` (`:35-37`).
  - `moveDialog = MoveDialogPresenter(lifecycle: lifecycle)` (`:38`).
- `makeResident(_:)` (`:61-74`) is the only place `Launcher`'s adapters are constructed:
  ```swift
  let catalog = AppCatalog.system
  let actions = WorkspaceActions()
  let launcher = Launcher(
      hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
      system: actions, catalog: catalog, scanner: SystemAppScanner(catalog: catalog),
      store: SettingsStore(defaults: .standard), startAtLogin: startAtLogin)
  shell = SettingsShell(launcher: launcher, quit: { [unowned self] in lifecycle.quit() })
  ```
  The shell is built before `Lifecycle` calls `launcher.start()` (`Lifecycle.swift:246-247`), so the first on-main icon pass (`SettingsShell.swift:23`) finishes before gestures run.
- `Launcher.init` signature (`Launcher.swift:76-80`):
  `init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions, system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore, startAtLogin: StartAtLogin)`.
  `Launcher` receives neither `Placement` nor `Build` today.

### 2. Opening the settings window

Entry points:
- Process start by hand: `applicationDidFinishLaunching` → `lifecycle.launched(launch)` (`TrackpadLauncherApp.swift:42-46`) → `Route` `.runWithWindow` → `replace(others, opensWindow: true, …)` (`Lifecycle.swift:186`) → `copies.stop(…){ othersExited() }` → `othersExited()` builds `makeResident()`, `launcher.start()`, `stage = .resident(launcher)`, then `if opensWindow { launcher.openedByHand() }` (`Lifecycle.swift:244-252`).
- Reopen of running copy (Spotlight, Dock click, Finder): `applicationShouldHandleReopen` → `lifecycle.openedAgain(ThisCopy.opening(of: event))` (`TrackpadLauncherApp.swift:48-53`) → `case (.resident(let launcher), .runWithWindow): launcher.openedByHand()` (`Lifecycle.swift:194`). If the reopen arrives while still `.replacingOthers`, it only flips `opensWindow` to true (`:193`). An `.atLogin` reopen never opens (`Route` `.runSilently`).
- Route table (`Lifecycle.swift:18-25`): `.byHand` + `.installed` or `.development` → `.runWithWindow`; `.byHand` + `.elsewhere` → `.askToMove` (no window).

`Launcher.openedByHand()` (`Launcher.swift:190-204`):
```swift
public func openedByHand() {
    if openings == 0 {
        if isFirstLaunch { startAtLogin.enrol(); if !isAccessibilityGranted { permissions.ask(.accessibility) }; store.save(settings) }
        else { startAtLogin.resume() }
    }
    openings += 1
    window = .open(request: openings)
    resolveRows()
    scanner.scan()
}
```
- It runs on every opening by hand, including when the window is already open (a "bring to front"): `window` goes `.open(request: n)` → `.open(request: n+1)`. There is no `.closed`→`.open` guard: `resolveRows()` and `scanner.scan()` run on every call, open or not. A transition from `.closed` is the only place a "fresh opening" can be told apart (the doc comment at `:46-48` says centring happens only from `.closed`).
- `openings` is `@ObservationIgnored` (`:66`); `window` is `public private(set) var window: Window = .closed` (`:52`) and observed. `isWindowOpen: Bool { window != .closed }` (`:22`).
- Test proof of the request counter: `LifecycleTests.openingAgainShowsTheSameWindowEveryTimeAndClosingKeepsGesturesRunning` (`LauncherCoreTests/LifecycleTests.swift:25-45`) expects history `[.closed, .open(request: 1), .open(request: 2), .open(request: 3), .closed, .open(request: 4)]`.

Shell rendering of `.open` (`SettingsShell.swift:96-116`):
```swift
case .open:
    if !isShown {
        isShown = true
        NSApp.setActivationPolicy(.regular)
        renderIcons()
        fit()
        centre()
    }
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
```
The shell's private `isShown` flag (`:18`) is what distinguishes first show from re-front at the UI level.

### 3. Closing the settings window (every path)

All close paths end in `Launcher.closeWindow()` (`Launcher.swift:206-207`): `public func closeWindow() { window = .closed }` — doc: "Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running." No guard, no side effects besides the state.

| Path | Code |
|---|---|
| Title-bar close button and ⌘W | Window menu item "Close" → `NSWindow.performClose(_:)` (`SettingsShell.swift:89`) → delegate `windowShouldClose(_:)` calls `launcher.closeWindow()` and returns `false` (`:66-69`), so AppKit never closes the window itself. |
| Escape | `SettingsWindow.cancelOperation(_:)` → `onCancel()` (`SettingsWindow.swift:29`); wired `window.onCancel = { [launcher] in launcher.closeWindow() }` (`SettingsShell.swift:33`). |
| *Close* button | `Button("Close") { launcher.closeWindow() }` (`SettingsView.swift:55`). |
| ⌘Q | App menu holds "Close Settings" with key `q`, action `closeSettings(_:)` → `launcher.closeWindow()` (`SettingsShell.swift:71, 74-83`; title `Copy.closeSettings` = "Close Settings", `Copy.swift:24`). There is no Quit menu item at all. |
| Dock icon's *Quit* (and AppleScript / Activity Monitor Quit) | `applicationShouldTerminate` → `lifecycle.shouldEnd(quitSignals.request(for: event))` (`TrackpadLauncherApp.swift:55-57`) → in `.resident`: `guard request == .other, launcher.isWindowOpen else { return true }; launcher.closeWindow(); return false` (`Lifecycle.swift:205-211`). With the window closed, `.other` ends the process. `.system` (logout/restart/shutdown, classified by `QuitSignals.request` from `kAEQuitReason`, loginwindow sender or `willPowerOffNotification`, `QuitSignals.swift:22-33`) always ends. |
| *Quit Trackpad Launcher* button | NOT a close: `Button(Copy.quitButton, action: actions.quit)` (`SettingsView.swift:53`) → `LauncherActions.quit` → closure from composition root `{ lifecycle.quit() }` (`TrackpadLauncherApp.swift:68`, `SettingsShell.swift:167`) → `Lifecycle.quit()` (`Lifecycle.swift:225-230`): `guard case .resident = stage`; `startAtLogin.suspend()`; `end()` → `stage = .ending; copies.endThisCopy()` → `NSApp.terminate(nil)` (`SystemRunningCopies.swift:47`) → `applicationShouldTerminate` → `shouldEnd` sees `.ending` → `true`. The window is left `.open` in the model (test `theQuitButtonEndsTheProcessAtOnceWithTheWindowOpen`, `LifecycleTests.swift:148-157`). |

Shell rendering of `.closed` (`SettingsShell.swift:98-103`):
```swift
case .closed:
    guard isShown else { return }
    isShown = false
    if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
    window.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
```
The Other… chooser sheet is cancelled on close. `setActivationPolicy` is confined to `SettingsShell.swift` by the source-scan test (`SourcePolicyTests.swift:117-119`). `LSUIElement: true` is set in `project.yml:39`.

How open/close reaches the model: only via `Launcher` intents (`openedByHand()`, `closeWindow()`) and `Lifecycle` (`openedAgain`, `shouldEnd`). There is no `isSettingsWindowOpen` callback, no session object, no `onClose` hook from model to anything else. The shell observes `launcher.window` with `Observations` (see §5). Nothing in the model is notified of "the window closed" except the state write itself.

### 4. Work started on each opening, and what happens to late results

Today two pieces of work start per opening; neither is dropped on close:

a) **App list refresh (recent apps)**: `scanner.scan()` in `openedByHand()` (`Launcher.swift:203`).
   - Port: `AppScanner` (`Ports.swift:141-148`): `var onScan: (@MainActor (InstalledApps) -> Void)? { get set }`; `func scan()` "Returns at once. Requests made while a scan runs coalesce into exactly one more scan after it."
   - Wiring: in `start()`: `scanner.onScan = { [unowned self] in installedApps = $0 }` (`Launcher.swift:109`).
   - Real adapter `SystemAppScanner.scan()` (`LauncherPlatform/SystemAppScanner.swift:21-39`):
     ```swift
     public func scan() {
         guard !isScanning else { isScanPending = true; return }
         isScanning = true
         Task { [catalog] in
             let installed = await Self.read(catalog)
             finishScan(installed)
         }
     }
     @concurrent private static func read(_ catalog: AppCatalog) async -> InstalledApps { catalog.installedApps() }
     ```
     The unstructured `Task` inherits `@MainActor` from the class; the `@concurrent` static runs off-main; `finishScan` runs back on main and calls `onScan`.
   - Late result handling: none. A scan finishing after close still replaces `installedApps` (desired: list stays fresh; `RecentAppsTests.installsAndRemovalsShowUpWhileTheWindowIsClosed`, `RecentAppsTests.swift:138-155`). No Task handle is kept, nothing is cancelled.
   - Tests: `openingTheWindowRefreshesTheRecentApps` (`RecentAppsTests.swift:105-121`), `theLastKnownListStaysUntilANewScanArrives` uses `world.scanner.holdScans()` / `deliverHeldScan()` (`:123-136`), `onlyStartAndOpeningTheWindowRequestAScan` asserts `scanner.scanRequests` (`:157-178`).

b) **Icon pass**: on `.closed`→`.open` only, `SettingsShell.render` calls `renderIcons()` (`SettingsShell.swift:108`) → `icons.renderOffMainActor(Self.iconTargets(launcher))` (`:126`). Also on every `installedApps` change (`:47-52`).
   - `AppIcons.renderOffMainActor(_:)` (`AppIcons.swift:75-89`): fire-and-forget `Task { await renderOffMainActor(urls:) }`; the async version snapshots `generation`, awaits `@concurrent renderChangedOffMain`, then `guard generation == self.generation else { return }` before merging. `removeAll()` bumps `generation` (`:97-100`). The settings shell never calls `removeAll()` (only `SwitcherPresenter.stopIconPasses()` does, `SwitcherPresenter.swift:75`), so window close does not drop a pass.

Existing late-result-discard patterns in the codebase (none tied to window close):
- Generation counter: `AppIcons.generation` (above); `OverlayPanel.generation` (`LauncherUI/OverlayPanel.swift:25, 54, 97-105`); `MultitouchTrackpads` `let generation = runs … guard let self, self.runs == generation else { return }` (`LauncherPlatform/MultitouchTrackpads.swift:84, 100`).
- Serial + cancellable Task handle: `WindowSwitcherPresenter` keeps `private var capture: Task<Void, Never>?` and `shownSerial`; on dismiss `capture?.cancel(); capture = nil; shownSerial = nil`; in the task `guard let self, shownSerial == serial else { return }` and `guard let self, !Task.isCancelled, shownSerial == serial else { return }` (`LauncherUI/WindowSwitcherPresenter.swift:38-45, 82-98`). The serial is model-issued (`Launcher.windowSwipesBegun`, `Launcher.swift:57, 332-337`; `WindowSwitcher.serial`, `WindowSwitcher.swift:76`).
- Model-side state guard for late port callbacks: `Launcher.progress(_:of:)` — `guard let bounce = bounces[app] else { return }` ("A report for an app whose bounce ended finds no record: a late window plays nothing", `Launcher.swift:276-278`). `Lifecycle.installed(_:)` — `guard case .moving(let resident) = stage else { return }` (`Lifecycle.swift:257-258`); `Lifecycle.othersExited()` — `guard case .replacingOthers(…) = stage else { return }` (`:244-245`). This "guard on the current stage/record" is the model's way to ignore a completion that no longer applies; there is no Task handle in LauncherCore anywhere (grep for `Task` in `Sources/LauncherCore` finds none).

### 5. Model state the views read, and how intents are forwarded

There is no view model and no section/value types for the window: views hold `let launcher: Launcher` (the `@Observable` model) directly and read its properties; SwiftUI observation tracks reads.

Public observable state read by the settings window (`Launcher.swift`):
- `rows: [GestureRow]` (`:11`) — `ForEach(launcher.rows)` (`SettingsView.swift:17`).
- `installedApps: InstalledApps` (`:21`) — app pickers (`SettingsView.swift:135`).
- `handMode` (`:23`), `isLaunchAnimationOn` (`:24`), `isSwipeOn` (`:25`), `isSwapOn` (`:26`), `isWindowSwipeOn` (`:27`) — computed from private `settings`.
- `activity: GestureActivity` (`:29-31`) — derived; `if case .inactive(let cause) = launcher.activity` (`SettingsView.swift:33`).
- `isAccessibilityGranted` (`:34`) — `if !launcher.isAccessibilityGranted` (`SettingsView.swift:38`).
- `screenRecordingHint: ScreenRecordingHint?` (`:39-42`) — `if let hint = launcher.screenRecordingHint` (`SettingsView.swift:43`). `ScreenRecordingHint` is `enum { case ask, openSettings }` (`ScreenRecordingHint.swift`); this is the closest existing precedent for a small core enum that a view switches on to pick a button's behaviour.
- `window: Window` (`:52`) and `isWindowOpen` (`:22`) — read by the shell and `Lifecycle`, not the SwiftUI view.

Intents (button presses) are direct method calls on `launcher` from view closures, or SwiftUI `Binding(get:set:)` wrappers:
- `Binding(get: { launcher.isLaunchAnimationOn }, set: { launcher.setLaunchAnimation(on: $0) })` (`SettingsView.swift:24-25`); same pattern for `setSwipe`, `setWindowSwipe`, `setSwap` (`SwitcherSection.swift:12, 16, 20`).
- `launcher.setAssignment($0, for: row.gesture)` (`SettingsView.swift:138-139`); `launcher.setHandMode(...)` via `ThumbPicker.Coordinator` (`:238`).
- `launcher.askForScreenRecording()` (`:46`); `launcher.closeWindow()` (`:55`).
- AppKit-only effects go through `LauncherActions` closures built in `SettingsShell.makeActions` (`SettingsShell.swift:149-168`): `cachedIcon`, `icon`, `chooseOtherApp` (NSOpenPanel sheet), `openSettings` (`NSWorkspace.shared.open(pane.url)`), `quit` (passed in from the composition root). The view therefore cannot reach `Lifecycle`; Quit is an opaque closure.

Shell-level observations (`SettingsShell.swift:36-58`), using the Observation framework's `Observations` async sequence in long-lived `Task`s stored in `observations: [Task<Void, Never>]` and cancelled in `isolated deinit` (`:61-63`):
```swift
for await _ in Observations({ (launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn, launcher.screenRecordingHint) }) { self?.refit() }
for await _ in Observations({ launcher.installedApps }) { self?.renderIcons() }
for await state in Observations({ launcher.window }) { self?.render(state) }
```
`MoveDialogPresenter` uses the same pattern over `lifecycle.moveDialog` (`MoveDialogPresenter.swift:11-16`).

### 6. SwiftUI view hierarchy and styling

`SettingsView.body` (`SettingsView.swift:14-66`), top to bottom inside `VStack(spacing: 10)`:
1. `FormGroup { ForEach(launcher.rows) { GestureRowView; FormDivider() }; FormRow { SwitchRow("Animate app launch", …) } }` (`:16-27`) — the five gesture rows + launch animation switch. This is the current first group.
2. `FormGroup { SwitcherSection(launcher:) }` (`:28`) — "Switch recent", "Switch windows", "Toggle recent" (`SwitcherSection.swift:10-20`).
3. `FormGroup { ThumbPicker(launcher:).padding(.vertical, 8) }` (`:29-32`) — `NSSegmentedControl` wrapper.
4. Conditional groups, each a `SettingsNotice` (which is itself a `FormGroup`), shown by plain `if` in the ViewBuilder (no transition/animation):
   - `if case .inactive(let cause) = launcher.activity` → trackpad settings notice (`:33-37`).
   - `if !launcher.isAccessibilityGranted` → Accessibility hint (`:38-42`).
   - `if let hint = launcher.screenRecordingHint` → screen recording hint, button switches on `hint` (`:43-50`).
5. `HStack(spacing: 8) { Spacer(minLength: 0); Button(Copy.quitButton, action: actions.quit).buttonStyle(TintedButtonStyle(tint: .red)); Button("Close") { launcher.closeWindow() }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 6)) }.padding(.top, 10)` (`:51-59`). "Close" is a literal, not in `Copy`; `Copy.quitButton` = "Quit Trackpad Launcher" (`Copy.swift:12`).

Modifiers on the whole stack (`:61-65`): `.font(.system(size: 13, weight: .medium))`, `.padding(16)`, `.frame(width: 326)`, `.fixedSize(horizontal: true, vertical: false)`.

Width: the code says 326, not 266. `.padding(16)` is applied before `.frame(width: 326)`, so the window's content view is 326 pt wide and the groups' column is 326 − 2×16 = 294 pt wide. The doc comment (`:5`) reads "One 326 pt column, 16 pt inside the window". The "266 pt" in commit `efee3a6` ("The settings window is 266 pt wide") changed the old `LauncherView.swift` (menu bar popover) from 270 to 266; that file no longer exists — `c9125b6` (#28) replaced it with the settings window at 326.

Styling constants:
- `FormGroup` (`:70-78`): `VStack(spacing: 0) { content }.padding(.horizontal, 10).background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))` — group corner radius 12, 10 pt horizontal inset, no vertical padding (rows provide height).
- `FormRow` (`:81-89`): `HStack(spacing: 0)`, `.padding(.vertical, 2)`, `.frame(maxWidth: .infinity, minHeight: 42)`.
- `FormDivider` (`:92-98`): 1 pt `Rectangle` filled `.quinaryLabel`.
- `SwitchRow` (`:101-115`): `Toggle` `.switch` style, `.controlSize(.mini)`, labels hidden, title leading.
- `SettingsNotice` (`:255-276`): inside `FormGroup`, `VStack(alignment: .leading, spacing: 8) { Text(message).font(.system(size: 11)).lineSpacing(1)…fixedSize(horizontal: false, vertical: true); Button(button, action: open).buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 6)) }.padding(.vertical, 8).frame(minHeight: 42)`. Text above, button below, left-aligned (not a text-left/button-right row).
- `TintedButtonStyle` (`:279-293`): label 13 pt medium in `tint`, `.padding(.horizontal, 16)`, `.frame(height: 24)`, background `RoundedRectangle(cornerRadius: 6).fill(tint.mix(with: .black, by: 0.1).opacity(configuration.isPressed ? 0.3 : 0.2))`. It reads no `isEnabled` environment value, so `.disabled(true)` on the Quit button would block the action but would not grey its look unless the style is changed.
- No `ProgressView`, `NSProgressIndicator`, `.disabled(`, `withAnimation`, `.animation(` or `.transition(` anywhere in `LauncherUI` or the app target (grep). There is no existing progress UI or disabled-button styling.

Window resizing when a group appears (`SettingsShell.swift:128-138`):
```swift
private func fit() {
    let top = window.frame.maxY
    window.setContentSize(window.contentFittingSize)
    window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
}
private func refit() { guard isShown else { return }; fit() }
```
- `contentFittingSize` = `hosting?.fittingSize` (`SettingsWindow.swift:26`). The top edge stays put; the window grows/shrinks downward, with no animation.
- `refit()` runs only when the tuple `(activity, isAccessibilityGranted, isSwipeOn, screenRecordingHint)` changes (`SettingsShell.swift:38-45`) — i.e. exactly the inputs of the three conditional groups (plus `isSwipeOn`). Any new conditional group (e.g. an update card) only resizes the window if its driving state is added to this tuple (or `fit()` is otherwise called). `fit()` also runs on each `.closed`→`.open` (`:109`).
- `centre()` (`:141-147`) centres on `Displays.screen(under: NSEvent.mouseLocation)`'s visible frame, only on first show.
- `SettingsWindow` (`SettingsWindow.swift:11-17`): style `[.titled, .closable, .miniaturizable]`, title "Trackpad Launcher", `isReleasedWhenClosed = false`, `.normal` level; the hosting view is built once and kept (`:19-23`).

### 7. Ports in LauncherCore (all in `LauncherKit/Sources/LauncherCore/Ports.swift`)

Every port is `@MainActor public protocol …: AnyObject`. None uses `async`; delivery is either a settable `@MainActor` callback property or an `@escaping @MainActor` completion parameter.

| Port | Lines | Members | Delivery | Real adapter (LauncherPlatform) | In-memory adapter (tests) |
|---|---|---|---|---|---|
| `TrackpadHardware` | 26-46 | `var onEvent: (@MainActor (TrackpadEvent) -> Void)?`; `connected() -> [Trackpad]`; `run(_:handMode:blockClicks:slides:swaps:)`; `playFeedback(_:on:)`; `confirmWindowSwipe(on:)` | push callback | `MultitouchTrackpads` | `InMemoryTrackpads` (`InMemoryAdapters.swift:6-243`) |
| `TrackpadPreferences` | 49-54 | `var onChange: (@MainActor () -> Void)?`; `current() -> [TrackpadKind: TrackpadPreferenceValues]` | push callback | `SystemTrackpadPreferences` | `InMemoryTrackpadPreferences` (`:245-258`) |
| `SystemActions` | 57-123 | `bringToFront`, `prepareLaunchAnimations(for:)`, `playLaunchAnimation(for:)`, `hasProcess(_:) -> Bool`, `bringToFrontBouncing(_:cap:)`, `limitLaunchBounce(of:to:)`, `endLaunchBounce(of:with:)`, `var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?`, `runningApps() -> RunningApps`, `frontmostWindows() -> FrontmostWindows`, `raiseWindows(_:)` | sync calls + push callback | `WorkspaceActions` | `RecordingSystemActions` (`:260-339`) + `FakeWindows` (`:344-425`) |
| `Permissions` | 131-139 | `var onChange: (@MainActor () -> Void)?`; `isGranted(_:) -> Bool`; `ask(_:)` | push callback | `SystemPermissions` | `InMemoryPermissions` (`:427-454`) |
| `AppScanner` | 142-148 | `var onScan: (@MainActor (InstalledApps) -> Void)?`; `scan()` | push callback, off-main work | `SystemAppScanner` | `InMemoryAppScanner` (`:624-659`) |
| `RunningCopies` | 151-160 | `others() -> [RunningCopy]`; `stop(_:then exited: @escaping @MainActor () -> Void)`; `endThisCopy()` | completion | `SystemRunningCopies` | `InMemoryRunningCopies` (`:575-621`) |
| `LoginItem` | 163-171 | `var isOn: Bool { get }`; `@discardableResult register() -> Bool`; `unregister()` | sync | `SystemLoginItem` | `InMemoryLoginItem` (`:456-516`) |
| `Installer` | 174-186 | `install(then done: @escaping @MainActor (InstallOutcome) -> Void)`; `removeOriginal()`; `openInstalledCopy()`; `eject(_:)` | completion, off-main work | `ApplicationsInstaller` | `InMemoryInstaller` (`:524-571`) |

`Launcher` uses the first five (+ concrete `AppCatalog`, `SettingsStore`, `StartAtLogin`); `Lifecycle` uses `RunningCopies`, `Installer` (+ `StartAtLogin`, which wraps `LoginItem`).

Rule from `docs/architecture.md:14`: "Every port has exactly two adapters: the real one in `LauncherPlatform` and an in-memory one in the tests. Concrete types that can be pointed at a temp directory or a throwaway `UserDefaults` suite are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous." Also `:13`: framework/wire types never cross a port; external data is parsed into domain types at the adapter.

Real-adapter async pattern (completion port): `ApplicationsInstaller.install` (`LauncherPlatform/ApplicationsInstaller.swift:22-30`):
```swift
public func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
    let location = location; let applications = applications; let administrator = administrator
    Task {
        let outcome = await Self.copy(location, into: applications, by: administrator)
        done(outcome)
    }
}
@concurrent private static func copy(...) async -> InstallOutcome { ... }   // :70-98
```
Off-main work in a `@concurrent` static; only the result hops back to the main actor. Internal test seams inside a real adapter are non-port, internal protocols (`protocol Administrator: Sendable`, `PrivilegedInstall.swift:7`; `protocol TapLink`, `FrameStream.swift:12`), with an `init` for tests taking a temp folder (`ApplicationsInstaller.swift:15-20`).

How ports that deliver asynchronously keep model tests synchronous — the in-memory adapter delivers inline or holds the callback until the test releases it:
- `InMemoryInstaller` (`InMemoryAdapters.swift:523-553`):
  ```swift
  /// Holds `done` until a row releases an outcome, and records its calls in the shared log.
  func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
      installCalls += 1; log?.entries.append("install"); held = done
  }
  func release(_ outcome: InstallOutcome) {
      guard let done = held else { return }
      held = nil
      if outcome == .installed { onEffect?(); onInstalled?(); onEffect?() }
      done(outcome)
  }
  ```
  plus `var isHolding: Bool { held != nil }`.
- `InMemoryAppScanner` (`:623-659`): `scan()` delivers `onScan?(catalog.installedApps())` synchronously unless `holdScans()` was called; `deliverHeldScan()` releases it; `foldersChanged()` stands in for the FSEvents push; `scanRequests` counts calls.
- `InMemoryRunningCopies` (`:573-621`): `stop` stores `exited` and fires it synchronously only when nothing is left to wait for; `letExit(_:)` / `letStoppedCopiesExit()` release; `deliverExitAgain()` replays a duplicate push; `endThisCopy()` asks `lifecycle?.shouldEnd(.other)` as `NSApp.terminate` would.
- `RecordingSystemActions.report(_:for:)` (`:336-338`) pushes `onLaunchProgress` inline: "A test withholds a report by not calling this, delivers one late by calling it after the end".
- Hooks `onEffect` / `onAsk` / `onRegister` / `onInstalled` run inside a call so a test can snapshot state at that instant (crash-consistency tests).

Test files/helpers for `Launcher` (all `@MainActor @Suite struct …` using Swift Testing):
- `World` (`World.swift:36-223`): builds `Launcher` over `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `RecordingSystemActions`, `InMemoryPermissions`, a real `AppCatalog` over temp folders, `InMemoryAppScanner`, a real `SettingsStore` on a temp-path `UserDefaults` suite, and a real `StartAtLogin` over `InMemoryLoginItem` (`:60-97, 99-107`). Placement for StartAtLogin defaults to `.installed` (`:118-125`). `relaunch()` makes a second `Launcher` on the same suite (`:214-222`). Helpers: `install`, `recordLaunch`, `app`, `tap`, `swipe`, `windowSwipe`, `swap`, `switcherWorld`, `windowWorld`.
- `LifecycleWorld` / `OneProcess` (`LifecycleWorld.swift`): one Mac + processes; each `OneProcess` has its own `InMemoryRunningCopies`, `InMemoryInstaller`, hardware, system; records `history: [Launcher.Window]` after each intent (`:99-100, 129-181`); `EffectLog` orders login item/copies/installer calls; `snapshots` taken around each effect.
- Window-related tests: `LauncherTests.swift`, `LifecycleTests.swift`, `RecentAppsTests.swift`, `PersistenceTests.swift`, `ActivityTests.swift`, `WindowSwitchingTests.swift`, `LaunchBounceFiringTests.swift`, `MoveToApplicationsTests.swift`, `ReplacingOtherCopiesTests.swift`, `StartAtLoginTests.swift`. Strings: `CopyTests.swift` asserts `Copy` values verbatim.
- Real adapters are tested in `LauncherPlatformTests` (e.g. `ApplicationsInstallerTests.swift` bridges the completion with `withCheckedContinuation`, `:8-12`, and uses `@testable import LauncherPlatform`).
- Package (`LauncherKit/Package.swift`): targets `LauncherCore`, `LauncherPlatform` (deps Core), `LauncherUI` (deps Core only, `.defaultIsolation(MainActor.self)`), test targets `LauncherCoreTests` (Core only) and `LauncherPlatformTests`. No UI test target. `Scripts/test.sh` runs `swift test`.

### 8. Source-scan test (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`)

Structure:
```swift
struct Entry: Sendable, CustomTestStringConvertible { let token: String; let rule: String }   // :7-11
static let banned: [Entry] = [ ... ]                                                        // :13-70
struct Confined: Sendable, CustomTestStringConvertible { let token: String; let onlyIn: Set<String>; let rule: String }  // :73-79
static let confined: [Confined] = [ ... ]                                                   // :81-150
```
- Scanned roots: `LauncherKit/Sources` and the app target dir `TrackpadLauncher` (`:156-162`). Tests are not scanned.
- Matching is plain substring `line.contains(token)` per line, case-sensitive, comments included (`:265-272`). Confinement is by file `lastPathComponent` (`:266`).
- `@Test(arguments: banned) func noSourceUses` (`:164-168`); `@Test(arguments: confined) func onlyItsAdapterUses` (`:170-174`); self-tests of the scanner (`:176-220`); `coreImportsOnlyFoundationAndObservation` with `coreAllowedImports: Set<String> = ["Foundation", "Observation"]` (`:222-228`).
- Header doc (`:4-5`): "Scans every Swift source file the app ships for APIs the product promises never to use. To forbid something new, add it to `banned`; do not write prose."

Banned list, by rule:
- log: `print(`, `debugPrint(`, `dump(`, `NSLog(`, `os_log`, `Logger(`, `import OSLog`, `import os` (`:14-21`).
- network: `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream` (`:22-26`). There is no confinement entry for any network API — they are banned everywhere, in every file.
- own files: `FileHandle(forWriting`, `.write(to:`, `createFile(atPath` (`:27-29`).
- timer: `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink`; polling: `Task.sleep` (`:30-35`). (`Timer` is a substring match, so any identifier containing "Timer" fails.)
- Input Monitoring/event posting, keyboard, `ScrollWheel`, synthesising events (`:36-52`).
- `nonisolated(unsafe)` ("one writer per field"), `perform: {` (`:53-56`).
- window switcher / previews: `AXUIElementSetAttributeValue`, `kAXPressAction`, `SCStream(`, `SCRecordingOutput`, `CGImageDestination`, `representation(using`, `tiffRepresentation` (`:57-63`).
- `NSStatusBar`, `NSStatusItem` ("no menu bar icon") (`:64-65`).
- `SMAppService.agent`, `SMAppService.daemon`, `SMAppService.loginItem`, `SMLoginItemSetEnabled` ("nothing relaunches the app") (`:66-69`).

Confined list highlights relevant to updates:
- `SecCode`, `SecStaticCode`, `SecRequirement` only in `CodeSignature.swift` ("the code signature is read in one place") (`:111-113`).
- `/bin/mv`, `/bin/rm` only in `PrivilegedInstall.swift`; `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` only in `PrivilegedInstall.swift` (`:114-115, 139-143`).
- `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `quarantinePropertiesKey` only in `BundleInstall.swift` ("the move's file operations are in one file") (`:132-138`).
- `forceTerminate` and `.terminate(` only in `SystemRunningCopies.swift` (`:129-131`).
- `setActivationPolicy` only in `SettingsShell.swift` (`:117-119`); `runModal` only in `MoveDialogPresenter.swift` (`:148`).
- `statfs`, `DADisk`, `unmountVolume` only in `DiskImages.swift`; `SecTranslocate` only in `ThisCopy.swift`; `currentAppleEvent` only in `ThisCopy.swift`, `TrackpadLauncherApp.swift`; `kAEQuitReason` only in `QuitSignals.swift`; `SMAppService` only in `SystemLoginItem.swift`; `disableRelaunchOnLogin` only in `TrackpadLauncherApp.swift`.

Architecture prose that accompanies it (`docs/architecture.md:27`): "No network code of any kind, no logging of any kind (`print`, `NSLog`, `os_log`, `Logger`), no files written other than settings in `UserDefaults`, and the app's own bundle copied into /Applications when the user chooses *Move to Applications* … A source-scan test in `LauncherCoreTests` fails the build on any banned API; add to its list rather than adding prose." And `:20`: "No timers, no polling, no background loops: every input is a push".

## Files Read

- `plans/022-in-app-updates/plan.md`
- `plans/022-in-app-updates/development-logs.md` (head)
- `docs/architecture.md`
- `docs/domain-model.md` (grep of settings window / quit / hint entries: lines 6, 12, 15, 18, 20-21, 24, 101-102, 111, 125-126, 160-164)
- `docs/product-overview.md`
- `TrackpadLauncher/TrackpadLauncherApp.swift`
- `LauncherKit/Package.swift`
- `LauncherKit/Sources/LauncherCore/Launcher.swift`
- `LauncherKit/Sources/LauncherCore/Lifecycle.swift`
- `LauncherKit/Sources/LauncherCore/Ports.swift`
- `LauncherKit/Sources/LauncherCore/Placement.swift`
- `LauncherKit/Sources/LauncherCore/Copy.swift`
- `LauncherKit/Sources/LauncherCore/ScreenRecordingHint.swift`
- `LauncherKit/Sources/LauncherUI/SettingsShell.swift`
- `LauncherKit/Sources/LauncherUI/SettingsView.swift`
- `LauncherKit/Sources/LauncherUI/SettingsWindow.swift`
- `LauncherKit/Sources/LauncherUI/LauncherActions.swift`
- `LauncherKit/Sources/LauncherUI/SwitcherSection.swift`
- `LauncherKit/Sources/LauncherUI/AppIcons.swift`
- `LauncherKit/Sources/LauncherUI/MoveDialogPresenter.swift`
- `LauncherKit/Sources/LauncherUI/WindowSwitcherPresenter.swift` (lines 1-100)
- `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift` (lines 60-100)
- `LauncherKit/Sources/LauncherUI/AppPicker.swift` (lines 80-95)
- `LauncherKit/Sources/LauncherPlatform/SystemAppScanner.swift`
- `LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift` (lines 1-99)
- `LauncherKit/Sources/LauncherPlatform/QuitSignals.swift`
- `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift`
- `LauncherKit/Sources/LauncherPlatform/ThisCopy.swift` (lines 1-30)
- `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` (lines 70-110)
- `LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift` (grep)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift`
- `LauncherKit/Tests/LauncherCoreTests/World.swift`
- `LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift`
- `LauncherKit/Tests/LauncherCoreTests/LifecycleTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/RecentAppsTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift` (lines 1-120)
- `LauncherKit/Tests/LauncherCoreTests/CopyTests.swift`
- `LauncherKit/Tests/LauncherCoreTests/Fixtures.swift` (head)
- `LauncherKit/Tests/LauncherPlatformTests/ApplicationsInstallerTests.swift` (head)
- `Scripts/test.sh`
- `git show efee3a6` (width history)

## Boundaries

- In: AppKit signals at `AppDelegate` (`applicationDidFinishLaunching`, `applicationShouldHandleReopen`, `applicationShouldTerminate`) → `Lifecycle` intents → `Launcher.openedByHand()` / `closeWindow()`. Window chrome/keyboard (close button, ⌘W, Escape, ⌘Q menu item) → `SettingsShell`/`SettingsWindow` → `Launcher.closeWindow()`. View buttons → `Launcher` intents or `LauncherActions` closures.
- Out: `Launcher.window` → `SettingsShell.render` (orderOut / makeKeyAndOrderFront / activation policy). `Launcher` observable properties → `SettingsView` (SwiftUI observation) and `SettingsShell.refit`/`renderIcons`.
- `LauncherActions.quit` is the only path from the window into `Lifecycle` (closure injected at the composition root). The view and the shell hold no reference to `Lifecycle`; `Launcher` holds none either.
- `Launcher` ↔ platform: only through the five ports + `AppCatalog`, `SettingsStore`, `StartAtLogin`. `Lifecycle` ↔ platform: `RunningCopies`, `Installer`, `StartAtLogin`, `Placement`.
- Build/placement facts enter only at `applicationWillFinishLaunching` (`Placement(build:location:)`), passed to `Lifecycle` and `StartAtLogin`, not to `Launcher`.

## Non-Obvious Things

1. **`openedByHand()` is also the "bring to front" path.** It runs for every opening by hand whether the window is open or closed, increments `openings`, sets `.open(request: n+1)`, re-resolves rows and requests a scan each time (`Launcher.swift:190-204`). "Window opened from closed" is not represented by any method; only the prior value of `window` (`.closed`) distinguishes it in the model, and `isShown` in the shell. Plan R1's "Reopening an open window → no second update check" contrasts with today's scan, which does re-run on a re-front.
2. **Nothing is dropped on close today.** `closeWindow()` only writes `window = .closed`. The scan and the icon pass started by an opening complete and apply after close by design. No `Task` handle exists anywhere in `LauncherCore`; late-result discard in the model is done by guarding on current state (`bounces[app]`, `Lifecycle.stage`), and in the UI/platform by generation/serial counters and `Task.cancel()`.
3. **⌘Q is not Quit.** The app menu's only item is "Close Settings" bound to `q`; there is no `terminate:` menu item. The Dock's Quit arrives as `applicationShouldTerminate` and `Lifecycle.shouldEnd(.other)` turns it into `closeWindow()` only while the window is open; with the window closed an `.other` quit ends the process (`Lifecycle.swift:205-211`). The only true quit from the UI is the red button, through `Lifecycle.quit()`, which also suspends start at login.
4. **Quit button cannot currently be disabled visually.** `TintedButtonStyle` (`SettingsView.swift:279-293`) ignores `isEnabled`; no `.disabled` is used anywhere.
5. **The window resizes only on specific state changes.** `refit()` is driven by `Observations` of a fixed tuple `(activity, isAccessibilityGranted, isSwipeOn, screenRecordingHint)` (`SettingsShell.swift:38-45`). A new conditional group whose driving state is not in that tuple will change SwiftUI's content but not the `NSWindow` frame. `fit()` pins the top edge, so content added at the top pushes everything below down and grows the window downward; no animation.
6. **Width is 326, not 266.** The commit message "The settings window is 266 pt wide" (`efee3a6`) applied to the deleted menu-bar `LauncherView.swift`. Current: `.padding(16).frame(width: 326)` → 326 pt content, 294 pt group column (`SettingsView.swift:63-64`).
7. **Notices are text-over-button.** `SettingsNotice` stacks message (11 pt) above a bordered button, left-aligned; the plan's card is text-left/button-right in one row, which no existing component does.
8. **`Placement.installed` does not imply release.** `Placement.init` returns `.installed` for any build inside /Applications (`Placement.swift:42-50`); `.development` is only a dev build outside /Applications. Release-ness comes from `CodeSignature.buildOfThisProcess`, which also returns `.release` for an unsigned build launched with `--as-release-build` (`CodeSignature.swift:11-22`). Today `Build` is computed in `applicationWillFinishLaunching` and discarded after building `Placement`.
9. **`Launcher` knows nothing about the process.** It does not know its placement, build, `Lifecycle`, or quit. `Lifecycle.launcher` exposes the resident for stages `.resident`, `.askingToMove`, `.moving`, `.moveFailed` (`Lifecycle.swift:149-155`). `Lifecycle.quit()` acts only in `.resident`.
10. **Source scan is substring-based and covers comments.** E.g. a doc comment containing the word `URLSession` or `Timer` fails the build; `removeItem(` anywhere outside `BundleInstall.swift` fails (World's `removeItem` is in tests, which are not scanned). Network APIs have no confinement escape hatch — they are on `banned`, so any network adapter requires changing the list (moving entries from `banned` to `confined`). `.write(to:` is banned outright (own files). `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource` are banned, relevant to plan R12's 30-second stall rule.
11. **`LauncherCore` may import only Foundation and Observation** (`SourcePolicyTests.swift:222-228`), so any version parsing / release-list parsing / update state machine in core must be Foundation-only.
12. **`Copy` holds window strings; "Close" is a literal** in `SettingsView.swift:55`, as are the switch titles in `SwitcherSection`. `CopyTests` asserts the `Copy` constants verbatim.
13. **`SettingsShell` is not `@MainActor`-annotated explicitly** but `LauncherUI` has `.defaultIsolation(MainActor.self)` (`Package.swift:15-19`); its `deinit` is `isolated deinit`.
14. **First icon pass is on-main and blocking** at shell construction (`SettingsShell.swift:23`), deliberately before gestures start (`TrackpadLauncherApp.swift:59-60`, `docs/architecture.md:19`).

## Open Questions

- Whether `@Observable`'s setter emits a change when `closeWindow()` writes `.closed` over `.closed` was not verified; the shell's `isShown` guard makes it harmless today.
- Why `isSwipeOn` is in the refit tuple (`SettingsShell.swift:40-41`) when no conditional group depends on it directly was not traced (possibly historical; `screenRecordingHint` already covers `isWindowSwipeOn`).
- `SystemRunningCopies.stop` / `endThisCopy` internals, `PrivilegedInstall`, `BundleInstall`, the release script and xcconfig versioning were outside this angle and only skimmed via grep.
- No Figma design was inspected; the card's exact measurements are not grounded here.
