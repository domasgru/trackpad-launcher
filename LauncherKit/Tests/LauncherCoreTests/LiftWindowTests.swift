import Testing
import LauncherCore

/// With Tap to click on and Accessibility, a gesture leaves no click behind: the click macOS makes at the lift, a
/// right click up to 0.5 s later and a press that starts in that window are all blocked. Times are counted from the
/// frame the fingers lift on.
@MainActor @Suite struct LiftWindowTests {
    private let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
    private let dropped: [InMemoryTrackpads.Delivery] = [.decided(.pointer(.drop)), .decided(.pointer(.drop))]
    private let passed: [InMemoryTrackpads.Delivery] = [.decided(.pointer(.pass)), .decided(.pointer(.pass))]

    private func world(
        _ apps: [String] = ["Arc", "Figma", "Notes"], attached: [Trackpad] = [.macBook14], tapToClick: TrackpadKind = .builtIn,
        accessGranted: Bool = true
    ) -> World {
        let world = World(apps: apps, attached: attached, accessGranted: accessGranted)
        world.launcher.start()
        for (gesture, name) in zip(Gesture.allCases, apps) { world.launcher.setAssignment(.app(world.app(name)), for: gesture) }
        world.preferences.set(.tapToClick, rawValue: 1, for: tapToClick)
        return world
    }

    /// The press and the release of one click, as the window server hands them.
    private func click(_ world: World, button: Int = 0, number: Int64 = 1) -> [InMemoryTrackpads.Delivery] {
        let id = PressID(button: button, number: number)
        return [world.hardware.offer(.pointer(.press(id))), world.hardware.offer(.pointer(.release(id)))]
    }

    @Test(arguments: 1...5)
    func aTapUnderTheThumbOfAnyFingerCountMakesNoClick(fingers: Int) {
        let apps = ["Arc", "Figma", "Notion", "Spotify", "Slack"]
        let world = world(apps)
        world.play(thumb.tap(fingers: fingers))

        #expect(world.system.broughtToFront == [world.app(apps[fingers - 1])])
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(click(world) == dropped)
    }

    @Test func aTapMakesNoClickOnceAccessIsGrantedWithoutARelaunch() {
        let world = world(["Arc", "Figma", "Notion", "Spotify", "Slack"], accessGranted: false)
        let first = thumb.tap(fingers: 1).liftThumb()
        world.play(first)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(click(world) == [.noTap, .noTap])

        world.permissions.set(.accessibility, granted: true)
        world.play(first.wait(.milliseconds(600)).thumb(atMM: (10, 10)).tap(fingers: 1))

        #expect(world.system.broughtToFront == [world.app("Arc"), world.app("Arc")])
        #expect(click(world, number: 2) == dropped)
    }

    @Test func aRightClickAfterATwoFingerTapOrAShortTouchIsBlockedToo() {
        let tapped = world()
        tapped.play(thumb.tap(fingers: 2).wait(.milliseconds(180)))
        #expect(click(tapped, button: 1) == dropped)
        #expect(tapped.system.broughtToFront == [tapped.app("Figma")])

        let touched = world()
        touched.play(thumb.land(fingers: 2).wait(.milliseconds(120)).lift().wait(.milliseconds(10)))
        #expect(click(touched, button: 1) == dropped)
        #expect(touched.system.broughtToFront == [touched.app("Figma")])
    }

    @Test func aTapOnTheExternalTrackpadMakesNoRightClick() {
        let world = world(attached: [.macBook14, .magicTrackpad], tapToClick: .external)
        world.play(TouchScript(.magicTrackpad).thumb(atMM: (10, 10)).tap(fingers: 2).wait(.milliseconds(180)), on: .magicTrackpad)

        #expect(click(world, button: 1) == dropped)
        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.hardware.feedback == [Trackpad.magicTrackpad.id])
    }

    @Test func aClickAfterTheThumbLiftedTooIsBlockedAndTheGatedPortStaysOn() {
        let world = world()
        world.play(thumb.land(fingers: 2).wait(.milliseconds(120)).lift().liftThumb().wait(.milliseconds(190)))

        #expect(world.hardware.isGatedPortOn)
        #expect(click(world, button: 1) == dropped)
        #expect(world.system.broughtToFront == [world.app("Figma")])
    }

    @Test func aTapWithNothingAssignedMakesNoClick() {
        let world = world([])
        world.play(thumb.tap(fingers: 1))

        #expect(click(world) == dropped)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.pulses.isEmpty)
    }

    @Test func aTapAfterTheThumbRestedForSecondsMakesNoClick() {
        let world = world()
        world.play(thumb.wait(.seconds(5)).tap(fingers: 1))

        #expect(click(world) == dropped)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func threeQuickTapsInARowLeaveNoClick() {
        let world = world()
        let first = thumb.tap(fingers: 1)
        let second = first.wait(.milliseconds(80)).tap(fingers: 1)
        let third = second.wait(.milliseconds(80)).tap(fingers: 1)
        var clicks: [[InMemoryTrackpads.Delivery]] = []
        for (number, script) in [first, second, third].enumerated() {
            world.play(script)
            clicks.append(click(world, number: Int64(number + 1)))
        }

        #expect(clicks == [dropped, dropped, dropped])
        #expect(world.system.broughtToFront == Array(repeating: world.app("Arc"), count: 3))
        #expect(world.hardware.feedback.count == 3)
    }

    @Test func aSwipeThatEndsAtOnceLeavesNoClick() {
        let world = World.switcherWorld(accessGranted: true)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        let swipe = thumb.land(fingers: 2).slide(byMM: (3.5, 0), over: .milliseconds(20)).lift()
        let seen = world.playFrameByFrame(swipe) { world.launcher.switcher != nil }
        world.play(swipe.wait(.milliseconds(240)))

        #expect(seen.contains(true))
        #expect(world.launcher.switcher == nil)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(click(world, button: 1) == dropped)
    }

    @Test func aWindowSwipeThatEndsAtOnceLeavesNoClick() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        let swipe = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5), over: .milliseconds(20)).lift()
        world.play(swipe)
        #expect(world.hardware.windowSwipeAnswers == [true])
        #expect(world.launcher.windowSwitcher == nil)

        world.play(swipe.wait(.milliseconds(240)))
        #expect(click(world, button: 1) == dropped)
    }

    @Test func aScrollUnderARestedThumbAndTwoPhysicalClicksKeepTheirClicks() {
        let scrolled = world()
        scrolled.play(thumb.wait(.seconds(4)).land(fingers: 2).slide(byMM: (0, 30), over: .seconds(1)).lift().wait(.milliseconds(60)))
        #expect(click(scrolled) == passed)

        let clicked = world()
        let twice = thumb.wait(.seconds(4)).tap(fingers: 1, click: .firm).wait(.milliseconds(80)).tap(fingers: 1, click: .firm)
        clicked.play(twice)
        #expect(clicked.hardware.pressVerdicts == [.pass, .pass, .pass, .pass])
        #expect(clicked.system.broughtToFront.isEmpty)
    }

    @Test func aTapWithNoThumbSoonAfterAThumbTapIsStillInsideTheFirstWindow() {
        let world = world()
        let hand = thumb.tap(fingers: 1).liftThumb().wait(.milliseconds(150)).land(fingers: 1).wait(.milliseconds(90)).lift()
        world.play(hand)

        #expect(click(world) == dropped)
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aTapWithNoThumbMakesItsClickAsMacOSMakesIt() {
        let one = world()
        let gatedDuringOne = one.playFrameByFrame(TouchScript(.macBook14).tap(fingers: 1)) { one.hardware.isGatedPortOn }
        #expect(!gatedDuringOne.contains(true))
        #expect(click(one) == passed)
        #expect(one.system.broughtToFront.isEmpty)

        let two = world()
        let gatedDuringTwo = two.playFrameByFrame(
            TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(120)).lift().wait(.milliseconds(10))
        ) { two.hardware.isGatedPortOn }
        #expect(!gatedDuringTwo.contains(true))
        #expect(click(two, button: 1) == passed)
        #expect(two.system.broughtToFront.isEmpty)
    }

    @Test(arguments: [(afterMS: 340, isBlocked: true), (afterMS: 360, isBlocked: false), (afterMS: 850, isBlocked: false)])
    func aClickIsBlockedOnlyInsideTheHalfSecondAfterTheLift(afterMS: Int, isBlocked: Bool) {
        let world = world()
        world.play(thumb.tap(fingers: 1).liftThumb().wait(.milliseconds(afterMS)))

        #expect(click(world) == (isBlocked ? dropped : passed))
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aPhysicalPressStillFollowsTheThreeSecondRuleWithTapToClickOn() {
        let late = world()
        late.play(thumb.wait(.seconds(4)).tap(fingers: 1, click: .firm))
        #expect(late.hardware.pressVerdicts == [.pass, .pass])
        #expect(late.system.broughtToFront.isEmpty)

        let early = world()
        early.play(thumb.tap(fingers: 1, click: .firm))
        #expect(early.hardware.pressVerdicts == [.drop, .drop])
        #expect(early.system.broughtToFront == [early.app("Arc")])
    }

    @Test func aTapAndHoldDragBegunInsideTheWindowIsBlockedWholeEvenAfterTheWindowEnds() {
        let world = world()
        let tapped = thumb.wait(.seconds(4)).tap(fingers: 1)
        world.play(tapped)
        let landed = tapped.land(fingers: 1)
        world.play(landed)
        let press = world.hardware.offer(.pointer(.press(PressID(button: 0, number: 1))))

        let early = landed.slide(byMM: (5, 0), over: .milliseconds(200))
        world.play(early)
        let firstDrag = world.hardware.offer(.pointer(.drag(button: 0)))
        let late = early.slide(byMM: (10, 0), over: .milliseconds(400))
        world.play(late)
        let secondDrag = world.hardware.offer(.pointer(.drag(button: 0)))
        let ended = late.slide(byMM: (5, 0), over: .milliseconds(200)).lift().wait(.milliseconds(50))
        world.play(ended)
        let release = world.hardware.offer(.pointer(.release(PressID(button: 0, number: 1))))

        #expect(press == .decided(.pointer(.drop)))
        #expect(firstDrag == .decided(.pointer(.passAsMove)))
        #expect(secondDrag == .decided(.pointer(.passAsMove)))
        #expect(release == .decided(.pointer(.drop)))
        #expect(world.system.broughtToFront == [world.app("Arc")])
    }

    @Test func aSwapsThumbTapLeavesNoClickBehind() {
        let world = World.switcherWorld(accessGranted: true)
        world.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        world.activate("Mail")
        world.activate("Safari")
        let rest = TouchScript(.macBook14).land(fingers: 2).wait(.milliseconds(150))
        let tapped = rest.thumbTap(hold: .milliseconds(60))
        let liftFrame = 1.0 + 0.150 + 0.060
        world.hardware.touch(tapped.frames.filter { $0.time.seconds <= liftFrame + 0.0001 }, on: Trackpad.macBook14.id)
        #expect(world.system.broughtToFront == [world.app("Mail")])

        world.hardware.touch(tapped.frames.filter { abs($0.time.seconds - (liftFrame + 0.01)) < 0.0001 }, on: Trackpad.macBook14.id)
        #expect(click(world) == dropped)
    }
}
