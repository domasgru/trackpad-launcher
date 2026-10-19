// Check (after fan-out): do two active session taps on one run-loop thread receive events in posting order across
// the two ports? Tap A masks mouseMoved (5), tap B masks scrollWheel (22). Alternating moved/scroll events are posted
// (moved to the pointer's current location, so the cursor does not move; scrolls with zero deltas). The callbacks
// append their tag to one sequence; strict alternation means the order held. Also times CGEvent.tapIsEnabled.
import ApplicationServices
import Foundation
import Darwin

setvbuf(stdout, nil, _IONBF, 0)

nonisolated(unsafe) var sequence: [Character] = []

let callbackA: CGEventTapCallBack = { _, _, event, _ in sequence.append("M"); return Unmanaged.passUnretained(event) }
let callbackB: CGEventTapCallBack = { _, _, event, _ in sequence.append("S"); return Unmanaged.passUnretained(event) }

guard let portA = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: 1 << 5, callback: callbackA, userInfo: nil),
      let portB = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: 1 << 22, callback: callbackB, userInfo: nil) else {
    print("tapCreate nil"); exit(2)
}
final class Box: @unchecked Sendable { var loop: CFRunLoop? = nil }
let box = Box()
let thread = Thread {
    box.loop = CFRunLoopGetCurrent()
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, portA, 0), .commonModes)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, portB, 0), .commonModes)
    CFRunLoopRun()
}
thread.qualityOfService = .userInteractive
thread.start()
while box.loop == nil { usleep(10_000) }
usleep(200_000)

let here = CGEvent(source: nil)?.location ?? CGPoint(x: 0, y: 0)
let n = 300
for _ in 0..<n {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: here, mouseButton: .left)?.post(tap: .cghidEventTap)
    let s = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)!
    s.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
    s.post(tap: .cghidEventTap)
    if let gap = CommandLine.arguments.dropFirst().first.flatMap({ UInt32($0) }) { usleep(gap) }
}
usleep(800_000)

let seq = String(sequence)
let expected = String(repeating: "MS", count: n)
let moves = sequence.filter { $0 == "M" }.count
let scrolls = sequence.filter { $0 == "S" }.count
print("two-tap order: \(moves) moved, \(scrolls) scroll callbacks of \(n) each; strictly alternating = \(seq == expected)")
if seq != expected {
    // Show the first divergence and how many inversions exist (real pointer movement by the user adds extra Ms).
    var inversions = 0
    var last: Character = "S"
    for c in sequence { if c == last { inversions += 1 }; last = c }
    print("  first 80: \(seq.prefix(80)); runs of a repeated tag: \(inversions)")
}

var t0 = DispatchTime.now().uptimeNanoseconds
for _ in 0..<1000 { _ = CGEvent.tapIsEnabled(tap: portB) }
let perCall = (DispatchTime.now().uptimeNanoseconds - t0) / 1000
print("tapIsEnabled: \(perCall) ns per call (1000 calls)")

CGEvent.tapEnable(tap: portA, enable: false)
CGEvent.tapEnable(tap: portB, enable: false)
CFMachPortInvalidate(portA)
CFMachPortInvalidate(portB)
CFRunLoopStop(box.loop!)
usleep(100_000)
print("done; nothing left installed")
