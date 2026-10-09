## Design

### Problem

Trackpad Launcher binds four thumb-anchored taps to *bring to front* and is configured from a menu bar window. The shape is non-obvious because every input is a push from a different thread and framework, and the whole app must cost nothing while idle. Raw touches come only from the private MultitouchSupport framework: `dlopen` works with no permission prompt, the framework is silent while nothing touches the trackpad, and frames arrive through a context-free C callback on a framework-owned thread at ~100 Hz while touching (grounding Q1; the 96-byte frame layout, state values and bottom-left origin are sourced, not yet probed). Whether gestures may run depends on another process's preferences in two cfprefs domains, pushed by KVO on the main thread (Q4), on which trackpads are attached, pushed by IOKit (Q5; MultitouchSupport has no hot-plug symbol), and on sleep/wake. Feedback must hit the trackpad that was tapped, which only the per-device `MTActuator` can do (Q3). A click must be told from a tap without an event tap, so button state is sampled (Q2). *Bring to front* is one probed call, `openApplication(at:configuration:)` with `activates`, which reproduces a Dock click and is idempotent under a double tap (Q6). `MenuBarExtra` cannot open or close its window programmatically, so the launcher window is an `NSStatusItem` plus an `NSPanel` hosting SwiftUI on Liquid Glass (Q8; the macOS 27 expanded-interface session API is not in SDK 26.5, see checks). Hard constraints: no permissions, no network, no logging, no timers or polling (R20–R22); Swift 6 strict concurrency on the Xcode 26 toolchain (SDK 26.5); a macOS 26 universal binary signed with Developer ID (this machine has no Developer ID certificate yet).

### Usage (caller's view)

**README excerpt.** One `@MainActor` model, `Launcher`, owns every decision. Adapters sense and act: they tell it "a gesture fired" or "the trackpads may have changed", and they carry out its commands (run devices, play feedback, bring an app to front, register the login item). The menu bar shell renders `launcher.activity` (icon, notice) and `launcher.isWindowOpen` (the panel). The window renders `launcher.rows` and `launcher.handMode`, calls `setAssignment` and `setHandMode`, and fills each app picker from the catalog the moment the picker's menu opens. Tests build the same model on in-memory adapters, a temp directory of fake `.app` bundles and a throwaway `UserDefaults` suite, and script touches as frames. Nothing in the app waits on a timer.

```swift
// TrackpadLauncher app target: the whole composition root.
@main @MainActor
enum TrackpadLauncherApp {
    static func main() {
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            system: WorkspaceActions(),
            catalog: catalog,
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher, catalog: catalog)   // status item first: a first-launch window needs its anchor
        launcher.start()                                                 // reconcile; on first launch: login item, then window
        withExtendedLifetime(shell) { NSApplication.shared.run() }
    }
}
```

```swift
// LauncherCoreTests: the high seam. R11 + R12 + R13 + R3 in one scenario, driven by frames, synchronous.
@MainActor @Test func thumbFirstThenTwoFingerTapBringsFigmaToFront() throws {
    let world = try World(apps: ["Figma"])              // fake bundles + in-memory adapters + throwaway suite
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
    world.launcher.openWindow()

    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2).frames, on: Trackpad.macBook14.id)

    #expect(world.system.broughtToFront == [world.app("Figma")])
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    #expect(world.launcher.isWindowOpen == false)
}

// R14: the external trackpad's setting silences gestures on the built-in one too, and the notice names only it.
@MainActor @Test func tapToClickOnExternalOnlySilencesEveryTrackpad() throws {
    let world = try World(apps: ["Arc"]); world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
    world.hardware.attach(.magicTrackpad)
    world.preferences.set(.tapToClick, rawValue: 1, for: .external)

    #expect(world.launcher.activity == .inactive(.settings(ConflictingSettings([.tapToClick])!)))
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1).frames, on: Trackpad.macBook14.id)
    #expect(world.system.broughtToFront.isEmpty && world.hardware.feedback.isEmpty)
}
```

```swift
// The recognizer's own seam: every R11 scenario as a frame script, pure and synchronous.
@Test(arguments: [(thumbXMM: 10.0, fires: true), (thumbXMM: 40.0, fires: false)])   // 1 cm in, 4 cm out on 124.8 mm
func anchorCornerGeometry(thumbXMM: Double, fires: Bool) {
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let frames = TouchScript(.macBook14).thumb(atMM: (thumbXMM, 10)).tap(fingers: 1).frames
    let fired = frames.compactMap { recognizer.step($0) }
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
            AppPicker(row.app, installedApps: actions.installedApps,              // enumerated each time the menu opens (R5)
                      choose: { launcher.setAssignment($0, for: row.gesture) },   // .app(entry) or .unassigned
                      chooseOther: { actions.chooseOtherApp(row.gesture) })       // NSOpenPanel lives in the shell
        }
    }
}
```

### Shape

**Data first.** All domain values are `Sendable` structs and enums in `LauncherCore`, each with a public memberwise initialiser (the platform adapters and the test fixtures construct them from other modules).

- *What the recognizer reads.* A `TouchFrame` is a complete snapshot of one trackpad at one instant: a `FrameTime`, the contacts that are down now (each a `Touch` with a `TouchID`, a `SurfacePoint` normalised with the origin top-left, and a `phase` of `.landing` or `.down`), and `buttonDown`. A contact absent from a frame has lifted; there is no other "touch ended" path. A `Trackpad` has a `TrackpadID`, a `TrackpadKind` (`.builtIn` or `.external`) and a `SurfaceSize` in mm.
- *What fires.* `Gesture` has four cases, `.one` to `.four`; its init from a finger count is failable, so five fingers produce no value. A `GestureEvent` is a gesture plus the trackpad it fired on.
- *What the user stores.* `HandMode` is `.right` or `.left`; `AnchorCorner` is derived from it and the surface. `Settings` holds the hand mode and `assignments: [Gesture: AssignedApp]`, where unassigned means absent. `AssignedApp` is a `BundleID` (the identity), a display name and a last-known URL used only as a fast path. "Launched before" is the existence of a stored record; it is not a second flag.
- *What the window shows.* *Missing* is never stored: `GestureRow.app` is `.unassigned`, `.present(AppEntry)` or `.missing(name:)`, derived when `AppCatalog.locate` returns nil. Gesture activity is `GestureActivity`: `.active` or `.inactive(InactiveCause)`, where the cause is `.noTrackpad` or `.settings(ConflictingSettings)`. `ConflictingSetting` is an enum whose cases are the rows of the R14 table (preference key, conflicting raw value, notice name, each an exhaustive switch), and `ConflictingSettings` is non-empty by construction, so "inactive for no reason" and "a row missing a fact" cannot compile (per `type-system-discipline`, `encode-lessons-in-structure`).

**Load-bearing decisions.**

1. *Recognition is a pure state machine that runs on the frame thread, one per trackpad.* `GestureRecognizer.step(_:) -> Gesture?` is a sum type over `idle`, `armed(anchor)`, `tapping(anchor, fingers, peak, start)` and `spoiled(anchor)`, so an anchor can never be absent while a tap is counted. Within a frame, lifts are evaluated before landings, and a tracked contact that reappears with `.landing` counts as lifted and landed anew, so a reused touch ID cannot fuse two taps. Time is data: frames carry their own timestamps and the tap duration is checked against them, so no clock object or timer exists anywhere. The test handle for "the clock" is `TouchFrame.time`; for the button sampler, `TouchFrame.buttonDown`. All fixed numbers live in `GestureRules`. Only fired gestures hop to the main actor; the main thread wakes for gestures, not frames (per `foundational-thinking`).
2. *Both hardware adapters drive the same recognizer.* The real `MultitouchTrackpads` steps it under a never-contended `Mutex` on the frame thread; `InMemoryTrackpads` steps it synchronously on the main actor. Every R11 scenario runs at the recognizer seam and through the whole app at the `Launcher` seam, with no async waiting.
3. *One idempotent `reconcile()`* handles launch, IOKit add/remove, wake, preference change and hand-mode change. It re-reads the truth (`hardware.connected()`, `preferences.current()`) into two stored inputs, from which `activity` is derived on read, and calls `hardware.run(activity.isActive ? trackpads : [], handMode:)`. `run` means "forget every session, stop every device, then start exactly these, each with a fresh recognizer"; it converges from any prior state, including deaf devices after wake (per `make-operations-idempotent`). Inactive means the devices are stopped: nothing is recognised (as `docs/domain-model.md` says) and touching costs nothing.
4. *Activity is a pure derivation over one table.* `GestureActivity(connected:values:)` joins each connected trackpad kind to its domain's raw values through `ConflictingSetting.conflicts(rawValue:)`. "No trackpad" wins over settings; causes are listed in table order. The status icon, the notice and the fire guard read the same `launcher.activity`. Adding Smart zoom is one enum case, and the compiler lists every switch to extend.
5. *The fire path decides every silent case in one function.* `Launcher.fire` checks, in order: inactive, unassigned, missing. If all pass it plays feedback on `event.trackpad`, brings the app to front and closes the window. The guard catches a gesture already in flight when activity flips.
6. *Assignment identity is the bundle ID.* `AppCatalog.locate` tries the last-known URL first if it still holds that bundle ID outside any Trash; otherwise it asks LaunchServices for registered copies and drops those in the Trash. Nil means missing, so a reinstalled app recovers without re-picking. The resolved URL is never written back. Rows are a snapshot refreshed when the window opens and when an assignment changes; the fire path resolves fresh each time. The app picker's list is enumerated each time the picker's menu opens (`NSMenuDelegate.menuNeedsUpdate` on an `NSPopUpButton`), so R5's "each time the picker opens" holds literally and no cache exists to invalidate.
7. *First launch is derived, not flagged:* it is a first launch exactly when no settings record is stored. `start()` registers the login item before its first save, so a crash between the two re-registers next time (registration is idempotent) instead of losing the item; an undecodable record loads as defaults, not as a first launch, so a user who turned the item off is never re-enrolled (R17).
8. *Window visibility is model state* (`isWindowOpen`): R18 opens and R3 closes it from the core, so both are testable; the shell maps AppKit signals to `openWindow()`/`closeWindow()` and renders the state.
9. *Rules are enforced by structure.* `LauncherCore` cannot import AppKit, IOKit or the private framework. `SourcePolicyTests` scans every source file for logging, network, timer, own-file-write and permission APIs and fails on any hit.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `Launcher` | 4 read-only properties, 5 intents | Persistence, first-launch policy, login item, device reconciliation across hot-plug and wake, activity derivation, fire policy, assignment resolution, refresh-on-show |
| `TrackpadHardware` | 4 members | `dlopen`, the MTTouch layout, the C-callback registry, the frame thread, IOKit and wake notifications, actuators, trackpad classification |
| `GestureRecognizer` | init and `step` | All of R11 |
| `AppCatalog` | 3 methods | Enumeration, bundle parsing, de-duplication, sorting, Trash filtering, the LaunchServices fallback |
| `TrackpadPreferences` | 2 members | KVO on two cfprefs domains, raw reads |
| `SystemActions` | 2 methods | Nothing much: the recording seam for the two effects the core decides on, with two real adapters |

**Concurrency** (Swift 6, language mode 6).

- *Main actor:* `Launcher`, the three port protocols and the public surface of every real adapter are `@MainActor`; `LauncherUI` and the app target use default main-actor isolation. `LauncherCore` and `LauncherPlatform` stay nonisolated by default because the recognizer and the C callback must not be main-isolated.
- *Frame thread:* the C callback looks up its `DeviceSession` in a `Mutex` registry (written by `run` on main, read on the frame thread), steps that device's recognizer (its own `Mutex` is the compiler's proof of single ownership and is never contended), and for events only hops with `Task { @MainActor }`.
- *Other threads:* IOKit notifications arrive through a port scheduled on `DispatchQueue.main`; wake is observed with `queue: .main`; preference KVO arrives on main (probed) but the adapter hops with `Task { @MainActor }` regardless. `AppCatalog.installedApps()` runs synchronously on the main actor when a picker's menu opens (user-initiated, tens of milliseconds).
- *Ownership:* every stored field has one writer. No two actors write the same state.

**Build and test layout.**

- Local SwiftPM package `LauncherKit` (`swift-tools-version 6.2`, `platforms: [.macOS(.v26)]`, `swiftLanguageModes: [.v6]`): library targets `LauncherCore` (Foundation, Observation), `LauncherPlatform` (AppKit, IOKit, CoreGraphics, ServiceManagement, Synchronization) and `LauncherUI` (AppKit, SwiftUI; `.defaultIsolation(MainActor.self)`); test targets `LauncherCoreTests` and `LauncherPlatformTests`, Swift Testing, run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` (`Scripts/test.sh`).
- xcodegen-generated app target `TrackpadLauncher` (`project.yml`): the composition root only; bundles the repo's `assets/*.svg` directly; Info.plist `LSUIElement = YES`, `LSMinimumSystemVersion = 26.0`; `MACOSX_DEPLOYMENT_TARGET 26.0`, `ARCHS_STANDARD` (arm64 + x86_64), hardened runtime, no sandbox, no entitlements; `Config/Debug.xcconfig` signs with Apple Development, `Config/Release.xcconfig` with Developer ID Application.
- `Scripts/release.sh`: `xcodebuild archive`, export with the developer-id method, `notarytool submit --wait`, `stapler staple`. Blocked until a Developer ID certificate exists; Apple Development signing is enough for `SMAppService` locally.
- Why: `swift test` runs the whole behavioural suite in seconds with no project generation; xcodebuild owns only what SwiftPM cannot produce (the bundle, Info.plist, signing, archiving). The Xcode 26 SDK is what makes Liquid Glass and `LSMinimumSystemVersion = 26.0` honest.

**Requirement trace.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | App target `LSUIElement` | manual |
| R2 | `GestureActivity` → `MenuBarShell` icon (`StatusIcon`) | `Launcher` seam (`activity`); look manual |
| R3 | `isWindowOpen`; shell dismissal (resign key with status-button guard, mouse-down monitor while open, Escape, icon toggle) | `Launcher` seam (gesture closes, first launch opens); rest manual |
| R4, R10 | `LauncherView` on `NSGlassEffectView`; SVGs as template images, mirrored for `.left`; hint from `AnchorCorner` | manual, light and dark |
| R5 | `AppCatalog.installedApps` on `menuNeedsUpdate` / `entry(at:)`; `AppPicker` over `NSPopUpButton`; Other… in the shell | catalog over a temp dir; menu and panel manual |
| R6, R8 | `Settings` defaults; `SettingsStore` | `Launcher` seam over a throwaway suite (two models, same suite) |
| R7 | `AppCatalog.locate`; rows refreshed on open; fire guard | `Launcher` seam over a temp dir (move, trash, reinstall) |
| R9 | `HandMode` → `AnchorCorner` via `run(_:handMode:)` | recognizer and `Launcher` seams |
| R11 | `GestureRecognizer`, `GestureRules` | recognizer seam (every scenario) and `Launcher` seam |
| R12 | `SystemActions.bringToFront` → `openApplication` with `activates` | recording fake; real call probed; Spaces and full-screen manual |
| R13 | `Launcher.fire` → `playFeedback(on: event.trackpad)` | `Launcher` seam (`feedback`) |
| R14, R15 | `ConflictingSetting` table, `GestureActivity`, `reconcile`, `TrackpadSettingsNotice` | pure table tests and `Launcher` seam |
| R16 | `MultitouchTrackpads` (IOKit, wake) → `reconcile` | `Launcher` seam via `attach`/`detach`/`wake`; hardware manual |
| R17, R18 | `Launcher.start` (first launch ⇔ nothing stored); `registerLoginItem` | `Launcher` seam |
| R19 | Shell Quit → `NSApp.terminate` | manual |
| R20–R22 | Module boundaries, push-only adapters, `run([])` when inactive, `SourcePolicyTests` | source scan; Console, network monitor and Activity Monitor manual |
| R23 | App target settings and release script | manual; blocked on Developer ID |

**Deliberately not done.** No FSEvents and no polling of app folders. No write-back of resolved URLs. No `NSHapticFeedbackManager`. No key-event monitors; the only global monitor is mouse-down and exists only while the window is open. No framework type crosses a port: `MTTouch`, `CFTypeRef`, `UserDefaults`, `NSRunningApplication` and `NSImage` stay inside adapters and views. No fast-user-switching handling (not required; see open questions).

#### Module map

```
LauncherCore     (Foundation, Observation)          domain types · GestureRules · GestureRecognizer · ConflictingSetting table ·
                                                     GestureActivity · AppCatalog · Settings/SettingsStore · ports · Launcher
LauncherPlatform (AppKit, IOKit, CoreGraphics,       MultitouchTrackpads (MT dlopen, MTTouch parse, C callback, IOKit, wake,
                  ServiceManagement, Synchronization)  actuators, trackpad classification) · SystemTrackpadPreferences (KVO) ·
                                                     WorkspaceActions · AppCatalog.system
LauncherUI       (AppKit, SwiftUI; MainActor)        MenuBarShell · LauncherPanel · StatusIcon · LauncherView · GestureRowView ·
                                                     AppPicker · HandModeToggle · HintText · TrackpadSettingsNotice
TrackpadLauncher app target (xcodegen)              composition root · Info.plist · assets/*.svg
Tests                                               LauncherCoreTests (recognizer, activity table, catalog, store, Launcher seam,
                                                     SourcePolicyTests) · LauncherPlatformTests (prefs KVO with throwaway domains,
                                                     MTTouch stride == 96, trackpad classification table)
```

#### LauncherCore: gesture domain and recognizer

```swift
import Foundation

/// Which hand holds the anchored thumb (R9). One global setting; default `.right`.
public enum HandMode: String, Codable, Sendable, CaseIterable {
    case right   // anchor corner top-left
    case left    // anchor corner top-right
    /// The words the hint uses (R10): "top-left" or "top-right".
    public var cornerName: String { self == .right ? "top-left" : "top-right" }
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
/// The MT adapter maps MultitouchSupport's convention onto this one; nothing else knows about it.
public struct SurfacePoint: Hashable, Sendable { public var x: Double; public var y: Double }

/// Physical surface size from MTDeviceGetSensorSurfaceDimensions (probed: 124.8 × 76.8 mm, 14" MacBook Pro).
public struct SurfaceSize: Hashable, Sendable {
    public var widthMM: Double; public var heightMM: Double
    /// Distance in millimetres between two normalised points on this surface.
    public func distanceMM(_ a: SurfacePoint, _ b: SurfacePoint) -> Double { fatalError("not implemented") }
}

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

/// A contact that is DOWN in this frame. The adapter drops hovering, lingering and lifted contacts.
/// `.landing` is MT state 3 (MakeTouch). A tracked ID that reappears with `.landing` was lifted and has landed
/// anew (the driver reused the ID); an ID that appears without `.landing` is treated as landed too.
public struct Touch: Sendable {
    public enum Phase: Sendable { case landing, down }
    public let id: TouchID
    public let phase: Phase
    public let position: SurfacePoint
}

/// Monotonic seconds on the multitouch driver's clock. The only time recognition ever reads.
public struct FrameTime: Comparable, Sendable {
    public var seconds: Double
    public static func - (lhs: FrameTime, rhs: FrameTime) -> Duration { .seconds(lhs.seconds - rhs.seconds) }
    public static func < (lhs: FrameTime, rhs: FrameTime) -> Bool { lhs.seconds < rhs.seconds }
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot:
/// a contact absent from `touches` has lifted. `[]` is the frame after the last lift.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
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
        // down   = frame.touches keyed by id
        // reused = ids in previouslyDown whose touch has phase .landing        (lifted AND landed anew on this frame)
        // lifted = previouslyDown − down.keys, plus reused
        // landed = touches with phase .landing, plus ids not in previouslyDown
        // Lifts are evaluated before landings: a tap that ends on this frame fires before this frame's landings
        // are seen, so a reused ID cannot fuse two taps.
        //
        // 1. Anchor maintenance (every state that carries an anchor):
        //      anchor.id in lifted, or !corner.holds(its position)  → state = .idle
        //      (a thumb that slides out is from then on just a finger; it is not re-adopted.
        //       thumb lifting before the fingers, or in the same frame as the last finger → idle → no fire)
        // 2. switch state
        //    .idle:
        //      if let thumb = landed.first(where: { corner.admits($0.position) }):
        //          anchor = Anchor(thumb.id, since: frame.time)
        //          state = (down minus thumb).isEmpty ? .armed(anchor) : .spoiled(anchor)
        //          // fingers already down when the thumb lands (or landing in the same frame) never fire: wait for a clean slate
        //    .armed(anchor):
        //      fingers = landed minus anchor
        //      if !fingers.isEmpty:
        //          state = frame.buttonDown ? .spoiled(anchor)
        //                                  : .tapping(anchor, fingers: [id: landing point], peak: fingers.count, start: frame.time)
        //    .tapping(anchor, fingers, peak, start):
        //      remove lifted ids from fingers
        //      if frame.buttonDown || frame.time - start > maxTapDuration
        //         || any remaining finger is > dragThresholdMM (surface.distanceMM) from its landing point → state = .spoiled(anchor)
        //      else if fingers.isEmpty:                                 // the last finger lifted on this frame
        //          fired = Gesture(fingerCount: peak)                   // nil for 5+
        //          new = landed minus anchor                            // a reused ID, or a fresh landing, starts the next tap now
        //          state = new.isEmpty ? .armed(anchor)
        //                              : .tapping(anchor, fingers: [id: landing point], peak: new.count, start: frame.time)
        //      else:
        //          add landed non-anchor touches to fingers; peak = max(peak, fingers.count)
        //    .spoiled(anchor):
        //      if (down minus anchor).isEmpty → state = .armed(anchor)
        // 3. previouslyDown = Set(down.keys); return fired
        fatalError("not implemented")
    }

    private struct Anchor: Sendable { let id: TouchID; let since: FrameTime }
    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, fingers: [TouchID: SurfacePoint], peak: Int, start: FrameTime)
        case spoiled(Anchor)
    }
    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID> = []
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
/// THIS ENUM IS THE TABLE: every case supplies its key, its conflicting value and its notice text through
/// exhaustive switches, so adding Smart zoom is one case the compiler forces through all three.
/// `allCases` order is notice order (R15). Values are sourced (grounding Q4); a correction is one line here.
public enum ConflictingSetting: CaseIterable, Hashable, Sendable {
    case tapToClick
    case lookUpTapWithThreeFingers
    // case smartZoom   // R14: add if testing shows a two-finger double tap fires with a thumb anchored

    /// Key within each trackpad preference domain. Read only by the preferences adapter.
    package var preferenceKey: String {
        switch self {
        case .tapToClick:                 "Clicking"
        case .lookUpTapWithThreeFingers:  "TrackpadThreeFingerTapGesture"
        }
    }
    /// True when the raw value means the action is bound to a tap. nil (key absent) is off.
    public func conflicts(rawValue: Int?) -> Bool {
        switch self {
        case .tapToClick:                 rawValue == 1
        case .lookUpTapWithThreeFingers:  rawValue == 2
        }
    }
    /// Exactly the words the trackpad settings notice uses (R15).
    public var noticeName: String {
        switch self {
        case .tapToClick:                 "Tap to click"
        case .lookUpTapWithThreeFingers:  "Look up: Tap with three fingers"
        }
    }
}

/// Raw values of the table keys as read from one domain. Absent keys are absent entries.
public typealias TrackpadPreferenceValues = [ConflictingSetting: Int]

/// Non-empty, in table order. The failable init is the only constructor.
public struct ConflictingSettings: Equatable, Sendable {
    public let settings: [ConflictingSetting]
    public init?(_ settings: [ConflictingSetting]) { fatalError("not implemented") }   // nil when empty
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

    /// Pure. No trackpad wins over settings; a setting blocks when it conflicts on ANY connected kind.
    public init(connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues]) {
        // guard !connected.isEmpty else { self = .inactive(.noTrackpad); return }
        // let blocking = ConflictingSetting.allCases.filter { s in connected.contains { kind in s.conflicts(rawValue: values[kind]?[s]) } }
        // self = ConflictingSettings(blocking).map { .inactive(.settings($0)) } ?? .active
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
    /// Enumerates on every call: the picker calls it each time its menu opens (R5).
    public func installedApps() -> [AppEntry] { fatalError("not implemented") }

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
    case trackpadsChanged   // attached, detached, or the Mac woke
}

/// The multitouch hardware. Real: MultitouchTrackpads. Test: InMemoryTrackpads.
@MainActor public protocol TrackpadHardware: AnyObject {
    /// Always called on the main actor.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    /// Trackpads connected now. Excludes multitouch devices that are not trackpads (Magic Mouse, Touch Bar).
    func connected() -> [Trackpad]
    /// Forgets every session, stops every running device, then starts exactly `trackpads`, each with a fresh
    /// GestureRecognizer for `handMode`. Idempotent. [] = nothing runs (zero cost).
    func run(_ trackpads: [Trackpad], handMode: HandMode)
    /// One haptic pulse on that trackpad (feedback, R13). No-op if it is gone.
    func playFeedback(on trackpad: TrackpadID)
}

/// The two trackpad preference domains. Real: SystemTrackpadPreferences. Test: InMemoryTrackpadPreferences.
@MainActor public protocol TrackpadPreferences: AnyObject {
    /// Called on the main actor after any table key changes in either domain.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Current raw values of every table key, per kind, read fresh (cheap, probed). Reads only; never writes a system domain.
    func current() -> [TrackpadKind: TrackpadPreferenceValues]
}

/// Effects the core decides and macOS performs. Real: WorkspaceActions. Test: RecordingSystemActions.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click (R12).
    func bringToFront(_ app: AppEntry)
    /// Open at Login (R17). Idempotent. Called only on first launch.
    func registerLoginItem()
}
```

#### LauncherCore: the Launcher (the high seam)

```swift
import Observation

/// The running Trackpad Launcher. Owns every decision; adapters sense and act, the shell and views render.
/// Invariants: `activity` is derived, never stored; `rows` derive from settings + the catalog; `fire` is the only
/// path that pulses, launches, or closes the window from a gesture; every stored field has one writer: this actor.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    public private(set) var isWindowOpen = false
    public var handMode: HandMode { settings.handMode }
    /// R2, R14, R15: one derivation, every reader (icon, notice, fire guard).
    public var activity: GestureActivity {
        GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }

    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
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
    public func start() {
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
        openWindow()
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

    /// Show the launcher window and re-resolve the rows (R7 missing/recovered). The picker's list is not held here:
    /// the picker enumerates the catalog itself each time its menu opens (R5).
    public func openWindow() {
        isWindowOpen = true
        rows = makeRows()
    }

    public func closeWindow() { isWindowOpen = false }

    /// The one convergent operation behind launch, hot-plug, wake, preference and hand-mode changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        hardware.run(activity.isActive ? connected : [], handMode: settings.handMode)
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

#### LauncherPlatform: real adapters

```swift
import AppKit
import IOKit
import ServiceManagement
import Synchronization

/// TrackpadHardware over MultitouchSupport (dlopen), IOKit and NSWorkspace notifications.
/// Threads: frames arrive on MultitouchSupport's thread and are recognised THERE; only gestures hop to main.
/// IOKit matched/terminated: notification port on DispatchQueue.main (initial iterator drained; that first
/// callback is one harmless extra reconcile). Wake: observer on `.main`.
@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    public var onEvent: (@MainActor (TrackpadEvent) -> Void)?

    /// dlopen + dlsym once (the probed symbol set). On failure: connected() == [] → "No trackpad connected".
    /// Registers IOServiceAddMatchingNotification(first-match + terminated, "AppleMultitouchDevice") and
    /// NSWorkspace.didWakeNotification → onEvent(.trackpadsChanged).
    public init() { fatalError("not implemented") }

    /// MTDeviceCreateList → keep devices classified as trackpads → [Trackpad].
    public func connected() -> [Trackpad] { fatalError("not implemented") }

    public func run(_ trackpads: [Trackpad], handMode: HandMode) {
        // TODO
        // 1. let old = sessions.withLock { s in defer { s = [:] }; return s }   — registry cleared FIRST:
        //    in-flight frames from old refs now find nothing and are dropped
        // 2. For every old session: MTUnregisterContactFrameCallback, MTDeviceStop, MTActuatorClose, MTDeviceRelease.
        // 3. Re-list; for each device whose ID is in `trackpads`:
        //      session = DeviceSession(trackpad, GestureRecognizer(handMode, surface), deliver: hop to main)
        //      open its actuator (MTActuatorCreateFromDeviceID + MTActuatorOpen) for low-latency feedback
        //      sessions[ref] = session; MTRegisterContactFrameCallback(ref, contactFrameCallback); MTDeviceStart(ref, 0)
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
    /// MTTouch[] → TouchFrame. Keeps states 3 (MakeTouch → .landing) and 4 (Touching → .down) only;
    /// maps MT's bottom-left normalised origin to SurfacePoint's top-left one.
    /// A layout correction after the first real-touch check is a change here and nowhere else.
    init(parsing touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double, buttonDown: Bool) {
        fatalError("not implemented")
    }
}

/// Magic Mouse and Touch Bar digitizers are multitouch devices but not trackpads (checks). One table, one place:
/// the IORegistry "Product" string of MTDeviceGetService(ref) must contain "Trackpad"; MTDeviceIsBuiltIn picks the kind.
func trackpadKind(product: String, isBuiltIn: Bool) -> TrackpadKind? { fatalError("not implemented") }

/// CGEventSource.buttonState(.combinedSessionState, …) for .left, .right, .center: a state query, no tap, no TCC.
func anyMouseButtonDown() -> Bool { fatalError("not implemented") }

/// TrackpadPreferences over the two cfprefs domains (probed: KVO fires when another process writes).
@MainActor public final class SystemTrackpadPreferences: TrackpadPreferences {
    public static let systemDomains: [TrackpadKind: String] = [
        .builtIn: "com.apple.AppleMultitouchTrackpad",
        .external: "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]
    public var onChange: (@MainActor () -> Void)?
    /// KVO (addObserver forKeyPath:) on every ConflictingSetting.preferenceKey in each suite;
    /// the nonisolated observeValue hops with Task { @MainActor }. Injectable domains for its own test.
    public init(domains: [TrackpadKind: String] = systemDomains) { fatalError("not implemented") }
    /// `suite.object(forKey:) as? Int` for every table key in every domain, regardless of what is connected.
    public func current() -> [TrackpadKind: TrackpadPreferenceValues] { fatalError("not implemented") }
}

@MainActor public final class WorkspaceActions: SystemActions {
    public init() {}
    /// NSWorkspace.openApplication(at: app.url, configuration: activates = true); completion ignored (nothing to log).
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
    public init(launcher: Launcher, catalog: AppCatalog) {
        // statusItem = NSStatusBar.system.statusItem(withLength: .squareLength); button image StatusIcon.image(active:)
        // actions = LauncherActions(installedApps: { catalog.installedApps() }, chooseOtherApp:, openTrackpadSettings:, quit:)
        // panel = LauncherPanel(content: LauncherView(launcher, actions: actions))
        // Task { for await active in Observations({ launcher.activity.isActive }) { button.image = StatusIcon.image(active:) } }
        // Task { for await open in Observations({ launcher.isWindowOpen }) { open ? showBelowIcon() : hide() } }
        //
        // Dismissal (R3):
        //   icon click        → launcher.isWindowOpen ? launcher.closeWindow() : launcher.openWindow()
        //   panel resigns key → launcher.closeWindow(), unless NSApp.currentEvent is a mouse-down in the status
        //                       item's button window (that click is the toggle above; otherwise it would close and reopen)
        //   mouse-down elsewhere → global monitor [.leftMouseDown, .rightMouseDown, .otherMouseDown], installed on
        //                       show and removed on hide (no idle cost; mouse-only monitors need no permission)
        //   Escape            → LauncherPanel.cancelOperation → launcher.closeWindow()
        //   gesture           → Launcher sets isWindowOpen = false → hide()
        // Other… (R5): closeWindow(); NSApp.activate(); NSOpenPanel(allowedContentTypes: [.application],
        //   canChooseDirectories: false).begin { url → setAssignment(.appBundle(at:)) }; then openWindow().
        // Notice button (R15): NSWorkspace.open("x-apple.systempreferences:com.apple.preference.trackpad").
        // Quit (R19): NSApp.terminate(nil); the login item is untouched.
        fatalError("not implemented")
    }
}

/// Borderless, non-activating, key-capable; pop-up-menu level; joins all Spaces and full-screen apps.
/// contentView = NSGlassEffectView (style .regular, cornerRadius set) whose contentView = NSHostingView(LauncherView).
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { fatalError("not implemented") }   // Escape
}

/// Template images for light and dark menu bars (R2). Inactive = the same symbol plus a knocked-out diagonal
/// stroke, drawn once (SF Symbols has no slashed hand symbol; checked against name_availability.plist).
enum StatusIcon { static func image(active: Bool) -> NSImage { fatalError("not implemented") } }

/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    let installedApps: () -> [AppEntry]   // the catalog, enumerated each time a picker's menu opens (R5)
    let chooseOtherApp: (Gesture) -> Void
    let openTrackpadSettings: () -> Void
    let quit: () -> Void
}

/// The app picker (R5): an NSPopUpButton whose NSMenuDelegate.menuNeedsUpdate rebuilds the items from
/// `installedApps()` every time the menu opens (icon + name per app, then a separator, Other…, None).
/// The button shows the row's app with its icon (NSWorkspace.icon(forFile:)), "Choose app…" when unassigned,
/// or the greyed name with "not found" when missing (R6, R7).
struct AppPicker: NSViewRepresentable {
    let app: RowApp
    let installedApps: () -> [AppEntry]
    let choose: (AppChoice) -> Void
    let chooseOther: () -> Void
    func makeNSView(context: Context) -> NSPopUpButton { fatalError("not implemented") }
    func updateNSView(_ button: NSPopUpButton, context: Context) { fatalError("not implemented") }
}

/// R4 layout: four gesture rows, HandModeToggle ("Left hand | Right hand"), Divider, then HintText while active
/// ("Hold thumb on \(handMode.cornerName) corner, tap with 1, 2, 3 or 4 fingers anywhere to launch selected app")
/// or TrackpadSettingsNotice(cause) while inactive (names from ConflictingSetting.noticeName, or "No trackpad
/// connected", plus the Trackpad settings button), then a bottom bar with Quit only.
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
    private(set) var attached: [Trackpad] = [.macBook14]
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    private(set) var deaf: Set<TrackpadID> = []          // running devices that deliver nothing until the next `run`
    private(set) var feedback: [TrackpadID] = []
    func connected() -> [Trackpad] { attached }
    func run(_ trackpads: [Trackpad], handMode: HandMode) { /* running = fresh recognizers for trackpads; deaf = [] */ }
    func playFeedback(on trackpad: TrackpadID) { feedback.append(trackpad) }
    func attach(_ t: Trackpad) { /* append; onEvent?(.trackpadsChanged) */ }
    func detach(_ id: TrackpadID) { /* remove; onEvent?(.trackpadsChanged) */ }
    /// After sleep the real devices deliver nothing until `run` restarts them (grounding Q5); so does this fake.
    /// A test calls `sleep()` then `wake()`: a reconcile that does not re-run the devices leaves them deaf (R16).
    func sleep() { deaf = Set(running.keys) }
    func wake() { onEvent?(.trackpadsChanged) }
    /// Frames on a trackpad that is not running, or deaf since `sleep()`, are dropped, exactly like stopped hardware.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) { /* step running[id]; onEvent?(.gesture) on each fire */ }
    /// A gesture the frame thread recognised just before activity flipped: delivered regardless of `running`,
    /// so the guard in `Launcher.fire` can be shown to hold.
    func inject(_ event: GestureEvent) { onEvent?(.gesture(event)) }
}

@MainActor final class InMemoryTrackpadPreferences: TrackpadPreferences {
    var onChange: (@MainActor () -> Void)?
    private var values: [TrackpadKind: TrackpadPreferenceValues] = [:]
    func current() -> [TrackpadKind: TrackpadPreferenceValues] { values }
    func set(_ setting: ConflictingSetting, rawValue: Int?, for kind: TrackpadKind) { /* mutate; onChange?() */ }
}

@MainActor final class RecordingSystemActions: SystemActions {
    private(set) var broughtToFront: [AppEntry] = []
    private(set) var loginItemRegistrations = 0
    /// Runs inside `registerLoginItem()`; the World wires it to snapshot `store.load()`, so a test can show the
    /// login item is registered before the first save (R17, decision 7).
    var onRegisterLoginItem: (() -> Void)?
    func bringToFront(_ app: AppEntry) { broughtToFront.append(app) }
    func registerLoginItem() { loginItemRegistrations += 1; onRegisterLoginItem?() }
}

/// Test fixtures for trackpads (surface from the probed 14" MacBook Pro; a Magic Trackpad is 160 × 115 mm).
extension Trackpad {
    static let macBook14 = Trackpad(id: TrackpadID(rawValue: 1), kind: .builtIn, surface: .macBook14)
    static let magicTrackpad = Trackpad(id: TrackpadID(rawValue: 2), kind: .external, surface: SurfaceSize(widthMM: 160, heightMM: 115))
}
extension SurfaceSize { static let macBook14 = SurfaceSize(widthMM: 124.8, heightMM: 76.8) }

/// Frames in millimetres on a surface, 10 ms apart unless told otherwise; `.landing` on each first frame.
/// R11 scripts: thumbFirstThenTap · repeatedTapsWhileAnchored · fingersBeforeThumb · sameFrameThumbAndFinger ·
/// thumbOutsideCorner · thumbAloneFiveSeconds · dragIsNotATap · fiveFingers · clickOnLanding · clickMidway ·
/// staggeredLandingAndLifting · thumbLiftsBeforeFingers · tapHeldTooLong · cornerAt1cmAnd4cm · leftHandMirror ·
/// thumbRollsWithinMargin · idReusedOnNextFrame.
/// The builder sequences thumb → taps → lifts; the four scripts it cannot sequence (fingersBeforeThumb,
/// sameFrameThumbAndFinger, thumbLiftsBeforeFingers, idReusedOnNextFrame) hand-build their frames through
/// TouchFrame's and Touch's public initialisers rather than growing the builder with offsets and ID-reuse options.
struct TouchScript {
    enum ClickTiming { case none, onLanding, midway }   // buttonDown on the landing frame, or on a frame mid-tap
    init(_ surface: SurfaceSize) { fatalError("not implemented") }
    func thumb(atMM p: (x: Double, y: Double)) -> TouchScript { fatalError("not implemented") }
    func tap(fingers n: Int, atMM p: (x: Double, y: Double) = (62, 45), stagger: Duration = .zero,
             hold: Duration = .milliseconds(120), dragMM: Double = 0, click: ClickTiming = .none) -> TouchScript { fatalError("not implemented") }
    /// Moves the anchored thumb over the following frames (thumbRollsWithinMargin: inside the margin keeps the anchor; past it drops it).
    func rollThumb(toMM p: (x: Double, y: Double)) -> TouchScript { fatalError("not implemented") }
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

**Test handles.** Everything a test cannot wait for or trigger directly.

| Thing | Handle |
|---|---|
| Clock behind the tap timeout | `TouchFrame.time`; no clock object exists |
| Frame source | `InMemoryTrackpads.touch(_:on:)` |
| Button-state sampler | `TouchFrame.buttonDown` |
| Preference store and its live change | `InMemoryTrackpadPreferences.set` (invokes `onChange` synchronously); the real adapter is tested against throwaway domains written with `defaults` |
| Device notifications | `attach` / `detach` / `wake` |
| Deaf devices after sleep | `InMemoryTrackpads.sleep()` then `wake()` |
| A gesture already in flight when activity flips | `InMemoryTrackpads.inject(_:)` |
| A click on the landing frame or mid-tap | `TouchScript.tap(click:)` |
| Bring to front and login item | `RecordingSystemActions` |
| Register-before-save order | `RecordingSystemActions.onRegisterLoginItem` snapshotting `store.load()` |
| Actuator | `InMemoryTrackpads.feedback` |
| Settings across "reboot" | `SettingsStore` over one throwaway suite shared by two `Launcher` instances |
| Disk, Trash, moves, reinstalls | `AppCatalog` over a temp directory with an injected `registeredCopies` |
| Window | `launcher.isWindowOpen` |
| Hint wording | `HandMode.cornerName` |
| No logging, network, timers, permission APIs | `SourcePolicyTests` |

### Synthesis decision

Both candidates converged on the whole shape: one `@MainActor @Observable` hub owning all policy; a pure per-trackpad recognizer stepped on the frame thread with the frame timestamp as its only clock (both independently rejected an injected clock and any timer); a table-driven activity derivation read by icon, notice and fire guard; an idempotent restart-everything reconcile; bundle-ID identity with a last-known-URL fast path and a Trash filter; `NSStatusItem` + non-activating `NSPanel` on `NSGlassEffectView`; a SwiftPM core with `swift test` plus an xcodegen app target; and a source-scan test as the no-logging/no-timer mechanism. That convergence is the signal; the differences were point decisions.

**Base: candidate-1.** The cross-judge scored it 18/18 against 11/18 and recommended it; my own scoring was 17 (3, 3, 3, 2, 3, 3) against 11 (2, 2, 2, 2, 1, 2), so we agree on the base. Candidate-1 won on the smaller hub surface (5 properties, 5 intents, 3 ports against 13 members, 7 protocols and 2 closures), on deterministic tests at the high seam (its in-memory hardware delivers gestures synchronously on the main actor, where candidate-2's hub-owned `Task { @MainActor }` hop made its own negative test unable to fail), on trackpad classification (candidate-2 would count a Magic Mouse as an external trackpad), on the login-item order (register before the first save) and on voiding fingers that were already down when the thumb landed (R11's "tap that began before the thumb was anchored"), where candidate-2 would have fired the wrong finger count.

**Grafted from candidate-2:** the recognizer state as one sum type that carries the anchor (`idle | armed | tapping | spoiled`), replacing `anchor?` beside `phase`; `Touch.Phase.landing` from MT state 3 so a reused touch ID still reads as a landing; `ConflictingSetting` as an enum whose exhaustive switches are the table, wrapped in candidate-1's non-empty `ConflictingSettings`; raw preference values crossing the port so `conflicts(rawValue:)` is tested in core with the sourced integers; `activity` as a computed derivation over the two stored inputs instead of a stored value set in `reconcile`; the resign-key guard for the status-button click; the concrete package and project settings (tools 6.2, `platforms: .macOS(.v26)`, main-actor default isolation for the UI, Debug/Release xcconfigs, `test.sh`, draining IOKit's initial iterator).

**Rejected from candidate-2:** the corner-agnostic recognizer (it splits the anchor-corner rule between the recognizer and the hub; keeping hand mode as recognizer input costs one device restart per toggle and keeps R11 in one module); gating only at `fire` with devices always running (contradicts the domain model's "nothing is recognised" and spends CPU on touches that can never fire); writing the resolved URL back on fire (a second writer of settings for a millisecond); the seven-protocol split with `openURL`/`terminate` closures in the hub (shell actions carry no policy); a schema version field (unrequested). **Dropped from candidate-1:** fast-user-switching handling (no requirement asks for it; listed as an open question).

**Candidate-1 defects fixed in the re-derivation** (from the cross-judge and my own read): usage called `recognizer.run` which the sketch lacked (usage now folds over `step`); fixtures `.builtIn`/`.magicTrackpad` were passed where a `Trackpad`/`TrackpadID` was expected (named fixtures added); `run` released devices before clearing the registry (registry cleared first).

**Test-planner findings folded in (Phase C):** the recognizer could not pass its own ID-reuse script because a tracked contact reappearing with `.landing` never left `down` (lifts are now evaluated before landings, and a reused ID lifts and lands anew in one frame); `InMemoryTrackpads` could not go deaf, so the after-sleep scenario could not fail (`sleep()` added; `run` clears it); the "gesture already in flight when activity flips" guard had no driver (`inject(_:)` added); the register-before-save order was unobservable (`onRegisterLoginItem` hook added); R5 says the list refreshes "each time the picker opens" while the design refreshed it on window open (the picker now enumerates the catalog in `menuNeedsUpdate`; `openWindow()` and `start()` became synchronous, the `installedApps` property and the async enumeration were removed); R10's hint wording had no seam (`HandMode.cornerName`); a click on the landing frame was inexpressible (`TouchScript.tap(click:)`). Rejected: none.

### Tradeoffs accepted

- We accept a full device restart on every reconcile (preference change, hand-mode toggle, hot-plug, wake), dropping a tap in progress on those rare events, in exchange for one convergent operation with no stale-device detection and no special wake path.
- We accept a `Mutex` around each recognizer that is never contended, in exchange for proving single ownership to the compiler instead of `nonisolated(unsafe)`.
- We accept a large real hardware adapter checked only by hand (MultitouchSupport, IOKit, wake, actuators, classification), in exchange for one hardware port whose fake runs the real recognizer.
- We accept sampling button state on every frame while touching, in exchange for a recognizer that is a pure function of its input.
- We accept a synchronous enumeration of the three Applications folders on the main actor each time a picker's menu opens (user-initiated, tens of milliseconds), in exchange for R5's "each time the picker opens" being literally true, no cache to invalidate and no FSEvents watcher. If a cold disk makes the menu's open latency visible, make the enumeration cheaper (read only the bundle identifier and display name of each bundle) rather than cache it: any cache reintroduces the staleness R5 forbids.
- We accept that Other… closes the launcher window, runs `NSOpenPanel` with the app activated, then reopens the window, in exchange for not fighting window levels and resign-key dismissal while the chooser is up.
- We accept that resolved URLs are never written back (a moved app costs one LaunchServices lookup per fire), in exchange for settings that change only through user intent.
- We accept that first launch is derived from the absence of a settings record, so a user who deletes the app's preferences gets a first launch again, including the login item.
- We accept that rows are a disk snapshot refreshed on open and on each assignment; the fire path resolves fresh, so behaviour is never wrong.
- We accept that `openApplication`'s completion is ignored: the only reactions (a log line or a dialog) are both ruled out.

### Alternatives considered

- **Hop every frame to the main actor and recognize there.** No frame-thread `Mutex`, but it wakes the main thread ~100 times a second whenever a finger is on the trackpad, for no gain in depth; button state would still be sampled on the frame thread. Rejected on cost.
- **The adapter delivers raw frames and the core owns the recognizer map plus the hop.** The core would contain threading, and tests would wait on an async hop to observe both "nothing happened" and "something happened". Moving the hop into the adapter keeps the core synchronous and deterministic.
- **Devices always running, gated only at the fire path.** Simpler device lifecycle, but CPU is spent on frames that can never fire while *Tap to click* is on, and "nothing is recognised" would hold only in effect. Reconcile already runs on every input, so stopping the devices costs nothing extra.
- **A corner-agnostic recognizer that reports which top corner held the thumb, matched against hand mode in `fire`.** Removes the device restart on hand-mode toggle and the only cross-thread configuration, but splits R11's anchor-corner rule across two modules and adds a field to every event. Rejected for reader load.
- **One `Trackpads` port that also reports each trackpad's settings.** A slightly smaller core, but the built-in/external join (R14's subtle case) would move into an untested adapter. Keeping preferences as a separate port keyed by `TrackpadKind` keeps the join pure and table-tested.
- **`MenuBarExtra(.window)` or `NSPopover` as the shell.** The first cannot be opened or closed programmatically (R18, R3); the second adds an arrow and chrome the design does not have, with the same status-click wrinkle.
- **An injected `Clock` and a tap-timeout timer.** Conventional, but every lift is observed as a frame, so the frame timestamp is a sufficient clock, and a timer would be the app's only timer (R22).
- **Refreshing the picker's list when the window opens, enumerated off the main actor.** Keeps the view body free of disk work and the menu instant, but it contradicts R5's "each time the picker opens" for an app installed in the background while the window is open, and the first open would show an empty picker until the enumeration finished. Rejected: the requirement text wins, and `menuNeedsUpdate` is the one hook that runs exactly when a menu opens.

### Open questions and risks

- **Frame layout (Q1).** The MTTouch layout, state values, coordinate origin and callback thread are sourced, not probed. The first slice prints real frames through the adapter before anything is built on it; a correction is confined to `TouchFrame.init(parsing:)`. Is that acceptable as the slice-one gate?
- **Trackpad classification.** Does the IORegistry `Product` string reliably contain "Trackpad" for every Apple trackpad and never for a Magic Mouse or Touch Bar? Allowlist on "Trackpad" risks ignoring a future device; a denylist risks counting a mouse. Which risk do you prefer?
- **Device readiness after wake or hot-plug.** Is a device startable the moment `didWake` or IOKit first-match fires, and does `MTDeviceCreateList` already include a just-paired Magic Trackpad when first-match fires? If not, should `screensDidWake` be a second signal, or is one bounded retry (the app's only timer) acceptable?
- **Preference semantics.** `Clicking == 1` and `TrackpadThreeFingerTapGesture == 2` are sourced from community documentation; verify once by toggling System Settings in the activity slice. Does a USB-wired Magic Trackpad read the Bluetooth domain, or is Bluetooth-only acceptable for v1?
- **Feel constants.** 300 ms tap, 3 mm drag, 2 mm anchor release margin, 20% × 25% corner (25 × 19 mm on the probed MacBook, roughly 32 × 29 mm on a Magic Trackpad), actuation ID 6. Should these be tuned once on a 13" MacBook and a Magic Trackpad before they are frozen, and should the corner be fixed in millimetres instead of fractions?
- **Fast user switching.** The plan does not mention it. Should gestures stop while another user's session is on the console (so we never fire on, or pulse, their trackpad)? If yes, it is one more `.trackpadsChanged` source plus `connected() == []` while off console.
- **Window behaviour to confirm in E2E.** Is closing and reopening the window around Other… acceptable? Does the resign-key guard make an icon click while open close (not close-then-reopen)? Does the `NSPopUpButton` picker open correctly inside a non-activating panel, and is its open latency (the enumeration in `menuNeedsUpdate`) acceptable on a cold disk?
- **Signing.** No Developer ID Application certificate is installed; R23 cannot be verified until one is. Who provisions it? Is a login item registered by an Apple Development-signed debug build acceptable on the developer's machine?

### Next implementation step

Scaffold the `LauncherKit` package with `LauncherCore` (domain types, `GestureRules`, `GestureRecognizer`) and `SourcePolicyTests`, then drive the recognizer test-first through every R11 frame script; meanwhile run `mt-probe` with a real touch to confirm the frame layout the adapter will parse.

