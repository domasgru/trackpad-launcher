// Probe: while a trackpad press is withheld, which treatment of its drags keeps the cursor still?
//
// Every phase drops presses and releases at a session tap, as the click tap does for a withheld press, so nothing
// under the cursor is clicked. Phases differ only in what happens to the press's drags:
//   move      session tap rewrites drags to mouseMoved (what the app ships today)
//   drop      session tap drops drags
//   hid-drop  HID tap drops drags
//   unlink    session tap drops drags, and CGAssociateMouseAndMouseCursorPosition(0) for the phase
// Per phase it prints the drags seen and how far the cursor got from where the phase started (sampled on every drag
// and at the end). Run it, then in each phase press the trackpad with two fingers and slide them while holding.
// Leaves nothing behind: taps invalidated, association restored.

import ApplicationServices
import Foundation

let dragTypes: [CGEventType] = [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
let pressTypes: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
func mask(_ types: [CGEventType]) -> CGEventMask { types.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) } }

enum DragMode: Int { case move, drop, pass }

nonisolated(unsafe) var mode = DragMode.pass
nonisolated(unsafe) var drags = 0
nonisolated(unsafe) var presses = 0
nonisolated(unsafe) var start = CGPoint.zero
nonisolated(unsafe) var farthest = 0.0

func cursor() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
func note() { let p = cursor(); farthest = max(farthest, hypot(p.x - start.x, p.y - start.y)) }

let pressCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return .passUnretained(event) }
    presses += 1
    return nil
}
let dragCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return .passUnretained(event) }
    drags += 1
    note()
    switch mode {
    case .pass: return .passUnretained(event)
    case .drop: return nil
    case .move:
        event.type = .mouseMoved
        return .passUnretained(event)
    }
}

func tap(_ location: CGEventTapLocation, _ types: [CGEventType], _ callback: CGEventTapCallBack) -> CFMachPort {
    guard let port = CGEvent.tapCreate(tap: location, place: .headInsertEventTap, options: .defaultTap,
                                       eventsOfInterest: mask(types), callback: callback, userInfo: nil)
    else { fatalError("tapCreate failed at \(location): no Accessibility for this process?") }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
    return port
}

func say(_ text: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    p.arguments = [text]
    try? p.run()
}

print("AXIsProcessTrusted: \(AXIsProcessTrusted())")
let presses0 = tap(.cgSessionEventTap, pressTypes, pressCallback)
let sessionDrags = tap(.cgSessionEventTap, dragTypes, dragCallback)
let hidDrags = tap(.cghidEventTap, dragTypes, dragCallback)

let seconds = Double(CommandLine.arguments.dropFirst().first ?? "") ?? 8
let phases: [(name: String, session: DragMode?, hid: DragMode?, unlink: Bool)] = [
    ("move", .move, nil, false),
    ("drop", .drop, nil, false),
    ("hid-drop", nil, .drop, false),
    ("unlink", .drop, nil, true),
]

func run(_ index: Int) {
    guard index < phases.count else {
        for port in [presses0, sessionDrags, hidDrags] { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        CGAssociateMouseAndMouseCursorPosition(1)
        say("done")
        print("done")
        exit(0)
    }
    let phase = phases[index]
    CGEvent.tapEnable(tap: sessionDrags, enable: phase.session != nil)
    CGEvent.tapEnable(tap: hidDrags, enable: phase.hid != nil)
    mode = phase.session ?? phase.hid ?? .pass
    CGAssociateMouseAndMouseCursorPosition(phase.unlink ? 0 : 1)
    drags = 0; presses = 0; farthest = 0; start = cursor()
    say("phase \(index + 1), press and slide")
    print("phase \(index + 1) \(phase.name): press with two fingers and slide while holding, \(Int(seconds)) s")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        note()
        let end = cursor()
        print(String(format: "  %@: presses %d, drags %d, farthest %.0f pt, end offset (%.0f, %.0f)",
                     phase.name, presses, drags, farthest, end.x - start.x, end.y - start.y))
        CGAssociateMouseAndMouseCursorPosition(1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { run(index + 1) }
    }
}

run(0)
CFRunLoopRun()
