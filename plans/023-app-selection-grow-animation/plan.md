# Plan: Pick animation and a per-animation tuner

## Problem statement

When the user picks an app for a gesture in the settings window, the app picker's icon just swaps. Nothing marks the moment, so the pick feels flat next to the lively launch animation and launch bounce.

Debug builds' animation tuner shows every slider for every animation in one long window. To tweak one animation, the developer scrolls past the sliders of all the others. The tuner also forgets which part the developer was tweaking, so each time it opens they scroll back to it.

## Solution

Picking an app plays the **pick animation**: the new icon in the app picker starts small, grows like a balloon a little past its size, and settles back smoothly. It is quick and uses the same fast-start easing as the launch animation's pop.

The animation tuner gets a fourth set of sliders for the pick animation. A control at the top of the tuner chooses one of four tabs: Launch, Bounce, Pick and Swipe. Only that tab's sliders show.

## Requirements

### R1. Picking an app plays the pick animation
When the user picks an app in an app picker, from the menu or through *Other…*, that picker's icon MUST play the pick animation.

#### Scenario: Pick from the menu
- **GIVEN** the settings window is open and gesture 2 has Safari
- **WHEN** the user picks Mail from gesture 2's picker menu
- **THEN** gesture 2's picker shows Mail's icon playing the pick animation

#### Scenario: Pick through Other…
- **WHEN** the user picks an app on disk through *Other…*
- **THEN** that picker shows the chosen app's icon playing the pick animation

#### Scenario: First assignment
- **GIVEN** gesture 3's picker shows "Choose app…"
- **WHEN** the user picks Calendar
- **THEN** Calendar's icon grows from 40% in the spot where it rests, and "Calendar" and the chevron show at once in their final places

#### Scenario: Other… cancelled
- **GIVEN** gesture 2 has Safari
- **WHEN** the user opens *Other…* and cancels
- **THEN** Safari's icon stays, with no animation

### R2. Re-picking the same app plays it again
Picking the app the picker already shows MUST play the pick animation again.

#### Scenario: Same app re-picked
- **GIVEN** gesture 1 has Finder
- **WHEN** the user picks Finder again from gesture 1's picker
- **THEN** Finder's icon plays the pick animation

### R3. Picking None plays nothing
Picking *None* MUST play no animation: the picker shows "Choose app…" at once.

#### Scenario: Unassign
- **GIVEN** gesture 3 has Notes
- **WHEN** the user picks *None*
- **THEN** the picker shows "Choose app…" with no animation

### R4. Only the user's pick plays it
A picker's icon MUST NOT animate when it changes for any reason other than the user's pick in that picker. This includes the settings window opening, a missing app being installed, and the hand-mode toggle. One exception: in Debug builds, the tuner's preview (R14) and preset previews (R16) also play it.

#### Scenario: Window opens
- **GIVEN** gestures 1 to 5 all have apps
- **WHEN** the user opens the settings window
- **THEN** every picker shows its icon at full size, with no animation

#### Scenario: Missing app comes back
- **GIVEN** gesture 4's app is missing and its picker shows the "not found" icon
- **WHEN** the app is installed and the picker shows its real icon
- **THEN** the icon appears with no animation

#### Scenario: Other pickers stay still
- **WHEN** the user picks an app in gesture 2's picker
- **THEN** the other four pickers do not animate

#### Scenario: Hand mode switched
- **WHEN** the user switches hand mode
- **THEN** no picker animates

### R5. Only the icon animates
During the pick animation, only the icon MUST change size. The app's name and the chevron MUST show at once in their final places and not move.

#### Scenario: Name stays put
- **WHEN** the user picks Calendar
- **THEN** "Calendar" and the chevron show at once in their final places while the icon grows

### R6. The pick animation's shape
The pick animation MUST look like this:
- The icon appears at 40% of its side, centred on its slot.
- It grows to 110% of its side in 0.2 seconds, starting fast and slowing down.
- It settles back to 100% by 0.35 seconds after the pick, slowing smoothly into 100%, with no second wobble.
- It is fully opaque throughout.

The grow uses a fixed curve that starts fast and slows down, like the launch animation's pop. The Launch tab's values do not affect it.

#### Scenario: Timing
- **WHEN** the user picks an app
- **THEN** the icon starts at 40% of its side, is at 110% 0.2 s later, and rests at 100% 0.35 s after the pick

### R7. The overshoot is not clipped
At its peak the whole icon MUST be visible. Where it is bigger than its slot, it MUST draw past the slot, uncut at any edge.

#### Scenario: Peak drawn in full
- **WHEN** the icon is at 110% of its side
- **THEN** the whole icon is visible, uncut at any edge

### R8. A new pick restarts the animation
When the user picks an app while that picker's pick animation still plays, the new icon MUST replace the old one at once and play its own pick animation from the start.

#### Scenario: Quick second pick
- **GIVEN** the user picked Mail 0.1 s ago and its icon is still growing
- **WHEN** the user picks Music in the same picker
- **THEN** Music's icon replaces Mail's and grows from 40%

### R9. Reduce motion turns it off
With the system's Reduce motion setting on, picking an app MUST play no animation. The icon MUST swap at once, as it does without this feature.

#### Scenario: Reduce motion on
- **GIVEN** Reduce motion is on in System Settings
- **WHEN** the user picks an app
- **THEN** the new icon shows at once at full size

In Debug builds, the tuner's *Simulate Reduce motion* switch, when on, MUST do the same: picks and the Pick tab's previews play no animation.

#### Scenario: Simulate Reduce motion on
- **GIVEN** the tuner's *Simulate Reduce motion* switch is on
- **WHEN** the user picks an app, or the developer previews the Pick tab
- **THEN** the icons show at once at full size, with no animation

### R10. The launch animation setting does not affect it
The pick animation MUST play whether the *Animate app launch* switch is on or off.

#### Scenario: Launch animation off
- **GIVEN** *Animate app launch* is off
- **WHEN** the user picks an app
- **THEN** the icon plays the pick animation

### R11. The tuner shows one tab at a time
Debug builds' animation tuner MUST show a segmented control at its top with four tabs: Launch, Bounce, Pick and Swipe. The segmented control, the presets, *Reset to shipped* and the preview button (where R14 shows it) MUST show on every tab. Everything else MUST be the chosen tab's.
- Launch: the launch animation's sliders.
- Bounce: the launch bounce's style, sliders and *Preview bounce* switch.
- Pick: the pick animation's sliders.
- Swipe: the switcher swipe's settings.

The *Simulate Reduce motion* switch MUST show on the Launch, Bounce and Pick tabs.

#### Scenario: Switch tab
- **GIVEN** the tuner shows the Launch tab
- **WHEN** the developer picks Pick
- **THEN** the pick animation's sliders and *Simulate Reduce motion* show, with the segmented control, the presets, *Reset to shipped* and *Preview in settings*, and no other tab's sliders show

### R12. The tuner remembers its tab
The tuner MUST open on the tab it last showed, across quits. The first time the tuner opens, with no remembered tab, it MUST show Launch.

#### Scenario: Reopen
- **GIVEN** the developer left the tuner on the Bounce tab and quit
- **WHEN** the tuner opens again
- **THEN** it shows the Bounce tab

#### Scenario: First open
- **GIVEN** the tuner has never opened before
- **WHEN** the developer opens it
- **THEN** it shows the Launch tab

### R13. Pick tab sliders
The Pick tab MUST have a slider each for:
- the start size, as a share of the icon's side
- the peak size, as a share of the icon's side
- the grow time, from the pick to the peak
- the settle time, from the peak to rest

Their shipped values MUST be R6's: 40%, 110%, 0.2 s and 0.15 s. A change MUST apply from the next pick.

#### Scenario: Slower grow
- **WHEN** the developer sets the grow time to 0.5 s and picks an app
- **THEN** the icon takes 0.5 s to reach its peak

### R14. Preview plays the shown tab
The preview button MUST play the shown tab's animation.
- On Launch it reads *Preview at pointer* and plays the launch animation at the pointer, as today.
- On Pick it reads *Preview in settings*. It plays the pick animation on every picker in the open settings window that shows an installed app's icon. Pickers that show the "not found" icon or "Choose app…" do not play it. The button is disabled while the settings window is closed or no picker shows an installed app's icon.
- On Bounce and Swipe it is hidden: Bounce has its own *Preview bounce* switch, and Swipe is not an animation.

#### Scenario: Preview pick
- **GIVEN** the settings window is open with apps on gestures 1, 2 and 4
- **WHEN** the developer clicks *Preview in settings* on the Pick tab
- **THEN** the pickers of gestures 1, 2 and 4 play the pick animation and their assignments do not change

#### Scenario: Settings window closed
- **GIVEN** the settings window is closed
- **WHEN** the tuner shows the Pick tab
- **THEN** *Preview in settings* is disabled

#### Scenario: No apps assigned
- **GIVEN** the settings window is open and every gesture is on *None*
- **WHEN** the tuner shows the Pick tab
- **THEN** *Preview in settings* is disabled

### R15. Reset to shipped resets the shown tab
*Reset to shipped* MUST reset only the shown tab's values to their shipped values. The other tabs MUST keep theirs.

#### Scenario: Reset Pick only
- **GIVEN** the developer changed the launch duration and the pick grow time
- **WHEN** they click *Reset to shipped* on the Pick tab
- **THEN** the pick values are shipped again and the launch duration keeps its change

### R16. Presets cover every tab
Presets MUST stay one shared list, shown under every tab. Saving, updating, loading and previewing a preset MUST cover all four tabs' values together, as today. A preset saved before this feature MUST load with the shipped pick values.

A preset's play button MUST play the shown tab's animation with that preset's values. On Pick it plays on the pickers as R14's *Preview in settings* does, and it is disabled under R14's same conditions. On Bounce and Swipe it is hidden, like the preview button.

#### Scenario: Old preset
- **GIVEN** a preset saved before the Pick tab existed
- **WHEN** the developer loads it
- **THEN** its launch, bounce and swipe values load and the pick values are shipped

## Non-goals

- **Animating the name or the chevron.** They change at once. Text that scales looks unsteady.
- **Animating the window's first appearance or other automatic icon changes.** Only a user's pick is a moment worth marking (R4).
- **A user-facing setting for the pick animation.** It is short and in the settings window only. Reduce motion covers people who want no motion.
- **A Reduce motion alternative such as a fade.** The user chose no animation under Reduce motion (R9).
- **Animating the open menu's icons.** The pick animation plays on the closed picker button only.
- **Haptic or sound on pick.** A pick is a click in a window, not a gesture.

## Implementation Decisions

### D1. The pick animation's shape is one pure value type in `LauncherCore`: `PickAnimation`
- Public, `Equatable`, `Sendable`. Four `Double`s: `startScale` (0.4), `peakScale` (1.1), `growTime` (0.2 s), `settleTime` (0.15 s); `static let shipped`; `duration` = grow + settle; `scale(at:)`, the icon's side as a share of its resting side, so many seconds after the pick; and `keyframes(perSecond:)`, the curve sampled for Core Animation: `duration × perSecond` steps, rounded, at least ten (the launch flight's rule), as key times from 0 to 1 (shares of the duration, Core Animation's convention) and the scale at each. Everything in R6 and R13 is in this type and nowhere else; the view only maps each scale to a transform.
- The curve, from the planning prototype (`.temp/pick-curve-check.swift`): the grow is the launch animation's pop curve, a quadratic ease-out, and the settle is a smoothstep, so both pieces have zero speed at the peak, the turn is smooth and nothing crosses below 100% afterwards (R6 "no second wobble"). A zero grow or settle time is instant.

  ```swift
  func scale(at t: Double) -> Double {
      if t <= 0 { return startScale }
      if t < growTime {                                   // fast start, slowing: the pop's 1 − (1 − p)²
          let p = t / growTime
          return startScale + (peakScale - startScale) * (1 - (1 - p) * (1 - p))
      }
      if t < growTime + settleTime {                      // smoothstep: at rest at the peak and at 100%
          let q = (t - growTime) / settleTime
          return peakScale + (1 - peakScale) * (3 * q * q - 2 * q * q * q)
      }
      return 1
  }
  ```

- It is not `Codable` in Core: nothing a Release build does saves it. The tuner's JSON conformance, missing-or-shipped as the bounce's, lives with the tuner's other Debug-only decoding (D7), so developer tooling stays out of shipping code.
- Why `LauncherCore`: it is pure policy the shell renders, like `SwitcherRowLayout`, `WindowColumnLayout` and `PointerCurve`; it needs only `Double`s, so Core's Foundation-only rule holds; and both the app picker (`LauncherUI`) and the tuner (`LauncherPlatform`) read it, which neither module could do from the other, so one type serves both with no copy. Plan 004 kept the launch flight in `LauncherPlatform` because it renders an adapter's effect in CG geometry, and so that its tests could read the keyframes Core Animation plays; here the geometry is one scale, the sampling is in Core where its tests read it, and the picker's own tests read the keyframes the layer plays (Testing Decisions). Only the wrapping into a `CAKeyframeAnimation` stays in the UI, the one place the picker has QuartzCore.

### D2. The picker draws its icon on a layer of its own, and only that layer animates
- The picker's view becomes layer-backed and owns one icon layer, drawn above the pop-up button over the button's image slot. For a present app, the button's closed item carries a *clear* image of the icon's size and the layer shows the icon; for "Choose app…" and for a missing app the button draws exactly as today and the layer is hidden. The button's layout, its name shortening, its 128 pt cap and its menu's alignment are therefore unchanged: the image slot is still there, only empty.
- The layer's implicit actions are off, so a change of contents or position never animates by itself. The pick animation is the only animation this layer ever plays: a window opening, a missing app coming back, a hand-mode switch, a model render after another picker's pick all go through the ordinary "show the current app" path, which sets contents and plays nothing (R4, R9).
- Its position is the leading 16 pt square of the cell's image rect (the cell reports the slot 3 pt in and 17 × 16 pt for today's spaced image, measured in the planning probe `.temp/picker-seam-probe.swift`, so the icon sits exactly where it draws today), set whenever the closed item changes and on layout; its anchor is its centre, so it grows about its slot's centre (R6 "centred on its slot"); its contents scale follows the window's backing scale; the contents are the picker's icon image, resolved by the layer at that scale. It is a sublayer of the picker's own layer with masking off, so the 110% peak (0.8 pt past a 16 pt slot) draws uncut (R7).
- The representable's make and update bodies become two internal functions that take the coordinator; `makeNSView` and `updateNSView` call them with the context's coordinator, and the picker's tests call the same two with a coordinator they hold, so they run the code SwiftUI runs, minus SwiftUI.
- Why: the pop-up button draws icon and name as one cell, so scaling the button's layer would scale the name and the chevron too (R5), and redrawing the item's image per frame is banned (no code of ours runs per display frame). A layer we own is the one thing Core Animation can scale alone, and keeping the icon on it permanently, rather than only during an animation, means there is one place the icon is drawn and no hand-back when the animation ends.

### D3. The pick animation is one Core Animation keyframe animation on the icon layer's transform
- Built from `PickAnimation.keyframes(perSecond: 240)` (the launch flight's rate): each scale becomes a uniform scale transform, the key times and the duration are the animation's, linear calculation mode, added under one fixed key. The layer's model transform stays identity, so when the animation is removed the icon rests at full size with nothing to clean up, which satisfies the architecture's completion rule with no callback. Only `transform` animates; opacity is never touched (R6 "fully opaque").
- Adding under the same key replaces a running one: a new pick in the same picker shows the new icon and plays from the start (R8). Showing the current app without a pick (a model render, the menu closing) only sets the contents and leaves a running animation alone.
- The picker plays when, and only when, a pick's answer is an entry (D4) and the supplier it was handed (D5) gives it an animation. It reads no system setting itself: Reduce motion, system or simulated, is the supplier's one decision.
- The Launch tab's values are never read: `PickAnimation` carries its own numbers, and only the *shape* of its grow is the pop's (R6).

### D4. The picker decides whether to play from the model's answer to the pick
- `Launcher.setAssignment(_:for:)` returns the gesture's app after the pick when the row shows it present (discardable): the menu's app, or the bundle Other… chose once the catalog has parsed and located it. It returns nil for None, for a bundle that is no app, which the model ignores as today, and for an app the catalog cannot locate, such as one in the Trash picked through Other…, whose row shows "not found", and "not found" never animates (R14's rule for pickers applies to picks too).
- The picker's interface changes to match: `choose: (AppChoice?) -> AppEntry?` and `chooseOther: (@escaping (AppEntry?) -> Void) -> Void`. The gesture row forwards both to the model. The picker plays exactly when the answer is an entry: a menu pick (R1), the same app again (R2), a pick through Other… (R1); None shows "Choose app…" at once (R3); an ignored bundle changes nothing; a cancelled Other… never calls back, so nothing changes (R1).
- Why the answer rather than watching the row change: the same app re-picked changes no row (R2), and a pick through Other… that the model ignores changes no row either, so "did the row change" cannot tell a pick from no pick. The answer can.
- Nothing on this path reads the launch animation setting (R10).

### D5. The shell supplies the pick animation to play
- `LauncherActions` gains `pickAnimation: () -> PickAnimation?`: the animation to play for a pick now, or nil for none. The picker (D3) and the Debug preview (D6) both call it.
- The rule behind it is one pure function on the shell, `pickAnimation(reduceMotion:tuned:)`: nil while `reduceMotion` is true; otherwise the tuned animation when there is one, nil when its Simulate Reduce motion switch is on; otherwise the shipped animation (R9). The shell's closure calls it with `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, read at that moment as the switcher presenters read it, and with the Debug hook's answer. System and simulated Reduce motion are thus decided in one place, and the only line a test cannot reach is the read of the system flag.
- Debug builds only: the shell exposes a hook, `pickTuning: (() -> (animation: PickAnimation, simulateReduceMotion: Bool))?`, that the composition root sets to a read of the tuner's current tuning, which `WorkspaceActions` exposes for the purpose. It is read at every pick and preview, never cached, so a slider change applies from the next pick (R13). Release builds never set the hook and carry none of this.

### D6. Preview in settings (Debug builds only)
- The shell offers `previewPickAnimation()` and `canPreviewPickAnimation`. Preview finds the settings window's picker views and tells each one showing an installed app's icon to play the supplied animation; the "not found" and "Choose app…" pickers play nothing, and no assignment is touched (R14). `canPreviewPickAnimation` is "the window is open and some row shows an installed app's icon", read from the model's observable state so the tuner's button follows it live.
- `WorkspaceActions.showAnimationTuner` takes two more closures, the preview and its availability, which the composition root wires to the shell; the tuner's preview and preset-play buttons on the Pick tab call them.
- Why a view walk rather than a token through the views: the preview is a developer tool, so all of it stays inside `#if DEBUG` in the shell, and the shipping views carry nothing for it.

### D7. The tuner shows one tab at a time
- A `TunerTab` enum (Launch, Bounce, Pick, Swipe). The tuner model holds the chosen tab and persists it in user defaults as `AnimationTuner.tab`, beside the tuner's existing keys; with nothing saved it is Launch (R12).
- The tuner view: a segmented control at the top bound to the tab; below it only the tab's sections. Launch: the flight's sliders. Bounce: the style picker, its sliders and *Preview bounce*. Pick: the four pick sliders. Swipe: the three swipe settings. *Simulate Reduce motion* shows on Launch, Bounce and Pick. The presets section shows on every tab. The bottom bar: *Reset to shipped* on every tab; the preview button reads *Preview at pointer* on Launch and plays the launch animation, *Preview in settings* on Pick, disabled while `canPreviewPickAnimation` is false, and is hidden on Bounce and Swipe (R11, R14). Each preset's play button follows the same rule per tab (R16). Leaving the Bounce tab ends a running bounce preview and turns *Preview bounce* off, so the switch never shows on with nothing bouncing. The window's title follows the docs' name for the tool, "Animation tuner".
- `LaunchTuning` gains `pick: PickAnimation`. Its JSON conformance is declared here, in the tuner's Debug-only block beside the bounce's, as a retroactive conformance of the Core type, decoding missing-or-shipped field by field as the bounce does (R16). The Pick tab's sliders bind to its four fields: *Start size* 0.1…1 and *Peak size* 1…1.6 as shares of the icon's side, *Grow time* and *Settle time* 0.05…1 s, each with the existing per-knob "back to shipped" button (R13).
- `LaunchTuning` gains a pure `resettingToShipped(_ tab:)`: the shipped values for that tab's fields only. The partition: Launch is the fourteen flight knobs (icon size, duration, pop size and time, rise and curve, shrink and curve, fade curve, the three sway knobs, tilt and curve); Bounce is the bounce; Pick is the pick animation; Swipe is the three swipe settings. *Simulate Reduce motion* belongs to no tab and is never reset by the button (R15). The button keeps the selected preset, which then shows as modified when it differs; the Shipped row's *Load* still loads the whole shipped tuning, like loading any preset (R16).
- Saving, updating and loading a preset keep covering the whole tuning, as today; `isModified` is unchanged. Previewing a preset, on any tab, swaps its values in with *Simulate Reduce motion* as it is now rather than as the preset saved it: the switch belongs to no tab, and with it on no preview animates, a preset's included (R9).

### D8. Docs
- `docs/domain-model.md` gains *Pick animation*, and *App picker* names it. `docs/architecture.md`'s developer-tools sentence names the pick animation and the Debug-only hook through which the settings window reads the tuner. Both are updated by planning; the slices check the code against them.

## Testing Decisions

### Strategy

Five seams: three existing, and two in one new test target over the existing `LauncherUI` module; all synchronous; nothing we own faked:

- **`PickAnimation` directly**, in `LauncherCoreTests`, as `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift` and `PointerCurveTests.swift` test Core's pure presentation types. The rows read `keyframes(perSecond: 240)`, the very samples the layer will play, and `scale(at:)`, and assert the requirement's literals and bounds, never the formula, as `LauncherKit/Tests/LauncherPlatformTests/BounceStagingTests.swift` reads the bounce's samples. This proves every number and the shape of R6 and R13. It misses the layer and what is on screen.
- **`World` over the real `Launcher`**, in `LauncherCoreTests`, as `LauncherKit/Tests/LauncherCoreTests/AppResolutionTests.swift` drives `setAssignment` with fake bundles in a temp folder (an Other… pick is a URL there; a text file stands in for a bundle that is no app; a bundle under a `.Trash` folder for one the catalog will not locate). This proves the model's answer, which is what the picker acts on (R1, R2, R3). It misses the picker.
- **The picker, driven as SwiftUI drives it**, in a new `LauncherUITests` target with `@testable import LauncherUI`. A test builds an `AppPicker` with closures it controls: two distinguishable icon images; a `choose` that answers as the model would and records its calls; a `chooseOther` that captures the completion; a `pickAnimation` supplier answering `.shipped` or nil. It makes a `Coordinator`, calls the representable's make and update (D2), picks through the real menu by having the coordinator build it (`menuNeedsUpdate`) and firing the chosen item's action at its target (the planning probe showed `performActionForItem` needs a running application and the action itself does not), and lays the view out (`layoutSubtreeIfNeeded`) where it reads frames. It then reads the icon layer: hidden, contents, anchor, opacity, `animationKeys()`, and the transform keyframes of its one animation, read back as `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` reads a stage's. This proves R1–R5, R8, R9 and the layer half of R6. It misses SwiftUI's two forwarding calls, pixels and clipping by ancestors.
- **`SettingsShell.pickAnimation(reduceMotion:tuned:)` directly**, in the same target. This proves the Reduce motion rule (R9). It misses the one-line read of the system flag.
- **`LaunchTuning` directly**, in `LauncherPlatformTests` through `@testable import`, as `LauncherKit/Tests/LauncherPlatformTests/TunerCodingTests.swift` tests the tuner's JSON. This proves the per-tab reset (R15) and that old saves load with the shipped pick values (R16). These are Debug-only and `swift test` builds Debug.

Faked: nothing of ours. `World`'s temp folder and throwaway defaults stand in for the disk and the user's settings as they already do. The picker tests hand the picker a scripted answer and a scripted supplier, which are the same two closures the gesture row and the shell hand it in the app. No clock is needed: the curve is a function of time, and a keyframe animation is read, not watched.

Why a new test target: the picker holds most of this feature's behaviour, and without the target R1–R5, R8 and R9 would rest on hand checks. The package already holds every library and test target; this is one more entry, with the module's main-actor default isolation.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R6 | `PickAnimation` | Given the shipped pick animation. Then `scale(at: 0) == 0.4`, `scale(at: 0.2) == 1.1`, `scale(at: 0.35) == 1.0` and `duration == 0.35`. `keyframes(perSecond: 240)` has 85 key times, evenly spaced from 0 to 1, and 85 scales: the first is 0.4; the one whose time (key time × duration) is within 1e-9 of 0.2 s is 1.1 and is the largest; the last is 1.0; every scale up to it rises on the one before and every scale after it falls on the one before; none after the peak is below 1.0 and none anywhere is above 1.1. The scale at 0.1 s is 0.925, three quarters of the way from 0.4 to 1.1, so the grow starts fast and slows. The drop over the last step before 0.35 s is under a quarter of the largest drop in the settle, so it slows into 100% (the smoothstep gives about a twentieth; a linear settle would give the same drop every step). | R6's literals 40%, 110%, 0.2 s, 0.35 s, "slowing smoothly into 100%", "no second wobble"; the pop's curve `1 − (1 − p)²` in the launch flight, which puts three quarters of the grow in its first half; the prototype's output |
| T2 | R13 | `PickAnimation` | Then `.shipped == PickAnimation(startScale: 0.4, peakScale: 1.1, growTime: 0.2, settleTime: 0.15)`. Then, one knob at a time with the other three shipped, on `keyframes(perSecond: 240)` with times compared within 1e-9: grow time 0.5 puts the largest scale, 1.1, at 0.5 s and 1.0 at 0.65 s, the first scale still 0.4; start size 0.2 makes the first scale 0.2, the largest still 1.1 at 0.2 s, 1.0 at 0.35 s; peak size 1.3 makes the largest scale 1.3 at 0.2 s, the first still 0.4, 1.0 at 0.35 s; settle time 0.3 keeps the first at 0.4 and the largest, 1.1, at 0.2 s, and the scale first reaches 1.0 at 0.5 s, still above 1.0 at 0.49 s. | R13's shipped values and its "Slower grow" scenario; the values the row sets |
| T3 | R1, R2, R3 | `World` | Given Figma and Mail installed, Sketch installed in Downloads, Pages installed under a `.Trash` folder, a `Notes.txt` in Downloads, and gesture 2 on Figma. When `setAssignment(.app(Mail), for: .two)`: it returns Mail and the row shows Mail. When `.app(Mail)` again: it returns Mail, the row unchanged. When `.appBundle(at: Sketch)`: it returns Sketch's entry and the row shows Sketch. When `.appBundle(at: Notes.txt)`: it returns nil and the row still shows Sketch. When `.appBundle(at: Pages)`: it returns nil and the row shows Pages as "not found". When `nil`: it returns nil and the row is unassigned. | R1 scenarios "Pick from the menu", "Pick through Other…"; R2 "Same app re-picked"; R3 "Unassign"; D4; `AppResolutionTests`' fixture |
| T4 | R16 | `TuningPreset` decoding | Given the preset JSON saved on this Mac by the current tuner (launch, bounce and swipe keys, no pick), copied verbatim from the app's defaults as the existing fixture was, and the existing fixture from before the bounce. When decoded. Then every saved knob equals the fixture's value and `pick == .shipped` in both. | The fixtures; R16 scenario "Old preset" |
| T5 | R16 | `LaunchTuning` coding | Given a tuning with every pick field away from shipped, inside a preset list. When encoded and decoded. Then it is equal; a forgotten decode line goes red. Given JSON whose `pick` object holds only `growTime: 0.5`. Then grow time is 0.5 and the other three are shipped. | The values the row sets; R16 "load with the shipped pick values" |
| T6 | R15 | `LaunchTuning.resettingToShipped` | Given a tuning with every field away from shipped: each of the fourteen flight knobs, every bounce field, every pick field, the three swipe settings, Simulate Reduce motion on. When reset for Pick: the pick animation is shipped and every other field keeps its value. When reset for Launch: the fourteen flight knobs are shipped and the bounce, pick, swipe fields and Simulate Reduce motion keep theirs. When reset for Bounce: only the bounce is shipped. When reset for Swipe: only the three swipe settings are shipped. | R15 scenario "Reset Pick only"; D7's partition |
| T7 | R1, R6 | picker | Given a picker showing Safari, the supplier answering `.shipped`. When Mail is picked from the menu. Then `choose` was called once, with `.app(Mail)`; the closed item is titled "Mail" and its image has the spaced icon's size and is not Mail's icon; the icon layer is unhidden, its contents Mail's icon, its anchor (0.5, 0.5), its opacity 1, its model transform identity; its animation keys are exactly the pick key; that animation is a transform keyframe animation, duration 0.35, whose key times and scales equal `PickAnimation.shipped.keyframes(perSecond: 240)` (0.4 first, 1.1 at 0.2 s, 1.0 last); the button's layer and the badge's carry no animation. | R1 "Pick from the menu"; R6 "centred on its slot", "fully opaque", the timing; D3 |
| T8 | R1 | picker | Given Safari shown. When "Other…" is picked from the menu. Then `chooseOther` was called once and handed a completion, and the picker shows Safari with no animation on any layer. When the completion is called with Calendar: the title is "Calendar", the layer shows Calendar's icon with the pick animation as T7 has it. In a second run the completion is never called: Safari stays and no layer carries an animation. In a third it is called with nil: nothing changes and no layer carries an animation. | R1 "Pick through Other…", "Other… cancelled"; D4 |
| T9 | R1, R5 | picker | Given a picker showing "Choose app…", its layer hidden. When Calendar is picked. Then the title is "Calendar" at once and the layer is unhidden and plays as T7 has it. After layout, the button's frame, the badge's frame and the picker's intrinsic size equal those of a second picker made and updated with Calendar as its current app and never picked in, so the name and the chevron are in their final places from the first frame; the button's layer and the badge's carry no animation. | R1 "First assignment"; R5 "Name stays put" |
| T10 | R2 | picker | Given Finder shown, picked once, and the test has removed the layer's animations. When Finder is picked again from the menu. Then `choose` was called with `.app(Finder)` and the layer carries the pick animation again, as T7 has it, with Finder's icon. | R2 "Same app re-picked" |
| T11 | R3 | picker | Given Notes shown. When "None" is picked. Then `choose` was called once, with nil; the title is "Choose app…"; the layer is hidden; no layer carries an animation. | R3 "Unassign" |
| T12 | R4 | picker | Given Safari shown with its animations removed. When update runs with Mail as the current app (another picker's pick, rendered); then with `.missing("Mail")`; then with Mail present again (installed again); then with Safari again; then with the same current app and a different installed-apps list (a scan). Then after each the layer's hidden state and contents follow the current app (hidden for "not found", Mail's icon for Mail) and no layer carries an animation at any point. | R4 scenarios "Window opens" and "Hand mode switched" (both are renders), "Missing app comes back", "Other pickers stay still" |
| T13 | R8 | picker | Given Mail just picked, its animation on the layer. When Music is picked at once. Then the layer's contents is Music's icon, its animation keys are exactly the pick key, and that animation's scales are the full shipped keyframes from 0.4, so the new pick plays from the start rather than continuing. | R8 "Quick second pick"; D3 |
| T14 | R9 | picker | Given the supplier answering nil. When Mail is picked from the menu, and, in a second run, an Other… completion delivers Calendar. Then the title and the layer's contents change at once and no layer carries an animation. | R9 "the new icon shows at once at full size" |
| T15 | R9 | `SettingsShell.pickAnimation(reduceMotion:tuned:)` | `(false, nil)` gives `.shipped`; `(true, nil)` gives nil; `(false, (custom, simulate: false))` gives `custom`; `(false, (custom, simulate: true))` gives nil; `(true, (custom, simulate: false))` gives nil. | R9: the system setting and the tuner's switch each turn it off; D5 |

### Verified without a test

Every manual check runs on a Debug build with the tuner on *Reset to shipped* on every tab unless the step says otherwise. What is left here is what no seam can see: clipping by the picker's ancestors, and the Debug tuner's window, whose model writes the developer's own defaults.

- **R7 (manual and review).** Set the tuner's peak size to 1.6 and grow time to 1 s, pick an app: the whole icon is visible past its slot on every side, uncut, including over the name's side. Back at shipped, pick again: the 110% peak is visibly whole. Review: the picker's layer and the icon layer have masking off.
- **R10 (manual and grep).** Turn *Animate app launch* off, pick an app: the pick animation plays. A grep shows the picker, the gesture row and the shell's supplier read no launch animation setting.
- **R11 (manual).** The tuner opens with a four-segment control at its top. On each tab only that tab's sliders show: Launch the flight's, Bounce the style picker, its sliders and *Preview bounce*, Pick four sliders, Swipe three settings. *Simulate Reduce motion* shows on Launch, Bounce and Pick and not on Swipe. The presets section and *Reset to shipped* show on every tab; the bottom-right button reads *Preview at pointer* on Launch and *Preview in settings* on Pick, and is absent on Bounce and Swipe. Turn *Preview bounce* on and switch to Pick: the bounce ends; back on Bounce the switch is off.
- **R12 (manual).** Choose Bounce, press *Quit Trackpad Launcher*, open the app again: the tuner shows Bounce. Run `defaults delete com.domasgru.TrackpadLauncherApp AnimationTuner.tab`, quit and open again: Launch.
- **R14 (manual).** With gestures 1, 2 and 4 assigned, gesture 3 on *None* and gesture 5 on a missing app, click *Preview in settings* on the Pick tab: the pickers of 1, 2 and 4 play, 3 and 5 do not, and reopening each menu shows the same app checked. Click a preset's play button on the Pick tab: the same pickers play with that preset's values, and *Current* does not change. Close the settings window: both buttons are disabled; reopen it with every gesture on *None*: disabled; assign one app: enabled.

## Slices

### S1: Picking an app grows its icon into place

**What to build:** Picking an app in an app picker, from the menu or through Other…, the same app included, plays the pick animation on that picker's icon: from 40% to 110% in 0.2 s and back to 100% by 0.35 s, the icon alone, uncut, restarted by a quicker second pick, skipped under Reduce motion, whatever the launch animation setting. Nothing else that changes an icon animates. Release builds ship this with the shipped values and no tuner involvement. The picker gets its own test target.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9, R10; R13 in part: the four knobs shape the curve as named (the sliders are S2's).

**Test scenarios:** T1, T2, T3, T7, T8, T9, T10, T11, T12, T13, T14, T15.

- [ ] `PickAnimation` in `LauncherCore` as D1 describes: the shipped values, the curve, `keyframes(perSecond:)`, no `Codable`, and a doc comment naming the glossary term.
- [ ] `Launcher.setAssignment(_:for:)` returns the row's present app or nil (D4); every existing caller compiles unchanged and the suite stays green.
- [ ] The picker owns its icon layer on the leading 16 pt square of the button's image slot, the slot holding a clear image (D2); its make and update are two internal functions the representable forwards to (D2); it plays the keyframes on a pick's answer when the supplier gives an animation and reads no system setting (D3); its `choose` / `chooseOther` carry the answer (D4). The gesture row forwards both and hands it the supplier.
- [ ] `LauncherActions.pickAnimation`, the shell's pure `pickAnimation(reduceMotion:tuned:)` and the closure over it (D5); the Debug hook exists on the shell but nothing sets it yet.
- [ ] A `LauncherUITests` target in the package, with the picker rows and T15 green under `swift test`.
- [ ] The manual check for R10 passes; and by feel, at shipped values: a menu pick, an Other… pick and a re-pick of the same app each grow the icon into place; *None* and a cancelled Other… play nothing; reopening the window and switching the thumb move nothing; under System Settings' Reduce motion a pick swaps at once.
- [ ] The code matches `docs/domain-model.md`'s *Pick animation* and *App picker* entries, which planning updated.
- [ ] `swift build -c release` builds and a grep shows the shell's hook inside `#if DEBUG`.

### S2: The tuner shows one tab at a time and tunes the pick animation

**What to build:** The Debug tuner opens on the tab it last showed (Launch the first time) with a segmented control for Launch, Bounce, Pick and Swipe and only that tab's sliders below it. The Pick tab's four sliders shape the next pick; *Preview in settings* plays the pick animation on the open settings window's pickers; *Reset to shipped* resets the shown tab alone; presets cover every tab and old ones load with the shipped pick values.

**Blocked by:** S1.

**Requirements:** R11, R12, R13 (the sliders and that a change applies from the next pick), R14, R15, R16.

**Test scenarios:** T4, T5, T6.

- [ ] `LaunchTuning.pick`, the Debug-only retroactive `Codable` for `PickAnimation` decoding missing-or-shipped, and `resettingToShipped(_:)` with D7's partition. T4's new fixture is the preset JSON saved on this Mac, copied verbatim; the existing before-the-bounce fixture also asserts `pick == .shipped`.
- [ ] `TunerTab`, the tab persisted as `AnimationTuner.tab`, the tabbed view, the per-tab bottom bar and preset play buttons, the Pick tab's sliders, previews that keep the current *Simulate Reduce motion*, and *Preview bounce* ending and turning off when the Bounce tab is left, as D7 describes; the window is titled "Animation tuner".
- [ ] `WorkspaceActions` exposes the tuner's current pick tuning and takes the preview closures; the shell's `previewPickAnimation()` and `canPreviewPickAnimation` exist (D6); the composition root wires the hook and the closures.
- [ ] The manual checks for R7, R11, R12 and R14 pass; and by feel: grow time 0.5 s applies from the next pick; with grow time 1 s, a pick of Mail then Music within the second shows Music growing from small, and the name and chevron never move; with *Simulate Reduce motion* on, a pick, *Preview in settings* and a preset's play button all change nothing on screen.
- [ ] The code matches `docs/architecture.md`'s developer-tools sentence, which planning updated; `swift build -c release` builds and a grep shows every new tuner symbol, the hook's wiring and the pick decoding inside `#if DEBUG`.

## Further Notes

- The planning probe `.temp/picker-seam-probe.swift` measured, in a plain process with no window and no running application: an arrowless, borderless pop-up button's cell reports its image rect at (3, 0, 17 × 16) for today's spaced icon and its title rect 24 pt in; `NSMenu.performActionForItem(at:)` does nothing while `NSApp` is nil, while sending the item's action to its target works; a layer's keyframe animation reads back with its duration and values, and adding under the same key leaves one key. The picker tests therefore fire the item's action at its target.
- `NSView.clipsToBounds` defaults to false since macOS 14, and the picker's own layers have masking off, so the overshoot should draw. If R7's check shows a cut, the clipping ancestor is SwiftUI's host view for the representable, and the fix is for the picker view to turn `clipsToBounds` off on that ancestor when it joins a window, not to shrink the animation.
- Core Animation's keyframe interpolation between 1/240 s samples is linear, as for the launch flight and the bounce; at 60–120 Hz the eye sees the curve.
- The planning prototype `.temp/pick-curve-check.swift` produced T1's and T2's literals; the key times come out as `i / 84 × 0.35`, so 0.2 s is 0.19999999999999998 and the rows compare times within 1e-9.

## Follow-up: the native pop-up

After S1 and S2, review in the running app found the picker unlike System Settings' pop-up: no hover bezel, a chevron badge that ignored clicks, a bold chevron and a medium name, a menu that opened at its top, a button that grew past the window for a moment after a pick, and the picked icon shown at full size before the pick animation. The picker is rebuilt on the system's control, changing only what the product asks for. This supersedes D2's layout (the arrowless borderless button, the badge view, the 1 pt spaced image) and S1's "menu opens at its top".

Probed on macOS 26.6 (`.temp/popup-probe/`):
- System Settings' pop-up (SwiftUI's menu `Picker` in a grouped `Form`) is a plain bordered `NSPopUpButton`, push bezel, regular size, 13 pt regular, native arrows. Its look (chevrons in a round badge, bezel on hover) comes from AppKit's semantic context 8, inherited from the Form: the cell then resolves button style 10 with rollover. No public bezel style, border shape or control size reaches it. SwiftUI's `Picker` itself cannot be the picker: outside a grouped Form it is the plain capsule and builds every item up front, its label is flattened into a menu item so nothing in it animates, and the icon-to-name gap is fixed.
- The picker sets the context on its button through AppKit's private `_setSemanticContext:`, guarded by `responds(to:)`; without it the button keeps the standard bordered look and works the same. Chosen by the human over hosting the gesture groups in a SwiftUI Form, which would re-tune the window's measured layout.
- The cell draws a display item of the picker's own (`usesItemFromMenu = false`): the button's size follows it even with 60 items in the menu, and a native pick leaves it alone, so the button never draws the picked item's icon before the picker shows the pick and plays the animation. The item's image is a clear 20 × 16 slot (the icon plus 4 pt; the button's own gap is 2 pt, so 6 pt from icon to the name's text box); the cell's image rect matched the drawn icon to the pixel, so the icon layer sits on its leading 16 pt square, in a non-interactive view above the button's drawing.
- AppKit places the menu from the selection before it asks the delegate for items, so the menu is built, with the row's app selected and checked, whenever the row's app or the list changes, and again in `menuNeedsUpdate` for icons drawn since (0.3 ms for 61 items).
- The content sits 12 pt inside the frame on the left (the hover bezel's padding) and the badge ends 3.5 pt from the right, so the frame cap is 128 + 12 + 3.5 = 143.5 pt for the same 128 pt of content.
- Native truncation leaves an oversized gap before the badge, so the picker keeps shortening the name itself.

Tests: `RealMenuTests` open the real menu by AppKit's own tracking in a window and pick from it: the menu opens reaching 400+ pt above the button for a row app 40 items down; at the moment the menu sends its action the button draws a clear slot, and right after it the icon layer shows the pick growing from 40%; the button and everything drawing it stay within the cap; the button is bordered with native arrows, resolves style 10 with rollover, uses the system font, and clicks on its chevrons, icon and name land on it. All but the width check failed on the previous picker. `PickerDemo` (run with `PICKER_DEMO=1`) shows the picker on screen with the Mac's apps for a screen recording.
