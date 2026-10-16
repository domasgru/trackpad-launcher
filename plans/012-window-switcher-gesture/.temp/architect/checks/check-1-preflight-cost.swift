// Check 1: what does a fresh Screen Recording preflight cost on the calling thread?
// Settles whether the model can read the grant fresh at each window swipe begin (the cross-judge's graft 1).
// Read-only: CGPreflightScreenCaptureAccess never prompts (CGWindow.h). Run: swift check-1-preflight-cost.swift
import CoreGraphics
import Foundation

func ms(_ start: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }

var start = DispatchTime.now().uptimeNanoseconds
let first = CGPreflightScreenCaptureAccess()
print("first call: \(first) in \(String(format: "%.3f", ms(start))) ms")

var samples: [Double] = []
for _ in 0..<200 {
    start = DispatchTime.now().uptimeNanoseconds
    _ = CGPreflightScreenCaptureAccess()
    samples.append(ms(start))
}
samples.sort()
print(String(format: "200 warm calls: median %.4f ms, p95 %.4f ms, max %.4f ms",
             samples[100], samples[189], samples[199]))
