# Grounding: observing other apps' lifecycle and windows

Angle: every place the codebase observes or reads other apps (workspace notifications, running-app reads, window reads, bring to front), how pushes reach the model, how tests fake them, and what is push vs. would need polling. All paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/017-launch-wait-bounce/`.

## Components Found

| Component | File | What it does |
|---|---|---|
| `SystemActions` (port) | `LauncherKit/Sources/LauncherCore/Ports.swift:57-81` | Effects the core decides and macOS performs: `bringToFront`, `registerLoginItem`, `prepareLaunchAnimations`, `playLaunchAnimation`, `runningApps`, `frontmostWindows`, `raiseWindows`. All synchronous, all `Void` or a value read now. **No push member** (no `onX` closure) today. |
| `WorkspaceActions` (real `SystemActions`) | `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` | `@MainActor public final class`; owns `LaunchOverlay`, `RunningAppsReader`, `FrontmostAppWindows`; `bringToFront` = `NSWorkspace.openApplication` with completion ignored. |
| `RunningAppsReader` | `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift` | The read behind `runningApps()`: frontmost via `NSWorkspace.shared.frontmostApplication`, apps via `LaunchServicesOrder` or (fallback) `NSWorkspace.shared.runningApplications` + `ActivationTracker`. |
| `LaunchServicesOrder` | `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift` | `dlsym`s `_LSCopyApplicationArrayInFrontToBackOrder` and `_LSCopyApplicationInformation`; returns ⌘-Tab apps (only `ApplicationType == "Foreground"`). |
| `FallbackOrder` | `LauncherKit/Sources/LauncherPlatform/FallbackOrder.swift` | Pure ordering of pids when the LS order is missing: recency, then launch date. |
| `ActivationTracker` | `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift` | Observes `NSWorkspace.didActivateApplicationNotification`; keeps a pid recency list. Only constructed on the fallback path. |
| `RunningApp` | `LauncherKit/Sources/LauncherPlatform/RunningApp.swift` | "The one place a running app's `AppEntry` is built" from `NSRunningApplication` or LS info. |
| `FrontmostAppWindows` | `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift` | The only file allowed to touch the AX element API and `CGWindowList`; reads/raises the **frontmost** app's windows. |
| `SwitcherPresenter` | `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift` | The only observer of `didLaunchApplicationNotification` / `didTerminateApplicationNotification`; uses them only to keep the switcher icon cache warm. Not a port; never reaches the model. |
| `AppIcons.icon(forSwitcher:)` | `LauncherKit/Sources/LauncherUI/AppIcons.swift:49-63` | Reads `NSRunningApplication.runningApplications(withBundleIdentifier:)` to borrow a running app's loaded icon. |
| `MultitouchTrackpads` wake observer | `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift:48-52` | `NSWorkspace.didWakeNotification` -> `onEvent?(.trackpadsChanged)`. |
| `LaunchOverlay` | `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift` | Plays the launch animation; one panel per play, closed from `CATransaction` completion block. Reads `NSEvent.mouseLocation` once at play. |
| Domain types | `LauncherKit/Sources/LauncherCore/Apps.swift:12-50`, `LauncherKit/Sources/LauncherCore/WindowSwitcher.swift:5-33` | `AppEntry {bundleID, name, url}`, `RunningApps {frontmost, apps}` + `contains(_ location: URL)`, `WindowID {rawValue: UInt32}`, `AppWindow`, `FrontmostWindows {.noApp, .app(AppEntry, visible:, minimised:)}`. No pid anywhere in the core. |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Source scan: banned tokens and confined tokens (table quoted below). |
| `RecordingSystemActions`, `FakeWindows` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:260-384` | Test fake of `SystemActions`; records calls, answers scripted running apps and windows. |

## Flow

### A. Gesture -> bring to front + launch animation (today)
1. Frame thread recognises a tap; `DeviceSession.receive` (`LauncherKit/Sources/LauncherPlatform/FrameStream.swift:54-80`) calls `deliver(TrackpadEvent(...), reply)`; `MultitouchTrackpads` hops it to main and calls `onEvent` through `WindowSwipeConfirmation.deliver` (`MultitouchTrackpads.swift:101`).
2. `Launcher.start()` set `hardware.onEvent = { [unowned self] event in switch event { case .gesture(let fired): fire(fired) ... } }` (`LauncherKit/Sources/LauncherCore/Launcher.swift:88-96`).
3. `Launcher.fire(_:)` (`Launcher.swift:234-244`):
   ```swift
   guard activity.isActive, let assigned = settings.assignments[event.gesture], let app = catalog.locate(assigned) else { return }
   hardware.playFeedback(.gesture, on: event.trackpad)
   system.bringToFront(app)
   // After bring to front, so whatever the animation costs lands on the icon, never on the app.
   if settings.isLaunchAnimationOn { system.playLaunchAnimation(for: app) }
   window = .closed
   ```
   No running check, no pid, nothing kept after the call.
4. `WorkspaceActions.bringToFront` (`WorkspaceActions.swift:14-20`):
   ```swift
   /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates.
   /// The completion is ignored: its only reactions would be a log line or a dialog.
   public func bringToFront(_ app: AppEntry) {
       let configuration = NSWorkspace.OpenConfiguration()
       configuration.activates = true
       NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
   }
   ```
   Called with two args, so the `completionHandler` (optional, `(NSRunningApplication?, Error?) -> Void`) is nil. Same call for running and non-running apps (no `activate()` anywhere for other apps). The `NSRunningApplication` (and so the pid) the completion would deliver is never learned; launch errors are never seen.
5. `WorkspaceActions.playLaunchAnimation` -> `LaunchOverlay.play(for:)` (`LaunchOverlay.swift:34-69`): reads `NSEvent.mouseLocation`, `NSScreen.screens`, Reduce motion once; stages CAKeyframeAnimations; `CATransaction.setCompletionBlock` closes the panel. ~0.34 s (`LaunchTuning.swift:10 var duration: Double = 0.34`). Nothing follows the pointer.

### B. Swipe / swap read running apps synchronously (pull, on a user event)
- `Launcher.swipe(.began)` -> `system.runningApps()` (`Launcher.swift:252`); `.ended` re-reads and guards `running.contains(target.url)` ("An app that quit meanwhile is never relaunched", `Launcher.swift:267-270`). `swap` reads `system.runningApps()` (`Launcher.swift:322`).
- `WorkspaceActions.runningApps()` -> `RunningAppsReader.read()` (`RunningAppsReader.swift:19-21`) -> `RunningApps(frontmost: frontmost(), apps: order?.apps() ?? fallbackApps())`.
- `LaunchServicesOrder.apps()` (`LaunchServicesOrder.swift:36-51`) keeps only `information["ApplicationType"] as? String == "Foreground"`, pid != own; asks only keys `["pid", "ApplicationType", "LSBundlePath", "CFBundleIdentifier", "LSDisplayName"]`. The pid is read but discarded (only `AppEntry` returned).
- Fallback: `NSWorkspace.shared.runningApplications` where `activationPolicy == .regular && pid != own`, ordered by `FallbackOrder.pids(running:recency:)` using `app.launchDate`.

### C. Window swipe reads the frontmost app's windows (pull, on a user event)
- `Launcher.windowSwipe(.began)` -> `system.frontmostWindows()` (`Launcher.swift:285`), again at `.ended` (`Launcher.swift:306`), raises via `system.raiseWindows`.
- `FrontmostAppWindows.read()` (`FrontmostAppWindows.swift:45-89`):
  1. `NSWorkspace.shared.frontmostApplication`, not own pid, `RunningApp.entry(for:)` else `.noApp`.
  2. `AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute, &value)`; failure -> `.app(entry, visible: [], minimised: [])`, `isUnanswering = (error == .cannotComplete)`.
  3. Per window `AXUIElementCopyMultipleAttributeValues` of role, subrole, title, minimised, `"AXFullScreen"`, position, size.
  4. Window number via private `_AXUIElementGetWindow` (dlsym'd in init, line 36); fallback match by frame+title against `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements])`.
  5. Ordering via `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` filtered to `kCGWindowOwnerPID == pid` and `kCGWindowLayer == 0` (`windowList(_:of:)`, lines 135-146).
  6. `sort` keeps visible = role `AXWindow` + subrole `AXStandardWindow` + not minimised + on screen now (this Space).
- `init()` (lines 33-39): `AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)` — "set on the system-wide element, which makes it the process's default"; warms `CGWindowListCopyWindowInfo` off main via `@concurrent private static func warmWindowList()` (~50 ms first call).
- `raise(_:)` uses `AXUIElementPerformAction(element, kAXRaiseAction)`.

### D. Workspace launch/terminate notifications (switcher icon cache only)
`SwitcherPresenter.startIconPasses(waiting:)` (`SwitcherPresenter.swift:44-67`), only while `launcher.isSwipeOn`:
```swift
center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    MainActor.assumeIsolated { self?.launched(app) }
},
center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { ... self?.terminated(app) }
```
- `launched(_:)` (78-81): `app.flatMap(Self.dockLocation)` (regular activation policy + bundleURL -> `AppEntry.location(ofBundleAtPath:)`), then `pass(over: [location])` = `Task { await icons.renderOffMainActor(urls:); icons.retainOnly(...) }`.
- `terminated(_:)` (83-88): evicts the icon unless another copy of the same bundle location is still running.
- Removed in `stopIconPasses()` when swipe setting goes off; observers keyed off `Observations({ launcher.isSwipeOn })` (lines 29-34).
- This is UI-internal: it does **not** publish through any port, and the model never hears of launches or terminations.

### E. Other workspace observers
- `ActivationTracker` (`ActivationTracker.swift:9-18`): `didActivateApplicationNotification`, queue `.main`, `MainActor.assumeIsolated { self?.note(app) }`; note() keeps `.regular`, non-own pids most-recent-first. Created only when `LaunchServicesOrder()` is nil (`RunningAppsReader.swift:13-16`: `tracker = order == nil ? ActivationTracker() : nil`). So on a normal Mac, nothing observes activations.
- `MultitouchTrackpads` (`MultitouchTrackpads.swift:48-52`): `didWakeNotification` -> `onEvent?(.trackpadsChanged)`.
- No `willLaunchApplicationNotification`, `didDeactivate`, `didHide`/`didUnhide`, `activeSpaceDidChange`; no KVO on `NSWorkspace.runningApplications` or on `NSRunningApplication.isFinishedLaunching` / `isTerminated`; no `AXObserver` anywhere.

## How pushes reach the model (pattern to copy)
- Every push port exposes a main-actor closure property set once by `Launcher.start()` (`Launcher.swift:87-101`):
  - `TrackpadHardware.onEvent: (@MainActor (TrackpadEvent) -> Void)?` (`Ports.swift:32`)
  - `TrackpadPreferences.onChange: (@MainActor () -> Void)?` (`Ports.swift:51`)
  - `Permissions.onChange: (@MainActor () -> Void)?` (`Ports.swift:91`) — "Carries no data: re-read."
  - `AppScanner.onScan: (@MainActor (InstalledApps) -> Void)?` (`Ports.swift:102`)
- Composition root `TrackpadLauncher/TrackpadLauncherApp.swift:8-26` constructs `WorkspaceActions()` etc., passes them to `Launcher(...)`, then `launcher.start()`. No AsyncStream, no delegates; closures with `[unowned self]`.
- Adapter-side delivery idioms:
  - NotificationCenter with `queue: .main` + `MainActor.assumeIsolated { ... }` (ActivationTracker, SwitcherPresenter, MultitouchTrackpads wake).
  - `notify_register_dispatch(..., .main) { MainActor.assumeIsolated { self?.refresh() } }` (`SystemPermissions.swift:22-24`), with de-dup (`onChange` only when grants changed).
  - KVO `observeValue` (nonisolated) -> `Task { @MainActor [weak self] in self?.onChange?() }` (`SystemTrackpadPreferences.swift:44-50`).
  - IOKit notification port on `.main` + `MainActor.assumeIsolated` (`MultitouchTrackpads.swift:27-46`).
  - FSEvents on `.main` dispatch queue (`SystemAppScanner.swift:46-56`).
  - `isolated deinit` removes observers (ActivationTracker:20-22, MultitouchTrackpads:55-58, SystemPermissions:26).
- `SystemActions` has no push at all today; a launch-lifecycle push would be the first push on that port (or a new port).
- UI presenters observe the model with `for await x in Observations({ launcher.switcher })` in `Task`s (`SwitcherPresenter.swift:25-34`).

## How tests fake adapters
- `InMemoryAdapters.swift`: each fake keeps the same closure property and calls it synchronously to simulate a push: `InMemoryTrackpadPreferences.set(...)` -> `onChange?()` (254-257); `InMemoryPermissions.set(_:granted:push:)` -> `onChange?()` only on a real change (405-409); `InMemoryAppScanner.foldersChanged()` -> `onScan?(...)`, with `holdScans()/deliverHeldScan()` to model latency (413-447); `InMemoryTrackpads.attach/detach/wake` -> `onEvent?(.trackpadsChanged)`, `inject(_:)`.
- `RecordingSystemActions` (260-298): `broughtToFront: [AppEntry]`, `launchAnimations: [AppEntry]`, `preparedLaunchAnimations`, settable `frontmost` / `running` answered by `runningApps()`, `windows = FakeWindows()` answered by `frontmostWindows()`, hooks `onRegisterLoginItem`, `onPlayLaunchAnimation` ("so a test can observe the other effects at that moment").
- `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift:36+`) wires `RecordingSystemActions` as `system`; helpers `makeRunning(_:)`, `makeFrontmost(_:)`, `activate(_:)`, `window(_:)`.
- Platform adapter tests run the real thing against the live Mac: `RunningAppsReaderTests` compares `RunningAppsReader().read()` with `NSWorkspace.shared.runningApplications` (`LauncherKit/Tests/LauncherPlatformTests/RunningAppsReaderTests.swift`); `FrontmostAppWindowsSortTests` tests only the pure `nonisolated static func sort` / `number(of:among:)` with recorded `RawWindow`s (`FrontmostAppWindowsTests.swift`). Injectable seams: `RunningAppsReader(order:)`, `SystemPermissions(trusted:capturing:)`, `SystemTrackpadPreferences(domains:)`.

## Source-scan confinement and bans (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`)
Scanned roots: `LauncherKit/Sources` and `TrackpadLauncher/` (lines 101-107). Plain substring match per line (`$0.element.contains(token)`, line 202), comments included.

Confinement table, verbatim (lines 74-95):
```swift
static let confined: [Confined] = [
    Confined(token: "AXIsProcessTrusted", onlyIn: "SystemPermissions.swift", rule: "R9 one permission, one adapter"),
    Confined(token: "notify_register", onlyIn: "SystemPermissions.swift", rule: "R7 the trust push"),
    Confined(
        token: "ScreenCaptureAccess", onlyIn: "SystemPermissions.swift", rule: "one permission check, one adapter"),
    Confined(token: "ScreenCaptureKit", onlyIn: "PreviewCapture.swift", rule: "one file captures the screen"),
    Confined(token: "SCShareableContent", onlyIn: "PreviewCapture.swift", rule: "one file captures the screen"),
    Confined(token: "SCScreenshotManager", onlyIn: "PreviewCapture.swift", rule: "one file captures the screen"),
    Confined(token: "tapCreate", onlyIn: "ClickTap.swift", rule: "the click tap's event taps, one file"),
    Confined(token: "CGEventTapCreate", onlyIn: "ClickTap.swift", rule: "the click tap's event taps, one file"),
    Confined(token: "tapEnable", onlyIn: "ClickTap.swift", rule: "the click tap's event taps, one file"),
    Confined(token: "tapIsEnabled", onlyIn: "ClickTap.swift", rule: "the click tap's event taps, one file"),
    Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", rule: "scrolling is read only by the click tap's event taps"),
    Confined(
        token: "_LSCopyApplicationArrayInFrontToBackOrder", onlyIn: "LaunchServicesOrder.swift",
        rule: "the private ⌘-Tab order has one reader"),
    Confined(
        token: "_LSCopyApplicationInformation", onlyIn: "LaunchServicesOrder.swift",
        rule: "the private ⌘-Tab order has one reader"),
    Confined(token: "AXUIElement", onlyIn: "FrontmostAppWindows.swift", rule: "the window read has one reader"),
    Confined(token: "CGWindowList", onlyIn: "FrontmostAppWindows.swift", rule: "the window read has one reader"),
]
```
Banned tokens relevant to a bounce (lines 30-35, 57-58):
```swift
Entry(token: "Timer", rule: "timer"),
Entry(token: "asyncAfter", rule: "timer"),
Entry(token: "Task.sleep", rule: "polling"),
Entry(token: "makeTimerSource", rule: "timer"),
Entry(token: "displayLink", rule: "timer"),
Entry(token: "DisplayLink", rule: "timer"),
...
Entry(token: "AXUIElementSetAttributeValue", rule: "the window switcher only raises a window"),
Entry(token: "kAXPressAction", rule: "the window switcher only raises a window"),
```
Also `nonisolated(unsafe)` banned ("one writer per field"), and `"perform: {"` banned.
Core may import only `Foundation` and `Observation` (`coreImportsOnlyFoundationAndObservation`, lines 155-161).

Implications (facts, not design):
- Because `"AXUIElement"` is a substring token, any AXObserver code (whose callback and `AXObserverAddNotification` take `AXUIElement`), and even `AXUIElementCreateApplication(pid)`, may only appear in `FrontmostAppWindows.swift` unless the table is edited. Same for any `CGWindowListCopyWindowInfo` / `CGWindowListOption` use.
- `"Timer"` is a bare substring: any identifier containing `Timer` (e.g. `launchTimer`, `capTimer`) fails the build, not just `Foundation.Timer`. `"displayLink"`/`"DisplayLink"` likewise bans `CADisplayLink` / `NSView.displayLink(target:selector:)` / `NSScreen.displayLink`.
- Architecture (`docs/architecture.md:20-21`): "No timers, no polling, no background loops: every input is a push (frames, cfprefs KVO, IOKit notifications, workspace notifications, the TCC Darwin notification, FSEvents for the app folders, user events)." and "Animation is Core Animation keyframes, which the render server plays. Whatever an animation leaves behind is cleaned up from its completion callback. No code of ours runs per frame, and display links are banned along with timers." The only existing "time passes" mechanism in the code is a CA animation's completion block (`LaunchOverlay.swift:48-53`).
- `docs/architecture.md:25`: Accessibility "is used only to block trackpad clicks, suppress trackpad scrolling and block the system's desktop and Mission Control swipes during gestures, to list the frontmost app's windows when two fingers start sliding up or down under the thumb, and to raise and restore them during a window swipe." A new AX use (observing a launching app's windows) would contradict this sentence as written.

## Pointer reads (for "follows the pointer every frame")
- Only polled-at-the-moment reads: `NSEvent.mouseLocation` in `LaunchOverlay.play` (35), `SwitcherPresenter.open` (130), `WindowSwitcherPresenter` (60).
- One existing `NSEvent.addGlobalMonitorForEvents` (mouse downs, `MenuBarShell.swift:105-110`, `MainActor.assumeIsolated { launcher.dismissWindow() }`), removed in `hide()` — shows a global NSEvent monitor is an accepted push source. No `.mouseMoved` monitor exists. `ClickTap` (CGEvent taps, confined to `ClickTap.swift`) sees presses/drags/scroll/gesture events only while armed, not plain moves.

## Boundaries
- Input from other apps today: `NSWorkspace.shared.frontmostApplication`, `.runningApplications`, `NSRunningApplication.runningApplications(withBundleIdentifier:)`, private LS order, AX element API on the frontmost pid, `CGWindowListCopyWindowInfo`, workspace notifications `didActivate` (fallback only), `didLaunch`/`didTerminate` (UI icon cache only), `didWake`.
- Output to other apps: `NSWorkspace.openApplication(at:configuration:)` (`activates = true`), `AXUIElementPerformAction(kAXRaiseAction)`.
- Core <-> platform: `SystemActions` (sync pulls + fire-and-forget effects). Core types carry no pid and no `NSRunningApplication`; identity is `BundleID` + bundle `url` (`AppEntry`), and `RunningApps.contains(_ location: URL)` matches by URL.
- `AppEntry.url` spelling: `AppEntry.location(ofBundleAtPath:)` = `URL(fileURLWithPath: path, isDirectory: true)` (`Apps.swift:27-29`); all running-app reads go through `RunningApp.entry` so URLs compare equal to the catalog's. SwitcherPresenter's `dockLocation` uses the same spelling.

## What exists for "finished launching" / "first window shows" (push vs poll)
In code today: nothing. No code reads `isFinishedLaunching`, observes a launched app, or learns a launched pid.

APIs available (from Apple's documentation / platform knowledge, NOT verified in this repo):
- `NSWorkspace.openApplication(at:configuration:completionHandler:)`: completion delivers `NSRunningApplication?` (gives pid) or `Error?` (launch failure, e.g. damaged app, user refused Gatekeeper prompt?) on a concurrent queue, not main. Push. When exactly it fires relative to `isFinishedLaunching` I could not confirm from the code; I believe it fires once the process is launched/registered, typically before finished launching.
- `NSWorkspace.willLaunchApplicationNotification` / `didLaunchApplicationNotification`: push, main queue if requested; `userInfo[NSWorkspace.applicationUserInfoKey]` is the `NSRunningApplication`. Apple docs state these are not posted for background apps or apps with `LSUIElement` (menu bar apps); for those, KVO on `NSWorkspace.runningApplications` is the documented route. didLaunch fires after the app finished launching (i.e. a "finished launching" signal for Dock apps).
- `NSRunningApplication.isFinishedLaunching`, `isTerminated`: KVO-observable -> push without polling, works for any app incl. LSUIElement.
- `NSWorkspace.didTerminateApplicationNotification`: push, same LSUIElement caveat as didLaunch; `isTerminated` KVO is the generic route.
- `NSWorkspace.didActivateApplicationNotification`: push; activation often but not always coincides with first window.
- First window shown: the only push is an `AXObserver` (`AXObserverCreate(pid, cb, &obs)`, `AXObserverAddNotification(obs, AXUIElementCreateApplication(pid), kAXWindowCreatedNotification, ...)`, run-loop source added to main). Requires Accessibility; can only be installed once the app's AX server answers (early in launch it may return `.cannotComplete` / `.notImplemented`), and every call obeys the process-wide 0.2 s messaging timeout set by `FrontmostAppWindows.init`. Without Accessibility or before the app answers there is no push for windows; `CGWindowListCopyWindowInfo` is pull-only (would need polling, banned).
- `FrontmostAppWindows.windowList(_:of:)` / `onScreenNumbers(of:)` are already pid-parameterised statics but `private`; they filter `kCGWindowLayer == 0` only, so a splash screen at a non-zero window level would not count, and `.optionOnScreenOnly` only covers the current Space.

## Non-Obvious Things
1. **`runningApps()` is not "is a process running"**: the LS path keeps only `ApplicationType == "Foreground"`, the fallback only `activationPolicy == .regular`; both exclude menu bar (LSUIElement) apps and Trackpad Launcher itself. Domain model: running apps are "never a menu bar app". So `system.runningApps().contains(app.url)` would call a running menu bar app "not running". Whether an app still launching (not finished) appears in `_LSCopyApplicationArrayInFrontToBackOrder` is unknown. `NSRunningApplication.runningApplications(withBundleIdentifier:)` (used in `AppIcons.swift:53`, matched by `bundleURL == app.url`) is the code's existing "any process for this bundle" read.
2. `bringToFront` deliberately drops the completion ("its only reactions would be a log line or a dialog"); learning pid/failure means changing that and the `SystemActions.bringToFront` signature (returns Void). The completion arrives off main; the codebase hops to main via `MainActor.assumeIsolated` only when the queue is `.main`, otherwise `Task { @MainActor ... }`.
3. The only `didLaunch`/`didTerminate` observers live in `LauncherUI` (SwitcherPresenter), gated on the swipe setting, and feed only an icon cache. Reusing them for a bounce would couple to the swipe setting; they are not a port.
4. `ActivationTracker` exists only on the fallback path; in production nothing observes activations.
5. `AXUIElementSetMessagingTimeout` on the system-wide element sets the default for every AX call in the process (comment at `FrontmostAppWindows.swift:30-32`), so any AX observer work inherits 0.2 s.
6. `FrontmostAppWindows` is stateful (`listed`, `isUnanswering`) and reads only the frontmost app; a launching app may not be frontmost (e.g. user switched away), so it cannot answer "has app X a window" as is.
7. Source scan is substring-based on whole lines, including comments: writing "Timer" in a doc comment, or "AXUIElement" in a comment elsewhere, fails the build.
8. `LaunchOverlay` panels are tracked in `playingPanels` because "AppKit keeps closed panels in its window list"; play never cancels/reuses an animation (port contract `Ports.swift:65-68`: "Every call plays its own animation and never cancels, restarts or reuses one already playing").
9. Window names from `CGWindowList` need Screen Recording (`ListedWindow.name` nil without it); owner pid and layer do not.

## Open Questions
- Exact timing of `openApplication`'s completion vs. `isFinishedLaunching` / `didLaunchApplicationNotification` — not determinable from code.
- Whether `didLaunchApplicationNotification` fires for LSUIElement menu bar apps on current macOS (docs say no) — not exercised in code.
- Whether a still-launching app appears in the private LS front-to-back array — unknown.
- When an AXObserver can first be registered on a just-launched pid and whether `kAXWindowCreatedNotification` reliably fires for splash windows / windows on another Space — not exercised anywhere in the repo.
- What error `openApplication` reports when the Gatekeeper "are you sure" dialog is pending or declined (R11 scenario) — not exercised.
