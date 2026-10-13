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
    surface: SurfaceSize = .macBook14,
    swipes: Bool = true,
    swaps: Bool = true
) -> [Gesture] {
    var recognizer = GestureRecognizer(handMode: handMode, surface: surface, swipes: swipes, swaps: swaps, travel: .linear)
    return frames.compactMap { recognizer.step($0).fired }
}

/// Runs a fresh recognizer over `frames` and returns every swipe phase it reported, in order.
func phases(
    _ frames: [TouchFrame],
    handMode: HandMode = .right,
    surface: SurfaceSize = .macBook14,
    swipes: Bool = true,
    swaps: Bool = true
) -> [SwipePhase] {
    var recognizer = GestureRecognizer(handMode: handMode, surface: surface, swipes: swipes, swaps: swaps, travel: .linear)
    return frames.compactMap { recognizer.step($0).swipe }
}

/// Runs a fresh recognizer over `frames` and returns `startsSeries` of every swap it reported, in order.
func swaps(
    _ frames: [TouchFrame],
    handMode: HandMode = .right,
    surface: SurfaceSize = .macBook14,
    swaps: Bool = true
) -> [Bool] {
    var recognizer = GestureRecognizer(handMode: handMode, surface: surface, swipes: true, swaps: swaps, travel: .linear)
    return frames.compactMap { recognizer.step($0).swapStartsSeries }
}

/// Per frame: what the recognizer said about a swipe, and whether it blocked clicks.
func perFrame(
    _ frames: [TouchFrame],
    handMode: HandMode = .right,
    surface: SurfaceSize = .macBook14,
    swaps: Bool = true
) -> [(swipe: SwipePhase?, blocks: Bool)] {
    var recognizer = GestureRecognizer(handMode: handMode, surface: surface, swipes: true, swaps: swaps, travel: .linear)
    return frames.map {
        let recognition = recognizer.step($0)
        return (recognition.swipe, recognition.blocksClicks)
    }
}

extension SwipePhase {
    /// Equality with travel compared within 1e-9 millimetres.
    func isCloseTo(_ other: SwipePhase) -> Bool {
        if case .moved(let a) = self, case .moved(let b) = other { return abs(a - b) < 1e-9 }
        return self == other
    }
}

func phasesMatch(_ actual: [SwipePhase], _ expected: [SwipePhase]) -> Bool {
    actual.count == expected.count && zip(actual, expected).allSatisfy { $0.isCloseTo($1) }
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

    func frame(atMS ms: Int, _ touches: [Touch] = [], press: TouchFrame.Press? = nil) -> TouchFrame {
        TouchFrame(time: FrameTime(seconds: 1.0 + Double(ms) / 1000), touches: touches, press: press)
    }
}

enum Fixtures {
    /// The record the build before the switcher saved: hand mode and gestures 1...4, no other keys.
    static func recordSavedByPlan002(handMode: HandMode = .right, two: AppEntry? = nil) -> Data {
        struct Saved: Codable {
            var handMode: HandMode
            var assignments: [Gesture: AssignedApp]
        }
        var saved = Saved(handMode: handMode, assignments: [:])
        if let two { saved.assignments[.two] = AssignedApp(two) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try! encoder.encode(saved)
    }
}
