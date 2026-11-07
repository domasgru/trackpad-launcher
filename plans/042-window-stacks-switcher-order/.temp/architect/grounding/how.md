# How the app switcher, the window swipe and the window switcher work (grounding for plan 042)

Paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order/`, and line numbers
are as of commit `2a4df98`. Abbreviations used below: `Core` = `LauncherKit/Sources/LauncherCore`, `Platform` =
`LauncherKit/Sources/LauncherPlatform`, `UI` = `LauncherKit/Sources/LauncherUI`, `CoreTests` =
`LauncherKit/Tests/LauncherCoreTests`.

This document merges four explorer reports: the switcher row, the window-swipe model, the platform window read, and the
window-switcher UI. I re-read the load-bearing code myself: `Launcher.swipe`/`windowSwipe`, `Switcher`,
`SwitcherSelection`, `WindowSwitcher` with `Content.init?`, `WindowLift.lift(now:)`, `WindowSwipeConfirmation`, both
presenters' `render`, and `SwitcherPanel.show`. The four reports do not contradict each other. Where they leave a gap,
the gap is listed in "Open questions".

---

## Overview

Both switchers are driven by one gesture: the thumb rests and two fingers slide.

- **A sideways slide is a swipe.** It shows the app switcher, a horizontal row of up to 10 app icons. The frontmost app
  comes first, then the other running apps in ⌘-Tab order. Lifting brings the selected app forward.
- **An up/down slide may be a window swipe.** It shows the window switcher, a vertical column of 2 to 10 of the
  frontmost app's windows. Each row has a preview and a title. Sliding raises each visible row's window as it is
  selected. Lifting settles the z-order.

The two switchers share a three-layer architecture:

- `LauncherCore` holds every rule as pure, testable value types: which items are listed, selection math, lift ordering,
  haptics and layout geometry.
- `LauncherPlatform` holds the real adapters: multitouch frames, haptics, LaunchServices, and the Accessibility (AX)
  window read and raise.
- `LauncherUI` holds two presenter/panel pairs. They observe the model and render with AppKit and plain Core Animation
  layers. No SwiftUI is involved.

`Launcher` (`Core/Launcher.swift`) is the `@MainActor @Observable` model. It holds a single
`private var shown: ShownSwitcher?` (`.apps(Switcher)` or `.windows(WindowSwitcher)`), so at most one switcher of either
kind exists at a time. It exposes two computed views over that slot, `switcher` and `windowSwitcher`. Each presenter
observes one of them.

Everything about one swipe is decided when the swipe begins and is fixed for its life: the row, the window list, and the
fact that the slide is a window swipe at all. Nothing survives to the next swipe except a window-swipe serial number.

Plan 042 changes three things, and each one hits an assumption that is baked in today:

- **(a) Window stacks need per-app window counts that arrive asynchronously.** Today the app switcher's model and
  presenter assume the row is the whole state and is final at begin.
- **(b) A stable per-app window order** needs memory across window swipes, and a selection that does not start at
  row 0. Today there is no cross-swipe memory, and "row 0 is the front window" is assumed in three places.
- **(c) A window swipe with 0 or 1 windows** inverts the "two or more rows, else decline" rule. That rule currently does
  quiet double duty: it is how the own-process, timeout and no-permission cases are filtered out.

---

## Key concepts

| Concept | Where | What it is |
|---|---|---|
| `SlideKind { swipe, windowSwipe }` | `Core/Gesture.swift:26-31` | Decided once by the recognizer: horizontal → `.swipe`, vertical → `.windowSwipe`, a tie → neither. |
| `SwipeEvent` / `SwipePhase` | `Core/Gesture.swift:34-56` | `.began`, `.moved(travelMM:)` (absolute travel, sent only when it changes), `.ended`, `.cancelled`, plus `trackpad`. Delivered as `TrackpadEvent.swipe(_)` or `.windowSwipe(_)`. |
| `WindowSwipeConfirmation` | `Core/WindowSwipeConfirmation.swift` | The synchronous yes/no answer to "is this up/down slide a window swipe?". It is true only if `confirmWindowSwipe(on:)` was called while `onEvent` handled the `.began`. |
| `Switcher` | `Core/Switcher.swift` | The app switcher for one swipe: a fixed `row: [AppEntry]`, a private `startsOnFrontmost`, a mutable `selection` and `trackpad`. There is **no serial**. |
| `WindowSwitcher` | `Core/WindowSwitcher.swift:38-136` | The window switcher for one window swipe: a fixed `content` (app plus `WindowList`), `selection`, `serial`, `trackpad`, `showsPreviews`. `rows`, `frontWindow` and `selectedVisibleWindow` are computed. |
| `WindowSwitcher.Content.init?(_ read:)` | `Core/WindowSwitcher.swift:145-165` | **The one parse that decides whether a slide is a window swipe.** It returns nil for `.noApp`, for a full-screen front window, and for fewer than 2 rows. It also applies the 10-row cap. |
| `SwitcherSelection` | `Core/SwitcherSelection.swift` | Selection math shared by both switchers. Travel is measured in "step mm", 12 per item. It provides `selected` (rounded and clamped), `position` (fractional), and `stretch` (a rubber band of at most 0.2 items). `follow(_:)` returns the number of items crossed, and one light tick plays per item. The selection always starts at item 0. |
| `FrontmostWindows` | `Core/WindowSwitcher.swift:26-34` | The read result: `.noApp`, or `.app(AppEntry, visible: [AppWindow], minimised: [AppWindow])`. It has **no case for "did not answer"**. |
| `WindowID` | `Core/WindowSwitcher.swift:5-9` | The CGWindowID. It is the same number from AX, from CGWindowList and from ScreenCaptureKit, and it is the only window identity that crosses the port. |
| `WindowLift` / `WindowStack.raises` | `Core/WindowLift.swift` | A pure computation of the raises and the haptic for a lift, made from the begin rows and a second read. |
| `SystemActions` (port) | `Core/Ports.swift:61-139` | Its members include `runningApps()`, `frontmostWindows()`, `raiseWindows(_:)`, `bringToFront`, `hideOtherApps`. All are `@MainActor` and synchronous. The only push is `onLaunchProgress`. |
| `TrackpadHardware` (port) | `Core/Ports.swift:26-50` | `onEvent`, `run(..., slides:)`, `playFeedback(.gesture \| .lightTick, on:)`, `confirmWindowSwipe(on:)`. |
| `FrontmostAppWindows` | `Platform/FrontmostAppWindows.swift` | The real window read and raise. It is `@MainActor`, it reads **only the frontmost app**, and it keeps `listed: [WindowID: AXUIElement]` from the latest read as the raise handles. |
| `OverlayPanel` | `UI/OverlayPanel.swift` | The shared `NSPanel` base for both switchers: Liquid Glass content under a rounded `masksToBounds` clip, `present(appear:)`, a 150 ms `dismiss()` fade and the `emptied()` hook. |
| `SwitcherRowLayout` / `WindowColumnLayout` | `Core/` | Pure geometry for the row and the column. The panels only read numbers from them. |

---

## How it works

### 1. End-to-end picture

```mermaid
sequenceDiagram
    participant FT as Frame thread<br/>(GestureRecognizer in DeviceSession)
    participant MQ as Main queue<br/>(MultitouchTrackpads.deliver)
    participant L as Launcher (model)
    participant SA as SystemActions<br/>(WorkspaceActions)
    participant HW as TrackpadHardware (haptics)
    participant P as Presenter (UI)
    participant PN as Panel (AppKit + CA)

    FT->>MQ: .slide(kind, .began)
    MQ->>L: onEvent(.swipe / .windowSwipe(.began))
    alt swipe
        L->>SA: runningApps() (sync)
        L->>L: shown = .apps(Switcher?)  (nil = nothing to switch to)
    else window swipe
        L->>SA: frontmostWindows() (sync AX read)
        L->>L: Content.init?  → nil: return without confirming
        L->>HW: confirmWindowSwipe(on:)
        L->>L: shown = .windows(WindowSwitcher(serial+1))
        MQ-->>FT: reply(answer) via Mutex, applied before next frame
    end
    L-->>P: Observations fires
    P->>PN: open: layout, present
    loop each changed travel
        FT->>MQ: .moved(travelMM)
        MQ->>L: selection.follow(travel) → crossed
        L->>HW: lightTick × crossed
        L->>SA: (window swipe only) raiseWindows([selected visible])
        L-->>P: Observations fires
        P->>PN: show(position, selected), maybe springHighlight
    end
    FT->>MQ: .ended
    MQ->>L: shown = nil; decide lift
    L->>SA: runningApps() / frontmostWindows() (second read)
    L->>HW: .gesture (if it changes something)
    L->>SA: bringToFront + hideOtherApps / raiseWindows(lift.raises)
    L-->>P: render(nil) → panel.dismiss() (150 ms fade)
```

### 2. Recognition and the window-swipe "question"

The recognizer (`Core/GestureRecognizer.swift`) runs per trackpad on the frame thread. When the thumb is anchored and
exactly two fingers rest, it watches the finger that has moved farthest. Once that finger is past 3 mm,
`beginOrSpoil` (`:317-326`) picks the kind. The rule is `abs(dx) > abs(dy)` for a swipe and the reverse for a window
swipe. If the kind is not in the session's `slides` set, the slide is spoiled.

**A swipe starts confirmed; a window swipe starts unconfirmed** (`:324`). An unconfirmed window swipe blocks only by the
thumb rules until it receives an answer.

`slides` is the hook for the setting and the permission. `Launcher.reconcile()` passes
`granted ? settings.slides : settings.slides.subtracting([.windowSwipe])` (`Launcher.swift:273`). With the window-swipe
setting off, or without Accessibility, the recognizer never emits a window swipe at all. In that case there is no read
and no answer. The model's `.began` handler never checks the setting or the permission itself.

Delivery to the main actor works like this:

1. `DeviceSession.receive` (`Platform/FrameStream.swift:57-84`) attaches a `reply` closure to a `.windowSwipe(.began)`.
2. `MultitouchTrackpads.deliver` (`Platform/MultitouchTrackpads.swift:98-108`) hops every event onto
   `DispatchQueue.main.async`. It drops events from a replaced session.
3. On the main actor it runs `WindowSwipeConfirmation.deliver(_:to:)`. For a window-swipe start, this sets
   `startBeingHandled = (trackpad, false)` and calls `Launcher`'s `onEvent` synchronously. It then returns whether
   `confirm(on:)` was called during that call.
4. The reply writes the answer into a `Mutex`.
5. On the next frame, the session calls `recognizer.answerWindowSwipe(began:isWindowSwipe:)` before stepping:
   - `true` confirms the slide, which then blocks clicks and scrolling.
   - `false` turns the slide into `.spoiled`. That is exactly what the setting-off slide would have done.

The frame thread never waits. However, **the answer must be known before `onEvent` returns**. That is why the window read
at begin is synchronous on the main actor today.

The test adapter `InMemoryTrackpads.touch` (`CoreTests/InMemoryAdapters.swift:114-135`) models the same steps
synchronously. It records each answer in `windowSwipeAnswers` and applies it before the next frame.

### 3. The app swipe in the model (`Launcher.swipe`, `Core/Launcher.swift:339-369`)

**Began.** The handler runs `guard shown == nil, activity.isActive`, then one synchronous `system.runningApps()`. That
call goes through `RunningAppsReader.read()`, which uses the LaunchServices ⌘-Tab order or a fallback, plus
`NSWorkspace.frontmostApplication`. The handler then calls `Switcher.init?`:

- The frontmost copy is dropped from the others **by URL**. Assigned apps are dropped **by bundle ID**. The frontmost app
  is never excluded.
- The init returns nil if there is nothing besides the frontmost app. The swipe then runs its course with no switcher, and
  the fingers stay blocked until lift.
- `row = [frontmost] + others`, capped at `GestureRules.switcherMaxApps` (10). `selection` starts at 0, which is the
  frontmost icon.

**Moved.** The handler copies the `Switcher` value, calls `selection.follow(travel)`, writes `shown = .apps(open)` back,
and plays one `.lightTick` per item crossed. Every move is therefore one `@Observable` mutation.

**Ended.** The handler sets `shown = nil` first. Then:

- If the selection is on the frontmost app (`selectsFrontmost`), the lift is silent and does nothing.
- Otherwise it re-reads `runningApps()`. If the target quit, the lift is silent.
- Otherwise it plays `.gesture`, then `bringToFront`, then `hideOtherApps(than:)`. The hide is a no-op unless *Hide
  background apps* is on.

**Cancelled.** The handler sets `shown = nil`. `reconcile()` also sets `shown = nil` whenever it re-runs the trackpads
(`:276-277`).

The model never sees pids. `LaunchServicesOrder` asks for the `"pid"` key (`Platform/LaunchServicesOrder.swift:20`) but
`entries` drops it (`:46-55`). `AppEntry` holds only `bundleID`, `name` and `url`, and its `id` is the bundle ID.

### 4. The window swipe in the model (`Launcher.windowSwipe`, `Core/Launcher.swift:372-408`)

**Began** (verified):

```swift
guard activity.isActive, let content = WindowSwitcher.Content(system.frontmostWindows()) else { return }
hardware.confirmWindowSwipe(on: event.trackpad)
guard shown == nil else { return }
windowSwipesBegun += 1
shown = .windows(WindowSwitcher(content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun, trackpad: event.trackpad))
```

Three points matter here:

- **A decline is "return without confirming".** The slide then behaves exactly as with the setting off. The test
  `CoreTests/WindowSwipeNeedsTwoWindowsTests.swift:119-151` pins this by comparing the whole outcome against a
  setting-off world across four fronts and four hands.
- **The confirmation comes before the `shown == nil` check.** A second trackpad's window swipe is therefore confirmed and
  blocks input, but shows nothing. Its read still happens.
- **`Content.init?` folds several cases into one "nil".** The own process, a timed-out app, no permission and "really no
  windows" all arrive as `.app(entry, [], [])` and fail the `count >= 2` guard.

`Content.init?` builds the list as follows:

- With a visible window, `visible.first` is the front window, and a full-screen front window gives nil. The other visible
  windows, without full-screen ones, follow, then the minimised windows fill the remaining slots up to 10.
- With no visible window, the result is `.minimisedOnly`.
- The result must have at least 2 rows.

`WindowSwitcher.init` always starts `selection` at row 0. `rows` is recomputed on every access: visible windows first,
then minimised. A title of `""` becomes `"<App> — Window N"`, and any other title goes through `WindowTitleRule`.

**Moved.** The handler calls `follow`, writes `shown` back and plays the ticks. If `crossed > 0` and the selected row is
visible, it calls `system.raiseWindows([thatWindow])`. Minimised rows are never raised while sliding, because raising
would restore them. These raises go through the adapter's `listed`, which comes from the begin read.

**Ended** (verified):

```swift
shown = nil
let lift = open.lift(now: system.frontmostWindows())     // second AX read; replaces `listed`
if lift.playsHaptic { hardware.playFeedback(.gesture, on: event.trackpad) }
system.raiseWindows(lift.raises)                          // always called, possibly []
if lift.playsHaptic { hideOtherApps(than: open.app.bundleID) }
```

`WindowSwitcher.lift(now:)` (`Core/WindowLift.swift:51-65`) is pure:

- If the second read shows another app (matched by `url`) or no app, the lift raises nothing and is silent.
- If the selected window closed, nothing is reordered. The haptic plays only if the window now in front differs from
  `frontWindow`.
- Otherwise the target order is the selected window, then the begin-time visible rows in row order, minus closed windows.
  The raises are `WindowStack.raises(current: onScreen, target:)`, the shortest front part of the target that must be
  raised. The haptic plays when `selected != frontWindow`.
  - Lifting on the front window therefore silently restores the begin z-order.
  - A minimised selected window is restored, because it is the first target and not on screen.
  - When every window is minimised, `frontWindow == nil`, so every row plays the haptic.

**Cancelled.** The handler sets `shown = nil` and does nothing else: no read, no raise, no haptic. The window raised while
sliding stays in front.

### 5. The Accessibility window read (`Platform/FrontmostAppWindows.swift`)

`WorkspaceActions` owns a single `FrontmostAppWindows`. Its `init` runs once per process and does three things:

- It sets the AX messaging timeout to **0.2 s on the system-wide element** (`:34`), which makes it the default for every
  AX element in the process.
- It resolves the private `_AXUIElementGetWindow` through `dlsym`.
- It warms `CGWindowListCopyWindowInfo` off main in a `@concurrent` static, because the cold call costs about 50 ms.

`read()` (`:45-90`) is synchronous and runs on the main actor:

1. It resets `listed` and `isUnanswering`.
2. It takes `NSWorkspace.shared.frontmostApplication`. If there is none, it returns `.noApp`.
3. **If the frontmost app is this process, it returns `.app(ownEntry, [], [])`.**
4. It reads `kAXWindowsAttribute`. On error it returns empty lists, and `.cannotComplete` sets `isUnanswering`.
5. For each element it makes one `AXUIElementCopyMultipleAttributeValues` call for role, subrole, title, minimised,
   `AXFullScreen`, position and size. A `.cannotComplete` breaks the loop and **keeps the partial list**.
6. It gets each window number from `_AXUIElementGetWindow`. If that fails, it matches frame and title against an
   `.optionAll` CG list.
7. It calls `sort(raw, onScreen:)` (`:152-167`, `nonisolated static`, pure):
   - **Visible** means an `AXWindow` with subrole `AXStandardWindow`, not minimised, and present in the
     `.optionOnScreenOnly` CG list. Visible windows are ordered front to back by that list.
   - **Minimised** means `AXMinimized == true` alone, in AX order, with no role or Space test.
   - A standard window that is neither on screen nor minimised is on another Space and **is dropped**.
8. It rebuilds `listed` for the kept windows.

`raise(_:)` (`:94-100`) runs `kAXRaiseAction` from the last window to the first. It only names ids in `listed`, which is
how "nothing on another Space is ever raised" holds. It stops for good after a `.cannotComplete` until the next read. It
returns nothing, so the model learns outcomes only by reading again.

**Timing.** Each AX call is bounded by 0.2 s, but a whole read is not. An app that stops answering costs about one
timeout. A slow app that answers each call just under 0.2 s can cost (1+N) × 0.2 s. No end-to-end latency has ever been
measured. The "about a millisecond" figure comes from TextEdit component probes in plan 012.

### 6. Haptics

Haptics are decided only in `Launcher` and never in the views. `MultitouchTrackpads.playFeedback` calls
`actuatorActuate` with strength 6 for `.gesture` and 3 for `.lightTick` (`Platform/MultitouchTrackpads.swift:121-135`).

| Moment | App swipe | Window swipe |
|---|---|---|
| Each item crossed | `.lightTick` | `.lightTick`, plus a raise when the new row is visible |
| Lift | `.gesture`, unless the selection is on the frontmost app or the target quit | `.gesture` iff `lift.playsHaptic`; the hide is gated on the same flag |
| Cancel, decline, nothing to show | silent | silent |

### 7. App switcher rendering (`UI/SwitcherPresenter.swift`, `UI/SwitcherPanel.swift`)

`SettingsShell` creates both presenters once (`UI/SettingsShell.swift:67-68`), and each presenter creates its panel up
front so that the first swipe pays no window cost.

`SwitcherPresenter.init` starts two `Observations` loops. One watches `launcher.switcher` and calls `render`. The other
watches `launcher.isSwipeOn` and starts or stops the icon passes.

`render(_:)` (`:114-127`, verified):

- For `nil` it calls `panel.dismiss()`.
- **It re-lays out when `!panel.isPresented || switcher.row != laidOutRow`.** That condition is the only "new swipe"
  signal, because `Switcher` has no serial.
- It then always calls `panel.show(position:selected:animatesSize: !reduceMotion)`.
- It calls `springHighlight` when `stretch` changed and is non-zero.

`open(row)` does the layout:

1. It picks the screen under the pointer and builds `SwitcherRowLayout(iconCount:displayWidth:)`.
2. It calls `panel.layoutRow(row.map { icons.icon(forSwitcher: $0) }, …)`.
3. It calls `present(appear: nil)`. The app switcher has no appear animation.

`SwitcherPanel` is an `OverlayPanel` with corner radius 34. It contains a `.clear` `NSGlassEffectView` highlight with
radius 24, and above it an `iconsHost` view whose layer holds one plain `CALayer` per icon.

- **`layoutRow`** sizes and centres the panel on the screen's full `frame`. With actions disabled, it **removes every icon
  layer and builds fresh ones**. Each layer has `bounds` equal to the icon side, sits at
  `(centreX(at: i), centreY)`, holds the icon's `CGImage` as `contents` with `.trilinear` minification, and uses the
  default centre anchor.
- **`show`** moves the highlight's x with actions disabled. Then, in a second transaction with
  `setDisableActions(!animatesSize)` and `setAnimationDuration(0.12)`, it sets **every** icon layer's `transform` to a
  scale of 1.12 (selected) or 1. This is the selected-icon "grow": an *implicit* 0.12 s action, re-issued on every render
  for every layer.
- **`springHighlight(from:)`** adds an additive `CASpringAnimation` on `position.x`, keyed `"stretch"` so each new spring
  replaces the previous one. Stiffness 420 and damping 22 are literals.

Geometry at full size comes from `Core/SwitcherRowLayout.swift`:

| Quantity | Value |
|---|---|
| Icon | 80 pt |
| Gap | 20 pt |
| Pitch | 100 pt |
| Highlight | 92 pt |
| Padding | 22 pt, not scaled |
| Selected-icon scale | 1.12 |
| Panel height | 2×22 + 92 = **136 pt** |
| Icon centre y | 68 |
| Icon top | 108 |
| Selected-icon top | 112.8 |
| Highlight top | 114 |

On a narrow display, `scale = min(1, (displayWidth − 44) / fullSpan)` shrinks everything except the padding. The content
is clipped by `roundedClip` (`UI/GlassClip.swift:6-21`, `masksToBounds`). The `iconsHost` coordinate space is not
flipped, so "up" is +y.

`AppIcons` (`UI/AppIcons.swift`) caches 80 pt bitmaps by URL. Passes fill it while the swipe setting is on: at start, on
app launch, on termination (evict), and on an appearance change. `icon(forSwitcher:)` falls back to the running app's
already-loaded icon, and then to a synchronous render. The view receives icons only as `[NSImage]` at `layoutRow`.

### 8. Window switcher rendering (`UI/WindowSwitcherPresenter.swift`, `UI/WindowSwitcherPanel.swift`)

`render(_:)` (`:38-54`) works like this:

- For `nil` it cancels the preview capture, clears `shownSerial` and calls `panel.dismiss()`.
- **It lays out once per window swipe, when `switcher.serial != shownSerial`.**
- Every render then calls `panel.show(position:selected:)` and uses the same stretch rule as the app switcher.

`open(_:)` (`:59-78`) runs these steps:

1. It picks the screen under the pointer and builds `WindowColumnLayout(rowCount:displayHeight: visibleFrame.height)`.
2. It **starts the ScreenCaptureKit capture first**.
3. It calls `panel.lay(out: rows, icon:, layout:, topLeft:)`, anchored at the `visibleFrame`'s top-left plus a 12 pt
   margin.
4. It calls `awaitPreviews`.
5. It calls `present(appear: OverlayAppear(0.1 s fade, from scale 0.96 about the top-left, spring 420/22))`, or `nil`
   under Reduce motion.

`WindowSwitcherPanel` pre-creates 10 `WindowRowView`s. Each row has a preview slot (an icon `NSImageView` plus a
`CALayer` for the picture), a one-line 13 pt medium title, and a "Minimised" pill. Minimised rows are drawn at alpha
0.55.

The highlight and the rows are placed through one function, `rowFrame(at:)`:

- `show` sets the highlight to `rowFrame(at: position)` with actions disabled and recolours the selected row's title.
- `springHighlight(fromY:)` is the additive spring on `position.y`, with constants from `WindowSwitcherLook`.

Geometry comes from `Core/WindowColumnLayout.swift`: a row is 72 pt tall, the pitch is 74 pt, the panel is 360 pt wide,
the title column is 200 pt wide starting at x = 138, and a one-row panel is 88 pt tall.

Previews arrive asynchronously:

1. `PreviewCapture.pictures(of:fitting:)` returns an `AsyncStream<(WindowID, CGImage)>` produced off main.
2. The presenter's `Task` checks `shownSerial == serial` for each picture and calls
   `panel.setPreview(_:row:animated:)`. That is an implicit 0.08 s opacity fade on the preview layer.
3. When the stream ends, the presenter shows icons in empty slots.
4. `emptied()` drops all pictures after the dismiss fade.

**This is the existing precedent for per-slot data that arrives after the panel is up.** The async work lives entirely
in `LauncherUI` and is guarded by the serial. It never touches the model.

### 9. Shared overlay, animation rules and Reduce motion

`OverlayPanel` (`UI/OverlayPanel.swift`) is borderless, non-activating and click-through, sits at screen-saver level, and
appears on every Space. Its content is a `.regular` `NSGlassEffectView` inside `roundedClip`.

- `present(appear:)` bumps a `generation` counter, removes in-flight fade and appear animations and calls
  `orderFrontRegardless()`.
- `dismiss()` is a no-op unless the panel is presented. It then sets `isPresented = false` and runs a 150 ms opacity fade.
  Its completion block calls `orderOut` and `emptied()` only if `generation` is unchanged. This is the only
  completion-callback cleanup in the switcher code.

The architecture rules (`docs/architecture.md` lines 20-21, enforced by `CoreTests/SourcePolicyTests.swift`):

- **No timers.** `Timer`, `asyncAfter`, `Task.sleep`, display links and `DispatchSourceTimer` are banned. "Time passes
  only on Core Animation's clock". A deadline is a CA animation whose completion is the push (`Platform/LaunchClock.swift`
  is the precedent).
- **Animation is Core Animation**, played by the render server. Leftovers are cleaned up from completion callbacks.
- **Per-input-event code is allowed only while its effect is on screen.** The switcher highlights on trackpad frames are
  the named example.
- **`AXUIElement` and `CGWindowList` may only appear in `FrontmostAppWindows.swift` and `LaunchWatch.swift`.** The scan
  is a line-substring match that includes comments.

Reduce motion is read live and is never injected into the switchers:

- The app switcher drops the grow animation (the scale still changes, at once) and the spring.
- The window switcher drops the appear animation, the spring and the preview fade.
- `dismiss` removes the panel at once.

The four explorers found no tests for any presenter or panel. `LauncherUITests` has bench precedents (`PickerBench`,
`GearBench`) that inspect `CALayer` animations and inject `reduceMotion`.

---

## What the 042 design runs into

### (a) Window stacks on the switcher row

**No per-app window reader exists.**

- `FrontmostAppWindows.read()` takes no argument and always reads the frontmost app.
- It is `@MainActor`.
- Calling it overwrites `listed` and `isUnanswering`. A stacks read routed through it would therefore replace the window
  switcher's raise handles.

A count reader needs these pieces:

- **Pids.** `LaunchServicesOrder` already fetches them and drops them. Otherwise the reader must map `AppEntry.url` back
  to `NSRunningApplication`, the way `AppIcons.icon(forSwitcher:)` does with bundle ID plus `bundleURL`.
- **A home.** It must live in one of the two confined files, or the `Confined` lists must be extended
  (`SourcePolicyTests.swift:172-173`). The Privacy sentence in `docs/architecture.md` would change too.
- **Reuse of the pure `sort`.** That way "counts exactly as the window switcher lists" (R2) holds by construction. Note
  two caveats: the full-screen rule is applied later, in `Content.init?`, and hidden apps were never probed. A hidden
  app's windows are probably absent from the on-screen list, so it would count only its minimised windows.

**There is no precedent for AX calls off the main thread.** The header says nothing about threads.

- `AXUIElement` is not `Sendable`. A counts-only result (`Int` or `[WindowID]`) avoids that problem.
- `nonisolated(unsafe)` is banned.
- Blocking AX calls in a cooperative-pool `TaskGroup` hold a pool thread for up to 0.2 s each. Several hung apps could
  starve the pool and delay other apps' counts, which runs against R4.

**A per-app 0.2 s deadline cannot be a timer.** Three options fit the codebase rules:

- The per-call messaging timeout, settable per element. This does not bound a slow app's whole read.
- A `LaunchClock`-style CA deadline that discards late results.
- `Uptime.now` checks between calls.

**The port is synchronous.** Async results reaching the model would need a new push on `SystemActions`, modelled on
`onLaunchProgress` and `AppScanner.onScan`, with an in-memory twin in `RecordingSystemActions`. The alternative is to keep
counts entirely in `LauncherUI`, as previews are kept. `FakeWindows` models one window stack shared by "whichever app is
frontmost", so per-app and slow-app scenarios need a fake extension either way.

**Presenter re-layout trap.** `render` re-lays out whenever `switcher.row != laidOutRow`, and `layoutRow` destroys every
icon layer. If counts are stored inside `row`'s element type, or anywhere compared by that check, a late count rebuilds
the row, replays the rise and calls `present` again.

- Counts must sit beside `row`, and the re-layout key must stay `row`, or better a new per-swipe serial.
- Every write to `shown` re-runs the whole `render`, so the per-arrival cost is a full `show()`. That is cheap but
  untargeted.

**There is no per-swipe identity for the rise.** The app presenter detects a new swipe only through `!panel.isPresented`.
That works today because every swipe ends with `shown = nil`, then `render(nil)`, then `dismiss()`. If `Observations`
ever coalesces `nil` followed by a new value, a same-row back-to-back swipe would not re-open, and a rise placed in
`open` would not play. A serial on `Switcher` (as on `WindowSwitcher`) removes this doubt.

**Layer structure for copies.** `show` sets `transform` on every layer in `iconLayers` by index, every render, as an
implicit 0.12 s action. Sublayers always draw *above* their parent's `contents`. Copies that peek from behind the icon and
grow with it therefore need a per-app container layer:

- The container holds the copies first and the front icon last.
- The selection transform moves from the icon layer to the container.
- `iconLayers` keeps one entry per row index.
- The rise animates a different key or layer than `transform` (for example the copies' `position`). That keeps the
  per-frame implicit transform action from replacing it.

Copies can reuse the same `CGImage`, since `.trilinear` minification handles the 92/84/76 % sizes.

**Vertical room.** Copies peeking up to 18 pt above an 80 pt icon, grown ×1.12 about the icon centre, reach about
68 + 58 × 1.12 ≈ 133 of the panel's 136 pt. That is inside, but the first and last stacks run into the radius-34 corner
arcs of the `masksToBounds` clip. This was computed on paper only.

**Row identity.** Two running copies of one bundle are two icons. `AppEntry.id` is the bundle ID, so counts keyed by
bundle ID would collide. Key counts by `url` or by row index instead.

**The frontmost app's read is not substituted.** `RunningAppsReader.frontmost` substitutes the previous app when
Trackpad Launcher is active without a Dock icon, but the window read does not substitute anything.

### (b) Stable per-app window order, with the selection starting on the front window

**The model keeps no state across window swipes** except `windowSwipesBegun`. A per-app order is new model state.
`SwapSeries` (`Launcher.swift:252`) is the closest precedent for remembering something across events.

**No app quit or relaunch push reaches the model.** Launch and terminate observers exist only in `SwitcherPresenter` (for
icons), `ActivationTracker`, `BackgroundHider` and `LaunchWatch`. "Forget on quit" therefore needs a new port push, or a
key that changes on relaunch. `AppEntry` has no pid, and a relaunched app keeps its `url`. A relaunched app's windows do
get new `WindowID`s, so stale ids simply vanish from the next read.

**"Row 0 is the front window" is baked in three places:**

- `WindowList.front(front, others:, minimised:)` and `rows`, which list visible windows first.
- `frontWindow`, which is derived from `.front`.
- `lift(now:)`, whose `visibleAtBegin` is taken in **row order** to restore the begin z-order.

With a display order that differs from the z-order, the begin z-order has to be kept separately from the display order.
Otherwise "lift on the front window restores the begin order silently" breaks.

**Starting the selection on row k.** `SwitcherSelection` has no start-index initializer: `travelMM` is `package(set)`
and `reportedMM` is private. Because `follow` works on deltas, setting `travelMM = k × 12` with `reportedMM = 0` is
enough. The view needs no change. `lay` puts the highlight on row 0, but `render` calls `show` in the same pass with
actions disabled, so the highlight lands on row k without animating.

**Off-Space windows are absent from the read**, because `sort` drops them. "An off-Space window keeps its place"
(plan R7) therefore has no data today: such a window looks exactly like a closed one. Raises must still name only ids
from the latest read (probe F24: raising an off-Space window switches Spaces).

**Tests that encode today's order** and will change:

- `CoreTests/WindowSwitchingTests.swift:64-79` expects `["News","Docs","Mail"]` with `selected == 0` after a lift.
- `CoreTests/WindowSwitcherOnScreenTests.swift:14-31` expects `selected == 0`.

### (c) Window swipe with 0 or 1 windows, the "no other windows" card

**The decline is load-bearing, and the design inverts it.**

- `WindowSwipeNeedsTwoWindowsTests` (`:21-51`, `:119-151`) and
  `SettingsWindowAsAppTests.slidingDownOverTheSettingsWindowIsNoWindowSwipe` (`:93-105`) all assert that a slide over 0 or
  1 window is exactly the setting-off slide.
- Today the `count >= 2` guard also, implicitly, rejects the own process, a timed-out app and a missing permission. With
  the permission missing, the recognizer never emits a window swipe anyway.

Plan R13 says there is no card without a known count, so the read has to be richer. `FrontmostWindows` must distinguish
these cases:

- answered with zero windows
- did not answer (the adapter already knows this through `isUnanswering`, but the port drops it, and a mid-loop timeout
  returns a *partial non-empty* list)
- the own process
- no app

Full-screen fronts currently return nil from `Content.init?` as well.

**The confirmation must stay synchronous.** Whatever decides "card or decline" must finish inside `onEvent`, as
`Content.init?` does today.

**No model case can express a card.** `WindowList` and `Row` have no 0- or 1-row case, and `WindowSwitcherPanel.lay`
takes only rows. A card needs:

- a new model case
- a new view, or a row-view mode
- a branch in `lay` and `render`
- a hidden highlight
- no capture

Titles are single-line in a 200 pt column, so "‹App› has no other windows on this desktop." will not fit at 13 pt.

**The selection math already supports one item.** `SwitcherSelection(count: 1)` rubber-bands at both ends, and its
turn-back rule moves at once toward the new direction (R11). Travel is clamped to ±0.25 step (3 step-mm).

**The finger-following offset is not today's rubber band.** Today's stretch saturates at about 0.111 items, which is
about 8.2 pt at the 74 pt pitch and above the 6 pt cap. It is also rendered as a spring that *returns to rest as soon as
the fingers stop*, not as an offset that is held. The card needs:

- A dedicated pure mapping in Core from `travelMM` or `stretch` to points, capped at 6.
- That offset applied per render with actions disabled, as the highlight is.
- A settle-back in `render(nil)`, alongside the 150 ms dismiss fade. Under Reduce motion the panel is removed at once.

One more caveat: with "move like the cursor", a step-mm is not a physical millimetre, so a cap expressed through travel
scales with pointer acceleration.

**A silent lift.** Today `raiseWindows(lift.raises)` is called even when the list is empty. Tests count that empty call:
`liftingOnTheFrontWindowRaisesNothingAndIsSilent` expects `raised.count == 1`, and `HideBackgroundAppsTests.swift:285`
expects `[[Mail],[Docs],[]]`. The card's lift has to decide whether that empty call stays. The second read at lift is
unnecessary for a card. The hide is already gated on `playsHaptic`.

**The light tick needs no special case.** `follow` returns 0 crossings for a one-item list, so no light tick plays.

---

## Where things live

| Area | Files |
|---|---|
| Model and effects | `Core/Launcher.swift` (`swipe` :339-369, `windowSwipe` :372-408, `reconcile` :260-280, `shown` :66-70) |
| App switcher state | `Core/Switcher.swift`, `Core/SwitcherSelection.swift`, `Core/SwitcherRowLayout.swift`, `Core/GestureRules.swift:31-41` |
| Window switcher state | `Core/WindowSwitcher.swift` (types, `rows`, `Content.init?`), `Core/WindowLift.swift`, `Core/WindowColumnLayout.swift`, `Core/WindowTitleRule.swift` |
| Recognition and confirmation | `Core/GestureRecognizer.swift` (`beginOrSpoil` :317, `answerWindowSwipe` :254), `Core/WindowSwipeConfirmation.swift`, `Platform/FrameStream.swift`, `Platform/MultitouchTrackpads.swift` |
| Ports | `Core/Ports.swift` (`TrackpadHardware` :26-50, `SystemActions` :61-139) |
| Window read and raise | `Platform/FrontmostAppWindows.swift`, `Platform/WorkspaceActions.swift`; deadline precedent in `Platform/LaunchClock.swift`; second AX reader in `Platform/LaunchWatch.swift` |
| Running apps | `Platform/RunningAppsReader.swift`, `Platform/LaunchServicesOrder.swift`, `Platform/RunningApp.swift` |
| App switcher UI | `UI/SwitcherPresenter.swift`, `UI/SwitcherPanel.swift`, `UI/AppIcons.swift` |
| Window switcher UI | `UI/WindowSwitcherPresenter.swift`, `UI/WindowSwitcherPanel.swift` (`WindowSwitcherLook`, `WindowRowView`), `UI/PreviewCapture.swift` |
| Shared UI | `UI/OverlayPanel.swift`, `UI/GlassClip.swift`, `UI/Displays.swift`, `UI/SettingsShell.swift:67-68` |
| Tests (model) | `CoreTests/SwitcherTests.swift`, `SwitcherOnScreenTests.swift`, `SwitcherRowLayoutTests.swift`, `WindowSwitchingTests.swift`, `WindowSwitcherOnScreenTests.swift`, `WindowSwipeNeedsTwoWindowsTests.swift`, `WindowColumnLayoutTests.swift`, `HideBackgroundAppsTests.swift`, `SettingsWindowAsAppTests.swift` |
| Test harness | `CoreTests/World.swift` (`windowWorld`, `windowSwipe`, `switcherWorld`), `CoreTests/InMemoryAdapters.swift` (`InMemoryTrackpads`, `RecordingSystemActions`, `FakeWindows` :392-473) |
| Policy | `CoreTests/SourcePolicyTests.swift` (timer bans :52-58, AX/CG confinement :172-173), `docs/architecture.md` (Concurrency, Privacy) |
| Platform tests | `LauncherKit/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift` (pure `sort`), `RunningAppsReaderTests.swift` |
| UI test precedents | `LauncherKit/Tests/LauncherUITests/` (`PickerBench`, `GearBench`, `AppPickerTests`) |

---

## Gotchas

1. **The app presenter's re-layout key is `row` equality.** Anything compared by it that changes mid-swipe destroys every
   icon layer and re-presents the panel.
2. **The app switcher has no serial.** The window switcher has one, and it is the reason the window presenter is immune
   to stale or coalesced deliveries.
3. **The selected-icon grow is an implicit action re-set on every render, for every layer.** Do not put new explicit
   animations on the icon layer's `transform`. `docs/performance.md:78` records that skipping unchanged writes was
   rejected because it would likely change the grow.
4. **The confirmation precedes `shown == nil`.** A second trackpad's window swipe blocks input but shows nothing.
5. **The empty read collapses four cases** (no windows, timeout, no permission, own process). A mid-loop timeout is not
   even empty. It is a partial list.
6. **Each `read()` replaces the raise handles.** The lift's second read means lift raises can name only windows that are
   still present. Any extra read through the same object would clobber the window switcher's handles.
7. **`FakeWindows` is one stack for "whichever app is frontmost".** It does not model the own-process empty read:
   `SettingsWindowAsAppTests` relies on `visible: ["Settings"]` being one window.
8. **The source-policy scan matches comments.** A doc comment that says "Timer" or "AXUIElement" in the wrong file fails
   the build's tests.
9. **Two placements.** The app switcher is centred on the full `frame` and shrinks by width. The window switcher sits at
   the top-left of `visibleFrame` and shrinks by height.
10. **Spring constants are duplicated.** They are literals in `SwitcherPanel` and fields of `WindowSwitcherLook`. No
    switcher visual is reachable from the Debug `AnimationTuner`, because `LauncherUI` cannot import `LauncherPlatform`.
    Tuning would need the `SettingsShell` Debug hook pattern used by the pick animation.
11. **Plan 023 is the app *picker*'s pick animation, not the switcher grow.** It is still the precedent for "a pure curve
    in Core, sampled into a `CAKeyframeAnimation` in UI, tested at both levels".

---

## Open questions (none verified by any explorer or by me)

- **`Observations` coalescing.** Can `Observations({ launcher.switcher })` merge `nil` and the next value across two
  quick swipes? If it can, the app presenter would not re-open, and a rise placed in `open` would not play. A per-swipe
  serial makes the question moot.
- **Same-value implicit actions.** Does re-setting an unchanged `transform` add a fresh 0.12 s animation each frame? This
  matters if stack layers share that layer.
- **Off-main AX.** Is it safe to make AX calls from non-main threads, concurrently across pids, while the main thread
  raises? And how do blocking AX calls behave in the cooperative pool versus GCD when several apps hang?
- **Cost and timeout behaviour of `_AXUIElementGetWindow`.** Is it an IPC round-trip? Also, a slow app under the 0.2 s
  timeout: does it surface as `.cannotComplete` or as per-attribute error values?
- **Real read latency.** No end-to-end latency has been measured for apps other than TextEdit components (Safari,
  Chromium/Electron, Finder, Xcode).
- **What AX and CG report for hidden apps and for background apps' other-Space and minimised windows.** This matters for
  R2's counts, especially with *Hide background apps* on and when the frontmost app is full screen.
- **Window-number reuse after a window closes,** and stability across tab tear-off and merge, full-screen re-creation, or
  window reloads. This matters for R7.
- **The clip margin for peeking copies** in the radius-34 corners. It was computed on paper only.
