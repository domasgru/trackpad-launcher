import Foundation

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// What one frame produced, if anything. A frame never both fires a tap and moves a swipe.
    public enum Event: Equatable, Sendable {
        case fired(Gesture)
        case swipe(SwipePhase)
    }

    public let event: Event?
    /// This trackpad's half of click blocking: true for the whole of a swipe; otherwise a thumb this recognizer saw
    /// land less than 3 s ago is still anchored and another finger is down. Whether a press is really blocked also
    /// needs the click filter armed (access granted, gestures active), which the recognizer never knows.
    public let blocksClicks: Bool
    /// This trackpad's half of Dock swipe blocking: true for the whole of a swipe, and while any thumb is anchored and
    /// another finger is down, with no time limit. macOS may count the anchored thumb as a finger, so thumb plus two
    /// sliding fingers can read as its three-finger swipe between desktops. Like `blocksClicks`, it only matters
    /// while the tap is armed.
    public let blocksDockSwipes: Bool

    public var fired: Gesture? { if case .fired(let gesture)? = event { gesture } else { nil } }
    public var swipe: SwipePhase? { if case .swipe(let phase)? = event { phase } else { nil } }

    public init(event: Event?, blocksClicks: Bool, blocksDockSwipes: Bool) {
        self.event = event
        self.blocksClicks = blocksClicks
        self.blocksDockSwipes = blocksDockSwipes
    }
}

/// The tap-with-anchored-thumb rules for ONE trackpad, as a pure state machine, plus the swipe that starts under the
/// same thumb. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    /// `swipes`: false (the swipe setting is off): a pair's drag spoils like any drag.
    /// `travel`: how finger movement becomes switcher travel. A var, so a Debug tuner can change it between frames.
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Bool, travel: SwipeTravel) {
        self.corner = AnchorCorner(handMode, surface: surface)
        self.edgeContacts = EdgeContacts(corner: corner, surface: surface)
        self.surface = surface
        self.swipes = swipes
        self.travel = travel
    }

    public var travel: SwipeTravel

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        let frame = edgeContacts.fingers(in: frame)
        let isFirstFrame = previouslyDown == nil
        let before = previouslyDown ?? []
        let down = Dictionary(frame.touches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let reused = Set(frame.touches.filter { $0.phase == .landing && before.contains($0.id) }.map(\.id))
        let lifted = before.subtracting(down.keys).union(reused)
        let landed = frame.touches.filter { $0.isLanding(after: before) }
        defer { previouslyDown = Set(down.keys) }

        if let anchor = state.anchor,
           lifted.contains(anchor.id) || !(down[anchor.id].map { corner.holds($0.position) } ?? false) {
            state = .idle
        }

        var event: Recognition.Event?
        switch state {
        case .idle:
            if let thumb = landed.first(where: { corner.admits($0.position) }) {
                // The pad sends no frames while nothing touches it, so a thumb landing on the first frame really
                // landed now. Only an already-resting contact (`.down`) has an unknown landing time: no window.
                let landedNow = !isFirstFrame || thumb.phase == .landing
                let anchor = Anchor(id: thumb.id, landedAt: landedNow ? frame.time : nil)
                state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)
            }
        case .armed(let anchor):
            let fingers = landed.filter { $0.id != anchor.id }
            if !fingers.isEmpty {
                state = frame.press == .click ? .spoiled(anchor) : .tapping(anchor, Tap(start: frame.time, landing: fingers))
            }
        case .tapping(let anchor, var tap):
            for id in lifted { tap.down[id] = nil }
            let joining = landed.filter { $0.id != anchor.id }
            let pair = swipes ? Pair(tap, joining: joining) : nil
            if frame.press == .click {
                state = .spoiled(anchor)
            } else if let move = Self.drag(of: tap.fingers, in: down, on: surface) {
                (state, event) = beginOrSpoil(pair, move, anchor, down, frame.time)
            } else if frame.time - tap.start > GestureRules.maxTapDuration {
                state = pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)
            } else if tap.down.isEmpty {
                event = Gesture(fingerCount: tap.touched.count).map(Recognition.Event.fired)
                state = joining.isEmpty ? .armed(anchor) : .tapping(anchor, Tap(start: frame.time, landing: joining))
            } else {
                for touch in joining {
                    tap.land(touch)
                }
                state = .tapping(anchor, tap)
            }
        case .resting(let anchor, let pair):
            if frame.press == .click
                || pair.fingers.contains(where: { lifted.contains($0.id) })
                || landed.contains(where: { $0.id != anchor.id }) {
                state = .spoiled(anchor)
            } else if let move = Self.drag(of: pair.fingers, in: down, on: surface) {
                (state, event) = beginOrSpoil(pair, move, anchor, down, frame.time)
            }
        case .spoiled(let anchor):
            if down.keys.allSatisfy({ $0 == anchor.id }) {
                state = .armed(anchor)
            }
        case .swiping(var swipe):
            // The thumb plays no part in a swipe: it is only remembered for what happens after it.
            if let thumb = swipe.thumb,
               lifted.contains(thumb.id) || !(down[thumb.id].map { corner.holds($0.position) } ?? false) {
                swipe.thumb = nil
            }
            if swipe.thumb == nil, let thumb = landed.first(where: { corner.admits($0.position) }) {
                swipe.thumb = Anchor(id: thumb.id, landedAt: frame.time)
            }
            // Until every non-thumb finger has lifted, nothing further happens.
            let after = swipe.thumb.map(State.spoiled) ?? .idle
            // A finger that loses contact for a moment (a light, fast slide) comes back as a new contact, often with
            // a new ID: it rejoins while the other swipe finger is still down. Only a third finger cancels.
            for id in lifted { swipe.fingers[id] = nil }
            let joining = landed.filter { $0.id != swipe.thumb?.id && !corner.admits($0.position) }
            if frame.press == .click || swipe.fingers.count + joining.count > 2 {
                state = after
                event = .swipe(.cancelled)
            } else if swipe.fingers.isEmpty {
                // The swipe lasts until both fingers have lifted. A finger landing on that frame starts nothing.
                state = after
                event = .swipe(.ended)
            } else {
                // Movement is what the fingers present on both frames did, so a finger dropping out or rejoining
                // never makes the highlight jump.
                let moves = swipe.fingers.compactMap { id, last in
                    down[id].map { ($0.position.x - last.x, $0.position.y - last.y) }
                }
                let interval = (frame.time - swipe.lastTime) / .seconds(1)
                for id in swipe.fingers.keys { swipe.fingers[id] = down[id]?.position }
                for touch in joining { swipe.fingers[touch.id] = touch.position }
                swipe.lastTime = frame.time
                if !moves.isEmpty {
                    let count = Double(moves.count)
                    let dxMM = moves.map(\.0).reduce(0, +) / count * surface.widthMM
                    let dyMM = moves.map(\.1).reduce(0, +) / count * surface.heightMM
                    let travel = swipe.travelMM + self.travel.travel(dxMM: dxMM, dyMM: dyMM, interval: interval)
                    if travel != swipe.travelMM {
                        swipe.travelMM = travel
                        event = .swipe(.moved(travelMM: travel))
                    }
                }
                state = .swiping(swipe)
            }
        }
        let blocksClicks: Bool
        let blocksDockSwipes: Bool
        if case .swiping = state {
            blocksClicks = true
            blocksDockSwipes = true
        } else {
            blocksDockSwipes = state.anchor.map { anchor in down.keys.contains { $0 != anchor.id } } ?? false
            blocksClicks = state.anchor.flatMap { anchor in
                anchor.landedAt.map { landedAt in
                    frame.time - landedAt < GestureRules.clickBlockingWindow
                        && down.keys.contains { $0 != anchor.id }
                }
            } ?? false
        }
        return Recognition(event: event, blocksClicks: blocksClicks, blocksDockSwipes: blocksDockSwipes)
    }

    /// A sideways drag of a pair begins the swipe; any other drag spoils the gesture like every drag does.
    private func beginOrSpoil(
        _ pair: Pair?, _ move: Move, _ anchor: Anchor, _ down: [TouchID: Touch], _ time: FrameTime
    ) -> (State, Recognition.Event?) {
        guard let pair, move.isSideways else { return (.spoiled(anchor), nil) }
        let fingers = Dictionary(uniqueKeysWithValues: pair.fingers.compactMap { f in down[f.id].map { (f.id, $0.position) } })
        return (.swiping(Swipe(fingers: fingers, lastTime: time, thumb: anchor)), .swipe(.began))
    }

    private struct Anchor: Sendable {
        let id: TouchID
        /// When this recognizer saw the thumb land. nil: the thumb was already resting on the first frame.
        let landedAt: FrameTime?
    }

    private struct Finger: Sendable {
        let id: TouchID
        let origin: SurfacePoint
    }

    /// Exactly two fingers: the only shape a swipe has.
    private struct Pair: Sendable {
        let first: Finger
        let second: Finger

        /// The tap as a pair: exactly two fingers touched since the last moment none was down, both still down, and
        /// none joins on this frame.
        init?(_ tap: Tap, joining: [Touch]) {
            let fingers = tap.fingers
            guard joining.isEmpty, tap.touched.count == 2, fingers.count == 2 else { return nil }
            first = fingers[0]
            second = fingers[1]
        }

        var fingers: [Finger] { [first, second] }
    }

    private struct Swipe: Sendable {
        /// The swipe fingers down now, at most two, with their positions on the last frame.
        var fingers: [TouchID: SurfacePoint]
        var lastTime: FrameTime
        /// Travel since the swipe began, in step millimetres.
        var travelMM: Double = 0
        var thumb: Anchor?
    }

    /// A finger's displacement in millimetres from its landing point.
    private struct Move: Sendable {
        let dxMM: Double
        let dyMM: Double

        /// More sideways than up or down.
        var isSideways: Bool { abs(dxMM) > abs(dyMM) }
    }

    /// The farthest-moved finger's displacement, when it is more than `dragThresholdMM`. Deterministic: the maximum.
    private static func drag(of fingers: [Finger], in down: [TouchID: Touch], on surface: SurfaceSize) -> Move? {
        let moves = fingers.compactMap { finger -> Move? in
            down[finger.id].map {
                Move(
                    dxMM: ($0.position.x - finger.origin.x) * surface.widthMM,
                    dyMM: ($0.position.y - finger.origin.y) * surface.heightMM)
            }
        }
        return moves
            .max { hypot($0.dxMM, $0.dyMM) < hypot($1.dxMM, $1.dyMM) }
            .flatMap { hypot($0.dxMM, $0.dyMM) > GestureRules.dragThresholdMM ? $0 : nil }
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

        /// Ordered by id, so everything derived from it is deterministic.
        var fingers: [Finger] {
            down.map { Finger(id: $0.key, origin: $0.value) }.sorted { $0.id.rawValue < $1.id.rawValue }
        }
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        /// Two fingers still down past the tap limit: no longer a tap, still able to become a swipe.
        case resting(Anchor, Pair)
        case spoiled(Anchor)
        case swiping(Swipe)

        /// The anchor the top-of-step check maintains. A swipe keeps its own optional thumb instead.
        var anchor: Anchor? {
            switch self {
            case .idle, .swiping: nil
            case .armed(let a), .tapping(let a, _), .resting(let a, _), .spoiled(let a): a
            }
        }
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private let swipes: Bool
    private var edgeContacts: EdgeContacts
    private var state: State = .idle
    /// Contacts down on the previous frame. nil until the first frame.
    private var previouslyDown: Set<TouchID>?
}
