# Grounding: self-exclusion, frontmost app, bringing to front

Angle: where the model closes the launcher window after a gesture / swipe / window swipe / swap, how the frontmost app is decided, how Trackpad Launcher (TL) excludes itself, how bring-to-front activates, what depends on LSUIElement / non-activation. All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle/`.

## Components Found

- `Launcher` — `LauncherKit/Sources/LauncherCore/Launcher.swift:10` — the model; owns the launcher window's open state (`private var window: Window`, :49) and is the only writer of it. `isWindowOpen` (:22) is `window != .closed`.
- `Launcher.Window` — `Launcher.swift:47` — `enum { closed, open, heldOpen }`; `.heldOpen` is the first-launch window under the Accessibility prompt.
- `SystemActions` port — `LauncherKit/Sources/LauncherCore/Ports.swift:57-125` — `bringToFront(_:)` (:59), `bringToFrontBouncing` (:98), `hasProcess` (:89), `runningApps()` (:114), `frontmostWindows()` (:118), `raiseWindows` (:124). There is NO port call for "close the window": closing is a model state write (`window = .closed`) that the shell observes.
- `RunningApps` — `LauncherKit/Sources/LauncherCore/Apps.swift:33-50` — one read: `frontmost: AppEntry?` + `apps: [AppEntry]` (⌘-Tab order). Doc at :34-35: frontmost is nil "when there is none, it has no bundle identifier or location, or it is Trackpad Launcher itself, which never activates except around the Other… chooser." `contains(_:)` (:47) matches by URL across frontmost and apps.
- `Switcher` — `LauncherKit/Sources/LauncherCore/Switcher.swift:6-33` — the app switcher row; `startsOnFrontmost`/`selectsFrontmost` make lifting on the frontmost app silent.
- `SwapSeries` — `LauncherKit/Sources/LauncherCore/SwapSeries.swift:4-25` — picks the swap target; remembers the last swap for in-flight activations.
- `FrontmostWindows` — `LauncherKit/Sources/LauncherCore/WindowSwitcher.swift:26-33` — `.noApp` ("There is no active app, or it is Trackpad Launcher itself", :27) or `.app(entry, visible:, minimised:)`.
- `WindowSwitcher.Content.init?(_:)` — `WindowSwitcher.swift:144` — returns nil for `.noApp` (:145), so no window swipe.
- `WindowSwitcher.lift(now:)` — `LauncherKit/Sources/LauncherCore/WindowLift.swift:51-65` — `.nothing` when `now` is `.noApp` or another app (:52).
- `WorkspaceActions` — `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:5` — real `SystemActions`; owns a `RunningAppsReader` (:8) and `FrontmostAppWindows` (:9).
- `RunningAppsReader` — `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift:5-44` — builds `RunningApps`: frontmost from `NSWorkspace.frontmostApplication`, apps from `LaunchServicesOrder` or the fallback.
- `LaunchServicesOrder` — `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift:8-52` — private `_LSCopyApplicationArrayInFrontToBackOrder` + `_LSCopyApplicationInformation` via dlsym.
- `ActivationTracker` — `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift:5-30` — fallback-only recency list from `didActivateApplicationNotification`.
- `FallbackOrder` — `LauncherKit/Sources/LauncherPlatform/FallbackOrder.swift:4-16` — recency first, then launch date, undated last.
- `RunningApp` — `LauncherKit/Sources/LauncherPlatform/RunningApp.swift:5-20` — the one `NSRunningApplication` → `AppEntry` builder (nil without bundle id/URL).
- `FrontmostAppWindows` — `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift:13` — AX read/raise of the frontmost app's windows.
- `MenuBarShell` — `LauncherKit/Sources/LauncherUI/MenuBarShell.swift:14` — observes `launcher.isWindowOpen` and shows/hides the `LauncherPanel`.
- `LauncherPanel` — `LauncherKit/Sources/LauncherUI/LauncherPanel.swift:6` — borderless `.nonactivatingPanel`, `.popUpMenu` level, `canBecomeKey` true.
- Test fakes: `RecordingSystemActions` — `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:260-347`; `FakeWindows` — same file :352-; `World` helpers `makeFrontmost`, `makeRunning`, `activate`, `switcherWorld`, `windowWorld` — `LauncherKit/Tests/LauncherCoreTests/World.swift:192-264`.

## Flow

### A. How the launcher window gets closed by a gesture/swipe/swap (model side)

No port call; every site is a direct write `window = .closed` inside `Launcher`. The shell reacts through Observation.

1. Entry: `Launcher.start()` (`Launcher.swift:89-98`) wires `hardware.onEvent` → `fire` / `swipe` / `windowSwipe` / `swap`.
2. Tap gesture — `fire(_:)` `Launcher.swift:247-266`:
   - guard `activity.isActive`, assignment exists, `catalog.locate` finds it (:248-251), else silent and window untouched.
   - haptic (:252), then one of `bringToFrontBouncing` (:257) / `bringToFront` + `playLaunchAnimation` (:259-261) / `bringToFront` (:263).
   - `window = .closed` (:265) — unconditional after a successful fire; this also closes `.heldOpen` (doc at :46 "A held window closes only on an explicit close, a fired gesture, or a grant").
3. Swipe (app switcher) — `swipe(_:)` `Launcher.swift:283-313`, `.ended` (:298-309):
   - `shown = nil`; if `open.selectsFrontmost` return (silent, window untouched, :301-302).
   - re-read `system.runningApps()` (:304); if selected app's URL no longer running, return (window untouched, :306).
   - haptic, `system.bringToFront(open.selectedApp)` (:308), `window = .closed` (:309).
4. Window swipe — `windowSwipe(_:)` `Launcher.swift:316-352`, `.ended` (:338-347):
   - `lift = open.lift(now: system.frontmostWindows())` (:342).
   - `if lift.playsHaptic { haptic; window = .closed }` (:343-346); then `system.raiseWindows(lift.raises)` (:347). Window closes only when the haptic plays (selected window ≠ the front window at begin). No `bringToFront` here—it only raises windows within the already-frontmost app.
5. Swap — `swap(_:)` `Launcher.swift:355-362`:
   - `startsSeries` resets `swapSeries` (:356); guard active (:357); `swapSeries.next(in: system.runningApps())` or return (:358).
   - haptic, `system.bringToFront(target)` (:360), `window = .closed` (:361).
6. Shell reaction — `MenuBarShell.init` `MenuBarShell.swift:70-75`: `for await open in Observations({ launcher.isWindowOpen }) { if open { show() } else { hide() } }`. `hide()` (:133-137) removes the outside-mouse-down monitor and `panel.orderOut(nil)`.

Other window state writers (non-gesture): `openWindow()` :186-190 (`.closed` → `.open`), `closeWindow()` :193 (always closes; icon click, Escape, settings-pane buttons, Other…), `dismissWindow()` :196 (closes only `.open`, not `.heldOpen`; called from panel `resignKey` via `MenuBarShell.resignedKey` :105-109 and the global mouse-down monitor :126-130), `reconcile` :219 (grant ends `.heldOpen`), `start` :112 (first launch opens).

Summary for R15: the four lines to change are `Launcher.swift:265`, `:309`, `:345`, `:361`.

### B. How the frontmost app is decided

Model never decides "frontmost" itself; it takes `RunningApps.frontmost` / `FrontmostWindows` from the port at:
- swipe begin `Launcher.swift:288-292` → `Switcher(frontmost: running.frontmost, running: running.apps, leavingOut: settings.assignedBundleIDs, trackpad:)`.
- swipe end `:304-306` (only to check the target still runs).
- window swipe begin `:321` (`WindowSwitcher.Content(system.frontmostWindows())`) and end `:342`.
- swap `:358` (`swapSeries.next(in: system.runningApps())`).

Platform read — `RunningAppsReader.read()` `RunningAppsReader.swift:19-21`:
- `frontmost()` :38-43: `NSWorkspace.shared.frontmostApplication`, returns nil if its `processIdentifier == ProcessInfo.processInfo.processIdentifier`; else `RunningApp.entry(for:)` (nil without bundle id or bundleURL, `RunningApp.swift:8`). Note: no activation-policy filter on frontmost — a menu bar (accessory) app in front IS reported as frontmost (that is intended; `Apps.swift:37-38`, domain-model.md:66).
- apps: `order?.apps() ?? fallbackApps()` :20.

`FrontmostAppWindows.read()` `FrontmostAppWindows.swift:45-51`: same rule — `frontmostApplication`, pid ≠ own pid, `RunningApp.entry` → else `.noApp`.

### C. How TL excludes itself — by PID everywhere, never by bundle id or activation policy

| Site | Filter |
|---|---|
| frontmost (running apps) `RunningAppsReader.swift:39-41` | `app.processIdentifier != ProcessInfo.processInfo.processIdentifier` |
| frontmost (windows) `FrontmostAppWindows.swift:48-50` | same pid check |
| ⌘-Tab order `LaunchServicesOrder.swift:38,43-44` | `ApplicationType == "Foreground"` AND `pid != ownPID` |
| fallback apps `RunningAppsReader.swift:24,28` | `activationPolicy == .regular && processIdentifier != own` |
| fallback recency `ActivationTracker.swift:25` | `activationPolicy == .regular && pid != own` (TL's own activation is never noted, so it never displaces the previous app in recency) |

Consequences:
- Because exclusion is by PID, TL stays excluded from both the frontmost app and the ⌘-Tab list even if it becomes `.regular` (Dock icon). Nothing keys on LSUIElement / `.accessory` for exclusion. (Today, with `LSUIElement: true` in `project.yml:39`, LaunchServices presumably reports TL's ApplicationType as something other than "Foreground" — "UIElement" — so the "Foreground" filter would have excluded it already; with `.regular` it would be "Foreground" and only the pid filter excludes it. I did not verify the ApplicationType string empirically.)
- When TL is the active app, `frontmost` is nil (not "the previous app"). The ⌘-Tab list, being TL-filtered front-to-back order, then has the app that was in front before TL as `apps.first` (LaunchServices path: TL is first in the LS front-to-back array and is dropped; fallback path: ActivationTracker never recorded TL, so recency[0] is the previous regular app). Caveat: if the previous front app was a menu bar/accessory app (not in ⌘-Tab), it is not in `apps` at all and there is no way today to recover it.
- `hasProcess` (`WorkspaceActions.swift:41-43`) has no self-exclusion (irrelevant: TL never assigns itself).
- UI: `SwitcherPresenter.dockLocation` `LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift:103-106` filters `activationPolicy == .regular` only (no pid) for icon pre-rendering — with TL `.regular` its own icon would be pre-rendered into the switcher icon cache (harmless; not a row source).

### D. What the model does with frontmost == nil ("TL itself active")

- Switcher `Switcher.swift:20-27`: `others = running.filter { $0.url != frontmost?.url && !leavingOut.contains($0.bundleID) }`; `row = (frontmost.map{[$0]} ?? []) + others` capped at `GestureRules.switcherMaxApps`; `startsOnFrontmost = frontmost != nil`. With nil: row is the running apps (minus assigned bundle ids), selection starts on index 0 = most recently used running app (= previous front app), `selectsFrontmost` (:32) is always false, so lifting immediately (no travel) brings row[0] to front with haptic and closes the window. Also, the previous front app is subject to `leavingOut` (assigned apps dropped) — whereas a real frontmost app is never left out (:18-19).
- Swap `SwapSeries.next` `SwapSeries.swift:16-24`: `frontmost = inFlight ?? running.frontmost`; target = `running.apps.first { $0.url != frontmost?.url }`. With nil frontmost: target = `apps.first` = the previous front app itself (i.e. it re-activates what was already in front before TL, rather than the app behind it). In-flight edge: `running.frontmost?.url == $0.from` is `nil == nil` → true when both the last swap started with nil and the read is still nil, so the last target stands in as frontmost.
- Window swipe: `FrontmostWindows.noApp` → `WindowSwitcher.Content` nil (`WindowSwitcher.swift:145`) → `confirmWindowSwipe` never called (`Launcher.swift:321-322`) → slide is declined and proceeds as with the window swipe setting off. At lift, `.noApp` → `WindowLift.nothing` (`WindowLift.swift:52`).
- Domain-model text pins this: `docs/domain-model.md:39` (swap: "with no frontmost app, as while Trackpad Launcher itself is active, the most recently used running app"; "the launcher window closes") and `:66` (Frontmost app: "never Trackpad Launcher. Trackpad Launcher is active only when macOS makes it so: right after it is opened (from Finder, or Run in Xcode) and around the Other… chooser. … When there is none, as while Trackpad Launcher itself is active, the row is the running apps without a gesture alone, the selection starts on the most recently used one, and lifting on any app, that one included, brings it to the front; a swap brings the most recently used one to the front; and a slide up or down is no window swipe.").

R15 gap: with an ordinary (activating) settings window in front, TL is active → frontmost nil → today's nil-branch behaviour (switcher starts on the previous app and lifting there re-activates it, swap brings the previous app instead of the one behind it, no window swipe). R15 wants the previous front app to be treated as frontmost.

### E. Why it works today with the launcher window open (non-activation)

- `LauncherPanel` is `[.borderless, .nonactivatingPanel]` (`LauncherPanel.swift:15`), `canBecomeKey` true (:33), `level = .popUpMenu` (:24), `hidesOnDeactivate = false` (:27), `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]` (:25). Shown via `makeKeyAndOrderFront` (`MenuBarShell.swift:124`) without `NSApp.activate`. So while the launcher window is key, `NSWorkspace.frontmostApplication` stays the user's app, and the switcher/swap/window swipe all run from the real frontmost app. This is the mechanism that would break if the settings window became an ordinary activating window.
- Because the panel is at `.popUpMenu` level, a brought-to-front app would NOT come over it; today that never matters because the model closes the window. An ordinary window at normal level would naturally go behind the activated app.
- Dismissal relies on key loss: `LauncherPanel.resignKey` → `onResignKey` (`LauncherPanel.swift:38-41`) → `MenuBarShell.resignedKey` → `launcher.dismissWindow()` (`MenuBarShell.swift:105-109`), plus a global mouse-down monitor (`MenuBarShell.swift:126-130`). Bringing another app to front makes the panel resign key, so even without `window = .closed` the popover-style window would be dismissed by `dismissWindow()` (unless `.heldOpen`).
- Places TL activates itself: `chooseOtherApp` → `launcher.closeWindow(); NSApp.activate()` (`MenuBarShell.swift:161-163`) before the `NSOpenPanel`; DEBUG-only `TunerPanel.sendEvent` → `NSApp.activate()` on left mouse down (`LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift:55-58`), and the tuner is shown at launch in DEBUG (`TrackpadLauncher/TrackpadLauncherApp.swift`, `system.showAnimationTuner()`). Doc comment `AnimationTuner.swift:41-42`: "the app is a menu bar app that is otherwise never active".
- Overlays that must never activate/become key: `OverlayPanel` (switcher panels) `LauncherKit/Sources/LauncherUI/OverlayPanel.swift:29,36,47-48` (`.nonactivatingPanel`, `hidesOnDeactivate=false`, `canBecomeKey/Main false`, `.screenSaver`); `LaunchOverlay.makePanel` `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift:133-143` with comment "The app is never active, so it never deactivates either." + `hidesOnDeactivate = false`. Port contracts `Ports.swift:69` and `:95-96`: "Nothing it shows activates Trackpad Launcher, becomes key or receives a click." These all set `hidesOnDeactivate = false` explicitly, so they do not depend on TL being inactive; the comment at LaunchOverlay.swift:142 would just become stale.

### F. Bring to front — how activation is done

- `WorkspaceActions.bringToFront(_:)` → `open(app)` (`WorkspaceActions.swift:39`).
- `open(_:then:)` `WorkspaceActions.swift:66-80`: `NSWorkspace.OpenConfiguration()`, `activates = true` (:68), `promptsUserIfNeeded = promptsUser` (:69, true in prod; tests turn it off), then `NSWorkspace.shared.openApplication(at: app.url, configuration:)` (:71) or with completion for bounces (:74-79). Doc :63-65: "One call reproduces a Dock click: launches, unhides, restores, reopens and activates."
- `bringToFrontBouncing` (:45-54) calls the same `open(app, then: watch.opened)` first, then starts the bounce.
- No use anywhere of `NSRunningApplication.activate(options:)`, `NSApp.yieldActivation(to:)`, `NSApp.yieldActivation(toApplicationWithBundleIdentifier:)`, or `activateIgnoringOtherApps`. (grep of Sources for `activate` found only the sites listed above.)
- Window-level raising: `FrontmostAppWindows.raise` (`FrontmostAppWindows.swift:93-99`) uses `AXUIElementPerformAction(element, kAXRaiseAction)` only — it does not activate the app (it relies on the app already being frontmost).
- Activation from a background app: works today from a never-active LSUIElement app via `openApplication(... activates: true)`. Nothing in the code handles macOS 14+ cooperative activation explicitly.

### G. ⌘-Tab order details (LaunchServicesOrder)

- `apps()` `LaunchServicesOrder.swift:36-51`: `copyOrder(0xFFFF_FFFE)` (default session) → serials; for each, `_LSCopyApplicationInformation(-2, serial, keys)` with keys `pid, ApplicationType, LSBundlePath, CFBundleIdentifier, LSDisplayName` (:20); keeps only `ApplicationType == "Foreground"` and `pid != ownPID` (:43-44); builds via `RunningApp.entry(bundleIdentifier:name:path:)`.
- Doc :34-35: "Every foreground app other than this process, frontmost first. The array holds nothing else today; the filters guard against a future macOS."
- `RunningAppsReader.init(order:)` :13-16: tracker is created only when `order == nil` (fallback path).

## Tests that pin this behaviour

Fakes:
- `RecordingSystemActions.frontmost: AppEntry?` (`InMemoryAdapters.swift:267-268`, doc "nil models no active app, or Trackpad Launcher itself"), `running: [AppEntry]` (:269-270). `runningApps()` returns them verbatim (:278); `frontmostWindows()` = `windows.read(frontmost: frontmost)` (:283), and `FakeWindows.read` returns `.noApp` for nil (:401-404).
- `bringToFront` only appends to `broughtToFront` (:276) — it does NOT change `frontmost`/`running`; tests simulate an activation landing with `World.activate(_:)` (`World.swift:231-235`) or `makeFrontmost`/`makeRunning`.
- `hasProcess` derived from processes/frontmost/running (:323-325).
- `World.makeFrontmost(_ name: String?)` (`World.swift:194-196`, doc "nil models no active app, or Trackpad Launcher itself"); `switcherWorld(... frontmost: String? = "Safari")` (:219-228); `windowWorld(... frontmost: String? = "Safari")` (:251-264).
- Launcher window open state is the real model state: tests call `world.launcher.openWindow()` and assert `world.launcher.isWindowOpen`. No shell is involved.

Tests asserting the window closes after an effect (would flip under R15):
- `LauncherTests.swift:10-30` `twoFingerTapBringsItsAppToFrontPulsesPlaysTheLaunchAnimationAndClosesTheWindow` (`#expect(!isWindowOpen)` :26); `:32-46` `withTheLaunchAnimationOffAGesturePulsesBringsToFrontAndClosesTheWindowWithoutAnIcon` (:43).
- `LaunchBounceFiringTests.swift:21/31, 58/67, 180/188`.
- `SwapTests.swift:15-36` `theThumbLiftingSwapsToThePreviousAppWithTheHapticAndNoAnimationAndClosesTheWindow` (:31).
- `SwitcherOnScreenTests.swift:190-211` `liftingOpensTheSelectionWithTheGestureHapticNoLaunchAnimationAndClosesTheWindow` (:210); `:~410-425` `oneStepRightAndLiftBringsMailToTheFrontWithTheGestureHapticAndClosesTheWindow` (:424).
- `WindowSwitchingTests.swift:64-79` (:74), `:82-98` (:97) — window swipe lift with haptic closes.
- `SwitcherAssignedAppsTests.swift:70-95` region (`openWindow` at :70, :80; `isWindowOpen` at :95 — check case-by-case).

Tests asserting the window stays open on silent outcomes (unchanged by R15): `LauncherTests.swift:97-108` (unassigned); `SwapTests.swift:139-152` (nothing to swap); `SwitcherOnScreenTests.swift:272-281` (lift on frontmost), `:427-435` (lift before an icon), `:507-519` (lift on starting app after another came forward), `:39-54` (drift tap); `WindowSwitchingTests.swift:100-128, 210-228`; `ActivityTests.swift:119-127`; `SwipeSettingTests.swift:11-15`; AccessibilityTests `:25-72` (held window vs dismiss/close).

Tests pinning nil-frontmost ("TL in front") behaviour (would change under R15 if "previous front app" replaces nil):
- `SwitcherOnScreenTests.swift` section `// MARK: Trackpad Launcher in front` (~:363): `withNoReadableFrontmostAppTheRowIsTheRunningAppsStartingOnTheMostRecent` (row == all running, selected 0), `withNoReadableFrontmostAppLiftingOnTheFirstAppBringsItToFront` (lift with no travel brings Safari, haptic), `withNoReadableFrontmostAppOneRunningAppIsEnoughToSwitchTo`.
- `SwitcherAssignedAppsTests.swift:134-161`: `withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst`, `withNoFrontmostAppAndEveryRunningAppAssignedNoSwitcherShows`.
- `SwapTests.swift:82-95` `aMenuBarAppInFrontIsSkippedAndNoFrontmostAppSwapsToTheFirstRunningApp` (nil frontmost → swaps to `apps.first` = Finder); `SwapTests.swift:148-152` (nil frontmost + empty running → nothing).
- `WindowSwipeNeedsTwoWindowsTests.swift:98` `.noFrontmostApp` case (`windowWorld(frontmost: nil)`) — slide is not a window swipe.
- `WindowTitleRuleTests.swift:29` has a `frontmost: nil` argument row.
- `SwitcherTests.swift:17-107` — pure `Switcher` init tests (default frontmost Safari; :105-107 nil-row cases).

Platform tests: `LauncherKit/Tests/LauncherPlatformTests/RunningAppsReaderTests.swift`
- Defines "Dock apps" as `activationPolicy == .regular && pid != own` (:11-16, :24-29).
- `theOrderHoldsEveryDockAppNamedAsMacOSNamesItWithTheActiveAppFirst` (:39-60): LS order equals the set of regular, non-self apps; when the active app is regular and not self, it's `frontmost` and `apps.first`.
- `theActiveAppIsSpelledLikeItsEntryInTheApps` (:62-75), `withoutTheOrderTheActiveAppIsStillRead` (:77-84), `theFallbackOrderPuts…` (:86-95, pure `FallbackOrder`), `withoutTheOrderTheSeedAndThenEachActivationComeFirst` (:97-119, posts fake `didActivateApplicationNotification`).
- These run inside the test host process (not TL), so "own pid" is the xctest/swift-testing runner; nothing tests "TL active → frontmost nil" on the platform side.

## Files Read

- LauncherKit/Sources/LauncherCore/Launcher.swift
- LauncherKit/Sources/LauncherCore/Ports.swift
- LauncherKit/Sources/LauncherCore/Apps.swift
- LauncherKit/Sources/LauncherCore/Switcher.swift
- LauncherKit/Sources/LauncherCore/SwapSeries.swift
- LauncherKit/Sources/LauncherCore/WindowSwitcher.swift (:1-60, :135-165)
- LauncherKit/Sources/LauncherCore/WindowLift.swift
- LauncherKit/Sources/LauncherCore/Activity.swift, Surface.swift (grep only: no frontmost/window logic)
- LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift
- LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift
- LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift
- LauncherKit/Sources/LauncherPlatform/FallbackOrder.swift
- LauncherKit/Sources/LauncherPlatform/RunningApp.swift
- LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift
- LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift
- LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift (:125-149)
- LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift (:15-62)
- LauncherKit/Sources/LauncherUI/MenuBarShell.swift
- LauncherKit/Sources/LauncherUI/LauncherPanel.swift
- LauncherKit/Sources/LauncherUI/LauncherActions.swift (:1-35)
- LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift (:85-125)
- LauncherKit/Sources/LauncherUI/OverlayPanel.swift (:20-60)
- TrackpadLauncher/TrackpadLauncherApp.swift
- project.yml (:25-50)
- docs/domain-model.md (lines 30-39, 66, 77-82 via grep), docs/architecture.md (grep)
- LauncherKit/Tests/LauncherCoreTests/World.swift
- LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift (:255-425)
- LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift (:1-50, :95-110)
- LauncherKit/Tests/LauncherCoreTests/SwapTests.swift (:1-160)
- LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift (selected ranges)
- LauncherKit/Tests/LauncherCoreTests/SwitcherAssignedAppsTests.swift (:125-165)
- LauncherKit/Tests/LauncherCoreTests/WindowSwitchingTests.swift (:60-135, :205-228)
- LauncherKit/Tests/LauncherCoreTests/WindowSwipeNeedsTwoWindowsTests.swift (:85-115)
- LauncherKit/Tests/LauncherCoreTests/SwitcherTests.swift (grep)
- LauncherKit/Tests/LauncherPlatformTests/RunningAppsReaderTests.swift

## Boundaries

- In: `TrackpadEvent` from `TrackpadHardware.onEvent` (`Ports.swift:3-20`, wired `Launcher.swift:90-98`).
- Out (effects): `SystemActions.bringToFront` / `bringToFrontBouncing` / `raiseWindows` / `playLaunchAnimation`; `TrackpadHardware.playFeedback` / `confirmWindowSwipe`.
- Reads: `SystemActions.runningApps()` → `RunningApps`; `SystemActions.frontmostWindows()` → `FrontmostWindows`. Both are the only way the model learns the frontmost app; the self-exclusion lives entirely below the port, in LauncherPlatform (pid checks).
- Model → shell: observable `Launcher.isWindowOpen`; shell → model: `openWindow`, `closeWindow`, `dismissWindow` (`MenuBarShell.swift:39, 87-91, 96, 105-109, 126-130, 161-178`).
- App configuration: `LSUIElement: true` in `project.yml:39` (Info.plist generated from it; `GENERATE_INFOPLIST_FILE: NO`, path `TrackpadLauncher/Info.plist`). No code calls `NSApp.setActivationPolicy` anywhere.

## Non-Obvious Things

1. Closing is not a port call; it's `window = .closed` in four effect paths (`Launcher.swift:265, 309, 345, 361`). Window swipe closes only when the haptic plays (`:343-346`); silent outcomes never touch the window. `fire` closes even a `.heldOpen` window.
2. Self-exclusion is purely by PID (5 sites, table in C). So a `.regular` TL with a Dock icon is still never in `apps` and never `frontmost` — but `frontmost` becomes nil (not "the previous app") whenever TL is active. The model cannot distinguish "TL is active" from "no active app" or "frontmost has no bundle id"; `RunningApps.frontmost == nil` conflates them (`Apps.swift:34-35`, `InMemoryAdapters.swift:267`).
3. Today TL is effectively never active while its window is open because `LauncherPanel` is a `.nonactivatingPanel` (`LauncherPanel.swift:15`). That — not LSUIElement — is what keeps the real frontmost app frontmost while the window is up. An ordinary titled window would activate TL and push every swipe/swap/window swipe into the nil-frontmost branch.
4. In the nil branch: switcher row starts on the previous front app and lifting with no travel re-activates it (not silent); assigned apps are left out even if that previous app is assigned (a real frontmost app is never left out, `Switcher.swift:18-19`); swap brings `apps.first` (= the previous front app, not the one behind it) — this is pinned by `SwapTests.swift:82-95`; window swipe is impossible (`.noApp`).
5. The previous front app can be recovered from `apps.first` while TL is active only if it is a ⌘-Tab (Foreground/regular) app; a menu bar app with a window that was frontmost before TL is invisible in `apps`. There is no "last non-self frontmost" memory anywhere in platform or core (ActivationTracker only exists on the fallback path and filters `.regular` only).
6. `SwapSeries` in-flight check compares optional URLs: `nil == nil` is true (`SwapSeries.swift:18`), so a series that started with no frontmost treats the last target as frontmost while the read still shows none.
7. `LauncherPanel.level = .popUpMenu` — an app brought to front would not cover it; R15's "app comes over the window" requires normal window level for the settings window.
8. Even if the model stopped writing `window = .closed`, the current panel would still be dismissed on key loss via `dismissWindow()` (`MenuBarShell.swift:105-109`) and on any global mouse-down (`:126-130`). For an ordinary settings window those dismissal paths are presumably removed, but note `dismissWindow`'s `.heldOpen` semantics.
9. Bring to front is exclusively `NSWorkspace.openApplication(at:configuration:)` with `activates = true` (`WorkspaceActions.swift:66-80`); no `NSRunningApplication.activate`, no `yieldActivation`. It currently runs from a never-active process.
10. Comments that encode the "never active" assumption and would go stale: `Apps.swift:34-35`, `RunningAppsReader.swift:36-37`, `WindowSwitcher.swift:27`, `Switcher.swift:4-5`, `LaunchOverlay.swift:142`, `AnimationTuner.swift:41-42`, `InMemoryAdapters.swift:267`, `World.swift:193`, docs/domain-model.md:39 and :66.
11. Fake `bringToFront` doesn't move `frontmost` — any test of "the app it brings to front comes over the window" or of a follow-up swap must use `World.activate` to land the activation.

## Open Questions

- macOS 14+/26 cooperative activation: whether `NSWorkspace.openApplication(... activates: true)` from TL while TL is active (settings window key) reliably activates the target and orders it above TL's window, or whether `NSApp.yieldActivation(to:)` is needed first. Not determinable from code; needs an E2E probe (there is a `probes` folder already under `.temp/architect/grounding/`).
- Exact `ApplicationType` LaunchServices reports for TL under `LSUIElement` vs after `setActivationPolicy(.regular)` (and whether the LS front-to-back array ordering updates to put TL first when it activates while `.regular`). The pid filter makes it moot for exclusion, but it matters for "is apps.first the previously-front app" while TL is active — assumed yes, unverified.
- Whether `NSWorkspace.frontmostApplication` reports TL immediately when its settings window becomes key (and how quickly it reverts after bring-to-front) — affects whether a "remember the last non-self frontmost app" approach needs a `didActivateApplicationNotification` observer on the primary (LaunchServices) path, where today no observer exists.
- I did not read SwitcherAssignedAppsTests :60-100 in full to confirm each isWindowOpen expectation's direction.
