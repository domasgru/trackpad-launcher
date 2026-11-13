import Foundation
import Testing
@testable import LauncherCore

@MainActor @Suite struct SplitFiringTests {
    private func B(_ name: String) -> BundleID { World.bundleID(name) }

    private let tenSeconds = Duration.seconds(10)

    /// Mail, Notes and Safari installed; Mail frontmost; the apps in `running` have a process too. Notes and Safari are
    /// on `.one`. The launch animation setting is on, the hide setting off.
    private func world(running: [String] = ["Notes", "Safari"], accessGranted: Bool = false) -> World {
        let world = World.switcherWorld(
            apps: ["Mail", "Notes", "Safari"], running: ["Mail"] + running, frontmost: "Mail",
            accessGranted: accessGranted)
        world.split("Notes", "Safari", on: .one)
        return world
    }

    private func arrival(_ world: World) throws -> SplitArrival {
        try #require(world.system.splits.first).arrival
    }

    private func running(_ app: AppEntry, animates: Bool = true) -> SplitApp {
        SplitApp(app, .running(animates: animates, followed: false))
    }

    @Test func aSplitGestureOfTwoRunningAppsPulsesOnceFirstAndHandsBothAppsOverInOneCall() {
        let world = world()
        var feedbackAtTheCall: [TrackpadID]?
        world.system.onBringToFrontSplit = { [unowned world] in feedbackAtTheCall = world.hardware.feedback }

        world.tap(1)

        #expect(world.system.splits.count == 1)
        #expect(world.system.splits.first?.cap == tenSeconds)
        #expect(
            world.system.splits.first?.arrival
                == SplitArrival(
                    first: running(world.app("Notes")), second: running(world.app("Safari")), secondEntry: .focused))
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(feedbackAtTheCall == [Trackpad.macBook14.id], "the pulse comes first")
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.launches.isEmpty)
    }

    @Test func aMissingAppsOfTheSplitAreWatchedAndBounceInRowOrder() throws {
        let both = world(running: [])
        both.tap(1)
        #expect(both.system.bounces.map(\.app) == [both.app("Notes"), both.app("Safari")])
        let bounced = try arrival(both)
        #expect(bounced.first.entrance == .launching(watch: .bouncing))
        #expect(bounced.second.entrance == .launching(watch: .bouncing))

        let safariLaunches = world(running: ["Notes"])
        safariLaunches.tap(1)
        let a = try arrival(safariLaunches)
        #expect(a.first == running(safariLaunches.app("Notes")))
        #expect(a.second == SplitApp(safariLaunches.app("Safari"), .launching(watch: .bouncing)))
        #expect(safariLaunches.system.bounces.map(\.app) == [safariLaunches.app("Safari")])

        let notesLaunches = world(running: ["Safari"])
        notesLaunches.tap(1)
        let b = try arrival(notesLaunches)
        #expect(b.first == SplitApp(notesLaunches.app("Notes"), .launching(watch: .bouncing)))
        #expect(b.second == running(notesLaunches.app("Safari")))
        #expect(notesLaunches.system.bounces.map(\.app) == [notesLaunches.app("Notes")])
    }

    @Test func withTheAnimationOffARunningAppIsOnlyBroughtForwardAndALaunchingOneIsNotWatched() throws {
        let world = world(running: ["Notes"])
        world.launcher.setLaunchAnimation(on: false)

        world.tap(1)

        let arrival = try arrival(world)
        #expect(arrival.first == running(world.app("Notes"), animates: false))
        #expect(arrival.second == SplitApp(world.app("Safari"), .launching(watch: nil)))
        #expect(world.system.launches.isEmpty)
    }

    @Test func withTheAnimationOffAndTheHideOnBothLaunchesAreWatchedWithoutBouncing() throws {
        let world = world(running: [])
        world.launcher.setLaunchAnimation(on: false)
        world.launcher.setHideBackgroundApps(on: true)

        world.tap(1)

        let arrival = try arrival(world)
        #expect(arrival.first.entrance == .launching(watch: .unseen))
        #expect(arrival.second.entrance == .launching(watch: .unseen))
        #expect(world.system.launches.map(\.app) == [world.app("Notes"), world.app("Safari")])
        #expect(world.system.bounces.isEmpty)
    }

    @Test func aSecondAppWhoseLaunchIsAlreadyWatchedKeepsItsOneWatch() throws {
        let world = world(running: ["Notes"])
        world.launcher.setAssignment(.app(world.app("Safari")), for: .two)
        world.tap(2)
        let watched = world.system.launches
        #expect(watched.map(\.app) == [world.app("Safari")])

        world.tap(1)

        let arrival = try arrival(world)
        #expect(arrival.first == running(world.app("Notes")))
        #expect(arrival.second == SplitApp(world.app("Safari"), .alreadyLaunching))
        #expect(world.system.launches == watched)
    }

    @Test func anAppWithAProcessMacOSListsButCommandTabDoesNotShowsIsRunning() throws {
        let world = world(running: ["Notes"])
        world.startProcess("Safari")

        world.tap(1)

        #expect(try arrival(world).second == running(world.app("Safari")))
    }

    @Test func aMissingAppOfASplitLeavesTheOneAppGestureItsSplitWouldBeAlone() throws {
        enum Case: CaseIterable { case safariTrashed, notesTrashed, bothTrashed, safariTrashedNotesNotRunning }
        for kind in Case.allCases {
            let running: [String] = kind == .safariTrashedNotesNotRunning ? ["Safari"] : ["Notes", "Safari"]
            func build(split: Bool) -> World {
                let world = world(running: running, accessGranted: true)
                world.launcher.setHideBackgroundApps(on: true)
                if !split {
                    world.launcher.removeSecondApp(for: .one)
                    if kind == .notesTrashed {
                        world.launcher.setAssignment(.app(world.app("Safari")), for: .one)
                    }
                }
                switch kind {
                case .safariTrashed, .safariTrashedNotesNotRunning: world.trash("Safari")
                case .notesTrashed: world.trash("Notes")
                case .bothTrashed:
                    world.trash("Notes")
                    if split { world.trash("Safari") }
                }
                return world
            }
            let split = build(split: true)
            let twin = build(split: false)

            split.tap(1)
            twin.tap(1)

            func record(_ world: World) -> [String] {
                [
                    "\(world.system.broughtToFront.map(\.bundleID.rawValue))",
                    "\(world.system.launchAnimations.map(\.bundleID.rawValue))",
                    "\(world.system.launches.map { [$0.app.bundleID.rawValue, "\($0.bouncing)", "\($0.cap)"] })",
                    "\(world.system.kept)", "\(world.hardware.feedback)",
                ]
            }
            #expect(record(split) == record(twin), "\(kind)")
            #expect(split.system.splits.isEmpty, "\(kind)")
            #expect(split.system.windowPlacements.isEmpty, "\(kind)")
            #expect(split.system.pointerDisplayReads == 0, "\(kind)")
            if kind == .bothTrashed {
                #expect(record(split) == ["[]", "[]", "[]", "[]", "[]"])
            }
        }
    }

    @Test func aSplitGestureKeepsBothAppsWhenTheHidesAndTheSplitCallComeInTheSameTurn() {
        let world = world()
        world.launcher.setHideBackgroundApps(on: true)
        var splitsAtTheHide: Int?
        world.system.onHideOtherApps = { [unowned world] in splitsAtTheHide = world.system.splits.count }

        world.tap(1)

        #expect(world.system.kept == [KeptApps(front: B("Notes"), beside: B("Safari"))])
        #expect(splitsAtTheHide == 1)
        #expect(world.system.hidesOthers == [B("Notes")])
        #expect(world.system.hiddenApps == [B("Mail")])
    }

    private func neitherHidden(_ world: World, _ step: String) {
        #expect(world.system.hiddenApps.contains(B("Notes")) == false, "Notes stays after \(step)")
        #expect(world.system.hiddenApps.contains(B("Safari")) == false, "Safari stays after \(step)")
    }

    @Test func aLaunchingSecondAppHidesTheOthersOnItsWindowOnlyWithTheFirstAppInFront() {
        for notesInFront in [true, false] {
            let world = world(running: ["Notes"])
            world.launcher.setHideBackgroundApps(on: true)
            world.tap(1)
            #expect(world.system.kept.isEmpty)
            if notesInFront { world.makeFrontmost("Notes") }

            world.report(.finishedLaunching, for: "Safari")
            neitherHidden(world, "finishing")
            world.report(.windowShown, for: "Safari")

            if notesInFront {
                #expect(world.system.kept == [KeptApps(front: B("Notes"), beside: B("Safari"))])
                #expect(world.system.hiddenApps == [B("Mail")])
            } else {
                #expect(world.system.kept.isEmpty)
                #expect(world.system.hiddenApps.isEmpty)
            }
            neitherHidden(world, "its window")
        }
    }

    @Test func aHideTurnedOffBeforeTheSecondGestureLeavesTheLaunchHidingNothing() {
        let world = world(running: ["Notes"])
        world.launcher.setHideBackgroundApps(on: true)
        world.tap(1)
        world.launcher.setHideBackgroundApps(on: false)
        world.tap(1)
        world.makeFrontmost("Notes")

        world.report(.windowShown, for: "Safari")

        #expect(world.system.kept.isEmpty)
    }

    @Test func aLaunchingFirstAppHidesOnItsOwnWindowAndTheSecondAppNeverWaitsForIt() {
        let kept = KeptApps(front: B("Notes"), beside: B("Safari"))

        let notesLaunches = world(running: ["Safari"])
        notesLaunches.launcher.setHideBackgroundApps(on: true)
        notesLaunches.tap(1)
        #expect(notesLaunches.system.kept.isEmpty)
        notesLaunches.makeFrontmost("Notes")
        notesLaunches.report(.windowShown, for: "Notes")
        #expect(notesLaunches.system.kept == [kept])
        neitherHidden(notesLaunches, "Notes's window")

        let both = world(running: [])
        both.launcher.setHideBackgroundApps(on: true)
        both.tap(1)
        both.makeFrontmost("Notes")
        both.report(.windowShown, for: "Safari")
        #expect(both.system.kept.isEmpty, "the first app still waits for its own window")
        both.report(.windowShown, for: "Notes")
        #expect(both.system.kept == [kept])
        neitherHidden(both, "both windows")

        let notesFirst = world(running: [])
        notesFirst.launcher.setHideBackgroundApps(on: true)
        notesFirst.tap(1)
        notesFirst.makeFrontmost("Notes")
        notesFirst.report(.windowShown, for: "Notes")
        #expect(notesFirst.system.kept == [kept])
        notesFirst.report(.windowShown, for: "Safari")
        #expect(notesFirst.system.kept == [kept, kept])
        neitherHidden(notesFirst, "both windows")

        let safariOnly = world(running: [])
        safariOnly.launcher.setHideBackgroundApps(on: true)
        safariOnly.tap(1)
        safariOnly.makeFrontmost("Notes")
        safariOnly.report(.windowShown, for: "Safari")
        safariOnly.report(.finishedLaunching, for: "Notes")
        safariOnly.report(.ranOut, for: "Notes")
        #expect(safariOnly.system.kept.isEmpty)
        neitherHidden(safariOnly, "Notes running out")
    }
}
