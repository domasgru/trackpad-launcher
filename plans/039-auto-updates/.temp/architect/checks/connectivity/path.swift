// When an NWPathMonitor starts, does it report the present reading at once, unasked?
// The two candidates differ on arming a retry after a failed check: one needs this reading to close
// the race where the path came up before the watch armed. Toggles nothing on this Mac.
import Foundation
import Network

let started = ContinuousClock.now
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    print("reading after \(ContinuousClock.now - started): status=\(path.status) interfaces=\(path.availableInterfaces.map(\.type))")
}
monitor.start(queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    monitor.cancel()
    print("done, cancelled")
    exit(0)
}
dispatchMain()
