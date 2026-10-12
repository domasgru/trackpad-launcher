// Probe: scroll-wheel events as a CGEvent tap would see them.
// 1. Raw values of CGEventType.scrollWheel and the scroll CGEventFields, and whether the phase/momentum/continuous
//    fields round-trip on an event built in-process (no posting: nothing is sent to the system).
// 2. Whether this process is AX-trusted, and whether a listen-only and an active session tap over scrollWheel can be
//    created without trust.
// 3. If a tap exists, listens 15 s and prints every scroll event's isContinuous, scrollPhase, momentumPhase and
//    deltas (passing every event through unchanged), so a real trackpad scroll, momentum and a wheel mouse show
//    their field values if someone scrolls meanwhile. The machine is left as found.
import ApplicationServices
import CoreGraphics
import Foundation

print("CGEventType.scrollWheel.rawValue = \(CGEventType.scrollWheel.rawValue)")
let fields: [(String, CGEventField)] = [
    ("scrollWheelEventDeltaAxis1", .scrollWheelEventDeltaAxis1),
    ("scrollWheelEventDeltaAxis2", .scrollWheelEventDeltaAxis2),
    ("scrollWheelEventPointDeltaAxis1", .scrollWheelEventPointDeltaAxis1),
    ("scrollWheelEventPointDeltaAxis2", .scrollWheelEventPointDeltaAxis2),
    ("scrollWheelEventIsContinuous", .scrollWheelEventIsContinuous),
    ("scrollWheelEventScrollPhase", .scrollWheelEventScrollPhase),
    ("scrollWheelEventMomentumPhase", .scrollWheelEventMomentumPhase),
]
for (name, field) in fields { print("CGEventField.\(name).rawValue = \(field.rawValue)") }
print("CGScrollPhase: began=\(CGScrollPhase.began.rawValue) changed=\(CGScrollPhase.changed.rawValue) ended=\(CGScrollPhase.ended.rawValue) cancelled=\(CGScrollPhase.cancelled.rawValue) mayBegin=\(CGScrollPhase.mayBegin.rawValue)")
print("CGMomentumScrollPhase: none=\(CGMomentumScrollPhase.none.rawValue) begin=\(CGMomentumScrollPhase.begin.rawValue) continuous=\(CGMomentumScrollPhase.continuous.rawValue) end=\(CGMomentumScrollPhase.end.rawValue)")

// Field round trip on a local event (never posted).
if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: -7, wheel2: 3, wheel3: 0) {
    print("local scroll event type=\(event.type.rawValue) isContinuous=\(event.getIntegerValueField(.scrollWheelEventIsContinuous)) axis1=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) axis2=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) pointAxis1=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))")
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.began.rawValue))
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(CGMomentumScrollPhase.begin.rawValue))
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    print("after set: isContinuous=\(event.getIntegerValueField(.scrollWheelEventIsContinuous)) scrollPhase=\(event.getIntegerValueField(.scrollWheelEventScrollPhase)) momentumPhase=\(event.getIntegerValueField(.scrollWheelEventMomentumPhase))")
    // Zeroing the deltas, as a "cut" rewrite would.
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.ended.rawValue))
    print("after zero+ended: axis1=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) pointAxis1=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)) fixed1=\(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)) scrollPhase=\(event.getIntegerValueField(.scrollWheelEventScrollPhase))")
    if let line = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0) {
        print("local line-unit event isContinuous=\(line.getIntegerValueField(.scrollWheelEventIsContinuous)) (a wheel mouse scrolls in lines)")
    }
}

print("AXIsProcessTrusted: \(AXIsProcessTrusted())")

final class Seen: @unchecked Sendable { var lines: [String] = []; var disabled = 0 }
let seen = Seen()
let callback: CGEventTapCallBack = { _, type, event, userInfo in
    let seen = Unmanaged<Seen>.fromOpaque(userInfo!).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { seen.disabled += 1; return Unmanaged.passUnretained(event) }
    if type == .scrollWheel, seen.lines.count < 400 {
        seen.lines.append("t=\(event.timestamp) cont=\(event.getIntegerValueField(.scrollWheelEventIsContinuous)) phase=\(event.getIntegerValueField(.scrollWheelEventScrollPhase)) momentum=\(event.getIntegerValueField(.scrollWheelEventMomentumPhase)) d1=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) d2=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) p1=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)) p2=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)) thread=\(Thread.isMainThread ? "main" : "other")")
    }
    return Unmanaged.passUnretained(event)
}
let mask: CGEventMask = CGEventMask(1) << CGEventMask(CGEventType.scrollWheel.rawValue)
var active: CFMachPort?
for (name, options) in [("listenOnly", CGEventTapOptions.listenOnly), ("default(active)", .defaultTap)] {
    let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: options, eventsOfInterest: mask,
                                callback: callback, userInfo: Unmanaged.passUnretained(seen).toOpaque())
    print("tapCreate(session, headInsert, \(name), scrollWheel): \(tap == nil ? "nil" : "created")")
    if let tap { if options == .defaultTap { active = tap } else { CFMachPortInvalidate(tap) } }
}
if let active {
    let source = CFMachPortCreateRunLoopSource(nil, active, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    print("Listening 15 s; scroll on the trackpad (and flick for momentum), and turn a mouse wheel if one is connected...")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 15))
    CGEvent.tapEnable(tap: active, enable: false)
    CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    CFMachPortInvalidate(active)
    print("scroll events seen: \(seen.lines.count), disabled notices: \(seen.disabled)")
    seen.lines.forEach { print("  \($0)") }
} else {
    print("No active tap: live scroll fields cannot be observed from this process.")
}
print("done")
