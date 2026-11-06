# Plan: Hide background apps

## Problem statement

The user wants one app on screen at a time. Trackpad Launcher brings an app to the front, but every other app stays visible behind it. To clear them, the user must also press ⌘⌥H after each gesture. That adds a keyboard step to a trackpad flow.

## Solution

A new *Hide background apps* switch in the settings window. While it is on, each tap, swipe lift, swap or window swipe lift that brings an app or window to the front also hides everything else, as ⌘⌥H does. A silent action hides nothing. Hidden apps stay reachable: the switcher lists them, the swap reaches them, and bringing one to the front shows it again.

## Requirements

### R1. The setting is a switch in the thumb corner group
The settings window MUST show a *Hide background apps* switch in its third group, directly below the thumb corner row.

#### Scenario: Reading the third group
- **WHEN** the user opens the settings window
- **THEN** the third group shows the thumb corner row, then the *Hide background apps* switch

### R2. The setting is off by default
The setting MUST be off on a fresh install and for a user upgrading from a version without it.

#### Scenario: Upgrading keeps the current behaviour
- **GIVEN** a user with saved settings from an earlier version
- **WHEN** they tap a gesture after updating
- **THEN** the target app comes to the front and no other app is hidden

#### Scenario: Fresh install
- **GIVEN** a Mac with no saved settings
- **WHEN** the user first opens the settings window
- **THEN** the switch is off

### R3. The setting survives a relaunch
The app MUST keep the user's choice across a relaunch and a login start.

#### Scenario: Switch stays on
- **GIVEN** the user turned the switch on
- **WHEN** Trackpad Launcher relaunches
- **THEN** the switch is on and gestures hide background apps

#### Scenario: Login start
- **GIVEN** the user turned the switch on
- **WHEN** Trackpad Launcher starts at login
- **THEN** gestures hide background apps

### R4. Changing the setting hides and shows nothing
Flipping the switch MUST NOT hide or show any app. It only affects later actions.

#### Scenario: Turning it on
- **GIVEN** three apps are visible
- **WHEN** the user turns the switch on
- **THEN** all three stay visible until the next action that hides

#### Scenario: Turning it off
- **GIVEN** the switch is on and two apps are hidden
- **WHEN** the user turns the switch off
- **THEN** both apps stay hidden
- **AND** later gestures hide nothing

### R5. A tap hides everything but its target app
While the setting is on, a tap that brings its target app to the front MUST hide everything else. This holds when the target app is already in front. A tap on that app is never silent, so it still hides.

#### Scenario: Tap on a running app
- **GIVEN** the setting is on and Mail, Safari and Notes are visible
- **WHEN** a tap brings Safari to the front
- **THEN** Safari stays visible, and Mail and Notes are hidden

#### Scenario: Tap on the app already in front
- **GIVEN** the setting is on, Safari is in front and Mail is visible behind it
- **WHEN** the user taps the gesture assigned to Safari
- **THEN** Mail is hidden

#### Scenario: Silent tap
- **GIVEN** the setting is on
- **WHEN** the user taps a gesture with no assignment, or one whose assigned app is no longer installed
- **THEN** no app is hidden

### R6. A swipe lift hides everything but the selected app
While the setting is on, a swipe lift that brings an app to the front MUST hide everything else.

#### Scenario: Lift on another app
- **GIVEN** the setting is on and Notes is in front
- **WHEN** the user lifts a swipe on Safari
- **THEN** Safari is in front, and every other app is hidden

### R7. A swap hides everything but the app it brings forward
While the setting is on, each swap MUST hide everything else, including the app it replaced.

#### Scenario: Swap series
- **GIVEN** the setting is on, Safari is in front and Mail was used before it
- **WHEN** the user swaps, then thumb taps again under the same fingers
- **THEN** after the first swap Mail is visible and Safari is hidden
- **AND** after the second swap Safari is visible and Mail is hidden

### R8. A window swipe lift that changes the front window hides every other app
While the setting is on, a window swipe lift that puts a different window in front MUST hide every app except the frontmost app. The frontmost app's own windows stay as the lift left them.

#### Scenario: Lift on another window
- **GIVEN** the setting is on, Safari is in front with two windows, and Mail is visible
- **WHEN** the user lifts a window swipe on Safari's other window
- **THEN** that window is in front, Safari's other window stays just behind it, and Mail is hidden

#### Scenario: Passing windows while sliding
- **GIVEN** the setting is on and Mail is visible
- **WHEN** windows come to the front as the fingers pass them
- **THEN** Mail stays visible until the lift

### R9. An action that changes nothing hides nothing
While the setting is on, an action MUST NOT hide anything when it brings nothing to the front and changes no window. This holds for every silent swipe, window swipe and thumb tap.

#### Scenario: Lift on the starting app
- **GIVEN** the setting is on and Mail is visible behind the frontmost app
- **WHEN** the user lifts a swipe on the starting app
- **THEN** Mail stays visible

#### Scenario: Cancelled window swipe
- **GIVEN** the setting is on and Mail is visible behind the frontmost app
- **WHEN** a window swipe is cancelled
- **THEN** Mail stays visible

#### Scenario: Selected app quit during the swipe
- **GIVEN** the setting is on and the selected app quit during the swipe
- **WHEN** the user lifts
- **THEN** no app is hidden

#### Scenario: Lift on the window already in front
- **GIVEN** the setting is on and Mail is visible behind the frontmost app
- **WHEN** the user lifts a window swipe on the front window
- **THEN** Mail stays visible

#### Scenario: Thumb tap with nothing to swap to
- **GIVEN** the setting is on and the swap has no app to go to
- **WHEN** the user taps the thumb under two resting fingers
- **THEN** no app is hidden

### R10. A launching app hides the others once it shows a window
While the setting is on, a gesture that launches an app that is not running MUST leave other apps visible until the launched app shows a window. It MUST then hide everything else.

#### Scenario: Slow launch
- **GIVEN** the setting is on and Mail is visible
- **WHEN** a gesture launches an app that takes five seconds to show a window
- **THEN** Mail stays visible for those five seconds
- **AND** Mail is hidden once the window shows

#### Scenario: Launch animation off
- **GIVEN** the setting is on and the launch animation setting is off
- **WHEN** a gesture launches an app
- **THEN** other apps hide once the launched app shows a window

### R11. A launch that never shows a window hides nothing
A launch that fails, or that shows no window within the time limit, MUST hide nothing. The limit is reached when the launched app shows no window within 10 seconds, or within 2 seconds of finishing launching, whichever comes first. These are the launch bounce's limits.

#### Scenario: App cannot launch
- **GIVEN** the setting is on
- **WHEN** a gesture targets an app macOS cannot open
- **THEN** no app is hidden

#### Scenario: App opens without a window
- **GIVEN** the setting is on
- **WHEN** a launched app finishes starting and shows no window before the time limit
- **THEN** no app is hidden

### R12. A launch the user left hides nothing
If another app is in front when the launched app shows its window, that launch MUST hide nothing. If the user moved away and came back to the launched app before its window showed, the launch hides as usual.

#### Scenario: User switches during the launch
- **GIVEN** the setting is on and a gesture is launching Slack
- **WHEN** the user clicks Mail in the Dock, and Slack's window then shows
- **THEN** Slack's launch hides nothing

### R13. Hiding reaches what ⌘⌥H reaches
Hiding MUST cover the same apps as ⌘⌥H: every other running app with a Dock icon, on every display and Space, Finder included. A full-screen app follows what ⌘⌥H does to it. Menu bar apps stay as they are. The Desktop's icons stay.

#### Scenario: App on a second display
- **GIVEN** the setting is on and Notes is visible on a second display
- **WHEN** a tap brings Safari to the front on the first display
- **THEN** Notes is hidden

#### Scenario: Finder windows
- **GIVEN** the setting is on and a Finder window is open
- **WHEN** a tap brings Safari to the front
- **THEN** the Finder window is hidden and the Desktop's icons stay

#### Scenario: App on another Space
- **GIVEN** the setting is on and Notes has a window on another Space
- **WHEN** a tap brings Safari to the front
- **THEN** Notes is hidden

### R14. The settings window hides with everything else
An action that hides MUST hide an open settings window too, unless the settings window is the frontmost app.

#### Scenario: Gesture while settings is open
- **GIVEN** the setting is on and the settings window is open
- **WHEN** a tap brings Safari to the front
- **THEN** the settings window is hidden

#### Scenario: Settings window hidden, gestures go on
- **GIVEN** the settings window is hidden by this feature
- **WHEN** the user taps a gesture
- **THEN** the gesture works as usual

#### Scenario: Settings window in front
- **GIVEN** the setting is on and the settings window is open behind Safari
- **WHEN** a swap brings the settings window to the front
- **THEN** the settings window stays visible and every other app is hidden

### R15. The Dock icon stays while the settings window is hidden
Trackpad Launcher's Dock icon MUST stay while the settings window is hidden.

#### Scenario: Hiding the settings window
- **GIVEN** the setting is on and the settings window is open
- **WHEN** a tap hides the settings window
- **THEN** Trackpad Launcher's Dock icon stays

### R16. Opening Trackpad Launcher shows the hidden settings window
Opening Trackpad Launcher from the Dock or anywhere else MUST show the hidden settings window.

#### Scenario: Bringing the settings window back
- **GIVEN** the settings window is hidden by this feature
- **WHEN** the user clicks the Dock icon
- **THEN** the settings window shows again at the same position with the switch still on

### R17. Trackpad Launcher's own visuals keep playing
Hiding MUST NOT cut short or remove the launch animation, launch bounce, switcher or window switcher. Haptic feedback MUST stay the same.

#### Scenario: Launch animation with settings open
- **GIVEN** the setting is on and the settings window is open
- **WHEN** a tap brings a running app to the front
- **THEN** the settings window is hidden and the launch animation plays in full

#### Scenario: Swipe right after hiding
- **GIVEN** the settings window was hidden by an earlier gesture
- **WHEN** the user starts a swipe
- **THEN** the switcher shows as usual

### R18. Hidden apps stay in the switcher
Hidden apps MUST stay in the switcher with their look unchanged. They MUST keep their relative order.

#### Scenario: Switcher after hiding
- **GIVEN** the setting is on and Mail and Notes were hidden
- **WHEN** the user swipes
- **THEN** the switcher lists Mail and Notes, and they keep their relative order

### R19. A swap treats a hidden app like any other app
A swap MUST treat a hidden app like any other app.

#### Scenario: Swap to a hidden app
- **GIVEN** Mail is hidden and was used before Safari
- **WHEN** the user swaps
- **THEN** Mail shows and comes to the front

### R20. Bringing a hidden app to the front shows it
Bringing a hidden app to the front MUST show it.

#### Scenario: Assigned hidden app
- **GIVEN** Safari is hidden and has a gesture
- **WHEN** the user taps that gesture
- **THEN** Safari shows and comes to the front

#### Scenario: Lift on a hidden app
- **GIVEN** the setting is on and Notes, which has no gesture, was hidden by an earlier tap
- **WHEN** the user lifts a swipe on Notes
- **THEN** Notes shows, comes to the front, and every other app is hidden

### R21. The setting needs no new permission
Turning the setting on or hiding apps MUST NOT trigger a permission prompt.

#### Scenario: Turning it on with existing permissions
- **GIVEN** the setting is off and the app holds the permissions it had before this version
- **WHEN** the user turns the switch on and taps a gesture
- **THEN** the other apps hide and no permission prompt shows

### R22. The app brought forward keeps the front
Hiding MUST NOT take the front from the app brought forward, whether that app was hidden or not, with single gestures or rapid ones. Every other app MUST end up hidden.

#### Scenario: Bringing back a hidden app
- **GIVEN** the setting is on and Calculator is hidden behind Dictionary
- **WHEN** a gesture brings Calculator to the front
- **THEN** Calculator is in front and Dictionary is hidden, and no third app takes the front

#### Scenario: Another app activates meanwhile
- **GIVEN** the setting is on
- **WHEN** a helper activates itself before the target app comes to the front
- **THEN** every other app still hides once the target app is in front

### R23. A launch hides on a window the user can see
A launch MUST count a window only when it is on screen. A hidden startup window MUST NOT hide other apps. The launch keeps watching until a window shows or its time limit passes.

#### Scenario: Hidden startup window
- **GIVEN** the setting is on and a launching app creates a hidden window, then shows its real window later
- **WHEN** the hidden window is created
- **THEN** no app hides until the real window is on screen

## Non-goals

- Hiding after actions outside Trackpad Launcher, such as ⌘-Tab, Dock clicks or Spotlight. The user asked for Trackpad Launcher's own actions, and it does not react to these today.
- Showing hidden apps again when the setting turns off. ⌘⌥H has no such undo, and the user agreed the switch only affects later actions.
- Per-app exceptions. The setting mirrors ⌘⌥H, and the user chose that everything hides.
- Marking hidden apps in the switcher. ⌘-Tab does not mark them either.
- Hiding individual windows of the frontmost app. ⌘⌥H works on whole apps.
- Hiding when the settings window opens. Opening the app is not a gesture.

## Implementation Decisions

Every claim marked *(probe)* was measured during planning on this Mac with the scripts under `.temp/` (scratch apps only; the hide probe, the full-screen probe, the self-hide probe, the activation probe, the no-`NSApplication` clock probe, the enumeration-cost probe and the post-review probe). The scripts print their results; the numbers quoted here are from the runs made while planning.

- **One new setting, off by default, saved like its siblings.** The settings record gains a Boolean field for the hide, under a key that is the field's name permanently, read with the record's decoding rule (absent reads as off, so every record written so far, and a downgrade's, keep today's behaviour; an undecodable value fails the whole record as for every field). The model exposes whether it is on and one intent to set it, which saves at once and re-runs nothing: no recognizer reads it, and flipping it hides and shows nothing. The settings view's third section holds the thumb corner row and then the switch, titled *Hide background apps*, in the form's own switch style like *Animate app launch*; the window's height rule is untouched because the switch always shows.

- **The model decides every hide; the adapter performs "hide every other app" without disturbing the ⌘-Tab order.** `SystemActions` gains one member, hide every other app than one, keyed by bundle identifier: it hides every running app with a Dock icon (the regular activation policy, which is exactly the set ⌘⌥H covers: Finder in, menu bar apps out) whose bundle identifier differs, every copy of the kept bundle staying as `hasProcess` counts copies, Trackpad Launcher itself included when its own Dock icon shows (see the settings-window decision), on every display and Space, full-screen apps included *(probe: a full-screen app on its own Space hides, and comes back full-screen when brought to front)*. It is idempotent and needs no permission (the public hide of a running app, and the app's own hide for itself). Two mechanics are the adapter's own, because they concern how macOS reacts to a hide, not what is hidden:
  - **The app that is frontmost at the call, when it is not the kept app, is hidden only once the kept app has come to the front**, on the workspace's activation push for it. Hiding the frontmost app at once makes macOS activate the next visible app, and in the common race that app lands second in the ⌘-Tab order, above the app the user came from, which would send the next swap to a third app *(post-review probe: with the hide in the same turn as the open, a third visible app landed second in three series steps out of four; hidden after the target's activation, the previous app stayed second in every step of every probe)*. The pending hide is forgotten when another app activates first, when the next hide call comes, and once it has fired; its observer exists only while it is pending, so nothing runs otherwise. When the kept app is already frontmost (a tap on the app in front, a window swipe lift, a launch whose window showed) nothing is deferred. A rapid second swap before the first one's activation lands drops the first's pending hide and the kept app's own late open unhides it, so the app the series started from can end visible behind the front app; the series itself still alternates, as the in-flight rule has it.
  - **The immediate hides go out on the next main-actor turn**, after the gesture's own turn has committed the bring-to-front and the launch animation's first frame: a hide costs about 0.75 ms per visible app and 0.25 ms per already hidden one, reading `isHidden` first costs as much as the call *(post-review probe)*, so fifteen visible Dock apps are about 11 ms the first time and 3–4 ms once most are hidden, and the enumeration itself 0.02 ms *(probe)*.
  The model calls it exactly where an action brought something to the front:
  - in `fire`, after the bring-to-front and, when it plays, after the launch animation, so the hides never delay either;
  - on a swipe lift that brings the selected app to the front;
  - on a swap that brings an app to the front;
  - on a window swipe lift whose lift plays the haptic (that flag is defined as "a different window in front, or a minimised one restored", which is R8's condition), keeping the window switcher's app, after the raises; the lift keeps using `raiseWindows`, never `bringToFront`.
  Every silent path hides nothing by construction: the hide sits after the guard that silences the action (inactive gestures, no assignment, a missing app, a lift on the frontmost app, an app that quit, a cancelled window swipe, a lift on the front window, nothing to swap to). With the hide setting on, `fire` reads `hasProcess` even with the launch animation off, so that a gesture whose app has no process brings it to front without an immediate hide: that launch's hide waits for its window (the watched-launch decision), or, before that decision is built, never comes.

- **A watched launch: the bounce's record generalised.** The model's per-launch record (today the bounce's two-case enum) becomes a small value, `WatchedLaunch`: the stage (starting up or started up, the same six-transition table on `LaunchProgress`, the same 10 s cap and 2 s grace) and whether its first window hides the others. Nothing in the model reads whether the bounce shows, so the record does not carry it: the table and the limit are the same either way, and the adapter ignores an ending when no bounce shows. The model keeps one record per launched bundle, as today. `fire` reads `hasProcess` when the launch animation setting or the hide setting is on (with both off it is not read, as today); with no process it asks the adapter to bring the app to front *watching* its launch, bouncing exactly when the launch animation setting is on, and records the launch with "hides others on window" set from the hide setting. A gesture for an app whose launch is already watched keeps the one watch as it is, bouncing or unseen (the launch animation setting applies to the next launch, as its entry says), brings the app to front as today, and re-arms "hides others on window" from the setting now, so the latest gesture's setting counts; the switch itself, flipped with no gesture, changes no record (R4). The progress handler keeps its table; when a `.windowShown` ends a launch whose record says so, and the launched app is the frontmost app at that moment (the existing `runningApps()` read, a few milliseconds on a launch push, never on the gesture path), it hides every other app, after the end so the bounce's launch animation starts first. `.wentNowhere` and `.ranOut` never hide, and a launch that ended leaves no record, so a late window hides nothing. One contingency, decided by S4's manual check: plan 017 accepted that an Electron or Chromium app may report its window created (`kAXWindowCreated`) for a hidden startup window, which was cosmetic for an icon and here would hide the other apps a moment before anything shows; if Slack, Figma or Chrome hides early, the watch reports `.windowShown` from the observer only once the window list shows an on-screen window of the app, re-looking on its clock as the no-Accessibility path does.

- **R12 is a read at the moment the window shows, not an activation push.** *(probe, from an app process like ours)*: LaunchServices activates a launched app about 90 ms after the open, long before its first window (0.5–1.6 s later); a user switch to another app mid-launch lands before the window, and the launched app does not take focus back when its window shows; and activation pushes carry system noise (Chess's `GameOverlayUI` helper activated itself and handed back a second later), so "any other activation cancels the hide" would misfire. Comparing the frontmost app with the launched app when the window shows is exact for the user's Dock click (frontmost is Mail: hide nothing) and for the model's own later actions (a second gesture, swipe or swap left its app frontmost). A splash screen cannot defeat it: the activation precedes any window. The record's flag, not the read alone, decides, so a launch started with the setting off never hides. A user who switched away and came back before the window gets the hide, as R12 says: the read hides exactly when the user is in the launched app. An activation observer in the watch is rejected: it would also cancel on the system noise the probe saw.

- **Port: the bounce members become launch members.** `bringToFrontBouncing(_:cap:)` becomes `bringToFrontWatching(_:cap:bouncing:)`: opens the app first exactly as `bringToFront` does, then watches its launch and pushes `onLaunchProgress` for it until the end, and, when `bouncing`, shows the launch bounce; one watch per app, a second call while one runs only brings the app to front. `limitLaunchBounce(of:to:)` becomes `limitLaunch(of:to:)`, and `endLaunchBounce(of:with:)` becomes `endLaunch(of:with:)`: stops the watch and its clock, and ends the bounce with the given ending when one shows, otherwise ignores the ending. `onLaunchProgress`, `LaunchProgress` and `LaunchBounceEnding` keep their shapes and their ordering rules, but their texts say "launch" where they say "bounce" today ("only for an app whose bounce plays" becomes "whose launch is watched"; `.ranOut`'s "the bounce reached a time limit" becomes the watch's), rewritten in the slice that changes each behaviour. One consequence, from S1 on: a bounce that cannot show (no display) no longer runs the launch out on the next turn; the watch runs as usual and only the icon is missing, and the port text that promised the early run-out goes with it.

- **The watch owns its clock; the bounce only draws (prefactor).** A new internal platform type, `LaunchClock`, holds one zero-size layer per watched launch in a one-point borderless panel that is never ordered in, made with the first clock and closed when the last one stops. A deadline is a 1→1 opacity animation on that layer whose stop is the push, with the fail-safe moved from the bounce's deadline (a stop the system causes counts as passed; a cancelled one reports nothing); stopping the clock cancels every deadline and removes the layer. *(probe: deadlines on such a layer pass on time, about 90 ms late as plan 017 measured for shown panels, with and without `NSApplication`, and while the app is hidden; a detached layer's animation stops at once with `finished == false`, so a window is needed; a removed sublayer's stops early with `finished == false`, so the cancel flag stays.)* `LaunchWatch` gains starting with a cap and limiting, both deadlines reporting `.ranOut` through the adapter's gate, and takes its 50 ms re-look waits on the same clock; stopping the watch stops the clock. `BounceOverlay` loses its deadlines, limits, `after` and `ranOut`: it starts a bounce and ends one; the Debug preview runs until the tuner stops it, as the tuner already does on toggle and disappearance.

- **The settings window hides with the others and comes back on any opening by hand.** No model change: `Launcher.window` stays open while the app is hidden, as it does while minimised, so the updater, the quit rules and the window's request count are untouched. The adapter hides Trackpad Launcher with the app's own hide when its Dock icon shows (the regular policy, exactly while the window is open) and it is not the kept app; the activation policy is not touched, so the Dock icon stays *(probe: the policy reads regular after the hide)*. The shell's rendering of an open window unhides the app before ordering the window front and activating, so every opening by hand (the Dock icon, Spotlight, Finder, a swap or a lift on Trackpad Launcher, all of which reach `openedByHand`) shows the window where it was, with its state *(probe: the window's frame is identical after hide and unhide; activation alone also unhides, so the explicit unhide documents the path and covers closing while hidden and reopening)*. The Dock's Quit while hidden closes the window as today, and the shell's rendering of a closed window, after ordering the window out and leaving the Dock, unhides the app without activating it, so the process is never left hidden with no window *(post-review probe: after `orderOut` the unhide leaves the window out, the hidden state cleared and the frontmost app untouched)*.

- **Overlays never hide with the app.** `canHide` is false on `OverlayPanel` (both switchers), on every panel `LaunchOverlay` makes (launch animations, the bounce row, quiet fades) and on the clock host. *(probe: a non-activating, screen-saver-level panel with `canHide` false stays visible through the app's hide, and animations added to its layer before and during the hide complete on time; post-review probe: a panel ordered in while the app is hidden shows whatever its `canHide` and `defer`, so the flag matters exactly for the panels already up when a hide lands, which are the switcher fading out after a lift and the launch animation or bounce started in the same turn as the hide.)* The Debug animation tuner's window hides with the app; it is a developer tool and comes back with the next opening.

- **Hidden apps need no handling in the model.** LaunchServices' ⌘-Tab order lists hidden apps in their place *(probe)*, so the switcher's row and the swap's target see them unchanged; `bringToFront` (an `openApplication` with activation) unhides *(probe)*, so a lift, a swap or a gesture on a hidden app shows it; the model never reads hidden-ness. The in-memory adapter models the effect (which apps are hidden now, cleared by a bring-to-front) so the model's rows read like the requirements.

- **Source policy.** The hide call (`.hide(`) is confined to the one adapter file, beside the other confined effects. Nothing banned is used: no timer (the clock is Core Animation), no event posting, no Apple event.

- **Documentation (done during planning).** The product overview gains the switch. The domain model gains *Hide background apps setting* and *Launch watch*, and *Trackpad Launcher*, *Settings window*, *Bring to front*, *Launch bounce* and *Launch animation setting* are amended. The architecture's Concurrency section names the launch watch in the push list, puts the watch's deadlines on its own clock layer in the deadline rule, and ties the repeating window-list read to the watch; its Privacy section says the window observer runs while a launch is watched, and confines the hiding of apps to one file.

## Testing Decisions

### Strategy

One seam carries the feature: the `SystemActions` port, crossed from the model side by the real `Launcher` over `RecordingSystemActions` in `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`), as `LaunchBounceFiringTests.swift`, `SwapTests.swift`, `SettingsWindowAsAppTests.swift`, `WindowSwitchingTests.swift` and `PersistenceTests.swift` cross it. The fake gains two records, one effect and one hook: every hide, by the app it kept, in order; every watched launch with its cap, whether it bounces and the limits set on it (the bouncing ones still readable as today's `bounces`, so the existing rows keep their literals); which apps are hidden now, computed as every ⌘-Tab app and the frontmost app but the kept one, cleared for an app by any bring-to-front, hidden at once (the adapter's deferral of the frontmost app and its next-turn hop are its own mechanics, verified without a test); and an `onHideOtherApps` hook run inside the hide, like `onPlayLaunchAnimation`, so a row can see what was already recorded when the hide came. Time is the test's: `.ranOut` is pushed, never waited for. The frontmost app is the test's (`makeFrontmost`). These rows observe every decision (what was hidden, after what, and what was not) and miss everything under the port: the real hide, the real clock, the shell. The fake's hidden set is modelling of the adapter's contract, so rows that only read it back prove nothing about the model; the rows below assert the model's targets and the hides it ordered, and leave "a hidden app shows again" to the manual checks.

Under the port, the launch watch is tested directly, at the highest seam that owns time: `LaunchWatch` in `LauncherPlatformTests`, with its report closure recording, never given a pid, awaited with the bounded `awaiting` helper (`BoundedWait.swift`), since the render server's time cannot be advanced; only lower bounds are asserted, because this suite has had starved timed tests before; the suite is serialized, as its rows share the process-wide clock host and are the first in the suite to make a window. Feasibility: the no-`NSApplication` clock probe. The deadline's stop rule keeps its pure row, moved from `BounceDeadlineTests` (`LaunchWatchLookTests.swift`). The settings record's bytes are read back as `PersistenceTests` reads them.

Faked: the system actions and the trackpads in memory, the settings in a throwaway suite, time on the model side. Nothing we own is faked under the port. Not tested, and verified without a test: the real hide and its reach (Spaces, full screen, Finder, a second display), the deferred hide of the frontmost app and the swap series it protects, the shell's unhide and the panels' `canHide`, the Dock icon, and the absence of a prompt. A test of those would hide real apps on the user's screen, and plan 017's real-app suite was removed after implementation at the human's request for taking `swift test` from about 6 s to about 92 s.

### Test scenarios

Unless a row says otherwise: the *hide world* is `World.switcherWorld(apps: ["Safari", "Mail", "Notes"])` (all three running in that order, Safari frontmost, Finder in CoreServices), `setHideBackgroundApps(on: true)`, Safari assigned to the 1-finger gesture and nothing else assigned; `B(x)` is `World.bundleID(x)`; `hidesOthers` is the fake's record of hides by kept app; `hiddenApps` the fake's set of hidden apps; `launches` the fake's record of watched launches; `endings` its record of launch ends. "Before" says what today's code does.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2, R3 | World + record bytes | Given a fresh `World(apps: ["Arc"])`, started: `isHideBackgroundAppsOn == false`. Given `PersistenceTests.savedSettings` (the released record, which predates the key and anchors the thumb top right) seeded, its apps registered, `relaunch()` and `start()` (a login start), Arc running: off, and a tap on Arc's gesture with `thumbAtMM: (114.8, 10)` gives `broughtToFront == [Arc]` and `hidesOthers == []`. Given a world with Arc assigned and running where `setHideBackgroundApps(on: true)`: the saved bytes read through `PropertyListSerialization` hold `isHideBackgroundAppsOn == true`; after `relaunch()` and `start()` alone it is on and a tap gives `hidesOthers == [B(Arc)]`; after `openedByHand()` it is still on. A record holding only `isHideBackgroundAppsOn = true` loads with it on and every other field default; `everySettingsFieldSurvivesTheStore` round-trips it on. Before: no such field. | R2's two scenarios; R3's two scenarios; the record's decoding rule; the fixture a released build wrote; `PersistenceTests.aRecordHoldingOnlyTheSwapKeyLoads…`'s shape. |
| T2 | R4 | World | Given the hide world with the switch off. When `setHideBackgroundApps(on: true)`: `hidesOthers == []`, `broughtToFront == []`, `hiddenApps == []`. When `tap(1)`: `hiddenApps == [B(Mail), B(Notes)]`. When `setHideBackgroundApps(on: false)`: `hiddenApps` unchanged, `hidesOthers.count == 1`. When `tap(1)` again: `broughtToFront == [Safari, Safari]` and `hidesOthers.count == 1` still. Before: no such intent. | R4's two scenarios. |
| T3 | R5 | World | Given the hide world with Mail frontmost. When `tap(1)`: `broughtToFront == [Safari]`, `hidesOthers == [B(Safari)]`, `hiddenApps == [B(Mail), B(Notes)]`, `launchAnimations == [Safari]`, `feedback == [macBook14]`, and the `onHideOtherApps` hook saw `broughtToFront == [Safari]` and `launchAnimations == [Safari]` already recorded, so the hide comes last. Given Safari frontmost instead: `tap(1)` gives `hidesOthers == [B(Safari)]` and `hiddenApps` holds Mail. Given `setLaunchAnimation(on: false)`, Mail frontmost: `tap(1)` gives `broughtToFront == [Safari]`, `hidesOthers == [B(Safari)]`, `launchAnimations == []`, `launches == []`. Given Figma assigned to 2 with no process, animation on and then off: `tap(2)` gives `broughtToFront == [Figma]` and `hidesOthers == []` both times (and `bounces == [Figma]` with the animation on). Given the 3-finger gesture unassigned and Notes assigned to 2 then removed from disk: `tap(3)` and `tap(2)` give `hidesOthers == []` and `broughtToFront == []`. Before: `hidesOthers` does not exist, and with the animation off `hasProcess` is never read. | R5's three scenarios; R10's "leave other apps visible until"; `LauncherTests`' literals for the animation and the pulse; `LaunchBounceFiringTests.withTheLaunchAnimationOffAnAppWithNoProcessJustLaunches`. |
| T4 | R6, R20 | World | Given the hide world with Notes frontmost and Safari's assignment cleared (an assigned app is left out of the row), so the row is Notes, Safari, Mail. When `swipe(3.5, 12)` (one icon right, lifting on Safari): `broughtToFront == [Safari]`, `hidesOthers == [B(Safari)]`, `hiddenApps == [B(Mail), B(Notes)]`, one gesture pulse. Given instead the hide world (Safari assigned), Safari frontmost, after `tap(1)` hid Mail and Notes. When `swipe(3.5, 12, 12)` lifts on Notes (the row is Safari, Mail, Notes; the hidden apps are listed as before): `broughtToFront == [Safari, Notes]`, `hidesOthers == [B(Safari), B(Notes)]`, two gesture pulses. Given Mail frontmost after a swap from Safari hid Safari. When `tap(1)`: `broughtToFront` ends with Safari and `hidesOthers` with `B(Safari)`. Before: nothing is hidden. | R6's scenario; R20's two scenarios (the model's part: the hidden app is the target and the others hide; "shows" is the adapter's, under S2's manual checks); `SwitcherOnScreenTests`' slide literals (3.5 then 12 per icon); `SwitcherAssignedAppsTests.anAssignedAppIsLeftOut…`. |
| T5 | R7, R19 | World | Given the hide world, Safari frontmost, Mail used before it, after `tap(1)` hid Mail and Notes. When `swap(taps: 1, lift: false)`: `broughtToFront == [Safari, Mail]`, `hidesOthers == [B(Safari), B(Mail)]`, `hiddenApps == [B(Safari), B(Notes)]`: the hidden Mail was the swap's target. When `activate("Mail")` and the script continues with one more thumb tap and the lift: `broughtToFront == [Safari, Mail, Safari]`, `hidesOthers == [B(Safari), B(Mail), B(Safari)]`, `hiddenApps == [B(Mail), B(Notes)]`; every pulse is the gesture haptic. Given instead two thumb taps before any activation lands (the first swap's app still coming to the front): the same `broughtToFront` and `hidesOthers`, by the in-flight rule. Before: no hides. | R7's scenario; R19's scenario; `SwapTests`' series literals and `rapidTapsAlternateWhetherOrNotTheFirstActivationLandedYet`. |
| T6 | R8 | World | Given `World.windowWorld(visible: ["Docs", "Mail"])` (Safari frontmost with two windows; Mail, Preview, TextEdit and Notes running) with the switch on. When `windowSwipe(3.5, 12, lift: false)` is played frame by frame: after every frame `hidesOthers == []`, while the stack's first window becomes "Mail" as the fingers pass it. When the fingers lift: `stack == ["Mail", "Docs"]`, `hidesOthers == [B(Safari)]`, `hiddenApps == [B(Mail), B(Preview), B(TextEdit), B(Notes)]`, `feedback.count == 1`, and `broughtToFront == []`. Before: `hidesOthers` empty throughout. | R8's two scenarios; `WindowSwitchingTests.liftingOnAnotherWindowKeepsItInFront…`'s stack literal. |
| T7 | R9 | World | Five cases, each ending with `hidesOthers == []`, `hiddenApps == []`, `feedback.isEmpty` (no gesture pulse; the slides' light ticks are allowed) and `broughtToFront == []`: (a) the hide world, Safari frontmost, `swipe(3.5)` lifting on the frontmost app; (b) `windowWorld(visible: ["Docs", "Mail"])`, switch on, `windowSwipe(3.5, 12, lift: false)`, then a third finger lands outside the corner (cancel) and all lift; (c) the hide world, `swipe(3.5, 12, lift: false)`, then `makeRunning(["Safari", "Notes"])` (Mail quit), lift; (d) `windowWorld`, switch on, `windowSwipe(3.5, 12, -12)` lifting on the front window (`raised == [[Mail], [Docs], []]`: the slides' raises and the lift's empty one, as `selectingAWindowThatClosed…`'s neighbours record it); (e) `World.switcherWorld(apps: ["Safari"], running: ["Safari"])`, switch on, `swap()`. Before: the same, trivially; these pin the silent paths. | R9's five scenarios; the glossary's *Feedback* silent list; `SwapTests.nothingHappened`'s shape; `WindowSwitchingTests`' `raised` literals. |
| T8 | R10 | World | Given Figma on the 2-finger gesture with no process, Mail running, switch on. (a) Animation on: `tap(2)` gives `launches == [Figma, cap 10 s, bouncing, no limits]`, `bounces == [Figma]`, `hidesOthers == []`, `hiddenApps == []` (a report withheld is the five seconds). When `makeFrontmost("Figma")` then `report(.windowShown)`: `endings == [Figma: .launchAnimation]`, `hidesOthers == [B(Figma)]`, `hiddenApps` holds Mail; a hook run inside the hide sees the ending already recorded, so the animation starts first. (b) Animation off: `tap(2)` gives `launches == [Figma, 10 s, not bouncing]`, `bounces == []`, `launchAnimations == []`, one pulse, `hidesOthers == []`; `makeFrontmost("Figma")` and `.windowShown` give `hidesOthers == [B(Figma)]` and `endings.count == 1`. Before: (b) brings to front with no watch, so nothing ever hides. | R10's two scenarios; R11's 10 s literal; `LaunchBounceFiringTests`' bounce literals. |
| T9 | R11 | World | Given Figma launching as in T8, once with the animation on and once off, `makeFrontmost("Figma")`. (a) `.wentNowhere`: `endings == [Figma: .quietFade]`, `hidesOthers == []`; a later `.windowShown` changes nothing. (b) `.finishedLaunching` then `.ranOut`: `launches.first.limits == [2 s]`, the launch ended, `hidesOthers == []`; a later `.windowShown` changes nothing. (c) `.ranOut` before finishing: `.quietFade`, `hidesOthers == []`. Before: with the animation off there is no launch record. | R11's two scenarios; its 10 s and 2 s literals; `LaunchBounceFiringTests.aLaunchThatGoesNowhereOrRunsOut…`. |
| T10 | R12 | World | Given Slack on the 2-finger gesture with no process, Mail running, switch and animation on, `tap(2)`. When `makeFrontmost("Mail")` (the user clicked Mail in the Dock) and `report(.windowShown)`: `endings == [Slack: .launchAnimation]` and `hidesOthers == []`. With `makeFrontmost(nil)` instead: `hidesOthers == []`. With `makeFrontmost("Slack")`: `hidesOthers == [B(Slack)]`. Before: no hide exists. | R12's scenario; the R12 decision (the frontmost read). |
| T11 | R4, R10 | World | Given Figma launching with the switch off (animation on), `tap(2)`. When `setHideBackgroundApps(on: true)` and `tap(2)` again: `launches.count == 1`, `broughtToFront == [Figma, Figma]`, two pulses; `makeFrontmost("Figma")` and `.windowShown` give `hidesOthers == [B(Figma)]`. The reverse (launched with it on, switched off, tapped again, window shown) gives `hidesOthers == []`. Given instead the switch flipped with no second tap: launched off, switched on, `makeFrontmost("Figma")`, `.windowShown` gives `hidesOthers == []`; launched on, switched off, window shown gives `hidesOthers == [B(Figma)]`: the record decided at the gesture, not the live setting. Before: a repeated gesture keeps the bounce (plan 017), with nothing to re-arm. | R4 "only affects later actions"; R10 "a gesture that launches"; the one-bounce rule (`LaunchBounceFiringTests.aRepeatedGestureKeepsTheOneBounce…`); the "latest gesture's setting counts" decision. |
| T12 | R14 | World | (1) The hide world; `openSettings()` (Trackpad Launcher frontmost and listed first). When `tap(1)`: `hidesOthers == [B(Safari)]`, `hiddenApps` holds `B(Trackpad Launcher)`, `launcher.window == .open(request: 1)`, `launchAnimations == [Safari]`, one pulse. (2) Then Notes assigned to 2 and `tap(2)`: `broughtToFront == [Safari, Notes]`, `hidesOthers.count == 2`. (3) Fresh hide world; `openSettings()`, `activate("Safari")` (the window behind Safari). When `swap()`: `broughtToFront == [trackpadLauncher]`, `launcher.window == .open(request: 2)`, `hidesOthers == [B(Trackpad Launcher)]`, `hiddenApps == [B(Safari), B(Mail), B(Notes)]`. Before: nothing hides; the window's request literal holds today. | R14's three scenarios; `SettingsWindowAsAppTests.swappingFromAnotherAppBackToTheSettings…` (`request: 2`). |
| T14 | R10, R11 | `LaunchWatch` (platform, serialized) | Given a `LaunchWatch` whose report closure records `(time, progress)`, never given a pid (`opened` not called), started with cap 0.2 s: exactly one `.ranOut` arrives, no earlier than 0.2 s after the start, within the 3 s bound (`awaiting`), and nothing else within 0.5 s after it; the clock host's panel is never visible. Given one started with cap 5 s and then `limit(to: 0.2 s)`: one `.ranOut`, no earlier than 0.2 s after the limit, within 3 s, long before the cap. Given one started with cap 0.2 s and stopped at once: nothing within 1 s. The deadline rule, moved from `BounceDeadlineTests`: not cancelled, it passes on `finished` true and on false; cancelled, never. Before: the watch has no cap or limit; both are the bounce's, so a watch with no bounce never runs out. | R11's limits as the watch's contract ("whichever comes first"); plan 017's measured lateness (about 90 ms); the no-`NSApplication` clock probe (a 0.3 s deadline passes on time, a removed layer stops early); the `awaiting` helper's bound. |

### Verified without a test

- **R1 (manual).** On a Debug build with its settings suite cleared (`defaults delete com.domasgru.TrackpadLauncherApp.debug`), open the settings window: the third group shows the *Thumb corner* row and, directly below it, the *Hide background apps* switch, off. A test would only re-state the view's wiring, as the thumb corner row's placement is checked today.
- **The adapter's deferred hide of the frontmost app (probe and manual; a decision check, not a requirement's proof: R7 is T5's).** Probe: hidden after the target's activation, the app the user came from stays second in the ⌘-Tab order through every step of a four-step series with the user's own apps visible, where a same-turn hide of the frontmost app put a third app second in three steps. Manual, with the switch on and four visible apps: a swap series of four thumb taps alternates the same two apps and never reaches a third; each step shows the app it brought forward alone. A test would hide the user's real apps.
- **R13 (probe and manual).** Probe: `hide()` reaches a full-screen app on its own Space, in the same turn as the bring-to-front and from another Space; the app comes back full-screen when opened; the ⌘-Tab order keeps hidden apps in place. Manual, with the switch on: a Finder window open, Notes with a window on a second display, Reminders with an ordinary window on another desktop, an app full-screen on its own Space, and a menu bar app with a window open; tap a gesture for Safari: the Finder window, Notes, Reminders and the full-screen app hide, the Desktop's icons stay, the menu bar app stays; then, from the same arrangement, press ⌘⌥H in Safari: the same apps hide, the full-screen one included. Should ⌘⌥H leave the full-screen app alone, the adapter skips full-screen apps (the window list tells) and the domain entry's "full-screen apps included" changes. A test would hide the user's real apps.
- **R15 (probe and manual).** Probe: the activation policy reads regular after the app's hide. Manual: with the settings window open, tap a gesture for a running app: the window goes and Trackpad Launcher's Dock icon stays, with the running dot. The Dock icon is macOS's rendering of the policy; nothing of ours changes it.
- **R16 (probe and manual).** Probe: the window's frame is identical after hide and unhide, and the close-while-hidden then reopen sequence shows it again. Manual: hide the window with a gesture, move nothing, click the Dock icon: the window shows at the same position with the switch on; the same from Spotlight; and after the Dock's Quit while hidden, the next opening shows it centred as a fresh open. A test would need the real `NSApplication` and the Dock.
- **R17 (probe and manual).** Probe: a `canHide = false` non-activating panel stays visible through the app's hide, animations added to its layer before and during the hide complete on time, and a panel ordered in while the app is hidden shows. Manual, in S3: with the settings window open, tap a gesture for a running app: the launch animation plays in full while the window goes; start a swipe right after: the switcher shows; with the window open, make a cold launch and, while it bounces, tap a gesture for a running app: the window goes and the bounce keeps playing, follows the pointer and ends on its window; haptics are as before (the World rows for R5–R8 assert the pulse counts). In S4: with the window open and the switch on, a cold launch alone: the bounce plays through and the window goes when the app's window shows. The visuals live in panels under the shell, which no test drives.
- **R18 (manual).** With the switch on, tap a gesture that hides Mail and Notes, then swipe: the switcher lists Mail and Notes in the same relative order as before the hide, their icons unchanged. A World row cannot fail here: the fake's ⌘-Tab list never changes on a hide and the model reads no hidden state, which is the decision; the real list's behaviour is the probe's (hidden apps keep their place) and this check's.
- **R21 (manual).** Remove the Debug build from the Accessibility and Screen Recording lists in System Settings, turn the switch on and tap a gesture for a running app: the other apps hide and no prompt shows; the console shows no TCC denial. A prompt is observed, not asserted; the hide is a public, prompt-free call, confined to one file by the source scan.

## Further Notes

- **Why the frontmost read for R12, and what it reads.** The activation probe showed that a launch's own activation precedes its window by hundreds of milliseconds and that system helpers can activate themselves mid-launch, so an "another app activated" push would cancel hides the user wanted. The read is exact for the requirement's scenario and reads R12 slightly generously: a user who switched away and back before the window gets the hide, which is what they then want. The read is `runningApps().frontmost`, so Trackpad Launcher active without its Dock icon reads as the app before it, as everywhere else.
- **A launching app hidden by a later action.** With the switch on, a gesture for a running app while another app is still launching hides the launching app too; its window then appears hidden, and the frontmost read keeps the launch from hiding anything. Its watch ends by its own ends: the window observer where it registered (whether it fires for a window the app shows while hidden is unmeasured), otherwise the 2 s limit, since the window list reads on-screen windows only. The user reaches the app through the swap, the switcher or its gesture, which unhide. This is what "hide everything else" asks for.
- **Why the frontmost app's hide waits for the target's activation.** The post-review probe showed the race the same-turn hide loses: hiding the frontmost app makes macOS activate the next visible app before the target's own activation lands, and that app then sits second in the ⌘-Tab order, so the next swap would reach it instead of the app the user came from (three steps out of four). Deferring only that one hide to the target's activation push keeps every immediate hide immediate and the order intact in every probe; the cost is one workspace observer that exists only while a hide is pending. The pending hide has no deadline: it is dropped by the next hide, by another app's activation, or by firing.
- **⌘⌥H equivalence.** Hide Others and a running app's hide set the same per-app hidden state; the manual check compares them on the same arrangement. The Desktop's icons are not a window the hide touches.
- **A bounce that cannot show.** With the deadlines on the watch, a launch with no display to bounce on runs its course; plan 017's "runs out on the next turn" goes. No test depended on it since the platform suite was removed.
- **The Debug tuner hides with the app.** It is a developer tool; the next opening by hand brings it back with the window.
- **Cost on the gesture path.** None in the gesture's own turn beyond a 0.02 ms enumeration and a frontmost read: the hides go out on the next main-actor turn, about 0.75 ms per visible Dock app and 0.25 ms per hidden one *(post-review probe)*, so about 11 ms once for fifteen visible apps and 3–4 ms on the gestures after, while the launch animation already plays on the render server.
- **App Nap and the unseen watch.** With the animation off, the watch's deadlines are the first in the app with no visible window of ours, in a process that is an accessory most of the time; the probes' deadlines were in unbundled scripts and no longer than 1 s. S4's manual check times the 2 s limit on a bundled Debug build after it has idled; should it run late, the watch holds a `ProcessInfo` activity for its span, which is no timer.
- **A repeat gesture on an unseen watch shows nothing.** Turning the launch animation on while an unseen launch is watched and tapping again brings the app to front with no bounce: the one watch keeps its kind, and the setting applies to the next launch, as its entry says.
- **Non-goal kept.** Turning the switch off shows nothing; hidden apps stay hidden until something brings them to front.
- **The fake's hidden set.** It models the adapter's contract (hide hides every Dock app but one; a bring-to-front unhides) so the rows read like the requirements; the model never reads it, and no row's pass depends on it alone.

## Slices

### S1: Prefactor: the launch watch owns its clock; the bounce only draws

**What to build:** Nothing the user sees changes. A launch bounce plays, ends and times out exactly as today, but its cap, its 2 s limit and its 50 ms re-look waits are deadlines on the watch's own clock layer in a never-shown window, not on the bounce's slot, and the bounce overlay only draws. A launch with no display to bounce on runs its watch to the end.

**Blocked by:** None (can start immediately).

**Requirements:** None (prefactor); R10 and R11's clock in advance.

**Test scenarios:** T14.

**Skills:** macos-dev-workflow:axiom-macos, macos-dev-workflow:swift-concurrency, macos-dev-workflow:swift-testing-pro.

- [ ] `LaunchClock` exists in the platform module with its host panel (never ordered in, `canHide` false, made with the first clock, closed with the last), `after(_:_:)`, `stop()` and the deadline rule with its fail-safe; `BounceOverlay.Deadline` and `BounceDeadlineTests` move to it.
- [ ] `LaunchWatch` starts with a cap, takes limits, re-looks on its clock and reports `.ranOut`; `WorkspaceActions` wires the cap and the limit through the watch; `BounceOverlay` has no deadline, limit, `after` or `ranOut`, and the Debug preview runs until stopped.
- [ ] The port's text no longer promises that a bounce it cannot show runs out on the next turn; the watch's own doc says where its time lives.
- [ ] The existing suite stays green with no test literal changed; the source scan stays green.
- [ ] Manual: a cold launch bounces and ends on its window; a menu bar app's bounce ends 2 s after it finished; the tuner's preview bounces until stopped.

### S2: The switch, and every immediate hide of the other apps

**What to build:** The *Hide background apps* switch below the thumb corner row, off by default and kept across relaunches and login starts. With it on, a tap on a running app, a swipe lift, a swap and a window swipe lift that changes the front window hide every other running app with a Dock icon, Finder included, on every display and Space, the app the user came from once the target has come to the front; every silent action hides nothing; flipping the switch hides and shows nothing; a gesture whose app has no process brings it to front and hides nothing. Hidden apps stay in the switcher and the swap and show when brought to front. Trackpad Launcher's own settings window is not hidden yet (S3), and a launched app's window hides nothing yet (S4).

**Blocked by:** None (can start immediately; independent of S1).

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, R13, R18, R19, R20, R21.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7.

**Skills:** macos-dev-workflow:axiom-macos, macos-dev-workflow:axiom-swiftui, macos-dev-workflow:axiom-data, macos-dev-workflow:swift-testing-pro.

- [ ] The settings record's field, the model's `isHideBackgroundAppsOn` and `setHideBackgroundApps(on:)`, and the switch in the third section below the thumb corner row.
- [ ] `SystemActions.hideOtherApps(than:)` with the contract text of the hide decision; `WorkspaceActions` implements it over the regular-policy running apps other than itself (self comes in S3): the immediate hides on the next main-actor turn, the frontmost app's hide on the kept app's activation push with the drop rules, the observer alive only while a hide is pending; `RecordingSystemActions` records hides, runs `onHideOtherApps` and models the hidden set; `World` exposes them.
- [ ] `fire` reads `hasProcess` when the hide setting is on, so an app with no process gets no immediate hide; `fire`, the swipe lift, the swap and the window swipe lift hide after their bring-to-front or raises, each behind its silencing guard.
- [ ] `.hide(` is confined to the adapter's file in the source scan; the scan and the existing suite stay green, with `hidesOthers.isEmpty` folded into the `nothingHappened` helpers.
- [ ] Manual: a hidden app shows again through its gesture, a swipe lift and a swap; the swap series check under R7; the checks for R1, R13 and R21.
- [ ] The code matches the domain model's *Hide background apps setting*, *Trackpad Launcher* and *Bring to front* entries, and the architecture's Privacy sentence on confinement, as planning wrote them.

### S3: The settings window hides with the others and comes back; the overlays never hide

**What to build:** With the switch on, an action that hides also hides the open settings window, unless Trackpad Launcher is the frontmost app; the Dock icon stays, and any opening by hand (the Dock icon, Spotlight, Finder, a swap or a lift on Trackpad Launcher) shows the window where it was with the switch as it was. The switcher, the window switcher, the launch animation and the launch bounce keep playing through a hide, and gestures keep working while the window is hidden.

**Blocked by:** S2.

**Requirements:** R14, R15, R16, R17.

**Test scenarios:** T12.

**Skills:** macos-dev-workflow:axiom-macos, macos-dev-workflow:swift-testing-pro.

- [ ] `WorkspaceActions.hideOtherApps(than:)` hides Trackpad Launcher itself with the app's own hide when its Dock icon shows and it is not the kept app, under the same deferral when it is frontmost.
- [ ] `OverlayPanel`, `LaunchOverlay.makePanel`'s panels and the clock host have `canHide` false; `SettingsShell` unhides the app when it renders an open window, and unhides without activation after ordering the window out when it renders a closed one.
- [ ] The manual checks for R15, R16 and R17 (its S3 steps) pass.
- [ ] The code matches the domain model's *Settings window* entry as planning wrote it.

### S4: A launched app hides the others once its window shows

**What to build:** With the switch on, a gesture that launches an app leaves the other apps visible until the app shows its first window, then hides them, with the launch animation on (the bounce plays as today) or off (nothing shows at the pointer, the launch is watched unseen). A launch that fails or shows no window within the bounce's limits hides nothing, and so does one whose app is not the frontmost app when its window shows, because the user went elsewhere. A repeated gesture keeps the one launch and takes the switch's current value; the switch alone changes nothing about a launch already under way.

**Blocked by:** S1, S2.

**Requirements:** R10, R11, R12.

**Test scenarios:** T8, T9, T10, T11.

**Skills:** macos-dev-workflow:axiom-macos, macos-dev-workflow:swift-concurrency, macos-dev-workflow:swift-testing-pro.

- [ ] `WatchedLaunch` replaces the bounce's record in the model; `fire` watches a launch without a process, bouncing exactly when the launch animation setting is on, and re-arms a watched app's hide from the setting; the progress handler hides after a `.windowShown` end when the record says so and the launched app is frontmost.
- [ ] The port's launch members are renamed and documented as decided (`bringToFrontWatching(_:cap:bouncing:)`, `limitLaunch`, `endLaunch`), their texts saying "launch" where they said "bounce"; `WorkspaceActions` shows the bounce only when asked; the fake records every watched launch with its cap, `bouncing` and limits, with `bounces` derived.
- [ ] The existing bounce rows keep their literals; the scan stays green.
- [ ] R12 reads the front app at the moment the window shows: a user who came back to the launched app gets the hide. No activation observer.
- [ ] The code matches the domain model's *Launch watch* and *Launch animation setting* entries and the architecture's Concurrency bullets on the push list, the deadline rule and the repeating read, as planning wrote them.
- [ ] Manual: with the animation off and the switch on, a cold launch of Slack hides the others when its window shows and nothing shows at the pointer; with the animation on, the bounce ends with the launch animation and the others hide; click Mail in the Dock during a cold launch: nothing hides when the window shows; with the animation off, launch a menu bar app, wait past 2 s, then open its window: nothing hides; cold-launch Slack, Figma and Chrome in turn: nothing hides before each app's window is on screen (else the window-list contingency); on a bundled Debug build idle for ten minutes, a menu bar app's unseen launch ends within about 2.1 s of finishing (else the `ProcessInfo` activity); the R17 step for S4.
