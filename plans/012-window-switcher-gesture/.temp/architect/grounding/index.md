# Grounding index: window swipe (plan 012)

The artifact the runners, the judge and the test planner start from. Paths are relative to the worktree root unless
absolute. `G/` is this directory. Standing of each fact:

- **probed**: what a probe printed on this machine today (macOS 26.6.2, SDK 26.5, the shell Accessibility-trusted and
  holding Screen Recording). Probe sources and verbatim outputs are in `G/probes/` (see its README). A conclusion drawn
  from an output is marked *conclusion*.
- **sourced**: a file and heading state it.
- **disputed**: both sides, with their evidence.

## Status of `how` and `why`

- `how` ran: `G/how.md` (the traced model; four explorer files `G/how-*.md` behind it). Read `how.md` in full: its
  "Where the window swipe meets this" section lists every file:line the change touches, and its Gotchas section has
  the stale comments and the R9 mismatch.
- `why` ran: `G/why.md`, ending with the Preserve / Change / Avoid / Risk constraint set. The design must honour it.
- Not greenfield: the window swipe is a sibling of the swipe and shares its recognizer, model, ports, panel pattern,
  settings and hints.

## Facts, by design question

### Q1. Recognising a vertical slide: direction decided once, vertical travel, the setting gate (R1, R2, R9, R15, R16)

- F1 **sourced** (`G/how.md` "One swipe, frame to haptic", `beginOrSpoil`): today a first drag past 3 mm that is not
  strictly more sideways than up or down spoils the pair (`.spoiled` is terminal until the non-thumb fingers lift). So
  "today's direction rules" (R16, setting off) = vertical drag spoils and later scrolls once the blocking window passes.
- F2 **sourced** (`G/how.md` meets #2): the swipe setting gates the pair itself (`let pair = swipes ? Pair(...) : nil`)
  and the `.resting` state. R16's "swipe off, window swipe on" passes through both lines.
- F3 **sourced** (`G/how.md` Gotchas "Travel is x-only"): `PointerCurve.cursorPoints` computes the speed from
  `hypot(dx, dy)` and returns `dx * multiplier / velocity`; `SwipeTravel.travel` returns x only. *Conclusion*: the y
  component is `dy * multiplier / velocity` by the same curve, because macOS acceleration scales the pointer delta by a
  multiplier that depends on speed alone. Not probed.
- F4 **sourced** (`G/how.md` Gotchas "The plan's R9 premise"; `Tests/SwipeTravelAndExitTests.swift:20-41`): the app
  switcher's travel starts at 0 on the begin frame; the 3 mm that start a swipe do not count towards the selection.
  R9 in the plan has been corrected to say so (the requirement's stated intent is "as in the app switcher").
- F5 **sourced** (`G/how.md` "The hop to the main actor"): only events hop, in frame order, through the one mapping
  `TrackpadEvent.init`; a replaced session's late events are dropped by the `runs == generation` check.
- F6 **sourced** (`G/how.md` `.swiping` handling, "Blocking: the other output"): `.swiping` holds both blocking flags on
  every frame (no timer); cancel on `press == .click` or a third finger; end when both fingers lifted; a lifted finger
  leaves and a landing outside the corner joins; the thumb plays no part after begin. R15 asks the window swipe to
  match all of this, so the natural shape is one `.swiping` state with an axis, not a second state machine.
- F7 **sourced** (`docs/domain-model.md` "Click blocking", `G/how.md` "Blocking"): with Accessibility, scrolling is
  suppressed from the thumb's landing while another finger is down (3 s window) and for the whole swipe; a scroll that
  began before suppression is "stilled". R15's "No scroll under a window swipe" is carried by that mechanism unchanged.

### Q2. Listing the frontmost app's windows (R3, R4, R13, R14)

- F8 **probed** (probe 2): `kAXWindowsAttribute` on `AXUIElementCreateApplication(pid)` returned the app's document
  windows in 0.29 ms; reading 8 attributes on each of 3 windows took 0.62 ms. In every reading the AX order matched
  the CG front-to-back order, with minimised windows last. *Conclusion*: AX order follows z-order, but no source
  documents it; CG on-screen order (F11) is the documented one.
- F9 **probed** (probe 2): per window, `kAXTitleAttribute` (an empty string for an untitled window, so "no title" means
  empty), `kAXRoleAttribute` = `AXWindow`, `kAXSubroleAttribute` = `AXStandardWindow` for document windows,
  `kAXMinimizedAttribute`, `kAXPositionAttribute`/`kAXSizeAttribute`. **A minimised document window reported subrole
  `AXDialog`**, so a subrole filter must apply only to visible windows; minimised ones are admitted by
  `kAXMinimized == true` alone.
- F10 **probed** (probe 5): making the front window full screen (settable `AXFullScreen`) left the AX list holding
  that window (`AXFullScreen == true`, subrole `AXStandardWindow`) plus an untitled sibling with subrole `AXUnknown`;
  the window left on the previous Space **disappeared from `kAXWindowsAttribute`**. `AXRaise` on that other-Space
  window succeeded and **switched Spaces**. *Conclusion*: the app's window list must be limited to the current Space
  before anything is raised, and the full-screen front window yields one row (R3) with nothing raised on lift.
- F11 **probed** (probes 2, 3) and **sourced** (`CGWindow.h`, `kCGWindowListOptionOnScreenOnly`):
  `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` lists on-screen windows
  front to back with `kCGWindowNumber`, `kCGWindowLayer` (0 for normal windows), `kCGWindowBounds`, `kCGWindowOwnerPID`;
  minimised and other-Space windows are absent. Cost: **52 ms on the first call in a process, 1.26 ms warm, 0.40 ms
  with a pid filter**. `kCGWindowName` was present because this shell has Screen Recording; without it names are
  absent (sourced: macOS 10.15 release notes; not probed), so titles must come from AX.
- F12 **probed** (probe 2): the private `_AXUIElementGetWindow(AXUIElementRef, CGWindowID*)` resolves with
  `dlsym(RTLD_DEFAULT, ...)` and returns the id equal to `kCGWindowNumber` / `SCWindow.windowID`. Precedent for a
  private symbol via `dlsym`, confined to one file, with a fallback when missing: `LaunchServicesOrder.swift`
  (`docs/architecture.md` Privacy and permissions). Fallback without it: match AX position/size and title against CG
  bounds (F9, F11).
- F13 **probed** (probe 2): a minimised window stays in the AX list with `kAXMinimized == true`, leaves the CG on-screen
  list, and appears in `optionAll` without `kCGWindowIsOnscreen`.
- F14 **probed** (probe 2): after a window closes, its `AXUIElement` answers `kAXErrorInvalidUIElement` (-25202) to
  attribute reads and to `AXRaise`. R10/R11 "a window that has closed changes nothing" falls out of ignoring that error.
- F15 **sourced** (`AXUIElement.h` `AXUIElementSetMessagingTimeout`, `AXError.h`): each AX call is synchronous IPC
  bounded by a per-element timeout; `kAXErrorCannotComplete` (-25204) when the app does not answer in time;
  `kAXErrorAPIDisabled` (-25211) when the caller is not trusted (not probed: this shell is trusted). The begin path
  runs on the main actor, so the adapter should set a short timeout on the app element.
- F16 **sourced** (`G/how.md` meets #20): `AppEntry`/`RunningApps` carry no pid; `NSWorkspace.shared.frontmostApplication`
  gives the frontmost pid inside an adapter. The frontmost app at begin is already a model concept
  (`docs/domain-model.md` "Frontmost app"); Trackpad Launcher itself is never it.
- F17 *conclusion* from probe 2 (a plain command-line process, trusted through its terminal) and `Config/Base.xcconfig`
  (`ENABLE_HARDENED_RUNTIME = YES`, no sandbox, no entitlements in `project.yml`): AX client calls need the Accessibility
  grant and nothing else. R14 covers the untrusted case.
- F18 **probed** (probe 3): `SCShareableContent` (all windows) listed, for TextEdit, four untitled layer-0 off-screen
  helper windows and one 500×500 off-screen window that AX does not list. *Conclusion*: the AX list defines the set of
  windows; CG/SC only order it and decide on-screen membership.

### Q3. Raising, focusing, restoring, re-stacking (R10, R11, R15)

- F19 **probed** (probe 2): `AXUIElementPerformAction(window, kAXRaiseAction)` took 1.4–2.2 ms, moved the window to the
  front of its app, and moved `kAXFocusedWindowAttribute` and `kAXMainAttribute` to it (keyboard focus) while the app
  was active. R10's "come to the front and get the keyboard focus" is one call.
- F20 **probed** (probe 2): `AXRaise` on a minimised window **restores it** (and fronts and focuses it). R10 forbids
  restoring while sliding, so the slide must never raise a minimised row.
- F21 **probed** (probe 2): `kAXMinimizedAttribute` is settable both ways (0.14 ms to minimise, 0.38 ms to restore);
  after a restore the window is in front and focused.
- F22 **probed** (probe 2): raising windows one after another, back to front, re-stacks exactly: raising Beta, Alpha,
  Gamma in that order produced the order Gamma, Alpha, Beta; three raises took 7.9 ms. R11's final order
  (selected, front window, the others as before) is reachable by raising in reverse of that order, and only the
  windows out of place need raising.
- F23 **probed** (probe 2): setting `kAXFocusedWindowAttribute` on the app element returned success and changed nothing;
  setting `kAXMainAttribute` likewise. Not needed given F19.
- F24 **probed** (probe 5): see F10: raising a window on another Space switches Spaces. Never raise an unlisted window.

### Q4. Previews (R6, R7, R17)

- F25 **probed** (probe 4, typecheck): `CGWindowListCreateImage` is **obsoleted in macOS 15** (compile error under the
  macOS 26 SDK); ScreenCaptureKit is the only capture path. `CGPreflightScreenCaptureAccess()`,
  `CGRequestScreenCaptureAccess()`, `NSGlassEffectView` (`cornerRadius`, `tintColor`, `style`),
  `NSGlassEffectContainerView` (`contentView`, `spacing`) and `NSPanel` with `.nonactivatingPanel` all compile.
- F26 **probed** (probe 3): `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)` took 14 ms
  (async); all windows 55 ms. `SCWindow` carries `windowID` (= `kCGWindowNumber`), `title`, `isOnScreen`, `isActive`,
  `windowLayer`, `frame`, `owningApplication?.processID`. Its on-screen order matched the CG order.
- F27 **probed** (probe 3): `SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow:),
  configuration:)` with `width`/`height` set to fit 240×120 px, `scalesToFit`, `showsCursor = false`,
  `ignoreShadowsSingleWindow = true`: **100 ms for the first capture in the process, then 19–28 ms per window; seven
  windows captured concurrently in 94 ms**. The image keeps the window's proportions when width and height are set
  proportionally (186×120 px for a 656×422 pt window). An occluded window captures its own content. A minimised window
  also captures (the plan's non-goal note says macOS keeps no picture; the requirement R4 still shows the icon, and
  the non-goal stands as a product choice).
- F28 **probed** (probe 1) and **sourced** (`CGWindow.h:294-298`): `CGPreflightScreenCaptureAccess()` "checks whether
  the current process already has screen capture access" and returned without prompting;
  `CGRequestScreenCaptureAccess()` "requests … access if absent, potentially prompting". **Unknown** (no source, not
  probed): whether a second call after a denial prompts again. R8 is written so the design need not know: the first
  press asks, any later press opens System Settings, which needs an "asked before" fact the app persists.
- F29 **probed** (probe 6): the Darwin notification `com.apple.tcc.access.changed` fired on a Screen Capture access
  change (a `tccutil reset ScreenCapture` of the app's own, never-granted entry; one post per built copy tccd knew).
  The existing Accessibility adapter listens to exactly this name (`SystemAccessibilityPermission.swift:10`). It
  carries no payload and names no service: the listener re-reads both permissions.
- F30 **disputed**, not probed (cannot toggle TCC here): whether macOS 26 still requires a relaunch before capture works
  after the grant. Historically the system asks to "Quit and Reopen". R7's wording ("after any relaunch macOS requires")
  already covers both; the design must not assume either.
- F31 **disputed**, not probed: since macOS 15, apps that capture through ScreenCaptureKit without the system picker
  get a periodic system alert ("… is requesting to bypass the system private window picker and directly access your
  screen …", allow for a period). From general platform knowledge, no local source. A UX risk for the human to weigh;
  it does not change the design.
- F32 **sourced** (`docs/architecture.md` Shape: "Framework and wire types never cross a port … `NSImage` stay inside
  adapters and views"; `G/how.md` "The shell", `AppIcons`): images never enter `LauncherCore`. Icons are owned by
  `LauncherUI` (`AppIcons`) keyed by app; previews follow the same ownership, keyed by window identity, and R17
  ("in memory only, discarded at end") is a shell-side invariant checked in code review plus the source policy's ban on
  file writes (`G/how.md` "What the source policy forbids").
- F33 **sourced** (`docs/architecture.md` Concurrency; Shape: "unless they deliver asynchronously: those sit behind a
  port so the model's tests stay synchronous"; `G/how.md` two-adapter rule, `AppScanner` precedent with
  `holdScans()`/`deliverHeldScan()`): capture runs off the main actor and its results hop back; anything delivering
  asynchronously to the model sits behind a port with an in-memory adapter the tests can hold and release.

### Q5. Permissions and the hint (R7, R8, R14)

- F34 **sourced** (`G/how.md` "Settings and permissions", "What the source policy forbids"): `AccessibilityPermission`
  port = `isGranted()`, `prompt()`, `onChange` push; real adapter `SystemAccessibilityPermission.swift` is the only
  file allowed to contain `AXIsProcessTrusted` and `notify_register` (`Tests/SourcePolicyTests.swift:64-76`,
  `Confined.onlyIn` is one file name). A second file registering for the TCC notification fails the scan, so either one
  permissions adapter owns both permissions and the one registration, or the table changes. `docs/architecture.md`
  Privacy says "asks for one permission" and that the Accessibility APIs are confined to one file; `G/how.md` Gotchas
  notes only `AXIsProcessTrusted` is actually confined and the `AXUIElement*` family is neither banned nor confined.
- F35 **sourced** (`LauncherUI/LauncherActions.swift:5-16`, `LauncherUI/MenuBarShell.swift:147-150, 77-81, 98-102`):
  `SettingsPane` holds `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`; the Screen
  Recording pane is the same scheme with `Privacy_ScreenCapture`. `openSettings` closes the launcher window first; the
  window also dismisses on any outside mouse-down and on resigning key. So the window is closed while the user is in
  System Settings; the hint's disappearance (R8) rides on the TCC push (F29) and the window re-rendering from model
  state when it next opens.
- F36 **sourced** (`G/how.md` "Settings and permissions"): the only persistence is the `Settings` Codable record in
  `UserDefaults` (`decodeIfPresent ?? default` per field, so a new key defaults on upgrade). There is no "asked before"
  state today; a persisted flag for Screen Recording is a settings-record field. `docs/architecture.md` Privacy: "no
  files written other than settings in `UserDefaults`".
- F37 **sourced** (`LauncherCore/Copy.swift`; `G/how.md` meets #30): window copy lives in `Copy` (tested as values);
  the Accessibility hint is a `SettingsNotice` in `LauncherView`, placed by the refit tuple in `MenuBarShell` which
  observes `(activity, isAccessibilityGranted, isSwipeOn)`.

### Q6. The panel: Liquid Glass, placement, rows (R5, R6)

- F38 **sourced** (`G/how.md` "The shell"; `LauncherUI/SwitcherPanel.swift`, `LauncherUI/LauncherPanel.swift`): the
  switcher panel is borderless, `.nonactivatingPanel`, `ignoresMouseEvents`, `.screenSaver` level, joins all Spaces and
  full-screen apps, `canBecomeKey/Main` false, content = `NSGlassEffectView` under `roundedClip`; the highlight is a
  second glass view moved with Core Animation actions disabled and a spring for the rubber band; the presenter
  observes `Observations({ launcher.switcher })` (coalesced per main-actor turn) and hides with a 150 ms fade.
  `SwitcherPresenter.screen(under:)` picks the pointer's display; the switcher centres on `screen.frame`, while
  `MenuBarShell.refit` uses `visibleFrame` (whose `maxY` is the menu bar's bottom edge, what R5 "just below the menu
  bar" needs).
- F39 **sourced** (Apple, `AppKit-Implementing-Liquid-Glass-Design.md`: Key Classes, Working with
  NSGlassEffectContainerView, Best Practices): `NSGlassEffectContainerView` merges nearby glass views and cuts render
  passes; "limit the number of glass effects"; only `contentView` is guaranteed inside the glass; `cornerRadius`,
  `tintColor`, `style`. Also `G/how.md`: `LaunchTuning` (DEBUG tuner) is the precedent for keeping motion parameters
  in one value type, which suits the human's "best judgement now, refine together later".
- F40 **sourced** (`G/how.md` "Where the tests sit"): there is no `LauncherUI` test target; panel, presenter, icons and
  views are checked by hand. `SwitcherRowLayout` (pure, in Core) is unit-tested, so geometry policy belongs in Core.

### Q7. Settings (R16)

- F41 **sourced** (`G/how.md` "Settings and permissions", meets #16-18): a `Settings` field with `decodeIfPresent ??
  true`, a setter on the pattern of `setSwipe(on:)` that saves at once and calls `reconcile()`; `reconcile` rebuilds
  the recognizers when its `Run` value changes (ending any swipe in progress); `PersistenceTests` holds a frozen
  pre-swap record that must not be regenerated and `everySettingsFieldSurvivesTheStore`.

### Q8. Model and feedback (R9 to R13)

- F42 **sourced** (`G/how.md` "The model", `Switcher`): `Switcher` is a value whose row is fixed at begin; `follow(travel)`
  applies hard stops and the rubber band (`GestureRules` stretch/overshoot), `selected` is the nearest, one `.lightTick`
  per icon crossed; `.ended` clears the switcher, re-reads `runningApps()`, is silent on the frontmost app or a quit
  app, else `.gesture` haptic and `bringToFront`; `.cancelled` only clears. The selection maths is generic over
  `row.count` but typed to `[AppEntry]`.
- F43 **sourced** (`G/how.md` meets #19): `SystemActions` offers `runningApps()`, `bringToFront(AppEntry)` and haptics
  (`.lightTick`, `.gesture`); nothing window-level.

## From `why.md`: the constraints that shape the design

`G/why.md` ends with a Preserve / Change / Avoid / Risk set; read it whole. The items that decide shape, with the
plan's answer where the plan already gives one:

- **sourced** (Preserve 1, 3; Avoid 1, 2): one recognizer, one finger session; the window swipe begins in the same
  `beginOrSpoil` at the same 3 mm crossing, direction judged once by the strict split; the recognizer never learns
  whether the app has windows (no main-to-frame channel); a window swipe with one row still runs its course blocked.
- **sourced** (Preserve 4; Change 2, 3): travel crosses the port as one scalar in step millimetres, accelerated by the
  curve installed at begin; the axis must be fixed at begin and carried with it; R9 fixes 100 cursor points per row.
- **sourced** (Preserve 5; Avoid 9; Risk 4): the list is fixed at begin; the system is read at begin and at the lift;
  a window closed mid-swipe is the analogue of an app that quit (silent, never re-created); mid-swipe raises are the
  first mid-swipe effect, so the lift must not depend on a state the raises changed (F22 shows a full back-to-front
  raise sequence yields the exact order whatever happened in between).
- **sourced** (Preserve 6, 7; Avoid 4, 5, 6): the window switcher is model state rendered by `LauncherUI` with AppKit
  layers and Core Animation, panel pre-created; reads and effects belong on `SystemActions` beside `runningApps()` and
  `bringToFront` (or on an equally deep port), never as one-method ports, never as show/update/hide effects; AX,
  `CGWindowID`, images and `NSImage` never cross a port.
- **sourced** (Preserve 8; Change 5, 6; Avoid 7, 8; Risk 5, 6): every new sensitive API gets a `Confined` row; the
  Privacy sentence in `docs/architecture.md` and the glossary's Accessibility hint scope are amended in Phase D; the
  plan already states what the window swipe does without each permission (R7, R14); plan 012 retires the earlier
  non-goals on windows and previews.
- **Product risks for the human** (Risk 1, 2, 3): with the window swipe setting on, a vertical two-finger scroll
  under an anchored thumb is no longer scrolling after the blocking window (the plan's R16 makes the setting the way
  out, and `docs/domain-model.md` "Swipe setting" must change); thumb plus two fingers sliding up or down has the
  shape of macOS's three-finger Mission Control swipe, which the Dock-swipe filter drops only with Accessibility
  (R14 should say Mission Control may open without it); two- and three-finger taps that drift vertically past 3 mm
  will flash the window switcher as the sideways drift already flashes the app switcher (R1's drift scenario is at
  2 mm).

## Sources, by design question

- Q1: `G/how.md` (Key concepts; One swipe, frame to haptic; Load-bearing invariants; Gotchas; Where the window swipe
  meets this #1-#10, #32-#34); `G/why.md` (sub-questions 1 and 3; constraint set); `docs/domain-model.md` (Swipe,
  Switcher, Click blocking, Blocking window).
- Q2, Q3: `G/probes/probe-2-ax-windows.output.txt`, `G/probes/probe-5-spaces.output.txt`; SDK headers `AXUIElement.h`
  (`AXUIElementSetMessagingTimeout`, `AXUIElementPerformAction` discussion), `AXError.h`, `CGWindow.h`; `G/how.md` meets
  #19-#20; `docs/architecture.md` Privacy and permissions (private symbols via `dlsym`, confined, with a fallback).
- Q4: `G/probes/probe-3-capture.output.txt`, `G/probes/probe-4-sdk-symbols.output.txt`,
  `G/probes/probe-6-tcc-notification.output.txt`; the axiom-macos references
  `/Users/dominykasgrubys/code/skills/plugins/macos-dev-workflow/.claude/skills/axiom-macos/skills/screencapturekit.md`
  (Part 5 Screenshots, Critical Gotchas, Part 7 Migration) and `screencapturekit-ref.md` (Parts 1, 2, 3, 6, 11);
  `docs/architecture.md` Shape and Concurrency; `G/how.md` meets #21.
- Q5: `G/how.md` Settings and permissions, meets #22-#24, #31; `LauncherUI/LauncherActions.swift`,
  `LauncherUI/MenuBarShell.swift`, `LauncherCore/Copy.swift`; `Tests/SourcePolicyTests.swift`.
- Q6: `G/how.md` The shell, meets #25-#30; Apple's
  `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/AppKit-Implementing-Liquid-Glass-Design.md`;
  `/Users/dominykasgrubys/code/skills/plugins/macos-dev-workflow/.claude/skills/axiom-macos/skills/appkit-modernization.md`
  ("macOS 27 Look and Feel": `NSGlassEffectView.effectIsInteractive`, concentric corners);
  `docs/product-overview.md` ("latest liquid glass human interface design").
- Q7, Q8: `G/how.md` The model, Settings and permissions, meets #11-#18; `docs/domain-model.md` (Switcher, Feedback,
  Light tick, Swipe setting, Swap setting).
- The human's instructions, verbatim, are at the top of the architect's task context and in `task.md`: modern UI,
  Liquid Glass patterns, the axiom-macos skill, the switcher always shown, previews with titles, best-judgement
  interaction and motion to be refined together later.

## What a test can produce for real, what needs a fake, what stays manual

- **Real, in `LauncherCoreTests`**: the recognizer through `TouchScript` (millimetres, `slide(byMM:)` already takes
  `(x, y)`); the model end to end through `World` (real `Launcher`, real recognizer and click/scroll filters inside
  `InMemoryTrackpads`, in-memory adapters, a throwaway `UserDefaults` suite, fake bundles in a temp folder);
  `Settings` persistence; pure policy values (`Switcher`-style selection, row geometry, a re-stack order, the row
  derivation from window facts); the source policy scan; `Copy` strings.
- **Needs a fake (in-memory adapter) with a test handle**: the app's windows (what the frontmost app's windows are,
  which raises/restores/re-stacks were requested, a window that closes mid-swipe, an app that answers nothing);
  previews (held, then delivered, or never delivered); the Screen Recording permission (granted or not, whether a
  prompt was requested, the push); haptics (already recorded by the fake `SystemActions`).
- **Possible in `LauncherPlatformTests` but only when the test process is trusted**: an AX adapter run against the
  test process's own windows (own pid), skipped when `AXIsProcessTrusted()` is false. The suite's hygiene standard
  (`d612c10`) forbids leaving state behind; nothing in the suite activates or launches other apps today.
- **Manual**: the panel's look and glass, placement on the pointer's display and on a second display, shrink-to-fit
  on a short display, the motion, the real `AXRaise` behaviour across apps (probed once here on TextEdit), capture
  images, the TCC prompt and the System Settings page, any relaunch macOS requires, the periodic capture alert (F31).

## Open questions

- O1 (F3): is the y-axis acceleration the same curve applied to `dy`? Conclusion by symmetry; verify by feel.
- O2 (F28): does `CGRequestScreenCaptureAccess()` prompt again after a denial? The design persists "asked".
- O3 (F30): does macOS 26 need a relaunch after the grant? Covered by R7's wording either way.
- O4 (F31): the periodic ScreenCaptureKit alert on macOS 15+: a product risk for the human.
- O5: apps whose accessibility tree is off until an assistive client connects (Chromium enables it on first AX query;
  Java apps need the access bridge): what `kAXWindowsAttribute` returns for them was not probed; the design degrades to
  the "No open windows" row and the messaging timeout bounds the wait.
- O6 (F34): which file owns the `AXUIElement*` family and the capture APIs under the source policy, and whether
  `docs/architecture.md` Privacy changes from "one permission" to two. A design decision, then a doc change in Phase D.
- O7 (F8 vs F11): whether to order rows by AX order (fast, observed) or by CG on-screen order (documented, 1.3 ms
  warm, 52 ms once per process). A design decision; the probes support both.
