# Grounding: the Debug animation tuner and LaunchTuning

Angle: `LaunchTuning`, how shipped vs. live values reach the overlay, the SwiftUI tuner window, presets persistence,
backward compatibility, `#if DEBUG` boundaries, tests, and where a "launch bounce" section would slot in.
All paths are relative to the worktree root
`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/017-launch-wait-bounce/`.

## Components Found

| Name | File | What it is |
|---|---|---|
| `LaunchTuning` (struct, internal, `Equatable, Sendable`) | `LauncherKit/Sources/LauncherPlatform/LaunchTuning.swift:6-54` | One value holding every launch-flight number plus three switcher-swipe knobs; its memberwise defaults ARE the shipped animation. |
| `LaunchTuning.shipped` | `LaunchTuning.swift:46` `static let shipped = LaunchTuning()` | The default-initialised value; the only tuning Release reads. |
| `LaunchTuning.current` | `LaunchTuning.swift:48-53` | `#if DEBUG` reads `tunerOverride.withLock { $0 }`; `#else` returns `shipped`. The single read point for consumers. |
| `extension LaunchTuning: Codable` (DEBUG only) | `LaunchTuning.swift:56-86` | Hand-written `init(from:)` using `decodeIfPresent ?? shipped.<field>` per key; `encode(to:)` and `CodingKeys` are compiler-synthesised. |
| `tunerOverride` | `LauncherKit/Sources/LauncherPlatform/AnimationTuner.swift:9` `let tunerOverride = Mutex(LaunchTuning.shipped)` | Module-level global (DEBUG only), a `Synchronization.Mutex`; the shared mutable store flights read in Debug. |
| `AnimationTuner` (`@MainActor final class`) | `AnimationTuner.swift:14-38` | Owns the floating `NSPanel` hosting the SwiftUI `TunerView`; `init(preview: @escaping @MainActor () -> Void)`, `show()`. |
| `TunerPanel` (private `NSPanel` subclass) | `AnimationTuner.swift:42-53` | `canBecomeKey/Main = true`; on `leftMouseDown` calls `NSApp.activate()` + `makeKey()` so the preset-name TextField can take typing in an LSUIElement app. |
| `TuningPreset` | `AnimationTuner.swift:55-59` | `struct TuningPreset: Codable, Identifiable, Equatable { var name: String; var tuning: LaunchTuning; var id: String { name } }` (synthesised Codable; nests LaunchTuning's tolerant decoder). |
| `TunerModel` (`@MainActor @Observable final class`) | `AnimationTuner.swift:61-147` | Holds the live `tuning`, `presets`, `selected`, `newName`; persists to `UserDefaults.standard`; writes `tunerOverride` on every change. |
| `TunerView` (SwiftUI `View`) | `AnimationTuner.swift:149-286` | `Form(.grouped)` of Sections built from a private `knob(...)` helper, toggles, presets section, and a bottom bar with "Reset to shipped" and "Preview at pointer". |
| `WorkspaceActions.showAnimationTuner()` (DEBUG, public) | `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift:41-55` | Lazily builds the `AnimationTuner` with a preview closure that plays Finder's icon through the real `LaunchOverlay`, then shows it. |
| `LaunchOverlay` | `LauncherKit/Sources/LauncherPlatform/LaunchOverlay.swift` | Plays the flight; reads `LaunchTuning.current.forceReduceMotion` (line 38) and, via `LaunchFlight`, all flight numbers. |
| `LaunchFlight` / `LaunchFlights` | `LauncherKit/Sources/LauncherPlatform/LaunchFlight.swift` | Computes poses/keyframes; every number via `LaunchTuning.current` (lines 63-73, 84). |
| `CursorTravel.travel(curves:)` | `LauncherKit/Sources/LauncherPlatform/CursorTravel.swift:37-43` | Reads `LaunchTuning.current` swipe knobs at each swipe start. |
| `WindowSwitcherLook` | `LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift:5-16` | Precedent of a separate "shipped look" value struct (`static let shipped`), explicitly modelled on `LaunchTuning` but NOT wired to any tuner (no Debug override). |

## LaunchTuning fields (all with defaults = shipped), `LaunchTuning.swift`

| Line | Field | Type | Default | Tuner control (AnimationTuner.swift line, range, step, unit) |
|---|---|---|---|---|
| 8 | `iconSide` | Double | 60 | 157 slider 16...128 step 1 "pt" |
| 10 | `duration` | Double | 0.34 | 158 0.1...2 step 0.01 "s" |
| 12 | `popSize` | Double | 0.2 | 161 0...0.6 step 0.01 |
| 15 | `popTime` | Double | 0.075 | 162 0.005...0.15 step 0.005 "s" |
| 17 | `rise` | Double | 70 | 165 0...200 step 1 "pt" |
| 19 | `riseCurve` | Double | 1.8 | 166 0.3...5 step 0.05 |
| 21 | `shrink` | Double | 0.55 | 169 0...1 step 0.01 |
| 23 | `shrinkCurve` | Double | 1.4 | 170 0.2...5 step 0.05 |
| 25 | `fadeCurve` | Double | 4 | 173 0.3...10 step 0.05 |
| 28 | `maximumSway` | Double | 0.26 | 176 0...1.5 step 0.01 |
| 30 | `minimumSway` | Double | 0.1 | 177 0...1 step 0.01 |
| 32 | `swayCurve` | Double | 1.8 | 178 0...5 step 0.05 |
| 34 | `maximumTilt` | Double | 4 (degrees) | 181 0...45 step 0.5 "°" |
| 36 | `tiltCurve` | Double | 1 | 182 0.2...5 step 0.05 |
| 38 | `forceReduceMotion` | Bool | false | 185 `Toggle("Simulate Reduce motion", isOn: $model.tuning.forceReduceMotion)` |
| 40 | `swipeFollowsCursor` | Bool | true | 188 Toggle "Move like the cursor" |
| 42 | `swipePointsPerStep` | Double | `SwipeTravel.shippedPointsPerStep` (from LauncherCore; 100 per comments) | 189 20...300 step 1 "pt" |
| 44 | `swipeTrackingSpeed` | Double | -1.0 | 191 -1...3 step 0.0625 |

Doc comment on the type (lines 4-5): "Every number that shapes a launch flight, plus the switcher's swipe acceleration, which the same tuner tweaks. `shipped` is the animation release builds play; Debug builds can override it live from the animation tuner (AnimationTuner.swift)."

All fields are flat on one struct; no nesting. All numeric knobs are `Double` (the `knob` helper only accepts `WritableKeyPath<LaunchTuning, Double>`). There are no Int fields, no steppers, no pickers.

## Flow

### A. Release build (shipped values)
1. Consumers read `LaunchTuning.current` (LaunchFlight.swift:64-73, 84; LaunchOverlay.swift:38; CursorTravel.swift:38).
2. `LaunchTuning.swift:52` `static var current: LaunchTuning { shipped }` → the memberwise defaults. No Mutex, no Codable, no tuner type exists in Release (AnimationTuner.swift is wrapped entirely in `#if DEBUG`, lines 1 and 287).

### B. Debug build start-up and live tuning
1. `TrackpadLauncher/TrackpadLauncherApp.swift:22-24`: after `launcher.start()`, `#if DEBUG system.showAnimationTuner() #endif`. The tuner opens automatically at every Debug launch; there is NO menu item or other entry point (grep of LauncherUI/MenuBarShell for "tuner" finds nothing).
2. `WorkspaceActions.showAnimationTuner()` (WorkspaceActions.swift:46-54): if `tuner == nil`, builds a hard-coded Finder `AppEntry` (`bundleID "com.apple.finder"`, url `/System/Library/CoreServices/Finder.app`) and `tuner = AnimationTuner { [overlay] in overlay.play(for: finder) }`; then `tuner?.show()`.
3. `AnimationTuner.init(preview:)` (AnimationTuner.swift:17-33): creates `TunerModel()`, an `NSHostingView(rootView: TunerView(model:preview:))`, a `TunerPanel` 420x760, style `[.titled, .resizable, .utilityWindow, .miniaturizable]` (no `.closable`), title "Launch animation tuner", level `.floating`, `hidesOnDeactivate = false`, `isReleasedWhenClosed = false`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, positioned top-right of `NSScreen.main.visibleFrame` (x = maxX − 440, y = maxY − 20). `show()` = `orderFrontRegardless()`.
4. `TunerModel.init()` (AnimationTuner.swift:84-89): `tuning = load(LaunchTuning.self, key: "AnimationTuner.current") ?? .shipped`; `presets = load([TuningPreset].self, key: "AnimationTuner.presets") ?? []`; `selected = UserDefaults.standard.string(forKey: "AnimationTuner.selected")`; then `tunerOverride.withLock { $0 = tuning }` explicitly (property observers do not fire in init). Consequence: a Debug build plays the last tuner state, not shipped, from launch (this bit plan 014: see Non-Obvious).
5. Any knob edit: `TunerView.knob` binding setter (line 262) does `model.tuning[keyPath:] = ($0 / step).rounded() * step` → `TunerModel.tuning.didSet` (lines 66-71) → `tunerOverride.withLock { $0 = tuning }` and `store(tuning, key: currentKey)` (JSON to UserDefaults on every change, including every slider drag tick).
6. Next gesture: `Launcher.fire` (LauncherCore/Launcher.swift:234-245) → `system.playLaunchAnimation(for:)` if `settings.isLaunchAnimationOn` → `WorkspaceActions.playLaunchAnimation` (WorkspaceActions.swift:37-39) → `LaunchOverlay.play(for:)` (LaunchOverlay.swift:34-69) → reads `LaunchTuning.current` (now the tuner's value through the Mutex) when computing reduce-motion and in `LaunchFlights.next` / `LaunchFlight.staged` / `pose(at:)`. All keyframes are staged synchronously inside `play`; nothing reads the tuning after `play` returns.

### C. "Preview at pointer" (bottom bar, AnimationTuner.swift:202-208)
1. `Button("Preview at pointer") { preview() }` `.buttonStyle(.borderedProminent)` → the closure from WorkspaceActions → `overlay.play(for: finder)`.
2. `LaunchOverlay.play` reads `NSEvent.mouseLocation` (line 35): since the user just clicked the button, the flight plays at the button's location, over the tuner (overlay panel level `.screenSaver` > tuner `.floating`).
3. This bypasses `Launcher` entirely, so it ignores the launch animation setting and gestures-active state (plan 005 line 295: "The tuner's previews play through the overlay directly and ignore the setting").
4. Finder is not usually among the `prepareLaunchAnimations` apps, so the first preview renders Finder's icon on the main actor via `LaunchOverlay.bitmap(for:scale:)` (lines 73-79) and caches it.

### D. Per-preset play button (presets section, lines 234 and 244)
`model.preview(.shipped, play: preview)` / `model.preview(preset.tuning, play: preview)` → `TunerModel.preview(_:play:)` (lines 91-96):
```swift
func preview(_ tuning: LaunchTuning, play: @MainActor () -> Void) {
    tunerOverride.withLock { $0 = tuning }
    play()
    tunerOverride.withLock { $0 = self.tuning }
}
```
It temporarily swaps the global override, plays synchronously, and restores it. This works ONLY because `LaunchOverlay.play` reads every tuning value synchronously during the call (keyframes are pre-staged). Anything that reads `LaunchTuning.current` later (e.g. a per-frame bounce follower, or an end-of-bounce float-away triggered seconds later) would see the restored live tuning, not the previewed preset's.

### E. Presets and persistence (TunerModel, AnimationTuner.swift:61-147)
- UserDefaults keys (all `UserDefaults.standard`, the app's own domain, bundle id `com.domasgru.TrackpadLauncherApp` per project.yml, shared by Debug and Release builds and by all worktrees' Debug builds):
  - `"AnimationTuner.current"` (line 62): JSON `Data` of `LaunchTuning`.
  - `"AnimationTuner.presets"` (line 63): JSON `Data` of `[TuningPreset]`.
  - `"AnimationTuner.selected"` (line 64): plain String (preset name) or nil.
- `store` (140-142): `UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey:)` (default encoder, unsorted keys). `load` (144-146): `data(forKey:)` then `try? JSONDecoder().decode`; any decode failure → nil.
- `presets.didSet` stores the whole array; `selected.didSet` stores the name.
- Operations: `resetToShipped()` (105-108) sets tuning `.shipped`, selected nil. `load(_ preset:)` (110-113) copies preset.tuning into `tuning` (which applies to the override) and selects it. `saveAsNew()` (115-128): trimmed `newName`, or the first unused "Preset N"; overwrites a same-named preset or appends; selects it; clears `newName`. `updateSelected()` (130-133) overwrites the selected preset with current tuning. `delete(_:)` (135-138). `isModified` (98-103) compares against the selected preset, or against `.shipped` when none.
- No export/import, no files, no clipboard; persistence is only these three defaults keys. A "Shipped" pseudo-row always heads the list (lines 229-237) with play and Load (Load = resetToShipped).
- Actual data on this machine (read-only `defaults export`): `AnimationTuner.selected = "Preset 2"`; `AnimationTuner.current` and both presets ("Preset 1", "Preset 2") contain only the 15 flight keys and NO `swipe*` keys, i.e. they were saved before the swipe knobs existed. They decode today because of the tolerant decoder: real-world proof that old presets are in use and must keep loading.

### F. Backward compatibility when decoding (LaunchTuning.swift:56-86)
```swift
#if DEBUG
/// The tuner saves tunings as JSON. Keys missing from an older save keep their shipped values.
extension LaunchTuning: Codable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        let s = LaunchTuning.shipped
        self.init()
        iconSide = try value(.iconSide, s.iconSide)
        ...
        swipeTrackingSpeed = try value(.swipeTrackingSpeed, s.swipeTrackingSpeed)
    }
}
#endif
```
- Missing key → shipped value. Unknown extra keys → ignored (keyed container). A present key with the wrong type → throws → the whole `load` returns nil (for presets: the whole array is lost → `[]` in memory; the stored blob is only overwritten on the next presets mutation, since didSet doesn't fire in init).
- `encode(to:)` and `CodingKeys` are synthesised (allowed because the extension is in the same file as the type). So a new stored property is automatically encoded, but it is NOT decoded unless a line is added to `init(from:)`. Forgetting it is not a compile error: `self.init()` already gave it the default, so a saved non-default value silently reverts to shipped on reload.
- Precedent: commit 10b0e91 added the three swipe fields with exactly one `value(...)` line each in `init(from:)`. Commit 18acef7 renamed `swipePointsPerIcon` → `swipePointsPerStep` (and `SwipeTravel.shippedPointsPerIcon` → `shippedPointsPerStep`); renamed keys silently drop old saved values (fall back to shipped) — no migration code exists.

## `#if DEBUG` boundaries (complete list)
1. `LaunchTuning.swift:48-53` — `current` reads `tunerOverride` (Debug) vs `shipped` (Release).
2. `LaunchTuning.swift:56-86` — the `Codable` conformance exists only in Debug.
3. `AnimationTuner.swift:1-287` — the whole file: `tunerOverride`, `AnimationTuner`, `TunerPanel`, `TuningPreset`, `TunerModel`, `TunerView`. Imports `AppKit, LauncherCore, Observation, SwiftUI, Synchronization` only inside DEBUG.
4. `WorkspaceActions.swift:41-55` — `private var tuner: AnimationTuner?` and `public func showAnimationTuner()`.
5. `TrackpadLauncher/TrackpadLauncherApp.swift:22-24` — the call `system.showAnimationTuner()`.
- DEBUG is defined by SwiftPM in debug configuration (no explicit `-DDEBUG` in `Config/*.xcconfig`, `project.yml` or `Package.swift`; Xcode builds the package with the scheme's Debug/Release config). `swift test` (Scripts/test.sh) builds debug, so tests see the DEBUG branch: `LaunchTuning.current` reads `tunerOverride`, which stays `.shipped` because no test constructs `TunerModel`.
- SwiftUI is used in LauncherPlatform only inside this DEBUG file (the shell's SwiftUI lives in LauncherUI). LauncherPlatform is nonisolated-by-default (no `defaultIsolation` in Package.swift for it), so the tuner types are explicitly `@MainActor`.

## TunerView layout (where a bounce section slots in), AnimationTuner.swift:149-286
- `body` (153-211): `VStack(spacing: 0) { Form { Sections...; presetsSection }.formStyle(.grouped); HStack { "Reset to shipped"; Spacer; "Preview at pointer" }.padding(12) }.frame(minWidth: 380, minHeight: 500)`.
- Section order: "Size & timing" (156), "Pop" (160), "Rise" (164), "Shrink" (168), "Fade" (172), "Sway" (175), "Tilt" (180), an untitled Section with the Reduce-motion toggle (184-186), "Switcher swipe" with `header:`/`footer:` builders (187-197), then `presetsSection` (198).
- A Section with its own controls plus a footer note is already the "Switcher swipe" pattern (header + footer Text). There is no per-section button today; the only preview button is in the global bottom bar. A bounce "Preview" button could be a `Button` row inside a new Section (e.g. before `presetsSection`).
- `knob(_ title:_ keyPath:_ range:step:unit:hint:)` (256-285): a VStack of [title, trailing numeric `TextField` (format `.number.precision(.fractionLength(0...3))`, width 60), unit label (width 34), a revert-to-shipped button (`arrow.uturn.backward`, tooltip "Shipped: <value>", dimmed/disabled when equal to shipped)], then a `Slider(value:in:)`, then an optional caption hint. Value is snapped to `step` in the setter. Keypath type is `WritableKeyPath<LaunchTuning, Double>`; nested keypaths (e.g. `\.bounce.height`) would also type-check if bounce knobs were a nested struct, and the "isShipped"/revert logic compares against `LaunchTuning.shipped[keyPath:]` so it would work for nested paths too.
- Booleans use `Toggle(..., isOn: $model.tuning.<field>)` directly (no revert button).
- Panel default 420x760 and resizable; Form scrolls, so ~10 more knobs only lengthen the scroll.

## Tests covering LaunchTuning / presets
- There are NO tests for `LaunchTuning`'s Codable decoding, `TuningPreset`, or `TunerModel` (grep for `Tuning|tuner|JSONDecoder|decodeIfPresent` under `LauncherKit/Tests` finds only an unrelated `Saved: Codable` in `LauncherCoreTests/Fixtures.swift:132`).
- `LauncherKit/Tests/LauncherPlatformTests/LaunchFlightTests.swift` (318 lines, Swift Testing `@Suite struct LaunchFlightTests`, `@testable import LauncherPlatform`) tests the shipped flight via `LaunchTuning.current` implicitly (== shipped in tests). Structure: a `Keyframe` struct and `LaunchStage.keyframes()` extension that reads back the `CAKeyframeAnimation` values (lines 6-54); fixture displays `LaunchDisplay.builtIn` (1512x982 @2x) and `.external` (2560x1440 @1x above it) (56-61); parameterised `@Test(arguments: modes, draws)` with `draws = [-1, -0.5, -0.01, 0, 0.01, 0.5, 1]`, `modes = [false, true]` (reduceMotion). Tests assert requirement bounds (e.g. peak 66...78 pt within 0.1 s, rise 60...80 pt, invisible between 0.3 and 0.4 s, sway ≤ rise/3, tilt ≤ 5°, edge clipping, display choice), not the formulas — per plan 004's "tests check the requirement bounds, not these formulas".
- Testing `TunerModel` would be awkward: it hard-codes `UserDefaults.standard` and three literal keys (no injection), and writes the global `tunerOverride`. Decoding `LaunchTuning` from JSON is testable directly in `LauncherPlatformTests` (DEBUG is on under `swift test`).
- `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` scans ALL Swift under `LauncherKit/Sources` and `TrackpadLauncher/` (including `#if DEBUG` code and comments, by substring) for banned tokens: `"Timer"`, `"asyncAfter"`, `"Task.sleep"`, `"makeTimerSource"`, `"displayLink"`, `"DisplayLink"`, `print(`, etc. (lines 13-64). This applies to the tuner too: a 3-second bounce preview cannot be timed with Timer/asyncAfter/Task.sleep, and even a comment containing "Timer" fails the test.

## Boundaries
- Inputs to the tuner: user edits in the SwiftUI window; persisted JSON in `UserDefaults.standard`.
- Output of the tuner: the `tunerOverride` Mutex (read through `LaunchTuning.current` by `LaunchFlight`, `LaunchOverlay`, `CursorTravel`), and the preview closure injected by `WorkspaceActions` (one closure, `@MainActor () -> Void`, which plays Finder's icon via `overlay.play(for:)`).
- `LaunchTuning`, `tunerOverride`, `TunerModel`, `AnimationTuner` are all internal to `LauncherPlatform`; only `WorkspaceActions.showAnimationTuner()` is public. `LauncherCore` knows nothing of tuning (the `SystemActions` port in `LauncherCore/Ports.swift:56-68` has `prepareLaunchAnimations(for:)` and `playLaunchAnimation(for:)`; the port doc says play "plays for about a third of a second and removes itself... never cancels, restarts or reuses one already playing").
- `LauncherCore` contributes one value into LaunchTuning: `SwipeTravel.shippedPointsPerStep` (hence `import LauncherCore` in LaunchTuning.swift:2).
- `docs/architecture.md:22`: "Developer tools live in `#if DEBUG` and never ship. Today that is the launch animation tuner in `LauncherPlatform`: a SwiftUI window over `LaunchTuning`, whose defaults are the shipped animation." `docs/architecture.md` (Concurrency bullet "Animation is Core Animation keyframes ... No code of ours runs per frame, and display links are banned along with timers.") constrains any per-frame follow.

## Non-Obvious Things
1. Debug builds do NOT play the shipped animation by default: `TunerModel.init` restores `AnimationTuner.current` from defaults and pushes it into `tunerOverride` at launch. Plan 014 (plans/014-gate-event-tap/development-logs.md:40, plan.md:45) records the user seeing Release's icon "much smaller" for exactly this reason; the fix was to make shipped equal "Preset 2". Manual checks are told to "Reset to shipped" first (plan 005 line 149, 206). New bounce knobs will start at shipped for everyone because existing saved blobs lack those keys.
2. The tolerant decoder is hand-maintained: every new field needs one `x = try value(.x, s.x)` line in `init(from:)`; the encoder is synthesised and the compiler won't flag a missing decode line. Renaming a field silently drops saved values (happened with `swipePointsPerIcon` → `swipePointsPerStep`).
3. A wrong-typed key in a saved preset makes the whole `[TuningPreset]` decode fail and the in-memory list empty; the next save then overwrites the stored blob, losing all presets. (Changing a field's type, e.g. Double→Int or Bool→Double, would trigger this for old presets.)
4. `TunerModel.preview(_:play:)` relies on `play()` consuming the tuning synchronously. A bounce that lives for seconds and reads `LaunchTuning.current` per frame or at its end would see the live tuning after the swap is restored, so per-preset play buttons would not faithfully preview a preset's bounce unless the bounce snapshots its tuning at start (the flight's behaviour already effectively snapshots, since keyframes are staged in `play`).
5. The tuner panel has no close button (no `.closable` in its style mask) and there is no menu item to reopen it; it opens once per Debug launch and can only be miniaturised.
6. The preview plays at `NSEvent.mouseLocation`, i.e. over the button just clicked, on top of the tuner (screenSaver level). A bounce preview that follows the pointer would sit over the tuner window; since the overlay panel ignores mouse events it would not block the tuner.
7. The preview closure is a single `() -> Void` passed into `AnimationTuner.init`; a second action (bounce preview) needs either a second closure parameter or a richer interface from `WorkspaceActions` (which owns the `overlay` and the Finder `AppEntry`).
8. The preview bypasses `Launcher` and so bypasses the launch-animation setting and any "is the app running" decision; for a bounce preview that is desirable (Finder is always running, so a real gesture would never bounce it).
9. Every slider tick writes JSON to UserDefaults (`tuning.didSet`), and `Equatable` on `LaunchTuning` drives `isModified` and per-knob "isShipped" display — any new field participates automatically via synthesised `==`.
10. The tuner's keys live in the same defaults domain as real settings and are shared across all worktrees' Debug builds (same bundle id), so a bounce tuned in one worktree applies in another.
11. `LaunchTuning` already mixes concerns (flight + switcher swipe), so adding bounce knobs to it is consistent with precedent; the type's name and doc comment would then be stale-ish ("Every number that shapes a launch flight, plus the switcher's swipe acceleration"). `WindowSwitcherLook` shows the alternative pattern (separate shipped struct, not tunable).
12. Source-scan bans ("Timer", "asyncAfter", "Task.sleep", "displayLink"/"DisplayLink") cover DEBUG code and comments too, so the R18 "3 seconds then end" preview needs a non-timer mechanism (e.g. Core Animation completion, or whatever end-scheduling the bounce itself uses).

## Open Questions
- Whether `SwipeTravel.shippedPointsPerStep` is exactly 100 was taken from comments (AnimationTuner.swift:190 hint "100 = the icon pitch"); I did not open `LauncherCore` to confirm the constant.
- I did not verify how Xcode passes `DEBUG` to the SwiftPM package targets beyond SwiftPM's default (debug config defines `DEBUG`); the existing code relies on it and works, per plan 004/014 history.
- No test currently pins the Codable backward-compat behaviour; whether the project wants one (e.g. decoding the real old preset JSON shown above) is a design choice, not something present.
