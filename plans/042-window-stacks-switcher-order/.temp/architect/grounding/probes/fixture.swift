// Fixture app for the 042 probes: a regular app whose windows the probes control.
// On launch: windows W1, W2, W3 (W3 minimised), a floating utility panel "Utility" and a plain titled panel "PlainPanel".
// Commands on stdin, one per line: hide, unhide, open, close <title>, churn <k>, quit.
// Every answer is one line on stdout. It never activates itself, so it never takes the user's focus.
import AppKit

final class Fixture: NSObject, NSApplicationDelegate {
    var windows: [String: NSWindow] = [:]
    var opened = 3

    func say(_ line: String) {
        FileHandle.standardOutput.write((line + "\n").data(using: .utf8)!)
    }

    func makeWindow(_ title: String, at index: Int) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 40 + index * 30, y: 40 + index * 30, width: 220, height: 120),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        windows[title] = window
        return window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for (index, title) in ["W1", "W2", "W3"].enumerated() { _ = makeWindow(title, at: index) }
        let utility = NSPanel(
            contentRect: NSRect(x: 300, y: 40, width: 160, height: 100),
            styleMask: [.titled, .utilityWindow, .closable], backing: .buffered, defer: false)
        utility.title = "Utility"
        utility.isFloatingPanel = true
        utility.hidesOnDeactivate = false
        utility.orderFrontRegardless()
        windows["Utility"] = utility
        let plain = NSPanel(
            contentRect: NSRect(x: 300, y: 200, width: 160, height: 100),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        plain.title = "PlainPanel"
        plain.hidesOnDeactivate = false
        plain.orderFrontRegardless()
        windows["PlainPanel"] = plain
        windows["W3"]?.miniaturize(nil)
        FileHandle.standardInput.readabilityHandler = { handle in
            let text = String(decoding: handle.availableData, as: UTF8.self)
            DispatchQueue.main.async { for line in text.split(separator: "\n") { self.handle(String(line)) } }
        }
        // Give the minimise animation time to finish before reporting ready.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let numbers = ["W1", "W2", "W3", "Utility", "PlainPanel"].map { "\($0)=\(self.windows[$0]!.windowNumber)" }
            self.say("ready pid=\(ProcessInfo.processInfo.processIdentifier) " + numbers.joined(separator: " "))
        }
    }

    func handle(_ line: String) {
        let parts = line.split(separator: " ").map(String.init)
        switch parts.first {
        case "hide": NSApp.hide(nil); say("hidden=\(NSApp.isHidden)")
        case "unhide": NSApp.unhideWithoutActivation(); say("hidden=\(NSApp.isHidden)")
        case "open":
            opened += 1
            let window = makeWindow("W\(opened)", at: opened)
            say("opened W\(opened)=\(window.windowNumber)")
        case "close":
            windows[parts[1]]?.close()
            windows[parts[1]] = nil
            say("closed \(parts[1])")
        case "churn":
            var numbers: [Int] = []
            for _ in 0..<Int(parts[1])! {
                let window = NSWindow(
                    contentRect: NSRect(x: 600, y: 40, width: 100, height: 80),
                    styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.orderFrontRegardless()
                numbers.append(window.windowNumber)
                window.orderOut(nil)
                window.close()
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            say("churn " + numbers.map(String.init).joined(separator: ","))
        case "quit": say("bye"); exit(0)
        default: say("unknown \(line)")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Fixture()
app.delegate = delegate
app.run()
