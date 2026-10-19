// Probe H: can the tap disable itself from inside its own callback (the tap thread), and how many events that were
// already queued still reach the callback after the disable? Also: is tapEnable(true) idempotent when already enabled?
//
// A thread posts 3000 zero-delta scroll events as fast as it can. The callback calls tapEnable(false) on its 500th
// event and keeps counting. Expected: the count stops at 500 plus whatever was already in flight; the tap reads
// disabled afterwards; re-enabling twice then posting one event delivers exactly one callback.

import ApplicationServices
import Foundation
import Darwin

setvbuf(stdout, nil, _IONBF, 0)

nonisolated(unsafe) var callbackCount = 0
nonisolated(unsafe) var countAtDisable = -1
nonisolated(unsafe) var tapPort: CFMachPort? = nil
nonisolated(unsafe) var disableNanos: UInt64 = 0

let callback: CGEventTapCallBack = { _, _, event, _ in
    callbackCount += 1
    if callbackCount == 500, let port = tapPort {
        let a = DispatchTime.now().uptimeNanoseconds
        CGEvent.tapEnable(tap: port, enable: false)
        disableNanos = DispatchTime.now().uptimeNanoseconds - a
        countAtDisable = callbackCount
    }
    return Unmanaged.passUnretained(event)
}

func makeScroll() -> CGEvent {
    let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)!
    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
    return e
}

let mask: CGEventMask = 1 << 22
guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                   eventsOfInterest: mask, callback: callback, userInfo: nil) else {
    print("tapCreate nil"); exit(2)
}
tapPort = port
final class Box: @unchecked Sendable { var loop: CFRunLoop? = nil }
let box = Box()
let thread = Thread {
    box.loop = CFRunLoopGetCurrent()
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
    CFRunLoopRun()
}
thread.qualityOfService = .userInteractive
thread.start()
while box.loop == nil { usleep(10_000) }
usleep(100_000)

let gapMicros = UInt32(CommandLine.arguments.dropFirst().first ?? "0") ?? 0
let poster = Thread { for _ in 0..<(gapMicros == 0 ? 3000 : 800) { makeScroll().post(tap: .cghidEventTap); if gapMicros > 0 { usleep(gapMicros) } } }
poster.start()
usleep(gapMicros == 0 ? 1_500_000 : 800 * gapMicros + 500_000)
print("H self-disable from the callback at event 500: took \(disableNanos / 1000) us; callbacks after 1.5 s = \(callbackCount) (events delivered after the disable = \(callbackCount - countAtDisable)); tapIsEnabled = \(CGEvent.tapIsEnabled(tap: port))")

callbackCount = 0
countAtDisable = -1
CGEvent.tapEnable(tap: port, enable: true)
CGEvent.tapEnable(tap: port, enable: true)
makeScroll().post(tap: .cghidEventTap)
usleep(300_000)
print("H enable twice then one event: callbacks = \(callbackCount) (1 expected); tapIsEnabled = \(CGEvent.tapIsEnabled(tap: port))")

CGEvent.tapEnable(tap: port, enable: false)
CFMachPortInvalidate(port)
CFRunLoopStop(box.loop!)
usleep(100_000)
print("done; nothing left installed")
