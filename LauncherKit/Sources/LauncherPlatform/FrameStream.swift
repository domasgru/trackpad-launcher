import CoreGraphics
import LauncherCore
import Synchronization

/// One running trackpad, replaced by every `run`, which resets its blocking flag by construction.
/// Its recognizer is stepped only by that device's frame callbacks; the Mutex is the compiler's proof of that
/// and is never contended.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    private let recognizer: Mutex<GestureRecognizer>
    /// This device's cursor acceleration curves, read once when the session starts.
    private let pointerCurves: [PointerCurve.Point]
    /// Writer: this device's frame callback. Reader: the click tap's thread.
    private let blocking = Mutex(false)
    /// Writer: this device's frame callback. Reader: the click tap's thread.
    private let blockingDockSwipes = Mutex(false)
    /// Installed by the same `run`, if any.
    private let clickTap: ClickTap?
    private let deliver: @Sendable (TrackpadEvent) -> Void

    init(
        trackpad: TrackpadID, recognizer: GestureRecognizer, pointerCurves: [PointerCurve.Point], clickTap: ClickTap?,
        deliver: @escaping @Sendable (TrackpadEvent) -> Void
    ) {
        self.trackpad = trackpad
        self.recognizer = Mutex(recognizer)
        self.pointerCurves = pointerCurves
        self.clickTap = clickTap
        self.deliver = deliver
    }

    /// Frame thread.
    func receive(_ frame: TouchFrame) {
        let recognition = recognizer.withLock {
            let recognition = $0.step(frame)
            // Each slide follows the cursor's acceleration at the tracking speed set when it starts. Travel is 0 on
            // the frame a slide begins, so the next frame is the first to use it.
            if recognition.beginsSlide { $0.travel = CursorTravel.travel(curves: pointerCurves) }
            return recognition
        }
        blocking.withLock { $0 = recognition.blocksClicks }
        blockingDockSwipes.withLock { $0 = recognition.blocksDockSwipes }
        if let event = recognition.event {
            deliver(TrackpadEvent(event, on: trackpad))
        }
    }

    /// Frame thread: the click filter's summary when a tap is live, nil otherwise.
    var holding: ClickFilter.Holding? { clickTap?.holding }

    /// Click tap thread.
    var blocksClicks: Bool { blocking.withLock { $0 } }

    /// Click tap thread.
    var blocksDockSwipes: Bool { blockingDockSwipes.withLock { $0 } }
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

/// Whether some running trackpad is inside its blocking window, merged across trackpads at the read.
/// Copies the sessions out first, so no lock is held while another is taken.
func anyTrackpadBlocksClicks() -> Bool {
    Array(sessions.withLock { $0.values }).contains { $0.blocksClicks }
}

/// Whether some running trackpad has a thumb anchored with another contact down, or a swipe on. Merged like
/// `anyTrackpadBlocksClicks()`.
func anyTrackpadBlocksDockSwipes() -> Bool {
    Array(sessions.withLock { $0.values }).contains { $0.blocksDockSwipes }
}
