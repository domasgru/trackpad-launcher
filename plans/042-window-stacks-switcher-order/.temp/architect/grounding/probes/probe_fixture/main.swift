// Probe A (fixture): what today's read lists for an app we control, in the states 042 depends on.
// 1. Normal: W1, W2 visible, W3 minimised, a floating utility panel and a plain titled panel.
// 2. Hidden (NSApp.hide): does AX still list the windows, does the CG on-screen list drop them, what would sort count?
// 3. Window numbers: are they reused after close (churn 40 windows), and is a newly opened window's number higher?
// 4. Stopped (SIGSTOP): how long does each call take under the 0.2 s process-wide timeout, which error comes back,
//    is _AXUIElementGetWindow an IPC call, and are concurrent reads of other apps delayed?
// Usage: probe_fixture <path to compiled fixture>. Terminates the fixture at the end whatever happens.
import AppKit
import ApplicationServices

setvbuf(stdout, nil, _IONBF, 0)
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)

let fixture = Process()
fixture.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
let toFixture = Pipe()
let fromFixture = Pipe()
fixture.standardInput = toFixture
fixture.standardOutput = fromFixture
try! fixture.run()
var stopped = false
atexit_b {}
func cleanup() {
    if stopped { kill(fixture.processIdentifier, SIGCONT) }
    if fixture.isRunning { fixture.terminate() }
}
signal(SIGINT) { _ in exit(1) }

var buffer = ""
func line() -> String {
    while true {
        if let range = buffer.range(of: "\n") {
            let found = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            return found
        }
        let data = fromFixture.fileHandleForReading.availableData
        if data.isEmpty { cleanup(); fatalError("fixture ended") }
        buffer += String(decoding: data, as: UTF8.self)
    }
}
func send(_ command: String) -> String {
    toFixture.fileHandleForWriting.write((command + "\n").data(using: .utf8)!)
    return line()
}
func pause(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

let ready = line()
print("fixture:", ready)
let pid = fixture.processIdentifier

func report(_ label: String) {
    let read = readAX(pid)
    let onScreen = cgList([.optionOnScreenOnly, .excludeDesktopElements], of: pid)
    let all = cgList([.optionAll, .excludeDesktopElements], of: pid)
    print("\n== \(label): AX error=\(read.error.rawValue) in \(ms(read.seconds))")
    for window in read.windows { print("  AX ", window) }
    print("  CG on-screen:", onScreen.map(\.number))
    print("  CG all:      ", all.map { "\($0.number)\($0.onScreen ? "*" : "")" }.joined(separator: " "), "(* = on screen)")
    let sorted = listed(read, onScreen: onScreen.map(\.number))
    print("  today's sort lists visible=\(sorted.visible) minimised=\(sorted.minimised) -> count \(sorted.visible.count + sorted.minimised.count)")
}

report("normal")
print("\nhide ->", send("hide"))
pause(1.0)
report("hidden")
print("\nunhide ->", send("unhide"))
pause(1.0)
report("unhidden")

// Window numbers across close and open.
print("\nclose W2 ->", send("close W2"))
let opened = send("open")
print("open ->", opened)
pause(0.5)
report("after closing W2 and opening a new window")
let churn = send("churn 40")
let numbers = churn.split(separator: " ")[1].split(separator: ",").compactMap { Int($0) }
let increasing = zip(numbers, numbers.dropFirst()).allSatisfy { $0 < $1 }
print("\nchurn of 40 windows: first=\(numbers.first!) last=\(numbers.last!) strictly increasing=\(increasing) distinct=\(Set(numbers).count)")

// Stopped app: per-call timings and errors.
let beforeStop = readAX(pid)
let element: AXUIElement? = {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success
    else { return nil }
    return (value as? [AXUIElement])?.first
}()
print("\nwindows before stop:", beforeStop.windows.count)
kill(pid, SIGSTOP)
stopped = true
pause(0.2)
let stoppedRead = readAX(pid, traceCalls: true)
print("== stopped: whole read \(ms(stoppedRead.seconds)), error=\(stoppedRead.error.rawValue)")
for (name, seconds, error) in stoppedRead.calls { print("  \(name): \(ms(seconds)) error=\(error.rawValue)") }
if let element {
    var number: CGWindowID = 0
    let t0 = now()
    let error = getWindow?(element, &number) ?? .failure
    print("  _AXUIElementGetWindow on a window element of the stopped app: \(ms(now() - t0)) error=\(error.rawValue) number=\(number)")
    var values: CFArray?
    let t1 = now()
    let multi = AXUIElementCopyMultipleAttributeValues(element, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
    let slots = (values as? [AnyObject])?.map { CFGetTypeID($0) == AXValueGetTypeID() ? "AXValue(error?)" : "\($0)" } ?? []
    print("  CopyMultipleAttributeValues on that element: \(ms(now() - t1)) return=\(multi.rawValue) slots=\(slots)")
}
let cg0 = now()
let stoppedCG = cgList([.optionOnScreenOnly, .excludeDesktopElements], of: pid)
print("  CG on-screen list while stopped: \(ms(now() - cg0)) -> \(stoppedCG.map(\.number))")

// Concurrent reads of other apps while one read is stuck on the stopped app.
let others = NSWorkspace.shared.runningApplications
    .filter { $0.activationPolicy == .regular && $0.processIdentifier != pid && $0.processIdentifier != getpid() }
    .prefix(6)
let group = DispatchGroup()
let lock = NSLock()
var lines: [String] = []
let start = now()
for app in [pid] + others.map(\.processIdentifier) {
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        let read = readAX(app)
        lock.lock()
        lines.append(String(format: "  pid %d finished at +%@ (own %@), error=%d, windows=%d", app, ms(now() - start), ms(read.seconds), read.error.rawValue, read.windows.count))
        lock.unlock()
        group.leave()
    }
}
group.wait()
print("== concurrent reads, the stopped fixture first, then \(others.count) other apps, one GCD block each:")
for line in lines { print(line) }

kill(pid, SIGCONT)
stopped = false
pause(0.3)
print("\nafter SIGCONT ->", send("quit"))
fixture.waitUntilExit()
print("fixture exited, status \(fixture.terminationStatus)")
