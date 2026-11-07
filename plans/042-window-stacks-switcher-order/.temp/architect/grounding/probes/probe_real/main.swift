// Probe B (real apps, read only): today's read against every regular running app.
// 1. Cold then warm: each app's whole read on the main thread, first call from this process and then 5 more rounds.
// 2. Concurrent: all apps at once, one GCD block each, while the main thread reads them too; 10 rounds.
//    Do the results equal the serial ones, and how long until the last app answers?
// 3. Concurrent on the Swift cooperative pool (a task group), same comparison.
// 4. Per app: windows AX lists that are neither on screen nor minimised, and the app's hidden state, to see what
//    today's sort drops (other Spaces, hidden apps, off-screen helpers).
// Usage: probe_real. Changes nothing: only AX attribute reads and CG window list copies.
import AppKit
import ApplicationServices

setvbuf(stdout, nil, _IONBF, 0)
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)

let apps = NSWorkspace.shared.runningApplications
    .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
let names = Dictionary(uniqueKeysWithValues: apps.map { ($0.processIdentifier, $0.localizedName ?? "?") })
let pids = apps.map(\.processIdentifier)
print("regular apps: \(apps.count); frontmost: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "none")")

struct Outcome: Equatable { let error: Int32; let visible: [UInt32]; let minimised: [UInt32] }
func outcome(_ pid: pid_t) -> (Outcome, Double) {
    let read = readAX(pid)
    let sorted = listed(read, onScreen: cgList([.optionOnScreenOnly, .excludeDesktopElements], of: pid).map(\.number))
    return (Outcome(error: read.error.rawValue, visible: sorted.visible, minimised: sorted.minimised), read.seconds)
}

// 1. Serial on the main thread, cold first.
var baseline: [pid_t: Outcome] = [:]
var cold: [pid_t: Double] = [:]
var warm: [pid_t: [Double]] = [:]
for pid in pids {
    let (result, seconds) = outcome(pid)
    baseline[pid] = result
    cold[pid] = seconds
}
for _ in 0..<5 { for pid in pids { warm[pid, default: []].append(outcome(pid).1) } }
print("\n== 1. serial on main: per app, first read (cold) and median of 5 warm reads; AX read only, CG list excluded")
var coldTotal = 0.0
var warmTotal = 0.0
for pid in pids {
    let sorted = warm[pid]!.sorted()
    coldTotal += cold[pid]!
    warmTotal += sorted[2]
    let result = baseline[pid]!
    print(String(format: "  %-28@ cold %@  warm %@  error=%d  listed=%d (visible %d, minimised %d)",
        names[pid]! as NSString, ms(cold[pid]!), ms(sorted[2]), result.error, result.visible.count + result.minimised.count,
        result.visible.count, result.minimised.count))
}
print("  sum over apps: cold \(ms(coldTotal)), warm \(ms(warmTotal))")
let cg0 = now()
for _ in 0..<10 { _ = cgList([.optionOnScreenOnly, .excludeDesktopElements], of: 0) }
print("  one CG on-screen copy (warm): \(ms((now() - cg0) / 10))")

// 2. Concurrent on GCD, with the main thread reading at the same time.
print("\n== 2. concurrent, one GCD block per app, main thread reading every app at the same time; 10 rounds")
var mismatches = 0
var lastAnswers: [Double] = []
for _ in 0..<10 {
    let group = DispatchGroup()
    let lock = NSLock()
    var results: [pid_t: Outcome] = [:]
    var latest = 0.0
    let start = now()
    for pid in pids {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let (result, _) = outcome(pid)
            let at = now() - start
            lock.lock(); results[pid] = result; latest = max(latest, at); lock.unlock()
            group.leave()
        }
    }
    for pid in pids where outcome(pid).0 != baseline[pid]! { mismatches += 1 }
    group.wait()
    lastAnswers.append(latest)
    for pid in pids where results[pid] != baseline[pid] { mismatches += 1 }
}
print("  mismatches against the serial baseline: \(mismatches) (main-thread and GCD reads, \(10 * 2 * pids.count) reads)")
print("  last app answered at: min \(ms(lastAnswers.min()!)), max \(ms(lastAnswers.max()!))")

// 3. Concurrent on the cooperative pool.
print("\n== 3. concurrent, a task group (cooperative pool), 10 rounds")
let semaphore = DispatchSemaphore(value: 0)
Task.detached {
    var poolMismatches = 0
    var latestAnswers: [Double] = []
    for _ in 0..<10 {
        let start = now()
        let results = await withTaskGroup(of: (pid_t, Outcome, Double).self) { group in
            for pid in pids { group.addTask { let (result, _) = outcome(pid); return (pid, result, now() - start) } }
            var all: [(pid_t, Outcome, Double)] = []
            for await item in group { all.append(item) }
            return all
        }
        latestAnswers.append(results.map(\.2).max() ?? 0)
        poolMismatches += results.filter { baseline[$0.0] != $0.1 }.count
    }
    print("  mismatches: \(poolMismatches); last app answered at: min \(ms(latestAnswers.min()!)), max \(ms(latestAnswers.max()!))")
    semaphore.signal()
}
semaphore.wait()

// 4. What today's sort drops, per app.
print("\n== 4. windows AX lists that today's sort drops (not on screen and not minimised), and hidden apps")
for app in apps {
    let pid = app.processIdentifier
    let read = readAX(pid)
    let onScreen = Set(cgList([.optionOnScreenOnly, .excludeDesktopElements], of: pid).map(\.number))
    let all = Set(cgList([.optionAll, .excludeDesktopElements], of: pid).map(\.number))
    let dropped = read.windows.filter { window in
        guard let number = window.number else { return true }
        return !window.minimised && !onScreen.contains(number)
    }
    let offScreenCG = all.subtracting(onScreen).subtracting(read.windows.compactMap(\.number))
    if app.isHidden || !dropped.isEmpty {
        print("  \(app.localizedName ?? "?") hidden=\(app.isHidden):")
        for window in dropped { print("    dropped AX \(window) inCGAll=\(window.number.map(all.contains) ?? false)") }
        print("    CG-only off-screen layer-0 windows AX does not list: \(offScreenCG.count)")
    }
}
print("\nsubroles seen across all apps (visible, not minimised):")
var subroles: [String: Int] = [:]
for pid in pids { for window in readAX(pid).windows where !window.minimised { subroles["\(window.role ?? "-")/\(window.subrole ?? "-")", default: 0] += 1 } }
for (subrole, count) in subroles.sorted(by: { $0.key < $1.key }) { print("  \(subrole): \(count)") }
