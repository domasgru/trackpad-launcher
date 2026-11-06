# How build, packaging, signing and release work (grounding for plan 039)

Angle: build, packaging, signing, release. Paths are relative to the worktree root. Sparkle source and docs were read at tag `2.10.1` through the GitHub API, and they are cited by file and function because I had no line numbers for them.

Evidence labels:

- **Read**: read in the code.
- **Observed**: seen in a command's output on this Mac.
- **Sparkle docs**: stated by Sparkle's documentation, not tested here.
- **Inference**: my conclusion, not shown directly.

Scratch probes ran on a copy of the project in `/private/tmp/tl-039-probe`, since deleted. "Variant A" and "variant B" are defined under "Embedding Sparkle". See "Side effects of this exploration" at the end.

## Headline findings

1. **Both ways of depending on Sparkle build and embed with no manual embed step.** With Sparkle as a dependency of `LauncherPlatform` in `Package.swift`, `project.yml` needs no change at all (Observed).
2. **`swift test` builds and loads Sparkle under variant A.** The focused tests passed, including one that touches `SPUUpdater` (Observed). `swift test` on a cold cache is not proven: see finding 3.
3. **The first `swift test` stalled on the keychain.** It sat in `SecItemCopyMatching` during the binary artifact step. `Scripts/test.sh` is called by `release.sh:338`, so this affects releases (see Non-Obvious 1).
4. **Old cards can install a release that embeds Sparkle, as far as a development-signed copy can show.** A real exported bundle with Sparkle passed `release.sh --archive-only`, the card's own `BundleInstall.unpack`, and the card's strict signature flags (Observed). Notarisation and the Developer ID requirement were not exercised.
5. **Export re-signs every nested Sparkle helper.** Inside the `.xcarchive` they are still ad hoc; after `-exportArchive` they carry the export identity and the hardened runtime (Observed with Apple Development, not with Developer ID).
6. **One `.aar` can serve both the card and Sparkle**, but only if the first automatic-update version sets `SUVerifyUpdateBeforeExtraction = YES` (Read, Sparkle `AppInstaller.m`).
7. **GitHub immutable releases are on for this repository** (Observed). Assets cannot be added to a published release, so an appcast hosted as a release asset must go up in the same `gh release create`.
8. **`origin/main` is two commits ahead of this branch.** It is at 1.0.15, build 16; v1.0.15 is the latest release. This worktree still has 1.0.14, build 15.
9. **No Sparkle signing key exists yet.** The keychain item `https://sparkle-project.org` is not found (Observed).

## Tools on this Mac (Observed)

| Tool | Result |
|---|---|
| `xcodebuild -version` | Xcode 27.1, build 27A9275 |
| `swift --version` | Apple Swift 6.4 (swiftlang-6.4.0.34.1), target arm64-apple-macosx27.2.0 |
| macOS | 27.2, build 26B123 |
| `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` |
| `gh` | 2.103.3, logged in as `domasgru`, token scopes `gist, read:org, repo, workflow` |
| `xcrun notarytool` | 1.1.3 (42), present |
| `xcodegen` | 2.46.0, at `/opt/homebrew/bin` |
| `security find-identity -v -p codesigning` | 2 valid identities: `Apple Development: dominykas.grubys@gmail.com (JFC6LR2268)` and `Developer ID Application: Dominykas Grubys (CQK27876UL)` |
| Sparkle EdDSA key | Not in the keychain: `security find-generic-password -s https://sparkle-project.org` finds nothing, metadata lookup only |
| Notary profile `trackpad-launcher` | Not confirmed. A metadata lookup under my guess at notarytool's item names found nothing, which is inconclusive. I did not run `notarytool history`. v1.0.15 was published on 2026-11-06, and the installed app's `BuildMachineOSBuild` 26B123 matches this Mac's macOS build, so credentials very likely work here (Inference). |

## Components Found

| Name | Path | What it does |
|---|---|---|
| Project spec | `project.yml` | XcodeGen input; the one tracked source of the Info.plist (`project.yml:32-40`, `docs/architecture.md:7`). |
| Generated project and plist | `TrackpadLauncher.xcodeproj/`, `TrackpadLauncher/Info.plist` | Generated, gitignored (`.gitignore:4-5`). |
| Build settings | `Config/Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Version.xcconfig` | Deployment target, hardened runtime, identities, version numbers. |
| LauncherKit package | `LauncherKit/Package.swift` | Three library products and three test targets; no external dependency and no `Package.resolved` today. |
| Release script | `Scripts/release.sh` | The one release command. |
| Test script | `Scripts/test.sh` | `cd LauncherKit && exec swift test "$@"`. |
| Perf build | `Scripts/perf/build.sh` | Release configuration with Apple Development signing. |
| Update fixtures | `Scripts/make-update-fixtures.sh` | Makes the committed notarised fixture app, its `.aar` and `fixture.json`. |
| Makefile | `Makefile` | Thin wrappers: `test`, `project`, `run`, `release*`. |
| Source policy test | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Substring scan of `LauncherKit/Sources` and `TrackpadLauncher/`, plus one key check of `project.yml`. |
| Card contract | `GitHubReleases.swift`, `BundleInstall.swift`, `CodeSignature.swift`, `ApplicationsUpdater.swift` (all `LauncherKit/Sources/LauncherPlatform/`), `Update.swift`, `Version.swift` (`LauncherCore/`) | What every old copy requires of a release. |

There is no CI: no `.github` folder, and no tracked entitlements file, `.xcodeproj` or `Package.resolved`. Releases are built on this Mac (`README.md:39-40`).

## App target configuration

- **Identity of the bundle:** `PRODUCT_NAME: Trackpad Launcher`, `PRODUCT_MODULE_NAME: TrackpadLauncher` (`project.yml:44-45`). Debug id `com.domasgru.TrackpadLauncherApp.debug`, Release id `com.domasgru.TrackpadLauncherApp` (`project.yml:50-53`).
- **Info.plist properties:** `CFBundleName`, `CFBundleDisplayName`, `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`, `LSUIElement: true`, `LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)` (`project.yml:32-40`). Sparkle keys would go here. The one Info.plist serves both configurations, so Debug would carry them too.
- **Base settings:** `MACOSX_DEPLOYMENT_TARGET = 26.0`, `ARCHS = $(ARCHS_STANDARD)`, `ONLY_ACTIVE_ARCH = NO`, Swift 6.0 with complete concurrency, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_STYLE = Manual` (`Config/Base.xcconfig:2-9`).
- **Hardened runtime:** on in both configurations, because it is in Base. The shipped binary shows `flags=0x10000(runtime)` (Observed).
- **Entitlements:** none. `project.yml` declares none, and `codesign -d --entitlements -` on the installed app prints an empty dict (Observed). `docs/architecture.md:35`: "hardened runtime, no entitlements". Sparkle's sandboxing guide tells non-sandboxed apps to skip that guide (Sparkle docs). The app is not sandboxed.
- **Runpath:** `@executable_path/../Frameworks` is already in the shipped binary (Observed `LC_RPATH`, twice, one per architecture) and in the generated project (`LD_RUNPATH_SEARCH_PATHS`, from XcodeGen's presets). Sparkle's docs call this sufficient for regular apps.
- **Shipped bundle today (1.0.14):** `Contents/{CodeResources, _CodeSignature, MacOS, Resources, Info.plist, PkgInfo}`. No `Frameworks` folder and no symlinks. `Notarization Ticket=stapled` (Observed). Sparkle would be the first nested code and the first symlinks in any release.

## Version and build numbers

- `MARKETING_VERSION` becomes `CFBundleShortVersionString`. `CURRENT_PROJECT_VERSION` becomes `CFBundleVersion` (`Config/Version.xcconfig:3-4`, `project.yml:37-38`).
- The installed copy shows `1.0.14` and `15` (Observed).
- `CFBundleVersion` has been a plain integer rising by 1 at every release from `1` at 1.0.0, and every release to date follows build = patch + 1 (Observed, `git log -p Config/Version.xcconfig`). `origin/main` is at 1.0.15 and 16.
- The comment `Config/Version.xcconfig:2` says the build number only ever goes up. Only `bump_version` does this (`release.sh:160-161`). **Nothing enforces it.** `preflight_version` compares `MARKETING_VERSION` with tags and releases only (`release.sh:169-182`). A hand-raised `MARKETING_VERSION` released with no argument keeps the old build number and passes every check.
- This now matters. Sparkle compares `CFBundleVersion` (Sparkle docs step 5: "incrementing and properly formatted `CFBundleVersion`… Sparkle uses this to compare"), and `generate_appcast` wrote `<sparkle:version>15</sparkle:version>` for 1.0.14 (Observed). The card compares `CFBundleShortVersionString` through the asset name.

## Flow: `Scripts/release.sh` step by step

Entry points: `make release-patch|minor|major` calls `Scripts/release.sh patch|minor|major`, and `make release` calls it with no argument (`Makefile:26-36`). `--image-only <app>` and `--archive-only <app>` exit early (`:318-330`).

1. **Set up.** `set -euo pipefail` (`:31`), fixed `DEVELOPER_DIR` (`:33`), `trap cleanup EXIT` (`:82`).
2. **Credentials and checkout: `preflight_checkout` (`:128-142`, called at `:337`).**
   - `gh auth status` (`:129`).
   - A `Developer ID Application` identity in the keychain (`:130`).
   - `notarytool history --keychain-profile "$NOTARY_PROFILE"`, default profile `trackpad-launcher` (`:132`, `:50`).
   - `xcodegen` on the PATH (`:134`).
   - `git fetch --tags origin` (`:137`); on `main` (`:138`); `git status --porcelain` empty, which also fails on untracked files (`:139`); `HEAD` equals `origin/main` (`:140`).
3. **Tests.** `Scripts/test.sh` (`:338`). Nothing has changed yet.
4. **Version bump: `bump_version` (`:146-165`, called at `:339`).** Only with a `patch|minor|major` argument. Rewrites both settings with `sed`, commits `Version <next>` locally, sets `UNPUSHED_BUMP=true`.
5. **`preflight_version` (`:169-182`, called at `:340`).** The version must be dotted whole numbers. Tag `v<version>` must not exist. The version must be above every tag and every release, drafts included (`:176`, `first_not_below` at `:109-119`). Sets `EXPECTED_VERSION`.
6. **Clean output.** `rm -rf "$OUT"`, default `build/release` (`:342`, `:45`).
7. **Generate the project.** `xcodegen generate` (`:345`).
8. **Archive.** `xcodebuild archive`, Release configuration, `generic/platform=macOS`, `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY=Developer ID Application`, `DEVELOPMENT_TEAM` (`:347-355`). No `-derivedDataPath`, so it uses the default DerivedData. `Config/Release.xcconfig:4` adds `OTHER_CODE_SIGN_FLAGS = --timestamp`.
9. **Export.** Writes `ExportOptions.plist` with `method=developer-id`, `teamID`, `signingStyle=manual`, `signingCertificate=Developer ID Application` (`:357-368`), then runs `xcodebuild -exportArchive` into `$OUT/export` (`:370-373`).
10. **Check the export.** `$OUT/export/Trackpad Launcher.app` exists (`:375-376`). `codesign --verify --strict` without `--deep` (`:378`). `Authority=Developer ID Application` (`:380`). `flags=0x10000(runtime)` (`:382`). These read the main app only.
11. **Notarise the app.** `ditto -c -k --keepParent` to a zip, `notarytool submit --wait`, `stapler staple`, `stapler validate` (`:386-391`). The stapling and its validation are what stop a rejected build under `set -e`, whatever the exit code of `submit --wait` is (Inference).
12. **Update asset: `archive_and_check "$APP" strict` (`:187-235`, called at `:393`).**
    - Reads version and minimum from the plist (`:191-196`).
    - Names the asset `TrackpadLauncher-<version>-macOS-<minimum>.aar` (`:198`).
    - `ditto`s the app to `source/TrackpadLauncher.app`. The name changes here, from `Trackpad Launcher.app` (`:202`).
    - `aa archive -d "$source" -subdir TrackpadLauncher.app -exclude-field uid,gid,xat,acl,flg` (`:205`), then `aa extract` (`:206`).
    - On the unpacked copy, checks: `codesign --verify --strict --deep` (`:210`); identifier and team unchanged (`:212-214`); identifier equals `BUNDLE_ID` (`:218`); stapled ticket and team, fatal in strict mode (`:222-230`); no extended attributes but `com.apple.provenance` (`:232`).
13. **Disk image: `build_image` (`:257-316`, called at `:395`).** Ejects same-named images, stages the app as `Trackpad Launcher.app` with an `/Applications` link and a background, makes an HFS+ read-write image, lays it out in Finder by AppleScript, converts to UDZO at `$OUT/TrackpadLauncher.dmg` (`:47`).
14. **Sign and notarise the image.** `codesign --timestamp -s "Developer ID Application"` (`:397`), verify (`:398`), `notarytool submit --wait`, staple, validate (`:400-402`).
15. **Gatekeeper.** `spctl --assess` on the image and on the app (`:404-405`).
16. **Push.** If there was a bump, `git push origin HEAD:main`, then `UNPUSHED_BUMP=false` (`:408-412`).
17. **Publish.** `gh release create "v$EXPECTED_VERSION" "$DMG" "$AAR" --repo domasgru/trackpad-launcher --latest --target <HEAD> --title "Trackpad Launcher <version>" --notes "Requires macOS <min> or later."` (`:413-415`). The script's header says gh uploads the assets before publishing (`:9`).

### Sign order

- Signing inside the bundle is left entirely to `xcodebuild`, which signs nested code first and the main executable last. `--deep` is never used (`release.sh:15-16`, `docs/architecture.md:35`). Sparkle's docs agree: do not add `--deep` to `OTHER_CODE_SIGN_FLAGS`.
- Final order: app signed, app notarised and stapled, `.aar` made from the stapled app, stapled app staged into the image, image signed, notarised and stapled.
- An EdDSA signature must be computed after step 12, over the final file (Inference). The appcast must then be published no earlier than step 17.

### Failure undo

- **`cleanup` on every exit (`:69-81`):** detaches a mount, deletes the read-write image and stage. If `UNPUSHED_BUMP` is true, runs `git reset --quiet --keep HEAD~1`.
- **Before the push:** any failure undoes the version commit, so the same command retries the same version (`:18-21`, `README.md:64`).
- **The push fails:** nothing published, and the commit is undone (`:409-410`).
- **The publish fails:** main already holds the version, so `UNPUSHED_BUMP` is false and nothing is undone. The message says to run `release.sh` with no argument (`:416`).
- **No undo after publishing.** Releases are "immutable once published" (`README.md:67`), and the repository setting enforces it (below).

### Published assets (Observed)

| Release | Assets |
|---|---|
| v1.0.0 | `TrackpadLauncher-1.0.0-macOS-26.0.aar` (4,453,413 bytes), `TrackpadLauncher.dmg` |
| v1.0.14 | `TrackpadLauncher-1.0.14-macOS-26.0.aar` (4,805,273 bytes), `TrackpadLauncher.dmg` (4,846,326 bytes) |
| v1.0.15 | `TrackpadLauncher-1.0.15-macOS-26.0.aar` (4,831,480 bytes), `TrackpadLauncher.dmg` (4,859,109 bytes) |

All 16 releases are full releases, not drafts or pre-releases. The repository is public, has no GitHub Pages, and `immutable-releases` is `enabled: true`. v1.0.14 reports `immutable: true`. `https://github.com/domasgru/trackpad-launcher/releases/latest/download/TrackpadLauncher.dmg` answers 302 to `/releases/download/v1.0.15/TrackpadLauncher.dmg`.

## What an old update card requires of a release (R16)

The contract code is unchanged since v1.0.0. `git diff v1.0.0 HEAD` over `GitHubReleases.swift`, `CodeSignature.swift`, `ApplicationsUpdater.swift`, `ApplicationsInstaller.swift`, `Update.swift`, `Updater.swift` and `Lifecycle.swift` is empty. `BundleInstall.swift` differs only by renaming a constant. So one list covers every old version.

**To be seen at all (`GitHubReleases.swift`):**

- The release appears in `GET https://api.github.com/repos/domasgru/trackpad-launcher/releases` (`:9`). No query string, so GitHub's default page of 30 newest applies (page size from GitHub's API behaviour, not this repo). Older releases are invisible to the card.
- `draft == false` and `prerelease == false` (`:127`).
- An asset with `state == "uploaded"`, a `size`, and `browser_download_url` starting `https://github.com/domasgru/trackpad-launcher/releases/download/` (`:10`, `:133-135`).
- The name parses as `TrackpadLauncher-<version>-macOS-<minimum>.aar`, split on exactly one `-macOS-` (`:142-150`). Both parts must be `Version`s: dotted whole numbers of 1 to 9 digits (`Version.swift:20-31`).
- The first such asset in the release counts (`:128`). Assets with other names are skipped by `counted` (`:132-139`). A third asset such as an appcast or zip is ignored.
- Tag, title and body are ignored (`:122`).
- The release is offered only if its version is above the running one and its minimum is at or below this macOS; the highest wins (`Update.swift:23-25`).

**To download:** exactly the listed `size` bytes with status 200 (`GitHubReleases.swift:64-66`), received into memory.

**To unpack (`BundleInstall.swift`):**

- Every entry's path must equal or sit under `TrackpadLauncher.app/`, with no `..` or `.`, not absolute (`:94-97`, `:12`).
- Each entry is a directory, regular file or symlink. Anything else cancels the whole extraction (`:98-100`, `:31`).
- A symlink's target must be relative and stay strictly inside the bundle (`:101-113`).
- `TrackpadLauncher.app` must exist afterwards (`:81-82`).

**To be genuine (`CodeSignature.isGenuine`, `CodeSignature.swift:60-82`):**

- Requirement: Developer ID chain (`:8-9`), `certificate leaf[subject.OU]` equal to the running copy's team, `identifier` equal to the running copy's identifier, and `notarized` (`:64-65`).
- Flags: strict validation, all architectures, nested code, no network (`:72-74`). The ticket must therefore be stapled.
- The sealed Info.plist's `CFBundleShortVersionString` and `LSMinimumSystemVersion` must equal the name's (`:76-81`).
- So the version and minimum in the asset name must match the plist. `release.sh:191-198` guarantees this by deriving the name from the plist.

**To finish:** the bundle goes over the running copy by atomic swap, whatever that copy is named (`ApplicationsUpdater.swift:82-90`, `ApplicationsInstaller.swift:87-105`). It is opened with `activates = true` and `createsNewApplicationInstance = true` (`ApplicationsUpdater.swift:65-74`), so the new version arrives as an ordinary opening by hand and shows its settings window (`docs/architecture.md:11`; `Updater.swift:136`).

### Results for a release that embeds Sparkle

- The contract's symlink rule admits framework layouts by unit test (`BundleInstallTests.swift:17-18`), but no committed test unpacked a real framework. `CraftedArchive` writes `LNK` by hand, and the fixture app has no symlinks.
- **Observed.** A scratch export was archived by `Scripts/release.sh --archive-only` with output in scratch. The real `BundleInstall.unpack` accepted the `.aar`, and `SecStaticCodeCheckValidity` passed with `isGenuine`'s exact flags and no requirement.
- **Not exercised:** the `Developer ID`, `notarized` and identifier requirement over a bundle with nested Sparkle code, because that needs a Developer ID signature and notarisation.

## Debug and perf builds

| | Debug (`make run`, Xcode) | Perf (`Scripts/perf/build.sh`) | Release |
|---|---|---|---|
| Configuration | Debug | Release | Release |
| Identity | `Apple Development` (`Config/Debug.xcconfig:2`) | `Apple Development`, command-line override (`build.sh:16`) | `Developer ID Application` (`Config/Release.xcconfig:2`, `release.sh:354`) |
| Bundle id | `...TrackpadLauncherApp.debug` | `...TrackpadLauncherApp` | `...TrackpadLauncherApp` |
| Derived data | `build/dev` (`Makefile:20-21`) | `build/perf/dd` (`build.sh:16`) | default |
| Hardened runtime | Yes | Yes (`build.sh:3-4`) | Yes |
| `--timestamp` flag | No | Yes, Release.xcconfig still applies; only the identity is overridden (Read) | Yes |
| Notarised | No | No | Yes |
| Export step | No | No | Yes |
| Updater created | No | No | Only in /Applications |

- `make run` depends on `project` (`Makefile:19`), so it regenerates the project each time.
- A build counts as development unless truly signed with a Developer ID. `CodeSignature.developerIDSigner()` returns nil "for Xcode, Debug, the perf build, ad hoc" (`CodeSignature.swift:34-44`). `--as-release-build` cannot fake it (`TrackpadLauncherApp.swift:43-45`). `makeUpdater` returns nil without a signer (`TrackpadLauncherApp.swift:46-57`). That is the existing gate R2 can reuse, though it does not yet cover R12.
- Debug output includes `Trackpad Launcher.debug.dylib` and `__preview.dylib` in `Contents/MacOS` (Observed), so a Debug build links Sparkle from the debug dylib rather than the stub executable.

### What happens to Sparkle in these builds (Observed)

| Build | `Sparkle.framework` | `Autoupdate`, `Installer.xpc` |
|---|---|---|
| As shipped by Sparkle | ad hoc, runtime | ad hoc, runtime |
| Debug | Apple Development, team CQK27876UL, runtime | still ad hoc (`Autoupdate` read) |
| Perf style | not read | still ad hoc (`Installer.xpc` read) |
| Inside `.xcarchive` | not read | still ad hoc (`Autoupdate` read) |
| After `-exportArchive` | re-signed | `Autoupdate`, `Downloader.xpc`, `Updater.app` signed with the export identity, team set, runtime kept |

- This matches Sparkle's docs: Code Sign on Copy does not re-sign helpers, and Archive and Export does.
- `codesign --verify --strict --deep` passed on Debug and on the export.
- Debug and perf builds therefore cannot run Sparkle's helpers as a signed team build. That should not matter while R2 stops those builds from starting the updater (Inference).
- The `method=debugging` export produced no secure timestamp line ("Signed Time" only). The `developer-id` export's timestamps were not exercised.

## Embedding Sparkle

**The package (Observed, Sparkle 2.10.1, published 2026-10-25):**

- `swift-tools-version:5.5`, `platforms: [.macOS(.v12)]`, one `.library("Sparkle")` over a `.binaryTarget(url:, checksum:)`.
- The URL is the 10,197,413-byte `Sparkle-for-Swift-Package-Manager.zip`. Its SHA-256 matched the manifest's checksum.
- The zip holds `Sparkle.xcframework` (one slice, `macos-arm64_x86_64`, with `dSYMs`) and `bin/{generate_appcast, sign_update, generate_keys, BinaryDelta}`.
- The framework is 2.9 MB: versioned layout `Versions/B`, 9 symlinks (`Autoupdate`, `Headers`, `Modules`, `PrivateHeaders`, `Resources`, `Sparkle`, `Updater.app`, `XPCServices`, `Versions/Current -> B`). Nested code: `Autoupdate`, `Updater.app`, `XPCServices/Downloader.xpc`, `XPCServices/Installer.xpc`.
- `Downloader.xpc` has no entitlements.
- `Sparkle` links `WebKit`, `AppKit`, `ServiceManagement`, `SystemConfiguration`, `IOKit`, `Security`, `libcompression`, none weakly (`otool -L`). `minos 12.0`, SDK 26.5.

### Variant A: dependency of `LauncherPlatform` (probed in full)

- `Package.swift`: add `.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")` and `.product(name: "Sparkle", package: "Sparkle")` on `LauncherPlatform`.
- `project.yml`: no change.
- `import Sparkle` works in `LauncherPlatform`, where every real adapter lives (`docs/architecture.md:12`). `LauncherCore` cannot import it: `SourcePolicyTests.swift:315-321` allows only Foundation and Observation.
- `xcodebuild build` (Debug), the perf-style Release build, `xcodebuild archive` and `-exportArchive` all succeeded on the real project copy, with `Contents/Frameworks/Sparkle.framework` embedded automatically and the executable linking `@rpath/Sparkle.framework/Versions/B/Sparkle`.
- `swift test` builds it and loads it in the test runner. `SparkleProbeTests` passed with `NSStringFromClass(SPUUpdater.self)`, alongside `BundleInstallTests`. All three test bundles were built, because the filter does not limit the build.
- `LauncherUI` does not depend on `LauncherPlatform` (`Package.swift:15-19`), and `LauncherCoreTests` and `LauncherUITests` do not gain Sparkle from this.
- `swift test` writes `LauncherKit/Package.resolved`. No `Package.resolved` appeared under the generated project, so `exact:` in `Package.swift` is what pins Xcode's build.
- Tools at `LauncherKit/.build/artifacts/sparkle/Sparkle/bin/` by default (seen under `--scratch-path`). Under Xcode: `<derived data>/SourcePackages/artifacts/sparkle/Sparkle/bin/`.

### Variant B: dependency of the app target only (probed to a Debug build)

- `project.yml`: add `packages: Sparkle: {url: https://github.com/sparkle-project/Sparkle, exactVersion: 2.10.1}` and `- package: Sparkle` under `dependencies`.
- The generated project has Sparkle in the Frameworks phase only, with **no Embed phase**. The built app still contains `Contents/Frameworks/Sparkle.framework`.
- The adapter would have to live in `TrackpadLauncher/`, which `swift test` does not compile. `SourcePolicyTests` would still scan it as text.
- `LauncherPlatform` cannot import Sparkle, and `swift test` is untouched.
- Xcode writes `TrackpadLauncher.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, inside the gitignored project. It survived `xcodegen generate`, but it is never committed.

### Not probed

A separate library target and product in LauncherKit holding only the Sparkle adapter. It would keep Sparkle out of `LauncherPlatform`'s test link, at the cost of a fourth module.

## Do the existing tests run with `swift test`?

Yes, by reading the setup:

- `Scripts/test.sh:3-5` sets `DEVELOPER_DIR`, enters `LauncherKit`, and runs `swift test "$@"`. `make test` calls it.
- `docs/architecture.md:7`: "`swift test` runs the whole behavioural suite; `xcodebuild` is used only for the bundle."
- Tests use Swift Testing with `@testable import`. Fixtures are found by `#filePath` (`UpdateFixtures.swift:6`, `SourcePolicyTests.swift:217`), so `Package.swift` declares no test resources. SwiftPM warns about 11 unhandled files (Observed).
- `SourcePolicyTests` reads `../TrackpadLauncher` and `../project.yml` from the package root (`:221-226`, `:365-367`).

I ran only focused filters on the scratch copy, not the full suite.

## Boundaries

- **In:** `Config/Version.xcconfig`, git state of `main`, keychain identity, notary profile, `gh` login.
- **Out:** GitHub release `v<version>` with two assets, plus a version commit on `main`.
- **Toward old copies:** the release list and the `.aar`.
- **Toward Sparkle-era copies (new):** Info.plist keys through `project.yml:34-40`, an appcast, an EdDSA signature.
- **Toward `docs/`:** `docs/architecture.md:7,11,12,27,30,35,36`, `docs/product-overview.md:8`, and `README.md:17-18,34,69-72` all describe the current update path.
- **Toward tests:** `SourcePolicyTests` substring tokens apply to any new Swift adapter. For example `Timer`, `http` (confined to `GitHubReleases.swift`), `.terminate(`, `URLSession` and `Process()`. Sparkle's binary is not scanned. A feed URL in `project.yml` is not scanned for `http`.

## What Sparkle needs from a release, for design

- **`.aar` is a supported format:** `SUPipedUnarchiver.m` extracts `.aar` with `/usr/bin/aa extract -d`. `needsVerifyBeforeExtractionKey` returns YES for it.
- **The key is required in the old app:** `AppInstaller.m` fails with "Extracting aar archives require setting SUVerifyUpdateBeforeExtraction to YES in the old app".
- **Effect of that key on rotation:** with it on, changing EdDSA keys "can only be done if the update archive is a Developer ID code signed disk image" (Sparkle docs).
- **The bundle's name inside the archive can differ:** `SUInstaller installSourcePathInUpdateFolder:forHost:` matches the host's file name, then `<host name>.app`, then any bundle with the host's bundle identifier. So `TrackpadLauncher.app` inside the `.aar` installs over `/Applications/Trackpad Launcher.app` by identifier, and installs to `host.bundlePath` (Read, not run).
- **`generate_appcast` accepts a shipped `.aar`.** On v1.0.14's asset it wrote (Observed):
  - `<sparkle:version>15</sparkle:version>`
  - `<sparkle:shortVersionString>1.0.14</sparkle:shortVersionString>`
  - `<sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>`
  - an `<enclosure>` with the given URL prefix, `length="4805273"`, `type="application/octet-stream"`
  - **no `sparkle:edSignature`**, although a key file was supplied. The old bundle has no `SUPublicEDKey`, which is the likely reason (Inference).
- **`generate_appcast` details (from `--help`):** it reuses an `appcast.xml` already in the folder. `--maximum-versions` defaults to 3 per branch point. `--maximum-deltas` defaults to 5. `--download-url-prefix` is a single prefix applied to new items.
- **Effect on `release.sh`:** `rm -rf "$OUT"` (`:342`) would remove a local feed, so prior feed items must come from somewhere else. R4's "needs a newer macOS" scenario needs older items kept in the feed (Inference).
- **Assets and immutability:** a release-asset feed must be uploaded in the `gh release create` at `release.sh:413`, and it cannot be corrected afterwards. A feed committed to a branch would have to be pushed after the release, so a separate failure point appears between steps 17 and the feed push (Inference).
- **Size (Observed):** bundle 6.0 MB to 8.8 MB. `Contents/Frameworks` is 2.7 MB. The `.aar` from a 1.0.14 tree grew from 4.8 MB to 5.66 MB.

## Files Read

Repository: `project.yml`, `Makefile`, `.gitignore`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Version.xcconfig`, `LauncherKit/Package.swift`, `Scripts/release.sh`, `Scripts/test.sh`, `Scripts/make-update-fixtures.sh`, `Scripts/perf/build.sh`, `README.md`, `plans/039-auto-updates/plan.md`, `TrackpadLauncher/TrackpadLauncherApp.swift`.

`LauncherKit/Sources/LauncherPlatform/`: `GitHubReleases.swift`, `ApplicationsUpdater.swift`, `ApplicationsInstaller.swift`, `BundleInstall.swift`, `CodeSignature.swift`.

`LauncherKit/Sources/LauncherCore/`: `Update.swift`, `Version.swift`, `Updater.swift` (`:95-160`).

`LauncherKit/Tests/`: `LauncherCoreTests/SourcePolicyTests.swift`, `LauncherPlatformTests/UpdateFixtures.swift`, `CraftedArchive.swift`, `BundleInstallTests.swift`, `CodeSignatureTests.swift`.

Searched, not read whole: `docs/architecture.md`, `docs/performance.md`, `docs/product-overview.md`, `plans/022-in-app-updates/development-logs.md`.

Sparkle 2.10.1, via GitHub: `Package.swift`, `Autoupdate/SUPipedUnarchiver.m`, `Autoupdate/SUInstaller.m`, `Autoupdate/AppInstaller.m` (`:266-287` only). Sparkle docs: `documentation/index.md`, `publishing/index.md` (searched), `sandboxing/index.md`, `customization/index.md`.

## Non-Obvious Things

1. **SwiftPM's binary download touches the keychain.**
   - The first `swift test` sat for about 8 minutes with no socket open, blocked in `SecItemCopyMatching` → `SecKeychainItemCopyContent` under `swift-package` (Observed by `sample`).
   - That likely means a keychain dialog was waiting for a person (Inference: I cannot see the screen). I stopped the run.
   - `xcodebuild -packageAuthorizationProvider netrc` then finished. `swift test --disable-keychain` next reported the artifact "from cache", so **a cold-cache `--disable-keychain` run is unverified**.
   - Plain `swift test` is what `release.sh:338` and `make test` run. An agent or headless run can hang here.
   - `Scripts/test.sh` forwards `"$@"`, but its callers pass nothing. `xcodebuild` has `-packageAuthorizationProvider keychain|netrc`, and the script calls do not pass it.
   - A vendored `.binaryTarget(path:)` would avoid the download entirely (not probed).
2. **`LauncherKit/Package.resolved` is a new tracked file.** It is not gitignored (`.gitignore:1-7`). If it stayed untracked, `git status --porcelain` at `release.sh:139` would refuse the next release.
3. **A plain build now needs the network the first time.** Today `swift test` and `xcodebuild` resolve nothing remote. Sparkle's git repository clones at 49 MB, plus the 10 MB artifact. `release.sh`'s default derived data and `make run`'s `build/dev` each resolve separately, though SwiftPM's shared cache helps.
4. **The release's self-check is not the card's check.** `archive_and_check` uses `aa extract` and `codesign` (`release.sh:206-214`), not `BundleInstall.admits` or `CodeSignature.isGenuine`. If the card's Swift code is removed from the app (the plan's direction), nothing in the repository will still run those rules, yet R16 binds every future release. `--archive-only` tests cover the script only.
5. **`codesign` checks at `release.sh:378-383` read the main app only.** The nested check first happens on the unpacked copy at `:210`, after notarisation. A helper left unsigned would be caught by Apple's notary service first (Inference).
6. **Sparkle links at load time in every build.** The executable links it non-weakly (Observed), so Debug, perf, ~/Applications copies and standard accounts all load Sparkle, and through it WebKit, even when R2 and R12 say the updater never starts. R2 is about network requests, so this breaks no requirement, but `docs/product-overview.md` promises the least resources. The memory cost was not measured.
7. **`SourcePolicyTests` bans `import WebKit` only in this repo's sources.** Sparkle's own dependency on it is outside the scan. Likewise the `Process()` and `curl` bans: Sparkle's helpers spawn `/usr/bin/aa` (Read).
8. **A retried release reuses its build number.** After a failure before the push, the commit is undone and the same version and build come back (`release.sh:18-21`). That is fine for Sparkle because nothing was published.
9. **`docs/architecture.md:36` and `release.sh:39-42` call the asset name and inner bundle name a contract with every shipped version.** Sparkle does not need that name. If the Sparkle enclosure were a separate asset, the `.aar` must still be published for R16.
10. **The DMG could also be a Sparkle enclosure.** Sparkle's docs recommend reuse, and it holds `Trackpad Launcher.app`. It is the only format that allows EdDSA rotation under `SUVerifyUpdateBeforeExtraction`. Not probed.
11. **Sparkle's `Updater.app` declares no `NSSupportsSuddenTermination`** (Observed), and `LSUIElement` is `"1"`. The source-policy manifest scan covers only `project.yml` (`SourcePolicyTests.swift:95-97`), so it would not catch a future Sparkle declaring it.
12. **Fixture signing state.** `UpdateFixtures/` holds a genuine notarised fixture identified `com.domasgru.TrackpadLauncherUpdateFixture`, regenerated only with `NOTARY_PROFILE` set (`make-update-fixtures.sh:14`).
13. **`build_image` needs Finder Automation permission** and asks once (`release.sh:14-15`, `:282-284`), so a release is not fully headless today regardless of Sparkle.

## Open Questions

- **Developer ID export and notarisation of a bundle with Sparkle.** Not run, because I did not use the Developer ID key. Unknown first-hand: that `-exportArchive` with `developer-id` puts secure timestamps on every helper, that the notary service accepts it, and that `isGenuine` returns true on the stapled result. Sparkle's docs say the workflow works. A real notarised test release is needed for R16's "one press" scenario.
- **Hardened-runtime load of Sparkle in the app.** I did not launch any scratch app, because an opening by hand stops other running copies, including the installed one (`docs/architecture.md:11`). Only the unhardened test runner loaded it. Same-team signing should satisfy library validation (Sparkle docs). Not proven here.
- **Cold-cache behaviour** of `swift test --disable-keychain` and of plain `swift test` after the prompt is answered.
- **Why the keychain lookup blocked.** I did not find which item it was reading.
- **Xcode's `Package.resolved` under variant A.** None appeared in the generated project. I did not determine whether Xcode writes one elsewhere. Pin stability rests on `exact:`.
- **Notary profile.** Presence not confirmed directly, as stated in the tools table.
- **`gh release create` partial failure.** I did not test whether a failed upload leaves a draft, which `preflight_version` would then treat as an earlier release (`release.sh:176`).
- **`SUVerifyUpdateBeforeExtraction` plus `SURequireSignedFeed`.** Available and described in Sparkle's docs; whether the feed should be signed is a design choice I did not explore.

## Side effects of this exploration

- **Keychain:** the first `swift test` may have shown a keychain dialog on this Mac. I killed that process and the concurrent `xcodebuild`, both mine, rather than leave it waiting.
- **Stray file:** a relative `-o appcast.xml` briefly wrote `appcast.xml` into the worktree root. I moved it out; `git status` afterwards showed only `plans/039-auto-updates/`.
- **Signing:** scratch builds were signed with Apple Development, the identity `make run` uses. Nothing was signed with Developer ID, notarised, pushed or published. A throwaway random seed was used for `generate_appcast`. No key was added to the keychain.
- **Left behind in SwiftPM's shared locations:** `~/Library/Caches/org.swift.swiftpm/repositories/Sparkle-09d89c53`, the artifact zip in `~/Library/Caches/org.swift.swiftpm/artifacts/`, and `~/Library/org.swift.swiftpm/security/fingerprints/sparkle-3462f34e.json`. These are harmless caches. I left them because parallel explorers share them. Note that a warm cache here hides the cold-cache path.
- **Removed after use:** the scratch folder and `~/Library/Caches/Sparkle_generate_appcast`.
