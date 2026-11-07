# Current-code map (before plan 042): window reads, window switcher, app switcher presenter, test harness

Paths relative to the worktree root. `LK` = `LauncherKit`. Line numbers are as of the plan commit; they drift as slices land.

## Names to rename
- `FrontmostAppWindows`: `LK/Sources/LauncherPlatform/FrontmostAppWindows.swift` (definition), `WorkspaceActions.swift:8`, `LK/Tests/LauncherPlatformTests/FrontmostAppWindowsTests.swift`, `LK/Tests/LauncherCoreTests/SourcePolicyTests.swift:172-173` (confinement file names).
- `WindowStack` enum: `LK/Sources/LauncherCore/WindowLift.swift:4` (definition), `:64` (its only use, in `WindowSwitcher.lift`). No test names it.

## LauncherPlatform
### FrontmostAppWindows.swift
`@MainActor final class FrontmostAppWindows`
- `static let messagingTimeout: Float = 0.2`; `getWindow` = `_AXUIElementGetWindow` via `dlsym(RTLD_DEFAULT)`; `private var listed: [WindowID: AXUIElement]` (raise handles); `private var isUnanswering`.
- attributes, in order: role, subrole, title, minimised, "AXFullScreen", position, size.
- `init()`: sets system-wide messaging timeout 0.2; resolves getWindow; `Task { await Self.warmWindowList() }` (`@concurrent`).
- `func read() -> FrontmostWindows`: reset listed; frontmost app nil → `.noApp`; own pid → `.app(entry, visible: [], minimised: [])`; `kAXWindows` copy, any error → empty `.app` (isUnanswering = cannotComplete); per window `AXUIElementCopyMultipleAttributeValues`: cannotComplete → isUnanswering + break (keeps partial), other → continue; number via getWindow; frame/title fallback only when some number is nil (`listedWindows(of:)` once, `Self.number(of:among:)`); `Self.sort(raw, onScreen: Self.onScreenNumbers(of: pid))`; fills `listed` for sorted windows.
- `func raise(_ frontToBack:)`: reverse; skip if isUnanswering or id not in listed; `kAXRaiseAction`; cannotComplete → isUnanswering.
- helpers: `number(of element)`, `rawWindow(values, number:)`, `onScreenNumbers(of:)` (`.optionOnScreenOnly, .excludeDesktopElements`), `listedWindows(of:)` (`.optionAll`), `windowList(_:of:)` (owner pid, layer 0).
- `nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32]) -> (visible:, minimised:)`: no number dropped; minimised by flag in AX order; visible = AXWindow/AXStandardWindow, ordered by onScreen.
- `nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32?`: exact frame + name==title when named; single match only.
- `struct RawWindow: Sendable { var number: UInt32?; let title; let role; let subrole; let isMinimised; let isFullScreen; let frame: CGRect? }`, `struct ListedWindow: Sendable { number, frame, name? }`.
### WorkspaceActions.swift
`@MainActor public final class WorkspaceActions: SystemActions`; owns `windows = FrontmostAppWindows()`, `reader = RunningAppsReader()`, `hider`. `frontmostWindows() { windows.read() }` (:87), `raiseWindows { windows.raise }` (:89).

## LauncherCore
- `WindowSwitcher.swift`: `WindowID(rawValue: UInt32)`, `AppWindow(id:title:isFullScreen:)`, `enum FrontmostWindows { case noApp; case app(AppEntry, visible:, minimised:) }`; `WindowSwitcher { Content { app, windows: WindowList }, enum WindowList { .front(AppWindow, others:, minimised:), .minimisedOnly(first:, rest:) }, enum Row { .visible(WindowID, title:), .minimised(...) }, content, selection, serial, trackpad, showsPreviews }`; `package init(_ content:, showsPreviews:, serial:, trackpad:)`; `rows` (untitled → `Copy.untitledWindow(of:position:)`, else `WindowTitleRule.displayTitle`); `previewWindows`, `frontWindow`, `selectedVisibleWindow`; `Content.init?(_ read: FrontmostWindows)` (:145-165): nil for noApp, full-screen front, < 2 rows; cut at `GestureRules.windowSwitcherMaxRows`.
- `WindowLift.swift`: `enum WindowStack { static func raises(current:target:) }`; `struct WindowLift { raises, playsHaptic, static nothing }`; `WindowSwitcher.lift(now:)` (:51-65).
- `SwitcherSelection.swift`: `count`, `travelMM`, `package init(count:)` (only init), `follow(_:) -> Int` crossed, `selected` (round(travel/12)), `position`, `stretch`.
- `Switcher.swift`: `row`, `startsOnFrontmost`, `selection`, `trackpad`; `package init?(frontmost:running:leavingOut:trackpad:)`; `selectedApp`, `selectsFrontmost`.
- `SwitcherRowLayout` (iconSide 80, gap 20, highlight 92, padding 22, selectedIconScale 1.12; `centreX(at:)`, `centreY`, `panelSize`, `scale`), `WindowColumnLayout(rowCount:displayHeight:)`.
- `GestureRules`: `switcherMaxApps = 10`, `windowSwitcherMaxRows = 10`, `switcherStepMM = 12`, `switcherMaxStretch = 0.2`, `switcherMaxOvershoot = 0.25`.
- `Copy`: `minimisedBadge`, `untitledWindow(of:position:)`.
- `Ports.swift:61` `SystemActions`: `runningApps()`, `frontmostWindows() -> FrontmostWindows` (:132), `raiseWindows(_:)` (:138), `hideOtherApps(than:)`. `TrackpadHardware.confirmWindowSwipe(on:)` (:49).
- `Uptime { seconds; + Duration }`; the clock is read only in `LauncherPlatform/UptimeNow.swift`.
- `Launcher.swift`: `shown: ShownSwitcher?` (`.apps`/`.windows`), `windowSwipesBegun`; `swipe(_:)` (:339-370); `windowSwipe(_:)` (:372-408): `.began` guards `activity.isActive, let content = WindowSwitcher.Content(system.frontmostWindows())`, confirms, requires `shown == nil`, builds switcher; `.moved` follows + raises on crossing; `.ended` second read, `lift(now:)`, haptic, `raiseWindows`, `hideOtherApps` if haptic; `.cancelled` clears. `reconcile` drops `.windowSwipe` slides without Accessibility.

## LauncherUI
- `SwitcherPresenter(launcher:)`: icon passes (sync first pass when swipe on), `Observations({ launcher.switcher })` → `render`, `Observations({ launcher.isSwipeOn })` → icon passes. `render` keys on `laidOutRow`, reads Reduce motion from NSWorkspace directly.
- `SwitcherPanel: OverlayPanel`: `layoutRow(_:layout:on:scale:)`, `show(position:selected:animatesSize:)` (1.12 over 0.12 s), `springHighlight(from:)`.
- `WindowSwitcherPresenter(launcher:)`: `Observations({ launcher.windowSwitcher })` → `render`; `open` captures previews (`PreviewCapture`), `panel.lay(out:icon:layout:topLeft:)`, `awaitPreviews`, `present(appear:)`.
- `WindowSwitcherPanel`: pre-created `WindowRowView`s, `lay(out:...)`, `setPreview`, `show(position:selected:)`, `springHighlight(fromY:)`.
- `OverlayPanel`: `present(appear:)`, `dismiss()` (150 ms fade), both read Reduce motion directly; `emptied()` hook.
- `SettingsShell.init` (:50) builds `SwitcherPresenter(launcher:)` (:67) and `WindowSwitcherPresenter(launcher:)` (:68); it must be created before `Launcher.start()` so the first icon pass finishes first (composition root `TrackpadLauncher/TrackpadLauncherApp.swift:78-92`).
- `GearView(image:reduceMotion: @escaping () -> Bool)`; production passes `{ NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }`.

## Tests
- Fakes in `LK/Tests/LauncherCoreTests/InMemoryAdapters.swift`: `InMemoryTrackpads` (`pulses`, `windowSwipeAnswers`, `pressVerdicts`, clock); `RecordingSystemActions` (:275; `frontmost`, `running`, `broughtToFront`, `hidesOthers`, `let windows = FakeWindows()`, `frontmostWindows()` → `windows.read(frontmost:)`); `FakeWindows` (:392-473): one stack for whichever app is frontmost; `onScreenTitles`, `minimisedTitles`, `answers`, `dropsRaises`, `reads`, `raised`; `set(visible:minimised:fullScreenFront:untitled:)`, `open`, `minimise`, `close`, `id(_:)` (ids `1000 + n` per title), `read(frontmost:)`, `raise`.
- `World.swift`: `init(apps:attached:accessGranted:screenRecording:)`, `relaunch()` (new Launcher, same adapters), `switcherWorld(...)` (:257), `windowWorld(visible:minimised:fullScreenFront:untitled:frontmost:accessGranted:screenRecording:attached:)` (:349), `swipe(...)`, `windowSwipe(...)`, `playFrameByFrame`, `window(_:)`, `openSettings()`.
- Window test files: `WindowSwitchingTests` (holds `liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere` :64), `WindowSwitcherOnScreenTests` (`theListIsCutAtTenWithTheVisibleWindowsFirst` :70), `WindowSwipeNeedsTwoWindowsTests` (`withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff` :120, `aWindowThatOpensMidSlideDoesNotMakeItAWindowSwipeButCountsForTheNextSlide` :153, `withoutAccessibilityASlideDownIsNoWindowSwipeAndAGrantBringsItBackWithTheNextSlide` :176), `SettingsWindowAsAppTests` (`slidingDownOverTheSettingsWindowIsNoWindowSwipe` :93), `HideBackgroundAppsTests`, `SwitcherOnScreenTests` (`twoRunningCopiesOfOneBundleAreTwoIcons` :88), `SwitcherTests`, `SwitcherRowLayoutTests`, `WindowSwipeAnswerTests`, `WindowSwipeBlockingTests`, `LiftWindowTests`, `WindowPreviewTests`, `WindowColumnLayoutTests`.
- `LauncherPlatformTests/FrontmostAppWindowsTests.swift`: pure `sort` and `number(of:among:)` over probe fixtures. `LaunchWatchClockTests.swift`: `await awaiting("what") { done in ... }` from `BoundedWait.swift`, lower time bounds only.
- `SourcePolicyTests`: scans `LK/Sources` and `TrackpadLauncher/` (not tests); `banned` includes `asyncAfter`, `Timer`, `makeTimerSource`, `DispatchSourceTimer`, `Task.sleep`, `displayLink`; `confined` :172-173 `AXUIElement` / `CGWindowList` only in `FrontmostAppWindows.swift`, `LaunchWatch.swift`.
- LauncherUITests benches: `GearBench.swift` (borderless NSWindow never ordered in, `ReduceMotionReader` box), `PickerBench.swift`.

## Running tests
`Scripts/test.sh` (`swift test` in LauncherKit); filter with `Scripts/test.sh --filter <Suite>`. Full gate: `make test`.
