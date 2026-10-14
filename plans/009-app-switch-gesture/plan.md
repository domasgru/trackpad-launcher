# Plan: Thumb tap to swap apps

## Problem statement

The quickest way to jump back to the previous app is a quick ⌘-Tab: press, release, and the two most recent apps swap. Trackpad Launcher has no equivalent. The swipe reaches the previous app, but it takes a slide and a lift, and it shows the switcher every time. A tap gesture reaches only the one app assigned to it, not "the app I was just in".

Users who flip between two apps all day want this on the trackpad, with one hand, without reaching for the keyboard.

## Solution

A new action, the **swap**: the user rests two fingers on the trackpad, then taps the thumb in the anchor corner. The app used just before the frontmost app comes to the front. Each further thumb tap, while the two fingers stay down, swaps back again: A, B, A, B. It works like a quick ⌘-Tab, and nothing is shown on screen. Each swap gives the gesture haptic and no launch animation.

The order of landing tells the swap apart from what exists today. Thumb first, then fingers: a tap gesture or a swipe, as today. Fingers first, then thumb: a swap.

The swap has its own switch, **Thumb tap to swap apps**, on by default. It sits in the launcher window's switcher section, below *Swipe to switch apps*. The two switches are independent.

Terms, for the glossary. New: *swap* (the action above), *swap series* (the swaps made while the same two fingers stay down), *thumb tap* (the thumb landing in the anchor corner and lifting quickly), and *swap setting* (the Thumb tap to swap apps switch). The *anchor corner*, *anchored thumb*, *gesture*, *feedback*, *click blocking*, *blocking window* and *launcher window* entries change to mention the swap. A swap is not a *gesture* in the glossary's sense, just as the swipe is not.

`docs/product-overview.md` gains the swap next to the swipe: resting two fingers and tapping the thumb in the anchor corner swaps the two most recently used apps, repeatable while the fingers stay down, with its own switch in the window. Its haptic exception generalises: a swipe lift or a thumb tap that changes nothing is silent. `docs/domain-model.md` follows the terms above.

## Requirements

### R1. A thumb tap under two resting fingers swaps apps
When the swap setting is on and gestures are active, a thumb tap under the resting fingers R6 describes MUST bring to front the app used most recently before the frontmost app. A *thumb tap* is a contact that lands inside the anchor corner, does not drag more than 3 mm, and lifts within the tap window, the same 400 ms as tap gestures'. A thumb that presses to click and releases within the tap window MUST count as a thumb tap. The swap MUST fire when the thumb lifts. The fingers may rest for any length of time beyond the minimum R6 sets.

#### Scenario: First swap
- **GIVEN** the user used Mail, then Safari, and Safari is frontmost
- **WHEN** the user rests two fingers in the middle of the trackpad, then taps the thumb in the anchor corner
- **THEN** Mail comes to the front when the thumb lifts

#### Scenario: Left-hand mode
- **GIVEN** hand mode is Left hand, and the user used Mail, then Safari
- **WHEN** the user rests two fingers, then taps the thumb in the top-right corner
- **THEN** Mail comes to the front

#### Scenario: Tap in the wrong corner
- **GIVEN** hand mode is Right hand
- **WHEN** the user rests two fingers, then taps the thumb in the top-right corner
- **THEN** no app changes and no haptic plays

#### Scenario: Thumb rests too long
- **WHEN** the user rests two fingers, then lands the thumb in the anchor corner and keeps it down longer than the tap window before lifting
- **THEN** no app changes and no haptic plays

#### Scenario: Thumb drags
- **WHEN** the user rests two fingers, then lands the thumb in the anchor corner, slides it more than 3 mm and lifts it quickly
- **THEN** no app changes and no haptic plays

#### Scenario: Thumb presses to click
- **GIVEN** the user used Mail, then Safari, Safari is frontmost, and Trackpad Launcher has the Accessibility permission
- **WHEN** the user rests two fingers, then presses the thumb in the anchor corner hard enough to click and releases it within the tap window
- **THEN** Mail comes to the front, and the click does not reach any app, as today's blocking window holds it back

### R2. The swap targets apps in ⌘-Tab order
The app a swap brings to front MUST be the first of the running apps, in the order ⌘-Tab shows them, that is not the frontmost app at the moment of the thumb tap. Bringing to front MUST work as for gestures: an app that is hidden, has only minimised windows, has no windows, or sits on another Space or in full screen comes to the front. When there is no frontmost app, as while Trackpad Launcher itself is active, the swap MUST bring the most recently used running app to the front.

#### Scenario: Hidden previous app
- **GIVEN** the user used Notes, then hid it, and Safari is frontmost
- **WHEN** the user swaps
- **THEN** Notes is unhidden and comes to the front

#### Scenario: Menu bar app is skipped
- **GIVEN** the user used Mail, then a menu bar only app, then Safari is frontmost
- **WHEN** the user swaps
- **THEN** Mail comes to the front

#### Scenario: Trackpad Launcher is active
- **GIVEN** Trackpad Launcher was just opened from Finder and is active, and Safari was used before Finder
- **WHEN** the user swaps
- **THEN** Finder comes to the front, since there is no frontmost app and Finder is the most recently used running app

### R3. Further thumb taps keep swapping
While the same two fingers stay down, each further thumb tap MUST fire another swap, and its target MUST follow R2. The app the previous swap brought to front is then the frontmost app, so the two apps alternate. A rapid tap MUST NOT target a stale order, even if the previous app has not finished coming to the front. This MUST hold however fast the user taps, as long as each tap is a thumb tap.

#### Scenario: Three taps
- **GIVEN** the user used Mail, then Safari, and Safari is frontmost
- **WHEN** the user rests two fingers and taps the thumb three times without lifting the fingers
- **THEN** Mail, then Safari, then Mail come to the front

#### Scenario: Rapid taps
- **GIVEN** Safari is frontmost and Mail was used before it
- **WHEN** the user taps the thumb four times in under a second with two fingers resting
- **THEN** the front app goes Mail, Safari, Mail, Safari, and Safari ends in front

#### Scenario: Previous app quits between taps
- **GIVEN** the user used Notes, then Mail, then Safari, and Safari is frontmost
- **WHEN** the user rests two fingers and swaps, Safari quits, and the user taps the thumb again
- **THEN** the second tap brings Notes to the front, since Mail is frontmost and Notes is the first other app in ⌘-Tab order

#### Scenario: Another app activates between taps
- **GIVEN** the user used Mail, then Safari, and Safari is frontmost
- **WHEN** the user rests two fingers and swaps, a Calendar alert brings Calendar to the front, and the user taps the thumb again
- **THEN** the second tap brings Mail back to the front, since Calendar is frontmost and Mail is the first other app in ⌘-Tab order

### R4. Nothing to swap is silent
When ⌘-Tab shows no running app other than the frontmost app, a thumb tap MUST change nothing and MUST play no haptic.

#### Scenario: Only one app running
- **GIVEN** Finder is the only running app that ⌘-Tab shows, and it is frontmost
- **WHEN** the user swaps
- **THEN** Finder stays in front, and the trackpad gives no haptic

### R5. A swap gives the gesture haptic and nothing on screen
Each swap that brings an app to front MUST play the gesture haptic. A thumb tap that does not swap MUST play no haptic. A swap MUST NOT play the launch animation, whatever the launch animation setting. It MUST NOT show the switcher or anything else on screen.

#### Scenario: Launch animation on
- **GIVEN** the launch animation setting is on
- **WHEN** the user swaps
- **THEN** the trackpad gives the gesture haptic, the previous app comes to the front, and no icon floats up from the pointer

### R6. Exactly two fingers, landed before the thumb
A thumb tap MUST NOT swap unless exactly two fingers are down outside the anchor corner, not counting edge contacts, and both landed in an earlier frame than the thumb, however shortly before. A thumb that lands before the fingers MUST NOT start a swap: today's tap gestures and swipe apply unchanged. Landing order MUST be judged for each thumb contact on its own: a thumb that lifts and lands again is judged by its new landing. A thumb that lands under two resting fingers and stays down longer than the tap window MUST NOT swap and MUST behave as today: once the fingers lift, it is an anchored thumb.

#### Scenario: One resting finger
- **WHEN** the user rests one finger, then taps the thumb in the anchor corner
- **THEN** no app changes and no haptic plays

#### Scenario: Three resting fingers
- **WHEN** the user rests three fingers, then taps the thumb in the anchor corner
- **THEN** no app changes and no haptic plays

#### Scenario: Thumb tapped right after the fingers land
- **WHEN** the user lands two fingers, taps the thumb in the anchor corner 20 ms later, and keeps the fingers down until the thumb has lifted
- **THEN** the swap fires

#### Scenario: Thumb lands together with the fingers
- **WHEN** the thumb lands in the anchor corner in the same instant as the two fingers, and lifts first
- **THEN** no app changes and no haptic plays

#### Scenario: Palm on the edge does not count
- **GIVEN** the side of the palm rests on the trackpad's edge
- **WHEN** the user rests two fingers, then taps the thumb in the anchor corner
- **THEN** the swap fires

#### Scenario: Thumb first is still a tap gesture
- **GIVEN** the 2-finger gesture is assigned to Notes
- **WHEN** the user anchors the thumb, then taps two fingers
- **THEN** the 2-finger gesture fires and Notes comes to the front; no swap happens

#### Scenario: Thumb first is still a swipe
- **GIVEN** the swipe setting is on
- **WHEN** the user anchors the thumb, then lands two fingers and slides them sideways
- **THEN** the switcher shows, as today; no swap happens

#### Scenario: Held thumb becomes an anchored thumb
- **GIVEN** the 2-finger gesture is assigned to Notes
- **WHEN** the user rests two fingers, lands the thumb in the anchor corner and keeps it down longer than the tap window, lifts the fingers, then taps two fingers
- **THEN** no swap happens, and the 2-finger gesture fires and Notes comes to the front

#### Scenario: A new thumb landing is judged again
- **GIVEN** the user used Mail, then Safari, and Safari is frontmost
- **WHEN** the user anchors the thumb, rests two fingers, lifts the thumb, and taps it again in the anchor corner
- **THEN** Mail comes to the front

### R7. Moving fingers do not swap
Before the first swap of a series, a thumb tap MUST NOT swap if either finger has moved more than 3 mm since it landed. After the first swap, small drift MUST NOT stop the series. Once either finger moves more than 3 mm from where it was at the last swap, further thumb taps MUST NOT swap until no finger rests outside the anchor corner.

#### Scenario: Scrolling then tapping
- **WHEN** the user scrolls a page with two fingers, keeps them down, and taps the thumb in the anchor corner
- **THEN** no app changes and no haptic plays

#### Scenario: Slight drift between taps
- **GIVEN** the user has just swapped
- **WHEN** the fingers drift 1 mm, and the user taps the thumb again
- **THEN** the apps swap again

#### Scenario: Sliding ends the series
- **GIVEN** the user has just swapped
- **WHEN** the fingers slide 10 mm, and the user taps the thumb again
- **THEN** no app changes and no haptic plays, and no thumb tap swaps until both fingers lift and land again

### R8. A swap series survives one finger lifting and ends on a third finger
A finger of the series that lifts MUST rejoin the series if it lands again while the other series finger is still down, so the next thumb tap still swaps. Its reference for R7's drift becomes where it landed again. The series MUST end when both fingers are up at the same moment. A third finger that lands outside the anchor corner during a series MUST stop it: no thumb tap swaps until no finger rests outside the anchor corner.

#### Scenario: One finger lifts and lands again
- **GIVEN** the user has just swapped
- **WHEN** one finger lifts and lands again while the other stays down, and the user taps the thumb
- **THEN** the apps swap again

#### Scenario: Both fingers lift
- **GIVEN** the user has just swapped
- **WHEN** both fingers lift, two fingers land again, and the user taps the thumb
- **THEN** the apps swap again, as the first swap of a new series

#### Scenario: Third finger lands
- **GIVEN** the user has just swapped
- **WHEN** a third finger lands, and the user taps the thumb
- **THEN** no app changes and no haptic plays, and no thumb tap swaps until no finger rests outside the anchor corner

### R9. Clicks, scrolling and system swipes stay blocked during a series
From the first swap of a series until no finger rests outside the anchor corner, Trackpad Launcher MUST block trackpad clicks, trackpad scrolling and the system's trackpad swipes, for the whole series, as during a swipe. Blocking needs the Accessibility permission, as all click blocking does. Without it, a swap MUST still bring the app to front; clicks and scrolling are simply not blocked. Before the first swap, today's blocking rules MUST apply unchanged.

#### Scenario: Pressing between taps
- **GIVEN** the user has just swapped and the thumb has lifted
- **WHEN** the user presses the trackpad hard enough to click, 5 seconds after the swap
- **THEN** the click does not reach the app in front

#### Scenario: Drift does not scroll
- **GIVEN** the user has just swapped in a long web page
- **WHEN** the fingers slide 10 mm
- **THEN** the page does not scroll

#### Scenario: One finger stays down
- **GIVEN** the user has just swapped
- **WHEN** the user lifts one finger, keeps the other down, and presses the trackpad hard enough to click
- **THEN** the click does not reach the app in front, as during a swipe

#### Scenario: Blocking ends when the fingers lift
- **GIVEN** the user has just swapped
- **WHEN** both fingers lift and the user then scrolls with two fingers
- **THEN** the page scrolls

#### Scenario: No Accessibility permission
- **GIVEN** Trackpad Launcher lacks the Accessibility permission, the user used Mail, then Safari, and Safari is frontmost
- **WHEN** the user swaps, then presses the trackpad hard enough to click
- **THEN** Mail comes to the front, and the click reaches Mail

### R10. The swap setting has its own switch, on by default
The launcher window's switcher section MUST show a **Thumb tap to swap apps** switch below *Swipe to switch apps*. It MUST be on by default, including for users upgrading from a version without it. Upgrading MUST change no other setting.

#### Scenario: Default on
- **GIVEN** a fresh install
- **WHEN** the user opens the launcher window
- **THEN** the Thumb tap to swap apps switch is on, and a swap works

#### Scenario: Upgrade
- **GIVEN** a user with the swipe setting off and the launch animation off upgrades to this version
- **WHEN** they open the launcher window
- **THEN** Thumb tap to swap apps is on, and Swipe to switch apps and Launch animation are still off

### R11. With the swap setting off, nothing changes from today
While the swap setting is off, a thumb tap under two resting fingers MUST do nothing beyond today's behaviour.

#### Scenario: Switched off
- **GIVEN** the user turned the switch off
- **WHEN** the user rests two fingers and taps the thumb in the anchor corner
- **THEN** no app changes and no haptic plays

### R12. A swap setting change applies at once and is kept
A change MUST apply to the next thumb tap. It MUST be saved at once, so it survives a quit, a force-quit or a Mac restart.

#### Scenario: Survives restart
- **GIVEN** the user turned the switch off
- **WHEN** the Mac restarts and Trackpad Launcher starts again
- **THEN** the switch is still off

#### Scenario: Survives force-quit
- **GIVEN** the user just turned the switch off
- **WHEN** the user force-quits Trackpad Launcher and opens it again
- **THEN** the switch is still off

### R13. The swap and swipe settings are independent
The swap MUST work whether the swipe setting is on or off. The swipe MUST work whether the swap setting is on or off.

#### Scenario: Swipe off, swap on
- **GIVEN** Swipe to switch apps is off and Thumb tap to swap apps is on
- **WHEN** the user swaps
- **THEN** the previous app comes to the front

#### Scenario: Swap off, swipe on
- **GIVEN** Thumb tap to swap apps is off and Swipe to switch apps is on
- **WHEN** the user anchors the thumb, then lands two fingers and slides them sideways
- **THEN** the switcher still shows

### R14. The swap follows gestures' active state
While gestures are inactive, a thumb tap MUST NOT swap. Gestures are inactive when no trackpad is connected, or when a conflicting setting (*Tap to click*, *Look up: Tap with three fingers*) is on for a connected trackpad.

#### Scenario: Tap to click is on
- **GIVEN** Tap to click is on for the connected trackpad
- **WHEN** the user rests two fingers and taps the thumb in the anchor corner
- **THEN** no app changes and no haptic plays

### R15. A swap closes the launcher window
A swap that brings an app to front MUST close the launcher window if it is open, as a gesture does.

#### Scenario: Window open
- **GIVEN** the launcher window is open
- **WHEN** the user swaps
- **THEN** the previous app comes to the front and the launcher window closes

## Non-goals

- **Walking further back with repeated taps (A → B → C).** The user chose a toggle between the two most recent apps. The swipe already reaches older apps.
- **An on-screen indicator or launch animation for swaps.** Swaps are fast and repeated. Visuals would get noisy, and the app coming to the front is feedback enough.
- **A thumb tap with one, three or more resting fingers.** Only two fingers make a swap. Other counts stay free for later.
- **A new illustration for the swap in the launcher window.** The switch sits in the existing switcher section, so no new design asset is needed.
- **A tunable corner zone or tap window for the thumb tap.** It uses the same fixed anchor corner and tap window as every gesture.
- **Sound effect.** Sound is still deferred for every gesture.
- **Swapping windows within one app (like ⌘-`).** The swap is app-level, like ⌘-Tab.
- **A thumb tap while the switcher is showing.** A swipe needs the thumb anchored first, so a swap and a swipe never overlap.

## Implementation Decisions

Two facts about the code shape the decisions. First, the recognizer already judges who landed first, implicitly: in its idle state a corner landing becomes the anchored thumb, and any contact already down makes that thumb a spoiled anchor that waits for the contacts to lift. The swap is exactly that fingers-first case, so it becomes a state of its own rather than a second recognizer. Second, bring to front is asynchronous: the running-apps read (the active app from the workspace, the ⌘-Tab order from LaunchServices) shows the activated app in front only once the activation lands, some tens of milliseconds to a few hundred later, so a thumb tap that follows another closely reads an order the previous swap has not reached yet. The in-memory system actions never update their frontmost app or their running list on bring to front, so the test world shows an in-flight activation by default and a landed one only when a test says so.

1. **Who landed first decides the mode; the recognizer gets a fingers-first state.** `GestureRecognizer` gains one state for contacts that landed with no thumb anchored: a *rest*, every contact down that is not the thumb (edge contacts are already filtered out before the state machine), plus an optional thumb, a corner contact that landed while the rest was down, which is either a *thumb tap* in progress or *held*. The thumb-first states (armed, tapping, resting pair, spoiled, swiping) keep their rules. The modes hand over to each other. An anchored thumb that lifts or leaves the corner while contacts are still down enters the fingers-first state with those contacts as the rest. A fingers-first thumb, candidate or held, that leaves the corner (past `corner.holds`) becomes a rest finger at once and the thumb slot empties, so a thumb that slid out is judged anew only when it lifts and lands again (R6), and nothing is blocked from that frame. A swipe that ends or is cancelled goes to spoiled with its remembered thumb, exactly as today; with no remembered thumb, its contacts still down become a rest, and with none, idle. A rest that empties leaves the state, to armed when a held thumb remains and to idle otherwise. Idle now means nothing is down. With the swap setting off the recognizer is built with `swaps: false`, and a corner contact under a rest is always held, never a thumb tap: nothing fires, no series starts, and the blocking flags follow the thumb rules, which is today's spoiled-anchor behaviour to the frame (R11), as `swipes: false` is for the swipe.

2. **A thumb tap qualifies at its landing and fires at its lift.** When a corner contact lands while a rest is down and no thumb is present, it is a thumb tap candidate iff `swaps` is on, the rest holds exactly two contacts (each landed in an earlier frame; a thumb landing in the same frame as the fingers goes down the thumb-first path from idle), and the rest is not stopped (decision 4). Otherwise it is held. A candidate is spoiled, and becomes held, on any frame where it is more than 3 mm from its landing point (`dragThresholdMM`), has been down longer than `maxTapDuration` (400 ms), or the rest changed under it (a contact lifted or landed, or the rest became stopped). A press during the tap, withheld or delivered, is part of it: R1 counts a thumb that presses to click as a thumb tap without naming the permission, and R9 wants the swap without one, so unlike a tap gesture a thumb tap is never cancelled by a click. A candidate that lifts unspoiled fires `.swap(startsSeries:)`, true iff no swap has fired in this rest; the rest's series is then on and every rest finger's reference moves to where it is now (R7). A held thumb that stays while the rest lifts is the anchor afterwards, as today (R6).

3. **One contact book replaces three scattered records (a prefactor).** The recognizer keeps, for every contact down after the edge filter, its reference point (its landing point, until a swap moves it) and when it was first seen, with whether that was a real landing (what the thumb's blocking window asks today). The anchor's landing time, the tap's landing points and the pair's origins read from it instead of carrying copies, and the drag check reads origins from it. Behaviour is unchanged and the suite stays green. It is what lets a rest be built from contacts that landed under a thumb (R6's "judged again" needs their real landing times) without copying state across the modes.

4. **The series lives in the rest.** The rest holds its finger set, whether its series is on, and whether it is stopped. Per frame: lifted contacts leave; landed non-thumb contacts join with a fresh reference (a series finger that lifts and lands again rejoins with its landing point as reference, R8); stopped latches when any rest finger is farther than 3 mm from its reference (from its landing point before any swap, R7's "Scrolling then tapping"; from where it was at the last swap during a series) or when a third contact joins while the series is on (R8). Stopped is permanent for that rest and ends only with it. Before any swap, "exactly two" is the count alone, so three resting fingers that become two can still swap, as R6 is written; during a series a third finger stops it, as R8 is written.

5. **Blocking flags.** With the series on, both `blocksClicks` and `blocksDockSwipes` are true on every frame the rest is non-empty, whatever the thumb or the clock did, as for a swipe (R9). Before the first swap, the fingers-first thumb (tapping or held) is the anchor for today's rules: Dock swipes are blocked while another contact is down, clicks while that holds and the thumb landed less than 3 s ago (R9, "unchanged"); a thumb already down on the recognizer's first frame opens no window, as today. With no thumb nothing is blocked. The top-of-step anchor reset must leave the fingers-first state alone, since the thumb's lift is the swap's trigger; that state handles its own thumb, including its leaving the corner (decision 1).

6. **The event and the port.** `Recognition.Event` gains `.swap(startsSeries: Bool)`; `TrackpadEvent` gains `.swap(SwapEvent)` where `SwapEvent(startsSeries:trackpad:)` carries the flag and the trackpad on which the haptic plays; `TrackpadEvent.init(_:on:)` maps it, so both hardware adapters forward it with no other change. `TrackpadHardware.run` gains `swaps: Bool` beside `swipes:`, `GestureRecognizer.init` likewise (no default, as for `swipes`), and `Launcher`'s run record takes `swaps` from the setting, so a change rebuilds the recognizers, ends any series, and applies to the next thumb tap (R12). The `Fixtures.swift` helpers (`fired`, `phases`, `perFrame`) take `swaps: Bool = true`, and every direct `GestureRecognizer(...)` construction in the tests passes `swaps: true`, so the existing rows run with the swap on. Two parallel flags mirror the swipe; a third recognition option would be the moment to fold them into one options value.

7. **The model performs the swap; a small core value targets it.** `Launcher.swap(_:)` is the swap's one path: forget the series memory when the event starts a series; guard gestures active (R14, as `fire` does; the setting needs no guard here, since a recognizer built with `swaps: false` never emits a swap and the port never delivers from a replaced session, exactly as for the swipe); read `system.runningApps()` once; ask the series value for the target; return silently when there is none (R4); otherwise play the gesture haptic on the event's trackpad, bring the target to front through the unchanged Dock-click bring to front (R2), and close the window (R15). Never the launch animation, never the switcher (R5). `SwapSeries`, a value in the core, remembers the last swap of the series in progress, the location it started from and the entry it brought to front, and computes R2's target with one correction for a stale read (R3): when the read's frontmost app is still the one the last swap started from (nil on both sides included, Trackpad Launcher active) and the app that swap brought to front is still running, that swap has not landed, and its target stands in as the frontmost app; any other read is taken as it is. The target is the first entry of `apps` whose location differs from the effective frontmost app's; nil when there is none. The rule, traced by hand:

   ```swift
   mutating func next(in running: RunningApps) -> AppEntry? {
       let inFlight = last.flatMap {
           running.frontmost?.url == $0.from && running.contains($0.to.url) ? $0.to : nil
       }
       let frontmost = inFlight ?? running.frontmost
       guard let target = running.apps.first(where: { $0.url != frontmost?.url }) else { return nil }
       last = Last(from: frontmost?.url, to: target)
       return target
   }
   ```

   Worked trace with the read never refreshing (Safari in front, apps Safari, Mail, Slack): Mail (from Safari); Safari is still `from`, so Mail stands in: Safari (from Mail); Safari is now `to`, not `from`: Mail; Safari is `from` again: Safari. Mail, Safari, Mail, Safari. When reads refresh between taps the correction never applies, so R3's quitting and activating scenarios read the real order. The memory is one per model, not per trackpad, is forgotten at the next series, and is never consulted by the swipe (Further Notes).

8. **The setting.** `Settings.isSwapOn`, default true, keyed by its field name permanently, decoded as true when the key is absent so any earlier record loads with it on and nothing else changed (R10). `Launcher.isSwapOn` exposes it; `setSwap(on:)` ignores a no-change call, saves at once and reconciles. It is independent of `isSwipeOn` (R13): the recognizer takes both. Until the setting exists (S2), `reconcile` passes `swaps: true`.

9. **The window.** `SwitcherSection` becomes two setting rows: the swipe row as today, then "Thumb tap to swap apps" with a switch bound to `isSwapOn`, laid out like the Launch animation row and with no illustration (a non-goal). The section's height is fixed, so the shell's refit observation is untouched. The hint is unchanged: no requirement names it (Further Notes).

10. **The test fakes.** `InMemoryTrackpads.run` takes `swaps`. `RecordingSystemActions` is unchanged: it never updates `frontmost` or `running` on `bringToFront`, which is the in-flight read R3 needs; a test that wants an activation to land sets them through a new `World.activate(_:)`.

11. **Documentation.** `docs/domain-model.md`: *Swap*, *Swap series*, *Thumb tap* and *Swap setting* added; *Gesture*, *Anchor corner*, *Anchored thumb*, *Running apps*, *Frontmost app*, *Launcher window*, *Feedback*, *Launch animation*, *Click blocking* and *Blocking window* follow this plan. `docs/product-overview.md`: the swap beside the swipe and the generalised haptic exception, as the Solution says. `docs/architecture.md`: the Concurrency bullet's list of events that hop to the main actor gains the swap; an accuracy edit, no new decision.

## Testing Decisions

### Strategy

Two seams, both existing. The high seam is `Launcher` through `World` in `LauncherKit/Tests/LauncherCoreTests/`: the real model, recognizer, click and scroll filters, catalog over a temp tree and settings store over a throwaway suite, with the in-memory hardware, preferences, access, system actions and scanner. It observes `system.broughtToFront`, `hardware.pulses` and `feedback`, `system.launchAnimations`, `launcher.switcher`, `isWindowOpen`, `isSwapOn`, `isSwipeOn`, `hardware.pressVerdicts`, `isBlockingClicks`, `scroll(_:)`, `hardware.running` and `store`/`relaunch()`. It misses what LaunchServices really answers (plan 008's adapter tests), the Dock-click semantics of bring to front (unchanged code, hardware steps only), the SwiftUI window, the real tap thread and haptic feel. The second seam is `GestureRecognizer.step` through the `Fixtures.swift` helpers (`HandFrames` for exact interleavings, a per-frame map of event and flags), for frame-exact boundaries and the blocking flags, as `ClickBlockingRecognizerTests.swift` and `DockSwipeBlockingRecognizerTests.swift` do. New rows resemble `SwitcherOnScreenTests.swift`, `SwipeSettingTests.swift`, `ClickBlockingTests.swift`, `ScrollSuppressionTests.swift`, `PersistenceTests.swift` and `GestureRecognizerTests.swift`.

Fixtures: `TouchScript` gains `thumbTap(atMM:hold:dragMM:click:)`, a corner contact with the script's thumb id landing at the cursor and lifting after `hold` (default 120 ms), the cursor advancing by the hold plus 100 ms, with drag and click timing as `tap` has them, so `slide` and `lift` keep ignoring it. A fingers-first script starts with the existing `land(fingers:)` and `wait(.milliseconds(150))`. `World.swap(taps:lift:)` mirrors `World.swipe`: two fingers rest 150 ms, `taps` thumb taps, then the fingers lift unless told otherwise, returning its script so a row can continue it with `play`. `World.activate(_:)` makes an installed app the frontmost app and the first of `running`: the previous swap's activation has landed. Leaving the fake alone between taps is the in-flight case. `play` delivers only frames newer than any already delivered on that trackpad, so a second independent hand in one World would deliver nothing: every lettered or semicolon-separated clause of a row below runs in its own World unless the row says it continues the same hand, and "nothing" is that World's whole record. The clock is the frame timestamps. Faked: nothing we own; the system boundaries are the ones already behind ports.

Default fixture, unless a row says otherwise: `World.switcherWorld()` (Safari, Mail, Slack, Notes installed and running in that order, Safari frontmost, started, `macBook14`, right hand); thumb at (10, 10) mm; fingers at (62, 45) and (70, 45) mm; "nothing" means nothing brought to front, no pulse, no launch animation, no switcher.

Existing tests touched: the `PersistenceTests` default rows gain `isSwapOn`, `everySettingsFieldSurvivesTheStore` sets it false, and `settingsSavedInTheCurrentFormatStillLoad`'s fixture, which predates the key, doubles as the upgrade proof (its comment says so); `InMemoryTrackpads.run`, the `Fixtures.swift` helpers and the direct recognizer constructions take `swaps`. Every recognizer row that lands fingers before the thumb (`fingersDownBeforeTheThumbNeverFire`, `fingersThatLandedBeforeTheThumbNeverSwipe`, `thumbAndFingerLandingInTheSameFrameNeverFire`, `fingersWithNoThumbInTheCornerNeverBlock`, `aThumbLandingDuringADragLeavesTheDragAlone`) keeps its assertions: none asserts the absence of a swap, and its tap gestures are unaffected by the swap path. Every swipe-exit row with a remembered thumb (`aThumbLandingOnTheExitFrameIsTheAnchorAfterwards`, `afterTheEndOnlyTheThreeSecondRuleBlocks`, `theThumbLiftingAndLandingAgainMidSwipeLeavesTheSwipeGoingAndTheNextTapFires`, `aThirdFingerCancelsOnceAndTheNextTapStillFires`) keeps its assertions: the exit goes to spoiled with that thumb, as today.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R5, R15 | World | Window open, launch animation on (the default). Play the script through the thumb's landing and 50 ms of hold: nothing. Play the thumb's lift: `broughtToFront == [Mail]`, `pulses == [gesture on macBook14]`, `launchAnimations` empty, `switcher` nil, window closed. Play the fingers' lift: nothing more. | R1 "First swap": "Mail comes to the front when the thumb lifts"; R5 "Launch animation on": "the trackpad gives the gesture haptic, the previous app comes to the front, and no icon floats up from the pointer"; R15 "Window open": "the launcher window closes". ("Menu bar app is skipped" is this same read, since the adapter never lists a menu bar app in `apps`: plan 008's `RunningAppsReaderTests`.) |
| T2 | R1 | World | (a) `setHandMode(.left)`; rest; thumb tap at (114.8, 10): `[Mail]`. (b) Right hand; rest; thumb tap at (114.8, 10): nothing. | R1 "Left-hand mode": "Mail comes to the front"; "Tap in the wrong corner": "no app changes and no haptic plays" |
| T3 | R1 | World | (a) Rest; the thumb lands and lifts after 500 ms: nothing. (b) Rest; thumb tap with a 3.5 mm drag: nothing. | R1 "Thumb rests too long", "Thumb drags": "no app changes and no haptic plays" |
| T4 | R1, R9 | World | Access granted. Rest; thumb tap with a firm press (from the frame after its landing to its lift): `[Mail]` and `pressVerdicts == [.drop, .drop]`. | R1 "Thumb presses to click": "Mail comes to the front, and the click does not reach any app, as today's blocking window holds it back" |
| T5 | R2 | World | (a) Bartender, Safari and Mail installed; frontmost Bartender (a menu bar app's window in front, absent from `running`); running Safari, Mail: swap brings Safari. (b) Frontmost nil; running Finder, Safari, Mail: swap brings Finder. | R2: "the first of the running apps, in the order ⌘-Tab shows them, that is not the frontmost app"; "Trackpad Launcher is active": "Finder comes to the front" |
| T6 | R3 | World | One rest, `lift: false`, continued with `play`. Thumb tap: Mail; `activate("Mail")`; thumb tap: Safari; `activate("Safari")`; thumb tap: Mail. `broughtToFront == [Mail, Safari, Mail]`, three gesture pulses. | R3 "Three taps": "Mail, then Safari, then Mail come to the front" |
| T7 | R3 | World | (a) Four thumb taps in one rest within 880 ms, the fake never updated: `[Mail, Safari, Mail, Safari]`. (b) `activate("Mail")` after the first tap only, three more taps in the same rest: the same four. | R3 "Rapid taps": "the front app goes Mail, Safari, Mail, Safari, and Safari ends in front" |
| T8 | R3 | World | (a) Safari, Mail, Notes running, Safari frontmost. Thumb tap: Mail; `makeFrontmost("Mail")`, `makeRunning(["Mail", "Notes"])`; thumb tap in the same rest: Notes. (b) `switcherWorld` plus Calendar installed: thumb tap: Mail; `makeFrontmost("Calendar")`, `makeRunning(["Calendar", "Mail", "Safari", "Slack", "Notes"])`; thumb tap in the same rest: Mail. | R3 "Previous app quits between taps": "the second tap brings Notes to the front"; "Another app activates between taps": "the second tap brings Mail back to the front" |
| T9 | R4 | World | (a) Window open; running Finder only, Finder frontmost; swap: nothing, window still open. (b) Frontmost nil, running empty; swap: nothing. | R4 "Only one app running": "Finder stays in front, and the trackpad gives no haptic" |
| T10 | R6 | World | (a) One finger rests; thumb tap: nothing. (b) Three fingers rest; thumb tap: nothing. (c) An edge contact at (123.8, 45) and two fingers rest from 0 ms; thumb tap at 150 ms: `[Mail]`. | R6 "One resting finger", "Three resting fingers": "no app changes and no haptic plays"; "Palm on the edge does not count": "the swap fires" |
| T11 | R6 | World | `HandFrames`: (a) two fingers land at 0 ms, the thumb lands in the corner at 20 ms and is absent at 100 ms with the fingers down, all absent at 200 ms: `[Mail]`; (b) the fingers and the thumb land in the same frame, the thumb lifts first: nothing. | R6 "Thumb tapped right after the fingers land": "the swap fires"; "Thumb lands together with the fingers": "no app changes and no haptic plays" |
| T12 | R6, R13 | World | (a) Notes on the 2-finger gesture; `tap(2)` (thumb first): `[Notes]`, pulses `[gesture]`. (b) Swipe on; `swipe(3.5, 12)` (thumb first): the switcher showed, Mail through the switcher, pulses `[lightTick, gesture]`. (c) `setSwap(on: false)`, then the same swipe: the same. | R6 "Thumb first is still a tap gesture": "Notes comes to the front; no swap happens"; "Thumb first is still a swipe": "the switcher shows, as today"; R13 "Swap off, swipe on": "the switcher still shows" |
| T13 | R6 | World | Notes on the 2-finger gesture. Rest; the thumb lands and stays 500 ms; the fingers lift; the thumb stays; a two-finger tap: `broughtToFront == [Notes]`, one pulse. | R6 "Held thumb becomes an anchored thumb": "no swap happens, and the 2-finger gesture fires and Notes comes to the front" |
| T14 | R6 | World | `HandFrames`: thumb lands at 0 ms, two fingers land at 100 ms, the thumb is absent at 200 ms with the fingers down, the thumb lands again at 250 ms (150 ms after the fingers, 50 ms after it left) and is absent at 350 ms: `[Mail]`. | R6 "A new thumb landing is judged again": "taps it again in the anchor corner. Mail comes to the front" |
| T15 | R7 | World | Rest; the fingers slide (0, 10) mm; thumb tap: nothing. | R7 "Scrolling then tapping": "no app changes and no haptic plays" |
| T16 | R7 | World | (a) Thumb tap (Mail), `activate("Mail")`; the fingers slide (1, 0) mm; thumb tap: Safari. (b) Thumb tap (Mail), `activate("Mail")`; the fingers slide (2, 0) mm; thumb tap: Safari; `activate("Safari")`; the fingers slide another (2, 0) mm (4 mm from their landing, 2 mm since the last swap); thumb tap: Mail. (c) Thumb tap (Mail), `activate("Mail")`; the fingers slide (10, 0) mm; thumb tap: nothing more; thumb tap again: nothing more; both fingers lift, two land again and rest; thumb tap: Safari. All in one hand each. | R7 "Slight drift between taps": "the apps swap again"; "After the first swap, small drift MUST NOT stop the series. Once either finger moves more than 3 mm from where it was at the last swap"; "Sliding ends the series": "no app changes and no haptic plays, and no thumb tap swaps until both fingers lift and land again" |
| T17 | R8 | World | After a thumb tap (Mail) and `activate("Mail")`, in one hand each: (a) `lift(.first)`, one finger lands again at (62, 45), 150 ms, thumb tap: Safari. (b) Both lift, two land, 150 ms, thumb tap: Safari. (c) A third finger lands at (86, 45); thumb tap: nothing more; the third lifts; thumb tap: nothing more; all lift, two rest again, thumb tap: Safari. | R8 "One finger lifts and lands again", "Both fingers lift": "the apps swap again"; "Third finger lands": "no app changes and no haptic plays, and no thumb tap swaps until no finger rests outside the anchor corner" |
| T18 | R9 | World | Access granted, after a thumb tap (Mail) with the thumb up, in one hand each: (a) wait 5 s, press, the fingers lift: `pressVerdicts == [.drop, .drop]`. (b) The fingers slide (10, 0) mm: `scroll(.fingers(.began)) == .drop`. (c) `lift(.first)`, press, lift: `[.drop, .drop]`. (d) Both lift: `scroll(.fingers(.began)) == .pass`. | R9 "Pressing between taps": "the click does not reach the app in front"; "Drift does not scroll": "the page does not scroll"; "One finger stays down": blocked "as during a swipe"; "Blocking ends when the fingers lift": "the page scrolls" |
| T19 | R1, R9 | World | Access not granted. (a) Rest; thumb tap with a firm press: `[Mail]`, `pressVerdicts` empty (no filter is armed). (b) Thumb tap: `[Mail]`; then press and lift: `pressVerdicts` empty, `isBlockingClicks` false. | R1: "A thumb that presses to click and releases within the tap window MUST count as a thumb tap"; R9 "No Accessibility permission": "Mail comes to the front, and the click reaches Mail" |
| T20 | R8, R9 | Recognizer | `HandFrames`, per-frame event and flags: fingers land at 0 ms; the thumb lands at 150 ms and is absent at 250 ms: `.swap(startsSeries: true)` on that frame; frames at 1000, 3500 and 5000 ms with the fingers down and no thumb: both flags true; the thumb lands at 5200 ms and is absent at 5300 ms: `.swap(startsSeries: false)`; one finger absent at 6000 ms: both flags true; both absent at 7000 ms: both false. | R9: "for the whole series, as during a swipe", "until no finger rests outside the anchor corner"; R8: "The series MUST end when both fingers are up at the same moment" |
| T21 | R1, R6 | Recognizer | Boundaries: the thumb landing 10 ms, 150 ms and 5 s after the fingers each fires a swap; the thumb down 390 ms fires, 410 ms does not; a thumb drag of 2.5 mm fires, 3.5 mm does not. | R6: "both landed in an earlier frame than the thumb, however shortly before"; R1: "The fingers may rest for any length of time", "lifts within the tap window, the same 400 ms as tap gestures'", "does not drag more than 3 mm" (the same 390/410 and 2.5/3.5 pairs as `GestureRecognizerTests`) |
| T22 | R3, R8 | Recognizer | `startsSeries` in order: a rest with two thumb taps: `[true, false]`; both fingers lift, two land again, rest, thumb tap: `true`; one finger lifts and lands again, 150 ms, thumb tap: `false`. | R3 "while the same two fingers stay down"; R8: a lifted finger "MUST rejoin the series", "The series MUST end when both fingers are up at the same moment" |
| T23 | R11 | Recognizer, World | Recognizer with `swaps: false`: rest, thumb tap (120 ms): no event, and both flags true on its down frames (today's thumb-with-finger rules). World: `setSwap(on: false)`, Notes on the 2-finger gesture; rest, thumb tap: nothing; the thumb lands again and stays; the fingers lift; a two-finger tap: `[Notes]`. | R11 "Switched off": "no app changes and no haptic plays"; "nothing beyond today's behaviour" (glossary *Anchored thumb*, *Click blocking*) |
| T24 | R10, R12 | World, store | (a) A fresh World started: `isSwapOn` true and a thumb tap brings Mail. (b) `setSwap(on: false)` then `relaunch()`: false. (c) `everySettingsFieldSurvivesTheStore` with `isSwapOn = false` round-trips. (d) The `savedSettings` fixture (no `isSwapOn` key; left hand, animation off, swipe off, apps on gestures 1, 2 and 5) loads with the swap on, the swipe off, the animation off, left hand and the same rows. (e) A plist literal holding only `<key>isSwapOn</key><false/>` loads with the swap off and every other default. | R10 "Default on": "the switch is on, and a swap works"; "Upgrade": "Thumb tap to swap apps is on, and Swipe to switch apps and Launch animation are still off"; R12 "Survives restart", "Survives force-quit": "the switch is still off"; decision 8's key name, pinned by the literal |
| T25 | R12 | World | `setSwap(on: false)`; rest and thumb tap: nothing. `setSwap(on: true)`; rest and thumb tap in a second World: `[Mail]`. No relaunch. | R12: "A change MUST apply to the next thumb tap" |
| T26 | R13 | World | `setSwipe(on: false)`; rest and thumb tap: `[Mail]`, pulses `[gesture]`. | R13 "Swipe off, swap on": "the previous app comes to the front" |
| T27 | R14 | World | Tap to click on for the built-in trackpad: `hardware.running` empty; rest and thumb tap: nothing; `inject(.swap(SwapEvent(startsSeries: true, trackpad: macBook14)))`: nothing. | R14 "Tap to click is on": "no app changes and no haptic plays" |
| T28 | R9 | Recognizer | Fingers land at 0 ms; the thumb lands at 150 ms and holds: at 200 ms both flags true; at 3200 ms `blocksClicks` false and `blocksDockSwipes` true; the fingers absent at 4000 ms: both false. | R9: "Before the first swap, today's blocking rules MUST apply unchanged" (glossary *Click blocking*: 3 s after the thumb lands, Dock swipes while a thumb is in the corner and another finger is down) |
| T29 | R6 | Recognizer | Rest; the thumb lands at 150 ms and holds; at 400 ms it rolls to (40, 10) mm over 50 ms and stays down: both flags false from the frame it leaves; the fingers lift at 1000 ms; a one-finger tap at 1200 to 1300 ms: no event. Then every contact lifts, the thumb lands at (10, 10) and a one-finger tap: `.one`. | R6: "a thumb that lifts and lands again is judged by its new landing"; glossary *Click blocking*: "while it stays there"; decision 1: a thumb that left the corner is a rest finger until it lifts |

### Verified without a test

None. The window's new switch (R10's placement) and bring to front's Dock-click semantics for a hidden, minimised, windowless or other-Space app (R2) are hardware steps in the slices below; both requirements have test rows for the rest of their text.

## Further Notes

- **A thumb tap is not cancelled by a delivered click, unlike a tap gesture.** Plan 002 made a click that reaches apps cancel a tap gesture: one press, one action. R1 counts a thumb that presses to click as a thumb tap without naming the permission, and R9 wants the swap without it, so a thumb tap fires whatever its press did. With the permission the press is withheld anyway (each thumb landing opens a blocking window). The one visible consequence is the accepted one-frame race: a press reaching the tap before the thumb's landing frame passes to apps and the swap fires too.
- **The swipe reads the order uncorrected.** A swipe begun within an activation's flight, a hundred milliseconds or so after a swap, shows the pre-swap row. The two never overlap (a swipe needs the thumb first), and lifting both fingers to anchor the thumb takes longer than an activation lands. If it ever matters, `SwapSeries`'s correction is the place to share.
- **The correction's blind spot.** Within a series, an app that genuinely comes back to the front by itself (the one the last swap started from) reads like an activation still in flight: the next tap targets what is already in front, a haptic with no visible change, and the tap after that is right again. It needs the from-app to reactivate on its own while the fingers stay down; one dead tap is the cost. An app that quits during its own activation is excluded from the correction, so no dead tap there.
- **The hint does not mention the swap.** No requirement asks for it and the hint is already long. A follow-up can add a clause gated on the swap setting, as the swipe's is.
- **Three fingers before the first swap.** R6 says exactly two fingers at the thumb tap; R8 says a third finger during a series stops it. So three resting fingers of which one lifts can still swap before any swap, and cannot during a series. The asymmetry is the requirements', recorded in decision 4.
- **The stop latch is one per rest.** A finger that moved more than 3 mm, lifted and landed again leaves the rest stopped before any swap, although neither finger now down has moved since it landed. R7's letter would allow the swap; one latch is simpler than one per finger, and the hand that scrolls, lifts one finger and taps the thumb without lifting the other is contrived. Record, not change.
- **Series memory is per model.** Two trackpads with interleaved series would reset each other's memory; harmless and absurd.
- **Cost on the swap path:** one LaunchServices read per thumb tap, 1.4 ms warm (plan 008's probe), and the unchanged bring to front.

## Slices

S1 is a prefactor with no behaviour change: the contact book the fingers-first state needs. S2 lands the swap end to end for one thumb tap at a time, always on, with the documents. S3 adds the switch. S4 adds the series: the rules that bind repeated taps while the fingers stay down, and the stale-order correction for rapid taps. S3 and S4 are independent of each other and need only S2.

### S1: One contact book in the recognizer

**What to build:** No change the user can see. The recognizer records, for every contact down, its landing point and when it was first seen (and whether that was a real landing), in one place; the anchor's landing time, the tap's landing points, the pair's origins and the drag check read from it. Decision 3.

**Blocked by:** None (can start immediately).

**Requirements:** None.

**Test scenarios:** None.

- [ ] Every existing row is green through `Scripts/test.sh`.
- [ ] The anchor, the tap and the pair carry no landing point or time of their own: the book is their only source.

### S2: A thumb tap under two resting fingers swaps apps

**What to build:** From the user's side: with two fingers resting on the trackpad, a thumb tap in the anchor corner brings the previous app to the front, with the gesture haptic, no animation and nothing on screen, and closes the launcher window; tapping again after the app has come forward brings the first app back, and the real order is followed when an app quits or another comes forward between taps; a tap in the wrong corner, a held thumb, a dragging thumb, one or three resting fingers, a thumb landing in the same instant as the fingers, or fingers that scrolled first do nothing, and a held thumb is the anchored thumb once the fingers lift; thumb first is still a gesture or a swipe; with one app running nothing happens; a thumb's press is withheld with the Accessibility permission and the swap still fires without it. Underneath: decisions 1, 2, 4 (the rest's count and drift-from-landing stop; every thumb tap starts a series, so no memory yet), 5 (the pre-series thumb rules), 6 (the event, `swaps:` through the port, both adapters, the helpers and the direct constructions, the model passing `true`), 7 (the model's path with `SwapSeries` targeting on a fresh read, the correction arriving in S4), 10 and 11; the `TouchScript` and `World` helpers; the three documents.

**Blocked by:** S1.

**Requirements:** R1, R2, R3 (taps after the activation landed), R4, R5, R6, R7 (before the first swap), R9 (the rules before the first swap; no permission), R14, R15.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T8, T9, T10, T11, T12 (a and b), T13, T14, T15, T19, T21, T27, T28, T29.

- [ ] Every row is green through `Scripts/test.sh`; the suite stays synchronous.
- [ ] `Launcher.swap(_:)` is the only caller of `SwapSeries.next(in:)`; `reconcile` passes `swaps: true`.
- [ ] On hardware: rest two fingers, tap the thumb in the corner: the previous app comes forward with the haptic and no icon; a second tap after it has settled brings the first app back; the window closes if it was open. Hide Mail, switch to Safari, swap: Mail unhides. Minimise Notes' only window, switch away, swap: it restores. Close every Preview window, switch away, swap: Preview comes forward and opens a window. Put Keynote in full screen on another Space, switch away, swap: the display moves there. Open Trackpad Launcher from Finder and swap at once: Finder comes forward. Left hand: the top-right corner swaps and the top-left does not.
- [ ] `docs/domain-model.md`, `docs/product-overview.md` and `docs/architecture.md` are committed as this plan edited them (the setting and series entries describe S3 and S4, which follow).

### S3: The swap switch

**What to build:** From the user's side: the window's switcher section gains "Thumb tap to swap apps" below the swipe switch, on by default and for upgrades, saved at once so it survives a force-quit, independent of the swipe switch; off, a thumb that lands under resting fingers is an anchored thumb waiting for them to lift, as before, and nothing swaps; on again, the next thumb tap swaps. Underneath: decisions 8 and 9: `Settings.isSwapOn`, `Launcher.isSwapOn` and `setSwap(on:)`, the run record's `swaps` from the setting, the section's second row.

**Blocked by:** S2.

**Requirements:** R10, R11, R12, R13.

**Test scenarios:** T12 (c), T23, T24, T25, T26.

- [ ] Every row is green through `Scripts/test.sh`.
- [ ] `Settings` has `isSwapOn` with its field-name key and absent-means-true decoding; `reconcile` is the only reader of it for `swaps`.
- [ ] On hardware, the window: the switcher section shows the swipe row, then "Thumb tap to swap apps" with a switch at the right end aligned with the other switches and no illustration; off, a thumb landing under resting fingers does nothing, and once the fingers lift with the thumb still down a two-finger tap still fires its gesture; on again, the next thumb tap swaps; the switch survives a force-quit.

### S4: The swap series

**What to build:** From the user's side: while the two fingers stay down, every thumb tap swaps back and forth however fast the user taps, even before the previous app has finished coming forward; a little drift between taps is fine, but a slide ends the swapping until the fingers lift; a finger may lift and land again and the next tap still swaps, both lifting ends the series, and a third finger stops it; from the first swap until the fingers lift, clicks, scrolling and the system's swipes are blocked. Underneath: decision 4's series (the reference reset at each swap, the third-finger stop, `startsSeries` false after the first swap), decision 5's series flags, and decision 7's stale-read correction in `SwapSeries`.

**Blocked by:** S2.

**Requirements:** R3 (rapid taps), R7 (after the first swap), R8, R9 (the series' blocking).

**Test scenarios:** T7, T16, T17, T18, T20, T22.

- [ ] Every row is green through `Scripts/test.sh`.
- [ ] On hardware: with two fingers resting, tap the thumb as fast as you can four or five times: the two apps alternate and the last tap's app ends in front; keep the fingers down after a swap and press: nothing clicks; slide the fingers: nothing scrolls and the next tap does nothing; lift and rest again: the next tap swaps; lift one finger and put it back: the next tap swaps; add a third finger: the next tap does nothing until all lift.
