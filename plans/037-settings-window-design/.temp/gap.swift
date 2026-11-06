// Probe: how far is a setting row's title from the row's leading edge today, with the HStack's default spacing after
// the 45 pt illustration, inside a grouped Form's Toggle? Prints the title's leading edge in the row's coordinates.
// Run: swift gap.swift
import AppKit
import SwiftUI

struct Row: View {
    var body: some View {
        Form {
            Section {
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Color(white: 0.9).frame(width: 45, height: 28)
                        Text("Switch windows")
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.onAppear {
                                        let frame = geometry.frame(in: .named("row"))
                                        print("default spacing: title leading edge at \(frame.minX) pt, so the gap is \(frame.minX - 45) pt")
                                    }
                                })
                    }
                    .frame(height: 26)
                    .coordinateSpace(name: "row")
                }
                .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 326)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let hosting = NSHostingView(rootView: Row())
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: 200, y: 200), size: NSSize(width: 326, height: 100)),
    styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = hosting
window.setContentSize(hosting.fittingSize)
window.orderFrontRegardless()
DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
app.run()
