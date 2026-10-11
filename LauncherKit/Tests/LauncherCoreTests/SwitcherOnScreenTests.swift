import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct SwitcherOnScreenTests {
    private let trackpad = Trackpad.macBook14
    private let h = HandFrames()
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))

    private func names(_ switcher: Switcher?) -> [String]? { switcher?.row.map(\.name) }

    private func nothingHappened(_ world: World) -> Bool {
        world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.system.launchAnimations.isEmpty
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

    @Test func theRowIsTheSwitcherListInWindowOrderAndTheSelectionStartsOnTheFrontmostApp() {
        let inList = World.switcherWorld()
        inList.makeFrontmost("Slack")
        inList.swipe(3.5, lift: false)
        #expect(names(inList.launcher.switcher) == ["Mail", "Slack", "Notes"])
        #expect(names(inList.launcher.switcher) == inList.launcher.switcherRows.map(\.assigned.name))
        #expect(inList.launcher.switcher?.selectedApp.name == "Slack")

        let outside = World.switcherWorld()
        outside.swipe(3.5, lift: false)
        #expect(names(outside.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])
        #expect(outside.launcher.switcher?.selectedApp.name == "Safari")

        let elsewhere = World.switcherWorld()
        elsewhere.install("Sketch", in: elsewhere.downloads)
        elsewhere.system.frontmost = elsewhere.downloads.appending(path: "Sketch.app")
        elsewhere.swipe(3.5, lift: false)
        #expect(names(elsewhere.launcher.switcher)?.first == "Sketch")
    }

    @Test func aListedAppInTheTrashIsLeftOutWithoutOpeningTheWindowFirst() {
        let world = World(apps: ["Safari", "Mail", "Figma", "Notes"])
        world.launcher.start()
        for name in ["Mail", "Figma", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
        world.makeFrontmost("Safari")
        world.registry[world.app("Figma").bundleID] = [world.trash("Figma")]

        world.swipe(3.5, lift: false)

        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Notes"])
    }

    @Test func theNextSwitcherUsesTheNewOrderAlsoAfterARelaunch() {
        let world = World.switcherWorld()
        world.makeFrontmost("Slack")
        world.launcher.moveInSwitcher(world.app("Notes").bundleID, to: 0)
        world.swipe(3.5, lift: false)
        #expect(names(world.launcher.switcher) == ["Notes", "Mail", "Slack"])
        #expect(world.launcher.switcher?.selectedApp.name == "Slack")

        let relaunched = World(apps: ["Safari", "Slack", "Notes", "Mail"])
        relaunched.launcher.start()
        relaunched.launcher.addToSwitcher(.app(relaunched.app("Mail")))
        relaunched.launcher.addToSwitcher(.app(relaunched.app("Notes")))
        relaunched.launcher.moveInSwitcher(relaunched.app("Notes").bundleID, to: 0)
        relaunched.relaunch()
        relaunched.launcher.start()
        relaunched.makeFrontmost("Safari")
        relaunched.swipe(3.5, lift: false)
        #expect(names(relaunched.launcher.switcher) == ["Safari", "Notes", "Mail"])
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

    @Test func halfAStepShowsProgressWithoutChangingTheSelectionOrTicking() {
        let world = World.switcherWorld()
        world.swipe(3.5, 5, lift: false)
        let switcher = world.launcher.switcher
        #expect(switcher?.selectsFrontmost == true)
        #expect((switcher?.position ?? 0) > 0 && (switcher?.position ?? 1) < 0.5)
        #expect(world.hardware.lightTicks.isEmpty)
    }

    @Test func pastTheMidpointTheSelectionSnapsAndTicksOnce() {
        let world = World.switcherWorld()
        world.swipe(3.5, 7, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")
        #expect((world.launcher.switcher?.position ?? 0) > 0.5)
        #expect(world.hardware.lightTicks.count == 1)
    }

    @Test func pushingPastTheLastIconStaysOnItWithAStretchAndOpensItAtTheLift() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 36, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Notes")

        world.play(hand.slide(byMM: (30, 0)))
        let switcher = world.launcher.switcher
        #expect(switcher?.selectedApp.name == "Notes")
        #expect(switcher?.position == 3)
        #expect((switcher?.stretch ?? 0) > 0 && (switcher?.stretch ?? 1) < 0.2)
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

    @Test func liftingOpensTheSelectionWithTheGestureHapticNoLaunchAnimationAndClosesTheWindow() {
        let world = World.switcherWorld()
        world.launcher.openWindow()
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
        #expect(world.launcher.switcher == nil)
        #expect(!world.launcher.isWindowOpen)
    }

    @Test func theFirstFingerToLiftOpensTheSelectionAndTheOtherChangesNothing() {
        let world = World.switcherWorld()
        let hand = world.swipe(3.5, 24, lift: false)

        world.play(hand.lift(.first))
        #expect(world.launcher.switcher == nil)
        world.play(hand.lift(.first).slide(byMM: (24, 0)).lift())

        #expect(world.system.broughtToFront == [world.app("Slack")])
        #expect(world.hardware.lightTicks.count == 2)
        #expect(world.hardware.feedback.count == 1)
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
        world.launcher.openWindow()

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

    @Test func anEmptyListRecognisesNoSwipeAndBlocksNothingPastTheWindowUntilItHoldsAnApp() {
        let world = World(apps: ["Safari", "Mail"], accessGranted: true)
        world.launcher.start()
        world.makeFrontmost("Safari")
        let late = thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (20, 0)).press().lift()

        world.play(late)
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
        #expect(world.hardware.pressVerdicts == [.pass, .pass])

        world.launcher.addToSwitcher(.app(world.app("Mail")))
        let swiping = late.frames.prefix { $0.press != .click }
        world.hardware.touch(Array(swiping), on: trackpad.id)
        #expect(world.launcher.switcher != nil)
        world.hardware.touch(Array(late.frames.dropFirst(swiping.count)), on: trackpad.id)
        #expect(world.hardware.pressVerdicts == [.pass, .pass, .drop, .drop])
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }

    @Test(arguments: [Duration.zero, .seconds(4)], [false, true])
    func aSwipeWithNothingToShowEndsFromMainSoNothingStaysBlocked(rest: Duration, missing: Bool) {
        let world = World(apps: ["Safari", "Mail", "Figma"], accessGranted: true)
        world.launcher.start()
        world.makeFrontmost("Safari")
        if missing {
            world.launcher.addToSwitcher(.app(world.app("Figma")))
            world.registry[world.app("Figma").bundleID] = [world.trash("Figma")]
        } else {
            world.launcher.addToSwitcher(.app(world.app("Safari")))
        }

        let begin = thumb.wait(rest).land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(begin)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)

        world.play(begin.press().slide(byMM: (12, 0)).lift())
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(world.launcher.switcher == nil)
        #expect(nothingHappened(world))
        #expect(world.scanner.scanRequests == 1)

        world.launcher.addToSwitcher(.app(world.app("Mail")))
        world.play(begin.press().slide(byMM: (12, 0)).lift().land(fingers: 2).slide(byMM: (3.5, 0)))
        #expect(names(world.launcher.switcher) == ["Safari", "Mail"])
    }

    @Test(arguments: [nil, "Notes.txt"] as [String?])
    func noReadableFrontmostAppShowsNothingAndNextTimeItWorks(frontmost: String?) {
        let world = World.switcherWorld(accessGranted: true)
        world.makeFrontmost(nil)
        if let frontmost { world.system.frontmost = world.downloads.appending(path: frontmost) }

        let begin = thumb.land(fingers: 2).slide(byMM: (3.5, 0))
        world.play(begin)
        #expect(world.launcher.switcher == nil)
        #expect(world.hardware.scroll(.fingers(.began)) == .pass)

        let rest = begin.press().slide(byMM: (12, 0)).lift()
        world.play(rest)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(nothingHappened(world))

        world.makeFrontmost("Safari")
        world.play(rest.land(fingers: 2).slide(byMM: (3.5, 0)))
        #expect(names(world.launcher.switcher) == ["Safari", "Mail", "Slack", "Notes"])
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

    @Test(arguments: [true, false])
    func anEditThatFlipsTheListsEmptinessRebuildsTheRecognizersAndOtherEditsDoNot(listed: Bool) {
        let world = World(apps: ["Safari", "Mail", "Slack"], accessGranted: true)
        world.launcher.start()
        if listed { world.launcher.addToSwitcher(.app(world.app("Mail"))) }

        let hand = thumb.land(fingers: 1)
        world.play(hand)
        world.launcher.addToSwitcher(.app(world.app("Slack")))
        world.play(hand.press().lift())

        #expect(world.hardware.pressVerdicts == (listed ? [.drop, .drop] : [.pass, .pass]))
        #expect(world.scanner.scanRequests == 1)
    }

    // MARK: Two trackpads, and a reconcile mid-swipe

    @Test func aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored() {
        let world = World(
            apps: ["Safari", "Mail", "Slack", "Notes"], attached: [.macBook14, .magicTrackpad])
        world.launcher.start()
        for name in ["Mail", "Slack", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
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
        world.launcher.setAssignment(.app(world.app("Mail")), for: .one)
        let hand = world.swipe(3.5, 12, lift: false)
        #expect(world.launcher.switcher?.selectedApp.name == "Mail")

        world.preferences.set(.tapToClick, rawValue: 0, for: .builtIn)
        #expect(world.launcher.switcher == nil)

        let lifted = hand.slide(byMM: (24, 0)).lift()
        world.play(lifted)
        #expect(world.hardware.lightTicks.count == 1)
        #expect(world.system.broughtToFront.isEmpty)

        world.play(lifted.tap(fingers: 1))
        #expect(world.system.broughtToFront == [world.app("Mail")])
    }
}
