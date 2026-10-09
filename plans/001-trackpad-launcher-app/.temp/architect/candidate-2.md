## Design

### Problem

Trackpad Launcher is a menu-bar-only macOS 26 app that turns four thumb-anchored taps into "bring this app to the front", with no permissions, no network, no logging and zero idle cost (R1–R23). Greenfield: no code, no architecture doc. What makes the shape non-obvious is that every input is a push from a different thread and framework, and all of it has to meet in one place: multitouch frames arrive on a MultitouchSupport-owned thread at ~100 Hz through a `@convention(c)` callback with no context pointer (grounding Q1); trackpad settings arrive by KVO on the main thread from two `cfprefsd` domains (Q4); device add/remove arrives on an IOKit dispatch queue and wake on the workspace notification center (Q5); the user's clicks arrive through AppKit. The grounding also fixes several constraints the design must honor: `MenuBarExtra` cannot open or close its window programmatically, so R18 and R3 force an `NSStatusItem` + `NSPanel` shell (Q8); `NSHapticFeedbackManager` cannot be aimed at a device, so R13 needs one `MTActuator` per trackpad (Q3); the frame layout is sourced, not probed, so the frame-to-domain parse must sit in exactly one adapter (Q1); the preference key semantics are sourced, so "which keys, which values, which notice text" must be one table (Q4); and there is no hot-plug symbol in MultitouchSupport, so the device set is re-listed, never incrementally patched (Q5). The design below has one main-actor hub that owns all policy, one pure recognizer that owns all gesture knowledge and runs on the frame thread, and six platform seams each with a real adapter and an in-memory adapter.

### Usage (caller's view)

**README (quickstart).** The app has one deep module, `TrackpadLauncher`, a `@MainActor @Observable` hub. The shell (status item, panel, SwiftUI views) reads four observable facts from it (`rows`, `handMode`, `activity`, `isWindowPresented`) and calls six verbs (`assign`, `unassign`, `installedApps`, `toggleWindow`/`dismissWindow`, `openTrackpadSettings`, `quit`). Everything else (recognition, device reconciliation, activity derivation, resolution, persistence, first-launch policy, the silent cases of feedback) happens behind that surface. You construct it with the six platform adapters; production passes the real ones, tests pass the in-memory ones. There is no timer, no clock and no background task anywhere: every change is pushed in by a frame, a KVO hit, an IOKit callback, a wake notification, or a click.

```swift
// App/AppDelegate.swift (the only place real adapters are named)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var launcher: TrackpadLauncher!
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ note: Notification) {
        launcher = TrackpadLauncher(
            trackpads: MultitouchSource.shared,                      // dlopen MultitouchSupport; frames + actuator
            deviceEvents: IOKitDeviceEventSource(),                  // IOKit first-match/terminated + NSWorkspace wake
            preferences: UserDefaultsTrackpadPreferenceSource(),     // KVO on the two trackpad domains
            apps: FileSystemAppCatalog(),                            // Bundle/FileManager/LaunchServices
            appLauncher: WorkspaceAppLauncher(),                     // NSWorkspace.openApplication(at:configuration:)
            settings: UserDefaultsSettingsStore(),                   // UserDefaults.standard, one Codable blob
            loginItem: SMAppServiceLoginItem(),                      // SMAppService.mainApp.register()
            openURL: { NSWorkspace.shared.open($0) },                            // R15 notice button opens System Settings > Trackpad
            terminate: { NSApplication.shared.terminate(nil) }
        )
        menuBar = MenuBarController(launcher: launcher)             // mirrors `activity` → icon, `isWindowPresented` → panel
        launcher.start()                                            // loads settings, first-launch policy, reconciles trackpads
    }
}
```

```swift
// App/Views/GestureRowView.swift (one gesture row: illustration + app picker)
struct GestureRowView: View {
    let row: GestureRow                     // launcher.rows[i]
    @Environment(TrackpadLauncher.self) private var launcher

    var body: some View {
        HStack {
            GestureIllustration(gesture: row.gesture, mirrored: launcher.handMode == .left)
            Spacer()
            Menu {
                ForEach(launcher.installedApps()) { app in      // enumerated when the menu opens (R5)
                    Button { launcher.assign(row.gesture, toAppAt: app.url) } label: { AppLabel(app) }
                }
                Divider()
                Button("Other…") { pickOther() }                // NSOpenPanel → launcher.assign(row.gesture, toAppAt:)
                Button("None") { launcher.unassign(row.gesture) }
            } label: {
                switch row.assignment {
                case .unassigned:               Text("Choose app…").foregroundStyle(.secondary)
                case .present(let name, let url): Label { Text(name) } icon: { AppIcon(url: url) }
                case .missing(let name):        Text("\(name)  not found").foregroundStyle(.tertiary)
                }
            }
        }
    }
}
```

```swift
// App/MenuBarController.swift (the shell never decides; it mirrors)
@MainActor
final class MenuBarController {
    init(launcher: TrackpadLauncher) {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked)
        panel.onDismissRequest = { launcher.dismissWindow() }        // click outside, Escape
        Task { for await shown in Observations { launcher.isWindowPresented } { shown ? panel.show(below: statusItem) : panel.orderOut(nil) } }
        Task { for await active in Observations { launcher.activity.isActive } { statusItem.button?.image = MenuBarIcon.image(active: active) } }
    }
    @objc private func iconClicked() { launcher.toggleWindow() }
}
```

```swift
// Tests/LauncherCoreTests/FeedbackTests.swift (every requirement scenario runs at this seam)
@Test func tapToClickOnIsSilent() {
    let world = TestWorld()                                          // in-memory adapters, one built-in trackpad, Figma installed
    world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
    let launcher = world.makeLauncher(); launcher.start()
    launcher.assign(.twoFingers, toAppAt: world.apps.url(of: "Figma"))
    world.trackpads.perform(.tap(fingers: 2, thumb: .topLeft))      // frame sequence through the real recognizer
    #expect(launcher.activity == .blocked(by: [.tapToClick]))
    #expect(world.appLauncher.launched.isEmpty)
    #expect(world.trackpads.pulses.isEmpty)
}

@Test func thumbLiftsBeforeFingersDoesNotFire() {
    var recognizer = TapRecognizer()
    let f = FrameScript(trackpad: .builtIn, surface: .macBook13)    // 124.8 × 76.8 mm, timestamps authored by the test
    #expect(recognizer.consume(f.land(.thumb, at: .mm(10, 10))) == nil)
    #expect(recognizer.consume(f.land(.finger(1), at: .center)) == nil)
    #expect(recognizer.consume(f.land(.finger(2), at: .center)) == nil)
    #expect(recognizer.consume(f.lift(.thumb)) == nil)
    #expect(recognizer.consume(f.lift(.finger(1), .finger(2))) == nil)
}
```

### Shape

**Data first.** Six domain types carry the whole app. `Gesture` is a four-case enum, so "five fingers" is unrepresentable and the recognizer's output cannot name a gesture that does not exist. `HandMode` is two cases with a derived `anchorCorner`; `AnchorCorner` is `topLeft | topRight`. `AppIdentity` is the stored assignment: a branded `BundleID`, the display name (kept so a missing app still has a name to grey out, R7) and a `lastKnownURL` hint; location is never identity. `Settings` is one `Codable` value (`handMode`, `assignments: [Gesture: AppIdentity]`, `hasLaunchedBefore`) persisted as one blob under one key, so "fresh install" is the absence of the blob and every write is atomic. `GestureActivity` is a sum: `active | noTrackpad | blocked(by: [ConflictingSetting])`, where `ConflictingSetting` is an enum whose cases are the table rows (key, conflicting raw value, notice name); adding Smart zoom is one new case and the compiler lists every switch to extend (per `encode-lessons-in-structure`, strongest mechanism available). `TouchFrame` is the recognizer's only input: a complete snapshot of the contacts on one trackpad plus the sampled button state and the device timestamp. There is no separate "touch ended" event; absence from the next frame is the lift, which is what makes stale recognizer state after sleep inert.

**Dominant access paths through those structures.** Frame to recognizer: keyed by `TrackpadID` in a `Mutex<[TrackpadID: TapRecognizer]>` owned by the frame thread (per `separate-before-serializing-shared-state`: the frame thread is the only writer; the main actor never touches it). Gesture to assignment: `settings.assignments[gesture]`, a four-entry dictionary. Rows for the window: derived from `settings` plus a `resolution` snapshot taken when the window opens (derive instead of sync). Activity: derived from `trackpads` (the connected set) and the latest `preferences` snapshot; the icon, the notice and the fire gate all read the one computed `activity` (single source of truth for R2/R14/R15).

**Flow.** `MultitouchSource` (frame thread) parses `MTTouch` into `TouchFrame`, samples `CGEventSource.buttonState`, and calls `GestureListener.ingest`. The listener runs the pure `TapRecognizer` for that trackpad under its mutex and, when a tap completes, hops once to the main actor with a `GestureEvent(trackpad, corner, gesture)`. `TrackpadLauncher.fire` is the one place that decides the silent cases (inactive, wrong corner for the hand mode, unassigned, missing) and otherwise closes the window, pulses the trackpad the event names, and brings the target app to the front. Everything else the hub does is a reaction to one of three pushes: `reconcileTrackpads()` (launch, IOKit add/remove, wake: one idempotent operation that restarts every device and replaces the connected set), `refreshPreferences()` (KVO), and window presentation (clicks, first launch, fire).

**Load-bearing decisions.**
- The recognizer is corner-agnostic: it reports which top corner the thumb was anchored in, and `fire` matches that against `handMode.anchorCorner`. Hand mode therefore never crosses a thread; the recognizer has zero configuration shared with the main actor.
- The recognizer's clock is the frame timestamp. Tap duration is measured between the landing frame and the lift frame, both of which always arrive (a final empty frame is delivered when the last contact lifts, Q1). No timer, no wall clock, no `Clock` protocol; a test authors the timestamps it wants. This is also how R22 is a mechanism, not a promise: the forbidden-API test bans timers.
- Gating happens at `fire`, not by stopping devices while inactive. Devices are started whenever present (free while idle, Q1) and recognition always runs; one guard chain in `fire` decides R13's three silent cases and R14's inactive case. One place, one test file.
- Device reconciliation is "restart everything": stop and release what was running, list afresh, register and start each, return the set. It converges from any prior state (launch, hot-plug, removal, wake all call the same method), per `make-operations-idempotent`.
- Validation lives at the adapters (per `boundary-discipline`): the frame parse, the preference raw ints, the bundle `Info.plist`, the settings blob. Inside, `Gesture`, `AppIdentity`, `TouchFrame` are trusted.

**Interface depth.** `TrackpadLauncher` exposes 4 observable facts and 8 methods and hides: the first-launch policy and login-item registration order, the device set lifecycle, the activity table and derivation, assignment resolution with the Trash filter and the fast path, the hand-mode/corner match, haptic targeting, window-closes-on-gesture, and persistence. `TapRecognizer` exposes one mutating function and hides the state machine, the geometry, the drag/click/duration spoilers and the staggered-landing count. `TrackpadSource` exposes `restartAll`, `pulse` and one frame callback and hides `dlopen`, the C callback registry, `MTTouch` layout, actuator caching. What stays exposed to callers: the `Gesture`/`HandMode`/`GestureActivity` vocabulary and `URL`s for apps, because the views render exactly those. Nothing framework-typed crosses the hub's surface: no `MTTouch`, no `CFTypeRef`, no `UserDefaults` key, no `NSRunningApplication`, no `NSImage` (the view derives icons from the resolved `URL`).

**What the design deliberately does not do.** No manual gesture on/off, no sound, no update checks (non-goals). No background `Task` loops. No per-key `UserDefaults` schema. No incremental device patching. No activity caching across launches: activity is recomputed at `start()` from the live inputs.

#### Module map

| Module | Isolation | Owns | Requirements |
|---|---|---|---|
| `LauncherCore` package target | | | |
| Domain types (`Gesture`, `HandMode`, `AnchorCorner`, `AppIdentity`, `Settings`, `Trackpad*`, `TouchFrame`, `GestureEvent`) | value, `Sendable` | vocabulary; invariants in types | R6, R9, R11 |
| `TapRecognizer` + `RecognizerTuning` | value, nonisolated | the gesture state machine and the fixed constants | R11 |
| `GestureListener` | `final class: Sendable`, frame thread | per-trackpad recognizer state behind a `Mutex`; the one hop to the main actor | R11, R16 |
| `ConflictingSetting` + `ActivityRule` | value, nonisolated | the settings table and the derivation | R2, R14, R15 |
| `AppResolution` | pure functions | pick-a-copy policy: fast path, Trash filter | R7 |
| `TrackpadLauncher` | `@MainActor @Observable` | all policy: start, reconcile, refresh, fire, assign, window presentation, quit | R3, R5–R10, R12–R19 |
| Adapter protocols (`TrackpadSource`, `DeviceEventSource`, `TrackpadPreferenceSource`, `AppCatalog`, `AppLauncher`, `SettingsStore`, `LoginItemRegistrar`) | protocols | the six seams (the catalog and the launcher share LaunchServices but vary independently) | all platform-facing R |
| `LauncherPlatform` package target | | | |
| `MultitouchSource` | `final class: Sendable`; callback on the MT thread | dlopen, device registry, frame parse, button sample, actuators | R11, R13, R16, R20, R22 |
| `IOKitDeviceEventSource` | nonisolated; IOKit queue + main | first-match/terminated + wake, each becoming one "changed" push on main | R16 |
| `UserDefaultsTrackpadPreferenceSource` | `NSObject`, main | KVO on both domains; raw ints per table key | R2, R14, R15 |
| `FileSystemAppCatalog` | main | bundle parse, three-folder enumeration + Finder, LaunchServices lookup | R5, R7 |
| `WorkspaceAppLauncher` | main | `openApplication(at:configuration:)` with `activates` | R12 |
| `UserDefaultsSettingsStore` | main | one Codable blob | R8, R18 |
| `SMAppServiceLoginItem` | main | `register()` | R17, R19 |
| `TrackpadLauncherApp` xcodegen target | `@MainActor` default isolation | thin shell | |
| `AppDelegate`, `MenuBarController`, `LauncherPanel`, `MenuBarIcon` | main | status item, panel, dismissal mechanics, icon drawing | R1, R2, R3, R18, R19 |
| `LauncherWindowView`, `GestureRowView`, `HintOrNoticeView`, `HandModeToggle` | main | layout per design, Liquid Glass, mirrored illustrations, notice | R4, R5, R6, R7, R9, R10, R15 |
| Tests | | | |
| `LauncherCoreTests`, with the in-memory adapters `InMemoryTrackpadSource`, `InMemoryDeviceEvents`, `InMemoryPreferences`, `InMemoryAppCatalog`, `RecordingAppLauncher`, `InMemorySettingsStore`, `RecordingLoginItem`, plus `FrameScript` and `TestWorld` | | every R11/R13/R14/R15/R7/R8/R17/R18 scenario at the `TrackpadLauncher` or `TapRecognizer` seam; `ForbiddenAPIRule` source scan | R11–R22 |
| `LauncherPlatformTests` | | real adapters against throwaway resources: a defaults suite, temp bundles, KVO on a throwaway key | R5, R7, R8, R14 |

#### Type sketch: domain

```swift
// LauncherCore — Domain.swift
// Everything here is a value, Sendable, framework-free.

/// The four launcher gestures. Finger count is the case; five fingers cannot be expressed.
public enum Gesture: Int, CaseIterable, Codable, Hashable, Sendable {
    case oneFinger = 1, twoFingers, threeFingers, fourFingers
    public var fingerCount: Int { rawValue }
    /// nil for 0 or > 4; the recognizer turns a count into a gesture or a spoil through this.
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
}

public enum HandMode: String, Codable, Sendable {
    case right, left
    public var anchorCorner: AnchorCorner { self == .right ? .topLeft : .topRight }
}

public enum AnchorCorner: Hashable, Sendable {
    case topLeft, topRight
    public var hintWord: String { self == .topLeft ? "top-left" : "top-right" }
}

/// Identity of an app, never its location. `lastKnownURL` is a hint for the resolver's fast path.
public struct BundleID: Hashable, Codable, Sendable, RawRepresentable { public let rawValue: String }

public struct AppIdentity: Hashable, Codable, Sendable {
    public let bundleID: BundleID
    public let name: String          // display name without ".app", so a missing app still has a name (R7)
    public var lastKnownURL: URL
}

/// What persists (R8). One blob, one key. Absence of the blob == fresh install.
public struct Settings: Codable, Equatable, Sendable {
    public static let currentSchema = 1
    public var schemaVersion = Settings.currentSchema
    public var handMode: HandMode = .right                       // R9 default
    public var assignments: [Gesture: AppIdentity] = [:]         // R6: all unassigned on fresh install
    public var hasLaunchedBefore = false                         // R17/R18 gate
    public static let fresh = Settings()
}

/// A connected trackpad, as the hub sees it.
public struct TrackpadID: Hashable, Sendable { public let rawValue: UInt64 }   // MTDeviceGetDeviceID == IORegistry "Multitouch ID"
public enum TrackpadKind: Hashable, Sendable, CaseIterable { case builtIn, external }
public struct SurfaceSize: Equatable, Sendable { public let widthMM: Double; public let heightMM: Double }
public struct Trackpad: Hashable, Sendable {
    public let id: TrackpadID
    public let kind: TrackpadKind
    public let surface: SurfaceSize
}

/// One contact in one frame. Parsed at the multitouch adapter; the recognizer trusts it.
public struct Touch: Equatable, Sendable {
    public struct ID: Hashable, Sendable { public let rawValue: Int32 }
    public enum Phase: Equatable, Sendable {
        case landing     // MT state 3 (MakeTouch): a fresh contact, even if the ID was reused
        case down        // MT state 4 (Touching)
        case notDown     // every other MT state: hover, break, linger, out of range
    }
    public let id: ID
    public let phase: Phase
    public let normalized: SIMD2<Float>   // 0...1, origin bottom-left (Q1): top-left corner is x < 0.2, y > 0.75
    public let millimetres: SIMD2<Float>  // absolute position in mm, same origin; for the drag threshold
    public var isDown: Bool { phase != .notDown }
}

/// The recognizer's only input: a complete snapshot of one trackpad at one instant.
/// Invariant: a contact absent from a frame has lifted. There is no other "touch ended" path.
public struct TouchFrame: Equatable, Sendable {
    public let trackpad: TrackpadID
    public let surface: SurfaceSize
    public let timestamp: TimeInterval      // device clock, seconds; the recognizer's only notion of time
    public let anyButtonDown: Bool          // CGEventSource.buttonState sampled on the frame thread (Q2)
    public let touches: [Touch]
}

/// What the recognizer emits: which trackpad, which top corner held the thumb, which gesture.
/// The hub matches `corner` against the hand mode; the recognizer never knows the hand mode.
public struct GestureEvent: Equatable, Sendable {
    public let trackpad: TrackpadID
    public let corner: AnchorCorner
    public let gesture: Gesture
}

/// Whether gestures fire, and why not (R2, R14, R15).
public enum GestureActivity: Equatable, Sendable {
    case active
    case noTrackpad
    case blocked(by: [ConflictingSetting])   // table order; produced only by ActivityRule, never empty
    public var isActive: Bool { self == .active }
}

/// A gesture row as the window renders it (R5–R7). `present` carries the URL so the view can ask the
/// workspace for the icon; the core never holds an NSImage.
public struct GestureRow: Identifiable, Equatable, Sendable {
    public var id: Gesture { gesture }
    public let gesture: Gesture
    public let assignment: ResolvedAssignment
}
public enum ResolvedAssignment: Equatable, Sendable {
    case unassigned
    case present(name: String, url: URL)
    case missing(name: String)
}

/// An entry in the app picker (R5). Finder is always included by the catalog.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let name: String
    public let url: URL
}
```

#### Type sketch: recognition (pure, frame thread)

```swift
// LauncherCore — TapRecognizer.swift

/// Every fixed number the recognizer uses (non-goal: none is user-tunable). One place to retune.
public enum RecognizerTuning {
    /// Anchor corner: the leftmost (or rightmost) fraction of the width and the topmost fraction of the height.
    /// On the probed 124.8 × 76.8 mm surface this is 25.0 × 19.2 mm: 1 cm in is inside, 4 cm in is outside (R11).
    public static let cornerWidthFraction: Float = 0.20
    public static let cornerHeightFraction: Float = 0.25
    /// A tap finger that travels further than this from where it landed is a drag, not a tap.
    public static let dragThresholdMM: Float = 4.0
    /// From the first tap finger landing to the last lifting; longer is a rest or a hold, not a tap.
    public static let maxTapDuration: TimeInterval = 0.35
}

/// One trackpad's gesture state machine. A value: tests copy it, the listener keeps one per trackpad.
/// Input: complete frames. Output: at most one event per frame, on the frame in which the last tap finger lifts.
/// Hand mode is not an input: the thumb may anchor in either top corner and the event says which.
public struct TapRecognizer: Equatable, Sendable {
    public init() {}

    /// Feed the next frame. Returns the gesture that completed on this frame, if any.
    public mutating func consume(_ frame: TouchFrame) -> GestureEvent? {
        // Pseudocode. Each step reads the whole snapshot; nothing is inferred from a missing event.
        //
        // down   = frame.touches.filter(\.isDown) keyed by id
        // landed = touches with phase == .landing, or down but not in `previouslyDown` (ID reuse is covered by .landing)
        //
        // switch state {
        // case .idle:
        //   if let thumb = landed.first(where: { corner(of: $0) != nil })  → state = .armed(thumb.id, corner, since: now)
        //   // contacts already down when the thumb lands are not tap fingers: "fingers before thumb" never fires
        //
        // case .armed(thumb, corner):
        //   guard down[thumb] exists, corner(of: down[thumb]) == corner else { state = .idle; break }   // lifted or slid out
        //   let fingers = landed.filter { $0.id != thumb }
        //   if !fingers.isEmpty → state = .tapping(thumb, corner, fingers: [id: landingMM], peak: fingers.count, startedAt: now)
        //
        // case .tapping(thumb, corner, fingers, peak, startedAt):
        //   guard down[thumb] exists, corner(of: down[thumb]) == corner else { state = .idle; break }   // "thumb lifts before fingers": void, not spoiled
        //   if frame.anyButtonDown                                  → state = .spoiled(thumb, corner)   // "click is not a tap"
        //   if now - startedAt > maxTapDuration                     → spoiled                             // a hold
        //   if any tracked finger moved > dragThresholdMM from landing → spoiled                          // "drag is not a tap"
        //   add newly landed non-thumb touches to fingers; peak = max(peak, fingers ∩ down count)
        //   if peak > 4                                             → spoiled                             // "five fingers"
        //   if fingers ∩ down is empty (all lifted; thumb still down):
        //       state = .armed(thumb, corner); return GestureEvent(frame.trackpad, corner, Gesture(fingerCount: peak)!)
        //       // staggered lifts: fires once, on the frame the last finger lifts; peak counts the staggered landings
        //
        // case .spoiled(thumb, corner):
        //   guard down[thumb] exists, corner(of: down[thumb]) == corner else { state = .idle; break }
        //   if every non-thumb contact is up                        → state = .armed(thumb, corner)      // wait for a clean slate
        // }
        // previouslyDown = Set(down.keys)
        fatalError("not implemented")
    }

    // MARK: internals (also the test surface for geometry)

    /// Which top corner a contact is in, if any. Normalized coordinates, origin bottom-left (Q1).
    static func corner(of touch: Touch) -> AnchorCorner? {
        // y > 1 - cornerHeightFraction && (x < cornerWidthFraction → .topLeft | x > 1 - cornerWidthFraction → .topRight)
        fatalError("not implemented")
    }

    private enum State: Equatable, Sendable {
        case idle
        case armed(thumb: Touch.ID, corner: AnchorCorner)
        case tapping(thumb: Touch.ID, corner: AnchorCorner, fingers: [Touch.ID: SIMD2<Float>], peak: Int, startedAt: TimeInterval)
        case spoiled(thumb: Touch.ID, corner: AnchorCorner)
    }
    private var state: State = .idle
    private var previouslyDown: Set<Touch.ID> = []
}
```

```swift
// LauncherCore — GestureListener.swift
import Synchronization

/// Owns one TapRecognizer per trackpad and is the only writer of that state (the frame thread).
/// Sendable by construction: the dictionary lives behind a Mutex; the callback is @Sendable.
/// Stale entries for trackpads that went away are inert: the next frame for that ID is a complete snapshot.
public final class GestureListener: Sendable {
    private let recognizers = Mutex<[TrackpadID: TapRecognizer]>([:])
    private let onGesture: @Sendable (GestureEvent) -> Void

    /// `onGesture` is called on the frame thread, outside the lock; the hub's wiring hops to the main actor.
    public init(onGesture: @escaping @Sendable (GestureEvent) -> Void) { self.onGesture = onGesture }

    /// The TrackpadSource's frame callback. Called on the source's thread, ~100 Hz while touched, never while idle.
    public func ingest(_ frame: TouchFrame) {
        // let event = recognizers.withLock { $0[frame.trackpad, default: TapRecognizer()].consume(frame) }
        // if let event { onGesture(event) }
        fatalError("not implemented")
    }
}
```

#### Type sketch: gestures active/inactive (table-driven, pure)

```swift
// LauncherCore — TrackpadSettings.swift

/// The system actions that are bound to a tap rather than a click (R14). This enum IS the table:
/// every row supplies its defaults key, its conflicting value and its notice text, and the compiler
/// refuses a new case (Smart zoom) until all three switches are extended. Values are sourced (Q4),
/// so a correction is one line here.
public enum ConflictingSetting: CaseIterable, Hashable, Sendable {
    case tapToClick
    case lookUpThreeFingerTap
    // case smartZoom   // add if testing shows a two-finger double tap fires with a thumb anchored (R14)

    /// Key within each trackpad preference domain.
    public var defaultsKey: String {
        switch self {
        case .tapToClick:            "Clicking"
        case .lookUpThreeFingerTap:  "TrackpadThreeFingerTapGesture"
        }
    }
    /// True when the raw value means the action is bound to a tap. nil (key absent) is "off".
    public func conflicts(rawValue: Int?) -> Bool {
        switch self {
        case .tapToClick:            rawValue == 1
        case .lookUpThreeFingerTap:  rawValue == 2
        }
    }
    /// Exactly the words R15 requires in the notice.
    public var noticeName: String {
        switch self {
        case .tapToClick:            "Tap to click"
        case .lookUpThreeFingerTap:  "Look up: Tap with three fingers"
        }
    }
}

/// Where macOS keeps those settings, per trackpad kind (Q4). The preference adapter is the only reader.
public enum TrackpadSettingsLocation {
    public static func domain(for kind: TrackpadKind) -> String {
        switch kind {
        case .builtIn:   "com.apple.AppleMultitouchTrackpad"
        case .external:  "com.apple.driver.AppleBluetoothMultitouch.trackpad"
        }
    }
    public static let settingsPane = URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")!
}

/// Raw values as read from one domain. Absent keys are absent entries.
public typealias TrackpadPreferenceValues = [ConflictingSetting: Int]

/// The derivation (R2, R14, R15). Pure; every scenario is one call.
public enum ActivityRule {
    /// - connected: kinds of the connected trackpads (empty → .noTrackpad)
    /// - values: the latest raw values per kind (the adapter reads both domains regardless of what is connected)
    /// Returns .blocked(by:) listing, in table order, every setting that conflicts on any connected kind.
    public static func derive(connected: Set<TrackpadKind>, values: [TrackpadKind: TrackpadPreferenceValues]) -> GestureActivity {
        // guard !connected.isEmpty else { return .noTrackpad }
        // let blocking = ConflictingSetting.allCases.filter { s in connected.contains { kind in s.conflicts(rawValue: values[kind]?[s]) } }
        // return blocking.isEmpty ? .active : .blocked(by: blocking)
        fatalError("not implemented")
    }
}
```

#### Type sketch: assignment resolution (pure policy) and the six seams

```swift
// LauncherCore — AppResolution.swift

/// Picks the copy of an app to use, or none (R7). Pure: the catalog supplies the facts, this owns the policy.
public enum AppResolution {
    /// - lastKnown: the stored hint; wins when it still holds the same bundle ID (fast path; also covers
    ///   apps picked from unregistered places such as the Downloads folder).
    /// - registered: every copy LaunchServices knows for the bundle ID, in its order.
    /// - identityAt: reads the bundle ID at a URL (nil if not a bundle); injected so tests use temp bundles.
    /// Copies under any `.Trash` or `.Trashes` path component are never chosen, whatever LaunchServices says.
    public static func locate(_ app: AppIdentity, registered: [URL], identityAt: (URL) -> BundleID?) -> URL? {
        // if identityAt(app.lastKnownURL) == app.bundleID && !isTrashed(app.lastKnownURL) { return app.lastKnownURL }
        // return registered.first { !isTrashed($0) && identityAt($0) == app.bundleID }
        fatalError("not implemented")
    }
    static func isTrashed(_ url: URL) -> Bool { url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" } }
}
```

```swift
// LauncherCore — Seams.swift
// One protocol per thing that varies between production and test. Each has exactly two adapters:
// the real one in LauncherPlatform and the in-memory one in LauncherCoreTests.
// The threading contract is part of each interface and is stated on it.

/// MultitouchSupport behind a domain surface. Sendable: `restartAll`/`pulse` are called on the main actor,
/// the frame callback runs on the framework's thread.
public protocol TrackpadSource: AnyObject, Sendable {
    /// Install the one frame consumer. Called once, before the first `restartAll`.
    func setFrameHandler(_ handler: @escaping @Sendable (TouchFrame) -> Void)
    /// The idempotent reconcile primitive (R16): stop and release every running device, list afresh,
    /// register the frame callback and start each, return the connected set. Safe to call at any time,
    /// any number of times; a device mid-touch loses that touch.
    func restartAll() -> [Trackpad]
    /// One haptic pulse on exactly that trackpad (R13). No-op if the trackpad is gone.
    func pulse(_ trackpad: TrackpadID)
    /// Stop everything (quit).
    func stopAll()
}

/// "The trackpad set may have changed." No payload: the hub re-lists anyway.
public protocol DeviceEventSource: AnyObject {
    /// `onChange` is invoked on the main actor for IOKit first-match, IOKit terminated, and workspace wake.
    func observe(_ onChange: @escaping @MainActor () -> Void)
}

/// The two trackpad preference domains (Q4). Main actor only.
public protocol TrackpadPreferenceSource: AnyObject {
    /// Current raw values of every table key, for both kinds, read fresh (cheap, probed).
    func current() -> [TrackpadKind: TrackpadPreferenceValues]
    /// `onChange` is invoked on the main actor whenever any table key changes in either domain (KVO push).
    func observe(_ onChange: @escaping @MainActor () -> Void)
}

/// Apps on disk (R5, R7). Main actor only.
public protocol AppCatalog: AnyObject {
    /// Parse a bundle at a URL into an identity (bundle ID + display name). nil if it is not an app bundle.
    func identity(ofAppAt url: URL) -> AppIdentity?
    /// The system and user Applications folders (with subfolders such as Utilities) plus Finder; sorted by name.
    /// Enumerates on every call (R5 "each time the picker opens").
    func installedApps() -> [InstalledApp]
    /// Every copy LaunchServices registers for the bundle ID. The resolver filters it.
    func registeredURLs(for bundleID: BundleID) -> [URL]
}

/// Bring to front (R12). Main actor only. Fire-and-forget; the probed call is idempotent under a double tap.
public protocol AppLauncher: AnyObject {
    func bringToFront(appAt url: URL)
}

/// Settings persistence (R8). Main actor only.
public protocol SettingsStore: AnyObject {
    /// nil on a fresh install or an unreadable blob (treated as fresh; the blob is rewritten on the next save).
    func load() -> Settings?
    func save(_ settings: Settings)
}

/// Login item (R17). Main actor only.
public protocol LoginItemRegistrar: AnyObject {
    /// Idempotent. Only ever called on first launch, so a user who turned it off is never re-enrolled.
    func register()
}
```

#### Type sketch: the hub

```swift
// LauncherCore — TrackpadLauncher.swift
import Observation

/// The one deep module. Owns every decision; the shell mirrors it.
/// Invariants: `activity` is derived, never stored; `rows` derive from `settings` + `resolution`;
/// `fire` is the only path that pulses, launches, or closes the window from a gesture;
/// every stored field has exactly one writer: this actor.
@MainActor @Observable
public final class TrackpadLauncher {

    // MARK: Observable facts (the view model is the model)

    public private(set) var rows: [GestureRow] = Gesture.allCases.map { GestureRow(gesture: $0, assignment: .unassigned) }
    public var handMode: HandMode {                       // R9; the view binds the toggle to this
        get { settings.handMode }
        set { settings.handMode = newValue; store.save(settings) }
    }
    public var activity: GestureActivity {                // R2, R14, R15: one derivation, every reader
        ActivityRule.derive(connected: Set(connected.map(\.kind)), values: preferenceValues)
    }
    public private(set) var isWindowPresented = false     // R3, R18: the shell shows/hides the panel to match

    // MARK: Verbs

    /// Call once after construction. Loads settings, applies the first-launch policy (R17, R18),
    /// subscribes to the pushes, reconciles the trackpad set. Idempotent: a second call re-reconciles.
    public func start() {
        // settings = store.load() ?? .fresh
        // if !settings.hasLaunchedBefore {
        //     settings.hasLaunchedBefore = true; store.save(settings)   // save first: a crash here must never re-enroll later (R17)
        //     loginItem.register()
        //     presentWindow()
        // }
        // preferences.observe { [weak self] in self?.refreshPreferences() }
        // deviceEvents.observe { [weak self] in self?.reconcileTrackpads() }
        // refreshPreferences(); reconcileTrackpads()
        fatalError("not implemented")
    }

    /// Assign a gesture to the app bundle at `url` (picker entry or Other…). The URL is parsed at this boundary.
    public func assign(_ gesture: Gesture, toAppAt url: URL) throws(AssignError) {
        // guard let identity = apps.identity(ofAppAt: url) else { throw .notAnApplication(url) }
        // settings.assignments[gesture] = identity; store.save(settings)
        // resolution[gesture] = url; rebuildRows()      // present by construction; the same app on two gestures is fine (R5)
        fatalError("not implemented")
    }
    public func unassign(_ gesture: Gesture) { /* settings.assignments[gesture] = nil; store.save(settings); resolution[gesture] = nil; rebuildRows() */ }

    /// The picker list, enumerated now (R5).
    public func installedApps() -> [InstalledApp] { apps.installedApps() }

    public func toggleWindow()  { isWindowPresented ? dismissWindow() : presentWindow() }
    public func dismissWindow() { isWindowPresented = false }
    public func presentWindow() {
        // resolution = resolveAll(); rebuildRows()       // R7: not-found and recovery are re-evaluated on open
        // isWindowPresented = true
    }

    public func openTrackpadSettings() { openURL(TrackpadSettingsLocation.settingsPane) }   // R15 button
    public func quit() { source.stopAll(); terminate() }                                     // R19; never touches the login item

    // MARK: Pushes (private; each is the single handler for its source)

    /// R16: one idempotent operation for launch, IOKit add, IOKit remove and wake.
    private func reconcileTrackpads() { /* connected = source.restartAll() */ }             // activity re-derives

    /// R14 live update: re-read both domains; activity re-derives.
    private func refreshPreferences() { /* preferenceValues = preferences.current() */ }

    /// The fire path (R3, R9, R12, R13). Every silent case is decided here and nowhere else.
    private func fire(_ event: GestureEvent) {
        // guard activity.isActive else { return }                                    // R14: inactive → silent
        // guard event.corner == settings.handMode.anchorCorner else { return }        // R9: thumb in the other corner
        // guard let app = settings.assignments[event.gesture] else { return }        // R13: unassigned → silent
        // guard let url = locate(app) else { return }                                 // R13: missing → silent
        // if url != app.lastKnownURL { settings.assignments[event.gesture]?.lastKnownURL = url; store.save(settings) }  // R7 moved app
        // isWindowPresented = false                                                   // R3: gesture closes the window
        // source.pulse(event.trackpad)                                                // R13: the trackpad it was performed on
        // appLauncher.bringToFront(appAt: url)                                        // R12
    }

    // MARK: Derivations

    private func locate(_ app: AppIdentity) -> URL? {
        AppResolution.locate(app, registered: apps.registeredURLs(for: app.bundleID), identityAt: { apps.identity(ofAppAt: $0)?.bundleID })
    }
    private func resolveAll() -> [Gesture: URL] { /* settings.assignments.compactMapValues(locate) */ fatalError("not implemented") }
    private func rebuildRows() {
        // rows = Gesture.allCases.map { g in
        //   GestureRow(gesture: g, assignment: settings.assignments[g].map { app in
        //       resolution[g].map { .present(name: app.name, url: $0) } ?? .missing(name: app.name) } ?? .unassigned) }
    }

    // MARK: State

    private var settings: Settings = .fresh
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    private var resolution: [Gesture: URL] = [:]      // snapshot taken on presentWindow() and on assign()

    // MARK: Wiring

    private let source: any TrackpadSource
    private let deviceEvents: any DeviceEventSource
    private let preferences: any TrackpadPreferenceSource
    private let apps: any AppCatalog
    private let appLauncher: any AppLauncher
    private let store: any SettingsStore
    private let loginItem: any LoginItemRegistrar
    private let openURL: @MainActor (URL) -> Void
    private let terminate: @MainActor () -> Void
    private var listener: GestureListener!

    public init(trackpads source: any TrackpadSource, deviceEvents: any DeviceEventSource, preferences: any TrackpadPreferenceSource,
                apps: any AppCatalog, appLauncher: any AppLauncher, settings store: any SettingsStore, loginItem: any LoginItemRegistrar,
                openURL: @escaping @MainActor (URL) -> Void, terminate: @escaping @MainActor () -> Void) {
        // store the fields
        // listener = GestureListener { [weak self] event in Task { @MainActor in self?.fire(event) } }   // the one hop, frame thread → main
        // source.setFrameHandler(listener.ingest)
        fatalError("not implemented")
    }
}

public enum AssignError: Error, Equatable { case notAnApplication(URL) }
```

#### Type sketch: real adapters (LauncherPlatform)

```swift
// LauncherPlatform — MultitouchSource.swift
import Synchronization
import CoreGraphics

/// The MultitouchSupport adapter. The only file that knows MTTouch's layout, the C callback, or the actuator.
/// One process-wide instance: the C callback has no context pointer, so it finds its device entry here.
public final class MultitouchSource: TrackpadSource, Sendable {
    public static let shared = MultitouchSource()

    /// Frames are parsed and delivered on the MultitouchSupport thread; ~100 Hz while touched, silent otherwise (Q1).
    public func setFrameHandler(_ handler: @escaping @Sendable (TouchFrame) -> Void) { state.withLock { $0.onFrame = handler } }

    public func restartAll() -> [Trackpad] {
        // state.withLock { s in
        //   for entry in s.devices.values { MTUnregisterContactFrameCallback(entry.ref, Self.frameCallback); MTDeviceStop(entry.ref); close actuator; MTDeviceRelease(entry.ref) }
        //   s.devices = [:]
        //   for ref in MTDeviceCreateList() {
        //     let trackpad = Trackpad(id: MTDeviceGetDeviceID, kind: MTDeviceIsBuiltIn ? .builtIn : .external, surface: MTDeviceGetSensorSurfaceDimensions / 100)
        //     MTRegisterContactFrameCallback(ref, Self.frameCallback); MTDeviceStart(ref, 0)
        //     s.devices[key(ref)] = DeviceEntry(ref: ref, trackpad: trackpad, actuator: nil)
        //   }
        //   return s.devices.values.map(\.trackpad)
        // }
        fatalError("not implemented")
    }

    public func pulse(_ trackpad: TrackpadID) {
        // entry = state.withLock { lookup by trackpad id; create+open actuator lazily via MTActuatorCreateFromDeviceID(id.rawValue) }
        // MTActuatorActuate(actuator, Self.pulseStrength, 0, 0, 0)
    }
    public func stopAll() { /* same as the first half of restartAll */ }

    /// Actuation ID (sourced: 3 weak, 4 medium, 6 strong, 15, 16). A feel decision; one constant.
    static let pulseStrength: Int32 = 6

    // MARK: Frame thread

    /// `@convention(c)`: no captures. Looks the device up by its ref, parses, samples the button, delivers.
    private static let frameCallback: MTContactCallback = { deviceRef, rawTouches, count, timestamp, _ in
        // guard let (trackpad, onFrame) = shared.state.withLock({ s in s.devices[key(deviceRef)].map { ($0.trackpad, s.onFrame) } }) else { return 0 }
        // let touches = (0..<count).map { parse(rawTouches[$0]) }               // MTTouch → Touch: state 3 → .landing, 4 → .down, else .notDown
        // let frame = TouchFrame(trackpad: trackpad.id, surface: trackpad.surface, timestamp: timestamp,
        //                        anyButtonDown: shared.buttonState(), touches: touches)
        // onFrame?(frame); return 0
        fatalError("not implemented")
    }

    /// The button sampler (Q2). Injectable so a platform test can pin it; production samples left, right and center.
    private let buttonState: @Sendable () -> Bool
    init(buttonState: @escaping @Sendable () -> Bool = {
        CGEventSource.buttonState(.combinedSessionState, button: .left) ||
        CGEventSource.buttonState(.combinedSessionState, button: .right) ||
        CGEventSource.buttonState(.combinedSessionState, button: .center)
    }) { self.buttonState = buttonState /* dlopen + dlsym every symbol once; a missing symbol is a startup failure, not a runtime one */ }

    private struct DeviceEntry { var ref: UnsafeMutableRawPointer; var trackpad: Trackpad; var actuator: CFTypeRef? }
    private struct State { var devices: [Int: DeviceEntry] = [:]; var onFrame: (@Sendable (TouchFrame) -> Void)? }   // keyed by Int(bitPattern: ref)
    private let state = Mutex(State())
    // + the dlsym'd function pointers as `let`s (typealiases mirror probes/mt-probe/main.swift; MTTouch is a private struct here)
}
```

```swift
// LauncherPlatform — IOKitDeviceEventSource.swift
import IOKit

/// Collapses IOKit first-match, IOKit terminated (class "AppleMultitouchDevice") and NSWorkspace.didWakeNotification
/// into one main-actor "changed" push. IOKit callbacks arrive on a private dispatch queue and hop with
/// `Task { @MainActor in onChange() }`; the wake notification is observed on `.main` and uses `MainActor.assumeIsolated`.
public final class IOKitDeviceEventSource: DeviceEventSource {
    public func observe(_ onChange: @escaping @MainActor () -> Void) { fatalError("not implemented") }
    // IONotificationPortCreate + IONotificationPortSetDispatchQueue; two IOServiceAddMatchingNotification registrations;
    // the initial iterator is drained (that first callback is a harmless extra reconcile). No polling.
}
```

```swift
// LauncherPlatform — UserDefaultsTrackpadPreferenceSource.swift

/// KVO on `UserDefaults(suiteName:)` for both domains in TrackpadSettingsLocation, one observer per table key.
/// KVO fires on the main thread when cfprefsd sees a write from System Settings (probed, Q4); `observeValue`
/// wraps in `MainActor.assumeIsolated`. `current()` reads `object(forKey:)` as Int?.
public final class UserDefaultsTrackpadPreferenceSource: NSObject, TrackpadPreferenceSource {
    public func current() -> [TrackpadKind: TrackpadPreferenceValues] { fatalError("not implemented") }
    public func observe(_ onChange: @escaping @MainActor () -> Void) { fatalError("not implemented") }
}
```

```swift
// LauncherPlatform — FileSystemAppCatalog.swift
import AppKit

/// Bundle parsing, folder enumeration and LaunchServices lookup. Roots and the registry are injected so
/// LauncherPlatformTests run it against a temp directory of fake bundles and a canned registry.
public final class FileSystemAppCatalog: AppCatalog {
    public init(roots: [URL] = FileSystemAppCatalog.defaultRoots,
                finder: URL = FileSystemAppCatalog.finderURL,
                registry: @escaping (BundleID) -> [URL] = { NSWorkspace.shared.urlsForApplications(withBundleIdentifier: $0.rawValue) })
    /// `FileManager.urls(for: .applicationDirectory, in: [.localDomainMask, .systemDomainMask, .userDomainMask])`
    public static let defaultRoots: [URL] = []            // not implemented
    public static let finderURL = URL(fileURLWithPath: "/" + "System/Library/CoreServices/Finder.app")

    public func identity(ofAppAt url: URL) -> AppIdentity? {
        // Bundle(url:)?.bundleIdentifier → BundleID; FileManager.displayName(atPath:) → name; url → lastKnownURL
        fatalError("not implemented")
    }
    public func installedApps() -> [InstalledApp] {
        // enumerator(at: root, options: [.skipsPackageDescendants, .skipsHiddenFiles]) over each root, keep ".app" with a bundle ID,
        // add Finder, sort by name (localizedStandardCompare), de-duplicate by URL
        fatalError("not implemented")
    }
    public func registeredURLs(for bundleID: BundleID) -> [URL] { registry(bundleID) }
}
```

```swift
// LauncherPlatform — WorkspaceAppLauncher.swift, UserDefaultsSettingsStore.swift, SMAppServiceLoginItem.swift
import AppKit
import ServiceManagement

/// R12 via the probed call: Dock-click semantics from a non-active process, idempotent under a double tap (Q6).
public final class WorkspaceAppLauncher: AppLauncher {
    public func bringToFront(appAt url: URL) {
        // let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true   // createsNewApplicationInstance stays false
        // NSWorkspace.shared.openApplication(at: url, configuration: cfg)   // completion ignored: there is nothing to do with an error and nothing to log
    }
}

/// One JSON blob under one key in `UserDefaults.standard` (R8). The suite is injectable for tests.
public final class UserDefaultsSettingsStore: SettingsStore {
    public init(defaults: UserDefaults = .standard, key: String = "settings")
    public func load() -> Settings? { /* data(forKey:) → JSONDecoder; nil on absence or decode failure */ fatalError("not implemented") }
    public func save(_ settings: Settings) { /* JSONEncoder → set(_:forKey:) */ }
}

/// `SMAppService.mainApp.register()` (R17). Requires a signed binary (Q9); errors are swallowed: there is no UI for them and no log.
public final class SMAppServiceLoginItem: LoginItemRegistrar {
    public func register() { /* try? SMAppService.mainApp.register() */ }
}
```

#### Type sketch: the shell (TrackpadLauncherApp target, default isolation MainActor)

```swift
// App/MenuBarController.swift
import AppKit
import Observation

/// Status item + panel. Mirrors two hub facts; forwards three user intents. No policy lives here.
/// Mechanisms (R3):
/// - icon click → `launcher.toggleWindow()` (button target/action; Return also fires it under keyboard navigation)
/// - click outside → the panel resigns key (`NSWindow.didResignKeyNotification`) → `launcher.dismissWindow()`,
///   except when the current event is the mouse-down on our own status button, which the action above handles
///   (otherwise the same click would close and reopen)
/// - Escape → `LauncherPanel.cancelOperation(_:)` → `launcher.dismissWindow()`
/// - gesture fires → the hub sets `isWindowPresented = false` → the mirror orders the panel out
/// - first launch → the hub sets `isWindowPresented = true` in `start()` → the mirror shows the panel
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel: LauncherPanel
    private let launcher: TrackpadLauncher

    init(launcher: TrackpadLauncher) {
        // panel = LauncherPanel(rootView: LauncherWindowView().environment(launcher))
        // statusItem.button: image = MenuBarIcon.image(active: launcher.activity.isActive), target/action = iconClicked
        // panel.onDismissRequest = { [launcher] in launcher.dismissWindow() }
        // Task { for await shown in Observations { launcher.isWindowPresented } { shown ? panel.show(below: statusItem) : panel.orderOut(nil) } }
        // Task { for await active in Observations { launcher.activity.isActive } { statusItem.button?.image = MenuBarIcon.image(active: active) } }
        fatalError("not implemented")
    }
    @objc private func iconClicked() { launcher.toggleWindow() }
}

/// Borderless, non-activating panel whose content view is an NSGlassEffectView (Liquid Glass, R4) hosting SwiftUI.
/// `.nonactivatingPanel` lets it become key (so the picker and toggle work) without activating this LSUIElement app.
final class LauncherPanel: NSPanel {
    var onDismissRequest: (() -> Void)?
    init(rootView: some View) {
        // styleMask [.borderless, .nonactivatingPanel]; isOpaque = false; backgroundColor = .clear; hasShadow = true
        // level = .popUpMenu; collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary]   // opens over full-screen apps too
        // contentView = NSGlassEffectView(style: .regular, cornerRadius: 20) whose contentView = NSHostingView(rootView)
        // observe didResignKeyNotification → onDismissRequest (guard: not our status button's mouse-down)
        fatalError("not implemented")
    }
    override func cancelOperation(_ sender: Any?) { onDismissRequest?() }          // Escape
    func show(below statusItem: NSStatusItem) { /* right-aligned under the button, clamped to the screen's visibleFrame; makeKeyAndOrderFront */ }
}

/// R2. Template images so AppKit tints them for light and dark menu bars. The inactive glyph is drawn: SF Symbols
/// has no slashed variant of `hand.tap` (probed, Q8), so it is the symbol plus a diagonal stroke with a knockout gap.
enum MenuBarIcon {
    static func image(active: Bool) -> NSImage {
        // NSImage(size: 18×18, flipped: false) { rect in draw hand.tap (symbol configuration .medium); if !active { clear a 2 pt band, stroke the diagonal } }
        // image.isTemplate = true; cached per state
        fatalError("not implemented")
    }
}
```

```swift
// App/Views/LauncherWindowView.swift — layout per the design image with R4's three deviations.
struct LauncherWindowView: View {
    @Environment(TrackpadLauncher.self) private var launcher
    var body: some View {
        // VStack {
        //   inner card (secondary glass or material, rounded):
        //     ForEach(launcher.rows) { GestureRowView(row: $0) }
        //     HandModeToggle(selection: Bindable(launcher).handMode)                                    // R9, between rows and divider
        //     Divider()
        //     HintOrNoticeView(activity: launcher.activity, corner: launcher.handMode.anchorCorner)    // R10, R15
        //   bottom bar: Spacer(); Button("Quit") { launcher.quit() }                                     // R19; no Learn more…
        // }.frame(width: 532)
        fatalError("not implemented")
    }
}

/// Illustrations from assets/ as template images (tinted with the label colour for light/dark, probed Q8),
/// flipped horizontally in Left hand mode (R10). The hint's inline thumb/other-finger marks use the two small SVGs.
struct GestureIllustration: View { let gesture: Gesture; let mirrored: Bool; var body: some View { fatalError("not implemented") } }

/// `.active` → the hint ("Hold thumb on \(corner.hintWord) corner, tap with 1, 2, 3 or 4 fingers anywhere to launch selected app");
/// `.noTrackpad` → "No trackpad connected"; `.blocked(by:)` → "Turn off \(names joined) in Trackpad settings"
/// plus a button calling `launcher.openTrackpadSettings()`. Names come from `ConflictingSetting.noticeName`, nowhere else.
struct HintOrNoticeView: View { let activity: GestureActivity; let corner: AnchorCorner; var body: some View { fatalError("not implemented") } }
```

#### Build, test and distribution layout

```
Package.swift                      swift-tools-version 6.2; platforms macOS 26; language mode 6 (strict concurrency complete)
  LauncherCore                     no AppKit import; default isolation nonisolated; the hub alone is @MainActor
  LauncherPlatform                 depends on LauncherCore; imports AppKit, IOKit, ServiceManagement, Synchronization
  LauncherCoreTests                Swift Testing; in-memory adapters, FrameScript, TestWorld, ForbiddenAPIRule
  LauncherPlatformTests            Swift Testing; throwaway UserDefaults suite, temp bundles, KVO on a throwaway key
project.yml                        xcodegen generates TrackpadLauncher.xcodeproj
  TrackpadLauncherApp (application) sources App/, resources assets/*.svg, depends on the local package products
    SWIFT_VERSION 6; SWIFT_DEFAULT_ACTOR_ISOLATION MainActor; SWIFT_STRICT_CONCURRENCY complete
    MACOSX_DEPLOYMENT_TARGET 26.0; ARCHS = ARCHS_STANDARD (arm64 + x86_64, universal)
    Info.plist: LSUIElement true, LSMinimumSystemVersion 26.0
    ENABLE_HARDENED_RUNTIME YES; no entitlements file (no sandbox, no runtime exceptions: the private framework is Apple-signed)
    Config/Release.xcconfig signs with Developer ID Application; Config/Debug.xcconfig signs with Apple Development
Scripts/release.sh                 archive, export with the developer-id method, ditto zip, notarytool submit with wait, stapler staple
Scripts/test.sh                    sets DEVELOPER_DIR to Xcode 26, runs swift test, then xcodegen and the app target build
```

Why this split: `swift test` runs the whole behavioural suite in seconds with no project generation, which is what the slices will iterate on; the app target exists only for what SwiftPM cannot produce (an `.app` bundle with `Info.plist` keys, resources, hardened runtime, Developer ID signing, a universal binary). xcodegen keeps the project a reviewable text file. The Xcode 26 toolchain is selected through `DEVELOPER_DIR` because `xcode-select` points at the CLT (Q10), and the macOS 26 SDK is what makes Liquid Glass and `LSMinimumSystemVersion = 26.0` honest. The machine has no Developer ID certificate yet (Q9/Q10): `release.sh` is written early and verified last.

#### Test handles (everything a test cannot wait for or provoke)

| Thing | Handle | Where |
|---|---|---|
| The tap window and every duration | `TouchFrame.timestamp`, authored by `FrameScript` | `TapRecognizer` tests |
| Frames and the connected set | `InMemoryTrackpadSource.perform(_:)`, `.connected = [...]` then `InMemoryDeviceEvents.fire()` | `TestWorld` |
| The button during a tap | `FrameScript.click()` sets `anyButtonDown` on the frames it emits | recognizer tests |
| Trackpad settings and their live change | `InMemoryPreferences.set(_:rawValue:for:)` invokes the observer synchronously | activity and hub tests |
| Device add, remove, wake | `InMemoryDeviceEvents.fire()` | hub tests |
| Apps on disk, Trash, moves, reinstalls | `InMemoryAppCatalog` (dictionary of URL to identity; a `registered` list per bundle ID) | resolution and hub tests |
| Bring to front | `RecordingAppLauncher.launched: [URL]` | R12, R13 scenarios |
| Haptic | `InMemoryTrackpadSource.pulses: [TrackpadID]` | R13 scenarios |
| Persistence across "reboot" | one `InMemorySettingsStore` shared by two `TrackpadLauncher` instances | R8, R17, R18 |
| Login item | `RecordingLoginItem.registrations: Int` | R17: once on first launch, zero on later launches, untouched by quit |
| Window | `launcher.isWindowPresented` | R3, R18 |
| No logging, network, timers, permission APIs | `ForbiddenAPIRule` scans Sources/ and App/ for `print(`, `debugPrint(`, `NSLog(`, `os_log`, `Logger(`, `URLSession`, `import Network`, `Timer`, `makeTimerSource`, `asyncAfter`, `Task.sleep`, `AXIsProcessTrusted`, `CGEvent.tapCreate`; fails on any hit | R20, R21, R22 |

The real adapters get their own in-process tests where the grounding says they can: `UserDefaultsSettingsStore` against a throwaway suite; `FileSystemAppCatalog` against a temp tree with fake bundles, a Utilities subfolder, a non-app file and a `.Trash` copy; `UserDefaultsTrackpadPreferenceSource` via the KVO-probe pattern on a throwaway key in a throwaway domain. `MultitouchSource`, `IOKitDeviceEventSource`, `WorkspaceAppLauncher` and `SMAppServiceLoginItem` are verified manually in the E2E checklist (real frames, haptic per device, hot-plug, wake, Dock-click semantics, Login Items UI).

#### Concurrency summary

- `@MainActor`: `TrackpadLauncher`, every adapter except `MultitouchSource` and the IOKit queue inside `IOKitDeviceEventSource`, the whole app target.
- Frame thread (MultitouchSupport's): `MultitouchSource.frameCallback` (parse + button sample) and `GestureListener.ingest` (recognizer under its `Mutex`). The only hop is `Task { @MainActor in fire(event) }`, once per completed tap.
- Other threads: IOKit callbacks on a private queue (hop via `Task { @MainActor }`); KVO and the wake notification arrive on the main thread and use `MainActor.assumeIsolated`.
- `Sendable`: every domain value, `TapRecognizer`, `GestureListener` (Mutex), `MultitouchSource` (Mutex), the hub (actor-isolated).
- Writers: the hub's fields have one writer (the hub); the recognizer dictionary has one writer (the frame thread); the multitouch device registry has one writer (the hub's thread, under the source's mutex, which the frame thread only reads). No field is written by two actors.

### Synthesis decision

### Tradeoffs accepted

- We accept that recognition runs while gestures are inactive (devices stay started, frames are parsed, the recognizer ticks) in exchange for one gate in `fire` that decides every silent case, and for never having a "device stopped because of settings" state to reconcile. The idle cost is unchanged: no frames arrive without a touch.
- We accept a `Mutex` in `GestureListener` and in `MultitouchSource` (two short critical sections on the frame path) in exchange for keeping the main actor out of the ~100 Hz frame stream and keeping the hub free of frames entirely.
- We accept that the recognizer has no wall clock, so a tap whose lift frame never arrives (device restarted mid-touch) simply never fires, in exchange for zero timers and fully authored time in tests.
- We accept that `restartAll` drops a touch in progress on every reconcile (launch, plug, unplug, wake) in exchange for one convergent operation instead of add/remove/wake paths with their own partial-state bugs.
- We accept re-resolving the four assignments on every window open and enumerating the Applications folders on every picker open, synchronously on the main actor (tens of milliseconds, user-initiated), in exchange for no cache to invalidate and R5/R7's "each time" semantics being literally true. If a slow disk makes this visible, `installedApps()` becomes `async` behind the same name.
- We accept storing the display name inside `AppIdentity` (a denormalised copy of a fact on disk) in exchange for rendering the "not found" row without a disk lookup. It refreshes on every assign.
- We accept a single JSON blob under one `UserDefaults` key, which makes the settings unreadable with `defaults read` as separate keys, in exchange for atomic writes and a one-line schema version.
- We accept that the status-button click wrinkle (resign-key firing before the toggle) is handled with an event guard in the shell rather than the macOS 27 expanded-interface session API, because the deployment target is macOS 26.
- We accept that `WorkspaceAppLauncher` ignores the completion of `openApplication`, because the only possible reactions (a log line or a dialog) are both ruled out (R21, product).

### Alternatives considered

- **`MenuBarExtra(.window)` as the shell.** Hides the status item and panel entirely, but exposes no programmatic open/close, so R18 (open on first launch) and R3 (gesture closes the window) are unimplementable; rejected on capability, not depth.
- **`NSPopover` from the status item.** Gives transient dismissal and Escape for free, but the arrow and popover chrome do not match the arrowless card in the design, and the status-click wrinkle is identical. Rejected: same exposed complexity, less control over the glass.
- **Recognizer on the main actor (hop every frame).** Simplest isolation story (no `Mutex`, one actor) and the hub could own the recognizers directly. Rejected: it puts a 100 Hz stream onto the actor that is also rendering SwiftUI while the window is open, and it makes the hub's interface carry frames. The chosen shape hides frames below the hub.
- **Hand mode as a recognizer input.** The natural first sketch: `TapRecognizer(handMode:)` and the hub pushes mode changes to the frame thread. Rejected because it creates the only cross-thread configuration in the app; the corner-agnostic recognizer plus a one-line match in `fire` removes it with no loss of behaviour.
- **An injected `Clock` and a tap-timeout timer.** Conventional and what the task anticipates. Rejected because every lift is observed as a frame, so the frame timestamp is a sufficient clock, and a timer would be the only timer in the app (R22).
- **Gating by stopping devices while inactive.** Saves parsing frames while inactive. Rejected: it splits the R13/R14 silent decision across `reconcile` and `fire` and adds a device state that must track settings.
- **Incremental device management (add on first-match, remove on terminated, restart on wake).** Three code paths that each reason about partial state; rejected for the one idempotent `restartAll` (per `make-operations-idempotent`), at the cost of dropping an in-flight touch on reconcile.
- **A settings table of structs (`[ConflictingSetting]`) instead of an enum.** Reads more like data, but nothing forces a new row to supply all three facts; the enum with exhaustive switches makes the compiler enforce it (per `encode-lessons-in-structure`).
- **One `LaunchServices` adapter for both the catalog and the launcher.** They share a framework but vary independently in tests (a canned app list versus a recorded activation), so they are two seams.

### Open questions and risks

1. The frame layout, state values, bottom-left origin and callback thread are sourced, not probed (Q1). The first slice prints real frames through `MultitouchSource` before anything else is built on it; if the layout differs, only `parse` changes. Is that acceptable as the slice-one gate?
2. Anchor-corner geometry: fractions (20% × 25%) give 25 × 19 mm on the probed MacBook surface and about 32 × 29 mm on a Magic Trackpad. Should the height be 30% so a flat-resting thumb on the MacBook is reliably inside, or should the zone be fixed in millimetres (the frame carries mm, so this is a one-constant change)?
3. Should a thumb that slides out of the corner and back re-arm without lifting? The sketch disarms on exit and requires a fresh landing; re-arming is friendlier but makes "thumb outside the corner" fuzzier.
4. `maxTapDuration = 0.35 s` and `dragThresholdMM = 4` are guesses to be tuned by feel on hardware. Who signs off on the feel?
5. The preference values (`Clicking == 1`, `TrackpadThreeFingerTapGesture == 2`) and the Force Click mapping are sourced (Q4). They are verified by toggling System Settings once in the activity slice; is a USB-wired Magic Trackpad reading the Bluetooth domain something to test, or is Bluetooth-only acceptable for v1?
6. Does IOKit's first-match fire before `MTDeviceCreateList` includes the new device? If not, the hot-plug reconcile could list the old set; a second reconcile on the next event would fix it, but R16's 5-second window might be missed. Needs a Magic Trackpad to check.
7. `SMAppService.register()` requires signed code; Debug builds sign with Apple Development. Is a login item registered by a development-signed build acceptable on the developer's machine, or should Debug skip registration behind a build flag?
8. SwiftUI `Menu` content is expected to be built when the menu opens; if it is pre-built, "newly installed app appears" would need the refresh on window open instead (weaker). Verify in the window slice.
9. Haptic actuation ID 6 (strong) is the probe's value; 3 or 4 may feel better. Feel decision.
10. No Developer ID certificate exists on the machine; R23 cannot be verified until one is installed. Who provisions it?

### Next implementation step

Create `Package.swift` with `LauncherCore` and `LauncherCoreTests`, write `Domain.swift` and `TapRecognizer.swift` with `FrameScript`, and make the R11 scenarios ("thumb first then tap", "fingers before thumb", "thumb lifts before fingers", "click is not a tap", "staggered landing and lifting", "five fingers", "1 cm in / 4 cm out on 124.8 mm") pass as Swift Testing cases through `TapRecognizer.consume`.
