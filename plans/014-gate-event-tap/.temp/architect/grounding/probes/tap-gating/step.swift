// Step-by-step isolation of the abort seen in main.swift's phase A.
import ApplicationServices
import Foundation
setvbuf(stdout, nil, _IONBF, 0)
print("1 make event")
let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)
print("2 event = \(e != nil)")
e?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
print("3 set phase")
var info = rusage_info_v4()
let rc = withUnsafeMutablePointer(to: &info) { p -> Int32 in
    p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
}
print("4 rusage rc=\(rc) user=\(info.ri_user_time) sys=\(info.ri_system_time)")
e?.post(tap: .cghidEventTap)
print("5 posted")
