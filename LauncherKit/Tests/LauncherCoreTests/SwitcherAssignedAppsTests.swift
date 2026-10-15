import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct SwitcherAssignedAppsTests {
    private let trackpad = Trackpad.macBook14
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func names(_ world: World) -> [String]? { world.launcher.switcher?.row.map(\.name) }

    private func assign(_ world: World, _ names: [String], to gestures: [Gesture] = [.one, .two, .three, .four, .five]) {
        for (name, gesture) in zip(names, gestures) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
    }

    private func started(apps: [String], running: [String]? = nil, frontmost: String?, accessGranted: Bool = false) -> World {
        let world = World(apps: apps, accessGranted: accessGranted)
        world.launcher.start()
        world.makeRunning(running ?? apps)
        world.makeFrontmost(frontmost)
        return world
    }

    @Test func anAssignedAppIsLeftOutAndTheLiftOpensTheNextOneInTheRow() {
        let world = started(
            apps: ["Safari", "Mail", "Notes", "Music"], running: ["Notes", "Mail", "Safari", "Music"], frontmost: "Notes")
        assign(world, ["Mail"], to: [.two])

        let hand = world.swipe(3.5, lift: false)
        #expect(names(world) == ["Notes", "Safari", "Music"])
        #expect(world.launcher.switcher?.selectsFrontmost == true)

        world.play(hand.slide(byMM: (12, 0)).lift())
        #expect(world.system.broughtToFront == [world.app("Safari")])
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])
        #expect(world.hardware.pulses.map(\.trackpad) == [trackpad.id, trackpad.id])
        #expect(world.launcher.switcher == nil)
    }

    @Test func everyGesturesAssignmentCountsAndAnotherCopyOfTheBundleIsLeftOutToo() {
        let assigned = ["Arc", "Figma", "Notion", "Sketch", "Xcode"]
        let world = World(apps: assigned + ["Safari", "Mail", "Notes"])
        world.launcher.start()
        world.install("Arc", in: world.downloads)
        assign(world, assigned)
        world.makeRunning(
            [
                world.app("Safari"), world.app("Arc"), world.app("Mail"), world.app("Figma"),
                world.app("Arc", in: world.downloads), world.app("Notion"), world.app("Notes"), world.app("Sketch"),
                world.app("Xcode"),
            ])
        world.makeFrontmost("Safari")

        world.swipe(3.5, lift: false)

        #expect(names(world) == ["Safari", "Mail", "Notes"])
    }

    @Test func withNoAssignmentTheRowIsStillTheFrontmostAppAndTheNineMostRecent() {
        let all = ["Safari"] + (1...12).map { "App\($0)" }
        let world = started(apps: all, frontmost: "Safari")

        world.swipe(3.5, lift: false)

        #expect(names(world) == ["Safari"] + (1...9).map { "App\($0)" })
        #expect(world.launcher.switcher?.selectedApp.name == "Safari")
    }

    @Test func anAssignedAppMovedToTheTrashIsStillLeftOut() {
        let world = started(apps: ["Safari", "Notes", "Mail"], frontmost: "Safari")
        assign(world, ["Notes"], to: [.three])
        let notes = world.app("Notes")
        world.registry[World.bundleID("Notes")] = [world.trash("Notes")]
        world.makeRunning([world.app("Safari"), notes, world.app("Mail")])
        world.launcher.openWindow()
        #expect(world.launcher.app(for: .three) == .missing(name: "Notes"))

        world.swipe(3.5, lift: false)

        #expect(names(world) == ["Safari", "Mail"])
    }

    @Test func theFrontmostAppStaysAtTheLeftEndEvenWhenItAndAnotherAppHaveGestures() {
        let world = World.switcherWorld()
        world.launcher.openWindow()
        assign(world, ["Safari", "Mail"], to: [.one, .two])

        let hand = world.swipe(3.5, lift: false)
        #expect(names(world) == ["Safari", "Slack", "Notes"])
        #expect(world.launcher.switcher?.selectedApp.name == "Safari")
        #expect(world.launcher.switcher?.selectsFrontmost == true)

        world.play(hand.lift())
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.isEmpty)
        #expect(world.launcher.isWindowOpen)
    }

    @Test(arguments: [
        (running: 14, assigned: [2, 5, 8], row: [0, 1, 3, 4, 6, 7, 9, 10, 11, 12]),
        (running: 6, assigned: [1, 4], row: [0, 2, 3, 5, 6]),
    ])
    func theFreedSlotsGoToTheNextMostRecentAppsWithoutAGesture(running: Int, assigned: [Int], row: [Int]) {
        func name(_ index: Int) -> String { index == 0 ? "Front" : "App\(index)" }
        let world = started(apps: (0...running).map(name), frontmost: "Front")
        assign(world, assigned.map(name), to: [.one, .two, .three])

        world.swipe(3.5, lift: false)

        #expect(names(world) == row.map(name))
    }

    @Test func onlyAssignedAppsBesideTheFrontOneShowNoSwitcherAndStayBlockedUntilTheFingersLift() {
        let world = started(apps: ["Notes", "Safari", "Mail"], frontmost: "Notes", accessGranted: true)
        assign(world, ["Safari", "Mail"], to: [.one, .two])
        let runs = world.hardware.runCount

        let begin = thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(begin)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.runCount == runs)
        #expect(world.hardware.scroll(.fingers(.began)) == .drop)

        world.play(begin.press().slide(byMM: (12, 0)).lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.isEmpty)
        #expect(world.hardware.scroll(.fingers(.ended)) == .drop)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    @Test func withNoFrontmostAppTheRowIsTheRunningAppsWithoutAGestureAndTheSelectionStartsOnTheFirst() {
        let some = started(apps: ["Safari", "Notes", "Mail"], frontmost: nil)
        assign(some, ["Safari"], to: [.one])

        let hand = some.swipe(3.5, lift: false)
        #expect(names(some) == ["Notes", "Mail"])
        #expect(some.launcher.switcher?.selected == 0)
        #expect(some.launcher.switcher?.selectedApp.name == "Notes")

        some.play(hand.lift())
        #expect(some.system.broughtToFront == [some.app("Notes")])
        #expect(some.hardware.feedback == [trackpad.id])

        let every = started(apps: ["Safari", "Mail"], frontmost: nil)
        assign(every, ["Safari", "Mail"], to: [.one, .two])
        every.swipe(3.5)
        #expect(every.launcher.switcher == nil)
        #expect(every.system.broughtToFront.isEmpty)
        #expect(every.hardware.pulses.isEmpty)
    }

    @Test func anAssignmentSetOrClearedBetweenSwipesCountsFromTheNextSwipe() {
        let world = World.switcherWorld()
        let first = world.swipe(3.5, lift: false)
        #expect(names(world) == ["Safari", "Mail", "Slack", "Notes"])
        world.play(first.lift())
        #expect(world.hardware.pulses.isEmpty)

        assign(world, ["Mail"], to: [.four])
        let second = first.lift().land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(second)
        #expect(names(world) == ["Safari", "Slack", "Notes"])
        let lifted = second.lift()
        world.play(lifted)

        world.launcher.setAssignment(nil, for: .four)
        world.play(lifted.land(fingers: 2).slide(byMM: (3.5, 0)))
        #expect(names(world) == ["Safari", "Mail", "Slack", "Notes"])
    }

    @Test func theSwapStillReachesAnAssignedApp() {
        let world = started(apps: ["Notes", "Mail", "Safari"], frontmost: "Notes")
        assign(world, ["Mail"], to: [.two])

        world.swap()

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses == [.init(haptic: .gesture, trackpad: trackpad.id)])
        #expect(world.launcher.switcher == nil)
    }
}
