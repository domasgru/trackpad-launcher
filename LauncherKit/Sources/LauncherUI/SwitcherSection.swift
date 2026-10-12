import AppKit
import LauncherCore
import SwiftUI

/// The swipe illustration and title, the switcher list's rows in switcher order, and Add app…. With no rows it is
/// only the illustration, the title and the button.
struct SwitcherSection: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TemplateImage.view("swipe")
                    .scaleEffect(x: launcher.handMode == .left ? -1 : 1, y: 1)
                    .accessibilityHidden(true)
                Text("Swipe to switch apps")
                    .font(.body)
                Spacer(minLength: 0)
            }
            if !launcher.switcherRows.isEmpty {
                SwitcherRowList(launcher: launcher, actions: actions)
                    .layoutPriority(-1)
            }
            AppMenuButton(
                form: .pullDown(title: "Add app…", listed: Set(launcher.switcherRows.map(\.id))),
                installedApps: launcher.installedApps,
                cachedIcon: actions.cachedIcon,
                icon: actions.icon,
                choose: { if let choice = $0 { launcher.addToSwitcher(choice) } },
                chooseOther: { actions.chooseOtherApp { launcher.addToSwitcher(.appBundle(at: $0)) } })
                .fixedSize()
        }
    }
}

/// Fixed-pitch rows in a scrolling region that stops growing when the window reaches the screen's height. Dragging a
/// row moves it with the pointer; on release it lands `round(dy / pitch)` rows away and the model clamps the index.
private struct SwitcherRowList: View {
    let launcher: Launcher
    let actions: LauncherActions
    @State private var dragging: BundleID?
    @State private var dragOffset: CGFloat = 0

    static let pitch: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(launcher.switcherRows.enumerated()), id: \.element.id) { index, row in
                    SwitcherListRow(row: row, launcher: launcher, actions: actions)
                        .frame(height: Self.pitch)
                        .offset(y: dragging == row.id ? dragOffset : 0)
                        .zIndex(dragging == row.id ? 1 : 0)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    dragging = row.id
                                    dragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    let target = index + Int((value.translation.height / Self.pitch).rounded())
                                    dragging = nil
                                    dragOffset = 0
                                    launcher.moveInSwitcher(row.id, to: target)
                                })
                }
            }
        }
        .scrollIndicators(.automatic)
    }
}

/// An app's icon and name, or its greyed name with "not found" while it is missing. Hovering shows the remove button.
private struct SwitcherListRow: View {
    let row: SwitcherRow
    let launcher: Launcher
    let actions: LauncherActions
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            if let present = row.present {
                Image(nsImage: actions.cachedIcon(present.url))
                Text(present.name)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .frame(width: 16, height: 16)
                Text("\(row.assigned.name)  not found")
            }
            Spacer(minLength: 8)
            if hovering {
                Button {
                    launcher.removeFromSwitcher(row.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(row.assigned.name)")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(row.present == nil ? .tertiary : .primary)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Remove") { launcher.removeFromSwitcher(row.id) }
        }
    }
}
