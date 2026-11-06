// Probe: does a process-exit dispatch source report a process that died before the source registered, or an unknown pid?
// `stop` activates its sources on the main queue, so a copy can be gone by the time one registers.
// Run: swift exit-source.swift
import Foundation

func spawnShortLived() -> pid_t {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/true")
    try! process.run()
    process.waitUntilExit()
    return process.processIdentifier
}

func watch(_ pid: pid_t, _ label: String) -> DispatchSourceProcess {
    let began = Date()
    let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
    source.setEventHandler { print("\(label): exit reported after \(Date().timeIntervalSince(began)) s") }
    source.activate()
    return source
}

let reaped = watch(spawnShortLived(), "already exited and reaped")
let unknown = watch(99_999, "pid that never existed")
let sleeper = Process()
sleeper.executableURL = URL(filePath: "/bin/sleep")
sleeper.arguments = ["30"]
try! sleeper.run()
let live = watch(sleeper.processIdentifier, "live, killed after activation")
kill(sleeper.processIdentifier, SIGKILL)

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    print("done")
    exit(0)
}
dispatchMain()
