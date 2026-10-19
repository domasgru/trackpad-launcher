# Stabilise the full gate: real-launch tests leak probes and race other suites

## Goal

`Scripts/test.sh` (the repo's full gate: `swift test` in `LauncherKit`) must pass reliably, run after run, on this Mac. Since S2–S4 of plan 017 added tests that launch real throwaway probe apps (`LaunchBounceAdapterTests` and its extensions `LaunchBounceWindowTests.swift`, `LaunchBounceFollowTests.swift`; `LaunchWatchTests`; `ProbeBundlesTests`), it does not. Fix the tests and helpers; change shipped code (`LauncherKit/Sources`) only if you find a real bug there, and say so.

The human who owns this Mac sees every probe launch and every bouncing icon; they asked about it. Leaked probe processes are on their screen and in their Dock.

## Evidence (gate run on commit "The bouncing icon follows the pointer, onto any display")

655 tests, 4 issues:

1. `RunningAppsReaderTests.theOrderHoldsEveryDockAppNamedAsMacOSNamesItWithTheActiveAppFirst` (`RunningAppsReaderTests.swift` lines 48–51): `NSWorkspace`'s Dock apps (before and after, equal) included a `com.trackpadlauncher.test.probe.<uuid>` app that the private LaunchServices order read did not. This test is from an earlier plan and was stable before probes existed. A probe launched by another suite was alive while this suite ran in parallel.
2. `LaunchBounceAdapterTests.hasProcessIsTrueFromTheMomentMacOSListsTheProcessAndFalseOnceItIsGone` line 30: `hasProcess` for the menu bar probe was false.
3. After the run, 2 probe processes were still running (`pgrep -fl test.probe`). Before the run, 4 more from earlier runs were still alive. Cleanup leaks.
4. The S4 implementer saw failures move between runs in `aBounceEndedBeforeMacOSAnswersHearsNothingMoreForIt`, `aWindowOpeningLongAfterFinishingEndsTheBounceWhenItShows` and `RunningAppsReaderTests`, with "probe apps not listed in time".

Note also: `LaunchBounceFollowTests.swift` runs `NSApplication.run()` briefly, stopped by a timer, so NSEvent monitors fire in the test process. The S4 implementer reported an earlier variant hung the run and one exited the whole test run silently with status 0. Check that what is there now cannot do either, and that it cannot let other suites' main-actor work interleave in surprising ways.

## What to do

- Reproduce first: run the full gate several times and the real-launch suites in isolation; record what fails and why. Kill leftover probes (`pkill -9 -f com.trackpadlauncher.test.probe`) before you start, and check for leftovers after every run.
- **No leaks.** Every probe a test launches is gone when the test ends, including when an expectation fails, a wait times out, or a probe is mid-launch (still listed-but-unfinished, blocked in will-finish, or not yet listed when cleanup runs). `ProbeBundles.withProbes` is the one place for this; make its cleanup wait (bounded) for termination and handle a process macOS lists only after cleanup started (e.g. kill by bundle ID / by executable path under the probe directory, then wait for `isTerminated`).
- **No cross-suite interference.** Suites that launch probes must not run while other suites read the system's running apps or the frontmost app (`RunningAppsReaderTests`, `FrontmostAppWindowsTests`, anything else that reads `NSWorkspace` / LaunchServices / the window list). Swift Testing runs suites in parallel; `.serialized` only orders tests within one suite. Options: one parent suite holding every real-launch suite and those readers, serialized; or make the readers ignore apps whose bundle ID starts with `com.trackpadlauncher.test.probe.` (only if that keeps the reader test meaningful). Choose what keeps each test honest; explain the choice.
- **No timing flakes.** Rows with time bounds (the 50 ms window rows, the deadline rows) must hold under the load of the full gate. Do not widen bounds the plan names (R9's 50 ms; deadline windows like 400–900 ms) to pass; find why they miss (contention with other suites, the main actor busy, probes from earlier rows still running) and remove the cause.
- Keep the existing names: `swift test --skip LaunchBounceAdapterTests` should still leave out the real-launch rows if possible (say if it no longer can).
- Done means: `Scripts/test.sh` passes three runs in a row, and after each run `pgrep -f com.trackpadlauncher.test.probe` finds nothing and no `CoreServicesUIAgent` alert window is up.

## Rules that apply

- `docs/architecture.md`: "Tests use Swift Testing." Shipped-code bans (no timers, polling, logging) apply to `LauncherKit/Sources` only; tests may wait with bounds, but prefer awaiting pushes over polling.
- Do not change behaviour the plan specifies; this is test reliability work.

## Starting point

Plan 017 slices S1–S4 are committed. Helpers: `Tests/LauncherPlatformTests/ProbeBundles.swift` (`withProbes`, push-based waits incl. `listed`, `finishedLaunching`, `terminated`), `BounceBench.swift` (`ProgressLog`, window-list reader, `openLikeTheDock`, `setDisplays`). Probe executable: `Tests/LaunchProbe/main.swift`.
