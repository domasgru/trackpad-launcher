# Grounding index: Trackpad Launcher

Produced 2026-10-09 on the development machine: macOS 26.6.2 (25G83), Mac15,6 (14" MacBook Pro, Apple silicon), built-in trackpad only, user logged in at the console.

## Standing of this grounding

- **Greenfield.** The repository holds no code, no `docs/architecture.md`, no `research/`. There is no surrounding system to integrate with, so the `how` and `why` skills did not run. Everything below is platform behaviour and toolchain fact.
- Standing of each fact: `probed` (what a probe printed here today; conclusions are marked as conclusions), `sourced` (file and heading), `disputed`/`open` (both sides).
- Probe sources, outputs and a run table: `probes/README.md`.

## Facts, grouped by design question

### Q1. Reading raw trackpad touches with no permission prompt (R11, R16, R20, R22)

- **probed** (`probes/mt-probe`): `dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport")` succeeds from a plain, unsigned, unsandboxed process with no link flags. Every symbol the design needs resolves with `dlsym`: `MTDeviceCreateList`, `MTDeviceIsBuiltIn`, `MTDeviceGetDeviceID`, `MTDeviceGetSensorSurfaceDimensions`, `MTDeviceGetFamilyID`, `MTDeviceIsRunning`, `MTDeviceIsAlive`, `MTRegisterContactFrameCallback`, `MTUnregisterContactFrameCallback`, `MTDeviceStart`, `MTDeviceStop`, `MTDeviceRelease`, `MTActuatorCreateFromDeviceID`, `MTActuatorOpen`, `MTActuatorIsOpen`, `MTActuatorActuate`, `MTActuatorClose`. The full export list (`dyld_info -exports`) is 130+ `MT*` symbols; there is **no** `MTRegisterMultitouchDeviceAddedCallback` or similar hot-plug symbol.
- **probed**: `MTDeviceCreateList()` returned 1 device: `builtIn=true`, `id=504403158265495834 (0x70000000000011a)`, sensor surface `12480 x 7680` (hundredths of mm, so 124.8 mm × 76.8 mm), family 109. `MTDeviceStart(dev, 0)` returned 0 and `MTDeviceIsRunning` turned true. `MTDeviceStop` returned 0. No TCC log entries were written for the process (`log show` over the probe window, predicate on `com.apple.TCC`). Conclusion: starting a multitouch device needs no permission on macOS 26.6.
- **probed**: over two listen windows (12 s + 25 s) with the user idle, the contact-frame callback fired 0 times. Conclusion: the callback is silent while nothing touches the trackpad, which is what R22 (zero idle CPU) needs; a running MT device costs nothing while idle.
- **not probed** (user idle during both windows): frame delivery and the frame layout. **sourced** from community projects that use exactly this mechanism (MiddleClick, OpenMultitouchSupport, HapticKey), consistent across sources:
  - callback signature `int cb(MTDeviceRef, MTTouch *touches, int count, double timestamp, int frame)`; registered with `MTRegisterContactFrameCallback`; delivered on a background thread owned by the framework, not the main thread;
  - `MTTouch` is 96 bytes (probe confirmed the Swift mirror's stride is 96): `frame: Int32, timestamp: Double, identifier: Int32, state: Int32, fingerID: Int32, handID: Int32, normalized: (pos x,y; vel x,y) Float, zTotal: Float, _: Int32, angle, majorAxis, minorAxis: Float, absolute (mm): (pos; vel) Float, _: Int32 ×2, zDensity: Float`;
  - `state` values: 0 NotTracking, 1 StartInRange, 2 HoverInRange, 3 MakeTouch, 4 Touching, 5 BreakTouch, 6 LingerInRange, 7 OutOfRange. A finger is *down* in states 3 and 4;
  - `normalized.pos` is in 0...1 with origin **bottom-left**, so the top-left corner is `x < 0.2 && y > 0.75`;
  - frames arrive at roughly 90–125 Hz while any finger touches, and one final frame with `count == 0` when the last finger lifts.
  The first implementation slice must verify these four bullets by printing a few frames with a real touch (the probe is ready for that: run `mt-probe` and touch the trackpad). The design keeps the frame-to-domain parse in one adapter so a layout correction is a one-place change.
- **sourced** (`MacOSX.sdk/.../AppKit/NSEvent.h`, comment above `addGlobalMonitorForEventsMatchingMask:`): global monitors receive copies of events posted to other applications; only *key-related* events need accessibility. Not needed by the design (see Q2) but available without a prompt for mouse events.

### Q2. Telling a physical click from a tap (R11 "Click is not a tap")

- **probed**: `CGEventSource.buttonState(.combinedSessionState, button: .left)` returns from a plain process with no prompt and no TCC entry (printed `false`; the user was idle so `true` was not observed).
- **sourced** (`MacOSX.sdk/.../CoreGraphics/CGEventSource.h`, "Return a Boolean value indicating the current button state of a Quartz event source"): it is a state query, not an event tap; no TCC category covers it.
- Conclusion: sampling left/right/other button state on every multitouch frame while a tap is in progress detects the click without monitors, main-thread hops or permissions. Frames come every ~8–11 ms and a physical click's down state lasts longer than that.
- MTTouch carries no button state (sourced: struct above). `zTotal` is pressure, not click; not usable for this.

### Q3. Haptic pulse on the trackpad the gesture was performed on (R13)

- **probed**: `MTActuatorCreateFromDeviceID(id)` with the ID from `MTDeviceGetDeviceID` returned an actuator; `MTActuatorOpen` → 0, `MTActuatorIsOpen` → true, `MTActuatorActuate(act, 6, 0, 0, 0)` → 0 (`kIOReturnSuccess`), `MTActuatorClose` → 0. The device ID equals the IORegistry property `Multitouch ID` on the `AppleMultitouchDevice` service (probed: both print 504403158265495834).
- **sourced** (HapticKey, `HTKMultitouchActuator`): actuation IDs 3 (weak), 4 (medium), 6 (strong), 15, 16 are valid; `unknown1 = 0`, `unknown2 = unknown3 = 0.0`. The strength to ship is a feel decision for implementation.
- **sourced** (`MacOSX.sdk/.../AppKit/NSHapticFeedback.h`, lines 29 and 36): `NSHapticFeedbackManager.defaultPerformer` is "the most appropriate feedback performer for the current input device" and "Force Touch trackpads will not perform the feedback if the user isn't currently touching the trackpad". It cannot be aimed at a device, so it cannot satisfy "the Magic Trackpad pulses, not the built-in one". The actuator path can: one actuator per MT device, keyed by the device the frame came from.

### Q4. Gestures active / inactive: trackpad settings and live updates (R2, R14, R15)

- **probed** (`defaults read`): two preference domains with the same schema exist on disk: `com.apple.AppleMultitouchTrackpad` (built-in trackpad; `~/Library/Preferences/com.apple.AppleMultitouchTrackpad.plist`) and `com.apple.driver.AppleBluetoothMultitouch.trackpad` (external trackpad; its plist was last written 2026-10-07 although no external trackpad is connected, so System Settings writes it regardless). Both hold `Clicking`, `TrackpadThreeFingerTapGesture`, `TrackpadTwoFingerDoubleTapGesture` (currently 0, 0, 1). The globals `com.apple.mouse.tapBehavior`, `com.apple.trackpad.threeFingerTapGesture`, `com.apple.trackpad.twoFingerDoubleTapGesture` do **not** exist in `NSGlobalDomain` on this machine (Tap to click is off here), so they are not a reliable read; the per-domain keys are.
- **sourced** (community `defaults` documentation, consistent across sources; not verifiable here without toggling the user's settings): `Clicking = 1` is *Tap to click* on, `0` off. `TrackpadThreeFingerTapGesture = 2` is *Look up: Tap with three fingers*; `0` is *Off* or *Force Click with one finger*. `TrackpadTwoFingerDoubleTapGesture = 1` is *Smart zoom* on. **open**: the exact mapping of *Force Click with one finger* (believed to be `0` with `ForceSuppressed = 0`). The design must keep "which keys, which values, which notice text" in one table so a correction or the Smart zoom addition (R14) is a data change.
- **probed** (`probes/kvo-probe`): KVO on `UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")` for a key fires **on the main thread** when another process writes or deletes that key via cfprefsd (`defaults write` / `defaults delete`), with old and new values. `UserDefaults.didChangeNotification` did **not** fire for the suite (0 notifications). Conclusion: push-based change detection with no polling and no timers; it comfortably meets "within 5 seconds". System Settings writes through the same cfprefsd path (`defaults read` reflects its changes immediately), so the same KVO fires for it.
- **probed**: reading the value is cheap and permission-free (`suite.object(forKey:)` and `CFPreferencesCopyAppValue` both returned 0 for `Clicking`).
- Which domain applies to which connected trackpad: `MTDeviceIsBuiltIn` (probed, true for the built-in) selects the built-in domain; any other MT device selects the external domain. **open**: a Magic Trackpad connected over USB cable rather than Bluetooth may or may not read the Bluetooth domain. Treat as a risk; the mapping is one function.
- **sourced** (`/System/Library/ExtensionKit/Extensions/TrackpadExtension.appex` strings): the pane identifier is `com.apple.preference.trackpad`; opening `x-apple.systempreferences:com.apple.preference.trackpad` via `NSWorkspace.open(_:)` opens System Settings on the Trackpad pane (standard URL scheme; R15 button).

### Q5. Trackpads connected later, and sleep/wake (R16)

- **probed**: `IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("AppleMultitouchDevice"), ...)` returns 0 and its iterator yields the existing device with the `Multitouch ID` property. Conclusion: the same registration fires for every trackpad that appears later (that is what first-match notifications do); `kIOTerminatedNotification` on the same class reports removal. The notification port was scheduled on a private dispatch queue, which worked.
- **sourced** (`MacOSX.sdk/.../AppKit/NSWorkspace.h` line 323): `NSWorkspaceDidWakeNotification` exists. **sourced** (MiddleClick's wake handling): multitouch devices stop delivering frames after sleep and have to be re-enumerated and restarted. The design should make "reconcile the device set" one idempotent operation run at launch, on IOKit add/remove and on wake (per `make-operations-idempotent`), instead of three code paths.
- `MTDeviceCreateFromDeviceID` exists (export list) for building an MTDevice from the IORegistry ID if the design wants to avoid re-listing.

### Q6. Bringing the target app to the front (R12)

- **probed** (`probes/activate-probe`, a background CLI process driving `NSWorkspace.shared.openApplication(at:configuration:)` with `configuration.activates = true` against a throwaway AppKit app):
  1. not running → launched and active (`frontmostApplication` is the target);
  2. hidden via `NSRunningApplication.hide()` → `didUnhide`, `didBecomeActive`, then a reopen event (`applicationShouldHandleReopen hasVisibleWindows=true`);
  3. only window minimised → reopen delivered with `mini=true`, then `windowDidDeminiaturize` with the same frame; app active;
  4. only window closed → reopen delivered with `hasVisibleWindows=false` (opening a new window is the target's own reopen handling, exactly as with a Dock click);
  5. already active → reopen delivered, window frame unchanged;
  6. after quit, two opens 50 ms apart → one instance (both completions reported the same pid).
  Conclusion: this one call reproduces the Dock-click contract of R12 from a process that is not active (macOS 14+ cooperative activation does not block it), and is idempotent under a double tap. Switching to the Space holding the window and leaving a full-screen app are macOS's own behaviour on activation and were not probed (manual check).
- **sourced** (`NSWorkspace.h` line 175): `createsNewApplicationInstance` defaults to NO, "prefers to reuse a running instance".

### Q7. App identity, resolution, and the picker (R5, R6, R7)

- **sourced** (`MacOSX.sdk/.../AppKit/NSWorkspace.h` lines 114, 117): `urlForApplication(withBundleIdentifier:)` (10.6+) and `urlsForApplications(withBundleIdentifier:)` (12.0+, returns every registered copy). **open**: whether LaunchServices includes copies in the Trash. The design must filter out URLs under any `.Trash` / `.Trashes` directory regardless, and prefer the last-known location when it still holds that bundle ID (fast path, also covers apps picked from unregistered places such as ~/Downloads).
- **sourced** (Foundation/AppKit, standard): `Bundle(url:)?.bundleIdentifier` reads the identity; `FileManager.default.displayName(atPath:)` gives the localised name without `.app`; `NSWorkspace.shared.icon(forFile:)` gives the icon; `FileManager.enumerator(at:includingPropertiesForKeys:options: [.skipsPackageDescendants, .skipsHiddenFiles])` walks `/Applications`, `/System/Applications`, `~/Applications` without descending into bundles. Finder is `/System/Library/CoreServices/Finder.app`, `com.apple.finder`, and activates through the same `openApplication` call.
- **sourced** (AppKit `NSOpenPanel`): `allowedContentTypes = [.application]` with `canChooseDirectories = false` lets only application bundles be chosen (R5 "file chooser rejects non-apps").

### Q8. Menu bar presence, the window, Liquid Glass (R1, R3, R4, R9, R10, R15)

- **sourced** (Apple Info.plist key reference): `LSUIElement = true` keeps the app out of the Dock and ⌘-Tab while allowing a status item.
- **sourced** (`MacOSX.sdk` 26.5, `AppKit/NSGlassEffectView.h`): `NSGlassEffectView` (`contentView`, `cornerRadius`, `tintColor`, `style: .regular | .clear`) and `NSGlassEffectContainerView`, `API_AVAILABLE(macos(26.0))`. **sourced** (`SwiftUICore.swiftmodule/arm64e-apple-macos.swiftinterface` lines 2529, 5753, 9045): `View.glassEffect(_ glass: Glass = .regular, in shape:)`, `struct Glass`, `GlassEffectContainer`. Apps linked against the macOS 26 SDK get the Liquid Glass appearance; apps linked against older SDKs do not (Apple's macOS 26 adoption guidance), which is why Q10 matters.
- **sourced** (`SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` line 4629): `MenuBarExtra` with `WindowMenuBarExtraStyle` exists. The interface exposes no way to open or close the extra's window programmatically (no `isPresented` binding; grep found none). R18 (open on first launch) and R3 (a gesture closes the open window) need programmatic open/close, so a custom `NSStatusItem` + `NSPanel` hosting SwiftUI is the fit; `MenuBarExtra` is not.
- **sourced** (AppKit, standard pattern): an `NSPanel` with `.nonactivatingPanel` can become key without activating the app; `NSWindow.didResignKeyNotification` fires when the user clicks elsewhere (R3 "click outside closes"); `cancelOperation(_:)` / `keyDown` with Escape closes (R3). `NSStatusItem.button` with a template `NSImage` adapts to light and dark menu bars (R2).
- **probed** (`/System/Library/CoreServices/CoreGlyphs.bundle/.../name_availability.plist`): SF Symbols available for the icon: `hand.tap`, `hand.tap.fill`, `hand.point.up.left`, `rectangle.and.hand.point.up.left` (+ `.fill`/`.filled`). There is **no** slashed variant of any of them. The inactive state (R2 "same symbol with a slash") has to be drawn: the symbol plus a diagonal stroke, as a template image.
- **probed** (`probes/svg-probe`): `NSImage(contentsOf:)` loads all six SVGs in `assets/` (`_NSSVGImageRep`, sizes 48×31, 8×8, 10×10) and draws them as template images (opaque pixel counts > 0). Conclusion: the illustrations can be bundle resources tinted with the label colour for light/dark (R4) and mirrored with a horizontal flip for left-hand mode (R10); an asset catalog is possible too now that Xcode 26 is present (Q10), but not required.
- Design image (`docs/menubar-window.png`): four rows, each a 48×31 illustration on the left and an app icon + name + chevron popup on the right; a divider; the hint with inline thumb/other-finger marks; a bottom bar. R4 moves the hand toggle above the divider, drops Learn more…, and swaps the hint for the notice while inactive.

### Q9. Persistence, first launch, login item (R8, R17, R18, R19)

- **sourced** (Foundation): `UserDefaults.standard` persists across quit, relaunch and reboot (R8); values are read at launch.
- **sourced** (`MacOSX.sdk/.../ServiceManagement/SMAppService.h` line 91 and the discussion above it): `SMAppService.mainApp` (macOS 13+) with `register()`, `unregister()`, `status`; "Apps that use SMAppService APIs must be code signed". Registering the main app is what adds "Open at Login" under Login Items; macOS posts its own "login item added" notification (R17). The requirement that the app not re-enable itself after the user turns it off (R17 scenario 2) is met by registering only on first launch, gated on the persisted first-launch flag (R18 uses the same flag).
- **probed** (`security find-identity`): only an "Apple Development" identity is installed here; **no Developer ID** certificate. Local builds must be signed ad hoc or with the development identity; the R23 Developer ID + notarization step cannot be completed on this machine until a Developer ID certificate exists.

### Q10. Toolchain, build, test, distribution (R23 and everything that compiles)

- **probed**: `xcode-select -p` → `/Library/Developer/CommandLineTools` (CLT with SDK **15.4**, Swift 6.1). **Xcode 26.6 is installed** at `/Applications/Xcode.app` with macOS SDK **26.5**, Swift 6.3.3, `actool`, `xcodebuild`, `notarytool`. Setting `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` makes `swift`/`xcrun` use it (probed: `xcrun --sdk macosx --show-sdk-version` → 26.5). The macOS 26 SDK is required for Liquid Glass (Q8) and for `LSMinimumSystemVersion = 26.0` to be honest.
- **probed** (`probes/swift-testing-probe`): with the CLT toolchain, `swift test` builds a package with a library target, an executable target and a test target and runs Swift Testing (`@Test`, `#expect`, parameterised tests; "Testing Library Version: 124"). The Xcode 26 toolchain includes a newer Swift Testing.
- **probed**: `xcodegen` is installed (`/opt/homebrew/bin/xcodegen`); `tuist`, `swiftlint`, `swiftformat` are not.
- **sourced** (Apple Info.plist key reference): `LSMinimumSystemVersion` makes older macOS refuse to open the app with its own alert (R23 scenario "Older macOS").
- **sourced** (Apple notarization requirements): notarization checks signing, hardened runtime and malware, not private-framework use; direct-download apps may link private frameworks. `dlopen` of a system private framework works under the hardened runtime without extra entitlements (the probe ran unsigned; the shipping app signs with hardened runtime, and loading Apple-signed libraries is permitted).
- Universal binaries: `xcodebuild` builds `ARCHS_STANDARD` (arm64 + x86_64) by default; SwiftPM needs `--arch arm64 --arch x86_64`. **sourced** (SwiftPM usage), not probed.

### Q11. Zero idle cost, no logging, no network (R21, R22)

- **probed** (Q1, Q4, Q5): every input the app waits on is push-based (MT frames only while touched, cfprefsd KVO, IOKit notifications, workspace wake notification). No timer is needed anywhere, so idle CPU is 0.0%.
- No network API is needed by any requirement; the design should have no `URLSession`/`Network` import at all. No-logging is a rule to encode (per `encode-lessons-in-structure`): a test that scans the sources for `print(`, `NSLog(`, `os_log`, `Logger(` and fails on any hit is the strongest mechanism available without swiftlint.

## Sources, by design question

| Question | Source | Sections that matter |
|---|---|---|
| Q1, Q2, Q3, Q5 | `probes/mt-probe/main.swift`, `output.txt`, `output-run2.txt` | whole |
| Q1 | `MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSEvent.h` | comment block above `addGlobalMonitorForEventsMatchingMask:` |
| Q2 | `MacOSX.sdk/.../CoreGraphics.framework/Headers/CGEventSource.h` | `CGEventSourceButtonState` |
| Q3 | `MacOSX.sdk/.../AppKit.framework/Headers/NSHapticFeedback.h` | lines 29–36 |
| Q4 | `probes/kvo-probe/main.swift`, `output.txt`; `defaults read` of both trackpad domains (recorded in this index) | whole |
| Q5 | `MacOSX.sdk/.../AppKit.framework/Headers/NSWorkspace.h` | line 323 `NSWorkspaceDidWakeNotification` |
| Q6 | `probes/activate-probe/{target,driver}.swift`, `run.sh`, `output.txt` | whole; `NSWorkspace.h` lines 46, 164, 175 |
| Q7 | `NSWorkspace.h` | lines 114, 117 |
| Q8 | Xcode 26 SDK `AppKit/NSGlassEffectView.h`; `SwiftUICore.swiftmodule/arm64e-apple-macos.swiftinterface` 2529/5753/9045; `SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` 4629; `probes/svg-probe`; `docs/menubar-window.png`; `assets/*.svg` | as cited |
| Q9 | Xcode 26 SDK `ServiceManagement/SMAppService.h` | lines 36–91 |
| Q10 | `probes/swift-testing-probe`; `xcrun`/`xcode-select` output recorded above | whole |
| Requirements | `plans/001-trackpad-launcher-app/plan.md` | R1–R23, Non-goals |
| Vocabulary | `docs/domain-model.md` | whole |

## What a test can produce for real, what needs a fake, what is manual

**Real, in-process, no hardware:**
- Gesture recognition from synthetic frames: the recognizer is a pure function of (frame, button state, hand mode, clock) → events. Every R11 scenario can be scripted as a frame sequence (thumb-first, fingers-first, staggered landing, thumb lifts early, drag, five fingers, click during tap, corner geometry at 1 cm / 4 cm using the probed 124.8 mm width).
- Active/inactive derivation from (connected trackpad kinds, preference values) → status + notice contents: pure; every R14/R15 scenario is a table row.
- Assignment resolution from (stored identity, candidate URLs, trash predicate) → found/not found: pure, with a temporary directory holding fake `.app` bundles (a directory with `Contents/Info.plist` is a bundle to `Bundle(url:)`).
- Picker listing: enumerate a temporary directory tree with fake bundles, subfolders and non-app files; check order, Finder entry, refresh on reopen.
- Settings persistence: `UserDefaults(suiteName:)` with a throwaway suite, removed after.
- No-logging rule: source scan.
- Preferences change detection: the KVO probe pattern (write via `defaults` to a throwaway key in a throwaway domain).

**Fake at the seam:**
- The multitouch source (device list, start/stop, frame delivery) and the actuator: an in-memory adapter that the tests drive. The real adapter is exercised manually.
- The launcher (bring to front): record calls; the real one was probed and is checked manually in E2E.
- The clock: injected, so tap timeouts never wait.

**Manual only (E2E on hardware):** actual frames from the trackpad (Q1 verification), haptic strength, Magic Trackpad hot-plug and per-device haptic, sleep/wake, System Settings toggles, Space switching, full-screen apps, the Liquid Glass look in both appearances, Login Items UI, Gatekeeper on a fresh Mac, Activity Monitor idle reading, Console/network silence.

## Open questions

1. Frame layout, state values, coordinate origin and callback thread (Q1) are sourced, not probed: verify with one real touch in the first slice.
2. Preference value semantics for *Look up* (`TrackpadThreeFingerTapGesture`: 2 = tap with three fingers) and the Smart zoom key are sourced from community documentation; verify by toggling System Settings once, and keep them in one table.
3. Which preference domain a USB-wired Magic Trackpad reads (Q4).
4. Whether `urlsForApplications(withBundleIdentifier:)` includes trashed copies (Q7); the design filters Trash paths either way.
5. Build system: the human has both Xcode 26 and `xcodegen`; `xcode-select` points at the CLT. The design assumes the Xcode 26 toolchain (via `DEVELOPER_DIR` or `xcode-select -s`) because Liquid Glass and the macOS 26 deployment target require its SDK.
6. No Developer ID certificate on this machine (Q9/Q10): R23's signing and notarization need one before the final slice can be verified.
7. Haptic actuation ID (3/4/6/15/16) is a feel choice.
