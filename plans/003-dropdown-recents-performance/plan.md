# Plan: Instant app picker with recent apps first

## Problem statement

Opening an app picker feels slow. The picker reads every installed app from disk each time it opens, so the menu shows up only after that work is done.

The picker lists every installed app alphabetically. The apps the user reaches for most often sit deep in a long list, so the user scrolls to find them.

## Solution

The app picker opens instantly. Its list is ready before the user clicks, and stays up to date in the background.

The picker shows recent apps first: the 10 installed apps the user opened most recently, newest first. A divider follows, then every other installed app alphabetically. Each app appears once. *Other…* and *None* stay at the bottom.

This plan changes R5 in `plans/001-trackpad-launcher-app/plan.md`. R5 required the picker to re-read installed apps on every open. R4 here lets installed and removed apps show up after a short lag, so the picker can open instantly. Recent apps refresh each time the launcher window opens. R5's list of folders, *Other…* and *None* still hold.

## Requirements

### R1. The picker opens instantly
An app picker's menu MUST appear within 100 ms of the click. This MUST hold on every open, including the first open after Trackpad Launcher starts.

#### Scenario: First open after login
- **GIVEN** Trackpad Launcher has just started at login and 120 apps are installed
- **WHEN** the user opens the launcher window and clicks the 1-finger picker
- **THEN** the menu appears within 100 ms, with all apps and their icons

#### Scenario: Opening a picker while the list refreshes
- **GIVEN** the user has just installed an app and Trackpad Launcher is still refreshing the list
- **WHEN** the user opens a picker right away
- **THEN** the menu appears within 100 ms
- **AND** the menu may not yet show the new app

### R2. Recent apps come first
The picker MUST list up to 10 recent apps at the top. Recent apps MUST be the installed apps the user opened most recently, as macOS's Spotlight records it, newest first. The order MAY lag behind the very latest launches; it need only be roughly current. Opened means launched. Switching to an app that is already running does not make it more recent. Only apps the picker already lists count; an app opened from elsewhere, such as ~/Downloads, does not. Finder counts like any other listed app. Recent apps have no age limit: the 10 most recently opened count, however long ago. All four pickers MUST show the same recent section.

#### Scenario: Most recently opened first
- **GIVEN** the user opened Figma, then Slack, then Arc, all installed in /Applications
- **WHEN** the user opens a picker
- **THEN** the list starts with Arc, Slack, Figma, in that order

#### Scenario: App opened by a gesture
- **GIVEN** Figma is not running and the 3-finger gesture is assigned to Figma
- **WHEN** the user performs the 3-finger gesture, waits a minute, then opens the launcher window and a picker
- **THEN** Figma is in the recent section

#### Scenario: Switching to a running app
- **GIVEN** Arc has run since login and the user has since opened 10 other listed apps
- **WHEN** the user switches to Arc, then opens a picker
- **THEN** Arc is below the divider

#### Scenario: More than 10 recent apps
- **GIVEN** the user opened 15 different installed apps
- **WHEN** the user opens a picker
- **THEN** the top section holds the 10 most recently opened, and the other 5 appear in the alphabetical section

#### Scenario: Fewer than 10 recent apps
- **GIVEN** the user has only ever opened three listed apps
- **WHEN** the user opens a picker
- **THEN** the recent section holds those three apps, then the divider, then every other installed app

#### Scenario: App opened from outside the listed folders
- **GIVEN** the user just opened an app that lives only in ~/Downloads
- **WHEN** the user opens a picker
- **THEN** that app is not in the list

#### Scenario: Same recent section in every picker
- **WHEN** the user opens the 1-finger picker, then the 4-finger picker
- **THEN** both show the same recent apps in the same order

### R3. Recent apps are separated and not repeated
A divider line MUST separate recent apps from the rest. Below the divider, the picker MUST list every other installed app alphabetically, without the recent apps. *Other…* and *None* MUST follow, as before. An app assigned via *Other…* from outside the listed folders MUST still show in the gesture's row, as plan 001 requires. It MUST NOT be added to the picker list.

#### Scenario: A recent app appears once
- **GIVEN** Arc is a recent app
- **WHEN** the user opens a picker
- **THEN** Arc appears above the divider and nowhere below it

#### Scenario: Assigned app is checked wherever it sits
- **GIVEN** the 2-finger gesture is assigned to Figma and Figma is a recent app
- **WHEN** the user opens the 2-finger picker
- **THEN** Figma is checked in the recent section

#### Scenario: App assigned from outside the listed folders
- **GIVEN** the user assigned an app in ~/Downloads to the 1-finger gesture via *Other…*
- **WHEN** the user opens the launcher window and then a picker
- **THEN** the 1-finger row still shows that app
- **AND** that app is in neither section of the picker

### R4. The list stays current
The recent section MUST refresh each time the launcher window opens. It MAY miss apps opened moments before; the picker MUST still open within 100 ms, showing the last known recent apps. An app installed or removed MUST show up correctly in the picker within 5 seconds of the change. This MUST hold whether the launcher window is open or closed.

#### Scenario: App opened while the window was closed
- **GIVEN** Notion is installed but not among the recent apps
- **WHEN** the user opens Notion, waits a minute, then opens the launcher window and a picker
- **THEN** Notion is in the recent section

#### Scenario: Newly installed app
- **GIVEN** Trackpad Launcher is running
- **WHEN** the user installs Slack into /Applications, waits 5 seconds and opens a picker
- **THEN** Slack is in the list

#### Scenario: Removed app
- **GIVEN** Figma is a recent app
- **WHEN** the user moves Figma to the Trash, waits 5 seconds and opens a picker
- **THEN** Figma is in neither section

### R5. No recent data, no recent section
When Spotlight has no usage data for any listed app, the picker MUST show no recent section and no extra divider. It MUST list every installed app alphabetically, as before.

#### Scenario: Spotlight indexing off
- **GIVEN** the user has turned Spotlight indexing off for the startup disk
- **WHEN** the user opens a picker
- **THEN** the list is every installed app alphabetically, then *Other…* and *None*

### R6. No work while idle
While nobody uses the picker, Trackpad Launcher MUST do no periodic work to keep it current. It MUST only react when the launcher window opens or apps are installed or removed.

#### Scenario: Idle hour
- **GIVEN** Trackpad Launcher is running
- **WHEN** an hour passes with the launcher window closed and no app installed or removed
- **THEN** Trackpad Launcher uses no CPU for the picker during that hour

## Non-goals

- **Section headers such as "Recent".** The user chose a divider line only.
- **Changing the number of recent apps.** 10 is fixed; there is no setting.
- **Search or filtering in the picker.** Not requested; the menu's built-in type-to-select still works.
- **Tracking app use inside Trackpad Launcher.** Recent apps come from macOS's records, so apps launched by gestures and by other means count the same.
- **Performance tests.** The product overview asks for the most performant path, not for tests that measure it.
- **Listing apps from more folders.** The listed folders stay those of R5 in plan 001.
- **Pinning or favourite apps.** Not requested.
- **Recent apps per gesture.** One shared list is simpler and matches the request.
- **Hiding or clearing the recent section.** Not requested; macOS already shows the same data in its own Recent Items.


## Implementation Decisions

Measured on this Mac with 108 listed apps (probes under `.temp/planner/probes/`):

| Step | Cost |
|------|------|
| Enumerate the listed folders and read each Info.plist | 64–183 ms |
| Read every listed app's Spotlight last-used date | 44–67 ms |
| Draw every workspace icon at 16 pt | 28 ms with macOS's icon cache warm, 1.1 s cold |
| Draw the same icons pre-rendered into small bitmaps | 1 ms |
| Build 79–108 menu items with images | 15–33 ms |

Today everything but the Spotlight read runs on the main actor between the click and the menu. The design moves every disk, Spotlight and icon-drawing step off the click path, so a click pays only for building menu items from values already in memory.

### Where the list lives, and when it changes
- **One shared list.** The picker's list becomes state the `Launcher` model owns: `installedApps: InstalledApps`. All four app pickers render that one value, so they show the same recent section (R2). A picker builds its menu from it without touching the disk (R1).
- **The first read.** `Launcher.init` reads the list once, synchronously, from the catalog it already holds, the way it already resolves `rows`. The composition root builds the launcher and then the shell before the run loop starts, so the list exists before the app handles its first event, and so do the icons (see Icons). No picker can open on an empty list, not even in the first-launch window (R1 "every open, including the first open after Trackpad Launcher starts"). This answers the reason plan 001 gave for rejecting a kept list: "the first open would show an empty picker until the enumeration finished".
- **Later changes.** After that, the list changes only through the app scanner, on exactly three triggers:
  - `start()`;
  - every `openWindow()` call (R4 "refresh each time the launcher window opens");
  - the scanner's own push after an install or removal in the listed folders (R4).

  Nothing else starts a scan, and there is no timer (R6).
- **One scan shape.** Every refresh is one full scan: enumerate the listed folders, read each listed app's Spotlight last-used date, order. It is one convergent operation, in the spirit of `reconcile`, with no separate "dates only" path.
- **No blank list.** The model keeps the last list until a newer scan arrives, and never empties it when a scan starts (R4 "showing the last known recent apps").
- **Equal scans.** The model assigns every scan it receives. Observation does not notify on an equal value (probed on this toolchain), so an unchanged scan re-renders nothing.
- **Plan 001.** This supersedes plan 001's decision to enumerate in `menuNeedsUpdate` and never cache. That covers its tradeoff "any cache reintroduces the staleness R5 forbids" and its manual check "the picker refreshes each time it opens". R4 here replaces that part of R5.

### Domain types (LauncherCore)
- **`InstalledApps`** (value; `Equatable`, `Sendable`):
  - `recent: [AppEntry]`: at most 10, newest launch first.
  - `others: [AppEntry]`: every other listed app, in Finder order (`localizedStandardCompare`, as today), without the recent ones.
- **The ordering.** One pure internal initializer builds `InstalledApps` from the listed entries (already in Finder order) and each entry's last-opened date:
  1. Dated entries are sorted newest first; ties keep Finder order.
  2. The first 10 are `recent`; everything else is `others`.

  An entry without a date is never recent, and there is no age limit. Each bundle ID appears once, because the enumeration already keeps one entry per bundle ID.
- **`PickerItem`** (enum; `Equatable`, `Sendable`): `.app(AppEntry, checked: Bool)`, `.divider`, `.other`, `.unassigned`.
- **`InstalledApps.pickerMenu(checking: RowApp) -> [PickerItem]`**: an app picker's menu, top to bottom:
  1. the recent apps;
  2. a divider, only when both the recent apps and the others are non-empty;
  3. the others;
  4. a divider, only when any app precedes it;
  5. *Other…*;
  6. *None*.

  The entry whose bundle ID equals the row's present app is checked, in whichever section it sits. An unassigned or missing row, or a row app outside the list, checks nothing. This is the one place R3's and R5's menu shape lives. The view only maps items to menu items, the same way `noticeName` and `cornerName` keep values the views quote in core, where they are tested.

### AppCatalog (LauncherCore)
- **`lastOpened`.** A third injected closure beside `registeredCopies`: `lastOpened: @Sendable (URL) -> Date?`, the time the app bundle at that URL was last launched, as Spotlight records it; nil when unknown. Tests inject a record; `AppCatalog.system` reads Spotlight.
- **`roots`** becomes public and read-only, so the real scanner watches exactly the folders the catalog enumerates.
- **`installedApps()`** returns `InstalledApps` instead of `[AppEntry]`. It runs the existing enumeration (folders and subfolders, Finder, one entry per bundle ID, first root wins), reads `lastOpened` for each listed entry, then applies the pure initializer. Dates are read only for listed entries. That is why an app opened from ~/Downloads is never recent (R2), and an app assigned through *Other…* is never listed (R3).
- **No cache here.** `installedApps()` still enumerates on every call. The cache is the model's state, not the catalog's. The existing `everyCallEnumeratesAfresh` test keeps guarding that, because the scanner relies on each call reading the disk anew.

### New port: AppScanner (LauncherCore)
- **Interface.** `@MainActor protocol AppScanner: AnyObject`, with `onScan: (@MainActor (InstalledApps) -> Void)?` and `scan()`.
- **Contract.**
  - `scan()` returns at once. The scan runs away from the main actor, and its result reaches `onScan` on the main actor.
  - Requests made while a scan runs coalesce into exactly one more scan after it.
  - The scanner also scans by itself after an app is installed, removed or renamed in the catalog's roots, whether or not the launcher window is open, and at no other time.
- **Adapters.** There are two, as the architecture requires: `SystemAppScanner` in LauncherPlatform and `InMemoryAppScanner` in the tests. Both call the same `catalog.installedApps()`; they differ only in thread and trigger, which is what varies across this seam.
- **Why a port.** The threading stays in the adapter and the model stays synchronous. Plan 001 made the same choice for the hardware port, after rejecting a model-owned `Task` hop whose negative tests could not fail. A temp directory could drive the real scanner, and the architecture usually keeps such types concrete. It now names the exception: an adapter that delivers asynchronously sits behind a port, so the model's tests stay synchronous.
- **Model changes.**
  - `Launcher.init` gains `scanner: any AppScanner`, and reads `installedApps` once from the catalog.
  - `start()` sets `onScan` to assign `installedApps`, then calls `scan()`.
  - `openWindow()` calls `scan()` after re-resolving the rows.

### SystemAppScanner (LauncherPlatform)
- **The stream.** One FSEvents stream over `catalog.roots`, created at init:
  - callbacks on the main queue, with a latency of 1 s;
  - the watch-root flag, paths delivered as CF types, events from now on;
  - stopped, invalidated and released in an isolated deinit.

  The callback reaches the adapter through an unretained context pointer and `MainActor.assumeIsolated`, as the IOKit notifications in `MultitouchTrackpads` do.
- **Which events count.** A callback requests one scan when any of its events counts. An event counts when either holds:
  - it carries the root-changed, must-scan-subdirectories, user-dropped or kernel-dropped flag;
  - its path does not continue past a `<name>.app/Contents/` folder.

  So installs, removals, renames and Info.plist writes count. A Finder-style copy creates the bundle folder first, and its later Info.plist write is reported at `X.app/Contents/`. Writes deeper inside a bundle do not count (R6): updaters staging files, apps writing into their own bundles, and a bundle's `Resources/` (staged probe). Anything such a write could change, such as a localized name, is picked up by the next window-open scan.
- **Paths.** The rule looks only at path components and never compares an event path with a root. So `/var` against `/private/var`, and the different forms FSEvents reports for root events, do not matter.
- **Root changes.** A root-changed event (a root created, deleted or renamed, often ~/Applications) re-creates the stream after the callback returns, and only then requests its scan, so a change made between the two streams is still seen. The probes showed that nothing from inside a root created after the stream started is reported until the stream is re-created, and everything is reported afterwards, including after the root is deleted and created again.
- **Timing.** In the probes, callbacks arrive 0.2–1.0 s after a change.
- **Scans.** Scans run in an explicitly concurrent function over the `Sendable` catalog: at most one in flight and one pending.
- **Why also a folder watch.** R4 bounds installs and removals at 5 s from the change, with the window open or closed. A scan started when the window opens lands 100–250 ms later, after a quick click.

### Spotlight last-used dates (LauncherPlatform)
- **The read.** `AppCatalog.system`'s `lastOpened` reads `kMDItemLastUsedDate` for one URL through `MDItemCreateWithURL` and `MDItemCopyAttribute`, in an internal static function the adapter test can call.
  - It compiles from nonisolated code under Swift 6.
  - It runs off the main actor (probe: 49–58 ms for 79 apps).
  - It needs no permission for a non-sandboxed app reading these folders.
- **What counts as opened.** "Opened means launched" is Spotlight's own rule, which R2 adopts by name. The app adds no rule of its own about launches or activations.
- **Rejected:**
  - A live `NSMetadataQuery`: it would wake the app on every app launch anywhere, breaking R6's "only react when the launcher window opens or apps are installed or removed".
  - One `MDQuery` over the roots: cheaper when warm, but it answers with paths that must be mapped back to entries, including system apps that live in cryptex paths.
  - The `com.apple.lastuseddate#PS` extended attribute: present on none of the 108 apps.

### Icons (LauncherUI)
- **The cache.** `AppIcons`, one per shell and shared by the four pickers, caches 16-pt bitmap icons (1× and 2× pixels). Each is keyed by app URL and stamped with the bundle's Info.plist modification date and the appearance it was drawn in.
- **Appearance.** Icons are drawn inside the appearance captured on the main actor (`NSApp.effectiveAppearance`, drawn with `performAsCurrentDrawingAppearance`), so they follow light and dark mode. A change of appearance changes every stamp, and the next pass redraws.
- **`render(_ apps: [AppEntry])`** hands the apps, that appearance and the cached stamps to one pass off the main actor. The pass reads each bundle's Info.plist modification date, and looks up and draws only the apps whose stamp is new or changed. The results merge on the main actor; overlapping passes are harmless, because the last write wins.
- **When passes run.**
  - The shell's first pass, in its init, runs before the app's first event and is waited for. It uses the same drawing, spread across cores, so the first menu has every icon.
  - Later passes run when the window opens, and whenever `launcher.installedApps` changes, with the listed apps plus the rows' present apps.

  The window-open pass refreshes the icon of an app updated in place, and follows an appearance change. When nothing changed it costs only the stamp reads.
- **Reading an icon.** There are two reads:
  - `cachedIcon(for:)` returns the cached bitmap or, on a miss, a generic app icon drawn once at init. It never draws, and the menu uses it, so the click path never draws an icon. An app listed a moment ago shows the generic icon until its pass lands, then its own icon from the next open.
  - `icon(for:)` draws a missing icon on the spot and caches it. Only the closed button uses it, for a row app outside the list that was just picked through *Other…*.
- **No eviction.** Entries are never evicted; a removed app's bitmap (about 5 KB) stays for the session.
- **Why drawing off the main actor is safe.**
  - The SDK does not isolate `NSWorkspace` to the main actor.
  - `NSImage` is `Sendable`, and its header notes an image draws on whatever thread draws it.
  - `NSGraphicsContext` keeps a per-thread context stack.
  - The probe rendered 79 icons off the main actor under Swift 6 strict concurrency.

  The slice's Thread Sanitizer and Main Thread Checker runs check it in the real app.

### App picker, shell and composition root (LauncherUI, app target)
- **`AppPicker`** takes `app: RowApp`, `installedApps: InstalledApps`, the two icon reads, `choose` and `chooseOther`.
  - `menuNeedsUpdate` maps `installedApps.pickerMenu(checking: app)` to menu items: an app item with `cachedIcon(for:)`, a separator, "Other…", "None". It then selects the checked app.
  - No disk, Spotlight or icon-drawing work runs on the click path.
  - The closed button holds only the row's current app, as today, now drawn with `icon(for:)`.
  - A list that arrives while the menu is open is applied at the next open (the existing `isMenuOpen` guard).
- **Views and actions.** `GestureRowView` passes `launcher.installedApps`. `LauncherActions` drops `installedApps` and gains the two icon reads.
- **`MenuBarShell.init(launcher:)`** drops its `catalog` parameter and owns the `AppIcons`. It runs the first icon pass in its init. It calls `render` from its window-show path and from an `Observations` loop over `launcher.installedApps`.
- **The composition root** builds `AppCatalog.system` once. It hands the catalog to `SystemAppScanner(catalog:)` and to `Launcher` (which still uses it for `locate` and `entry(at:)`), and passes the scanner to `Launcher`. The order is unchanged: launcher, shell, `start()`, run loop.

### Startup cost (accepted)
- **The cost.** The first scan and the first icon pass run before the menu bar icon appears. Launch gets about 0.3 s longer with warm caches, and up to 1–2 s on a cold login.
- **Why it is acceptable.** At login nobody waits for a menu bar app. On a first launch, the window appears that much later.
- **What it buys.** No picker can open before its list and icons exist.

### Docs
- **Domain model:** new **Installed apps** and **Recent apps** entries; **App picker** updated to the new menu.
- **Architecture:**
  - FSEvents for the app folders added to the list of pushes.
  - The port exception for adapters that deliver asynchronously.
  - Work that would block a click (folder scans, Spotlight reads, icon drawing) runs off the main actor in explicitly concurrent functions, and only results hop back.

## Testing Decisions

### Strategy

Three seams, highest first.

1. **`Launcher` through `World`** (LauncherCoreTests), the existing high seam.
   - **`InMemoryAppScanner(catalog:)`, new in `World`.**
     - Its `scan()` and `foldersChanged()` (the FSEvents stand-in) run the real `catalog.installedApps()` synchronously and push the result.
     - It counts `scan()` requests in `scanRequests`.
     - `holdScans()` defers deliveries until `deliverHeldScan()`, which then scans once.
   - **`recordLaunch(_ name:, in:)`, new in `World`: the Spotlight stand-in**, in the same pattern as `Registry`.
     - It stores a strictly increasing date: the reference date (1 January 2001) plus one second per launch, so no test depends on how recent a launch is.
     - Dates are keyed by the bundle's canonical path (`resolvingSymlinksInPath().path`, no trailing slash), in a `Mutex`-backed record.
     - The catalog's `lastOpened` closure computes the same key from the URL the enumeration hands it.
   - **What it observes.**
     - `launcher.installedApps`: `recent` and `others`, compared by name.
     - `pickerMenu(checking:)`, through a test projection: an app as its name, prefixed with "✓ " when checked; a divider as "—"; then "Other…" and "None".
     - The rows, and the scan request count.
   - **What it misses:** threading, FSEvents, Spotlight, icons and the AppKit menu.
   - **Resembles:** `LauncherKit/Tests/LauncherCoreTests/AppResolutionTests.swift`.
2. **`SystemAppScanner` over a temp tree** (LauncherPlatformTests).
   - Real FSEvents and real off-main scans, over a catalog whose `lastOpened` returns nothing, or blocks on a gate the test holds.
   - Each push is awaited with a 5 s bound, never polled. The one negative check waits 3 s for silence.
   - It misses the model.
   - Resembles `LauncherKit/Tests/LauncherPlatformTests/SystemTrackpadPreferencesTests.swift`.
3. **The Spotlight reader against `mdls`** (LauncherPlatformTests). `mdls` is Spotlight's own command-line reader, an independent source in the way `/usr/bin/defaults` is for the preferences adapter. Ordering is left to seam 1.

**Existing tests.**
- The existing `AppCatalogTests` (plan 001 T45, T46) keep their assertions and read `installedApps().others`. With no dates injected, nothing is recent.
- `SourcePolicyTests` stays as it is and keeps proving there is no timer, which T13 and T14 rely on for R6.

**Faked:**
- Spotlight: the injected launch record.
- FSEvents and the off-main hop: the in-memory scanner, at seam 1 only.
- The clock: launch dates are synthetic and increasing.

**Real:** temp folders of fake bundles, `AppCatalog`, the ordering, the model, and at seam 2 the real FSEvents and concurrency.

**R2's Spotlight scenarios.** "App opened by a gesture" and "Switching to a running app" follow Spotlight's own rules for what counts as opened, which R2 adopts by name. T11 proves the app reads exactly Spotlight's record, and T7 proves the window-open refresh picks a new record up.

**Not tested: R1's latency.** Performance tests are a non-goal; it is checked by hand below.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2, R3 | Launcher | `World(apps: ["Figma", "Slack", "Arc", "Notion", "Zed"])`; `recordLaunch` Figma, then Slack, then Arc; `start()`. → `installedApps.recent` names `== ["Arc", "Slack", "Figma"]`; `others` names `== ["Finder", "Notion", "Zed"]` | R2 scenario "Most recently opened first"; R3 scenario "A recent app appears once" and "every other installed app alphabetically, without the recent apps" |
| T2 | R2 | Launcher | Fifteen apps "App 01" … "App 15"; `recordLaunch` in the order 08, 03, 12, 01, 15, 06, 10, 02, 14, 05, 09, 13, 04, 11, 07; `start()`. → `recent` names `== ["App 07", "App 11", "App 04", "App 13", "App 09", "App 05", "App 14", "App 02", "App 10", "App 06"]`; `others` names `== ["App 01", "App 03", "App 08", "App 12", "App 15", "Finder"]`. The launch dates lie in 2001 | R2 scenario "More than 10 recent apps" and "no age limit: the 10 most recently opened count"; both lists worked by hand from the launch order |
| T3 | R2 | Launcher | `World(apps: ["Arc", "Notion", "Slack", "Zed"])`; `recordLaunch` Notion, then Finder (in the CoreServices folder), then Arc; `start()`. → `recent` names `== ["Arc", "Finder", "Notion"]`; `others` names `== ["Slack", "Zed"]` | R2 scenario "Fewer than 10 recent apps"; R2 "Finder counts like any other listed app" |
| T4 | R2, R3 | Launcher | `World(apps: ["Arc"])`, Sketch installed in Downloads; `start()`; `setAssignment(.appBundle(at: Downloads/Sketch.app), for: .one)`; `recordLaunch` Arc, then Sketch (in Downloads); `openWindow()`. → `recent` names `== ["Arc"]`; no entry named "Sketch" in `recent` or `others`; `app(for: .one) == .present(world.app("Sketch", in: world.downloads))`; the projection of `pickerMenu(checking: app(for: .one))` has no "✓ " item | R2 scenario "App opened from outside the listed folders"; R3 scenario "App assigned from outside the listed folders" (the row still shows it; it is in neither section) |
| T5 | R2, R3 | Launcher | `World(apps: ["Arc", "Figma", "Zed"])`; `start()`; Figma on `.two`, Zed on `.four`; `recordLaunch` Figma, then Arc; `openWindow()`. → projection of `pickerMenu(checking: app(for: .two)) == ["Arc", "✓ Figma", "—", "Finder", "Zed", "—", "Other…", "None"]`; for `.four` it is `["Arc", "Figma", "—", "Finder", "✓ Zed", "—", "Other…", "None"]` | R3 scenario "Assigned app is checked wherever it sits"; R3 "A divider line MUST separate recent apps from the rest" and "*Other…* and *None* MUST follow, as before" (today's menu: apps, separator, Other…, None); R2 scenario "Same recent section in every picker" (both rows share one recent section; a per-row ordering fails it) |
| T6 | R5 | Launcher | `World(apps: ["Arc", "Zed"])`, no launch recorded; `start()`. → `recent == []`; projection of `pickerMenu(checking: .unassigned) == ["Arc", "Finder", "Zed", "—", "Other…", "None"]` | R5 "no recent section and no extra divider", "every installed app alphabetically, as before"; R5 scenario "Spotlight indexing off" |
| T7 | R4 | Launcher | `World(apps: ["Arc", "Notion"])`; `recordLaunch` Arc; `start()`; `closeWindow()` → `!isWindowOpen`, `recent` names `== ["Arc"]`. `recordLaunch` Notion; `openWindow()` → `["Notion", "Arc"]`. `closeWindow()`; `recordLaunch` Arc; `openWindow()` → `["Arc", "Notion"]` | R4 scenario "App opened while the window was closed"; R4 "MUST refresh each time the launcher window opens" (the second opening) |
| T8 | R4 | Launcher | `World(apps: ["Arc", "Figma"])`; `recordLaunch` Figma; `start()` → `recent` names `== ["Figma"]`. `scanner.holdScans()`; `recordLaunch` Arc; `openWindow()` → `recent` names still `== ["Figma"]` (the last known list, not emptied). `scanner.deliverHeldScan()` → `["Arc", "Figma"]` | R4 "It MAY miss apps opened moments before; the picker MUST still open … showing the last known recent apps" |
| T9 | R4 | Launcher | `World(apps: ["Figma", "Zed"])`; `recordLaunch` Figma; `start()`; `closeWindow()` → `!isWindowOpen`. `world.install("Slack")`; `scanner.foldersChanged()` → `others` names `== ["Finder", "Slack", "Zed"]`. `world.trash("Figma")`; `scanner.foldersChanged()` → `recent == []`, no entry named "Figma" in either section; `!isWindowOpen` throughout | R4 scenarios "Newly installed app" and "Removed app"; R4 "whether the launcher window is open or closed" |
| T10 | R4 | SystemAppScanner | Temp tree: `Applications/Zed.app`; `UserApplications` absent. Catalog over both roots, no extras, no registered copies, no dates; the adapter is created and `onScan` set. `scan()` → a scan whose `others` names `== ["Zed"]` arrives within 5 s. Then, with no `scan()` call: (a) create `Applications/Slack.app/Contents`; await the scan it causes (Slack not listed); write Slack's Info.plist → a scan listing Slack within 5 s of the write. (b) Delete `Slack.app` → a scan without Slack within 5 s. (c) Create `UserApplications/Arc.app/Contents` (the root appears); await the scan it causes; write Arc's Info.plist → a scan listing Arc within 5 s of the write | R4 "within 5 seconds of the change … whether the launcher window is open or closed" (the adapter has no window input). Staged and re-create probe outputs: a Finder-style copy reports its Info.plist write at `X.app/Contents/`, and nothing inside a root created after the stream started is reported until the stream is re-created |
| T11 | R2 | Spotlight reader | Enabled only when `mdls` reports a last-used date for at least one app `AppCatalog.system.installedApps()` lists (skipped, not passed, on a Mac without Spotlight data). One `mdls -raw -name kMDItemLastUsedDate <every listed path>` run (NUL-separated; `(null)` means none). → For every listed app, the reader's date for its URL equals the `mdls` date, to the whole second, and both are absent together. `AppCatalog.system.installedApps().recent` is non-empty, and its first app's `mdls` date is the newest `mdls` date among all listed apps | R2 "as macOS's Spotlight records it"; `mdls`, Spotlight's own reader |
| T12 | R4 | SystemAppScanner | Catalog over `Applications/Zed.app` whose `lastOpened` blocks on a gate the test holds. `scan()` (that scan blocks); write a complete `Applications/Slack.app`; wait 2 s, so the FSEvents callback lands while that scan still runs; open the gate. → The held scan delivers, then a scan listing Slack arrives within 5 s of opening the gate | R4 "within 5 seconds of the change" for a change made during a scan. FSEvents probes: callbacks arrive within 1 s, so 2 s puts the request inside the held scan |
| T13 | R6 | Launcher | `World(apps: ["Arc"])`; `start()` → `scanner.scanRequests == 1`. Then `setAssignment(.app(Arc), for: .one)`, `setHandMode(.left)`, `setHandMode(.right)`, `preferences.set(.tapToClick, rawValue: 1, for: .builtIn)` and back to 0, `hardware.attach(.magicTrackpad)`, `hardware.detach(magicTrackpad.id)`, `hardware.wake()`, `access.set(granted: true)`, a 1-finger tap (Arc comes to the front), `closeWindow()`, `dismissWindow()` → still 1. `openWindow()` → 2 | R6 "MUST only react when the launcher window opens or apps are installed or removed"; R4 "refresh each time the launcher window opens" |
| T14 | R6 | SystemAppScanner | `Applications/Zed.app/Contents/Resources` exists before the adapter starts; `scan()` → the scan arrives. Write `Zed.app/Contents/Resources/cache.bin` → no scan arrives within 3 s. Then write a complete `Applications/Slack.app` → a scan listing Slack within 5 s (the stream is still alive) | R6 "MUST only react when … apps are installed or removed" (a write inside an installed bundle is neither); staged probe (that write is reported only at `Zed.app/Contents/Resources/`) |

### Verified without a test

- **R1.** A manual timing run on this Mac (at least 100 listed apps; the probe counted 108), with the Release build installed in /Applications and registered as a login item:
  1. Log out and log back in.
  2. Start a QuickTime Player screen recording with "Show Mouse Clicks in Recording" on. Open the launcher window from the menu bar icon and click the 1-finger picker. Stop the recording, then read its frame rate in the Movie Inspector (Cmd-I) and convert 100 ms to frames at that rate: 6 frames at 60 fps.
  3. Step through the recording frame by frame. From the first frame showing the click indicator to the first frame showing the open menu: no more than 100 ms' worth of frames. The menu lists every listed app with its own icon, recent apps first.
  4. Close the menu and click the 4-finger picker: within 100 ms, with the same recent section.
  5. Close the window. In Finder, start copying an app of at least 1 GB into /Applications. While the copy runs, open the window and click a picker: within 100 ms. The new app may be absent.
  6. Click the menu bar icon and click a picker straight away, while the window-open refresh is in flight: within 100 ms.

  Why not a test: performance tests are a non-goal, and the latency is AppKit presenting a menu, which no in-process test observes.

## Further Notes

- **Finder in recents.** On this Mac Spotlight has no last-used date for Finder (`mdls` prints `(null)`): macOS starts Finder itself and never records it as opened. The app treats Finder exactly like any other listed app, as R2 says, but in practice Finder will seldom or never appear in the recent section. Worth telling the user.
- **Trackpad Launcher in its own list.** Installed in /Applications, Trackpad Launcher is listed like any app and is launched at every login. If Spotlight records login launches, it will usually sit in the recent section. Nothing filters it (not requested); the smoke run shows whether it happens.
- **Icon style.** macOS 26 lets the user pick an icon style (default, dark, clear, tinted). If that choice is not part of the effective appearance, changing it leaves the pickers on the old style until each app's stamp changes. The smoke run checks it; the remedy is adding the style to the stamp.
- **If the manual timing misses 100 ms** on slower hardware, the next step is to keep each picker's built menu items between opens, and rebuild them only when `installedApps` or the row's app changes. Building items is the only work left on the click path (15–33 ms measured here).
- **Duplicate bundle IDs.** When the same bundle ID exists in two roots, only the first root's copy is listed, and only that copy's last-used date counts. Launching the other copy does not make the app recent.
- **Plan 001 superseded in part.** These no longer apply; R4 here replaces them:
  - its R5 "each time the picker opens" rule;
  - the AppCatalog tradeoff "make the enumeration cheaper rather than cache it";
  - its manual check "R5 (the picker refreshes each time it opens)".

  Its folders, *Other…* and *None* still hold.

## Slices

### S1: Instant picker with recent apps first

**What to build:**
- The app pickers open instantly, from a list and icons Trackpad Launcher prepared before the user could click.
- Each picker starts with the up to 10 installed apps the user launched most recently, newest first. A divider follows, then every other installed app alphabetically, then *Other…* and *None*, all with their icons.
- Opening the launcher window refreshes the recent apps in the background.
- Installing or removing an app shows up in the pickers within 5 seconds, with the window open or closed.
- Nothing runs while idle.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14.

- [ ] T1–T14 pass, and the whole existing suite stays green under `swift test`, with `AppCatalogTests` reading `installedApps().others`.
- [ ] The app target builds with `xcodebuild` in Debug and Release.
- [ ] The R1 manual timing run under Verified without a test passes and is ticked in the plan.
- [ ] End-to-end smoke run on this Mac with the Release build:
  - Launch Figma, Slack and Arc from Finder, then open the window and a picker: the list starts Arc, Slack, Figma.
  - Switch to an already running app that is below the divider, then reopen the window: it stays below.
  - Fire a gesture assigned to an app that is not running, wait a minute and reopen the window: that app is in the recent section.
  - With the window closed, copy a spare app into /Applications, wait 5 s, open the window and a picker: it is listed.
  - Move a recent app to the Trash, wait 5 s and open a picker: it is in neither section.
  - Switch between light and dark mode, and change the icon style in System Settings, then reopen the window: the picker icons follow.
  - Note whether Finder and Trackpad Launcher itself appear in the recent section, for the user.
- [ ] Idle hour:
  1. Pause App Store and other automatic updates. Close the window and install or remove nothing.
  2. Run `sudo fs_usage -w -f filesys <pid>` for an hour, saved to a file: no entry touches the listed folders or any Info.plist.
  3. Meanwhile, Activity Monitor shows Trackpad Launcher at 0.0% CPU, with at most one momentary blip per minute (plan 001's R22 tolerance).
- [ ] A Debug run from Xcode with Thread Sanitizer on, and one with Main Thread Checker on, report nothing during these steps: open the window, open every picker, copy an app into /Applications, switch appearance.
