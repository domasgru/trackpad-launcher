import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

@Suite struct DeviceSessionAnswerTests {
    private static let surface = SurfaceSize(widthMM: 124.8, heightMM: 76.8)

    /// Every event a session delivered, with the reply it carried, in order.
    private final class Delivered: Sendable {
        private let events = Mutex<[(event: TrackpadEvent, reply: (@Sendable (Bool) -> Void)?)]>([])
        func append(_ event: TrackpadEvent, _ reply: (@Sendable (Bool) -> Void)?) {
            events.withLock { $0.append((event, reply)) }
        }
        var all: [(event: TrackpadEvent, reply: (@Sendable (Bool) -> Void)?)] { events.withLock { $0 } }
    }

    private func session(_ delivered: Delivered) -> DeviceSession {
        DeviceSession(
            trackpad: TrackpadID(rawValue: 1),
            recognizer: GestureRecognizer(
                handMode: .right, surface: Self.surface, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear),
            pointerCurves: PointerCurve.builtInCurves, clickTap: nil, deliver: { delivered.append($0, $1) })
    }

    private func touch(_ id: Int32, _ phase: Touch.Phase, _ x: Double, _ y: Double) -> Touch {
        Touch(id: TouchID(rawValue: id), phase: phase, position: SurfacePoint(x: x / Self.surface.widthMM, y: y / Self.surface.heightMM))
    }

    /// The thumb rests 4 s, then two slides down under it, each 3.5 mm and then 12 mm more in 10 ms frames, then a
    /// lift and a frame with only the thumb. `slides`: each slide's frames, the second's starting after the first's.
    private func frames() -> (all: [TouchFrame], slides: [Range<Int>]) {
        var frames = [TouchFrame(time: FrameTime(seconds: 1), touches: [touch(9, .landing, 10, 10)], press: nil)]
        var slides: [Range<Int>] = []
        var time = 5.0
        for ids: (Int32, Int32) in [(1, 2), (3, 4)] {
            let first = frames.count
            let moves = Array(repeating: 0.35, count: 10) + Array(repeating: 1.2, count: 10)
            var along = 0.0
            for (i, move) in ([0.0] + moves).enumerated() {
                along += move
                let phase: Touch.Phase = i == 0 ? .landing : .down
                frames.append(TouchFrame(
                    time: FrameTime(seconds: time),
                    touches: [touch(9, .down, 10, 10), touch(ids.0, phase, 62, 30 + along), touch(ids.1, phase, 70, 30 + along)],
                    press: nil))
                time += 0.01
            }
            for _ in 0..<2 {
                frames.append(TouchFrame(time: FrameTime(seconds: time), touches: [touch(9, .down, 10, 10)], press: nil))
                time += 0.01
            }
            slides.append(first..<frames.count)
        }
        return (frames, slides)
    }

    /// A frame that reported a window swipe start, and that start's reply.
    private typealias Start = (frame: Int, reply: @Sendable (Bool) -> Void)

    /// What a session did over `frames()`: each frame's `blocksClicks`, and the frames that reported a window swipe
    /// start, with each start's reply.
    private struct Played {
        var blocks: [Bool] = []
        var starts: [Start] = []
        /// Whether every delivered event carried a reply exactly when it was a window swipe start.
        var onlyStartsCarryAReply = true

        var blockedFrames: [Int] { blocks.indices.filter { blocks[$0] } }
    }

    /// Plays `frames()` through a fresh session. After each frame, `answering` gets that frame's index and every start
    /// so far, and may call their replies, before the session's `blocksClicks` is read.
    private func play(answering: (_ frame: Int, _ starts: [Start]) -> Void) -> Played {
        let delivered = Delivered()
        let session = session(delivered)
        var played = Played()
        for (index, frame) in frames().all.enumerated() {
            let before = delivered.all.count
            session.receive(frame)
            for (event, reply) in delivered.all.dropFirst(before) {
                let isStart = if case .windowSwipe(let e) = event, e.phase == .began { true } else { false }
                if (reply != nil) != isStart { played.onlyStartsCarryAReply = false }
                if let reply { played.starts.append((index, reply)) }
            }
            answering(index, played.starts)
            played.blocks.append(session.blocksClicks)
        }
        return played
    }

    /// The frame the first slide's fingers lift on.
    private var firstLift: Int { frames().slides[0].upperBound - 2 }

    @Test func eachSlideReportsOneStartAndOnlyAStartCarriesAReply() {
        let played = play { _, _ in }
        #expect(played.starts.count == 2)
        #expect(played.onlyStartsCarryAReply)
    }

    @Test func aStartConfirmedAtOnceBlocksClicksFromTheNextFrameUntilTheLift() {
        let played = play { frame, starts in
            if starts.count == 1, starts[0].frame == frame { starts[0].reply(true) }
        }
        let start = played.starts.first?.frame ?? -1
        #expect(played.blockedFrames == Array((start + 1)..<firstLift))
    }

    @Test func aStartDeclinedAtOnceNeverBlocksClicks() {
        let played = play { frame, starts in
            if starts.count == 1, starts[0].frame == frame { starts[0].reply(false) }
        }
        #expect(played.blockedFrames.isEmpty)
    }

    @Test func aStartNeverAnsweredNeverBlocksClicks() {
        let played = play { _, _ in }
        #expect(played.blockedFrames.isEmpty)
    }

    @Test func aConfirmationOfTheFirstStartArrivingAfterTheSecondStartNeverBlocksClicks() {
        let played = play { frame, starts in
            if starts.count == 2, starts[1].frame == frame { starts[0].reply(true) }
        }
        #expect(played.blockedFrames.isEmpty)
    }
}
