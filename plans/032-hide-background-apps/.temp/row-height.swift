// Measures one settings-form row by the height it adds to a grouped Form, as the real form lays it out: the row as the
// switch has it, the row as Animate app launch has it, and the thumb corner row's shape.
import AppKit
import SwiftUI

@MainActor func height<Row: View>(rows count: Int, @ViewBuilder _ row: () -> Row) -> CGFloat {
    let content = row()
    let form = Form { Section { ForEach(0..<count, id: \.self) { _ in content } } }
        .formStyle(.grouped).scrollDisabled(true).frame(width: 326)
    let host = NSHostingView(rootView: form)
    host.frame = NSRect(x: 0, y: 0, width: 326, height: 900)
    host.layoutSubtreeIfNeeded()
    return host.fittingSize.height
}

@MainActor func rowHeight<Row: View>(@ViewBuilder _ row: () -> Row) -> CGFloat {
    let view = row()
    return height(rows: 3) { view } - height(rows: 2) { view }
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    print("plain Toggle (the switch today):", rowHeight { Toggle("Hide background apps", isOn: .constant(true)).toggleStyle(.switch) })
    print("Toggle with 26 pt label (Animate app launch):", rowHeight {
        Toggle(isOn: .constant(true)) { Text("Animate app launch").frame(height: 26) }.toggleStyle(.switch)
    })
    print("Picker with 26 pt label (thumb corner):", rowHeight {
        Picker(selection: .constant(0)) { Text("Top left").tag(0) } label: { Text("Thumb corner").frame(height: 26) }.pickerStyle(.menu)
    })
}
