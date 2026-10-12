// Records every raw MultitouchSupport frame (all driver states) to stdout, one line per frame:
// <timestamp> <count> then per touch: id:state:x:y:z:major:minor (x, y normalised, origin bottom-left).
import Foundation

typealias MTDeviceRef = UnsafeMutableRawPointer
struct MTTouch {
    var frame: Int32; var timestamp: Double; var identifier: Int32; var state: Int32
    var fingerID: Int32; var handID: Int32
    var nx: Float; var ny: Float; var vx: Float; var vy: Float
    var zTotal: Float; var field9: Int32; var angle: Float; var majorAxis: Float; var minorAxis: Float
    var ax: Float; var ay: Float; var avx: Float; var avy: Float
    var field14: Int32; var field15: Int32; var zDensity: Float
}
typealias CB = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)!
func sym<T>(_ n: String, _ t: T.Type) -> T { unsafeBitCast(dlsym(h, n)!, to: t) }
let createList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>).self)
let register = sym("MTRegisterContactFrameCallback", (@convention(c) (MTDeviceRef, CB) -> Void).self)
let start = sym("MTDeviceStart", (@convention(c) (MTDeviceRef, Int32) -> Int32).self)
let dims = sym(
    "MTDeviceGetSensorSurfaceDimensions",
    (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32).self)
setvbuf(stdout, nil, _IOLBF, 0)
let cb: CB = { _, raw, n, ts, _ in
    var line = String(format: "%.4f %d", ts, n)
    if let t = raw?.assumingMemoryBound(to: MTTouch.self) {
        for i in 0..<Int(n) {
            let x = t[i]
            line += String(
                format: " %d:%d:%.4f:%.4f:%.2f:%.2f:%.2f", x.identifier, x.state, x.nx, x.ny, x.zTotal, x.majorAxis,
                x.minorAxis)
        }
    }
    print(line)
    return 0
}
for d in createList().takeRetainedValue() as [AnyObject] {
    let ref = Unmanaged.passUnretained(d).toOpaque()
    var w: Int32 = 0
    var hh: Int32 = 0
    _ = dims(ref, &w, &hh)
    print("# device surface \(w)x\(hh)")
    register(ref, cb)
    _ = start(ref, 0)
}
RunLoop.main.run(until: Date().addingTimeInterval(Double(CommandLine.arguments.dropFirst().first ?? "120")!))
