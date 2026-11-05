# Plan: Opening the app by hand brings its window to the front

## Problem statement

Opening Trackpad Launcher from Finder or Spotlight when the process is not running leaves its window under the app that was in front. The product overview promises that opening the app opens its settings window, and a window the user cannot see fails that promise.

Reproduced on the real app (`plans/034-launch-window-to-front/.temp/repro/repro.swift`, a harness that opens the built app and reads the on-screen window order):

| Opening | Result on main |
|---|---|
| Not running, Finder opens the app | Under Finder, 12 of 12 |
| Not running, LaunchServices opens the app with Calculator in front | Under Calculator, 12 of 12 |
| Not running, real Spotlight, installed 1.0.10 | Under Calculator, 4 of 4 (the harness kills the release bundle id only, so which copy Spotlight opened was not confirmed) |
| Running, window closed | On top, and the app's own log reads `active=true key=true` |
| Running, window open behind another app | On top |

Root cause: the app is `LSUIElement`, so a cold launch does not make it active. `SettingsShell.render` then calls `NSApp.activate()`, which since macOS 14 is cooperative: it is a request the system may refuse unless the active app yielded. It is refused here. The app log at that moment and one second later reads `active=false key=false front=<previous app>`, with the policy already `.regular`. Waiting does not help: `activate()` on the next run-loop turn, 150 ms later, and `NSRunningApplication.current.activate(options:)` all fail the same way, 3 of 3 in each cold mode. `NSApp.activate(ignoringOtherApps: true)` succeeds, 3 of 3 in each cold mode, and the log then reads `active=true key=true` in all 15 of its openings, across every mode. A reopen works today because macOS has already made the app active before `render` runs.

`MoveDialogPresenter` makes the same `NSApp.activate()` call on the same cold launch, so the move dialog is expected to fall under other windows in the same way. This has not been reproduced yet; R2 covers it.

No existing test could catch this. The model correctly reaches `.open`; the failure lives in the system's answer to the shell's AppKit call.

## Requirements

### R1. A cold opening by hand brings the settings window to the front
When the app is opened by hand while its process is not running, the settings window MUST end up as the frontmost window, key, with the app active.

#### Scenario: Opened from Finder
GIVEN the app is not running and Finder is in front
WHEN Finder opens the app
THEN the settings window is above every other normal window AND the app is active

#### Scenario: Opened through LaunchServices with another app in front
GIVEN the app is not running and Calculator is in front
WHEN LaunchServices opens the app, as Spotlight does
THEN the settings window is above Calculator AND the app is active

### R2. The move dialog comes to the front the same way
A copy opened by hand outside /Applications MUST show its move dialog in front of other windows, with the app active.

#### Scenario: Opened outside /Applications
GIVEN a development build opened with `open <app> --args --as-release-build` from outside /Applications and another app in front
WHEN the dialog shows
THEN the dialog is in front of that app. Quit the dialog after checking; do not press Move.

### R3. Openings that work today keep working
Reopening with the window closed, and reopening with the window open behind another app, MUST still bring the window to the front. A login start MUST still show no window and take no focus.

### R4. The reason survives the deprecation
The activation that overrides other apps MUST live in one place that states why plain `NSApp.activate()` is not enough, so nobody restores the plain call, and a source-policy test MUST confine it there.

## Non-goals

- The Debug animation tuner's `NSApp.activate()`: it runs on a mouse click in the panel, which is user intent the system accepts, and it ships in no release build.
- Replacing `activate(ignoringOtherApps:)` with an API free of the to-be-deprecated mark: the SDK only marks it to-be-deprecated, so it produces no compiler warning, and every call without that mark was refused. If a later macOS removes it, the harness shows it at once.
- Automated tests of real activation: `swift test` cannot drive LaunchServices or window order. The harness is the check for R1 and for R3's reopenings, run by hand; R2's check is the hand sequence its scenario describes, since the harness opens the app with no arguments. The harness must not send synthetic keystrokes: doing so opened Dictionary and raised a macOS accessibility warning, so real Spotlight runs are for a human.

## Implementation Decisions

- **One place activates the app over other apps: `AppActivation.activateOverOtherApps()`, a tiny module in `LauncherUI`.** An enum with one static function and no parameters, internal to `LauncherUI` (both callers live there), in its own file named for it so the source-policy test can name the file. Its implementation is the one call, `NSApp.activate(ignoringOtherApps: true)`. Its doc comment is the reason, and is the artefact R4 asks for; it must say, in substance: the app is `LSUIElement`, so an opening by hand that starts the process does not make it active; since macOS 14 `activate()` is cooperative, a request the system grants only when the active app yielded, and on a cold launch nothing yielded, so the window stays under the app in front; `activate(ignoringOtherApps: true)` is marked for a future deprecation but is the one call that works, 3 of 3 in each cold mode of plan 034's harness, where `activate()`, a deferred `activate()` and `NSRunningApplication.current.activate(options:)` (whose `.activateIgnoringOtherApps` option the SDK says has had no effect since macOS 14) each failed 3 of 3; and a reopen arrives already active, where the call changes nothing. Nothing else goes in: no window ordering, no policy change. Those stay where they are.

- **`SettingsShell.render(.open)` and `MoveDialogPresenter.run` call it in place of their plain `NSApp.activate()`, at the same point in each.** The shell still orders the window front and then activates, on every render of `.open` (a cold open, a reopen with the window closed, a reopen with it behind another app); the presenter activates inside the modal session, once the alert shows, because the system drops an activation while the app has no window on screen (measured during S1: 0 of 3 before `runModal`, 3 of 3 inside the session; ordering the alert front first also works but leaves it off-centre). No other line of either changes; the model is untouched, since it already reaches `.open` correctly.

- **The source-policy test gains two `confined` entries.** `ignoringOtherApps`, allowed only in `AppActivation.swift`: the override has one home. `.activate()`, allowed only in `AnimationTuner.swift`: the plain call lives only in the Debug tuner, whose click-time call is the exception the non-goals name. That token catches `NSApp.activate()`, `NSApplication.shared.activate()` and `NSRunningApplication.current.activate()` alike, and matches neither the helper's own call nor `NSLayoutConstraint.activate([`. The second entry is what makes "nobody restores the plain call" a tested property rather than a comment; it also fails today, on the two plain calls, so the fix is test-first. The scan matches substrings of whole lines, comments included, so neither token may appear in a comment outside its files.

- **The call is marked for a future deprecation, not deprecated, and is called directly.** The SDK declares `activateIgnoringOtherApps:` `API_TO_BE_DEPRECATED`, so the compiler is silent and the build gains no warning; the package compiles with none today. The call stays a direct Swift call, never a selector or `perform`, so the compiler, the reader and the source scan all see it, and should a later SDK deprecate or remove it, the warning or the break lands at the one place that explains it.

- **No port, no fake.** The failure is in the system's answer to the shell's AppKit call, which no in-memory adapter can reproduce; a port here would have one adapter, a hypothetical seam. The architecture's rule that the shell stays thin holds: the helper is a shell concern, in `LauncherUI`, beside the activation policy it already owns.

## Testing Decisions

### Strategy

Two checks, one old seam and one harness. The source-policy scan (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`, `onlyItsAdapterUses` over the `confined` table) proves R4's confinement: it reads every Swift line the app ships and reports a token outside its allowed files, exactly as the existing `setActivationPolicy` → `SettingsShell.swift` entry does. It observes where the call lives; it cannot observe whether the call works, nor what the comment beside it says, which S1's review criterion checks. The harness (`plans/034-launch-window-to-front/.temp/repro/repro.swift`) proves R1 and the reopen half of R3: it opens the real built app through Finder and through LaunchServices, the way the user does, with Finder or Calculator in front, and reads the real window order and the real frontmost app two seconds later. It observes the state the user is left with; it misses whether the window is key (it reads the frontmost app and the window order, not the key window), which one hand step covers, real Spotlight (its LaunchServices mode is the same path) and the login start, which it cannot stage. R2 is a manual sequence, since its own scenario is one, and the login start half of R3 rests on the existing suite's login-start row over every placement (`aLoginStartRunsSilentlyWhereverItLies` in `LauncherKit/Tests/LauncherCoreTests/MoveToApplicationsTests.swift`), which keeps the window closed and the dialog absent, the only two paths that reach the new call. Nothing is faked: the scan reads the real sources and the harness runs the real system.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R4 | Source-policy scan, `confined` | Given the entry `ignoringOtherApps` allowed only in `AppActivation.swift`. When every Swift file under the library sources and the app target is scanned. Then no line outside that file holds it. Passes vacuously today (no file uses it) and guards the move afterwards. | R4: the override "MUST live in one place" |
| T2 | R4 | Source-policy scan, `confined` | Given the entry `.activate()` allowed only in `AnimationTuner.swift`. When scanned. Then no line outside that file holds it. Today: two hits, the plain calls in `SettingsShell.swift` and `MoveDialogPresenter.swift`. | R4: "so nobody restores the plain call"; the non-goal that keeps the tuner's click-time call |

### Verified without a test

- **R1**, by the harness, whose red run is already recorded in the problem statement (12 of 12 under Finder, 12 of 12 under Calculator). After the change: build the app with `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath build/dev -quiet`, compile the harness with `swiftc plans/034-launch-window-to-front/.temp/repro/repro.swift -o build/repro` (`build/` exists once the app has been built), then run `./build/repro "<absolute path to build/dev/Build/Products/Debug/Trackpad Launcher.app>" com.domasgru.TrackpadLauncherApp.debug 4 base` from the repository root. Expected: the summary lines `== base cold-finder: 0/4 bad` and `== base cold-other: 0/4 bad`, every trial line `ok` with `front=Trackpad Launcher` and `order=["Trackpad Launcher", …]`. Never pass the `spotlight` argument: it sends synthetic keystrokes, which opened Dictionary and raised a macOS accessibility warning. The harness does not read which window is key, so one hand step covers R1's key clause: with no copy running and Calculator in front, open the app with `open "<absolute path to build/dev/Build/Products/Debug/Trackpad Launcher.app>"` and, without clicking anything, press ⌘W. Expected: the settings window closes, since the Window menu's Close reaches only the key window of the active app (the Debug tuner's floating panel is not key until clicked, and stays). Why no test: `swift test` cannot open the app through LaunchServices or read the window order, and the thing under test is the system's answer to the call.
- **R2**, by hand, twice: once on the unchanged source, as R2's first reproduction (the problem statement says it has none), and once after the change. Rebuild first each time with the `xcodebuild` command above: `build/dev` holds the investigation's instrumented build, not the source. With no copy of the app running (the harness ends by killing its copy): bring Calculator to the front (`open -a Calculator`), then open the Debug build from where it was built, outside /Applications, with `open "<absolute path to build/dev/Build/Products/Debug/Trackpad Launcher.app>" --args --as-release-build`. Expected after the change: the move dialog, *Trackpad Launcher needs to be in the Applications folder*, is above Calculator's window and has the keyboard focus: its *Move to Applications* button is drawn filled in the accent colour, and Calculator's window shows as inactive. The focus is the clause to watch: an alert run modally sits at the modal panel level, so it may float above Calculator even while the app is not active, with its default button unfilled. Press *Quit*; never *Move*. Record both runs under Implement; if the unchanged source already passes both clauses, say so, and R2 is a no-regression check. Why no test: the requirement's own scenario is a human check, and the harness's window read is not worth extending for a one-off modal.
- **R3**, two halves. The reopenings, by the same harness run: `== base reopen-finder: 0/4 bad`, `== base reopen-other: 0/4 bad` and `== base behind-other: 0/4 bad`, with every trial `ok`; the problem statement records these as on top today, so this is a no-regression check. The login start, by the existing suite staying green under `make test`: `aLoginStartRunsSilentlyWhereverItLies` (`MoveToApplicationsTests.swift`), over every placement, keeps `windows == [.closed, .closed]` and `moveDialog == nil`, and the diff changes only the `.open` render and the dialog's run, so a login start never reaches the new call. Why no test: the harness cannot stage a login start, and the model's own rows already pin the two states that gate the call.

## Further Notes

- **The harness's `base` argument** is the variant label from the investigation. The harness writes it to `/tmp/tl034-variant` for the instrumented builds that read it; the shipped app never reads that file, so with the fix in place the label only names the output. Each trial takes a few seconds; 4 trials over 5 modes is about two minutes and leaves Calculator open.
- **Real Spotlight** is for a human, after a release is installed: the harness's LaunchServices mode is the path Spotlight takes, and the problem statement's Spotlight row could not tell which copy Spotlight opened while a Debug build lay beside the installed release.
- **Record the harness's output** after the fix under Implement in `development-logs.md`, as the problem statement recorded the red runs.
- **`build/dev` holds the investigation's instrumented build**, whose binary carries the override while no source does. Every run in this plan starts with the `xcodebuild` command, so what runs is the source.

## Slices

### S1: The window and the move dialog come to the front on a cold opening

**What to build:** Opening the app by hand from Finder or Spotlight while it is not running leaves its settings window in front, key, with the app active; the move dialog of a copy outside /Applications likewise. The activation that overrides the app in front lives in one helper with its reason, both call sites use it, and the source-policy test confines it, with the `.activate()` entry written first so it fails on today's two plain calls.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4.

**Test scenarios:** T2 (red first), T1.

**Skills:** `axiom-macos`, `swift-testing-pro`.

- [ ] Before any source change: the app is rebuilt from the unchanged source with the `xcodebuild` command and R2's hand sequence is run once, as its first reproduction; what is seen (above Calculator or not, the default button filled or not) is recorded under Implement in `development-logs.md`.
- [ ] The `.activate()` confined entry is added before any source changes and `make test` reports its two hits; the `ignoringOtherApps` entry is added beside it.
- [ ] `AppActivation.activateOverOtherApps()` exists in `LauncherUI`, in its own file, with the doc comment the Implementation Decisions spell out, reviewed against that list point by point; `SettingsShell` and `MoveDialogPresenter` call it in place of their plain calls, and neither token appears outside the files its entry allows, comments included.
- [ ] `make test` is green, every existing row included, and the build gains no new warning.
- [ ] The app builds with the `xcodebuild` command in Verified without a test, the harness compiles with the `swiftc` command, and the harness run with `4 base` reports `0/4 bad` for all five modes; the ⌘W step closes the cold-opened window; the output is recorded under Implement. The `spotlight` argument is never passed.
- [ ] R2's hand sequence is run again on the changed build and the dialog is above Calculator with the keyboard focus; *Quit* is pressed, never *Move*; the result is recorded under Implement.
