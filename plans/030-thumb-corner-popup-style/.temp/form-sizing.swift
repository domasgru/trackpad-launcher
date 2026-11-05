// Does a grouped Form inside the settings column's VStack report its content height through fittingSize?
import AppKit
import SwiftUI

func form(rows: Int) -> some View {
    Form {
        Section { ForEach(0..<rows, id: \.self) { Toggle("Row \($0)", isOn: .constant(true)) } }
        Section { Picker("Thumb corner", selection: .constant(0)) { Text("Top left").tag(0) } }
    }
    .formStyle(.grouped)
}

func column(_ content: some View) -> some View {
    VStack(spacing: 10) {
        content
        Text("After the form")
    }
    .frame(width: 326)
    .fixedSize(horizontal: true, vertical: false)
}

let app = NSApplication.shared
for rows in [2, 6] {
    let plain = NSHostingView(rootView: column(form(rows: rows)))
    let fixed = NSHostingView(rootView: column(form(rows: rows).fixedSize(horizontal: false, vertical: true)))
    let disabled = NSHostingView(
        rootView: column(form(rows: rows).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)))
    print("rows \(rows): plain \(plain.fittingSize) fixed \(fixed.fittingSize) scrollDisabled+fixed \(disabled.fittingSize)")
}
