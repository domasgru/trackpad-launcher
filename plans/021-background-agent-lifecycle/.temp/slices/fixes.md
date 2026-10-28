# Fixes after review: plan 021

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/021-background-agent-lifecycle` (branch `feature/021-background-agent-lifecycle`). Every slice is committed; fix the findings below in place. Do not commit; the orchestrator commits your work. Paths are relative to the worktree root.

The full gate after S7 was green (`Scripts/test.sh`: 145 platform + 565 core tests; Debug `xcodebuild` succeeded) with one compiler warning (item 9).

## Fixes

1. **R20: a copy nested inside /Applications is not replaced.** `LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift:53-65` looks for an existing Trackpad Launcher only directly inside /Applications, while `Placement` treats any depth as installed. Rule: plan design, `ApplicationsInstaller.install` step 1, "destination = the bundle with this bundle identifier already inside /Applications, if any"; R20 "When /Applications already holds Trackpad Launcher, *Move to Applications* MUST … replace it with the copy being moved". **Fix:** search `applications` recursively for `.app` bundles whose `CFBundleIdentifier` matches (a `FileManager` enumerator with `.skipsPackageDescendants` and `.skipsHiddenFiles`, so it never descends into bundles), preferring a direct child when there are several; fall back to `applications/<original's name>` when none. This runs off the main actor inside the install, as now. Add a T34 case: an existing copy at `Utilities/TrackpadLauncher.app` inside the temp /Applications is the one replaced, and no second copy appears.

2. **The move dialog's text is false in some cases.** `LauncherKit/Sources/LauncherCore/Copy.swift:14` `moveDialogMessage` says "The copy you opened will be removed." Rule: R19 "A copy on a disk image stays there" and "If it cannot be removed, … leave the original where it was". **Fix:** drop the removal promise, e.g. "Move it there to finish installing." (Update any test that pins the string.)

3. **The move's file operations are in two files, but the docs say one.** `PrivilegedInstall.swift:22-35`'s script runs `/bin/mv` and `/bin/rm -rf` on the bundle, while `docs/architecture.md` § Privacy says "every file operation of that move is confined to one file" and `BundleInstall.swift:4` claims to be the only file that copies, moves or deletes a bundle. The plan designed the administrator script as its own file deliberately (it confines `AuthorizationExecuteWithPrivileges` and the test runs the real script), so the doc is what's wrong. **Fix:**
   - `docs/architecture.md` § Privacy: change "every file operation of that move is confined to one file" to say the unprivileged file operations are confined to one file and the administrator's are confined to the one script that runs them (one more file).
   - `BundleInstall.swift:4`: say it holds every *unprivileged* file operation of the move, and that the administrator path's moves are `PrivilegedInstall`'s script.
   - `SourcePolicyTests.confined`: add `/bin/mv` and `/bin/rm` confined to `PrivilegedInstall.swift`.

4. **DEBUG animation tuner is lost when another copy is running.** `TrackpadLauncher/TrackpadLauncherApp.swift:76-81` sets `hasShownTuner` before the resident exists, so when the opening by hand first waits for other copies to exit the tuner never opens. Rule: plan module map, "DEBUG: the animation tuner opens with the first opening by hand". **Fix:** show it once the resident's window first opens (e.g. observe `lifecycle.launcher?.isWindowOpen`, or set the flag only when the tuner was actually shown). Still `#if DEBUG`, still never calls `setActivationPolicy`.

5. **`SystemRunningCopies.stop` reports already-exited copies a turn late.** `LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift:35-41`. Rule: the `RunningCopies.stop` contract, "Calls `exited` once … synchronously when none still runs." **Fix:** before registering KVO, drop every resolved copy whose `isTerminated` is already true; if none remain, call `exited` synchronously; otherwise observe only those still running (the `.initial` delivery may still race a termination; keep the once-only guard).

6. **Stale comment.** `LauncherKit/Sources/LauncherPlatform/ThisCopy.swift:20-21` says the disk-image lookup "answers nil until a disk image can be told…", but it is wired to `DiskImages`. **Fix:** reword to describe `DiskImages.image(holding:)` on the original.

7. **Ports declared outside `Ports.swift`.** `RunningCopies`, `LoginItem` and `Installer` are declared in `LauncherKit/Sources/LauncherCore/Lifecycle.swift:68-159`, while every other port lives in `Ports.swift`. **Fix:** move the three protocols (with their doc comments) into `Ports.swift`. The value types they use (`RunningCopy`, `CopyID`, `InstallOutcome`, `DiskImage`) stay where they are.

8. **Quit button's white text is implicit.** `LauncherKit/Sources/LauncherUI/SettingsView.swift:51-56`. Rule: R10 "tinted solid red, with white text". **Fix:** set `.foregroundStyle(.white)` on the button's label explicitly.

9. **Compiler warning.** `LauncherKit/Sources/LauncherPlatform/PrivilegedInstall.swift:83`: `var argv` is never mutated → `let` (if it must be `var` for an `inout`/pointer use, restructure so no warning remains). The build must have no warnings from this branch's files.

## Test fixes

10. **T3 skips `moveDialog`.** `LauncherKit/Tests/LauncherCoreTests/LifecycleTests.swift:47-61`. Rule: T3 "after every step the window is `.closed` and `moveDialog == nil`". **Fix:** assert `lifecycle.moveDialog == nil` after every step.

11. **T10 repeats the code under test.** `LauncherKit/Tests/LauncherPlatformTests/QuitSignalsTests.swift:25-27` computes the expected value with the same formula as `QuitSignals.request`. Rule (tdd `tests.md`): the expected value comes from an independent source of truth. **Fix:** spell the eight rows (× the two senders) with hard-coded expected `.system`/`.other`.

12. **Tautological assertion.** `LauncherKit/Tests/LauncherPlatformTests/PrivilegedInstallTests.swift:80`, `#expect(administrator.calls.first?.script == PrivilegedInstall.script)` passes by construction. **Fix:** delete it (keep the assertion that the administrator was asked, and the destination/manifest assertions).

13. **Tests read `StartAtLogin`'s private key by name.** `LauncherKit/Tests/LauncherCoreTests/StartAtLoginTests.swift:6` and `MoveToApplicationsTests.swift:140` read `"startAtLoginTurnedOffByQuit"`. Rule (tdd `tests.md`): verify through the interface, not the storage. T20's wording is "the suite holds a key beside `settings`" / "only `settings` remains". **Fix:** assert on the suite's key set (a key other than `settings` is present / the keys are exactly `["settings"]`), and on behaviour (the next opening by hand turns the login item on), without naming the key.

## Not fixed (decided)

- Order assertions on the shared effect log (`MoveToApplicationsTests`, `ReplacingOtherCopiesTests`, `LifecycleTests`): kept. The plan pins the move's order and the first run's effects-before-save order by tests on purpose (decision 9, crash convergence).
- `Launch`, "resident", `open(request:)` names; start-at-login split between `Lifecycle` (suspend) and `Launcher.openedByHand` (enrol/resume); `InstallOutcome.failed(reason:)` carrying text: all as the plan designed them.
- Shared `dlsym` helper, `MoveDialogPresenter`'s double switch, the `(opensWindow, eject)` pair: left as is.
- `--image-only`, the background generator, deleting `docs/menubar-window.png`: asked for by the slice briefs.

## Done when

- [ ] Every fix 1-13 is in, with the T34 nested-copy case added.
- [ ] Full gate green with no warnings from this branch's files: delete `LauncherKit/.build`, run `Scripts/test.sh` from the worktree root; then `xcodegen generate` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug build CODE_SIGNING_ALLOWED=NO`.

Report: what you changed per item, any item you could not do and why, the test counts, and the gate results.
