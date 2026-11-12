import Foundation
import LauncherCore
import Testing

/// A Mac that once had a built-in and an external trackpad connected at the same time has a thumb corner for each kind.
@MainActor @Suite struct MixedTrackpadsTests {
    private let both: [Trackpad] = [.macBook14, .magicTrackpad]
    private let mixed = ThumbCorners.perKind(macBook: .topLeft, external: .bottomLeft)

    private func externalCornerKey(_ world: World) -> String? { world.suiteDomain()["externalThumbCorner"] as? String }

    private func startedWorld(attached: [Trackpad], gestures: [Gesture: String] = [.one: "Arc"]) -> World {
        let world = World(apps: ["Arc", "Figma"], attached: attached)
        world.launcher.start()
        for (gesture, name) in gestures { world.launcher.setAssignment(.app(world.app(name)), for: gesture) }
        return world
    }

    private func firedCount(_ world: World) -> Int { world.system.broughtToFront.count }

    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.launcher.switcher == nil
    }

    private func opposite(of corner: ThumbCorner) -> ThumbCorner {
        switch corner {
        case .topLeft: .bottomRight
        case .topRight: .bottomLeft
        case .bottomLeft: .topRight
        case .bottomRight: .topLeft
        }
    }

    // MARK: Detection

    enum Arrival: CaseIterable, CustomStringConvertible {
        case hotPlugged, lidClosedThenOpened, whileAsleep

        var description: String {
            switch self {
            case .hotPlugged: "a Magic Trackpad connects while the app runs"
            case .lidClosedThenOpened: "the MacBook's trackpad comes back beside a Magic Trackpad"
            case .whileAsleep: "a Magic Trackpad connects while the Mac sleeps"
            }
        }
    }

    @Test(arguments: Arrival.allCases) func theFirstTimeBothKindsAreConnectedTheMacHasMixedTrackpadsWithoutARun(
        arrival: Arrival
    ) {
        let world = World(apps: ["Arc"], attached: arrival == .lidClosedThenOpened ? [.magicTrackpad] : [.macBook14])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .two)
        let record = world.settingsRecordBytes()
        let runs = world.hardware.runCount
        #expect(record != nil)
        #expect(world.launcher.thumbCorners == .single(.topLeft))
        #expect(externalCornerKey(world) == nil)

        switch arrival {
        case .hotPlugged: world.hardware.attach(.magicTrackpad)
        case .lidClosedThenOpened: world.hardware.attach(.macBook14)
        case .whileAsleep:
            world.hardware.sleep()
            world.hardware.attachWhileAsleep(.magicTrackpad)
            world.hardware.wake()
        }

        #expect(world.launcher.thumbCorners == mixed)
        #expect(world.launcher.drawnThumbCorner == .bottomLeft)
        #expect(externalCornerKey(world) == "bottomLeft")
        #expect(world.settingsRecordBytes() == record)
        #expect(world.hardware.runCount == runs + 1)
    }

    @Test func aStartWithBothTrackpadsRecordsItWithoutSavingTheSettingsRecord() {
        let world = World(attached: both)

        world.launcher.start()

        #expect(world.launcher.thumbCorners == mixed)
        #expect(world.hardware.runCount == 1)
        #expect(world.settingsRecordBytes() == nil)
        #expect(Set(world.suiteDomain().keys) == ["externalThumbCorner"])
    }

    @Test func aMacWithOnlyExternalTrackpadsKeepsTheSingleCorner() {
        let world = World(apps: ["Arc"], attached: [])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        for second in [Trackpad.magicTrackpad, .secondMagicTrackpad] {
            world.hardware.attach(second)
            #expect(world.launcher.thumbCorners == .single(.topLeft))
            #expect(world.launcher.drawnThumbCorner == .topLeft)
            #expect(externalCornerKey(world) == nil)
        }
        for trackpad in [Trackpad.magicTrackpad, .secondMagicTrackpad] {
            world.tap(1, on: trackpad, thumbIn: .bottomLeft)
            #expect(firedCount(world) == 0)
        }
        world.tap(1, on: .magicTrackpad, thumbIn: .topLeft)
        #expect(firedCount(world) == 1)
        world.tap(1, on: .secondMagicTrackpad, thumbIn: .topLeft)
        #expect(firedCount(world) == 2)
    }

    @Test func aMagicMouseConnectingDoesNotGiveTheMacMixedTrackpads() {
        let world = World()
        world.launcher.start()

        world.hardware.connectMagicMouse()

        #expect(world.launcher.thumbCorners == .single(.topLeft))
        #expect(externalCornerKey(world) == nil)
    }

    @Test func nothingTheUserDoesAndNoDisconnectOrRelaunchClearsTheRecord() {
        let world = startedWorld(attached: both)
        world.launcher.openedByHand()
        var recorded: [Bool] = []
        func step(_ action: () -> Void) {
            action()
            recorded.append(world.launcher.thumbCorners.hasMixedTrackpads && externalCornerKey(world) == "bottomLeft")
        }

        step { world.hardware.detach(Trackpad.magicTrackpad.id) }
        step { world.hardware.sleep() }
        step { world.hardware.wake() }
        step {
            world.relaunch().start()
            world.launcher.openedByHand()
        }
        step { world.launcher.setThumbCorner(.topRight) }
        step { world.launcher.setSwipe(on: !world.launcher.isSwipeOn) }
        step { world.launcher.setSwap(on: !world.launcher.isSwapOn) }
        step { world.launcher.setWindowSwipe(on: !world.launcher.isWindowSwipeOn) }
        step { world.launcher.setLaunchAnimation(on: !world.launcher.isLaunchAnimationOn) }
        step { world.launcher.setHideBackgroundApps(on: !world.launcher.isHideBackgroundAppsOn) }
        step { world.launcher.setAssignment(nil, for: .one) }
        step { world.launcher.askForScreenRecording() }
        step { world.launcher.closeWindow() }
        step { world.hardware.detach(Trackpad.macBook14.id) }
        step { world.hardware.attach(.macBook14) }
        step { world.relaunch().start() }

        #expect(recorded == Array(repeating: true, count: 16))
    }

    @Test(arguments: ["sideways" as any Sendable, 1 as any Sendable]) func aValueThisBuildCannotReadStillMeansMixedTrackpads(
        unreadable: any Sendable
    ) {
        let world = World()
        world.freshStore().save(Settings())
        world.seedSuite(["externalThumbCorner": unreadable])

        world.relaunch().start()

        #expect(world.launcher.thumbCorners == mixed)
        #expect(sameValue(world.suiteDomain()["externalThumbCorner"], unreadable))
        world.hardware.attach(.magicTrackpad)
        #expect(world.launcher.thumbCorners == mixed)
        #expect(sameValue(world.suiteDomain()["externalThumbCorner"], unreadable))
    }

    private func sameValue(_ saved: Any?, _ seeded: any Sendable) -> Bool {
        if let seeded = seeded as? String { return saved as? String == seeded }
        if let seeded = seeded as? Int { return saved as? Int == seeded }
        return false
    }

    // MARK: Upgrading

    @Test func aMacBookOnTheReleasedRecordGetsTheExternalCornerWhenAMagicTrackpadConnects() {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(PersistenceTests.savedSettings.utf8))
        world.relaunch().start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .two)
        #expect(world.launcher.thumbCorners == .single(.topRight))

        world.hardware.attach(.magicTrackpad)

        #expect(world.launcher.thumbCorners == .perKind(macBook: .topRight, external: .bottomLeft))
        world.tap(2, on: .magicTrackpad, thumbIn: .bottomLeft)
        #expect(firedCount(world) == 1)
        world.tap(2, thumbIn: .topRight)
        #expect(firedCount(world) == 2)
    }

    // MARK: Each trackpad anchors in its own corner

    @Test func eachTrackpadFiresOnlyWithTheThumbInItsOwnKindsCorner() {
        let world = startedWorld(attached: both, gestures: [.two: "Arc"])
        var counts: [Int] = []

        world.tap(2, on: .magicTrackpad, thumbIn: .bottomLeft)
        counts.append(firedCount(world))
        world.tap(2, on: .macBook14, thumbIn: .bottomLeft)
        counts.append(firedCount(world))
        world.tap(2, on: .macBook14, thumbIn: .topLeft)
        counts.append(firedCount(world))
        world.tap(2, on: .magicTrackpad, thumbIn: .topLeft)
        counts.append(firedCount(world))

        #expect(counts == [1, 1, 2, 2])
        #expect(world.hardware.feedback == [Trackpad.magicTrackpad.id, Trackpad.macBook14.id])
    }

    @Test func aSwapFromTheMagicTrackpadsBottomLeftCornerOnly() {
        let bottom = World.switcherWorld(attached: both)
        bottom.swap(thumbAtMM: (10, 105), on: .magicTrackpad)
        #expect(bottom.system.broughtToFront == [bottom.app("Mail")])
        #expect(bottom.hardware.pulses.map(\.trackpad) == [Trackpad.magicTrackpad.id])

        let top = World.switcherWorld(attached: both)
        top.swap(thumbAtMM: (10, 10), on: .magicTrackpad)
        #expect(nothingHappened(top))
    }

    @Test func aSwipeAndAWindowSwipeFromTheMagicTrackpadsBottomLeftCornerKeepTheirDirections() {
        let apps = World.switcherWorld(attached: both)
        apps.swipe(3.5, 12, lift: false, thumbAtMM: (10, 105), on: .magicTrackpad)
        #expect(apps.launcher.switcher?.selectedApp.name == "Mail")

        let topLeft = World.switcherWorld(attached: both)
        topLeft.swipe(3.5, 12, lift: false, thumbAtMM: (10, 10), on: .magicTrackpad)
        #expect(topLeft.launcher.switcher == nil)

        let windows = World.windowWorld(visible: ["Docs", "Mail", "News"], attached: both)
        windows.windowSwipe(3.5, 12, lift: false, thumbAtMM: (10, 105), on: .magicTrackpad)
        #expect(windows.launcher.windowSwitcher?.selection.selected == 1)
    }

    @Test func aThumbOnOneTrackpadNeverArmsTapsOnTheOther() {
        let resting = startedWorld(attached: both, gestures: [.two: "Arc"])
        resting.play(TouchScript(.magicTrackpad).thumb(atMM: (10, 105)), on: .magicTrackpad)
        resting.play(TouchScript(.macBook14).tap(fingers: 2), on: .macBook14)
        #expect(firedCount(resting) == 0)

        let other = startedWorld(attached: both, gestures: [.two: "Arc"])
        other.play(TouchScript(.macBook14).thumb(atMM: (10, 10)), on: .macBook14)
        other.play(TouchScript(.magicTrackpad).tap(fingers: 2), on: .magicTrackpad)
        #expect(firedCount(other) == 0)

        let control = startedWorld(attached: both, gestures: [.two: "Arc"])
        control.tap(2, on: .macBook14, thumbIn: .topLeft)
        #expect(firedCount(control) == 1)
    }

    @Test func edgeContactsFollowTheCornerOfTheTrackpadTheyLandOn() {
        let world = startedWorld(attached: both, gestures: [.one: "Arc", .two: "Figma"])

        world.play(
            TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2, atMM: (115.8, 53.76)), on: .macBook14)
        #expect(world.system.broughtToFront == [world.app("Arc")])

        world.play(
            TouchScript(.magicTrackpad).thumb(atMM: (10, 105)).tap(fingers: 2, atMM: (151, 80.5)), on: .magicTrackpad)
        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Figma")])
    }

    @Test(arguments: [
        ("topLeft", ThumbCorner.topLeft), ("topRight", .topRight), ("bottomLeft", .bottomLeft),
        ("bottomRight", .bottomRight),
    ]) func eachSavedExternalCornerAnchorsEveryMagicTrackpad(wire: String, corner: ThumbCorner) {
        let world = World(apps: ["Arc"], attached: both)
        var settings = Settings()
        settings.thumbCorner = .topLeft
        settings.assignments[.one] = AssignedApp(world.app("Arc"))
        world.freshStore().save(settings)
        world.seedSuite(["externalThumbCorner": wire])

        world.relaunch().start()

        #expect(world.launcher.thumbCorners == .perKind(macBook: .topLeft, external: corner))
        world.tap(1, on: .magicTrackpad, thumbIn: corner)
        #expect(firedCount(world) == 1)
        world.tap(1, on: .magicTrackpad, thumbIn: opposite(of: corner))
        #expect(firedCount(world) == 1)
        world.tap(1, on: .macBook14, thumbIn: .topLeft)
        #expect(firedCount(world) == 2)
        world.hardware.attach(.secondMagicTrackpad)
        world.tap(1, on: .secondMagicTrackpad, thumbIn: corner)
        #expect(firedCount(world) == 3)
    }

    // MARK: Kept while a trackpad is gone, and drawn

    @Test func disconnectingTrackpadsKeepsTheMixedRecordAndDrawsTheCornerOfWhatIsConnected() {
        let world = startedWorld(attached: both)

        world.hardware.detach(Trackpad.macBook14.id)

        #expect(world.launcher.thumbCorners == mixed)
        #expect(world.launcher.drawnThumbCorner == .bottomLeft)
        world.tap(1, on: .magicTrackpad, thumbIn: .topLeft)
        #expect(firedCount(world) == 0)
        world.tap(1, on: .magicTrackpad, thumbIn: .bottomLeft)
        #expect(firedCount(world) == 1)

        world.hardware.detach(Trackpad.magicTrackpad.id)

        #expect(world.launcher.drawnThumbCorner == .topLeft)
        #expect(world.launcher.thumbCorners == mixed)
    }

    @Test func theIllustrationsFollowWhichKindIsConnectedWhileTheWindowIsOpen() {
        let world = World()
        world.launcher.start()
        world.launcher.openedByHand()
        var drawn = [world.launcher.drawnThumbCorner]

        world.hardware.attach(.magicTrackpad)
        drawn.append(world.launcher.drawnThumbCorner)
        world.hardware.detach(Trackpad.magicTrackpad.id)
        drawn.append(world.launcher.drawnThumbCorner)
        world.hardware.attach(.magicTrackpad)
        drawn.append(world.launcher.drawnThumbCorner)

        #expect(drawn == [.topLeft, .bottomLeft, .topLeft, .bottomLeft])

        let started = World(attached: both)
        started.launcher.start()
        started.launcher.openedByHand()
        #expect(started.launcher.drawnThumbCorner == .bottomLeft)
    }

    // MARK: Lifecycle

    @Test func aLoginStartOnAMacWithOneSavedCornerKeepsTheSingleRowAndItsCorner() {
        let world = LifecycleWorld(record: [.one: "Arc"], corner: .bottomRight, loginItemOn: true)
        let record = world.mac.settingsRecordBytes()

        let process = world.login()!

        #expect(process.launcher.thumbCorners == .single(.bottomRight))
        #expect(process.launcher.drawnThumbCorner == .bottomRight)
        process.tap(1, thumbIn: .bottomRight)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
        process.tap(1, thumbIn: .topLeft)
        #expect(process.system.broughtToFront.count == 1)
        #expect(world.mac.settingsRecordBytes() == record)
        #expect(Set(world.mac.suiteDomain().keys) == ["settings"])
    }

    @Test(arguments: [Opening.atLogin, .afterUpdate(withWindow: false)])
    func aSilentStartWithBothTrackpadsRecordsMixedTrackpadsAndNothingElse(opening: Opening) {
        let world = LifecycleWorld(record: [.one: "Arc"], corner: .topLeft, loginItemOn: true)
        let record = world.mac.settingsRecordBytes()

        let process = world.launch(opening, running: opening == .atLogin ? .development : .release, attached: both)

        #expect(process.window == .closed)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.mac.settingsRecordBytes() == record)
        #expect(world.mac.suiteDomain()["externalThumbCorner"] as? String == "bottomLeft")
        process.tap(1, on: .magicTrackpad, thumbIn: .bottomLeft)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
        process.tap(1, on: .magicTrackpad, thumbIn: .topLeft)
        #expect(process.system.broughtToFront.count == 1)
        process.tap(1, on: .macBook14, thumbIn: .topLeft)
        #expect(process.system.broughtToFront.count == 2)

        let next = world.login()
        #expect(next?.launcher.thumbCorners == mixed)
    }

    @Test func mixedTrackpadsRecordedAtALoginStartDoNotSpendTheFirstRun() {
        let world = LifecycleWorld(accessGranted: false)
        var atRegistration: [Settings?] = []
        var atAsk: [Settings?] = []
        world.loginItem.onRegister = { [unowned mac = world.mac] in atRegistration.append(mac.freshStore().load()) }
        world.permissions.onAsk = { [unowned mac = world.mac] in atAsk.append(mac.freshStore().load()) }

        let process = world.launch(.atLogin, attached: both)

        #expect(process.window == .closed)
        #expect(world.mac.freshStore().load() == nil)
        #expect(world.mac.suiteDomain()["externalThumbCorner"] as? String == "bottomLeft")

        process.openAgain(.byHand)

        #expect(world.loginItem.calls == ["register"])
        #expect(world.permissions.asks == [.accessibility])
        #expect(atRegistration == [nil])
        #expect(atAsk == [nil])
        #expect(world.mac.freshStore().load() != nil)
        #expect(process.launcher.thumbCorners == mixed)
    }
}
