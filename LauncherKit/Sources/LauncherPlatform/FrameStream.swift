import CoreGraphics
import LauncherCore
import Synchronization

/// One running trackpad. Its recognizer is stepped only by that device's frame callbacks;
/// the Mutex is the compiler's proof of that and is never contended.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    private let recognizer: Mutex<GestureRecognizer>
    private let deliver: @Sendable (GestureEvent) -> Void

    init(trackpad: TrackpadID, recognizer: GestureRecognizer, deliver: @escaping @Sendable (GestureEvent) -> Void) {
        self.trackpad = trackpad
        self.recognizer = Mutex(recognizer)
        self.deliver = deliver
    }

    func receive(_ frame: TouchFrame) {
        if let gesture = recognizer.withLock({ $0.step(frame) }) {
            deliver(GestureEvent(gesture: gesture, trackpad: trackpad))
        }
    }
}

/// The only state shared with the frame thread: written by `run` (main), read by the callback.
/// Key: the device ref's bit pattern. `run` empties it before it touches any device, so a frame that is
/// already in flight for a device being torn down finds nothing and is dropped.
let sessions = Mutex<[UInt: DeviceSession]>([:])

let contactFrameCallback: MultitouchSupport.ContactFrameCallback = { device, touches, count, timestamp, _ in
    guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    session.receive(
        TouchFrame(parsing: touches, count: count, timestamp: timestamp, buttonDown: anyMouseButtonDown()))
    return 0
}

/// A state query on the session's event source: no event tap, no permission.
func anyMouseButtonDown() -> Bool {
    [CGMouseButton.left, .right, .center].contains { CGEventSource.buttonState(.combinedSessionState, button: $0) }
}
