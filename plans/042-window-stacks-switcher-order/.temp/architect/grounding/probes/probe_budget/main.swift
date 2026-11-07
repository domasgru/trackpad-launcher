// Probe D: can one read of an app be held to a total budget with per-element messaging timeouts?
// With the fixture stopped (SIGSTOP), and the process-wide timeout at 0.2 s:
// 1. AXUIElementSetMessagingTimeout(appElement, 0.05) then kAXWindows: does it return after about 50 ms?
// 2. The same on a window element obtained before the stop, for CopyMultipleAttributeValues and _AXUIElementGetWindow.
// 3. Does a fresh app element for the same pid still use the process-wide 0.2 s?
// Usage: probe_budget <path to compiled fixture>. Resumes and terminates the fixture at the end.
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
print("fixture:", text.trimmingCharacters(in: .newlines))
let pid = fixture.processIdentifier

let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
_ = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
let window = (value as? [AXUIElement])?.first
kill(pid, SIGSTOP)
RunLoop.current.run(until: Date().addingTimeInterval(0.2))

func timed(_ label: String, _ body: () -> AXError) {
    let start = now()
    let error = body()
    print("  \(label): \(ms(now() - start)) error=\(error.rawValue)")
}
print("== stopped fixture")
AXUIElementSetMessagingTimeout(app, 0.05)
timed("kAXWindows on the app element with its own 0.05 s timeout") {
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
}
if let window {
    AXUIElementSetMessagingTimeout(window, 0.03)
    timed("CopyMultipleAttributeValues on a window element with 0.03 s") {
        var values: CFArray?
        return AXUIElementCopyMultipleAttributeValues(window, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
    }
    timed("_AXUIElementGetWindow on that window element with 0.03 s") {
        var number: CGWindowID = 0
        return getWindow?(window, &number) ?? .failure
    }
}
let fresh = AXUIElementCreateApplication(pid)
timed("kAXWindows on a fresh app element for the same pid (process-wide 0.2 s)") {
    AXUIElementCopyAttributeValue(fresh, kAXWindowsAttribute as CFString, &value)
}
kill(pid, SIGCONT)
fixture.terminate()
fixture.waitUntilExit()
print("fixture ended")
