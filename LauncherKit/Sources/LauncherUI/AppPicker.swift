import AppKit
import LauncherCore
import SwiftUI

/// A gesture row's app picker: the system pop-up button, 132 pt wide. It shows the row's app and checks it in the
/// menu; the menu ends in Other… and None. An app picked through Other… from outside the list, and a missing app, show
/// in the button without joining the menu.
///
/// The button shortens a long name itself. Left to it, the pop-up button first narrows its left margin, by up to 7 pt,
/// and only then truncates, so a long name would start further left than a short one.
struct AppPicker: View {
    let current: RowApp
    let installedApps: InstalledApps
    /// Never draws: the menu's icons.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot: the button's icon only.
    let icon: (URL) -> NSImage
    /// nil = None.
    let choose: (AppChoice?) -> Void
    let chooseOther: () -> Void

    var body: some View {
        Picker(selection: selection) {
            ForEach(Array(installedApps.pickerMenu(checking: current).enumerated()), id: \.offset) { _, item in
                switch item {
                case .app(let entry, _):
                    Label { Text(entry.name) } icon: { Image(nsImage: cachedIcon(entry.url)) }
                        .tag(Choice.app(entry))
                case .divider:
                    Divider()
                case .other:
                    Text("Other…").tag(Choice.other)
                case .unassigned:
                    Text("None").tag(Choice.unassigned)
                }
            }
        } label: {
            Text("App")
        } currentValueLabel: {
            switch current {
            case .unassigned:
                Text("Choose app…").foregroundStyle(.secondary)
            case .present(let entry):
                Label { Text(Self.fitted(entry.name)) } icon: { Image(nsImage: icon(entry.url)) }
            case .missing(let name):
                Label(Self.fitted("\(name)  not found"), systemImage: "questionmark.app.dashed")
                    .foregroundStyle(.tertiary)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 132)
    }

    /// The room a name has beside a 16 pt icon in a 132 pt button at the full left margin, measured on macOS 26.
    private static let nameWidth: CGFloat = 66

    /// `name`, cut at the end with an ellipsis until it fits `nameWidth` in the button's font.
    private static func fitted(_ name: String) -> String {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
        guard width(name) > nameWidth else { return name }
        var kept = name
        while !kept.isEmpty, width(kept + "…") > nameWidth { kept.removeLast() }
        return kept.trimmingCharacters(in: .whitespaces) + "…"
    }

    private enum Choice: Hashable {
        case app(AppEntry)
        case other
        case unassigned
        /// Not in the menu: the button shows the missing app.
        case missing
    }

    /// Other… is an action, not a value: it leaves the selection as it was.
    private var selection: Binding<Choice> {
        Binding {
            switch current {
            case .unassigned: .unassigned
            case .present(let entry): .app(entry)
            case .missing: .missing
            }
        } set: { choice in
            switch choice {
            case .app(let entry): choose(.app(entry))
            case .unassigned: choose(nil)
            case .other: chooseOther()
            case .missing: break
            }
        }
    }
}
