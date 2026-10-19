## Design

### Problem

A fired gesture must choose between three visuals in the same synchronous main-actor turn as its haptic: the launch bounce, the launch animation, or nothing. It must then keep an icon alive for up to 10 s, glued to the pointer, and end that icon on events about another app's process, or on time. The existing shape gets in the way in five places. First, `Launcher.fire` never asks whether its app runs. The one read it could use, `runningApps()`, is the ⌘-Tab list, which misses menu bar apps (F3), and for 60–440 ms after our own `openApplication` macOS still lists no process (F7). So R14 cannot rest on any read and needs the model's own record. Second, the model has no clock, and the source scan bans `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource` and display links by substring, comments and `#if DEBUG` included (F23). Third, `playLaunchAnimation` is fire-and-forget and "never cancels" (F4), so nothing can end a visual early. Fourth, `SystemActions` has no push. Its `bringToFront` drops `openApplication`'s completion, which is the only way to learn of a failed launch (F2, F10). Fifth, the Accessibility element API and the window list are confined to `FrontmostAppWindows.swift` (F18). The probes fix what the lifecycle can lean on. The completion arrives at check-in, off the main thread, with an error or a terminated app for a launch that went nowhere (F9–F11). KVO on `isFinishedLaunching` and `isTerminated` pushes for every kind of app, menu bar apps included (F12, F13). Windows made by the time the app finishes launching are on screen within about 1 ms of finishing (F15). An `AXObserver` can register only from about that moment, and `kAXWindowCreated` then leads each later window by 1–9 ms (F16, F17). Without Accessibility, no push for a later window exists at all (F19). A Core Animation completion is a precise deadline (about 1 ms late), but only on a layer inside an ordered-in window (F24). Constraints the design keeps:
- The haptic and the first visible icon are issued in one turn.
- The app is brought to front before any animation work.
- `LauncherCore` imports only Foundation and Observation.
- No framework type crosses a port.
- Every port has two adapters.
- A bounce snapshots its tuning, because the tuner restores its override as soon as `play` returns (F25).
- Release builds are unchanged.

### Usage (caller's view)

```swift
// README (LauncherCore): a gesture that launches its app shows the launch bounce.
//
// The model decides everything:
//   * which visual a gesture gets;
//   * which bounces are live (keyed by bundle ID);
//   * how each one ends.
// The SystemActions adapter shows each bounce, watches its launch and keeps its time, and reports
// LaunchProgress through `onLaunchProgress`. A report for an app with no live bounce does nothing.
//
//   fire:            system.bringToFrontBouncing(app, cap: 10 s)   // opens the app first, then the bounce
//   .finishedLaunching:  system.limitLaunchBounce(of: id, to: 2 s)
//   .windowShown:        system.endLaunchBounce(of: id, with: .launchAnimation)
//   .wentNowhere:        system.endLaunchBounce(of: id, with: .quietFade)
//   .ranOut:             either ending, by stage
//
// Time is the adapter's. `.ranOut` arrives:
//   * at the cap,
//   * or at the limit set when the app finished launching,
//   * whichever comes first.
// Tests push it like any other report.
```

**Call site 1: `Launcher.fire`.** The decision comes before any effect. The effects run in today's order.

```swift
private func fire(_ event: GestureEvent) {
    guard activity.isActive, let assigned = settings.assignments[event.gesture], let app = catalog.locate(assigned)
    else { return }
    let visual = visual(for: app)                       // reads "has a process?" only when it decides something
    hardware.playFeedback(.gesture, on: event.trackpad)
    switch visual {
    case .launchBounce:
        bounces[app.bundleID] = .startingUp
        system.bringToFrontBouncing(app, cap: LaunchBounceRules.cap)   // brings to front first, inside the call
    case .launchAnimation:
        system.bringToFront(app)
        // After bring to front, so whatever the animation costs lands on the icon, never on the app.
        system.playLaunchAnimation(for: app)
    case .none:                                         // setting off, or R14: this app's bounce still plays
        system.bringToFront(app)
    }
    window = .closed
}
```

**Call site 2: the progress push, installed in `start()`, and the model's whole ending policy.**

```swift
system.onLaunchProgress = { [unowned self] app, progress in self.progress(progress, of: app) }

private func progress(_ progress: LaunchProgress, of app: BundleID) {
    guard let stage = bounces[app] else { return }      // the bounce ended: a late window plays nothing (R12)
    switch stage.next(after: progress) {
    case .carryOn: break
    case .startUp(let limit):
        bounces[app] = .startedUp
        system.limitLaunchBounce(of: app, to: limit)
    case .end(let ending):
        bounces[app] = nil
        system.endLaunchBounce(of: app, with: ending)
    }
}
```

**Call site 3: World tests at the model seam.** Lifecycle and time are pushed inline, and nothing waits.

```swift
@Test func aGestureForAnAppWithNoProcessBouncesItsIconInsteadOfTheLaunchAnimation() {          // R1
    let world = World(apps: ["Figma"])
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

    world.tap(2)

    #expect(world.system.bounces == [.init(app: world.app("Figma"), cap: .seconds(10))])
    #expect(world.system.broughtToFront == [world.app("Figma")])
    #expect(world.system.launchAnimations.isEmpty)
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
}

@Test func aMenuBarAppThatStartedUpKeepsOneBounceAndFloatsAwayWhenItsTwoSecondsRunOut() {    // R10, R14
    let world = World(apps: ["Bartender"])
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Bartender")), for: .five)
    world.tap(5)
    world.report(.finishedLaunching, for: "Bartender")
    #expect(world.system.bounces.first?.limit == .seconds(2))

    world.startProcess("Bartender")                     // macOS lists it now; ⌘-Tab never will
    world.tap(5)                                        // R14: haptic and bring to front, still one bounce
    #expect(world.system.bounces.count == 1)
    #expect(world.system.launchAnimations.isEmpty)
    #expect(world.system.broughtToFront.count == 2)

    world.report(.ranOut, for: "Bartender")
    #expect(world.system.bounceEndings == [.init(app: world.app("Bartender").bundleID, ending: .launchAnimation)])
}

@Test func stillStartingUpAtTheCapFadesQuietlyAndALaterWindowPlaysNothing() {                 // R11, R12
    let world = World(apps: ["Figma"])
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
    world.tap(2)

    world.report(.ranOut, for: "Figma")
    world.report(.windowShown, for: "Figma")

    #expect(world.system.bounceEndings == [.init(app: world.app("Figma").bundleID, ending: .quietFade)])
    #expect(world.system.launchAnimations.isEmpty)
}
```

**Call site 4: the Debug tuner's bounce preview (R18).** It bypasses the model as today's preview does, and gets its 3 s from the bounce's own deadline.

```swift
tuner = AnimationTuner(
    preview: { [overlay] in overlay.play(for: finder) },
    previewBounce: { [bounces] in bounces.preview(finder, for: .seconds(3)) })   // then floats away, as a window would
```

### Shape

**Data first.**
- **In the model,** the bounce data is `bounces: [BundleID: LaunchStage]`. `LaunchStage` has two cases, `.startingUp` and `.startedUp`, and absence means "no bounce playing". The two access patterns are both lookups by app: `fire` reads it (R14), and each progress push reads and writes it. Nothing iterates it, so a dictionary is the structure.
- **Ending policy (R9–R12).** It is one total function, `LaunchStage.next(after:) -> LaunchStep`:
  - A window ends the bounce with the launch animation in either stage.
  - Going nowhere ends it with the quiet fade in either stage.
  - Finishing launching moves `.startingUp` to `.startedUp` and limits the bounce to the 2 s grace.
  - Running out ends the bounce with the quiet fade while `.startingUp`, and with the launch animation once `.startedUp`.

  This covers R10 and R12, including the 9 s menu bar scenario: the cap comes before finishing + 2 s, and the stage is `.startedUp`. The model never needs to know which deadline passed, only the stage. "Ended" is not a stage, so a report after the end has nothing to act on (R12, last sentence). Per `model-the-domain` and `type-system-discipline`.
- **In the adapter,** the data is the row: `[Bouncing]` in start order, newest last, which gives R13's left-to-right order. Each entry holds:
  - its tuning snapshot,
  - three layers: a slot that follows, an icon that bounces, and a zero-size clock;
  - its deadlines.

  The model's dictionary is the only record of which bounces are live. The adapter never ends a bounce on its own: it reports `.ranOut` and waits for `endLaunchBounce`. Its row therefore follows the model's commands and is never a second source of truth (per `separate-before-serializing-shared-state`). The Debug preview is the one exception: it has no model, so its own callback ends it.

**The decision (R1–R3, R14).**
- `visual(for:)` is three lines:
  1. If the setting is off, the gesture gets nothing.
  2. If a bounce is live for this bundle ID, it gets nothing (R14).
  3. Otherwise `system.hasProcess(app.bundleID)` picks the launch animation or the bounce.
- The read happens only when it decides something.
- `hasProcess` is `NSRunningApplication.runningApplications(withBundleIdentifier:)`. It covers apps that are still launching and menu bar apps. It costs under 0.1 ms, and its 1.65 ms first call is paid in `WorkspaceActions.init` (F7).
- Identity is the bundle ID, as for assignments (F3).
- Swipes, window swipes and swaps never reach `fire`, so R3 holds by construction.
- **Order in `fire`.** `bringToFrontBouncing` is one port call that runs `openApplication` (with its completion) before it builds any layer. "Bring to front before any animation work" is therefore encoded in one method that the model cannot call out of order (per `encode-lessons-in-structure`). The bounce's first layers are committed in the same turn as the haptic (R1), as plan 004 reads "no later".
- **R14.** The repeated gesture calls plain `bringToFront`. F8 shows that a second `openApplication` changes nothing.
- **Effects that stay unconditional.** `window = .closed` runs on every path (R16).

**The port.** `SystemActions` gains four members and its first push. Each member is a separate model decision:
- `hasProcess` is read in `fire`.
- `bringToFrontBouncing(_:cap:)` is called in `fire`.
- `limitLaunchBounce(of:to:)` is called on startup.
- `endLaunchBounce(of:with:)` is called on any ending.
- `onLaunchProgress` carries `(BundleID, LaunchProgress)`.

No framework type crosses the port. `pid_t`, `NSRunningApplication`, `AXError` and `CALayer` stay in `LauncherPlatform`. Durations cross as `Duration`, the type `GestureRules` already uses. A bounce the adapter cannot show (no display) runs out on the next main-actor turn rather than staying silent, so no model record can be stranded (per `make-operations-idempotent`). `endLaunchBounce` and a second `bringToFrontBouncing` for a live app are both no-ops beyond bringing the app to front.

**The lifecycle (R9–R12): `LaunchWatch`, one per bounce.**
1. `bringToFrontBouncing` hands `openApplication` a completion. The completion maps the result to the launched process, or to nil: nil on an error (F10) or on a terminated app with pid −1 (F11). It then hops to the main actor. Only the pid crosses threads, and the main actor re-fetches the app with `NSRunningApplication(processIdentifier:)`.
2. A nil pid, a missing app or a terminated app reports `.wentNowhere`.
3. Otherwise the watch observes `isTerminated` and `isFinishedLaunching` with `[.initial, .new]`. `.initial` closes the race between the completion and the observation. Each observation hops to the main actor, as `SystemTrackpadPreferences` does.
   - `isTerminated` → `.wentNowhere`.
   - The first `isFinishedLaunching` → `.finishedLaunching`, and the watch takes one look at the windows (F15, F16):
     - It tries to register an `AXObserver` for `kAXWindowCreatedNotification`.
     - If that succeeds, it counts `kAXWindowsAttribute`. A splash counts (F16, run 8).
     - If the app does not answer yet (`cannotComplete`, F16 runs 1 and 8), or Accessibility is off (`apiDisabled`), it counts the pid's on-screen windows below the status-item level in the window list instead.

     The pure `LaunchWatch.look(_:windows:)` maps the outcome:
     - `.shown` → `.windowShown`;
     - `.watching` → wait for the observer's callback, then `.windowShown`;
     - `.blind` → nothing further. R10's limit ends the bounce.
4. The window-list fallback exists because the probes' late registrations (runs 1 and 8) were exactly the apps that made their windows while finishing. Those windows are listed by the time our hop runs (F15).
5. No retry runs, so the polling ban holds as written.
6. `endLaunchBounce` stops the watch: it invalidates the KVO and removes the observer's run-loop source. Once no bounce is live, nothing observes anything.
7. The AX code lives in `LaunchWatch.swift`, which joins `FrontmostAppWindows.swift` in the confinement table.
8. Accessibility is never checked: a refused call answers `apiDisabled`, as `FrontmostAppWindows` already relies on.

**Time (R10, R12, R18): Core Animation is the clock, and deadlines belong to a bounce.**
- Each bounce's clock layer is a zero-size sublayer of its slot, inside the ordered-in row panel, where F24 measured about 1 ms of lateness.
- A deadline is a 1→1 `opacity` `CABasicAnimation` on that layer. Its delegate's `animationDidStop` is the deadline passing.
- `bringToFrontBouncing` arms the cap.
- `limitLaunchBounce` adds a second deadline. Whichever passes first reports `.ranOut`, once. A later limit can never extend a bounce, because the cap stays armed.
- Ending a bounce cancels its deadlines (a flag) before it removes the layer. Its stops then report nothing.
- A stop the system causes, which arrives with `finished == false` and no cancel, reports as passed. So a bounce cannot outlive its cap.
- The tuner's 3 s preview is a bounce whose cap is 3 s, ended by its own callback.
- No token is unbanned and the model holds no clock. The idle-CPU rationale of R22 holds by construction: a deadline cannot outlive the bounce panel that carries it.
- Tests take time from the fake: `.ranOut` is pushed inline, and the cap and limit durations the model asked for are recorded and asserted.

**The pointer and the row (R5–R7, R13, R16).**
- **Row panel.** One display-sized panel on the pointer's display holds the row. It uses `LaunchOverlay`'s panel recipe: click-through, non-activating, `.screenSaver`, on every Space. Because the panel is the display, R6's cut at the top edge and the rule that nothing spills onto a display above both come free. Crossing to another display re-frames the panel once (R7).
- **Following.** `NSEvent` global and local monitors for moves and drags are installed when the first bounce starts and removed when the last stops following. They read only `NSEvent.mouseLocation` (F20). Each event does three things in one transaction with actions disabled, about 0.04 ms (F21):
  1. recompute the pure `BounceRow`;
  2. re-frame the panel if the display changed;
  3. set each slot's position.

  A non-zero `trailing` instead animates each slot from its presentation value over that time.
- **Re-flow (R13).** When the row changes, each icon that moves slides there through an additive position animation from its old minus its new rest to zero over `slide`. Pointer moves keep composing with it.
- **`BounceRow`, pure.** It places one row centred on the tip plus `offset`, newest on the right, `spacing` apart, with bottoms `gap` above the tip. It clamps sideways onto the display and never adjusts vertically (R5, R6), and it is pixel-snapped.
- **D1 reading.** The design relies on Hypothesis A: no code of ours runs per *display* frame, and code may run per *input event* while the effect it serves is on screen. That is the switcher's per-trackpad-frame precedent (006 F27, `docs/performance.md`). The bounce motion itself is keyframes on the render server. After the last bounce stops following, no monitor exists.
- **D2 reading.** Pointer *position* is read only while a bounce shows, used only to place the icon, and never kept. This is a new Privacy line, and the source scan confines `mouseMoved` and `addLocalMonitorForEvents` to the bounce overlay's file. It supersedes plan 002 R9's pointer clause for this one purpose, which needs the human's sign-off.
- **R16.** The panel ignores mouse events, the monitors are passive, and the click tap is untouched.

**The motion (R4, R8, R9, R11, R15).**
- **`BounceMotion`, pure.** It builds one cycle as 240-per-second `transform` keyframes about the icon's bottom centre:
  1. up for `timeUp`, easing out to `height`;
  2. down for `timeDown` with gravity;
  3. `rest` on the ground, with the optional area-keeping `squash`.

  The cycle repeats forever, starting at rest, so the first jump starts at once. Shipped values: 30 pt, 0.30 s up, 0.30 s down, 0.10 s rest. That is half the icon in 0.70 s (R8).
- **Reduce motion.** The cycle becomes an opacity pulse in place (R15).
- **Size and sharpness.** The icon is `LaunchTuning.iconSide` with the prepared 72 pt bitmap, so it is never upscaled (R4).
- **Ending.** The icon is lifted out of the row:
  - `.launchAnimation`: `LaunchOverlay.play(for:from:)` stages the existing flight at the icon's presentation centre (`staged(at:among:)` already takes a start point) in its own panel. The flight therefore no longer follows the pointer and runs from mid-jump if that is where the icon is (R9). Under Reduce motion the flight is `.fadeInPlace` (R15).
  - `.quietFade`: a small panel at the icon's presentation frame, cut to the display, fades it from its presentation opacity to 0 over `fadeOut` (R11, R15).
- **One frame for the swap.** Both endings build their new panel inside the same outer `CATransaction` that removes the slot, so the swap commits as one.

**The tuner (R17–R19).**
- **Knobs.** `LaunchTuning` gains `var bounce = Bounce()`, a nested struct of `Double` knobs whose defaults are shipped: height, timeUp, timeDown, rest, squash, gap, offset, trailing, spacing, slide, fadeOut, pulseLow, pulsePeriod.
- **Section.** A "Launch bounce" section uses the existing `knob` helper with nested key paths (`\.bounce.height`, F25), plus a "Preview bounce" button wired to the second closure (R18). Changes apply to the next bounce because each bounce snapshots `LaunchTuning.current` when it starts (R17, F25).
- **Decoding.** `Bounce` gets its own tolerant Debug `init(from:)`, and `LaunchTuning.init(from:)` gains `bounce = try value(.bounce, s.bounce)`. An old preset therefore keeps the shipped bounce values (R19).
- **Guarding the decoder.** A forgotten decode line is not a compile error, so it is caught by a test instead: perturb every leaf of the encoded JSON, decode, and re-encode, and the result must be equal (per `encode-lessons-in-structure`).
- **Release.** Release still reads `shipped`, and everything new in the tuner stays `#if DEBUG`.

**Seams and test handles.** Requirements map to seams as follows:

| Seam | What runs there |
|---|---|
| `World` over `RecordingSystemActions` (model) | R1–R3, R9–R14 decisions, R16's window close |
| Pure `LauncherPlatformTests`, keyframes decoded as in `LaunchFlightTests` | `BounceRow` (R5, R6, R13), `BounceMotion` (R8, R15, R17's effects), `LaunchWatch.look` (the Accessibility answers), `LaunchTuning` decoding against the real 15-key old preset JSON (R19) |
| Real on this Mac, heavier and tagged | `LaunchWatch` against throwaway bundles scripted like P1 (window at finish, late window, splash, menu bar app, crash, missing executable) |
| Manual | lag (R7), feel (R8), sharpness (R4), clicks through (R16), a second display, the preview (R18) |

The handles a test needs:
- **Time:** `.ranOut` is pushed inline.
- **Lost or late signals:** the test withholds a report, or reports after the end.
- **Accessibility answers:** the pure `look` table.
- **Blocking AX calls:** the model never waits on one; they happen only in `LaunchWatch`, bounded by the 0.2 s timeout.

Existing tests are affected in two ways. The six positive `launchAnimations` expectations gain a running app (`makeRunning`), which makes them R2 tests. The R3 negatives gain `bounces.isEmpty`.

**Docs and source policy (Phase D).**
- `docs/architecture.md`, Concurrency:
  - The push list gains a launch's progress, while its bounce shows, and pointer moves.
  - New sentence: "Time passes only on Core Animation's clock: a launch bounce's deadlines are animations on its own layer, which exist only while it shows."
  - The animation bullet becomes Hypothesis A in words: per display frame never, per input event while the effect shows.
- `docs/architecture.md`, Privacy:
  - The list of Accessibility uses gains "to notice the first window of an app a gesture is launching, while its launch bounce shows".
  - A new pointer sentence.
  - "Without Accessibility" gains the 2 s ending for windows that show late.
  - The confinement sentence names two window files and pointer movement.
- `docs/domain-model.md`:
  - A new **Launch bounce** entry.
  - **Launch animation:** "every fired gesture plays its own" becomes "every gesture for a running app", plus "the end of a launch bounce".
  - **Launch animation setting:** it also covers the bounce.
- `Ports.swift`: the new members' contracts. The old "the completion is ignored" comment goes, because its reason no longer holds (`why.md` Change).
- `SourcePolicyTests`:
  - `Confined.onlyIn` becomes a `Set<String>`.
  - `AXUIElement` and `CGWindowList` may also appear in `LaunchWatch.swift`.
  - `mouseMoved` is confined to `BounceOverlay.swift` and `ClickTap.swift`, which only rewrites to it.
  - `addLocalMonitorForEvents` is confined to `BounceOverlay.swift`.

**Depth.**
- **What the model learns:** four members, a push, and three small enums.
- **What it does not see:** `openApplication`'s completion, two KVO observations, AX registration and its fallback, the window list, Core Animation deadlines and their fail-safe, a following panel, row geometry and re-flow, edge rules, two endings and the hand-off into the flight.
- **Call chain.** No member is a stage of another, so the model never calls two of them for one operation. The flow from gesture to pixels is `Launcher.fire` → `WorkspaceActions` → `BounceOverlay`, with the pure staging beside it.
- **Lifecycle path.** `LaunchWatch` → `WorkspaceActions` → `Launcher`.

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` · launch bounce vocabulary (new file) | `LaunchProgress`, `LaunchBounceEnding`, `LaunchBounceRules`, `LaunchStage` / `LaunchStep` |
| `LauncherCore` · `SystemActions` | `hasProcess`, `bringToFrontBouncing`, `limitLaunchBounce`, `endLaunchBounce`, `onLaunchProgress`; contract text |
| `LauncherCore` · `Launcher` | `bounces`, three-way `fire`, `progress(_:of:)`, push installed in `start()` |
| `LauncherPlatform` · `WorkspaceActions` | the members; `open(_:then:)`; owns `BounceOverlay` and `watches`; warms `hasProcess`; tuner's second preview |
| `LauncherPlatform` · `LaunchWatch` (new, confined) | completion → KVO → first window (AX observer, window-list fallback); pure `look` |
| `LauncherPlatform` · `BounceOverlay` (new, confined for pointer) | row panel, pointer monitors, deadlines, endings, DEBUG preview |
| `LauncherPlatform` · bounce staging (new, pure) | `BounceMotion`, `BounceRow` |
| `LauncherPlatform` · `LaunchOverlay`, `LaunchFlight` | `play(for:from:)`; `bitmap` and `makePanel` internal; `LaunchDisplay.containing` shared by flight and row |
| `LauncherPlatform` · `LaunchTuning`, `AnimationTuner` | nested `Bounce` with tolerant decoding; "Launch bounce" section with preview |
| Tests | `RecordingSystemActions` bounce surface; World `report`/`startProcess`; new model, staging, watch-decision and decoding suites; multi-file confinement |

#### Type sketch

```swift
// MARK: - LauncherCore · launch bounce vocabulary (new file)

/// What the adapter learned about a launch a gesture started, pushed while its launch bounce plays.
public enum LaunchProgress: Equatable, Sendable {
    /// macOS reports the app finished launching; menu bar apps too (key-value observation, F12, F13).
    case finishedLaunching
    /// A window of the app is on screen, on any display; a splash screen counts (R9).
    case windowShown
    /// macOS could not launch it, or its process ended before a window showed (R11).
    case wentNowhere
    /// The bounce reached its time limit: its cap, or the limit set once the app finished launching.
    case ranOut
}

/// How a launch bounce ends.
public enum LaunchBounceEnding: Equatable, Sendable {
    /// The launch animation, from wherever the icon is at that moment, even mid-jump (R9, R10, R12).
    case launchAnimation
    /// A fade in place, about 0.2 s, with no launch animation (R11).
    case quietFade
}

/// The two times R10 and R12 set, as durations: the model has no clock; the adapter keeps the time.
package enum LaunchBounceRules {
    /// No bounce lasts longer than this after its gesture fired (R12).
    package static let cap = Duration.seconds(10)
    /// Once its app finished launching, how long a bounce waits for a window (R10).
    package static let grace = Duration.seconds(2)
}

/// How far a bouncing launch has got, as far as its ending depends on it. A bounce that ended has no stage: the
/// model drops it, so a late report finds nothing and plays nothing (R12).
package enum LaunchStage: Equatable, Sendable {
    case startingUp
    case startedUp

    /// R9–R12 as one total table.
    package func next(after progress: LaunchProgress) -> LaunchStep {
        // TODO:
        // (_, .windowShown)                  -> .end(.launchAnimation)                         R9
        // (_, .wentNowhere)                  -> .end(.quietFade)                               R11
        // (.startingUp, .finishedLaunching)  -> .startUp(limit: LaunchBounceRules.grace)       R10
        // (.startedUp, .finishedLaunching)   -> .carryOn                                       a repeat changes nothing
        // (.startingUp, .ranOut)             -> .end(.quietFade)                               R11, R12: still starting
        // (.startedUp, .ranOut)              -> .end(.launchAnimation)                         R10 limit, or R12 cap
        fatalError("not implemented")
    }
}

package enum LaunchStep: Equatable, Sendable {
    case carryOn
    /// The stage becomes `.startedUp`, and the bounce now runs out within `limit` at the latest.
    case startUp(limit: Duration)
    case end(LaunchBounceEnding)
}

// MARK: - LauncherCore · SystemActions (additions; existing members unchanged except their docs)

@MainActor public protocol SystemActions: AnyObject {
    // ... bringToFront, registerLoginItem, runningApps, frontmostWindows, raiseWindows as today ...

    /// The apps the next launch animations and launch bounces may be for. (Text widened; behaviour as today.)
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// As today. Every call plays its own and never cancels, restarts or reuses one already playing; the model calls
    /// it for an app with a process. A launch bounce's ending plays the same animation inside the adapter.
    func playLaunchAnimation(for app: AppEntry)

    /// Whether macOS reports a process for the app now, still launching or finished, menu bar apps included; unlike
    /// `runningApps()`, not the ⌘-Tab list. Under 0.1 ms; reads only.
    func hasProcess(_ app: BundleID) -> Bool

    /// Bring to front for an app with no process, with its launch bounce. Opens the app exactly as `bringToFront`
    /// does, first, so the bounce never delays it; then, before returning, shows its icon bouncing just above the
    /// pointer, following it, in one row with any other bounce, newest on the right. Watches that launch and pushes
    /// `onLaunchProgress` for it until `endLaunchBounce`: `.ranOut` at `cap` at the latest. Reads the pointer,
    /// displays, Reduce motion and the tuning at the call; nothing it shows activates Trackpad Launcher, becomes key or
    /// receives a click. A bounce it cannot show runs out on the next main-actor turn. One bounce per app: for an app
    /// whose bounce still plays it only brings the app to front.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration)

    /// From now on the bounce runs out within `limit` at the latest, never later than its cap or an earlier limit.
    /// No-op for an app whose bounce is not playing.
    func limitLaunchBounce(of app: BundleID, to limit: Duration)

    /// Ends the bounce from where the icon is, stops watching its launch and pushes nothing more for it. The icon
    /// no longer follows the pointer. Idempotent: a no-op for an app whose bounce is not playing.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding)

    /// On the main actor, only for an app whose bounce plays: `.finishedLaunching` at most once, then at most one of
    /// the others before `endLaunchBounce`. Nothing for an app whose launch Trackpad Launcher did not start.
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)? { get set }
}

// MARK: - LauncherCore · Launcher (changes)

extension Launcher {
    // stored: @ObservationIgnored private var bounces: [BundleID: LaunchStage] = [:]
    //   The launches whose bounce plays. Written only by `fire` and `progress(_:of:)`: the one record of which
    //   bounces are live (R14); the adapter's row mirrors its commands.

    private enum Visual { case launchBounce, launchAnimation, none }

    /// R1–R3, R14. Reads `hasProcess` only when it decides something.
    private func visual(for app: AppEntry) -> Visual {
        // TODO:
        // guard settings.isLaunchAnimationOn else { return .none }                  R3: setting off
        // if bounces[app.bundleID] != nil { return .none }                          R14: keep the one bounce
        // return system.hasProcess(app.bundleID) ? .launchAnimation : .launchBounce  R1, R2
        fatalError("not implemented")
    }
    // fire(_:) and progress(_:of:) exactly as in Usage, call sites 1 and 2.
}

// MARK: - LauncherPlatform · WorkspaceActions (changes)

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    /// One per bounce playing, from `bringToFrontBouncing` to `endLaunchBounce`.
    private var watches: [BundleID: LaunchWatch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?

    public init() {
        overlay = LaunchOverlay()
        bounces = BounceOverlay(flights: overlay)
        // TODO: one `NSRunningApplication.runningApplications(withBundleIdentifier:)` now: the first in a process
        // costs 1.65 ms (F7), which must not land on a gesture.
        fatalError("not implemented")
    }

    public func bringToFront(_ app: AppEntry) { open(app) }

    public func hasProcess(_ app: BundleID) -> Bool {
        // TODO: !runningApplications(withBundleIdentifier: app.rawValue).filter { !$0.isTerminated }.isEmpty
        fatalError("not implemented")
    }

    public func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        // TODO:
        // let id = app.bundleID
        // guard watches[id] == nil else { return bringToFront(app) }
        // let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.onLaunchProgress?(id, $0) }
        // let watch = LaunchWatch(report: report); watches[id] = watch
        // open(app, then: watch.opened)                        // the app first: nothing below can delay it
        // bounces.start(app, cap: cap) { report(.ranOut) }
        fatalError("not implemented")
    }

    public func limitLaunchBounce(of app: BundleID, to limit: Duration) { bounces.limit(app, to: limit) }

    public func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) {
        watches.removeValue(forKey: app)?.stop()
        bounces.end(app, with: ending)
    }

    /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates. `opened`, when given,
    /// hears macOS's answer from any thread: the launched process, or nil when it could not launch it (F10) or the
    /// process ended before checking in (F11, pid −1).
    private func open(_ app: AppEntry, then opened: (@Sendable (pid_t?) -> Void)? = nil) {
        fatalError("not implemented")
    }

    #if DEBUG
    // showAnimationTuner(): AnimationTuner(preview: { overlay.play(for: finder) },
    //                                      previewBounce: { bounces.preview(finder, for: .seconds(3)) })
    #endif
}

// MARK: - LauncherPlatform · LaunchWatch (new; LaunchWatch.swift joins the AX / window-list confinement)

/// Watches one launch a gesture started, from macOS's answer to `openApplication` until `stop()`: the process's
/// finishing and ending by key-value observation, which macOS pushes for every kind of app (F9–F13), then one look
/// at its windows and, with Accessibility, its first window created later (F15–F17). Reports each fact at most once,
/// nothing after `stop()`, and holds nothing once stopped.
@MainActor final class LaunchWatch {
    private let report: @MainActor (LaunchProgress) -> Void
    private var process: NSRunningApplication?
    private var observations: [NSKeyValueObservation] = []
    private var windowObserver: AXObserver?
    private var hasFinished = false
    private var isStopped = false

    init(report: @escaping @MainActor (LaunchProgress) -> Void) { self.report = report }

    /// macOS's answer, from any thread. Hops to the main actor with only the pid.
    nonisolated func opened(_ pid: pid_t?) {
        Task { @MainActor [weak self] in self?.adopt(pid) }
    }

    /// Invalidates the observations and removes the window observer's run-loop source. Idempotent.
    func stop() { fatalError("not implemented") }

    private func adopt(_ pid: pid_t?) {
        // TODO:
        // guard !isStopped
        // guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        //     else { return wentNowhere() }
        // observe \.isTerminated        [.initial, .new]: true -> Task { @MainActor } -> wentNowhere()
        // observe \.isFinishedLaunching [.initial, .new]: true -> Task { @MainActor } -> finished(pid)
        fatalError("not implemented")
    }

    private func finished(_ pid: pid_t) {
        // TODO:
        // guard !isStopped, !hasFinished; hasFinished = true; report(.finishedLaunching)
        // registration = AXObserverCreate(pid, callback) + AXObserverAddNotification(app element,
        //     kAXWindowCreatedNotification, refcon: Unmanaged(self)) mapped: .success -> .registered (source added
        //     to the main run loop), .apiDisabled -> .noAccess, anything else -> .notAnswering
        // windows = registration == .registered ? count of kAXWindowsAttribute (bounded by the 0.2 s timeout)
        //                                       : count of window-list entries of pid, on screen, layer 0..<status
        // switch Self.look(registration, windows: windows)
        //     .shown -> report(.windowShown); .watching -> wait; .blind -> drop the observer, nothing more (R10 ends it)
        // callback (C, main run loop): MainActor.assumeIsolated { guard !isStopped; report(.windowShown) }
        fatalError("not implemented")
    }

    private func wentNowhere() {
        // TODO: guard !isStopped; report(.wentNowhere)
        fatalError("not implemented")
    }

    enum Registration: Equatable { case registered, notAnswering, noAccess }
    enum Look: Equatable { case shown, watching, blind }

    /// One look at a launching app's windows when it finished launching. Pure.
    /// (.registered, >0) .shown · (.registered, 0) .watching · (_, >0) .shown · (_, 0) .blind
    nonisolated static func look(_ registration: Registration, windows: Int) -> Look { fatalError("not implemented") }
}

// MARK: - LauncherPlatform · BounceOverlay (new; BounceOverlay.swift is the only file observing pointer movement)

/// Shows launch bounces. Every bouncing icon sits in one row above the pointer, in one display-sized, click-through
/// panel on the pointer's display, re-framed when the pointer crosses to another display. NSEvent monitors for moves
/// and drags exist from the first bounce until the last stops following; they read only where the pointer is.
/// Core Animation plays the bounce. Each bounce carries its own deadlines (1→1 opacity animations on its clock layer):
/// they pass on the render server's clock and die with the bounce. An ending lifts the icon out of the row into its own
/// panel. Once the row is empty and the last ending's completion has run, nothing of ours runs.
@MainActor final class BounceOverlay {
    private let flights: LaunchOverlay
    /// Oldest first: the row's order, newest on the right (R13).
    private var row: [Bouncing] = []
    /// The row's panel and the display it covers; nil while the row is empty.
    private var stage: (panel: NSPanel, host: CALayer, display: LaunchDisplay)?
    /// Quiet-fade panels, kept until their fade's completion (AppKit keeps closed panels in its window list).
    private var fading: Set<NSPanel> = []
    private var monitors: [Any] = []

    private struct Bouncing {
        let app: AppEntry
        /// `LaunchTuning.current` when it started: the tuner restores its override right after a preview (F25).
        let tuning: LaunchTuning
        let reduceMotion: Bool
        /// Positioned at the icon's rest; follows the pointer.
        let slot: CALayer
        /// Anchor at its bottom centre; plays `BounceMotion` forever.
        let icon: CALayer
        /// Zero-size; carries the deadlines.
        let clock: CALayer
        var deadlines: [Deadline]
        /// Called once, by the first deadline to pass; nil after.
        var ranOut: (@MainActor () -> Void)?
    }

    init(flights: LaunchOverlay) { self.flights = flights }

    func start(_ app: AppEntry, cap: Duration, ranOut: @escaping @MainActor () -> Void) {
        // TODO:
        // guard !row.contains { $0.app.bundleID == app.bundleID } else { return }
        // snapshot tuning, Reduce motion (system || tuning.forceReduceMotion), displays, NSEvent.mouseLocation
        // guard let layout = BounceRow(count: row.count + 1, pointer:, among:, side: iconSide, tuning: tuning.bounce),
        //       let stage = stage(on: layout.display)       // LaunchOverlay.makePanel(frame: display.frame), ordered in
        //     else { Task { @MainActor in ranOut() }; return }  // nothing to show: runs out next turn
        // one CATransaction, actions disabled: slot at layout.rests.last; icon (side, bitmap from flights.bitmap,
        //     contentsScale, trilinear) + BounceMotion(...).animations(); clock + deadline(cap) -> runOut(app);
        //     slide the others to layout.rests.dropLast() (BounceRow.slide)
        // row.append(...); if row.count == 1 { follow() }
        fatalError("not implemented")
    }

    func limit(_ app: BundleID, to limit: Duration) {
        // TODO: add a deadline of `limit` to that bounce's clock; the cap stays, so a later limit never extends it.
        fatalError("not implemented")
    }

    func end(_ app: BundleID, with ending: LaunchBounceEnding) {
        // TODO:
        // guard let index = row.firstIndex(where: app) else { return }      // idempotent
        // let bouncing = row.remove(at: index); bouncing.deadlines.forEach { $0.isCancelled = true }
        // let frame = the icon's presentation frame in global coordinates (presentation layer → host → panel origin)
        // one outer CATransaction:
        //     .launchAnimation: flights.play(for: bouncing.app, from: frame.centre)    // R9; Reduce motion fades in place
        //     .quietFade: own panel at frame ∩ display, a layer frozen at the presentation transform and opacity,
        //                 BounceMotion.quietFade(from:), closed from its completion       // R11
        //     bouncing.slot.removeFromSuperlayer(); slide the rest to their new rests       // R13, 0.2 s
        // if row.isEmpty { unfollow(); close the row panel }
        fatalError("not implemented")
    }

    #if DEBUG
    /// R18: bounces `app` at the pointer for `duration`, then ends it as a window showing would.
    func preview(_ app: AppEntry, for duration: Duration) {
        start(app, cap: duration) { [weak self] in self?.end(app.bundleID, with: .launchAnimation) }
    }
    #endif

    private func follow() {
        // TODO: global + local NSEvent monitors for [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
        //     .otherMouseDragged]; each handler (MainActor.assumeIsolated) -> moved(to: NSEvent.mouseLocation); the
        //     local one returns its event unchanged.
        fatalError("not implemented")
    }

    private func unfollow() { fatalError("not implemented") }   // removes both monitors; idempotent

    private func moved(to pointer: CGPoint) {
        // TODO: layout = BounceRow(count: row.count, ...); re-frame the panel if layout.display changed (R7);
        //     one CATransaction, actions disabled: each slot.position = layout rest in panel coordinates, or with
        //     tuning.bounce.trailing > 0 an ease-out from its presentation position over `trailing`.
        fatalError("not implemented")
    }

    private func runOut(_ app: BundleID) {
        // TODO: guard let i, let ranOut = row[i].ranOut; row[i].ranOut = nil; ranOut()
        fatalError("not implemented")
    }

    /// A deadline on the render server's clock. A cancelled one reports nothing. A stop the system causes
    /// (`finished == false`, not cancelled) reports as passed, so no bounce can outlive its cap.
    @MainActor private final class Deadline: NSObject, CAAnimationDelegate {
        var isCancelled = false
        let passed: @MainActor () -> Void
        init(passed: @escaping @MainActor () -> Void) { self.passed = passed }
        nonisolated func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            MainActor.assumeIsolated { if !isCancelled { passed() } }
        }
    }
}

// MARK: - LauncherPlatform · bounce staging (new, pure, tested like LaunchFlight)

/// Where the bouncing icons rest for a pointer: one row, newest on the right, `spacing` apart, centred on the
/// pointer's tip plus `offset`, bottoms `gap` above the tip (R5, R13). It slides sideways just enough to stay on the
/// pointer's display and never moves down, so the top edge cuts it (R6). Pixel-snapped to the display.
struct BounceRow: Equatable {
    let display: LaunchDisplay
    /// Each icon's bottom centre, global y-up, in row order.
    let rests: [CGPoint]

    /// Nil with no display. The display is AppKit's rule for the pointer, shared with the flight
    /// (`LaunchDisplay.containing(_:among:)`).
    init?(count: Int, pointer: CGPoint, among displays: [LaunchDisplay], side: CGFloat, tuning: LaunchTuning.Bounce) {
        fatalError("not implemented")
    }

    /// The re-flow: an additive position animation from `old − new` to zero over `duration`, easing out; nil when the
    /// rest did not move. Additive, so pointer moves during the slide compose with it.
    static func slide(from old: CGPoint, to new: CGPoint, over duration: CFTimeInterval) -> CABasicAnimation? {
        fatalError("not implemented")
    }
}

/// One launch bounce's motion, which Core Animation repeats forever. A Dock-like jump on `transform` about the
/// icon's bottom centre: up for `timeUp`, easing out to `height`; down for `timeDown` with gravity; then `rest` on the
/// ground, with the optional area-keeping `squash`. Under Reduce motion, an opacity pulse in place instead
/// (R8, R15). 240 samples a second. It starts at rest, so the first jump starts at once.
struct BounceMotion {
    init(tuning: LaunchTuning.Bounce, side: CGFloat, reduceMotion: Bool) { fatalError("not implemented") }
    /// timeUp + timeDown + rest, or the pulse period.
    var period: CFTimeInterval { fatalError("not implemented") }
    /// `repeatCount = .infinity`, `calculationMode = .linear`, easing baked into the samples, as in `LaunchFlight`.
    func animations() -> [CAKeyframeAnimation] { fatalError("not implemented") }
    /// The quiet end: opacity from `opacity` to 0 over `tuning.fadeOut`, easing out (R11).
    func quietFade(from opacity: Float) -> CABasicAnimation { fatalError("not implemented") }
}

// MARK: - LauncherPlatform · LaunchOverlay / LaunchFlight (small changes)

extension LaunchOverlay {
    /// As `play(for:)`, staged at `start` instead of the pointer: a bounce's ending, from wherever its icon is (R9).
    func play(for app: AppEntry, from start: CGPoint) { fatalError("not implemented") }
    // bitmap(for:scale:) and static makePanel(frame:) become internal: one icon cache and one panel recipe.
}

extension LaunchDisplay {
    /// AppKit's rule for the pointer's display, else the nearest; moved here from `LaunchFlight.display(for:among:)`.
    static func containing(_ point: CGPoint, among displays: [LaunchDisplay]) -> LaunchDisplay? {
        fatalError("not implemented")
    }
}

extension Duration {
    /// For Core Animation, which counts in seconds.
    var seconds: CFTimeInterval { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}

// MARK: - LauncherPlatform · LaunchTuning (additions)

extension LaunchTuning {
    // stored: var bounce = Bounce()

    /// Every number that shapes a launch bounce. The defaults are the shipped bounce.
    struct Bounce: Equatable, Sendable {
        /// Points the icon jumps, about half the icon (R8).
        var height: Double = 30
        var timeUp: Double = 0.30
        var timeDown: Double = 0.30
        /// Seconds on the ground between jumps.
        var rest: Double = 0.10
        /// Share of its height the icon loses on landing, widening to keep its area. 0 = none (R8).
        var squash: Double = 0
        /// Points between the pointer's tip and the icon's bottom at rest (R5).
        var gap: Double = 8
        /// Sideways from the tip to the row's centre (R5: none).
        var offset: Double = 0
        /// Seconds the row takes to catch up with the pointer. 0 = glued to it (R7).
        var trailing: Double = 0
        /// Points between icons in the row (R13).
        var spacing: Double = 12
        /// Seconds the others take to slide when one ends (R13).
        var slide: Double = 0.2
        /// Seconds of the quiet fade (R11).
        var fadeOut: Double = 0.2
        /// Reduce motion: the pulse's dimmest opacity, and its period (R15).
        var pulseLow: Double = 0.5
        var pulsePeriod: Double = 1.4
    }
}

#if DEBUG
extension LaunchTuning.Bounce: Codable {
    /// Keys missing from an older save keep their shipped values: one `x = try value(.x, s.x)` line per field, as
    /// `LaunchTuning`'s. `LaunchTuning.init(from:)` gains `bounce = try value(.bounce, s.bounce)` (R19).
    init(from decoder: any Decoder) throws { fatalError("not implemented") }
}
// AnimationTuner.init(preview:previewBounce:). TunerView gains, before the presets:
//   Section { knob("Jump height", \.bounce.height, 0...80, step: 1, unit: "pt") ... one knob per field above ...
//             Button("Preview bounce") { previewBounce() } }
//   header: { Text("Launch bounce") }
//   footer: { Text("Applies from the next bounce. Preview bounces Finder's icon for 3 s, then floats it away.") }
#endif

// MARK: - Tests · RecordingSystemActions (additions)

extension RecordingSystemActions {
    // stored: var processes: Set<BundleID> = []
    //   Processes ⌘-Tab does not show: menu bar apps, apps still starting from the Dock.
    // stored: private(set) var bounces: [Bounce] = []
    //   The bounces playing, in start order: the row, newest last.
    // stored: private(set) var bounceEndings: [BounceEnd] = []
    //   Every endLaunchBounce call, in order, so a double end shows.
    // stored: var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?

    struct Bounce: Equatable {
        let app: AppEntry
        let cap: Duration
        var limit: Duration? = nil
    }

    struct BounceEnd: Equatable {
        let app: BundleID
        let ending: LaunchBounceEnding
    }

    /// Derived, never synced: a ⌘-Tab app and the frontmost app have a process too.
    func hasProcess(_ app: BundleID) -> Bool {
        // TODO: processes.contains(app) || frontmost?.bundleID == app || running.contains { $0.bundleID == app }
        fatalError("not implemented")
    }

    /// Records the bring to front, then the bounce, in that order.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration) { fatalError("not implemented") }
    /// Lowers the limit, never raises it.
    func limitLaunchBounce(of app: BundleID, to limit: Duration) { fatalError("not implemented") }
    /// Records every call; removes a playing bounce.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) { fatalError("not implemented") }
    /// The launch reports `progress` inline, as the real adapter pushes it on the main actor. A test withholds a
    /// report by not calling this, delivers one late by calling it after the end, and passes time with `.ranOut`.
    func report(_ progress: LaunchProgress, for app: BundleID) { onLaunchProgress?(app, progress) }
}
// World: report(_:for name:), startProcess(_ name:). SourcePolicyTests: Confined(token:onlyIn: Set<String>, rule:).
```

### Synthesis decision

### Tradeoffs accepted

- **Time from Core Animation.** We accept time borrowed from the render server's clock, which may stretch across display sleep, in exchange for three things: no timer, no change to the ban, and deadlines that cannot outlive the bounce that carries them. A stop the system causes counts as the deadline passing, so no model record can be stranded.
- **Four members and a first push on `SystemActions`, not a new port.** We accept a larger port in exchange for an unchanged `Launcher` initialiser, World and composition root. The bounce is one more effect macOS performs, plus the reports about it (plan 004's "no new port" reasoning).
- **Bring-to-front merged into `bringToFrontBouncing`.** "Bring to front first" becomes an adapter contract that the model's tests cannot observe. In exchange, the model cannot get the order wrong, and the watch is bound to the `openApplication` call it needs.
- **No Accessibility registration retry.** We accept that an app whose Accessibility server lags at finishing (F16, runs 1 and 8) and that opens its first window *later* waits out the 2 s limit. In exchange, the polling ban holds literally. The window-list look at finishing still catches the lagging apps the probes saw, because each made its window while finishing.
- **Code on every pointer event while a bounce shows** (about 0.04 ms per move, up to about 120 per second). We accept it in exchange for gluing the icon to the pointer with no display-driven code, and nothing runs once the last bounce stops following.
- **A display-sized panel re-framed on display crossings.** We accept a larger window and a possible one-frame hitch at a crossing, in exchange for the top-edge cut, the rule that nothing spills onto a display above, and moves that are layer-only.
- **Endings lifted into their own panels.** We accept two windows changing in one transaction, a possible one-frame overlap. In exchange, the hand-off reuses the real launch animation unchanged, and an ending never moves when the row's panel re-frames.
- **The flight's tuning at hand-off.** A bounce snapshots its own tuning, but the flight at its end reads the live flight tuning. That only matters in Debug, and only when knobs change mid-bounce.
- **A process read before the haptic.** We accept a read of under 0.1 ms, warmed at launch, before the pulse, in exchange for a `fire` that decides first and then acts in today's order.
- **Six existing launch-animation tests gain a running app.** They now state R2's precondition, which was implicit before.
- **Identity by bundle ID.** We accept that a running copy of the same bundle elsewhere on disk reads as running and gets the launch animation, in exchange for assignment identity matching (F3).

### Alternatives considered

- **Adapter-owned endings: a fire-and-forget `playLaunchBounce` plus one `onBounceEnded` push.**
  - Its interface is smaller, and policy sits beside the signals it uses.
  - It moves R9–R12 out of `Launcher`, breaking "one model owns every decision" and plan 005's policy-free adapter.
  - It still needs a mirrored live set for R14, kept in sync by a push, so it exposes a sync contract while hiding policy the requirements name.
  - Lost.
- **A deadline port backed by a dispatch source.**
  - It is semantically honest about time.
  - It needs `makeTimerSource` or `asyncAfter` unbanned and the architecture rewritten.
  - Its deadlines could outlive a bounce unless every path cancels them, where a deadline on the bounce's layer dies with it.
  - It exposes a general clock to the model where only bounce-scoped time is needed. Lost.
- **The bounce as observable model state rendered by a `LauncherUI` presenter, the switcher pattern.**
  - `Observations` delivers on a later turn, which breaks R1's same-turn reading.
  - `LauncherUI` cannot reach `LaunchFlight` or the icon cache for the hand-off.
  - Lost.
- **One small panel per bounce, moved with `setFrameOrigin`.**
  - It is cheap per move (F21).
  - Each move would have to recompute frame ∩ display for the top-edge cut and keep the clip and the layer in step across two systems.
  - Rows would be several windows moving independently.
  - Lost to one display-sized panel with layers moved inside it.
- **The adapter starting the 2 s limit by itself when it observes finishing.**
  - It saves `limitLaunchBounce`.
  - It puts R10's rule ("2 s after finishing") in the adapter, and leaves the 2 s untestable at the model seam.
  - Lost.

### Open questions and risks

- **O1.** Without Accessibility, a window that opens *after* its app finished launching can end the bounce only through R10's 2 s rule, so R9's 50 ms cannot be met for it. Windows already up at finishing are still caught by the window-list look. Do you accept this degradation, written into the Privacy section's "without Accessibility" sentence?
- **AX lag at finishing.** With Accessibility on, registration can lag finishing by up to 10 ms (F16). The design accepts a 2 s ending for an app that both lags and opens its first window later. Should Phase B instead add a bounded retry, three tries on the bounce's own deadline within about 150 ms? If so, a probe of the adapter as built, using the P1 technique, should first show how often that case occurs.
- **D2.** Do you sign off on observing pointer movement (position only, only while a bounce shows, recorded nowhere) as a new Privacy line? It supersedes plan 002 R9's pointer clause for this purpose.
- **D1.** Is the reading written into `docs/architecture.md` ("never per display frame; per input event while the effect shows") the rule you want to hold for later features too?
- **R7.** The icon trails the hardware cursor by the monitor's delivery delay (median 3.5 ms) plus up to one display frame. Is that "no lag the user can see"? Only drawing the cursor itself would beat it. This is a manual check.
- **D3 / O4.** An Electron or Chromium app that creates a hidden window at startup, or any app whose window opens on another Space, could report `kAXWindowCreated` early and float away sooner than R9 or R10 intend. Is that acceptable, pending cold-launch checks of Slack, Figma and Chrome during Verify?
- **O8.** A hung launching app can block the main actor for up to the 0.2 s messaging timeout during the one window look at finishing. Following pauses for that time, but the bounce itself keeps playing on the render server. Is that acceptable off the gesture path?
- **The hand-off frame.** The swap from the row's panel to the ending's panel is one transaction across two windows. Should Verify specifically look for a blink or a doubled icon at 120 Hz?
- **O6.** Re-framing the row's panel on a second display, with "Displays have separate Spaces" on, is unprobed here (F22). Who can check it on a two-display Mac?
- **Local monitor and the tuner.** The local monitor sees moves only over our windows that accept mouse-moved events. Should the tuner panel set `acceptsMouseMovedEvents` so R18's preview follows the pointer over the tuner?
- **Display sleep, screen lock and the Gatekeeper prompt (O5).** A bounce may outlast 10 s of wall time across a display sleep, because its deadlines are on the render server's clock. During a pending Gatekeeper prompt it runs to the cap (R11 accepts this). Is that acceptable?
- **R4.** Keyframed motion places the icon at fractional pixels between samples, as the launch flight already does. Is a manual sharpness check enough?

### Next implementation step

Start with the model. Add the launch bounce vocabulary, the four `SystemActions` members and the push, and `RecordingSystemActions`' bounce surface. Then write the World tests for R1–R3 and R9–R14 against the three-way `fire` and `progress(_:of:)`, before any platform code.
