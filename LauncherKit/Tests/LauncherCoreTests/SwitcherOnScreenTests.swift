import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct SwitcherOnScreenTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func names(_ switcher: Switcher?) -> [String]? { switcher?.row.map(\.name) }

    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.system.launchAnimations.isEmpty && world.system.bounces.isEmpty
    }

    // MARK: Drift through the app

    @Test func aRollingThreeFingerTapWithDriftShowsTheSwitcherThenRemovesItWithoutOpeningAnything() {
        let world = World.switcherWorld()
        world.install("Notion")
        world.launcher.setAssignment(.app(world.app("Notion")), for: .three)
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 100, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 120, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 140, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45), h.contact(3, .landing, atMM: 86, 45)]),
            h.frame(atMS: 200, [h.contact(9, atMM: 10, 10)]),
            h.frame(atMS: 300),
        ]

        world.hardware.touch(Array(frames.prefix(3)), on: trackpad.id)
        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])

        world.hardware.touch(Array(frames.dropFirst(3)), on: trackpad.id)
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
    }

    @Test func aTwoFingerTapThatDriftsShowsTheSwitcherBrieflyAndOpensNothing() {
        let world = World.switcherWorld()
        world.install("Figma")
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        let windowWasOpen = world.launcher.isWindowOpen

        let hand = thumb.land(fingers: 2).slide(byMM: (4, 0))
        world.play(hand)
        #expect(world.launcher.switcher != nil)
        #expect(world.launcher.switcher?.selectsFrontmost == true)

        world.play(hand.lift())
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
        #expect(world.launcher.isWindowOpen == windowWasOpen)
    }

    // MARK: The row and where the selection starts

    @Test func theRowIsTheRunningAppsInOrderAndTheSelectionStartsOnTheFrontmostApp() {
        let world = World(apps: ["Safari", "Mail", "Notes"])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Notes"])
        world.makeFrontmost("Safari")

        world.swipe(3.5, lift: false)

        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Notes"])
        #expect(world.launcher.switcher?.selectedApp.name == "Safari")
        #expect(world.launcher.switcher?.selectsFrontmost == true)
    }

    @Test func aFrontmostAppMissingFromTheRunningAppsSitsAtTheLeftEndAndTheActiveAppLeadsADisagreeingList() {
        let menuBar = World(apps: ["Bartender", "Safari", "Mail"])
        menuBar.launcher.start()
        menuBar.makeRunning(["Safari", "Mail"])
        menuBar.makeFrontmost("Bartender")
        menuBar.swipe(3.5, lift: false)
        #expect(names(menuBar.launcher.switcher) == ["Bartender", "Safari", "Mail"])
        #expect(menuBar.launcher.switcher?.selectedApp.name == "Bartender")

        let race = World(apps: ["Safari", "Mail", "Notes"])
        race.launcher.start()
        race.makeRunning(["Safari", "Mail", "Notes"])
        race.makeFrontmost("Mail")
        race.swipe(3.5, lift: false)
        #expect(names(race.launcher.switcher) == ["Mail", "Safari", "Notes"])
    }

    @Test func twoRunningCopiesOfOneBundleAreTwoIcons() {
        let world = World(apps: ["Safari", "Slack"])
        world.launcher.start()
        world.install("Slack", in: world.downloads)
        let applicationsCopy = world.app("Slack")
        let downloadsCopy = world.app("Slack", in: world.downloads)
        world.makeRunning([world.app("Safari"), applicationsCopy, downloadsCopy])
        world.system.frontmost = downloadsCopy

        world.swipe(3.5, lift: false)

        #expect(names(world.launcher.switcher) == ["Slack", "Safari", "Slack"])
        #expect(world.launcher.switcher?.row.map(\.url) == [downloadsCopy.url, world.app("Safari").url, applicationsCopy.url])
        #expect(world.launcher.switcher?.selectedApp == downloadsCopy)
    }

    @Test func theNextSwitcherReadsTheOrderAfreshRatherThanKeepingTheLastRow() {
        let world = World.switcherWorld()
        let first = world.swipe(3.5, 12)
        #expect(world.system.broughtToFront == [world.app("Mail")])

        world.makeFrontmost("Mail")
        world.makeRunning(["Mail", "Safari", "Slack", "Notes"])
        world.play(first.land(fingers: 2).slide(byMM: (3.5, 0)))

        #expect(names(world.launcher.switcher) == ["Mail", "Safari", "Slack", "Notes"])
    }

    // MARK: Following the fingers

    @Test func twoStepsRightSelectSlackWithOneTickPerIconAndBackAgainSelectsMail() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 24, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Slack")
        #expect(world.hardware.lightTicks.count == 2)
        #expect(world.hardware.feedback.isEmpty)

        world.play(hand.slide(byMM: (-12, 0)))
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect(world.hardware.lightTicks.count == 3)
    }

    @Test func thirtyRunningAppsStillTakeTwelveMillimetresPerIcon() {
        let names = ["Safari"] + (1..<30).map { "App\($0)" }
        let world = World(apps: names)
        world.launcher.start()
        world.makeRunning(names)
        world.makeFrontmost("Safari")

        world.swipe(3.5, 24, lift: false)

        #expect(world.launcher.switcher?.selectedApp.name == "App2")
        #expect(world.hardware.lightTicks.count == 2)
        #expect(world.hardware.feedback.isEmpty)
    }

    @Test func halfAStepShowsProgressWithoutChangingTheSelectionOrTicking() {
        let world = World.switcherWorld()
        world.swipe(3.5, 5, lift: false)
        let switcher = world.launcher.switcher
        #expect(switcher?.selectsFrontmost == true)
        #expect((switcher?.selection.position ?? 0) > 0 && (switcher?.selection.position ?? 1) < 0.5)
        #expect(world.hardware.lightTicks.isEmpty)
    }

    @Test func pastTheMidpointTheSelectionSnapsAndTicksOnce() {
        let world = World.switcherWorld()
        world.swipe(3.5, 7, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect((world.launcher.switcher?.selection.position ?? 0) > 0.5)
        #expect(world.hardware.lightTicks.count == 1)
    }

    @Test func pushingPastTheLastIconStaysOnItWithAStretchAndOpensItAtTheLift() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 36, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Notes")

        world.play(hand.slide(byMM: (30, 0)))
        let switcher = world.launcher.switcher
        #expect(switcher?.selectedApp.name == "Notes")
        #expect(switcher?.selection.position == 3)
        #expect((switcher?.selection.stretch ?? 0) > 0 && (switcher?.selection.stretch ?? 1) < 0.2)
        #expect(world.hardware.lightTicks.count == 3)

        world.play(hand.slide(byMM: (30, 0)).lift())
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func oneFrameCrossingThreeIconsTicksThreeTimes() {
        let slow = World.switcherWorld()
        slow.swipe(3.5, 36, lift: false)
        #expect(slow.hardware.lightTicks == [trackpad.id, trackpad.id, trackpad.id])

        let jump = World.switcherWorld()
        jump.play(thumb.land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (36, 0), over: .milliseconds(10)))
        #expect(jump.hardware.lightTicks.count == 3)
    }

    // MARK: The lift

    @Test func liftingOpensTheSelectionWithTheGestureHapticNoLaunchAnimationAndLeavesTheWindowOpen() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()
        let hand = world.swipe(3.5, 24, lift: false)
        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])
        #expect(world.launcher.switcher?.selectedApp.name == "Slack")
        #expect(world.hardware.lightTicks.count == 2)
        #expect(world.launcher.switcher != nil)

        world.play(hand.lift())

        #expect(world.system.broughtToFront == [world.app("Slack")])
        #expect(
            world.hardware.pulses == [
                .init(haptic: .lightTick, trackpad: trackpad.id), .init(haptic: .lightTick, trackpad: trackpad.id),
                .init(haptic: .gesture, trackpad: trackpad.id),
            ])
        #expect(world.hardware.feedback == [trackpad.id])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.bounces.isEmpty)
        #expect(world.launcher.switcher == nil)
        #expect(world.launcher.window == .open(request: 1))
    }

    @Test func theSwitcherStaysUntilBothFingersLiftAndTheLastOneKeepsSteering() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 24, lift: false)

        world.play(hand.lift(.first))
        #expect(world.launcher.switcher?.selectedApp == world.app("Slack"))
        world.play(hand.lift(.first).slide(byMM: (12, 0)).lift())

        #expect(world.system.broughtToFront == [world.app("Notes")])
        #expect(world.hardware.lightTicks.count == 3)
        #expect(world.hardware.feedback.count == 1)
    }

    @Test func aPreferenceNotificationThatChangesNothingLeavesTheSwipeAlone() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 12, lift: false)
        let runs = world.hardware.runCount

        world.preferences.touch()

        #expect(world.hardware.runCount == runs)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        world.play(hand.lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test func theWholeHandLiftingTogetherOpensTheSelection() {
        let world = World.switcherWorld()
        let frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
            h.frame(atMS: 60, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 66, 45), h.contact(2, atMM: 70, 45)]),
            h.frame(atMS: 150, [h.contact(9, atMM: 10, 10), h.contact(1, atMM: 90, 45), h.contact(2, atMM: 94, 45)]),
            h.frame(atMS: 200),
        ]
        world.hardware.touch(frames, on: trackpad.id)

        #expect(world.system.broughtToFront == [world.app("Slack")])
        #expect(world.hardware.feedback == [trackpad.id])
        #expect(world.launcher.switcher == nil)
    }

    @Test func theThumbLiftingMidSwipeChangesNothing() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        let thumbless = hand.liftThumb()
        world.play(thumbless)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        let slid = thumbless.slide(byMM: (24, 0))
        world.play(slid)
        #expect(world.launcher.switcher?.selectedApp.name == "Notes")

        world.play(slid.lift())
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func liftingOnTheFrontmostAppOnlyRemovesTheSwitcherAndLeavesTheWindowAlone() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()

        world.swipe(3.5, 4)

        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
        #expect(world.launcher.isWindowOpen)
        #expect(world.scanner.scanRequests == 2)
    }

    // MARK: Cancels

    @Test func aThirdFingerCancelsTheSwitcherAndNothingOpens() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 24, lift: false)

        let third = hand.wait(.milliseconds(10)).land(fingers: 1, atMM: (86, 45))
        world.play(third)
        #expect(world.launcher.switcher == nil)

        world.play(third.lift())
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.allSatisfy { $0.haptic == .lightTick })
        #expect(world.hardware.pulses.count == 2)
    }

    @Test func anUnblockedClickCancelsTheSwipe() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 24, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Slack")

        let pressed = hand.press().slide(byMM: (12, 0))
        world.play(pressed)
        #expect(world.launcher.switcher == nil)

        world.play(pressed.lift())
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.hardware.pressVerdicts.isEmpty)
        #expect(!world.hardware.isBlockingClicks)
    }

    @Test func aBlockedPressDuringTheSwipeIsIgnoredAndTheSelectionAtTheLiftOpens() {
        let world = World.switcherWorld(accessGranted: true)
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        let pressed = hand.press().slide(byMM: (12, 0))
        world.play(pressed)
        #expect(world.launcher.switcher != nil)

        world.play(pressed.lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront == [world.app("Slack")])
    }

    @Test func aPressAfterAThumbLiftDuringALateSwipeIsStillBlocked() {
        let world = World.switcherWorld(accessGranted: true)
        let hand = world.swipe(3.5, 5, lift: false)

        world.play(hand.liftThumb().press().slide(byMM: (12, 0)).lift())

        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    // MARK: Nothing to switch to

    @Test(arguments: [false, true])
    func aSwipeWithNothingToShowStaysBlockedUntilTheFingersLiftWithoutRestartingTheTrackpads(noActiveApp: Bool) {
        let world = World(apps: ["Safari", "Mail"], accessGranted: true)
        world.launcher.start()
        let finder = world.app("Finder", in: world.coreServices)
        world.makeRunning(noActiveApp ? [] : [finder])
        world.system.frontmost = noActiveApp ? nil : finder
        let runs = world.hardware.runCount

        let begin = thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(begin)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.runCount == runs)

        world.play(begin.press().slide(byMM: (12, 0)).lift())
        #expect(world.hardware.pressVerdicts == [.drop, .drop])
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)
    }

    // MARK: No active app

    @Test func withNoActiveAppTheRowIsTheRunningAppsStartingOnTheMostRecent() {
        let world = World.switcherWorld()
        world.makeFrontmost(nil)

        world.swipe(3.5, lift: false)

        #expect(world.launcher.switcher?.row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"])
        #expect(world.launcher.switcher?.selection.selected == 0)
    }

    @Test func withNoActiveAppLiftingOnTheFirstAppBringsItToFront() {
        let world = World.switcherWorld()
        world.makeFrontmost(nil)

        world.swipe(3.5)

        #expect(world.system.broughtToFront == [world.app("Safari")])
        #expect(world.hardware.feedback == [trackpad.id])
    }

    @Test func withNoActiveAppOneRunningAppIsEnoughToSwitchTo() {
        let world = World.switcherWorld()
        world.makeRunning(["Safari"])
        world.makeFrontmost(nil)

        world.swipe(3.5)

        #expect(world.system.broughtToFront == [world.app("Safari")])
    }

    @Test func whileGesturesAreInactiveTheSwipeDoesNothingEvenIfOneWasInFlight() {
        let world = World.switcherWorld()
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        #expect(world.hardware.running.isEmpty)

        world.swipe(3.5, 12)
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))

        world.hardware.inject(.swipe(SwipeEvent(phase: .began, trackpad: trackpad.id)))
        #expect(world.launcher.switcher == nil)
    }

    // MARK: The lift and the left end

    @Test func oneStepRightAndLiftBringsMailToTheFrontWithTheGestureHapticAndLeavesTheWindowOpen() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()

        world.swipe(3.5, 12)

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(
            world.hardware.pulses == [
                .init(haptic: .lightTick, trackpad: trackpad.id), .init(haptic: .gesture, trackpad: trackpad.id),
            ])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.bounces.isEmpty)
        #expect(world.launcher.switcher == nil)
        #expect(world.launcher.window == .open(request: 1))
    }

    @Test func liftingBeforeAnIconIsReachedDoesNothing() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()

        world.swipe(3.5, 4)

        #expect(nothingHappened(world))
        #expect(world.launcher.isWindowOpen)
    }

    @Test func leftHandedTheSameSlideRightReachesTheSameNextApp() {
        let world = World.switcherWorld()
        world.launcher.setHandMode(.left)

        world.play(
            TouchScript(trackpad.surface).thumb(atMM: (114.8, 10)).land(fingers: 2).slide(byMM: (3.5, 0))
                .slide(byMM: (12, 0)).lift())

        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])
    }

    @Test func pushingLeftPastTheFrontmostAppStretchesAndTheNextAppComesSevenMillimetresAfterTheTurn() {
        let world = World.switcherWorld()
        let pushed = world.swipe(3.5, -30, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Safari")
        #expect((world.launcher.switcher?.selection.stretch ?? 0) < 0)
        #expect(world.hardware.lightTicks.isEmpty)

        let turned = pushed.slide(byMM: (5, 0))
        world.play(turned)
        #expect(world.launcher.switcher?.selectedApp.name == "Safari")
        #expect(world.launcher.switcher?.selection.stretch == 0)

        world.play(turned.slide(byMM: (2, 0)))
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect(world.hardware.lightTicks.count == 1)

        world.play(turned.slide(byMM: (2, 0)).lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    // MARK: The row is fixed for the swipe

    @Test func anAppThatQuitMidSwipeIsNotRelaunchedAndNothingPlaysAtTheLift() {
        let world = World(apps: ["Safari", "Mail", "Notes"])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Notes"])
        world.makeFrontmost("Safari")
        let hand = world.swipe(3.5, 24, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Notes")

        world.makeRunning(["Safari", "Mail"])
        world.play(hand.lift())

        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .lightTick])
        #expect(world.launcher.switcher == nil)
    }

    @Test func anAppThatLaunchedMidSwipeNeverJoinsTheRow() {
        let world = World(apps: ["Safari", "Mail", "Slack", "Notes", "Calendar"])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Slack", "Notes"])
        world.makeFrontmost("Safari")
        let hand = world.swipe(3.5, lift: false)

        world.makeFrontmost("Calendar")
        world.makeRunning(["Calendar", "Safari", "Mail", "Slack", "Notes"])
        let slid = hand.slide(byMM: (36, 0))
        world.play(slid)

        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])
        #expect(world.launcher.switcher?.selectedApp.name == "Notes")
        #expect(world.hardware.lightTicks.count == 3)

        world.play(slid.lift())
        #expect(world.system.broughtToFront == [world.app("Notes")])
    }

    @Test func liftingOnTheStartingAppAfterAnotherCameForwardIsSilent() {
        let world = World.switcherWorld()
        world.launcher.openedByHand()
        let hand = world.swipe(3.5, 12, -12, lift: false)

        world.makeFrontmost("Mail")
        world.makeRunning(["Mail", "Safari", "Slack", "Notes"])
        world.play(hand.lift())

        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.map(\.haptic) == [.lightTick, .lightTick])
        #expect(world.launcher.isWindowOpen)
    }

    // MARK: Two trackpads, and a reconcile mid-swipe

    @Test func aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored() {
        let world = World(
            apps: ["Safari", "Mail", "Slack", "Notes"], attached: [.macBook14, .magicTrackpad])
        world.launcher.start()
        world.makeRunning(["Safari", "Mail", "Slack", "Notes"])
        world.makeFrontmost("Safari")
        let magic = Trackpad.magicTrackpad.id

        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect(world.hardware.lightTicks.count == 1)

        world.hardware.inject(.swipe(SwipeEvent(phase: .moved(travelMM: 24), trackpad: magic)))
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect(world.hardware.lightTicks.count == 1)

        world.hardware.inject(.swipe(SwipeEvent(phase: .ended, trackpad: magic)))
        #expect(world.launcher.switcher != nil)
        #expect(world.system.broughtToFront.isEmpty)

        world.hardware.inject(.swipe(SwipeEvent(phase: .cancelled, trackpad: magic)))
        world.hardware.inject(.swipe(SwipeEvent(phase: .began, trackpad: magic)))
        #expect(world.launcher.switcher?.trackpad == trackpad.id)

        world.play(hand.lift())
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.feedback == [trackpad.id])
    }

    @Test func aReconcileMidSwipeRemovesTheSwitcherAndTheRemainingFingersDoNothingUntilTheyLift() {
        let world = World.switcherWorld()
        world.install("Figma")
        world.launcher.setAssignment(.app(world.app("Figma")), for: .one)
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        world.hardware.wake()
        #expect(world.launcher.switcher == nil)

        let lifted = hand.slide(byMM: (24, 0)).lift()
        world.play(lifted)
        #expect(world.hardware.lightTicks.count == 1)
        #expect(world.system.broughtToFront.isEmpty)

        world.play(lifted.tap(fingers: 1))
        #expect(world.system.broughtToFront == [world.app("Figma")])
    }
}
