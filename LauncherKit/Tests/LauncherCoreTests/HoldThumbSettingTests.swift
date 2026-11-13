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

    /// The switcher world with Notes on gesture 2 and Hold thumb off.
    private func thumblessSwitcherWorld(accessGranted: Bool = true) -> World {
        let world = World.switcherWorld(accessGranted: accessGranted)
        world.launcher.setAssignment(.app(world.app("Notes")), for: .two)
        world.launcher.setHoldThumb(on: false)
        return world
    }

    /// The window world with Mail on gesture 2 and Hold thumb off.
    private func thumblessWindowWorld() -> World {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.launcher.setHoldThumb(on: false)
        return world
    }

    private func fired(_ world: World) -> [AppEntry] { world.system.broughtToFront }
    private func apps(_ world: World, _ names: String...) -> [AppEntry] { apps(world, names) }
    private func apps(_ world: World, _ names: [String]) -> [AppEntry] { names.map { world.app($0) } }

    private struct Firing: Equatable {
        let broughtToFront: [AppEntry]
        let pulses: [InMemoryTrackpads.Pulse]
        let launchAnimations: [AppEntry]
        let bounces: [RecordingSystemActions.Bounce]
    }

    private func firing(of world: World) -> Firing {
        Firing(
            broughtToFront: world.system.broughtToFront, pulses: world.hardware.pulses,
            launchAnimations: world.system.launchAnimations, bounces: world.system.bounces)
    }

    /// Nothing fires: no app brought to front, no pulse, no launch animation and no bounce.
    private func expectNothingFires(
        in world: World, sourceLocation: SourceLocation = #_sourceLocation, after action: () -> Void
    ) {
        let before = firing(of: world)
        action()
        #expect(firing(of: world) == before, "nothing fired", sourceLocation: sourceLocation)
    }

    /// `names` is empty when nothing should fire.
    private func expectFiring(
        _ names: [String], in world: World, sourceLocation: SourceLocation = #_sourceLocation, after action: () -> Void
    ) {
        if names.isEmpty {
            expectNothingFires(in: world, sourceLocation: sourceLocation, after: action)
        } else {
            action()
            #expect(fired(world) == apps(world, names), sourceLocation: sourceLocation)
        }
    }

    private func expectClickPasses(in world: World, number: Int64) {
        let press = PressID(button: 0, number: number)
        #expect(world.hardware.offer(.pointer(.press(press))) == .decided(.pointer(.pass)))
        #expect(world.hardware.offer(.pointer(.release(press))) == .decided(.pointer(.pass)))
    }

    private func everyRowIsPresent(_ launcher: Launcher) -> Bool {
        launcher.rows.allSatisfy { if case .present = $0.app { true } else { false } }
    }

    @Test func holdThumbIsOnForAFreshWorld() {
        let world = World()
        world.launcher.start()
        #expect(world.launcher.isHoldThumbOn)
        world.launcher.openedByHand()
        #expect(world.launcher.isHoldThumbOn)
    }

    @Test(arguments: 1...5) func withHoldThumbOnATapWithNoThumbFiresNothingAndBlocksNothing(fingers: Int) {
        let world = thumblessWorld(access: true, holdThumb: true)
        expectNothingFires(in: world) { world.tapWithoutThumb(fingers) }

        #expect(world.hardware.isGatedPortOn == false)
        expectClickPasses(in: world, number: 90)
    }

    @Test(arguments: 1...5) func aThumblessTapFiresTheGestureOfItsFingerCount(fingers: Int) {
        let world = thumblessWorld()
        world.tapWithoutThumb(fingers)

        let app = world.app(Self.apps[fingers - 1])
        #expect(fired(world) == [app])
        #expect(world.hardware.feedback == [pad])
        #expect(world.system.launchAnimations == [app])
    }

    enum LaunchCase: CaseIterable { case running, notRunning, hidesOthers, noAnimation }

    @Test(arguments: LaunchCase.allCases) func aThumblessTapLaunchesLikeATapUnderTheThumb(launch: LaunchCase) {
        func world() -> World {
            let world = thumblessWorld()
            switch launch {
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

        #expect(thumbless.system.broughtToFront.isEmpty == false)
        #expect(thumbless.system.broughtToFront.map(\.bundleID) == held.system.broughtToFront.map(\.bundleID))
        #expect(thumbless.hardware.pulses == held.hardware.pulses)
        #expect(thumbless.system.launchAnimations.map(\.bundleID) == held.system.launchAnimations.map(\.bundleID))
        #expect(
            thumbless.system.bounces.map { [$0.app.bundleID.rawValue, "\($0.cap)", "\($0.limits)"] }
                == held.system.bounces.map { [$0.app.bundleID.rawValue, "\($0.cap)", "\($0.limits)"] })
        #expect(thumbless.system.hidesOthers == held.system.hidesOthers)
        if launch == .hidesOthers { #expect(thumbless.system.hidesOthers == [World.bundleID("Arc")]) }
    }

    @Test func anUnassignedCountFiresNothing() {
        let world = thumblessWorld()
        world.launcher.setAssignment(.none, for: .three)
        expectNothingFires(in: world) { world.tapWithoutThumb(3) }
    }

    @Test(arguments: [(390, true), (410, false)]) func aSingleFingerHasTheTapWindow(heldMS: Int, fires: Bool) {
        let world = thumblessWorld()
        expectFiring(fires ? ["Arc"] : [], in: world) {
            world.hardware.touch(plain.tap(fingers: 1, hold: .milliseconds(heldMS)).frames, on: pad)
        }
    }

    @Test(arguments: [(200, true), (300, false)]) func theTapWindowRunsFromTheFirstLanding(downMS: Int, fires: Bool) {
        let world = thumblessWorld()
        expectFiring(fires ? ["Notion"] : [], in: world) {
            world.hardware.touch(
                plain.tap(fingers: 3, stagger: .milliseconds(75), hold: .milliseconds(downMS)).frames, on: pad)
        }
    }

    @Test(arguments: [(2.5, true), (3.5, false)]) func aFingerDraggingMoreThanThreeMillimetresIsNoTap(
        dragMM: Double, fires: Bool
    ) {
        let world = thumblessWorld()
        expectFiring(fires ? ["Arc"] : [], in: world) {
            world.hardware.touch(plain.tap(fingers: 1, dragMM: (dragMM, 0)).frames, on: pad)
        }
    }

    @Test func oneDraggingFingerSpoilsAPairsTap() {
        let world = thumblessWorld()
        let frames = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 60, 40), hand.contact(2, .landing, atMM: 68, 40)]),
            hand.frame(atMS: 60, [hand.contact(1, atMM: 63.5, 40), hand.contact(2, atMM: 68, 40)]),
            hand.frame(atMS: 120),
        ]
        expectNothingFires(in: world) { world.hardware.touch(frames, on: pad) }
    }

    @Test func aFingerThatSlidAwayOrRestsKeepsASecondFingersTapFromFiring() {
        let sliding = thumblessWorld()
        let slid = plain.land(fingers: 1).slide(byMM: (10, 0), over: .milliseconds(300))
            .tap(fingers: 1, atMM: (90, 45)).lift()
        expectNothingFires(in: sliding) { sliding.hardware.touch(slid.frames, on: pad) }

        let resting = thumblessWorld()
        expectNothingFires(in: resting) {
            resting.hardware.touch(
                plain.land(fingers: 1).wait(.milliseconds(500)).tap(fingers: 1, atMM: (90, 45)).lift().frames, on: pad)
        }
    }

    @Test(arguments: [TouchScript.ClickTiming.onLanding, .firm, .midway])
    func aPressedTapFiresNothingAndItsClickPasses(click: TouchScript.ClickTiming) {
        let world = thumblessWorld(access: true)
        world.hardware.touch(plain.tap(fingers: 1, click: click).tap(fingers: 1).frames, on: pad)
        #expect(world.hardware.pressVerdicts == [.pass, .pass])
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test(arguments: [TouchScript.ClickTiming.onLanding, .firm, .midway])
    func aPressedTapWithoutAccessibilityFiresNothing(click: TouchScript.ClickTiming) {
        let world = thumblessWorld()
        expectNothingFires(in: world) { world.hardware.touch(plain.tap(fingers: 1, click: click).frames, on: pad) }
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
        expectNothingFires(in: lone) { lone.hardware.touch(plain.tap(fingers: 1, atMM: (60, 75.5)).frames, on: pad) }
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
        expectNothingFires(in: world) { world.tapWithoutThumb(6) }
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
        expectNothingFires(in: world) {
            world.hardware.touch([hand.frame(atMS: 0, touches), hand.frame(atMS: 120)], on: pad)
        }
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
        expectNothingFires(in: world) { world.hardware.touch(frames, on: pad) }
    }

    @Test func aTapInTheAnchorCornerFiresNothingAndTheCornerFollowsTheSettingAndTheTrackpad() {
        let corner = thumblessWorld()
        expectNothingFires(in: corner) { corner.tapWithoutThumb(1, atMM: (10, 10)) }

        let bottom = thumblessWorld()
        bottom.launcher.setThumbCorner(.bottomLeft)
        expectNothingFires(in: bottom) { bottom.tapWithoutThumb(1, atMM: (10, 66.8)) }
        bottom.tapWithoutThumb(1, atMM: (10, 10))
        #expect(fired(bottom) == apps(bottom, "Arc"))

        let mixed = thumblessWorld(attached: [.macBook14, .magicTrackpad])
        expectNothingFires(in: mixed) { mixed.tapWithoutThumb(1, on: .magicTrackpad, atMM: (10, 105)) }
        mixed.tapWithoutThumb(1, on: .magicTrackpad, atMM: (10, 10))
        #expect(fired(mixed) == apps(mixed, "Arc"))
        #expect(mixed.hardware.feedback == [Trackpad.magicTrackpad.id])
    }

    @Test func aQuickSwapStillSwapsAndNeverFiresATap() {
        let script = plain.land(fingers: 2).wait(.milliseconds(50)).thumbTap().lift()
        let world = thumblessSwitcherWorld(accessGranted: false)
        world.play(script)
        #expect(world.system.broughtToFront == [world.app("Mail")])
        #expect(world.hardware.pulses.map(\.haptic) == [.gesture])
        #expect(world.system.launchAnimations.isEmpty)

        let off = thumblessSwitcherWorld(accessGranted: false)
        off.launcher.setSwap(on: false)
        expectNothingFires(in: off) { off.play(script) }
    }

    @Test func aDoubleTapFiresTheOneFingerGestureTwice() {
        let world = thumblessWorld()
        world.hardware.touch(plain.tap(fingers: 1, hold: .milliseconds(100)).tap(fingers: 1, hold: .milliseconds(100)).frames, on: pad)
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
            #expect(world.hardware.isGatedPortOn == false)
        }
        #expect(fired(world) == apps(world, "Arc"))
        expectClickPasses(in: world, number: 91)
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
        other.hardware.touch(plain.tap(fingers: 1, click: .firm).frames, on: pad)
        #expect(other.hardware.pressVerdicts == [.pass, .pass])

        let zoom = thumblessWorld(access: true)
        let secondTap = [
            hand.frame(atMS: 200, [hand.contact(3, .landing, atMM: 62, 45), hand.contact(4, .landing, atMM: 70, 45)]),
            hand.frame(atMS: 320),
        ]
        let firstTap = [
            hand.frame(atMS: 0, [hand.contact(1, .landing, atMM: 62, 45), hand.contact(2, .landing, atMM: 70, 45)]),
            hand.frame(atMS: 120),
        ]
        zoom.hardware.touch(firstTap + secondTap, on: pad)
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
        let thumbless = thumblessSwitcherWorld()
        let slide = plain.land(fingers: 2).slide(byMM: (3.5, 0)).settle().slide(byMM: (12, 0)).settle()
        expectNothingFires(in: thumbless) { thumbless.play(slide) }
        #expect(thumbless.launcher.switcher == nil)
        #expect(thumbless.hardware.scroll(.fingers(.began)) == .pass)
        expectNothingFires(in: thumbless) { thumbless.play(slide.lift()) }

        let held = thumblessSwitcherWorld()
        let script = held.swipe(3.5, 12, lift: false)
        #expect(held.launcher.switcher != nil)
        held.play(script.lift())
        #expect(held.system.broughtToFront == [held.app("Mail")])
        #expect(held.hardware.pulses.map(\.haptic) == [.lightTick, .gesture])

        let rest = thumblessSwitcherWorld()
        expectNothingFires(in: rest) { rest.play(plain.land(fingers: 2).wait(.milliseconds(500)).lift()) }
    }

    @Test func aWindowSwipeStillNeedsTheThumb() {
        let thumbless = thumblessWindowWorld()
        let slide = plain.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)).settle().slide(byMM: (0, 12)).settle()
        expectNothingFires(in: thumbless) { thumbless.play(slide) }
        #expect(thumbless.launcher.windowSwitcher == nil)
        expectNothingFires(in: thumbless) { thumbless.play(slide.lift()) }

        let held = thumblessWindowWorld()
        held.windowSwipe(3.5, 12, lift: false)
        #expect(held.launcher.windowSwitcher != nil)
    }

    @Test func theSettingAppliesToTheNextTapInBothDirectionsOnOneLauncher() {
        let world = thumblessWorld(holdThumb: true)
        expectNothingFires(in: world) { world.tapWithoutThumb(1) }
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
        expectNothingFires(in: world) { world.play(down.wait(.milliseconds(30)).lift()) }
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
    }

    @Test func theChoiceIsSavedAtOnceAndSurvivesARelaunch() {
        let world = thumblessWorld()
        #expect(world.freshStore().load()?.isHoldThumbOn == false)

        world.relaunch()
        world.launcher.start()
        #expect(world.launcher.isHoldThumbOn == false)
        world.tapWithoutThumb(1)
        #expect(fired(world) == apps(world, "Arc"))
        world.launcher.openedByHand()
        #expect(world.launcher.isHoldThumbOn == false)
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
        #expect(relaunched.isLaunchAnimationOn == false)
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
        #expect(relaunched.isLaunchAnimationOn == false)
        #expect(everyRowIsPresent(relaunched))
        expectNothingFires(in: world) { world.tapWithoutThumb(1) }
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
        for (gesture, name) in zip(Gesture.allCases, Self.apps) {
            #expect(decoded.assignments[gesture]?.bundleID == World.bundleID(name), "gesture \(gesture)")
        }
        #expect(decoded.isLaunchAnimationOn == false)

        try world.previousVersionSaves { _ in }
        let relaunched = world.relaunch()
        relaunched.start()
        #expect(everyRowIsPresent(relaunched))
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
