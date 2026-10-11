// Probe (post-fan-out check for R22): does a SwiftUI ScrollView with layoutPriority(-1), inside a VStack whose root is
// fixedSize(horizontal: true, vertical: false), (a) report its full content height to NSHostingView.fittingSize, and
// (b) absorb the whole deficit when the hosting view's frame is capped below that height, leaving the fixed siblings
// at their natural heights? Candidate 1 rests R22 on this; candidate 2 instead hands the view an observable cap.
import AppKit
import SwiftUI

struct Heights: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func measured(_ name: String) -> some View {
        background(GeometryReader { g in Color.clear.preference(key: Heights.self, value: [name: g.size.height]) })
    }
}

struct Probe: View {
    let rows: Int
    let report: ([String: CGFloat]) -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text("Header").frame(height: 40).measured("header")
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { i in Text("Row \(i)").frame(height: 24) }
                }
            }
            .layoutPriority(-1)
            .measured("list")
            Text("Footer").frame(height: 40).measured("footer")
        }
        .padding(16)
        .frame(width: 266)
        .fixedSize(horizontal: true, vertical: false)
        .onPreferenceChange(Heights.self) { report($0) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let rows = 30
let expectedFull = 16.0 + 40 + 12 + Double(rows) * 24 + 12 + 40 + 16
var latest: [String: CGFloat] = [:]
let hosting = NSHostingView(rootView: Probe(rows: rows) { latest = $0 })
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 266, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = hosting

let fitting = hosting.fittingSize
print("rows=\(rows) expected natural height=\(expectedFull) fittingSize=\(fitting)")
print("(a) fittingSize reports the full content height:", abs(Double(fitting.height) - expectedFull) < 1)

for cap in [400.0, 300.0] {
    window.setContentSize(NSSize(width: fitting.width, height: cap))
    hosting.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    let fixed = 16.0 + 40 + 12 + 12 + 40 + 16
    print("cap=\(cap) measured=\(latest.sorted(by: { $0.key < $1.key })) expected list=\(cap - fixed)")
    let ok = latest["header"] == 40 && latest["footer"] == 40 && abs(Double(latest["list"] ?? -1) - (cap - fixed)) < 1
    print("(b) at cap \(cap) the list alone absorbs the deficit:", ok)
}
print("done")
