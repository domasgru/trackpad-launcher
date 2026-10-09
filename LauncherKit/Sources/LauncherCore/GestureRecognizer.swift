import Foundation

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// At most once per tap, on the frame where its last finger is gone.
    public let fired: Gesture?
    /// This trackpad's half of click blocking: a thumb this recognizer saw land less than 3 s ago is still anchored,
    /// and another contact is down. Whether a press is really blocked also needs the click filter armed (access
    /// granted, gestures active), which the recognizer never knows.
    public let blocksClicks: Bool

    public init(fired: Gesture?, blocksClicks: Bool) {
        self.fired = fired
        self.blocksClicks = blocksClicks
    }
}

/// The tap-with-anchored-thumb rules for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) {
        self.corner = AnchorCorner(handMode, surface: surface)
        self.surface = surface
    }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        let isFirstFrame = previouslyDown == nil
        let before = previouslyDown ?? []
        let down = Dictionary(frame.touches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let reused = Set(frame.touches.filter { $0.phase == .landing && before.contains($0.id) }.map(\.id))
        let lifted = before.subtracting(down.keys).union(reused)
        let landed = frame.touches.filter { $0.phase == .landing || !before.contains($0.id) }
        defer { previouslyDown = Set(down.keys) }

        if let anchor = state.anchor,
           lifted.contains(anchor.id) || !(down[anchor.id].map { corner.holds($0.position) } ?? false) {
            state = .idle
        }

        var fired: Gesture?
        switch state {
        case .idle:
            if let thumb = landed.first(where: { corner.admits($0.position) }) {
                // A contact present on the first frame (a reconcile under a resting hand) anchors but opens no
                // blocking window: its real landing time is unknown, whatever phase the driver reports.
                let anchor = Anchor(id: thumb.id, landedAt: isFirstFrame ? nil : frame.time)
                state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)
            }
        case .armed(let anchor):
            let fingers = landed.filter { $0.id != anchor.id }
            if !fingers.isEmpty {
                state = frame.press == .click ? .spoiled(anchor) : .tapping(anchor, Tap(start: frame.time, landing: fingers))
            }
        case .tapping(let anchor, var tap):
            for id in lifted { tap.down[id] = nil }
            if frame.press == .click
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
        let blocksClicks = state.anchor.flatMap { anchor in
            anchor.landedAt.map { landedAt in
                frame.time - landedAt < GestureRules.clickBlockingWindow
                    && down.keys.contains { $0 != anchor.id }
            }
        } ?? false
        return Recognition(fired: fired, blocksClicks: blocksClicks)
    }

    private struct Anchor: Sendable {
        let id: TouchID
        /// When this recognizer saw the thumb land. nil: the thumb was already there on the first frame.
        let landedAt: FrameTime?
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
    /// Contacts down on the previous frame. nil until the first frame.
    private var previouslyDown: Set<TouchID>?
}
