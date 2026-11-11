import Testing
import LauncherCore

/// A finger left alone by the other one's brief loss of contact can be reported far from where it is: that jump is
/// not movement.
@Suite struct SnapTravelTests {
    private let h = HandFrames()

    /// One frame of a hand: how far each of the two fingers moves along x on it, nil when it is out of contact.
    private struct Step {
        let a: Double?
        let b: Double?
        static func both(_ mm: Double, _ times: Int = 1) -> [Step] { Array(repeating: Step(a: mm, b: mm), count: times) }
        static func alone(_ mm: Double, _ times: Int = 1) -> [Step] { Array(repeating: Step(a: nil, b: mm), count: times) }
    }

    /// The travel after a frame (kept from before it when the frame sent no `.moved`) and whether it sent an event.
    private struct Frame {
        let travel: Double
        let sentEvent: Bool
    }

    /// The pair lands 8 mm apart under the thumb and one frame moves it 3.5 mm and begins the slide; the steps are the
    /// frames after it. A finger that comes back after being absent lands again with a new ID.
    private func moved(_ steps: [Step], using travel: SwipeTravel = .linear) -> [Frame] {
        var nextID: Int32 = 3
        var ids: [Int32?] = [1, 2]
        var along = [0.0, 0.0]
        let thumb = h.contact(9, atMM: 10, 10)
        func contacts(_ moves: [Double?], landing: Bool) -> [Touch] {
            var touches = [thumb]
            for slot in 0..<2 {
                guard let move = moves[slot] else { ids[slot] = nil; continue }
                along[slot] += move
                var phase = Touch.Phase.down
                if landing || ids[slot] == nil {
                    phase = .landing
                    if ids[slot] == nil { ids[slot] = nextID; nextID += 1 }
                }
                touches.append(h.contact(ids[slot]!, phase, atMM: 62 + 8 * Double(slot) + along[slot], 45))
            }
            return touches
        }
        var frames = [
            h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
            h.frame(atMS: 50, [thumb, h.contact(1, .landing, atMM: 62, 45), h.contact(2, .landing, atMM: 70, 45)]),
        ]
        along = [3.5, 3.5]
        frames.append(h.frame(atMS: 60, [thumb, h.contact(1, atMM: 65.5, 45), h.contact(2, atMM: 73.5, 45)]))
        for (index, step) in steps.enumerated() {
            frames.append(h.frame(atMS: 70 + 10 * index, contacts([step.a, step.b], landing: false)))
        }
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [.swipe], swaps: true, travel: travel)
        var travel = 0.0
        var afterBegin: [Frame] = []
        var began = false
        for frame in frames {
            let phase = recognizer.step(frame).swipe
            if phase == .began { began = true; continue }
            guard began else { continue }
            if case .moved(let mm)? = phase { travel = mm }
            afterBegin.append(Frame(travel: travel, sentEvent: phase != nil))
        }
        return afterBegin
    }

    private func expect(_ frames: [Frame], _ expected: [Double], sourceLocation: SourceLocation = #_sourceLocation) {
        let actual = frames.map(\.travel)
        #expect(
            actual.count == expected.count && zip(actual, expected).allSatisfy { abs($0 - $1) < 1e-9 },
            "\(actual) is not \(expected)", sourceLocation: sourceLocation)
        #expect(frames.last?.sentEvent == false, "the last frame of the rest sends nothing", sourceLocation: sourceLocation)
    }

    @Test func aRemainingFingersSnapAwayAndItsReturnTwoFramesLaterMoveNothing() {
        let steps = Step.both(0.2, 4) + Step.alone(7) + Step.alone(0.2) + Step.alone(-7)
            + [Step(a: 0, b: 0.2)] + Step.both(0.2, 2) + Step.both(0, 4)
        expect(moved(steps), [0.05, 0.15, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0, 1.15, 1.3, 1.45, 1.55, 1.6, 1.6])
    }

    @Test(arguments: [(0.2, 2.1, 0.8), (0.5, 2.6, 2.0), (1.0, 4.1, 4.0)])
    func aRemainingFingersMovementOverTheSnapThresholdsIsDiscarded(p: Double, a: Double, end: Double) throws {
        let travel = moved(Step.both(p, 4) + Step.alone(a) + Step.alone(0, 4))
        #expect(abs(try #require(travel.last).travel - end) < 1e-9)
    }

    @Test(arguments: [(0.2, 1.9, 2.7), (0.5, 2.4, 4.4), (1.0, 3.9, 7.9)])
    func aRemainingFingersMovementWithinTheSnapThresholdsCounts(p: Double, a: Double, end: Double) throws {
        let travel = moved(Step.both(p, 4) + Step.alone(a) + Step.alone(0, 4))
        #expect(abs(try #require(travel.last).travel - end) < 1e-9)
    }

    @Test func aFingerThatStartsAbruptlyAfterTheOtherLiftsLosesOneFrameAndThenFollowsTheReference() {
        let steps = Step.both(1, 2) + Step.alone(0, 4) + Step.alone(2.4, 5) + Step.alone(0, 4)
        let frames = moved(steps)
        expect(frames, [0.25, 0.75, 1.25, 1.75, 2, 2, 2, 2.6, 3.8, 5.6, 8, 9.8, 11, 11.6, 11.6])
        #expect(frames[5...6].map(\.sentEvent) == [false, false], "the last frame of the rest and the first fast one send nothing")
    }

    @Test(arguments: [
        (-7.0, [0.05, 0.15, 0.3, 0.5, 0.65, 0.75, 0.85, 0.95, 1.1, 1.25, 1.35, 1.4, 1.4]),
        (-4.0, [0.05, 0.15, 0.3, 0.5, 0.65, 0.75, 0.85, 0.95, 1.1, 1.25, 1.35, 1.4, 1.4]),
        (-3.0, [0.05, 0.15, 0.3, 0.5, 0.65, 0.0, -0.65, -1.3, -1.9, -1.75, -1.65, -1.6, -1.6]),
    ])
    func aSnapAwayAndBackOnAdjacentFramesIsDiscardedUnlessTheBackFallsShortOfUndoingIt(back: Double, expected: [Double]) {
        let steps = Step.both(0.2, 4) + Step.alone(7) + Step.alone(back)
            + [Step(a: 0, b: 0.2)] + Step.both(0.2, 2) + Step.both(0, 4)
        expect(moved(steps), expected)
    }

    @Test func aSnapIsRememberedForFourFramesAndNoLonger() {
        let after = Step.alone(-2.4, 2) + Step.alone(0, 4)
        let fifth = moved(Step.both(1, 2) + Step.alone(0, 4) + Step.alone(2.4, 5) + after)
        expect(fifth, [0.25, 0.75, 1.25, 1.75, 2, 2, 2, 2.6, 3.8, 5.6, 8, 9.2, 9.2, 8.6, 7.4, 6.8, 6.8])
        let fourth = moved(Step.both(1, 2) + Step.alone(0, 4) + Step.alone(2.4, 4) + after)
        expect(fourth, [0.25, 0.75, 1.25, 1.75, 2, 2, 2, 2.6, 3.8, 5.6, 7.4, 8, 8, 7.4, 6.8, 6.8])
    }

    @Test(arguments: [(7.0, 7.8), (0.2, 4.4)])
    func withBothFingersDownNothingIsDiscarded(otherJump: Double, end: Double) throws {
        let jump = Step(a: otherJump, b: 7)
        let travel = moved(Step.both(0.2, 4) + [jump] + Step.both(0, 4))
        #expect(abs(try #require(travel.last).travel - end) < 1e-9)
    }

    @Test func aFingerSlidingFastWhenTheOtherLiftsForGoodKeepsItsTravel() {
        let steps = Step.both(4, 4) + Step.alone(4, 3) + Step.alone(0, 4)
        expect(moved(steps), [1, 3, 6, 10, 14, 18, 22, 25, 27, 28, 28])
    }

    @Test func aFingersFirstMovementAfterItRejoinsCounts() {
        let steps = Step.both(1, 4) + Step.alone(1, 2) + [Step(a: 0, b: 1)]
            + [Step(a: 5, b: nil)] + Array(repeating: Step(a: 0, b: nil), count: 4)
        expect(moved(steps), [0.25, 0.75, 1.5, 2.5, 3.5, 4.5, 5.5, 7.5, 9.25, 10.75, 12, 12])
    }

    @Test func aRecordedSwipesSnapAwayAndBackLeavesTheHighlightWhereTheFingersAre() throws {
        let swipe = try #require(RecordedSwipe.load().first { $0.number == 4 })
        let cursor = RecordedSwipe.cursor
        let replay = swipe.replay(travel: cursor)
        #expect(abs(try #require(replay.beganAt) - 192535.342) < 1e-6)
        #expect(abs(try #require(replay.endedAt) - 192538.422) < 1e-6)
        #expect(replay.leaps.isEmpty)
        func travel(at offset: Double) throws -> Double {
            let index = try #require(replay.times.firstIndex { abs($0 - (swipe.began + offset)) < 1e-6 })
            return replay.travel[index]
        }
        let before = try travel(at: 1.128)
        for offset in [1.136, 1.144, 1.152] {
            #expect(abs(try travel(at: offset) - before) < 1)
        }
    }
}
