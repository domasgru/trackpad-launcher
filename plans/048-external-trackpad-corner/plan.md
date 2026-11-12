# Plan: A thumb corner per trackpad kind

## Problem statement

A MacBook user who also uses a Magic Trackpad has one thumb corner for both. The two trackpads sit in different places and are held differently. The corner that suits the built-in trackpad often does not suit the external one. Today the user must pick one corner and live with it on the other trackpad, or switch it by hand each time.

## Solution

Once the MacBook has seen a Magic Trackpad, the settings window shows two thumb corners: one for the MacBook trackpad and one for the external trackpad. Each trackpad anchors the thumb in its own corner. Both choices are remembered. The illustrations show the external trackpad's corner while one is connected, and the MacBook trackpad's corner otherwise. A Mac that has never had both kinds connected sees no change.

## Requirements

Terms: a *built-in* trackpad is the MacBook's own trackpad. An *external* trackpad is a Magic Trackpad. A Magic Mouse is not a trackpad. A trackpad is *connected* while macOS reports it to Trackpad Launcher: plugged in, or paired and switched on.

### R1. Mixed trackpads are detected and remembered
Trackpad Launcher MUST record that the Mac *has mixed trackpads* the first time it sees a built-in trackpad and an external trackpad connected at the same time. That happens, for example, when an external trackpad connects while the app runs, or when the app starts with both connected. The record belongs to the user's Trackpad Launcher settings. It MUST survive a quit, a force-quit, a disconnect, a Mac restart and an update. No control clears it.

#### Scenario: Magic Trackpad connects while the app runs
- **GIVEN** a MacBook that does not have mixed trackpads
- **WHEN** a Magic Trackpad connects while Trackpad Launcher runs
- **THEN** the Mac has mixed trackpads

#### Scenario: App starts with both trackpads connected
- **GIVEN** a MacBook with a Magic Trackpad connected, and Trackpad Launcher not running
- **WHEN** Trackpad Launcher starts
- **THEN** the Mac has mixed trackpads

#### Scenario: Disconnect and relaunch keep the record
- **GIVEN** a Mac that has mixed trackpads
- **WHEN** the Magic Trackpad disconnects, and Trackpad Launcher quits and starts again with only the built-in trackpad
- **THEN** the Mac still has mixed trackpads

#### Scenario: A Mac with only external trackpads
- **GIVEN** a Mac with no built-in trackpad, such as a Mac mini
- **WHEN** a Magic Trackpad connects
- **THEN** the Mac does not have mixed trackpads

#### Scenario: A Magic Mouse is not a trackpad
- **GIVEN** a MacBook that does not have mixed trackpads
- **WHEN** a Magic Mouse connects
- **THEN** the Mac does not have mixed trackpads

### R2. Two thumb corner rows once the Mac has mixed trackpads
While the Mac has mixed trackpads, the settings window's thumb corner group MUST show the title "Thumb corner:". Two rows MUST follow it, indented: *MacBook trackpad* and *External trackpad*, in that order. Each row has its own pop-up at the trailing edge. Each pop-up offers the four corners in this order: *Top left*, *Top right*, *Bottom left*, *Bottom right*. It shows that row's current corner. The *Hide background apps* switch stays below, as today. The rows MUST show whether or not an external trackpad is connected right now. The window MUST resize to fit when the rows change.

#### Scenario: Both rows show after the Magic Trackpad disconnects
- **GIVEN** a Mac that has mixed trackpads, with the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom right*
- **WHEN** the Magic Trackpad is disconnected and the user opens the settings window
- **THEN** the window shows "Thumb corner:" with *MacBook trackpad* set to *Top left* and *External trackpad* set to *Bottom right*

#### Scenario: Rows appear while the window is open
- **GIVEN** the settings window is open on a MacBook that does not have mixed trackpads, showing the single *Thumb corner* row
- **WHEN** a Magic Trackpad connects
- **THEN** the window replaces the single row with the two rows and resizes to fit
- **AND** the illustrations draw the thumb in the *External trackpad* corner, *Bottom left* by default, and the Hold/Tap guide hides

### R3. One row until the Mac has mixed trackpads
While the Mac does not have mixed trackpads, the settings window MUST show the single *Thumb corner* row exactly as today. The one corner applies to every connected trackpad, defaults to *Top left*, and the illustrations show it.

#### Scenario: Mac mini with a Magic Trackpad
- **GIVEN** a Mac with no built-in trackpad and a Magic Trackpad connected, with the thumb corner never changed
- **WHEN** the user opens the settings window
- **THEN** the window shows the single *Thumb corner* row set to *Top left*, and a thumb on the Magic Trackpad anchors in the top-left corner

#### Scenario: MacBook-only user upgrades
- **GIVEN** a MacBook on the previous version with the thumb corner set to *Bottom right*, that does not have mixed trackpads
- **WHEN** they upgrade
- **THEN** the single *Thumb corner* row shows *Bottom right*, and gestures and illustrations are unchanged

### R4. Each trackpad anchors the thumb in its own kind's corner
While the Mac has mixed trackpads, a thumb on the built-in trackpad MUST anchor in the *MacBook trackpad* corner. A thumb on an external trackpad MUST anchor in the *External trackpad* corner. Every rule that depends on the thumb corner MUST follow the corner of the trackpad the touch is on. That covers the anchor corner, the thumb tap and edge contacts. Swipes and window swipes keep their directions from every corner, as today. Both trackpads work at the same time, each with its own corner. Touches on different trackpads never combine: a thumb on one trackpad never arms taps on the other.

#### Scenario: Both trackpads connected with different corners
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected
- **WHEN** the user holds a thumb in the bottom-left corner of the Magic Trackpad and taps with two fingers
- **THEN** the 2-finger gesture fires
- **AND WHEN** the user holds a thumb in the bottom-left corner of the built-in trackpad and taps with two fingers
- **THEN** no gesture fires

#### Scenario: Swap on the external trackpad
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected, with the swap setting on
- **WHEN** two fingers rest on the Magic Trackpad and the thumb taps its bottom-left corner
- **THEN** the swap fires

#### Scenario: Swipe on the external trackpad
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected
- **WHEN** the user holds a thumb in the bottom-left corner of the Magic Trackpad and slides two fingers right
- **THEN** the switcher shows and the highlight moves to older apps

#### Scenario: Thumb on one trackpad, fingers on the other
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected
- **WHEN** a thumb rests in the bottom-left corner of the Magic Trackpad and two fingers tap the built-in trackpad
- **THEN** no gesture fires

### R5. Changing one corner leaves the other alone
Choosing a corner in one row MUST change only that trackpad kind's corner. The choice MUST apply to the next thumb that lands on a trackpad of that kind. It MUST be saved at once, so it survives a quit, a force-quit or a Mac restart. A thumb already down on a trackpad of that kind is judged afresh at once: it anchors if it rests in the new corner, and otherwise it is not anchored.

#### Scenario: Change applies live
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected
- **WHEN** the user sets *External trackpad* to *Bottom right*, without restarting Trackpad Launcher
- **THEN** the next thumb held in the bottom-right corner of the Magic Trackpad fires a gesture

#### Scenario: Change survives a force-quit
- **GIVEN** the user has set *MacBook trackpad* to *Top left* and *External trackpad* to *Bottom right*
- **WHEN** Trackpad Launcher is force-quit and started again
- **THEN** *MacBook trackpad* shows *Top left* and *External trackpad* shows *Bottom right*

#### Scenario: Changing the MacBook corner leaves the external one alone
- **GIVEN** the MacBook trackpad set to *Top left* and the external trackpad set to *Bottom left*, both connected
- **WHEN** the user sets *MacBook trackpad* to *Top right*
- **THEN** *External trackpad* still shows *Bottom left*, and a thumb in the bottom-left corner of the Magic Trackpad still anchors

### R6. Default corners
The *MacBook trackpad* corner MUST default to *Top left*, and it MUST be the corner the single row showed before. The *External trackpad* corner MUST default to *Bottom left* for every user, including users upgrading from a version without it. The *External trackpad* corner applies only while the Mac has mixed trackpads. A Mac without mixed trackpads uses the one corner for every trackpad (R3).

#### Scenario: First Magic Trackpad on a fresh install
- **GIVEN** a fresh install on a MacBook, with no corner changed
- **WHEN** a Magic Trackpad connects
- **THEN** *MacBook trackpad* shows *Top left* and *External trackpad* shows *Bottom left*

#### Scenario: Upgrading user keeps the MacBook corner
- **GIVEN** a user on the previous version with the thumb corner set to *Top right*
- **WHEN** they upgrade and connect a Magic Trackpad to their MacBook
- **THEN** *MacBook trackpad* shows *Top right* and *External trackpad* shows *Bottom left*

#### Scenario: Upgrading user with both trackpads already in use
- **GIVEN** a MacBook user on the previous version with the thumb corner set to *Top left* and a Magic Trackpad connected
- **WHEN** the update installs and Trackpad Launcher starts at login with both trackpads connected
- **THEN** the Magic Trackpad anchors the thumb bottom-left from then on, with nothing telling the user
- **AND** the user can change it in the settings window

### R7. Illustrations show the corner of the connected trackpad
While the Mac has mixed trackpads, every illustration in the settings window MUST draw the thumb in the *External trackpad* corner while an external trackpad is connected. Otherwise it MUST draw the thumb in the *MacBook trackpad* corner. That covers the five gesture rows, the swipe, the window swipe and the thumb tap. The illustrations MUST switch while the window is open, as a trackpad connects or disconnects. The handwritten Hold/Tap guide MUST show only when the corner drawn is *Top left*, as today.

#### Scenario: Magic Trackpad connects with the window open
- **GIVEN** the MacBook trackpad set to *Top left*, the external trackpad set to *Bottom left*, and the settings window open with no Magic Trackpad connected
- **WHEN** a Magic Trackpad connects
- **THEN** every illustration draws the thumb bottom-left, and the Hold/Tap guide hides

#### Scenario: Magic Trackpad disconnects with the window open
- **GIVEN** the same corners, with the Magic Trackpad connected and the settings window open
- **WHEN** the Magic Trackpad disconnects
- **THEN** every illustration draws the thumb top-left, and the Hold/Tap guide shows

#### Scenario: Changing the corner not in view
- **GIVEN** the Magic Trackpad disconnected and the settings window open
- **WHEN** the user changes *External trackpad* to *Top right*
- **THEN** the illustrations keep drawing the *MacBook trackpad* corner

#### Scenario: Changing the corner in view
- **GIVEN** the Magic Trackpad connected and the settings window open
- **WHEN** the user sets *External trackpad* to *Top right*
- **THEN** every illustration draws the thumb top-right at once

#### Scenario: New user with a Magic Trackpad sees no guide
- **GIVEN** a fresh install on a MacBook with a Magic Trackpad connected, with no corner changed
- **WHEN** the user opens the settings window
- **THEN** every illustration draws the thumb bottom-left, and the Hold/Tap guide does not show

### R8. Downgrading keeps the MacBook corner
The existing thumb corner setting keeps its meaning as the *MacBook trackpad* corner. So the previous version, installed over this one, MUST use the *MacBook trackpad* corner for every trackpad and keep every other setting. Installing this version again MUST bring back the *External trackpad* corner and the mixed-trackpads record.

#### Scenario: Downgrade and upgrade again
- **GIVEN** *MacBook trackpad* set to *Bottom right* and *External trackpad* set to *Top left*
- **WHEN** the user installs the previous version, then this version again
- **THEN** the previous version anchors at bottom-right on both trackpads, and this version shows both corners as they were set

## Non-goals

- **A corner per individual trackpad.** Two Magic Trackpads share the *External trackpad* corner. Apple's own trackpad settings work per kind too, and owning two is rare.
- **Two rows on a Mac with no built-in trackpad.** Such a Mac has only one kind, so one corner covers it.
- **Carrying an upgrading user's corner over to the external trackpad.** The product has almost no users yet, so one simple default wins.
- **Forgetting the mixed-trackpads record.** Once seen, the second row stays. No reset is offered.
- **Other settings per trackpad kind.** Only the thumb corner splits. The hide background apps setting, the switcher settings and the assignments stay global.
- **Illustrations following the trackpad last touched.** With both connected, the illustrations show the external corner even while the user works on the built-in trackpad. Following connection is simpler and stable.
- **A notice when the external corner takes effect for an upgrading user.** The product has almost no users yet.

## Design

### Problem

Each trackpad kind gets its own thumb corner once the Mac has *mixed trackpads*. Recognition is plumbing: `Trackpad.kind` already exists end to end, every device already runs its own `GestureRecognizer`, and the corner is already a recognizer input. Four constraints decide the shape.

- **Persistence.** The previous version, v1.0.18, has settings code identical to today's. It reads a newer `settings` record fine, but its next save rewrites the record with its own keys only. So any 048 fact stored inside the record is lost the moment the user changes one setting while downgraded, and R8 asks for the External corner and the record back unconditionally (grounding facts 11-12, probe 02).
- **Detection.** R1 and R6 need the record saved at a login start with both trackpads connected, and saved durably through a force-quit. But "first run" means "the `settings` key holds no data", and `start()` and `reconcile()` promise to save nothing (fact 14). Saving the record there would spend the first run on a kill.
- **Re-runs.** Every `run` restarts every trackpad and hides the switcher, and the `Run` guard is all that stops a re-run (facts 7-8). So `Run` must compare corners in effect, never raw settings.
- **The window.** No test hosts the views. Today five separate reads of `launcher.thumbCorner` draw eight illustrations (five gesture rows, the swipe, the window swipe and the thumb tap) and the guide, and the window refits only when `SettingsShell.Fit` changes (facts 18-19).

Kept as they are:

- `handMode` and `isThumbAtBottom`, with their keys, raw values and meaning (now the MacBook trackpad corner);
- `ThumbCorner` stays non-`Codable`;
- the anchor rule stays inside the recognizer;
- `reconcile()` stays the one convergent operation;
- both trackpad adapters change together.

### Usage (caller's view)

> `launcher.thumbCorners` is `.single(corner)` until the Mac has mixed trackpads, then `.perKind(macBook:external:)`. `launcher.drawnThumbCorner` is the corner every illustration draws, and the Hold/Tap guide shows when it is *Top left*. `launcher.setThumbCorner(_:)` sets the one corner, which is the MacBook trackpad's. `launcher.setExternalThumbCorner(_:)` sets the External trackpad's, and does nothing on a Mac without mixed trackpads. Both save at once and re-run the trackpads only when a connected trackpad's corner changed. Nobody sets the mixed-trackpads record: the model records it the first time it sees both kinds connected.

The thumb corner group. The enum is the layout, so no flag has to stay in step with a row count:

```swift
struct ThumbCornerRows: View {                       // replaces ThumbCornerRow in the form's third Section
    let launcher: Launcher
    var body: some View {
        switch launcher.thumbCorners {
        case .single(let corner):                    // R3: exactly today's row
            CornerPicker(title: Copy.thumbCornerRow, corner: corner, indented: false) { launcher.setThumbCorner($0) }
        case .perKind(let macBook, let external):    // R2: title, then the two rows, connected or not
            Text(Copy.thumbCornerGroupTitle).formRowContent()
            CornerPicker(title: Copy.macBookTrackpadRow, corner: macBook, indented: true) { launcher.setThumbCorner($0) }
            CornerPicker(title: Copy.externalTrackpadRow, corner: external, indented: true) {
                launcher.setExternalThumbCorner($0)
            }
        }
    }
}
```

The illustrations and the refit. Every drawing reads one value:

```swift
// SettingsView.body: one read, passed down; the guide derives from the same value.
let corner = launcher.drawnThumbCorner
ForEach(launcher.rows) { row in GestureRowView(row: row, corner: corner, launcher: launcher, actions: actions) }
Section { SwitcherSection(launcher: launcher, corner: corner, actions: actions) }
// GestureRowView: GestureIllustration(gesture:, corner: corner); guide iff row.gesture == .one && corner.showsGuide

// SettingsShell's Fit loop gains one field.
Fit(inactiveNotice: launcher.inactiveNotice, /* … as today … */ hasMixedTrackpads: launcher.thumbCorners.hasMixedTrackpads)
```

Recognition, from `Launcher.reconcile` to both adapters. `Run` holds what it passes, so the guard stays plain `==`:

```swift
let corners = thumbCorners
let run = Run(trackpads: active ? connected.map { TrackpadRun($0, corner: corners.corner(for: $0.kind)) } : [], /* … */)
guard restart || run != lastRun else { return }
hardware.run(run.trackpads, blockClicks: run.blockClicks, blockTapClicks: run.blockTapClicks, slides: run.slides, swaps: run.swaps)
```

Two scenarios at the one high seam, `World`: the real `Launcher`, the real `SettingsStore` on a throwaway suite, and fake hardware running real recognizers.

```swift
@Test func aMagicTrackpadConnectingGivesTheMacMixedTrackpadsAndItsOwnCorner() {        // R1, R2, R4, R6, R7
    let world = World(apps: ["Arc"]); world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Arc")), for: .two)
    #expect(world.launcher.thumbCorners == .single(.topLeft))
    world.hardware.attach(.magicTrackpad)
    #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft))
    #expect(world.launcher.drawnThumbCorner == .bottomLeft)
    world.tap(2, on: .magicTrackpad, thumbIn: .bottomLeft); #expect(world.system.broughtToFront.count == 1)
    world.tap(2, on: .macBook14, thumbIn: .bottomLeft);     #expect(world.system.broughtToFront.count == 1)
    world.hardware.detach(Trackpad.magicTrackpad.id)
    let runs = world.hardware.runCount
    world.launcher.setExternalThumbCorner(.topRight)                                    // R7: the corner not in view
    #expect(world.hardware.runCount == runs && world.launcher.drawnThumbCorner == .topLeft)
}

@Test func whateverThePreviousVersionSavesBothCornersComeBack() throws {               // R8, both halves
    let world = World(attached: [.macBook14, .magicTrackpad]); world.launcher.start()
    world.launcher.setThumbCorner(.bottomRight); world.launcher.setExternalThumbCorner(.topLeft)
    let old = try world.previousVersionSaves { $0.isSwipeOn.toggle() }   // frozen v1.0.18 coding: decode, change, re-save
    #expect(old.handMode == "left" && old.isThumbAtBottom)              // bottom right, for every trackpad
    #expect(world.relaunch().thumbCorners == .perKind(macBook: .bottomRight, external: .topLeft))
}
```

### Shape

**One fact, in one key, is both the External corner and the mixed-trackpads record.** A Mac has an External corner exactly when it has mixed trackpads: R6 says the External corner applies only while the Mac has mixed trackpads, and R1 says nothing clears the record. So the External corner's presence *is* the record (per model-the-domain). There is no flag that could contradict it.

What is persisted:

```
the app's defaults domain
  settings                    <binary plist>   key set unchanged by this plan; handMode + isThumbAtBottom = the MacBook trackpad corner
  externalThumbCorner         "bottomLeft"     absent until the Mac has mixed trackpads; written at detection and by the External row; never removed
  startAtLoginTurnedOffByQuit …                StartAtLogin's, as today
```

In memory, those two facts build a sum type (per type-system-discipline). "Mixed but no External corner" and "an External corner on a Mac that is not mixed" cannot be built, on disk or as a value.

```swift
// MARK: LauncherCore

/// The thumb corners this Mac has. It has an External trackpad corner exactly when it has mixed trackpads: a built-in
/// and an external trackpad were once connected at the same time. Until then one corner serves every trackpad of
/// either kind. Every "which corner" rule lives here; recognition, the window's rows and its illustrations read answers.
public enum ThumbCorners: Equatable, Sendable {
    /// No mixed trackpads: the single *Thumb corner* row; its corner is the MacBook trackpad corner, saved in `settings`.
    case single(ThumbCorner)
    /// Mixed trackpads: the *MacBook trackpad* and *External trackpad* rows.
    case perKind(macBook: ThumbCorner, external: ThumbCorner)

    /// The External corner a Mac gets the moment it has mixed trackpads, upgraders included (R6).
    static let defaultExternal: ThumbCorner = .bottomLeft

    /// From the two saved facts: the record's corner, and the External corner, nil until mixed.
    init(macBook: ThumbCorner, external: ThumbCorner?) {
        self = external.map { .perKind(macBook: macBook, external: $0) } ?? .single(macBook)
    }

    /// Whether these kinds, connected at the same time, give the Mac mixed trackpads (R1). A Magic Mouse is no kind,
    /// and a Mac with no built-in trackpad never qualifies.
    static func areMixed(_ connected: Set<TrackpadKind>) -> Bool { connected.isSuperset(of: [.builtIn, .external]) }

    /// One row or two: the only corner fact that changes the window's height.
    public var hasMixedTrackpads: Bool { if case .perKind = self { true } else { false } }

    /// The corner a trackpad of this kind anchors the thumb in (R3, R4, R6). Total.
    public func corner(for kind: TrackpadKind) -> ThumbCorner {
        switch (self, kind) {
        case (.single(let corner), _): corner
        case (.perKind(let macBook, _), .builtIn): macBook
        case (.perKind(_, let external), .external): external
        }
    }

    /// The corner every illustration draws (R7): an external trackpad's while one is connected, else the built-in's,
    /// none connected included. Without mixed trackpads both are the one corner.
    func drawn(connected: Set<TrackpadKind>) -> ThumbCorner { corner(for: connected.contains(.external) ? .external : .builtIn) }
}

/// One trackpad of a run: the device, and the corner its fresh recognizer anchors the thumb in.
public struct TrackpadRun: Hashable, Sendable {
    public let trackpad: Trackpad
    public let corner: ThumbCorner
    public init(_ trackpad: Trackpad, corner: ThumbCorner) { fatalError("not implemented") }
}

@MainActor public protocol TrackpadHardware: AnyObject {
    // onEvent, connected(), playFeedback(_:on:), confirmWindowSwipe(on:): unchanged.
    /// Forgets every session, removes the click tap, stops every device, then starts exactly the trackpads in
    /// `trackpads`, each with a fresh recognizer anchoring the thumb in that entry's corner. Idempotent. [] = nothing runs.
    func run(_ trackpads: [TrackpadRun], blockClicks: Bool, blockTapClicks: Bool, slides: Set<SlideKind>, swaps: Bool)
}

/// The settings record under `settings`, plus, beside it, the one key the previous version must never drop.
@MainActor public struct SettingsStore {
    public init(defaults: UserDefaults)                 // unchanged
    public func load() -> Settings?                     // unchanged: reads only `settings`; nil = a first launch
    public func save(_ settings: Settings)              // unchanged: writes only `settings`

    /// The External trackpad corner; nil until the Mac has mixed trackpads. The key's presence is that record, so a
    /// value this build cannot read loads as `ThumbCorners.defaultExternal`, never as nil.
    func loadExternalCorner() -> ThumbCorner? {
        // guard let saved = defaults.object(forKey: "externalThumbCorner") else { return nil }
        // return (saved as? String).flatMap(SavedCorner.init(rawValue:))?.corner ?? ThumbCorners.defaultExternal
        fatalError("not implemented")
    }

    /// One synchronous `set` of one key beside the record. It survives a force-quit (probe 03), a version that does not
    /// know the key never rewrites it (probe 02), and it neither ends nor fakes a first run. Takes no nil: nothing
    /// clears the record.
    func saveExternalCorner(_ corner: ThumbCorner) { fatalError("not implemented") }
}

/// The key's permanent values. Exhaustive switches map them to and from `ThumbCorner`, so renaming a case there
/// cannot change what is saved, and `ThumbCorner` stays non-`Codable`.
private enum SavedCorner: String { case topLeft, topRight, bottomLeft, bottomRight }

@MainActor @Observable public final class Launcher {
    // Removed: `thumbCorner`.
    public var thumbCorners: ThumbCorners { ThumbCorners(macBook: settings.thumbCorner, external: externalCorner) }
    public var drawnThumbCorner: ThumbCorner { thumbCorners.drawn(connected: connectedKinds) }

    /// nil until the Mac has mixed trackpads. Loaded in `init` beside `store.load()`, which alone still decides
    /// `isFirstLaunch`. Written once by `reconcile()` and by `setExternalThumbCorner`. Observed.
    private var externalCorner: ThumbCorner?
    private var connectedKinds: Set<TrackpadKind> { Set(connected.map(\.kind)) }   // `activity` reads it too

    /// The one corner, which is the MacBook trackpad corner. Body unchanged: guard, `settings.thumbCorner`, save the
    /// record, reconcile.
    public func setThumbCorner(_ corner: ThumbCorner)

    /// The External trackpad corner (R5). Saved at once under its own key; the reconcile re-runs the trackpads only if
    /// an external trackpad is connected, since only then does a corner in effect change. Does nothing on a Mac without
    /// mixed trackpads, which has no External corner and no row to set it from.
    public func setExternalThumbCorner(_ corner: ThumbCorner) {
        // guard let current = externalCorner, corner != current else { return }
        // externalCorner = corner; store.saveExternalCorner(corner); reconcile()
        fatalError("not implemented")
    }

    /// Gestures on. Asks nothing, opens nothing and never saves the settings record, so a first run still waits for
    /// the first opening by hand. It may write one thing, once in a Mac's life: the External corner (see `reconcile`).
    public func start()

    private struct Run: Equatable {           // `corner` is gone: each trackpad carries its own
        let trackpads: [TrackpadRun]
        let blockClicks: Bool, blockTapClicks: Bool, slides: Set<SlideKind>, swaps: Bool
    }

    private func reconcile(restart: Bool = false) {
        // connected = hardware.connected()
        // // Mixed trackpads seen for the first time: a start, a hot-plug, a wake, a login start or hand-over after an
        // // update. Never the settings record. Idempotent: a later pass finds an External corner and writes nothing.
        // if externalCorner == nil, ThumbCorners.areMixed(connectedKinds) {
        //     store.saveExternalCorner(ThumbCorners.defaultExternal)
        //     externalCorner = ThumbCorners.defaultExternal
        // }
        // … preferences, permissions, active, blockClicks, tapToClickIsOn as today …
        // let corners = thumbCorners
        // let run = Run(trackpads: active ? connected.map { TrackpadRun($0, corner: corners.corner(for: $0.kind)) } : [], …)
        // guard restart || run != lastRun else { return }; lastRun = run; shown = nil; hardware.run(run.trackpads, …)
        fatalError("not implemented")
    }
}

// Copy: thumbCornerRow = "Thumb corner" stays for the single row; new:
public static let thumbCornerGroupTitle = "Thumb corner:"
public static let macBookTrackpadRow = "MacBook trackpad"
public static let externalTrackpadRow = "External trackpad"

// MARK: LauncherPlatform

/// The listed devices to run, in the listing's order, each with the corner of the entry that carries its ID. A listed
/// device no entry names is left out, and an entry no listed device carries runs nothing, so a device runs iff it was
/// asked for and then has its corner: there is no fallback corner to get wrong. Internal and pure, beside
/// `trackpadKind(product:isBuiltIn:)`, and tested the same way in LauncherPlatformTests with plain values as devices.
func devicesToRun<Device>(
    _ listed: [(device: Device, trackpad: Trackpad)], _ runs: [TrackpadRun]
) -> [(device: Device, trackpad: Trackpad, corner: ThumbCorner)] {
    // let corners = Dictionary(runs.map { ($0.trackpad.id, $0.corner) }, uniquingKeysWith: { first, _ in first })
    // return listed.compactMap { listed in corners[listed.trackpad.id].map { (listed.device, listed.trackpad, $0) } }
    fatalError("not implemented")
}

// MultitouchTrackpads.run: teardown, click tap, sessions and generations exactly as today; the `wanted` filter becomes
// `devicesToRun(listTrackpads(), trackpads)`, and each session's recognizer is
// GestureRecognizer(corner: entry.corner, surface: entry.trackpad.surface, …), the surface being the fresh listing's.
// Tests · InMemoryTrackpads.run mirrors it:
// running = Dictionary(uniqueKeysWithValues: trackpads.map {
//     ($0.trackpad.id, GestureRecognizer(corner: $0.corner, surface: $0.trackpad.surface, slides: slides, swaps: swaps, travel: .linear)) })

// MARK: LauncherUI
// ThumbCornerRows and CornerPicker(title:corner:indented:choose:) as in Usage. CornerPicker is today's menu Picker with
// formRowContent(). TODO, by eye against the Figma node on macOS 26: how the grouped Form draws the non-control
// "Thumb corner:" row and the indent of the two rows.
// GestureRowView and SwitcherSection take `corner: ThumbCorner`; SettingsView.body reads drawnThumbCorner once.
// SettingsShell.Fit gains `hasMixedTrackpads: Bool`, read in the same Observations closure.
```

**How data flows.** `UserDefaults` → `SettingsStore` → `Launcher` (`settings`, `externalCorner`, `connected`) → `ThumbCorners`, derived on read and never stored. From there, three consumers:

- `corner(for:)` feeds `Run`, then the port, then each recognizer;
- `drawn(connected:)` feeds the illustrations and the guide;
- the enum's case feeds the rows and `Fit`.

No question takes more than three files to answer: view → `Launcher` → adapter.

**Load-bearing decisions.**

- **Own key, never the record** (per separate-before-serializing-shared-state). The previous version and this one publish independent facts under independent keys, so "what if the old build saves?" answers "nothing". R8 holds whatever v1.0.18 does (probe 02). The record gains no key, so v1.0.18's decode cannot fail on it, and it reads `handMode` and `isThumbAtBottom` as the corner for every trackpad. The frozen fixtures and `everySettingsFieldSurvivesTheStore` stay as they are. Plan 021's `startAtLoginTurnedOffByQuit` is the precedent. `SettingsStore` stays the one owner of where settings live and in what wire form, so `Launcher.init` and the three composition sites keep their signatures.
- **Detection in `reconcile()`, saved to that key only** (per make-operations-idempotent). `reconcile()` is the one place that sees a start with both connected, a hot-plug, a wake and the first start after an update (a login start or a silent hand-over). The write is one synchronous `set`: it survives a force-quit (probe 03), happens once in a Mac's life, and never creates the `settings` key. `store.load()` is therefore still nil on a Mac before its first run, so enrolment and the Accessibility ask survive a kill at any point. "A login start saves nothing" is deliberately amended to "never saves the settings record", in `start()`'s doc and in the domain model.
- **Becoming mixed never causes a run of its own.** It happens only in a reconcile that already runs: the first one (`lastRun == nil`), a hot-plug or wake (`restart`), or one whose trackpad list changed. Mixed is a saved, one-way fact, never re-derived from the transient `connected`, so `Run` gains no input that flaps (the 006 symptom).
- **The port carries resolved corners** (per boundary-discipline). `TrackpadRun` is a construction: a trackpad cannot be run without its corner, and no adapter sees a kind-to-corner rule, a map with a missing kind, or the word "mixed". `Run` stores exactly what it passes and keeps today's order semantics. So changing the External corner while no Magic Trackpad is connected leaves `Run` equal and nothing restarts, with no bespoke comparison. The real adapter's one new step, joining the devices it re-lists to the entries by ID, is the pure `devicesToRun(_:_:)`, so it is proven by a test rather than only on a Magic Trackpad.
- **A change to a corner in effect re-runs every trackpad**, as every settings change does today. Fresh recognizers judge resting thumbs afresh (R5). The other kind's corner is unchanged, so a thumb resting there still anchors.
- **Recognition is untouched.** `GestureRecognizer`, `AnchorCorner` and `EdgeContacts` keep their inputs, so the anchor zone, the thumb tap and edge contacts follow their pad's corner (R4), and swipe directions stay corner-free. "Never combine" stays structural, with one recognizer per device. The frame thread shares nothing new.
- **Validation at one boundary**, `SettingsStore.loadExternalCorner()`; inside, the types are trusted. The one runtime guard is `setExternalThumbCorner` before the Mac is mixed, and the window cannot reach it.

**Interface depth.** The public surface gains:

- one enum, with two cases, one Bool and one rule;
- one pair type at the port;
- two `Launcher` reads and one intent;
- three `Copy` strings.

It loses `Launcher.thumbCorner` and the port's `corner:`. The store methods and the rest of the rules stay internal. Behind that surface sit detection, the default, the fall back to one corner, the drawn corner, live switching, the wire form, downgrade safety and first-run safety. Callers learn only that two rows exist in `.perKind` and that illustrations take `drawnThumbCorner`. They never learn kinds, connection state or keys.

**Testing seam.** Every R-scenario runs at `World`, or at `LifecycleWorld` for login starts, hand-overs and first runs. The handles:

- `World(attached: [.macBook14, .magicTrackpad])` for a start with both connected, and `[.magicTrackpad]` alone for a Mac mini;
- `hardware.attach`, `detach`, `sleep` and `wake`, plus two new ones: `hardware.connectMagicMouse()`, which pushes a payload-free `.trackpadsChanged` and attaches nothing, as the real IOKit match does; and `hardware.attachWhileAsleep(_:)`, which lists a trackpad and pushes nothing, so the `wake()` after it is the only signal and the wake path is told apart from a hot-plug;
- `devicesToRun(_:_:)` in LauncherPlatformTests, the one place the real adapter's join of listed devices to their corners is proven, since no Magic Trackpad is at hand and the fake builds from the entries it is passed;
- `relaunch()` for a quit or a force-quit (every write is synchronous);
- `LifecycleWorld.launch(.atLogin, attached:)` and `.afterUpdate(withWindow: false)` for R6, with `settingsRecordBytes()` and `freshStore().load()`;
- `hardware.runCount`, and `suiteDomain()` for a mixed Mac's key set;
- a new `World.tap(_:on:thumbIn:)` over `SurfaceSize.thumbMM(in:)`, to rest the thumb in a named corner on either surface, plus `on:` for `OneProcess.tap`;
- a new `World.previousVersionSaves(_:)` over a frozen `Build1018Settings`, a copy of today's `Settings` coding (identical to v1.0.18's), never regenerated, as `Build106Settings` was.

The views stay unhosted. Every rule they apply (`thumbCorners`, `drawnThumbCorner`, `hasMixedTrackpads`, `showsGuide`, `Copy`) is a value a test reaches.

**What it deliberately does not do.** No corner per device, no other per-kind setting, no reset, no notice, and no carrying an upgrader's corner to the External row. No migration code: an absent key is the upgrade. No partial re-run, and no view model.

**Docs.** `docs/architecture.md` holds unchanged: settings stay in `UserDefaults`, and keys stay inside the store. `docs/domain-model.md` changes in these entries:

- *Thumb corner*: loses "One global setting". It gains the MacBook and External corners, their defaults, and the downgrade sentence.
- *Mixed trackpads* (new): when the record is made, that it is the Mac having an External corner, that it is saved the moment it is seen, and that nothing clears it.
- *Trackpad*: each kind has its own corner once the Mac has mixed trackpads.
- *Anchor corner* and *Edge contact*: "the thumb corner of the trackpad the touch is on".
- *First run*: the mixed-trackpads record alone is not saved settings.
- *Settings window*: one row, or "Thumb corner:" and two rows. Illustrations draw the connected trackpad's corner, the guide follows the corner drawn, and the window resizes when the rows change.
- *Hide background apps setting*: "below the thumb corner rows".

### Synthesis decision

**Base: candidate 2 (Fable).** The cross-judge scored it 29 against candidate 1's 27, and my own criterion-by-criterion scoring agreed. Its edges:

- **Data shape.** One key whose presence is the record makes the invalid pairs unbuildable.
- **The port.** `[TrackpadRun]` keeps the 006 guard's order semantics and matches how `MultitouchTrackpads.run` filters re-listed devices by ID.
- **Churn.** It keeps today's `setThumbCorner(_:)`.
- **Tests.** It foresaw the six existing mixed-pad tests that R6 changes (verified in `checks/01`).

**Convergence.** Both candidates reached the same whole shape independently:

- a pure `ThumbCorners` sum type;
- the new facts beside an untouched record;
- detection in `reconcile()` writing only that key;
- resolved corners at the port;
- the full re-run kept;
- `Fit` gaining the row fact.

That is a strong agreement signal.

**Grafted from candidate 1:**

- one read of the drawn corner in `SettingsView.body`, passed to `GestureRowView` and `SwitcherSection`;
- a named `connectMagicMouse()` handle for R1's mouse scenario;
- the R7 "not in view" assertion with `runCount`;
- R5's other-trackpad restart put to the human as a question, not settled as a tradeoff.

**From the cross-judge:** the store methods and `areMixed`, `defaultExternal`, `init(macBook:external:)` and `drawn(connected:)` stay internal.

**Rejected:**

- **Candidate 1's `[Trackpad: ThumbCorner]` port.** It makes `Run` order-insensitive, an unrequested change, and its adapter sketch indexed the map by ID.
- **Its flag-plus-corner pair of keys.** "An External corner stored before it applies" needs a comment to explain.
- **Its `setThumbCorner(_:for:)`.** Under presence-is-record, `.external` before mixed needs the same guard, and the change touches about 20 call sites.
- **Candidate 2's case against two keys.** It argued from write atomicity, which the judge showed does not describe candidate 1. The reason recorded here is the invariant.

### Tradeoffs accepted

- We accept a second key of ours in the defaults domain, with `SettingsStore` owning two keys, in exchange for R8 holding whatever the previous version saves and detection never touching the first-run sentinel.
- We accept that the mixed-trackpads record has no flag of its own, being the External corner's presence, in exchange for no pair of saved facts that can contradict each other.
- We accept writing the default down at detection, in exchange for a corner that never moves under a user later. A future change of default would not reach Macs that are already mixed.
- We accept amending "a login start saves nothing" to "never saves the settings record". A start, a login start, a hot-plug or a wake may write `externalThumbCorner` once in a Mac's life. In exchange, R1 and R6 hold across a force-quit.
- We accept a full re-run of every trackpad when a corner in effect changes, in exchange for one convergent reconcile and no second writer to recognizers the frame thread owns. A swipe on the other pad ends, and its resting thumb loses its blocking window.
- We accept removing `Launcher.thumbCorner`, about 20 one-line test reads, in exchange for the compiler stopping at every illustration site.
- We accept moving the thumb to bottom-left in the six existing tests that rest it top-left on a Magic Trackpad beside the MacBook (`checks/01`), because R6 changes what they assert.
- We accept `Settings.thumbCorner` and `setThumbCorner(_:)` keeping their names while meaning "the MacBook trackpad corner, the one corner until mixed", in exchange for an untouched record, untouched fixtures and untouched call sites.
- We accept that the row order, the indent and the title are view code checked by hand, in exchange for no view model in core.

### Alternatives considered

- **Both facts as new keys inside the `settings` record** (the 005/028/032 pattern). It has the smallest-looking surface, and the key-set tests need no new case. It lost because it hides nothing and breaks two requirements:
  - the previous version's next save drops the keys, so R8's re-upgrade fails (probe 02; plan 028 dropped the same clause);
  - detection would have to save the record from `reconcile()`, which either writes the first-run sentinel early or parks a "pending" fact that a force-quit loses.
- **Two own keys, a `hasMixedTrackpads` flag and the External corner.** The downgrade safety is the same. It lost on depth: a corner can exist without the flag, which needs a comment and a rule for what it means. One key makes the invariant structural.
- **The port carries `ThumbCorners` or a per-kind map, and adapters resolve by kind.** It needs one fewer type. It lost because:
  - the per-kind rule would be re-derived in both adapters;
  - a partial map needs a fallback corner;
  - `Run` would need its own resolved copy or a custom `==` to avoid restarting the built-in trackpad when only an unconnected kind's corner changes.
- **A `[Trackpad: ThumbCorner]` map at the port.** It adds no type, but it changes `Run`'s order semantics, which nothing asked for. The adapter re-keys by ID anyway.
- **A partial re-run, keeping sessions whose configuration did not change.** The other pad's swipe would survive a corner change. It lost because it opens a second path through the shared click tap, the session registry and the generation counter, which plans 001 and 028 rejected. It does so for a disturbance that needs two hands on two trackpads while clicking a pop-up.
- **Holding the mixed fact in memory until the next save, or saving only once a record exists.** Both fail R1's force-quit at a login start, and on a first run with both trackpads connected.

### Open questions and risks

- **R5 and the other trackpad.** R5 says only "that kind" is judged afresh. Is it acceptable that the other connected trackpad restarts too, as every settings change does today? Its resting thumb stays anchored but loses its blocking window, and a swipe on it ends.
- **The amended start.** Is one write of `externalThumbCorner` at a start, login start, hot-plug or wake, once in a Mac's life, an acceptable amendment to "a login start saves nothing"? It never touches the `settings` record or the first run.
- **Where the record lives.** Does R1's "the record belongs to the user's Trackpad Launcher settings" accept the app's defaults domain beside the `settings` record, where `startAtLoginTurnedOffByQuit` lives today? R8 as written cannot hold inside the record.
- **An unreadable key value.** If `externalThumbCorner` ever holds a value this build cannot read, such as a later version's, should the Mac count as mixed with *Bottom left*, as designed, or as not mixed?
- **Rows that encode these answers.** T19 asserts the designed answer to the unreadable-value question, and T21 (c) the designed answer to the R5 question. Either answer given the other way flips its row.
- **Layout.** Who matches the layout against the Figma node, which no tool here could open? The "Thumb corner:" title row and the rows' indent in a macOS 26 grouped `Form` have no precedent in the code.
- **Hardware.** Can a Magic Trackpad be connected for the hand checks no test covers? These are:
  - `MTDeviceIsBuiltIn` over a USB-C cable;
  - whether a device is listed when its first-match fires;
  - the first frame after a restart;
  - whether the built-in trackpad is still listed with the lid closed, which decides when a docked MacBook first counts as mixed.
- **Downgrade check.** Will the downgrade to v1.0.18 and back be done by hand on a Release build in /Applications? Plan 028's equivalent check was never recorded, and the frozen replica proves the coding, not the old binary.

### Next implementation step

Build S1. Add `ThumbCorners` and `TrackpadRun`, and change `TrackpadHardware.run` to take `[TrackpadRun]` in both adapters, the real one through `devicesToRun(_:_:)` with its tests. Then replace `Launcher.thumbCorner` with `thumbCorners` and `drawnThumbCorner`, with the window reading `drawnThumbCorner` once in `SettingsView.body`. Every trackpad still resolves from `.single`, so the whole suite stays green before any behaviour changes.

## Testing Decisions

### Strategy

The requirements are proven at one high seam, `World` (`LauncherKit/Tests/LauncherCoreTests/World.swift`). It runs the real `Launcher` and the real `SettingsStore` on a throwaway `UserDefaults` suite, over `InMemoryTrackpads`, whose `run` builds a real `GestureRecognizer` for each trackpad. The design's own two scenarios work the same way. `LifecycleWorld` (`LifecycleWorld.swift`) is the same seam stretched over a whole Mac, for login starts, hand-overs, first runs and kills between effects. At that seam a row observes:
- the two public reads, `launcher.thumbCorners` and `launcher.drawnThumbCorner`, which carry every rule that the rows, the illustrations, the guide and `Fit` apply;
- what each trackpad's own recognizer fires, through `system.broughtToFront`, `hardware.feedback`, `launcher.switcher` and `launcher.windowSwitcher`;
- `hardware.runCount`;
- the defaults domain as a new process reads it: `suiteDomain()`, `settingsRecordBytes()` and `freshStore().load()`;
- for lifecycle rows, the window, the asks, the login item's calls, and the snapshot `LifecycleWorld` takes around each effect.

It misses the views, which no test hosts. It also misses the real `MultitouchTrackpads`: its listing, `MTDeviceIsBuiltIn`, and the call in `run` that hands the listing to `devicesToRun`. It also misses durability across a real SIGKILL and a real v1.0.18 binary. Those are under Verified without a test.

There is one seam below `World`: `devicesToRun(_:_:)` in `LauncherPlatformTests`, with `@testable import LauncherPlatform` and plain values standing in for devices, as `TrackpadClassificationTests` drives `trackpadKind(product:isBuiltIn:)`. It is the one place the real adapter's join of listed devices to their corners can be proven. The fake builds its recognizers from the entries it is passed, so no `World` row can see that join.

The only other seams are values that already have tests, both unchanged: `CopyTests` for the strings and `ThumbCornerRuleTests` for the guide's rule. `ThumbCorners` gets no rows of its own. Its internal members (`areMixed`, `drawn(connected:)`, `init(macBook:external:)`, `defaultExternal`) would need `@testable`. Every rule they hold is reached through `Launcher`'s two reads, which also prove the wiring.

The new rows resemble:
- `LauncherTests.swift`: the corner rows, `aBottomCornerChosenMidTouchJudgesTheThumbAfresh` and `hotPluggedExternalTrackpadWorksAndPulsesItself`;
- the two-trackpad rows of `SwapTests.swift`, `SwitcherOnScreenTests.swift` and `WindowSwitcherOnScreenTests.swift`;
- `LifecycleTests.swift`: `aLoginStartIsSilentAndLeavesTheSavedSettingsAlone` and `aLoginStartOnAMacWithoutSettingsDoesNothingUntilOpenedByHand`;
- `StartAtLoginTests.swift`: `convergesAfterAKillAnywhereIn`;
- `PersistenceTests.swift`: `Build106Settings` and the frozen `savedSettings`;
- `TrackpadClassificationTests.swift`, for `devicesToRun`.

Faked, all with existing fakes:
- the trackpad hardware, through `InMemoryTrackpads`, which must mirror the real adapter's `run`;
- the system trackpad preferences;
- the permissions;
- the login item.

The previous version is a frozen replica, `Build1018Settings`. Everything we own is used for real, the `UserDefaults` suite included. The feature has no timer, deadline, poll or retry, and no call that blocks, so no row owns a clock or holds a call. Touch timing comes from the scripts' frame times, as today.

Test-side handles this plan adds:
- `SurfaceSize.thumbMM(in:)`: a point 10 mm in from the corner's two edges. On the 14" MacBook that is (10, 10), (114.8, 10), (10, 66.8) and (114.8, 66.8). On the Magic Trackpad it is (10, 10), (150, 10), (10, 105) and (150, 105). These are the points today's rows use, inside the anchor corner (20% by 25%) on both surfaces.
- `World.tap(_:on:thumbIn:)` and `OneProcess.tap(_:on:thumbIn:)`, built on `thumbMM(in:)`, and an `attached:` parameter on `World.switcherWorld`.
- `Trackpad.secondMagicTrackpad`: ID 3, external, with the Magic Trackpad's surface.
- `InMemoryTrackpads.connectMagicMouse()`: pushes a payload-free `.trackpadsChanged` and lists nothing, as the real IOKit match does.
- `InMemoryTrackpads.attachWhileAsleep(_:)`: lists a trackpad and pushes nothing. The `wake()` that follows is then the only signal (withhold and inject).
- `Build1018Settings`: a frozen copy of today's `Settings` coding, which is v1.0.18's. Like `Build106Settings`, it is never regenerated.
- `World.previousVersionSaves(_:)`: decodes the record with that replica, applies a change, and writes back only `settings`, which is all v1.0.18 writes (probe 02).

Existing rows change in two ways:
- **S1, mechanically.** About 20 reads of `launcher.thumbCorner` become `thumbCorners == .single(…)`, and the fake's `run` takes `[TrackpadRun]`.
- **S2, the six rows listed in `checks/01`.** Each rests the thumb top-left on a Magic Trackpad beside the MacBook. They now rest it bottom-left (R6).

### Test scenarios

`both` is `[.macBook14, .magicTrackpad]`. "Fires" means the assigned app is brought to the front.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1, R2, R6, R7 | World | Given a fresh `World(apps: ["Arc"])`, started, with Arc on gesture 2, which saves a record. The trackpads arrive in three orders: (a) the MacBook alone, then `hardware.attach(.magicTrackpad)`; (b) the Magic Trackpad alone (lid closed), then `attach(.macBook14)`; (c) the MacBook alone, `sleep()`, `attachWhileAsleep(.magicTrackpad)`, then `wake()`. Before the last step, `thumbCorners == .single(.topLeft)` and the domain holds no `externalThumbCorner`. After it: `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)`; `drawnThumbCorner == .bottomLeft`; `suiteDomain()["externalThumbCorner"] as? String == "bottomLeft"`; `settingsRecordBytes()` is unchanged; `runCount` rose by exactly 1. | R1 scenario 1 and "the first time it sees … connected at the same time"; R6's defaults (Top left, Bottom left); R2 scenario 2 ("Bottom left by default"); the design's persisted table (`externalThumbCorner "bottomLeft"`, never the record) and "Becoming mixed never causes a run of its own" |
| T2 | R1, R6 | World | Given a fresh `World(attached: both)` that never saved settings. When `start()`. Then `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)`, `runCount == 1`, `settingsRecordBytes() == nil`, and the domain's keys are exactly `["externalThumbCorner"]`. | R1 scenario 2; R6's defaults; the design's "never saves the settings record", so the first run is not spent |
| T3 | R1, R3 | World | Given `World(apps: ["Arc"], attached: [])`, a Mac mini, started, with Arc on gesture 1. When a Magic Trackpad is attached, then `Trackpad.secondMagicTrackpad`. Then after each: `thumbCorners == .single(.topLeft)`, `drawnThumbCorner == .topLeft`, and the domain holds no `externalThumbCorner`. On either Magic Trackpad, a one-finger tap with the thumb top-left fires and one with the thumb bottom-left does nothing. | R1 scenario 4; R3 scenario 1 (single row, Top left, anchors top-left) |
| T4 | R1 | World | Given a started MacBook `World()`. When `hardware.connectMagicMouse()`. Then `thumbCorners == .single(.topLeft)`, and the domain holds no `externalThumbCorner`. | R1 scenario 5; domain-model *Trackpad* ("A Magic Mouse is not a trackpad") |
| T5 | R1, R2 | World | Given T2's mixed Mac, opened by hand, with Arc on gesture 1. When these steps run in order: detach the Magic Trackpad; `sleep()`; `wake()`; `relaunch()`, `start()` and `openedByHand()` with the MacBook alone; `setThumbCorner(.topRight)`; turn `setSwipe`, `setSwap`, `setWindowSwipe`, `setLaunchAnimation` and `setHideBackgroundApps` each from its value; `setAssignment(nil, for: .one)`; `askForScreenRecording()`; `closeWindow()`; detach the MacBook; attach it again; `relaunch()` and `start()`. Then after every step, recorded in order, `thumbCorners.hasMixedTrackpads` is true and `suiteDomain()["externalThumbCorner"] as? String == "bottomLeft"`. | R1 "No control clears it" and "MUST survive a quit, a force-quit, a disconnect"; R2 "The rows MUST show whether or not an external trackpad is connected right now" |
| T6 | R3 | LifecycleWorld | Given a Mac whose saved record has Arc on gesture 1 and the corner Bottom right, with the login item on and the MacBook alone. When it starts at login. Then `thumbCorners == .single(.bottomRight)` and `drawnThumbCorner == .bottomRight`. A tap with the thumb bottom-right fires and one top-left does not. The record's bytes are unchanged, and the domain's keys are exactly `["settings"]`. | R3 scenario 2 ("shows *Bottom right*, and gestures and illustrations are unchanged"); the record's coding is unchanged by this plan (checked below) |
| T7 | R6 | World | Given the frozen released record `PersistenceTests.savedSettings` seeded, relaunched and started on the MacBook alone, with Arc put on gesture 2. When a Magic Trackpad connects. Then `thumbCorners` goes from `.single(.topRight)` to `.perKind(macBook: .topRight, external: .bottomLeft)`. A two-finger tap fires with the thumb bottom-left on the Magic Trackpad, and fires again with the thumb top-right on the MacBook. | R6 scenario 2; the fixture's doc ("top-right corner", never regenerated) |
| T8 | R4, R6 | World | Given `World(apps: ["Arc"], attached: both)`, started, with Arc on gesture 2 and no corner changed. When four two-finger taps run in order, with the thumb: bottom-left on the Magic Trackpad; bottom-left on the MacBook; top-left on the MacBook; top-left on the Magic Trackpad. Then `broughtToFront.count` after each is 1, 1, 2, 2, and `hardware.feedback == [magicTrackpad.id, macBook14.id]`. | R4 scenario 1; R6's defaults |
| T9 | R4 | World | Given Safari, Mail, Slack and Notes running, Safari frontmost, both trackpads attached, started, with the swap on. When two fingers rest on the Magic Trackpad and the thumb taps at (10, 105). Then Mail comes to the front with one pulse on the Magic Trackpad. In a fresh world, the same swap with the thumb at (10, 10) on the Magic Trackpad does nothing. | R4 scenario 2; `SwapTests.aBottomLeftThumbSwapsFromTheBottomLeftCornerOnly` (Mail is the previous app) |
| T10 | R4 | World | (a) In T9's world, the thumb rests bottom-left on the Magic Trackpad and two fingers slide right 3.5 mm, then 12 mm, and hold: the switcher shows with Mail selected. With the thumb top-left instead, no switcher shows. (b) In `windowWorld(visible: ["Docs", "Mail", "News"], attached: both)`, the thumb rests bottom-left on the Magic Trackpad and two fingers slide down 3.5 mm, then 12 mm, and hold: the window switcher shows with row 1 selected. | R4 scenario 3 and "Swipes and window swipes keep their directions from every corner"; the fixtures of `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored` and `eventsFromASecondTrackpadNeverTouchTheWindowSwitcherUp` (3.5 + 12 mm selects Mail, and row 1) |
| T11 | R4 | World | Given T8's world. When (a) a thumb rests bottom-left on the Magic Trackpad without lifting, and two fingers tap the MacBook with no thumb; (b) a thumb rests top-left on the MacBook, and two fingers tap the Magic Trackpad with no thumb; (c) as a control, two fingers tap the MacBook under that resting top-left thumb. Then nothing fires in (a) or (b), and (c) fires once. | R4 scenario 4 and "a thumb on one trackpad never arms taps on the other" |
| T12 | R4 | World | Given T8's world, with Arc on gesture 1 and Figma on gesture 2. When, on the MacBook (Top left), the thumb rests at (10, 10) and two fingers tap at (62, 30) and (123.8, 53.76). And when, on the Magic Trackpad (Bottom left), the thumb rests at (10, 105) and two fingers tap at (80, 40) and (159, 80.5). Then the MacBook fires gesture 1 (Arc): its second contact lies in a top corner's hand-side band, so it is an edge contact. The Magic Trackpad fires gesture 2 (Figma): a bottom corner has no side band. | domain-model *Edge contact* (3 mm; 40% of the height; no side edge for a bottom corner). Both points are 1 mm from the right edge, 70% of the way down. |
| T13 | R4 | World | For each pair of wire value and corner, ("topLeft", .topLeft), ("topRight", .topRight), ("bottomLeft", .bottomLeft) and ("bottomRight", .bottomRight): given a saved record with the corner Top left and `externalThumbCorner` seeded with that string, then a world relaunched and started with both trackpads and Arc on gesture 1. Then `thumbCorners == .perKind(macBook: .topLeft, external: corner)`. On the Magic Trackpad a thumb in that corner fires and one in the diagonally opposite corner does not. The MacBook fires top-left. Once `Trackpad.secondMagicTrackpad` is attached, it fires in that corner too. | the design's persisted table (the key and its four permanent values); R2's four corners; R4 "A thumb on an external trackpad"; Non-goals ("Two Magic Trackpads share the *External trackpad* corner") |
| T14 | R1, R4, R6, R7 | World | Given T2's mixed Mac, with Arc on gesture 1. When the MacBook is detached (lid closed, the Magic Trackpad alone). Then `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)` and `drawnThumbCorner == .bottomLeft`, and the Magic Trackpad fires with the thumb bottom-left, not top-left. When the Magic Trackpad is detached too, `drawnThumbCorner == .topLeft` and `thumbCorners` stays `.perKind`. | R1 (survives a disconnect); R6 "applies only while the Mac has mixed trackpads"; R7 "Otherwise it MUST draw the thumb in the *MacBook trackpad* corner" |
| T15 | R7 | World | (a) Given a fresh MacBook world, started and opened by hand. When the Magic Trackpad is attached, detached and attached again. Then `drawnThumbCorner` reads `[.topLeft, .bottomLeft, .topLeft, .bottomLeft]`: once after opening, then after each step. (b) Given a fresh world with both trackpads, started and opened by hand. Then `drawnThumbCorner == .bottomLeft`. | R7 scenarios 1, 2 and 5. The guide's rule (`ThumbCornerRuleTests`: it shows for Top left only) turns these into: shown, hidden, shown, hidden, and hidden. |
| T16 | R1, R6 | LifecycleWorld | For each opening, `.atLogin`, and `.afterUpdate(withWindow: false)` as a release copy: given a Mac whose saved record has Arc on gesture 1 and the corner Top left, with the login item on. When the process starts with both trackpads. Then the window stays closed, nothing is asked, and the login item gets no call. The record's bytes are unchanged, and `externalThumbCorner` is `"bottomLeft"`. A tap fires with the thumb bottom-left on the Magic Trackpad, not top-left on it, and does fire top-left on the MacBook. A next process, started at login with the MacBook alone, reads `.perKind(macBook: .topLeft, external: .bottomLeft)`. | R6 scenario 3 ("from then on, with nothing telling the user"); domain-model *Login start* (silent) and *Hand-over*; R1 (survives a restart and an update) |
| T17 | R1, R6 | LifecycleWorld | Given a Mac that holds no settings, with Accessibility not granted, and with the login item's register and the ask each recording `freshStore().load()`. When a process starts at login with both trackpads, and is then opened by hand. Then after the login start: the window is closed, `freshStore().load() == nil`, and `externalThumbCorner` is `"bottomLeft"`. After the opening: `loginItem.calls == ["register"]` and `asks == [.accessibility]`; the loads recorded at the registration and at the ask were both nil; a record now exists; and `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)`. | domain-model *First run*, with the design's amendment ("the mixed-trackpads record alone is not saved settings"); the expectations of `aLoginStartOnAMacWithoutSettingsDoesNothingUntilOpenedByHand` |
| T18 | R1, R6 | LifecycleWorld | Given a Mac that holds no settings, with Accessibility not granted. When a first run by hand with both trackpads runs. It is then repeated from every snapshot it left: before the run, before and after each login item call and the ask, and at the end. Each restored Mac is opened by hand with both trackpads. Then no snapshot taken before the first save holds a `settings` key. Every restored end has the login item on, exactly the keys `["settings", "externalThumbCorner"]`, the uncrashed run's record, and `.perKind(macBook: .topLeft, external: .bottomLeft)`. | R1 "MUST survive … a force-quit"; domain-model *First run* (a kill before the first save repeats it); `StartAtLoginTests.convergesAfterAKillAnywhereIn` |
| T19 | R1 | World | For each `externalThumbCorner` value this build cannot read, the string "sideways" and the integer 1, seeded beside a record with the corner Top left: a MacBook world, relaunched and started. Then `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)`. The seeded value is still there after `start()`, and still there after a Magic Trackpad connects. | the design's `loadExternalCorner` doc ("a value this build cannot read loads as `ThumbCorners.defaultExternal`, never as nil"), which answers the open question on unreadable values; R1 "No control clears it" |
| T20 | R5, R7 | World | For each of the four corners: given both trackpads, started and opened by hand, with Arc on gesture 1 and `runs = runCount`. When `setExternalThumbCorner(corner)`. For `.bottomLeft`, the current value, nothing changes and `runCount == runs`. For the others, read before any further call: `runCount == runs + 1`; `thumbCorners == .perKind(macBook: .topLeft, external: corner)`; `drawnThumbCorner == corner`; `externalThumbCorner` holds that corner's wire string. A thumb in `corner` on the Magic Trackpad fires and one bottom-left does not, and top-left on the MacBook still fires. | R5 scenario 1 (Bottom right) and "saved at once"; R7 scenario 4 (Top right, "at once"); the design's persisted table for the wire strings |
| T21 | R5 | World | Given T20's world. (a) A thumb rests bottom-right on the Magic Trackpad; the External corner becomes Bottom right; one finger taps without the thumb lifting. (b) In a fresh world, a thumb rests bottom-left on the Magic Trackpad and a tap fires; the External corner becomes Bottom right; one finger taps again without the thumb lifting. (c) In a fresh world, a thumb rests top-left on the MacBook; the External corner becomes Bottom right; one finger taps the MacBook. Then (a) fires, (b) fires only its first tap, and (c) fires. | R5: a thumb already down "is judged afresh at once: it anchors if it rests in the new corner, and otherwise it is not anchored"; the design's "a thumb resting there still anchors" for the other kind |
| T22 | R5 | World | Given T20's world. When `setThumbCorner(.topRight)`. Then `thumbCorners == .perKind(macBook: .topRight, external: .bottomLeft)`. The Magic Trackpad still fires with the thumb bottom-left. The MacBook fires top-right and not top-left. | R5 scenario 3 |
| T23 | R1, R2, R5 | World | Given T20's world. When the External corner is set to Bottom right, the Magic Trackpad is detached, and the world is relaunched, started and opened by hand with the MacBook alone. Then `thumbCorners == .perKind(macBook: .topLeft, external: .bottomRight)` and `drawnThumbCorner == .topLeft`. | R5 scenario 2; R2 scenario 1 (both rows, set to Top left and Bottom right, after a disconnect) |
| T24 | R5, R7 | World | (a) Given T20's world with the Magic Trackpad detached, and `runs = runCount`. When `setExternalThumbCorner(.topRight)`. Then `runCount == runs`, `drawnThumbCorner == .topLeft`, and `thumbCorners` holds `external: .topRight`. When the Magic Trackpad connects again, `drawnThumbCorner == .topRight`, and the Magic Trackpad fires with the thumb top-right. (b) Given T20's world with the MacBook detached (lid closed). When `setThumbCorner(.bottomRight)`. Then `runCount == runs`, the Magic Trackpad still fires bottom-left, and `drawnThumbCorner == .bottomLeft`. | R7 scenario 3 ("keep drawing the *MacBook trackpad* corner"); R5 (the choice applies to the next thumb on that kind); the design's "re-run the trackpads only when a connected trackpad's corner changed" |
| T25 | R1, R3, R6 | World | Given a started MacBook world that does not have mixed trackpads, and `runs = runCount`. When `setExternalThumbCorner(.topRight)`. Then `thumbCorners == .single(.topLeft)`, the domain holds no `externalThumbCorner`, and `runCount == runs`. When a Magic Trackpad then connects, `thumbCorners == .perKind(macBook: .topLeft, external: .bottomLeft)`. | R6 ("applies only while the Mac has mixed trackpads"; *Bottom left* "for every user"); R1 (only seeing both kinds makes the record) |
| T26 | R5, R6 | World | Given T20's world, with the External corner set to Top right. When these steps run in order: detach the Magic Trackpad; attach it; `sleep()`; `wake()`; `relaunch()` and `start()` with both trackpads. Then after every step, `externalThumbCorner` holds `"topRight"` and `thumbCorners == .perKind(macBook: .topLeft, external: .topRight)`. | R5 (saved, survives a quit); R6 (*Bottom left* is a default, applied only the first time the Mac is mixed) |
| T27 | R2 | World | (a) Given a started MacBook world, with `withObservationTracking` armed on `launcher.thumbCorners.hasMixedTrackpads`. When a Magic Trackpad connects. Then its change handler has run. (b) Given the world of T24 (a), mixed with the Magic Trackpad detached, and tracking armed on `launcher.thumbCorners`. When `setExternalThumbCorner(.topRight)`. Then its change handler has run. | R2: "The window MUST resize to fit when the rows change", and each pop-up "shows that row's current corner". `SettingsShell`'s `Fit` loop and the rows read exactly these values. |
| T28 | R8 | World | For each thing the previous version saves (nothing; *Switch recent* turned off; the corner set to Top right; Notes put on gesture 3): given both trackpads, started, with Arc on gesture 1, the MacBook corner Bottom right and the External corner Top left. When `previousVersionSaves` decodes the record with `Build1018Settings`, applies the change and writes the record back. Then the decoded record has `handMode == .left` and `isThumbAtBottom`, which is Bottom right as its one corner for every trackpad, and has Arc on gesture 1. `relaunch()` reads `.perKind(macBook: .bottomRight, external: .topLeft)`, or a MacBook corner of `.topRight` in the corner case, and keeps the change. | R8 scenario; the wire mapping in `Settings` ("`right` is the hand whose thumb rests on the left"; plan 028); probe 02 (an older build rewrites only `settings`); `Build1018Settings`, frozen from v1.0.18 |
| T29 | R2, R3 | Value (`CopyTests`) | `Copy.thumbCornerGroupTitle == "Thumb corner:"`, `Copy.macBookTrackpadRow == "MacBook trackpad"` and `Copy.externalTrackpadRow == "External trackpad"`. The existing `Copy.thumbCornerRow == "Thumb corner"` row and the four titles, in order, stay. | the R2 and R3 literals |
| T30 | R4 | Platform function (`devicesToRun`, `LauncherPlatformTests`) | Given a listing of four devices, plain strings in this order:<br>• "built-in", ID 1, built-in, 124.8 by 76.8 mm;<br>• "magic", ID 2, external, 160 by 115 mm;<br>• "magic 2", ID 3, external, 160 by 115 mm;<br>• "unasked", ID 4, external.<br>Given these entries, in this order:<br>• ID 3 with Bottom right;<br>• ID 1 with Top left;<br>• ID 2 with Bottom left, whose trackpad carries a stale surface of 100 by 100 mm;<br>• ID 9, which nothing lists, with Top right.<br>When `devicesToRun(listing, entries)`. Then it returns exactly ("built-in", the listed ID 1, `.topLeft`), ("magic", the listed ID 2 with its listed 160 by 115 mm surface, `.bottomLeft`) and ("magic 2", the listed ID 3, `.bottomRight`), in the listing's order:<br>• "unasked" is left out;<br>• ID 9 runs nothing;<br>• each Magic Trackpad has its own entry's corner;<br>• the trackpad returned is the fresh listing's.<br>With no entries, it returns nothing. | the port's contract ("starts exactly the trackpads in `trackpads`, each with a fresh recognizer anchoring the thumb in that entry's corner"); the design's `devicesToRun` doc (the listing's order; "a listed device no entry names is left out, and an entry no listed device carries runs nothing"); the `MultitouchTrackpads.run` sketch ("the surface being the fresh listing's"); R4 |

### Verified without a test

- **R4, the real adapter's call site.** T30 proves the join. What no test reaches is that `MultitouchTrackpads.run` uses it. The checks:
  - the quick gate compiles it;
  - a read of `run` shows the devices it starts come from `devicesToRun(listTrackpads(), trackpads)`, and each session's recognizer takes that entry's `corner` and its listed trackpad's `surface`;
  - `grep -n "wanted" LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` finds nothing;
  - `grep -nE "topLeft|topRight|bottomLeft|bottomRight" LauncherKit/Sources/LauncherPlatform/MultitouchTrackpads.swift` finds nothing.

  On hardware, M2 covers it.
- **R4, recognition untouched.** `git diff main -- LauncherKit/Sources/LauncherCore/GestureRecognizer.swift LauncherKit/Sources/LauncherCore/Surface.swift` prints nothing. The recognizer suites stay green: `GestureRecognizerTests`, `EdgeContactRecognizerTests`, `SwipeTravelAndExitTests`, `WindowSwipeRecognizerTests` and `SwapRecognizerTests`. Between them they cover swipe and window-swipe directions from every corner on both surfaces, and the thumb tap and edge contacts for each corner.
- **R7, one drawn corner.** Four checks:
  - `grep -rn "drawnThumbCorner" LauncherKit/Sources/LauncherUI` finds exactly one read, in `SettingsView.body`;
  - `grep -rn "launcher.thumbCorner\b" LauncherKit` finds nothing;
  - `GestureRowView`'s guide condition reads the `showsGuide` of the corner passed to it;
  - `ThumbCornerRuleTests.theGuideShowsOnlyForTheTopLeftCorner` stays green.
- **R2, the refit.** A read shows `SettingsShell`'s `Fit` holding `hasMixedTrackpads`, taken from `launcher.thumbCorners` inside its `Observations` closure. M1 checks the refit itself.
- **R1, R5, durability across a kill.** Probe 03 (`.temp/architect/grounding/probes/03-force-quit-durability.out`) shows that a `UserDefaults` `set` survives a SIGKILL of the writer immediately after `set` returns. A read of `saveExternalCorner` shows one synchronous `set`, and a read of `setExternalThumbCorner` shows it called before `reconcile()`.
- **R3, R8, the record unchanged.** `git diff main -- LauncherKit/Sources/LauncherCore/Settings.swift` touches only `SettingsStore` and the new `SavedCorner`. `PersistenceTests` stays green with no edit: the `savedSettings` rows, the `Build106Settings` rows and `everySettingsFieldSurvivesTheStore`.
- **R1, R3, a Mac that never had both kinds.** The key-set rows in `StartAtLoginTests`, `MoveToApplicationsTests` and `WindowOrderTests` stay green with no edit.
- **R8, the replica.** When `Build1018Settings` is written, its stored fields, defaults, `HandMode` raw values and decode lines are read side by side with `git show v1.0.18:LauncherKit/Sources/LauncherCore/Settings.swift`, and match. On 2026-11-12, before this plan, `git diff v1.0.18 HEAD -- LauncherKit/Sources/LauncherCore/Settings.swift` printed nothing.
- **M1: R2, R3, R6, R7, the window, by hand.** On a MacBook, with a Magic Trackpad at hand:
  1. Quit any running copy, run `defaults delete com.domasgru.TrackpadLauncherApp.debug externalThumbCorner` (a "not found" error is fine), switch the Magic Trackpad off, then `make run`. Expected: the single *Thumb corner* row reads *Top left*, as before. All eight drawings put the thumb top-left (five gesture rows, the swipe, the window swipe and the thumb tap), and the Hold/Tap guide shows.
  2. With the window open, switch the Magic Trackpad on. Expected:
     - the single row gives way to "Thumb corner:" with two indented rows below it, *MacBook trackpad* (*Top left*) and then *External trackpad* (*Bottom left*);
     - each row's pop-up sits at the trailing edge and lists *Top left*, *Top right*, *Bottom left*, *Bottom right*;
     - *Hide background apps* sits below the two rows;
     - the window grows to fit, with no clipping and no gap;
     - all eight drawings put the thumb bottom-left, and the guide hides;
     - the layout matches the Figma node 2231-13555.
  3. Switch the Magic Trackpad off. Expected: both rows stay, the drawings return to top-left, the guide shows, and the height does not change.
  4. Set *External trackpad* to *Top right*. Expected: the drawings stay top-left.
  5. Switch the Magic Trackpad on. Expected: the drawings move to top-right, and the guide hides.
  6. Run `defaults read com.domasgru.TrackpadLauncherApp.debug externalThumbCorner`. Expected: it prints `topRight`.
- **M2: R4, R5, on hardware.** Both trackpads connected, Accessibility granted, *MacBook trackpad* set to *Top left*, *External trackpad* to *Bottom left*, and an app on gesture 2.
  1. Thumb bottom-left on the Magic Trackpad, two-finger tap. Expected: the app comes forward, and the Magic Trackpad pulses.
  2. Thumb bottom-left on the MacBook, two-finger tap. Expected: no gesture.
  3. Thumb top-left on the MacBook, two-finger tap. Expected: the app comes forward.
  4. Thumb bottom-left on the Magic Trackpad, slide two fingers right. Expected: the switcher shows and moves to older apps.
  5. Rest two fingers on the Magic Trackpad and tap its bottom-left corner with the thumb. Expected: a swap.
  6. Rest the thumb bottom-left on the Magic Trackpad and tap two fingers on the MacBook. Expected: no gesture.
  7. Rest the thumb bottom-right on the Magic Trackpad and set *External trackpad* to *Bottom right*. Without lifting the thumb, tap two fingers. Expected: the app comes forward.
  8. Turn Bluetooth off and connect the Magic Trackpad by its cable. Expected: it still anchors in the *External trackpad* corner.
  9. With an external display attached, close the lid. Expected: the Magic Trackpad still anchors in the *External trackpad* corner.
- **M3: R8, the real downgrade.** On a Release-configuration build in /Applications, whose defaults domain is `com.domasgru.TrackpadLauncherApp`:
  1. Build this branch with `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Release -derivedDataPath build/release`, copy `Trackpad Launcher.app` into /Applications and open it. With both trackpads connected, set *MacBook trackpad* to *Bottom right* and *External trackpad* to *Top left*, then quit.
  2. Install v1.0.18 from its GitHub release disk image over it, and open it. Expected: one *Thumb corner* row reading *Bottom right*. The thumb anchors bottom-right on both trackpads, and every other setting is as it was.
  3. In v1.0.18, turn *Switch recent* off, then quit. Run `defaults read com.domasgru.TrackpadLauncherApp externalThumbCorner`. Expected: it prints `topLeft`.
  4. Copy this branch's Release build into /Applications again, and open it. Expected: *MacBook trackpad* reads *Bottom right*, *External trackpad* reads *Top left*, and *Switch recent* is off.

## Slices

There are three slices. S1 is the prefactor the design names as its next step. It changes nothing a user sees, and it proves the real adapter's join (T30). S2 makes a MacBook mixed and gives each trackpad its own kind's corner: everything a user meets at the trackpads. S3 adds the two rows and the External intent, so that either corner can be changed, and proves the round trip through the previous version. Each slice lands green on the quick gate.

### S1: Every trackpad runs with a corner of its own

**What to build:** nothing a user can see changes. Each trackpad is run with a corner resolved for it, and the window draws from one value. The pieces:
- `ThumbCorners`, whole, as the design gives it;
- `TrackpadRun`, and `TrackpadHardware.run(_ trackpads: [TrackpadRun], …)` with no `corner:` parameter;
- `devicesToRun(_:_:)`, internal and pure, beside `trackpadKind(product:isBuiltIn:)`;
- both adapters: the real one replaces its `wanted` filter with `devicesToRun`, and the fake builds each recognizer from its entry;
- `Run`, holding `[TrackpadRun]`;
- `Launcher.thumbCorners` and `drawnThumbCorner`, replacing `thumbCorner`. With no External corner yet, `thumbCorners` is always `.single(settings.thumbCorner)`;
- `SettingsView.body`, which reads `drawnThumbCorner` once and passes `corner` to `GestureRowView` (illustration and guide) and to `SwitcherSection`. The single row's pop-up reads `thumbCorners.corner(for: .builtIn)`.

**Blocked by:** None (can start immediately).

**Requirements:** R4, in part: the real adapter runs each listed device that was asked for, with that device's own entry's corner. Nothing a user sees changes yet.

**Test scenarios:** T30.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-swiftui`

- [ ] The quick gate is green, and the existing suites change only mechanically: the `launcher.thumbCorner` reads become `thumbCorners == .single(…)`, and the fake's `run` takes `[TrackpadRun]`.
- [ ] The "R4, the real adapter's call site" check passes, and so do the first two greps of the "R7, one drawn corner" check.

### S2: A Magic Trackpad beside the MacBook anchors in its own corner

**What to build:** the first time a MacBook sees its own trackpad and a Magic Trackpad connected at the same time, it has mixed trackpads, for good. From then on the Magic Trackpad anchors the thumb bottom-left, and the MacBook keeps its corner. The illustrations follow whichever trackpad is connected. This holds whether the trackpads arrive by hot-plug, at a start, at a wake, at a login start or at a hand-over, and a kill at any point spends no first run. A Mac without mixed trackpads behaves exactly as today. The window keeps its one row, which is now the MacBook trackpad's corner, until S3. The pieces:
- `SettingsStore.loadExternalCorner()` and `saveExternalCorner(_:)`, with `SavedCorner`;
- `Launcher`'s `externalCorner`, loaded in `init` beside `store.load()`, observed;
- detection in `reconcile()`;
- the doc comments of `start()` and `ThumbCorner`;
- the test-side handles listed under Strategy.

**Blocked by:** S1.

**Requirements:** R1, R3, R4 and R6. R2's model part: `thumbCorners` turns `.perKind` and stays so. R7's connection-driven switch.

**Test scenarios:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-data`

- [ ] The six rows in `checks/01` rest the Magic Trackpad's thumb bottom-left and assert what they asserted before. No other existing row changes.
- [ ] The quick gate is green. These checks pass: "R4, recognition untouched"; "R3, R8, the record unchanged"; "R1, R3, a Mac that never had both kinds"; and the probe 03 read under "R1, R5, durability across a kill".
- [ ] The entries of `docs/domain-model.md` that the architect already updated match what this slice built: *Thumb corner*, *Mixed trackpads*, *Trackpad*, *Anchor corner*, *Edge contact* and *First run*. Where the build departs from an entry, the entry is corrected.
- [ ] M2 steps 1 to 6, 8 and 9 pass by hand, once a Magic Trackpad is connected.

### S3: Two thumb corner rows, and changing either corner

**What to build:** once the Mac has mixed trackpads, the settings window shows "Thumb corner:", then the *MacBook trackpad* and *External trackpad* rows. It shows them whether or not a Magic Trackpad is connected, and it resizes when they appear. Choosing a corner in either row:
- changes only that kind's corner;
- is saved at once;
- re-judges a thumb already down on that kind;
- redraws the illustrations only when that corner is the one in view.

After a downgrade to v1.0.18 and an upgrade back, both corners return, whatever the previous version saved. The pieces:
- `Launcher.setExternalThumbCorner(_:)`;
- `ThumbCornerRows` and `CornerPicker`;
- the three new `Copy` strings;
- `SettingsShell.Fit.hasMixedTrackpads`;
- `Build1018Settings` and `World.previousVersionSaves(_:)`.

**Blocked by:** S2.

**Requirements:** R2, R5 and R8. R6's "the user can change it in the settings window". R7's corner changes, in view and out of view.

**Test scenarios:** T20, T21, T22, T23, T24, T25, T26, T27, T28, T29.

**Skills:** `macos-dev-workflow:swift-testing-pro`, `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:axiom-macos`, `macos-dev-workflow:axiom-data`

- [ ] The quick gate is green. These checks pass: "R7, one drawn corner", "R2, the refit" and "R8, the replica".
- [ ] The entries of `docs/domain-model.md` that the architect already updated match what this slice built: *Settings window* and *Hide background apps setting*. Where the build departs from an entry, the entry is corrected.
- [ ] M1, M2 step 7 and M3 pass by hand.
