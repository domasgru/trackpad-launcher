import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

@Suite struct DeviceSessionTravelTests {
    private static let surface = SurfaceSize(widthMM: 124.8, heightMM: 76.8)

    /// Every event a session delivered, in order.
    private final class Delivered: Sendable {
        private let events = Mutex<[TrackpadEvent]>([])
        func append(_ event: TrackpadEvent) { events.withLock { $0.append(event) } }
        var all: [TrackpadEvent] { events.withLock { $0 } }
    }

    private func session(_ delivered: Delivered) -> DeviceSession {
        DeviceSession(
            trackpad: TrackpadID(rawValue: 1),
            recognizer: GestureRecognizer(
                handMode: .right, surface: Self.surface, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear),
            pointerCurves: PointerCurve.builtInCurves, tap: nil, deliver: { event, reply in
                delivered.append(event)
                reply?(true)
            })
    }

    private func touch(_ id: Int32, _ phase: Touch.Phase, _ x: Double, _ y: Double) -> Touch {
        Touch(id: TouchID(rawValue: id), phase: phase, position: SurfacePoint(x: x / Self.surface.widthMM, y: y / Self.surface.heightMM))
    }

    /// The thumb anchors, two fingers land, then slide 3.5 mm and 12 mm along `step` in 10 ms frames.
    private func frames(origin: (x: Double, y: Double), step: (x: Double, y: Double)) -> [TouchFrame] {
        var frames = [TouchFrame(time: FrameTime(seconds: 1), touches: [touch(9, .landing, 10, 10)], press: nil)]
        let moves = Array(repeating: 0.35, count: 10) + Array(repeating: 1.2, count: 10)
        var along = 0.0
        for (i, move) in ([0.0] + moves).enumerated() {
            along += move
            let phase: Touch.Phase = i == 0 ? .landing : .down
            let x = origin.x + step.x * along, y = origin.y + step.y * along
            frames.append(TouchFrame(
                time: FrameTime(seconds: 1.05 + Double(i) / 100),
                touches: [touch(9, .down, 10, 10), touch(1, phase, x, y), touch(2, phase, x + 8, y)], press: nil))
        }
        return frames
    }

    @Test func aWindowSwipeTravelsDownExactlyAsFarAsASwipeTravelsRightForTheSameFingerMovement() {
        let down = Delivered(), right = Delivered()
        let a = session(down), b = session(right)
        let framesA = frames(origin: (62, 30), step: (0, 1))
        let framesB = frames(origin: (62, 45), step: (1, 0))

        var pairs: [(Double?, Double?)] = []
        for (frameA, frameB) in zip(framesA, framesB) {
            let before = (down.all.count, right.all.count)
            a.receive(frameA)
            b.receive(frameB)
            let windowTravel = down.all.dropFirst(before.0).compactMap { event -> Double? in
                if case .windowSwipe(let e) = event, case .moved(let travel) = e.phase { travel } else { nil }
            }.first
            let swipeTravel = right.all.dropFirst(before.1).compactMap { event -> Double? in
                if case .swipe(let e) = event, case .moved(let travel) = e.phase { travel } else { nil }
            }.first
            pairs.append((windowTravel, swipeTravel))
        }

        let moved = pairs.filter { $0.0 != nil || $0.1 != nil }
        #expect(moved.count >= 10)
        for (window, swipe) in moved {
            #expect(window != nil && swipe != nil && abs(window! - swipe!) < 1e-9, "\(String(describing: window)) vs \(String(describing: swipe))")
        }
        #expect(right.all.allSatisfy { if case .windowSwipe = $0 { false } else { true } })
        #expect(down.all.allSatisfy { if case .swipe = $0 { false } else { true } })
    }
}
