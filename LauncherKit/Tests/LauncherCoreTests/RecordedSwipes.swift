import Foundation
import LauncherCore

/// Real swipes recorded on a MacBook Pro 14 trackpad, replayed through a fresh recognizer.
struct RecordedSwipe {
    let number: Int
    let began: Double
    let ended: Double
    let frames: [TouchFrame]

    /// What a replay saw: the times of the frames on which the slide began and ended, and the travel after every frame
    /// from the begin frame to the last frame before the end (a frame with no `.moved` keeps the travel before it).
    struct Replay {
        var beganAt: Double?
        var endedAt: Double?
        var travel: [Double] = []
        var times: [Double] = []

        /// A frame's step is the absolute change of travel on it.
        var steps: [Double] { zip(travel, [0.0] + travel).map { abs($0 - $1) } }

        /// Frames with a neighbour on both sides whose step is over 2 and over 2.2 times the mean of its neighbours'.
        var leaps: [Int] {
            let steps = steps
            return steps.indices.dropFirst().dropLast().filter { i in
                steps[i] > 2 && steps[i] > 2.2 * (steps[i - 1] + steps[i + 1]) / 2
            }
        }
    }

    func replay(travel: SwipeTravel) -> Replay {
        var recognizer = GestureRecognizer(
            corner: .topLeft, surface: .macBook14, slides: [.swipe, .windowSwipe], swaps: true, travel: travel)
        var replay = Replay()
        var current = 0.0
        for frame in frames {
            let phase = recognizer.step(frame).swipe
            if phase == .began { replay.beganAt = frame.time.seconds }
            if phase == .ended { replay.endedAt = frame.time.seconds }
            if case .moved(let mm)? = phase { current = mm }
            if replay.beganAt != nil, replay.endedAt == nil {
                replay.travel.append(current)
                replay.times.append(frame.time.seconds)
            }
        }
        return replay
    }

    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "RecordedSwipes")

    static func load() throws -> [RecordedSwipe] {
        let text = try String(contentsOf: folder.appending(path: "recorded-swipes.txt"), encoding: .utf8)
        var swipes: [RecordedSwipe] = []
        var header: (number: Int, began: Double, ended: Double)?
        var frames: [TouchFrame] = []
        func close() {
            if let header {
                swipes.append(RecordedSwipe(number: header.number, began: header.began, ended: header.ended, frames: frames))
            }
            frames = []
        }
        for line in text.split(separator: "\n") {
            if line.hasPrefix("## swipe ") {
                close()
                let numbers = line.dropFirst("## swipe ".count).split { !"0123456789.".contains($0) }.compactMap { Double($0) }
                header = (Int(numbers[0]), numbers[1], numbers[2])
            } else if !line.hasPrefix("#") {
                frames.append(parse(line))
            }
        }
        close()
        return swipes
    }

    /// Mirrors `TouchFrame(parsing:count:timestamp:press:)` of the platform module, which the core tests cannot reach:
    /// only states 3 and 4 are contacts, 3 is a landing and 4 is down, each coordinate is read as a 32-bit `Float` and
    /// widened to `Double`, and y is `1 - Double(y)`.
    private static func parse(_ line: Substring) -> TouchFrame {
        let fields = line.split(separator: " ")
        let touches = fields.dropFirst().compactMap { field -> Touch? in
            let parts = field.split(separator: ":")
            guard let id = Int32(parts[0]), let state = Int(parts[1]), state == 3 || state == 4,
                  let x = Float(parts[2]), let y = Float(parts[3]) else { return nil }
            return Touch(
                id: TouchID(rawValue: id), phase: state == 3 ? .landing : .down,
                position: SurfacePoint(x: Double(x), y: 1 - Double(y)))
        }
        return TouchFrame(time: FrameTime(seconds: Double(fields[0])!), touches: touches, press: nil)
    }
}
