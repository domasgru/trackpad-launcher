# Plan: Smaller launch icon and launch animation setting

## Problem statement

When a gesture fires, the launch animation shows the target app's icon at the pointer. The icon starts at 60 × 60 points. That is too big for a quick confirmation and draws more attention than it should.

Some users don't want any animation at all. Today the only way to tone it down is the macOS Reduce motion setting, and that affects every app. Even then the icon still fades in place. Trackpad Launcher has no setting to turn the launch animation off.

## Solution

The launch animation icon starts at 40 × 40 points instead of 60. The motion keeps the same shape, scaled down to the smaller icon: it puffs, rises, sways, shrinks and fades as before.

The launcher window gets a **Launch animation** switch below the hand mode toggle. It is on by default. When it is off, no icon appears at the pointer. The haptic pulse and bringing the app to front work as before. The choice is kept across restarts.

## Requirements

### R1. The launch icon starts at 40 points
The animated icon MUST start at 40 × 40 points. It MUST stay sharp on Retina and non-Retina displays throughout the animation.

#### Scenario: Smaller icon on a Retina display
- **GIVEN** the 1-finger gesture is assigned to Notion, the launch animation is on, and the pointer is on a Retina display
- **WHEN** the user makes the 1-finger gesture
- **THEN** Notion's icon appears 40 points square at the pointer, with no blur or pixelation at any point

#### Scenario: Reduce motion on
- **GIVEN** the launch animation is on and macOS Reduce motion is on
- **WHEN** the user makes an assigned gesture
- **THEN** the icon appears 40 points square at the pointer and fades out in place

### R2. The flight scales with the icon
Unless Reduce motion is on, the icon MUST swell to between 110 % and 130 % of its start size (44–52 points). It MUST end between 40 and 53 points above its start, measured at the icon's centre. It MUST end no larger than 60 % of its start size (24 points).

#### Scenario: Scaled-down flight
- **GIVEN** the launch animation is on and Reduce motion is off
- **WHEN** the user makes an assigned gesture
- **THEN** the icon puffs to between 44 and 52 points square, its centre ends 40 to 53 points above where it started, and it ends no larger than 24 points square

### R3. Timing stays the same
The icon MUST be fully invisible between 300 and 400 ms after it appears, with or without Reduce motion.

#### Scenario: Icon is gone on time
- **GIVEN** the launch animation is on
- **WHEN** the user makes an assigned gesture, with Reduce motion either on or off
- **THEN** the icon is fully invisible between 300 and 400 ms after it appeared

### R4. The launcher window has a Launch animation switch
The launcher window MUST show a switch labelled "Launch animation" below the hand mode toggle. The switch MUST show the current state of the setting. Clicking the switch MUST turn the setting on or off.

#### Scenario: Switch is visible
- **WHEN** the user opens the launcher window
- **THEN** a "Launch animation" switch appears below the hand mode toggle, showing whether the animation is on

#### Scenario: Switch shows off
- **GIVEN** the launch animation setting is off
- **WHEN** the user opens the launcher window
- **THEN** the "Launch animation" switch shows off

### R5. The animation is on by default
The launch animation setting MUST be on for a new install. It MUST also be on for a user upgrading from a version without the setting. Adding the setting MUST NOT change any other saved setting.

#### Scenario: Fresh install
- **GIVEN** Trackpad Launcher has never run on this Mac
- **WHEN** the user opens the launcher window
- **THEN** the "Launch animation" switch is on

#### Scenario: Upgrade keeps existing settings
- **GIVEN** a user in Left hand mode with three assigned gestures, on a version without the setting
- **WHEN** they upgrade and open the launcher window
- **THEN** the "Launch animation" switch is on, Left hand mode is kept, and all three assignments are kept

### R6. Turning the animation off hides the launch icon
While the launch animation setting is off, a gesture MUST NOT show the launch icon or any other visual at the pointer, whatever the Reduce motion setting. The haptic pulse, bringing the target app to front and closing the launcher window MUST work as when it is on.

#### Scenario: Animation off
- **GIVEN** the 1-finger gesture is assigned to Arc, Arc is running, the launcher window is open, and the launch animation is off
- **WHEN** the user makes the 1-finger gesture
- **THEN** the trackpad pulses, Arc comes to the front, the launcher window closes, and no icon appears at the pointer

#### Scenario: Animation off, app not running
- **GIVEN** the 1-finger gesture is assigned to Arc, Arc is not running, and the launch animation is off
- **WHEN** the user makes the 1-finger gesture
- **THEN** the trackpad pulses and Arc launches and comes to the front, with no icon

#### Scenario: Animation off with Reduce motion on
- **GIVEN** the launch animation is off and macOS Reduce motion is on
- **WHEN** the user makes an assigned gesture
- **THEN** no icon appears, not even a fade in place

### R7. Changing the setting takes effect at once
A change to the switch MUST apply to the next gesture, with no restart.

#### Scenario: Turn off, then gesture
- **GIVEN** the launch animation is on
- **WHEN** the user turns the switch off, then makes an assigned gesture
- **THEN** no icon appears

#### Scenario: Turn back on
- **GIVEN** the launch animation is off
- **WHEN** the user turns the switch on, then makes an assigned gesture
- **THEN** the icon animates at the pointer

### R8. The setting is kept across restarts
The launch animation setting MUST be saved as soon as the switch changes. It MUST keep its value when Trackpad Launcher quits and starts again, including after a Mac restart.

#### Scenario: Off survives a restart
- **GIVEN** the user turned the launch animation off
- **WHEN** they quit Trackpad Launcher and open it again
- **THEN** the switch is still off, and gestures show no icon

#### Scenario: Off survives a force-quit or Mac restart
- **GIVEN** the user turned the switch off
- **WHEN** Trackpad Launcher is force-quit or the Mac restarts, and it opens again
- **THEN** the switch is still off

## Non-goals

- **A haptic feedback switch.** The user decided the haptic pulse stays always on.
- **Sound.** The product overview asks for a sound with each gesture. That is a separate change.
- **A user-chosen icon size.** One fixed size, 40 points. A size picker adds UI for little gain.
- **Changing the menu bar icon.** Only the launch animation icon gets smaller.
- **Changing the animation's timing or character.** Duration, curves and the puff-rise-sway-fade sequence stay as they are, only scaled to the new size. Sway (at most a third of the rise) and tilt (at most 5 degrees) stay as they are.

## Implementation Decisions

### The setting lives in `Settings`; the model enforces it in `fire`
- `Settings` gains one field, `isLaunchAnimationOn`, a Bool that defaults to true. It is kept in the same single plist record, under the same `UserDefaults` key, as hand mode and the assignments, and its own key inside that record is the field's name, `isLaunchAnimationOn`, which is permanent from the first release that writes it. No new `UserDefaults` key, no second store.
- `Launcher` exposes `isLaunchAnimationOn` (read; observable through the stored settings, exactly as `handMode` is) and the intent `setLaunchAnimation(on:)`. The intent writes the field and saves at once (R8), and does nothing else: no reconcile, no window change, no re-prepare. A call that changes nothing is a no-op, like `setHandMode`.
- `fire` keeps its guard and its four effects in their order. The third, `playLaunchAnimation`, now runs only while the setting is on. The pulse, bring to front and closing the window stay unconditional (R6).
- Because the model decides, nothing below it learns about the setting: the `SystemActions` port, `WorkspaceActions` and the overlay are unchanged. An overlay that is never asked to play shows nothing. Reduce motion is read inside `playLaunchAnimation` (its contract), so with the setting off there is no fade-in-place path left to leak through (R6, "whatever the Reduce motion setting").
- Preparing continues regardless of the setting: `prepareLaunchAnimations` still receives the present assigned apps at start, on an assignment change and when the window opens. This is a performance decision: the first gesture after the switch is turned on then plays a prepared icon instead of rendering one on the main actor (a first render is 45–120 ms, plan 004's probe). Preparing while off costs a few milliseconds off the main actor at those three moments plus a few small bitmaps, and adds no code path. The alternative (prepare only while on, re-prepare on turning on) adds a path and a way to get a cold icon. T14 pins it.
- `Launcher`'s doc comment gains that `fire` plays the launch animation only while its setting is on.
- Two stale comments go with this change: the launcher view's doc comment lists the window's parts and gains the switch; the port's `playLaunchAnimation` comment still says "about 500 ms" and now says about a third of a second (R3). Comments only.

### Older records decode without loss
- Checked while planning (see Further Notes): Swift's synthesized decoder requires every key, defaults notwithstanding. With the new field added and nothing else done, a record a 004 build wrote fails to decode with `keyNotFound`, and `SettingsStore.load()` returns `Settings()`: right hand, no assignments. That breaks R5's upgrade scenario silently.
- Decision: `Settings` gets a hand-written decoding initialiser in which every field missing from the record takes its default (`decodeIfPresent`, else the default), for every field, present and future. Encoding stays synthesized. `LaunchTuning` already decodes this way. The rule, stated in `Settings`' doc comment so later plans see it: a key missing from the record decodes as that field's default; a key the build does not know is ignored (checked while planning: the current decoder already tolerates unknown keys, so a downgrade keeps hand mode and assignments too); a key whose value does not decode (an unknown hand mode, a malformed assignment) still fails the whole record, as today.
- `load()` keeps returning `Settings()`, not a first launch, for a record that fails to decode or is not a plist at all.
- Nothing rewrites the record on load. The first save after an upgrade (any assignment, hand mode or switch change) writes the record whole, with the new key.

### The switch (LauncherUI)
- One new view in the launcher window's upper card, directly beneath the hand mode toggle and above the divider: the text "Launch animation" at the leading edge and a switch-style toggle at the trailing edge, with the card's existing spacing. The toggle keeps "Launch animation" as its accessibility title even though the visible label is laid out separately.
- It reads `isLaunchAnimationOn` and sends `setLaunchAnimation(on:)` through a binding, as the hand mode picker does. No local state.
- A change neither closes the window nor changes its size.

### The icon: two tuning numbers
- `LaunchTuning`'s shipped values change in two places: the icon side 60 → 40, and the rise 70 → 47 (70 × 40 ÷ 60 = 46.7, rounded to whole points, keeping the rise at about 1.17 × the side). Everything else stands: 0.34 s, a 20 % pop over 75 ms, shrink 0.55 and its curve, the fade curve, sway 0.26 per point of rise (so it scales with the rise by itself), tilt 4°.
- What follows, for the record: peak 48 pt (R2's 44–52), end side 21.6 pt (≤ 24), rise 47 pt (40–53), end drift at most 12.2 pt (under a third of the rise), the icon still 21.6 pt when it becomes invisible (above 40 ÷ 3), gone at 340 ms (R3).
- Sharpness (R1) rides on the unchanged mechanism: the bitmap is drawn at the peak side × the display's scale in pixels (now 96 px at 2×, 48 px at 1×) so it is never scaled up, the layer's `contentsScale` is the display's, minification is trilinear, and the start point is rounded to the display's pixel grid. Only the number changes.
- The Debug tuner needs no change; its "Shipped" preset is the new defaults. A Debug build with a tuning saved by the tuner plays that tuning, not the shipped one; the manual checks reset to shipped first.
- No shipped source outside `LaunchTuning` holds 60 or 70. The flight tests hold literals derived from the start size; see Testing.
- The transform keyframes are relative: the flight writes each one's scale as the pose's side ÷ the icon side, so it is 1 at the start, 1.2 at the peak and 0.54 at the end for any icon side. The absolute size travels in the stage's `iconSide`, which the overlay puts in the layer's bounds. A test that reads the side from the transform alone cannot tell a 40-pt icon from a 60-pt one; see Testing for what follows.

### Unchanged
- The ports, `World`, `RecordingSystemActions`, `WorkspaceActions`, `LaunchOverlay`, `LaunchFlight`, the composition root and the source policy. No new port, adapter or seam.

### Docs
- Domain model: *Launch animation* no longer says there is no setting; new term *Launch animation setting*; *Launcher window* lists the switch.
- Architecture: no change. Nothing here crosses a core decision.

## Testing Decisions

### Strategy

Two existing seams, no new one.

1. **`Launcher` through `World`** (LauncherCoreTests): the real model over in-memory adapters, a temp directory of fake app bundles and a throwaway `UserDefaults` suite. Rows read `isLaunchAnimationOn`, `handMode`, `rows`, `isWindowOpen`, the recorder's `launchAnimations` and `broughtToFront`, the fake hardware's `feedback`, `loginItemRegistrations`, and the stored record through a fresh `SettingsStore`. It is synchronous end to end. It proves the default, the upgrade, what a gesture does while the setting is off, immediacy and persistence (R5–R8). It cannot see the view. New rows resemble `LauncherKit/Tests/LauncherCoreTests/PersistenceTests.swift` and `LauncherTests.swift`.
2. **The launch flight** (LauncherPlatformTests, `@testable`): `LaunchFlights.next` → `staged(at:among:)` → the keyframes read back from the three animations, exactly as `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` does today. It proves R2 and R3 against the shipped tuning. It cannot see the overlay or the pixels.

The views have no in-process seam in this repo; the window is checked by eye, as in plans 001, 002 and 004 (R4). Pixels and sharpness likewise (R1).

**Fakes and boundaries.** The trackpad, system-action, accessibility and scanner ports are in memory, as today. The store is the real `SettingsStore` over a throwaway suite. Randomness is the `draw` argument. There is no clock to fake. Everything we own runs for real.

**Upgrade fixture.** The record a 004 build writes for Left hand with Arc, Figma and Notion on gestures 1–3, captured while planning as an XML plist (Further Notes). The test writes it under the store's key in the World's suite, with the World's three bundle URLs substituted for the record's `relative` strings: the record's `lastKnownURL` is how an assignment is found, so with foreign URLs the apps would resolve as missing and the row would prove nothing about them.

**Reading the side.** The existing keyframe helper multiplies the transform's scale by a literal start side. Since the transform is relative (Implementation Decisions), that helper reports the literal at t = 0 whatever `LaunchTuning` says, and would keep every size row green with the icon still at 60. The helper changes to multiply by the stage's `iconSide`, the layer's bounds the overlay sets, so the side it reports is what reaches the screen; the literal 40 then appears only in assertions, and T1 asserts the stage's `iconSide` itself. The corner check in `awayFromTheEdgesNothingOfTheIconIsEverCut` gets the real side from the same change.

**Existing flight rows.** Rows that hold a literal derived from the start size move it to 40: the "clearly larger than a dot" threshold (60 ÷ 3 → 40 ÷ 3) and the Reduce-motion side (every keyframe at the pointer, side 40, rotation 0, plan 004's R15) along with the Reduce-motion half of the first-keyframe row (plan 004's R5). The rows for the fade shape, sway, tilt, the sway streak and the display edges keep their assertions. All of these are the non-goal "character unchanged": they stay green and are not re-listed below.

### Test scenarios

Conventions:
- **World rows** call `start()` before acting. "No animation" means `launchAnimations` is unchanged by the gesture.
- **D** is the set of draws {−1, −0.5, −0.01, 0, 0.01, 0.5, 1}; **both modes** means Reduce motion off and on; **motion** means off. Rows stage at (700, 400) among the built-in (0, 0, 1512, 982 at 2×) and external (−524, 982, 2560, 1440 at 1×) displays, as the existing suite does.
- **Keyframes** are read as the existing suite reads them, except that side is the stage's `iconSide` × √(m11² + m12²) of the transform (the layer's bounds times its scale, which is what the overlay shows); rise and drift are the screen position minus its value at t = 0.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2 | flight | Motion × D. → The stage's `iconSide` is 40. The first keyframe is at (700, 400), side 40, opacity 1, rotation 0. Within the first 100 ms the side never drops below 40; opacity never rises at any step. Retargets the motion half of `iconAppearsAtThePointerAtFullSizeAndFullyOpaqueAndNeverFadesIn`; its Reduce-motion half stays as an existing row. | R2 "between 110 % and 130 % of its start size (44–52 points)": 44–52 is 110–130 % of 40, so 40 is the start size R2's percentages are of. The at-once, no-fade-in part is plan 004's R5, unchanged. |
| T2 | R2 | flight | Motion × D. → The peak side is within 44…52 and comes at or before 100 ms; up to the peak the side strictly grows, the position stays at (700, 400), rotation is 0 and opacity is 1. Retargets `iconPopsInPlaceTo110To130PercentWithinTheFirst100Milliseconds`. | R2 "44–52 points". The in-place, within-100-ms part is plan 004's R16, unchanged. |
| T3 | R2 | flight | Motion × D. → The last keyframe's rise is within 40…53; the rise in the second half of the duration exceeds the rise in the first; after the peak every rise step is larger than the one before. Retargets and renames `iconRisesFasterAndFasterToBetween60And80PointsAboveItsStart` (to "…Between40And53…"). | R2 "40 to 53 points above where it started", at the icon's centre: the position keyframes are the layer's centre. "Faster and faster" is plan 004's R6, unchanged. |
| T4 | R2 | flight | Motion × D. → After the peak the side strictly falls at every step; the last keyframe's side is ≤ 24. Retargets `afterThePopIconShrinksSteadilyToNoMoreThan60PercentOfItsStartSize`. | R2 "no larger than 24 points square". |
| T5 | R3 | flight | Both modes × D. → Each animation's duration is within 0.3…0.4 s; opacity > 0 at every keyframe before 300 ms; the first keyframe with opacity 0 is at or before 400 ms. The existing `iconIsFullyInvisibleBetween300And400Milliseconds`, unchanged, run against the new tuning. | R3 "fully invisible between 300 and 400 ms, with or without Reduce motion". |
| T6 | R5 | World | Nothing stored. `start()`. → `isLaunchAnimationOn` is true, alongside the row's existing expectations. Extends `firstLaunchShowsFreshDefaultsOpensTheWindowAndRegistersTheLoginItem`. | R5 scenario "Fresh install". |
| T7 | R5 | World | Arc, Figma and Notion installed. The upgrade fixture, with the World's URLs, written under the store's key. `relaunch()`, `start()`. → `isLaunchAnimationOn` true; `handMode` left; rows 1–3 present Arc, Figma, Notion; row 4 unassigned; `loginItemRegistrations` 0; window closed. New row in `PersistenceTests`. | R5 scenario "Upgrade keeps existing settings" (Left hand, three assignments, switch on). The fixture is the record the 004 build writes. A stored record is not a first launch, per the store's contract. |
| T8 | R5 | World | After T7's upgrade: `setLaunchAnimation(on: false)`, `relaunch()`. → off; `handMode` left; rows 1–3 still present. | R5 "MUST NOT change any other saved setting": the first save after the upgrade rewrites the record whole, and must carry the old values with it. |
| T9 | R5 | World | Garbage under the store's key. `relaunch()`, `start()`. → `isLaunchAnimationOn` true, alongside the row's existing expectations. Extends `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch`. | R5 "on by default": the fallback record is the defaults, and on is the default. |
| T10 | R5 | World | An empty dictionary plist under the store's key. `relaunch()`, `start()`. → `isLaunchAnimationOn` true; `handMode` right; four rows unassigned; `loginItemRegistrations` 0; window closed. New row in `PersistenceTests`. | R5 "on by default" for a record without the key, in its barest form, and the decoding rule for every field at once: missing keys take their defaults, and a record that decodes is not a first launch (the store's contract). |
| T11 | R6 | World | Arc on 1, window open, `setLaunchAnimation(on: false)`. `tap(1)`. → `feedback == [macBook14]`, `broughtToFront == [Arc]`, window closed, `launchAnimations` empty. New row in `LauncherTests`. | R6 scenario "Animation off". "Animation off, app not running": World apps never run and the model has no running branch, so one row covers both. "Animation off with Reduce motion on": Reduce motion is read only inside `playLaunchAnimation`, which is never called, so no fade-in-place path exists for it to take. |
| T12 | R7 | World | Arc on 1, on. `tap(1)` → `launchAnimations == [Arc]`. `setLaunchAnimation(on: false)`, `tap(1)`. → `launchAnimations` still `[Arc]`; `feedback` has two entries; `broughtToFront == [Arc, Arc]`. No relaunch. | R7 scenario "Turn off, then gesture": the next gesture shows no icon, and the other effects still happen. |
| T13 | R7 | World | Arc on 1, `setLaunchAnimation(on: false)`. `setLaunchAnimation(on: true)`, `tap(1)`. → `launchAnimations == [Arc]`. No relaunch. | R7 scenario "Turn back on". |
| T14 | R7 | World | Arc installed, `setLaunchAnimation(on: false)`. `setAssignment(Arc, for: .one)`. → `preparedLaunchAnimations == [Arc]`; `launchAnimations` empty. New row in `LauncherTests`. | R7 "apply to the next gesture": the icon for that gesture must already be prepared, because play does no slow work only for prepared apps (the port's contract) and a first render costs 45–120 ms on the main actor (plan 004's probe). The decision "preparing continues regardless of the setting". |
| T15 | R8 | World | Arc on 1, `setLaunchAnimation(on: false)` as the last intent. `relaunch()`, `start()` on the new launcher, `tap(1)`. → `isLaunchAnimationOn` false; `feedback` gained an entry; `launchAnimations` empty. New row in `PersistenceTests`. | R8 "saved as soon as the switch changes" and scenario "Off survives a restart": the switch change is the last intent before the relaunch, so only its own save can have stored it, and the relaunched launcher reads the suite through a fresh `UserDefaults` instance, as every persistence row does. Surviving a force-quit or a Mac restart rests on `UserDefaults` keeping a value once `set` returns, which the existing persistence rows already rely on. |

### Verified without a test

Setup for both checks: a Release build, or a Debug build after "Reset to shipped" in the animation tuner (a Debug build plays a tuning the tuner saved, if any). "Recording" means a QuickTime screen recording at 60 fps, stepped frame by frame.

**R1: the launch icon starts at 40 points and stays sharp.**
- Assign Notion to the 1-finger gesture. What is measured: the side of the icon artwork's rounded square, in the recording. macOS app artwork fills about 80 % of its canvas, so a 40-pt icon shows a rounded square of about 32 pt: about 64 px at 2×, about 32 px at 1×.
- (a) Retina, Reduce motion on (System Settings › Accessibility › Display), so the icon does not puff and its first frame is its start size. On the built-in display (2×), record and make the gesture. Expected: on every frame while it is visible, the rounded square is 62–66 px and neither moves, grows nor shrinks; it fades in place; its edges are crisp on every frame.
- (b) Retina, Reduce motion off. Record and make the gesture. Expected: on the first captured frame the rounded square is 64–70 px (the puff may have begun within that frame's 16 ms); it then swells, rises, shrinks and tilts with crisp edges on every frame, no blocky edges or blur.
- (c) Non-Retina. System Settings › Displays › Advanced… › turn on "Show resolutions as list"; back in Displays, turn on "Show all resolutions" and pick a mode marked "(low resolution)", which gives a backing scale of 1 (an external 1× display does as well). Repeat (a) and (b). Expected: 31–33 px in place under Reduce motion, 32–35 px on the first frame otherwise, crisp throughout. Restore the display mode afterwards.
- Why not a test: the size as shown and the sharpness are pixels the process cannot see.

**R4: the launcher window has a Launch animation switch.**
- Open the launcher window from the menu bar icon. Expected: beneath the Left hand / Right hand control and above the divider, a row reading "Launch animation" with a switch, on.
- Click the switch. Expected: it shows off. Close and reopen the window. Expected: it still shows off. Click it. Expected: on.
- With VoiceOver on, or the Accessibility Inspector, focus the switch. Expected: it is announced as "Launch animation", a switch, with its state.
- Why not a test: the repo has no in-process seam for its SwiftUI views, which only render model state and forward intents; this is how the window's other controls were verified in plans 001, 002 and 004. What the switch does to gestures is T11–T13 and is not repeated here.

## Slices

One slice. The tuning change, the setting and the switch are each small, share one test run, and nothing needs sequencing. No prefactoring: the seams exist, and the decoding rule is part of adding the field.

### S1: Smaller launch icon and the Launch animation switch

**What to build:** The launch icon appears 40 points square and flies the same path scaled down. The launcher window shows a "Launch animation" switch beneath the hand mode toggle, on by default and on after an upgrade that keeps every other setting. While it is off, a gesture pulses, brings the app to front and closes the window with nothing at the pointer; a change applies to the next gesture and survives a relaunch.
- `LaunchTuning`'s two shipped numbers.
- `Settings`' new field and its per-field default decoding; `Launcher`'s `isLaunchAnimationOn`, `setLaunchAnimation(on:)` and the condition in `fire`.
- The switch view in the launcher window.
- The World rows and the retargeted flight rows.

**Blocked by:** None (can start immediately).

**Requirements:** R1–R8.

**Test scenarios:** T1–T15.

- [ ] T1–T15 pass through `Scripts/test.sh`; the remaining flight rows stay green, with the keyframe helper reading the stage's `iconSide` and the dot threshold at 40 ÷ 3.
- [ ] `Settings` names the field and key `isLaunchAnimationOn`, and its doc comment states the decoding rule (missing keys default, unknown keys ignored, a bad value fails the record).
- [ ] `fire` skips only the animation while the setting is off; the pulse, bring to front and closing the window stay unconditional.
- [ ] The launcher view's doc comment lists the switch; the port's play comment says about a third of a second.
- [ ] The ports, `World`, `RecordingSystemActions`, `WorkspaceActions`, `LaunchOverlay`, `LaunchFlight` and the composition root are unchanged; the only shipped change in LauncherPlatform is `LaunchTuning`'s two numbers.
- [ ] The switch sits beneath the hand mode toggle, is titled "Launch animation", and binds to the model with no local state.
- [ ] The source-policy test passes; `swift build` and the `xcodebuild` app bundle succeed.
- [ ] The R1 and R4 manual checks are ticked on hardware, R1 (b) on a 1× display mode.

## Further Notes

- **Planning probe.** A throwaway Swift Testing suite in LauncherCoreTests, run through `Scripts/test.sh` and deleted, found:
  - A copy of `Settings` with `isLaunchAnimationOn: Bool = true` added and `Codable` synthesized fails to decode the current record: `keyNotFound … "isLaunchAnimationOn"`. This is why the decoding initialiser is a decision, not a nicety.
  - The current `Settings` decodes a record carrying an unknown key, so a downgrade keeps hand mode and assignments.
  - The record the current build writes for the upgrade scenario, re-encoded as XML (the store writes binary; the decoder reads either). Two URLs carry a trailing slash only because those paths existed on the planning machine; the test substitutes the World's URLs for all three `relative` strings.

    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>assignments</key>
      <dict>
        <key>1</key>
        <dict>
          <key>bundleID</key>
          <dict><key>rawValue</key><string>com.test.arc</string></dict>
          <key>lastKnownURL</key>
          <dict><key>relative</key><string>file:///Applications/Arc.app</string></dict>
          <key>name</key>
          <string>Arc</string>
        </dict>
        <key>2</key>
        <dict>
          <key>bundleID</key>
          <dict><key>rawValue</key><string>com.test.figma</string></dict>
          <key>lastKnownURL</key>
          <dict><key>relative</key><string>file:///Applications/Figma.app/</string></dict>
          <key>name</key>
          <string>Figma</string>
        </dict>
        <key>3</key>
        <dict>
          <key>bundleID</key>
          <dict><key>rawValue</key><string>com.test.notion</string></dict>
          <key>lastKnownURL</key>
          <dict><key>relative</key><string>file:///Applications/Notion.app/</string></dict>
          <key>name</key>
          <string>Notion</string>
        </dict>
      </dict>
      <key>handMode</key>
      <string>left</string>
    </dict>
    </plist>
    ```
- **The tuner's previews** play through the overlay directly and ignore the setting. They are a Debug-only developer tool, not a gesture.
- **Why 47 and not 46.67.** Tuning values are whole points where the eye cannot tell the difference; 47 sits in the middle of R2's 40–53 and keeps the rise-to-side ratio within 1 % of the 004 animation.
- **Sound** (product overview) would be another effect in `fire`, and would get its own switch question then. Out of scope here, as the PRD says.
