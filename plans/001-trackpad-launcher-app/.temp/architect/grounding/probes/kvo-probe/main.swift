// Probe: does KVO on UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad") fire when another
// process writes that domain through cfprefsd (as `defaults` and System Settings do)?
// Shows false if no KVO callback arrives after `defaults write` / `defaults delete` of a probe key.
// Leaves the machine as found: the probe key is deleted again and never touches a real setting.
import Foundation

let domain = "com.apple.AppleMultitouchTrackpad"
let key = "TLProbeKey"
let suite = UserDefaults(suiteName: domain)!
print("Clicking (read via suite) = \(String(describing: suite.object(forKey: "Clicking")))")
print("TrackpadThreeFingerTapGesture = \(String(describing: suite.object(forKey: "TrackpadThreeFingerTapGesture")))")
print("CFPreferencesCopyAppValue Clicking = \(String(describing: CFPreferencesCopyAppValue("Clicking" as CFString, domain as CFString)))")

final class Observer: NSObject {
    var hits: [String] = []
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let s = "KVO \(keyPath ?? "?") old=\(String(describing: change?[.oldKey])) new=\(String(describing: change?[.newKey])) main=\(Thread.isMainThread)"
        hits.append(s); print(s)
    }
}
let obs = Observer()
suite.addObserver(obs, forKeyPath: key, options: [.old, .new], context: nil)
suite.addObserver(obs, forKeyPath: "Clicking", options: [.old, .new], context: nil)
var notif = 0
let token = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { n in
    notif += 1; print("UserDefaults.didChangeNotification object=\(String(describing: (n.object as? UserDefaults).map { ObjectIdentifier($0) == ObjectIdentifier(suite) ? "suite" : "other" }))")
}
func defaults(_ args: [String]) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults"); p.arguments = args
    try! p.run(); p.waitUntilExit(); print("ran defaults \(args.joined(separator: " ")) -> \(p.terminationStatus)")
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1) { defaults(["write", domain, key, "-int", "1"]) }
DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { defaults(["delete", domain, key]) }
RunLoop.main.run(until: Date().addingTimeInterval(4))
print("hits=\(obs.hits.count) didChangeNotifications=\(notif)")
print("after cleanup, suite value for \(key) = \(String(describing: suite.object(forKey: key)))")
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults"); p.arguments = ["read", domain, key]
let pipe = Pipe(); p.standardError = pipe; p.standardOutput = pipe; try! p.run(); p.waitUntilExit()
print("defaults read \(key) exit=\(p.terminationStatus) (1 = key absent, machine as found)")
suite.removeObserver(obs, forKeyPath: key); suite.removeObserver(obs, forKeyPath: "Clicking")
NotificationCenter.default.removeObserver(token)
