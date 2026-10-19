// Check P6 (after fan-out): what a display-sized click-through panel holding one bouncing 60 pt layer costs in this
// process's memory, against a small panel holding the same layer. Candidate 1 puts the bounce row in a panel the size
// of the pointer's display; candidate 2 rejects that for "about 24 MB at 2x" and moves a small panel per event.
// Prints the process's phys_footprint (what Activity Monitor's Memory column shows) at each step.
import AppKit
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
}
func panel(_ frame: NSRect) -> (NSPanel, CALayer) {
    let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.isOpaque = false; p.backgroundColor = .clear; p.ignoresMouseEvents = true; p.level = .screenSaver; p.hasShadow = false
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let v = NSView(frame: NSRect(origin: .zero, size: frame.size)); v.wantsLayer = true; p.contentView = v
    let icon = CALayer(); icon.bounds = CGRect(x: 0, y: 0, width: 60, height: 60)
    icon.contents = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app").cgImage(forProposedRect: nil, context: nil, hints: nil)
    icon.contentsScale = p.backingScaleFactor
    icon.position = CGPoint(x: min(frame.width, 600) / 2, y: 40)
    let bounce = CABasicAnimation(keyPath: "position.y"); bounce.fromValue = 40; bounce.toValue = 70; bounce.duration = 0.35
    bounce.autoreverses = true; bounce.repeatCount = .infinity
    icon.add(bounce, forKey: "bounce")
    v.layer!.addSublayer(icon)
    p.orderFrontRegardless()
    return (p, icon)
}

let screen = NSScreen.screens[0].frame
print(String(format: "display %.0fx%.0f @%.0fx", screen.width, screen.height, NSScreen.screens[0].backingScaleFactor))
DispatchQueue.main.async {
    print(String(format: "start: %.1f MB", footprintMB()))
    let (small, _) = panel(NSRect(x: 200, y: 200, width: 84, height: 120))
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        print(String(format: "small 84x120 panel bouncing: %.1f MB", footprintMB()))
        small.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print(String(format: "small closed: %.1f MB", footprintMB()))
            let (big, icon) = panel(screen)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print(String(format: "display-sized panel bouncing: %.1f MB", footprintMB()))
                for i in 0..<300 {   // follow-like moves
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    icon.position.x = 100 + CGFloat(i)
                    CATransaction.commit()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print(String(format: "display-sized panel after 300 moves: %.1f MB", footprintMB()))
                    big.close()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print(String(format: "display-sized closed: %.1f MB", footprintMB()))
                        exit(0)
                    }
                }
            }
        }
    }
}
app.run()
