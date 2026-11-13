import Foundation
import Testing
@testable import LauncherCore

@MainActor @Suite struct SplitPlacingTests {
    private func B(_ name: String) -> BundleID { World.bundleID(name) }
    private func L(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .left, display: display) }
    private func R(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .right, display: display) }

    private func world(running: [String], accessGranted: Bool) -> World {
        let world = World.switcherWorld(
            apps: ["Mail", "Notes", "Safari"], running: ["Mail"] + running, frontmost: "Mail",
            accessGranted: accessGranted)
        world.split("Notes", "Safari", on: .one)
        return world
    }

    private func placements(_ world: World) -> [RecordingSystemActions.WindowPlacement] {
        world.system.windowPlacements
    }

    @Test func aSplitGesturePlacesBothWindowsOnTheDisplayUnderThePointerAtEveryFire() {
        let world = world(running: ["Notes", "Safari"], accessGranted: true)
        var splitsAtEachPlacement: [Int] = []
        world.system.onPlaceFrontWindow = { [unowned world] in splitsAtEachPlacement.append(world.system.splits.count) }

        world.tap(1)

        #expect(placements(world) == [.init(app: B("Notes"), half: L(World.D1)), .init(app: B("Safari"), half: R(World.D1))])
        #expect(splitsAtEachPlacement == [1, 1], "the apps come forward before any window is placed")
        #expect(world.system.pointerDisplayReads == 1)

        world.tap(1)
        #expect(placements(world).count == 4)
        #expect(Array(placements(world)[2...]) == Array(placements(world)[..<2]))

        world.system.pointerDisplayAnswer = World.D2
        world.tap(1)
        #expect(
            Array(placements(world)[4...])
                == [.init(app: B("Notes"), half: L(World.D2)), .init(app: B("Safari"), half: R(World.D2))])

        world.system.pointerDisplayAnswer = nil
        world.tap(1)
        #expect(world.system.splits.count == 4)
        #expect(placements(world).count == 6)
    }

    @Test func withoutAccessibilityNothingIsReadOrPlacedAndBothAppsStillComeForward() throws {
        let world = world(running: ["Notes"], accessGranted: false)
        let hintBefore = world.launcher.inactiveNotice
        let recordingHintBefore = world.launcher.screenRecordingHint
        world.tap(1)
        #expect(world.system.pointerDisplayReads == 0)
        #expect(world.system.windowPlacements.isEmpty)
        let arrival = try #require(world.system.splits.first).arrival
        #expect(arrival.first.entrance == .running(animates: true, followed: false))
        #expect(arrival.second.entrance == .launching(watch: .bouncing))

        world.report(.finishedLaunching, for: "Safari")
        world.report(.windowShown, for: "Safari")
        #expect(world.system.pointerDisplayReads == 0)
        #expect(world.system.windowPlacements.isEmpty)
        #expect(world.launcher.showsAccessibilityHint)
        #expect(Copy.accessibilityHint == "Allow Accessibility access to make trackpad gestures work reliably.")
        #expect(world.launcher.inactiveNotice == hintBefore)
        #expect(world.launcher.screenRecordingHint == recordingHintBefore)
    }

    @Test func theSecondAppTakesTheFocusOnlyWhileTheOtherAppsStay() throws {
        for accessGranted in [true, false] {
            let world = world(running: ["Notes", "Safari"], accessGranted: accessGranted)
            world.tap(1)
            #expect(try #require(world.system.splits.last).arrival.secondEntry == .focused)

            world.launcher.setHideBackgroundApps(on: true)
            world.tap(1)
            #expect(try #require(world.system.splits.last).arrival.secondEntry == .unfocused)
        }
    }

    @Test func theAppOnThePointersSideIsFocusedAndKeptInFrontByTheHide() throws {
        let world = world(running: ["Notes", "Safari"], accessGranted: true)
        world.launcher.setHideBackgroundApps(on: true)

        world.tap(1)
        #expect(try #require(world.system.splits.last).arrival.focus == .left)
        #expect(world.system.kept.last == KeptApps(front: B("Notes"), beside: B("Safari")))

        world.system.pointerSideAnswer = .right
        world.tap(1)
        let arrival = try #require(world.system.splits.last).arrival
        #expect(arrival.focus == .right)
        #expect(arrival.focused.app.bundleID == B("Safari") && arrival.other.app.bundleID == B("Notes"))
        #expect(world.system.kept.last == KeptApps(front: B("Safari"), beside: B("Notes")))
        #expect(world.system.pointerSideReads == [World.D1, World.D1], "the side of the display the split goes to")
    }

    @Test func withoutAccessibilityThePointerIsNotReadAndTheFirstAppIsFocused() throws {
        let world = world(running: ["Notes", "Safari"], accessGranted: false)
        world.system.pointerSideAnswer = .right
        world.tap(1)
        #expect(try #require(world.system.splits.last).arrival.focus == .left)
        #expect(world.system.pointerSideReads.isEmpty)
    }

    @Test func aLaunchingAppIsNotPlacedByTheGestureItself() {
        let world = world(running: ["Notes"], accessGranted: true)
        world.tap(1)
        #expect(placements(world) == [.init(app: B("Notes"), half: L(World.D1))])
    }
}
