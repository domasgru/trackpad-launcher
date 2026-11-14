# Plan: Automatic updates switch and Check for updates

## Problem statement

Trackpad App checks for updates on its own, at each login start, if it can write to its own bundle, and each time the settings window opens, and installs a newer version silently at login. The user cannot stop this. A user who wants an app that makes no network calls has no way to get one. A user who wants the newest version now has no way to ask for it either: the update card shows only when the window's own check happened to find something. The settings window also never says which version is running. Progress labels today show static dots, so a long check or download looks stuck.

## Solution

The settings window gets a new row at the end of the thumb corner group: an *Automatic updates* switch, the running version, and a *Check for updates…* button.

- With the switch on (the default), updates work as today, apart from the row's button and the animated dots.
- With the switch off, Trackpad App makes no network request of its own. The only requests are those a *Check for updates…* click and its alert's *Update* start, plus a download already under way when the switch was turned off.
- *Check for updates…* works whatever the switch says. It reads the update list once and answers in a standard macOS alert: an update is ready to install, the app is up to date, or the check failed.
- Labels that show progress (*Checking…*, *Updating…*) animate their dots.

The product overview's privacy statement and the domain model's *Update check*, *Login update* and *Update card* entries change to match this feature.

## Requirements

Terms: *update check*, *newer version*, *login update*, *update card*, *hand-over*, *settings window*, *thumb corner group*, *mixed trackpads* and *no trackpad notice* keep their meaning from `docs/domain-model.md`. A *manual check* is the update check a *Check for updates…* click starts. An *update-capable copy* is a copy signed with a Developer ID that lies in /Applications, the only kind that checks today.

### R1. The updates row ends the thumb corner group
The settings window MUST show a new row as the last row of the thumb corner group, directly below the *Hide background apps* switch. The row holds, top to bottom: the title *Automatic updates* at the leading edge with its switch at the trailing edge; the line "Current version: <version>"; and a bordered *Check for updates…* button aligned to the leading edge. The no trackpad notice, when it applies, and the *Quit Trackpad App* and *Close* buttons stay below the group.

#### Scenario: Row position with a trackpad connected
- **GIVEN** a Mac with a trackpad connected
- **WHEN** the user opens the settings window
- **THEN** the *Automatic updates* row is the last row of the thumb corner group, under *Hide background apps*, and the *Quit Trackpad App* and *Close* buttons follow it

#### Scenario: Row position with mixed trackpads
- **GIVEN** a MacBook that once had an external trackpad connected, so it has mixed trackpads, now with only its built-in trackpad
- **WHEN** the user opens the settings window
- **THEN** the group shows *MacBook trackpad*, *External trackpad*, *Hide background apps*, then the *Automatic updates* row

#### Scenario: Row position with the no trackpad notice
- **GIVEN** a Mac mini with no trackpad connected
- **WHEN** the user opens the settings window
- **THEN** the *Automatic updates* row is the last row of the thumb corner group, and the no trackpad notice sits below the group

### R2. The row follows its design
The row MUST follow `plans/052-auto-update-toggle/design/auto-updates.json`, the single source for its spacing, text size and button width. The version line MUST use the window's secondary text colour, in both light and dark appearance.

#### Scenario: Dark appearance
- **GIVEN** the Mac uses the dark appearance
- **WHEN** the user opens the settings window
- **THEN** the version line shows in the window's secondary text colour, readable against the dark group

### R3. The row shows the running version
The version line MUST show the running copy's version number, without the build number (for example "Current version: 1.1.22").

#### Scenario: Version of the running copy
- **GIVEN** Trackpad App 1.1.22 is running
- **WHEN** the user opens the settings window
- **THEN** the row reads "Current version: 1.1.22"

### R4. Automatic updates is on by default
The *Automatic updates* setting MUST be on for a new install and for a copy that upgrades from a version without the setting.

#### Scenario: Upgrade from 1.1.x
- **GIVEN** a user on a version without the setting
- **WHEN** a login update installs a version with the setting and the user opens the settings window
- **THEN** the *Automatic updates* switch is on

### R5. The setting is saved at once
A change of the switch MUST be saved at once, so it survives a quit, a force quit, a Mac restart and an update.

#### Scenario: Off survives a restart
- **GIVEN** the user turned *Automatic updates* off
- **WHEN** the Mac restarts and the user opens the settings window
- **THEN** the switch is off

#### Scenario: Off survives an update from the alert
- **GIVEN** *Automatic updates* is off and the user updates through the update alert
- **WHEN** the new version opens with its settings window
- **THEN** the switch is off, and after that opening Trackpad App makes no network request

### R6. On keeps today's update behaviour
While *Automatic updates* is on, update-capable copies MUST behave exactly as they do today: the login start's update check and *login update*, its retry when a connection returns, the update check each time the settings window opens, and the *update card*.

#### Scenario: Window check with the switch on
- **GIVEN** an update-capable copy with *Automatic updates* on, and a newer version published
- **WHEN** the user opens the settings window
- **THEN** the app reads the update list once and shows the update card

#### Scenario: Login update with the switch on
- **GIVEN** an update-capable copy that can write to its own bundle, with *Automatic updates* on, and a newer version published
- **WHEN** the Mac starts Trackpad App at login
- **THEN** it downloads and installs the newer version silently, as a login update

### R7. Off means no network request of the app's own
While *Automatic updates* is off, Trackpad App MUST make no network request except those a *Check for updates…* click and its alert's *Update* start, plus a download already under way when the switch was turned off. This means no update check at a login start, no *login update*, no retry when a connection returns, no update check when the settings window opens, and therefore no update card.

#### Scenario: Login start with the switch off
- **GIVEN** an update-capable copy with *Automatic updates* off, and a newer version published
- **WHEN** the Mac starts Trackpad App at login and the user works for a while, with connections dropping and returning
- **THEN** Trackpad App makes no network request and nothing installs

#### Scenario: Window opening with the switch off
- **GIVEN** an update-capable copy with *Automatic updates* off, and a newer version published
- **WHEN** the user opens the settings window
- **THEN** Trackpad App makes no network request and no update card shows

### R8. Turning the switch off stops pending automatic work
Turning *Automatic updates* off MUST drop a running window update check, remove an update card that offers an update, and end a failed login check's wait for a connection. A login check still running MUST be dropped before it downloads anything. A manual check still running MUST carry on unaffected. A download already running, whether from *Update now*, the alert's *Update* or a login update, MUST carry on and install. An *Update now* download that fails after the switch went off MUST leave no card: the card does not return while the switch is off.

#### Scenario: Card disappears
- **GIVEN** the update card shows *Update available*
- **WHEN** the user turns *Automatic updates* off
- **THEN** the card disappears at once and the window resizes to fit

#### Scenario: Switch off before the window check answers
- **GIVEN** the user opened the settings window and its update check is still running, with a newer version published
- **WHEN** the user turns *Automatic updates* off before the check answers
- **THEN** no update card shows

#### Scenario: Waiting retry is cancelled
- **GIVEN** a login start's check failed for lack of a connection and the user then turned *Automatic updates* off
- **WHEN** a connection arrives
- **THEN** Trackpad App makes no network request

#### Scenario: Running download carries on
- **GIVEN** the update card shows *Updating…* after *Update now*
- **WHEN** the user turns *Automatic updates* off
- **THEN** the download carries on, installs, and the hand-over opens the new version

#### Scenario: Update now fails after the switch went off
- **GIVEN** the update card shows *Updating…* after *Update now*, and the user turned *Automatic updates* off
- **WHEN** the download fails
- **THEN** no update card shows, and the running version keeps working

### R9. Turning the switch on checks nothing by itself
Turning *Automatic updates* on MUST NOT start an update check. Automatic checks resume at the next login start or the next opening of the settings window.

#### Scenario: Turn on while the window is open
- **GIVEN** *Automatic updates* is off and the settings window is open
- **WHEN** the user turns it on
- **THEN** Trackpad App makes no network request of its own until the window next goes from closed to open, or the next login start

#### Scenario: Card stays gone after off and on
- **GIVEN** the update card shows *Update available*
- **WHEN** the user turns *Automatic updates* off, so the card goes, then on again
- **THEN** the card stays gone until the next opening of the settings window

### R10. Check for updates works whatever the switch says
In an update-capable copy, a *Check for updates…* click MUST read the update list once, whether *Automatic updates* is on or off and whether or not the update card is showing.

#### Scenario: Manual check with the switch off
- **GIVEN** an update-capable copy with *Automatic updates* off
- **WHEN** the user clicks *Check for updates…*
- **THEN** Trackpad App reads the update list exactly once

#### Scenario: Manual check while the card shows
- **GIVEN** the update card shows *Update available*
- **WHEN** the user clicks *Check for updates…*
- **THEN** Trackpad App reads the update list once more and, finding the newer version, shows the update alert

### R11. The button shows Checking… while the check runs
While a manual check runs, the button MUST be disabled and read *Checking…*. It MUST return to *Check for updates…* when the check's alert shows. A check with no answer within 30 seconds MUST count as failed, and the "Couldn't check for updates" alert shows.

#### Scenario: Slow connection
- **GIVEN** a connection slow enough that the check takes several seconds
- **WHEN** the user clicks *Check for updates…*
- **THEN** the button greys out as *Checking…* until the alert appears, and a second click does nothing

#### Scenario: No answer within 30 seconds
- **GIVEN** a connection that never answers
- **WHEN** the user clicks *Check for updates…* and 30 seconds pass
- **THEN** the "Couldn't check for updates" alert shows and the button reads *Check for updates…*

### R12. A newer version shows the update alert
When a manual check finds a *newer version*, Trackpad App MUST show a standard macOS alert, free-standing (not a sheet), with the app's icon:
- title "Restart Trackpad App to update?";
- body "Update Trackpad App from <running version> to <new version>." then, after a blank line, "Trackpad App will quit to install the update and open again.";
- the buttons *Not now* and *Update*, with *Update* the default.

A manual check MUST never add the update card: a window with no card showing stays without one.

#### Scenario: Newer version published
- **GIVEN** Trackpad App 1.1.22 is running and 1.1.23 is the newest published version
- **WHEN** the user clicks *Check for updates…*
- **THEN** the alert reads "Restart Trackpad App to update?" and "Update Trackpad App from 1.1.22 to 1.1.23."

#### Scenario: No card from a manual check
- **GIVEN** *Automatic updates* is off, no update card shows, and 1.1.23 is published
- **WHEN** the user clicks *Check for updates…* and then *Not now*
- **THEN** the update alert showed, and no update card shows

### R13. Not now dismisses with nothing remembered
*Not now* MUST close the alert and change nothing: no version is skipped. The next check offers the same version again.

#### Scenario: Not now, then check again
- **GIVEN** the user chose *Not now* for 1.1.23
- **WHEN** they click *Check for updates…* again
- **THEN** the alert offers 1.1.23 again

### R14. Update installs like Update now
The alert's *Update* MUST download and install exactly as the update card's *Update now* does: it reads the update list once more before downloading and installs the newest *newer version* it then finds, which may be newer than the one the alert named; only a genuine update installs; a copy that cannot write to its own bundle asks for an administrator's name and password after the download; and the *hand-over* then opens the new version with its settings window. It MUST do so whatever the *Automatic updates* switch says. R7's exception covers this read of the update list.

#### Scenario: Update with the switch off
- **GIVEN** *Automatic updates* is off and the update alert offers 1.1.23
- **WHEN** the user clicks *Update*
- **THEN** 1.1.23 downloads and installs, and opens with its settings window

#### Scenario: A newer release meanwhile
- **GIVEN** the update alert offers 1.1.23, and 1.1.24 is published while it shows
- **WHEN** the user clicks *Update*
- **THEN** 1.1.24 downloads and installs

### R15. The button shows Updating… while an update downloads
While an update downloads or installs, whether started by the alert's *Update*, the card's *Update now* or a *login update*, the *Check for updates…* button MUST be disabled and read *Updating…*. An update card that shows during the download (see R16) MUST read *Updating…* too.

#### Scenario: Update from the alert while the card shows
- **GIVEN** the update card shows *Update available*
- **WHEN** the user clicks *Check for updates…*, then *Update* in the alert
- **THEN** both the card's button and the row's button read *Updating…*, disabled

### R16. One download at a time
While a download runs, whatever started it (the card's *Update now*, the alert's *Update* or a login update), opening the settings window MUST make no update check. The update card MUST show *Updating…* only if the card was showing when that download started; otherwise no card shows. The row's button reads *Updating…*. At most one download MUST run at a time: when a download is already running as the user clicks the alert's *Update*, *Update* starts nothing new and the button reads *Updating…*.

#### Scenario: Window opened during a login update
- **GIVEN** a login update is downloading
- **WHEN** the user opens the settings window
- **THEN** Trackpad App makes no update check, no update card shows, and the row's button reads *Updating…*, disabled

#### Scenario: Window reopened during Update now
- **GIVEN** the update card shows *Updating…* after *Update now*
- **WHEN** the user closes and reopens the settings window
- **THEN** Trackpad App makes no update check, the card shows *Updating…*, and the row's button reads *Updating…*

#### Scenario: Window reopened during an update from the alert
- **GIVEN** no update card showed when the user clicked *Update* in the update alert
- **WHEN** the user closes and reopens the settings window during the download
- **THEN** Trackpad App makes no update check, no update card shows, and the row's button reads *Updating…*

#### Scenario: Update while a login retry downloads
- **GIVEN** the update alert shows, and a login check's retry found the newer version and started a login update
- **WHEN** the user clicks *Update*
- **THEN** no second download starts, the row's button reads *Updating…*, and the running download installs

### R17. Up to date shows an alert
When a manual check finds no newer version, Trackpad App MUST show an alert "Trackpad App is up to date" with the body "You're running the latest version, <running version>." and a single *OK* button.

#### Scenario: No newer version
- **GIVEN** Trackpad App 1.1.22 is running and is the newest published version
- **WHEN** the user clicks *Check for updates…*
- **THEN** the alert reads "Trackpad App is up to date" and "You're running the latest version, 1.1.22."

### R18. A failed check shows an alert
When a manual check fails, for lack of a connection or any other reason, Trackpad App MUST show an alert "Couldn't check for updates" with the body "Check your internet connection and try again." and a single *OK* button. The button returns to *Check for updates…*.

#### Scenario: Offline
- **GIVEN** the Mac has no connection
- **WHEN** the user clicks *Check for updates…*
- **THEN** the "Couldn't check for updates" alert shows, and nothing retries by itself

### R19. A failed update from the alert shows an alert
When a download or install started by the alert's *Update* fails, or the update is not genuine, Trackpad App MUST keep the running version working and show an alert "Couldn't install the update" with the body "Trackpad App <running version> keeps running. Try again later." and a single *OK* button. The button returns to *Check for updates…*. If the failure comes while the settings window is closed, no alert MUST show, then or later, and the next opening shows *Check for updates…*.

#### Scenario: Download fails
- **GIVEN** the user clicked *Update* in the update alert
- **WHEN** the connection drops mid-download
- **THEN** the "Couldn't install the update" alert shows, 1.1.22 keeps running, and the button reads *Check for updates…*

#### Scenario: Update not genuine
- **GIVEN** the downloaded update is not genuine
- **WHEN** the alert's *Update* finishes downloading
- **THEN** nothing installs, the "Couldn't install the update" alert shows, and the running version keeps working

#### Scenario: Download fails with the window closed
- **GIVEN** the user clicked *Update* in the update alert and then closed the settings window
- **WHEN** the download fails
- **THEN** no alert shows, then or later, and the next opening of the window shows *Check for updates…*

### R20. A cancelled administrator prompt returns the button
When the user cancels the administrator prompt after the alert's *Update*, Trackpad App MUST show no alert, return the button to *Check for updates…*, and keep the running version working.

#### Scenario: Administrator prompt cancelled
- **GIVEN** a copy that cannot write to its own bundle, after the user clicked *Update*
- **WHEN** the user cancels the administrator prompt
- **THEN** no alert shows, the button reads *Check for updates…*, and the running version keeps working

### R21. Closing the window drops a manual check
Closing the settings window while a manual check runs MUST drop the check silently: no alert shows then or at the next opening. A download already started by the alert's *Update* MUST carry on, and reopening the window during it follows R16.

#### Scenario: Close during Checking…
- **GIVEN** the button reads *Checking…*
- **WHEN** the user closes the settings window and the check then finds 1.1.23
- **THEN** no alert shows, and the next opening shows *Check for updates…*

### R22. Copies that cannot update explain why
In a copy that is not update-capable (a development build, a copy not signed with a Developer ID, or a copy outside /Applications), the row MUST show as in R1 and R2 with a working switch, and *Check for updates…* MUST stay enabled. The switch there only saves its value: such a copy has nothing for it to turn on or off. A click MUST make no network request and show an alert "Updates aren't available for this copy" with the body "This copy of Trackpad App can't update itself." and a single *OK* button.

#### Scenario: Debug build
- **GIVEN** a Debug build run from Xcode
- **WHEN** the user clicks *Check for updates…*
- **THEN** the "Updates aren't available for this copy" alert shows and no request is made

### R23. Progress dots step in time
The labels *Checking…* and *Updating…*, on the row's button and on the update card's button, MUST animate their three dots: a 1-second loop of four equal 250 ms steps showing no dots, one, two and three, each step switching instantly with no fade. The word MUST NOT move as the dots change. VoiceOver MUST read a stable label, "Checking…" or "Updating…", and announce no dot changes.

#### Scenario: Dots cycle
- **GIVEN** Reduce motion is off
- **WHEN** the button reads *Checking…* for two seconds
- **THEN** the dots show none, one, two, three, none, one, two, three, each for 250 ms, and the word "Checking" stays in place

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the button reads *Checking…* while its dots animate
- **THEN** VoiceOver reads "Checking…" and announces nothing as the dots change

### R24. Reduce motion stills the dots
With the system's Reduce motion setting on, a progress label MUST show a static "…".

#### Scenario: Reduce motion
- **GIVEN** Reduce motion is on
- **WHEN** the update card reads *Updating…*
- **THEN** the label shows "Updating…" with still dots

### R25. Only progress labels animate
Only *Checking…* and *Updating…* MUST animate. Labels whose ellipsis means "opens something" (*Check for updates…*, *Open Settings…*, *Other…*) MUST stay static.

#### Scenario: Idle button
- **GIVEN** Reduce motion is off
- **WHEN** the button reads *Check for updates…*
- **THEN** its "…" stays still

### R26. Alerts are app-modal and gestures keep working
Every update alert MUST be app-modal: while one shows, the settings window takes no clicks until the user answers it. While any of the update alerts shows, gestures, the swipe, the window swipe and the swap MUST keep working. This part guards existing behaviour: no alert stops gestures today.

#### Scenario: Window blocked during the alert
- **GIVEN** the update alert shows
- **WHEN** the user clicks the *Automatic updates* switch
- **THEN** the switch does not change until the user answers the alert

#### Scenario: Tap during the alert
- **GIVEN** the update alert shows
- **WHEN** the user makes the 2-finger gesture
- **THEN** its app comes to the front as usual

#### Scenario: Hide background apps during the alert
- **GIVEN** *Hide background apps* is on and the update alert shows
- **WHEN** the user makes a gesture that brings another app to the front, then opens Trackpad App again
- **THEN** the gesture hides Trackpad App with its alert, and the reopening shows the settings window with the alert still waiting

## Non-goals

- **A schedule of checks.** Automatic checks stay at the two moments they have today, a login start and the window opening. The product has no timers, and the switch only turns those moments on or off.
- **Release notes or a progress bar in the alert.** The alert matches the system's update prompt (versions only), and progress shows as the animated *Updating…*.
- **Skipping a version.** *Not now* remembers nothing. A skip list adds state no one asked for.
- **Separate switches for checking and installing.** One switch covers both. Off means no requests, and on keeps today's silent login update.
- **A Check for updates menu item.** The app menu holds only *Close Settings* and the Window items. The button in the window is the one entry point.
- **Changing the update card's silent failure.** The card is unchanged apart from its animated *Updating…* (R23) and disappearing when the switch turns off (R8).
- **Showing an alert or card for an update found or failed while the window is closed.** With no window and no Dock icon, nothing has a place to show it.

## Design

### Problem

Today one gated model, `Updater`, makes every update decision with a `Phase` enum. Each phase says two things at once: what Sparkle is doing, and who asked for it. `probing` is the window's check, and `updatingFromCard` is *Update now*'s cycle. 052 breaks that pairing:
- One running read of the update list can be wanted by the window, by a click, by both or by no one.
- A login cycle becomes a login update only once it starts downloading.
- A download can be asked for while another cycle runs.

The constraints the shape honours are below. F-numbers point to `.temp/architect/grounding/index.md` and C-numbers to `.temp/architect/checks/notes.md`.

- **One cycle at a time.** The engine runs one cycle at a time. A request made during a cycle is dropped silently, and the model would wait for ever. No cycle can be cancelled (F4, F7).
- **Stopping and timing a cycle.** The only public stop between reading the list and downloading is Sparkle's `showUpdateFound` reply (F8). Nothing in Sparkle gives 30 s (F9), and no timer may exist (F19, F20).
- **Where a modal may start.** `runModal()` started inside a main-queue block or a main-actor job holds the main queue, and gestures with it. Started from a run-loop callout, it does not (F26, F27). While a two-button alert is up, a quit Apple event is refused, so the update alert would cancel a logout (C4).
- **Versions.** No Sparkle type crosses the engine port, yet the alerts name versions (F5).
- **Copies that cannot update.** A copy the gate turns away has no engine and must keep none (F1). Yet R22 gives it a working switch and an answer to the click.
- **Kept from 039.** `start` is the only place updates start, and it stands in for the first window edge (F2). Every lasting effect starts and stops in one transition (F3). The hand-over's order is unchanged, and `.afterUpdate` still starts nothing.
- **Reversed non-goals.** 052 deliberately reverses four non-goals of plans 022 and 039: no off switch, no *Check for updates* button, no dialogs about updates, and no version shown.

### Usage (caller's view)

> `Updater` is the one object the settings window, the alert presenter and `Lifecycle` talk to about updates, in every copy. The window reads `version`, `isAutomaticUpdatesOn`, `checkButton`, `card` and `alert`. It sends `setAutomaticUpdates(on:)`, `checkForUpdates()`, `updateNow()` and `answer(_:to:)`. The `Updater` decides the rest:
> - whether this copy can update at all;
> - whether a cycle runs, and who waits for its answer;
> - the 30 s limit;
> - what an answer means by the time it arrives.

```swift
// Composition root: every copy gets an Updater; only the gate's copy gets the ports that can reach the network.
updater = Updater(
    version: ThisCopy.version(), store: SettingsStore(defaults: .standard),
    ports: makeUpdatePorts(placement: placement, location: location))

/// The gate is a value only `UpdatableCopy.init?` can make, and no engine reaches the model without one.
private func makeUpdatePorts(placement: Placement, location: Location) -> UpdatePorts? {
    let signer = CodeSignature.developerIDSigner()
    guard
        let copy = UpdatableCopy(
            placement: placement, developerIDSigned: signer != nil,
            canReplaceItself: SparkleEngine.canReplace(location.running)),
        let signer
    else { return nil }
    return UpdatePorts(
        copy, engine: SparkleEngine(bundle: location.running, signer: signer), connection: SystemConnection(),
        deadline: LayerCheckDeadline())
}
```

```swift
// SettingsView, the thumb corner group: the row is the section's last cell.
Section {
    ThumbCornerRows(launcher: launcher)
    Toggle(isOn: Binding(get: { launcher.isHideBackgroundAppsOn }, set: { launcher.setHideBackgroundApps(on: $0) })) {
        Text("Hide background apps").formRow(height: Self.oneLineRowHeight)
    }
    .toggleStyle(.switch)
    UpdatesRow(updater: updater)
}

// UpdatesRow: no capability check and no state of its own.
Toggle(isOn: Binding(get: { updater.isAutomaticUpdatesOn }, set: { updater.setAutomaticUpdates(on: $0) })) {
    Text(Copy.automaticUpdatesRow)
}
.toggleStyle(.switch)
Text(Copy.currentVersion(updater.version)).font(.system(size: 11)).foregroundStyle(.secondary)
Button { updater.checkForUpdates() } label: { ButtonTitleView(title: updater.checkButton.title) }
    .disabled(!updater.checkButton.isEnabled)

// UpdateCardView: the same title view, so *Updating…* steps there too.
Button(action: updateNow) { ButtonTitleView(title: card.buttonTitle) }

// SettingsShell.init: one presenter for every update alert.
alerts = UpdateAlertPresenter(updater: updater)
```

```swift
// The high seam, LifecycleWorld / OneProcess over the in-memory engine, connection and deadline (R7, R10-R12, R14):
let world = LifecycleWorld(record: [.one: "Arc"], automaticUpdates: false)
let process = world.launch(.byHand, running: .release)            // runs 1.1.22, window open, switch off
#expect(process.engine.probes == 0 && process.connection.watches == 0)
process.checkForUpdates()
#expect(process.updater.checkButton == .checking && process.deadline.armed == .seconds(30))
process.engine.push(.cycleEnded(.found("1.1.23")))
#expect(process.updater.alert == .updateAvailable(from: "1.1.22", to: "1.1.23"))
#expect(process.card == nil && process.deadline.armed == nil)       // a manual check never adds the card
process.answer(.update)
#expect(process.updater.checkButton == .updating && process.engine.updates == 1)
#expect(process.engine.offer("1.1.24"))                             // the list, read once more: the newest downloads
process.engine.push(.held)
#expect(process.engine.arms == [true] && process.engine.overlaps == 0)
```

### Shape

**Load-bearing decisions**

1. **The switch belongs to `Updater`, under a key of its own beside the settings record.** The key is `automaticUpdatesOff`, and its presence is the fact, as `externalThumbCorner`'s is. Present, whatever it holds, means off; absent means on (R4). An unreadable value therefore stays off and never turns automatic requests back on. `setAutomaticUpdates(on:)` saves the value at once and runs the switch-off transition in the same function. There is no second owner and no change closure. `Launcher` and `Settings` are untouched. An off survives an older build's save of the record (the 048 analysis); for a privacy switch, that matters. Per separate-before-serializing-shared-state.
2. **`Updater` exists in every copy. The gate's absent object becomes `UpdatePorts`:** the engine, the path monitor and the deadline. Only an `UpdatableCopy` can make a `UpdatePorts`. A copy the gate turns away still builds no `SparkleEngine`, so nothing in it can make a request. In that copy `checkForUpdates()` raises `.unavailable` (R22), and the switch only saves. This changes a preserved decision on purpose: the gate stays "an object's absence", and the absent object is now the ports. Per encode-lessons-in-structure.
3. **The phase says what the engine is doing. Who waits for the list's answer are facts beside it:** `window` (the opening's stake: a check it waits for, or the card) and `manualWaits` (a click waits, *Checking…*).
   - `probing` and `droppedProbe` become one `checking`. A dropped check is a check nobody waits for.
   - An answer goes to whoever waits when it arrives. So a click adopts a running window check, dropped check, timed-out check or login read, with no new request. A click that adopts the window's running check takes its answer, so no card appears (R12).
   - A cycle starts in exactly one function, `begin(_:)`, which refuses unless the engine is free. `settle()` runs after every input and starts whatever waits.
   - "Never asked while a cycle runs" holds by construction, not by case analysis in each transition. Per model-the-domain.
4. **Every lasting effect starts and stops in `enter(_:)`, from the diff of one `State`.** The connection watch follows the phase, as today, and the 30 s deadline follows `manualWaits`. Per encode-lessons-in-structure.
5. **A download the user asks for (*Update now*, the alert's *Update*) is one phase, `installing(Install)`, reached through one function, `want(_:)`:**
   - While a download runs, `want` starts nothing (R16).
   - It adopts a running login download, which then hands over with the window and reports a failure (R14, R19).
   - It is queued behind a running read and starts once the engine is free. No queued download can meet a login read: a request comes only from an *Update available* card or an update alert, and neither exists while a login read runs.
   - The card's *Updating…* travels inside the `Install` (`showsCard`), fixed when the download is asked for (R16).
   - `card` and `checkButton` are computed from the state, so they cannot disagree or go stale. Per type-system-discipline.
6. **Consent to download crosses the port as one synchronous question.** `shouldDownload: (AppVersion) -> Bool` is asked inside Sparkle's `showUpdateFound` and answered at once:
   - true: the reply is *install*;
   - false: the reply is *dismiss*, and nothing downloads and nothing is remembered.
   This gives the model the stop before a download (R8) and the moment a login download starts (R15, R16). It cannot leave a cycle waiting, because a function must return.
7. **Versions cross the port as `AppVersion`, display text only.** A probe's `.found` carries one, and the offer question carries one. `ThisCopy.version()` reads the running version once at start and hands it in, through a bundle-taking form a test can point at a fixture. Sparkle compares build numbers, so nothing here compares versions. Per boundary-discipline.
8. **The 30 s limit is a port, `CheckDeadline`, armed with a duration.** The model owns the policy (`checkLimit`) and the real adapter owns the clock: one `LaunchClock` per armed wait, so the limit is an animation on a layer that goes when the wait ends (F20). When the limit passes, the wait fails, not the cycle. The read runs on wanted by no one, and a second click adopts it with a fresh 30 s (R11).
9. **One presenter shows `updater.alert`, a single slot.**
   - Its observation only schedules. The modal session starts in a `RunLoop.main.perform` callout, so its nested run loop keeps serving the main queue, gestures included (F26, R26).
   - Closing the window withdraws the alert in the model, and the presenter ends the session with `abortModal()`, which works from a main-actor job (C1).
   - `NSWorkspace.willPowerOffNotification` also ends the session unanswered, so the alert never refuses a logout (C4).
   - An answer is read against the state at that moment, never against a snapshot. An answer to a withdrawn alert does nothing.
   - The alert takes no activation: it never pulls the user away from another app.
10. **The row is one form cell of constant height,** so `Fit` gains nothing. The card leaving when the switch turns off already refits through `Fit.card`.
11. **Progress is a type.** `ButtonTitle.progress` is the only title that animates, so "Check for updates…", "Open Settings…" and "Other…" cannot (R25). The dots are one render-server animation: a mask over three fixed dots in a fixed box, growing in four held steps, as the xreader reference does (F24). They follow the card arrow's rules: they run only while the window is on screen with Reduce motion off (R23, R24).

**What the interface hides.** The shell learns nine members of one object, and `Lifecycle` learns two more. Behind them sit:
- the capability gate;
- one-cycle scheduling and adoption;
- the retry debt;
- the offer question;
- the deadline;
- which alert an answer earns;
- what a late answer may still start;
- the hand-over.

The engine port grows by one closure, a decision that belongs to the model and must not be made in the adapter.

**What the design deliberately does not do.**
- It adds no schedule and no timer.
- It never shows an alert or card for automatic outcomes, and never shows one while the window is closed.
- It never cancels or skips in Sparkle, and never turns `SUEnableAutomaticChecks` on.
- It does not change the move dialog.
- The hand-over and `.afterUpdate` are unchanged.

#### Module map

| Module | New | Changed |
|---|---|---|
| `LauncherCore` | `AppVersion`, `ButtonTitle`, `Progress`, `CheckButton`, `UpdateAlert`, `AlertButton`, `AlertAnswer`, `UpdatePorts`; port `CheckDeadline` | `Updater` (every copy; reshaped state); `UpdateEngine` (`shouldDownload`); `CycleOutcome` (`.found(AppVersion)`, `.cancelled`); `UpdateCard.buttonTitle` (a `ButtonTitle`); `SettingsStore` (the switch's key); `Copy`; `Lifecycle` (`updater` no longer optional) |
| `LauncherPlatform` | `LayerCheckDeadline`, `ThisCopy.version()` and `version(of:)` | `SparkleEngine` (the offer question, versions, `.cancelled`) |
| `LauncherUI` | `UpdatesRow`, `ButtonTitleView`, `ProgressDots` / `ProgressDotsView`, `UpdateAlertPresenter` | `SettingsView`, `SettingsShell` (takes `Updater`, owns the presenter), `UpdateCardView`, `UpdateCardPreview` (becomes `UpdatesPreview`) |
| App target | | The composition root |
| Tests | `InMemoryCheckDeadline`, `ProgressDotsBench`, `UpdateAlertBench` | `InMemoryUpdateEngine`, `LifecycleWorld` / `OneProcess`, `PersistenceTests`, `CopyTests`, `SourcePolicyTests`, `SparkleEngineTests` |

`Launcher`, `Settings`, `LauncherActions` and `MoveDialogPresenter` do not change.

#### LauncherCore: values and ports

```swift
/// A version as people read it ("1.1.22"), never the build number: `CFBundleShortVersionString`, or the feed's
/// `sparkle:shortVersionString`. Made at the two boundaries that read one. Display text only: Sparkle compares builds.
public struct AppVersion: Equatable, Sendable, CustomStringConvertible {
    public let description: String
    public init(_ text: String) { description = text }
}

/// Work under way: a still word, then three dots that step while it runs.
public enum Progress: Equatable, Sendable {
    case checking, updating
    /// "Checking", "Updating": the part that never moves.
    public var word: String { fatalError("not implemented") }
    /// "Checking…": what VoiceOver reads and Reduce motion shows (R23, R24).
    public var label: String { word + "…" }
}

/// A button's title. Only `.progress` animates (R23, R25); an ellipsis meaning "opens something" is `.plain`.
public enum ButtonTitle: Equatable, Sendable {
    case plain(String)
    case progress(Progress)
    public var text: String { fatalError("not implemented") }      // the plain text, or the progress label
}

/// The update card. Unchanged apart from its progress title.
public enum UpdateCard: Equatable, Sendable {
    case available, updating
    public var text: String { Copy.updateAvailable }
    public var buttonTitle: ButtonTitle { self == .available ? .plain(Copy.updateNowButton) : .progress(.updating) }
    public var isButtonEnabled: Bool { self == .available }
}

/// The row's button, in every copy (R10, R11, R15, R22).
public enum CheckButton: Equatable, Sendable {
    case idle, checking, updating
    /// `.plain("Check for updates…")`, `.progress(.checking)`, `.progress(.updating)`.
    public var title: ButtonTitle { fatalError("not implemented") }
    public var isEnabled: Bool { self == .idle }
}

/// An update alert, as values; every text comes from `Copy`. Only a *Check for updates…* click, or the download its
/// *Update* asked for, raises one, and only while the window is open.
public enum UpdateAlert: Equatable, Sendable {
    /// R12. A waiting manual check heard "newer". *Update* (default), *Not now* (Escape).
    case updateAvailable(from: AppVersion, to: AppVersion)
    /// R17. A waiting manual check heard "nothing new", or the alert's *Update* re-read the list and found nothing.
    case upToDate(AppVersion)
    /// R18, and R11's 30 s. *OK*.
    case checkFailed
    /// R19. A download the alert's *Update* asked for ended without installing, the window open. *OK*.
    case installFailed(running: AppVersion)
    /// R22. *Check for updates…* in a copy without ports. *OK*.
    case unavailable

    public var title: String { fatalError("not implemented") }
    /// `.updateAvailable`: "Update Trackpad App from 1.1.22 to 1.1.23.\n\nTrackpad App will quit to install the update
    /// and open again."
    public var message: String { fatalError("not implemented") }
    /// In AppKit's order: the first is the default. `isCancel` takes Escape (AppKit gives it to no "Not now" itself).
    public var buttons: [AlertButton] { fatalError("not implemented") }
}

public struct AlertButton: Equatable, Sendable {
    public let title: String
    public let answer: AlertAnswer
    public let isCancel: Bool
}

/// `.dismissed`: *Not now*, *OK*, Escape, or a session the presenter ended.
public enum AlertAnswer: Equatable, Sendable { case update, dismissed }

public enum CycleOutcome: Equatable, Sendable {
    /// A probe found a newer version: the newest, as its display version. Never an update's outcome.
    case found(AppVersion)
    case nothingNew
    /// The feed's request failed. The only outcome that earns a login start's retry.
    case requestFailed
    /// The user cancelled the administrator prompt (R20). An update's outcome only.
    case cancelled
    /// Anything else after the feed was read: a failed download, a refused or ungenuine archive, a discarded update.
    case failed
}

public enum UpdateEngineEvent: Equatable, Sendable { case held, cycleEnded(CycleOutcome) }   // cases unchanged

/// Sparkle, and the restart that follows it. No Sparkle type or feed value crosses this port; a version crosses only
/// as `AppVersion`. Real: SparkleEngine. Test: InMemoryUpdateEngine.
@MainActor public protocol UpdateEngine: AnyObject {
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? { get set }
    /// An update cycle read the list and found `version`, the newest newer version; nothing has downloaded. True: the
    /// download begins. False: nothing downloads and nothing is remembered (Sparkle's *dismiss*, never its *skip*);
    /// `.cycleEnded` follows, whose outcome the model ignores. Asked at most once per update cycle, inside Sparkle's
    /// callback, answered at once. Never asked for a probe, nor for an update Sparkle is already installing (a crash's
    /// leftover, which the engine skips itself, as today). Unset: false.
    var shouldDownload: (@MainActor (AppVersion) -> Bool)? { get set }
    /// Reads the list and downloads nothing. Answers once, `.cycleEnded`. Never asked while a cycle runs.
    func probe()
    /// Reads the list, asks `shouldDownload`, downloads, refuses an ungenuine archive, asks for an administrator when
    /// this user cannot replace the bundle, prepares, pushes `.held`. Never asked while a cycle runs.
    func update()
    func discardHeldUpdate()
    func armRestart(opensWindow: Bool) -> Bool
}

/// The manual check's limit, on Core Animation's clock. A stop of the clock the system causes counts as passed.
/// Real: LayerCheckDeadline. Test: InMemoryCheckDeadline.
@MainActor public protocol CheckDeadline: AnyObject {
    var onPassed: (@MainActor () -> Void)? { get set }
    /// Calls `onPassed` once after `wait`, unless cancelled or armed again first.
    func arm(for wait: Duration)
    func cancel()
}

/// What an update-capable copy updates through. Only the gate's value makes one, so a copy the gate turns away has no
/// engine, no path monitor and no deadline: nothing in it can make a request.
@MainActor public struct UpdatePorts {
    let engine: any UpdateEngine
    let connection: any Connection
    let deadline: any CheckDeadline
    let canReplaceItself: Bool
    public init(_ copy: UpdatableCopy, engine: any UpdateEngine, connection: any Connection, deadline: any CheckDeadline) {
        fatalError("not implemented")
    }
}

extension SettingsStore {
    /// The Automatic updates switch: one key beside the record, `automaticUpdatesOff`, whose presence is the fact.
    /// Absent: on, so a new install and an upgrade need no code (R4). Present, whatever it holds: off, so a value this
    /// build cannot read never turns automatic requests back on. A version that does not know the key never rewrites
    /// it, so an off survives a downgrade and its saves; it neither ends nor fakes a first run. Read once, by
    /// `Updater.init`.
    func loadAutomaticUpdates() -> Bool { fatalError("not implemented") }
    /// One synchronous write, on a change of the switch only (R5): off sets the key, on removes it.
    func saveAutomaticUpdates(_ on: Bool) { fatalError("not implemented") }
}
```

#### LauncherCore: the model

```swift
/// Owns every update decision, in every copy. Without ports it holds the switch, the version and one alert, and its
/// phase never leaves `resting`.
@MainActor @Observable
public final class Updater {
    public init(version: AppVersion, store: SettingsStore, ports: UpdatePorts?) { fatalError("not implemented") }

    public let version: AppVersion
    public private(set) var isAutomaticUpdatesOn: Bool
    public var checkButton: CheckButton { fatalError("not implemented") }   // derived, see below
    public var card: UpdateCard? { fatalError("not implemented") }          // derived, see below
    public var alert: UpdateAlert? { state.alert }
    @ObservationIgnored public var onHandOver: (@MainActor () -> Void)?

    /// Once, from a resident only. Sets `launcher.onWindowEdge` in every copy, since an alert leaves with the window,
    /// then returns without ports. With ports: wires `engine.onEvent`, `engine.shouldDownload`, `connection.onChange`,
    /// `deadline.onPassed`. A login start of a copy that can replace itself, with the switch on, begins
    /// `checkingAtLogin(retry: false, dropped: false)`. `.afterUpdate` starts nothing. Any other start with its window
    /// open goes through the open edge (F2).
    public func start(watching launcher: Launcher, opening: Opening, opensWindow: Bool) { fatalError("not implemented") }
    public func setAutomaticUpdates(on: Bool) { fatalError("not implemented") }
    public func checkForUpdates() { fatalError("not implemented") }
    public func updateNow() { fatalError("not implemented") }
    /// Ignored unless `alert` is still the one that shows, so a session the model withdrew answers nothing.
    public func answer(_ answer: AlertAnswer, to alert: UpdateAlert) { fatalError("not implemented") }

    static let checkLimit = Duration.seconds(30)

    // MARK: State

    @ObservationIgnored private let ports: UpdatePorts?
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private weak var launcher: Launcher?
    private var state = State()

    private struct State: Equatable {
        var phase = Phase.resting
        /// What the open window has at stake in the list's next answer. `.none` while it is closed or the switch is off.
        var window = WindowStake.none
        /// A *Check for updates…* click waits for the list's answer: *Checking…*, and the deadline is armed.
        var manualWaits = false
        /// A download the user asked for while a cycle ran; it starts when the engine is free (R16).
        var queued: Install?
        /// At most one; only while the window is open.
        var alert: UpdateAlert?
    }

    /// What the engine is doing, and what a login start is still owed. A cycle runs in every phase but `resting`,
    /// `awaitingConnection` and `handedOver`.
    private enum Phase: Equatable {
        case resting
        /// The login check failed for the network; the path monitor runs. As today; exists only while the switch is on.
        case awaitingConnection(spent: Bool)
        /// A read that downloads nothing (a probe). `debt`: what an interrupted login wait still owes. Was `probing` and
        /// `droppedProbe`: nobody waiting makes it a dropped check.
        case checking(debt: RetryDebt)
        /// The login cycle reads the list. Was `updatingAtLogin`, before its offer. `retry`, `dropped`: as today.
        case checkingAtLogin(retry: Bool, dropped: Bool)
        /// The switch went off while the login cycle read the list. It cannot be stopped, so it runs on; its offer is
        /// declined, so nothing downloads (R8). `listAnswered`: the offer has come.
        case abandonedAtLogin(listAnswered: Bool)
        /// The login update: its offer was accepted, it downloads, is checked and prepared. Silent.
        case updatingAtLogin
        /// A download the user asked for: it reads the list once more, then downloads (R14). Was `updatingFromCard`.
        case installing(Install)
        /// Terminal: the restart is armed and the process ends in this turn.
        case handedOver
    }

    private enum RetryDebt: Equatable { case none, owed(spent: Bool) }

    /// A download the user asked for, and whether the card reads *Updating…* through it (R15, R16).
    private enum Install: Equatable {
        case fromCard
        /// `overCard`: the card was showing when *Update* was clicked.
        case fromAlert(overCard: Bool)
        var showsCard: Bool { self == .fromCard || self == .fromAlert(overCard: true) }
    }

    private enum WindowStake: Equatable {
        case none
        /// This opening's check has not answered yet.
        case check
        /// It found a newer version: the card shows *Update available*. Was the phase `offering`.
        case card
    }

    // Derived, never stored:
    //   card:        phase installing(i), or queued i  →  i.showsCard ? .updating : nil
    //                phase updatingAtLogin, handedOver  →  nil
    //                otherwise                          →  window == .card ? .available : nil
    //   checkButton: phase installing, updatingAtLogin, handedOver, or queued != nil  →  .updating
    //                manualWaits → .checking;  otherwise → .idle

    // MARK: Transitions (every input builds the next State, enters it, then settles)

    /// After every input. A free engine takes what waits: first a download the user asked for, then a check someone
    /// waits for. Idempotent.
    private func settle() {
        // guard ports != nil, phase is .resting or .awaitingConnection(spent)
        // if let i = queued { next.queued = nil; begin(.installing(i)) }          // an install settles a login wait
        // else if manualWaits || window == .check { begin(.checking(debt: awaiting ? .owed(spent) : .none)) }
        fatalError("not implemented")
    }

    /// The one place a cycle starts, and only from a phase that runs none. The phase is entered first: the engine may
    /// answer inside the call. `.checking` → `probe()`; `.checkingAtLogin`, `.installing` → `update()`.
    private func begin(_ next: Phase) { fatalError("not implemented") }

    /// The one place a lasting effect starts or stops, from the diff of `state` and `next`, the watch last (it pushes
    /// inside the call):
    ///   deadline: manualWaits false → true: arm(for: checkLimit); true → false: cancel()
    ///   watch:    into awaitingConnection from any other phase: watch(); out of awaitingConnection or
    ///             checkingAtLogin(retry: true, _) into a phase that is neither: stop()
    ///   handedOver withdraws the alert.
    private func enter(_ next: State) { fatalError("not implemented") }

    /// The list answered. Everyone waiting takes the answer; a read nobody waits for answers no one.
    private func listAnswered(_ outcome: CycleOutcome, into next: inout State) {
        // window: .check + found → .card;  .check + anything else → .none;  .card + nothingNew → .none
        // manual: if manualWaits { manualWaits = false
        //   alert = found(v) → .updateAvailable(from: version, to: v); nothingNew → .upToDate(version); else .checkFailed }
        fatalError("not implemented")
    }

    /// *Update now* and the alert's *Update*. At most one download (R16).
    private func want(_ install: Install) {
        // installing, handedOver, or queued != nil → nothing
        // updatingAtLogin → enter(.installing(install)), no engine call: the running login download becomes the
        //   user's, so it hands over with the window and reports a failure (R14, R19)
        // otherwise → manualWaits = false; window = .none; queued = install
        fatalError("not implemented")
    }

    /// `shouldDownload`, asked inside Sparkle's `showUpdateFound`.
    private func offered(_ version: AppVersion) -> Bool {
        // checkingAtLogin         → listAnswered(.found(v)); window = .none; updatingAtLogin; true
        // abandonedAtLogin(false) → listAnswered(.found(v)); abandonedAtLogin(true); false (R8: nothing downloads)
        // installing              → true (R14: the newest it finds, whatever the switch)
        // otherwise               → false
        // No download is queued in either login phase: only a card or an update alert asks for one, and neither
        // exists while a login read runs.
        fatalError("not implemented")
    }

    private func installEnded(_ install: Install, _ outcome: CycleOutcome, into next: inout State) {
        // window = .card only if install.showsCard, outcome != .nothingNew, the window is open and the switch is on (R8)
        // fromAlert with the window open: .nothingNew → .upToDate(version); .cancelled → no alert (R20);
        //   anything else → .installFailed(running: version) (R19)
        fatalError("not implemented")
    }

    /// As today: arm, or discard and let the cycle's `.failed` resolve through the phase. `updatingAtLogin` opens the
    /// window only if it is open; `installing` always (R14).
    private func handOver(opensWindow: Bool) { fatalError("not implemented") }
}
```

**Inputs.** Each one ends in `settle()`.

| Input | Effect |
|---|---|
| Open edge, and a start's own opening (not `.afterUpdate`) | Nothing in these cases: no ports, the switch off, a download queued, or the phase is `checkingAtLogin`, `updatingAtLogin`, `installing` or `handedOver`. Otherwise `window = .check`. A free engine starts a check. A running `checking` or `abandonedAtLogin` read is adopted, and the opening checks again once it ends (R6, R9). |
| Close edge | `window = .none`, `manualWaits = false`, `alert = nil`. The read, and any queued or running download, carry on. The card that download shows stays (R19, R21). |
| `setAutomaticUpdates(on: false)` | Saved. `window = .none`. `awaitingConnection` → `resting`. `checking(debt)` → `checking(.none)`. `checkingAtLogin` → `abandonedAtLogin(listAnswered: false)`. `updatingAtLogin`, `installing`, `queued` and `manualWaits` are untouched (R8). |
| `setAutomaticUpdates(on: true)` | Saved. Nothing else (R9). |
| `checkForUpdates()` | Without ports: `alert = .unavailable`, with no request (R22). Nothing happens unless the button is `.idle` and no alert shows. Otherwise `manualWaits = true`, and `window` goes from `.check` to `.none`, so the click takes the opening's running check and no card appears (R12). A free engine starts a check. A `checking`, `checkingAtLogin` or `abandonedAtLogin(false)` read is adopted. After `abandonedAtLogin(true)` ends, a check starts. |
| Deadline passed | When `manualWaits`: `manualWaits = false`, `alert = .checkFailed`. The read runs on, wanted by no one. A later click adopts it with a fresh 30 s (R11). |
| `updateNow()` | With the card `.available`: `want(.fromCard)`. |
| `answer(.update, to: .updateAvailable)` | `alert = nil`, then `want(.fromAlert(overCard: window == .card))`. |
| Any other answer | `alert = nil`. Nothing is remembered (R13). |

**Engine events.** Each one ends in `settle()`. A dash marks a cell that cannot occur; the event is ignored there.

| Phase | `shouldDownload(v)` | `.held` | `.cycleEnded(o)` |
|---|---|---|---|
| `checking(debt)` | – | – | `listAnswered(o)`. Then `awaitingConnection(spent)` for `.requestFailed` with the debt owed, else `resting`. |
| `checkingAtLogin(retry, dropped)` | `listAnswered(.found(v))`, `updatingAtLogin`: true | – | `listAnswered(o)`. Then `awaitingConnection(spent: retry && !dropped)` for `.requestFailed`, else `resting`. |
| `abandonedAtLogin(false)` | `listAnswered(.found(v))`, `abandonedAtLogin(true)`: false | – | `listAnswered(o)`, then `resting`. |
| `abandonedAtLogin(true)` | – | – | `resting`. |
| `updatingAtLogin` | – | Hand over, with the window as it is. | `resting`, silently. |
| `installing(i)` | true | Hand over, with the window. | `installEnded(i, o)`, then `resting`. |

Connection changes are today's: `updatingAtLogin(retry: true, _)` reads as `checkingAtLogin(retry: true, _)`, and the retry starts through `begin`.

**Lasting effects.**

| Effect | Exists while | Starts and stops in |
|---|---|---|
| A cycle (an `SPUUpdater`) | Every phase but `resting`, `awaitingConnection` and `handedOver` | `begin(_:)`, and the engine's `.cycleEnded` |
| The connection watch | `awaitingConnection`, `checkingAtLogin(retry: true, _)` | `enter(_:)` |
| The check's deadline | `manualWaits` | `enter(_:)` |
| The alert | `alert != nil` (the window is open) | Raised in `listAnswered`, on the deadline, in `installEnded` and `checkForUpdates`. Withdrawn by `answer`, the close edge and the hand-over. |
| The card, the button's title | Derived | |

#### LauncherPlatform

```swift
// SparkleEngine, still the only file that knows Sparkle.
public var shouldDownload: (@MainActor (AppVersion) -> Bool)?
// UpdateUserDriver.showUpdateFound(appcastItem, state, reply):
//   stage .installing → reply(.skip), as today (an installer left by a crash)
//   otherwise         → reply(shouldDownload?(AppVersion(appcastItem.displayVersionString)) == true ? .install : .dismiss)
// A probe that found: .cycleEnded(.found(AppVersion(the delegate's offer's version))).
// outcome(of:): an update cycle ending with SUInstallationCanceledError (4007) → .cancelled.

extension ThisCopy {
    /// This process's own `CFBundleShortVersionString`, read once at start: after a swap the bundle is the new one's.
    /// `version(of: .main)`.
    public static func version() -> AppVersion { fatalError("not implemented") }
    /// A bundle's `CFBundleShortVersionString`, never its `CFBundleVersion` (R3). A bundle without the key reads as an
    /// empty version: a built copy always has it, from `MARKETING_VERSION`. Beside `version()` as `location(of:)` sits
    /// beside `location()`, so a test can point it at a fixture bundle.
    static func version(of bundle: Bundle) -> AppVersion { fatalError("not implemented") }
}

/// One `LaunchClock` per armed wait: a 1→1 opacity animation on a zero-size layer in the clocks' never-ordered-in
/// panel, whose completion is the push. Cancelling stops the clock and its layer goes.
@MainActor public final class LayerCheckDeadline: CheckDeadline {
    public var onPassed: (@MainActor () -> Void)?
    public init() {}
    public func arm(for wait: Duration) { fatalError("not implemented") }
    public func cancel() { fatalError("not implemented") }
}
```

#### LauncherUI

```swift
/// The thumb corner group's last cell (R1-R3): one cell, so the form draws no divider inside it. 98 pt in every state,
/// per design/auto-updates.json: the form's 10 + 6; the title line, 16 (title leading, the switch trailing as in the
/// window's other rows); 4; the version line (11 pt on a 14 pt line, `.secondary`); 8; the bordered button, 162 x 24,
/// radius 6, leading; 6 + the form's 10. `formRow(height: 98)` frames the content at 78. Checked on a screenshot
/// against the JSON, as plan 048 did.
struct UpdatesRow: View {
    let updater: Updater
    static let height: CGFloat = 98
    static let buttonWidth: CGFloat = 162
    var body: some View { fatalError("not implemented") }
}

/// A button's label. `.plain`: the text. `.progress`: the word, then `ProgressDots` in a box as wide as "…", as one
/// accessibility element labelled `progress.label`, so VoiceOver reads "Checking…" and hears no dot change (R23).
/// Used by the row's button and the card's.
struct ButtonTitleView: View {
    let title: ButtonTitle
    var body: some View { fatalError("not implemented") }
}

/// Three dots that step: none, one, two, three, 250 ms each. Three period glyphs at the label's font, one centred in
/// each of three equal slots whose total width is the advance of "…" at that font. A mask anchored at the leading edge
/// covers 0, 1, 2 or 3 slots, so no dot is ever cut and the box never resizes: the word never moves. The animation runs
/// while the view is in a window on screen with Reduce motion off; otherwise the mask shows all three, still (R24).
/// It is added and removed on window, occlusion and display-options changes, idempotently, as for the card's arrow.
/// The render server plays it; no code of ours runs per frame. Hidden from accessibility. Readers injected for the bench.
final class ProgressDotsView: NSView {
    static let animationKey = "steps"
    let maskLayer = CALayer()
    init(font: NSFont, color: NSColor, isOnScreen: @escaping (NSWindow) -> Bool, reduceMotion: @escaping () -> Bool) {
        fatalError("not implemented")
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    /// keyPath `bounds.size.width`; values 0, 1, 2, 3 slots; `.discrete`; key times 0, .25, .5, .75, 1 (five: with four
    /// the last value never shows, F22); duration 1 s; `repeatCount = .infinity`; `isRemovedOnCompletion = false`.
    static func animation(slot: CGFloat) -> CAKeyframeAnimation { fatalError("not implemented") }
}
struct ProgressDots: NSViewRepresentable { /* the system label font and the disabled title colour; occlusion; NSWorkspace Reduce motion */ }

/// Shows `updater.alert` as a free-standing, app-modal `NSAlert` with the app's icon, one at a time, and sends the
/// answer back. Its observation never runs a session: one started inside a main-queue job holds the main queue,
/// gestures included (F26). It starts in a run-loop callout, whose nested run loop keeps serving the main queue.
public final class UpdateAlertPresenter {
    private let updater: Updater
    /// The alert whose session runs.
    private var showing: UpdateAlert?
    private var isScheduled = false

    /// Debug only: the `-PreviewUpdates alert` alert, shown once through the same session path; its answer is dropped.
    private var previewAlert: UpdateAlert?

    public init(updater: Updater) {
        // previewAlert = UpdatesPreview.alert(running: updater.version)              // nil in Release
        // if previewAlert != nil { changed(to: previewAlert) }                       // once, over the first opening
        // Task { for await alert in Observations({ updater.alert }) { changed(to: alert) } }
        // NSWorkspace.willPowerOffNotification → if showing != nil { NSApp.abortModal() }   // never refuse a logout (C4)
        fatalError("not implemented")
    }

    private func changed(to alert: UpdateAlert?) {
        // if let showing, showing != previewAlert, showing != alert { NSApp.abortModal() }
        //                                          // a model alert withdrawn: the window closed, a hand-over (C1)
        // guard alert != nil, showing == nil, !isScheduled else { return }
        // isScheduled = true
        // RunLoop.main.perform(inModes: [.default]) { MainActor.assumeIsolated { self.presentWhileAny() } }
        fatalError("not implemented")
    }

    private func presentWhileAny() {
        // isScheduled = false
        // while let alert = previewAlert ?? updater.alert {   // read now, not when scheduled
        //     showing = alert
        //     let response = Self.makeAlert(alert).runModal()
        //     showing = nil
        //     if alert == previewAlert { previewAlert = nil; continue }   // a preview's answer goes nowhere
        //     updater.answer(the pressed button's answer, or .dismissed for an ended session, to: alert)
        // }
        fatalError("not implemented")
    }

    /// `.informational`; title, message; the buttons in order; `isCancel` gets Escape as its key equivalent.
    static func makeAlert(_ alert: UpdateAlert) -> NSAlert { fatalError("not implemented") }
}
```

`SettingsShell.init(launcher:updater:quit:)` takes a non-optional `Updater`, keeps the presenter beside its switcher presenters and reads `Fit.card` from `updater.card`. `SettingsView.updater` is non-optional. `Lifecycle.updater` is non-optional, and `othersExited()` remains the only caller of `start`.

**Debug previews for the hand checks.** A Debug copy has no ports, so it can show only the "not available" alert. The hand checks for the dots, the alerts' look, a logout under the two-button alert and the card's refit would otherwise need a Developer ID copy and a published newer version. `UpdateCardPreview` becomes `UpdatesPreview`, still Debug-only and still the one file the shell reads it through. It takes one launch argument, `-PreviewUpdates <state>`:
- `available`: today's `-PreviewUpdateCard YES` card, now shown only while the switch is on, so turning the switch off removes it and refits the window.
- `checking`: the row's button reads *Checking…*.
- `updating`: the row's button and the card read *Updating…*.
- `alert`: the presenter shows `.updateAvailable(from: version, to: "9.9.9")` once, and drops its answer. `UpdateAlertPresenter.init` reads it and schedules it once through the same `changed(to:)` path as a model alert: the run-loop callout, `showing`, and the power-off observer. So M6 and M10 exercise the shipped session code. The presenter is built with the resident, in the same turn as the start's own opening, so the callout runs over that first window.

It overrides only what the view and the presenter render; the model never sees it. In Release builds every function passes the model's value through and reads no argument, as `UpdateCardPreview` does today.

```swift
/// What a Debug copy renders in place of the model's values, for the hand checks; read from `-PreviewUpdates`, inside
/// `#if DEBUG` only. Release: the model's values, unchanged.
enum UpdatesPreview {
    static func card(_ modelCard: UpdateCard?, isAutomaticUpdatesOn: Bool) -> UpdateCard? { fatalError("not implemented") }
    static func checkButton(_ modelButton: CheckButton) -> CheckButton { fatalError("not implemented") }
    /// The one alert `alert` shows at the first opening; nil otherwise, and always nil in Release.
    static func alert(running: AppVersion) -> UpdateAlert? { fatalError("not implemented") }
}
```

#### The test seam

Every R4-R22 scenario runs at `LifecycleWorld` / `OneProcess`, over real `Lifecycle`, `Launcher` and `Updater` objects. The harness mirrors the composition root with `UpdatableCopy(...).map { UpdatePorts($0, ...) }`, so `process.ports == nil` takes over from `process.updater == nil`. `Published` records `button` and `alert` beside `window` and `card`. The handles:

- **The 30 s:** `InMemoryCheckDeadline` with `armed: Duration?`, `arms` and `pass()`.
- **Sparkle's answers, with versions:**
  - `engine.push(.cycleEnded(.found("1.1.23")))`.
  - `engine.offer("1.1.24") -> Bool`, which asks `shouldDownload` and records `offers: [(AppVersion, Bool)]`.
  - `engine.push(.held)` makes an offer first when the cycle has made none, and counts `unconsented` when the model said no. So 039's suites run unchanged, and the fake cannot hold an update the model never took.
- **The user's answer:** `process.answer(.update)` and `process.answer(.dismissed)`. Each answers the alert that shows.
- **The switch and its persistence:**
  - `LifecycleWorld(automaticUpdates:)` and `process.setAutomaticUpdates(on:)`.
  - `PersistenceTests` covers four things: an absent key reads as on over the frozen old records; an off holds across a relaunch; an off holds across `previousVersionSaves`; the record's bytes never hold the key.
- **"No request":** as today. The log has no engine entry and there is no watch. A copy without ports has no engine at all.
- **`RunningBuild.version`:** "1.1.22" by default. `AppVersion` is `ExpressibleByStringLiteral` in the tests.
- **Every state the model published:** `OneProcess` records a `Published` state after each of its own intents and after each delivery by any of its three fakes. `Published` carries `window`, `card`, `button`, `alert` and `isAutomaticUpdatesOn`, so a row about "never" or "not until" reads every state.
- **An engine that answers inside the call:** `InMemoryUpdateEngine.answersInside`, an event the next `probe()` or `update()` pushes before returning, as `SparkleEngine` does when a cycle cannot begin. It drives `begin`'s rule that the phase is entered first.
- **Fakes that cannot do what the real adapters never would:** `offer(_:)` requires an update cycle not offered yet, and `pass()` requires an armed deadline.

On the real clock and real views:

- **`ProgressDotsBench`**, after `UpdatePictureBench`, checks:
  - the animation's literals;
  - the four steps, sampled on a paused layer at 0.125, 0.375, 0.625 and 0.875 s (F22);
  - Reduce motion and occlusion, through the injected readers;
  - that the dots are hidden from accessibility.
- **`LayerCheckDeadline`** runs with a short wait.
- **`UpdateAlertBench`** runs the real presenter over a portless `Updater`:
  1. `checkForUpdates()` shows `.unavailable`.
  2. A block hops from a background thread to the main queue, records that it ran, and answers the alert.
  3. That answer ends the session.
  A test-only common-mode timer aborts a session still up after a few seconds, so a regression that holds the main queue fails the test instead of hanging it. Tests are not scanned.
- **Tables:** `SparkleEngine.outcome(of:)` gains the `.cancelled` row. `CopyTests` pins every new string.

#### Source scan and docs

- **`SourcePolicyTests`.**
  - `runModal` becomes confined to `MoveDialogPresenter.swift` and `UpdateAlertPresenter.swift`, with the rule "two modals: the move dialog, and the update alerts, whose session starts in a run-loop callout so the main queue keeps running".
  - `abortModal` is confined to `UpdateAlertPresenter.swift`.
  - `repeatForever`, `TimelineView`, `phaseAnimator` and `keyframeAnimator` are banned under "a repeating animation is the render server's".
  - `UpdatePorts`, `UpdateAlert` and `CheckDeadline` join `keptOutOfTheFramePath`.
- **`docs/architecture.md`.**
  - Line 11: `Updater` exists in every resident copy and owns the switch (its own key beside the record), the manual check and the alerts. Its ports exist only in a copy the gate lets through. A modal runs only from a run-loop callout.
  - Line 20: the inputs gain the manual check's 30 s, an animation on a layer of its own that lives exactly while the check waits.
  - Line 21: three animations never complete, the progress dots now among them, following the arrow's rules.
  - Line 22: the Debug-only `-PreviewUpdates <state>` takes over from `-PreviewUpdateCard YES`.
  - Line 27: the network promise. With the switch off, the only requests are a *Check for updates…* click's read, its alert's *Update*, and a download already under way.
  - The `Ports.swift` doc: a version crosses only as `AppVersion`.
- **`docs/domain-model.md`.**
  - *Update check*, *Login update*, *Update card* and *Settings window* are rewritten for the switch, the row and the alerts.
  - New entries: *Automatic updates setting*, *Manual check*, *Update alert*, *Progress label*.
  - *Quit Trackpad App*: while the update alert asks *Restart Trackpad App to update?*, the Dock's *Quit* does nothing until it is answered (AppKit refuses the quit event under a two-button alert, C4). A logout, restart or shutdown ends the alert's session unanswered, so it still ends the app without asking.
  - *Hand-over*: the update alert's *Update* opens the new version with its settings window, as *Update now* does.
- **`docs/product-overview.md`.** The privacy statement.

### Synthesis decision

**Base: candidate 2.** The cross-judge scored it 23 of 25 against 20 for candidate 1 and recommended it as the base. My own criterion-by-criterion scoring agreed.

Why candidate 2:
- Its phase cases map one to one onto today's.
- Its "who waits" facts beside the phase make a click's adoption one rule.
- `begin` refuses unless the engine is free, and `settle()` starts whatever waits. A future input therefore cannot ask a busy engine, which is the invariant a maintainer is most likely to break.
- Its fake keeps 039's suites as the regression net.

Candidate 1's nested `State`/`Engine`/`Cycle`/`Reader` encoded more invariants in types, but each new input would have to decide join, queue or drain for every cycle case.

**Convergence.** Both candidates reached the same whole shape:
- `Updater` in every copy, with the gate as the ports' absence;
- the switch's own key beside the record;
- versions as a display value;
- a download gate at `showUpdateFound`;
- a deadline port over `LaunchClock` that fails the wait, not the cycle;
- adoption of in-flight reads;
- `ButtonTitle.progress`;
- Core Animation dots;
- one presenter run from a run-loop callout.

**Grafted from candidate 1:**
- The deadline armed from `enter(_:)`'s diff, keeping "every lasting effect in one transition", in place of a `didSet`.
- The user's install adopting a running login download, so the hand-over brings the window (R14) and a failure is reported (R19).
- A click during the window's own check taking its answer, so no card appears (R12's letter).
- The synchronous `shouldDownload` question, in place of candidate 2's `.offered` event with `accept()`/`decline()` and a reply held in the adapter. It is a smaller port, and no cycle can be left waiting.
- `AppVersion` (candidate 2's `Version` clashes with `CardContract.Version`) and the typed `Progress`.
- The row's arithmetic.

**Added in synthesis:**
- The dots are three periods in slots sized to the "…" glyph: the xreader mechanism, with R24's still "…".
- The judge's corrections: an explicit Escape on *Not now*, and an alert bench that fails instead of hanging.
- From the post-fan-out checks: ending the session on power-off, because a two-button alert refuses a quit Apple event (C4); and the confirmation that `abortModal()` from a main-actor job and `terminate` during a modal both work (C1, C2).

**Rejected:**
- Candidate 1's activation of the app inside the alert's session: it would pull the user away from another app. Left as an open question.
- Candidate 1's "Couldn't install the update" for an alert *Update* that finds nothing new. "Up to date" is what happened. Also an open question.
- Candidate 1's `withAnimation` ban: nothing asked for it.
- Candidate 2's `NSAlert` and `CFBundleShortVersionString` confinements: unasked churn. The `runModal` confinement covers the risk.
- Candidate 2's card-plus-alert for a click during the window's check.
- Candidate 2's `want` ignoring a running login download.

### Tradeoffs accepted

- We accept `Updater` in every copy, with the gate's absent object becoming `UpdatePorts`. In exchange, one object stands behind the row, the card and the alerts, and R22 is decided and tested in the model. No copy gains an engine.
- We accept a second persisted fact beside the record. In exchange, `Launcher` still knows nothing about updates, there is no change closure, and an older build's save cannot drop an off.
- We accept reshaping 039's phases (`probing`/`droppedProbe` into `checking`, `offering` into the window stake, `updatingAtLogin` split at the offer, `updatingFromCard` into `installing`). In exchange, one rule covers "wanted while the engine is busy". Every case in the 039 log still has a state that holds it, and the existing suites are the regression net.
- We accept that a click may be answered by a read that began before it. In exchange, a second read is never queued behind one that cannot be cancelled.
- We accept that a click during a login read shows "Restart Trackpad App to update?" while the login update already downloads, that the button reads *Updating…* under that alert rather than *Check for updates…* (R15 over R11), and that *Not now* does not stop the download. In exchange, R6's login update stays unchanged and R16's last scenario is reachable.
- We accept that *Update now* clicked during *Checking…* supersedes the click: the download is queued behind the read, the click's wait ends, and no alert answers it. In exchange, no update alert can offer an update that is already on its way.
- We accept that a click during the window's own check takes its answer, so that opening shows the alert and no card.
- We accept that a timed-out read keeps the engine busy until Sparkle ends it, up to its own 60 s idle timeout (F9). A download asked for meanwhile waits, reading *Updating…*.
- We accept that a display sleep during *Checking…* can read as 30 s passed, a false "Couldn't check for updates" at worst. In exchange, there is no timer.
- We accept a second copy of the arrow's on-screen and Reduce-motion gating in the dots view. In exchange, the shipped arrow stays untouched. The dots restart from none when the window returns.
- We accept an alert on screen for a moment during `make test`. In exchange, a test fails when someone moves `runModal` back into a main-queue job.
- We accept a semantic `.secondary` version line whose dark appearance the shipped app cannot show while the window is pinned light (F16). It is checked by hand in a Debug run with the pin removed locally and never committed.

### Alternatives considered

- **`Updater?` stays absent, the switch is a field of `Launcher`'s record, and the shell answers R22 from `updater == nil`.** This keeps the gate's wording and the settings recipe, but callers would coordinate:
  - the row would talk to `Launcher` for the switch, to `Updater?` for the button and to the shell for the alert;
  - `Launcher` would need a second closure to tell `Updater` of a change;
  - an older build's save would drop an off.
  It hides nothing this shape does not.
- **One phase per combination, extending today's enum** (`probing(manual:)`, `updatingAtLogin` with stage, abandoned and manual fields, a queued download on each). The interface is the same, but every transition must prove by cases that it never asks a busy engine. The 039 log records four defects from interactions of exactly this kind.
- **The manual check as an update cycle held open at Sparkle's offer while the alert shows.** It is one cycle with no second read. But it breaks R14 (the list read once more, and a newer release meanwhile installs), keeps an `SPUUpdater` alive while the alert waits, and blocks every other cycle behind an unanswered alert.
- **The 30 s inside the engine, as `probe(within:)`.** The port would be smaller. But the engine cannot end a cycle Sparkle still runs, and a click that adopted a running read has no `probe` call to carry the limit.
- **Presenting the alerts as the move dialog does, from its `Observations` task.** It would freeze gestures for as long as an alert shows (F26, F27).
- **SwiftUI dots (`TimelineView`, `phaseAnimator`).** They run code of ours per frame, which the architecture rules out and plan 037 measured as costly.

### Open questions and risks

- Is it acceptable that `Updater` exists in every copy, with the gate kept as the absence of `UpdatePorts`?
- Should an update alert bring Trackpad App to the front when the user switched to another app during *Checking…*? The design takes no activation: the alert waits behind the front app, and the window stays blocked until it is answered.
- When a click lands during a login read that then finds a version, the update alert shows over a login download that *Not now* cannot stop. Is that right, or should the button go straight from *Checking…* to *Updating…* with no alert?
- Should a manual check that finds nothing new remove a card that offers *Update available*, as designed?
- When the alert's *Update* re-reads the list and finds nothing new (a release withdrawn), is "Trackpad App is up to date" the right alert?
- R10 says a click "MUST read the update list once". The design answers a click with exactly one read, which may be one already running: a window check, a dropped check, a timed-out check or a login read. It never queues a second read behind one that cannot be cancelled. Should R10 say "is answered by exactly one read of the update list, which may be one already running"?
- R11 says the button returns to *Check for updates…* when the check's alert shows. A click answered by a login read shows its alert over a download, so the button reads *Updating…* (R15). R12, R17 and R18 say a manual check's result shows an alert, yet *Update now* during *Checking…* ends the wait with no alert. Are both the intended reading?
- Is a semantic secondary colour, checked by hand with the light pin removed locally, enough for R2's dark-appearance scenario until the window's dark theme is designed (F16)?
- The move dialog runs its session from a `Task`, so it holds gestures for a login-started resident outside /Applications that is opened by hand (F27). It also refuses a logout while it shows (C4). Should that be fixed with the same callout and power-off handling in a plan of its own?
- **Risk: declining an offer** rests on Sparkle's documented *dismiss* at `showUpdateFound`. Does the cycle then end with `didFinishUpdateCycle`, with nothing remembered? T6 proves it on the pinned 2.10.1, with real cycles against a feed the test serves on 127.0.0.1.
- **Risk: R20** rests on a cancelled administrator prompt ending with `SUInstallationCanceledError` (4007) in every case. That is documented, not proven by a cycle test.
- **Risk: logout.** Does `NSWorkspace.willPowerOffNotification` always arrive before loginwindow's quit event, so that ending the session lets the logout through? This is a hand check: a real logout with the update alert up.
- **Risk: appearance.** The dots' font and colour must match a disabled bordered button's own title, in the row and on the card. The alert must show again after a hide and a reopen (F28 did not measure it). Both are hand checks.

### Next implementation step

Slice S1: reshape `Updater`'s state and the engine port, with the switch always on and no manual check, test-first from T1-T7, and get the existing update suites green over the new shape. The pieces are `AppVersion`, `.found(AppVersion)`, `shouldDownload`, `UpdatePorts`, `State`/`Phase`, `begin`, `settle` and `enter`, with the in-memory engine offering before `.held`.

## Testing Decisions

### Strategy

The design names one high seam, and nearly every requirement is proven there. `LifecycleWorld` / `OneProcess` (`LauncherKit/Tests/LauncherCoreTests/LifecycleWorld.swift`) runs real `Lifecycle`, `Launcher` and `Updater` objects and the real `SettingsStore` on a throwaway `UserDefaults` suite, and mirrors the composition root's gate as `UpdatableCopy(...).map { UpdatePorts($0, ...) }`. Only the ports are faked, as the architecture requires:
- Sparkle is `InMemoryUpdateEngine`. It holds every cycle until the row answers it (`push(.cycleEnded(_))`, `push(.held)`, `offer(_:)`), so a read or a download still running is the held call a row forces an interleaving against.
- The network path is `InMemoryConnection`, whose returns a row injects.
- The 30 s clock is `InMemoryCheckDeadline`. Only a row about the limit passes it; every other row proves its answer came by the event path.
- The hand-over job is `armRestart`, and `finishHandOver` starts the next process on the same Mac.

A row reads the `Published` history (window, card, button, alert, the switch), the engine's counts (probes, updates, offers, unconsented, overlaps, arms), the watch, the deadline's arms, the shared effect log and the suite's keys. "No request" is today's assertion: no engine entry in the log and no watch; a copy the gate turns away has no ports at all. The rows resemble `UpdateCardTests.swift`, `UpdateRetryTests.swift`, `HandOverTests.swift`, `PersistenceTests.swift` and `MixedTrackpadsTests.swift`. This seam misses the views, the presenter, AppKit's modality, Sparkle and the real clock.

Each of those is tested at its own interface:
- **`SparkleEngine`**: `outcome(of:)` and the offer reply as tables, and real `SPUUpdater` cycles against a feed the test serves on 127.0.0.1. These settle the design's risk that a *dismiss* at `showUpdateFound` ends the cycle with nothing downloaded or remembered. They resemble `SparkleEngineTests.swift` and `SparkleEngineCycleTests.swift`. A probe here showed that a `swift test` process loads plain http from 127.0.0.1 (`.temp/test-planner/probes/runloop/Tests/ProbeTests/LocalHTTPTests.swift`).
- **`LayerCheckDeadline`**, on the render server's clock with waits of a few hundred milliseconds, asserting lower bounds only, as `LaunchWatchClockTests.swift` does.
- **`ProgressDotsBench`**, after `UpdatePictureBench.swift`: the real `ProgressDotsView` in a window that is never ordered in, its on-screen and Reduce motion readers injected, its mask sampled on a paused layer (F22). Beside it, `ButtonTitleView` in an `NSHostingView` shows which titles host the dots (F23).
- **`UpdateAlertBench`**: the real `UpdateAlertPresenter` over a portless `Updater`, running real `runModal` sessions on screen. A common-mode `Timer` (tests are not scanned) aborts a session still up after 5 s and fails the row, so a regression that holds the main queue fails rather than hangs. A probe here showed two things (`.temp/test-planner/probes/runloop/Tests/ProbeTests/RunLoopTests.swift`, `ranDuringModal=true`):
  - `swift test` runs the main run loop in its default mode;
  - a modal started from a `RunLoop.main.perform` callout lets a background thread's main-queue block run during the session.

Value tests (`CopyTests`, `UpdateAlert`, `CheckButton`, `ButtonTitle`) and the source scan (`SourcePolicyTests`) complete the tests. The 039 update suites (`UpdaterStartTests`, `UpdateCardTests`, `UpdateRetryTests`, `HandOverTests`) stay the regression net for R6, edited only mechanically.

The rows use the handles the design's "The test seam" lists. Four of them serve the techniques directly:
- the `Published` record after every fake delivery, so rows about "never", "at no moment" and "not until" read every state the model published;
- `answersInside`, which drives `begin`'s rule that the phase is entered first;
- the `offer(_:)` and `pass()` preconditions, so a row cannot do what the real adapter never would;
- `Published.isAutomaticUpdatesOn`, the abandoned process's own log in the kill-at-random row.

`LifecycleWorld(automaticUpdates: false)` seeds the switch's wire key, as `MixedTrackpadsTests` seeds `externalThumbCorner`.

Hand checks cover the rest:
- the row against the JSON;
- the alerts' look and VoiceOver;
- the dots' feel;
- gestures and a logout during an alert;
- the live network on a Developer ID copy.

The design's Debug previews (`-PreviewUpdates <state>`) let every check that needs only what the window and the alert render run on a Debug build. The 30 s on a live connection and the real update still need a Developer ID release.

### Test scenarios

Terms used in the rows:
- *World*: `LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)`. *Off world*: the same with `automaticUpdates: false`.
- *Release copy*: `world.launch(.byHand, running: .release)`. It is Developer ID signed, lies in /Applications, can write, runs 1.1.22, and has its window open and its start's probe running. *Answered*: a release copy whose start's probe ended `.nothingNew`.
- *Login copy*: `world.launch(.atLogin, running: .release)`, with its window closed and its login cycle's `update()` made and not yet offered. *Offered*: then `engine.offer("1.1.23")` answered true, so the login update downloads. *Waiting login copy*: a login copy whose cycle ended `.requestFailed` with the connection down, so it watches.
- *Found*: `engine.push(.cycleEnded(.found("1.1.23")))`. *Card showing*: a release copy after *Found*. *Updating from the card*: a card showing, then `updateNow()`.
- *Clicked*: `checkForUpdates()`. *Update*, *Not now*, *OK*: `answer(.update)` or `answer(.dismissed)` to the alert that shows. *The switch turns off* (or *on*): `setAutomaticUpdates(on:)`.
- *No request*: no `probe`, `update`, `discard` or `arm restart` entry is added to the world's log, and `connection.watches` is unchanged. *Ends*: the log's last entry is `end`.
- *Gate-refused copies*: every copy `UpdatableCopy` turns away whose opening by hand shows the window. These are `.installed` unsigned, `.development` signed and `.development` unsigned, each with `canWrite` true and false. A release copy elsewhere shows only the move dialog.
- Every `LifecycleWorld` row also expects `engine.overlaps == 0`, and `engine.unconsented == 0` unless it says otherwise.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R6 | LifecycleWorld | Given a login copy: `updates == 1` and no offer yet. When `engine.offer("1.1.23")`. Then it answers true and `offers` holds 1.1.23 accepted. When the window opens by hand and `.held` is pushed. Then no probe was made, `card` is nil in every Published state, `arms == [true]`, and the process ends. | R6 scenario "Login update with the switch on"; domain-model *Login update* (opening the window during it makes no check and shows no card; the hand-over then brings the window) |
| T2 | R6 | LifecycleWorld | Given a release copy: `probes == 1`. When *Found*. Then `card == .available`, `updates == 0`, and `offers` is empty. | R6 scenario "Window check with the switch on"; the port's doc ("Never asked for a probe") |
| T3 | R6, R22 | LifecycleWorld | For each gate-refused copy, started by hand, then in a new process at login. When the window closes and opens five times and the connection drops and returns twice. Then `ports == nil`, `updater.version == "1.1.22"`, and no request. | F1 (the gate); R22 "such a copy has nothing for it to turn on or off"; `UpdaterStartTests`' gate table |
| T4 | R6, R13 | SparkleEngine | The offer reply as a table over the stage Sparkle reports and the model's answer. `.notDownloaded` and `.downloaded` ask `shouldDownload` once and reply *install* for true, and *dismiss* for false or an unset question. `.installing` replies *skip* and never asks. | The port's doc for `shouldDownload` ("Unset: false", never asked "for an update Sparkle is already installing"); F8 (*dismiss* downloads nothing); R13 (no version skipped) |
| T5 | R12, R14 | SparkleEngine | `outcome(of:)`, extended. A probe with no error whose delegate found the item 1.1.23 ends `.found("1.1.23")`; with nothing found, `.nothingNew`. Every existing row keeps its outcome. | F5 (the found item's `displayVersionString`); the existing outcome table |
| T6 | R6, R8, R12, R13 | SparkleEngine cycle | Given a throwaway host at build 1 whose feed the test serves on 127.0.0.1. The feed lists build 2 with `sparkle:shortVersionString` "1.1.23" and an enclosure under the host's pinned prefix, and the server records each path asked for. (a) `probe()` ends `.cycleEnded(.found("1.1.23"))`; `shouldDownload` is never asked and the enclosure never requested. (b) `update()` with `shouldDownload` answering false asks it exactly once, with "1.1.23". The cycle ends with a `.cycleEnded`, the enclosure is never requested, and the host's defaults hold no skipped version. A second `update()` asks again with "1.1.23". (c) `update()` with `shouldDownload` answering true requests the enclosure; the server answers 404 and the cycle ends `.failed`. | The feed the row serves; F8 (*dismiss* downloads nothing); R13 "no version is skipped"; the design's risk on `decline()`, which asks for exactly this proof on the pinned 2.10.1 |
| T7 | R3 | ThisCopy | Given a fixture bundle whose Info.plist holds `CFBundleShortVersionString` "1.1.22" and `CFBundleVersion` "25". Then `ThisCopy.version(of:)` reads "1.1.22". Given one with only `CFBundleVersion` "25". Then it reads an empty version, never "25". | R3 "without the build number (for example "Current version: 1.1.22")"; `Config/Version.xcconfig` (`MARKETING_VERSION` beside `CURRENT_PROJECT_VERSION`); the design's doc of `version(of:)` (a bundle without the key reads as an empty version) |
| T8 | R23 | ProgressDotsBench | Given a dots view on screen with Reduce motion off. Then the mask's animation under `animationKey` has keyPath `bounds.size.width`, values 0, 1, 2 and 3 slots, `calculationMode == .discrete`, key times [0, 0.25, 0.5, 0.75, 1], duration 1, `repeatCount == .infinity` and `isRemovedOnCompletion == false`. | R23 (a 1-second loop of four equal 250 ms steps: none, one, two, three, switching instantly); F22 (five key times for four discrete values) |
| T9 | R23 | ProgressDotsBench | Given T8's view with its mask layer paused (`speed = 0`). When `timeOffset` is set to 0.125, 0.375, 0.625, 0.875, 1.125, 1.375, 1.625 and 1.875 s in turn. Then the mask's presented width is, in slots, 0, 1, 2, 3, 0, 1, 2, 3. | R23 scenario "Dots cycle"; F22 (paused-layer sampling) |
| T10 | R23 | ProgressDotsBench | As T9, at 0.24 and 0.26, 0.49 and 0.51, 0.74 and 0.76, and 0.99 and 1.01 s. Then the widths are 0 and 1, 1 and 2, 2 and 3, and 3 and 0 slots. | R23's 250 ms steps and 1 s loop, each boundary sampled 10 ms either side |
| T11 | R23 | ProgressDotsBench | Given T8's view. Then its width equals the advance of "…" in its font as `NSAttributedString.size()` measures it, and a slot is a third of that. At every sample of T9 the view's frame is unchanged and the mask's origin is the view's leading edge. | R23 "The word MUST NOT move as the dots change"; AppKit's own text measurement |
| T12 | R24 | ProgressDotsBench | (a) Given a view whose Reduce motion reader answers on before it enters the window. Then it has no animation and its mask shows 3 slots. (b) Given an animating view. When the reader turns on and the display-options notification is posted. Then the animation is gone, the mask shows 3 slots at once and nothing animates its bounds. When the reader turns off and the notification is posted. Then T8's animation is back. | R24 "a progress label MUST show a static "…""; scenario "Reduce motion" |
| T13 | R23 | ProgressDotsBench | Given an animating view. When the window reports itself off screen (occlusion), then on screen; and when the view leaves the window, then enters it again. Then the animation is gone while off screen or outside a window and back on each return. Repeated notifications leave exactly one animation under the key. A view that arrives in a window already off screen starts none. | R23: the dots step whenever the label shows, the window closed and opened again included; `UpdatePictureTests` (the arrow's same rules) |
| T14 | R23 | ProgressDotsBench, values | The dots view is not an accessibility element and exposes no accessibility children. `Progress.checking` has word "Checking" and label "Checking…"; `Progress.updating` has "Updating" and "Updating…". | R23 "VoiceOver MUST read a stable label, "Checking…" or "Updating…", and announce no dot changes" |
| T15 | R23, R25 | NSHostingView | Given `ButtonTitleView` hosted in a window that is never ordered in, laid out. For `.plain("Check for updates…")` and `.plain("Update now")` the subtree holds no `ProgressDotsView`; for `.progress(.checking)` and `.progress(.updating)` it holds exactly one. `UpdateCard.available.buttonTitle == .plain("Update now")` and `UpdateCard.updating.buttonTitle == .progress(.updating)`. | R25 and its scenario "Idle button"; R23 (the card's *Updating…*); F23 (a representable's view is a real subview) |
| T16 | R23 | Source scan | `repeatForever`, `TimelineView`, `phaseAnimator` and `keyframeAnimator` are banned in every shipped file under the rule "a repeating animation is the render server's", and a planted use fails the scan. | `docs/architecture.md` (Core Animation keyframes; no code of ours per display frame); plan 037's measurement |
| T17 | R4 | LifecycleWorld | (a) Given a Mac that never saved settings. When a release copy starts by hand, a first run. Then the switch is on and the suite holds no `automaticUpdatesOff`. (b) Given the frozen released record `PersistenceTests.savedSettings` seeded. When a release copy starts as `.afterUpdate(withWindow: true)`, then its window closes and opens. Then the switch is on, the start made no request, and the reopening made one probe. | R4 and its scenario "Upgrade from 1.1.x"; F13 (start and reconcile save nothing) |
| T18 | R4, R5 | LifecycleWorld | Given a release copy. (a) The switch turns off: the suite holds `automaticUpdatesOff` within that input, and `settingsRecordBytes()` is unchanged and holds no such key. It turns on: the key is gone. (b) Off, then `previousVersionSaves { $0.isSwipeOn = false }`: a new process reads the switch off and the swipe off. (c) A suite seeded with `automaticUpdatesOff` holding a string, and one holding `false`, each load the switch off, and a login start makes no request. | R5 "saved at once"; design decision 1 (the key's presence is the fact: present, whatever it holds, is off; an off survives a downgrade and its saves); `World.previousVersionSaves` |
| T19 | R5, R6 | LifecycleWorld | Given a release copy whose switch turns off. (a) When it is abandoned with no quit, a force quit, and a release copy starts at login. Then that copy's switch is off and no request. (b) When it quits and a release copy starts at login, as after a restart. The same. (c) Given the switch turned off then on: the login start makes one `update()` and a later opening by hand one probe. | R5 and its scenario "Off survives a restart"; R6 |
| T20 | R5 | LifecycleWorld | For each of 50 seeds. Given a release copy. A seeded generator picks n in 1...12 and k in 0...n, and the copy flips the switch k times through `setAutomaticUpdates(on: !isAutomaticUpdatesOn)` and is abandoned with no quit. Then a login start on the same Mac reads the switch as the abandoned process's last Published `isAutomaticUpdatesOn`. The suite holds `automaticUpdatesOff` exactly when that value is off, and `engine.updates` is 1 when on and 0 when off. | The abandoned process's own history; R5 "survives ... a force quit" |
| T21 | R7 | LifecycleWorld | Given an off world. When a release copy starts at login, the connection drops and returns three times, and the window opens by hand and closes twice. Then no request, no `arm restart`, and nothing installs. | R7 scenario "Login start with the switch off" |
| T22 | R7 | LifecycleWorld | Given an off world, for a release copy and for one that cannot write. When it starts by hand and its window closes and opens three times. Then no request, and `card` is nil in every Published state. | R7 scenario "Window opening with the switch off"; F2 (the start stands in for the first opening) |
| T23 | R8 | LifecycleWorld | Given a card showing. When the switch turns off. Then the Published state of that input has no card and the one before it `.available`. | R8 scenario "Card disappears" |
| T24 | R8 | LifecycleWorld | Given a release copy whose start's probe is unanswered. When the switch turns off, then *Found*. Then no Published state ever has a card and no second probe is made; closing and opening the window makes none either. | R8 scenario "Switch off before the window check answers" |
| T25 | R8 | LifecycleWorld | Given a waiting login copy. When the switch turns off. Then `isWatching` is false within that input. When the connection returns. Then no request (`updates == 1`). | R8 scenario "Waiting retry is cancelled" |
| T26 | R8 | LifecycleWorld | (a) Given a waiting login copy whose window then opens, so its probe runs owing the retry. When the switch turns off, `connection.reading` becomes true, and the probe ends `.requestFailed`. Then no watch starts and `updates == 1`. (b) Given a waiting login copy whose retry runs (the connection returned, the watch on). When the switch turns off. Then the watch stops within that input. | R8 "end a failed login check's wait for a connection"; `UpdateCardTests.aLoginCheckFailedForTheNetworkLeavesTheWindowsCheckToTakeOverItsRetry` (the window's check owes the retry) |
| T27 | R8 | LifecycleWorld | Given a login copy. When the switch turns off, then `engine.offer("1.1.23")`. Then it answers false. `push(.held)` delivers nothing and `unconsented == 1`; `arms` is empty; the button never reads *Updating…*. After the cycle ends, an opening by hand makes no request. | R8 "A login check still running MUST be dropped before it downloads anything" |
| T28 | R8 | LifecycleWorld | (a) Given updating from the card. When the switch turns off, then `.held`. Then `card == .updating` up to the hand-over, `arms == [true]`, and the process ends. (b) Given an offered login copy whose window has opened since. When the switch turns off, then `.held`. Then `arms == [true]`; with the window closed instead, `arms == [false]`. | R8 scenario "Running download carries on"; domain-model *Hand-over* (a login update brings the window only when it is open) |
| T29 | R8, R9 | LifecycleWorld | Given updating from the card, then the switch off. When the cycle ends `.failed`. Then there is no card, and none when the switch turns on again; a tap of 1 still brings Arc forward. When the window closes and opens and *Found* follows. Then one probe and `.available`. | R8 scenario "Update now fails after the switch went off"; R9 "Automatic checks resume at ... the next opening" |
| T30 | R9 | LifecycleWorld | Given an off world and a release copy started by hand. When the switch turns on. Then no request. When the window closes and opens. Then one probe. | R9 scenario "Turn on while the window is open" |
| T31 | R9 | LifecycleWorld | Given a card showing. When the switch turns off, then on. Then no Published state from the off onward has a card. When the window closes and opens and *Found* follows. Then `.available`. | R9 scenario "Card stays gone after off and on" |
| T32 | R9 | LifecycleWorld | Given a waiting login copy. When the switch turns off, then on, and the connection returns. Then no request. | R9 "MUST NOT start an update check"; R8 (the wait ended) |
| T33 | R6, R9 | LifecycleWorld | Given a login copy. When the switch turns off, then on, and the window opens by hand. Then no probe is made. When `engine.offer("1.1.23")`. Then it answers false, the card shows `.available`, and nothing downloads. | The design's inputs table (an opening adopts a running `abandonedAtLogin` read); R9 (turning on resumes no login update); R6 (the opening's check and its card) |
| T34 | R7, R10, R11 | LifecycleWorld | Given an off world and a release copy started by hand. When clicked. Then `probes == 1`, `updates == 0`, `watches == 0`, `checkButton == .checking` (title `.progress(.checking)`, not enabled), and `deadline.armed == .seconds(30)`. When the probe ends `.nothingNew`. Then `alert == .upToDate("1.1.22")`, the button is `.idle`, `deadline.armed == nil`, and still `probes == 1`. | R10 scenario "Manual check with the switch off" (exactly once); R11; R7's exception |
| T35 | R10, R12 | LifecycleWorld | Given a card showing. When clicked. Then a second probe. When *Found*. Then `alert == .updateAvailable(from: "1.1.22", to: "1.1.23")` and the card is `.available` in every Published state. | R10 scenario "Manual check while the card shows" |
| T36 | R11 | LifecycleWorld | Given an answered release copy. When clicked, clicked again, then *Found*. Then the second click made no probe and `deadline.arms == [.seconds(30)]`. Every Published state from the first click up to the answer has the button `.checking` and no alert; the answer's state has the alert and the button `.idle` together. | R11 scenario "Slow connection" (greys out until the alert appears; a second click does nothing); R11 "return to Check for updates… when the check's alert shows" |
| T37 | R11, R18 | LifecycleWorld | Given an answered release copy, clicked, its probe unanswered. When `deadline.pass()`. Then `alert == .checkFailed` and the button `.idle`. When *OK* and then *Found*. Then no alert and no card follow, and no probe is added. | R11 scenario "No answer within 30 seconds" (the 30 s is `deadline.armed`); R18 |
| T38 | R11 | LifecycleWorld | Given T37 after `pass()` and *OK*, the read still running. When clicked. Then no probe is added, `deadline.arms == [.seconds(30), .seconds(30)]`, and the button is `.checking`. When *Found*. Then `.updateAvailable(from: "1.1.22", to: "1.1.23")`. | The design: "A later click adopts it with a fresh 30 s"; F4 (one cycle at a time) |
| T39 | R11, R18 | LifecycleWorld | Given an answered release copy with `engine.answersInside = .cycleEnded(.failed)`. When clicked. Then within that input the probe is made and answered: `alert == .checkFailed`, the button `.idle`, `deadline.armed == nil`. | The design's `begin` ("The phase is entered first: the engine may answer inside the call"); `SparkleEngineCycleTests.anEmptyKeyEndsTheCycleFailedAtOnceAndLeavesNoUpdater` |
| T40 | R12 | LifecycleWorld, values | Given an answered release copy running 1.1.22. When clicked and *Found*. Then the alert's `title` is "Restart Trackpad App to update?" and its `message` "Update Trackpad App from 1.1.22 to 1.1.23.\n\nTrackpad App will quit to install the update and open again.". Its `buttons` are *Update* (`.update`), then *Not now* (`.dismissed`, `isCancel`). | R12 and its scenario "Newer version published" |
| T41 | R12, R13 | LifecycleWorld | Given an off world and a release copy started by hand. When clicked, *Found*, then *Not now*. Then the alert showed, no Published state has a card, and `updates == 0`. When clicked and *Found* again. Then the alert offers 1.1.23 again. | R12 scenario "No card from a manual check"; R13 scenario "Not now, then check again" |
| T42 | R12 | LifecycleWorld | Given a release copy whose start's probe, the window's own check, is unanswered. When clicked. Then no probe is added and the button is `.checking`. When *Found*. Then the alert shows and no Published state has a card. | R12 "A manual check MUST never add the update card"; design decision 3 (the click takes the opening's running check) |
| T43 | R17 | LifecycleWorld, values | Given an answered release copy running 1.1.22, clicked. When `.nothingNew`. Then `.upToDate("1.1.22")`: title "Trackpad App is up to date", message "You're running the latest version, 1.1.22.", and one button, *OK*. | R17 and its scenario |
| T44 | R18 | LifecycleWorld, values | For each of `.requestFailed` and `.failed`: an answered release copy, clicked, then that outcome. Then `.checkFailed`: title "Couldn't check for updates", message "Check your internet connection and try again.", one *OK*; the button `.idle`. When the connection drops and returns. Then no request and `watches == 0`. | R18 and its scenario "Offline" (nothing retries by itself) |
| T45 | R21 | LifecycleWorld | Given an off world and a release copy, clicked. When the window closes. Then `deadline.armed == nil` and the button `.idle`. When *Found*, then the window opens. Then no Published state from the close onward has an alert or a card, and the button is `.idle`. | R21 scenario "Close during Checking…" |
| T46 | R6, R21 | LifecycleWorld | Given an answered release copy, clicked. When the window closes and opens before the answer. Then no probe is added. When *Found*. Then `card == .available` and no alert ever shows. | R21 (no alert at the next opening); R6 (each opening checks); the design's inputs table (an opening adopts a running `checking` read) |
| T47 | R8 | LifecycleWorld | (a) Given an answered release copy, clicked. When the switch turns off, then *Found*. Then `.updateAvailable` shows, and the deadline stayed armed up to the answer. (b) Given a login copy whose window opened by hand, clicked, making no request. When the switch turns off and `engine.offer("1.1.23")`. Then it answers false, `.updateAvailable(from: "1.1.22", to: "1.1.23")` shows, and the button is `.idle`. | R8 "A manual check still running MUST carry on unaffected"; R8 (a login check dropped before it downloads) |
| T48 | R22 | LifecycleWorld, values | For each gate-refused copy started by hand. When clicked. Then `alert == .unavailable` (title "Updates aren't available for this copy", message "This copy of Trackpad App can't update itself.", one *OK*), no request, and the button `.idle` before and after. When the window closes. Then no alert. When the switch turns off and a new process starts. Then it reads off. | R22 and its scenario "Debug build" |
| T49 | R21, R26 | LifecycleWorld | Given an answered release copy, clicked and *Found*, so `.updateAvailable` shows. (a) When clicked again. Then nothing changes. (b) When the window closes. Then `alert == nil`. When `updater.answer(.update, to:)` arrives for that alert, as the presenter's late answer. Then no `update()` is made. | Design decision 9 ("An answer to a withdrawn alert does nothing"); R26 (no clicks until answered); R21 |
| T50 | R5, R7, R14 | LifecycleWorld | Given an off world and a release copy, clicked and *Found*. When *Update*. Then one `update()` and the button `.updating`. `engine.offer("1.1.23")` answers true; `.held` arms `[true]` and the process ends. When `finishHandOver()`. Then the new copy's window is open, its switch off, and it made no request, nor does it when its window closes and opens. | R14 scenario "Update with the switch off"; R5 scenario "Off survives an update from the alert"; R7's exception |
| T51 | R22, R26 | UpdateAlertBench | Given a portless `Updater` and its presenter. When `checkForUpdates()` is called, and a background thread dispatches to the main queue until a block finds `NSApp.modalWindow` set. That block records that the modal window has no `sheetParent` and shows "Updates aren't available for this copy", then sends `updater.answer(.dismissed, to: .unavailable)`. Then the session ends, the safety timer never fired, `updater.alert == nil`, and no modal window remains. | F26 (a modal started in a run-loop callout keeps serving the main queue; one started in a main-actor job does not); C1 (`abortModal` from a main-actor job ends it); R26 (app-modal, free-standing) |
| T52 | R26 | UpdateAlertBench | As T51, except the block posts `NSWorkspace.willPowerOffNotification` instead of answering. Then the session ends, the presenter answers `.dismissed`, `updater.alert == nil`, and the safety timer never fired. | C4 (a two-button alert refuses a quit Apple event) and the design's fix; domain-model *Quit Trackpad App* (logging out ends the app without delay) |
| T53 | R12, R17, R18, R19, R22 | Values | `UpdateAlertPresenter.makeAlert` for each `UpdateAlert` case: style `.informational`; `messageText` and `informativeText` are the alert's `title` and `message`; the button titles are `buttons`' titles in order; the first button's key equivalent is Return and *Not now*'s is Escape. `.installFailed(running: "1.1.22")` reads "Couldn't install the update" and "Trackpad App 1.1.22 keeps running. Try again later.", with one *OK*. | R12, R17, R18, R19 and R22 literals; R12 "*Update* the default"; the design's explicit Escape on *Not now* |
| T54 | R11 | LayerCheckDeadline | (a) Armed for 200 ms: `onPassed` runs once, not before 200 ms; a `cancel()` after it changes nothing, and nothing follows within 1 s. (b) Armed for 200 ms and cancelled at once: nothing within 1 s. (c) Armed for 2 s, then armed again for 200 ms: one pass, not before 200 ms after the second arm, and none after. (d) After (a) to (c), the clocks' host panel closes once no other clock is open. | The port's doc ("Calls `onPassed` once after `wait`, unless cancelled or armed again first"); `LaunchWatchClockTests` (lower bounds only; the host closes with the last clock) |
| T55 | R1, R3, R10, R11, R15 | Values | `Copy.automaticUpdatesRow == "Automatic updates"` and `Copy.currentVersion("1.1.22") == "Current version: 1.1.22"`. `CheckButton.idle.title == .plain("Check for updates…")`, `.checking.title == .progress(.checking)`, `.updating.title == .progress(.updating)`, and only `.idle` is enabled. | R1, R3's example, R10, R11 and R15 literals |
| T56 | R26 | Source scan | `runModal` is confined to `MoveDialogPresenter.swift` and `UpdateAlertPresenter.swift` under the design's two-modal rule, `abortModal` to `UpdateAlertPresenter.swift`, and `UpdatePorts`, `UpdateAlert` and `CheckDeadline` join the frame-path scan. A planted use outside fails. | The design's "Source scan and docs"; F27 |
| T57 | R10, R12, R14, R15, R16 | LifecycleWorld | Given a waiting login copy whose connection returned, so its retry runs, and whose window opened by hand. When clicked. Then no request and `deadline.armed == .seconds(30)`. When `engine.offer("1.1.23")`. Then it answers true, `.updateAvailable(from: "1.1.22", to: "1.1.23")` shows, the button reads `.updating`, and the deadline is cancelled. When *Update*. Then `updates` stays 2, the button stays `.updating`, and no card shows. When `.held`. Then `arms == [true]`. | R16 scenario "Update while a login retry downloads"; R14 (the hand-over opens the window); Tradeoffs accepted (the button reads *Updating…* under that alert, R15 over R11) |
| T58 | R16, R26 | LifecycleWorld | Given T57 up to the alert showing over the login download. When `.held` arrives before any answer. Then `alert == nil`, `arms == [true]`, and the process ends. | The design (the hand-over withdraws the alert); C2 (a terminate during the modal ends the process) |
| T59 | R14 | LifecycleWorld | Given an answered release copy, clicked and *Found* (the alert offers 1.1.23). When *Update*, then `engine.offer("1.1.24")`. Then it answers true and `offers` names 1.1.24; `.held` arms `[true]`. | R14 scenario "A newer release meanwhile" |
| T60 | R14, R16, R21 | LifecycleWorld | Given *Update* clicked with no card showing. When the window closes, then opens. Then no probe, no card in any Published state, and the button `.updating`. When the window closes and `.held` arrives. Then `arms == [true]`. | R16 scenario "Window reopened during an update from the alert"; R21 (the download carries on); R14 (opens with its settings window) |
| T61 | R15 | LifecycleWorld | Given a card showing. When clicked, *Found*, then *Update*. Then `card == .updating` and the button `.updating`, neither enabled. | R15 scenario "Update from the alert while the card shows" |
| T62 | R16 | LifecycleWorld | (a) Given an offered login copy. When the window opens by hand. Then no probe, no card, and the button `.updating`. (b) Given updating from the card. When the window closes and opens. Then no probe, `card == .updating`, and the button `.updating`. | R16 scenarios "Window opened during a login update" and "Window reopened during Update now" |
| T63 | R16 | LifecycleWorld | Given a login copy. The switch turns off, the window opens, and the copy is clicked; `engine.offer("1.1.23")` answers false and the alert shows. When *Update*. Then no `update()` yet and the button `.updating`. When the declined cycle ends. Then `updates == 2`; `engine.offer("1.1.23")` answers true; `.held` arms `[true]`. | R16 "At most one download MUST run at a time"; F4 (a request during a cycle is dropped and never answered) |
| T64 | R16 | LifecycleWorld | Given a card showing, clicked, its probe running. When *Update now*. Then the button and the card read `.updating`, `deadline.armed == nil`, and no `update()` is made yet. When the probe ends *Found*. Then one `update()`, and no alert ever answers the click. | The design's `want` (a download asked for during a read waits for it and drops the click's wait); Tradeoffs accepted (*Update now* during *Checking…* supersedes the click, with no alert); F4 |
| T65 | R19 | LifecycleWorld, values | Given *Update* clicked, with the window open. For each ending, run separately: (a) the cycle ends `.failed` with no `.held`, a failed download or an update that is not genuine; (b) it ends `.requestFailed`; (c) `.held` with `armWorks = false`, then `.failed`. Then `alert == .installFailed(running: "1.1.22")`, the button `.idle`, the process has not ended, and a tap of 1 brings Arc forward. | R19 scenarios "Download fails" and "Update not genuine"; `UpdateCardTests.aRefusedRestartKeepsTheProcessWorkingAndReturnsTheCard` |
| T66 | R19 | LifecycleWorld | Given *Update* clicked, then the window closed. When the cycle ends `.failed`. Then no Published state from then on has an alert, and the window's next opening shows the button `.idle` and no alert. | R19 scenario "Download fails with the window closed" |
| T67 | R14, R19 | LifecycleWorld | Given T57's login download after *Update*. When it ends `.failed` with the window open. Then `.installFailed(running: "1.1.22")`. | Design decision 5 (the adopted login download "reports a failure (R19)") |
| T68 | R20 | LifecycleWorld, SparkleEngine | (a) Given *Update* clicked with no card showing. When the cycle ends `.cancelled`. Then no alert, the button `.idle`, and the process runs. (b) The same with the card showing when *Update* was clicked: the card returns to `.available`. (c) `outcome(of:)` maps an update cycle ending with `SUInstallationCanceledError` (4007) to `.cancelled`, and a probe ending with it to `.failed`. | R20 and its scenario; domain-model *Update card* (a cancelled prompt returns the card); Sparkle's `SUErrors.h` (4007) |
| T69 | R8 | LifecycleWorld | (a) Given *Update* clicked. When the switch turns off, then `.held`. Then `arms == [true]`. (b) Given *Update* clicked while the card showed, then the switch off. When the cycle ends `.failed`. Then `.installFailed` shows and no card. | R8 "A download already running, whether from ... the alert's Update ... MUST carry on"; R8 "the card does not return while the switch is off" |
| T70 | R14 | LifecycleWorld | Given *Update* clicked. When the re-read finds nothing (`.nothingNew`). Then `.upToDate("1.1.22")` and the button `.idle`. | The design's `installEnded` (a release withdrawn meanwhile reads as up to date) |

### Verified without a test

- **R1, the row's place.** No test hosts the settings form, as with every sibling row (plan 050).
  - A read of `SettingsView`: the thumb corner `Section` holds, in order, `ThumbCornerRows`, the *Hide background apps* toggle and `UpdatesRow`, and nothing after them. The no trackpad notice and the *Quit Trackpad App* / *Close* row follow the `Form`. `UpdatesRow` reads only `updater`, with no capability check.
  - **M1**, by hand: `make run`. The thumb corner group shows *Thumb corner*, *Hide background apps*, then the *Automatic updates* row, and the *Quit Trackpad App* and *Close* buttons lie fully inside the window below it. On a MacBook that has had an external trackpad, the group reads *MacBook trackpad*, *External trackpad*, *Hide background apps*, then the row. For the no trackpad notice, the read above is the check unless a Mac without a trackpad is at hand.
- **R2, the row's design.**
  - **M2**: a 2x screenshot of the row in the Debug build, measured against `design/auto-updates.json`:
    - the row is 98 pt: the form's 10 plus 6, the 16 pt title line, 4, the 14 pt version line, 8, the 24 pt button, then 6 plus the form's 10;
    - the version text is 11 pt;
    - the button is 162 x 24 with radius 6, at the leading edge;
    - the switch is at the trailing edge.
  - A read of `UpdatesRow`: the version line's style is `.secondary`.
  - **M2b**, the dark appearance, as the design's tradeoff gives it: with the Mac in dark appearance, remove the settings window's `.aqua` pin locally and `make run`. The version line shows in the window's secondary text colour, readable against the dark group. Restore the pin; `git diff` of `SettingsWindow.swift` shows nothing.
- **R3.** **M3**: `make run`. The row reads "Current version: " followed by `MARKETING_VERSION` from `Config/Version.xcconfig`, with no build number.
- **R6.** The quick gate is green, and the 039 suites (`UpdaterStartTests`, `UpdateCardTests`, `UpdateRetryTests`, `HandOverTests`) change only mechanically:
  - `.found` becomes `.found("1.1.23")`;
  - `updater?` becomes `updater`, and `updater != nil` becomes `ports != nil`;
  - `UpdateCard.buttonTitle` is compared as a `ButtonTitle`.
  `git diff --merge-base main` of those four files shows nothing else.
- **R6, R7 and R10 on a real network.** **M4**: a Developer ID release built from this branch, in /Applications, watched with `nettop -p <pid>` or Little Snitch.
  - With the switch off, start it with `--at-login`, turn Wi-Fi off and on twice, then open the window by hand and close and reopen it three times: Trackpad App opens no connection.
  - *Check for updates…* makes exactly one connection to `raw.githubusercontent.com`.
  - With the switch on, closing and opening the window makes one connection.
- **R11 live.** **M5**: on that release, with Network Link Conditioner's 100% Loss profile on, click *Check for updates…*. The button reads *Checking…* with stepping dots for about 30 s, then "Couldn't check for updates" shows. *OK* returns the button to *Check for updates…*. Only a release can show this: the Debug preview's *Checking…* never ends.
- **R12, R17, R18 and R22, the alerts' look.** **M6**, on Debug builds:
  - `make run`, then *Check for updates…*: a free-standing alert with the app's icon, the bold title, the body and *OK*. Return and Escape both close it.
  - Launched with `-PreviewUpdates alert`: at the first opening, the update alert reads "Restart Trackpad App to update?" over its two paragraphs, "Update Trackpad App from <version> to 9.9.9." and the quit line, with *Not now* and a blue default *Update*. Escape answers *Not now*.
- **R14, R19 and R20 against a real update.** **M7**, needing a published newer version:
  - *Update* installs and reopens the new version with its settings window.
  - A copy the user cannot write (owned by root) asks for an administrator after the download. Cancelling the prompt shows no alert and returns the button. This also settles the design's 4007 risk.
  - Wi-Fi off during the download shows "Couldn't install the update", and 1.1.22 keeps running.
- **R23, R24 and R25 by eye and ear.** **M8**, on a Debug build launched with `-PreviewUpdates checking`, then with `-PreviewUpdates updating` (the row's button and the card):
  - The dots step none, one, two, three as in the xreader reference, and the word stays still. They match the disabled button's own title in font and colour, in the row and on the card.
  - Reduce motion on, live, stills them as "…".
  - VoiceOver reads "Checking…" and announces nothing as the dots change.
  - *Check for updates…*, *Open Settings…* and *Other…* stay still.
  - A grep: `ProgressDots` appears only in `ButtonTitleView`, and `ButtonTitleView` only in `UpdatesRow` and `UpdateCardView`.
- **R26 with a real alert.**
  - **M9**, in the Debug build with the "Updates aren't available for this copy" alert up:
    - the 2-finger gesture brings its app forward, and the swipe, the window swipe and the swap work;
    - clicking the *Automatic updates* switch changes nothing until *OK*;
    - with *Hide background apps* on, a gesture to another app hides Trackpad App with its alert, and opening Trackpad App again shows the window with the alert still waiting.
  - **M10**, the design's logout risk (C4). A `make run` build, not under the debugger, launched with `-PreviewUpdates alert`, with the two-button update alert up. Log out: the logout completes, and no "Trackpad App cancelled logout" appears. Then, with the alert up again, the Dock's *Quit* does nothing until the alert is answered, as `docs/domain-model.md` *Quit Trackpad App* now says. M10 proves the shipped path because the preview's alert runs through the presenter's own session code: the run-loop callout, `showing`, and the power-off observer.
- **R8, the window refits.** **M11**, on a Debug build launched with `-PreviewUpdates available`, the card showing *Update available*. Turning the switch off removes the card and the window shrinks to fit. R9's "card stays gone after off and on" is T31's alone: the preview card follows the switch, not the model.

## Slices

Five slices. S1 is the prefactor the design's next step names: it reshapes the model and the engine port with no visible change, and the 039 suites prove it. S2, the progress dots, depends on nothing else and can run beside S1. Then S3 (the switch), S4 (*Check for updates…* and its alerts) and S5 (the alert's *Update* beside other downloads, and how it ends) each add one user-visible capability, in order.

### S1: One Updater in every copy, its ports made only by the gate

**What to build:** nothing a user sees changes. The pieces:
- `Updater` exists in every copy, built from the running version and `UpdatePorts?`. The gate's absent object becomes the ports: the engine and the path monitor. A portless `Updater` rests for ever.
- Versions cross the engine port as `AppVersion`, through `.found(AppVersion)`.
- The engine asks `shouldDownload` inside `showUpdateFound`, replying *dismiss* for no and *skip* to a crash's installer without asking.
- The model's state takes the design's shape, with the switch always on and no manual check:
  - the phase, with `checking`, `checkingAtLogin`, `updatingAtLogin` from the offer on, and `installing(.fromCard)`;
  - the window stake, and `queued`;
  - `begin`, `settle`, `enter`, `listAnswered`, `want`, `offered`, `installEnded` and `handOver`.
- `Lifecycle.updater`, `SettingsShell` and `SettingsView` take a non-optional `Updater`. The composition root builds `UpdatePorts` behind the gate and reads `ThisCopy.version()`, which is `version(of: .main)`.
- The harness mirrors this, with the design's test-seam handles that S1's rows use:
  - `OneProcess.ports` and `RunningBuild.version`;
  - the engine's `offer(_:)` (with its precondition), `offers` and `unconsented`, and its offer before `.held`;
  - the `Published` record after every fake delivery;
  - a loopback feed server for the cycle tests.
- The doc comments that say an updater exists only for a Developer ID copy are corrected in `SettingsView` and `Lifecycle`, and in `UpdateCardPreview` unless S2 has already replaced it. The `Ports.swift` port doc says a version crosses as `AppVersion`.

**Blocked by:** None (can start immediately).

**Requirements:** R6 (today's behaviour over the new shape); R3 (reading the running version); R22 (in part: a copy the gate turns away holds an `Updater` and makes no request); R8, R12, R13 and R14 (in part: the found version crossing the port, a declined offer downloading nothing, and the engine never skipping).

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`, `dev-workflow:tdd`

- [ ] T1 to T7 are green, each written before the code that turns it green.
- [ ] The quick gate is green. Every suite on `LifecycleWorld` can break: `UpdaterStartTests`, `UpdateCardTests`, `UpdateRetryTests`, `HandOverTests`, `LifecycleTests`, `MoveToApplicationsTests`, `ReplacingOtherCopiesTests`, `StartAtLoginTests` and `MixedTrackpadsTests`. So can `SparkleEngineTests` and `SparkleEngineCycleTests`. Their bodies change only as the R6 check under Verified without a test allows.
- [ ] The docs Phase D already rewrote match what S1 built: the parts of `docs/architecture.md` line 11 that say `Updater` exists in every resident copy and its ports only in a copy the gate lets through. Where the build departs from that text, the text is corrected.

### S2: Progress labels step their dots

**What to build:** the update card's *Updating…* shows a still "Updating", then three dots that step none, one, two, three, 250 ms each, as one animation the render server plays. With Reduce motion on, the dots stand still. VoiceOver reads "Updating…". The pieces:
- `Progress` and `ButtonTitle`, with `UpdateCard.buttonTitle` as a `ButtonTitle`;
- `ButtonTitleView` and `ProgressDots` / `ProgressDotsView`, used by the card's button;
- the source scan's ban on SwiftUI repeating animations;
- `UpdatesPreview`, which replaces `UpdateCardPreview` and reads `-PreviewUpdates`, with its card states: `available`, as `-PreviewUpdateCard YES` showed it, and `updating`'s card.

The row's button adopts the same view in S4. S3 makes `available` follow the switch, and S4 adds the row's states and `alert`.

**Blocked by:** None (can start immediately).

**Requirements:** R23 and R24 (the card's *Updating…*); R25 (the card's *Update now*, and that only a `.progress` title can animate).

**Test scenarios:** T8, T9, T10, T11, T12, T13, T14, T15, T16.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:axiom-swiftui`, `dev-workflow:tdd`

- [ ] T8 to T16 are green, each written before the code that turns it green.
- [ ] The quick gate is green. The existing tests this can break are `UpdateCardTests.theCardsTextAndButtonFollowItsState` (the title becomes typed), `UpdatePictureTests` (the card view changes around the picture) and `SourcePolicyTests`.
- [ ] R25's grep under Verified without a test passes.
- [ ] M8 passes on the card with `-PreviewUpdates updating`.
- [ ] A read of `UpdatesPreview`: it reads `-PreviewUpdates` only inside `#if DEBUG`, and otherwise returns the model's values unchanged. `grep -rn "PreviewUpdateCard" LauncherKit TrackpadApp docs` finds nothing.
- [ ] The docs Phase D already rewrote match what S2 built: `docs/architecture.md` line 21 (the progress dots among the animations that never complete, following the arrow's rules) and line 22 (`-PreviewUpdates`), and `docs/domain-model.md`'s *Progress label*. Where the build departs from them, they are corrected.

### S3: The Automatic updates switch

**What to build:** the thumb corner group ends with a row that reads *Automatic updates*, with its switch, then "Current version: <version>".
- The switch is on by default. It is saved at once under its own key beside the settings record, so it survives a quit, a force quit, a restart and an older version's save.
- While it is off, the app makes no automatic request: no login check, login update, retry, window check or card.
- Turning it off:
  - drops a window check's answer and removes an *Update available* card;
  - ends a login wait, and declines a running login read's offer;
  - lets running downloads carry on, and a failed *Update now* leaves no card.
- Turning it on starts nothing.

The pieces:
- `isAutomaticUpdatesOn` and `setAutomaticUpdates(on:)`;
- `SettingsStore`'s `loadAutomaticUpdates` and `saveAutomaticUpdates`, read through `Updater.init`'s store;
- the `abandonedAtLogin` phase and the switch-off transition;
- the open edge's switch gate, and `installEnded`'s switch condition;
- `UpdatesRow` with its first two lines;
- `UpdatesPreview.card(_:isAutomaticUpdatesOn:)`, so the Debug preview's card shows only while the switch is on;
- `LifecycleWorld(automaticUpdates:)`, `setAutomaticUpdates(on:)` and `Published.isAutomaticUpdatesOn` in the harness.

**Blocked by:** S1.

**Requirements:** R1 and R2 (the row's place, its first two lines); R3; R4; R5 (all but the survival of an update from the alert); R6; R7 (no automatic request); R8 (all but a manual check and the alert's download); R9.

**Test scenarios:** T17, T18, T19, T20, T21, T22, T23, T24, T25, T26, T27, T28, T29, T30, T31, T32, T33.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-data`, `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:swift-concurrency`, `dev-workflow:tdd`

- [ ] T17 to T33 are green, each written before the code that turns it green.
- [ ] The quick gate is green. The existing tests this can break:
  - `PersistenceTests.everySettingsFieldSurvivesTheStore`, which must stay unchanged because the record gains no field;
  - `MixedTrackpadsTests`, whose suite-key assertions must still find only `externalThumbCorner` while the switch is on;
  - the 039 suites.
- [ ] R1's read and M1 pass for the row's first two lines. M2b, M3 and M11 pass on a Debug build.
- [ ] The docs Phase D already rewrote match what S3 built. Where the build departs from them, they are corrected:
  - `docs/domain-model.md`'s *Automatic updates setting*, and the switch's part of *Update check*, *Login update*, *Update card* and *Settings window*;
  - `docs/architecture.md` line 27's network promise;
  - `docs/product-overview.md`'s privacy statement.

### S4: Check for updates… and its answers

**What to build:** the row gains a bordered *Check for updates…* button, and the row becomes the 98 pt the JSON gives.
- A click reads the update list once whatever the switch says, or takes a read already running. The button meanwhile reads *Checking…* with stepping dots.
- The answer comes in a free-standing app-modal alert:
  - the update is ready to install, with *Update* and *Not now*;
  - the app is up to date;
  - the check failed, which also follows 30 s with no answer;
  - in a copy that cannot update, updates aren't available.
- *Not now* remembers nothing. *Update* downloads and installs as *Update now* does, and hands over with the window.
- Closing the window drops a running check silently.
- Alerts start in a run-loop callout so gestures keep working, end on power-off, and leave with the window.

The pieces:
- `CheckButton`, `UpdateAlert`, `AlertButton` and `AlertAnswer`;
- `checkForUpdates()`, `answer(_:to:)`, `alert`, `checkButton`, `manualWaits` and `Install.fromAlert(overCard:)`;
- the `CheckDeadline` port in `UpdatePorts`, `LayerCheckDeadline` and `InMemoryCheckDeadline`;
- `UpdateAlertPresenter`, owned by `SettingsShell`;
- the row's button through `ButtonTitleView`, and the `Copy` strings;
- the source scan's modal rules;
- `UpdatesPreview.checkButton(_:)` for `checking` and the row's part of `updating`, and `UpdatesPreview.alert(running:)` for `alert`, shown through the presenter's own session code;
- the harness's `deadline` (with `pass()`'s precondition), `checkForUpdates()`, `answer(_:)` and `answersInside`.

**Blocked by:** S2, S3.

**Requirements:** R1, R2 and R3 (the whole row, its strings pinned); R5 (an off survives an update from the alert); R6 (an opening while a dropped check runs still checks); R7 (the click's exceptions); R8 (a manual check carries on); R10; R11; R12; R13; R14 (the alert's *Update* through to the hand-over); R15 (the button's values); R17; R18; R19 (in part: the alert's text); R21 (the check); R22; R23 and R25 (the row's button); R26.

**Test scenarios:** T34, T35, T36, T37, T38, T39, T40, T41, T42, T43, T44, T45, T46, T47, T48, T49, T50, T51, T52, T53, T54, T55, T56.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:axiom-swiftui`, `dev-workflow:tdd`

- [ ] T34 to T56 are green, each written before the code that turns it green. `UpdateAlertBench` shows its alerts on screen for a moment, as the design accepts.
- [ ] The quick gate is green. The existing tests this can break are `SourcePolicyTests` (the `runModal` rule's text and files), the 039 suites, and the `LauncherUITests` benches around the shell.
- [ ] M1 and M2 pass for the whole row. M6, M8 on the row's button, M9 and M10 pass on a Debug build. M4 and M5 pass on a Developer ID release, or are recorded as pending for one.
- [ ] The docs Phase D already rewrote match what S4 built. Where the build departs from them, they are corrected:
  - `docs/domain-model.md`'s *Manual check*, *Update alert* (its check answers), the button in *Settings window*, and *Quit Trackpad App* (the Dock's *Quit* under the update alert, and a logout ending its session);
  - `docs/architecture.md` line 11 (a modal runs only from a run-loop callout) and line 20 (the manual check's 30 s).

### S5: The alert's Update beside other downloads, and how it ends

**What to build:** the alert's *Update* never starts a second download.
- It takes over a running login download, which then hands over with the window.
- It waits behind a read still running.
- The row's button reads *Updating…*, and the card does too only if it showed when the download was asked for. Opening the window during any download checks nothing.
- When the download ends without installing and the window is open:
  - "Couldn't install the update" shows for a failed download, an update that is not genuine, or a refused restart;
  - "Trackpad App is up to date" shows when the re-read found nothing;
  - nothing shows for a cancelled administrator prompt.
- With the window closed, nothing shows, then or later.
- A hand-over withdraws an alert still up.

The pieces:
- `want`'s takeover of `updatingAtLogin` and its queue, for `.fromAlert`;
- `installEnded`'s alerts;
- `CycleOutcome.cancelled` in `SparkleEngine.outcome(of:)`.

**Blocked by:** S4.

**Requirements:** R8 (the alert's download carries on); R10 and R12 (a click during a login read); R14; R15; R16; R19; R20; R21 (the download); R26 (a hand-over withdraws the alert).

**Test scenarios:** T57, T58, T59, T60, T61, T62, T63, T64, T65, T66, T67, T68, T69, T70.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`, `dev-workflow:tdd`

- [ ] T57 to T70 are green, each written before the code that turns it green.
- [ ] The quick gate is green. The existing tests this can break are `UpdateCardTests` (a cancelled prompt still returns the card) and `SparkleEngineTests` (the outcome table).
- [ ] M7 passes once a newer version is published, or is recorded as pending until then.
- [ ] The docs Phase D already rewrote match what S5 built: `docs/domain-model.md`'s *Update alert* (the endings of its *Update*), *Update card* and *Hand-over* (the alert's *Update* opens the new version with its window, and takes over a running login download). Where the build departs from them, they are corrected.

---

# Addendum: Move dialog fix (technical change, requested during 052)

## Problem statement

The update alerts start their modal session from a run-loop callout so the main queue keeps running. The move dialog predates that rule: `MoveDialogPresenter` runs `NSAlert.runModal()` inside its `Observations` task, a main-actor job. Reproduced end-to-end on 2026-11-14 with a Developer ID release build in `/tmp`, started with `--at-login` and then opened by hand (`Lifecycle.openedAgain` → `.askingToMove(resident:)`):

- `sample` of the process showed `-[NSAlert runModal]` under `completeTaskWithClosure` on the main thread: the session holds a main-actor job, so every other main-queue job, recognised gestures included, waits until the dialog is answered (grounding F26). That breaks the domain model's promise that a resident copy keeps its gestures.
- A quit Apple event that reached the copy while the dialog showed ended the dialog as its first button, *Move to Applications*: the move ran, the opened copy in `/tmp` was removed, and the installed copy opened. A logout, restart, shutdown, the Dock's *Quit*, or another copy stopping this one can therefore install the copy instead of ending it.

## Requirements

### R27. The move dialog does not stop a resident copy's gestures
While the move dialog shows over a resident copy (a login-started copy outside /Applications opened by hand), main-queue work, recognised gestures included, MUST keep running.

#### Scenario: Gestures during the move dialog
- **GIVEN** a release copy outside /Applications started at login and recognising gestures
- **WHEN** the user opens it by hand and the move dialog shows
- **THEN** a main-queue job queued from another thread runs while the dialog is still up, and gestures keep working

### R28. A quit request while the move dialog shows never moves
While the move dialog shows, no quit request MUST ever end it as *Move to Applications*. A logout, restart or shutdown MUST end the copy with nothing moved, so the dialog never cancels a logout. Any other quit Apple event (a script, the Dock's *Quit*) waits until the dialog is answered, as it does for the update alerts.

#### Scenario: Quit Apple event during the dialog (the reproduction)
- **GIVEN** the move dialog shows over a login-started copy in `/tmp`
- **WHEN** a quit Apple event reaches the copy
- **THEN** the event is refused, the dialog stays, /Applications is unchanged, and the opened copy stays where it was

#### Scenario: Logout during the dialog
- **GIVEN** the move dialog shows
- **WHEN** the user logs out
- **THEN** the logout proceeds and nothing is moved

### Verification (2026-11-14, Developer ID build of 294c5a8 run from `/tmp`)
- R27: `sample` shows `-[NSAlert runModal]` under `__CFRunLoopDoBlocks` (a run-loop callout), no longer under a Swift task job.
- R28: a quit Apple event by pid and `osascript … to quit` each got -128; the copy kept running with the dialog up, the `/tmp` bundle stayed, and /Applications was byte-identical to its backup. Before the fix the same `osascript` quit ran the move.
- Not verified: a real logout with the dialog up (hand check, as M10 is for the update alert).

## Non-goals

- Changing the dialog's text, buttons or default. *Move to Applications* stays the default button for a real click and Return.
