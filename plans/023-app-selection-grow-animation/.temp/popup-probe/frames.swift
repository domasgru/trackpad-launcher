// Tool: tiles frames of a screen recording, cropped to the screen's centre, into contact sheets, to step through a
// short UI moment. Usage: frames <movie> <from s> <to s> <fps> <crop width pt> <crop height pt> <out prefix>
// [<right of centre pt> <above centre pt>]
// Build: swiftc -swift-version 5 frames.swift -o /tmp/frames
import AVFoundation
import AppKit

let args = CommandLine.arguments
let movie = URL(fileURLWithPath: args[1])
let from = Double(args[2])!, to = Double(args[3])!, fps = Double(args[4])!
let cropW = CGFloat(Double(args[5])!), cropH = CGFloat(Double(args[6])!)
let out = args[7]
let dx = args.count > 8 ? CGFloat(Double(args[8])!) : 0, dy = args.count > 9 ? CGFloat(Double(args[9])!) : 0

let asset = AVURLAsset(url: movie)
let generator = AVAssetImageGenerator(asset: asset)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let semaphore = DispatchSemaphore(value: 0)
var frames: [(Double, CGImage)] = []
Task {
    let duration = try await asset.load(.duration).seconds
    print("duration \(duration)")
    var t = from
    while t <= min(to, duration) {
        if let image = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image {
            // Pixels per point from the movie against the main screen's size in points.
            let scale = CGFloat(image.width) / (NSScreen.main?.frame.width ?? CGFloat(image.width))
            let w = cropW * scale, h = cropH * scale
            let rect = CGRect(
                x: (CGFloat(image.width) - w) / 2 + dx * scale, y: (CGFloat(image.height) - h) / 2 - dy * scale, width: w,
                height: h)
            if let cropped = image.cropping(to: rect) { frames.append((t, cropped)) }
        }
        t += 1 / fps
    }
    semaphore.signal()
}
semaphore.wait()

let columns = 4, perSheet = 16
for (sheetIndex, start) in stride(from: 0, to: frames.count, by: perSheet).enumerated() {
    let chunk = Array(frames[start..<min(start + perSheet, frames.count)])
    let fw = CGFloat(chunk[0].1.width), fh = CGFloat(chunk[0].1.height)
    let rows = (chunk.count + columns - 1) / columns
    let sheet = NSImage(size: NSSize(width: fw * CGFloat(columns), height: (fh + 30) * CGFloat(rows)))
    sheet.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: sheet.size).fill()
    for (i, (t, image)) in chunk.enumerated() {
        let x = CGFloat(i % columns) * fw
        let y = sheet.size.height - CGFloat(i / columns + 1) * (fh + 30)
        NSImage(cgImage: image, size: NSSize(width: fw, height: fh)).draw(in: NSRect(x: x, y: y, width: fw, height: fh))
        (String(format: "%.2f s", t) as NSString).draw(
            at: NSPoint(x: x + 8, y: y + fh + 4),
            withAttributes: [.font: NSFont.boldSystemFont(ofSize: 22), .foregroundColor: NSColor.red])
        NSColor.gray.setStroke()
        NSRect(x: x, y: y, width: fw, height: fh).frame()
    }
    sheet.unlockFocus()
    let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
    let path = "\(out)-\(sheetIndex).png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print(path, chunk.count, "frames")
}
