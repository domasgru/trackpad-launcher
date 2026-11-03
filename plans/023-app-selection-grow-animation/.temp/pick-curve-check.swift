import Foundation

struct Pick {
    var start = 0.4, peak = 1.1, grow = 0.2, settle = 0.15
    var duration: Double { grow + settle }
    func scale(at t: Double) -> Double {
        if t <= 0 { return start }
        if t < grow {
            let p = t / grow
            return start + (peak - start) * (1 - (1 - p) * (1 - p))
        }
        if t < grow + settle {
            let q = (t - grow) / settle
            return peak + (1 - peak) * (3 * q * q - 2 * q * q * q)
        }
        return 1
    }
}

let p = Pick()
let steps = Int((p.duration * 240).rounded())
print("steps", steps)
let samples = (0...steps).map { i in
    (t: Double(i) / Double(steps) * p.duration, s: p.scale(at: Double(i) / Double(steps) * p.duration))
}
print("first", samples[0], "at0.2", samples.first { abs($0.t - 0.2) < 1e-9 }!, "last", samples.last!)
print("max", samples.max { $0.s < $1.s }!)
print("half-grow", p.scale(at: 0.1), "share", (p.scale(at: 0.1) - 0.4) / 0.7)
let up = samples.filter { $0.t <= 0.2 + 1e-9 }
let down = samples.filter { $0.t >= 0.2 - 1e-9 }
print("monotone up", zip(up, up.dropFirst()).allSatisfy { $1.s > $0.s },
      "monotone down", zip(down, down.dropFirst()).allSatisfy { $1.s < $0.s })
print("never below 1 after peak", down.allSatisfy { $0.s >= 1 - 1e-12 })
var slow = p
slow.grow = 0.5
let s2 = Int((slow.duration * 240).rounded())
let ss = (0...s2).map { i in
    (t: Double(i) / Double(s2) * slow.duration, s: slow.scale(at: Double(i) / Double(s2) * slow.duration))
}
print("slow grow peak at", ss.max { $0.s < $1.s }!, "duration", slow.duration)
