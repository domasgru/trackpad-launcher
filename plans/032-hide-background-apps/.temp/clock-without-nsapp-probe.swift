// Probe (R10/R11 clock under `swift test`): with no NSApplication and only the main run loop pumped, as the platform
// tests run, does a deadline animation on a layer in a panel that is never ordered in complete, and on time? Touches
// nothing else.
import AppKit
import QuartzCore

let started = Date()
final class Stop: NSObject, CAAnimationDelegate {
    let label: String
    init(_ label: String) { self.label = label }
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        print(String(format: "[%.3f] '%@' stopped finished=%d", Date().timeIntervalSince(started), label, finished ? 1 : 0))
    }
}
var stops: [Stop] = []
func deadline(on layer: CALayer, _ seconds: Double, _ label: String) {
    let a = CABasicAnimation(keyPath: "opacity")
    a.fromValue = Float(1); a.toValue = Float(1); a.duration = seconds
    let stop = Stop(label); stops.append(stop); a.delegate = stop
    layer.add(a, forKey: label)
}
let content = NSView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
content.wantsLayer = true
let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.contentView = content
panel.isReleasedWhenClosed = false
let host = content.layer!
let clock = CALayer()
host.addSublayer(clock)
deadline(on: clock, 0.3, "never-shown panel, sublayer, 0.3 s")
let cancelled = CALayer()
host.addSublayer(cancelled)
deadline(on: cancelled, 0.3, "removed sublayer (should stop early, finished=0)")
RunLoop.main.run(until: Date().addingTimeInterval(0.1))
cancelled.removeFromSuperlayer()
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
// Close the host: do deadlines on it still pass?
deadline(on: clock, 0.3, "after panel.close(), 0.3 s")
panel.close()
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
print("done")
