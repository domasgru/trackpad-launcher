// Prints the vertical runs of same-coloured pixels down one column of a 2x screenshot, in points, so gaps between
// filled groups can be read exactly. Usage: swift runs.swift <png> <x in pt>
import AppKit

let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(filePath: CommandLine.arguments[1])))!
let scale = CGFloat(rep.pixelsWide) / rep.size.width
let x = Int(Double(CommandLine.arguments[2])! * scale)
func shade(_ y: Int) -> Int {
    let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return Int((c.redComponent * 255).rounded())
}
var start = 0
for y in 1...rep.pixelsHigh {
    if y == rep.pixelsHigh || shade(y) != shade(start) {
        print("from \(CGFloat(start) / scale) pt, \(CGFloat(y - start) / scale) pt tall, shade \(shade(start))")
        start = y
    }
}
