# Plan: Trackpad Launcher runs in the background, with a settings window instead of a menu bar icon

## Problem statement

Trackpad Launcher lives in the menu bar. Its icon takes menu bar space for an app the user sets up once and then forgets. The window hangs under the icon and closes at any outside click, so the user loses it while trying a gesture or picking an app with *Other…*. Quit hides in the icon's right-click menu.

Getting the app is not defined either. Nothing makes sure the app ends up in /Applications. An app run from ~/Downloads or straight from a disk image breaks in quiet ways: its login item points at a file the user later deletes, and macOS runs a quarantined download from a hidden, randomised copy.

## Solution

Trackpad Launcher becomes a background app with no menu bar icon. Opening the app, from Spotlight, Finder, Launchpad or anywhere else, opens its **settings window**. While that window is open, the app shows in the Dock like any app. Closing the window removes the Dock icon, and gestures keep working. Trackpad Launcher starts by itself at every login, with no window and no Dock icon. Of the app's own controls, only the *Quit Trackpad Launcher* button at the end of the settings window stops it.

The app ships as a signed, notarised disk image that shows "drag to Applications". When the user opens the app by hand from anywhere outside /Applications, it first moves itself there.

The glossary's *launcher window* is renamed *settings window*. In the product overview, every mention of the menu bar and the menubar window, including the menubar-window.png image reference, changes to match this plan.

## Requirements

### R1. No menu bar icon
Trackpad Launcher MUST NOT show an icon in the menu bar, in any state.

#### Scenario: Running with the settings window closed
- **GIVEN** Trackpad Launcher is running and its settings window is closed
- **WHEN** the user looks at the menu bar and the Dock
- **THEN** neither shows Trackpad Launcher, and a 1-finger gesture still brings its assigned app to front

#### Scenario: Gestures inactive
- **GIVEN** *Tap to click* is on, so gestures are inactive (the glossary's *Conflicting setting*)
- **WHEN** the user opens the settings window
- **THEN** the menu bar shows nothing for Trackpad Launcher, and the settings window shows the trackpad settings notice

### R2. One Trackpad Launcher at a time
At most one Trackpad Launcher MUST recognise gestures at any moment. Opening the copy in /Applications while Trackpad Launcher runs MUST NOT start a second one that recognises gestures. It MUST open the running one's settings window instead. A copy opened by hand from anywhere else is a separate process. It shows only the move dialog (R18) and never recognises gestures.

#### Scenario: Opening the app from Spotlight while it runs in the background
- **GIVEN** Trackpad Launcher runs from /Applications with its settings window closed, and no other copy is open
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the settings window opens in front with the keyboard focus, the Dock shows one Trackpad Launcher icon, and Activity Monitor lists one Trackpad Launcher process

#### Scenario: Opening the app while its settings window is already open behind other windows
- **GIVEN** the settings window is open behind another app's window
- **WHEN** the user opens Trackpad Launcher from /Applications in Finder
- **THEN** the same settings window comes to the front, and no second window opens

#### Scenario: Opening the app while the settings window is minimised
- **GIVEN** the user minimised the settings window to the Dock
- **WHEN** the user opens Trackpad Launcher from Spotlight
- **THEN** the settings window is restored and comes to the front

### R3. Opening a different build replaces the running one
When the user opens the copy in /Applications by hand while a different build of Trackpad Launcher runs, or the same build from another place, Trackpad Launcher MUST stop the running one and start the opened one with its settings window open. One Trackpad Launcher MUST run afterwards, and it MUST be the opened version. This holds when the user dragged a newer version over a running one in Finder, and when they upgraded from the menu bar version. The old menu bar icon MUST be gone without logging out.

#### Scenario: Replacing the running menu bar version in Finder
- **GIVEN** the menu bar version runs from /Applications and shows its menu bar icon
- **WHEN** the user drags this version over it in Finder and opens it from Launchpad
- **THEN** the menu bar icon disappears, the settings window opens, and Activity Monitor lists one Trackpad Launcher process, which is the new version

### R4. Opening the app when it is not running starts it
Opening the app by hand from /Applications while it is not running MUST start Trackpad Launcher and open its settings window. R18 covers copies opened from anywhere else.

#### Scenario: After Quit
- **GIVEN** the user stopped Trackpad Launcher with *Quit Trackpad Launcher*
- **WHEN** they open it from Launchpad
- **THEN** gestures work again and the settings window opens

#### Scenario: After a crash
- **GIVEN** Trackpad Launcher crashed and is not running
- **WHEN** the user opens it from Spotlight
- **THEN** gestures work again and the settings window opens

### R5. The first run sets everything up
The first run is the first run on a Mac that holds no saved Trackpad Launcher settings. The first run from /Applications MUST make Trackpad Launcher start at every login, ask for the Accessibility permission when it is missing, and open the settings window. Gestures MUST work from that moment on, with no further step. Later runs MUST NOT ask for the permission.

#### Scenario: First run on a fresh Mac
- **GIVEN** Trackpad Launcher has never run on this Mac and was just dragged into /Applications
- **WHEN** the user opens it
- **THEN** macOS asks for the Accessibility permission, the settings window opens with every gesture unassigned, Trackpad Launcher shows under *System Settings → General → Login Items*, and a 1-finger gesture assigned now works

#### Scenario: First run with Accessibility already granted
- **GIVEN** Trackpad Launcher already holds the Accessibility permission
- **WHEN** it runs for the first time
- **THEN** nothing asks for the permission, and the settings window opens

#### Scenario: Accessibility missing on a later run
- **GIVEN** Trackpad Launcher ran on this Mac before, and the user revoked its Accessibility permission
- **WHEN** the user opens it by hand
- **THEN** the settings window opens showing the Accessibility hint, and macOS does not ask for the permission

### R6. The Dock shows the app exactly while the settings window is open
Trackpad Launcher MUST appear in the Dock and in ⌘-Tab while its settings window is open, minimised included. It MUST leave both when the window closes. Gestures MUST keep working.

#### Scenario: Closing the window
- **GIVEN** the settings window is open and the Dock shows Trackpad Launcher
- **WHEN** the user clicks the window's close button
- **THEN** the window and the Dock icon disappear, and a 2-finger gesture still brings its assigned app to front

### R7. The settings window is an ordinary window
The settings window MUST be a normal macOS window with the close and minimise buttons. It MUST open centred on the display under the pointer, in front, with the keyboard focus, every time it opens. It MUST stay open when the user clicks elsewhere or switches to another app.

#### Scenario: Clicking another app
- **GIVEN** the settings window is open
- **WHEN** the user clicks a Safari window
- **THEN** Safari comes to the front, the settings window stays open behind it, and the Dock still shows Trackpad Launcher

#### Scenario: Reopening on another display
- **GIVEN** the user closed the settings window after dragging it to the left edge of the main display
- **WHEN** they open the app again with the pointer on a second display
- **THEN** the window opens centred on the second display

### R8. Every ordinary way to quit only closes the window
The app menu's quit item MUST NOT read *Quit Trackpad Launcher*. It MUST read *Close Settings*, with ⌘Q, and close the settings window. Each of these MUST close the settings window and keep Trackpad Launcher running:
- the window's close button
- ⌘W
- Escape, when no menu or chooser is open. When one is open, Escape closes that first.
- ⌘Q, or *Close Settings* in the app menu
- *Quit* in the Dock icon's menu

The Dock menu's *Quit* label can't be changed. It is an accepted oddity. Logging out, restarting and shutting down MUST still end Trackpad Launcher without the user being asked.

#### Scenario: ⌘Q
- **GIVEN** the settings window is open and focused
- **WHEN** the user presses ⌘Q
- **THEN** the window and the Dock icon disappear, and a 3-finger gesture still brings its assigned app to front

#### Scenario: The app menu
- **GIVEN** the settings window is open and focused
- **WHEN** the user opens the app menu
- **THEN** it shows *Close Settings* with ⌘Q, and no *Quit Trackpad Launcher*

#### Scenario: Escape
- **GIVEN** the settings window is open and focused, and no menu or chooser is open
- **WHEN** the user presses Escape
- **THEN** the window and the Dock icon disappear, and gestures keep working

#### Scenario: Escape with an app picker's menu open
- **GIVEN** the 1-finger gesture's app picker menu is open
- **WHEN** the user presses Escape
- **THEN** the menu closes, the settings window stays open, and the gesture keeps its app

#### Scenario: Quit from the Dock
- **GIVEN** the settings window is open
- **WHEN** the user right-clicks the Dock icon and chooses Quit
- **THEN** the window and the Dock icon disappear, and gestures keep working

#### Scenario: Closing the window while choosing an app with *Other…*
- **GIVEN** the user chose *Other…* in the 2-finger gesture's picker, and the file chooser is open
- **WHEN** the user chooses Quit in the Dock icon's menu
- **THEN** the chooser and the settings window close, the 2-finger gesture keeps its app, and gestures keep working

#### Scenario: Restart
- **GIVEN** Trackpad Launcher runs in the background
- **WHEN** the user restarts the Mac
- **THEN** the restart is not held up or questioned by Trackpad Launcher

### R9. Trackpad Launcher starts silently at login
While starting at login is on, Trackpad Launcher MUST start at every login with no window, no Dock icon, no dialog and no permission prompt. This holds when the settings window was open at logout, and when the Accessibility permission is missing. Gestures MUST work from the moment it starts.

#### Scenario: Turning the Mac off and on
- **GIVEN** Trackpad Launcher runs in the background
- **WHEN** the user shuts the Mac down, turns it on and logs in
- **THEN** a 1-finger gesture brings its assigned app to front, and neither the Dock nor the screen shows Trackpad Launcher

#### Scenario: The settings window was open at logout
- **GIVEN** the settings window was open when the user logged out, with macOS's *Reopen windows when logging back in* ticked
- **WHEN** the user logs back in
- **THEN** no settings window opens, the Dock shows no Trackpad Launcher icon, and gestures work

#### Scenario: Starting at login without the Accessibility permission
- **GIVEN** Trackpad Launcher does not hold the Accessibility permission
- **WHEN** the user logs in
- **THEN** no window opens and nothing asks for the permission, and a 1-finger gesture still brings its assigned app to front; only click blocking and the window swipe need the permission

### R10. The Quit button's place and look
The settings window MUST end with a *Quit Trackpad Launcher* button, below every other setting, notice and hint, aligned right. It MUST be a Liquid Glass capsule tinted solid red, with white text, at the system's regular button size.

#### Scenario: The button stays last
- **GIVEN** the Accessibility hint and the screen recording hint both show
- **WHEN** the user scrolls to the end of the settings window
- **THEN** the Quit button sits below both of them, at the right edge of the window's content

### R11. Pressing Quit stops Trackpad Launcher
Pressing *Quit Trackpad Launcher* MUST stop Trackpad Launcher at once, with no confirmation: the window and the Dock icon disappear and no gesture is recognised.

#### Scenario: Quitting
- **GIVEN** the settings window is open
- **WHEN** the user presses *Quit Trackpad Launcher*
- **THEN** the window and the Dock icon disappear, Activity Monitor lists no Trackpad Launcher process, and a 1-finger gesture under the anchored thumb is an ordinary tap

### R12. Quit holds across restarts until the app is opened again
Pressing *Quit Trackpad Launcher* MUST turn starting at login off, only if it was on at that moment. Trackpad Launcher MUST NOT start at the next login after a Quit. Opening it by hand after a Quit MUST start it. It MUST turn starting at login back on only when that Quit was what turned it off.

#### Scenario: Quit, then restart
- **GIVEN** the user pressed *Quit Trackpad Launcher*
- **WHEN** they restart the Mac and log in
- **THEN** Trackpad Launcher is not running

#### Scenario: Quit, restart, then open by hand
- **GIVEN** the user quit Trackpad Launcher and restarted the Mac
- **WHEN** they open it from Spotlight and then restart again
- **THEN** after the second restart Trackpad Launcher runs in the background with no window

### R13. The user's Login Items choice is kept
When the user turned Trackpad Launcher off under *System Settings → General → Login Items*, Trackpad Launcher MUST NOT turn it back on, whatever happens: opening it by hand, the first run of a newer version, or opening it after a Quit. When the user turns it back on there, R12 applies again.

#### Scenario: Turned off in System Settings, then opened by hand
- **GIVEN** the user switched Trackpad Launcher off in *Login Items*
- **WHEN** they open the app from Spotlight
- **THEN** the settings window opens, and *Login Items* still shows it off

#### Scenario: Turned off in System Settings, then Quit and reopened
- **GIVEN** the user switched Trackpad Launcher off in *Login Items* and later pressed *Quit Trackpad Launcher*
- **WHEN** they open the app again
- **THEN** *Login Items* still shows it off

#### Scenario: Turned off, back on, then Quit and reopened
- **GIVEN** the user switched Trackpad Launcher off in *Login Items*, later switched it back on there, and then pressed *Quit Trackpad Launcher*
- **WHEN** they open the app again
- **THEN** *Login Items* shows it on

#### Scenario: Turned off, then upgraded
- **GIVEN** the user switched Trackpad Launcher off in *Login Items*
- **WHEN** they install a newer version into /Applications and open it
- **THEN** *Login Items* still shows it off

### R14. No relaunch after a crash or force quit
Trackpad Launcher MUST NOT relaunch by itself after it crashes or is force-quit. It MUST start again at the next login, while starting at login is on, or when the user opens it.

#### Scenario: Force quit from Activity Monitor
- **GIVEN** Trackpad Launcher runs in the background
- **WHEN** the user force-quits it in Activity Monitor
- **THEN** it stays stopped until the next login or until the user opens it

### R15. Gestures leave the settings window open
A gesture, a swipe, a window swipe or a swap that fires while the settings window is open MUST leave the window open. The app it brings to front comes over the window. Its feedback and launch animation are unchanged. Trackpad Launcher MUST never count as a running app or as the frontmost app for the switcher or the swap. With the settings window in front, the switcher's row and the swap MUST work from the app that was in front before it, as the glossary's *Frontmost app* says.

#### Scenario: Trying a gesture just assigned
- **GIVEN** the settings window is open and the user just assigned Notes to the 2-finger gesture
- **WHEN** they make the 2-finger gesture
- **THEN** Notes comes to the front over the settings window, with the gesture haptic and the launch animation, and the settings window and the Dock icon stay

#### Scenario: The switcher never lists Trackpad Launcher
- **GIVEN** Safari was in front, and the user opened the settings window over it
- **WHEN** the user swipes to open the switcher
- **THEN** the switcher's row does not hold Trackpad Launcher, and it is the row the user would get with Safari in front

### R16. *Other…* chooses an app without closing the window
Choosing *Other…* in an app picker MUST show the file chooser attached to the settings window, which stays open. Choosing an app MUST assign it to that gesture. Cancelling MUST leave the assignment as it was.

#### Scenario: Choosing an app in ~/Downloads
- **GIVEN** the settings window is open
- **WHEN** the user chooses *Other…* in the 3-finger gesture's picker and picks an app in ~/Downloads
- **THEN** the chooser closes, the settings window stays open, and the 3-finger gesture's picker shows that app

#### Scenario: Cancelling
- **WHEN** the user chooses *Other…* and presses Cancel
- **THEN** the settings window stays open and the gesture keeps its app

### R17. System Settings buttons leave the window open
The Accessibility hint's, the screen recording hint's and the trackpad settings notice's buttons MUST open System Settings and leave the settings window open.

#### Scenario: Granting Accessibility
- **GIVEN** the settings window shows the Accessibility hint
- **WHEN** the user presses its button
- **THEN** System Settings opens on the Accessibility page, and the settings window stays open behind it

### R18. Opening the app outside /Applications asks to move it first
When the user opens Trackpad Launcher by hand from anywhere outside /Applications, it MUST first show a dialog saying it needs to be in the Applications folder, with *Move to Applications* (default) and *Quit*. ~/Applications counts as outside. Until the user answers, a copy opened this way MUST NOT start recognising gestures, ask for a permission, register for login or open the settings window. *Quit* MUST stop it with nothing changed. A release build opened by hand MUST NOT keep running from outside /Applications. R22 and R23 are the exceptions.

#### Scenario: Opened straight from the disk image
- **GIVEN** the user opened the downloaded disk image
- **WHEN** they double-click Trackpad Launcher inside it
- **THEN** the move dialog shows, and nothing else of Trackpad Launcher does

#### Scenario: Quit in the move dialog
- **GIVEN** Trackpad Launcher has never run on this Mac, and the user opened it from ~/Downloads, so the move dialog shows
- **WHEN** the user presses *Quit* in the move dialog
- **THEN** Trackpad Launcher stops, nothing is copied, and no login item, permission prompt or settings exists afterwards that was not there before

#### Scenario: A copy already in /Applications is running
- **GIVEN** Trackpad Launcher runs from /Applications
- **WHEN** the user opens another copy from ~/Downloads
- **THEN** the move dialog shows, and the running copy keeps recognising gestures while it does

#### Scenario: Opening by hand a copy outside /Applications that started at login
- **GIVEN** a Trackpad Launcher in ~/Applications/Tools started at login (R22) and runs in the background
- **WHEN** the user opens that copy by hand
- **THEN** the move dialog shows, and gestures keep working while it does; *Move to Applications* then installs it into /Applications as R19 and R20 say, and *Quit* stops it

### R19. Moving finishes the install from /Applications
*Move to Applications* MUST put the app in /Applications and open it from there, which goes on to its first run (R5) or opens its settings window. The copy the user opened MUST be removed from where it was. If it cannot be removed, for example on a read-only network share, the move MUST still complete and leave the original where it was. A copy on a disk image stays there. The disk image SHOULD be ejected. If it cannot be, because other files on it are in use, it stays mounted and the move still completes.

#### Scenario: Moving from ~/Downloads
- **GIVEN** the user opens Trackpad Launcher from ~/Downloads for the first time
- **WHEN** they press *Move to Applications*
- **THEN** /Applications holds Trackpad Launcher, ~/Downloads no longer does, and the settings window opens with macOS asking for the Accessibility permission

#### Scenario: Moving from the disk image
- **WHEN** the user opens the app from the disk image and presses *Move to Applications*
- **THEN** /Applications holds Trackpad Launcher, the disk image is no longer mounted, and the settings window opens

### R20. Moving replaces the copy in /Applications and keeps the settings
When /Applications already holds Trackpad Launcher, *Move to Applications* MUST stop it if it is running, replace it with the copy being moved, and open the new one with its settings window open. The copy being moved MUST replace the one in /Applications whatever their versions, because the user chose that copy. Every setting MUST be kept, including the assignments and starting at login.

#### Scenario: Installing a newer version over a running one
- **GIVEN** an older Trackpad Launcher runs from /Applications with Arc on the 1-finger gesture and Left thumb chosen
- **WHEN** the user opens a newer version from its disk image and presses *Move to Applications*
- **THEN** one Trackpad Launcher runs, it is the newer version, its settings window shows Arc on the 1-finger gesture and Left thumb, and a 1-finger gesture brings Arc to front

### R21. Moving on an account that needs an administrator
When the user's account cannot write to /Applications by itself, *Move to Applications* MUST ask for an administrator's name and password the way Finder does. Cancelling MUST stop Trackpad Launcher with nothing moved.

#### Scenario: Standard account cancels
- **GIVEN** the user is on a standard account
- **WHEN** they press *Move to Applications* and then Cancel in the password prompt
- **THEN** Trackpad Launcher stops and /Applications is unchanged

### R22. Starting at login never asks to move
A Trackpad Launcher that starts at login MUST NOT show the move dialog, wherever it lies. It MUST run as R9 says.

#### Scenario: An older install outside /Applications
- **GIVEN** a Trackpad Launcher in ~/Applications/Tools was registered to start at login before this version
- **WHEN** the user logs in
- **THEN** it runs in the background with no dialog

### R23. Development builds never ask to move
A development build is a build not signed for release, for example one run from Xcode. A development build MUST NOT show the move dialog. It MUST run where it was built.

#### Scenario: Running from Xcode
- **WHEN** the developer runs Trackpad Launcher from Xcode
- **THEN** no move dialog shows, and the settings window opens

### R24. Trackpad Launcher ships as a notarised disk image
Each release MUST be a disk image signed with a Developer ID and notarised by Apple. Opening it MUST show Trackpad Launcher beside a shortcut to the Applications folder, with a cue to drag one onto the other. A Mac MUST open the downloaded disk image and the app inside it with no Gatekeeper warning about an unverified developer. One command MUST build the release disk image from the repository.

#### Scenario: Downloading and installing with Safari
- **GIVEN** a Mac that has never seen Trackpad Launcher
- **WHEN** the user downloads the release disk image with Safari, opens it, drags Trackpad Launcher onto the Applications shortcut and opens it from Launchpad
- **THEN** no warning about an unverified developer shows, no move dialog shows, and the first run of R5 follows

### R25. Upgrading from the menu bar version keeps everything
Upgrading from a version with the menu bar icon MUST keep every setting and keep starting at login as it was. The menu bar icon MUST be gone from the first start of the new version.

#### Scenario: First login after the upgrade
- **GIVEN** a menu bar version, with gestures assigned, was replaced by this version
- **WHEN** the user logs in
- **THEN** Trackpad Launcher runs with no menu bar icon and no Dock icon, and every gesture brings its assigned app to front

## Non-goals

- **Updating itself.** Checking for updates needs a network call, and the overview promises none. Changing that is its own product decision and a later feature.
- **Mac App Store.** Its sandbox forbids reading raw trackpad touches and blocking clicks system-wide, which the app needs.
- **Homebrew cask.** It can be added on top of the disk image later.
- **Relaunching after a crash or force quit.** The user chose the next login or opening the app by hand (R14).
- **A replacement for the menu bar icon's active or inactive state.** The trackpad settings notice in the settings window is enough.
- **An option to keep a menu bar icon.** The settings window opened from Spotlight replaces it. It can be revisited if asked for.
- **A keyboard shortcut to open the settings window.** Spotlight, Launchpad and Finder open it. A global shortcut is a separate feature.
- **Remembering where the settings window was.** It opens centred each time (R7).
- **A confirmation before Quit.** Opening the app undoes it (R11).
- **Refusing to downgrade.** Moving an older copy over a newer one replaces it. The user chose that copy (R20).
- **Getting the Developer ID certificate.** The developer gets it. The release command needs it to sign and notarise.

## Design

### Problem

Today the whole lifecycle is one first-launch branch in `Launcher.start()`, a status item and a non-activating panel. Plan 021 needs every process to decide, as it starts and each time it is opened again, between five outcomes: run gestures silently, run them with the settings window open, stop other running copies first, ask to move, or end. It also needs gestures to keep working while the app's own ordinary, activating window is in front. The grounding (`.temp/architect/grounding/index.md`) fixes the constraints the shape must honour:

- The login marker in the open event is readable only from `applicationDidFinishLaunching` (F1, F2), so nothing can be decided before the run loop starts.
- The gesture adapters start sensing in their `init`s and `Launcher.init` scans the disk (F11). A copy that only asks to move must never build them, yet a copy that already runs gestures must still be able to ask (R18, last scenario).
- LaunchServices turns an open of the running copy's own bundle into a reopen; any other open (another place, or a bundle replaced at the same path, whatever its version) starts a second process (F4-F6, `checks/same-version-replace`). So every second process is a newcomer to resolve, never a reopen.
- A quit sent by another copy looks exactly like the Dock's Quit (F15, F16); the menu bar version vetoes nothing (F20).
- First run means no `settings` record, and its side effects come before the first save (F10, `why.md` Preserve 1). A user who turned starting at login off is never re-enrolled (Avoid 1).
- No timers, polling or sleeps (F37). `LauncherCore` imports Foundation and Observation only. Every port has a real and an in-memory adapter.
- The own-pid filters keep Trackpad Launcher out of the ⌘-Tab apps, but make `frontmost == nil` whenever it is active (F26, F27).
- The restricted Privileged File Operation entitlement is out (F31); the admin path is `AuthorizationExecuteWithPrivileges` through `dlsym` (F32).

### Usage (caller's view)

One process-level owner, `Lifecycle`, decides; the app delegate parses four AppKit signals into values and forwards them, and builds the gesture model and its window only when `Lifecycle` asks for them. The settings window talks to `Launcher` as today, plus a Quit closure into `Lifecycle`.

```swift
// TrackpadLauncher/TrackpadLauncherApp.swift: the composition root and the only NSApplicationDelegate.
@main enum TrackpadLauncherApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var lifecycle: Lifecycle!
    private var shell: SettingsShell?
    private var moveDialog: MoveDialogPresenter?
    private let quitSignals = QuitSignals()              // remembers willPowerOff; classifies the quit being handled
    private var event: NSAppleEventDescriptor? { NSAppleEventManager.shared().currentAppleEvent }

    func applicationWillFinishLaunching(_: Notification) {
        NSApp.disableRelaunchOnLogin()                     // R9: only the login item starts it at login (F3)
        let location = ThisCopy.location()                 // translocation resolved, disk image found, once
        let placement = Placement(
            build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location: location)
        let startAtLogin = StartAtLogin(item: SystemLoginItem(), defaults: .standard, placement: placement)
        lifecycle = Lifecycle(
            placement: placement, copies: SystemRunningCopies(), installer: ApplicationsInstaller(location: location),
            startAtLogin: startAtLogin, makeResident: { [unowned self] in makeResident(startAtLogin) })
        moveDialog = MoveDialogPresenter(lifecycle: lifecycle)
    }
    func applicationDidFinishLaunching(_: Notification) {           // the open event exists only from here (F1)
        lifecycle.launched(ThisCopy.launch(event: event, arguments: CommandLine.arguments))
    }
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        lifecycle.openedAgain(ThisCopy.opening(of: event)); return false
    }
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        lifecycle.shouldEnd(quitSignals.request(for: event)) ? .terminateNow : .terminateCancel
    }

    /// The gesture model and the window that renders it, built together, only for a copy that runs gestures.
    private func makeResident(_ startAtLogin: StartAtLogin) -> Launcher {
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(), permissions: SystemPermissions(),
            system: WorkspaceActions(), catalog: catalog, scanner: SystemAppScanner(catalog: catalog),
            store: SettingsStore(defaults: .standard), startAtLogin: startAtLogin)
        shell = SettingsShell(launcher: launcher, quit: { [unowned self] in lifecycle.quit() })
        return launcher
    }
}
```

The settings shell's call sites, each one intent:

```swift
func windowShouldClose(_: NSWindow) -> Bool { launcher.closeWindow(); return false }    // close button, ⌘W
override func cancelOperation(_: Any?) { onCancel() }                                   // Escape → launcher.closeWindow()
@objc func closeSettings(_: Any?) { launcher.closeWindow() }                            // app menu "Close Settings" ⌘Q
Button(Copy.quitButton, action: actions.quit)                                           // the red capsule, last in the view
```

Two requirement scenarios at the one high seam:

```swift
@Test func openingAnotherBuildByHandStopsTheRunningOneAndRunsOnlyOnceItHasExited() {
    let world = LifecycleWorld(placement: .installed, others: [.startedEarlier])
    world.lifecycle.launched(Launch(opening: .byHand))
    #expect(world.copies.stopped == world.copies.others)
    #expect(world.lifecycle.launcher == nil)            // R2: nothing of ours recognises gestures yet
    world.copies.letStoppedCopiesExit()                 // the push the test withheld
    #expect(world.lifecycle.launcher?.isWindowOpen == true)
}

@Test func aCopyOutsideApplicationsAsksFirstAndItsQuitChangesNothing() {
    let world = LifecycleWorld(placement: .elsewhere, others: [.startedEarlier])
    world.lifecycle.launched(Launch(opening: .byHand))
    #expect(world.lifecycle.moveDialog == .asking)
    #expect(world.residentsBuilt == 0 && world.copies.stopped.isEmpty)   // R18: the running copy keeps its gestures
    world.lifecycle.answer(.quit)
    #expect(world.copies.hasEnded && !world.hasSettingsRecord && world.loginItem.calls.isEmpty)
}
```

### Shape

**Data first.** A process is in exactly one `Lifecycle.Stage`, a private enum that is the only record of what the process is doing; `moveDialog` and `launcher` are derived from it (per model-the-domain). The facts it acts on are values parsed once at the AppKit boundary: `Opening`, `Location`, `Placement`, `Launch`, `QuitRequest` (per boundary-discipline). What an opening leads to is one pure table, `Route(opening:placement:olderCopyRuns:)`, used by both a launch and a reopen. The settings window is `Launcher.Window { closed, open(request:) }`; every opening by hand increments the request, so a reopen of an open or minimised window is still a state change the shell renders. Starting at login is owned by `StartAtLogin`, whose one remembered fact has its own `UserDefaults` key beside the `settings` record, never inside it: the mover and the running copy then never write the same record, an older build's save cannot drop the fact (`Settings` ignores unknown keys), and a move never creates or spends a first run (per separate-before-serializing-shared-state).

**Load-bearing decisions.**

1. **`Lifecycle` sits above and beside `Launcher` and builds it lazily** (via `makeResident`). A copy that only asks to move never builds the sensing adapters, the catalog scan or the window's icon pass; a resident copy can still show the dialog while its gestures run. The route table:

   | Opening | Placement | Older copy runs | Route |
   |---|---|---|---|
   | at login | any | yes | `end` (two login starts converge on the older) |
   | at login | any | no | `runSilently` (R9, R22) |
   | by hand | `installed` or `development` | any | `runWithWindow`, after stopping every other copy (R2-R4, R23) |
   | by hand | `elsewhere` | any | `askToMove` (R18) |

   A reopen uses the same table: `runWithWindow` raises the window, `askToMove` shows the dialog over a running resident (R18, last scenario), `runSilently` (a login start reaching the running copy) does nothing.

2. **`Placement` is one rule for R5, R18 and R23**, derived from `Location`, which `ThisCopy.location()` reads once: the bundle as it runs, its original place and whether it is translocated (both from `SecTranslocate*`, F34, stored, never inferred by comparing URLs), and the disk image it lies on (F35). `installed` when the running bundle is not translocated and lies anywhere inside /Applications, whatever its build (R18 says "outside /Applications", so a copy in /Applications/Utilities is inside; R5 binds every first run from /Applications). Otherwise `development` when the build is not signed with Developer ID (F7), never `#if DEBUG`, so the perf build is development too (F8). Otherwise `elsewhere`, ~/Applications included. A translocated copy runs from a hidden mount, so it reads `elsewhere` even when its original is in /Applications, and re-installs itself without quarantine. Paths are compared standardized, so `Bundle.main.bundleURL`'s trailing slash never matters. For checking the release-only paths by hand without a Developer ID certificate (F40), a build not signed for release reads as `release` when launched with `--as-release-build`; a release build ignores the argument, so it can never make a release copy skip the move dialog.

3. **Other copies are stopped, not asked.** `RunningCopies.stop` calls `forceTerminate()` and waits for KVO on `isTerminated` (with `.initial`), a push. A copy cannot refuse, hang, show its own dialog or be mistaken for the Dock's Quit, and no handshake binds versions together, the menu bar version included. A copy has nothing to flush: every setting is saved when it changes (F21). Gestures start only after every other copy has exited (R2). Which copy started earlier is one strict total order, a pure rule in the adapter: launch date, a missing date counting as latest, then pid. Two login starts therefore compute mirror-image answers and converge on one copy.

4. **A login start never does first-run work; the first opening by hand does.** `Launcher.start()` turns gestures on and asks, opens and saves nothing. `Launcher.openedByHand()`, once per process, does the first-run setup (on no `settings` record: `startAtLogin.enrol()`, the Accessibility ask when missing, then the first save, both effects before the save as today) or else `startAtLogin.resume()`; every time, it raises the window.

5. **`StartAtLogin` has three intents** and only ever asks "is it `.enabled` now?", so the disputed status after a user's own choice (F25) cannot mislead it:
   - `enrol()` on a first run: register, forget any stale fact. A user's earlier off stands: macOS refuses (F22).
   - `suspend()` on Quit and on a move: if it is on now, remember that Trackpad Launcher turned it off, then unregister. Already off (the user's choice), nothing changes (R13).
   - `resume()` on an opening by hand: re-register only if remembered, and forget only once macOS accepts.

   Crash order: remember before unregistering, register before forgetting, so every crash point converges on the next opening by hand (per make-operations-idempotent). **A development build outside /Applications leaves starting at login alone**: all three are no-ops for `.development`, so it never registers its build folder and never turns off the installed copy's item. A development build inside /Applications is `installed` and behaves as a release copy there (R5).

6. **The Dock follows the window, only in the shell.** `SettingsShell` renders `launcher.window`. On `.open` from `.closed`: `.regular`, size to content, centre on `Displays.screen(under: NSEvent.mouseLocation)`. On every `.open(request:)`: de-miniaturise, `makeKeyAndOrderFront`, `NSApp.activate()` (F12, F13). On `.closed`: end any attached sheet (its completion sees Cancel), `orderOut`, `.accessory`. `LSUIElement` stays `true`, so a login start never flashes a Dock icon (F12). The window is an ordinary titled, closable, miniaturisable, non-resizable window at normal level with no event monitors; its content is built once and kept (`docs/performance.md`). `.heldOpen`, `dismissWindow()` and the four effect-closes in `fire`, `swipe`, `windowSwipe` and `swap` are deleted (R7, R15).

7. **Quit.** Every ordinary way to quit (the app menu, the Dock icon's menu) exists only while the window is open. So `shouldEnd(.other)` with the window open closes it and refuses; any quit while it is closed ends the app. A logout with the window closed, the usual case, can never be held up, whatever the unprobed signals do. With the window open, three layers apply: `NSSupportsSuddenTermination = YES` lets the system kill instead of asking (F18); `QuitSignals` classifies as `.system` any quit that carries `kAEQuitReason`, comes from `com.apple.loginwindow`, or arrives after `willPowerOffNotification` (F17, F19); and the Quit button goes through `Lifecycle.quit()`, whose `.ending` stage lets AppKit's terminate through. The model never holds a `terminate` closure: `RunningCopies.endThisCopy()` is a port command, and it carries policy now (Quit turns login off), which `why.md` Preserve 5 allows.

8. **The frontmost app while Trackpad Launcher is active (R15)** stays below the port, where self-exclusion lives. While this process is the active app, `RunningAppsReader` reports as frontmost the first ⌘-Tab app. That order already drops this process by pid (F26), so it holds the app that was in front before it, and Spotlight, which is not a ⌘-Tab app, never counts. One pure function, no new state. `FrontmostAppWindows` is unchanged: while Trackpad Launcher is active a slide up or down is no window swipe, because raising windows needs their app frontmost (F29). The swap, switcher and window-swipe paths in `Launcher` change only by losing their window closes.

9. **The move is ordered for convergence**, in `Lifecycle`, pinned by tests:
   1. `installer.install`: stage a copy in a temporary folder on the /Applications volume, clear its quarantine, get the administrator's answer when this user cannot write there, then swap it in. That swap is the first change anywhere. Unprivileged it is one atomic replace. With an administrator it is two renames, the old copy moved aside into the staging folder (never left inside /Applications), then the new one in: a kill between them leaves /Applications without the app and the old copy in the staging folder, and the next Move installs again. Cancel → end with nothing changed (R21); failure → the failure dialog.
   2. `startAtLogin.suspend()`: the item is handed over before the original can go, so a crash leaves it owed, never lost.
   3. `installer.removeOriginal()`: unless it is on a disk image; a failure leaves it (R19).
   4. Stop every other copy, the one that ran from /Applications included (R20), so the next open starts a fresh process.
   5. `installer.openInstalledCopy()`, passing `--eject-disk-image <volume>` when this copy came from one.
   6. End. The installed copy is an opening by hand: first run (R5) or `resume()`, and it ejects the disk image once it has stopped the mover (R19).

   A logout during the move ends the process (`shouldEnd(.system)` is true while moving, R8); the order above is what keeps that safe: before the swap nothing has changed, after it the installed copy is whole and the next opening by hand converges. Only the administrator path's gap between its two renames is not covered, as step 1 says.

**Depth.** `Lifecycle` has five intents (`launched`, `openedAgain`, `shouldEnd`, `answer`, `quit`) and two derived reads; behind them sit routing, replacement and its wait, the login tie-break, the move's order and its crash convergence, the login hand-over and the quit policy. The delegate knows nothing about copies, installs or login items. `StartAtLogin` has three intents over a key, an ordering and macOS's errors. `Launcher`'s lifecycle surface shrinks: `openWindow`, `dismissWindow` and the first-launch branch become `openedByHand()`. Each new port hides a platform tangle behind two to four calls: `forceTerminate` plus KVO; translocation, staging, authorization and an atomic swap; `SMAppService` and its errors.

#### Type sketch: LauncherCore

```swift
// MARK: Lifecycle.swift: one process, from start to exit. Imports Foundation and Observation only.

/// How macOS started this process, or opened it again. Parsed from the open/reopen Apple event by `ThisCopy`.
public enum Opening: Equatable, Sendable {
    /// As a login item: the open event carries the login-item marker (F2). Silent: no window, dialog or prompt.
    /// (Core doc comments never spell a confined API name: the source scan reads comments.)
    case atLogin
    /// Finder, Spotlight, Launchpad, the Dock, Xcode, or a move finishing: every opening that is not at login.
    case byHand
}

public enum Build: Equatable, Sendable {
    case release
    /// Not signed with a Developer ID (F7): Xcode, the perf build, an ad-hoc binary. Never `#if DEBUG` (F8).
    case development
}

public struct DiskImage: Hashable, Sendable {
    public let volume: URL
    public init(volume: URL) { self.volume = volume }
}

/// Where this copy lies, read once at start by `ThisCopy.location()`.
public struct Location: Equatable, Sendable {
    /// `Bundle.main.bundleURL`: a hidden translocation mount when macOS translocated a quarantined copy.
    public let running: URL
    /// The bundle the user opened, where Finder shows it; `running` when not translocated.
    public let original: URL
    /// What macOS says (F34), stored: never inferred by comparing two spellings of a URL.
    public let isTranslocated: Bool
    /// The disk image `original` lies on; nil anywhere else.
    public let diskImage: DiskImage?
    public init(running: URL, original: URL, isTranslocated: Bool, diskImage: DiskImage?) { fatalError("not implemented") }
}

/// Where this copy stands for an opening by hand (R5, R18, R23). One rule, pure.
public enum Placement: Equatable, Sendable {
    /// Inside /Applications, at any depth, not translocated, whatever the build: its first run starts it at login (R5).
    case installed
    /// A development build anywhere else: it runs where it was built and leaves starting at login alone (R23).
    case development
    /// A release build anywhere else: a disk image, ~/Downloads, ~/Applications, a translocated copy.
    case elsewhere

    public init(build: Build, location: Location, applications: URL = URL(filePath: "/Applications")) {
        // !location.isTranslocated && location.running's standardized path lies under `applications`' → .installed
        //     (component-wise, so /ApplicationsOld is not inside, and a trailing slash never matters)
        // build == .development → .development
        // else → .elsewhere
        fatalError("not implemented")
    }
}

/// What one opening of this process leads to: the whole table, pure (R2-R4, R9, R18, R22, R23).
public enum Route: Equatable, Sendable {
    case runSilently, runWithWindow, askToMove, end

    /// `olderCopyRuns` matters only at login: two login starts converge on the older copy.
    public init(_ opening: Opening, placement: Placement, olderCopyRuns: Bool) {
        // (.atLogin, _, true) → .end;  (.atLogin, _, false) → .runSilently
        // (.byHand, .installed or .development, _) → .runWithWindow;  (.byHand, .elsewhere, _) → .askToMove
        fatalError("not implemented")
    }
}

/// One process start.
public struct Launch: Equatable, Sendable {
    public var opening: Opening
    /// Only on the copy a move just installed: the disk image the mover ran from, ejected once the mover has exited.
    public var diskImageToEject: DiskImage?
    public init(opening: Opening, diskImageToEject: DiskImage? = nil) { fatalError("not implemented") }
}

/// The quit being handled in `applicationShouldTerminate`, as `QuitSignals` classifies it.
public enum QuitRequest: Equatable, Sendable {
    /// Logout, restart, shutdown: the event carried a quit reason, came from loginwindow, or arrived after power-off
    /// was announced.
    case system
    /// The Dock's Quit, AppleScript, Activity Monitor's Quit, another app.
    case other
}

public enum MoveDialog: Equatable, Sendable {
    /// "Trackpad Launcher needs to be in the Applications folder": Move to Applications (default), Quit.
    case asking
    /// The move failed before /Applications changed: the reason, and Quit.
    case failed(reason: String)
}
public enum MoveAnswer: Sendable { case move, quit }
public enum InstallOutcome: Equatable, Sendable { case installed, cancelled, failed(reason: String) }

public struct CopyID: Hashable, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
}
/// Another running Trackpad Launcher process: any build, any place, the menu bar version included.
public struct RunningCopy: Hashable, Sendable {
    public let id: CopyID
    /// Launched before this process, by the adapter's one total order (launch date, a missing date counting as latest,
    /// then pid). At login, this process defers to such a copy.
    public let startedEarlier: Bool
    public init(id: CopyID, startedEarlier: Bool) { fatalError("not implemented") }
}

/// The running Trackpad Launcher processes. Real: SystemRunningCopies. Test: InMemoryRunningCopies.
@MainActor public protocol RunningCopies: AnyObject {
    /// Every other process with this bundle identifier, read now.
    func others() -> [RunningCopy]
    /// Stops each at once without asking: a copy can neither refuse, nor ask its user, nor hang the stop. Calls
    /// `exited` once, on the main actor, when every listed copy has exited; synchronously when none still runs. The
    /// signal is the processes' own termination (KVO on isTerminated), never a wait or a poll.
    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void)
    /// AppKit's terminate for this process; `Lifecycle.shouldEnd` has already agreed (stage `.ending`).
    func endThisCopy()
}

/// Putting this copy into /Applications. Real: ApplicationsInstaller. Test: InMemoryInstaller.
@MainActor public protocol Installer: AnyObject {
    /// Copies this copy into /Applications, replacing any Trackpad Launcher there whatever its version, asking for an
    /// administrator's name and password the way Finder does when this user cannot write there. Nothing there changes
    /// unless the outcome is `.installed`, and never a mix of two copies. Unprivileged, the replace is one atomic step.
    /// With an administrator it is two renames, the old copy moved into the staging folder first: a process killed
    /// between them leaves /Applications without the app, and the next Move installs again. `done` runs once, on the
    /// main actor. The prompt and the copy can block; a test holds `done`.
    func install(then done: @escaping @MainActor (InstallOutcome) -> Void)
    /// Removes the copy the user opened (its original place when translocated), unless it is on a disk image or is the
    /// installed copy itself. A failure (a read-only share) leaves it there (R19).
    func removeOriginal()
    /// Opens the installed copy as by hand, passing the disk image to eject when this copy came from one.
    func openInstalledCopy()
    /// Ejects it; returns at once. A file on it in use leaves it mounted (R19).
    func eject(_ diskImage: DiskImage)
}

/// This app's login item, as the main app's Open at Login entry. Real: SystemLoginItem. Test: InMemoryLoginItem.
@MainActor public protocol LoginItem: AnyObject {
    /// `.enabled`: the next login starts it. Every other status (never registered, the user's off) is off.
    var isOn: Bool { get }
    /// True when registered afterwards, already-registered included; false when macOS refused (the user turned it off
    /// in Login Items, an unsigned build).
    @discardableResult func register() -> Bool
    /// This process keeps running. A no-op when not registered.
    func unregister()
}

/// Starting at login: the one owner of "Trackpad Launcher turns back on only what it turned off itself" (R5, R12,
/// R13, R20, R25). Its one fact is its own key in the app's defaults domain, beside the `settings` record.
/// A development build outside /Applications leaves starting at login alone: every intent is a no-op for
/// `.development`.
@MainActor public final class StartAtLogin {
    public init(item: any LoginItem, defaults: UserDefaults, placement: Placement) { fatalError("not implemented") }

    /// The first run: turn it on and forget any stale fact. A user's earlier off stands: macOS refuses.
    public func enrol() { fatalError("not implemented") }        // item.register(); forget()

    /// Quit, or a move: if it is on now, remember that Trackpad Launcher turned it off, then turn it off.
    public func suspend() {
        // guard item.isOn else { return }
        // remember()            // first: a crash before unregister leaves it on and remembered; resume converges
        // item.unregister()
        fatalError("not implemented")
    }

    /// Opened by hand: turn it back on only if Trackpad Launcher turned it off. The fact stays until macOS accepts.
    public func resume() {
        // guard isRemembered else { return }
        // if item.register() { forget() }     // register first: a crash before forget re-registers, harmlessly
        fatalError("not implemented")
    }
}

/// What this process does as it starts, is opened again and is asked to quit, and how it moves into /Applications.
@MainActor @Observable
public final class Lifecycle {
    /// Every legal situation of the process, and nothing else. Written only by the five intents and two callbacks.
    private enum Stage {
        case idle                                                        // before `launched`
        case replacingOthers(opensWindow: Bool, eject: DiskImage?)       // others stopping; nothing of ours senses
        case resident(Launcher)                                          // gestures run
        case askingToMove(resident: Launcher?)                           // dialog up; a resident keeps its gestures
        case moving(resident: Launcher?)                                 // after Move, until the process ends
        case moveFailed(reason: String, resident: Launcher?)
        case ending                                                      // `endThisCopy` called; every quit passes
    }
    private var stage: Stage = .idle

    /// Derived: `.askingToMove` → `.asking`, `.moveFailed` → `.failed`. The move dialog presenter renders it.
    public var moveDialog: MoveDialog? { fatalError("not implemented") }
    /// Derived: the gesture model once it runs; nil for a copy that only asks or is still stopping others.
    public var launcher: Launcher? { fatalError("not implemented") }

    public init(
        placement: Placement, copies: any RunningCopies, installer: any Installer, startAtLogin: StartAtLogin,
        makeResident: @escaping @MainActor () -> Launcher
    ) { fatalError("not implemented") }

    /// Once, from applicationDidFinishLaunching. A second call does nothing.
    public func launched(_ launch: Launch) {
        // guard case .idle = stage
        // let others = copies.others()
        // switch Route(launch.opening, placement: placement, olderCopyRuns: others.contains(where: \.startedEarlier)) {
        // case .end:           end()
        // case .askToMove:     stage = .askingToMove(resident: nil)   // nothing built, sensed, asked, registered, saved
        // case .runSilently:   replace(others, opensWindow: false, eject: launch.diskImageToEject)
        // case .runWithWindow: replace(others, opensWindow: true, eject: launch.diskImageToEject)
        // }
        fatalError("not implemented")
    }

    /// From applicationShouldHandleReopen.
    public func openedAgain(_ opening: Opening) {
        // switch (stage, Route(opening, placement: placement, olderCopyRuns: false)) {
        // case (.replacingOthers(_, let eject), .runWithWindow): stage = .replacingOthers(opensWindow: true, eject: eject)
        // case (.resident(let launcher), .runWithWindow):        launcher.openedByHand()   // R2: front, restored, focused
        // case (.resident(let launcher), .askToMove):            stage = .askingToMove(resident: launcher)   // R18
        // default: break   // a login start reaching the running copy; the dialog already up; the process leaving
        // }
        fatalError("not implemented")
    }

    /// From applicationShouldTerminate.
    public func shouldEnd(_ request: QuitRequest) -> Bool {
        // switch stage {
        // case .ending: true
        // case .resident(let launcher):
        //     // Every ordinary way to quit exists only while the window is open (R8): close it, keep running.
        //     // With it closed, a quit is the system's or a script's: end, never hold up a logout.
        //     if request == .other && launcher.isWindowOpen { launcher.closeWindow(); false } else { true }
        // case .moving: request == .system
        // case .idle, .replacingOthers, .askingToMove, .moveFailed: true
        // }
        fatalError("not implemented")
    }

    /// The move dialog's buttons.
    public func answer(_ answer: MoveAnswer) {
        // (.askingToMove(let r), .move) → stage = .moving(resident: r); installer.install { installed($0) }
        // (.askingToMove, .quit), (.moveFailed, _) → end()          // R18: nothing changed
        fatalError("not implemented")
    }

    /// The Quit Trackpad Launcher button (R11, R12).
    public func quit() {
        // guard launcher != nil; startAtLogin.suspend(); end()
        fatalError("not implemented")
    }

    private func replace(_ others: [RunningCopy], opensWindow: Bool, eject: DiskImage?) {
        // stage = .replacingOthers(opensWindow: opensWindow, eject: eject)   // before stop: it may call back at once
        // copies.stop(others) { [unowned self] in othersExited() }
        fatalError("not implemented")
    }

    private func othersExited() {
        // guard case .replacingOthers(let opensWindow, let eject) = stage
        // let launcher = makeResident(); launcher.start(); stage = .resident(launcher)
        // if opensWindow { launcher.openedByHand() }
        // if let eject { installer.eject(eject) }            // the mover has exited, so its volume is free
        fatalError("not implemented")
    }

    private func installed(_ outcome: InstallOutcome) {
        // guard case .moving(let resident) = stage
        // .cancelled → end()                                   // R21: nothing moved
        // .failed(r) → stage = .moveFailed(reason: r, resident: resident)
        // .installed:
        //     startAtLogin.suspend()        // hand over before the original goes: a crash leaves it owed, never lost
        //     installer.removeOriginal()
        //     copies.stop(copies.others()) {                    // the copy running from /Applications included (R20)
        //         installer.openInstalledCopy()                  // so this open always starts a fresh process
        //         end()
        //     }
        fatalError("not implemented")
    }

    private func end() { /* stage = .ending; copies.endThisCopy() */ fatalError("not implemented") }
}
```

```swift
// MARK: Launcher.swift: the lifecycle-facing surface after the change (everything else as today)

@MainActor @Observable public final class Launcher {
    public enum Window: Equatable, Sendable {
        case closed
        /// `request` counts openings by hand in this process. Each one brings the window to the front with the keyboard
        /// focus, restoring it when minimised; centring on the pointer's display happens only from `.closed` (R7).
        case open(request: Int)
    }
    public private(set) var window: Window = .closed
    public var isWindowOpen: Bool { window != .closed }

    /// `startAtLogin` replaces `SystemActions.registerLoginItem()`, which leaves the port.
    public init(
        hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
        system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore,
        startAtLogin: StartAtLogin
    ) { fatalError("not implemented") }

    /// Gestures on: wires the adapters, scans, reconciles. Asks nothing, opens nothing, saves nothing: all a login
    /// start does, so a first run waits for the first opening by hand. Call once.
    public func start() { fatalError("not implemented") }

    /// The user opened Trackpad Launcher. The first time in this process: on a first run (no `settings` record),
    /// `startAtLogin.enrol()` and the Accessibility ask when missing, then the first save, both before it (Preserve 1);
    /// on any other run, `startAtLogin.resume()`. Every time: `window = .open(request: n + 1)`, rows, scan.
    public func openedByHand() { fatalError("not implemented") }

    /// Close button, ⌘W, Escape, Close Settings (⌘Q), the Dock's Quit. Gestures keep running.
    public func closeWindow() { fatalError("not implemented") }

    // Deleted: openWindow(), dismissWindow(), Window.heldOpen, the grant ending a hold in reconcile(), and
    // `window = .closed` in fire, swipe, windowSwipe and swap (R15, R16, R17).
}
```

#### Type sketch: LauncherPlatform, LauncherUI

```swift
// ThisCopy.swift: facts about this process, parsed once into Core types. Confines the launch Apple-event keys
// and SecTranslocate* (resolved with dlsym, as LaunchServicesOrder resolves its symbols).
public enum ThisCopy {
    /// `location(of: Bundle.main.bundleURL, …)` over SecTranslocateIsTranslocatedURL /
    /// SecTranslocateCreateOriginalPathForURL (F34) and `DiskImages.image(holding:)` (F35).
    public static func location() -> Location { fatalError("not implemented") }
    /// The test handle: the same composition over injected lookups, so a test drives the translocated, the disk-image
    /// and the trailing-slash cases.
    static func location(
        of bundle: URL, originalIfTranslocated: (URL) -> URL?, diskImage: (URL) -> DiskImage?
    ) -> Location { fatalError("not implemented") }
    /// The `oapp` of a start (read in didFinishLaunching, F1), plus `--eject-disk-image <volume>` from a move.
    public static func launch(event: NSAppleEventDescriptor?, arguments: [String]) -> Launch { fatalError("not implemented") }
    /// A reopen: `.atLogin` only when it carries the login marker; otherwise `.byHand`.
    public static func opening(of event: NSAppleEventDescriptor?) -> Opening { fatalError("not implemented") }
}

// CodeSignature.swift: confines SecCode* / SecStaticCode* / SecRequirement*. The Developer ID requirement F7 probed.
public enum CodeSignature {
    /// SecCodeCopySelf against the requirement. A build not signed for release reads as `.release` when `arguments`
    /// hold `--as-release-build`, so the move and the login rules can be checked by hand without a Developer ID
    /// certificate (F40); a release build ignores the argument.
    public static func buildOfThisProcess(arguments: [String]) -> Build { fatalError("not implemented") }
    /// Any bundle or binary on disk; a test runs it on its own ad-hoc binary and expects `.development`.
    static func build(of url: URL) -> Build { fatalError("not implemented") }
}

// QuitSignals.swift: confines kAEQuitReason and the power-off observer.
@MainActor public final class QuitSignals {
    public init(workspace: NotificationCenter = NSWorkspace.shared.notificationCenter) { fatalError("not implemented") }
    public func request(for event: NSAppleEventDescriptor?) -> QuitRequest { fatalError("not implemented") }
    /// Pure; tested with built descriptors.
    static func request(hasQuitReason: Bool, senderBundleID: String?, afterPowerOff: Bool) -> QuitRequest {
        hasQuitReason || senderBundleID == "com.apple.loginwindow" || afterPowerOff ? .system : .other
    }
}

// SystemRunningCopies.swift: NSRunningApplication by bundle id minus own pid; forceTerminate; KVO isTerminated
// [.initial, .new]; endThisCopy = NSApp.terminate(nil). Confines forceTerminate and `.terminate(`.
extension SystemRunningCopies {
    /// The one start order, a strict total order so two copies always give mirror-image answers: launch date first,
    /// a missing date counting as later than any date, then the lower pid. Pure; a test runs it over pairs.
    static func started(_ a: (launched: Date?, pid: pid_t), before b: (launched: Date?, pid: pid_t)) -> Bool {
        // (a.launched ?? .distantFuture, a.pid) < (b.launched ?? .distantFuture, b.pid)
        fatalError("not implemented")
    }
}
// SystemLoginItem.swift: SMAppService.mainApp; isOn = status == .enabled; kSMErrorAlreadyRegistered → true;
// kSMErrorJobNotFound on unregister ignored. Confines SMAppService.

// ApplicationsInstaller.swift: the Installer adapter. Owns one install: the order below, off the main actor in a
// concurrent function; only `done` hops back. Every file operation goes through BundleInstall.
@MainActor public final class ApplicationsInstaller: Installer {
    public convenience init(location: Location) { fatalError("not implemented") }   // /Applications, the real prompt
    /// Tests: a temp dir for /Applications and a test administrator.
    init(location: Location, applications: URL, administrator: any Administrator) { fatalError("not implemented") }

    public func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
        // TODO:
        // 1. destination = the bundle with this bundle identifier already inside /Applications, if any, else
        //    /Applications/<location.original's name>
        // 2. staged = BundleInstall.stage(location.running, near: destination): a copy in the item-replacement
        //    directory of the /Applications volume, with quarantine cleared on every item (an unquarantined copy is
        //    never translocated); an unreadable source → .failed before anything else
        // 3. if /Applications or destination is not writable by this user:
        //        PrivilegedInstall.swap(staged, into: destination, asideIn: staged's folder, by: administrator)
        //        .cancelled → BundleInstall.discard(staged); .cancelled, nothing touched
        //    else BundleInstall.swap(staged, into: destination): one atomic replace, or a move when there is none
        // 4. any error before the swap → BundleInstall.discard(staged); .failed(localizedDescription), destination untouched
        fatalError("not implemented")
    }
    /// BundleInstall.removeOriginal(location.original), unless it is on a disk image or is the destination.
    public func removeOriginal() { fatalError("not implemented") }
    public func openInstalledCopy() { fatalError("not implemented") }   // openApplication(activates, ["--eject-disk-image", volume])
    public func eject(_ diskImage: DiskImage) { fatalError("not implemented") }   // DiskImages.eject
}
// BundleInstall.swift: every unprivileged file operation, over URLs a test points at temp dirs: stage, swap,
//   discard, removeOriginal (a failure is tolerated). Confines copyItem(, moveItem(, replaceItemAt(, removeItem(
//   and quarantinePropertiesKey.

// PrivilegedInstall.swift: the administrator path (R21).
/// The one privileged call, placed below the script so a test runs the real script. Real: `AuthorizationAdministrator`
/// (AuthorizationCreate, AuthorizationCopyRights with execute and interaction allowed, then
/// AuthorizationExecuteWithPrivileges resolved with dlsym, F32). Test: runs the same command unprivileged.
protocol Administrator: Sendable {
    /// Asks for an administrator's name and password the way Finder does, then runs `/bin/sh -c script sh arguments…`
    /// as root. Blocks; called off the main actor.
    func run(script: String, arguments: [String]) -> AdministratorResult
}
enum AdministratorResult: Equatable { case ran(exitStatus: Int32), cancelled, failed }
enum PrivilegedInstall {
    /// The script takes the paths as "$1" (destination), "$2" (staged) and "$3" (aside, inside the staging folder),
    /// never interpolated: move an existing destination to the aside path; move the staged copy in, and when that
    /// fails move the aside copy back and exit non-zero (`.failed`, /Applications as it was); then remove the aside
    /// copy, ignoring a failure there, and exit zero (`.installed`). So a status matches what /Applications holds. Only
    /// a kill between the two moves leaves /Applications without the app and the old copy in the staging folder,
    /// never inside /Applications.
    static let script: String = { fatalError("not implemented") }()
    static func swap(_ staged: URL, into destination: URL, asideIn folder: URL, by administrator: any Administrator)
        -> InstallOutcome { fatalError("not implemented") }
}
// Confines AuthorizationExecuteWithPrivileges and AuthorizationCopyRights.
// DiskImages.swift: statfs → f_mntfromname → DADiskCopyDescription → device model "Disk Image" (F35);
//   eject = FileManager.unmountVolume(at:options: .allPartitionsAndEjectDisk) { _ in } (a push). Confines statfs,
//   DADisk and unmountVolume.

// RunningAppsReader.swift (changed): frontmost = Self.frontmost(activePID:activeEntry:ownPID:apps:).
/// Never this process. While it is active (its settings window in front), the app that was in front before it: the
/// first ⌘-Tab app, an order this process never enters (LaunchServices drops its pid; the tracker never notes it). Pure.
static func frontmost(activePID: pid_t?, activeEntry: AppEntry?, ownPID: pid_t, apps: [AppEntry]) -> AppEntry? {
    guard let activePID else { return nil }
    return activePID == ownPID ? apps.first : activeEntry
}

// LauncherUI
/// The settings window, its Dock icon and main menu, and both switchers' presenters (taken over from MenuBarShell,
/// with the first synchronous icon pass). Renders `launcher.window`; the only caller of setActivationPolicy:
/// .regular exactly while the window is open, minimised included (R6).
/// Main menu: the app menu with "Close Settings" ⌘Q in Quit's place (R8); Window: Minimize ⌘M, Close ⌘W.
public final class SettingsShell: NSObject, NSWindowDelegate {
    public init(launcher: Launcher, quit: @escaping () -> Void) { fatalError("not implemented") }
}
/// Titled ("Trackpad Launcher"), closable, miniaturisable, not resizable, normal level; today's glass content.
/// Escape: `cancelOperation` → closeWindow; an open picker menu's tracking consumes Escape first (F45).
final class SettingsWindow: NSWindow {}
/// Renders `lifecycle.moveDialog` as an NSAlert run modally after activating the app (an accessory app activates
/// without a Dock icon, as for today's chooser) and sends the answer. Confines runModal.
public final class MoveDialogPresenter {
    public init(lifecycle: Lifecycle) { fatalError("not implemented") }
}
```

#### Module map

| Module | Change |
|---|---|
| LauncherCore | **New** `Lifecycle.swift`: `Lifecycle`, `StartAtLogin`, `Route`, `Placement`, `Location`, the values above, and the `RunningCopies`, `Installer` and `LoginItem` ports. **Changed** `Launcher`: `start()`, `openedByHand()`, `closeWindow()`, public `window`. `SystemActions.registerLoginItem` is removed. `Copy` gains the Quit label, "Close Settings" and the move dialog's strings. The "never active" doc on `RunningApps.frontmost` is updated. |
| LauncherPlatform | **New** `ThisCopy`, `CodeSignature`, `QuitSignals`, `SystemRunningCopies` (with its pure start order), `SystemLoginItem`, `ApplicationsInstaller` with `BundleInstall`, `PrivilegedInstall` (with the internal `Administrator` seam and its real `AuthorizationAdministrator`), `DiskImages`. **Changed** the `RunningAppsReader` frontmost rule; `WorkspaceActions` loses `SMAppService`; the stale "never active" comments (`RunningAppsReader`, `LaunchOverlay`, `AnimationTuner`). |
| LauncherUI | **Replaced** `MenuBarShell` by `SettingsShell`, `LauncherPanel` by `SettingsWindow`, `LauncherView` by `SettingsView`, which ends with the Quit button: `.glassProminent`, `.tint(.red)`, `.buttonBorderShape(.capsule)`, `.controlSize(.regular)`, trailing-aligned below every notice (R10). Other… becomes `beginSheetModal(for:)` and leaves the window open (R16). `openSettings` only opens the pane (R17). **New** `MoveDialogPresenter`. **Deleted** `StatusIcon`. `SwitcherPresenter.dockLocation` gains the own-pid filter (R15). |
| App target | `AppDelegate`, as in Usage. DEBUG: the animation tuner opens with the first opening by hand and never drives the Dock. |
| `project.yml` | Keeps `LSUIElement: true`; adds `NSSupportsSuddenTermination: true`. |
| Scripts | `release.sh` builds the disk image; `Scripts/release/dmg-background.png` holds the drag cue (outside `assets/`, whose PNGs are bundled into the app). |
| Tests | `LifecycleWorld`: a real `Lifecycle` building a real `Launcher` over today's in-memory adapters, plus `InMemoryRunningCopies` (`others`, `stopped`, `letStoppedCopiesExit()`, `hasEnded`), `InMemoryInstaller` (holds `done`; records `removeOriginal`, `openInstalledCopy` and `eject` in one ordered log shared with the login item) and `InMemoryLoginItem` (`isOn` settable, standing for the user's Login Items choice). The tests `how.md` lists as flipping are updated. |

**The test seam is `Lifecycle`, with `Launcher` behind it.** Every R2-R5, R9, R11-R14 and R18-R23 scenario runs there, synchronously. A test holds a handle on every signal it cannot produce for real: how a process was opened, the quit request, the dialog's answer and the user's Login Items choice are values; copies exiting is withheld and released; the administrator and the copy are held by not calling `done`. Nothing in the design waits on time, so no clock is needed. The platform boundary is tested at its own seams: `ThisCopy` parsing and `QuitSignals.request` over built descriptors, `Placement` and `Route` as tables, `CodeSignature.build(of:)` over the test's own ad-hoc binary, the pure frontmost rule, and `BundleInstall` over temp directories (staging, quarantine cleared, atomic replace, a read-only original left in place). Checked by hand and recorded in the slices' acceptance: a real login start (F2), logout and restart with the window open (F17-F19), the Dock's real Quit, a Finder drag over a running copy, Escape inside an open picker (F45), a quarantined disk image and a translocated move (F38), a standard account's prompt (F36), the eject, and notarisation.

**Requirement coverage.**

| Requirements | Carried by |
|---|---|
| R1 | `StatusIcon` and the status item are deleted; the trackpad settings notice is unchanged. |
| R2, R3, R4 | A reopen reaches `openedAgain`; any second process takes `Route.runWithWindow` or `askToMove`; `RunningCopies.stop` before gestures. |
| R5 | `Launcher.openedByHand` on a first run, with `StartAtLogin.enrol`. |
| R6, R7 | `SettingsShell` rendering `Launcher.Window`. |
| R8 | `closeWindow` from every window control, `Lifecycle.shouldEnd`, `QuitSignals`, sudden termination. |
| R9, R22 | `Opening.atLogin` → `Route.runSilently`; `disableRelaunchOnLogin`. |
| R10, R11 | The Quit button → `Lifecycle.quit`. |
| R12, R13, R25 | `StartAtLogin`. |
| R14 | `SMAppService.mainApp` is never relaunched (F23); nothing else starts the app. |
| R15, R16, R17 | No effect closes the window; the frontmost rule; the sheet; the panes. |
| R18-R21 | `Route.askToMove`, `Lifecycle.answer`/`installed`, `Installer`. |
| R23 | `Placement.development` from `CodeSignature`. |
| R24 | `release.sh`. |

**`release.sh` (R24)**, one command from a clean checkout:

1. Preflight: a Developer ID Application identity, `NOTARY_PROFILE`, xcodegen.
2. `xcodegen generate`.
3. Archive and export with the developer-id method (as today).
4. Verify the signature authority and the runtime flag (as today).
5. Notarise the app as a zip, then staple and validate the app, so a copy dragged out of the image opens offline (F39).
6. Stage `TrackpadLauncher.app` beside an `Applications` symlink and `.background/dmg-background.png`.
7. `hdiutil create -format UDRW` from the stage, attach it, and lay it out with a Finder `osascript`: icon view, the background with its drag arrow, both icons' positions, the window's bounds.
8. Detach, then `hdiutil convert -format UDZO`.
9. `codesign --timestamp -s "Developer ID Application"` the image.
10. `notarytool submit --wait` the image, then `stapler staple` and `stapler validate` it.
11. `spctl --assess --type open --context context:primary-signature` the image and `spctl --assess --type execute` the app.

The output is `build/release/TrackpadLauncher.dmg`. No `--deep`, no entitlements, the main executable signed last by Xcode (F41).

**Docs and the source scan.**

- `docs/domain-model.md`:
  - *Trackpad Launcher*: "a macOS background app that brings apps to the front with trackpad gestures; it shows in the Dock only while its settings window is open".
  - *Launcher window* → *Settings window*, in the heading and every mention: an ordinary window opened by opening the app, closed only by its own controls, ⌘Q and the Dock's Quit, ending with the Quit button.
  - *Frontmost app*: drop "Trackpad Launcher is active only when macOS makes it so…"; while Trackpad Launcher itself is active, the frontmost app is the most recently used running app, the one in front before it, and a slide up or down is no window swipe. The rest of the "when there is none" tail stays for no active app.
  - *Swap* and *Launch animation setting* lose "the launcher window closes".
  - New entries: *Opened by hand* and *Login start*, *First run*, *Starting at login*, *Move dialog*, *Development build*, *Quit Trackpad Launcher*.
- `docs/architecture.md`:
  - Shape: two observable models; `Lifecycle` owns process start, reopen, quit and the move, and builds `Launcher`. At most one Trackpad Launcher runs gestures: an opening by hand stops every other copy and waits for their exit. LauncherUI is the settings window shell and the move dialog. The platform list gains Security (code signature, authorization, two private translocation functions via `dlsym`) and DiskArbitration.
  - Concurrency: the first scan and icon pass run "before gestures run and before the window can show"; the push list gains Apple events, copies' termination, `willPowerOff`, the install's and the eject's completions.
  - Privacy: the launcher window's outside-click monitor goes; "no files written other than settings in UserDefaults, and the app's own bundle into /Applications when the user chooses Move to Applications".
  - Distribution: a notarised, stapled disk image.
- `docs/performance.md:8`: opening the perf build stops other copies by itself; "menu window" becomes "settings window".
- `docs/product-overview.md`: per the Solution above.
- `SourcePolicyTests`: drop `MenuBarShell.swift` from `addGlobalMonitorForEvents`; confine `SMAppService` to `SystemLoginItem.swift`; `forceTerminate` and `.terminate(` to `SystemRunningCopies.swift`; `setActivationPolicy` to `SettingsShell.swift`; `disableRelaunchOnLogin` to `TrackpadLauncherApp.swift`; `keyAELaunchedAsLogInItem`, `currentAppleEvent` and `SecTranslocate` to `ThisCopy.swift` and, for `currentAppleEvent`, `TrackpadLauncherApp.swift`; `kAEQuitReason` to `QuitSignals.swift`; `SecCode`, `SecStaticCode`, `SecRequirement` to `CodeSignature.swift`; `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(`, `quarantinePropertiesKey` to `BundleInstall.swift`; `AuthorizationExecuteWithPrivileges`, `AuthorizationCopyRights` to `PrivilegedInstall.swift`; `statfs`, `DADisk`, `unmountVolume` to `DiskImages.swift`; `runModal` to `MoveDialogPresenter.swift`.

### Synthesis decision

- **Base: candidate-1** (`.temp/architect/candidate-1.md`), a separate `Lifecycle` owner that builds `Launcher` lazily. It carries every requirement through types, including the two R18 scenarios candidate-2 got wrong (a login-started copy outside /Applications opened by hand, and nothing but the dialog showing), and it orders the move so an administrator's cancel changes nothing. Its rule that every ordinary quit exists only while the window is open makes logout safe without the unprobed signals. A future maintainer finds each rule in one place: routing, reopen and quit in `Lifecycle`, login state in `StartAtLogin`, first run in `Launcher.openedByHand`.
- **Cross-judge: agreed**, recommending candidate-1, scored 5/5/5/5/4/4 against candidate-2's 3/4/3/4/3/4. It found candidate-2's reopen routed to the window (R18), its move stopping the running copy before the admin prompt (R21), its login flag in the shared `settings` record (stale saves, dropped by older builds), its sender-based login fallback undercut by F1, and a `Copy` name collision.
- **Grafted from candidate-2:**
  - The routing as one pure table: `Route`, used by launch and reopen alike.
  - One boundary value for where the copy is: `Location`, which `Placement` and the installer share.
  - The installer split into `BundleInstall`, `PrivilegedInstall` and `DiskImages`, with their source-scan rows (`runModal`, `currentAppleEvent`, `statfs`, `DADisk`, `SecRequirement`).
  - `CodeSignature.build(of:)`, so the development-build test is portable.
  - A committed disk-image background.
  - Its open questions on the Accessibility grant after a move and on the app icon.
- **Re-derived in synthesis:**
  - `Placement` gains a third case, `development`, for a development build outside /Applications, which leaves starting at login alone. This replaces candidate-1's "registers its DerivedData path" and candidate-2's partial skip. Any copy inside /Applications is `installed` whatever its build, because R5 binds every first run from /Applications (a test-planner finding).
  - "Installed" means anywhere inside /Applications, not directly in it, because R18 asks only about copies outside /Applications. Both candidates had this wrong.
  - The disk-image background lives under `Scripts/release/`, because `assets/*.png` are bundled into the app.
  - Candidate-1's release-time version stamping is dropped. A post-fan-out check (`.temp/architect/checks/same-version-replace/output.txt`) showed that LaunchServices starts a new process for a bundle replaced at the same path even with the same `CFBundleVersion`, so R3 does not need it, and no requirement asks for it.
- **Rejected from candidate-2:**
  - Lifecycle folded into `Launcher`: a copy that only asks would build every sensing adapter (F11), and it adds a public `Phase` that leaks its stages.
  - Asking peers to quit by classifying the sender: a peer can refuse or hang, and future versions would be bound to honour it.
  - `FrontmostApp` activation memory for R15: an extra observer and state, Spotlight could become "the app before", and it claimed a window swipe that `kAXRaiseAction` cannot do while another app is active (F29).
  - The mover idling in `.replaced` until the installed copy stops it: it never ends if that copy fails to start.
  - Sudden termination disabled while the install runs (first grafted, then dropped on the test planner's finding): a logout's quit still reaches `shouldEnd`, which ends a moving process (R8), so it protected nothing. The move's order carries the guarantee instead.
  - Deriving the disk image to eject from the stopped peers: it is implicit, and it ejects for any peer on an image. The explicit one-shot argument stays.

### Tradeoffs accepted

- We accept stopping other copies with `forceTerminate()`, with no teardown, in exchange for a stop that cannot be refused, hung or confused with the Dock's Quit, and no protocol between versions. Nothing needs saving (F21).
- We accept that two copies opened by hand at the same instant stop each other and the user opens it again, in exchange for no election or lock. At login, where simultaneous starts are real, the older copy wins.
- We accept that while Trackpad Launcher is active the frontmost app is the most recent ⌘-Tab app, so a menu bar app that was in front is not it and a slide is no window swipe, in exchange for no new state, and Spotlight never counting as the app before.
- We accept that a login start does no first-run work and the first opening by hand does it, in exchange for a login start that is always silent.
- We accept that a development build opened by hand stops the installed copy, and that outside /Applications it never touches starting at login, in exchange for R2 holding strictly, one placement rule and no build folder ever registered. On a developer's Mac whose first run was such a build, the first run is spent without registering, so the installed copy never registers by itself.
- We accept a development-only `--as-release-build` argument, in exchange for checking the move and the login rules by hand before a Developer ID certificate exists. A release build ignores it.
- We accept that a copy which survives `forceTerminate()` (only one stuck in the kernel, such as on a hung network share) leaves the opened copy waiting with nothing shown or recognised until it exits, in exchange for no deadline (timers are banned) and no copy ever running gestures beside another.
- We accept that any quit while the settings window is closed ends the app (AppleScript, Activity Monitor), in exchange for a logout that can never be held up in the common case.
- We accept a deprecated `AuthorizationExecuteWithPrivileges`, resolved by `dlsym`, and a gap between the privileged swap's two renames in which /Applications holds no copy (the old one waits in the staging folder), in exchange for a Finder-like administrator prompt with no entitlement and no helper.
- We accept a second key in the defaults domain, in exchange for each key having one writer and a move never spending a first run.
- We accept that a translocated copy sitting in /Applications shows the move dialog, in exchange for it re-installing itself without quarantine instead of running, and registering for login, from a hidden mount.
- We accept a Finder script at release time for the disk image's layout (it needs the release machine's Automation permission for Finder once), in exchange for no committed `.DS_Store` and no third-party tool.

### Alternatives considered

- **Decide in the AppKit delegate with pure helpers, no `Lifecycle`.** The interface is smaller, but the sequencing that R2, R18 and R21 hinge on would live in the untested app target (`why.md` Risk 9): wait for other copies before sensing, ask before building anything, install before handing over the login item.
- **Fold the lifecycle into `Launcher`, started by a `launch(_:)` intent.** It keeps one model, but `Launcher` exists only with its sensing adapters and its disk scan (F11). A copy that only asks must not build them, and a running copy must still be able to ask, so the owner of the decision has to exist before the gesture model and beside it.
- **Hand over with a quit Apple event that the running copy honours from a peer.** It exposes a sender-pid protocol to every future version, rests on sender resolution, and leaves the new copy waiting forever on a refusing or hung copy, with no timeout allowed.
- **Derive "Quit turned it off" from `.notRegistered` on a later run.** It removes the key, but it cannot be told apart from a failed registration, a moved path or a user's removal from the list (F25).
- **Remember the last activated app other than this one, for R15.** The open from Spotlight or Launchpad itself becomes "the app before", and it adds an always-on observer for one edge case.
- **`NSWorkspace.requestAuthorization(to: .replaceFile)`.** It is the public API, but it needs the Privileged File Operation entitlement Apple grants on request (F31).
- **`#if DEBUG` as the development-build rule.** It is trivial, but it calls the perf build a release, which would then move itself out of its build folder (F8).

### Open questions and risks

1. **The login marker on macOS 26.** Does an `SMAppService.mainApp` login start still carry `keyAELaunchedAsLogInItem` (F2)? R9 and R22 rest on it. If it does not, should the login item become an `SMAppService.agent` that passes `--launched-at-login`? That stays behind `LoginItem` and `ThisCopy` and changes nothing else, but the item would then show under *Allow in the Background* rather than *Open at Login*.
2. **R15's reading.** Is "the most recently used ⌘-Tab app, and no window swipe while Trackpad Launcher is active" the intended reading of R15 and the glossary's *Frontmost app*?
3. **Development builds.** Is it right that one opened by hand stops the installed copy, and that outside /Applications it never registers or unregisters starting at login?
4. **Logout with the window open.** Do sudden termination, `kAEQuitReason`, the loginwindow sender and `willPowerOff` behave as assumed (F17-F19)? This needs an end-to-end check before release.
5. **What Background Task Management keys a main-app item by.** Path or bundle identifier? The answer decides whether a Finder replace keeps the item (R25), and whether the move's hand-over makes macOS show "login item added" again. Every path converges, but the manual check should record which.
6. **The Accessibility grant after a move.** Does it follow the copy into /Applications (F38)? If not, the installed copy's later runs only show the hint, because R5 forbids asking again.
7. **No app icon.** The Dock (R6), the move dialog and the disk image (R24) will all show the generic icon. Who supplies one?

### Next implementation step

Slice S1: write `LifecycleWorld` and, test-first from T1-T11, `Lifecycle`'s `launched`, `openedAgain`, `shouldEnd` and `quit` over the resident stages, with `Launcher.start()`/`openedByHand()`/`closeWindow()` and `StartAtLogin.enrol()` behind them; then the `AppDelegate` and `SettingsShell` that replace the menu bar shell.

## Testing Decisions

### Strategy

The lifecycle is proven at one high seam: `Lifecycle`, with the real `Launcher` it builds behind it. A new `LifecycleWorld` in `LauncherCoreTests` drives it synchronously. It sits beside `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`) and follows `PersistenceTests` and `AccessibilityTests`, whose hooks read the store at the moment of an effect. It observes everything the app delegate forwards and everything a process leaves behind: `lifecycle.launcher`, `lifecycle.moveDialog`, `launcher.window`, the trackpads' runs and taps, the Accessibility asks, the defaults suite's persistent domain, the login item's status and calls, the copies stopped, the installer's calls, and whether the process ended. It misses AppKit. There is no LauncherUI test target, so the Dock icon, ⌘-Tab, centring, the sheet, the menus and the alert are checked by hand. So are real Apple events, logins, processes, `SMAppService`, translocation, disk images, the administrator prompt and notarisation, as the grounding index's "Manual or E2E only" list says.

The existing `World` stays the seam for the gesture effects that now leave the window open (R15). The tests `how.md` lists as flipping keep their feedback assertions and expect the window still open. `World` tests that relied on `start()`'s first-launch branch call `openedByHand()` instead.

The platform boundary is tested at its own seams, as `RunningAppsReaderTests` does. `Placement` is a table in `LauncherCoreTests`. `LauncherPlatformTests` covers:
- the pure rules: `RunningAppsReader.frontmost`, `QuitSignals.request` and `SystemRunningCopies.started(_:before:)`;
- `ThisCopy`, over built `NSAppleEventDescriptor`s and through `location(of:originalIfTranslocated:diskImage:)` with injected lookups;
- `CodeSignature`, checked against `codesign -dvv`;
- `ApplicationsInstaller` and `PrivilegedInstall` over temp directories, checked against a fixture bundle's manifest and `/usr/bin/xattr`. A test `Administrator` runs the real script without privileges.

`SourcePolicyTests` gains the design's rows.

Only the boundaries the grounding index says a test cannot produce are faked: how a process was opened, other processes, `SMAppService`, the installer and the administrator at the `Lifecycle` seam, TCC, and the trackpads. Everything we own runs for real, including `UserDefaults` and `FileManager` over a throwaway suite and temp directories.

`LifecycleWorld` models one Mac:
- **What outlives a process.** One throwaway defaults suite holding the `settings` record and `StartAtLogin`'s key, plus `InMemoryLoginItem`, `InMemoryPermissions` (grants and asks) and the fixture apps. `InMemoryLoginItem` is never registered, on, or off by the user's choice. F25 leaves open how macOS reports that choice, so it models both ways: `register()` refused (`.requiresApproval`), or accepted (`.notRegistered` after a removal).
- **A process.** `start(_:placement:others:)` builds a `Lifecycle` with its own `InMemoryRunningCopies` and `InMemoryInstaller`. Its `makeResident` builds a real `Launcher` over fresh in-memory sensing adapters and counts `residentsBuilt`. `login()` is macOS at login: it starts a process at login only while the login item is on. A process dropped without an intent has crashed or been force-quit.
- **Withheld pushes and held calls.**
  - `stop` records `stopped` and holds `exited` until the row lets each copy exit, one at a time or all at once.
  - A copy can have exited before `stop` runs. Then `stop` calls back inside itself, as KVO's `.initial` does.
  - An exit can be delivered twice.
  - `endThisCopy()` does what `NSApp.terminate` does: it asks `shouldEnd(.other)` and records `hasEnded` only on yes.
  - `InMemoryInstaller` holds `done` until the row releases an `InstallOutcome`.
  - Openings, quit requests and the dialog's answers are values the row passes.
- **Every crash point.** One ordered effect log is shared by the login item, the installer, the copies, the Accessibility ask and the first save. It snapshots what outlives a process before and after each effect, and `LifecycleWorld(restoring:)` builds a Mac from any snapshot. A guarantee that must hold however the process ends is checked at every point between two writes, which covers any random kill.
- **History.** The state after each intent and each released callback. That is every state the shell can render, since `Observations` delivers on later turns.

No clock is owned. The design has no timer, deadline or retry, and every wait is a push the row withholds. The existing timer bans in `SourcePolicyTests` keep a timer from turning a row green. A copy that survives `forceTerminate()` is an accepted tradeoff, so no row tries to make it converge. T14 shows only that nothing of the opened copy runs until every stopped copy has exited.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R4, R14 | `Lifecycle` (`LifecycleWorld`) | Given a settings record with Arc on the 1-finger gesture, Accessibility granted, the login item on and no other copy (the previous one crashed or was force-quit); when this copy is `launched(Launch(opening: .byHand))` from /Applications; then one resident is built and started, `launcher.window == .open(request: 1)`, nothing is asked, registered or stopped, and `tap(1)` brings Arc to front with the gesture haptic; a second `launched` changes nothing (`residentsBuilt == 1`, request 1). | R4 scenario "After a crash" ("gestures work again and the settings window opens"); R14 ("or when the user opens it"); Arc from the seeded record. |
| T2 | R2, R6, R7, R8 | `Lifecycle` | Given a login-started resident with Arc on the 2-finger gesture and its window closed; when `openedAgain(.byHand)` runs three times (Spotlight; Finder with the window behind Safari; Spotlight with it minimised), then `launcher.closeWindow()` (close button, ⌘W, Escape, *Close Settings*), then `tap(2)`, then `openedAgain(.byHand)`; then the window's history is `closed, open(1), open(2), open(3), closed, open(4)`, there is one resident and nothing stopped throughout, and `tap(2)` with the window closed brings Arc to front. | R2 scenarios 1-3 (the same window comes to the front, restored, no second window); R6 scenario "Closing the window"; R7 ("every time it opens"). |
| T3 | R9 | `Lifecycle` | Given a record with Arc on the 1-finger gesture, Accessibility missing and the login item on; when `launched(.atLogin)`, then `tap(1)`; then after every step the window is `.closed` and `moveDialog == nil`, nothing was asked, the login item saw no call, the record's bytes equal the seeded bytes, and `tap(1)` brings Arc to front. | R9 scenarios 1 and 3. |
| T4 | R5, R9 | `Lifecycle` | Given no settings record and Accessibility missing; when `launched(.atLogin)`; then gestures run, the window stays closed, and nothing is asked, registered or saved (`store.load() == nil`); when `openedAgain(.byHand)`; then the login item is registered and Accessibility asked once, both while the store still loads nil, then the record is saved and the window is `.open(request: 1)`. | R9 (silent at login); R5 (the first opening by hand registers, asks and opens); `why.md` Preserve 1. |
| T5 | R5 | `Lifecycle` | On a Mac with no record and no login item: (a) with Accessibility missing, `launched(.byHand)` registers and asks while the store loads nil, then saves; the window is `.open(request: 1)` with every row unassigned and the login item on; assigning Arc to the 1-finger gesture, then `tap(1)`, brings Arc to front; a second process opened by hand asks and registers nothing more; (b) with Accessibility granted: no ask, the window opens; (c) in a later process with Accessibility revoked: no ask, the window opens, `isAccessibilityGranted == false` (the hint shows). | R5 scenarios 1-3; Preserve 1. |
| T6 | R11 | `Lifecycle` | Given a resident with its window `.open(request: 1)`; when `quit()`; then the process has ended: the terminate that `endThisCopy()` starts asks `shouldEnd(.other)` with the window still open, and the answer is yes. | R11 ("stop Trackpad Launcher at once, with no confirmation"). |
| T7 | R8 | `Lifecycle` | Given a resident with Arc on the 3-finger gesture, Notes on the 2-finger gesture and the window open; when `shouldEnd(.other)` (the Dock's Quit, also while the *Other…* chooser is up); then it answers false, the window is closed, the process keeps running, the 2-finger gesture keeps Notes, and `tap(3)` brings Arc to front; with the window closed, `shouldEnd(.other)` answers true. | R8 scenarios "Quit from the Dock" and "Closing the window while choosing an app with *Other…*"; the design's accepted tradeoff for a quit while the window is closed. |
| T8 | R8 | `Lifecycle` | For each stage S1's process can be in (a resident with the window closed, a resident with it open, an ending process): `shouldEnd(.system)` answers true and leaves the window as it was. T17 and T32 add the stages later slices bring. | R8 ("Logging out, restarting and shutting down MUST still end Trackpad Launcher without the user being asked"). |
| T9 | R2, R4, R9 | `ThisCopy` | Over built descriptors: `launch(event:arguments:)` of an `aevt/oapp` whose `keyAEPropData` is `keyAELaunchedAsLogInItem` → `.atLogin`; of an `oapp` without it → `.byHand`; of nil → `.byHand`; `opening(of:)` of an `aevt/rapp` → `.byHand`, of one with the marker → `.atLogin`, of nil → `.byHand`. | SDK `AERegistry.h:1052` (`'lgit'`); the by-hand `oapp` and the reopen's `rapp` as the lifecycle probe recorded them (F1, F4). |
| T10 | R8 | `QuitSignals` | `request(hasQuitReason:senderBundleID:afterPowerOff:)` over all eight combinations, with `com.apple.loginwindow` and `com.apple.dock` as senders: `.system` exactly when one of the three holds; `request(for:)` of a built `aevt/quit` whose `kAEQuitReason` is each of `kAEQuitAll`, `kAEShutDown`, `kAERestart`, `kAEReallyLogOut` → `.system`; without a reason → `.other`; nil → `.other`; once `NSWorkspace.willPowerOffNotification` is posted to the injected `NotificationCenter`, a quit without a reason → `.system`. | SDK `AERegistry.h:602`, `AppleEvents.h:67`; F15 (a user's quit carries no reason); F19. |
| T11 | R1, R7, R14 | `SourcePolicyTests` | New banned rows: `NSStatusBar` and `NSStatusItem` (R1); `SMAppService.agent`, `SMAppService.daemon`, `SMAppService.loginItem` and `SMLoginItemSetEnabled` (R14: nothing relaunches the app); `addGlobalMonitorForEvents` confined to `BounceOverlay.swift` alone (R7: no outside-click close); the design's confinements for `SMAppService`, `setActivationPolicy`, `disableRelaunchOnLogin`, `keyAELaunchedAsLogInItem`, `currentAppleEvent` and `kAEQuitReason`. | R1, R7, R14; the design's "Docs and the source scan" list. |
| T12 | R15 | `Launcher` (`World`) | Given the window opened by `openedByHand()`; when each effect fires (a 2-finger gesture for a running app, a gesture for an app with no process, a swipe lifted on another app, a window swipe lifted on another window with Safari frontmost and two windows, a swap); then each plays exactly the haptic, bring to front, launch animation or bounce its existing test asserts, and the window is still `.open(request: 1)`. | R15 scenario 1; the feedback expectations of the tests `how.md` lists as flipping (`LauncherTests`, `LaunchBounceFiringTests`, `SwapTests`, `SwitcherOnScreenTests`, `WindowSwitchingTests`). |
| T13 | R15 | `RunningAppsReader.frontmost` | This process active with ⌘-Tab apps `[Safari, Mail]` → Safari; this process active with no apps → nil; another process active → its entry, also when it is not among the apps (a menu bar app); no active app → nil. | R15 scenario 2 ("the row the user would get with Safari in front"); the glossary's *Frontmost app*. |
| T14 | R2, R3 | `Lifecycle` | Given another copy that started earlier (the menu bar version, another build, or this build from another place) and a record with Arc on the 1-finger gesture; when this copy is `launched(.byHand)`; then that copy is stopped, and until the row lets it exit, `launcher == nil`, `residentsBuilt == 0`, the trackpads never ran, the window never opened, and nothing was asked or registered; once it exits, one resident runs with the window `.open(request: 1)` and `tap(1)` brings Arc to front. | R2 ("At most one ... at any moment"); R3 scenario (one process afterwards, the new version). |
| T15 | R2 | `Lifecycle` | Given two other copies (the menu bar version and a copy in ~/Applications/Tools); when `launched(.byHand)`; then both are stopped at once; after the first exits, nothing is built and the trackpads have not run; after the second exits, the resident runs with its window open. | R2 (at most one; two copies is the boundary above T14's one and T1's none). |
| T16 | R2, R4 | `Lifecycle` | (a) A listed copy has exited by the time `stop` runs: `stop` calls back inside itself, and the resident and its window exist when `launched` returns; (b) the exit push arrives twice: one resident, the window `.open(request: 1)`. | The `RunningCopies.stop` contract ("synchronously when none still runs"; KVO's `.initial`); R4. |
| T17 | R2, R8, R9 | `Lifecycle` | Given a login start waiting for a copy that started later: (a) `openedAgain(.byHand)` during the wait → once the copy exits, the window is open; (b) with no reopen, the window stays closed; (c) `openedAgain(.atLogin)` during the wait → the window stays closed; (d) `shouldEnd(.system)` during the wait answers true. A resident's `openedAgain(.atLogin)` leaves its window closed. | R2 scenario 1 (opened from Spotlight → the window); R9 (a login start is silent); R8 (logout). |
| T18 | R2, R9 | `Lifecycle` | Two login starts: the process whose `others` holds a copy that started earlier ends at once, building and stopping nothing; the one whose `others` holds a copy that started later stops it and, once it exits, runs gestures with no window. | R2 (at most one); R9; the design's accepted tie-break (the older start wins). |
| T19 | R2, R9 | `SystemRunningCopies.started(_:before:)` | Over pairs of (launch date, pid): the earlier date comes first; a missing date comes after any date; equal dates, or two missing dates, fall to the lower pid; no copy comes before itself; for any two distinct copies, exactly one of `started(a, before: b)` and `started(b, before: a)` holds. | The order documented on `RunningCopy.startedEarlier` (launch date, a missing date latest, then pid); strictness is what two login starts need to give mirror-image answers (R2). |
| T20 | R11, R12 | `Lifecycle` | Given a resident with the window open, the login item on and Arc on the 1-finger gesture; when `quit()`: the login item is off, the suite holds a key beside `settings`, and the process ended; `login()`: no process starts; opened by hand (a new process): the window opens, the login item is on, only `settings` remains in the suite, and Arc is still assigned; `login()`: a process starts, its window closed throughout, and `tap(1)` brings Arc to front. | R12 scenarios 1-2. |
| T21 | R12, R13, R25 | `Lifecycle` | For each way macOS may report the user's off (`register()` refused; `register()` accepted after a removal): (a) off, then opened by hand (this also stands for a newer version installed by Finder and opened, since a record exists) → no `register` in the login item's whole log, still off; (b) off, Quit, then opened by hand → no call at all in the log, still off; (c) off, back on, Quit, then opened by hand → on. | R13 scenarios 1-4; F25 (disputed, so both readings). |
| T22 | R25, R9 | `Lifecycle` | Given the record the menu bar version wrote (literal bytes in today's format, all five gestures assigned, Left thumb), its login item on and no `StartAtLogin` key; when `launched(.atLogin)`: no window, no ask, no login-item call, the record's bytes unchanged, and each `tap(n)` brings its app to front; opened by hand later: the window opens, nothing is asked, and the login item is still on with no call. | R25 scenario; F24 (the menu bar version registered on its first run); the precedent `settingsSavedInTheCurrentFormatStillLoad`. |
| T23 | R5, R12, R13 | `Lifecycle`, every crash point | For each run (Quit with the login item on; the opening by hand after a Quit; a first run) and every snapshot its effect log took: a Mac restored from that snapshot and opened by hand from /Applications ends with the same login item status, only `settings` in the suite, and a record equal to the one the uncrashed run ends with. | The uncrashed run's own final state; the design's crash order ("every crash point converges on the next opening by hand"); Preserve 1. |
| T24 | R23 | `Lifecycle` | At placement `.development` (a development build outside /Applications): (a) a first run opens the window, asks for Accessibility and saves, with the login item's log empty; (b) with the installed copy's login item on, a development build opened by hand and then quit with `quit()` leaves the log empty and the item on, so `login()` starts a process. | R23 (a development build runs where it was built); the design's rule that it leaves starting at login alone (open question 3). |
| T25 | R5, R18, R23 | `Placement` | The running bundle is spelled as `Bundle.main.bundleURL` gives it, with a trailing slash. (a) Not translocated, inside /Applications (`/Applications/TrackpadLauncher.app/`, `/Applications/Utilities/TrackpadLauncher.app/`) → installed, for a release build and a development build alike. (b) Not translocated, outside /Applications (`/ApplicationsOld/TrackpadLauncher.app/`, `/Applications/../Users/me/Downloads/TrackpadLauncher.app/`, `~/Applications/TrackpadLauncher.app/`, `~/Applications/Tools/TrackpadLauncher.app/`, `~/Downloads/TrackpadLauncher.app/`, and `/Volumes/Trackpad Launcher/TrackpadLauncher.app/` with its disk image) → elsewhere for a release build, development for a development build. (c) Translocated (running in an `AppTranslocation` mount, original in /Applications, `isTranslocated` true) → elsewhere for a release build, development for a development build. | R5 ("The first run from /Applications"); R18 ("outside /Applications"; "~/Applications counts as outside"); R23; F34. |
| T26 | R23 | `CodeSignature` | `build(of:)` of the test's own ad-hoc binary → `.development`. `buildOfThisProcess(arguments:)` in the test process → `.development` without `--as-release-build`, `.release` with it among the arguments, and `.development` with a near spelling such as `--as-release`. Every app in /Applications reads `.release` exactly when `codesign -dvv` reports `Authority=Developer ID Application`; this part runs only when /Applications holds at least one such app and one other app, so the rule is seen to discriminate. | F7 (probed); `codesign -dvv` as an independent oracle; the design's `--as-release-build` argument. |
| T27 | R22, R23, R9 | `Lifecycle` | `launched(.atLogin)` at `.installed`, at `.elsewhere` (~/Applications/Tools) and at `.development` → a silent resident, with `moveDialog == nil` throughout; `launched(.byHand)` at `.development` with the installed copy running → that copy is stopped, then the window opens, with `moveDialog == nil` throughout. | R22 scenario; R23 scenario "Running from Xcode"; R9. |
| T28 | R18, R2 | `Lifecycle` | Given a copy running from /Applications and this copy in ~/Downloads, on a Mac with a settings record and on one without; when `launched(.byHand)`; then, until an answer, `moveDialog == .asking`, `launcher == nil`, `residentsBuilt == 0`, nothing is stopped, asked, registered or installed, and the suite's persistent domain equals its snapshot from before the launch; when `answer(.quit)`, the process ends, and the suite, the login item and the installer's log are as they were. | R18 scenarios 1-3 ("nothing else of Trackpad Launcher does"; "no login item, permission prompt or settings exists afterwards that was not there before"; the running copy keeps its gestures). |
| T29 | R18 | `Lifecycle` | Given a resident started at login in ~/Applications/Tools with Arc on the 1-finger gesture; when `openedAgain(.byHand)`; then `moveDialog == .asking`, `launcher` is that same resident, its window never opens, and `tap(1)` brings Arc to front while the dialog asks; a second `openedAgain(.byHand)` changes nothing; `answer(.quit)` ends the process and the login item saw no call. | R18 scenario 4; R18 ("*Quit* MUST stop it with nothing changed"). |
| T30 | R19, R5 | `Lifecycle` | Given no settings record and this copy in ~/Downloads; when `answer(.move)`: the dialog is gone and the install is held; a second `answer(.move)` and an `openedAgain(.byHand)` while it is held start no second install and show no dialog; when the row releases `.installed`: the original is removed, the installed copy is opened and this process ends, with no login-item call and still no settings record; the installed copy, `launched(.byHand)` at `.installed`, registers and asks while the store loads nil, then saves and opens its window. | R19 scenario 1 ("the settings window opens with macOS asking for the Accessibility permission"); `why.md` Risk 4 (the move must not spend the first run). |
| T31 | R20, R19, R13, R2 | `Lifecycle` | Given an older copy running from /Applications, a record with Arc on the 1-finger gesture and Left thumb, the login item on, and this copy on a disk image: while the dialog asks, the older copy is not stopped; after `answer(.move)` and `.installed`, the login item is off with its fact kept, the older copy is stopped, and the installed copy is opened only after the row lets the older one exit, then this process ends; opened by hand, the installed copy turns the login item on, only `settings` remains, the window shows Arc and Left thumb, and `tap(1)` brings Arc to front. With the login item off by the user's choice instead, it is still off afterwards and its log holds no `register`. | R20 scenario; R19 (in /Applications, opened from there); R13 scenario 4; R2. |
| T32 | R21, R18, R8 | `Lifecycle` | (a) `answer(.move)` then `.cancelled` → the process ends with no login-item call, no `removeOriginal`, nothing stopped or opened and the suite unchanged; a login-started resident (T29's) ends too; (b) `.failed(reason:)` → `moveDialog == .failed(reason:)` with that reason, a resident still brings Arc to front on `tap(1)`, and `answer(.quit)` ends the process with nothing changed; (c) `shouldEnd(.system)` answers true while the dialog asks, while the install is held and while the failure shows. Every path out of the dialog ends the process. | R21 scenario; R18 ("*Quit* MUST stop it with nothing changed"; "MUST NOT keep running from outside /Applications"); R8. |
| T33 | R19, R20 | `Lifecycle`, every crash point | For T30's and T31's runs and every snapshot their effect logs took: a crash before the install completed, followed by opening the original again, leaves what outlives a process as it was before the move; a crash after it, followed by opening the /Applications copy by hand, ends with the login item status, the suite's keys and the record of the uncrashed run. | The uncrashed run's own final state; the design's move order (decision 9). |
| T34 | R19, R20 | `ApplicationsInstaller` over temp dirs | A fixture bundle (this bundle identifier, version 1.0, nested files and a symlink, `com.apple.quarantine` set on every item with `/usr/bin/xattr -w`) installed into a writable temp /Applications: (a) when empty → `.installed`, the destination matches the fixture's manifest (relative paths, SHA-256, symlink targets), no item carries `com.apple.quarantine` (`/usr/bin/xattr -r`), and the administrator is never asked; (b) holding version 2.0 under the same name → replaced by 1.0, no other copy; (c) holding it renamed `Trackpad Launcher Old.app` → that bundle is replaced, no second copy; (d) a translocated location → the copy comes from the running bundle and takes the original's name. | The fixture's manifest, recorded when it is made; `xattr` as an independent reader; R20 ("whatever their versions"). |
| T35 | R19 | `ApplicationsInstaller.removeOriginal` | The original in a temp Downloads → removed; in a folder made read-only (`chmod 0555`, standing for a read-only share) → left, nothing thrown; with `Location.diskImage` set → left; when it is the installed copy → left. | R19. |
| T36 | R18, R19 | `ThisCopy.location(of:originalIfTranslocated:diskImage:)` | (a) For `/Applications/TrackpadLauncher.app/` with both lookups answering nil: `running` and `original` are that bundle, `isTranslocated` is false, there is no disk image, and `Placement` of a release build there is installed. (b) For a bundle in an `AppTranslocation` mount whose translocation lookup answers `/Volumes/Trackpad Launcher/TrackpadLauncher.app`, with a disk-image lookup that knows only paths under `/Volumes/Trackpad Launcher`: `original` is that path, `isTranslocated` is true, and the disk image is the one found from the original, not from the running bundle. | The `Location` docs ("`running` when not translocated"; "The disk image `original` lies on"); F34, F35. |
| T37 | R19 | `Lifecycle` and `ThisCopy` | `ThisCopy.launch(event:arguments:)` with `--eject-disk-image "/Volumes/Trackpad Launcher"` → that volume; the flag with no value → nil; Xcode's `-NSDocumentRevisionsDebugMode YES` → ignored. The installed copy `launched(Launch(opening: .byHand, diskImageToEject:))` while the mover is still exiting: no eject while the row withholds the mover's exit; after it exits, the resident and its window, then one eject of that image. | R19 scenario 2 ("the disk image is no longer mounted"); the design's argument. |
| T38 | R21, R18, R20 | `ApplicationsInstaller` and `PrivilegedInstall` with a test `Administrator` | (a) With the temp /Applications unwritable, and again with only the existing copy unwritable, the administrator is asked. If it answers `.cancelled`, the outcome is `.cancelled`; if `.failed`, the outcome is `.failed`. Either way the destination matches its manifest from before, and the staged copy it was handed (`$2`) is gone. (b) A running bundle that cannot be read → `.failed` before the administrator is asked, the destination unchanged. (c) `PrivilegedInstall.swap` through a test administrator that runs `PrivilegedInstall.script` without privileges, over writable temp dirs whose paths hold spaces, `'`, `"` and `$(touch pwned)`, → `.installed`: the destination matches the fixture's manifest, the aside path (`$3`) lies in the staging folder outside /Applications and nothing is left there, and no `pwned` file exists under the temp root. (d) The second move fails (the staged path removed just before the script runs) → `.failed`, and the destination matches its manifest from before. (e) The old copy cannot be fully removed from the aside path (a read-only folder inside it) → `.installed`, since the new copy is in place. | R21 scenario; the `Installer` doc ("Nothing there changes unless the outcome is `.installed`"; the old copy moves into the staging folder); the fixture's manifests; F32 (the command's shape). |

### Verified without a test

C16, C18, C19 and C20 need a copy outside /Applications that reads as release. That is a build signed with Developer ID, or a development build opened with `open <app> --args --as-release-build`. Some checks test a login start, Gatekeeper, quarantine, translocation or notarisation itself: C16's login-started step, C17, C21 and C23. These need a Developer ID build.

- **C1** (R1). With the app running and the window closed, the menu bar shows no Trackpad Launcher item. Turn on *Tap to click* and open the app from Spotlight: still no menu bar item, and the window shows the trackpad settings notice.
- **C2** (R2). With the /Applications copy running in the background, open it from Spotlight: the window opens in front with the keyboard focus, the Dock shows one Trackpad Launcher icon, and `pgrep -x TrackpadLauncher` prints one pid. Put a Safari window over it and open the app from /Applications in Finder: the same window comes to the front, and no second window opens. Minimise it and open the app from Spotlight: the window is restored and in front.
- **C3** (R3). Install the last menu bar release in /Applications and run it. Drag this build over it in Finder (record whether Finder allows replacing a running app; grounding open question 4), then open it from Launchpad: the menu bar icon disappears without logging out, the window opens, and Activity Monitor lists one Trackpad Launcher process, the new version. Repeat with this build running from ~/Applications/Tools and the /Applications copy opened from Spotlight.
- **C4** (R5). On a new macOS user account, drag the app into /Applications and open it: macOS asks for Accessibility, the window opens with every gesture unassigned and stays open while the prompt shows, *System Settings → General → Login Items* lists Trackpad Launcher, and a 1-finger gesture assigned now brings its app to front. On a second new account, grant Accessibility before the first run: no prompt, and the window opens.
- **C5** (R6, R7). The window is titled, with close and minimise buttons, centred on the pointer's display, in front and focused. The Dock and ⌘-Tab show the app, also while the window is minimised. Clicking a Safari window brings Safari to the front, the window stays open behind it, and the Dock still shows the app. Closing the window removes the Dock icon and the ⌘-Tab entry, and a 2-finger gesture still works. Drag the window to the main display's left edge, close it, move the pointer to a second display and open the app: the window opens centred there.
- **C6** (R8). The app menu shows *Close Settings* with ⌘Q, and no *Quit Trackpad Launcher*. Each of the close button, ⌘W, Escape, ⌘Q and the Dock icon's Quit closes the window and removes the Dock icon, and a 3-finger gesture still works. With the 1-finger picker's menu open, Escape closes only the menu, and the gesture keeps its app (F45). Restart and shut down, once with the window open and once with it closed: neither is held up or questioned (F17-F19, open question 4).
- **C7** (R8, R16). Choose *Other…* in the 2-finger picker, then Quit in the Dock icon's menu: the sheet and the window close, the 2-finger gesture keeps its app, and gestures work.
- **C8** (R9). Shut down, start and log in: a 1-finger gesture works, and nothing of Trackpad Launcher shows. Log out with the window open and *Reopen windows when logging back in* ticked, then log in: no window, no Dock icon, and gestures work. Run `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp`, then log out and in: no window, no prompt, and a 1-finger gesture works. This also settles open question 1 (the login marker).
- **C9** (R10). Revoke Accessibility, turn the window swipe setting on without Screen Recording, open the window and scroll to its end. *Quit Trackpad Launcher* is a red Liquid Glass capsule with white text at the regular size, right-aligned, below both hints.
- **C10** (R11, R12). Press *Quit Trackpad Launcher*: the window and the Dock icon go at once with no confirmation, `pgrep -x TrackpadLauncher` prints nothing, and a 1-finger tap under the anchored thumb clicks as usual. Then: *Login Items* shows it off. Restart: it is not running. Open it from Spotlight: *Login Items* shows it on. Restart: it runs with no window.
- **C11** (R13). Turn it off in *Login Items* and open it from Spotlight: still off. Press Quit and open it: still off. Turn it on, press Quit and open it: on. Record which status macOS reports after each change (F25).
- **C12** (R14). Force-quit it in Activity Monitor: `pgrep` prints nothing a minute later. Log out and in: it runs. Force-quit it again and open it from Spotlight: it runs.
- **C13** (R15). With Safari in front, open the window over it and swipe: the row starts on Safari and holds no Trackpad Launcher. Thumb-tap a swap: the app used before Safari comes to front. Assign Notes to the 2-finger gesture in the window and make the gesture: Notes comes over the window with the haptic and the launch animation, and the window and the Dock icon stay.
- **C14** (R16). Choose *Other…* in the 3-finger picker: the file chooser shows as a sheet on the window. Pick an app in ~/Downloads: the sheet closes, the window stays, and the picker shows the app. Again with Cancel: the assignment is kept.
- **C15** (R17). With the Accessibility hint, the screen recording hint and the trackpad settings notice showing, each one's button opens its System Settings page, and the window stays open behind it.
- **C16** (R18). On a new account, copy the app to ~/Downloads, open it and press *Quit*: `defaults read com.domasgru.TrackpadLauncherApp` reports that the domain does not exist, *Login Items* and /Applications are unchanged, and no prompt showed. With the /Applications copy running, open a ~/Downloads copy: the dialog shows, and a 1-finger gesture still works. With a copy in ~/Applications/Tools started at login, open it from Finder: the dialog shows, a 1-finger gesture works while it does, and *Quit* stops it.
- **C17** (R18, R19). Download the notarised disk image with Safari, open it and double-click the app: only the move dialog shows (no window, no Dock icon, no prompt). Press *Move to Applications*: the installed copy runs from /Applications rather than from a translocation mount (`ps -o comm= -p` its pid; F38), and the image no longer appears in `hdiutil info`. Repeat with a document on the image open in TextEdit: the move completes, and the image stays mounted.
- **C18** (R19). Open the app from ~/Downloads for the first time and press *Move to Applications*: /Applications holds it, ~/Downloads does not, and the window opens with macOS asking for Accessibility (record whether an earlier grant followed the copy; open question 6). From a read-only share: the move completes, and the original stays.
- **C19** (R20). An older build with Arc on the 1-finger gesture and Left thumb runs from /Applications. Open a newer build from its disk image and press *Move to Applications*: Activity Monitor lists one process, the newer version; the window shows Arc and Left thumb; a 1-finger gesture brings Arc to front; *Login Items* is unchanged (record whether macOS announced a login item; open question 5).
- **C20** (R21). On a standard account, press *Move to Applications*: an administrator name-and-password prompt like Finder's appears (F36). Cancel: the app stops, and /Applications is unchanged. Again with an administrator's credentials: the app moves and opens from /Applications. Log out while the prompt shows: the logout proceeds, and /Applications is unchanged.
- **C21** (R22). On a new account, run a menu bar version from ~/Applications/Tools so it registers at login, replace it there with this build, then log out and in: it runs with no dialog and no window.
- **C22** (R23). Run from Xcode, and open the perf build: no move dialog, the window opens, and neither changes *Login Items*.
- **C23** (R24). On a Mac with a Developer ID Application identity and `NOTARY_PROFILE`, run the release command from a clean clone: it produces `build/release/TrackpadLauncher.dmg`. `spctl --assess --type open --context context:primary-signature -vv` on it reports accepted, Notarized Developer ID. `xcrun stapler validate` on the image and on the app inside reports valid. Mounted, the image shows the app beside an Applications shortcut over the drag cue. On a Mac that never saw the app, download the image with Safari, open it, drag the app onto the shortcut and open it from Launchpad: no unverified-developer warning, no move dialog, then C4's first run.
- **C24** (R25). With the last menu bar release in /Applications, gestures assigned and its login item on, quit it, replace it with this build, then log out and in: no menu bar icon, no Dock icon, every gesture brings its app to front, and *Login Items* still shows it on.
- **C25** (R6, R8, R9). In the built app's Info.plist (`plutil -p`), `LSUIElement` and `NSSupportsSuddenTermination` are both true. `applicationWillFinishLaunching` calls `disableRelaunchOnLogin` (grep; the source scan confines the call to the app target).
- **C26** (all). `swift test` and the app's `xcodebuild` pass. Grep finds no `registerLoginItem`, `dismissWindow`, `heldOpen`, `openWindow(`, `MenuBarShell`, `StatusIcon` or `LauncherPanel`.

## Slices

### S1: A background app whose settings window opens by hand

**What to build:** Trackpad Launcher has no menu bar icon.
- Opening it by hand starts it with its settings window, or brings the running copy's window to the front.
- A login start runs gestures silently.
- On a Mac without settings, the first opening by hand registers starting at login and asks for Accessibility.
- The window is an ordinary titled window, centred on the pointer's display, and the app is in the Dock and ⌘-Tab exactly while it is open.
- The close button, ⌘W, Escape, the app menu's *Close Settings* (⌘Q) and the Dock's Quit close the window and keep gestures running.
- A logout ends the app, and the red *Quit Trackpad Launcher* button at the end of the window ends it.

This means building:
- `Lifecycle` with `launched`, `openedAgain`, `shouldEnd` and `quit` over the stages it needs now. Every opening by hand runs with the window; other copies, placement and the move come later.
- `Opening`, `Launch` and `QuitRequest`.
- `Launcher.start()`, `openedByHand()`, `closeWindow()` and the public `Window` with its request count. `.heldOpen`, `dismissWindow()` and the grant's end of the hold are deleted.
- `StartAtLogin.enrol()` over the `LoginItem` port, with `SystemLoginItem` in place of `SystemActions.registerLoginItem`.
- The `RunningCopies` port with `endThisCopy()`.
- `ThisCopy`'s parse of openings, and `QuitSignals`.
- The `AppDelegate`.
- `SettingsShell`, `SettingsWindow` and `SettingsView`, replacing the menu bar shell, the panel, the old view and the status icon.
- Sudden termination in the bundle.
- `LifecycleWorld`.

Gesture effects may still close the window until S2.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2 (in part: opening the running copy brings its window to the front), R4, R5, R6, R7, R8, R9, R10, R11 (in part: Quit stops the app; S4 turns starting at login off), R14.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11.

- [ ] T1-T11 green. The existing suite is green: the tests that relied on `start()`'s first launch use `openedByHand()`, and the held-window tests are deleted.
- [ ] C1, C2, C4, C5, C6, C8, C9, C12 pass, and so does C10 up to the `pgrep` and click steps.
- [ ] C25 and C26 pass.
- [ ] What was built still matches the domain model's *Trackpad Launcher*, *Settings window*, *Opened by hand*, *Login start*, *First run* and *Quit Trackpad Launcher* entries and the architecture doc's Shape, Concurrency and Privacy sections, all written at planning; a difference is fixed in the code or, if the plan was wrong, in the doc.
- [ ] The product overview follows the Solution, without the menubar-window image.
- [ ] The performance doc says "settings window".

### S2: Gestures, *Other…* and System Settings with the settings window in front

**What to build:** A gesture, swipe, window swipe or swap leaves the settings window open. With the window in front, the switcher and the swap start from the app that was in front before it. *Other…* shows the file chooser as a sheet on the window, and the System Settings buttons leave the window open.

This means building:
- The four effect closes deleted.
- `RunningAppsReader.frontmost(activePID:activeEntry:ownPID:apps:)`.
- The own-pid filter in the switcher presenter's Dock-app read.
- The sheet, and `openSettings` that only opens the pane.
- The stale "never active" comments corrected, and the no-frontmost tests reworded as "no active app".

**Blocked by:** S1.

**Requirements:** R15, R16, R17.

**Test scenarios:** T12, T13.

- [ ] T12 and T13 green. The flipped tests no longer say "AndClosesTheWindow" in their names.
- [ ] C7, C13, C14 and C15 pass.
- [ ] What was built still matches the domain model's *Frontmost app*, *Swap* and *Launch animation setting* entries, written at planning.

### S3: One Trackpad Launcher at a time

**What to build:** Opening Trackpad Launcher by hand while another build, or a copy from another place, runs stops that copy. The opened copy starts gestures and its window only once that copy has exited. This includes the menu bar version. When two copies start at login, the older one keeps running.

This means building:
- `RunningCopies.others()` and `stop(_:then:)`.
- `SystemRunningCopies`: force terminate, KVO on termination with the initial value, and the pure start order `started(_:before:)`.
- `Lifecycle`'s replacing stage and the older-copy rule at login.
- `InMemoryRunningCopies`' per-copy exits, early exit and duplicated push.

**Blocked by:** S1.

**Requirements:** R2, R3.

**Test scenarios:** T14, T15, T16, T17, T18, T19.

- [ ] T14-T19 green.
- [ ] C3 passes, and C2's one-process step still holds with a second build running.
- [ ] The source scan confines `forceTerminate` and `.terminate(` to the copies adapter.
- [ ] What was built still matches the architecture doc's "at most one Trackpad Launcher runs gestures", written at planning. The performance doc no longer asks developers to quit other copies by hand.

### S4: Quit holds across restarts, and the user's Login Items choice is kept

**What to build:** Quit turns starting at login off, but only when it is on, and only then does the next opening by hand turn it back on. The user's own off is never overridden, including by an upgrade. Any copy inside /Applications is treated as installed, whatever its build. A development build outside /Applications never touches starting at login.

This means building:
- `StartAtLogin.suspend()` and `resume()`, with their own defaults key and their crash order.
- `Lifecycle.quit()` suspends, and `Launcher.openedByHand()` resumes on any run that is not the first.
- `LoginItem.isOn` and `unregister()` in `SystemLoginItem`.
- `Placement` and `CodeSignature`, with `StartAtLogin`'s no-ops for `.development`.
- `buildOfThisProcess(arguments:)`, which honours `--as-release-build` for a build not signed for release.
- `InMemoryLoginItem`'s two readings of the user's off, and the crash-point snapshots.

**Blocked by:** S1.

**Requirements:** R5 (in part: a development build inside /Applications does the first run's setup), R11 (turning starting at login off), R12, R13, R18 (in part: which copies count as outside /Applications), R23 (in part: starting at login), R25.

**Test scenarios:** T20, T21, T22, T23, T24, T25, T26.

- [ ] T20-T26 green.
- [ ] C10's *Login Items* steps, C11 and C24 pass, and C22's *Login Items* step holds.
- [ ] The source scan confines `SecCode`, `SecStaticCode` and `SecRequirement` to the code-signature file.
- [ ] What was built still matches the domain model's *Starting at login* and *Development build* entries, written at planning.

### S5: Opened outside /Applications, it moves itself there

**What to build:** A release copy opened by hand anywhere outside /Applications shows only the move dialog.
- *Quit* stops it with nothing changed.
- *Move to Applications* copies it into /Applications, replacing any copy already there. It then hands starting at login over, removes the original when it can, and stops every other copy. Last, it opens the installed copy, which does its first run or opens its window.
- A failure before /Applications changes shows the reason and Quit.
- A login start and a development build never ask.

This means building:
- `Location` and `ThisCopy.location()` with its test handle `location(of:originalIfTranslocated:diskImage:)`, and translocation resolved.
- `Route` with `askToMove`.
- `Lifecycle`'s asking, moving and failed stages, with `answer(_:)`.
- `MoveDialog`, `MoveAnswer` and `InstallOutcome`.
- The `Installer` port, with `ApplicationsInstaller` and `BundleInstall` on the unprivileged path.
- `MoveDialogPresenter`, and the dialog's strings.
- `InMemoryInstaller`.

**Blocked by:** S3, S4.

**Requirements:** R18, R19 (except ejecting the disk image), R20, R22, R23.

**Test scenarios:** T27, T28, T29, T30, T31, T32, T33, T34, T35, T36.

- [ ] T27-T36 green.
- [ ] C16 (except its login-started step), C18, C19 and C22 pass. Until a Developer ID build exists, the copy outside /Applications is opened with `--as-release-build`.
- [ ] The source scan confines `copyItem(`, `moveItem(`, `replaceItemAt(`, `removeItem(` and `quarantinePropertiesKey` to the bundle-install file, `SecTranslocate` to `ThisCopy`'s file, and `runModal` to the dialog presenter.
- [ ] What was built still matches the domain model's *Move dialog* entry and the architecture doc's Privacy rule on writing the app's own bundle into /Applications, both written at planning.

### S6: The administrator prompt and the disk image

**What to build:** On an account that cannot write to /Applications, *Move to Applications* asks for an administrator's name and password the way Finder does, and Cancel stops the app with nothing moved. A copy moved from a disk image ejects the image once the mover has exited. It leaves the image mounted when a file on it is in use.

This means building:
- `PrivilegedInstall` and its script, behind the internal `Administrator` seam, with the real `AuthorizationAdministrator`.
- `ApplicationsInstaller`'s routing on whether this user can write to /Applications or to the copy there.
- `DiskImages` (detection and eject), as the real disk-image lookup in `ThisCopy.location()`.
- The eject argument, from `openInstalledCopy()` to `ThisCopy.launch`.
- `Lifecycle`'s eject after the other copies exit.

**Blocked by:** S5.

**Requirements:** R19 (ejecting the disk image), R21.

**Test scenarios:** T37, T38.

- [ ] T37 and T38 green.
- [ ] C17's eject steps pass with a locally built disk image and the copy opened with `--as-release-build`. C20 passes the same way.
- [ ] The source scan confines `AuthorizationExecuteWithPrivileges` and `AuthorizationCopyRights` to the privileged-install file, and `statfs`, `DADisk` and `unmountVolume` to the disk-image file.
- [ ] What was built uses no framework beyond the architecture doc's platform list (Security for the code signature, Authorization and the private translocation functions; DiskArbitration), written at planning.

### S7: The release disk image

**What to build:** One command builds a disk image that is signed with Developer ID, notarised and stapled. It opens on Trackpad Launcher beside an Applications shortcut, with a cue to drag one onto the other. This means the release script's eleven steps from the design, and the committed background picture, kept out of the app's bundled assets.

**Blocked by:** S6.

**Requirements:** R24.

**Test scenarios:** None.

- [ ] C23 passes. With the Developer ID build, C17 passes in full, and so do C16's login-started step and C21.
- [ ] What was built still matches the architecture doc's Distribution section (the notarised, stapled disk image), written at planning.
