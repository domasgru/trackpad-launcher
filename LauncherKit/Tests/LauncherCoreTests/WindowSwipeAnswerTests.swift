import Testing
import LauncherCore

/// A thumb in the corner, then two fingers that slide 5 mm down in one frame, which starts a window swipe, followed by
/// one of four shapes. 10 ms frames.
private struct AnswerHand {
    enum Shape: CaseIterable, CustomStringConvertible {
        /// 20 mm more down, then the fingers lift.
        case down
        /// 20 mm sideways, then the fingers lift.
        case sideways
        /// The thumb lifts, taps the corner while the fingers rest, and the fingers lift.
        case thumbTaps
        /// On the frame after the start the thumb rolls 20 mm out of the corner; a new thumb taps the corner while the
        /// fingers rest, and they all lift.
        case thumbRolls

        var description: String {
            switch self {
            case .down: "down"
            case .sideways: "sideways"
            case .thumbTaps: "thumb taps"
            case .thumbRolls: "thumb rolls"
            }
        }
    }

    let frames: [TouchFrame]
    /// The frame the window swipe starts on.
    let start: Int
    /// The frame both fingers lift on.
    let lift: Int
    /// The start of an earlier slide down that lifted under the same thumb, when there is one.
    let earlierStart: FrameTime?

    init(_ shape: Shape, thumbLandedAgo: Duration, earlierSlide: Bool = false) {
        let h = HandFrames()
        let thumb = h.contact(9, atMM: 10, 10)
        let fingersLand = thumbLandedAgo == .zero ? 300 : 4300
        func fingers(_ phase: Touch.Phase = .down, dx: Double = 0, dy: Double, ids: (Int32, Int32) = (1, 2)) -> [Touch] {
            [h.contact(ids.0, phase, atMM: 62 + dx, 30 + dy), h.contact(ids.1, phase, atMM: 70 + dx, 30 + dy)]
        }
        var frames = [h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)])]
        var earlierStart: FrameTime?
        if earlierSlide {
            let at = fingersLand - 200
            frames += [
                h.frame(atMS: at, [thumb] + fingers(.landing, dy: 0, ids: (3, 4))),
                h.frame(atMS: at + 10, [thumb] + fingers(dy: 5, ids: (3, 4))),
                h.frame(atMS: at + 20, [thumb] + fingers(dy: 10, ids: (3, 4))),
                h.frame(atMS: at + 30, [thumb]),
                h.frame(atMS: at + 40, [thumb]),
            ]
            earlierStart = frames[frames.count - 4].time
        }
        frames += [
            h.frame(atMS: fingersLand, [thumb] + fingers(.landing, dy: 0)),
            h.frame(atMS: fingersLand + 10, [thumb] + fingers(dy: 5)),
        ]
        let start = frames.count - 1
        var after: [[Touch]] = []
        switch shape {
        case .down:
            after = (1...4).map { [thumb] + fingers(dy: 5 + 5 * Double($0)) } + [[thumb], [thumb], []]
        case .sideways:
            after = (1...4).map { [thumb] + fingers(dx: 5 * Double($0), dy: 5) } + [[thumb], [thumb], []]
        case .thumbTaps:
            after = [[thumb] + fingers(dy: 5)]
                + Array(repeating: fingers(dy: 5), count: 4)
                + [[h.contact(9, .landing, atMM: 10, 10)] + fingers(dy: 5)]
                + Array(repeating: [thumb] + fingers(dy: 5), count: 5)
                + Array(repeating: fingers(dy: 5), count: 2)
                + [[]]
        case .thumbRolls:
            let rolled = h.contact(9, atMM: 30, 10)
            let newThumb = h.contact(10, atMM: 10, 10)
            after = Array(repeating: [rolled] + fingers(dy: 5), count: 5)
                + [[rolled, h.contact(10, .landing, atMM: 10, 10)] + fingers(dy: 5)]
                + Array(repeating: [rolled, newThumb] + fingers(dy: 5), count: 5)
                + Array(repeating: [rolled] + fingers(dy: 5), count: 2)
                + [[]]
        }
        for (k, touches) in after.enumerated() {
            frames.append(h.frame(atMS: fingersLand + 10 + 10 * (k + 1), touches))
        }
        self.frames = frames
        self.start = start
        self.lift = frames.indices.first { $0 > start && frames[$0].touches.filter { [1, 2].contains($0.id.rawValue) }.isEmpty }!
        self.earlierStart = earlierStart
    }
}

/// A recognizer with window swipes on, and its reference: the same settings with the window swipe setting off.
private struct Pairing: Sendable, CustomStringConvertible {
    let subject: Set<SlideKind>
    let reference: Set<SlideKind>

    static let all = [
        Pairing(subject: [.swipe, .windowSwipe], reference: [.swipe]),
        Pairing(subject: [.windowSwipe], reference: []),
    ]

    var description: String { "\(subject.count) kinds" }
}

/// Steps a subject and its reference through `frames`. After stepping frame i, the subject takes `answers[i]`, in order.
private func run(
    _ frames: [TouchFrame], _ pairing: Pairing, answers: [Int: [(began: FrameTime, isWindowSwipe: Bool)]]
) -> (subject: [Recognition], reference: [Recognition]) {
    var subject = GestureRecognizer(
        handMode: .right, surface: .macBook14, slides: pairing.subject, swaps: true, travel: .linear)
    var reference = GestureRecognizer(
        handMode: .right, surface: .macBook14, slides: pairing.reference, swaps: true, travel: .linear)
    var seen: (subject: [Recognition], reference: [Recognition]) = ([], [])
    for (i, frame) in frames.enumerated() {
        seen.subject.append(subject.step(frame))
        seen.reference.append(reference.step(frame))
        for answer in answers[i] ?? [] {
            subject.answerWindowSwipe(began: answer.began, isWindowSwipe: answer.isWindowSwipe)
        }
    }
    return seen
}

private func sameFlags(_ a: Recognition, _ b: Recognition) -> Bool {
    a.blocksClicks == b.blocksClicks && a.blocksDockSwipes == b.blocksDockSwipes
}

private let landedAgo: [Duration] = [.zero, .seconds(4)]

@Suite struct WindowSwipeAnswerTests {
    @Test func aDeclinedStartIsExactlyTheSlideOfTheSettingOff() {
        for pairing in Pairing.all {
            for ago in landedAgo {
                for shape in AnswerHand.Shape.allCases {
                    let hand = AnswerHand(shape, thumbLandedAgo: ago)
                    let label = "\(pairing), \(ago), \(shape)"
                    let seen = run(hand.frames, pairing, answers: [hand.start: [(hand.frames[hand.start].time, false)]])
                    #expect(seen.subject[hand.start].windowSwipe == .began, "\(label)")
                    #expect(seen.reference[hand.start].event == nil, "\(label)")
                    #expect(sameFlags(seen.subject[hand.start], seen.reference[hand.start]), "\(label)")
                    for i in hand.frames.indices where i != hand.start {
                        #expect(seen.subject[i] == seen.reference[i], "\(label), frame \(i)")
                    }
                    if shape == .sideways {
                        #expect(seen.subject.allSatisfy { $0.swipe == nil }, "\(label)")
                    }
                    if shape == .thumbTaps {
                        #expect(seen.subject.compactMap(\.swapStartsSeries) == [true], "\(label)")
                        #expect(seen.reference.compactMap(\.swapStartsSeries) == [true], "\(label)")
                    }
                }
            }
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedStartBlocksFromTheNextFrameUntilBothFingersLift(laterDecline: Bool) {
        for pairing in Pairing.all {
            for ago in landedAgo {
                for shape in AnswerHand.Shape.allCases {
                    let hand = AnswerHand(shape, thumbLandedAgo: ago)
                    let began = hand.frames[hand.start].time
                    var answers = [hand.start: [(began, true)]]
                    if laterDecline { answers[hand.start + 1] = [(began, false)] }
                    let seen = run(hand.frames, pairing, answers: answers)
                    let label = "\(pairing), \(ago), \(shape)"
                    #expect(seen.subject[hand.lift].windowSwipe == .ended, "\(label)")
                    for i in (hand.start + 1)..<hand.lift {
                        #expect(seen.subject[i].blocksClicks && seen.subject[i].blocksDockSwipes, "\(label), frame \(i)")
                    }
                }
            }
        }
    }

    enum Unconfirmed: CaseIterable {
        case neverAnswered, answerNamesAnEarlierStart, answeredAfterTheLift
    }

    @Test(arguments: Unconfirmed.allCases)
    func anUnconfirmedStartBlocksAsTheSettingOffAndStillEnds(answering: Unconfirmed) {
        for pairing in Pairing.all {
            for ago in landedAgo {
                for shape in [AnswerHand.Shape.down, .sideways] {
                    let hand = AnswerHand(shape, thumbLandedAgo: ago, earlierSlide: answering == .answerNamesAnEarlierStart)
                    let answers: [Int: [(began: FrameTime, isWindowSwipe: Bool)]] = switch answering {
                    case .neverAnswered: [:]
                    case .answerNamesAnEarlierStart: [hand.start: [(hand.earlierStart!, true)]]
                    case .answeredAfterTheLift: [hand.lift: [(hand.frames[hand.start].time, true)]]
                    }
                    let seen = run(hand.frames, pairing, answers: answers)
                    let label = "\(pairing), \(ago), \(shape)"
                    for i in hand.frames.indices {
                        #expect(sameFlags(seen.subject[i], seen.reference[i]), "\(label), frame \(i)")
                    }
                    let phases = seen.subject[hand.start...].compactMap(\.windowSwipe)
                    #expect(phases.first == .began && phases.last == .ended, "\(label)")
                }
            }
        }
    }

    @Test func aLateDeclineBlocksAsTheSettingOffThroughoutAndMatchesItFromTheAnswerOn() {
        for pairing in Pairing.all {
            for ago in landedAgo {
                for shape in AnswerHand.Shape.allCases {
                    let hand = AnswerHand(shape, thumbLandedAgo: ago)
                    let answered = hand.start + 3
                    let seen = run(hand.frames, pairing, answers: [answered: [(hand.frames[hand.start].time, false)]])
                    let label = "\(pairing), \(ago), \(shape)"
                    for i in hand.frames.indices {
                        #expect(sameFlags(seen.subject[i], seen.reference[i]), "\(label), frame \(i)")
                    }
                    for i in (answered + 1)..<hand.frames.count {
                        #expect(seen.subject[i] == seen.reference[i], "\(label), frame \(i)")
                    }
                    if shape == .thumbRolls {
                        #expect(seen.subject.allSatisfy { $0.swapStartsSeries == nil }, "\(label)")
                        #expect(seen.reference.allSatisfy { $0.swapStartsSeries == nil }, "\(label)")
                    }
                }
            }
        }
    }
}
