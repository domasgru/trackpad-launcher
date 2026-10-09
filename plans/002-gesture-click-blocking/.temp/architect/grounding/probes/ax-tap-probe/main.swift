// Probe: Accessibility trust state, event-tap creation per option for mouse-button events, callback thread,
// and whether a press DROPPED by an active session tap still shows in CGEventSource.buttonState.
//
// Safety: the tap passes every real event through unchanged. The only events it drops are the probe's own
// synthetic presses of mouse button 10, which no application handles. No prompt is shown (AXIsProcessTrusted,
// not AXIsProcessTrustedWithOptions). The machine is left as found.
//
// Build and run:
//   swiftc -O -o /tmp/ax-tap-probe main.swift && /tmp/ax-tap-probe

import ApplicationServices
import CoreGraphics
import Foundation

final class Counter: @unchecked Sendable {
    var seen: [String] = []
    var disabled = 0
}

let probeButton: Int64 = 10

let callback: CGEventTapCallBack = { _, type, event, userInfo in
    let counter = Unmanaged<Counter>.fromOpaque(userInfo!).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        counter.disabled += 1
        return Unmanaged.passUnretained(event)
    }
    let button = event.getIntegerValueField(.mouseEventButtonNumber)
    let subtype = event.getIntegerValueField(.mouseEventSubtype)
    let number = event.getIntegerValueField(.mouseEventNumber)
    let thread = Thread.isMainThread ? "main" : "other"
    counter.seen.append(
        "type=\(type.rawValue) button=\(button) number=\(number) subtype=\(subtype) thread=\(thread) ts=\(event.timestamp)")
    // Drop only the probe's own synthetic button-10 presses.
    if button == probeButton { return nil }
    return Unmanaged.passUnretained(event)
}

let trusted = AXIsProcessTrusted()
print("AXIsProcessTrusted: \(trusted)")

let mouseMask: CGEventMask = [
    CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
].reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }

let counter = Counter()
let userInfo = Unmanaged.passUnretained(counter).toOpaque()

var activeTap: CFMachPort?
for (name, options) in [("listenOnly", CGEventTapOptions.listenOnly), ("default(active)", .defaultTap)] {
    let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: options,
        eventsOfInterest: mouseMask, callback: callback, userInfo: userInfo)
    print("tapCreate(.cgSessionEventTap, .headInsertEventTap, \(name), mouse buttons): \(tap == nil ? "nil" : "created")")
    if let tap {
        print("  tapIsEnabled: \(CGEvent.tapIsEnabled(tap: tap))")
        if options == .defaultTap { activeTap = tap } else { CFMachPortInvalidate(tap) }
    }
}

guard let activeTap else {
    print("No active tap: the dropped-press button-state check cannot run here.")
    exit(0)
}

let source = CFMachPortCreateRunLoopSource(nil, activeTap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

func buttonState(_ button: Int64) -> String {
    let b = CGMouseButton(rawValue: UInt32(button))!
    let combined = CGEventSource.buttonState(.combinedSessionState, button: b)
    let hid = CGEventSource.buttonState(.hidSystemState, button: b)
    return "combinedSession=\(combined) hidSystem=\(hid)"
}

let location = CGEvent(source: nil)?.location ?? .zero
print("cursor at \(location)")
print("button \(probeButton) state before: \(buttonState(probeButton))")

func post(_ type: CGEventType) {
    let event = CGEvent(
        mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
        mouseButton: CGMouseButton(rawValue: UInt32(probeButton))!)
    event?.post(tap: .cghidEventTap)
}

post(.otherMouseDown)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
print("button \(probeButton) state after a DROPPED down: \(buttonState(probeButton))")
post(.otherMouseUp)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
print("button \(probeButton) state after a DROPPED up: \(buttonState(probeButton))")

print("events seen by the tap: \(counter.seen.count), disabled notices: \(counter.disabled)")
counter.seen.forEach { print("  \($0)") }

CGEvent.tapEnable(tap: activeTap, enable: false)
CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
CFMachPortInvalidate(activeTap)
print("tap invalidated; done")
