// Probe: does NSRunningApplication.hide() on other apps behave like ⌘⌥H, without permissions, and what does it do to
// the ⌘-Tab order the switcher and swap read? Touches only three scratch apps; the caller's front app is restored.
import AppKit

typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias CopyInfo = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?
let copyOrder = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationArrayInFrontToBackOrder"), to: CopyOrder.self)
let copyInfo = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationInformation"), to: CopyInfo.self)

let ids = ["com.apple.calculator", "com.apple.Dictionary", "com.apple.Chess"]
let paths = ["/System/Applications/Calculator.app", "/System/Applications/Dictionary.app", "/System/Applications/Chess.app"]
let short = ["com.apple.calculator": "Calc", "com.apple.Dictionary": "Dict", "com.apple.Chess": "Chess"]

func pump(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
func app(_ i: Int) -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: ids[i]).first }

func order() -> [String] {
    guard let serials = copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
    return serials.compactMap { serial in
        let info = copyInfo(-2, serial, ["CFBundleIdentifier"] as CFArray)?.takeRetainedValue() as? [String: Any]
        return (info?["CFBundleIdentifier"] as? String).flatMap { short[$0] }
    }
}
func report(_ label: String) {
    let hidden = ids.indices.map { "\(short[ids[$0]]!)=\(app($0)?.isHidden == true ? "hidden" : "shown")" }.joined(separator: " ")
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.flatMap { short[$0] ?? "OTHER" } ?? "nil"
    print("\(label): front=\(front) order=\(order()) \(hidden)")
}
func open(_ i: Int) {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: paths[i]), configuration: c)
}

let original = NSWorkspace.shared.frontmostApplication
for i in ids.indices where app(i) != nil { print("ABORT: \(ids[i]) already running"); exit(1) }
for i in ids.indices { open(i); pump(2) }
report("start (Calc, Dict, Chess opened in turn)")

// A: same turn as the open, hiding even the app still in front.
open(0)
let answerA = [app(1)?.hide(), app(2)?.hide()]
print("A hide() answers (same turn as open):", answerA)
report("A +0")
pump(1); report("A +1s")

// B: the hidden most recent app comes back, the other one still hidden.
open(2); pump(1); report("B open hidden Chess, +1s, no hide")

// C: hide after activation, as a didActivate observer would.
_ = app(0)?.hide()
pump(1); report("C hide Calc from behind, +1s")

// D: swap-shaped sequence: alternate two apps hiding the other each time; is the previous app still second?
for (target, other) in [(0, 2), (2, 0), (0, 2)] {
    open(target); pump(0.6); _ = app(other)?.hide(); pump(0.6); report("D to \(short[ids[target]]!), hide \(short[ids[other]]!)")
}

// E: only one app remains visible and it is hidden while frontmost: who comes forward?
open(1); pump(0.6); report("E front Dict")
_ = app(1)?.hide(); pump(1); report("E hid the frontmost itself")

for i in ids.indices { app(i)?.terminate() }
pump(1.5)
original?.activate()
pump(0.3)
print("restored front:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")
