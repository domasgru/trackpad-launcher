// Probe I: does our own tapEnable(false) / tapEnable(true) deliver an out-of-band event
// (tapDisabledByTimeout 0xFFFFFFFE or tapDisabledByUserInput 0xFFFFFFFF) to the callback?
// Mask: scroll only. Nothing is posted. Ten disable/enable cycles from a foreign thread, 200 ms apart.
// Any type-22 callbacks are the user's real scrolling during the run and are reported separately.

import ApplicationServices
import Foundation
import Darwin

setvbuf(stdout, nil, _IONBF, 0)

nonisolated(unsafe) var countsByType: [UInt32: Int] = [:]

let callback: CGEventTapCallBack = { _, type, event, _ in
    countsByType[type.rawValue, default: 0] += 1
    return Unmanaged.passUnretained(event)
}

guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                   eventsOfInterest: 1 << 22, callback: callback, userInfo: nil) else {
    print("tapCreate nil"); exit(2)
}
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
usleep(200_000)

let done = DispatchSemaphore(value: 0)
Thread {
    for _ in 0..<10 {
        CGEvent.tapEnable(tap: port, enable: false)
        usleep(200_000)
        CGEvent.tapEnable(tap: port, enable: true)
        usleep(200_000)
    }
    done.signal()
}.start()
done.wait()
usleep(300_000)

let oob = countsByType.filter { $0.key >= 0xFFFFFFF0 }
let scrolls = countsByType[22] ?? 0
print("I ten disable/enable cycles from a foreign thread, nothing posted: out-of-band callbacks by type = \(oob.map { "\(String($0.key, radix: 16)):\($0.value)" }.sorted()) (empty expected if our own toggles deliver nothing); real scroll events seen meanwhile = \(scrolls); other types = \(countsByType.filter { $0.key != 22 && $0.key < 0xFFFFFFF0 })")

CGEvent.tapEnable(tap: port, enable: false)
CFMachPortInvalidate(port)
CFRunLoopStop(box.loop!)
usleep(100_000)
print("done; nothing left installed")
