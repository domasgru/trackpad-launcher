# Development logs: Instant app picker with recent apps first

## Specify
- Instant open (R1) conflicted with "recents current up to the click" (R4) → lag limited to installs/removals (5 s); recents have no lag.
- "Recent" was undefined between launched and switched-to → defined as launched; added "Switching to a running app" scenario.
- Timing words were untestable → 100 ms open, 5 s for installs/removals.
- No scenario for gesture-launched apps, partial recents, shared recents across pickers, Other… apps → added scenarios.
- Background freshness vs. the overview's minimal-resources rule → added R6 "No work while idle".
- Weak scenarios (several pickers, removed non-recent app, "past week") → replaced or sharpened.
- Missing non-goals → added pinning, per-gesture recents, hiding/clearing recents.
- Kept the Spotlight mention in R2: it is the observable dependency R5 relies on.
- User review: recents need only be roughly current → recents refresh when the launcher window opens and are kept for instant display; R2, R4, R6 and their scenarios relaxed.

## Plan
- The first open could find an empty list (first-launch window, cold login), which R1 forbids and plan 001 had cited against a kept list → `Launcher.init` reads the list synchronously and the shell's first icon pass runs and is waited for before the run loop starts; the startup cost is recorded as an accepted tradeoff.
- The icon fallback drew on the click path → the menu reads `cachedIcon(for:)`, which never draws and shows a generic icon on a miss; only the closed button draws a missing icon (`icon(for:)`).
- T7 and T9 assumed a closed window, but a fresh `World` holds the first-launch window open → both close the window after `start()` and assert it is closed.
- Nothing tested that a request during a scan queues one more → added T12 (a gated scan, an install landing during it, a scan listing the app within 5 s).
- R6 rested on a one-time grep and an hour of Activity Monitor → added T13 (the model asks for scans only on start and window open) and T14 (a write inside a bundle triggers no scan); R6 left Verified without a test; the idle hour became a slice acceptance check using `fs_usage` and plan 001's R22 tolerance, with auto-updates paused.
- T10 could not tell a path-filtering scanner apart and its late-root step did not match reality → new probes showed nothing inside a root created after the stream starts is reported until the stream is re-created; the scanner now re-creates its stream on root-changed events, and T10 stages each install (bundle folder, then Info.plist) in both roots.
- The watch reacted to writes deep inside bundles, beyond R6's "installs or removals" → events whose path continues past `X.app/Contents/` no longer trigger a scan (the staged probe shows Info.plist writes report at `Contents/`); the next window-open scan picks up anything else.
- The fixture keyed launches by hand-built URLs that may differ in form from enumerated ones → keys are canonical paths; `PickerItem` is `Equatable` and `Sendable`; T5 and T6 compare a label projection instead of `AppEntry` values.
- T11 could pass vacuously or with the reader unwired → it is enabled only when Spotlight has a date for a listed app, and also checks that `AppCatalog.system`'s first recent app has the newest `mdls` date.
- T2's "no age limit" could not fail → synthetic launch dates start at the 2001 reference date.
- T8 cited R1, which is proved only by hand; T5's "same recent section" citation looked vacuous → T8 cites R4 only; T5 states that a per-row ordering fails it.
- `pickerMenu` could emit two dividers in a row when `others` is empty → the first divider appears only when both sections are non-empty.
- Cached bitmaps could freeze one appearance → the stamp includes the appearance, drawing uses it, and the smoke run toggles dark mode and the icon style (icon style recorded as a risk in Further Notes).
- The new port bent the architecture's "temp-directory types stay concrete" rule silently → architecture.md now names the exception for asynchronous adapters, and the off-main rule for work that would delay a click.
- QuickTime has no frame-rate setting, and Main Thread Checker cannot see `NSImage` drawing or races → the R1 run reads the recording's real frame rate; the slice adds a Thread Sanitizer run beside Main Thread Checker.

## Implement
- `AppIcons.icon(for:)` drew on the main actor, against architecture.md's off-main rule → kept, as the plan intends (closed button for a just-picked app outside the list only); architecture.md now names it as an exception, and the reads are renamed `iconDrawingIfMissing(for:)`, `renderOnMainActor`, `renderOffMainActor`.
- architecture.md's Shape omitted CoreServices → added it (FSEvents, MDItem) to LauncherPlatform.
- `recent + others` rebuilt in about 6 places → `InstalledApps.all`.
- `recentLimit` was public with no outside user → private.
- T10 did not check that Slack is absent from the scan caused by its bare `Contents` folder → asserted.
- T12's 5 s bound started after the held scan, not at gate open → the deadline is taken just before the gate opens.
- Not changed: T13's request count, multi-step T7/T9/T10, and T11 calling the Spotlight reader directly are prescribed by the plan; the scan in `start()` after `init`'s synchronous read is the plan's design.
