// Probe: how long does it take to draw an app icon at the switcher's size (80 pt at 2x = 160 px) in a plain
// process, for (a) the frontmost app via NSWorkspace.icon(forFile:) on its bundle URL, first and second draw;
// (b) the same via NSRunningApplication.icon; (c) ten installed apps never drawn by this process at this size
// (cold in-process, warm or cold in the system icon cache), first draw each; (d) one other running app via
// NSRunningApplication.icon. The switcher must appear with no perceptible delay, and the frontmost app is unknown
// until the swipe begins, so this decides whether its icon can be drawn at swipe begin or must be prepared ahead.
// Reads as "slow" if a first draw exceeds about 16 ms (one display refresh).
import AppKit
import Foundation

let pixels = 160
func bitmap(_ image: NSImage) -> CGImage? {
    guard let space = CGColorSpace(name: CGColorSpace.displayP3),
          let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
}
func ms(_ body: () -> Void) -> Double {
    let clock = ContinuousClock()
    let d = clock.measure(body)
    return Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000
}

let workspace = NSWorkspace.shared
guard let front = workspace.frontmostApplication, let url = front.bundleURL else {
    print("no frontmost app with a bundle URL"); exit(0)
}
print("frontmost: \(front.bundleIdentifier ?? "nil") at \(url.path)")
var img: CGImage?
let t1 = ms { img = bitmap(workspace.icon(forFile: url.path)) }
let t2 = ms { img = bitmap(workspace.icon(forFile: url.path)) }
print(String(format: "(a) NSWorkspace.icon(forFile:) frontmost: first draw %.1f ms, second %.1f ms, %@", t1, t2, img == nil ? "nil" : "\(img!.width)px"))
if let icon = front.icon {
    let t3 = ms { img = bitmap(icon) }
    let t4 = ms { img = bitmap(icon) }
    print(String(format: "(b) NSRunningApplication.icon frontmost: first draw %.1f ms, second %.1f ms, reps=%d", t3, t4, icon.representations.count))
} else { print("(b) NSRunningApplication.icon is nil") }

// (c) ten installed apps, first draw each (this process has never drawn them).
let apps = (try? FileManager.default.contentsOfDirectory(at: URL(filePath: "/Applications"), includingPropertiesForKeys: nil))?
    .filter { $0.pathExtension == "app" }.sorted { $0.path < $1.path } ?? []
var sample: [URL] = []
var seen = Set<String>()
for (i, app) in apps.enumerated() where i % max(1, apps.count / 10) == 0 && sample.count < 10 && seen.insert(app.lastPathComponent).inserted { sample.append(app) }
var times: [Double] = []
for app in sample {
    let t = ms { img = bitmap(workspace.icon(forFile: app.path)) }
    times.append(t)
    print(String(format: "(c) %@: first draw %.1f ms", app.lastPathComponent, t))
}
if let mx = times.max(), !times.isEmpty {
    print(String(format: "(c) %d apps: max %.1f ms, median %.1f ms", times.count, mx, times.sorted()[times.count / 2]))
}
// (d) one running app other than the frontmost, via NSRunningApplication.icon (the image the Dock shows).
if let other = workspace.runningApplications.first(where: { $0.activationPolicy == .regular && $0 != front && $0.icon != nil }) {
    let t = ms { img = bitmap(other.icon!) }
    print(String(format: "(d) running %@ via NSRunningApplication.icon: first draw %.1f ms", other.bundleIdentifier ?? "?", t))
}
print("done")
