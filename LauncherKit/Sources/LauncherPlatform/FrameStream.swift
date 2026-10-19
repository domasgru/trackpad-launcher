import CoreGraphics
import LauncherCore
import Synchronization

/// The answer to one window swipe start: the frame time the start was reported on, and whether it is a window swipe.
struct WindowSwipeAnswer: Sendable {
    let began: FrameTime
    let isWindowSwipe: Bool
}

/// What a session needs from the click tap: the press summary and a wake-up.
protocol TapLink: Sendable {
    var holding: ClickFilter.Holding { get }
    /// Never waits.
    func wake()
}

extension ClickTap: TapLink {}

/// One running trackpad, replaced by every `run`, which resets its blocking flag by construction.
/// Its recognizer is stepped only by that device's frame callbacks; the Mutex is the compiler's proof of that
/// and is never contended.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    private let recognizer: Mutex<GestureRecognizer>
    /// This device's cursor acceleration curves, read once when the session starts.
    private let pointerCurves: [PointerCurve.Point]
    /// Writer: this device's frame callback. Reader: the click tap's thread.
    private let level = Mutex(Blocking.none)
    /// Installed by the same `run`, if any.
    private let tap: (any TapLink)?
    /// Writer: the main actor, through a reply. Reader: this device's frame callback, which hands it to the recognizer
    /// before each step. Never cleared: the recognizer ignores an answer it has already taken or that names another
    /// start.
    private let answer = Mutex<WindowSwipeAnswer?>(nil)
    private let deliver: @Sendable (TrackpadEvent, _ reply: (@Sendable (Bool) -> Void)?) -> Void

    /// `deliver` carries, for a frame that reported `.windowSwipe(.began)`, the reply for that start: called once on the
    /// main actor, it records whether the start is a window swipe for the recognizer's next frame. nil for every other
    /// event.
    init(
        trackpad: TrackpadID, recognizer: GestureRecognizer, pointerCurves: [PointerCurve.Point],
        tap: (any TapLink)?,
        deliver: @escaping @Sendable (TrackpadEvent, _ reply: (@Sendable (Bool) -> Void)?) -> Void
    ) {
        self.trackpad = trackpad
        self.recognizer = Mutex(recognizer)
        self.pointerCurves = pointerCurves
        self.tap = tap
        self.deliver = deliver
    }

    /// Frame thread.
    func receive(_ frame: TouchFrame) {
        let latestAnswer = answer.withLock { $0 }
        let recognition = recognizer.withLock {
            if let latestAnswer {
                $0.answerWindowSwipe(began: latestAnswer.began, isWindowSwipe: latestAnswer.isWindowSwipe)
            }
            let recognition = $0.step(frame)
            // Each slide follows the cursor's acceleration at the tracking speed set when it starts. Travel is 0 on
            // the frame a slide begins, so the next frame is the first to use it.
            if recognition.beginsSlide { $0.travel = CursorTravel.travel(curves: pointerCurves) }
            return recognition
        }
        let flipped = level.withLock { was in
            defer { was = recognition.blocking }
            return was.wantsTap != recognition.blocking.wantsTap
        }
        if flipped { tap?.wake() }
        if let event = recognition.event {
            var reply: (@Sendable (Bool) -> Void)?
            if recognition.windowSwipe == .began {
                reply = { [self] isWindowSwipe in
                    answer.withLock { $0 = WindowSwipeAnswer(began: frame.time, isWindowSwipe: isWindowSwipe) }
                }
            }
            deliver(TrackpadEvent(event, on: trackpad), reply)
        }
    }

    /// Frame thread: the click filter's summary when a tap is live, nil otherwise.
    var holding: ClickFilter.Holding? { tap?.holding }

    /// Click tap thread.
    var blocking: Blocking { level.withLock { $0 } }

    var blocksClicks: Bool { blocking.blocksClicks }
}

/// The only state shared with the frame thread: written by `run` (main), read by the callback and the click tap.
/// Key: the device ref's bit pattern. `run` empties it before it touches any device, so a frame that is
/// already in flight for a device being torn down finds nothing and is dropped.
let sessions = Mutex<[UInt: DeviceSession]>([:])

let contactFrameCallback: MultitouchSupport.ContactFrameCallback = { device, touches, count, timestamp, _ in
    guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    let press = TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())
    session.receive(TouchFrame(parsing: touches, count: count, timestamp: timestamp, press: press))
    return 0
}

/// A state query on the session's event source, no permission: the no-tap path and the "still down" check of a passed press.
func anyMouseButtonDown() -> Bool {
    [CGMouseButton.left, .right, .center].contains { CGEventSource.buttonState(.combinedSessionState, button: $0) }
}

/// Tap thread: the highest level of any running trackpad. Copies the sessions out first: never two locks at once.
func mergedBlocking() -> Blocking {
    Array(sessions.withLock { $0.values }).map(\.blocking).max() ?? .none
}
