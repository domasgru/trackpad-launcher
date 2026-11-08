# Plan: Window stacks, a stable window order and the "no other windows" card

## Problem statement

The app switcher shows one icon per app. It does not tell which apps have several windows. The user learns that only by bringing the app to the front and trying a window swipe.

The window switcher reorders its rows on every use. Lifting on a window brings it to the front, and the next window swipe lists the window in front first. So the row a window sits on keeps changing. A user who picked the last row finds that window on the first row next time, and every other window shifted down by one. They cannot build muscle memory for "my second window is one row down".

A slide up or down in an app with fewer than two windows does nothing visible. It is no window swipe, so the user cannot tell whether the gesture failed or the app has nothing to switch to.

## Solution

**Window stacks in the app switcher.** An app with two or more windows shows a stack in the app switcher: smaller copies of its icon peek out above it, one copy per extra window, up to four icons in all. Windows are counted as the window switcher would list them. The row appears at once. Each stack rises out from behind its icon, with a short, soft animation, as soon as its count is known. Stacks show even with the window swipe setting off: knowing which apps have several windows is useful on its own.

**A stable window order.** Each app keeps one window order for as long as it runs and Trackpad Launcher runs. The window switcher always lists the windows in that order. The selection starts on the row of the window in front. Lifting on the last row and swiping again shows the same list, with the last row selected.

**The "no other windows" card.** With the window swipe setting on, a slide up or down in an app with zero or one window now shows the window switcher with a single card. The card names the app and says it has no other windows. It follows the fingers up or down a few points and no further, then settles back. Lifting changes nothing and is silent.

Terms, for the glossary. New: *window stack* (the icons behind an app's icon in the switcher) and *no-windows card* (the window switcher's single card). Changed: *window swipe* (it now exists with zero or one window too), *window switcher* (stable order, selection start, the card), *switcher* (stacks), *front window* (no longer always the first row).

### Documentation

`docs/product-overview.md`: the window swipe sentence loses "when the frontmost app has two or more windows". It gains that an app with fewer windows shows a card saying so. The swipe sentence gains that apps with several windows show a stack of icons. The silent-lift exception gains the lift on the no-windows card. The window swipe ordering clause, "the window in front first, then its other windows, then its minimised ones", becomes: its windows in the app's window order, set by the first window swipe into the app and kept until the app quits, with the selection starting on the window in front. `docs/domain-model.md` follows the terms above.

## Requirements

### R1. Apps with several windows show a window stack
In the switcher, each app with two or more windows MUST show a window stack: its icon at the usual place, with copies of the icon behind it. The number of icons MUST equal the app's window count, capped at 4. So 2 windows show 2 icons, 3 show 3, and 4 or more show 4. An app with zero or one window MUST show its icon alone, as today. The frontmost app at the left end shows its stack too.

#### Scenario: Three windows
- **GIVEN** Safari is running with three windows and has no gesture assigned
- **WHEN** the user swipes
- **THEN** Safari's slot shows three icons: its icon and two copies behind it

#### Scenario: Many windows hit the cap
- **GIVEN** Chrome has seven windows
- **WHEN** the user swipes
- **THEN** Chrome's slot shows four icons

#### Scenario: One window
- **GIVEN** Notes has one window
- **WHEN** the user swipes
- **THEN** Notes shows its icon alone

#### Scenario: Frontmost app
- **GIVEN** the frontmost app, Xcode, has two windows
- **WHEN** the user swipes
- **THEN** the first slot shows Xcode with a stack of two icons

### R2. A stack counts windows exactly as the window switcher lists them
An app's window count MUST be the number of windows the window switcher would list for it. That is its windows on the current Space, minimised ones included, and never its windows on other Spaces. The frontmost app, when its front window is in full screen, MUST count as one window. Panels, palettes, sheets and other helpers MUST not count.

#### Scenario: Minimised windows count
- **GIVEN** Safari has one visible window and one minimised window
- **WHEN** the user swipes
- **THEN** Safari shows a stack of two icons

#### Scenario: Windows on another Space do not count
- **GIVEN** Safari has one window on the current Space and two on another Space
- **WHEN** the user swipes
- **THEN** Safari shows its icon alone

#### Scenario: Full screen
- **GIVEN** Keynote's front window is in full screen and it has two other windows
- **WHEN** the user swipes
- **THEN** Keynote shows its icon alone

#### Scenario: Panels do not count
- **GIVEN** Finder has one window and a Get Info panel open
- **WHEN** the user swipes
- **THEN** Finder shows its icon alone

### R3. Stacks show whether the window swipe setting is on or off
Stacks MUST show whether the window swipe setting is on or off. Without the Accessibility permission, every app MUST show its icon alone, since windows cannot be read.

#### Scenario: Window swipe setting off
- **GIVEN** *Switch windows* is off and Safari has two windows
- **WHEN** the user swipes
- **THEN** Safari shows a stack of two icons

#### Scenario: No Accessibility permission
- **GIVEN** Trackpad Launcher lacks the Accessibility permission and Safari has two windows
- **WHEN** the user swipes
- **THEN** Safari shows its icon alone

### R4. The switcher never waits for window counts
The switcher MUST NOT wait for any window count. An app whose count is not known yet MUST show its icon alone. Its stack MUST appear as soon as the count is known. Each count MUST be read once, when the swipe begins, and MUST hold for the rest of the swipe: a window that opens or closes during the swipe does not change any stack. An app that has not reported its windows within 0.2 s does not answer. It MUST show its icon alone for the whole swipe, and MUST NOT delay the other apps' stacks. A stack MUST appear for every app that answers within 0.2 s.

#### Scenario: A slow app
- **GIVEN** Safari has two windows, and Mail has two windows and takes 150 ms to report them
- **WHEN** the user swipes
- **THEN** the switcher appears at once, Safari's stack appears at once, and Mail's stack appears when Mail answers, 150 ms later

#### Scenario: An app that does not answer
- **GIVEN** Safari and Notes have two windows each, and Mail has two windows and never reports them
- **WHEN** the user swipes
- **THEN** Safari and Notes show their stacks, and Mail shows its icon alone for the whole swipe

#### Scenario: A window opens mid-swipe
- **GIVEN** Notes has one window
- **WHEN** the user swipes and, during the swipe, Notes opens a second window
- **THEN** Notes shows its icon alone until the fingers lift

#### Scenario: A window closes mid-swipe
- **GIVEN** Safari has two windows
- **WHEN** the user swipes and, during the swipe, Safari's second window closes
- **THEN** Safari shows its stack of two icons until the fingers lift

### R5. A stack's shape
The front icon of a stack MUST sit and size exactly as a lone icon does, so the row's spacing, the highlight and the panel size do not change. Each copy behind it MUST be smaller than the one in front of it (about 92%, 84% and 76% of the icon) and MUST peek out above it by about 6 pt per layer. When the app is selected and its icon grows, the whole stack MUST grow with it by the same factor. When the row shrinks to fit the display, the stack MUST shrink by the same factor.

#### Scenario: Stack inside the row
- **GIVEN** a row of five apps, one of them with four windows
- **WHEN** the user swipes
- **THEN** the panel has the same size and the icons the same spacing as a row of five lone icons

#### Scenario: Selected stack
- **WHEN** the selection lands on an app with a stack
- **THEN** its icon and every copy behind it grow together

#### Scenario: Narrow display
- **GIVEN** the row shrinks to fit a narrow display
- **WHEN** the user swipes
- **THEN** every stack shrinks by the same factor as the icons

### R6. A stack rises into place
When a stack appears, its copies MUST start exactly behind the front icon, at the same height, and rise to their places. The rise MUST take about 0.3 s with a soft ease-out, each copy starting about 40 ms after the one in front of it. A stack MUST rise once per swipe, never again while the selection moves. With macOS's *Reduce motion* setting on, the copies MUST appear in place without moving.

#### Scenario: Rise on showing
- **GIVEN** Safari has three windows
- **WHEN** the switcher appears
- **THEN** Safari's two copies rise out from behind its icon, the nearer one first, and come to rest within about half a second

#### Scenario: Moving the selection replays nothing
- **WHEN** the user slides the selection on and off Safari
- **THEN** Safari's stack stays where it is

#### Scenario: Reduce motion
- **GIVEN** *Reduce motion* is on
- **WHEN** the switcher appears
- **THEN** every stack shows in place at once

### R7. Each app keeps one window order
The window switcher MUST list an app's windows in that app's window order. The first window swipe into an app MUST set its order as today's list: the window in front, then the other visible windows front to back, then the minimised windows in the order the app lists them. Every later window swipe into that app MUST keep the order. Only these MUST change it: a window opening joins the order at its end, a window closing leaves it, and the app quitting or Trackpad Launcher stopping forgets it. Nothing else changes it. Lifting, clicking, ⌘`, the Window menu, Mission Control, the Dock, minimising, restoring and hiding the app MUST NOT change it. A minimised window keeps its place in the order, and shows dimmed and badged as today. A window that is not on the current Space MUST NOT be listed, but MUST keep its place in the order. When it is back on the current Space, it MUST be listed in that place again. The order MUST NOT be saved.

#### Scenario: The order survives a lift on the last row
- **GIVEN** Safari's window switcher lists A, B, C, with A in front
- **WHEN** the user window-swipes to C, lifts, and window-swipes again
- **THEN** the list reads A, B, C

#### Scenario: A clicked window keeps its place
- **GIVEN** Safari's order is A, B, C
- **WHEN** the user clicks window B and then window-swipes
- **THEN** the list reads A, B, C

#### Scenario: A new window joins at the end
- **GIVEN** Safari's order is A, B, C, with C in front
- **WHEN** the user opens window D, which comes to the front, and window-swipes
- **THEN** the list reads A, B, C, D

#### Scenario: A closed window leaves
- **GIVEN** Safari's order is A, B, C
- **WHEN** the user closes B and window-swipes
- **THEN** the list reads A, C

#### Scenario: A minimised window keeps its place
- **GIVEN** Safari's order is A, B, C
- **WHEN** the user minimises B and window-swipes
- **THEN** the list reads A, B, C, with B dimmed and badged "Minimised"

#### Scenario: A window on another Space keeps its place
- **GIVEN** Safari's order is A, B, C
- **WHEN** the user moves B to another Space and window-swipes
- **THEN** the list reads A, C
- **WHEN** the user moves B back to the current Space and window-swipes
- **THEN** the list reads A, B, C

#### Scenario: Lifting on a middle row
- **GIVEN** Safari's order is A, B, C, with A in front
- **WHEN** the user window-swipes to B, lifts, and window-swipes again
- **THEN** the list reads A, B, C and the selection starts on B, the second row

#### Scenario: The app relaunches
- **GIVEN** Safari's order is A, B, C, with C in front
- **WHEN** the user quits Safari, reopens it with windows A, B and C, C in front, and window-swipes
- **THEN** the list reads C, then the other windows front to back

#### Scenario: Trackpad Launcher restarts
- **GIVEN** Safari's order is A, B, C, with C in front
- **WHEN** Trackpad Launcher is quit and opened again, and the user window-swipes
- **THEN** the list reads C, then the other windows front to back

### R8. The selection starts on the window in front
The selection MUST start on the row of the window in front when the window swipe begins. When every window is minimised, it MUST start on the first row. Lifting MUST keep today's rules: the selected window stays in front, restored if minimised, with the window that was in front just behind it; the gesture haptic plays only when the window in front changed or a minimised window was restored.

#### Scenario: Start on the last row
- **GIVEN** Safari's order is A, B, C, with C in front
- **WHEN** the user window-swipes
- **THEN** the selection starts on C, the third row

#### Scenario: Slide up from the last row
- **GIVEN** the selection starts on C, the third row
- **WHEN** the user slides up by one row and lifts
- **THEN** B comes to the front with the gesture haptic

#### Scenario: Lift where it started
- **GIVEN** the selection starts on C
- **WHEN** the user slides down past the end and lifts
- **THEN** nothing changes and the lift is silent

#### Scenario: Every window minimised
- **GIVEN** Safari's order is A, B, both minimised
- **WHEN** the user window-swipes
- **THEN** the selection starts on A

#### Scenario: Lifting on a minimised window
- **GIVEN** Safari's order is A, B, C, with B minimised
- **WHEN** the user window-swipes to B and lifts, which restores B
- **AND** the user window-swipes again
- **THEN** the list reads A, B, C, B is no longer dimmed, and the selection starts on B

### R9. More than ten windows
When an app has more than ten windows, the window switcher MUST pick ten by today's rule: the window in front, the other visible windows front to back, then the minimised windows. It MUST list those ten in the app's window order.

#### Scenario: Twelve windows
- **GIVEN** Safari's order is W1 to W12, W12 in front, and W1 and W2 minimised
- **WHEN** the user window-swipes
- **THEN** the list reads W3 to W12 and the selection starts on W12, the last row

### R10. An app with zero or one window shows the no-windows card
While the window swipe setting is on and Trackpad Launcher has the Accessibility permission, two fingers sliding up or down under an anchored thumb MUST be a window swipe whenever the frontmost app has zero or one window. That includes an app whose front window is in full screen. The window switcher MUST then show a single card in place of the rows. The card MUST show the app's icon on the left, like a row's preview, and two lines of text. The first line MUST be bold and the second line regular weight. With one window, the first line reads "No other windows" and the second "‹App› has no other windows on this desktop." With zero windows, the first line reads "No open windows" and the second "‹App› has no windows on this desktop." ‹App› is the app's name. The slide MUST then follow every other window swipe rule: no scrolling, no clicks, no system trackpad swipes, until the fingers lift.

#### Scenario: One window
- **GIVEN** Notes is frontmost with one window
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** the window switcher shows the card "No other windows / Notes has no other windows on this desktop." and the page does not scroll

#### Scenario: No windows
- **GIVEN** Finder is frontmost with no windows
- **WHEN** the user slides two fingers up under the anchored thumb
- **THEN** the card reads "No open windows / Finder has no windows on this desktop."

#### Scenario: Full screen
- **GIVEN** Keynote is frontmost in full screen with two other windows
- **WHEN** the user slides two fingers down under the anchored thumb
- **THEN** the card reads "No other windows / Keynote has no other windows on this desktop."

#### Scenario: Setting off
- **GIVEN** *Switch windows* is off and Notes is frontmost with one window
- **WHEN** the user slides two fingers down under the anchored thumb
- **THEN** no card shows and the slide scrolls as an ordinary two-finger slide, as today

### R11. The card follows the fingers a little
The card's offset MUST track the fingers' up or down movement since their last change of direction, damped, and clamped at 6 pt above or below its resting place. Sliding further MUST NOT move it further. When the fingers change direction, the card MUST at once move toward the new direction, passing its resting place and going up to 6 pt beyond it. When the fingers lift, it MUST settle back as the switcher goes. The card MUST play no haptic while it moves. With *Reduce motion* on, the card MUST stay still.

#### Scenario: Capped travel
- **GIVEN** the card shows
- **WHEN** the user slides the fingers down by 40 mm
- **THEN** the card has moved down by no more than 6 pt

#### Scenario: Turning back
- **GIVEN** the card has moved down to its cap
- **WHEN** the fingers slide back up
- **THEN** the card moves back up at once, past its resting place and up to 6 pt above it if the fingers keep going

### R12. Lifting on the card changes nothing
Lifting on the card MUST leave every window and app as it was. It MUST be silent, with no haptic. With the hide background apps setting on, it MUST hide nothing. A cancelled window swipe on the card MUST be silent too.

#### Scenario: Lift
- **GIVEN** the card shows for Notes
- **WHEN** the user lifts
- **THEN** the card goes, Notes stays as it was, and nothing plays

### R13. No card without a known window count
When there is no frontmost app, or the frontmost app does not answer (it has not reported its windows within 0.2 s), the slide MUST be no window swipe: nothing shows, and the slide scrolls as an ordinary two-finger slide, as today. Without the Accessibility permission, the same MUST hold.

#### Scenario: App not answering
- **GIVEN** the frontmost app does not report its windows within 0.2 s
- **WHEN** the user slides two fingers down under the anchored thumb
- **THEN** no window switcher shows and the slide scrolls as an ordinary two-finger slide, as today

#### Scenario: No frontmost app
- **GIVEN** there is no frontmost app
- **WHEN** the user slides two fingers down under the anchored thumb
- **THEN** no window switcher shows and the slide scrolls as an ordinary two-finger slide, as today

#### Scenario: No Accessibility permission
- **GIVEN** Trackpad Launcher lacks the Accessibility permission and Notes has one window
- **WHEN** the user slides two fingers down under the anchored thumb
- **THEN** no window switcher shows

## Non-goals

- **A number badge on stacks.** The row shows no text. Above four windows, a stack reads as "many".
- **Saving the window order across restarts.** Window identities do not survive an app relaunch, so a saved order could not be matched reliably.
- **Letting the user reorder windows by hand.** The order is set by first use and the end of the order. There is no drag or setting.
- **Counting windows on other Spaces.** The stack matches what a window swipe into the app would show.
- **Live stacks during a swipe.** Counts are fixed when the swipe begins, like the rest of the row.
- **A card for a slide the setting or the permission rules out.** With *Switch windows* off or without Accessibility, slides behave as today.
- **Stable rows above ten windows.** The ten windows R9 picks depend on which windows were used recently. So with more than ten windows, rows may shift.
- **Window previews on the card.** The card shows the app icon even with Screen Recording granted, since there is nothing to switch to.

## Design

### Problem

The switchers decide everything once, when a slide starts, and keep it for the slide. The three behaviours each cut against a shape that assumes the opposite.

- **Stacks** need the window counts of up to ten apps. The only window reader reads the frontmost app, synchronously on the main actor, and every read replaces its raise handles. Plan 012 rejected an async window read for the window swipe. The 0.2 s messaging timeout bounds one call, not one read: a slow app can take (1 + 2N) × 0.2 s. Timers are banned. Accessibility and the window list are confined to two files. The counts must equal what the window switcher would list (R2), so they cannot be a second copy of its rule. While an app is hidden, its document windows report `AXDialog` and leave the on-screen list, so today's rule would count only its minimised windows. With *Hide background apps* on, most row apps are hidden.
- **A stable order** is the first window state the model keeps between slides (012 recorded "no window state between window swipes" as deliberate). To the Accessibility read, a window on another Space looks exactly like a closed one. No app-quit push reaches the model. "Row 0 is the front window" is built into `WindowList`, `frontWindow` and the lift's restore of the begin z-order.
- **The card** reverses the two-or-more rule, which today also quietly filters out the own process, timeouts and partial reads. The read has to tell those cases apart. The start's verdict must still be given inside the `onEvent` call.

The design keeps these invariants:
- A raise names only ids from the latest frontmost read.
- A declined slide is exactly the setting-off slide.
- The lift is computed from a second read.
- A silent lift has no side effect, so nothing hides.
- The frame thread never waits.
- `LauncherCore` imports Foundation and Observation only.
- Every port keeps two adapters.
- No timers.

Platform facts this design rests on, all probed on this Mac:
- Window numbers rise and are never reused.
- Concurrent off-main reads give the same answers as serial ones.
- One hung app holds only its own thread.
- A per-element messaging timeout set on any thread caps that call.
- One `optionAll` copy does not give the on-screen order.
- "Which of these window numbers still exist" costs 0.19 ms.

### Usage (caller's view)

```swift
// README: window reads, from the model (LauncherCore)
//
// A slide up or down: one synchronous read, held to 0.2 s in all, decides it and brings the app's window order up to date.
//   let read = system.frontmostWindows(within: GestureRules.windowReadDeadline)
//   windowOrders.list(read, stillOpen: system.openWindows(among:))  // nil: no window swipe; else rows in the app's order, or the card
//
// A swipe: the row shows first, then each row app's windows are read away from the main actor, each on its own, each
// answered once within 0.2 s of the call or as `.unanswered`; a count lands only in the switcher it was read for.
//   system.readWindows(of: switcher.row, within: GestureRules.windowReadDeadline) { slot, read in ... }
//
// Both count through `WindowRead.windowCount`, so a stack and the window switcher never disagree (R2).
```

Call site 1, `Launcher.swipe`:

```swift
case .began:
    guard shown == nil, activity.isActive else { return }
    let running = system.runningApps()
    guard let switcher = Switcher(
        frontmost: running.frontmost, running: running.apps, leavingOut: settings.assignedBundleIDs,
        serial: switchersBegun + 1, trackpad: event.trackpad) else { return }
    switchersBegun += 1
    shown = .apps(switcher)                                  // R4: the row is up before any read starts
    guard isAccessibilityGranted else { return }             // R3: no window can be read; the setting plays no part
    let serial = switcher.serial
    system.readWindows(of: switcher.row, within: GestureRules.windowReadDeadline) { [unowned self] slot, read in
        counted(read, at: slot, swipe: serial)
    }

/// A count lands only in the switcher it was read for, once per slot: an ended, cancelled, reconciled or later
/// swipe's switcher drops it.
private func counted(_ read: WindowRead, at slot: Int, swipe serial: Int) {
    guard case .apps(var open)? = shown, open.serial == serial, open.take(read, at: slot) else { return }
    shown = .apps(open)
}
```

Call site 2, `Launcher.windowSwipe`:

```swift
case .began:
    guard activity.isActive,
          let content = windowOrders.list(
              system.frontmostWindows(within: GestureRules.windowReadDeadline),
              stillOpen: { system.openWindows(among: $0) })
    else { return }                                          // R13: no app, or no answer within 0.2 s
    hardware.confirmWindowSwipe(on: event.trackpad)
    guard shown == nil else { return }
    switchersBegun += 1
    shown = .windows(WindowSwitcher(content, showsPreviews: isScreenRecordingGranted, serial: switchersBegun,
                                    trackpad: event.trackpad))
case .moved(let travel):                                     // unchanged: the card's one-item selection never ticks or raises
    ...
case .ended:
    guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
    shown = nil
    guard !open.isCard else { return }                       // R12: no read, no raise, no haptic, no hide
    let lift = open.lift(now: system.frontmostWindows(within: GestureRules.windowReadDeadline))
    ...as today
```

Call site 3, the presenters (LauncherUI):

```swift
// SwitcherPresenter.render
if switcher.serial != laidOutSerial { open(switcher) }      // keyed by the swipe, never by the row; shownStacks = all .pending
for (slot, stack) in switcher.stacks.enumerated() where shownStacks[slot] == .pending {
    guard case .stack(let windows) = stack else { continue }
    panel.addStack(at: slot, copies: stackLayout.copies(of: windows), rises: !reduceMotion())   // once per swipe (R6)
}
shownStacks = switcher.stacks
panel.show(position: ..., selected: ..., animatesSize: !reduceMotion())   // the 1.12 grow, now on each slot's container

// WindowSwitcherPresenter.render
switch switcher.content.list {
case .rows: panel.show(position: selection.position, selected: selection.selected)      // + today's spring
case .card: panel.moveCard(by: reduceMotion() ? 0 : switcher.cardOffset ?? 0, animated: !reduceMotion())
}
// render(nil): panel.settleCard(animated: !reduceMotion()); panel.dismiss()
```

Call site 4, a model test at the high seam (R4's slow app):

```swift
let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], accessGranted: true)
world.windows(of: "Safari").set(visible: ["S1", "S2"])
world.windows(of: "Mail").set(visible: ["M1", "M2"], answering: .held)
world.swipe(3.5, lift: false)
#expect(world.launcher.switcher?.stacks == [.stack(WindowStack(windows: 2)!), .pending, .alone])
world.answerCountReads(of: "Mail")                           // "150 ms later": the windows as they were at the begin
#expect(world.launcher.switcher?.stacks[1] == .stack(WindowStack(windows: 2)!))
```

### Shape

**Data first, per model-the-domain.**

- **The read.** `WindowRead` is a sum of three cases: `.windows(AppWindows)`, `.unanswered` and `.ownProcess`. The window swipe's verdict, the lift and the stacks all switch over it exhaustively, per type-system-discipline.
  - These are all `.unanswered`: a partial read, a read past its deadline, missing Accessibility, an app no longer running, and an app that refuses at once.
  - `AppWindows` stays today's pair. `visible` holds the windows on the current Space, front to back. For a hidden app it holds its document windows, in the app's order. `minimised` is in the app's order.
- **The one count rule.** `WindowRead.windowCount` (`Int?`) is built on `WindowPick`, today's cut from `Content.init?` without its two-row guard:
  - the front window first, then the other visible windows front to back, then the minimised ones, ten at most;
  - a full-screen front window is picked alone;
  - other full-screen windows are never picked;
  - `.ownProcess` counts one, for the settings window.

  The stacks take this count, and `WindowOrders.list` uses the same count to choose rows or the card. So R2 holds by construction. The platform's one `sort` serves both reads, so panels and other Spaces drop out before Core sees anything.
- **Stacks.** A `WindowStack` holds 2 to 4 icons by construction: `init?(windows:)` is nil below two, and the count is capped at `maxIcons`. `Switcher` gains `serial` and `stacks: [SlotStack]`, one per slot. Keying by slot keeps two copies of one bundle apart, even at one location.
  - `SlotStack` is `.pending` until its app answers, then `.alone` or `.stack`, and never changes again (R4). This invariant lives in `take(_:at:)`.
  - `WindowStackLayout`, beside `SwitcherRowLayout`, gives each copy's side (92, 84, 76 % of the icon), its centre's rise above the icon's centre (`fullPeek × layer × scale + (iconSide − side) / 2`), its delay (40 ms per layer) and the rise's duration and curve.
- **The order (settles grounding open question 2).** `WindowOrders` holds, per app location, the `AppLaunch` its order belongs to and the order itself. It lives inside `Launcher` and is written only by `list`, at a window swipe's start.
  - `AppLaunch` is an opaque value the frontmost read carries: one launch of the app, made by the adapter from the process id and the kernel's start time for that process (`sysctl`'s `kp_proc.p_starttime`, which every process has, unlike `NSRunningApplication.launchDate`, which apps launched outside LaunchServices lack). A relaunch that reuses a pid still differs. Core can only compare it.
  - An order belonging to another launch, or none, is set as today's list. That covers the first window swipe into an app, a relaunch, and a Trackpad Launcher restart (nothing is saved). So "the app quitting forgets it" holds exactly, with no quit push.
  - A remembered window that the read did not list is asked about through `stillOpen`, a targeted window-server query over just those numbers, made only when one is missing:
    - one still open (another Space, a full-screen Space) keeps its place unlisted;
    - one gone has closed and leaves.
  - Listed windows the order lacks join at its end, in the order they opened, by rising window numbers. This holds even when every remembered window has closed, or the app had none: the zero-window card's slide sets an empty order, and windows opened later join it in turn (R7).
  - The update is idempotent, per make-operations-idempotent.
  - The stacks reads never write an order: only a window swipe sets it.
- **Rows or the card.** `WindowSwitcher.List` is `.rows(Rows)` or `.card(NoWindowsCard)`, so the card cannot reach the lift, the capture or a raise.
  - `Rows` holds the rows in the app's order, the `frontWindow`, and the begin z-order (`zOrder`). Keeping the z-order apart from the display order lets the lift still restore "the selected window, the one that was in front, then the others as before".
  - The selection starts on the front window's row, or on row 0 when every window is minimised (R8).
  - The card is a one-item window switcher. A one-item `SwitcherSelection` already forgets the overshoot at a turn and crosses nothing, so no light tick plays.
  - `cardOffset` maps that selection's `stretch` to points, at most 6 either way (R11).

**Where things live.**

- **The 0.2 s.** It is one Core constant, `GestureRules.windowReadDeadline`, and both port reads receive it as an argument, as `bringToFrontWatching` receives `cap:`. The adapter enforces it with the pure `ReadBudget`, stamped once at the call on the monotonic clock:
  - before each call into the app, the element's messaging timeout is set to what is left;
  - no time left (at or past the deadline, never a zero timeout, which Accessibility would read as "use the global 0.2 s"), or a read that ends past the deadline, gives `.unanswered`, so a late answer cannot get through;
  - nothing fires at the deadline.

  This is the lift window's stamp-and-compare shape. The model holds no clock.

  The read's calls into the app (copy the windows, copy a window's attributes, its number, set a timeout) and the clock sit behind an internal seam in the adapter, `WindowCalls`: the real one over Accessibility and a test double in `LauncherPlatformTests`. So the budget rule, the error rules and "partial is unanswered" are tested against a scripted app. `readEach` takes the per-app read as a parameter (the real one by default), so a test can hold one app's read and see the others answer. This is an internal seam with two adapters, like `RunningAppsReader`'s `order:` and `FrameStream`'s `clock:`, not a port.
- **The frontmost read** stays synchronous on the main actor (012's decision). It is now held to 0.2 s in all, where today a slow app could take seconds. It also carries the app's `AppLaunch`, for the order.
- **The row reads.** The main actor resolves each entry to its process (bundle identifier plus location, and whether it is hidden or is Trackpad Launcher itself), stamps one budget for all of them, and hands each process to its own GCD work item, never the cooperative pool. A call into a hung app holds its thread for what is left of the budget, and must hold up no other read. Only the `Sendable` `WindowRead` hops back. AX elements never leave the frontmost path, which alone keeps raise handles (why Preserve 1).
- **Read errors.**
  - On `kAXWindows`, no value reads as no windows; any other failure is `.unanswered`.
  - On a window's attributes, `cannotComplete` is `.unanswered`; any other failure skips that window, as today (a window closing mid-read answers invalid-element).
  - On a window's number, `cannotComplete` is `.unanswered`; any other failure, the private function missing included, falls back to today's match by frame and title against the window list, and a window matching none is left out.
- **Hidden apps (settles grounding open question 1).** `sort` gains one branch, used only when the app is hidden. A window counts as visible when it is an `AXWindow`, not minimised, not full screen, and has a full-screen button: the probed signal that separated document windows from panels. The frontmost app is never hidden, so the window switcher's own lists are unchanged.
- **Trackpad Launcher frontmost (settles grounding open question 4).** It reads `.ownProcess`, which counts one, so a slide over the settings window shows the card, as R10 asks for any app.

**Rendering.**

- **Slots.** `SwitcherPanel` holds one container layer per slot, at `(centreX(at:), centreY)`, with the copies first and the front icon last. Sublayers draw above their parent's contents, so this puts the copies behind the icon. `show` sets the 1.12 grow on the container, the same implicit 0.12 s action as today, so a whole stack grows with its icon and shrinks with the row (R5). The copies share the icon's bitmap.
- **The rise.** `addStack(at:copies:rises:)` places the copies at rest. With `rises` set, each copy also gets a `CABasicAnimation` on `position.y` from the icon's centre:
  - `beginTime` staggered by the copy's delay, `fillMode = .backwards` so a waiting copy hides behind the icon;
  - the layout's ease-out control points;
  - keyed `"rise"`.

  The animation is removed on completion and leaves nothing behind. Selection moves write only the container's `transform`, so they never replay or cut it.
- **The presenter.** It lays out once per serial and adds a stack when a slot goes from `.pending` to `.stack`: once per swipe, as soon as the count is known (R6).
- **The card.** `WindowSwitcherPanel` lays the card in a one-row column. The icon sits in a row's preview slot. The highlight's glass is the card's plate. The title column holds a 13 pt bold title above a 12 pt regular message, wrapping onto a second line and then cut short at its end.
  - `moveCard` moves the plate and content inside the panel's 8 pt padding. Each render uses a 0.1 s implicit action, so the turn through rest reads as a quick move and not a jump.
  - `settleCard` returns it to rest over the dismiss fade.
- **The presenters render values.** Each is built with only a `reduceMotion` reader (injected as `GearView` does). The shell then calls `observe(launcher)`, which starts the observations (and, for the app switcher, the icon passes) and feeds each value to `render(_:)`. So a bench in `LauncherUITests` builds a presenter with no `Launcher` and feeds it `Switcher` or `WindowSwitcher` values: two swipes with no `nil` between them, a `.pending` slot turning `.stack`, Reduce motion on and off, the card's lift.

**Depth.**

- **The port** grows by two calls. `readWindows` hides process lookup, own-process and hidden detection, the budget, the threads and the hop back. `openWindows(among:)` is one cheap question that only `WindowOrders` asks.
- **`WindowOrders.list`** is one method that hides the pick, the order's whole lifecycle, card versus rows, the row order and the selection start.
- **`Launcher`** keeps its shape and gains one branch, the card's silent lift.
- **Per boundary-discipline**, every decision is a pure value and the shell only renders.

**What the design deliberately does not do:**
- no AX observers;
- no count ever decides whether a slide is a window swipe or what a lift does (why Avoid 3);
- no warm-up reads at launch;
- nothing saved;
- nothing reordered mid-swipe;
- no app-quit push;
- no full window-list copy per read.

**Module map.**

| Module | New or changed |
|---|---|
| `LauncherCore` | `AppWindows`, `WindowRead`, `AppLaunch`, `FrontmostWindows` (reshaped), `WindowPick`, `WindowStack`, `SlotStack`, `Switcher` (`serial`, `stacks`, `take`), `WindowStackLayout`, `WindowOrders`, `WindowSwitcher` (`List`, `Rows`, `cardOffset`), `NoWindowsCard`, `RaiseOrder` (today's `WindowStack` enum, renamed to free the glossary word), `SwitcherSelection.init(count:startingAt:)` and `fullStretch`, `GestureRules.windowReadDeadline`, `Copy` (four strings), `SystemActions` (three members), `Launcher` |
| `LauncherPlatform` | `AppWindowReader` (today's `FrontmostAppWindows`, renamed with its file and both confinement entries), the internal `WindowCalls` seam with `AXWindowCalls`, `ReadBudget`, `RawWindow.hasFullScreenButton`, `WorkspaceActions` |
| `LauncherUI` | `SwitcherPresenter` and `SwitcherPanel` (keyed by serial, slot containers, `addStack`), `WindowSwitcherPresenter` and `WindowSwitcherPanel` (card mode); both presenters take a `reduceMotion` reader, render values, and are wired to the model by `SettingsShell` through `observe` |
| App target | nothing |

```swift
// MARK: - LauncherCore: what a read says

/// One app's windows as one read found them.
public struct AppWindows: Equatable, Sendable {
    /// On the current Space, front to back; for a hidden app, its document windows in the app's order (they show when
    /// it is shown again). Panels, palettes, sheets and other helpers are left out.
    public let visible: [AppWindow]
    /// Minimised, in the order the app lists them.
    public let minimised: [AppWindow]
    public init(visible: [AppWindow], minimised: [AppWindow])
}

/// What one read of one app's windows came to.
public enum WindowRead: Equatable, Sendable {
    /// Every call into the app answered within the read's deadline.
    case windows(AppWindows)
    /// No answer within the deadline, a call that could not complete partway (what was read so far is dropped), an
    /// immediate refusal, no Accessibility, or the app no longer running.
    case unanswered
    /// Trackpad Launcher itself, never read: its one window is the settings window.
    case ownProcess
}

/// One launch of a running app: equal for the same process, different after the app quits and opens again. Opaque:
/// the adapter makes it from the process id and the kernel's start time for that process; Core only compares it.
public struct AppLaunch: Hashable, Sendable {
    package init(_ token: String)
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    case noApp
    case app(AppEntry, AppLaunch, WindowRead)
}

extension WindowRead {
    /// How many windows a window swipe into the app lists (R2): `WindowPick`'s count, ten at most; one for Trackpad
    /// Launcher's settings window; nil when the app did not answer. The one count the stacks and the window switcher's
    /// choice between rows and the card both read.
    public var windowCount: Int? {
        switch self {
        case .windows(let windows): WindowPick(windows).count
        case .ownProcess: 1
        case .unanswered: nil
        }
    }
}

/// The windows a window swipe into the app lists, picked from one answered read (R2, R9): the window in front, the
/// other visible windows front to back, then the minimised ones in the app's order, `windowSwitcherMaxRows` at most. A
/// full-screen front window is picked alone; other full-screen windows never.
struct WindowPick: Equatable, Sendable {
    let front: AppWindow?
    let others: [AppWindow]
    let minimised: [AppWindow]

    init(_ windows: AppWindows) {
        // TODO: today's `Content.init?` cut without its two-row guard:
        //   front = visible.first; if front?.isFullScreen == true { others = []; minimised = [] }
        //   else others = visible.dropFirst().filter { !$0.isFullScreen }.prefix(limit - 1)
        //        minimised = windows.minimised.prefix(limit - (front == nil ? 0 : 1) - others.count)
        fatalError("not implemented")
    }

    var count: Int { (front == nil ? 0 : 1) + others.count + minimised.count }
    /// The picked visible windows, front to back: what a lift on the front window restores.
    var zOrder: [WindowID] { ((front.map { [$0] } ?? []) + others).map(\.id) }
    var windows: [AppWindow] { (front.map { [$0] } ?? []) + others + minimised }
}

// MARK: - LauncherCore: stacks in the app switcher

/// A window stack: the app's icon and one copy behind it per further window, 2 to 4 icons in all (R1).
public struct WindowStack: Equatable, Sendable {
    public static let maxIcons = 4
    public let icons: Int
    /// nil below two windows; `icons` is the count capped at `maxIcons`.
    public init?(windows: Int) { fatalError("not implemented") }
    public var copies: Int { icons - 1 }
}

/// One slot's stack as the swipe knows it: `.pending` until its app answers, then fixed for the swipe (R4).
public enum SlotStack: Equatable, Sendable {
    case pending
    /// Zero or one window, Trackpad Launcher itself, or no answer within the deadline.
    case alone
    case stack(WindowStack)
    /// `.windows` counts through `windowCount`; `.unanswered` and `.ownProcess` are `.alone`.
    init(_ read: WindowRead) { fatalError("not implemented") }
}

public struct Switcher: Equatable, Sendable {
    public let row: [AppEntry]
    /// The switchers begun since launch, either kind: the presenter lays out once per swipe and keys the rise on it,
    /// and a count read for one swipe never lands in another.
    public let serial: Int
    /// One per slot of `row`, every one `.pending` at the begin. Keyed by slot: two copies of one bundle are two slots.
    public private(set) var stacks: [SlotStack]
    public package(set) var selection: SwitcherSelection
    public let trackpad: TrackpadID
    private let startsOnFrontmost: Bool

    package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, serial: Int, trackpad: TrackpadID)

    /// Fills a `.pending` slot from its app's read; true when that changed the switcher. A slot already answered, or out
    /// of range, changes nothing: a count is read once, when the swipe begins, and holds for it.
    @discardableResult package mutating func take(_ read: WindowRead, at slot: Int) -> Bool { fatalError("not implemented") }
}

/// Where a window stack's copies sit behind an icon of `row`'s size, from the icon's centre, y up. The front icon is the
/// lone icon unchanged, so the row's spacing, the highlight and the panel stay as they are (R5); copies grow with the
/// selected icon because they live in its slot, whose transform the panel scales.
public struct WindowStackLayout: Equatable, Sendable {
    /// Each copy's side as a share of the icon's, nearest first. `copyScales.count == WindowStack.maxIcons - 1`.
    public static let copyScales = [0.92, 0.84, 0.76]
    /// How far each copy's top edge peeks above the top edge of the one in front of it, at full size.
    public static let fullPeek = 6.0
    /// The rise (R6): seconds, the delay between neighbouring copies, and a soft ease-out as cubic Bézier control points.
    public static let riseDuration = 0.3
    public static let riseStagger = 0.04
    public static let riseCurve: (Double, Double, Double, Double) = (0.25, 1.0, 0.5, 1.0)

    public let row: SwitcherRowLayout
    public init(row: SwitcherRowLayout)

    public struct Copy: Equatable, Sendable {
        /// Side, in points: `row.iconSide × copyScales[k]`.
        public let side: Double
        /// Centre at rest above the icon's centre: `fullPeek × (k + 1) × row.scale + (row.iconSide − side) / 2`. The
        /// rise starts at 0, exactly behind the icon.
        public let rise: Double
        /// Seconds after the stack appears that this copy starts rising: `riseStagger × k`, the nearest first.
        public let delay: Double
    }

    /// Nearest first: one per copy of `stack`.
    public func copies(of stack: WindowStack) -> [Copy] { fatalError("not implemented") }
}

// MARK: - LauncherCore: the window order

/// Each app's window order, by the app's location, for one launch of the app and as long as Trackpad Launcher runs;
/// never saved. Owned by `Launcher`, written only when a window swipe starts; the stacks' reads never touch it.
package struct WindowOrders: Equatable, Sendable {
    private struct Remembered: Equatable, Sendable {
        let launch: AppLaunch
        var windows: [WindowID]
    }
    /// One entry per app location: a later launch of the app replaces it, so memory is bounded by the apps window-swiped.
    private var orders: [URL: Remembered] = [:]
    package init() {}

    /// What a slide up or down shows, from the read at its start, after bringing the app's order up to date with an
    /// answered read. nil (no window swipe, R13) for no frontmost app and for an app that did not answer. The card (R10)
    /// for a count of zero or one: no windows, one window, a lone minimised one, a full-screen front window, Trackpad
    /// Launcher itself. Otherwise the rows: the R9 pick in the app's order, the front window's row noted. `stillOpen`
    /// answers which of the given windows the window server still holds; it is asked only when the order remembers a
    /// window the read did not list. Idempotent: the same read twice leaves the same order and gives the same content.
    package mutating func list(
        _ read: FrontmostWindows, stillOpen: (Set<WindowID>) -> Set<WindowID>
    ) -> WindowSwitcher.Content? {
        // TODO:
        //   guard case .app(let app, let launch, let windowRead) = read, let count = windowRead.windowCount else { return nil }
        //   if case .windows(let windows) = windowRead {
        //       let remembered = orders[app.url].flatMap { $0.launch == launch ? $0.windows : nil }   // another launch: none
        //       orders[app.url] = Remembered(launch: launch, windows: Self.updated(remembered, with: windows, stillOpen: stillOpen)) }
        //   guard count >= 2, case .windows(let windows) = windowRead else {
        //       return Content(app: app, list: .card(NoWindowsCard(count == 0 ? .noWindows : .oneWindow, of: app))) }
        //   return Content(app: app, list: .rows(Rows(app: app, pick: WindowPick(windows), order: orders[app.url]!.windows)))
        fatalError("not implemented")
    }

    /// The app's order now, for this launch; [] before its first window swipe.
    package func order(of app: AppEntry) -> [WindowID] { orders[app.url]?.windows ?? [] }

    /// The order brought up to date with one answered read. Pure but for `stillOpen`, which a test passes.
    /// - No order for this launch (`nil`: the first window swipe into this launch of the app): today's list, visible front
    ///   to back, then the minimised ones.
    /// - A remembered window the read did not list stays in its place if `stillOpen` holds it (another Space, a
    ///   full-screen Space), and leaves otherwise: it closed (numbers are never reused).
    /// - Listed windows the order lacks join at its end, in the order they opened (rising window numbers), even when
    ///   nothing remembered is left (R7: the app's windows all closed, or it had none at its first window swipe).
    static func updated(
        _ order: [WindowID]?, with windows: AppWindows, stillOpen: (Set<WindowID>) -> Set<WindowID>
    ) -> [WindowID] {
        // TODO:
        //   let listed = (windows.visible + windows.minimised).map(\.id); let listedSet = Set(listed)
        //   guard let order else { return listed }
        //   let missing = Set(order).subtracting(listedSet)
        //   let open = missing.isEmpty ? [] : stillOpen(missing)
        //   let kept = order.filter { listedSet.contains($0) || open.contains($0) }
        //   return kept + listed.filter { !kept.contains($0) }.sorted { $0.rawValue < $1.rawValue }
        fatalError("not implemented")
    }
}

// MARK: - LauncherCore: the window switcher, rows or the card

public struct WindowSwitcher: Equatable, Sendable {
    /// What one window swipe shows, fixed at its start.
    public struct Content: Equatable, Sendable {
        public let app: AppEntry
        public let list: List
    }

    public enum List: Equatable, Sendable {
        /// Two to ten windows, in the app's window order.
        case rows(Rows)
        /// Zero or one window: the no-windows card in place of the rows.
        case card(NoWindowsCard)
    }

    public struct Rows: Equatable, Sendable {
        /// Top to bottom, in the app's window order. `Row` is unchanged; a window titled "" reads "‹App› — Window N",
        /// N its 1-based row, as today.
        public let rows: [Row]
        /// The app's window in front when the window swipe began; nil when every listed window is minimised.
        public let frontWindow: WindowID?
        /// The listed visible windows, front to back, at the start: a lift restores this order behind the selected
        /// window. Kept apart from the row order, which no longer follows the z-order.
        let zOrder: [WindowID]
        /// The pick sorted by `order`, every picked window being in it; titled by `Copy.untitledWindow` and
        /// `WindowTitleRule` as today.
        init(app: AppEntry, pick: WindowPick, order: [WindowID]) { fatalError("not implemented") }
        /// The front window's row; 0 when there is none (R8).
        var startRow: Int { fatalError("not implemented") }
    }

    public enum Row: Equatable, Sendable { /* unchanged: .visible(WindowID, title:), .minimised(WindowID, title:) */ }

    public let content: Content
    /// Rows: one item per row, starting on `startRow`. The card: one item, so it rubber-bands both ways and crosses
    /// nothing: no light tick, no raise.
    public package(set) var selection: SwitcherSelection
    /// The switchers begun since launch, either kind.
    public let serial: Int
    public let trackpad: TrackpadID
    public let showsPreviews: Bool

    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        // TODO: rows → SwitcherSelection(count: rows.rows.count, startingAt: rows.startRow); card → SwitcherSelection(count: 1)
        fatalError("not implemented")
    }

    public var app: AppEntry { content.app }
    public var isCard: Bool { if case .card = content.list { true } else { false } }
    /// [] for the card.
    public var rows: [Row] { if case .rows(let rows) = content.list { rows.rows } else { [] } }
    /// The visible rows while `showsPreviews`; [] for the card.
    public var previewWindows: [WindowID] { fatalError("not implemented") }
    public var frontWindow: WindowID? { if case .rows(let rows) = content.list { rows.frontWindow } else { nil } }
    /// nil on a minimised row and on the card.
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }
    /// The card's offset from rest, in points, positive down; nil for rows.
    public var cardOffset: Double? { isCard ? NoWindowsCard.offset(stretch: selection.stretch) : nil }
}

/// The window switcher's single card for an app with zero or one window (R10): the app's icon on the left, a bold
/// first line and a regular second line.
public struct NoWindowsCard: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case noWindows, oneWindow }
    public let kind: Kind
    /// "No open windows" / "No other windows".
    public let title: String
    /// "‹App› has no windows on this desktop." / "‹App› has no other windows on this desktop."
    public let message: String
    package init(_ kind: Kind, of app: AppEntry) { fatalError("not implemented") }

    /// The most the card moves from rest, either way.
    public static let maxOffset = 6.0
    /// `maxOffset × stretch / SwitcherSelection.fullStretch`. A one-item selection keeps its travel within a quarter
    /// step of rest and restarts it from a turn, so the offset follows the movement since the last change of direction,
    /// damped by the rubber band's curve, never past 6 pt, and turns at once (R11). Pure.
    public static func offset(stretch: Double) -> Double { fatalError("not implemented") }
}

extension WindowSwitcher {
    /// The lift, from the start's rows and a second read; 012's rules restated against the order. Pure.
    /// - The card, no app, another app, no answer, or Trackpad Launcher: `.nothing`.
    /// - The selected window has closed or left this Space: no raises; the haptic plays iff a window is in front now and
    ///   it is not `frontWindow`.
    /// - Otherwise the target is the selected window, then `zOrder` without it and without any window the second read
    ///   did not list; the raises are `RaiseOrder.raises(current: visible now, target:)`; the haptic plays iff the
    ///   selected window is not `frontWindow`, which covers restoring a minimised one. Every raised id comes from the
    ///   second read, so nothing on another Space is raised.
    public func lift(now: FrontmostWindows) -> WindowLift { fatalError("not implemented") }
}

/// Today's `WindowStack.raises(current:target:)`, renamed so "window stack" means what the glossary says. Unchanged.
public enum RaiseOrder {
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID]
}

extension SwitcherSelection {
    /// Starts on item `start`, clamped: travel `start × switcherStepMM`, nothing reported yet, so the next `follow`
    /// moves by the frame's own travel.
    package init(count: Int, startingAt start: Int) { fatalError("not implemented") }
    /// `stretch` at the full overshoot of a quarter step: about 0.111 items.
    public static var fullStretch: Double { fatalError("not implemented") }
}

extension GestureRules {
    /// The most one read of one app's windows may take from the moment it is asked for (R4, R13).
    package static let windowReadDeadline = Duration.milliseconds(200)
}

extension Copy {
    public static let noOtherWindowsTitle = "No other windows"
    public static func noOtherWindowsMessage(of app: String) -> String { "\(app) has no other windows on this desktop." }
    public static let noOpenWindowsTitle = "No open windows"
    public static func noOpenWindowsMessage(of app: String) -> String { "\(app) has no windows on this desktop." }
}

// MARK: - LauncherCore: the port and the model

@MainActor public protocol SystemActions: AnyObject {
    // ... every other member unchanged ...

    /// The frontmost app's windows, read now on the main actor and held to `deadline` in all: each call into the app
    /// waits at most what is left, and a read that ends past it is `.unanswered`. Never reads Trackpad Launcher
    /// (`.ownProcess`). The windows it lists are the only ones a later `raiseWindows` may name, until the next read.
    func frontmostWindows(within deadline: Duration) -> FrontmostWindows

    /// Reads each app's windows away from the main actor, each on its own, all held to `deadline` from this call, and
    /// returns. `answer` runs on the main actor exactly once per slot of `apps`, inside this call or later, in no set
    /// order: `.unanswered` for an app that did not answer in time, stopped answering partway or no longer runs;
    /// `.ownProcess` for Trackpad Launcher. A slow or hung app delays no other. Replaces nothing `raiseWindows` uses;
    /// nothing these reads list is ever raised. The caller checks Accessibility.
    func readWindows(
        of apps: [AppEntry], within deadline: Duration,
        answer: @escaping @Sendable @MainActor (_ slot: Int, _ read: WindowRead) -> Void)

    /// Which of `windows` the window server still holds, on any Space, minimised or not: about 0.2 ms. Window numbers
    /// are never reused, so one missing here has closed (or its app quit).
    func openWindows(among windows: Set<WindowID>) -> Set<WindowID>

    /// Unchanged: raises ids of the latest `frontmostWindows` read only.
    func raiseWindows(_ frontToBack: [WindowID])
}

// Launcher (changed state):
//   @ObservationIgnored private var switchersBegun = 0          // replaces windowSwipesBegun: both kinds take a serial
//   /// Each app's window order. Written only by `windowSwipe(.began)`; survives reconciles; never saved.
//   @ObservationIgnored private var windowOrders = WindowOrders()
//   The doc comment "it always shows" on `windowSwitcher` becomes true again.

// MARK: - LauncherPlatform

/// The switchers' window reads and raises: the frontmost app's on the main actor, whose listed windows a raise may name,
/// and the switcher row's away from it, which are only counted. One of the two files allowed the Accessibility element
/// API and the window list (renamed from `FrontmostAppWindows`; both confinement entries follow the name).
@MainActor final class AppWindowReader {
    /// The process default for any element that sets none, as today; every read here sets its own per call.
    static let messagingTimeout: Float = 0.2
    private var listed: [WindowID: AXUIElement] = [:]
    private var isUnanswering = false

    /// As today: the process default, the private window-number function resolved once (into a `Sendable` holder, so
    /// the off-main reads can call it), and the window list warmed off the main actor.
    init() { fatalError("not implemented") }

    /// The frontmost app's read, held to `deadline`; replaces the raise handles with the listed windows' elements.
    func readFrontmost(within deadline: Duration) -> FrontmostWindows {
        // TODO: listed = [:]; isUnanswering = false
        //   NSWorkspace frontmost → .noApp; launch = AppLaunch(pid + sysctl kp_proc.p_starttime); own pid → .app(entry, launch, .ownProcess)
        //   let (read, elements) = Self.read(Target(pid: pid, isHidden: false),
        //                                    budget: ReadBudget(from: .now, within: deadline), calls: AXWindowCalls())
        //   listed = elements; isUnanswering = read == .unanswered
        fatalError("not implemented")
    }

    func raise(_ frontToBack: [WindowID]) { fatalError("not implemented") }   // unchanged

    /// On the main actor: resolves each entry to its running copy (bundle identifier plus `bundleURL == app.url`, its
    /// hidden state, and whether it is this process), stamps one `ReadBudget` for all, then one GCD work item per process,
    /// never the cooperative pool. Own process and no process answer at once, still through the hop. Each work item runs
    /// `readOne` and hops only its `WindowRead` back (`DispatchQueue.main.async` + `MainActor.assumeIsolated`, as the
    /// trackpads do). `readOne` is the real read by default; a test passes one that holds a chosen app's read.
    func readEach(
        _ apps: [AppEntry], within deadline: Duration,
        readOne: @escaping @Sendable (Target, ReadBudget) -> WindowRead = { Self.read($0, budget: $1, calls: AXWindowCalls()).read },
        answer: @escaping @Sendable @MainActor (Int, WindowRead) -> Void) { fatalError("not implemented") }

    /// `CGWindowListCreateDescriptionFromArray` over just these numbers.
    func openWindows(among windows: Set<WindowID>) -> Set<WindowID> { fatalError("not implemented") }

    /// One app's whole read, on the calling thread, through `calls`: kAXWindows; one multiple-attribute call per window
    /// (role, subrole, title, minimised, full screen, position, size, full-screen button); the window's number; the
    /// on-screen window list for order (and the full list only for the frame fallback when the private function is
    /// missing). Before each call into the app, the element's messaging timeout is set to `budget.timeout(at: calls.now())`.
    /// - kAXWindows: success lists; no value is no windows; anything else is `.unanswered`.
    /// - A window's attributes: `cannotComplete` is `.unanswered`; any other failure skips that window, as today.
    /// - A window's number: `cannotComplete` is `.unanswered`; any other failure (the private function missing
    ///   included) falls back to `number(of:among:)` over `calls.listedWindows(of:)`, copied once per read only when
    ///   needed; no single match leaves the window out, as today.
    /// - No time left before a call, or a read `budget` does not admit when it ends: `.unanswered`, whatever was read.
    /// Returns the listed windows' elements, for the one caller that raises.
    nonisolated static func read<Calls: WindowCalls>(_ target: Target, budget: ReadBudget, calls: Calls)
        -> (read: WindowRead, elements: [WindowID: Calls.Element]) { fatalError("not implemented") }

    /// Which windows are listed, and in what order. Pure; tested with probe facts.
    /// - Shown app: `AXWindow`/`AXStandardWindow`, not minimised, on screen, in the window list's order (unchanged).
    /// - Hidden app: `AXWindow`, not minimised, not full screen, with a full-screen button, in the app's order: its
    ///   document windows report `AXDialog` and leave the on-screen list but keep that button, which panels lack.
    /// - Minimised: by the flag alone, in the app's order (unchanged). A window with no number is left out.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32], appIsHidden: Bool)
        -> (visible: [AppWindow], minimised: [AppWindow]) { fatalError("not implemented") }

    struct Target: Sendable { let pid: pid_t; let isHidden: Bool }
}

/// The read's calls into one app, and the clock: an internal seam with two adapters, the real `AXWindowCalls` (in this
/// file, over the Accessibility element API, the private window number and the window list) and a scripted double in
/// `LauncherPlatformTests` that answers, refuses, stalls past the budget or advances the clock per call.
protocol WindowCalls: Sendable {
    associatedtype Element
    func now() -> Uptime
    /// Sets the element's messaging timeout for its next call (always positive: the budget never hands out zero).
    func setTimeout(_ seconds: Float, on element: Element)
    func appElement(_ pid: pid_t) -> Element
    func windows(of app: Element) -> Result<[Element], WindowCallError>
    func attributes(of window: Element) -> Result<RawWindow, WindowCallError>   // number not yet filled
    func number(of window: Element) -> Result<UInt32, WindowCallError>
    func onScreenNumbers(of pid: pid_t) -> [UInt32]
    /// Every normal-layer window of the pid, with frame and name: only for the frame fallback.
    func listedWindows(of pid: pid_t) -> [ListedWindow]
}

/// How a call into the app failed, parsed from the Accessibility error at the seam.
enum WindowCallError: Error, Equatable { case cannotComplete, noValue, other }

/// What is left of one read's deadline on the process's monotonic clock. Pure: tests pass the time.
struct ReadBudget: Equatable, Sendable {
    let deadline: Uptime
    init(from start: Uptime, within: Duration) { deadline = start + within }
    /// The messaging timeout for a call made at `now`: what is left, always positive; nil at or past the deadline, so no
    /// further call is made (a zero timeout would mean "the global 0.2 s" to Accessibility).
    func timeout(at now: Uptime) -> Float? { fatalError("not implemented") }
    /// Whether a read that ended at `now` answered in time.
    func admits(endedAt now: Uptime) -> Bool { now <= deadline }
}

// RawWindow gains `hasFullScreenButton: Bool`. WorkspaceActions forwards the three members to its `AppWindowReader`.

// MARK: - LauncherUI

final class SwitcherPresenter {
    /// `reduceMotion` is read at each render: the system's setting by default, injected by a bench. Builds the panel.
    init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    /// Called once by the shell: observes `launcher.switcher` into `render`, and `launcher.isSwipeOn` into the icon passes.
    func observe(_ launcher: Launcher)
    /// One value of `launcher.switcher`; a bench calls it directly. Lays out once per serial, adds each stack once.
    func render(_ switcher: Switcher?)
    private var laidOutSerial: Int?                 // replaces laidOutRow
    private var shownStacks: [SlotStack] = []
    private var stackLayout: WindowStackLayout
}

final class SwitcherPanel: OverlayPanel {
    /// One container layer per slot at (centreX(at:), centreY): its copies first, its icon last.
    func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat)
    /// The 1.12 grow on the containers, as today on the icons.
    func show(position: CGFloat, selected: Int, animatesSize: Bool)
    /// Inserts `copies` behind the slot's icon, sharing its image, at rest. With `rises`, each copy's `position.y`
    /// animates from the icon's centre (`WindowStackLayout`'s duration, curve and delay as `beginTime`, backwards fill),
    /// keyed "rise", removed on completion. Without it, the copies are in place at once (Reduce motion).
    func addStack(at slot: Int, copies: [WindowStackLayout.Copy], rises: Bool)
}

final class WindowSwitcherPresenter {
    init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    /// Called once by the shell: observes `launcher.windowSwitcher` into `render`.
    func observe(_ launcher: Launcher)
    /// One value of `launcher.windowSwitcher`; a bench calls it directly. A new serial lays out the rows as today, or the
    /// card (no capture, no awaited previews); `nil` settles a shown card, then dismisses. See Usage.
    func render(_ switcher: WindowSwitcher?)
}

final class WindowSwitcherPanel: OverlayPanel {
    /// The card in `WindowColumnLayout(rowCount: 1, …)`'s one row frame: the icon in the preview slot, the bold title
    /// and the regular message in the title column (two lines at most, then cut short), the highlight as its plate.
    func lay(card: NoWindowsCard, icon: NSImage, layout: WindowColumnLayout, topLeft: NSPoint)
    /// Plate and content `offset` points below rest (inside the 8 pt padding); a 0.1 s implicit action when animated.
    func moveCard(by offset: Double, animated: Bool)
    /// Back to rest over the dismiss fade's 150 ms, or at once; a no-op unless a card is laid out.
    func settleCard(animated: Bool)
}

// MARK: - Tests: the twins and handles (LauncherCoreTests)

// RecordingSystemActions
//   func windows(of app: AppEntry) -> FakeWindows        // one per running location; ids from one shared rising counter
//   var windows: FakeWindows { windows(of: frontmost) }   // today's tests keep working
//   var ownApp: AppEntry?                                  // reads of it are `.ownProcess`
//   private(set) var frontmostDeadlines: [Duration]
//   private(set) var countReads: [CountReadRequest]        // every readWindows call: apps, deadline, snapshots at the call
//   readWindows: answers `.now` apps inside the call; keeps `.held` ones for the test; never answers `.never` ones
//   openWindows(among:): the fakes' open windows on any Space
// FakeWindows gains
//   enum Answering { case now, held, never }; set(…, answering:)  // frontmost read: `.held` and `.never` read `.unanswered`
//   moveToAnotherSpace(_:), returnToThisSpace(_:), hide(), show()
//   var launch: AppLaunch                                  // the app's current launch, carried by its frontmost reads
// World gains
//   windows(of:), answerCountReads(of:) (the snapshot), giveUpCountReads(of:) (`.unanswered`),
//   quit(_:), relaunch(_:)                                 // a relaunch mints a new AppLaunch and fresh window numbers
//
// LauncherPlatformTests: a scripted `WindowCalls` double (answers, refusals, a stall past the budget, a clock that
// advances per call). LauncherUITests: benches build `SwitcherPresenter(reduceMotion:)` and `WindowSwitcherPresenter(reduceMotion:)`
// and feed `render` values, with no `Launcher`.
```

**Seams.** Each requirement group's scenarios run at `World`, the model driven through real recognisers under the in-memory adapters:
- R1 to R4 through `launcher.switcher.stacks`;
- R7 to R9 through `windowSwitcher.rows` and `.selection`;
- R10 to R13 through `windowSwitcher.isCard`, the card's text, `windowSwipeAnswers`, `raised`, pulses and `hidesOthers`.

Pure Core values carry the rules below the seam: `WindowPick`, `WindowOrders.updated`, `WindowStack`, `WindowStackLayout`, `NoWindowsCard.offset` and `SwitcherSelection(count:startingAt:)`. In `LauncherPlatformTests`, `sort` and `ReadBudget` are pure statics over probe facts and a driven clock, and `read` runs against a scripted `WindowCalls` double: the budget handed to each call, no call once time is out, a stall past the deadline, partial reads and the error rules. `readEach` runs with a `readOne` that holds one app, to show the others answer. Benches in `LauncherUITests` build each presenter without a `Launcher`, feed `render` values with Reduce motion injected, and read the panels' layers and animations back. Real hung, slow, cold and hidden apps stay a manual check, as 012 chose.

**Docs once this lands** (written in this plan's Phase D).
- `docs/product-overview.md`: as the requirements' Documentation section says (stacks, the window order with the selection on the window in front, the card, its silent lift).
- `docs/domain-model.md`:
  - new *Window order*, *Window stack* and *No-windows card* entries;
  - *Switcher*, *Window swipe*, *Window switcher*, *Window*, *Front window*, *Frontmost app*, *Tap* and *Feedback* follow the requirements.
- `docs/architecture.md` changes only its codebase-wide rules; the window order is feature-level and stays here.
  - **Concurrency:** the frontmost read is held to 0.2 s in all. A swipe reads its row's apps' windows off the main actor, one GCD work item per app. The window read's deadline is the second stamp-and-compare deadline beside the lift window.
  - **Privacy:** Accessibility also counts the windows of the switcher's row apps when a swipe begins. The confinement sentence names the switchers' window reads.

### Synthesis decision

**Base: candidate 1** (Opus). The cross-judge (`architect-judge`, on a different model) scored candidate 1 at 29 of 30 and candidate 2 (Fable) at 25 of 30, and recommended candidate 1. My own scoring, criterion by criterion, agrees. The decisive differences are factual:
- Candidate 2 took the on-screen order from one `optionAll` window-list copy. A check after fan-out falsified that (C2: the order differed in all 20 samples).
- Candidate 2's `retain(running)` forgot the order of any app missing from the ⌘-Tab list, such as a menu bar app with a window in front.
- Candidate 2 split the order's update across three places.

Candidate 1's runner reported that it read the rubric, which runners are not meant to see. Its score rests on the factual differences above and the judge scored independently, so the pick stands. The dropout count is zero.

**Convergence.** The two candidates arrived independently at the same whole shape:
- a three-case read;
- one count rule shared by the stacks and the rows;
- a URL-keyed order, pruned against the window server and reset to today's list when empty, with no quit push;
- rows or the card as a sum type, with the begin z-order kept apart from the display order;
- a per-swipe serial;
- one GCD work item per app, held to a per-element budget;
- the full-screen-button rule for hidden apps;
- the card for Trackpad Launcher;
- per-slot container layers.

That is a strong agreement signal, so the synthesis ships that shape and grafts only details.

**Grafted from candidate 2:**
- the copies' rise formula, `peek × layer × scale + (icon − side) / 2`, and the corner-clip risk. Candidate 1's formula halved the peek, which the judge caught.
- `WindowStack` (2 to 4 icons by construction) and the per-slot `SlotStack` (`.pending`, `.alone`, `.stack`), still filled by slot through candidate 1's `take(_:at:)`. This replaces `windowCounts: [Int?]`, so R4's "fixed once answered" is a state, not a convention.
- the fake's `Answering` vocabulary (`.now`, `.held`, `.never`), keeping candidate 1's snapshot taken at the begin.
- resolving each entry to its process on the main actor before dispatch. This avoids resting on an unprobed claim that `NSRunningApplication` is thread safe.

**Changed by verification:**
- **Existence check.** Both candidates found closed versus elsewhere through a full window-list copy in every read: 2.35 to 2.56 ms, on the main actor at each window swipe's start and lift, and ten times over on the row reads. Check C3 showed that one `CGWindowListCreateDescriptionFromArray` over just the remembered numbers costs 0.19 ms. So `AppWindows.elsewhere` is gone. `WindowOrders.list` asks `stillOpen` only when a remembered window is missing from the read, through a new `openWindows(among:)` port call.
- **Read errors.** Read errors follow today's reader: a per-window failure other than `cannotComplete` skips the window, and no value on `kAXWindows` is no windows. Candidate 1 had declined the whole read on any error.
- **Off-main budgets.** Check C1 settles the per-element timeout on GCD threads, which both candidates assumed.

**Changed by the test planner's findings:**
- **Presenters built without a model.** Each presenter is built with only its Reduce motion reader, wired by `observe(launcher)` and driven through `render(_:)`, so a bench can feed values: a `LauncherUITests` bench has no adapters to build a `Launcher`.
- **A seam for the read itself.** The read's calls into the app and the clock sit behind the internal `WindowCalls` seam, and `readEach` takes its per-app read, so the 0.2 s whole-read bound and "one hung app delays no other" are tested, not only the budget's arithmetic.
- **The budget at its edge.** `ReadBudget.timeout(at:)` is nil at or past the deadline and never zero, since Accessibility reads a zero timeout as the global 0.2 s.
- **The order belongs to one launch** of the app (`AppLaunch`). Both candidates reset an order to today's list whenever nothing remembered was left, so an app with no windows at its first window swipe, or whose windows all closed, listed new windows front first. R7 requires the end of the order. Keying by launch tells "this launch's order is empty" from "a relaunch", so R7 holds as written.
- **A newly recorded tradeoff:** the cold frontmost decline.

**Rejected from candidate 2:**
- the single `optionAll` copy (falsified);
- `retain(running)` (the menu-bar hole);
- `Body.init?(_:orders: inout)`, an initializer that writes an outside store;
- the budget as an adapter constant (the 0.2 s is requirement policy, so it lives in Core and the fake records it);
- answers keyed by `AppEntry` (ambiguous for two slots at one location);
- `StackRise` keyframes (a plain ease-out needs only a timing function).

### Tradeoffs accepted

- We accept that the first swipe after an app or Trackpad Launcher starts may miss a cold app's stack (cold first reads reach 204 ms) in exchange for a hard 0.2 s bound and no reading of other apps at launch.
- We accept one GCD work item per row app, a named exception to "explicitly concurrent functions", in exchange for a hung app delaying no other read on any core count.
- We accept that the same 0.2 s in all declines the first window swipe into a cold frontmost app whose first read runs longer (Xcode's took 204 ms here), which then scrolls, where today's per-call timeout let it through. In exchange, R13's "within 0.2 s" holds and a slow app can no longer stall the main actor for seconds. The next slide reads warm.
- We accept a quit app's order lingering (a few window numbers, never saved) until the app's next window swipe replaces it with the new launch's, in exchange for no app-quit push and no always-on observer.
- We accept an opaque launch identity in the frontmost read, so an order can tell an empty order of this launch from a relaunch (R7).
- We accept that new windows join in creation order taken from rising window numbers, which is probed but not documented.
- We accept counting a hidden app's document windows by a probed but undocumented signal, the full-screen button, in exchange for stacks that still show with *Hide background apps* on.
- We accept the card's reach being the rubber band's quarter step of travel, about 25 cursor points to the 6 pt cap, with a turn passing through rest, softened by a 0.1 s action, in exchange for "turn at once" and "no tick" being one rule shared with both switchers.
- We accept that a partial frontmost read declines the slide, and that an unanswered read at the lift raises nothing, in exchange for R13 holding with one outcome mapping.
- We accept that a slide under the anchored thumb over a zero- or one-window app no longer scrolls while the setting is on (why Change 2, at the human's request).
- We accept renaming `FrontmostAppWindows` to `AppWindowReader` and the `WindowStack` enum to `RaiseOrder`, plus the confinement edit, so names say what they own and the glossary word means one thing.

### Alternatives considered

- **Counts kept in `LauncherUI`, like previews.** The UI cannot import Platform, so it would gain a shell-injected count reader. It would then hold all of R2 to R4: whom to read, the permission, the own process and dropping stale answers. That is model policy in a view, with no model test seam. One deep port call hides the same work.
- **A model-held deadline** (a clock port plus a "timed out" push, or arrival stamps compared in the model). This makes the interface larger and needs a second copy of the 0.2 s, since the adapter must still hold each call to the budget to stop a slow read early. Nothing needs to fire at the deadline, because a late app just stays `.pending`, which draws as alone.
- **An app-quit push** (a terminate observer, or a pid on `AppEntry`). It would forget an order at the quit itself, but at the price of a push, an observer that runs whenever gestures do, and a process identity on every `AppEntry`. The opaque `AppLaunch`, carried only by the frontmost read, tells a relaunch apart at the one moment it matters, the next window swipe. Neither can tell closed windows from off-Space ones; the existence check does.
- **An order reset whenever nothing remembered is left**, both candidates' first shape. It needs no launch identity, but it lists new windows front first after an app had none or all closed, which R7 rules out.
- **The order inside the adapter**, with the read returning windows already ordered. The selection start, the R9 pick and the lift would then depend on adapter state, and the in-memory twin would need a second copy of the order rule. This loses on locality and testability.
- **A full window-list copy in every read** for existence. It costs 2.4 ms per read on the main actor, and ten times over per swipe off it, to answer a question that is usually empty. The targeted query costs 0.19 ms, only when a remembered window is missing.

### Open questions and risks

- **Default taken: hidden apps count by the full-screen-button rule.** Does a hidden app's Accessibility list leave out its windows on other Spaces, as the frontmost app's does? This is unprobed. If not, a hidden app's stack can over-count. The branch in `sort` is cheap to remove; check by hand.
- **Default taken: Trackpad Launcher frontmost shows the card** ("No other windows / Trackpad Launcher has no other windows on this desktop."), since R10 exempts no app. Plans 021 and 025 chose no window swipe over it. Reversing this is one case in `WindowOrders.list`.
- **Default taken: the card's message may wrap onto a second line.** R10 puts the icon "like a row's preview", which leaves the row's 200 pt title column for text. R10's own message ("Notes has no other windows on this desktop.", about 245 pt at 12 pt) cannot fit on one line there, even for a short name. So the bold title takes one line and the regular message wraps onto a second only when it must. Is three lines for such names acceptable, or should the card trade the preview-slot position for a narrower icon slot (about 260 pt of text, which fits short names)?
- **Default taken: copies start centred behind the icon**, fully hidden since each is smaller, and rise with ease-out control points (0.25, 1, 0.5, 1). The feel needs a hand check. Each is one constant.
- **Risk: the end slots' copies come near the panel's corners.** Selected, they reach about 133 of the panel's 136 pt, near the radius-34 continuous-corner clip. This was computed on paper. Check on screen; the fix would be a smaller top layer or a little less peek.
- **Risk: background reads run concurrently with main-thread raises and `LaunchWatch`.** This is probed (420 concurrent reads, no mismatch), but no source states it is safe.
- **Risk: R2's Get Info panel scenario rests on its subrole not being `AXStandardWindow`.** This is unprobed (opening it needs Finder automation), so it needs a manual check.
- **Risk: apps that refuse at once** (Preview read `cannotComplete` in 0.05 ms) show no stack and give no card. That is R13's letter, but a frontmost Preview with no windows will scroll rather than show "No open windows".
- **Risk: two running copies of one bundle at one location share an order key.** This was judged too rare to model.

### Next implementation step

Slice S1: reshape the read (`AppWindows`, `WindowRead`, `AppLaunch`, `FrontmostWindows`, `WindowPick`, `windowCount`) and rename `FrontmostAppWindows` to `AppWindowReader`. Then hold its read to 0.2 s in all through `ReadBudget` over the `WindowCalls` seam, test-first from T14 and T12, with the per-app test twins and the presenters' `init(reduceMotion:)`, `observe(_:)` and `render(_:)` split.

## Testing Decisions

### Strategy

The requirements are proven at one high seam, `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`): the real `Launcher`, driven through real `GestureRecognizer`s by scripted frames, over `InMemoryTrackpads` and `RecordingSystemActions`. It observes what the model publishes after every frame and every answer: `launcher.switcher`'s row, `stacks` and `serial`, and `launcher.windowSwitcher`'s rows, selection, `isCard`, card and `cardOffset`. It also observes what the model did to the ports: `windowSwipeAnswers`, `pulses`, press verdicts and scroll probes, every read with its deadline, `raised`, `hidesOthers`, `broughtToFront`, and every `openWindows(among:)` question. It misses the Accessibility API, the window server, the deadline's enforcement, the threads and the screen. Rows that say "never" or "at most once" record the published state after every frame and every answer and check the whole history. The new rows resemble `WindowSwitchingTests.swift`, `WindowSwitcherOnScreenTests.swift`, `SwitcherOnScreenTests.swift`, `HideBackgroundAppsTests.swift`, `SettingsWindowAsAppTests.swift` and `WindowSwipeNeedsTwoWindowsTests.swift`. The last one's reference comparison against the setting off is kept for no app and no answer, and becomes a comparison against a two-window window swipe for the card.

Below that seam sit four more, each as high as a real run allows:
- **Core values** in `LauncherCoreTests`, for the numbers a requirement states: `WindowStack`, `WindowStackLayout`, `NoWindowsCard.offset`, `SwitcherSelection(count:startingAt:)` and `Switcher.take`. These rows are like `SwitcherTests.swift` and `SwitcherRowLayoutTests.swift`. They miss the wiring, which the world rows carry.
- **Platform statics and the real adapter** in `LauncherPlatformTests`:
  - `AppWindowReader.sort` over probe facts, as `FrontmostAppWindowsTests.swift` does today (renamed);
  - `ReadBudget` over literal `Uptime`s;
  - `read(_:budget:calls:)` over a scripted `WindowCalls` double, whose clock advances per call and whose calls answer, refuse or stall on cue, so the whole-read bound, the error rules and "partial is unanswered" run for real;
  - `readEach(_:within:readOne:answer:)` with a `readOne` that holds one chosen app's read until the test releases it;
  - a real `AppWindowReader` for `readEach`'s once-per-slot hop and for `openWindows(among:)` against the real window server, awaited as `LaunchWatchClockTests.swift` awaits, with no upper bound on time asserted.

  They miss real apps that are hung, cold, hidden or on other Spaces, and the real Accessibility API behind `AXWindowCalls`.
- **Panel benches** in `LauncherUITests`: `SwitcherPanel` and `WindowSwitcherPanel` in a borderless window that is never ordered in. They read layers, frames, fonts and animations back, as `GearBench.swift` and `PickerBench.swift` do.
- **Presenter benches**: `SwitcherPresenter(reduceMotion:)` and `WindowSwitcherPresenter(reduceMotion:)`, built with no `Launcher` and never `observe`d, so no icon pass and no observation runs. The bench calls `render(_:)` with successive `Switcher` and `WindowSwitcher` values and reads their panels back. Rows are fed with `showsPreviews` false, so no screen capture starts.

The benches miss the feel, the timing on screen and the panel's corner clip, which are checked by hand.

**What is faked:**
- The Accessibility API and the window server, as `FakeWindows` per running location inside `RecordingSystemActions`. The fake carries no policy: reads report windows as they are, and its only knobs are what a real app and the window server can do.
- Reduce motion, as a closure, the way `GearBench` injects it.
- Inside the adapter's own tests, the AX calls and the monotonic clock, through the scripted `WindowCalls` double.

Everything we own runs for real. The model reads no clock, so no world row owns one. A late answer is a held answer that the test releases. The 0.2 s itself is checked in two places: as the deadline each read is asked for, and, in the adapter, on a test clock.

**Harness changes** (test code only):
- `RecordingSystemActions`:
  - `windows(of:)` gives one `FakeWindows` per running location, and `windows` is the frontmost app's;
  - `ownApp` is the app whose reads are `.ownProcess`;
  - `frontmostDeadlines` records each frontmost read's deadline;
  - `countReads` holds one record per `readWindows` call: its apps, its deadline, a snapshot of each app's windows taken at the call, and an `answer` per held slot;
  - `.now` slots are answered inside the call in reverse slot order, so no row leans on the order of answers;
  - `onReadWindows` runs inside `readWindows` before any answer, as `onPlayLaunchAnimation` runs inside its call;
  - `openWindowsQueries` records every `openWindows(among:)` argument, in order.
- `FakeWindows`:
  - `Answering`: `.now`, `.held` or `.never`. For the frontmost read, `.held` and `.never` read `.unanswered`;
  - a window gets its number when it is created (by `set`, in list order, or by `open`), from one counter shared by every app, so numbers rise in creation order as the window server's do (grounding F19);
  - `focus(_:)`: the user brings a window to the front by a click, ⌘`, the Window menu, Mission Control or the Dock, which also restores a minimised window;
  - `moveToAnotherSpace(_:)` and `returnToThisSpace(_:)`;
  - `hide()` and `show()`;
  - `launch`, the app's current `AppLaunch`, which its frontmost reads carry.
- `World`:
  - `windows(of:)`;
  - `answerCountReads(of:)` answers every held request for that app, in request order, from its snapshot;
  - `giveUpCountReads(of:)` answers them `.unanswered`;
  - `quit(_:)`, and `relaunch(_:)` for an app, which mints a new `AppLaunch` and recreates the app's windows under new numbers, in a given creation order and z-order. Today's `relaunch()` stays as it is and restarts Trackpad Launcher.
- `LauncherPlatformTests`: the scripted `WindowCalls` double records every timeout it is handed and every call it answers, in order.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R3 | World | Given `switcherWorld` with Accessibility, Safari frontmost with 2 windows, Mail with 3, Slack with 7, Notes with 1, all answering `.now`, and *Switch windows* off (its default). When the user swipes 3.5 mm and holds. Then `switcher.stacks` reads `.stack` of 2, 3 and 4 icons for Safari, Mail and Slack, and `.alone` for Notes. The same world with *Switch windows* on gives the same stacks. | R1 scenarios: 2 windows show 2 icons, 3 show 3, 7 show 4, one window shows its icon alone, and the frontmost app's slot does too; R3 "on or off" |
| T2 | R1 | World | Given two running copies of one bundle at two locations in the row, one with 3 windows and one with 1, set up as `twoRunningCopiesOfOneBundleAreTwoIcons` sets them up. When the user swipes. Then the two slots read `.stack` of 3 icons and `.alone`, each from its own copy. | R1 "each app"; the existing two-copies row's fixture |
| T3 | R1 | Core value | `WindowStack(windows:)` for 0, 1, 2, 3, 4, 5 and 7 is nil, nil, then 2, 3, 4, 4 and 4 icons, and `copies` is one fewer. | R1 literals: 2 → 2, 3 → 3, 4 or more → 4, zero or one alone |
| T4 | R2 | World | For each listing of Safari's windows, in a fresh world with Accessibility and *Switch windows* on: (a) 1 visible and 1 minimised; (b) 3 visible; (c) 1 visible and 2 moved to another Space; (d) none; (e) 10 visible and 2 minimised; (f) with Safari frontmost, a full-screen front window and 2 others. When the user swipes, and then, with Safari brought to the front, slides down under the thumb. Then the stack and the window switcher agree: (a) 2 icons and 2 rows; (b) 3 icons and 3 rows; (c) alone and the card; (d) alone and the card; (e) 4 icons and 10 rows; (f) alone and the card. | R2's scenarios (minimised windows count, windows on other Spaces do not, a full-screen front window counts one) and R2's own definition: what the window switcher lists for the same windows |
| T5 | R2 | Platform static | `AppWindowReader.sort` over `probe_hidden`'s facts for the hidden fixture: Utility `AXFloatingWindow` and PlainPanel `AXDialog`, neither with a full-screen button; W2 and W1 `AXDialog`, each with one; W3 minimised. With an empty on-screen list and `appIsHidden: true`, it lists W2 then W1 as visible and W3 as minimised. That is 3 windows, the 3 the shown read lists for the same fixture. A hidden app's full-screen window is left out. The shown facts with `appIsHidden: false` give W2, W1 and W3 as today, and today's sort rows stay green under the new name. | `probe_hidden.output.txt` (subroles and buttons, hidden and shown); `probe_fixture.output.txt` ("normal": count 3); R2 "never its windows on other Spaces" (a full-screen window has a Space of its own) |
| T6 | R3 | World | Given Accessibility missing and Safari with 2 windows. When the user swipes across the row and lifts. Then no `readWindows` call is made, and every slot is `.pending` on every frame until the switcher goes. | R3 "Without the Accessibility permission, every app MUST show its icon alone" |
| T7 | R4 | World | Given Safari frontmost with 2 windows and Notes with 1, both answering `.now`, and Mail with 2 answering `.held`; `onReadWindows` records `launcher.switcher`. When the swipe begins. Then at the read the switcher was already up with every slot `.pending`, and the read asked for the row's apps with a 200 ms deadline. After the begin frame the stacks read Safari `.stack` of 2, Mail `.pending` and Notes `.alone`. When the user slides one icon and the test then answers Mail's read. Then Mail reads `.stack` of 2. Over every state recorded after each frame and each answer, each slot leaves `.pending` at most once and never changes after. | R4 scenario "A slow app": the 150 ms answer is a held answer released inside the deadline, and T12 checks 150 ms against the budget; R4's 0.2 s |
| T8 | R4 | World | Given Safari and Notes with 2 windows each, answering `.now`, and Mail with 2 answering `.never`. When the user swipes across the whole row and lifts. Then Safari and Notes read `.stack` of 2 from the begin frame, and Mail reads `.pending` on every frame until the switcher goes. In the same setup with Mail `.held`, its read is given up (`.unanswered`, as the adapter answers past 0.2 s): Mail reads `.alone` from then on, and Safari and Notes do not change. | R4 scenario "An app that does not answer" |
| T9 | R4 | World | Given Notes with 1 window and Safari with 2, both answering `.now`. When the user swipes; during the swipe Notes opens a second window and Safari's second window closes; the fingers slide on and lift. Then Notes reads `.alone` and Safari `.stack` of 2 on every frame, and one `readWindows` call was made in all. | R4 scenarios "A window opens mid-swipe", "A window closes mid-swipe" |
| T10 | R4 | World | This row forces the interleaving. Given Mail with 2 windows answering `.held`. Swipe 1 begins and lifts with Mail's read pending. Mail opens a third window. Swipe 2 begins, again with Mail's read pending. When the test answers both held reads in request order. Then swipe 2's Mail slot reads `.stack` of 3, never 2. Separately, a held read answered after its swipe lifted leaves `launcher.switcher` nil, and so does one answered after a settings change removed its switcher mid-swipe. | R4 "read once, when the swipe begins": swipe 2's own read saw 3 windows |
| T11 | R1, R4 | Core value | `Switcher.take`: a `.windows` read of 3 windows at a `.pending` slot fills it with `.stack` of 3 and returns true. A second read at that slot returns false and changes nothing. A slot out of range returns false. `.unanswered` and `.ownProcess` each fill a slot with `.alone`. | R4 "MUST hold for the rest of the swipe"; R1: one window alone (Trackpad Launcher's settings window) |
| T12 | R4, R13 | Platform static | `ReadBudget(from: 10 s, within: 200 ms)`: `timeout(at:)` is 0.2 at 10 s and 0.05 at 10.15 s. It is nil at 10.2 s and at 10.25 s, and never 0 or negative. `admits(endedAt:)` is true at 10.15 s and at 10.2 s, and false at 10.2001 s. | R4's and R13's 0.2 s; R4's 150 ms; `AXUIElement.h`: a timeout of 0 on an element "makes that element use the current global timeout value", and timeout values "must be positive" |
| T13 | R4 | Platform adapter | A real `AppWindowReader`'s `readEach` runs over an entry for a bundle that is not running and over Finder's entry, within 200 ms. The call returns before any answer. Each slot is answered exactly once, on the main actor. The not-running slot answers `.unanswered`. Finder answers `.windows` when the test process is trusted for Accessibility and `.unanswered` when it is not. | The port's contract in the design; `AXIsProcessTrusted()`, read by the test |
| T14 | R4, R13 | Platform adapter, `WindowCalls` double | `read(_:budget:calls:)` over the scripted double, with a 200 ms budget stamped at 0 ms on the double's clock. (a) Every call into the app (`windows(of:)`, `attributes(of:)`, `number(of:)`) takes 50 ms. For an app with one window, the double is handed timeouts of 0.2, 0.15 and 0.1 before the three calls, and the read answers `.windows` with that window. For an app with two windows, it is handed 0.2, 0.15, 0.1 and 0.05, no fifth call is made, and the read answers `.unanswered`. (b) `windows(of:)` answers with one window, but only at 210 ms: the read answers `.unanswered` and makes no further call. (c) With instant calls: `windows(of:)` failing `.noValue` answers `.windows` with none; failing `.cannotComplete` or `.other` answers `.unanswered`. The second window's `attributes(of:)` or `number(of:)` failing `.cannotComplete` answers `.unanswered`, and the first window is dropped. Its `attributes(of:)` failing `.other` lists the other windows. Its `number(of:)` failing `.other` takes the number from the one `listedWindows(of:)` entry with the same frame (the window is listed under it), and from none leaves it out, the others still listed. On `.windows`, the returned elements are exactly the listed windows'. | R4's and R13's 0.2 s; R13 "has not reported its windows" (a partial read); the design's read-error rules; `probe_budget` (a per-element timeout caps the next call); `probe_fixture` (`_AXUIElementGetWindow` is an IPC call that times out) |
| T44 | R4 | Platform adapter, held `readOne` | A real `AppWindowReader`'s `readEach(_:within:readOne:answer:)` runs over three running apps the test picks from `NSWorkspace.shared.runningApplications`. Its `readOne` holds the first app's read on a semaphore and answers the others at once. The other two slots are answered first, each exactly once, on the main actor. When the test releases the first read, its slot is answered, once. All three `readOne` calls ran off the main thread and were handed one `ReadBudget`. | R4 "MUST NOT delay the other apps' stacks"; the port's contract in the design (once per slot, one budget stamped for all); `probe_fixture` (a stopped app holds only its own thread) |
| T15 | R5 | Core value | `WindowStackLayout(row: SwitcherRowLayout(iconCount: 5, displayWidth: 1512)).copies(of:)` a 4-icon stack gives sides of 73.6, 67.2 and 60.8 pt, nearest first. Their top edges (rise + side / 2) sit 6, 12 and 18 pt above the icon's top edge, which is 40 pt above its centre. At `SwitcherRowLayout(iconCount: 10, displayWidth: 540)` (scale 0.5), every side and every top-edge offset is half of that. A 2-icon stack gives the first copy only. | R5 literals (92, 84 and 76 % of the icon, about 6 pt per layer, the same factor); the layout's 80 pt icon at scale 1, and (540 − 44) / 992 = 0.5 |
| T16 | R5 | Panel bench | Given `SwitcherPanel.layoutRow` of five icons at the 1512 pt layout. When `addStack(at: 2, copies:` a 4-icon stack's copies`, rises: false)`. Then the panel is 536 × 136. The slot containers sit at x 68, 168, 268, 368 and 468, at y 68. Each slot's icon layer is 80 × 80 and is its container's last sublayer. Slot 2 holds three copies before its icon, sharing its contents, with their top edges 6, 12 and 18 pt above the icon's in window coordinates. When `show(position: 2, selected: 2, animatesSize: false)`. Then slot 2's container is scaled 1.12 with its copies' transforms at identity, and every other container is at identity. | `SwitcherRowLayoutTests` literals (536 × 136, pitch 100, first centre at 68); R5 "the whole stack MUST grow with it by the same factor"; the existing 1.12 |
| T17 | R6 | Core value | The rise from `WindowStackLayout`: the copies' delays are 0, 0.04 and 0.08 s, nearest first. The duration is 0.3 s, so the last copy is at rest by 0.38 s. The curve is an ease-out: its first control point lies above the diagonal and its second is at y = 1. | R6 literals: about 0.3 s, about 40 ms, the nearer one first, at rest within about half a second, a soft ease-out |
| T18 | R6 | Panel bench | `addStack(at: 1, copies:, rises: true)`: each copy has one animation, keyed "rise", on `position.y`. It runs from the icon's centre to the copy's place at rest, takes 0.3 s and fills backwards. The copies' begin times are 0.04 s apart, nearest first. Then `show(position:selected:animatesSize: true)` on each slot in turn leaves every copy's "rise" the same object and adds no animation to any copy. `addStack(rises: false)` places the copies at rest with no animation. | R6 "start exactly behind the front icon, at the same height", "never again while the selection moves", and Reduce motion's copies "in place without moving" |
| T19 | R6, R4 | Presenter bench | A `SwitcherPresenter(reduceMotion:)`, never `observe`d. With Reduce motion off, `render(_:)` is fed in turn: (1) serial 1, stacks `.stack` of 3, `.pending`, `.alone`; (2) serial 1, slot 1 now `.stack` of 2, the selection on slot 1; (3) serial 1, the selection on slot 2; (4) serial 2, with no nil between, slot 0 `.stack` of 3. Then render 1 lays out the row and only slot 0 rises. Render 2 adds slot 1's rise and leaves slot 0's alone. Render 3 adds no animation. Render 4 lays out afresh, and slot 0 rises again. A first render with every slot `.pending` shows the row with no copies. With Reduce motion on, the same feed places every copy at rest with no animation. | R6 "once per swipe, never again while the selection moves", and Reduce motion; R4 "never waits", "as soon as its count is known" |
| T20 | R7, R8 | World | Given Safari's windows Docs, Mail and News, with Docs in front. When the user window-swipes to News (the last row), lifts, and window-swipes again. Then the rows read Docs, Mail, News, and the selection starts on News, row 2. The same from a lift on Mail (the middle row) gives Docs, Mail, News, starting on row 1. This inverts `liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere`. | R7 scenarios "The order survives a lift on the last row" and "Lifting on a middle row"; R8 |
| T21 | R7 | World | Given Safari's order A, B, C, set by a first window swipe. Before the next window swipe, the user does one of these: focuses B; focuses C, then A; minimises B; minimises B and focuses it again; hides and shows Safari; swipes with Safari in the row. When the user window-swipes. Then the rows read A, B, C every time, with B dimmed and badged "Minimised" while it is minimised. | R7 "Nothing else changes it" and its list; scenarios "A clicked window keeps its place", "A minimised window keeps its place" |
| T22 | R7 | World | Given Safari's order A, B, C, with C in front. When the user opens D, which comes to the front, and window-swipes. Then the rows read A, B, C, D, starting on D. When the user opens E, then F, with F in front, and window-swipes. Then the rows read A, B, C, D, E, F. | R7 scenario "A new window joins at the end"; window numbers rise in creation order (grounding F19) |
| T23 | R7 | World | Given Safari's order A, B, C. When B closes and the user window-swipes. Then the rows read A, C, and `openWindows` was asked about B alone. Given the order A, B, C again. When B moves to another Space and the user window-swipes. Then the rows read A, C. When B returns and the user window-swipes. Then the rows read A, B, C. A window swipe whose read lists every remembered window asks `openWindows` nothing. | R7 scenarios "A closed window leaves", "A window on another Space keeps its place"; the design: asked only when a remembered window is missing |
| T24 | R7 | World | Given Safari's order A, B, C, with C in front. When Safari quits and relaunches (a new `AppLaunch`) with windows created as A', B', C' (new numbers), with C' in front, then A', then B', and the user window-swipes. Then the rows read C', A', B', not A', B', C' as new windows joining an order would. Given the same order. When Trackpad Launcher restarts (a new `Launcher` over the same Mac, started) and the user window-swipes. Then the rows read C, A, B. The settings suite holds the same keys before and after every window swipe. | R7 scenarios "The app relaunches", "Trackpad Launcher restarts" ("C, then the other windows front to back"); R7 "MUST NOT be saved" |
| T45 | R7 | World | Given Safari's order A, B, C. When all three close, then D opens, then E opens in front, and the user window-swipes. Then the rows read D, E, starting on E, and `openWindows` was asked about A, B and C. | R7 "a window closing leaves it" and "a window opening joins the order at its end"; resetting to today's list would read E, D |
| T46 | R7, R10 | World | Given Finder frontmost with no windows. When the user slides down. Then the card reads "No open windows". When X opens, then Y opens in front, and the user slides down again. Then the rows read X, Y, starting on Y. | R7 "The first window swipe into an app MUST set its order as today's list" (here, empty) and "a window opening joins the order at its end"; R10 (the card is that first window swipe) |
| T25 | R7 | Platform adapter | A real `AppWindowReader`'s `openWindows(among:)`, over a number from the window server's on-screen list and `UInt32.max`, answers the listed number alone. | `CGWindowListCopyWindowInfo`, read by the test; grounding F19: numbers rise and are never reused, so a number far above every listed one does not exist |
| T26 | R7 | World | Given Mail never window-swiped, with window X in front and Y behind it. When the user swipes (the app switcher reads Mail's windows), then focuses Y, brings Mail to the front and window-swipes. Then the rows read Y, X: the first window swipe set the order, and the count read did not. | R7 "The first window swipe into an app MUST set its order as today's list" |
| T27 | R8 | World | Given Safari's order A, B, C, set at a first window swipe, and the user then focuses C. When the user window-swipes. Then the selection starts on row 2 with no light tick and no raise. When the fingers slide up one row and lift. Then the windows read B, C, A from the front (the selected window, then the window that was in front, then the others as before), with one light tick and one gesture haptic. From the same start, sliding down past the end and lifting raises nothing, leaves C, A, B, and plays no haptic. | R8 scenarios "Start on the last row", "Slide up from the last row", "Lift where it started"; R8 "with the window that was in front just behind it" |
| T28 | R8 | World | Given Safari's order A, B, with both minimised. When the user window-swipes. Then the selection starts on A, row 0. Given the order A, B, C with B minimised. When the user window-swipes to B and lifts. Then B is restored in front with the gesture haptic. When the user window-swipes again. Then the rows read A, B, C, B is a visible row, and the selection is on B. | R8 scenarios "Every window minimised", "Lifting on a minimised window" |
| T29 | R8 | Core value | `SwitcherSelection(count: 3, startingAt: 2)` has `selected` 2, `position` 2 and `stretch` 0. Its first `follow(0.5)` stays on 2 with a stretch and crosses none. From that start, `follow(-6.1)` crosses one, to 1. `startingAt: 5` starts on 2, and `startingAt: -1` on 0. | R8; the switcher's half-row rule (the selection changes 6 mm from an item, per `SwitcherSelection`'s documentation) |
| T30 | R9 | World | Given Safari's order W1 to W12, set by a first window swipe with W1 in front; then W1 and W2 are minimised and W12 is focused. When the user window-swipes. Then the rows read W3 to W12, and the selection starts on W12, row 9. Today's cut rows at 10, 11 and 14 windows (`theListIsCutAtTenWithTheVisibleWindowsFirst`) stay green. | R9 scenario "Twelve windows"; the existing rows' literals |
| T31 | R10 | World | With Screen Recording granted, take each case in turn: (a) Notes frontmost with one window, sliding down; (b) Finder with no windows, sliding up; (c) Safari's front window in full screen with two others, sliding down; (d) Safari with one minimised window; (e) Trackpad Launcher frontmost, with its settings window open. Then `windowSwipeAnswers` is `[true]`, and the window switcher is the card, with no rows and no preview windows. Its lines read: (a) "No other windows" / "Notes has no other windows on this desktop."; (b) "No open windows" / "Finder has no windows on this desktop."; (c) and (d) "No other windows" / "Safari has no other windows on this desktop."; (e) "No other windows" / "Trackpad Launcher has no other windows on this desktop.". Each case makes one frontmost read. | R10 literals and scenarios; Non-goals: "Window previews on the card" |
| T32 | R10 | World | For the first three cases of T31, against a reference world where Safari has two windows, run four hands: a fresh slide, press and lift; a late slide, press and lift; down then sideways; down then a thumb tap. Then every frame's scroll probe and every press verdict on the card equals the two-window window swipe's, and for the fresh slide every frame with fingers down drops scrolling. This inverts `withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff` for these fronts. | R10 "follow every other window swipe rule"; the two-window window swipe as the reference; Dock swipes are covered by the recognizer's confirmed-start rows (`WindowSwipeAnswerTests`), which the `[true]` answer reaches |
| T33 | R10 | World | Given *Switch windows* off and Notes frontmost with one window. When the user slides two fingers down under the anchored thumb. Then no window swipe start is reported, no window read is made, no window switcher shows, and scrolling passes once the blocking window has passed. | R10 scenario "Setting off": today's behaviour, as `WindowSwipeBlockingTests`' setting-off row has it |
| T34 | R10, R7 | World | Given TextEdit frontmost with one window, Letter. When the user slides down. Then the card shows. Draft opens mid-slide, and the card stays on every frame, with one read. When the next slide starts. Then the rows read Letter, Draft, starting on Draft. This inverts `aWindowThatOpensMidSlideDoesNotMakeItAWindowSwipeButCountsForTheNextSlide`. | R10: the card is a window swipe, fixed at its start; R7: the card's window swipe set the order, and Draft joins at its end |
| T35 | R10 | Panel bench | `WindowSwitcherPanel.lay(card:` Notes's one-window card`, icon:, layout: WindowColumnLayout(rowCount: 1, …), topLeft:)`: the icon sits centred in the row's preview slot. The title reads "No other windows" in a bold 13 pt font. It sits above the message "Notes has no other windows on this desktop.", in a regular 12 pt font, on at most two lines. No row view is visible. A following `lay(out:)` of three rows hides the card and shows three rows, and a `lay(card:)` after that hides the rows. | R10 "the app's icon on the left, like a row's preview", "The first line MUST be bold and the second line regular weight"; the design's 13 and 12 pt |
| T36 | R11 | World | Given Notes with one window and the card shown. When the fingers slide down 40 mm in 1 mm frames. Then `cardOffset` after every frame lies between −6 and 6, never decreases and reaches 6. From the second frame on, its increase per millimetre never grows. When the fingers turn and slide up 40 mm. Then the first frame after the turn lowers the offset, and the offset passes 0 and ends at −6, never going beyond it. No pulse plays over the whole slide and its lift. | R11 scenarios "Capped travel", "Turning back"; R11 "damped", "6 pt", "no haptic" |
| T37 | R11 | World | Take two card worlds: one slides down 10 mm and then up 1 mm, the other down 40 mm and then up 1 mm. Then their `cardOffset`s are equal and negative. | R11 "since their last change of direction" and "passing its resting place", with the other world as the reference |
| T38 | R11 | Core value | `NoWindowsCard.offset(stretch:)` is 0 at 0. A one-item `SwitcherSelection` followed 40 mm down reaches a stretch whose offset is 6, and followed 40 mm up, −6. The offset's sign is the stretch's. | R11 "6 pt above or below its resting place" |
| T39 | R11 | Panel bench | After `lay(card:)`: `moveCard(by: 6, animated: true)` puts the plate and its content 6 pt below rest, with a 0.1 s action, and `moveCard(by: -6, …)` puts them 6 pt above. `settleCard(animated: true)` returns them to rest with a 0.15 s animation; `settleCard(animated: false)` does so at once, with none. With rows laid out, `settleCard` changes nothing. | R11 "settle back as the switcher goes"; the design's 0.1 s action and 150 ms fade |
| T40 | R11, R10 | Presenter bench | A `WindowSwitcherPresenter(reduceMotion:)`, never `observe`d. `render(_:)` is fed a card window switcher with `cardOffset` 6, then nil. With Reduce motion off, the plate moves 6 pt down, then settles back over the fade. With Reduce motion on, the plate is at rest after every step, with no animation. A card of serial 1 followed directly by rows of serial 2 lays out the rows and hides the card. | R11 "With Reduce motion on, the card MUST stay still"; R10 "in place of the rows" |
| T41 | R12 | World | Given *Hide background apps* on, the settings window open, and Notes frontmost with one window. When the user slides down on the card and lifts. Then Notes's windows were read once, at the start; `raiseWindows` was never called; no pulse played; nothing hid; nothing came to the front; and the settings window is still open. The same holds when a third finger cancels the card instead. | R12 literals and scenario "Lift". Today's window lift always reads again and calls `raiseWindows`, so this row proves the card's own path |
| T42 | R13 | World | The reference comparison of `withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff`, now over three fronts: no active app; Safari frontmost answering `.held`; Safari frontmost answering `.never`. For every hand and both swipe settings, the outcome equals that of the reference world with *Switch windows* off; no frame shows a window switcher; `windowSwipeAnswers` is `[false]`; and each app's frontmost read asked for 200 ms. A two-window window swipe asks for 200 ms at its start and at its lift. | R13 scenarios "App not answering", "No frontmost app" ("as today" is the setting-off slide); R13's 0.2 s |
| T43 | R13 | World | Given Accessibility missing and Notes with one window. When the user slides down. Then no window read is made, no window switcher shows, and no start is reported. After the grant, the next slide shows the card. This inverts `withoutAccessibilityASlideDownIsNoWindowSwipeAndAGrantBringsItBackWithTheNextSlide`. | R13 scenario "No Accessibility permission"; R10 (with the permission) |

### Verified without a test

- **R2, a helper panel.** By hand, with Accessibility granted and *Switch windows* on:
  1. Make Finder frontmost with one window. Select a file and press ⌘I.
  2. Swipe. Expected: Finder's icon shows alone.
  3. Slide two fingers down under the thumb. Expected: the card reads "No other windows / Finder has no other windows on this desktop."

  The Get Info panel's subrole is not probed, so no fact exists to copy into a sort row.
- **R2, a hidden app's windows on other Spaces.** By hand:
  1. Turn *Hide background apps* on. Give Safari one window on this desktop and two on another.
  2. Tap a gesture for another app, so Safari hides.
  3. Swipe. Expected: Safari's icon shows alone.

  Three icons here means the hidden branch of `sort` over-counts, the design's open question; the branch is then removed.
- **R4, a hung or cold app.** By hand:
  1. Give Mail two windows and run `kill -STOP` on Mail's pid.
  2. Swipe. Expected: the row shows at once, the other apps' stacks rise, and Mail's icon stays alone through the lift.
  3. Run `kill -CONT` and swipe again. Expected: Mail's stack rises.
  4. Quit and reopen Trackpad Launcher, then swipe at once. Expected: any app whose stack is missing shows it from the next swipe on.
- **R13, a stopped frontmost app.** By hand:
  1. In Terminal, run `sleep 5; kill -STOP <TextEdit's pid>`, then click TextEdit's only window within the 5 s.
  2. Once the 5 s have passed, slide two fingers down under the thumb. Expected: no window switcher, nothing pulses, and the pointer never shows the busy cursor.
  3. Run `kill -CONT` and slide again. Expected: the card.
- **R5, the corner clip.** By hand: put an app with four or more windows in the row's last slot and swipe onto it. Expected: its top copy is whole inside the panel's rounded corner, selected and not.
- **R6, the feel.** By hand:
  1. Give Safari three windows and swipe. Expected: two copies rise out from behind its icon, the nearer one first, and are still within half a second.
  2. Slide the selection on and off Safari. Expected: the copies do not move.
  3. Turn Reduce motion on in System Settings → Accessibility → Display, and swipe. Expected: the copies show in place.
- **R10, a long name.** By hand: make System Information frontmost with one window and slide down. Expected: the bold title stays on one line, and the message takes at most two lines, cut short with an ellipsis if longer.
- **R11, the feel.** By hand:
  1. Give Notes one window, then slide down and back. Expected: the card moves a few points with the fingers, turns at once, and settles back as the panel fades.
  2. Turn Reduce motion on and repeat. Expected: the card stays still.
- **R4, R13, the design's invariants.** `swift test` is green, `SourcePolicyTests` included:
  - no timer token appears anywhere;
  - `AXUIElement` and `CGWindowList` appear only in `AppWindowReader.swift` and `LaunchWatch.swift`;
  - `LauncherCore` imports only Foundation and Observation.

  The Swift 6 build proves that the row reads cannot write the raise handles: `listed` is main-actor state, and `read` is a `nonisolated static` running in `@Sendable` work items.
- **R7, never saved.** A grep shows that `WindowOrders` conforms to no `Codable` and that `SettingsStore` never names it. T24 shows the same behaviour across a restart.
- **R1 to R13, the documents.** Phase D's diff of `docs/product-overview.md`, `docs/domain-model.md` and `docs/architecture.md` is read against the plan's Documentation section and the design's "Docs once this lands". `docs/architecture.md` changes only its Concurrency and Privacy sentences.

## Slices

Each slice lands green on `swift test`. The four behaviours follow one another, because each later one reads what the earlier one wrote: the stable order is built on the reshaped read, the card is one of `WindowOrders.list`'s answers, and T4 compares a stack with the card. The documents are written in Phase D from the design's "Docs once this lands", and checked as Verified without a test says.

### S1: The read says what happened, held to 0.2 s in all

**What to build:** a slow or hung frontmost app declines a slide up or down within 0.2 s, instead of holding the main actor for seconds. A read that stops partway declines it too. Everything else behaves as today. This slice is also the prefactor for the rest:
- the renames: `FrontmostAppWindows` becomes `AppWindowReader`, with its file and both confinement entries, and the `WindowStack` enum becomes `RaiseOrder`;
- the read's types: `AppWindows`, `WindowRead`, `AppLaunch`, `FrontmostWindows` reshaped to `.app(AppEntry, AppLaunch, WindowRead)`, `WindowPick` and `WindowRead.windowCount`;
- `GestureRules.windowReadDeadline`, `SystemActions.frontmostWindows(within:)`, and `ReadBudget` in the adapter;
- the internal `WindowCalls` seam, with `AXWindowCalls` and `WindowCallError`, and `read(_:budget:calls:)` built over it;
- `WindowSwitcher.Content`, built on `WindowPick` and still requiring two windows;
- both presenters built by `init(reduceMotion:)`, wired by `observe(_:)` from `SettingsShell`, and drawn by `render(_:)`;
- the test twins per app, with `Answering`, numbers given at creation from one shared counter, `launch`, and `frontmostDeadlines`.

**Blocked by:** None (can start immediately).

**Requirements:** R13 (the 0.2 s bound on the frontmost read, and a partial read declines), R4 (the adapter's deadline arithmetic).

**Test scenarios:** T12, T14, T42.

**Skills:** `dev-workflow:codebase-design`, `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`

- [ ] Every existing suite is green after mechanical updates. `SourcePolicyTests` confines `AXUIElement` and `CGWindowList` to `AppWindowReader.swift` and `LaunchWatch.swift`.
- [ ] A grep finds `FrontmostAppWindows` nowhere, and the old `WindowStack` enum nowhere.
- [ ] `SettingsShell` calls each presenter's `observe(_:)` where it built the presenter before, so the first icon pass still runs, and is waited for, before gestures run (read in the shell's start order).
- [ ] The R13 stopped-frontmost-app sequence under Verified without a test passes by hand.

### S2: A stable window order

**What to build:** the window switcher lists each app's windows in that app's window order. The first window swipe into a launch of the app sets the order, which lasts until the app quits or Trackpad Launcher stops. Windows that open later join its end, even after every remembered window has closed. The selection starts on the window in front, and the lift still restores the z-order from the start. The pieces:
- `WindowOrders` in `Launcher`, holding one `Remembered` order per app location for its `AppLaunch` and written only by `windowSwipe(.began)`. Its `updated(_:with:stillOpen:)` takes no order (`nil`) as "set today's list". Its `list` still gives no window swipe below two windows; S3 brings the card;
- `Rows` with `zOrder` and `startRow`;
- `SwitcherSelection.init(count:startingAt:)`;
- `lift(now:)` restated against the order;
- `SystemActions.openWindows(among:)`, with both its adapters;
- the fake's `focus`, Space moves, and hide and show; app `quit`, and `relaunch`, which mints a new `AppLaunch`.

**Blocked by:** S1.

**Requirements:** R7, R8, R9.

**Test scenarios:** T20, T21, T22, T23, T24, T45, T25, T27, T28, T29, T30.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`

- [ ] The rows that assumed "row 0 is the front window" are inverted or updated, starting with `liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere`.
- [ ] The R7 never-saved grep under Verified without a test passes.

### S3: The no-windows card

**What to build:** with *Switch windows* on and Accessibility granted, a slide up or down over an app with zero or one window shows the window switcher's single card, naming the app. That covers a full-screen front window, a lone minimised window and Trackpad Launcher itself. The card follows the fingers a few points and settles back. Lifting or cancelling changes nothing and is silent. No app, or no answer, still declines the slide. The pieces:
- `WindowSwitcher.List` (`.rows` or `.card`) and `NoWindowsCard`, with its `offset(stretch:)`;
- `SwitcherSelection.fullStretch`, `cardOffset` and the four `Copy` strings;
- `WindowOrders.list` answering with the card;
- `Launcher`'s silent lift on the card;
- `WindowSwitcherPanel`'s card mode: `lay(card:icon:layout:topLeft:)`, `moveCard` and `settleCard`;
- `WindowSwitcherPresenter`'s card branch, with its `reduceMotion` reader.

**Blocked by:** S2.

**Requirements:** R10, R11, R12, R13.

**Test scenarios:** T31, T32, T33, T34, T46, T35, T36, T37, T38, T39, T40, T41, T43.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`

- [ ] `WindowSwipeNeedsTwoWindowsTests` is inverted and renamed after what it now proves. `SettingsWindowAsAppTests.slidingDownOverTheSettingsWindowIsNoWindowSwipe` becomes T31's Trackpad Launcher case.
- [ ] The R10 long-name and R11 feel sequences under Verified without a test pass by hand.

### S4: Window stacks, counted and drawn

**What to build:** every swipe shows each app with two or more windows as a stack of up to four icons. Windows are counted exactly as a window swipe into that app would list them. They are read once, off the main actor, when the swipe begins, and the switcher never waits for them. A hidden app's document windows count. The copies are drawn at rest. The pieces:
- `SystemActions.readWindows(of:within:answer:)` and `AppWindowReader.readEach(_:within:readOne:answer:)`;
- the hidden branch of `sort`, and `RawWindow.hasFullScreenButton`;
- `WindowStack`, `SlotStack`, and `Switcher`'s `serial`, `stacks` and `take(_:at:)`;
- the shared `switchersBegun`, and `Launcher.swipe`'s reads and `counted`;
- `WindowStackLayout`'s geometry;
- `SwitcherPanel`'s slot containers, with `addStack(at:copies:rises:)` placing the copies at rest;
- `SwitcherPresenter`, keyed by serial, adding a stack when a slot goes from `.pending` to `.stack`.

**Blocked by:** S1, S3 (T4 compares a stack with the card).

**Requirements:** R1, R2, R3, R4, R5.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T13, T44, T15, T16, T26.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:swift-concurrency`, `macos-dev-workflow:axiom-macos`

- [ ] The R2 helper-panel, R2 hidden-app, R4 hung-app and R5 corner-clip sequences under Verified without a test pass by hand.

### S5: The stacks rise into place

**What to build:** each stack rises out from behind its icon once per swipe, as soon as its count is known, with the nearest copy first. With Reduce motion on, it shows in place instead. The pieces:
- the rise timing of `WindowStackLayout`;
- the `rises` path of `addStack`: staggered `position.y` animations keyed "rise", removed on completion;
- `SwitcherPresenter`'s `reduceMotion` reader.

**Blocked by:** S4.

**Requirements:** R6.

**Test scenarios:** T17, T18, T19.

**Skills:** `dev-workflow:tdd`, `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`

- [ ] The R6 feel sequence under Verified without a test passes by hand, Reduce motion included.
