# Plan: VS Code window titles lead with the project

## Problem statement

The window switcher shows each window's title exactly as the app gives it. VS Code puts the file first and the project folder second: `main.swift — trackpad-launcher`. The user switches between VS Code windows to reach a project, not a file. With the file first, the project is hard to spot. The project name is also the part that gets cut short when the title is too long for the row.

## Solution

In the window switcher, VS Code window titles lead with the project: `trackpad-launcher — main.swift`. The file follows after an em dash. Any other part of the title keeps its order after the file. Titles of every other app stay exactly as the app gives them.

VS Code is the first app with a reworded title. More apps will follow. Adding the next one must be a small, self-contained change that leaves the other apps' rules alone.

## Requirements

In every scenario the frontmost app has two or more windows, so a window swipe shows the window switcher.

### R1. VS Code titles show the project first
For a window of VS Code (`com.microsoft.VSCode`) or VS Code Insiders (`com.microsoft.VSCodeInsiders`), the window switcher MUST swap the first two parts of a title split by " — " (space, em dash, space). The second part (the project) goes first and the first part (the file) goes second.

#### Scenario: File open in a project
- **GIVEN** VS Code is the frontmost app with windows titled `product-overview.md — trackpad-launcher` and `how-explorer.md — skills`
- **WHEN** a window swipe begins
- **THEN** the rows read `trackpad-launcher — product-overview.md` and `skills — how-explorer.md`

#### Scenario: VS Code Insiders
- **GIVEN** VS Code Insiders is the frontmost app with a window titled `main.swift — trackpad-launcher`
- **WHEN** a window swipe begins
- **THEN** that row reads `trackpad-launcher — main.swift`

#### Scenario: Minimised VS Code window
- **GIVEN** VS Code is the frontmost app, with a window in front and a minimised window titled `main.swift — trackpad-launcher`
- **WHEN** a window swipe begins
- **THEN** that minimised row reads `trackpad-launcher — main.swift`

#### Scenario: Lifting on a reworded row
- **GIVEN** VS Code is the frontmost app with windows titled `main.swift — trackpad-launcher` (in front) and `README.md — skills`
- **WHEN** the user lifts a window swipe on the row reading `skills — README.md`
- **THEN** the window titled `README.md — skills` is in front, with the `main.swift — trackpad-launcher` window just behind it

### R2. Parts after the second keep their order
When a VS Code title has more than two parts, every part after the second MUST stay after the file, in its original order.

#### Scenario: Non-default profile
- **GIVEN** a VS Code window titled `main.swift — trackpad-launcher — Work`
- **WHEN** a window swipe begins
- **THEN** its row reads `trackpad-launcher — main.swift — Work`

### R3. Parts keep their own text
Swapping the parts MUST NOT change the text of any part. Workspace and remote labels stay on the project part. The unsaved-changes dot stays on the file part.

#### Scenario: Multi-root workspace
- **GIVEN** a VS Code window titled `main.swift — myspace (Workspace)`
- **WHEN** a window swipe begins
- **THEN** its row reads `myspace (Workspace) — main.swift`

#### Scenario: Remote window
- **GIVEN** a VS Code window titled `main.swift — trackpad-launcher [SSH: host]`
- **WHEN** a window swipe begins
- **THEN** its row reads `trackpad-launcher [SSH: host] — main.swift`

#### Scenario: Unsaved file
- **GIVEN** a VS Code window titled `● main.swift — trackpad-launcher`
- **WHEN** a window swipe begins
- **THEN** its row reads `trackpad-launcher — ● main.swift`

### R4. Single-part VS Code titles stay unchanged
A non-empty VS Code title with no " — " separator MUST be shown exactly as VS Code gives it.

#### Scenario: Folder with no file open
- **GIVEN** a VS Code window titled `trackpad-launcher`
- **WHEN** a window swipe begins
- **THEN** its row reads `trackpad-launcher`

#### Scenario: File with no folder open
- **GIVEN** a VS Code window titled `notes.md`
- **WHEN** a window swipe begins
- **THEN** its row reads `notes.md`

### R5. Untitled VS Code windows keep the fallback
A VS Code window with an empty title MUST read as the app's name followed by " — Window N", where N is the row's position in the switcher, as for any other app. The rewording applies only to the title VS Code gives, never to the fallback text.

#### Scenario: Empty title
- **GIVEN** VS Code is the frontmost app and the window in the second row has no title
- **WHEN** a window swipe begins
- **THEN** the second row reads `Code — Window 2` ("Code" is the name macOS reports for VS Code, from its bundle's display name)

### R6. Other apps' titles stay unchanged
For every app other than VS Code and VS Code Insiders, the window switcher MUST show each title exactly as the app gives it, even when it contains " — ".

#### Scenario: Another app with an em dash title
- **GIVEN** Safari is the frontmost app with a window titled `Apple — Start Page`
- **WHEN** a window swipe begins
- **THEN** its row reads `Apple — Start Page`

### R7. Long reworded titles are cut at the end
A reworded title that does not fit its row MUST be cut short at the end with an ellipsis, like any other title, so the project stays visible.

#### Scenario: Long file name
- **GIVEN** a VS Code window titled `a-very-long-file-name-that-does-not-fit-in-the-row.swift — trackpad-launcher`
- **WHEN** a window swipe begins
- **THEN** its row starts with `trackpad-launcher — ` and ends with an ellipsis

## Non-goals

- **Other VS Code–based editors (VSCodium, Cursor, Windsurf).** The user does not use them today. They can be added later the same way.
- **File or folder names that contain " — ".** The rule swaps the first two parts, so such a title may not lead with the project. Telling the parts apart is not reliable, and the user accepts that.
- **Detecting a customised `window.title` or `window.titleSeparator` setting.** Trackpad Launcher cannot read VS Code's settings reliably. A customised title is still swapped by the same rule. A customised separator is not recognised, so the title is shown as VS Code gives it. The user accepts both.
- **A setting to turn the rewording off or to define custom rules.** The rules are built in. No one has asked to configure them.
- **Changing titles anywhere other than the window switcher.** The window switcher is the only place Trackpad Launcher shows window titles.

## Implementation Decisions

- **One new pure type in `LauncherCore`, the title rule, with one caller.** `WindowTitleRule` is one enum, as the domain model's *Title rule* is one thing: its cases are the rewordings, today one, `leadWithSecondPart(separator:)`, each of which knows how to apply itself to a title; its static table maps a `BundleID` to the rule for that app's windows; and one static function, the display title for a title of a window of a given app, reworded by that app's rule when it has one and returned unchanged otherwise, is the one thing the window switcher calls. It is internal to `LauncherCore` (nothing outside it rewords a title, and the tests prove the rules through the switcher's rows), `Sendable` so the table can be a static constant under strict concurrency, imports Foundation only, holds no state and is part of no port. Adding the next app is one table entry (its bundle identifier mapped to an existing case where its title has the same shape); a new shape of rewording is one new case with its own apply, touching no other app's entry. Nothing is configurable: the table is the rules, as the non-goals say.

- **The rewording is an enum case, not a closure or a switch on bundle identifier.** A closure-valued table was rejected because it hides the shape of each rule and cannot be described; a `switch` on bundle identifier inside the function was rejected because adding an app would then edit the function body rather than a table. Two apps that share a shape share a case value.

- **`leadWithSecondPart` is defined exactly, and keeps every part's text.** Split the title on the separator, keeping empty parts; with fewer than two parts, return the title unchanged; otherwise return the second part, then the first, then every later part in its original order, joined again with the same separator. No part is trimmed, re-cased or otherwise altered, so workspace and remote labels stay on the project part and the unsaved dot stays on the file part (R3), and a title with no separator comes back byte for byte (R4). The separator is a parameter of the case, not a constant, so an app that separates with " - " can reuse the rewording with its own separator.

- **The table today: VS Code and VS Code Insiders, both `leadWithSecondPart(separator: " — ")`.** Keyed by `com.microsoft.VSCode` and `com.microsoft.VSCodeInsiders`, the bundle identifiers R1 names (the installed VS Code's `Info.plist` confirms the first). The separator is space, em dash, space, VS Code's default `window.titleSeparator` on macOS.

- **The rule is applied in the window switcher's rows, after the untitled fallback decides.** `WindowSwitcher.rows` already decides what a row reads: today, the untitled fallback for an empty title and the raw title otherwise. It now reads: an empty title gives `Copy.untitledWindow`, as today; a non-empty title gives the title rule's display title for the content's app (`Content.app.bundleID`). The fallback text is therefore never passed to a rule (R5): the fallback itself contains " — ", so the order of these two decisions is the one line that matters, and the row's doc comment states it. The rule reads the frontmost app from the content, so visible and minimised rows, in both `WindowList` cases, go through the same line (R1's minimised scenario).

- **Nothing upstream or downstream of the rows changes.** `AppWindow.title` stays "as the app titles it", `FrontmostWindows`, `WindowSwitcher.Content`, its parse, the `SystemActions` port and `FrontmostAppWindows` are untouched. Two things depend on raw titles staying raw: the adapter matches a window to the window list by frame and title when the private window number is missing, and the test world's fake window stack is keyed by the raw name, which is what lets T4 assert the lift by the raw title. The lift identifies windows by `WindowID` and never reads a title, so lifting on a reworded row raises the right window with no change (R1's lifting scenario). The panel reads `Row.title` and nothing else about the title, so `LauncherUI` does not change; the label's one line and tail truncation apply to a reworded title as to any other (R7).

- **Why not the adapter or the shell.** Rewording in `FrontmostAppWindows` would put policy ("what the switcher shows") in `LauncherPlatform`, out of reach of the model seam where every window switcher behaviour is proved, and would break the adapter's frame-and-title matching. Rewording in `WindowSwitcherPanel` would put policy in `LauncherUI`, which has no test target. The rows are where the row's text is already decided (the fallback), so that is the one place.

- **`WindowTitleRule`'s interface.** `static func displayTitle(_ title: String, of app: BundleID) -> String`, total over any title: an app without a rule, or a title its rule leaves alone, comes back unchanged, and "" comes back "". That the fallback is decided before the rule is the rows' decision, not the rule's, and T6 guards it. The cases with their `apply(to:)` and the static table are the extension points.

- **Tests live at the model seam, with no new helper.** `World.windowWorld` installs Safari, Mail, Preview, TextEdit and Notes under `com.test.*` identifiers, which no rule matches, and sets the fake system's frontmost app directly. A VS Code test does the same with an `AppEntry` built as the running-app adapter builds one on a real Mac: bundle identifier `com.microsoft.VSCode` (or `com.microsoft.VSCodeInsiders`), the name macOS reports ("Code", "Code - Insiders"), its `/Applications` location. The window swipe reads the frontmost app from the system and never looks it up in the catalog, so no fake bundle is installed for it, and `windowWorld`'s `frontmost:` name, which must be an installed app, is left alone. No existing test changes.

- **Documents.** `docs/domain-model.md` gains a *Title rule* entry and the *Window switcher* entry says a title is reworded by the app's title rule when it has one, else shown exactly as the app gives it. `docs/architecture.md` is unchanged: policy as pure functions in `LauncherCore` is already the rule, and no port, module or concurrency decision moves.

## Testing Decisions

### Strategy

One seam, existing: the model seam, a `World` driving the real `Launcher` with touch scripts and observing `launcher.windowSwitcher?.rows` and the fake window stack, exactly as `LauncherKit/Tests/LauncherCoreTests/WindowSwitcherOnScreenTests.swift` (the list tests, `anUntitledWindowReadsAsTheAppNumberedByItsRow`) and `LauncherKit/Tests/LauncherCoreTests/WindowSwitchingTests.swift` (the lift tests) do. It observes what each row reads, which window each row is, the selection, the raises and the window stack after a lift: everything the requirements state except the drawing. It misses the drawing: that the panel puts `Row.title` in its label and that AppKit cuts it at the end, which is R7, verified without a test. The new scenarios go in one new suite beside those two files, in their style; the per-app scenario, T1, is one parametrised test whose argument rows are apps, so the next app's rule is proved by one more argument row, not a new test.

Everything we own runs for real: the recognizer, the model, `WindowSwitcher`, the title rule, `Copy`. Faked, as in every model test and with the fakes already there: the trackpad hardware (`InMemoryTrackpads`), the system (`RecordingSystemActions` with `FakeWindows`, whose stack is keyed by raw title), the permissions (`InMemoryPermissions`, Accessibility and Screen Recording granted) and the app catalog pointed at a temp directory of fake bundles; VS Code is not installed there, its frontmost entry is built as the running-app adapter builds one. No new fake.

Before and after: every expected row that leads with a project fails today, since rows read the raw title: T1's VS Code and Insiders rows, T2, T3, T4, T5's second row and T6's first row. T1's Safari row, T5's first row and T6's second row pass today and stay as guards that other apps, single-part titles and the fallback are untouched. The existing window switcher suites run unchanged and prove nothing else moved.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R6 | Model (`World`) | One parametrised test, one argument row per app: the app's name, its bundle identifier, the raw titles of its two visible windows, and the rows expected. The argument rows: "Code", `com.microsoft.VSCode`, `product-overview.md — trackpad-launcher` and `how-explorer.md — skills`, expecting `trackpad-launcher — product-overview.md` and `skills — how-explorer.md`; "Code - Insiders", `com.microsoft.VSCodeInsiders`, `main.swift — trackpad-launcher` and `how-explorer.md — skills`, expecting `trackpad-launcher — main.swift` and `skills — how-explorer.md`; "Safari", `com.test.safari` (no rule), `Apple — Start Page` and `how-explorer.md — skills`, expecting `Apple — Start Page` and `how-explorer.md — skills`. For each: that app is the frontmost app with those windows, a window swipe begins (3.5 mm down, no lift). Then the rows read as expected, the selection is on the first row, and each row's `WindowID` is the id of the raw-titled window it came from. | R1 "File open in a project": both rows literal; R1 "VS Code Insiders": `trackpad-launcher — main.swift`, with the second window and its row from "File open in a project"; R6 "Another app with an em dash title": `Apple — Start Page`, and R6's "even when it contains ' — '" for the second window, which VS Code's rule would have swapped |
| T2 | R1 | Model (`World`) | VS Code is the frontmost app with the visible window `README.md` in front and the minimised window `main.swift — trackpad-launcher`. A window swipe begins. Then the rows are `.visible` with title `README.md` then `.minimised` with title `trackpad-launcher — main.swift`, each carrying its window's id. | R1 "Minimised VS Code window": the minimised row reads `trackpad-launcher — main.swift`; the row kinds from the domain model's *Window switcher* (minimised rows last, badged) |
| T3 | R1 | Model (`World`) | VS Code is the frontmost app with visible windows `main.swift — trackpad-launcher` (in front) and `README.md — skills`. The fingers slide 3.5 mm then 12 mm down without lifting: the rows read `trackpad-launcher — main.swift` and `skills — README.md` and the selection is on the second row. Then the fingers lift. Then the fake stack is `README.md — skills`, `main.swift — trackpad-launcher`, front to back, and the gesture haptic played once. | R1 "Lifting on a reworded row": the window titled `README.md — skills` in front with `main.swift — trackpad-launcher` just behind; one gesture haptic per the domain model's *Feedback* (a lift that changes the front window) |
| T4 | R2, R3 | Model (`World`) | Parametrised over four VS Code front windows, each beside a second window `how-explorer.md — skills`: `main.swift — trackpad-launcher — Work`, `main.swift — myspace (Workspace)`, `main.swift — trackpad-launcher [SSH: host]`, `● main.swift — trackpad-launcher`. A window swipe begins. Then the first row reads, respectively, `trackpad-launcher — main.swift — Work`, `myspace (Workspace) — main.swift`, `trackpad-launcher [SSH: host] — main.swift`, `trackpad-launcher — ● main.swift`, and the second row reads `skills — how-explorer.md`. | R2 "Non-default profile"; R3 "Multi-root workspace", "Remote window", "Unsaved file": the four literal rows; the second row from R1 "File open in a project" |
| T5 | R4 | Model (`World`) | Parametrised over two VS Code front windows, each beside `how-explorer.md — skills`: `trackpad-launcher` and `notes.md`. A window swipe begins. Then the first row reads `trackpad-launcher` and `notes.md` respectively, unchanged, while the second row reads `skills — how-explorer.md`: the rule is on for this app and still leaves a single-part title alone. | R4 "Folder with no file open" and "File with no folder open": the two literal rows; the second row from R1 "File open in a project" |
| T6 | R5 | Model (`World`) | VS Code is the frontmost app, named "Code" as macOS reports it, with a visible window `main.swift — trackpad-launcher` in front and a second visible window with an empty title. A window swipe begins. Then the rows read `trackpad-launcher — main.swift` and `Code — Window 2`, in that order: the fallback is not reworded, which would have read `Window 2 — Code`. | R5 "Empty title": `Code — Window 2`; `Copy.untitledWindow` is the fallback the existing `anUntitledWindowReadsAsTheAppNumberedByItsRow` proves |

### Verified without a test

- **R7, long reworded titles are cut at the end.** The reworded title reaches the panel through the same `Row.title` as every other title: `grep -rn "\.title\b" LauncherKit/Sources/LauncherUI` returns the one reader, the row view's `title.stringValue = row.title`, and `grep -n "byTruncatingTail\|maximumNumberOfLines = 1" LauncherKit/Sources/LauncherUI/WindowSwitcherPanel.swift` returns both lines in that row view's init, so AppKit keeps it to one line and cuts it at its end against the title column plan 013 proved. Then the manual sequence in Further Notes, step 3: a VS Code window whose file name is far wider than the row shows a row that starts with `trackpad-launcher — ` and ends in "…". A test is not the right proof: the ellipsis is drawn by AppKit against the label's frame and is observable only on screen; `LauncherUI` has no test target, and the model seam can prove the text (T1–T6) but not how it is drawn.

## Further Notes

- **The running app's name for VS Code is "Code".** The installed VS Code's `Info.plist` has `CFBundleName` and `CFBundleDisplayName` both "Code", so `NSRunningApplication.localizedName`, which the running-app adapter uses, reports "Code", as the Dock and ⌘-Tab do. R5's scenario names it so (its literal was "Visual Studio Code", the bundle's file name, which the product never shows), and T6 builds the frontmost entry with that name.
- **Adding the next app**, the recipe the user asked for: one entry in the title rule's table (the app's bundle identifier mapped to `leadWithSecondPart` with that app's separator, " — " or " - "), one domain-model sentence naming the app under *Title rule*, and one argument row in T1 (the app's name, bundle identifier, two raw titles and the rows expected). An app whose title needs a different shape adds one enum case with its apply, and its own argument row. Other VS Code-based editors (VSCodium, Cursor, Windsurf) would each be one table entry with the same rewording.
- The rule rewords on every read of `rows`, which the model reads once per selection change and the presenter once per window swipe: splitting at most ten short strings, microseconds, nothing to cache.
- A customised `window.titleSeparator` is not recognised and such a title comes back unchanged, as the non-goals accept; a file or folder name containing " — " is swapped at its first separator, as the non-goals accept.
- Manual sequence, once at the end of S1, on a built app with Accessibility and Screen Recording granted, the window swipe setting on, and VS Code in front with two or more windows:
  1. Open `main.swift` in the `trackpad-launcher` folder in one window and any file in another folder in a second window; thumb in the corner, two fingers slide down: each row leads with its folder, `trackpad-launcher — main.swift` first (R1, demo).
  2. Without lifting, slide to the second row and lift: that window comes to the front, the first just behind it (R1, demo).
  3. Open a file whose name is far wider than the row (for instance `a-very-long-file-name-that-does-not-fit-in-the-row.swift`) in the `trackpad-launcher` window and window-swipe: its row starts with `trackpad-launcher — ` and ends in "…" on one line (R7).
  4. Switch to Safari with two windows, one on the Start Page, and window-swipe: its row reads `Apple — Start Page` (R6, demo).

## Slices

### S1: VS Code titles lead with the project

**What to build:** During a window swipe on VS Code or VS Code Insiders, every row leads with the project: the first two " — "-separated parts of the window's title are swapped, later parts keep their order, no part's text changes, single-part titles and the untitled fallback are untouched, and lifting on a reworded row raises that window. Every other app's rows read exactly as today. The rules are one table in `LauncherCore` to which the next app is one entry.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3, R4, R5, R6, R7.

**Test scenarios:** T1, T2, T3, T4, T5, T6.

- [ ] `WindowTitleRule` exists in `LauncherCore` as one internal `Sendable` enum: the case `leadWithSecondPart(separator:)` with its apply, the static table keyed by bundle identifier holding `com.microsoft.VSCode` and `com.microsoft.VSCodeInsiders`, and the static `displayTitle(_:of:)` as its one entry point; it imports Foundation only (the source-policy import scan stays green).
- [ ] `WindowSwitcher.rows` gives the untitled fallback for an empty title and the title rule's display title for a non-empty one, in that order, for visible and minimised rows alike; `grep -rn "WindowTitleRule" LauncherKit/Sources` finds the rule's own file and that one caller only.
- [ ] No port, `AppWindow`, `FrontmostWindows`, `WindowSwitcher.Content`, `WindowLift`, `LauncherPlatform` or `LauncherUI` source changes: the diff under `LauncherKit/Sources` touches `WindowSwitcher.swift` and the rule's new file only.
- [ ] A new suite beside `WindowSwitcherOnScreenTests` holds T1–T6, all green, with T1 one parametrised test whose argument rows are apps; the VS Code tests set the fake system's frontmost app to an entry built as the running-app adapter builds one; no `World` helper is added and no existing test is edited.
- [ ] The manual sequence in Further Notes, step 3, shows a row starting `trackpad-launcher — ` and ending in "…" on one line (R7).
- [ ] `docs/domain-model.md`'s *Title rule* and *Window switcher* entries match what ships.
- [ ] `Scripts/test.sh` is green: the whole suite, the six new scenarios included.
