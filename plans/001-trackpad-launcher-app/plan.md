# Plan: Trackpad Launcher

## Problem statement

Switching to a specific app on a Mac takes the user's attention away from what they are doing. ⌘-Tab cycles through a list the user has to read. The Dock needs the cursor to travel and the eye to find the icon. Spotlight needs typing. None of these become muscle memory for "go to Arc" the way a single hand movement does.

Trackpad users have nothing faster. There is no way to say "this hand shape means Figma" and have the Mac obey, without looking.

A launcher only earns a place in the menu bar if it costs nothing to keep. One that asks for Accessibility, phones home, logs, or burns CPU while idle gets uninstalled.

## Solution

Trackpad Launcher turns four trackpad gestures into app shortcuts. The user rests a thumb in the top-left corner of the trackpad (top-right for left-handers) and taps anywhere else with one, two, three or four fingers. Each gesture brings its assigned app to the front: launching it, unhiding it or restoring it as needed. The trackpad answers every gesture with a haptic pulse.

The app lives in the menu bar only. Its window shows the four gestures, each with an app picker, and a hand-mode toggle. It starts at login, needs no permissions, never touches the network, and idles at zero cost.

Gestures need *Tap to click* off. When it is on, the window says so and opens the right System Settings pane.

## Requirements

### R1. Menu bar presence only
Trackpad Launcher MUST appear as an icon in the menu bar and nowhere else: no Dock icon, no entry in the ⌘-Tab app switcher.

#### Scenario: Running app shows only in the menu bar
- **GIVEN** Trackpad Launcher is running
- **WHEN** the user looks at the Dock and presses ⌘-Tab
- **THEN** Trackpad Launcher is in neither, and its icon is in the menu bar

### R2. Menu bar icon shows whether gestures are active
The menu bar icon MUST show one of two states: *active* (gestures work) and *inactive* (gestures are off because of trackpad settings, see R14). The active state is the symbol as is; the inactive state is the same symbol with a slash through it. The two states must be distinguishable at a glance in both light and dark menu bars. When no trackpad is connected the icon shows the inactive state.

#### Scenario: Icon flips to inactive
- **GIVEN** gestures are active
- **WHEN** the user turns *Tap to click* on in System Settings
- **THEN** the menu bar icon changes to the inactive state within 5 seconds, without relaunch

#### Scenario: Icon flips back to active
- **GIVEN** the icon shows the inactive state
- **WHEN** the user turns *Tap to click* and *Look up: Tap with three fingers* off
- **THEN** the icon returns to the active state within 5 seconds

#### Scenario: No trackpad connected
- **GIVEN** a Mac with no built-in trackpad and no external trackpad connected
- **WHEN** the app runs
- **THEN** the icon shows the inactive state

### R3. Launcher window opens from the icon
Clicking the menu bar icon MUST open the launcher window: four gesture rows (1 to 4 fingers, top to bottom), the hand-mode toggle, the hint text, and a Quit button. The window MUST close when the user clicks outside it or presses Escape. Clicking the icon while the window is open MUST close it. A gesture that fires while the window is open closes the window as the target app comes to the front.

#### Scenario: Open and dismiss
- **WHEN** the user clicks the menu bar icon
- **THEN** the launcher window opens below the icon with four gesture rows in finger-count order
- **WHEN** the user then clicks anywhere outside the window
- **THEN** the window closes

#### Scenario: Escape closes
- **GIVEN** the launcher window is open
- **WHEN** the user presses Escape
- **THEN** the window closes

#### Scenario: Icon click toggles
- **GIVEN** the window is open
- **WHEN** the user clicks the menu bar icon
- **THEN** the window closes

#### Scenario: Gesture closes the window
- **GIVEN** the window is open and the 1-finger gesture is assigned to Arc
- **WHEN** the user performs it
- **THEN** Arc becomes active and the window closes

### R4. Window follows the design
The launcher window MUST match the layout of `docs/menubar-window.png` with three deviations: the Left hand | Right hand toggle sits between the gesture rows and the divider; there is no Learn more… button, so the bottom bar holds only Quit; and while gestures are inactive the hint is replaced by the notice of R15. It MUST use the gesture illustrations from `assets/` and the macOS 26 Liquid Glass appearance, and MUST look correct in both light and dark appearance.

#### Scenario: Matches the design in both appearances
- **WHEN** the window is opened with the system in light appearance, then in dark appearance
- **THEN** the layout matches the design image in both, with readable text and icons in each

### R5. Each gesture row has an app picker
Each gesture row MUST have an app picker that lists the apps in /Applications and /System/Applications (including their subfolders such as Utilities), ~/Applications, and Finder, alphabetically with their icons, followed by *Other…* and *None*. *Other…* MUST open a file chooser that only accepts applications. *None* MUST unassign the gesture. The list MUST reflect apps installed or removed since the app launched, each time the picker opens.

#### Scenario: Pick an installed app
- **GIVEN** Figma is installed in /Applications
- **WHEN** the user opens the 2-finger picker and chooses Figma
- **THEN** the row shows Figma's icon and name

#### Scenario: Newly installed app appears
- **GIVEN** Trackpad Launcher is running
- **WHEN** the user installs Slack into /Applications and opens a picker
- **THEN** Slack is in the list

#### Scenario: Pick an app from elsewhere
- **WHEN** the user chooses *Other…* and selects an app bundle in ~/Downloads
- **THEN** the row shows that app's icon and name

#### Scenario: File chooser rejects non-apps
- **WHEN** the user chooses *Other…* and browses to a folder containing documents and an app
- **THEN** only the app is selectable

#### Scenario: Unassign
- **GIVEN** the 3-finger gesture is assigned to Notion
- **WHEN** the user chooses *None* in its picker
- **THEN** the row shows the "Choose app…" placeholder and the gesture is unassigned

#### Scenario: Same app on two gestures
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user assigns Arc to the 4-finger gesture too
- **THEN** both rows show Arc, without a warning

### R6. Unassigned rows show a placeholder
An unassigned gesture row MUST show a "Choose app…" placeholder instead of an app. On a fresh install all four gestures MUST be unassigned.

#### Scenario: Fresh install
- **WHEN** the user opens the window after installing for the first time
- **THEN** all four rows show "Choose app…"

### R7. Missing apps are shown as not found
An assignment refers to the app's identity, not its location. The row MUST show the assignment greyed out with a "not found" label when no copy of the app exists outside the Trash. When a copy exists again, the row MUST recover without the user re-picking. The picker MUST still work on a not-found row.

#### Scenario: Assigned app deleted
- **GIVEN** the 2-finger gesture is assigned to Figma
- **WHEN** the user moves Figma to the Trash and opens the launcher window
- **THEN** the 2-finger row shows "Figma" greyed out with "not found"
- **WHEN** the user picks another app in that row
- **THEN** the row shows the new app normally

#### Scenario: Moved app keeps working
- **GIVEN** the 2-finger gesture is assigned to Figma in /Applications
- **WHEN** the user moves Figma to ~/Applications and performs the gesture
- **THEN** Figma comes to the front and the row shows it normally

#### Scenario: Reinstalled app recovers
- **GIVEN** the 2-finger row shows Figma as not found
- **WHEN** the user reinstalls Figma and reopens the window
- **THEN** the row shows Figma normally and the gesture works

### R8. Settings persist
Assignments, hand mode and whether the app has launched before MUST persist across quitting, relaunching and rebooting.

#### Scenario: Survives reboot
- **GIVEN** the user assigned four apps and chose Left hand
- **WHEN** the Mac is rebooted and the launcher window is opened
- **THEN** the same four apps and Left hand are shown

### R9. Hand mode toggle
The launcher window MUST have a *Left hand | Right hand* toggle between the gesture rows and the divider. The default MUST be Right hand. In Left hand mode the anchor corner is top-right; in Right hand mode it is top-left.

#### Scenario: Default is right hand
- **WHEN** the user opens the window on a fresh install
- **THEN** Right hand is selected

#### Scenario: Switching hands moves the corner
- **GIVEN** Right hand is selected and the 1-finger gesture is assigned to Arc
- **WHEN** the user selects Left hand, anchors the thumb top-right and taps with one finger
- **THEN** Arc comes to the front
- **WHEN** the user anchors the thumb top-left and taps with one finger
- **THEN** nothing happens

### R10. Window mirrors the current hand mode
In Left hand mode the gesture illustrations MUST be mirrored horizontally (thumb mark top-right) and the hint MUST read "top-right corner". In Right hand mode the illustrations and hint MUST match the design (thumb top-left).

#### Scenario: Illustrations and hint follow the toggle
- **GIVEN** the window shows Right hand
- **WHEN** the user selects Left hand
- **THEN** all four illustrations show the thumb mark top-right and the hint says "Hold thumb on top-right corner"

### R11. Gesture recognition
While a thumb is anchored in the anchor corner, a tap with N fingers (N = 1 to 4) elsewhere on the trackpad MUST fire the N-finger gesture exactly once, when the fingers lift. N is the largest number of non-thumb fingers simultaneously down during the tap. The thumb MUST be anchored from before the first finger lands until the last finger lifts. The following MUST NOT fire a gesture:
- a physical click (trackpad pressed down), with any number of fingers;
- a tap that began before the thumb was anchored;
- a tap that ends after the thumb has lifted;
- a tap while the thumb is outside the anchor corner;
- a thumb resting alone, however long;
- fingers that drag or scroll while the thumb is anchored;
- taps with more than four fingers.

The anchor corner is a fixed zone: roughly the leftmost 20% and topmost 25% of the trackpad surface (rightmost 20% in Left hand mode). The exact size is tuned so a naturally placed thumb lands inside on both a 13" MacBook and a Magic Trackpad.

#### Scenario: Thumb first, then tap
- **GIVEN** the 2-finger gesture is assigned to Figma and gestures are active
- **WHEN** the user anchors the thumb top-left, then taps with two fingers in the middle of the trackpad
- **THEN** Figma comes to the front once

#### Scenario: Repeated taps while anchored
- **GIVEN** 1-finger → Arc and 2-finger → Figma
- **WHEN** the user anchors the thumb, taps with one finger, then without lifting the thumb taps with two fingers
- **THEN** Arc comes to the front, then Figma

#### Scenario: Fingers before thumb
- **WHEN** the user puts two fingers down in the middle, then puts the thumb in the corner, then lifts the two fingers
- **THEN** nothing happens

#### Scenario: Thumb outside the corner
- **WHEN** the user rests the thumb in the bottom-left corner and taps with one finger
- **THEN** nothing happens

#### Scenario: Thumb alone
- **WHEN** the user rests the thumb in the anchor corner for five seconds and lifts it
- **THEN** nothing happens

#### Scenario: Drag is not a tap
- **WHEN** the user anchors the thumb and drags two fingers across the trackpad
- **THEN** nothing happens, and the cursor or scroll behaves as macOS normally would

#### Scenario: Five fingers
- **WHEN** the user anchors the thumb and taps with five fingers of the other hand
- **THEN** nothing happens

#### Scenario: Click is not a tap
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb and presses the trackpad down with one finger over a button
- **THEN** the button is clicked as normal and Arc does not come to the front

#### Scenario: Fingers land and lift one at a time
- **GIVEN** the 3-finger gesture is assigned to Notion
- **WHEN** the user anchors the thumb and taps with three fingers that land and lift a few milliseconds apart
- **THEN** Notion comes to the front exactly once

#### Scenario: Thumb lifts before the fingers
- **WHEN** the user anchors the thumb, puts two fingers down, lifts the thumb, then lifts the fingers
- **THEN** nothing happens

#### Scenario: Just inside and just outside the corner
- **GIVEN** a 13" MacBook and the 1-finger gesture assigned to Arc
- **WHEN** the user rests the thumb 1 cm from the top-left corner and taps with one finger
- **THEN** Arc comes to the front
- **WHEN** the user rests the thumb 4 cm from the left edge and taps with one finger
- **THEN** nothing happens

### R12. Gesture brings the target app to the front
When a gesture fires and its target app is present on disk, Trackpad Launcher MUST bring the target app to the front. If the app is not running, it launches and becomes active. If it is running, the result MUST be exactly what clicking the app's Dock icon does: unhide it, restore its minimised windows, open a new window if it has none, switch to the desktop its window is on, and make it active. It MUST NOT resize, zoom or full-screen any window. If the target app is already the active app, nothing changes (feedback still plays, see R13). Gestures MUST work whichever app is active, including full-screen apps, and while the launcher window is open. If some part of this cannot be done without a permission prompt, R20 wins and that part is dropped.

#### Scenario: Launches a closed app
- **GIVEN** Spotify is assigned to the 4-finger gesture and is not running
- **WHEN** the gesture fires
- **THEN** Spotify launches and becomes the active app

#### Scenario: Unhides a hidden app
- **GIVEN** Arc is running and hidden (⌘H)
- **WHEN** its gesture fires
- **THEN** Arc is unhidden and active, with its windows where they were

#### Scenario: Restores a minimised app
- **GIVEN** Notion is running with its only window minimised to the Dock
- **WHEN** its gesture fires
- **THEN** the window is restored and Notion is active

#### Scenario: Opens a window when there is none
- **GIVEN** Finder is running with no open windows
- **WHEN** its gesture fires
- **THEN** a new Finder window opens and Finder is active

#### Scenario: Already in front
- **GIVEN** Figma is the active app with a window sized to half the screen
- **WHEN** its gesture fires
- **THEN** Figma stays active and its window keeps its size and position

#### Scenario: Works over a full-screen app
- **GIVEN** Safari is in full screen and active
- **WHEN** the gesture assigned to Arc fires
- **THEN** Arc becomes the active app

#### Scenario: Target on another desktop
- **GIVEN** Arc's only window is on Desktop 2 and the user is on Desktop 1
- **WHEN** Arc's gesture fires
- **THEN** macOS switches to Desktop 2 and Arc is active

#### Scenario: Second tap during launch
- **GIVEN** Spotify is assigned and not running
- **WHEN** the user fires its gesture twice within two seconds
- **THEN** one Spotify instance launches and becomes active

### R13. Haptic feedback on every fired gesture
When a gesture fires for an assigned, present target app, the trackpad the gesture was performed on MUST give a single haptic pulse. A haptic MUST NOT play when the gesture is unassigned, its app is missing, or gestures are inactive.

#### Scenario: Pulse on fire
- **GIVEN** the 1-finger gesture is assigned
- **WHEN** the user performs it on the built-in trackpad
- **THEN** the built-in trackpad pulses once

#### Scenario: Pulse on the external trackpad
- **GIVEN** a Magic Trackpad is connected and the 1-finger gesture is assigned
- **WHEN** the user performs it on the Magic Trackpad
- **THEN** the Magic Trackpad pulses, not the built-in one

#### Scenario: Silent when unassigned
- **GIVEN** the 3-finger gesture is unassigned
- **WHEN** the user performs it
- **THEN** no haptic plays and no app changes

#### Scenario: Silent when missing
- **GIVEN** the 2-finger gesture's app was deleted
- **WHEN** the user performs it
- **THEN** no haptic plays and no app changes

### R14. Gestures need tap-bound system actions off and a trackpad connected
Gestures MUST be inactive while any connected trackpad has a system action bound to a tap rather than a click. Today those are *Tap to click* and *Look up & data detectors* set to *Tap with three fingers*; if testing shows that *Smart zoom* (double-tap with two fingers) fires with a thumb anchored, it joins the list and the notice of R15. Gestures MUST also be inactive while no trackpad is connected. Gestures MUST become active within 5 seconds of every conflicting setting being off, without relaunch.

#### Scenario: Tap to click on
- **GIVEN** *Tap to click* is on for the built-in trackpad
- **WHEN** the user performs an assigned gesture
- **THEN** nothing happens: no app change, no haptic

#### Scenario: Only the external trackpad has it on
- **GIVEN** *Tap to click* is off for the built-in trackpad but on for a connected Magic Trackpad (macOS stores these settings separately for built-in and external trackpads)
- **WHEN** the user performs an assigned gesture on the built-in trackpad
- **THEN** nothing happens: no app change, no haptic, and the icon shows the inactive state

#### Scenario: Turning it off activates gestures live
- **GIVEN** gestures are inactive because *Tap to click* is on
- **WHEN** the user turns it off in System Settings and performs an assigned gesture within 5 seconds
- **THEN** the target app comes to the front

#### Scenario: Three-finger Look up
- **GIVEN** *Tap to click* is off and *Look up & data detectors* is set to *Tap with three fingers*
- **THEN** gestures are inactive

### R15. Trackpad settings notice
While gestures are inactive, the launcher window MUST replace the hint text with a notice naming only the settings currently causing it (*Tap to click*, *Look up: Tap with three fingers*), or "No trackpad connected" when that is the cause, and a button that opens System Settings > Trackpad. The gesture rows MUST stay visible and editable. Once gestures become active, the next time the window is shown it MUST show the hint text, with no relaunch.

#### Scenario: Notice names only the offending setting
- **GIVEN** *Tap to click* is on and Look up is set to Force Click
- **WHEN** the user opens the launcher window
- **THEN** the notice mentions *Tap to click* only, with a button to open Trackpad settings

#### Scenario: Notice names both
- **GIVEN** *Tap to click* is on and Look up is *Tap with three fingers*
- **WHEN** the user opens the launcher window
- **THEN** the notice mentions both settings

#### Scenario: Notice names only Look up
- **GIVEN** *Tap to click* is off and Look up is *Tap with three fingers*
- **WHEN** the user opens the launcher window
- **THEN** the notice mentions Look up only

#### Scenario: No trackpad
- **GIVEN** no trackpad is connected
- **WHEN** the user opens the launcher window
- **THEN** the notice says no trackpad is connected and the rows are still editable

#### Scenario: Button opens the right pane
- **WHEN** the user clicks the notice's button
- **THEN** System Settings opens on the Trackpad pane

#### Scenario: Rows still editable
- **GIVEN** the notice is shown
- **WHEN** the user assigns Arc to the 1-finger gesture
- **THEN** the assignment is saved and shown

#### Scenario: Notice disappears live
- **GIVEN** the launcher window showed the notice
- **WHEN** the user turns *Tap to click* off in System Settings and clicks the menu bar icon again
- **THEN** the hint text is shown and the notice is gone, without relaunching the app

### R16. Every connected trackpad works
Gestures MUST work on the built-in trackpad and on every connected external Apple trackpad, including trackpads connected after launch, and after the Mac sleeps and wakes.

#### Scenario: Hot-plugged Magic Trackpad
- **GIVEN** Trackpad Launcher is running
- **WHEN** the user pairs a Magic Trackpad and performs an assigned gesture on it within 5 seconds
- **THEN** the target app comes to the front

#### Scenario: After sleep
- **WHEN** the Mac sleeps, wakes, and the user performs an assigned gesture on the built-in trackpad
- **THEN** the target app comes to the front

### R17. Starts at login
On first launch, Trackpad Launcher MUST register itself to open at login. It MUST keep running in the background until the user quits it or logs out.

#### Scenario: Added to login items
- **WHEN** the user launches the app for the first time
- **THEN** it appears under System Settings > General > Login Items as "Open at Login", and the system shows its "login item added" notification
- **WHEN** the user logs out and back in
- **THEN** the menu bar icon is present without the user launching the app

#### Scenario: User disables it in System Settings
- **GIVEN** the user turned Trackpad Launcher off under Login Items
- **WHEN** the user logs in
- **THEN** the app does not start, and the app does not re-enable itself on its next manual launch

### R18. First launch opens the window
On first launch Trackpad Launcher MUST open the launcher window without the user clicking the icon. Later launches MUST NOT open it.

#### Scenario: First launch
- **WHEN** the user opens the app for the first time
- **THEN** the launcher window is open, showing four "Choose app…" rows

#### Scenario: Second launch
- **GIVEN** the app has been launched before
- **WHEN** it starts at login
- **THEN** only the menu bar icon appears

### R19. Quit
The Quit button MUST quit Trackpad Launcher immediately: the icon leaves the menu bar and gestures stop. Quitting MUST NOT remove the login item.

#### Scenario: Quit stops gestures
- **WHEN** the user clicks Quit and then performs an assigned gesture
- **THEN** the icon is gone and nothing happens
- **WHEN** the user opens Login Items
- **THEN** Trackpad Launcher is still listed as "Open at Login"

### R20. No permissions
Trackpad Launcher MUST work without asking the user for any system permission (no Accessibility, Input Monitoring or other prompt).

#### Scenario: No prompts from install to first gesture
- **WHEN** a user installs the app, assigns an app and performs the gesture
- **THEN** no permission prompt appears at any point and the gesture works

### R21. No network, no logging
Trackpad Launcher MUST make no network connection of any kind. It MUST write nothing to disk of its own except its settings (assignments, hand mode, whether it has launched before); files macOS writes on every app's behalf do not count. It MUST NOT write log messages of its own, to the system log or to any file.

#### Scenario: Silent on the network
- **WHEN** a network monitor watches the app through launch, configuration, ten gestures and quit
- **THEN** it records zero connections or connection attempts from Trackpad Launcher

#### Scenario: Nothing in the log
- **WHEN** the user filters Console for the app through the same session
- **THEN** no messages written by Trackpad Launcher itself appear (messages emitted by macOS frameworks on its behalf do not count)

### R22. Zero cost when idle
While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU in Activity Monitor, with at most one momentary blip per minute.

#### Scenario: Idle in Activity Monitor
- **GIVEN** the app has been running for ten minutes with no trackpad touches
- **WHEN** the user watches it in Activity Monitor for a minute
- **THEN** its CPU reads 0.0% throughout, with at most one momentary blip

### R23. Platform and distribution
Trackpad Launcher MUST run on macOS 26 and later on Apple silicon and Intel Macs. It MUST be distributed as a direct download, signed with Developer ID and notarized, so it opens without Gatekeeper warnings.

#### Scenario: Opens cleanly on a fresh Mac
- **WHEN** a user downloads the app on a Mac running macOS 26 and opens it
- **THEN** it opens without a Gatekeeper warning

#### Scenario: Older macOS
- **WHEN** a user tries to open the app on macOS 15
- **THEN** macOS says the app needs a newer version of macOS, and nothing else happens

## Non-goals

- **Sound effect on gesture.** The overview asks for a subtle sound; the user deferred it and wants it added in a later feature.
- **Maximising or zooming windows.** The overview's "maximise" is read as restoring minimised windows (R12).
- **A manual on/off switch for gestures.** Gestures are on whenever the app runs and the trackpad settings allow; the only off switch is Quit.
- **"Learn more…" button.** Dropped from the window for now.
- **Toggles for haptics or sound.** Haptics always play; the window stays as designed.
- **Tunable anchor corner, tap timing or finger-count rules.** Fixed values, chosen to feel natural on common trackpads.
- **Working with *Tap to click* on.** The app requires it off instead of fighting the system's own clicks; this keeps the app free of permissions.
- **Mac App Store distribution.** The sandbox does not allow what the app needs to read trackpad touches.
- **Automatic updates.** Update checks are network calls; the app makes none.
- **Gestures beyond the four, or actions beyond "bring to front"** (URLs, scripts, window layouts).
- **Localisation.** English only.
- **Custom menu bar icon.** An SF Symbol for now, to be swapped later.

## Design

### Problem

Trackpad Launcher binds four thumb-anchored taps to *bring to front* and is configured from a menu bar window. The shape is non-obvious because every input is a push from a different thread and framework, and the whole app must cost nothing while idle. Raw touches come only from the private MultitouchSupport framework: `dlopen` works with no permission prompt, the framework is silent while nothing touches the trackpad, and frames arrive through a context-free C callback on a framework-owned thread at ~100 Hz while touching (grounding Q1; the 96-byte frame layout, state values and bottom-left origin are sourced, not yet probed). Whether gestures may run depends on another process's preferences in two cfprefs domains, pushed by KVO on the main thread (Q4), on which trackpads are attached, pushed by IOKit (Q5; MultitouchSupport has no hot-plug symbol), and on sleep/wake. Feedback must hit the trackpad that was tapped, which only the per-device `MTActuator` can do (Q3). A click must be told from a tap without an event tap, so button state is sampled (Q2). *Bring to front* is one probed call, `openApplication(at:configuration:)` with `activates`, which reproduces a Dock click and is idempotent under a double tap (Q6). `MenuBarExtra` cannot open or close its window programmatically, so the launcher window is an `NSStatusItem` plus an `NSPanel` hosting SwiftUI on Liquid Glass (Q8; the macOS 27 expanded-interface session API is not in SDK 26.5, see checks). Hard constraints: no permissions, no network, no logging, no timers or polling (R20–R22); Swift 6 strict concurrency on the Xcode 26 toolchain (SDK 26.5); a macOS 26 universal binary signed with Developer ID (this machine has no Developer ID certificate yet).

### Usage (caller's view)

**README excerpt.** One `@MainActor` model, `Launcher`, owns every decision. Adapters sense and act: they tell it "a gesture fired" or "the trackpads may have changed", and they carry out its commands (run devices, play feedback, bring an app to front, register the login item). The menu bar shell renders `launcher.activity` (icon, notice) and `launcher.isWindowOpen` (the panel). The window renders `launcher.rows` and `launcher.handMode`, calls `setAssignment` and `setHandMode`, and fills each app picker from the catalog the moment the picker's menu opens. Tests build the same model on in-memory adapters, a temp directory of fake `.app` bundles and a throwaway `UserDefaults` suite, and script touches as frames. Nothing in the app waits on a timer.

```swift
// TrackpadLauncher app target: the whole composition root.
@main @MainActor
enum TrackpadLauncherApp {
    static func main() {
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            system: WorkspaceActions(),
            catalog: catalog,
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher, catalog: catalog)   // status item first: a first-launch window needs its anchor
        launcher.start()                                                 // reconcile; on first launch: login item, then window
        withExtendedLifetime(shell) { NSApplication.shared.run() }
    }
}
```

```swift
// LauncherCoreTests: the high seam. R11 + R12 + R13 + R3 in one scenario, driven by frames, synchronous.
@MainActor @Test func thumbFirstThenTwoFingerTapBringsFigmaToFront() throws {
    let world = try World(apps: ["Figma"])              // fake bundles + in-memory adapters + throwaway suite
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
    world.launcher.openWindow()

    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2).frames, on: Trackpad.macBook14.id)

    #expect(world.system.broughtToFront == [world.app("Figma")])
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    #expect(world.launcher.isWindowOpen == false)
}

// R14: the external trackpad's setting silences gestures on the built-in one too, and the notice names only it.
@MainActor @Test func tapToClickOnExternalOnlySilencesEveryTrackpad() throws {
    let world = try World(apps: ["Arc"]); world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
    world.hardware.attach(.magicTrackpad)
    world.preferences.set(.tapToClick, rawValue: 1, for: .external)

    #expect(world.launcher.activity == .inactive(.settings(ConflictingSettings([.tapToClick])!)))
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).frames, on: Trackpad.macBook14.id)
    #expect(world.system.broughtToFront.isEmpty && world.hardware.feedback.isEmpty)
}
```

```swift
// The recognizer's own seam: every R11 scenario as a frame script, pure and synchronous.
@Test(arguments: [(thumbXMM: 10.0, fires: true), (thumbXMM: 40.0, fires: false)])   // 1 cm in, 4 cm out on 124.8 mm
func anchorCornerGeometry(thumbXMM: Double, fires: Bool) {
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let frames = TouchScript(.macBook14).thumb(atMM: (thumbXMM, 10)).tap(fingers: 1).frames
    let fired = frames.compactMap { recognizer.step($0) }
    #expect(fired == (fires ? [.one] : []))
}
```

```swift
// LauncherUI: a gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow; let launcher: Launcher; let actions: LauncherActions
    var body: some View {
        HStack {
            GestureIllustration(row.gesture, handMode: launcher.handMode)   // mirrored in left-hand mode (R10)
            Spacer()
            AppPicker(row.app, installedApps: actions.installedApps,              // enumerated each time the menu opens (R5)
                      choose: { launcher.setAssignment($0, for: row.gesture) },   // .app(entry) or .unassigned
                      chooseOther: { actions.chooseOtherApp(row.gesture) })       // NSOpenPanel lives in the shell
        }
    }
}
```

### Shape

**Data first.** All domain values are `Sendable` structs and enums in `LauncherCore`, each with a public memberwise initialiser (the platform adapters and the test fixtures construct them from other modules).

- *What the recognizer reads.* A `TouchFrame` is a complete snapshot of one trackpad at one instant: a `FrameTime`, the contacts that are down now (each a `Touch` with a `TouchID`, a `SurfacePoint` normalised with the origin top-left, and a `phase` of `.landing` or `.down`), and `buttonDown`. A contact absent from a frame has lifted; there is no other "touch ended" path. A `Trackpad` has a `TrackpadID`, a `TrackpadKind` (`.builtIn` or `.external`) and a `SurfaceSize` in mm.
- *What fires.* `Gesture` has four cases, `.one` to `.four`; its init from a finger count is failable, so five fingers produce no value. A `GestureEvent` is a gesture plus the trackpad it fired on.
- *What the user stores.* `HandMode` is `.right` or `.left`; `AnchorCorner` is derived from it and the surface. `Settings` holds the hand mode and `assignments: [Gesture: AssignedApp]`, where unassigned means absent. `AssignedApp` is a `BundleID` (the identity), a display name and a last-known URL used only as a fast path. "Launched before" is the existence of a stored record; it is not a second flag.
- *What the window shows.* *Missing* is never stored: `GestureRow.app` is `.unassigned`, `.present(AppEntry)` or `.missing(name:)`, derived when `AppCatalog.locate` returns nil. Gesture activity is `GestureActivity`: `.active` or `.inactive(InactiveCause)`, where the cause is `.noTrackpad` or `.settings(ConflictingSettings)`. `ConflictingSetting` is an enum whose cases are the rows of the R14 table (preference key, conflicting raw value, notice name, each an exhaustive switch), and `ConflictingSettings` is non-empty by construction, so "inactive for no reason" and "a row missing a fact" cannot compile (per `type-system-discipline`, `encode-lessons-in-structure`).

**Load-bearing decisions.**

1. *Recognition is a pure state machine that runs on the frame thread, one per trackpad.* `GestureRecognizer.step(_:) -> Gesture?` is a sum type over `idle`, `armed(anchor)`, `tapping(anchor, fingers, peak, start)` and `spoiled(anchor)`, so an anchor can never be absent while a tap is counted. Within a frame, lifts are evaluated before landings, and a tracked contact that reappears with `.landing` counts as lifted and landed anew, so a reused touch ID cannot fuse two taps. Time is data: frames carry their own timestamps and the tap duration is checked against them, so no clock object or timer exists anywhere. The test handle for "the clock" is `TouchFrame.time`; for the button sampler, `TouchFrame.buttonDown`. All fixed numbers live in `GestureRules`. Only fired gestures hop to the main actor; the main thread wakes for gestures, not frames (per `foundational-thinking`).
2. *Both hardware adapters drive the same recognizer.* The real `MultitouchTrackpads` steps it under a never-contended `Mutex` on the frame thread; `InMemoryTrackpads` steps it synchronously on the main actor. Every R11 scenario runs at the recognizer seam and through the whole app at the `Launcher` seam, with no async waiting.
3. *One idempotent `reconcile()`* handles launch, IOKit add/remove, wake, preference change and hand-mode change. It re-reads the truth (`hardware.connected()`, `preferences.current()`) into two stored inputs, from which `activity` is derived on read, and calls `hardware.run(activity.isActive ? trackpads : [], handMode:)`. `run` means "forget every session, stop every device, then start exactly these, each with a fresh recognizer"; it converges from any prior state, including deaf devices after wake (per `make-operations-idempotent`). Inactive means the devices are stopped: nothing is recognised (as `docs/domain-model.md` says) and touching costs nothing.
4. *Activity is a pure derivation over one table.* `GestureActivity(connected:values:)` joins each connected trackpad kind to its domain's raw values through `ConflictingSetting.conflicts(rawValue:)`. "No trackpad" wins over settings; causes are listed in table order. The status icon, the notice and the fire guard read the same `launcher.activity`. Adding Smart zoom is one enum case, and the compiler lists every switch to extend.
5. *The fire path decides every silent case in one function.* `Launcher.fire` checks, in order: inactive, unassigned, missing. If all pass it plays feedback on `event.trackpad`, brings the app to front and closes the window. The guard catches a gesture already in flight when activity flips.
6. *Assignment identity is the bundle ID.* `AppCatalog.locate` tries the last-known URL first if it still holds that bundle ID outside any Trash; otherwise it asks LaunchServices for registered copies and drops those in the Trash. Nil means missing, so a reinstalled app recovers without re-picking. The resolved URL is never written back. Rows are a snapshot refreshed when the window opens and when an assignment changes; the fire path resolves fresh each time. The app picker's list is enumerated each time the picker's menu opens (`NSMenuDelegate.menuNeedsUpdate` on an `NSPopUpButton`), so R5's "each time the picker opens" holds literally and no cache exists to invalidate.
7. *First launch is derived, not flagged:* it is a first launch exactly when no settings record is stored. `start()` registers the login item before its first save, so a crash between the two re-registers next time (registration is idempotent) instead of losing the item; an undecodable record loads as defaults, not as a first launch, so a user who turned the item off is never re-enrolled (R17).
8. *Window visibility is model state* (`isWindowOpen`): R18 opens and R3 closes it from the core, so both are testable; the shell maps AppKit signals to `openWindow()`/`closeWindow()` and renders the state.
9. *Rules are enforced by structure.* `LauncherCore` cannot import AppKit, IOKit or the private framework. `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `Launcher` | 4 read-only properties, 5 intents | Persistence, first-launch policy, login item, device reconciliation across hot-plug and wake, activity derivation, fire policy, assignment resolution, refresh-on-show |
| `TrackpadHardware` | 4 members | `dlopen`, the MTTouch layout, the C-callback registry, the frame thread, IOKit and wake notifications, actuators, trackpad classification |
| `GestureRecognizer` | init and `step` | All of R11 |
| `AppCatalog` | 3 methods | Enumeration, bundle parsing, de-duplication, sorting, Trash filtering, the LaunchServices fallback |
| `TrackpadPreferences` | 2 members | KVO on two cfprefs domains, raw reads |
| `SystemActions` | 2 methods | Nothing much: the recording seam for the two effects the core decides on, with two real adapters |

**Concurrency** (Swift 6, language mode 6).

- *Main actor:* `Launcher`, the three port protocols and the public surface of every real adapter are `@MainActor`; `LauncherUI` and the app target use default main-actor isolation. `LauncherCore` and `LauncherPlatform` stay nonisolated by default because the recognizer and the C callback must not be main-isolated.
- *Frame thread:* the C callback looks up its `DeviceSession` in a `Mutex` registry (written by `run` on main, read on the frame thread), steps that device's recognizer (its own `Mutex` is the compiler's proof of single ownership and is never contended), and for events only hops with `Task { @MainActor }`.
- *Other threads:* IOKit notifications arrive through a port scheduled on `DispatchQueue.main`; wake is observed with `queue: .main`; preference KVO arrives on main (probed) but the adapter hops with `Task { @MainActor }` regardless. `AppCatalog.installedApps()` runs synchronously on the main actor when a picker's menu opens (user-initiated, tens of milliseconds).
- *Ownership:* every stored field has one writer. No two actors write the same state.

**Build and test layout.**

- Local SwiftPM package `LauncherKit` (`swift-tools-version 6.2`, `platforms: [.macOS(.v26)]`, `swiftLanguageModes: [.v6]`): library targets `LauncherCore` (Foundation, Observation), `LauncherPlatform` (AppKit, IOKit, CoreGraphics, ServiceManagement, Synchronization) and `LauncherUI` (AppKit, SwiftUI; `.defaultIsolation(MainActor.self)`); test targets `LauncherCoreTests` and `LauncherPlatformTests`, Swift Testing, run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` (`Scripts/test.sh`).
- xcodegen-generated app target `TrackpadLauncher` (`project.yml`): the composition root only; bundles the repo's `assets/*.svg` directly; Info.plist `LSUIElement = YES`, `LSMinimumSystemVersion = 26.0`; `MACOSX_DEPLOYMENT_TARGET 26.0`, `ARCHS_STANDARD` (arm64 + x86_64), hardened runtime, no sandbox, no entitlements; `Config/Debug.xcconfig` signs with Apple Development, `Config/Release.xcconfig` with Developer ID Application.
- `Scripts/release.sh`: `xcodebuild archive`, export with the developer-id method, `notarytool submit --wait`, `stapler staple`. Blocked until a Developer ID certificate exists; Apple Development signing is enough for `SMAppService` locally.
- Why: `swift test` runs the whole behavioural suite in seconds with no project generation; xcodebuild owns only what SwiftPM cannot produce (the bundle, Info.plist, signing, archiving). The Xcode 26 SDK is what makes Liquid Glass and `LSMinimumSystemVersion = 26.0` honest.

**Requirement trace.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | App target `LSUIElement` | manual |
| R2 | `GestureActivity` → `MenuBarShell` icon (`StatusIcon`) | `Launcher` seam (`activity`); look manual |
| R3 | `isWindowOpen`; shell dismissal (resign key with status-button guard, mouse-down monitor while open, Escape, icon toggle) | `Launcher` seam (gesture closes, first launch opens); rest manual |
| R4, R10 | `LauncherView` on `NSGlassEffectView`; SVGs as template images, mirrored for `.left`; hint from `AnchorCorner` | manual, light and dark |
| R5 | `AppCatalog.installedApps` on `menuNeedsUpdate` / `entry(at:)`; `AppPicker` over `NSPopUpButton`; Other… in the shell | catalog over a temp dir; menu and panel manual |
| R6, R8 | `Settings` defaults; `SettingsStore` | `Launcher` seam over a throwaway suite (two models, same suite) |
| R7 | `AppCatalog.locate`; rows refreshed on open; fire guard | `Launcher` seam over a temp dir (move, trash, reinstall) |
| R9 | `HandMode` → `AnchorCorner` via `run(_:handMode:)` | recognizer and `Launcher` seams |
| R11 | `GestureRecognizer`, `GestureRules` | recognizer seam (every scenario) and `Launcher` seam |
| R12 | `SystemActions.bringToFront` → `openApplication` with `activates` | recording fake; real call probed; Spaces and full-screen manual |
| R13 | `Launcher.fire` → `playFeedback(on: event.trackpad)` | `Launcher` seam (`feedback`) |
| R14, R15 | `ConflictingSetting` table, `GestureActivity`, `reconcile`, `TrackpadSettingsNotice` | pure table tests and `Launcher` seam |
| R16 | `MultitouchTrackpads` (IOKit, wake) → `reconcile` | `Launcher` seam via `attach`/`detach`/`wake`; hardware manual |
| R17, R18 | `Launcher.start` (first launch ⇔ nothing stored); `registerLoginItem` | `Launcher` seam |
| R19 | Shell Quit → `NSApp.terminate` | manual |
| R20–R22 | Module boundaries, push-only adapters, `run([])` when inactive, `SourcePolicyTests` | source scan; Console, network monitor and Activity Monitor manual |
| R23 | App target settings and release script | manual; blocked on Developer ID |

**Deliberately not done.** No FSEvents and no polling of app folders. No write-back of resolved URLs. No `NSHapticFeedbackManager`. No key-event monitors; the only global monitor is mouse-down and exists only while the window is open. No framework type crosses a port: `MTTouch`, `CFTypeRef`, `UserDefaults`, `NSRunningApplication` and `NSImage` stay inside adapters and views. No fast-user-switching handling (not required; see open questions).

#### Module map

```
LauncherCore     (Foundation, Observation)          domain types · GestureRules · GestureRecognizer · ConflictingSetting table ·
                                                     GestureActivity · AppCatalog · Settings/SettingsStore · ports · Launcher
LauncherPlatform (AppKit, IOKit, CoreGraphics,       MultitouchTrackpads (MT dlopen, MTTouch parse, C callback, IOKit, wake,
                  ServiceManagement, Synchronization)  actuators, trackpad classification) · SystemTrackpadPreferences (KVO) ·
                                                     WorkspaceActions · AppCatalog.system
LauncherUI       (AppKit, SwiftUI; MainActor)        MenuBarShell · LauncherPanel · StatusIcon · LauncherView · GestureRowView ·
                                                     AppPicker · HandModeToggle · HintText · TrackpadSettingsNotice
TrackpadLauncher app target (xcodegen)              composition root · Info.plist · assets/*.svg
Tests                                               LauncherCoreTests (recognizer, activity table, catalog, store, Launcher seam,
                                                     SourcePolicyTests) · LauncherPlatformTests (prefs KVO with throwaway domains,
                                                     MTTouch stride == 96, trackpad classification table)
```

#### LauncherCore: gesture domain and recognizer

```swift
import Foundation

/// Which hand holds the anchored thumb (R9). One global setting; default `.right`.
public enum HandMode: String, Codable, Sendable, CaseIterable {
    case right   // anchor corner top-left
    case left    // anchor corner top-right
    /// The words the hint uses (R10): "top-left" or "top-right".
    public var cornerName: String { self == .right ? "top-left" : "top-right" }
}

/// Every fixed number in gesture recognition, in one place (R11; not user-tunable per Non-goals).
package enum GestureRules {
    static let cornerWidth = 0.20                            // fraction of width, from the anchor-side edge
    static let cornerHeight = 0.25                           // fraction of height, from the top edge
    static let anchorReleaseMarginMM = 2.0                   // an anchored thumb may roll this far past the zone edge
    static let maxTapDuration = Duration.milliseconds(300)   // first finger down → last finger up
    static let dragThresholdMM = 3.0                         // a finger farther than this from its landing point is dragging
}

/// Normalised position: x 0 = left edge … 1 = right edge; y 0 = TOP edge … 1 = bottom edge.
/// The MT adapter maps MultitouchSupport's convention onto this one; nothing else knows about it.
public struct SurfacePoint: Hashable, Sendable { public var x: Double; public var y: Double }

/// Physical surface size from MTDeviceGetSensorSurfaceDimensions (probed: 124.8 × 76.8 mm, 14" MacBook Pro).
public struct SurfaceSize: Hashable, Sendable {
    public var widthMM: Double; public var heightMM: Double
    /// Distance in millimetres between two normalised points on this surface.
    public func distanceMM(_ a: SurfacePoint, _ b: SurfacePoint) -> Double { fatalError("not implemented") }
}

/// The fixed zone where a thumb arms gestures (R11).
package struct AnchorCorner: Sendable {
    package init(_ handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }
    /// A contact *landing* here, while no thumb is anchored, becomes the anchored thumb.
    /// fromEdge = right hand ? p.x : 1 - p.x;  fromEdge < cornerWidth && p.y < cornerHeight
    package func admits(_ p: SurfacePoint) -> Bool { fatalError("not implemented") }
    /// An anchored thumb stays anchored while inside the zone grown by `anchorReleaseMarginMM`.
    package func holds(_ p: SurfacePoint) -> Bool { fatalError("not implemented") }
}

public struct TouchID: Hashable, Sendable { public let rawValue: Int32 }

/// A contact that is DOWN in this frame. The adapter drops hovering, lingering and lifted contacts.
/// `.landing` is MT state 3 (MakeTouch). A tracked ID that reappears with `.landing` was lifted and has landed
/// anew (the driver reused the ID); an ID that appears without `.landing` is treated as landed too.
public struct Touch: Sendable {
    public enum Phase: Sendable { case landing, down }
    public let id: TouchID
    public let phase: Phase
    public let position: SurfacePoint
}

/// Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads.
public struct FrameTime: Comparable, Sendable {
    public var seconds: Double
    public static func - (lhs: FrameTime, rhs: FrameTime) -> Duration { .seconds(lhs.seconds - rhs.seconds) }
    public static func < (lhs: FrameTime, rhs: FrameTime) -> Bool { lhs.seconds < rhs.seconds }
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot:
/// a contact absent from `touches` has lifted. `[]` is the frame after the last lift.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
    public let buttonDown: Bool   // any mouse button pressed, sampled when the frame arrived (click ≠ tap)
}

/// One of the four launcher gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Comparable {
    case one = 1, two, three, four
    /// nil outside 1...4: a five-finger tap is not a gesture (R11).
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
    public static func < (a: Gesture, b: Gesture) -> Bool { a.rawValue < b.rawValue }
}

/// A gesture that fired on a specific trackpad (feedback plays on that one, R13).
public struct GestureEvent: Equatable, Sendable { public let gesture: Gesture; public let trackpad: TrackpadID }

/// R11 for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }

    /// The gesture that fired on this frame, if any. At most once per tap, on the frame where the last finger lifts.
    public mutating func step(_ frame: TouchFrame) -> Gesture? {
        // TODO
        // down   = frame.touches keyed by id
        // reused = ids in previouslyDown whose touch has phase .landing        (lifted AND landed anew on this frame)
        // lifted = previouslyDown − down.keys, plus reused
        // landed = touches with phase .landing, plus ids not in previouslyDown
        // Lifts are evaluated before landings: a tap that ends on this frame fires before this frame's landings
        // are seen, so a reused ID cannot fuse two taps.
        //
        // 1. Anchor maintenance (every state that carries an anchor):
        //      anchor.id in lifted, or !corner.holds(its position)  → state = .idle
        //      (a thumb that slides out is from then on just a finger; it is not re-adopted.
        //       thumb lifting before the fingers, or in the same frame as the last finger → idle → no fire)
        // 2. switch state
        //    .idle:
        //      if let thumb = landed.first(where: { corner.admits($0.position) }):
        //          anchor = Anchor(thumb.id, since: frame.time)
        //          state = (down minus thumb).isEmpty ? .armed(anchor) : .spoiled(anchor)
        //          // fingers already down when the thumb lands (or landing in the same frame) never fire: wait for a clean slate
        //    .armed(anchor):
        //      fingers = landed minus anchor
        //      if !fingers.isEmpty:
        //          state = frame.buttonDown ? .spoiled(anchor)
        //                                  : .tapping(anchor, fingers: [id: landing point], peak: fingers.count, start: frame.time)
        //    .tapping(anchor, fingers, peak, start):
        //      remove lifted ids from fingers
        //      if frame.buttonDown || frame.time - start > maxTapDuration
        //         || any remaining finger is > dragThresholdMM (surface.distanceMM) from its landing point → state = .spoiled(anchor)
        //      else if fingers.isEmpty:                                 // the last finger lifted on this frame
        //          fired = Gesture(fingerCount: peak)                   // nil for 5+
        //          new = landed minus anchor                            // a reused ID, or a fresh landing, starts the next tap now
        //          state = new.isEmpty ? .armed(anchor)
        //                              : .tapping(anchor, fingers: [id: landing point], peak: new.count, start: frame.time)
        //      else:
        //          add landed non-anchor touches to fingers; peak = max(peak, fingers.count)
        //    .spoiled(anchor):
        //      if (down minus anchor).isEmpty → state = .armed(anchor)
        // 3. previouslyDown = Set(down.keys); return fired
        fatalError("not implemented")
    }

    private struct Anchor: Sendable { let id: TouchID; let since: FrameTime }
    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, fingers: [TouchID: SurfacePoint], peak: Int, start: FrameTime)
        case spoiled(Anchor)
    }
    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID> = []
}
```

#### LauncherCore: trackpads, settings table, activity

```swift
/// MultitouchSupport device ID (== IORegistry "Multitouch ID", probed).
public struct TrackpadID: Hashable, Sendable { public let rawValue: UInt64 }

/// macOS keeps trackpad settings per kind: one domain for the built-in, one shared by all external trackpads (R14).
public enum TrackpadKind: Hashable, Sendable, CaseIterable { case builtIn, external }

public struct Trackpad: Hashable, Sendable, Identifiable {
    public let id: TrackpadID
    public let kind: TrackpadKind
    public let surface: SurfaceSize
}

/// A system trackpad setting that binds an action to a tap, so gestures cannot coexist with it (R14).
/// THIS ENUM IS THE TABLE: every case supplies its key, its conflicting value and its notice text through
/// exhaustive switches, so adding Smart zoom is one case the compiler forces through all three.
/// `allCases` order is notice order (R15). Values are sourced (grounding Q4); a correction is one line here.
public enum ConflictingSetting: CaseIterable, Hashable, Sendable {
    case tapToClick
    case lookUpTapWithThreeFingers
    // case smartZoom   // R14: add if testing shows a two-finger double tap fires with a thumb anchored

    /// Key within each trackpad preference domain. Read only by the preferences adapter.
    package var preferenceKey: String {
        switch self {
        case .tapToClick:                 "Clicking"
        case .lookUpTapWithThreeFingers:  "TrackpadThreeFingerTapGesture"
        }
    }
    /// True when the raw value means the action is bound to a tap. nil (key absent) is off.
    public func conflicts(rawValue: Int?) -> Bool {
        switch self {
        case .tapToClick:                 rawValue == 1
        case .lookUpTapWithThreeFingers:  rawValue == 2
        }
    }
    /// Exactly the words the trackpad settings notice uses (R15).
    public var noticeName: String {
        switch self {
        case .tapToClick:                 "Tap to click"
        case .lookUpTapWithThreeFingers:  "Look up: Tap with three fingers"
        }
    }
}

/// Raw values of the table keys as read from one domain. Absent keys are absent entries.
public typealias TrackpadPreferenceValues = [ConflictingSetting: Int]

/// Non-empty, in table order. The failable init is the only constructor.
public struct ConflictingSettings: Equatable, Sendable {
    public let settings: [ConflictingSetting]
    public init?(_ settings: [ConflictingSetting]) { fatalError("not implemented") }   // nil when empty
}

public enum InactiveCause: Equatable, Sendable {
    case noTrackpad
    case settings(ConflictingSettings)
}

/// Gestures active / inactive (R2, R14, R15). One value read by the icon, the notice and the fire guard.
public enum GestureActivity: Equatable, Sendable {
    case active
    case inactive(InactiveCause)

    public var isActive: Bool { self == .active }

    /// Pure. No trackpad wins over settings; a setting blocks when it conflicts on ANY connected kind.
    public init(connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues]) {
        // guard !connected.isEmpty else { self = .inactive(.noTrackpad); return }
        // let blocking = ConflictingSetting.allCases.filter { s in connected.contains { kind in s.conflicts(rawValue: values[kind]?[s]) } }
        // self = ConflictingSettings(blocking).map { .inactive(.settings($0)) } ?? .active
        fatalError("not implemented")
    }
}
```

#### LauncherCore: apps, assignments, persistence

```swift
public struct BundleID: Hashable, Codable, Sendable { public let rawValue: String }

/// An app bundle on disk right now.
public struct AppEntry: Hashable, Sendable, Identifiable {
    public let bundleID: BundleID
    public let name: String   // FileManager display name, without ".app"
    public let url: URL
    public var id: BundleID { bundleID }
}

/// What a gesture points at (R7): identity, plus what is needed to show it while missing and to find it fast.
public struct AssignedApp: Codable, Hashable, Sendable {
    public let bundleID: BundleID   // identity
    public let name: String         // shown greyed with "not found"
    public let lastKnownURL: URL    // fast path only; never authoritative, never rewritten
    public init(_ entry: AppEntry) { fatalError("not implemented") }
}

/// The app picker's three kinds of item (R5).
public enum AppChoice: Sendable {
    case app(AppEntry)        // from the installed list
    case appBundle(at: URL)   // from Other…; parsed by AppCatalog.entry(at:), ignored if not an app with a bundle ID
    case unassigned           // None
}

public enum RowApp: Equatable, Sendable { case unassigned, present(AppEntry), missing(name: String) }

/// A gesture row as the launcher window shows it (R5–R7).
public struct GestureRow: Identifiable, Equatable, Sendable {
    public let gesture: Gesture
    public let app: RowApp
    public var id: Gesture { gesture }
}

/// Apps on disk (R5, R7). Local-substitutable: tests point it at a temp directory of fake bundles
/// (a folder with Contents/Info.plist is a bundle to `Bundle(url:)`) and inject `registeredCopies`.
public struct AppCatalog: Sendable {
    public init(roots: [URL], extras: [URL], registeredCopies: @escaping @Sendable (BundleID) -> [URL]) {
        fatalError("not implemented")
    }

    /// Picker list: every .app under `roots` (recursing into folders, never into bundles, skipping hidden files)
    /// plus `extras` (Finder). One entry per bundle ID (first root wins), sorted by localizedStandardCompare.
    /// Bundles without an identifier are skipped (they cannot be assigned by identity).
    /// Enumerates on every call: the picker calls it each time its menu opens (R5).
    public func installedApps() -> [AppEntry] { fatalError("not implemented") }

    /// Boundary parse for Other…: the app bundle at `url`, if it has a bundle identifier.
    public func entry(at url: URL) -> AppEntry? { fatalError("not implemented") }

    /// Where the assigned app lives now; nil = missing.
    /// 1. lastKnownURL, if it is outside the Trash and still holds that bundle ID (also covers ~/Downloads picks).
    /// 2. else the first of registeredCopies(bundleID) outside the Trash that still holds that bundle ID.
    public func locate(_ app: AssignedApp) -> AppEntry? { fatalError("not implemented") }

    /// Any path component named ".Trash" or ".Trashes".
    static func isInTrash(_ url: URL) -> Bool { fatalError("not implemented") }
}

/// Everything persisted besides the implicit "launched before" (R8, R21).
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right                  // R9 default
    public var assignments: [Gesture: AssignedApp] = [:]    // absent = unassigned (R6 fresh install)
}

/// One plist-encoded record under one key. Local-substitutable: tests use UserDefaults(suiteName: "test-<uuid>").
@MainActor public struct SettingsStore {
    public init(defaults: UserDefaults, key: String = "settings") { fatalError("not implemented") }
    /// nil ⇔ nothing was ever saved ⇔ first launch (R18). Undecodable data loads as `Settings()`, NOT as a first launch.
    public func load() -> Settings? { fatalError("not implemented") }
    public func save(_ settings: Settings) { fatalError("not implemented") }
}
```

#### LauncherCore: ports

```swift
public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case trackpadsChanged   // attached, detached, or the Mac woke
}

/// The multitouch hardware. Real: MultitouchTrackpads. Test: InMemoryTrackpads.
@MainActor public protocol TrackpadHardware: AnyObject {
    /// Always called on the main actor.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    /// Trackpads connected now. Excludes multitouch devices that are not trackpads (Magic Mouse, Touch Bar).
    func connected() -> [Trackpad]
    /// Forgets every session, stops every running device, then starts exactly `trackpads`, each with a fresh
    /// GestureRecognizer for `handMode`. Idempotent. [] = nothing runs (zero cost).
    func run(_ trackpads: [Trackpad], handMode: HandMode)
    /// One haptic pulse on that trackpad (feedback, R13). No-op if it is gone.
    func playFeedback(on trackpad: TrackpadID)
}

/// The two trackpad preference domains. Real: SystemTrackpadPreferences. Test: InMemoryTrackpadPreferences.
@MainActor public protocol TrackpadPreferences: AnyObject {
    /// Called on the main actor after any table key changes in either domain.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Current raw values of every table key, per kind, read fresh (cheap, probed). Reads only; never writes a system domain.
    func current() -> [TrackpadKind: TrackpadPreferenceValues]
}

/// Effects the core decides and macOS performs. Real: WorkspaceActions. Test: RecordingSystemActions.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click (R12).
    func bringToFront(_ app: AppEntry)
    /// Open at Login (R17). Idempotent. Called only on first launch.
    func registerLoginItem()
}
```

#### LauncherCore: the Launcher (the high seam)

```swift
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// Invariants: `activity` is derived, never stored; `rows` derive from settings + the catalog; `fire` is the only
/// path that pulses, launches, or closes the window from a gesture; every stored field has one writer: this actor.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    public private(set) var isWindowOpen = false
    public var handMode: HandMode { settings.handMode }
    /// R2, R14, R15: one derivation, every reader (icon, notice, fire guard).
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }

    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let store: SettingsStore

    public init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, system: any SystemActions,
                catalog: AppCatalog, store: SettingsStore) {
        // let stored = store.load(); isFirstLaunch = stored == nil; settings = stored ?? Settings(); rows = makeRows()
        fatalError("not implemented")
    }

    /// Launch. Call once, after the status item exists (R16–R18).
    public func start() {
        hardware.onEvent = { [unowned self] event in
            switch event {
            case .gesture(let fired): fire(fired)
            case .trackpadsChanged: reconcile()
            }
        }
        preferences.onChange = { [unowned self] in reconcile() }
        reconcile()
        guard isFirstLaunch else { return }
        system.registerLoginItem()   // before the first save: a crash in between re-registers, never loses it
        store.save(settings)         // from now on, not a first launch
        openWindow()
    }

    /// App picker (R5–R7). Same app on two gestures is fine (R5).
    public func setAssignment(_ choice: AppChoice, for gesture: Gesture) {
        // .app(e) → settings.assignments[gesture] = AssignedApp(e)
        // .appBundle(url) → guard let e = catalog.entry(at: url) else { return }; same
        // .unassigned → settings.assignments[gesture] = nil
        // store.save(settings); rows = makeRows()
        fatalError("not implemented")
    }

    /// Hand mode toggle (R9). Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setHandMode(_ mode: HandMode) {
        // guard mode != settings.handMode; settings.handMode = mode; store.save(settings); reconcile()
        fatalError("not implemented")
    }

    /// Show the launcher window and re-resolve the rows (R7 missing/recovered). The picker's list is not held here:
    /// the picker enumerates the catalog itself each time its menu opens (R5).
    public func openWindow() {
        isWindowOpen = true
        rows = makeRows()
    }

    public func closeWindow() { isWindowOpen = false }

    /// The one convergent operation behind launch, hot-plug, wake, preference and hand-mode changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        hardware.run(activity.isActive ? connected : [], handMode: settings.handMode)
    }

    /// Every silent case of R13 decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(on: event.trackpad)
        system.bringToFront(app)
        isWindowOpen = false   // R3: the window closes as the target app comes to the front
    }

    private func makeRows() -> [GestureRow] {
        // Gesture.allCases.map { g in
        //   settings.assignments[g].map { a in catalog.locate(a).map(RowApp.present) ?? .missing(name: a.name) } ?? .unassigned }
        fatalError("not implemented")
    }
}
```

#### LauncherPlatform: real adapters

```swift
import AppKit
import IOKit
import ServiceManagement
import Synchronization

/// TrackpadHardware over MultitouchSupport (dlopen), IOKit and NSWorkspace notifications.
/// Threads: frames arrive on MultitouchSupport's thread and are recognised THERE; only gestures hop to main.
/// IOKit matched/terminated: notification port on DispatchQueue.main (initial iterator drained; that first
/// callback is one harmless extra reconcile). Wake: observer on `.main`.
@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    public var onEvent: (@MainActor (TrackpadEvent) -> Void)?

    /// dlopen + dlsym once (the probed symbol set). On failure: connected() == [] → "No trackpad connected".
    /// Registers IOServiceAddMatchingNotification(first-match + terminated, "AppleMultitouchDevice") and
    /// NSWorkspace.didWakeNotification → onEvent(.trackpadsChanged).
    public init() { fatalError("not implemented") }

    /// MTDeviceCreateList → keep devices classified as trackpads → [Trackpad].
    public func connected() -> [Trackpad] { fatalError("not implemented") }

    public func run(_ trackpads: [Trackpad], handMode: HandMode) {
        // TODO
        // 1. let old = sessions.withLock { s in defer { s = [:] }; return s }   — registry cleared FIRST:
        //    in-flight frames from old refs now find nothing and are dropped
        // 2. For every old session: MTUnregisterContactFrameCallback, MTDeviceStop, MTActuatorClose, MTDeviceRelease.
        // 3. Re-list; for each device whose ID is in `trackpads`:
        //      session = DeviceSession(trackpad, GestureRecognizer(handMode, surface), deliver: hop to main)
        //      open its actuator (MTActuatorCreateFromDeviceID + MTActuatorOpen) for low-latency feedback
        //      sessions[ref] = session; MTRegisterContactFrameCallback(ref, contactFrameCallback); MTDeviceStart(ref, 0)
        // Postcondition: frames flow from exactly `trackpads`, each into a fresh recognizer.
        fatalError("not implemented")
    }

    /// MTActuatorActuate(actuator, Self.feedbackActuation, 0, 0, 0). Strength is a feel choice (3/4/6).
    public func playFeedback(on trackpad: TrackpadID) { fatalError("not implemented") }
    static let feedbackActuation: Int32 = 6
}

/// The only shared state on the frame path: written by `run` (main), read by the callback (frame thread).
private let sessions = Mutex<[UInt: DeviceSession]>([:])   // key: MTDeviceRef bit pattern

/// One running trackpad. Its recognizer is stepped only by that device's frame callbacks;
/// the Mutex is the compiler's proof and is never contended.
private final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    let recognizer: Mutex<GestureRecognizer>
    let deliver: @Sendable (GestureEvent) -> Void   // { e in Task { @MainActor [weak owner] in owner?.onEvent?(.gesture(e)) } }
    init(trackpad: TrackpadID, recognizer: GestureRecognizer, deliver: @escaping @Sendable (GestureEvent) -> Void) {
        fatalError("not implemented")
    }
}

/// `int cb(MTDeviceRef, MTTouch*, int count, double timestamp, int frame)`; context-free, hence the global registry.
private let contactFrameCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32 = {
    device, touches, count, timestamp, _ in
    // guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    // let frame = TouchFrame(parsing: touches, count: count, timestamp: timestamp, buttonDown: anyMouseButtonDown())
    // if let g = session.recognizer.withLock({ $0.step(frame) }) { session.deliver(GestureEvent(gesture: g, trackpad: session.trackpad)) }
    return 0
}

/// The 96-byte MTTouch mirror (stride checked by a test). Only this file knows its layout.
struct MTTouchMirror { /* frame, timestamp, identifier, state, fingerID, handID, normalized(pos, vel), zTotal, … */ }

extension TouchFrame {
    /// MTTouch[] → TouchFrame. Keeps states 3 (MakeTouch → .landing) and 4 (Touching → .down) only;
    /// maps MT's bottom-left normalised origin to SurfacePoint's top-left one.
    /// A layout correction after the first real-touch check is a change here and nowhere else.
    init(parsing touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double, buttonDown: Bool) {
        fatalError("not implemented")
    }
}

/// Magic Mouse and Touch Bar digitizers are multitouch devices but not trackpads (checks). One table, one place:
/// the IORegistry "Product" string of MTDeviceGetService(ref) must contain "Trackpad"; MTDeviceIsBuiltIn picks the kind.
func trackpadKind(product: String, isBuiltIn: Bool) -> TrackpadKind? { fatalError("not implemented") }

/// CGEventSource.buttonState(.combinedSessionState, …) for .left, .right, .center: a state query, no tap, no TCC.
func anyMouseButtonDown() -> Bool { fatalError("not implemented") }

/// TrackpadPreferences over the two cfprefs domains (probed: KVO fires when another process writes).
@MainActor public final class SystemTrackpadPreferences: TrackpadPreferences {
    public static let systemDomains: [TrackpadKind: String] = [
        .builtIn: "com.apple.AppleMultitouchTrackpad",
        .external: "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]
    public var onChange: (@MainActor () -> Void)?
    /// KVO (addObserver forKeyPath:) on every ConflictingSetting.preferenceKey in each suite;
    /// the nonisolated observeValue hops with Task { @MainActor }. Injectable domains for its own test.
    public init(domains: [TrackpadKind: String] = systemDomains) { fatalError("not implemented") }
    /// `suite.object(forKey:) as? Int` for every table key in every domain, regardless of what is connected.
    public func current() -> [TrackpadKind: TrackpadPreferenceValues] { fatalError("not implemented") }
}

@MainActor public final class WorkspaceActions: SystemActions {
    public init() {}
    /// NSWorkspace.openApplication(at: app.url, configuration: activates = true); completion ignored (nothing to log).
    public func bringToFront(_ app: AppEntry) { fatalError("not implemented") }
    /// try? SMAppService.mainApp.register()
    public func registerLoginItem() { fatalError("not implemented") }
}

extension AppCatalog {
    /// roots: /Applications, /System/Applications, ~/Applications · extras: /System/Library/CoreServices/Finder.app ·
    /// registeredCopies: NSWorkspace.shared.urlsForApplications(withBundleIdentifier:)
    public static var system: AppCatalog { fatalError("not implemented") }
}
```

#### LauncherUI: menu bar shell and launcher window

```swift
import AppKit
import SwiftUI

/// The thin AppKit shell (R1–R3, R15 button, R19). Maps AppKit signals to Launcher intents; renders Launcher state.
public final class MenuBarShell {
    public init(launcher: Launcher, catalog: AppCatalog) {
        // statusItem = NSStatusBar.system.statusItem(withLength: .squareLength); button image StatusIcon.image(active:)
        // actions = LauncherActions(installedApps: { catalog.installedApps() }, chooseOtherApp:, openTrackpadSettings:, quit:)
        // panel = LauncherPanel(content: LauncherView(launcher, actions: actions))
        // Task { for await active in Observations({ launcher.activity.isActive }) { button.image = StatusIcon.image(active:) } }
        // Task { for await open in Observations({ launcher.isWindowOpen }) { open ? showBelowIcon() : hide() } }
        //
        // Dismissal (R3):
        //   icon click        → launcher.isWindowOpen ? launcher.closeWindow() : launcher.openWindow()
        //   panel resigns key → launcher.closeWindow(), unless NSApp.currentEvent is a mouse-down in the status
        //                       item's button window (that click is the toggle above; otherwise it would close and reopen)
        //   mouse-down elsewhere → global monitor [.leftMouseDown, .rightMouseDown, .otherMouseDown], installed on
        //                       show and removed on hide (no idle cost; mouse-only monitors need no permission)
        //   Escape            → LauncherPanel.cancelOperation → launcher.closeWindow()
        //   gesture           → Launcher sets isWindowOpen = false → hide()
        // Other… (R5): closeWindow(); NSApp.activate(); NSOpenPanel(allowedContentTypes: [.application],
        //   canChooseDirectories: false).begin { url → setAssignment(.appBundle(at:)) }; then openWindow().
        // Notice button (R15): NSWorkspace.open("x-apple.systempreferences:com.apple.preference.trackpad").
        // Quit (R19): NSApp.terminate(nil); the login item is untouched.
        fatalError("not implemented")
    }
}

/// Borderless, non-activating, key-capable; pop-up-menu level; joins all Spaces and full-screen apps.
/// contentView = NSGlassEffectView (style .regular, cornerRadius set) whose contentView = NSHostingView(LauncherView).
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { fatalError("not implemented") }   // Escape
}

/// Template images for light and dark menu bars (R2). Inactive = the same symbol plus a knocked-out diagonal
/// stroke, drawn once (SF Symbols has no slashed hand symbol; checked against name_availability.plist).
enum StatusIcon { static func image(active: Bool) -> NSImage { fatalError("not implemented") } }

/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    let installedApps: () -> [AppEntry]   // the catalog, enumerated each time a picker's menu opens (R5)
    let chooseOtherApp: (Gesture) -> Void
    let openTrackpadSettings: () -> Void
    let quit: () -> Void
}

/// The app picker (R5): an NSPopUpButton whose NSMenuDelegate.menuNeedsUpdate rebuilds the items from
/// `installedApps()` every time the menu opens (icon + name per app, then a separator, Other…, None).
/// The button shows the row's app with its icon (NSWorkspace.icon(forFile:)), "Choose app…" when unassigned,
/// or the greyed name with "not found" when missing (R6, R7).
struct AppPicker: NSViewRepresentable {
    let app: RowApp
    let installedApps: () -> [AppEntry]
    let choose: (AppChoice) -> Void
    let chooseOther: () -> Void
    func makeNSView(context: Context) -> NSPopUpButton { fatalError("not implemented") }
    func updateNSView(_ button: NSPopUpButton, context: Context) { fatalError("not implemented") }
}

/// R4 layout: four gesture rows, HandModeToggle ("Left hand | Right hand"), Divider, then HintText while active
/// ("Hold thumb on \(handMode.cornerName) corner, tap with 1, 2, 3 or 4 fingers anywhere to launch selected app")
/// or TrackpadSettingsNotice(cause) while inactive (names from ConflictingSetting.noticeName, or "No trackpad
/// connected", plus the Trackpad settings button), then a bottom bar with Quit only.
/// The illustrations are assets/*.svg from Bundle.main as template images, mirrored horizontally for .left (R10).
struct LauncherView: View {
    let launcher: Launcher
    let actions: LauncherActions
    var body: some View { fatalError("not implemented") }
}
```

#### Tests: in-memory adapters and the source policy

```swift
/// Real recognizer, scripted frames, synchronous main-actor delivery: R11 scenarios run through the whole app.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad] = [.macBook14]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []          // running devices that deliver nothing until the next `run`
    private(set) var feedback: [TrackpadID] = []
    func connected() -> [Trackpad] { attached }
    func run(_ trackpads: [Trackpad], handMode: HandMode) { /* running = fresh recognizers for trackpads; deaf = [] */ }
    func playFeedback(on trackpad: TrackpadID) { feedback.append(trackpad) }
    func attach(_ t: Trackpad) { /* append; onEvent?(.trackpadsChanged) */ }
    func detach(_ id: TrackpadID) { /* remove; onEvent?(.trackpadsChanged) */ }
    /// After sleep the real devices deliver nothing until `run` restarts them (grounding Q5); so does this fake.
    /// A test calls `sleep()` then `wake()`: a reconcile that does not re-run the devices leaves them deaf (R16).
    func sleep() { deaf = Set(running.keys) }
    func wake() { onEvent?(.trackpadsChanged) }
    /// Frames on a trackpad that is not running, or deaf since `sleep()`, are dropped, exactly like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) { /* step running[id]; onEvent?(.gesture) on each fire */ }
    /// A gesture the frame thread recognised just before activity flipped: delivered regardless of `running`,
    /// so the guard in `Launcher.fire` can be shown to hold.
    func inject(_ event: GestureEvent) { onEvent?(.gesture(event)) }
}

@MainActor final class InMemoryTrackpadPreferences: TrackpadPreferences {
    var onChange: (@MainActor () -> Void)?
    private var values: [TrackpadKind: TrackpadPreferenceValues] = [:]
    func current() -> [TrackpadKind: TrackpadPreferenceValues] { values }
    func set(_ setting: ConflictingSetting, rawValue: Int?, for kind: TrackpadKind) { /* mutate; onChange?() */ }
}

@MainActor final class RecordingSystemActions: SystemActions {
    private(set) var broughtToFront: [AppEntry] = []
    private(set) var loginItemRegistrations = 0
    /// Runs inside `registerLoginItem()`; the World wires it to snapshot `store.load()`, so a test can show the
    /// login item is registered before the first save (R17, decision 7).
    var onRegisterLoginItem: (() -> Void)?
    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }
    func registerLoginItem() { loginItemRegistrations += 1; onRegisterLoginItem?() }
}

/// Test fixtures for trackpads (surface from the probed 14" MacBook Pro; a Magic Trackpad is 160 × 115 mm).
extension Trackpad {
    static let macBook14 = Trackpad(id: TrackpadID(rawValue: 1), kind: .builtIn, surface: .macBook14)
    static let magicTrackpad = Trackpad(id: TrackpadID(rawValue: 2), kind: .external, surface: SurfaceSize(widthMM: 160, heightMM: 115))
}
extension SurfaceSize { static let macBook14 = SurfaceSize(widthMM: 124.8, heightMM: 76.8) }

/// Frames in millimetres on a surface, 10 ms apart unless told otherwise; `.landing` on each first frame.
/// R11 scripts: thumbFirstThenTap · repeatedTapsWhileAnchored · fingersBeforeThumb · sameFrameThumbAndFinger ·
/// thumbOutsideCorner · thumbAloneFiveSeconds · dragIsNotATap · fiveFingers · clickOnLanding · clickMidway ·
/// staggeredLandingAndLifting · thumbLiftsBeforeFingers · tapHeldTooLong · cornerAt1cmAnd4cm · leftHandMirror ·
/// thumbRollsWithinMargin · idReusedOnNextFrame.
/// The builder sequences thumb → taps → lifts; the four scripts it cannot sequence (fingersBeforeThumb,
/// sameFrameThumbAndFinger, thumbLiftsBeforeFingers, idReusedOnNextFrame) hand-build their frames through
/// TouchFrame's and Touch's public initialisers rather than growing the builder with offsets and ID-reuse options.
struct TouchScript {
    enum ClickTiming { case none, onLanding, midway }   // buttonDown on the landing frame, or on a frame mid-tap
    init(_ surface: SurfaceSize) { fatalError("not implemented") }
    func thumb(atMM p: (x: Double, y: Double)) -> TouchScript { fatalError("not implemented") }
    func tap(fingers n: Int, atMM p: (x: Double, y: Double) = (62, 45), stagger: Duration = .zero,
             hold: Duration = .milliseconds(120), dragMM: Double = 0, click: ClickTiming = .none) -> TouchScript { fatalError("not implemented") }
    /// Moves the anchored thumb over the following frames (thumbRollsWithinMargin: inside the margin keeps the anchor; past it drops it).
    func rollThumb(toMM p: (x: Double, y: Double)) -> TouchScript { fatalError("not implemented") }
    func liftThumb() -> TouchScript { fatalError("not implemented") }
    func wait(_ d: Duration) -> TouchScript { fatalError("not implemented") }
    var frames: [TouchFrame] { fatalError("not implemented") }
}

/// R20–R22 as a gate: scans every .swift file in LauncherKit/Sources and the app target; fails on any hit.
@Suite struct SourcePolicyTests {
    static let banned: [(token: String, rule: String)] = [
        ("print(", "R21 log"), ("debugPrint(", "R21 log"), ("dump(", "R21 log"), ("NSLog(", "R21 log"),
        ("os_log", "R21 log"), ("Logger(", "R21 log"), ("import OSLog", "R21 log"), ("import os", "R21 log"),
        ("URLSession", "R21 network"), ("import Network", "R21 network"), ("NWConnection", "R21 network"),
        ("CFSocket", "R21 network"), ("CFStream", "R21 network"),
        ("FileHandle(forWriting", "R21 own files"), (".write(to:", "R21 own files"), ("createFile(atPath", "R21 own files"),
        ("Timer", "R22 timer"), ("asyncAfter", "R22 timer"), ("Task.sleep", "R22 polling"), ("makeTimerSource", "R22 timer"),
        ("AXIsProcessTrusted", "R20"), ("tapCreate", "R20"), ("CGEventTapCreate", "R20"), ("IOHIDManager", "R20"),
        ("CGRequestListenEventAccess", "R20"), ("CGPreflightListenEventAccess", "R20"),
    ]
    @Test(arguments: banned) func noSourceUses(_ entry: (token: String, rule: String)) { /* scan; #expect(hits.isEmpty) */ }
}
```

**Test handles.** Everything a test cannot wait for or trigger directly.

| Thing | Handle |
|---|---|
| Clock behind the tap timeout | `TouchFrame.time`; no clock object exists |
| Frame source | `InMemoryTrackpads.touch(_:on:)` |
| Button-state sampler | `TouchFrame.buttonDown` |
| Preference store and its live change | `InMemoryTrackpadPreferences.set` (invokes `onChange` synchronously); the real adapter is tested against throwaway domains written with `defaults` |
| Device notifications | `attach` / `detach` / `wake` |
| Deaf devices after sleep | `InMemoryTrackpads.sleep()` then `wake()` |
| A gesture already in flight when activity flips | `InMemoryTrackpads.inject(_:)` |
| A click on the landing frame or mid-tap | `TouchScript.tap(click:)` |
| Bring to front and login item | `RecordingSystemActions` |
| Register-before-save order | `RecordingSystemActions.onRegisterLoginItem` snapshotting `store.load()` |
| Actuator | `InMemoryTrackpads.feedback` |
| Settings across "reboot" | `SettingsStore` over one throwaway suite shared by two `Launcher` instances |
| Disk, Trash, moves, reinstalls | `AppCatalog` over a temp directory with an injected `registeredCopies` |
| Window | `launcher.isWindowOpen` |
| Hint wording | `HandMode.cornerName` |
| No logging, network, timers, permission APIs | `SourcePolicyTests` |

### Synthesis decision

Both candidates converged on the whole shape: one `@MainActor @Observable` hub owning all policy; a pure per-trackpad recognizer stepped on the frame thread with the frame timestamp as its only clock (both independently rejected an injected clock and any timer); a table-driven activity derivation read by icon, notice and fire guard; an idempotent restart-everything reconcile; bundle-ID identity with a last-known-URL fast path and a Trash filter; `NSStatusItem` + non-activating `NSPanel` on `NSGlassEffectView`; a SwiftPM core with `swift test` plus an xcodegen app target; and a source-scan test as the no-logging/no-timer mechanism. That convergence is the signal; the differences were point decisions.

**Base: candidate-1.** The cross-judge scored it 18/18 against 11/18 and recommended it; my own scoring was 17 (3, 3, 3, 2, 3, 3) against 11 (2, 2, 2, 2, 1, 2), so we agree on the base. Candidate-1 won on the smaller hub surface (5 properties, 5 intents, 3 ports against 13 members, 7 protocols and 2 closures), on deterministic tests at the high seam (its in-memory hardware delivers gestures synchronously on the main actor, where candidate-2's hub-owned `Task { @MainActor }` hop made its own negative test unable to fail), on trackpad classification (candidate-2 would count a Magic Mouse as an external trackpad), on the login-item order (register before the first save) and on voiding fingers that were already down when the thumb landed (R11's "tap that began before the thumb was anchored"), where candidate-2 would have fired the wrong finger count.

**Grafted from candidate-2:** the recognizer state as one sum type that carries the anchor (`idle | armed | tapping | spoiled`), replacing `anchor?` beside `phase`; `Touch.Phase.landing` from MT state 3 so a reused touch ID still reads as a landing; `ConflictingSetting` as an enum whose exhaustive switches are the table, wrapped in candidate-1's non-empty `ConflictingSettings`; raw preference values crossing the port so `conflicts(rawValue:)` is tested in core with the sourced integers; `activity` as a computed derivation over the two stored inputs instead of a stored value set in `reconcile`; the resign-key guard for the status-button click; the concrete package and project settings (tools 6.2, `platforms: .macOS(.v26)`, main-actor default isolation for the UI, Debug/Release xcconfigs, `test.sh`, draining IOKit's initial iterator).

**Rejected from candidate-2:** the corner-agnostic recognizer (it splits the anchor-corner rule between the recognizer and the hub; keeping hand mode as recognizer input costs one device restart per toggle and keeps R11 in one module); gating only at `fire` with devices always running (contradicts the domain model's "nothing is recognised" and spends CPU on touches that can never fire); writing the resolved URL back on fire (a second writer of settings for a millisecond); the seven-protocol split with `openURL`/`terminate` closures in the hub (shell actions carry no policy); a schema version field (unrequested). **Dropped from candidate-1:** fast-user-switching handling (no requirement asks for it; listed as an open question).

**Candidate-1 defects fixed in the re-derivation** (from the cross-judge and my own read): usage called `recognizer.run` which the sketch lacked (usage now folds over `step`); fixtures `.builtIn`/`.magicTrackpad` were passed where a `Trackpad`/`TrackpadID` was expected (named fixtures added); `run` released devices before clearing the registry (registry cleared first).

**Test-planner findings folded in (Phase C):** the recognizer could not pass its own ID-reuse script because a tracked contact reappearing with `.landing` never left `down` (lifts are now evaluated before landings, and a reused ID lifts and lands anew in one frame); `InMemoryTrackpads` could not go deaf, so the after-sleep scenario could not fail (`sleep()` added; `run` clears it); the "gesture already in flight when activity flips" guard had no driver (`inject(_:)` added); the register-before-save order was unobservable (`onRegisterLoginItem` hook added); R5 says the list refreshes "each time the picker opens" while the design refreshed it on window open (the picker now enumerates the catalog in `menuNeedsUpdate`; `openWindow()` and `start()` became synchronous, the `installedApps` property and the async enumeration were removed); R10's hint wording had no seam (`HandMode.cornerName`); a click on the landing frame was inexpressible (`TouchScript.tap(click:)`). Rejected: none.

### Tradeoffs accepted

- We accept a full device restart on every reconcile (preference change, hand-mode toggle, hot-plug, wake), dropping a tap in progress on those rare events, in exchange for one convergent operation with no stale-device detection and no special wake path.
- We accept a `Mutex` around each recognizer that is never contended, in exchange for proving single ownership to the compiler instead of `nonisolated(unsafe)`.
- We accept a large real hardware adapter checked only by hand (MultitouchSupport, IOKit, wake, actuators, classification), in exchange for one hardware port whose fake runs the real recognizer.
- We accept sampling button state on every frame while touching, in exchange for a recognizer that is a pure function of its input.
- We accept a synchronous enumeration of the three Applications folders on the main actor each time a picker's menu opens (user-initiated, tens of milliseconds), in exchange for R5's "each time the picker opens" being literally true, no cache to invalidate and no FSEvents watcher. If a cold disk makes the menu's open latency visible, make the enumeration cheaper (read only the bundle identifier and display name of each bundle) rather than cache it: any cache reintroduces the staleness R5 forbids.
- We accept that Other… closes the launcher window, runs `NSOpenPanel` with the app activated, then reopens the window, in exchange for not fighting window levels and resign-key dismissal while the chooser is up.
- We accept that resolved URLs are never written back (a moved app costs one LaunchServices lookup per fire), in exchange for settings that change only through user intent.
- We accept that first launch is derived from the absence of a settings record, so a user who deletes the app's preferences gets a first launch again, including the login item.
- We accept that rows are a disk snapshot refreshed on open and on each assignment; the fire path resolves fresh, so behaviour is never wrong.
- We accept that `openApplication`'s completion is ignored: the only reactions (a log line or a dialog) are both ruled out.

### Alternatives considered

- **Hop every frame to the main actor and recognize there.** No frame-thread `Mutex`, but it wakes the main thread ~100 times a second whenever a finger is on the trackpad, for no gain in depth; button state would still be sampled on the frame thread. Rejected on cost.
- **The adapter delivers raw frames and the core owns the recognizer map plus the hop.** The core would contain threading, and tests would wait on an async hop to observe both "nothing happened" and "something happened". Moving the hop into the adapter keeps the core synchronous and deterministic.
- **Devices always running, gated only at the fire path.** Simpler device lifecycle, but CPU is spent on frames that can never fire while *Tap to click* is on, and "nothing is recognised" would hold only in effect. Reconcile already runs on every input, so stopping the devices costs nothing extra.
- **A corner-agnostic recognizer that reports which top corner held the thumb, matched against hand mode in `fire`.** Removes the device restart on hand-mode toggle and the only cross-thread configuration, but splits R11's anchor-corner rule across two modules and adds a field to every event. Rejected for reader load.
- **One `Trackpads` port that also reports each trackpad's settings.** A slightly smaller core, but the built-in/external join (R14's subtle case) would move into an untested adapter. Keeping preferences as a separate port keyed by `TrackpadKind` keeps the join pure and table-tested.
- **`MenuBarExtra(.window)` or `NSPopover` as the shell.** The first cannot be opened or closed programmatically (R18, R3); the second adds an arrow and chrome the design does not have, with the same status-click wrinkle.
- **An injected `Clock` and a tap-timeout timer.** Conventional, but every lift is observed as a frame, so the frame timestamp is a sufficient clock, and a timer would be the app's only timer (R22).
- **Refreshing the picker's list when the window opens, enumerated off the main actor.** Keeps the view body free of disk work and the menu instant, but it contradicts R5's "each time the picker opens" for an app installed in the background while the window is open, and the first open would show an empty picker until the enumeration finished. Rejected: the requirement text wins, and `menuNeedsUpdate` is the one hook that runs exactly when a menu opens.

### Open questions and risks

- **Frame layout (Q1).** The MTTouch layout, state values, coordinate origin and callback thread are sourced, not probed. The first slice prints real frames through the adapter before anything is built on it; a correction is confined to `TouchFrame.init(parsing:)`. Is that acceptable as the slice-one gate?
  - **Status (S1): gate pending a real-touch run.** `mt-probe` is built and ready (`.build/mt-probe` at the repo root, from `swiftc -O -o .build/mt-probe plans/001-trackpad-launcher-app/.temp/architect/grounding/probes/mt-probe/main.swift` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`). It needs a person touching the trackpad: run it, touch once with one finger near the top-left corner within 25 s, lift, and record the output beside the probe as `output-touch.txt`. Check against the gate list under Verified without a test (R11 frame layout gate). No frame has been observed yet; nothing here is measured. Until then `TouchFrame.init(parsing:)` (S5) rests on the sourced layout.
- **Trackpad classification.** Does the IORegistry `Product` string reliably contain "Trackpad" for every Apple trackpad and never for a Magic Mouse or Touch Bar? Allowlist on "Trackpad" risks ignoring a future device; a denylist risks counting a mouse. Which risk do you prefer?
- **Device readiness after wake or hot-plug.** Is a device startable the moment `didWake` or IOKit first-match fires, and does `MTDeviceCreateList` already include a just-paired Magic Trackpad when first-match fires? If not, should `screensDidWake` be a second signal, or is one bounded retry (the app's only timer) acceptable?
- **Preference semantics.** `Clicking == 1` and `TrackpadThreeFingerTapGesture == 2` are sourced from community documentation; verify once by toggling System Settings in the activity slice. Does a USB-wired Magic Trackpad read the Bluetooth domain, or is Bluetooth-only acceptable for v1?
- **Feel constants.** 300 ms tap, 3 mm drag, 2 mm anchor release margin, 20% × 25% corner (25 × 19 mm on the probed MacBook, roughly 32 × 29 mm on a Magic Trackpad), actuation ID 6. Should these be tuned once on a 13" MacBook and a Magic Trackpad before they are frozen, and should the corner be fixed in millimetres instead of fractions?
- **Fast user switching.** The plan does not mention it. Should gestures stop while another user's session is on the console (so we never fire on, or pulse, their trackpad)? If yes, it is one more `.trackpadsChanged` source plus `connected() == []` while off console.
- **Window behaviour to confirm in E2E.** Is closing and reopening the window around Other… acceptable? Does the resign-key guard make an icon click while open close (not close-then-reopen)? Does the `NSPopUpButton` picker open correctly inside a non-activating panel, and is its open latency (the enumeration in `menuNeedsUpdate`) acceptable on a cold disk?
- **Signing.** No Developer ID Application certificate is installed; R23 cannot be verified until one is. Who provisions it? Is a login item registered by an Apple Development-signed debug build acceptable on the developer's machine?

### Next implementation step

Scaffold the `LauncherKit` package with `LauncherCore` (domain types, `GestureRules`, `GestureRecognizer`) and `SourcePolicyTests`, then drive the recognizer test-first through every R11 frame script; meanwhile run `mt-probe` with a real touch to confirm the frame layout the adapter will parse.

## Testing Decisions

### Strategy

Five seams, highest first. There is no existing suite (greenfield); the fixtures below are the patterns every later test copies.

1. **`Launcher` (LauncherCoreTests), the high seam.** A `World` fixture builds the real `Launcher` over `InMemoryTrackpads` (which steps the real `GestureRecognizer` synchronously on the main actor), `InMemoryTrackpadPreferences` (whose `set` invokes `onChange` synchronously), `RecordingSystemActions`, a real `AppCatalog` over a temp directory of fake `.app` bundles (a folder with `Contents/Info.plist` carrying `CFBundleIdentifier`) with an injected `registeredCopies` closure the test controls, and a real `SettingsStore` over `UserDefaults(suiteName: "tl-test-<uuid>")` removed in `deinit`. `World(apps:attached:)` takes the initial trackpad list; `world.app("Figma")` is the `AppEntry` on disk; `world.install`, `world.remove`, `world.move`, `world.trash` edit the temp tree; `world.registry[bundleID]` is what `registeredCopies` returns; `world.catalog` is the catalog the launcher was built on; `world.relaunch()` builds a second `Launcher` over the same adapters and a fresh `UserDefaults` instance on the same suite name. Every call is synchronous (`start()`, `openWindow()`, `touch`, `set`, `attach`, `detach`, `sleep`, `wake`, `inject`), so no row waits. It observes `rows`, `isWindowOpen`, `handMode`, `activity`, `system.broughtToFront`, `system.loginItemRegistrations`, `hardware.feedback`, `hardware.running` and the suite itself. It misses the AppKit shell and views (the panel, the status icon, the `NSPopUpButton` picker and its `menuNeedsUpdate`), real frames, real cfprefs, real LaunchServices, IOKit and wake. The activity table (`GestureActivity`, `ConflictingSetting`), `AppCatalog.locate` and `entry(at:)`, and `SettingsStore` are driven here through `set`, `attach`, `detach`, `setAssignment`, `openWindow()` and `relaunch()`, so they carry no tests of their own; two pure values the views quote verbatim, `ConflictingSetting.noticeName` and `HandMode.cornerName`, are asserted directly.
2. **`GestureRecognizer.step` over `TouchScript` frames.** Every R11 edge, built in S1 before the `Launcher` exists; the frame timestamp is the only clock, so a row about the tap timeout moves `TouchFrame.time` and a row that never does proves the event path alone. Observes the full list of fired gestures over every frame (`frames.compactMap { r.step($0) }`), so "exactly once" and "never" are asserted over the whole history. Misses device gating and live hand-mode switching, which seam 1 covers with a representative subset.
3. **`AppCatalog.installedApps()` over the World's temp tree.** The picker's list never passes through `Launcher`: the design has the picker call the catalog through `LauncherActions.installedApps` each time its menu opens, so R5's list rows call `world.catalog.installedApps()` directly. The first call proves the folders, subfolders, Finder entry, de-duplication and order; a second call after the tree changed, with nothing else in between, proves every call enumerates afresh: a cache at any level would turn it red, which is the guard behind the design's tradeoff that a slow enumeration is made cheaper, never cached. It misses the `menuNeedsUpdate` wiring that makes "each time the picker opens" true in the app, which is a manual check under R5.
4. **LauncherPlatformTests: real adapters that need no hardware.** `SystemTrackpadPreferences` against throwaway cfprefs domains written by `/usr/bin/defaults` from a child process (the KVO probe pattern); `TouchFrame.init(parsing:)` over hand-built `MTTouchMirror` buffers; `trackpadKind(product:isBuiltIn:)`. Misses the MultitouchSupport device lifecycle, actuators, IOKit and wake, which are manual.
5. **`SourcePolicyTests`**: the R20–R22 gate, plus a self-check that the scanner really scans.

Faked at the seam: the hardware port (in-memory adapter with the real recognizer inside), the preferences port (in-memory), the system actions (recording). Real: the filesystem (a temp directory), `UserDefaults` (a throwaway suite), and every module we own. The clock needs no fake: no clock object exists. Randomness: none in the design.

Techniques, applied: boundary rows for every number in a requirement (finger counts 1–5, 1 cm/4 cm, 20%/25% of the probed surface) and both sides of each design constant (300 ms, 3 mm, 2 mm) with a margin, because script timestamps are 10 ms multiples and the exact edge is float-sensitive; withhold and inject through the design's two handles on the in-memory adapter, `sleep()` (running devices drop frames until the next `run`, as real devices do after sleep; `run` clears `deaf`) and `inject(_:)` (deliver a `GestureEvent` the frame thread would have hopped over after activity flipped, regardless of `running`); force the interleaving for the two writes of first launch with the design's `RecordingSystemActions.onRegisterLoginItem` hook, which the World wires to snapshot `store.load()`; kill-at-random replaced by rows at both post-crash states of the only two-step write (nothing stored → registers again; stored → never again), since the sequence has exactly one gap; hold-the-blocking-call: not applicable, the design bounds no call with a deadline or cancel and awaits nothing (`start()` and `openWindow()` are synchronous; the one blocking call, `NSOpenPanel` behind Other…, lives in the shell and is manual). The "within 5 seconds" bounds of R2, R14 and R16 are push paths with no timer; seam 1 proves the reaction, T56 proves the real KVO push arrives inside the bound, and hot-plug is manual.

Risk noted, not a defect: the KVO probe watched a domain that already existed; T56 watches a throwaway domain the test creates. If KVO does not fire for a brand-new domain, the test writes a non-table key first to create it, then observes.

### Test scenarios

Conventions: right hand and `SurfaceSize.macBook14` (124.8 × 76.8 mm) unless stated; thumb at (10, 10) mm from the top-left; fingers at (62, 45) mm; a tap holds 120 ms; frames 10 ms apart; "fired" is the list of gestures over every frame; "tap N on T" at seam 1 is `hardware.touch(TouchScript(T.surface).thumb(atMM: (10, 10)).tap(fingers: N).frames, on: T.id)`; "nothing" means `broughtToFront` and `feedback` gained no entry. Rows whose thumb and finger events interleave in a way `TouchScript`'s builder cannot compose (fingers down before the thumb lands, thumb and finger in one frame, thumb lifting under held fingers, a touch ID reappearing with `.landing`: T4, T5, T13, T20) build their `TouchFrame`s by hand through the public memberwise initialisers.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R11 | recognizer | Parametrised N in 1…4. Thumb lands, N fingers tap, lift. → fired == [Gesture(fingerCount: N)] | R11 "fire the N-finger gesture exactly once, when the fingers lift"; scenario "Thumb first, then tap" |
| T2 | R11 | recognizer | Thumb anchored; five fingers tap. → fired == [] | R11 scenario "Five fingers"; `Gesture.init?(fingerCount:)` nil outside 1…4 |
| T3 | R11 | recognizer | Thumb anchored; tap 1 finger; without lifting the thumb tap 2 fingers. → fired == [.one, .two] | R11 scenario "Repeated taps while anchored" |
| T4 | R11 | recognizer | Two fingers land at (62, 45); then the thumb lands in the corner; the two fingers lift; then a clean 1-finger tap. → fired == [.one] (nothing from the first lift) | R11 "a tap that began before the thumb was anchored" MUST NOT fire; the trailing tap proves recovery |
| T5 | R11 | recognizer | Thumb and one finger land in the same frame; the finger lifts; then a clean 1-finger tap. → fired == [.one] | R11 "The thumb MUST be anchored from before the first finger lands" |
| T6 | R11 | recognizer | Thumb at (10, 66) (bottom-left); 1-finger tap. → fired == [] | R11 scenario "Thumb outside the corner" |
| T7 | R11 | recognizer | Thumb lands; frames continue for 5 s with only the thumb down; thumb lifts. → fired == [] | R11 scenario "Thumb alone" (five seconds) |
| T8 | R11 | recognizer | Thumb anchored; two fingers land and move 20 mm over 100 ms, then lift; then a clean 2-finger tap. → fired == [.two] | R11 scenario "Drag is not a tap"; trailing tap proves recovery |
| T9 | R11 | recognizer | One finger moves 2.5 mm before lifting → fired == [.one]; moves 3.5 mm → fired == [] | R11 "fingers that drag" MUST NOT fire; 3 mm is `GestureRules.dragThresholdMM` (design, strictly greater), rows sit 0.5 mm either side |
| T10 | R11 | recognizer | Parametrised over fingers {1, 3} × `TouchScript.ClickTiming` {`.onLanding`, `.midway`}: `tap(fingers: N, click: timing)` sets `buttonDown` on the landing frame, or from a mid-tap frame through the lift; fingers lift, button releases; then a clean N-finger tap. → fired == [Gesture(N)] (only the trailing tap) | R11 scenario "Click is not a tap", "with any number of fingers"; two recognizer transitions (`armed` → `spoiled` on the landing frame, `tapping` → `spoiled` mid-tap) |
| T11 | R11 | recognizer | Three fingers land 10 ms apart and lift 10 ms apart. → fired == [.three] | R11 scenario "Fingers land and lift one at a time" (exactly once) |
| T12 | R11 | recognizer | Three fingers with `stagger: 50 ms` (land at 0, 50, 100 ms; lift at 120, 170, 220 ms), so all three are down together only between 100 and 120 ms and one finger is down at the last lift. → fired == [.three] | R11 "N is the largest number of non-thumb fingers simultaneously down during the tap" (not the number down when the last lifts) |
| T13 | R11 | recognizer | Thumb anchored; two fingers down; thumb lifts; fingers lift → fired == []. Variant: thumb and last finger lift in the same frame → fired == [] | R11 scenario "Thumb lifts before the fingers"; "until the last finger lifts" |
| T14 | R11 | recognizer | Tap 1 finger; thumb lifts; tap 1 finger again with the thumb up. → fired == [.one] | R11 "a tap that ends after the thumb has lifted" / thumb not anchored MUST NOT fire |
| T15 | R11 | recognizer | One finger held 290 ms → fired == [.one]; held 310 ms → fired == [] | `GestureRules.maxTapDuration` = 300 ms (design); domain model "Tap: … within a short window"; rows 10 ms either side |
| T16 | R11 | recognizer | Parametrised: thumb at (10, 10) → fired == [.one]; thumb at (40, 10) → fired == [] | R11 scenario "Just inside and just outside the corner" (1 cm in, 4 cm from the left edge) on the probed 124.8 mm surface |
| T17 | R11 | recognizer | Thumb at (24, 10) → fires; (26, 10) → []; (10, 18) → fires; (10, 20) → [] | R11 "leftmost 20% and topmost 25%": 0.20 × 124.8 = 24.96 mm, 0.25 × 76.8 = 19.2 mm |
| T18 | R9, R11 | recognizer | `handMode: .left`: thumb at (114.8, 10) + 1-finger tap → fired == [.one]; thumb at (10, 10) → fired == [] | R9 "In Left hand mode the anchor corner is top-right"; R11 "rightmost 20% in Left hand mode" |
| T19 | R11 | recognizer | `TouchScript(.macBook14).thumb(atMM: (24, 10)).rollThumb(toMM: (26.5, 10)).tap(fingers: 1).frames` (the anchored thumb moves over the tap's frames) → fired == [.one]; the same script with `rollThumb(toMM: (28, 10))` → fired == [] | R11 "anchored from before the first finger lands until the last finger lifts"; `GestureRules.anchorReleaseMarginMM` = 2 (design): 24.96 + 2 = 26.96 mm, rows sit either side; design "a thumb that slides out is from then on just a finger; it is not re-adopted" |
| T20 | R11 | recognizer | Thumb anchored; finger id 7 is down for three frames; the next frame carries id 7 with `.landing` again at the same spot; three more frames; then absent. → fired == [.one, .one], the first on the frame id 7 reappears | R11 "exactly once, when the fingers lift" for each of two taps; `Touch` contract "a tracked ID that reappears with `.landing` was lifted and has landed anew"; design decision 1 "lifts are evaluated before landings … so a reused touch ID cannot fuse two taps" |
| T21 | R11 | recognizer | Surface 160 × 115 mm (Magic Trackpad): thumb at (10, 10) → fired == [.one]; thumb at (40, 10) → fired == [] | R11 "a naturally placed thumb lands inside on both a 13-inch MacBook and a Magic Trackpad"; 0.20 × 160 = 32 mm |
| T22 | R20, R21, R22 | SourcePolicyTests | Parametrised over the banned-token list (the design's list plus `nonisolated(unsafe)` for the one-writer rule): zero hits across every `.swift` under the package's Sources and the app target. Self-check: scanning a temp directory holding a file containing `print("x")` returns exactly that one hit; the real scan visits at least one file per library target | `docs/architecture.md` "Privacy and permissions", "Concurrency"; R20–R22 |
| T23 | R3, R11, R12, R13 | Launcher | World(apps: [Figma]); `start()`; Figma assigned to `.two`; `openWindow()`; tap 2 on macBook14. → `broughtToFront == [Figma entry with its on-disk URL]`, `feedback == [macBook14.id]`, `isWindowOpen == false` | R11 "Thumb first, then tap"; R13 "Pulse on fire"; R3 "Gesture closes the window"; R12 "Launches a closed app" (the call the probe showed does it) |
| T24 | R11, R12 | Launcher | Arc on `.one`, Figma on `.two`; one script: thumb, tap 1, tap 2. → `broughtToFront == [Arc, Figma]`, `feedback.count == 2` | R11 "Repeated taps while anchored" |
| T25 | R3, R13 | Launcher | `.three` unassigned; `openWindow()`; tap 3. → `feedback == []`, `broughtToFront == []`, `isWindowOpen == true` | R13 "Silent when unassigned"; R3 "closes the window as the target app comes to the front" (no target, no close) |
| T26 | R7, R13 | Launcher | Figma on `.two`; `world.remove("Figma")`, registry returns []; tap 2. → nothing | R13 "Silent when missing" |
| T27 | R2, R14 | Launcher | Arc on `.one`; `preferences.set(.tapToClick, 1, for: .builtIn)`. → `activity == .inactive(.settings(ConflictingSettings([.tapToClick])!))`, `running.isEmpty`; tap 1 → nothing | R14 "Tap to click on"; R2 "Icon flips to inactive"; domain model "nothing is recognised" |
| T28 | R2, R14, R15 | Launcher | `attach(.magicTrackpad)`; `set(.tapToClick, 1, for: .external)`; tap 1 on macBook14. → `activity == .inactive(.settings([.tapToClick]))`, nothing | R14 "Only the external trackpad has it on" |
| T29 | R14 | Launcher | No external trackpad attached; `set(.tapToClick, 1, for: .external)`; tap 1. → `activity == .active`, `broughtToFront == [Arc]` | R14 "while any *connected* trackpad has …" |
| T30 | R2, R14 | Launcher | From T27's state, `set(.tapToClick, 0, for: .builtIn)`. → `activity == .active`, `running.keys == [macBook14.id]`; tap 1 → `broughtToFront == [Arc]` | R14 "Turning it off activates gestures live"; R2 "Icon flips back to active" |
| T31 | R14, R15 | Launcher | Parametrised over built-in values → expected: {ThreeFingerTap: 2} → `.inactive(.settings([.lookUpTapWithThreeFingers]))`; {Clicking: 1, ThreeFingerTap: 2} → settings == [.tapToClick, .lookUpTapWithThreeFingers] in that order; {Clicking: 1, ThreeFingerTap: 0} → [.tapToClick]; {Clicking: 0, ThreeFingerTap: 0} and {} → `.active` | R14 "Three-finger Look up"; R15 "names only the offending setting", "names both", "names only Look up"; raw values 1 and 2 from grounding Q4; key-absent-is-off from the design |
| T32 | R15 | pure value | `ConflictingSetting.tapToClick.noticeName == "Tap to click"`; `.lookUpTapWithThreeFingers.noticeName == "Look up: Tap with three fingers"`; `ConflictingSettings([]) == nil` | R15's literal setting names; design "non-empty by construction" |
| T33 | R2, R14, R15 | Launcher | World(attached: []) with Clicking = 1 for `.builtIn`; `start()`. → `activity == .inactive(.noTrackpad)`; `attach(.macBook14)` with Clicking back to 0 → `.active`; `detach(macBook14.id)` → `.inactive(.noTrackpad)` | R2 "No trackpad connected"; R15 "No trackpad"; design "No trackpad wins over settings" |
| T34 | R8, R15 | Launcher | Clicking = 1 (inactive); `setAssignment(.app(Arc), for: .one)`. → `rows[.one].app == .present(Arc)`; `relaunch()` → same | R15 "Rows still editable: the assignment is saved and shown" |
| T35 | R13, R16 | Launcher | `attach(.magicTrackpad)` → `running.keys == {macBook14.id, magicTrackpad.id}`; tap 1 on magicTrackpad → `broughtToFront == [Arc]`, `feedback == [magicTrackpad.id]`; `detach(magicTrackpad.id)` → `running.keys == {macBook14.id}`; frames on magicTrackpad → nothing more | R16 "Hot-plugged Magic Trackpad"; R13 "Pulse on the external trackpad" (not the built-in one) |
| T36 | R16 | Launcher | `hardware.sleep()` (every running device drops frames until the next `run`); tap 1 → nothing; `hardware.wake()`; tap 1 → `broughtToFront == [Arc]` | R16 "After sleep"; grounding Q5 (devices go deaf after sleep and must be restarted) |
| T37 | R13, R14 | Launcher | Arc on `.one`; Clicking = 1 (inactive, `running.isEmpty`); `openWindow()`; `hardware.inject(GestureEvent(gesture: .one, trackpad: macBook14.id))`, which delivers regardless of `running`. → `feedback == []`, `broughtToFront == []`, `isWindowOpen == true` | R14 "nothing happens: no app change, no haptic"; design decision 5 "the guard catches a gesture already in flight when activity flips" |
| T38 | R9 | Launcher | Fresh World: `handMode == .right`; Arc on `.one`; `setHandMode(.left)`; thumb at (114.8, 10) + tap 1 → `broughtToFront == [Arc]`; thumb at (10, 10) + tap 1 → no further entry | R9 "Default is right hand"; "Switching hands moves the corner" |
| T39 | R8 | Launcher | Arc, Figma, Notion, Spotify on `.one`…`.four`; `setHandMode(.left)`; `relaunch()`. → `rows` show the four as `.present`, `handMode == .left` | R8 "Survives reboot" (the suite is what survives) |
| T40 | R3, R6, R9, R17, R18 | Launcher | Fresh suite; `start()`. → `rows.map(\.app) == [.unassigned × 4]`, `handMode == .right`, `isWindowOpen == true`, `loginItemRegistrations == 1` | R6 "Fresh install"; R9 default; R18 "First launch"; R17 "Added to login items" |
| T41 | R17, R18 | Launcher | `relaunch()` after T40; `start()`. → `isWindowOpen == false`, `loginItemRegistrations == 0` | R18 "Second launch"; R17 "does not re-enable itself" |
| T42 | R17 | Launcher | Suite holds `Data("garbage")` under the settings key; `start()`. → `loginItemRegistrations == 0`, `isWindowOpen == false`, rows all `.unassigned`, `handMode == .right` | R17 "does not re-enable itself on its next manual launch"; design decision 7 (undecodable ⇒ defaults, not first launch) |
| T43 | R17 | Launcher | Fresh suite; `RecordingSystemActions.onRegisterLoginItem` snapshots `store.load()`; `start()`. → snapshots == [nil]; afterwards `store.load() != nil` | Design decision 7 "registers the login item before its first save" |
| T44 | R8 | Launcher | `setAssignment(.app(Arc), for: .one)`; a new `SettingsStore` over a new `UserDefaults(suiteName:)` instance of the same name. → `load()?.assignments[.one]?.bundleID == Arc's` | R8 persist (reaches cfprefsd, not an instance cache) |
| T45 | R5 | AppCatalog | Roots: Applications{Zed.app, arc.app, Figma.app (which contains Contents/Helpers/Helper.app), Utilities/Terminal.app, Notes.txt, NoID.app (no CFBundleIdentifier), .Hidden.app}; SystemApplications{arc.app with the same bundle ID}; UserApplications{App 10.app, App 2.app}; extras [Finder fixture]. `world.catalog.installedApps()`. → `.map(\.name) == ["App 2", "App 10", "arc", "Figma", "Finder", "Terminal", "Zed"]`; the arc entry's URL is under Applications | R5 folders, subfolders, Finder, alphabetical; the order is Finder's list-view order of those names (Finder sorts with `localizedStandardCompare`), checked once by hand |
| T46 | R5 | AppCatalog | `world.catalog.installedApps()` (Slack absent); `world.install("Slack")`; `installedApps()` again, with no other call in between → contains Slack; `world.remove("Zed")`; `installedApps()` again → Zed absent | R5 "Newly installed app appears" / "installed or removed since the app launched, each time the picker opens"; design `installedApps` "Enumerates on every call" |
| T47 | R5 | Launcher | `setAssignment(.app(Figma), for: .two)`. → `rows[.two].app == .present(Figma)` | R5 "Pick an installed app" |
| T48 | R5 | Launcher | `setAssignment(.appBundle(at: Downloads/Sketch.app), for: .one)` → `.present(Sketch)`; `setAssignment(.appBundle(at: Downloads/Notes.txt), for: .one)` → row unchanged; tap 1 → `broughtToFront == [Sketch]` | R5 "Pick an app from elsewhere"; "only accepts applications" |
| T49 | R5, R6 | Launcher | Notion on `.three`; `setAssignment(.unassigned, for: .three)`. → `.unassigned`; `relaunch()` → still `.unassigned`; tap 3 → nothing | R5 "Unassign"; R6 placeholder state |
| T50 | R5 | Launcher | Arc on `.one`; `setAssignment(.app(Arc), for: .four)`. → `rows[.one].app == rows[.four].app == .present(Arc)` | R5 "Same app on two gestures" |
| T51 | R7, R13 | Launcher | Figma on `.two`; `world.trash("Figma")` (moves it under `<tmp>/.Trash/`); registry returns [that URL]; `openWindow()` → `rows[.two].app == .missing(name: "Figma")`; tap 2 → nothing; `setAssignment(.app(Arc), for: .two)` → `.present(Arc)` | R7 "Assigned app deleted"; "The picker MUST still work on a not-found row" |
| T52 | R7, R12 | Launcher | Figma on `.two` (lastKnownURL under Applications); `world.move("Figma", to: UserApplications)`; registry returns [new URL]; tap 2 → `broughtToFront == [entry at the new URL]`; `openWindow()` → `.present(that entry)` | R7 "Moved app keeps working" |
| T53 | R7 | Launcher | From T51's missing state; `world.install("Figma")` again under Applications; registry returns [it]; `openWindow()` → `.present(Figma)`; tap 2 → `broughtToFront == [Figma]` | R7 "Reinstalled app recovers" without re-picking |
| T54 | R7 | Launcher | Replace Figma.app at the lastKnownURL with a bundle whose CFBundleIdentifier differs; registry returns []; `openWindow()`. → `.missing(name: "Figma")` | R7 "An assignment refers to the app's identity, not its location" |
| T55 | R7 | Launcher | lastKnownURL gone; registry returns [`<tmp>/.Trash/Figma.app`, `UserApplications/Figma.app`]; tap 2. → `broughtToFront == [the UserApplications copy]` | R7 "no copy of the app exists outside the Trash" (trashed copies never count) |
| T56 | R2, R14 | SystemTrackpadPreferences | Parametrised over `TrackpadKind`: adapter over throwaway domains `tl.test.<uuid>.<kind>`; a child process runs `/usr/bin/defaults write <domain> Clicking -int 1`. → `onChange` runs on the main actor within 5 s of the write; `current()[kind]?[.tapToClick] == 1`, `[.lookUpTapWithThreeFingers] == nil`; `defaults delete <domain>` → `onChange` again and `.tapToClick` absent. Domains deleted in teardown | R2/R14 "within 5 seconds, without relaunch"; grounding Q4 (key `Clicking`; KVO push on cross-process writes) |
| T57 | R14 | SystemTrackpadPreferences | `defaults write <domain> TrackpadThreeFingerTapGesture -int 2` → `current()[kind]?[.lookUpTapWithThreeFingers] == 2` | Grounding Q4 (key name and the value for "Tap with three fingers") |
| T58 | R11, R16 | TouchFrame(parsing:) | `MemoryLayout<MTTouchMirror>.stride == 96`. A buffer of four `MTTouchMirror`: id 7 state 3 at normalized (0.1, 0.9); id 8 state 4 at (0.5, 0.5); id 9 state 2; id 10 state 5; timestamp 12.5, `buttonDown: false`. → `time.seconds == 12.5`, `touches == [(7, .landing, SurfacePoint(0.1, 0.1)), (8, .down, (0.5, 0.5))]`; count 0 → `touches == []` | Grounding Q1: 96-byte layout, states 3/4 are down, bottom-left origin (y flipped to top-left); updated from the S1 real-touch check if it disagrees |
| T59 | R14, R16 | trackpadKind(product:isBuiltIn:) | (the built-in's `Product` string as printed by `ioreg -c AppleMultitouchDevice -r`, true) → `.builtIn`; (a Magic Trackpad's `Product` string, false) → `.external`; ("Magic Mouse", false) → nil | `ioreg` on the development Mac (built-in) and on a Mac with the Magic Trackpad (recorded during S5); domain model "A Magic Mouse is not a trackpad" |
| T60 | R10 | pure value | `HandMode.right.cornerName == "top-left"`; `HandMode.left.cornerName == "top-right"` | R10 "the hint MUST read 'top-right corner'" in Left hand mode and "(thumb top-left)" in Right hand mode; R9 "In Left hand mode the anchor corner is top-right; in Right hand mode it is top-left" |

### Verified without a test

Build and tool checks run from the worktree with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Manual sequences run against a Debug build signed with Apple Development unless the check says otherwise.

- **R1.** `plutil -p TrackpadLauncher.app/Contents/Info.plist` prints `LSUIElement => 1`. Manual: launch; the Dock shows no Trackpad Launcher tile; ⌘-Tab does not list it; its icon is in the menu bar.
- **R2 (look and timing).** Manual: with gestures active, switch System Settings > Appearance between Light and Dark: the symbol is legible on both menu bars. Turn *Tap to click* on: within 5 s the icon shows the slashed symbol. Turn it off with Look up not on three fingers: within 5 s the plain symbol returns. On a Mac with no trackpad (a desktop with only a mouse), the icon shows the slashed symbol at launch.
- **R3 (shell).** Manual: click the icon → the window opens directly below it with rows 1 to 4 top to bottom; click the desktop → it closes; reopen, press Escape → it closes; reopen, click the icon → it closes and does not reopen.
- **R4.** Manual: open the window in Light, then Dark, beside `docs/menubar-window.png`: four rows with the `assets/` illustrations, the Left hand | Right hand toggle between the rows and the divider, the hint, a bottom bar with Quit only, a glass background; text and icons readable in both.
- **R5 (Other…).** Manual: choose *Other…*, browse to a folder holding a `.txt`, a `.pdf` and an `.app`: only the `.app` is selectable; choosing it fills the row with its icon and name, and the launcher window is back.
- **R5 (the picker refreshes each time it opens).** Manual, with the launcher window left open throughout: copy a spare `.app` into /Applications, click a picker: the app is listed with its icon; close the menu, move that app to the Trash, click the picker again: it is gone. Because the window never closed, the list can only have come from `AppPicker`'s `menuNeedsUpdate` calling `installedApps` (T46 proves the catalog enumerates afresh; this step proves the menu asks it).
- **R7 (real LaunchServices).** Manual: assign Figma; move it to ~/Applications; gesture → Figma fronts and the row shows it normally; move it to the Trash, reopen → "Figma" greyed with "not found"; put it back, reopen → normal and the gesture works.
- **R8.** Manual: assign four apps and Left hand; reboot; open the window: the same four and Left hand.
- **R9, R10.** Manual: fresh install → Right hand selected, thumb marks top-left, hint says "Hold thumb on top-left corner"; select Left hand → all four illustrations mirrored with the thumb mark top-right and the hint says "Hold thumb on top-right corner"; back to Right hand → matches the design image. The corner words themselves are T60; this step proves `HintText` interpolates `handMode.cornerName` and the illustrations flip.
- **R11 (frame layout gate, S1).** Run the grounding's `mt-probe`, touch once with one finger near the top-left corner, lift: the callback fires on a thread that is not the main thread; `count == 1`; `state` reads 3 then 4; `normalized.x < 0.2` and `normalized.y > 0.75`; a final frame with `count == 0` arrives; the device reports 12480 × 7680. Record the output beside the probe. A deviation changes `TouchFrame.init(parsing:)` and T58's fixture, nothing else.
- **R11 (on hardware).** Manual, on a 13" MacBook and a Magic Trackpad, with an app assigned to each gesture: every R11 scenario as written, including thumb 1 cm from the corner (fires) and 4 cm from the left edge (nothing); during a two-finger drag with the thumb anchored the page scrolls as normal; a physical click with the thumb anchored clicks the button under the cursor and fronts nothing; three fingers landing a few milliseconds apart fire once. If the corner or the timing feels wrong, `GestureRules` changes and the affected T-rows' constants move with it.
- **R12.** (a) The grounding transcript `probes/activate-probe/output.txt` shows the six states (not running, hidden, minimised, no windows, already active, double open 50 ms apart → one pid). (b) Manual: Safari full screen and active → Arc's gesture → Arc is active; Arc's only window on Desktop 2 while on Desktop 1 → gesture → macOS switches to Desktop 2; Figma active with a half-screen window → gesture → size and position unchanged; Spotify not running → two gestures within 2 s → `pgrep -x Spotify | wc -l` prints 1.
- **R13.** Manual: gesture on the built-in trackpad → one pulse under the hand; with a Magic Trackpad paired, gesture on it → it pulses and the built-in does not. The actuation strength (3, 4 or 6) is chosen by feel and recorded in `MultitouchTrackpads.feedbackActuation`.
- **R14 (preference semantics and the Smart zoom rule).** Manual: toggle *Tap to click* on then off in System Settings and run `defaults read com.apple.AppleMultitouchTrackpad Clicking` after each: 1 then 0. Set *Look up & data detectors* to *Tap with three fingers*, *Force Click with one finger*, *Off* and read `TrackpadThreeFingerTapGesture` after each: 2, then 0, then 0 (record the real values; a difference is a one-line change in `ConflictingSetting` and T31/T57). With Smart zoom on and the thumb anchored, double-tap two fingers: if the view zooms, add `.smartZoom` (key `TrackpadTwoFingerDoubleTapGesture`, conflicting value 1, notice name "Smart zoom") and extend T31 and T32. With a Magic Trackpad connected, toggle Tap to click for it: the icon flips and the notice appears while the built-in's setting is off. A USB-wired Magic Trackpad is checked only if one is available.
- **R15 (rendering and the button).** Manual: Tap to click on → open the window: the hint is replaced by a notice naming "Tap to click" only, the four rows are present, and the button opens System Settings on the Trackpad pane; with Look up on three fingers too → both named; Tap to click off and Look up on three fingers → only Look up named; with the notice showing, assign Arc → saved and shown; turn every setting off and click the icon → the hint is back, no relaunch.
- **R16 (hardware).** Manual: pair a Magic Trackpad while the app runs; within 5 s a gesture on it fronts the target. Put the Mac to sleep (`pmset sleepnow`), wake it, gesture on the built-in → fronts the target.
- **R17.** Manual: first launch → System Settings > General > Login Items lists Trackpad Launcher under "Open at Login" and macOS shows its "login item added" notification; log out and in → the icon is present without launching. Turn it off there, log out and in → not started; launch it by hand → Login Items still shows it off.
- **R18.** Manual: first launch shows the window with four "Choose app…" rows; quit, launch again → only the icon.
- **R19.** Manual: click Quit → the icon leaves the menu bar, `pgrep -x TrackpadLauncher` prints nothing, a gesture does nothing; Login Items still lists it as "Open at Login".
- **R20.** T22's permission tokens, plus manual: from install through assigning an app and the first gesture no prompt appears, and `log show --last 15m --predicate 'subsystem == "com.apple.TCC"'` contains no line mentioning the app's bundle ID (the grounding probe's technique).
- **R21.** T22's logging, network and file tokens, plus one manual session: `nettop -p $(pgrep -x TrackpadLauncher)` (or Little Snitch) over launch, configuration, ten gestures and quit shows zero connections and attempts; Console filtered on the process shows no message of the app's own; `lsof -p <pid>` during the session lists no file open for writing except through cfprefsd.
- **R22.** T22's timer tokens, plus manual: after ten minutes with no touch, Activity Monitor for one minute reads 0.0% CPU for the app with at most one momentary blip.
- **R23.** `xcodebuild -showBuildSettings` prints `MACOSX_DEPLOYMENT_TARGET = 26.0` and `ARCHS = arm64 x86_64`; `lipo -archs` on the built executable prints both; `plutil -p Info.plist` prints `LSMinimumSystemVersion => 26.0`; `codesign -dv --verbose=2` prints `flags=0x10000(runtime)` and, for a release build, `Authority=Developer ID Application`; `spctl --assess --type execute` accepts the stapled app with `source=Notarized Developer ID`; a fresh Mac on macOS 26 opens it without a Gatekeeper warning; a macOS 15 VM shows the "needs a newer version of macOS" alert and nothing else. The Developer ID steps wait for the certificate.
- **Design mechanisms with no row.** `run` clears the callback registry before stopping devices: manual, toggle Tap to click several times while fingers rest on the trackpad: no crash, and no gesture fires after the toggle. The resign-key guard for the status button: covered by the R3 "click the icon → closes and does not reopen" step. `AppPicker` enumerating in `menuNeedsUpdate` and the shell wiring `LauncherActions.installedApps` to the one `AppCatalog.system` the composition root shares with `Launcher`: the R5 picker-refresh step above. "Every stored field has one writer": the package builds in Swift 6 language mode with strict concurrency and T22 bans `nonisolated(unsafe)`.

## Slices

S1 keeps the design's named first step. It is the one slice that is not a vertical path through the app: the recognizer is the deepest pure module, every later slice feeds it, and the real adapter's parse depends on the frame-layout check that S1 runs by hand; proving both before anything is built on them is the point of the order.

### S1: Recognizer, package scaffold and the frame-layout gate

**What to build:** The `LauncherKit` package as the design's build layout names it (library targets `LauncherCore`, `LauncherPlatform`, `LauncherUI`, test targets `LauncherCoreTests`, `LauncherPlatformTests`, the test script that selects the Xcode 26 toolchain), with `LauncherCore` holding the gesture domain (`HandMode`, `GestureRules`, `SurfacePoint`, `SurfaceSize`, `AnchorCorner`, `TouchID`, `Touch`, `FrameTime`, `TouchFrame`, `Gesture`, `GestureEvent`, `TrackpadID`, `TrackpadKind`, `Trackpad`) and `GestureRecognizer` driven test-first through `TouchScript` frames, one R11 row at a time; the `Trackpad` and `SurfaceSize` fixtures; `SourcePolicyTests` with its self-check. In parallel, the real-touch run of `mt-probe` that confirms the frame layout the S5 adapter will parse.

**Blocked by:** None (can start immediately).

**Requirements:** R11 (recognition, every scenario at the recognizer seam), R9 (the anchor corner follows hand mode), R10 (the hint's corner words, `HandMode.cornerName`), R20–R22 (the source gate).

**Test scenarios:** T1–T22, T60.

- [x] `Scripts/test.sh` runs `swift test` on the Xcode 26 toolchain and every row above is green; the package builds in Swift 6 language mode with strict concurrency.
- [x] `GestureRecognizer.step` is the only public entry besides `init`; every fixed number lives in `GestureRules`.
- [ ] The frame-layout gate (Verified without a test, "R11 (frame layout gate)") has been run with a real touch and its output recorded; any deviation from grounding Q1 is written into the plan's open questions before S5 starts.
- [x] T22's scanner finds the planted hit in a temp file and visits the real source tree.

### S2: The launcher on in-memory adapters

**What to build:** The whole decision core at the `Launcher` seam: the activity table (`ConflictingSetting`, `ConflictingSettings`, `InactiveCause`, `GestureActivity`, `TrackpadPreferenceValues`), the three ports and `TrackpadEvent`, the assignment and persistence types (`BundleID`, `AppEntry`, `AssignedApp`, `AppChoice`, `RowApp`, `GestureRow`, `Settings`, `SettingsStore`), `AppCatalog` with `entry(at:)` and `locate` (last-known URL, registered copies, the Trash predicate; `installedApps()` arrives in S3), and `Launcher` itself: `start` with first-launch policy and login-item order, `reconcile` across attach, detach, sleep/wake and preference change, `fire` with its three silent cases, `setAssignment`, `setHandMode`, `openWindow`, `closeWindow`. The test doubles `InMemoryTrackpads` (with `attach`, `detach`, `sleep`, `wake`, `touch`, `inject`), `InMemoryTrackpadPreferences`, `RecordingSystemActions` (with the register hook) and the `World` fixture over fake bundles and a throwaway suite.

**Blocked by:** S1.

**Requirements:** R2 (activity derivation), R3 (gesture closes, first launch opens), R6, R8, R9, R11 (through the app), R12 (the core's part), R13, R14, R15 (notice data), R16 (in-memory hot-plug and wake), R17, R18.

**Test scenarios:** T23–T44.

- [ ] Every row is synchronous: no `Task.sleep`, no polling, no `confirmation` with a timeout anywhere in LauncherCoreTests.
- [ ] `activity` is a computed derivation; `fire` is the only path that pulses, fronts or closes the window from a gesture; the `World` tears down its suite and temp directory.
- [ ] `LauncherCore` imports Foundation and Observation only (build fails otherwise).

### S3: App catalog, picker list and resolution on disk

**What to build:** `AppCatalog.installedApps()` (recursion into folders but never into bundles, hidden files skipped, bundles without an identifier skipped, one entry per bundle ID with the first root winning, Finder as an extra, Finder's ordering), synchronous and enumerating afresh on every call, proven at the catalog seam; rows refreshed on `openWindow()` and on every assignment; *Other…* through `AppChoice.appBundle(at:)`; the missing, moved, reinstalled, replaced and trashed-copy behaviours of `locate` proven at the `Launcher` seam.

**Blocked by:** S2.

**Requirements:** R5, R6 (unassign), R7, R12 (moved target), R13 (silent when missing).

**Test scenarios:** T45–T55.

- [ ] `world.catalog.installedApps()` matches Finder's order for the fixture names (T45 checked once by hand against a Finder list view of those names), and `Launcher` holds no list of installed apps (its public surface stays 4 properties and 5 intents, per the design's Depth table).
- [ ] The stored record's `lastKnownURL` is never rewritten by a fire or an open (inspect the suite after T52).

### S4: Menu bar app and launcher window on the real Mac

**What to build:** The xcodegen app target (composition root, `LSUIElement`, `LSMinimumSystemVersion`, Debug signing with Apple Development, the `assets/` SVGs), the real adapters that need no frames (`SystemTrackpadPreferences` over the two cfprefs domains with KVO, `WorkspaceActions` over `openApplication` and `SMAppService`, `AppCatalog.system` created once by the composition root and handed to both `Launcher` and `MenuBarShell(launcher:catalog:)`, and the inventory half of `MultitouchTrackpads`: `dlopen`/`dlsym`, `MTDeviceCreateList`, trackpad classification, IOKit first-match and terminated notifications → `.trackpadsChanged`, `connected()`; `run` and `playFeedback` keep their session bookkeeping but start no device until S5), and `LauncherUI`: `MenuBarShell` (building `LauncherActions` whose `installedApps` supplier calls `catalog.installedApps()`), `LauncherPanel` on `NSGlassEffectView`, `StatusIcon` (symbol and slashed template images), `LauncherView`, `GestureRowView`, `AppPicker` (`NSViewRepresentable` over `NSPopUpButton`, rebuilding its items from the supplier in `menuNeedsUpdate`), `HandModeToggle`, `HintText` (interpolating `handMode.cornerName`), `TrackpadSettingsNotice`. From the user's side: install, see the icon, open the window from the icon, assign apps including *Other…* and see a just-installed app in the picker without reopening the window, toggle hands, see the notice when a setting conflicts, relaunch with everything kept, the login item, Quit.

**Blocked by:** S3.

**Requirements:** R1, R2 (icon look and live flip), R3 (shell dismissals), R4, R5 (*Other…* chooser; the picker enumerating on every menu open with real folders), R8 (reboot), R9 (toggle), R10 (rendering: mirrored illustrations, the hint), R14 (real preference push), R15 (notice rendering, button), R16 (classification), R17 (real login item), R18 (first launch for real), R19, R20 (no prompt through configuration), R23 (deployment target and `LSUIElement` in the built bundle).

**Test scenarios:** T56, T57, T59.

- [ ] The manual sequences under Verified without a test for R1, R2, R3, R4, R5 (*Other…* and the picker refresh), R8, R9/R10, R15, R17, R18 and R19 pass on this Mac and are ticked in the plan.
- [ ] `plutil -p` on the built Info.plist shows `LSUIElement => 1` and `LSMinimumSystemVersion => 26.0`; `xcodebuild -showBuildSettings` shows the macOS 26 deployment target.
- [ ] T22 still passes with `LauncherPlatform`, `LauncherUI` and the app target included in the scan.
- [ ] The built-in's `Product` string from `ioreg` is recorded in T59.

### S5: Gestures for real

**What to build:** The streaming half of `MultitouchTrackpads`: `run` (registry cleared first, then unregister/stop/close/release, re-list, a `DeviceSession` with a fresh `GestureRecognizer` per trackpad, callback registration and `MTDeviceStart`), the context-free contact-frame callback, `MTTouchMirror` and `TouchFrame.init(parsing:)` (states 3 and 4 only, origin flipped), `anyMouseButtonDown()`, per-device actuators and `playFeedback`, the wake observer. From the user's side: a thumb-anchored tap brings the assigned app to the front with a pulse on the trackpad that was tapped, on every connected trackpad, after hot-plug and after sleep.

**Blocked by:** S4.

**Requirements:** R11 (on hardware), R12 (Spaces, full screen, already active, double tap), R13 (real feedback, per device), R14 (preference semantics, Smart zoom rule, external trackpad), R16 (hot-plug and wake on hardware), R20 (TCC silence through the first gesture), R22 (idle CPU).

**Test scenarios:** T58.

- [ ] The hardware session under Verified without a test (R11 on hardware, R12, R13, R14 semantics and Smart zoom, R16, R20, R22, and "run clears the registry first") is run on a 13" MacBook and a Magic Trackpad and ticked in the plan; the measured preference values, the chosen actuation strength and any `GestureRules` tuning are written back into the design.
- [ ] If Smart zoom fires with the thumb anchored, `.smartZoom` is added and T31/T32 extended in the same slice.
- [ ] A Magic Trackpad's `Product` string is recorded in T59.

### S6: Release build and the silence checks

**What to build:** Release signing with Developer ID and hardened runtime, the release script (archive, developer-id export, `notarytool submit --wait`, `stapler staple`), the universal-binary check, and the one-session verification of network, log and file silence on the release build.

**Blocked by:** S5. Externally blocked on a Developer ID Application certificate for the signing and notarization steps; everything else in the slice can run on an Apple Development build.

**Requirements:** R21, R23.

**Test scenarios:** None.

- [ ] The R23 checks under Verified without a test pass: deployment target, `lipo` architectures, hardened runtime, Developer ID authority, `spctl` acceptance of the stapled app, a clean open on a fresh macOS 26 Mac, the macOS 15 alert.
- [ ] The R21 session (network monitor, Console, `lsof`) is run on the release build and ticked in the plan.
- [ ] The release script is the only path that signs the release; `--deep` is not used and the main executable is signed last (per `docs/architecture.md`).
