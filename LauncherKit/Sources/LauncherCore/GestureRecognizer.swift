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
                state = frame.buttonDown ? .spoiled(anchor) : .tapping(anchor, Tap(start: frame.time, landing: fingers))
            }
        case .tapping(let anchor, var tap):
            for id in lifted { tap.down[id] = nil }
            if frame.buttonDown
                || frame.time - tap.start > GestureRules.maxTapDuration
                || tap.down.contains(where: { id, origin in
                    down[id].map { surface.distanceMM(origin, $0.position) > GestureRules.dragThresholdMM } ?? false
                }) {
                state = .spoiled(anchor)
            } else if tap.down.isEmpty {
                fired = Gesture(fingerCount: tap.touched.count)
                let new = landed.filter { $0.id != anchor.id }
                state = new.isEmpty ? .armed(anchor) : .tapping(anchor, Tap(start: frame.time, landing: new))
            } else {
                for touch in landed where touch.id != anchor.id {
                    tap.land(touch)
                }
                state = .tapping(anchor, tap)
            }
        case .spoiled(let anchor):
            if down.keys.allSatisfy({ $0 == anchor.id }) {
                state = .armed(anchor)
            }
        }
        return fired
    }

    private struct Anchor: Sendable {
        let id: TouchID
    }

    private struct Tap: Sendable {
        let start: FrameTime
        /// Fingers down now, with their landing points (the drag check).
        var down: [TouchID: SurfacePoint]
        /// Every finger that touched during this tap. Always a superset of `down.keys`.
        private(set) var touched: Set<TouchID>

        init(start: FrameTime, landing: [Touch]) {
            self.start = start
            down = [:]
            touched = []
            for touch in landing { land(touch) }
        }

        /// The only way a finger joins: a re-landed id gets a new origin but still counts once.
        mutating func land(_ touch: Touch) {
            down[touch.id] = touch.position
            touched.insert(touch.id)
        }
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        case spoiled(Anchor)

        var anchor: Anchor? {
            switch self {
            case .idle: nil
            case .armed(let a), .tapping(let a, _), .spoiled(let a): a
            }
        }
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID> = []
}
