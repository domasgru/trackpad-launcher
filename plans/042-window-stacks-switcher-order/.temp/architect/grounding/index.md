# Grounding index for plan 042 (window stacks, a stable window order, the no-windows card)

Start here. Paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order/`; `G/` is this
grounding directory (`plans/042-window-stacks-switcher-order/.temp/architect/grounding/`).

**What ran.** This is not greenfield. `how` ran over the switcher row, the window swipe model, the platform window read
and the window switcher UI (`G/how.md`, the synthesis, plus the four explorer files `G/how-*.md` it was built from).
`why` ran on the window read, the window-swipe decision, the window order and the switcher row (`G/why.md`, with its
Preserve / Change / Avoid / Risk set, from `G/why-git.md` and `G/why-plans.md`). Probes ran on this machine today
(`G/probes/README.md`: Mac15,6, macOS 27.2, AX-trusted shell; machine left as found). There is no `research/` directory.

Standing: **probed** (a probe's output on this machine today, named), **sourced** (file and heading or lines),
**disputed** (both sides). A conclusion drawn from a probe is marked *Conclusion*.

---

## Q1. Reading window counts for the stacks (R1, R2, R3, R4)

### Where the read lives today
- F1 **sourced** (`G/how-window-read-platform.md` "read()"; `LauncherPlatform/FrontmostAppWindows.swift:45-90`): the only
  window reader for the switchers is `FrontmostAppWindows`, a `@MainActor final class` that reads **only** the frontmost
  app (`NSWorkspace.shared.frontmostApplication`), synchronously, and **replaces its raise handles** (`listed`) and its
  `isUnanswering` flag on every `read()`. A stacks read routed through `read()` would clobber the window switcher's raise
  handles.
- F2 **sourced** (`LauncherCore/Ports.swift:127-138`): `SystemActions.frontmostWindows() -> FrontmostWindows` and
  `raiseWindows(_ frontToBack: [WindowID])` are synchronous `@MainActor` members; no port member reads another app's
  windows or takes a pid, bundle ID or `AppEntry`. The one push on `SystemActions` is `onLaunchProgress`.
- F3 **sourced** (`LauncherCore/Apps.swift:12-51`; `LauncherPlatform/LaunchServicesOrder.swift:20, 46-55`): `AppEntry`
  (`bundleID`, `name`, `url`; `id` is the bundle ID) and `RunningApps` carry no pid. `LaunchServicesOrder` already asks
  for each app's `pid` and drops it. `AppIcons.icon(forSwitcher:)` maps an entry back to a process by bundle ID plus
  `bundleURL == app.url` (`LauncherUI/AppIcons.swift:56-57`). Two running copies of one bundle are two icons in the row,
  so anything keyed by bundle ID collides; key by `url` or by row index (`G/how-switcher-row.md` Non-Obvious 12).
- F4 **sourced** (`LauncherCoreTests/SourcePolicyTests.swift:172-173`, `:52-58`, `:76`): `AXUIElement` and `CGWindowList`
  are confined to `FrontmostAppWindows.swift` and `LaunchWatch.swift` (rule "the window reads have two readers"); the scan
  is a substring match per line, **comments included**. `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`,
  `DispatchSourceTimer`, display links and `nonisolated(unsafe)` are banned everywhere.
- F5 **sourced** (`docs/architecture.md` Concurrency, Privacy): the Accessibility permission's stated uses list "the
  frontmost app's windows when two fingers start sliding up or down"; the Concurrency section says the window read is on
  the main actor; "Work that would delay a click ... runs off the main actor in explicitly concurrent functions"; "Time
  passes only on Core Animation's clock" (`LaunchClock` is the one deadline mechanism, `LauncherPlatform/LaunchClock.swift`);
  async-delivering adapters sit behind a port "so the model's tests stay synchronous". Reading other apps' windows at a
  swipe's start is a new Accessibility use and a new off-main AX path: both sentences change in Phase D.

### What the platform does (probed today)
- F6 **probed** (`probe_real`, sections 2 and 3): AX reads of 14 real apps (Ghostty, Claude, Finder, Spotify, ChatGPT,
  Figma, Chrome, Passwords, Things, Preview, Xcode, Files, System Settings, Todo) made concurrently, one GCD block per app,
  **while the main thread read every app at the same time**, gave results identical to the serial main-thread reads in
  all 280 reads; on a task group (cooperative pool) in all 140. The last app answered within 1.6 to 2.6 ms warm.
  *Conclusion*: off-main, concurrent, per-pid AX reads work on this macOS; no source states it (the header is silent on
  threads, `G/how-window-read-platform.md` Q "Thread safety").
- F7 **probed** (`probe_real` section 1): one app's whole read (kAXWindows + per-window attributes + `_AXUIElementGetWindow`)
  costs **0.2 to 0.9 ms warm**, and **16 to 204 ms cold**, on the first read of that app from the process (Passwords 127 ms,
  Files 151 ms, Xcode 204 ms; most 16 to 26 ms). Sum over 14 apps: 714 ms cold, 5.2 ms warm. One warm CG on-screen copy:
  0.20 ms. *Conclusion*: a 0.2 s per-app budget will drop some apps' stacks on the first swipe after Trackpad Launcher
  (or the app) starts, and catch them on later swipes. In `probe_fixture` (a fresh process) six apps read concurrently
  each took 36 to 50 ms cold, in parallel.
- F8 **probed** (`probe_fixture`, "stopped"): with the process-wide messaging timeout at 0.2 s, a stopped app (SIGSTOP)
  costs **205 ms per call** and every call returns `kAXErrorCannotComplete` (-25204) **as the function's return**, not as
  per-attribute error values; this holds for `kAXWindows`, `AXUIElementCopyMultipleAttributeValues` and
  **`_AXUIElementGetWindow`, which is therefore an IPC call** that can time out. The CG list is unaffected (3 ms).
  While one GCD block was stuck on the stopped app, six other apps' reads on other GCD blocks finished at +37 to +51 ms,
  before the stuck one ended at +205 ms. *Conclusion*: one hung app does not delay the others when each read has its own
  thread. A read of N windows from a slow app can take up to (1 + 2N) x 0.2 s under today's per-call timeout.
- F9 **probed** (`probe_budget`): `AXUIElementSetMessagingTimeout(element, t)` caps the next call on that element at
  about t (0.05 s gave 55 ms, 0.03 s gave 35 ms, on an app element and on a window element, for kAXWindows,
  CopyMultipleAttributeValues and `_AXUIElementGetWindow`); a fresh element for the same pid still uses the process-wide
  0.2 s. *Conclusion*: a whole read can be held to a remaining budget by setting each element's timeout before its call,
  with no timer.
- F10 **probed** (`probe_real` section 1): Preview answered `kAXErrorCannotComplete` to kAXWindows **at once** (0.05 to
  0.08 ms), cold and warm. *Conclusion*: "does not answer" is not always slow; it can be an immediate error.
- F11 **probed** (`probe_fixture`, `probe_hidden`): for a shown app, visible document windows are `AXWindow`/
  `AXStandardWindow`, a floating utility `NSPanel` is `AXFloatingWindow`, a plain titled `NSPanel` is `AXDialog`, a
  minimised window is `AXDialog` with `AXMinimized == true`. Today's sort counts W1, W2 and the minimised W3: 3.
- F12 **probed** (`probe_fixture` "hidden", `probe_hidden`): **while an app is hidden, its document windows report
  `AXDialog`, not `AXStandardWindow`, and leave the CG on-screen list**; AX still lists them, and CG `optionAll` still has
  them. Today's sort would count only the hidden app's minimised windows (1 instead of 3). The standard windows keep their
  minimise, zoom, close and **full-screen** buttons when hidden; the two panels have no full-screen button. After unhiding,
  the subroles return to `AXStandardWindow`. *Conclusion*: with *Hide background apps* on (every other Dock app hidden after
  each action, `docs/domain-model.md` "Hide background apps setting"), today's rule would show no stack for most apps.
  Whether a hidden app's AX list omits its other-Space windows, as the frontmost app's does (F21), is **not probed**.
- F13 **sourced** (`plans/012-window-switcher-gesture/.temp/architect/grounding/index.md` F10, F11, F13, F18): AX lists a
  minimised window with `AXMinimized`; CG on-screen omits minimised and other-Space windows; CG `optionAll` includes them;
  AX does not list some off-screen helper windows that CG and SCK do (`probe_hidden`: Things has five such CG windows and
  no AX window today).
- F14 **sourced** (`LauncherCore/WindowSwitcher.swift:145-165`): the full-screen rule lives in the Core parse, not the
  read: a full-screen front window gives no window swipe today, and other visible full-screen windows are dropped. A
  background app's full-screen windows are on another Space, so not on screen, so not counted (*conclusion* from F13).
- F15 **sourced** (`LauncherPlatform/FrontmostAppWindows.swift:50-52`; commit 7bcb68d): the read never reads Trackpad
  Launcher's own process (an AX call from the main thread into its own main thread would wait out the timeout); it
  returns empty lists for it.
- F16 **sourced** (`G/how-switcher-row.md` Flow 2; `LauncherCore/Launcher.swift:339-369`): the swipe's begin reads
  `runningApps()` once and builds `Switcher(frontmost:running:leavingOut:trackpad:)`; the row is fixed for the swipe; the
  model learns nothing else about the row's apps.
- F17 **sourced** (`G/why.md` Q1, Change 3, Avoid 3, 4, 6): plan 012 rejected an async window read for the window swipe
  (a loading state in model and shell; a lift that lands before the read), rejected AX-observer pushes for counts
  (unreliable for full screen, Spaces, Chromium/Electron), and recorded that the 0.2 s messaging timeout bounds each call,
  not each app. Stacks are display only: a stack count must not decide whether a slide is a window swipe or what a lift does.

## Q2. A stable window order (R7, R8, R9)

- F18 **sourced** (`LauncherCore/WindowSwitcher.swift:5-34`): `WindowID` wraps the window server's `CGWindowID`;
  `AppWindow { id, title, isFullScreen }`; `FrontmostWindows` is `.noApp` or `.app(AppEntry, visible:, minimised:)` with
  visible windows front to back on the current Space and minimised ones in AX order. The read cannot tell "no windows"
  from "did not answer" from "own process" from "no permission", and a mid-loop timeout returns a **partial** list.
- F19 **probed** (`probe_fixture` "churn", "after closing W2"): window numbers are **strictly increasing and never reused**
  across 40 open-and-close cycles; a window opened after another closed gets a higher number (W2=64804 closed, W4=64808).
  **sourced** (012 probes 2 and 5): numbers are stable across minimise and across a move to full screen.
  *Conclusion*: a remembered `WindowID` that is absent from a read is closed, off-Space, or (if the app relaunched) gone for
  good; it can never come back as a different window. Not probed: tab tear-off and merge, apps that rebuild windows.
- F20 **probed** (`probe_fixture`): a newly opened window is first in the AX and CG on-screen orders (it comes to the
  front), so today's list puts it on row 0; R7 puts it at the end of the order.
- F21 **sourced** (012 grounding F10, probe 5, frontmost app only): a window moved to another Space **disappears from
  `kAXWindowsAttribute`**; CG `optionAll` keeps it (F13). `AXRaise` on an other-Space window switches Spaces, so only ids
  from the latest read may ever be raised (`G/why.md` Preserve 1). *Conclusion*: from AX and the on-screen list alone an
  off-Space window looks exactly like a closed one; CG `optionAll` is the one public source that tells them apart.
- F22 **sourced** (`G/how-window-swipe-model.md` Boundaries; `G/how-window-read-platform.md` Boundaries): no app launch,
  quit or activation push reaches the model; observers exist only in adapters and the shell (`SwitcherPresenter` icon
  passes, `ActivationTracker`, `BackgroundHider`, `LaunchWatch`, `QuitSignals`). A relaunched app keeps its `url`, so
  `AppEntry` does not tell a relaunch apart; its windows get new numbers (F19).
- F23 **sourced** (`G/why.md` Q4, Change 1): "no window state in the model between window swipes" (012) and "pull, never
  store" (008 decision 1) are recorded decisions this plan reverses; `SwapSeries` and `WatchedLaunch` are the precedents
  for model memory across events.
- F24 **sourced** (`LauncherCore/WindowSwitcher.swift:83-136`, `LauncherCore/WindowLift.swift:4-65`,
  `G/how-window-swipe-model.md` Non-Obvious 6-8): "row 0 is the front window" is built into `WindowList.front`, `rows`
  (visible first), `frontWindow`, and `lift(now:)`, whose `visibleAtBegin` is taken **in row order** to restore the begin
  z-order (selected, then the front window, then the others as before). `WindowStack.raises(current:target:)` is the pure
  shortest-prefix raise rule (minimised first target restored, other minimised never). The lift re-reads the windows and
  `raiseWindows(lift.raises)` is always called, even with `[]`; tests count that call
  (`WindowSwitchingTests.liftingOnTheFrontWindowRaisesNothingAndIsSilent`, `HideBackgroundAppsTests.swift:285`).
  `hideOtherApps` on a window lift is gated by `lift.playsHaptic` (`Launcher.swift:403`).
- F25 **sourced** (`LauncherCore/SwitcherSelection.swift`): the selection always starts at item 0; there is no start
  initializer (`travelMM` is `package(set)`, `reportedMM` private). Because `follow` works on deltas, a start on item k is
  `travelMM = k x 12` with `reportedMM = 0`. The window presenter calls `show(position:selected:)` in the same pass as the
  layout, with actions off, so the highlight would land on row k without animating (`G/how-window-switcher-ui.md`
  Non-Obvious 4).
- F26 **sourced** (`LauncherCore/WindowSwitcher.swift:145-165`): the 10-row cut takes the front window, then the other
  visible windows front to back, then minimised windows into the remaining slots; R9 keeps that pick and orders the pick by
  the app's window order.

## Q3. The no-windows card (R10, R11, R12, R13)

- F27 **sourced** (`LauncherCore/Launcher.swift:273, 374-386`; `G/how-window-swipe-model.md` Flow 2-3): the setting and
  the Accessibility permission are folded into the recognizer's `slides` at `reconcile`; without either, no window swipe is
  ever emitted and nothing is read. At `.began` the model reads `frontmostWindows()` synchronously and confirms through
  `hardware.confirmWindowSwipe(on:)` **during** the `onEvent` call; returning without confirming declines, and a declined
  slide is exactly the setting-off slide (`G/why.md` Preserve 3). The confirm comes before `guard shown == nil`.
- F28 **sourced** (`G/why.md` Q2, Change 2, 5): plan 012's human first asked for a switcher even with one window, then
  reversed it ("change 1") with no recorded reason; this plan's requirements (R10) reverse it back at the human's request.
  The answer hop stays for the cases R13 still declines (no frontmost app, no answer within 0.2 s), and R10 keeps today's
  declines for the setting off and no Accessibility.
- F29 **sourced** (`docs/domain-model.md` "Frontmost app"; plan 021 decision 8 via `G/why.md` Q1): while its settings window
  is in front Trackpad Launcher is the frontmost app "like any app", and today a slide over it is no window swipe "since the
  settings window is its only window". The read returns empty lists for the own process (F15). R10 makes a one-window app a
  card, and the requirements do not exempt Trackpad Launcher.
- F30 **sourced** (`G/how-window-switcher-ui.md` Non-Obvious 1-3, 18): the window switcher panel holds ten pre-made rows and
  no card; titles are one line in a 200 pt column at 13 pt medium; the highlight always sits at a row frame. Today's rubber
  band is a spring that returns to rest as soon as the fingers stop and peaks at about 8.2 pt, above R11's 6 pt cap.
  `SwitcherSelection(count: 1)` already gives "forget the overshoot the moment the fingers turn" within plus or minus 3
  step-mm, and `follow` returns 0 crossings, so no light tick plays.
- F31 **sourced** (`LauncherCore/PointerCurve.swift:135-156`, `LauncherPlatform/FrameStream.swift:66`): a window swipe's
  travel is `.cursor(curve, pointsPerStep: 100)` in the real session and `.linear` in tests; a step-mm is not a physical
  millimetre, so any cap expressed through travel scales with pointer acceleration.
- F32 **sourced** (`LauncherCore/Launcher.swift:394-406`): the lift clears the switcher, re-reads, plays the gesture haptic
  only when `lift.playsHaptic`, raises, then hides others only when the haptic played; cancel clears it silently.

## Q4. Drawing the stacks (R5, R6)

- F33 **sourced** (`G/how-switcher-row.md` Flow 5-7, Non-Obvious 1-6; `LauncherUI/SwitcherPresenter.swift:112-138`,
  `LauncherUI/SwitcherPanel.swift:32-94`): the app switcher is AppKit plus plain `CALayer`s, one per icon, rebuilt whenever
  `!panel.isPresented || switcher.row != laidOutRow`; `show` re-sets **every** icon layer's `transform` on every render as
  an implicit 0.12 s action (the 1.12 selected grow); there is no per-swipe serial on `Switcher` (the window switcher has
  one and lays out once per serial). Sublayers draw above their parent's contents, so copies behind an icon need a
  per-slot container, with the selection transform on the container.
- F34 **sourced** (`LauncherCore/SwitcherRowLayout.swift`): 80 pt icons, 20 pt gaps, 92 pt highlight, 22 pt padding, panel
  136 pt tall at full size, icon centre 68, icon top 108; `scale` shrinks everything but the padding. Copies peeking 6, 12
  and 18 pt reach 126 at rest and about 133 when the slot is selected (x1.12 about the centre), inside the 136 pt panel;
  the end slots' copies come near the radius-34 continuous-corner clip (`LauncherUI/GlassClip.swift:9-11`). On paper only.
- F35 **sourced** (`docs/architecture.md` Concurrency, animation paragraph): animation is Core Animation, played by the
  render server, cleaned up from completion; nothing of ours runs per display frame; code may run per input event while its
  effect is on screen. `PickAnimation` (Core curve, `CAKeyframeAnimation` in UI, tested in both targets) is the precedent
  for a pure curve rendered by Core Animation (`LauncherCore/PickAnimation.swift`, `LauncherUI/AppPicker.swift:277-285`).
- F36 **sourced** (`G/how-window-switcher-ui.md` Non-Obvious 9): Reduce motion is read live from
  `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` at each use in both presenters, with no injected reader;
  `GearView.init(image:reduceMotion:)` is the precedent for injecting it.
- F37 **disputed** (`G/how.md` Open questions): whether `Observations({ launcher.switcher })` can coalesce a `nil` and the
  next swipe's value. For: it is an async sequence over observed changes, delivered on the main actor after the writes.
  Against: every recognised event is its own main-queue block, and today's presenters work. Not probed. A per-swipe serial
  on `Switcher`, as on `WindowSwitcher`, makes it moot.

## Constraints from `why` (abridged; full set in `G/why.md`)

Preserve: only ids from the latest read are raised; raising is a frontmost-app operation; a declined slide is exactly the
setting-off slide; the lift is computed from a second read; a lift that changes nothing is silent with no side effect (no
hide); the frame thread never waits or makes AX calls; the main actor is never blocked by a multi-app read; one API, one
owning adapter (prefer an existing confined file); the own process is never read; geometry stays a pure tested Core value;
icons are ready before any swipe.
Change, knowingly: model-held window state across swipes; the 2+ rule; the Accessibility use statement; the meaning of the
answer hop. Avoid: AX on the frame thread; letting a background count gate a window swipe or a lift; AX observers for
counts; reordering rows mid-swipe; treating the per-call timeout as a per-app deadline; changing the process-wide timeout
without `LaunchWatch` in mind.

## Tests: what is real, what needs a fake, what is manual

- **Real in `swift test`:** the model through `World` (`LauncherCoreTests/World.swift`) with real `GestureRecognizer`s
  under `InMemoryTrackpads` (synchronous delivery, the window-swipe answer applied before the next frame, `pulses`,
  `windowSwipeAnswers`) and `RecordingSystemActions` (`runningApps`, `FakeWindows`). Pure Core values: layouts, selection,
  the lift rule, title rules, `PickAnimation` (`LauncherCoreTests`). Platform pure statics over raw facts
  (`LauncherPlatformTests/FrontmostAppWindowsTests.swift` tests `sort` with facts copied from probes). `LauncherUITests`
  benches drive AppKit views in a never-ordered-in window and read back `CALayer` animations, with `reduceMotion`
  injected (`PickerBench`, `GearBench`). The source-policy scan.
- **Needs a fake or an extension:** `FakeWindows` models one window stack for "whichever app is frontmost", keyed by title;
  stacks need windows per app, a slow app (answers later), an app that never answers, and a way to deliver answers after
  the switcher shows. The model reads no clock today (`Uptime` exists in Core, read only in `UptimeNow.swift`; `FrameStream`
  takes an injected `clock: @Sendable () -> Uptime`): a 0.2 s deadline needs a clock or a deadline push a test can drive.
  No app quit push exists for the fake to send.
- **Manual only:** real AX against hung, slow and cold apps (plan 012 chose a manual check, M18, over faking the AX API:
  "faking the AX calls would test our model of the API, not the API"); hidden apps and other Spaces; Finder's Get Info
  panel (R2 scenario; its subrole is **not probed**, since opening it needs Finder automation and a permission prompt); the
  rise's and the card's feel; the clip margin in the panel's corners; Reduce motion on screen.

## Open questions (for the design to settle or to flag)

1. **Hidden apps' counts** (F12). R2 says "its windows on the current Space, minimised ones included". A hidden app's
   document windows are neither on screen nor `AXStandardWindow`. Count them (how, given panels also report `AXDialog`;
   the full-screen button is one probed signal on AppKit windows), or show such apps alone? With *Hide background apps* on
   this decides whether stacks show at all.
2. **Off-Space windows for the order** (F21). Keep absent ids in the order (they can never return as other windows, F19),
   or prune by CG `optionAll`, or by an app-quit signal? And how is "the app quit" known without a push (F22)?
3. **Where the 0.2 s per-app deadline lives** (F8, F9): in the adapter (per-element timeouts held to a remaining budget),
   in the model (a clock), or on Core Animation's clock; and how a test drives it.
4. **Trackpad Launcher frontmost** (F29): card ("No other windows / Trackpad Launcher has no other windows on this
   desktop.") or no window swipe; its own window count without an AX read of itself.
5. **The read's result cases** (F18): the window swipe needs answered-with-windows, answered-with-none, did-not-answer,
   no app and own process; a partial read must count as not answered (R13).
6. **First-swipe misses** (F7): cold reads up to about 200 ms; accept, or warm each app's AX at a cheaper moment?
7. **Card text width** (F30): two lines of text beside the icon in a 360 pt panel; "‹App› has no other windows on this
   desktop." does not fit the 200 pt title column on one line at 13 pt.
8. **Card motion units** (F31): the 6 pt cap and damping are in points on screen, while travel is in cursor-scaled step-mm.
