// Check C5 (after fan-out): the unknowns a keyframe-track design rests on (candidate 1's P7 a, b, c).
//  (b) Is AppKit's mirror of a glass view frame set synchronous, i.e. already on the element before our transaction
//      commits, so a view frame set and a re-based additive track land in one commit?
//  (c) Per-event cost: 200 events at 100 Hz, each replacing 3 additive CAKeyframeAnimations of 240 samples on the
//      swell's element layer (centre x, width, height), and every 5th event 10 bead height tracks of 150 samples,
//      with the samples computed from a damped sine each time. 12 glass views (band, 10 beads, swell).
//  (a) Rest cost of finished, filled-forward additive animations: WindowServer CPU over 5 s with 13 held animations
//      attached, against 5 s after removing them, twice; plus our own main wake-ups while held.
//
// Build: swiftc -swift-version 5 -parse-as-library -O c5-keyframe-tracks.swift -o /tmp/tl-check-024/c5
// Run:   /tmp/tl-check-024/c5

import AppKit
import QuartzCore

func cpuMS() -> Double {
    var u = rusage(); getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000 + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1000
}
func run(_ path: String, _ args: [String]) -> String {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe
    try? p.run(); p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}
/// WindowServer's accumulated CPU seconds, from ps's TIME column (m:ss.cc).
func windowServerCPU() -> Double {
    let pid = run("/usr/bin/pgrep", ["-x", "WindowServer"]).split(separator: "\n").first.map(String.init) ?? ""
    let t = run("/bin/ps", ["-o", "time=", "-p", pid])
    let parts = t.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
    return parts.count == 2 ? parts[0] * 60 + parts[1] : (parts.count == 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : -1)
}
final class WakeCounter {
    var count = 0
    var observer: CFRunLoopObserver?
    func start() {
        count = 0
        observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, _ in self?.count += 1 }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    func stop() -> Int { if let o = observer { CFRunLoopRemoveObserver(CFRunLoopGetMain(), o, .commonModes) }; return count }
}
func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }

func track(_ keyPath: String, samples: Int, amplitude: Double, phase: Double) -> CAKeyframeAnimation {
    let a = CAKeyframeAnimation(keyPath: keyPath)
    a.isAdditive = true
    a.calculationMode = .linear
    let step = 1.0 / 240
    a.values = (0..<samples).map { i -> NSNumber in
        let t = Double(i) * step
        return NSNumber(value: amplitude * exp(-4 * t) * sin(2 * .pi * 4.5 * t + phase) * (1 - Double(i) / Double(samples - 1)))
    }
    a.duration = Double(samples - 1) * step
    return a
}

@main
struct Check {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 1100, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.level = .floating; panel.hasShadow = true
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        let band = NSGlassEffectView(frame: NSRect(x: 90, y: 64, width: 900, height: 52)); band.cornerRadius = 26
        content.addSubview(band)
        var beads: [NSGlassEffectView] = []
        for i in 0..<10 {
            let b = NSGlassEffectView(frame: NSRect(x: 50 + CGFloat(i) * 100, y: 50, width: 80, height: 80)); b.cornerRadius = 25.6
            content.addSubview(b); beads.append(b)
        }
        let swell = NSGlassEffectView(frame: NSRect(x: 38, y: 38, width: 104, height: 104)); swell.cornerRadius = 33
        content.addSubview(swell)
        panel.contentView = container
        panel.orderFrontRegardless()
        CATransaction.flush()

        let els = allLayers(container.layer!).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" }
        func element(_ v: NSView) -> CALayer? {
            els.first { abs($0.frame.minX - v.frame.minX) < 0.5 && abs($0.frame.minY - v.frame.minY) < 0.5 && abs($0.frame.width - v.frame.width) < 0.5 }
        }
        let swellEl = element(swell)!
        let beadEls = beads.map { element($0)! }
        print("elements=\(els.count), matched swell and \(beadEls.count) beads")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // (b) synchronous mirror?
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let before = swellEl.frame.minX
            swell.frame.origin.x += 100
            let inside = swellEl.frame.minX
            CATransaction.commit()
            let afterCommit = swellEl.frame.minX
            DispatchQueue.main.async {
                print("(b) swell element minX: before \(before), right after the view frame set inside the transaction \(inside), right after commit \(afterCommit), next turn \(swellEl.frame.minX)")
                // (c) per-event keyframe tracks
                let counter = WakeCounter(); counter.start()
                let cpu0 = cpuMS()
                var n = 0
                let source = DispatchSource.makeTimerSource(queue: .main)
                source.schedule(deadline: .now(), repeating: .milliseconds(10))
                source.setEventHandler {
                    n += 1
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    let ph = Double(n) * 0.1
                    swellEl.add(track("position.x", samples: 240, amplitude: 20, phase: ph), forKey: "liquid.swell.centreX")
                    swellEl.add(track("bounds.size.width", samples: 240, amplitude: 30, phase: ph), forKey: "liquid.swell.width")
                    swellEl.add(track("bounds.size.height", samples: 240, amplitude: 6, phase: ph), forKey: "liquid.swell.height")
                    if n % 5 == 0 {
                        for (i, e) in beadEls.enumerated() {
                            e.add(track("bounds.size.height", samples: 150, amplitude: 5, phase: ph + Double(i)), forKey: "liquid.bead.height")
                        }
                    }
                    CATransaction.commit()
                    if n == 200 {
                        source.cancel()
                        let wakes = counter.stop()
                        print("(c) 200 events over 2 s, 3 tracks x 240 samples per event + 10 bead tracks x 150 every 5th: process CPU \(String(format: "%.1f", cpuMS() - cpu0)) ms, main wake-ups \(wakes) (the event source alone is 200)")
                        // (a) hold: 13 finished, filled-forward additive animations
                        CATransaction.begin(); CATransaction.setDisableActions(true)
                        for (key, e, kp) in [("hold.x", swellEl, "position.x"), ("hold.w", swellEl, "bounds.size.width"), ("hold.h", swellEl, "bounds.size.height")] + beadEls.map({ ("hold.h", $0, "bounds.size.height") }) {
                            e.removeAllAnimations()
                            let a = CAKeyframeAnimation(keyPath: kp)
                            a.isAdditive = true; a.values = [0, 8].map(NSNumber.init(value:)); a.duration = 0.05
                            a.fillMode = .forwards; a.isRemovedOnCompletion = false
                            e.add(a, forKey: key)
                        }
                        CATransaction.commit()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            func phase(_ label: String, _ next: @escaping () -> Void) {
                                let w = WakeCounter(); w.start()
                                let ws0 = windowServerCPU()
                                DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                                    let ws1 = windowServerCPU()
                                    DispatchQueue.main.async {
                                        print("(a) \(label): WindowServer CPU over 5 s = \(String(format: "%.2f", ws1 - ws0)) s; our main wake-ups = \(w.stop())")
                                        next()
                                    }
                                }
                            }
                            phase("13 held finished animations") {
                                CATransaction.begin(); CATransaction.setDisableActions(true)
                                ([swellEl] + beadEls).forEach { $0.removeAllAnimations() }
                                CATransaction.commit()
                                phase("no animations") {
                                    CATransaction.begin(); CATransaction.setDisableActions(true)
                                    for e in [swellEl] + beadEls {
                                        let a = CAKeyframeAnimation(keyPath: "bounds.size.height")
                                        a.isAdditive = true; a.values = [0, 8].map(NSNumber.init(value:)); a.duration = 0.05
                                        a.fillMode = .forwards; a.isRemovedOnCompletion = false
                                        e.add(a, forKey: "hold.h")
                                    }
                                    CATransaction.commit()
                                    phase("11 held finished animations, again") {
                                        CATransaction.begin(); CATransaction.setDisableActions(true)
                                        ([swellEl] + beadEls).forEach { $0.removeAllAnimations() }
                                        CATransaction.commit()
                                        phase("no animations, again") {
                                            // A running animation for contrast: one 5 s keyframe on the swell.
                                            swellEl.add(track("position.x", samples: 1200, amplitude: 20, phase: 0), forKey: "running")
                                            phase("one running 5 s animation (contrast)") { app.terminate(nil) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                source.resume()
            }
        }
        app.run()
    }
}
