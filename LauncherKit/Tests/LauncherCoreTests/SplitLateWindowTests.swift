import Foundation
import Testing
@testable import LauncherCore

@MainActor @Suite struct SplitLateWindowTests {
    private func B(_ name: String) -> BundleID { World.bundleID(name) }
    private func L(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .left, display: display) }
    private func R(_ display: DisplayID) -> ScreenHalf { ScreenHalf(side: .right, display: display) }

    private struct Placed: Equatable {
        let app: BundleID
        let half: ScreenHalf
    }

    private func placements(_ world: World) -> [Placed] {
        world.system.windowPlacements.map { Placed(app: $0.app, half: $0.half) }
    }

    private func world(running: [String]) -> World {
        let world = World.switcherWorld(
            apps: ["Mail", "Notes", "Safari", "Calendar", "Music", "Maps"], running: ["Mail"] + running,
            frontmost: "Mail", accessGranted: true)
        world.split("Notes", "Safari", on: .one)
        return world
    }

    private func limits(_ world: World, _ name: String) -> [Duration]? {
        world.system.launches.first { $0.app.bundleID == B(name) }?.limits
    }

    private func ending(_ world: World, _ name: String) -> LaunchBounceEnding? {
        world.system.launchEndings.last { $0.app == B(name) }?.ending
    }

    @Test func aLaunchingAppIsPlacedWhenItsFirstWindowShowsOnTheDisplayChosenAtTheGesture() {
        let world = world(running: ["Notes"])
        world.tap(1)
        #expect(placements(world) == [Placed(app: B("Notes"), half: L(World.D1))])

        world.report(.finishedLaunching, for: "Safari")
        #expect(placements(world).count == 1)

        world.system.pointerDisplayAnswer = World.D2
        world.report(.windowShown, for: "Safari")

        #expect(
            placements(world) == [Placed(app: B("Notes"), half: L(World.D1)), Placed(app: B("Safari"), half: R(World.D1))])
        #expect(world.system.pointerDisplayReads == 1)
        #expect(ending(world, "Safari") == .launchAnimation)
    }

    @Test func aWindowThatShowsAfterTheWatchRanOutIsNotPlaced() {
        let capped = world(running: ["Notes"])
        capped.tap(1)
        capped.report(.ranOut, for: "Safari")
        capped.report(.windowShown, for: "Safari")
        #expect(placements(capped) == [Placed(app: B("Notes"), half: L(World.D1))])

        let graced = world(running: ["Notes"])
        graced.tap(1)
        graced.report(.finishedLaunching, for: "Safari")
        #expect(limits(graced, "Safari") == [.seconds(2)])
        graced.report(.ranOut, for: "Safari")
        graced.report(.windowShown, for: "Safari")
        #expect(placements(graced) == [Placed(app: B("Notes"), half: L(World.D1))])
        #expect(graced.system.splits.first?.cap == .seconds(10))
    }

    @Test func aRunningAppWithoutAWindowIsFollowedAndPlacedOnceWhenItShows() {
        let world = world(running: ["Notes", "Safari"])
        world.launcher.setHideBackgroundApps(on: true)
        world.tap(1)

        let arrival = world.system.splits.first?.arrival
        #expect(arrival?.first.entrance == .running(animates: true, followed: true))
        #expect(arrival?.second.entrance == .running(animates: true, followed: true))
        #expect(world.system.launches.map(\.app.bundleID) == [B("Notes"), B("Safari")])
        #expect(world.system.launches.allSatisfy { !$0.bouncing && $0.cap == .seconds(10) })
        #expect(
            placements(world) == [Placed(app: B("Notes"), half: L(World.D1)), Placed(app: B("Safari"), half: R(World.D1))])

        world.report(.finishedLaunching, for: "Safari")
        #expect(limits(world, "Safari") == [.seconds(2)])
        world.report(.windowShown, for: "Safari")

        #expect(placements(world).count == 3)
        #expect(placements(world).last == Placed(app: B("Safari"), half: R(World.D1)))
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.splits.count == 1)
        #expect(world.system.kept == [KeptApps(front: B("Notes"), beside: B("Safari"))])

        let late = self.world(running: ["Notes", "Safari"])
        late.tap(1)
        late.report(.ranOut, for: "Safari")
        late.report(.windowShown, for: "Safari")
        #expect(placements(late).count == 2)
    }

    private func laterGestureWorld() -> World {
        let world = world(running: ["Notes", "Calendar", "Music"])
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.split("Calendar", "Music", on: .three)
        world.launcher.setAssignment(.app(world.app("Maps")), for: .five)
        _ = world.trash("Maps")
        return world
    }

    @Test func aLaterGestureThatBringsAnAppToFrontCancelsThePendingPlacement() {
        let oneApp = laterGestureWorld()
        oneApp.tap(1)
        oneApp.tap(2)
        oneApp.report(.finishedLaunching, for: "Safari")
        oneApp.report(.windowShown, for: "Safari")
        #expect(placements(oneApp) == [Placed(app: B("Notes"), half: L(World.D1))])
        #expect(ending(oneApp, "Notes") == .quietFade)
        #expect(ending(oneApp, "Safari") == .launchAnimation)

        let split = laterGestureWorld()
        split.tap(1)
        split.tap(3)
        split.report(.windowShown, for: "Safari")
        #expect(
            placements(split) == [
                Placed(app: B("Notes"), half: L(World.D1)), Placed(app: B("Calendar"), half: L(World.D1)),
                Placed(app: B("Music"), half: R(World.D1)),
            ])
    }

    @Test func aLaterSplitGesturePlacesTheWindowOnItsOwnDisplay() {
        let world = laterGestureWorld()
        world.tap(1)
        world.system.pointerDisplayAnswer = World.D2
        world.tap(1)
        world.report(.windowShown, for: "Safari")
        #expect(placements(world).filter { $0.app == B("Safari") } == [Placed(app: B("Safari"), half: R(World.D2))])
    }

    @Test func silentGesturesAndSwipesDoNotCancelAPendingPlacement() {
        let world = laterGestureWorld()
        world.tap(1)
        world.tap(4)
        world.tap(5)
        world.swipe(3.5)
        world.report(.windowShown, for: "Safari")
        #expect(placements(world).last == Placed(app: B("Safari"), half: R(World.D1)))
    }

    @Test func aOneAppGestureForAFollowedAppEndsTheFollowAndPlaysItsOwnAnimation() {
        let world = world(running: ["Notes", "Safari"])
        world.launcher.setAssignment(.app(world.app("Safari")), for: .two)
        world.tap(1)
        world.tap(2)

        #expect(ending(world, "Safari") == .quietFade)
        #expect(world.system.broughtToFront.map(\.bundleID) == [B("Safari")])
        #expect(world.system.launchAnimations.map(\.bundleID) == [B("Safari")])

        let count = placements(world).count
        world.report(.windowShown, for: "Safari")
        #expect(placements(world).count == count)
    }
}
