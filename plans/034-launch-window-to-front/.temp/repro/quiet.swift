// Waits until another project's UI tests stop raising their app, so a harness run measures only this app. It reads the
// running apps and touches nothing. Exits 0 once no app named with `name` has run for `quietSeconds`, 1 at `limitSeconds`.
// usage: quiet <name> <quietSeconds> <limitSeconds>
import AppKit
import Foundation

let args = CommandLine.arguments
let name = args[1]
let quietSeconds = Double(args[2])!
let limitSeconds = Double(args[3])!
let start = Date()
var quietSince = Date()

while Date().timeIntervalSince(start) < limitSeconds {
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    let running = NSWorkspace.shared.runningApplications.contains { $0.localizedName?.contains(name) == true }
    if running { quietSince = Date() }
    if Date().timeIntervalSince(quietSince) >= quietSeconds {
        print("quiet after \(Int(Date().timeIntervalSince(start))) s")
        exit(0)
    }
}
print("still running after \(Int(limitSeconds)) s")
exit(1)
