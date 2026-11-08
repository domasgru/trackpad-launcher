# How the window read works on the platform side (LauncherPlatform)

Angle: the Accessibility (AX) window read and raise adapter, its timeout and warm-up, window identity, app lifecycle
observation, the source-scan confinement, and prior probes. All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order`.

There is no `research/` directory anywhere in the repo. The only prior platform probes for windows live in
`plans/012-window-switcher-gesture/.temp/architect/grounding/` (index.md F8 to F24, probes/probe-2 and probe-5). They
were run on 2026-10-16 on macOS 26.6.2 against TextEdit only (`probes/README.md`).

---

## Components Found

| Name | File | What it does |
|---|---|---|
| `FrontmostAppWindows` | `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift:13` | `@MainActor final class`. It reads the frontmost app's windows (AX plus CGWindowList) and raises them. One of only two files allowed to name `AXUIElement` and `CGWindowList`. |
| `FrontmostAppWindows.messagingTimeout` | same file `:15` | `static let messagingTimeout: Float = 0.2`, the value set process-wide in `init`. |
| `FrontmostAppWindows.read()` | `:45-90` | `func read() -> FrontmostWindows`. One synchronous read of the frontmost app. Also replaces the raise handles (`listed`). |
| `FrontmostAppWindows.raise(_:)` | `:94-100` | `func raise(_ frontToBack: [WindowID])`. Calls `AXRaise` on the listed elements, the last first. Returns Void and reports nothing. |
| `FrontmostAppWindows.sort(_:onScreen:)` | `:152-167` | `nonisolated static`, pure. It decides which raw windows are listed as visible or minimised, and their order. |
| `FrontmostAppWindows.number(of:among:)` | `:171-175` | `nonisolated static`, pure. The frame-and-title fallback for a window's number. |
| `RawWindow` | `:179-188` | `struct RawWindow: Sendable`. What AX said about one window. It has no AX handle. |
| `ListedWindow` | `:191-196` | `struct ListedWindow: Sendable`. One CGWindowList entry: number, frame, optional name. |
| `WorkspaceActions` | `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:4` | The real `SystemActions` adapter. It holds `private let windows = FrontmostAppWindows()` (`:8`) and delegates `frontmostWindows()` (`:87`) and `raiseWindows(_:)` (`:89`) to it. |
| `SystemActions` port, window members | `LauncherKit/Sources/LauncherCore/Ports.swift:127-138` | `func runningApps() -> RunningApps`, `func frontmostWindows() -> FrontmostWindows`, `func raiseWindows(_ frontToBack: [WindowID])`. All `@MainActor` and synchronous. |
| `WindowID` | `LauncherKit/Sources/LauncherCore/WindowSwitcher.swift:5-9` | `public struct WindowID: Hashable, Sendable { public let rawValue: UInt32 }`. Its doc says the window server's number is "stable for the window's life". |
| `AppWindow` | `WindowSwitcher.swift:12-23` | `id: WindowID`, `title: String`, `isFullScreen: Bool`. |
| `FrontmostWindows` | `WindowSwitcher.swift:26-34` | `case noApp`, and `case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])`. There is no case for "did not answer". |
| `WindowSwitcher.Content.init?(_ read: FrontmostWindows)` | `WindowSwitcher.swift:145-165` | The core parse. It applies the full-screen front-window rule, the cut at 10 and the two-row minimum. |
| `LaunchWatch` | `LauncherKit/Sources/LauncherPlatform/LaunchWatch.swift:16` | The second AX and CGWindowList reader. It watches a launch for its first window. It has its own `messagingTimeout = 0.2` (`:17`) set on its own app element (`:100`). |
| `LaunchClock` | `LauncherKit/Sources/LauncherPlatform/LaunchClock.swift:7` | The only deadline mechanism in the codebase. Deadlines are 1→1 opacity `CABasicAnimation`s on a layer in a hidden 1-pt panel, so time passes on the render server's clock. |
| `RunningAppsReader` | `LauncherKit/Sources/LauncherPlatform/RunningAppsReader.swift:5` | The `runningApps()` read: the ⌘-Tab order from `LaunchServicesOrder`, or a fallback. Its `frontmost` substitutes for Trackpad Launcher's own pid. |
| `LaunchServicesOrder` | `LauncherKit/Sources/LauncherPlatform/LaunchServicesOrder.swift:8` | Calls the private `_LSCopyApplicationArrayInFrontToBackOrder` and `_LSCopyApplicationInformation`. It asks for the `"pid"` key (`:20`) but drops it when it builds `AppEntry` (`:46-55`). |
| `ActivationTracker` | `LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift:5` | Observes `didActivateApplicationNotification`. It exists only on the fallback path inside `RunningAppsReader` and is not a port. |
| `RunningApp.entry(for:)` | `LauncherKit/Sources/LauncherPlatform/RunningApp.swift:7` | The one place an `NSRunningApplication` becomes an `AppEntry`. |
| `PreviewCapture` | `LauncherKit/Sources/LauncherUI/PreviewCapture.swift:8` | Captures windows with ScreenCaptureKit off the main actor, keyed by `WindowID` (`SCWindow.windowID`). |
| `SourcePolicyTests` | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | A line-based substring scan of all shipped Swift. It holds the confinement and ban rules. |
| `FakeWindows` | `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift:392-470` | The test double. One fixed `WindowID` per window name for the life of a test, starting at 1000. `answers = false` makes reads list nothing. |
| `FrontmostAppWindowsTests` | `LauncherKit/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift` | Tests only the pure `sort` and `number(of:among:)`, over raw facts copied from probe 2 and probe 5. |

---

## Flow

### Construction and warm-up (at launch)

1. `TrackpadLauncherApp.makeResident(_:)` creates `WorkspaceActions()` (`TrackpadLauncher/TrackpadLauncherApp.swift:80`). This happens only for a copy that runs gestures, before `Launcher` exists.
2. The `WorkspaceActions` stored property `windows = FrontmostAppWindows()` runs `FrontmostAppWindows.init()` (`FrontmostAppWindows.swift:33-39`):
   - `AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)` (`:34`). The return value is ignored. Per `AXUIElement.h:389-393`, "Pass the system-wide accessibility object ... if you want to set the timeout globally for this process. Setting the timeout on another accessibility object sets it only for that object". So every element the process creates, including the window elements AX returns, defaults to 0.2 s.
   - `getWindow = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow").map { unsafeBitCast($0, to: GetWindow.self) }` (`:36-37`). Here `-2` is `RTLD_DEFAULT`, and the type is `private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError` (`:17`).
   - `Task { await Self.warmWindowList() }` (`:38`). `@concurrent private static func warmWindowList() async` (`:41-43`) calls `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` once and discards the result. Probe 3 measured the cold first call at 52.15 ms and the warm call at 1.26 ms (`plans/012-window-switcher-gesture/.temp/architect/grounding/probes/probe-3-capture.output.txt:3-4`). Only the CG list is warmed. No AX call is warmed.

### `read()`: synchronous, on the main actor (`FrontmostAppWindows.swift:45-90`)

1. Resets `listed = [:]` and `isUnanswering = false` (`:46-47`).
2. `NSWorkspace.shared.frontmostApplication` → `RunningApp.entry(for:)`. Either one nil gives `.noApp` (`:48-49`).
3. If the frontmost pid is this process, returns `.app(entry, visible: [], minimised: [])` (`:50-52`). This is Trackpad Launcher's own entry, with no substitution (see Non-Obvious #6).
4. `AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)` (`:55-56`). This is IPC call #1. On any error, `isUnanswering = (windowsError == .cannotComplete)` and the read returns `.app(entry, [], [])` (`:57-60`). Without Accessibility this returns `apiDisabled` (sourced F15, not probed), so the result is empty and not marked unanswering.
5. For each window element, in AX order, one `AXUIElementCopyMultipleAttributeValues(element, Self.attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)` (`:64-67`). The attributes are `[kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute, "AXFullScreen", kAXPositionAttribute, kAXSizeAttribute]` (`:25-28`). This is IPC call #2..N+1.
   - `.cannotComplete` sets `isUnanswering = true` and breaks. "What was read so far stands" (`:68-72`), so the read returns a partial list, not an empty one.
   - Any other error, or a non-array result, skips that window (`:73`).
   - On success, `Self.rawWindow(values, number: number(of: element))` (`:74`). `number(of:)` (`:102-106`) calls the private `getWindow(element, &number)`, which may be another IPC call per window (unverified, see Open Questions). Its failure gives nil and never sets `isUnanswering`.
6. If any window has no number, `Self.listedWindows(of: pid)` (`:132-134`) makes one system-wide `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)`, filtered client-side to the pid and layer 0. Then `Self.number(of:among:)` (`:171-175`) matches by exact frame, and by title only where the list has names. `kCGWindowName` needs Screen Recording (comment `:194`; F11 sourced from release notes, not probed). With more or fewer than one match, the window stays numberless and is dropped.
7. `Self.sort(raw, onScreen: Self.onScreenNumbers(of: pid))` (`:83`). `onScreenNumbers` (`:127-129`) makes one system-wide `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`, filtered to the pid, layer 0, front to back. A read therefore makes one CG list call always, and two when the fallback runs. Both copy every window on the system and filter by pid on the client side (`windowList` `:136-147`).
8. `sort` (`:152-167`):
   - Visible: `role == "AXWindow"`, `subrole == "AXStandardWindow"`, not minimised, and in the on-screen list. The order is the CG on-screen order (front to back), whatever the AX order.
   - Minimised: `isMinimised` alone, with no role or subrole check, because probe 2 saw a minimised TextEdit window report `AXDialog`. The order is the AX order.
   - A window without a number is left out.
   - `isFullScreen` is carried only on visible windows.
   - Panels and palettes (`AXFloatingWindow`, `AXSystemFloatingWindow`), on-screen `AXDialog` windows and the `AXUnknown` full-screen sibling are dropped (tests `FrontmostAppWindowsTests.swift:38-56`).
9. It rebuilds `listed: [WindowID: AXUIElement]` for exactly the windows `sort` kept (`:84-88`) and returns `.app(entry, visible:, minimised:)` (`:89`).

The "current Space" test is implicit. A visible window must be in the on-screen CG list. Probe 5 also showed `kAXWindowsAttribute` itself dropping the frontmost app's window on another Space (F10, `probe-5-spaces.output.txt:6-9`). Minimised windows get no Space test (see Non-Obvious #3).

Full-screen handling in the read is only the `AXFullScreen` attribute. The rule "a full-screen front window counts as one" and leaving out other full-screen windows happen in the core parse, `WindowSwitcher.Content.init?` (`WindowSwitcher.swift:150-152`): `guard !front.isFullScreen else { return nil }` and `visible.dropFirst().filter { !$0.isFullScreen }`.

### `raise(_:)` (`FrontmostAppWindows.swift:94-100`)

```swift
func raise(_ frontToBack: [WindowID]) {
    for id in frontToBack.reversed() {
        guard !isUnanswering else { return }
        guard let element = listed[id] else { continue }
        if AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .cannotComplete { isUnanswering = true }
    }
}
```

- Only ids from the latest read can be raised. This is the "nothing on another Space is raised" guarantee (`:20`, `Ports.swift:133-137`). Probe 5 / F24 showed that `AXRaise` on another Space's window switches Spaces.
- Restore is `AXRaise` on a minimised element. Probe 2 / F20 showed it restores, fronts and focuses, on TextEdit only (plan 012 open question 11).
- No minimise operation exists. The source policy bans `AXUIElementSetAttributeValue` and `kAXPressAction` (`SourcePolicyTests.swift:80-81`, rule "the window switcher only raises a window").
- Failure reporting: none. The result is Void. A closed window answers `-25202` (`kAXErrorInvalidUIElement`, probe 2), which is silently ignored. `.cannotComplete` sets `isUnanswering`, which skips every later raise until the next `read()` resets it (`:47`). The model learns outcomes only by reading again: the lift's second `frontmostWindows()` (`Launcher.swift:398`).
- `isUnanswering` is one flag per adapter, not per pid. That works today only because the adapter holds one app's listing at a time.

### Who calls it (the model, `LauncherCore/Launcher.swift`)

- Swipe begin (`:339-347`): only `system.runningApps()`. No window read today.
- Window swipe begin (`:374-384`): `WindowSwitcher.Content(system.frontmostWindows())`. The read is synchronous inside `onEvent`, because `hardware.confirmWindowSwipe(on:)` must be called during that call (`WindowSwipeConfirmation.swift:16-26`, `Ports.swift:27-31`).
- Each selection crossing onto a visible row (`:393`): `system.raiseWindows([window])`.
- End (`:396-403`): a second read, `open.lift(now: system.frontmostWindows())`, then `system.raiseWindows(lift.raises)`. The lift matches windows across the two reads only by `WindowID` (`WindowLift.swift:51-65`).

---

## Files Read

- `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift` (whole)
- `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` (whole)
- `LauncherKit/Sources/LauncherPlatform/LaunchWatch.swift` (whole)
- `LauncherKit/Sources/LauncherPlatform/LaunchClock.swift` (whole)
- `LauncherKit/Sources/LauncherPlatform/RunningApp.swift`, `RunningAppsReader.swift`, `ActivationTracker.swift`, `LaunchServicesOrder.swift`, `BackgroundHider.swift` (1-125), `QuitSignals.swift` (1-34), `UptimeNow.swift`, `LaunchOverlay.swift` (70-115), `SystemAppScanner.swift` (30-60)
- `LauncherKit/Sources/LauncherCore/Ports.swift` (whole), `WindowSwitcher.swift` (whole), `WindowLift.swift` (whole), `WindowSwipeConfirmation.swift` (1-33), `Launcher.swift` (320-420), `Apps.swift` (`AppEntry`, `RunningApps`)
- `LauncherKit/Sources/LauncherUI/PreviewCapture.swift` (1-61), `SwitcherPresenter.swift` (1-130)
- `TrackpadLauncher/TrackpadLauncherApp.swift` (60-110)
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (banned list, confined list, scan implementation `:306-311`, `:411-414`, `:518-546`)
- `LauncherKit/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift` (1-80)
- `LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift` (385-470)
- `docs/architecture.md` (Shape, Concurrency, Privacy), `docs/domain-model.md` (92-112), `docs/performance.md` (40-56)
- `plans/042-window-stacks-switcher-order/plan.md`, `development-logs.md`
- `plans/012-window-switcher-gesture/plan.md` (380-440, 665-700, 1085-1135, 1262-1275, 1428-1484, 1540-1580), `development-logs.md` (grep)
- `plans/012-window-switcher-gesture/.temp/architect/grounding/index.md` (40-130, 280-300), `probes/README.md`, `probes/probe-2-ax-windows.output.txt`, `probes/probe-3-capture.output.txt`, `probes/probe-5-spaces.output.txt`
- `plans/012-window-switcher-gesture/.temp/slices/*.md` (grep for timeout and M18)
- `plans/015-vscode-window-titles/plan.md` (123), `development-logs.md` (19)
- SDK header `.../HIServices.framework/Versions/A/Headers/AXUIElement.h` (lines 96-105, 186-244, 387-402)

---

## Boundaries

**Into the adapter:** nothing but the system. `read()` takes no arguments. It picks the pid itself from `NSWorkspace.shared.frontmostApplication`. No port method today takes an app, a pid or a bundle ID for a window read.

**Out of the adapter:** `FrontmostWindows` (Sendable value). It holds `AppEntry` plus `[AppWindow]`, each with `WindowID(rawValue: CGWindowID)`, title and `isFullScreen`. AX handles never cross the port. They stay in `listed`.

**Port signatures (verbatim, `Ports.swift:127-138`):**
```swift
/// The active app and the ⌘-Tab apps, read now from their one source of truth.
func runningApps() -> RunningApps
/// The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout
/// (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later `raiseWindows`
/// may name, until the next read.
func frontmostWindows() -> FrontmostWindows
/// Raises these windows of the latest `frontmostWindows()` read, the last first, ... About 2 ms per raise; once the
/// app has timed out, no further calls go to it for that read. [] does nothing.
func raiseWindows(_ frontToBack: [WindowID])
```
`SystemActions` is `@MainActor public protocol` (`Ports.swift:61`). Every member is synchronous, and no member is async or callback-based for windows. The only push-style member is `onLaunchProgress`.

**`AppEntry` carries no pid** (`Apps.swift:12-30`: `bundleID`, `name`, `url`), and `RunningApps` carries no pid (`:33-51`). To read up to 10 switcher apps, the platform must map an entry back to a process:
- `LaunchServicesOrder` already requests `"pid"` per app (`LaunchServicesOrder.swift:20`) and discards it in `entries(_:)` (`:46-55`).
- The fallback path has pids in `RunningAppsReader.fallbackApps()` (`:28-38`).
- Two running copies with the same bundle ID are possible. `SwitcherPresenter.terminated` (`LauncherUI/SwitcherPresenter.swift:84-85`) guards for "a second copy of the same bundle".

**App lifecycle observation: no port carries launch, terminate or activate to the model.**
- `ActivationTracker` (`ActivationTracker.swift:9-18`) observes `NSWorkspace.didActivateApplicationNotification` on `.main`. It exists only when `LaunchServicesOrder` failed to resolve (`RunningAppsReader.swift:13-16`). Its `recency: [Int32]` (pids) is used only by `FallbackOrder`.
- `BackgroundHider` (`BackgroundHider.swift:57-64`) observes `didActivateApplicationNotification` and `didUnhideApplicationNotification`, only during a hide run.
- `SwitcherPresenter` in LauncherUI (`SwitcherPresenter.swift:51-63`) observes `didLaunchApplicationNotification` and `didTerminateApplicationNotification` to keep its icon cache. These are shell-only, never reach the model, and run only while the swipe setting is on.
- `LaunchWatch` uses KVO on `NSRunningApplication.isTerminated` and `isFinishedLaunching` for one watched launch (`LaunchWatch.swift:81-90`).
- `QuitSignals` observes `willPowerOffNotification` (`QuitSignals.swift:12`).
- The model's only pushes from `SystemActions` are `onLaunchProgress` (`Ports.swift:125`). For R7's "app quitting forgets its order", the model has no termination push today. It sees processes only through `runningApps()` (bundle-ID and URL level, no pid) and `hasProcess(_:)` (`Ports.swift:101`).

**Source-scan confinement** (`SourcePolicyTests.swift`):
- `:172` `Confined(token: "AXUIElement", onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers")`
- `:173` `Confined(token: "CGWindowList", onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers")`
- `:80-81` banned everywhere: `AXUIElementSetAttributeValue`, `kAXPressAction`.
- `:148-150` `ScreenCaptureKit`, `SCShareableContent`, `SCScreenshotManager` only in `PreviewCapture.swift`.
- `:144` `AXIsProcessTrusted` only in `SystemPermissions.swift`.
- `:151` `systemUptime` only in `UptimeNow.swift` ("the process's clock is read in one place").
- `:52-57` banned everywhere: `asyncAfter`, `Timer`, `makeTimerSource`, `DispatchSourceTimer`, `Task.sleep`, `displayLink`, `DisplayLink`. `:76` bans `nonisolated(unsafe)`. `:239-245` re-checks that the timer bans stay listed.
- The scan is a case-sensitive substring match per line, comments included (`hits(in:for:)` `:541-546`). It covers `LauncherKit/Sources` and `TrackpadLauncher/` (`scannedRoots` `:306-311`), not tests. A comment that spells `AXUIElement` or `Timer` in any other file fails. Plan 012 `:825` notes "Core comments never spell the confined API names".
- The `AXUIElement` token catches `AXUIElementCreateApplication`, `AXUIElementCopy…`, `AXUIElementPerformAction`, `AXUIElementSetMessagingTimeout` and `_AXUIElementGetWindow`. It does not catch `kAXWindowsAttribute`, `AXValue…`, `AXObserver…`, `AXError` or the type name in a `@convention(c)` typealias written without the token. Any new file that reads windows must be added to `onlyIn` on both lines, or the code must live in one of the two files. `docs/architecture.md` Privacy (line 24 of the file, the "two (the frontmost app's window read and the launch watch)" sentence) would need its wording changed too.

**Docs that describe this boundary and would change for 042:**
- `docs/architecture.md` Concurrency. Verbatim: "Every slide up or down reads the frontmost app's windows when it starts, and a window swipe raises them, through the Accessibility API on the main actor: synchronous calls into another app, about a millisecond each, each bounded by a short messaging timeout, after which that app gets no further raises until it is read again; the window list's first call in the process (about 50 ms) is paid off the main actor at launch."
- `docs/architecture.md` Concurrency also says "Time passes only on Core Animation's clock" with the named exceptions, and "Work that would delay a click ... runs off the main actor in explicitly concurrent functions".
- `docs/architecture.md` Privacy: Accessibility is used "to list the frontmost app's windows when two fingers start sliding up or down under the thumb". Reading other apps' windows at swipe begin is a new use that this sentence does not cover.

---

## Answers to the angle's specific questions

### Is the read synchronous on the main actor today?
Yes. `FrontmostAppWindows` is `@MainActor final class` (`:13`), and `read()` and `raise` are main-actor instance methods. In a `@MainActor` class the private static helpers `rawWindow`, `onScreenNumbers`, `listedWindows` and `windowList` (`:109-147`) are main-actor-isolated too, because only `sort` and `number(of:among:)` are marked `nonisolated` and `warmWindowList` is `@concurrent`. The model calls `read()` inline in `Launcher.windowSwipe(.began)` and `.ended`.

### How long does one app's read take?
There is no end-to-end measurement of `read()` anywhere in the repo. The figures are component probes on TextEdit with 3 windows (F8, `probe-2-ax-windows.output.txt`):
- `kAXWindowsAttribute`: 0.29 ms.
- Describing 3 windows with 8 attributes each: 0.62 ms.
- CG list, on-screen: 22.47 ms in probe 2 (cold), 52.15 ms cold and 1.26 ms warm in probe 3, and 0.40 ms "third call + pid filter".

The "about a millisecond" in `Ports.swift:129` and in architecture.md is an estimate from these numbers. `docs/performance.md:51` gives only CPU per frame for window swipes (0.58 ms), not read latency. `_AXUIElementGetWindow` was not timed separately.

### What bounds a read in time?
Each AX IPC call is bounded by the 0.2 s process-wide messaging timeout. The read as a whole is not bounded by 0.2 s:
- A hung app costs one timeout at `kAXWindowsAttribute` (then returns empty). If it hangs mid-loop, it costs one timeout at the next `CopyMultipleAttributeValues` (then breaks with a partial list), plus possibly one more if `_AXUIElementGetWindow` is IPC and times out (its failure does not stop the loop, `:102-106`).
- A slow app that answers each call just under 0.2 s can take about (1 + N, or 1 + 2N) × 0.2 s for N windows.

So the port doc "at most one messaging timeout (0.2 s) when the app does not answer" holds for an app that stops answering. It does not hold for a slow app. A per-app 0.2 s deadline needs something beyond the per-call timeout. Options within the codebase rules:
- Set `AXUIElementSetMessagingTimeout` on each element to the remaining budget. A per-element setting affects only that element (`AXUIElement.h:390`), and window elements returned by AX are new objects that use the global value.
- A `LaunchClock`-style Core Animation deadline on the main actor that discards late results.
- Elapsed-time checks between calls through `Uptime.now` (`UptimeNow.swift:6`).

`Task.sleep`, `asyncAfter` and `Timer` are banned by the source policy.

### What would 10 concurrent off-main reads need?
- **Adapter state.** `listed: [WindowID: AXUIElement]` and `isUnanswering: Bool` are main-actor state. Each `read()` overwrites both, so stack-count reads must not go through `read()`, or they would replace the frontmost app's raise handles. `getWindow` is an immutable C function pointer resolved in `init`. `sort` and `number(of:among:)` are already nonisolated and pure. `rawWindow`, `windowList`, `onScreenNumbers`, `listedWindows` and `number(of element:)` would need `nonisolated`.
- **Sendability.** A typecheck under `-swift-version 6` gives `type 'AXUIElement' does not conform to the 'Sendable' protocol` (verified with `swiftc -typecheck`). An element created off main cannot be handed to the main actor without a wrapper. The codebase has precedent for `@unchecked Sendable` wrappers: `private struct Unchecked<Value>: @unchecked Sendable` (`ClickTap.swift:149`), `Remaining` (`SystemRunningCopies.swift:65`) and `AppIcons.Appearance` (`LauncherUI/AppIcons.swift:22`). `nonisolated(unsafe)` is banned. Counting only, which returns `Int` or `[WindowID]`, needs no element to cross.
- **Thread safety of AX.** `AXUIElement.h` says nothing about threads (grep for "thread" finds nothing). The repo has no precedent of an AX call off the main thread. Both readers are `@MainActor`, and `LaunchWatch`'s `AXObserver` source is on the main run loop (`LaunchWatch.swift:139`). Off-main AX safety is therefore not asserted or verified anywhere in the repo, so the architect should probe it.
- **CGWindowList off main has precedent.** `warmWindowList` is `@concurrent` (`FrontmostAppWindows.swift:41-43`), and `LaunchWatch.listedWindows(of:)` is `nonisolated static` (`LaunchWatch.swift:163-167`).
- **CGWindowList calls per read.** Every call copies all windows system-wide (`kCGNullWindowID`) and filters by pid on the client side: one or two calls per `read()`. Ten per-app reads built from today's code would make 10 to 20 system-wide copies. One shared copy, filtered per pid, would do the same job.
- **Off-main conventions.** The architecture rule is "explicitly concurrent functions": `@concurrent` static funcs (`FrontmostAppWindows.swift:41`, `PreviewCapture.swift:24`, `SystemAppScanner.swift:41`, `LaunchOverlay.swift:88`, `ApplicationsInstaller.swift:70`, `AppIcons.swift:109`). Fan-out precedents:
  - `PreviewCapture` uses `withTaskGroup` with one child task per window (`:32-44`).
  - `LaunchOverlay.renderOffMain` uses `DispatchQueue.concurrentPerform` with a `Mutex` (`:88-95`).
  - Both have width limited by CPU count. A blocking AX call inside a Swift cooperative-pool task holds a pool thread for up to 0.2 s per call. With more hung apps than pool threads, the remaining reads would queue, which breaks R4's "never delays the other apps". This is a design concern from the runtime model, not measured.
- **Results back to main.** Results reach main the same way as other off-main work: `await` in a main-actor `Task`, as in `SystemAppScanner.scan()` and `SwitcherPresenter.pass(over:)` (`SwitcherPresenter.swift:91-98`).

### Window identity
- **`WindowID`** is the window server's `CGWindowID`, the same number from AX (`_AXUIElementGetWindow`), the CG list (`kCGWindowNumber`) and ScreenCaptureKit (`SCWindow.windowID`). Probe 2 shows `cgid` equal to the CG `number`. Probe 3 shows SC and CG orders and ids agree.
- **The doc comment** "stable for the window's life" (`WindowSwitcher.swift:3-4`) is asserted, not proved. Probe evidence for stability:
  - Across minimise: Beta stayed `cgid=6864` before and after minimise (`probe-2…output.txt:7, 39`). After restore the probe prints titles only, not cgids.
  - Across going full screen, which is a move to a new Space: Beta was `6895` before and after (`probe-5…output.txt:3, 9`).
  - Across a Space switch caused by `AXRaise`: Alpha was `6896` before and after (`:4, 12`).
  - Not probed: whether numbers are ever reused after a window closes, stability across an app's own "re-create window" behaviour (tab drag-out and merge, apps that rebuild windows on full screen), and stability across a display change or sleep.
- **What the code uses across reads.** It never compares AX elements across reads. Elements are re-fetched per read, and `listed` is rebuilt each read (`:84-88`). Identity across reads is purely `WindowID`, as in `WindowLift.lift(now:)` (`WindowLift.swift:51-65`). `pid` is not part of `WindowID`. Within one window server session, CGWindowIDs are unique across processes, so `WindowID` alone keys a window. The window's owner pid is not carried.
- **Fallback windows** keep the same `WindowID` identity, because the fallback finds the CG number. A fallback window whose frame and title are ambiguous gets no number and is not listed at all.
- **Relaunch.** The 042 plan's non-goals already say "Window identities do not survive an app relaunch". New process, new windows, new numbers.

### "No answer within 0.2 s" for the frontmost read
Today the adapter knows the answer (`isUnanswering`), but the port does not carry it:
- `FrontmostWindows` has only `.noApp` and `.app(entry, visible:, minimised:)` (`WindowSwitcher.swift:26-34`). Its doc lumps together "no windows", "Accessibility missing", "did not answer" and "it is Trackpad Launcher" as both-empty.
- A timeout mid-loop returns a partial non-empty list (`:68-72`), so "did not answer" is not even always "both empty".
- For R10 (zero windows → card) versus R13 (no answer → no card, and no Accessibility → no card), the port result must distinguish answered-with-zero from not-answered, not-trusted and own-app.
- The window-swipe start is answered synchronously during `onEvent` (`WindowSwipeConfirmation.deliver`, `WindowSwipeConfirmation.swift:16-26`). A frontmost read that went async would also need the confirmation mechanism changed. Today it must finish before `onEvent` returns.

---

## Non-Obvious Things

1. **The timeout is process-wide, not per app or per element.** One `AXUIElementSetMessagingTimeout` on the system-wide element at `FrontmostAppWindows.init` (`:34`) is the default for every AX element in the process, `LaunchWatch`'s included. `LaunchWatch` also sets 0.2 on its own app element (`LaunchWatch.swift:100`), which is redundant because both adapters live in `WorkspaceActions`. Plan 012's dev log `:24` records this choice: "the AX messaging timeout was set on the app element only → set once on the system-wide element". The adapter ignores the return value.

2. **"At most one messaging timeout" is not a bound on read time.** It holds for an app that stops answering. A slow-but-answering app costs one near-0.2 s wait per call (1 + N, possibly 1 + 2N, calls). `_AXUIElementGetWindow` failures do not set `isUnanswering`.

3. **Minimised windows get no Space or role test.** `sort` admits any element with `AXMinimized == true` (`:159-160`). Two consequences:
   - A minimised window that belongs to another Space, if AX lists it, would be listed and counted. Not probed: probe 5 had no minimised window.
   - The "minimised order" is the AX order, which F8 observed follows z-order with minimised windows last. It is not documented and was observed only on TextEdit.

4. **Hidden apps.** A hidden app's windows are not in the `.optionOnScreenOnly` CG list. That is standard window-server behaviour, but not probed in this repo. `sort` would then list only its minimised windows. `BackgroundHider` hides every other Dock app when *Hide background apps* is on (`BackgroundHider.swift:108-120`). If 042's stack counts reuse `sort` unchanged, a hidden app with several windows would count 0 or only its minimised windows. What `kAXWindowsAttribute` returns for a hidden app was never probed.

5. **Full-screen Space context.** When the frontmost app is full screen, the current Space is that full-screen Space. Other apps' desktop windows are then not on screen there, so per-app counts made the same way would be 0 (minimised aside) for every other app. This follows from F10 and F11. Never probed for background apps.

6. **The window read does not substitute for Trackpad Launcher itself.** `RunningAppsReader.frontmost` substitutes the previous app when Trackpad Launcher is active without its Dock icon (`RunningAppsReader.swift:43-48`). `FrontmostAppWindows.read()` returns `.app(own entry, [], [])` for its own pid (`:50-52`), added in commit `7bcb68d`. The two reads also query different sources (`NSWorkspace.frontmostApplication` versus LaunchServices) at slightly different moments. Under 042's R10 (zero windows → card), Trackpad Launcher frontmost would read as "zero windows" unless the new result distinguishes it.

7. **The read side-effects the raise handles.** `read()` rebuilds `listed` and resets `isUnanswering`. Any extra read through the same object, for example a stacks read of the frontmost app at swipe begin, would replace the window switcher's handles. The rule "after a timeout that app gets no further raises until read again" is implemented by `read()` resetting the flag (`:47`). A hung app therefore pays another 0.2 s at the lift's second read (accepted in plan 012 Tradeoffs `:1430-1434`, dev log `:47`).

8. **AX elements are created fresh per read.** `AXUIElementCreateApplication(pid)` runs on every read (`:56`), and window elements come back new each time. Nothing caches across reads, and nothing compares elements.

9. **Raised windows are only ever from the latest read**, which is how "nothing on another Space is ever raised" holds. Probe 5 showed `AXRaise` on another Space's window switches Spaces (F24). A stable-order design that lists ids from a remembered order must still raise only ids the latest read listed.

10. **The source scan matches substrings in comments too.** A new file whose doc comment mentions "AXUIElement" or "CGWindowList", or any file mentioning "Timer", fails the test. To add a third AX reader file, edit both `Confined` lines (`:172-173`) and the architecture Privacy sentence ("the Accessibility element API with the window list to two (the frontmost app's window read and the launch watch)").

11. **No timers allowed. The 0.2 s deadline must come from AX itself or from Core Animation's clock.** `LaunchClock` is the precedent: each deadline is a `CABasicAnimation` on a layer in a never-ordered-in 1-pt `NSPanel`, created with the first clock and closed with the last (`LaunchClock.swift:18-26, 31-49, 69-81`). Its `Deadline.animationDidStop` treats a system-caused stop (`finished == false`, not cancelled) as passed (`:86-97`).

12. **`AXUIElementCopyMultipleAttributeValues` with options 0.** A per-attribute error comes back as an `AXValue` of error type in the array (`AXUIElement.h:233-236`). `rawWindow` reads such slots as nil or false (`:108-124`). A window whose subrole slot errors is therefore dropped as non-standard, and one whose minimised slot errors reads as not minimised. Whether a timeout surfaces as the function's return or as error values in the array was not probed. The code assumes the function return (`:69`).

13. **CG list cost.** The cold call cost (about 50 ms) is paid once off main. Each later read still copies the whole system's window list one or two times (about 0.4 to 1.3 ms warm, probe 3).

14. **`LaunchServicesOrder` already fetches `pid`.** It is in `keys` (`:20`) but unused. That is the cheapest source of per-app pids aligned with the switcher's ⌘-Tab entries.

15. **The minimised subrole quirk.** A minimised TextEdit window reported subrole `AXDialog` (probe 2 line 39). That is why minimised windows bypass the subrole filter. It was observed on TextEdit only.

---

## Open Questions (unverified platform claims the architect should probe)

1. **Off-main AX calls.** Is it safe to call `AXUIElementCopyAttributeValue`, `AXUIElementCopyMultipleAttributeValues` and `_AXUIElementGetWindow` from non-main threads, concurrently for different pids, while the main thread makes AX calls (raises, `LaunchWatch`)? There is no header statement and no repo precedent.
2. **`_AXUIElementGetWindow`.** Is it an IPC round-trip to the app, or answered locally? Can it time out, and what does it cost per window? Never timed separately.
3. **End-to-end read time.** What is one `read()`'s real latency for typical apps (Safari, Chrome or Electron, Finder, Xcode, Mail) and for many windows? Only TextEdit components were measured. Does the first AX query of an app pay a warm-up? Plan 012 O5 and open question 5 raise this for Chromium and Java apps, and it was never probed.
4. **Hidden apps.** What do `kAXWindowsAttribute` and the CG on-screen list give for a hidden app (relevant with *Hide background apps* on)?
5. **Background apps and Spaces.** Does `kAXWindowsAttribute` omit a non-frontmost app's other-Space windows the way it did for the frontmost TextEdit (F10)? Are minimised windows "of another Space" listed?
6. **The Finder "Get Info" panel's subrole** (042 R2 scenario). The filter assumes it is not `AXStandardWindow`. Not probed.
7. **Behaviour of a slow app under the 0.2 s per-call timeout.** Does `CopyMultipleAttributeValues` return `.cannotComplete`, or `.success` with error values? Probe with `kill -STOP` mid-read, or with an app throttled by a debugger.
8. **Window number reuse after close**, and stability across app-driven window re-creation (tab tear-off and merge, Safari or Chrome full screen, VS Code window reloads). These matter for R7's "a window closing leaves the order, a new one joins at the end".
9. **The `AXRaise` restore of a minimised window** was verified on TextEdit only (plan 012 open question 11).
10. **Cooperative pool versus GCD.** How do blocking AX calls behave in a Swift `TaskGroup` (pool width equals core count) versus a dispatch queue, when several apps hang at once? Not measured. It is relevant to R4's "never delays other apps".
11. **Manual check M18 (hung app).** I could not confirm from the logs whether it was actually run. Plan 012 open question 13 states the timeout has no automated test. `FakeWindows.answers = false` is the only test handle, and it models "lists nothing", not a partial list.
