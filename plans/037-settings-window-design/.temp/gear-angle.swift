// Measures the gear's angle in the real window: captures the window with screencapture, matches each capture against
// assets/gear.svg rotated through 0..<360 degrees over the gear's visible part, and prints the angle (clockwise
// positive) with its time. A clockwise 30 s turn reads as +12 degrees per second.
// Build: swiftc -O gear-angle.swift -o ../../../build/gear-angle
// Run:   gear-angle <windowID> <gear.svg> <cardLeftPt> <cardTopPt> <samples> <intervalSeconds> [saveFirstPNG]
//        cardLeftPt and cardTopPt are the card's corner relative to the window's top-left corner.
import AppKit

struct Gray {
    let width: Int, height: Int
    var values: [Float]
    func at(_ x: Int, _ y: Int) -> Float {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return values[y * width + x]
    }
}

func luminance(_ image: CGImage) -> Gray {
    let (w, h) = (image.width, image.height)
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let context = CGContext(
        data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var values = [Float](repeating: 0, count: w * h)
    for i in 0..<(w * h) {
        values[i] = (Float(pixels[i * 4]) + Float(pixels[i * 4 + 1]) + Float(pixels[i * 4 + 2])) / 3
    }
    return Gray(width: w, height: h, values: values)
}

/// The gear's coverage, 0 to 1, at 2 px per point.
func template(_ path: String) -> Gray {
    let image = NSImage(contentsOfFile: path)!
    let side = 182
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    var values = [Float](repeating: 0, count: side * side)
    for y in 0..<side {
        for x in 0..<side { values[y * side + x] = Float(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) }
    }
    return Gray(width: side, height: side, values: values)
}

let arguments = CommandLine.arguments
let windowID = arguments[1]
let gear = template(arguments[2])
let cardLeft = Double(arguments[3])!, cardTop = Double(arguments[4])!
let samples = Int(arguments[5])!, interval = Double(arguments[6])!
let saveFirst = arguments.count > 7 ? arguments[7] : nil

let centre = (x: (cardLeft + 222 + 45.5) * 2, y: (cardTop - 23 + 45.5) * 2)
// Inside the card only: 2 pt in from its border, left of its right edge and below its top edge.
let minY = Int((cardTop + 2) * 2), maxX = Int((cardLeft + 294 - 2) * 2)
let minX = Int((cardLeft + 215) * 2), maxY = Int((cardTop + 70) * 2)

func capture(to path: String) -> CGImage {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-o", "-l\(windowID)", path]
    try! process.run()
    process.waitUntilExit()
    let image = NSImage(contentsOfFile: path)!
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

func angle(in frame: Gray) -> (degrees: Double, error: Float) {
    let (fill, ink): (Float, Float) = (247, 222)
    var best = (degrees: 0.0, error: Float.infinity)
    for tenth in stride(from: 0, to: 3600, by: 5) {
        let radians = Double(tenth) / 10 * .pi / 180
        let (c, s) = (cos(radians), sin(radians))
        var error: Float = 0
        for y in stride(from: minY, to: maxY, by: 2) {
            for x in stride(from: minX, to: maxX, by: 2) {
                let (dx, dy) = (Double(x) - centre.x, Double(y) - centre.y)
                // The template at this angle, sampled by turning the pixel back.
                let tx = Int(91 + dx * c + dy * s), ty = Int(91 - dx * s + dy * c)
                let seen = min(max((fill - frame.at(x, y)) / (fill - ink), 0), 1)
                error += abs(seen - gear.at(tx, ty))
            }
        }
        if error < best.error { best = (Double(tenth) / 10, error) }
    }
    return best
}

let path = NSTemporaryDirectory() + "gear-frame-\(ProcessInfo.processInfo.processIdentifier).png"
let start = Date()
var unwrapped: [(t: Double, degrees: Double)] = []
var last: Double?
var turns = 0.0
for index in 0..<samples {
    let target = start.addingTimeInterval(Double(index) * interval)
    let wait = target.timeIntervalSinceNow
    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
    let taken = Date().timeIntervalSince(start)
    let image = capture(to: path)
    if index == 0, let saveFirst { try? FileManager.default.copyItem(atPath: path, toPath: saveFirst) }
    let measured = angle(in: luminance(image))
    let folded = measured.degrees.truncatingRemainder(dividingBy: 120)
    if let last, folded < last - 60 { turns += 120 }
    if let last, folded > last + 60 { turns -= 120 }
    last = folded
    unwrapped.append((taken, folded + turns))
    print(String(format: "t=%6.2f angle=%6.1f unwrapped=%7.1f error=%.0f", taken, folded, folded + turns, measured.error))
}
try? FileManager.default.removeItem(atPath: path)

guard unwrapped.count > 2 else { exit(0) }
let n = Double(unwrapped.count)
let (meanT, meanA) = (unwrapped.map(\.t).reduce(0, +) / n, unwrapped.map(\.degrees).reduce(0, +) / n)
let slope = unwrapped.map { ($0.t - meanT) * ($0.degrees - meanA) }.reduce(0, +) / unwrapped.map { pow($0.t - meanT, 2) }.reduce(0, +)
let residuals = unwrapped.map { abs($0.degrees - (meanA + slope * ($0.t - meanT))) }
print(String(format: "slope %.3f deg/s (%.1f s per turn, %@), largest residual %.2f deg over %.1f s", slope, abs(360 / slope), slope > 0 ? "clockwise" : "anticlockwise", residuals.max()!, unwrapped.last!.t))
