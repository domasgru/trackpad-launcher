// Check 1 (after fan-out): two claims a candidate rests on.
// (a) A per-element messaging timeout set on a GCD thread caps that call at the budget there too, with other apps read
//     on other GCD threads at the same moment unaffected.
// (b) One CGWindowListCopyWindowInfo(optionAll) copy, filtered to a pid's on-screen layer-0 windows, gives the same
//     front-to-back order as the optionOnScreenOnly copy, for every regular app, over 20 samples.
// Usage: probe_offmain_budget <path to compiled fixture>. Resumes and terminates the fixture at the end.
import AppKit
import ApplicationServices

setvbuf(stdout, nil, _IONBF, 0)
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)

let fixture = Process()
fixture.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fromFixture = Pipe()
fixture.standardInput = Pipe()
fixture.standardOutput = fromFixture
try! fixture.run()
var text = ""
while !text.contains("\n") { text += String(decoding: fromFixture.fileHandleForReading.availableData, as: UTF8.self) }
let pid = fixture.processIdentifier
let others = NSWorkspace.shared.runningApplications
    .filter { $0.activationPolicy == .regular && $0.processIdentifier != pid && $0.processIdentifier != getpid() }
    .map(\.processIdentifier)
for other in others { _ = readAX(other) }   // warm them, so their times are warm times
kill(pid, SIGSTOP)
RunLoop.current.run(until: Date().addingTimeInterval(0.2))

print("== (a) budgets set on GCD threads, the stopped fixture with 0.06 s per call, \(others.count) other apps at once")
let group = DispatchGroup()
let lock = NSLock()
var lines: [String] = []
let start = now()
group.enter()
DispatchQueue.global(qos: .userInteractive).async {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.06)
    var value: CFTypeRef?
    let t0 = now()
    let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    lock.lock(); lines.append("  stopped fixture: \(ms(now() - t0)) error=\(error.rawValue), done at +\(ms(now() - start))"); lock.unlock()
    group.leave()
}
for other in others {
    group.enter()
    DispatchQueue.global(qos: .userInteractive).async {
        let read = readAX(other)
        lock.lock(); lines.append("  pid \(other): \(ms(read.seconds)) error=\(read.error.rawValue), done at +\(ms(now() - start))"); lock.unlock()
        group.leave()
    }
}
group.wait()
for line in lines.sorted() { print(line) }
kill(pid, SIGCONT)
RunLoop.current.run(until: Date().addingTimeInterval(0.3))

print("\n== (b) optionAll's on-screen subset against optionOnScreenOnly, per regular app, 20 samples")
var compared = 0
var differ = 0
for _ in 0..<20 {
    let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    func numbers(_ list: [[String: Any]], _ pid: pid_t, onScreenOnly: Bool) -> [UInt32] {
        list.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                !onScreenOnly || ((info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false)
            else { return nil }
            return (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        }
    }
    for other in others + [pid] {
        let a = numbers(all, other, onScreenOnly: true)
        let b = numbers(onScreen, other, onScreenOnly: false)
        compared += 1
        if a != b { differ += 1; print("  pid \(other): optionAll on-screen \(a) vs onScreenOnly \(b)") }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}
print("  compared \(compared) (app, sample) pairs; \(differ) differ")
let c0 = now()
for _ in 0..<20 { _ = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) }
print("  one optionAll copy (warm): \(ms((now() - c0) / 20))")
print("  the fixture's on-screen order: \(cgList([.optionOnScreenOnly, .excludeDesktopElements], of: pid).map(\.number))")
fixture.terminate()
fixture.waitUntilExit()
print("fixture ended")
