import Foundation
import IOKit

/// The private MultitouchSupport framework, loaded with `dlopen` (no link flags, no entitlements, no prompt;
/// the framework is Apple-signed so the hardened runtime needs no library-validation exception).
/// Only the symbols in use are resolved; a missing one fails the whole load, which reads as "no trackpad".
struct MultitouchSupport: Sendable {
    typealias DeviceRef = UnsafeMutableRawPointer
    /// `int cb(MTDeviceRef, MTTouch *touches, int count, double timestamp, int frame)`, delivered on the
    /// framework's own thread. Context-free, so the receiver finds its state through a global registry.
    typealias ContactFrameCallback =
        @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

    let createList: @convention(c) () -> Unmanaged<CFArray>
    let isBuiltIn: @convention(c) (DeviceRef) -> Bool
    let getDeviceID: @convention(c) (DeviceRef, UnsafeMutablePointer<UInt64>) -> Int32
    /// Hundredths of a millimetre.
    let getSensorSurfaceDimensions: @convention(c) (DeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    let getService: @convention(c) (DeviceRef) -> io_service_t
    let registerContactFrameCallback: @convention(c) (DeviceRef, ContactFrameCallback) -> Void
    let unregisterContactFrameCallback: @convention(c) (DeviceRef, ContactFrameCallback) -> Void
    let start: @convention(c) (DeviceRef, Int32) -> Int32
    let stop: @convention(c) (DeviceRef) -> Int32
    let actuatorCreateFromDeviceID: @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    let actuatorOpen: @convention(c) (CFTypeRef) -> Int32
    let actuatorActuate: @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32
    let actuatorClose: @convention(c) (CFTypeRef) -> Int32

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return nil }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: type) }
        }
        guard let createList = symbol("MTDeviceCreateList", as: (@convention(c) () -> Unmanaged<CFArray>).self),
            let isBuiltIn = symbol("MTDeviceIsBuiltIn", as: (@convention(c) (DeviceRef) -> Bool).self),
            let getDeviceID = symbol(
                "MTDeviceGetDeviceID", as: (@convention(c) (DeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self),
            let getSensorSurfaceDimensions = symbol(
                "MTDeviceGetSensorSurfaceDimensions",
                as: (@convention(c) (DeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32).self),
            let getService = symbol("MTDeviceGetService", as: (@convention(c) (DeviceRef) -> io_service_t).self),
            let registerContactFrameCallback = symbol(
                "MTRegisterContactFrameCallback", as: (@convention(c) (DeviceRef, ContactFrameCallback) -> Void).self),
            let unregisterContactFrameCallback = symbol(
                "MTUnregisterContactFrameCallback",
                as: (@convention(c) (DeviceRef, ContactFrameCallback) -> Void).self),
            let start = symbol("MTDeviceStart", as: (@convention(c) (DeviceRef, Int32) -> Int32).self),
            let stop = symbol("MTDeviceStop", as: (@convention(c) (DeviceRef) -> Int32).self),
            let actuatorCreateFromDeviceID = symbol(
                "MTActuatorCreateFromDeviceID", as: (@convention(c) (UInt64) -> Unmanaged<CFTypeRef>?).self),
            let actuatorOpen = symbol("MTActuatorOpen", as: (@convention(c) (CFTypeRef) -> Int32).self),
            let actuatorActuate = symbol(
                "MTActuatorActuate", as: (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32).self),
            let actuatorClose = symbol("MTActuatorClose", as: (@convention(c) (CFTypeRef) -> Int32).self)
        else { return nil }
        self.createList = createList
        self.isBuiltIn = isBuiltIn
        self.getDeviceID = getDeviceID
        self.getSensorSurfaceDimensions = getSensorSurfaceDimensions
        self.getService = getService
        self.registerContactFrameCallback = registerContactFrameCallback
        self.unregisterContactFrameCallback = unregisterContactFrameCallback
        self.start = start
        self.stop = stop
        self.actuatorCreateFromDeviceID = actuatorCreateFromDeviceID
        self.actuatorOpen = actuatorOpen
        self.actuatorActuate = actuatorActuate
        self.actuatorClose = actuatorClose
    }
}
