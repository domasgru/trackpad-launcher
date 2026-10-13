import Foundation

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// What one frame produced, if anything. A frame never both fires a tap and moves a swipe.
    public enum Event: Equatable, Sendable {
        case fired(Gesture)
        case swipe(SwipePhase)
        /// A thumb tap under two resting fingers. `startsSeries`: the first swap under them.
        case swap(startsSeries: Bool)
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

    public var swap: Bool? { if case .swap(let startsSeries)? = event { startsSeries } else { nil } }

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
    /// `swaps`: false: a thumb landing under resting fingers is only ever held, never a thumb tap.
    /// `travel`: how finger movement becomes switcher travel. A var, so a Debug tuner can change it between frames.
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Bool, swaps: Bool, travel: SwipeTravel) {
        self.corner = AnchorCorner(handMode, surface: surface)
        self.edgeContacts = EdgeContacts(corner: corner, surface: surface)
        self.surface = surface
        self.swipes = swipes
        self.swaps = swaps
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

        let departed = book.contacts(of: lifted)
        for id in lifted { book[id] = nil }
        for touch in landed {
            // The pad sends no frames while nothing touches it, so a contact landing on the first frame really
            // landed now. Only an already-resting contact (`.down`) has an unknown landing time.
            book[touch.id] = Contact(
                origin: touch.position, firstSeen: frame.time, isRealLanding: !isFirstFrame || touch.phase == .landing)
        }

        if let anchor = state.anchor,
           lifted.contains(anchor.id) || !(down[anchor.id].map { corner.holds($0.position) } ?? false) {
            state = Self.restOrIdle(of: down.keys.filter { id in !landed.contains { $0.id == id } })
        }

        var event: Recognition.Event?
        switch state {
        case .idle:
            if let thumb = landed.first(where: { corner.admits($0.position) }) {
                let anchor = Anchor(id: thumb.id)
                state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)
            } else if !landed.isEmpty {
                state = .rest(Rest(fingers: Set(landed.map(\.id))))
            }
        case .armed(let anchor):
            let fingers = landed.filter { $0.id != anchor.id }
            if !fingers.isEmpty {
                state = frame.press == .click ? .spoiled(anchor) : .tapping(anchor, Tap(start: frame.time, landing: fingers))
            }
        case .tapping(let anchor, var tap):
            for id in lifted { tap.down.remove(id) }
            let joining = landed.filter { $0.id != anchor.id }
            let pair = swipes ? Pair(tap, joining: joining) : nil
            if frame.press == .click {
                state = .spoiled(anchor)
            } else if let move = Self.drag(of: tap.fingers, in: down, book: book, on: surface) {
                (state, event) = beginOrSpoil(pair, move, anchor, down, frame.time)
            } else if frame.time - tap.start > GestureRules.maxTapDuration {
                state = pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)
            } else if tap.down.isEmpty {
                event = Gesture(fingerCount: tap.touched.count).map(Recognition.Event.fired)
                state = joining.isEmpty ? .armed(anchor) : .tapping(anchor, Tap(start: frame.time, landing: joining))
            } else {
                for touch in joining {
                    tap.land(touch.id)
                }
                state = .tapping(anchor, tap)
            }
        case .resting(let anchor, let pair):
            if frame.press == .click
                || pair.fingers.contains(where: { lifted.contains($0) })
                || landed.contains(where: { $0.id != anchor.id }) {
                state = .spoiled(anchor)
            } else if let move = Self.drag(of: pair.fingers, in: down, book: book, on: surface) {
                (state, event) = beginOrSpoil(pair, move, anchor, down, frame.time)
            }
        case .spoiled(let anchor):
            if down.keys.allSatisfy({ $0 == anchor.id }) {
                state = .armed(anchor)
            }
        case .rest(let rest):
            (state, event) = step(rest, frame, down: down, landed: landed, lifted: lifted, departed: departed)
        case .swiping(var swipe):
            // The thumb plays no part in a swipe: it is only remembered for what happens after it.
            if let thumb = swipe.thumb,
               lifted.contains(thumb.id) || !(down[thumb.id].map { corner.holds($0.position) } ?? false) {
                swipe.thumb = nil
            }
            if swipe.thumb == nil, let thumb = landed.first(where: { corner.admits($0.position) }) {
                swipe.thumb = Anchor(id: thumb.id)
            }
            // Until every non-thumb finger has lifted, nothing further happens.
            let after = swipe.thumb.map(State.spoiled) ?? Self.restOrIdle(of: down.keys)
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
        } else if case .rest(let rest) = state, rest.isSeries {
            blocksClicks = true
            blocksDockSwipes = true
        } else {
            let thumb = state.thumb
            blocksDockSwipes = thumb.map { thumb in down.keys.contains { $0 != thumb } } ?? false
            blocksClicks = thumb.flatMap { thumb in
                book.landingTime(of: thumb).map { landedAt in
                    frame.time - landedAt < GestureRules.clickBlockingWindow
                        && down.keys.contains { $0 != thumb }
                }
            } ?? false
        }
        return Recognition(event: event, blocksClicks: blocksClicks, blocksDockSwipes: blocksDockSwipes)
    }

    /// One frame of the fingers-first state. A thumb tap qualifies when its thumb lands and fires when that thumb lifts.
    private mutating func step(
        _ rest: Rest, _ frame: TouchFrame, down: [TouchID: Touch], landed: [Touch], lifted: Set<TouchID>,
        departed: [TouchID: Contact]
    ) -> (State, Recognition.Event?) {
        var rest = rest
        var event: Recognition.Event?
        // Anything that happens to the other contacts spoils a thumb tap in progress.
        var changed = !lifted.isDisjoint(with: rest.fingers) || landed.contains { $0.id != rest.thumb?.id }
        rest.fingers.subtract(lifted)
        if !rest.isStopped, Self.drag(of: rest.fingers.sorted { $0.rawValue < $1.rawValue }, in: down, book: book, on: surface) != nil {
            rest.isStopped = true
            changed = true
        }

        if let thumb = rest.thumb {
            if lifted.contains(thumb.id) {
                if thumb.isTap, !changed, let landedAt = departed[thumb.id]?.firstSeen,
                   frame.time - landedAt <= GestureRules.maxTapDuration {
                    event = .swap(startsSeries: !rest.isSeries)
                    rest.isSeries = true
                    for id in rest.fingers { if let at = down[id]?.position { book[id]?.origin = at } }
                }
                rest.thumb = nil
            } else if let position = down[thumb.id]?.position, !corner.holds(position) {
                // A thumb that slid out is a finger until it lifts and lands again.
                rest.fingers.insert(thumb.id)
                rest.thumb = nil
            } else if thumb.isTap,
                      changed || Self.drag(of: [thumb.id], in: down, book: book, on: surface) != nil
                        || book[thumb.id].map({ frame.time - $0.firstSeen > GestureRules.maxTapDuration }) ?? true {
                rest.thumb?.isTap = false
            }
        }

        let thumbLanding = rest.thumb == nil ? landed.first { corner.admits($0.position) } : nil
        for touch in landed where touch.id != thumbLanding?.id { rest.fingers.insert(touch.id) }
        if rest.isSeries && rest.fingers.count > 2 { rest.isStopped = true }
        if let thumbLanding {
            let qualifies = swaps && !rest.isStopped && rest.fingers.count == 2
                && rest.fingers.allSatisfy { id in
                    book[id].map { frame.time - $0.firstSeen >= GestureRules.minRestBeforeThumbTap } ?? false
                }
            rest.thumb = RestThumb(id: thumbLanding.id, isTap: qualifies)
        }

        if rest.fingers.isEmpty {
            return (rest.thumb.map { .armed(Anchor(id: $0.id)) } ?? .idle, event)
        }
        return (.rest(rest), event)
    }

    /// The contacts down with no thumb anchored: a rest, or idle when nothing is down.
    private static func restOrIdle(of ids: some Collection<TouchID>) -> State {
        ids.isEmpty ? .idle : .rest(Rest(fingers: Set(ids)))
    }

    /// A sideways drag of a pair begins the swipe; any other drag spoils the gesture like every drag does.
    private func beginOrSpoil(
        _ pair: Pair?, _ move: Move, _ anchor: Anchor, _ down: [TouchID: Touch], _ time: FrameTime
    ) -> (State, Recognition.Event?) {
        guard let pair, move.isSideways else { return (.spoiled(anchor), nil) }
        let fingers = Dictionary(uniqueKeysWithValues: pair.fingers.compactMap { id in down[id].map { (id, $0.position) } })
        return (.swiping(Swipe(fingers: fingers, lastTime: time, thumb: anchor)), .swipe(.began))
    }

    private struct Anchor: Sendable {
        let id: TouchID
    }

    /// What the recognizer knows about one contact down, whoever is using it.
    private struct Contact: Sendable {
        /// Where it landed, until a swap moves it to where the contact was then.
        var origin: SurfacePoint
        let firstSeen: FrameTime
        /// False for a contact already resting on the first frame: when it really landed is unknown.
        let isRealLanding: Bool
    }

    /// Every contact down after the edge filter: the only source of landing points and times.
    private struct ContactBook: Sendable {
        private var contacts: [TouchID: Contact] = [:]

        subscript(id: TouchID) -> Contact? {
            get { contacts[id] }
            set { contacts[id] = newValue }
        }

        /// What was known about these contacts just before they left the book.
        func contacts(of ids: Set<TouchID>) -> [TouchID: Contact] {
            contacts.filter { ids.contains($0.key) }
        }

        /// When this recognizer saw the contact land. nil: unknown or not down.
        func landingTime(of id: TouchID) -> FrameTime? {
            contacts[id].flatMap { $0.isRealLanding ? $0.firstSeen : nil }
        }
    }

    /// Exactly two fingers: the only shape a swipe has.
    private struct Pair: Sendable {
        let first: TouchID
        let second: TouchID

        /// The tap as a pair: exactly two fingers touched since the last moment none was down, both still down, and
        /// none joins on this frame.
        init?(_ tap: Tap, joining: [Touch]) {
            let fingers = tap.fingers
            guard joining.isEmpty, tap.touched.count == 2, fingers.count == 2 else { return nil }
            first = fingers[0]
            second = fingers[1]
        }

        var fingers: [TouchID] { [first, second] }
    }

    /// Contacts that landed with no thumb anchored, and the thumb that may land under them.
    private struct Rest: Sendable {
        /// Every contact down but the thumb.
        var fingers: Set<TouchID>
        var thumb: RestThumb?
        /// Some finger moved more than `dragThresholdMM` from its reference, or a third finger joined a series.
        /// Permanent for this rest.
        var isStopped = false
        /// A swap has fired under this rest: it blocks until the rest empties.
        var isSeries = false
    }

    private struct RestThumb: Sendable {
        let id: TouchID
        /// Still able to swap when it lifts. Otherwise it is only held: an anchored thumb once the fingers lift.
        var isTap: Bool
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
    private static func drag(
        of fingers: [TouchID], in down: [TouchID: Touch], book: ContactBook, on surface: SurfaceSize
    ) -> Move? {
        let moves = fingers.compactMap { id -> Move? in
            guard let touch = down[id], let origin = book[id]?.origin else { return nil }
            return Move(
                dxMM: (touch.position.x - origin.x) * surface.widthMM,
                dyMM: (touch.position.y - origin.y) * surface.heightMM)
        }
        return moves
            .max { hypot($0.dxMM, $0.dyMM) < hypot($1.dxMM, $1.dyMM) }
            .flatMap { hypot($0.dxMM, $0.dyMM) > GestureRules.dragThresholdMM ? $0 : nil }
    }

    private struct Tap: Sendable {
        let start: FrameTime
        /// Fingers down now.
        var down: Set<TouchID>
        /// Every finger that touched during this tap. Always a superset of `down.keys`.
        private(set) var touched: Set<TouchID>

        init(start: FrameTime, landing: [Touch]) {
            self.start = start
            down = []
            touched = []
            for touch in landing { land(touch.id) }
        }

        /// The only way a finger joins: a re-landed id still counts once.
        mutating func land(_ id: TouchID) {
            down.insert(id)
            touched.insert(id)
        }

        /// Ordered by id, so everything derived from it is deterministic.
        var fingers: [TouchID] {
            down.sorted { $0.rawValue < $1.rawValue }
        }
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        /// Two fingers still down past the tap limit: no longer a tap, still able to become a swipe.
        case resting(Anchor, Pair)
        case spoiled(Anchor)
        /// Contacts landed with no thumb anchored; a thumb landing under them may swap.
        case rest(Rest)
        case swiping(Swipe)

        /// The anchor the top-of-step check maintains. A rest and a swipe keep their own optional thumb instead.
        var anchor: Anchor? {
            switch self {
            case .idle, .rest, .swiping: nil
            case .armed(let a), .tapping(let a, _), .resting(let a, _), .spoiled(let a): a
            }
        }

        /// The thumb the blocking rules follow: the anchor, or the thumb under a rest.
        var thumb: TouchID? {
            if case .rest(let rest) = self { rest.thumb?.id } else { anchor?.id }
        }
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private let swipes: Bool
    private let swaps: Bool
    private var edgeContacts: EdgeContacts
    private var state: State = .idle
    private var book = ContactBook()
    /// Contacts down on the previous frame. nil until the first frame.
    private var previouslyDown: Set<TouchID>?
}
