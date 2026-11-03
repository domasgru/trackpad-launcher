// Helper for relaunch.sh.
//   swap <destination> <staged>        FileManager.replaceItemAt(destination, withItemAt: staged)
//   open <app> <new-instance: 0|1>     NSWorkspace.openApplication(at:) and print the pid it answers with
import AppKit

let args = CommandLine.arguments
switch args[1] {
case "swap":
    _ = try FileManager.default.replaceItemAt(URL(filePath: args[2]), withItemAt: URL(filePath: args[3]))
    print("swapped")
case "open":
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = args[3] == "1"
    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: URL(filePath: args[2]), configuration: configuration) { app, error in
        print("openApplication answered pid=\(app.map { String($0.processIdentifier) } ?? "nil") error=\(error.map { "\($0)" } ?? "nil")")
        done.signal()
    }
    done.wait()
default:
    break
}
