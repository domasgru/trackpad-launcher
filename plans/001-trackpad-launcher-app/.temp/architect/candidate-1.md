## Design

### Problem

Trackpad Launcher binds four gestures to *bring to front* and configures them from a menu bar window. What makes the design hard is that its inputs come from four unrelated places, and the whole app must cost nothing while idle.

- **Raw touches** come only from the private MultitouchSupport framework. The probe showed that `dlopen` works with no permission prompt, and that the framework is silent while nothing touches the trackpad. Touches arrive through a context-free C callback on a framework-owned thread, at roughly 100 Hz while touching. Each is a 96-byte `MTTouch`. Its layout, state numbers and bottom-left origin come from community sources and have not been probed yet.
- **Whether gestures may run** depends on three things:
  - Another process's preferences: two cfprefs domains, one for the built-in trackpad and one for external trackpads. Changes are pushed to us by KVO on the main thread (probed).
  - Which trackpads are attached. That comes from IOKit first-match and terminated notifications; MultitouchSupport has no hot-plug callback.
  - Sleep and wake: devices stop delivering frames after wake.
- **Feedback** must hit the trackpad that was tapped. Only the per-device `MTActuator` can do that; `NSHapticFeedbackManager` cannot target a device.
- **A click must be told from a tap** without an event tap. The design samples `CGEventSource.buttonState` instead.
- **Bring to front** is one probed call: `openApplication(at:configuration:)` with `activates`. It reproduces a Dock click, and two calls in a row still give one app instance.
- **The window.** `MenuBarExtra` cannot be opened or closed programmatically, so the launcher window is an `NSStatusItem` plus an `NSPanel` hosting SwiftUI on Liquid Glass.

Hard constraints: no permissions, no network, no logging, no timers or polling (R20–R22); Swift 6 strict concurrency on Xcode 26 (SDK 26.5); a macOS 26 universal binary signed with Developer ID (this machine has no Developer ID certificate yet).

### Usage (caller's view)

**README excerpt.** One `@MainActor` model, `Launcher`, owns every decision. The rest of the app either feeds it signals or renders it.
- Adapters sense and act. They tell the model "a gesture fired" or "the trackpads may have changed", and they carry out its commands: run devices, play feedback, bring an app to front.
- The menu bar shell renders `launcher.activity` (icon, notice) and `launcher.isWindowOpen` (the panel).
- The window renders `launcher.rows`, `launcher.handMode` and `launcher.installedApps`, and calls `setAssignment` and `setHandMode`.

Tests build the same model on in-memory adapters, a temp directory of fake `.app` bundles and a throwaway `UserDefaults` suite. They script touches as frames.

```swift
// App target: the whole composition root.
@main @MainActor
enum TrackpadLauncherApp {
    static func main() {
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            system: WorkspaceActions(),
            catalog: .system,
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher)   // status item first: a first-launch window needs its anchor
        Task { await launcher.start() }                 // reconcile, then first-launch login item + window
        withExtendedLifetime(shell) { NSApplication.shared.run() }
    }
}
```

```swift
// LauncherCoreTests — the high seam: R11 + R12 + R13 + R3 in one scenario, driven by frames.
@MainActor @Test func thumbFirstThenTwoFingerTapBringsFigmaToFront() async throws {
    let world = try World(apps: ["Figma"])              // fake bundles + in-memory adapters + throwaway suite
    await world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
    await world.launcher.openWindow()

    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2).frames, on: .builtIn)

    #expect(world.system.broughtToFront == [world.app("Figma")])
    #expect(world.hardware.feedback == [.builtIn])
    #expect(world.launcher.isWindowOpen == false)
}

// R14: the external trackpad's setting silences gestures on the built-in one too.
@MainActor @Test func tapToClickOnExternalOnlyMakesGesturesInactive() async throws {
    let world = try World(apps: ["Arc"]); await world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
    world.hardware.attach(.magicTrackpad)
    world.preferences.set(.tapToClick, on: true, for: .external)

    #expect(world.launcher.activity == .inactive(.settings(ConflictingSettings([.tapToClick])!)))
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).frames, on: .builtIn)
    #expect(world.system.broughtToFront.isEmpty && world.hardware.feedback.isEmpty)
}
```

```swift
// The recognizer's own seam: every R11 scenario as a frame script, pure and synchronous.
@Test(arguments: [(thumbXMM: 10.0, fires: true), (thumbXMM: 40.0, fires: false)])  // 1 cm in, 4 cm out on 124.8 mm
func anchorCornerGeometry(thumbXMM: Double, fires: Bool) {
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let fired = recognizer.run(TouchScript(.macBook14).thumb(atMM: (thumbXMM, 10)).tap(fingers: 1).frames)
    #expect(fired == (fires ? [.one] : []))
}
```

```swift
// LauncherUI: a gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow; let launcher: Launcher; let actions: LauncherActions
    var body: some View {
        HStack {
            GestureIllustration(row.gesture, handMode: launcher.handMode)   // mirrored in left-hand mode (R10)
            Spacer()
            AppPicker(row.app, apps: launcher.installedApps,
                      choose: { launcher.setAssignment($0, for: row.gesture) },   // .app(entry) or .unassigned
                      chooseOther: { actions.chooseOtherApp(row.gesture) })       // NSOpenPanel lives in the shell
        }
    }
}
```

### Shape

**Data first.** All domain values are `Sendable` structs and enums in `LauncherCore`.

- **What the recognizer reads.** A `TouchFrame` holds a `FrameTime`, the touches that are down now, and `buttonDown`. Each `Touch` has a `TouchID` and a `SurfacePoint`, normalised with the origin at the top-left. A `Trackpad` has a `TrackpadID`, a `TrackpadKind` (`.builtIn` or `.external`) and a `SurfaceSize` in mm.
- **What fires.** `Gesture` has four cases, `.one` to `.four`. Its init from a finger count is failable: five fingers produce no value. A `GestureEvent` is a gesture plus the trackpad it fired on.
- **What the user stores.** `HandMode` is `.right` or `.left`; `AnchorCorner` is derived from it. `Settings` holds the hand mode and `assignments: [Gesture: AssignedApp]`, where unassigned means absent. `AssignedApp` is a bundle ID (the identity), a display name and a last-known URL used only as a fast path.
- **What the window shows.**
  - *Missing* is never stored. It is derived when `AppCatalog.locate` returns nil, and each `GestureRow` shows `.unassigned`, `.present(AppEntry)` or `.missing(name:)`.
  - Gesture activity is `GestureActivity`: either `.active` or `.inactive(InactiveCause)`, where the cause is `.noTrackpad` or `.settings(ConflictingSettings)`. `ConflictingSettings` is non-empty by construction, so "inactive for no reason" cannot be represented (per type-system-discipline).

**Load-bearing decisions**

1. **Recognition is a pure state machine that runs on the frame thread, one per trackpad.**
   - `GestureRecognizer.step(_:) -> Gesture?` holds three pieces of state: the anchor (touch ID and the time it was adopted), each finger's landing point, and the tap phase (`idle`, `counting(start, peak)` or `void`).
   - **Time is data.** Frames carry their own timestamps. The tap duration is checked against them at lift time, so no clock object or timer exists anywhere. The test handle for "the clock" is `TouchFrame.time`, and the button-state sampler's handle is `TouchFrame.buttonDown`.
   - All fixed numbers live in `GestureRules`.
   - Only fired gestures hop to the main actor (`Task { @MainActor }`). A touch costs one struct step on the framework thread, and the main thread wakes only for gestures (per foundational-thinking).
2. **Both hardware adapters drive the same recognizer.** The real `MultitouchTrackpads` steps it under a never-contended `Mutex` on the frame thread. `InMemoryTrackpads` steps it synchronously on the main actor. So every R11 scenario can run at the recognizer seam (exhaustive tables) and also through the full app at the `Launcher` seam, with no async waiting.
3. **One idempotent `reconcile()` handles launch, IOKit add/remove, wake, session switch, preference change and hand-mode change.** It re-reads the truth (`hardware.connected()`, `preferences.settingsOn()`), derives `activity`, and calls `hardware.run(active ? trackpads : [], handMode:)`.
   - `run` means "stop and forget everything, then start exactly these, each with a fresh recognizer". It converges from any prior state, including deaf devices after wake, with no staleness detection (per make-operations-idempotent).
   - **Inactive means the devices are stopped.** Nothing is recognised, and nothing costs CPU even while the user touches the trackpad.
4. **Activity is a pure derivation over one table.**
   - `TrackpadSetting.conflicting` holds, for each setting: its title (the notice text), its preference key and the raw values that mean "on". It currently lists *Tap to click* and *Look up: Tap with three fingers*. Adding Smart zoom is one row.
   - `GestureActivity(connected: Set<TrackpadKind>, settingsOn: [TrackpadKind: Set<TrackpadSetting>])` joins each connected kind to its domain. "No trackpad" takes precedence over settings, and causes are listed in table order.
   - The status icon, the trackpad settings notice and the fire guard all read the same `launcher.activity` (single source of truth).
   - Preference keys are `package` access: visible to the preferences adapter, invisible to the app target.
5. **The fire path decides every silent case in one function.** `Launcher.fire` checks, in order: inactive, then unassigned, then missing. If all pass, it plays feedback on `event.trackpad`, calls `bringToFront`, and closes the window.
   - Stopping the devices while inactive saves cost.
   - The guard in `fire` is what guarantees correctness: it catches a gesture already in flight when activity flips.
6. **Assignment identity is the bundle ID.**
   - `AppCatalog.locate` tries the last-known URL first, if it still holds that bundle ID outside any `.Trash`/`.Trashes`. Otherwise it asks LaunchServices for registered copies and drops those in the Trash. Nil means missing, so a reinstalled app recovers without re-picking.
   - The resolved URL is never written back: settings change only through user intent.
   - Disk state cannot be observed without idle cost, so rows are a snapshot. It is refreshed when the window opens and when an assignment changes; the fire path resolves fresh each time.
7. **First launch is derived, not flagged.** It is a first launch exactly when no settings record is stored. `start()` registers the login item before its first save, so a crash between the two re-registers on the next launch instead of losing the item. A user who disables the login item is never overridden (R17).
8. **Window visibility is model state (`isWindowOpen`).** R18 opens the window and R3 closes it from the core, so both are testable. The shell only maps AppKit signals to `openWindow()`/`closeWindow()` and renders the state.
9. **Rules are enforced by structure** (per encode-lessons-in-structure).
   - `LauncherCore` cannot import AppKit, IOKit or the private framework.
   - `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs, and fails on any hit.

**Depth**

| Module | Public surface | What it hides |
|---|---|---|
| `Launcher` | 5 read-only properties and 5 intents | Persistence, first-launch policy, the login item, device reconciliation across hot-plug, wake and session switches, activity derivation, fire policy, assignment resolution, refresh-on-show |
| `TrackpadHardware` | 4 members | `dlopen`, the MTTouch layout, the C-callback registry, the frame thread, IOKit, wake and session notifications, actuators, device classification |
| `GestureRecognizer` | init and `step` | All of R11 |
| `AppCatalog` | 3 methods | Enumeration, bundle parsing, de-duplication, sorting, Trash filtering, the LaunchServices fallback |
| `SystemActions` | 2 methods | Nothing much |

`SystemActions` is shallow on purpose. It is the recording seam for the two system effects the core decides on (bring to front and the login item), and it has two real adapters.

**Concurrency** (Swift 6, language mode 6)

- **Main actor.** `Launcher`, the three port protocols and the public surface of every real adapter are `@MainActor`, and `LauncherUI` uses `defaultIsolation(MainActor.self)`. `LauncherCore` and `LauncherSystem` stay nonisolated by default because the recognizer and the C callback must not be main-isolated.
- **Frame thread.** The C callback looks up the registry under a `Mutex` (written by `run` on main, read on the frame thread). It steps that device's recognizer, which only that device's callback ever touches; its `Mutex` exists to satisfy the compiler. For events only, it hops with `Task { @MainActor }`.
- **Other threads.**
  - IOKit notifications are delivered through a port on `DispatchQueue.main`.
  - Wake and session notifications are observed with `queue: .main`.
  - Preference KVO arrives on main (probed), but the adapter hops to main anyway with `Task { @MainActor }`.
  - `AppCatalog.installedApps()` is `@concurrent` and runs off the main actor.
- **Ownership.** No two actors write the same state.

**Build and test layout**

- **Local SwiftPM package `LauncherKit`.**
  - Library targets: `LauncherCore` (Foundation and Observation only), `LauncherSystem` (adapters) and `LauncherUI` (shell and views).
  - Test targets: `LauncherCoreTests` and `LauncherSystemTests`.
  - Tests run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`, using Swift Testing.
- **xcodegen-generated app target `TrackpadLauncher`.**
  - Contains the composition root and bundles the repo's `assets/*.svg` directly, so there is no copy.
  - Info.plist: `LSUIElement = YES`, `LSMinimumSystemVersion = 26.0`, no `NSSupportsAutomaticTermination`.
  - Hardened runtime, no sandbox, no entitlements. Release builds use `ARCHS_STANDARD` (arm64 and x86_64).
- **Why this layout.** `swift test` runs the core in seconds with no app host. xcodebuild owns what SwiftPM cannot do: the bundle, Info.plist, signing and archiving.
- **Release script.** `xcodebuild archive`, export with Developer ID, `notarytool submit --wait`, `stapler staple`. It is blocked until a Developer ID certificate exists; local builds are signed with Apple Development, which is enough for `SMAppService`.

**Requirement trace**

| R | Carried by | Verified at |
|---|---|---|
| R1 | App target `LSUIElement` | manual |
| R2 | `GestureActivity` → `MenuBarShell` icon (`StatusIcon`) | `Launcher` seam (`activity`); icon look manual |
| R3 | `isWindowOpen`; shell dismissal (resign key, mouse-down monitor while open, Escape, icon) | `Launcher` seam (gesture closes, first launch opens); rest manual |
| R4, R10 | `LauncherView` on `NSGlassEffectView`; SVGs as template images, mirrored for `.left`; hint text from hand mode | manual, light and dark |
| R5 | `AppCatalog.installedApps` / `entry(at:)`; `AppPicker`; Other… in the shell | catalog over a temp dir; panel manual |
| R6, R8 | `Settings` defaults; `SettingsStore` | `Launcher` seam over a throwaway suite (two models, same suite) |
| R7 | `AppCatalog.locate`; rows refreshed on open; fire guard | `Launcher` seam over a temp dir (move, trash, reinstall) |
| R9 | `HandMode` → `AnchorCorner` via `run(_:handMode:)` | recognizer and `Launcher` seams |
| R11 | `GestureRecognizer`, `GestureRules` | recognizer seam (every scenario) and `Launcher` seam |
| R12 | `SystemActions.bringToFront` → `openApplication` with `activates` | recording fake; real call probed, Spaces and full-screen manual |
| R13 | `Launcher.fire` → `playFeedback(on: event.trackpad)` | `Launcher` seam (`feedback`) |
| R14, R15 | `TrackpadSetting` table, `GestureActivity`, `reconcile`, `TrackpadSettingsNotice` | pure table tests and `Launcher` seam |
| R16 | `MultitouchTrackpads` (IOKit, wake, session) → `reconcile` | `Launcher` seam via `attach`/`detach`/`wake`; hardware manual |
| R17, R18 | `Launcher.start` (first launch ⇔ nothing stored); `registerLoginItem` | `Launcher` seam |
| R19 | Shell Quit → `NSApp.terminate` | manual |
| R20–R22 | Module boundaries, push-only adapters, `run([])` when inactive, `SourcePolicyTests` | source scan; Console, network monitor and Activity Monitor manual |
| R23 | App target settings and release script | manual; blocked on Developer ID |

**Deliberately not done**

- No FSEvents and no polling of app folders.
- No write-back of resolved URLs.
- No `NSHapticFeedbackManager`.
- No key-event monitors. The only global monitor is mouse-down, and it exists only while the window is open.
- No framework type crosses a port: `MTTouch`, `CFTypeRef`, `UserDefaults`, `NSRunningApplication` and `NSImage` stay inside adapters and views.

#### Module map

```
LauncherCore    (Foundation, Observation)        domain types · GestureRules · GestureRecognizer · TrackpadSetting table ·
                                                  GestureActivity · AppCatalog · Settings/SettingsStore · ports · Launcher
LauncherSystem  (AppKit, IOKit, CoreGraphics,     MultitouchTrackpads (MT dlopen, MTTouch parse, C callback, IOKit, wake,
                 ServiceManagement, Synchronization)  session, actuators) · SystemTrackpadPreferences (KVO) ·
                                                  WorkspaceActions · AppCatalog.system
LauncherUI      (AppKit, SwiftUI; MainActor)     MenuBarShell · LauncherPanel · StatusIcon · LauncherView · GestureRowView ·
                                                  AppPicker · HandModeToggle · HintText · TrackpadSettingsNotice
TrackpadLauncher app target (xcodegen)           composition root · Info.plist · assets/*.svg
Tests                                            LauncherCoreTests (recognizer, activity table, catalog, store, Launcher seam,
                                                  SourcePolicyTests) · LauncherSystemTests (prefs KVO with throwaway domains,
                                                  MTTouch stride == 96, trackpad classification table)
```

#### LauncherCore: gesture domain and recognizer

```swift
import Foundation

/// Which hand holds the anchored thumb (R9). One global setting; default `.right`.
public enum HandMode: String, Codable, Sendable, CaseIterable {
    case right   // anchor corner top-left
    case left    // anchor corner top-right
}

/// Every fixed number in gesture recognition, in one place (R11; not user-tunable per Non-goals).
package enum GestureRules {
    static let cornerWidth = 0.20                            // fraction of width, from the anchor-side edge
    static let cornerHeight = 0.25                           // fraction of height, from the top edge
    static let anchorReleaseMarginMM = 2.0                   // an anchored thumb may roll this far past the zone edge
    static let maxTapDuration = Duration.milliseconds(300)   // first finger down → last finger up
    static let dragThresholdMM = 3.0                         // a finger farther than this from its landing point is dragging
}

/// Normalised position: x 0 = left edge … 1 = right edge; y 0 = TOP edge … 1 = bottom edge.
/// The MT adapter flips MultitouchSupport's bottom-left origin; nothing else knows about it.
public struct SurfacePoint: Hashable, Sendable { public var x: Double; public var y: Double }

/// Physical surface size from MTDeviceGetSensorSurfaceDimensions (probed: 124.8 × 76.8 mm, 14" MacBook Pro).
public struct SurfaceSize: Hashable, Sendable { public var widthMM: Double; public var heightMM: Double }

/// The fixed zone where a thumb arms gestures (R11).
package struct AnchorCorner: Sendable {
    package init(_ handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }
    /// A contact *landing* here, while no thumb is anchored, becomes the anchored thumb.
    /// fromEdge = right hand ? p.x : 1 - p.x;  fromEdge < cornerWidth && p.y < cornerHeight
    package func admits(_ p: SurfacePoint) -> Bool { fatalError("not implemented") }
    /// An anchored thumb stays anchored while inside the zone grown by `anchorReleaseMarginMM`.
    package func holds(_ p: SurfacePoint) -> Bool { fatalError("not implemented") }
}

public struct TouchID: Hashable, Sendable { public let rawValue: Int32 }

/// A contact that is DOWN in this frame. Hovering, lingering and lifted contacts are dropped by the adapter,
/// so "landed" = first frame an id appears and "lifted" = first frame it is absent.
public struct Touch: Sendable { public let id: TouchID; public let position: SurfacePoint }

/// Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads.
public struct FrameTime: Comparable, Sendable {
    public var seconds: Double
    public static func - (lhs: FrameTime, rhs: FrameTime) -> Duration { .seconds(lhs.seconds - rhs.seconds) }
    public static func < (lhs: FrameTime, rhs: FrameTime) -> Bool { lhs.seconds < rhs.seconds }
}

/// Everything the recognizer needs about one instant on one trackpad.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]   // [] is the frame after the last lift
    public let buttonDown: Bool   // any mouse button pressed, sampled when the frame arrived (click ≠ tap)
}

/// One of the four launcher gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable, Comparable {
    case one = 1, two, three, four
    /// nil outside 1...4: a five-finger tap is not a gesture (R11).
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
    public static func < (a: Gesture, b: Gesture) -> Bool { a.rawValue < b.rawValue }
}

/// A gesture that fired on a specific trackpad (feedback plays on that one, R13).
public struct GestureEvent: Equatable, Sendable { public let gesture: Gesture; public let trackpad: TrackpadID }

/// R11 for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }

    /// The gesture that fired on this frame, if any. At most once per tap, on the frame where the last finger lifts.
    public mutating func step(_ frame: TouchFrame) -> Gesture? {
        // TODO
        // 1. Anchor: keep it only if its id is present and corner.holds(position); else anchor = nil.
        //    (A thumb that slides out is from then on just a finger: it is not re-adopted.)
        // 2. Landings, for each touch not seen before (not the anchor, not in `fingers`):
        //      anchor == nil && corner.admits(position) → anchor = Anchor(id, since: frame.time)
        //      otherwise                                → fingers[id] = position   (landing point)
        //    Drop fingers whose id is absent (lifted).
        // 3. Phase:
        //      .idle, fingers non-empty:
        //          anchor?.since < frame.time && !frame.buttonDown → .counting(start: frame.time, peak: fingers.count)
        //          else                                           → .void   (fingers before thumb / same frame / click)
        //      .counting(start, peak):
        //          anchor == nil || buttonDown || frame.time - start > maxTapDuration
        //            || some finger is > dragThresholdMM (via surface) from its landing point → .void
        //          else peak = max(peak, fingers.count)
        //    If fingers is now empty: fired = phase is .counting(_, peak) ? Gesture(fingerCount: peak) : nil;
        //    phase = .idle. (Thumb and last finger lifting in one frame: anchor already nil → void → no fire.)
        fatalError("not implemented")
    }

    private struct Anchor: Sendable { let id: TouchID; let since: FrameTime }
    private enum Phase: Sendable { case idle, counting(start: FrameTime, peak: Int), void }
    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var anchor: Anchor?
    private var fingers: [TouchID: SurfacePoint] = [:]   // non-anchor contacts → where they landed
    private var phase: Phase = .idle
}
```

#### LauncherCore: trackpads, settings table, activity

```swift
/// MultitouchSupport device ID (== IORegistry "Multitouch ID", probed).
public struct TrackpadID: Hashable, Sendable { public let rawValue: UInt64 }

/// macOS keeps trackpad settings per kind: one domain for the built-in, one shared by all external trackpads (R14).
public enum TrackpadKind: Hashable, Sendable, CaseIterable { case builtIn, external }

public struct Trackpad: Hashable, Sendable, Identifiable {
    public let id: TrackpadID
    public let kind: TrackpadKind
    public let surface: SurfaceSize
}

/// A system trackpad setting that binds an action to a tap, so gestures cannot coexist with it (R14).
/// THE table. Derivation, notice text and the preferences adapter all read it; adding Smart zoom is one row.
public struct TrackpadSetting: Hashable, Sendable {
    public let title: String            // as named in the trackpad settings notice (R15)
    package let preferenceKey: String   // read only by the preferences adapter
    package let onValues: Set<Int>      // raw values meaning "bound to a tap"; an absent key reads as off

    public static let tapToClick = TrackpadSetting(
        title: "Tap to click", preferenceKey: "Clicking", onValues: [1])
    public static let lookUpTapWithThreeFingers = TrackpadSetting(
        title: "Look up: Tap with three fingers", preferenceKey: "TrackpadThreeFingerTapGesture", onValues: [2])
    // R14, conditional on testing:
    // public static let smartZoom = TrackpadSetting(
    //     title: "Smart zoom", preferenceKey: "TrackpadTwoFingerDoubleTapGesture", onValues: [1])

    /// Notice order.
    public static let conflicting: [TrackpadSetting] = [.tapToClick, .lookUpTapWithThreeFingers]
}

/// Non-empty, in table order. The failable init is the only constructor.
public struct ConflictingSettings: Equatable, Sendable {
    public let settings: [TrackpadSetting]
    public init?(_ settings: [TrackpadSetting]) { fatalError("not implemented") }   // nil when empty
}

public enum InactiveCause: Equatable, Sendable {
    case noTrackpad
    case settings(ConflictingSettings)
}

/// Gestures active / inactive (R2, R14, R15). One value read by the icon, the notice and the fire guard.
public enum GestureActivity: Equatable, Sendable {
    case active
    case inactive(InactiveCause)

    public var isActive: Bool { self == .active }

    /// Pure. No trackpad wins over settings; settings are unioned over the CONNECTED kinds only.
    public init(connected: Set<TrackpadKind>, settingsOn: [TrackpadKind: Set<TrackpadSetting>]) {
        // guard !connected.isEmpty else { self = .inactive(.noTrackpad) }
        // let on = union of settingsOn[kind] for kind in connected
        // self = ConflictingSettings(TrackpadSetting.conflicting.filter(on.contains)).map { .inactive(.settings($0)) } ?? .active
        fatalError("not implemented")
    }
}
```

#### LauncherCore: apps, assignments, persistence

```swift
public struct BundleID: Hashable, Codable, Sendable { public let rawValue: String }

/// An app bundle on disk right now.
public struct AppEntry: Hashable, Sendable, Identifiable {
    public let bundleID: BundleID
    public let name: String   // FileManager display name, without ".app"
    public let url: URL
    public var id: BundleID { bundleID }
}

/// What a gesture points at (R7): identity, plus what is needed to show it while missing and to find it fast.
public struct AssignedApp: Codable, Hashable, Sendable {
    public let bundleID: BundleID   // identity
    public let name: String         // shown greyed with "not found"
    public let lastKnownURL: URL    // fast path only; never authoritative, never rewritten
    public init(_ entry: AppEntry) { fatalError("not implemented") }
}

/// The app picker's three kinds of item (R5).
public enum AppChoice: Sendable {
    case app(AppEntry)        // from the installed list
    case appBundle(at: URL)   // from Other…; parsed by AppCatalog.entry(at:), ignored if not an app with a bundle ID
    case unassigned           // None
}

public enum RowApp: Equatable, Sendable { case unassigned, present(AppEntry), missing(name: String) }

/// A gesture row as the launcher window shows it (R5–R7).
public struct GestureRow: Identifiable, Equatable, Sendable {
    public let gesture: Gesture
    public let app: RowApp
    public var id: Gesture { gesture }
}

/// Apps on disk (R5, R7). Local-substitutable: tests point it at a temp directory of fake bundles
/// (a folder with Contents/Info.plist is a bundle to `Bundle(url:)`) and inject `registeredCopies`.
public struct AppCatalog: Sendable {
    public init(roots: [URL], extras: [URL], registeredCopies: @escaping @Sendable (BundleID) -> [URL]) {
        fatalError("not implemented")
    }

    /// Picker list: every .app under `roots` (recursing into folders, never into bundles, skipping hidden files)
    /// plus `extras` (Finder). One entry per bundle ID (first root wins), sorted by localizedStandardCompare.
    /// Bundles without an identifier are skipped (they cannot be assigned by identity).
    @concurrent public func installedApps() async -> [AppEntry] { fatalError("not implemented") }

    /// Boundary parse for Other…: the app bundle at `url`, if it has a bundle identifier.
    public func entry(at url: URL) -> AppEntry? { fatalError("not implemented") }

    /// Where the assigned app lives now; nil = missing.
    /// 1. lastKnownURL, if it is outside the Trash and still holds that bundle ID (also covers ~/Downloads picks).
    /// 2. else the first of registeredCopies(bundleID) outside the Trash that still holds that bundle ID.
    public func locate(_ app: AssignedApp) -> AppEntry? { fatalError("not implemented") }

    /// Any path component named ".Trash" or ".Trashes".
    static func isInTrash(_ url: URL) -> Bool { fatalError("not implemented") }
}

/// Everything persisted besides the implicit "launched before" (R8, R21).
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right                  // R9 default
    public var assignments: [Gesture: AssignedApp] = [:]    // absent = unassigned (R6 fresh install)
}

/// One plist-encoded record under one key. Local-substitutable: tests use UserDefaults(suiteName: "test-<uuid>").
@MainActor public struct SettingsStore {
    public init(defaults: UserDefaults, key: String = "settings") { fatalError("not implemented") }
    /// nil ⇔ nothing was ever saved ⇔ first launch (R18). Undecodable data loads as `Settings()`, NOT as a first launch.
    public func load() -> Settings? { fatalError("not implemented") }
    public func save(_ settings: Settings) { fatalError("not implemented") }
}
```

#### LauncherCore: ports

```swift
public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case trackpadsChanged   // attached, detached, woke, or our login session moved on/off the console
}

/// The multitouch hardware. Real: MultitouchTrackpads. Test: InMemoryTrackpads.
@MainActor public protocol TrackpadHardware: AnyObject {
    /// Always called on the main actor.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    /// Trackpads usable by this login session now. Excludes non-trackpad multitouch devices; [] while not on console.
    func connected() -> [Trackpad]
    /// Stops and forgets every running device, then starts exactly `trackpads`, each with a fresh
    /// GestureRecognizer for `handMode`. Idempotent. [] = nothing runs (zero cost).
    func run(_ trackpads: [Trackpad], handMode: HandMode)
    /// One haptic pulse on that trackpad (feedback, R13). No-op if it is gone.
    func playFeedback(on trackpad: TrackpadID)
}

/// The two trackpad preference domains. Real: SystemTrackpadPreferences. Test: InMemoryTrackpadPreferences.
@MainActor public protocol TrackpadPreferences: AnyObject {
    /// Called on the main actor after any `TrackpadSetting.conflicting` key changes in either domain.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Which table settings are on, per kind. Reads only; never writes a system domain.
    func settingsOn() -> [TrackpadKind: Set<TrackpadSetting>]
}

/// Effects the core decides and macOS performs. Real: WorkspaceActions. Test: RecordingSystemActions.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click (R12).
    func bringToFront(_ app: AppEntry)
    /// Open at Login (R17). Called only on first launch.
    func registerLoginItem()
}
```

#### LauncherCore: the Launcher (the high seam)

```swift
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
@MainActor @Observable
public final class Launcher {
    public private(set) var activity: GestureActivity = .inactive(.noTrackpad)
    public private(set) var rows: [GestureRow] = []
    public private(set) var installedApps: [AppEntry] = []
    public private(set) var isWindowOpen = false
    public var handMode: HandMode { settings.handMode }

    private var settings: Settings
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let store: SettingsStore

    public init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, system: any SystemActions,
                catalog: AppCatalog, store: SettingsStore) {
        // let stored = store.load(); isFirstLaunch = stored == nil; settings = stored ?? Settings(); rows = makeRows()
        fatalError("not implemented")
    }

    /// Launch. Call once, after the status item exists (R16–R18).
    public func start() async {
        hardware.onEvent = { [unowned self] event in
            switch event {
            case .gesture(let fired): fire(fired)
            case .trackpadsChanged: reconcile()
            }
        }
        preferences.onChange = { [unowned self] in reconcile() }
        reconcile()
        guard isFirstLaunch else { return }
        system.registerLoginItem()   // before the first save: a crash in between re-registers, never loses it
        store.save(settings)         // from now on, not a first launch
        await openWindow()
    }

    /// App picker (R5–R7). Same app on two gestures is fine (R5).
    public func setAssignment(_ choice: AppChoice, for gesture: Gesture) {
        // .app(e) → settings.assignments[gesture] = AssignedApp(e)
        // .appBundle(url) → guard let e = catalog.entry(at: url) else { return }; same
        // .unassigned → settings.assignments[gesture] = nil
        // store.save(settings); rows = makeRows()
        fatalError("not implemented")
    }

    /// Hand mode toggle (R9). Moves the anchor corner by re-running the devices with fresh recognizers.
    public func setHandMode(_ mode: HandMode) {
        // guard mode != settings.handMode; settings.handMode = mode; store.save(settings); reconcile()
        fatalError("not implemented")
    }

    /// Show the launcher window and refresh what comes from disk (R5 new apps, R7 missing/recovered).
    /// Returns once the installed-apps list is fresh: the test handle for the one call that can take a while.
    public func openWindow() async {
        isWindowOpen = true
        rows = makeRows()
        installedApps = await catalog.installedApps()
    }

    public func closeWindow() { isWindowOpen = false }

    /// The one convergent operation behind launch, hot-plug, wake, session switch, preference and hand-mode changes.
    private func reconcile() {
        let trackpads = hardware.connected()
        activity = GestureActivity(connected: Set(trackpads.map(\.kind)), settingsOn: preferences.settingsOn())
        hardware.run(activity.isActive ? trackpads : [], handMode: settings.handMode)
    }

    /// Every silent case of R13 decided here and only here: inactive, unassigned, missing.
    private func fire(_ event: GestureEvent) {
        guard activity.isActive,
              let assigned = settings.assignments[event.gesture],
              let app = catalog.locate(assigned)
        else { return }
        hardware.playFeedback(on: event.trackpad)
        system.bringToFront(app)
        isWindowOpen = false   // R3: the window closes as the target app comes to the front
    }

    private func makeRows() -> [GestureRow] {
        // Gesture.allCases.map { g in
        //   settings.assignments[g].map { a in catalog.locate(a).map(RowApp.present) ?? .missing(name: a.name) } ?? .unassigned }
        fatalError("not implemented")
    }
}
```

#### LauncherSystem: real adapters

```swift
import AppKit
import IOKit
import ServiceManagement
import Synchronization

/// TrackpadHardware over MultitouchSupport (dlopen), IOKit and NSWorkspace notifications.
/// Threads: frames arrive on MultitouchSupport's thread and are recognised THERE; only gestures hop to main.
/// IOKit matched/terminated: notification port on DispatchQueue.main. Wake and session: observers on `.main`.
@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    public var onEvent: (@MainActor (TrackpadEvent) -> Void)?

    /// dlopen + dlsym once (the probed symbol set). On failure: connected() == [] → "No trackpad connected".
    /// Registers IOServiceAddMatchingNotification(first-match + terminated, "AppleMultitouchDevice"),
    /// NSWorkspace didWake, sessionDidBecomeActive / sessionDidResignActive → onEvent(.trackpadsChanged).
    public init() { fatalError("not implemented") }

    /// MTDeviceCreateList → classify each → [Trackpad]. [] while our session is off the console
    /// (fast user switching must not recognise another user's touches or pulse their trackpad).
    public func connected() -> [Trackpad] { fatalError("not implemented") }

    public func run(_ trackpads: [Trackpad], handMode: HandMode) {
        // TODO
        // 1. For every device we started: MTUnregisterContactFrameCallback, MTDeviceStop, MTActuatorClose, MTDeviceRelease.
        // 2. sessions.withLock { $0 = [:] }   — in-flight frames from old refs now find nothing and are dropped
        // 3. Re-list; for each device whose ID is in `trackpads`:
        //      sessions[ref] = DeviceSession(trackpad, GestureRecognizer(handMode, surface), deliver: hop to main)
        //      MTRegisterContactFrameCallback(ref, contactFrameCallback); MTDeviceStart(ref, 0)
        //      open its actuator (MTActuatorCreateFromDeviceID + MTActuatorOpen) for low-latency feedback
        // Postcondition: frames flow from exactly `trackpads`, each into a fresh recognizer.
        fatalError("not implemented")
    }

    /// MTActuatorActuate(actuator, Self.feedbackActuation, 0, 0, 0). Strength is a feel choice (3/4/6).
    public func playFeedback(on trackpad: TrackpadID) { fatalError("not implemented") }
    static let feedbackActuation: Int32 = 6
}

/// The only shared state on the frame path: written by `run` (main), read by the callback (frame thread).
private let sessions = Mutex<[UInt: DeviceSession]>([:])   // key: MTDeviceRef bit pattern

/// One running trackpad. Its recognizer is stepped only by that device's frame callbacks;
/// the Mutex is the compiler's proof and is never contended.
private final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    let recognizer: Mutex<GestureRecognizer>
    let deliver: @Sendable (GestureEvent) -> Void   // { e in Task { @MainActor [weak owner] in owner?.onEvent?(.gesture(e)) } }
    init(trackpad: TrackpadID, recognizer: GestureRecognizer, deliver: @escaping @Sendable (GestureEvent) -> Void) {
        fatalError("not implemented")
    }
}

/// `int cb(MTDeviceRef, MTTouch*, int count, double timestamp, int frame)`; context-free, hence the global registry.
private let contactFrameCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32 = {
    device, touches, count, timestamp, _ in
    // guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    // let frame = TouchFrame(parsing: touches, count: count, timestamp: timestamp, buttonDown: anyMouseButtonDown())
    // if let g = session.recognizer.withLock({ $0.step(frame) }) { session.deliver(GestureEvent(gesture: g, trackpad: session.trackpad)) }
    return 0
}

/// The 96-byte MTTouch mirror (stride checked by a test). Only this file knows its layout.
struct MTTouchMirror { /* frame, timestamp, identifier, state, fingerID, handID, normalized(pos, vel), zTotal, … */ }

extension TouchFrame {
    /// MTTouch[] → TouchFrame. Keeps states 3 (MakeTouch) and 4 (Touching) only; flips y (origin bottom-left → top-left).
    /// A layout correction after the first real-touch check is a change here and nowhere else.
    init(parsing touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double, buttonDown: Bool) {
        fatalError("not implemented")
    }
}

/// Magic Mouse and Touch Bar digitizers are multitouch devices but not trackpads. One table, one place.
func trackpadKind(isBuiltIn: Bool, familyID: Int32) -> TrackpadKind? { fatalError("not implemented") }

/// CGEventSource.buttonState(.combinedSessionState, …) for .left, .right, .center: a state query, no tap, no TCC.
func anyMouseButtonDown() -> Bool { fatalError("not implemented") }

/// TrackpadPreferences over the two cfprefs domains (probed: KVO fires when another process writes).
@MainActor public final class SystemTrackpadPreferences: TrackpadPreferences {
    public static let systemDomains: [TrackpadKind: String] = [
        .builtIn: "com.apple.AppleMultitouchTrackpad",
        .external: "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]
    public var onChange: (@MainActor () -> Void)?
    /// KVO (addObserver forKeyPath:) on every `TrackpadSetting.conflicting` key in each suite;
    /// the nonisolated observeValue hops with Task { @MainActor }. Injectable domains for its own test.
    public init(domains: [TrackpadKind: String] = systemDomains) { fatalError("not implemented") }
    public func settingsOn() -> [TrackpadKind: Set<TrackpadSetting>] { fatalError("not implemented") }
}

@MainActor public final class WorkspaceActions: SystemActions {
    public init() {}
    /// NSWorkspace.openApplication(at: app.url, configuration: activates = true); completion ignored (no logging).
    public func bringToFront(_ app: AppEntry) { fatalError("not implemented") }
    /// try? SMAppService.mainApp.register()
    public func registerLoginItem() { fatalError("not implemented") }
}

extension AppCatalog {
    /// roots: /Applications, /System/Applications, ~/Applications · extras: /System/Library/CoreServices/Finder.app ·
    /// registeredCopies: NSWorkspace.shared.urlsForApplications(withBundleIdentifier:)
    public static var system: AppCatalog { fatalError("not implemented") }
}
```

#### LauncherUI: menu bar shell and launcher window

```swift
import AppKit
import SwiftUI

/// The thin AppKit shell (R1–R3, R15 button, R19). Maps AppKit signals to Launcher intents; renders Launcher state.
public final class MenuBarShell {
    public init(launcher: Launcher) {
        // statusItem = NSStatusBar.system.statusItem(withLength: .squareLength); button image StatusIcon.image(active:)
        // panel = LauncherPanel(content: LauncherView(launcher, actions: LauncherActions(…)))
        // Task { for await active in Observations({ launcher.activity.isActive }) { button.image = StatusIcon.image(active:) } }
        // Task { for await open in Observations({ launcher.isWindowOpen }) { open ? showBelowIcon() : hide() } }
        //
        // Dismissal (R3):
        //   icon click        → launcher.isWindowOpen ? launcher.closeWindow() : Task { await launcher.openWindow() }
        //   panel resigns key → launcher.closeWindow()
        //   mouse-down elsewhere → global monitor [.leftMouseDown, .rightMouseDown, .otherMouseDown], installed on
        //                     show and removed on hide (no idle cost; mouse-only monitors need no permission)
        //   Escape            → LauncherPanel.cancelOperation → launcher.closeWindow()
        //   gesture           → Launcher sets isWindowOpen = false → hide()
        // Other… (R5): closeWindow(); NSApp.activate(); NSOpenPanel(allowedContentTypes: [.application],
        //   canChooseDirectories: false).begin { url → setAssignment(.appBundle(at:)) }; then openWindow().
        // Notice button (R15): NSWorkspace.open("x-apple.systempreferences:com.apple.preference.trackpad").
        // Quit (R19): NSApp.terminate(nil); the login item is untouched.
        fatalError("not implemented")
    }
}

/// Borderless, non-activating, key-capable; status-bar level; joins all Spaces and full-screen apps.
/// contentView = NSGlassEffectView whose contentView = NSHostingView(LauncherView).
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { fatalError("not implemented") }   // Escape
}

/// Template images for light and dark menu bars (R2). Inactive = the same symbol plus a knocked-out diagonal
/// stroke, drawn once (SF Symbols has no slashed hand symbol).
enum StatusIcon { static func image(active: Bool) -> NSImage { fatalError("not implemented") } }

/// AppKit-only actions the views trigger.
struct LauncherActions {
    let chooseOtherApp: (Gesture) -> Void
    let openTrackpadSettings: () -> Void
    let quit: () -> Void
}

/// R4 layout: four gesture rows, HandModeToggle ("Left hand | Right hand"), Divider, then HintText while active
/// or TrackpadSettingsNotice(cause) while inactive, then a bottom bar with Quit only.
/// The illustrations are assets/*.svg from Bundle.main as template images, mirrored horizontally for .left (R10).
struct LauncherView: View {
    let launcher: Launcher
    let actions: LauncherActions
    var body: some View { fatalError("not implemented") }
}
```

#### Tests: in-memory adapters and the source policy

```swift
/// Real recognizer, scripted frames, synchronous main-actor delivery: R11 scenarios run through the whole app.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)?
    private(set) var attached: [Trackpad] = [.macBook14BuiltIn]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var feedback: [TrackpadID] = []
    func connected() -> [Trackpad] { attached }
    func run(_ trackpads: [Trackpad], handMode: HandMode) { /* running = fresh recognizers for trackpads */ }
    func playFeedback(on trackpad: TrackpadID) { feedback.append(trackpad) }
    func attach(_ t: Trackpad) { /* append; onEvent?(.trackpadsChanged) */ }
    func detach(_ id: TrackpadID) { /* remove; onEvent?(.trackpadsChanged) */ }
    func wake() { onEvent?(.trackpadsChanged) }
    /// Frames on a trackpad that is not running are dropped, exactly like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) { /* step running[id]; onEvent?(.gesture) on each fire */ }
}

@MainActor final class InMemoryTrackpadPreferences: TrackpadPreferences {
    var onChange: (@MainActor () -> Void)?
    func settingsOn() -> [TrackpadKind: Set<TrackpadSetting>] { fatalError("not implemented") }
    func set(_ setting: TrackpadSetting, on: Bool, for kind: TrackpadKind) { /* mutate; onChange?() */ }
}

@MainActor final class RecordingSystemActions: SystemActions {
    private(set) var broughtToFront: [AppEntry] = []
    private(set) var loginItemRegistrations = 0
    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }
    func registerLoginItem() { loginItemRegistrations += 1 }
}

/// Frames in millimetres on a surface, 10 ms apart unless told otherwise.
/// R11 scripts: thumbFirstThenTap · repeatedTapsWhileAnchored · fingersBeforeThumb · sameFrameThumbAndFinger ·
/// thumbOutsideCorner · thumbAloneFiveSeconds · dragIsNotATap · fiveFingers · clickIsNotATap (buttonDown mid-tap) ·
/// staggeredLandingAndLifting · thumbLiftsBeforeFingers · tapHeldTooLong · cornerAt1cmAnd4cm · leftHandMirror.
struct TouchScript {
    init(_ surface: SurfaceSize) { fatalError("not implemented") }
    func thumb(atMM p: (x: Double, y: Double)) -> TouchScript { fatalError("not implemented") }
    func tap(fingers n: Int, atMM p: (x: Double, y: Double) = (62, 45), stagger: Duration = .zero,
             hold: Duration = .milliseconds(120), dragMM: Double = 0, clickMidway: Bool = false) -> TouchScript { fatalError("not implemented") }
    func liftThumb() -> TouchScript { fatalError("not implemented") }
    func wait(_ d: Duration) -> TouchScript { fatalError("not implemented") }
    var frames: [TouchFrame] { fatalError("not implemented") }
}

/// R20–R22 as a gate: scans every .swift file in LauncherKit/Sources and the app target; fails on any hit.
@Suite struct SourcePolicyTests {
    static let banned: [(token: String, rule: String)] = [
        ("print(", "R21 log"), ("debugPrint(", "R21 log"), ("dump(", "R21 log"), ("NSLog(", "R21 log"),
        ("os_log", "R21 log"), ("Logger(", "R21 log"), ("import OSLog", "R21 log"), ("import os", "R21 log"),
        ("URLSession", "R21 network"), ("import Network", "R21 network"), ("NWConnection", "R21 network"),
        ("CFSocket", "R21 network"), ("CFStream", "R21 network"),
        ("FileHandle(forWriting", "R21 own files"), (".write(to:", "R21 own files"), ("createFile(atPath", "R21 own files"),
        ("Timer", "R22 timer"), ("asyncAfter", "R22 timer"), ("Task.sleep", "R22 polling"), ("makeTimerSource", "R22 timer"),
        ("AXIsProcessTrusted", "R20"), ("tapCreate", "R20"), ("CGEventTapCreate", "R20"), ("IOHIDManager", "R20"),
        ("CGRequestListenEventAccess", "R20"), ("CGPreflightListenEventAccess", "R20"),
    ]
    @Test(arguments: banned) func noSourceUses(_ entry: (token: String, rule: String)) { /* scan; #expect(hits.isEmpty) */ }
}
```

**Test handles.** These cover everything a test cannot wait for or trigger directly.

| Thing | Handle |
|---|---|
| Clock behind the tap timeout | `TouchFrame.time`; no clock object exists |
| Frame source | `InMemoryTrackpads.touch(_:on:)` |
| Button-state sampler | `TouchFrame.buttonDown` |
| Preference store | `InMemoryTrackpadPreferences.set`; the real adapter is tested against throwaway domains written with `defaults` |
| Device notifications | `attach` / `detach` / `wake` |
| Launcher (bring to front) and login item | `RecordingSystemActions` |
| Actuator | `InMemoryTrackpads.feedback` |
| Settings | `SettingsStore` over a throwaway suite |
| Disk | `AppCatalog` over a temp directory with an injected `registeredCopies` |
| The one slow call | `await launcher.openWindow()` |

### Synthesis decision

### Tradeoffs accepted

- **Full restart on every reconcile.** `run` stops and restarts every device, even when only a preference or the hand mode changed. A tap in progress is dropped (a few ms, on rare events). In exchange there is one convergent operation with no stale-device detection, and wake needs no special path.
- **A `Mutex` around each recognizer that is never contended.** This proves single ownership to the compiler instead of using `nonisolated(unsafe)`.
- **A large real hardware adapter, checked only by hand.** It holds MultitouchSupport, IOKit, wake, session, actuators and classification. In exchange the core has one hardware port, and its fake runs the real recognizer.
- **Button state sampled on every frame while touching.** This is a cheap state query, and it keeps the recognizer a pure function of its input. The alternative was sampling only when a tap is being counted, which would leak recognizer state into the adapter.
- **Installed apps refresh when the window opens, not strictly when the picker opens.** These are equivalent here: any interaction outside the window closes it (R3), so the window must reopen before a picker can. In exchange, enumeration runs off the main actor and no FSEvents watcher runs at idle.
- **Other… closes the launcher window, runs `NSOpenPanel` with the app activated, then reopens the window.** This avoids fighting window levels and resign-key dismissal while the chooser is up.
- **Resolved URLs are not written back.** An app moved away from its last-known URL costs a LaunchServices lookup on each fire (around a millisecond). In exchange, settings change only through user intent.
- **First launch is derived from whether a settings record exists.** A user who deletes the app's preferences gets a first launch again, including the login item.
- **Rows are a disk snapshot.** It is refreshed on open and on each assignment, so an app deleted while the window is open still shows as present until the next open. The fire path resolves fresh each time, so behaviour is never wrong.

### Alternatives considered

- **Hop every frame to the main actor and recognize there.** This needs no frame-thread `Mutex`, but it wakes the main thread about 100 times a second whenever a finger is on the trackpad, for no gain in depth. Button state would still have to be sampled on the frame thread. Rejected on cost, against the overview's "most performant path".
- **The adapter delivers raw frames, and the core owns a thread-safe engine plus the hop.** The core would then contain threading and an engine (map of recognizers, `setHandMode`, `reset`). Its tests would have to wait on an async hop to observe both "nothing happened" and "something happened". Moving the hop into the adapter keeps the core synchronous and deterministic.
- **Devices always running, gated only at the fire path.** The device lifecycle would be simpler (prefs changes would not touch devices), but CPU is spent on frames that can never fire while *Tap to click* is on, and "nothing is recognised" would hold only in effect. Reconcile already runs on every input, so stopping the devices costs nothing extra.
- **One `Trackpads` port that also reports each trackpad's settings.** The core would be slightly smaller, but the built-in/external join, which is R14's subtle case, would move into an untested adapter. Keeping preferences as a separate port keyed by `TrackpadKind` keeps the join pure and covered by table tests.
- **`MenuBarExtra(.window)`.** It cannot be opened or closed programmatically (per grounding), which R18 and R3 need.

### Open questions and risks

- **Device classification.** Which family IDs (or IORegistry properties) mark Magic Mouse and the Touch Bar digitizer? macOS 26 still supports two Intel MacBook Pros with Touch Bars. Should classification be a denylist (risk: a mouse counts as a trackpad) or an allowlist (risk: a new trackpad is ignored)?
- **Device readiness after wake or hot-plug.**
  - Is a device startable at the moment `didWake` or IOKit first-match fires? If not, should we add `screensDidWake` as a later signal, or accept one bounded one-shot retry? That retry would be the app's only timer.
  - Does App Nap delay the gesture hop or activation for a background `LSUIElement` app? This should be measured in E2E.
- **Preference semantics.**
  - Does an absent `TrackpadThreeFingerTapGesture` really mean "not a tap", for example on a first-generation Magic Trackpad?
  - Does a USB-wired Magic Trackpad read the Bluetooth domain?
- **Fast user switching.** Is stopping the devices while our login session is off the console the behaviour you want? It prevents firing on, and pulsing, another user's trackpad.
- **Feel constants:** 300 ms tap, 3 mm drag, 2 mm anchor release margin, actuation 6. Should these be tuned once on a 13" MacBook and on a Magic Trackpad before they are frozen?
- **Window behaviour to confirm in E2E.**
  - Is closing and reopening the window around Other… acceptable UX?
  - Does a click on the status icon while the window is open close it, rather than closing on resign-key and then reopening on the action?
  - Should the shell adopt `NSStatusItemExpandedInterfaceDelegate` once the macOS 27 SDK ships? It is not in SDK 26.5.
- **Frame layout.** The frame layout (Q1) is still unprobed. Until a real touch confirms it, the recognizer is proven only against frames we wrote ourselves.
- **Signing.** R23 cannot be verified until a Developer ID Application certificate is installed.

### Next implementation step

Scaffold the `LauncherKit` package with `LauncherCore` (domain types, `GestureRules`, `GestureRecognizer`) and `SourcePolicyTests`, then drive the recognizer test-first through every R11 frame script. Meanwhile the human runs `mt-probe` with a real touch to confirm the frame layout the adapter will parse.
