// Probe: in what order do the multitouch frames of a tap and the click macOS synthesizes for it (Tap to click)
// reach a process? Logs, on one clock (systemUptime at receipt), every frame whose set of contacts changes and
// every mouse button event. Run: swiftc -O tap-click-order.swift -o /tmp/tap-click-order && /tmp/tap-click-order 90
import CoreGraphics
import Foundation

typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

struct MTTouch {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var identifier: Int32 = 0
    var state: Int32 = 0
    var fingerID: Int32 = 0
    var handID: Int32 = 0
    var x: Float = 0
    var y: Float = 0
    var rest: (Float, Float, Float, Int32, Float, Float, Float, Float, Float, Float, Float, Int32, Int32, Float) =
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

let start = ProcessInfo.processInfo.systemUptime
let lock = NSLock()
func log(_ s: String) {
    lock.lock()
    defer { lock.unlock() }
    let t = (ProcessInfo.processInfo.systemUptime - start) * 1000
    print(String(format: "%9.1f ms  ", t) + s)
    fflush(stdout)
}

nonisolated(unsafe) var lastKey = ""
let frameCallback: Callback = { _, touches, count, timestamp, _ in
    var parts: [String] = []
    if let touches, count > 0 {
        let records = UnsafeBufferPointer(start: touches.assumingMemoryBound(to: MTTouch.self), count: Int(count))
        for r in records where r.state >= 1 && r.state <= 7 {
            parts.append(String(format: "#%d s%d (%.2f,%.2f)", r.identifier, r.state, r.x, 1 - r.y))
        }
    }
    // Log only when the ids or states change, not on every move.
    let key = parts.map { $0.components(separatedBy: " (").first! }.joined(separator: ",")
    if key != lastKey {
        lastKey = key
        log(String(format: "FRAME mt=%.4f n=%d  ", timestamp, parts.count) + parts.joined(separator: "  "))
    }
    return 0
}

let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
guard let h = dlopen(path, RTLD_NOW) else { fatalError("no MultitouchSupport") }
let createList = unsafeBitCast(dlsym(h, "MTDeviceCreateList"), to: (@convention(c) () -> Unmanaged<CFArray>).self)
let register = unsafeBitCast(
    dlsym(h, "MTRegisterContactFrameCallback"),
    to: (@convention(c) (UnsafeMutableRawPointer, Callback) -> Void).self)
let startDevice = unsafeBitCast(
    dlsym(h, "MTDeviceStart"), to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Int32).self)
let devices = createList().takeRetainedValue() as [AnyObject]
for d in devices {
    let ref = Unmanaged.passUnretained(d).toOpaque()
    register(ref, frameCallback)
    _ = startDevice(ref, 0)
}
log("devices: \(devices.count)")

let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
// Every type but moves, drags, scrolls, pressure and keys: catch whatever Look up and Smart zoom arrive as.
var mask: CGEventMask = 0
for bit in 0..<64 where ![5, 6, 7, 10, 11, 12, 22, 27, 34].contains(bit) { mask |= CGEventMask(1) << CGEventMask(bit) }
let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    let name: String
    switch type {
    case .leftMouseDown: name = "LEFT DOWN"
    case .leftMouseUp: name = "LEFT UP"
    case .rightMouseDown: name = "RIGHT DOWN"
    case .rightMouseUp: name = "RIGHT UP"
    case .otherMouseDown: name = "OTHER DOWN"
    case .otherMouseUp: name = "OTHER UP"
    default:
        let hid = event.getIntegerValueField(CGEventField(rawValue: 110)!)
        let phase = event.getIntegerValueField(CGEventField(rawValue: 132)!)
        // Skip the flood of plain gesture frames (hid 0) and Dock swipe changes.
        if type.rawValue == 29 && hid == 0 { return Unmanaged.passUnretained(event) }
        // Drop mode: the file /tmp/probe-drop exists. Look up (hid 24) and Smart zoom (hid 22) are dropped.
        let drops = type.rawValue == 29 && (hid == 22 || hid == 24)
            && FileManager.default.fileExists(atPath: "/tmp/probe-drop")
        var fields = ""
        if hid == 22 || hid == 24 {
            for raw in 0..<256 where raw != 110 && raw != 132 && raw != 58 {
                guard let field = CGEventField(rawValue: UInt32(raw)) else { continue }
                let value = event.getIntegerValueField(field)
                if value != 0 { fields += " f\(raw)=\(value)" }
            }
        }
        log("EVENT type=\(type.rawValue) hid=\(hid) phase=\(phase)\(drops ? " DROPPED" : "")\(fields)")
        return drops ? nil : Unmanaged.passUnretained(event)
    }
    let number = event.getIntegerValueField(.mouseEventNumber)
    let pressure = event.getDoubleValueField(.mouseEventPressure)
    let subtype = event.getIntegerValueField(.mouseEventSubtype)
    let source = event.getIntegerValueField(.eventSourceStateID)
    let evTime = Double(event.timestamp) / 1e9
    log(String(format: "%@  number=%lld pressure=%.2f subtype=%lld source=%lld evts=%.4f", name, number, pressure,
               subtype, source, evTime))
    return Unmanaged.passUnretained(event)
}
guard
    let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
        callback: tapCallback, userInfo: nil)
else { fatalError("event tap refused: grant Accessibility/Input Monitoring to the terminal") }
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
CGEvent.tapEnable(tap: port, enable: true)
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "60") ?? 60
log("listening for \(seconds) s")
CFRunLoopRunInMode(.defaultMode, seconds, false)
log("done")
