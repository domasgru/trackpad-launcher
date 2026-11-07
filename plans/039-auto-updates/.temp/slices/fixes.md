# Fixes after review

Repo root (a git worktree; use absolute paths): `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/039-auto-updates`. The full gate is `make test` (`Scripts/test.sh`, plain `swift test`); it was green before these fixes and must be green after. The app target must still build (`xcodegen generate` then `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath build/dev -quiet`). Fix each item below as decided, test-first where it changes behaviour, and nothing else. Do not commit. Report each item's outcome, and anything you could not do.

## 1. An unfound download fails open

- **Where:** `LauncherKit/Sources/LauncherPlatform/SparkleEngine.swift`, the delegate's `updater(_:didDownloadUpdate:)` (about L266-277).
- **What is wrong:** when `SparkleInternals.persistentDownload(...)` returns nil (or `offer` is nil), the code sets `genuine = false` and returns, removing nothing. Sparkle then launches its installer for a bundle nobody checked, and a Quit, logout or crash before `showReady`'s *skip* installs it.
- **Rule it breaks:** the plan's decision 2: "A refused one removes the downloaded archive, so Sparkle's own extraction fails and the cycle ends `.failed`; no installer was ever launched for it, so no quit, crash or termination can install it." And `docs/architecture.md` Concurrency: "…so that no unchecked update is ever prepared." R15: "Otherwise it MUST install nothing."
- **Fix decided:** fail closed. When the lookup cannot name exactly one archive for this item, or there is no offer, remove this app's whole persistent-download folder (`<caches>/<identifier>/org.sparkle-project.Sparkle/PersistentDownloads`), so whatever Sparkle downloaded is gone and its extraction fails before any installer runs. Put the removal in `SparkleInternals` (or `UpdateArchive`, wherever the existing refused-archive removal lives) as a pure function over a caches folder, so it is testable over a temp folder in Sparkle's layout as `UpdateDownloadTests` already does. Keep every file-removal call inside the files the `SourcePolicyTests` confined rows already allow (`removeItem(` is confined; extend the row only to a file already holding update removal code, if needed). Add a test in `LauncherKit/Tests/LauncherPlatformTests/UpdateDownloadTests.swift`: a layout the lookup cannot resolve (two files in the build folder; no folder for the build) ends with the persistent-download folder gone. Show it fails before the fix.

## 2. The lookup accepts any file name

- **Where:** `SparkleInternals.persistentDownload` and `UpdateDownloadTests.swift` (T39).
- **Rule it breaks:** the plan's T39: "one archive under one random folder with the item's file name is it; … another file name is nil." The enclosure is pinned to an `.aar` (`isPinned`).
- **Fix decided:** the one file in the build folder must end in `.aar`; anything else is nil (and, by item 1, fails closed). Add the T39 row "another file name is nil" (a single `.dmg` or `.zip` in the right folder).

## 3. T27's planted keys are not tested

- **Where:** `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` (the `neverDeclared` check; the only plant today is `NSSupportsSuddenTermination`, about L371).
- **Rule it breaks:** the plan's T27: "`SUAutomaticallyUpdate`, `SUScheduledCheckInterval` and `SUEnableDownloaderService` are absent; a planted one fails." Also "`SUEnableAutomaticChecks` is declared `false` and `SUEnableInstallerLauncherService` `true`; a planted `true` or `false` respectively fails" — check those two plants exist; add any missing.
- **Fix decided:** a parameterized test that plants each of the three never-declared keys into a copy of `project.yml`'s text and expects the check to fail; and the two value plants if missing.

## 4. The E2E build cache ignores the vendored Sparkle

- **Where:** `Scripts/update-e2e.sh` `commit_key()` (about L113-114): `paths` lists the deleted `LauncherKit/Package.resolved` and omits `LauncherKit/Vendor`.
- **Rule it breaks:** the cache must change when the build's inputs change; re-vendoring Sparkle would reuse stale builds.
- **Fix decided:** replace `LauncherKit/Package.resolved` with `LauncherKit/Vendor` in `paths`. `bash -n Scripts/update-e2e.sh` must pass.

## 5. The product overview's privacy sentence is wrong

- **Where:** `docs/product-overview.md` line 8.
- **What is wrong:** "a copy signed with a Developer ID in /Applications that can write to its own bundle checks … at each login start, if it can write to its own bundle, and each time its settings window opens" puts the writable condition on the window's check too, and states it twice.
- **Rule it breaks:** the plan's Solution privacy rule: "a copy signed with a Developer ID in /Applications checks a public update list on GitHub at each login start, if it can write to its own bundle, and each time its settings window opens, and downloads a new version from GitHub releases at a login start or when the user presses *Update now*"; R19 "Its settings window MUST check and show the card as usual."
- **Fix decided:** delete "that can write to its own bundle" after "in /Applications", leaving the rest of the sentence as it is.

## 6. The update card's frame is a copy of the Accessibility hint card's

- **Where:** `LauncherKit/Sources/LauncherUI/UpdateCardView.swift` (about L10-38) and `AccessibilityHintCard.swift`.
- **What is wrong:** the card copies the hint card's whole frame: the `#DEDEDE` border colour, the rounded shape, the group fill, the clip, the overlay border and the corner-picture background.
- **Rule it breaks:** duplicated code (the review's smell baseline); `docs/architecture.md` Shape: "the shell stays thin".
- **Fix decided:** extract one shared view modifier (or small view) in `LauncherUI` for "a bordered, clipped group with a picture behind its content" taking the picture view and its placement, used by both cards; the border colour lives once. Both cards must render exactly as before (same insets, offsets, clip, border); existing UI tests stay green. Keep it small; do not touch `GearView` or `UpdatePictureView`'s Reduce motion code.

## 7. The plan's text lags three facts the code proved

- **Where:** `plans/039-auto-updates/plan.md`.
- **Fix decided:** edit the plan text only, minimally, so it states what shipped:
  - Decision 2's and Further Notes' persistent download layout: `PersistentDownloads/<random>/<host name> <build>/<file>` (the build folder named by Sparkle's download driver), not `PersistentDownloads/<random>/<file>`; T39's row wording to match (the item's build folder, one `.aar`).
  - Decision 9: the card's text is SF Pro Regular 11 pt (line height 14) and its button is the *Close* button's style, as the plan's own "Card measurements from Figma" section says, not "13 pt medium" and "the solid accent style".
  - Decision 10: the arrow layer sits inside a static container masked to outside the tray, so only the shaft above the tray shows while the hole moves with it (the view has more than three layers); the animated layers and their animation are as stated.
  - T22: on this toolchain's test host WebKit is already loaded, so the check walks Sparkle's own dependency closure for WebKit and AppKit; the person's T37 `vmmap` row is the whole-process check on the real app.

## Not taken (no action)

- Negated `#expect(!…)` in new tests: this repo's existing style throughout; revision 1's review made the same call.
- `SparkleEngine.currentUpdater`, the test-only weak reference: the plan's T21 asks for exactly that ("a weak reference the engine exposes for tests").
- `public nonisolated static func canReplace`: the plan's own signature, called from the composition root before any actor context matters.
- The other judgement calls (data clumps, primitive obsession, fixed sleeps in pre-existing platform tests, the duplicated `ProcessWait` test helper across two test targets, architecture.md's hand-over detail): not changed.
