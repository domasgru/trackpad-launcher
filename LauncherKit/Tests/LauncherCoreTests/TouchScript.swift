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
    }

    private static let frameIntervalMS = 10
    private static let thumbID: Int32 = 100

    private let surface: SurfaceSize
    private var contacts: [Contact] = []
    private var presses: [ClosedRange<Int>] = []
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

    /// Moves the anchored thumb to `p` over the next 50 ms.
    func rollThumb(toMM p: (x: Double, y: Double)) -> TouchScript {
        var s = self
        guard let i = s.contacts.firstIndex(where: { $0.id == Self.thumbID }),
              let here = s.contacts[i].path.last else { return s }
        s.contacts[i].path.append(Waypoint(ms: cursorMS, x: here.x, y: here.y))
        s.contacts[i].path.append(Waypoint(ms: cursorMS + 50, x: p.x, y: p.y))
        s.cursorMS += 50
        return s
    }

    func liftThumb() -> TouchScript {
        var s = self
        if let i = s.contacts.firstIndex(where: { $0.id == Self.thumbID }) {
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
                press: presses.contains { $0.contains(ms) } ? .click : nil)
        }
    }

    private static func milliseconds(_ d: Duration) -> Int {
        let c = d.components
        return Int(c.seconds) * 1000 + Int(c.attoseconds / 1_000_000_000_000_000)
    }
}
