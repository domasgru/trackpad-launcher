// Probe (R13, R12): does NSRunningApplication.hide() reach a full-screen app on its own Space, what does it do to it,
// and does the app come back full-screen when opened again? Also logs every didActivateApplication push during the
// run, to see what a launch watch would hear (R12). Touches only Calculator and Chess; aborts if either runs; quits
// only what it opened; restores the original front app. Needs Accessibility (checked) to flip AXFullScreen.
import AppKit
import ApplicationServices

typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias CopyInfo = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?
let copyOrder = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationArrayInFrontToBackOrder"), to: CopyOrder.self)
let copyInfo = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationInformation"), to: CopyInfo.self)

let calcID = "com.apple.calculator", chessID = "com.apple.Chess"
let paths = [calcID: "/System/Applications/Calculator.app", chessID: "/System/Applications/Chess.app"]
let short = [calcID: "Calc", chessID: "Chess"]

func pump(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
func app(_ id: String) -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: id).first }
func order() -> [String] {
    guard let serials = copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
    return serials.compactMap { serial in
        let info = copyInfo(-2, serial, ["CFBundleIdentifier"] as CFArray)?.takeRetainedValue() as? [String: Any]
        return (info?["CFBundleIdentifier"] as? String).flatMap { short[$0] }
    }
}
func onScreenWindows(of pid: pid_t) -> Int {
    let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid && (($0[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0) == 0 }.count
}
func firstWindow(of pid: pid_t) -> AXUIElement? {
    let element = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(element, 1)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success else { return nil }
    return (value as? [AXUIElement])?.first
}
func isFullScreen(_ window: AXUIElement?) -> String {
    guard let window else { return "noWindow" }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success else { return "unreadable" }
    return (value as? Bool).map { $0 ? "fullScreen" : "windowed" } ?? "unreadable"
}
func report(_ label: String) {
    let states = [calcID, chessID].map { id -> String in
        guard let a = app(id) else { return "\(short[id]!)=gone" }
        return "\(short[id]!)=\(a.isHidden ? "hidden" : "shown")/onScreen:\(onScreenWindows(of: a.processIdentifier))/\(isFullScreen(firstWindow(of: a.processIdentifier)))"
    }.joined(separator: " ")
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.flatMap { short[$0] ?? "OTHER(\($0))" } ?? "nil"
    print("\(label): front=\(front) order=\(order()) \(states)")
}
func open(_ id: String) {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: paths[id]!), configuration: c)
}

let original = NSWorkspace.shared.frontmostApplication
for id in [calcID, chessID] where app(id) != nil { print("ABORT: \(id) already running"); exit(1) }

// R12's signal: every activation push, as a watch would hear it.
var activations: [String] = []
let observer = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
    let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    let name = a?.bundleIdentifier.flatMap { short[$0] ?? "OTHER(\($0))" } ?? "nil"
    activations.append(name)
    print("  didActivate: \(name)")
}

open(calcID); pump(2)
print("activations after opening Calc (launch): \(activations)"); activations = []
open(chessID); pump(2)
print("activations after opening Chess (launch): \(activations)"); activations = []
report("start")

// Chess into full screen (its own Space), from the Accessibility attribute.
guard let chess = app(chessID), let chessWindow = firstWindow(of: chess.processIdentifier) else { print("ABORT: no Chess window"); exit(1) }
let setFS = AXUIElementSetAttributeValue(chessWindow, "AXFullScreen" as CFString, kCFBooleanTrue)
print("set AXFullScreen on Chess:", setFS.rawValue)
pump(3)
report("Chess full screen, front")

// The user is in full-screen Chess and taps a gesture for Calc: open Calc, then hide Chess in the same turn.
open(calcID)
let answer = app(chessID)?.hide()
print("same turn: open Calc, Chess.hide() answered \(String(describing: answer))")
pump(2.5)
report("after open Calc + hide Chess (full screen) same turn")
print("activations: \(activations)"); activations = []

// Bring the hidden full-screen app back, as a gesture would (openApplication).
open(chessID); pump(3)
report("after open hidden Chess")
print("activations: \(activations)"); activations = []

// From Calc's Space, hide a full-screen app that is on another Space but not frontmost: open Calc first, let it land,
// then hide Chess (the didActivate-observer timing).
open(calcID); pump(2)
report("Calc front again, Chess full screen on its Space")
_ = app(chessID)?.hide(); pump(2)
report("after hiding Chess from Calc's Space")
open(chessID); pump(3)
report("after open hidden Chess again")
print("activations: \(activations)"); activations = []

// Leave full screen before quitting, so nothing is left in an odd state.
if let w = firstWindow(of: app(chessID)!.processIdentifier) { _ = AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, kCFBooleanFalse) }
pump(2.5)
report("Chess windowed again")

NSWorkspace.shared.notificationCenter.removeObserver(observer)
for id in [calcID, chessID] { app(id)?.terminate() }
pump(1.5)
original?.activate()
pump(0.5)
print("restored front:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")
