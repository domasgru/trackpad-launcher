import Foundation
import IOKit

/// The private MultitouchSupport framework, loaded with `dlopen` (no link flags, no entitlements, no prompt;
/// the framework is Apple-signed so the hardened runtime needs no library-validation exception).
/// Only the symbols in use are resolved; a missing one fails the whole load, which reads as "no trackpad".
struct MultitouchSupport: Sendable {
    typealias DeviceRef = UnsafeMutableRawPointer

    let createList: @convention(c) () -> Unmanaged<CFArray>
    let isBuiltIn: @convention(c) (DeviceRef) -> Bool
    let getDeviceID: @convention(c) (DeviceRef, UnsafeMutablePointer<UInt64>) -> Int32
    /// Hundredths of a millimetre.
    let getSensorSurfaceDimensions: @convention(c) (DeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    let getService: @convention(c) (DeviceRef) -> io_service_t

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
            let getService = symbol("MTDeviceGetService", as: (@convention(c) (DeviceRef) -> io_service_t).self)
        else { return nil }
        self.createList = createList
        self.isBuiltIn = isBuiltIn
        self.getDeviceID = getDeviceID
        self.getSensorSurfaceDimensions = getSensorSurfaceDimensions
        self.getService = getService
    }
}
