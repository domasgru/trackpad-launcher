import Testing
import LauncherCore

@MainActor @Suite struct NoWindowsCardTests {
    private var thumb: TouchScript { TouchScript(.macBook14).thumb(atMM: (10, 10)) }

    struct Listing: CustomTestStringConvertible, Sendable {
        let visible: Int
        let minimised: Int
        var fullScreenFront = false
        var answers = true
        /// The rows the switcher shows from the start frame; nil: the slide is no window swipe.
        let rows: Int?

        var testDescription: String {
            "\(visible) visible, \(minimised) minimised\(fullScreenFront ? ", full-screen front" : "")"
                + "\(answers ? "" : ", not answering")"
        }
    }

    @Test(arguments: [
        Listing(visible: 1, minimised: 1, rows: 2),
        Listing(visible: 2, minimised: 0, rows: 2),
        Listing(visible: 0, minimised: 2, rows: 2),
        Listing(visible: 14, minimised: 0, rows: 10),
        Listing(visible: 2, minimised: 0, answers: false, rows: nil),
    ])
    func aSlideDownShowsRowsWhenTheReadListsTwoOrMoreAndNothingWhenTheAppDoesNotAnswer(_ listing: Listing) {
        let names = (0..<(listing.visible + listing.minimised)).map { "W\($0 + 1)" }
        let world = World.windowWorld(
            visible: Array(names.prefix(listing.visible)), minimised: Array(names.dropFirst(listing.visible)),
            fullScreenFront: listing.fullScreenFront)
        world.system.windows.answering = listing.answers ? .now : .held
        let script = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))

        let history = world.playFrameByFrame(script)

        let beganAt = perFrame(script.frames).firstIndex { $0.windowSwipe == .began }
        #expect(beganAt != nil)
        guard let beganAt else { return }
        #expect(world.hardware.windowSwipeAnswers == [listing.rows != nil])
        if let rows = listing.rows {
            #expect(history[..<beganAt].allSatisfy { $0.windowSwitcher == nil })
            #expect(history[beganAt...].allSatisfy { $0.windowSwitcher?.rows.count == rows })
        } else {
            #expect(history.allSatisfy { $0.windowSwitcher == nil })
        }
        #expect(world.system.windows.reads == 1)
    }

    enum Front: String, CaseIterable, Sendable {
        case noActiveApp, safariHeld, safariNever
    }

    enum CardFront: String, CaseIterable, Sendable {
        case textEditOneWindow, finderNoWindows, safariFullScreen
    }

    enum Hand: String, CaseIterable, Sendable {
        case freshSlidePressLift, lateSlidePressLift, downThenSideways, downThenThumbTap

        var script: TouchScript {
            let thumb = TouchScript(.macBook14).thumb(atMM: (10, 10))
            switch self {
            case .freshSlidePressLift:
                return thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 20)).press().lift()
            case .lateSlidePressLift:
                return thumb.wait(.seconds(4)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 2))
                    .slide(byMM: (0, 18)).press().lift()
            case .downThenSideways:
                return thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)).slide(byMM: (20, 0)).lift()
            case .downThenThumbTap:
                return thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)).liftThumb().thumbTap().lift()
            }
        }
    }

    struct Seen: Equatable {
        let windowSwitcher: WindowSwitcher?
        let switcher: Switcher?
        let probe: ScrollVerdict?
    }

    struct Outcome: Equatable {
        let frames: [Seen]
        let pressVerdicts: [PointerVerdict]
        let pulses: [InMemoryTrackpads.Pulse]
        /// By name: each world's apps live under its own folder.
        let broughtToFront: [String]
        let raised: [[WindowID]]
    }

    private func configure(_ world: World, windowSwipe: Bool, swipe: Bool) -> World {
        world.launcher.setAssignment(.app(world.app("Notes")), for: .one)
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.launcher.setWindowSwipe(on: windowSwipe)
        world.launcher.setSwipe(on: swipe)
        return world
    }

    private func world(_ front: Front, windowSwipe: Bool, swipe: Bool) -> World {
        let world: World
        switch front {
        case .noActiveApp: world = .windowWorld(frontmost: nil)
        case .safariHeld:
            world = .windowWorld()
            world.system.windows.set(visible: ["Docs", "Mail"], answering: .held)
        case .safariNever:
            world = .windowWorld()
            world.system.windows.set(visible: ["Docs", "Mail"], answering: .never)
        }
        return configure(world, windowSwipe: windowSwipe, swipe: swipe)
    }

    private func cardWorld(_ front: CardFront, swipe: Bool) -> World {
        let world: World
        switch front {
        case .textEditOneWindow: world = .windowWorld(visible: ["Letter"], frontmost: "TextEdit")
        case .finderNoWindows: world = .windowWorld(frontmost: "Finder")
        case .safariFullScreen: world = .windowWorld(visible: ["Film", "Docs", "Mail"], fullScreenFront: true)
        }
        return configure(world, windowSwipe: true, swipe: swipe)
    }

    private func notesWorld() -> World { .windowWorld(visible: ["Letter"], frontmost: "Notes") }

    private func card(_ switcher: WindowSwitcher?) -> NoWindowsCard? {
        if case .card(let card)? = switcher?.content.list { card } else { nil }
    }

    private func outcome(of hand: Hand, in world: World) -> Outcome {
        let frames = world.playFrameByFrame(hand.script) {
            Seen(
                windowSwitcher: world.launcher.windowSwitcher, switcher: world.launcher.switcher,
                probe: world.hardware.scroll(.unphased))
        }
        return Outcome(
            frames: frames, pressVerdicts: world.hardware.pressVerdicts, pulses: world.hardware.pulses,
            broughtToFront: world.system.broughtToFront.map(\.name), raised: world.system.windows.raised)
    }

    @Test(arguments: Front.allCases, [true, false])
    func withoutAKnownWindowCountASlideDownBehavesExactlyAsWithTheWindowSwipeOff(_ front: Front, swipe: Bool) {
        for hand in Hand.allCases {
            let on = world(front, windowSwipe: true, swipe: swipe)
            let reference = world(front, windowSwipe: false, swipe: swipe)

            let seen = outcome(of: hand, in: on)
            let expected = outcome(of: hand, in: reference)

            #expect(seen == expected, "\(hand)")
            #expect(seen.frames.allSatisfy { $0.windowSwitcher == nil && $0.switcher == nil }, "\(hand)")
            #expect(on.hardware.windowSwipeAnswers == [false], "\(hand)")
            #expect(on.system.windows.reads == 1, "\(hand)")
            #expect(on.system.frontmostDeadlines == [.milliseconds(200)], "\(hand)")
            if hand == .downThenThumbTap {
                #expect(seen.broughtToFront.count == 1, "\(hand)")
                #expect(seen.pulses.map(\.haptic) == [.gesture], "\(hand)")
            }
        }
    }

    @Test func aTwoWindowSwipeAsksForTwoHundredMillisecondsAtItsStartAndAtItsLift() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setWindowSwipe(on: true)

        world.play(thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)).lift())

        #expect(world.system.frontmostDeadlines == [.milliseconds(200), .milliseconds(200)])
    }

    // MARK: The card

    enum Case: String, CaseIterable, Sendable {
        case notesOneWindow, finderNoWindows, safariFullScreenFront, safariLoneMinimised, trackpadLauncherItself

        var lines: (title: String, message: String) {
            switch self {
            case .notesOneWindow: ("No other windows", "Notes has no other windows on this desktop.")
            case .finderNoWindows: ("No open windows", "Finder has no windows on this desktop.")
            case .safariFullScreenFront, .safariLoneMinimised:
                ("No other windows", "Safari has no other windows on this desktop.")
            case .trackpadLauncherItself:
                ("No other windows", "Trackpad Launcher has no other windows on this desktop.")
            }
        }
    }

    @Test(arguments: Case.allCases)
    func aSlideOverAnAppWithZeroOrOneWindowShowsTheCardNamingTheApp(_ scenario: Case) {
        let world: World
        var slide = 5.0
        switch scenario {
        case .notesOneWindow: world = .windowWorld(visible: ["Letter"], frontmost: "Notes")
        case .finderNoWindows:
            world = .windowWorld(frontmost: "Finder")
            slide = -5
        case .safariFullScreenFront:
            world = .windowWorld(visible: ["Film", "Docs", "Mail"], fullScreenFront: true)
        case .safariLoneMinimised: world = .windowWorld(minimised: ["Old"])
        case .trackpadLauncherItself:
            world = .windowWorld()
            world.openSettings()
        }

        world.playFrameByFrame(thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, slide)))

        #expect(world.hardware.windowSwipeAnswers == [true])
        let shown = world.launcher.windowSwitcher
        #expect(shown?.isCard == true)
        #expect(shown?.rows.isEmpty == true)
        #expect(shown?.previewWindows.isEmpty == true)
        #expect(card(shown)?.title == scenario.lines.title)
        #expect(card(shown)?.message == scenario.lines.message)
        #expect(world.system.windows.reads == 1)
    }

    @Test(arguments: CardFront.allCases, [true, false])
    func theCardFollowsEveryOtherWindowSwipeRule(_ front: CardFront, swipe: Bool) {
        for hand in Hand.allCases {
            let on = cardWorld(front, swipe: swipe)
            let reference = configure(.windowWorld(visible: ["Docs", "Mail"]), windowSwipe: true, swipe: swipe)

            let seen = outcome(of: hand, in: on)
            let expected = outcome(of: hand, in: reference)

            #expect(seen.frames.map(\.probe) == expected.frames.map(\.probe), "\(hand)")
            #expect(seen.pressVerdicts == expected.pressVerdicts, "\(hand)")
            #expect(on.hardware.windowSwipeAnswers == [true], "\(hand)")
            if hand == .freshSlidePressLift {
                let script = hand.script.frames
                let fingersDown = script.indices.filter { script[$0].touches.count >= 3 }
                #expect(fingersDown.isEmpty == false)
                #expect(fingersDown.allSatisfy { seen.frames[$0].probe == .drop }, "\(hand)")
                #expect(seen.broughtToFront.isEmpty && seen.pulses.isEmpty && seen.raised.isEmpty, "\(hand)")
            }
        }
    }

    @Test func withTheWindowSwipeOffASlideOverAOneWindowAppScrollsAndShowsNothing() {
        let world = configure(notesWorld(), windowSwipe: false, swipe: false)
        let script = Hand.lateSlidePressLift.script

        let seen = world.playFrameByFrame(script) { (world.launcher.windowSwitcher, world.hardware.scroll(.unphased)) }

        #expect(seen.allSatisfy { $0.0 == nil })
        #expect(world.hardware.windowSwipeAnswers.isEmpty)
        #expect(world.system.windows.reads == 0)
        let frames = script.frames
        let fingersDown = frames.indices.filter { frames[$0].touches.count >= 3 }
        #expect(fingersDown.isEmpty == false)
        #expect(fingersDown.allSatisfy { seen[$0].1 == .pass })
    }

    @Test func aWindowThatOpensMidSlideLeavesTheCardAndJoinsTheOrderOfTheNextSlide() {
        let world = World.windowWorld(visible: ["Letter"], frontmost: "TextEdit")
        let started = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))
        let startHistory = world.playFrameByFrame(started) {
            (windowSwitcher: world.launcher.windowSwitcher, reads: world.system.windows.reads)
        }

        world.system.windows.open("Draft")
        let lifted = started.slide(byMM: (0, 20)).lift()
        let liftHistory = world.playFrameByFrame(lifted) {
            (windowSwitcher: world.launcher.windowSwitcher, reads: world.system.windows.reads)
        }

        let shownFrames = (startHistory + liftHistory).filter { $0.windowSwitcher != nil }
        #expect(shownFrames.isEmpty == false && shownFrames.allSatisfy { $0.windowSwitcher?.isCard == true })
        #expect((startHistory + liftHistory).last?.reads == 1)
        #expect(world.hardware.windowSwipeAnswers == [true])

        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)))

        #expect(world.hardware.windowSwipeAnswers == [true, true])
        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["Letter", "Draft"])
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)
    }

    @Test func windowsThatOpenAfterANoWindowsCardJoinTheOrderInTheOrderTheyOpened() {
        let world = World.windowWorld(frontmost: "Finder")
        let first = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5))
        world.play(first)
        #expect(card(world.launcher.windowSwitcher)?.title == "No open windows")

        let lifted = first.lift()
        world.play(lifted)
        world.system.windows.open("X")
        world.system.windows.open("Y")
        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)))

        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["X", "Y"])
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)
    }

    @Test func withoutAccessibilityASlideOverAOneWindowAppIsNoWindowSwipeAndAGrantBringsTheCardWithTheNextSlide() {
        let world = World.windowWorld(visible: ["Letter"], frontmost: "Notes", accessGranted: false)
        let first = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 24)).lift()

        let history = world.playFrameByFrame(first)

        #expect(history.allSatisfy { $0.windowSwitcher == nil })
        #expect(world.hardware.windowSwipeAnswers.isEmpty)
        #expect(world.system.windows.reads == 0)

        let runs = world.hardware.runCount
        world.permissions.set(.accessibility, granted: true)
        #expect(world.hardware.runCount == runs + 1)

        world.play(first.liftThumb().thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)))

        #expect(card(world.launcher.windowSwitcher)?.title == "No other windows")
        #expect(world.hardware.windowSwipeAnswers == [true])
    }

    // MARK: The card's travel

    /// Slides down (positive) or up in 1 mm steps, the offset after each.
    private func follow(_ world: World, _ script: inout TouchScript, mm: Int) -> [Double] {
        (0..<abs(mm)).map { _ in
            script = script.slide(byMM: (0, mm > 0 ? 1 : -1))
            world.play(script)
            return world.launcher.windowSwitcher?.cardOffset ?? 0
        }
    }

    @Test func theCardFollowsTheFingersDampedAndCappedAtSixPointsThenTurnsAtOnce() {
        let world = notesWorld()
        var script = thumb.land(fingers: 2, atMM: (62, 30))

        let down = follow(world, &script, mm: 40)

        #expect(down.allSatisfy { (-6.0...6.0).contains($0) })
        #expect(zip(down, down.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(down.last == 6)
        let gains = zip(down, down.dropFirst()).map { $1 - $0 }.drop { $0 == 0 }
        #expect(zip(gains, gains.dropFirst()).allSatisfy { $1 <= $0 + 1e-9 })

        let up = follow(world, &script, mm: -40)

        #expect(up[0] < 6)
        #expect(up.contains { $0 < 0 })
        #expect(up.allSatisfy { $0 >= -6 })
        #expect(up.last == -6)
        #expect(zip(up, up.dropFirst()).allSatisfy { $0 >= $1 })

        world.play(script.lift())
        #expect(world.hardware.pulses.isEmpty)
    }

    @Test func theOffsetAfterATurnDoesNotDependOnHowFarTheFingersWentBefore() {
        func offset(afterDownMM down: Int) -> Double? {
            let world = notesWorld()
            var script = thumb.land(fingers: 2, atMM: (62, 30))
            _ = follow(world, &script, mm: down)
            return follow(world, &script, mm: -1).last
        }

        let near = offset(afterDownMM: 10)
        let far = offset(afterDownMM: 40)

        #expect(abs((near ?? 0) - (far ?? 0)) < 1e-6)
        #expect((near ?? 0) < 0)
    }

    // MARK: Lifting and cancelling

    private func hidingWorld() -> World {
        let world = World.windowWorld(visible: ["Letter"], frontmost: "Notes")
        world.launcher.setHideBackgroundApps(on: true)
        world.openSettings()
        world.system.frontmost = world.app("Notes")
        world.system.windows.set(visible: ["Letter"])
        return world
    }

    private func changedNothing(_ world: World) -> Bool {
        world.system.windows.reads == 1 && world.system.windows.raised.isEmpty && world.hardware.pulses.isEmpty
            && world.system.hidesOthers.isEmpty && world.system.hiddenApps.isEmpty
            && world.system.broughtToFront.isEmpty && world.launcher.isWindowOpen
    }

    @Test func liftingOnTheCardChangesNothingAndIsSilent() {
        let world = hidingWorld()

        world.windowSwipe(5, 12)

        #expect(world.hardware.windowSwipeAnswers == [true])
        #expect(world.launcher.windowSwitcher == nil)
        #expect(changedNothing(world))
    }

    @Test func aCancelledWindowSwipeOnTheCardChangesNothingAndIsSilent() {
        let world = hidingWorld()

        let hand = world.windowSwipe(5, 12, lift: false)
        #expect(world.launcher.windowSwitcher?.isCard == true)
        world.play(hand.wait(.milliseconds(10)).land(fingers: 1, atMM: (86, 45)).lift())

        #expect(world.launcher.windowSwitcher == nil)
        #expect(changedNothing(world))
    }
}
