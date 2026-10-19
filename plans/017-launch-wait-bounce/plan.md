# Plan: Launch bounce

## Problem statement

A gesture for an app that is not running launches it. A cold launch takes 1 to 4 seconds, sometimes longer. Today the launch animation plays at once and is gone within a third of a second. Then the only feedback until the app's window shows is the Dock's own bounce, and that is often hidden, on another display, or far from the pointer. The user cannot tell whether the app is still coming or the gesture did nothing. They tap again, or reach for the Dock.

## Solution

When a gesture fires for an app that is not running, its icon bounces above the pointer instead. The bounce feels like the Dock's: the icon jumps up, falls back with gravity, and jumps again. The icon is glued to the pointer, so it stays in view wherever the user moves it. When the app's window shows, the bouncing icon plays the launch animation from wherever it is and floats away. If the app never gets going, the icon fades out quietly instead.

Apps that are already running keep the launch animation exactly as today.

The debug animation tuner gains a launch bounce section, so the bounce's feel can be tried and tweaked live.

## Requirements

### R1. The launch bounce plays for a gesture that launches its app
The launch bounce MUST play when a gesture fires for an assigned, present target app that is not running, while the launch animation setting is on. Not running means macOS reports no process for the app when the gesture fires. An app already launching from the Dock or Finder therefore counts as running and gets the launch animation (R2). The bounce MUST appear no later than the haptic feedback. It MUST replace the launch animation for that gesture: no launch animation plays when the gesture fires.

#### Scenario: Assigned app that is not running
- **GIVEN** the 2-finger gesture is assigned to Figma, and Figma is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** Figma's icon appears above the pointer and starts bouncing at once, with the gesture haptic, no icon floats up, and Figma launches

### R2. Running apps keep the launch animation
A gesture whose target app is already running MUST play the launch animation exactly as today, with no launch bounce, unless that app's launch bounce is still playing (see R14). This holds whether or not the app has a window.

#### Scenario: Running app
- **GIVEN** the 1-finger gesture is assigned to Arc, and Arc is running
- **WHEN** the user makes the 1-finger gesture
- **THEN** Arc's icon floats up from the pointer as today, and no icon bounces

#### Scenario: Running app with no window
- **GIVEN** the 3-finger gesture is assigned to Mail, Mail is running, and all its windows are closed
- **WHEN** the user makes the 3-finger gesture
- **THEN** the launch animation plays, and no icon bounces

#### Scenario: App launching from the Dock
- **GIVEN** the 2-finger gesture is assigned to Figma, and the user opened Figma from the Dock a second ago and it is still starting up
- **WHEN** the user makes the 2-finger gesture
- **THEN** Figma's icon floats up from the pointer as the launch animation, and no icon bounces

### R3. Only gestures bounce
A swipe, a window swipe and a swap MUST never play the launch bounce. Nothing else plays it either: an unassigned gesture, a missing assignment, gestures inactive, or the launch animation setting off.

#### Scenario: Launch animation setting off
- **GIVEN** the launch animation setting is off, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** no icon appears at any point, the gesture haptic plays, and Figma launches

#### Scenario: Missing assignment
- **GIVEN** the 4-finger gesture is assigned to Spotify, and Spotify has been moved to the Trash
- **WHEN** the user makes the 4-finger gesture
- **THEN** no icon appears

### R4. The bouncing icon is the target app's icon, the same size as the launch animation's icon
The bouncing icon MUST be the target app's own icon, the one Finder shows for it, the same size as the launch animation's icon: 60 × 60 points as shipped. It MUST show no blur or pixelation at any point of the bounce.

#### Scenario: Retina display
- **GIVEN** the pointer is on a Retina display, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** a 60-point Figma icon bounces, sharp at every height

### R5. The icon rests just above the pointer
This applies to a single bouncing icon, except as the edge-of-display rule (R6) and the row rule (R13) say. At rest, between jumps, the icon MUST sit centred horizontally on the pointer's tip, its bottom edge 8 points above the tip. It MUST jump upward from there and never cover the pointer.

#### Scenario: Resting spot
- **GIVEN** the pointer's tip is at the middle of the display
- **WHEN** a launch bounce starts
- **THEN** the icon's horizontal centre is on the tip, and at rest its bottom edge is 8 points above it

### R6. The icon stays above the pointer at the display's edges
The icon, or the whole row of icons (R13), MUST always rest and bounce above the pointer, wherever the pointer is. Near the top edge, the part that does not fit MUST be cut off by the edge; the icon MUST NOT move below the pointer or onto another display. Near the left or right edge, it MUST slide sideways just enough to stay entirely on the pointer's display.

#### Scenario: Pointer at the top of the display
- **GIVEN** the pointer rests on the menu bar
- **WHEN** a launch bounce starts
- **THEN** the icon bounces above the pointer, cut off by the top edge of the display, and never below the pointer

#### Scenario: Pointer at the right edge
- **GIVEN** the pointer's tip is 10 points from the right edge of its display
- **WHEN** a launch bounce starts
- **THEN** the icon is entirely on the display, its right edge at the display's edge

### R7. The icon follows the pointer
While it bounces, the icon MUST move with the pointer on every frame, with no lag the user can see. With the shipped tuning it MUST not trail behind the pointer; the tuner may set trailing for experiments. It MUST follow the pointer onto another display.

#### Scenario: Moving the pointer while the app launches
- **GIVEN** Figma's icon is bouncing
- **WHEN** the user moves the pointer across the screen and onto a second display
- **THEN** the icon stays just above the pointer the whole way, and keeps bouncing on the second display

### R8. The bounce feels like the Dock's
Each bounce MUST rise quickly to about half the icon's height, slow at the top, and fall back with gravity, about 0.7 seconds per bounce, repeated until the bounce ends. With the shipped tuning the icon MUST keep its size and shape while it bounces; the tuner may set squash for experiments.

#### Scenario: Side by side with the Dock
- **GIVEN** the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the gesture, and then opens a second app that is not running from the Dock
- **THEN** both icons bounce at a similar height and rhythm

### R9. The bounce ends when the app's window shows
When a window of the launching app first shows on screen, on any display, the bounce MUST end within 50 milliseconds. A splash screen counts as a window. The icon MUST then play the launch animation, starting from wherever it is at that moment, even mid-jump. From then on it no longer follows the pointer. Two exceptions: without the Accessibility permission, or when the app does not answer Accessibility while it starts up, a window that shows only after the app finished starting up ends the bounce through R10's 2-second rule instead.

#### Scenario: Window shows mid-jump
- **GIVEN** Figma's icon is bouncing and is near the top of a jump
- **WHEN** Figma's window shows
- **THEN** the icon floats away from that spot, and moving the pointer afterwards does not move it

#### Scenario: Splash screen
- **GIVEN** a gesture is launching an app that shows a splash screen before its main window
- **WHEN** the splash screen shows
- **THEN** the bounce ends with the launch animation

### R10. The bounce ends when the app starts up without a window
When the app has finished starting up and no window of it has shown within 2 seconds after that, the bounce MUST end with the launch animation, or earlier at the 10-second cap (R12). This covers menu bar apps, apps that open no window, and apps whose window opens on another Space.

#### Scenario: Menu bar app
- **GIVEN** the 5-finger gesture is assigned to a menu bar app that is not running
- **WHEN** the user makes the 5-finger gesture
- **THEN** the icon bounces until 2 seconds after the Dock stops bouncing its icon, then floats away

### R11. The bounce fades quietly when the launch goes nowhere
The bounce MUST end without the launch animation when the app fails to launch, quits before a window shows, or is still starting up at the 10-second cap (R12). The icon MUST then fade out in place within about 0.2 seconds.

#### Scenario: App fails to launch
- **GIVEN** the 2-finger gesture is assigned to an app that macOS refuses to open
- **WHEN** the user makes the 2-finger gesture
- **THEN** the icon bounces until macOS reports the failure, then fades out where it is, with no float-up

#### Scenario: App crashes during startup
- **GIVEN** a gesture is launching an app that crashes while starting up
- **WHEN** the app quits
- **THEN** the icon bounces until that moment, then fades out where it is, with no float-up

#### Scenario: App still starting after 10 seconds
- **GIVEN** a gesture is launching an app that takes 15 seconds to start up
- **WHEN** 10 seconds have passed since the gesture fired
- **THEN** the icon fades out where it is, and the app's window still shows when it is ready

#### Scenario: First launch of a downloaded app
- **GIVEN** a gesture is launching a downloaded app for the first time, and macOS asks whether the user is sure they want to open it
- **WHEN** the user has not answered 10 seconds after the gesture fired
- **THEN** the icon keeps bouncing until then, because that dialog is not the app's window, and then fades out where it is; this is accepted

### R12. No bounce lasts longer than about 10 seconds
No icon MUST bounce longer than about 10 seconds after its gesture fired. At the cap, if the app has finished starting up, the icon MUST play the launch animation. If the app is still starting up, the icon MUST fade out quietly (R11). A window that shows after the bounce has ended MUST play nothing.

#### Scenario: App started up late without a window
- **GIVEN** a gesture is launching a menu bar app that finishes starting up 9 seconds after the gesture fired
- **WHEN** 10 seconds have passed since the gesture fired
- **THEN** the icon floats away from where it is

### R13. Several launches bounce side by side
Each gesture that launches a different app MUST get its own bouncing icon. Bouncing icons MUST sit in one row centred above the pointer, newest on the right, 12 points apart. When one ends, the others MUST slide to their new places over about 0.2 seconds. Each ends on its own app's events.

#### Scenario: Two cold launches
- **GIVEN** the 1-finger gesture is assigned to Xcode and the 2-finger gesture to Slack, neither running
- **WHEN** the user makes the 1-finger gesture, then the 2-finger gesture while Xcode's icon still bounces
- **THEN** Xcode's and Slack's icons bounce side by side above the pointer, Slack's on the right

#### Scenario: One of two ends
- **GIVEN** Xcode's and Slack's icons are bouncing side by side
- **WHEN** Slack's window shows first
- **THEN** Slack's icon floats away, and Xcode's icon moves to the centre above the pointer and keeps bouncing

### R14. Firing the same app again keeps one bounce
A gesture for an app whose launch bounce is still playing MUST NOT start a second bounce or restart the first. The gesture haptic MUST play, and the gesture's usual bring-to-front action MUST happen; for a launching app it asks macOS to open the app again, which changes nothing visible. No launch animation plays for that repeated gesture.

#### Scenario: Impatient second tap
- **GIVEN** Figma's icon is bouncing
- **WHEN** the user makes Figma's gesture again
- **THEN** the gesture haptic plays, one Figma icon keeps bouncing without a jump in its rhythm, and Figma's window shows when it is ready

#### Scenario: Menu bar app started up, still bouncing
- **GIVEN** a menu bar app has started up, and its icon is still bouncing
- **WHEN** the user makes its gesture again
- **THEN** no icon floats up, and the one icon keeps bouncing

### R15. Reduce motion pulses instead of bouncing
With the system's Reduce motion setting on, the icon MUST stay at its resting spot above the pointer and gently pulse its opacity instead of bouncing. It MUST still follow the pointer. Every ending MUST fade it out in place, as the launch animation does under Reduce motion.

#### Scenario: Reduce motion on
- **GIVEN** Reduce motion is on, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture and Figma's window later shows
- **THEN** Figma's icon pulses above the pointer without moving up or down, then fades out in place when the window shows

### R16. The bounce never gets in the way
The bouncing icon MUST never take focus or receive clicks. Clicks, scrolling and every gesture, swipe, window swipe and swap MUST work exactly as when no icon shows. The launcher window MUST close on the gesture as today.

#### Scenario: Clicking under the icon
- **GIVEN** Figma's icon is bouncing above the pointer
- **WHEN** the user moves the pointer up so the icon's area covers a button, and clicks the button
- **THEN** the button receives the click

### R17. The animation tuner can tweak the bounce
The bounce's feel cannot be pinned down in numbers up front, so the debug tuner lets it be tried live. Debug builds' animation tuner MUST have a launch bounce section. It MUST offer a control for each of: the jump height, the time up, the time down, the rest between bounces, the squash on landing (none by default), the resting gap above the pointer, the horizontal offset from the pointer, trailing behind the pointer (none by default), the gap between icons, and the fade out on a quiet end. Changes MUST apply to the next launch bounce. Release builds MUST play the shipped bounce and show no tuner.

#### Scenario: Trying a higher jump
- **GIVEN** the tuner is open in a Debug build, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user raises the jump height and makes the 2-finger gesture
- **THEN** Figma's icon bounces higher above the pointer

### R18. The tuner previews the bounce
The tuner's launch bounce section MUST have a preview button. It MUST bounce Finder's icon at the pointer for 3 seconds, then end it as a window showing would.

#### Scenario: Previewing the bounce
- **GIVEN** the tuner is open in a Debug build
- **WHEN** the user presses the preview button
- **THEN** Finder's icon bounces above the pointer for 3 seconds, then floats away

### R19. Presets carry the bounce knobs
Tunings and presets MUST save and load the bounce knobs together with the existing ones.

#### Scenario: Older saved preset
- **GIVEN** a preset saved before the launch bounce existed
- **WHEN** the user loads it
- **THEN** the launch animation knobs take the preset's values, and the bounce knobs keep the shipped values

## Non-goals

- **A bounce for running apps without a window.** Bringing such an app to front opens a window almost at once, so a bounce would only flash.
- **A bounce for swipes, window swipes and swaps.** They only reach running apps, so they never launch one.
- **A separate setting for the bounce.** The launch animation setting covers both; one switch keeps the window simple.
- **Bouncing for launches Trackpad Launcher did not start.** The bounce answers a gesture. A launch from the Dock, Spotlight or Finder has no gesture to answer. A gesture made while such a launch is starting finds the app running (R1) and plays the launch animation.
- **Suppressing the Dock's own bounce.** It is macOS's to show. Both bouncing for the same launch does no harm.
- **A sound.** Gesture sounds are still deferred for the whole product.
- **Showing progress or an estimated time.** macOS reports no launch progress; the bounce only says "still coming".

## Design

### Problem

A fired gesture must choose, in the same synchronous main-actor turn as its haptic, between the launch bounce, the launch animation and nothing. A bounce then keeps an icon alive for up to 10 s, glued to the pointer, and ends it on events about another app's process, or on time. Today's shape resists this in five places:

- `Launcher.fire` never asks whether its app runs. The only read it has, `runningApps()`, is the ⌘-Tab list, which leaves out menu bar apps. And for 60–440 ms after our own `openApplication`, macOS lists no process at all (grounding F3, F7). So R14 cannot rest on any read: it needs the model's own record of live bounces.
- The model has no clock. The source scan bans `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource` and display links by substring, in comments and `#if DEBUG` code too (F23).
- `playLaunchAnimation` is fire-and-forget and "never cancels" (F4).
- `SystemActions` has no push. `bringToFront` drops `openApplication`'s completion, the only way to learn that a launch failed (F2, F10).
- The Accessibility element API and the window list are confined to `FrontmostAppWindows.swift` (F18).

The probes fix what the lifecycle can lean on:

- The completion arrives off the main thread when the app checks in. A launch that went nowhere answers with an error or a terminated app (F9–F11).
- KVO on `isFinishedLaunching` and `isTerminated` pushes for every kind of app, menu bar apps included. Workspace notifications do not (F12, F13).
- Activation is not a window signal (F14).
- A window made during launch reaches the screen within about 1 ms of finishing (F15).
- An `AXObserver` can register only from about that moment: in every probe run it had become possible just before the `isFinishedLaunching` push arrived. After that, `kAXWindowCreated` leads each later window by 1–9 ms (F16, F17).
- Without Accessibility there is no push for a later window (F19).
- A Core Animation completion is a deadline about 1 ms late, given a layer committed inside a window (F24). It still completes when that window is off-screen, empty or ordered out (check P5).

The design keeps these constraints:

- The haptic and the first visible icon go out in one turn.
- The app is brought to front before any animation work.
- `LauncherCore` imports only Foundation and Observation.
- No framework type crosses a port, and every port has two adapters.
- A bounce snapshots its tuning, because the tuner restores its override as soon as `play` returns (F25).
- Release builds play the shipped values and show no tuner.

### Usage (caller's view)

```swift
// README (LauncherCore): a gesture that launches its app shows the launch bounce.
//
// The model decides everything: which visual a gesture gets, which bounces are live (keyed by bundle ID) and how
// each one ends. The SystemActions adapter shows each bounce, watches its launch, keeps its time, and reports
// LaunchProgress through `onLaunchProgress`. A report for an app with no live bounce does nothing.
//
//   fire, no process:      system.bringToFrontBouncing(app, cap: 10 s)   // opens the app first, then the bounce
//   .finishedLaunching:    system.limitLaunchBounce(of: id, to: 2 s)
//   .windowShown:          system.endLaunchBounce(of: id, with: .launchAnimation)
//   .wentNowhere:          system.endLaunchBounce(of: id, with: .quietFade)
//   .ranOut:               either ending, by how far the launch got
//
// Time is the adapter's: `.ranOut` arrives at the cap, or at the limit set once the app finished launching,
// whichever comes first. Tests push it like any other report.
```

**Call site 1: `Launcher.fire`.** The effects run in today's order: pulse, bring to front, then the icon.

```swift
private func fire(_ event: GestureEvent) {
    guard activity.isActive, let assigned = settings.assignments[event.gesture], let app = catalog.locate(assigned)
    else { return }
    hardware.playFeedback(.gesture, on: event.trackpad)
    switch visual(for: app) {                           // reads "has a process?" only when it decides something
    case .launchBounce:
        bounces[app.bundleID] = .startingUp
        system.bringToFrontBouncing(app, cap: LaunchBounce.cap)   // opens the app first, inside the call
    case .launchAnimation:
        system.bringToFront(app)
        // After bring to front, so whatever the animation costs lands on the icon, never on the app.
        system.playLaunchAnimation(for: app)
    case .none:                                         // the setting is off, or R14: this app's bounce still plays
        system.bringToFront(app)
    }
    window = .closed
}
```

**Call site 2: the progress push, installed in `start()`. This is the model's whole ending policy.**

```swift
system.onLaunchProgress = { [unowned self] app, progress in self.progress(progress, of: app) }

private func progress(_ progress: LaunchProgress, of app: BundleID) {
    guard let bounce = bounces[app] else { return }     // the bounce ended: a late window plays nothing (R12)
    switch bounce.next(after: progress) {
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

**Call site 3: World tests at the model seam.** Lifecycle and time are pushed inline, so nothing waits.

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
    #expect(world.system.bounces.first?.limits == [.seconds(2)])

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

**Call site 4: the Debug tuner's bounce preview (R18).** As today's preview does, it bypasses the model. Its 3 s is the bounce's own deadline.

```swift
tuner = AnimationTuner(
    preview: { [overlay] in overlay.play(for: finder) },
    previewBounce: { [bounces] in bounces.preview(finder, for: .seconds(3)) })   // then floats away, as a window would
```

### Shape

**Data first.**

- **In the model**, the data is `bounces: [BundleID: LaunchBounce]`. `LaunchBounce` has two cases, `.startingUp` and `.startedUp`, and absence from the dictionary means "no bounce plays". There are two access patterns, both lookups by app:
  - `fire` reads it (R14);
  - each progress push reads and writes it.

  Nothing iterates it, so a dictionary is the structure. The key is the bundle ID, the identity assignments already use (F3).
- **The ending policy (R9–R12)** is one total function, `LaunchBounce.next(after:) -> LaunchBounce.Step`:
  - A window ends the bounce with the launch animation, in either case.
  - Going nowhere (failed or quit) ends it with the quiet fade, in either case.
  - Finishing launching moves `.startingUp` to `.startedUp` and limits the bounce to the 2 s grace. A second report of it changes nothing.
  - Running out ends it with the quiet fade while `.startingUp`, and with the launch animation once `.startedUp`.

  That covers R12's 9 s menu bar scenario: the cap passes before finishing plus 2 s, and the case is `.startedUp`. The model never needs to know which deadline passed, only how far the launch got. "Ended" is not a case, so a report after the end has nothing to act on (R12, last sentence). Per model-the-domain and type-system-discipline.
- **In the adapter**, the data is the row: `[Bouncing]` in start order, newest last, which is R13's left-to-right order. Each entry holds:
  - its tuning snapshot and Reduce motion reading;
  - three layers: a slot that follows the pointer, an icon that bounces inside it, and a zero-size clock;
  - its deadlines.

  The model's dictionary is the only record of which bounces are live. The adapter never ends a bounce by itself: it reports `.ranOut` and waits for `endLaunchBounce`. Its row therefore follows the model's commands and is never a second source of truth (per separate-before-serializing-shared-state). The one exception is the Debug preview, which has no model behind it and ends itself.

**The decision (R1–R3, R14).**

- `visual(for:)` answers in three steps:
  1. If the setting is off, the answer is `.none`.
  2. If a bounce is live for the bundle ID, the answer is `.none` (R14).
  3. Otherwise `system.hasProcess(app.bundleID)` picks `.launchAnimation` or `.launchBounce`.
- `hasProcess` is `NSRunningApplication.runningApplications(withBundleIdentifier:)`:
  - it counts apps still launching and menu bar apps;
  - it costs under 0.1 ms;
  - its 1.65 ms first call is paid in `WorkspaceActions.init` (F7).
- The pulse is issued before the read, so today's effect order holds exactly.
- `bringToFrontBouncing` is one port call: it runs `openApplication`, with its completion, before it builds any layer. "Bring to front before any animation work" is therefore a contract the model cannot break by calling things out of order. It also binds the launch watch to the one `openApplication` whose answer it needs (per encode-lessons-in-structure). The bounce's first layers are committed in the same turn as the haptic, which is how plan 004 reads R1's "no later".
- For R14 the repeated gesture calls plain `bringToFront`; F8 shows that a second `openApplication` changes nothing.
- Swipes, window swipes and swaps never reach `fire`, so R3 holds by construction.
- `window = .closed` runs on every path (R16).

**The port.** `SystemActions` gains four members and its first push. Each member is a separate model decision:

| Member | Called from |
|---|---|
| `hasProcess` | read in `fire` |
| `bringToFrontBouncing(_:cap:)` | `fire` |
| `limitLaunchBounce(of:to:)` | finishing launching |
| `endLaunchBounce(of:with:)` | any ending |
| `onLaunchProgress`, carrying `(BundleID, LaunchProgress)` | the push |

- `pid_t`, `NSRunningApplication`, `AXError` and `CALayer` stay in `LauncherPlatform`. Durations cross as `Duration`, which `GestureRules` already uses.
- If the adapter cannot show a bounce (there is no display), the bounce runs out on the next main-actor turn rather than staying silent, so no model record can be stranded (per make-operations-idempotent). A stranded record would make R14 swallow every later gesture for that app.
- `endLaunchBounce` is idempotent. So is `bringToFrontBouncing` for an app whose bounce is live: it only brings the app to front.
- The push stays on `SystemActions`, not a new port. Its source is the completion of this port's own `openApplication` and the clock of this port's own bounce. A second port would make two adapters coordinate one call.

**The lifecycle (R9–R12): `LaunchWatch`, one per bounce.**

1. `bringToFrontBouncing` hands `openApplication` a completion. The completion maps the answer to the launched pid, or to nil on an error (F10) or a terminated app with pid −1 (F11), then hops to the main actor. Only the pid crosses threads. On the main actor the app is re-fetched with `NSRunningApplication(processIdentifier:)`.
2. A nil pid, a missing app or a terminated app reports `.wentNowhere`.
3. Otherwise the watch observes `isTerminated` and `isFinishedLaunching` with `[.initial, .new]`. `.initial` covers a completion that arrives after finishing, as a second open's does (F8). Each observation hops to the main actor, following the `SystemTrackpadPreferences` precedent.
   - `isTerminated` reports `.wentNowhere`.
   - The first `isFinishedLaunching` reports `.finishedLaunching`, then takes **one look** at the windows:
     - It tries once to register an `AXObserver` for `kAXWindowCreatedNotification`. In every probe run, registration had become possible before this push arrived (F16).
     - If registration succeeds, it counts the app's windows in `kAXWindowsAttribute`. A splash counts (F16, run 8).
     - Whether or not registration succeeds, `LaunchWatch.listedWindows(of:)`, a static read like `FrontmostAppWindows`' own, counts the pid's on-screen window-list entries below the status-window level. That read needs no permission (F18) and is warm (`FrontmostAppWindows` paid its first call at launch).
     - Every Accessibility call goes to the app element the watch creates, and the watch sets that element's messaging timeout to 0.2 s itself. So the bound does not depend on `FrontmostAppWindows` having set the process default first.

     The pure `LaunchWatch.look(_:axWindows:listedWindows:)` maps the outcome:
     - any window → `.shown` → drop the observer and report `.windowShown`;
     - registered with no window → `.watching` → the observer's callback reports `.windowShown`;
     - otherwise `.blind` → nothing more; R10's limit ends the bounce.
4. Without Accessibility, registration simply fails (`apiDisabled`). As in `FrontmostAppWindows`, which treats any failed call as "no windows", nothing checks trust first, so the trust check never leaves `SystemPermissions.swift`. The window-list read still catches a window made during launch.
   - That catch is racy (F15): one probe run listed the window 0.6 ms after `didLaunch`. The KVO handler runs a main-actor hop later, so the window is usually listed by then, but this is not guaranteed.
   - A window made later can end the bounce only through R10's 2 s limit (O1).
5. Nothing retries, so the polling ban holds as written.
6. `endLaunchBounce` stops the watch: it invalidates the KVO and removes the observer's run-loop source. Each report is the watch's last act, and a guard checks `isStopped` after it, so a report that ends the bounce re-entrantly is safe. The observer's callback also drops the observer once it has reported. Once no bounce is live, nothing observes anything.
7. **The push contract holds by construction.** Every report for a bounce, from its watch or from its deadlines, passes through that bounce's `LaunchReportGate` in `WorkspaceActions` before it reaches `onLaunchProgress`. The gate is a pure value: it admits `.finishedLaunching` at most once, then exactly one of `.windowShown`, `.wentNowhere` or `.ranOut`, and nothing after that. So a splash followed by a main window, or a deadline passing just after a window showed, reports once, even to a receiver that did not end the bounce.
8. The Accessibility and window-list code lives in `LaunchWatch.swift`, which joins `FrontmostAppWindows.swift` in the confinement table.

**Time (R10, R12, R18): Core Animation is the clock, and every deadline belongs to a bounce.**

- Each bounce's clock layer is a zero-size sublayer of its slot inside the row panel.
- A deadline is a 1→1 `opacity` `CABasicAnimation` on that layer, and its delegate's `animationDidStop` is the deadline passing. That is about 1 ms late while the panel is composited, and up to about 60 ms late when the row is cut off entirely at the top edge (F24, P5).
- `bringToFrontBouncing` arms the cap; `limitLaunchBounce` adds a deadline. Whichever passes first reports `.ranOut`, once. The cap stays armed, so a later limit can never extend a bounce.
- Ending a bounce cancels its deadlines (a flag) before it removes the layer, so their stops report nothing. A stop the system causes, which arrives with `finished == false` and no cancel, counts as passed, so no bounce can outlive its cap.
- The tuner's 3 s preview is a bounce whose cap is 3 s, ended by its own callback.
- No banned token is lifted, and the model holds no clock. The idle-CPU rationale behind the ban holds by construction: a deadline cannot outlive the bounce that carries it. Tests take time from the fake: they push `.ranOut` inline and assert the durations the model asked for.

**The pointer and the row (R5–R7, R13, R16).**

- **The row panel** is one panel the size of the pointer's display, built with `LaunchOverlay`'s recipe: click-through, non-activating, `.screenSaver`, on every Space. Because the panel is the display, R6's cut at the top edge comes free, and nothing can spill onto a display above.
  - It costs about 0.8 MB in our process (check P6).
  - When the pointer crosses to another display, the panel is re-framed once. Each icon's `contentsScale` is updated to that display's scale, since the bitmap is rendered at the highest scale (R4, R7).
- **Following.** `NSEvent` global and local monitors for moves and drags are installed when the first bounce starts and removed when the last ends. They read only `NSEvent.mouseLocation` (F20). Each event does this in one transaction with actions disabled, about 0.04 ms (F21):
  - recompute the pure `BounceRow`;
  - re-frame the panel if the display changed;
  - set each slot's position.

  With a non-zero `trailing`, each slot animates from its presentation position over that time instead.
- **The row's geometry and re-flow.** The row's geometry uses the newest bounce's snapshot; each icon's motion uses its own. When the row changes, each icon that moves slides to its new place through an additive position animation, from its old rest minus its new rest down to zero, over `slide` (R13). Additive animations compose with pointer moves.
- **`BounceRow` is pure.** It centres one row on the tip plus `offset`, newest on the right, `spacing` apart, with bottoms `gap` above the tip. It slides sideways just enough to stay on the display, never moves vertically, and pixel-snaps (R5, R6).
- **D1 reading.** No code of ours runs per *display* frame. Code may run per *input event* while the effect it serves is on screen. This is the switcher's per-trackpad-frame precedent (plan 006 F27, `docs/performance.md`). The bounce itself is keyframes on the render server.
- **D2 reading.** Pointer *position* is read only while a bounce shows, only to place the icon, and never kept. A new Privacy line says so. It supersedes plan 002 R9's pointer clause for this one purpose, and needs the human's sign-off.
- The source scan names every reader of pointer events (see Docs and source policy).
- **R16.** The panel ignores mouse events, the monitors are passive, and the click tap is untouched.
- **The tuner panel** sets `acceptsMouseMovedEvents`, so R18's preview follows the pointer over the tuner too. The local monitor sees moves only over our windows that accept them.

**The motion (R4, R8, R9, R11, R15).**

- `BounceMotion` is pure. It builds one cycle as 240-per-second `transform` keyframes about the icon's bottom centre:
  - up for `timeUp`, easing out to `height`;
  - down for `timeDown` with gravity;
  - `rest` on the ground, with the optional area-keeping `squash`.

  The cycle repeats forever and starts at rest, so the first jump starts at once. Shipped: 30 pt, 0.30 s up, 0.30 s down, 0.10 s rest, which is half the icon every 0.70 s (R8). Under Reduce motion the cycle is an opacity pulse in place instead (R15).
- The icon's side is `LaunchTuning.iconSide`, using the prepared 72 pt bitmap, so at the shipped tuning it is never upscaled (R4).
- **Endings lift the icon out of the row:**
  - `.launchAnimation`: `LaunchOverlay.play(for:from:among:)` stages the existing flight at the icon's presentation centre (`staged(at:among:)` already takes a start point), among the displays from the bounce's own `ScreenRead`, in its own panel. So the flight no longer follows the pointer, and it starts mid-jump if that is where the icon is (R9). It begins with the flight's usual swell, from 60 pt toward 72 pt. Under Reduce motion the flight is `.fadeInPlace` (R15).
  - `.quietFade`: a small panel at the icon's presentation frame, cut to the display, fades the icon from its presentation opacity to 0 over `fadeOut` (R11, R15).
  - Both endings build their new panel inside the same outer `CATransaction` that removes the slot, so the swap commits as one.

**The tuner (R17–R19).**

- `LaunchTuning` gains `var bounce = Bounce()`, a nested struct of `Double` knobs whose defaults are shipped:
  - R17's ten: `height`, `timeUp`, `timeDown`, `rest`, `squash`, `gap`, `offset`, `trailing`, `spacing`, `fadeOut`;
  - plus `slide` (R13's 0.2 s), `pulseLow` and `pulsePeriod` (R15's pulse). These are numbers the bounce needs anyway, so they live with the others, one source of shipped values.
- A "Launch bounce" section uses the existing `knob` helper with nested key paths (`\.bounce.height`, F25), and adds a "Preview bounce" button wired to a second closure (R18).
- Changes apply to the next bounce, because each bounce snapshots `LaunchTuning.current` when it starts (R17, F25).
- `Bounce` gets its own tolerant Debug `init(from:)`, and `LaunchTuning.init(from:)` gains `bounce = try value(.bounce, s.bounce)`, so an old preset keeps the shipped bounce (R19).
- A forgotten decode line is not a compile error, so a test catches it instead: set every field to a non-shipped value, encode, decode, and expect equality (per encode-lessons-in-structure).
- Release still reads `shipped`, and everything new in the tuner is `#if DEBUG`.

**Depth.**

- **What the model learns:** four members, a push and three small enums.
- **What it does not see:** `openApplication`'s completion, two KVO observations, Accessibility registration and the window-list look, the Core Animation deadlines and their fail-safe, a following panel, row geometry and re-flow, edge rules, two endings and the hand-off into the flight.
- No member is a stage of another, so the model never calls two members for one operation.
- Gesture to pixels is `Launcher.fire` → `WorkspaceActions` → `BounceOverlay`, with the pure staging beside it. Lifecycle back to the model is `LaunchWatch` → `WorkspaceActions` → `Launcher`.

#### Module map

| Module | Change |
|---|---|
| `LauncherCore` · launch bounce vocabulary (new) | `LaunchProgress`, `LaunchBounceEnding` (public); `LaunchBounce` and its `Step` (internal) |
| `LauncherCore` · `SystemActions` | `hasProcess`, `bringToFrontBouncing`, `limitLaunchBounce`, `endLaunchBounce`, `onLaunchProgress`; contract text |
| `LauncherCore` · `Launcher` | `bounces`, `visual(for:)`, the three-way `fire`, `progress(_:of:)`, the push installed in `start()` |
| `LauncherPlatform` · `WorkspaceActions` | the new members; `open(_:then:)`; owns `BounceOverlay` and each bounce's watch and `LaunchReportGate`; internal `init(screen:)`; warms `hasProcess`; the tuner's second preview |
| `LauncherPlatform` · `LaunchWatch` (new, confined) | completion → KVO → one look at the windows (AX observer plus `listedWindows(of:)`), its own 0.2 s messaging timeout; pure `look` |
| `LauncherPlatform` · `BounceOverlay` (new, confined for pointer events) | row panel, pointer monitors, deadlines, endings, DEBUG preview |
| `LauncherPlatform` · bounce staging (new, pure) | `BounceRow`, `BounceMotion` |
| `LauncherPlatform` · `LaunchOverlay`, `LaunchFlight` | `play(for:from:among:)`; `bitmap` and `makePanel` internal; `LaunchDisplay.containing` shared by flight and row |
| `LauncherPlatform` · `LaunchTuning`, `AnimationTuner` | nested `Bounce` with tolerant decoding; "Launch bounce" section, preview, `acceptsMouseMovedEvents` |
| Tests | `RecordingSystemActions` bounce surface; World `report` and `startProcess`; new model, staging, watch-decision and decoding suites; set-valued confinement |

#### Type sketch

```swift
// MARK: - LauncherCore · launch bounce vocabulary (new file)

/// What the adapter learned about a launch a gesture started, pushed while its launch bounce plays.
public enum LaunchProgress: Equatable, Sendable {
    /// macOS reports the app finished launching; menu bar apps too (key-value observation, F12, F13).
    case finishedLaunching
    /// A window of the app is on screen, on any display; a splash screen counts (R9).
    case windowShown
    /// macOS could not launch it, or its process ended before the bounce did (R11).
    case wentNowhere
    /// The bounce reached a time limit: its cap, or the limit set once the app finished launching.
    case ranOut
}

/// How a launch bounce ends.
public enum LaunchBounceEnding: Equatable, Sendable {
    /// The launch animation, from wherever the icon is at that moment, even mid-jump (R9, R10, R12).
    case launchAnimation
    /// A fade in place, about 0.2 s, with no launch animation (R11).
    case quietFade
}

/// One app's launch bounce as the model sees it: how far its launch has got, as far as the ending depends on it.
/// A bounce that ended is absent from `Launcher.bounces`, so a late report finds nothing and plays nothing (R12).
enum LaunchBounce: Equatable, Sendable {
    case startingUp
    case startedUp

    /// No bounce lasts longer than this after its gesture fired (R12).
    static let cap = Duration.seconds(10)
    /// Once its app finished launching, how long a bounce waits for a window (R10).
    static let grace = Duration.seconds(2)

    enum Step: Equatable, Sendable {
        case carryOn
        /// The bounce becomes `.startedUp` and now runs out within `limit` at the latest.
        case startUp(limit: Duration)
        case end(LaunchBounceEnding)
    }

    /// R9–R12 as one total table.
    func next(after progress: LaunchProgress) -> Step {
        // (_, .windowShown)                  -> .end(.launchAnimation)              R9
        // (_, .wentNowhere)                  -> .end(.quietFade)                    R11
        // (.startingUp, .finishedLaunching)  -> .startUp(limit: Self.grace)         R10
        // (.startedUp, .finishedLaunching)   -> .carryOn                            a repeat changes nothing
        // (.startingUp, .ranOut)             -> .end(.quietFade)                    R11, R12: still starting
        // (.startedUp, .ranOut)              -> .end(.launchAnimation)              R10 limit, or R12 cap
        fatalError("not implemented")
    }
}

// MARK: - LauncherCore · SystemActions (additions; existing members unchanged except their docs)

@MainActor public protocol SystemActions: AnyObject {
    // bringToFront, registerLoginItem, runningApps, frontmostWindows, raiseWindows: as today.

    /// The apps the next launch animations and launch bounces may be for. (Text widened; behaviour as today.)
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// As today, for an app with a process. Every call plays its own and never cancels, restarts or reuses one already
    /// playing. A launch bounce's ending plays the same animation inside the adapter.
    func playLaunchAnimation(for app: AppEntry)

    /// Whether macOS reports a process for the app now, still launching or finished, menu bar apps included; unlike
    /// `runningApps()`, not the ⌘-Tab list. Under 0.1 ms; reads only.
    func hasProcess(_ app: BundleID) -> Bool

    /// Bring to front for an app with no process, with its launch bounce. Opens the app exactly as `bringToFront`
    /// does, first, so the bounce never delays it; then, before returning, shows its icon bouncing just above the
    /// pointer and following it, in one row with any other bounce, newest on the right. Watches that launch and pushes
    /// `onLaunchProgress` for it until `endLaunchBounce`, `.ranOut` at `cap` at the latest. Reads the pointer, the
    /// displays, Reduce motion and the tuning at the call. Nothing it shows activates Trackpad Launcher, becomes key or
    /// receives a click. A bounce it cannot show runs out on the next main-actor turn. One bounce per app: for an app
    /// whose bounce still plays it only brings the app to front.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration)

    /// From now on the bounce runs out within `limit` at the latest; never later than its cap or an earlier limit.
    /// No-op for an app whose bounce is not playing.
    func limitLaunchBounce(of app: BundleID, to limit: Duration)

    /// Ends the bounce from wherever the icon is, stops watching its launch and pushes nothing more for it; the icon no
    /// longer follows the pointer, and the others close up over about 0.2 s. Once the last bounce has ended nothing of
    /// ours remains: no row panel, no monitor, no observer. Idempotent: a no-op for an app whose bounce is not playing.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding)

    /// On the main actor, only for an app whose bounce plays: `.finishedLaunching` at most once, then at most one of
    /// the others before `endLaunchBounce`. Nothing for a launch Trackpad Launcher did not start.
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)? { get set }
}

// MARK: - LauncherCore · Launcher (changes)

extension Launcher {
    // stored: @ObservationIgnored private var bounces: [BundleID: LaunchBounce] = [:]
    //   The launches whose bounce plays. Written only by `fire` and `progress(_:of:)`: the one record of which
    //   bounces are live (R14); the adapter's row follows its commands.

    private enum Visual { case launchBounce, launchAnimation, none }

    /// R1–R3, R14. Reads `hasProcess` only when it decides something.
    private func visual(for app: AppEntry) -> Visual {
        // guard settings.isLaunchAnimationOn else { return .none }                    R3: setting off
        // if bounces[app.bundleID] != nil { return .none }                            R14: keep the one bounce
        // return system.hasProcess(app.bundleID) ? .launchAnimation : .launchBounce    R1, R2
        fatalError("not implemented")
    }
    // fire(_:) and progress(_:of:) exactly as in Usage, call sites 1 and 2; start() installs onLaunchProgress.
}

// MARK: - LauncherPlatform · WorkspaceActions (changes)

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    /// One per bounce playing, from `bringToFrontBouncing` to `endLaunchBounce`.
    private var launches: [BundleID: Launch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?

    private struct Launch {
        let watch: LaunchWatch
        var gate = LaunchReportGate()
    }

    public convenience init() { self.init(screen: ScreenRead.now) }

    /// Tests inject the pointer-and-displays read (for example, one with no display).
    init(screen: @escaping @MainActor () -> ScreenRead) {
        overlay = LaunchOverlay()
        bounces = BounceOverlay(flights: overlay, screen: screen)
        // TODO: one runningApplications(withBundleIdentifier:) now: the first in a process costs 1.65 ms (F7).
        fatalError("not implemented")
    }

    /// Every report for a bounce, from its watch or its deadlines, passes the bounce's gate first.
    private func report(_ progress: LaunchProgress, of app: BundleID) {
        // guard var launch = launches[app], launch.gate.admits(progress) else { return }
        // launches[app] = launch; onLaunchProgress?(app, progress)
        fatalError("not implemented")
    }

    public func bringToFront(_ app: AppEntry) { open(app) }

    public func hasProcess(_ app: BundleID) -> Bool {
        // !NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).allSatisfy(\.isTerminated)
        fatalError("not implemented")
    }

    public func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        // let id = app.bundleID
        // guard launches[id] == nil else { return bringToFront(app) }
        // let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.report($0, of: id) }
        // let watch = LaunchWatch(report: report); launches[id] = Launch(watch: watch)
        // open(app, then: watch.opened)                        // the app first: nothing below can delay it
        // bounces.start(app, cap: cap) { report(.ranOut) }
        fatalError("not implemented")
    }

    public func limitLaunchBounce(of app: BundleID, to limit: Duration) { bounces.limit(app, to: limit) }

    public func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) {
        launches.removeValue(forKey: app)?.watch.stop()
        bounces.end(app, with: ending)
    }

    /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates. `opened`, when given, hears
    /// macOS's answer from any thread: the launched pid, or nil when it could not launch the app (F10) or the process
    /// ended before checking in (F11, pid −1).
    private func open(_ app: AppEntry, then opened: (@Sendable (pid_t?) -> Void)? = nil) {
        fatalError("not implemented")
    }

    #if DEBUG
    // showAnimationTuner(): AnimationTuner(preview: { overlay.play(for: finder) },
    //                                      previewBounce: { bounces.preview(finder, for: .seconds(3)) })
    #endif
}

/// What may still be reported for one bounce: `.finishedLaunching` at most once, then exactly one of the others, then
/// nothing. Pure; it makes `onLaunchProgress`'s contract true whoever receives the reports.
struct LaunchReportGate: Equatable {
    private var hasFinished = false
    private var hasEnded = false
    mutating func admits(_ progress: LaunchProgress) -> Bool {
        // guard !hasEnded else { return false }
        // .finishedLaunching: admit once (hasFinished)
        // .windowShown, .wentNowhere, .ranOut: hasEnded = true; admit
        fatalError("not implemented")
    }
}

/// Where the pointer is and which displays exist, read now: what a bounce reads when it starts and on every move.
struct ScreenRead {
    let pointer: CGPoint
    let displays: [LaunchDisplay]
    /// `NSEvent.mouseLocation` and `NSScreen.screens`.
    @MainActor static func now() -> ScreenRead { fatalError("not implemented") }
}

// MARK: - LauncherPlatform · LaunchWatch (new; LaunchWatch.swift joins the AXUIElement and CGWindowList confinement)

/// Watches one launch a gesture started, from macOS's answer to `openApplication` until `stop()`: the process's
/// finishing and ending by key-value observation, which macOS pushes for every kind of app (F9–F13), then one look at
/// its windows and, with Accessibility, its first window created later (F15–F17). Reports each fact at most once,
/// nothing after `stop()`, and holds nothing once stopped. Every AX call goes to the app element it creates, whose
/// messaging timeout it sets to `messagingTimeout` itself.
@MainActor final class LaunchWatch {
    static let messagingTimeout: Float = 0.2
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
        // guard !isStopped
        // guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        //     else { return wentNowhere() }
        // observe \.isTerminated        [.initial, .new]: true -> Task { @MainActor } -> wentNowhere()
        // observe \.isFinishedLaunching [.initial, .new]: true -> Task { @MainActor } -> finished(pid)
        fatalError("not implemented")
    }

    private func finished(_ pid: pid_t) {
        // guard !isStopped, !hasFinished; hasFinished = true
        // report(.finishedLaunching); guard !isStopped                     // the report may end the bounce
        // element = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        // registration = AXObserverCreate(pid, callback) + AXObserverAddNotification(element,
        //     kAXWindowCreatedNotification, refcon: Unmanaged(self).passUnretained) mapped:
        //     .success -> .registered (source added to the main run loop), .apiDisabled -> .noAccess, else -> .notAnswering
        // axWindows = registration == .registered ? count of kAXWindowsAttribute on element : 0
        // switch Self.look(registration, axWindows:, listedWindows: Self.listedWindows(of: pid))
        //     .shown -> drop the observer; report(.windowShown) · .watching -> wait · .blind -> drop the observer
        // callback (C, main run loop): MainActor.assumeIsolated { guard !isStopped; drop the observer;
        //     report(.windowShown) }
        fatalError("not implemented")
    }

    /// The pid's windows on screen now in the window list, below the status-window level: a splash counts, a
    /// status-level helper does not. Needs no permission. Racy at finishing (F15).
    nonisolated static func listedWindows(of pid: pid_t) -> Int { fatalError("not implemented") }

    private func wentNowhere() {
        // guard !isStopped; report(.wentNowhere)
        fatalError("not implemented")
    }

    enum Registration: Equatable { case registered, notAnswering, noAccess }
    enum Look: Equatable { case shown, watching, blind }

    /// One look at a launching app's windows when it finished launching. Pure.
    /// Any window, by either count: .shown · none and .registered: .watching · none otherwise: .blind
    nonisolated static func look(_ registration: Registration, axWindows: Int, listedWindows: Int) -> Look {
        fatalError("not implemented")
    }
}

// MARK: - LauncherPlatform · BounceOverlay (new; the only file besides ClickTap.swift and MenuBarShell.swift that
// names pointer events)

/// Shows launch bounces. Every bouncing icon sits in one row above the pointer, in one display-sized click-through
/// panel on the pointer's display, re-framed when the pointer crosses to another display. NSEvent monitors for moves
/// and drags exist from the first bounce until the last ends; they read only where the pointer is. Core Animation
/// plays the bounce. Each bounce carries its own deadlines (1→1 opacity animations on its clock layer), which pass on
/// the render server's clock and die with the bounce. An ending lifts the icon out of the row into its own panel. Once
/// the row is empty and the last ending's completion has run, nothing of ours runs.
@MainActor final class BounceOverlay {
    private let flights: LaunchOverlay
    /// The pointer and the displays, read at each start and each move. `ScreenRead.now` in the app.
    private let screen: @MainActor () -> ScreenRead
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

    init(flights: LaunchOverlay, screen: @escaping @MainActor () -> ScreenRead) {
        self.flights = flights
        self.screen = screen
    }

    func start(_ app: AppEntry, cap: Duration, ranOut: @escaping @MainActor () -> Void) {
        // guard !row.contains { $0.app.bundleID == app.bundleID } else { return }
        // snapshot tuning, Reduce motion (system || tuning.forceReduceMotion); let read = screen()
        // guard let layout = BounceRow(count: row.count + 1, pointer: read.pointer, among: read.displays,
        //                              side: iconSide, tuning: tuning.bounce),
        //       let stage = stage(on: layout.display)       // LaunchOverlay.makePanel(frame: display.frame), ordered in
        //     else { Task { @MainActor in ranOut() }; return }  // nothing to show: runs out next turn
        // one CATransaction, actions disabled: slot at layout.rests.last; icon (side, bitmap from flights.bitmap,
        //     contentsScale = display scale, trilinear) + BounceMotion(...).animations(); clock + deadline(cap) ->
        //     runOut(app); slide the others to layout.rests.dropLast() (BounceRow.slide)
        // row.append(...); if row.count == 1 { follow() }
        fatalError("not implemented")
    }

    func limit(_ app: BundleID, to limit: Duration) {
        // add a deadline of `limit` to that bounce's clock; the cap stays, so a later limit never extends it
        fatalError("not implemented")
    }

    func end(_ app: BundleID, with ending: LaunchBounceEnding) {
        // guard let index = row.firstIndex(where: app) else { return }            // idempotent
        // let bouncing = row.remove(at: index); bouncing.deadlines.forEach { $0.isCancelled = true }
        // let frame = the icon's presentation frame in global coordinates (presentation layer → slot → host → panel)
        // one outer CATransaction:
        //     .launchAnimation: flights.play(for: bouncing.app, from: frame.centre, among: screen().displays)
        //                                                                            // R9; Reduce motion fades in place
        //     .quietFade: own panel at frame ∩ display, a layer frozen at the presentation transform and opacity,
        //                 BounceMotion.quietFade(from:), closed from its completion   // R11
        //     bouncing.slot.removeFromSuperlayer(); slide the rest to their new rests  // R13
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
        // global + local NSEvent monitors for [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged];
        // each handler (MainActor.assumeIsolated) -> moved(screen()); the local one returns its event.
        fatalError("not implemented")
    }

    private func unfollow() { fatalError("not implemented") }   // removes both monitors; idempotent

    private func moved(_ read: ScreenRead) {
        // layout = BounceRow(count: row.count, pointer: read.pointer, among: read.displays, ...,
        //                    tuning: row.last.tuning.bounce)
        // display changed: re-frame the panel, set each icon's contentsScale to the new display's scale (R4, R7)
        // one CATransaction, actions disabled: each slot.position = its rest in panel coordinates, or with
        //     trailing > 0 an ease-out from its presentation position over `trailing`
        fatalError("not implemented")
    }

    private func runOut(_ app: BundleID) {
        // guard let i, let ranOut = row[i].ranOut; row[i].ranOut = nil; ranOut()
        fatalError("not implemented")
    }

    /// A deadline on the render server's clock. A cancelled one reports nothing. A stop the system causes
    /// (`finished == false`, not cancelled) reports as passed, so no bounce can outlive its cap. Internal, so a test can
    /// drive its stop rule directly.
    @MainActor final class Deadline: NSObject, CAAnimationDelegate {
        var isCancelled = false
        let passed: @MainActor () -> Void
        init(passed: @escaping @MainActor () -> Void) { self.passed = passed }
        nonisolated func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            MainActor.assumeIsolated { if !isCancelled { passed() } }
        }
    }
}

// MARK: - LauncherPlatform · bounce staging (new, pure, tested like LaunchFlight)

/// Where the bouncing icons rest for a pointer: one row, newest on the right, `spacing` apart, centred on the pointer's
/// tip plus `offset`, bottoms `gap` above the tip (R5, R13). It slides sideways just enough to stay on the pointer's
/// display and never moves down, so the top edge cuts it (R6). Pixel-snapped to the display.
struct BounceRow: Equatable {
    let display: LaunchDisplay
    /// Each icon's bottom centre, global y-up, in row order.
    let rests: [CGPoint]

    /// Nil with no display. The display is AppKit's rule for the pointer, shared with the flight.
    init?(count: Int, pointer: CGPoint, among displays: [LaunchDisplay], side: CGFloat, tuning: LaunchTuning.Bounce) {
        fatalError("not implemented")
    }

    /// The re-flow: an additive position animation from `old − new` to zero over `duration`, easing out; nil when the
    /// rest did not move. Additive, so pointer moves during the slide compose with it.
    static func slide(from old: CGPoint, to new: CGPoint, over duration: CFTimeInterval) -> CABasicAnimation? {
        fatalError("not implemented")
    }
}

/// One launch bounce's motion, which Core Animation repeats forever: a Dock-like jump on `transform` about the icon's
/// bottom centre, or under Reduce motion an opacity pulse in place (R8, R15). 240 samples a second; starts at rest.
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
    /// As `play(for:)`, staged at `start` among `displays` instead of at the pointer among `NSScreen.screens`: a
    /// bounce's ending, from wherever its icon is (R9), among the displays the bounce read, so one `ScreenRead` places
    /// both. `play(for:)` becomes `play(for: app, from: read.pointer, among: read.displays)` with `ScreenRead.now()`.
    func play(for app: AppEntry, from start: CGPoint, among displays: [LaunchDisplay]) { fatalError("not implemented") }
    // bitmap(for:scale:) and static makePanel(frame:) become internal: one icon cache and one panel recipe.
}

extension LaunchDisplay {
    /// AppKit's rule for the pointer's display, else the nearest; moved here from `LaunchFlight.display(for:among:)`.
    static func containing(_ point: CGPoint, among displays: [LaunchDisplay]) -> LaunchDisplay? {
        fatalError("not implemented")
    }
}

// MARK: - LauncherPlatform · LaunchTuning (additions)

extension LaunchTuning {
    // stored: var bounce = Bounce()

    /// Every number that shapes a launch bounce. The defaults are the shipped bounce.
    struct Bounce: Equatable, Sendable {
        /// Points the icon jumps: about half the icon (R8).
        var height: Double = 30
        var timeUp: Double = 0.30
        var timeDown: Double = 0.30
        /// Seconds on the ground between jumps.
        var rest: Double = 0.10
        /// Share of its height the icon loses on landing, widening to keep its area. 0 = none (R8).
        var squash: Double = 0
        /// Points between the pointer's tip and the icons' bottoms at rest (R5).
        var gap: Double = 8
        /// Sideways from the tip to the row's centre (R5: none).
        var offset: Double = 0
        /// Seconds the row takes to catch up with the pointer. 0 = glued to it (R7).
        var trailing: Double = 0
        /// Points between icons in the row (R13).
        var spacing: Double = 12
        /// Seconds of the quiet fade (R11).
        var fadeOut: Double = 0.2
        /// Seconds the others take to slide when one ends (R13).
        var slide: Double = 0.2
        /// Reduce motion: the pulse's dimmest opacity, and its period in seconds (R15).
        var pulseLow: Double = 0.5
        var pulsePeriod: Double = 1.4
    }
}

#if DEBUG
extension LaunchTuning.Bounce: Codable {
    /// Keys missing from an older save keep their shipped values: one `x = try value(.x, s.x)` line per field, as in
    /// `LaunchTuning`'s. `LaunchTuning.init(from:)` gains `bounce = try value(.bounce, s.bounce)` (R19).
    init(from decoder: any Decoder) throws { fatalError("not implemented") }
}
// AnimationTuner.init(preview:previewBounce:); its panel sets acceptsMouseMovedEvents. TunerView gains, before the
// presets: Section { one knob per Bounce field, e.g. knob("Jump height", \.bounce.height, 0...80, step: 1, unit: "pt");
//   Button("Preview bounce") { previewBounce() } } header: { Text("Launch bounce") }
//   footer: { Text("Applies from the next bounce. Preview bounces Finder's icon for 3 s, then floats it away.") }
#endif

// MARK: - Tests · RecordingSystemActions (additions) and World

extension RecordingSystemActions {
    // stored: var processes: Set<BundleID> = []
    //   Processes ⌘-Tab does not show: menu bar apps, apps still starting from the Dock.
    // stored: private(set) var bounces: [Bounce] = []
    //   The bounces playing, in start order: the row, newest last. Every bringToFrontBouncing call appends, a repeated
    //   one too, so a second start shows; the fake does not copy the adapter's one-bounce-per-app guard.
    // stored: private(set) var bounceEndings: [BounceEnd] = []
    //   Every endLaunchBounce call, in order, so a double end shows.
    // stored: var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    // stored: var onBringToFrontBouncing: (() -> Void)?
    //   Runs inside bringToFrontBouncing, like onPlayLaunchAnimation, so a test can see the other effects then.

    struct Bounce: Equatable {
        let app: AppEntry
        let cap: Duration
        /// Every limit the model set, in order. Recorded, not applied: which deadline passes first is the adapter's.
        var limits: [Duration] = []
    }

    struct BounceEnd: Equatable {
        let app: BundleID
        let ending: LaunchBounceEnding
    }

    /// Derived, never synced: a ⌘-Tab app and the frontmost app have a process too.
    func hasProcess(_ app: BundleID) -> Bool {
        // processes.contains(app) || frontmost?.bundleID == app || running.contains { $0.bundleID == app }
        fatalError("not implemented")
    }

    /// Records the bring to front, then the bounce, in that order.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration) { fatalError("not implemented") }
    /// Appends to that bounce's `limits`.
    func limitLaunchBounce(of app: BundleID, to limit: Duration) { fatalError("not implemented") }
    /// Records every call; removes a playing bounce.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) { fatalError("not implemented") }
    /// The launch reports `progress` inline, as the real adapter pushes it on the main actor. A test withholds a report
    /// by not calling this, delivers one late by calling it after the end, and passes time with `.ranOut`.
    func report(_ progress: LaunchProgress, for app: BundleID) { onLaunchProgress?(app, progress) }
}
// World: report(_:for name:), startProcess(_ name:).
// SourcePolicyTests: Confined(token:onlyIn: Set<String>, rule:).
```

**Seams and test handles.**

| Seam | What runs there |
|---|---|
| `World` over `RecordingSystemActions` (model) | R1–R3 and R9–R14 decisions; R16's window close |
| Pure `LauncherPlatformTests`, keyframes decoded as in `LaunchFlightTests` | `BounceRow` (R5, R6, R13); `BounceMotion` (R8, R15, R17's effects); `LaunchWatch.look` (the Accessibility answers); `LaunchReportGate`; `BounceOverlay.Deadline`'s stop rule; `LaunchTuning` decoding against the real 15-key old preset JSON (R19) |
| Real on this Mac, heavier, serialized | the real `WorkspaceActions` through the port's members, and `LaunchWatch` where a pid must be withheld, against throwaway bundles scripted as in P1 (window at finish, late window, splash, menu bar app, crash, missing executable); a `ScreenRead` with no display |
| Manual | lag (R7), feel (R8), sharpness (R4), clicks through (R16), a second display, the preview (R18) |

The handles a test needs:

- **Time:** on the model side `.ranOut` is pushed inline, and the cap and limits the model asked for are recorded. On the adapter side, the render server's clock cannot be advanced, so tests pass short caps and limits and wait for them, each wait bounded.
- **Displays:** `WorkspaceActions(screen:)` takes the pointer-and-displays read.
- **Lost or late signals:** the test withholds a report, or reports after the end.
- **Accessibility answers:** the pure `look` table.
- **Calls that can block:** only `LaunchWatch` makes AX calls, each bounded by the 0.2 s timeout it sets on its own element. The model never waits on one.

Existing tests change in two ways:

- The six positive `launchAnimations` expectations (`LauncherTests` lines 22, 52, 56, 62, 86 and `FiveFingerTests` line 19) gain a running app, which makes them R2 tests.
- The R3 negatives gain `bounces.isEmpty`.

**Docs and source policy.** Planning has already made the doc changes below; the source-policy changes land with the code.

- **`docs/architecture.md`, Concurrency:**
  - The push list gains a launch's progress while its bounce shows, and pointer moves while a bounce shows.
  - New sentence: time passes only on Core Animation's clock, because a launch bounce's deadlines are animations on its own layer and exist only while it shows.
  - The animation bullet is reworded to say what it allows: never per display frame, per input event while the effect shows.
  - The icon-drawing exception ("the launch overlay likewise draws an icon at gesture time only when its off-main pass has not drawn one yet") covers the launch bounce too, since it shares the prepared icons.
- **`docs/architecture.md`, Privacy:**
  - Accessibility is also used to notice the first window of an app a gesture is launching, while its launch bounce shows.
  - New: the pointer's position is read only while a launch bounce shows, and never kept.
  - The "without Accessibility" sentence gains the late-window case.
  - The confinement sentence names the second window file and the pointer-event files.
- **`docs/domain-model.md`:**
  - A new **Launch bounce** entry.
  - **Launch animation**: "every fired gesture plays its own" applies to a running app's gesture; the end of a launch bounce plays it too.
  - **Launch animation setting**: it also covers the bounce.
  - **Bring to front**: it notes the launch-bounce variant.
- **`Ports.swift`:** the new members' contracts as above. The "completion is ignored" comment goes, because its reason no longer holds.
- **Plan 004's non-goals** "showing the icon until the app's window appears" and "tracking the pointer during the animation" are reversed by this plan.
- **`SourcePolicyTests`:**
  - `Confined.onlyIn` becomes a `Set<String>`.
  - `AXUIElement` and `CGWindowList` may also appear in `LaunchWatch.swift`.
  - `mouseMoved` is confined to `BounceOverlay.swift` and `ClickTap.swift`, which only rewrites to it.
  - `addGlobalMonitorForEvents` is confined to `MenuBarShell.swift` and `BounceOverlay.swift`.
  - `addLocalMonitorForEvents` is confined to `BounceOverlay.swift`.

### Synthesis decision

**Base: candidate 1.**

- **The cross-judge** picked candidate 1, 28 to 24, ahead on fidelity, depth, state correctness and testability, and level on architecture fit and the tuner.
- **My own scoring by criterion agreed.** Candidate 1 decides with one query (`hasProcess`) and then one command per visual. Candidate 2's `bringToFront -> BringToFront` followed by `showLaunchBounce` needs the adapter to pair two calls behind the model's back (the shallow-module flag). Candidate 1 also keeps R9 working without Accessibility for windows made during launch, through one window-list look. And it cannot strand a model record.

**Convergence.** The two candidates agreed, independently, on the core: the model-owned two-case record keyed by bundle ID with the same six-transition table; the push on `SystemActions`; Core Animation deadlines on a per-bounce clock layer; global and local NSEvent monitors; the hand-off through `staged(at:)` from the presentation point; and a nested tolerant `Bounce` tuning with a round-trip test. That consensus shipped as it was.

**Grafted from candidate 2:**

- The model's value is named `LaunchBounce`, with a nested `Step`. This replaces candidate 1's `LaunchStage`, which collided with `LaunchStage` in `LaunchFlight.swift`.
- Re-framing to another display updates each icon's `contentsScale`.
- `addGlobalMonitorForEvents` is confined too, so every reader of pointer events is named.
- The design states that plan 004's non-goals are reversed. It names the hand-off swell and the Dock-launch window (below).
- The fake records every limit as a list instead of re-implementing "earliest wins", which removes a policy copy the judge flagged.

**My own changes:**

- The pulse goes before the process read, so `fire`'s effect order is exactly today's.
- The window-list read happens on every look, not only when AX registration fails, so the look is `look(_:axWindows:listedWindows:)`. Its claim is softened to "racy" (F15, F19).
- The tuner panel accepts mouse-moved events, so the preview follows over it.
- The row's geometry uses the newest bounce's snapshot.

**Rejected:**

- **Candidate 2's two-call `bringToFront`/`showLaunchBounce` split:** the hidden pairing.
- **Its small panel moved per event:** check P6 measured the display-sized panel at about 0.8 MB in our process, not the 24 MB candidate 2 assumed. A small panel also leaves `trailing` without a defined frame.
- **Its AX retry ticks:** in every P1 run, registration had become possible before the `isFinishedLaunching` push arrived. The grounding's F16 wording ("within 0–10 ms") understated this. A retry would bend the polling rule for a case no probe produced, so it stays an open question.
- **Its `Double` seconds:** `Duration` is already the codebase's type.

**Evidence gathered after fan-out:**

- `checks/p5-offscreen-clock.md`: deadlines survive a row cut off entirely at the top edge.
- `checks/p6-panel-memory.md`: the panel's memory.

### Tradeoffs accepted

- **The cap passes a little late.** A deadline passes about 1 ms late while the row shows, up to about 60 ms late when the row is cut off entirely (P5), and about 90 ms late under `swift test`. So "no longer than 10 seconds" (R12) means 10 s plus at most about 0.1 s, and longer across a display sleep, when nothing is on screen anyway.
- **Time from Core Animation.** We accept time borrowed from the render server's clock, which may stretch across display sleep, in exchange for three things:
  - no timer and no change to the ban;
  - deadlines that cannot outlive the bounce carrying them;
  - a fail-safe that counts a system stop as passed.
- **Four members and a first push on `SystemActions`, not a new port.** We accept a larger port in exchange for an unchanged `Launcher` initialiser, World and composition root (plan 004's "no new port").
- **Bring to front merged into `bringToFrontBouncing`.** "Bring to front first" becomes an adapter contract the model's tests cannot observe. In exchange, the model cannot get the order wrong, and the watch is bound to the open it needs.
- **No Accessibility registration retry.** An app whose Accessibility server is not answering when it finishes launching, and whose first window comes later, waits out the 2 s limit. In exchange, the polling ban holds literally.
- **Code on every pointer event while a bounce shows** (about 0.04 ms per move, up to about 120 per second). In exchange, the icon is glued to the pointer, no code is driven by the display, and nothing runs once the last bounce ends.
- **A display-sized panel, re-framed on display crossings.** We accept about 0.8 MB, an unmeasured WindowServer compositing cost and a possible one-frame hitch at a crossing. In exchange, the top-edge cut and "never onto another display" come for free, and moves are layer-only.
- **Endings lifted into their own panels.** We accept two windows changing in one transaction, which may overlap for a frame. In exchange, the hand-off reuses the real launch animation unchanged, including its swell from 60 pt.
- **The flight's tuning at hand-off.** The flight at a bounce's end reads the live flight tuning, not the bounce's snapshot. That matters only in Debug, when knobs change mid-bounce.
- **The process read just after the pulse.** We accept a read of under 0.1 ms, warmed at launch, on the gesture path.
- **The Dock-launch window.** An app launched from the Dock less than 60–440 ms before the gesture has no process yet (F7), so it bounces instead of floating up.
- **Identity by bundle ID.** A running copy of the same bundle elsewhere on disk reads as running and gets the launch animation, matching assignment identity.
- **Three knobs beyond R17's ten** (`slide`, `pulseLow`, `pulsePeriod`). We accept them so that every number the bounce uses lives in one tuning, as `LaunchTuning`'s doc promises. They change nothing about the shipped behaviour.
- **Squash beyond 0.2 is slightly upscaled.** At area-keeping squash past 0.2, the icon widens beyond the prepared 72 pt bitmap. The shipped squash is 0; this affects only the tuner's experiments.

### Alternatives considered

- **Adapter-owned endings: a fire-and-forget `playLaunchBounce` plus one `onBounceEnded` push.**
  - Its interface is the smallest, and the policy sits beside its signals.
  - It moves R9–R12 out of `Launcher`, breaking "one model owns every decision" and plan 005's policy-free adapter.
  - R14 would still need a mirrored live set kept in sync by a push, so it exposes a sync contract while hiding policy the requirements name.
  - Lost.
- **`bringToFront` answering whether it launched, then a separate `showLaunchBounce`.**
  - It fuses the read into the action.
  - But the adapter must pair the two calls to know which launch to follow, which is hidden coupling. Swipes and swaps would also learn a value they discard.
  - Lost.
- **A deadline port backed by a dispatch source.**
  - It is honest about time.
  - It needs `asyncAfter` or `makeTimerSource` unbanned and the architecture rewritten.
  - Every path would have to cancel its deadlines, and it gives the model a general clock where only bounce-scoped time is needed.
  - Lost.
- **The bounce as observable model state, rendered by a `LauncherUI` presenter (the switcher pattern).**
  - `Observations` delivers on a later turn, which breaks R1's same-turn reading.
  - `LauncherUI` cannot reach `LaunchFlight` or the icon cache for the hand-off.
  - Lost.
- **One small panel per row, moved with `setFrame` per event.**
  - It is as cheap per move (F21).
  - The top-edge clip would change the frame and the layer offset in two systems that may not land in the same frame.
  - `trailing` would need an unbounded reach.
  - Lost to the display-sized panel once P6 showed that panel is cheap in our process.

### Open questions and risks

The human answered on review: D2 signed off (no new macOS permission; only the written privacy rule changes). D1 accepted as the rule for later features too. O1 and O7 accepted, R9 amended with both exceptions, no Accessibility retry unless a real app needs it. R12 now reads "about 10 seconds". D3 and O4 accepted, to be checked by hand with Slack, Figma or Chrome. The questions below are kept as asked.


- **D2:** do you sign off on reading the pointer's position (only while a bounce shows, used only to place the icon, kept nowhere) as a new Privacy line that supersedes plan 002 R9's pointer clause for this purpose?
- **D1:** is "never per display frame; per input event while the effect shows" the rule you want written into `docs/architecture.md` for later features too?
- **O1, R9 as written is not met:** without Accessibility, a window that opens *after* the app finished launching ends the bounce only through R10's 2 s rule, not within 50 ms. Windows made during launch are still caught, racily, by the window-list look. Do you accept this, with the Privacy section's "without Accessibility" sentence saying so, or should R9 be amended? S3 does not merge until this is answered.
- **AX lag (O7), the second case where R9 is not met:** an app whose Accessibility server is not answering when it finishes launching, and whose window comes later, also waits out the 2 s. No probe produced this case. Should a bounded retry on the bounce's own deadlines be added if it turns up, accepting the change to the polling rule?
- **R12's "no longer than 10 seconds":** the cap passes up to about 0.1 s late, and later across a display sleep (Tradeoffs). Accept, or should R12 read "about 10 seconds"?
- **R7:** the icon trails the hardware cursor by the monitor's delivery delay (median 3.5 ms) plus up to one display frame. Is that "no lag the user can see"? Only drawing the cursor itself would beat it. This is a manual check.
- **D3 and O4:** an Electron or Chromium app that creates a hidden window at startup, or any app whose window opens on another Space, could report `kAXWindowCreated` early and float away sooner than R9 or R10 intend. Accept, pending cold-launch checks of Slack, Figma and Chrome?
- **O8:** a hung launching app can block the main actor for up to the 0.2 s messaging timeout during the one look at finishing. Following pauses for that time, but the bounce keeps playing on the render server. Acceptable off the gesture path?
- **The hand-off frame:** the swap from the row's panel to the ending's panel is one transaction across two windows. Is a manual check for a blink or a doubled icon at 120 Hz enough?
- **O6:** re-framing to a second display, with "Displays have separate Spaces" on, is unprobed (F22). Who can check it on a two-display Mac?
- **Display sleep, screen lock and the Gatekeeper prompt (O5):** a bounce may outlast 10 s of wall time across a display sleep. During a pending Gatekeeper prompt it runs to the cap, which R11 accepts.
- **WindowServer cost:** compositing a display-sized transparent panel for up to 10 s is unmeasured outside our process. Should the performance doc gain a bounce scenario?
- **Debug builds play the saved tuner state (plan 014):** manual checks of the shipped bounce should "Reset to shipped" first.

### Next implementation step

S1's prefactor:
- `ScreenRead`, and `LaunchOverlay.play(for:from:among:)` with the shared `LaunchDisplay.containing`;
- the overlay's icon cache and panel recipe made internal;
- the set-valued confinement table;
- the scripted throwaway probe bundles the platform tests launch.

Then S2 begins with the launch bounce vocabulary, the `SystemActions` members and `RecordingSystemActions`' bounce surface, and the World tests for R1–R3 and R9–R14.

## Testing Decisions

> **Changed after implementation, at the human's request:** every test that launches a real throwaway app was removed (the `LaunchProbe` target and the adapter, window, follow and watch suites). They took the suite from about 6 s to about 92 s, too much for this feature. The bounce's rules stay covered by the model (`World`), staging, gate, look and deadline tests. What the removed rows checked against real apps is now part of the manual checks.

### Strategy

The design has one seam that matters, the `SystemActions` port. Its two adapters give the two sides the tests cross it from.

- **Model side: `World` over `RecordingSystemActions`**, like `LauncherTests.swift` and `FiveFingerTests.swift`.
  - Synchronous. The test owns the clock: time passes only when it pushes `.ranOut`, and the cap and limits the model asked for are read back as recorded `Duration`s.
  - Lifecycle is pushed inline with `World.report(_:for:)`. A test withholds a report by not pushing it and delivers one late by pushing it after an ending. `World.startProcess(_:)` gives an app a process that ⌘-Tab does not list.
  - Rows assert the whole history the fake records: `broughtToFront`, `bounces` with their `limits`, `bounceEndings`, `launchAnimations` and the feedback.
  - Two details of the design's fake make the R14 rows discriminating. `bringToFrontBouncing` appends to `bounces` on every call, a repeated one too, because the fake does not copy the adapter's one-bounce-per-app guard. The `onBringToFrontBouncing` hook lets a row see the other effects at that moment.
  - Misses everything under the port.
- **Platform side: the real `WorkspaceActions`, through the same members**, in one serialized suite in `LauncherPlatformTests`, as `SystemTrackpadPreferencesTests.swift` and `SystemAppScannerTests.swift` drive their adapters: each push is awaited with a bound, never polled. The open, the watch, the gate, the deadlines, the panels and the re-entrant endings run together as they do in the app.
  - **Launched apps are real**: throwaway `.app` bundles around a test-only probe executable with P1's startup scripts (`p1-probe-app.swift`). The script is read from a key in the bundle's Info.plist, because `bringToFrontBouncing` passes no launch arguments. Each bundle has a fresh bundle ID. The suite quits, unregisters (`lsregister -u`) and deletes each one, as `World` removes its folder.
  - **A recording driver** set as `onLaunchProgress` logs `(time, app, progress)`. It ends the bounce re-entrantly on the terminal report a row names, as `Launcher.progress` does, and otherwise leaves it. It holds no policy.
  - **Time is the render server's** and cannot be advanced. Rows own it by passing the `cap` and `limit` the port takes, scaled to hundreds of milliseconds, and by bounding each wait.
  - **The screen read is injected** through `WorkspaceActions(screen:)`. A row sets the pointer in its `ScreenRead`, so the user's pointer never moves, and takes the displays from `NSScreen`. Where a row needs it, the read reports no display, or adds a second display that does not exist. Where following is under test, a posted mouse-moved event with zero motion (P2) makes the monitors read the screen again. Reduce motion is forced through `tunerOverride`'s `forceReduceMotion` where a row needs the icon at rest when it ends.
  - **Independent reads**: our own windows from the window list (owner pid, layer 1000, bounds); the probe's first on-screen window from the window list polled every 2 ms off the main actor, as P1 measured; main-actor stalls.
  - Rows that need Accessibility (the window look, posted events) run only while the test process is trusted, which this terminal is (F16).
  - **Checked feasible on this Mac**, in a scratch Swift Testing package under `swift test`, with no `NSApplication`:
    - a panel orders in;
    - a committed 0.3 s animation's delegate fires with `finished == true`, about 90 ms late;
    - the main run loop runs in its default mode;
    - `NSScreen` and `NSEvent.mouseLocation` answer;
    - the window list shows our panel at layer 1000 until it closes.
  - **Misses** what the icon does inside the display-sized panel while it bounces (its motion and pixels), and a real second display (its own Spaces, its scale).
  - **Cost**: about a minute, serialized. It moves focus to the probe apps and shows icons on screen, so hands off while it runs. `swift test --skip LaunchBounceAdapterTests` leaves it out.
- **`LaunchWatch` directly**, in the same serialized suite, in two cases: where a pid must be withheld (the test opens the probe itself and calls `opened(_:)` late), and where the watch's own reports must be seen without `WorkspaceActions`' gate and launch record in front of them. Both of those also stop reports at the port, so a row there cannot tell whether the watch's own guards hold.
- **Pure units**, for what the port cannot show. `BounceRow` and `BounceMotion` are tested like `LaunchFlightTests.swift`: keyframes are read back and requirement bounds asserted, not formulas, over its `builtIn` and `external` displays. `LaunchWatch.look` and `LaunchReportGate` are tested as `FrontmostAppWindowsTests.swift` tests its pure statics. `BounceOverlay.Deadline`'s stop rule gets one row.
- **Tuner coding**: `LaunchTuning` and `TuningPreset` JSON. These are Debug-only, and `swift test` builds Debug.
- **Source scan**: `SourcePolicyTests.swift`, with the confinement table made set-valued.

What is faked: on the model side, processes, lifecycle and time. On the platform side nothing we own. The boundary is met with scripted throwaway apps, a withheld pid, and an injected `ScreenRead`. What is manual: lag, feel, sharpness, clicks through, a real second display, the Gatekeeper dialog, real cold launches and the preview.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R16 | World | Given Figma on the 2-finger gesture with no process, and the launcher window open. When `tap(2)`. Then `bounces == [Figma, cap 10 s, limits []]`, `broughtToFront == [Figma]`, `launchAnimations == []`, feedback `== [macBook14]`, and the window is closed. The `onBringToFrontBouncing` hook sees the feedback already recorded, so the pulse comes first, in the same turn. | R1 scenario; R16 "close on the gesture as today"; today's effect order (F1) |
| T2 | R2 | World | Given the target has a process in each of four ways: in the ⌘-Tab list (Arc), frontmost only, a menu bar app (`startProcess`, never in ⌘-Tab), and an app launching from the Dock (`startProcess`). `FakeWindows` holds no window. When its gesture fires. Then `launchAnimations == [app]`, `bounces == []` and `broughtToFront == [app]`. The last two cases go red if the model reads `runningApps()` instead of `hasProcess`. | R2 scenarios; F3, F7 |
| T3 | R2, R3 | World (existing rows) | Given the six rows that expect a launch animation (`LauncherTests` lines 22, 52, 56, 62, 86 and `FiveFingerTests` line 19), each with its target made running; and the rows for an unassigned gesture, a missing assignment, inactive gestures, a swipe, a window swipe and a swap. Then all keep their expectations, and the negatives also expect `bounces == []`. | The existing rows' literals; R3 |
| T4 | R3, R16 | World | Given the launch animation setting off, and Figma with no process. When `tap(2)`. Then `bounces == []`, `launchAnimations == []`, `broughtToFront == [Figma]`, one pulse, and the window is closed. | R3 scenario "Launch animation setting off" |
| T5 | R9 | World | Given Figma bouncing. When `.windowShown` is reported, once while `.startingUp` and once after `.finishedLaunching`. Then in both cases `bounceEndings == [Figma: .launchAnimation]` and `launchAnimations == []`, because the adapter plays the hand-off. A later `.windowShown`, `.ranOut` or `.wentNowhere` adds nothing to either history. | R9; R12 "a window that shows after the bounce has ended MUST play nothing" |
| T6 | R10 | World | Given Bartender, a menu bar app, bouncing. When `.finishedLaunching` is reported twice, then `.ranOut`. Then `limits == [2 s]` exactly, the repeat adding none, and `bounceEndings == [Bartender: .launchAnimation]`. | R10 "within 2 seconds", menu bar scenario |
| T7 | R11 | World | Given Figma bouncing. When `.wentNowhere` arrives before finishing; or `.wentNowhere` after `.finishedLaunching` (a crash after startup); or `.ranOut` before finishing. Then each case ends with exactly `[Figma: .quietFade]` and no launch animation. | R11 scenarios "fails to launch", "crashes during startup", "still starting after 10 seconds" |
| T8 | R12 | World | Given Xcode and Slack, both bouncing. Then each `bringToFrontBouncing` carried `cap == 10 s`. When Xcode has reported `.finishedLaunching` and its `.ranOut` arrives (R12's late menu bar app), Then it ends with `.launchAnimation`. When `.windowShown` arrives for Xcode again, or for an assigned app that never bounced (a launch from the Dock), Then every history is unchanged. | R12 literal 10 s and its scenario; non-goal "launches Trackpad Launcher did not start" |
| T9 | R1, R14 | World | Given Figma's bounce has ended by `.windowShown`, by `.wentNowhere` or by `.ranOut`, and Figma still has no process. When `tap(2)` again. Then a new bounce starts with cap 10 s, so no record was stranded. | R1 (no process, so a bounce); design "no model record can be stranded" |
| T10 | R13 | World | Given Xcode on 1 and Slack on 2, neither with a process. When `tap(1)`, then `tap(2)`, then `.windowShown` for Slack. Then before the report `bounces == [Xcode, Slack]` (start order, newest last). After it, `bounceEndings == [Slack: .launchAnimation]` and `bounces == [Xcode]`. Xcode's later `.ranOut` ends only Xcode. | R13 scenarios "Two cold launches", "One of two ends" |
| T11 | R14, R16 | World | Given Figma bouncing and still with no process (the 60–440 ms before macOS lists it), and the launcher window reopened. When `tap(2)` again. Then `bounces.count == 1`, `broughtToFront == [Figma, Figma]`, `launchAnimations == []`, two pulses, and the window is closed. The same holds with Figma on gestures 1 and 2, tapped in turn. Without the record check this row goes red, because the fake records a second start. | R14 scenario "Impatient second tap"; F7 |
| T12 | R14, R10 | World | Given Bartender bouncing, `.finishedLaunching` reported, then `startProcess` (listed now). When `tap(5)`. Then one bounce, no launch animation, and `broughtToFront.count == 2`. When `.ranOut` arrives, Then `.launchAnimation`: the bounce is still `.startedUp`, neither restarted nor reset. | R14 scenario "Menu bar app started up, still bouncing" |
| T13 | R16, R2 | World | Given Figma bouncing and Arc running on the 1-finger gesture. When `tap(1)` fires and a swap brings an app to front. Then Arc gets its launch animation, the swap brings to front with no animation and no bounce, and Figma's bounce gets no ending and no limit. Goes red if any live bounce silences other gestures. | R16 "every gesture … and swap MUST work exactly as when no icon shows"; R2 |
| T14 | R5 | `BounceRow` | Given the shipped tuning, side 60, the built-in display (1512 × 982 @2x) and the pointer at (700, 400). When the count is 1. Then the rest (bottom centre) is (700, 408): centred on the tip, its bottom 8 pt above it. | R5 literal 8 pt and its scenario |
| T15 | R13 | `BounceRow` | Given the pointer at (700, 400). When the count is 2, then 5 (five gestures, so at most five bounces). Then two icons rest at (664, 408) and (736, 408): 12 pt between their edges, centred on the tip, the newest on the right. Five icons are centred on 700, 72 pt apart, every bottom at 408. | R13 literal 12 pt; R4 60 pt |
| T16 | R6 | `BounceRow` | Given the built-in display with the external one above it. When the tip is 10 pt from the right edge (x 1502), Then the icon's right edge is 1512. At x 1482, exactly half an icon in, it is not slid; at x 1483 it slides 1 pt. With the tip 10 pt from the left edge, the left edge is 0. Five icons at x 1502 slide as one, the rightmost edge at 1512, spacing unchanged. With the tip on the menu bar (y 970 and y 981), the rests sit at tip + 8 above the display's top, so the edge cuts them, and the display is the built-in one, never the one above. In every case `rest.y == tip.y + 8`. | R6 scenarios; literals 10 pt and 8 pt |
| T17 | R6, R7 | `BounceRow` | Given the pointer on the external 1x display at (1000, 2000), Then the display is the external one and the rest is (1000, 2008), integral. Given (700.3, 400.2) on the built-in @2x display, Then every coordinate is a multiple of 0.5. With no displays, the init returns nil. | `LaunchFlightTests` fixture displays; R7 "onto another display" |
| T18 | R13 | `BounceRow.slide` | Given the old rest (664, 408), the new rest (700, 408) and 0.2 s. Then an additive position animation whose presented point is the old rest at 0 s and the new rest at 0.2 s, easing out. Identical rests give nil. | R13 "over about 0.2 seconds" |
| T19 | R8, R4, R5 | `BounceMotion` | Given the shipped tuning, side 60, Reduce motion off. Then one cycle lasts 0.65–0.75 s and repeats forever. The first sample is on the ground, and the icon is off it within 20 ms. The top is 27–33 pt, reached by a rise whose speed falls throughout (slow at the top), followed by a fall whose speed grows throughout (gravity), then ground. At every sample the scale is 1 (60 × 60, shape kept) and the lift is ≥ 0, so with T14 the icon never covers the tip. | R8 "about half the icon's height", "about 0.7 seconds"; R4 60 × 60; R5 |
| T20 | R8, R17 | `BounceMotion` | Given squash 0.2, Then on landing the icon is 0.8 of its height and 1.25 of its width (area kept), its bottom still at rest. Given squash 0, Then no sample differs from 60 × 60. | R8 "keep its size and shape" as shipped; R17 squash "none by default" |
| T21 | R15 | `BounceMotion` | Given Reduce motion on. Then no sample lifts, scales or moves the icon, and its opacity stays within 0.5–1, pulsing once every 1.4 s, forever. | R15; the design's shipped `pulseLow` and `pulsePeriod` |
| T22 | R11, R15 | `BounceMotion.quietFade(from:)` | Given a presentation opacity of 1, 0.73 or 0.5. Then the opacity starts there, reaches 0 at 0.2 s and never rises, and nothing moves. | R11 "fade out in place within about 0.2 seconds" |
| T23 | R17 | `BounceRow`, `BounceMotion` | Each knob set away from its shipped value moves what it names and nothing else: `height` 50 gives a 50 pt top; `timeUp` 0.5 puts the top at 0.5 s; `timeDown` 0.5 makes the fall last 0.5 s; `rest` 0.3 gives 0.3 s on the ground; `gap` 20 puts the bottom 20 pt above the tip; `offset` 15 centres the row 15 pt right of the tip; `spacing` 20 puts 20 pt between icons; `fadeOut` 0.5 makes the fade last 0.5 s; `slide` 0.4 makes the slide last 0.4 s; `pulseLow` and `pulsePeriod` set the pulse's range and period. Squash is T20 and trailing is T45. | R17's list; the values the row sets |
| T24 | R9, R10 | `LaunchWatch.look` | `(registered, 0, 0)` gives `.watching`. `(registered, 1, 0)`, `(registered, 0, 1)`, `(noAccess, 0, 1)` and `(notAnswering, 0, 1)` give `.shown`. `(noAccess, 0, 0)` and `(notAnswering, 0, 0)` give `.blind`. | R9: a window, splash included, ends the bounce. R10: none, so the limit ends it. F16, F19 |
| T25 | R12 | `BounceOverlay.Deadline` | A deadline that is not cancelled calls `passed` from `animationDidStop` both with `finished == true` and with `finished == false` (a stop the system causes). A cancelled one calls nothing in either case. | Design: "A stop the system causes … counts as passed, so no bounce can outlive its cap" |
| T51 | R9, R10, R11, R12 | `LaunchReportGate` | Fed `[.finishedLaunching, .finishedLaunching, .windowShown, .windowShown, .ranOut, .wentNowhere]`, it admits `[.finishedLaunching, .windowShown]`. Fed `[.ranOut, .finishedLaunching, .windowShown]`, it admits `[.ranOut]`. Each of `.windowShown`, `.wentNowhere` and `.ranOut` is admitted alone, and nothing after it. | Port contract: "`.finishedLaunching` at most once, then at most one of the others before `endLaunchBounce`" |
| T26 | R19 | `TuningPreset` decoding | Given the preset JSON saved on this Mac before the bounce existed (the 15 flight keys), copied verbatim from `defaults export` as a fixture. When it is decoded. Then each flight knob equals the fixture's value and `bounce == LaunchTuning.Bounce()`. | The fixture; R19 scenario "Older saved preset" |
| T27 | R19, R17 | `LaunchTuning` coding | Given a tuning with every `Bounce` field set away from its shipped value, inside a preset list. When encoded and decoded. Then it is equal. A forgotten decode line turns this red. | The values the row sets |
| T28 | R19 | `LaunchTuning` coding | Given saved JSON whose `bounce` object holds only `height` and `gap`. Then those two take the saved values and the rest keep the shipped ones. | R19 "the bounce knobs keep the shipped values" |
| T29 | R1, R2 | `WorkspaceActions.hasProcess` | A probe bundle never launched gives false. Opened directly with `openApplication`, as the Dock would, with a 2 s slow start: true as soon as macOS lists the process (within 0.5 s), while `isFinishedLaunching` is still false. A menu bar probe gives true while `runningApps()` does not list it. After the probe is killed: false. | F7; the test's own launches and kills; `runningApps()` as the contrast |
| T30 | R11, R12 | `WorkspaceActions` | Given a probe that sleeps 5 s before `NSApplication` runs. When `bringToFrontBouncing(cap: 400 ms)`, with the driver ending on `.ranOut` with `.quietFade`. Then the history is exactly `[.ranOut]`, at 400–900 ms, and nothing follows in the next second. `hasProcess` is still true after the end: the app keeps starting. | R11 scenario "still starting after 10 seconds", scaled; P5 (late by up to 60 ms) |
| T31 | R10 | `WorkspaceActions` | Given a menu bar probe with no window, and `bringToFrontBouncing(cap: 5 s)`. When the driver answers `.finishedLaunching` with `limitLaunchBounce(to: 300 ms)` and ends on `.ranOut`. Then the history is `[.finishedLaunching, .ranOut]`, with the `.ranOut` 300–800 ms after the limit call, long before the cap. | R10 menu bar scenario, scaled; F12, F13 |
| T32 | R12 | `WorkspaceActions` | Given a slow-start probe that reports nothing, and a driver that does **not** end on `.ranOut`. (a) Cap 500 ms, then at once `limit(to: 2 s)`: one `.ranOut`, at 500–1000 ms. (b) Cap 2 s, then `limit(to: 200 ms)`: one `.ranOut`, at 200–700 ms, and still only one at 2.5 s, after the cap has passed. The timing proves which deadline passed. The "only one" is the contract's outcome, which both `runOut` and the gate enforce. | Design: "a later limit can never extend a bounce"; "whichever passes first reports `.ranOut`, once" |
| T33 | R12, R14 | `WorkspaceActions` | Force the interleaving. Given a slow-start probe bouncing with cap 300 ms. When at 100 ms the test ends it with `.quietFade` and, in the same turn, calls `bringToFrontBouncing(cap: 2 s)` for the same app. Then no `.ranOut` arrives before 2 s, and one arrives at 2–2.5 s. Without the cancel flag, the removed deadline's stop at the next commit would run the new bounce out at once. | Design: "Ending a bounce cancels its deadlines … before it removes the layer"; F24 (a removal stops with `finished == false` at the next commit) |
| T34 | R11, R12 | `WorkspaceActions` | Force the interleaving. Given a probe that starts in 0.3 s with a window at finish. When the test ends the bounce in the same turn as `bringToFrontBouncing`, before macOS answers. Then nothing is reported for it until 1 s after the probe has finished launching, which the test sees through its own observation. This proves the port's outcome. The watch's own guard is T46 (d), because `WorkspaceActions` drops a report for a bounce with no launch record. | Port contract "pushes nothing more for it"; F9 (macOS answers 118 ms or more later) |
| T35 | R11 | `WorkspaceActions` | Given (a) a bundle with no executable, or (b) a probe that exits 0.5 s in, before checking in. When `bringToFrontBouncing(cap: 5 s)`, and in a third run (a) with cap 500 ms and a driver that does **not** end on `.wentNowhere`. Then the history is exactly `[.wentNowhere]`, within 2 s, and nothing follows. In the third run nothing follows even when the cap passes: only the gate stands between that deadline and a second ending report. | R11 "fails to launch", "quits before a window shows"; F10, F11; port contract "then at most one of the others" |
| T36 | R11, R12 | `WorkspaceActions` | Kill at random, 10 runs. Each run uses a fresh probe that checks in after 0.4 s, finishes 0.6 s later and opens a window 2 s after that. The test SIGKILLs it at a moment drawn uniformly from 0–1.4 s after macOS first lists it, and logs the seed. Then each run's history is `[.wentNowhere]` or `[.finishedLaunching, .wentNowhere]`, with `.wentNowhere` within 1 s of the kill and nothing after: however the launch ends, the bounce ends. | The test's own log of kills and reports; F11, F12 |
| T37 | R9 | `WorkspaceActions` (trusted) | Given a probe with its window made at did-finish, and in a second case at will-finish (state restoration). Then the history is `[.finishedLaunching, .windowShown]`, and `.windowShown` arrives no later than 50 ms after the window is first on screen. | R9 literal 50 ms; F15, F16 runs 1 and 7 |
| T38 | R9 | `WorkspaceActions` (trusted) | Given a probe whose window opens 1.5 s after it finished launching. Then `.windowShown` arrives between 50 ms before and 50 ms after the window is first on screen, never at finishing. | R9 50 ms; F17 |
| T39 | R9 | `WorkspaceActions` (trusted) | Given a probe with a borderless splash at did-finish and its main window 1 s later, cap 1.5 s, and a driver that does **not** end on `.windowShown`. Then `.windowShown` arrives within 50 ms of the splash being on screen, exactly once. Nothing more arrives when the main window shows, or when the cap passes. | R9 splash scenario; F16 run 8; port contract "then at most one of the others" |
| T40 | R9, R10 | `LaunchWatch` (trusted), its report closure seen raw | Force the interleaving. Given a probe with its window at did-finish, its pid delivered as soon as macOS answers. When the report closure calls `stop()` from inside `.finishedLaunching`. Then the watch reports nothing more, although its look would have found the window. At the port, `WorkspaceActions`' launch record would hide a report sent after the end, so this row sits under it. | Design: "Each report is the watch's last act, and a guard checks `isStopped` after it" |
| T41 | R14 | `WorkspaceActions` | Given a menu bar probe bouncing whose `.finishedLaunching` has arrived. When `bringToFrontBouncing` is called again for it. Then no second `.finishedLaunching` arrives within 1 s, and our window list holds one row panel. Without the one-bounce guard, a second watch would adopt the finished app through `.initial`, and its report would pass the fresh gate of the record that replaced the first. | Port contract "One bounce per app"; R14; F8 |
| T42 | R6, R9, R11, R13 | `WorkspaceActions(screen:)` with the tip at (700, 400) on the `NSScreen` displays, + window list | Given two slow-start probes bouncing. Then our windows at layer 1000 are exactly one, framed as the display holding the tip. When the first ends with `.quietFade`, Then a second window of about 60 × 60 appears and is gone within 0.5 s, while the row stays. When the second ends with `.launchAnimation`, Then the row window is gone and a flight window larger than the icon appears and is gone within 0.6 s. A second `endLaunchBounce` for it adds nothing. 1 s later no window of ours remains. | `NSScreen`; R11 0.2 s; R13 one row; flight 0.34 s (F4); design "Once the last bounce has ended nothing of ours remains" |
| T43 | R5, R6, R11, R13 | `WorkspaceActions(screen:)` with the tip set by the row on the `NSScreen` displays, + window list, Reduce motion forced | Given one slow-start probe bouncing with the tip at (700, 400). When it ends with `.quietFade`, Then the fade window is 60 × 60 with its bottom centre at (700, 408). With the tip 10 pt from the right edge, its right edge is the display's. With the tip 30 pt below the top edge, the display's top edge cuts it and its bottom is at tip + 8. With two bounces, ending the older one puts its window's centre 36 pt left of the tip. With Reduce motion off and the bounce ended mid-jump, its bottom is between tip + 8 and tip + 38, centred on the tip. | R5 8 pt; R6 10 pt scenario; R13 12 pt; R11 "in place"; `NSScreen` |
| T44 | R12 | `WorkspaceActions(screen:)` with a `ScreenRead` that reports no display | When `bringToFrontBouncing(cap: 5 s)`. Then nothing is reported during the call, one `.ranOut` arrives on the next main-actor turn, no window of ours appears, and nothing follows. | Design: "A bounce it cannot show runs out on the next main-actor turn" |
| T45 | R7, R9, R17 | `WorkspaceActions(screen:)` with a tip the row moves, + posted zero-motion moves (trusted) + window list, Reduce motion forced | Given a bounce started with the tip at (500, 400). When the row sets the tip to (900, 500), posts one zero-motion move, waits 100 ms and ends the bounce with `.quietFade`, Then the fade window's bottom centre is at (900, 508): glued, no trail. When the tip then moves again with another posted move, Then that window does not move. With a second display that does not exist added to the read, and the tip moved onto it, the row window is re-framed to that display's frame, and a quiet end leaves the fade window at the rest there. With `trailing` 0.5 set before the bounce starts, and the end 50 ms after the move, the window sits between the two rests. Without the monitors, every case ends at the first rest. | R7 "MUST not trail" as shipped, "the tuner may set trailing", "follow the pointer onto another display"; R9 "no longer follows the pointer" |
| T46 | R10, R11 | `LaunchWatch`, pid withheld | Withhold and inject. The test opens a menu bar probe itself and keeps the pid from `opened(_:)`. (a) Delivered after the app has finished launching: exactly `[.finishedLaunching]`, through the `.initial` observation. (b) Delivered after the app was killed: `[.wentNowhere]`. (c) Delivered after finishing, with `stop()` called from a main-actor task the test enqueues right after the pid, so it runs between the adoption and the finishing hop the adoption enqueued: nothing. (d) `stop()` called before the pid is delivered: nothing, through the probe's finishing plus 1 s. | F8 (an answer that arrives after finishing); design lifecycle steps 3 and 6 |
| T47 | R16, R10 | `LaunchWatch` (trusted), with the process-wide Accessibility timeout reset to the system's for the row and restored after | Hold the blocking call. Given a probe that, on its first turn after finishing, writes a marker file, blocks its main thread for 3 s, then opens a window; the pid is withheld until the marker exists. When it is delivered. Then `.finishedLaunching` arrives, and the main actor is free again within 0.5 s of it, because each Accessibility call is bounded by `LaunchWatch.messagingTimeout` on the watch's own element. No `.windowShown` arrives, before or after the window opens: registration failed, nothing retries, and R10's limit ends the bounce. The reset matters: other rows construct `WorkspaceActions`, whose `FrontmostAppWindows` sets a 0.2 s process default that would hide a missing per-element timeout. | F18 (0.2 s messaging timeout); design O7, O8 |
| T48 | R9 | `LaunchWatch.listedWindows(of:)` | A probe whose titled window is on screen gives 1. A borderless splash gives 1. A probe whose only window sits at the status-window level gives 0. A menu bar probe gives 0, and a pid with no process gives 0. | The probes' scripts; R9 "a splash screen counts" |
| T52 | R9 | `LaunchWatch` (trusted), its report closure seen raw | Given (a) a probe with a borderless splash at did-finish and its main window 1 s later, and (b) a probe whose first window opens 1 s after finishing and a second 0.5 s after that. When nothing stops the watch. Then in each case the watch itself reports `.windowShown` exactly once: it drops the observer on `.shown`, and in its callback once it has reported. At the port the gate would hide a second report, so this row sits under it. | `LaunchWatch`'s doc: "Reports each fact at most once"; F16 run 8, F17 |
| T49 | R9 | `SourcePolicyTests` | With the confinement table set-valued, `AXUIElement` and `CGWindowList` may appear in `FrontmostAppWindows.swift` and `LaunchWatch.swift` only. The scan stays green, and a use in a third file fails it. | The design's "Docs and source policy" |
| T50 | R7 | `SourcePolicyTests` | `mouseMoved` may appear only in `BounceOverlay.swift` and `ClickTap.swift`; `addGlobalMonitorForEvents` only in `MenuBarShell.swift` and `BounceOverlay.swift`; `addLocalMonitorForEvents` only in `BounceOverlay.swift`. The scan stays green, and a use elsewhere fails it. | The design's "Docs and source policy"; D2 |

### Verified without a test

Run every manual check on a Debug build after "Reset to shipped" (plan 014).

- **R1, R8, R16 (manual).** Assign Slack to the 2-finger gesture and quit Slack. Make the gesture. Slack's icon appears just above the pointer with the haptic and starts jumping at once, nothing floats up, and Slack launches. While it bounces, open a second app that is not running from the Dock: both icons jump at a similar height and rhythm. Click a button under the icon and scroll under it: both reach the app beneath. Make another gesture, a swipe, a window swipe and a swap: each behaves as with no icon. With the launcher window open, the gesture closes it.
- **R1 (review).** `bringToFrontBouncing` calls `open(_:then:)` before `BounceOverlay.start`. This is the "bring to front first" contract that, as the tradeoffs say, the model's tests cannot observe.
- **R4 (manual).** Take screenshots at the top of a jump and at rest on the Retina display: no blur or pixelation. Repeat on a 1x display after the pointer crosses onto it (a two-display Mac, O6).
- **R7 (manual and sampler).** Move the pointer fast in circles while an icon bounces: no gap opens between the pointer and the icon. Move it onto a second display: the icon keeps bouncing there, sharp (O6). With `Scripts/perf/sampler.c` attached, 30 s of pointer movement after the last bounce ended costs the app no more CPU than 30 s hands-off: no monitor is left, so the pointer is read only while a bounce shows.
- **R9 (manual).** Cold-launch Xcode and watch for the window to show while the icon is near the top of a jump: the icon floats away from that spot, and moving the pointer afterwards does not move it. An app with a splash screen ends the bounce at the splash. Remove the Debug build from the Accessibility list: an app whose window shows during launch usually still ends the bounce at once, and one whose window comes later ends it 2 s after finishing (O1).
- **R10 (manual).** Launch a menu bar app that is not running: its icon floats away about 2 s after the Dock stops bouncing its icon. An app whose window opens on another Space floats away 2 s after finishing (O4).
- **R11 (manual).** Use a freshly downloaded, quarantined app and leave macOS's "are you sure" dialog unanswered: the icon bounces until 10 s after the gesture, then fades in place (O5).
- **R13 (manual).** Make two cold launches: two icons side by side, the second on the right. When one window shows, the other icon slides to the centre over about 0.2 s, also while the pointer moves.
- **R15 (manual).** Turn Reduce motion on and cold-launch an app: its icon pulses above the pointer without moving up or down, follows the pointer, and fades in place when the window shows. When the launch goes nowhere, it fades in place too.
- **R17 (manual and build).** The tuner shows a Launch bounce section with a control for each of the ten knobs. Raise Jump height mid-bounce: the current bounce keeps its height and the next jumps higher. Set trailing to 0.3: the row lags behind the pointer. `swift build -c release` builds, and a grep shows every new tuner symbol and the bounce's `Codable` inside `#if DEBUG`, so Release plays the shipped bounce and shows no tuner.
- **R18 (manual).** Press Preview bounce. Finder's icon bounces above the pointer for about 3 s, following it over the tuner, then floats away.

## Slices

### S1: Prefactor: shared flight staging, set-valued confinement, launch probes

**What to build:** Nothing the user sees changes. The launch animation can start from any point. The bounce can reach the overlay's icon cache and panel recipe, and the rule for the pointer's display is shared. The source scan can confine a token to several files. The platform tests can build scripted throwaway apps and clean them up.

**Blocked by:** None (can start immediately).

**Requirements:** None (prefactor).

**Test scenarios:** None.

- [ ] `LaunchOverlay.play(for:from:among:)` exists, and `play(for:)` calls it with `ScreenRead.now()`'s pointer and displays. `LaunchDisplay.containing(_:among:)` replaces the flight's private display rule. `bitmap(for:scale:)` and `makePanel(frame:)` are internal. The existing suite stays green (580 tests).
- [ ] `Confined.onlyIn` is a set of file names, every entry keeps its meaning, and the scan's own self-test still passes.
- [ ] A test-only probe executable builds with `swift test`, outside the scanned roots. It reads P1's startup scripts from its bundle's Info.plist and adds three: block the main thread inside will-finish; write a marker file, then block on the first turn after finishing; open its only window at the status-window level.
- [ ] A test helper builds one bundle per script with a fresh bundle ID, or one without its executable. When its test ends, even if an expectation failed, it quits, unregisters and deletes every bundle it built.

### S2: A cold launch bounces above the pointer and ends on its launch, its failure or its time

**What to build:** A gesture for an assigned app with no process bounces the app's icon above the pointer, with the haptic, instead of floating it up, and the app launches. Several cold launches bounce in one row, newest on the right. Each bounce ends with the launch animation 2 s after its app finished launching. It fades in place instead when the launch fails, the app quits, or 10 s pass while the app is still starting, and the other icons slide to their new places. A repeated gesture keeps the one bounce. Running apps keep the launch animation. Under Reduce motion the icon pulses. Windows do not end a bounce yet (S3), the icon does not follow the pointer yet (S4), and the tuner does not know the bounce yet (S5).

**Blocked by:** S1.

**Requirements:** R1, R2, R3, R4, R5, R6, R8, R10, R11, R12, R13, R14, R15; R16 (the window closes, the panel is click-through); R17 (each knob shapes the bounce).

**Test scenarios:** T1–T23, T25, T51, T29–T36, T41–T44, T46.

- [ ] The launch bounce vocabulary, `LaunchBounce` with its `Step` table, `Launcher.bounces`, `visual(for:)`, the three-way `fire`, and `progress(_:of:)` installed in `start()`, as designed.
- [ ] `SystemActions` gains `hasProcess`, `bringToFrontBouncing(_:cap:)`, `limitLaunchBounce(of:to:)`, `endLaunchBounce(of:with:)` and `onLaunchProgress`, with the design's contract text. `RecordingSystemActions` and `World` gain the surface the strategy names.
- [ ] `WorkspaceActions` warms `hasProcess` in its internal `init(screen:)`, behind the public convenience `init()` that reads `ScreenRead.now`. It implements `open(_:then:)` and keeps one `Launch`, a watch plus its `LaunchReportGate`, per bounce. Every report, from the watch or from the deadlines, passes `report(_:of:)`.
- [ ] `LaunchWatch` runs without the window look: the answer, both observations, `stop()`.
- [ ] `BounceOverlay(flights:screen:)` runs without pointer monitors: the row panel, `BounceRow` rests, `BounceMotion`, the deadlines (`BounceOverlay.Deadline`, internal) with their fail-safe, both endings, the re-flow slide, and the Debug `preview`.
- [ ] `LaunchTuning.Bounce` carries the shipped defaults.
- [ ] `Ports.swift` carries the design's contract text and loses "the completion is ignored". The banned-token scan stays green. The code matches `docs/domain-model.md` (Launch bounce, Launch animation, Launch animation setting, Bring to front) and `docs/architecture.md`'s Concurrency section (the push list, time on Core Animation's clock), which planning already updated.
- [ ] The manual checks for R1, R4, R8, R11, R15 and R16 pass, and so does R10's menu bar app.

### S3: The bounce ends when the app's window shows

**What to build:** When the launching app's first window shows, a splash screen included, its bounce ends within 50 ms with the launch animation, from wherever the icon is. Without Accessibility, a window made during launch still ends it, and a later one waits for the 2 s. A launching app that does not answer cannot stall gestures for longer than the messaging timeout.

**Blocked by:** S2.

**Requirements:** R9; R16 (a hung app cannot stall gestures).

**Test scenarios:** T24, T37, T38, T39, T40, T47, T48, T49, T52.

- [ ] `LaunchWatch` takes its one look at finishing: Accessibility registration on the app element it creates, with `LaunchWatch.messagingTimeout` set on that element; `listedWindows(of:)`; the pure `look`. The observer is dropped on `.shown`, and in its callback once it has reported. All of it is undone by `stop()`.
- [ ] The code matches `docs/architecture.md`'s Privacy section as planning updated it: Accessibility also notices the first window of an app a gesture is launching, the "without Accessibility" sentence's late-window case, and the second window file in the confinement sentence.
- [ ] The human has answered O1 and O7, accepting that R9 as written is not met in those cases or amending R9, before merge.
- [ ] The manual checks for R9 and for R10's window on another Space pass.

### S4: The icon follows the pointer, onto any display

**What to build:** While any bounce shows, the row stays glued above the pointer on every move and drag. It re-frames onto another display and re-scales its icons there. An ended icon no longer follows. Once the last bounce has ended, nothing of ours reads the pointer. The trailing knob, set by hand, makes the row lag for experiments.

**Blocked by:** S2.

**Requirements:** R7; R9 (an ended icon stays where it is); R13 (the slide composes with moves); R16 (the monitors are passive); R17 (trailing).

**Test scenarios:** T45, T50.

- [ ] `BounceOverlay`'s global and local monitors exist from the first bounce until the last ends. On each event, `moved(_:)` takes a fresh `ScreenRead`, re-frames to the pointer's display, updates each icon's `contentsScale`, and applies `trailing`.
- [ ] The tuner panel accepts mouse-moved events, so a bounce follows the pointer over it.
- [ ] The human has signed off D2 and D1, which planning already wrote into `docs/architecture.md`: the Privacy line on the pointer's position and the pointer-event files in the confinement sentence; in Concurrency, input-driven work while an effect shows and pointer moves in the push list. The code matches them.
- [ ] The manual checks for R7 (including the sampler) and R13 pass.

### S5: The tuner tries, previews and saves the bounce

**What to build:** The animation tuner in Debug builds gains a Launch bounce section, with a control for each bounce knob and a Preview bounce button. The button bounces Finder's icon for 3 s, then floats it away. Tunings and presets save and load the bounce knobs, and an older preset keeps the shipped bounce. Release builds play the shipped bounce and show no tuner.

**Blocked by:** S4.

**Requirements:** R17, R18, R19.

**Test scenarios:** T26, T27, T28.

- [ ] `LaunchTuning.Bounce` gains its tolerant Debug decoding, and `LaunchTuning.init(from:)` its `bounce` line. T26's fixture is the preset JSON saved on this Mac, copied verbatim.
- [ ] `AnimationTuner.init(preview:previewBounce:)`, the section and footer as designed, and `WorkspaceActions`' second preview closure exist.
- [ ] The manual checks for R17 (including the Release build) and R18 pass.
