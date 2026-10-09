// Check (after fan-out): two claims the candidates make about the toolchain.
//  1. `kAXTrustedCheckOptionPrompt` imports as a global `var` of type `Unmanaged<CFString>`; referencing it from a
//     main-actor function under `-swift-version 6 -strict-concurrency=complete` fails with "reference to var
//     'kAXTrustedCheckOptionPrompt' is not concurrency-safe because it involves shared mutable state"
//     (recorded in build-strict-error.txt). So the adapter spells the key out; this probe prints the key's real value.
//  2. Is `CGEventType(rawValue: 34)` (NSEventTypePressure, no public case) a usable value for a tap mask and for
//     rewriting an event's type?
// Build and run:
//   xcrun swiftc -swift-version 6 -strict-concurrency=complete -o /tmp/tl-swift6-probe main.swift && /tmp/tl-swift6-probe

import ApplicationServices
import CoreGraphics

nonisolated(unsafe) let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
print("kAXTrustedCheckOptionPrompt value: \"\(promptKey as String)\"")

let pressure = CGEventType(rawValue: 34)
print("CGEventType(rawValue: 34) -> \(String(describing: pressure)) rawValue=\(pressure?.rawValue ?? 0)")
let mask: CGEventMask = [CGEventType.leftMouseDown, .leftMouseUp, pressure!]
    .reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
print("mask value 0x\(String(mask, radix: 16))")
let event = CGEvent(source: nil)
event?.type = pressure!
print("settable type on a CGEvent: \(String(describing: event?.type.rawValue))")
