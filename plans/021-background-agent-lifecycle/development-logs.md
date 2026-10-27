# Development logs: Trackpad Launcher runs in the background, with a settings window instead of a menu bar icon

## Specify
- R2's single-instance rule would stop a copy outside /Applications from showing the move dialog → R2 scoped to the /Applications copy; other copies only show the move dialog.
- Dragging a new build over a running one, or upgrading from the menu bar version, left two builds fighting → new R3: opening the /Applications copy replaces a running different build or a copy from another place.
- "No way to run outside /Applications" contradicted the login and development-build exceptions → limited to release builds opened by hand; ~/Applications counts as outside.
- The app menu's "Quit Trackpad Launcher" would only close the window while the button of the same name quits → the app menu item reads "Close Settings" (⌘Q); the Dock's "Quit" label is an accepted oddity.
- "First run" was undefined → first run means no saved settings on the Mac; later runs never prompt for Accessibility and show the hint instead.
- Which Login Items state Quit restores was ambiguous → Quit turns starting at login back on only when Quit itself turned it off; a System Settings choice is kept.
- Missing scenarios: silent start at login without Accessibility, logout with the window open, Escape, closing under the Other… chooser, upgrade with the login item off, an unremovable original, an un-ejectable disk image → added.
- Switcher and swap with the settings window in front were unstated → Trackpad Launcher never counts as a running or frontmost app (R15).
- R9 bundled look and behaviour → split into R10 and R11.
- Non-goals a reader would assume → added: keeping a menu bar icon, a global shortcut, refusing to downgrade.
- Rejected: moving the release command and the development-build rule out of the requirements. The user asked for the release tooling in this feature.

## Plan
- Grounding: a reopen of the running bundle reaches it as `rapp`, but another place or a bundle replaced at the same path starts a second process (probed) → every second process is resolved by `Lifecycle`, never treated as a reopen.
- Grounding: a peer's `terminate()` arrives exactly like the Dock's Quit (probed) → other copies are stopped with `forceTerminate()` and a KVO wait, not asked.
- Grounding: `NSWorkspace.requestAuthorization` needs a restricted entitlement (sourced) → the administrator path uses `AuthorizationExecuteWithPrivileges` through `dlsym`.
- Grounding: the login marker on macOS 26 is sourced only from a third-party answer → kept as open question 1, with a `SMAppService.agent` fallback that stays behind `LoginItem` and `ThisCopy`.
- Red-flag screen, candidate-2: `Launcher` absorbed peers, the move and quit classification (an owner of unrelated concerns), and its public `Phase` leaked internal stages → rejected as the base.
- Red-flag screen, candidate-1: the `Installer` port's four calls look shallow → kept, because `Lifecycle` must hand over the login item between the install and removing the original, and tests pin that order.
- Cross-judge: recommended candidate-1 (5/5/5/5/4/4 against 3/4/3/4/3/4), which agrees with the orchestrator's pick → candidate-1 is the base.
- Cross-judge: candidate-2 routed a reopen of a login-started copy outside /Applications to the window (R18), stopped the running copy before the admin prompt (R21), kept the login flag in the shared `settings` record (stale saves, dropped by older builds), and its sender-based login fallback is undercut by F1 → none grafted.
- Cross-judge: suggested grafts → taken: the pure `Route` table, one `Location` value, the installer split (`BundleInstall`, `PrivilegedInstall`, `DiskImages`), `CodeSignature.build(of:)`, the committed disk-image background. Rejected: `FrontmostApp` activation memory (Spotlight would count as the app before, and it claimed a window swipe F29 rules out).
- Verification: both candidates treated only a copy directly in /Applications as installed, while R18 says "outside /Applications" → installed means anywhere inside /Applications.
- Verification: the disk-image background under `assets/` would be bundled into the app (`assets/*.png` are resources) → it moves to `Scripts/release/`.
- Verification: candidate-1 stamped versions at release for R3 → a post-fan-out check showed LaunchServices starts a new process for a same-version bundle replaced in place → stamping dropped, since no requirement asks for it.
- Verification: three Core doc comments spelled confined tokens (`keyAELaunchedAsLogInItem`, `kAEQuitReason`, `SMAppService`), which the source scan reads → reworded.
- Test planner: the sudden-termination claim for the install contradicted `shouldEnd(.moving)` → dropped; the move's order carries the guarantee.
- Test planner: "development build leaves login alone" broke R5 for a development copy in /Applications, and the release-only paths could not be checked by hand without a Developer ID certificate → any copy inside /Applications is `installed`; a development-only `--as-release-build` argument.
- Test planner: `Administrator` had no shape → `run(script:arguments:)` placed below the script, so the real script runs in tests.
- Test planner: a copy that survives `forceTerminate()` leaves the opened copy blank → rejected as a design change, because no deadline is allowed; recorded as an accepted tradeoff.
- Test planner: the copies' start order had no test handle and an undefined missing date → a pure strict total order, `SystemRunningCopies.started(_:before:)`, with a missing date latest.
- Test planner: the installer's "never a mix" promise contradicted the admin path's rename gap, and the aside copy could stay in /Applications → the aside goes into the staging folder; the port doc states the gap.
- Test planner: `isTranslocated` compared URLs, and a trailing slash would make the installed copy ask to move → stored from macOS; paths compared standardized; `ThisCopy.location(of:…)` as the test handle.
- Test planner: `Location`, `DiskImage`, `RunningCopy` and `CopyID` had no public initialisers → added.
- Test planner: the `removeItem(` confinement clashed with the installer's comments and its cancel path → every file operation goes through `BundleInstall`.
- Test planner (second pass): the admin script's failure paths could report `.failed` with /Applications changed → the script moves the aside copy back when the second move fails, and ignores a failed removal of the aside copy.
- Phase D: the domain model and the architecture doc were updated at planning → the slices' doc checkboxes now check that what was built still matches them.
