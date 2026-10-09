import Foundation

/// The tap-with-anchored-thumb rules for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) {
        self.corner = AnchorCorner(handMode, surface: surface)
        self.surface = surface
    }

    /// The gesture that fired on this frame, if any. At most once per tap, on the frame where the last finger lifts.
    public mutating func step(_ frame: TouchFrame) -> Gesture? {
        let down = Dictionary(frame.touches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let reused = Set(frame.touches.filter { $0.phase == .landing && previouslyDown.contains($0.id) }.map(\.id))
        let lifted = previouslyDown.subtracting(down.keys).union(reused)
        let landed = frame.touches.filter { $0.phase == .landing || !previouslyDown.contains($0.id) }
        defer { previouslyDown = Set(down.keys) }

        if let anchor = state.anchor,
           lifted.contains(anchor.id) || !(down[anchor.id].map { corner.holds($0.position) } ?? false) {
            state = .idle
        }

        var fired: Gesture?
        switch state {
        case .idle:
            if let thumb = landed.first(where: { corner.admits($0.position) }) {
                let anchor = Anchor(id: thumb.id)
                state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)
            }
        case .armed(let anchor):
            let fingers = landed.filter { $0.id != anchor.id }
            if !fingers.isEmpty {
                state = frame.buttonDown ? .spoiled(anchor) : Self.tapping(anchor, landed: fingers, at: frame.time)
            }
        case .tapping(let anchor, var fingers, var peak, let start):
            fingers = fingers.filter { !lifted.contains($0.key) }
            if frame.buttonDown
                || frame.time - start > GestureRules.maxTapDuration
                || fingers.contains(where: { id, origin in
                    down[id].map { surface.distanceMM(origin, $0.position) > GestureRules.dragThresholdMM } ?? false
                }) {
                state = .spoiled(anchor)
            } else if fingers.isEmpty {
                fired = Gesture(fingerCount: peak)
                let new = landed.filter { $0.id != anchor.id }
                state = new.isEmpty ? .armed(anchor) : Self.tapping(anchor, landed: new, at: frame.time)
            } else {
                for touch in landed where touch.id != anchor.id {
                    fingers[touch.id] = touch.position
                }
                peak = max(peak, fingers.count)
                state = .tapping(anchor, fingers: fingers, peak: peak, start: start)
            }
        case .spoiled(let anchor):
            if down.keys.allSatisfy({ $0 == anchor.id }) {
                state = .armed(anchor)
            }
        }
        return fired
    }

    private static func tapping(_ anchor: Anchor, landed: [Touch], at time: FrameTime) -> State {
        .tapping(anchor, fingers: landingPoints(landed), peak: landed.count, start: time)
    }

    private struct Anchor: Sendable {
        let id: TouchID
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, fingers: [TouchID: SurfacePoint], peak: Int, start: FrameTime)
        case spoiled(Anchor)

        var anchor: Anchor? {
            switch self {
            case .idle: nil
            case .armed(let a), .tapping(let a, _, _, _), .spoiled(let a): a
            }
        }
    }

    private static func landingPoints(_ touches: [Touch]) -> [TouchID: SurfacePoint] {
        Dictionary(touches.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID> = []
}
