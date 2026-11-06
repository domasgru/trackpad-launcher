# Review fixes for plan 032

Work only in `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/032-hide-background-apps`. Do not commit: the orchestrator commits. Never run anything that hides, activates, launches or quits a real app.

Apply exactly these fixes, then run `make test` from the repo root and report its exit code. All paths are from the repo root. `LauncherKit/Tests/LauncherPlatformTests/ApplicationsUpdaterTests.swift:675` is an existing upper time bound that fails under machine load; re-run once if it alone fails, and say so. Expected test counts may rise only by nothing: no test is added or removed here.

## Docs

1. `docs/domain-model.md`, *Running apps* (line 79). Rule broken: the entry says where the list is read, "Read from LaunchServices at the moment a swipe begins and again when it ends, and at each thumb tap that may swap"; `Launcher.swift:332` also reads it when a launched app's first window shows. Fix: add that moment to the sentence: "…and at each thumb tap that may swap, and when a launched app's window shows while the hide background apps setting waits for it".

2. `docs/domain-model.md`, *Bring to front* (line 127). Rule broken: "with both settings off nothing is watched" (*Launch watch*, line 180) against the unconditional "A gesture that launches its app shows the launch bounce while the app starts up, and is followed by a launch watch." Fix: replace that sentence with "A gesture that launches its app shows the launch bounce while the app starts up, and is followed by a launch watch, as long as the launch animation setting or the hide background apps setting is on."

3. `docs/architecture.md`, Privacy (line 25). Rule broken: the glossary's *Launch watch* runs without a bounce, but the text says "the launch bounce's launch watch". Fix: change those words to "the launch watch". Nothing else in the sentence changes.

## Code

4. `LauncherKit/Sources/LauncherCore/Launcher.swift`, `fire`, around line 316. Smell: `if hides { hideOtherApps(than: id) }` repeats the setting check inside the private helper `hideOtherApps(than:)`. Fix: call `hideOtherApps(than: id)` unconditionally there. `hides` stays for the two earlier uses.

5. `LauncherKit/Sources/LauncherPlatform/LaunchWatch.swift:27` and its uses. Mysterious name: `hasRanOut` is not English. Fix: rename to `hasRunOut`.

6. `LauncherKit/Sources/LauncherPlatform/WorkspaceActions.swift` lines 18, 50 and 87. Primitive obsession; `docs/domain-model.md` *Assignment* identifies an app by bundle identifier and the repo has `BundleID`. Fix: `PendingHide.kept` is a `BundleID`, `hideOtherApps` uses `app` directly, and the comparisons use `.rawValue`. `applicationActivated` keeps taking the `String?` the notification gave. No behaviour change.

## Tests

7. `LauncherKit/Tests/LauncherCoreTests/HideBackgroundAppsTests.swift:138`. Plan's T3 clause: "`launchAnimations == []`, `launches == []`". `bounces.isEmpty` derives from bouncing launches only, so it cannot see an unseen watch wrongly started for a running app. Fix: assert `world.system.launches.isEmpty`.

8. `LauncherKit/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift:12` and `LauncherKit/Tests/LauncherCoreTests/SwipeSettingTests.swift:5`. Plan's S2 criterion: "with `hidesOthers.isEmpty` folded into the `nothingHappened` helpers". Fix: fold it into both.

9. `LauncherKit/Tests/LauncherCoreTests/HideBackgroundAppsTests.swift:23,41`. swift-testing-pro `core-rules.md`: "Never use `!`" in `#expect`. Fix: write these and every other `#expect(!…)` in this one file as `== false`. Leave other files alone.

10. `LauncherKit/Tests/LauncherPlatformTests/LaunchWatchClockTests.swift:30,55`. `writing-better-tests.md`: `#require` for preconditions. Fix: `(reports.seen.first?.time ?? began)` and `?? limited` become a `try #require(reports.seen.first?.time)`, making the test throw where needed.

11. `LauncherKit/Tests/LauncherCoreTests/LaunchBounceTests.swift`. The file and its suite test `WatchedLaunch.Stage` now. Fix: `git mv` it to `WatchedLaunchTests.swift` and rename the suite `WatchedLaunchTests`. Keep every test and value.
