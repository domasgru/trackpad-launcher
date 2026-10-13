# Plan: The switcher shows running apps like ⌘-Tab

## Problem statement

The switcher shows only the apps the user put in the switcher list. The user must build and maintain that list in the launcher window. Any app not on the list cannot be reached by swiping, and the order never follows what the user actually does. A fresh install has an empty list, so the swipe does nothing until the user sets it up.

Users already know a switcher that needs no setup: ⌘-Tab. It shows every running app, most recently used first. The swipe should feel the same.

The user also asked for a single switch to turn the swipe on or off. Without the list there is no other way to turn it off, and some users want taps alone.

## Solution

The switcher shows the same apps, in the same order, as macOS's own ⌘-Tab app switcher: every running app that appears in the Dock, most recently used first. The frontmost app sits at the left end and the selection starts on it. Sliding the fingers right moves to apps used longer ago. Lifting brings the selected app to the front, as today. The name under the selected icon is the one macOS shows for the running app, as the Dock and Force Quit do; for a few apps it differs from the Finder name the app pickers show ("Code" for Visual Studio Code).

The switcher list goes away, together with its rows and Add app… in the launcher window. In its place, the switcher section gets one switch: **Swipe to switch apps**, on by default. Off means the swipe does not exist: the fingers behave as if the feature were never built, and taps keep working.

When many apps run, the row shrinks its icons to fit the display, like ⌘-Tab. The finger distance per icon stays the same.

Terms, for the glossary: *switcher list* is retired. New: *running apps* (the apps ⌘-Tab shows, in its order) and *swipe setting* (the Swipe to switch apps switch). The *switcher*, *frontmost app*, *launcher window*, *swipe* and *click blocking* entries change to follow this plan.

This plan amends plan 006. Its switcher list requirements (the list, its rows, Add app…, reorder, remove, missing apps) are replaced by this plan. Its switcher row rule ("the switcher list's present apps in list order with the frontmost app added at the left end") is replaced by R1 and R2 here. Its fixed 80 pt icons become the largest size, shrinking as R6 says. The switcher version with a list was never released, so no saved list needs carrying over. `docs/product-overview.md` changes in two places. First, the swipe shows the running apps like ⌘-Tab, and the user slides right to reach older apps, instead of apps chosen in the window; and the swipe can be switched off. Second, the haptic exception becomes general: a swipe lift that changes nothing is silent, whether the user lifts on the starting app, on an app that quit, or with no switcher showing. `docs/domain-model.md` follows the terms above.

## Requirements

### R1. The switcher shows the apps ⌘-Tab shows
The switcher's row MUST hold the apps macOS's ⌘-Tab app switcher would show at the moment the swipe begins: every running app that appears in the Dock. The one exception is the frontmost app: when ⌘-Tab would not show it, such as a menu bar app with a window in front, it MUST still be in the row, as R2 says. The row MUST include apps that are hidden, apps whose windows are all minimised, apps with no windows, and apps whose windows are on another Space or in full screen. Apart from the frontmost app, it MUST NOT include apps that do not appear in the Dock, such as menu bar apps. Trackpad Launcher never comes to the front, so it is never frontmost and never in the row.

#### Scenario: Hidden and minimised apps are included
- **GIVEN** Safari, Mail and Notes are running, Mail is hidden and Notes has its only window minimised
- **WHEN** the user swipes
- **THEN** the row holds Safari, Mail and Notes, along with every other app ⌘-Tab would show

#### Scenario: Windowless app is included
- **GIVEN** Preview is running with all its windows closed
- **WHEN** the user swipes
- **THEN** Preview is in the row

#### Scenario: Menu bar apps are left out
- **GIVEN** a menu bar only app is running, with no Dock icon, and it is not frontmost
- **WHEN** the user swipes
- **THEN** that app is not in the row, and Trackpad Launcher is not in the row

#### Scenario: Matches ⌘-Tab
- **GIVEN** any set of running apps
- **WHEN** the user holds ⌘, presses Tab, notes the apps, presses Esc to dismiss without switching, releases ⌘, then swipes
- **THEN** the switcher holds the same apps as ⌘-Tab, plus the frontmost app only when ⌘-Tab does not show it

### R2. The row is in ⌘-Tab order, the frontmost app first
The row MUST list the apps left to right in the order ⌘-Tab shows them: the frontmost app at the left end, then the other apps from most to least recently used. This order MUST hold from the first swipe after Trackpad Launcher starts, including apps used before it started. When the frontmost app is not one ⌘-Tab would show, it MUST still sit at the left end, followed by the ⌘-Tab apps in order. If macOS ever stops revealing when an app was last used, apps whose order is unknown MUST go after the known ones, in the order they launched.

#### Scenario: Most recently used comes next
- **GIVEN** the user used Notes, then Mail, then Safari, and Safari is frontmost
- **WHEN** the user swipes
- **THEN** the row starts Safari, Mail, Notes, in that order

#### Scenario: Order known right after start
- **GIVEN** the user used Notes, then Mail, then Safari, then started Trackpad Launcher with Safari frontmost
- **WHEN** the user swipes before switching to any app
- **THEN** the row starts Safari, Mail, Notes

#### Scenario: Order follows the last switch
- **GIVEN** Safari is frontmost and Mail is second
- **WHEN** the user swipes one icon right and lifts, so Mail comes to the front, and then swipes again
- **THEN** the row starts Mail, Safari

#### Scenario: Frontmost menu bar app
- **GIVEN** a menu bar app's window is frontmost
- **WHEN** the user swipes
- **THEN** that app sits at the left end, followed by the ⌘-Tab apps in order

#### Scenario: Matches ⌘-Tab order
- **GIVEN** any set of running apps
- **WHEN** the user holds ⌘, presses Tab, notes the order, presses Esc to dismiss without switching, releases ⌘, then swipes
- **THEN** the switcher shows the apps in the same order as ⌘-Tab

### R3. The selection starts on the frontmost app and moves right to older apps
When the switcher appears, the selection MUST be on the frontmost app, at the left end of the row. Sliding the fingers right MUST move the selection towards apps used longer ago; sliding left MUST move it back towards the frontmost app. The direction MUST be the same in left-hand mode.

#### Scenario: One step right selects the previous app
- **GIVEN** Safari is frontmost and Mail was used just before it
- **WHEN** the user swipes right by one icon and lifts
- **THEN** Mail comes to the front with the gesture haptic

#### Scenario: Lift without moving an icon
- **GIVEN** Safari is frontmost
- **WHEN** the user swipes right less than half an icon and lifts
- **THEN** nothing happens and no haptic plays

#### Scenario: Same direction in left-hand mode
- **GIVEN** left-hand mode is on, Safari is frontmost and Mail was used just before it
- **WHEN** the user swipes right by one icon and lifts
- **THEN** Mail comes to the front, as in right-hand mode

### R4. The left end is a hard stop
Sliding left from the frontmost app MUST meet the row's hard stop with its rubber band, as at either end today. Turning back right MUST move the selection after the usual travel for one icon. The rubber band MUST NOT add a dead zone.

#### Scenario: Left from the start is a hard stop
- **WHEN** the user swipes left as soon as the switcher appears, then turns back right
- **THEN** the highlight stretches a little past the left end and the selection stays on the frontmost app; after the turn, the selection moves to the next app after the usual travel for one icon, with no extra travel to undo the stretch

### R5. The row is fixed for the whole swipe
The row MUST be decided when the swipe begins and MUST NOT change during the swipe. An app that launches during the swipe MUST NOT appear in it. An app that quits during the swipe MUST stay in the row; lifting on it MUST do nothing, with no haptic, and MUST NOT launch it again.

#### Scenario: App quits mid-swipe
- **GIVEN** the switcher shows Safari, Mail, Notes and the user has selected Notes
- **WHEN** Notes quits before the user lifts, then the user lifts
- **THEN** nothing happens, no haptic plays, and Notes is not launched

#### Scenario: App launches mid-swipe
- **GIVEN** the switcher is showing
- **WHEN** Calendar launches before the user lifts
- **THEN** Calendar does not appear in the row

### R6. Many apps shrink to fit the display
Icons MUST be 80 pt when the whole row fits on the pointer's display. When it does not, the icons and the gaps between them MUST scale by the same factor, so the row keeps its proportions and the whole row fits on that display, in one row. The finger travel per icon MUST NOT change with the icon size.

#### Scenario: Few apps
- **GIVEN** five apps are running
- **WHEN** the user swipes
- **THEN** the row shows five 80 pt icons

#### Scenario: Many apps
- **GIVEN** so many apps are running that 80 pt icons would overflow the display
- **WHEN** the user swipes
- **THEN** every app shows in one row within the display, with smaller icons, and moving one icon takes the same finger travel as with five apps

### R7. Lifting brings the selected app to the front as today
Lifting on an app other than the one that was frontmost when the swipe began MUST bring it to the front with the gesture haptic, as clicking the app's Dock icon would: unhide it, restore its minimised windows, open a new window, or move to its Space as needed, and make it the active app. Lifting on the app that was frontmost when the swipe began MUST do nothing and stay silent, even if another app came forward during the swipe.

#### Scenario: Hidden app comes back
- **GIVEN** Mail is hidden and the switcher has Mail selected
- **WHEN** the user lifts
- **THEN** Mail unhides and becomes the active app, with the gesture haptic

#### Scenario: Minimised app comes back
- **GIVEN** Notes has its only window minimised and the switcher has Notes selected
- **WHEN** the user lifts
- **THEN** the Notes window is restored and Notes becomes the active app

#### Scenario: Windowless app opens a window
- **GIVEN** Preview is running with no windows and the switcher has Preview selected
- **WHEN** the user lifts
- **THEN** Preview becomes the active app and a new window opens

#### Scenario: Full-screen app on another Space
- **GIVEN** Keynote is in full screen on another Space and the switcher has Keynote selected
- **WHEN** the user lifts
- **THEN** the display moves to Keynote's Space and Keynote becomes the active app

#### Scenario: Lifting on the starting app
- **GIVEN** Safari was frontmost when the swipe began, and Mail came forward during the swipe
- **WHEN** the user lifts with Safari selected
- **THEN** nothing happens and no haptic plays

### R8. No switcher when there is nothing to switch to
The switcher MUST NOT appear when the row would hold only the frontmost app. The swipe itself still happens: clicks and scrolling stay blocked until the fingers lift, as today.

#### Scenario: Only one app running
- **GIVEN** Finder is the only running app that ⌘-Tab shows, and it is frontmost
- **WHEN** the user swipes
- **THEN** no switcher appears and nothing happens on lift

### R9. The launcher window has a swipe switch instead of the switcher list
The launcher window's switcher section MUST show one row: the swipe illustration, the title "Swipe to switch apps", and a switch at the right end, laid out like the window's other setting rows. The switcher list rows and Add app… MUST NOT appear. The illustration MUST still mirror in left-hand mode.

#### Scenario: Window shows the switch
- **WHEN** the user opens the launcher window
- **THEN** the switcher section shows the swipe illustration, "Swipe to switch apps" and a switch, and no app rows or Add app…

#### Scenario: Left hand mirrors the illustration
- **WHEN** the user selects Left hand
- **THEN** the swipe illustration mirrors as it does today

### R10. The swipe setting is on by default and saved at once
The swipe setting MUST be on for a fresh install. A change MUST apply to the next swipe and MUST be saved at once, so it survives a quit, a force-quit or a Mac restart.

#### Scenario: Fresh install
- **WHEN** the user installs Trackpad Launcher and opens the launcher window
- **THEN** the Swipe to switch apps switch is on, and swiping shows the switcher

#### Scenario: Off survives a force-quit
- **GIVEN** the user turned the switch off
- **WHEN** the user force-quits Trackpad Launcher and starts it again
- **THEN** the switch is still off

### R11. With the setting off, there is no swipe
While the swipe setting is off, two fingers sliding sideways under an anchored thumb MUST NOT be a swipe. No switcher MUST appear. Tap gestures MUST work exactly as with the setting on.

#### Scenario: Sliding does nothing
- **GIVEN** the swipe setting is off
- **WHEN** the user anchors the thumb and slides two fingers sideways
- **THEN** no switcher appears, no app changes when the fingers lift, and after the blocking window the slide scrolls the content under the pointer as a normal two-finger scroll

#### Scenario: Taps still fire
- **GIVEN** the swipe setting is off and the 2-finger gesture is assigned to Mail
- **WHEN** the user anchors the thumb and taps with two fingers
- **THEN** Mail comes to the front

#### Scenario: Turning it back on
- **GIVEN** the swipe setting is off
- **WHEN** the user turns the switch on and then swipes
- **THEN** the switcher appears

### R12. With the setting off, only the tap blocking rules apply
While the swipe setting is off, clicks, scrolling and the system's trackpad swipes MUST be blocked only under the rules that apply without swipes: the 3-second blocking window, and Dock swipe blocking while a thumb is anchored and another finger is down.

#### Scenario: Clicks work after the blocking window
- **GIVEN** the swipe setting is off
- **WHEN** the user anchors the thumb, slides two fingers sideways for more than 3 seconds, then clicks
- **THEN** the click reaches the app under the pointer

### R13. The hint stays accurate
The launcher window's hint MUST mention swiping only while the swipe setting is on. When the switch changes while the window is open, the hint MUST update at once.

#### Scenario: Hint with the setting off
- **GIVEN** the swipe setting is off
- **WHEN** the user opens the launcher window
- **THEN** the hint describes the tap gestures and does not mention swiping

#### Scenario: Hint with the setting on
- **GIVEN** the swipe setting is on
- **WHEN** the user opens the launcher window
- **THEN** the hint mentions swiping

#### Scenario: Hint follows the switch
- **GIVEN** the launcher window is open and the swipe setting is on
- **WHEN** the user turns the switch off
- **THEN** the hint stops mentioning swiping at once

## Non-goals

- **Carrying over a saved switcher list.** The version with the list was never released, so no user has one.
- **Windows instead of apps.** ⌘-Tab switches apps, not windows; so does the switcher. Picking a specific window is a different feature.
- **Choosing or hiding apps from the switcher.** The point is to match ⌘-Tab with no setup. A per-app exclude list would bring back the list this plan removes.
- **Starting the selection on the previous app, as ⌘-Tab does.** The user asked for the selection to start on the frontmost app, so lifting without moving stays where you are.
- **Quitting or hiding apps from the switcher**, as ⌘-Tab allows with Q and H. The swipe has no keyboard.
- **Changing swipe recognition, travel, highlight, light tick, end behaviour, haptics or blocking with the setting on.** The selected app's name shown below its icon also stays. Only which apps show, their order and icon size change. Two deliberate exceptions, each stated by a requirement: R8 keeps a swipe with nothing to show blocked until the fingers lift, where plan 006 ended it early; R4 lets the rubber band add no dead zone at either end.
- **Reaching the far end of a very long row with a slow slide.** It may take a fast slide, since the switcher follows the cursor's pointer acceleration. There is no lift-and-reposition within one swipe, because lifting both fingers ends the swipe.

## Implementation Decisions

Three numbers from a probe (`.temp/planner/probes/switcher-order-probe`, run on this Mac with 14 regular apps and 66 other running processes) shape the decisions below. The private LaunchServices order call plus one keyed information read per app costs 1.4 ms warm and under 4 ms cold when asked only for the five keys it needs (10 ms when asked for everything); its per-app dictionary carries the pid, the application type, the bundle path, the bundle identifier and the display name; and the array holds only `Foreground` applications, none of the 66 others, even after an accessory app has made itself frontmost (the membership probe did exactly that). `AppCatalog.entry(at:)` costs about 5 ms per app, all of it in the Finder display-name lookup, so parsing one bundle per running app would stall the swipe's first frame by 70 ms with 14 apps. A running app's first icon load plus 80 pt draw costs about 25 ms per app (0.1 ms once drawn), so a cold row of 14 would stall 350 ms if drawn at the swipe.

1. **One port read answers both the frontmost app and the ⌘-Tab list.** `SystemActions.frontmostApp()` is replaced by `runningApps()`, returning a domain value `RunningApps` with two fields: `frontmost`, the active app as an `AppEntry` (nil when there is none, it has no bundle identifier or location, or it is Trackpad Launcher itself, exactly as the old read), and `apps`, the apps ⌘-Tab would show at that moment as `AppEntry` values in ⌘-Tab order, most recently activated first. `apps` may lack `frontmost` (a menu bar app with a window in front) and may fail to start with it only in a race; the core, not the adapter, composes the row. The read is a pull at the moment it is needed (a swipe's begin and end), never stored: the order changes with every activation and LaunchServices is its one source of truth. Entries are built at the adapter from what LaunchServices reports for the running process; their name is the name macOS shows for a running app (LaunchServices' display name, the same string as `NSRunningApplication.localizedName`), which is what the Dock and Force Quit show. The app pickers keep the Finder name from `AppCatalog.entry(at:)`; the two can differ for an app whose bundle name is not its file name ("Code" and "Visual Studio Code"). Plan 006 rejected a second name rule for the frontmost app; the measured cost of the first rule per running app, on the swipe's first frame, is why this plan accepts it. The row's identity is the running copy's location: two running copies of one bundle at two locations are two icons, as in ⌘-Tab.

2. **The real adapter reads LaunchServices through two private functions, resolved at runtime, and falls back to observed activations.** The whole running-apps read lives in one small platform type, `RunningAppsReader`, which `WorkspaceActions` creates once and delegates `runningApps()` to; it holds no window, so its tests construct it alone. Its initialiser takes the LaunchServices order (resolved by default; nil for the fallback), the type's one internal seam, used only by its own tests, and it exposes an internal `isTrackingActivations` so a test can tell which path it is on. The LaunchServices order is a value type that resolves `_LSCopyApplicationArrayInFrontToBackOrder` and `_LSCopyApplicationInformation` with `dlsym` from the LaunchServices already loaded by AppKit (no link flag, no entitlement, no permission; the app is not sandboxed), and is nil when either symbol is missing. Its one function returns the entries in order: the array for the default session, then one keyed information read per application serial number asking only for the pid, the application type, the bundle path, the bundle identifier and the display name. An entry is kept only when its type is `Foreground`, its pid is not this process and all three bundle fields are present; the probe showed the array never holds anything else, so the two filters are guards against a future macOS, not today's behaviour. From the probe, the shape that encodes the decision:

   ```swift
   // _LSCopyApplicationArrayInFrontToBackOrder(kLSDefaultSessionID = 0xFFFFFFFE) -> CFArray of ASNs, frontmost first
   // _LSCopyApplicationInformation(-2, asn, ["pid", "ApplicationType", "LSBundlePath", "CFBundleIdentifier", "LSDisplayName"]) -> CFDictionary
   // keep where ApplicationType == "Foreground" && pid != getpid()
   ```

   The frontmost app keeps its public read (`NSWorkspace.frontmostApplication`, own process excluded), turned into an entry from the running application's bundle identifier, localized name and bundle location. When the LaunchServices order could not be built, the reader answers from `NSWorkspace`'s running applications with the regular activation policy, ordered by a pure function over (pid, launch date) pairs and a recency list: the apps activated since Trackpad Launcher started, most recent first and only while still running, then the rest in launch-date order, undated ones last in their given order. The recency list is kept by an activation tracker that observes the workspace's did-activate notification and is seeded, when created, with the app then frontmost if it is a regular app (the most recently used app at start, which no later notification would report); it is created only when the order is missing, so the shipped path on today's macOS registers no observer. The source-scan test confines the two private symbol names to the LaunchServices order's file.

3. **The row rule lives in `Switcher`, with the frontmost app always at index 0.** `Switcher`'s initialiser takes the frontmost entry, the running entries and the trackpad, and builds the row as the frontmost entry followed by the running entries minus the one at the frontmost's location; it is nil when the row would hold fewer than two icons. `home` disappears: the selection is `clamp(round(travel / 12 mm), 0, count − 1)` and `selectsFrontmost` is "selected index 0". `follow` keeps at most a quarter icon (3 mm) of travel past either end for the rubber band, as today, and forgives it the moment the fingers turn back: on a frame that moves the travel back towards the row from past an end, the travel restarts at that end plus the frame's movement, so the next selection change comes the usual 6 mm from the turn, however far the fingers went past the end, and the stretch is 0 from that frame on (the highlight's last spring settles it on the end icon). That is R4's "no extra travel to undo the stretch", applied at both ends, and it replaces plan 006's rule, under which 3 mm of the way back undid the band first. `follow` keeps the last reported travel instead of a dropped total; `position` and `stretch` keep their formulas with home 0.

4. **The swipe in the model reads the running apps twice and never restarts recognition for a null row.** On `began` (gestures active, no switcher up): one `runningApps()` read; when `frontmost` is nil or the row would be a single icon, no switcher is created and the swipe is left to run its course: the recognizer stays in its swiping state, so clicks, scrolling and Dock swipes stay blocked until the fingers lift, `moved` events find no switcher and do nothing, and `ended` does nothing. This replaces plan 006's mechanism of ending a null-row swipe by re-running the trackpads, which is what R8 asks for and removes a device restart from a user gesture. On `ended` with a switcher up: index 0 is silent and leaves the window alone; otherwise a second `runningApps()` read decides whether the selected entry's location is still among the running apps (the frontmost or the list); if so, the gesture haptic plays, the app is brought to front through the unchanged `bringToFront` (a Dock click: launch, unhide, restore, reopen, activate, change Space) and the window closes; if not, nothing happens and nothing plays, so an app that quit mid-swipe is never relaunched. The row itself is a value fixed at `began`, so an app that launches mid-swipe never appears in it. `reconcile` keeps clearing the switcher when it re-runs the trackpads (hot-plug, wake, settings), and its documentation drops the null-row restart.

5. **The switcher list is retired end to end.** `Settings.switcherList` and `SwitcherList`, `SwitcherRow` and `Launcher.switcherRows`, the add, remove and move intents and their reconcile-on-emptiness rule, `InstalledApps.addMenu(listing:)` and the `.listed` item state, the app menu button's pull-down form (the button keeps its one pop-up form; the `Form` enum goes), the section's row list, drag reorder, hover and context-menu removal, and Add app… are all deleted; the Other… chooser serves the gesture rows only. `Settings` decoding already ignores a key this build does not know, so a record from the unreleased list build loads without a migration and nothing is written for it. `AppCatalog.locate` keeps its gesture-row callers and is no longer on the swipe path. The launcher window's height cap goes with the scrolling region it served: with no list the content is fixed-height again and fits every display, and a cap with nothing to scroll would only clip Quit. The shell no longer refits on a list count.

6. **The swipe setting is one more `Settings` field, read by `reconcile`.** `Settings.isSwipeOn`, default true, keyed by its field name permanently and decoded as true when absent, so a record from any earlier build loads with the swipe on. `Launcher.isSwipeOn` exposes it; `setSwipe(on:)` ignores a no-change call, saves at once and reconciles. `Run.swipes` becomes `settings.isSwipeOn`, so the recognizers are rebuilt with swipes on or off through the existing `run(_:handMode:blockClicks:swipes:)`, and a change ends any swipe in progress exactly as a hand-mode change does. With swipes off the recognizer already treats a pair's sideways drag as a spoil, so no switcher can appear, the slide scrolls once the blocking window has passed, taps are untouched, and the recognizer's two blocking flags fall back to the thumb rules alone: that is R11 and R12 by construction of plan 006's recognizer. Until the setting exists (the first slice), `reconcile` passes `swipes: true`.

7. **The hint is one copy value with a swipe flag, derived by the model.** `Copy.gestureHint(for:swipe:)` returns today's sentence when the swipe is on and the same sentence without its ", or swipe left or right with 2 fingers to switch apps" tail when it is off. `Launcher.gestureHint` derives it from the hand mode and the swipe setting, so the hint view renders one string and a test reads the very string the window shows; the shell's refit observation includes `isSwipeOn`, since the hint's height changes with it.

8. **The switcher section becomes one setting row.** The swipe illustration (still mirrored in left-hand mode), the title "Swipe to switch apps", a spacer and a switch bound to `isSwipeOn`, laid out like the Launch animation row.

9. **Icons are drawn before any swipe, from the running apps, only while the swipe is on.** `SwitcherPresenter` draws the 80 pt icons of every running app with the regular activation policy at start (waited for, the existing first-pass exception), redraws off the main actor for each app the workspace reports launched (a push, never a poll) and for every running app on an appearance change, drops an app's icon when the workspace reports it terminated, and at a swipe's begin reads the cache, drawing on the main actor only for an app whose pass has not finished or that no pass covers (a frontmost menu bar app, drawn from the running app's already-loaded icon as today). While the swipe setting is off there is nothing to draw for: the passes stop, the two workspace observers are removed and the cache is emptied; turning it on runs a pass off the main actor and observes again. The presenter reads `NSWorkspace` itself: AppKit types stay in the shell, and the model keeps no running-apps state. The cache is keyed by location and bounded by the apps running now.

10. **A pure row layout scales the panel to the display.** `SwitcherRowLayout`, a value in the core beside `Switcher`, takes the icon count and the display width and gives the scale factor `min(1, (displayWidth − 2 × 28) / (n × 80 + (n − 1) × 20))` and the sizes derived from it: icon side 80 × scale, gap 20 × scale, pitch, highlight side 92 × scale, row width and panel width (row plus the 28 pt padding each side), and one function, `centreX(at:)`, giving the horizontal centre of a position in icons (padding + half an icon + position × pitch), which the panel uses for both the icon layers (integer positions) and the highlight (any position), so the two cannot drift apart. A display width that is not positive means no constraint (scale 1). The presenter builds the layout from the pointer's display when it opens the row and hands it to the panel, which positions its layers from it; the rubber-band spring offset uses the layout's pitch; the selected icon's 1.12 factor, the name's font and the vertical paddings do not scale. The core's travel (12 mm, or 100 cursor points, per icon) never sees the layout, so the finger travel per icon is unchanged by construction. The 80 pt bitmaps are shown smaller by the layer's trilinear minification. There is no lower bound on the icon size, as in ⌘-Tab.

11. **Documentation.** `docs/domain-model.md`: *Switcher list* removed; *Running apps* and *Swipe setting* added; *Swipe*, *Switcher*, *Frontmost app*, *Launcher window*, *Recent apps*, *Feedback* and *Click blocking* follow this plan. `docs/architecture.md`: the platform module's list names the two private LaunchServices functions, the Concurrency paragraph's switcher-icon sentence describes the pre-drawn running apps, and the Privacy paragraph records the `dlsym` resolution and the fallback. `docs/product-overview.md`: the two edits the Solution names. All three are edited with this plan so the review reads the docs as they will be.

## Testing Decisions

### Strategy

Seven seams: four existing (`Launcher` through `World`, the `Switcher` value, the `Copy` value, the recognizer) and three new (the `SwitcherRowLayout` value, the platform's `RunningAppsReader` through its one `read()`, and the fallback's pure order function). The high seam is `Launcher` through `World` in `LauncherKit/Tests/LauncherCoreTests/` (the real model, recognizer, click and scroll filters, catalog over a temp tree and settings store over a throwaway suite), where `RecordingSystemActions` answers `runningApps()` from two fields a test sets, `frontmost: AppEntry?` and `running: [AppEntry]`, replacing `frontmost: URL?`; `World.makeFrontmost(_:)` stores the catalog's entry, a new `World.makeRunning(_:)` sets the ⌘-Tab list from entries (with an overload over installed app names), and `World.switcherWorld` becomes Safari, Mail, Slack and Notes installed and running in that order with Safari frontmost and the launcher started, which keeps the fixture's row identical to today's so the existing on-screen rows keep their assertions. The seam observes `launcher.switcher` (`row`, `selected`, `selectedApp`, `selectsFrontmost`, `position`, `stretch`), `isSwipeOn`, `gestureHint`, `isWindowOpen`, `system.broughtToFront`, `hardware.pulses`, `pressVerdicts`, `scroll(_:)`, `runCount` and `running`. New rows resemble `SwitcherOnScreenTests` and `PersistenceTests` line for line. What it misses: what LaunchServices really answers, the window and the panel on screen, and the Dock-click semantics of `bringToFront` (unchanged code).

The two pure values are tested on their own, as `SwitcherTests` does today: `Switcher` through `follow` and its derived properties, and the new `SwitcherRowLayout` through its initialiser, in `LauncherCoreTests`. `Copy` is read as a value in `CopyTests`. The recognizer seam (`GestureRecognizer.step` through the `Fixtures.swift` helpers, as in `DockSwipeBlockingRecognizerTests`) proves the swipes-off blocking flags.

The adapter's half is proven in `LauncherKit/Tests/LauncherPlatformTests/` at `RunningAppsReader.read()`, the type `WorkspaceActions` delegates the port's `runningApps()` to (constructing `WorkspaceActions` itself would create the launch overlay's window, which no platform test does), in the style of `SpotlightLastUsedTests` (the real reader against the system's own other reader): with the LaunchServices order resolved, against `NSWorkspace.runningApplications` filtered to the regular activation policy, enabled only when the private symbols resolve on the test Mac; and built without the order, whose activation tracker is fed by posting the workspace's own did-activate notification on `NSWorkspace.shared.notificationCenter` with a real `NSRunningApplication`, delivered synchronously to a main-actor observer posting from the main thread. The fallback's order function is a pure value tested on literal (pid, launch date) pairs.

Faked: nothing we own. The system boundaries behind in-memory adapters are the ones already behind them (hardware, preferences, access, the system actions, the scanner). The clock is the frame timestamps. The order beyond "frontmost first" can only be judged against ⌘-Tab by eye; that is a hardware check in S1, not a test.

Existing tests that go with the list: both suites in `SwitcherListTests.swift` (`LocateTests` moves beside the other catalog tests), the two Add app… menu rows in `RecentAppsTests` (the second one's row-menu assertion, `["Finder", "Mail", "✓ Slack", "—", "Other…", "None"]`, stays as its own row), and in `SwitcherOnScreenTests` the rows `aListedAppInTheTrashIsLeftOut…`, `theNextSwitcherUsesTheNewOrderAlsoAfterARelaunch`, `anEmptyListRecognisesNoSwipe…`, `aSwipeWithNothingToShowEndsFromMain…` and `anEditThatFlipsTheListsEmptiness…`, each replaced by a row below. Amended: `SwitcherTests`' helper and every row that starts with the selection in the middle of the row (`frontmost: slack`, home 1), which is impossible without `home`: `travelPastAnEndIsKeptOnlyUpToAQuarterIcon…` becomes T9 and `theSelectionMovesBackUnderTheSameRule` reads its travels from home 0 (from 18 mm back to 6 and −6); `identityIsTheBundleIDNotTheLocation` is inverted into T23; `theRowIsTheSwitcherListInWindowOrder…` (becomes T1 and T2), `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored` (its `addToSwitcher` set-up becomes `makeRunning`), `noReadableFrontmostAppShowsNothing…` (folded into T14, nil case only: the "Notes.txt" case now lives in the adapter), the four `PersistenceTests` default rows gaining `isSwipeOn`, and `CopyTests`.

### Test scenarios

`switcherWorld` unless a row says otherwise: Safari, Mail, Slack, Notes running in that order, Safari frontmost, surface `macBook14`, right-hand thumb at (10, 10) mm, two fingers landing at (62, 45) mm; `swipe(3.5, …)` begins the swipe with its first 3.5 mm slide, after which travel counts from about 0. "World" is `Launcher` through `World`.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R2 | World | Running Safari, Mail, Notes (Safari frontmost), started, no switch made yet. The user swipes 3.5 mm. Then the row's names are Safari, Mail, Notes in that order, the selected app is Safari and `selectsFrontmost` is true. | R2 scenario "Most recently used comes next": "the row starts Safari, Mail, Notes" (R2's "Order known right after start" is proved by T4 and S1's hardware step: the LaunchServices order needs no tracking, so this seam cannot observe it) |
| T2 | R1, R2 | World | Bartender installed and frontmost but not in the running list (a menu bar app with a window in front); running Safari, Mail. Swipe 3.5 mm. Then the row is Bartender, Safari, Mail and Bartender is selected. A second case: frontmost Mail with running Safari, Mail, Notes (the list and the active app disagree in a race). Then the row is Mail, Safari, Notes. | R1 exception and R2 "Frontmost menu bar app": "that app sits at the left end, followed by the ⌘-Tab apps in order" |
| T3 | R2 | World | Swipe one icon right (3.5 + 12 mm) and lift, so Mail comes to the front; the adapter now answers running Mail, Safari, Slack, Notes with Mail frontmost. Swipe again 3.5 mm. Then the row starts Mail, Safari: the model read the order afresh rather than keeping the last row. | R2 scenario "Order follows the last switch": "the row starts Mail, Safari" |
| T4 | R1, R2 | Platform: `RunningAppsReader.read()` with the LaunchServices order | The reader built with the order on this Mac (test enabled only when both private symbols resolve); `isTrackingActivations` is false. The test takes the workspace's regular-policy set, reads once, takes the set again, and ends without asserting if the two sets differ (an app launched or quit meanwhile; the workspace's list is a snapshot refreshed by the run loop while LaunchServices is live). Otherwise the set of (bundle identifier, location) in `apps` equals that set: every Dock app whether hidden, minimised or windowless, no menu bar app, not the test process; each entry's name equals that running application's `localizedName`; and when `NSWorkspace.shared.frontmostApplication` is a regular app, `frontmost` is its entry and `apps.first` is at its bundle location. | R1 "every running app that appears in the Dock" is Apple's regular activation policy (`NSApplication.ActivationPolicy.regular`, "the application is an ordinary app that appears in the Dock"); R2 "the frontmost app at the left end" |
| T5 | R2 | (a) Platform: fallback order value; (b) Platform: `RunningAppsReader.read()` without the LaunchServices order | (a) Pure: recency [c, a] (c most recent), running [(a, t1), (b, t3), (c, t2), (d, t0), (e, nil)] with t0 < t1 < t2 < t3. Then the order is c, a, d, b, e. With recency [z, c] where z is not running: c, d, a, b, e. With recency [c] alone (the seed): c, d, a, b, e. With an empty recency: d, a, c, b, e. (b) Real: the reader built without the order; `isTrackingActivations` is true. Read at once, in the same statement sequence as the build (no real activation can land between). Precondition, not the proof: the set of (bundle identifier, location) in `apps` equals the workspace's regular-policy set. Assertions: when `NSWorkspace.shared.frontmostApplication` is a regular app, `apps.first` is at its bundle location (the seed). Then the test posts `NSWorkspace.didActivateApplicationNotification` on `NSWorkspace.shared.notificationCenter` with the *last* entry of that read under `NSWorkspace.applicationUserInfoKey` (so the posted app is never the one already first, which a real activation could not distinguish), and reads again at once: that app is `apps.first` and the others keep their previous relative order. A second post for the entry now last moves it first and the previously posted app second. The test needs at least three regular apps on the Mac; otherwise it is skipped, not red. | R2: "apps whose order is unknown MUST go after the known ones, in the order they launched"; the glossary's *Running apps*: "the app in front when Trackpad Launcher started and the apps activated since come first, most recent first, and the rest follow in the order they launched" |
| T6 | R3, R7 | World | Window open. Swipe 3.5 + 12 mm (one light tick, Mail selected) and lift. Then Mail is brought to front, the pulses are exactly [light tick, gesture], no launch animation plays, the switcher is gone and the window is closed. | R3 scenario "One step right selects the previous app": "Mail comes to the front with the gesture haptic"; R7 "as today" (plan 006 R8: closes the window) |
| T7 | R3 | World | Window open. Swipe 3.5 + 4 mm and lift. Then nothing is brought to front, no pulse plays, the window is still open. | R3 scenario "Lift without moving an icon": "nothing happens and no haptic plays" |
| T8 | R3 | World | Hand mode set to left, thumb at (114.8, 10) mm. Swipe right 3.5 + 12 mm and lift. Then Mail is brought to front with one light tick before the gesture haptic. | R3 scenario "Same direction in left-hand mode": "Mail comes to the front, as in right-hand mode" |
| T9 | R4 | Switcher value | Row Safari, Mail, Slack, Notes. `follow(−30)`: travel −3, selected 0, `selectsFrontmost`, stretch below 0 and above −0.2. `follow(−40)`: still travel −3 (the band is the most ever kept). `follow(−35)`: travel 5, selected 0, stretch 0 (the band is forgiven on the turn). `follow(−34)`: travel 6, selected 1. From rest again `follow(−300)` then `follow(−294)`: selected 1, the same 6 mm back however far past the end. At the right end from rest: `follow(60)`: travel 39, selected 3, stretch above 0 and below 0.2; `follow(54)`: travel 30, selected 3 (the midpoint rounds away from zero, as today); `follow(53)`: travel 29, selected 2. `follow(0)` from rest: stretch 0. | R4 scenario: "after the turn, the selection moves to the next app after the usual travel for one icon, with no extra travel to undo the stretch", and "MUST NOT add a dead zone"; 6 mm is the half icon at which the selection changes from rest today (`SwitcherTests.theSelectionIsTheNearestIconAndNeverPassesAnEnd`: 6.0 → 1, 5.9 → 0); the 3 mm band is `GestureRules.switcherMaxOvershoot` × 12, unchanged |
| T10 | R4 | World | Swipe 3.5 then −30 mm without lifting: Safari selected, stretch below 0, no light tick. Continue +5 mm: still Safari, stretch 0. Continue +2 mm more: Mail, one light tick (7 mm from the turn; plan 006's rule would have needed 9). Lift: Mail is brought to front. | R4 scenario: "the selection stays on the frontmost app; after the turn, the selection moves to the next app after the usual travel for one icon, with no extra travel to undo the stretch" |
| T11 | R5 | World | Running Safari, Mail, Notes. Swipe 3.5 + 24 mm (Notes selected, two ticks). The adapter now answers running Safari, Mail (Notes quit). Lift. Then nothing is brought to front, the pulses are the two light ticks only, the switcher is gone. | R5 scenario "App quits mid-swipe": "nothing happens, no haptic plays, and Notes is not launched" |
| T12 | R5 | World | Swipe 3.5 mm. The adapter now answers running Calendar, Safari, Mail, Slack, Notes with Calendar frontmost (Calendar launched). Continue +36 mm. Then the row is still Safari, Mail, Slack, Notes, Notes is selected, three ticks; lift brings Notes to front. | R5 scenario "App launches mid-swipe": "Calendar does not appear in the row" |
| T13 | R7 | World | Swipe 3.5 + 12 mm (Mail), then −12 mm back to Safari; the adapter now answers Mail frontmost with running Mail, Safari, Slack, Notes (Mail came forward). Lift. Then nothing is brought to front, the pulses are the two light ticks only, the window is as it was. | R7 scenario "Lifting on the starting app": "nothing happens and no haptic plays" |
| T14 | R8 | World | Access granted, running Finder only and frontmost, thumb rested 4 s before two fingers land (so only a swipe could block). Slide 3.5 mm: no switcher and `runCount` unchanged (no restart). Press and slide 12 mm, lift: the press verdicts are [drop, drop], nothing brought to front, no pulse; afterwards `scroll(.fingers(.began))` passes. Second case, same hand with `makeFrontmost(nil)` and running Safari, Mail: the same. | R8: "no switcher … the swipe itself still happens: clicks and scrolling stay blocked until the fingers lift"; scenario "Only one app running": "no switcher appears and nothing happens on lift" |
| T15 | R6 | Layout value | (5 icons, 1512 pt): scale 1, icon 80, gap 20, pitch 100, highlight 92, panel width 536; `centreX(at: 0)` 68, `centreX(at: 1)` 168, `centreX(at: 2.5)` 318. (14, 1512): scale 1 (row 1380 fits 1456). (15, 1512): scale 1456 / 1480, icon 78.70, gap 19.68, panel width 1512 (within 0.01). (30, 1512): icon 39.09, gap 9.77, panel width 1512; `centreX(at: 0)` 47.54 and `centreX(at: 29)` 1464.46, so the first icon's left edge is 28 and the last icon's right edge 1484 (within 0.01). (30, 0): scale 1. | R6: "80 pt when the whole row fits", "icons and gaps … scale by the same factor", "fits on that display, in one row"; worked example on a 1512 pt display with the panel's 80 / 20 / 92 / 28 constants: 28 + 40 = 68; 28 + 40 × 0.48859 = 47.54; 1512 − 28 − 19.54 = 1464.46 |
| T16 | R6 | World | Thirty apps running (Safari frontmost). Swipe 3.5 + 24 mm. Then the third app is selected with two light ticks, as with four apps. A regression guard: the core never sees the layout, so this holds by construction today; the row pins it against a future coupling. | R6: "The finger travel per icon MUST NOT change with the icon size"; `GestureRules.switcherStepMM` = 12 |
| T17 | R10 | World, store | A fresh World started: `isSwipeOn` is true. `setSwipe(on: false)`, then `relaunch()` (a new launcher over the same suite, the force-quit case): false. A record saved by the build before the switcher (`Fixtures.recordSavedByPlan002`) loads with the swipe on and its assignments intact. `everySettingsFieldSurvivesTheStore` with `isSwipeOn = false` round-trips. | R10 scenarios "Fresh install" and "Off survives a force-quit" |
| T18 | R10, R11, R13 | World | Window open. `gestureHint` is T22's swipe-on string. `setSwipe(on: false)`: `isSwipeOn` is false and `gestureHint` is T22's swipe-off string at once, the window still open. Swipe 3.5 + 12 mm and lift: no switcher at any point, nothing brought to front, no pulse. `setSwipe(on: true)`: `gestureHint` is the swipe-on string again; then the same swipe: the row Safari, Mail, Slack, Notes shows and Mail is brought to front. | R10 "A change MUST apply to the next swipe"; R11 scenario "Turning it back on"; R13 scenario "Hint follows the switch": "the hint stops mentioning swiping at once", with T22's strings |
| T19 | R11, R12 | World | Access granted, `setSwipe(on: false)`. Fresh thumb, two fingers slide 20 mm sideways within the window: no switcher; `scroll(.fingers(.began))` is dropped and a press is dropped (the 3-second rule still applies). Then a thumb rested 4 s, two fingers slide 20 mm, press, lift: no switcher, the press verdicts over the one World are now [drop, drop, pass, pass], `scroll(.fingers(.began))` passes, nothing brought to front. | R11 scenario "Sliding does nothing": "after the blocking window the slide scrolls the content … as a normal two-finger scroll"; R12 scenario "Clicks work after the blocking window" |
| T20 | R11 | World | `setSwipe(on: false)`, Mail assigned to the 2-finger gesture. Two-finger tap. Then Mail is brought to front with the gesture haptic. | R11 scenario "Taps still fire": "Mail comes to the front" |
| T21 | R12 | Recognizer | Recognizer built with swipes off. Thumb lands at 0 ms; two fingers land at 100 ms and slide 40 mm sideways over 5 s; all lift. Then no swipe phase is ever reported; `blocksDockSwipes` is true on every frame with a finger down through the fifth second; `blocksClicks` is true on those frames before 3 s and false after. | R12: "the 3-second blocking window, and Dock swipe blocking while a thumb is anchored and another finger is down" |
| T22 | R13 | Copy value | `gestureHint(for: .right, swipe: true)` is "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers to switch apps"; `swipe: false` is "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app"; the left-hand variants say "top-right". | R13: "mention swiping only while the swipe setting is on"; today's copy in `CopyTests` |
| T23 | R1, R2 | World | Safari and Slack installed in Applications, a second Slack copy installed in Downloads (`makeRunning` takes entries, so a copy outside the catalog's roots can run); running Safari, Slack (Applications), Slack (Downloads); frontmost the Downloads copy. Swipe 3.5 mm. Then the row is Slack (Downloads), Safari, Slack (Applications): three icons, the two Slacks one bundle identifier at two locations, the frontmost copy selected. | R1 "every running app that appears in the Dock": each running copy is its own process with its own Dock tile and ⌘-Tab icon; decision 1's identity by location (inverts `SwitcherTests.identityIsTheBundleIDNotTheLocation`) |

### Verified without a test

- **R9** (the window's switcher section): no test target renders the SwiftUI window. Manual: open the launcher window; the section shows the swipe illustration, "Swipe to switch apps" and a switch at the right end, aligned with the Launch animation row's switch; no app rows and no Add app…; select Left hand and the illustration mirrors. Plus `grep -rn "addToSwitcher\|SwitcherList\|switcherRows\|Add app\|pullDown\|addMenu" LauncherKit/Sources` returns nothing, which proves the list's code is gone rather than hidden.

## Further Notes

- **The null-row swipe changed shape.** Plan 006 ended a swipe with nothing to show by re-running the trackpads from the main actor so nothing stayed blocked; its test asserted passing clicks. R8 here says the swipe still happens and stays blocked, so that mechanism and its test go (T14 replaces it). The case is also rarer now: it needs a single Dock app running, or no readable active app.
- **R4 is read literally, for the owner to confirm.** Today's rubber band keeps a quarter icon (3 mm) of travel past either end, and 3 mm of the way back undoes it before the selection can move: a dead zone, which R4 forbids ("MUST NOT add a dead zone", "no extra travel to undo the stretch"). So the band is forgiven on the turn, at both ends, and "the usual travel for one icon" is read as the 6 mm at which the selection changes from rest (half an icon), not the 12 mm pitch. The visual band is unchanged: the highlight springs while the fingers push past the end and settles on the end icon. T9 and T10 pin the numbers; if the owner meant plan 006's rule after all, they revert to 9 mm and the band is kept on reversal.
- **Names.** The switcher labels the selected app with the name LaunchServices shows for the running app; the pickers keep the Finder name. They agree for every app on this Mac but one ("Code" / "Visual Studio Code"). No requirement asked for the change; the Solution now records it, since the Finder name costs 5 ms per app on the swipe's first frame and is not cached by `FileManager.displayName(atPath:)`. `URLResourceValues.localizedName` is cached after a first 4 ms read, so a future plan could warm it off the main actor if one name is wanted everywhere.
- **The LaunchServices call is private.** It has existed from 10.x through macOS 26 and the Dock depends on it, but Apple may remove it; the LaunchServices order fails to build rather than crash (every symbol resolved up front, like `MultitouchSupport`), the fallback keeps the feature usable, and T4 is enabled only where the symbols resolve so a future Mac without them turns the test off rather than red.
- **Why the model reads the order and the presenter reads the apps.** The order is needed only at a swipe's begin and end and changes on every activation: a pull from the source of truth, no state. Icon readiness is a shell concern tied to AppKit's notifications and types; pushing the running apps through the model only to feed the presenter would add state the model never decides on.
- **The probes and their numbers** stay under `plans/008-recent-apps-switcher/.temp/planner/probes/switcher-order-probe/` (`main.swift` for the order and the costs, `names.swift` for the name sources, `membership.swift` for what the array holds; sources only, the compiled binaries are not committed), as plans 003 and 006 kept theirs.
- **Cost on the swipe path after this plan:** one LaunchServices read (1.4 ms warm, under 4 ms cold, for 14 apps) and cache hits for icons; a second read at the lift. The first swipe after launch waits for nothing: the icon pass ran at start.

## Slices

S1 lands the feature's core and its riskiest assumption first: the switcher shows the running apps in ⌘-Tab order through the private LaunchServices call, and the list is gone everywhere, which is the bulk of the model, shell and test changes and the whole of the documentation. S2 adds the fallback R2 prescribes for a macOS that stops revealing the order; S3 pre-draws the icons so the first swipe shows at once; S4 shrinks long rows; S5 adds the switch. S2, S3 and S4 are independent of each other and need only S1; S5 needs S1 and S3 (it gates S3's passes on the setting).

### S1: The switcher shows the running apps in ⌘-Tab order

**What to build:** From the user's side: with the thumb anchored, sliding two fingers shows every Dock app that is running, in ⌘-Tab's order from the first swipe after Trackpad Launcher starts, the active app at the left end and selected and labelled with the name macOS shows for it; sliding right reaches older apps; the left end is a hard stop whose rubber band adds no dead zone; lifting brings the selected app forward as before, silently when it is the starting app or one that quit meanwhile; a menu bar app in front sits at the left end; with only one Dock app running nothing shows and the fingers stay blocked until they lift; the launcher window's switcher section is the illustration and its title alone (no rows, no Add app…), and old settings load. Underneath: decisions 1, 3, 4, 5 and 11, and decision 2 without its fallback: `RunningApps` and `runningApps()` on the port; `RunningAppsReader` in the platform module over the LaunchServices order resolved with `dlsym`, answering an empty list when the order is missing (S2 fills that in), with the source-scan confinement of the two private symbol names; `Switcher`'s row rule without `home` and its band forgiven on the turn; the model's two reads and null-row behaviour; the list's removal from settings, model, menus, views, the shell's icon targets and the window's height cap; the `World` fixtures (`makeRunning` over entries); and the three documents. The presenter keeps drawing a row's icons as today (the frontmost from the running app's loaded icon, the rest at the swipe when not cached) until S3. `reconcile` passes `swipes: true`.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2 (the ⌘-Tab order; the fallback is S2), R3, R4, R5, R7, R8.

**Test scenarios:** T1, T2, T3, T4, T6, T7, T8, T9, T10, T11, T12, T13, T14, T23.

- [ ] Every row is green through `Scripts/test.sh`, with the list's tests removed and the amended rows named in the Strategy passing; T4 runs (not skipped) on the development Mac; the suite stays synchronous.
- [ ] `grep -rn "addToSwitcher\|SwitcherList\|switcherRows\|SwitcherRow\b\|Add app\|pullDown\|addMenu\|screenMargin" LauncherKit/Sources TrackpadLauncher` and `grep -rnF "frontmostApp(" LauncherKit/Sources TrackpadLauncher` both return nothing (the first catches the list and the height cap, the second the old port read without matching `frontmostApplication`); the two private symbol names appear only in the LaunchServices order's file (the source-scan test's new confined entries).
- [ ] On hardware, the "Matches ⌘-Tab" scenarios of R1 and R2: hold ⌘, press Tab, note the apps and their order, Esc, release ⌘, then swipe; the row holds the same apps in the same order, plus the frontmost app at the left when ⌘-Tab did not show it (check once with a menu bar app's window in front). Repeat as the first swipe after launching Trackpad Launcher: the order already matches. Hide Mail and minimise Notes' only window first: both are in the row. Bring a menu bar app's window to front, switch away, swipe: it is absent. Use Other…, cancel, swipe: Trackpad Launcher is absent.
- [ ] On hardware, the R7 lift scenarios through the unchanged Dock-click `bringToFront`: a hidden app unhides, a minimised window restores, a windowless app (Preview with all windows closed) opens a window, a full-screen app on another Space takes the display there; each with the gesture haptic; lifting on the starting app after another app came forward is silent.
- [ ] On hardware, pushing left past the frontmost app and turning back: the highlight stretches and settles, and the next app is selected after the same short slide as from rest, with no extra travel.
- [ ] `docs/domain-model.md`, `docs/architecture.md` and `docs/product-overview.md` are committed as this plan edited them (the architecture's fallback clause describes S2, which follows); the probe sources stay under `.temp`, without binaries.

### S2: The order survives a macOS that stops revealing it

**What to build:** From the user's side: on a macOS without the private LaunchServices functions, the row still shows every running Dock app, the app in front when Trackpad Launcher started and the apps switched to since first, most recent first, then the rest in launch order. Underneath: decision 2's fallback: the pure order function, the activation tracker seeded with the frontmost regular app and fed by the workspace's did-activate notification, built only when the LaunchServices order is missing, and the reader's `isTrackingActivations`.

**Blocked by:** S1 (the reader and the port).

**Requirements:** R2 (the fallback order).

**Test scenarios:** T5.

- [ ] Every row is green; T4 gains its `isTrackingActivations` false assertion here, so the shipped path on the development Mac provably registers no workspace observer.
- [ ] Manual, through the internal seam: a debug run with the LaunchServices order forced nil shows the row with the app in front at launch first, then each app switched to since, most recent first, then the rest in launch order.

### S3: The first swipe shows at once

**What to build:** From the user's side: the first swipe after launching Trackpad Launcher with a dozen apps running shows the row with no perceptible delay, and an app launched afterwards shows its icon on the next swipe without a stall. Underneath: decision 9: the presenter's icon pass over the running Dock apps at start, off the main actor on each launch notification and on an appearance change, eviction on each termination notification, and the swipe-time draw kept only for an app no pass covers.

**Blocked by:** S1 (the row of running apps).

**Requirements:** None new; keeps plan 006 R10's "appears as the swipe begins with no perceptible delay" true for R1's row.

**Test scenarios:** None (the presenter is shell code with no test target; the model is untouched).

- [ ] Every row is green.
- [ ] On hardware: with a dozen apps running, the first swipe after launch shows the row with no perceptible delay; an app launched afterwards shows its icon on the next swipe; an app quit and relaunched shows its icon; switching light and dark appearance redraws the icons by the next swipe.

### S4: Many apps shrink to fit the display

**What to build:** From the user's side: with more Dock apps running than fit the pointer's display at 80 pt, the row shrinks its icons and gaps by one factor so every app shows in one row within the display, and moving one icon takes the same finger travel as with five apps. Underneath: decision 10: `SwitcherRowLayout` in the core with its `centreX(at:)`, the panel laying out icons and highlight from it (icon, gap, highlight, pitch, panel width), the presenter building it from the pointer's display at open and using its pitch for the spring.

**Blocked by:** S1 (the row that can now be long).

**Requirements:** R6.

**Test scenarios:** T15, T16.

- [ ] Every row is green; the layout's constants (80, 20, 92, 28) live in `SwitcherRowLayout` and nowhere else in the panel, and the panel positions icons and highlight through `centreX(at:)` alone.
- [ ] On hardware on the 14" display (1512 pt): with 14 Dock apps running the icons are 80 pt; with 15 or more the row shrinks and spans the display within its padding, in one row, the highlight centred on the selected icon and scaling with it, the name below unchanged in size; a swipe across two icons still takes the same finger movement as with five apps.

### S5: The swipe switch

**What to build:** From the user's side: the switcher section shows one row, the swipe illustration, "Swipe to switch apps" and a switch at the right, on by default; off, two fingers sliding under the thumb are not a swipe (no switcher, and the slide scrolls once the blocking window has passed), taps work as before, only the tap blocking rules apply, and nothing is drawn or observed for a switcher; the change applies to the next swipe and survives a force-quit; the hint stops mentioning swiping while the switch is off and updates as the switch flips. Underneath: decisions 6, 7 and 8 and decision 9's gating: `Settings.isSwipeOn`, `Launcher.isSwipeOn`, `setSwipe(on:)` and `gestureHint`, `Run.swipes` from the setting, `Copy.gestureHint(for:swipe:)` and the hint view rendering `gestureHint`, the section's switch row, the shell's refit on `isSwipeOn`, the presenter's passes and observers following `isSwipeOn`.

**Blocked by:** S1 (the section's shape; `reconcile`'s `swipes` source), S3 (the passes to gate).

**Requirements:** R9, R10, R11, R12, R13.

**Test scenarios:** T17, T18, T19, T20, T21, T22.

- [ ] Every row is green; `Settings` has `isSwipeOn` with its field-name key and absent-means-true decoding, and `reconcile` is the only reader of it for `swipes`.
- [ ] The R9 check under Verified without a test is ticked, including its grep.
- [ ] On hardware: with the switch off, a thumb-anchored two-finger slide shows nothing and, after three seconds, scrolls the page under the pointer; a two-finger tap still opens its app; turning the switch on makes the next swipe show the switcher with every icon ready; the hint loses and regains its swipe clause as the switch flips while the window is open, and the window refits to the shorter hint.
