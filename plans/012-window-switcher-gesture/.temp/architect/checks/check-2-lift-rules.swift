// Check 2: do the design's `WindowStack.raises` and `WindowSwitcher.lift(now:)`, exactly as the plan specifies them,
// produce R10, R11 and R12's scenarios when run against a stack that behaves as AXRaise does (probe 2: a raised window
// moves to the front of its app; a raised minimised window is restored)? Pure; touches nothing.
// Run: swift check-2-lift-rules.swift

typealias W = String

/// The shortest front part of `target` that, raised back to front, leaves the app's windows in target order. The first
/// target window is part of it unless it already leads `current`; target windows not in `current`, other than the
/// first, are left out.
func raises(current: [W], target: [W]) -> [W] {
    guard !target.isEmpty else { return [] }
    let onScreen = Set(current)
    let start = current.first == target.first ? 0 : 1
    for k in start...target.count {
        let raised = Set(target.prefix(k))
        let rest = current.filter { target.contains($0) && !raised.contains($0) }
        let wanted = target.dropFirst(k).filter { onScreen.contains($0) }
        if rest == Array(wanted) { return Array(target.prefix(k)) }
    }
    return target
}

struct Stack {
    var visible: [W]          // front to back
    var minimised: [W]
    mutating func raise(_ frontToBack: [W]) {
        for w in frontToBack.reversed() {
            if let i = minimised.firstIndex(of: w) { minimised.remove(at: i) }
            else if let i = visible.firstIndex(of: w) { visible.remove(at: i) }
            else { continue }                                   // closed: skipped
            visible.insert(w, at: 0)
        }
    }
}

/// The switcher as fixed at begin: visible rows front to back, then minimised rows.
struct Switcher {
    let visibleRows: [W]
    let minimisedRows: [W]
    var selected = 0
    var rows: [W] { visibleRows + minimisedRows }
    var front: W? { visibleRows.first }
    var selectedVisible: W? { selected < visibleRows.count ? visibleRows[selected] : nil }

    func lift(now: Stack) -> (raises: [W], haptic: Bool) {
        let sel = rows[selected]
        let alive = Set(now.visible + now.minimised)
        guard alive.contains(sel) else {
            return ([], now.visible.first.map { $0 != front } ?? false)
        }
        let target = ([sel] + visibleRows.filter { $0 != sel }).filter(alive.contains)
        return (raises(current: now.visible, target: target), sel != front)
    }
}

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  " + detail))
    if !ok { failures += 1 }
}

/// Plays a window swipe: begin on `stack`, slide through `path` (row indices), optionally mutate mid-swipe, lift.
func play(_ start: Stack, path: [Int], midSwipe: (inout Stack) -> Void = { _ in }) -> (Stack, [W], Bool) {
    var stack = start
    var sw = Switcher(visibleRows: start.visible, minimisedRows: start.minimised)
    for row in path {
        sw.selected = row
        if let w = sw.selectedVisible { stack.raise([w]) }   // R10: raise while sliding, never a minimised one
    }
    midSwipe(&stack)
    let lift = sw.lift(now: stack)
    stack.raise(lift.raises)
    return (stack, lift.raises, lift.haptic)
}

let three = Stack(visible: ["Docs", "Mail", "News"], minimised: [])

// R11 toggle: slide to News, lift → News, Docs, Mail; haptic.
var r = play(three, path: [1, 2])
check("R11 toggle order", r.0.visible == ["News", "Docs", "Mail"], "\(r.0.visible)")
check("R11 toggle haptic", r.2)

// R10 live switch: one row down → Mail in front before the lift.
var live = three; live.raise(["Mail"])
check("R10 live switch", live.visible.first == "Mail", "\(live.visible)")

// R11 lift on the front window without moving → nothing raised, silent (R5 focus).
r = play(three, path: [])
check("R11 front, no slide: no raises", r.1.isEmpty, "\(r.1)")
check("R11 front, no slide: silent", !r.2)

// R10 slide back, then lift on the front window: order restored, silent.
r = play(three, path: [1, 2, 1, 0])
check("R10/R11 slide away and back: order restored", r.0.visible == ["Docs", "Mail", "News"], "\(r.0.visible)")
check("R10/R11 slide away and back: silent", !r.2)

// R11 selected window closes: no reordering; haptic only if the window in front is not the front window.
r = play(three, path: [1], midSwipe: { s in s.visible.removeAll { $0 == "Mail" } })
check("R11 closed selected: no raises", r.1.isEmpty, "\(r.1)")
check("R11 closed selected: order as it is", r.0.visible == ["Docs", "News"], "\(r.0.visible)")
check("R11 closed selected, Docs in front: silent", !r.2)
r = play(three, path: [1, 2], midSwipe: { s in s.visible.removeAll { $0 == "Mail" } })
check("R11 closed selected (Mail), News in front: haptic", r.2 && r.1.isEmpty, "\(r)")

// R11 lift on a minimised window: restored and in front; haptic. R10: not restored while sliding.
let withMin = Stack(visible: ["A", "B"], minimised: ["M"])
var slid = withMin
var sw = Switcher(visibleRows: withMin.visible, minimisedRows: withMin.minimised)
sw.selected = 2
if let w = sw.selectedVisible { slid.raise([w]) }
check("R10 passing a minimised window: stays minimised", slid.minimised == ["M"] && slid.visible == ["A", "B"])
r = play(withMin, path: [1, 2])
check("R11 lift on minimised: restored in front", r.0.visible.first == "M" && r.0.minimised.isEmpty, "\(r.0)")
check("R11 lift on minimised: order M, A, B", r.0.visible == ["M", "A", "B"], "\(r.0.visible)")
check("R11 lift on minimised: haptic", r.2)

// R11 every window minimised: lift on the first row restores it with the haptic.
let allMin = Stack(visible: [], minimised: ["X", "Y"])
r = play(allMin, path: [])
check("R11 all minimised: first restored", r.0.visible == ["X"] && r.0.minimised == ["Y"], "\(r.0)")
check("R11 all minimised: haptic", r.2)

// R13 one window: lift changes nothing, silent.
r = play(Stack(visible: ["Only"], minimised: []), path: [0])
check("R13 one window: nothing, silent", r.1.isEmpty && !r.2, "\(r)")

// Every listed window closed: silent.
r = play(three, path: [1], midSwipe: { s in s.visible = [] })
check("every window closed: silent", r.1.isEmpty && !r.2, "\(r)")

// A window opened in front mid-swipe: the selected window still ends in front (R11).
r = play(three, path: [1], midSwipe: { s in s.visible.insert("New", at: 0) })
check("opened mid-swipe: Mail ends in front", r.0.visible.first == "Mail", "\(r.0.visible)")
// The unlisted window (R3: not added) stays just behind the selected one; the listed windows keep R11's order among
// themselves. Pushing it behind every listed window would raise them all, even on a lift on the front window.
check("opened mid-swipe: order Mail, New, Docs, News", r.0.visible == ["Mail", "New", "Docs", "News"], "\(r.0.visible)")
r = play(three, path: [], midSwipe: { s in s.visible.insert("New", at: 0) })
check("opened mid-swipe, lift on front: Docs back in front, silent", r.0.visible.first == "Docs" && !r.2, "\(r)")

// A later minimised window is never restored by the lift.
r = play(Stack(visible: ["A", "B"], minimised: ["M"]), path: [1])
check("later minimised never restored", r.0.minimised == ["M"], "\(r.0)")

print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
