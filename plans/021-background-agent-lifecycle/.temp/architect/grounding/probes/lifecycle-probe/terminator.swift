// Sends NSRunningApplication.terminate() (a polite quit Apple event) to every running copy of the probe,
// as a newer Trackpad Launcher would to an older one, and prints what came back.
import AppKit

let copies = NSRunningApplication.runningApplications(withBundleIdentifier: "com.domasgru.tl021probe")
print("terminator pid \(ProcessInfo.processInfo.processIdentifier): \(copies.count) running copies")
for copy in copies {
    let accepted = copy.terminate()
    print("terminate() pid \(copy.processIdentifier) -> \(accepted)")
}
RunLoop.main.run(until: Date().addingTimeInterval(1.5))
for copy in copies {
    print("after 1.5 s pid \(copy.processIdentifier) isTerminated=\(copy.isTerminated)")
}
