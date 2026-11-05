// Renders SwiftUI menu-picker variants in a window like the settings window's groups, then exits after a screenshot.
import AppKit
import SwiftUI

struct Variant: View {
    let name: String
    let picker: AnyView

    var body: some View {
        HStack(spacing: 16) {
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            picker
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 42)
        .background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))
    }
}

func picker(_ selection: Int) -> some View {
    Picker("Corner", selection: .constant(selection)) {
        Text("Top left").tag(0)
        Text("Bottom right").tag(1)
        Text("Top").tag(2)
    }
    .labelsHidden()
}

struct Probe: View {
    var body: some View {
        VStack(spacing: 6) {
            ForEach([0, 1, 2], id: \.self) { s in
                Variant(name: "G form, no margins \(s)", picker: AnyView(
                    Form { picker(s).pickerStyle(.menu) }.formStyle(.grouped).scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .contentMargins(0, for: .scrollContent)
                        .frame(width: 160, height: 40)))
                Variant(name: "H columns form \(s)", picker: AnyView(
                    Form { picker(s).pickerStyle(.menu) }.formStyle(.columns).fixedSize()))
            }
            Form {
                Picker("Thumb corner", selection: .constant(0)) {
                    Text("Top left").tag(0)
                    Text("Bottom right").tag(1)
                }
            }
            .formStyle(.grouped).scrollDisabled(true).frame(height: 80)
        }
        .padding(16)
        .frame(width: 380)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(
    contentRect: NSRect(x: 200, y: 200, width: 380, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
window.title = "SwiftUIPickerProbe"
window.contentView = NSHostingView(rootView: Probe())
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 8) { app.terminate(nil) }
app.run()
