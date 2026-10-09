import CoreGraphics
import LauncherCore
import Synchronization

/// One running trackpad, replaced by every `run`, which resets its blocking flag by construction.
/// Its recognizer is stepped only by that device's frame callbacks; the Mutex is the compiler's proof of that
/// and is never contended.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    private let recognizer: Mutex<GestureRecognizer>
    /// Writer: this device's frame callback. Reader: the click tap's thread.
    private let blocking = Mutex(false)
    private let deliver: @Sendable (GestureEvent) -> Void

    init(trackpad: TrackpadID, recognizer: GestureRecognizer, deliver: @escaping @Sendable (GestureEvent) -> Void) {
        self.trackpad = trackpad
        self.recognizer = Mutex(recognizer)
        self.deliver = deliver
    }

    /// Frame thread.
    func receive(_ frame: TouchFrame) {
        let recognition = recognizer.withLock { $0.step(frame) }
        blocking.withLock { $0 = recognition.blocksClicks }
        if let gesture = recognition.fired {
            deliver(GestureEvent(gesture: gesture, trackpad: trackpad))
        }
    }

    /// Frame thread: the click filter's summary when a tap is live, nil otherwise. No tap exists yet.
    var holding: ClickFilter.Holding? { nil }

    /// Click tap thread.
    var blocksClicks: Bool { blocking.withLock { $0 } }
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

/// A state query on the session's event source: no event tap, no permission.
func anyMouseButtonDown() -> Bool {
    [CGMouseButton.left, .right, .center].contains { CGEventSource.buttonState(.combinedSessionState, button: $0) }
}
