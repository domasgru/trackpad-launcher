# Grounding: build, versioning, signing, notarisation and distribution (angle "build-release")

Repository root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates` (paths below are relative to it). Raw facts only, no recommendations.

## Components Found

| Component | Path | What it is |
|---|---|---|
| xcodegen spec | `project.yml` | Generates `TrackpadLauncher.xcodeproj` (gitignored); one app target that depends on three SwiftPM products; holds the Info.plist properties and the bundle identifier. |
| SwiftPM package | `LauncherKit/Package.swift` | All library and test targets (`LauncherCore`, `LauncherPlatform`, `LauncherUI`, `LauncherCoreTests`, `LauncherPlatformTests`); tools 6.2, `platforms: [.macOS(.v26)]`. |
| Base xcconfig | `Config/Base.xcconfig` | Shared build settings: (uncommitted) `#include "Version.xcconfig"`, deployment target 26.0, universal arch, Swift 6 strict concurrency, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_STYLE = Manual`. |
| Debug xcconfig | `Config/Debug.xcconfig` | `CODE_SIGN_IDENTITY = Apple Development`, `DEVELOPMENT_TEAM = CQK27876UL`. |
| Release xcconfig | `Config/Release.xcconfig` | `CODE_SIGN_IDENTITY = Developer ID Application`, `DEVELOPMENT_TEAM = CQK27876UL`, `OTHER_CODE_SIGN_FLAGS = --timestamp`. |
| Version xcconfig (untracked, new) | `Config/Version.xcconfig` | `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`. |
| Generated Info.plist (gitignored) | `TrackpadLauncher/Info.plist` | Written by xcodegen from `project.yml` `info.properties`; values are build-setting substitutions. |
| Release script | `Scripts/release.sh` | The "one command": xcodegen, archive, export (developer-id), verify, notarise + staple app, build DMG, sign DMG, notarise + staple DMG, spctl assess. |
| DMG background generator | `Scripts/release/make-dmg-background.swift` (+ committed output `Scripts/release/dmg-background.png`) | Draws the 600x400 pt "Drag to Applications" background at 2x. |
| Perf build | `Scripts/perf/build.sh` | Release configuration build signed with `Apple Development`, into `build/perf/`. |
| Test runner | `Scripts/test.sh` | `swift test` in `LauncherKit`. |
| Code signature reader | `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift` | The only place that reads code signatures (`SecCode`, `SecStaticCode`, `SecRequirement`); decides `Build.release` vs `.development` by a Developer ID requirement string. |
| `Build` / `Placement` | `LauncherKit/Sources/LauncherCore/Placement.swift` | `Build` enum (`.release`, `.development`) and the pure `Placement` rule (`.installed`, `.development`, `.elsewhere`). |
| Source policy test | `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift` | Source scan: bans `URLSession` / `import Network` etc. and confines `SecCode`/`SecStaticCode`/`SecRequirement` to `CodeSignature.swift`. |

## Uncommitted working-tree changes (`git diff`)

`Config/Base.xcconfig`:
```
+#include "Version.xcconfig"
 MACOSX_DEPLOYMENT_TARGET = 26.0
```
`project.yml`:
```
-        CFBundleShortVersionString: "1.0"
-        CFBundleVersion: "1"
+        CFBundleShortVersionString: $(MARKETING_VERSION)
+        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
 ...
         GENERATE_INFOPLIST_FILE: NO
+        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```
Untracked: `Config/Version.xcconfig`, `TrackpadLauncher/AppIcon.icon/` (an Icon Composer bundle: `icon.json` + `Assets/app-icon.png`, white fill, macOS only), `plans/022-in-app-updates/`.

`Config/Version.xcconfig` in full:
```
// The version users see (CFBundleShortVersionString) and the build number (CFBundleVersion).
// Raise both for every release; the build number only ever goes up.
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
```
So on the committed `main`/HEAD the shipped version is the literal `"1.0"` / build `"1"`; in the working tree it becomes `1.0.0` / `1` via build settings. Version history: `git log -- Scripts/release.sh Config project.yml` shows only `1cf9c4b` (#1), `997a42f` (#26), `c9125b6` (#28); there are no git tags (`git tag -l` empty).

## project.yml (xcodegen) - `project.yml`
- `:1` `name: TrackpadLauncher`; `:3` `bundleIdPrefix: com.domasgru`; `:4-5` `deploymentTarget: macOS: "26.0"`.
- `:6-11` configs `Debug: debug`, `Release: release`; `configFiles` map `Debug -> Config/Debug.xcconfig`, `Release -> Config/Release.xcconfig`. In the generated pbxproj these attach as `baseConfigurationReference` on the PROJECT-level configurations (`project.pbxproj:264`, `:325`); the target-level configurations (`:245-260`, `:378-393`) set only `ASSETCATALOG_COMPILER_APPICON_NAME`, `COMBINE_HIDPI_IMAGES`, `GENERATE_INFOPLIST_FILE = NO`, `INFOPLIST_FILE = TrackpadLauncher/Info.plist`, `LD_RUNPATH_SEARCH_PATHS`, `ONLY_ACTIVE_ARCH = NO`, `PRODUCT_BUNDLE_IDENTIFIER`, `SDKROOT`. `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` therefore resolve from the project-level xcconfig chain (Debug/Release -> Base -> Version). `Version.xcconfig` is not a file reference in the pbxproj; it is only reached through `#include`.
- `:12-14` local package `LauncherKit` at `LauncherKit`; `:25-31` the app target depends on products `LauncherCore`, `LauncherPlatform`, `LauncherUI`.
- `:19-24` sources: `TrackpadLauncher` (excluding `Info.plist`) and `assets/*.svg|*.png` as resources. `AppIcon.icon` is picked up automatically as a resource (`project.pbxproj:19,37,210`).
- `:32-41` Info.plist properties (see table below). `:44` `PRODUCT_BUNDLE_IDENTIFIER: com.domasgru.TrackpadLauncherApp`; `:45` `GENERATE_INFOPLIST_FILE: NO`.
- Generated pbxproj Debug project config: `GCC_PREPROCESSOR_DEFINITIONS DEBUG=1` (`:306`), `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` (`:318`), `SWIFT_OPTIMIZATION_LEVEL = "-Onone"` (`:319`), `ENABLE_TESTABILITY = YES`. Release: `SWIFT_COMPILATION_MODE = wholemodule`, `SWIFT_OPTIMIZATION_LEVEL = "-O"`, `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, `ENABLE_NS_ASSERTIONS = NO`. `PRODUCT_NAME = "$(TARGET_NAME)"` so the bundle on disk is `TrackpadLauncher.app` and the executable `TrackpadLauncher`.
- No shared scheme directory is committed (`TrackpadLauncher.xcodeproj/xcshareddata/` holds none; xcodegen generates the scheme `TrackpadLauncher`). No entitlements file exists anywhere.

## Config/*.xcconfig
- `Config/Base.xcconfig` (working tree): `:1 #include "Version.xcconfig"`, `:2 MACOSX_DEPLOYMENT_TARGET = 26.0`, `:3 ARCHS = $(ARCHS_STANDARD)`, `:4 ONLY_ACTIVE_ARCH = NO`, `:5 SWIFT_VERSION = 6.0`, `:6 SWIFT_STRICT_CONCURRENCY = complete`, `:7 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `:8 ENABLE_HARDENED_RUNTIME = YES`, `:9 CODE_SIGN_STYLE = Manual`.
- `Config/Debug.xcconfig`: `:1 #include "Base.xcconfig"`, `:2 CODE_SIGN_IDENTITY = Apple Development`, `:3 DEVELOPMENT_TEAM = CQK27876UL`.
- `Config/Release.xcconfig`: `:1 #include "Base.xcconfig"`, `:2 CODE_SIGN_IDENTITY = Developer ID Application`, `:3 DEVELOPMENT_TEAM = CQK27876UL`, `:4 OTHER_CODE_SIGN_FLAGS = --timestamp`.
- Hardened runtime is on in BOTH configurations (Base). Signing is manual in both.

## Info.plist keys and where each value comes from
Generated file `TrackpadLauncher/Info.plist` (gitignored, `.gitignore:5`), current contents:

| Key | Value in plist | Source |
|---|---|---|
| CFBundleIdentifier | `$(PRODUCT_BUNDLE_IDENTIFIER)` -> `com.domasgru.TrackpadLauncherApp` | xcodegen default key; setting at `project.yml:44` |
| CFBundleShortVersionString | `$(MARKETING_VERSION)` -> `1.0.0` | `project.yml:37` (uncommitted) -> `Config/Version.xcconfig:3` |
| CFBundleVersion | `$(CURRENT_PROJECT_VERSION)` -> `1` | `project.yml:38` (uncommitted) -> `Config/Version.xcconfig:4` |
| LSMinimumSystemVersion | literal `26.0` | `project.yml:41` (hard-coded string, not `$(MACOSX_DEPLOYMENT_TARGET)`) |
| LSUIElement | `true` | `project.yml:39` (agent app; Dock icon is toggled at runtime by `setActivationPolicy`, confined to `SettingsShell.swift` per `SourcePolicyTests.swift:117-119`) |
| NSSupportsSuddenTermination | `true` | `project.yml:40` |
| CFBundleName / CFBundleDisplayName | `Trackpad Launcher` | `project.yml:35-36` |
| CFBundleExecutable | `$(EXECUTABLE_NAME)` -> `TrackpadLauncher` | xcodegen default |
| CFBundleDevelopmentRegion, CFBundleInfoDictionaryVersion 6.0, CFBundlePackageType APPL | defaults | xcodegen |

No `CFBundleIconFile`/`CFBundleIconName` key in the plist; with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` (uncommitted) actool is expected to add the icon name at build time (not verified by building).

"macOS 26" minimum is stated in four independent places: `project.yml:5` (deploymentTarget), `project.yml:41` (LSMinimumSystemVersion literal), `Config/Base.xcconfig:2` (MACOSX_DEPLOYMENT_TARGET), `LauncherKit/Package.swift:6` (`.macOS(.v26)`).

## The release command - `Scripts/release.sh` (traced)
Header `:1-15` states: archive, export with developer-id, notarise and staple the app, lay out a disk image, sign, notarise and staple it; output `build/release/TrackpadLauncher.dmg`; needs a "Developer ID Application" identity, a notarytool keychain profile named by `NOTARY_PROFILE`, xcodegen on PATH, Automation permission for Finder; "Signing of the app is left to xcodebuild, which signs nested code first and the main executable last; --deep is never used."

Variables (`:18-33`): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (forced), `TEAM_ID="${TEAM_ID:-CQK27876UL}"`, `APP_NAME="TrackpadLauncher"`, `VOLUME_NAME="Trackpad Launcher"`, `OUT="${RELEASE_OUT:-$ROOT/build/release}"`, `DMG="$OUT/$APP_NAME.dmg"`, `STAGE="$OUT/dmg-stage"`, `RW_DMG="$OUT/$APP_NAME-rw.dmg"`, window 600x400 at (200,120). `trap cleanup EXIT` (`:38-46`) detaches a mounted image and deletes the RW image and stage.

Modes: `--image-only <app>` (`:112-118`) builds an UNSIGNED image around an existing app and exits.

Full release, in order:
1. Preflight (`:120-130`): `security find-identity -v -p codesigning | grep -q "Developer ID Application"`; `NOTARY_PROFILE` set; `xcrun notarytool history --keychain-profile "$NOTARY_PROFILE"` succeeds; `command -v xcodegen`.
2. `rm -rf "$OUT"; mkdir -p "$OUT"` (`:132-133`) - each run wipes the previous output.
3. `(cd "$ROOT" && xcodegen generate)` (`:135`).
4. Archive (`:137-145`):
   ```
   xcodebuild archive -project "$ROOT/$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
     -destination 'generic/platform=macOS' -archivePath "$OUT/$APP_NAME.xcarchive" \
     CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID"
   ```
   (command-line overrides equal the Release.xcconfig values; hardened runtime and `--timestamp` come from the xcconfigs.)
5. Writes `$OUT/ExportOptions.plist` (`:147-158`): `method developer-id`, `teamID $TEAM_ID`, `signingStyle manual`, `signingCertificate Developer ID Application`.
6. Export (`:160-163`): `xcodebuild -exportArchive -archivePath ... -exportOptionsPlist ... -exportPath "$OUT/export"`; app at `$OUT/export/TrackpadLauncher.app` (`:165-166`).
7. Verify (`:168-173`): `codesign --verify --strict --verbose=2 "$APP"`; `codesign -dv --verbose=2` output must contain `Authority=Developer ID Application` and `flags=0x10000(runtime)`.
8. Notarise + staple the app (`:175-181`): `ditto -c -k --keepParent "$APP" "$ZIP"` (`$OUT/TrackpadLauncher-notarize.zip`); `xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait`; `xcrun stapler staple "$APP"`; `xcrun stapler validate "$APP"`; zip deleted. Comment `:175`: "The app is stapled before it goes into the image so a copy dragged out opens offline."
9. `build_image "$APP"` (`:50-110`): stage dir with `ditto "$app" "$STAGE/$APP_NAME.app"`, `ln -s /Applications`, `.background/dmg-background.png`; `hdiutil create -srcfolder ... -volname "Trackpad Launcher" -fs HFS+ -format UDRW -size <du+20>m`; attach read-write; wait (up to 20 s, `sleep 1` loop) for Finder to see the disk; AppleScript sets icon view, bounds, icon size 128, background, positions `TrackpadLauncher.app` at {150,190} and `Applications` at {450,190}; detach; `hdiutil convert ... -format UDZO -imagekey zlib-level=9 -o "$DMG"`.
10. Sign DMG (`:185-186`): `codesign --timestamp -s "Developer ID Application" "$DMG"`; `codesign --verify --verbose=2 "$DMG"`.
11. Notarise + staple DMG (`:188-190`): `xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait`; `xcrun stapler staple "$DMG"`; `xcrun stapler validate "$DMG"`.
12. Gatekeeper checks (`:192-193`): `spctl --assess --type open --context context:primary-signature -vv "$DMG"`; `spctl --assess --type execute -vv "$APP"`.
13. `echo "Release artifact: $DMG"` (`:195`).

Final artefacts in `build/release/` (gitignored, `.gitignore:7`): `TrackpadLauncher.dmg` (signed, notarised, stapled), `export/TrackpadLauncher.app` (signed, notarised, stapled), `TrackpadLauncher.xcarchive`, `ExportOptions.plist`. The script never reads or prints the version; the DMG name carries no version. Nothing is uploaded, tagged or published.

Local environment facts (observed, not in repo): `security find-identity -v -p codesigning` lists `Apple Development: dominykas.grubys@gmail.com (JFC6LR2268)` and `Developer ID Application: Dominykas Grubys (CQK27876UL)`; `notarytool` 1.1.3; `xcodegen` 2.46.0 and `gh` at `/opt/homebrew/bin`. No `/Applications/TrackpadLauncher.app` and no `build/` directory exist on this machine.

## Where releases are published today
- `git remote -v`: `origin https://github.com/domasgru/trackpad-launcher.git` (fetch/push).
- `gh repo view domasgru/trackpad-launcher --json visibility,isPrivate,defaultBranchRef` -> `PUBLIC`, `isPrivate: false`, default branch `main`.
- `gh release list --repo domasgru/trackpad-launcher` -> no output (no GitHub releases exist). `git tag -l` -> empty.
- No `gh release`, appcast, Sparkle, website URL or download host anywhere in tracked sources, scripts or docs (grep of `plans/**/*.md` outside 022 for `sparkle|appcast|gh release|github release` returns nothing). No README at the repo root.
- Docs on distribution: `docs/architecture.md:29-30` "## Distribution - Direct download only, as a disk image: the app and the image are each signed with Developer ID, notarized with `notarytool` and stapled; hardened runtime, no entitlements. One command builds it from the repository. Never sign with `--deep`; the main executable is signed last." `docs/product-overview.md:3`: "It ships as a signed, notarised disk image that shows 'drag to Applications'..." Neither says where the DMG is hosted.
- `docs/architecture.md:27`: "No network code of any kind ..." and the source-scan test enforces it (`SourcePolicyTests.swift:22-26` ban `URLSession`, `import Network`, `NWConnection`, `CFSocket`, `CFStream`; `:27-29` ban `FileHandle(forWriting`, `.write(to:`, `createFile(atPath` as "own files").

## How the running app reads its own identity today
- Version: NO code reads its own `CFBundleShortVersionString` or `CFBundleVersion` (grep over `TrackpadLauncher/`, `LauncherKit/Sources` finds none). The only version string in code is in the test fixture `LauncherKit/Tests/LauncherPlatformTests/BundleFixture.swift:39` (`"CFBundleShortVersionString": version` written into fake bundles), used by `ApplicationsInstallerTests.swift:22,38,40,53,55,66,68,80` with versions "1.0"/"2.0" to show the move replaces a copy "whatever its version" (`Ports.swift:175`).
- Bundle identifier: `Bundle.main.bundleIdentifier` in `LauncherKit/Sources/LauncherPlatform/SystemRunningCopies.swift:12` (finding other running copies); `Bundle(url: location.running)?.bundleIdentifier` and `Bundle(url: $0)?.bundleIdentifier` in `LauncherKit/Sources/LauncherPlatform/ApplicationsInstaller.swift:58,63` (finding the copy in /Applications to replace). `LauncherKit/Sources/LauncherCore/Apps.swift:205-211` reads other apps' `Contents/Info.plist` directly, with the comment "`Bundle(url:)` caches by path and would hide a bundle replaced in place."
- Code signature: `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift`:
  - `:8-9` requirement string: `"anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"` - Apple anchor + Developer ID intermediate + Developer ID Application leaf. It does NOT pin a team identifier (no `certificate leaf[subject.OU] = CQK27876UL`), does NOT include the `notarized` clause, and does not check the identifier.
  - `:14-22` `buildOfThisProcess(arguments:)`: `SecCodeCopySelf` + `SecCodeCheckValidity(me, [], requirement)` -> `.release`; otherwise `.release` only if `arguments.contains("--as-release-build")`, else `.development`.
  - `:26-32` `build(of url:)` (internal): `SecStaticCodeCreateWithPath` + `SecStaticCodeCheckValidity(code, kSecCSDoNotValidateResources, requirement)`; comment `:24-25` "Resources are not validated: a bundle edited after signing is still signed with a Developer ID." Used only by tests (`CodeSignatureTests.swift:12,45`); grep shows no production caller.
  - Nothing reads `kSecCodeInfoTeamIdentifier`, `SecCodeCopySigningInformation`, or any `teamIdentifier` (grep finds none).
  - `SourcePolicyTests.swift:111-113` confine `SecCode`, `SecStaticCode`, `SecRequirement` to `CodeSignature.swift` ("the code signature is read in one place").
- Composition: `TrackpadLauncher/TrackpadLauncherApp.swift:31-33` `ThisCopy.location()` then `Placement(build: CodeSignature.buildOfThisProcess(arguments: CommandLine.arguments), location:)`; `:36` `ApplicationsInstaller(location: location)`.

## Development build vs release build
- Runtime distinction is by signature, not by configuration: `LauncherCore/Placement.swift:3-7` `enum Build { case release; /// Not signed with a Developer ID: Xcode, the perf build, an ad-hoc binary. Never #if DEBUG. case development }`. Glossary `docs/domain-model.md:26-27` "Development build: A build not signed with a Developer ID, such as one run from Xcode or the performance build."
- `Placement.init` (`Placement.swift:42-50`): inside /Applications and not translocated -> `.installed` (any build); else `.development` for a development build; else `.elsewhere`.
- `--as-release-build` launch argument makes a non-Developer-ID build read as release (manual testing hook, `CodeSignature.swift:11-13`, tested `CodeSignatureTests.swift:15-20`).
- `#if DEBUG` is used only for developer tools: `TrackpadLauncher/TrackpadLauncherApp.swift:23,69,79,85` (animation tuner), `LauncherPlatform/AnimationTuner.swift:1`, `LaunchTuning.swift:51,59`, `BounceOverlay.swift:164`, `WorkspaceActions.swift:95`. `docs/architecture.md:22`: "Developer tools live in `#if DEBUG` and never ship."
- Configurations: Debug (`-Onone`, `DEBUG` condition, signed `Apple Development`, team CQK27876UL, hardened runtime on); Release (`-O`, whole module, signed `Developer ID Application`, `--timestamp`, hardened runtime on).
- Perf build `Scripts/perf/build.sh:15-17`: `xcodebuild ... -configuration Release ... -derivedDataPath "$OUT/dd" CODE_SIGN_IDENTITY="Apple Development" build` -> optimised Release binary that `CodeSignature` reads as `.development`. Output `build/perf/dd/Build/Products/Release/TrackpadLauncher.app`. `docs/performance.md:8` describes it.
- Tests: `Scripts/test.sh` runs `swift test` in `LauncherKit`; test binaries are ad-hoc signed (`CodeSignatureTests.swift:10-13` asserts the test binary reads `.development`).

## Existing tests that touch the build or bundle
- `LauncherKit/Tests/LauncherPlatformTests/CodeSignatureTests.swift`: ad-hoc test binary is development (`:10-13`); exact `--as-release-build` matching (`:15-20`); cross-checks `CodeSignature.build(of:)` against `/usr/bin/codesign -dvv` "Authority=Developer ID Application" for every app in /Applications (`:35-47`, skipped unless both kinds exist).
- `LauncherKit/Tests/LauncherPlatformTests/BundleFixture.swift`: builds fake, unsigned, quarantined app bundles with `CFBundleIdentifier = com.example.TrackpadLauncherFixture` and a given `CFBundleShortVersionString` (`:6`, `:31-49`).
- `ApplicationsInstallerTests.swift`, `PrivilegedInstallTests.swift`, `ThisCopyTests.swift`, `ThisCopyLocationTests.swift` exercise the move/installer with those fixtures (not read in depth here; other explorers own the move).
- `SourcePolicyTests.swift` (network/file-write bans and Sec* confinement; scanned roots `LauncherKit/Sources` and `TrackpadLauncher/`, `:157-162`).
- No test reads the generated `Info.plist`, `project.yml` or the xcconfigs; no test checks the version, `LSMinimumSystemVersion` or the bundle identifier of the real app.

## research/ directory and prior notes
- No `research/` directory in the worktree or at `/Users/dominykasgrubys/code/trackpad-launcher/research` (ls: No such file or directory). No notes on Sparkle, appcasts or GitHub releases anywhere under `plans/` outside 022.
- Nearest prior notes (paths and headings only):
  - `plans/021-background-agent-lifecycle/.temp/architect/grounding/how-build-release.md` - "Grounding: build, test and release tooling, and the test harness shape": sections "project.yml (xcodegen)", "Config/*.xcconfig", "How a running app could tell development from release (R23)", "Scripts/release.sh (full behaviour)", "SourcePolicyTests - full rules", "Distribution policy (docs)", "research/ directory" (states none existed then either).
  - `plans/001-trackpad-launcher-app/.temp/architect/checks/status-item-and-hardened-runtime.md` - "Checks gathered after fan-out": "Hardened runtime and `dlopen` of MultitouchSupport" (no entitlement needed; no `--deep`).
  - `plans/021-background-agent-lifecycle/plan.md` R22-R24 (release/move/build rules), referenced by the 021 grounding.

## Flow (release build, end to end)
1. Developer edits `Config/Version.xcconfig` (working-tree convention; comment says raise both numbers each release).
2. `NOTARY_PROFILE=<name> Scripts/release.sh` -> preflight -> wipe `build/release` -> `xcodegen generate` (regenerates `TrackpadLauncher/Info.plist` from `project.yml` with `$(MARKETING_VERSION)` etc.) -> `xcodebuild archive` (Release, Developer ID, team CQK27876UL, hardened runtime, `--timestamp`; Xcode substitutes Info.plist variables) -> `-exportArchive` (developer-id) -> codesign verify + authority/runtime checks -> zip, notarytool submit --wait, staple, validate app -> DMG layout via hdiutil + Finder AppleScript -> UDZO -> codesign DMG -> notarytool submit --wait, staple, validate DMG -> spctl assess both.
3. Output `build/release/TrackpadLauncher.dmg`; distribution step beyond this is manual and undocumented.
4. At runtime the app classifies itself via `CodeSignature.buildOfThisProcess` -> `Placement`; it never reads its version.

## Boundaries
- Inputs to the pipeline: `Config/Version.xcconfig` (version), `project.yml` (bundle id, plist keys, min macOS literal), keychain identity "Developer ID Application" (team CQK27876UL, overridable by `TEAM_ID` env), notarytool keychain profile (`NOTARY_PROFILE` env), `RELEASE_OUT` env, Finder Automation permission, `/Applications/Xcode.app`.
- Outputs: `build/release/TrackpadLauncher.dmg` (+ `export/TrackpadLauncher.app`, xcarchive). No upload, no tag, no release metadata (no minimum-macOS declaration outside the app's own Info.plist).
- Runtime boundary: `CodeSignature` (LauncherPlatform, Security framework) -> `Build` (LauncherCore) -> `Placement` -> `Lifecycle`/`StartAtLogin`/`ApplicationsInstaller`.
- Policy boundary: `SourcePolicyTests` bans network APIs and file writes outside confined files; any update feature touches these lists.

## Non-Obvious Things
- `TrackpadLauncher/Info.plist` and the `.xcodeproj` are gitignored and regenerated by xcodegen; the source of truth for plist keys is `project.yml`. Editing the plist directly is lost.
- `CFBundleShortVersionString`/`CFBundleVersion` substitution is uncommitted work; HEAD ships `"1.0"`/`"1"` literally, the working tree `1.0.0`/`1`. The plan's examples use three-part versions (1.0.0, 1.1.0, 1.10.0).
- `LSMinimumSystemVersion` is a literal `"26.0"` in `project.yml:41`, separate from `MACOSX_DEPLOYMENT_TARGET` (Base.xcconfig:2), xcodegen `deploymentTarget` (project.yml:5) and SwiftPM `.macOS(.v26)`; they can drift.
- The Developer ID requirement in `CodeSignature.swift:9` accepts ANY Developer ID Application certificate (any team) and does not require notarisation; the team ID `CQK27876UL` appears only in xcconfigs and `release.sh:20`, never in Swift code.
- `CodeSignature.build(of:)` deliberately skips resource validation (`kSecCSDoNotValidateResources`) so a bundle edited after signing still reads as release; it has no production caller today.
- The bundle on disk is `TrackpadLauncher.app` (PRODUCT_NAME = target name) while the display name and DMG volume are "Trackpad Launcher"; test fixtures use "Trackpad Launcher.app" too, and `ApplicationsInstaller.destination` matches by bundle identifier, preferring a direct child of /Applications.
- `release.sh` wipes `$OUT` at start and has no versioned artefact name, so successive releases overwrite `build/release/TrackpadLauncher.dmg`.
- The app is notarised and stapled before being put on the DMG (so a dragged-out copy has its own ticket), then the DMG is notarised and stapled separately: two notarytool round-trips per release.
- Hardened runtime is on in Debug too; Debug is signed with Apple Development under the same team, so `CodeSignature` still says `.development` for it.
- `--timestamp` is only in Release (`OTHER_CODE_SIGN_FLAGS`), and the perf build (Release config) inherits it while signing with Apple Development.

## Open Questions
- Whether `xcrun notarytool submit --wait` exits non-zero on an "Invalid" result was not verified; if it exits 0, the following `stapler staple` under `set -e` would be what fails.
- Whether actool adds `CFBundleIconName` for `AppIcon.icon` with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` was not verified by building.
- Where the DMG is meant to be hosted is not stated anywhere in the repo; the GitHub repo is public with no releases and no tags.
- How `ThisCopy`, `ApplicationsInstaller`, `BundleInstall`, `PrivilegedInstall` handle replacement in depth was not traced here (other explorers' angle).
