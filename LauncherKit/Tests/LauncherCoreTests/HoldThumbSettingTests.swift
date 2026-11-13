import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct HoldThumbSettingTests {
    private static let apps = ["Arc", "Figma", "Notion", "Spotify", "Slack"]
    private let plain = TouchScript(.macBook14)
    private let hand = HandFrames()
    private let pad = Trackpad.macBook14.id

    /// The five apps on gestures 1 to 5, running, Hold thumb off unless `holdThumb`.
    private func thumblessWorld(
        access: Bool = false, holdThumb: Bool = false, attached: [Trackpad] = [.macBook14]
    ) -> World {
        let world = World(apps: Self.apps, attached: attached, accessGranted: access)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, Self.apps) {
            world.launcher.setAssignment(.app(world.app(name)), for: gesture)
        }
        world.makeRunning(Self.apps)
        world.preferences.set(.tapToClick, rawValue: access ? 1 : 0, for: .builtIn)
        world.preferences.set(.lookUpTapWithThreeFingers, rawValue: access ? 2 : 0, for: .builtIn)
        if !holdThumb { world.launcher.setHoldThumb(on: false) }
        return world
    }

    private func fired(_ world: World) -> [AppEntry] { world.system.broughtToFront }
    private func apps(_ world: World, _ names: String...) -> [AppEntry] { names.map { world.app($0) } }

    @Test func holdThumbIsOnForAFreshWorld() {
        let world = World()
        world.launcher.start()
        #expect(world.launcher.isHoldThumbOn)
        world.launcher.openedByHand()
        #expect(world.launcher.isHoldThumbOn)
    }

    @Test(arguments: 1...5) func withHoldThumbOnATapWithNoThumbFiresNothingAndBlocksNothing(fingers: Int) {
        let world = thumblessWorld(access: true, holdThumb: true)
        world.tapWithoutThumb(fingers)

        #expect(fired(world).isEmpty)
        #expect(!world.hardware.isGatedPortOn)
        let press = PressID(button: 0, number: 90)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.pass)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.pass)))
    }

    @Test(arguments: 1...5) func aThumblessTapFiresTheGestureOfItsFingerCount(fingers: Int) {
        let world = thumblessWorld()
        world.tapWithoutThumb(fingers)

        let app = world.app(Self.apps[fingers - 1])
        #expect(fired(world) == [app])
        #expect(world.hardware.feedback == [pad])
        #expect(world.system.launchAnimations == [app])
    }

    enum Case: CaseIterable { case running, notRunning, hidesOthers, noAnimation }

    @Test(arguments: Case.allCases) func aThumblessTapLaunchesLikeATapUnderTheThumb(kind: Case) {
        func world() -> World {
            let world = thumblessWorld()
            switch kind {
            case .running: break
            case .notRunning: world.makeRunning([String]())
            case .hidesOthers: world.launcher.setHideBackgroundApps(on: true)
            case .noAnimation: world.launcher.setLaunchAnimation(on: false)
            }
            return world
        }
        let thumbless = world()
        thumbless.tapWithoutThumb(1)
        let held = world()
        held.tap(1)

        #expect(!thumbless.system.broughtToFront.isEmpty)
        #expect(thumbless.system.broughtToFront.map(\.bundleID) == held.system.broughtToFront.map(\.bundleID))
        #expect(thumbless.hardware.pulses == held.hardware.pulses)
        #expect(thumbless.system.launchAnimations.map(\.bundleID) == held.system.launchAnimations.map(\.bundleID))
        #expect(
            thumbless.system.bounces.map { [$0.app.bundleID.rawValue, "\($0.cap)", "\($0.limits)"] }
                == held.system.bounces.map { [$0.app.bundleID.rawValue, "\($0.cap)", "\($0.limits)"] })
        #expect(thumbless.system.hidesOthers == held.system.hidesOthers)
        if kind == .hidesOthers { #expect(thumbless.system.hidesOthers == [World.bundleID("Arc")]) }
    }

    @Test func anUnassignedCountFiresNothing() {
        let world = thumblessWorld()
        world.launcher.setAssignment(.none, for: .three)
        world.tapWithoutThumb(3)
        #expect(fired(world).isEmpty)
        #expect(world.hardware.pulses.isEmpty)
    }

    @Test(arguments: [(390, true), (410, false)]) func aSingleFingerHasTheTapWindow(heldMS: Int, fires: Bool) {
        let world = thumblessWorld()
        world.hardware.touch(plain.tap(fingers: 1, hold: .milliseconds(heldMS)).frames, on: pad)
        #expect(fired(world) == (fires ? apps(world, "Arc") : []))
    }

    @Test(arguments: [(200, true), (300, false)]) func theTapWindowRunsFromTheFirstLanding(downMS: Int, fires: Bool) {
        let world = thumblessWorld()
        world.hardware.touch(
            plain.tap(fingers: 3, stagger: .milliseconds(75), hold: .milliseconds(downMS)).frames, on: pad)
        #expect(fired(world) == (fires ? apps(world, "Notion") : []))
    }

    @Test(arguments: [(2.5, true), (3.5, false)]) func aFingerDraggingMoreThanThreeMillimetresIsNoTap(
        dragMM: Double, fires: Bool
    ) {
        let world = thumblessWorld()
        world.hardware.touch(plain.tap(fingers: 1, dragMM: (dragMM, 0)).frames, on: pad)
        #expect(fired(world) == (fires ? apps(world, "Arc") : []))
    }

    @Test func oneDraggingFingerSpoilsAPairsTap() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 60, 40), hand.contact(2, .landing, atMM: 68, 40)]),
            hand.frame(atMS: 60, [hand.contact(1, atMM: 63.5, 40), hand.contact(2, atMM: 68, 40)]),
            hand.frame(atMS: 120),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world).isEmpty)
    }

    @Test func aFingerThatSlidAwayOrRestsKeepsASecondFingersTapFromFiring() {
        let sliding = thumblessWorld()
        let slid = plain.land(fingers: 1).slide(byMM: (10, 0), over: .milliseconds(300))
            .tap(fingers: 1, atMM: (90, 45)).lift()
        sliding.hardware.touch(slid.frames, on: pad)
        #expect(fired(sliding).isEmpty)

        let resting = thumblessWorld()
        resting.hardware.touch(
            plain.land(fingers: 1).wait(.milliseconds(500)).tap(fingers: 1, atMM: (90, 45)).lift().frames, on: pad)
        #expect(fired(resting).isEmpty)
    }

    @Test(arguments: [TouchScript.ClickTiming.onLanding, .firm, .midway])
    func aPressedTapFiresNothingAndItsClickPasses(click: TouchScript.ClickTiming) {
        let world = thumblessWorld(access: true)
        world.hardware.touch(plain.tap(fingers: 1, click: click).tap(fingers: 1).frames, on: pad)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func aPressedTapWithoutAccessibilityFiresNothing() {
        let world = thumblessWorld()
        world.hardware.touch(plain.tap(fingers: 1, click: .firm).frames, on: pad)
        #expect(fired(world).isEmpty)
    }

    @Test(arguments: [true, false]) func aClickAfterTheLiftFrameDoesNotCancelTheGesture(access: Bool) {
        let world = thumblessWorld(access: access)
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 62, 45)]),
            hand.frame(atMS: 50, [hand.contact(1, atMM: 62, 45)]),
            hand.frame(atMS: 100, [], press: .click),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func edgeContactsDoNotCountAndAPalmDoesNotSpoilATap() {
        let world = thumblessWorld()
        let script = plain.land(fingers: 1, atMM: (60, 75.5)).wait(.milliseconds(600))
            .tap(fingers: 2).tap(fingers: 1).lift()
        world.hardware.touch(script.frames, on: pad)
        #expect(fired(world) == apps(world, "Figma", "Arc"))

        let lone = thumblessWorld()
        lone.hardware.touch(plain.tap(fingers: 1, atMM: (60, 75.5)).frames, on: pad)
        #expect(fired(lone).isEmpty)
    }

    @Test func fingersLandingAndLiftingOneByOneCountOnceEach() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 50, 40)]),
            hand.frame(atMS: 10, [hand.contact(1, atMM: 50, 40), hand.contact(2, .landing, atMM: 60, 40)]),
            hand.frame(atMS: 20, [
                hand.contact(1, atMM: 50, 40), hand.contact(2, atMM: 60, 40), hand.contact(3, .landing, atMM: 70, 40),
            ]),
            hand.frame(atMS: 30, [hand.contact(2, atMM: 60, 40), hand.contact(3, atMM: 70, 40)]),
            hand.frame(atMS: 40, [hand.contact(3, atMM: 70, 40)]),
            hand.frame(atMS: 50),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Notion"))
    }

    @Test func fourFingersLandingWhileEarlierOnesLiftFireFour() {
        let world = thumblessWorld()
        world.hardware.touch(
            plain.tap(fingers: 4, stagger: .milliseconds(40), hold: .milliseconds(100)).frames, on: pad)
        #expect(fired(world) == apps(world, "Spotify"))
    }

    @Test func sixFingersFireNothing() {
        let world = thumblessWorld()
        world.tapWithoutThumb(6)
        #expect(fired(world).isEmpty)
    }

    @Test func aThumbLandingFirstMakesTheTapAThumbHeldOne() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(100, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 10, [
                hand.contact(100, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40),
                hand.contact(2, .landing, atMM: 68, 40),
            ]),
            hand.frame(atMS: 120, [hand.contact(100, atMM: 10, 10)]),
            hand.frame(atMS: 130),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Figma"))
    }

    @Test func aThumbAndFingersLandingTogetherFireNothing() {
        let world = thumblessWorld()
        let touches = [
            hand.contact(100, .landing, atMM: 10, 10), hand.contact(1, .landing, atMM: 60, 40),
            hand.contact(2, .landing, atMM: 68, 40),
        ]
        world.hardware.touch([hand.frame(atMS: 0, touches), hand.frame(atMS: 120)], on: pad)
        #expect(fired(world).isEmpty)
    }

    @Test(arguments: [true, false]) func aThumbLandingUnderLandedFingersFiresNothing(swaps: Bool) {
        let world = thumblessWorld()
        world.launcher.setSwap(on: swaps)
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 60, 40), hand.contact(2, .landing, atMM: 68, 40)]),
            hand.frame(atMS: 10, [
                hand.contact(1, atMM: 60, 40), hand.contact(2, atMM: 68, 40), hand.contact(100, .landing, atMM: 10, 10),
            ]),
            hand.frame(atMS: 120),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world).isEmpty)
    }

    @Test func aTapInTheAnchorCornerFiresNothingAndTheCornerFollowsTheSettingAndTheTrackpad() {
        let corner = thumblessWorld()
        corner.tapWithoutThumb(1, atMM: (10, 10))
        #expect(fired(corner).isEmpty)

        let bottom = thumblessWorld()
        bottom.launcher.setThumbCorner(.bottomLeft)
        bottom.tapWithoutThumb(1, atMM: (10, 66.8))
        #expect(fired(bottom).isEmpty)
        bottom.tapWithoutThumb(1, atMM: (10, 10))
        #expect(fired(bottom) == apps(bottom, "Arc"))

        let mixed = thumblessWorld(attached: [.macBook14, .magicTrackpad])
        mixed.tapWithoutThumb(1, on: .magicTrackpad, atMM: (10, 105))
        #expect(fired(mixed).isEmpty)
        mixed.tapWithoutThumb(1, on: .magicTrackpad, atMM: (10, 10))
        #expect(fired(mixed) == apps(mixed, "Arc"))
        #expect(mixed.hardware.feedback == [Trackpad.magicTrackpad.id])
    }

    @Test func aQuickSwapStillSwapsAndNeverFiresATap() {
        let script = plain.land(fingers: 2).wait(.milliseconds(50)).thumbTap().wait(.milliseconds(50)).lift()
        let world = World.switcherWorld()
        world.launcher.setAssignment(.app(world.app("Notes")), for: .two)
        world.launcher.setHoldThumb(on: false)
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.count == 1)
        #expect(world.system.launchAnimations.isEmpty)

        let off = World.switcherWorld()
        off.launcher.setAssignment(.app(off.app("Notes")), for: .two)
        off.launcher.setHoldThumb(on: false)
        off.launcher.setSwap(on: false)
        off.play(script)
        #expect(off.system.broughtToFront.isEmpty)
    }

    @Test func aDoubleTapFiresTheOneFingerGestureTwice() {
        let world = thumblessWorld()
        world.hardware.touch(plain.tap(fingers: 1).tap(fingers: 1).frames, on: pad)
        #expect(fired(world) == apps(world, "Arc", "Arc"))
        #expect(world.hardware.feedback.count == 2)
    }

    @Test func aFingerReportedAsLandingAgainUnderItsOldIDStartsASecondTap() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 62, 45)]),
            hand.frame(atMS: 60, [hand.contact(1, .landing, atMM: 62, 45)]),
            hand.frame(atMS: 120),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Arc", "Arc"))
    }

    @Test func aFingerLandingOnTheFrameAnotherLiftsStartsANewTap() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 62, 45)]),
            hand.frame(atMS: 50, [hand.contact(2, .landing, atMM: 80, 45)]),
            hand.frame(atMS: 150),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Arc", "Arc"))
    }

    @Test func aContactLandingInTheCornerOnTheLiftFrameBelongsToWhatComesNext() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 62, 45)]),
            hand.frame(atMS: 100, [hand.contact(2, .landing, atMM: 10, 10)]),
            hand.frame(atMS: 200),
        ]
        world.hardware.touch(frames, on: pad)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func aThumblessTapBlocksNothingAndMacOSStillMakesItsTapAction() {
        let world = thumblessWorld(access: true)
        for frame in plain.tap(fingers: 1).frames {
            world.hardware.touch([frame], on: pad)
            #expect(!world.hardware.isGatedPortOn)
        }
        #expect(fired(world) == apps(world, "Arc"))
        let press = PressID(button: 0, number: 91)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.pass)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.pass)))
    }

    @Test func rightClickLookUpScrollDockSwipeAndSmartZoomAreNotBlockedAfterAThumblessTap() {
        let right = thumblessWorld(access: true)
        right.tapWithoutThumb(2)
        right.hardware.advanceClock(by: .milliseconds(280))
        #expect(right.hardware.offer(.pointer(.press(PressID(button: 1, number: 92)))) == .decided(.pointer(.pass)))
        #expect(fired(right) == apps(right, "Figma"))

        let lookUp = thumblessWorld(access: true)
        lookUp.tapWithoutThumb(3)
        let pair = [lookUp.hardware.offer(.tapAction(.lookUp)), lookUp.hardware.offer(.tapAction(.lookUp))]
        #expect(pair == [.notSent, .notSent])
        #expect(fired(lookUp) == apps(lookUp, "Notion"))

        let other = thumblessWorld(access: true)
        other.tapWithoutThumb(1)
        #expect(other.hardware.scroll(.fingers(.began)) == .pass)
        #expect(other.hardware.offer(.dockSwipe(.began, .gesture)) == .notSent)

        let zoom = thumblessWorld(access: true)
        zoom.hardware.touch(plain.tap(fingers: 2).wait(.milliseconds(80)).tap(fingers: 2).frames, on: pad)
        #expect(fired(zoom) == apps(zoom, "Figma", "Figma"))
        #expect(zoom.hardware.offer(.tapAction(.smartZoom)) == .notSent)
    }

    @Test func tappingTheSwitchTurnsItOnAndTheGestureStillFires() {
        let world = thumblessWorld(access: true)
        world.tapWithoutThumb(1)
        world.launcher.setHoldThumb(on: true)
        #expect(world.launcher.isHoldThumbOn)
        #expect(fired(world) == apps(world, "Arc"))
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test(arguments: [true, false]) func aTapUnderAThumbIsTheSameWhateverTheSetting(holdThumb: Bool) {
        let world = thumblessWorld(access: true, holdThumb: holdThumb)
        world.play(plain.thumb(atMM: (10, 10)).tap(fingers: 2))
        #expect(fired(world) == apps(world, "Figma"))
        world.hardware.advanceClock(by: .milliseconds(180))
        let press = PressID(button: 1, number: 93)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.drop)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.drop)))
    }

    @Test func twoFingersSlidingWithNoThumbNeverSwipeAndAThumbFirstSwipeStillDoes() {
        let thumbless = World.switcherWorld(accessGranted: true)
        thumbless.launcher.setAssignment(.app(thumbless.app("Notes")), for: .two)
        thumbless.launcher.setHoldThumb(on: false)
        let slide = plain.land(fingers: 2).slide(byMM: (3.5, 0)).settle().slide(byMM: (12, 0)).settle()
        thumbless.play(slide)
        #expect(thumbless.launcher.switcher == nil)
        #expect(thumbless.hardware.scroll(.fingers(.began)) == .pass)
        thumbless.play(slide.lift())
        #expect(thumbless.system.broughtToFront.isEmpty)

        let held = World.switcherWorld(accessGranted: true)
        held.launcher.setHoldThumb(on: false)
        let script = held.swipe(3.5, 12, lift: false)
        #expect(held.launcher.switcher != nil)
        held.play(script.lift())
        #expect(held.system.broughtToFront == [held.app("Mail")])
        #expect(held.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])

        let rest = World.switcherWorld(accessGranted: true)
        rest.launcher.setHoldThumb(on: false)
        rest.play(plain.land(fingers: 2).wait(.milliseconds(500)).lift())
        #expect(rest.system.broughtToFront.isEmpty)
    }

    @Test func aWindowSwipeStillNeedsTheThumb() {
        let thumbless = World.windowWorld(visible: ["Docs", "Mail", "News"])
        thumbless.launcher.setAssignment(.app(thumbless.app("Mail")), for: .two)
        thumbless.launcher.setHoldThumb(on: false)
        thumbless.play(
            plain.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)).settle().slide(byMM: (0, 12)).settle())
        #expect(thumbless.launcher.windowSwitcher == nil)
        #expect(thumbless.system.broughtToFront.isEmpty)

        let held = World.windowWorld(visible: ["Docs", "Mail", "News"])
        held.launcher.setHoldThumb(on: false)
        held.windowSwipe(3.5, 12, lift: false)
        #expect(held.launcher.windowSwitcher != nil)
    }

    @Test func theSettingAppliesToTheNextTapInBothDirectionsOnOneLauncher() {
        let world = thumblessWorld(holdThumb: true)
        world.tapWithoutThumb(1)
        #expect(fired(world).isEmpty)
        world.launcher.setHoldThumb(on: false)
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
        world.launcher.setHoldThumb(on: true)
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func aFlipWhileAFingerIsDownDropsThatTouchAndTheNextTapFires() {
        let world = thumblessWorld(holdThumb: true)
        let down = plain.land(fingers: 1).wait(.milliseconds(50))
        world.play(down)
        world.launcher.setHoldThumb(on: false)
        world.play(down.wait(.milliseconds(30)).lift())
        #expect(fired(world).isEmpty)
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func theChoiceIsSavedAtOnceAndSurvivesARelaunch() {
        let world = thumblessWorld()
        #expect(world.freshStore().load()?.isHoldThumbOn == false)

        world.relaunch()
        world.launcher.start()
        #expect(!world.launcher.isHoldThumbOn)
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
        world.launcher.openedByHand()
        #expect(!world.launcher.isHoldThumbOn)
    }

    @Test func aReleasedRecordWithoutTheKeyLoadsWithHoldThumbOnAndEverythingElseKept() {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(PersistenceTests.savedSettings.utf8))
        let relaunched = world.relaunch()
        relaunched.start()
        #expect(relaunched.isHoldThumbOn)
        #expect(!relaunched.isLaunchAnimationOn)
        #expect(
            relaunched.rows.map(\.app) == [
                .present(world.app("Arc")), .present(world.app("Figma")), .unassigned, .unassigned,
                .present(world.app("Spotify")),
            ])
    }

    @Test func aRecordOfThePreviousVersionLoadsWithHoldThumbOn() throws {
        let world = World(apps: Self.apps)
        var old = PersistenceTests.Build1018Settings()
        old.isLaunchAnimationOn = false
        for (gesture, name) in zip(Gesture.allCases, Self.apps) { old.assignments[gesture] = AssignedApp(world.app(name)) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        world.seedSettingsRecord(try encoder.encode(old))

        let relaunched = world.relaunch()
        relaunched.start()
        world.makeRunning(Self.apps)
        #expect(relaunched.isHoldThumbOn)
        #expect(!relaunched.isLaunchAnimationOn)
        #expect(relaunched.rows.allSatisfy { if case .present = $0.app { true } else { false } })
        world.tapWithoutThumb(1)
        #expect(fired(world).isEmpty)
        world.tap(1)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func theSavedRecordKeepsTheKeyAndAnOlderVersionIgnoresIt() throws {
        let world = thumblessWorld()
        world.launcher.setLaunchAnimation(on: false)
        let bytes = try #require(world.settingsRecordBytes())
        let record = try #require(try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
        #expect(record["isHoldThumbOn"] as? Bool == false)

        let decoded = try PropertyListDecoder().decode(PersistenceTests.Build1018Settings.self, from: bytes)
        #expect(decoded.assignments.count == 5)
        #expect(decoded.assignments[.one]?.bundleID == World.bundleID("Arc"))
        #expect(!decoded.isLaunchAnimationOn)

        try world.previousVersionSaves { _ in }
        let relaunched = world.relaunch()
        relaunched.start()
        #expect(relaunched.rows.allSatisfy { if case .present = $0.app { true } else { false } })
        #expect(relaunched.isHoldThumbOn)
    }

    @Test func aRecordHoldingOnlyTheKeyLoadsAsDefaultsWithThatFieldOff() throws {
        let world = World()
        world.seedSettingsRecord(
            try PropertyListSerialization.data(fromPropertyList: ["isHoldThumbOn": false], format: .binary, options: 0))
        var expected = Settings()
        expected.isHoldThumbOn = false
        #expect(world.freshStore().load() == expected)
    }
}
