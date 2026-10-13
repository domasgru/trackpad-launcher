# Codebase map for plan 008 (running-apps switcher)

Paths are relative to the worktree root. `K/` = `LauncherKit/`. Line numbers are as of commit f378996.

## Build, test, project

- Tests: `Scripts/test.sh` = `DEVELOPER_DIR=/Applications/Xcode.app/... ; cd LauncherKit && exec swift test "$@"` (args pass through, e.g. `--filter SwitcherTests`).
- `K/Package.swift`: swift-tools 6.2, macOS 26, Swift 6 mode. Targets `LauncherCore` (Foundation + Observation only), `LauncherPlatform` (deps Core), `LauncherUI` (deps Core, `.defaultIsolation(MainActor.self)`); test targets `LauncherCoreTests` (Core only) and `LauncherPlatformTests` (Platform + Core). LauncherUI has no test target.
- Xcode project: `project.yml` is the xcodegen spec (`xcodegen generate` regenerates the committed `TrackpadLauncher.xcodeproj`). It builds only the app bundle from `TrackpadLauncher/` + `assets/*.svg`, depending on the package products. Files added inside the package need no regeneration. `Scripts/release.sh` archives with xcodebuild.
- Composition root: `TrackpadLauncher/TrackpadLauncherApp.swift` (`WorkspaceActions()` :11, `MenuBarShell(launcher:)` :20).
- No CLAUDE.md/AGENTS.md in the repo. Standards: `docs/architecture.md`. Note: `docs/architecture.md`, `docs/domain-model.md` and `docs/product-overview.md` were ALREADY edited for plan 008 in commit f378996.

## Conventions observed

- Swift Testing only: `import Testing`, `@Suite struct`, `@Test func`, `#expect`, `#require`, `@Test(arguments:)`, `.enabled(if:, "reason")`. Suites that touch `Launcher`/`World` are `@MainActor @Suite struct`. Core tests `import LauncherCore` without `@testable` (they use `package` access for test-only mutators such as `Switcher.travelMM`'s `package(set)`). Platform tests use `@testable import LauncherPlatform`.
- Test names are sentence-style camelCase stating the behaviour (`liftingOnTheFrontmostAppOnlyRemovesTheSwitcherAndLeavesTheWindowAlone`).
- Doc comments: `///` on every type and non-obvious member, terse present tense, state the rule and why. Units go in names (`travelMM`, `switcherStepMM`). Inline `//` only for reasons. No logging, timers or polling (enforced by the source scan).
- Ports: `@MainActor` protocols in `K/Sources/LauncherCore/Ports.swift`. Each has exactly one real adapter (Platform) and one in-memory adapter (`K/Tests/LauncherCoreTests/InMemoryAdapters.swift`). Framework types never cross a port.
- Model intents (`setX(...)`) guard against a no-change call, then `store.save(settings)`, then `reconcile()` when the recognizers depend on the value.

## Port and adapters

- `SystemActions` protocol: `K/Sources/LauncherCore/Ports.swift:47-62`. `func frontmostApp() -> URL?` is at :59-61 (doc + decl). Replace it with `runningApps() -> RunningApps`.
- `WorkspaceActions`: `K/Sources/LauncherPlatform/WorkspaceActions.swift:5`. `init()` creates `LaunchOverlay` (:8-10), which is why platform tests must not construct it. `bringToFront` :14-18 is unchanged (`NSWorkspace.openApplication` with `activates = true`). `frontmostApp()` :20-27 reads `frontmostApplication`, excludes its own pid and returns `bundleURL`.
- `RecordingSystemActions`: `K/Tests/LauncherCoreTests/InMemoryAdapters.swift:136`. `broughtToFront` :137, `var frontmost: URL?` :143-144, `func frontmostApp()` :152.
- The in-memory hardware is in the same file: `running` :8, `runCount` :42 (bumped in `run` :44-45), `scroll(_:)` :113, `inject` :118, pulses/feedback.
- `AppEntry` (bundleID, name, url) is at `K/Sources/LauncherCore/Apps.swift:12-25`. Its `id` is the bundle ID (:17), not the location, even though the plan makes identity the location. `Equatable` covers the url, so the presenter's `switcher.row != laidOutRow` check is fine.

## Private-symbol pattern (MultitouchSupport)

- `K/Sources/LauncherPlatform/MultitouchSupport.swift:7` is `struct MultitouchSupport: Sendable` with a failable `init?()` at :28. It calls `dlopen(path, RTLD_NOW)` and defines a local `func symbol<T>(_ name: String, as: T.Type) -> T?` = `dlsym(handle, name).map { unsafeBitCast($0, to: type) }`. One `guard let ... else { return nil }` covers every symbol, so one missing symbol makes the whole load nil. The function pointers are stored as `@convention(c)` lets. The LaunchServices order should follow the same pattern, resolving from the image AppKit already loaded.

## Source-scan test

- `K/Tests/LauncherCoreTests/SourcePolicyTests.swift`: `banned: [Entry]` :13-54. `Confined(token:onlyIn:rule:)` :57-61. `static let confined` :64-70: add `_LSCopyApplicationArrayInFrontToBackOrder` and `_LSCopyApplicationInformation`, confined to the LaunchServices order's file name. The scan covers `K/Sources` and `TrackpadLauncher/` (:76-81). Tests: `noSourceUses` :84, `onlyItsAdapterUses` :90, `confinedScanFindsAUseOutsideItsFile` :96. Banned tokens include `Timer`, `asyncAfter`, `print(` and `nonisolated(unsafe)`.

## Switcher value: `K/Sources/LauncherCore/Switcher.swift`

- `struct Switcher: Equatable, Sendable` :4. Fields: `row` :7, `home` :9 (remove), `travelMM` `package(set)` :11, `droppedMM` :13 (the plan keeps the last reported travel instead), `trackpad` :14.
- `package init?(listed:frontmost:trackpad:)` :17-26 matches on bundle ID. It becomes: frontmost + running minus the entry at the same location, nil when fewer than 2.
- `selected` :30-33 (home + round(travel / 12), `.toNearestOrAwayFromZero`, clamped). `selectedApp` :35. `follow(_:)` :39-48 (band = `switcherMaxOvershoot * step`). `selectsFrontmost` :51 (`selected == home`). `position` :55, `stretch` :59-63, `unclampedPosition` :65.
- Constants in `K/Sources/LauncherCore/GestureRules.swift`: `switcherStepMM = 12.0` :21, `switcherMaxStretch = 0.2` :23, `switcherMaxOvershoot = 0.25` :24-26.
- The new `SwitcherRowLayout` goes beside `Switcher` in Core.

## Launcher model: `K/Sources/LauncherCore/Launcher.swift`

- `switcherRows: [SwitcherRow]` :11-12 (remove). `switcher: Switcher?` :13-14. `isLaunchAnimationOn` :19 is the pattern for `isSwipeOn`. The init (:46-63) sets `switcherRows = makeSwitcherRows()` at :62. `start()` :66 routes `.swipe(let event): swipe(event)` at :70.
- `entry(for: AppChoice)` :103-108: keep it for the gesture rows.
- Remove all four list intents: `addToSwitcher` :110-114, `removeFromSwitcher` :116, `moveInSwitcher` :118-119, and `editSwitcherList` :121-131 (which reconciles when the list's emptiness flips).
- `setHandMode` :133-139 and `setLaunchAnimation(on:)` :141-146 are the patterns for `setSwipe(on:)`.
- `openWindow` :149-153. `struct Run { trackpads, handMode, blockClicks, swipes }` :161-168. `lastRun` :170.
- `reconcile(restart:)` :172-192:
  - Its doc (:172-174) mentions the null-row restart; drop that part.
  - `swipes: !settings.switcherList.isEmpty` :186 becomes `true` in S1 and `settings.isSwipeOn` in S5.
  - It sets `switcher = nil` and calls `hardware.run(...)` at :190-191.
- `fire(_:)` :195-205 is the tap path (`.gesture` feedback, bringToFront, launch animation, close window).
- `swipe(_ event: SwipeEvent)` :208-236:
  - `.began` :210-217 reads `system.frontmostApp().flatMap(catalog.entry(at:))` and the listed apps via `catalog.locate`, then calls `reconcile(restart: true)` on a nil row at :217 (remove that restart).
  - `.moved(travel)` :218-223 plays one light tick per index change.
  - `.ended` :224-231 is silent on `selectsFrontmost`; otherwise it plays the `.gesture` haptic, calls `bringToFront` and sets `window = .closed`. The second `runningApps()` read goes here.
  - `.cancelled` :232-233.
- `resolveRows()` :239-248 (sets `switcherRows` at :241) and `makeSwitcherRows()` :250-252: remove the list parts.
- `SwipePhase` and `SwipeEvent` live in `K/Sources/LauncherCore/Gesture.swift:25,38`.

## Settings and list types

- `K/Sources/LauncherCore/Settings.swift`:
  - `Settings` :7. Its doc (:3-6) states the decoding rule: a missing key decodes as the default and an unknown key is ignored.
  - `switcherList` :11 and its decode at :22: remove.
  - `isLaunchAnimationOn` :12-13 and its decode at :23-24 are the pattern for `isSwipeOn`.
  - `SwitcherList` :28-61: remove.
  - `SettingsStore` :63 (`load` :73, `save` :78).
- `K/Sources/LauncherCore/Apps.swift`:
  - `SwitcherRow` :55-67: remove.
  - `InstalledApps.pickerMenu(checking:)` :110-114: keep.
  - `addMenu(listing:)` :116-119: remove. The private `menu(state:)` is at :121-127.
  - `AppItemState.listed` :143-144: remove.
  - `AppCatalog` :149, `entry(at:)` :198, `locate(_:)` :212: keep (the gesture rows use `locate`).

## Copy

- `K/Sources/LauncherCore/Copy.swift:6-8` `gestureHint(for handMode:)` becomes `gestureHint(for:swipe:)`. With the swipe off it drops ", or swipe left or right with 2 fingers to switch apps".
- The `HintText` view (`K/Sources/LauncherUI/LauncherView.swift:139-158`) calls `Copy.gestureHint(for: handMode)` twice (:144, :149) and is used at :24 as `HintText(handMode: launcher.handMode)`. It should render `launcher.gestureHint` instead.

## Recognizer

- `K/Sources/LauncherCore/GestureRecognizer.swift`:
  - `Recognition { event, blocksClicks, blocksDockSwipes }` :4-30.
  - `GestureRecognizer` :35. `init(handMode:surface:swipes:travel:)` :38; its doc at :36 says "false while the switcher list is empty" (update it). `step(_:)` :48.
  - `swipes ? Pair(...) : nil` :81: with swipes off, a drag spoils.
  - Blocking flags are computed at :154-168. While swiping both are true. Otherwise Dock swipes block when a thumb and another finger are down, and clicks follow the thumb rule (the 3 s window).
  - `private let swipes` :286.
- `TrackpadHardware.run(_:handMode:blockClicks:swipes:)` is at `K/Sources/LauncherCore/Ports.swift:33`.

## UI shell (LauncherUI, no tests)

- `K/Sources/LauncherUI/AppMenuButton.swift`:
  - `enum Form` :9-14: keep `.popUp(current:)`, remove `.pullDown(title:listed:)`, then drop the enum and take `current: RowApp`.
  - `makeNSView` :26-35 switches on the form.
  - The coordinator's menu build is at :88-115 (`.pullDown` :92-94 uses `addMenu`; `case .listed` :103). Title item :121-123. `Form.pullsDown` extension :178-182.
  - The only other caller is `LauncherView.swift:64-65` (`form: .popUp(current: row.app)`).
- `K/Sources/LauncherUI/SwitcherSection.swift` (111 lines):
  - `SwitcherSection` :7-35: the illustration `TemplateImage.view("swipe")`, mirrored with `.scaleEffect(x: handMode == .left ? -1 : 1)` (:14-16); title :17; rows :21-24; Add app… pull-down :25-32.
  - `SwitcherRowList` :39-73: ScrollView, drag reorder, pitch 28.
  - `SwitcherListRow` :75-111: hover xmark and a context-menu Remove.
  - Rewrite it as one row like `LaunchAnimationSwitch` (`LauncherView.swift:122-137`): an HStack of Text, `Spacer(minLength: 8)`, and `Toggle(...).toggleStyle(.switch).labelsHidden()` with a get/set Binding to the model.
- `LauncherView` (`K/Sources/LauncherUI/LauncherView.swift:7-52`): section order :14-21. Fixed width 266 with `.fixedSize(horizontal: true, vertical: false)` at :49.
- Height cap in `K/Sources/LauncherUI/LauncherPanel.swift`:
  - `screenMargin = 8` :31.
  - `fitToContent(centeredOn:topEdge:within:)` :45-51. The cap `size.height = min(size.height, screenFrame.height - screenMargin*2)` is at :47 and `y = max(..., minY + screenMargin)` at :49. The doc at :43-44 mentions the scrolling region.
  - Remove the cap: grepping for `screenMargin` must return nothing after S1.
- `K/Sources/LauncherUI/MenuBarShell.swift`:
  - `switcherPresenter = SwitcherPresenter(launcher:)` :28.
  - The refit observation `Observations({ (launcher.activity, launcher.isAccessibilityGranted, launcher.switcherRows.count) })` is at :48-55. Drop the count, and add `isSwipeOn` in S5.
  - `iconTargets` (around :86-92) includes `switcherRows.compactMap(\.present)` at :90: remove.
  - `refit()` :117.
- `K/Sources/LauncherUI/LauncherActions.swift:24-26`: the `chooseOtherApp` doc mentions the switcher list (update it).

## SwitcherPresenter / SwitcherPanel

- `K/Sources/LauncherUI/SwitcherPresenter.swift`:
  - The class is at :9 and `icons = AppIcons(side: SwitcherPanel.iconSide)` at :12.
  - init :21-35:
    - `icons.renderOnMainActor(listedApps)` :23 is the start pass, and it is waited for.
    - It observes `launcher.switcher` and calls `render` (:24-27).
    - It observes `launcher.switcherRows` and calls `renderIcons` (:28-31). S3 replaces this with NSWorkspace launch/terminate observers.
    - Appearance KVO :32-34.
  - `listedApps` :41, `renderIcons` :43.
  - `render(_:)` :47-61. The spring call `panel.springHighlight(from: stretch * SwitcherPanel.iconPitch)` at :58 switches to the layout's pitch in S4.
  - `open(_:)` :63-74 finds the screen with `screen(under: NSEvent.mouseLocation)` and calls `panel.layoutRow(row.map { icons.icon(forSwitcher:) }, on: screen.frame, scale:)`.
  - `hide` :76-91, `screen(under:)` :94-98.
- `K/Sources/LauncherUI/AppIcons.swift`:
  - `icon(forSwitcher:)` :49-63 tries, in order: the cache (keyed by url and appearance); the running app's `icon` (via `NSRunningApplication.runningApplications(withBundleIdentifier:)`, matched on `bundleURL`); a render on the main actor.
  - `renderOnMainActor` :66 and `renderOffMainActor` :74. The cache is keyed by URL.
- `K/Sources/LauncherUI/SwitcherPanel.swift`:
  - Constants: `iconSide 80` :8, `iconGap 20` :9, `iconPitch` :11, `highlightSide 92` :12, `selectedScale 1.12` :13, `cornerRadius 34` :15, `horizontalPadding 28` :16, `topPadding 22` :17, `bottomPadding 18` :18, `nameHeight 18` :19, `nameGap 10` :20.
  - `size(forIconCount:)` :92-98.
  - `layoutRow(_:on:scale:)` :100-131 centres the panel on the screen, sets layer bounds to 80 and uses trilinear minification.
  - `show(position:selected:name:animatesSize:)` :135-151, `springHighlight(from:)` :154-165.
  - `iconCentreX(at:)` :167-169 becomes `SwitcherRowLayout.centreX(at:)`.

## World fixtures: `K/Tests/LauncherCoreTests/World.swift`

- `init(apps:attached:accessGranted:)` :55, `makeLauncher` :87, `seedSettingsRecord` :102, `bundleID(_:)` :106, `install(_:in:bundleID:)` :111, `app(_:in:)` :127, `trash` :143, `tap` :149, `play` :155. Tests also use a `downloads` directory.
- `relaunch()` :162-172 builds a new `Launcher` over the same adapters and the same `UserDefaults` suite.
- `makeFrontmost(_ name: String?)` :176-178 sets `system.frontmost = app(name).url`; it should store the entry instead.
- `switcherWorld(accessGranted:)` :181-187 installs Safari, Mail, Slack and Notes, calls `start()`, runs `addToSwitcher` for Mail, Slack and Notes, and makes Safari frontmost. It becomes all four running, Safari frontmost. Add `makeRunning(_:)` (over entries, plus a names overload).
- `swipe(_ slidesMM: Double..., lift:on:)` :192-199 puts the thumb at (10, 10), lands two fingers and plays the slides.
- `Fixtures.recordSavedByPlan002(handMode:two:)` is at `K/Tests/LauncherCoreTests/Fixtures.swift:86-97`: a plist with only handMode and assignments. Other helpers in that file: surfaces :6-7, `Trackpad.macBook14` / `.magicTrackpad` :16-17, `fired`/`phases`/`perFrame` :21-55, and recognizer-level frames via `contact` / `frame(atMS:)` :75-81.

## Tests named by the plan

Removed:
- `K/Tests/LauncherCoreTests/SwitcherListTests.swift`:
  - `SwitcherListTests` :6, all of its rows (:16-130). This includes `aRecordSavedBeforeTheSwitcherLoadsWithItsAssignmentsAndNoList` :114, which uses `recordSavedByPlan002`.
  - `SwitcherListValueTests` :132, plus its `Settings.append` helper extension :186-188.
  - `LocateTests` :190 (`registeredCopiesAreConsultedOnlyWhenTheLastKnownLocationMisses` :191) is not removed: it moves beside the catalog tests (`AppCatalogTests.swift` / `AppResolutionTests.swift`).
- `K/Tests/LauncherCoreTests/RecentAppsTests.swift`:
  - The `addMenu` helper :23-32.
  - `theAddMenuDisablesListedAppsAndHasNoNone` :197.
  - `theAddMenuWithoutLaunchDataAndTheRowMenuKeepTheirShapes` :207. Keep its row-menu assertion `["Finder","Mail","✓ Slack","—","Other…","None"]` as its own row.
- `K/Tests/LauncherCoreTests/SwitcherOnScreenTests.swift`: `aListedAppInTheTrashIsLeftOutWithoutOpeningTheWindowFirst` :78, `theNextSwitcherUsesTheNewOrderAlsoAfterARelaunch` :90, `anEmptyListRecognisesNoSwipeAndBlocksNothingPastTheWindowUntilItHoldsAnApp` :321, `aSwipeWithNothingToShowEndsFromMainSoNothingStaysBlocked` :341-342, `anEditThatFlipsTheListsEmptinessRebuildsTheRecognizersAndOtherEditsDoNot` :403-404.

Amended:
- `K/Tests/LauncherCoreTests/SwitcherTests.swift`:
  - The helper `switcher(frontmost:travel:)` :17-22 uses `listed:`.
  - `travelPastAnEndIsKeptOnlyUpToAQuarterIconSoTurningBackMovesAtOnce` :24 becomes T9.
  - `theFrontmostAppInTheListKeepsItsPlaceAndStartsSelected` :40.
  - `aFrontmostAppOutsideTheListIsShownAtTheLeftEndAndStartsSelected` :49.
  - `identityIsTheBundleIDNotTheLocation` :56 is inverted into T23.
  - `aRowNeedsAnotherIconBesidesTheFrontmostApp` :62.
  - `theSelectionIsTheNearestIconAndNeverPassesAnEnd` :69-73 (6.0 → 1, 5.9 → 0).
  - `theSelectionMovesBackUnderTheSameRule` :77-80 reads from home 0 (from 18 back to 6 and −6).
  - `theHighlightSitsBetweenIconsInProportionToTheTravel` :84.
  - `pushingPastAnEndStretchesTheHighlightButNeverByAFifthOfAnIcon` :92.
  - Rows using `frontmost: slack` (home 1) must be rewritten.
- `SwitcherOnScreenTests.swift`:
  - `theRowIsTheSwitcherListInWindowOrderAndTheSelectionStartsOnTheFrontmostApp` :58 becomes T1/T2. It sets `system.frontmost = downloads...` at :73.
  - `noReadableFrontmostAppShowsNothingAndNextTimeItWorks` :369-370 becomes T14, nil case only.
  - `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored` :420: `addToSwitcher` becomes `makeRunning`.
  - Helpers: `names(_:)` :10, `nothingHappened(_:)` :12.
- `K/Tests/LauncherCoreTests/PersistenceTests.swift`:
  - The four default rows that gain `isSwipeOn`: `firstLaunchShowsFreshDefaults...` :21 (asserts `isLaunchAnimationOn` at :28), `undecodableRecordLoadsAsDefaultsNotAsFirstLaunch` :44 (:55), `upgradingFromARecordWithoutTheLaunchAnimationSettingKeepsEverythingElse` :100 (:108), `anEmptyRecordDecodesAsDefaultsNotAsFirstLaunch` :129 (:137).
  - `everySettingsFieldSurvivesTheStore` :159-171: set `isSwipeOn = false`.
  - `turningTheLaunchAnimationOffSurvivesARelaunch...` :144 is the pattern for T17. Helper `recordFromBeforeTheLaunchAnimationSetting` :81.
- `K/Tests/LauncherCoreTests/CopyTests.swift`: `theHintNamesFiveFingersAndTheSwipeWithTheCornerOfTheHand` :5 becomes T22.

Style references for new tests:
- `K/Tests/LauncherPlatformTests/SpotlightLastUsedTests.swift` (model T4 and T5(b) on it, e.g. `.enabled(if: symbolsResolve, ...)`):
  - `@Suite struct` :8, `@testable import LauncherPlatform`.
  - It compares the real reader to the system's own reader (`mdls` run via `Process`).
  - Inputs are precomputed statically (`listed` :28), with a static guard (`hasSpotlightData` :33) used as `@Test(.enabled(if: hasSpotlightData, "Spotlight has no last-used dates on this Mac"))` :35.
- `K/Tests/LauncherCoreTests/DockSwipeBlockingRecognizerTests.swift:8-11` builds `GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, travel: .linear)`, steps it over `Fixtures` frames and maps `.blocksDockSwipes`. T21 is the same with `swipes: false`; `ClickBlockingRecognizerTests.swift` shows the same for `blocksClicks`.
