import Foundation
import LauncherCore

/// Frames in millimetres on a surface, 10 ms apart; `.landing` on each contact's first frame.
/// The builder sequences thumb, taps and lifts left to right on one timeline.
struct TouchScript {
    /// `.onLanding`: the press starts on the landing frame, before the tap could know a finger is down (the accepted
    /// race). `.firm`: from the frame after the first landing to the last lift, as a real firm tap. `.midway`: halfway
    /// through the hold.
    enum ClickTiming { case none, onLanding, firm, midway }

    private struct Waypoint {
        var ms: Int
        var x: Double
        var y: Double
    }

    private struct Contact {
        var id: Int32
        var landMS: Int
        var liftMS: Int?
        var path: [Waypoint]

        func position(atMS ms: Int) -> (x: Double, y: Double) {
            guard let first = path.first, let last = path.last else { return (0, 0) }
            if ms <= first.ms { return (first.x, first.y) }
            if ms >= last.ms { return (last.x, last.y) }
            for (a, b) in zip(path, path.dropFirst()) where ms >= a.ms && ms <= b.ms {
                let f = Double(ms - a.ms) / Double(b.ms - a.ms)
                return (a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)
            }
            return (last.x, last.y)
        }

        func isDown(atMS ms: Int) -> Bool {
            ms >= landMS && ms < (liftMS ?? .max)
        }

        mutating func moveFromHere(atMS ms: Int, byMM d: (x: Double, y: Double), overMS: Int) {
            guard let here = path.last else { return }
            if here.ms < ms { path.append(Waypoint(ms: ms, x: here.x, y: here.y)) }
            path.append(Waypoint(ms: ms + overMS, x: here.x + d.x, y: here.y + d.y))
        }
    }

    private static let frameIntervalMS = 10
    private static let thumbID: Int32 = 100

    private let surface: SurfaceSize
    private var contacts: [Contact] = []
    private var presses: [ClosedRange<Int>] = []
    private var pressStartMS: Int?
    private var cursorMS = 0
    private var nextFingerID: Int32 = 1

    init(_ surface: SurfaceSize) {
        self.surface = surface
    }

    func thumb(atMM p: (x: Double, y: Double)) -> TouchScript {
        var s = self
        s.contacts.append(Contact(
            id: Self.thumbID, landMS: cursorMS, liftMS: nil,
            path: [Waypoint(ms: cursorMS, x: p.x, y: p.y)]))
        s.cursorMS += 50
        return s
    }

    func tap(
        fingers n: Int,
        atMM p: (x: Double, y: Double) = (62, 45),
        stagger: Duration = .zero,
        hold: Duration = .milliseconds(120),
        dragMM: Double = 0,
        click: ClickTiming = .none
    ) -> TouchScript {
        var s = self
        let start = cursorMS
        let staggerMS = Self.milliseconds(stagger)
        let holdMS = Self.milliseconds(hold)
        var lastLift = start
        for i in 0..<n {
            let land = start + i * staggerMS
            let lift = land + holdMS
            let x = p.x + 8 * Double(i)
            var path = [Waypoint(ms: land, x: x, y: p.y)]
            if dragMM != 0 {
                path.append(Waypoint(ms: lift - Self.frameIntervalMS, x: x + dragMM, y: p.y))
            }
            s.contacts.append(Contact(id: s.nextFingerID, landMS: land, liftMS: lift, path: path))
            s.nextFingerID += 1
            lastLift = max(lastLift, lift)
        }
        switch click {
        case .none: break
        case .onLanding: s.presses.append(start...lastLift)
        case .firm: s.presses.append((start + Self.frameIntervalMS)...lastLift)
        case .midway: s.presses.append((start + holdMS / 2)...lastLift)
        }
        s.cursorMS = lastLift + 100
        return s
    }

    enum Lift { case all, first }

    /// Lands `n` fingers 8 mm apart from `p`; they stay down until `lift`.
    func land(fingers n: Int = 2, atMM p: (x: Double, y: Double) = (62, 45)) -> TouchScript {
        var s = self
        for i in 0..<n {
            s.contacts.append(Contact(
                id: s.nextFingerID, landMS: cursorMS, liftMS: nil,
                path: [Waypoint(ms: cursorMS, x: p.x + 8 * Double(i), y: p.y)]))
            s.nextFingerID += 1
        }
        return s
    }

    /// Moves every non-thumb finger that is down by `d` over `over`.
    func slide(byMM d: (x: Double, y: Double), over: Duration = .milliseconds(100)) -> TouchScript {
        var s = self
        let overMS = Self.milliseconds(over)
        for i in s.contacts.indices where s.contacts[i].id != Self.thumbID && s.contacts[i].isDown(atMS: cursorMS) {
            s.contacts[i].moveFromHere(atMS: cursorMS, byMM: d, overMS: overMS)
        }
        s.cursorMS += overMS
        return s
    }

    /// Lifts the fingers that are down, one frame after the last slide's final frame: all of them, or only the first
    /// landed. Ends a press in progress.
    func lift(_ which: Lift = .all) -> TouchScript {
        var s = self
        let liftMS = cursorMS + Self.frameIntervalMS
        let down = s.contacts.indices.filter { s.contacts[$0].id != Self.thumbID && s.contacts[$0].isDown(atMS: cursorMS) }
        for i in (which == .all ? down : Array(down.prefix(1))) { s.contacts[i].liftMS = liftMS }
        if let start = s.pressStartMS {
            s.presses.append(start...liftMS)
            s.pressStartMS = nil
        }
        s.cursorMS += 50
        return s
    }

    /// A press held from now until the next lift.
    func press() -> TouchScript {
        var s = self
        s.pressStartMS = s.pressStartMS ?? cursorMS
        return s
    }

    /// Moves the anchored thumb to `p` over the next 50 ms.
    func rollThumb(toMM p: (x: Double, y: Double)) -> TouchScript {
        var s = self
        guard let i = s.contacts.lastIndex(where: { $0.id == Self.thumbID }),
              let here = s.contacts[i].path.last else { return s }
        s.contacts[i].moveFromHere(atMS: cursorMS, byMM: (p.x - here.x, p.y - here.y), overMS: 50)
        s.cursorMS += 50
        return s
    }

    func liftThumb() -> TouchScript {
        var s = self
        if let i = s.contacts.lastIndex(where: { $0.id == Self.thumbID }) {
            s.contacts[i].liftMS = cursorMS
        }
        s.cursorMS += 50
        return s
    }

    func wait(_ d: Duration) -> TouchScript {
        var s = self
        s.cursorMS += Self.milliseconds(d)
        return s
    }

    /// The first frame is the first contact's landing: a pad delivers no frames while nothing touches it.
    var frames: [TouchFrame] {
        stride(from: 0, through: cursorMS, by: Self.frameIntervalMS).map { ms in
            let touches = contacts.filter { $0.isDown(atMS: ms) }.map { contact in
                let p = contact.position(atMS: ms)
                return Touch(
                    id: TouchID(rawValue: contact.id),
                    phase: ms == contact.landMS ? .landing : .down,
                    position: surface.point(mm: p.x, p.y))
            }
            return TouchFrame(
                time: FrameTime(seconds: 1.0 + Double(ms) / 1000),
                touches: touches,
                press: presses.contains { $0.contains(ms) } || (pressStartMS.map { ms >= $0 } ?? false) ? .click : nil)
        }
    }

    private static func milliseconds(_ d: Duration) -> Int {
        let c = d.components
        return Int(c.seconds) * 1000 + Int(c.attoseconds / 1_000_000_000_000_000)
    }
}
