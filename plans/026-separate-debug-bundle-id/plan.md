# Plan: Debug builds get their own bundle identifier

## Problem statement

Debug builds and the released app share the bundle identifier `com.domasgru.TrackpadLauncherApp`, but Debug builds are signed with Apple Development and releases with Developer ID. macOS stores each Accessibility and Screen Recording grant under the bundle identifier, together with the designated requirement of the copy that was granted. After a Debug build was granted, System Settings showed "Trackpad Launcher" as allowed, yet the installed release copy was refused because its signature did not match the stored requirement. Its settings window kept both the Accessibility and the Screen Recording hint, and the toggle in System Settings looked already on. This happened on the developer's Mac with release 1.0.1 (TCC entries inspected on 2026-11-03). The same applies in the other direction: granting the release copy leaves a Debug build refused.

The single-instance rule depends on the shared identifier: `SystemRunningCopies.others()` lists running copies by `Bundle.main.bundleIdentifier`, so opening a Debug build today stops the resident release copy, and the reverse. Separating the identifiers alone would let both copies run at once, and both would react to every gesture.

## Requirements

### R1. Debug builds have their own bundle identifier
The Debug configuration MUST build the app with bundle identifier `com.domasgru.TrackpadLauncherApp.debug`. The Release configuration (the notarized release and the perf build of `Scripts/perf/build.sh`) MUST keep `com.domasgru.TrackpadLauncherApp`, so installed users keep their grants, settings and login item.

#### Scenario: Grants no longer cross between Debug and release
- **GIVEN** a Debug build has been allowed Accessibility and Screen Recording
- **WHEN** the released app is opened
- **THEN** System Settings lists the Debug build and the released app as separate entries, and the released app's grants are its own

### R2. A Debug copy and a release copy are still one app at runtime
Every copy of Trackpad Launcher, Debug or release, MUST count the other's running copies as its own when deciding which copy stays (today's single-instance rule, unchanged otherwise): opening a Debug build while a release copy runs MUST stop the release copy, and the reverse, so only one copy ever reacts to gestures.

#### Scenario: Opening a Debug build replaces the installed copy
- **GIVEN** the installed release copy is running
- **WHEN** the developer opens a Debug build by hand
- **THEN** the release copy exits and only the Debug build reacts to gestures

### R3. Nothing else that matches by bundle identifier changes behaviour for users
Release builds MUST behave exactly as before. Other matches by the app's own bundle identifier (such as the move-to-Applications installer replacing a copy with the same identifier) stay per identifier.

## Non-goals

- A separate display name for Debug builds. Both entries read "Trackpad Launcher" in System Settings; the request was only the identifier, and the name is visible in the menu bar and window title.
- Migrating Debug builds' saved settings from the release defaults domain. Debug builds start with fresh settings under their own domain; that is a developer-only one-off.
- Removing stale TCC entries from earlier experiments on the developer's Mac.
- Separating the perf build's identifier from the release's: R1 keeps the perf build on the release identifier, so its Accessibility grant and the installed release's still share one TCC entry, and allowing one can refuse the other.

## Implementation Decisions

- **The bundle identifier is set per configuration, in the xcodegen project spec.** `PRODUCT_BUNDLE_IDENTIFIER` leaves the app target's base settings and is set in its per-configuration settings: Debug `com.domasgru.TrackpadLauncherApp.debug`, Release `com.domasgru.TrackpadLauncherApp`. Nothing else in the build changes. The Release configuration is what both the notarized release and the perf build compile (the perf build overrides only the signing identity on its command line), so both keep the release identifier. The identifiers are not put in the xcconfigs: xcodegen's `bundleIdPrefix` option fills in a `PRODUCT_BUNDLE_IDENTIFIER` for a target whose settings set none, and target settings shadow xcconfig values, so an xcconfig value could be silently overridden; the per-configuration target settings are the one level nothing shadows. A prototype confirmed it: with the two per-configuration values, the generated project carries exactly those two settings and nothing else for the key, and `xcodebuild -showBuildSettings` resolves Debug to `com.domasgru.TrackpadLauncherApp.debug` and Release, with the perf build's `CODE_SIGN_IDENTITY="Apple Development"` override, to `com.domasgru.TrackpadLauncherApp`.
- **The family of identifiers is derived in one place, as a pure function.** `SystemRunningCopies`, the real adapter of the `RunningCopies` port, gains a pure static function that maps one bundle identifier to the set of identifiers of every build of that app: the release identifier (the given one with a trailing `.debug` component removed, when it has one) and that identifier with `.debug` appended. `others()` is one flat map over the whole family: it lists the running applications of each identifier in it rather than of this copy's identifier alone, then drops this process as today. That function is the only code that knows the `.debug` convention; the identifiers themselves live in the project spec and in the release command's guard. The `RunningCopies` port, its in-memory test adapter and `Lifecycle` are untouched but for the port's doc comment on `others()`, which today reads "with this bundle identifier" and comes to read "every other running Trackpad Launcher, Debug or release": the port already promises "the running Trackpad Launcher processes", and which identifiers those are is the adapter's business. No core change, no new port, no new type.
- **The adapter reads its own identifier through its initialiser**, defaulting to the main bundle's, in the manner of `ApplicationsInstaller`'s test initialiser, so a test can run the adapter as a copy with any identifier against the real list of running applications. A process with no identifier lists no copies, as today.
- **The release command guards the release identifier.** `Scripts/release.sh`'s archive check, which already fails when the archived app's Team ID is not ours, also fails when its code-signing `Identifier` is not exactly `com.domasgru.TrackpadLauncherApp`: a whole-line match, as the Team ID check makes, so `com.domasgru.TrackpadLauncherApp.debug` fails it. Under another identifier a release would be a different app to macOS, with fresh grants, settings and login item, and one no installed copy would accept as an update, since the update's genuineness check pins the signer's identifier. The check needs no credential, so it is fatal in `--archive-only` mode too, and the script's usage text, which says that mode only reports the stapler and Team ID checks, says so.
- **Nothing else follows the identifier.** The move's installer keeps matching the bundle with this copy's own identifier inside /Applications; the update keeps matching the signer's identifier read from the signature; settings (the standard `UserDefaults` suite), the login item and the Accessibility and Screen Recording grants are keyed by macOS on the identifier and so come apart for Debug builds by themselves, which is the point. Every other adapter excludes this process by pid, not by identifier. The glossary gets a *Debug build* entry and the architecture's build bullet records the identifier scheme.

## Testing Decisions

### Strategy

Two seams, both existing. The pure family function on `SystemRunningCopies` is tested as `LauncherKit/Tests/LauncherPlatformTests/RunningCopiesOrderTests.swift` tests `started(_:before:)`: it observes the derivation and misses the wiring. The adapter's `others()` is run against the real list of running applications, as `LauncherKit/Tests/LauncherPlatformTests/RunningAppsReaderTests.swift` reads the real workspace: the adapter is built as a copy whose identifier is the Debug member of Finder's family (`com.apple.finder.debug`), so Finder stands in for the installed release copy and the Debug-stops-release direction is proven against the real system; it misses the release-lists-Debug direction: observing it needs a running process under a `.debug` identifier, which no test can cheaply provide, so that half rests on `others()` being one flat map over the whole family (T1 and T2 prove the family holds both members) and on the slice's by-hand R2 step, the installed release opened by hand stopping the Debug build. Nothing is faked; the running-application list is real, and the adapter test is enabled only while Finder runs, as `RunningAppsReaderTests` gates on the Mac. R1 is build configuration: no test under `swift test` can observe the Xcode build's product, so it is verified by reading the resolved build settings and the perf build's Info.plist, and guarded at every release by the release command. R3 asks that unchanged code stay unchanged: the existing suite stays green and a grep shows the own identifier is read in one place.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R2 | Pure family function | Given the release identifier `com.domasgru.TrackpadLauncherApp` / When its family is derived / Then it is the set of `com.domasgru.TrackpadLauncherApp` and `com.domasgru.TrackpadLauncherApp.debug` | R1's two literals |
| T2 | R2 | Pure family function | Given the Debug identifier `com.domasgru.TrackpadLauncherApp.debug` / When its family is derived / Then it is the same set as T1: the family never depends on which build asks | R1's two literals |
| T3 | R2 | `SystemRunningCopies.others()` against the real running applications | Given Finder runs, and an adapter built as a copy with identifier `com.apple.finder.debug`, and another built as `com.apple.finder` / When each lists its other running copies / Then both list exactly Finder's processes, by pid | `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")` read independently in the test |

### Verified without a test

- **R1.** No test under `swift test` builds the app or sees the Xcode project; the resolved build settings and the built bundles are the ground truth. The build settings, after `xcodegen generate`: `xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -destination 'generic/platform=macOS' -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER` prints `com.domasgru.TrackpadLauncherApp.debug`; the same with `-configuration Release CODE_SIGN_IDENTITY="Apple Development"` (the perf build's command line) prints `com.domasgru.TrackpadLauncherApp`; and the generated `project.pbxproj` holds exactly two `PRODUCT_BUNDLE_IDENTIFIER` lines, one per value. The products: after `make run`, `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/dev/Build/Products/Debug/TrackpadLauncher.app/Contents/Info.plist` prints `com.domasgru.TrackpadLauncherApp.debug`; after `Scripts/perf/build.sh`, the same on `build/perf/dd/Build/Products/Release/TrackpadLauncher.app/Contents/Info.plist` prints `com.domasgru.TrackpadLauncherApp`. The release guard: `Scripts/release.sh --archive-only build/dev/Build/Products/Debug/TrackpadLauncher.app` exits non-zero naming the identifier, and the same on the perf build's app passes; at every release the guard runs again. The scenario by hand, on the developer's Mac, whose release entries still hold an old Debug build's requirement (the Problem statement's reproduction): first `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp` and `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp`; run the Debug build from Xcode and allow it Accessibility and Screen Recording; open the installed release; *System Settings › Privacy & Security* lists two *Trackpad Launcher* entries under Accessibility and two under Screen Recording, the release's off and its settings window showing both hints, until its own entries are turned on, which leaves the Debug entries as they were.
- **R3.** The requirement is that unchanged code behave as before, so a new test would restate existing ones. The check: `swift test` stays green with no existing test edited (the single-instance rule through `InMemoryRunningCopies` in `ReplacingOtherCopiesTests`, `ApplicationsInstallerTests`, the code-signature and updater tests); `git diff main --stat` touches, outside the plan folder and the docs, only the project spec, the running-copies adapter, the port's doc comment, the release command, the README and the new test file, and none of the other files that read a bundle identifier (the installer, the code signature, the running-app parsers, the quit signals); and the release identifier is unchanged, so every release-side key (grants, settings, login item, the update's signer) is unchanged.

## Further Notes

- The single-instance rule now spans both identifiers in every direction, "unchanged otherwise" included: a release's login start while a Debug build still runs ends itself, since an older copy runs, until the release is opened by hand, and a Debug build's login start never happens (it never registers for login outside /Applications).
- Debug builds start with fresh settings (a non-goal). The developer can carry the old ones over once by hand: `defaults export com.domasgru.TrackpadLauncherApp - | defaults import com.domasgru.TrackpadLauncherApp.debug -`.
- The developer's one-off recovery on a Mac whose release TCC entries hold a Debug build's requirement (a non-goal for the code): `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp` and `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp`, then allow the installed release again.
- The hand-testing path `--as-release-build` is unchanged in outcome: a Debug build moved to /Applications finds no bundle with its identifier there and falls back to its own name, so it lands on `/Applications/TrackpadLauncher.app` as it did when the identifiers were shared. Developer-only; per identifier as R3 asks.
- The literals: the two identifiers in the project spec, the release identifier in the release command's guard, the `.debug` suffix in the family function. All come from R1; T1 and T2 pin the code's suffix to R1's literals, the release command pins the shipped identifier, and the R1 checks pin the Debug configuration and its product.

## Slices

### S1: Debug builds carry their own identifier and still replace the release copy

**What to build:** A Debug build runs under `com.domasgru.TrackpadLauncherApp.debug`, so System Settings lists it apart from the installed release and neither's grants cross; opening either build by hand still stops the other, so only one copy ever reacts to gestures. The release and the perf build keep `com.domasgru.TrackpadLauncherApp`, and the release command refuses to ship anything else.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3.

**Test scenarios:** T1, T2, T3.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-macos`.

- [ ] T1–T3 are green and `swift test` is green with no existing test edited.
- [ ] R1: after `xcodegen generate`, the Debug configuration's resolved `PRODUCT_BUNDLE_IDENTIFIER` is `com.domasgru.TrackpadLauncherApp.debug` and the Release configuration's, with the perf build's `CODE_SIGN_IDENTITY="Apple Development"` override, is `com.domasgru.TrackpadLauncherApp`; the generated `project.pbxproj` holds exactly those two `PRODUCT_BUNDLE_IDENTIFIER` lines.
- [ ] R1: `make run`'s product has `CFBundleIdentifier` `com.domasgru.TrackpadLauncherApp.debug`; the perf build's product (`Scripts/perf/build.sh`) has `com.domasgru.TrackpadLauncherApp`.
- [ ] R1: `Scripts/release.sh --archive-only` on `make run`'s Debug product exits non-zero naming the identifier; on the perf build's app it passes. The match is whole-line, as the Team ID check's, and the script's usage text names the identifier check as fatal in that mode.
- [ ] R1 scenario by hand, after `tccutil reset Accessibility com.domasgru.TrackpadLauncherApp` and `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp`: with the Debug build allowed Accessibility and Screen Recording, the installed release shows as its own entry under each in *System Settings › Privacy & Security*, off and its settings window showing both hints, until turned on itself.
- [ ] R2 scenario by hand: with the installed release running, opening the Debug build from Xcode makes the release exit and only the Debug build reacts to gestures; opening the installed release by hand then makes the Debug build exit.
- [ ] R3: `git diff main --stat` touches, outside the plan folder and the docs, only the project spec, the running-copies adapter, the port's doc comment on `others()`, the release command, the README and the new test file.
- [ ] The port's doc comment on `others()` no longer says "with this bundle identifier"; the README names the Debug identifier, the second *Trackpad Launcher* entry in Privacy & Security and the separate settings.
