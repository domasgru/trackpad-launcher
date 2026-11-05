// The settings column's layout with the form spanning the window's width, next to a notice padded 16 pt.
import AppKit
import SwiftUI

struct Column: View {
    var body: some View {
        VStack(spacing: 10) {
            Form {
                Section { Toggle("Animate app launch", isOn: .constant(true)).toggleStyle(.switch) }
                Section {
                    Picker("Thumb corner", selection: .constant(0)) {
                        Text("Top left").tag(0)
                        Text("Bottom right").tag(1)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .padding(.top, -20)
            .padding(.bottom, -24)
            .zIndex(-1)
            Text("A notice, 16 pt in from the window's edges, on the faintest fill.")
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(width: 326)
        .fixedSize(horizontal: true, vertical: false)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let hosting = NSHostingView(rootView: Column())
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: 200, y: 200), size: hosting.fittingSize), styleMask: [.titled],
    backing: .buffered, defer: false)
window.title = "FormWidthProbe"
window.contentView = hosting
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 8) { app.terminate(nil) }
app.run()
