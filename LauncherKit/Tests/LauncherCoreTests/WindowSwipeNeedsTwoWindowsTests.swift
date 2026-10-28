import Testing
import LauncherCore

@MainActor @Suite struct WindowSwipeNeedsTwoWindowsTests {
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
        Listing(visible: 1, minimised: 0, rows: nil),
        Listing(visible: 0, minimised: 1, rows: nil),
        Listing(visible: 0, minimised: 0, rows: nil),
        Listing(visible: 3, minimised: 1, fullScreenFront: true, rows: nil),
        Listing(visible: 2, minimised: 0, answers: false, rows: nil),
    ])
    func aSlideDownIsAWindowSwipeOnlyWhenTheReadListsTwoOrMoreRows(_ listing: Listing) {
        let names = (0..<(listing.visible + listing.minimised)).map { "W\($0 + 1)" }
        let world = World.windowWorld(
            visible: Array(names.prefix(listing.visible)), minimised: Array(names.dropFirst(listing.visible)),
            fullScreenFront: listing.fullScreenFront)
        world.system.windows.answers = listing.answers
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
        case textEditOneWindow, finderNoWindows, noActiveApp, safariFullScreen
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

    private func world(_ front: Front, windowSwipe: Bool, swipe: Bool) -> World {
        let world: World
        switch front {
        case .textEditOneWindow: world = .windowWorld(visible: ["Letter"], frontmost: "TextEdit")
        case .finderNoWindows: world = .windowWorld(frontmost: "Finder")
        case .noActiveApp: world = .windowWorld(frontmost: nil)
        case .safariFullScreen: world = .windowWorld(visible: ["Film", "Docs", "Mail"], fullScreenFront: true)
        }
        world.launcher.setAssignment(.app(world.app("Notes")), for: .one)
        world.launcher.setAssignment(.app(world.app("Mail")), for: .two)
        world.launcher.setWindowSwipe(on: windowSwipe)
        world.launcher.setSwipe(on: swipe)
        return world
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
    func withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff(_ front: Front, swipe: Bool) {
        for hand in Hand.allCases {
            let on = world(front, windowSwipe: true, swipe: swipe)
            let reference = world(front, windowSwipe: false, swipe: swipe)

            let seen = outcome(of: hand, in: on)
            let expected = outcome(of: hand, in: reference)

            #expect(seen == expected, "\(hand)")
            #expect(seen.frames.allSatisfy { $0.windowSwitcher == nil && $0.switcher == nil }, "\(hand)")
            #expect(on.hardware.windowSwipeAnswers == [false], "\(hand)")
            #expect(on.system.windows.reads == 1, "\(hand)")

            let script = hand.script.frames
            let fingersDown = script.indices.filter { script[$0].touches.count >= 3 }
            #expect(!fingersDown.isEmpty)
            if front == .textEditOneWindow || front == .safariFullScreen {
                switch hand {
                case .freshSlidePressLift:
                    #expect(fingersDown.allSatisfy { seen.frames[$0].probe == .drop }, "\(hand)")
                    #expect(seen.broughtToFront.isEmpty && seen.pulses.isEmpty && seen.raised.isEmpty, "\(hand)")
                case .lateSlidePressLift:
                    #expect(fingersDown.allSatisfy { seen.frames[$0].probe == .pass }, "\(hand)")
                default: break
                }
            }
            if hand == .downThenThumbTap {
                #expect(seen.broughtToFront.count == 1, "\(hand)")
                #expect(seen.pulses.map(\.haptic) == [.gesture], "\(hand)")
            }
        }
    }

    @Test func aWindowThatOpensMidSlideDoesNotMakeItAWindowSwipeButCountsForTheNextSlide() {
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

        #expect((startHistory + liftHistory).allSatisfy { $0.windowSwitcher == nil })
        #expect((startHistory + liftHistory).last?.reads == 1)
        #expect(world.hardware.windowSwipeAnswers == [false])

        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)))

        #expect(world.hardware.windowSwipeAnswers == [false, true])
        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["Draft", "Letter"])
    }

    @Test func withoutAccessibilityASlideDownIsNoWindowSwipeAndAGrantBringsItBackWithTheNextSlide() {
        let world = World.windowWorld(visible: ["Docs", "Mail"], accessGranted: false)
        let first = thumb.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 24)).lift()

        let history = world.playFrameByFrame(first)

        #expect(history.allSatisfy { $0.windowSwitcher == nil })
        #expect(world.hardware.windowSwipeAnswers.isEmpty)
        #expect(world.system.windows.reads == 0)

        let runs = world.hardware.runCount
        world.permissions.set(.accessibility, granted: true)
        #expect(world.hardware.runCount == runs + 1)

        world.play(first.liftThumb().thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 5)))

        #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["Docs", "Mail"])
        #expect(world.hardware.windowSwipeAnswers == [true])
    }
}
