// Probe: what a disabled event tap costs, whether tapEnable works from a foreign thread, and what one toggle costs.
//
// Phases (each posts N zero-delta pixel scroll events to the HID tap and measures the tap thread's CPU and the
// callback count):
//   A. no tap installed             -> posting cost alone (baseline)
//   B. tap installed and enabled    -> callbacks == N, CPU per event
//   C. tap disabled from a thread that is neither main nor the tap thread -> callbacks == 0?, CPU ~ baseline?
//   D. re-enabled from that same foreign thread, one event posted right after the call returns -> delivered?
//   E. mask that excludes scroll (left mouse down only), enabled -> callbacks == 0?, CPU ~ baseline?  (server-side mask)
//   F. 2000 enable/disable toggles from the foreign thread while events are posted -> time per toggle, no crash,
//      tapIsEnabled consistent afterwards
// Leaves nothing behind: the tap is invalidated and the thread stopped before exit. Posted events carry zero deltas.

import ApplicationServices
import Foundation
import Darwin

nonisolated(unsafe) var callbackCount = 0
nonisolated(unsafe) var tapThreadPort: thread_t = 0
nonisolated(unsafe) var lastSeenType: UInt32 = 0

func threadCPU(_ port: thread_t) -> Double {
    var info = thread_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            thread_info(port, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return -1 }
    let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
    let sys = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6
    return user + sys
}

func processCPU() -> Double {
    var usage = rusage_info_v4()
    let ok = withUnsafeMutablePointer(to: &usage) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
    }
    guard ok == 0 else { return -1 }
    return Double(usage.ri_user_time + usage.ri_system_time) / 1e9
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    callbackCount += 1
    lastSeenType = type.rawValue
    return Unmanaged.passUnretained(event)
}

func makeScroll() -> CGEvent {
    let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)!
    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2) // changed
    return e
}

func post(_ n: Int) {
    for _ in 0..<n { makeScroll().post(tap: .cghidEventTap) }
}

func settle() { usleep(400_000) }

struct Tap: @unchecked Sendable {
    let port: CFMachPort
    let thread: Thread
    let runLoop: CFRunLoop
}

func install(mask: CGEventMask) -> Tap? {
    guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                       eventsOfInterest: mask, callback: callback, userInfo: nil) else { return nil }
    let loopBox = Mutex<CFRunLoop?>(nil)
    let thread = Thread {
        tapThreadPort = mach_thread_self()
        loopBox.withLock { $0 = CFRunLoopGetCurrent() }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CFRunLoopRun()
    }
    thread.qualityOfService = .userInteractive
    thread.start()
    var loop: CFRunLoop? = nil
    while loop == nil { usleep(10_000); loop = loopBox.withLock { $0 } }
    usleep(100_000)
    return Tap(port: port, thread: thread, runLoop: loop!)
}

func remove(_ tap: Tap) {
    CGEvent.tapEnable(tap: tap.port, enable: false)
    CFMachPortInvalidate(tap.port)
    CFRunLoopStop(tap.runLoop)
    usleep(100_000)
}

final class Mutex<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()
    init(_ value: T) { self.value = value }
    func withLock<R>(_ body: (inout T) -> R) -> R { lock.lock(); defer { lock.unlock() }; return body(&value) }
}

/// Runs `body` on a fresh thread (neither main nor the tap thread) and waits for it.
func onForeignThread(_ body: @escaping @Sendable () -> Void) {
    let done = DispatchSemaphore(value: 0)
    let t = Thread { body(); done.signal() }
    t.start()
    done.wait()
}

setvbuf(stdout, nil, _IONBF, 0)
let n = 2000
let shippedMask: CGEventMask = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 6) | (1 << 7) | (1 << 22) | (1 << 25) | (1 << 26) | (1 << 27) | (1 << 29) | (1 << 30) | (1 << 34)

print("AXIsProcessTrusted: \(AXIsProcessTrusted())")

// A. no tap: posting cost alone
do {
    let c0 = processCPU(); post(n); settle(); let c1 = processCPU()
    print(String(format: "A no tap: process CPU for posting %d events = %.3f ms (%.1f us/event)", n, (c1 - c0) * 1e3, (c1 - c0) * 1e6 / Double(n)))
}

guard let tap = install(mask: shippedMask) else {
    print("tapCreate returned nil: no Accessibility for this process; the rest of the probe cannot run")
    exit(2)
}
print("tap installed; enabled = \(CGEvent.tapIsEnabled(tap: tap.port))")

// B. enabled
do {
    callbackCount = 0
    let t0 = threadCPU(tapThreadPort); let c0 = processCPU(); post(n); settle()
    let t1 = threadCPU(tapThreadPort); let c1 = processCPU()
    print(String(format: "B enabled: callbacks = %d of %d; tap thread CPU = %.3f ms (%.1f us/event); process CPU = %.3f ms; last type = %d",
                 callbackCount, n, (t1 - t0) * 1e3, (t1 - t0) * 1e6 / Double(n), (c1 - c0) * 1e3, lastSeenType))
}

// C. disabled from a foreign thread
do {
    onForeignThread { CGEvent.tapEnable(tap: tap.port, enable: false) }
    print("C after disable from foreign thread: tapIsEnabled = \(CGEvent.tapIsEnabled(tap: tap.port))")
    callbackCount = 0
    let t0 = threadCPU(tapThreadPort); let c0 = processCPU(); post(n); settle()
    let t1 = threadCPU(tapThreadPort); let c1 = processCPU()
    print(String(format: "C disabled: callbacks = %d of %d; tap thread CPU = %.3f ms; process CPU = %.3f ms",
                 callbackCount, n, (t1 - t0) * 1e3, (c1 - c0) * 1e3))
}

// D. re-enabled from a foreign thread, one event posted right after the call returns
do {
    callbackCount = 0
    var enableNanos: UInt64 = 0
    onForeignThread {
        let a = DispatchTime.now().uptimeNanoseconds
        CGEvent.tapEnable(tap: tap.port, enable: true)
        enableNanos = DispatchTime.now().uptimeNanoseconds - a
        makeScroll().post(tap: .cghidEventTap)
    }
    settle()
    print("D re-enabled from foreign thread in \(enableNanos / 1000) us; event posted right after: callbacks = \(callbackCount) (1 expected); tapIsEnabled = \(CGEvent.tapIsEnabled(tap: tap.port))")
}

// F. toggle storm from a foreign thread while events are posted from main
do {
    let toggles = 2000
    var total: UInt64 = 0
    let posting = Thread { post(n) }
    posting.start()
    onForeignThread {
        let a = DispatchTime.now().uptimeNanoseconds
        for i in 0..<toggles { CGEvent.tapEnable(tap: tap.port, enable: i % 2 == 0) }
        total = DispatchTime.now().uptimeNanoseconds - a
    }
    settle()
    print(String(format: "F toggle storm: %d toggles in %.2f ms = %.1f us per toggle; callbacks during storm = %d; final tapIsEnabled = %d (false expected: last toggle was disable)",
                 toggles, Double(total) / 1e6, Double(total) / 1e3 / Double(toggles), callbackCount, CGEvent.tapIsEnabled(tap: tap.port) ? 1 : 0))
    CGEvent.tapEnable(tap: tap.port, enable: true)
    callbackCount = 0
    post(10); settle()
    print("F after storm, enabled again: 10 posted, callbacks = \(callbackCount)")
}

remove(tap)

// E. mask without scroll: left mouse down only
do {
    guard let narrow = install(mask: 1 << 1) else { print("E: tapCreate nil"); exit(2) }
    callbackCount = 0
    let t0 = threadCPU(tapThreadPort); let c0 = processCPU(); post(n); settle()
    let t1 = threadCPU(tapThreadPort); let c1 = processCPU()
    print(String(format: "E press-only mask, enabled: callbacks = %d of %d scroll events; tap thread CPU = %.3f ms; process CPU = %.3f ms",
                 callbackCount, n, (t1 - t0) * 1e3, (c1 - c0) * 1e3))
    remove(narrow)
}

// G. no tap again, to confirm the baseline did not drift
do {
    let c0 = processCPU(); post(n); settle(); let c1 = processCPU()
    print(String(format: "G no tap (again): process CPU for posting %d events = %.3f ms", n, (c1 - c0) * 1e3))
}
print("done; nothing left installed")
