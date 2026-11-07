import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

@Suite(.serialized) struct DeviceSessionContactTests {
    private static let surface = SurfaceSize(widthMM: 124.8, heightMM: 76.8)

    private final class Delivered: Sendable {
        private let events = Mutex<[TrackpadEvent]>([])
        func append(_ event: TrackpadEvent) { events.withLock { $0.append(event) } }
        var contactChanges: Int {
            events.withLock { $0.filter { if case .contactChanged = $0 { true } else { false } }.count }
        }
        var count: Int { events.withLock { $0.count } }
    }

    private final class Flag: Sendable {
        private let value: Mutex<Bool>
        init(_ initial: Bool) { value = Mutex(initial) }
        var isOn: Bool {
            get { value.withLock { $0 } }
            set { value.withLock { $0 = newValue } }
        }
    }

    private final class ClockReads: Sendable {
        private let reads = Mutex(0)
        var count: Int { reads.withLock { $0 } }
        func read() -> Uptime {
            reads.withLock { $0 += 1 }
            return Uptime(seconds: 10)
        }
    }

    private func session(
        _ delivered: Delivered, senses: Flag, reads: ClockReads = ClockReads(), id: UInt64 = 1
    ) -> DeviceSession {
        DeviceSession(
            trackpad: TrackpadID(rawValue: id),
            recognizer: GestureRecognizer(
                corner: .topLeft, surface: Self.surface, slides: [.swipe, .windowSwipe], swaps: true, travel: .linear),
            pointerCurves: PointerCurve.builtInCurves, tap: nil, clock: { reads.read() },
            sensesContact: { senses.isOn }, deliver: { event, _ in delivered.append(event) })
    }

    private func touch(_ id: Int32, _ phase: Touch.Phase, _ x: Double, _ y: Double) -> Touch {
        Touch(id: TouchID(rawValue: id), phase: phase, position: SurfacePoint(x: x / Self.surface.widthMM, y: y / Self.surface.heightMM))
    }

    /// Each frame with the occupancy it must leave behind.
    private func frames() -> [(frame: TouchFrame, occupied: Bool)] {
        let finger = touch(1, .landing, 60, 40)
        let other = touch(2, .landing, 70, 40)
        let palmAtTheEdge = touch(3, .landing, 0.5, 76)
        let contents: [([Touch], Bool)] = [
            ([], false),
            ([finger], true),
            ([touch(1, .down, 60, 40), other], true),
            ([touch(2, .down, 70, 40)], true),
            ([], false),
            ([palmAtTheEdge], true),
            ([], false),
        ]
        return contents.enumerated().map { index, content in
            (TouchFrame(time: FrameTime(seconds: 1 + Double(index) * 0.01), touches: content.0, press: nil), content.1)
        }
    }

    @Test func contactChangedComesOnExactlyTheFlipsAndOccupancyFollows() {
        let delivered = Delivered()
        let session = session(delivered, senses: Flag(true))
        var changes: [Int] = []

        for step in frames() {
            session.receive(step.frame)
            changes.append(delivered.contactChanges)
            #expect(session.isOccupied == step.occupied)
        }

        #expect(changes == [0, 1, 1, 1, 2, 3, 4])
    }

    @Test func framesFromDriverStatesTwoAndFiveOnlyAreNoContact() {
        var buffer = [
            MTTouchMirror(identifier: 9, state: 2, x: 0.3, y: 0.3),
            MTTouchMirror(identifier: 10, state: 5, x: 0.4, y: 0.4),
        ]
        let frame = buffer.withUnsafeMutableBytes {
            TouchFrame(parsing: $0.baseAddress, count: 2, timestamp: 1, press: nil)
        }
        let delivered = Delivered()
        let session = session(delivered, senses: Flag(true))

        session.receive(frame)

        #expect(!session.isOccupied)
        #expect(delivered.contactChanges == 0)
    }

    @Test func withSensingOffNothingIsDeliveredOccupancyStillTracksAndTheClockIsReadAsOften() {
        let silent = Delivered()
        let silentReads = ClockReads()
        let quiet = session(silent, senses: Flag(false), reads: silentReads)
        let sensed = Delivered()
        let sensedReads = ClockReads()
        let loud = session(sensed, senses: Flag(true), reads: sensedReads)

        for step in frames() {
            quiet.receive(step.frame)
            loud.receive(step.frame)
            #expect(quiet.isOccupied == step.occupied)
        }

        #expect(silent.contactChanges == 0)
        #expect(sensed.contactChanges == 4)
        #expect(silentReads.count == sensedReads.count)
    }

    @Test func sensingTurnedOnWithAFingerDownDeliversNothingUntilTheNextFlip() {
        let delivered = Delivered()
        let senses = Flag(false)
        let session = session(delivered, senses: senses)
        let steps = frames()
        session.receive(steps[1].frame)

        senses.isOn = true
        session.receive(steps[2].frame)
        session.receive(steps[3].frame)
        #expect(delivered.contactChanges == 0)
        session.receive(steps[4].frame)

        #expect(delivered.contactChanges == 1)
    }

    @Test func anyTrackpadTouchedIsTrueWhenEitherIsOccupiedAndFalseWhenNeitherIs() {
        let first = session(Delivered(), senses: Flag(false), id: 1)
        let second = session(Delivered(), senses: Flag(false), id: 2)
        let steps = frames()

        #expect(!anyOccupied([first, second]))
        second.receive(steps[1].frame)
        #expect(anyOccupied([first, second]))
        first.receive(steps[1].frame)
        second.receive(steps[4].frame)
        #expect(anyOccupied([first, second]))
        first.receive(steps[4].frame)
        #expect(!anyOccupied([first, second]))
    }

    @Test func aReplacedSessionsContactReadsFalse() {
        let running = session(Delivered(), senses: Flag(false))
        running.receive(frames()[1].frame)
        sessions.withLock { $0 = [1: running] }
        #expect(isAnyTrackpadTouched())

        sessions.withLock { $0 = [:] }

        #expect(!isAnyTrackpadTouched())
    }
}
