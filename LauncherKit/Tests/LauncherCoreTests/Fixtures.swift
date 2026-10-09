import Foundation
import LauncherCore

extension SurfaceSize {
    /// Probed on a 14" MacBook Pro: 12480 x 7680 hundredths of a millimetre.
    static let macBook14 = SurfaceSize(widthMM: 124.8, heightMM: 76.8)
    static let magicTrackpad = SurfaceSize(widthMM: 160, heightMM: 115)

    /// A point given in millimetres from the top-left corner.
    func point(mm x: Double, _ y: Double) -> SurfacePoint {
        SurfacePoint(x: x / widthMM, y: y / heightMM)
    }
}

extension Trackpad {
    static let macBook14 = Trackpad(id: TrackpadID(rawValue: 1), kind: .builtIn, surface: .macBook14)
    static let magicTrackpad = Trackpad(id: TrackpadID(rawValue: 2), kind: .external, surface: .magicTrackpad)
}

/// Runs a fresh recognizer over `frames` and returns everything that fired, in order.
func fired(
    _ frames: [TouchFrame],
    handMode: HandMode = .right,
    surface: SurfaceSize = .macBook14
) -> [Gesture] {
    var recognizer = GestureRecognizer(handMode: handMode, surface: surface)
    return frames.compactMap { recognizer.step($0) }
}

/// Hand-built frames for the interleavings `TouchScript` cannot sequence.
struct HandFrames {
    let surface: SurfaceSize

    init(_ surface: SurfaceSize = .macBook14) {
        self.surface = surface
    }

    func contact(_ id: Int32, _ phase: Touch.Phase = .down, atMM x: Double, _ y: Double) -> Touch {
        Touch(id: TouchID(rawValue: id), phase: phase, position: surface.point(mm: x, y))
    }

    func frame(atMS ms: Int, _ touches: [Touch] = [], buttonDown: Bool = false) -> TouchFrame {
        TouchFrame(time: FrameTime(seconds: 1.0 + Double(ms) / 1000), touches: touches, buttonDown: buttonDown)
    }
}
