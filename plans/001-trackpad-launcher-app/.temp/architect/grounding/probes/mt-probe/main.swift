// Probe: MultitouchSupport.framework via dlopen, no link flags, no entitlements.
// Shows false if: symbols missing, device list empty, MTDeviceStart fails, frames never arrive
// while the trackpad is touched, device ID differs from IORegistry "Multitouch ID",
// actuator calls fail, IOKit first-match notification for AppleMultitouchDevice yields nothing,
// or CGEventSourceButtonState needs a permission.
import Foundation
import CoreGraphics
import IOKit

typealias MTDeviceRef = UnsafeMutableRawPointer
struct MTPoint { var x: Float; var y: Float }
struct MTReadout { var pos: MTPoint; var vel: MTPoint }
struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTReadout
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}
typealias MTContactCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
    print("FAIL dlopen: \(String(cString: dlerror()))"); exit(1)
}
func sym<T>(_ name: String, _ type: T.Type) -> T {
    guard let p = dlsym(handle, name) else { print("FAIL dlsym \(name)"); exit(1) }
    return unsafeBitCast(p, to: type)
}
let MTDeviceCreateList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>).self)
let MTDeviceIsBuiltIn = sym("MTDeviceIsBuiltIn", (@convention(c) (MTDeviceRef) -> Bool).self)
let MTDeviceGetDeviceID = sym("MTDeviceGetDeviceID", (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self)
let MTDeviceGetSensorSurfaceDimensions = sym("MTDeviceGetSensorSurfaceDimensions", (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32).self)
let MTDeviceGetFamilyID = sym("MTDeviceGetFamilyID", (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> Int32).self)
let MTDeviceIsRunning = sym("MTDeviceIsRunning", (@convention(c) (MTDeviceRef) -> Bool).self)
let MTDeviceIsAlive = sym("MTDeviceIsAlive", (@convention(c) (MTDeviceRef) -> Bool).self)
let MTRegisterContactFrameCallback = sym("MTRegisterContactFrameCallback", (@convention(c) (MTDeviceRef, MTContactCallback) -> Void).self)
let MTUnregisterContactFrameCallback = sym("MTUnregisterContactFrameCallback", (@convention(c) (MTDeviceRef, MTContactCallback) -> Void).self)
let MTDeviceStart = sym("MTDeviceStart", (@convention(c) (MTDeviceRef, Int32) -> Int32).self)
let MTDeviceStop = sym("MTDeviceStop", (@convention(c) (MTDeviceRef) -> Int32).self)
let MTDeviceRelease = sym("MTDeviceRelease", (@convention(c) (MTDeviceRef) -> Void).self)
let MTActuatorCreateFromDeviceID = sym("MTActuatorCreateFromDeviceID", (@convention(c) (UInt64) -> Unmanaged<CFTypeRef>?).self)
let MTActuatorOpen = sym("MTActuatorOpen", (@convention(c) (CFTypeRef) -> Int32).self)
let MTActuatorIsOpen = sym("MTActuatorIsOpen", (@convention(c) (CFTypeRef) -> Bool).self)
let MTActuatorActuate = sym("MTActuatorActuate", (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32).self)
let MTActuatorClose = sym("MTActuatorClose", (@convention(c) (CFTypeRef) -> Int32).self)
print("OK all symbols resolved; MemoryLayout<MTTouch>.stride = \(MemoryLayout<MTTouch>.stride) (expect 96)")

// ---- Device list
let list = MTDeviceCreateList().takeRetainedValue() as [AnyObject]
print("MTDeviceCreateList count = \(list.count)")
var devices: [MTDeviceRef] = []
for d in list {
    let ref = Unmanaged.passUnretained(d).toOpaque()
    var id: UInt64 = 0; var w: Int32 = 0; var h: Int32 = 0; var fam: Int32 = 0
    let r1 = MTDeviceGetDeviceID(ref, &id)
    let r2 = MTDeviceGetSensorSurfaceDimensions(ref, &w, &h)
    let r3 = MTDeviceGetFamilyID(ref, &fam)
    print("device builtIn=\(MTDeviceIsBuiltIn(ref)) id=\(id) (0x\(String(id, radix: 16))) rc=\(r1) surface=\(w)x\(h) rc=\(r2) family=\(fam) rc=\(r3) alive=\(MTDeviceIsAlive(ref)) running=\(MTDeviceIsRunning(ref))")
    devices.append(ref)
}

// ---- IOKit matching notification (hot-plug mechanism) + existing devices drained from the iterator
let port = IONotificationPortCreate(kIOMainPortDefault)
IONotificationPortSetDispatchQueue(port, DispatchQueue(label: "io"))
var iter: io_iterator_t = 0
let matchCB: IOServiceMatchingCallback = { _, iterator in
    var n = 0
    while case let s = IOIteratorNext(iterator), s != 0 { n += 1
        if let v = IORegistryEntryCreateCFProperty(s, "Multitouch ID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() { print("  IOKit matched AppleMultitouchDevice Multitouch ID = \(v)") }
        IOObjectRelease(s) }
    print("IOKit first-match callback: \(n) device(s)")
}
let kr = IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("AppleMultitouchDevice"), matchCB, nil, &iter)
print("IOServiceAddMatchingNotification rc=\(kr)")
matchCB(nil, iter) // drain existing

// ---- Frames
nonisolated(unsafe) var frameCount = 0
nonisolated(unsafe) var emptyFrames = 0
nonisolated(unsafe) var printed = 0
nonisolated(unsafe) var threads = Set<String>()
nonisolated(unsafe) var statesSeen = Set<Int32>()
let cb: MTContactCallback = { dev, rawTouches, n, ts, frame in
    let touches = rawTouches?.assumingMemoryBound(to: MTTouch.self)
    frameCount += 1
    if n == 0 { emptyFrames += 1 }
    threads.insert(Thread.isMainThread ? "main" : "bg:\(pthread_mach_thread_np(pthread_self()))")
    if let t = touches, n > 0 {
        for i in 0..<Int(n) { statesSeen.insert(t[i].state) }
        if printed < 12 {
            printed += 1
            let btn = CGEventSource.buttonState(.combinedSessionState, button: .left)
            var desc = "frame#\(frame) n=\(n) ts=\(String(format: "%.3f", ts)) leftButtonDown=\(btn):"
            for i in 0..<Int(n) {
                let x = t[i]
                desc += " [id=\(x.identifier) st=\(x.state) nx=\(String(format: "%.3f", x.normalized.pos.x)) ny=\(String(format: "%.3f", x.normalized.pos.y)) z=\(String(format: "%.2f", x.zTotal)) mm=\(String(format: "%.1f", x.absolute.pos.x)),\(String(format: "%.1f", x.absolute.pos.y))]"
            }
            print(desc)
        }
    }
    return 0
}
for d in devices {
    MTRegisterContactFrameCallback(d, cb)
    let rc = MTDeviceStart(d, 0)
    print("MTDeviceStart rc=\(rc) running=\(MTDeviceIsRunning(d))")
}
print("CGEventSourceButtonState(left) now = \(CGEventSource.buttonState(.combinedSessionState, button: .left))")
print("Listening 25 s. Touch the trackpad if you are there...")
RunLoop.main.run(until: Date().addingTimeInterval(25))
print("frames=\(frameCount) emptyFrames=\(emptyFrames) threads=\(threads) states=\(statesSeen.sorted())")
for d in devices { MTUnregisterContactFrameCallback(d, cb); print("MTDeviceStop rc=\(MTDeviceStop(d))") }

// ---- Actuator on the built-in trackpad
if let builtIn = devices.first(where: { MTDeviceIsBuiltIn($0) }) {
    var id: UInt64 = 0; _ = MTDeviceGetDeviceID(builtIn, &id)
    if let act = MTActuatorCreateFromDeviceID(id)?.takeRetainedValue() {
        let o = MTActuatorOpen(act)
        print("MTActuatorCreateFromDeviceID ok; MTActuatorOpen rc=\(o) isOpen=\(MTActuatorIsOpen(act))")
        let a = MTActuatorActuate(act, 6, 0, 0, 0)
        print("MTActuatorActuate(id 6) rc=\(a) (0 = kIOReturnSuccess)")
        print("MTActuatorClose rc=\(MTActuatorClose(act))")
    } else { print("FAIL MTActuatorCreateFromDeviceID returned nil") }
}
for d in devices { MTDeviceRelease(d) }
print("done")
