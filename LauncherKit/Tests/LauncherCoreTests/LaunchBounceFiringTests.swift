import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct LaunchBounceFiringTests {
    private let tenSeconds = Duration.seconds(10)

    private func world(_ assignments: [(String, Gesture)], others: [String] = []) -> World {
        let world = World(apps: assignments.map(\.0) + others)
        world.launcher.start()
        for (name, gesture) in assignments { world.launcher.setAssignment(.app(world.app(name)), for: gesture) }
        return world
    }

    private func bounced(_ world: World, _ names: String...) -> [RecordingSystemActions.Bounce] {
        names.map { RecordingSystemActions.Bounce(app: world.app($0), cap: tenSeconds) }
    }

    @Test func aGestureForAnAppWithNoProcessBouncesInsteadOfFloatingAndPulsesFirst() {
        let world = world([("Figma", .two)])
        world.launcher.openedByHand()
        var feedbackWhenBouncing: [TrackpadID]?
        world.system.onBringToFrontBouncing = { [unowned world] in feedbackWhenBouncing = world.hardware.feedback }

        world.tap(2)

        #expect(world.system.bounces == bounced(world, "Figma"))
        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(world.launcher.window == .open(request: 1))
        #expect(feedbackWhenBouncing == [Trackpad.macBook14.id], "the pulse comes first, in the same turn")
    }

    enum ProcessKind: CaseIterable {
        case commandTab, frontmostOnly, menuBar, launchingFromTheDock
    }

    @Test(arguments: ProcessKind.allCases)
    func aGestureForAnAppWithAProcessFloatsWhateverKindOfProcessItIs(kind: ProcessKind) {
        let world = world([("Arc", .one)], others: ["Mail"])
        switch kind {
        case .commandTab: world.makeRunning(["Arc"])
        case .frontmostOnly: world.makeFrontmost("Arc")
        // Both are a process macOS lists that the ⌘-Tab list does not show.
        case .menuBar, .launchingFromTheDock: world.startProcess("Arc")
        }

        world.tap(1)

        #expect(world.system.launchAnimations == [world.app("Arc")])
        #expect(world.system.bounces.isEmpty)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func withTheLaunchAnimationOffAnAppWithNoProcessJustLaunches() {
        let world = world([("Figma", .two)])
        world.launcher.openedByHand()
        world.launcher.setLaunchAnimation(on: false)

        world.tap(2)

        #expect(world.system.bounces.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.hardware.feedback.count == 1)
        #expect(world.launcher.window == .open(request: 1))
    }

    @Test(arguments: [LaunchProgress.windowShown, .wentNowhere, .ranOut])
    func anEndingReportEndsTheBounceAndLaterReportsPlayNothing(ending: LaunchProgress) {
        let world = world([("Figma", .two)])
        world.tap(2)

        world.system.report(ending, for: World.bundleID("Figma"))
        world.system.report(.windowShown, for: World.bundleID("Figma"))
        world.system.report(.ranOut, for: World.bundleID("Figma"))
        world.system.report(.wentNowhere, for: World.bundleID("Figma"))

        #expect(world.system.bounceEndings.count == 1)
        #expect(world.system.bounces.isEmpty)
        #expect(world.system.launchAnimations.isEmpty)
    }

    @Test func aWindowEndsTheBounceWithTheLaunchAnimationBeforeAndAfterTheAppFinishedLaunching() {
        for finishesFirst in [false, true] {
            let world = world([("Figma", .two)])
            world.tap(2)
            if finishesFirst { world.report(.finishedLaunching, for: "Figma") }

            world.report(.windowShown, for: "Figma")

            #expect(world.system.bounceEndings == [.init(app: World.bundleID("Figma"), ending: .launchAnimation)])
            #expect(world.system.launchAnimations.isEmpty, "the adapter plays the hand-off")
        }
    }

    @Test func aMenuBarAppThatFinishedLaunchingWaitsTwoSecondsThenEndsWithTheLaunchAnimation() {
        let world = world([("Bartender", .five)])
        world.tap(5)

        world.report(.finishedLaunching, for: "Bartender")
        world.report(.finishedLaunching, for: "Bartender")
        #expect(world.system.bounces.first?.limits == [.seconds(2)])

        world.report(.ranOut, for: "Bartender")
        #expect(world.system.bounceEndings == [.init(app: World.bundleID("Bartender"), ending: .launchAnimation)])
    }

    @Test func aLaunchThatGoesNowhereOrRunsOutBeforeFinishingEndsWithAQuietFade() {
        let cases: [(String, [LaunchProgress])] = [
            ("fails", [.wentNowhere]),
            ("crashes after startup", [.finishedLaunching, .wentNowhere]),
            ("still starting at the cap", [.ranOut]),
        ]
        for (name, reports) in cases {
            let world = world([("Figma", .two)])
            world.tap(2)
            for report in reports { world.report(report, for: "Figma") }

            #expect(
                world.system.bounceEndings == [.init(app: World.bundleID("Figma"), ending: .quietFade)], "\(name)")
            #expect(world.system.launchAnimations.isEmpty, "\(name)")
        }
    }

    @Test func everyBounceCarriesTheTenSecondCapAndAWindowAfterTheEndPlaysNothing() {
        let world = world([("Xcode", .one), ("Slack", .two), ("Mail", .three)])
        world.tap(1)
        world.tap(2)
        #expect(world.system.bounces.map(\.cap) == [tenSeconds, tenSeconds])

        world.report(.finishedLaunching, for: "Xcode")
        world.report(.ranOut, for: "Xcode")
        #expect(world.system.bounceEndings == [.init(app: World.bundleID("Xcode"), ending: .launchAnimation)])

        let bounces = world.system.bounces
        let endings = world.system.bounceEndings
        let launchAnimations = world.system.launchAnimations
        let broughtToFront = world.system.broughtToFront
        world.report(.windowShown, for: "Xcode")
        world.report(.windowShown, for: "Mail")
        #expect(world.system.bounces == bounces)
        #expect(world.system.bounceEndings == endings)
        #expect(world.system.launchAnimations == launchAnimations)
        #expect(world.system.broughtToFront == broughtToFront)
    }

    @Test(arguments: [LaunchProgress.windowShown, .wentNowhere, .ranOut])
    func anAppWhoseBounceEndedBouncesAgainOnItsNextGesture(ending: LaunchProgress) {
        let world = world([("Figma", .two)])
        world.tap(2)
        world.report(ending, for: "Figma")
        #expect(world.system.bounces.isEmpty)

        world.tap(2)

        #expect(world.system.bounces == bounced(world, "Figma"))
    }

    @Test func bouncesFormARowNewestLastAndEachEndsOnItsOwnAppsEvents() {
        let world = world([("Xcode", .one), ("Slack", .two)])
        world.tap(1)
        world.tap(2)
        #expect(world.system.bounces == bounced(world, "Xcode", "Slack"))

        world.report(.windowShown, for: "Slack")

        #expect(world.system.bounceEndings == [.init(app: World.bundleID("Slack"), ending: .launchAnimation)])
        #expect(world.system.bounces == bounced(world, "Xcode"))

        world.report(.ranOut, for: "Xcode")
        #expect(world.system.bounceEndings.map(\.app) == [World.bundleID("Slack"), World.bundleID("Xcode")])
    }

    @Test(arguments: [false, true])
    func aRepeatedGestureKeepsTheOneBounceButPulsesAndBringsTheAppToFront(twoGestures: Bool) {
        let world = twoGestures ? world([("Figma", .one), ("Figma", .two)]) : world([("Figma", .two)])
        world.tap(twoGestures ? 1 : 2)
        world.launcher.openedByHand()

        world.tap(2)

        #expect(world.system.bounces.count == 1)
        #expect(world.system.broughtToFront == [world.app("Figma"), world.app("Figma")])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.hardware.feedback.count == 2)
        #expect(world.launcher.window == .open(request: 1))
    }

    @Test func aBounceThatStartedUpAndIsStillBouncingKeepsItsStateThroughARepeatedGesture() {
        let world = world([("Bartender", .five)])
        world.tap(5)
        world.report(.finishedLaunching, for: "Bartender")
        world.startProcess("Bartender")

        world.tap(5)

        #expect(world.system.bounces.count == 1)
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.broughtToFront.count == 2)

        world.report(.ranOut, for: "Bartender")
        #expect(world.system.bounceEndings == [.init(app: World.bundleID("Bartender"), ending: .launchAnimation)])
    }

    @Test func aLiveBounceSilencesNoOtherGesture() {
        let world = world([("Figma", .two), ("Arc", .one)])
        world.startProcess("Arc")
        world.tap(2)

        world.tap(1)
        world.makeRunning(["Arc", "Figma"])
        world.activate("Arc")
        world.swap()

        #expect(world.system.launchAnimations == [world.app("Arc")])
        #expect(world.system.broughtToFront.count == 3, "the bounce's app, the gesture's app and the swap's app")
        #expect(world.system.bounces == bounced(world, "Figma"))
        #expect(world.system.bounceEndings.isEmpty)
        #expect(world.system.bounces.first?.limits == [])
    }
}
