// Probe P3: is a Core Animation completion a usable deadline, and where does it need to live?
// Adds a 2 s CABasicAnimation (on opacity, 1 -> 1, so nothing visible changes) to a layer in
// (a) a visible click-through panel, (b) a panel ordered front with alphaValue 0, (c) a layer in no window,
// (d) an infinitely repeating keyframe bounce with a 2 s repeatDuration in a visible panel,
// and reports how late each completion arrives, plus whether removing an animation early fires
// the completion (finished = false) at once.
import AppKit
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class Done: NSObject, CAAnimationDelegate {
    let label: String; let start: CFTimeInterval; let expected: Double
    init(_ label: String, expected: Double) { self.label = label; start = CACurrentMediaTime(); self.expected = expected }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        let elapsed = CACurrentMediaTime() - start
        print(String(format: "%@: stopped after %.1f ms (expected %.0f ms, late by %.1f ms) finished=%@", label, elapsed * 1000, expected * 1000, (elapsed - expected) * 1000, flag ? "true" : "false"))
    }
}

func panel(alpha: CGFloat) -> NSPanel {
    let p = NSPanel(contentRect: NSRect(x: 40, y: 40, width: 4, height: 4), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.isOpaque = false; p.backgroundColor = .clear; p.ignoresMouseEvents = true; p.level = .screenSaver
    p.alphaValue = alpha
    let v = NSView(frame: NSRect(x: 0, y: 0, width: 4, height: 4)); v.wantsLayer = true; p.contentView = v
    p.orderFrontRegardless()
    return p
}
func hold(_ label: String, on layer: CALayer, seconds: Double) {
    let a = CABasicAnimation(keyPath: "opacity")
    a.fromValue = 1; a.toValue = 1; a.duration = seconds
    a.delegate = Done(label, expected: seconds)
    layer.add(a, forKey: label)
}

let visible = panel(alpha: 1)
let invisible = panel(alpha: 0)
let loose = CALayer()
let bouncePanel = panel(alpha: 1)

DispatchQueue.main.async {
    hold("(a) visible panel", on: visible.contentView!.layer!, seconds: 2)
    hold("(b) alpha-0 panel", on: invisible.contentView!.layer!, seconds: 2)
    hold("(c) layer in no window", on: loose, seconds: 2)

    let bounce = CAKeyframeAnimation(keyPath: "position.y")
    bounce.values = [0, 1, 0]; bounce.keyTimes = [0, 0.5, 1]; bounce.duration = 0.7
    bounce.repeatDuration = 2
    bounce.delegate = Done("(d) repeating bounce, repeatDuration 2 s", expected: 2)
    bouncePanel.contentView!.layer!.add(bounce, forKey: "bounce")

    let early = CABasicAnimation(keyPath: "opacity")
    early.fromValue = 1; early.toValue = 1; early.duration = 10
    early.delegate = Done("(e) 10 s animation removed at 0.5 s", expected: 0.5)
    visible.contentView!.layer!.add(early, forKey: "early")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { visible.contentView!.layer!.removeAnimation(forKey: "early") }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        visible.close(); invisible.close(); bouncePanel.close()
        exit(0)
    }
}
app.run()
