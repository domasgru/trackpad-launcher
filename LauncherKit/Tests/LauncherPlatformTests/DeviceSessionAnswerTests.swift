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

    enum Replying: CaseIterable {
        case confirmAtOnce, declineAtOnce, never, confirmAfterTheSecondStart
    }

    @Test(arguments: Replying.allCases)
    func aWindowSwipeBlocksClicksOnlyOnceItsOwnStartIsConfirmed(replying: Replying) {
        let delivered = Delivered()
        let session = session(delivered)
        let (frames, slides) = frames()
        var blocks: [Bool] = []
        var starts: [Int] = []
        for (index, frame) in frames.enumerated() {
            let before = delivered.all.count
            session.receive(frame)
            let new = delivered.all.dropFirst(before)
            for (event, reply) in new {
                let isStart = if case .windowSwipe(let e) = event, e.phase == .began { true } else { false }
                #expect((reply != nil) == isStart, "frame \(index)")
                if isStart { starts.append(index) }
            }
            if let reply = new.first?.reply {
                switch replying {
                case .confirmAtOnce: if starts.count == 1 { reply(true) }
                case .declineAtOnce: if starts.count == 1 { reply(false) }
                case .never, .confirmAfterTheSecondStart: break
                }
            }
            if replying == .confirmAfterTheSecondStart, starts.count == 2, starts[1] == index {
                delivered.all.first { $0.reply != nil }?.reply?(true)
            }
            blocks.append(session.blocksClicks)
        }
        #expect(starts.count == 2)
        guard starts.count == 2 else { return }
        let lift = slides[0].upperBound - 2
        switch replying {
        case .confirmAtOnce:
            #expect(blocks[slides[0]].enumerated().allSatisfy { i, blocked in
                blocked == (slides[0].lowerBound + i > starts[0] && slides[0].lowerBound + i < lift)
            })
        case .declineAtOnce, .never:
            #expect(!blocks.contains(true))
        case .confirmAfterTheSecondStart:
            #expect(!blocks[slides[1]].contains(true))
        }
    }
}
