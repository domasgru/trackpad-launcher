// Replays a recorder file through the real GestureRecognizer (compiled into this module with LauncherCore's sources),
// parsing frames exactly like TouchFrameParsing does (states 3 and 4 only, y flipped). Prints every event.
import Foundation

let path = CommandLine.arguments[1]
let lines = try! String(contentsOfFile: path, encoding: .utf8).split(separator: "\n")
var recognizer = GestureRecognizer(
    handMode: .right, surface: SurfaceSize(widthMM: 124.8, heightMM: 76.8), swipes: true,
    travel: SwipeTravel.linear)
for line in lines where !line.hasPrefix("#") && !line.hasPrefix("*") {
    let parts = line.split(separator: " ")
    let time = Double(parts[0])!
    var touches: [Touch] = []
    for item in parts.dropFirst(2) {
        let f = item.split(separator: ":")
        let state = Int32(f[1])!
        guard state == 3 || state == 4 else { continue }
        touches.append(
            Touch(
                id: TouchID(rawValue: Int32(f[0])!), phase: state == 3 ? .landing : .down,
                position: SurfacePoint(x: Double(f[2])!, y: 1 - Double(f[3])!)))
    }
    let r = recognizer.step(TouchFrame(time: FrameTime(seconds: time), touches: touches, press: nil))
    if let event = r.event { print(String(format: "%.4f", time), event) }
}
