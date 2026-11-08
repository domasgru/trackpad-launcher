# How the window swipe works: recognition and the model's window-swipe logic (LauncherCore side)

Paths are relative to the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order/`. Line numbers are as of commit 2a4df98.

## Components Found

### Domain types (LauncherCore)
- `WindowID`: `LauncherKit/Sources/LauncherCore/WindowSwitcher.swift:5-9`. `public struct WindowID: Hashable, Sendable { public let rawValue: UInt32 }`. The doc comment calls it "the window server's number for one window: the one number the Accessibility API, the window list and screen capture all report, stable for the window's life." **Identity is the CGWindowID (window number). No AX element token crosses the port.**
- `AppWindow`: `WindowSwitcher.swift:12-23`. `public struct AppWindow: Equatable, Sendable, Identifiable { public let id: WindowID; public let title: String /* "" when untitled */; public let isFullScreen: Bool }`, with `init(id:title:isFullScreen: Bool = false)`.
- `FrontmostWindows`: `WindowSwitcher.swift:26-34`, the result of one read:
  ```swift
  public enum FrontmostWindows: Equatable, Sendable {
      case noApp
      case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])
  }
  ```
  `visible` lists the windows on the current Space, front to back. `minimised` is in the app's own order. Both lists are empty when the app has no windows, when Accessibility is missing, when the app timed out, or when the app is Trackpad Launcher itself (doc at :29-32). **The read does not tell these empty cases apart.**
- `WindowSwitcher`: `WindowSwitcher.swift:38-136`. It is the window switcher's state for one window swipe:
  - `Content { app: AppEntry; windows: WindowList }` (:40-44).
  - `WindowList` (:47-52): `.front(AppWindow, others: [AppWindow], minimised: [AppWindow])` or `.minimisedOnly(first: AppWindow, rest: [AppWindow])`. Its doc says "Two to `GestureRules.windowSwitcherMaxRows` windows in all", so the type has no 0- or 1-row case.
  - `Row` (:54-71): `.visible(WindowID, title:)` or `.minimised(WindowID, title:)`.
  - `content`, `selection: SwitcherSelection` (`package(set)`), `serial: Int` (the count of window swipes since launch, used by the presenter to tell one swipe's switcher from the next), `trackpad`, `showsPreviews` (:73-80).
  - `package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID)` (:83-89). It sets `selection = SwitcherSelection(count: Self.rows(of: content).count)`, so **the selection always starts on row 0**.
  - `rows` (:96-119) is computed on every access. It lists visible rows first, then minimised rows. A title of "" becomes `Copy.untitledWindow(of: app.name, position: index + 1)` (`Copy.swift:49-51`, "\(appName) — Window \(position)"). Any other title goes through `WindowTitleRule.displayTitle(_:of:)`.
  - `previewWindows` (:122-125), `frontWindow: WindowID?` (:128-130, nil for `.minimisedOnly`), `selectedVisibleWindow: WindowID?` (:133-135, nil on a minimised row).
- `WindowSwitcher.Content.init?(_ read: FrontmostWindows)`: `WindowSwitcher.swift:145-165`. This is **the one parse that decides whether a slide is a window swipe**:
  - `.noApp` gives nil.
  - If there is a visible window, `visible.first` is the front window. A full-screen front window gives nil (:151). `others` = the remaining visible windows minus full-screen ones, `prefix(limit - 1)`. `rest` = `minimised.prefix(limit - 1 - others.count)`.
  - With no visible window, the first minimised window is the head and the rest are `prefix(limit - 1)` (`.minimisedOnly`).
  - `guard count >= 2 else { return nil }` (:163). **This is the ">= 2 windows" rule.**
  - **The 10-window cap rule:** `limit = GestureRules.windowSwitcherMaxRows` (10). Visible windows take priority, minimised windows fill whatever slots are left, and the front window always counts as one.
- `WindowStack.raises(current:target:)`: `LauncherKit/Sources/LauncherCore/WindowLift.swift:4-26`. A pure function that returns the shortest front part of `target` which, raised back to front, leaves the target windows in `target` order among themselves. Its rules:
  - The first target window is always included unless it already leads `current`. This is how a minimised first target gets restored.
  - Target windows other than the first that are not in `current` are dropped, so a later minimised window is never restored.
  - An empty result means the order already holds.
- `WindowLift { raises: [WindowID]; playsHaptic: Bool }`, with `static let nothing`: `WindowLift.swift:30-40`.
- `WindowSwitcher.lift(now: FrontmostWindows) -> WindowLift`: `WindowLift.swift:51-65`. Pure; the lift rules are below.
- `SwitcherSelection`: `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift:6-57`. The selection math is **shared by both switchers** (`Switcher.selection`, `Switcher.swift:14`, and `WindowSwitcher.selection`):
  - `package init(count:)` clamps to `max(count, 1)`, with the comment "a one-item switcher rubber-bands at both ends" (:7-17).
  - `follow(_ reportedMM:) -> Int` returns the number of items crossed (:23-35).
  - `selected` (:39-42) is the nearest item: `round(travel/12)` half away from zero, clamped.
  - `position` (:46) and `stretch` (:50-54) drive the rubber band.
- `GestureRules` (`LauncherKit/Sources/LauncherCore/GestureRules.swift`): `windowSwitcherMaxRows = 10` (:34, `package static`), `switcherStepMM = 12.0` (:36), `switcherMaxStretch = 0.2` (:38), `switcherMaxOvershoot = 0.25` (:41), `dragThresholdMM = 3.0` (:21).
- `SlideKind { swipe, windowSwipe }`: `LauncherKit/Sources/LauncherCore/Gesture.swift:26-31`. `SwipePhase { began, moved(travelMM:), ended, cancelled }` is at :34-45, and its `.began` doc says "A window swipe's start is a question". `SwipeEvent { phase; trackpad }` is at :48-56.
- `TrackpadEvent.windowSwipe(SwipeEvent)`: `LauncherKit/Sources/LauncherCore/Ports.swift:3-20`. `init(_ event: Recognition.Event, on:)` is the one mapping both hardware adapters use.
- `WindowSwipeConfirmation`: `LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift:6-33`. It is the main-actor half of the answer, shared by the real and in-memory hardware adapters (described under Flow).
- `Settings.isWindowSwipeOn` (default `false`): `LauncherKit/Sources/LauncherCore/Settings.swift:34`. `Settings.slides` (:46-51) is derived and inserts `.windowSwipe` iff that setting is on.
- `AppEntry { bundleID; name; url }`: `LauncherKit/Sources/LauncherCore/Apps.swift:12-30`. **It carries no pid.** A running app's identity in core is its `url` (location). `RunningApps { frontmost: AppEntry?; apps: [AppEntry] }` is at `Apps.swift:33-51`.

### Ports (LauncherCore/Ports.swift), quoted verbatim
- `TrackpadHardware` (:26-50):
  - `var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }`. Its doc (:27-31) says "A `.windowSwipe(.began)` asks whether its slide is a window swipe. Once the call returns, the adapter answers that start, true only if `confirmWindowSwipe(on:)` was called during it, and the trackpad's recognizer takes the answer before its next frame".
  - `func run(_ trackpads: [Trackpad], corner: ThumbCorner, blockClicks: Bool, blockTapClicks: Bool, slides: Set<SlideKind>, swaps: Bool)` (:42-44).
  - `func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)` (:46). `Haptic` is `{ gesture, lightTick }` (:23).
  - `func confirmWindowSwipe(on trackpad: TrackpadID)` (:49). It works "Only while `onEvent` is handling a `.windowSwipe(.began)` from `trackpad`".
- `SystemActions` (:61-139). These members are the window port:
  - `func runningApps() -> RunningApps` (:128)
  - `func frontmostWindows() -> FrontmostWindows` (:132). Doc: "The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later `raiseWindows` may name, until the next read."
  - `func raiseWindows(_ frontToBack: [WindowID])` (:138). Doc: "Raises these windows of the latest `frontmostWindows()` read, the last first, so the first ends in front of its app with the keyboard focus and the rest behind it in this order ... A raised minimised window is restored. A window that has closed is skipped; an id the latest read did not list is skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no further calls go to it for that read. [] does nothing."
  - `func hideOtherApps(than app: BundleID)` (:70)
  - `var onLaunchProgress` (:125). This is the only push SystemActions makes into the model, and it fires only for watched launches.
- **Error and timeout modes, as seen by the model:** there is no error type. A timeout, a missing permission, the own process or no windows all come back as `.app(entry, visible: [], minimised: [])`. No frontmost app comes back as `.noApp`. Raises are fire-and-forget and return nothing.
- `Permissions.isGranted(_:)` and `onChange` (:147-155). Screen Recording is read only on pushes, never during a gesture.

### Real adapters (LauncherPlatform)
- `WorkspaceActions`: `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift`. It holds `private let windows = FrontmostAppWindows()` (:8). `frontmostWindows()` calls `windows.read()` (:87) and `raiseWindows` calls `windows.raise(_:)` (:89).
- `FrontmostAppWindows` (`@MainActor final class`): `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift:13-176`. It is the only file allowed to touch `AXUIElement` and `CGWindowList`, together with `LaunchWatch.swift` (`SourcePolicyTests.swift:172-173`).
  - `static let messagingTimeout: Float = 0.2` (:15). `init` sets it once on the **system-wide** element (:34), which makes it the process default. It also resolves `_AXUIElementGetWindow` via dlsym (:36-37) and warms `CGWindowListCopyWindowInfo` off-main through a `@concurrent` static (:38-43).
  - `private var listed: [WindowID: AXUIElement]` (:21) holds the AX element per window from the **latest** read. It is the only state, and it is replaced by each read. `isUnanswering` (:23) is reset per read.
  - `read()` (:45-90) works through these steps:
    1. It takes `NSWorkspace.shared.frontmostApplication` and returns `.noApp` if there is none or no entry.
    2. For its own pid it returns empty lists (:50-51).
    3. It reads `kAXWindowsAttribute` of `AXUIElementCreateApplication(pid)`. On failure it returns empty lists and sets `isUnanswering` on `.cannotComplete` (:55-60).
    4. For each element it calls `AXUIElementCopyMultipleAttributeValues` for role, subrole, title, minimised, "AXFullScreen", position and size. `.cannotComplete` stops the loop, and whatever was read so far still counts (:64-76).
    5. Windows without a number are matched by frame and title against the `.optionAll` window list (:77-82).
    6. `sort(raw, onScreen: onScreenNumbers(of: pid))` (:83).
    7. It fills `listed` (:84-88).
  - `raise(_:)` (:94-100) performs `kAXRaiseAction` on each id in reverse order. It skips ids not in `listed` and stops for good once one call returns `.cannotComplete`.
  - `nonisolated static func sort(_:onScreen:)` (:152-167) decides which windows count as **visible**: `AXWindow`/`AXStandardWindow`, not minimised, and present in the `.optionOnScreenOnly` list, ordered by that list (front to back). Minimised windows are picked by the minimised flag alone, in AX order. **A standard window that is neither on screen nor minimised (another Space) is dropped.** The platform test `FrontmostAppWindowsTests.swift:58-61` (`aStandardWindowNeitherOnScreenNorMinimisedIsOnAnotherSpaceAndLeftOut`) pins this.
- `DeviceSession` / `FrameStream`: `LauncherKit/Sources/LauncherPlatform/FrameStream.swift`. It holds `struct WindowSwipeAnswer { let began: FrameTime; let isWindowSwipe: Bool }` (:6-9) and `private let answer = Mutex<WindowSwipeAnswer?>(nil)` (:37). The main actor writes the answer through the reply, and the frame thread reads it.
- `MultitouchTrackpads`: `LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift`. It owns `private let confirmation = WindowSwipeConfirmation()` (:23). Its `deliver` closure is at :98-108, and `confirmWindowSwipe(on:)` forwards to `confirmation.confirm(on:)` (:127). The haptic strengths are `actuation(for:)` (:130-135): gesture 6, light tick 3.

## Flow

### 1. Recognition of a slide up or down (frame thread; `GestureRecognizer.swift`)
1. **States.** The thumb anchors (`.armed`) and exactly two fingers land (`.tapping`). If they rest past 400 ms the state becomes `.resting(anchor, Pair)` (:139-165). `Pair` exists only when `slides` is non-empty and exactly two fingers have touched (:142, :370-375).
2. **Direction.** Each frame, `drag(of:in:book:on:)` (:424-436) takes the **farthest-moved** finger's displacement from its landing point, in mm (normalised delta times surface mm). It returns a `Move` only past `dragThresholdMM` (3 mm, strictly greater).
   - `Move.slide` (:420) is `abs(dx) > abs(dy) ? .swipe : abs(dy) > abs(dx) ? .windowSwipe : nil`. A tie is neither.
3. **The one place direction is decided** is `beginOrSpoil` (:317-326):
   - If there is no pair, no kind, or the kind is not in `slides`, the state becomes `.spoiled(anchor)`.
   - Otherwise it creates `Swipe(kind:, began: time, isConfirmed: kind == .swipe, ...)` and emits `.slide(kind, .began)`. **A window swipe starts unconfirmed; a swipe starts confirmed** (:324).
4. **`.swiping`** (:172-216) emits `.moved(travelMM:)` when travel changes. Travel comes from `SwipeTravel.travel(along:dxMM:dyMM:interval:)` (`PointerCurve.swift:148-156`): `dyMM` for a window swipe, positive downwards (y=0 is the top edge, `Surface.swift:3`). It is `.linear` in tests and `.cursor(curve, pointsPerStep: 100)` in the real session, installed on the `beginsSlide` frame (`FrameStream.swift:66`).
   - `.ended` comes when both fingers have lifted (:190-193).
   - `.cancelled` comes on a click, or when the finger count plus joining fingers exceeds 2 (:187-189).
   - Kind never changes after begin.
5. **Blocking** (:218-243). A confirmed swipe sets `.clicks`. An *unconfirmed* window swipe follows the thumb rules: the `State.thumb` of an unconfirmed swipe is its thumb (:485-490), and with no thumb it is `.possible` (:232-233).

### 2. The start hops to the main actor (`FrameStream.swift:57-84`, `MultitouchTrackpads.swift:98-108`)
1. In `DeviceSession.receive(_:)`, for a recognition whose `windowSwipe == .began`, the session builds a `reply` closure that writes `WindowSwipeAnswer(began: frame.time, isWindowSwipe:)` into the `answer` Mutex (:76-81). It then calls `deliver(TrackpadEvent(event, on: trackpad), reply)`.
2. `deliver` does `DispatchQueue.main.async { MainActor.assumeIsolated { guard self.runs == generation ...; let answer = self.confirmation.deliver(event, to: self.onEvent); if let reply, let answer { reply(answer) } } }`. Events from a replaced session are dropped, reply included. Main-queue FIFO keeps frame order.
3. `WindowSwipeConfirmation.deliver(_:to:)` (`WindowSwipeConfirmation.swift:16-26`) works like this:
   - For a `.windowSwipe` with `.began` it saves the outer value, sets `startBeingHandled = (trackpad, false)`, calls the handler (`Launcher.onEvent`), and returns `startBeingHandled?.confirmed ?? false`.
   - Every other event is passed through and gets the answer `nil`.
   - `confirm(on:)` (:30-32) sets `confirmed = true` only if the trackpad matches the start being handled.
4. **The hop back:** the reply writes the Mutex. On the **next frame**, `receive` reads `answer` and calls `recognizer.answerWindowSwipe(began:isWindowSwipe:)` before `step` (:58-62). The answer is never cleared.
5. `GestureRecognizer.answerWindowSwipe(began:isWindowSwipe:)` (:254-262) applies the answer:
   - It ignores the answer unless the state is `.swiping`, still unconfirmed, with `swipe.began == began`.
   - `true` sets `isConfirmed`, so the slide blocks everything from the next frame.
   - `false` turns the state into `.spoiled(thumb)`, or into `restOrIdle(previouslyDown)` if the thumb is gone. **That is exactly the setting-off slide, so it never becomes a swipe.**
   - The frame thread never waits. Until the answer arrives the slide blocks only by the thumb rules.

### 3. The model answers "is this a window swipe?" (`Launcher.swift`)
- **The setting and the permission are not checked in the handler.** They are enforced earlier, in `reconcile()`:
  - `slides: granted ? settings.slides : settings.slides.subtracting([.windowSwipe])` (`Launcher.swift:273`) is passed to `hardware.run`. Without Accessibility, or with the setting off, the recognizer never emits `.windowSwipe`, so no read happens (the test `WindowSwipeNeedsTwoWindowsTests.swift:176-195` expects `reads == 0` and `windowSwipeAnswers.isEmpty`).
  - `setWindowSwipe(on:)` (:179-184) saves and reconciles. Reconcile sets `shown = nil` (:277) and rebuilds the recognizers, which ends any window swipe in progress.
- `Launcher.start()` (:111-128) wires `hardware.onEvent` so that `.windowSwipe(let event)` calls `windowSwipe(event)` (:116).
- `windowSwipe(_:)` handles `.began` at `Launcher.swift:374-386`:
  ```swift
  guard activity.isActive, let content = WindowSwitcher.Content(system.frontmostWindows()) else { return }
  hardware.confirmWindowSwipe(on: event.trackpad)
  guard shown == nil else { return }
  windowSwipesBegun += 1
  shown = .windows(WindowSwitcher(content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun, trackpad: event.trackpad))
  ```
  - The checks run in this order: (1) gestures active; (2) **one synchronous AX read on the main actor**; (3) the frontmost app exists, it is not the own process (whose lists come back empty), it has no full-screen front, and it has two or more rows, all through `Content.init?`. Returning without confirming means "declined".
  - The confirm comes **before** the `shown == nil` check. A second trackpad's slide while any switcher shows is therefore confirmed (it blocks) but shows nothing. The read still happens (`WindowSwitcherOnScreenTests.swift:282-312` expects `reads == 1` and `windowSwipeAnswers == [true]` with no window switcher).
  - `showsPreviews` uses the cached `isScreenRecordingGranted` (`Launcher.swift:49`), which is set in `reconcile` (:263). A fresh preflight would cost about 4 ms.

### 4. Move (`Launcher.swift:387-393`)
- The guard requires `.windows(var open)` with the same trackpad, so events from other trackpads are ignored.
- `let crossed = open.selection.follow(travel)`, then `shown = .windows(open)`, then one `.lightTick` per crossed row.
- `if crossed > 0, let window = open.selectedVisibleWindow { system.raiseWindows([window]) }`. **Raising while sliding** only ever raises the selected visible window. Minimised rows are never raised (raising would restore them). Sliding back to row 0 raises the front window again.
- These raises go through the adapter's `listed`, which comes from the **begin** read.

### 5. Lift (`Launcher.swift:394-403`)
```swift
guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
shown = nil
let lift = open.lift(now: system.frontmostWindows())   // second AX read
if lift.playsHaptic { hardware.playFeedback(.gesture, on: event.trackpad) }
system.raiseWindows(lift.raises)                        // always called, possibly []
if lift.playsHaptic { hideOtherApps(than: open.app.bundleID) }
```
The effects run in this order: the switcher is cleared, the second read happens, the haptic plays, the raises happen, then the hide. `hideOtherApps` (:282-285) does nothing while `isHideBackgroundAppsOn` is off, and the hide runs only when the haptic played.

The rules inside `WindowSwitcher.lift(now:)` (`WindowLift.swift:51-65`):
- If `now` is not `.app`, or its app's `url` differs from the switcher's app, the result is `.nothing` (no raises, silent).
- `selected = rows[selection.selected].window`, `onScreen = visible ids`, and `open = Set(onScreen + minimised ids)`.
- **Lift on a closed window:** if `selected` is not in `open`, the result is `WindowLift(raises: [], playsHaptic: onScreen.first.map { $0 != frontWindow } ?? false)`. Nothing is reordered, and the haptic plays only if the window in front now differs from the begin's front window.
- **Otherwise:** `target = [selected] + visibleAtBegin.filter { $0 != selected && open.contains($0) }`, where `visibleAtBegin` is the visible rows in begin order with the front window first. The raises are `WindowStack.raises(current: onScreen, target: target)`, and `playsHaptic = selected != frontWindow`.
  - That gives the order **selected, then front window, then the other visible windows in begin order**.
  - A minimised selected window is restored because it is the first target and not in `current`.
  - Other minimised windows are not restored.
  - With every window minimised, `frontWindow == nil`, so every row plays the haptic.
  - A lift on the front window restores the begin order silently (`WindowSwitchingTests.swift:114-128`).
  - A window opened mid-swipe ends just behind the raised ones (`WindowSwitchingTests.swift:180-193`).

### 6. Cancel (`Launcher.swift:404-406`)
`if case .windows(let open)? = shown, open.trackpad == event.trackpad { shown = nil }`. There is no second read, no raise and no haptic. The window that was raised while sliding stays in front ("the windows stay as they are"), which `WindowSwitchingTests.swift:232-253` pins.

### 7. Feedback summary for the window swipe
- `.lightTick` plays once per row crossed, on `.moved`, through `hardware.playFeedback(.lightTick, on:)` (:391).
- `.gesture` plays on the lift only when `lift.playsHaptic`.
- A cancel, a declined start, and a lift on the front window are all silent.

### 8. Comparison with the app swipe (`Launcher.swift:338-369`)
The app swipe uses the same `SwitcherSelection.follow`, the same tick loop and the same `shown` slot (`ShownSwitcher.apps`). Its `.began` has no confirmation, because swipes start confirmed. It reads `system.runningApps()` and builds `Switcher(...)`, which may be nil (nothing to switch to). In that case the swipe still runs its course with no switcher. **This is the existing precedent for "a confirmed slide that shows nothing / changes nothing on lift"**.

## Files Read
- docs/architecture.md (full; Concurrency and Privacy sections are relevant)
- docs/domain-model.md (Swipe, Switcher, Running apps, Window swipe, Window switcher, Window, Front window, Title rule, Window swipe setting, Frontmost app, Feedback, Light tick: lines 71-169)
- LauncherKit/Sources/LauncherCore/WindowSwitcher.swift
- LauncherKit/Sources/LauncherCore/WindowLift.swift
- LauncherKit/Sources/LauncherCore/WindowSwipeConfirmation.swift
- LauncherKit/Sources/LauncherCore/SwitcherSelection.swift
- LauncherKit/Sources/LauncherCore/Switcher.swift
- LauncherKit/Sources/LauncherCore/Launcher.swift
- LauncherKit/Sources/LauncherCore/Ports.swift
- LauncherKit/Sources/LauncherCore/Gesture.swift
- LauncherKit/Sources/LauncherCore/GestureRules.swift
- LauncherKit/Sources/LauncherCore/GestureRecognizer.swift
- LauncherKit/Sources/LauncherCore/Settings.swift (lines 28-52)
- LauncherKit/Sources/LauncherCore/Apps.swift (lines 1-55)
- LauncherKit/Sources/LauncherCore/PointerCurve.swift (lines 85-157)
- LauncherKit/Sources/LauncherCore/WindowColumnLayout.swift (lines 1-30)
- LauncherKit/Sources/LauncherCore/WindowTitleRule.swift (lines 1-15), Copy.swift (untitledWindow)
- LauncherKit/Sources/LauncherPlatform/FrameStream.swift
- LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift
- LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift
- LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift (lines 1-40, grep)
- LauncherKit/Sources/LauncherPlatform/ActivationTracker.swift, QuitSignals.swift (lines 1-40), LaunchWatch.swift (grep), BackgroundHider.swift (grep), RunningAppsReader.swift (grep)
- LauncherKit/Sources/LauncherUI/SwitcherPresenter.swift (lines 40-85), WindowSwitcherPresenter.swift (grep)
- LauncherKit/Tests/LauncherCoreTests/InMemoryAdapters.swift (lines 1-140, 240-475)
- LauncherKit/Tests/LauncherCoreTests/World.swift (lines 200-384 plus a grep)
- LauncherKit/Tests/LauncherCoreTests/WindowSwitchingTests.swift (full)
- LauncherKit/Tests/LauncherCoreTests/WindowSwipeNeedsTwoWindowsTests.swift (full)
- LauncherKit/Tests/LauncherCoreTests/WindowSwitcherOnScreenTests.swift (lines 14-40, 262-325, test list)
- LauncherKit/Tests/LauncherCoreTests/SettingsWindowAsAppTests.swift (lines 85-110)
- LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift (lines 50-56, 160-200, 250-270)
- LauncherKit/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift (lines 8-75)
- Test lists (grep of `@Test`) for WindowSwipeAnswerTests, WindowSwipeConfirmationTests, WindowSwipeRecognizerTests, WindowSwipeBlockingTests, WindowPreviewTests, LiftWindowTests, HideBackgroundAppsTests

## Boundaries
- **Input from the frame thread:** `TrackpadEvent.windowSwipe(SwipeEvent)` comes through `TrackpadHardware.onEvent`. The output back to it is the `Bool` answer, through `confirmWindowSwipe(on:)` during the `.began` handling. Nothing else crosses back.
- **Inputs from the system:** `SystemActions.frontmostWindows()` runs twice per window swipe, once at begin and once at lift, both synchronous on the main actor. `runningApps()` is not used by the window swipe.
- **Outputs to the system:** `SystemActions.raiseWindows(_:)` (while sliding: one window; on the lift: the computed list, possibly `[]`), `hideOtherApps(than:)` on a lift that plays the haptic, and `TrackpadHardware.playFeedback(.lightTick | .gesture, on:)`.
- **Output to the UI:** `Launcher.windowSwitcher: WindowSwitcher?` (`Launcher.swift:18-20`), observed by `LauncherUI/WindowSwitcherPresenter.swift:26` through `Observations({ launcher.windowSwitcher })`. The presenter reads `serial` (:47, :64), `rows`, `previewWindows` (:70, :85), the selection and the app.
- **Pushes into `Launcher` today:** `hardware.onEvent` (gestures, swipes, window swipes, swaps, `.trackpadsChanged` from IOKit match/terminate and `NSWorkspace.didWakeNotification`, `MultitouchTrackpads.swift:31-52`), `system.onLaunchProgress` (only for launches the model is watching), `scanner.onScan`, `preferences.onChange` and `permissions.onChange` (`Launcher.swift:112-125`).
- **No workspace app-launch, app-quit or activation notification reaches LauncherCore.** Such observers exist only in adapters and UI:
  - `LauncherUI/SwitcherPresenter.swift:51-62` observes `didLaunchApplicationNotification` and `didTerminateApplicationNotification` for icon passes, only while the swipe setting is on (`startIconPasses`/`stopIconPasses`).
  - `LauncherPlatform/ActivationTracker.swift:9-18` observes `didActivateApplicationNotification` and keeps a pid recency list. It is created only when the private LaunchServices order is unavailable (`RunningAppsReader.swift:15`).
  - `LauncherPlatform/BackgroundHider.swift:58-60` observes `didActivate`/`didUnhide`, only during a hide run.
  - `LauncherPlatform/QuitSignals.swift:10-16` observes `willPowerOffNotification`.
  - `LaunchWatch` uses KVO and an AXObserver, only during a watched launch.
  - Forgetting a per-app order on app quit would therefore need a **new push on a port** (for example on `SystemActions`), with its in-memory twin in `RecordingSystemActions`. Alternatively the order could be keyed by an identity the core does not have today: `AppEntry` has no pid, and an app that quits and relaunches has the same `url`.
- **Source-policy constraints that bear on the design** (`LauncherCoreTests/SourcePolicyTests.swift`):
  - `AXUIElement` and `CGWindowList` are confined to `FrontmostAppWindows.swift` and `LaunchWatch.swift` (:172-173). A new async per-app window-count reader must live in one of those files, or the list must be extended.
  - `Timer`, `asyncAfter`, `makeTimerSource`, `DispatchSourceTimer` and `Task.sleep` are banned (:52-56). A "0.2 s per-app deadline" cannot be a timer. Today the only deadline is the AX messaging timeout: 0.2 s, set process-wide on the system-wide element (`FrontmostAppWindows.swift:34`), and per element in `LaunchWatch.swift:100`.
  - The frame-path files (:255-260) must not mention update tokens. That is irrelevant here, but `FrameStream.swift` and `GestureRecognizer.swift` are on the list.
  - `FrontmostAppWindows` is `@MainActor`, and so are `read()` and `raise()`. The docs say "the window list's first call in the process (about 50 ms) is paid off the main actor at launch" via a `@concurrent` static (:41-43), which is the existing precedent for off-main window-list work.

## Tests: where they live, style, helpers
- **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `@Test(arguments:)`, `#expect`, `#require`). Model suites are `@MainActor @Suite struct ...`. Pure recognizer suites are plain `@Suite struct`.
- **Model-level (World) suites**, all in `LauncherKit/Tests/LauncherCoreTests/`:
  - `WindowSwitchingTests.swift`: sliding raises, the lift order and haptic, closed and minimised windows, windows opened mid-swipe, dropped raises, cancel.
  - `WindowSwitcherOnScreenTests.swift`: appears on the begin frame with row 0 selected; the 10-row cut; fixed list; minimised rows last; untitled naming; 12 mm per row; ticks; rubber band; second trackpad; inactive.
  - `WindowSwipeNeedsTwoWindowsTests.swift`: the ">= 2 rows" rule, declines matching the setting-off behaviour exactly, a window opened mid-slide, no Accessibility.
  - `WindowSwipeBlockingTests.swift`: scrolling and press blocking; `WindowSwipeSettingTests` (setting toggles mid-swipe).
  - `WindowPreviewTests.swift`: Screen Recording and `showsPreviews`.
  - `HideBackgroundAppsTests.swift:241-300`: window swipe hide on the lift only.
  - `SettingsWindowAsAppTests.swift:93-105`: a slide over the settings window is no window swipe.
  - `LiftWindowTests.swift:130`: the tap-action lift window, unrelated to the window lift despite the name.
- **Recognizer and confirmation unit suites:**
  - `WindowSwipeRecognizerTests.swift`: begin past 3 mm, direction, ties, kinds, travel sign, exits.
  - `WindowSwipeAnswerTests.swift`: a declined start equals the setting-off slide; confirmed and late answers.
  - `WindowSwipeConfirmationTests.swift`: `WindowSwipeConfirmation` alone.
  - `WindowColumnLayoutTests.swift` and `WindowTitleRuleTests.swift`: pure.
- **In-memory adapters** (`InMemoryAdapters.swift`):
  - `InMemoryTrackpads` (:6-257) runs the real `GestureRecognizer` per trackpad with `travel: .linear` and holds its own `WindowSwipeConfirmation` (:39).
    - `touch(_:on:)` (:114-135) steps each frame. It delivers events synchronously through `confirmation.deliver`, records each answer in `windowSwipeAnswers: [Bool]` (:41), then immediately calls `running[id]?.answerWindowSwipe(began:isWindowSwipe:)`, modelling "before the next frame".
    - `inject(_:)` (:257) delivers a raw event.
    - `pulses`/`feedback`/`lightTicks` (:12, :50-52).
  - `RecordingSystemActions` (:275-388): `frontmost`, `running`, `let windows = FakeWindows()` (:314), `frontmostWindows()` gives `windows.read(frontmost: frontmost)` (:316), and `raiseWindows` gives `windows.raise(_:)` (:318). It also records `broughtToFront`, `hidesOthers` and `hiddenApps`.
  - `FakeWindows` (:392-473) models one stack, of whichever app is frontmost:
    - `set(visible:minimised:fullScreenFront:untitled:)`; `open(_:)` inserts in front; `minimise(_:)`; `close(_:)`.
    - `id(_:)` gives a stable `WindowID(1000 + n)` per name for the test's life.
    - `answers` (false: reads list nothing); `dropsRaises`.
    - `reads` count, `raised: [[WindowID]]`, and `listed` (raises are limited to the latest read).
    - **It has one window stack shared across all apps.** It is keyed by title, not by app, so a multi-app window-count scenario (stacks) needs an extension: windows per app, plus a way to model a slow or unanswering app.
    - **It does not model the own-process empty read.** With Trackpad Launcher frontmost it lists whatever was `set`; `SettingsWindowAsAppTests` relies on `visible: ["Settings"]` being one window.
- **World helpers** (`World.swift`):
  - `static func windowWorld(visible:minimised:fullScreenFront:untitled:frontmost:accessGranted:screenRecording:attached:)` (:319-333): installs Safari, Mail, Preview, TextEdit and Notes, starts, turns the window swipe on, and puts `frontmost` (default "Safari") in front with these windows.
  - `window(_ title:) -> WindowID` (:336).
  - `windowSwipe(_ slidesMM: Double..., lift:thumbAtMM:on:) -> TouchScript` (:341-350): thumb at (10,10), two fingers at (62,30), slides straight down, optional lift. 3.5 mm begins the swipe; each further 12 mm is one row.
  - `playFrameByFrame(_:on:)` and `playFrameByFrame(_:on:observing:)` (:353-372): per-frame snapshots.
  - `play(_:on:)` (:210-215) plays a script in pieces.
  - `makeFrontmost(_:)` (:232-234), `openSettings()`/`closeSettings()` (:289-303).
  - `perFrame(_:)` (`Fixtures.swift:73`) runs a fresh recognizer over frames, used to find the `.began` frame index.
  - `TouchScript` is in `TouchScript.swift`.
- **Platform tests:** `LauncherKit/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift` tests `FrontmostAppWindows.sort` and `number(of:among:)` as pure statics.

## Non-Obvious Things
1. **The model checks neither the window swipe setting nor Accessibility when a slide begins.** Both are folded into the recognizer's `slides` at `reconcile` (`Launcher.swift:273`). Without them the recognizer never emits a window swipe at all, so there is no read and no answer. The model's own checks at `.began` are only `activity.isActive` and `Content.init?` (frontmost app present, rows >= 2, no full-screen front).
2. **"Is there a frontmost app" and "is it Trackpad Launcher" are folded into the read.**
   - `.noApp` covers the first. The own process returns empty lists (`FrontmostAppWindows.swift:50-51`), so it fails the >= 2 rule.
   - Under design (c) ("0 or 1 window still makes a window swipe"), the model loses that implicit protection. It will need explicit rules for `.noApp`, for the own settings window, for a full-screen front window, and for an app that timed out. All of them come back as the same `.app(entry, [], [])` or `.noApp` shapes.
   - The current read cannot tell "0 windows" from "not answering" from "own process". Any rule that treats them differently needs a richer `FrontmostWindows`.
3. **The confirm comes before the `shown == nil` check** (`Launcher.swift:377-380`). A second trackpad's window swipe is confirmed and blocks even though no switcher shows. The read happens either way.
4. **The decline is load-bearing.** `WindowSwipeNeedsTwoWindowsTests.withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff` (:119-151) compares the whole outcome (frames, press verdicts, pulses, broughtToFront, raised) against a setting-off world, for four fronts and four hands. That includes `.downThenThumbTap`, where the declined slide lets a later thumb tap swap. `aSlideDownIsAWindowSwipeOnlyWhenTheReadListsTwoOrMoreRows` (:21-51) and `SettingsWindowAsAppTests.slidingDownOverTheSettingsWindowIsNoWindowSwipe` (:93-105) also encode the rule. **Design (c) inverts these tests.**
5. **The lift does a second full read.** `FrontmostAppWindows.read()` resets `listed`, so lift raises can only name windows in the second read. Raises while sliding use the begin read's `listed`.
6. **Today the list order equals the z-order at begin.** After a lift on another window, the next window swipe lists that window first (`WindowSwitchingTests.liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere`, :64-79, which expects `["News", "Docs", "Mail"]` and `selected == 0`). Design (b), a stable order with the selection starting on the front window's row, changes this test and the `WindowSwitcherOnScreenTests` begin test (`selected == 0`, :31).
7. **The selection always starts at row 0.** That is hard-coded by `SwitcherSelection.init` (travel 0) and by `WindowSwitcher.init`. There is no API to start elsewhere: `travelMM` is `package(set)` and `reportedMM` is private, so a start index would need a new initializer. `count` is clamped to at least 1, so a "no other windows" card with 0 or 1 rows would still get a valid one-item selection that rubber-bands.
8. **The haptic logic assumes "front window == the first visible row".** `frontWindow` comes from `WindowList.front`. With a stable order, the front window is no longer the first row, so `frontWindow` must be stored or derived differently. `lift(now:)` builds `visibleAtBegin` from the **row order** (front window first) to restore the begin z-order, so a reordered list would change which z-order "lifting on the front window" restores, unless the begin z-order is kept separately from the display order.
9. **The 10-row cap prefers visible windows and fills with minimised ones.** Off-Space windows are not in the read at all (dropped in `FrontmostAppWindows.sort`), so "off-Space windows keep their place" has no data to work from today. The model sees an off-Space window exactly as a closed one: absent.
10. **The lift's app-identity check is by `url`** (`WindowLift.swift:52`). `AppEntry` carries no pid, so "the same app still running" cannot be told from "quit and relaunched" in the core. Window numbers are fresh for a relaunched app's windows, so stale ids from a stored order would simply be absent from the next read.
11. **No state persists across window swipes in the model** except `windowSwipesBegun` (`@ObservationIgnored`, `Launcher.swift:70`), a serial used by the presenter. `shown` is cleared on lift, on cancel and on every `reconcile` that re-runs (`:277`). The adapter keeps only the latest read's `listed`/`isUnanswering`. `SwapSeries` (`:252`) is the existing example of the model remembering something across events ("the last swap"), replaced when the next series starts.
12. **`WindowSwitcher.rows` is a computed property**, rebuilt on each access, and `selectedVisibleWindow` and `previewWindows` call it. Cheap at 10 rows, but it means nothing about rows is stored.
13. **`raiseWindows([])` is always called on the lift**, even when there is nothing to raise. The tests count it (`liftingOnTheFrontWindowRaisesNothingAndIsSilent` expects `raised.count == 1` with an empty entry; `HideBackgroundAppsTests.swift:285` expects `[[Mail],[Docs],[]]`). Design (c)'s "lifting is silent and changes nothing" for the card should decide whether that empty call stays.
14. **`hideOtherApps` on the window lift is gated by `lift.playsHaptic`**, not by "a window changed".
15. **The `.moved` raise happens only when `crossed > 0`.** A frame inside the rubber band raises nothing.

## Open Questions
- How AX `kAXWindowsAttribute` treats windows on other Spaces varies by app. The code comment and the platform test assume they may appear as standard windows that are not on screen, and drops them. I did not verify what real apps return. Whether off-Space windows can be told from closed ones (for design (b)) needs a probe.
- Where per-app window counts for the stacks should be read (design (a)). `FrontmostAppWindows` is `@MainActor` and reads only the frontmost app. Running AX reads for many apps off the main actor with a per-app 0.2 s deadline would be new. The process-wide messaging timeout is already 0.2 s, and `AXUIElementSetMessagingTimeout` can be set per app element (as `LaunchWatch.swift:100` does). Whether AX calls are safe from a `@concurrent` context in this codebase's patterns is not established by any existing code; the only off-main window work today is the `CGWindowList` warm-up.
- I did not read `WindowSwipeAnswerTests.swift`, `WindowSwipeRecognizerTests.swift` or `WindowSwipeBlockingTests.swift` line by line, only their test lists. They test the recognizer and the confirmation and should be unaffected unless the recognizer's confirmation semantics change.
- I did not trace `RunningAppsReader.read()` or `RunningApp.entry(for:)` in depth. That `AppEntry.url` is the bundle location (via `AppEntry.location(ofBundleAtPath:)`) comes from the doc comments in `Apps.swift:25-29` and `RunningApp.swift:4-16`.
